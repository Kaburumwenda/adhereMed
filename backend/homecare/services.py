"""Service helpers for the homecare app."""
from datetime import datetime, timedelta, time as dt_time

from django.db import transaction
from django.utils import timezone

from .models import (
    DoseEvent, MedicationSchedule, Escalation, EscalationRule, HomecarePatient,
)
from notifications.models import Notification


def _times_for_day(schedule: MedicationSchedule, day):
    """Return a list of timezone-aware datetimes when doses occur on `day`."""
    times = schedule.times_of_day or []
    out = []
    tz = timezone.get_current_timezone()
    for t in times:
        try:
            hh, mm = [int(x) for x in str(t).split(':')[:2]]
        except (ValueError, TypeError):
            continue
        naive = datetime.combine(day, dt_time(hour=hh, minute=mm))
        out.append(timezone.make_aware(naive, tz))
    if not times:
        # default once-daily at 09:00 if nothing configured
        naive = datetime.combine(day, dt_time(hour=9, minute=0))
        out.append(timezone.make_aware(naive, tz))
    return out


@transaction.atomic
def expand_doses_for_schedule(schedule: MedicationSchedule, days_ahead: int = 1):
    """Create pending DoseEvent rows for the next ``days_ahead`` days."""
    if not schedule.is_active:
        return 0
    today = timezone.localdate()
    horizon = today + timedelta(days=days_ahead)
    if schedule.end_date and horizon > schedule.end_date:
        horizon = schedule.end_date

    created = 0
    day = max(today, schedule.start_date)
    while day <= horizon:
        for at in _times_for_day(schedule, day):
            obj, was_new = DoseEvent.objects.get_or_create(
                schedule=schedule, scheduled_at=at,
                defaults={'status': DoseEvent.Status.PENDING},
            )
            if was_new:
                created += 1
        day += timedelta(days=1)
    return created


def expand_all_active_schedules(days_ahead: int = 1):
    total = 0
    for sched in MedicationSchedule.objects.filter(is_active=True):
        total += expand_doses_for_schedule(sched, days_ahead=days_ahead)
    return total


def mark_overdue_doses_missed(grace_minutes: int = 60):
    """Mark pending doses past their scheduled time + grace as 'missed'."""
    cutoff = timezone.now() - timedelta(minutes=grace_minutes)
    qs = DoseEvent.objects.filter(status=DoseEvent.Status.PENDING,
                                  scheduled_at__lt=cutoff)
    missed = []
    for d in qs:
        d.status = DoseEvent.Status.MISSED
        d.save(update_fields=['status'])
        missed.append(d)
        _notify_dose_missed(d)
    return len(missed)


def send_dose_reminders(window_minutes: int = 30):
    """Notify caregiver + patient for doses due in the next window."""
    now = timezone.now()
    horizon = now + timedelta(minutes=window_minutes)
    qs = DoseEvent.objects.filter(
        status=DoseEvent.Status.PENDING,
        scheduled_at__gte=now,
        scheduled_at__lte=horizon,
        reminded_at__isnull=True,
    ).select_related('schedule', 'schedule__patient', 'schedule__patient__user',
                     'schedule__patient__assigned_caregiver',
                     'schedule__patient__assigned_caregiver__user')
    sent = 0
    for d in qs:
        patient = d.schedule.patient
        title = f'Dose due: {d.schedule.medication_name}'
        msg = f'{d.schedule.medication_name} {d.schedule.dose} at {timezone.localtime(d.scheduled_at):%H:%M}'
        data = {'dose_id': d.id, 'schedule_id': d.schedule_id,
                'scheduled_at': d.scheduled_at.isoformat()}
        # Patient reminder
        Notification.objects.create(
            recipient=patient.user,
            type=Notification.NotificationType.DOSE_REMINDER,
            title=title, message=msg, data=data,
        )
        # Caregiver reminder
        cg = patient.assigned_caregiver
        if cg:
            Notification.objects.create(
                recipient=cg.user,
                type=Notification.NotificationType.DOSE_REMINDER,
                title=f'Administer: {d.schedule.medication_name}',
                message=f'{patient.user.full_name} – {msg}', data=data,
            )
        d.reminded_at = timezone.now()
        d.save(update_fields=['reminded_at'])
        sent += 1
    return sent


