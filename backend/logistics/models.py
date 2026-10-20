"""Warehouse Transport & Logistics models.

Covers the full movement lifecycle for an inventory/warehouse tenant:

    Carrier / Vehicle / Driver  ->  the physical transport capacity
    Shipment                    ->  a transport job (inventory transfer,
                                    customer delivery, supplier pickup…)
    ShipmentStop / Item / Event ->  multi-stop routing, parcels, tracking trail
    RoutePlan                   ->  planned run for one driver + vehicle + date
    VehicleMaintenance          ->  fleet upkeep, service and compliance

All models live in the tenant schema (django-tenants TENANT_APPS) so each
business gets an isolated fleet, partner roster and shipment history.
"""
from decimal import Decimal

from django.conf import settings
from django.db import models
from django.utils import timezone


class TimeStampedModel(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


# ─────────────────────────────────────────────────────────────────────────
#  Partners & capacity
# ─────────────────────────────────────────────────────────────────────────
class Carrier(TimeStampedModel):
    """Third-party logistics partner (3PL / courier / haulier)."""

    class ServiceLevel(models.TextChoices):
        ECONOMY = 'economy', 'Economy'
        STANDARD = 'standard', 'Standard'
        EXPRESS = 'express', 'Express'
        SAME_DAY = 'same_day', 'Same day'

    name = models.CharField(max_length=255)
    code = models.CharField(max_length=30, blank=True)
    contact_person = models.CharField(max_length=255, blank=True)
    phone = models.CharField(max_length=30, blank=True)
    email = models.EmailField(blank=True)
    address = models.TextField(blank=True)
    service_area = models.CharField(max_length=255, blank=True, help_text='Regions served')
    service_level = models.CharField(
        max_length=20, choices=ServiceLevel.choices, default=ServiceLevel.STANDARD,
    )
    rate_per_km = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    flat_rate = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    currency = models.CharField(max_length=8, default='KES')
    rating = models.DecimalField(max_digits=3, decimal_places=2, default=0)
    on_time_rate = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    is_active = models.BooleanField(default=True)
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ['name']
        verbose_name_plural = 'carriers'

    def __str__(self):
        return self.name


class Vehicle(TimeStampedModel):
    """A physical asset used to move goods."""

    class VehicleType(models.TextChoices):
        LORRY = 'lorry', 'Lorry'
        TRUCK = 'truck', 'Truck'
        VAN = 'van', 'Van'
        PICKUP = 'pickup', 'Pickup'
        REFRIGERATED = 'refrigerated', 'Refrigerated truck'
        MOTORBIKE = 'motorbike', 'Motorbike'
        BICYCLE = 'bicycle', 'Bicycle'
        OTHER = 'other', 'Other'

    class Ownership(models.TextChoices):
        OWNED = 'owned', 'Owned'
        LEASED = 'leased', 'Leased'
        THIRD_PARTY = 'third_party', 'Third party'

    class Status(models.TextChoices):
        AVAILABLE = 'available', 'Available'
        IN_USE = 'in_use', 'In use'
        MAINTENANCE = 'maintenance', 'In maintenance'
        RETIRED = 'retired', 'Retired'

    class FuelType(models.TextChoices):
        PETROL = 'petrol', 'Petrol'
        DIESEL = 'diesel', 'Diesel'
        ELECTRIC = 'electric', 'Electric'
        HYBRID = 'hybrid', 'Hybrid'
        NONE = 'none', 'N/A'

    plate_number = models.CharField(max_length=30, unique=True)
    name = models.CharField(max_length=120, blank=True, help_text='Friendly name')
    vehicle_type = models.CharField(
        max_length=20, choices=VehicleType.choices, default=VehicleType.VAN,
    )
    make = models.CharField(max_length=80, blank=True)
    model = models.CharField(max_length=80, blank=True)
    year = models.PositiveIntegerField(null=True, blank=True)
    color = models.CharField(max_length=30, blank=True)

    capacity_kg = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    capacity_volume_m3 = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    ownership = models.CharField(
        max_length=20, choices=Ownership.choices, default=Ownership.OWNED,
    )
    carrier = models.ForeignKey(
        Carrier, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='vehicles',
    )
    home_branch = models.ForeignKey(
        'pharmacy_profile.Branch', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='logistics_vehicles',
    )

    status = models.CharField(max_length=20, choices=Status.choices, default=Status.AVAILABLE)

    odometer_km = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    fuel_type = models.CharField(max_length=20, choices=FuelType.choices, default=FuelType.DIESEL)
    fuel_capacity_l = models.DecimalField(max_digits=10, decimal_places=2, default=0)

    insurance_expiry = models.DateField(null=True, blank=True)
    inspection_expiry = models.DateField(null=True, blank=True)
    last_service_at = models.DateField(null=True, blank=True)
    next_service_km = models.DecimalField(max_digits=12, decimal_places=2, default=0)

    is_active = models.BooleanField(default=True)
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ['plate_number']

    def __str__(self):
        return f'{self.plate_number}{f" · {self.name}" if self.name else ""}'

    @property
    def display_name(self):
        label = ' '.join(x for x in [self.make, self.model] if x)
        return f'{self.plate_number} — {label}' if label else self.plate_number


class Driver(TimeStampedModel):
    """A person licensed to operate fleet vehicles."""

    class Status(models.TextChoices):
        AVAILABLE = 'available', 'Available'
        ON_TRIP = 'on_trip', 'On trip'
        OFF_DUTY = 'off_duty', 'Off duty'
        SUSPENDED = 'suspended', 'Suspended'

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='logistics_driver_profile',
    )
    full_name = models.CharField(max_length=255)
    phone = models.CharField(max_length=30, blank=True)
    email = models.EmailField(blank=True)
    national_id = models.CharField(max_length=40, blank=True)
    license_number = models.CharField(max_length=60, blank=True)
    license_class = models.CharField(max_length=30, blank=True)
    license_expiry = models.DateField(null=True, blank=True)
    medical_check_expiry = models.DateField(null=True, blank=True)

    status = models.CharField(max_length=20, choices=Status.choices, default=Status.AVAILABLE)
    home_branch = models.ForeignKey(
        'pharmacy_profile.Branch', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='logistics_drivers',
    )
    assigned_vehicle = models.ForeignKey(
        Vehicle, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='assigned_drivers',
    )

    rating = models.DecimalField(max_digits=3, decimal_places=2, default=0)
    total_trips = models.PositiveIntegerField(default=0)
    total_distance_km = models.DecimalField(max_digits=12, decimal_places=2, default=0)

    is_active = models.BooleanField(default=True)
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ['full_name']

    def __str__(self):
        return self.full_name

    @property
    def license_valid(self):
        return not self.license_expiry or self.license_expiry >= timezone.localdate()


