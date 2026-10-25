from datetime import timedelta
from decimal import Decimal

from django.db.models import Count, Q, Sum
from django.utils import timezone
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import filters, permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView

from config.cache import tenant_cache

from .models import (
    Equipment,
    EquipmentCategory,
    EquipmentFault,
    EquipmentMaintenance,
    EquipmentTransfer,
)
from .serializers import (
    EquipmentCategorySerializer,
    EquipmentFaultSerializer,
    EquipmentListSerializer,
    EquipmentMaintenanceSerializer,
    EquipmentTransferSerializer,
    EquipmentWriteSerializer,
)

ADMIN_ROLES = {'tenant_admin', 'clinic_admin', 'admin', 'super_admin', 'inventory_admin'}


def _is_admin(user):
    if not user or not getattr(user, 'is_authenticated', False):
        return False
    if getattr(user, 'is_superuser', False):
        return True
    return getattr(user, 'role', '') in ADMIN_ROLES


def _user_site_id(user):
    """Clinic branch implied by the user's staff profile (via their drug store)."""
    if not user or not getattr(user, 'is_authenticated', False):
        return None
    try:
        branch = user.staff_profile.branch
    except Exception:
        return None
    return getattr(branch, 'site_id', None)


def _dashboard_scope(request):
    """Cache scope: admins share one entry, branch staff share per clinic site."""
    if _is_admin(getattr(request, 'user', None)):
        return 'all'
    return f'site:{_user_site_id(request.user) or "none"}'


class SiteScopedEquipmentMixin:
    """Admins see the whole network; branch staff see only their own branch."""

    site_field = 'site'

    def scope_queryset(self, qs, user=None):
        user = user or self.request.user
        if _is_admin(user):
            return qs
        site_id = _user_site_id(user)
        if not site_id:
            return qs
        lookup = {self.site_field: site_id}
        return qs.filter(Q(**lookup) | Q(**{f'{self.site_field}__isnull': True}))


class EquipmentCategoryViewSet(viewsets.ModelViewSet):
    queryset = EquipmentCategory.objects.all()
    serializer_class = EquipmentCategorySerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['is_active', 'requires_calibration']
    search_fields = ['name', 'code', 'description']
    ordering_fields = ['name', 'created_at']
    ordering = ['name']

    def get_queryset(self):
        return EquipmentCategory.objects.annotate(item_count=Count('items', distinct=True))

    def get_permissions(self):
        if self.request.method in permissions.SAFE_METHODS:
            return [permissions.IsAuthenticated()]
        return [permissions.IsAuthenticated()]


