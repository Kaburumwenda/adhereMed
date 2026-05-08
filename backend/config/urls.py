from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

urlpatterns = [
    path('admin/', admin.site.urls),
    # API — Shared apps
    path('api/auth/', include('accounts.urls')),
    path('api/tenants/', include('tenants.urls')),
    path('api/medications/', include('medications.urls')),
    path('api/exchange/', include('exchange.urls')),
    path('api/superadmin/', include('superadmin.urls')),
    path('api/usage-billing/', include('usage_billing.urls')),
    # API — Shared public apps
    path('api/doctors/', include('doctors.urls')),
    path('api/messaging/', include('messaging.urls')),
    path('api/clinical-catalog/', include('clinical_catalog.urls')),
    # API — Hospital tenant apps
    path('api/departments/', include('departments.urls')),
    path('api/staff/', include('staff_profiles.urls')),
    path('api/patients/', include('patients.urls')),
    path('api/appointments/', include('appointments.urls')),
    path('api/consultations/', include('consultations.urls')),
    path('api/prescriptions/', include('prescriptions.urls')),
    path('api/lab/', include('lab.urls')),
    path('api/radiology/', include('radiology.urls')),
    path('api/wards/', include('wards.urls')),
    path('api/triage/', include('triage.urls')),
    path('api/billing/', include('billing.urls')),
    path('api/notifications/', include('notifications.urls')),
    # API — Pharmacy tenant apps
    path('api/pharmacy-profile/', include('pharmacy_profile.urls')),
    path('api/inventory/', include('inventory.urls')),
    path('api/suppliers/', include('suppliers.urls')),
    path('api/purchase-orders/', include('purchase_orders.urls')),
    path('api/pos/', include('pos.urls')),
    path('api/dispensing/', include('dispensing.urls')),
    path('api/expenses/', include('expenses.urls')),
    path('api/insurance/', include('insurance.urls')),
    path('api/reports/', include('reports.urls')),
    # API — Homecare tenant app
    path('api/homecare/', include('homecare.urls')),
    # OpenAPI documentation
    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
    path('api/docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
