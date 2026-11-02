"""Executive inventory KPIs (Tier 7).

The metrics finance and operations ask for, computed from real movement data:

* **Inventory turns** — COGS ÷ average inventory value (annualised).
* **DIO** — days inventory outstanding (365 ÷ turns).
* **GMROI** — gross margin ÷ average inventory cost.
* **Fill rate / stockout rate** — service performance.
* **Excess & obsolete** — value by age band since last movement.

All queries use ``with_quantities()`` so a 5 000-item catalogue still
resolves in a handful of SQL round-trips.
"""
from __future__ import annotations

from datetime import timedelta

from django.db.models import Sum
from django.utils import timezone

from ..models import InventorySettings, InventorySnapshot, MedicationStock, StockBatch
from .valuation import stock_unit_cost

AGE_BANDS = [(0, 30), (31, 90), (91, 180), (181, 365), (366, None)]


def cogs(*, days: int = 90, branch_id=None) -> float:
    """Cost of goods moved out of stock over the window.

    Counts POS sales, dispensing, sales-order fulfilment and negative
    adjustments (excluding cycle-count corrections, which are error, not
    demand).

    Each unit is valued at the **cost of the lot that left stock** where the
    ledger row knows it, falling back to the item's cost price. Valuing history
    at ``stock.cost_price`` meant last quarter's COGS silently changed every
    time a new purchase order updated the price.
    """
    start = timezone.localdate() - timedelta(days=days)
    total = 0.0

    def _unit_cost(row) -> float:
        return float(row.get('batch__cost_price_per_unit')
                     or row.get('stock__cost_price') or 0)

    try:
        from pos.models import TransactionItem
        qs = (TransactionItem.objects
              .filter(transaction__status='completed',
                      transaction__created_at__date__gte=start,
                      stock__isnull=False)
              .values('quantity', 'stock__cost_price',
                      'batch__cost_price_per_unit'))
        if branch_id:
            qs = qs.filter(transaction__branch_id=branch_id)
        total += sum(float(r['quantity'] or 0) * _unit_cost(r) for r in qs)
    except Exception:
        pass

    try:
        from inventory.models import CHANNEL_ADJUSTMENT_REASONS, StockAdjustment
        qs = (StockAdjustment.objects
              .filter(created_at__date__gte=start, quantity_change__lt=0)
              .exclude(reason='count_correction')
              .exclude(reason__in=CHANNEL_ADJUSTMENT_REASONS)
              .values('quantity_change', 'stock__cost_price',
                      'batch__cost_price_per_unit', 'stock_id', 'reason'))
        if branch_id:
            qs = qs.filter(stock__branch_id=branch_id)
        # Every remaining reason is a genuine write-out: sales-order fulfilment,
        # damage, theft, expiry and returns to the supplier all remove units the
        # business paid for. (Sales orders do *not* also appear in POS, so they
        # must be counted here.)
        total += sum(abs(float(r['quantity_change'] or 0)) * _unit_cost(r)
                     for r in qs)
    except Exception:
        pass

    return round(total, 2)


def inventory_value(*, branch_id=None) -> dict:
    """Current inventory value at cost and retail."""
    method = InventorySettings.get().valuation_method
    stocks = MedicationStock.objects.with_quantities().select_related('branch')
    if branch_id:
        stocks = stocks.filter(branch_id=branch_id)
    cost = retail = 0.0
    for stock in stocks.iterator():
        qty = stock.total_quantity
        if qty <= 0:
            continue
        cost += float(stock_unit_cost(stock, method)) * qty
        retail += float(stock.selling_price or 0) * qty
    return {'cost': round(cost, 2), 'retail': round(retail, 2),
            'margin': round(retail - cost, 2)}


def _average_inventory(*, days: int = 90, branch_id=None) -> float:
    """Simple average of snapshot values, falling back to live value."""
    snaps = list(InventorySnapshot.objects
                 .filter(period__gte=timezone.localdate() - timedelta(days=days))
                 .values_list('total_cost_value', flat=True))
    if snaps:
        return round(sum(float(s) for s in snaps) / len(snaps), 2)
    return inventory_value(branch_id=branch_id)['cost']


