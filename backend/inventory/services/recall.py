"""Recall / withdrawal tracing (Tier 3 flagship).

A batch is never only on a shelf. Once a lot number is flagged we must know
exactly where every unit went: another warehouse, a POS receipt, a patient
dispensing record, or a sales order. This module walks all of those sources
and produces an auditable, quantified trace.

The trace is intentionally read-only; :func:`quarantine_case` applies the
blocking once a human confirms the result.
"""
from __future__ import annotations

from collections import defaultdict

from django.db import transaction
from django.db.models import Sum
from django.utils import timezone

from ..models import (MedicationStock, RecallCase, RecallLine, StockBatch,
                      StockPolicy)

TOUCH = RecallLine.Touch


def _match_batches(case: RecallCase):
    """Batches covered by a case.

    Three shapes, in priority order:

    1. **Hand-picked shelf rows** (``target_batch_ids``). The dialog lets a
       user tick "this box but not that one" when the same lot sits on several
       items or warehouses, so an explicit selection always wins over the
       broader lot/item filters.
    2. **Lot number** — every row carrying that lot, *across every item*.
       A lot number is deliberately not unique per item here: the same lot can
       sit on two catalogue items across three shelves, and a recall is about
       the lot, not the label on the box. Filtering by medication as well used
       to silently leave half the lot on sale.
    3. **Medication name** — every lot of one item, when no lot is given.
    """
    qs = StockBatch.objects.select_related('stock', 'stock__branch', 'supplier')

    target_ids = []
    for raw in (case.target_batch_ids or []):
        try:
            target_ids.append(int(raw))
        except (TypeError, ValueError):
            continue
    if target_ids:
        return qs.filter(id__in=target_ids).order_by('expiry_date')

    lot = (case.batch_number or '').strip()
    if lot:
        return qs.filter(batch_number__iexact=lot).order_by('expiry_date')

    medical = (case.medication_name or '').strip()
    if medical:
        return qs.filter(stock__medication_name__iexact=medical)
    return qs.none()


