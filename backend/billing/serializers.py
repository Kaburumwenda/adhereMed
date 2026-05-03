from rest_framework import serializers

from .models import Invoice, Payment


class PaymentSerializer(serializers.ModelSerializer):
    received_by_name = serializers.CharField(source='received_by.full_name', read_only=True)

    class Meta:
        model = Payment
        fields = [
            'id', 'invoice', 'amount', 'method', 'reference',
            'received_by', 'received_by_name', 'notes', 'paid_at',
        ]
        read_only_fields = ['id', 'paid_at']


class InvoiceSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    balance = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)
    payments = PaymentSerializer(many=True, read_only=True)

    class Meta:
        model = Invoice
        fields = [
            'id', 'invoice_number', 'patient', 'patient_name',
            'consultation', 'items',
            'subtotal', 'tax', 'discount', 'total', 'amount_paid',
            'balance', 'status', 'due_date', 'notes',
            'payments', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'invoice_number', 'created_at', 'updated_at']


class InvoiceCreateSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    balance = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)

    class Meta:
        model = Invoice
        fields = [
            'id', 'invoice_number', 'patient', 'patient_name',
            'consultation', 'items',
            'subtotal', 'tax', 'discount', 'total', 'amount_paid',
            'balance', 'status', 'due_date', 'notes',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

    def create(self, validated_data):
        import uuid
        if not validated_data.get('invoice_number'):
            validated_data['invoice_number'] = f'INV-{uuid.uuid4().hex[:8].upper()}'
        items = validated_data.get('items', [])
        subtotal = sum(item.get('total', 0) for item in items)
        validated_data.setdefault('subtotal', subtotal)
        tax = validated_data.get('tax', 0)
        discount = validated_data.get('discount', 0)
        validated_data.setdefault('total', subtotal + tax - discount)
        return super().create(validated_data)
