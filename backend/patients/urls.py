from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('', views.PatientViewSet, basename='patient')

urlpatterns = [
    path('register/', views.PatientRegistrationView.as_view(), name='patient-register'),
    path('', include(router.urls)),
]
