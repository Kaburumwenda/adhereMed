from django.db import transaction
from rest_framework import serializers

from accounts.models import User
from .models import StaffProfile, Specialization

PHARMACY_ROLES = ['pharmacist', 'pharmacy_tech', 'cashier']


class SpecializationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Specialization
        fields = ['id', 'name', 'description', 'is_active', 'created_at']
        read_only_fields = ['id', 'created_at']


class StaffProfileSerializer(serializers.ModelSerializer):
    user_email = serializers.CharField(source='user.email', read_only=True)
    user_name = serializers.CharField(source='user.full_name', read_only=True)
    user_role = serializers.CharField(source='user.role', read_only=True)
    user_phone = serializers.CharField(source='user.phone', read_only=True)
    department_name = serializers.CharField(
        source='department.name', read_only=True, default=None,
    )
    specialization_name = serializers.CharField(
        source='specialization.name', read_only=True, default=None,
    )
    branch_name = serializers.CharField(
        source='branch.name', read_only=True, default=None,
    )

    class Meta:
        model = StaffProfile
        fields = [
            'id', 'user', 'user_email', 'user_name', 'user_role', 'user_phone',
            'department', 'department_name',
            'specialization', 'specialization_name',
            'branch', 'branch_name',
            'license_number', 'qualification',
            'years_of_experience', 'bio', 'schedule',
            'is_available', 'created_at',
        ]
        read_only_fields = ['id', 'created_at']


class StaffCreateSerializer(serializers.Serializer):
    """Creates a User + StaffProfile in one request."""
    email = serializers.EmailField()
    first_name = serializers.CharField(max_length=150)
    last_name = serializers.CharField(max_length=150)
    phone = serializers.CharField(max_length=20, required=False, default='')
    role = serializers.ChoiceField(choices=[(r, r) for r in PHARMACY_ROLES])
    password = serializers.CharField(min_length=8, write_only=True)

    specialization = serializers.PrimaryKeyRelatedField(
        queryset=Specialization.objects.all(), required=False, allow_null=True, default=None,
    )
    license_number = serializers.CharField(max_length=100, required=False, default='')
    qualification = serializers.CharField(max_length=255, required=False, default='')
    years_of_experience = serializers.IntegerField(required=False, default=0)
    is_available = serializers.BooleanField(required=False, default=True)
    branch_id = serializers.IntegerField(required=False, allow_null=True)

    def validate_email(self, value):
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError('A user with this email already exists.')
        return value

    @transaction.atomic
    def create(self, validated_data):
        request = self.context['request']
        user_data = {
            'email': validated_data['email'],
            'first_name': validated_data['first_name'],
            'last_name': validated_data['last_name'],
            'phone': validated_data.get('phone', ''),
            'role': validated_data['role'],
            'tenant': request.user.tenant,
        }
        user = User.objects.create_user(
            password=validated_data['password'], **user_data,
        )
        profile = StaffProfile.objects.create(
            user=user,
            specialization=validated_data.get('specialization'),
            license_number=validated_data.get('license_number', ''),
            qualification=validated_data.get('qualification', ''),
            years_of_experience=validated_data.get('years_of_experience', 0),
            is_available=validated_data.get('is_available', True),
            branch_id=validated_data.get('branch_id'),
        )
        return profile


class StaffUpdateSerializer(serializers.Serializer):
    """Updates User fields + StaffProfile fields."""
    first_name = serializers.CharField(max_length=150, required=False)
    last_name = serializers.CharField(max_length=150, required=False)
    phone = serializers.CharField(max_length=20, required=False)
    role = serializers.ChoiceField(
        choices=[(r, r) for r in PHARMACY_ROLES], required=False,
    )

    specialization = serializers.PrimaryKeyRelatedField(
        queryset=Specialization.objects.all(), required=False, allow_null=True,
    )
    license_number = serializers.CharField(max_length=255, required=False)
    qualification = serializers.CharField(max_length=255, required=False)
    years_of_experience = serializers.IntegerField(required=False)
    is_available = serializers.BooleanField(required=False)
    branch_id = serializers.IntegerField(required=False, allow_null=True)

    @transaction.atomic
    def update(self, instance, validated_data):
        user = instance.user
        user_fields = ['first_name', 'last_name', 'phone', 'role']
        user_changed = False
        for field in user_fields:
            if field in validated_data:
                setattr(user, field, validated_data[field])
                user_changed = True
        if user_changed:
            user.save()

        profile_fields = [
            'specialization', 'license_number', 'qualification',
            'years_of_experience', 'is_available', 'branch_id',
        ]
        for field in profile_fields:
            if field in validated_data:
                setattr(instance, field, validated_data[field])
        instance.save()
        return instance
