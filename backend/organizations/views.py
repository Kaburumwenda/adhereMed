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

# Length of the trend window returned for the Command Center sparklines.
ACTIVITY_DAYS = 14

# Hard cap for a custom traffic range. A quarter is plenty for a network
# monitor and keeps the `DailyUsage` scan bounded no matter what a client asks.
MAX_TRAFFIC_DAYS = 92

# Preset lengths the UI offers.
TRAFFIC_PRESETS = (7, 14, 30)


def _parse_iso_date(value):
    """Parse ``YYYY-MM-DD`` into a ``date``, or ``None`` when malformed."""
    from datetime import date as _date

    if not value:
        return None
    try:
        return _date.fromisoformat(str(value).strip()[:10])
    except (TypeError, ValueError):
        return None


def _resolve_traffic_range(request, today):
    """Work out the ``(start, end, kind, error)`` for a traffic request.

    Precedence: explicit ``start``/``end`` (also triggered by ``range=custom``)
    → ``window=N`` preset → the default preset. Always returns inclusive dates
    ordered oldest-first, clamped to ``MAX_TRAFFIC_DAYS``.
    """
    params = request.query_params
    raw_kind = (params.get('range') or '').strip().lower()
    start_raw = params.get('start')
    end_raw = params.get('end')

    wants_custom = raw_kind == 'custom' or bool(start_raw or end_raw)

    if wants_custom:
        start = _parse_iso_date(start_raw)
        end = _parse_iso_date(end_raw) or today

        if start and end and start > end:
            start, end = end, start
        if not start:
            # No usable start — fall back to the default preset but keep the
            # request honest about what happened.
            start = end - timedelta(days=ACTIVITY_DAYS - 1)
            return start, end, 'preset', None

        if end > today:
            end = today
        if start > end:
            start = end

        if (end - start).days + 1 > MAX_TRAFFIC_DAYS:
            start = end - timedelta(days=MAX_TRAFFIC_DAYS - 1)

        return start, end, 'custom', None

    try:
        window = int(params.get('window') or ACTIVITY_DAYS)
    except (TypeError, ValueError):
        window = ACTIVITY_DAYS
    window = max(2, min(MAX_TRAFFIC_DAYS, window))

    end = today
    start = end - timedelta(days=window - 1)
    kind = 'preset' if window in TRAFFIC_PRESETS else 'custom'
    return start, end, kind, None


def _day_buckets(rows, days=ACTIVITY_DAYS, as_float=False):
    """Turn ``[(date, value), ...]`` into a zero-filled list, oldest → newest.

    The database returns only the days that actually have rows; charts need a
    contiguous series so gaps read as zero instead of collapsing.
    """
    today = timezone.localdate()
    start = today - timedelta(days=days - 1)
    buckets = [0.0 if as_float else 0] * days
    for day, value in rows:
        if day is None or value is None:
            continue
        idx = (day - start).days
        if 0 <= idx < days:
            buckets[idx] = value
    return buckets


def _daily_activity():
    """14-day audit-event counts for the schema currently selected."""
    from django.db.models import Count
    from django.db.models.functions import TruncDate
    from audit.models import AuditEvent

    since = timezone.now() - timedelta(days=ACTIVITY_DAYS - 1)
    rows = (
        AuditEvent.objects.filter(created_at__gte=since)
        .annotate(day=TruncDate('created_at'))
        .values('day')
        .annotate(count=Count('id'))
        .order_by('day')
    )
    return _day_buckets([(r['day'], r['count']) for r in rows])


