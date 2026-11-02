"""Planning engine: policies (ROP / safety stock / EOQ) and forecasts.

Run nightly by ``inventory.tasks`` and on demand from the planning API.
Everything is idempotent: running twice in a day produces the same rows.
"""
from __future__ import annotations

from datetime import timedelta

from django.db import transaction
from django.db.models import Sum
from django.utils import timezone

from ..models import (DemandForecast, InventorySettings, MedicationStock,
                      StockBatch, StockPolicy)
from . import forecasting
from .demand import stock_usage_summary

#: Cost assumptions for EOQ when the tenant has no explicit figures.
DEFAULT_ORDER_COST = 500.0          # KES per purchase order line
DEFAULT_HOLDING_RATE = 0.20         # 20 % of unit cost per year


def _measured_lead_time(supplier_id=None) -> tuple[float, float]:
    """Average and std-dev of PO → GRN days, optionally per supplier.

    Uses real receipts so the reorder point reflects the supplier's actual
    behaviour rather than the tenant-wide default.
    """
    try:
        from purchase_orders.models import GoodsReceivedNote
        qs = (GoodsReceivedNote.objects
              .filter(purchase_order__isnull=False,
                      purchase_order__order_date__isnull=False)
              .values_list('purchase_order__order_date', 'received_date'))
        if supplier_id:
            qs = qs.filter(purchase_order__supplier_id=supplier_id)
        deltas = [
            max(0.0, (received - ordered).days)
            for ordered, received in qs
            if ordered and received
        ]
    except Exception:
        deltas = []
    if not deltas:
        return 0.0, 0.0
    from statistics import fmean, pstdev
    return fmean(deltas), (pstdev(deltas) if len(deltas) > 1 else 0.0)


def refresh_policies(*, branch_id=None, days: int = 90) -> dict:
    """Recompute ``StockPolicy`` rows from actual demand and lead times.

    Returns a small summary dict for the task log / API response.
    """
    settings_obj = InventorySettings.get()
    usage = stock_usage_summary(days=days, branch_id=branch_id)

    stocks = (MedicationStock.objects
              .filter(is_active=True)
              .select_related('policy', 'branch'))
    if branch_id:
        stocks = stocks.filter(branch_id=branch_id)

    lead_default = float(settings_obj.default_lead_time_days or 14)
    measured_lt, measured_lt_sd = _measured_lead_time()

    # ABC needs the whole catalogue at once (value shares are relative).
    valued = list(stocks.values('id', 'cost_price'))
    totals = {row['id']: float(row['cost_price'] or 0) for row in valued}
    qty_map = dict(
        StockBatch.objects.filter(quantity_remaining__gt=0)
        .values('stock_id')
        .annotate(q=Sum('quantity_remaining'))
        .values_list('stock_id', 'q'))
    values = [totals.get(row['id'], 0) * (qty_map.get(row['id']) or 0)
              for row in valued]
    abc = forecasting.abc_classes(values)
    abc_by_stock = {row['id']: abc[i] for i, row in enumerate(valued)}
    total_value = sum(values) or 1.0

    updated = 0
    created = 0
    for stock in stocks.iterator():
        stats = usage.get(stock.id) or {
            'avg': 0.0, 'stddev': 0.0, 'cv': 0.0, 'total': 0.0}

        policy = getattr(stock, 'policy', None)
        if policy is None:
            policy = StockPolicy(stock=stock)
            created += 1

        if not policy.is_manual_lead_time:
            policy.lead_time_days = int(round(
                measured_lt or lead_default)) or 1
            policy.lead_time_stddev = round(measured_lt_sd, 2)
        if not policy.is_manual_service_level:
            policy.service_level = settings_obj.service_level

        policy.avg_daily_demand = round(float(stats['avg']), 4)
        policy.demand_stddev = round(float(stats['stddev']), 4)

        ss = forecasting.safety_stock(
            stats['avg'], stats['stddev'],
            policy.lead_time_days, policy.lead_time_stddev,
            policy.service_level)
        policy.safety_stock = ss

        if not policy.is_manual_reorder_point:
            policy.reorder_point = forecasting.reorder_point(
                stats['avg'], policy.lead_time_days, ss)

        annual = float(stats['avg']) * 365
        unit_cost = float(stock.cost_price or 0)
        holding = max(0.01, unit_cost * DEFAULT_HOLDING_RATE) if unit_cost else 1.0
        policy.eoq = forecasting.economic_order_quantity(
            annual, DEFAULT_ORDER_COST, holding)

        policy.abc_class = abc_by_stock.get(stock.id, 'C')
        policy.value_share = round(
            (totals.get(stock.id, 0) * (qty_map.get(stock.id) or 0)) / total_value, 4)
        policy.xyz_class = forecasting.classify_xyz(float(stats['cv']))

        # Min/max are derived quantities. They used to only ever *grow*
        # (``max(existing, new)``), so a few months of demand drift pushed the
        # replenishment target up forever and systematically over-ordered.
        # They are recomputed unless the planner pinned the reorder point.
        if not policy.is_manual_reorder_point:
            policy.min_qty = int(max(stock.reorder_level or 0,
                                     round(policy.reorder_point)))
            policy.max_qty = int(round(policy.reorder_point
                                       + (policy.eoq or stock.reorder_quantity or 0)))

        policy.save()
        updated += 1

    return {
        'policies_updated': updated,
        'policies_created': created,
        'measured_lead_time_days': round(measured_lt, 1),
    }


