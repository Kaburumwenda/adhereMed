from django.urls import path
from . import views
from . import admin_views

app_name = 'organizations'

urlpatterns = [
    path('me/', views.organization_me, name='org-me'),
    path('stats/', views.organization_stats, name='org-stats'),
    path('traffic/', views.organization_traffic, name='org-traffic'),
    path('switch-tenant/', views.switch_tenant, name='switch-tenant'),
    path('switch-back/', views.switch_back, name='switch-back'),

    # ── Superadmin CRUD ──
    path('admin/', admin_views.OrganizationListView.as_view(), name='admin-org-list'),
    path('admin/unlinked-tenants/', admin_views.unlinked_tenants, name='admin-unlinked-tenants'),
    path('admin/<int:pk>/', admin_views.OrganizationDetailView.as_view(), name='admin-org-detail'),
    path('admin/<int:pk>/link-tenant/', admin_views.link_tenant, name='admin-link-tenant'),
    path('admin/<int:pk>/unlink-tenant/', admin_views.unlink_tenant, name='admin-unlink-tenant'),
    path('admin/<int:pk>/set-admin/', admin_views.set_admin, name='admin-set-admin'),
    path('admin/<int:pk>/remove-admin/', admin_views.remove_admin, name='admin-remove-admin'),
]