@transaction.atomic
def trace_case(case: RecallCase, *, keep_existing_manual: bool = True) -> dict:
    """(Re)build every ``RecallLine`` for a recall case.

    Rows a human confirmed are preserved when ``keep_existing_manual`` is
    true, so re-running the trace never discards field verification.
    """
    confirmed = {}
    if keep_existing_manual:
        for line in case.lines.filter(is_confirmed=True):
            confirmed[(line.touch, line.reference, line.stock_id)] = line

    case.lines.all().delete()

    batches = list(_match_batches(case))
    batch_ids = [b.id for b in batches]
    stock_ids = {b.stock_id for b in batches}
    lot_number = case.batch_number.strip()

    lines = []

    def add(**kwargs):
        key = (kwargs.get('touch'), kwargs.get('reference', ''), kwargs.get('stock_id'))
        was_confirmed = key in confirmed
        lines.append(RecallLine(is_confirmed=was_confirmed, **kwargs))

    # ── 1. Units still on hand ──────────────────────────────────────────
    for batch in batches:
        if batch.quantity_remaining <= 0:
            continue
        add(
            case=case, touch=TOUCH.ON_HAND, stock=batch.stock, batch=batch,
            branch=batch.stock.branch,
            quantity_on_hand=batch.quantity_remaining,
            reference=batch.batch_number,
            detail=(f'{batch.quantity_remaining} on hand at '
                    f'{batch.stock.branch.name if batch.stock.branch else "warehouse"}'
                    + (' · already quarantined' if batch.is_blocked else '')),
            occurred_at=None,
        )

    # ── 2. Transfer movements (the lot may have left this warehouse) ────
    try:
        from inventory.models import StockTransferLine
        tlines = (StockTransferLine.objects
                  .filter(batch_id__in=batch_ids)
                  .select_related('transfer', 'transfer__dest_branch',
                                  'transfer__source_branch', 'stock'))
        for line in tlines:
            add(
                case=case, touch=TOUCH.TRANSFER, stock=line.stock,
                batch_id=line.batch_id,
                branch=line.transfer.dest_branch,
                quantity_downstream=line.quantity,
                reference=line.transfer.reference,
                detail=(f'{line.transfer.status}: '
                        f'{line.transfer.source_branch} → {line.transfer.dest_branch}'),
                occurred_at=line.transfer.requested_at,
            )
    except Exception:
        pass

    # ── 3. POS sales ────────────────────────────────────────────────────
    try:
        from pos.models import TransactionItem
        sales = (TransactionItem.objects
                 .filter(batch_id__in=batch_ids,
                         transaction__status='completed')
                 .select_related('transaction', 'transaction__branch', 'stock'))
        for item in sales:
            ts = item.transaction.created_at
            add(
                case=case, touch=TOUCH.POS, stock=item.stock,
                batch_id=item.batch_id,
                branch=item.transaction.branch,
                quantity_downstream=item.quantity,
                reference=item.transaction.transaction_number,
                detail=(item.transaction.customer_name
                        or (item.transaction.customer.name
                            if getattr(item.transaction, 'customer', None) else '')
                        or 'Walk-in'),
                occurred_at=ts,
            )
    except Exception:
        pass

    # ── 4. Dispensing to patients (JSON items, no batch FK) ─────────────
    if lot_number or stock_ids:
        try:
            from dispensing.models import DispensingRecord
            qs = (DispensingRecord.objects.filter(status='completed')
                  .only('id', 'receipt_number', 'dispensed_at', 'patient_name',
                        'items_dispensed', 'dispensed_by'))
            for rec in qs:
                for item in (rec.items_dispensed or []):
                    sid = item.get('stock_id')
                    lot = str(item.get('batch_number') or '')
                    if not sid or int(sid) not in stock_ids:
                        continue
                    if lot_number and lot.lower() != lot_number.lower():
                        continue
                    add(
                        case=case, touch=TOUCH.DISPENSED, stock_id=int(sid),
                        batch_id=None,
                        quantity_downstream=int(item.get('qty') or 0),
                        reference=rec.receipt_number or f'RCP-{rec.pk}',
                        detail=f'Patient: {rec.patient_name or "—"}',
                        occurred_at=rec.dispensed_at,
                    )
        except Exception:
            pass

    # ── 5. Sales orders (fulfilled) ─────────────────────────────────────
    try:
        from sales_orders.models import SalesOrder
        qs = (SalesOrder.objects
              .filter(status__in=['fulfilled', 'delivered'],
                      items__isnull=False)
              .only('so_number', 'customer_name', 'items', 'created_at',
                    'status', 'branch_id'))
        for so in qs:
            for item in (so.items or []):
                sid = item.get('stock_id')
                if not sid or int(sid) not in stock_ids:
                    continue
                add(
                    case=case, touch=TOUCH.SALES_ORDER, stock_id=int(sid),
                    quantity_downstream=int(item.get('qty') or 0),
                    reference=so.so_number,
                    detail=f'Customer: {so.customer_name or "—"}',
                    occurred_at=so.created_at,
                )
    except Exception:
        pass

    RecallLine.objects.bulk_create(lines, batch_size=500)

    totals = {
        'lines': len(lines),
        'on_hand': sum(l.quantity_on_hand for l in lines),
        'downstream': sum(l.quantity_downstream for l in lines),
        'batches': len(batches),
    }
    case.status = RecallCase.Status.TRACING
    if case.severity in ('high', 'critical'):
        pass
    case.save(update_fields=['status', 'updated_at'])
    return totals


def affected_batch_ids(case: RecallCase) -> list:
    """Every ``StockBatch`` row this case must quarantine.

    Derived from the case **scope** (picked rows, lot number or medication),
    not from the trace, so a case whose trace has not been run — or failed
    halfway — still blocks the whole lot. Traced batch ids are unioned in
    because a trace can reference a row the scope filter no longer matches
    (e.g. the lot string was edited afterwards).
    """
    ids = set(_match_batches(case).values_list('id', flat=True))
    ids.update(
        RecallLine.objects.filter(case=case)
        .exclude(batch_id__isnull=True)
        .values_list('batch_id', flat=True)
    )
    return sorted(ids)


