from rest_framework import serializers

from .models import PharmacyDetail, Delivery, Branch


class BranchSerializer(serializers.ModelSerializer):
    class Meta:
        model = Branch
        fields = [
            'id', 'name', 'address', 'place_name', 'latitude', 'longitude',
            'phone', 'email',
            'is_main', 'is_active', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class PharmacyDetailSerializer(serializers.ModelSerializer):
    logo_url = serializers.SerializerMethodField()

    class Meta:
        model = PharmacyDetail
        fields = [
            'id', 'name', 'logo', 'logo_url', 'license_number', 'operating_hours',
            'services', 'delivery_radius_km', 'delivery_fee',
            'accepts_insurance', 'insurance_providers',
            'description', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'logo_url', 'created_at', 'updated_at']
        extra_kwargs = {'logo': {'required': False, 'allow_null': True}}

    def get_logo_url(self, obj):
        if not obj.logo:
            return None
        request = self.context.get('request')
        if request:
            return request.build_absolute_uri(obj.logo.url)
        return obj.logo.url


class DeliverySerializer(serializers.ModelSerializer):
    transaction_number = serializers.CharField(source='transaction.transaction_number', read_only=True)
    assigned_to_name = serializers.CharField(source='assigned_to.full_name', read_only=True, default=None)
    driver_display = serializers.SerializerMethodField()

    class Meta:
        model = Delivery
        fields = [
            'id', 'transaction', 'transaction_number',
            'delivery_address', 'latitude', 'longitude',
            'recipient_name', 'recipient_phone',
            'delivery_fee', 'status',
            'assigned_to', 'assigned_to_name',
            'assigned_driver_name', 'driver_display',
            'notes', 'scheduled_at', 'delivered_at',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

    def get_driver_display(self, obj):
        if obj.assigned_to_id and getattr(obj.assigned_to, 'full_name', None):
            return obj.assigned_to.full_name
        return obj.assigned_driver_name or None
