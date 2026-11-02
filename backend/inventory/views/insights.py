"""Executive insights API (Tier 7) and finance snapshots (Tier 5)."""
from __future__ import annotations

import logging

from rest_framework import serializers, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView

from django.utils import timezone

from ..models import (CycleCountSchedule, InventorySnapshot,
                      InventorySnapshotLine, StockAnomaly, WriteOffRequest)
from ..rbac import InventoryPermission, can_view_cost
from ..services import anomaly as anomaly_service
from ..services import cycle_count, kpis, scorecard, valuation
from ..services import planning
from .base import _audit, _forced_branch_id

logger = logging.getLogger(__name__)

#: Keys derived from purchase cost — hidden from till roles.
_COST_KPI_KEYS = ('cogs', 'inventory_value_cost', 'gross_margin',
                  'avg_inventory', 'gmroi', 'turns', 'dio_days')


def _scrub_cost(payload: dict) -> None:
    """Blank every cost-derived figure for roles without ``stock.cost``.

    The stock and batch serializers already hide unit costs, but the insights
    endpoints returned COGS, GMROI and valuation to any role that could read
    stock at all.
    """
    for key in _COST_KPI_KEYS:
        payload['kpis'][key] = None
    for band in payload['excess_obsolete'].get('bands', []):
        band['value'] = None
    payload['excess_obsolete']['total_value'] = None
    payload['excess_obsolete']['excess_value'] = None
    for key in ('total_cost_value', 'potential_profit', 'margin_pct'):
        if key in payload['valuation']:
            payload['valuation'][key] = None


class InsightsView(APIView):
    """Turns, DIO, GMROI, fill rate and excess/obsolete in one payload."""
    permission_classes = [InventoryPermission]

    def get(self, request):
        days = int(request.query_params.get('days', 90) or 90)
        branch = request.query_params.get('branch')
        # A branch-scoped user sees their own warehouse only — the valuation
        # used to be tenant-wide while the KPIs beside it were scoped.
        forced = _forced_branch_id(getattr(request, 'user', None))
        if forced:
            branch = forced
        payload = {
            'kpis': kpis.kpi_dashboard(days=days, branch_id=branch),
            'service': kpis.service_level(days=min(days, 90), branch_id=branch),
            'excess_obsolete': kpis.excess_by_age(branch_id=branch),
            'valuation': valuation.valuation_summary(branch_id=branch),
        }
        if not can_view_cost(request):
            _scrub_cost(payload)
        return Response(payload)


class WhatIfView(APIView):
    permission_classes = [InventoryPermission]

    def get(self, request):
        try:
            level = int(request.query_params.get('service_level', 95))
        except (TypeError, ValueError):
            return Response({'detail': 'service_level must be an integer.'},
                            status=400)
        if not 50 <= level <= 99:
            return Response({'detail': 'service_level must be between 50 and 99.'},
                            status=400)
        return Response(kpis.whats_if(level, branch_id=request.query_params.get('branch')))


class AnomalyViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [InventoryPermission]

    def get_queryset(self):
        qs = StockAnomaly.objects.select_related('stock', 'branch', 'user')
        if self.request.query_params.get('status'):
            qs = qs.filter(status=self.request.query_params['status'])
        if self.request.query_params.get('kind'):
            qs = qs.filter(kind=self.request.query_params['kind'])
        return qs.order_by('-created_at')

    def list(self, request, *args, **kwargs):
        only_open = request.query_params.get('open', '1') not in ('0', 'false')
        if only_open:
            rows = anomaly_service.open_anomalies(
                limit=int(request.query_params.get('limit', 50) or 50))
        else:
            rows = [{
                'id': a.id, 'kind': a.kind, 'kind_label': a.get_kind_display(),
                'severity': a.severity, 'title': a.title, 'detail': a.detail,
                'metric': a.metric, 'baseline': a.baseline, 'z_score': a.z_score,
                'occurrences': a.occurrences,
                'stock_id': a.stock_id,
                'stock_name': a.stock.medication_name if a.stock else '',
                'branch_name': a.branch.name if a.branch else '',
                'user_name': a.user.full_name if a.user else '',
                'created_at': a.created_at.isoformat(timespec='seconds'),
            } for a in self.get_queryset()[:200]]
        return Response({'results': rows})

    @action(detail=False, methods=['post'])
    def scan(self, request):
        """Run the detectors now (also runs nightly)."""
        result = anomaly_service.detect_all()
        return Response(result)

    @action(detail=True, methods=['post'])
    def acknowledge(self, request, pk=None):
        obj = self.get_object()
        obj.status = request.data.get('status', StockAnomaly.Status.ACKNOWLEDGED)
        obj.save(update_fields=['status'])
        return Response({'id': obj.id, 'status': obj.status})


