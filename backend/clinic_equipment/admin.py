from django.contrib import admin

from .models import (
    Equipment,
    EquipmentCategory,
    EquipmentFault,
    EquipmentMaintenance,
    EquipmentSeedRun,
    EquipmentTransfer,
)


@admin.register(EquipmentCategory)
class EquipmentCategoryAdmin(admin.ModelAdmin):
    list_display = ('name', 'code', 'maintenance_interval_days', 'requires_calibration', 'is_active')
    list_filter = ('requires_calibration', 'is_active')
    search_fields = ('name', 'code')


@admin.register(Equipment)
class EquipmentAdmin(admin.ModelAdmin):
    list_display = (
        'asset_tag', 'name', 'category', 'site', 'status', 'condition',
        'criticality', 'next_maintenance', 'is_active',
    )
    list_filter = ('status', 'condition', 'criticality', 'site', 'category', 'is_active')
    search_fields = ('asset_tag', 'name', 'serial_number', 'manufacturer', 'model_number')
    date_hierarchy = 'created_at'


@admin.register(EquipmentMaintenance)
class EquipmentMaintenanceAdmin(admin.ModelAdmin):
    list_display = ('equipment', 'kind', 'status', 'scheduled_date', 'completed_date', 'cost')
    list_filter = ('kind', 'status', 'performed_by')
    search_fields = ('equipment__name', 'equipment__asset_tag', 'vendor_name', 'technician')


@admin.register(EquipmentFault)
class EquipmentFaultAdmin(admin.ModelAdmin):
    list_display = ('title', 'equipment', 'severity', 'status', 'reported_at', 'resolved_at')
    list_filter = ('severity', 'status')
    search_fields = ('title', 'equipment__name', 'equipment__asset_tag')


@admin.register(EquipmentTransfer)
class EquipmentTransferAdmin(admin.ModelAdmin):
    list_display = ('equipment', 'from_site', 'to_site', 'transferred_at')
    search_fields = ('equipment__name', 'equipment__asset_tag', 'reason')


@admin.register(EquipmentSeedRun)
class EquipmentSeedRunAdmin(admin.ModelAdmin):
    list_display = (
        'label', 'status', 'records_created', 'duration_ms',
        'run_by_label', 'created_at',
    )
    list_filter = ('status', 'pack_key')
    search_fields = ('label', 'detail', 'run_by_label')
    readonly_fields = (
        'pack_key', 'label', 'status', 'detail', 'categories_created',
        'assets_created', 'jobs_created', 'faults_created', 'transfers_created',
        'duration_ms', 'run_by', 'run_by_label', 'created_at',
    )

    def has_add_permission(self, request):
        return False
