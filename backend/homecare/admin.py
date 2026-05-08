from django.contrib import admin
from .models import (
    HomecareCompanyProfile, Caregiver, HomecarePatient, CaregiverSchedule,
    CaregiverNote, TreatmentPlan, MedicationSchedule, DoseEvent,
    EscalationRule, Escalation, TeleconsultRoom, HomecareAppointment,
    HomecarePrescription, PharmacyStockAlert, InsurancePolicy, InsuranceClaim,
    Consent,
)


@admin.register(HomecareCompanyProfile)
class HomecareCompanyProfileAdmin(admin.ModelAdmin):
    list_display = ('legal_name', 'city', 'country', 'updated_at')


@admin.register(Caregiver)
class CaregiverAdmin(admin.ModelAdmin):
    list_display = ('user', 'license_number', 'is_available', 'rating',
                    'employment_status', 'total_visits')
    list_filter = ('employment_status', 'is_available', 'is_independent')
    search_fields = ('user__email', 'user__first_name', 'user__last_name', 'license_number')


@admin.register(HomecarePatient)
class HomecarePatientAdmin(admin.ModelAdmin):
    list_display = ('medical_record_number', 'user', 'risk_level',
                    'assigned_caregiver', 'is_active', 'enrolled_at')
    list_filter = ('risk_level', 'is_active')
    search_fields = ('medical_record_number', 'user__email', 'user__first_name', 'user__last_name')


@admin.register(CaregiverSchedule)
class CaregiverScheduleAdmin(admin.ModelAdmin):
    list_display = ('caregiver', 'patient', 'shift_type', 'start_at', 'end_at', 'status')
    list_filter = ('status', 'shift_type')


@admin.register(CaregiverNote)
class CaregiverNoteAdmin(admin.ModelAdmin):
    list_display = ('patient', 'caregiver', 'category', 'recorded_at')
    list_filter = ('category',)


@admin.register(TreatmentPlan)
class TreatmentPlanAdmin(admin.ModelAdmin):
    list_display = ('title', 'patient', 'status', 'start_date', 'end_date')
    list_filter = ('status',)


@admin.register(MedicationSchedule)
class MedicationScheduleAdmin(admin.ModelAdmin):
    list_display = ('medication_name', 'patient', 'dose', 'route', 'is_active', 'start_date')
    list_filter = ('route', 'is_active', 'requires_caregiver')
    search_fields = ('medication_name', 'patient__user__first_name', 'patient__user__last_name')


@admin.register(DoseEvent)
class DoseEventAdmin(admin.ModelAdmin):
    list_display = ('schedule', 'scheduled_at', 'status', 'administered_at')
    list_filter = ('status',)


@admin.register(EscalationRule)
class EscalationRuleAdmin(admin.ModelAdmin):
    list_display = ('name', 'missed_doses_window_hours', 'missed_count_threshold', 'is_active')


@admin.register(Escalation)
class EscalationAdmin(admin.ModelAdmin):
    list_display = ('reason', 'patient', 'severity', 'status', 'triggered_at')
    list_filter = ('status', 'severity')


@admin.register(TeleconsultRoom)
class TeleconsultRoomAdmin(admin.ModelAdmin):
    list_display = ('room_token', 'patient', 'doctor_user_id', 'scheduled_at', 'status')
    list_filter = ('status', 'provider')


@admin.register(HomecareAppointment)
class HomecareAppointmentAdmin(admin.ModelAdmin):
    list_display = ('patient', 'appointment_type', 'scheduled_at', 'status')
    list_filter = ('appointment_type', 'status')


@admin.register(HomecarePrescription)
class HomecarePrescriptionAdmin(admin.ModelAdmin):
    list_display = ('patient', 'forwarded_pharmacy_name', 'pharmacy_status', 'created_at')
    list_filter = ('pharmacy_status',)


@admin.register(PharmacyStockAlert)
class PharmacyStockAlertAdmin(admin.ModelAdmin):
    list_display = ('medication_name', 'patient', 'stock_status', 'resolved', 'created_at')
    list_filter = ('stock_status', 'resolved')


@admin.register(InsurancePolicy)
class InsurancePolicyAdmin(admin.ModelAdmin):
    list_display = ('provider_name', 'policy_number', 'patient', 'is_primary', 'is_active')
    list_filter = ('is_primary', 'is_active')


@admin.register(InsuranceClaim)
class InsuranceClaimAdmin(admin.ModelAdmin):
    list_display = ('claim_number', 'patient', 'claim_type', 'amount_requested',
                    'status', 'submitted_at')
    list_filter = ('status', 'claim_type')


@admin.register(Consent)
class ConsentAdmin(admin.ModelAdmin):
    list_display = ('patient', 'scope', 'granted_to', 'granted_at', 'expires_at', 'revoked_at')
    list_filter = ('scope',)
