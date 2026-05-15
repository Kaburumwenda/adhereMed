from django.db import models
from django.conf import settings


class Category(models.Model):
    name = models.CharField(max_length=100, unique=True)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']
        verbose_name_plural = 'Categories'

    def __str__(self):
        return self.name


class Unit(models.Model):
    name = models.CharField(max_length=50, unique=True, help_text='e.g. tablets, capsules, ml, mg')
    abbreviation = models.CharField(max_length=10, blank=True, help_text='e.g. tab, cap, ml')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


class MedicationStock(models.Model):
    medication_id = models.CharField(max_length=20, unique=True, blank=True, help_text='Auto-generated unique medication ID')
    medication_name = models.CharField(max_length=255, help_text='Cached from global pool')
    abbreviation = models.CharField(
        max_length=20, blank=True, db_index=True,
        help_text='Short code (e.g. PCM, AMOX) for quick POS search.',
    )
    category = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, blank=True, related_name='stocks')
    unit = models.ForeignKey(Unit, on_delete=models.SET_NULL, null=True, blank=True, related_name='stocks')
    selling_price = models.DecimalField(max_digits=10, decimal_places=2)
    cost_price = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    tax_percent = models.DecimalField(
        max_digits=5, decimal_places=2, default=0,
        help_text='VAT / tax percentage applied on cost price (0–100)',
    )
    discount_percent = models.DecimalField(
        max_digits=5, decimal_places=2, default=0,
        help_text='Default discount applied at POS, as a percentage (0–100)',
    )
    reorder_level = models.PositiveIntegerField(default=10)
    reorder_quantity = models.PositiveIntegerField(default=50)
    location_in_store = models.CharField(max_length=100, blank=True, help_text='Shelf/bin location')
    barcode = models.CharField(max_length=100, blank=True, null=True, help_text='Barcode or SKU')
    prescription_required = models.CharField(
        max_length=20,
        choices=[('none', 'None'), ('recommended', 'Recommended'), ('required', 'Required')],
        default='none',
        help_text='Whether a doctor prescription is needed',
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['medication_name']

    def save(self, *args, **kwargs):
        # Auto-fill abbreviation from the shared Medication catalog when missing
        if not self.abbreviation and self.medication_name:
            try:
                from medications.models import Medication
                key = self.medication_name.strip()
                m = (
                    Medication.objects
                    .filter(generic_name__iexact=key)
                    .exclude(abbreviation='')
                    .only('abbreviation')
                    .first()
                )
                if not m:
                    head = key.split(' ')[0] if key else ''
                    if head:
                        m = (
                            Medication.objects
                            .filter(generic_name__iexact=head)
                            .exclude(abbreviation='')
                            .only('abbreviation')
                            .first()
                        )
                if m:
                    self.abbreviation = m.abbreviation
            except Exception:
                pass

        if not self.medication_id:
            super().save(*args, **kwargs)
            self.medication_id = f'MED-{self.pk:05d}'
            kwargs['force_insert'] = False
        super().save(*args, **kwargs)

    def __str__(self):
        return self.medication_name

    @property
    def total_quantity(self):
        return sum(b.quantity_remaining for b in self.batches.filter(quantity_remaining__gt=0))

    @property
    def is_low_stock(self):
        return self.total_quantity <= self.reorder_level


class StockBatch(models.Model):
    stock = models.ForeignKey(MedicationStock, on_delete=models.CASCADE, related_name='batches')
    batch_number = models.CharField(max_length=100)
    quantity_received = models.PositiveIntegerField()
    quantity_remaining = models.PositiveIntegerField()
    cost_price_per_unit = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    expiry_date = models.DateField(null=True, blank=True)
    received_date = models.DateField(auto_now_add=True)
    supplier = models.ForeignKey(
        'suppliers.Supplier', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='batches',
    )
    branch = models.ForeignKey(
        'pharmacy_profile.Branch', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='batches',
        help_text='Physical location of this batch. Null = main / unassigned.',
    )

    class Meta:
        ordering = ['expiry_date']  # FEFO ordering

    def __str__(self):
        return f'{self.stock.medication_name} - Batch {self.batch_number} (Exp: {self.expiry_date})'

    @property
    def is_expired(self):
        from django.utils import timezone
        if not self.expiry_date:
            return False
        return self.expiry_date < timezone.now().date()


class StockAdjustment(models.Model):
    class Reason(models.TextChoices):
        DAMAGE = 'damage', 'Damage'
        THEFT = 'theft', 'Theft'
        EXPIRY = 'expiry', 'Expiry'
        COUNT_CORRECTION = 'count_correction', 'Count Correction'
        RETURN_TO_SUPPLIER = 'return_to_supplier', 'Return to Supplier'
        OTHER = 'other', 'Other'

    stock = models.ForeignKey(MedicationStock, on_delete=models.CASCADE, related_name='adjustments')
    batch = models.ForeignKey(StockBatch, on_delete=models.SET_NULL, null=True, blank=True, related_name='adjustments')
    quantity_change = models.IntegerField(help_text='Positive for additions, negative for removals')
    reason = models.CharField(max_length=30, choices=Reason.choices)
    notes = models.TextField(blank=True)
    adjusted_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name='stock_adjustments',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.stock.medication_name} {self.quantity_change:+d} ({self.get_reason_display()})'


