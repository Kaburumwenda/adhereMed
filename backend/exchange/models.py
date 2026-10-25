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


# ─────────────────────────────────────────────────
# Clinic → Patient sharing
# ─────────────────────────────────────────────────
#
# The patient dashboard runs in the *patient* context (no clinic schema), while
# lab orders live inside each clinic's own schema. ``exchange`` is a SHARED_APP
# – its tables only exist in ``public`` – so it is the bridge the patient portal
# can read from.
#
# A clinic pushes a flattened snapshot of an order here whenever the order
# moves: created → sample collected → processing → completed → verified. The
# patient therefore sees the live pipeline and, once the verifier signs, the
# final released report.
#
# One row per (clinic, clinic-side order id). Re-pushing updates in place, so
# the patient never sees duplicates.


class PatientLabRecord(models.Model):
    """Read-only mirror of a clinic lab order, exposed to the patient."""

    class Stage(models.TextChoices):
        """Patient-facing stages — the clinic's internal states, simplified."""

        REQUESTED = 'requested', 'Requested'
        SAMPLE_COLLECTED = 'sample_collected', 'Sample collected'
        PROCESSING = 'processing', 'Being analysed'
        READY = 'ready', 'Report ready'
        RELEASED = 'released', 'Released to you'
        CANCELLED = 'cancelled', 'Cancelled'

    # ── Where it came from ────────────────────────────────────────────────
    source_tenant_id = models.IntegerField(
        help_text='ID of the clinic/hospital tenant that owns the order',
    )
    source_tenant_name = models.CharField(max_length=255, blank=True)
    source_order_id = models.IntegerField(
        help_text='LabOrder.id inside the source tenant schema',
    )
    order_ref = models.CharField(
        max_length=40, blank=True,
        help_text='Human readable order reference shown to the patient',
    )

    # ── Who it is for ─────────────────────────────────────────────────────
    patient_user_id = models.IntegerField(
        db_index=True, help_text='accounts.User id of the patient (public schema)',
    )
    patient_name = models.CharField(max_length=255, blank=True)
    patient_number = models.CharField(max_length=40, blank=True)

    # ── What was requested ────────────────────────────────────────────────
    tests = models.JSONField(
        default=list, blank=True,
        help_text='[{name, code, department, specimen_type}]',
    )
    priority = models.CharField(max_length=10, default='routine')
    clinical_notes = models.TextField(blank=True)
    ordered_by_name = models.CharField(max_length=255, blank=True)
    clinic_site_name = models.CharField(max_length=255, blank=True)
    is_home_collection = models.BooleanField(default=False)
    requested_on = models.DateTimeField(null=True, blank=True)

    # ── Where it is now ───────────────────────────────────────────────────
    stage = models.CharField(
        max_length=20, choices=Stage.choices, default=Stage.REQUESTED,
    )
    raw_status = models.CharField(
        max_length=20, blank=True, help_text="The clinic's own status value",
    )
    stage_updated_at = models.DateTimeField(null=True, blank=True)

    # ── The result ────────────────────────────────────────────────────────
    results = models.JSONField(
        default=list, blank=True,
        help_text='[{test_name, result_value, unit, reference_range, is_abnormal, comments}]',
    )
    result_summary = models.CharField(
        max_length=255, blank=True,
        help_text='e.g. "2 of 6 results outside the reference range"',
    )
    abnormal_count = models.PositiveSmallIntegerField(default=0)
    performed_by_name = models.CharField(max_length=255, blank=True)
    performed_at = models.DateTimeField(null=True, blank=True)
    verified_by_name = models.CharField(max_length=255, blank=True)
    verified_at = models.DateTimeField(null=True, blank=True)
    is_verified = models.BooleanField(
        default=False,
        help_text='Only verified reports are released to the patient.',
    )
    turnaround_seconds = models.PositiveIntegerField(null=True, blank=True)

    # ── Housekeeping ──────────────────────────────────────────────────────
    synced_at = models.DateTimeField(auto_now=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-requested_on', '-id']
        constraints = [
            models.UniqueConstraint(
                fields=['source_tenant_id', 'source_order_id'],
                name='uniq_patient_lab_record_per_order',
            ),
        ]
        indexes = [
            models.Index(fields=['patient_user_id', '-requested_on']),
        ]

    #: Clinic status → patient-facing stage. Verification overrides this with
    #: ``RELEASED`` because that is the moment the report becomes readable.
    CLINIC_STAGE_MAP = {
        'pending': Stage.REQUESTED,
        'sample_collected': Stage.SAMPLE_COLLECTED,
        'processing': Stage.PROCESSING,
        'completed': Stage.READY,
        'cancelled': Stage.CANCELLED,
    }

    #: Ordered pipeline, used for the progress meter and stage ordering.
    PIPELINE = [
        Stage.REQUESTED, Stage.SAMPLE_COLLECTED, Stage.PROCESSING,
        Stage.READY, Stage.RELEASED,
    ]

    @classmethod
    def stage_for(cls, raw_status, is_verified=False):
        """Resolve the patient-facing stage for a clinic status.

        Used by both the in-clinic push helper and the API sync endpoint so the
        two can never disagree.
        """
        if is_verified:
            return cls.Stage.RELEASED
        return cls.CLINIC_STAGE_MAP.get(
            (raw_status or '').strip().lower(), cls.Stage.REQUESTED,
        )

    @staticmethod
    def summarise(results):
        """Human summary of a result set — "2 of 6 results outside …"."""
        results = results or []
        if not results:
            return ''
        abnormal = sum(1 for r in results if r.get('is_abnormal'))
        count = len(results)
        plural = '' if count == 1 else 's'
        if abnormal:
            return f'{abnormal} of {count} result{plural} outside the reference range'
        return f'All {count} result{plural} within the reference range'

    def __str__(self):
        return f'Lab {self.order_ref or self.source_order_id} – {self.patient_name}'
