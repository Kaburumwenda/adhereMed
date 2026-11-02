"""End-to-end item traceability: warehouse entry through to the patient.

A recall can already be traced backwards from a *lot*. This module answers the
harder question a warehouse manager actually asks: **"take this item and show me
the whole life of it"** - which supplier delivered it, which lots arrived, where
each lot sits now, how it moved between warehouses, and who bought or was
dispensed which units.

Design notes
------------
* Every event is emitted with a **signed quantity** (positive = into stock,
  negative = out) so a single running balance can be walked down the chain. That
  balance is then reconciled against physical stock on hand; when it does not
  tie out the trace says so instead of quietly printing a plausible list.
* Each event carries a **chain-of-custody hash** (SHA-256 over the canonical
  fields of every event up to and including it). Two exports of the same trace
  reproduce the same digest, and an edited export will not - which is the whole
  point of a custody record.
* Read-only. Nothing here mutates stock; quarantine still lives in
  :mod:`inventory.services.recall`.
"""
from __future__ import annotations

import hashlib
from collections import defaultdict
from datetime import date, datetime, timedelta

from django.utils import timezone

#: Event classes in the order they appear in the legend.
EVENT_TYPES = {
    'receipt': {'label': 'Goods received', 'direction': 1,
                'icon': 'mdi-truck-delivery-outline'},
    'transfer_in': {'label': 'Transfer in', 'direction': 1,
                    'icon': 'mdi-arrow-down-bold-box-outline'},    'transfer_out': {'label': 'Transfer out', 'direction': -1,
                     'icon': 'mdi-arrow-up-bold-box-outline'},
    'adjustment_in': {'label': 'Adjustment in', 'direction': 1,
                      'icon': 'mdi-plus-box-outline'},
    'adjustment_out': {'label': 'Adjustment out', 'direction': -1,
                       'icon': 'mdi-minus-box-outline'},
    'sale': {'label': 'Customer sale', 'direction': -1,
             'icon': 'mdi-cash-register'},
    'dispensed': {'label': 'Dispensed', 'direction': -1,
                  'icon': 'mdi-pill'},
    'sales_order': {'label': 'Sales order', 'direction': -1,
                    'icon': 'mdi-file-document-outline'},
    'quarantine': {'label': 'Quarantined', 'direction': 0,
                   'icon': 'mdi-lock'},
    'writeoff': {'label': 'Written off', 'direction': -1,
                 'icon': 'mdi-delete-outline'},
    'disposed': {'label': 'Expired / disposed', 'direction': -1,
                 'icon': 'mdi-calendar-remove'},
}

#: Reasons on ``StockAdjustment`` that a sales channel writes itself. Counting
#: them alongside the channel rows would double every unit, so they are skipped
#: (the same rule the reports use - see ``CHANNEL_ADJUSTMENT_REASONS``).
CHANNEL_REASONS = ('pos_sale', 'dispensing', 'dispense_return')


def _dt(value):
    """Coerce a date/datetime to an aware datetime so events sort together."""
    if value is None:
        return None
    if isinstance(value, datetime):
        return timezone.make_aware(value) if timezone.is_naive(value) else value
    if isinstance(value, date):
        naive = datetime.combine(value, datetime.min.time())
        return timezone.make_aware(naive)
    return None


def _stamp(value):
    if not value:
        return ''
    return timezone.localtime(value).strftime('%Y-%m-%d %H:%M')


def _branch_name(branch):
    return getattr(branch, 'name', '') or 'Unassigned'


def branch_label(branch):
    """Public spelling of the name-or-``Unassigned`` rule.

    Exposed so the views can label the branch scope exactly the way every event
    in the trace is labelled, instead of re-deriving the fallback in a second
    place and drifting from it.
    """
    return _branch_name(branch)


def _digest(payload):
    """Stable short digest for one event plus everything before it."""
    raw = '|'.join(str(payload.get(k, '')) for k in (
        'seq', 'kind', 'at', 'reference', 'branch', 'quantity',
        'batch_number', 'party', 'prev'))
    return hashlib.sha256(raw.encode('utf-8')).hexdigest()[:16]


def _collect_receipts(stock, date_from=None, date_to=None):
    """Inbound lots, plus the purchase order that brought them in."""
    from ..models import StockBatch

    batches = (StockBatch.objects
               .filter(stock=stock)
               .select_related('supplier', 'branch')
               .order_by('received_date', 'id'))

    # A GRN stores its lines in JSON, so linking is a scan rather than a join.
    # Only worth doing when there is more than one supplier to disambiguate.
    grn_by_lot = {}
    try:
        from purchase_orders.models import GoodsReceivedNote
        for grn in (GoodsReceivedNote.objects
                    .select_related('purchase_order', 'purchase_order__supplier')
                    .order_by('-received_date')[:400]):
            for line in grn.items_received or []:
                sid = line.get('medication_stock_id') or line.get('stock_id')
                lot = str(line.get('batch_number') or '').strip().lower()
                if sid and int(sid) == stock.id and lot:
                    grn_by_lot.setdefault(lot, {
                        'grn': grn.grn_number,
                        'po': grn.purchase_order.po_number,
                        'received': grn.received_date,
                        'supplier': getattr(grn.purchase_order.supplier, 'name', ''),
                    })
    except Exception:
        pass

    events = []
    for batch in batches:
        received = _dt(batch.received_date)
        if date_from and received and received.date() < date_from:
            continue
        if date_to and received and received.date() > date_to:
            continue
        lot = (batch.batch_number or '').strip()
        grn = grn_by_lot.get(lot.lower(), {})
        supplier = getattr(batch.supplier, 'name', '') or grn.get('supplier', '')
        # Lots booked by a transfer receipt are named TRF-<reference>; labelling
        # them as a purchase would send the reader looking for a supplier who
        # never delivered them.
        is_transfer_lot = lot.upper().startswith('TRF-')
        if grn.get('grn'):
            reference = grn['grn']
        elif is_transfer_lot:
            reference = lot
        elif lot.upper().startswith('PO-'):
            reference = lot
        else:
            reference = f'LOT {lot or batch.id}'
        detail = []
        if grn.get('po'):
            detail.append(f'PO {grn["po"]}')
        if is_transfer_lot:
            detail.append('Booked by an inter-warehouse transfer')
        if batch.expiry_date:
            detail.append(f'expires {batch.expiry_date.isoformat()}')
        if batch.cost_price_per_unit:
            detail.append(f'@ {batch.cost_price_per_unit:,.2f}/unit')
        events.append({
            'kind': 'receipt',
            'at': received,
            'at_display': _stamp(received),
            'reference': reference,
            'branch': _branch_name(batch.branch or stock.branch),
            'party': supplier or ('Transfer received' if is_transfer_lot
                                  else 'Unknown supplier'),
            'batch_number': lot or f'#{batch.id}',
            'batch_id': batch.id,
            'quantity': int(batch.quantity_received or 0),
            'detail': ' · '.join(detail) or 'No purchase order recorded',
            'cost': float(batch.cost_price_per_unit or 0),
            'expiry': batch.expiry_date.isoformat() if batch.expiry_date else None,
            'is_blocked': bool(batch.is_blocked),
        })
    return events, batches


