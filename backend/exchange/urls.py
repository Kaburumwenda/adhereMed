from django.urls import path
from . import views

app_name = 'exchange'

urlpatterns = [
    path('', views.ExchangeListCreateView.as_view(), name='list-create'),
    path('<int:pk>/', views.ExchangeDetailView.as_view(), name='detail'),
    path('<int:exchange_id>/quotes/', views.QuoteListView.as_view(), name='quotes'),
    path('<int:exchange_id>/quotes/<int:quote_id>/accept/', views.accept_quote, name='accept-quote'),
    path('<int:exchange_id>/generate-quote/', views.generate_quote, name='generate-quote'),

    # Patient pharmacy store
    path('pharmacies/', views.pharmacy_list, name='pharmacy-list'),
    path('pharmacies/<int:pharmacy_id>/products/', views.pharmacy_products, name='pharmacy-products'),
    path('orders/', views.PatientOrderListView.as_view(), name='order-list'),
    path('orders/create/', views.create_patient_order, name='order-create'),
    path('orders/<int:pk>/', views.PatientOrderDetailView.as_view(), name='order-detail'),

    # Pharmacy-side order management
    path('pharmacy/orders/', views.PharmacyOrderListView.as_view(), name='pharmacy-order-list'),
    path('pharmacy/orders/<int:pk>/status/', views.pharmacy_update_order_status, name='pharmacy-order-status'),

    # Lab exchange
    path('lab/', views.LabExchangeListCreateView.as_view(), name='lab-exchange-list'),
    path('lab/<int:pk>/', views.LabExchangeDetailView.as_view(), name='lab-exchange-detail'),
    path('lab/<int:pk>/accept/', views.lab_exchange_accept, name='lab-exchange-accept'),
    path('lab/<int:pk>/results/', views.lab_exchange_submit_results, name='lab-exchange-results'),
    path('lab/dashboard/', views.lab_dashboard_stats, name='lab-dashboard-stats'),
]
