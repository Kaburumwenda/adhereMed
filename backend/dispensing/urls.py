from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('returns', views.DispenseReturnViewSet, basename='dispensereturn')
router.register('', views.DispensingRecordViewSet, basename='dispensingrecord')

urlpatterns = [
    path('', include(router.urls)),
]
