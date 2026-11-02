from django.db import models
from django.conf import settings
from django.db.models import Q, Sum
from django.db.models.functions import Coalesce, Lower
from django.utils import timezone


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


class MedicationStockQuerySet(models.QuerySet):
    """Adds the batch aggregates the model properties need.

    Without this, ``total_quantity`` / ``is_low_stock`` issued up to three
    queries *per stock row* because a ``.filter()`` on the related manager
    ignores the ``prefetch_related('batches')`` cache. Annotating in SQL
    collapses that to zero extra queries.
    """

    def with_quantities(self):
        today = timezone.localdate()
        # A batch is *sellable* when it still has units, is not expired and
        # has not been quarantined by auto-quarantine or a recall.
        sellable_q = (
            Q(batches__quantity_remaining__gt=0)
            & Q(batches__is_blocked=False)
            & (Q(batches__expiry_date__gte=today)
               | Q(batches__expiry_date__isnull=True))
        )
        return self.annotate(
            annotated_total_quantity=Coalesce(
                Sum('batches__quantity_remaining',
                    filter=Q(batches__quantity_remaining__gt=0)), 0),
            annotated_expired_quantity=Coalesce(
                Sum('batches__quantity_remaining',
                    filter=Q(batches__quantity_remaining__gt=0,
                             batches__expiry_date__lt=today)), 0),
            annotated_blocked_quantity=Coalesce(
                Sum('batches__quantity_remaining',
                    filter=Q(batches__quantity_remaining__gt=0,
                             batches__is_blocked=True)), 0),
            annotated_sellable_quantity=Coalesce(
                Sum('batches__quantity_remaining', filter=sellable_q), 0),
        )


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

    objects = MedicationStockQuerySet.as_manager()

    class Meta:
        ordering = ['medication_name']
        indexes = [
            models.Index(fields=['branch', 'medication_name'],
                         name='inv_stock_branch_name_idx'),
            models.Index(fields=['barcode'], name='inv_stock_barcode_idx'),
            models.Index(fields=['is_active', 'branch'],
                         name='inv_stock_active_branch_idx'),
        ]
        constraints = [
            # One item per warehouse per name+strength. The serializer already
            # enforced this; the DB constraint stops imports, transfers and
            # concurrent requests from creating duplicates.
            models.UniqueConstraint(
                Lower('medication_name'),
                Lower('strength'),
                'branch',
                name='uniq_inv_stock_branch_name_strength',
            ),
        ]

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

    # ── Quantity helpers ─────────────────────────────────────────────────
    # These are used on every list/detail/serializer call, so they must never
    # fire an extra query per row:
    #   1. a queryset annotation (``annotated_total_quantity`` /
    #      ``annotated_sellable_quantity``) wins when present,
    #   2. otherwise the prefetch cache of ``batches`` is used,
    #   3. otherwise a single related query is issued.
    def _loaded_batches(self):
        cache = getattr(self, '_prefetched_objects_cache', None)
        if cache and 'batches' in cache:
            return cache['batches']
        return list(self.batches.all())

    @property
    def total_quantity(self):
        """Physical units on hand, including expired stock."""
        annotated = getattr(self, 'annotated_total_quantity', None)
        if annotated is not None:
            return int(annotated)
        return sum(b.quantity_remaining or 0 for b in self._loaded_batches())

    @property
    def expired_quantity(self):
        """Units on hand whose batch has already expired."""
        annotated = getattr(self, 'annotated_expired_quantity', None)
        if annotated is not None:
            return int(annotated)
        today = timezone.localdate()
        return sum(
            b.quantity_remaining or 0
            for b in self._loaded_batches()
            if b.expiry_date and b.expiry_date < today
        )

    @property
    def blocked_quantity(self):
        """Units quarantined by auto-quarantine or a recall."""
        annotated = getattr(self, 'annotated_blocked_quantity', None)
        if annotated is not None:
            return int(annotated)
        return sum(
            b.quantity_remaining or 0
            for b in self._loaded_batches()
            if b.is_blocked and (b.quantity_remaining or 0) > 0
        )

    @property
    def sellable_quantity(self):
        """Units that may still be sold (on hand minus expired/blocked)."""
        annotated = getattr(self, 'annotated_sellable_quantity', None)
        if annotated is not None:
            return int(annotated)
        today = timezone.localdate()
        return sum(
            b.quantity_remaining or 0
            for b in self._loaded_batches()
            if (b.quantity_remaining or 0) > 0
            and not b.is_blocked
            and (b.expiry_date is None or b.expiry_date >= today)
        )

    @property
    def available_quantity(self):
        """Sellable stock minus quantities committed to sales orders."""
        return max(0, self.sellable_quantity - (self.committed_qty or 0))

    @property
    def is_low_stock(self):
        """True when the *sellable* quantity has hit the reorder level.

        Expired units are excluded: keeping them in the comparison let a
        shelf of expired stock hide a real shortage.
        """
        return self.available_quantity <= self.reorder_level


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

    # ── Quarantine ──────────────────────────────────────────────────────
    is_blocked = models.BooleanField(
        default=False, db_index=True,
        help_text='Quarantined: excluded from sellable stock and allocation. '
                  'Set by auto-quarantine (expired) or a recall.')
    blocked_reason = models.CharField(max_length=255, blank=True)
    blocked_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['expiry_date']  # FEFO ordering
        indexes = [
            models.Index(fields=['stock', 'expiry_date'],
                         name='inv_batch_stock_expiry_idx'),
            models.Index(fields=['branch', 'expiry_date'],
                         name='inv_batch_branch_expiry_idx'),
            models.Index(fields=['expiry_date', 'quantity_remaining'],
                         name='inv_batch_expiry_remaining_idx'),
            models.Index(fields=['is_blocked', 'expiry_date'],
                         name='inv_batch_blocked_expiry_idx'),
        ]

    def __str__(self):
        return f'{self.stock.medication_name} - Batch {self.batch_number} (Exp: {self.expiry_date})'

    @property
    def is_expired(self):
        from django.utils import timezone
        if not self.expiry_date:
            return False
        return self.expiry_date < timezone.now().date()

    @property
    def days_to_expiry(self):
        if not self.expiry_date:
            return None
        return (self.expiry_date - timezone.localdate()).days


