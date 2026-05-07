from django.contrib import admin

from .models import DispensingRecord, DispenseReturn


@admin.register(DispensingRecord)
class DispensingRecordAdmin(admin.ModelAdmin):
    list_display = ('receipt_number', 'patient_name', 'total', 'payment_method', 'status', 'dispensed_at')
    list_filter = ('status', 'payment_method', 'dispensed_at')
    search_fields = ('receipt_number', 'patient_name', 'patient_phone')
    readonly_fields = ('receipt_number', 'dispensed_at')


@admin.register(DispenseReturn)
class DispenseReturnAdmin(admin.ModelAdmin):
    list_display = ('reference', 'original', 'refund_amount', 'reason', 'created_at')
    list_filter = ('reason', 'created_at')
    search_fields = ('reference', 'original__receipt_number')
    readonly_fields = ('reference', 'created_at')
