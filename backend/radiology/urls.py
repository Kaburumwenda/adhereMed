from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('modalities', views.ImagingModalityViewSet, basename='imagingmodality')
router.register('exam-catalog', views.ExamCatalogViewSet, basename='examcatalog')
router.register('exam-panels', views.ExamPanelViewSet, basename='exampanel')
router.register('referring-facilities', views.ReferringFacilityViewSet, basename='referringfacility')
router.register('referring-doctors', views.ReferringDoctorViewSet, basename='referringdoctor')
router.register('orders', views.RadiologyOrderViewSet, basename='radiologyorder')
router.register('order-extras', views.RadiologyOrderExtraViewSet, basename='radiologyorderextra')
router.register('schedules', views.RadiologyScheduleViewSet, basename='radiologyschedule')
router.register('contrast', views.ContrastAdministrationViewSet, basename='contrastadministration')
router.register('dose-records', views.DoseRecordViewSet, basename='doserecord')
router.register('results', views.RadiologyResultViewSet, basename='radiologyresult')
router.register('report-templates', views.ReportTemplateViewSet, basename='reporttemplate')
router.register('reports', views.RadiologyReportViewSet, basename='radiologyreport')
router.register('critical-alerts', views.CriticalFindingAlertViewSet, basename='criticalfindingalert')
router.register('qc', views.QualityControlRecordViewSet, basename='qualitycontrolrecord')
router.register('invoices', views.RadiologyInvoiceViewSet, basename='radiologyinvoice')
router.register('invoice-items', views.RadiologyInvoiceItemViewSet, basename='radiologyinvoiceitem')
router.register('payments', views.RadiologyPaymentViewSet, basename='radiologypayment')

urlpatterns = [
    path('', include(router.urls)),
]
