from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('directory', views.DoctorDirectoryViewSet, basename='doctor-directory')

urlpatterns = [
    path('register/', views.DoctorRegisterView.as_view(), name='doctor-register'),
    path('me/', views.MyDoctorProfileView.as_view(), name='doctor-me'),
    path('', include(router.urls)),
]
