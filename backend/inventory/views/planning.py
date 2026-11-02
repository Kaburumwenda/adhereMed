"""Planning API (Tier 2): policies, forecasts, S&OP and what-if."""
from __future__ import annotations

from datetime import timedelta

from django.db.models import Avg, Count, Max, Min, Q, Sum
from django.utils import timezone
from rest_framework import serializers, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response
from rest_framework.views import APIView

from ..models import (DemandForecast, InventorySettings, MedicationStock,
                      StockPolicy, StorageZone)
from ..rbac import InventoryPermission, has_capability
from ..services import forecasting, kpis, planning, replenishment
from .base import _audit, _forced_branch_id
from pharmacy_profile.models import Branch


class StockPolicySerializer(serializers.ModelSerializer):
    medication_name = serializers.CharField(
        source='stock.medication_name', read_only=True)
    stock_unit = serializers.CharField(
        source='stock.unit.abbreviation', read_only=True, default='')
    branch_name = serializers.CharField(
        source='stock.branch.name', read_only=True, default=None)
    on_hand = serializers.IntegerField(source='stock.total_quantity', read_only=True)
    sellable = serializers.IntegerField(
        source='stock.sellable_quantity', read_only=True)
    days_of_cover = serializers.SerializerMethodField()
    storage_zone_name = serializers.CharField(
        source='storage_zone.name', read_only=True, default=None)

    class Meta:
        model = StockPolicy
        fields = [
            'id', 'stock', 'medication_name', 'stock_unit', 'branch_name',
            'on_hand', 'sellable', 'days_of_cover',
            'avg_daily_demand', 'demand_stddev', 'lead_time_days',
            'lead_time_stddev', 'safety_stock', 'reorder_point', 'eoq',
            'order_multiple', 'min_qty', 'max_qty', 'service_level',
            'abc_class', 'xyz_class', 'value_share', 'forecast_mape',
            'is_manual_lead_time', 'is_manual_reorder_point',
            'is_manual_service_level',
            'is_quarantined', 'quarantine_reason',
            'storage_zone', 'storage_zone_name',
            'last_counted_at', 'next_count_due', 'updated_at',
        ]
        read_only_fields = [
            'id', 'avg_daily_demand', 'demand_stddev', 'safety_stock',
            'eoq', 'abc_class', 'xyz_class', 'value_share', 'forecast_mape',
            'last_counted_at', 'updated_at',
        ]

    def get_days_of_cover(self, obj):
        return replenishment.days_of_cover(obj.stock, obj.avg_daily_demand)