class SnapshotLineSerializer(serializers.ModelSerializer):
    class Meta:
        model = InventorySnapshotLine
        fields = ['id', 'medication_name', 'unit_cost', 'quantity',
                  'value', 'abc_class']
        read_only_fields = fields


class InventorySnapshotSerializer(serializers.ModelSerializer):
    method_label = serializers.CharField(source='get_method_display', read_only=True)
    lines = SnapshotLineSerializer(many=True, read_only=True)

    class Meta:
        model = InventorySnapshot
        fields = ['id', 'period', 'method', 'method_label', 'total_units',
                  'total_cost_value', 'total_retail_value', 'expired_value',
                  'sku_count', 'created_by', 'created_at', 'lines']
        read_only_fields = fields


class InventorySnapshotViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [InventoryPermission]

    serializer_class = InventorySnapshotSerializer
    queryset = InventorySnapshot.objects.prefetch_related('lines').all()

    @action(detail=False, methods=['post'])
    def generate(self, request):
        period = request.data.get('period')
        parse = None
        if period:
            from datetime import date
            try:
                y, m, d = (int(x) for x in str(period).split('-'))
                parse = date(y, m, d)
            except (TypeError, ValueError):
                return Response({'detail': 'period must be YYYY-MM-DD.'}, status=400)
        snapshot = valuation.create_snapshot(
            period=parse,
            method=request.data.get('method'),
            user=request.user,
        )
        _audit(request, 'valuation_snap', snapshot,
               description=f'Valuation snapshot {snapshot.period} '
                           f'({snapshot.get_method_display()})',
               payload_diff={'total_cost_value': float(snapshot.total_cost_value),
                             'sku_count': snapshot.sku_count})
        return Response(self.get_serializer(snapshot).data,
                        status=status.HTTP_201_CREATED)


class LandedCostView(APIView):
    """Spread freight/duty/insurance across a purchase order's lines."""
    permission_classes = [InventoryPermission]

    def post(self, request):
        from purchase_orders.models import PurchaseOrder

        po = PurchaseOrder.objects.filter(id=request.data.get('purchase_order')).first()
        if not po:
            return Response({'detail': 'Purchase order not found.'}, status=404)
        result = valuation.apply_landed_cost(
            po,
            freight=request.data.get('freight', 0),
            duty=request.data.get('duty', 0),
            insurance=request.data.get('insurance', 0),
            other=request.data.get('other', 0),
        )
        _audit(request, 'landed_cost', po,
               description=f'Applied landed cost to {po.po_number}',
               payload_diff={'extra_cost': result['extra_cost']})
        return Response({**result, 'po_number': po.po_number})


class SupplierScorecardView(APIView):
    """Supplier performance ranking (Tier 6)."""
    permission_classes = [InventoryPermission]

    def get(self, request):
        days = int(request.query_params.get('days', 90) or 90)
        return Response({
            'results': scorecard.supplier_ranking(days=days),
            'window_days': days,
        })

    def post(self, request):
        result = scorecard.refresh_scorecards(
            days=int(request.data.get('days', 90) or 90))
        _audit(request, 'scorecard_sync', 'suppliers',
               description=f'Refreshed {result["scorecards"]} supplier scorecards',
               payload_diff=result)
        return Response({**result,
                         'results': scorecard.supplier_ranking(days=90)})


class WriteOffRequestSerializer(serializers.ModelSerializer):
    stock_name = serializers.CharField(source='stock.medication_name', read_only=True)
    requested_by_name = serializers.CharField(
        source='requested_by.full_name', read_only=True, default='')
    decided_by_name = serializers.CharField(
        source='decided_by.full_name', read_only=True, default='')

    class Meta:
        model = WriteOffRequest
        fields = ['id', 'adjustment', 'stock', 'stock_name', 'quantity', 'value',
                  'reason', 'notes', 'status', 'requested_by',
                  'requested_by_name', 'decided_by', 'decided_by_name',
                  'decided_at', 'signature', 'decision_note', 'created_at']
        read_only_fields = ['id', 'status', 'requested_by', 'decided_by',
                            'decided_at', 'created_at']


