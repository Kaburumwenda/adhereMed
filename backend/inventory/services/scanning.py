"""Scan-to-verify (Tier 4).

The mobile app already had a ``barcode_scanner_dialog`` for POS. This gives
the server a resolve endpoint plus an audit trail so receiving, picking and
counting can be verified against the expected item — and so a wrong-item
scan is visible after the fact.

Design notes
------------
* Resolution is attempted along a **fixed ladder** (internal payload → lot
  number → barcode → SKU → exact name) and the winning rung is reported back
  as ``match_type``. When a scan goes wrong the first question an operator
  asks is "what did it think I scanned?", and that is unanswerable without
  saying *how* it resolved.
* A miss is not an error: it is a fact worth recording and worth helping with.
  Failures therefore return *suggestions* - the codes the operator most likely
  meant - rather than a bare "not found".
* Lot-level facts (expired, expiring, quarantined) are raised as warning
  strings on the result. A scan that resolves correctly against a lot nobody
  may sell is still a problem, and the scanner is the last place it can be
  caught before the carton moves.
"""
from __future__ import annotations

from datetime import timedelta

from django.db.models import Count, Q
from django.utils import timezone

from ..models import MedicationStock, ScanVerification, StockBatch

#: The resolution ladder, in the order ``resolve_code`` walks it. The label is
#: what the UI shows next to a scan so the reader knows which rule fired.
RESOLUTION_STEPS = {
    'payload': 'Internal label payload',
    'lot': 'Lot number',
    'barcode': 'Barcode',
    'sku': 'SKU',
    'name': 'Item name',
    'none': 'Not resolved',
}

#: Days before expiry at which a scan starts warning. Matches the inventory
#: quality dashboard so the two never disagree about "expiring soon".
EXPIRY_WARN_DAYS = 30


def resolve_code(code: str, *, branch_id=None) -> dict:
    """Resolve a scanned code to stock / batch.

    Accepts, in order: an internal ``stockid|lot|expiry`` payload, a batch
    number, a barcode/SKU, or an exact item name.
    """
    code = (code or '').strip()
    if not code:
        return {'found': False, 'reason': 'Empty code', 'match_type': 'none',
                'match_label': RESOLUTION_STEPS['none']}

    stock_qs = MedicationStock.objects.filter(is_active=True).select_related(
        'branch', 'unit')
    if branch_id:
        stock_qs = stock_qs.filter(Q(branch_id=branch_id) | Q(branch__isnull=True))

    def miss(reason):
        return {'found': False, 'reason': reason, 'match_type': 'none',
                'match_label': RESOLUTION_STEPS['none'], 'suggestions': []}

    # 1) Internal payload: <stock id or medication_id>|<lot>|<expiry>
    if '|' in code:
        parts = code.split('|')
        key = (parts[0] or '').strip()
        stock = None
        if key:
            # Labels carry the human-readable medication_id, older ones the pk —
            # accept either so a reprint is never required.
            if key.isdigit():
                stock = stock_qs.filter(pk=int(key)).first()
            if stock is None:
                stock = stock_qs.filter(medication_id__iexact=key).first()
            if stock is None and key.isdigit():
                stock = stock_qs.filter(medication_id__iexact=key).first()
        if stock:
            batch = None
            if len(parts) > 1 and parts[1]:
                batch = stock.batches.filter(batch_number__iexact=parts[1]).first()
            return _payload(stock, batch, match=True, code=code,
                            match_type='payload')

    # 2) Batch number
    batch = (StockBatch.objects
             .filter(batch_number__iexact=code)
             .select_related('stock', 'stock__branch', 'stock__unit')
             .first())
    if batch and batch.stock:
        if branch_id and batch.stock.branch_id and batch.stock.branch_id != int(branch_id):
            return miss('Item belongs to another warehouse')
        return _payload(batch.stock, batch, match=True, code=code,
                        match_type='lot',
                        # A lot number is not unique: say when more than one
                        # item carries it, or the operator will assume the
                        # first match is the only one.
                        extra={'lot_shared': _lot_share(batch.batch_number)})

    # 3) Barcode / SKU
    stock = stock_qs.filter(barcode__iexact=code).first()
    if stock:
        return _payload(stock, None, match=True, code=code, match_type='barcode')

    # 4) medication_id
    stock = stock_qs.filter(medication_id__iexact=code).first()
    if stock:
        return _payload(stock, None, match=True, code=code, match_type='sku')

    # 5) Exact name (last resort)
    stock = stock_qs.filter(medication_name__iexact=code).first()
    if stock:
        return _payload(stock, None, match=True, code=code, match_type='name')

    result = miss('No item or batch matches this code')
    result['suggestions'] = _suggest(code, stock_qs, branch_id=branch_id)
    return result


