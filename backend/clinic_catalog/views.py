from django.db.models import Count, Q
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import filters, permissions, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from config.cache import tenant_cache

from .models import ClinicAllergy, ClinicChronicCondition
from .serializers import ClinicAllergySerializer, ClinicChronicConditionSerializer

CLINIC_CATALOG_ADMIN_ROLES = {'tenant_admin', 'clinic_admin', 'admin'}


def _catalog_stats(qs):
    """Shared aggregate payload for the catalog KPI tiles.

    Returns totals (all / active / inactive), source split (seeded vs
    custom) and a per-category breakdown sorted by count desc. Computed in
    one pass over the queryset so the page never has to page through rows
    to count them client-side.
    """
    totals = qs.aggregate(
        total=Count('id'),
        active=Count('id', filter=Q(is_active=True)),
        inactive=Count('id', filter=Q(is_active=False)),
        seeded=Count('id', filter=Q(source='seed')),
        custom=Count('id', filter=Q(source='custom')),
    )
    by_category = list(
        qs.exclude(category='')
          .values('category')
          .annotate(count=Count('id'))
          .order_by('-count', 'category')
    )
    return {
        **{k: (v or 0) for k, v in totals.items()},
        'by_category': by_category,
        'categories_count': len(by_category),
    }


class ClinicCatalogPermission(permissions.IsAuthenticated):
    """Reads are open to all authenticated clinic staff; writes and deletes
    are restricted to the tenant's admins."""

    def has_permission(self, request, view):
        if not super().has_permission(request, view):
            return False
        if request.method in permissions.SAFE_METHODS:
            return True
        return request.user.role in CLINIC_CATALOG_ADMIN_ROLES


class ClinicAllergyViewSet(viewsets.ModelViewSet):
    queryset = ClinicAllergy.objects.all()
    serializer_class = ClinicAllergySerializer
    permission_classes = [ClinicCatalogPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['category', 'source', 'is_active']
    search_fields = ['name', 'description', 'common_symptoms', 'category']
    ordering_fields = ['name', 'category', 'created_at']

    def perform_create(self, serializer):
        serializer.save(source=ClinicAllergy.Source.CUSTOM)

    @tenant_cache('clinic.catalog', timeout=300)
    @action(detail=False, methods=['get'])
    def stats(self, request):
        """KPI + category breakdown for the Allergies page tiles."""
        return Response(_catalog_stats(self.get_queryset()))

    @action(detail=False, methods=['get'])
    def search(self, request):
        q = (request.query_params.get('q') or '').strip()
        qs = self.get_queryset().filter(is_active=True)
        if q:
            qs = qs.filter(Q(name__icontains=q))
        qs = qs[:30]
        return Response(self.get_serializer(qs, many=True).data)

    @action(detail=False, methods=['post'], url_path='seed')
    def seed(self, request):
        """Copy all global Allergy rows into this clinic tenant's catalog.
        Existing names are skipped. Restricted to clinic admins."""
        if request.user.role not in CLINIC_CATALOG_ADMIN_ROLES:
            return Response({'detail': 'Admin only.'}, status=403)
        from django.core.management import call_command
        from io import StringIO
        out = StringIO()
        call_command('seed_clinic_catalog', '--allergies', stdout=out)
        return Response({'detail': out.getvalue().strip() or 'Seeded.',
                         'total': ClinicAllergy.objects.count()})


class ClinicChronicConditionViewSet(viewsets.ModelViewSet):
    queryset = ClinicChronicCondition.objects.all()
    serializer_class = ClinicChronicConditionSerializer
    permission_classes = [ClinicCatalogPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['category', 'source', 'is_active']
    search_fields = ['name', 'icd_code', 'description', 'category']
    ordering_fields = ['name', 'category', 'icd_code', 'created_at']

    def perform_create(self, serializer):
        serializer.save(source=ClinicChronicCondition.Source.CUSTOM)

    @tenant_cache('clinic.catalog', timeout=300)
    @action(detail=False, methods=['get'])
    def stats(self, request):
        """KPI + category breakdown for the Chronic Conditions page tiles."""
        return Response(_catalog_stats(self.get_queryset()))

    @action(detail=False, methods=['get'])
    def search(self, request):
        q = (request.query_params.get('q') or '').strip()
        qs = self.get_queryset().filter(is_active=True)
        if q:
            qs = qs.filter(Q(name__icontains=q) | Q(icd_code__icontains=q))
        qs = qs[:30]
        return Response(self.get_serializer(qs, many=True).data)

    @action(detail=False, methods=['post'], url_path='seed')
    def seed(self, request):
        """Copy all global ChronicCondition rows into this clinic tenant's
        catalog. Existing names are skipped. Restricted to clinic admins."""
        if request.user.role not in CLINIC_CATALOG_ADMIN_ROLES:
            return Response({'detail': 'Admin only.'}, status=403)
        from django.core.management import call_command
        from io import StringIO
        out = StringIO()
        call_command('seed_clinic_catalog', '--conditions', stdout=out)
        return Response({'detail': out.getvalue().strip() or 'Seeded.',
                         'total': ClinicChronicCondition.objects.count()})
