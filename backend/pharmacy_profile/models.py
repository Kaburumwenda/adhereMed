from django.db import models
from django.conf import settings


class PharmacyDetail(models.Model):
    name = models.CharField(max_length=255)
    logo = models.ImageField(upload_to='pharmacy_logos/', null=True, blank=True)
    license_number = models.CharField(max_length=100, blank=True)
    operating_hours = models.JSONField(default=dict, blank=True, help_text='Day-wise open/close hours')
    services = models.JSONField(default=list, blank=True, help_text='e.g., delivery, compounding')
    delivery_radius_km = models.DecimalField(max_digits=5, decimal_places=1, default=0)
    delivery_fee = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    accepts_insurance = models.BooleanField(default=False)
    insurance_providers = models.JSONField(default=list, blank=True)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Pharmacy Detail'
        verbose_name_plural = 'Pharmacy Details'

    def __str__(self):
        return self.name


class Branch(models.Model):
    name = models.CharField(max_length=255)
    address = models.TextField(blank=True)
    place_name = models.CharField(max_length=255, blank=True)
    latitude = models.DecimalField(max_digits=30, decimal_places=12, null=True, blank=True)
    longitude = models.DecimalField(max_digits=30, decimal_places=12, null=True, blank=True)
    phone = models.CharField(max_length=20, blank=True)
    email = models.EmailField(blank=True)
    is_main = models.BooleanField(default=False, help_text='Main/head branch')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name_plural = 'Branches'
        ordering = ['name']

    def __str__(self):
        return self.name


class Delivery(models.Model):
    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        ASSIGNED = 'assigned', 'Assigned'
        IN_TRANSIT = 'in_transit', 'In Transit'
        DELIVERED = 'delivered', 'Delivered'
        FAILED = 'failed', 'Failed'
        CANCELLED = 'cancelled', 'Cancelled'

    transaction = models.OneToOneField(
        'pos.POSTransaction', on_delete=models.CASCADE, related_name='delivery',
    )
    delivery_address = models.TextField()
    latitude = models.DecimalField(max_digits=30, decimal_places=12, null=True, blank=True)
    longitude = models.DecimalField(max_digits=30, decimal_places=12, null=True, blank=True)
    recipient_name = models.CharField(max_length=255)
    recipient_phone = models.CharField(max_length=20)
    delivery_fee = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    assigned_to = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='deliveries',
    )
    assigned_driver_name = models.CharField(max_length=255, blank=True)
    notes = models.TextField(blank=True)
    scheduled_at = models.DateTimeField(null=True, blank=True)
    delivered_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name_plural = 'Deliveries'

    def __str__(self):
        return f'Delivery #{self.id} - {self.get_status_display()}'
