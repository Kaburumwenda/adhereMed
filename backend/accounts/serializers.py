from rest_framework import serializers
from django.contrib.auth import authenticate
from .models import User


class UserSerializer(serializers.ModelSerializer):
    tenant_name = serializers.CharField(source='tenant.name', read_only=True, default=None)
    tenant_type = serializers.CharField(source='tenant.type', read_only=True, default=None)
    tenant_schema = serializers.CharField(source='tenant.schema_name', read_only=True, default=None)
    branch_id = serializers.SerializerMethodField()
    branch_name = serializers.SerializerMethodField()
    is_tenant_admin = serializers.SerializerMethodField()
    billing = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id', 'email', 'phone', 'first_name', 'last_name',
            'role', 'tenant', 'tenant_name', 'tenant_type', 'tenant_schema',
            'is_active', 'date_joined', 'pin',
            'branch_id', 'branch_name', 'is_tenant_admin', 'billing',
        ]
        read_only_fields = ['date_joined', 'pin']

    def get_branch_id(self, obj):
        try:
            return obj.staff_profile.branch_id
        except Exception:
            return None

    def get_branch_name(self, obj):
        try:
            branch = obj.staff_profile.branch
            return branch.name if branch else None
        except Exception:
            return None

    def get_is_tenant_admin(self, obj):
        return obj.role in {'tenant_admin', 'homecare_admin', 'admin'}

    def get_billing(self, obj):
        """Lightweight overdue-lock summary so the frontend can gate access."""
        default = {'locked': False, 'has_overdue': False, 'overdue_count': 0,
                   'total_overdue': '0'}
        tenant = getattr(obj, 'tenant', None)
        if tenant is None or getattr(tenant, 'schema_name', 'public') == 'public':
            return default
        try:
            from usage_billing.views import compute_billing_lock
            lock = compute_billing_lock(tenant)
            return {
                'locked': lock['locked'],
                'has_overdue': lock['has_overdue'],
                'overdue_count': lock['overdue_count'],
                'total_overdue': lock['total_overdue'],
                'reason': lock['reason'],
                'grace_until': lock['grace_until'],
            }
        except Exception:
            return default


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
            patient, _ = Patient.objects.get_or_create(
                user=user,
                defaults={
                    'patient_number': f'PT-{uuid.uuid4().hex[:8].upper()}',
                    'date_of_birth': '1900-01-01',
                    'gender': 'other',
                },
            )
            try:
                from superadmin.mailer import send_patient_welcome_email
                send_patient_welcome_email(user, patient)
            except Exception:
                pass
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
