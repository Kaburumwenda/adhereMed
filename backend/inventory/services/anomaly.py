"""Anomaly detection (Tier 7).

Nightly statistical sweep that surfaces the patterns a warehouse manager
would otherwise miss: the same item repeatedly miscounted, an adjustment
volume far above its own baseline, mass expiry events, or a price jump.

Each finding gets a stable ``signature`` so re-running the job updates the
existing row instead of stacking duplicates.
"""
from __future__ import annotations

import hashlib
from collections import defaultdict
from datetime import timedelta
from statistics import fmean, pstdev

from django.db.models import Count
from django.utils import timezone

from ..models import StockAdjustment, StockAnomaly, StockBatch

MIN_OCCURRENCES = 3


def _signature(*parts) -> str:
    return hashlib.sha1('|'.join(str(p) for p in parts).encode()).hexdigest()[:40]


def _upsert(kind, signature, *, defaults, branch_id=None, stock_id=None,
            user_id=None) -> bool:
    """Create or refresh an anomaly keyed by its stable signature."""
    obj, created = StockAnomaly.objects.update_or_create(
        kind=kind, signature=signature,
        defaults={
            **defaults,
            'status': 'open',
            'branch_id': branch_id,
            'stock_id': stock_id,
            'user_id': user_id,
        },
    )
    return created


def detect_repeated_variances(*, days: int = 90) -> int:
    """Items whose cycle counts keep disagreeing — often theft or mis-picking."""
    start = timezone.localdate() - timedelta(days=days)
    rows = (StockAdjustment.objects
            .filter(reason=StockAdjustment.Reason.COUNT_CORRECTION,
                    created_at__date__gte=start)
            .values('stock_id', 'stock__medication_name', 'stock__branch_id')
            .annotate(count=Count('id')))
    found = 0
    for row in rows:
        if (row['count'] or 0) < MIN_OCCURRENCES:
            continue
        sig = _signature('variance', row['stock_id'])
        if _upsert(
            'variance', sig,
            defaults={
                'severity': 'high' if row['count'] >= 5 else 'medium',
                'title': f'{row["stock__medication_name"]}: {row["count"]} count corrections',
                'detail': (f'{row["count"]} cycle counts disagreed with the system in '
                           f'the last {days} days. Investigate picking and storage.'),
                'metric': float(row['count']),
                'baseline': float(MIN_OCCURRENCES - 1),
                'occurrences': row['count'],
            },
            branch_id=row['stock__branch_id'], stock_id=row['stock_id'],
        ):
            found += 1
    return found


def detect_adjustment_volume(*, days: int = 30) -> int:
    """A user/site posting far more adjustments than its own baseline."""
    start = timezone.localdate() - timedelta(days=days)
    baseline_start = start - timedelta(days=days * 3)

    recent = defaultdict(int)
    for row in (StockAdjustment.objects
                .filter(created_at__date__gte=start)
                .values('adjusted_by_id', 'stock__branch_id')):
        recent[(row['adjusted_by_id'], row['stock__branch_id'])] += 1

    baseline = defaultdict(list)
    for row in (StockAdjustment.objects
                .filter(created_at__date__gte=baseline_start,
                        created_at__date__lt=start)
                .values('adjusted_by_id', 'stock__branch_id')):
        baseline[(row['adjusted_by_id'], row['stock__branch_id'])].append(1)

    from accounts.models import User

    found = 0
    for (user_id, branch_id), count in recent.items():
        history = baseline.get((user_id, branch_id))
        if not history or len(history) < 5:
            continue
        expected = len(history) / 3
        sd = pstdev([1] * len(history)) or 1.0
        z = (count - expected) / sd
        if z < 3:
            continue
        user = User.objects.filter(id=user_id).first()
        label = user.full_name if user else 'Unknown user'
        sig = _signature('adjustment', user_id, branch_id, start)
        if _upsert(
            'adjustment', sig,
            defaults={
                'severity': 'high' if z >= 5 else 'medium',
                'title': f'{label}: {count} adjustments in {days} days',
                'detail': (f'Baseline is about {expected:.0f} per {days} days '
                           f'(z = {z:.1f}). Check for mis-scanning or unrecorded sales.'),
                'metric': float(count),
                'baseline': round(expected, 2),
                'z_score': round(z, 2),
                'occurrences': count,
            },
            branch_id=branch_id, user_id=user_id,
        ):
            found += 1
    return found

