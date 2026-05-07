from django.urls import path
from . import views

urlpatterns = [
    path('sales-summary/', views.SalesSummaryView.as_view(), name='reports-sales'),
    path('top-products/', views.TopProductsView.as_view(), name='reports-top-products'),
    path('cashier-performance/', views.CashierPerformanceView.as_view(), name='reports-cashiers'),
    path('inventory-valuation/', views.InventoryValuationView.as_view(), name='reports-inv-val'),
    path('expiry/', views.ExpiryReportView.as_view(), name='reports-expiry'),
    path('low-stock/', views.LowStockReportView.as_view(), name='reports-low-stock'),
    path('profit-loss/', views.ProfitLossView.as_view(), name='reports-pnl'),
]
