"""
Seed a clinic tenant with realistic demo data:
  • Clinical staff (doctors, clinical officers, nurses, receptionist, cashier)
  • Patients with demographics
  • Departments
  • Appointments (past + today + future)
  • Consultations with diagnoses and vitals
  • Temperature checks for escalations/homecare-vitals

Usage:
  python manage.py seed_clinic --schema riverside_clinic
  python manage.py seed_clinic --schema riverside_clinic --clear
"""
import random
from datetime import date, datetime, timedelta

from django.core.management.base import BaseCommand
from django.db import connection
from django_tenants.utils import tenant_context
from tenants.models import Tenant
from accounts.models import User
from patients.models import Patient
from appointments.models import Appointment
from departments.models import Department
from consultations.models import Consultation

FIRST_NAMES = ['James', 'Mary', 'John', 'Patricia', 'Robert', 'Jennifer', 'Michael',
               'Linda', 'William', 'Elizabeth', 'David', 'Barbara', 'Joseph', 'Susan',
               'Thomas', 'Jessica', 'Charles', 'Sarah', 'Daniel', 'Karen', 'Peter',
               'Nancy', 'Paul', 'Grace', 'Brian', 'Faith', 'Kevin', 'Joy']
LAST_NAMES = ['Kamau', 'Mwangi', 'Ochieng', 'Wanjiru', 'Kiptoo', 'Achieng', 'Mutua',
              'Njeri', 'Ouma', 'Wafula', 'Chebet', 'Akinyi', 'Kariuki', 'Wambui',
              'Omondi', 'Atieno', 'Maina', 'Nyong\'o', 'Korir', 'Jepkemboi']
DOCTOR_FIRST = ['Ayan', 'Kalkidan', 'Daniel', 'Wanjiku', 'Tobias', 'Penninah']
DOCTOR_LAST = ['Gatabi', 'Gebretsadik', 'Onyango', 'Kibe', 'Mwenda', 'Auma']

CHIEF_COMPLAINTS = [
    'Headache and fever for 3 days', 'Persistent cough with chest pain',
    'Lower back pain', 'Abdominal cramps and nausea', 'Blurred vision',
    'Sore throat and difficulty swallowing', 'Joint pain in both knees',
    'Skin rash on arms and legs', 'Frequent urination and thirst',
    'Shortness of breath on exertion', 'Dizziness and fatigue',
    'Ear pain with discharge', 'High blood pressure reading at home',
    'Allergic reaction to unknown trigger', 'Migraine with aura',
    'Ankle swelling after fall', 'Insomnia and anxiety',
    'Numbness in right hand', 'Heartburn after meals', 'Fever with chills',
]
DIAGNOSES = [
    {'code': 'J00', 'description': 'Acute nasopharyngitis (common cold)'},
    {'code': 'R51', 'description': 'Headache'},
    {'code': 'M54.5', 'description': 'Low back pain'},
    {'code': 'I10', 'description': 'Essential hypertension'},
    {'code': 'E11.9', 'description': 'Type 2 diabetes mellitus without complications'},
    {'code': 'J45.909', 'description': 'Unspecified asthma, uncomplicated'},
    {'code': 'R10.9', 'description': 'Unspecified abdominal pain'},
    {'code': 'K21.9', 'description': 'Reflux esophagitis'},
    {'code': 'L20.9', 'description': 'Atopic dermatitis, unspecified'},
    {'code': 'R07.9', 'description': 'Chest pain, unspecified'},
    {'code': 'F41.1', 'description': 'Generalized anxiety disorder'},
    {'code': 'M25.561', 'description': 'Pain in right knee'},
]
HISTORIES = [
    'Patient reports symptoms started 3 days ago, progressively worsening.',
    'Chronic condition, patient on maintenance medication.',
    'Acute onset after physical exertion. No prior episodes.',
    'Recurrent condition, third episode this year.',
    'Patient has family history of similar complaints.',
]
EXAMINATIONS = [
    'Vital signs stable. Examination unremarkable.',
    'Lungs clear on auscultation. Heart sounds normal.',
    'Abdomen soft, non-tender. No organomegaly.',
    'Mild tenderness on palpation. Range of motion full.',
    'Skin examination shows erythematous rash. No exudate.',
]
TREATMENT_PLANS = [
    'Symptomatic treatment prescribed. Follow-up in 7 days.',
    'Started on appropriate medication. Lifestyle counseling provided.',
    'Refer to specialist for further evaluation.',
    'Conservative management initiated. Patient education provided.',
    'Lab tests ordered. Review results at next visit.',
]
NOTES = [
    'Patient cooperative and compliant with treatment plan.',
    'Advised to return if symptoms persist or worsen.',
    'Patient educated on medication adherence.',
    'Follow-up scheduled.',
]
VITAL_SETS = [
    {'temperature': 36.8, 'heart_rate': 72, 'blood_pressure_systolic': 120, 'blood_pressure_diastolic': 80, 'respiratory_rate': 16, 'oxygen_saturation': 98, 'weight': 70, 'height': 170},
    {'temperature': 37.2, 'heart_rate': 80, 'blood_pressure_systolic': 128, 'blood_pressure_diastolic': 82, 'respiratory_rate': 18, 'oxygen_saturation': 97, 'weight': 65, 'height': 160},
    {'temperature': 38.5, 'heart_rate': 95, 'blood_pressure_systolic': 135, 'blood_pressure_diastolic': 88, 'respiratory_rate': 20, 'oxygen_saturation': 94, 'weight': 75, 'height': 175},
    {'temperature': 36.5, 'heart_rate': 68, 'blood_pressure_systolic': 110, 'blood_pressure_diastolic': 70, 'respiratory_rate': 14, 'oxygen_saturation': 99, 'weight': 80, 'height': 180},
    {'temperature': 37.0, 'heart_rate': 85, 'blood_pressure_systolic': 140, 'blood_pressure_diastolic': 90, 'respiratory_rate': 18, 'oxygen_saturation': 96, 'weight': 68, 'height': 165},
    {'temperature': 38.0, 'heart_rate': 90, 'blood_pressure_systolic': 125, 'blood_pressure_diastolic': 78, 'respiratory_rate': 19, 'oxygen_saturation': 95, 'weight': 72, 'height': 168},
]


