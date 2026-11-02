"""Row builders for every report in the catalog.

Each builder has the same signature::

    build(request, *, date_from=None, date_to=None, branch_id=None) -> dict

and returns ``{'rows': [...], 'totals': {...}, 'meta': {...}}``. Rows are plain
dicts keyed by the catalog's column keys, so the PDF, the spreadsheet and the
JSON preview all consume exactly the same data — a report can never print a
different number from the one the screen shows.

Cost-derived columns are stripped for roles without the ``stock.cost``
capability (``can_view_cost``), the same rule the stock serializers apply.
"""
from __future__ import annotations

from collections import defaultdict
from datetime import date, datetime, time, timedelta
from decimal import Decimal

from django.db.models import Count, Q, Sum
from django.utils import timezone


# ── Shared helpers ──────────────────────────────────────────────────────
def parse_date(value):
    """``YYYY-MM-DD`` → :class:`datetime.date` (``None`` when unusable)."""
    if not value:
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    try:
        return datetime.strptime(str(value).strip()[:10], '%Y-%m-%d').date()
    except (TypeError, ValueError):
        return None


def _aware_range(date_from=None, date_to=None):
    """Inclusive ``(start_datetime, end_datetime)`` for a filter range."""
    start = parse_date(date_from)
    end = parse_date(date_to)
    start_dt = (timezone.make_aware(datetime.combine(start, time.min))
                if start else None)
    end_dt = (timezone.make_aware(datetime.combine(end, time.max))
              if end else None)
    return start_dt, end_dt


def _status_of(stock) -> str:
    """Canonical stock status — same rule as ``utils/stockStatus.js``."""
    if stock.available_quantity <= 0:
        return 'Out of stock' if not stock.expired_quantity else 'Expired'
    if stock.available_quantity <= (stock.reorder_level or 0):
        return 'Low'
    return 'In stock'


def _num(value, default=0):
    try:
        return float(value or default)
    except (TypeError, ValueError):
        return float(default)


def _int(value, default=0):
    try:
        return int(value or default)
    except (TypeError, ValueError):
        return int(default)


def _scoped_stocks(branch_id):
    """Active stock items, annotated with batch quantities."""
    from ..models import MedicationStock

    qs = (MedicationStock.objects.with_quantities()
          .filter(is_active=True)
          .select_related('category', 'unit', 'branch', 'classification'))
    if branch_id:
        qs = qs.filter(Q(branch_id=branch_id) | Q(branch__isnull=True))
    return qs


def _next_expiry(stock) -> date | None:
    """Earliest expiry among the item's live batches."""
    today = timezone.localdate()
    batch = (stock.batches
             .filter(quantity_remaining__gt=0, is_blocked=False,
                     expiry_date__isnull=False, expiry_date__gte=today)
             .order_by('expiry_date')
             .first())
    return batch.expiry_date if batch else None


def _value_at_retail(stock) -> float:
    return _num(stock.total_quantity) * _num(stock.selling_price)


# ══════════════════════════════════════════════════════════════════════
#  Stock & valuation
# ══════════════════════════════════════════════════════════════════════
def build_stock_on_hand(request, *, date_from=None, date_to=None, branch_id=None):
    stocks = list(_scoped_stocks(branch_id))
    rows, status_counts = [], defaultdict(int)
    totals = {'total_quantity': 0, 'sellable_quantity': 0,
              'expired_quantity': 0, 'available_quantity': 0,
              'value_cost': 0.0, 'value_retail': 0.0}

    for s in stocks:
        status = _status_of(s)
        status_counts[status] += 1
        qty = _int(s.total_quantity)
        cost_value = qty * _num(s.cost_price)
        retail_value = _value_at_retail(s)
        totals['total_quantity'] += qty
        totals['sellable_quantity'] += _int(s.sellable_quantity)
        totals['expired_quantity'] += _int(s.expired_quantity)
        totals['available_quantity'] += _int(s.available_quantity)
        totals['value_cost'] += cost_value
        totals['value_retail'] += retail_value
        rows.append({
            'medication_id': s.medication_id,
            'medication_name': s.medication_name,
            'strength': s.strength or '',
            'category': s.category.name if s.category_id else 'Uncategorised',
            'classification': s.classification.name if s.classification_id else '',
            'branch': s.branch.name if s.branch_id else '',
            'unit': s.unit.abbreviation if s.unit_id else '',
            'location': s.location_in_store or '',
            'barcode': s.barcode or '',
            'total_quantity': qty,
            'sellable_quantity': _int(s.sellable_quantity),
            'expired_quantity': _int(s.expired_quantity),
            'committed_quantity': _int(s.committed_qty),
            'available_quantity': _int(s.available_quantity),
            'reorder_level': _int(s.reorder_level),
            'cost_price': _num(s.cost_price),
            'selling_price': _num(s.selling_price),
            'value_cost': round(cost_value, 2),
            'value_retail': round(retail_value, 2),
            'status': status,
            'next_expiry': _next_expiry(s),
        })

    return {
        'rows': rows,
        'totals': {k: (round(v, 2) if isinstance(v, float) else v)
                   for k, v in totals.items()},
        'meta': {'items': len(rows),
                 'status_counts': dict(status_counts)},
    }


