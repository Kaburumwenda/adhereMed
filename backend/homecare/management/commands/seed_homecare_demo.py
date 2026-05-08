"""Seed demo data for the homecare tenant.

Usage:
    python manage.py tenant_command seed_homecare_demo --schema=homecare_demo
"""
import random
from datetime import timedelta

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand
from django.utils import timezone

from homecare.models import (
    HomecareCompanyProfile, Caregiver, HomecarePatient, CaregiverSchedule,
    CaregiverNote, TreatmentPlan, MedicationSchedule, DoseEvent,
    Escalation, EscalationRule, TeleconsultRoom, HomecareAppointment,
    InsurancePolicy, InsuranceClaim, Consent,
)

User = get_user_model()


class Command(BaseCommand):
    help = 'Seed demo homecare data inside the current tenant schema.'

    def handle(self, *args, **options):
        # Company profile
        company, _ = HomecareCompanyProfile.objects.get_or_create(
            legal_name='Demo Homecare Services Ltd',
            defaults={
                'registration_number': 'HC-2026-001',
                'city': 'Nairobi',
                'country': 'Kenya',
                'contact_phone': '+254700000003',
                'contact_email': 'admin@demohomecare.local',
                'service_areas': ['Westlands', 'Karen', 'Lavington', 'Kileleshwa'],
                'accreditations': ['Kenya Ministry of Health', 'ISO 9001:2015'],
                'about': 'Premium in-home care for chronic conditions and post-op recovery.',
            },
        )
        self.stdout.write(self.style.SUCCESS(f'Company: {company.legal_name}'))

        # Default escalation rule
        EscalationRule.objects.get_or_create(
            name='72h missed-dose escalation',
            defaults={
                'description': 'Triggers when patient misses doses within 72 hours.',
                'missed_doses_window_hours': 72,
                'missed_count_threshold': 1,
            },
        )

        # Tenant admin
        admin, _ = User.objects.get_or_create(
            email='admin@demohomecare.local',
            defaults={'first_name': 'Sara', 'last_name': 'Otieno',
                      'role': 'homecare_admin', 'is_staff': True},
        )
        admin.set_password('homecare1234')
        admin.role = 'homecare_admin'
        admin.is_staff = True
        admin.save()

        # Caregivers
        caregivers = []
        for i, (fn, ln, lic) in enumerate([
            ('Joyce', 'Wanjiku', 'CG-001'),
            ('Peter', 'Kamau', 'CG-002'),
            ('Mary', 'Achieng', 'CG-003'),
        ]):
            user, _ = User.objects.get_or_create(
                email=f'{fn.lower()}@demohomecare.local',
                defaults={'first_name': fn, 'last_name': ln, 'role': 'caregiver'},
            )
            user.set_password('caregiver1234')
            user.role = 'caregiver'
            user.save()
            cg, _ = Caregiver.objects.get_or_create(
                user=user,
                defaults={
                    'license_number': lic,
                    'specialties': random.sample(
                        ['elderly', 'post-op', 'pediatric', 'palliative', 'diabetes'], 2,
                    ),
                    'bio': f'{fn} is an experienced caregiver with 5+ years.',
                    'hourly_rate': 800,
                    'rating': round(random.uniform(4.0, 5.0), 2),
                    'total_visits': random.randint(50, 250),
                    'hire_date': (timezone.localdate() - timedelta(days=365 * 2)),
                    'employment_status': 'active',
                },
            )
            caregivers.append(cg)
        self.stdout.write(self.style.SUCCESS(f'Caregivers: {len(caregivers)}'))

        # Patients
        patients = []
        for i, (fn, ln, dx, risk) in enumerate([
            ('John', 'Mwangi', 'Type 2 Diabetes', 'medium'),
            ('Grace', 'Njeri', 'Post-hip replacement', 'low'),
            ('Samuel', 'Otieno', 'Stage 3 CKD', 'high'),
            ('Faith', 'Akinyi', 'Hypertension', 'low'),
            ('Daniel', 'Kibet', 'COPD', 'high'),
        ]):
            user, _ = User.objects.get_or_create(
                email=f'patient{i+1}@demohomecare.local',
                defaults={'first_name': fn, 'last_name': ln, 'role': 'patient'},
            )
            user.set_password('patient1234')
            user.role = 'patient'
            user.save()
            patient, _ = HomecarePatient.objects.get_or_create(
                user=user,
                defaults={
                    'date_of_birth': timezone.localdate() - timedelta(days=365 * random.randint(45, 80)),
                    'gender': random.choice(['Male', 'Female']),
                    'address': f'{random.randint(1, 200)} Demo Lane, Nairobi',
                    'primary_diagnosis': dx,
                    'allergies': random.choice(['None', 'Penicillin', 'Sulfa drugs']),
                    'emergency_contacts': [
                        {'name': f'Family of {fn}', 'relationship': 'Spouse',
                         'phone': '+2547' + str(random.randint(10000000, 99999999))},
                    ],
                    'assigned_caregiver': caregivers[i % len(caregivers)],
                    'risk_level': risk,
                },
            )
            patients.append(patient)
        self.stdout.write(self.style.SUCCESS(f'Patients: {len(patients)}'))

        # Treatment plans + medication schedules + dose events
        meds = [
            ('Metformin', '500mg', ['08:00', '20:00']),
            ('Lisinopril', '10mg', ['08:00']),
            ('Atorvastatin', '20mg', ['20:00']),
            ('Insulin Glargine', '20 units', ['22:00']),
            ('Salbutamol Inhaler', '2 puffs', ['08:00', '14:00', '20:00']),
        ]
        for patient in patients:
            plan, _ = TreatmentPlan.objects.get_or_create(
                patient=patient, title=f'Care plan: {patient.primary_diagnosis}',
                defaults={
                    'diagnosis': patient.primary_diagnosis,
                    'goals': ['Stabilise condition', 'Maintain adherence', 'Quality of life'],
                    'start_date': timezone.localdate() - timedelta(days=30),
                },
            )
            chosen = random.sample(meds, 2)
            for name, dose, times in chosen:
                sched, _ = MedicationSchedule.objects.get_or_create(
                    patient=patient, medication_name=name,
                    defaults={
                        'treatment_plan': plan,
                        'dose': dose,
                        'route': 'oral' if 'Inhaler' not in name else 'inhaled',
                        'times_of_day': times,
                        'start_date': timezone.localdate() - timedelta(days=14),
                        'requires_caregiver': random.choice([True, False]),
                        'instructions': 'Take with food.' if name == 'Metformin' else '',
                    },
                )
                # Generate 7 days of dose events
                for d in range(-3, 4):
                    day = timezone.localdate() + timedelta(days=d)
                    for t in times:
                        hh, mm = [int(x) for x in t.split(':')]
                        from datetime import datetime, time as dt_time
                        naive = datetime.combine(day, dt_time(hh, mm))
                        scheduled = timezone.make_aware(naive)
                        status = 'pending'
                        if scheduled < timezone.now():
                            status = random.choices(
                                ['taken', 'missed', 'skipped'],
                                weights=[80, 15, 5], k=1,
                            )[0]
                        DoseEvent.objects.get_or_create(
                            schedule=sched, scheduled_at=scheduled,
                            defaults={
                                'status': status,
                                'administered_at': scheduled if status == 'taken' else None,
                                'administered_by_caregiver': (
                                    patient.assigned_caregiver if status == 'taken' else None
                                ),
                            },
                        )

        # Caregiver schedules (next 7 days)
        for patient in patients:
            cg = patient.assigned_caregiver
            for d in range(0, 7):
                day = timezone.localdate() + timedelta(days=d)
                from datetime import datetime, time as dt_time
                start = timezone.make_aware(datetime.combine(day, dt_time(10, 0)))
                end = start + timedelta(hours=2)
                CaregiverSchedule.objects.get_or_create(
                    caregiver=cg, patient=patient, start_at=start,
                    defaults={'end_at': end, 'shift_type': 'visit',
                              'status': 'scheduled' if d > 0 else 'checked_in'},
                )

        # Sample notes
        for patient in patients[:3]:
            CaregiverNote.objects.get_or_create(
                patient=patient, caregiver=patient.assigned_caregiver,
                category='vitals', content='Routine vitals check.',
                defaults={'vitals': {'bp': '128/82', 'hr': 76, 'temp': 36.6, 'spo2': 97}},
            )

        # Insurance + claim
        for patient in patients[:3]:
            policy, _ = InsurancePolicy.objects.get_or_create(
                patient=patient, provider_name='NHIF',
                policy_number=f'NHIF-{random.randint(100000, 999999)}',
                defaults={
                    'coverage': {'visits': 80, 'medication': 70, 'teleconsult': 100},
                    'valid_from': timezone.localdate() - timedelta(days=180),
                    'valid_to': timezone.localdate() + timedelta(days=365),
                },
            )
            InsuranceClaim.objects.get_or_create(
                patient=patient, policy=policy,
                claim_type='visit', service_start=timezone.localdate() - timedelta(days=10),
                service_end=timezone.localdate() - timedelta(days=10),
                amount_requested=4500,
                defaults={
                    'status': random.choice(['submitted', 'approved', 'denied']),
                    'submitted_at': timezone.now() - timedelta(days=8),
                },
            )

        # One open escalation
        if patients:
            Escalation.objects.get_or_create(
                patient=patients[2], reason='3 missed doses in last 72h',
                defaults={
                    'detail': f'{patients[2].user.full_name} missed insulin schedule.',
                    'severity': 'high', 'status': 'open',
                },
            )

        # Teleconsult room
        TeleconsultRoom.objects.get_or_create(
            patient=patients[0],
            doctor_user_id=admin.id,
            scheduled_at=timezone.now() + timedelta(days=1),
            defaults={'duration_minutes': 30, 'provider': 'jitsi'},
        )

        # Consents
        for patient in patients:
            Consent.objects.get_or_create(
                patient=patient, scope='records',
                defaults={'granted_to': 'Demo Homecare Services Ltd'},
            )

        self.stdout.write(self.style.SUCCESS('\nHomecare demo data seeded.'))
        self.stdout.write('Login: admin@demohomecare.local / homecare1234 (homecare admin)')
        self.stdout.write('Login: joyce@demohomecare.local / caregiver1234 (caregiver)')
        self.stdout.write('Login: patient1@demohomecare.local / patient1234 (patient)')
