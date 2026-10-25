import uuid
import secrets
import random
from datetime import date, timedelta, time as dtime
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.db import transaction
from django.utils import timezone
from rest_framework import viewsets, filters, status
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.generics import CreateAPIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django_filters.rest_framework import DjangoFilterBackend

from .models import CareNote, Patient, VitalObservation
from .serializers import (
    CareNoteSerializer, PatientSerializer, PatientRegistrationSerializer,
    VitalObservationSerializer,
)
from .vitals import bmi_for, news2_risk, score_news2
from clinic_sites.mixins import ClinicSiteScopedMixin
from clinic_sites.utils import resolve_site

User = get_user_model()


def _to_list(val):
    """Accept a string or list for allergies / chronic_conditions."""
    if not val:
        return []
    if isinstance(val, list):
        return val
    return [v.strip() for v in str(val).split(',') if v.strip()]


def _clean_national_id(data):
    """Return a trimmed national ID, or None when the caller left it blank.

    `Patient.national_id` is `unique=True, null=True`. Storing `''` therefore
    makes the *second* patient without an ID fail with an IntegrityError, so
    blanks must be persisted as NULL (multiple NULLs are allowed).
    Also accepts the `id_number` alias used by other clients.
    """
    raw = data.get('national_id')
    if raw is None:
        raw = data.get('id_number')
    return (str(raw).strip() or None) if raw else None


def _clean_coord(value, limit):
    """Coerce a lat/lng value to a bounded Decimal, or None when unusable."""
    if value is None or value == '':
        return None
    try:
        dec = Decimal(str(value))
    except (TypeError, ValueError, ArithmeticError):
        return None
    if abs(dec) > limit:
        return None
    return dec.quantize(Decimal('0.000001'))