def _recent_events(limit=4):
    """Most recent audit events for the schema currently selected."""
    from audit.models import AuditEvent

    events = AuditEvent.objects.order_by('-created_at')[:limit]
    out = []
    for e in events:
        summary = e.description or ' '.join(
            part for part in (e.get_action_display(), e.object_type) if part
        )
        out.append({
            'id': e.id,
            'action': e.action,
            'severity': e.severity,
            'description': summary or 'Activity',
            'actor_email': e.actor_email,
            'actor_role': e.actor_role,
            'object_type': e.object_type,
            'object_repr': e.object_repr,
            'created_at': e.created_at.isoformat(),
        })
    return out


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
        # Trend + activity extras (Command Center).
        'activity_14d': [0] * ACTIVITY_DAYS,
        'revenue_14d': None,
        'recent_events': [],
        'last_event_at': None,
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
                    appointment_date=today,
                ).exclude(
                    status=Appointment.Status.CANCELLED,
                ).count()
            except Exception:
                pass

        if ttype in ('pharmacy', 'inventory'):
            # Aggregate in the database — the previous Python loop loaded every
            # stock row plus one query per stock's batches (~5s on real data).
            try:
                from django.db.models import DecimalField, ExpressionWrapper, F, Sum
                from inventory.models import StockBatch
                agg = StockBatch.objects.aggregate(
                    total=Sum(ExpressionWrapper(
                        F('quantity_remaining') * F('stock__cost_price'),
                        output_field=DecimalField(max_digits=20, decimal_places=2),
                    )),
                )
                stats['stock_value'] = float(agg['total'] or 0)
            except Exception:
                pass
            try:
                from django.db.models import F, Sum, Value
                from django.db.models.functions import Coalesce
                from inventory.models import MedicationStock
                stats['low_stock_items'] = (
                    MedicationStock.objects
                    .annotate(available=Coalesce(
                        Sum('batches__quantity_remaining'), Value(0)))
                    .filter(reorder_level__gt=0, available__lte=F('reorder_level'))
                    .count()
                )
            except Exception:
                pass

        if ttype in ('pharmacy', 'inventory'):
            try:
                from django.db.models import Sum
                from pos.models import POSTransaction
                cutoff = timezone.now() - timedelta(days=30)
                stats['revenue_30d'] = float(
                    POSTransaction.objects.filter(
                        created_at__gte=cutoff,
                        status=POSTransaction.SaleStatus.COMPLETED,
                    ).aggregate(total=Sum('total'))['total'] or 0
                )
            except Exception:
                pass
            # 14-day revenue trend for the Command Center sparkline.
            try:
                from django.db.models import Sum
                from django.db.models.functions import TruncDate
                from pos.models import POSTransaction
                since = timezone.now() - timedelta(days=ACTIVITY_DAYS - 1)
                rows = (
                    POSTransaction.objects
                    .filter(
                        created_at__gte=since,
                        status=POSTransaction.SaleStatus.COMPLETED,
                    )
                    .annotate(day=TruncDate('created_at'))
                    .values('day')
                    .annotate(total=Sum('total'))
                    .order_by('day')
                )
                stats['revenue_14d'] = _day_buckets(
                    [(r['day'], float(r['total'] or 0)) for r in rows],
                    as_float=True,
                )
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

        # ── Activity trail: 14-day trend + newest events ──
        try:
            stats['activity_14d'] = _daily_activity()
        except Exception:
            pass
        try:
            events = _recent_events()
            stats['recent_events'] = events
            stats['last_event_at'] = events[0]['created_at'] if events else None
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

    # Org-wide trend series, accumulated element-wise below.
    activity_trend = [0] * ACTIVITY_DAYS
    revenue_trend = [0.0] * ACTIVITY_DAYS
    activity_feed = []
    offline = []

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
            if v is not None and not isinstance(v, (list, dict)):
                totals[k] += v

        for i, n in enumerate(ts.get('activity_14d') or []):
            if i < ACTIVITY_DAYS:
                activity_trend[i] += n
        for i, n in enumerate(ts.get('revenue_14d') or []):
            if i < ACTIVITY_DAYS:
                revenue_trend[i] += n

        if not t.is_active:
            offline.append({'id': t.id, 'name': t.name, 'type': t.type})

        # Merge this tenant's newest events into the organisation-wide feed.
        for ev in ts.get('recent_events') or []:
            activity_feed.append({
                **ev,
                'tenant_id': t.id,
                'tenant_name': t.name,
                'tenant_type': t.type,
            })

    activity_feed.sort(key=lambda e: e.get('created_at') or '', reverse=True)

    totals['activity_14d'] = activity_trend
    totals['revenue_14d'] = revenue_trend
    totals['event_count_14d'] = sum(activity_trend)

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
        'activity': activity_feed[:12],
        'trend_days': ACTIVITY_DAYS,
        'generated_at': timezone.now().isoformat(),
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def organization_traffic(request):
    """Per-facility API traffic for the Command Center traffic monitor + chart.

    Two sources are merged:

    * ``DailyUsage`` — the durable, exact per-day request counter written by
      ``usage_billing.middleware.RequestUsageMiddleware``. It lives in the
      public schema, so every facility's history comes from a single query
      instead of switching schemas per tenant.
    * the middleware's in-process rolling window — a genuine last-minute /
      per-minute rate, which is what makes the monitor look alive.

    Range selection (mutually exclusive, ``range`` wins):

    ``window=7|14|30``  preset length ending today
    ``start=YYYY-MM-DD&end=YYYY-MM-DD``  explicit inclusive range
    ``range=custom`` plus ``start``/``end``  same, for readable URLs

    Custom ranges are clamped to ``MAX_TRAFFIC_DAYS`` so a stray date cannot
    ask the database for years of rows.
    """
    org = _get_org(request.user)
    if not org:
        return Response(
            {'detail': 'You are not part of an organization.'},
            status=status.HTTP_403_FORBIDDEN,
        )

    today = timezone.localdate()
    start, end, range_kind, range_error = _resolve_traffic_range(request, today)
    if range_error:
        return Response(
            {'detail': range_error},
            status=status.HTTP_400_BAD_REQUEST,
        )

    span = (end - start).days + 1
    # The comparison window (immediately before the selected one) is only
    # useful when it fits inside the same cap.
    prev_end = start - timedelta(days=1)
    prev_start = prev_end - timedelta(days=span - 1)
    earliest = min(start, prev_start)

    from usage_billing.middleware import (
        LIVE_WINDOW_SECONDS,
        live_traffic_snapshot,
    )
    from usage_billing.models import DailyUsage

    tenants = list(_linked_tenants(org))
    if not tenants:
        return Response({
            'facilities': [],
            'totals': {},
            'range': {
                'kind': range_kind,
                'start': start.isoformat(),
                'end': end.isoformat(),
                'days': span,
                'dates': [(start + timedelta(days=i)).isoformat() for i in range(span)],
            },
            'live_window_seconds': LIVE_WINDOW_SECONDS,
            'generated_at': timezone.now().isoformat(),
        })

    # One query covers every facility AND both the selected and comparison
    # windows — cheaper than two round-trips.
    rows = (
        DailyUsage.objects
        .filter(
            tenant_id__in=[t.id for t in tenants],
            date__gte=earliest,
            date__lte=end,
        )
        .values('tenant_id', 'date', 'request_count', 'last_updated')
    )

    by_tenant = {}
    for row in rows:
        by_tenant.setdefault(row['tenant_id'], {})[row['date']] = row

    dates = [(start + timedelta(days=i)) for i in range(span)]
    prev_dates = [(prev_start + timedelta(days=i)) for i in range(span)]

    live = live_traffic_snapshot()
    network_series = [0] * span
    network_prev = [0] * span
    facilities = []
    net_today = 0
    net_live_per_min = 0.0

    for tenant in tenants:
        days = by_tenant.get(tenant.id, {})

        def value_on(day):
            entry = days.get(day)
            return int(entry['request_count']) if entry else 0

        series = [value_on(d) for d in dates]
        previous = [value_on(d) for d in prev_dates]

        # "Today" only means something when the window actually ends today;
        # otherwise report the selected window's final day.
        today_count = series[-1] if series else 0
        yesterday_count = series[-2] if len(series) > 1 else 0
        total = sum(series)
        prev_total = sum(previous)
        peak = max(series) if series else 0
        peak_idx = series.index(peak) if series and peak else -1
        active_days = sum(1 for v in series if v)
        avg = round(total / active_days, 1) if active_days else 0.0

        if prev_total:
            trend = round((total - prev_total) / prev_total * 100, 1)
        else:
            trend = None

        last_seen = None
        seen_candidates = [e['last_updated'] for e in days.values() if e['last_updated']]
        if seen_candidates:
            last_seen = max(seen_candidates)

        live_row = live.get(tenant.schema_name) or {}
        per_min = float(live_row.get('per_min') or 0)
        last_60 = int(live_row.get('last_60s') or 0)
        live_age = live_row.get('last_seen_s')

        if not tenant.is_active:
            status = 'offline'
        elif last_60:
            status = 'flowing'
        elif today_count:
            status = 'idle'
        else:
            status = 'silent'

        net_today += today_count
        net_live_per_min += per_min
        for i, value in enumerate(series):
            network_series[i] += value
        for i, value in enumerate(previous):
            network_prev[i] += value

        facilities.append({
            'id': tenant.id,
            'name': tenant.name,
            'type': tenant.type,
            'slug': tenant.slug,
            'schema_name': tenant.schema_name,
            'is_active': tenant.is_active,
            'requests_today': today_count,
            'requests_yesterday': yesterday_count,
            'requests_total': total,
            'requests_previous_total': prev_total,
            'requests_peak': peak,
            'peak_date': dates[peak_idx].isoformat() if peak_idx >= 0 else None,
            'active_days': active_days,
            'avg_per_active_day': avg,
            'trend_pct': trend,
            'series': series,
            'previous_series': previous,
            'last_seen': last_seen.isoformat() if last_seen else None,
            'live_per_min': per_min,
            'live_last_60s': last_60,
            'live_age_seconds': live_age,
            'status': status,
        })

    # Busiest first — the monitor is read top-down.
    facilities.sort(key=lambda f: (-f['live_per_min'], -f['requests_today'], f['name']))

    net_total = sum(network_series)
    net_prev_total = sum(network_prev)
    trend_pct = None
    if net_prev_total:
        trend_pct = round((net_total - net_prev_total) / net_prev_total * 100, 1)

    net_peak = max(network_series) if network_series else 0
    net_peak_idx = network_series.index(net_peak) if net_peak else -1

    return Response({
        'facilities': facilities,
        'range': {
            'kind': range_kind,
            'start': start.isoformat(),
            'end': end.isoformat(),
            'days': span,
            'dates': [d.isoformat() for d in dates],
            'previous_start': prev_start.isoformat(),
            'previous_end': prev_end.isoformat(),
            'max_days': MAX_TRAFFIC_DAYS,
        },
        'totals': {
            'requests_today': net_today,
            'requests_total': net_total,
            'requests_previous_total': net_prev_total,
            'requests_peak': net_peak,
            'peak_date': dates[net_peak_idx].isoformat() if net_peak_idx >= 0 else None,
            'live_per_min': round(net_live_per_min, 2),
            'facilities_reporting': sum(1 for f in facilities if f['status'] in ('flowing', 'idle')),
            'facilities_offline': sum(1 for f in facilities if f['status'] == 'offline'),
            'facilities_silent': sum(1 for f in facilities if f['status'] == 'silent'),
            'facilities_active': sum(1 for f in facilities if f['requests_total']),
            'trend_pct': trend_pct,
            'series': network_series,
            'previous_series': network_prev,
        },
        'live_window_seconds': LIVE_WINDOW_SECONDS,
        'generated_at': timezone.now().isoformat(),
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
