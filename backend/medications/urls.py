from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

app_name = 'medications'

router = DefaultRouter()
router.register('interactions', views.DrugInteractionViewSet, basename='druginteraction')

urlpatterns = [
    path('', views.MedicationListCreateView.as_view(), name='list-create'),
    path('search/', views.MedicationSearchView.as_view(), name='search'),
    path('check-interactions/', views.CheckInteractionsView.as_view(), name='check-interactions'),
    path('delete-all/', views.delete_all_medications, name='delete-all'),
    path('update-brand-names/', views.update_brand_names, name='update-brand-names'),
    path('bulk-update/', views.bulk_update_medications, name='bulk-update'),
    path('bulk-delete/', views.bulk_delete_medications, name='bulk-delete'),
    path('brand-names/', views.brand_names_catalog, name='brand-names-catalog'),
    path('brand-names/seed/', views.seed_all_brand_names, name='seed-brand-names'),
    path('brand-names/expand/', views.expand_brands_to_catalog, name='expand-brands'),
    path('brand-names/expand-all/', views.expand_all_to_catalog, name='expand-all-brands'),
    path('brand-names/create/', views.create_brand_entry, name='create-brand-entry'),
    path('export/', views.export_medications, name='export'),
    path('import-template/', views.import_template, name='import-template'),
    path('import-preview/', views.import_preview, name='import-preview'),
    path('import-commit/', views.import_commit, name='import-commit'),
    path('', include(router.urls)),
    path('<int:pk>/', views.MedicationDetailView.as_view(), name='detail'),
]
