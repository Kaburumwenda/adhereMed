from rest_framework import serializers

from .models import PharmacyDetail, Delivery, Branch


class BranchSerializer(serializers.ModelSerializer):
    transfer_count = serializers.SerializerMethodField()
    stock_count = serializers.SerializerMethodField()

    class Meta:
        model = Branch
        fields = [
            'id', 'name', 'address', 'place_name', 'latitude', 'longitude',
            'phone', 'email',
            'is_main', 'is_active', 'transfer_count', 'stock_count',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'transfer_count', 'stock_count', 'created_at', 'updated_at']

    def get_transfer_count(self, obj):
        """Stock transfers that reference this branch (source or destination).
        Uses the viewset's annotations when available, else queries directly."""
        out = getattr(obj, 'transfer_out_count', None)
        inc = getattr(obj, 'transfer_in_count', None)
        if out is not None or inc is not None:
            return (out or 0) + (inc or 0)
        from django.db.models import Q
        from inventory.models import StockTransfer
        return StockTransfer.objects.filter(
            Q(source_branch=obj) | Q(dest_branch=obj),
        ).count()

    def get_stock_count(self, obj):
        """Stock items assigned to this branch/warehouse.
        Uses the viewset's annotation when available, else queries directly."""
        count = getattr(obj, 'stock_count', None)
        if count is not None:
            return count
        return obj.stocks.count()


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
    transaction_number = serializers.CharField(source='transaction.transaction_number', read_only=True, default=None)
    so_number = serializers.CharField(source='sales_order.so_number', read_only=True, default=None)
    assigned_to_name = serializers.CharField(source='assigned_to.full_name', read_only=True, default=None)
    driver_display = serializers.SerializerMethodField()

    class Meta:
        model = Delivery
        fields = [
            'id', 'transaction', 'transaction_number',
            'sales_order', 'so_number',
            'delivery_address', 'latitude', 'longitude',
            'recipient_name', 'recipient_phone',
            'delivery_fee', 'status',
            'assigned_to', 'assigned_to_name',
            'assigned_driver_name', 'driver_display',
            'notes', 'scheduled_at', 'delivered_at',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

    def validate(self, attrs):
        # A delivery must be tied to either a POS transaction or a sales order
        has_transaction = attrs.get('transaction', getattr(self.instance, 'transaction', None))
        has_so = attrs.get('sales_order', getattr(self.instance, 'sales_order', None))
        if not has_transaction and not has_so:
            raise serializers.ValidationError(
                'A delivery must be linked to a POS transaction or a sales order.')
        return attrs

    def get_driver_display(self, obj):
        if obj.assigned_to_id and getattr(obj.assigned_to, 'full_name', None):
            return obj.assigned_to.full_name
        return obj.assigned_driver_name or None
