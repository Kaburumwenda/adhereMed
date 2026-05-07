from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('providers', views.InsuranceProviderViewSet, basename='insuranceprovider')
router.register('claims', views.InsuranceClaimViewSet, basename='insuranceclaim')

urlpatterns = [path('', include(router.urls))]
