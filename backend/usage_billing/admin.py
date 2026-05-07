from django.contrib import admin

from .models import BillingRate, DailyUsage, DoctorCommissionRate, MonthlyBill


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
