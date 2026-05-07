from rest_framework import viewsets, filters, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from django.db.models import Sum, Count, Avg, Q
from django.db.models.functions import TruncDate
from django.utils import timezone
from datetime import timedelta, date as date_type

from .models import StaffProfile, Specialization
from .serializers import (
    StaffProfileSerializer, StaffCreateSerializer, StaffUpdateSerializer,
    SpecializationSerializer,
)


class SpecializationViewSet(viewsets.ModelViewSet):
    queryset = Specialization.objects.all()
    serializer_class = SpecializationSerializer
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name']
    ordering_fields = ['name', 'created_at']


class StaffProfileViewSet(viewsets.ModelViewSet):
    queryset = StaffProfile.objects.select_related('user', 'department', 'specialization').all()
    serializer_class = StaffProfileSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['department', 'is_available', 'specialization', 'branch']
    search_fields = ['user__first_name', 'user__last_name', 'specialization__name']
    ordering_fields = ['created_at', 'specialization__name']

    def get_serializer_class(self):
        if self.action == 'create':
            return StaffCreateSerializer
        if self.action in ('update', 'partial_update'):
            return StaffUpdateSerializer
        return StaffProfileSerializer

    def create(self, request, *args, **kwargs):
        serializer = StaffCreateSerializer(
            data=request.data, context={'request': request},
        )
        serializer.is_valid(raise_exception=True)
        profile = serializer.save()
        return Response(
            StaffProfileSerializer(profile).data,
            status=status.HTTP_201_CREATED,
        )

    def update(self, request, *args, **kwargs):
        instance = self.get_object()
        partial = kwargs.pop('partial', False)
        serializer = StaffUpdateSerializer(
            data=request.data, partial=partial,
            context={'instance': instance, 'request': request},
        )
        serializer.is_valid(raise_exception=True)
        profile = serializer.update(instance, serializer.validated_data)
        return Response(StaffProfileSerializer(profile).data)

    def partial_update(self, request, *args, **kwargs):
        kwargs['partial'] = True
        return self.update(request, *args, **kwargs)

    @action(detail=False, methods=['get'])
    def performance(self, request):
        """Aggregated POS performance for all staff over a date range.

        Only completed transactions feed revenue/items KPIs; voids are
        counted separately. Admin-only is enforced by the frontend route
        guard; this endpoint also restricts non-admins to their own row.
        """
        from pos.models import POSTransaction, TransactionItem

        today = timezone.now().date()
        period = (request.query_params.get('period') or '30d').lower()
        date_from = request.query_params.get('date_from')
        date_to = request.query_params.get('date_to')
        branch_id = request.query_params.get('branch')

        if date_from and date_to:
            try:
                start = date_type.fromisoformat(date_from)
                end = date_type.fromisoformat(date_to)
                label = f'{start} – {end}'
            except ValueError:
                start, end, label = today, today, 'Today'
        else:
            mapping = {
                'today': (today, today, 'Today'),
                'yesterday': (today - timedelta(days=1), today - timedelta(days=1), 'Yesterday'),
                '7d': (today - timedelta(days=6), today, 'Last 7 days'),
                'week': (today - timedelta(days=6), today, 'Last 7 days'),
                '30d': (today - timedelta(days=29), today, 'Last 30 days'),
                'month': (today - timedelta(days=29), today, 'Last 30 days'),
                '90d': (today - timedelta(days=89), today, 'Last 90 days'),
                'year': (today - timedelta(days=364), today, 'Last 365 days'),
                '1y': (today - timedelta(days=364), today, 'Last 365 days'),
            }
            start, end, label = mapping.get(period, (today - timedelta(days=29), today, 'Last 30 days'))

        completed = POSTransaction.SaleStatus.COMPLETED
        voided = POSTransaction.SaleStatus.VOIDED if hasattr(POSTransaction.SaleStatus, 'VOIDED') else 'voided'

        tx_qs = POSTransaction.objects.filter(
            created_at__date__gte=start,
            created_at__date__lte=end,
        )
        if branch_id:
            tx_qs = tx_qs.filter(branch_id=branch_id)

        # Restrict non-admin users to their own row.
        ADMIN_ROLES = {'super_admin', 'tenant_admin', 'pharmacist'}
        is_admin = (
            getattr(request.user, 'is_superuser', False)
            or getattr(request.user, 'role', None) in ADMIN_ROLES
        )
        if not is_admin:
            tx_qs = tx_qs.filter(cashier=request.user)

        completed_qs = tx_qs.filter(status=completed)

        # Per-cashier aggregation (only users who actually have sales).
        from django.db.models import Min, Max
        per_user = (
            completed_qs.values('cashier_id')
            .annotate(
                transactions=Count('id'),
                revenue=Sum('total'),
                discount=Sum('discount'),
                avg_transaction=Avg('total'),
            )
        )
        bounds = {
            row['cashier_id']: row
            for row in completed_qs
                .annotate(_d=TruncDate('created_at'))
                .values('cashier_id')
                .annotate(
                    first_sale=Min('created_at'),
                    last_sale=Max('created_at'),
                    active_days=Count('_d', distinct=True),
                )
        }
        items_per_user = {
            row['transaction__cashier_id']: row['items_sold'] or 0
            for row in TransactionItem.objects
                .filter(transaction__in=completed_qs)
                .values('transaction__cashier_id')
                .annotate(items_sold=Sum('quantity'))
        }
        voided_per_user = {
            row['cashier_id']: row['voided_count']
            for row in tx_qs.filter(status=voided).values('cashier_id').annotate(voided_count=Count('id'))
        }

        sales_by_user = {row['cashier_id']: row for row in per_user}

        # Build the staff list to include (everyone with a StaffProfile,
        # plus any cashier who logged sales but lacks a profile).
        staff_qs = StaffProfile.objects.select_related('user', 'specialization', 'branch')
        if branch_id:
            staff_qs = staff_qs.filter(Q(branch_id=branch_id) | Q(user_id__in=sales_by_user.keys()))
        if not is_admin:
            staff_qs = staff_qs.filter(user=request.user)

        rows = []
        seen_user_ids = set()
        for sp in staff_qs:
            uid = sp.user_id
            seen_user_ids.add(uid)
            sales = sales_by_user.get(uid) or {}
            b = bounds.get(uid) or {}
            rows.append({
                'staff_id': sp.id,
                'user_id': uid,
                'name': sp.user.full_name or sp.user.email,
                'email': sp.user.email,
                'role': sp.user.role,
                'specialization': sp.specialization.name if sp.specialization else None,
                'branch_id': sp.branch_id,
                'branch_name': sp.branch.name if sp.branch else None,
                'is_available': sp.is_available,
                'transactions': sales.get('transactions') or 0,
                'revenue': float(sales.get('revenue') or 0),
                'discount_given': float(sales.get('discount') or 0),
                'avg_transaction': round(float(sales.get('avg_transaction') or 0), 2),
                'items_sold': items_per_user.get(uid, 0),
                'voided_count': voided_per_user.get(uid, 0),
                'first_sale': b.get('first_sale'),
                'last_sale': b.get('last_sale'),
                'active_days': b.get('active_days') or 0,
            })

        # Include cashiers without a StaffProfile (admins only) so totals match.
        if is_admin:
            from django.contrib.auth import get_user_model
            User = get_user_model()
            extra_ids = [uid for uid in sales_by_user.keys() if uid and uid not in seen_user_ids]
            for u in User.objects.filter(id__in=extra_ids):
                sales = sales_by_user.get(u.id) or {}
                b = bounds.get(u.id) or {}
                rows.append({
                    'staff_id': None,
                    'user_id': u.id,
                    'name': u.full_name or u.email,
                    'email': u.email,
                    'role': u.role,
                    'specialization': None,
                    'branch_id': None,
                    'branch_name': None,
                    'is_available': u.is_active,
                    'transactions': sales.get('transactions') or 0,
                    'revenue': float(sales.get('revenue') or 0),
                    'discount_given': float(sales.get('discount') or 0),
                    'avg_transaction': round(float(sales.get('avg_transaction') or 0), 2),
                    'items_sold': items_per_user.get(u.id, 0),
                    'voided_count': voided_per_user.get(u.id, 0),
                    'first_sale': b.get('first_sale'),
                    'last_sale': b.get('last_sale'),
                    'active_days': b.get('active_days') or 0,
                })

        rows.sort(key=lambda r: r['revenue'], reverse=True)

        # Tenant-wide totals
        agg = completed_qs.aggregate(
            revenue=Sum('total'),
            transactions=Count('id'),
            discount=Sum('discount'),
            avg_transaction=Avg('total'),
        )
        items_total = TransactionItem.objects.filter(
            transaction__in=completed_qs
        ).aggregate(items_sold=Sum('quantity'))['items_sold'] or 0
        voided_total = tx_qs.filter(status=voided).count()
        active_staff = sum(1 for r in rows if r['transactions'] > 0)

        # Daily series (tenant-wide, for sparkline)
        daily = list(
            completed_qs.annotate(d=TruncDate('created_at'))
            .values('d')
            .annotate(revenue=Sum('total'), transactions=Count('id'))
            .order_by('d')
        )
        # Payment breakdown
        by_payment = list(
            completed_qs.values('payment_method')
            .annotate(revenue=Sum('total'), count=Count('id'))
            .order_by('-revenue')
        )

        return Response({
            'range': {
                'start': start.isoformat(),
                'end': end.isoformat(),
                'label': label,
            },
            'totals': {
                'revenue': float(agg['revenue'] or 0),
                'transactions': agg['transactions'] or 0,
                'discount_given': float(agg['discount'] or 0),
                'avg_transaction': round(float(agg['avg_transaction'] or 0), 2),
                'items_sold': int(items_total),
                'voided_count': voided_total,
                'active_staff': active_staff,
                'staff_count': len(rows),
            },
            'leaderboard': rows,
            'daily': [
                {'date': d['d'].isoformat() if d['d'] else None,
                 'revenue': float(d['revenue'] or 0),
                 'transactions': d['transactions']}
                for d in daily
            ],
            'by_payment': [
                {'payment_method': p['payment_method'],
                 'revenue': float(p['revenue'] or 0),
                 'count': p['count']}
                for p in by_payment
            ],
        })
