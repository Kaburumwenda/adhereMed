from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('directory', views.DoctorDirectoryViewSet, basename='doctor-directory')

urlpatterns = [
    path('register/', views.DoctorRegisterView.as_view(), name='doctor-register'),
    path('me/', views.MyDoctorProfileView.as_view(), name='doctor-me'),
    path('me/upload-picture/', views.UploadDoctorPictureView.as_view(), name='doctor-upload-picture'),
    path('me/upload-signature/', views.UploadDoctorSignatureView.as_view(), name='doctor-upload-signature'),
    path('me/delete-signature/', views.DeleteDoctorSignatureView.as_view(), name='doctor-delete-signature'),
    path('', include(router.urls)),
]
