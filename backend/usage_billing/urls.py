from django.urls import path

from . import views

app_name = "usage_billing"

urlpatterns = [
    # Tenant-facing
    path("dashboard/", views.tenant_dashboard, name="tenant-dashboard"),
    path("range/", views.tenant_range_usage, name="tenant-range-usage"),
    path("lab/dashboard/", views.tenant_lab_dashboard, name="tenant-lab-dashboard"),
    path("lab/range/", views.tenant_lab_range, name="tenant-lab-range"),
    path("doctor/dashboard/", views.doctor_dashboard, name="doctor-dashboard"),

    # Super admin
    path("admin/rates/", views.RateListCreateView.as_view(), name="admin-rate-list"),
    path("admin/rates/<int:pk>/", views.RateDetailView.as_view(), name="admin-rate-detail"),
    path("admin/doctor-rates/", views.DoctorRateListCreateView.as_view(), name="admin-doctor-rate-list"),
    path("admin/doctor-rates/<int:pk>/", views.DoctorRateDetailView.as_view(), name="admin-doctor-rate-detail"),
    path("admin/doctor-commissions/", views.admin_doctor_commission_overview, name="admin-doctor-commission-overview"),
    path("admin/usage/", views.admin_usage_overview, name="admin-usage-overview"),
    path("admin/usage/<int:tenant_id>/", views.admin_tenant_usage_detail, name="admin-tenant-usage"),
    path("admin/bills/", views.BillListView.as_view(), name="admin-bill-list"),
    path("admin/bills/<int:pk>/mark-paid/", views.mark_bill_paid, name="admin-bill-mark-paid"),
    path("admin/generate-bills/", views.generate_bills, name="admin-generate-bills"),
]
