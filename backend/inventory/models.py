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


class Classification(models.Model):
    """User-managed lookup controlling how a stock item is treated
    operationally (e.g. Routine, Emergency, Cold Chain, Controlled).

    A default "Routine" classification is seeded for every tenant so new
    stock items can be classified without any extra setup. Tenants can
    add more classifications to fit how their warehouse is organised.
    """
    name = models.CharField(max_length=100, unique=True)
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']
        verbose_name_plural = 'Classifications'

    def __str__(self):
        return self.name


def _default_classification_id():
    """Return the pk of this tenant's "Routine" classification, creating
    it lazily so new MedicationStock rows default to "Routine" even on a
    fresh tenant schema that has no classification rows yet."""
    obj, _ = Classification.objects.get_or_create(name='Routine')
    return obj.pk


class MedicationStock(models.Model):
    medication_id = models.CharField(max_length=20, unique=True, blank=True, help_text='Auto-generated unique medication ID')
    medication_name = models.CharField(max_length=255, help_text='Cached from global pool')
    abbreviation = models.CharField(
        max_length=20, blank=True, db_index=True,
        help_text='Short code (e.g. PCM, AMOX) for quick POS search.',
    )
    brand_name = models.CharField(max_length=255, blank=True, default='', help_text='Brand / trade name for this medication item')
    generic_name = models.CharField(max_length=255, blank=True, default='', help_text='Generic name cached from Medication catalog')
    strength = models.CharField(max_length=100, blank=True, default='', help_text='Strength cached from Medication catalog')
    dosage_form = models.CharField(max_length=20, blank=True, default='', help_text='Dosage form cached from Medication catalog')
    category = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, blank=True, related_name='stocks')
    unit = models.ForeignKey(Unit, on_delete=models.SET_NULL, null=True, blank=True, related_name='stocks')
    classification = models.ForeignKey(
        Classification, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='stocks',
        default=_default_classification_id,
        help_text='Operational classification (Routine, Emergency, Cold Chain, …). '
                  'Defaults to "Routine" when left blank.',
    )
    branch = models.ForeignKey(
        'pharmacy_profile.Branch', on_delete=models.PROTECT,
        null=False, blank=False, related_name='stocks',
        help_text='Warehouse this stock item belongs to (required)',
    )
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
    items_per_unit = models.PositiveIntegerField(
        default=0,
        help_text='How many individual items are inside one box/pack/strip of this stock item. '
                  'Only meaningful when the unit is a container type (e.g. box, pack, strip).',
    )
    is_active = models.BooleanField(default=True)
    committed_qty = models.PositiveIntegerField(
        default=0,
        help_text='Quantity reserved by paid/partially-paid sales orders (not yet delivered)',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['medication_name']

    def save(self, *args, **kwargs):
        # Auto-fill abbreviation and medication fields from the shared catalog
        if self.medication_name:
            try:
                from medications.models import Medication
                key = self.medication_name.strip()
                m = (
                    Medication.objects
                    .filter(generic_name__iexact=key)
                    .only('abbreviation', 'brand_names', 'generic_name', 'strength', 'dosage_form')
                    .first()
                )
                if not m:
                    head = key.split(' ')[0] if key else ''
                    if head:
                        m = (
                            Medication.objects
                            .filter(generic_name__iexact=head)
                            .only('abbreviation', 'brand_names', 'generic_name', 'strength', 'dosage_form')
                            .first()
                        )
                if not m:
                    # Try matching by brand name in brand_names JSON array
                    meds = (
                        Medication.objects
                        .filter(brand_names__contains=[key])
                        .only('abbreviation', 'brand_names', 'generic_name', 'strength', 'dosage_form')
                        [:1]
                    )
                    if meds:
                        m = meds[0]
                if m:
                    if not self.abbreviation and m.abbreviation:
                        self.abbreviation = m.abbreviation
                    if not self.generic_name and m.generic_name:
                        self.generic_name = m.generic_name
                    if not self.strength and m.strength:
                        self.strength = m.strength
                    if not self.dosage_form and m.dosage_form:
                        self.dosage_form = m.dosage_form
                    if not self.brand_name and m.brand_names:
                        self.brand_name = m.brand_names[0] if isinstance(m.brand_names, list) else str(m.brand_names)
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
    def available_quantity(self):
        """Physical stock minus quantities committed to sales orders."""
        return max(0, self.total_quantity - (self.committed_qty or 0))

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
        SALES_ORDER = 'sales_order', 'Sales Order Fulfilment'
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

    # ── Cargo & scheduling (optional, populated from the wizard) ──
    class Priority(models.TextChoices):
        LOW = 'low', 'Low'
        NORMAL = 'normal', 'Normal'
        HIGH = 'high', 'High'
        URGENT = 'urgent', 'Urgent'

    priority = models.CharField(
        max_length=10, choices=Priority.choices, default=Priority.NORMAL,
    )
    parcel_count = models.PositiveIntegerField(null=True, blank=True)
    weight_kg = models.DecimalField(
        max_digits=10, decimal_places=2, null=True, blank=True,
    )
    scheduled_pickup = models.DateTimeField(null=True, blank=True)
    scheduled_delivery = models.DateTimeField(null=True, blank=True)

    # ── Assignment (nullable links to the logistics fleet) ──
    assigned_driver = models.ForeignKey(
        'logistics.Driver', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='stock_transfers',
    )
    assigned_carrier = models.ForeignKey(
        'logistics.Carrier', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='stock_transfers',
    )
    assigned_vehicle = models.ForeignKey(
        'logistics.Vehicle', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='stock_transfers',
    )
    assigned_vehicle_note = models.CharField(
        max_length=255, blank=True,
        help_text='Free-text vehicle description when no fleet vehicle is linked.',
    )

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

    # ── Digital signatures (captured in the approve / receive dialogs) ──
    # Stored as base64 PNG data-URLs, mirroring homecare.Consent so the whole
    # platform uses a single signature representation.
    approved_signature = models.TextField(
        blank=True, default='',
        help_text="Base64 data-URL of the approver's captured signature (PNG).",
    )
    received_signature = models.TextField(
        blank=True, default='',
        help_text="Base64 data-URL of the receiver's captured signature (PNG).",
    )

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
    batch = models.ForeignKey(
        StockBatch, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='transfer_lines',
        help_text='Optional: specific source batch to deduct from. '
                  'When null, the approver drains batches FEFO.',
    )
    quantity = models.PositiveIntegerField()
    quantity_received = models.PositiveIntegerField(default=0, help_text='How much actually arrived')
    notes = models.CharField(max_length=255, blank=True)

    class Meta:
        ordering = ['stock__medication_name']

    @property
    def variance(self):
        return self.quantity_received - self.quantity


# ─────────────────────────────────────────────────────────────────────────
#  RBAC: tenant-defined custom roles (Roles & Access admin page)
# ─────────────────────────────────────────────────────────────────────────
class RoleDefinition(models.Model):
    """A tenant-managed role definition.

    * custom roles (is_system=False): tenant-created roles with an explicit
      capability list;
    * built-in overrides (is_system=True): a tenant's customized capability
      list for a built-in role (e.g. trimmed Storekeeper powers). The `key`
      matches the built-in role key on User.role. Deleting the row restores
      the platform defaults.

    The `key` is stored on User.role, so it must stay short (max 20 chars)
    and cannot collide with the built-in role keys enforced in rbac.py.
    """
    key = models.SlugField(max_length=20, unique=True)
    label = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    icon = models.CharField(max_length=50, default='mdi-badge-account-horizontal-outline')
    capabilities = models.JSONField(default=list, help_text='List of capability keys (see rbac.py)')
    is_system = models.BooleanField(
        default=False,
        help_text='True = capability override for a built-in role')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['label']
        verbose_name = 'Role definition'
        verbose_name_plural = 'Role definitions'

    def __str__(self):
        return f'{self.label} ({len(self.capabilities or [])} capabilities)'


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


# ─────────────────────────────────────────────────────────────────────────
#  Catalog seed run history (persisted audit of seed operations)
# ─────────────────────────────────────────────────────────────────────────
class CatalogSeedRun(models.Model):
    """One executed catalog-seed command inside this tenant.

    The clinic Catalog → Seed Data page used to keep its run history in
    component state only, so reloading the page lost everything. This
    model persists each attempt (success or failure) so the page can show
    a durable, auditable history of what was seeded, by whom and when.
    """

    class Status(models.TextChoices):
        SUCCESS = 'success', 'Success'
        FAILED = 'failed', 'Failed'

    command_key = models.CharField(max_length=50, db_index=True,
                                   help_text='Seed key, e.g. categories_units')
    label = models.CharField(max_length=150, blank=True,
                             help_text='Human-readable label at run time')
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.SUCCESS)
    detail = models.TextField(blank=True, help_text='Success message or error trace')
    duration_ms = models.PositiveIntegerField(default=0)
    records_created = models.PositiveIntegerField(default=0)
    run_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='catalog_seed_runs',
    )
    run_by_label = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['command_key', '-created_at']),
            models.Index(fields=['status', '-created_at']),
        ]
        verbose_name = 'Catalog Seed Run'
        verbose_name_plural = 'Catalog Seed Runs'

    def __str__(self):
        return f'{self.command_key} · {self.status} @ {self.created_at:%Y-%m-%d %H:%M}'

