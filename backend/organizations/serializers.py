from rest_framework import serializers
from tenants.models import Tenant
from .models import Organization, OrganizationMembership


class TenantBriefSerializer(serializers.ModelSerializer):
    """Minimal tenant info for the command center grid."""
    logo_url = serializers.SerializerMethodField()

    class Meta:
        model = Tenant
        fields = ['id', 'name', 'type', 'slug', 'schema_name',
                  'is_active', 'logo_url']

    def get_logo_url(self, obj):
        logo = getattr(obj, 'logo', None)
        if not logo:
            return None
        request = self.context.get('request')
        if request:
            return request.build_absolute_uri(logo.url)
        return logo.url


class OrganizationSerializer(serializers.ModelSerializer):
    linked_tenants = serializers.SerializerMethodField()

    class Meta:
        model = Organization
        fields = [
            'id', 'name', 'slug', 'logo', 'motto', 'address', 'city', 'country',
            'phone', 'email', 'website', 'is_active',
            'created_at', 'linked_tenants',
        ]
        read_only_fields = ['slug', 'created_at']

    def get_linked_tenants(self, obj):
        memberships = obj.memberships.filter(is_active=True).select_related('tenant')
        return TenantBriefSerializer(
            [m.tenant for m in memberships], many=True,
            context=self.context).data


class TenantSwitchSerializer(serializers.Serializer):
    """Validates and returns the target tenant for the frontend to switch to."""
    tenant_id = serializers.IntegerField()

    def validate_tenant_id(self, value):
        user = self.context.get('request').user
        org = getattr(user, 'organization', None)
        if not org:
            raise serializers.ValidationError('You are not part of an organization.')
        try:
            membership = OrganizationMembership.objects.select_related('tenant').get(
                organization=org, tenant_id=value, is_active=True,
            )
        except OrganizationMembership.DoesNotExist:
            raise serializers.ValidationError(
                'This tenant is not linked to your organization.')
        self._tenant = membership.tenant
        return value

    def to_representation(self, instance):
        tenant = self._tenant
        return {
            'id': tenant.id,
            'name': tenant.name,
            'type': tenant.type,
            'slug': tenant.slug,
            'schema_name': tenant.schema_name,
        }


class TenantStatsSerializer(serializers.Serializer):
    """Per-tenant stats returned by the stats endpoint."""
    id = serializers.IntegerField()
    name = serializers.CharField()
    type = serializers.CharField()
    slug = serializers.SlugField()
    schema_name = serializers.CharField()
    is_active = serializers.BooleanField()
    user_count = serializers.IntegerField()
    # Type-specific (populated dynamically by views)
    patient_count = serializers.IntegerField(required=False)
    stock_value = serializers.FloatField(required=False)
    revenue_30d = serializers.FloatField(required=False)
    appointments_today = serializers.IntegerField(required=False)
    active_alerts = serializers.IntegerField(required=False)
    low_stock_items = serializers.IntegerField(required=False)


class OrganizationStatsSerializer(serializers.Serializer):
    """Aggregated KPIs across all linked tenants."""
    org = serializers.DictField()
    tenants = serializers.ListField()
    totals = serializers.DictField()
