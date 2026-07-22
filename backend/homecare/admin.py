from django.contrib import admin
from .models import (
    HomecareCompanyProfile, Caregiver, HomecarePatient, CaregiverSchedule,
    CaregiverNote, TreatmentPlan, MedicationSchedule, DoseEvent,
    EscalationRule, Escalation, TeleconsultRoom, HomecareAppointment,
    HomecarePrescription, PharmacyStockAlert, InsurancePolicy, InsuranceClaim,
    Consent, PatientDataSharing, BillingSettings,
    HREmployee, LeaveRequest, LeaveBalance, Shift, Attendance, Timesheet,
    BenefitPlan, BenefitEnrollment, PayrollEntry, JobOpening, Applicant,
    OnboardingTemplate, OnboardingRecord, OnboardingTask,
    TrainingProgram, TrainingEnrollment,
    PerformanceReview, Goal,
    ComplianceViolation, Certification, ComplianceReport,
    HRDocument,
)


@admin.register(HomecareCompanyProfile)
class HomecareCompanyProfileAdmin(admin.ModelAdmin):
    list_display = ('legal_name', 'city', 'country', 'updated_at')


@admin.register(BillingSettings)
class BillingSettingsAdmin(admin.ModelAdmin):
    list_display = ('billing_type', 'auto_generate', 'last_run_at', 'updated_at')
    list_filter = ('billing_type', 'auto_generate')


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


@admin.register(PatientDataSharing)
class PatientDataSharingAdmin(admin.ModelAdmin):
    list_display = ('patient', 'is_shared', 'share_vitals', 'share_medications',
                    'share_care_team', 'updated_at')
    list_filter = ('is_shared',)
    search_fields = ('patient__medical_record_number',)


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


# ── HR module ──
@admin.register(HREmployee)
class HREmployeeAdmin(admin.ModelAdmin):
    list_display = ('name', 'email', 'department', 'job_title', 'employment_type', 'status', 'hire_date')
    list_filter = ('status', 'department', 'employment_type')
    search_fields = ('first_name', 'last_name', 'email', 'phone', 'national_id', 'job_title')


@admin.register(LeaveRequest)
class LeaveRequestAdmin(admin.ModelAdmin):
    list_display = ('employee', 'leave_type', 'start_date', 'end_date', 'status', 'approved_at')
    list_filter = ('status', 'leave_type')


@admin.register(LeaveBalance)
class LeaveBalanceAdmin(admin.ModelAdmin):
    list_display = ('employee', 'annual_used', 'annual_total', 'sick_used', 'sick_total')


@admin.register(Shift)
class ShiftAdmin(admin.ModelAdmin):
    list_display = ('employee', 'date', 'shift_type', 'start_time', 'end_time')
    list_filter = ('shift_type',)


@admin.register(Attendance)
class AttendanceAdmin(admin.ModelAdmin):
    list_display = ('employee', 'date', 'clock_in', 'clock_out', 'late', 'status')
    list_filter = ('status', 'late')


@admin.register(Timesheet)
class TimesheetAdmin(admin.ModelAdmin):
    list_display = ('employee', 'date', 'hours', 'shift_type', 'status')
    list_filter = ('status', 'shift_type')


@admin.register(BenefitPlan)
class BenefitPlanAdmin(admin.ModelAdmin):
    list_display = ('name', 'type', 'employer_contribution', 'employee_contribution', 'mandatory', 'is_active')
    list_filter = ('type', 'mandatory', 'is_active')


@admin.register(BenefitEnrollment)
class BenefitEnrollmentAdmin(admin.ModelAdmin):
    list_display = ('benefit', 'employee', 'enrolled_at')


@admin.register(PayrollEntry)
class PayrollEntryAdmin(admin.ModelAdmin):
    list_display = ('employee', 'period', 'gross', 'deductions', 'net', 'status')
    list_filter = ('status', 'period')


@admin.register(JobOpening)
class JobOpeningAdmin(admin.ModelAdmin):
    list_display = ('title', 'department', 'employment_type', 'status', 'is_published', 'closing_date')
    list_filter = ('status', 'employment_type', 'is_published')


@admin.register(Applicant)
class ApplicantAdmin(admin.ModelAdmin):
    list_display = ('name', 'job', 'stage', 'rating', 'applied_date')
    list_filter = ('stage',)
    search_fields = ('name', 'email', 'phone')


@admin.register(OnboardingTemplate)
class OnboardingTemplateAdmin(admin.ModelAdmin):
    list_display = ('name', 'created_at')


@admin.register(OnboardingRecord)
class OnboardingRecordAdmin(admin.ModelAdmin):
    list_display = ('employee', 'status', 'progress', 'start_date', 'completed_at')
    list_filter = ('status',)


@admin.register(OnboardingTask)
class OnboardingTaskAdmin(admin.ModelAdmin):
    list_display = ('onboarding', 'title', 'done', 'due_date')


@admin.register(TrainingProgram)
class TrainingProgramAdmin(admin.ModelAdmin):
    list_display = ('title', 'category', 'duration_hours', 'delivery_mode', 'mandatory', 'is_active')
    list_filter = ('category', 'delivery_mode', 'mandatory', 'is_active')


@admin.register(TrainingEnrollment)
class TrainingEnrollmentAdmin(admin.ModelAdmin):
    list_display = ('program', 'employee', 'deadline', 'completed', 'enrolled_at')


@admin.register(PerformanceReview)
class PerformanceReviewAdmin(admin.ModelAdmin):
    list_display = ('employee', 'cycle_name', 'review_type', 'rating', 'review_date', 'status')
    list_filter = ('status', 'review_type')


@admin.register(Goal)
class GoalAdmin(admin.ModelAdmin):
    list_display = ('employee', 'title', 'category', 'progress', 'due_date')


@admin.register(ComplianceViolation)
class ComplianceViolationAdmin(admin.ModelAdmin):
    list_display = ('employee', 'title', 'type', 'severity', 'status', 'created_at')
    list_filter = ('status', 'severity', 'type')


@admin.register(Certification)
class CertificationAdmin(admin.ModelAdmin):
    list_display = ('employee', 'name', 'type', 'expiry_date')
    list_filter = ('type',)


@admin.register(ComplianceReport)
class ComplianceReportAdmin(admin.ModelAdmin):
    list_display = ('title', 'type', 'start_date', 'end_date', 'generated_at')
    list_filter = ('type',)


@admin.register(HRDocument)
class HRDocumentAdmin(admin.ModelAdmin):
    list_display = ('name', 'category', 'employee', 'access_level', 'expiry_date', 'uploaded_at')
    list_filter = ('category', 'access_level')
    search_fields = ('name', 'description')
