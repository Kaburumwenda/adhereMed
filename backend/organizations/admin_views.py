"""Superadmin CRUD endpoints for organizations + tenant linking + admin assignment."""
from django.contrib.auth import get_user_model
from django.db import connection
from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, BasePermission
from rest_framework.response import Response

from tenants.models import Tenant
from .models import Organization, OrganizationMembership
from .admin_serializers import (
    OrganizationAdminSerializer,
    OrganizationCreateSerializer,
    LinkTenantSerializer,
    SetAdminSerializer,
    TenantOptionSerializer,
)

User = get_user_model()


class CanManageOrganizations(BasePermission):
    """Allow super_admin role, superusers, or users with is_org_admin flag."""
    def has_permission(self, request, view):
        u = request.user
        if not u or not u.is_authenticated:
            return False
        return (
            u.role == 'super_admin'
            or u.is_superuser
            or getattr(u, 'is_org_admin', False)
        )


PERMISSION_CLASSES = [IsAuthenticated, CanManageOrganizations]


class OrganizationListView(generics.ListCreateAPIView):
    permission_classes = PERMISSION_CLASSES

    def get_queryset(self):
        qs = Organization.objects.all().order_by('-created_at')
        q = self.request.query_params.get('q', '')
        if q:
            qs = qs.filter(name__icontains=q)
        return qs

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return OrganizationCreateSerializer
        return OrganizationAdminSerializer


class OrganizationDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = PERMISSION_CLASSES
    serializer_class = OrganizationAdminSerializer
    queryset = Organization.objects.all()

    def perform_destroy(self, instance):
        # Unlink all tenants and clear admin flags, then delete
        OrganizationMembership.objects.filter(organization=instance).delete()
        User.objects.filter(organization=instance).update(
            organization=None, is_org_admin=False
        )
        instance.delete()


@api_view(['GET'])
@permission_classes(PERMISSION_CLASSES)
def unlinked_tenants(request):
    """Return tenants that are NOT linked to any organization."""
    linked_ids = OrganizationMembership.objects.values_list('tenant_id', flat=True)
    qs = Tenant.objects.exclude(schema_name='public').exclude(id__in=linked_ids).order_by('name')
    return Response(TenantOptionSerializer(qs, many=True).data)


@api_view(['POST'])
@permission_classes(PERMISSION_CLASSES)
def link_tenant(request, pk):
    """Link a tenant to an organization."""
    try:
        org = Organization.objects.get(pk=pk)
    except Organization.DoesNotExist:
        return Response({'detail': 'Organization not found.'}, status=status.HTTP_404_NOT_FOUND)

    serializer = LinkTenantSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    tenant_id = serializer.validated_data['tenant_id']
    tenant = Tenant.objects.get(id=tenant_id)

    membership, created = OrganizationMembership.objects.get_or_create(
        organization=org, tenant=tenant,
        defaults={'is_active': True},
    )
    if not created:
        if not membership.is_active:
            membership.is_active = True
            membership.save(update_fields=['is_active'])
            return Response({'detail': f'Re-activated link: {tenant.name}'})
        return Response({'detail': f'{tenant.name} is already linked.'}, status=status.HTTP_200_OK)

    return Response({'detail': f'Linked {tenant.name} to {org.name}.'}, status=status.HTTP_201_CREATED)


@api_view(['POST'])
@permission_classes(PERMISSION_CLASSES)
def unlink_tenant(request, pk):
    """Remove a tenant from an organization."""
    try:
        org = Organization.objects.get(pk=pk)
    except Organization.DoesNotExist:
        return Response({'detail': 'Organization not found.'}, status=status.HTTP_404_NOT_FOUND)

    tenant_id = request.data.get('tenant_id')
    if not tenant_id:
        return Response({'detail': 'tenant_id is required.'}, status=status.HTTP_400_BAD_REQUEST)

    deleted = OrganizationMembership.objects.filter(organization=org, tenant_id=tenant_id).delete()
    if deleted[0]:
        return Response({'detail': 'Tenant unlinked.'})
    return Response({'detail': 'Link not found.'}, status=status.HTTP_404_NOT_FOUND)


@api_view(['POST'])
@permission_classes(PERMISSION_CLASSES)
def set_admin(request, pk):
    """Designate a user as org admin for this organization."""
    try:
        org = Organization.objects.get(pk=pk)
    except Organization.DoesNotExist:
        return Response({'detail': 'Organization not found.'}, status=status.HTTP_404_NOT_FOUND)

    serializer = SetAdminSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    email = serializer.validated_data['user_email']

    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        return Response({'detail': f'User "{email}" not found.'}, status=status.HTTP_404_NOT_FOUND)

    user.organization = org
    user.is_org_admin = True
    user.save(update_fields=['organization', 'is_org_admin'])
    return Response({'detail': f'{email} is now an admin of {org.name}.'})


@api_view(['POST'])
@permission_classes(PERMISSION_CLASSES)
def remove_admin(request, pk):
    """Remove org admin status from a user."""
    user_id = request.data.get('user_id')
    if not user_id:
        return Response({'detail': 'user_id is required.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        user = User.objects.get(pk=user_id, organization_id=pk)
    except User.DoesNotExist:
        return Response({'detail': 'User not found in this organization.'}, status=status.HTTP_404_NOT_FOUND)

    user.is_org_admin = False
    user.organization = None
    user.save(update_fields=['is_org_admin', 'organization'])
    return Response({'detail': 'Admin removed.'})
