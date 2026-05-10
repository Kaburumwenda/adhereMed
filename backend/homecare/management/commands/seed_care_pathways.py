"""Seed a few starter care pathways into all homecare tenants."""
from django.core.management.base import BaseCommand
from django_tenants.utils import schema_context, get_tenant_model

from homecare.models import CarePathway


PATHWAYS = [
    {
        'name': 'Post-op Hip Replacement',
        'code': '52734007',
        'condition_label': 'Post-operative hip replacement recovery',
        'description': 'Standard 30-day post-op pathway: pain control, anticoagulation, '
                       'wound care, mobility milestones, infection monitoring.',
        'default_duration_days': 30,
        'goals': [
            'Pain ≤ 3/10 by day 7',
            'Independent ambulation with walker by day 14',
            'No surgical-site infection',
            'Adherence to anticoagulation ≥ 95%',
        ],
        'medication_orders': [
            {'medication_name': 'Paracetamol', 'dose': '1000', 'route': 'oral',
             'times_of_day': ['08:00', '14:00', '20:00'], 'duration_days': 14,
             'instructions': 'For pain. Max 4 g/day.'},
            {'medication_name': 'Enoxaparin', 'dose': '40', 'route': 'sc',
             'times_of_day': ['20:00'], 'duration_days': 28,
             'instructions': 'DVT prophylaxis. Subcut injection.', 'requires_caregiver': True},
            {'medication_name': 'Ibuprofen', 'dose': '400', 'route': 'oral',
             'times_of_day': ['08:00', '20:00'], 'duration_days': 7,
             'instructions': 'With food. Hold if creatinine rises.'},
        ],
        'vital_targets': {'pain_max': 3, 'temp_max': 38.0, 'hr_max': 110},
        'tasks': [
            {'title': 'Wound dressing change', 'day_offset': 2, 'category': 'observation'},
            {'title': 'Physio: weight-bearing exercises', 'day_offset': 3, 'category': 'activity'},
            {'title': 'Suture removal', 'day_offset': 14, 'category': 'observation'},
            {'title': 'Follow-up teleconsult', 'day_offset': 21, 'category': 'observation'},
        ],
    },
    {
        'name': 'CHF — Heart Failure Home Management',
        'code': '42343007',
        'condition_label': 'Congestive heart failure',
        'description': 'Daily weight, BP, symptom check, medication adherence and '
                       'fluid-balance monitoring with escalation thresholds.',
        'default_duration_days': 90,
        'goals': [
            'Daily weight gain < 1 kg/day',
            'BP within target 110–130 / 60–80',
            'No new dyspnoea or oedema',
            'Adherence to all heart-failure meds ≥ 95%',
        ],
        'medication_orders': [
            {'medication_name': 'Furosemide', 'dose': '40', 'route': 'oral',
             'times_of_day': ['08:00'], 'duration_days': 90,
             'instructions': 'Diuretic. Monitor weight + electrolytes.'},
            {'medication_name': 'Lisinopril', 'dose': '10', 'route': 'oral',
             'times_of_day': ['08:00'], 'duration_days': 90,
             'instructions': 'ACE inhibitor. Hold if SBP < 100.'},
            {'medication_name': 'Bisoprolol', 'dose': '5', 'route': 'oral',
             'times_of_day': ['08:00'], 'duration_days': 90,
             'instructions': 'Beta-blocker. Hold if HR < 55.'},
            {'medication_name': 'Spironolactone', 'dose': '25', 'route': 'oral',
             'times_of_day': ['08:00'], 'duration_days': 90,
             'instructions': 'Monitor K⁺.'},
        ],
        'vital_targets': {'spo2_min': 94, 'bp_systolic_max': 140, 'weight_delta_max': 1.5},
        'tasks': [
            {'title': 'Daily weight + symptom check', 'day_offset': 1, 'category': 'vitals'},
            {'title': 'Electrolytes draw', 'day_offset': 7, 'category': 'observation'},
            {'title': 'Cardiology teleconsult', 'day_offset': 14, 'category': 'observation'},
        ],
    },
    {
        'name': 'Palliative Care — Comfort Pathway',
        'code': '103735009',
        'condition_label': 'Palliative care',
        'description': 'Symptom control, dignity-focused care, family support and '
                       'PRN escalation. Emphasises comfort over curative goals.',
        'default_duration_days': 60,
        'goals': [
            'Pain ≤ 3/10 at all times',
            'No distressing dyspnoea',
            'Patient + family wishes documented',
        ],
        'medication_orders': [
            {'medication_name': 'Morphine', 'dose': '5', 'route': 'oral',
             'times_of_day': ['08:00', '14:00', '20:00', '02:00'], 'duration_days': 60,
             'instructions': 'PRN for pain. Titrate to comfort.', 'requires_caregiver': True},
            {'medication_name': 'Lorazepam', 'dose': '1', 'route': 'oral',
             'times_of_day': ['22:00'], 'duration_days': 60,
             'instructions': 'For anxiety / sleep.'},
            {'medication_name': 'Haloperidol', 'dose': '0.5', 'route': 'sc',
             'times_of_day': ['08:00', '20:00'], 'duration_days': 60,
             'instructions': 'For nausea / agitation.', 'requires_caregiver': True},
        ],
        'vital_targets': {'pain_max': 3},
        'tasks': [
            {'title': 'Family meeting & goals review', 'day_offset': 1, 'category': 'observation'},
            {'title': 'Mouth + skin care', 'day_offset': 1, 'category': 'observation'},
            {'title': 'Spiritual care visit (if requested)', 'day_offset': 3, 'category': 'observation'},
        ],
    },
    {
        'name': 'Type 2 Diabetes — Home Stabilisation',
        'code': '44054006',
        'condition_label': 'Type 2 diabetes mellitus',
        'description': 'Glucose monitoring, medication adherence and lifestyle '
                       'support with monthly HbA1c review.',
        'default_duration_days': 90,
        'goals': [
            'Fasting glucose 4.4–7.0 mmol/L',
            'No hypoglycaemia (< 4.0)',
            'HbA1c trending toward < 7.0%',
        ],
        'medication_orders': [
            {'medication_name': 'Metformin', 'dose': '500', 'route': 'oral',
             'times_of_day': ['08:00', '20:00'], 'duration_days': 90,
             'instructions': 'With meals. Monitor renal function.'},
            {'medication_name': 'Glipizide', 'dose': '5', 'route': 'oral',
             'times_of_day': ['08:00'], 'duration_days': 90,
             'instructions': 'Hold if patient skipping meals.'},
        ],
        'vital_targets': {'glucose_min': 4.0, 'glucose_max': 10.0},
        'tasks': [
            {'title': 'Fasting glucose check', 'day_offset': 1, 'category': 'vitals'},
            {'title': 'Foot inspection', 'day_offset': 7, 'category': 'observation'},
            {'title': 'Dietitian session', 'day_offset': 14, 'category': 'observation'},
            {'title': 'HbA1c draw', 'day_offset': 90, 'category': 'observation'},
        ],
    },
]


class Command(BaseCommand):
    help = 'Seed default care pathways into every homecare-enabled tenant.'

    def handle(self, *args, **opts):
        Tenant = get_tenant_model()
        tenants = Tenant.objects.exclude(schema_name='public')
        for t in tenants:
            with schema_context(t.schema_name):
                created = 0
                for spec in PATHWAYS:
                    obj, was_created = CarePathway.objects.update_or_create(
                        name=spec['name'], defaults=spec,
                    )
                    if was_created:
                        created += 1
                self.stdout.write(self.style.SUCCESS(
                    f'  [{t.schema_name}] {created} new / {len(PATHWAYS) - created} updated'
                ))
        self.stdout.write(self.style.SUCCESS('Done.'))