# ─────────────────────────────────────────────────────────────────────────
#  Stock Take (cycle count)
# ─────────────────────────────────────────────────────────────────────────
class InventoryCount(models.Model):
    class Status(models.TextChoices):
        DRAFT = 'draft', 'Draft'
        IN_PROGRESS = 'in_progress', 'In Progress'
        COMPLETED = 'completed', 'Completed'
        CANCELLED = 'cancelled', 'Cancelled'

    reference = models.CharField(max_length=30, unique=True, blank=True)
    name = models.CharField(max_length=255, help_text='e.g. "Monthly count - May 2026"')
    branch = models.ForeignKey(
        'pharmacy_profile.Branch', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='inventory_counts',
    )
    category = models.ForeignKey(
        Category, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='inventory_counts',
        help_text='Optional: limit count to a single category',
    )
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.DRAFT)
    notes = models.TextField(blank=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='created_counts',
    )
    completed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='completed_counts',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    def save(self, *args, **kwargs):
        if not self.reference:
            super().save(*args, **kwargs)
            self.reference = f'CNT-{self.pk:05d}'
            kwargs['force_insert'] = False
        super().save(*args, **kwargs)

    @property
    def total_variance(self):
        return sum(line.variance for line in self.lines.all())

    @property
    def total_variance_value(self):
        return sum(line.variance_value for line in self.lines.all())

    def __str__(self):
        return f'{self.reference} · {self.name}'


class InventoryCountLine(models.Model):
    count = models.ForeignKey(InventoryCount, on_delete=models.CASCADE, related_name='lines')
    stock = models.ForeignKey(MedicationStock, on_delete=models.CASCADE, related_name='count_lines')
    expected_quantity = models.IntegerField(default=0, help_text='System qty at the time the sheet was generated')
    counted_quantity = models.IntegerField(null=True, blank=True, help_text='Physical count')
    notes = models.CharField(max_length=255, blank=True)

    class Meta:
        ordering = ['stock__medication_name']
        unique_together = [('count', 'stock')]

    @property
    def variance(self):
        if self.counted_quantity is None:
            return 0
        return self.counted_quantity - self.expected_quantity

    @property
    def variance_value(self):
        from decimal import Decimal
        return Decimal(self.variance) * (self.stock.cost_price or Decimal(0))


