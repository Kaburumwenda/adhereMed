from django.urls import include, path
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('customers', views.CustomerCRMViewSet, basename='crm-customer')
router.register('profiles', views.CustomerProfileViewSet, basename='crm-profile')
router.register('segments', views.SegmentViewSet, basename='crm-segment')
router.register('tags', views.TagViewSet, basename='crm-tag')
router.register('interactions', views.InteractionViewSet, basename='crm-interaction')
router.register('tickets', views.TicketViewSet, basename='crm-ticket')
router.register('opportunities', views.OpportunityViewSet, basename='crm-opportunity')
router.register('campaigns', views.CampaignViewSet, basename='crm-campaign')
router.register('tasks', views.TaskViewSet, basename='crm-task')
router.register('feedback', views.FeedbackViewSet, basename='crm-feedback')
router.register('points', views.PointsEntryViewSet, basename='crm-points')

urlpatterns = [
    path('', include(router.urls)),
]
