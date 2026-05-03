from django.urls import path
from . import views

app_name = "superadmin"

urlpatterns = [
    # Platform stats
    path("stats/", views.platform_stats, name="platform-stats"),

    # Tenant management
    path("tenants/", views.TenantListView.as_view(), name="tenant-list"),
    path("tenants/<int:pk>/", views.TenantDetailView.as_view(), name="tenant-detail"),
    path("tenants/<int:pk>/toggle-active/", views.toggle_tenant_active, name="tenant-toggle-active"),
    path("tenants/<int:pk>/stats/", views.tenant_stats, name="tenant-stats"),

    # User management
    path("users/", views.UserListView.as_view(), name="user-list"),
    path("users/<int:pk>/", views.UserDetailView.as_view(), name="user-detail"),
    path("users/<int:pk>/reset-password/", views.reset_user_password, name="user-reset-password"),
    path("users/<int:pk>/toggle-active/", views.toggle_user_active, name="user-toggle-active"),

    # Seed data
    path("seed/", views.seed_catalog, name="seed-catalog"),
    path("seed/run/", views.run_seed, name="seed-run"),
]
