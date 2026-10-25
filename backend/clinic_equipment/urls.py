from django.urls import include, path
from rest_framework.routers import DefaultRouter

from . import seed_views, views

app_name = 'clinic_equipment'

router = DefaultRouter()
router.register('categories', views.EquipmentCategoryViewSet, basename='equipment-category')
router.register('items', views.EquipmentViewSet, basename='equipment')
router.register('maintenance', views.EquipmentMaintenanceViewSet, basename='equipment-maintenance')
router.register('faults', views.EquipmentFaultViewSet, basename='equipment-fault')
router.register('transfers', views.EquipmentTransferViewSet, basename='equipment-transfer')

urlpatterns = [
    path('dashboard/', views.EquipmentDashboardView.as_view(), name='dashboard'),
    # Seeding — surfaced on /clinics/seed-data
    path('seed/catalog/', seed_views.equipment_seed_catalog, name='seed-catalog'),
    path('seed/run/', seed_views.equipment_run_seed, name='seed-run'),
    path('seed/history/', seed_views.equipment_seed_history, name='seed-history'),
    path('', include(router.urls)),
]