class StockAdjustment(models.Model):
    class Reason(models.TextChoices):
        DAMAGE = 'damage', 'Damage'
        THEFT = 'theft', 'Theft'
        EXPIRY = 'expiry', 'Expiry'
        COUNT_CORRECTION = 'count_correction', 'Count Correction'
        RETURN_TO_SUPPLIER = 'return_to_supplier', 'Return to Supplier'
        SALES_ORDER = 'sales_order', 'Sales Order Fulfilment'
        OTHER = 'other', 'Other'
        # Written by the sales channels themselves. Reports that already
        # enumerate POS receipts / dispensing records must skip these rows or
        # every unit is counted twice — see CHANNEL_ADJUSTMENT_REASONS.
        POS_SALE = 'pos_sale', 'POS Sale'
        DISPENSING = 'dispensing', 'Dispensing'
        DISPENSE_RETURN = 'dispense_return', 'Dispense Return'
        TRANSFER_SHORTAGE = 'transfer_shortage', 'Transfer Shortage'

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
        indexes = [
            models.Index(fields=['stock', '-created_at'],
                         name='inv_adj_stock_created_idx'),
            models.Index(fields=['created_at'], name='inv_adj_created_idx'),
            models.Index(fields=['reason', '-created_at'],
                         name='inv_adj_reason_created_idx'),
        ]

    def __str__(self):
        return f'{self.stock.medication_name} {self.quantity_change:+d} ({self.get_reason_display()})'


#: Ledger reasons written by a sales channel that has its *own* enumerator in
#: the reports. Anything summing ``StockAdjustment`` alongside POS/dispensing
#: rows must exclude these to avoid double counting.
CHANNEL_ADJUSTMENT_REASONS = ('pos_sale', 'dispensing', 'dispense_return')


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
        indexes = [
            models.Index(fields=['status', '-created_at'],
                         name='inv_count_status_created_idx'),
            models.Index(fields=['branch', 'status'],
                         name='inv_count_branch_status_idx'),
        ]

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
        indexes = [
            models.Index(fields=['status', '-requested_at'],
                         name='inv_trf_status_requested_idx'),
            models.Index(fields=['source_branch', '-requested_at'],
                         name='inv_trf_source_requested_idx'),
            models.Index(fields=['dest_branch', '-requested_at'],
                         name='inv_trf_dest_requested_idx'),
        ]

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
    batches_deducted = models.JSONField(
        default=list, blank=True,
        help_text='Lots drained at approval: [{batch_id, batch_number, expiry_date, '
                  'cost_price_per_unit, supplier_id, branch_id, qty}]. Receiving books '
                  'the real expiry/supplier from this snapshot - the source lot is '
                  'usually at zero by then.',
    )
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


# ═══════════════════════════════════════════════════════════════════════
#  Premium inventory layer — planning, traceability, execution, finance
#
#  Everything below is tenant-only (lives in each tenant schema) and is
#  driven by ``inventory/tasks.py`` (nightly) plus the planning APIs.
# ═══════════════════════════════════════════════════════════════════════


