import uuid
import secrets
import random
from datetime import date, timedelta, time as dtime
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.db import transaction
from rest_framework import viewsets, filters, status
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.generics import CreateAPIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django_filters.rest_framework import DjangoFilterBackend

from .models import Patient
from .serializers import PatientSerializer, PatientRegistrationSerializer

User = get_user_model()


def _to_list(val):
    """Accept a string or list for allergies / chronic_conditions."""
    if not val:
        return []
    if isinstance(val, list):
        return val
    return [v.strip() for v in str(val).split(',') if v.strip()]


class PatientViewSet(viewsets.ModelViewSet):
    queryset = Patient.objects.select_related('user').all()
    serializer_class = PatientSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['gender', 'blood_type']
    search_fields = ['patient_number', 'user__first_name', 'user__last_name', 'national_id']
    ordering_fields = ['created_at', 'patient_number']

    def create(self, request, *args, **kwargs):
        data = request.data
        email = data.get('email', '').strip()
        if not email:
            return Response({'email': ['Email is required.']}, status=status.HTTP_400_BAD_REQUEST)
        if User.objects.filter(email=email).exists():
            return Response({'email': ['A user with this email already exists.']}, status=status.HTTP_400_BAD_REQUEST)

        password = data.get('password') or secrets.token_urlsafe(12)
        user = User(
            email=email,
            first_name=data.get('first_name', ''),
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

        patient = Patient.objects.create(
            user=user,
            patient_number=f'PT-{uuid.uuid4().hex[:8].upper()}',
            registration_source=source,
            date_of_birth=data.get('date_of_birth') or '1900-01-01',
            gender=data.get('gender') or 'other',
            blood_type=data.get('blood_type') or data.get('blood_group', ''),
            national_id=data.get('national_id') or data.get('id_number', ''),
            address=data.get('address', ''),
            allergies=_to_list(data.get('allergies', [])),
            chronic_conditions=_to_list(data.get('chronic_conditions', [])),
            emergency_contact_name=data.get('emergency_contact_name', ''),
            emergency_contact_phone=data.get('emergency_contact_phone', ''),
            emergency_contact_relation=data.get('emergency_contact_relation', ''),
            insurance_provider=data.get('insurance_provider', ''),
            insurance_number=data.get('insurance_number') or data.get('insurance_policy_number', ''),
        )
        return Response(PatientSerializer(patient).data, status=status.HTTP_201_CREATED)

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
            patient.national_id = data['national_id']
        elif 'id_number' in data:
            patient.national_id = data['id_number']
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


class PatientRegistrationView(CreateAPIView):
    serializer_class = PatientRegistrationSerializer