def _lot_share(lot_number):
    """How many item/warehouse rows carry this lot number.

    Reported so a scan of a shared lot does not read as a unique identification
    when two items genuinely use the same number.
    """
    rows = (StockBatch.objects
            .filter(batch_number__iexact=lot_number)
            .values('stock_id').distinct().count())
    return max(rows - 1, 0)


def _suggest(code, stock_qs, *, branch_id=None, limit=5):
    """Near-miss candidates for a code that did not resolve.

    A scanner miss is usually a truncated read or a near-identical label, so
    prefix matching on the barcode and a substring match on the name finds the
    intended item far more often than it misleads. Each candidate carries *why*
    it was offered, so the operator can judge it instead of trusting a bare
    list.
    """
    term = (code or '').strip()
    if len(term) < 3:
        return []

    needle = term.lower()
    reasons = {}

    def note(stock, reason):
        if stock.pk in reasons:
            return
        reasons[stock.pk] = reason

    barcode_hits = stock_qs.filter(barcode__istartswith=term[:12])
    sku_hits = stock_qs.filter(medication_id__istartswith=term[:12])
    name_hits = stock_qs.filter(medication_name__icontains=term[:24])

    for stock in barcode_hits:
        note(stock, 'barcode starts with the scan')
    for stock in sku_hits:
        note(stock, 'SKU starts with the scan')
    for stock in name_hits:
        note(stock, 'name contains the scan')

    ordered = list(stock_qs.filter(pk__in=reasons.keys())
                   .order_by('medication_name')[:limit])

    # Also try the lot table: a mistyped lot is common and the item is what
    # the operator actually needs.
    if len(ordered) < limit:
        lot_matches = (StockBatch.objects
                       .filter(batch_number__icontains=term[:24])
                       .select_related('stock', 'stock__branch')
                       .exclude(stock__isnull=True))
        for batch in lot_matches:
            if len(ordered) >= limit:
                break
            stock = batch.stock
            if branch_id and stock.branch_id and stock.branch_id != int(branch_id):
                continue
            if any(s.pk == stock.pk for s in ordered):
                continue
            reasons[stock.pk] = f'lot {batch.batch_number} contains the scan'
            ordered.append(stock)

    return [{
        'stock_id': s.id,
        'medication_name': s.medication_name,
        'medication_id': s.medication_id,
        'barcode': s.barcode or '',
        'branch_name': s.branch.name if s.branch else '',
        'why': reasons.get(s.pk, 'similar to the scan'),
    } for s in ordered[:limit]]



def _payload(stock, batch, *, match: bool, code: str, match_type='none',
             extra=None) -> dict:
    payload = {
        'found': True,
        'match': match,
        'code': code,
        'match_type': match_type,
        'match_label': RESOLUTION_STEPS.get(match_type, match_type),
        'stock_id': stock.id,
        'medication_name': stock.medication_name,
        'medication_id': stock.medication_id,
        'barcode': stock.barcode or '',
        'unit': stock.unit.abbreviation if stock.unit else '',
        'branch_name': stock.branch.name if stock.branch else '',
        'on_hand': stock.total_quantity,
        'sellable': stock.sellable_quantity,
        'batch': {
            'id': batch.id,
            'batch_number': batch.batch_number,
            'quantity_remaining': batch.quantity_remaining,
            'expiry_date': batch.expiry_date.isoformat() if batch.expiry_date else None,
            'cost_price_per_unit': float(batch.cost_price_per_unit or 0),
            'is_blocked': batch.is_blocked,
        } if batch else None,
    }
    if extra:
        payload.update(extra)
    return payload


