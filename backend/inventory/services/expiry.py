"""Expiry watch: alert ladder and automatic quarantine.

Two independent jobs:

* :func:`run_expiry_alerts` — notify the right people as a batch approaches
  each rung of the tenant's ladder (90/60/30/14/7/1 days). Notifications are
  deduplicated per batch per rung so a daily tick cannot spam.
* :func:`auto_quarantine_expired` — flip expired batches to
  ``is_blocked`` so they leave sellable stock and can no longer be allocated.

Both are safe to run repeatedly.
"""
from __future__ import annotations

import logging
from collections import defaultdict
from datetime import timedelta

from django.db import transaction
from django.utils import timezone

from ..models import InventorySettings, MedicationStock, StockBatch

logger = logging.getLogger(__name__)

#: Notification type used for every inventory alert.
STOCK_ALERT = 'stock_alert'


def _managers_for_branch(branch):
    """Users who should hear about this warehouse's stock."""
    from accounts.models import User
    from config.branch_scope import BRANCH_ADMIN_BYPASS_ROLES

    qs = User.objects.filter(is_active=True)
    if branch is not None:
        # Branch staff first, then tenant admins as a safety net.
        branch_users = list(qs.filter(staff_profile__branch=branch))
        if branch_users:
            return branch_users
    return list(qs.filter(role__in=BRANCH_ADMIN_BYPASS_ROLES))


def _notification_exists(recipient, key: str) -> bool:
    from notifications.models import Notification
    return Notification.objects.filter(
        recipient=recipient,
        type=STOCK_ALERT,
        data__key=key,
    ).exists()


def _notify(recipient, *, key, title, message, data):
    from notifications.models import Notification
    if _notification_exists(recipient, key):
        return False
    Notification.objects.create(
        recipient=recipient,
        type=STOCK_ALERT,
        title=title,
        message=message,
        data={'key': key, **data},
    )
    return True


def _rung_for(days_left: int, ladder: list[int]) -> int | None:
    """Return the ladder rung a batch has just crossed, if any.

    A batch 12 days from expiry has crossed 14 but not 7, so it belongs to
    the 14-day rung — one alert per rung, never a daily stream.
    """
    for step in sorted(ladder):          # ascending: 1, 7, 14, 30, …
        if days_left <= step:
            return step
    return None


def run_expiry_alerts(*, days_horizon: int | None = None) -> dict:
    """Create expiry notifications for batches crossing a ladder rung."""
    settings_obj = InventorySettings.get()
    ladder = sorted(int(d) for d in (settings_obj.expiry_alert_days or [30]))
    horizon = days_horizon or max(ladder)
    today = timezone.localdate()
    cutoff = today + timedelta(days=horizon)

    batches = (StockBatch.objects
               .filter(quantity_remaining__gt=0, expiry_date__isnull=False,
                       expiry_date__lte=cutoff, is_blocked=False)
               .select_related('stock', 'stock__branch', 'branch'))

    grouped = defaultdict(list)
    for batch in batches.iterator():
        days_left = batch.days_to_expiry
        rung = _rung_for(days_left, ladder)
        if rung is None:
            continue
        grouped[(batch.stock.branch_id, batch.stock_id, rung)].append(batch)

    sent = 0
    for (branch_id, stock_id, rung), rows in grouped.items():
        stock = rows[0].stock
        branch = stock.branch
        qty = sum(b.quantity_remaining for b in rows)
        value = sum(float(b.quantity_remaining) * float(b.cost_price_per_unit or 0)
                    for b in rows)
        label = 'already expired' if rung <= 1 else f'expires within {rung} day(s)'
        title = f'{stock.medication_name} — {label}'
        message = (
            f'{qty} unit(s) worth KES {value:,.2f} at {branch.name if branch else "the warehouse"} '
            f'{label}. Batches: ' + ', '.join(b.batch_number or '—' for b in rows[:5])
            + (' …' if len(rows) > 5 else '')
        )
        payload = {
            'stock_id': stock_id,
            'branch_id': branch_id,
            'rung': rung,
            'quantity': qty,
            'value': round(value, 2),
            'batch_ids': [b.id for b in rows][:50],
        }
        for user in _managers_for_branch(branch):
            if _notify(user, key=f'expiry:{stock_id}:{rung}', title=title,
                       message=message, data=payload):
                sent += 1

    return {'alerts_sent': sent, 'groups': len(grouped), 'horizon_days': horizon}


