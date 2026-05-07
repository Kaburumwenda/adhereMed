from django.urls import path
from . import views

app_name = 'clinical_catalog'

urlpatterns = [
    # Allergies
    path('allergies/', views.AllergyListCreateView.as_view(), name='allergy-list'),
    path('allergies/search/', views.AllergySearchView.as_view(), name='allergy-search'),
    path('allergies/<int:pk>/', views.AllergyDetailView.as_view(), name='allergy-detail'),
    # Chronic Conditions
    path('conditions/', views.ChronicConditionListCreateView.as_view(), name='condition-list'),
    path('conditions/search/', views.ChronicConditionSearchView.as_view(), name='condition-search'),
    path('conditions/<int:pk>/', views.ChronicConditionDetailView.as_view(), name='condition-detail'),
]
