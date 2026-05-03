from rest_framework import viewsets, filters
from django_filters.rest_framework import DjangoFilterBackend

from .models import PurchaseOrder, GoodsReceivedNote
from .serializers import PurchaseOrderSerializer, GoodsReceivedNoteSerializer


class PurchaseOrderViewSet(viewsets.ModelViewSet):
    queryset = PurchaseOrder.objects.select_related('supplier', 'ordered_by').prefetch_related('grns').all()
    serializer_class = PurchaseOrderSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'supplier']
    search_fields = ['po_number', 'supplier__name']
    ordering_fields = ['created_at', 'order_date', 'total_cost']


class GoodsReceivedNoteViewSet(viewsets.ModelViewSet):
    queryset = GoodsReceivedNote.objects.select_related('purchase_order', 'received_by').all()
    serializer_class = GoodsReceivedNoteSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['purchase_order']
    search_fields = ['grn_number']
    ordering_fields = ['received_date']
