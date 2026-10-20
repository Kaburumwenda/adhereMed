from django.contrib import admin

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


@admin.register(Carrier)
class CarrierAdmin(admin.ModelAdmin):
    list_display = ('name', 'code', 'phone', 'service_level', 'rating', 'is_active')
    list_filter = ('service_level', 'is_active')
    search_fields = ('name', 'code', 'contact_person')


@admin.register(Vehicle)
class VehicleAdmin(admin.ModelAdmin):
    list_display = ('plate_number', 'name', 'vehicle_type', 'status', 'home_branch', 'is_active')
    list_filter = ('status', 'vehicle_type', 'ownership', 'is_active')
    search_fields = ('plate_number', 'name', 'make', 'model')


@admin.register(Driver)
class DriverAdmin(admin.ModelAdmin):
    list_display = ('full_name', 'phone', 'status', 'license_number', 'license_expiry', 'is_active')
    list_filter = ('status', 'is_active')
    search_fields = ('full_name', 'phone', 'license_number')


@admin.register(DeliveryZone)
class DeliveryZoneAdmin(admin.ModelAdmin):
    list_display = ('name', 'zone_type', 'base_fee', 'per_km_fee', 'eta_hours', 'is_active')
    list_filter = ('zone_type', 'is_active')


class ShipmentStopInline(admin.TabularInline):
    model = ShipmentStop
    extra = 0


class ShipmentItemInline(admin.TabularInline):
    model = ShipmentItem
    extra = 0


@admin.register(Shipment)
class ShipmentAdmin(admin.ModelAdmin):
    list_display = ('reference', 'movement_type', 'status', 'priority', 'origin_name', 'dest_name', 'scheduled_delivery')
    list_filter = ('status', 'movement_type', 'priority', 'requires_refrigeration')
    search_fields = ('reference', 'tracking_number', 'origin_name', 'dest_name')
    inlines = [ShipmentStopInline, ShipmentItemInline]


@admin.register(ShipmentEvent)
class ShipmentEventAdmin(admin.ModelAdmin):
    list_display = ('shipment', 'event_type', 'occurred_at', 'location')
    list_filter = ('event_type',)


@admin.register(RoutePlan)
class RoutePlanAdmin(admin.ModelAdmin):
    list_display = ('name', 'plan_date', 'status', 'driver', 'vehicle', 'stop_count')
    list_filter = ('status', 'plan_date')
    filter_horizontal = ('shipments',)


@admin.register(VehicleMaintenance)
class VehicleMaintenanceAdmin(admin.ModelAdmin):
    list_display = ('vehicle', 'kind', 'performed_at', 'cost', 'vendor', 'next_due_at')
    list_filter = ('kind',)