class WriteOffRequestViewSet(viewsets.ReadOnlyModelViewSet):
    """Write-off approvals.

    Read-only by design: a request is *created automatically* when a damage /
    expiry / theft adjustment crosses the tenant's threshold (see
    ``StockAdjustmentViewSet.perform_create``). Allowing a bare POST here
    produced a confusing "adjustment is required" 400 for a screen that only
    ever needs to list and decide.
    """
    serializer_class = WriteOffRequestSerializer
    permission_classes = [InventoryPermission]
    queryset = WriteOffRequest.objects.select_related(
        'stock', 'requested_by', 'decided_by').all()

    def get_queryset(self):
        qs = super().get_queryset()
        if self.request.query_params.get('status'):
            qs = qs.filter(status=self.request.query_params['status'])
        return qs

    @action(detail=True, methods=['post'])
    def decide(self, request, pk=None):
        from ..rbac import has_capability

        if not has_capability(request, 'adjustment.create'):
            return Response({'detail': 'Only supervisors may approve write-offs.'},
                            status=status.HTTP_403_FORBIDDEN)
        obj = self.get_object()
        if obj.status != WriteOffRequest.Status.PENDING:
            return Response({'detail': 'This request has already been decided.'},
                            status=status.HTTP_409_CONFLICT)

        approve = bool(request.data.get('approve'))
        obj.status = (WriteOffRequest.Status.APPROVED if approve
                      else WriteOffRequest.Status.REJECTED)
        obj.decided_by = request.user
        obj.decided_at = timezone.now()
        obj.signature = request.data.get('signature', '') or ''
        obj.decision_note = request.data.get('note', '') or ''
        obj.save()

        # Rejecting must undo the loss, otherwise the shelf silently stays short.
        outcome = 'applied'
        try:
            from ..services import quality as quality_service
            outcome = quality_service.apply_writeoff_decision(obj, approve=approve)
        except Exception:
            logger.exception('could not apply the write-off decision')

        _audit(request, 'writeoff_decide', obj,
               severity='warning' if approve else 'info',
               description=f'Write-off {"approved" if approve else "rejected"} '
                           f'for {obj.stock.medication_name}',
               payload_diff={'value': float(obj.value), 'approved': approve,
                             'outcome': outcome})
        return Response({**self.get_serializer(obj).data, 'outcome': outcome})


class CycleCountPlanView(APIView):
    """ABC cycle-count plan (Tier 1)."""
    permission_classes = [InventoryPermission]

    def _payload(self, branch, horizon):
        # Bootstrap / top-up the schedule before reading it. ``ensure_coverage``
        # only writes when fewer schedules exist than active stock rows, so a
        # partially-seeded plan (three rows for a 31-item catalogue) heals
        # itself instead of hiding 28 items from the plan forever.
        cycle_count.ensure_coverage(branch_id=branch)
        return cycle_count.plan_dashboard(branch_id=branch,
                                          horizon_days=horizon)

    def get(self, request):
        branch = request.query_params.get('branch')
        try:
            horizon = int(request.query_params.get('horizon', 90) or 90)
        except (TypeError, ValueError):
            horizon = 90
        horizon = max(14, min(horizon, 365))
        return Response(self._payload(branch, horizon))

    def post(self, request):
        branch = request.data.get('branch')
        try:
            horizon = int(request.data.get('horizon', 90) or 90)
        except (TypeError, ValueError):
            horizon = 90
        replan = cycle_count.replan(branch_id=branch)
        created = cycle_count.create_count_from_schedule(
            branch_id=branch, user=request.user,
            limit=int(request.data.get('limit', 200) or 200))
        _audit(request, 'cycle_count_plan', 'counts',
               description=f'Planned {created["counts_created"]} cycle count(s)',
               payload_diff={**replan, **created})
        return Response({**replan, **created,
                         **self._payload(branch, max(14, min(horizon, 365)))})


class PlanRefreshView(APIView):
    """One-click recompute of policies + forecasts (planning screen)."""
    permission_classes = [InventoryPermission]

    def post(self, request):
        branch = request.data.get('branch')
        result = {
            'policies': planning.refresh_policies(branch_id=branch),
            'forecasts': planning.refresh_forecasts(branch_id=branch),
            'accuracy': planning.backfill_forecast_accuracy(),
        }
        _audit(request, 'planning_refresh', 'planning',
               description='Recomputed policies and forecasts',
               payload_diff=result['policies'])
        return Response(result)
