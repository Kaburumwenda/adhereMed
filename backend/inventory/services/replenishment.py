"""Replenishment engine (Tier 1 flagship).

Produces ``purchase_orders.ReorderSuggestion`` rows from **sellable**
quantity, the statistical reorder point and the EOQ — then optionally
drafts one ``PurchaseOrder`` per supplier.

Why this replaced the old ``generate`` action:

* it read ``total_quantity``, so a shelf of expired stock suppressed a
  genuine shortage;
* the suggested quantity was ``max(reorder*2, reorder - qty)`` — pure
  guesswork with no velocity, no lead time and no pack rounding;
* it had to be clicked manually, and nothing ever turned a suggestion
  into an actual order.
"""
from __future__ import annotations

import uuid
from collections import defaultdict
from datetime import timedelta

from django.db import transaction
from django.db.models import Q
from django.utils import timezone

from ..models import InventorySettings, MedicationStock, StockPolicy
from .forecasting import round_to_multiple

#: Suggestion statuses (mirrors purchase_orders.ReorderSuggestion choices).
PENDING = 'pending'
ORDERED = 'ordered'
DISMISSED = 'dismissed'


def _preferred_supplier(stock):
    """Cheapest active supplier item for this stock, else None.

    ``supplier_items`` is a *reverse* FK (SupplierItem → MedicationStock), so it
    must be ``prefetch_related``-ed rather than ``select_related``-ed. Reading
    ``.all()`` here hits the prefetch cache when one is present.
    """
    try:
        rows = [si for si in stock.supplier_items.all()
                if si.supplier is not None and si.supplier.is_active]
        if not rows:
            return None, stock.cost_price
        best = min(rows, key=lambda si: (si.unit_cost or 0, si.id))
        return best.supplier, best.unit_cost
    except Exception:
        return None, stock.cost_price


def _severity(days_cover: float | None, on_hand: float) -> str:
    if on_hand <= 0:
        return 'out'
    if days_cover is None:
        return 'unplanned'
    if days_cover <= 7:
        return 'critical'
    if days_cover <= 14:
        return 'high'
    if days_cover <= 30:
        return 'watch'
    return 'ok'


