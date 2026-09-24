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
router.register('rbac/roles', views.RoleDefinitionViewSet, basename='rbac-role')

urlpatterns = [
    path('analytics/', views.InventoryAnalyticsView.as_view(), name='inventory-analytics'),
    path('overview/', views.InventoryOverviewView.as_view(), name='inventory-overview'),
    path('stock-movements/', views.StockMovementReportView.as_view(), name='inventory-stock-movements'),
    path('rbac/', views.RBACMatrixView.as_view(), name='inventory-rbac'),
    path('rbac/users/<int:user_id>/role/', views.RBACSetUserRoleView.as_view(), name='inventory-rbac-set-role'),
    path('rbac/builtin-roles/<str:key>/', views.RBACBuiltinRoleOverrideView.as_view(), name='inventory-rbac-builtin-override'),
    path('', include(router.urls)),
]
