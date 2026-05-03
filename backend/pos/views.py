from rest_framework import viewsets, mixins, filters, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from django_filters.rest_framework import DjangoFilterBackend
from django.utils import timezone
from django.db.models import Sum, Count, Avg, F
from datetime import timedelta

from .models import POSTransaction, Customer
from .serializers import POSTransactionSerializer, POSCheckoutSerializer, CustomerSerializer


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
    filterset_fields = ['payment_method', 'created_at', 'branch']
    search_fields = ['customer_name', 'transaction_number']
    ordering_fields = ['created_at', 'total']

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
        qs = self.get_queryset().filter(created_at__date=today)
        serializer = POSTransactionSerializer(qs, many=True)
        return Response(serializer.data)


class SalesAnalyticsView(APIView):
    """Aggregated sales analytics for the pharmacy dashboard."""

    def get(self, request):
        now = timezone.now()
        today = now.date()
        period = request.query_params.get('period', 'today')

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

        transactions = POSTransaction.objects.filter(created_at__date__gte=start)
        branch_id = request.query_params.get('branch_id')
        if branch_id:
            transactions = transactions.filter(branch_id=branch_id)
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
        txn_filter = {'transaction__created_at__date__gte': start}
        if branch_id:
            txn_filter['transaction__branch_id'] = branch_id
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