class StockPolicyViewSet(viewsets.ModelViewSet):
    """Planning parameters. Manual overrides are preserved across recomputes.

    Policies are inherently per-warehouse: each one hangs off a
    :class:`MedicationStock` row, which belongs to exactly one branch. A
    branch-scoped user (branch admin, storekeeper, pharmacist) must therefore
    never see — or be able to patch — another warehouse's parameters, even by
    passing ``?branch=``. :meth:`_scope` is the single place that decides which
    warehouse a request applies to, for reads *and* writes.
    """
    serializer_class = StockPolicySerializer
    permission_classes = [InventoryPermission]
    filter_backends = []
    http_method_names = ['get', 'patch', 'put', 'post', 'head', 'options']

    # ── Branch resolution ──────────────────────────────────────────────
    def _requested_branch(self):
        params = self.request.query_params
        raw = params.get('branch') or self.request.data.get('branch')
        if raw in (None, '', 'all'):
            return None
        try:
            return int(raw)
        except (TypeError, ValueError):
            return None

    def _scope(self):
        """Return ``(branch_id, locked)`` for the current request."""
        forced = _forced_branch_id(getattr(self.request, 'user', None))
        if forced:
            # A scoped user asking for another warehouse silently gets their
            # own — the alternative (an empty table) looks like "no policies".
            return forced, True
        return self._requested_branch(), False

    def get_queryset(self):
        qs = StockPolicy.objects.select_related(
            'stock', 'stock__unit', 'stock__branch', 'storage_zone')
        params = self.request.query_params

        branch, _locked = self._scope()
        if branch:
            qs = qs.filter(stock__branch_id=branch)

        if params.get('abc'):
            qs = qs.filter(abc_class=params['abc'].upper())
        if params.get('xyz'):
            qs = qs.filter(xyz_class=params['xyz'].upper())
        if params.get('quarantined') in ('1', 'true'):
            qs = qs.filter(is_quarantined=True)
        if params.get('manual') in ('1', 'true'):
            qs = qs.filter(
                Q(is_manual_reorder_point=True)
                | Q(is_manual_lead_time=True)
                | Q(is_manual_service_level=True))
        if params.get('search'):
            qs = qs.filter(stock__medication_name__icontains=params['search'])
        if params.get('below_rop') in ('1', 'true'):
            qs = qs.filter(stock__isnull=False)
            ids = [p.stock_id for p in qs
                   if p.stock.sellable_quantity <= p.reorder_point]
            qs = qs.filter(stock_id__in=ids)
        ordering = params.get('ordering')
        allowed = {'abc_class', 'xyz_class', 'reorder_point', 'safety_stock',
                   'avg_daily_demand', 'next_count_due', 'value_share'}
        if ordering and ordering.lstrip('-') in allowed:
            return qs.order_by(ordering)
        return qs.order_by('abc_class', '-value_share')

    # ── Read: scope metadata for the branch switcher ────────────────────
    def list(self, request, *args, **kwargs):
        """Paginated policies plus the branch scope the UI should render."""
        response = super().list(request, *args, **kwargs)
        branch, locked = self._scope()
        if isinstance(response.data, dict):
            response.data['branch_scope'] = {
                'locked': locked,
                'branch_id': branch,
            }
            response.data['summary'] = self._summarise(branch)
        return response

    def _summarise(self, branch):
        """Per-branch headline numbers, so the workspace is never a bare table."""
        qs = StockPolicy.objects.filter(stock__isnull=False)
        if branch:
            qs = qs.filter(stock__branch_id=branch)

        policies = list(qs.only(
            'id', 'reorder_point', 'abc_class', 'is_quarantined', 'stock_id'))
        policy_by_stock = {p.stock_id: p for p in policies}

        # Branch-level totals need the stock rows, not just the policies, so
        # items with no policy yet still count towards the catalogue.
        stocks = (MedicationStock.objects.filter(is_active=True)
                  .with_quantities())
        if branch:
            stocks = stocks.filter(branch_id=branch)

        below = 0
        out = 0
        total_items = 0
        for stock in stocks.only('id', 'reorder_level'):
            total_items += 1
            policy = policy_by_stock.get(stock.id)
            rop = float(policy.reorder_point) if policy else float(
                stock.reorder_level or 0)
            rop = max(rop, float(stock.reorder_level or 0))
            sellable = float(stock.available_quantity or 0)
            if sellable <= 0:
                out += 1
            elif sellable <= rop:
                below += 1

        return {
            'policies': len(policies),
            'items': total_items,
            'without_policy': max(0, total_items - len(policies)),
            'below_rop': below,
            'out_of_stock': out,
            'quarantined': sum(1 for p in policies if p.is_quarantined),
            'manual_overrides': qs.filter(
                Q(is_manual_reorder_point=True)
                | Q(is_manual_lead_time=True)
                | Q(is_manual_service_level=True)).count(),
            'abc': {
                'A': sum(1 for p in policies if p.abc_class == 'A'),
                'B': sum(1 for p in policies if p.abc_class == 'B'),
                'C': sum(1 for p in policies if p.abc_class == 'C'),
            },
        }

    @action(detail=False, methods=['get'], url_path='branches')
    def branches(self, request):
        """Warehouses available to this user, with their planning load.

        Powers the branch switcher so it can show per-warehouse pressure
        instead of a blind list of names — and it disappears entirely for a
        scoped user, who only ever sees their own shelf.
        """
        forced = _forced_branch_id(request.user)
        rows = StockPolicy.objects.values('stock__branch_id').annotate(
            policies=Count('id'))
        counts = {r['stock__branch_id']: r['policies'] for r in rows}

        branches = Branch.objects.all().order_by('-is_main', 'name')
        if forced:
            branches = branches.filter(id=forced)

        payload = []
        for branch in branches:
            payload.append({
                'id': branch.id,
                'name': branch.name,
                'is_main': branch.is_main,
                'policies': counts.get(branch.id, 0),
            })
        return Response({
            'branches': payload,
            'locked': bool(forced),
            'branch_id': forced,
        })

    # ── Write: never cross a warehouse boundary ─────────────────────────
    def _assert_scope(self, policy):
        forced = _forced_branch_id(self.request.user)
        if forced and policy.stock.branch_id != forced:
            raise PermissionDenied(
                'You can only edit planning parameters for your own warehouse.')

    def perform_update(self, serializer):
        # Track every planner-editable field, not just the derived ones — a
        # min/max or pack-size edit is just as auditable as a ROP change.
        self._assert_scope(serializer.instance)
        tracked = ('reorder_point', 'safety_stock', 'eoq', 'min_qty', 'max_qty',
                   'order_multiple', 'lead_time_days', 'service_level',
                   'abc_class', 'xyz_class')
        before = {f: getattr(serializer.instance, f) for f in tracked}
        policy = serializer.save()
        changes = {k: [before[k], getattr(policy, k)]
                   for k in tracked if before[k] != getattr(policy, k)}
        if changes:
            _audit(self.request, 'policy_update', policy,
                   description=f'Updated stock policy for {policy.stock.medication_name}',
                   payload_diff={'changes': changes,
                                 'branch': policy.stock.branch_id})

    @action(detail=False, methods=['post'], url_path='recompute')
    def recompute(self, request):
        """Recompute every policy in scope (demand, safety stock, ROP, EOQ).

        A branch-scoped planner recomputes their own warehouse only — the
        nightly job still refreshes the whole tenant.
        """
        branch, locked = self._scope()
        result = planning.refresh_policies(branch_id=branch)
        _audit(request, 'policy_recompute', 'policies',
               description=(f'Recomputed {result["policies_updated"]} stock '
                            f'policies'
                            + (f' for branch {branch}' if branch else '')),
               payload_diff={**result, 'branch': branch, 'scoped': locked})
        return Response({**result, 'branch': branch, 'branch_locked': locked})

    @action(detail=False, methods=['post'], url_path='reset-manual')
    def reset_manual(self, request):
        """Hand control back to the statistical engine for selected policies.

        Manual overrides are sticky by design, so undoing them needs to be an
        explicit action — otherwise a single mistyped reorder point would
        follow the item forever.
        """
        ids = request.data.get('ids') or []
        field = request.data.get('field') or 'all'
        if field not in ('all', 'reorder_point', 'lead_time', 'service_level'):
            return Response({'detail': 'Unknown field.'},
                            status=status.HTTP_400_BAD_REQUEST)

        qs = self.get_queryset()
        if ids:
            try:
                qs = qs.filter(id__in=[int(i) for i in ids])
            except (TypeError, ValueError):
                return Response({'detail': 'ids must be a list of integers.'},
                                status=status.HTTP_400_BAD_REQUEST)

        flags = []
        if field in ('all', 'reorder_point'):
            flags.append('is_manual_reorder_point')
        if field in ('all', 'lead_time'):
            flags.append('is_manual_lead_time')
        if field in ('all', 'service_level'):
            flags.append('is_manual_service_level')

        reset = 0
        branch, locked = self._scope()
        for policy in qs:
            self._assert_scope(policy)
            for flag in flags:
                setattr(policy, flag, False)
            policy.save(update_fields=list(flags) + ['updated_at'])
            reset += 1

        if reset:
            planning.refresh_policies(branch_id=branch)
            _audit(request, 'policy_reset', 'policies',
                   description=f'Cleared manual overrides on {reset} policies',
                   payload_diff={'reset': reset, 'field': field,
                                 'branch': branch, 'scoped': locked})
        return Response({'reset': reset, 'field': field,
                         'branch': branch, 'branch_locked': locked})



class DemandForecastViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_fields = None
    permission_classes = [InventoryPermission]

    def get_queryset(self):
        qs = (DemandForecast.objects
              .select_related('stock', 'stock__unit', 'branch'))
        params = self.request.query_params
        if params.get('stock'):
            qs = qs.filter(stock_id=params['stock'])
        if params.get('branch'):
            qs = qs.filter(branch_id=params['branch'])
        days = int(params.get('days', 30) or 30)
        today = timezone.localdate()
        qs = qs.filter(forecast_date__gte=today,
                       forecast_date__lte=today + timedelta(days=days))
        return qs.order_by('forecast_date')

    def list(self, request, *args, **kwargs):
        """Grouped payload: one entry per item with its daily chart."""
        qs = self.get_queryset()
        grouped = {}
        for row in qs[:5000]:
            entry = grouped.setdefault(row.stock_id, {
                'stock_id': row.stock_id,
                'name': row.stock.medication_name,
                'unit': row.stock.unit.abbreviation if row.stock.unit else '',
                'branch_name': row.branch.name if row.branch else '',
                'method': row.method,
                'confidence': row.confidence,
                'points': [],
                'total': 0.0,
            })
            entry['points'].append({
                'date': row.forecast_date.isoformat(),
                'qty': round(row.predicted_qty, 2),
                'actual': row.actual_qty,
                'mape': row.mape,
            })
            entry['total'] = round(entry['total'] + row.predicted_qty, 2)
        return Response({'results': list(grouped.values())})

    @action(detail=False, methods=['get'])
    def accuracy(self, request):
        """Forecast accuracy (MAPE) summary and worst performers."""
        lookback = int(request.query_params.get('days', 30) or 30)
        start = timezone.localdate() - timedelta(days=lookback)
        rows = (DemandForecast.objects
                .filter(forecast_date__gte=start, actual_qty__isnull=False)
                .values('stock__medication_name')
                .annotate(
                    n=Count('id'),
                    avg_actual=Avg('actual_qty'),
                    avg_predicted=Avg('predicted_qty'),
                )
                .order_by('-n')[:200])

        scored = []
        for row in rows:
            from django.db.models import F
            forecast_row = (DemandForecast.objects
                            .filter(forecast_date__gte=start,
                                    stock__medication_name=row['stock__medication_name'])
                            .values_list('actual_qty', 'predicted_qty'))
            value = forecasting.mape([a for a, _ in forecast_row],
                                     [p for _, p in forecast_row])
            if value is not None:
                scored.append({
                    'name': row['stock__medication_name'],
                    'mape': round(value, 1),
                    'samples': row['n'],
                })
        scored.sort(key=lambda r: r['mape'])

        overall = (round(sum(r['mape'] for r in scored) / len(scored), 1)
                   if scored else None)

        # Error distribution — a single average hides whether the catalogue is
        # uniformly mediocre or split between excellent and useless forecasts.
        band_defs = [('0–5%', 0, 5), ('5–10%', 5, 10), ('10–20%', 10, 20),
                     ('20–30%', 20, 30), ('30%+', 30, None)]
        bands = []
        for label, lo, hi in band_defs:
            count = sum(1 for r in scored
                        if r['mape'] >= lo and (hi is None or r['mape'] < hi))
            bands.append({
                'label': label,
                'count': count,
                'pct': round(count / len(scored) * 100, 1) if scored else 0,
            })

        return Response({
            'window_days': lookback,
            'overall_mape': overall,
            'accuracy_pct': round(100 - overall, 1) if overall is not None else None,
            'best': scored[:5],
            'worst': scored[-5:][::-1] if scored else [],
            'items_scored': len(scored),
            'samples': sum(r['samples'] for r in scored),
            'bands': bands,
            'rating': ('excellent' if overall is not None and overall <= 10 else
                       'good' if overall is not None and overall <= 20 else
                       'fair' if overall is not None and overall <= 30 else
                       'poor' if overall is not None else 'unscored'),
        })

    @action(detail=False, methods=['post'], url_path='refresh')
    def refresh(self, request):
        branch = request.data.get('branch') or request.query_params.get('branch')
        horizon = request.data.get('horizon')
        result = planning.refresh_forecasts(
            branch_id=branch,
            horizon_days=int(horizon) if horizon else None)
        return Response(result)