def _batch_warnings(resolved):
    """Lot-level reasons not to move these units, phrased for a scanner screen."""
    warnings = []
    batch = resolved.get('batch') or {}
    if not batch:
        return warnings

    if batch.get('is_blocked'):
        warnings.append({
            'severity': 'critical',
            'message': 'This lot is quarantined — do not issue or sell it.',
        })

    expiry = batch.get('expiry_date')
    if expiry:
        from datetime import date
        try:
            days = (date.fromisoformat(expiry) - timezone.localdate()).days
        except ValueError:
            days = None
        if days is not None and days < 0:
            warnings.append({
                'severity': 'critical',
                'message': f'Lot expired {abs(days)} day(s) ago ({expiry}).',
            })
        elif days is not None and days <= EXPIRY_WARN_DAYS:
            warnings.append({
                'severity': 'warning',
                'message': (f'Lot expires in {days} day(s) ({expiry}) — rotate '
                            f'it to the front of the shelf.'),
            })

    if resolved.get('sellable') == 0 and resolved.get('on_hand'):
        warnings.append({
            'severity': 'warning',
            'message': ('No sellable units remain for this item — everything '
                        'on hand is expired, blocked or committed.'),
        })
    return warnings


def verify_scan(*, code: str, context: str, expected_stock=None,
                user=None, reference: str = '', quantity: int = 0,
                branch_id=None) -> dict:
    """Resolve a code, compare with the expectation and audit the result."""
    resolved = resolve_code(code, branch_id=branch_id)
    matched_stock_id = resolved.get('stock_id')

    is_match = bool(resolved.get('found'))
    if expected_stock is not None and matched_stock_id:
        is_match = int(matched_stock_id) == int(
            getattr(expected_stock, 'pk', expected_stock))

    # A scan that found nothing is a failure whether or not a line was
    # expected, so the two cases get different wording rather than one
    # misleading "does not match".
    if not resolved.get('found'):
        warning = resolved.get('reason') or 'Nothing matched this code.'
    elif is_match:
        warning = None
    else:
        warning = 'Scanned item does not match the expected line — check the carton.'

    record = ScanVerification.objects.create(
        context=context,
        scanned_code=code[:120],
        expected_stock=expected_stock if expected_stock is not None else None,
        matched_stock_id=matched_stock_id,
        batch_id=resolved.get('batch', {}).get('id') if resolved.get('batch') else None,
        reference=reference[:100],
        is_match=is_match,
        quantity=int(quantity or 0),
        scanned_by=user if user and getattr(user, 'is_authenticated', False) else None,
    )

    expected_item = None
    if expected_stock is not None:
        expected_item = {
            'stock_id': getattr(expected_stock, 'pk', expected_stock),
            'medication_name': getattr(expected_stock, 'medication_name', ''),
            'medication_id': getattr(expected_stock, 'medication_id', ''),
            'barcode': getattr(expected_stock, 'barcode', '') or '',
        }

    return {
        **resolved,
        'is_match': is_match,
        'scan_id': record.id,
        'scanned_at': record.created_at.isoformat(timespec='seconds'),
        'expected': (
            getattr(expected_stock, 'medication_name', None)
            if expected_stock is not None else None
        ),
        'expected_item': expected_item,
        'warning': warning,
        'warnings': _batch_warnings(resolved) if resolved.get('found') else [],
        # Where the operator can go next. Only offered when the scan resolved,
        # so a dead end never pretends to be a lead.
        'links': ([{'label': 'Open batch trace',
                    'path': f"/ims/inventory/batch-trace?lot={resolved['batch']['batch_number']}"}]
                  if resolved.get('batch') and resolved['batch'].get('batch_number')
                  else []),
    }


