from rest_framework import serializers

from .models import (
    Category, Unit, Classification, MedicationStock, StockBatch, StockAdjustment,
    InventoryCount, InventoryCountLine,
    StockTransfer, StockTransferLine,
    ControlledSubstanceLog,
)
from .rbac import can_view_cost


def _scrub_cost(request):
    """True when cost fields must be hidden for the requesting role."""
    return not can_view_cost(request)


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


class ClassificationSerializer(serializers.ModelSerializer):
    stock_count = serializers.IntegerField(read_only=True, default=0)

    class Meta:
        model = Classification
        fields = ['id', 'name', 'description', 'is_active', 'stock_count', 'created_at']
        read_only_fields = ['id', 'stock_count', 'created_at']


class StockBatchSerializer(serializers.ModelSerializer):
    supplier_name = serializers.CharField(source='supplier.name', read_only=True)
    stock_name = serializers.CharField(source='stock.medication_name', read_only=True)
    stock_unit = serializers.CharField(
        source='stock.unit.abbreviation', read_only=True, default='')
    stock_barcode = serializers.CharField(
        source='stock.barcode', read_only=True, default='')
    stock_total_quantity = serializers.IntegerField(
        source='stock.total_quantity', read_only=True, default=0)
    branch_name = serializers.CharField(
        source='branch.name', read_only=True, default=None)
    is_expired = serializers.BooleanField(read_only=True)

    class Meta:
        model = StockBatch
        fields = [
            'id', 'stock', 'stock_name', 'stock_unit', 'stock_barcode',
            'stock_total_quantity', 'batch_number',
            'quantity_received', 'quantity_remaining',
            'cost_price_per_unit', 'expiry_date', 'received_date',
            'supplier', 'supplier_name',
            'branch', 'branch_name', 'is_expired',
        ]
        read_only_fields = ['id', 'received_date']

    def to_representation(self, instance):
        data = super().to_representation(instance)
        # RBAC: cost prices are hidden from till roles (cashier, pharmacy tech…)
        if _scrub_cost(self.context.get('request')):
            data['cost_price_per_unit'] = None
        return data


class MedicationStockSerializer(serializers.ModelSerializer):
    total_quantity = serializers.IntegerField(read_only=True)
    available_quantity = serializers.IntegerField(read_only=True)
    is_low_stock = serializers.BooleanField(read_only=True)
    batches = StockBatchSerializer(many=True, read_only=True)
    category_name = serializers.CharField(source='category.name', read_only=True, default=None)
    unit_name = serializers.CharField(source='unit.name', read_only=True, default=None)
    unit_abbreviation = serializers.CharField(source='unit.abbreviation', read_only=True, default=None)
    branch_name = serializers.CharField(source='branch.name', read_only=True, default=None)
    classification_name = serializers.CharField(source='classification.name', read_only=True, default=None)

    # Write-only fields for creating an initial batch alongside the stock item
    initial_quantity = serializers.IntegerField(write_only=True, required=False, min_value=0)
    batch_number = serializers.CharField(write_only=True, required=False, allow_blank=True)
    expiry_date = serializers.DateField(write_only=True, required=False, allow_null=True, default=None)

    class Meta:
        model = MedicationStock
        fields = [
            'id', 'medication_id', 'medication_name', 'abbreviation',
            'category', 'category_name', 'unit', 'unit_name', 'unit_abbreviation',
            'classification', 'classification_name',
            'brand_name', 'generic_name', 'strength', 'dosage_form',
            'branch', 'branch_name',
            'selling_price', 'cost_price', 'tax_percent', 'discount_percent',
            'reorder_level', 'reorder_quantity',
            'location_in_store', 'barcode', 'prescription_required', 'is_active',
            'items_per_unit',
            'total_quantity', 'available_quantity', 'is_low_stock',
            'batches', 'created_at', 'updated_at',
            'initial_quantity', 'batch_number', 'expiry_date',
        ]
        read_only_fields = ['id', 'medication_id', 'created_at', 'updated_at']

    def validate(self, data):
        name = data.get('medication_name') or (self.instance and self.instance.medication_name)
        branch = data.get('branch') or (self.instance and self.instance.branch)
        if name and branch:
            qs = MedicationStock.objects.filter(
                medication_name__iexact=name, branch=branch,
            )
            if self.instance:
                qs = qs.exclude(pk=self.instance.pk)
            if qs.exists():
                raise serializers.ValidationError(
                    f'"{name}" already exists in {branch.name}. '
                    f'Use a different warehouse or edit the existing item.'
                )
        return data

    def to_representation(self, instance):
        data = super().to_representation(instance)
        # RBAC: cost prices are hidden from till roles (cashier, pharmacy tech…)
        if _scrub_cost(self.context.get('request')):
            data['cost_price'] = None
        return data

    def create(self, validated_data):
        initial_quantity = validated_data.pop('initial_quantity', None)
        batch_number = validated_data.pop('batch_number', None) or ''
        expiry_date = validated_data.pop('expiry_date', None)
        # Ensure a classification is set — fall back to this tenant's
        # "Routine" classification when the client omitted it (the model
        # default already covers raw ORM saves; this guards the serializer
        # path where DRF strips None values before reaching the model).
        if not validated_data.get('classification_id'):
            routine, _ = Classification.objects.get_or_create(name='Routine')
            validated_data['classification'] = routine
        stock = super().create(validated_data)
        if initial_quantity:
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
    batch_number = serializers.CharField(source='batch.batch_number', read_only=True, default=None)
    batch_expiry = serializers.DateField(source='batch.expiry_date', read_only=True, default=None)
    batch_quantity_remaining = serializers.IntegerField(
        source='batch.quantity_remaining', read_only=True, default=None)
    in_stock = serializers.SerializerMethodField()
    variance = serializers.IntegerField(read_only=True)
    line_value = serializers.SerializerMethodField()

    class Meta:
        model = StockTransferLine
        fields = ['id', 'stock', 'stock_name', 'stock_unit',
                  'batch', 'batch_number', 'batch_expiry', 'batch_quantity_remaining',
                  'quantity', 'quantity_received', 'variance', 'notes',
                  'in_stock', 'line_value']

    def get_in_stock(self, obj):
        return obj.stock.total_quantity if obj.stock else 0

    def get_line_value(self, obj):
        if not obj.stock:
            return 0
        return round(float(obj.stock.cost_price or 0) * (obj.quantity or 0), 2)

    def validate_quantity(self, value):
        if value is None or value < 1:
            raise serializers.ValidationError('Quantity must be at least 1.')
        return value


