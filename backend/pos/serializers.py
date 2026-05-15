from decimal import Decimal
from django.db import transaction
from django.utils import timezone
from rest_framework import serializers

from .models import POSTransaction, TransactionItem, Customer, ParkedSale, CashierShift, LoyaltyTransaction, CreditSale, CreditPayment
from inventory.models import MedicationStock, StockBatch


class CustomerSerializer(serializers.ModelSerializer):
    class Meta:
        model = Customer
        fields = [
            'id', 'name', 'phone', 'email', 'address', 'notes',
            'total_purchases', 'visit_count',
            'loyalty_points', 'loyalty_tier', 'loyalty_joined_at',
            'is_active',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'total_purchases', 'visit_count',
                            'loyalty_points', 'loyalty_tier', 'loyalty_joined_at',
                            'created_at', 'updated_at']


class TransactionItemSerializer(serializers.ModelSerializer):
    stock_name = serializers.CharField(source='stock.medication_name', read_only=True)
    category_name = serializers.CharField(source='stock.category.name', read_only=True, default='Uncategorized')

    class Meta:
        model = TransactionItem
        fields = [
            'id', 'transaction', 'stock', 'stock_name',
            'batch', 'medication_name', 'category_name',
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
            'status',
            'items', 'created_at',
        ]
        read_only_fields = ['id', 'created_at']


class CreditSaleSerializer(serializers.ModelSerializer):
    transaction_number = serializers.CharField(source='transaction.transaction_number', read_only=True)
    created_at = serializers.DateTimeField(read_only=True)
    cashier_name = serializers.CharField(source='transaction.cashier.full_name', read_only=True, default='')

    class Meta:
        model = CreditSale
        fields = [
            'id', 'transaction', 'transaction_number',
            'customer_name', 'customer_phone',
            'due_date', 'notes',
            'total_amount', 'partial_paid_amount', 'balance_amount',
            'partial_payment_method', 'status',
            'cashier_name',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'transaction', 'transaction_number', 'created_at', 'updated_at', 'cashier_name']


class CreditPaymentSerializer(serializers.ModelSerializer):
    recorded_by_name = serializers.CharField(source='recorded_by.full_name', read_only=True, default='')

    class Meta:
        model = CreditPayment
        fields = [
            'id', 'credit_sale', 'amount', 'payment_method',
            'reference', 'notes', 'recorded_by', 'recorded_by_name', 'paid_at',
        ]
        read_only_fields = ['id', 'credit_sale', 'recorded_by', 'recorded_by_name', 'paid_at']