class InventorySettings(models.Model):
    """Per-tenant inventory policy switches (singleton row).

    Kept as a single row so the nightly jobs and the UI read one source of
    truth instead of scattering magic numbers through the codebase.
    """

    class ValuationMethod(models.TextChoices):
        WEIGHTED_AVERAGE = 'weighted_average', 'Weighted average'
        FIFO = 'fifo', 'FIFO'
        BATCH_COST = 'batch_cost', 'Batch cost (per-batch actual)'

    # ── Alerting ────────────────────────────────────────────────────────
    expiry_alert_days = models.JSONField(
        default=list, blank=True,
        help_text='Days-before-expiry ladder, e.g. [90, 60, 30, 14, 7, 1].')
    auto_quarantine_expired = models.BooleanField(
        default=True,
        help_text='Block expired batches from allocation/issuing automatically.')
    low_stock_notify = models.BooleanField(default=True)
    stale_days = models.PositiveIntegerField(
        default=90, help_text='Days without movement before an item is "stale".')

    # ── Replenishment ───────────────────────────────────────────────────
    service_level = models.PositiveSmallIntegerField(
        default=95, help_text='Target service level (%) used for safety stock.')
    default_lead_time_days = models.PositiveIntegerField(default=14)
    auto_draft_purchase_orders = models.BooleanField(
        default=False,
        help_text='Nightly replenishment also drafts (never sends) POs.')
    forecast_days = models.PositiveIntegerField(default=30)
    forecast_min_history_days = models.PositiveIntegerField(
        default=14, help_text='Below this many days of history we fall back to the naive average.')

    # ── Cycle counting (ABC cadence, in days) ───────────────────────────
    count_cadence_a = models.PositiveIntegerField(default=30)
    count_cadence_b = models.PositiveIntegerField(default=90)
    count_cadence_c = models.PositiveIntegerField(default=365)

    # ── Finance ─────────────────────────────────────────────────────────
    valuation_method = models.CharField(
        max_length=20, choices=ValuationMethod.choices,
        default=ValuationMethod.WEIGHTED_AVERAGE)
    writeoff_approval_threshold = models.DecimalField(
        max_digits=14, decimal_places=2, default=0,
        help_text='Damage/write-off value above this needs supervisor approval (0 = never).')

    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Inventory settings'
        verbose_name_plural = 'Inventory settings'

    def save(self, *args, **kwargs):
        self.pk = 1
        super().save(*args, **kwargs)

    @classmethod
    def get(cls):
        obj, _ = cls.objects.get_or_create(pk=1)
        if not obj.expiry_alert_days:
            obj.expiry_alert_days = [90, 60, 30, 14, 7, 1]
            obj.save(update_fields=['expiry_alert_days'])
        return obj

    def __str__(self):
        return f'Inventory settings (service level {self.service_level}%)'


class StockPolicy(models.Model):
    """Planning parameters for one stock item in one warehouse.

    Holds the statistical reorder point, safety stock, EOQ and the ABC/XYZ
    classification. The nightly planner recomputes the numbers; the UI lets
    a planner override any of them (``is_manual_*`` flags preserve intent).
    """
    class ABC(models.TextChoices):
        A = 'A', 'A — high value'
        B = 'B', 'B — mid value'
        C = 'C', 'C — long tail'

    class XYZ(models.TextChoices):
        X = 'X', 'X — stable demand'
        Y = 'Y', 'Y — seasonal / variable'
        Z = 'Z', 'Z — erratic'

    stock = models.OneToOneField(
        MedicationStock, on_delete=models.CASCADE, related_name='policy')

    # ── Demand & lead time ──────────────────────────────────────────────
    avg_daily_demand = models.FloatField(default=0)
    demand_stddev = models.FloatField(default=0)
    lead_time_days = models.PositiveIntegerField(
        default=0, help_text='Measured from PO → GRN; 0 = use the tenant default.')
    lead_time_stddev = models.FloatField(default=0)

    # ── Derived targets ─────────────────────────────────────────────────
    safety_stock = models.FloatField(default=0)
    reorder_point = models.FloatField(default=0)
    eoq = models.FloatField(default=0, help_text='Economic order quantity.')
    order_multiple = models.PositiveIntegerField(
        default=1, help_text='Round order quantities up to this pack size.')
    min_qty = models.PositiveIntegerField(default=0)
    max_qty = models.PositiveIntegerField(default=0)
    service_level = models.PositiveSmallIntegerField(default=95)

    is_manual_lead_time = models.BooleanField(default=False)
    is_manual_reorder_point = models.BooleanField(default=False)
    is_manual_service_level = models.BooleanField(default=False)

    # ── Classification ──────────────────────────────────────────────────
    abc_class = models.CharField(max_length=1, choices=ABC.choices, default=ABC.C)
    xyz_class = models.CharField(max_length=1, choices=XYZ.choices, default=XYZ.X)
    value_share = models.FloatField(default=0, help_text='Share of total capital (0–1).')
    forecast_mape = models.FloatField(
        null=True, blank=True,
        help_text='Rolling mean absolute %% error of this item\'s forecast.')

    # ── Quality / storage ───────────────────────────────────────────────
    is_quarantined = models.BooleanField(default=False)
    quarantine_reason = models.CharField(max_length=255, blank=True)
    quarantine_case = models.ForeignKey(
        'inventory.RecallCase', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='quarantined_stocks')
    storage_zone = models.ForeignKey(
        'inventory.StorageZone', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='policies')

    # ── Cycle counting ──────────────────────────────────────────────────
    last_counted_at = models.DateTimeField(null=True, blank=True)
    next_count_due = models.DateField(null=True, blank=True)

    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Stock policy'
        verbose_name_plural = 'Stock policies'
        indexes = [
            models.Index(fields=['abc_class', 'next_count_due']),
            models.Index(fields=['is_quarantined']),
        ]

    def __str__(self):
        return f'{self.stock.medication_name} · ROP {self.reorder_point:.0f}'


