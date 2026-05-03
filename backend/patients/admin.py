from django.contrib import admin
from .models import Patient


@admin.register(Patient)
class PatientAdmin(admin.ModelAdmin):
    list_display = ('patient_number', 'user', 'gender', 'date_of_birth', 'insurance_provider')
    search_fields = ('patient_number', 'user__first_name', 'user__last_name', 'national_id')
    list_filter = ('gender',)
