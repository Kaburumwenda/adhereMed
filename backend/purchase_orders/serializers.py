from rest_framework import serializers

from .models import PurchaseOrder, GoodsReceivedNote


class GoodsReceivedNoteSerializer(serializers.ModelSerializer):
    received_by_name = serializers.CharField(source='received_by.full_name', read_only=True)

    class Meta:
        model = GoodsReceivedNote
        fields = [
            'id', 'purchase_order', 'grn_number',
            'received_by', 'received_by_name',
            'items_received', 'received_date', 'notes',
        ]
        read_only_fields = ['id', 'received_date']


class PurchaseOrderSerializer(serializers.ModelSerializer):
    supplier_name = serializers.CharField(source='supplier.name', read_only=True)
    ordered_by_name = serializers.CharField(source='ordered_by.full_name', read_only=True)
    grns = GoodsReceivedNoteSerializer(many=True, read_only=True)

    class Meta:
        model = PurchaseOrder
        fields = [
            'id', 'po_number', 'supplier', 'supplier_name',
            'items', 'total_cost', 'status',
            'ordered_by', 'ordered_by_name',
            'order_date', 'expected_delivery', 'notes',
            'grns', 'created_at',
        ]
        read_only_fields = ['id', 'order_date', 'created_at']
