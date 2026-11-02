"""Demand history extraction shared by forecasting, replenishment and KPIs.

All usage sources are normalised into a single stream of
``(stock_id, date, units_out)`` tuples so the same numbers feed the
forecast, the reorder point and the turns calculation. Previously each
screen re-derived demand and they disagreed.
"""
from __future__ import annotations

from collections import defaultdict
from datetime import date, timedelta

from django.db.models import Sum
from django.utils import timezone


def _window_start(days: int) -> date:
    return timezone.localdate() - timedelta(days=max(1, days) - 1)


def _window(days: int, date_from=None, date_to=None) -> tuple[date, date]:
    """Resolve a ``(start, end)`` window.

    An explicit ``date_from``/``date_to`` always wins over the rolling ``days``
    count, so callers that report on an arbitrary period (ABC/XYZ, movements)
    read exactly the range the user asked for. A reversed range is normalised
    rather than returning nothing.
    """
    end = date_to or timezone.localdate()
    start = date_from or (end - timedelta(days=max(1, days) - 1))
    if start > end:
        start, end = end, start
    return start, end


#: Adjustment reasons that record a *loss of goods*, not customer demand.
LOSS_REASONS = ('damage', 'theft', 'expiry', 'return_to_supplier')


def usage_by_stock(days: int = 90, branch_id=None, *, date_from=None,
                   date_to=None) -> dict[int, dict[date, float]]:
    """Return ``{stock_id: {date: units_out}}`` over the window.

    Combines POS sales, dispensing, sales orders and negative stock
    adjustments. Transfer lines are **not** usage — the goods still exist,
    they merely moved warehouse.
    """
    start, end = _window(days, date_from, date_to)
    out: dict[int, dict[date, float]] = defaultdict(lambda: defaultdict(float))

    # ── POS sales ───────────────────────────────────────────────────────
    try:
        from pos.models import TransactionItem
        qs = (TransactionItem.objects
              .filter(transaction__status='completed',
                      transaction__created_at__date__gte=start,
                      transaction__created_at__date__lte=end,
                      stock__isnull=False)
              .values('stock_id', 'transaction__created_at'))
        if branch_id:
            qs = qs.filter(transaction__branch_id=branch_id)
        for row in qs:
            d = timezone.localtime(row['transaction__created_at']).date()
            out[row['stock_id']][d] += float(row.get('quantity') or 0)
    except Exception:
        pass

    # ── Sales orders (fulfilment is also mirrored as an adjustment below,
    #    so they are counted once via the adjustment stream only) ────────

    # ── Dispensing (JSON items — scan the window) ───────────────────────
    try:
        from dispensing.models import DispensingRecord
        qs = (DispensingRecord.objects
              .filter(status='completed',
                      dispensed_at__date__gte=start,
                      dispensed_at__date__lte=end)
              .only('dispensed_at', 'items_dispensed'))
        for rec in qs:
            d = timezone.localtime(rec.dispensed_at).date() if rec.dispensed_at else None
            if not d:
                continue
            for item in (rec.items_dispensed or []):
                sid = item.get('stock_id')
                if sid:
                    out[int(sid)][d] += float(item.get('qty') or 0)
    except Exception:
        pass

    # ── Negative adjustments (sales-order fulfilment, losses) ───────────
    try:
        from inventory.models import CHANNEL_ADJUSTMENT_REASONS, StockAdjustment
        qs = (StockAdjustment.objects
              .filter(created_at__date__gte=start,
                      created_at__date__lte=end,
                      quantity_change__lt=0)
              .values('stock_id', 'created_at', 'quantity_change', 'reason'))
        for row in qs:
            d = timezone.localtime(row['created_at']).date()
            if row['reason'] == 'count_correction':
                # A cycle-count correction is error, not demand.
                continue
            if row['reason'] in CHANNEL_ADJUSTMENT_REASONS:
                # POS sales and dispensing are read from their own records
                # above; their ledger rows would count the units twice.
                continue
            if row['reason'] in LOSS_REASONS:
                # Damage, theft, expiry and returns to the supplier are losses,
                # not demand. Counting them inflated the average daily demand
                # (and therefore the reorder point, safety stock and forecast)
                # for items that simply got written off.
                continue
            out[row['stock_id']][d] += abs(float(row['quantity_change'] or 0))
    except Exception:
        pass

    return out


def stock_usage_summary(days: int = 90, branch_id=None, *, date_from=None,
                        date_to=None) -> dict[int, dict]:
    """Per-stock totals: sum, daily average and standard deviation.

    Uses a dense daily series so a slow-moving item is not overstated.
    """
    from .forecasting import daily_series, summarise_series

    start, end = _window(days, date_from, date_to)
    raw = usage_by_stock(branch_id=branch_id, date_from=start, date_to=end)

    summary: dict[int, dict] = {}
    for stock_id, by_day in raw.items():
        series = daily_series(
            [(d, q) for d, q in by_day.items()], start, end)
        stats = summarise_series(series)
        stats['series'] = series
        stats['start'] = start
        stats['end'] = end
        summary[stock_id] = stats
    return summary


def last_movement_at(days: int = 400) -> dict[int, date]:
    """Most recent usage date per stock (for stale-stock detection)."""
    raw = usage_by_stock(days=days)
    return {
        stock_id: max(by_day) for stock_id, by_day in raw.items() if by_day
    }