def build_valuation(request, *, date_from=None, date_to=None, branch_id=None):
    from ..services.valuation import stock_unit_cost
    from ..models import InventorySettings

    method = InventorySettings.get().valuation_method
    stocks = list(_scoped_stocks(branch_id))
    rows = []
    totals = {'value_cost': 0.0, 'value_retail': 0.0, 'margin': 0.0}

    for s in stocks:
        qty = _int(s.total_quantity)
        if qty <= 0:
            continue
        unit_cost = float(stock_unit_cost(s, method))
        cost_value = unit_cost * qty
        retail_value = _num(s.selling_price) * qty
        margin = retail_value - cost_value
        totals['value_cost'] += cost_value
        totals['value_retail'] += retail_value
        totals['margin'] += margin
        rows.append({
            'medication_id': s.medication_id,
            'medication_name': s.medication_name,
            'strength': s.strength or '',
            'category': s.category.name if s.category_id else 'Uncategorised',
            'classification': s.classification.name if s.classification_id else '',
            'branch': s.branch.name if s.branch_id else '',
            'quantity': qty,
            'unit_cost': round(unit_cost, 2),
            'value_cost': round(cost_value, 2),
            'value_retail': round(retail_value, 2),
            'margin': round(margin, 2),
            'margin_pct': round((margin / retail_value) * 100, 1) if retail_value else 0.0,
        })

    rows.sort(key=lambda r: -r['value_cost'])
    totals['value_cost'] = round(totals['value_cost'], 2)
    totals['value_retail'] = round(totals['value_retail'], 2)
    totals['margin'] = round(totals['margin'], 2)
    totals['margin_pct'] = (round(totals['margin'] / totals['value_retail'] * 100, 1)
                            if totals['value_retail'] else 0.0)
    return {'rows': rows, 'totals': totals,
            'meta': {'method': method, 'items': len(rows)}}


def build_dead_stock(request, *, date_from=None, date_to=None, branch_id=None):
    from ..models import InventorySettings
    from ..services.demand import last_movement_at

    window = _int(InventorySettings.get().stale_days, 90)
    last_move = last_movement_at(days=max(400, window + 60))
    cutoff = timezone.localdate() - timedelta(days=window)

    rows = []
    total_value = 0.0
    for s in _scoped_stocks(branch_id):
        qty = _int(s.total_quantity)
        if qty <= 0:
            continue
        moved = last_move.get(s.id)
        reference = moved or (s.created_at.date() if s.created_at else None)
        if reference and reference > cutoff:
            continue
        value = qty * _num(s.cost_price)
        total_value += value
        rows.append({
            'medication_id': s.medication_id,
            'medication_name': s.medication_name,
            'strength': s.strength or '',
            'category': s.category.name if s.category_id else 'Uncategorised',
            'classification': s.classification.name if s.classification_id else '',
            'branch': s.branch.name if s.branch_id else '',
            'quantity': qty,
            'value_cost': round(value, 2),
            'last_sold': moved or None,
            'days_idle': ((timezone.localdate() - reference).days
                          if reference else None),
        })

    rows.sort(key=lambda r: -(r['days_idle'] or 0))
    return {'rows': rows,
            'totals': {'value_cost': round(total_value, 2), 'items': len(rows)},
            'meta': {'window_days': window, 'cutoff': cutoff.isoformat()}}


# ══════════════════════════════════════════════════════════════════════
#  Operations
# ══════════════════════════════════════════════════════════════════════
_TYPE_LABELS = {
    'pos_sale': 'Sale', 'dispensing': 'Dispensing', 'return': 'Return',
    'dispense_return': 'Return', 'sales_order': 'Sales order',
    'branch_transfer': 'Transfer', 'transfer_shortage': 'Transfer shortage',
    'purchase_order': 'Receipt', 'receipt': 'Receipt',
}


