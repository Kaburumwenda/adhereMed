from django.urls import path
from . import views

app_name = 'tenants'

urlpatterns = [
    path('register/', views.TenantRegistrationView.as_view(), name='register'),
    path('hospitals/', views.PublicHospitalListView.as_view(), name='public-hospitals'),
    # Self-service organization profile (must precede the slug route)
    path('me/', views.TenantMeView.as_view(), name='tenant-me'),
    path('me/upload-logo/', views.TenantMeLogoUploadView.as_view(), name='tenant-me-logo'),
    path('', views.TenantListView.as_view(), name='list'),
    path('<slug:slug>/', views.TenantDetailView.as_view(), name='detail'),
]