class StockTransferSerializer(serializers.ModelSerializer):
    source_branch_name = serializers.CharField(source='source_branch.name', read_only=True)
    dest_branch_name = serializers.CharField(source='dest_branch.name', read_only=True)
    requested_by_name = serializers.CharField(source='requested_by.full_name', read_only=True, default=None)
    approved_by_name = serializers.CharField(source='approved_by.full_name', read_only=True, default=None)
    received_by_name = serializers.CharField(source='received_by.full_name', read_only=True, default=None)
    assigned_driver_name = serializers.CharField(source='assigned_driver.full_name', read_only=True, default=None)
    assigned_carrier_name = serializers.CharField(source='assigned_carrier.name', read_only=True, default=None)
    assigned_vehicle_label = serializers.SerializerMethodField()
    lines = StockTransferLineSerializer(many=True)
    total_items = serializers.IntegerField(read_only=True)
    total_quantity = serializers.IntegerField(read_only=True)
    total_value = serializers.SerializerMethodField()
    total_variance = serializers.SerializerMethodField()

    class Meta:
        model = StockTransfer
        fields = ['id', 'reference', 'source_branch', 'source_branch_name',
                  'dest_branch', 'dest_branch_name', 'status', 'notes',
                  'priority', 'parcel_count', 'weight_kg',
                  'scheduled_pickup', 'scheduled_delivery',
                  'assigned_driver', 'assigned_driver_name',
                  'assigned_carrier', 'assigned_carrier_name',
                  'assigned_vehicle', 'assigned_vehicle_label',
                  'assigned_vehicle_note',
                  'requested_by', 'requested_by_name',
                  'approved_by', 'approved_by_name',
                  'received_by', 'received_by_name',
                  'requested_at', 'shipped_at', 'received_at',
                  'approved_signature', 'received_signature',
                  'lines', 'total_items', 'total_quantity',
                  'total_value', 'total_variance']
        read_only_fields = ['id', 'reference', 'requested_by', 'approved_by',
                            'received_by', 'requested_at', 'shipped_at', 'received_at',
                            'approved_signature', 'received_signature']

    def get_total_value(self, obj):
        return round(sum(
            float(l.stock.cost_price or 0) * l.quantity
            for l in obj.lines.select_related('stock').all()
        ), 2)

    def get_total_variance(self, obj):
        return sum(l.variance for l in obj.lines.all())

    def get_assigned_vehicle_label(self, obj):
        return str(obj.assigned_vehicle) if obj.assigned_vehicle_id else None

    def validate(self, data):
        src = data.get('source_branch') or getattr(self.instance, 'source_branch', None)
        dst = data.get('dest_branch') or getattr(self.instance, 'dest_branch', None)
        if src and dst and src == dst:
            raise serializers.ValidationError({'dest_branch': 'Destination must differ from source.'})
        lines = data.get('lines', [])
        if lines:
            seen = set()  # (stock_pk, batch_pk_or_None) — same stock with a
            # different batch is allowed so a transfer can drain multiple
            # batches of one item in a single shipment.
            for line in lines:
                stock = line.get('stock')
                batch = line.get('batch')
                stock_pk = stock.pk if stock else None
                batch_pk = batch.pk if batch else None
                key = (stock_pk, batch_pk)
                if stock_pk and key in seen:
                    raise serializers.ValidationError(
                        {'lines': f'Duplicate item "{stock.medication_name}" with the same batch — '
                                  f'merge the quantities into one line.'})
                seen.add(key)
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
        if instance.status != StockTransfer.Status.DRAFT:
            raise serializers.ValidationError({
                'detail': f'Only draft transfers can be edited. {instance.reference} '
                          f'is currently "{instance.get_status_display()}".'
            })
        lines = validated_data.pop('lines', None)
        for k, v in validated_data.items():
            setattr(instance, k, v)
        instance.save()
        if lines is not None:
            # The client sends the complete line set, so replace wholesale.
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
