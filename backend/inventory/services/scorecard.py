"""Supplier performance scorecard (Tier 6).

Everything is derived from real purchase-order and GRN history so the
numbers cannot be massaged the way a hand-entered evaluation can.

Metrics
-------
* **OTIF** — on time *and* in full (the headline supplier KPI).
* **Fill rate** — received qty ÷ ordered qty.
* **Lead time** — mean and std-dev of PO → GRN days (feeds safety stock).
* **On-time %** — arrival within the promised window.
* **Rejection %** — units rejected/short on receipt.
* **Composite score** — weighted 0–100 → letter grade.
"""
from __future__ import annotations

from collections import defaultdict
from datetime import date, timedelta
from statistics import fmean, pstdev

from django.db import transaction
from django.utils import timezone

from ..models import SupplierScorecard

#: Weighting of the composite score (sums to 1.0).
WEIGHTS = {'otif': 0.40, 'fill': 0.25, 'on_time': 0.20, 'quality': 0.15}

#: On-time tolerance in days — a delivery this late still counts as on time.
GRACE_DAYS = 1


def _grade(score: float) -> str:
    if score >= 90:
        return 'A'
    if score >= 80:
        return 'B'
    if score >= 65:
        return 'C'
    if score >= 50:
        return 'D'
    return 'E'


#: Grade used when nothing has been delivered yet — the score is unknown, not bad.
UNRATED_GRADE = '-'


def _unrated() -> dict:
    return {
        'orders_count': 0, 'lines_ordered': 0, 'lines_received_in_full': 0,
        'otif_pct': 0.0, 'fill_rate_pct': 0.0, 'avg_lead_time_days': 0.0,
        'lead_time_stddev': 0.0, 'on_time_pct': 0.0, 'rejection_pct': 0.0,
        'score': 0.0, 'grade': UNRATED_GRADE, 'is_rated': False,
    }


def _period_bounds(period_end=None, days: int = 90):
    end = period_end or timezone.localdate()
    return end - timedelta(days=days - 1), end


def compute_scorecard(supplier, period_start: date, period_end: date) -> dict:
    """Calculate one supplier's metrics for a period (no DB write)."""
    from purchase_orders.models import GoodsReceivedNote, PurchaseOrder

    pos = list(PurchaseOrder.objects
               .filter(supplier=supplier,
                       order_date__gte=period_start,
                       order_date__lte=period_end)
               .exclude(status=PurchaseOrder.Status.CANCELLED)
               .only('id', 'order_date', 'expected_delivery', 'items', 'status'))

    if not pos:
        return _unrated()

    grns = list(GoodsReceivedNote.objects
                .filter(purchase_order_id__in=[p.id for p in pos])
                .select_related('purchase_order'))

    received_by_po = defaultdict(list)
    for grn in grns:
        received_by_po[grn.purchase_order_id].append(grn)

    ordered_units = defaultdict(float)
    received_units = defaultdict(float)
    total_ordered = total_received = 0.0
    lines_ordered = lines_full = 0

    for po in pos:
        items = po.items or []
        lines_ordered += len(items)
        po_ordered = 0.0
        po_received = 0.0
        # Per-PO maps: the period-wide totals used to let a later PO's receipt
        # mark an earlier PO's line as "received in full".
        po_ordered_by_key = defaultdict(float)
        po_received_by_key = defaultdict(float)
        for item in items:
            key = str(item.get('medication_stock_id') or item.get('name') or '')
            qty = float(item.get('qty') or 0)
            po_ordered_by_key[key] += qty
            ordered_units[key] += qty
            po_ordered += qty
        for grn in received_by_po.get(po.id, []):
            for item in (grn.items_received or []):
                key = str(item.get('medication_stock_id')
                          or item.get('stock_id')
                          or item.get('name') or '')
                qty = float(item.get('qty') or item.get('quantity') or 0)
                po_received_by_key[key] += qty
                received_units[key] += qty
                po_received += qty
        total_ordered += po_ordered
        total_received += po_received
        # "In full" is evaluated per line, within this purchase order.
        for key in po_ordered_by_key:
            if po_received_by_key.get(key, 0) + 1e-9 >= po_ordered_by_key[key]:
                lines_full += 1

    # ── Timing ──────────────────────────────────────────────────────────
    lead_times = []
    on_time = 0
    on_time_checked = 0
    otif_hits = 0
    otif_checked = 0

    for po in pos:
        grn_list = received_by_po.get(po.id, [])
        if not grn_list:
            continue
        first = min(g.received_date for g in grn_list)
        lead_times.append(max(0.0, (first - po.order_date).days))

        on_time_checked += 1
        deadline = (po.expected_delivery or po.order_date) + timedelta(days=GRACE_DAYS)
        is_on_time = first <= deadline
        if is_on_time:
            on_time += 1

        # OTIF = the whole order arrived on time AND complete.
        po_ordered = sum(float(i.get('qty') or 0) for i in (po.items or []))
        po_received = sum(float(i.get('qty') or i.get('quantity') or 0)
                          for g in grn_list for i in (g.items_received or []))
        complete = po_received + 1e-9 >= po_ordered if po_ordered else True
        otif_checked += 1
        if is_on_time and complete:
            otif_hits += 1

    fill_rate = (total_received / total_ordered * 100) if total_ordered else 0.0
    on_time_pct = (on_time / on_time_checked * 100) if on_time_checked else 0.0
    otif_pct = (otif_hits / otif_checked * 100) if otif_checked else 0.0
    rejection_pct = max(0.0, 100 - fill_rate)
    avg_lt = fmean(lead_times) if lead_times else 0.0
    sd_lt = pstdev(lead_times) if len(lead_times) > 1 else 0.0

    # Nothing has arrived yet: the PO exists but no GRN. Scoring it would grade
    # the supplier on zero evidence, so report it as unrated instead.
    if not otif_checked:
        return {
            **_unrated(),
            'orders_count': len(pos),
            'lines_ordered': lines_ordered,
            'lines_received_in_full': lines_full,
        }

    score = (
        WEIGHTS['otif'] * otif_pct
        + WEIGHTS['fill'] * fill_rate
        + WEIGHTS['on_time'] * on_time_pct
        + WEIGHTS['quality'] * max(0.0, 100 - rejection_pct)
    )

    return {
        'orders_count': len(pos),
        'lines_ordered': lines_ordered,
        'lines_received_in_full': lines_full,
        'otif_pct': round(otif_pct, 1),
        'fill_rate_pct': round(fill_rate, 1),
        'avg_lead_time_days': round(avg_lt, 1),
        'lead_time_stddev': round(sd_lt, 1),
        'on_time_pct': round(on_time_pct, 1),
        'rejection_pct': round(rejection_pct, 1),
        'score': round(score, 1),
        'grade': _grade(score),
        'is_rated': True,
    }