def build_suggestions(*, branch_id=None, include_watch: bool = True,
                      write: bool = True) -> dict:
    """Compute replenishment needs and (optionally) persist them.

    Returns a payload with the rows so the API can render the screen even
    when nothing is written.
    """
    settings_obj = InventorySettings.get()
    from purchase_orders.models import ReorderSuggestion

    stocks = (MedicationStock.objects
              .filter(is_active=True)
              .select_related('policy', 'branch', 'unit')
              .prefetch_related('supplier_items__supplier')
              .with_quantities())
    if branch_id:
        stocks = stocks.filter(branch_id=branch_id)

    # Anything already on an open purchase order should not be re-ordered.
    outstanding = _outstanding_on_order(branch_id)

    rows = []
    created = updated = 0
    today = timezone.localdate()

    for stock in stocks:
        policy = getattr(stock, 'policy', None)
        # ``available`` = sellable − committed. Using the raw sellable figure
        # ignored paid sales orders that have already reserved units, so an
        # item could look healthy while every unit was promised to a customer.
        on_hand = stock.available_quantity
        avg = float(policy.avg_daily_demand) if policy else 0.0
        # A policy's statistical ROP is 0 for a zero-demand item; never let it
        # override a reorder level the planner typed in by hand.
        rop = max(float(policy.reorder_point) if policy else 0.0,
                  float(stock.reorder_level or 0))
        eoq = float(policy.eoq) if policy else 0.0
        lead = int(policy.lead_time_days) if policy else settings_obj.default_lead_time_days

        if policy and policy.is_quarantined:
            continue          # recalled / quarantined stock is not replenished

        # Trigger: below ROP, or nothing sellable at all.
        if on_hand > rop and on_hand > 0:
            continue

        already = outstanding.get(stock.id, 0)
        target = max(
            float(policy.max_qty) if policy and policy.max_qty else rop * 2,
            rop + eoq if eoq else rop * 2,
        )
        shortfall = max(0.0, target - (on_hand + already))
        if shortfall <= 0:
            continue

        multiple = int(policy.order_multiple) if policy else 1
        quantity = round_to_multiple(shortfall, multiple) or round_to_multiple(rop, multiple)
        if quantity <= 0:
            continue

        days_cover = round(on_hand / avg, 1) if avg > 0 else None
        severity = _severity(days_cover, on_hand)
        if not include_watch and severity in ('watch', 'ok'):
            continue

        supplier, unit_cost = _preferred_supplier(stock)
        estimated = round(float(quantity) * float(unit_cost or 0), 2)

        row = {
            'stock_id': stock.id,
            'medication_name': stock.medication_name,
            'unit': stock.unit.abbreviation if stock.unit else '',
            'branch_id': stock.branch_id,
            'branch_name': stock.branch.name if stock.branch else '',
            'on_hand': on_hand,
            'on_order': already,
            'reorder_point': round(rop, 1),
            'avg_daily_demand': round(avg, 2),
            'days_cover': days_cover,
            'suggested_quantity': int(quantity),
            'order_multiple': multiple,
            'unit_cost': float(unit_cost or 0),
            'estimated_cost': estimated,
            'supplier_id': supplier.id if supplier else None,
            'supplier_name': supplier.name if supplier else '',
            'lead_time_days': lead,
            'severity': severity,
            'abc_class': policy.abc_class if policy else 'C',
            'reason': _reason(on_hand, rop, days_cover, already),
        }
        rows.append(row)

        if not write:
            continue

        # Reuse the existing model so procurement screens keep working.
        obj, is_new = ReorderSuggestion.objects.update_or_create(
            stock=stock,
            status=PENDING,
            defaults={
                'current_quantity': on_hand,
                'reorder_level': rop,
                'suggested_quantity': quantity,
                'recommended_supplier': supplier,
                'last_unit_cost': float(unit_cost or 0),
                'estimated_cost': estimated,
                'branch_id': stock.branch_id,
            },
        )
        created += 1 if is_new else 0
        updated += 0 if is_new else 1

    rows.sort(key=lambda r: (
        {'out': 0, 'critical': 1, 'high': 2, 'watch': 3,
         'unplanned': 4, 'ok': 5}.get(r['severity'], 9),
        -(r['estimated_cost'] or 0),
    ))

    # Suggestions whose stock is now healthy should not linger.
    if write:
        stale = ReorderSuggestion.objects.filter(status=PENDING).exclude(
            stock_id__in=[r['stock_id'] for r in rows])
        if branch_id:
            # A scoped run owns its warehouse only — deleting unfiltered used to
            # wipe every other branch's pending plan.
            stale = stale.filter(Q(branch_id=branch_id) | Q(stock__branch_id=branch_id))
        stale.delete()

    return {
        'rows': rows,
        'summary': {
            'lines': len(rows),
            'estimated_cost': round(sum(r['estimated_cost'] for r in rows), 2),
            'out': sum(1 for r in rows if r['severity'] == 'out'),
            'critical': sum(1 for r in rows if r['severity'] == 'critical'),
            'created': created,
            'updated': updated,
            'as_of': today.isoformat(),
        },
    }


def _reason(on_hand, rop, days_cover, on_order) -> str:
    if on_hand <= 0:
        return 'Out of sellable stock'
    if days_cover is not None and days_cover <= 7:
        return f'Only {days_cover:g} day(s) of cover left'
    if on_order:
        return f'Below reorder point ({on_order:g} already on order)'
    return f'Below reorder point of {rop:g}'


def _outstanding_on_order(branch_id=None) -> dict[int, float]:
    """Units already ordered but not yet received, per stock item."""
    from purchase_orders.models import PurchaseOrder

    out = defaultdict(float)
    qs = (PurchaseOrder.objects
          .filter(status__in=[PurchaseOrder.Status.DRAFT,
                              PurchaseOrder.Status.SENT,
                              PurchaseOrder.Status.PARTIAL])
          .only('items', 'branch_id'))
    if branch_id:
        qs = qs.filter(branch_id=branch_id)
    for po in qs:
        for item in (po.items or []):
            sid = item.get('medication_stock_id') or item.get('stock_id')
            if not sid:
                continue
            try:
                out[int(sid)] += float(item.get('qty') or 0)
            except (TypeError, ValueError):
                continue
    return out


