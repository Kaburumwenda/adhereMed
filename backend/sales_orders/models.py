from django.conf import settings
from django.db import models


class SalesOrder(models.Model):
    class Status(models.TextChoices):
        DRAFT = 'draft', 'Draft'
        CONFIRMED = 'confirmed', 'Confirmed'
        PARTIAL = 'partial', 'Partially Fulfilled'
        FULFILLED = 'fulfilled', 'Fulfilled'
        CANCELLED = 'cancelled', 'Cancelled'

    class PaymentStatus(models.TextChoices):
        UNPAID = 'unpaid', 'Unpaid'
        PARTIAL = 'partial', 'Partially Paid'
        PAID = 'paid', 'Paid'

    class PaymentMethod(models.TextChoices):
        CASH = 'cash', 'Cash'
        MPESA = 'mpesa', 'M-Pesa'
        BANK = 'bank', 'Bank Transfer'
        CARD = 'card', 'Card'
        CHEQUE = 'cheque', 'Cheque'
        INSURANCE = 'insurance', 'Insurance'
        CREDIT = 'credit', 'Credit'
        OTHER = 'other', 'Other'

    so_number = models.CharField(max_length=50, unique=True)
    customer = models.ForeignKey(
        'pos.Customer', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='sales_orders',
    )
    customer_name = models.CharField(max_length=255, help_text='Cached from customer or free text')
    customer_phone = models.CharField(max_length=20, blank=True)
    items = models.JSONField(default=list, help_text='[{stock_id, name, qty, unit_price, discount_percent, total}]')
    total_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    discount_amount = models.DecimalField(
        max_digits=12, decimal_places=2, default=0,
        help_text='Order-level discount applied after line items',
    )
    delivery_fee = models.DecimalField(
        max_digits=12, decimal_places=2, default=0,
        help_text='Delivery/shipping cost charged to the customer',
    )
    amount_paid = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.DRAFT)
    payment_status = models.CharField(
        max_length=20, choices=PaymentStatus.choices, default=PaymentStatus.UNPAID,
    )
    payment_method = models.CharField(
        max_length=20, choices=PaymentMethod.choices, default=PaymentMethod.CASH,
    )
    expected_delivery = models.DateField(null=True, blank=True)
    delivery_address = models.TextField(blank=True)
    delivery_place_name = models.CharField(max_length=255, blank=True)
    delivery_lat = models.DecimalField(max_digits=10, decimal_places=6, null=True, blank=True)
    delivery_lng = models.DecimalField(max_digits=10, decimal_places=6, null=True, blank=True)
    notes = models.TextField(blank=True)
    branch = models.ForeignKey(
        'pharmacy_profile.Branch', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='sales_orders',
    )
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='sales_orders',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'SO {self.so_number} - {self.customer_name}'

    @property
    def balance_due(self):
        return (self.total_amount or 0) - (self.amount_paid or 0)

    def recompute_payment_status(self):
        """Sync payment_status from amount_paid vs total_amount."""
        total = self.total_amount or 0
        paid = self.amount_paid or 0
        if paid <= 0:
            self.payment_status = self.PaymentStatus.UNPAID
        elif paid >= total:
            self.payment_status = self.PaymentStatus.PAID
        else:
            self.payment_status = self.PaymentStatus.PARTIAL
