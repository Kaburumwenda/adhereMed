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
}


@app.task(bind=True)
def debug_task(self):
    print(f'Request: {self.request!r}')
