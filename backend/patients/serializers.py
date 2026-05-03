from django.contrib.auth import get_user_model
from rest_framework import serializers

from .models import Patient

User = get_user_model()


class _NestedUserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'email', 'first_name', 'last_name', 'phone']


class PatientSerializer(serializers.ModelSerializer):
    user = _NestedUserSerializer(read_only=True)
    user_email = serializers.CharField(source='user.email', read_only=True)
    user_name = serializers.CharField(source='user.full_name', read_only=True)

    class Meta:
        model = Patient
        fields = [
            'id', 'user', 'user_email', 'user_name',
            'patient_number', 'date_of_birth', 'gender', 'blood_type',
            'national_id', 'address', 'allergies', 'chronic_conditions',
            'emergency_contact_name', 'emergency_contact_phone',
            'emergency_contact_relation',
            'insurance_provider', 'insurance_number',
            'notes', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'patient_number', 'created_at', 'updated_at']


class PatientRegistrationSerializer(serializers.Serializer):
    # User fields
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, min_length=8)
    first_name = serializers.CharField(max_length=150)
    last_name = serializers.CharField(max_length=150)
    phone = serializers.CharField(max_length=20, required=False, default='')

    # Patient fields
    date_of_birth = serializers.DateField()
    gender = serializers.ChoiceField(choices=Patient.Gender.choices)
    blood_type = serializers.ChoiceField(choices=Patient.BloodType.choices, required=False, default='')
    national_id = serializers.CharField(max_length=30, required=False, default='')
    address = serializers.CharField(required=False, default='')
    allergies = serializers.ListField(child=serializers.CharField(), required=False, default=list)
    chronic_conditions = serializers.ListField(child=serializers.CharField(), required=False, default=list)
    emergency_contact_name = serializers.CharField(max_length=255, required=False, default='')
    emergency_contact_phone = serializers.CharField(max_length=20, required=False, default='')
    emergency_contact_relation = serializers.CharField(max_length=50, required=False, default='')
    insurance_provider = serializers.CharField(max_length=255, required=False, default='')
    insurance_number = serializers.CharField(max_length=100, required=False, default='')

    def validate_email(self, value):
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError('A user with this email already exists.')
        return value

    def create(self, validated_data):
        user_data = {
            'email': validated_data['email'],
            'password': validated_data['password'],
            'first_name': validated_data['first_name'],
            'last_name': validated_data['last_name'],
            'phone': validated_data.get('phone', ''),
            'role': User.Role.PATIENT,
        }
        password = user_data.pop('password')
        user = User(**user_data)
        user.set_password(password)
        user.save()

        import uuid
        patient_number = f'PT-{uuid.uuid4().hex[:8].upper()}'

        patient = Patient.objects.create(
            user=user,
            patient_number=patient_number,
            date_of_birth=validated_data['date_of_birth'],
            gender=validated_data['gender'],
            blood_type=validated_data.get('blood_type', ''),
            national_id=validated_data.get('national_id', ''),
            address=validated_data.get('address', ''),
            allergies=validated_data.get('allergies', []),
            chronic_conditions=validated_data.get('chronic_conditions', []),
            emergency_contact_name=validated_data.get('emergency_contact_name', ''),
            emergency_contact_phone=validated_data.get('emergency_contact_phone', ''),
            emergency_contact_relation=validated_data.get('emergency_contact_relation', ''),
            insurance_provider=validated_data.get('insurance_provider', ''),
            insurance_number=validated_data.get('insurance_number', ''),
        )
        return patient
