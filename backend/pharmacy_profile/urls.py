from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('profile', views.PharmacyDetailViewSet, basename='pharmacydetail')
router.register('deliveries', views.DeliveryViewSet, basename='delivery')
router.register('branches', views.BranchViewSet, basename='branch')

urlpatterns = [
    path('', include(router.urls)),
]
