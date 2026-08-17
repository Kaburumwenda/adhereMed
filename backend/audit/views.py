from datetime import timedelta

from django.utils import timezone
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import filters as _filters, viewsets, permissions
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import AuditEvent
from .serializers import AuditEventSerializer, AuditEventExportSerializer


# We build CSV exports manually to avoid a hard dependency on drf-csv.


class IsStaffOrAdmin(permissions.BasePermission):
    """Only tenant admins and staff users can read the audit trail."""
    ADMIN_ROLES = {
        'super_admin', 'tenant_admin', 'pharmacy_admin', 'branch_admin',
        'hospital_admin', 'clinic_admin', 'lab_admin', 'radiology_admin',
        'homecare_admin', 'admin',
    }

    def has_permission(self, request, view):
        u = request.user
        if not (u and u.is_authenticated):
            return False
        if getattr(u, 'is_superuser', False):
            return True
        return u.role in self.ADMIN_ROLES or u.is_staff


class AuditEventViewSet(viewsets.ReadOnlyModelViewSet):
    """Read-only audit trail with rich filtering, KPI aggregation and export.

    Endpoints:
        GET /api/audit/events/              list (paginated, filterable)
        GET /api/audit/events/<id>/         retrieve
        GET /api/audit/events/kpis/         aggregated KPI tiles
        GET /api/audit/events/export/?format=csv|json   bulk export
        GET /api/audit/events/trends/?days=30  events per day for charts
        GET /api/audit/events/top_actors/?limit=10  most active users
    """
    permission_classes = [IsStaffOrAdmin]
    serializer_class = AuditEventSerializer
    filter_backends = [DjangoFilterBackend, _filters.SearchFilter, _filters.OrderingFilter]
    search_fields = ['actor_email', 'object_repr', 'description', 'path', 'ip']
    filterset_fields = {
        'action': ['exact'],
        'severity': ['exact'],
        'object_type': ['exact'],
        'actor_user_id': ['exact'],
        'actor_email': ['exact', 'icontains'],
        'method': ['exact'],
        'status_code': ['exact', 'gte', 'lte'],
        'created_at': ['gte', 'lte', 'date'],
        'ip': ['exact'],
    }
    ordering_fields = ['created_at', 'actor_email', 'action', 'object_type',
                       'status_code', 'severity']
    ordering = ['-created_at']

    def get_queryset(self):
        qs = AuditEvent.objects.all()
        # Quick "since" filter — last N days
        since_days = self.request.query_params.get('since_days')
        if since_days:
            try:
                days = int(since_days)
                if days > 0:
                    qs = qs.filter(created_at__gte=timezone.now() - timedelta(days=days))
            except ValueError:
                pass
        severity_gte = self.request.query_params.get('severity_gte')
        if severity_gte:
            order = [c[0] for c in AuditEvent.Severity.choices]
            if severity_gte in order:
                start = order.index(severity_gte)
                qs = qs.filter(severity__in=order[start:])
        return qs

    # ── Aggregations ──────────────────────────────────────────────────
    @action(detail=False, methods=['get'], url_path='kpis')
    def kpis(self, request):
        """Top-line KPIs for the page header."""
        qs = self.get_queryset()
        since_24h = timezone.now() - timedelta(hours=24)
        since_7d = timezone.now() - timedelta(days=7)
        total = qs.count()
        last_24 = qs.filter(created_at__gte=since_24h).count()
        distinct_actors = qs.values('actor_user_id').distinct().count()
        critical = qs.filter(severity=AuditEvent.Severity.CRITICAL).count()
        warnings = qs.filter(severity=AuditEvent.Severity.WARNING).count()
        failures = qs.filter(status_code__gte=400).count()
        return Response({
            'total': total,
            'last_24h': last_24,
            'distinct_actors': distinct_actors,
            'critical': critical,
            'warnings': warnings,
            'failures': failures,
        })

    @action(detail=False, methods=['get'], url_path='trends')
    def trends(self, request):
        """Events per day for the last N days (default 30)."""
        try:
            days = int(request.query_params.get('days', 30))
        except ValueError:
            days = 30
        days = max(1, min(days, 365))
        start = (timezone.now() - timedelta(days=days)).date()
        from django.db.models.functions import TruncDate
        from django.db.models import Count
        rows = (self.get_queryset()
                .filter(created_at__date__gte=start)
                .annotate(day=TruncDate('created_at'))
                .values('day')
                .annotate(count=Count('id'))
                .order_by('day'))
        # Build a contiguous series so missing days show as zero.
        series = {str(start + timedelta(days=i)): 0 for i in range(days + 1)}
        for r in rows:
            series[str(r['day'])] = r['count']
        return Response([
            {'date': k, 'count': v} for k, v in sorted(series.items())
        ])

    @action(detail=False, methods=['get'], url_path='action-breakdown')
    def action_breakdown(self, request):
        from django.db.models import Count
        rows = (self.get_queryset()
                .values('action')
                .annotate(count=Count('id'))
                .order_by('-count'))
        return Response([
            {'action': r['action'], 'count': r['count']} for r in rows
        ])

    @action(detail=False, methods=['get'], url_path='top-actors')
    def top_actors(self, request):
        from django.db.models import Count
        try:
            limit = int(request.query_params.get('limit', 10))
        except ValueError:
            limit = 10
        limit = max(1, min(limit, 100))
        rows = (self.get_queryset()
                .exclude(actor_user_id__isnull=True)
                .values('actor_user_id', 'actor_email', 'actor_role')
                .annotate(count=Count('id'))
                .order_by('-count')[:limit])
        return Response([
            {
                'user_id': r['actor_user_id'],
                'email': r['actor_email'],
                'role': r['actor_role'],
                'count': r['count'],
            }
            for r in rows
        ])

    @action(detail=False, methods=['get'], url_path='object-types')
    def object_types(self, request):
        """Distinct object_type values — powers the frontend filter dropdown."""
        from django.db.models import Count
        rows = (self.get_queryset()
                .exclude(object_type='')
                .values('object_type')
                .annotate(count=Count('id'))
                .order_by('-count'))
        return Response([
            {'object_type': r['object_type'], 'count': r['count']} for r in rows
        ])

    # ── Export ────────────────────────────────────────────────────────
    @action(detail=False, methods=['get'], url_path='export')
    def export(self, request):
        """Stream the current filtered set as CSV or JSON.

        Query params:
            format=csv|json   (default: csv)
            limit=1000        (cap rows; default 5000)
        """
        import csv
        from django.http import HttpResponse, JsonResponse
        fmt = (request.query_params.get('format') or 'csv').lower()
        try:
            limit = int(request.query_params.get('limit', 5000))
        except ValueError:
            limit = 5000
        limit = max(1, min(limit, 20000))
        qs = self.get_queryset()[:limit]
        data = AuditEventExportSerializer(qs, many=True).data
        if fmt == 'json':
            return JsonResponse(
                {'count': len(data), 'results': data},
                json_dumps_params={'indent': 2, 'default': str},
            )
        # CSV
        response = HttpResponse(content_type='text/csv')
        fname = f'audit-logs-{timezone.now():%Y%m%d-%H%M%S}.csv'
        response['Content-Disposition'] = f'attachment; filename="{fname}"'
        if not data:
            return response
        writer = csv.DictWriter(response, fieldnames=list(data[0].keys()))
        writer.writeheader()
        for row in data:
            writer.writerow({k: str(v) for k, v in row.items()})
        return response
