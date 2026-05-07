from django.contrib import admin
from .models import InsuranceProvider, InsuranceClaim


@admin.register(InsuranceProvider)
class InsuranceProviderAdmin(admin.ModelAdmin):
    list_display = ('name', 'code', 'phone', 'is_active')
    search_fields = ('name', 'code')


@admin.register(InsuranceClaim)
class InsuranceClaimAdmin(admin.ModelAdmin):
    list_display = ('reference', 'provider', 'member_name', 'claim_amount', 'approved_amount', 'paid_amount', 'status')
    list_filter = ('status', 'provider')
    search_fields = ('reference', 'member_name', 'member_number')
