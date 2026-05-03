from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('catalog', views.LabTestCatalogViewSet, basename='labtestcatalog')
router.register('orders', views.LabOrderViewSet, basename='laborder')
router.register('results', views.LabResultViewSet, basename='labresult')
router.register('home-visits', views.HomeSampleVisitViewSet, basename='homesamplevisit')

urlpatterns = [
    path('', include(router.urls)),
]
