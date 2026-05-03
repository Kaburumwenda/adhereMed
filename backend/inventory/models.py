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
    category = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, blank=True, related_name='stocks')
    unit = models.ForeignKey(Unit, on_delete=models.SET_NULL, null=True, blank=True, related_name='stocks')
    selling_price = models.DecimalField(max_digits=10, decimal_places=2)
    cost_price = models.DecimalField(max_digits=10, decimal_places=2, default=0)
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
    expiry_date = models.DateField()
    received_date = models.DateField(auto_now_add=True)
    supplier = models.ForeignKey(
        'suppliers.Supplier', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='batches',
    )

    class Meta:
        ordering = ['expiry_date']  # FEFO ordering

    def __str__(self):
        return f'{self.stock.medication_name} - Batch {self.batch_number} (Exp: {self.expiry_date})'

    @property
    def is_expired(self):
        from django.utils import timezone
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