class DemandForecast(models.Model):
    """A stored forecast point for one item / warehouse / day.

    Storing (rather than recomputing per request) lets us show forecast
    accuracy over time: MAPE is only meaningful once predictions are
    persisted and later compared with actuals.
    """
    class Method(models.TextChoices):
        MOVING_AVERAGE = 'moving_average', 'Moving average'
        WEIGHTED = 'weighted', 'Weighted moving average'
        HOLT_WINTERS = 'holt_winters', 'Holt-Winters'
        NAIVE = 'naive', 'Naive (history average)'

    stock = models.ForeignKey(
        MedicationStock, on_delete=models.CASCADE, related_name='forecasts')
    branch = models.ForeignKey(
        'pharmacy_profile.Branch', on_delete=models.CASCADE,
        null=True, blank=True, related_name='forecasts')
    forecast_date = models.DateField(
        help_text='The day being forecast (today + horizon).')
    horizon_days = models.PositiveIntegerField(default=1)
    predicted_qty = models.FloatField(default=0)
    method = models.CharField(max_length=20, choices=Method.choices,
                              default=Method.MOVING_AVERAGE)
    confidence = models.FloatField(default=0, help_text='0–1 heuristic confidence.')
    mape = models.FloatField(null=True, blank=True,
                             help_text='Mean absolute %% error once the day is in the past.')
    actual_qty = models.FloatField(null=True, blank=True)
    generated_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['forecast_date']
        indexes = [
            models.Index(fields=['stock', 'forecast_date']),
            models.Index(fields=['branch', 'forecast_date']),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=['stock', 'branch', 'forecast_date'],
                name='uniq_forecast_stock_branch_date'),
        ]

    def __str__(self):
        return f'{self.stock.medication_name} {self.forecast_date} = {self.predicted_qty:.1f}'


# ─────────────────────────────────────────────────────────────────────────
#  Tier 3 — Traceability, cold chain and recalls
# ─────────────────────────────────────────────────────────────────────────
class StorageZone(models.Model):
    """A physical storage area with a temperature band (cold chain)."""
    name = models.CharField(max_length=100, unique=True)
    code = models.CharField(max_length=20, blank=True)
    min_temp_c = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    max_temp_c = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    requires_cold_chain = models.BooleanField(default=False)
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']

    @property
    def band(self):
        return f'{self.min_temp_c:g}–{self.max_temp_c:g} °C'

    def __str__(self):
        return f'{self.name} ({self.band})'


class TemperatureExcursion(models.Model):
    """A logged out-of-band temperature reading for a batch / zone."""
    class Severity(models.TextChoices):
        MINOR = 'minor', 'Minor'
        MAJOR = 'major', 'Major'
        CRITICAL = 'critical', 'Critical'

    class Status(models.TextChoices):
        OPEN = 'open', 'Open'
        ASSESSED = 'assessed', 'Assessed'
        RESOLVED = 'resolved', 'Resolved'

    zone = models.ForeignKey(
        StorageZone, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='excursions')
    batch = models.ForeignKey(
        StockBatch, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='excursions')
    recorded_temp_c = models.DecimalField(max_digits=5, decimal_places=2)
    allowed_min_c = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    allowed_max_c = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    started_at = models.DateTimeField()
    ended_at = models.DateTimeField(null=True, blank=True)
    severity = models.CharField(max_length=10, choices=Severity.choices,
                               default=Severity.MINOR)
    status = models.CharField(max_length=10, choices=Status.choices,
                              default=Status.OPEN)
    action_taken = models.TextField(blank=True)
    auto_quarantined = models.BooleanField(default=False)
    recorded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='temperature_excursions')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-started_at']
        indexes = [
            models.Index(fields=['status', '-started_at']),
            models.Index(fields=['batch', '-started_at']),
        ]

    def __str__(self):
        return f'{self.recorded_temp_c} °C · {self.get_severity_display()}'


