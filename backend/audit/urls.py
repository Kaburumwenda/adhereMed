from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import AuditEventViewSet

router = DefaultRouter()
router.register('events', AuditEventViewSet, basename='audit-event')

app_name = 'audit'

urlpatterns = [
    path('', include(router.urls)),
]
