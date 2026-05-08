import uuid
from django.db import models


class PrescriptionExchange(models.Model):
    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        QUOTED = 'quoted', 'Quoted'
        ACCEPTED = 'accepted', 'Accepted'
        COMPLETED = 'completed', 'Completed'
        EXPIRED = 'expired', 'Expired'
        CANCELLED = 'cancelled', 'Cancelled'

    hospital_tenant_id = models.IntegerField(help_text='ID of the hospital tenant')
    source_tenant_type = models.CharField(
        max_length=20, default='hospital',
        help_text="'hospital' or 'homecare' — origin of this prescription",
    )
    patient_user_id = models.IntegerField(help_text='ID of the patient user')
    prescription_ref = models.CharField(max_length=100)
    items = models.JSONField(help_text='List of medication items with dosage info')
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    selected_pharmacy_tenant_id = models.IntegerField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'Exchange #{self.id} - {self.prescription_ref}'


class PharmacyQuote(models.Model):
    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        QUOTED = 'quoted', 'Quoted'
        ACCEPTED = 'accepted', 'Accepted'
        REJECTED = 'rejected', 'Rejected'
        EXPIRED = 'expired', 'Expired'

    exchange = models.ForeignKey(
        PrescriptionExchange,
        on_delete=models.CASCADE,
        related_name='quotes',
    )
    pharmacy_tenant_id = models.IntegerField()
    pharmacy_name = models.CharField(max_length=255)
    items_pricing = models.JSONField(help_text='Per-item pricing: [{medication_id, name, qty, unit_price, total}]')
    subtotal = models.DecimalField(max_digits=12, decimal_places=2)
    delivery_available = models.BooleanField(default=False)
    delivery_fee = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    total_cost = models.DecimalField(max_digits=12, decimal_places=2)
    valid_until = models.DateTimeField()
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['total_cost']

    def __str__(self):
        return f'{self.pharmacy_name} - KSh {self.total_cost}'


class PatientOrder(models.Model):
    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        CONFIRMED = 'confirmed', 'Confirmed'
        PROCESSING = 'processing', 'Processing'
        READY = 'ready', 'Ready for Pickup/Delivery'
        COMPLETED = 'completed', 'Completed'
        CANCELLED = 'cancelled', 'Cancelled'

    class PaymentMethod(models.TextChoices):
        CASH = 'cash', 'Cash on Delivery'
        MPESA = 'mpesa', 'M-Pesa'

    order_number = models.CharField(max_length=20, unique=True, editable=False)
    patient_user_id = models.IntegerField(help_text='ID of the patient user')
    patient_name = models.CharField(max_length=255)
    patient_phone = models.CharField(max_length=20, blank=True)
    pharmacy_tenant_id = models.IntegerField()
    pharmacy_name = models.CharField(max_length=255)
    items = models.JSONField(
        help_text='[{medication_name, quantity, unit_price, total}]'
    )
    subtotal = models.DecimalField(max_digits=12, decimal_places=2)
    delivery_fee = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    total = models.DecimalField(max_digits=12, decimal_places=2)
    delivery_address = models.TextField(blank=True)
    payment_method = models.CharField(
        max_length=20, choices=PaymentMethod.choices, default=PaymentMethod.CASH,
    )
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'Order {self.order_number} - {self.pharmacy_name}'

    def save(self, *args, **kwargs):
        if not self.order_number:
            self.order_number = f'ORD-{uuid.uuid4().hex[:8].upper()}'
        super().save(*args, **kwargs)


# ─────────────────────────────────────────────────
# Lab Exchange – hospitals/doctors send test requests
# to independent lab tenants
# ─────────────────────────────────────────────────

class LabOrderExchange(models.Model):
    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        ACCEPTED = 'accepted', 'Accepted'
        SAMPLE_COLLECTED = 'sample_collected', 'Sample Collected'
        PROCESSING = 'processing', 'Processing'
        COMPLETED = 'completed', 'Completed'
        CANCELLED = 'cancelled', 'Cancelled'

    class Priority(models.TextChoices):
        ROUTINE = 'routine', 'Routine'
        URGENT = 'urgent', 'Urgent'
        STAT = 'stat', 'STAT'

    # Source info (hospital/doctor that ordered)
    source_tenant_id = models.IntegerField(
        help_text='ID of the hospital tenant that created the order',
    )
    source_tenant_name = models.CharField(max_length=255, blank=True)
    ordering_doctor_name = models.CharField(max_length=255, blank=True)
    ordering_doctor_user_id = models.IntegerField(null=True, blank=True)

    # Patient info (denormalised – cross‑schema)
    patient_user_id = models.IntegerField(help_text='ID of the patient user')
    patient_name = models.CharField(max_length=255)
    patient_phone = models.CharField(max_length=20, blank=True)

    # Lab request details
    tests = models.JSONField(
        help_text='[{test_name, code, specimen_type, instructions}]',
    )
    priority = models.CharField(
        max_length=10, choices=Priority.choices, default=Priority.ROUTINE,
    )
    clinical_notes = models.TextField(blank=True)
    is_home_collection = models.BooleanField(default=False)
    collection_address = models.TextField(blank=True)

    # Accepting lab
    lab_tenant_id = models.IntegerField(null=True, blank=True)
    lab_tenant_name = models.CharField(max_length=255, blank=True)

    # Results (JSON blob returned by the lab)
    results = models.JSONField(
        null=True, blank=True,
        help_text='[{test_name, result_value, unit, is_abnormal, comments}]',
    )

    status = models.CharField(
        max_length=20, choices=Status.choices, default=Status.PENDING,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'LabExchange #{self.id} – {self.patient_name}'