class DeliveryZone(TimeStampedModel):
    """Pricing / ETA rules by geographic zone."""

    class ZoneType(models.TextChoices):
        LOCAL = 'local', 'Local'
        REGIONAL = 'regional', 'Regional'
        NATIONAL = 'national', 'National'
        INTERNATIONAL = 'international', 'International'

    name = models.CharField(max_length=120)
    code = models.CharField(max_length=30, blank=True)
    zone_type = models.CharField(
        max_length=20, choices=ZoneType.choices, default=ZoneType.LOCAL,
    )
    branch = models.ForeignKey(
        'pharmacy_profile.Branch', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='logistics_zones',
    )
    areas = models.JSONField(default=list, blank=True, help_text='Area / town names')
    base_fee = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    per_km_fee = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    free_above = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    eta_hours = models.PositiveIntegerField(default=24, help_text='Typical delivery window')
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


# ─────────────────────────────────────────────────────────────────────────
#  Shipments
# ─────────────────────────────────────────────────────────────────────────
class Shipment(TimeStampedModel):
    """A single transport job.

    A shipment may be generated from an internal stock transfer, a customer
    sales order, a supplier purchase order, or created standalone for ad-hoc
    movement. It is the unit of work dispatched to a carrier / vehicle /
    driver and tracked through to proof of delivery.
    """

    class MovementType(models.TextChoices):
        TRANSFER = 'transfer', 'Internal transfer'
        CUSTOMER_DELIVERY = 'customer_delivery', 'Customer delivery'
        SUPPLIER_PICKUP = 'supplier_pickup', 'Supplier pickup'
        CUSTOMER_RETURN = 'customer_return', 'Customer return'
        SUPPLIER_RETURN = 'supplier_return', 'Return to supplier'
        INTERCOMPANY = 'intercompany', 'Intercompany'

    class Status(models.TextChoices):
        DRAFT = 'draft', 'Draft'
        PLANNED = 'planned', 'Planned'
        ASSIGNED = 'assigned', 'Assigned'
        PICKED_UP = 'picked_up', 'Picked up'
        IN_TRANSIT = 'in_transit', 'In transit'
        OUT_FOR_DELIVERY = 'out_for_delivery', 'Out for delivery'
        DELIVERED = 'delivered', 'Delivered'
        FAILED = 'failed', 'Failed'
        CANCELLED = 'cancelled', 'Cancelled'
        RETURNED = 'returned', 'Returned'

    class Priority(models.TextChoices):
        LOW = 'low', 'Low'
        NORMAL = 'normal', 'Normal'
        HIGH = 'high', 'High'
        URGENT = 'urgent', 'Urgent'

    class PartyType(models.TextChoices):
        WAREHOUSE = 'warehouse', 'Warehouse'
        CUSTOMER = 'customer', 'Customer'
        SUPPLIER = 'supplier', 'Supplier'
        OTHER = 'other', 'Other'

    reference = models.CharField(max_length=30, unique=True, blank=True)
    tracking_number = models.CharField(max_length=40, blank=True, db_index=True)

    movement_type = models.CharField(
        max_length=25, choices=MovementType.choices, default=MovementType.TRANSFER,
    )
    status = models.CharField(max_length=25, choices=Status.choices, default=Status.DRAFT)
    priority = models.CharField(max_length=10, choices=Priority.choices, default=Priority.NORMAL)

    source_type = models.CharField(
        max_length=20, choices=PartyType.choices, default=PartyType.WAREHOUSE,
    )
    dest_type = models.CharField(
        max_length=20, choices=PartyType.choices, default=PartyType.WAREHOUSE,
    )

    source_branch = models.ForeignKey(
        'pharmacy_profile.Branch', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='logistics_shipments_out',
    )
    dest_branch = models.ForeignKey(
        'pharmacy_profile.Branch', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='logistics_shipments_in',
    )

    origin_name = models.CharField(max_length=255, blank=True)
    origin_address = models.TextField(blank=True)
    origin_contact = models.CharField(max_length=255, blank=True)
    origin_phone = models.CharField(max_length=30, blank=True)

    dest_name = models.CharField(max_length=255, blank=True)
    dest_address = models.TextField(blank=True)
    dest_contact = models.CharField(max_length=255, blank=True)
    dest_phone = models.CharField(max_length=30, blank=True)

    # Optional links into the rest of the ERP
    stock_transfer = models.ForeignKey(
        'inventory.StockTransfer', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='shipments',
    )
    sales_order = models.ForeignKey(
        'sales_orders.SalesOrder', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='shipments',
    )
    purchase_order = models.ForeignKey(
        'purchase_orders.PurchaseOrder', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='shipments',
    )

    carrier = models.ForeignKey(
        Carrier, on_delete=models.SET_NULL, null=True, blank=True, related_name='shipments',
    )
    vehicle = models.ForeignKey(
        Vehicle, on_delete=models.SET_NULL, null=True, blank=True, related_name='shipments',
    )
    driver = models.ForeignKey(
        Driver, on_delete=models.SET_NULL, null=True, blank=True, related_name='shipments',
    )
    zone = models.ForeignKey(
        DeliveryZone, on_delete=models.SET_NULL, null=True, blank=True, related_name='shipments',
    )

    scheduled_pickup = models.DateTimeField(null=True, blank=True)
    scheduled_delivery = models.DateTimeField(null=True, blank=True)
    actual_pickup = models.DateTimeField(null=True, blank=True)
    actual_delivery = models.DateTimeField(null=True, blank=True)

    distance_km = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    duration_minutes = models.PositiveIntegerField(default=0)

    freight_cost = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    fuel_cost = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    other_cost = models.DecimalField(max_digits=12, decimal_places=2, default=0)

    weight_kg = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    volume_m3 = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    parcel_count = models.PositiveIntegerField(default=0)
    requires_refrigeration = models.BooleanField(default=False)

    pod_received_by = models.CharField(max_length=255, blank=True)
    pod_signature = models.TextField(blank=True, help_text='Signature data URL or reference')
    pod_notes = models.TextField(blank=True)
    failure_reason = models.TextField(blank=True)

    notes = models.TextField(blank=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='created_shipments',
    )

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['status', 'scheduled_delivery']),
            models.Index(fields=['movement_type']),
        ]

    def save(self, *args, **kwargs):
        if not self.reference:
            super().save(*args, **kwargs)
            self.reference = f'SHP-{self.pk:05d}'
            if not self.tracking_number:
                self.tracking_number = f'TRK{self.pk:08d}'
            kwargs['force_insert'] = False
        super().save(*args, **kwargs)

    def __str__(self):
        return f'{self.reference} · {self.origin_name or "?"} → {self.dest_name or "?"}'

    @property
    def total_cost(self):
        return (self.freight_cost or Decimal('0')) + (self.fuel_cost or Decimal('0')) + (self.other_cost or Decimal('0'))

    @property
    def is_open(self):
        return self.status not in (
            self.Status.DELIVERED, self.Status.CANCELLED, self.Status.RETURNED,
        )

    @property
    def is_late(self):
        if not self.scheduled_delivery or not self.is_open:
            return False
        return timezone.now() > self.scheduled_delivery


