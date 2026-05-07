from rest_framework import serializers

from .models import (
    Category, Unit, MedicationStock, StockBatch, StockAdjustment,
    InventoryCount, InventoryCountLine,
    StockTransfer, StockTransferLine,
    ControlledSubstanceLog,
)


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
            'id', 'medication_id', 'medication_name', 'abbreviation',
            'category', 'category_name', 'unit', 'unit_name', 'unit_abbreviation',
            'selling_price', 'cost_price', 'discount_percent',
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


# ─────────────────────────────────────────────────────────────────────────
class InventoryCountLineSerializer(serializers.ModelSerializer):
    stock_name = serializers.CharField(source='stock.medication_name', read_only=True)
    stock_unit = serializers.CharField(source='stock.unit.abbreviation', read_only=True, default='')
    cost_price = serializers.DecimalField(source='stock.cost_price', read_only=True, max_digits=10, decimal_places=2)
    variance = serializers.IntegerField(read_only=True)
    variance_value = serializers.DecimalField(read_only=True, max_digits=12, decimal_places=2)

    class Meta:
        model = InventoryCountLine
        fields = ['id', 'stock', 'stock_name', 'stock_unit', 'cost_price',
                  'expected_quantity', 'counted_quantity', 'notes',
                  'variance', 'variance_value']


class InventoryCountSerializer(serializers.ModelSerializer):
    branch_name = serializers.CharField(source='branch.name', read_only=True, default=None)
    category_name = serializers.CharField(source='category.name', read_only=True, default=None)
    created_by_name = serializers.CharField(source='created_by.full_name', read_only=True, default=None)
    completed_by_name = serializers.CharField(source='completed_by.full_name', read_only=True, default=None)
    lines = InventoryCountLineSerializer(many=True, read_only=True)
    total_lines = serializers.SerializerMethodField()
    counted_lines = serializers.SerializerMethodField()
    total_variance = serializers.IntegerField(read_only=True)
    total_variance_value = serializers.DecimalField(read_only=True, max_digits=14, decimal_places=2)

    class Meta:
        model = InventoryCount
        fields = ['id', 'reference', 'name', 'branch', 'branch_name',
                  'category', 'category_name', 'status', 'notes',
                  'created_by', 'created_by_name', 'completed_by', 'completed_by_name',
                  'created_at', 'completed_at', 'lines',
                  'total_lines', 'counted_lines',
                  'total_variance', 'total_variance_value']
        read_only_fields = ['id', 'reference', 'created_by', 'completed_by',
                            'created_at', 'completed_at']

    def get_total_lines(self, obj):
        return obj.lines.count()

    def get_counted_lines(self, obj):
        return obj.lines.exclude(counted_quantity__isnull=True).count()


# ─────────────────────────────────────────────────────────────────────────
class StockTransferLineSerializer(serializers.ModelSerializer):
    stock_name = serializers.CharField(source='stock.medication_name', read_only=True)
    stock_unit = serializers.CharField(source='stock.unit.abbreviation', read_only=True, default='')
    in_stock = serializers.SerializerMethodField()

    class Meta:
        model = StockTransferLine
        fields = ['id', 'stock', 'stock_name', 'stock_unit',
                  'quantity', 'quantity_received', 'notes', 'in_stock']

    def get_in_stock(self, obj):
        return obj.stock.total_quantity if obj.stock else 0


class StockTransferSerializer(serializers.ModelSerializer):
    source_branch_name = serializers.CharField(source='source_branch.name', read_only=True)
    dest_branch_name = serializers.CharField(source='dest_branch.name', read_only=True)
    requested_by_name = serializers.CharField(source='requested_by.full_name', read_only=True, default=None)
    approved_by_name = serializers.CharField(source='approved_by.full_name', read_only=True, default=None)
    received_by_name = serializers.CharField(source='received_by.full_name', read_only=True, default=None)
    lines = StockTransferLineSerializer(many=True)
    total_items = serializers.IntegerField(read_only=True)
    total_quantity = serializers.IntegerField(read_only=True)

    class Meta:
        model = StockTransfer
        fields = ['id', 'reference', 'source_branch', 'source_branch_name',
                  'dest_branch', 'dest_branch_name', 'status', 'notes',
                  'requested_by', 'requested_by_name',
                  'approved_by', 'approved_by_name',
                  'received_by', 'received_by_name',
                  'requested_at', 'shipped_at', 'received_at',
                  'lines', 'total_items', 'total_quantity']
        read_only_fields = ['id', 'reference', 'requested_by', 'approved_by',
                            'received_by', 'requested_at', 'shipped_at', 'received_at']

    def validate(self, data):
        src = data.get('source_branch') or getattr(self.instance, 'source_branch', None)
        dst = data.get('dest_branch') or getattr(self.instance, 'dest_branch', None)
        if src and dst and src == dst:
            raise serializers.ValidationError({'dest_branch': 'Destination must differ from source.'})
        return data

    def create(self, validated_data):
        lines = validated_data.pop('lines', [])
        request = self.context.get('request')
        if request and request.user and request.user.is_authenticated:
            validated_data['requested_by'] = request.user
        transfer = StockTransfer.objects.create(**validated_data)
        for line in lines:
            StockTransferLine.objects.create(transfer=transfer, **line)
        return transfer

    def update(self, instance, validated_data):
        lines = validated_data.pop('lines', None)
        for k, v in validated_data.items():
            setattr(instance, k, v)
        instance.save()
        if lines is not None and instance.status == StockTransfer.Status.DRAFT:
            instance.lines.all().delete()
            for line in lines:
                StockTransferLine.objects.create(transfer=instance, **line)
        return instance


# ─────────────────────────────────────────────────────────────────────────
class ControlledSubstanceLogSerializer(serializers.ModelSerializer):
    recorded_by_name = serializers.CharField(source='recorded_by.full_name', read_only=True, default=None)

    class Meta:
        model = ControlledSubstanceLog
        fields = ['id', 'medication_name', 'schedule', 'action', 'quantity', 'balance_after',
                  'batch_number', 'patient_name', 'patient_id_number',
                  'prescriber_name', 'prescription_reference',
                  'source_type', 'source_id', 'notes',
                  'recorded_by', 'recorded_by_name', 'created_at']
        read_only_fields = ['id', 'recorded_by', 'created_at']
