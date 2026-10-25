from django.db.models import Count
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import filters, permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from accounts.views import IsTenantAdminOrSuperAdmin

from config.cache import tenant_cache

from .models import ClinicSite
from .serializers import ClinicSiteSerializer
from .utils import ensure_hq_site, get_hq_site


class ClinicSiteViewSet(viewsets.ModelViewSet):
    """CRUD for the clinics that belong to this tenant.

    Read is open to every authenticated member (operational pages need the list
    to build a site switcher); writes are restricted to tenant admins.
    """

    serializer_class = ClinicSiteSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['is_hq', 'is_active', 'kind']
    search_fields = ['name', 'code', 'place_name', 'city', 'address', 'phone', 'email']
    ordering_fields = ['name', 'code', 'created_at', 'is_hq']

    def get_permissions(self):
        if self.request.method in permissions.SAFE_METHODS:
            return [permissions.IsAuthenticated()]
        return [IsTenantAdminOrSuperAdmin()]

    def get_queryset(self):
        return ClinicSite.objects.select_related('manager', 'profile').order_by('-is_hq', 'name')

    def _attach_counts(self, rows):
        """Attach per-site record counts without a 4-way JOIN.

        ``Count('patients', distinct=True) + Count('appointments', ...)`` in one
        annotated queryset multiplies the joined rows together (patients ×
        appointments × consultations × invoices), which makes the list endpoint
        take minutes on a real clinic. Four grouped aggregates are far cheaper.
        """
        rows = list(rows)
        if not rows:
            return rows

        counts = {row.id: {} for row in rows}
        sources = [
            ('patients', 'patients', 'Patient'),
            ('appointments', 'appointments', 'Appointment'),
            ('consultations', 'consultations', 'Consultation'),
            ('invoices', 'billing', 'Invoice'),
        ]
        from django.apps import apps

        for label, app_label, model_name in sources:
            try:
                model = apps.get_model(app_label, model_name)
                grouped = (
                    model.objects.exclude(clinic_site__isnull=True)
                    .values('clinic_site_id')
                    .annotate(n=Count('id'))
                )
                for row in grouped:
                    bucket = counts.get(row['clinic_site_id'])
                    if bucket is not None:
                        bucket[label] = row['n']
            except Exception:  # noqa: BLE001 - app not installed in this schema
                continue

        for row in rows:
            row._counts = counts.get(row.id, {})
        return rows

    def list(self, request, *args, **kwargs):
        # A clinic tenant always has an HQ — make sure one exists before listing
        # so the UI never shows an empty network.
        ensure_hq_site()
        queryset = self.filter_queryset(self.get_queryset())
        page = self.paginate_queryset(queryset)
        if page is not None:
            self._attach_counts(page)
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        rows = list(queryset)
        self._attach_counts(rows)
        return Response(self.get_serializer(rows, many=True).data)

    def retrieve(self, request, *args, **kwargs):
        site = self.get_object()
        self._attach_counts([site])
        return Response(self.get_serializer(site).data)

    def perform_create(self, serializer):
        serializer.save()

    def destroy(self, request, *args, **kwargs):
        site = self.get_object()
        if site.is_hq:
            return Response(
                {'detail': 'The HQ clinic cannot be deleted. Promote another clinic first.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        from appointments.models import Appointment
        from consultations.models import Consultation
        from patients.models import Patient

        counts = {
            'patients': Patient.objects.filter(clinic_site=site).count(),
            'appointments': Appointment.objects.filter(clinic_site=site).count(),
            'consultations': Consultation.objects.filter(clinic_site=site).count(),
        }
        if any(counts.values()):
            detail = ', '.join(f'{v} {k}' for k, v in counts.items() if v)
            return Response(
                {
                    'detail': (
                        f'"{site.name}" still owns clinical records ({detail}). '
                        'Move them to another clinic or deactivate this one instead.'
                    ),
                    **counts,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        return super().destroy(request, *args, **kwargs)

    @action(detail=True, methods=['post'], url_path='set-hq')
    def set_hq(self, request, pk=None):
        """Promote this clinic to HQ (the previous HQ becomes a branch)."""
        site = get_hq_site()
        target = self.get_object()
        if target.id == (site.id if site else None) and target.is_hq:
            return Response(self.get_serializer(target).data)

        ClinicSite.objects.filter(is_hq=True).exclude(pk=target.pk).update(
            is_hq=False, kind=ClinicSite.Kind.BRANCH,
        )
        target.is_hq = True
        target.kind = ClinicSite.Kind.HQ
        target.is_active = True
        target.save()
        self._attach_counts([target])
        return Response(self.get_serializer(target).data)

    @tenant_cache('clinic.network', timeout=120)
    @action(detail=False, methods=['get'], url_path='summary')
    def summary(self, request):
        """Network at a glance: totals per clinic plus the HQ pointer."""
        ensure_hq_site()
        qs = self.filter_queryset(self.get_queryset()).order_by('-is_hq', 'name')
        rows = self.get_serializer(self._attach_counts(qs), many=True).data
        hq = next((row for row in rows if row['is_hq']), None)
        totals = {
            'clinics': len(rows),
            'active': sum(1 for row in rows if row['is_active']),
            'patients': sum(int(row['counts'].get('patients') or 0) for row in rows),
            'appointments': sum(int(row['counts'].get('appointments') or 0) for row in rows),
            'consultations': sum(int(row['counts'].get('consultations') or 0) for row in rows),
        }
        return Response({
            'hq': hq,
            'totals': totals,
            'clinics': rows,
        })
