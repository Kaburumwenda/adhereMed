"""Cold chain and certificates (Tier 3).

* :func:`log_excursion` — record an out-of-band temperature reading, grade it
  and (for critical excursions) quarantine the batch.
* :func:`batch_certified` — whether a batch may be released for sale: its
  item must have a certificate that covers the receipt date and has not
  expired.
"""
from __future__ import annotations

from decimal import Decimal

from django.db import transaction
from django.utils import timezone

from ..models import (MedicationStock, StorageZone, SupplierCertificate,
                      TemperatureExcursion)


def grade_excursion(recorded: Decimal, low: Decimal, high: Decimal) -> str:
    """Minor / major / critical from how far outside the band we went."""
    lo, hi = Decimal(str(low)), Decimal(str(high))
    value = Decimal(str(recorded))
    if lo <= value <= hi:
        return TemperatureExcursion.Severity.MINOR

    span = max(Decimal('1'), (hi - lo) or Decimal('1'))
    deviation = (lo - value) if value < lo else (value - hi)
    ratio = deviation / span
    if ratio <= 0.2:
        return TemperatureExcursion.Severity.MINOR
    if ratio <= 0.6:
        return TemperatureExcursion.Severity.MAJOR
    return TemperatureExcursion.Severity.CRITICAL


@transaction.atomic
def log_excursion(*, recorded_temp_c, zone=None, batch=None,
                  started_at=None, ended_at=None, user=None,
                  notes: str = '') -> TemperatureExcursion:
    """Record a reading, auto-grading it against the zone's band.

    Critical excursions block the affected batch immediately — a cold-chain
    breach is not something a warehouse should have to remember to action.
    """
    low = zone.min_temp_c if zone else Decimal('0')
    high = zone.max_temp_c if zone else Decimal('0')
    severity = grade_excursion(recorded_temp_c, low, high)

    excursion = TemperatureExcursion.objects.create(
        zone=zone,
        batch=batch,
        recorded_temp_c=recorded_temp_c,
        allowed_min_c=low,
        allowed_max_c=high,
        started_at=started_at or timezone.now(),
        ended_at=ended_at,
        severity=severity,
        status=TemperatureExcursion.Status.OPEN,
        action_taken=notes,
        recorded_by=user if user and getattr(user, 'is_authenticated', False) else None,
    )

    if severity == TemperatureExcursion.Severity.CRITICAL and batch is not None:
        batch.is_blocked = True
        batch.blocked_reason = (
            f'Cold chain breach: {recorded_temp_c} °C (allowed '
            f'{low}–{high} °C)')
        batch.blocked_at = timezone.now()
        batch.save(update_fields=['is_blocked', 'blocked_reason', 'blocked_at'])
        excursion.auto_quarantined = True
        excursion.action_taken = (
            (excursion.action_taken + '\n' if excursion.action_taken else '')
            + 'Batch quarantined automatically — assess product quality.')
        excursion.save(update_fields=['auto_quarantined', 'action_taken'])
        _notify(excursion)

    return excursion


def _notify(excursion: TemperatureExcursion):
    from notifications.models import Notification

    from .expiry import _managers_for_branch

    branch = excursion.batch.stock.branch if excursion.batch else None
    title = f'Cold chain breach — {excursion.recorded_temp_c} °C'
    message = (
        f'A reading of {excursion.recorded_temp_c} °C is outside the '
        f'{excursion.allowed_min_c}–{excursion.allowed_max_c} °C band'
        + (f' for batch {excursion.batch.batch_number} '
           f'({excursion.batch.stock.medication_name}).' if excursion.batch else '.')
        + ' The batch has been quarantined pending an assessment.'
    )
    for user in _managers_for_branch(branch):
        Notification.objects.create(
            recipient=user,
            type='stock_alert',
            title=title,
            message=message,
            data={'key': f'excursion:{excursion.pk}',
                  'excursion_id': excursion.pk,
                  'batch_id': excursion.batch_id},
        )


def batch_certified(batch, *, kind=SupplierCertificate.Kind.COA) -> dict:
    """Whether a certificate on file covers this batch.

    A certificate covers the batch when it belongs to the same supplier or
    stock item, was issued on/before the receipt date, and has not expired.
    """
    if batch is None:
        return {'certified': True, 'required': False, 'reason': 'No batch'}
    stock = batch.stock
    supplier = batch.supplier

    qs = SupplierCertificate.objects.filter(kind=kind)
    if supplier is not None:
        qs = qs.filter(supplier=supplier)
    elif stock is not None:
        qs = qs.filter(stock=stock)
    else:
        return {'certified': False, 'required': True,
                'reason': 'No supplier or item to match a certificate'}

    today = timezone.localdate()
    valid = [c for c in qs if not c.is_expired]
    if not valid:
        return {'certified': False, 'required': True,
                'reason': f'No valid {kind} certificate on file'}

    covering = [
        c for c in valid
        if (c.issued_on is None or c.issued_on <= batch.received_date)
    ]
    if not covering:
        return {'certified': False, 'required': True,
                'reason': 'Certificate predates the receipt'}

    return {'certified': True, 'required': True,
            'reason': f'Covered by {covering[0].reference}',
            'certificate_id': covering[0].id}


