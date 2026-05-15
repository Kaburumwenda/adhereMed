from django.urls import path

from . import views
from . import referral_views

app_name = "usage_billing"

urlpatterns = [
    # Tenant-facing
    path("dashboard/", views.tenant_dashboard, name="tenant-dashboard"),
    path("range/", views.tenant_range_usage, name="tenant-range-usage"),
    path("lab/dashboard/", views.tenant_lab_dashboard, name="tenant-lab-dashboard"),
    path("lab/range/", views.tenant_lab_range, name="tenant-lab-range"),
    path("doctor/dashboard/", views.doctor_dashboard, name="doctor-dashboard"),

    # Referral system
    path("referral/dashboard/", referral_views.referral_dashboard, name="referral-dashboard"),
    path("referral/transactions/", referral_views.referral_transactions, name="referral-transactions"),
    path("referral/stats/", referral_views.referral_stats, name="referral-stats"),
    path("referral/performance/", referral_views.referral_performance, name="referral-performance"),
    path("referral/validate/<str:code>/", referral_views.validate_referral_code, name="referral-validate"),

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
