"""Nightly / scheduled inventory automation (Tier 1).

Every job is idempotent and safe to re-run: notifications are deduplicated,
snapshots are upserted and anomalies are keyed by a stable signature.

Beat runs these in the public schema; each ``tick_*`` task fans out to every
inventory-type tenant and switches schema via ``tenant_task``.

Entry points are also exported as plain functions so a management command or
a test can call them directly without a broker.
"""
from __future__ import annotations

import logging

from celery import shared_task

from config.tenant_tasks import tenant_task, tenants_of_type

logger = logging.getLogger(__name__)


# ══════════════════════════════════════════════════════════════════════
#  Per-tenant unit tasks (run inside one tenant schema)
# ══════════════════════════════════════════════════════════════════════

@tenant_task(name='inventory.run_expiry_alerts')
def run_expiry_alerts():
    from .services import expiry
    return expiry.run_expiry_alerts()


@tenant_task(name='inventory.run_auto_quarantine')
def run_auto_quarantine():
    from .services import expiry
    released = expiry.release_expired_block()
    result = expiry.auto_quarantine_expired()
    return {**result, 'released': released.get('released', 0)}


@tenant_task(name='inventory.run_replenishment')
def run_replenishment():
    """Refresh suggestions and (if enabled) draft POs."""
    from .models import InventorySettings
    from .services import replenishment

    payload = replenishment.build_suggestions(write=True)
    drafted = {'purchase_orders': []}
    settings_obj = InventorySettings.get()
    if settings_obj.auto_draft_purchase_orders:
        drafted = replenishment.draft_purchase_orders()
    return {'suggestions': payload['summary'],
            'drafted': len(drafted.get('purchase_orders', []))}


@tenant_task(name='inventory.run_cycle_counts')
def run_cycle_counts():
    from .services import cycle_count
    replan = cycle_count.replan()
    created = cycle_count.create_count_from_schedule()
    return {**replan, **created}


@tenant_task(name='inventory.refresh_plans')
def refresh_plans():
    """Recompute policies, forecasts and forecast accuracy."""
    from .services import planning
    return {
        'policies': planning.refresh_policies(),
        'forecasts': planning.refresh_forecasts(),
        'accuracy': planning.backfill_forecast_accuracy(),
    }


@tenant_task(name='inventory.detect_anomalies')
def detect_anomalies():
    from .services import anomaly
    return anomaly.detect_all()


@tenant_task(name='inventory.stale_sweep')
def stale_sweep():
    """Notify about idle capital that has not moved in the tenant's window."""
    from datetime import timedelta

    from django.utils import timezone

    from .models import InventorySettings, MedicationStock
    from .services.demand import last_movement_at
    from .services.expiry import _managers_for_branch, _notify
    from .services.valuation import stock_unit_cost

    settings_obj = InventorySettings.get()
    window = int(settings_obj.stale_days or 90)
    last_move = last_movement_at(days=max(400, window + 60))
    cutoff = timezone.localdate() - timedelta(days=window)

    by_branch = {}
    for stock in MedicationStock.objects.with_quantities().select_related('branch'):
        qty = stock.total_quantity
        if qty <= 0:
            continue
        moved = last_move.get(stock.id)
        reference = moved or (stock.created_at.date() if stock.created_at else None)
        if reference is None or reference > cutoff:
            continue
        value = float(stock_unit_cost(stock)) * qty
        by_branch.setdefault(stock.branch_id, []).append((stock, qty, value))

    sent = 0
    for branch_id, rows in by_branch.items():
        value = sum(r[2] for r in rows)
        branch = rows[0][0].branch
        title = f'{len(rows)} item(s) idle for {window}+ days'
        message = (f'KES {value:,.2f} of stock at '
                   f'{branch.name if branch else "the warehouse"} has not moved in '
                   f'{window} days: '
                   + ', '.join(r[0].medication_name for r in rows[:5])
                   + (' …' if len(rows) > 5 else '') + '.')
        for user in _managers_for_branch(branch):
            if _notify(user, key=f'stale:{branch_id}:{window}',
                       title=title, message=message,
                       data={'branch_id': branch_id,
                             'stock_ids': [r[0].id for r in rows][:50],
                             'value': round(value, 2)}):
                sent += 1
    return {'branches': len(by_branch), 'alerts_sent': sent}


