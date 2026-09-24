"""
Independent API namespace for inventory / warehouse (IMS) tenants.

Reuses the shared business-profile, branch (warehouse) and seed views so
inventory tenants never call /api/pharmacy-profile/* endpoints. All
inventory-tenant frontend features talk to /api/ims/* instead.
"""
from django.urls import path, include
from rest_framework.routers import DefaultRouter

from pharmacy_profile import views as business_views

router = DefaultRouter()
# Warehouses (shared Branch model, served under the IMS namespace)
router.register('branches', business_views.BranchViewSet, basename='ims-branch')
# Business profile (name, license, hours, services — shared model)
router.register('profile', business_views.PharmacyDetailViewSet, basename='ims-profile')
# Deliveries (sales order / POS transaction fulfilment)
router.register('deliveries', business_views.DeliveryViewSet, basename='ims-delivery')

urlpatterns = [
    path('', include(router.urls)),
    # Setup / seed catalog (categories, units, medications, interactions)
    path('setup/seed/', business_views.pharmacy_seed_catalog, name='ims-seed-catalog'),
    path('setup/seed/run/', business_views.pharmacy_run_seed, name='ims-run-seed'),
]
