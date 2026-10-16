from django.db import models
from django.conf import settings


class PurchaseOrder(models.Model):
    class Status(models.TextChoices):
        DRAFT = 'draft', 'Draft'
        SENT = 'sent', 'Sent'
        RECEIVED = 'received', 'Received'
        PARTIAL = 'partial', 'Partially Received'
        CANCELLED = 'cancelled', 'Cancelled'
        RETURNED = 'returned', 'Returned'

    po_number = models.CharField(max_length=50, unique=True)
    supplier = models.ForeignKey('suppliers.Supplier', on_delete=models.CASCADE, related_name='purchase_orders')
    items = models.JSONField(default=list, help_text='[{medication_stock_id, name, qty, unit_cost, total}]')
    total_cost = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    shipping_cost = models.DecimalField(
        max_digits=12, decimal_places=2, default=0,
        help_text='Recorded as an expense; NOT included in total_cost',
    )
    proof_image = models.ImageField(
        upload_to='po_proofs/', null=True, blank=True,
        help_text='Optional proof image (signed delivery note, receipt photo, etc.)',
    )
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.DRAFT)
    ordered_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name='purchase_orders',
    )
    order_date = models.DateField(auto_now_add=True)
    expected_delivery = models.DateField(null=True, blank=True)
    notes = models.TextField(blank=True)
    branch = models.ForeignKey(
        'pharmacy_profile.Branch', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='purchase_orders',
    )
    approved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='approved_purchase_orders',
    )
    approved_at = models.DateTimeField(null=True, blank=True)
    rejected_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='rejected_purchase_orders',
    )
    rejected_at = models.DateTimeField(null=True, blank=True)
    rejection_reason = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'PO {self.po_number} - {self.supplier}'


class GoodsReceivedNote(models.Model):
    purchase_order = models.ForeignKey(PurchaseOrder, on_delete=models.CASCADE, related_name='grns')
    grn_number = models.CharField(max_length=50, unique=True)
    received_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name='grns_received',
    )
    items_received = models.JSONField(default=list)
    received_date = models.DateField(auto_now_add=True)
    notes = models.TextField(blank=True)

    def __str__(self):
        return f'GRN {self.grn_number}'


class RequestForQuotation(models.Model):
    """Request for Quotation — send to multiple suppliers for price comparison."""
    class Status(models.TextChoices):
        DRAFT = 'draft', 'Draft'
        SENT = 'sent', 'Sent to Suppliers'
        QUOTED = 'quoted', 'Quotes Received'
        AWARDED = 'awarded', 'Awarded'
        CLOSED = 'closed', 'Closed'
        CANCELLED = 'cancelled', 'Cancelled'

    rfq_number = models.CharField(max_length=50, unique=True)
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    items = models.JSONField(
        default=list,
        help_text='[{medication_stock_id, name, qty, unit}] — items being requested',
    )
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.DRAFT)
    expected_delivery = models.DateField(null=True, blank=True)
    response_deadline = models.DateField(null=True, blank=True, help_text='Deadline for suppliers to respond')
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name='rfqs_created',
    )
    branch = models.ForeignKey(
        'pharmacy_profile.Branch', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='rfqs',
    )
    awarded_supplier = models.ForeignKey(
        'suppliers.Supplier', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='awarded_rfqs', help_text='Supplier who won the RFQ',
    )
    awarded_po = models.ForeignKey(
        PurchaseOrder, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='rfqs', help_text='PO created from the winning quote',
    )
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Request for Quotation'
        verbose_name_plural = 'Requests for Quotation'

    def __str__(self):
        return f'RFQ {self.rfq_number} — {self.title}'


class RFQQuote(models.Model):
    """A supplier's quote/response to an RFQ."""
    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        AWARDED = 'awarded', 'Awarded'
        REJECTED = 'rejected', 'Rejected'

    rfq = models.ForeignKey(RequestForQuotation, on_delete=models.CASCADE, related_name='quotes')
    supplier = models.ForeignKey(
        'suppliers.Supplier', on_delete=models.CASCADE, related_name='quotes',
    )
    items = models.JSONField(
        default=list,
        help_text='[{medication_stock_id, name, qty, unit_cost, total}] — quoted line items',
    )
    total_cost = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    delivery_days = models.PositiveIntegerField(
        default=0, help_text='Estimated delivery time in days',
    )
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    notes = models.TextField(blank=True, help_text='Supplier notes or terms')
    valid_until = models.DateField(null=True, blank=True, help_text='Quote validity date')
    submitted_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['total_cost']
        unique_together = ['rfq', 'supplier']
        verbose_name = 'RFQ Quote'
        verbose_name_plural = 'RFQ Quotes'

    def __str__(self):
        return f'{self.supplier.name} — RFQ {self.rfq.rfq_number}'


class SupplierEvaluation(models.Model):
    """Supplier performance evaluation / scorecard for analytics."""
    supplier = models.ForeignKey(
        'suppliers.Supplier', on_delete=models.CASCADE, related_name='evaluations',
    )
    evaluation_date = models.DateField(auto_now_add=True)
    on_time_delivery_score = models.PositiveIntegerField(
        default=3, help_text='1-5 scale; 5 = always on time',
    )
    quality_score = models.PositiveIntegerField(
        default=3, help_text='1-5 scale; 5 = excellent quality',
    )
    responsiveness_score = models.PositiveIntegerField(
        default=3, help_text='1-5 scale; 5 = very responsive',
    )
    pricing_competitiveness = models.PositiveIntegerField(
        default=3, help_text='1-5 scale; 5 = best prices',
    )
    payment_flexibility = models.PositiveIntegerField(
        default=3, help_text='1-5 scale; 5 = very flexible',
    )
    overall_rating = models.DecimalField(
        max_digits=3, decimal_places=2, default=0,
        help_text='Computed average of all scores',
    )
    notes = models.TextField(blank=True)
    evaluated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True,
        related_name='supplier_evaluations',
    )

    class Meta:
        ordering = ['-evaluation_date']

    def __str__(self):
        return f'{self.supplier.name} — {self.evaluation_date}'

    def save(self, *args, **kwargs):
        scores = [
            self.on_time_delivery_score, self.quality_score,
            self.responsiveness_score, self.pricing_competitiveness,
            self.payment_flexibility,
        ]
        if scores:
            self.overall_rating = sum(scores) / len(scores)
        super().save(*args, **kwargs)


class ReorderSuggestion(models.Model):
    """Auto-generated reorder suggestion based on stock levels and reorder points."""
    stock = models.ForeignKey(
        'inventory.MedicationStock', on_delete=models.CASCADE, related_name='reorder_suggestions',
    )
    current_quantity = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    reorder_level = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    suggested_quantity = models.DecimalField(
        max_digits=12, decimal_places=2, default=0,
        help_text='Suggested order quantity (based on usage velocity)',
    )
    recommended_supplier = models.ForeignKey(
        'suppliers.Supplier', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='reorder_suggestions',
    )
    last_unit_cost = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    estimated_cost = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    status = models.CharField(
        max_length=20,
        choices=[('pending', 'Pending'), ('ordered', 'Ordered'), ('dismissed', 'Dismissed')],
        default='pending',
    )
    branch = models.ForeignKey(
        'pharmacy_profile.Branch', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='reorder_suggestions',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'Reorder: {self.stock.medication_name} × {self.suggested_quantity}'
