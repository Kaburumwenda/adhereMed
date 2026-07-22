from django.urls import path

from . import views
from . import referral_views
from . import payment_views

app_name = "usage_billing"

urlpatterns = [
    # Tenant-facing
    path("dashboard/", views.tenant_dashboard, name="tenant-dashboard"),
    path("range/", views.tenant_range_usage, name="tenant-range-usage"),
    path("bills/<int:pk>/", views.tenant_bill_detail, name="tenant-bill-detail"),
    path("billing-status/", views.billing_status, name="billing-status"),
    path("payments/", views.tenant_payments, name="tenant-payments"),
    path("payments/mpesa/initiate/", payment_views.mpesa_initiate, name="mpesa-initiate"),
    path("payments/mpesa/confirm/", payment_views.mpesa_confirm, name="mpesa-confirm"),
    path("payments/wallet/pay-bill/", payment_views.wallet_pay_bill, name="wallet-pay-bill"),
    path("payments/coupon/apply/", views.apply_coupon, name="coupon-apply"),
    path("lab/dashboard/", views.tenant_lab_dashboard, name="tenant-lab-dashboard"),
    path("lab/range/", views.tenant_lab_range, name="tenant-lab-range"),
    path("doctor/dashboard/", views.doctor_dashboard, name="doctor-dashboard"),

    # Referral system
    path("referral/dashboard/", referral_views.referral_dashboard, name="referral-dashboard"),
    path("referral/transactions/", referral_views.referral_transactions, name="referral-transactions"),
    path("referral/stats/", referral_views.referral_stats, name="referral-stats"),
    path("referral/performance/", referral_views.referral_performance, name="referral-performance"),
    path("referral/validate/<str:code>/", referral_views.validate_referral_code, name="referral-validate"),
    path("referral/redeem/pay-bill/", referral_views.redeem_pay_bill, name="referral-redeem-pay-bill"),
    path("referral/redeem/gift/", referral_views.redeem_gift_coins, name="referral-redeem-gift"),

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
    path("admin/bills/<int:pk>/waive/", views.admin_waive_bill, name="admin-bill-waive"),
    path("admin/generate-bills/", views.generate_bills, name="admin-generate-bills"),
    path("admin/payment-config/", payment_views.payment_config, name="admin-payment-config"),
    path("admin/payments/", payment_views.admin_payments, name="admin-payments"),
    # Suspension / grace / coupons
    path("admin/tenants/<int:tenant_id>/suspend/", views.admin_suspend_tenant, name="admin-suspend-tenant"),
    path("admin/tenants/<int:tenant_id>/unsuspend/", views.admin_unsuspend_tenant, name="admin-unsuspend-tenant"),
    path("admin/tenants/<int:tenant_id>/extend-grace/", views.admin_extend_grace, name="admin-extend-grace"),
    path("admin/coupons/", views.admin_coupons, name="admin-coupons"),
    path("admin/coupons/<int:pk>/", views.admin_coupon_detail, name="admin-coupon-detail"),
]