class RecallCase(models.Model):
    """Batch recall / market withdrawal.

    The workflow exists because a batch is *never* only in one place: it can
    have been transferred, sold at POS, dispensed to a patient, or shipped on
    a sales order. ``inventory.services.recall`` traces all of those so the
    case can report how many units were quarantined vs. already gone.
    """
    class Status(models.TextChoices):
        DRAFT = 'draft', 'Draft'
        TRACING = 'tracing', 'Tracing'
        QUARANTINED = 'quarantined', 'Quarantined'
        COMPLETED = 'completed', 'Completed'
        CANCELLED = 'cancelled', 'Cancelled'

    class Reason(models.TextChoices):
        MANUFACTURER = 'manufacturer', 'Manufacturer recall'
        QUALITY = 'quality', 'Quality defect'
        TEMPERATURE = 'temperature', 'Temperature excursion'
        EXPIRY = 'expiry', 'Expired stock'
        REGULATORY = 'regulatory', 'Regulatory directive'
        OTHER = 'other', 'Other'

    class Severity(models.TextChoices):
        LOW = 'low', 'Low'
        MEDIUM = 'medium', 'Medium'
        HIGH = 'high', 'High'
        CRITICAL = 'critical', 'Critical'

    reference = models.CharField(max_length=30, unique=True, blank=True)
    title = models.CharField(max_length=255)
    reason = models.CharField(max_length=20, choices=Reason.choices,
                              default=Reason.QUALITY)
    severity = models.CharField(max_length=10, choices=Severity.choices,
                                default=Severity.MEDIUM)
    status = models.CharField(max_length=15, choices=Status.choices,
                              default=Status.DRAFT)
    batch_number = models.CharField(max_length=100, blank=True,
                                    help_text='Batch lot reported by the manufacturer.')
    medication_name = models.CharField(max_length=255, blank=True)
    target_batch_ids = models.JSONField(
        default=list, blank=True,
        help_text=('Specific StockBatch rows picked in the recall dialog. '
                   'Empty means "every batch that matches the lot number / '
                   'medication name" — the whole-lot behaviour.'))
    external_reference = models.CharField(max_length=100, blank=True,
                                          help_text='Manufacturer / regulator notice number.')
    notes = models.TextField(blank=True)
    began_at = models.DateField(default=timezone.localdate)
    completed_at = models.DateTimeField(null=True, blank=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='recall_cases_created')
    completed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='recall_cases_completed')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['status', '-created_at']),
            models.Index(fields=['batch_number']),
        ]

    def save(self, *args, **kwargs):
        if not self.reference:
            super().save(*args, **kwargs)
            self.reference = f'RCL-{self.pk:05d}'
            kwargs['force_insert'] = False
        super().save(*args, **kwargs)

    @property
    def units_on_hand(self):
        return sum(l.quantity_on_hand for l in self.lines.all())

    @property
    def units_downstream(self):
        return sum(l.quantity_downstream for l in self.lines.all())

    def __str__(self):
        return f'{self.reference} · {self.title}'


class RecallLine(models.Model):
    """One traced location/event for a recall case."""
    class Touch(models.TextChoices):
        ON_HAND = 'on_hand', 'On hand at warehouse'
        TRANSFER = 'transfer', 'Moved by transfer'
        POS = 'pos', 'Sold at POS'
        DISPENSED = 'dispensed', 'Dispensed to patient'
        SALES_ORDER = 'sales_order', 'Sales order'

    case = models.ForeignKey(RecallCase, on_delete=models.CASCADE,
                             related_name='lines')
    touch = models.CharField(max_length=15, choices=Touch.choices)
    stock = models.ForeignKey(
        MedicationStock, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='recall_lines')
    batch = models.ForeignKey(
        StockBatch, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='recall_lines')
    branch = models.ForeignKey(
        'pharmacy_profile.Branch', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='recall_lines')
    quantity_on_hand = models.IntegerField(default=0)
    quantity_downstream = models.IntegerField(default=0)
    reference = models.CharField(max_length=100, blank=True)
    detail = models.CharField(max_length=255, blank=True)
    occurred_at = models.DateTimeField(null=True, blank=True)
    is_confirmed = models.BooleanField(
        default=False, help_text='Set once the location has been physically verified.')

    class Meta:
        ordering = ['touch', 'reference']

    def __str__(self):
        return f'{self.get_touch_display()} · {self.reference or self.stock_id}'