def affected_stock_ids(case: RecallCase) -> list:
    """Stock items holding any affected row, plus everything the trace found."""
    ids = set(
        StockBatch.objects.filter(id__in=affected_batch_ids(case))
        .exclude(stock_id__isnull=True)
        .values_list('stock_id', flat=True)
    )
    ids.update(
        RecallLine.objects.filter(case=case)
        .exclude(stock_id__isnull=True)
        .values_list('stock_id', flat=True)
    )
    return sorted(ids)


@transaction.atomic
def quarantine_case(case: RecallCase, *, user=None) -> dict:
    """Block every row of the recalled lot and quarantine its stock items.

    Quarantining is deliberately lot-wide: once a batch number is flagged,
    **every** shelf row carrying it stops being sellable, whether or not the
    trace happened to surface it. ``StockBatch.is_blocked`` is what
    ``sellable_quantity`` and :func:`inventory.services.stock.consume_stock`
    both honour, so a blocked row cannot be sold at POS, dispensed, or
    allocated to a sales order until the case is closed.
    """
    batch_ids = affected_batch_ids(case)
    now = timezone.now()
    reason = f'{case.reference} — {case.get_reason_display()}'

    blocked = (StockBatch.objects
               .filter(id__in=batch_ids)
               .exclude(is_blocked=True)
               .update(is_blocked=True, blocked_reason=reason, blocked_at=now))
    # Rows already blocked by an earlier recall keep their original reason, but
    # they are still part of this case's containment set.
    blocked_total = StockBatch.objects.filter(id__in=batch_ids, is_blocked=True).count()

    quarantined_items = 0
    for stock in MedicationStock.objects.filter(id__in=affected_stock_ids(case)):
        policy, _ = StockPolicy.objects.get_or_create(stock=stock)
        if not policy.is_quarantined:
            policy.is_quarantined = True
            policy.quarantine_reason = f'{case.reference}: {case.title}'
            policy.quarantine_case = case
            policy.save(update_fields=['is_quarantined', 'quarantine_reason',
                                       'quarantine_case', 'updated_at'])
            quarantined_items += 1

    units_blocked = (
        StockBatch.objects
        .filter(id__in=batch_ids, is_blocked=True)
        .aggregate(total=Sum('quantity_remaining'))['total'] or 0
    )

    case.status = RecallCase.Status.QUARANTINED
    case.save(update_fields=['status', 'updated_at'])

    _notify_case(case, 'quarantined', units_blocked=units_blocked)
    return {'batches_blocked': blocked, 'batches_in_scope': blocked_total,
            'items_quarantined': quarantined_items,
            'units_blocked': units_blocked}


@transaction.atomic
def release_case(case: RecallCase, *, user=None, note: str = '') -> dict:
    """Close a recall: unblock its batches and lift the item quarantine.

    A stock item can be caught by two open recalls at once (two bad lots of the
    same product). Closing one must not put the other's units back on sale, so
    the policy quarantine is only lifted when no other open case still covers
    that stock.
    """
    batches = (StockBatch.objects
               .filter(blocked_reason__startswith=case.reference, is_blocked=True))
    released = batches.update(is_blocked=False, blocked_reason='', blocked_at=None)

    still_held = {}
    for other in (RecallCase.objects
                  .exclude(pk=case.pk)
                  .filter(status=RecallCase.Status.QUARANTINED)):
        for stock_id in affected_stock_ids(other):
            still_held.setdefault(stock_id, other)

    items = 0
    for policy in StockPolicy.objects.filter(quarantine_case=case):
        keeper = still_held.get(policy.stock_id)
        if keeper is not None:
            # Another live recall still owns this item — keep it locked.
            policy.quarantine_case = keeper
            policy.quarantine_reason = f'{keeper.reference}: {keeper.title}'
            policy.save(update_fields=['quarantine_reason', 'quarantine_case',
                                       'updated_at'])
            continue
        policy.is_quarantined = False
        policy.quarantine_reason = ''
        policy.quarantine_case = None
        policy.save(update_fields=['is_quarantined', 'quarantine_reason',
                                   'quarantine_case', 'updated_at'])
        items += 1

    case.status = RecallCase.Status.COMPLETED
    case.completed_at = timezone.now()
    case.completed_by = user if user and getattr(user, 'is_authenticated', False) else None
    if note:
        case.notes = (case.notes + '\n' + note).strip()
    case.save(update_fields=['status', 'completed_at', 'completed_by', 'notes', 'updated_at'])
    _notify_case(case, 'closed')
    return {'batches_released': released, 'items_released': items}


