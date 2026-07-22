from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views
from . import hr_views

router = DefaultRouter()
router.register('company-profile', views.HomecareCompanyProfileViewSet, basename='company-profile')
router.register('caregivers', views.CaregiverViewSet, basename='caregiver')
router.register('patients', views.HomecarePatientViewSet, basename='homecare-patient')
router.register('schedules', views.CaregiverScheduleViewSet, basename='caregiver-schedule')
router.register('notes', views.CaregiverNoteViewSet, basename='caregiver-note')
router.register('treatment-plans', views.TreatmentPlanViewSet, basename='treatment-plan')
router.register('medication-schedules', views.MedicationScheduleViewSet, basename='medication-schedule')
router.register('doses', views.DoseEventViewSet, basename='dose-event')
router.register('escalation-rules', views.EscalationRuleViewSet, basename='escalation-rule')
router.register('escalations', views.EscalationViewSet, basename='escalation')
router.register('vitals', views.HomecareVitalsViewSet, basename='homecare-vitals')
router.register('teleconsult-rooms', views.TeleconsultRoomViewSet, basename='teleconsult-room')
router.register('appointments', views.HomecareAppointmentViewSet, basename='homecare-appointment')
router.register('prescriptions', views.HomecarePrescriptionViewSet, basename='homecare-prescription')
router.register('stock-alerts', views.PharmacyStockAlertViewSet, basename='stock-alert')
router.register('insurance-policies', views.InsurancePolicyViewSet, basename='insurance-policy')
router.register('insurance-claims', views.InsuranceClaimViewSet, basename='insurance-claim')
router.register('consents', views.ConsentViewSet, basename='consent')
router.register('diagnoses', views.HomecareDiagnosisViewSet, basename='homecare-diagnosis')
router.register('allergies', views.HomecareAllergyViewSet, basename='homecare-allergy')
router.register('devices', views.DeviceViewSet, basename='homecare-device')
router.register('device-assignments', views.DeviceAssignmentViewSet, basename='homecare-device-assignment')
router.register('device-maintenance', views.DeviceMaintenanceViewSet, basename='homecare-device-maintenance')
router.register('drains-lines', views.DrainLineViewSet, basename='homecare-drain-line')
router.register('audit-events', views.AuditEventViewSet, basename='homecare-audit-event')
router.register('drug-interactions', views.DrugInteractionViewSet, basename='homecare-drug-interaction')
router.register('safety-alerts', views.PrescriptionSafetyAlertViewSet, basename='homecare-safety-alert')
router.register('care-pathways', views.CarePathwayViewSet, basename='homecare-care-pathway')
router.register('pathway-enrollments', views.CarePathwayEnrollmentViewSet, basename='homecare-pathway-enrollment')
router.register('care-plans', views.CarePlanViewSet, basename='homecare-care-plan')
router.register('medical-supplies', views.MedicalSupplyViewSet, basename='homecare-medical-supply')
router.register('patient-bills', views.PatientBillViewSet, basename='homecare-patient-bill')
router.register('patient-payments', views.PatientPaymentViewSet, basename='homecare-patient-payment')
router.register('assessment-sessions', views.AssessmentSessionViewSet, basename='homecare-assessment-session')
router.register('braden-assessments', views.BradenAssessmentViewSet, basename='homecare-braden-assessment')
router.register('caprini-assessments', views.CapriniAssessmentViewSet, basename='homecare-caprini-assessment')
router.register('morse-assessments', views.MorseAssessmentViewSet, basename='homecare-morse-assessment')
router.register('must-assessments', views.MustAssessmentViewSet, basename='homecare-must-assessment')
router.register('cam-assessments', views.CamAssessmentViewSet, basename='homecare-cam-assessment')
router.register('pain-assessments', views.PainAssessmentViewSet, basename='homecare-pain-assessment')
router.register('skin-care-assessments', views.SkinCareAssessmentViewSet, basename='homecare-skin-care-assessment')
router.register('gcs-assessments', views.GcsAssessmentViewSet, basename='homecare-gcs-assessment')
router.register('diabetes-bundle-assessments', views.DiabetesBundleAssessmentViewSet, basename='homecare-diabetes-bundle-assessment')
router.register('hf-bundle-assessments', views.HeartFailureBundleAssessmentViewSet, basename='homecare-hf-bundle-assessment')
router.register('pivc-assessments', views.PIVCAssessmentViewSet, basename='homecare-pivc-assessment')
router.register('enteral-feeding-assessments', views.EnteralFeedingAssessmentViewSet, basename='homecare-enteral-feeding-assessment')
router.register('urinary-catheter-assessments', views.UrinaryCatheterAssessmentViewSet, basename='homecare-urinary-catheter-assessment')
router.register('artificial-airway-assessments', views.ArtificialAirwayAssessmentViewSet, basename='homecare-artificial-airway-assessment')
router.register('cvad-assessments', views.CVADAssessmentViewSet, basename='homecare-cvad-assessment')
router.register('patient-documents', views.PatientDocumentViewSet, basename='homecare-patient-document')

