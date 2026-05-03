from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('pharmacy-rx', views.PharmacyPrescriptionViewSet, basename='pharmacy-prescription')
router.register('', views.PrescriptionViewSet, basename='prescription')

urlpatterns = [
    path('', include(router.urls)),
]
