from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('orders', views.PurchaseOrderViewSet, basename='purchaseorder')
router.register('grns', views.GoodsReceivedNoteViewSet, basename='goodsreceivednote')
router.register('rfqs', views.RequestForQuotationViewSet, basename='rfq')
router.register('quotes', views.RFQQuoteViewSet, basename='rfqquote')
router.register('evaluations', views.SupplierEvaluationViewSet, basename='evaluation')
router.register('reorder-suggestions', views.ReorderSuggestionViewSet, basename='reorder-suggestion')

urlpatterns = [
    path('dashboard/', views.ProcurementDashboardView.as_view(), name='procurement-dashboard'),
    path('', include(router.urls)),
]
