"""Stock quantity mutation service.

Every quantity change in inventory is represented by a
:class:`~inventory.models.StockAdjustment` row *and* a batch mutation, so the
movement ledger and the physical batch table can never drift apart.

Before this module existed:

* an adjustment created **without** a batch wrote a ledger row but changed
  no stock (on-hand is derived from batches) — a silent no-op;
* over-deductions were clamped with ``max(0, …)`` instead of being rejected;
* duplicate copies of the drain/increment loop lived in the stock serializer,
  the bulk-update action and the stock-take completion action;
  **and in POS, dispensing, sales orders and transfer approval**, where the
  copies also sold expired / quarantined lots and completed sales they could
  not cover.

Three entry points now cover every caller:

* :func:`consume_stock` — sales channels. Drains **sellable** batches only and
  refuses to go short; writes one ledger row per batch consumed.
* :func:`receipt_stock` — goods in. Tops up a sellable batch or opens a new lot;
  never resurrects an expired/quarantined batch.
* :func:`apply_quantity_change` — the permissive inventory-adjustment path
  (stock takes, write-offs, reversals) that may touch expired/blocked units.
"""
from __future__ import annotations

from datetime import date, timedelta

from django.db import transaction
from django.db.models import Q
from django.utils import timezone

from ..models import StockAdjustment, StockBatch


class InsufficientStock(Exception):
    """Raised when a deduction would take a stock item below zero."""

    def __init__(self, stock, requested: int, available: int):
        self.stock = stock
        self.requested = requested
        self.available = available
        super().__init__(
            f'Only {available} unit(s) of {getattr(stock, "medication_name", "item")} '
            f'are available ({requested} requested).'
        )


def _actor(user):
    """Return a User instance suitable for ``adjusted_by`` (or ``None``)."""
    return user if getattr(user, 'is_authenticated', False) else None


# ── Candidate selection (single source of truth) ─────────────────────────
def _drain_candidates(stock, *, batch=None, branch_id=None, lock=False,
                      allow_expired=False, allow_blocked=False):
    """Batches eligible to be drained, in FEFO order (earliest expiry first).

    A pinned ``batch`` is returned as-is — the caller has explicitly chosen it
    and the allow_* flags do not apply (transfer approval validates separately).
    """
    if batch is not None:
        return [batch]

    qs = StockBatch.objects.filter(stock=stock, quantity_remaining__gt=0)
    if not allow_blocked:
        # Quarantined by auto-quarantine, a recall or a cold-chain breach.
        qs = qs.exclude(is_blocked=True)
    if not allow_expired:
        today = timezone.localdate()
        qs = qs.filter(Q(expiry_date__isnull=True) | Q(expiry_date__gte=today))
    if branch_id:
        qs = qs.filter(Q(branch_id=branch_id) | Q(branch__isnull=True))
    if lock:
        qs = qs.select_for_update()
    return list(qs.order_by('expiry_date', 'received_date'))


def _topup_candidate(stock, *, allow_expired_topup=False):
    """Batch new units should be added to, or ``None`` to open a fresh lot.

    Adding units into an expired or quarantined batch leaves them permanently
    invisible to ``sellable_quantity`` — physically on the shelf, unsellable —
    so by default only a live batch is eligible.
    """
    qs = StockBatch.objects.filter(stock=stock)
    if allow_expired_topup:
        # Legacy behaviour (used by reversals): newest-expiring batch, any state.
        return qs.order_by('-expiry_date').first()
    today = timezone.localdate()
    return (qs.filter(is_blocked=False)
              .filter(Q(expiry_date__isnull=True) | Q(expiry_date__gte=today))
              .order_by('expiry_date')
              .first())