class RecordCreditPaymentSerializer(serializers.Serializer):
    amount = serializers.DecimalField(max_digits=12, decimal_places=2, min_value=Decimal('0.01'))
    payment_method = serializers.ChoiceField(choices=CreditPayment.PaymentMethod.choices)
    reference = serializers.CharField(max_length=100, required=False, default='', allow_blank=True)
    notes = serializers.CharField(max_length=500, required=False, default='', allow_blank=True)


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
    credit_due_date = serializers.DateField(required=False, allow_null=True)
    credit_notes = serializers.CharField(required=False, allow_blank=True, max_length=500, default='')
    partial_paid_amount = serializers.DecimalField(max_digits=12, decimal_places=2, required=False, default=0)
    partial_payment_method = serializers.ChoiceField(
        choices=CreditSale.PartialPaymentMethod.choices,
        required=False,
        default=CreditSale.PartialPaymentMethod.NONE,
    )
    items = CheckoutItemSerializer(many=True)

    def validate(self, attrs):
        payment_method = attrs.get('payment_method')
        if payment_method == POSTransaction.PaymentMethod.CREDIT:
            customer_name = (attrs.get('customer_name') or '').strip()
            if not customer_name:
                raise serializers.ValidationError({'customer_name': 'Customer name is required for credit sales.'})
            if not attrs.get('credit_due_date'):
                raise serializers.ValidationError({'credit_due_date': 'Due date is required for credit sales.'})

            total_partial = attrs.get('partial_paid_amount') or 0
            if total_partial < 0:
                raise serializers.ValidationError({'partial_paid_amount': 'Partial payment cannot be negative.'})
            if total_partial > 0 and attrs.get('partial_payment_method') == CreditSale.PartialPaymentMethod.NONE:
                raise serializers.ValidationError({'partial_payment_method': 'Select partial payment method when partial payment is entered.'})
        return attrs

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
        total_tax = Decimal('0')
        transaction_items = []

        for item_data in items_data:
            stock = MedicationStock.objects.get(id=item_data['stock_id'])
            qty_needed = item_data['quantity']
            unit_price = stock.selling_price
            line_total = unit_price * qty_needed
            subtotal += line_total

            # Compute tax per item based on stock.tax_percent (tax-inclusive price)
            tax_pct = Decimal(str(stock.tax_percent or 0))
            if tax_pct > 0:
                line_tax = line_total * tax_pct / (100 + tax_pct)
            else:
                line_tax = Decimal('0')
            total_tax += line_tax

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

        # Round tax to 2 decimal places
        total_tax = total_tax.quantize(Decimal('0.01'))

        branch_id = validated_data.get('branch_id')

        pos_txn = POSTransaction.objects.create(
            transaction_number=transaction_number,
            customer_name=validated_data.get('customer_name', ''),
            customer_phone=validated_data.get('customer_phone', ''),
            subtotal=subtotal,
            tax=total_tax,
            discount=discount,
            total=total,
            payment_method=validated_data['payment_method'],
            payment_reference=validated_data.get('payment_reference', ''),
            cashier=cashier,
            branch_id=branch_id,
        )

        for ti in transaction_items:
            TransactionItem.objects.create(transaction=pos_txn, **ti)

        if validated_data['payment_method'] == POSTransaction.PaymentMethod.CREDIT:
            partial_paid = validated_data.get('partial_paid_amount', 0) or 0
            balance = max(Decimal('0'), total - partial_paid)
            due_date = validated_data.get('credit_due_date')
            status = CreditSale.Status.OPEN
            if balance == 0:
                status = CreditSale.Status.SETTLED
            elif partial_paid > 0:
                status = CreditSale.Status.PARTIAL
            if due_date and due_date < timezone.now().date() and balance > 0:
                status = CreditSale.Status.OVERDUE

            CreditSale.objects.create(
                transaction=pos_txn,
                customer_name=validated_data.get('customer_name', ''),
                customer_phone=validated_data.get('customer_phone', ''),
                due_date=due_date,
                notes=validated_data.get('credit_notes', ''),
                total_amount=total,
                partial_paid_amount=partial_paid,
                balance_amount=balance,
                partial_payment_method=validated_data.get('partial_payment_method', CreditSale.PartialPaymentMethod.NONE),
                status=status,
            )

        return pos_txn


class ParkedSaleSerializer(serializers.ModelSerializer):
    cashier_name = serializers.CharField(source='cashier.full_name', read_only=True)
    item_count = serializers.IntegerField(read_only=True)
    total = serializers.FloatField(read_only=True)

    class Meta:
        model = ParkedSale
        fields = [
            'id', 'park_number', 'customer_name', 'customer_phone',
            'payment_method', 'discount', 'items', 'notes',
            'cashier', 'cashier_name', 'branch',
            'item_count', 'total',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'park_number', 'cashier', 'cashier_name', 'created_at', 'updated_at']

    def create(self, validated_data):
        import uuid
        request = self.context.get('request')
        if request and request.user and request.user.is_authenticated:
            validated_data['cashier'] = request.user
        validated_data['park_number'] = f'PARK-{uuid.uuid4().hex[:8].upper()}'
        return super().create(validated_data)


class CashierShiftSerializer(serializers.ModelSerializer):
    cashier_name = serializers.SerializerMethodField(read_only=True)
    branch_name = serializers.CharField(source='branch.name', read_only=True, default=None)

    class Meta:
        model = CashierShift
        fields = '__all__'
        read_only_fields = ('reference', 'cashier', 'expected_cash', 'cash_variance',
                            'closed_at', 'z_report', 'opened_at')

    def get_cashier_name(self, obj):
        u = obj.cashier
        if not u:
            return ''
        return f'{u.first_name} {u.last_name}'.strip() or u.email

    def create(self, validated_data):
        request = self.context.get('request')
        validated_data['cashier'] = request.user
        return super().create(validated_data)


class LoyaltyTransactionSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source='customer.name', read_only=True)
    created_by_name = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = LoyaltyTransaction
        fields = '__all__'
        read_only_fields = ('balance_after', 'created_by', 'created_at')

    def get_created_by_name(self, obj):
        u = obj.created_by
        if not u:
            return ''
        return f'{u.first_name} {u.last_name}'.strip() or u.email
