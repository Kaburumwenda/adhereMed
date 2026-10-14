"""Organization Command Center API views.

All views operate in the PUBLIC schema (Organization / OrganizationMembership
are shared models).  The stats endpoint temporarily switches into each
linked tenant's schema to gather type-specific metrics.
"""
from datetime import timedelta
from django.contrib.auth import get_user_model
from django.db import connection
from django.utils import timezone
from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from tenants.models import Tenant
from .models import Organization, OrganizationMembership
from .serializers import (
    OrganizationSerializer,
    TenantSwitchSerializer,
)

User = get_user_model()


# ── Helpers ────────────────────────────────────────────────────────────────────

ORG_ADMIN_ROLES = {'super_admin'}


def _is_org_admin(user):
    if user.role in ORG_ADMIN_ROLES:
        return True
    return getattr(user, 'is_org_admin', False) and user.organization_id


def _get_org(user):
    return getattr(user, 'organization', None)


def _linked_tenants(org):
    """Return active tenant queryset for an org."""
    if not org:
        return Tenant.objects.none()
    return Tenant.objects.filter(
        org_memberships__organization=org,
        org_memberships__is_active=True,
    ).exclude(schema_name='public').order_by('name')


def _collect_tenant_stats(tenant):
    """Switch into tenant schema and collect type-specific metrics."""
    stats = {
        'user_count': 0,
        'patient_count': None,
        'stock_value': None,
        'revenue_30d': None,
        'appointments_today': None,
        'active_alerts': None,
        'low_stock_items': None,
    }

    try:
        connection.set_schema(tenant.schema_name)
    except Exception:
        return stats

    try:
        # User count — User lives in the shared (public) schema so filter
        # by the tenant FK to get only users belonging to this tenant.
        try:
            stats['user_count'] = User.objects.filter(tenant=tenant).count()
        except Exception:
            stats['user_count'] = 0

        ttype = tenant.type

        if ttype in ('hospital', 'clinic'):
            try:
                from patients.models import Patient
                stats['patient_count'] = Patient.objects.count()
            except Exception:
                pass
            try:
                from appointments.models import Appointment
                today = timezone.now().date()
                stats['appointments_today'] = Appointment.objects.filter(
                    scheduled_at__date=today,
                ).count()
            except Exception:
                pass

        if ttype in ('pharmacy', 'inventory'):
            try:
                from inventory.models import MedicationStock
                stocks = MedicationStock.objects.all()
                stats['stock_value'] = float(sum(
                    (s.cost_price or 0) * sum(
                        (b.quantity_remaining or 0)
                        for b in s.batches.all()
                    ) for s in stocks
                ))
            except Exception:
                pass
            try:
                from inventory.models import MedicationStock
                stats['low_stock_items'] = MedicationStock.objects.filter(
                    reorder_level__gt=0,
                ).extra(
                    where=["COALESCE((SELECT SUM(quantity_remaining) "
                           "FROM inventory_stockbatch "
                           "WHERE inventory_stockbatch.stock_id = "
                           "inventory_medicationstock.id), 0) <= "
                           "inventory_medicationstock.reorder_level"],
                ).count()
            except Exception:
                pass

        if ttype in ('pharmacy', 'inventory'):
            try:
                from pos.models import POSSale
                cutoff = timezone.now() - timedelta(days=30)
                sales = POSSale.objects.filter(
                    created_at__gte=cutoff,
                )
                stats['revenue_30d'] = float(sum(
                    (s.total or 0) for s in sales
                ))
            except Exception:
                pass

        if ttype in ('hospital', 'clinic', 'pharmacy', 'inventory'):
            try:
                from notifications.models import Notification
                stats['active_alerts'] = Notification.objects.filter(
                    is_read=False,
                ).count()
            except Exception:
                pass

    except Exception:
        pass
    finally:
        connection.set_schema_to_public()

    return stats


# ── Views ──────────────────────────────────────────────────────────────────────

@api_view(['GET', 'PATCH'])
@permission_classes([IsAuthenticated])
def organization_me(request):
    """GET/PATCH the organization profile for the requesting user."""
    org = _get_org(request.user)
    if not org:
        return Response(
            {'detail': 'You are not part of an organization.'},
            status=status.HTTP_403_FORBIDDEN,
        )

    if request.method == 'GET':
        serializer = OrganizationSerializer(
            org, context={'request': request})
        return Response(serializer.data)

    # PATCH — only org admins
    if not _is_org_admin(request.user):
        return Response(
            {'detail': 'Only organization admins can update the profile.'},
            status=status.HTTP_403_FORBIDDEN,
        )
    serializer = OrganizationSerializer(
        org, data=request.data, partial=True,
        context={'request': request})
    serializer.is_valid(raise_exception=True)
    serializer.save()
    return Response(serializer.data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def organization_stats(request):
    """Aggregated KPIs across all linked tenants."""
    org = _get_org(request.user)
    if not org:
        return Response(
            {'detail': 'You are not part of an organization.'},
            status=status.HTTP_403_FORBIDDEN,
        )

    tenants = list(_linked_tenants(org))
    tenant_stats = []
    totals = {
        'user_count': 0,
        'patient_count': 0,
        'stock_value': 0,
        'revenue_30d': 0,
        'appointments_today': 0,
        'active_alerts': 0,
        'low_stock_items': 0,
    }

    for t in tenants:
        ts = _collect_tenant_stats(t)
        row = {
            'id': t.id,
            'name': t.name,
            'type': t.type,
            'slug': t.slug,
            'schema_name': t.schema_name,
            'is_active': t.is_active,
            **ts,
        }
        tenant_stats.append(row)
        for k in totals:
            v = ts.get(k)
            if v is not None:
                totals[k] += v

    # Type counts
    type_counts = {}
    for t in tenants:
        type_counts[t.type] = type_counts.get(t.type, 0) + 1

    org_data = {
        'id': org.id,
        'name': org.name,
        'slug': org.slug,
        'logo': request.build_absolute_uri(org.logo.url) if org.logo else None,
        'motto': org.motto,
        'tenant_count': len(tenants),
        'type_counts': type_counts,
    }

    return Response({
        'org': org_data,
        'tenants': tenant_stats,
        'totals': totals,
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def switch_tenant(request):
    """Validate that the tenant belongs to the user's org and return its info.

    The frontend then sets ``X-Tenant-Schema`` header to the returned
    ``schema_name`` for all subsequent API calls.
    """
    if not _is_org_admin(request.user):
        return Response(
            {'detail': 'Only organization admins can switch tenants.'},
            status=status.HTTP_403_FORBIDDEN,
        )
    serializer = TenantSwitchSerializer(data=request.data,
                                        context={'request': request})
    serializer.is_valid(raise_exception=True)
    return Response(serializer.data)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def switch_back(request):
    """Clear the tenant override — return the user's home tenant or org context."""
    user = request.user
    org = _get_org(user)
    # If the user has a home tenant, return it so the frontend can
    # set the header back.  Otherwise just confirm.
    if user.tenant_id and user.tenant.schema_name != 'public':
        return Response({
            'schema_name': user.tenant.schema_name,
            'name': user.tenant.name,
            'type': user.tenant.type,
        })
    return Response({'schema_name': None})
