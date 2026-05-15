from rest_framework import serializers
from .models import Tenant, Domain


class DomainSerializer(serializers.ModelSerializer):
    class Meta:
        model = Domain
        fields = ['id', 'domain', 'is_primary']


class TenantSerializer(serializers.ModelSerializer):
    domains = DomainSerializer(many=True, read_only=True)

    class Meta:
        model = Tenant
        fields = [
            'id', 'name', 'type', 'slug', 'schema_name',
            'logo', 'address', 'city', 'country',
            'latitude', 'longitude', 'place_name',
            'phone', 'email', 'website',
            'is_active', 'created_at', 'domains',
        ]
        read_only_fields = ['schema_name', 'created_at']


class TenantRegistrationSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=255)
    type = serializers.ChoiceField(choices=Tenant.TenantType.choices)
    slug = serializers.SlugField()
    domain = serializers.CharField(max_length=253)
    address = serializers.CharField(required=False, allow_blank=True)
    city = serializers.CharField(max_length=100, required=False, allow_blank=True)
    phone = serializers.CharField(max_length=20, required=False, allow_blank=True)
    email = serializers.EmailField(required=False, allow_blank=True)
    # Admin user details
    admin_email = serializers.EmailField()
    admin_first_name = serializers.CharField(max_length=150)
    admin_last_name = serializers.CharField(max_length=150)
    admin_password = serializers.CharField(min_length=8, write_only=True)
    # Optional referral code
    referral_code = serializers.CharField(max_length=12, required=False, allow_blank=True)

    def validate_slug(self, value):
        if Tenant.objects.filter(slug=value).exists():
            raise serializers.ValidationError('A tenant with this slug already exists.')
        return value

    def validate_domain(self, value):
        if Domain.objects.filter(domain=value).exists():
            raise serializers.ValidationError('This domain is already in use.')
        return value

    def validate_admin_email(self, value):
        from accounts.models import User
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError('A user with this email already exists.')
        return value
