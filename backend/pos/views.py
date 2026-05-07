from rest_framework import viewsets, mixins, filters, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from django_filters.rest_framework import DjangoFilterBackend
from django.utils import timezone
from django.db.models import Sum, Count, Avg, F
from datetime import timedelta

from .models import POSTransaction, Customer, ParkedSale
from .serializers import POSTransactionSerializer, POSCheckoutSerializer, CustomerSerializer, ParkedSaleSerializer


# Roles that may view ALL POS records and analytics for the tenant.
# Anyone else (e.g. cashier, pharmacy_tech) only sees their own data.
ADMIN_ROLES = {'super_admin', 'tenant_admin', 'pharmacist'}


def _user_is_admin(user) -> bool:
    if not user or not getattr(user, 'is_authenticated', False):
        return False
    if getattr(user, 'is_superuser', False) or getattr(user, 'is_staff', False):
        return True
    return getattr(user, 'role', None) in ADMIN_ROLES


class CustomerViewSet(viewsets.ModelViewSet):
    queryset = Customer.objects.all()
    serializer_class = CustomerSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['is_active']
    search_fields = ['name', 'phone', 'email']
    ordering_fields = ['name', 'total_purchases', 'visit_count', 'created_at']


class POSTransactionViewSet(
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    mixins.CreateModelMixin,
    viewsets.GenericViewSet,
):
    queryset = POSTransaction.objects.select_related('cashier').prefetch_related('items').all()
    serializer_class = POSTransactionSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['payment_method', 'created_at', 'branch', 'status']
    search_fields = ['customer_name', 'transaction_number']
    ordering_fields = ['created_at', 'total']

    def get_queryset(self):
        from datetime import date as date_type
        qs = super().get_queryset()
        if not _user_is_admin(self.request.user):
            qs = qs.filter(cashier=self.request.user)
        date_from = self.request.query_params.get('date_from')
        date_to = self.request.query_params.get('date_to')
        period = self.request.query_params.get('period')
        today = timezone.now().date()

        if date_from and date_to:
            try:
                start = date_type.fromisoformat(date_from)
                end = date_type.fromisoformat(date_to)
                qs = qs.filter(created_at__date__gte=start, created_at__date__lte=end)
            except ValueError:
                pass
        elif period:
            if period == 'yesterday':
                day = today - timedelta(days=1)
                qs = qs.filter(created_at__date=day)
            elif period == 'week':
                qs = qs.filter(created_at__date__gte=today - timedelta(days=7))
            elif period == 'month':
                qs = qs.filter(created_at__date__gte=today - timedelta(days=30))
            elif period == 'year':
                qs = qs.filter(created_at__date__gte=today - timedelta(days=365))
            else:  # today
                qs = qs.filter(created_at__date=today)
        return qs

    def get_serializer_class(self):
        if self.action == 'create':
            return POSCheckoutSerializer
        return POSTransactionSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        transaction = serializer.save()
        return Response(
            POSTransactionSerializer(transaction).data,
            status=status.HTTP_201_CREATED,
        )

    @action(detail=False, methods=['get'])
    def today(self, request):
        today = timezone.now().date()
        qs = self.get_queryset().filter(
            created_at__date=today,
            status=POSTransaction.SaleStatus.COMPLETED,
        )
        serializer = POSTransactionSerializer(qs, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def export(self, request):
        """Export transactions as CSV for a given period or date range."""
        import csv
        from io import StringIO
        from datetime import date as date_type
        from django.http import HttpResponse

        today = timezone.now().date()
        period = request.query_params.get('period', 'today')
        date_from = request.query_params.get('date_from')
        date_to = request.query_params.get('date_to')

        if date_from and date_to:
            try:
                start = date_type.fromisoformat(date_from)
                end = date_type.fromisoformat(date_to)
            except ValueError:
                start = end = today
        else:
            if period == 'yesterday':
                start = end = today - timedelta(days=1)
            elif period == 'week':
                start = today - timedelta(days=7)
                end = today
            elif period == 'month':
                start = today - timedelta(days=30)
                end = today
            elif period == 'year':
                start = today - timedelta(days=365)
                end = today
            else:  # today
                start = end = today

        qs = (
            POSTransaction.objects
            .select_related('cashier')
            .prefetch_related('items')
            .filter(created_at__date__gte=start, created_at__date__lte=end)
            .order_by('created_at')
        )
        if not _user_is_admin(request.user):
            qs = qs.filter(cashier=request.user)

        output = StringIO()
        writer = csv.writer(output)
        writer.writerow([
            'Receipt #', 'Date', 'Customer Name', 'Customer Phone',
            'Payment Method', 'Status',
            'Subtotal (KSh)', 'Discount (KSh)', 'Tax (KSh)', 'Total (KSh)',
            'Items', 'Served By',
        ])
        for t in qs:
            items_str = '; '.join(
                f'{item.medication_name} x{item.quantity}'
                for item in t.items.all()
            )
            writer.writerow([
                t.transaction_number,
                t.created_at.strftime('%Y-%m-%d %H:%M'),
                t.customer_name or 'Walk-in',
                t.customer_phone or '',
                t.payment_method,
                t.status,
                float(t.subtotal),
                float(t.discount),
                float(t.tax),
                float(t.total),
                items_str,
                t.cashier.full_name if t.cashier else '',
            ])

        filename = f'transactions_{start}_{end}.csv'
        response = HttpResponse(
            output.getvalue(), content_type='text/csv; charset=utf-8'
        )
        response['Content-Disposition'] = f'attachment; filename="{filename}"'
        return response

    @action(detail=True, methods=['patch'])
    def update_status(self, request, pk=None):
        transaction = self.get_object()
        status_val = request.data.get('status')
        valid = [s[0] for s in POSTransaction.SaleStatus.choices]
        if status_val not in valid:
            return Response(
                {'error': f'Invalid status. Valid values: {valid}'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        transaction.status = status_val
        transaction.save(update_fields=['status'])
        return Response(POSTransactionSerializer(transaction).data)


class SalesAnalyticsView(APIView):
    """Aggregated sales analytics for the pharmacy dashboard."""

    def get(self, request):
        now = timezone.now()
        today = now.date()
        period = request.query_params.get('period', 'today')
        date_from = request.query_params.get('date_from')
        date_to = request.query_params.get('date_to')

        if date_from and date_to:
            from datetime import date as date_type
            try:
                start = date_type.fromisoformat(date_from)
                end = date_type.fromisoformat(date_to)
            except ValueError:
                start = today
                end = today
            transactions = POSTransaction.objects.filter(
                created_at__date__gte=start,
                created_at__date__lte=end,
            )
        else:
            if period == 'today':
                start = today
            elif period == 'week':
                start = today - timedelta(days=7)
            elif period == 'month':
                start = today - timedelta(days=30)
            elif period == 'year':
                start = today - timedelta(days=365)
            else:
                start = today
            end = today
            transactions = POSTransaction.objects.filter(created_at__date__gte=start)

        branch_id = request.query_params.get('branch_id')
        if branch_id:
            transactions = transactions.filter(branch_id=branch_id)
        if not _user_is_admin(request.user):
            transactions = transactions.filter(cashier=request.user)
        transactions = transactions.filter(status=POSTransaction.SaleStatus.COMPLETED)
        agg = transactions.aggregate(
            total_revenue=Sum('total'),
            total_discount=Sum('discount'),
            transaction_count=Count('id'),
            avg_transaction=Avg('total'),
        )

        # Payment method breakdown
        payment_breakdown = (
            transactions.values('payment_method')
            .annotate(total=Sum('total'), count=Count('id'))
            .order_by('-total')
        )

        # Daily sales for the period (last 30 entries max)
        from django.db.models.functions import TruncDate
        daily = (
            transactions
            .annotate(date=TruncDate('created_at'))
            .values('date')
            .annotate(revenue=Sum('total'), count=Count('id'))
            .order_by('date')
        )[:30]

        # Top selling items (with category)
        from pos.models import TransactionItem
        txn_filter = {
            'transaction__created_at__date__gte': start,
            'transaction__created_at__date__lte': end,
            'transaction__status': POSTransaction.SaleStatus.COMPLETED,
        }
        if branch_id:
            txn_filter['transaction__branch_id'] = branch_id
        if not _user_is_admin(request.user):
            txn_filter['transaction__cashier'] = request.user
        top_items = (
            TransactionItem.objects
            .filter(**txn_filter)
            .values('medication_name', category_name=F('stock__category__name'))
            .annotate(
                total_qty=Sum('quantity'),
                total_revenue=Sum('total_price'),
            )
            .order_by('-total_qty')[:10]
        )

        # Category sales breakdown
        cat_filter = {**txn_filter, 'stock__category__isnull': False}
        category_sales = (
            TransactionItem.objects
            .filter(**cat_filter)
            .values(category_name=F('stock__category__name'))
            .annotate(
                total_qty=Sum('quantity'),
                total_revenue=Sum('total_price'),
                item_count=Count('id'),
            )
            .order_by('-total_revenue')
        )

        return Response({
            'total_revenue': float(agg['total_revenue'] or 0),
            'total_discount': float(agg['total_discount'] or 0),
            'transaction_count': agg['transaction_count'] or 0,
            'avg_transaction': round(float(agg['avg_transaction'] or 0), 2),
            'payment_breakdown': list(payment_breakdown),
            'daily_sales': list(daily),
            'top_selling_items': list(top_items),
            'category_sales': list(category_sales),
        })


class ParkedSaleViewSet(viewsets.ModelViewSet):
    queryset = ParkedSale.objects.select_related('cashier').all()
    serializer_class = ParkedSaleSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['cashier', 'branch']
    search_fields = ['park_number', 'customer_name', 'customer_phone']
    ordering_fields = ['created_at', 'updated_at']

    def get_queryset(self):
        qs = super().get_queryset()
        # Non-admin users only see their own parked sales.
        if not _user_is_admin(self.request.user):
            qs = qs.filter(cashier=self.request.user)
        # mine=1 → only this cashier's parked sales (kept for explicit filtering)
        elif self.request.query_params.get('mine') in ('1', 'true', 'True'):
            qs = qs.filter(cashier=self.request.user)
        return qs



# ------------------------------------------------------------------------------
# Cashier shifts (Z-Report)
# ------------------------------------------------------------------------------
from .models import CashierShift, LoyaltyTransaction
from .serializers import CashierShiftSerializer, LoyaltyTransactionSerializer


class CashierShiftViewSet(viewsets.ModelViewSet):
    queryset = CashierShift.objects.select_related('cashier', 'branch').all()
    serializer_class = CashierShiftSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'cashier', 'branch']
    search_fields = ['reference']
    ordering = ['-opened_at']

    def get_queryset(self):
        qs = super().get_queryset()
        user = self.request.user
        if not _user_is_admin(user):
            qs = qs.filter(cashier=user)
        return qs

    @action(detail=False, methods=['get'])
    def current(self, request):
        """Return current open shift for the calling user, if any."""
        shift = (CashierShift.objects
                 .filter(cashier=request.user, status=CashierShift.Status.OPEN)
                 .order_by('-opened_at').first())
        if not shift:
            return Response(None)
        return Response(self.get_serializer(shift).data)

    @action(detail=True, methods=['post'])
    def close(self, request, pk=None):
        shift = self.get_object()
        if shift.status != CashierShift.Status.OPEN:
            return Response({'detail': 'Shift already closed.'}, status=400)
        try:
            actual_cash = float(request.data.get('closing_actual_cash', 0))
        except (TypeError, ValueError):
            return Response({'detail': 'Invalid cash amount.'}, status=400)
        notes = request.data.get('closing_notes', '')

        # Compute Z-report from POS transactions during the shift
        end = timezone.now()
        txns = POSTransaction.objects.filter(
            cashier=shift.cashier, status='completed',
            created_at__gte=shift.opened_at, created_at__lte=end,
        )
        if shift.branch_id:
            txns = txns.filter(branch_id=shift.branch_id)

        agg = txns.aggregate(count=Count('id'), revenue=Sum('total'),
                             discount=Sum('discount'), tax=Sum('tax'))
        by_method = list(txns.values('payment_method')
                         .annotate(count=Count('id'), amount=Sum('total')))
        cash_sales = next((float(r['amount'] or 0) for r in by_method
                          if r['payment_method'] == 'cash'), 0.0)
        expected = float(shift.opening_float or 0) + cash_sales
        variance = actual_cash - expected

        z = {
            'opened_at': shift.opened_at.isoformat(),
            'closed_at': end.isoformat(),
            'opening_float': float(shift.opening_float or 0),
            'transactions': agg['count'] or 0,
            'gross_revenue': float(agg['revenue'] or 0),
            'discount': float(agg['discount'] or 0),
            'tax': float(agg['tax'] or 0),
            'cash_sales': cash_sales,
            'by_payment_method': [
                {'method': r['payment_method'],
                 'count': r['count'],
                 'amount': float(r['amount'] or 0)} for r in by_method
            ],
            'expected_cash': expected,
            'actual_cash': actual_cash,
            'variance': variance,
        }

        shift.expected_cash = expected
        shift.closing_actual_cash = actual_cash
        shift.cash_variance = variance
        shift.closed_at = end
        shift.closing_notes = notes
        shift.status = CashierShift.Status.CLOSED
        shift.z_report = z
        shift.save()
        return Response(self.get_serializer(shift).data)

    @action(detail=True, methods=['get'], url_path='z-report')
    def z_report(self, request, pk=None):
        shift = self.get_object()
        if shift.z_report:
            return Response(shift.z_report)
        # Live report for an open shift
        end = timezone.now()
        txns = POSTransaction.objects.filter(
            cashier=shift.cashier, status='completed',
            created_at__gte=shift.opened_at, created_at__lte=end,
        )
        if shift.branch_id:
            txns = txns.filter(branch_id=shift.branch_id)
        agg = txns.aggregate(count=Count('id'), revenue=Sum('total'))
        by_method = list(txns.values('payment_method')
                         .annotate(count=Count('id'), amount=Sum('total')))
        cash_sales = next((float(r['amount'] or 0) for r in by_method
                          if r['payment_method'] == 'cash'), 0.0)
        return Response({
            'opened_at': shift.opened_at.isoformat(),
            'closed_at': None,
            'opening_float': float(shift.opening_float or 0),
            'transactions': agg['count'] or 0,
            'gross_revenue': float(agg['revenue'] or 0),
            'cash_sales': cash_sales,
            'by_payment_method': [
                {'method': r['payment_method'], 'count': r['count'],
                 'amount': float(r['amount'] or 0)} for r in by_method
            ],
            'expected_cash': float(shift.opening_float or 0) + cash_sales,
            'live': True,
        })


# ------------------------------------------------------------------------------
# Loyalty
# ------------------------------------------------------------------------------
class LoyaltyTransactionViewSet(viewsets.ModelViewSet):
    queryset = LoyaltyTransaction.objects.select_related('customer', 'created_by').all()
    serializer_class = LoyaltyTransactionSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['type', 'customer']
    ordering = ['-created_at']

    def perform_create(self, serializer):
        from django.db import transaction as dbtx
        with dbtx.atomic():
            obj = serializer.save(created_by=self.request.user)
            customer = obj.customer
            customer.loyalty_points = (customer.loyalty_points or 0) + obj.points
            if customer.loyalty_points < 0:
                customer.loyalty_points = 0
            if not customer.loyalty_joined_at:
                customer.loyalty_joined_at = timezone.now()
            customer.recompute_tier()
            customer.save(update_fields=['loyalty_points', 'loyalty_tier', 'loyalty_joined_at'])
            obj.balance_after = customer.loyalty_points
            obj.save(update_fields=['balance_after'])

    @action(detail=False, methods=['post'], url_path='earn-from-transaction')
    def earn_from_transaction(self, request):
        """Award points based on a POSTransaction. Body: {transaction_id, rate?}.
        Default rate: 1 point per KSh 100 spent."""
        try:
            txn = POSTransaction.objects.get(id=request.data.get('transaction_id'))
        except POSTransaction.DoesNotExist:
            return Response({'detail': 'Transaction not found.'}, status=404)
        if not txn.customer_id:
            return Response({'detail': 'Transaction has no customer linked.'}, status=400)
        rate = float(request.data.get('rate') or 100)
        points = int(float(txn.total) // rate)
        if points <= 0:
            return Response({'detail': 'No points earned for this amount.'}, status=400)
        from django.db import transaction as dbtx
        with dbtx.atomic():
            customer = Customer.objects.select_for_update().get(id=txn.customer_id)
            entry = LoyaltyTransaction.objects.create(
                customer=customer, type=LoyaltyTransaction.Type.EARN,
                points=points, transaction=txn, created_by=request.user,
                notes=f'Earned on {txn.transaction_number}',
            )
            customer.loyalty_points = (customer.loyalty_points or 0) + points
            customer.recompute_tier()
            if not customer.loyalty_joined_at:
                customer.loyalty_joined_at = timezone.now()
            customer.save(update_fields=['loyalty_points', 'loyalty_tier', 'loyalty_joined_at'])
            entry.balance_after = customer.loyalty_points
            entry.save(update_fields=['balance_after'])
        return Response(LoyaltyTransactionSerializer(entry).data)

    @action(detail=False, methods=['get'])
    def stats(self, request):
        from .models import Customer as Cust
        agg = Cust.objects.aggregate(
            total_customers=Count('id'),
            total_points=Sum('loyalty_points'),
        )
        by_tier = list(Cust.objects.values('loyalty_tier').annotate(count=Count('id')))
        top = list(Cust.objects.filter(loyalty_points__gt=0)
                   .order_by('-loyalty_points')
                   .values('id', 'name', 'loyalty_points', 'loyalty_tier')[:10])
        return Response({
            'total_customers': agg['total_customers'] or 0,
            'total_points_outstanding': agg['total_points'] or 0,
            'by_tier': by_tier,
            'top_members': top,
        })
