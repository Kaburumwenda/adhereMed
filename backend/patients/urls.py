from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('', views.PatientViewSet, basename='patient')

urlpatterns = [
    path('register/', views.PatientRegistrationView.as_view(), name='patient-register'),
    path('seed-demo-data/', views.seed_demo_data, name='seed-demo-data'),
    path('clear-demo-data/', views.clear_demo_data, name='clear-demo-data'),
    path('', include(router.urls)),
]