class PatientViewSet(ClinicSiteScopedMixin, viewsets.ModelViewSet):
    queryset = Patient.objects.select_related('user', 'clinic_site').all()
    serializer_class = PatientSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['gender', 'blood_type', 'clinic_site', 'patient_category']
    search_fields = ['patient_number', 'user__first_name', 'user__last_name', 'national_id',
                     'guardian_name', 'guardian_phone']
    ordering_fields = ['created_at', 'patient_number']

    @transaction.atomic
    def create(self, request, *args, **kwargs):
        data = request.data
        email = (data.get('email') or '').strip()
        password = data.get('password') or ''
        has_portal = bool(password)

        # Email is only compulsory for patients who get a dashboard login.
        if has_portal and not email:
            return Response(
                {'email': ['Email is required for a patient dashboard login.']},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if email and User.objects.filter(email=email).exists():
            return Response({'email': ['A user with this email already exists.']}, status=status.HTTP_400_BAD_REQUEST)

        if not has_portal:
            password = secrets.token_urlsafe(12)

        patient_number = f'PT-{uuid.uuid4().hex[:8].upper()}'
        # Clinic-only records still need a unique value in the shared email
        # column — use a non-deliverable placeholder instead of blocking
        # reception on a field the patient does not have.
        if not email:
            email = f'{patient_number.lower()}@no-email.adheremed.local'

        user = User(
            email=email,
            first_name=data.get('first_name', ''),
            middle_name=data.get('middle_name', '') or '',
            last_name=data.get('last_name', ''),
            phone=data.get('phone', ''),
            role=User.Role.PATIENT,
        )
        user.set_password(password)
        user.save()

        # Record how the patient got registered (facility type or explicit value).
        valid_sources = {c[0] for c in Patient.RegistrationSource.choices}
        source = (data.get('registration_source') or '').strip().lower()
        if source not in valid_sources:
            tenant_type = getattr(getattr(request, 'tenant', None), 'tenant_type', '') or ''
            source = tenant_type if tenant_type in valid_sources else Patient.RegistrationSource.OTHER

        # Clinical stream — general by default, paediatrics stores the guardian
        # block the front desk needs at check-in.
        valid_categories = {c[0] for c in Patient.Category.choices}
        category = (data.get('patient_category') or '').strip().lower()
        if category not in valid_categories:
            category = Patient.Category.GENERAL

        valid_immunisation = {c[0] for c in Patient.ImmunisationStatus.choices}
        immunisation = (data.get('immunisation_status') or '').strip().lower()

        patient = Patient.objects.create(
            user=user,
            patient_number=patient_number,
            clinic_site=self._resolve_create_site(data),
            registration_source=source,
            patient_category=category,
            guardian_name=data.get('guardian_name', '') or '',
            guardian_phone=data.get('guardian_phone', '') or '',
            guardian_relationship=data.get('guardian_relationship', '') or '',
            immunisation_status=immunisation if immunisation in valid_immunisation else '',
            date_of_birth=data.get('date_of_birth') or '1900-01-01',
            gender=data.get('gender') or 'other',
            blood_type=data.get('blood_type') or data.get('blood_group', ''),
            # A blank national ID must be NULL — an empty string collides on the
            # unique constraint once more than one patient has no ID.
            national_id=_clean_national_id(data),
            address=data.get('address', ''),
            latitude=_clean_coord(data.get('latitude'), 90),
            longitude=_clean_coord(data.get('longitude'), 180),
            address_place_id=data.get('address_place_id', '') or '',
            allergies=_to_list(data.get('allergies', [])),
            chronic_conditions=_to_list(data.get('chronic_conditions', [])),
            emergency_contact_name=data.get('emergency_contact_name', ''),
            emergency_contact_phone=data.get('emergency_contact_phone', ''),
            emergency_contact_relation=data.get('emergency_contact_relation', ''),
            insurance_provider=data.get('insurance_provider', ''),
            insurance_number=data.get('insurance_number') or data.get('insurance_policy_number', ''),
            has_portal_access=has_portal,
            shared_fields=data.get('shared_fields') or [],
        )
        return Response(PatientSerializer(patient).data, status=status.HTTP_201_CREATED)

    def _resolve_create_site(self, data):
        """Clinic the patient is registered at: payload → header/query → None."""
        try:
            explicit = data.get('clinic_site')
        except AttributeError:
            explicit = None
        if explicit:
            from clinic_sites.models import ClinicSite
            return ClinicSite.objects.filter(pk=explicit).first()
        return self._request_site()

    def partial_update(self, request, *args, **kwargs):
        patient = self.get_object()
        data = request.data

        # Patient profile fields (with frontend alias support)
        profile_map = {
            'date_of_birth': 'date_of_birth',
            'gender': 'gender',
            'address': 'address',
            'emergency_contact_name': 'emergency_contact_name',
            'emergency_contact_phone': 'emergency_contact_phone',
            'emergency_contact_relation': 'emergency_contact_relation',
            'insurance_provider': 'insurance_provider',
        }
        for src, dest in profile_map.items():
            if src in data:
                setattr(patient, dest, data[src])

        # Field name aliases
        if 'blood_type' in data:
            patient.blood_type = data['blood_type']
        elif 'blood_group' in data:
            patient.blood_type = data['blood_group']
        if 'national_id' in data:
            patient.national_id = (data['national_id'] or '').strip() or None
        elif 'id_number' in data:
            patient.national_id = (data['id_number'] or '').strip() or None
        if 'insurance_number' in data:
            patient.insurance_number = data['insurance_number']
        elif 'insurance_policy_number' in data:
            patient.insurance_number = data['insurance_policy_number']
        if 'allergies' in data:
            patient.allergies = _to_list(data['allergies'])
        if 'chronic_conditions' in data:
            patient.chronic_conditions = _to_list(data['chronic_conditions'])
        patient.save()

        # Update user fields
        user = patient.user
        user_changed = False
        for f in ['first_name', 'last_name', 'email', 'phone']:
            if f in data and data[f]:
                setattr(user, f, data[f])
                user_changed = True
        if user_changed:
            user.save()

        return Response(PatientSerializer(patient).data)

    @action(detail=False, methods=['get', 'patch'], url_path='me',
            permission_classes=[IsAuthenticated])
    def me(self, request):
        """Return or update the patient profile of the currently logged-in user."""
        try:
            patient = Patient.objects.select_related('user').get(user=request.user)
        except Patient.DoesNotExist:
            return Response({'detail': 'Patient profile not found.'}, status=status.HTTP_404_NOT_FOUND)

        if request.method == 'PATCH':
            # Temporarily set pk in kwargs so partial_update can resolve the object
            self.kwargs['pk'] = patient.pk
            return self.partial_update(request, pk=patient.pk)

        return Response(PatientSerializer(patient).data)


    @action(detail=False, methods=['post'], url_path='walk-in',
            permission_classes=[IsAuthenticated])
    def walk_in(self, request):
        """Quickly register a walk-in patient with just a name and optional phone.

        POST /api/patients/walk-in/
        Body: { "name": "John Doe", "phone": "0700123456" }
        """
        data = request.data
        full_name = (data.get('name') or '').strip()
        if not full_name:
            return Response(
                {'name': ['Name is required for walk-in patients.']},
                status=status.HTTP_400_BAD_REQUEST,
            )

        parts = full_name.split(None, 1)
        first_name = parts[0]
        last_name = parts[1] if len(parts) > 1 else ''

        # Generate a unique placeholder email so the User model constraint is satisfied.
        email = f'walkin_{uuid.uuid4().hex[:12]}@walkin.adheremed'

        phone = (data.get('phone') or '').strip()

        user = User(
            email=email,
            first_name=first_name,
            last_name=last_name,
            phone=phone,
            role=User.Role.PATIENT,
        )
        user.set_password(secrets.token_urlsafe(16))
        user.save()

        valid_sources = {c[0] for c in Patient.RegistrationSource.choices}
        tenant_type = getattr(getattr(request, 'tenant', None), 'tenant_type', '') or ''
        source = tenant_type if tenant_type in valid_sources else Patient.RegistrationSource.OTHER

        patient = Patient.objects.create(
            user=user,
            patient_number=f'PT-{uuid.uuid4().hex[:8].upper()}',
            registration_source=source,
            date_of_birth='1900-01-01',
            gender='other',
        )
        return Response(PatientSerializer(patient).data, status=status.HTTP_201_CREATED)


def _generate_patient_id_safe():
    """Generate a unique AdhereMed patient ID using the model's logic."""
    from .models import generate_patient_id
    return generate_patient_id()


# ──────────────────────────────────────────────────────────────────────────────
# Demo Data Seeding Endpoint
# ──────────────────────────────────────────────────────────────────────────────

# Sample data pools for realistic demo entries
DEMO_FIRST_NAMES = [
    'James', 'Mary', 'John', 'Patricia', 'Robert', 'Jennifer', 'Michael',
    'Linda', 'David', 'Elizabeth', 'William', 'Barbara', 'Richard', 'Susan',
    'Joseph', 'Sarah', 'Thomas', 'Karen', 'Charles', 'Nancy',
]
DEMO_LAST_NAMES = [
    'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller',
    'Davis', 'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Gonzalez',
    'Wilson', 'Anderson', 'Thomas', 'Taylor', 'Moore', 'Jackson', 'Lee',
]
DEMO_SPECIALTIES = [
    'General Practice', 'Internal Medicine', 'Pediatrics',
    'Cardiology', 'Dermatology',
]
DEMO_REASONS = [
    'Routine checkup', 'Follow-up consultation', 'Fever and cough',
    'Blood pressure monitoring', 'Diabetes management', 'Migraine',
    'Allergic reaction', 'Stomach pain', 'Joint pain', 'Skin rash',
]
DEMO_COMPLAINTS = [
    'Patient presents with occasional headaches and fatigue.',
    'Routine follow-up for hypertension. BP under control with medication.',
    'Complains of persistent cough for 3 days, no fever present.',
    'Blood pressure reading today: 142/92 mmHg. Adjusting medication.',
    'Diabetic patient for quarterly review. Fasting glucose slightly elevated.',
    'Reports severe migraine pain, photophobia for 2 days.',
    'Mild allergic reaction on arms and legs after outdoor activity.',
    'Epigastric pain, worsening after meals for 1 week.',
    'Left knee pain, worse in the morning difficulty climbing stairs.',
    'Pruritic red rash on torso spreading over 5 days.',
]
DEMO_DIAGNOSES = [
    'Primary headache, tension type',
    'Essential hypertension, well controlled',
    'Acute upper respiratory infection',
    'Stage 2 hypertension, adjusting therapy',
    'Type 2 diabetes mellitus',
    'Migraine without aura, acute episode',
    'Contact dermatitis, mild',
    'Gastritis, probabmp',
    'Early osteoarthritis of left knee',
    'Viral exanthem, resolving',
]
DEMO_ALLERGIES = [
    ['Penicillin'], ['Pollen'], ['Latex'], ['Shellfish', 'Iodine'], ['Aspirin'],
    [], ['Dust mites'], [], ['Peanuts'], ['Sulfa drugs'],
]
DEMO_CHRONIC = [
    [], ['Hypertension'], [], ['Diabetes Type 2'], [], ['Migraine'],
    [], [], ['Osteoarthritis'], [],
]
DEMO_MED_NAMES = [
    'Paracetamol', 'Amoxicillin', 'Metformin', 'Amlodipine',
    'Omeprazole', 'Ibuprofen', 'Cetirizine', 'Atorvastatin',
]
DEMO_DOSAGES = ['500mg', '250mg', '850mg', '5mg', '20mg', '400mg', '10mg', '40mg']
DEMO_FREQUENCIES = ['Twice daily', 'Three times daily', 'Once daily', 'Twice daily',
                    'Once daily', 'As needed', 'Once daily', 'Once at bedtime']
DEMO_DURATIONS = ['7 days', '5 days', '30 days', 'Ongoing', '14 days']


def _create_demo_doctors(count, tenant):
    """Create *count* doctor users with DoctorProfiles in the current tenant."""
    from doctors.models import DoctorProfile

    created = []
    for i in range(count):
        first = random.choice(DEMO_FIRST_NAMES)
        last = random.choice(DEMO_LAST_NAMES)
        email = f'demo.doctor{i + 1}@clinic.demo'
        if User.objects.filter(email=email).exists():
            email = f'demo.doctor{i + 1}.{secrets.token_hex(2)}@clinic.demo'

        user = User(
            email=email,
            first_name=first,
            last_name=last,
            role=User.Role.DOCTOR,
            tenant=tenant,
            phone=f'+2547{random.randint(10000000, 99999999)}',
        )
        user.set_password('Demo@12345')
        user.save()

        profile = DoctorProfile.objects.create(
            user=user,
            specialization=DEMO_SPECIALTIES[i % len(DEMO_SPECIALTIES)],
            license_number=f'LIC-DEM-{i + 1:04d}',
            qualification='MBBS, MD',
            years_of_experience=random.randint(3, 25),
            consultation_fee=Decimal(str(random.choice([50, 75, 100, 120, 150]))),
            is_accepting_patients=True,
            is_verified=True,
            available_days=['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
            available_hours={'start': '08:00', 'end': '17:00'},
        )
        created.append({'user': user, 'profile': profile})

    return created


def _create_demo_patients(count, tenant):
    """Create *count* patient users with Patient records in the current tenant schema."""
    created = []
    genders = [Patient.Gender.MALE, Patient.Gender.FEMALE]
    blood_types = ['A+', 'O+', 'B+', 'AB+', 'A-', 'O-', 'B-', 'AB-']

    for i in range(count):
        first = random.choice(DEMO_FIRST_NAMES)
        last = random.choice(DEMO_LAST_NAMES)
        email = f'demo.patient{i + 1}@clinic.demo'
        if User.objects.filter(email=email).exists():
            email = f'demo.patient{i + 1}.{secrets.token_hex(2)}@clinic.demo'

        user = User(
            email=email,
            first_name=first,
            last_name=last,
            role=User.Role.PATIENT,
            tenant=tenant,
            phone=f'+2547{random.randint(10000000, 99999999)}',
        )
        user.set_password('Demo@12345')
        user.save()

        patient_number = f'DEMO-PT-{i + 1:02d}'
        # If one already exists, add a suffix
        if Patient.objects.filter(patient_number=patient_number).exists():
            patient_number = f'DEMO-PT-{i + 1:02d}-{secrets.token_hex(2)}'

        birth_year = random.randint(1950, 2008)
        birth_month = random.randint(1, 12)
        birth_day = random.randint(1, 28)

        patient = Patient.objects.create(
            user=user,
            patient_number=patient_number,
            registration_source=Patient.RegistrationSource.CLINIC,
            date_of_birth=date(birth_year, birth_month, birth_day),
            gender=random.choice(genders),
            blood_type=random.choice(blood_types),
            address=f'{random.randint(1, 999)} Demo Street, Nairobi',
            allergies=DEMO_ALLERGIES[i % len(DEMO_ALLERGIES)],
            chronic_conditions=DEMO_CHRONIC[i % len(DEMO_CHRONIC)],
            emergency_contact_name=f'{random.choice(DEMO_FIRST_NAMES)} {last}',
            emergency_contact_phone=f'+2547{random.randint(10000000, 99999999)}',
            emergency_contact_relation=random.choice(['Spouse', 'Parent', 'Sibling', 'Child']),
            insurance_provider=random.choice(['NHIF', 'Jubilee', 'AAR', 'UAP', 'None']),
            insurance_number=f'INS-{random.randint(100000, 999999)}',
        )
        created.append(patient)

    return created


def _create_demo_appointments(count, patients, doctors):
    """Create *count* appointments linking patients to doctors."""
    from appointments.models import Appointment

    created = []
    today = date.today()
    for i in range(count):
        patient = patients[i % len(patients)]
        doctor_user = doctors[i % len(doctors)]['user']
        appt_date = today + timedelta(days=random.randint(-5, 15))
        appt_time = dtime(random.randint(8, 16), random.choice([0, 15, 30, 45]))

        appt = Appointment.objects.create(
            patient=patient,
            staff=doctor_user,
            appointment_date=appt_date,
            appointment_time=appt_time,
            duration_minutes=random.choice([15, 30, 45, 60]),
            status=random.choice([
                Appointment.Status.SCHEDULED,
                Appointment.Status.CONFIRMED,
                Appointment.Status.COMPLETED,
                Appointment.Status.SCHEDULED,
            ]),
            reason=DEMO_REASONS[i % len(DEMO_REASONS)],
            notes='demo-seeded appointment',
        )
        created.append(appt)

    return created


def _create_demo_consultations(count, patients, doctors):
    """Create *count* consultations linking patients to doctors."""
    from consultations.models import Consultation

    created = []
    for i in range(count):
        patient = patients[i % len(patients)]
        doctor_user = doctors[i % len(doctors)]['user']

        cons = Consultation.objects.create(
            patient=patient,
            doctor=doctor_user,
            status=random.choice([
                Consultation.ConsultationStatus.DRAFT,
                Consultation.ConsultationStatus.SIGNED,
            ]),
            chief_complaint=DEMO_COMPLAINTS[i % len(DEMO_COMPLAINTS)],
            history_present_illness=DEMO_COMPLAINTS[i % len(DEMO_COMPLAINTS)],
            examination_findings='Patient alert and oriented. Vitals within normal limits.',
            assessment=DEMO_DIAGNOSES[i % len(DEMO_DIAGNOSES)],
            diagnosis=[{'code': 'D' + str(i + 1), 'description': DEMO_DIAGNOSES[i % len(DEMO_DIAGNOSES)]}],
            treatment_plan='Continue current management. Follow up in 2 weeks.',
            disposition=random.choice([
                Consultation.Disposition.DISCHARGE,
                Consultation.Disposition.PENDING,
            ]),
            notes='demo-seeded consultation',
        )
        created.append(cons)

    return created


def _create_demo_prescriptions(count, patients, doctors):
    """Create *count* prescriptions with 1-2 items each."""
    from prescriptions.models import Prescription, PrescriptionItem

    created = []
    for i in range(count):
        patient = patients[i % len(patients)]
        doctor_user = doctors[i % len(doctors)]['user']

        rx = Prescription.objects.create(
            patient=patient,
            doctor=doctor_user,
            status=Prescription.Status.ACTIVE,
            notes='demo-seeded prescription',
        )

        # Add 1-2 items
        num_items = random.randint(1, 2)
        for j in range(num_items):
            med_idx = random.randint(0, len(DEMO_MED_NAMES) - 1)
            PrescriptionItem.objects.create(
                prescription=rx,
                medication_name=DEMO_MED_NAMES[med_idx],
                dosage=DEMO_DOSAGES[med_idx],
                frequency=DEMO_FREQUENCIES[med_idx],
                duration=DEMO_DURATIONS[random.randint(0, len(DEMO_DURATIONS) - 1)],
                quantity=random.randint(10, 60),
                instructions='Take with food. Complete the full course.',
                refills=random.randint(0, 2),
            )
        created.append(rx)

    return created


def _create_demo_lab_orders(count, patients, doctors):
    """Create *count* lab orders with tests."""
    from lab.models import LabOrder, LabTestCatalog

    created = []

    # Ensure some lab test catalog entries exist
    catalog = list(LabTestCatalog.objects.all()[:5])
    if len(catalog) < 3:
        seed_tests = [
            ('CBC', 'LAB-CBC', 'Hematology', 'Blood'),
            ('Lipid Panel', 'LAB-LIP', 'Chemistry', 'Blood'),
            ('Glucose Fasting', 'LAB-GLU', 'Chemistry', 'Blood'),
            ('Urinalysis', 'LAB-URN', 'Chemistry', 'Urine'),
            ('Liver Function', 'LAB-LFT', 'Chemistry', 'Blood'),
        ]
        for name, code, dept, specimen in seed_tests:
            LabTestCatalog.objects.get_or_create(
                code=code,
                defaults={'name': name, 'department': dept, 'specimen_type': specimen, 'price': Decimal('500')},
            )
        catalog = list(LabTestCatalog.objects.all()[:5])

    for i in range(count):
        patient = patients[i % len(patients)]
        doctor_user = doctors[i % len(doctors)]['user']

        order = LabOrder.objects.create(
            patient=patient,
            ordered_by=doctor_user,
            status=random.choice([LabOrder.Status.PENDING, LabOrder.Status.SAMPLE_COLLECTED, LabOrder.Status.COMPLETED]),
            priority=random.choice([LabOrder.Priority.ROUTINE, LabOrder.Priority.URGENT, LabOrder.Priority.ROUTINE]),
            clinical_notes='demo-seeded lab order',
            is_home_collection=False,
        )

        # Add 1-2 tests
        num_tests = random.randint(1, 2)
        selected = random.sample(catalog, min(num_tests, len(catalog)))
        order.tests.set(selected)
        created.append(order)

    return created


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def seed_demo_data(request):
    """
    Seed demo data for the current tenant (clinic).
    Creates: 5 doctors, 10 patients, 10 appointments, 10 consultations,
    5 prescriptions, 5 lab orders.
    """
    # Only allow tenant admins or super admins
    if request.user.role not in [User.Role.TENANT_ADMIN, User.Role.SUPER_ADMIN, User.Role.BRANCH_ADMIN]:
        return Response(
            {'error': 'Only tenant administrators can seed demo data.'},
            status=status.HTTP_403_FORBIDDEN,
        )

    tenant = getattr(request, 'tenant', None)
    if not tenant:
        return Response(
            {'error': 'Could not determine current tenant.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    # Check if demo data already exists
    existing_patients = Patient.objects.filter(patient_number__startswith='DEMO').count()
    existing_doctors = User.objects.filter(
        email__icontains='@clinic.demo', role=User.Role.DOCTOR
    ).count()
    if existing_patients > 0 or existing_doctors > 0:
        return Response(
            {
                'error': 'Demo data already exists. Please clear it first using the Clear Demo Data button.',
                'existing': {
                    'patients': existing_patients,
                    'doctors': existing_doctors,
                },
            },
            status=status.HTTP_409_CONFLICT,
        )

    try:
        with transaction.atomic():
            # 1. Create 5 doctors
            doctors = _create_demo_doctors(5, tenant)

            # 2. Create 10 patients
            patients = _create_demo_patients(10, tenant)

            # 3. Create 10 appointments
            appointments = _create_demo_appointments(10, patients, doctors)

            # 4. Create 10 consultations
            consultations = _create_demo_consultations(10, patients, doctors)

            # 5. Create 5 prescriptions
            prescriptions = _create_demo_prescriptions(5, patients, doctors)

            # 6. Create 5 lab orders
            lab_orders = _create_demo_lab_orders(5, patients, doctors)

        return Response({
            'success': True,
            'message': 'Demo data seeded successfully.',
            'summary': {
                'doctors': len(doctors),
                'patients': len(patients),
                'appointments': len(appointments),
                'consultations': len(consultations),
                'prescriptions': len(prescriptions),
                'lab_orders': len(lab_orders),
            },
        }, status=status.HTTP_201_CREATED)

    except Exception as e:
        return Response(
            {'error': f'Failed to seed demo data: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def clear_demo_data(request):
    """
    Remove all demo data (entries with 'demo' in notes/email or 'DEMO' in patient_number).
    """
    if request.user.role not in [User.Role.TENANT_ADMIN, User.Role.SUPER_ADMIN, User.Role.BRANCH_ADMIN]:
        return Response(
            {'error': 'Only tenant administrators can clear demo data.'},
            status=status.HTTP_403_FORBIDDEN,
        )

    try:
        from consultations.models import Consultation
        from prescriptions.models import Prescription
        from lab.models import LabOrder

        # Delete demo lab orders
        deleted_lab = LabOrder.objects.filter(clinical_notes__icontains='demo-seeded').delete()

        # Delete demo prescriptions
        deleted_rx = Prescription.objects.filter(notes__icontains='demo-seeded').delete()

        # Delete demo consultations
        deleted_cons = Consultation.objects.filter(notes__icontains='demo-seeded').delete()

        # Delete demo appointments
        from appointments.models import Appointment
        deleted_appts = Appointment.objects.filter(notes__icontains='demo-seeded').delete()

        # Delete demo patients
        deleted_patients = Patient.objects.filter(
            patient_number__startswith='DEMO'
        ).delete()

        # Delete demo patients (patient_number starts with DEMO)
        deleted_patients = Patient.objects.filter(
            patient_number__startswith='DEMO'
        ).delete()

        # Delete demo doctor users (role=doctor) + their profiles
        demo_doctor_users = User.objects.filter(
            email__icontains='@clinic.demo', role=User.Role.DOCTOR
        )
        deleted_doctor_count = demo_doctor_users.count()
        from doctors.models import DoctorProfile
        DoctorProfile.objects.filter(user__in=demo_doctor_users).delete()
        demo_doctor_users.delete()

        # Delete demo patient users (role=patient) – they are separate from
        # the patient records deleted above.
        User.objects.filter(
            email__icontains='@clinic.demo', role=User.Role.PATIENT
        ).delete()

        return Response({
            'success': True,
            'message': 'Demo data cleared successfully.',
            'summary': {
                'doctors': deleted_doctor_count,
                'patients': deleted_patients[0] if isinstance(deleted_patients, tuple) else 0,
                'appointments': deleted_appts[0] if isinstance(deleted_appts, tuple) else 0,
                'consultations': deleted_cons[0] if isinstance(deleted_cons, tuple) else 0,
                'prescriptions': deleted_rx[0] if isinstance(deleted_rx, tuple) else 0,
                'lab_orders': deleted_lab[0] if isinstance(deleted_lab, tuple) else 0,
            },
        }, status=status.HTTP_200_OK)
    except Exception as e:
        return Response(
            {'error': f'Failed to clear demo data: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )


class CareNoteViewSet(viewsets.ModelViewSet):
    """Clinic care notes — see ``patients.CareNote`` for why this is separate
    from ``homecare.CaregiverNote``."""

    queryset = CareNote.objects.select_related('patient__user').all()
    serializer_class = CareNoteSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['patient', 'category', 'priority', 'is_pinned']
    search_fields = [
        'title', 'content', 'tags',
        'patient__patient_number', 'patient__patient_id',
        'patient__user__first_name', 'patient__user__last_name',
        'author_name',
    ]
    ordering_fields = ['recorded_at', 'created_at', 'priority']
    ordering = ['-is_pinned', '-recorded_at']

    def perform_create(self, serializer):
        user = self.request.user
        display = ''
        role = ''
        if getattr(user, 'is_authenticated', False):
            # The project's User is an AbstractBaseUser (not PermissionsMixin's
            # AbstractUser), so it has NO `get_full_name()` — only a `full_name`
            # property. Calling get_full_name() raises AttributeError.
            display = (user.full_name or '').strip() or user.email
            role = getattr(user, 'role', '') or ''
        serializer.save(
            author=user if getattr(user, 'is_authenticated', False) else None,
            author_name=(serializer.validated_data.get('author_name') or display),
            author_role=role,
        )

    def perform_update(self, serializer):
        # The original author snapshot is never overwritten — editing someone
        # else's note must not rewrite history. Only backfill it if blank.
        extra = {}
        if not serializer.instance.author_name:
            user = self.request.user
            if getattr(user, 'is_authenticated', False):
                extra['author'] = user
                extra['author_name'] = (user.full_name or '').strip() or user.email
                extra['author_role'] = getattr(user, 'role', '') or ''
        serializer.save(**extra)


class VitalObservationViewSet(viewsets.ModelViewSet):
    """Clinic vital signs — the module's own records plus a merged read view.

    ``GET /patients/vitals/`` returns a single de-duplicated clinical timeline
    built from three stores:

    * ``patients.VitalObservation`` — written by this module (``editable: true``)
    * ``triage.Triage.vital_signs`` — captured during triage (read-only)
    * ``consultations.Consultation.vital_signs`` — captured in a consultation
      (read-only)

    Without the merge the page would only ever show what someone happened to
    type into this module, even though the clinic has been recording vitals at
    triage and in consults for months. External rows carry ``editable: false``
    so the UI hides edit/delete on them instead of offering a button that 404s.
    """

    queryset = VitalObservation.objects.select_related('patient__user').all()
    serializer_class = VitalObservationSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['patient']
    search_fields = [
        'patient__patient_number', 'patient__patient_id',
        'patient__user__first_name', 'patient__user__last_name',
        'recorded_by_name',
    ]
    ordering_fields = ['recorded_at', 'news2_score']
    ordering = ['-recorded_at']

    MAX_ROWS = 1000

    # ── helpers ──────────────────────────────────────────────────
    @staticmethod
    def _patient_meta(patient):
        user = getattr(patient, 'user', None)
        return {
            'patient': patient.pk,
            'patient_name': getattr(user, 'full_name', '') or '',
            'patient_number': getattr(patient, 'patient_number', '') or '',
            'patient_display_id': getattr(patient, 'patient_id', '') or '',
        }

    def _own_rows(self):
        rows = []
        for obs in self.get_queryset():
            vs = obs.as_vital_signs()
            rows.append({
                'key': f'vitals-{obs.pk}',
                'id': obs.pk,
                'source': 'vitals',
                'source_label': 'Vitals',
                'editable': True,
                'recorded_at': obs.recorded_at,
                'recorded_by_name': obs.recorded_by_name,
                'recorded_by_role': obs.recorded_by_role,
                'notes': obs.notes,
                'context': '',
                'vital_signs': vs,
                'news2_score': obs.news2_score,
                'news2_breakdown': obs.news2_breakdown or {},
                'bmi': bmi_for(vs.get('weight'), vs.get('height')),
                **self._patient_meta(obs.patient),
            })
        return rows

    def _external_rows(self):
        """Triage + consultation vitals, normalised to the same row shape."""
        from consultations.models import Consultation
        from triage.models import Triage

        rows = []
        # NOTE: do not add .only(...) here — `full_name` is a Python property on
        # accounts.User, not a column, so .only('nurse__full_name') raises
        # FieldDoesNotExist. select_related alone is enough.
        triages = (
            Triage.objects.select_related('patient__user', 'nurse')
            .exclude(vital_signs={})
            .order_by('-triage_time')[: self.MAX_ROWS]
        )
        for t in triages:
            vs = t.vital_signs or {}
            if not any(v not in (None, '', 0) for v in vs.values()):
                continue
            total, breakdown = score_news2(vs)
            rows.append({
                'key': f'triage-{t.pk}',
                'id': t.pk,
                'source': 'triage',
                'source_label': 'Triage',
                'editable': False,
                'recorded_at': t.triage_time,
                'recorded_by_name': getattr(t.nurse, 'full_name', '') or '',
                'recorded_by_role': 'nurse',
                'notes': '',
                'context': t.chief_complaint or '',
                'vital_signs': self._normalise(vs),
                'news2_score': total,
                'news2_breakdown': breakdown,
                'bmi': bmi_for(vs.get('weight'), vs.get('height')),
                **self._patient_meta(t.patient),
            })

        consults = (
            Consultation.objects.select_related('patient__user')
            .exclude(vital_signs={})
            .order_by('-created_at')[: self.MAX_ROWS]
        )
        for c in consults:
            vs = c.vital_signs or {}
            if not any(v not in (None, '', 0) for v in vs.values()):
                continue
            total, breakdown = score_news2(vs)
            rows.append({
                'key': f'consult-{c.pk}',
                'id': c.pk,
                'source': 'consultation',
                'source_label': 'Consultation',
                'editable': False,
                'recorded_at': c.created_at,
                'recorded_by_name': '',
                'recorded_by_role': 'doctor',
                'notes': '',
                'context': c.chief_complaint or '',
                'vital_signs': self._normalise(vs),
                'news2_score': total,
                'news2_breakdown': breakdown,
                'bmi': bmi_for(vs.get('weight'), vs.get('height')),
                **self._patient_meta(c.patient),
            })
        return rows

    @staticmethod
    def _normalise(vs):
        """Fold the legacy aliases used by triage/consultation JSON into the
        canonical keys so every row renders identically."""
        def pick(*keys):
            for k in keys:
                v = vs.get(k)
                if v not in (None, ''):
                    return v
            return None

        return {
            'temperature': pick('temperature', 'temp'),
            'bp_systolic': pick('bp_systolic', 'systolic', 'blood_pressure_systolic'),
            'bp_diastolic': pick('bp_diastolic', 'diastolic', 'blood_pressure_diastolic'),
            'heart_rate': pick('heart_rate', 'pulse'),
            'respiratory_rate': pick('respiratory_rate', 'resp_rate', 'resp'),
            'oxygen_saturation': pick('oxygen_saturation', 'spo2', 'o2_saturation'),
            'blood_sugar': pick('blood_sugar', 'glucose'),
            'weight': pick('weight'),
            'height': pick('height'),
            'pain_score': pick('pain_score', 'pain'),
            'spo2_scale': vs.get('spo2_scale') or 1,
            'on_oxygen': bool(vs.get('on_oxygen')),
            'consciousness': vs.get('consciousness') or vs.get('avpu') or 'A',
        }

    # ── endpoints ────────────────────────────────────────────────
    def list(self, request, *args, **kwargs):
        rows = self._own_rows() + self._external_rows()

        # Manual filters — the merged list is not a queryset.
        patient_id = request.query_params.get('patient')
        if patient_id:
            try:
                pid = int(patient_id)
                rows = [r for r in rows if r['patient'] == pid]
            except (TypeError, ValueError):
                pass

        source = request.query_params.get('source')
        if source:
            rows = [r for r in rows if r['source'] == source]

        risk = request.query_params.get('risk')
        if risk:
            rows = [r for r in rows if news2_risk(r['news2_score'], r['news2_breakdown']) == risk]

        q = (request.query_params.get('search') or '').strip().lower()
        if q:
            rows = [
                r for r in rows
                if q in ' '.join(filter(None, [
                    r['patient_name'], r['patient_number'], r['patient_display_id'],
                    r['recorded_by_name'], r['context'], str(r.get('notes') or ''),
                ])).lower()
            ]

        for r in rows:
            r['risk'] = news2_risk(r['news2_score'], r['news2_breakdown'])
            r['critical_params'] = [
                k for k, v in (r['news2_breakdown'] or {}).items() if int(v or 0) >= 3
            ]

        rows.sort(key=lambda r: r['recorded_at'], reverse=True)
        rows = rows[: self.MAX_ROWS]

        # Per-patient roll-up: latest reading + NEWS2 series for the sparkline.
        by_patient = {}
        for r in sorted(rows, key=lambda x: x['recorded_at']):
            p = by_patient.setdefault(r['patient'], {
                'patient': r['patient'],
                'patient_name': r['patient_name'],
                'patient_number': r['patient_number'],
                'patient_display_id': r['patient_display_id'],
                'count': 0,
                'series': [],
                'latest': None,
            })
            p['count'] += 1
            p['series'].append(r['news2_score'])
            p['latest'] = {
                'recorded_at': r['recorded_at'],
                'news2_score': r['news2_score'],
                'risk': r['risk'],
                'vital_signs': r['vital_signs'],
                'source': r['source'],
            }

        patient_rows = []
        for p in by_patient.values():
            latest = p['latest'] or {}
            vs = latest.get('vital_signs') or {}
            patient_rows.append({
                **{k: p[k] for k in ('patient', 'patient_name', 'patient_number',
                                     'patient_display_id', 'count')},
                'latest_at': latest.get('recorded_at'),
                'latest_news2': latest.get('news2_score', 0),
                'risk': latest.get('risk', 'low'),
                'source': latest.get('source', ''),
                'vital_signs': vs,
                'bmi': bmi_for(vs.get('weight'), vs.get('height')),
                'series': p['series'][-12:],
            })
        patient_rows.sort(key=lambda p: (-p['latest_news2'], p['patient_name']))

        now = timezone.now()
        day_ago = now - timedelta(hours=24)
        summary = {
            'total': len(rows),
            'patients': len(patient_rows),
            'critical': sum(1 for r in rows if r['risk'] == 'high'),
            'review': sum(1 for r in rows if r['risk'] in ('high', 'medium')),
            'last_24h': sum(1 for r in rows if r['recorded_at'] >= day_ago),
            'avg_news2': round(sum(r['news2_score'] for r in rows) / len(rows), 1) if rows else 0,
        }

        for r in rows:
            r['recorded_at'] = r['recorded_at'].isoformat()
        for p in patient_rows:
            if p['latest_at'] is not None:
                p['latest_at'] = p['latest_at'].isoformat()

        return Response({
            'count': len(rows),
            'summary': summary,
            'patients': patient_rows,
            'results': rows,
        })

    def perform_create(self, serializer):
        user = self.request.user
        display = ''
        role = ''
        if getattr(user, 'is_authenticated', False):
            display = (user.full_name or '').strip() or user.email
            role = getattr(user, 'role', '') or ''
        serializer.save(
            recorded_by=user if getattr(user, 'is_authenticated', False) else None,
            recorded_by_name=display,
            recorded_by_role=role,
        )


class PatientRegistrationView(CreateAPIView):
    serializer_class = PatientRegistrationSerializer
