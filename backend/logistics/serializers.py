from rest_framework import serializers

from .models import (
    Carrier,
    DeliveryZone,
    Driver,
    RoutePlan,
    Shipment,
    ShipmentEvent,
    ShipmentItem,
    ShipmentStop,
    Vehicle,
    VehicleMaintenance,
)


class CarrierSerializer(serializers.ModelSerializer):
    class Meta:
        model = Carrier
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']


class VehicleSerializer(serializers.ModelSerializer):
    carrier_name = serializers.CharField(source='carrier.name', read_only=True)
    home_branch_name = serializers.CharField(source='home_branch.name', read_only=True)
    display_name = serializers.CharField(read_only=True)
    shipment_count = serializers.SerializerMethodField()

    class Meta:
        model = Vehicle
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']

    def get_shipment_count(self, obj):
        return obj.shipments.count()


class DriverSerializer(serializers.ModelSerializer):
    assigned_vehicle_plate = serializers.CharField(
        source='assigned_vehicle.plate_number', read_only=True,
    )
    home_branch_name = serializers.CharField(source='home_branch.name', read_only=True)
    license_valid = serializers.BooleanField(read_only=True)
    shipment_count = serializers.SerializerMethodField()

    class Meta:
        model = Driver
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']

    def get_shipment_count(self, obj):
        return obj.shipments.count()


class DeliveryZoneSerializer(serializers.ModelSerializer):
    branch_name = serializers.CharField(source='branch.name', read_only=True)

    class Meta:
        model = DeliveryZone
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']


class ShipmentStopSerializer(serializers.ModelSerializer):
    class Meta:
        model = ShipmentStop
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']


class ShipmentItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = ShipmentItem
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']


class ShipmentEventSerializer(serializers.ModelSerializer):
    created_by_name = serializers.SerializerMethodField()

    class Meta:
        model = ShipmentEvent
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']

    def get_created_by_name(self, obj):
        if not obj.created_by:
            return ''
        return getattr(obj.created_by, 'full_name', '') or obj.created_by.get_username()


class ShipmentSerializer(serializers.ModelSerializer):
    stops = ShipmentStopSerializer(many=True, read_only=True)
    items = ShipmentItemSerializer(many=True, read_only=True)
    events = ShipmentEventSerializer(many=True, read_only=True)

    carrier_name = serializers.CharField(source='carrier.name', read_only=True)
    vehicle_plate = serializers.CharField(source='vehicle.plate_number', read_only=True)
    vehicle_display = serializers.CharField(source='vehicle.display_name', read_only=True)
    driver_name = serializers.CharField(source='driver.full_name', read_only=True)
    driver_phone = serializers.CharField(source='driver.phone', read_only=True)
    source_branch_name = serializers.CharField(source='source_branch.name', read_only=True)
    dest_branch_name = serializers.CharField(source='dest_branch.name', read_only=True)
    zone_name = serializers.CharField(source='zone.name', read_only=True)
    stock_transfer_reference = serializers.CharField(
        source='stock_transfer.reference', read_only=True,
    )

    total_cost = serializers.DecimalField(max_digits=14, decimal_places=2, read_only=True)
    is_late = serializers.BooleanField(read_only=True)
    created_by_name = serializers.SerializerMethodField()

    class Meta:
        model = Shipment
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at', 'reference', 'tracking_number']

    def get_created_by_name(self, obj):
        if not obj.created_by:
            return ''
        return getattr(obj.created_by, 'full_name', '') or obj.created_by.get_username()


class ShipmentListSerializer(serializers.ModelSerializer):
    """Lighter payload for board / list views."""

    carrier_name = serializers.CharField(source='carrier.name', read_only=True)
    vehicle_plate = serializers.CharField(source='vehicle.plate_number', read_only=True)
    driver_name = serializers.CharField(source='driver.full_name', read_only=True)
    source_branch_name = serializers.CharField(source='source_branch.name', read_only=True)
    dest_branch_name = serializers.CharField(source='dest_branch.name', read_only=True)
    total_cost = serializers.DecimalField(max_digits=14, decimal_places=2, read_only=True)
    is_late = serializers.BooleanField(read_only=True)

    class Meta:
        model = Shipment
        fields = [
            'id', 'reference', 'tracking_number', 'movement_type', 'status', 'priority',
            'source_type', 'dest_type', 'source_branch', 'dest_branch',
            'source_branch_name', 'dest_branch_name',
            'origin_name', 'origin_address', 'dest_name', 'dest_address',
            'dest_contact', 'dest_phone',
            'carrier', 'carrier_name', 'vehicle', 'vehicle_plate', 'driver', 'driver_name',
            'scheduled_pickup', 'scheduled_delivery', 'actual_pickup', 'actual_delivery',
            'distance_km', 'parcel_count', 'weight_kg',
            'freight_cost', 'fuel_cost', 'other_cost', 'total_cost',
            'requires_refrigeration', 'is_late',
            'stock_transfer', 'sales_order', 'purchase_order',
            'created_at', 'updated_at',
        ]


class RoutePlanSerializer(serializers.ModelSerializer):
    driver_name = serializers.CharField(source='driver.full_name', read_only=True)
    vehicle_plate = serializers.CharField(source='vehicle.plate_number', read_only=True)
    carrier_name = serializers.CharField(source='carrier.name', read_only=True)
    shipment_refs = serializers.SerializerMethodField()

    class Meta:
        model = RoutePlan
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']

    def get_shipment_refs(self, obj):
        return list(obj.shipments.values_list('reference', flat=True))


class VehicleMaintenanceSerializer(serializers.ModelSerializer):
    vehicle_plate = serializers.CharField(source='vehicle.plate_number', read_only=True)

    class Meta:
        model = VehicleMaintenance
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']