def build_movements(request, *, date_from=None, date_to=None, branch_id=None):
    """Unified ledger: every quantity change in one stream.

    Outflows come from ``StockAdjustment`` (sales channels write their rows
    there now); inflows come from the batches that were actually received, so
    a partial GRN reports what arrived rather than what was ordered.
    """
    from ..models import StockAdjustment, StockBatch

    start_dt, end_dt = _aware_range(date_from, date_to)
    rows = []
    totals = {'quantity_in': 0, 'quantity_out': 0, 'value_in': 0.0,
              'value_out': 0.0}

    adj = (StockAdjustment.objects
           .select_related('stock', 'stock__branch', 'stock__unit', 'batch',
                           'adjusted_by'))
    if start_dt:
        adj = adj.filter(created_at__gte=start_dt)
    if end_dt:
        adj = adj.filter(created_at__lte=end_dt)
    if branch_id:
        adj = adj.filter(Q(stock__branch_id=branch_id)
                         | Q(stock__branch__isnull=True))

    for a in adj:
        qty = _int(a.quantity_change)
        unit_cost = _num(getattr(a.batch, 'cost_price_per_unit', None)
                         or (a.stock.cost_price if a.stock_id else 0))
        value = abs(qty) * unit_cost
        if qty >= 0:
            totals['quantity_in'] += qty
            totals['value_in'] += value
        else:
            totals['quantity_out'] += -qty
            totals['value_out'] += value
        rows.append({
            'occurred_at': a.created_at,
            'movement_type': 'Inflow' if qty >= 0 else 'Outflow',
            'reason': a.get_reason_display() if a.reason else 'Other',
            'medication_name': a.stock.medication_name if a.stock_id else '',
            'batch_number': a.batch.batch_number if a.batch_id else '',
            'reference': f'ADJ-{a.pk}',
            'branch': (a.stock.branch.name
                       if a.stock_id and a.stock.branch_id else ''),
            'quantity_in': qty if qty > 0 else 0,
            'quantity_out': -qty if qty < 0 else 0,
            'unit_cost': round(unit_cost, 2),
            'value': round(value, 2),
            'user': getattr(a.adjusted_by, 'full_name', '') or 'System',
        })

    batches = (StockBatch.objects
               .select_related('stock', 'stock__branch', 'supplier'))
    if start_dt:
        batches = batches.filter(received_date__gte=start_dt.date())
    if end_dt:
        batches = batches.filter(received_date__lte=end_dt.date())
    if branch_id:
        batches = batches.filter(Q(branch_id=branch_id) | Q(branch__isnull=True))

    for b in batches:
        # Returns are already represented by their ledger row.
        if (b.batch_number or '').upper().startswith('RET-'):
            continue
        qty = _int(b.quantity_received)
        if qty <= 0:
            continue
        unit_cost = _num(b.cost_price_per_unit)
        value = qty * unit_cost
        totals['quantity_in'] += qty
        totals['value_in'] += value
        rows.append({
            'occurred_at': timezone.make_aware(
                datetime.combine(b.received_date, time.min)),
            'movement_type': 'Inflow',
            'reason': 'Stock received',
            'medication_name': b.stock.medication_name if b.stock_id else '',
            'batch_number': b.batch_number or '',
            'reference': b.batch_number or f'BATCH-{b.pk}',
            'branch': b.branch.name if b.branch_id else (
                b.stock.branch.name if b.stock_id and b.stock.branch_id else ''),
            'quantity_in': qty,
            'quantity_out': 0,
            'unit_cost': round(unit_cost, 2),
            'value': round(value, 2),
            'user': b.supplier.name if b.supplier_id else 'Receiving',
        })

    rows.sort(key=lambda r: r['occurred_at'] or timezone.now(), reverse=True)
    totals = {k: (round(v, 2) if isinstance(v, float) else v)
              for k, v in totals.items()}
    totals['net_quantity'] = totals['quantity_in'] - totals['quantity_out']
    return {'rows': rows, 'totals': totals, 'meta': {'lines': len(rows)}}


