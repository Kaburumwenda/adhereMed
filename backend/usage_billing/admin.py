from django.contrib import admin

from .models import BillingRate, DailyUsage, DoctorCommissionRate, MonthlyBill
from .referral_models import CoinTransaction, Referral, ReferralProfile
from .payment_models import (
    MpesaTransaction,
    PaymentGatewayConfig,
    TenantWallet,
    WalletTransaction,
)


@admin.register(BillingRate)
class BillingRateAdmin(admin.ModelAdmin):
    list_display = ("id", "requests_per_unit", "unit_cost", "currency", "is_active", "effective_from")
    list_filter = ("is_active", "currency")


@admin.register(DailyUsage)
class DailyUsageAdmin(admin.ModelAdmin):
    list_display = ("tenant", "date", "request_count", "last_updated")
    list_filter = ("date",)
    search_fields = ("tenant__name", "tenant__schema_name")


@admin.register(MonthlyBill)
class MonthlyBillAdmin(admin.ModelAdmin):
    list_display = ("tenant", "year", "month", "total_requests", "amount", "currency", "status")
    list_filter = ("status", "year", "month", "currency")
    search_fields = ("tenant__name",)


@admin.register(DoctorCommissionRate)
class DoctorCommissionRateAdmin(admin.ModelAdmin):
    list_display = ("id", "percentage", "currency", "is_active", "effective_from")
    list_filter = ("is_active", "currency")


@admin.register(ReferralProfile)
class ReferralProfileAdmin(admin.ModelAdmin):
    list_display = ("tenant", "referral_code", "coin_balance", "total_earned", "referral_count", "created_at")
    search_fields = ("tenant__name", "referral_code")
    readonly_fields = ("referral_code",)


@admin.register(Referral)
class ReferralAdmin(admin.ModelAdmin):
    list_display = ("referrer", "referred", "status", "bonus_awarded", "tracked_requests", "coins_from_usage", "created_at")
    list_filter = ("status", "bonus_awarded")
    search_fields = ("referrer__name", "referred__name")


@admin.register(CoinTransaction)
class CoinTransactionAdmin(admin.ModelAdmin):
    list_display = ("profile", "type", "amount", "reason", "created_at")
    list_filter = ("type",)
    search_fields = ("profile__tenant__name", "reason")


@admin.register(PaymentGatewayConfig)
class PaymentGatewayConfigAdmin(admin.ModelAdmin):
    list_display = ("name", "is_active", "stk_push_url", "confirm_url", "source", "updated_at")


@admin.register(TenantWallet)
class TenantWalletAdmin(admin.ModelAdmin):
    list_display = ("tenant", "balance", "currency", "updated_at")
    search_fields = ("tenant__name", "tenant__schema_name")


@admin.register(WalletTransaction)
class WalletTransactionAdmin(admin.ModelAdmin):
    list_display = ("wallet", "type", "amount", "balance_after", "reason", "created_at")
    list_filter = ("type",)
    search_fields = ("wallet__tenant__name", "reason")


@admin.register(MpesaTransaction)
class MpesaTransactionAdmin(admin.ModelAdmin):
    list_display = ("tenant", "purpose", "amount", "currency", "status", "phone", "checkout_request_id", "created_at")
    list_filter = ("status", "purpose", "currency")
    search_fields = ("tenant__name", "phone", "checkout_request_id")
    readonly_fields = ("initiate_response", "confirm_response", "created_at", "completed_at")
