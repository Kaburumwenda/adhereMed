from django.conf import settings
from django.db import models


class CoinPackage(models.Model):
    """Predefined coin packages tenants can purchase."""
    name = models.CharField(max_length=120)
    coins = models.PositiveIntegerField(help_text="Number of coins in this package")
    price = models.DecimalField(max_digits=12, decimal_places=2, help_text="Price in base currency")
    currency = models.CharField(max_length=3, default="KES")
    bonus_coins = models.PositiveIntegerField(default=0, help_text="Extra bonus coins included")
    is_active = models.BooleanField(default=True)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["price"]

    def __str__(self):
        return f"{self.name} ({self.coins} coins)"

    @property
    def total_coins(self):
        return self.coins + self.bonus_coins


class CoinWallet(models.Model):
    """Each tenant has a coin wallet."""
    tenant = models.OneToOneField(
        "tenants.Tenant", on_delete=models.CASCADE, related_name="coin_wallet"
    )
    balance = models.PositiveIntegerField(default=0)
    lifetime_earned = models.PositiveIntegerField(default=0)
    lifetime_spent = models.PositiveIntegerField(default=0)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-balance"]

    def __str__(self):
        return f"{self.tenant} — {self.balance} coins"


class CoinTransaction(models.Model):
    """Immutable ledger of all coin movements."""
    class TxType(models.TextChoices):
        CREDIT = "credit", "Credit"
        DEBIT = "debit", "Debit"
        BONUS = "bonus", "Bonus"
        REFUND = "refund", "Refund"
        EXPIRED = "expired", "Expired"
        PURCHASE = "purchase", "Purchase"

    wallet = models.ForeignKey(
        CoinWallet, on_delete=models.CASCADE, related_name="transactions"
    )
    tx_type = models.CharField(max_length=16, choices=TxType.choices)
    amount = models.PositiveIntegerField()
    balance_after = models.PositiveIntegerField()
    description = models.CharField(max_length=255, blank=True)
    reference = models.CharField(max_length=128, blank=True, help_text="External ref e.g. payment ID")
    package = models.ForeignKey(
        CoinPackage, null=True, blank=True, on_delete=models.SET_NULL
    )
    performed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.tx_type} {self.amount} → {self.wallet.tenant}"
