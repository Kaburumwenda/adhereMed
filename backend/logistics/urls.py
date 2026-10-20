from django.urls import include, path
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('carriers', views.CarrierViewSet, basename='logistics-carrier')
router.register('vehicles', views.VehicleViewSet, basename='logistics-vehicle')
router.register('drivers', views.DriverViewSet, basename='logistics-driver')
router.register('zones', views.DeliveryZoneViewSet, basename='logistics-zone')
router.register('shipments', views.ShipmentViewSet, basename='logistics-shipment')
router.register('routes', views.RoutePlanViewSet, basename='logistics-route')

urlpatterns = [
    path('', include(router.urls)),
]