def _collect_outbound(stock, batch_ids, date_from=None, date_to=None):
    """Everything that took units out of the warehouse, by channel."""

    def within(value):
        if not value:
            return True
        day = value.date()
        if date_from and day < date_from:
            return False
        if date_to and day > date_to:
            return False
        return True

    events, transfers_map = _collect_transfers(stock, batch_ids, within)
    lot_by_batch = dict(transfers_map)

    sales, maps = _collect_sales(stock, batch_ids, within)
    lot_by_batch.update(maps)

    dispensed, maps = _collect_dispensing(stock, within)
    lot_by_batch.update(maps)

    orders, maps = _collect_sales_orders(stock, within)
    lot_by_batch.update(maps)

    # ``StockAdjustment`` already records dispensing, POS and write-off
    # movements written by those channels. Only *manual* adjustments are added
    # here - see CHANNEL_REASONS.
    adjustments = _collect_adjustments(stock, batch_ids, within)

    return events + sales + dispensed + orders + adjustments, lot_by_batch


def _batch_lot_map(batch_ids):
    from ..models import StockBatch
    return {b.id: (b.batch_number or f'#{b.id}')
            for b in StockBatch.objects.filter(id__in=batch_ids)}


def _collect_transfers(stock, batch_ids, within):
    """Units that left this warehouse for another one.

    Only the **outbound** leg is emitted. A completed transfer books a *new*
    lot at the destination (named ``TRF-<reference>``), and that lot already
    appears in this trace as its own receipt - emitting a ``transfer_in`` as
    well added the same units twice and inflated the reconciliation by exactly
    the transferred quantity.
    """
    from ..models import StockTransferLine

    lot_map = _batch_lot_map(batch_ids)
    events = []
    lines = (StockTransferLine.objects
             .filter(stock=stock)
             .select_related('transfer', 'transfer__source_branch',
                             'transfer__dest_branch', 'batch'))
    for line in lines:
        transfer = line.transfer
        # ``StockTransfer`` has approved_by but no approved_at, so the timestamp
        # has to come from one of the three fields that actually exist.
        at = _dt(transfer.shipped_at or transfer.received_at
                 or transfer.requested_at)
        if not within(at):
            continue
        lot = lot_map.get(line.batch_id) or (
            line.batch.batch_number if line.batch_id and line.batch else '')
        detail = transfer.get_status_display()
        if transfer.priority and transfer.priority != 'normal':
            detail += f' · {transfer.get_priority_display()} priority'
        if line.quantity_received != line.quantity:
            detail += (f' · {line.quantity_received} of {line.quantity} '
                       f'arrived')
        events.append({
            'kind': 'transfer_out',
            'at': at,
            'at_display': _stamp(at),
            'reference': transfer.reference,
            'branch': _branch_name(transfer.source_branch),
            'party': f'to {_branch_name(transfer.dest_branch)}',
            'batch_number': lot or '—',
            'batch_id': line.batch_id,
            'quantity': -int(line.quantity or 0),
            'detail': detail,
        })
    return events, lot_map


def _collect_sales(stock, batch_ids, within):
    from pos.models import TransactionItem

    lot_map = {}
    events = []
    items = (TransactionItem.objects
             .filter(stock=stock,
                     transaction__status='completed')
             .select_related('transaction', 'transaction__branch', 'batch'))
    for item in items:
        at = _dt(item.transaction.created_at)
        if not within(at):
            continue
        customer = (item.transaction.customer_name or '').strip()
        if not customer and getattr(item.transaction, 'customer', None):
            customer = getattr(item.transaction.customer, 'name', '') or ''
        lot = item.batch.batch_number if item.batch_id and item.batch else '—'
        if item.batch_id:
            lot_map[item.batch_id] = lot
        unit_price = float(item.unit_price or 0)
        events.append({
            'kind': 'sale',
            'at': at,
            'at_display': _stamp(at),
            'reference': item.transaction.transaction_number,
            'branch': _branch_name(item.transaction.branch),
            'party': customer or 'Walk-in customer',
            'batch_number': lot,
            'batch_id': item.batch_id,
            'quantity': -int(item.quantity or 0),
            'value': round(unit_price * int(item.quantity or 0), 2),
            'detail': (f'{item.transaction.payment_method}'
                       if item.transaction.payment_method else 'Sale'),
        })
    return events, lot_map


def _collect_dispensing(stock, within):
    """Dispensing records hold their lines as JSON, so this is a scan."""
    from dispensing.models import DispensingRecord

    events = []
    lot_map = {}
    records = (DispensingRecord.objects
               .filter(status='completed')
               .only('id', 'receipt_number', 'dispensed_at', 'patient_name',
                     'items_dispensed', 'total'))
    for record in records:
        for line in record.items_dispensed or []:
            try:
                if int(line.get('stock_id') or 0) != stock.id:
                    continue
            except (TypeError, ValueError):
                continue
            at = _dt(record.dispensed_at)
            if not within(at):
                continue
            lot = str(line.get('batch_number') or '—')
            events.append({
                'kind': 'dispensed',
                'at': at,
                'at_display': _stamp(at),
                'reference': record.receipt_number or f'RCP-{record.pk}',
                'branch': _branch_name(stock.branch),
                'party': record.patient_name or 'Unnamed patient',
                'batch_number': lot,
                'batch_id': None,
                'quantity': -int(line.get('qty') or 0),
                'value': float(line.get('total') or 0) or None,
                'detail': 'Dispensed to patient',
            })
    return events, lot_map


def _collect_sales_orders(stock, within):
    from sales_orders.models import SalesOrder

    events = []
    lot_map = {}
    # Exclude by *negation* rather than listing the statuses that count: the
    # real choices are draft/confirmed/partial/fulfilled/cancelled, and an
    # allow-list silently drops any status added later.
    excluded = {SalesOrder.Status.DRAFT, SalesOrder.Status.CANCELLED}
    orders = (SalesOrder.objects
              .exclude(status__in=excluded)
              .filter(items__isnull=False)
              .only('so_number', 'customer_name', 'items', 'created_at',
                    'status', 'branch_id', 'branch'))
    for order in orders:
        for line in order.items or []:
            try:
                if int(line.get('stock_id') or 0) != stock.id:
                    continue
            except (TypeError, ValueError):
                continue
            at = _dt(order.created_at)
            if not within(at):
                continue
            events.append({
                'kind': 'sales_order',
                'at': at,
                'at_display': _stamp(at),
                'reference': order.so_number,
                'branch': _branch_name(getattr(order, 'branch', None) or stock.branch),
                'party': order.customer_name or 'Account customer',
                'batch_number': str(line.get('batch_number') or '—'),
                'batch_id': None,
                'quantity': -int(line.get('qty') or 0),
                'value': (float(line.get('total') or 0) or None),
                'detail': f'Order {order.get_status_display()}',
            })
    return events, lot_map


def _collect_adjustments(stock, batch_ids, within):
    from ..models import StockAdjustment

    lot_map = _batch_lot_map(batch_ids)
    events = []
    rows = (StockAdjustment.objects
            .filter(stock=stock)
            .exclude(reason__in=CHANNEL_REASONS)
            .select_related('batch', 'adjusted_by'))
    for row in rows:
        at = _dt(row.created_at)
        if not within(at):
            continue
        change = int(row.quantity_change or 0)
        if not change:
            continue
        lot = lot_map.get(row.batch_id) or (
            row.batch.batch_number if row.batch_id and row.batch else '—')
        events.append({
            'kind': 'adjustment_in' if change > 0 else 'adjustment_out',
            'at': at,
            'at_display': _stamp(at),
            'reference': f'ADJ-{row.pk:05d}',
            'branch': _branch_name(stock.branch),
            'party': getattr(row.adjusted_by, 'full_name', '') or 'System',
            'batch_number': lot,
            'batch_id': row.batch_id,
            'quantity': change,
            'detail': row.get_reason_display() + (
                f' · {row.notes}' if row.notes else ''),
        })
    return events


