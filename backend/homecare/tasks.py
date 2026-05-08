"""Celery tasks for the homecare app.

Beat-scheduled "tick" tasks loop over homecare tenants and dispatch the
real per-tenant work via ``tenant_task``-wrapped callables.
"""
from datetime import timedelta, datetime, time as dt_time

from celery import shared_task
from django.utils import timezone

from .tasks_base import tenant_task, homecare_tenants


# ──────────────────────────────────────────────
# Per-tenant unit tasks
# ──────────────────────────────────────────────
@tenant_task(name='homecare.expand_dose_events_for_today')
def expand_dose_events_for_today():
    from .services import expand_all_active_schedules
    return expand_all_active_schedules(days_ahead=1)


@tenant_task(name='homecare.send_dose_reminders')
def send_dose_reminders():
    from .services import send_dose_reminders as _send
    return _send(window_minutes=30)


@tenant_task(name='homecare.mark_missed_doses')
def mark_missed_doses():
    from .services import mark_overdue_doses_missed
    return mark_overdue_doses_missed(grace_minutes=60)


@tenant_task(name='homecare.evaluate_escalations')
def evaluate_escalations():
    from .services import evaluate_escalations as _eval
    return _eval()


@tenant_task(name='homecare.auto_close_teleconsult')
def auto_close_teleconsult():
    from .models import TeleconsultRoom
    now = timezone.now()
    closed = 0
    for room in TeleconsultRoom.objects.filter(status=TeleconsultRoom.Status.IN_PROGRESS):
        end = (room.started_at or room.scheduled_at) + timedelta(minutes=room.duration_minutes + 15)
        if now >= end:
            room.status = TeleconsultRoom.Status.ENDED
            room.ended_at = now
            room.save(update_fields=['status', 'ended_at'])
            closed += 1
    # Also cancel scheduled rooms long past start
    overdue = TeleconsultRoom.objects.filter(
        status=TeleconsultRoom.Status.SCHEDULED,
        scheduled_at__lt=now - timedelta(hours=2),
    )
    overdue.update(status=TeleconsultRoom.Status.CANCELLED)
    return closed


@tenant_task(name='homecare.daily_digest')
def daily_digest():
    """Email/notify caregivers and admins with today's schedule + open escalations."""
    from accounts.models import User
    from notifications.models import Notification
    from .models import CaregiverSchedule, Escalation
    today = timezone.localdate()
    start = timezone.make_aware(datetime.combine(today, dt_time.min))
    end = start + timedelta(days=1)

    digests = 0
    for u in User.objects.filter(role__in=['caregiver', 'homecare_admin', 'tenant_admin', 'admin'],
                                  is_active=True):
        if u.role == 'caregiver':
            try:
                cg = u.caregiver_profile
            except Exception:
                continue
            visits = CaregiverSchedule.objects.filter(
                caregiver=cg, start_at__gte=start, start_at__lt=end,
            ).count()
            if not visits:
                continue
            Notification.objects.create(
                recipient=u, type=Notification.NotificationType.SYSTEM,
                title=f"Today: {visits} visit(s)",
                message=f'You have {visits} scheduled visit(s) today.',
                data={'kind': 'daily_digest', 'visits': visits},
            )
            digests += 1
        else:
            open_esc = Escalation.objects.filter(status=Escalation.Status.OPEN).count()
            todays_visits = CaregiverSchedule.objects.filter(
                start_at__gte=start, start_at__lt=end,
            ).count()
            Notification.objects.create(
                recipient=u, type=Notification.NotificationType.SYSTEM,
                title='Daily homecare digest',
                message=f'{todays_visits} visit(s) today, {open_esc} open escalation(s).',
                data={'kind': 'daily_digest', 'visits': todays_visits,
                      'open_escalations': open_esc},
            )
            digests += 1
    return digests


# ──────────────────────────────────────────────
# Beat-triggered "tick" tasks (run in public schema, fan out per tenant)
# ──────────────────────────────────────────────
def _fan_out(unit_task):
    dispatched = 0
    for schema in homecare_tenants():
        unit_task.delay(_schema=schema)
        dispatched += 1
    return dispatched


@shared_task(name='homecare.tasks.tick_expand_dose_events')
def tick_expand_dose_events():
    return _fan_out(expand_dose_events_for_today)


@shared_task(name='homecare.tasks.tick_send_dose_reminders')
def tick_send_dose_reminders():
    return _fan_out(send_dose_reminders)


@shared_task(name='homecare.tasks.tick_mark_missed_doses')
def tick_mark_missed_doses():
    return _fan_out(mark_missed_doses)


@shared_task(name='homecare.tasks.tick_evaluate_escalations')
def tick_evaluate_escalations():
    return _fan_out(evaluate_escalations)


@shared_task(name='homecare.tasks.tick_auto_close_teleconsult')
def tick_auto_close_teleconsult():
    return _fan_out(auto_close_teleconsult)


@shared_task(name='homecare.tasks.tick_daily_digest')
def tick_daily_digest():
    return _fan_out(daily_digest)