def uncertified_batches(*, limit: int = 100) -> list[dict]:
    """Live batches that cannot be released for sale for lack of a COA."""
    from ..models import StockBatch

    out = []
    for batch in (StockBatch.objects.filter(quantity_remaining__gt=0)
                  .select_related('stock', 'supplier')[:1000]):
        result = batch_certified(batch)
        if result['certified']:
            continue
        out.append({
            'batch_id': batch.id,
            'batch_number': batch.batch_number,
            'stock_id': batch.stock_id,
            'name': batch.stock.medication_name if batch.stock else '',
            'supplier': batch.supplier.name if batch.supplier else '',
            'quantity': batch.quantity_remaining,
            'reason': result['reason'],
        })
        if len(out) >= limit:
            break
    return out


# ─────────────────────────────────────────────────────────────────────────
#  Write-off approvals
# ─────────────────────────────────────────────────────────────────────────
#: Adjustment reasons that represent a loss of stock (and so need approval).
WRITE_OFF_REASONS = ('damage', 'expiry', 'theft', 'other')


def needs_approval(adjustment) -> bool:
    """Whether an adjustment's value crosses the tenant's approval threshold."""
    from ..models import InventorySettings

    threshold = InventorySettings.get().writeoff_approval_threshold
    if not threshold or Decimal(str(threshold)) <= 0:
        return False
    if adjustment.reason not in WRITE_OFF_REASONS:
        return False
    return writeoff_value(adjustment) >= Decimal(str(threshold))


@transaction.atomic
def request_writeoff(adjustment, *, user=None) -> 'WriteOffRequest':
    """Open (or return the existing) approval request for an adjustment.

    Idempotent: the FK is one-to-one, so a re-save never stacks requests.
    """
    from ..models import WriteOffRequest

    existing = WriteOffRequest.objects.filter(adjustment=adjustment).first()
    if existing:
        return existing

    stock = adjustment.stock
    return WriteOffRequest.objects.create(
        adjustment=adjustment,
        stock=stock,
        quantity=abs(int(adjustment.quantity_change or 0)),
        value=writeoff_value(adjustment),
        reason=adjustment.reason or '',
        notes=adjustment.notes or '',
        requested_by=user if user and getattr(user, 'is_authenticated', False) else None,
    )


def writeoff_value(adjustment) -> Decimal:
    """Cost value of the stock an adjustment removed."""
    stock = getattr(adjustment, 'stock', None)
    if stock is None:
        return Decimal('0')
    unit_cost = Decimal(str(stock.cost_price or 0))
    return (unit_cost * abs(int(adjustment.quantity_change or 0))).quantize(Decimal('0.01'))


def pending_writeoffs(*, limit: int = 200) -> list[dict]:
    """Open write-off requests awaiting a second signature."""
    from ..models import WriteOffRequest

    qs = (WriteOffRequest.objects
          .filter(status=WriteOffRequest.Status.PENDING)
          .select_related('stock', 'stock__branch', 'requested_by', 'adjustment')
          .order_by('-created_at')[:limit])
    return [{
        'id': w.id,
        'stock_id': w.stock_id,
        'name': w.stock.medication_name if w.stock else '',
        'branch_name': (w.stock.branch.name
                        if w.stock and w.stock.branch else ''),
        'quantity': w.quantity,
        'value': float(w.value or 0),
        'reason': w.reason,
        'requested_by': (w.requested_by.get_full_name()
                         if w.requested_by and hasattr(w.requested_by, 'get_full_name')
                         else ''),
        'created_at': w.created_at.isoformat() if w.created_at else None,
    } for w in qs]


def apply_writeoff_decision(writeoff, *, approve: bool) -> str:
    """Reflect an approval decision on the underlying adjustment.

    Rejecting a damage write-off puts the quantity back, so the ledger and
    the shelf agree — otherwise a rejection silently left the loss in place.
    """
    from .stock import apply_quantity_change

    adjustment = writeoff.adjustment
    if adjustment is None or approve:
        return 'applied'

    if adjustment.quantity_change and adjustment.quantity_change < 0:
        stock = adjustment.stock
        apply_quantity_change(
            stock,
            abs(int(adjustment.quantity_change)),
            reason=adjustment.Reason.COUNT_CORRECTION,
            notes=f'Reversal of rejected write-off #{writeoff.pk}',
            user=writeoff.decided_by,
            batch=adjustment.batch,
        )
        return 'reversed'
    return 'applied'