@transaction.atomic
def draft_purchase_orders(*, branch_id=None, user=None,
                          min_severity: str = 'high') -> dict:
    """Turn pending suggestions into DRAFT purchase orders, one per supplier.

    Drafts are never sent — a human still approves them. Items without a
    supplier are reported back so the planner can assign one.
    """
    from purchase_orders.models import PurchaseOrder, ReorderSuggestion

    allowed = {'out', 'critical', 'high'}
    if min_severity == 'out':
        allowed = {'out'}
    elif min_severity == 'critical':
        allowed = {'out', 'critical'}
    elif min_severity == 'watch':
        allowed = {'out', 'critical', 'high', 'watch'}

    payload = build_suggestions(branch_id=branch_id, write=False)
    urgent = [r for r in payload['rows'] if r['severity'] in allowed]
    candidates = [r for r in urgent if r['supplier_id']]
    no_supplier = [r for r in urgent if not r['supplier_id']]

    if not candidates:
        return {'purchase_orders': [],
                'skipped_no_supplier': len(no_supplier),
                'unsupplied': [
                    {'stock_id': r['stock_id'], 'name': r['medication_name'],
                     'branch_name': r['branch_name'],
                     'suggested_quantity': r['suggested_quantity'],
                     'severity': r['severity']}
                    for r in no_supplier
                ]}

    by_supplier = defaultdict(list)
    for row in candidates:
        by_supplier[row['supplier_id']].append(row)

    created = []
    for supplier_id, rows in by_supplier.items():
        items = []
        total = 0.0
        for row in rows:
            line_total = float(row['suggested_quantity']) * float(row['unit_cost'] or 0)
            total += line_total
            items.append({
                'medication_stock_id': row['stock_id'],
                'name': row['medication_name'],
                'qty': row['suggested_quantity'],
                'unit_cost': float(row['unit_cost'] or 0),
                'total': round(line_total, 2),
                'auto_generated': True,
                'reason': row['reason'],
            })

        po = PurchaseOrder.objects.create(
            po_number=f'AUTO-{uuid.uuid4().hex[:8].upper()}',
            supplier_id=supplier_id,
            items=items,
            total_cost=round(total, 2),
            status=PurchaseOrder.Status.DRAFT,
            branch_id=branch_id or (rows[0]['branch_id'] if rows else None),
            ordered_by=user if user and getattr(user, 'is_authenticated', False) else None,
            notes='Auto-drafted by nightly replenishment. Review before sending.',
        )
        created.append({
            'id': po.id,
            'po_number': po.po_number,
            'supplier_id': supplier_id,
            'supplier_name': rows[0]['supplier_name'],
            'lines': len(items),
            'total_cost': float(po.total_cost),
        })
        ReorderSuggestion.objects.filter(
            stock_id__in=[r['stock_id'] for r in rows],
            status=PENDING).update(status=ORDERED)

    return {'purchase_orders': created,
            'skipped_no_supplier': len(no_supplier),
            'unsupplied': [
                {'stock_id': r['stock_id'], 'name': r['medication_name'],
                 'branch_name': r['branch_name'],
                 'suggested_quantity': r['suggested_quantity'],
                 'severity': r['severity']}
                for r in no_supplier
            ]}


def apply_policy_to_suggestions(*, branch_id=None) -> dict:
    """Refresh suggestions after a policy/price change (manual trigger)."""
    return build_suggestions(branch_id=branch_id, write=True)


def days_of_cover(stock, avg_daily: float | None = None) -> float | None:
    """Days until the item runs out at its current run-rate.

    Uses *available* units (sellable − committed), matching the reorder point.
    """
    if avg_daily is None:
        policy = getattr(stock, 'policy', None)
        avg_daily = float(policy.avg_daily_demand) if policy else 0.0
    if not avg_daily:
        return None
    return round(stock.available_quantity / avg_daily, 1)


# ══════════════════════════════════════════════════════════════════════════
#  Reviewed purchase-order drafting (the "Draft purchase orders" workbench)
# ══════════════════════════════════════════════════════════════════════════
class DraftError(ValueError):
    """Raised when a reviewed draft payload cannot be turned into POs."""


def _po_number() -> str:
    return f'AUTO-{uuid.uuid4().hex[:8].upper()}'