def _batch_breakdown(batches, events):
    """Per-lot position: received, sold, moved, and what physically remains."""
    per_lot = defaultdict(lambda: {'received': 0, 'sold': 0, 'moved': 0,
                                   'adjusted': 0})
    for event in events:
        lot = event.get('batch_number')
        if not lot:
            continue
        bucket = per_lot[lot]
        if event['kind'] == 'receipt':
            bucket['received'] += event['quantity']
        elif event['kind'] in ('sale', 'dispensed', 'sales_order'):
            bucket['sold'] += -event['quantity']
        elif event['kind'] == 'transfer_out':
            bucket['moved'] += -event['quantity']
        elif event['kind'] in ('adjustment_in', 'adjustment_out'):
            bucket['adjusted'] += event['quantity']

    today = timezone.localdate()
    rows = []
    for batch in batches:
        lot = (batch.batch_number or '').strip() or f'#{batch.id}'
        bucket = per_lot.get(lot, {'received': 0, 'sold': 0, 'moved': 0,
                                   'adjusted': 0})
        received = int(batch.quantity_received or 0) or bucket['received']
        sold = bucket['sold']
        moved = bucket['moved']
        on_hand = int(batch.quantity_remaining or 0)
        sell_through = (sold / received * 100) if received else 0.0
        days_to_expiry = ((batch.expiry_date - today).days
                          if batch.expiry_date else None)
        age = ((today - batch.received_date).days
               if batch.received_date else None)
        rows.append({
            'batch_id': batch.id,
            'batch_number': lot,
            'received_date': (batch.received_date.isoformat()
                              if batch.received_date else None),
            'expiry_date': (batch.expiry_date.isoformat()
                            if batch.expiry_date else None),
            'supplier': getattr(batch.supplier, 'name', '') or '',
            'branch': _branch_name(batch.branch or batch.stock.branch),
            'received': received,
            'sold': sold,
            'moved': moved,
            'on_hand': on_hand,
            'sell_through_pct': round(sell_through, 1),
            'age_days': age,
            'days_to_expiry': days_to_expiry,
            'unit_cost': float(batch.cost_price_per_unit or 0),
            'value_on_hand': round(on_hand * float(batch.cost_price_per_unit or 0), 2),
            'is_blocked': bool(batch.is_blocked),
            'blocked_reason': batch.blocked_reason or '',
            'status': ('quarantined' if batch.is_blocked
                       else 'expired' if days_to_expiry is not None and days_to_expiry < 0
                       else 'depleted' if on_hand <= 0
                       else 'in stock'),
        })
    rows.sort(key=lambda r: (r['received_date'] or ''), reverse=True)
    return rows


def _reconciliation(*, received, sold, moved_out, adjusted, on_hand,
                    windowed=False):
    """Does the ledger walk end where the shelf says it should?

    ``on_hand`` is physical stock, not the running balance, so a mismatch means
    a movement exists that no channel recorded (or that a channel counted the
    same units twice). Reporting the residual is more useful than hiding it.

    **A windowed trace cannot reconcile.** ``on_hand`` is the all-time physical
    balance while the events only cover the requested range, so any stock
    received before the window looks like an unexplained surplus. Rather than
    printing a false failure, the verdict says plainly that the comparison is
    not applicable over a range.
    """
    explained = received - sold - moved_out + adjusted
    residual = on_hand - explained
    tied = abs(residual) <= max(1, 0.005 * max(abs(explained), 1))
    if windowed:
        verdict = ('Not comparable: this is a date-bounded view of the '
                   'movements, so the running total cannot be checked against '
                   'stock on hand. Clear the dates for a full reconciliation.')
    elif tied:
        verdict = 'Ledger reconciles with physical stock'
    else:
        verdict = f'Unrecorded movement of {residual:+,} unit(s)'
    return {
        'received': received,
        'sold': sold,
        'moved_out': moved_out,
        'adjusted': adjusted,
        'explained': explained,
        'on_hand': on_hand,
        'residual': residual,
        'tied': tied,
        'windowed': windowed,
        'comparable': not windowed,
        'verdict': verdict,
    }


def _anomalies(*, events, batches, reconciliation, stock):
    """Integrity problems worth a human's attention."""
    findings = []
    if not batches:
        findings.append({
            'severity': 'high',
            'label': 'No inbound lot recorded',
            'detail': ('This item has stock history but no lot with a receipt '
                       'date, so it cannot be traced to a supplier.'),
        })
    if not reconciliation['tied'] and reconciliation.get('comparable', True):
        findings.append({
            'severity': 'high',
            'label': 'Trace does not reconcile',
            'detail': (f'Explained balance {reconciliation["explained"]:,} vs '
                       f'physical {reconciliation["on_hand"]:,} '
                       f'({reconciliation["residual"]:+,}). A movement is '
                       f'missing or double-counted.'),
        })

    # Units leaving without a lot attached cannot be recalled later.
    unlinked = [e for e in events
                if e['kind'] in ('sale', 'dispensed', 'sales_order')
                and not e.get('batch_id')
                and e.get('batch_number') in (None, '', '—')]
    if unlinked:
        findings.append({
            'severity': 'medium',
            'label': 'Outbound rows with no lot linkage',
            'detail': (f'{len(unlinked)} sale/dispensing row(s) carry no batch '
                       f'reference, so those units cannot be recalled by lot.'),
        })

    negative = [b for b in batches
                if int(b.quantity_remaining or 0) < 0]
    if negative:
        findings.append({
            'severity': 'high',
            'label': 'Negative lot balance',
            'detail': f'{len(negative)} lot(s) have a negative remaining quantity.',
        })

    today = timezone.localdate()
    sold_expired = []
    for batch in batches:
        if not batch.expiry_date:
            continue
        for event in events:
            if (event.get('batch_id') == batch.id
                    and event['kind'] in ('sale', 'dispensed', 'sales_order')
                    and event['at'] and event['at'].date() > batch.expiry_date):
                sold_expired.append((batch.batch_number, event['reference']))
                break
    if sold_expired:
        findings.append({
            'severity': 'critical',
            'label': 'Expired stock sold',
            'detail': (f'{len(sold_expired)} lot(s) had units leave after the '
                       f'expiry date (e.g. {sold_expired[0][0]} on '
                       f'{sold_expired[0][1]}).'),
        })

    expiring_held = [b for b in batches
                     if b.expiry_date and 0 <= (b.expiry_date - today).days <= 30
                     and (b.quantity_remaining or 0) > 0]
    if expiring_held:
        findings.append({
            'severity': 'medium',
            'label': 'Stock expiring within 30 days',
            'detail': (f'{len(expiring_held)} lot(s) with '
                       f'{sum(int(b.quantity_remaining or 0) for b in expiring_held):,} '
                       f'units will expire inside a month.'),
        })

    expired_held = [b for b in batches
                    if b.expiry_date and (b.expiry_date - today).days < 0
                    and (b.quantity_remaining or 0) > 0]
    if expired_held:
        findings.append({
            'severity': 'high',
            'label': 'Expired units still on hand',
            'detail': (f'{len(expired_held)} lot(s) hold '
                       f'{sum(int(b.quantity_remaining or 0) for b in expired_held):,} '
                       f'expired unit(s) that cannot be sold. Raise a write-off '
                       f'to clear them from sellable stock.'),
        })

    if stock.committed_qty:
        findings.append({
            'severity': 'low',
            'label': 'Units committed to open orders',
            'detail': (f'{int(stock.committed_qty):,} unit(s) are reserved '
                       f'against paid sales orders and are not available to sell.'),
        })

    # An outbound row dated before the first inbound lot means the units left
    # before anyone recorded them arriving - either a backdated receipt or a
    # lot that was never booked in.
    first_receipt = min((e['at'] for e in events if e['kind'] == 'receipt'
                         and e['at']), default=None)
    if first_receipt:
        early = [e for e in events
                 if e['kind'] in ('sale', 'dispensed', 'sales_order')
                 and e['at'] and e['at'] < first_receipt]
        if early:
            findings.append({
                'severity': 'medium',
                'label': 'Units left before any receipt',
                'detail': (f'{len(early)} outbound row(s) predate the first '
                           f'receipt (earliest {early[0]["reference"]} on '
                           f'{early[0]["at_display"]}). Either the receipt was '
                           f'backdated or that lot was never booked in.'),
            })
    return findings