def build_adjustments(request, *, date_from=None, date_to=None, branch_id=None):
    from ..models import StockAdjustment

    start_dt, end_dt = _aware_range(date_from, date_to)
    qs = (StockAdjustment.objects
          .select_related('stock', 'stock__branch', 'batch', 'adjusted_by'))
    if start_dt:
        qs = qs.filter(created_at__gte=start_dt)
    if end_dt:
        qs = qs.filter(created_at__lte=end_dt)
    if branch_id:
        qs = qs.filter(Q(stock__branch_id=branch_id)
                       | Q(stock__branch__isnull=True))

    rows, by_reason = [], defaultdict(float)
    total_value = 0.0
    for a in qs:
        qty = _int(a.quantity_change)
        unit_cost = _num(getattr(a.batch, 'cost_price_per_unit', None)
                         or (a.stock.cost_price if a.stock_id else 0))
        value = abs(qty) * unit_cost
        total_value += value
        label = a.get_reason_display() if a.reason else 'Other'
        by_reason[label] += value
        rows.append({
            'created_at': a.created_at,
            'reason_label': label,
            'medication_name': a.stock.medication_name if a.stock_id else '',
            'batch_number': a.batch.batch_number if a.batch_id else '',
            'quantity_change': qty,
            'value': round(value, 2),
            'branch': (a.stock.branch.name
                       if a.stock_id and a.stock.branch_id else ''),
            'user': getattr(a.adjusted_by, 'full_name', '') or 'System',
            'notes': a.notes or '',
        })

    return {
        'rows': rows,
        'totals': {'value': round(total_value, 2), 'lines': len(rows)},
        'meta': {'by_reason': {k: round(v, 2)
                               for k, v in sorted(by_reason.items(),
                                                  key=lambda x: -x[1])}},
    }


def build_transfers(request, *, date_from=None, date_to=None, branch_id=None):
    from ..models import StockTransfer

    start_dt, end_dt = _aware_range(date_from, date_to)
    qs = (StockTransfer.objects
          .select_related('source_branch', 'dest_branch')
          .prefetch_related('lines__stock'))
    if start_dt:
        qs = qs.filter(requested_at__gte=start_dt)
    if end_dt:
        qs = qs.filter(requested_at__lte=end_dt)
    if branch_id:
        qs = qs.filter(Q(source_branch_id=branch_id) | Q(dest_branch_id=branch_id))

    rows = []
    totals = {'units_sent': 0, 'units_received': 0, 'variance': 0,
              'value': 0.0}
    for t in qs:
        lines = list(t.lines.all())
        sent = sum(_int(l.quantity) for l in lines)
        received = sum(_int(l.quantity_received) for l in lines)
        value = sum(_int(l.quantity) * _num(l.stock.cost_price)
                    for l in lines if l.stock_id)
        completed = t.status == StockTransfer.Status.COMPLETED
        variance = (received - sent) if completed else 0
        totals['units_sent'] += sent
        totals['units_received'] += received if completed else 0
        totals['variance'] += variance
        totals['value'] += value
        rows.append({
            'requested_at': t.requested_at,
            'reference': t.reference or f'TRF-{t.pk}',
            'status': t.get_status_display() if t.status else '',
            'source_branch': t.source_branch.name if t.source_branch_id else '',
            'dest_branch': t.dest_branch.name if t.dest_branch_id else '',
            'priority': t.get_priority_display() if t.priority else '',
            'lines': len(lines),
            'units_sent': sent,
            'units_received': received if completed else 0,
            'variance': variance,
            'value': round(value, 2),
        })

    totals['value'] = round(totals['value'], 2)
    return {'rows': rows, 'totals': totals, 'meta': {'transfers': len(rows)}}


def build_cycle_count(request, *, date_from=None, date_to=None, branch_id=None):
    from ..models import InventoryCountLine

    start_dt, end_dt = _aware_range(date_from, date_to)
    qs = (InventoryCountLine.objects
          .select_related('count', 'count__branch', 'stock')
          .exclude(counted_quantity__isnull=True)
          .filter(count__status='completed'))
    if start_dt:
        qs = qs.filter(count__completed_at__gte=start_dt)
    if end_dt:
        qs = qs.filter(count__completed_at__lte=end_dt)
    if branch_id:
        qs = qs.filter(count__branch_id=branch_id)

    rows = []
    totals = {'variance': 0, 'variance_value': 0.0, 'lines': 0}
    for line in qs:
        variance = line.variance
        value = _num(line.variance_value)
        totals['variance'] += variance
        totals['variance_value'] += value
        totals['lines'] += 1
        rows.append({
            'completed_at': line.count.completed_at,
            'reference': line.count.reference,
            'medication_name': line.stock.medication_name if line.stock_id else '',
            'expected_quantity': _int(line.expected_quantity),
            'counted_quantity': _int(line.counted_quantity),
            'variance': variance,
            'variance_value': round(value, 2),
            'branch': (line.count.branch.name
                       if line.count.branch_id else ''),
        })

    totals['variance_value'] = round(totals['variance_value'], 2)
    return {'rows': rows, 'totals': totals, 'meta': {'lines': len(rows)}}