class SOPView(APIView):
    """Sales & operations planning: forecast vs actual, bias, what-if.

    The response carries four story blocks so the planner screen can explain
    itself without a second round-trip:

    ``series``/``horizon``   what was predicted vs what happened (history)
    ``scenarios``/``ladder`` the capital cost of moving the service level
    ``planning``             posture of the policy set (ABC/XYZ, lead times,
                             capital, manual overrides)
    ``readiness``            what is still missing before S&OP can be scored

    The last block matters because a tenant can have 31 policies and zero
    demand history — every number is legitimately 0 and the UI must say why
    rather than render an empty chart.
    """
    permission_classes = [InventoryPermission]

    #: Service levels offered by the what-if ladder.
    LADDER_LEVELS = (90, 95, 98, 99)

    def get(self, request):
        days = int(request.query_params.get('days', 30) or 30)
        branch = request.query_params.get('branch')
        today = timezone.localdate()
        start = today - timedelta(days=days)

        forecasts = DemandForecast.objects.all()
        if branch:
            forecasts = forecasts.filter(stock__branch_id=branch)

        # ── History: forecast vs actual ────────────────────────────────
        actuals = (forecasts
                   .filter(forecast_date__gte=start, actual_qty__isnull=False)
                   .values('forecast_date')
                   .annotate(actual=Avg('actual_qty'), predicted=Avg('predicted_qty'))
                   .order_by('forecast_date'))

        series = [{
            'date': row['forecast_date'].isoformat(),
            'actual': round(float(row['actual'] or 0), 2),
            'forecast': round(float(row['predicted'] or 0), 2),
        } for row in actuals]

        total_actual = sum(r['actual'] for r in series)
        total_forecast = sum(r['forecast'] for r in series)
        bias = (round((total_forecast - total_actual) / total_actual * 100, 1)
                if total_actual else 0)

        # ── Forward-looking horizon ────────────────────────────────────
        # Reported separately from accuracy: a tenant right after a
        # successful recompute has a horizon but no scored history yet.
        horizon_qs = forecasts.filter(forecast_date__gt=today)
        horizon_agg = horizon_qs.aggregate(
            units=Sum('predicted_qty'), points=Count('id'),
            skus=Count('stock', distinct=True),
        )
        horizon_end = horizon_qs.aggregate(last=Max('forecast_date'))['last']

        # Weekly buckets for the projection chart (real rows only).
        weekly = {}
        for row in (horizon_qs.values('forecast_date')
                    .annotate(units=Sum('predicted_qty'))
                    .order_by('forecast_date')):
            iso = row['forecast_date'].isocalendar()
            key = f'{iso[0]}-W{iso[1]:02d}'
            bucket = weekly.setdefault(key, {'key': key, 'units': 0.0,
                                             'start': row['forecast_date']})
            bucket['units'] += float(row['units'] or 0)
            bucket['start'] = min(bucket['start'], row['forecast_date'])
        horizon_weeks = [
            {'key': b['key'], 'start': b['start'].isoformat(),
             'units': round(b['units'], 1)}
            for b in sorted(weekly.values(), key=lambda x: x['start'])
        ]

        # ── Policy posture ─────────────────────────────────────────────
        policy_scope = {'stock__branch_id': branch} if branch else {}
        policies = StockPolicy.objects.filter(**policy_scope)
        posture = policies.aggregate(
            policies=Count('id'),
            with_demand=Count('id', filter=Q(avg_daily_demand__gt=0)),
            with_rop=Count('id', filter=Q(reorder_point__gt=0)),
            with_lead_time=Count('id', filter=Q(lead_time_days__gt=0)),
            quarantined=Count('id', filter=Q(is_quarantined=True)),
            manual=Count(
                'id',
                filter=Q(is_manual_reorder_point=True)
                | Q(is_manual_service_level=True)
                | Q(is_manual_lead_time=True)),
            lead_avg=Avg('lead_time_days'),
            lead_min=Min('lead_time_days'),
            lead_max=Max('lead_time_days'),
            scored=Count('id', filter=Q(forecast_mape__isnull=False)),
        )
        abc_counts = {c: 0 for c in ('A', 'B', 'C')}
        for row in policies.values('abc_class').annotate(n=Count('id')):
            abc_counts[row['abc_class']] = row['n']
        xyz_counts = {c: 0 for c in ('X', 'Y', 'Z')}
        for row in policies.values('xyz_class').annotate(n=Count('id')):
            xyz_counts[row['xyz_class']] = row['n']

        # Capital held per ABC class, plus the count of items with no policy.
        stocks = MedicationStock.objects.with_quantities().filter(is_active=True)
        if branch:
            stocks = stocks.filter(branch_id=branch)
        capital = {c: {'value': 0.0, 'units': 0.0, 'items': 0}
                   for c in ('A', 'B', 'C', 'unplanned')}
        items_seen = 0
        for stock in stocks.select_related('policy', 'branch'):
            items_seen += 1
            policy = getattr(stock, 'policy', None)
            key = policy.abc_class if policy else 'unplanned'
            units = float(stock.total_quantity or 0)
            bucket = capital.setdefault(key, {'value': 0.0, 'units': 0.0, 'items': 0})
            bucket['value'] += units * float(stock.cost_price or 0)
            bucket['units'] += units
            bucket['items'] += 1

        capital_total = round(sum(b['value'] for b in capital.values()), 2)
        capital_rows = [
            {'abc': key,
             'value': round(b['value'], 2),
             'units': round(b['units'], 1),
             'items': b['items'],
             'share': round(b['value'] / capital_total * 100, 1) if capital_total else 0}
            for key, b in capital.items()
        ]
        capital_rows.sort(key=lambda r: -r['value'])

        # ── Service-level ladder ───────────────────────────────────────
        settings_obj = InventorySettings.get()
        current_level = settings_obj.service_level
        scenarios = [kpis.whats_if(level, days=days, branch_id=branch)
                     for level in self.LADDER_LEVELS]
        baseline = next((s for s in scenarios
                         if s['service_level_pct'] == current_level), None)
        base_units = float(baseline['extra_units']) if baseline else 0.0
        base_capital = float(baseline['extra_capital']) if baseline else 0.0

        ladder = []
        prev = None
        for row in scenarios:
            level = row['service_level_pct']
            capital_delta = round(float(row['extra_capital']) - base_capital, 2)
            units_delta = round(float(row['extra_units']) - base_units, 1)
            # Marginal spend of the last step up — the number that actually
            # kills a "let's just target 99%" conversation.
            marginal = None
            if prev is not None and level > prev['service_level_pct']:
                marginal = round(
                    (float(row['extra_capital']) - float(prev['extra_capital']))
                    / (level - prev['service_level_pct']), 2)
            ladder.append({
                **row,
                'z': round(forecasting.z_for_service_level(level), 3),
                'delta_units': units_delta,
                'delta_capital': capital_delta,
                'marginal_per_point': marginal,
                'is_current': level == current_level,
            })
            prev = row

        # ── Readiness checklist ────────────────────────────────────────
        has_history = bool(series)
        horizon_points = horizon_agg['points'] or 0
        readiness = [
            {
                'key': 'history',
                'label': 'Consumption history',
                'done': has_history,
                'detail': (f'{len(series)} scored day(s) in the last {days} days'
                           if has_history else
                           f'no issued or dispensed units in the last {days} days'),
                'action': 'Record sales, dispensing or stock issues',
            },
            {
                'key': 'forecasts',
                'label': 'Forecast horizon',
                'done': horizon_points > 0,
                'detail': (f'{horizon_points} point(s) for '
                           f"{horizon_agg['skus'] or 0} SKU(s)"
                           if horizon_points else
                           'nothing projected — press Recompute plan'),
                'action': 'Press Recompute plan',
            },
            {
                'key': 'demand',
                'label': 'Daily demand measured',
                'done': (posture['with_demand'] or 0) > 0,
                'detail': f"{posture['with_demand'] or 0} of "
                          f"{posture['policies'] or 0} policy(ies) have a rate",
                'action': 'Needs outbound movement',
            },
            {
                'key': 'lead_time',
                'label': 'Supplier lead time',
                'done': (posture['with_lead_time'] or 0) > 0,
                'detail': (f"average {float(posture['lead_avg'] or 0):.0f} d across "
                           f"{posture['with_lead_time']} item(s)"
                           if posture['with_lead_time'] else
                           'no lead time captured'),
                'action': 'Set lead times on the policy screen',
            },
            {
                'key': 'policy',
                'label': 'Reorder points derived',
                'done': (posture['with_rop'] or 0) > 0,
                'detail': f"{posture['with_rop'] or 0} of "
                          f"{posture['policies'] or 0} policy(ies) have a ROP",
                'action': 'Press Recompute plan',
            },
            {
                'key': 'accuracy',
                'label': 'Accuracy scored',
                'done': (posture['scored'] or 0) > 0,
                'detail': (f"{posture['scored']} item(s) carry a rolling MAPE"
                           if posture['scored'] else
                           'MAPE needs a forecast day to pass'),
                'action': 'Wait for forecast dates to pass',
            },
        ]
        blockers = [r for r in readiness if not r['done']]

        return Response({
            'window_days': days,
            'current_service_level': current_level,
            'series': series,
            'total_actual': round(total_actual, 2),
            'total_forecast': round(total_forecast, 2),
            'bias_pct': bias,
            'bias_direction': ('over-forecast' if bias > 5 else
                               'under-forecast' if bias < -5 else 'balanced'),
            'horizon': {
                'units': round(float(horizon_agg['units'] or 0), 2),
                'points': horizon_points,
                'skus': horizon_agg['skus'] or 0,
                'until': horizon_end.isoformat() if horizon_end else None,
            },
            'horizon_weeks': horizon_weeks,
            'scenarios': scenarios,
            'ladder': ladder,
            'quarantined_items': posture['quarantined'] or 0,
            'planning': {
                'policies': posture['policies'] or 0,
                'items': items_seen,
                'uncovered': capital['unplanned']['items'],
                'with_demand': posture['with_demand'] or 0,
                'with_rop': posture['with_rop'] or 0,
                'with_lead_time': posture['with_lead_time'] or 0,
                'manual': posture['manual'] or 0,
                'scored': posture['scored'] or 0,
                'quarantined': posture['quarantined'] or 0,
                'abc': abc_counts,
                'xyz': xyz_counts,
                'lead_time': {
                    'avg': round(float(posture['lead_avg'] or 0), 1),
                    'min': posture['lead_min'] or 0,
                    'max': posture['lead_max'] or 0,
                },
                'capital': capital_rows,
                'capital_total': capital_total,
                'forecast_days': settings_obj.forecast_days,
                'min_history_days': settings_obj.forecast_min_history_days,
                'cadence': {
                    'A': settings_obj.count_cadence_a,
                    'B': settings_obj.count_cadence_b,
                    'C': settings_obj.count_cadence_c,
                },
            },
            'readiness': readiness,
            'blockers': len(blockers),
            'ready': not blockers,
        })