def _provenance(batches, events):
    """Who supplied it, and where has it been."""

    def supplier_of(batch):
        name = getattr(batch.supplier, 'name', '') or ''
        if name:
            return name
        # Lots booked by a transfer have no supplier - saying "Unknown supplier"
        # would imply a missing record when there was never meant to be one.
        if (batch.batch_number or '').upper().startswith('TRF-'):
            return 'Inter-warehouse transfer'
        return 'Unknown supplier'

    suppliers = []
    seen = set()
    for batch in batches:
        name = supplier_of(batch)
        if name in seen:
            continue
        seen.add(name)
        lots = [b for b in batches if supplier_of(b) == name]
        suppliers.append({
            'name': name,
            'lots': len(lots),
            'units': sum(int(b.quantity_received or 0) for b in lots),
            'first_receipt': min((b.received_date for b in lots
                                  if b.received_date), default=None),
        })
    suppliers.sort(key=lambda s: -s['units'])

    branches = defaultdict(lambda: {'in': 0, 'out': 0})
    for event in events:
        name = event.get('branch') or 'Unassigned'
        if event['quantity'] > 0:
            branches[name]['in'] += event['quantity']
        elif event['quantity'] < 0:
            branches[name]['out'] += -event['quantity']
    movements = [{'branch': name, 'in': v['in'], 'out': v['out']}
                 for name, v in branches.items()]
    movements.sort(key=lambda m: -(m['in'] + m['out']))

    first = min((e['at'] for e in events if e['at']), default=None)
    last = max((e['at'] for e in events if e['at']), default=None)
    return {
        'suppliers': [
            {'name': s['name'], 'lots': s['lots'], 'units': s['units'],
             'first_receipt': (s['first_receipt'].isoformat()
                               if s['first_receipt'] else None)}
            for s in suppliers
        ],
        'branches': movements,
        'first_event': _stamp(first),
        'last_event': _stamp(last),
        'span_days': ((last - first).days if first and last else 0),
    }


def trace_stock(stock, *, date_from=None, date_to=None, limit_days=None):
    """Full life-of-item trace. Read-only.

    Returns a dict the API returns verbatim and the page renders directly:
    ``events`` (chronological, with running balance and custody hash),
    ``batches``, ``reconciliation``, ``anomalies``, ``provenance`` and
    ``summary``.

    ``date_from``/``date_to`` narrow the *event list* only. The lot ledger and
    reconciliation always cover the item's whole life, because a balance that
    reconciled over a window but not overall would be actively misleading.
    """
    if limit_days and not date_from:
        date_from = timezone.localdate() - timedelta(days=limit_days)

    receipts, batches = _collect_receipts(stock, date_from, date_to)
    outbound, _lots = _collect_outbound(
        stock, [b.id for b in batches], date_from, date_to)

    events = receipts + outbound
    events.sort(key=lambda e: (e['at'] or timezone.now(), e['reference']))

    # Quarantine is a lateral state change, not a movement: it is surfaced as
    # an annotation on the lot rather than an event with a quantity.
    for event in events:
        meta = EVENT_TYPES.get(event['kind'], {})
        event.setdefault('label', meta.get('label', event['kind']))
        event.setdefault('icon', meta.get('icon', 'mdi-circle-small'))
        event.setdefault('value', None)
        event.setdefault('cost', None)
        event.setdefault('expiry', None)

    # Running balance + chain of custody.
    balance = 0
    previous = 'genesis'
    for index, event in enumerate(events, start=1):
        balance += event['quantity']
        event['seq'] = index
        event['balance'] = balance
        event['hash'] = _digest({
            'seq': index,
            'kind': event['kind'],
            'at': event['at_display'],
            'reference': event['reference'],
            'branch': event['branch'],
            'quantity': event['quantity'],
            'batch_number': event['batch_number'],
            'party': event['party'],
            'prev': previous,
        })
        previous = event['hash']

    sold = sum(-e['quantity'] for e in events
               if e['kind'] in ('sale', 'dispensed', 'sales_order'))
    moved_out = sum(-e['quantity'] for e in events
                    if e['kind'] == 'transfer_out')
    adjusted = sum(e['quantity'] for e in events
                   if e['kind'] in ('adjustment_in', 'adjustment_out'))
    written_off = sum(-e['quantity'] for e in events if e['kind'] == 'writeoff')
    received = sum(e['quantity'] for e in events if e['kind'] == 'receipt')

    on_hand = int(stock.total_quantity or 0)
    reconciliation = _reconciliation(
        received=received,
        sold=sold + written_off,
        moved_out=moved_out,
        adjusted=adjusted,
        on_hand=on_hand,
        windowed=bool(date_from or date_to),
    )

    revenue = sum(e['value'] or 0 for e in events
                  if e['kind'] in ('sale', 'dispensed', 'sales_order'))
    cost_of_sold = 0.0
    cost_by_lot = {b.batch_number: float(b.cost_price_per_unit or 0)
                   for b in batches}
    for event in events:
        if event['kind'] in ('sale', 'dispensed', 'sales_order'):
            unit = cost_by_lot.get(event.get('batch_number'), 0.0)
            cost_of_sold += -event['quantity'] * unit

    lot_rows = _batch_breakdown(batches, events)
    today = timezone.localdate()
    receipt_dates = [b.received_date for b in batches if b.received_date]
    oldest = max(receipt_dates, default=None)
    # Dwell = how long the *undepleted* stock has been sitting. Measuring from
    # the oldest lot overall would keep growing even after that lot sold out,
    # which reads as an aging problem that no longer exists.
    held = [b.received_date for b in batches
            if b.received_date and int(b.quantity_remaining or 0) > 0]
    dwell = (today - min(held)).days if held else None

    summary = {
        'stock_id': stock.id,
        'medication_id': stock.medication_id,
        'name': stock.medication_name,
        'strength': stock.strength or '',
        'abbreviation': stock.abbreviation or '',
        'barcode': stock.barcode or '',
        'category': getattr(stock.category, 'name', '') or '',
        'unit': (getattr(stock.unit, 'abbreviation', '')
                 or getattr(stock.unit, 'name', '') or 'units'),
        'branch': _branch_name(stock.branch),
        'received': received,
        'sold': sold,
        'moved_out': moved_out,
        'adjusted': adjusted,
        'written_off': written_off,
        'on_hand': on_hand,
        'sellable': int(stock.sellable_quantity or 0),
        'expired': int(stock.expired_quantity or 0),
        'quarantined': int(stock.blocked_quantity or 0),
        'committed': int(stock.committed_qty or 0),
        'lots': len(batches),
        'events': len(events),
        'revenue': round(revenue, 2),
        'cost_of_sold': round(cost_of_sold, 2),
        'margin': round(revenue - cost_of_sold, 2),
        'margin_pct': round(((revenue - cost_of_sold) / revenue * 100)
                            if revenue else 0.0, 1),
        'sell_through_pct': round((sold / received * 100) if received else 0.0, 1),
        'dwell_days': dwell,
        'last_receipt': oldest.isoformat() if oldest else None,
        'value_on_hand': round(sum(r['value_on_hand'] for r in lot_rows), 2),
        'custody_digest': previous if previous != 'genesis' else '',
    }

    payload = {
        'summary': summary,
        # ``at`` is a datetime and is not JSON-serialisable; the pre-formatted
        # ``at_display`` carries everything the page and the CSV need.
        'events': [
            {k: v for k, v in event.items() if k != 'at'}
            for event in events
        ],
        'batches': lot_rows,
        'reconciliation': reconciliation,
        'anomalies': _anomalies(events=events, batches=batches,
                                reconciliation=reconciliation, stock=stock),
        'provenance': _provenance(batches, events),
        'event_types': EVENT_TYPES,
    }
    return payload


