from django.urls import path
from . import views
from .clinic_analytics import ClinicAnalyticsView
from .clinic_dashboard import ClinicDashboardView

urlpatterns = [
    path('clinic-dashboard/', ClinicDashboardView.as_view(), name='reports-clinic-dashboard'),
    path('clinic-analytics/', ClinicAnalyticsView.as_view(), name='reports-clinic-analytics'),
    path('sales-summary/', views.SalesSummaryView.as_view(), name='reports-sales'),
    path('top-products/', views.TopProductsView.as_view(), name='reports-top-products'),
    path('cashier-performance/', views.CashierPerformanceView.as_view(), name='reports-cashiers'),
    path('inventory-valuation/', views.InventoryValuationView.as_view(), name='reports-inv-val'),
    path('expiry/', views.ExpiryReportView.as_view(), name='reports-expiry'),
    path('low-stock/', views.LowStockReportView.as_view(), name='reports-low-stock'),
    path('profit-loss/', views.ProfitLossView.as_view(), name='reports-pnl'),
    path('roi/', views.ROIView.as_view(), name='reports-roi'),
    path('cash-flow/', views.CashFlowView.as_view(), name='reports-cashflow'),
]
