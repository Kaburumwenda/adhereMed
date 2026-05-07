from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('transactions', views.POSTransactionViewSet, basename='postransaction')
router.register('customers', views.CustomerViewSet, basename='customer')
router.register('parked-sales', views.ParkedSaleViewSet, basename='parkedsale')
router.register('shifts', views.CashierShiftViewSet, basename='cashiershift')
router.register('loyalty', views.LoyaltyTransactionViewSet, basename='loyalty')

urlpatterns = [
    path('analytics/', views.SalesAnalyticsView.as_view(), name='sales-analytics'),
    path('', include(router.urls)),
]