def trace_candidates(qs, *, search='', limit=40):
    """Items a user can start a trace from, with the data needed to pick one.

    Two traps here, both of which silently inflate quantities:

    1. ``with_quantities()`` aggregates over ``batches``. Any **second** join to
       that table multiplies every ``Sum`` by the join's row count, so
       ``Count('batches', distinct=True)`` as a sibling annotation is wrong.
       The lot count is a correlated subquery instead.
    2. The same applies to a *filter*. ``Q(batches__batch_number__icontains=…)``
       puts a JOIN in the WHERE clause and multiplies the Sums even when the
       other branches of the OR matched — so searching by lot number made a
       30-unit item with 3 lots report 90. The lot branch is an ``Exists``
       subquery for exactly this reason.
    """
    from django.db.models import Count, Exists, IntegerField, OuterRef, Q, Subquery
    from django.db.models.functions import Coalesce

    from ..models import MedicationStock, StockBatch

    qs = qs.filter(is_active=True).with_quantities()
    if search:
        term = search.strip()
        lots_match = Exists(
            StockBatch.objects.filter(stock=OuterRef('pk'),
                                      batch_number__icontains=term))
        qs = qs.filter(
            Q(medication_name__icontains=term)
            | Q(medication_id__icontains=term)
            | Q(abbreviation__icontains=term)
            | Q(barcode__icontains=term)
            | lots_match
        )

    lot_counts = (MedicationStock.objects
                  .filter(pk=OuterRef('pk'))
                  .values('pk')
                  .annotate(total=Count('batches'))
                  .values('total'))
    qs = qs.annotate(lot_count=Coalesce(
        Subquery(lot_counts, output_field=IntegerField()), 0))

    rows = []
    for stock in qs.select_related('branch', 'category').order_by(
            'medication_name')[:limit]:
        rows.append({
            'id': stock.id,
            'medication_id': stock.medication_id,
            'name': stock.medication_name,
            'strength': stock.strength or '',
            'barcode': stock.barcode or '',
            'branch': _branch_name(stock.branch),
            'on_hand': int(stock.total_quantity or 0),
            'sellable': int(stock.sellable_quantity or 0),
            'lots': int(getattr(stock, 'lot_count', 0) or 0),
        })
    return rows


# ── Batch (lot) trace ───────────────────────────────────────────────────
#: The lot equivalent of the item trace, and a different question. An item
#: trace asks "what happened to this product?"; a batch trace asks "where did
#: *these units* go?" - which is the recall question, and the one a regulator
#: asks. A lot number is deliberately **not** unique per item or per warehouse:
#: the same lot can sit on two catalogue items across three shelves, so every
#: figure here aggregates across ``StockBatch`` rows rather than assuming one.

def batch_candidates(qs, *, search='', limit=40):
    """Lots a user can start a batch trace from.

    Aggregates by lot number instead of listing rows, because one lot routinely
    spans several items and warehouses and a row-per-batch picker would show
    the same lot three times with three partial quantities.
    """
    from django.db.models import Count, Min, Q, Sum

    if search:
        term = search.strip()
        qs = qs.filter(
            Q(batch_number__icontains=term)
            | Q(stock__medication_name__icontains=term)
            | Q(stock__medication_id__icontains=term)
        )

    rows = list(
        qs.values('batch_number').annotate(
            items=Count('stock_id', distinct=True),
            branches=Count('branch_id', distinct=True),
            received=Sum('quantity_received'),
            on_hand=Sum('quantity_remaining'),
            expiry=Min('expiry_date'),
            received_on=Min('received_date'),
            quarantined=Count('id', filter=Q(is_blocked=True)),
        ).order_by('-received_on', 'batch_number')[:limit])

    if not rows:
        return []

    # Names come from a second pass constrained to the same (already scoped)
    # queryset, so a branch-scoped user never sees another warehouse's name.
    lots = [r['batch_number'] for r in rows]
    detail = {}
    for batch in (qs.filter(batch_number__in=lots)
                  .select_related('stock', 'branch')
                  .order_by('stock__medication_name')):
        entry = detail.setdefault(batch.batch_number, {
            'names': [], 'branch_names': [],
        })
        name = batch.stock.medication_name if batch.stock_id else ''
        if name and name not in entry['names']:
            entry['names'].append(name)
        branch = _branch_name(batch.branch or getattr(batch.stock, 'branch', None))
        if branch not in entry['branch_names']:
            entry['branch_names'].append(branch)

    today = timezone.localdate()
    out = []
    for row in rows:
        lot = row['batch_number'] or ''
        info = detail.get(lot, {'names': [], 'branch_names': []})
        expiry = row['expiry']
        days_to_expiry = (expiry - today).days if expiry else None
        on_hand = int(row['on_hand'] or 0)
        out.append({
            'batch_number': lot,
            'items': int(row['items'] or 0),
            'branches': int(row['branches'] or 0),
            'names': info['names'],
            'label': (info['names'][0] if len(info['names']) == 1
                      else f"{info['names'][0]} +{len(info['names']) - 1} more"
                      if info['names'] else 'Unknown item'),
            'branch_names': info['branch_names'],
            'received': int(row['received'] or 0),
            'on_hand': on_hand,
            'expiry_date': expiry.isoformat() if expiry else None,
            'received_date': (row['received_on'].isoformat()
                              if row['received_on'] else None),
            'days_to_expiry': days_to_expiry,
            'quarantined': int(row['quarantined'] or 0) > 0,
            'status': ('quarantined' if row['quarantined']
                       else 'expired' if days_to_expiry is not None and days_to_expiry < 0
                       else 'depleted' if on_hand <= 0
                       else 'in stock'),
        })
    return out


