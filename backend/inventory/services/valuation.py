"""Costing and month-end valuation (Tier 5).

Two things were missing before: a reproducible valuation figure for finance,
and any notion of *landed* cost (freight/duty spread across the lines).
"""
from __future__ import annotations

from decimal import Decimal

from django.db import transaction
from django.db.models import Sum
from django.utils import timezone

from ..models import (InventorySettings, InventorySnapshot,
                      InventorySnapshotLine, MedicationStock, StockBatch,
                      StockPolicy)


def _weighted_average_cost(stock) -> Decimal:
    """Value-weighted average of the units actually on hand.

    Falls back to ``stock.cost_price`` when the item has no live batch, so a
    fully depleted line still values at the last known cost.
    """
    rows = (StockBatch.objects
            .filter(stock=stock, quantity_remaining__gt=0)
            .values('quantity_remaining', 'cost_price_per_unit'))
    qty = sum(r['quantity_remaining'] or 0 for r in rows)
    if not qty:
        return Decimal(str(stock.cost_price or 0))
    value = sum((Decimal(str(r['cost_price_per_unit'] or 0))
                 * (r['quantity_remaining'] or 0)) for r in rows)
    return (value / Decimal(qty)).quantize(Decimal('0.01'))


def _fifo_cost(stock) -> Decimal:
    """Cost of the earliest-expiring live batch (FEFO ≈ FIFO for perishables)."""
    batch = (stock.batches
             .filter(quantity_remaining__gt=0)
             .order_by('expiry_date', 'received_date')
             .first())
    if batch:
        return Decimal(str(batch.cost_price_per_unit or 0))
    return Decimal(str(stock.cost_price or 0))


def stock_unit_cost(stock, method: str | None = None) -> Decimal:
    """Unit cost under the tenant's valuation method."""
    method = method or InventorySettings.get().valuation_method
    if method == InventorySettings.ValuationMethod.FIFO:
        return _fifo_cost(stock)
    if method == InventorySettings.ValuationMethod.BATCH_COST:
        return Decimal(str(stock.cost_price or 0))
    return _weighted_average_cost(stock)


def allocation_base(stock, method: str | None = None) -> Decimal:
    """Cost used when a unit leaves stock (issuing/POS)."""
    return stock_unit_cost(stock, method)


@transaction.atomic
def create_snapshot(*, period=None, method=None, user=None) -> InventorySnapshot:
    """Freeze a valuation snapshot for a period.

    Re-running for the same period replaces the previous figures rather
    than stacking duplicates.
    """
    settings_obj = InventorySettings.get()
    period = period or timezone.localdate().replace(day=1)
    method = method or settings_obj.valuation_method

    snapshot, _ = InventorySnapshot.objects.update_or_create(
        period=period, method=method,
        defaults={'created_by': user if user and getattr(user, 'is_authenticated', False) else None},
    )
    snapshot.lines.all().delete()

    stocks = MedicationStock.objects.with_quantities().select_related('policy')
    policy_abc = dict(StockPolicy.objects.values_list('stock_id', 'abc_class'))

    lines = []
    total_units = sku_count = 0
    total_cost = total_retail = expired_value = Decimal('0')

    for stock in stocks.iterator():
        qty = stock.total_quantity
        if qty <= 0:
            continue
        sku_count += 1
        unit_cost = stock_unit_cost(stock, method)
        line_value = (unit_cost * qty).quantize(Decimal('0.01'))
        total_units += qty
        total_cost += line_value
        total_retail += Decimal(str(stock.selling_price or 0)) * qty
        if stock.expired_quantity:
            expired_value += (unit_cost * stock.expired_quantity).quantize(Decimal('0.01'))
        lines.append(InventorySnapshotLine(
            snapshot=snapshot,
            stock=stock,
            medication_name=stock.medication_name,
            unit_cost=unit_cost,
            quantity=qty,
            value=line_value,
            abc_class=policy_abc.get(stock.id, ''),
        ))

    InventorySnapshotLine.objects.bulk_create(lines, batch_size=500)

    snapshot.total_units = total_units
    snapshot.sku_count = sku_count
    snapshot.total_cost_value = total_cost.quantize(Decimal('0.01'))
    snapshot.total_retail_value = total_retail.quantize(Decimal('0.01'))
    snapshot.expired_value = expired_value.quantize(Decimal('0.01'))
    snapshot.save(update_fields=['total_units', 'sku_count', 'total_cost_value',
                                 'total_retail_value', 'expired_value'])
    return snapshot


def valuation_summary(*, branch_id=None) -> dict:
    """Live (non-snapshotted) valuation under the tenant's method.

    ``branch_id`` scopes the figures to one warehouse; the insights screen used
    to show tenant-wide valuation beside branch-scoped KPIs.
    """
    method = InventorySettings.get().valuation_method
    stocks = MedicationStock.objects.with_quantities()
    if branch_id:
        stocks = stocks.filter(branch_id=branch_id)
    total_units = total_cost = total_retail = 0
    for stock in stocks.iterator():
        qty = stock.total_quantity
        if qty <= 0:
            continue
        total_units += qty
        total_cost += float(stock_unit_cost(stock, method)) * qty
        total_retail += float(stock.selling_price or 0) * qty
    return {
        'method': method,
        'total_units': total_units,
        'total_cost_value': round(total_cost, 2),
        'total_retail_value': round(total_retail, 2),
        'potential_profit': round(total_retail - total_cost, 2),
        'margin_pct': round((total_retail - total_cost) / total_retail * 100, 1)
        if total_retail else 0,
    }


def apply_landed_cost(po, *, freight=0, duty=0, insurance=0,
                      other=0) -> dict:
    """Spread landed costs across a PO's lines by value share.

    Writes the allocation onto ``po.items[*].landed_unit_cost`` and returns
    the per-line breakdown. It does **not** mutate stock costs directly —
    that would silently rewrite history; receiving uses the landed figure.
    """
    extras = Decimal(str(freight or 0)) + Decimal(str(duty or 0)) \
        + Decimal(str(insurance or 0)) + Decimal(str(other or 0))
    items = po.items or []
    line_values = [Decimal(str(i.get('qty') or 0)) * Decimal(str(i.get('unit_cost') or 0))
                   for i in items]
    total_value = sum(line_values, Decimal('0'))
    if not items or total_value <= 0 or extras <= 0:
        return {'applied': False, 'extra_cost': float(extras), 'lines': []}

    out = []
    for item, value in zip(items, line_values):
        share = value / total_value
        allocated = (extras * share).quantize(Decimal('0.01'))
        qty = Decimal(str(item.get('qty') or 0))
        landed_unit = (Decimal(str(item.get('unit_cost') or 0))
                       + (allocated / qty if qty else Decimal('0'))).quantize(Decimal('0.01'))
        item['landed_unit_cost'] = float(landed_unit)
        item['landed_cost'] = float(allocated)
        out.append({
            'name': item.get('name'),
            'qty': float(qty),
            'unit_cost': float(item.get('unit_cost') or 0),
            'landed_unit_cost': float(landed_unit),
            'allocated': float(allocated),
        })
    po.items = items
    po.save(update_fields=['items'])
    return {'applied': True, 'extra_cost': float(extras), 'lines': out}