class ShipmentStop(TimeStampedModel):
    """An ordered stop on a shipment route."""

    class StopType(models.TextChoices):
        PICKUP = 'pickup', 'Pickup'
        DROPOFF = 'dropoff', 'Drop-off'
        TRANSIT = 'transit', 'Transit hub'
        RETURN = 'return', 'Return'

    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        ARRIVED = 'arrived', 'Arrived'
        COMPLETED = 'completed', 'Completed'
        FAILED = 'failed', 'Failed'
        SKIPPED = 'skipped', 'Skipped'

    shipment = models.ForeignKey(Shipment, on_delete=models.CASCADE, related_name='stops')
    sequence = models.PositiveIntegerField(default=0)
    stop_type = models.CharField(max_length=20, choices=StopType.choices, default=StopType.DROPOFF)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)

    name = models.CharField(max_length=255)
    address = models.TextField(blank=True)
    contact_name = models.CharField(max_length=255, blank=True)
    contact_phone = models.CharField(max_length=30, blank=True)
    latitude = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    longitude = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)

    scheduled_at = models.DateTimeField(null=True, blank=True)
    arrived_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    notes = models.TextField(blank=True)

    class Meta:
        ordering = ['sequence', 'id']

    def __str__(self):
        return f'{self.sequence}. {self.name}'


