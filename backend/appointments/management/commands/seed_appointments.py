"""
Seed demo appointment data for a given hospital tenant.

Usage:
    python manage.py seed_appointments --schema yusra_hospital
    python manage.py seed_appointments --schema hospital_demo

Creates ~30 appointments spread across past and future dates with varied
statuses, reasons, durations and departments for a realistic demo.
"""

import random
from datetime import date, timedelta, time

from django.core.management.base import BaseCommand
from django.db import connection
from django_tenants.utils import tenant_context

from tenants.models import Tenant
from accounts.models import User
from patients.models import Patient
from departments.models import Department
from appointments.models import Appointment


REASONS = [
    "General consultation",
    "Follow-up checkup",
    "Annual physical examination",
    " Hypertension management",
    "Diabetes review",
    "Lab results discussion",
    "Pre-operative assessment",
    "Post-operative review",
    "Vaccination",
    "Chronic disease monitoring",
    "Back pain evaluation",
    "Skin rash examination",
    "Headache & migraine",
    "Respiratory infection",
    "Abdominal pain",
    "Maternal checkup",
    "Child immunization",
    "Eye examination",
    "Mental health consultation",
    "Allergy assessment",
]

NOTES_SAMPLES = [
    "",
    "Patient requested morning appointment",
    "Priority case - referred from triage",
    "New patient registration",
    "",
    "Needs interpreter",
    "",
    "Bring previous lab results",
    "",
    "Wheelchair access required",
]

DURATIONS = [15, 30, 30, 30, 45, 60, 60, 90]
STATUSES = ['scheduled', 'confirmed', 'in_progress', 'completed', 'cancelled', 'no_show']


class Command(BaseCommand):
    help = "Seed demo appointment data for a hospital tenant schema"

    def add_arguments(self, parser):
        parser.add_argument(
            '--schema', default=None,
            help='Tenant schema_name to seed (default: all hospital tenants)',
        )
        parser.add_argument(
            '--count', type=int, default=30,
            help='Number of appointments to create per tenant (default: 30)',
        )
        parser.add_argument(
            '--clear', action='store_true',
            help='Delete existing appointments before seeding',
        )

    def handle(self, *args, **opts):
        schema = opts['schema']
        count = opts['count']
        clear = opts['clear']

        if schema:
            tenants = Tenant.objects.filter(schema_name=schema)
        else:
            tenants = Tenant.objects.filter(type='hospital').exclude(schema_name='public')

        if not tenants.exists():
            self.stdout.write(self.style.WARNING(
                f"No tenants matched schema '{schema}' or type 'hospital'."
            ))
            return

        for tenant in tenants:
            self._seed_tenant(tenant, count, clear)

    def _seed_tenant(self, tenant, count, clear):
        self.stdout.write(f"\n=== Seeding {tenant.name} ({tenant.schema_name}) ===")
        with tenant_context(tenant):
            # Check data availability
            try:
                patients_qs = list(Patient.objects.all())
            except Exception:
                patients_qs = []
            try:
                departments_qs = list(Department.objects.all())
            except Exception:
                departments_qs = []
            try:
                doctors_qs = list(
                    User.objects.filter(role__in=['doctor', 'clinical_officer', 'nurse', 'tenant_admin'])
                )
            except Exception:
                doctors_qs = []

            if not patients_qs:
                self.stdout.write(self.style.WARNING(
                    f"  No patients found in {tenant.schema_name} — skipping."
                ))
                return
            if not doctors_qs:
                self.stdout.write(self.style.WARNING(
                    f"  No staff/doctor users found in {tenant.schema_name} — skipping."
                ))
                return

            self.stdout.write(
                f"  Found {len(patients_qs)} patients, "
                f"{len(doctors_qs)} staff, "
                f"{len(departments_qs)} departments"
            )

            if clear:
                deleted, _ = Appointment.objects.all().delete()
                self.stdout.write(f"  Cleared {deleted} existing appointments")

            today = date.today()
            created = 0

            for i in range(count):
                patient = random.choice(patients_qs)
                doctor = random.choice(doctors_qs)
                department = random.choice(departments_qs) if departments_qs else None

                # Spread dates: 40% past, 10% today, 50% future
                r = random.random()
                if r < 0.40:
                    offset = -random.randint(1, 30)   # past
                elif r < 0.50:
                    offset = 0                         # today
                else:
                    offset = random.randint(1, 60)     # future
                appt_date = today + timedelta(days=offset)

                # Avoid weekends for realism (~70% chance skip weekend)
                if random.random() < 0.70 and appt_date.weekday() >= 5:
                    appt_date += timedelta(days=(7 - appt_date.weekday()))

                hour = random.choice([8, 9, 9, 10, 10, 11, 11, 14, 14, 15, 15, 16])
                minute = random.choice([0, 0, 15, 30])
                appt_time = time(hour=hour, minute=minute)

                duration = random.choice(DURATIONS)
                reason = random.choice(REASONS).strip()
                notes = random.choice(NOTES_SAMPLES)

                # Status based on date
                if offset < 0:
                    status = random.choice(['completed', 'completed', 'completed', 'cancelled', 'no_show'])
                elif offset == 0:
                    status = random.choice(['scheduled', 'confirmed', 'in_progress'])
                else:
                    status = random.choice(['scheduled', 'scheduled', 'confirmed'])

                Appointment.objects.create(
                    patient=patient,
                    staff=doctor,
                    department=department,
                    appointment_date=appt_date,
                    appointment_time=appt_time,
                    duration_minutes=duration,
                    status=status,
                    reason=reason,
                    notes=notes,
                )
                created += 1

            # Distribution summary
            self.stdout.write(self.style.SUCCESS(
                f"  ✓ Created {created} appointments"
            ))
            for s in STATUSES:
                c = Appointment.objects.filter(status=s).count()
                if c:
                    self.stdout.write(f"    {s}: {c}")
