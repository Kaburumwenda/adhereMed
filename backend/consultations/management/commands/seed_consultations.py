"""
Seed demo consultation data for a given hospital tenant.

Usage:
    python manage.py seed_consultations --schema yusra_hospital
    python manage.py seed_consultations --clear
"""

import random
from datetime import datetime, timedelta

from django.core.management.base import BaseCommand
from django_tenants.utils import tenant_context

from tenants.models import Tenant
from accounts.models import User
from patients.models import Patient
from appointments.models import Appointment
from consultations.models import Consultation


CHIEF_COMPLAINTS = [
    "Fever and chills for 3 days",
    "Severe headache with sensitivity to light",
    "Lower back pain radiating to right leg",
    "Abdominal pain and nausea",
    "Chest tightness and shortness of breath",
    "Persistent cough with yellow sputum",
    "Joint pain in both knees",
    "Dizziness and fatigue",
    "Skin rash on arms and face",
    "Sore throat and difficulty swallowing",
    "Blurred vision in left eye",
    "Frequent urination and excessive thirst",
    "Ankle swelling, worse in evenings",
    "Heartburn and acid reflux",
    "Anxiety and sleep difficulties",
    "Child with recurrent ear infections",
    "Post-operative wound check",
    "Routine prenatal checkup",
    "Migraine episodes, weekly",
    "Knee injury from sports activity",
]

HISTORIES = [
    "Condition started 3 days ago, progressively worsening. Patient has tried OTC medication without relief.",
    "Patient reports similar episodes in the past. No known allergies. Not on regular medication.",
    "Chronic condition with acute exacerbation. Patient is on antihypertensive medication.",
    "Sudden onset after physical exertion. No prior history of similar symptoms.",
    "Gradual onset over 2 weeks. Patient has family history of diabetes and hypertension.",
    "",
    "Patient has been experiencing symptoms for over a month, delayed seeking care.",
    "",
    "Recurrent condition, third episode this year. Patient works outdoors.",
    "",
]

EXAMINATIONS = [
    "Patient alert and oriented. Vitals stable. No acute distress observed.",
    "Tenderness on palpation of affected area. Range of motion limited.",
    "Lungs clear on auscultation. Heart sounds normal. No murmurs.",
    "Abdomen soft, non-tender. Bowel sounds present. No organomegaly.",
    "Skin examination reveals erythematous rash with no signs of infection.",
    "Normal physical examination. No abnormalities detected.",
    "",
    "Swelling and bruising noted. Neurovascular examination intact.",
    "Throat inflamed with exudate. Cervical lymphadenopathy present.",
    "",
]

DIAGNOSES = [
    [{"code": "J00", "description": "Acute nasopharyngitis (common cold)"}],
    [{"code": "R51", "description": "Headache, unspecified"}],
    [{"code": "M54.5", "description": "Low back pain"}],
    [{"code": "R10.9", "description": "Unspecified abdominal pain"}],
    [{"code": "J45.909", "description": "Unspecified asthma, uncomplicated"}],
    [{"code": "I10", "description": "Essential (primary) hypertension"}],
    [{"code": "E11.9", "description": "Type 2 diabetes mellitus without complications"}],
    [{"code": "L30.9", "description": "Dermatitis, unspecified"}],
    [{"code": "J02.9", "description": "Acute pharyngitis, unspecified"}],
    [{"code": "F41.1", "description": "Generalized anxiety disorder"}],
    [{"code": "M25.561", "description": "Pain in right knee"}],
    [{"code": "K21.9", "description": "Gastro-esophageal reflux disease without esophagitis"}],
    [{"code": "H53.9", "description": "Unspecified visual disturbance"}],
    [{"code": "N39.0", "description": "Urinary tract infection, site not specified"}],
    [{
        "code": "S83.5",
        "description": "Sprain of cruciate ligament of knee",
    }, {
        "code": "M23.2",
        "description": "Derangement of posterior horn of medial meniscus",
    }],
]

TREATMENTS = [
    "Prescribed rest and hydration. OTC analgesics recommended. Follow-up in 1 week if symptoms persist.",
    "Refer to physiotherapy. Prescribed NSAIDs for pain management. Avoid heavy lifting for 2 weeks.",
    "Started on antihypertensive medication. Lifestyle modification counseling provided.",
    "Prescribed antibiotics course. advised to complete full course even if symptoms improve.",
    "Inhaler prescribed. Trigger avoidance counseling. Follow-up in 2 weeks.",
    "Dietary modification and exercise plan. Blood glucose monitoring recommended.",
    "Refer to dermatology. Prescribed topical corticosteroid cream.",
    "Prescribed oral medication. advised to return if symptoms worsen.",
    "Ordered laboratory tests for further evaluation. Results pending.",
    "Counseling session conducted. Prescribed anxiolytic medication.",
    "Refer to orthopedics. MRI ordered. Rest and analgesics in the interim.",
    "Proton pump inhibitor prescribed. Dietary changes recommended.",
]

