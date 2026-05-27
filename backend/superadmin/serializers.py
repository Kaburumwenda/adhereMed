from django.contrib.auth import get_user_model
from rest_framework import serializers

from tenants.models import Domain, Tenant
from .models import CoinPackage
from usage_billing.referral_models import ReferralProfile, CoinTransaction as RefCoinTransaction, Referral

User = get_user_model()


class DomainInlineSerializer(serializers.ModelSerializer):
    class Meta:
        model = Domain
        fields = ["id", "domain", "is_primary"]


class TenantAdminSerializer(serializers.ModelSerializer):
    domains = DomainInlineSerializer(many=True, read_only=True)
    user_count = serializers.SerializerMethodField()

    class Meta:
        model = Tenant
        fields = [
            "id", "name", "type", "slug", "schema_name",
            "address", "city", "country",
            "latitude", "longitude", "place_name",
            "phone", "email", "website",
            "is_active", "created_at", "updated_at",
            "domains", "user_count",
        ]
        read_only_fields = ["schema_name", "created_at", "updated_at", "slug"]

    def get_user_count(self, obj):
        return User.objects.filter(tenant=obj).count()


class TenantCreateSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=255)
    type = serializers.ChoiceField(choices=Tenant.TenantType.choices)
    slug = serializers.SlugField()
    domain = serializers.CharField(max_length=253)
    address = serializers.CharField(required=False, allow_blank=True, default="")
    city = serializers.CharField(max_length=100, required=False, allow_blank=True, default="")
    phone = serializers.CharField(max_length=20, required=False, allow_blank=True, default="")
    email = serializers.EmailField(required=False, allow_blank=True, default="")
    website = serializers.URLField(required=False, allow_blank=True, default="")
    country = serializers.CharField(max_length=100, required=False, allow_blank=True, default="Kenya")
    latitude = serializers.DecimalField(max_digits=10, decimal_places=6, required=False, allow_null=True, default=None)
    longitude = serializers.DecimalField(max_digits=10, decimal_places=6, required=False, allow_null=True, default=None)
    place_name = serializers.CharField(max_length=255, required=False, allow_blank=True, default="")
    # Admin user
    admin_email = serializers.EmailField()
    admin_first_name = serializers.CharField(max_length=150)
    admin_last_name = serializers.CharField(max_length=150)
    admin_password = serializers.CharField(min_length=8, write_only=True, required=False, allow_blank=True)

    def validate_slug(self, value):
        if Tenant.objects.filter(slug=value).exists():
            raise serializers.ValidationError("A tenant with this slug already exists.")
        return value

    def validate_domain(self, value):
        if Domain.objects.filter(domain=value).exists():
            raise serializers.ValidationError("This domain is already in use.")
        return value

    def validate_admin_email(self, value):
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("A user with this email already exists.")
        return value


class UserAdminSerializer(serializers.ModelSerializer):
    tenant_name = serializers.CharField(source="tenant.name", read_only=True, default=None)
    tenant_type = serializers.CharField(source="tenant.type", read_only=True, default=None)

    class Meta:
        model = User
        fields = [
            "id", "email", "phone", "first_name", "last_name",
            "role", "tenant", "tenant_name", "tenant_type",
            "is_active", "is_staff", "date_joined",
        ]
        read_only_fields = ["date_joined"]


class UserAdminUpdateSerializer(serializers.ModelSerializer):
    """Allows updating user info but not password (use the dedicated endpoint)."""

    class Meta:
        model = User
        fields = [
            "email", "phone", "first_name", "last_name",
            "role", "tenant", "is_active", "is_staff",
        ]

    def validate_email(self, value):
        user = self.instance
        if User.objects.filter(email=value).exclude(pk=user.pk).exists():
            raise serializers.ValidationError("This email is already in use.")
        return value


# ── Adhere Coins ───────────────────────────────────────────────────────────────

