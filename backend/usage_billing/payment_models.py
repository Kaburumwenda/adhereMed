"""
Payment gateway, tenant wallet and M-Pesa transaction models.

Live in the PUBLIC schema (alongside the rest of usage_billing) so that:
  * super admins can manage the gateway config and see every transaction
  * each tenant can top up a prepaid wallet and pay usage bills
"""
from decimal import Decimal

from django.conf import settings
from django.db import models
from django.utils import timezone


class PaymentGatewayConfig(models.Model):
    """
    Singleton configuration for the M-Pesa STK push gateway (Jeypay).

    Super admins can update the initiation/confirmation URLs without a
    code deploy.
    """

    DEFAULT_STK_PUSH_URL = "https://jeypay.tiktek-ex.com/v1/pay/stk_push"
    DEFAULT_CONFIRM_URL = "https://jeypay.tiktek-ex.com/v1/pay/cipher"

    name = models.CharField(max_length=60, default="M-Pesa")
    stk_push_url = models.URLField(
        default=DEFAULT_STK_PUSH_URL,
        help_text="Endpoint used to initiate an STK push.",
    )
    confirm_url = models.URLField(
        default=DEFAULT_CONFIRM_URL,
        help_text="Endpoint polled to confirm a payment.",
    )
    source = models.CharField(
        max_length=60,
        default="AdhereMed",
        help_text="`source` field sent with every STK push request.",
    )
    is_active = models.BooleanField(default=True)
    request_timeout_seconds = models.PositiveSmallIntegerField(default=60)
    poll_interval_seconds = models.PositiveSmallIntegerField(default=6)
    updated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="payment_configs_updated",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Payment gateway config"
        verbose_name_plural = "Payment gateway config"

    def __str__(self):
        return f"{self.name} gateway ({'active' if self.is_active else 'inactive'})"

    @classmethod
    def get_solo(cls):
        """Return the single config row, creating defaults on first access."""
        config = cls.objects.order_by("id").first()
        if config is None:
            config = cls.objects.create()
        return config


class TenantWallet(models.Model):
    """Prepaid credit balance a tenant can build up and spend on usage bills."""

    tenant = models.OneToOneField(
        "tenants.Tenant",
        on_delete=models.CASCADE,
        related_name="billing_wallet",
    )
    balance = models.DecimalField(max_digits=14, decimal_places=2, default=Decimal("0.00"))
    currency = models.CharField(max_length=8, default="KSH")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-balance"]

    def __str__(self):
        return f"{self.tenant.name} wallet — {self.balance} {self.currency}"

    def credit(self, amount, reason, related_bill=None, mpesa=None):
        amount = Decimal(str(amount))
        self.balance += amount
        self.save(update_fields=["balance", "updated_at"])
        return WalletTransaction.objects.create(
            wallet=self,
            type=WalletTransaction.Type.CREDIT,
            amount=amount,
            reason=reason,
            related_bill=related_bill,
            mpesa=mpesa,
            balance_after=self.balance,
        )

    def debit(self, amount, reason, related_bill=None):
        amount = Decimal(str(amount))
        self.balance -= amount
        self.save(update_fields=["balance", "updated_at"])
        return WalletTransaction.objects.create(
            wallet=self,
            type=WalletTransaction.Type.DEBIT,
            amount=amount,
            reason=reason,
            related_bill=related_bill,
            balance_after=self.balance,
        )


class WalletTransaction(models.Model):
    class Type(models.TextChoices):
        CREDIT = "credit", "Credit"
        DEBIT = "debit", "Debit"

    wallet = models.ForeignKey(
        TenantWallet, on_delete=models.CASCADE, related_name="transactions"
    )
    type = models.CharField(max_length=10, choices=Type.choices)
    amount = models.DecimalField(max_digits=14, decimal_places=2)
    balance_after = models.DecimalField(max_digits=14, decimal_places=2, default=Decimal("0.00"))
    reason = models.CharField(max_length=255)
    related_bill = models.ForeignKey(
        "usage_billing.MonthlyBill",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="wallet_transactions",
    )
    mpesa = models.ForeignKey(
        "usage_billing.MpesaTransaction",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="wallet_transactions",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.get_type_display()} {self.amount} — {self.reason}"


class MpesaTransaction(models.Model):
    """One M-Pesa STK push attempt, used for both bill payments and wallet top-ups."""

    class Purpose(models.TextChoices):
        BILL = "bill", "Bill payment"
        WALLET = "wallet", "Wallet top-up"

    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        SUCCESS = "success", "Success"
        FAILED = "failed", "Failed"

    tenant = models.ForeignKey(
        "tenants.Tenant",
        on_delete=models.CASCADE,
        related_name="mpesa_transactions",
    )
    purpose = models.CharField(max_length=10, choices=Purpose.choices, default=Purpose.BILL)
    bill = models.ForeignKey(
        "usage_billing.MonthlyBill",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="mpesa_transactions",
    )
    phone = models.CharField(max_length=20)
    amount = models.DecimalField(max_digits=14, decimal_places=2)
    currency = models.CharField(max_length=8, default="KSH")
    checkout_request_id = models.CharField(max_length=120, blank=True, db_index=True)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING)
    result_code = models.CharField(max_length=20, blank=True)
    result_desc = models.CharField(max_length=255, blank=True)
    applied = models.BooleanField(
        default=False,
        help_text="Whether a successful payment has already been credited.",
    )
    initiate_response = models.JSONField(default=dict, blank=True)
    confirm_response = models.JSONField(default=dict, blank=True)
    initiated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="mpesa_transactions_initiated",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["tenant", "status"]),
            models.Index(fields=["checkout_request_id"]),
        ]

    def __str__(self):
        return f"{self.tenant.schema_name} {self.amount} {self.currency} — {self.get_status_display()}"

    def mark_completed(self, status):
        self.status = status
        self.completed_at = timezone.now()
        self.save(update_fields=["status", "completed_at"])