# ══════════════════════════════════════════════════════════════════════
#  Expiry & compliance
# ══════════════════════════════════════════════════════════════════════
def _expiry_risk(days_left) -> str:
    if days_left is None:
        return 'No date'
    if days_left < 0:
        return 'Expired'
    if days_left <= 7:
        return 'Critical'
    if days_left <= 30:
        return 'High'
    if days_left <= 90:
        return 'Watch'
    return 'OK'


def build_expiry(request, *, date_from=None, date_to=None, branch_id=None):
    from ..models import StockBatch

    today = timezone.localdate()
    qs = (StockBatch.objects
          .filter(quantity_remaining__gt=0, expiry_date__isnull=False)
          .select_related('stock', 'stock__branch', 'stock__category',
                          'branch', 'supplier'))
    if branch_id:
        qs = qs.filter(Q(branch_id=branch_id) | Q(branch__isnull=True))
    # Expiry is date-scoped on the *expiry date*, not on when the batch
    # arrived: "what falls due between these dates". Without the lower bound a
    # from-date silently did nothing.
    horizon = parse_date(date_to)
    if horizon:
        qs = qs.filter(expiry_date__lte=horizon)
    floor = parse_date(date_from)
    if floor:
        qs = qs.filter(expiry_date__gte=floor)

    rows = []
    totals = {'quantity_remaining': 0, 'value': 0.0}
    risk_counts = defaultdict(int)
    for b in qs.order_by('expiry_date'):
        days_left = (b.expiry_date - today).days
        qty = _int(b.quantity_remaining)
        unit_cost = _num(b.cost_price_per_unit)
        value = qty * unit_cost
        risk = _expiry_risk(days_left)
        risk_counts[risk] += 1
        totals['quantity_remaining'] += qty
        totals['value'] += value
        rows.append({
            'medication_name': b.stock.medication_name if b.stock_id else '',
            'strength': (b.stock.strength if b.stock_id else '') or '',
            'category': (b.stock.category.name
                         if b.stock_id and b.stock.category_id
                         else 'Uncategorised'),
            'batch_number': b.batch_number or '',
            'expiry_date': b.expiry_date,
            'days_to_expiry': days_left,
            'quantity_remaining': qty,
            'unit_cost': round(unit_cost, 2),
            'value': round(value, 2),
            'risk': risk,
            'branch': b.branch.name if b.branch_id else (
                b.stock.branch.name if b.stock_id and b.stock.branch_id else ''),
        })

    totals['value'] = round(totals['value'], 2)
    return {'rows': rows, 'totals': totals,
            'meta': {'batches': len(rows), 'risk_counts': dict(risk_counts)}}


def build_low_stock(request, *, date_from=None, date_to=None, branch_id=None):
    rows = []
    status_counts = defaultdict(int)
    total_shortfall = 0
    for s in _scoped_stocks(branch_id):
        available = _int(s.available_quantity)
        reorder = _int(s.reorder_level)
        if available > reorder:
            continue
        status = _status_of(s)
        status_counts[status] += 1
        shortfall = max(0, reorder - available)
        total_shortfall += shortfall
        rows.append({
            'medication_id': s.medication_id,
            'medication_name': s.medication_name,
            'strength': s.strength or '',
            'category': s.category.name if s.category_id else 'Uncategorised',
            'classification': s.classification.name if s.classification_id else '',
            'branch': s.branch.name if s.branch_id else '',
            'available_quantity': available,
            'reorder_level': reorder,
            'shortfall': shortfall,
            'status': status,
        })

    rows.sort(key=lambda r: -r['shortfall'])
    return {'rows': rows,
            'totals': {'items': len(rows), 'shortfall': total_shortfall},
            'meta': {'status_counts': dict(status_counts)}}