# ── HR module router ──
hr_router = DefaultRouter()
hr_router.register('employees', hr_views.HREmployeeViewSet, basename='hr-employee')
hr_router.register('leave-requests', hr_views.LeaveRequestViewSet, basename='hr-leave-request')
hr_router.register('leave-balances', hr_views.LeaveBalanceViewSet, basename='hr-leave-balance')
hr_router.register('shifts', hr_views.ShiftViewSet, basename='hr-shift')
hr_router.register('timesheets', hr_views.TimesheetViewSet, basename='hr-timesheet')
hr_router.register('payroll', hr_views.PayrollEntryViewSet, basename='hr-payroll')
hr_router.register('benefits', hr_views.BenefitPlanViewSet, basename='hr-benefit')
hr_router.register('jobs', hr_views.JobOpeningViewSet, basename='hr-job')
hr_router.register('applicants', hr_views.ApplicantViewSet, basename='hr-applicant')
hr_router.register('onboarding', hr_views.OnboardingRecordViewSet, basename='hr-onboarding')
hr_router.register('onboarding-templates', hr_views.OnboardingTemplateViewSet, basename='hr-onboarding-template')
hr_router.register('training-programs', hr_views.TrainingProgramViewSet, basename='hr-training-program')
hr_router.register('performance-reviews', hr_views.PerformanceReviewViewSet, basename='hr-performance-review')
hr_router.register('goals', hr_views.GoalViewSet, basename='hr-goal')
hr_router.register('compliance/violations', hr_views.ComplianceViolationViewSet, basename='hr-compliance-violation')
hr_router.register('compliance/certifications', hr_views.CertificationViewSet, basename='hr-certification')
hr_router.register('compliance/reports', hr_views.ComplianceReportViewSet, basename='hr-compliance-report')
hr_router.register('documents', hr_views.HRDocumentViewSet, basename='hr-document')

urlpatterns = [
    path('', include(router.urls)),
    path('billing-settings/', views.billing_settings, name='homecare-billing-settings'),
    path('dashboard/summary/', views.dashboard_summary, name='homecare-dashboard'),
    path('caregivers/me/my-day/', views.caregiver_my_day, name='homecare-my-day'),
    path('events/stream/', views.event_stream, name='homecare-event-stream'),
    # ── Analytics ──
    path('analytics/overview/', views.analytics_overview, name='homecare-analytics-overview'),
    path('analytics/patients/', views.analytics_patients, name='homecare-analytics-patients'),
    path('analytics/workforce/', views.analytics_workforce, name='homecare-analytics-workforce'),
    path('analytics/visits/', views.analytics_visits, name='homecare-analytics-visits'),
    path('analytics/adherence/', views.analytics_adherence, name='homecare-analytics-adherence'),
    path('analytics/escalations/', views.analytics_escalations, name='homecare-analytics-escalations'),
    path('analytics/financials/', views.analytics_financials, name='homecare-analytics-financials'),
    path('analytics/insurance/', views.analytics_insurance, name='homecare-analytics-insurance'),
    path('analytics/equipment/', views.analytics_equipment, name='homecare-analytics-equipment'),
    path('analytics/equipment-hire/', views.analytics_equipment_hire, name='homecare-analytics-equipment-hire'),
    # Tenant mailbox (homecare tenants only)
    path('mail/folders/', views.mail_folders, name='homecare-mail-folders'),
    path('mail/messages/', views.mail_messages, name='homecare-mail-messages'),
    path('mail/messages/<str:uid>/', views.mail_message_detail, name='homecare-mail-message'),
    path('mail/messages/<str:uid>/seen/', views.mail_mark_seen, name='homecare-mail-seen'),
    path('mail/send/', views.mail_send, name='homecare-mail-send'),
    path('mail/account/', views.mail_account_settings, name='homecare-mail-account'),
    path('mail/account/test/', views.mail_account_test, name='homecare-mail-account-test'),
    # ── HR module ──
    path('hr/', include(hr_router.urls)),
    path('hr/dashboard/', hr_views.hr_dashboard, name='hr-dashboard'),
    path('hr/leave-calendar/', hr_views.leave_calendar, name='hr-leave-calendar'),
    path('hr/attendance/today/', hr_views.attendance_today, name='hr-attendance-today'),
    path('hr/attendance/clock/', hr_views.attendance_clock, name='hr-attendance-clock'),
    path('hr/performance/leaderboard/', hr_views.performance_leaderboard, name='hr-performance-leaderboard'),
    path('hr/compliance/working-hours/', hr_views.compliance_working_hours, name='hr-compliance-working-hours'),
]
