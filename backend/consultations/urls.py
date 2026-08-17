from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('', views.ConsultationViewSet, basename='consultation')
router.register('addenda', views.ConsultationAddendumViewSet, basename='consultation-addendum')

urlpatterns = [
    path('', include(router.urls)),
]