def build_controlled_register(request, *, date_from=None, date_to=None,
                              branch_id=None):
    from ..models import ControlledSubstanceLog

    start_dt, end_dt = _aware_range(date_from, date_to)
    qs = ControlledSubstanceLog.objects.select_related('recorded_by')
    if start_dt:
        qs = qs.filter(created_at__gte=start_dt)
    if end_dt:
        qs = qs.filter(created_at__lte=end_dt)

    rows = []
    by_action = defaultdict(float)
    for log in qs:
        action = log.get_action_display() if log.action else ''
        by_action[action] += _num(log.quantity)
        rows.append({
            'created_at': log.created_at,
            'medication_name': log.medication_name,
            'schedule': log.schedule or '',
            'action': action,
            'quantity': _num(log.quantity),
            'batch_number': log.batch_number or '',
            'patient_name': log.patient_name or '',
            'prescriber_name': log.prescriber_name or '',
            'prescription_reference': log.prescription_reference or '',
            'user': getattr(log.recorded_by, 'full_name', '') or 'System',
        })

    return {'rows': rows,
            'totals': {'records': len(rows)},
            'meta': {'by_action': {k: round(v, 2)
                                   for k, v in by_action.items()}}}


# ══════════════════════════════════════════════════════════════════════
#  Planning & suppliers
# ══════════════════════════════════════════════════════════════════════
def build_replenishment(request, *, date_from=None, date_to=None,
                        branch_id=None):
    from ..services import replenishment

    payload = replenishment.build_suggestions(
        branch_id=branch_id, write=False)
    rows = [{
        'medication_name': r['medication_name'],
        'branch': r['branch_name'],
        'on_hand': r['on_hand'],
        'on_order': r['on_order'],
        'reorder_point': r['reorder_point'],
        'days_cover': r['days_cover'],
        'suggested_quantity': r['suggested_quantity'],
        'unit_cost': r['unit_cost'],
        'estimated_cost': r['estimated_cost'],
        'supplier_name': r['supplier_name'] or 'No supplier',
        'severity': (r['severity'] or '').title(),
    } for r in payload['rows']]

    totals = {
        'lines': len(rows),
        'suggested_quantity': sum(_int(r['suggested_quantity']) for r in rows),
        'estimated_cost': round(sum(_num(r['estimated_cost']) for r in rows), 2),
    }
    return {'rows': rows, 'totals': totals,
            'meta': {'summary': payload['summary']}}


