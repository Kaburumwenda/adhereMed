from django.contrib import admin
from .models import DispensingRecord


@admin.register(DispensingRecord)
class DispensingRecordAdmin(admin.ModelAdmin):
    list_display = ('id', 'patient_name', 'total', 'dispensed_by', 'dispensed_at')