class SupplierCertificate(models.Model):
    """Certificate of analysis / conformity attached to a GRN or supplier.

    Regulated stock cannot be released for sale without one; the GRN
    completion hook refuses lines whose item requires certification and has
    no valid certificate on file.
    """
    class Kind(models.TextChoices):
        COA = 'coa', 'Certificate of analysis'
        COC = 'coc', 'Certificate of conformity'
        GDP = 'gdp', 'Good distribution practice'
        LICENSE = 'license', 'Licence / permit'
        OTHER = 'other', 'Other'

    supplier = models.ForeignKey(
        'suppliers.Supplier', on_delete=models.CASCADE,
        related_name='certificates', null=True, blank=True)
    stock = models.ForeignKey(
        MedicationStock, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='certificates')
    kind = models.CharField(max_length=10, choices=Kind.choices, default=Kind.COA)
    reference = models.CharField(max_length=100)
    issued_on = models.DateField(null=True, blank=True)
    expires_on = models.DateField(null=True, blank=True)
    file = models.FileField(upload_to='inventory/certificates/', blank=True, null=True)
    file_name = models.CharField(max_length=255, blank=True)
    notes = models.TextField(blank=True)
    uploaded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='supplier_certificates')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['stock', '-created_at']),
            models.Index(fields=['expires_on']),
        ]

    @property
    def is_expired(self):
        return bool(self.expires_on and self.expires_on < timezone.localdate())

    def __str__(self):
        return f'{self.get_kind_display()} {self.reference}'


# ─────────────────────────────────────────────────────────────────────────
#  Tier 4 — Warehouse execution (bin hierarchy, putaway, scan verification)
# ─────────────────────────────────────────────────────────────────────────
class WarehouseBin(models.Model):
    """A physical slot: Zone → Aisle → Rack → Bin, with a capacity.

    ``MedicationStock.location_in_store`` remains as a free-text fallback;
    a bin assignment supersedes it once present.
    """
    branch = models.ForeignKey(
        'pharmacy_profile.Branch', on_delete=models.CASCADE,
        related_name='bins')
    zone = models.CharField(max_length=50, blank=True)
    aisle = models.CharField(max_length=20, blank=True)
    rack = models.CharField(max_length=20, blank=True)
    bin_code = models.CharField(max_length=20, blank=True)
    name = models.CharField(max_length=120)
    capacity_units = models.PositiveIntegerField(default=0,
                                                 help_text='0 = unlimited')
    storage_zone = models.ForeignKey(
        StorageZone, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='bins')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['branch', 'zone', 'aisle', 'rack', 'bin_code']
        constraints = [
            models.UniqueConstraint(
                fields=['branch', 'name'], name='uniq_bin_branch_name'),
        ]
        verbose_name = 'Warehouse bin'

    @property
    def canonical(self):
        parts = [self.zone, self.aisle, self.rack, self.bin_code]
        return '/'.join(p for p in parts if p) or self.name

    @property
    def used_units(self):
        return sum(p.quantity for p in self.placements.all())

    @property
    def free_units(self):
        if not self.capacity_units:
            return None
        return max(0, self.capacity_units - self.used_units)

    @property
    def fill_pct(self):
        if not self.capacity_units:
            return 0
        return min(100, round(self.used_units / self.capacity_units * 100))

    def __str__(self):
        return f'{self.canonical} · {self.branch}'


class StockPlacement(models.Model):
    """Units of a stock item sitting in a bin (advisory putaway/pick)."""
    bin = models.ForeignKey(WarehouseBin, on_delete=models.CASCADE,
                            related_name='placements')
    stock = models.ForeignKey(MedicationStock, on_delete=models.CASCADE,
                              related_name='placements')
    batch = models.ForeignKey(StockBatch, on_delete=models.SET_NULL,
                              null=True, blank=True, related_name='placements')
    quantity = models.PositiveIntegerField(default=0)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['bin', 'stock']
        constraints = [
            models.UniqueConstraint(fields=['bin', 'stock', 'batch'],
                                    name='uniq_placement_bin_stock_batch'),
        ]

    def __str__(self):
        return f'{self.stock.medication_name} × {self.quantity} @ {self.bin.canonical}'