@transaction.atomic
def refresh_forecasts(*, branch_id=None, history_days: int = 120,
                      horizon_days: int | None = None) -> dict:
    """Persist ``horizon_days`` of forward forecasts per active stock item."""
    settings_obj = InventorySettings.get()
    horizon = int(horizon_days or settings_obj.forecast_days or 30)
    min_history = int(settings_obj.forecast_min_history_days or 14)

    usage = stock_usage_summary(days=history_days, branch_id=branch_id)
    stocks = MedicationStock.objects.filter(is_active=True)
    if branch_id:
        stocks = stocks.filter(branch_id=branch_id)

    today = timezone.localdate()
    written = 0
    methods = {}

    for stock in stocks.iterator():
        stats = usage.get(stock.id)
        if not stats:
            # No usage at all: a flat-zero forecast is still useful because it
            # powers the "no demand" / dead-stock insight.
            series = []
            history = 0
        else:
            series = stats['series']
            # History depth is the number of days since the item first moved,
            # not the length of the dense window. A catalogue item added
            # yesterday has 1 day of history, not 120 days of zeros — otherwise
            # every item "qualified" for Holt-Winters.
            first_use = next((i for i, v in enumerate(series) if v), None)
            history = (len(series) - first_use) if first_use is not None else 0
        method = forecasting.choose_method(history, min_history)
        projected = forecasting.forecast_series(series, method, horizon)
        methods[method] = methods.get(method, 0) + 1

        # Confidence: more history + lower variance = higher confidence. An item
        # with no history cannot be 99% confident just because its variance is 0.
        cv = float(stats['cv']) if stats else 1.0
        if not history:
            confidence = 0.05
        else:
            confidence = max(0.05, min(0.99,
                                      (min(history, 90) / 90) * (1 - min(cv, 1))))

        for step, predicted in enumerate(projected, start=1):
            if step > horizon:
                break
            DemandForecast.objects.update_or_create(
                stock=stock,
                branch=stock.branch,
                forecast_date=today + timedelta(days=step),
                defaults={
                    'horizon_days': step,
                    'predicted_qty': round(float(predicted), 4),
                    'method': method,
                    'confidence': round(confidence, 3),
                },
            )
            written += 1

    return {'forecasts_written': written, 'horizon_days': horizon,
            'methods': methods}


def backfill_forecast_accuracy(*, lookback_days: int = 30) -> dict:
    """Compare stored forecasts with what actually happened.

    Runs nightly so ``DemandForecast.mape`` stays meaningful — that number is
    what the S&OP screen shows as "forecast accuracy".
    """
    from collections import defaultdict

    from .demand import usage_by_stock

    today = timezone.localdate()
    start = today - timedelta(days=lookback_days)
    actuals = usage_by_stock(days=lookback_days + 1)

    scored = 0
    pending = (DemandForecast.objects
               .filter(forecast_date__gte=start, forecast_date__lt=today,
                       actual_qty__isnull=True)
               .select_related('stock'))

    for fc in pending.iterator():
        by_day = actuals.get(fc.stock_id, {})
        fc.actual_qty = round(float(by_day.get(fc.forecast_date, 0)), 4)
        fc.save(update_fields=['actual_qty'])
        scored += 1

    # Roll per-stock MAPE into the policy row for quick ranking.
    rows = defaultdict(lambda: [[], []])
    for fc in (DemandForecast.objects
               .filter(forecast_date__gte=start, forecast_date__lt=today,
                       actual_qty__isnull=False)
               .values('stock_id', 'predicted_qty', 'actual_qty')):
        rows[fc['stock_id']][0].append(float(fc['actual_qty'] or 0))
        rows[fc['stock_id']][1].append(float(fc['predicted_qty'] or 0))

    updated = 0
    for stock_id, (actual, predicted) in rows.items():
        value = forecasting.mape(actual, predicted)
        if value is None:
            continue
        StockPolicy.objects.filter(stock_id=stock_id).update(
            forecast_mape=round(value, 2))
        updated += 1

    return {'scored': scored, 'mape_updated': updated}