def detect_price_jumps(*, days: int = 60, threshold_pct: float = 25.0) -> int:
    """Purchase price moving sharply versus the item's own history."""
    from purchase_orders.models import PurchaseOrder

    start = timezone.localdate() - timedelta(days=days)
    history = defaultdict(list)
    for po in (PurchaseOrder.objects.filter(order_date__gte=start - timedelta(days=days))
               .only('order_date', 'items', 'supplier_id')):
        for item in (po.items or []):
            sid = item.get('medication_stock_id')
            cost = item.get('unit_cost')
            if sid and cost:
                history[int(sid)].append((po.order_date, float(cost)))

    found = 0
    for sid, points in history.items():
        points.sort()
        if len(points) < 2:
            continue
        recent_cost = points[-1][1]
        prior = [c for _, c in points[:-1]]
        baseline = fmean(prior)
        if not baseline:
            continue
        delta_pct = (recent_cost - baseline) / baseline * 100
        if abs(delta_pct) < threshold_pct:
            continue
        from inventory.models import MedicationStock
        stock = MedicationStock.objects.filter(id=sid).first()
        name = stock.medication_name if stock else f'Item {sid}'
        sig = _signature('price', sid, points[-1][0])
        if _upsert(
            'price', sig,
            defaults={
                'severity': 'high' if abs(delta_pct) >= 50 else 'medium',
                'title': f'{name}: unit cost {delta_pct:+.0f}%',
                'detail': (f'Latest price {recent_cost:,.2f} vs a baseline of '
                           f'{baseline:,.2f}. Verify the invoice and landed cost.'),
                'metric': recent_cost,
                'baseline': round(baseline, 2),
            },
            branch_id=stock.branch_id if stock else None, stock_id=sid,
        ):
            found += 1
    return found


def detect_mass_expiry(*, days: int = 30, min_batches: int = 5) -> int:
    """Many batches of one item expiring together (a buying/rotation problem)."""
    horizon = timezone.localdate() + timedelta(days=days)
    rows = (StockBatch.objects
            .filter(quantity_remaining__gt=0, expiry_date__isnull=False,
                    expiry_date__lte=horizon)
            .values('stock_id', 'stock__medication_name', 'stock__branch_id')
            .annotate(count=Count('id')))
    found = 0
    for row in rows:
        if (row['count'] or 0) < min_batches:
            continue
        sig = _signature('expiry', row['stock_id'], timezone.localdate().isoformat()[:7])
        if _upsert(
            'expiry', sig,
            defaults={
                'severity': 'high',
                'title': f'{row["stock__medication_name"]}: {row["count"]} batches expiring',
                'detail': (f'{row["count"]} batches of this item expire within {days} days. '
                           'Rotate FEFO and consider a stock take before write-off.'),
                'metric': float(row['count']),
                'baseline': float(min_batches - 1),
                'occurrences': row['count'],
            },
            branch_id=row['stock__branch_id'], stock_id=row['stock_id'],
        ):
            found += 1
    return found


def detect_all() -> dict:
    """Run every detector; returns how many new anomalies each found."""
    return {
        'variance': detect_repeated_variances(),
        'adjustment_volume': detect_adjustment_volume(),
        'price': detect_price_jumps(),
        'mass_expiry': detect_mass_expiry(),
    }


def open_anomalies(limit: int = 50) -> list[dict]:
    rows = (StockAnomaly.objects.filter(status='open')
            .select_related('stock', 'branch', 'user')
            .order_by('-severity', '-created_at')[:limit])
    return [{
        'id': a.id,
        'kind': a.kind,
        'kind_label': a.get_kind_display(),
        'severity': a.severity,
        'title': a.title,
        'detail': a.detail,
        'metric': a.metric,
        'baseline': a.baseline,
        'z_score': a.z_score,
        'occurrences': a.occurrences,
        'stock_id': a.stock_id,
        'stock_name': a.stock.medication_name if a.stock else '',
        'branch_name': a.branch.name if a.branch else '',
        'user_name': a.user.full_name if a.user else '',
        'created_at': a.created_at.isoformat(timespec='seconds'),
    } for a in rows]
