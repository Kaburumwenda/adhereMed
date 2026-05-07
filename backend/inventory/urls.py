from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('categories', views.CategoryViewSet, basename='category')
router.register('units', views.UnitViewSet, basename='unit')
router.register('stocks', views.MedicationStockViewSet, basename='medicationstock')
router.register('batches', views.StockBatchViewSet, basename='stockbatch')
router.register('adjustments', views.StockAdjustmentViewSet, basename='stockadjustment')
router.register('counts', views.InventoryCountViewSet, basename='inventorycount')
router.register('transfers', views.StockTransferViewSet, basename='stocktransfer')
router.register('controlled-register', views.ControlledSubstanceLogViewSet, basename='controlled-register')

urlpatterns = [
    path('analytics/', views.InventoryAnalyticsView.as_view(), name='inventory-analytics'),
    path('', include(router.urls)),
]