def _batch_events(batches, lot_number, within):
    """Every movement of this lot, across every item and warehouse holding it.

    Two linkage styles exist and both must be walked: a real ``batch`` FK
    (receipts, transfers, POS, adjustments) and a lot *string* inside a JSON
    line (dispensing, sales orders). Skipping the second would silently omit
    the patient-facing half of the chain - exactly the half a recall needs.
    """
    from django.db.models import Q

    from ..models import StockAdjustment, StockTransferLine

    batch_ids = [b.id for b in batches]
    stock_ids = {b.stock_id for b in batches if b.stock_id}
    lot_key = (lot_number or '').strip().lower()
    by_id = {b.id: b for b in batches}

    events = []

    # ── Receipts: one per StockBatch row ────────────────────────────────
    for batch in batches:
        received = _dt(batch.received_date)
        if not within(received):
            continue
        supplier = getattr(batch.supplier, 'name', '') or ''
        is_transfer_lot = (batch.batch_number or '').upper().startswith('TRF-')
        if not supplier:
            supplier = ('Inter-warehouse transfer' if is_transfer_lot
                        else 'Unknown supplier')
        detail = []
        if batch.expiry_date:
            detail.append(f'expires {batch.expiry_date.isoformat()}')
        if batch.cost_price_per_unit:
            detail.append(f'@ {batch.cost_price_per_unit:,.2f}/unit')
        if batch.is_blocked:
            detail.append('quarantined')
        events.append({
            'kind': 'receipt',
            'at': received,
            'at_display': _stamp(received),
            'reference': f'LOT {lot_number}',
            'branch': _branch_name(batch.branch
                                   or getattr(batch.stock, 'branch', None)),
            'party': supplier,
            'batch_number': batch.batch_number or '',
            'batch_id': batch.id,
            'stock_id': batch.stock_id,
            'item': getattr(batch.stock, 'medication_name', '') or '',
            'quantity': int(batch.quantity_received or 0),
            'detail': ' · '.join(detail) or 'No expiry or cost recorded',
            'cost': float(batch.cost_price_per_unit or 0),
            'expiry': (batch.expiry_date.isoformat()
                       if batch.expiry_date else None),
        })

    # ── Transfers (outbound leg only - the destination re-lots) ─────────
    if batch_ids:
        for line in (StockTransferLine.objects
                     .filter(batch_id__in=batch_ids)
                     .select_related('transfer', 'transfer__source_branch',
                                     'transfer__dest_branch', 'stock')):
            transfer = line.transfer
            at = _dt(transfer.shipped_at or transfer.received_at
                     or transfer.requested_at)
            if not within(at):
                continue
            detail = transfer.get_status_display()
            if line.quantity_received != line.quantity:
                detail += (f' · {line.quantity_received} of {line.quantity} '
                           f'arrived')
            events.append({
                'kind': 'transfer_out',
                'at': at,
                'at_display': _stamp(at),
                'reference': transfer.reference,
                'branch': _branch_name(transfer.source_branch),
                'party': f'to {_branch_name(transfer.dest_branch)}',
                'batch_number': lot_number,
                'batch_id': line.batch_id,
                'stock_id': line.stock_id,
                'item': getattr(line.stock, 'medication_name', '') or '',
                'quantity': -int(line.quantity or 0),
                'detail': detail,
            })

    # ── POS sales (real batch FK) ───────────────────────────────────────
    if batch_ids:
        try:
            from pos.models import TransactionItem
            for item in (TransactionItem.objects
                         .filter(batch_id__in=batch_ids,
                                 transaction__status='completed')
                         .select_related('transaction', 'transaction__branch',
                                         'stock', 'batch')):
                at = _dt(item.transaction.created_at)
                if not within(at):
                    continue
                customer = (item.transaction.customer_name or '').strip()
                if not customer and getattr(item.transaction, 'customer', None):
                    customer = getattr(item.transaction.customer, 'name', '')
                unit_price = float(item.unit_price or 0)
                events.append({
                    'kind': 'sale',
                    'at': at,
                    'at_display': _stamp(at),
                    'reference': item.transaction.transaction_number,
                    'branch': _branch_name(item.transaction.branch),
                    'party': customer or 'Walk-in customer',
                    'batch_number': lot_number,
                    'batch_id': item.batch_id,
                    'stock_id': item.stock_id,
                    'item': getattr(item.stock, 'medication_name', '') or '',
                    'quantity': -int(item.quantity or 0),
                    'value': round(unit_price * int(item.quantity or 0), 2),
                    'detail': (item.transaction.payment_method or 'Sale'),
                })
        except Exception:
            pass

    # ── Dispensing to patients (lot string only) ────────────────────────
    try:
        from dispensing.models import DispensingRecord
        for record in (DispensingRecord.objects
                       .filter(status='completed')
                       .only('id', 'receipt_number', 'dispensed_at',
                             'patient_name', 'items_dispensed')):
            for line in record.items_dispensed or []:
                try:
                    if int(line.get('stock_id') or 0) not in stock_ids:
                        continue
                except (TypeError, ValueError):
                    continue
                if str(line.get('batch_number') or '').strip().lower() != lot_key:
                    continue
                at = _dt(record.dispensed_at)
                if not within(at):
                    continue
                events.append({
                    'kind': 'dispensed',
                    'at': at,
                    'at_display': _stamp(at),
                    'reference': record.receipt_number or f'RCP-{record.pk}',
                    'branch': _branch_name(
                        getattr(batches[0].stock, 'branch', None)
                        if batches else None),
                    'party': record.patient_name or 'Unnamed patient',
                    'batch_number': lot_number,
                    'batch_id': None,
                    'stock_id': int(line.get('stock_id')),
                    'item': '',
                    'quantity': -int(line.get('qty') or 0),
                    'value': float(line.get('total') or 0) or None,
                    'detail': 'Dispensed to patient',
                })
    except Exception:
        pass

    # ── Sales orders (lot string only) ──────────────────────────────────
    try:
        from sales_orders.models import SalesOrder
        excluded = {SalesOrder.Status.DRAFT, SalesOrder.Status.CANCELLED}
        for order in (SalesOrder.objects
                      .exclude(status__in=excluded)
                      .filter(items__isnull=False)
                      .only('so_number', 'customer_name', 'items',
                            'created_at', 'status', 'branch_id', 'branch')):
            for line in order.items or []:
                try:
                    if int(line.get('stock_id') or 0) not in stock_ids:
                        continue
                except (TypeError, ValueError):
                    continue
                if str(line.get('batch_number') or '').strip().lower() != lot_key:
                    continue
                at = _dt(order.created_at)
                if not within(at):
                    continue
                events.append({
                    'kind': 'sales_order',
                    'at': at,
                    'at_display': _stamp(at),
                    'reference': order.so_number,
                    'branch': _branch_name(getattr(order, 'branch', None)),
                    'party': order.customer_name or 'Account customer',
                    'batch_number': lot_number,
                    'batch_id': None,
                    'stock_id': int(line.get('stock_id')),
                    'item': '',
                    'quantity': -int(line.get('qty') or 0),
                    'value': float(line.get('total') or 0) or None,
                    'detail': f'Order {order.get_status_display()}',
                })
    except Exception:
        pass

    # ── Manual adjustments (channel reasons are their own events) ───────
    if batch_ids:
        for row in (StockAdjustment.objects
                    .filter(batch_id__in=batch_ids)
                    .exclude(reason__in=CHANNEL_REASONS)
                    .select_related('batch', 'stock', 'adjusted_by')):
            at = _dt(row.created_at)
            if not within(at):
                continue
            change = int(row.quantity_change or 0)
            if not change:
                continue
            # Prefer the lot's own warehouse; fall back to the item's.
            lot_rows = [by_id[row.batch_id]] if row.batch_id in by_id else []
            source = lot_rows[0] if lot_rows else (batches[0] if batches else None)
            branch = _branch_name(
                getattr(source, 'branch', None)
                or getattr(getattr(source, 'stock', None), 'branch', None))
            events.append({
                'kind': 'adjustment_in' if change > 0 else 'adjustment_out',
                'at': at,
                'at_display': _stamp(at),
                'reference': f'ADJ-{row.pk:05d}',
                'branch': branch,
                'party': getattr(row.adjusted_by, 'full_name', '') or 'System',
                'batch_number': lot_number,
                'batch_id': row.batch_id,
                'stock_id': row.stock_id,
                'item': getattr(row.stock, 'medication_name', '') or '',
                'quantity': change,
                'detail': row.get_reason_display() + (
                    f' · {row.notes}' if row.notes else ''),
            })

    # A lot is identified by string too, so normalise what came back.
    for event in events:
        event['batch_number'] = event.get('batch_number') or lot_number
    return events