def scan_history(*, context: str | None = None, only_mismatches: bool = False,
                 limit: int = 100, search: str = '', branch_id=None,
                 days: int | None = None) -> list[dict]:
    rows = ScanVerification.objects.select_related(
        'expected_stock', 'matched_stock', 'batch', 'scanned_by')

    if context:
        rows = rows.filter(context=context)
    if only_mismatches:
        rows = rows.filter(is_match=False)
    if search:
        term = search.strip()
        # ``full_name`` is a model property, not a column, so the operator
        # branch has to hit the underlying name fields.
        rows = rows.filter(
            Q(scanned_code__icontains=term)
            | Q(reference__icontains=term)
            | Q(expected_stock__medication_name__icontains=term)
            | Q(matched_stock__medication_name__icontains=term)
            | Q(scanned_by__first_name__icontains=term)
            | Q(scanned_by__last_name__icontains=term)
            | Q(scanned_by__email__icontains=term)
        )
    if days:
        rows = rows.filter(
            created_at__gte=timezone.now() - timedelta(days=int(days)))
    if branch_id:
        # Keep unresolved scans visible: a failed read has no warehouse, and
        # hiding it would erase exactly the rows an audit cares about.
        rows = rows.filter(
            Q(matched_stock__branch_id=branch_id)
            | Q(expected_stock__branch_id=branch_id)
            | Q(matched_stock__isnull=True, expected_stock__isnull=True)
            | Q(matched_stock__branch__isnull=True)
        )

    return [{
        'id': s.id,
        'context': s.context,
        'context_label': s.get_context_display(),
        'code': s.scanned_code,
        'expected': s.expected_stock.medication_name if s.expected_stock else '',
        'matched': s.matched_stock.medication_name if s.matched_stock else '',
        'batch': s.batch.batch_number if s.batch else '',
        'reference': s.reference,
        'is_match': s.is_match,
        'quantity': s.quantity,
        'user': s.scanned_by.full_name if s.scanned_by else 'System',
        'created_at': s.created_at.isoformat(timespec='seconds'),
    } for s in rows[:limit]]


def scan_analytics(*, branch_id=None, days: int = 30) -> dict:
    """Headline figures for the scanner screen.

    Match *rate* is the number that matters: a scanner that resolves everything
    but matches nothing is worse than no scanner, because it produces
    confident wrong answers. Reported alongside the mismatch list so the rate
    is never read without the evidence behind it.
    """
    since = timezone.now() - timedelta(days=days)
    rows = ScanVerification.objects.filter(created_at__gte=since)
    if branch_id:
        rows = rows.filter(
            Q(matched_stock__branch_id=branch_id)
            | Q(expected_stock__branch_id=branch_id)
            | Q(matched_stock__isnull=True, expected_stock__isnull=True)
            | Q(matched_stock__branch__isnull=True)
        )

    totals = rows.aggregate(
        total=Count('id'),
        matches=Count('id', filter=Q(is_match=True)),
        misses=Count('id', filter=Q(is_match=False)),
        operators=Count('scanned_by', distinct=True),
    )
    total = totals['total'] or 0
    matches = totals['matches'] or 0

    by_context = []
    for row in (rows.values('context')
                .annotate(total=Count('id'),
                          matches=Count('id', filter=Q(is_match=True)))
                .order_by('-total')):
        label = dict(ScanVerification.Context.choices).get(
            row['context'], row['context'])
        by_context.append({
            'context': row['context'],
            'label': label,
            'total': row['total'],
            'matches': row['matches'],
            'misses': row['total'] - row['matches'],
            'match_rate': round(row['matches'] / row['total'] * 100, 1)
            if row['total'] else 0.0,
        })

    today = timezone.localdate()
    today_total = rows.filter(created_at__date=today).count()

    top_misses = []
    for row in (rows.filter(is_match=False)
                .values('scanned_code')
                .annotate(count=Count('id'))
                .order_by('-count')[:5]):
        top_misses.append({'code': row['scanned_code'], 'count': row['count']})

    return {
        'days': days,
        'total': total,
        'matches': matches,
        'misses': totals['misses'] or 0,
        'operators': totals['operators'] or 0,
        'today': today_total,
        'match_rate': round(matches / total * 100, 1) if total else 0.0,
        'by_context': by_context,
        'top_misses': top_misses,
    }

