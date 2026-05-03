from rest_framework import serializers

from .models import Category, Unit, MedicationStock, StockBatch, StockAdjustment


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ['id', 'name', 'description', 'created_at']
        read_only_fields = ['id', 'created_at']


class UnitSerializer(serializers.ModelSerializer):
    class Meta:
        model = Unit
        fields = ['id', 'name', 'abbreviation', 'created_at']
        read_only_fields = ['id', 'created_at']


class StockBatchSerializer(serializers.ModelSerializer):
    supplier_name = serializers.CharField(source='supplier.name', read_only=True)
    stock_name = serializers.CharField(source='stock.medication_name', read_only=True)
    is_expired = serializers.BooleanField(read_only=True)

    class Meta:
        model = StockBatch
        fields = [
            'id', 'stock', 'stock_name', 'batch_number',
            'quantity_received', 'quantity_remaining',
            'cost_price_per_unit', 'expiry_date', 'received_date',
            'supplier', 'supplier_name', 'is_expired',
        ]
        read_only_fields = ['id', 'received_date']


class MedicationStockSerializer(serializers.ModelSerializer):
    total_quantity = serializers.IntegerField(read_only=True)
    is_low_stock = serializers.BooleanField(read_only=True)
    batches = StockBatchSerializer(many=True, read_only=True)
    category_name = serializers.CharField(source='category.name', read_only=True, default=None)
    unit_name = serializers.CharField(source='unit.name', read_only=True, default=None)
    unit_abbreviation = serializers.CharField(source='unit.abbreviation', read_only=True, default=None)

    # Write-only fields for creating an initial batch alongside the stock item
    initial_quantity = serializers.IntegerField(write_only=True, required=False, min_value=0)
    batch_number = serializers.CharField(write_only=True, required=False, allow_blank=True)
    expiry_date = serializers.DateField(write_only=True, required=False)

    class Meta:
        model = MedicationStock
        fields = [
            'id', 'medication_id', 'medication_name',
            'category', 'category_name', 'unit', 'unit_name', 'unit_abbreviation',
            'selling_price', 'cost_price',
            'reorder_level', 'reorder_quantity',
            'location_in_store', 'barcode', 'prescription_required', 'is_active',
            'total_quantity', 'is_low_stock',
            'batches', 'created_at', 'updated_at',
            'initial_quantity', 'batch_number', 'expiry_date',
        ]
        read_only_fields = ['id', 'medication_id', 'created_at', 'updated_at']

    def create(self, validated_data):
        initial_quantity = validated_data.pop('initial_quantity', None)
        batch_number = validated_data.pop('batch_number', None) or ''
        expiry_date = validated_data.pop('expiry_date', None)
        stock = super().create(validated_data)
        if initial_quantity and expiry_date:
            StockBatch.objects.create(
                stock=stock,
                batch_number=batch_number or f'INIT-{stock.pk:05d}',
                quantity_received=initial_quantity,
                quantity_remaining=initial_quantity,
                cost_price_per_unit=stock.cost_price,
                expiry_date=expiry_date,
            )
        return stock


class StockAdjustmentSerializer(serializers.ModelSerializer):
    stock_name = serializers.CharField(source='stock.medication_name', read_only=True)
    adjusted_by_name = serializers.CharField(source='adjusted_by.full_name', read_only=True, default=None)

    class Meta:
        model = StockAdjustment
        fields = [
            'id', 'stock', 'stock_name', 'batch',
            'quantity_change', 'reason', 'notes',
            'adjusted_by', 'adjusted_by_name', 'created_at',
        ]
        read_only_fields = ['id', 'adjusted_by', 'created_at']

    def create(self, validated_data):
        validated_data['adjusted_by'] = self.context['request'].user
        adjustment = super().create(validated_data)
        # Apply the quantity change to the batch if specified
        batch = adjustment.batch
        if batch:
            batch.quantity_remaining = max(0, batch.quantity_remaining + adjustment.quantity_change)
            batch.save(update_fields=['quantity_remaining'])
        return adjustment
