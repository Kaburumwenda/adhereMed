from rest_framework import serializers

from .models import (
    Equipment,
    EquipmentCategory,
    EquipmentFault,
    EquipmentMaintenance,
    EquipmentTransfer,
)


class EquipmentCategorySerializer(serializers.ModelSerializer):
    item_count = serializers.SerializerMethodField()

    class Meta:
        model = EquipmentCategory
        fields = [
            'id', 'name', 'code', 'description', 'icon',
            'maintenance_interval_days', 'requires_calibration',
            'calibration_interval_days', 'is_active', 'item_count',
            'created_at',
        ]
        read_only_fields = ['id', 'item_count', 'created_at']

    def get_item_count(self, obj):
        cached = getattr(obj, 'item_count', None)
        if cached is not None:
            return cached
        return obj.items.count()


class EquipmentListSerializer(serializers.ModelSerializer):
    """Lean representation for tables and cards."""

    category_name = serializers.CharField(source='category.name', read_only=True, default=None)
    category_icon = serializers.CharField(source='category.icon', read_only=True, default=None)
    site_name = serializers.CharField(source='site.name', read_only=True, default=None)
    department_name = serializers.CharField(source='department.name', read_only=True, default=None)
    custodian_name = serializers.SerializerMethodField()

    status_label = serializers.CharField(source='get_status_display', read_only=True)
    condition_label = serializers.CharField(source='get_condition_display', read_only=True)
    criticality_label = serializers.CharField(source='get_criticality_display', read_only=True)
    ownership_label = serializers.CharField(source='get_ownership_display', read_only=True)

    health_score = serializers.IntegerField(read_only=True)
    health_label = serializers.CharField(read_only=True)
    open_faults = serializers.IntegerField(read_only=True)
    days_to_maintenance = serializers.IntegerField(read_only=True, allow_null=True)
    maintenance_overdue = serializers.BooleanField(read_only=True)
    calibration_overdue = serializers.BooleanField(read_only=True)
    warranty_expired = serializers.BooleanField(read_only=True)
    days_to_warranty_expiry = serializers.IntegerField(read_only=True, allow_null=True)
    age_years = serializers.FloatField(read_only=True, allow_null=True)

    class Meta:
        model = Equipment
        fields = [
            'id', 'asset_tag', 'name', 'description',
            'category', 'category_name', 'category_icon',
            'manufacturer', 'model_number', 'serial_number',
            'site', 'site_name', 'department', 'department_name',
            'location', 'custodian', 'custodian_name',
            'status', 'status_label', 'condition', 'condition_label',
            'criticality', 'criticality_label', 'is_active',
            'ownership', 'ownership_label',
            'purchase_date', 'purchase_price', 'supplier_name', 'warranty_expiry',
            'lease_end', 'commissioned_on', 'expected_life_years',
            'maintenance_interval_days', 'last_maintenance', 'next_maintenance',
            'calibration_required', 'last_calibration', 'next_calibration',
            'notes', 'health_score', 'health_label', 'open_faults',
            'days_to_maintenance', 'maintenance_overdue',
            'calibration_overdue', 'warranty_expired',
            'days_to_warranty_expiry', 'age_years',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

    def get_custodian_name(self, obj):
        user = obj.custodian
        if not user:
            return None
        return getattr(user, 'full_name', '') or getattr(user, 'email', '') or None


class EquipmentWriteSerializer(serializers.ModelSerializer):
    """Create / update payload — accepts everything writable."""

    class Meta:
        model = Equipment
        fields = [
            'id', 'asset_tag', 'name', 'description',
            'category', 'manufacturer', 'model_number', 'serial_number',
            'site', 'department', 'location', 'custodian',
            'status', 'condition', 'criticality', 'is_active',
            'ownership', 'purchase_date', 'purchase_price', 'supplier_name',
            'invoice_number', 'warranty_expiry', 'lease_end', 'commissioned_on',
            'expected_life_years',
            'maintenance_interval_days', 'last_maintenance', 'next_maintenance',
            'calibration_required', 'calibration_interval_days',
            'last_calibration', 'next_calibration',
            'notes',
        ]
        read_only_fields = ['id']
        extra_kwargs = {'asset_tag': {'required': False, 'allow_blank': True}}


class EquipmentMaintenanceSerializer(serializers.ModelSerializer):
    equipment_name = serializers.CharField(source='equipment.name', read_only=True)
    equipment_tag = serializers.CharField(source='equipment.asset_tag', read_only=True)
    site_name = serializers.CharField(source='equipment.site.name', read_only=True, default=None)
    kind_label = serializers.CharField(source='get_kind_display', read_only=True)
    status_label = serializers.CharField(source='get_status_display', read_only=True)
    performed_by_label = serializers.CharField(source='get_performed_by_display', read_only=True)
    is_overdue = serializers.BooleanField(read_only=True)
    days_until_due = serializers.IntegerField(read_only=True)
    created_by_name = serializers.SerializerMethodField()

    class Meta:
        model = EquipmentMaintenance
        fields = [
            'id', 'equipment', 'equipment_name', 'equipment_tag', 'site_name',
            'kind', 'kind_label', 'status', 'status_label',
            'scheduled_date', 'completed_date',
            'performed_by', 'performed_by_label', 'vendor_name', 'technician',
            'cost', 'downtime_hours', 'description', 'findings', 'next_due_date',
            'is_overdue', 'days_until_due',
            'created_by', 'created_by_name', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'created_by']

    def get_created_by_name(self, obj):
        user = obj.created_by
        if not user:
            return None
        return getattr(user, 'full_name', '') or getattr(user, 'email', '') or None


class EquipmentFaultSerializer(serializers.ModelSerializer):
    equipment_name = serializers.CharField(source='equipment.name', read_only=True)
    equipment_tag = serializers.CharField(source='equipment.asset_tag', read_only=True)
    site_name = serializers.CharField(source='equipment.site.name', read_only=True, default=None)
    severity_label = serializers.CharField(source='get_severity_display', read_only=True)
    status_label = serializers.CharField(source='get_status_display', read_only=True)
    is_open = serializers.BooleanField(read_only=True)
    days_open = serializers.IntegerField(read_only=True)
    reported_by_name = serializers.SerializerMethodField()
    resolved_by_name = serializers.SerializerMethodField()

    class Meta:
        model = EquipmentFault
        fields = [
            'id', 'equipment', 'equipment_name', 'equipment_tag', 'site_name',
            'title', 'description', 'severity', 'severity_label',
            'status', 'status_label', 'is_open', 'days_open',
            'reported_by', 'reported_by_name', 'reported_at',
            'resolved_at', 'resolved_by', 'resolved_by_name',
            'resolution', 'downtime_hours', 'maintenance',
            'created_at', 'updated_at',
        ]
        read_only_fields = [
            'id', 'reported_at', 'resolved_at', 'resolved_by',
            'created_at', 'updated_at',
        ]

    def get_reported_by_name(self, obj):
        user = obj.reported_by
        if not user:
            return None
        return getattr(user, 'full_name', '') or getattr(user, 'email', '') or None

    def get_resolved_by_name(self, obj):
        user = obj.resolved_by
        if not user:
            return None
        return getattr(user, 'full_name', '') or getattr(user, 'email', '') or None


class EquipmentTransferSerializer(serializers.ModelSerializer):
    equipment_name = serializers.CharField(source='equipment.name', read_only=True)
    equipment_tag = serializers.CharField(source='equipment.asset_tag', read_only=True)
    from_site_name = serializers.CharField(source='from_site.name', read_only=True, default=None)
    to_site_name = serializers.CharField(source='to_site.name', read_only=True, default=None)
    from_department_name = serializers.CharField(source='from_department.name', read_only=True, default=None)
    to_department_name = serializers.CharField(source='to_department.name', read_only=True, default=None)
    transferred_by_name = serializers.SerializerMethodField()

    class Meta:
        model = EquipmentTransfer
        fields = [
            'id', 'equipment', 'equipment_name', 'equipment_tag',
            'from_site', 'from_site_name', 'to_site', 'to_site_name',
            'from_department', 'from_department_name',
            'to_department', 'to_department_name',
            'reason', 'notes', 'transferred_by', 'transferred_by_name',
            'transferred_at', 'created_at',
        ]
        read_only_fields = ['id', 'created_at']

    def get_transferred_by_name(self, obj):
        user = obj.transferred_by
        if not user:
            return None
        return getattr(user, 'full_name', '') or getattr(user, 'email', '') or None
