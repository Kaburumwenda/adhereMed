from rest_framework import serializers
from django.contrib.auth import authenticate
from .models import User


class UserSerializer(serializers.ModelSerializer):
    tenant_name = serializers.CharField(source='tenant.name', read_only=True, default=None)
    tenant_type = serializers.CharField(source='tenant.type', read_only=True, default=None)
    tenant_schema = serializers.CharField(source='tenant.schema_name', read_only=True, default=None)

    class Meta:
        model = User
        fields = [
            'id', 'email', 'phone', 'first_name', 'last_name',
            'role', 'tenant', 'tenant_name', 'tenant_type', 'tenant_schema',
            'is_active', 'date_joined',
        ]
        read_only_fields = ['date_joined']


class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(min_length=8, write_only=True)

    class Meta:
        model = User
        fields = [
            'email', 'phone', 'first_name', 'last_name',
            'role', 'password',
        ]

    def create(self, validated_data):
        user = User.objects.create_user(**validated_data)
        if user.role == User.Role.PATIENT:
            import uuid
            from patients.models import Patient
            Patient.objects.get_or_create(
                user=user,
                defaults={
                    'patient_number': f'PT-{uuid.uuid4().hex[:8].upper()}',
                    'date_of_birth': '1900-01-01',
                    'gender': 'other',
                },
            )
        return user


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)

    def validate(self, data):
        user = authenticate(email=data['email'], password=data['password'])
        if not user:
            raise serializers.ValidationError('Invalid email or password.')
        if not user.is_active:
            raise serializers.ValidationError('Account is disabled.')
        data['user'] = user
        return data


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(min_length=8, write_only=True)

    def validate_old_password(self, value):
        if not self.context['request'].user.check_password(value):
            raise serializers.ValidationError('Current password is incorrect.')
        return value


class PasswordResetRequestSerializer(serializers.Serializer):
    email = serializers.EmailField()


class PasswordResetConfirmSerializer(serializers.Serializer):
    uid = serializers.CharField()
    token = serializers.CharField()
    new_password = serializers.CharField(min_length=8, write_only=True)
