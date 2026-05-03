from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('wards', views.WardViewSet, basename='ward')
router.register('beds', views.BedViewSet, basename='bed')
router.register('admissions', views.AdmissionViewSet, basename='admission')

urlpatterns = [
    path('', include(router.urls)),
]