class ShipmentItem(TimeStampedModel):
    """Parcel / goods line for shipments not already described by a transfer."""

    shipment = models.ForeignKey(Shipment, on_delete=models.CASCADE, related_name='items')
    description = models.CharField(max_length=255)
    sku = models.CharField(max_length=80, blank=True)
    quantity = models.DecimalField(max_digits=12, decimal_places=2, default=1)
    unit = models.CharField(max_length=30, blank=True)
    weight_kg = models.DecimalField(max_digits=12, decimal_places=3, default=0)
    value = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    notes = models.CharField(max_length=255, blank=True)

    class Meta:
        ordering = ['description']

    def __str__(self):
        return f'{self.description} × {self.quantity}'


class ShipmentEvent(TimeStampedModel):
    """Immutable tracking trail entry."""

    class EventType(models.TextChoices):
        CREATED = 'created', 'Created'
        PLANNED = 'planned', 'Planned'
        ASSIGNED = 'assigned', 'Assigned'
        PICKED_UP = 'picked_up', 'Picked up'
        DEPARTED = 'departed', 'Departed hub'
        IN_TRANSIT = 'in_transit', 'In transit'
        ARRIVED = 'arrived', 'Arrived at stop'
        DELIVERED = 'delivered', 'Delivered'
        FAILED = 'failed', 'Delivery failed'
        EXCEPTION = 'exception', 'Exception'
        CANCELLED = 'cancelled', 'Cancelled'
        NOTE = 'note', 'Note'

    shipment = models.ForeignKey(Shipment, on_delete=models.CASCADE, related_name='events')
    event_type = models.CharField(max_length=20, choices=EventType.choices, default=EventType.NOTE)
    description = models.CharField(max_length=255, blank=True)
    location = models.CharField(max_length=255, blank=True)
    occurred_at = models.DateTimeField(default=timezone.now)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='shipment_events',
    )

    class Meta:
        ordering = ['-occurred_at', '-id']

    def __str__(self):
        return f'{self.shipment.reference} · {self.event_type}'