class InventorySettingsView(APIView):
    """Tenant-level policy switches (service level, ladder, cadences)."""
    permission_classes = [InventoryPermission]

    def _payload(self, obj):
        return {
            'expiry_alert_days': obj.expiry_alert_days,
            'auto_quarantine_expired': obj.auto_quarantine_expired,
            'low_stock_notify': obj.low_stock_notify,
            'stale_days': obj.stale_days,
            'service_level': obj.service_level,
            'default_lead_time_days': obj.default_lead_time_days,
            'auto_draft_purchase_orders': obj.auto_draft_purchase_orders,
            'forecast_days': obj.forecast_days,
            'forecast_min_history_days': obj.forecast_min_history_days,
            'count_cadence_a': obj.count_cadence_a,
            'count_cadence_b': obj.count_cadence_b,
            'count_cadence_c': obj.count_cadence_c,
            'valuation_method': obj.valuation_method,
            'writeoff_approval_threshold': float(obj.writeoff_approval_threshold or 0),
            'updated_at': obj.updated_at.isoformat(timespec='seconds'),
        }

    def get(self, request):
        return Response(self._payload(InventorySettings.get()))

    #: field -> (min, max) for the numeric policy switches.
    _RANGES = {
        'service_level': (50, 99),
        'default_lead_time_days': (0, 365),
        'forecast_days': (1, 365),
        'forecast_min_history_days': (1, 180),
        'stale_days': (1, 3650),
        'count_cadence_a': (1, 3650),
        'count_cadence_b': (1, 3650),
        'count_cadence_c': (1, 3650),
    }

    def _validate(self, data):
        """Reject values that would break the planning maths.

        ``PATCH`` used to write anything through — a 500% service level, a
        zero-day cadence or an unknown valuation method all persisted and
        silently corrupted safety stock / cycle planning.
        """
        errors = {}
        for field, (lo, hi) in self._RANGES.items():
            if field not in data:
                continue
            try:
                value = int(data[field])
            except (TypeError, ValueError):
                errors[field] = 'Must be a whole number.'
                continue
            if not lo <= value <= hi:
                errors[field] = f'Must be between {lo} and {hi}.'
        if 'valuation_method' in data:
            valid = {c[0] for c in InventorySettings.ValuationMethod.choices}
            if data['valuation_method'] not in valid:
                errors['valuation_method'] = f'Must be one of {sorted(valid)}.'
        if 'writeoff_approval_threshold' in data:
            try:
                if float(data['writeoff_approval_threshold']) < 0:
                    errors['writeoff_approval_threshold'] = 'Cannot be negative.'
            except (TypeError, ValueError):
                errors['writeoff_approval_threshold'] = 'Must be a number.'
        if 'expiry_alert_days' in data:
            try:
                ladder = {int(v) for v in data['expiry_alert_days']}
            except (TypeError, ValueError):
                ladder = set()
            if not ladder or any(day < 1 or day > 365 for day in ladder):
                errors['expiry_alert_days'] = ('Provide 1–365 day offsets, '
                                               'e.g. [90, 60, 30, 14, 7, 1].')
        return errors

    def patch(self, request):

        if not has_capability(request, 'org.manage'):
            return Response(
                {'detail': 'Only tenant administrators can change inventory policy.'},
                status=status.HTTP_403_FORBIDDEN)
        errors = self._validate(request.data)
        if errors:
            return Response(errors, status=status.HTTP_400_BAD_REQUEST)
        obj = InventorySettings.get()
        editable = {
            'expiry_alert_days', 'auto_quarantine_expired', 'low_stock_notify',
            'stale_days', 'service_level', 'default_lead_time_days',
            'auto_draft_purchase_orders', 'forecast_days',
            'forecast_min_history_days', 'count_cadence_a', 'count_cadence_b',
            'count_cadence_c', 'valuation_method', 'writeoff_approval_threshold',
        }
        before = self._payload(obj)
        for field, value in request.data.items():
            if field not in editable:
                continue
            if field == 'expiry_alert_days':
                try:
                    value = sorted({int(v) for v in value}, reverse=True)
                except (TypeError, ValueError):
                    continue
            setattr(obj, field, value)
        obj.save()
        after = self._payload(obj)
        changes = {k: [before[k], after[k]] for k in before if before[k] != after[k]}
        if changes:
            _audit(request, 'settings_update', 'inventory-settings',
                   description='Updated inventory policy settings',
                   payload_diff={'changes': changes})
        return Response(after)


class StorageZoneViewSet(viewsets.ModelViewSet):
    """Cold-chain storage zones."""
    permission_classes = [InventoryPermission]
    pagination_class = None

    class Serializer(serializers.ModelSerializer):
        band = serializers.CharField(read_only=True)

        class Meta:
            model = StorageZone
            fields = ['id', 'name', 'code', 'min_temp_c', 'max_temp_c',
                      'requires_cold_chain', 'description', 'is_active',
                      'band', 'created_at']
            read_only_fields = ['id', 'band', 'created_at']

    serializer_class = Serializer

    def get_queryset(self):
        qs = StorageZone.objects.all()
        if self.request.query_params.get('active') in ('1', 'true'):
            qs = qs.filter(is_active=True)
        return qs
