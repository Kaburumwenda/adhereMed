from django.contrib import admin
from .models import PrescriptionExchange, PharmacyQuote


@admin.register(PrescriptionExchange)
class PrescriptionExchangeAdmin(admin.ModelAdmin):
    list_display = ('id', 'prescription_ref', 'patient_user_id', 'status', 'created_at')
    list_filter = ('status',)


@admin.register(PharmacyQuote)
class PharmacyQuoteAdmin(admin.ModelAdmin):
    list_display = ('id', 'exchange', 'pharmacy_name', 'total_cost', 'status')
    list_filter = ('status',)
