"""Replenishment API (Tier 1)."""
from __future__ import annotations

from rest_framework import status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView

from ..rbac import InventoryPermission, has_capability
from ..services import replenishment
from .base import _audit, _forced_branch_id


def _resolve_branch(request):
    """Branch the request applies to, honouring the user's scope.

    A branch-scoped user is pinned to their own warehouse even if they pass a
    different ``branch`` — the read *and* the write must agree, otherwise a
    storekeeper could draft a PO for someone else's shelf.
    """
    forced = _forced_branch_id(getattr(request, 'user', None))
    if forced:
        return forced
    return request.data.get('branch') or request.query_params.get('branch')


class ReplenishmentView(APIView):
    """Live replenishment plan: what to buy, how much, from whom."""
    permission_classes = [InventoryPermission]

    def get(self, request):
        branch = _resolve_branch(request)
        include_watch = request.query_params.get('watch', '1') not in ('0', 'false')
        payload = replenishment.build_suggestions(
            branch_id=branch, include_watch=include_watch, write=False)
        # Tell the UI whether the branch switcher should be locked.
        payload['branch_scope'] = {
            'locked': bool(_forced_branch_id(request.user)),
            'branch_id': int(branch) if branch else None,
        }
        return Response(payload)

    def post(self, request):
        """Persist the plan (refreshes ReorderSuggestion rows)."""
        branch = _resolve_branch(request)
        payload = replenishment.build_suggestions(branch_id=branch, write=True)
        _audit(request, 'replenish_plan', 'reorder-suggestions',
               description=f'Replenishment plan: {payload["summary"]["lines"]} line(s)',
               payload_diff=payload['summary'])
        return Response(payload)


class DraftPurchaseOrdersView(APIView):
    """Turn the plan into DRAFT purchase orders, one per supplier."""
    permission_classes = [InventoryPermission]

    def post(self, request):
        if not has_capability(request, 'manage_purchase_orders'):
            # Fall back to the stock-manage capability when the purchasing
            # capability is not part of this tenant's role set.
            if not has_capability(request, 'stock.manage'):
                return Response(
                    {'detail': 'You do not have permission to draft purchase orders.'},
                    status=status.HTTP_403_FORBIDDEN)
        branch = _resolve_branch(request)
        min_severity = request.data.get('min_severity', 'high')
        result = replenishment.draft_purchase_orders(
            branch_id=branch,
            user=request.user,
            min_severity=min_severity,
        )
        _audit(request, 'po_autodraft', 'purchase-orders',
               description=f'Auto-drafted {len(result["purchase_orders"])} purchase order(s)',
               payload_diff=result)
        return Response(result, status=status.HTTP_201_CREATED)


class ReviewedPurchaseOrdersView(APIView):
    """Create DRAFT POs from the reviewed workbench payload.

    The client posts exactly what the planner confirmed — suppliers, edited
    quantities and negotiated prices — instead of asking the server to re-derive
    the plan. Every line is re-validated server-side (see
    :func:`inventory.services.replenishment.create_purchase_orders`).
    """
    permission_classes = [InventoryPermission]

    def post(self, request):
        if not has_capability(request, 'manage_purchase_orders') \
                and not has_capability(request, 'stock.manage'):
            return Response(
                {'detail': 'You do not have permission to draft purchase orders.'},
                status=status.HTTP_403_FORBIDDEN)

        groups = request.data.get('groups') or []
        branch = _resolve_branch(request)
        try:
            result = replenishment.create_purchase_orders(
                groups,
                user=request.user,
                branch_id=branch,
                notes=request.data.get('notes', '') or '',
            )
        except replenishment.DraftError as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_400_BAD_REQUEST)

        _audit(request, 'po_review_draft', 'purchase-orders',
               description=(f'Drafted {len(result["purchase_orders"])} purchase '
                            f'order(s) from the workbench'),
               payload_diff={'lines': result['lines'],
                             'total_cost': result['total_cost'],
                             'skipped': len(result['skipped'])})
        return Response(result, status=status.HTTP_201_CREATED)


class LinkSupplierView(APIView):
    """Attach a supplier to a stock item (resolves "no supplier" lines)."""
    permission_classes = [InventoryPermission]

    def post(self, request):
        stock_id = request.data.get('stock_id')
        supplier_id = request.data.get('supplier_id')
        if not stock_id or not supplier_id:
            return Response({'detail': 'stock_id and supplier_id are required.'},
                            status=status.HTTP_400_BAD_REQUEST)
        try:
            result = replenishment.link_supplier_item(
                supplier_id=supplier_id,
                stock_id=stock_id,
                unit_cost=request.data.get('unit_cost'),
                item_name=request.data.get('item_name', '') or '',
            )
        except replenishment.DraftError as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_400_BAD_REQUEST)

        _audit(request, 'supplier_link', 'supplier-item',
               description=f'Linked {result["supplier_name"]} to a stock item',
               payload_diff=result)
        return Response(result, status=status.HTTP_201_CREATED)


