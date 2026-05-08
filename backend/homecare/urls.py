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

urlpatterns = [
    path('', include(router.urls)),
    path('dashboard/summary/', views.dashboard_summary, name='homecare-dashboard'),
    path('caregivers/me/my-day/', views.caregiver_my_day, name='homecare-my-day'),
    path('events/stream/', views.event_stream, name='homecare-event-stream'),
]