# ── Sales-channel entry points ──────────────────────────────────────────
@transaction.atomic
def consume_stock(stock, quantity: int, *, reason: str, notes: str = '',
                  user=None, batch=None, allow_partial: bool = False,
                  allow_expired: bool = False, allow_blocked: bool = False,
                  branch_id=None, lock: bool = True) -> list:
    """Remove ``quantity`` units from ``stock``, one ledger row per batch.

    POS, dispensing and sales-order fulfilment use the defaults: only
    **sellable** batches are drained (not expired, not quarantined, optionally
    restricted to ``branch_id``). A deduction the shelf cannot cover raises
    :class:`InsufficientStock` rather than completing a sale that leaves the
    item short — that silent path used to create phantom stock.

    Stock takes and expiry write-offs pass ``allow_expired=True`` /
    ``allow_blocked=True``: those units are exactly what they must remove.
    """
    qty = int(quantity or 0)
    if qty <= 0:
        return []

    candidates = _drain_candidates(
        stock, batch=batch, branch_id=branch_id, lock=lock,
        allow_expired=allow_expired, allow_blocked=allow_blocked,
    )
    available = sum(b.quantity_remaining or 0 for b in candidates)
    if available < qty and not allow_partial:
        raise InsufficientStock(stock, qty, available)

    actor = _actor(user)
    created = []
    remaining = qty
    for target in candidates:
        if remaining <= 0:
            break
        take = min(target.quantity_remaining or 0, remaining)
        if take <= 0:
            continue
        created.append(StockAdjustment.objects.create(
            stock=stock, batch=target, quantity_change=-take, reason=reason,
            notes=notes or '', adjusted_by=actor,
        ))
        target.quantity_remaining = (target.quantity_remaining or 0) - take
        target.save(update_fields=['quantity_remaining'])
        remaining -= take

    if remaining > 0:
        # Only reachable with allow_partial=True: record the unbacked part so
        # the ledger still explains the full change.
        created.append(StockAdjustment.objects.create(
            stock=stock, batch=None, quantity_change=-remaining, reason=reason,
            notes=notes or '', adjusted_by=actor,
        ))
    return created


@transaction.atomic
def receipt_stock(stock, quantity: int, *, reason: str, notes: str = '',
                  user=None, batch=None, batch_number: str = '',
                  expiry_date=None, unit_cost=None, supplier=None,
                  branch=None, create_new_lot: bool = False,
                  allow_expired_topup: bool = False) -> list:
    """Add ``quantity`` units to ``stock`` and write the ledger row.

    Tops up a live batch by default; opens a new lot when the item has none.
    ``expiry_date`` / ``unit_cost`` / ``supplier`` / ``branch`` only apply to a
    newly created lot — top-ups keep the lot's real identity.
    """
    qty = int(quantity or 0)
    if qty <= 0:
        return []

    target = batch
    if target is None and not create_new_lot:
        target = _topup_candidate(stock, allow_expired_topup=allow_expired_topup)

    if target is None:
        target = StockBatch.objects.create(
            stock=stock,
            batch_number=batch_number or f'ADJ-{stock.pk}-{date.today():%Y%m%d}',
            quantity_received=qty,
            quantity_remaining=0,
            cost_price_per_unit=(unit_cost if unit_cost is not None
                                 else (stock.cost_price or 0)),
            expiry_date=expiry_date or (date.today() + timedelta(days=365)),
            supplier=supplier,
            branch=branch if branch is not None else stock.branch,
        )

    created = [StockAdjustment.objects.create(
        stock=stock, batch=target, quantity_change=qty, reason=reason,
        notes=notes or '', adjusted_by=_actor(user),
    )]
    target.quantity_remaining = (target.quantity_remaining or 0) + qty
    target.save(update_fields=['quantity_remaining'])
    return created


@transaction.atomic
def apply_quantity_change(stock, delta: int, *, reason: str, notes: str = '',
                          user=None, batch=None, lock: bool = False,
                          allow_negative: bool = False) -> list:
    """Apply ``delta`` units to ``stock`` for inventory's own adjustments.

    This is the *permissive* path — manual adjustments, stock takes, expiry and
    recall write-offs and their reversals legitimately need to move expired or
    quarantined units, and to record an unbacked remainder. Sales channels must
    call :func:`consume_stock` / :func:`receipt_stock` instead, which enforce
    sellability.
    """
    delta = int(delta or 0)
    if delta == 0:
        return []

    if delta > 0:
        return receipt_stock(
            stock, delta, reason=reason, notes=notes, user=user, batch=batch,
            allow_expired_topup=True,
        )

    return consume_stock(
        stock, -delta, reason=reason, notes=notes, user=user, batch=batch,
        allow_partial=allow_negative, allow_expired=True, allow_blocked=True,
        lock=lock,
    )


@transaction.atomic
def reconcile_quantity(stock, target_qty: int, *, user=None, reason=None,
                       notes: str = '') -> list:
    """Bring ``stock`` to exactly ``target_qty`` units on hand."""
    reason = reason or StockAdjustment.Reason.COUNT_CORRECTION
    delta = int(target_qty) - int(stock.total_quantity)
    return apply_quantity_change(
        stock, delta, reason=reason, notes=notes, user=user,
    )
