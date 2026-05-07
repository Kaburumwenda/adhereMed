from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('expenses', views.ExpenseViewSet, basename='expense')
router.register('categories', views.ExpenseCategoryViewSet, basename='expense-category')

urlpatterns = [
    path('', include(router.urls)),
]
