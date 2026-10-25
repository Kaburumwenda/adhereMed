from django.urls import include, path
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('roles', views.ClinicRoleDefinitionViewSet, basename='clinic-role')

urlpatterns = [
    path('matrix/', views.ClinicRBACMatrixView.as_view(), name='clinic-rbac-matrix'),
    path('users/<int:user_id>/role/', views.ClinicRBACSetUserRoleView.as_view(),
         name='clinic-rbac-user-role'),
    path('builtin-roles/<str:key>/', views.ClinicRBACBuiltinRoleView.as_view(),
         name='clinic-rbac-builtin-role'),
    path('', include(router.urls)),
]