@transaction.atomic
def refresh_scorecards(*, days: int = 90, period_end: date | None = None) -> dict:
    """Recompute and store a scorecard for every active supplier."""
    from suppliers.models import Supplier

    start, end = _period_bounds(period_end, days)
    written = 0
    for supplier in Supplier.objects.filter(is_active=True).iterator():
        metrics = compute_scorecard(supplier, start, end)
        metrics.pop('is_rated', None)      # presentation flag, not a column
        SupplierScorecard.objects.update_or_create(
            supplier=supplier, period_start=start, period_end=end,
            defaults=metrics,
        )
        written += 1
    return {'scorecards': written, 'period_start': start.isoformat(),
            'period_end': end.isoformat()}


def supplier_ranking(days: int = 90) -> list[dict]:
    """Ranked supplier list for the procurement screen (latest period each)."""
    rows = (SupplierScorecard.objects
            .select_related('supplier')
            .order_by('-period_end', '-score'))
    latest = {}
    for row in rows:
        # Keep the most recent period per supplier — ordering by score alone
        # surfaced whichever historical period graded best.
        if row.supplier_id in latest:
            continue
        latest[row.supplier_id] = {
            'supplier_id': row.supplier_id,
            'name': row.supplier.name,
            'score': row.score,
            'grade': row.grade,
            'is_rated': row.grade != UNRATED_GRADE,
            'otif_pct': row.otif_pct,
            'fill_rate_pct': row.fill_rate_pct,
            'on_time_pct': row.on_time_pct,
            'avg_lead_time_days': row.avg_lead_time_days,
            'lead_time_stddev': row.lead_time_stddev,
            'orders_count': row.orders_count,
            'period_end': row.period_end.isoformat(),
            'risk': ('unknown' if row.grade == UNRATED_GRADE else
                     'high' if row.score < 65 else
                     'medium' if row.score < 80 else 'low'),
        }
    # Rated suppliers first (best score first), unrated at the bottom.
    return sorted(latest.values(),
                  key=lambda r: (not r['is_rated'], -r['score'], r['name']))