class CoinPackageSerializer(serializers.ModelSerializer):
    total_coins = serializers.IntegerField(read_only=True)

    class Meta:
        model = CoinPackage
        fields = [
            "id", "name", "coins", "bonus_coins", "total_coins",
            "price", "currency", "is_active", "description",
            "created_at", "updated_at",
        ]
        read_only_fields = ["created_at", "updated_at"]


class CoinWalletSerializer(serializers.ModelSerializer):
    tenant_name = serializers.CharField(source="tenant.name", read_only=True)
    tenant_type = serializers.CharField(source="tenant.type", read_only=True)
    balance = serializers.DecimalField(source="coin_balance", max_digits=14, decimal_places=2, read_only=True)
    lifetime_earned = serializers.DecimalField(source="total_earned", max_digits=14, decimal_places=2, read_only=True)
    lifetime_spent = serializers.DecimalField(source="total_redeemed", max_digits=14, decimal_places=2, read_only=True)

    class Meta:
        model = ReferralProfile
        fields = [
            "id", "tenant", "tenant_name", "tenant_type",
            "balance", "lifetime_earned", "lifetime_spent",
            "referral_code", "referral_count", "updated_at",
        ]


class CoinTransactionSerializer(serializers.ModelSerializer):
    tenant_name = serializers.CharField(source="profile.tenant.name", read_only=True)
    tx_type = serializers.CharField(source="type", read_only=True)
    description = serializers.CharField(source="reason", read_only=True)
    balance_after = serializers.SerializerMethodField()

    class Meta:
        model = RefCoinTransaction
        fields = [
            "id", "tenant_name", "tx_type", "amount",
            "balance_after", "description", "created_at",
        ]

    def get_balance_after(self, obj):
        return None  # Not tracked per-transaction in this model


class CoinAllocateSerializer(serializers.Serializer):
    """Allocate coins to a tenant wallet."""
    tenant_id = serializers.IntegerField()
    amount = serializers.IntegerField(min_value=1)
    tx_type = serializers.ChoiceField(
        choices=[("credit", "Credit"), ("bonus", "Bonus"), ("refund", "Refund")],
        default="credit",
    )
    description = serializers.CharField(max_length=255, required=False, default="")
    reference = serializers.CharField(max_length=128, required=False, default="")
    package_id = serializers.IntegerField(required=False, allow_null=True, default=None)


class CoinDeductSerializer(serializers.Serializer):
    """Deduct coins from a tenant wallet."""
    tenant_id = serializers.IntegerField()
    amount = serializers.IntegerField(min_value=1)
    description = serializers.CharField(max_length=255, required=False, default="")
    reference = serializers.CharField(max_length=128, required=False, default="")


# ── Referral Management ────────────────────────────────────────────────────────

class ReferralProfileAdminSerializer(serializers.ModelSerializer):
    tenant_name = serializers.CharField(source="tenant.name", read_only=True)
    tenant_type = serializers.CharField(source="tenant.type", read_only=True)
    tenant_is_active = serializers.BooleanField(source="tenant.is_active", read_only=True)

    class Meta:
        model = ReferralProfile
        fields = [
            "id", "tenant", "tenant_name", "tenant_type", "tenant_is_active",
            "referral_code", "coin_balance", "total_earned", "total_redeemed",
            "referral_count", "created_at", "updated_at",
        ]
        read_only_fields = ["referral_code", "coin_balance", "total_earned", "total_redeemed", "created_at", "updated_at"]


class ReferralAdminSerializer(serializers.ModelSerializer):
    referrer_name = serializers.CharField(source="referrer.name", read_only=True)
    referred_name = serializers.CharField(source="referred.name", read_only=True)
    referrer_type = serializers.CharField(source="referrer.type", read_only=True)
    referred_type = serializers.CharField(source="referred.type", read_only=True)

    class Meta:
        model = Referral
        fields = [
            "id", "referrer", "referrer_name", "referrer_type",
            "referred", "referred_name", "referred_type",
            "status", "bonus_awarded", "tracked_requests",
            "coins_from_usage", "created_at", "updated_at",
        ]
        read_only_fields = ["created_at", "updated_at"]
