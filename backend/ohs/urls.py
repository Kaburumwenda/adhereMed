from django.urls import include, path
from rest_framework.routers import DefaultRouter

from . import demo_data_views, rbac_views, views

router = DefaultRouter()
router.register('sites', views.SiteViewSet, basename='ohs-site')
router.register('hazard-categories', views.HazardCategoryViewSet, basename='ohs-hazard-category')
router.register('hazards', views.HazardViewSet, basename='ohs-hazard')
router.register('controls', views.ControlMeasureViewSet, basename='ohs-control')
router.register('risk-assessments', views.RiskAssessmentViewSet, basename='ohs-risk-assessment')
router.register('risk-items', views.RiskAssessmentItemViewSet, basename='ohs-risk-item')
router.register('incidents', views.IncidentViewSet, basename='ohs-incident')
router.register('incident-actions', views.IncidentActionViewSet, basename='ohs-incident-action')
router.register('inspections', views.InspectionViewSet, basename='ohs-inspection')
router.register('inspection-items', views.InspectionItemViewSet, basename='ohs-inspection-item')
router.register('permits', views.PermitToWorkViewSet, basename='ohs-permit')
router.register('training-courses', views.TrainingCourseViewSet, basename='ohs-training-course')
router.register('training-records', views.TrainingRecordViewSet, basename='ohs-training-record')
router.register('ppe-items', views.PpeItemViewSet, basename='ohs-ppe-item')
router.register('ppe-issues', views.PpeIssueViewSet, basename='ohs-ppe-issue')
router.register('health-surveillance', views.HealthSurveillanceViewSet, basename='ohs-health')
router.register('job-demands', views.JobDemandProfileViewSet, basename='ohs-job-demand')
router.register('assessments', views.HealthAssessmentViewSet, basename='ohs-assessment')
router.register('assessment-findings', views.AssessmentFindingViewSet,
                basename='ohs-assessment-finding')
router.register('assessment-labs', views.AssessmentLabResultViewSet,
                basename='ohs-assessment-lab')
router.register('observations', views.ObservationViewSet, basename='ohs-observation')
router.register('exposure', views.ExposureMonitoringViewSet, basename='ohs-exposure')
router.register('drills', views.EmergencyDrillViewSet, basename='ohs-drill')
router.register('legal', views.LegalRequirementViewSet, basename='ohs-legal')
router.register('audits', views.ComplianceAuditViewSet, basename='ohs-audit')
router.register('objectives', views.SafetyObjectiveViewSet, basename='ohs-objective')
router.register('documents', views.DocumentViewSet, basename='ohs-document')
router.register('document-revisions', views.DocumentRevisionViewSet, basename='ohs-document-revision')
router.register(
    'document-acknowledgements', views.DocumentAcknowledgementViewSet,
    basename='ohs-document-acknowledgement',
)
router.register('contractors', views.ContractorViewSet, basename='ohs-contractor')
router.register('engagements', views.ContractorEngagementViewSet, basename='ohs-engagement')
router.register('meetings', views.SafetyMeetingViewSet, basename='ohs-meeting')
router.register('attendance', views.MeetingAttendanceViewSet, basename='ohs-attendance')
router.register('management-reviews', views.ManagementReviewViewSet, basename='ohs-management-review')
router.register('certifications', views.CertificationViewSet, basename='ohs-certification')
router.register('equipment', views.SafetyEquipmentViewSet, basename='ohs-equipment')
router.register('equipment-inspections', views.EquipmentInspectionViewSet,
                basename='ohs-equipment-inspection')
router.register('equipment-defects', views.EquipmentDefectViewSet, basename='ohs-equipment-defect')
router.register('rbac/roles', rbac_views.OhsRoleDefinitionViewSet, basename='ohs-rbac-role')

urlpatterns = [
    path('dashboard/', views.OhsDashboardView.as_view(), name='ohs-dashboard'),
    path('intelligence/', views.OhsIntelligenceView.as_view(), name='ohs-intelligence'),
    path('alerts/', views.OhsAlertsView.as_view(), name='ohs-alerts'),
    path('search/', views.OhsSearchView.as_view(), name='ohs-search'),
    path('lookups/', views.OhsLookupsView.as_view(), name='ohs-lookups'),
    path('equipment-summary/', views.OhsEquipmentSummaryView.as_view(), name='ohs-equipment-summary'),
    path('assessment-summary/', views.OhsAssessmentSummaryView.as_view(),
         name='ohs-assessment-summary'),
    # Roles & Access (RBAC)
    path('rbac/', rbac_views.OhsRBACMatrixView.as_view(), name='ohs-rbac'),
    path('rbac/users/<int:user_id>/role/', rbac_views.OhsRBACSetUserRoleView.as_view(),
         name='ohs-rbac-set-role'),
    path('rbac/builtin-roles/<str:key>/', rbac_views.OhsRBACBuiltinRoleView.as_view(),
         name='ohs-rbac-builtin-role'),
    # Demo data (SECURITY & SETTINGS)
    path('demo-data/', demo_data_views.OhsDemoDataOverviewView.as_view(),
         name='ohs-demo-data'),
    path('demo-data/seed/', demo_data_views.OhsDemoDataSeedView.as_view(),
         name='ohs-demo-data-seed'),
    path('demo-data/clear/', demo_data_views.OhsDemoDataClearView.as_view(),
         name='ohs-demo-data-clear'),
    path('', include(router.urls)),
]
