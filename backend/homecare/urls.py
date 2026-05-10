from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

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
router.register('audit-events', views.AuditEventViewSet, basename='homecare-audit-event')
router.register('drug-interactions', views.DrugInteractionViewSet, basename='homecare-drug-interaction')
router.register('safety-alerts', views.PrescriptionSafetyAlertViewSet, basename='homecare-safety-alert')
router.register('care-pathways', views.CarePathwayViewSet, basename='homecare-care-pathway')
router.register('pathway-enrollments', views.CarePathwayEnrollmentViewSet, basename='homecare-pathway-enrollment')

urlpatterns = [
    path('', include(router.urls)),
    path('dashboard/summary/', views.dashboard_summary, name='homecare-dashboard'),
    path('caregivers/me/my-day/', views.caregiver_my_day, name='homecare-my-day'),
    path('events/stream/', views.event_stream, name='homecare-event-stream'),
    # Tenant mailbox (homecare tenants only)
    path('mail/folders/', views.mail_folders, name='homecare-mail-folders'),
    path('mail/messages/', views.mail_messages, name='homecare-mail-messages'),
    path('mail/messages/<str:uid>/', views.mail_message_detail, name='homecare-mail-message'),
    path('mail/messages/<str:uid>/seen/', views.mail_mark_seen, name='homecare-mail-seen'),
    path('mail/send/', views.mail_send, name='homecare-mail-send'),
    path('mail/account/', views.mail_account_settings, name='homecare-mail-account'),
    path('mail/account/test/', views.mail_account_test, name='homecare-mail-account-test'),
]
