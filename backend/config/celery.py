"""Celery app for AfyaOne.

Tasks scheduled by Beat run in the public schema by default. Tenant-aware
work happens via the ``tenant_task`` decorator (see ``homecare/tasks_base.py``)
which switches the schema before executing the task body.
"""
import os

from celery import Celery
from celery.schedules import crontab

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

app = Celery('config')
app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks()


# ──────────────────────────────────────────────
# Beat schedule
# ──────────────────────────────────────────────
app.conf.beat_schedule = {
    # Homecare ticks — fan out per-tenant inside the task
    'homecare-expand-doses': {
        'task': 'homecare.tasks.tick_expand_dose_events',
        'schedule': crontab(minute='*/30'),
    },
    'homecare-dose-reminders': {
        'task': 'homecare.tasks.tick_send_dose_reminders',
        'schedule': crontab(minute='*/5'),
    },
    'homecare-mark-missed': {
        'task': 'homecare.tasks.tick_mark_missed_doses',
        'schedule': crontab(minute='*/15'),
    },
    'homecare-evaluate-escalations': {
        'task': 'homecare.tasks.tick_evaluate_escalations',
        'schedule': crontab(minute='*/30'),
    },
    'homecare-auto-close-teleconsult': {
        'task': 'homecare.tasks.tick_auto_close_teleconsult',
        'schedule': crontab(minute='*/15'),
    },
    'homecare-daily-digest': {
        'task': 'homecare.tasks.tick_daily_digest',
        'schedule': crontab(hour=7, minute=0),
    },
    'homecare-auto-generate-bills': {
        # Runs a few minutes after every hour so hourly plans bill promptly and
        # daily / weekly / monthly plans are also picked up on their first tick
        # past midnight / week-end / month-end (see homecare/services.py).
        'task': 'homecare.tasks.tick_auto_generate_bills',
        'schedule': crontab(minute=5),
    },
    # POS — auto-delete parked sales older than 48 hours
    'pos-cleanup-parked-sales': {
        'task': 'pos.tasks.cleanup_expired_parked_sales',
        'schedule': crontab(minute='*/15'),
    },

    # ── Inventory / IMS automation ────────────────────────────────────
    # Every tick fans out per tenant inside the task.
    'inventory-refresh-plans': {
        # Policies, forecasts and forecast accuracy — the input to
        # replenishment, so it must run first.
        'task': 'inventory.tasks.tick_refresh_plans',
        'schedule': crontab(hour=1, minute=10),
    },
    'inventory-expiry-alerts': {
        'task': 'inventory.tasks.tick_expiry_alerts',
        'schedule': crontab(hour=6, minute=0),
    },
    'inventory-auto-quarantine': {
        'task': 'inventory.tasks.tick_auto_quarantine',
        'schedule': crontab(hour=6, minute=20),
    },
    'inventory-replenishment': {
        'task': 'inventory.tasks.tick_replenishment',
        'schedule': crontab(hour=2, minute=0),
    },
    'inventory-cycle-counts': {
        'task': 'inventory.tasks.tick_cycle_counts',
        'schedule': crontab(hour=3, minute=0),
    },
    'inventory-anomalies': {
        'task': 'inventory.tasks.tick_detect_anomalies',
        'schedule': crontab(hour=4, minute=0),
    },
    'inventory-stale-sweep': {
        'task': 'inventory.tasks.tick_stale_sweep',
        'schedule': crontab(hour=5, minute=0, day_of_week=1),
    },
    'inventory-daily-digest': {
        'task': 'inventory.tasks.tick_daily_digest',
        'schedule': crontab(hour=7, minute=15),
    },
    'inventory-scorecards': {
        'task': 'inventory.tasks.tick_refresh_scorecards',
        'schedule': crontab(hour=4, minute=30, day_of_week=1),
    },
    'inventory-monthly-snapshot': {
        'task': 'inventory.tasks.tick_monthly_snapshot',
        'schedule': crontab(hour=1, minute=0, day_of_month=1),
    },
    'inventory-write-off-expired': {
        # Off by default in behaviour: only touches batches auto-quarantined
        # as expired, and only when the tenant has opted in via settings.
        'task': 'inventory.tasks.tick_write_off_expired',
        'schedule': crontab(hour=6, minute=40, day_of_month='*/7'),
    },
}


@app.task(bind=True)
def debug_task(self):
    print(f'Request: {self.request!r}')
