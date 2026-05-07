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
    path('', include(router.urls)),
    path('<int:pk>/', views.MedicationDetailView.as_view(), name='detail'),
]