class RoutePlan(TimeStampedModel):
    """A planned run: one driver + vehicle over a set of shipments."""

    class Status(models.TextChoices):
        DRAFT = 'draft', 'Draft'
        OPTIMIZED = 'optimized', 'Optimized'
        DISPATCHED = 'dispatched', 'Dispatched'
        IN_PROGRESS = 'in_progress', 'In progress'
        COMPLETED = 'completed', 'Completed'
        CANCELLED = 'cancelled', 'Cancelled'

    name = models.CharField(max_length=150)
    plan_date = models.DateField()
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.DRAFT)

    driver = models.ForeignKey(
        Driver, on_delete=models.SET_NULL, null=True, blank=True, related_name='route_plans',
    )
    vehicle = models.ForeignKey(
        Vehicle, on_delete=models.SET_NULL, null=True, blank=True, related_name='route_plans',
    )
    carrier = models.ForeignKey(
        Carrier, on_delete=models.SET_NULL, null=True, blank=True, related_name='route_plans',
    )
    shipments = models.ManyToManyField(Shipment, blank=True, related_name='route_plans')

    stop_count = models.PositiveIntegerField(default=0)
    planned_distance_km = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    planned_duration_minutes = models.PositiveIntegerField(default=0)
    optimized_sequence = models.JSONField(default=list, blank=True)
    notes = models.TextField(blank=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='route_plans',
    )

    class Meta:
        ordering = ['-plan_date', 'name']

    def __str__(self):
        return f'{self.name} · {self.plan_date}'


class VehicleMaintenance(TimeStampedModel):
    """Service / repair log for a fleet vehicle."""

    class Kind(models.TextChoices):
        SERVICE = 'service', 'Routine service'
        REPAIR = 'repair', 'Repair'
        INSPECTION = 'inspection', 'Inspection'
        TYRES = 'tyres', 'Tyres'
        INSURANCE = 'insurance', 'Insurance'
        OTHER = 'other', 'Other'

    vehicle = models.ForeignKey(Vehicle, on_delete=models.CASCADE, related_name='maintenance')
    kind = models.CharField(max_length=20, choices=Kind.choices, default=Kind.SERVICE)
    performed_at = models.DateField()
    odometer_km = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    cost = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    vendor = models.CharField(max_length=255, blank=True)
    description = models.TextField(blank=True)
    next_due_at = models.DateField(null=True, blank=True)
    next_due_km = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='vehicle_maintenance',
    )

    class Meta:
        ordering = ['-performed_at']
        verbose_name_plural = 'vehicle maintenance'

    def __str__(self):
        return f'{self.vehicle.plate_number} · {self.get_kind_display()} · {self.performed_at}'