def _notify_dose_missed(dose: DoseEvent):
    schedule = dose.schedule
    patient = schedule.patient
    title = f'Missed dose: {schedule.medication_name}'
    msg = (f'{patient.user.full_name} missed {schedule.medication_name} '
           f'scheduled at {timezone.localtime(dose.scheduled_at):%Y-%m-%d %H:%M}.')
    data = {'dose_id': dose.id, 'patient_id': patient.id, 'kind': 'missed'}
    recipients = [patient.user]
    if patient.assigned_caregiver:
        recipients.append(patient.assigned_caregiver.user)
    for u in recipients:
        Notification.objects.create(
            recipient=u, type=Notification.NotificationType.DOSE_MISSED,
            title=title, message=msg, data=data,
        )


def evaluate_escalations():
    """Run all active EscalationRule and create Escalations as needed."""
    rules = EscalationRule.objects.filter(is_active=True)
    if not rules.exists():
        # Seed a default 72h rule on first run
        EscalationRule.objects.create(
            name='Default 72h missed-dose escalation',
            description='Auto-generated. Triggers when patient misses any dose '
                        'within the past 72 hours.',
        )
        rules = EscalationRule.objects.filter(is_active=True)

    now = timezone.now()
    created = 0
    for rule in rules:
        cutoff = now - timedelta(hours=rule.missed_doses_window_hours)
        patients_qs = HomecarePatient.objects.filter(is_active=True)
        if rule.risk_level_filter:
            patients_qs = patients_qs.filter(risk_level=rule.risk_level_filter)
        for patient in patients_qs:
            missed = DoseEvent.objects.filter(
                schedule__patient=patient,
                status=DoseEvent.Status.MISSED,
                scheduled_at__gte=cutoff,
            )
            count = missed.count()
            if count < rule.missed_count_threshold:
                continue
            # Avoid duplicate open escalations for same rule+patient
            if Escalation.objects.filter(
                patient=patient, rule=rule, status=Escalation.Status.OPEN
            ).exists():
                continue
            severity = (
                Escalation.Severity.CRITICAL if count >= 5
                else Escalation.Severity.HIGH if count >= 3
                else Escalation.Severity.MEDIUM
            )
            esc = Escalation.objects.create(
                patient=patient, rule=rule,
                reason=f'{count} missed doses in last {rule.missed_doses_window_hours}h',
                detail=f'Patient {patient.user.full_name} missed {count} dose(s).',
                severity=severity,
                related_dose_ids=list(missed.values_list('id', flat=True)),
            )
            _fan_out_escalation(esc, rule)
            created += 1
    return created


def _fan_out_escalation(esc: Escalation, rule: EscalationRule):
    from accounts.models import User
    title = f'Escalation: {esc.patient.user.full_name}'
    msg = f'[{esc.get_severity_display()}] {esc.reason}'
    data = {'escalation_id': esc.id, 'patient_id': esc.patient_id,
            'severity': esc.severity}
    recipients = []
    if rule.notify_caregiver and esc.patient.assigned_caregiver:
        recipients.append(esc.patient.assigned_caregiver.user)
    if rule.notify_doctor and esc.patient.assigned_doctor_user_id:
        try:
            recipients.append(User.objects.get(id=esc.patient.assigned_doctor_user_id))
        except User.DoesNotExist:
            pass
    if rule.notify_family:
        # Family contacts are JSON; we just notify the patient user (who can forward)
        recipients.append(esc.patient.user)
    seen = set()
    for u in recipients:
        if u.id in seen:
            continue
        seen.add(u.id)
        Notification.objects.create(
            recipient=u, type=Notification.NotificationType.ESCALATION,
            title=title, message=msg, data=data,
        )