class RFQFromPlanView(APIView):
    """Open an RFQ for selected replenishment lines and invite suppliers."""
    permission_classes = [InventoryPermission]

    def post(self, request):
        rows = request.data.get('items') or []
        supplier_ids = request.data.get('supplier_ids') or []
        branch = _resolve_branch(request)
        try:
            result = replenishment.create_rfq(
                rows=rows,
                supplier_ids=supplier_ids,
                user=request.user,
                branch_id=branch,
                title=request.data.get('title', '') or '',
                response_deadline=request.data.get('response_deadline') or None,
                expected_delivery=request.data.get('expected_delivery') or None,
                notes=request.data.get('notes', '') or '',
            )
        except replenishment.DraftError as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_400_BAD_REQUEST)

        _audit(request, 'rfq_create', 'rfq',
               description=(f'Opened {result["rfq_number"]} for '
                            f'{result["lines"]} item(s), '
                            f'{len(result["invited"])} supplier(s) invited'),
               payload_diff=result)
        return Response(result, status=status.HTTP_201_CREATED)


class SupplierPickerView(APIView):
    """Suppliers available to buy from, with per-item pricing hints.

    Used by both the PO workbench and the RFQ invite picker so the client does
    not need a second round-trip per line.
    """
    permission_classes = [InventoryPermission]

    def get(self, request):
        from suppliers.models import SupplierItem

        from ..models import MedicationStock

        qs = SupplierItem.objects.select_related('supplier', 'stock').filter(
            supplier__is_active=True)
        stock_ids = request.query_params.get('stocks', '')
        if stock_ids:
            try:
                wanted = [int(v) for v in stock_ids.split(',') if v.strip()]
            except ValueError:
                return Response({'detail': 'stocks must be a comma-separated list of ids.'},
                                status=status.HTTP_400_BAD_REQUEST)
            qs = qs.filter(stock_id__in=wanted)

        offered = {}
        for item in qs:
            offered.setdefault(item.stock_id, []).append({
                'supplier_id': item.supplier_id,
                'supplier_name': item.supplier.name,
                'unit_cost': float(item.unit_cost or 0),
                'lead_time_days': None,
            })
        return Response({'offers': {str(k): v for k, v in offered.items()}})


class DaysOfCoverView(APIView):
    """Ranked cover days for every moving item (server-side)."""
    permission_classes = [InventoryPermission]

    def get(self, request):
        from ..models import MedicationStock

        branch = request.query_params.get('branch')
        limit = int(request.query_params.get('limit', 100) or 100)
        qs = (MedicationStock.objects.with_quantities()
              .filter(is_active=True)
              .select_related('policy', 'branch', 'unit'))
        if branch:
            qs = qs.filter(branch_id=branch)

        rows = []
        for stock in qs:
            policy = getattr(stock, 'policy', None)
            avg = float(policy.avg_daily_demand) if policy else 0.0
            cover = replenishment.days_of_cover(stock, avg)
            rows.append({
                'stock_id': stock.id,
                'name': stock.medication_name,
                'unit': stock.unit.abbreviation if stock.unit else '',
                'branch_name': stock.branch.name if stock.branch else '',
                'on_hand': stock.total_quantity,
                'sellable': stock.sellable_quantity,
                'avg_daily_demand': round(avg, 2),
                'days_of_cover': cover,
                'reorder_point': round(float(policy.reorder_point), 1) if policy else 0,
                'severity': ('out' if stock.sellable_quantity <= 0 else
                             'critical' if cover is not None and cover <= 7 else
                             'high' if cover is not None and cover <= 14 else
                             'watch' if cover is not None and cover <= 30 else 'ok'),
            })

        # Items with no demand sink to the bottom (infinite cover).
        rows.sort(key=lambda r: (r['days_of_cover'] is None,
                                 r['days_of_cover'] or 0))
        return Response({'results': rows[:limit], 'total': len(rows)})


class AutoDraftSettingsView(APIView):
    """Flip the auto-draft switch without leaving the replenishment screen."""
    permission_classes = [InventoryPermission]

    def post(self, request):
        from ..models import InventorySettings
        obj = InventorySettings.get()
        obj.auto_draft_purchase_orders = bool(
            request.data.get('enabled', not obj.auto_draft_purchase_orders))
        obj.save(update_fields=['auto_draft_purchase_orders'])
        return Response({'auto_draft_purchase_orders': obj.auto_draft_purchase_orders})
