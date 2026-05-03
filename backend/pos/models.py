from django.db import models
from django.conf import settings


class Customer(models.Model):
    name = models.CharField(max_length=255)
    phone = models.CharField(max_length=20, unique=True)
    email = models.EmailField(blank=True)
    address = models.TextField(blank=True)
    notes = models.TextField(blank=True)
    total_purchases = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    visit_count = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return f'{self.name} ({self.phone})'


class POSTransaction(models.Model):
    class PaymentMethod(models.TextChoices):
        CASH = 'cash', 'Cash'
        CARD = 'card', 'Card'
        MPESA = 'mpesa', 'M-Pesa'
        INSURANCE = 'insurance', 'Insurance'

    transaction_number = models.CharField(max_length=50, unique=True)
    customer = models.ForeignKey(
        Customer, on_delete=models.SET_NULL, null=True, blank=True, related_name='transactions',
    )
    customer_name = models.CharField(max_length=255, blank=True)
    customer_phone = models.CharField(max_length=20, blank=True)
    subtotal = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    tax = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    discount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    total = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    payment_method = models.CharField(max_length=20, choices=PaymentMethod.choices, default=PaymentMethod.CASH)
    payment_reference = models.CharField(max_length=100, blank=True)
    cashier = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name='pos_transactions',
    )
    branch = models.ForeignKey(
        'pharmacy_profile.Branch',
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='transactions',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'TXN {self.transaction_number} - KSh {self.total}'


class TransactionItem(models.Model):
    transaction = models.ForeignKey(POSTransaction, on_delete=models.CASCADE, related_name='items')
    stock = models.ForeignKey('inventory.MedicationStock', on_delete=models.SET_NULL, null=True)
    batch = models.ForeignKey('inventory.StockBatch', on_delete=models.SET_NULL, null=True, blank=True)
    medication_name = models.CharField(max_length=255)
    quantity = models.PositiveIntegerField()
    unit_price = models.DecimalField(max_digits=10, decimal_places=2)
    total_price = models.DecimalField(max_digits=10, decimal_places=2)

    def __str__(self):
        return f'{self.medication_name} x{self.quantity}'