class Command(BaseCommand):
    help = 'Seeds a clinic tenant with clinical staff, patients, appointments, and consultations.'

    def add_arguments(self, parser):
        parser.add_argument('--schema', type=str, help='Tenant schema name to seed')
        parser.add_argument('--clear', action='store_true', help='Clear existing seeded data before seeding')
        parser.add_argument('--count', type=int, default=25, help='Number of consultations/appointments per tenant')
        parser.add_argument('--all-clinics', action='store_true', help='Seed all clinic-type tenants')

    def handle(self, *args, **options):
        schema = options.get('schema')
        all_clinics = options.get('all_clinics')

        if all_clinics:
            tenants = Tenant.objects.filter(type='clinic', is_active=True)
        elif schema:
            tenants = Tenant.objects.filter(schema_name=schema, is_active=True)
        else:
            tenants = Tenant.objects.filter(type='clinic', is_active=True)

        if not tenants:
            self.stdout.write(self.style.WARNING(
                f"No clinic tenants found{f' matching schema={schema}' if schema else ''}."
            ))
            return

        for tenant in tenants:
            self._seed_tenant(tenant, options.get('count', 25), options.get('clear', False))

    def _seed_tenant(self, tenant, count, clear):
        self.stdout.write(f"\n=== Seeding {tenant.name} ({tenant.schema_name}) ===")
        with tenant_context(tenant):
            if clear:
                Consultation.objects.all().delete()
                Appointment.objects.all().delete()
                Patient.objects.all().delete()
                # Remove non-admin users we created
                User.objects.exclude(role='tenant_admin').filter(
                    email__contains='@riversideclinic'
                ).delete()
                self.stdout.write("  Cleared existing data")

            # ─── Create clinical staff ──────────────────────────────────
            staff_config = [
                ('doctor', 'Dr. Ayan', 'Gatabi', 'doctor1@riversideclinic.co'),
                ('doctor', 'Dr. Kalkidan', 'Gebretsadik', 'doctor2@riversideclinic.co'),
                ('doctor', 'Dr. Daniel', 'Onyango', 'doctor3@riversideclinic.co'),
                ('doctor', 'Dr. Wanjiku', 'Kibe', 'doctor4@riversideclinic.co'),
                ('clinical_officer', 'Cecilia', 'Mwende', 'co@riversideclinic.co'),
                ('nurse', 'Jane', 'Wambui', 'nurse@riversideclinic.co'),
                ('nurse', 'Peter', 'Omondi', 'nurse2@riversideclinic.co'),
                ('receptionist', 'Mary', 'Atieno', 'reception@riversideclinic.co'),
                ('cashier', 'John', 'Maina', 'cashier@riversideclinic.co'),
                ('pharmacist', 'Esther', 'Korir', 'pharmacy@riversideclinic.co'),
            ]
            staff_users = []
            for role, first, last, email in staff_config:
                user, created = User.objects.get_or_create(
                    email=email,
                    defaults={
                        'first_name': first.replace('Dr. ', ''),
                        'last_name': last,
                        'role': role,
                        'tenant': tenant,
                        'is_active': True,
                    },
                )
                if created:
                    user.set_password('ClinicStaff123')
                    user.save()
                    self.stdout.write(f"  ✓ Created {role}: {first} {last}")
                staff_users.append(user)

            doctors_qs = [u for u in staff_users if u.role in ['doctor', 'clinical_officer', 'nurse', 'tenant_admin']]
            # Include the tenant admin (already created during registration) as a potential doctor
            admins = list(User.objects.filter(role='tenant_admin'))
            doctors_qs = list(set(doctors_qs + admins))

            # ─── Create patients ─────────────────────────────────────────
            n_patients = 15
            patients_list = []
            for i in range(n_patients):
                first = random.choice(FIRST_NAMES)
                last = random.choice(LAST_NAMES)
                email = f'patient{i + 1}@riversideclinic.co'
                user, created = User.objects.get_or_create(
                    email=email,
                    defaults={
                        'first_name': first,
                        'last_name': last,
                        'role': 'patient',
                        'tenant': tenant,
                        'is_active': True,
                    },
                )
                if created:
                    user.set_password('PatientPass123')
                    user.save()

                patient, p_created = Patient.objects.get_or_create(
                    user=user,
                    defaults={
                        'patient_number': f'RMC{1000 + i}',
                        'date_of_birth': date(
                            random.randint(1950, 2005), random.randint(1, 12), random.randint(1, 28)
                        ),
                        'gender': random.choice(['male', 'female']),
                        'blood_type': random.choice(['A+', 'B+', 'O+', 'AB+', 'O-', 'A-']),
                        'address': f'{random.randint(1, 99)} Riverside Drive, Nairobi',
                        'emergency_contact_name': random.choice(FIRST_NAMES) + ' ' + random.choice(LAST_NAMES),
                        'emergency_contact_phone': f'+2547{random.randint(10000000, 99999999)}',
                        'emergency_contact_relation': random.choice(['Spouse', 'Parent', 'Sibling', 'Guardian']),
                        'allergies': random.sample(['Penicillin', 'Sulfa', 'Peanuts', 'Latex', 'Aspirin'], k=random.randint(0, 2)),
                        'chronic_conditions': random.sample(['Hypertension', 'Diabetes', 'Asthma', 'Arthritis'], k=random.randint(0, 1)),
                        'insurance_provider': random.choice(['NHIF', 'Jubilee', 'AAR Healthcare', 'UAP Old Mutual', '', '', '']),
                        'insurance_number': f'INS{random.randint(10000, 99999)}' if random.random() > 0.3 else '',
                    },
                )
                if p_created:
                    patients_list.append(patient)
                else:
                    patients_list.append(patient)

            self.stdout.write(f"  ✓ Ensured {len(patients_list)} patients exist")

            # ─── Departments should already be seeded ───────────────────
            departments_qs = list(Department.objects.all())
            if not departments_qs:
                self.stdout.write(self.style.WARNING(
                    "  No departments found — run: python manage.py seed_departments --schema " + tenant.schema_name
                ))

            # ─── Create appointments ─────────────────────────────────────
            today = date.today()
            appt_count = count
            created_appts = 0
            for i in range(appt_count):
                patient = random.choice(patients_list)
                doctor = random.choice(doctors_qs)
                dept = random.choice(departments_qs) if departments_qs else None

                r = random.random()
                if r < 0.35:
                    offset = -random.randint(1, 30)
                elif r < 0.45:
                    offset = 0
                else:
                    offset = random.randint(1, 60)
                appt_date = today + timedelta(days=offset)

                hour = random.randint(8, 16)
                minute = random.choice([0, 15, 30, 45])

                status = (
                    'completed' if offset < 0 else
                    'in_progress' if offset == 0 and random.random() > 0.7 else
                    'scheduled'
                )

                Appointment.objects.create(
                    patient=patient,
                    staff=doctor,
                    department=dept,
                    appointment_date=appt_date,
                    appointment_time=datetime.strptime(f'{hour:02d}:{minute:02d}', '%H:%M').time(),
                    status=status,
                    reason=random.choice(CHIEF_COMPLAINTS),
                    notes=random.choice(NOTES),
                )
                created_appts += 1
            self.stdout.write(f"  ✓ Created {created_appts} appointments")

            # ─── Create consultations ────────────────────────────────────
            # Get appointments available (only completed ones) for linking
            past_appts = list(Appointment.objects.filter(
                appointment_date__lte=today, patient__in=patients_list
            ))
            used_appt_ids = set()
            available_appts = list(past_appts)
            random.shuffle(available_appts)

            created_consultations = 0
            for i in range(min(count, len(patients_list))):
                patient = random.choice(patients_list)
                doctor = random.choice(doctors_qs)

                appointment = None
                while available_appts:
                    candidate = available_appts.pop()
                    if candidate.patient_id == patient.id and candidate.id not in used_appt_ids:
                        appointment = candidate
                        used_appt_ids.add(candidate.id)
                        break

                diagnosis = random.sample(DIAGNOSES, k=random.randint(1, 2))
                Consultation.objects.create(
                    appointment=appointment,
                    patient=patient,
                    doctor=doctor,
                    chief_complaint=random.choice(CHIEF_COMPLAINTS),
                    history_present_illness=random.choice(HISTORIES),
                    examination_findings=random.choice(EXAMINATIONS),
                    diagnosis=diagnosis,
                    treatment_plan=random.choice(TREATMENT_PLANS),
                    notes=random.choice(NOTES),
                    vital_signs=random.choice(VITAL_SETS),
                )
                created_consultations += 1
            self.stdout.write(
                self.style.SUCCESS(
                    f"  ✓ Created {created_consultations} consultations"
                )
            )

        self.stdout.write(self.style.SUCCESS(f"\n✓ Clinic {tenant.name} seeded successfully!"))
        self.stdout.write(f"  Login: admin@{tenant.schema_name.replace('_', '.')}.co / ClinicPass123")
