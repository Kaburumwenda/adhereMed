from datetime import timedelta
from decimal import Decimal

from django.db.models import Sum, Count
from django.utils import timezone
from rest_framework import viewsets, filters, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend

from .models import DispensingRecord, DispenseReturn
from .serializers import DispensingRecordSerializer, DispenseReturnSerializer


class DispensingRecordViewSet(viewsets.ModelViewSet):
    queryset = DispensingRecord.objects.select_related('dispensed_by').all()
    serializer_class = DispensingRecordSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['dispensed_by', 'status', 'payment_method']
    search_fields = ['patient_name', 'patient_phone', 'receipt_number']
    ordering_fields = ['dispensed_at', 'total']

    def get_queryset(self):
        qs = super().get_queryset()
        params = self.request.query_params
        date_from = params.get('date_from')
        date_to = params.get('date_to')
        if date_from:
            qs = qs.filter(dispensed_at__date__gte=date_from)
        if date_to:
            qs = qs.filter(dispensed_at__date__lte=date_to)
        return qs

    @action(detail=False, methods=['get'])
    def stats(self, request):
        qs = DispensingRecord.objects.filter(status='completed')
        now = timezone.now()
        today = now.date()
        month_start = today.replace(day=1)

        today_qs = qs.filter(dispensed_at__date=today)
        month_qs = qs.filter(dispensed_at__date__gte=month_start)

        # Top selling items this month
        top = {}
        for rec in month_qs.only('items_dispensed'):
            for it in (rec.items_dispensed or []):
                name = it.get('medication_name') or 'Unknown'
                qty = float(it.get('qty') or 0)
                rev = float(it.get('line_total') or 0)
                row = top.setdefault(name, {'name': name, 'qty': 0.0, 'revenue': 0.0})
                row['qty'] += qty
                row['revenue'] += rev
        top_items = sorted(top.values(), key=lambda r: r['revenue'], reverse=True)[:5]

        return Response({
            'today_count': today_qs.count(),
            'today_revenue': float(today_qs.aggregate(s=Sum('total'))['s'] or 0),
            'month_count': month_qs.count(),
            'month_revenue': float(month_qs.aggregate(s=Sum('total'))['s'] or 0),
            'total_count': qs.count(),
            'total_revenue': float(qs.aggregate(s=Sum('total'))['s'] or 0),
            'top_items': top_items,
        })

    @action(detail=True, methods=['post'])
    def void(self, request, pk=None):
        record = self.get_object()
        if record.status == 'cancelled':
            return Response({'detail': 'Already cancelled'}, status=status.HTTP_400_BAD_REQUEST)
        record.status = 'cancelled'
        record.notes = (record.notes or '') + f"\n[Voided by {request.user} on {timezone.now():%Y-%m-%d %H:%M}]"
        record.save(update_fields=['status', 'notes'])
        # Best-effort restock
        try:
            from inventory.models import StockBatch
            for it in (record.items_dispensed or []):
                stock_id = it.get('stock_id')
                qty = int(float(it.get('qty') or 0))
                if not stock_id or qty <= 0:
                    continue
                batch = (
                    StockBatch.objects
                    .filter(stock_id=stock_id)
                    .order_by('expiry_date')
                    .first()
                )
                if batch:
                    batch.quantity_remaining += qty
                    batch.save(update_fields=['quantity_remaining'])
        except Exception:
            pass
        return Response(self.get_serializer(record).data)


class DispenseReturnViewSet(viewsets.ModelViewSet):
    queryset = DispenseReturn.objects.select_related('original', 'processed_by').all()
    serializer_class = DispenseReturnSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['reason', 'original']
    search_fields = ['reference', 'original__receipt_number', 'original__patient_name']
    ordering_fields = ['created_at', 'refund_amount']

    @action(detail=False, methods=['get'])
    def stats(self, request):
        from django.db.models import Sum
        qs = self.get_queryset()
        return Response({
            'total_returns': qs.count(),
            'total_refunded': float(qs.aggregate(s=Sum('refund_amount'))['s'] or 0),
        })
