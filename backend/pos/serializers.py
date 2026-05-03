from django.db import transaction
from rest_framework import serializers

from .models import POSTransaction, TransactionItem, Customer
from inventory.models import MedicationStock, StockBatch


class CustomerSerializer(serializers.ModelSerializer):
    class Meta:
        model = Customer
        fields = [
            'id', 'name', 'phone', 'email', 'address', 'notes',
            'total_purchases', 'visit_count', 'is_active',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'total_purchases', 'visit_count', 'created_at', 'updated_at']


class TransactionItemSerializer(serializers.ModelSerializer):
    stock_name = serializers.CharField(source='stock.medication_name', read_only=True)

    class Meta:
        model = TransactionItem
        fields = [
            'id', 'transaction', 'stock', 'stock_name',
            'batch', 'medication_name',
            'quantity', 'unit_price', 'total_price',
        ]
        read_only_fields = ['id']


class POSTransactionSerializer(serializers.ModelSerializer):
    items = TransactionItemSerializer(many=True, read_only=True)
    cashier_name = serializers.CharField(source='cashier.full_name', read_only=True)
    branch_name = serializers.CharField(source='branch.name', read_only=True, default=None)

    class Meta:
        model = POSTransaction
        fields = [
            'id', 'transaction_number', 'customer_name', 'customer_phone',
            'subtotal', 'tax', 'discount', 'total',
            'payment_method', 'payment_reference',
            'cashier', 'cashier_name',
            'branch', 'branch_name',
            'items', 'created_at',
        ]
        read_only_fields = ['id', 'created_at']


class CheckoutItemSerializer(serializers.Serializer):
    stock_id = serializers.IntegerField()
    quantity = serializers.IntegerField(min_value=1)


class POSCheckoutSerializer(serializers.Serializer):
    customer_name = serializers.CharField(max_length=255, required=False, default='', allow_blank=True)
    customer_phone = serializers.CharField(max_length=20, required=False, default='', allow_blank=True)
    payment_method = serializers.ChoiceField(choices=POSTransaction.PaymentMethod.choices)
    payment_reference = serializers.CharField(max_length=100, required=False, default='', allow_blank=True)
    discount = serializers.DecimalField(max_digits=12, decimal_places=2, required=False, default=0)
    branch_id = serializers.IntegerField(required=False, allow_null=True)
    items = CheckoutItemSerializer(many=True)

    def validate_items(self, value):
        if not value:
            raise serializers.ValidationError('At least one item is required.')
        for item in value:
            try:
                stock = MedicationStock.objects.get(id=item['stock_id'], is_active=True)
            except MedicationStock.DoesNotExist:
                raise serializers.ValidationError(
                    f"Medication stock with id {item['stock_id']} not found or inactive."
                )
            if stock.total_quantity < item['quantity']:
                raise serializers.ValidationError(
                    f"Insufficient stock for {stock.medication_name}. "
                    f"Available: {stock.total_quantity}, Requested: {item['quantity']}."
                )
        return value

    @transaction.atomic
    def create(self, validated_data):
        import uuid
        items_data = validated_data.pop('items')
        cashier = self.context['request'].user

        transaction_number = f'TXN-{uuid.uuid4().hex[:8].upper()}'

        subtotal = 0
        transaction_items = []

        for item_data in items_data:
            stock = MedicationStock.objects.get(id=item_data['stock_id'])
            qty_needed = item_data['quantity']
            unit_price = stock.selling_price
            line_total = unit_price * qty_needed
            subtotal += line_total

            # FEFO: deduct from earliest expiring batches first
            batches = StockBatch.objects.filter(
                stock=stock, quantity_remaining__gt=0,
            ).order_by('expiry_date')

            remaining = qty_needed
            fefo_batch = None
            for batch in batches:
                if remaining <= 0:
                    break
                deduct = min(batch.quantity_remaining, remaining)
                batch.quantity_remaining -= deduct
                batch.save(update_fields=['quantity_remaining'])
                remaining -= deduct
                if fefo_batch is None:
                    fefo_batch = batch

            transaction_items.append({
                'stock': stock,
                'batch': fefo_batch,
                'medication_name': stock.medication_name,
                'quantity': qty_needed,
                'unit_price': unit_price,
                'total_price': line_total,
            })

        discount = validated_data.get('discount', 0)
        total = subtotal - discount
        branch_id = validated_data.get('branch_id')

        pos_txn = POSTransaction.objects.create(
            transaction_number=transaction_number,
            customer_name=validated_data.get('customer_name', ''),
            customer_phone=validated_data.get('customer_phone', ''),
            subtotal=subtotal,
            tax=0,
            discount=discount,
            total=total,
            payment_method=validated_data['payment_method'],
            payment_reference=validated_data.get('payment_reference', ''),
            cashier=cashier,
            branch_id=branch_id,
        )

        for ti in transaction_items:
            TransactionItem.objects.create(transaction=pos_txn, **ti)

        return pos_txn