def build_abc_analysis(request, *, date_from=None, date_to=None, branch_id=None):
    """ABC/XYZ classification, optionally recomputed for a date window.

    Without a window the stored ``StockPolicy`` snapshot is echoed (it is a
    whole-catalogue statement, so a period would be meaningless). With one, the
    classes are recomputed from **consumption inside that window**: ABC from the
    Pareto of consumption value, XYZ from the coefficient of variation of the
    daily demand series. That is the only way the period control can honestly
    change the letters — a stored snapshot has no date dimension.

    Two different value bases therefore exist, and the report must say which one
    it is using:

    * windowed  → **consumption value** (units sold in the window x unit cost),
      the measure the letters were just computed from;
    * snapshot  → **on-hand capital** (units on the shelf x unit cost), the
      measure ``services.planning`` stores ``value_share`` and ``abc_class``
      from.

    Both are absolute figures, so the Pareto chart and the class shares are real
    money either way — the stored snapshot only carries a *share*, which is
    useless as a chart axis.
    """
    from ..models import StockBatch, StockPolicy
    from ..services import demand as demand_service
    from ..services import forecasting

    floor = parse_date(date_from)
    ceiling = parse_date(date_to)
    windowed = bool(floor or ceiling)

    qs = (StockPolicy.objects
          .select_related('stock', 'stock__branch'))
    if branch_id:
        qs = qs.filter(stock__branch_id=branch_id)

    policies = list(qs)

    # ── Window-scoped reclassification ──────────────────────────────────
    usage = {}
    start, end = None, None
    if windowed and policies:
        start, end = demand_service._window(90, floor, ceiling)
        usage = demand_service.usage_by_stock(
            branch_id=branch_id, date_from=start, date_to=end)

    # ── Absolute value basis ────────────────────────────────────────────
    # One aggregate for the whole catalogue; asking each policy for
    # ``stock.total_quantity`` would fire a query per row.
    on_hand_by_stock = dict(
        StockBatch.objects
        .filter(quantity_remaining__gt=0)
        .values('stock_id')
        .annotate(q=Sum('quantity_remaining'))
        .values_list('stock_id', 'q'))

    def cost_of(policy):
        return _num(getattr(policy.stock, 'cost_price', 0)) if policy.stock_id else 0.0

    if windowed:
        values = []
        for p in policies:
            qty = sum(usage.get(p.stock_id, {}).values()) if p.stock_id else 0
            values.append(qty * cost_of(p))
        basis = 'consumption'
    else:
        values = [(on_hand_by_stock.get(p.stock_id) or 0) * cost_of(p)
                  for p in policies]
        basis = 'on_hand'

    total_value = sum(values)
    letters = (forecasting.abc_classes(values) if windowed
               else [p.abc_class for p in policies])

    rows = []
    abc_counts = defaultdict(int)
    xyz_counts = defaultdict(int)
    by_class = {k: {'count': 0, 'value': 0.0, 'avg_daily': 0.0, 'units': 0}
                for k in ('A', 'B', 'C')}
    by_xyz = {k: {'count': 0, 'value': 0.0, 'avg_daily': 0.0}
              for k in ('X', 'Y', 'Z')}
    matrix = {f'{a}{x}': {'count': 0, 'value': 0.0}
              for a in 'ABC' for x in 'XYZ'}

    for index, p in enumerate(policies):
        value = values[index]
        if windowed:
            abc_class = letters[index]
            share = (value / total_value) if total_value else 0.0
            series = demand_service_series(usage, p.stock_id, start, end)
            stats = forecasting.summarise_series(series)
            xyz_class = forecasting.classify_xyz(float(stats['cv']))
            avg_daily = round(float(stats['avg']), 2)
        else:
            abc_class = p.abc_class or 'C'
            share = _num(p.value_share)
            xyz_class = p.xyz_class or 'X'
            avg_daily = round(_num(p.avg_daily_demand), 2)

        abc_counts[abc_class] += 1
        xyz_counts[xyz_class] += 1

        bucket = by_class.setdefault(abc_class, {
            'count': 0, 'value': 0.0, 'avg_daily': 0.0, 'units': 0})
        bucket['count'] += 1
        bucket['value'] += value
        bucket['avg_daily'] += avg_daily
        bucket['units'] += int(on_hand_by_stock.get(p.stock_id) or 0)

        xyz_bucket = by_xyz.setdefault(xyz_class, {
            'count': 0, 'value': 0.0, 'avg_daily': 0.0})
        xyz_bucket['count'] += 1
        xyz_bucket['value'] += value
        xyz_bucket['avg_daily'] += avg_daily

        cell = matrix.setdefault(f'{abc_class}{xyz_class}',
                                 {'count': 0, 'value': 0.0})
        cell['count'] += 1
        cell['value'] += value

        rows.append({
            'medication_name': p.stock.medication_name if p.stock_id else '',
            'abc_class': abc_class,
            'xyz_class': xyz_class,
            'value_share_pct': round(share * 100, 1),
            'avg_daily_demand': avg_daily,
            'reorder_point': round(_num(p.reorder_point), 1),
            'safety_stock': round(_num(p.safety_stock), 1),
            'eoq': round(_num(p.eoq), 1),
            'lead_time_days': _int(p.lead_time_days),
            'forecast_mape': (round(_num(p.forecast_mape), 1)
                              if p.forecast_mape is not None else None),
            'branch': (p.stock.branch.name
                       if p.stock_id and p.stock.branch_id else ''),
        })

    # Keep each row glued to the value it was classified on: the display order
    # is (class, share) while the Pareto order is raw value, and indexing a
    # separate ``values`` list by row position after re-sorting silently
    # attached the wrong value to every item.
    pairs = list(zip(rows, values))
    rows.sort(key=lambda r: (r['abc_class'], -r['value_share_pct']))

    # ── Pareto curve (sorted high → low, cumulative share) ──────────────
    ranked = sorted(pairs, key=lambda pair: -pair[1])
    pareto, cumulative, items_for_80, items_for_90 = [], 0.0, None, None
    item_count = len(ranked) or 1
    for position, (row, value) in enumerate(ranked, start=1):
        cumulative += value
        pct = (cumulative / total_value * 100) if total_value else 0.0
        if items_for_80 is None and pct >= 80:
            items_for_80 = position
        if items_for_90 is None and pct >= 90:
            items_for_90 = position
        pareto.append({
            'label': row['medication_name'],
            'value': round(value, 2),
            'cumulative_pct': round(pct, 1),
            'position': position,
        })

    # A curve with one point per SKU is unreadable at print size; sample it
    # down to ~40 points once the catalogue gets large, always keeping the
    # first and the last.
    curve = pareto
    if len(curve) > 40:
        step = (len(curve) - 1) / 39.0
        curve = [curve[min(int(round(i * step)), len(curve) - 1)]
                 for i in range(40)]

    # ── Class and matrix summaries with shares ──────────────────────────
    def pack(bucket):
        value = bucket['value']
        return {
            'count': bucket['count'],
            'value': round(value, 2),
            'value_pct': round((value / total_value * 100) if total_value else 0, 1),
            'items_pct': round(bucket['count'] / item_count * 100, 1),
            'avg_daily': round(bucket['avg_daily'], 2),
            'units': int(bucket.get('units') or 0),
            'avg_value': round(value / bucket['count'], 2) if bucket['count'] else 0,
        }

    class_summary = [
        {'cls': key, **pack(by_class.get(key) or
                            {'count': 0, 'value': 0.0, 'avg_daily': 0.0,
                             'units': 0})}
        for key in 'ABC'
    ]
    xyz_summary = [
        {'cls': key, **pack(by_xyz.get(key) or
                            {'count': 0, 'value': 0.0, 'avg_daily': 0.0})}
        for key in 'XYZ'
    ]
    matrix_summary = [
        {'abc': cell[0], 'xyz': cell[1],
         'count': matrix[cell]['count'],
         'value': round(matrix[cell]['value'], 2),
         'value_pct': round((matrix[cell]['value'] / total_value * 100)
                            if total_value else 0, 1)}
        for cell in (f'{a}{x}' for a in 'ABC' for x in 'XYZ')
    ]

    return {
        'rows': rows,
        'totals': {'items': len(rows), 'value': round(total_value, 2)},
        'meta': {
            'abc_counts': dict(abc_counts),
            'xyz_counts': dict(xyz_counts),
            'windowed': windowed,
            'window_start': start.isoformat() if start else None,
            'window_end': end.isoformat() if end else None,
            'value_basis': basis,
            'total_value': round(total_value, 2),
            'class_summary': class_summary,
            'xyz_summary': xyz_summary,
            'matrix': matrix_summary,
            'pareto': curve,
            'concentration': {
                'items': len(rows),
                'items_for_80': items_for_80,
                'items_for_90': items_for_90,
                'pct_for_80': (round(items_for_80 / item_count * 100, 1)
                               if items_for_80 else None),
                'sku_pct_for_80': (items_for_80 or 0),
            },
            'thresholds': {'a': 70, 'b': 90},
        },
    }


