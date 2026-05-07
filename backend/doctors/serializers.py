from django.db import transaction
from rest_framework import serializers

from accounts.models import User
from tenants.models import Tenant
from .models import DoctorProfile


class DoctorProfileSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.full_name', read_only=True)
    user_email = serializers.CharField(source='user.email', read_only=True)
    user_phone = serializers.CharField(source='user.phone', read_only=True)
    hospital_name = serializers.CharField(
        source='hospital.name', read_only=True, default=None,
    )
    profile_picture_url = serializers.SerializerMethodField()
    signature_url = serializers.SerializerMethodField()

    class Meta:
        model = DoctorProfile
        fields = [
            'id', 'user', 'user_name', 'user_email', 'user_phone',
            'practice_type', 'hospital', 'hospital_name',
            'specialization', 'license_number', 'qualification',
            'years_of_experience', 'bio', 'consultation_fee',
            'is_accepting_patients', 'is_verified',
            'languages', 'available_days', 'available_hours',
            'profile_picture', 'profile_picture_url',
            'signature', 'signature_url',
            'created_at', 'updated_at',
        ]
        read_only_fields = [
            'id', 'user', 'is_verified',
            'profile_picture_url', 'signature_url',
            'created_at', 'updated_at',
        ]

    def get_profile_picture_url(self, obj):
        if not obj.profile_picture:
            return None
        request = self.context.get('request')
        if request:
            return request.build_absolute_uri(obj.profile_picture.url)
        return obj.profile_picture.url

    def get_signature_url(self, obj):
        if not obj.signature:
            return None
        request = self.context.get('request')
        if request:
            return request.build_absolute_uri(obj.signature.url)
        return obj.signature.url


class DoctorRegistrationSerializer(serializers.Serializer):
    """Creates a User (role=doctor) + DoctorProfile in one request."""
    # User fields
    email = serializers.EmailField()
    password = serializers.CharField(min_length=8, write_only=True)
    first_name = serializers.CharField(max_length=150)
    last_name = serializers.CharField(max_length=150)
    phone = serializers.CharField(max_length=20, required=False, default='')

    # Profile fields
    practice_type = serializers.ChoiceField(
        choices=DoctorProfile.PracticeType.choices,
        default=DoctorProfile.PracticeType.INDEPENDENT,
    )
    hospital = serializers.PrimaryKeyRelatedField(
        queryset=Tenant.objects.filter(type='hospital'),
        required=False, allow_null=True, default=None,
    )
    specialization = serializers.CharField(max_length=255)
    license_number = serializers.CharField(max_length=100)
    qualification = serializers.CharField(max_length=255, required=False, default='')
    years_of_experience = serializers.IntegerField(required=False, default=0)
    bio = serializers.CharField(required=False, default='')
    consultation_fee = serializers.DecimalField(
        max_digits=10, decimal_places=2, required=False, default=0,
    )
    languages = serializers.ListField(
        child=serializers.CharField(), required=False, default=list,
    )

    def validate_email(self, value):
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError('A user with this email already exists.')
        return value

    def validate(self, data):
        if data.get('practice_type') == 'hospital' and not data.get('hospital'):
            raise serializers.ValidationError(
                {'hospital': 'Hospital is required for hospital-affiliated doctors.'}
            )
        return data

    @transaction.atomic
    def create(self, validated_data):
        user = User.objects.create_user(
            email=validated_data['email'],
            password=validated_data['password'],
            first_name=validated_data['first_name'],
            last_name=validated_data['last_name'],
            phone=validated_data.get('phone', ''),
            role=User.Role.DOCTOR,
            tenant=validated_data.get('hospital'),
        )
        profile = DoctorProfile.objects.create(
            user=user,
            practice_type=validated_data.get('practice_type', 'independent'),
            hospital=validated_data.get('hospital'),
            specialization=validated_data['specialization'],
            license_number=validated_data['license_number'],
            qualification=validated_data.get('qualification', ''),
            years_of_experience=validated_data.get('years_of_experience', 0),
            bio=validated_data.get('bio', ''),
            consultation_fee=validated_data.get('consultation_fee', 0),
            languages=validated_data.get('languages', []),
        )
        return profile


class DoctorDirectorySerializer(serializers.ModelSerializer):
    """Lightweight serializer for the public doctor directory."""
    name = serializers.CharField(source='user.full_name', read_only=True)
    email = serializers.CharField(source='user.email', read_only=True)
    phone = serializers.CharField(source='user.phone', read_only=True)
    hospital_name = serializers.CharField(
        source='hospital.name', read_only=True, default=None,
    )
    profile_picture_url = serializers.SerializerMethodField()

    class Meta:
        model = DoctorProfile
        fields = [
            'id', 'user', 'name', 'email', 'phone',
            'practice_type', 'hospital_name',
            'specialization', 'qualification',
            'years_of_experience', 'bio', 'consultation_fee',
            'is_accepting_patients', 'is_verified',
            'languages', 'available_days', 'available_hours',
            'profile_picture_url',
        ]

    def get_profile_picture_url(self, obj):
        if not obj.profile_picture:
            return None
        request = self.context.get('request')
        if request:
            return request.build_absolute_uri(obj.profile_picture.url)
        return obj.profile_picture.url
