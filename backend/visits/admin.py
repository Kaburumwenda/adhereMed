from django.contrib import admin

from .models import ClinicSettings, PatientVisit, VisitEvent


@admin.register(PatientVisit)
class PatientVisitAdmin(admin.ModelAdmin):
    list_display = ('visit_number', 'patient', 'stage', 'doctor', 'payment_status', 'arrived_at')
    list_filter = ('stage', 'payment_status', 'priority', 'outcome')
    search_fields = ('visit_number', 'patient__user__first_name', 'patient__user__last_name')
    readonly_fields = ('visit_number', 'queue_number', 'created_at', 'updated_at')


@admin.register(VisitEvent)
class VisitEventAdmin(admin.ModelAdmin):
    list_display = ('visit', 'stage', 'action', 'actor', 'created_at')
    list_filter = ('stage', 'action')
    search_fields = ('visit__visit_number', 'action')


@admin.register(ClinicSettings)
class ClinicSettingsAdmin(admin.ModelAdmin):
    list_display = ('consultation_fee', 'currency', 'require_payment_before_triage', 'updated_at')
