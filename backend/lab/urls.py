from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('catalog', views.LabTestCatalogViewSet, basename='labtestcatalog')
router.register('orders', views.LabOrderViewSet, basename='laborder')
router.register('results', views.LabResultViewSet, basename='labresult')
router.register('home-visits', views.HomeSampleVisitViewSet, basename='homesamplevisit')
router.register('panels', views.LabPanelViewSet, basename='labpanel')
router.register('referring-facilities', views.ReferringFacilityViewSet, basename='referringfacility')
router.register('referring-doctors', views.ReferringDoctorViewSet, basename='referringdoctor')
router.register('instruments', views.InstrumentViewSet, basename='instrument')
router.register('specimens', views.SpecimenViewSet, basename='specimen')
router.register('qc', views.QualityControlRunViewSet, basename='qcrun')
router.register('invoices', views.LabInvoiceViewSet, basename='labinvoice')
router.register('invoice-items', views.LabInvoiceItemViewSet, basename='labinvoiceitem')
router.register('invoice-payments', views.LabInvoicePaymentViewSet, basename='labinvoicepayment')
router.register('report-templates', views.ReportTemplateViewSet, basename='reporttemplate')
router.register('order-extras', views.LabOrderExtraViewSet, basename='laborderextra')
router.register('result-audits', views.LabResultAuditViewSet, basename='labresultaudit')
router.register('reagents', views.LabReagentViewSet, basename='labreagent')
router.register('reagent-lots', views.ReagentLotViewSet, basename='reagentlot')
router.register('reagent-transactions', views.ReagentTransactionViewSet, basename='reagenttxn')

urlpatterns = [
    path('', include(router.urls)),
]
