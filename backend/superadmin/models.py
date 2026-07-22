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


class MailConfiguration(models.Model):
    """Platform-wide outgoing/incoming mail configuration (public schema).

    Singleton: there is a single active configuration row used to send
    transactional emails such as patient welcome messages. Managed from the
    superadmin dashboard.
    """
    from_name = models.CharField(
        max_length=120, default="AdhereMed",
        help_text="Friendly From name shown to recipients.")
    from_email = models.EmailField(
        default="info@adheremed.co",
        help_text="Address used as the From / login address.")
    username = models.CharField(
        max_length=255, default="info@adheremed.co",
        help_text="IMAP/SMTP username.")
    password = models.CharField(
        max_length=512, blank=True, default="",
        help_text="Plain-text mailbox password. Stored at rest.")
    imap_host = models.CharField(max_length=255, default="mail.adheremed.co")
    imap_port = models.PositiveIntegerField(default=993)
    imap_use_ssl = models.BooleanField(default=True)
    smtp_host = models.CharField(max_length=255, default="mail.adheremed.co")
    smtp_port = models.PositiveIntegerField(default=465)
    smtp_use_ssl = models.BooleanField(default=True)
    is_active = models.BooleanField(
        default=True,
        help_text="If false, Django settings defaults are used instead.")
    last_verified_at = models.DateTimeField(null=True, blank=True)
    last_verified_ok = models.BooleanField(default=False)
    last_error = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Mail configuration"
        verbose_name_plural = "Mail configuration"

    def __str__(self):
        return self.from_email or "Mail configuration"

    @classmethod
    def get_solo(cls):
        """Return the single configuration row, creating it with sensible
        AdhereMed defaults on first access."""
        obj = cls.objects.first()
        if obj is None:
            obj = cls.objects.create()
        return obj
