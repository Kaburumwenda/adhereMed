from django.urls import path
from . import views

app_name = 'tenants'

urlpatterns = [
    path('register/', views.TenantRegistrationView.as_view(), name='register'),
    path('hospitals/', views.PublicHospitalListView.as_view(), name='public-hospitals'),
    path('', views.TenantListView.as_view(), name='list'),
    path('<slug:slug>/', views.TenantDetailView.as_view(), name='detail'),
]