@transaction.atomic
def create_purchase_orders(groups, *, user=None, branch_id=None,
                           notes: str = '') -> dict:
    """Create DRAFT purchase orders from an **explicitly reviewed** payload.

    Unlike :func:`draft_purchase_orders` (which re-derives the plan), this
    trusts the caller's edits — a planner may have changed quantities, typed a
    negotiated price, or assigned a supplier to an item that had none. So every
    value is still validated here, because the client must never be able to
    inject a negative quantity or an unknown stock id.

    ``groups`` shape::

        [{
          'supplier_id': 4,
          'items': [{'stock_id': 12, 'name': 'Paracetamol', 'qty': 600,
                     'unit_cost': 9.5}],
        }, …]

    Returns ``{'purchase_orders': [...], 'lines': n, 'total_cost': x,
    'skipped': [...]}``. ``skipped`` lists lines dropped by validation with a
    reason, so the UI can tell the planner exactly what did not make it.
    """
    from purchase_orders.models import PurchaseOrder, ReorderSuggestion
    from suppliers.models import Supplier

    from ..models import MedicationStock

    if not groups:
        raise DraftError('Select at least one line to order.')

    # Everything must belong to a warehouse the user may buy for.
    scope_branch = branch_id

    created = []
    skipped = []
    touched_stock_ids = []

    for group in groups:
        supplier_id = group.get('supplier_id')
        items_in = group.get('items') or []
        if not supplier_id:
            skipped.append({'reason': 'No supplier selected',
                            'items': [i.get('name') for i in items_in]})
            continue
        supplier = Supplier.objects.filter(id=supplier_id, is_active=True).first()
        if not supplier:
            skipped.append({'reason': f'Supplier {supplier_id} not found or inactive',
                            'items': [i.get('name') for i in items_in]})
            continue

        lines = []
        total = 0.0
        group_branch = None

        for item in items_in:
            stock_id = item.get('stock_id')
            if not stock_id:
                skipped.append({'reason': 'Line has no stock id',
                                'items': [item.get('name')]})
                continue
            stock = (MedicationStock.objects
                     .select_related('unit', 'branch')
                     .filter(id=stock_id).first())
            if stock is None:
                skipped.append({'reason': f'Stock item {stock_id} no longer exists',
                                'items': [item.get('name')]})
                continue
            if scope_branch and stock.branch_id != int(scope_branch):
                skipped.append({
                    'reason': 'Item belongs to another warehouse',
                    'items': [stock.medication_name]})
                continue

            try:
                qty = int(float(item.get('qty') or 0))
            except (TypeError, ValueError):
                qty = 0
            if qty <= 0:
                skipped.append({'reason': 'Quantity must be greater than zero',
                                'items': [stock.medication_name]})
                continue

            try:
                unit_cost = float(item.get('unit_cost') or 0)
            except (TypeError, ValueError):
                unit_cost = 0.0
            if unit_cost < 0:
                skipped.append({'reason': 'Unit cost cannot be negative',
                                'items': [stock.medication_name]})
                continue

            line_total = round(qty * unit_cost, 2)
            total += line_total
            group_branch = group_branch or stock.branch_id
            lines.append({
                'medication_stock_id': stock.id,
                'name': stock.medication_name,
                'strength': stock.strength or '',
                'unit': stock.unit.abbreviation if stock.unit else '',
                'qty': qty,
                'unit_cost': round(unit_cost, 2),
                'total': line_total,
                'auto_generated': True,
                'reason': item.get('reason') or '',
            })
            touched_stock_ids.append(stock.id)

        if not lines:
            skipped.append({'reason': f'No valid lines for {supplier.name}',
                            'items': []})
            continue

        po = PurchaseOrder.objects.create(
            po_number=_po_number(),
            supplier=supplier,
            items=lines,
            total_cost=round(total, 2),
            status=PurchaseOrder.Status.DRAFT,
            branch_id=group_branch or scope_branch,
            ordered_by=user if user and getattr(user, 'is_authenticated', False) else None,
            notes=notes or 'Drafted from the replenishment workbench. Review before sending.',
        )
        created.append({
            'id': po.id,
            'po_number': po.po_number,
            'supplier_id': supplier.id,
            'supplier_name': supplier.name,
            'lines': len(lines),
            'total_cost': float(po.total_cost),
        })

    if touched_stock_ids:
        ReorderSuggestion.objects.filter(
            stock_id__in=touched_stock_ids, status=PENDING).update(status=ORDERED)

    return {
        'purchase_orders': created,
        'lines': sum(c['lines'] for c in created),
        'total_cost': round(sum(c['total_cost'] for c in created), 2),
        'skipped': skipped,
    }