def _batch_positions(batches, events):
    """One row per physical lot: item, warehouse, and what remains there."""
    per_batch = defaultdict(lambda: {'sold': 0, 'moved': 0, 'adjusted': 0})
    for event in events:
        if not event.get('batch_id'):
            continue
        bucket = per_batch[event['batch_id']]
        if event['kind'] in ('sale', 'dispensed', 'sales_order'):
            bucket['sold'] += -event['quantity']
        elif event['kind'] == 'transfer_out':
            bucket['moved'] += -event['quantity']
        elif event['kind'] in ('adjustment_in', 'adjustment_out'):
            bucket['adjusted'] += event['quantity']

    today = timezone.localdate()
    rows = []
    for batch in batches:
        bucket = per_batch[batch.id]
        received = int(batch.quantity_received or 0)
        on_hand = int(batch.quantity_remaining or 0)
        expiry = batch.expiry_date
        days_to_expiry = (expiry - today).days if expiry else None
        rows.append({
            'batch_id': batch.id,
            'batch_number': batch.batch_number or '',
            'stock_id': batch.stock_id,
            'item': getattr(batch.stock, 'medication_name', '') or '',
            'medication_id': getattr(batch.stock, 'medication_id', '') or '',
            'branch': _branch_name(batch.branch
                                   or getattr(batch.stock, 'branch', None)),
            'supplier': getattr(batch.supplier, 'name', '') or '',
            'received_date': (batch.received_date.isoformat()
                              if batch.received_date else None),
            'expiry_date': expiry.isoformat() if expiry else None,
            'days_to_expiry': days_to_expiry,
            'received': received,
            'sold': bucket['sold'],
            'moved': bucket['moved'],
            'adjusted': bucket['adjusted'],
            'on_hand': on_hand,
            'sell_through_pct': round((bucket['sold'] / received * 100)
                                      if received else 0.0, 1),
            'unit_cost': float(batch.cost_price_per_unit or 0),
            'value_on_hand': round(on_hand * float(batch.cost_price_per_unit or 0), 2),
            'is_blocked': bool(batch.is_blocked),
            'blocked_reason': batch.blocked_reason or '',
            'status': ('quarantined' if batch.is_blocked
                       else 'expired' if days_to_expiry is not None and days_to_expiry < 0
                       else 'depleted' if on_hand <= 0
                       else 'in stock'),
        })
    rows.sort(key=lambda r: (r['branch'], r['item']))
    return rows


def _batch_anomalies(*, events, batches, reconciliation, lot_number):
    """Integrity findings specific to a lot.

    Deliberately *not* the item-level list: "no inbound lot recorded" is
    meaningless here because the lot is the subject, and a lot that was never
    received is a different and worse finding.
    """
    findings = []
    if not batches:
        findings.append({
            'severity': 'critical',
            'label': 'Lot not found in stock',
            'detail': (f'No stock lot carries the number {lot_number}. The units '
                       f'may have been fully written off, or the number was '
                       f'mistyped.'),
        })
        return findings

    if not reconciliation['tied'] and reconciliation.get('comparable', True):
        findings.append({
            'severity': 'high',
            'label': 'Lot ledger does not reconcile',
            'detail': (f'Received {reconciliation["received"]:,} and accounted '
                       f'for {reconciliation["explained"]:,} against '
                       f'{reconciliation["on_hand"]:,} physically on hand '
                       f'({reconciliation["residual"]:+,}). A movement for this '
                       f'lot is missing or double-counted.'),
        })

    # A lot with no supplier cannot be traced to a source, which is the first
    # thing a recall investigation asks.
    unknown = [b for b in batches if not getattr(b.supplier, 'name', '')
               and not (b.batch_number or '').upper().startswith('TRF-')]
    if unknown:
        findings.append({
            'severity': 'medium',
            'label': 'Lot has no supplier recorded',
            'detail': (f'{len(unknown)} lot row(s) name no supplier, so the '
                       f'source of these units cannot be identified.'),
        })

    negative = [b for b in batches if int(b.quantity_remaining or 0) < 0]
    if negative:
        findings.append({
            'severity': 'high',
            'label': 'Negative lot balance',
            'detail': f'{len(negative)} lot row(s) hold a negative quantity.',
        })

    blocked = [b for b in batches if b.is_blocked]
    if blocked:
        findings.append({
            'severity': 'medium',
            'label': 'Lot is quarantined',
            'detail': (f'{len(blocked)} lot row(s) are blocked from sale'
                       + (f': {blocked[0].blocked_reason}' if blocked[0].blocked_reason
                          else '.')),
        })

    today = timezone.localdate()
    expired_held = [b for b in batches
                    if b.expiry_date and (b.expiry_date - today).days < 0
                    and (b.quantity_remaining or 0) > 0]
    if expired_held:
        findings.append({
            'severity': 'high',
            'label': 'Expired units still on hand',
            'detail': (f'{sum(int(b.quantity_remaining or 0) for b in expired_held):,} '
                       f'expired unit(s) of this lot are still held and cannot '
                       f'be sold. Raise a write-off to clear them.'),
        })

    sold_expired = []
    for batch in batches:
        if not batch.expiry_date:
            continue
        for event in events:
            if (event.get('batch_id') == batch.id
                    and event['kind'] in ('sale', 'dispensed', 'sales_order')
                    and event['at'] and event['at'].date() > batch.expiry_date):
                sold_expired.append(event['reference'])
                break
    if sold_expired:
        findings.append({
            'severity': 'critical',
            'label': 'Units sold after expiry',
            'detail': (f'{len(sold_expired)} movement(s) took units of this lot '
                       f'out after the expiry date (e.g. {sold_expired[0]}). '
                       f'Those recipients may need to be contacted.'),
        })

    expiring_held = [b for b in batches
                     if b.expiry_date and 0 <= (b.expiry_date - today).days <= 30
                     and (b.quantity_remaining or 0) > 0]
    if expiring_held:
        findings.append({
            'severity': 'medium',
            'label': 'Lot expires within 30 days',
            'detail': (f'{sum(int(b.quantity_remaining or 0) for b in expiring_held):,} '
                       f'unit(s) expire inside a month. Prioritise them on the '
                       f'shelf or move them.'),
        })

    # Transfers re-lot at the destination under TRF-<reference>, so this lot
    # number stops at the warehouse gate. Saying so prevents a reader
    # concluding the units vanished.
    moved = [e for e in events if e['kind'] == 'transfer_out']
    if moved:
        findings.append({
            'severity': 'info',
            'label': 'Units transferred to another warehouse',
            'detail': (f'{len(moved)} transfer(s) moved units of this lot out. '
                       f'The receiving warehouse books them under a new lot '
                       f'reference (TRF-…), so this number ends at that '
                       f'warehouse boundary.'),
        })

    unlinked = [e for e in events
                if e['kind'] in ('sale', 'dispensed', 'sales_order')
                and not (e.get('batch_number') or '').strip()]
    if unlinked:
        findings.append({
            'severity': 'medium',
            'label': 'Outbound rows with no lot reference',
            'detail': (f'{len(unlinked)} outbound row(s) matched this item but '
                       f'carry no lot number, so they cannot be confirmed as '
                       f'part of this batch.'),
        })

    # Units leaving before the lot was received means the receipt date is
    # wrong or the stock was issued off-book - either way the chain of custody
    # has a hole at its first link.
    first_receipt = min((e['at'] for e in events if e['kind'] == 'receipt'
                         and e['at']), default=None)
    if first_receipt:
        early = [e for e in events
                 if e['kind'] in ('sale', 'dispensed', 'sales_order')
                 and e['at'] and e['at'] < first_receipt]
        if early:
            findings.append({
                'severity': 'medium',
                'label': 'Units left before the lot was received',
                'detail': (f'{len(early)} outbound row(s) predate the receipt '
                           f'(earliest {early[0]["reference"]} on '
                           f'{early[0]["at_display"]}). Either the receipt was '
                           f'backdated or the units were issued off-book.'),
            })
    return findings


