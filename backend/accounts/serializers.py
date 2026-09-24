from rest_framework import serializers
from django.contrib.auth import authenticate
from django.contrib.auth.models import Group, Permission
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
        return obj.role in {'tenant_admin', 'homecare_admin', 'inventory_admin', 'admin'}

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


class UserManagementSerializer(serializers.ModelSerializer):
    """Write serializer for tenant admins managing staff users."""
    password = serializers.CharField(min_length=8, write_only=True, required=False, allow_blank=True)
    full_name = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = User
        fields = [
            'id', 'email', 'phone', 'first_name', 'last_name',
            'role', 'is_active', 'password', 'full_name',
        ]
        read_only_fields = ['id', 'date_joined', 'pin']

    def get_full_name(self, obj):
        return f'{obj.first_name} {obj.last_name}'.strip() or obj.email

    def create(self, validated_data):
        password = validated_data.pop('password', None)
        user = User(**validated_data)
        if password:
            user.set_password(password)
        else:
            # Staff users must have a password; generate a random one if omitted.
            import secrets, string
            user.set_password(''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(12)))
        user.is_staff = True
        user.save()
        return user

    def update(self, instance, validated_data):
        password = validated_data.pop('password', None)
        if password:
            instance.set_password(password)
        for k, v in validated_data.items():
            setattr(instance, k, v)
        instance.save()
        return instance


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


# ---------------------------------------------------------------------------
# Roles & Permissions (IAM & Security)
#
# Uses Django's built-in auth.Group / auth.Permission models which are
# already per-tenant (auth is listed in TENANT_APPS). A Group is a "Role"
# that bundles a set of Permissions; users are assigned to one or more
# roles through user.groups.
# ---------------------------------------------------------------------------

class PermissionSerializer(serializers.ModelSerializer):
    app_label = serializers.CharField(source='content_type.app_label', read_only=True)
    model = serializers.CharField(source='content_type.model', read_only=True)

    class Meta:
        model = Permission
        fields = ['id', 'name', 'codename', 'app_label', 'model']
        read_only_fields = fields


class RoleSerializer(serializers.ModelSerializer):
    """Serializer for auth.Group, treated as a 'Role'."""
    permissions = serializers.PrimaryKeyRelatedField(
        many=True, queryset=Permission.objects.all(),
        required=False, allow_empty=True
    )
    user_count = serializers.SerializerMethodField()
    permission_details = serializers.SerializerMethodField()

    class Meta:
        model = Group
        fields = ['id', 'name', 'permissions', 'user_count', 'permission_details']
        read_only_fields = ['id', 'user_count', 'permission_details']

    def get_user_count(self, obj):
        return obj.user_set.count() if hasattr(obj, 'user_set') else 0

    def get_permission_details(self, obj):
        return [{'id': p.id, 'name': p.name, 'codename': p.codename}
                for p in obj.permissions.all()]