# ─────────────────────────────────────────────────────────────────────────
#  Branch-to-branch Stock Transfer
# ─────────────────────────────────────────────────────────────────────────
class StockTransfer(models.Model):
    class Status(models.TextChoices):
        DRAFT = 'draft', 'Draft'
        REQUESTED = 'requested', 'Requested'
        APPROVED = 'approved', 'Approved'
        IN_TRANSIT = 'in_transit', 'In Transit'
        COMPLETED = 'completed', 'Completed'
        CANCELLED = 'cancelled', 'Cancelled'

    reference = models.CharField(max_length=30, unique=True, blank=True)
    source_branch = models.ForeignKey(
        'pharmacy_profile.Branch', on_delete=models.PROTECT,
        related_name='transfers_out',
    )
    dest_branch = models.ForeignKey(
        'pharmacy_profile.Branch', on_delete=models.PROTECT,
        related_name='transfers_in',
    )
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.DRAFT)
    notes = models.TextField(blank=True)
    requested_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='requested_transfers',
    )
    approved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='approved_transfers',
    )
    received_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='received_transfers',
    )
    requested_at = models.DateTimeField(auto_now_add=True)
    shipped_at = models.DateTimeField(null=True, blank=True)
    received_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-requested_at']

    def save(self, *args, **kwargs):
        if not self.reference:
            super().save(*args, **kwargs)
            self.reference = f'TRF-{self.pk:05d}'
            kwargs['force_insert'] = False
        super().save(*args, **kwargs)

    @property
    def total_items(self):
        return self.lines.count()

    @property
    def total_quantity(self):
        return sum(l.quantity for l in self.lines.all())

    def __str__(self):
        return f'{self.reference} · {self.source_branch} → {self.dest_branch}'


class StockTransferLine(models.Model):
    transfer = models.ForeignKey(StockTransfer, on_delete=models.CASCADE, related_name='lines')
    stock = models.ForeignKey(MedicationStock, on_delete=models.CASCADE, related_name='transfer_lines')
    quantity = models.PositiveIntegerField()
    quantity_received = models.PositiveIntegerField(default=0, help_text='How much actually arrived')
    notes = models.CharField(max_length=255, blank=True)

    class Meta:
        ordering = ['stock__medication_name']

    @property
    def variance(self):
        return self.quantity_received - self.quantity


# ─────────────────────────────────────────────────────────────────────────
#  Controlled Substance Register (regulatory compliance)
# ─────────────────────────────────────────────────────────────────────────
class ControlledSubstanceLog(models.Model):
    class Action(models.TextChoices):
        DISPENSED = 'dispensed', 'Dispensed'
        RECEIVED = 'received', 'Received'
        ADJUSTED = 'adjusted', 'Adjusted'
        DESTROYED = 'destroyed', 'Destroyed'
        TRANSFERRED = 'transferred', 'Transferred'
        RETURNED = 'returned', 'Returned'

    medication_name = models.CharField(max_length=255)
    schedule = models.CharField(max_length=20, blank=True, help_text='e.g. Schedule II, III')
    action = models.CharField(max_length=20, choices=Action.choices)
    quantity = models.DecimalField(max_digits=12, decimal_places=2)
    balance_after = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    batch_number = models.CharField(max_length=100, blank=True)

    # Patient + prescriber details (for dispensed)
    patient_name = models.CharField(max_length=255, blank=True)
    patient_id_number = models.CharField(max_length=50, blank=True, help_text='National ID, passport, etc.')
    prescriber_name = models.CharField(max_length=255, blank=True)
    prescription_reference = models.CharField(max_length=100, blank=True)

    # Source document
    source_type = models.CharField(max_length=30, blank=True, help_text='dispense, adjustment, transfer, etc.')
    source_id = models.IntegerField(null=True, blank=True)

    notes = models.TextField(blank=True)
    recorded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='controlled_logs',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['medication_name', '-created_at']),
            models.Index(fields=['action', '-created_at']),
        ]

    def __str__(self):
        return f'{self.medication_name} {self.get_action_display()} {self.quantity} @ {self.created_at:%Y-%m-%d}'