def _batch_exposure(events):
    """Who received units of this lot - the recall call-list.

    Grouped by party so a pharmacist ringing round sees one line per customer
    rather than one per receipt line.
    """
    received = defaultdict(lambda: {'quantity': 0, 'references': [],
                                    'kind': '', 'last': None})
    for event in events:
        if event['kind'] not in ('sale', 'dispensed', 'sales_order'):
            continue
        quantity = -event['quantity']
        if quantity <= 0:
            continue
        party = event.get('party') or 'Unknown recipient'
        bucket = received[party]
        bucket['quantity'] += quantity
        if len(bucket['references']) < 8:
            bucket['references'].append(event['reference'])
        bucket['kind'] = event['kind']
        stamp = event.get('at_display') or ''
        if not bucket['last'] or stamp > bucket['last']:
            bucket['last'] = stamp

    rows = [{
        'party': party,
        'quantity': data['quantity'],
        'kind': data['kind'],
        'kind_label': EVENT_TYPES.get(data['kind'], {}).get('label', data['kind']),
        'references': data['references'],
        'last': data['last'] or '',
    } for party, data in received.items()]
    rows.sort(key=lambda r: -r['quantity'])
    return rows


def trace_batch(lot_number, batches, *, date_from=None, date_to=None,
                limit_days=None):
    """Full life of one lot number, across every item and warehouse holding it.

    ``batches`` is the resolved, already branch-scoped list of ``StockBatch``
    rows for ``lot_number``; the view owns that lookup so scoping stays in one
    place. Read-only.
    """
    if limit_days and not date_from:
        date_from = timezone.localdate() - timedelta(days=limit_days)

    def within(value):
        if not value:
            return True
        day = value.date() if hasattr(value, 'date') else value
        if date_from and day < date_from:
            return False
        if date_to and day > date_to:
            return False
        return True

    windowed = bool(date_from or date_to)
    events = _batch_events(batches, lot_number, within)
    events.sort(key=lambda e: (e['at'] or timezone.now(), e['reference']))

    for event in events:
        meta = EVENT_TYPES.get(event['kind'], {})
        event.setdefault('label', meta.get('label', event['kind']))
        event.setdefault('icon', meta.get('icon', 'mdi-circle-small'))
        event.setdefault('value', None)

    balance = 0
    previous = 'genesis'
    for index, event in enumerate(events, start=1):
        balance += event['quantity']
        event['seq'] = index
        event['balance'] = balance
        event['hash'] = _digest({
            'seq': index,
            'kind': event['kind'],
            'at': event['at_display'],
            'reference': event['reference'],
            'branch': event['branch'],
            'quantity': event['quantity'],
            'batch_number': event['batch_number'],
            'party': event['party'],
            'prev': previous,
        })
        previous = event['hash']

    positions = _batch_positions(batches, events)

    received = sum(int(b.quantity_received or 0) for b in batches)
    on_hand = sum(int(b.quantity_remaining or 0) for b in batches)
    sold = sum(-e['quantity'] for e in events
               if e['kind'] in ('sale', 'dispensed', 'sales_order'))
    moved_out = sum(-e['quantity'] for e in events
                    if e['kind'] == 'transfer_out')
    adjusted = sum(e['quantity'] for e in events
                   if e['kind'] in ('adjustment_in', 'adjustment_out'))

    reconciliation = _reconciliation(
        received=received, sold=sold, moved_out=moved_out, adjusted=adjusted,
        on_hand=on_hand, windowed=windowed)

    exposure = _batch_exposure(events)
    today = timezone.localdate()
    expiries = [b.expiry_date for b in batches if b.expiry_date]
    expiry = min(expiries, default=None)
    received_dates = [b.received_date for b in batches if b.received_date]

    summary = {
        'batch_number': lot_number,
        'items': len({b.stock_id for b in batches if b.stock_id}),
        'item_names': sorted({getattr(b.stock, 'medication_name', '') or ''
                              for b in batches if b.stock_id}),
        'branches': len({_branch_name(b.branch
                                     or getattr(b.stock, 'branch', None))
                         for b in batches}),
        'branch_names': sorted({_branch_name(b.branch
                                            or getattr(b.stock, 'branch', None))
                                for b in batches}),
        'lot_rows': len(batches),
        'received': received,
        'on_hand': on_hand,
        'sold': sold,
        'moved_out': moved_out,
        'adjusted': adjusted,
        'sell_through_pct': round((sold / received * 100) if received else 0.0, 1),
        'expiry_date': expiry.isoformat() if expiry else None,
        'days_to_expiry': (expiry - today).days if expiry else None,
        'first_received': (min(received_dates).isoformat()
                           if received_dates else None),
        'suppliers': sorted({getattr(b.supplier, 'name', '') or ''
                             for b in batches} - {''}),
        'quarantined': sum(int(b.quantity_remaining or 0) for b in batches
                           if b.is_blocked),
        'expired': sum(int(b.quantity_remaining or 0) for b in batches
                       if b.expiry_date and (b.expiry_date - today).days < 0),
        'value_on_hand': round(sum(r['value_on_hand'] for r in positions), 2),
        'recipients': len(exposure),
        'units_downstream': sum(r['quantity'] for r in exposure),
        'events': len(events),
        'custody_digest': previous if previous != 'genesis' else '',
    }

    return {
        'summary': summary,
        'events': [{k: v for k, v in e.items() if k != 'at'} for e in events],
        'positions': positions,
        'exposure': exposure,
        'reconciliation': reconciliation,
        'anomalies': _batch_anomalies(
            events=events, batches=batches, reconciliation=reconciliation,
            lot_number=lot_number),
        'event_types': EVENT_TYPES,
    }