def demand_service_series(usage, stock_id, start, end):
    """Dense daily demand series for one stock inside the window."""
    from ..services.forecasting import daily_series

    if not stock_id or start is None or end is None:
        return []
    by_day = (usage or {}).get(stock_id) or {}
    return daily_series([(d, q) for d, q in by_day.items()], start, end)


def build_supplier_performance(request, *, date_from=None, date_to=None,
                               branch_id=None):
    from ..services.scorecard import supplier_ranking

    rows = []
    for r in supplier_ranking():
        rows.append({
            'supplier': r['name'],
            'grade': r['grade'],
            'score': r['score'],
            'otif_pct': r['otif_pct'],
            'fill_rate_pct': r['fill_rate_pct'],
            'on_time_pct': r['on_time_pct'],
            'avg_lead_time_days': r['avg_lead_time_days'],
            'orders_count': r['orders_count'],
            'risk': (r['risk'] or '').title(),
            'period_end': parse_date(r['period_end']),
        })

    rated = [r for r in rows if r['grade'] != '-']
    return {
        'rows': rows,
        'totals': {'suppliers': len(rows), 'rated': len(rated),
                   'avg_score': (round(sum(r['score'] for r in rated) / len(rated), 1)
                                 if rated else 0.0)},
        'meta': {'unrated': len(rows) - len(rated)},
    }


# ══════════════════════════════════════════════════════════════════════
#  Registry
# ══════════════════════════════════════════════════════════════════════
BUILDERS = {
    'stock_on_hand': build_stock_on_hand,
    'valuation': build_valuation,
    'dead_stock': build_dead_stock,
    'movements': build_movements,
    'adjustments': build_adjustments,
    'transfers': build_transfers,
    'cycle_count': build_cycle_count,
    'expiry': build_expiry,
    'low_stock': build_low_stock,
    'controlled_register': build_controlled_register,
    'replenishment': build_replenishment,
    'abc_analysis': build_abc_analysis,
    'supplier_performance': build_supplier_performance,
}

#: Columns that expose purchase cost / valuation.
COST_COLUMNS = frozenset({
    'cost_price', 'unit_cost', 'value_cost', 'value_retail', 'margin',
    'margin_pct', 'value', 'estimated_cost', 'value_share_pct',
    'avg_daily_demand', 'reorder_point', 'safety_stock', 'eoq',
})