class ScanVerification(models.Model):
    """Record of a scan used to verify a receive / pick / count.

    Gives the mobile app an audit trail and lets the desk spot scans that
    disagreed with the expected item (wrong item pulled, mislabelled carton).
    """
    class Context(models.TextChoices):
        RECEIVE = 'receive', 'Transfer receive'
        PICK = 'pick', 'Pick'
        COUNT = 'count', 'Cycle count'
        PUTAWAY = 'putaway', 'Putaway'
        POS = 'pos', 'POS'

    context = models.CharField(max_length=10, choices=Context.choices)
    scanned_code = models.CharField(max_length=120)
    expected_stock = models.ForeignKey(
        MedicationStock, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='scan_verifications')
    matched_stock = models.ForeignKey(
        MedicationStock, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='scan_matches')
    batch = models.ForeignKey(StockBatch, on_delete=models.SET_NULL,
                              null=True, blank=True, related_name='scans')
    reference = models.CharField(max_length=100, blank=True)
    is_match = models.BooleanField(default=False)
    quantity = models.IntegerField(default=0)
    scanned_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='inventory_scans')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['context', '-created_at']),
            models.Index(fields=['is_match', '-created_at']),
        ]

    def __str__(self):
        return f'{self.get_context_display()} {self.scanned_code} ({"match" if self.is_match else "miss"})'


# ─────────────────────────────────────────────────────────────────────────
#  Tier 5 — Costing, valuation snapshots and write-off approvals
# ─────────────────────────────────────────────────────────────────────────
class InventorySnapshot(models.Model):
    """Month-end valuation snapshot.

    Valuation must be reproducible for finance, so each run freezes the
    per-item cost, quantity and method used rather than relying on today's
    ``cost_price``.
    """
    class Method(models.TextChoices):
        WEIGHTED_AVERAGE = 'weighted_average', 'Weighted average'
        FIFO = 'fifo', 'FIFO'
        BATCH_COST = 'batch_cost', 'Batch cost (per-batch actual)'

    period = models.DateField(help_text='Snapshot period (usually the 1st).')
    method = models.CharField(max_length=20, choices=Method.choices,
                              default=Method.WEIGHTED_AVERAGE)
    total_units = models.IntegerField(default=0)
    total_cost_value = models.DecimalField(max_digits=16, decimal_places=2, default=0)
    total_retail_value = models.DecimalField(max_digits=16, decimal_places=2, default=0)
    expired_value = models.DecimalField(max_digits=16, decimal_places=2, default=0)
    sku_count = models.PositiveIntegerField(default=0)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='inventory_snapshots')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-period']
        constraints = [
            models.UniqueConstraint(fields=['period', 'method'],
                                    name='uniq_snapshot_period_method'),
        ]
        verbose_name = 'Inventory snapshot'

    def __str__(self):
        return f'Valuation {self.period} ({self.get_method_display()})'


class InventorySnapshotLine(models.Model):
    snapshot = models.ForeignKey(InventorySnapshot, on_delete=models.CASCADE,
                                 related_name='lines')
    stock = models.ForeignKey(MedicationStock, on_delete=models.SET_NULL,
                              null=True, blank=True, related_name='snapshot_lines')
    medication_name = models.CharField(max_length=255)
    unit_cost = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    quantity = models.IntegerField(default=0)
    value = models.DecimalField(max_digits=16, decimal_places=2, default=0)
    abc_class = models.CharField(max_length=1, blank=True)

    class Meta:
        ordering = ['-value']

    def __str__(self):
        return f'{self.medication_name} {self.quantity} × {self.unit_cost}'


class WriteOffRequest(models.Model):
    """Adjustment above the tenant threshold that needs a second signature."""
    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending approval'
        APPROVED = 'approved', 'Approved'
        REJECTED = 'rejected', 'Rejected'

    adjustment = models.OneToOneField(
        StockAdjustment, on_delete=models.CASCADE, related_name='writeoff')
    stock = models.ForeignKey(MedicationStock, on_delete=models.CASCADE,
                              related_name='writeoff_requests')
    quantity = models.IntegerField()
    value = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    reason = models.CharField(max_length=30, blank=True)
    notes = models.TextField(blank=True)
    status = models.CharField(max_length=10, choices=Status.choices,
                              default=Status.PENDING)
    requested_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='writeoff_requests')
    decided_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='writeoff_decisions')
    decided_at = models.DateTimeField(null=True, blank=True)
    signature = models.TextField(blank=True,
                                 help_text="Base64 data-URL of the approver's signature.")
    decision_note = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [models.Index(fields=['status', '-created_at'])]

    def __str__(self):
        return f'Write-off {self.value} · {self.stock.medication_name}'


