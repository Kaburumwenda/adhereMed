"""Care-pathway / protocol bundle engine.

Applies a `CarePathway` template to a `HomecarePatient` — creates a
TreatmentPlan and the medication schedules described by the template.
"""
from __future__ import annotations

from datetime import date, timedelta

from django.db import transaction
from django.utils import timezone

from .models import (
    CarePathway, CarePathwayEnrollment, MedicationSchedule, TreatmentPlan,
)


@transaction.atomic
def enroll_patient(pathway: CarePathway, patient, *, started_by_user_id=None,
                   start_date: date | None = None) -> CarePathwayEnrollment:
    start_date = start_date or timezone.localdate()
    duration = pathway.default_duration_days or 0
    end_date = (start_date + timedelta(days=duration)) if duration else None

    plan = TreatmentPlan.objects.create(
        patient=patient,
        title=f'{pathway.name}',
        diagnosis=pathway.condition_label or pathway.name,
        goals=pathway.goals or [],
        start_date=start_date,
        end_date=end_date,
        status=TreatmentPlan.Status.ACTIVE,
        notes=pathway.description or '',
    )

    schedules = []
    for tmpl in (pathway.medication_orders or []):
        if not isinstance(tmpl, dict) or not tmpl.get('medication_name'):
            continue
        med_duration = tmpl.get('duration_days') or duration or 0
        med_end = (start_date + timedelta(days=med_duration)) if med_duration else None
        sch = MedicationSchedule.objects.create(
            patient=patient,
            treatment_plan=plan,
            medication_name=tmpl['medication_name'],
            dose=tmpl.get('dose', ''),
            route=tmpl.get('route', MedicationSchedule.Route.ORAL),
            times_of_day=tmpl.get('times_of_day', []),
            frequency_cron=tmpl.get('frequency_cron', ''),
            start_date=start_date,
            end_date=med_end,
            instructions=tmpl.get('instructions', ''),
            requires_caregiver=bool(tmpl.get('requires_caregiver', False)),
            is_active=True,
        )
        schedules.append(sch)

    enrollment = CarePathwayEnrollment.objects.create(
        pathway=pathway,
        patient=patient,
        treatment_plan=plan,
        status=CarePathwayEnrollment.Status.ACTIVE,
        started_at=timezone.now(),
        started_by_user_id=started_by_user_id,
        target_end_date=end_date,
        meta={'schedule_ids': [s.id for s in schedules]},
    )
    return enrollment
