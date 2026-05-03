from django.contrib import admin
from .models import Medication


@admin.register(Medication)
class MedicationAdmin(admin.ModelAdmin):
    list_display = ('generic_name', 'category', 'dosage_form', 'strength', 'requires_prescription', 'is_active')
    list_filter = ('category', 'dosage_form', 'requires_prescription', 'is_active')
    search_fields = ('generic_name', 'brand_names')