def kpi_dashboard(*, days: int = 90, branch_id=None) -> dict:
    """The full executive KPI bundle."""
    window_cogs = cogs(days=days, branch_id=branch_id)
    value = inventory_value(branch_id=branch_id)
    avg_inv = _average_inventory(days=days, branch_id=branch_id) or value['cost'] or 1.0

    annual_cogs = window_cogs * (365 / days) if days else window_cogs
    turns = round(annual_cogs / avg_inv, 2) if avg_inv else 0
    dio = round(365 / turns, 1) if turns else None
    gross_margin = value['retail'] - value['cost']
    gmroi = round(gross_margin / avg_inv, 2) if avg_inv else 0

    # Service: SKUs that are fully out of sellable stock.
    stocks = MedicationStock.objects.with_quantities().filter(is_active=True)
    if branch_id:
        stocks = stocks.filter(branch_id=branch_id)
    rows = list(stocks)
    skus = len(rows)
    out = sum(1 for s in rows if s.sellable_quantity <= 0)
    fill_rate = round((skus - out) / skus * 100, 1) if skus else 100.0

    band_data = excess_by_age(branch_id=branch_id)

    return {
        'window_days': days,
        'cogs': window_cogs,
        'inventory_value_cost': value['cost'],
        'inventory_value_retail': value['retail'],
        'gross_margin': round(gross_margin, 2),
        'avg_inventory': avg_inv,
        'turns': turns,
        'dio_days': dio,
        'gmroi': gmroi,
        'skus': skus,
        'out_of_stock': out,
        'fill_rate_pct': fill_rate,
        'excess_obsolete': band_data,
    }


def excess_by_age(*, branch_id=None) -> dict:
    """Value sitting in each age band since last movement.

    "Excess & obsolete" is normally reported as 90+/180+/365+ buckets, so
    the bands are returned individually as well as the total.
    """
    from .demand import last_movement_at

    today = timezone.localdate()
    last_move = last_movement_at(days=400)

    stocks = MedicationStock.objects.with_quantities().select_related('branch')
    if branch_id:
        stocks = stocks.filter(branch_id=branch_id)

    bands = {f'{lo}-{hi}' if hi else f'{lo}+': {'qty': 0, 'value': 0.0,
                                                'skus': 0}
             for lo, hi in AGE_BANDS}
    total_value = 0.0
    excess_value = 0.0

    for stock in stocks.iterator():
        qty = stock.total_quantity
        if qty <= 0:
            continue
        unit_cost = float(stock_unit_cost(stock))
        value = unit_cost * qty
        total_value += value

        moved = last_move.get(stock.id)
        reference = moved or (stock.created_at.date() if stock.created_at else today)
        age = (today - reference).days

        for lo, hi in AGE_BANDS:
            if age >= lo and (hi is None or age <= hi):
                key = f'{lo}-{hi}' if hi else f'{lo}+'
                bands[key]['qty'] += qty
                bands[key]['value'] += value
                bands[key]['skus'] += 1
                if lo >= 91:
                    excess_value += value
                break

    return {
        'bands': [
            {'band': k, 'qty': v['qty'], 'value': round(v['value'], 2),
             'skus': v['skus']}
            for k, v in bands.items()
        ],
        'total_value': round(total_value, 2),
        'excess_value': round(excess_value, 2),
        'excess_pct': round(excess_value / total_value * 100, 1) if total_value else 0,
    }


def service_level(*, days: int = 30, branch_id=None) -> dict:
    """Stockout incidence over the window (proxy for service level)."""
    from inventory.models import StockAdjustment

    start = timezone.localdate() - timedelta(days=days)
    stocks = MedicationStock.objects.with_quantities().filter(is_active=True)
    if branch_id:
        stocks = stocks.filter(branch_id=branch_id)
    rows = list(stocks)
    out_today = sum(1 for s in rows if s.sellable_quantity <= 0)

    replenished = (StockAdjustment.objects
                   .filter(created_at__date__gte=start, quantity_change__gt=0)
                   .values('stock_id').distinct().count())

    return {
        'window_days': days,
        'skus': len(rows),
        'out_of_stock_now': out_today,
        'stockout_rate_pct': round(out_today / len(rows) * 100, 1) if rows else 0,
        'skus_replenished': replenished,
    }


def whats_if(service_level_pct: int, *, days: int = 90,
             branch_id=None) -> dict:
    """Cost of changing the target service level across the catalogue.

    Recomputes safety stock with the new z-value and reports the delta in
    capital tied up — the "what does 98% cost me?" question.
    """
    from .forecasting import safety_stock

    from ..models import StockPolicy

    policies = StockPolicy.objects.select_related('stock')
    if branch_id:
        policies = policies.filter(stock__branch_id=branch_id)

    extra_units = 0.0
    extra_value = 0.0
    for policy in policies.iterator():
        current = float(policy.safety_stock or 0)
        proposed = safety_stock(
            policy.avg_daily_demand, policy.demand_stddev,
            policy.lead_time_days or 1, policy.lead_time_stddev,
            service_level_pct)
        delta = proposed - current
        if delta > 0:
            extra_units += delta
            extra_value += delta * float(policy.stock.cost_price or 0)

    return {
        'service_level_pct': service_level_pct,
        'extra_units': round(extra_units, 1),
        'extra_capital': round(extra_value, 2),
        'basis_days': days,
    }