# ─────────────────────────────────────────────────────────────────────────
#  Tier 6 — Supplier performance
# ─────────────────────────────────────────────────────────────────────────
class SupplierScorecard(models.Model):
    """Computed supplier performance for a period (OTIF, fill rate, etc.)."""
    supplier = models.ForeignKey(
        'suppliers.Supplier', on_delete=models.CASCADE,
        related_name='scorecards')
    period_start = models.DateField()
    period_end = models.DateField()
    orders_count = models.PositiveIntegerField(default=0)
    lines_ordered = models.PositiveIntegerField(default=0)
    lines_received_in_full = models.PositiveIntegerField(default=0)
    otif_pct = models.FloatField(default=0, help_text='On time in full.')
    fill_rate_pct = models.FloatField(default=0)
    avg_lead_time_days = models.FloatField(default=0)
    lead_time_stddev = models.FloatField(default=0)
    on_time_pct = models.FloatField(default=0)
    rejection_pct = models.FloatField(default=0)
    score = models.FloatField(default=0, help_text='Composite 0–100.')
    grade = models.CharField(max_length=2, default='C')
    generated_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-period_end', '-score']
        constraints = [
            models.UniqueConstraint(
                fields=['supplier', 'period_start', 'period_end'],
                name='uniq_scorecard_supplier_period'),
        ]

    def __str__(self):
        return f'{self.supplier} {self.period_end:%Y-%m} · {self.score:.0f} ({self.grade})'


# ─────────────────────────────────────────────────────────────────────────
#  Tier 7 — Anomaly detection
# ─────────────────────────────────────────────────────────────────────────
class StockAnomaly(models.Model):
    """A statistical outlier surfaced by the nightly detector.

    ``severity`` drives the badge in the UI; ``status`` lets a manager
    dismiss or confirm (confirming usually opens an investigation).
    """
    class Kind(models.TextChoices):
        VARIANCE = 'variance', 'Repeated count variance'
        WRITE_OFF = 'write_off', 'Unusual write-off'
        ADJUSTMENT = 'adjustment', 'Unusual adjustment volume'
        PRICE = 'price', 'Unexpected price change'
        DEMAND = 'demand', 'Demand spike / drop'
        EXPIRY = 'expiry', 'Mass expiry event'

    class Status(models.TextChoices):
        OPEN = 'open', 'Open'
        ACKNOWLEDGED = 'acknowledged', 'Acknowledged'
        DISMISSED = 'dismissed', 'Dismissed'

    kind = models.CharField(max_length=15, choices=Kind.choices)
    severity = models.CharField(max_length=10,
                                choices=[('low', 'Low'), ('medium', 'Medium'),
                                         ('high', 'High')],
                                default='medium')
    status = models.CharField(max_length=15, choices=Status.choices,
                              default=Status.OPEN)
    stock = models.ForeignKey(MedicationStock, on_delete=models.CASCADE,
                              null=True, blank=True, related_name='anomalies')
    branch = models.ForeignKey(
        'pharmacy_profile.Branch', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='anomalies')
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='inventory_anomalies')
    title = models.CharField(max_length=255)
    detail = models.TextField(blank=True)
    metric = models.FloatField(default=0, help_text='The observed value.')
    baseline = models.FloatField(default=0, help_text='The expected value.')
    z_score = models.FloatField(default=0)
    occurrences = models.PositiveIntegerField(default=1)
    window_start = models.DateTimeField(null=True, blank=True)
    window_end = models.DateTimeField(null=True, blank=True)
    signature = models.CharField(
        max_length=64, blank=True, db_index=True,
        help_text='Stable hash so a nightly run does not duplicate a known anomaly.')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['status', 'severity', '-created_at']),
            models.Index(fields=['kind', '-created_at']),
        ]

    def __str__(self):
        return f'{self.get_kind_display()} · {self.title}'


class CycleCountSchedule(models.Model):
    """ABC-driven recurring count plan for one item / warehouse."""
    class Cadence(models.TextChoices):
        A = 'A', 'A — monthly'
        B = 'B', 'B — quarterly'
        C = 'C', 'C — annual'

    stock = models.ForeignKey(MedicationStock, on_delete=models.CASCADE,
                              related_name='count_schedules')
    branch = models.ForeignKey(
        'pharmacy_profile.Branch', on_delete=models.CASCADE,
        related_name='count_schedules')
    cadence = models.CharField(max_length=1, choices=Cadence.choices,
                               default=Cadence.C)
    interval_days = models.PositiveIntegerField(default=365)
    next_due = models.DateField()
    last_counted_at = models.DateTimeField(null=True, blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['next_due']
        constraints = [
            models.UniqueConstraint(fields=['stock', 'branch'],
                                    name='uniq_count_schedule_stock_branch'),
        ]
        indexes = [models.Index(fields=['is_active', 'next_due'])]

    def __str__(self):
        return f'{self.stock.medication_name} · {self.cadence} due {self.next_due}'


