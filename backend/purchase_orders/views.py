from rest_framework import viewsets, filters, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend

from .models import PurchaseOrder, GoodsReceivedNote
from .serializers import (
    PurchaseOrderSerializer,
    GoodsReceivedNoteSerializer,
    revert_received_items,
)


class PurchaseOrderViewSet(viewsets.ModelViewSet):
    queryset = PurchaseOrder.objects.select_related('supplier', 'ordered_by').prefetch_related('grns').all()
    serializer_class = PurchaseOrderSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'supplier']
    search_fields = ['po_number', 'supplier__name']
    ordering_fields = ['created_at', 'order_date', 'total_cost']

    @action(detail=True, methods=['get'])
    def return_preview(self, request, pk=None):
        """Show what would happen if this PO were returned (without applying)."""
        po = self.get_object()
        preview = []
        from inventory.models import MedicationStock, StockBatch
        for it in (po.items or []):
            if not it.get('_synced') or it.get('_returned'):
                continue
            try:
                stock = MedicationStock.objects.get(pk=it['medication_stock_id'])
            except MedicationStock.DoesNotExist:
                continue
            batch = StockBatch.objects.filter(stock=stock, batch_number=it.get('batch_number')).first()
            received = int(it.get('qty') or 0)
            consumed = 0
            remaining = 0
            if batch:
                remaining = int(batch.quantity_remaining)
                consumed = max(0, int(batch.quantity_received) - remaining)
            preview.append({
                'name': it.get('name') or stock.medication_name,
                'received': received,
                'consumed': consumed,
                'remaining': remaining,
                'current_cost_price': float(stock.cost_price or 0),
                'previous_cost_price': it.get('_prev_cost_price'),
                'current_selling_price': float(stock.selling_price or 0),
                'previous_selling_price': it.get('_prev_selling_price'),
            })
        return Response({
            'po_number': po.po_number,
            'status': po.status,
            'items': preview,
            'has_consumed': any(p['consumed'] > 0 for p in preview),
        })

    @action(detail=True, methods=['post'])
    def return_purchase(self, request, pk=None):
        """Return a previously received PO. Reverses stock and prices.

        Pass `{"force": true}` to allow reverting even if some stock was already used.
        """
        po = self.get_object()
        if po.status not in (PurchaseOrder.Status.RECEIVED, PurchaseOrder.Status.PARTIAL):
            return Response(
                {'detail': f'Only received purchase orders can be returned (current status: {po.status}).'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        force = bool(request.data.get('force'))
        try:
            result = revert_received_items(po, force=force)
        except ValueError as exc:
            payload = exc.args[0] if exc.args else {'message': str(exc)}
            if isinstance(payload, dict):
                payload['needs_force'] = True
                return Response(payload, status=status.HTTP_409_CONFLICT)
            return Response({'detail': str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        po.refresh_from_db()
        data = self.get_serializer(po).data
        return Response({**result, 'purchase_order': data})


class GoodsReceivedNoteViewSet(viewsets.ModelViewSet):
    queryset = GoodsReceivedNote.objects.select_related('purchase_order', 'received_by').all()
    serializer_class = GoodsReceivedNoteSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['purchase_order']
    search_fields = ['grn_number']
    ordering_fields = ['received_date']