@transaction.atomic
def auto_quarantine_expired(*, reason: str = 'Expired') -> dict:
    """Block expired batches so they drop out of sellable stock."""
    settings_obj = InventorySettings.get()
    if not settings_obj.auto_quarantine_expired:
        return {'quarantined': 0, 'skipped': True}

    today = timezone.localdate()
    stale = (StockBatch.objects
             .filter(quantity_remaining__gt=0, is_blocked=False,
                     expiry_date__isnull=False, expiry_date__lt=today))
    ids = list(stale.values_list('id', flat=True))
    if not ids:
        return {'quarantined': 0}

    now = timezone.now()
    updated = (StockBatch.objects.filter(id__in=ids).update(
        is_blocked=True, blocked_reason=f'{reason} on {today}', blocked_at=now))

    # Tell the warehouse so the units get physically pulled.
    rows = (StockBatch.objects.filter(id__in=ids)
            .select_related('stock', 'stock__branch'))
    by_branch = defaultdict(list)
    for batch in rows:
        by_branch[batch.stock.branch_id].append(batch)

    notified = 0
    for branch_id, batch_rows in by_branch.items():
        total = sum(b.quantity_remaining for b in batch_rows)
        branch = batch_rows[0].stock.branch
        title = f'{len(batch_rows)} expired batch(es) quarantined'
        message = (f'{total} unit(s) across {len(batch_rows)} batch(es) have expired '
                   f'and were blocked from sale at '
                   f'{branch.name if branch else "the warehouse"}. '
                   'Book a write-off or return to supplier.')
        for user in _managers_for_branch(branch):
            if _notify(user, key=f'quarantine:{branch_id}:{today}',
                       title=title, message=message,
                       data={'branch_id': branch_id,
                             'batch_ids': [b.id for b in batch_rows][:50]}):
                notified += 1

    return {'quarantined': updated, 'notified': notified}


def release_expired_block() -> dict:
    """Un-block batches whose expiry was corrected (mis-keyed dates)."""
    today = timezone.localdate()
    fixed = (StockBatch.objects
             .filter(is_blocked=True, blocked_reason__startswith='Expired',
                     expiry_date__gte=today)
             .update(is_blocked=False, blocked_reason='', blocked_at=None))
    return {'released': fixed}


def write_off_expired(*, branch_id=None, user=None) -> dict:
    """Post expiry adjustments for blocked, expired batches (value zeroed).

    Only touches batches explicitly blocked as expired; recalled batches are
    left alone so their case can close them.
    """
    from .stock import apply_quantity_change
    from ..models import StockAdjustment

    today = timezone.localdate()
    batches = (StockBatch.objects
               .filter(quantity_remaining__gt=0, is_blocked=True,
                       expiry_date__isnull=False, expiry_date__lt=today,
                       blocked_reason__startswith='Expired')
               .select_related('stock'))
    if branch_id:
        batches = batches.filter(stock__branch_id=branch_id)

    written = 0
    for batch in batches:
        adjustments = apply_quantity_change(
            batch.stock, -batch.quantity_remaining,
            reason=StockAdjustment.Reason.EXPIRY,
            notes=f'Expired batch {batch.batch_number}',
            user=user, batch=batch,
        )
        written += 1
        # Above the tenant threshold a write-off needs a second signature —
        # the nightly job used to remove stock with no approval at all.
        try:
            from . import quality as quality_service
            for adjustment in adjustments:
                if quality_service.needs_approval(adjustment):
                    quality_service.request_writeoff(adjustment, user=user)
        except Exception:
            logger.exception('could not open a write-off request for an expired batch')
    return {'batches_written_off': written}
