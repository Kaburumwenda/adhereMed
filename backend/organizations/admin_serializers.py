"""Serializers for the superadmin organization management endpoints."""
from rest_framework import serializers
from tenants.models import Tenant
from .models import Organization, OrganizationMembership


class TenantOptionSerializer(serializers.ModelSerializer):
    """Minimal tenant info for dropdowns / link pickers."""
    class Meta:
        model = Tenant
        fields = ['id', 'name', 'type', 'schema_name', 'is_active']


class OrganizationAdminSerializer(serializers.ModelSerializer):
    """Full org representation for superadmin CRUD."""
    linked_tenants = serializers.SerializerMethodField()
    admin_users = serializers.SerializerMethodField()
    tenant_count = serializers.SerializerMethodField()

    class Meta:
        model = Organization
        fields = [
            'id', 'name', 'slug', 'logo', 'motto', 'address', 'city', 'country',
            'phone', 'email', 'website', 'is_active',
            'created_at', 'updated_at',
            'linked_tenants', 'admin_users', 'tenant_count',
        ]
        read_only_fields = ['id', 'slug', 'created_at', 'updated_at']

    def get_linked_tenants(self, obj):
        memberships = obj.memberships.select_related('tenant').order_by('tenant__name')
        return [
            {
                'id': m.tenant.id,
                'name': m.tenant.name,
                'type': m.tenant.type,
                'schema_name': m.tenant.schema_name,
                'is_active': m.tenant.is_active,
                'membership_active': m.is_active,
            }
            for m in memberships
        ]

    def get_admin_users(self, obj):
        from django.contrib.auth import get_user_model
        User = get_user_model()
        users = User.objects.filter(organization=obj, is_org_admin=True).values(
            'id', 'email', 'first_name', 'last_name'
        )
        return list(users)

    def get_tenant_count(self, obj):
        return obj.memberships.filter(is_active=True).count()


class OrganizationCreateSerializer(serializers.ModelSerializer):
    """For creating an org — auto-generates slug if not provided."""
    tenant_ids = serializers.ListField(
        child=serializers.IntegerField(), required=False, allow_empty=True
    )
    admin_emails = serializers.ListField(
        child=serializers.EmailField(), required=False, allow_empty=True
    )

    class Meta:
        model = Organization
        fields = [
            'name', 'slug', 'address', 'city', 'country',
            'phone', 'email', 'website', 'is_active',
            'tenant_ids', 'admin_emails',
        ]

    def validate_slug(self, value):
        if value and Organization.objects.filter(slug=value).exists():
            raise serializers.ValidationError("An org with this slug already exists.")
        return value

    def create(self, validated_data):
        tenant_ids = validated_data.pop('tenant_ids', [])
        admin_emails = validated_data.pop('admin_emails', [])

        slug = validated_data.get('slug') or validated_data['name'].lower().replace(' ', '-')
        validated_data['slug'] = slug

        org = Organization.objects.create(**validated_data)

        # Link tenants
        for tid in tenant_ids:
            try:
                tenant = Tenant.objects.get(id=tid)
                OrganizationMembership.objects.get_or_create(
                    organization=org, tenant=tenant,
                    defaults={'is_active': True},
                )
            except Tenant.DoesNotExist:
                pass

        # Designate admins
        if admin_emails:
            from django.contrib.auth import get_user_model
            User = get_user_model()
            for email in admin_emails:
                try:
                    user = User.objects.get(email=email)
                    user.organization = org
                    user.is_org_admin = True
                    user.save(update_fields=['organization', 'is_org_admin'])
                except User.DoesNotExist:
                    pass

        return org


class LinkTenantSerializer(serializers.Serializer):
    tenant_id = serializers.IntegerField()

    def validate_tenant_id(self, value):
        if not Tenant.objects.filter(id=value).exists():
            raise serializers.ValidationError("Tenant not found.")
        return value


class SetAdminSerializer(serializers.Serializer):
    user_email = serializers.EmailField()