@tenant_task(name='inventory.daily_digest')
def daily_digest():
    """One summary notification per manager, once a day."""
    from datetime import timedelta

    from django.utils import timezone

    from .models import InventorySettings, MedicationStock, RecallCase, StockBatch, StockTransfer
    from .services.expiry import _managers_for_branch, _notify

    today = timezone.localdate()
    settings_obj = InventorySettings.get()

    stocks = list(MedicationStock.objects.with_quantities().filter(is_active=True))
    out = sum(1 for s in stocks if s.sellable_quantity <= 0)
    low = sum(1 for s in stocks
              if 0 < s.sellable_quantity <= (s.reorder_level or 0))

    horizon = today + timedelta(days=max(settings_obj.expiry_alert_days or [30]))
    expiring = (StockBatch.objects
                .filter(quantity_remaining__gt=0, expiry_date__isnull=False,
                        expiry_date__lte=horizon)
                .values('stock_id').distinct().count())

    awaiting = StockTransfer.objects.filter(
        status=StockTransfer.Status.REQUESTED).count()
    open_recalls = RecallCase.objects.exclude(
        status__in=[RecallCase.Status.COMPLETED, RecallCase.Status.CANCELLED]).count()

    title = 'Inventory daily digest'
    message = (
        f'{out} item(s) out of stock · {low} at or below reorder · '
        f'{expiring} expiring soon · {awaiting} transfer(s) awaiting approval · '
        f'{open_recalls} open recall(s).'
    )

    sent = 0
    seen = set()
    for branch in {s.branch for s in stocks if s.branch}:
        for user in _managers_for_branch(branch):
            if user.id in seen:
                continue
            seen.add(user.id)
            if _notify(user, key=f'digest:{today}', title=title, message=message,
                       data={'date': today.isoformat(), 'out': out, 'low': low,
                             'expiring': expiring, 'transfers': awaiting,
                             'recalls': open_recalls}):
                sent += 1
    return {'digest_sent': sent}


@tenant_task(name='inventory.refresh_scorecards')
def refresh_scorecards(days: int = 90):
    from .services import scorecard
    return scorecard.refresh_scorecards(days=days)


@tenant_task(name='inventory.monthly_snapshot')
def monthly_snapshot():
    from .services import valuation
    snapshot = valuation.create_snapshot()
    return {'snapshot_id': snapshot.pk, 'period': snapshot.period.isoformat(),
            'total_cost_value': float(snapshot.total_cost_value)}


@tenant_task(name='inventory.write_off_expired')
def write_off_expired():
    from .services import expiry
    return expiry.write_off_expired()


# ══════════════════════════════════════════════════════════════════════
#  Beat ticks — fan out to every inventory tenant
# ══════════════════════════════════════════════════════════════════════
INVENTORY_TENANT_TYPES = ('inventory', 'pharmacy', 'hospital', 'clinic')


def _fan_out(unit_task, *args, **kwargs):
    dispatched = []
    for schema in tenants_of_type(*INVENTORY_TENANT_TYPES):
        try:
            unit_task.delay(*args, _schema=schema, **kwargs)
            dispatched.append(schema)
        except Exception:  # pragma: no cover - broker hiccup should not kill beat
            logger.exception('inventory fan-out failed for %s', schema)
    return {'dispatched': len(dispatched)}


@shared_task(name='inventory.tasks.tick_expiry_alerts')
def tick_expiry_alerts():
    return _fan_out(run_expiry_alerts)


@shared_task(name='inventory.tasks.tick_auto_quarantine')
def tick_auto_quarantine():
    return _fan_out(run_auto_quarantine)


@shared_task(name='inventory.tasks.tick_replenishment')
def tick_replenishment():
    return _fan_out(run_replenishment)


@shared_task(name='inventory.tasks.tick_cycle_counts')
def tick_cycle_counts():
    return _fan_out(run_cycle_counts)


@shared_task(name='inventory.tasks.tick_refresh_plans')
def tick_refresh_plans():
    return _fan_out(refresh_plans)


@shared_task(name='inventory.tasks.tick_detect_anomalies')
def tick_detect_anomalies():
    return _fan_out(detect_anomalies)


@shared_task(name='inventory.tasks.tick_stale_sweep')
def tick_stale_sweep():
    return _fan_out(stale_sweep)


@shared_task(name='inventory.tasks.tick_daily_digest')
def tick_daily_digest():
    return _fan_out(daily_digest)


@shared_task(name='inventory.tasks.tick_refresh_scorecards')
def tick_refresh_scorecards():
    return _fan_out(refresh_scorecards)


@shared_task(name='inventory.tasks.tick_monthly_snapshot')
def tick_monthly_snapshot():
    return _fan_out(monthly_snapshot)


@shared_task(name='inventory.tasks.tick_write_off_expired')
def tick_write_off_expired():
    return _fan_out(write_off_expired)
