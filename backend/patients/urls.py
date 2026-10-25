from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
# Registered BEFORE the bare '' patient route: the patient detail pattern
# (`^(?P<pk>[^/.]+)/$`) would otherwise swallow `care-notes/` / `vitals/` as a pk.
router.register('care-notes', views.CareNoteViewSet, basename='care-note')
router.register('vitals', views.VitalObservationViewSet, basename='vital-observation')
router.register('', views.PatientViewSet, basename='patient')

urlpatterns = [
    path('register/', views.PatientRegistrationView.as_view(), name='patient-register'),
    path('seed-demo-data/', views.seed_demo_data, name='seed-demo-data'),
    path('clear-demo-data/', views.clear_demo_data, name='clear-demo-data'),
    path('', include(router.urls)),
]
