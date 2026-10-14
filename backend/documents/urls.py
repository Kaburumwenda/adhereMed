from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('categories', views.DocumentCategoryViewSet, basename='doc-category')
router.register('tags', views.TagViewSet, basename='doc-tag')
router.register('documents', views.DocumentViewSet, basename='document')
router.register('comments', views.DocumentCommentViewSet, basename='doc-comment')
router.register('shares', views.DocumentShareViewSet, basename='doc-share')
router.register('activities', views.DocumentActivityViewSet, basename='doc-activity')
router.register('signatures', views.SignatureRequestViewSet, basename='doc-signature')

urlpatterns = [
    path('', include(router.urls)),
]
