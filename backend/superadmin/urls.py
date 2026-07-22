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

    # Adhere Coins
    path("coins/stats/", views.coin_stats, name="coin-stats"),
    path("coins/packages/", views.CoinPackageListView.as_view(), name="coin-package-list"),
    path("coins/packages/<int:pk>/", views.CoinPackageDetailView.as_view(), name="coin-package-detail"),
    path("coins/wallets/", views.CoinWalletListView.as_view(), name="coin-wallet-list"),
    path("coins/transactions/", views.CoinTransactionListView.as_view(), name="coin-transaction-list"),
    path("coins/allocate/", views.coin_allocate, name="coin-allocate"),
    path("coins/deduct/", views.coin_deduct, name="coin-deduct"),
    path("coins/init-wallets/", views.coin_init_wallets, name="coin-init-wallets"),

    # Referral Management
    path("referrals/stats/", views.referral_admin_stats, name="referral-admin-stats"),
    path("referrals/", views.ReferralListView.as_view(), name="referral-list"),
    path("referrals/<int:pk>/", views.ReferralDetailView.as_view(), name="referral-detail"),
    path("referrals/profiles/", views.ReferralProfileListView.as_view(), name="referral-profile-list"),
    path("referrals/profiles/<int:pk>/", views.ReferralProfileDetailView.as_view(), name="referral-profile-detail"),
    path("referrals/profiles/<int:pk>/regenerate-code/", views.regenerate_referral_code, name="referral-regenerate-code"),
    path("referrals/earnings-history/", views.referral_earnings_history, name="referral-earnings-history"),
    path("referrals/monthly-projections/", views.referral_monthly_projections, name="referral-monthly-projections"),

    # Mail configuration
    path("mail/config/", views.mail_config, name="mail-config"),
    path("mail/test/", views.mail_config_test, name="mail-config-test"),
]
