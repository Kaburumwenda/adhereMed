from django.urls import include, path
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('events', views.VisitEventViewSet, basename='visit-event')
router.register('', views.PatientVisitViewSet, basename='patient-visit')

urlpatterns = [
    path('settings/', views.ClinicSettingsView.as_view({'get': 'list', 'patch': 'partial_update'}),
         name='clinic-frontdesk-settings'),
    path('', include(router.urls)),
]