NOTES = [
    "Patient cooperative and compliant with treatment plan.",
    "Patient advised to seek emergency care if symptoms worsen significantly.",
    "",
    "Follow-up scheduled via appointment system.",
    "Patient declined hospital admission, will manage as outpatient.",
    "",
    "Family present and engaged in care discussion.",
    "",
    "Tele-medicine follow-up considered for remote monitoring.",
    "",
]

VITALS = [
    {"temperature": 37.2, "heart_rate": 80, "blood_pressure_systolic": 120, "blood_pressure_diastolic": 80, "respiratory_rate": 16, "oxygen_saturation": 98, "weight": 72, "height": 170},
    {"temperature": 38.5, "heart_rate": 95, "blood_pressure_systolic": 128, "blood_pressure_diastolic": 84, "respiratory_rate": 18, "oxygen_saturation": 96, "weight": 68, "height": 165},
    {"temperature": 36.8, "heart_rate": 72, "blood_pressure_systolic": 145, "blood_pressure_diastolic": 92, "respiratory_rate": 14, "oxygen_saturation": 98, "weight": 85, "height": 178},
    {"temperature": 36.5, "heart_rate": 68, "blood_pressure_systolic": 118, "blood_pressure_diastolic": 76, "respiratory_rate": 15, "oxygen_saturation": 99, "weight": 60, "height": 160},
    {"temperature": 37.0, "heart_rate": 88, "blood_pressure_systolic": 130, "blood_pressure_diastolic": 85, "respiratory_rate": 20, "oxygen_saturation": 94, "weight": 75, "height": 172},
    {"temperature": 36.9, "heart_rate": 76, "blood_pressure_systolic": 125, "blood_pressure_diastolic": 78, "respiratory_rate": 16, "oxygen_saturation": 97, "weight": 90, "height": 180},
]


class Command(BaseCommand):
    help = "Seed demo consultation data for a hospital tenant schema"

    def add_arguments(self, parser):
        parser.add_argument('--schema', default=None, help='Tenant schema_name to seed (default: all hospital tenants)')
        parser.add_argument('--count', type=int, default=25, help='Number of consultations to create (default: 25)')
        parser.add_argument('--clear', action='store_true', help='Delete existing consultations before seeding')

    def handle(self, *args, **opts):
        schema = opts['schema']
        count = opts['count']
        clear = opts['clear']

        if schema:
            tenants = Tenant.objects.filter(schema_name=schema)
        else:
            tenants = Tenant.objects.filter(type='hospital').exclude(schema_name='public')

        for tenant in tenants:
            self._seed_tenant(tenant, count, clear)

    def _seed_tenant(self, tenant, count, clear):
        self.stdout.write(f"\n=== Seeding {tenant.name} ({tenant.schema_name}) ===")
        with tenant_context(tenant):
            try:
                patients_qs = list(Patient.objects.all())
            except Exception:
                patients_qs = []
            try:
                doctors_qs = list(User.objects.filter(role__in=['doctor', 'clinical_officer', 'nurse', 'tenant_admin']))
            except Exception:
                doctors_qs = []
            try:
                appts_qs = list(Appointment.objects.all())
            except Exception:
                appts_qs = []

            if not patients_qs:
                self.stdout.write(self.style.WARNING(f"  No patients found in {tenant.schema_name} — skipping."))
                return
            if not doctors_qs:
                self.stdout.write(self.style.WARNING(f"  No doctors found in {tenant.schema_name} — skipping."))
                return

            self.stdout.write(f"  Found {len(patients_qs)} patients, {len(doctors_qs)} doctors, {len(appts_qs)} appointments")

            if clear:
                deleted, _ = Consultation.objects.all().delete()
                self.stdout.write(f"  Cleared {deleted} existing consultations")

            created = 0
            now = datetime.now()
            # Build a pool of unique appointments we can link to
            used_appt_ids = set()
            available_appts = list(appts_qs)
            random.shuffle(available_appts)
            for i in range(count):
                patient = random.choice(patients_qs)
                doctor = random.choice(doctors_qs)

                # Try to link to an unused appointment if one exists
                appointment = None
                while available_appts:
                    candidate = available_appts.pop()
                    if candidate.patient_id == patient.id and candidate.id not in used_appt_ids:
                        appointment = candidate
                        used_appt_ids.add(candidate.id)
                        break

                offset = random.randint(-60, 5)
                created_at = now + timedelta(days=offset, hours=random.randint(-12, 12), minutes=random.randint(0, 59))
                if created_at > now:
                    created_at = now - timedelta(hours=random.randint(1, 72))

                Consultation.objects.create(
                    appointment=appointment,
                    patient=patient,
                    doctor=doctor,
                    chief_complaint=random.choice(CHIEF_COMPLAINTS),
                    history_present_illness=random.choice(HISTORIES),
                    examination_findings=random.choice(EXAMINATIONS),
                    diagnosis=random.choice(DIAGNOSES),
                    treatment_plan=random.choice(TREATMENTS),
                    notes=random.choice(NOTES),
                    vital_signs=random.choice(VITALS),
                    created_at=created_at,
                    updated_at=created_at,
                )
                created += 1

            self.stdout.write(self.style.SUCCESS(f"  Created {created} consultations"))
            self.stdout.write(f"  Total consultations in tenant: {Consultation.objects.count()}")
