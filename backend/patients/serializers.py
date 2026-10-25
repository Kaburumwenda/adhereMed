from django.contrib.auth import get_user_model
from django.db import transaction
from rest_framework import serializers

from clinic_sites.models import ClinicSite
from .models import CareNote, Patient, VitalObservation

User = get_user_model()


class _NestedUserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'email', 'first_name', 'middle_name', 'last_name', 'phone']


class PatientSerializer(serializers.ModelSerializer):
    user = _NestedUserSerializer(read_only=True)
    user_email = serializers.CharField(source='user.email', read_only=True)
    user_name = serializers.CharField(source='user.full_name', read_only=True)
    clinic_site_name = serializers.CharField(source='clinic_site.name', read_only=True, default=None)
    age = serializers.IntegerField(source='age_years', read_only=True)
    is_paediatric = serializers.BooleanField(read_only=True)

    class Meta:
        model = Patient
        fields = [
            'id', 'user', 'user_email', 'user_name',
            'patient_id', 'patient_number', 'registration_source',
            'patient_category', 'is_paediatric', 'age',
            'guardian_name', 'guardian_phone', 'guardian_relationship',
            'immunisation_status',
            'clinic_site', 'clinic_site_name',
            'date_of_birth', 'gender', 'blood_type',
            'national_id', 'address', 'latitude', 'longitude', 'address_place_id',
            'allergies', 'chronic_conditions',
            'emergency_contact_name', 'emergency_contact_phone',
            'emergency_contact_relation',
            'insurance_provider', 'insurance_number',
            'notes', 'has_portal_access', 'shared_fields',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'patient_id', 'patient_number', 'created_at', 'updated_at']


class PatientRegistrationSerializer(serializers.Serializer):
    # User fields
    email = serializers.EmailField(required=False, allow_blank=True, default='')
    middle_name = serializers.CharField(max_length=150, required=False, allow_blank=True, default='')
    password = serializers.CharField(write_only=True, min_length=8)
    first_name = serializers.CharField(max_length=150)
    last_name = serializers.CharField(max_length=150)
    phone = serializers.CharField(max_length=20, required=False, default='')

    # Patient fields
    date_of_birth = serializers.DateField()
    gender = serializers.ChoiceField(choices=Patient.Gender.choices)
    patient_category = serializers.ChoiceField(
        choices=Patient.Category.choices, required=False,
        default=Patient.Category.GENERAL,
    )
    guardian_name = serializers.CharField(max_length=255, required=False, default='')
    guardian_phone = serializers.CharField(max_length=20, required=False, default='')
    guardian_relationship = serializers.CharField(max_length=50, required=False, default='')
    immunisation_status = serializers.ChoiceField(
        choices=Patient.ImmunisationStatus.choices, required=False, default='',
    )
    blood_type = serializers.ChoiceField(choices=Patient.BloodType.choices, required=False, default='')
    national_id = serializers.CharField(
        max_length=30, required=False, allow_null=True, allow_blank=True,
        help_text='Optional. Blank values are stored as NULL so many patients '
                  'without an ID can coexist under the unique constraint.',
    )
    address = serializers.CharField(required=False, default='')
    latitude = serializers.DecimalField(
        max_digits=9, decimal_places=6, required=False, allow_null=True,
    )
    longitude = serializers.DecimalField(
        max_digits=9, decimal_places=6, required=False, allow_null=True,
    )
    address_place_id = serializers.CharField(required=False, allow_blank=True, default='')
    allergies = serializers.ListField(child=serializers.CharField(), required=False, default=list)
    chronic_conditions = serializers.ListField(child=serializers.CharField(), required=False, default=list)
    emergency_contact_name = serializers.CharField(max_length=255, required=False, default='')
    emergency_contact_phone = serializers.CharField(max_length=20, required=False, default='')
    emergency_contact_relation = serializers.CharField(max_length=50, required=False, default='')
    insurance_provider = serializers.CharField(max_length=255, required=False, default='')
    insurance_number = serializers.CharField(max_length=100, required=False, default='')
    clinic_site = serializers.PrimaryKeyRelatedField(
        queryset=ClinicSite.objects.all(), required=False, allow_null=True,
    )

    def validate_email(self, value):
        value = (value or '').strip()
        if not value:
            return ''
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError('A user with this email already exists.')
        return value

    def validate_national_id(self, value):
        # Blank / missing ID is stored as NULL — many patients legitimately have
        # none, and an empty string would collide on the unique constraint.
        value = (value or '').strip()
        if not value:
            return None
        if Patient.objects.filter(national_id=value).exists():
            raise serializers.ValidationError('A patient with this National ID already exists.')
        return value

    @transaction.atomic
    def create(self, validated_data):
        import uuid

        patient_number = f'PT-{uuid.uuid4().hex[:8].upper()}'

        # Email is only mandatory for portal accounts. Walk-in / clinic-only
        # records get a non-deliverable placeholder so the unique email column
        # stays satisfied without inventing a real inbox.
        email = (validated_data.get('email') or '').strip()
        if not email:
            email = f'{patient_number.lower()}@no-email.adheremed.local'

        user_data = {
            'email': email,
            'password': validated_data['password'],
            'first_name': validated_data['first_name'],
            'middle_name': validated_data.get('middle_name', ''),
            'last_name': validated_data['last_name'],
            'phone': validated_data.get('phone', ''),
            'role': User.Role.PATIENT,
        }
        password = user_data.pop('password')
        user = User(**user_data)
        user.set_password(password)
        user.save()

        patient = Patient.objects.create(
            user=user,
            patient_number=patient_number,
            clinic_site=validated_data.get('clinic_site'),
            date_of_birth=validated_data['date_of_birth'],
            gender=validated_data['gender'],
            patient_category=validated_data.get('patient_category') or Patient.Category.GENERAL,
            guardian_name=validated_data.get('guardian_name', ''),
            guardian_phone=validated_data.get('guardian_phone', ''),
            guardian_relationship=validated_data.get('guardian_relationship', ''),
            immunisation_status=validated_data.get('immunisation_status', ''),
            blood_type=validated_data.get('blood_type', ''),
            national_id=validated_data.get('national_id') or None,
            address=validated_data.get('address', ''),
            latitude=validated_data.get('latitude'),
            longitude=validated_data.get('longitude'),
            address_place_id=validated_data.get('address_place_id', '') or '',
            allergies=validated_data.get('allergies', []),
            chronic_conditions=validated_data.get('chronic_conditions', []),
            emergency_contact_name=validated_data.get('emergency_contact_name', ''),
            emergency_contact_phone=validated_data.get('emergency_contact_phone', ''),
            emergency_contact_relation=validated_data.get('emergency_contact_relation', ''),
            insurance_provider=validated_data.get('insurance_provider', ''),
            insurance_number=validated_data.get('insurance_number', ''),
        )
        try:
            from superadmin.mailer import send_patient_welcome_email
            send_patient_welcome_email(user, patient)
        except Exception:
            pass
        return patient


class CareNoteSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    patient_number = serializers.CharField(source='patient.patient_number', read_only=True)
    patient_display_id = serializers.CharField(source='patient.patient_id', read_only=True)
    category_label = serializers.CharField(source='get_category_display', read_only=True)
    priority_label = serializers.CharField(source='get_priority_display', read_only=True)
    author_name = serializers.CharField(required=False, allow_blank=True)
    content = serializers.CharField(allow_blank=False)

    class Meta:
        model = CareNote
        fields = [
            'id', 'patient', 'patient_name', 'patient_number', 'patient_display_id',
            'author', 'author_name', 'author_role',
            'category', 'category_label', 'priority', 'priority_label',
            'title', 'content', 'vitals', 'tags',
            'follow_up_at', 'is_pinned', 'recorded_at',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'author', 'author_role', 'created_at', 'updated_at']

    def validate_content(self, value):
        value = (value or '').strip()
        if not value:
            raise serializers.ValidationError('A care note cannot be empty.')
        return value


# ── Vitals ───────────────────────────────────────────────────────────────────
# Physiological hard bounds. Mirrors VITAL_BOUNDS on the triage workspace so a
# fat-fingered 111 % SpO2 or a 120/100 BP cannot be persisted from this module.
VITAL_BOUNDS = {
    'temperature': (30, 45),
    'bp_systolic': (40, 300),
    'bp_diastolic': (20, 200),
    'heart_rate': (20, 300),
    'respiratory_rate': (4, 80),
    'oxygen_saturation': (50, 100),
    'blood_sugar': (0.5, 50),
    'weight': (0.5, 500),
    'height': (20, 250),
    'pain_score': (0, 10),
}


class VitalObservationSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    patient_number = serializers.CharField(source='patient.patient_number', read_only=True)
    patient_display_id = serializers.CharField(source='patient.patient_id', read_only=True)

    class Meta:
        model = VitalObservation
        fields = [
            'id', 'patient', 'patient_name', 'patient_number', 'patient_display_id',
            'recorded_at', 'recorded_by_name', 'recorded_by_role',
            'temperature', 'bp_systolic', 'bp_diastolic', 'heart_rate',
            'respiratory_rate', 'oxygen_saturation', 'blood_sugar',
            'weight', 'height', 'pain_score',
            'spo2_scale', 'on_oxygen', 'consciousness',
            'news2_score', 'news2_breakdown', 'notes',
            'created_at', 'updated_at',
        ]
        read_only_fields = [
            'id', 'recorded_by_name', 'recorded_by_role',
            'news2_score', 'news2_breakdown', 'created_at', 'updated_at',
        ]

    def validate(self, attrs):
        instance = self.instance
        for field, (low, high) in VITAL_BOUNDS.items():
            if field not in attrs and instance is None:
                continue
            value = attrs.get(field, getattr(instance, field, None) if instance else None)
            if value is None:
                continue
            try:
                num = float(value)
            except (TypeError, ValueError):
                raise serializers.ValidationError({field: 'Enter a number.'})
            if not (low <= num <= high):
                raise serializers.ValidationError(
                    {field: f'Must be between {low} and {high}.'}
                )

        sys_v = attrs.get('bp_systolic', getattr(instance, 'bp_systolic', None) if instance else None)
        dia_v = attrs.get('bp_diastolic', getattr(instance, 'bp_diastolic', None) if instance else None)
        if sys_v and dia_v and float(dia_v) >= float(sys_v):
            raise serializers.ValidationError(
                {'bp_diastolic': 'Diastolic must be lower than systolic.'}
            )
        return attrs