def _notify_case(case: RecallCase, event: str, *, units_blocked: int | None = None):
    """Tell every warehouse manager about a recall state change.

    Branches come from the trace *and* the affected lot rows: a case can be
    quarantined before its trace has run, and the people who need to walk to
    the shelf are exactly the ones holding a blocked row.
    """
    from notifications.models import Notification

    from ..services.expiry import _managers_for_branch

    branches = {l.branch for l in case.lines.select_related('branch') if l.branch}
    if not branches:
        branches = {
            row.branch or getattr(row.stock, 'branch', None)
            for row in (StockBatch.objects
                        .filter(id__in=affected_batch_ids(case))
                        .select_related('stock', 'branch'))
        }
    branches.discard(None)

    title = (f'Recall {case.reference} {"quarantined" if event == "quarantined" else "closed"}')
    message = (f'{case.title} ({case.get_reason_display()}). ')
    if event == 'quarantined':
        message += (f'{units_blocked if units_blocked is not None else case.units_on_hand} '
                    f'unit(s) locked and no longer sellable')
    else:
        message += (f'{case.units_on_hand} unit(s) on hand, '
                    f'{case.units_downstream} unit(s) already dispatched')
    message += '.'

    seen = set()
    for branch in branches:
        for user in _managers_for_branch(branch):
            if user.id in seen:
                continue
            seen.add(user.id)
            Notification.objects.create(
                recipient=user,
                type='stock_alert',
                title=title,
                message=message,
                data={'key': f'recall:{case.pk}:{event}',
                      'recall_id': case.pk, 'reference': case.reference},
            )


def blocked_units_for(case: RecallCase) -> int:
    """Units this case has actually locked (non-sellable) right now."""
    return (StockBatch.objects
            .filter(is_blocked=True,
                    blocked_reason__startswith=case.reference)
            .aggregate(total=Sum('quantity_remaining'))['total'] or 0)


def recall_impact(case: RecallCase) -> dict:
    """Quantified impact split by touch point, for the case header."""
    by_touch = defaultdict(lambda: {'lines': 0, 'on_hand': 0, 'downstream': 0})
    for line in case.lines.all():
        bucket = by_touch[line.get_touch_display()]
        bucket['lines'] += 1
        bucket['on_hand'] += line.quantity_on_hand
        bucket['downstream'] += line.quantity_downstream
    total_down = sum(b['downstream'] for b in by_touch.values())
    total_hand = sum(b['on_hand'] for b in by_touch.values())
    # Units that a shopper could still buy — the number to drive to zero.
    today = timezone.localdate()
    sellable_left = sum(
        remaining or 0
        for remaining, blocked, expiry in _match_batches(case).values_list(
            'quantity_remaining', 'is_blocked', 'expiry_date')
        if not blocked and (expiry is None or expiry >= today)
    )
    return {
        'by_touch': [{'touch': k, **v} for k, v in by_touch.items()],
        'units_on_hand': total_hand,
        'units_downstream': total_down,
        'units_blocked': blocked_units_for(case),
        'units_still_sellable': sellable_left,
        'recoverable_pct': round(
            total_hand / (total_hand + total_down) * 100, 1)
        if (total_hand + total_down) else 0,
    }