class EquipmentViewSet(SiteScopedEquipmentMixin, viewsets.ModelViewSet):
    """Clinic equipment register."""

    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = [
        'status', 'condition', 'criticality', 'category', 'site',
        'department', 'is_active', 'ownership', 'calibration_required',
    ]
    search_fields = [
        'name', 'asset_tag', 'serial_number', 'manufacturer',
        'model_number', 'location', 'description',
    ]
    ordering_fields = ['name', 'asset_tag', 'next_maintenance', 'purchase_date', 'created_at']
    ordering = ['name']

    def get_queryset(self):
        qs = (
            Equipment.objects
            .select_related('category', 'site', 'department', 'custodian')
            .annotate(
                open_fault_count=Count(
                    'faults',
                    filter=Q(faults__status__in=['open', 'investigating']),
                    distinct=True,
                ),
            )
        )
        qs = self.scope_queryset(qs)

        # Convenience filters used by the dashboard tiles.
        params = self.request.query_params
        if params.get('attention') == '1':
            today = timezone.localdate()
            qs = qs.filter(
                Q(next_maintenance__lt=today)
                | Q(next_calibration__lt=today)
                | Q(status__in=['out_of_service', 'under_maintenance'])
                | Q(warranty_expiry__lt=today)
            ).distinct()
        return qs

    def get_serializer_class(self):
        if self.action in ('create', 'update', 'partial_update'):
            return EquipmentWriteSerializer
        return EquipmentListSerializer

    def get_permissions(self):
        if self.request.method in permissions.SAFE_METHODS:
            return [permissions.IsAuthenticated()]
        return [permissions.IsAuthenticated()]

    def perform_create(self, serializer):
        serializer.save()

    # ── Per-asset detail bundle ──
    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        data = EquipmentListSerializer(instance, context={'request': request}).data
        data['maintenance'] = EquipmentMaintenanceSerializer(
            instance.maintenance_jobs.select_related('equipment')[:25],
            many=True,
            context={'request': request},
        ).data
        data['faults'] = EquipmentFaultSerializer(
            instance.faults.select_related('equipment')[:25],
            many=True,
            context={'request': request},
        ).data
        data['transfers'] = EquipmentTransferSerializer(
            instance.transfers.select_related('equipment')[:25],
            many=True,
            context={'request': request},
        ).data
        return Response(data)

    @action(detail=True, methods=['post'], url_path='report-fault')
    def report_fault(self, request, pk=None):
        """Raise a fault from the asset detail view."""
        equipment = self.get_object()
        serializer = EquipmentFaultSerializer(data={**request.data, 'equipment': equipment.pk})
        serializer.is_valid(raise_exception=True)
        serializer.save(reported_by=request.user)
        if equipment.status == Equipment.Status.OPERATIONAL:
            equipment.status = Equipment.Status.OUT_OF_SERVICE
            equipment.save(update_fields=['status', 'updated_at'])
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'], url_path='schedule-maintenance')
    def schedule_maintenance(self, request, pk=None):
        equipment = self.get_object()
        serializer = EquipmentMaintenanceSerializer(
            data={**request.data, 'equipment': equipment.pk},
        )
        serializer.is_valid(raise_exception=True)
        serializer.save(created_by=request.user)
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class EquipmentMaintenanceViewSet(SiteScopedEquipmentMixin, viewsets.ModelViewSet):
    serializer_class = EquipmentMaintenanceSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['kind', 'status', 'performed_by', 'equipment']
    search_fields = ['equipment__name', 'equipment__asset_tag', 'vendor_name', 'technician', 'description']
    ordering_fields = ['scheduled_date', 'completed_date', 'cost', 'created_at']
    ordering = ['-scheduled_date']
    site_field = 'equipment__site'

    def get_queryset(self):
        qs = EquipmentMaintenance.objects.select_related(
            'equipment', 'equipment__site', 'created_by',
        )
        qs = self.scope_queryset(qs)

        params = self.request.query_params
        if params.get('due') == '1':
            qs = qs.filter(
                status__in=['scheduled', 'in_progress'],
                scheduled_date__lte=timezone.localdate(),
            )
        return qs

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)

    @action(detail=True, methods=['post'])
    def complete(self, request, pk=None):
        """Close out a maintenance job and roll the asset's dates forward."""
        job = self.get_object()
        if job.status == EquipmentMaintenance.Status.COMPLETED:
            return Response(
                {'detail': 'This job is already completed.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        today = timezone.localdate()
        job.status = EquipmentMaintenance.Status.COMPLETED
        job.completed_date = job.completed_date or today
        for field in ('findings', 'cost', 'downtime_hours', 'next_due_date', 'technician'):
            if field in request.data:
                setattr(job, field, request.data[field])
        job.save()

        equipment = job.equipment
        updates = []
        if job.kind == EquipmentMaintenance.Kind.CALIBRATION:
            equipment.last_calibration = job.completed_date
            equipment.next_calibration = (
                job.next_due_date
                or job.completed_date + timedelta(days=equipment.effective_calibration_interval)
            )
            updates += ['last_calibration', 'next_calibration']
        else:
            equipment.last_maintenance = job.completed_date
            equipment.next_maintenance = (
                job.next_due_date
                or job.completed_date + timedelta(days=equipment.effective_maintenance_interval)
            )
            updates += ['last_maintenance', 'next_maintenance']

        # Bring the asset back online when the last open job is closed.
        still_open = equipment.maintenance_jobs.filter(
            status=EquipmentMaintenance.Status.IN_PROGRESS,
        ).exclude(pk=job.pk).exists()
        if not still_open and equipment.status == Equipment.Status.UNDER_MAINTENANCE:
            equipment.status = Equipment.Status.OPERATIONAL
            updates.append('status')

        if updates:
            equipment.save(update_fields=updates + ['updated_at'])

        return Response(self.get_serializer(job).data)

    @action(detail=True, methods=['post'])
    def start(self, request, pk=None):
        """Mark a scheduled job as in progress and park the asset."""
        job = self.get_object()
        job.status = EquipmentMaintenance.Status.IN_PROGRESS
        job.save(update_fields=['status', 'updated_at'])
        equipment = job.equipment
        if equipment.status == Equipment.Status.OPERATIONAL:
            equipment.status = Equipment.Status.UNDER_MAINTENANCE
            equipment.save(update_fields=['status', 'updated_at'])
        return Response(self.get_serializer(job).data)

    @action(detail=True, methods=['post'])
    def cancel(self, request, pk=None):
        job = self.get_object()
        job.status = EquipmentMaintenance.Status.CANCELLED
        job.save(update_fields=['status', 'updated_at'])
        return Response(self.get_serializer(job).data)


class EquipmentFaultViewSet(SiteScopedEquipmentMixin, viewsets.ModelViewSet):
    serializer_class = EquipmentFaultSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['severity', 'status', 'equipment']
    search_fields = ['title', 'description', 'equipment__name', 'equipment__asset_tag']
    ordering_fields = ['reported_at', 'severity', 'status']
    ordering = ['-reported_at']
    site_field = 'equipment__site'

    def get_queryset(self):
        qs = EquipmentFault.objects.select_related(
            'equipment', 'equipment__site', 'reported_by', 'resolved_by',
        )
        qs = self.scope_queryset(qs)
        if self.request.query_params.get('open') == '1':
            qs = qs.filter(status__in=['open', 'investigating'])
        return qs

    def perform_create(self, serializer):
        serializer.save(reported_by=self.request.user)

    @action(detail=True, methods=['post'])
    def resolve(self, request, pk=None):
        fault = self.get_object()
        fault.status = EquipmentFault.Status.RESOLVED
        fault.resolved_at = timezone.now()
        fault.resolved_by = request.user
        fault.resolution = request.data.get('resolution', fault.resolution)
        if 'downtime_hours' in request.data:
            fault.downtime_hours = request.data['downtime_hours']
        fault.save()

        equipment = fault.equipment
        if (
            equipment.status == Equipment.Status.OUT_OF_SERVICE
            and not equipment.faults.filter(status__in=['open', 'investigating']).exists()
        ):
            equipment.status = Equipment.Status.OPERATIONAL
            equipment.save(update_fields=['status', 'updated_at'])

        return Response(self.get_serializer(fault).data)

    @action(detail=True, methods=['post'])
    def dismiss(self, request, pk=None):
        fault = self.get_object()
        fault.status = EquipmentFault.Status.DISMISSED
        fault.resolved_at = timezone.now()
        fault.resolved_by = request.user
        fault.resolution = request.data.get('resolution', 'Dismissed — no fault found.')
        fault.save()
        return Response(self.get_serializer(fault).data)


class EquipmentTransferViewSet(SiteScopedEquipmentMixin, viewsets.ModelViewSet):
    serializer_class = EquipmentTransferSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['equipment', 'from_site', 'to_site']
    search_fields = ['equipment__name', 'equipment__asset_tag', 'reason']
    ordering_fields = ['transferred_at']
    ordering = ['-transferred_at']
    site_field = 'equipment__site'

    def get_queryset(self):
        qs = EquipmentTransfer.objects.select_related(
            'equipment', 'from_site', 'to_site',
            'from_department', 'to_department', 'transferred_by',
        )
        return self.scope_queryset(qs)

    def perform_create(self, serializer):
        transfer = serializer.save(transferred_by=self.request.user)
        # Apply the move so the register reflects where the asset now lives.
        equipment = transfer.equipment
        updates = []
        if transfer.to_site_id:
            equipment.site_id = transfer.to_site_id
            updates.append('site')
        if transfer.to_department_id:
            equipment.department_id = transfer.to_department_id
            updates.append('department')
        if updates:
            equipment.save(update_fields=updates + ['updated_at'])


class EquipmentDashboardView(APIView):
    """Everything the equipment command centre needs, in one request."""

    permission_classes = [permissions.IsAuthenticated]

    @tenant_cache('clinic.equipment', timeout=60, scope=_dashboard_scope)
    def get(self, request):
        today = timezone.localdate()
        soon = today + timedelta(days=30)

        qs = Equipment.objects.all()
        if not _is_admin(request.user):
            site_id = _user_site_id(request.user)
            if site_id:
                qs = qs.filter(Q(site_id=site_id) | Q(site__isnull=True))

        qs = qs.select_related('category', 'site')
        items = list(qs)

        def count(predicate):
            return sum(1 for e in items if predicate(e))

        total = len(items)
        operational = count(lambda e: e.status == Equipment.Status.OPERATIONAL)
        in_repair = count(lambda e: e.status == Equipment.Status.UNDER_MAINTENANCE)
        out_of_service = count(lambda e: e.status == Equipment.Status.OUT_OF_SERVICE)
        retired = count(lambda e: e.status == Equipment.Status.RETIRED)
        maintenance_overdue = count(lambda e: e.maintenance_overdue)
        calibration_overdue = count(lambda e: e.calibration_overdue)
        warranty_expiring = count(
            lambda e: e.warranty_expiry and today <= e.warranty_expiry <= soon
        )
        due_soon = count(lambda e: e.maintenance_due_soon)

        open_faults = EquipmentFault.objects.filter(status__in=['open', 'investigating'])
        if not _is_admin(request.user):
            site_id = _user_site_id(request.user)
            if site_id:
                open_faults = open_faults.filter(
                    Q(equipment__site_id=site_id) | Q(equipment__site__isnull=True),
                )
        open_fault_qs = open_faults.select_related('equipment')

        # ── Value / depreciation ──
        book_value = Decimal('0')
        purchase_total = Decimal('0')
        for e in items:
            price = e.purchase_price or Decimal('0')
            purchase_total += price
            if e.expected_life_years and e.purchase_date and price:
                age = (today - e.purchase_date).days / 365.25
                remaining = max(0.0, 1 - (age / e.expected_life_years))
                book_value += price * Decimal(str(round(remaining, 4)))
            else:
                book_value += price

        # ── Breakdowns ──
        by_category = {}
        for e in items:
            key = e.category.name if e.category_id else 'Uncategorised'
            by_category.setdefault(key, {'name': key, 'count': 0, 'value': Decimal('0')})
            by_category[key]['count'] += 1
            by_category[key]['value'] += e.purchase_price or Decimal('0')
        categories = sorted(by_category.values(), key=lambda r: -r['count'])

        by_status = {}
        for e in items:
            label = e.get_status_display()
            by_status[label] = by_status.get(label, 0) + 1

        by_site = {}
        for e in items:
            label = e.site.name if e.site_id and e.site else 'Unassigned'
            by_site.setdefault(label, {'name': label, 'count': 0, 'operational': 0, 'at_risk': 0})
            by_site[label]['count'] += 1
            if e.status == Equipment.Status.OPERATIONAL:
                by_site[label]['operational'] += 1
            if e.health_score < 65:
                by_site[label]['at_risk'] += 1

        # ── Attention list ──
        attention = []
        for e in items:
            reasons = []
            if e.maintenance_overdue:
                reasons.append({'type': 'maintenance', 'label': f'Maintenance {abs(e.days_to_maintenance)}d overdue'})
            elif e.maintenance_due_soon:
                reasons.append({'type': 'maintenance', 'label': f'Service in {e.days_to_maintenance}d'})
            if e.calibration_overdue:
                reasons.append({'type': 'calibration', 'label': f'Calibration {abs(e.days_to_calibration)}d overdue'})
            if e.status == Equipment.Status.OUT_OF_SERVICE:
                reasons.append({'type': 'status', 'label': 'Out of service'})
            if e.status == Equipment.Status.UNDER_MAINTENANCE:
                reasons.append({'type': 'status', 'label': 'Under maintenance'})
            if e.condition in (Equipment.Condition.POOR, Equipment.Condition.UNUSABLE):
                reasons.append({'type': 'condition', 'label': e.get_condition_display()})
            if e.warranty_expiry and today <= e.warranty_expiry <= soon:
                reasons.append({'type': 'warranty', 'label': f'Warranty ends in {(e.warranty_expiry - today).days}d'})
            if reasons:
                attention.append({
                    'id': e.pk,
                    'name': e.name,
                    'asset_tag': e.asset_tag,
                    'site': e.site.name if e.site_id and e.site else None,
                    'health_score': e.health_score,
                    'health_label': e.health_label,
                    'reasons': reasons[:3],
                })
        attention.sort(key=lambda r: (r['health_score'], -len(r['reasons'])))
        attention = attention[:12]

        # ── Upcoming maintenance ──
        jobs = EquipmentMaintenance.objects.filter(
            status__in=['scheduled', 'in_progress'],
        ).select_related('equipment', 'equipment__site')
        if not _is_admin(request.user):
            site_id = _user_site_id(request.user)
            if site_id:
                jobs = jobs.filter(
                    Q(equipment__site_id=site_id) | Q(equipment__site__isnull=True),
                )
        upcoming_jobs = []
        for job in jobs.order_by('scheduled_date')[:15]:
            upcoming_jobs.append({
                'id': job.pk,
                'equipment': job.equipment.name,
                'asset_tag': job.equipment.asset_tag,
                'site': job.equipment.site.name if job.equipment.site_id and job.equipment.site else None,
                'kind': job.kind,
                'kind_label': job.get_kind_display(),
                'status': job.status,
                'status_label': job.get_status_display(),
                'scheduled_date': job.scheduled_date,
                'days_until_due': job.days_until_due,
                'is_overdue': job.is_overdue,
                'vendor_name': job.vendor_name,
            })

        # ── Fault feed ──
        fault_feed = []
        for fault in open_fault_qs.order_by('-reported_at')[:10]:
            fault_feed.append({
                'id': fault.pk,
                'title': fault.title,
                'equipment': fault.equipment.name,
                'asset_tag': fault.equipment.asset_tag,
                'severity': fault.severity,
                'severity_label': fault.get_severity_display(),
                'status': fault.status,
                'status_label': fault.get_status_display(),
                'reported_at': fault.reported_at,
                'days_open': fault.days_open,
            })

        # ── Spend ──
        year_start = today.replace(month=1, day=1)
        maint_qs = EquipmentMaintenance.objects.filter(
            status='completed', completed_date__gte=year_start,
        )
        if not _is_admin(request.user):
            site_id = _user_site_id(request.user)
            if site_id:
                maint_qs = maint_qs.filter(equipment__site_id=site_id)
        spend = maint_qs.aggregate(total=Sum('cost'), downtime=Sum('downtime_hours'))

        # 12-month maintenance spend trend (oldest → newest)
        def _month_start(offset):
            """First day of the month ``offset`` months before the current one."""
            year, month = today.year, today.month - offset
            while month <= 0:
                month += 12
                year -= 1
            return today.replace(year=year, month=month, day=1)

        def _next_month(day):
            if day.month == 12:
                return day.replace(year=day.year + 1, month=1, day=1)
            return day.replace(month=day.month + 1, day=1)

        trend = []
        for i in range(11, -1, -1):
            start = _month_start(i)
            end = _next_month(start) - timedelta(days=1)
            agg = maint_qs.filter(
                completed_date__gte=start, completed_date__lte=end,
            ).aggregate(total=Sum('cost'))
            trend.append({
                'label': start.strftime('%b'),
                'year': start.year,
                'month': start.month,
                'value': float(agg['total'] or 0),
            })

        return Response({
            'generated_at': timezone.now().isoformat(),
            'kpis': {
                'total': total,
                'operational': operational,
                'in_repair': in_repair,
                'out_of_service': out_of_service,
                'retired': retired,
                'maintenance_overdue': maintenance_overdue,
                'calibration_overdue': calibration_overdue,
                'maintenance_due_soon': due_soon,
                'warranty_expiring': warranty_expiring,
                'open_faults': open_fault_qs.count(),
                'uptime_pct': round((operational / total) * 100, 1) if total else 0,
                'purchase_value': float(purchase_total),
                'book_value': float(round(book_value, 2)),
                'maintenance_spend_ytd': float(spend['total'] or 0),
                'downtime_hours_ytd': float(spend['downtime'] or 0),
            },
            'by_category': [
                {'name': row['name'], 'count': row['count'], 'value': float(row['value'])}
                for row in categories
            ],
            'by_status': [{'label': k, 'count': v} for k, v in by_status.items()],
            'by_site': sorted(by_site.values(), key=lambda r: -r['count']),
            'attention': attention,
            'upcoming_maintenance': upcoming_jobs,
            'open_faults': fault_feed,
            'spend_trend': trend,
        })
