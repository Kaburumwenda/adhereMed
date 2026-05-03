from django.contrib.auth import get_user_model
from rest_framework import serializers

from tenants.models import Domain, Tenant

User = get_user_model()


class DomainInlineSerializer(serializers.ModelSerializer):
    class Meta:
        model = Domain
        fields = ["id", "domain", "is_primary"]


class TenantAdminSerializer(serializers.ModelSerializer):
    domains = DomainInlineSerializer(many=True, read_only=True)
    user_count = serializers.SerializerMethodField()

    class Meta:
        model = Tenant
        fields = [
            "id", "name", "type", "slug", "schema_name",
            "address", "city", "country", "phone", "email", "website",
            "is_active", "created_at", "updated_at",
            "domains", "user_count",
        ]
        read_only_fields = ["schema_name", "created_at", "updated_at", "slug"]

    def get_user_count(self, obj):
        return User.objects.filter(tenant=obj).count()


class TenantCreateSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=255)
    type = serializers.ChoiceField(choices=Tenant.TenantType.choices)
    slug = serializers.SlugField()
    domain = serializers.CharField(max_length=253)
    address = serializers.CharField(required=False, allow_blank=True, default="")
    city = serializers.CharField(max_length=100, required=False, allow_blank=True, default="")
    phone = serializers.CharField(max_length=20, required=False, allow_blank=True, default="")
    email = serializers.EmailField(required=False, allow_blank=True, default="")
    website = serializers.URLField(required=False, allow_blank=True, default="")
    # Admin user
    admin_email = serializers.EmailField()
    admin_first_name = serializers.CharField(max_length=150)
    admin_last_name = serializers.CharField(max_length=150)
    admin_password = serializers.CharField(min_length=8, write_only=True, required=False, allow_blank=True)

    def validate_slug(self, value):
        if Tenant.objects.filter(slug=value).exists():
            raise serializers.ValidationError("A tenant with this slug already exists.")
        return value

    def validate_domain(self, value):
        if Domain.objects.filter(domain=value).exists():
            raise serializers.ValidationError("This domain is already in use.")
        return value

    def validate_admin_email(self, value):
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("A user with this email already exists.")
        return value


class UserAdminSerializer(serializers.ModelSerializer):
    tenant_name = serializers.CharField(source="tenant.name", read_only=True, default=None)
    tenant_type = serializers.CharField(source="tenant.type", read_only=True, default=None)

    class Meta:
        model = User
        fields = [
            "id", "email", "phone", "first_name", "last_name",
            "role", "tenant", "tenant_name", "tenant_type",
            "is_active", "is_staff", "date_joined",
        ]
        read_only_fields = ["date_joined"]


class UserAdminUpdateSerializer(serializers.ModelSerializer):
    """Allows updating user info but not password (use the dedicated endpoint)."""

    class Meta:
        model = User
        fields = [
            "email", "phone", "first_name", "last_name",
            "role", "tenant", "is_active", "is_staff",
        ]

    def validate_email(self, value):
        user = self.instance
        if User.objects.filter(email=value).exclude(pk=user.pk).exists():
            raise serializers.ValidationError("This email is already in use.")
        return value
