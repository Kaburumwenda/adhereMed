from django.db import models
from django.conf import settings


class Customer(models.Model):
    class LoyaltyTier(models.TextChoices):
        BRONZE = 'bronze', 'Bronze'
        SILVER = 'silver', 'Silver'
        GOLD = 'gold', 'Gold'
        PLATINUM = 'platinum', 'Platinum'

    name = models.CharField(max_length=255)
    phone = models.CharField(max_length=20, unique=True)
    email = models.EmailField(blank=True)
    address = models.TextField(blank=True)
    notes = models.TextField(blank=True)
    total_purchases = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    visit_count = models.PositiveIntegerField(default=0)
    # Loyalty
    loyalty_points = models.IntegerField(default=0)
    loyalty_tier = models.CharField(max_length=12, choices=LoyaltyTier.choices, default=LoyaltyTier.BRONZE)
    loyalty_joined_at = models.DateTimeField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return f'{self.name} ({self.phone})'

    def recompute_tier(self):
        spent = float(self.total_purchases or 0)
        if spent >= 100000:
            tier = self.LoyaltyTier.PLATINUM
        elif spent >= 50000:
            tier = self.LoyaltyTier.GOLD
        elif spent >= 10000:
            tier = self.LoyaltyTier.SILVER
        else:
            tier = self.LoyaltyTier.BRONZE
        if tier != self.loyalty_tier:
            self.loyalty_tier = tier
            return True
        return False


class POSTransaction(models.Model):
    class PaymentMethod(models.TextChoices):
        CASH = 'cash', 'Cash'
        CARD = 'card', 'Card'
        MPESA = 'mpesa', 'M-Pesa'
        INSURANCE = 'insurance', 'Insurance'
        CREDIT = 'credit', 'Credit'

    class SaleStatus(models.TextChoices):
        COMPLETED = 'completed', 'Completed'
        CANCELLED = 'cancelled', 'Cancelled'
        SUSPENDED = 'suspended', 'Suspended'
        PENDING = 'pending', 'Pending'

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
    status = models.CharField(
        max_length=20,
        choices=SaleStatus.choices,
        default=SaleStatus.COMPLETED,
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


class ParkedSale(models.Model):
    """A sale put on hold (parked) so the cashier can serve another customer first.

    Stored without deducting stock; resumed by loading items back into the cart
    and deleting the parked sale.
    """
    park_number = models.CharField(max_length=50, unique=True)
    customer_name = models.CharField(max_length=255, blank=True)
    customer_phone = models.CharField(max_length=20, blank=True)
    payment_method = models.CharField(
        max_length=20, choices=POSTransaction.PaymentMethod.choices, blank=True, default='',
    )
    discount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    items = models.JSONField(default=list)
    notes = models.TextField(blank=True)
    cashier = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name='parked_sales',
    )
    branch = models.ForeignKey(
        'pharmacy_profile.Branch', on_delete=models.SET_NULL, null=True, blank=True, related_name='parked_sales',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'PARK {self.park_number} ({len(self.items)} items)'

    @property
    def item_count(self):
        try:
            return sum(int(it.get('quantity') or 0) for it in (self.items or []))
        except Exception:
            return 0

    @property
    def total(self):
        try:
            return sum(
                (float(it.get('selling_price') or 0) * float(it.get('quantity') or 0))
                for it in (self.items or [])
            ) - float(self.discount or 0)
        except Exception:
            return 0


class CashierShift(models.Model):
    """An open/close cashier session — basis for the Z-Report."""
    class Status(models.TextChoices):
        OPEN = 'open', 'Open'
        CLOSED = 'closed', 'Closed'

    reference = models.CharField(max_length=30, unique=True, blank=True)
    cashier = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name='shifts',
    )
    branch = models.ForeignKey(
        'pharmacy_profile.Branch', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='shifts',
    )
    opening_float = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    closing_actual_cash = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True,
                                              help_text='Cash physically counted at close')
    expected_cash = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True,
                                        help_text='Computed expected cash at close')
    cash_variance = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.OPEN)
    opened_at = models.DateTimeField(auto_now_add=True)
    closed_at = models.DateTimeField(null=True, blank=True)
    closing_notes = models.TextField(blank=True)
    z_report = models.JSONField(default=dict, blank=True,
                                help_text='Snapshot Z-report at close')

    class Meta:
        ordering = ['-opened_at']
        indexes = [
            models.Index(fields=['cashier', 'status']),
            models.Index(fields=['opened_at']),
        ]

    def save(self, *args, **kwargs):
        if not self.reference:
            super().save(*args, **kwargs)
            self.reference = f'SHF-{self.pk:06d}'
            kwargs['force_insert'] = False
            return super().save(update_fields=['reference'])
        return super().save(*args, **kwargs)

    def __str__(self):
        return f'{self.reference or "SHF-?"} ({self.cashier_id})'


class LoyaltyTransaction(models.Model):
    class Type(models.TextChoices):
        EARN = 'earn', 'Earned'
        REDEEM = 'redeem', 'Redeemed'
        ADJUST = 'adjust', 'Manual Adjustment'
        EXPIRE = 'expire', 'Expired'

    customer = models.ForeignKey(
        Customer, on_delete=models.CASCADE, related_name='loyalty_transactions',
    )
    type = models.CharField(max_length=10, choices=Type.choices)
    points = models.IntegerField(help_text='+ for earn/adjust, - for redeem/expire')
    balance_after = models.IntegerField(default=0)
    transaction = models.ForeignKey(
        POSTransaction, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='loyalty_entries',
    )
    notes = models.CharField(max_length=255, blank=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='loyalty_transactions_created',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.customer.name} {self.type} {self.points}'
