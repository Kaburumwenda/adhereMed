"""
Adhere Coin referral system models.
Lives in PUBLIC schema (shared) alongside other usage_billing models.
"""
import secrets
import string
from decimal import Decimal

from django.db import models


def _generate_referral_code():
    chars = string.ascii_uppercase + string.digits
    while True:
        code = ''.join(secrets.choice(chars) for _ in range(8))
        if not ReferralProfile.objects.filter(referral_code=code).exists():
            return code


class ReferralProfile(models.Model):
    tenant = models.OneToOneField(
        'tenants.Tenant', on_delete=models.CASCADE, related_name='referral_profile',
    )
    referral_code = models.CharField(max_length=12, unique=True, default=_generate_referral_code, db_index=True)
    coin_balance = models.DecimalField(max_digits=14, decimal_places=2, default=Decimal('0.00'))
    total_earned = models.DecimalField(max_digits=14, decimal_places=2, default=Decimal('0.00'))
    total_redeemed = models.DecimalField(max_digits=14, decimal_places=2, default=Decimal('0.00'))
    referral_count = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-coin_balance']

    def __str__(self):
        return f'{self.tenant.name} — {self.coin_balance} coins'

    def credit(self, amount, reason, related_tenant=None):
        amount = Decimal(str(amount))
        self.coin_balance += amount
        self.total_earned += amount
        self.save(update_fields=['coin_balance', 'total_earned', 'updated_at'])
        return CoinTransaction.objects.create(
            profile=self, type=CoinTransaction.Type.EARNED,
            amount=amount, reason=reason, related_tenant=related_tenant,
        )

    def debit(self, amount, reason):
        amount = Decimal(str(amount))
        self.coin_balance -= amount
        self.total_redeemed += amount
        self.save(update_fields=['coin_balance', 'total_redeemed', 'updated_at'])
        return CoinTransaction.objects.create(
            profile=self, type=CoinTransaction.Type.REDEEMED,
            amount=amount, reason=reason,
        )


class Referral(models.Model):
    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        ACTIVE = 'active', 'Active'
        EXPIRED = 'expired', 'Expired'

    referrer = models.ForeignKey('tenants.Tenant', on_delete=models.CASCADE, related_name='referrals_made')
    referred = models.OneToOneField('tenants.Tenant', on_delete=models.CASCADE, related_name='referred_by')
    status = models.CharField(max_length=12, choices=Status.choices, default=Status.ACTIVE)
    bonus_awarded = models.BooleanField(default=False)
    tracked_requests = models.PositiveIntegerField(default=0)
    coins_from_usage = models.DecimalField(max_digits=14, decimal_places=2, default=Decimal('0.00'))
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        unique_together = ('referrer', 'referred')

    def __str__(self):
        return f'{self.referrer.name} -> {self.referred.name}'


class CoinTransaction(models.Model):
    class Type(models.TextChoices):
        EARNED = 'earned', 'Earned'
        REDEEMED = 'redeemed', 'Redeemed'
        BONUS = 'bonus', 'Bonus'
        ADJUSTMENT = 'adjustment', 'Adjustment'

    profile = models.ForeignKey(ReferralProfile, on_delete=models.CASCADE, related_name='transactions')
    type = models.CharField(max_length=12, choices=Type.choices)
    amount = models.DecimalField(max_digits=14, decimal_places=2)
    reason = models.CharField(max_length=255)
    related_tenant = models.ForeignKey(
        'tenants.Tenant', null=True, blank=True, on_delete=models.SET_NULL, related_name='+',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.get_type_display()} {self.amount} — {self.reason}'
