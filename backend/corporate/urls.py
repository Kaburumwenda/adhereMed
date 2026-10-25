from django.urls import include, path
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('clients', views.CorporateClientViewSet, basename='corporate-client')
router.register('staff', views.CorporateStaffViewSet, basename='corporate-staff')
router.register('documents', views.CorporateDocumentViewSet, basename='corporate-document')
router.register('dashboard', views.CorporateDashboardViewSet, basename='corporate-dashboard')

urlpatterns = [path('', include(router.urls))]
