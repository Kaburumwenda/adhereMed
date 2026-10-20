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
        'homecare_admin', 'inventory_admin', 'admin',
        # Occupational Health & Safety (OHSMS) leadership
        'hse_manager', 'safety_officer',
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

    def _filtered_queryset(self):
        """The queryset with the DRF filter backends applied.

        Custom ``@action`` handlers do **not** run ``filter_queryset``
        automatically — using ``get_queryset()`` alone silently ignores every
        ``?action=``, ``?severity=``, ``?created_at__gte=``… query param.
        Every aggregate and the export must go through this helper.
        """
        return self.filter_queryset(self.get_queryset())

    # ── Aggregations ──────────────────────────────────────────────────
    @action(detail=False, methods=['get'], url_path='kpis')
    def kpis(self, request):
        """Top-line KPIs for the page header."""
        qs = self._filtered_queryset()
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
        rows = (self._filtered_queryset()
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
        rows = (self._filtered_queryset()
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
        rows = (self._filtered_queryset()
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
        rows = (self._filtered_queryset()
                .exclude(object_type='')
                .values('object_type')
                .annotate(count=Count('id'))
                .order_by('-count'))
        return Response([
            {'object_type': r['object_type'], 'count': r['count']} for r in rows
        ])

    # ── Security overview (single call for the audit dashboard) ───────
    @action(detail=False, methods=['get'], url_path='security-overview')
    def security_overview(self, request):
        """Everything the audit-log cockpit renders, in one round trip.

        Returns KPIs, severity/action/module mixes, a zero-filled trend over the
        selected window, a 24-hour activity profile, an actor leaderboard,
        derived security signals and the retention window implied by the oldest
        retained event.

        The trend window follows the applied date filter
        (``created_at__gte`` / ``created_at__lte`` or ``since_days``) and can be
        overridden with ``trend_days``. It is capped at 180 points.
        """
        from datetime import date as _date
        from django.db.models import Count
        from django.db.models.functions import ExtractHour, TruncDate

        qs = self._filtered_queryset()
        base = AuditEvent.objects.all()
        now = timezone.now()
        since_24h = now - timedelta(hours=24)
        since_7d = now - timedelta(days=7)
        since_30d = now - timedelta(days=30)

        # ── Resolve the trend window from the active date filter ──────
        def _parse(dt):
            if not dt:
                return None
            try:
                return _date.fromisoformat(str(dt)[:10])
            except (TypeError, ValueError):
                return None

        frm = _parse(request.query_params.get('created_at__gte'))
        to = _parse(request.query_params.get('created_at__lte'))
        if frm and to:
            window_days = max(1, min((to - frm).days + 1, 180))
        elif frm:
            window_days = max(1, min((timezone.now().date() - frm).days + 1, 180))
        else:
            try:
                window_days = int(request.query_params.get('trend_days')
                                  or request.query_params.get('since_days') or 30)
            except (TypeError, ValueError):
                window_days = 30
            window_days = max(1, min(window_days, 180))

        if frm and to:
            trend_start, trend_end = frm, to
        elif frm:
            trend_start, trend_end = frm, timezone.now().date()
        else:
            trend_end = to or timezone.now().date()
            trend_start = trend_end - timedelta(days=window_days - 1)

        # Never render more than 180 points — clamp the start of the series.
        if (trend_end - trend_start).days + 1 > 180:
            trend_start = trend_end - timedelta(days=179)

        total = qs.count()
        oldest = qs.order_by('created_at').values_list('created_at', flat=True).first()

        severity_order = [c[0] for c in AuditEvent.Severity.choices]
        severity_rows = {
            r['severity']: r['count']
            for r in qs.values('severity').annotate(count=Count('id'))
        }
        action_rows = list(
            qs.values('action').annotate(count=Count('id')).order_by('-count')
        )
        module_rows = list(
            qs.exclude(object_type='')
            .values('object_type').annotate(count=Count('id')).order_by('-count')[:12]
        )

        # ── Zero-filled daily trend across the resolved window ────────
        span = (trend_end - trend_start).days + 1
        trend_rows = (
            qs.filter(created_at__date__gte=trend_start, created_at__date__lte=trend_end)
            .annotate(day=TruncDate('created_at'))
            .values('day').annotate(count=Count('id')).order_by('day')
        )
        series = {str(trend_start + timedelta(days=i)): 0 for i in range(span)}
        for r in trend_rows:
            series[str(r['day'])] = r['count']
        trend = [{'date': k, 'count': v} for k, v in sorted(series.items())]

        # 24-hour profile (server timezone)
        hour_rows = {
            r['hour']: r['count']
            for r in qs.exclude(created_at__isnull=True)
            .annotate(hour=ExtractHour('created_at'))
            .values('hour').annotate(count=Count('id'))
        }
        hourly = [{'hour': h, 'count': hour_rows.get(h, 0)} for h in range(24)]

        # Actor leaderboard
        actors = [
            {
                'user_id': r['actor_user_id'],
                'email': r['actor_email'],
                'role': r['actor_role'],
                'count': r['count'],
            }
            for r in (
                qs.exclude(actor_user_id__isnull=True)
                .values('actor_user_id', 'actor_email', 'actor_role')
                .annotate(count=Count('id')).order_by('-count')[:8]
            )
        ]

        # ── Derived security signals ─────────────────────────────────
        signals = []

        critical_7d = qs.filter(
            severity=AuditEvent.Severity.CRITICAL, created_at__gte=since_7d,
        )
        if critical_7d.count():
            signals.append({
                'severity': 'high', 'kind': 'critical',
                'title': f'{critical_7d.count()} critical events in the last 7 days',
                'detail': 'Deletions, server errors or privileged changes need review.',
                'count': critical_7d.count(),
            })

        failed_auth = qs.filter(
            path__endswith='/login/', status_code__gte=400,
            created_at__gte=since_7d,
        )
        if failed_auth.count():
            actors_hit = (
                failed_auth.exclude(actor_email='')
                .values('actor_email').annotate(n=Count('id')).order_by('-n')
            )
            worst = actors_hit.first()
            detail = (
                f'Highest: {worst["actor_email"]} ({worst["n"]} attempts)'
                if worst else 'Review the sign-in trail for credential stuffing.'
            )
            signals.append({
                'severity': 'high' if failed_auth.count() >= 5 else 'medium',
                'kind': 'auth',
                'title': f'{failed_auth.count()} failed sign-in attempts',
                'detail': detail,
                'count': failed_auth.count(),
            })

        deletes_7d = qs.filter(action='delete', created_at__gte=since_7d)
        if deletes_7d.count():
            signals.append({
                'severity': 'medium', 'kind': 'deletion',
                'title': f'{deletes_7d.count()} deletions recorded',
                'detail': 'Confirm each deletion was authorised and documented.',
                'count': deletes_7d.count(),
            })

        exports_7d = qs.filter(action='export', created_at__gte=since_7d)
        if exports_7d.count():
            signals.append({
                'severity': 'medium', 'kind': 'export',
                'title': f'{exports_7d.count()} data exports',
                'detail': 'Exports move records outside the system — verify recipients.',
                'count': exports_7d.count(),
            })

        config_7d = qs.filter(action='config', created_at__gte=since_7d)
        if config_7d.count():
            signals.append({
                'severity': 'medium', 'kind': 'config',
                'title': f'{config_7d.count()} configuration changes',
                'detail': 'Palette, roles and organisation settings were modified.',
                'count': config_7d.count(),
            })

        # After-hours activity — 22:00 to 05:59
        from django.db.models import Q
        after_hours = (
            qs.filter(created_at__gte=since_30d)
            .annotate(hour=ExtractHour('created_at'))
            .filter(Q(hour__gte=22) | Q(hour__lt=6))
        )
        if after_hours.count():
            signals.append({
                'severity': 'low', 'kind': 'after_hours',
                'title': f'{after_hours.count()} after-hours events (30d)',
                'detail': 'Activity between 22:00 and 06:00 — confirm on-call cover.',
                'count': after_hours.count(),
            })

        signals.sort(key=lambda s: {'high': 0, 'medium': 1, 'low': 2}[s['severity']])

        retention_days = (now - oldest).days if oldest else 0

        return Response({
            'generated_at': now,
            'window': {
                'days': span,
                'from': trend_start.isoformat(),
                'to': trend_end.isoformat(),
            },
            'kpis': {
                'total': total,
                # Activity tiles stay relative to *now* so a historical window
                # never shows a misleading zero.
                'last_24h': base.filter(created_at__gte=since_24h).count(),
                'last_7d': base.filter(created_at__gte=since_7d).count(),
                'critical': severity_rows.get('critical', 0),
                'warnings': severity_rows.get('warning', 0),
                'failures': qs.filter(status_code__gte=400).count(),
                'distinct_actors': qs.values('actor_user_id').distinct().count(),
                'modules': qs.exclude(object_type='').values('object_type').distinct().count(),
                'retention_days': retention_days,
            },
            'severity_mix': [
                {'severity': s, 'count': severity_rows.get(s, 0)}
                for s in severity_order
            ],
            'action_mix': action_rows,
            'module_mix': module_rows,
            'trend': trend,
            'hourly': hourly,
            'top_actors': actors,
            'signals': signals,
        })

    # ── Export ────────────────────────────────────────────────────────
    @action(detail=False, methods=['get'], url_path='export')
    def export(self, request):
        """Stream the current filtered set as CSV or JSON.

        Query params:
            fmt=csv|json      (default: csv)
            limit=1000        (cap rows; default 5000)

        NOTE: the parameter is ``fmt``, not ``format`` — DRF reserves
        ``?format=`` for its renderer override and raises Http404 for any
        value it doesn't recognise as a renderer.
        """
        import csv
        from django.http import HttpResponse, JsonResponse
        fmt = (request.query_params.get('fmt')
               or request.query_params.get('file_format')
               or 'csv').lower()
        try:
            limit = int(request.query_params.get('limit', 5000))
        except ValueError:
            limit = 5000
        limit = max(1, min(limit, 20000))
        qs = self._filtered_queryset()[:limit]
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
