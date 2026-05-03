from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('specializations', views.SpecializationViewSet, basename='specialization')
router.register('', views.StaffProfileViewSet, basename='staffprofile')

urlpatterns = [
    path('', include(router.urls)),
]
