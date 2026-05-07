from django.db import models
from django.conf import settings


class ExpenseCategory(models.Model):
    name = models.CharField(max_length=120, unique=True)
    description = models.TextField(blank=True)
    color = models.CharField(max_length=20, blank=True, help_text='Hex color for UI')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']
        verbose_name_plural = 'Expense categories'

    def __str__(self):
        return self.name


class Expense(models.Model):
    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending Approval'
        APPROVED = 'approved', 'Approved'
        PAID = 'paid', 'Paid'
        REJECTED = 'rejected', 'Rejected'
        CANCELLED = 'cancelled', 'Cancelled'

    class PaymentMethod(models.TextChoices):
        CASH = 'cash', 'Cash'
        MPESA = 'mpesa', 'M-Pesa'
        BANK = 'bank', 'Bank Transfer'
        CARD = 'card', 'Card'
        CHEQUE = 'cheque', 'Cheque'
        OTHER = 'other', 'Other'

    reference = models.CharField(max_length=50, unique=True, db_index=True)
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    category = models.ForeignKey(
        ExpenseCategory, on_delete=models.PROTECT, related_name='expenses', null=True, blank=True,
    )
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    tax_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    expense_date = models.DateField()
    due_date = models.DateField(null=True, blank=True)
    payment_method = models.CharField(
        max_length=20, choices=PaymentMethod.choices, default=PaymentMethod.CASH,
    )
    payment_reference = models.CharField(
        max_length=120, blank=True,
        help_text='Mpesa code, cheque #, transaction ref, etc.',
    )
    vendor = models.CharField(max_length=255, blank=True, help_text='Payee / supplier name')
    supplier = models.ForeignKey(
        'suppliers.Supplier', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='expenses',
    )
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    is_recurring = models.BooleanField(default=False)
    recurring_period = models.CharField(
        max_length=20, blank=True,
        help_text='daily | weekly | monthly | quarterly | yearly',
    )
    receipt = models.FileField(upload_to='expense_receipts/', blank=True, null=True)
    notes = models.TextField(blank=True)
    submitted_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='submitted_expenses',
    )
    approved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='approved_expenses',
    )
    approved_at = models.DateTimeField(null=True, blank=True)
    paid_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-expense_date', '-created_at']

    def __str__(self):
        return f'{self.reference} — {self.title} ({self.amount})'

    @property
    def total_amount(self):
        return (self.amount or 0) + (self.tax_amount or 0)
