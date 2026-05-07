from datetime import datetime, timedelta
from decimal import Decimal

from django.db.models import Count, Sum, Q
from django.utils import timezone
from rest_framework import viewsets, filters, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend

from .models import Expense, ExpenseCategory
from .serializers import ExpenseSerializer, ExpenseCategorySerializer


class ExpenseCategoryViewSet(viewsets.ModelViewSet):
    queryset = ExpenseCategory.objects.all()
    serializer_class = ExpenseCategorySerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['is_active']
    search_fields = ['name']
    ordering_fields = ['name', 'created_at']

    def get_queryset(self):
        qs = super().get_queryset()
        return qs.annotate(
            expense_count=Count('expenses'),
            total_spent=Sum('expenses__amount'),
        )


class ExpenseViewSet(viewsets.ModelViewSet):
    queryset = Expense.objects.select_related('category', 'supplier', 'submitted_by', 'approved_by').all()
    serializer_class = ExpenseSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'category', 'payment_method', 'is_recurring', 'supplier']
    search_fields = ['reference', 'title', 'vendor', 'description', 'payment_reference']
    ordering_fields = ['expense_date', 'amount', 'created_at', 'due_date']

    def get_queryset(self):
        qs = super().get_queryset()
        params = self.request.query_params
        date_from = params.get('date_from')
        date_to = params.get('date_to')
        min_amount = params.get('min_amount')
        max_amount = params.get('max_amount')
        if date_from:
            qs = qs.filter(expense_date__gte=date_from)
        if date_to:
            qs = qs.filter(expense_date__lte=date_to)
        if min_amount:
            try:
                qs = qs.filter(amount__gte=Decimal(min_amount))
            except Exception:
                pass
        if max_amount:
            try:
                qs = qs.filter(amount__lte=Decimal(max_amount))
            except Exception:
                pass
        return qs

    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        exp = self.get_object()
        if exp.status not in (Expense.Status.PENDING,):
            return Response({'detail': f'Cannot approve from status {exp.status}.'}, status=400)
        exp.status = Expense.Status.APPROVED
        exp.approved_at = timezone.now()
        if request.user and request.user.is_authenticated:
            exp.approved_by = request.user
        exp.save(update_fields=['status', 'approved_at', 'approved_by', 'updated_at'])
        return Response(self.get_serializer(exp).data)

    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        exp = self.get_object()
        reason = request.data.get('reason') or ''
        exp.status = Expense.Status.REJECTED
        if reason:
            exp.notes = (exp.notes + '\n' if exp.notes else '') + f'Rejected: {reason}'
        exp.save(update_fields=['status', 'notes', 'updated_at'])
        return Response(self.get_serializer(exp).data)

    @action(detail=True, methods=['post'])
    def mark_paid(self, request, pk=None):
        exp = self.get_object()
        if exp.status not in (Expense.Status.APPROVED, Expense.Status.PENDING):
            return Response({'detail': f'Cannot mark as paid from status {exp.status}.'}, status=400)
        exp.status = Expense.Status.PAID
        exp.paid_at = timezone.now()
        # Optional payment-method override on payment
        method = request.data.get('payment_method')
        ref = request.data.get('payment_reference')
        update_fields = ['status', 'paid_at', 'updated_at']
        if method:
            exp.payment_method = method
            update_fields.append('payment_method')
        if ref:
            exp.payment_reference = ref
            update_fields.append('payment_reference')
        exp.save(update_fields=update_fields)
        return Response(self.get_serializer(exp).data)

    @action(detail=False, methods=['get'])
    def summary(self, request):
        """Aggregate KPIs + breakdowns for dashboards."""
        qs = self.get_queryset()
        today = timezone.localdate()
        month_start = today.replace(day=1)

        totals = qs.aggregate(
            total=Sum('amount'),
            count=Count('id'),
        )
        by_status = list(qs.values('status').annotate(total=Sum('amount'), count=Count('id')))
        by_method = list(qs.values('payment_method').annotate(total=Sum('amount'), count=Count('id')))
        by_category = list(
            qs.values('category', 'category__name', 'category__color')
            .annotate(total=Sum('amount'), count=Count('id'))
            .order_by('-total')[:10]
        )
        this_month_total = qs.filter(expense_date__gte=month_start).aggregate(s=Sum('amount'))['s'] or 0
        pending_total = qs.filter(status=Expense.Status.PENDING).aggregate(s=Sum('amount'))['s'] or 0
        paid_total = qs.filter(status=Expense.Status.PAID).aggregate(s=Sum('amount'))['s'] or 0
        overdue = qs.filter(
            due_date__isnull=False, due_date__lt=today,
        ).exclude(status__in=[Expense.Status.PAID, Expense.Status.CANCELLED, Expense.Status.REJECTED])
        overdue_total = overdue.aggregate(s=Sum('amount'))['s'] or 0

        # last 12 months trend
        trend = []
        y, m = month_start.year, month_start.month
        for i in range(11, -1, -1):
            mm = m - i
            yy = y
            while mm <= 0:
                mm += 12
                yy -= 1
            start = month_start.replace(year=yy, month=mm, day=1)
            nm = mm + 1
            ny = yy
            if nm > 12:
                nm = 1
                ny += 1
            end = start.replace(year=ny, month=nm, day=1)
            total = qs.filter(expense_date__gte=start, expense_date__lt=end).aggregate(s=Sum('amount'))['s'] or 0
            trend.append({'month': start.isoformat(), 'total': float(total)})

        return Response({
            'total': float(totals['total'] or 0),
            'count': totals['count'] or 0,
            'this_month_total': float(this_month_total),
            'pending_total': float(pending_total),
            'paid_total': float(paid_total),
            'overdue_total': float(overdue_total),
            'overdue_count': overdue.count(),
            'by_status': [
                {'status': r['status'], 'total': float(r['total'] or 0), 'count': r['count']}
                for r in by_status
            ],
            'by_method': [
                {'method': r['payment_method'], 'total': float(r['total'] or 0), 'count': r['count']}
                for r in by_method
            ],
            'by_category': [
                {
                    'category_id': r['category'],
                    'name': r['category__name'] or 'Uncategorized',
                    'color': r['category__color'] or '',
                    'total': float(r['total'] or 0),
                    'count': r['count'],
                }
                for r in by_category
            ],
            'trend': trend,
        })
