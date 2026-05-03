from django.urls import path
from . import views

app_name = 'medications'

urlpatterns = [
    path('', views.MedicationListCreateView.as_view(), name='list-create'),
    path('search/', views.MedicationSearchView.as_view(), name='search'),
    path('<int:pk>/', views.MedicationDetailView.as_view(), name='detail'),
]
