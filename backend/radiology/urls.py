from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('orders', views.RadiologyOrderViewSet, basename='radiologyorder')
router.register('results', views.RadiologyResultViewSet, basename='radiologyresult')

urlpatterns = [
    path('', include(router.urls)),
]