def link_supplier_item(*, supplier_id, stock_id, unit_cost=None,
                       item_name: str = '') -> dict:
    """Attach a supplier to a stock item so it can be ordered.

    The replenishment workbench lets a planner resolve "no supplier" lines
    inline; this creates (or updates) the ``SupplierItem`` link and returns the
    row shape the table expects.
    """
    from suppliers.models import Supplier, SupplierItem

    from ..models import MedicationStock

    stock = MedicationStock.objects.filter(id=stock_id).first()
    if stock is None:
        raise DraftError('Stock item not found.')
    supplier = Supplier.objects.filter(id=supplier_id, is_active=True).first()
    if supplier is None:
        raise DraftError('Supplier not found or inactive.')

    try:
        cost = float(unit_cost) if unit_cost not in (None, '') else float(stock.cost_price or 0)
    except (TypeError, ValueError):
        cost = float(stock.cost_price or 0)
    if cost < 0:
        raise DraftError('Unit cost cannot be negative.')

    item, created = SupplierItem.objects.update_or_create(
        supplier=supplier, stock=stock,
        defaults={'item_name': item_name or stock.medication_name,
                  'unit_cost': cost},
    )
    return {
        'id': item.id,
        'created': created,
        'supplier_id': supplier.id,
        'supplier_name': supplier.name,
        'unit_cost': float(item.unit_cost or 0),
        'stock_id': stock.id,
    }


# ══════════════════════════════════════════════════════════════════════════
#  Request for Quotation from the replenishment plan
# ══════════════════════════════════════════════════════════════════════════
@transaction.atomic
def create_rfq(*, rows, supplier_ids, user=None, branch_id=None,
               title: str = '', response_deadline=None,
               expected_delivery=None, notes: str = '') -> dict:
    """Open an RFQ for selected replenishment lines and invite suppliers.

    Pre-creates a pending :class:`RFQQuote` per invited supplier so the
    comparison grid has its columns ready the moment a price lands — a planner
    should never have to remember which suppliers were asked.
    """
    from purchase_orders.models import (RFQQuote, RequestForQuotation)
    from suppliers.models import Supplier

    if not rows:
        raise DraftError('Select at least one item to quote.')

    suppliers = list(Supplier.objects.filter(id__in=supplier_ids or [], is_active=True))
    if not suppliers:
        raise DraftError('Choose at least one supplier to invite.')

    items = []
    for row in rows:
        try:
            qty = int(float(row.get('qty') or 0))
        except (TypeError, ValueError):
            qty = 0
        if qty <= 0:
            continue
        items.append({
            'medication_stock_id': row.get('stock_id'),
            'name': row.get('name') or '',
            'qty': qty,
            'unit': row.get('unit') or '',
            'target_unit_cost': float(row.get('unit_cost') or 0),
        })
    if not items:
        raise DraftError('None of the selected items has a quantity above zero.')

    rfq = RequestForQuotation.objects.create(
        rfq_number=f'RFQ-{timezone.now():%Y%m}-{uuid.uuid4().hex[:8].upper()}',
        title=title or f'Replenishment quote — {timezone.localdate():%d %b %Y}',
        description=notes,
        items=items,
        status=RequestForQuotation.Status.DRAFT,
        expected_delivery=expected_delivery or None,
        response_deadline=response_deadline or None,
        created_by=user if user and getattr(user, 'is_authenticated', False) else None,
        branch_id=branch_id or None,
        notes=notes,
    )

    invited = []
    for supplier in suppliers:
        quote, _ = RFQQuote.objects.get_or_create(rfq=rfq, supplier=supplier)
        invited.append({
            'supplier_id': supplier.id,
            'supplier_name': supplier.name,
            # The placeholder quote id lets the client PATCH the bid into the
            # existing row instead of POSTing (rfq, supplier) twice, which the
            # unique constraint forbids.
            'quote_id': quote.id,
        })

    return {
        'id': rfq.id,
        'rfq_number': rfq.rfq_number,
        'title': rfq.title,
        'status': rfq.status,
        'lines': len(items),
        'invited': invited,
    }
