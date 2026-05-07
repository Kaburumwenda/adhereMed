import uuid
from decimal import Decimal

from django.utils import timezone
from rest_framework import serializers

from .models import Expense, ExpenseCategory


class ExpenseCategorySerializer(serializers.ModelSerializer):
    expense_count = serializers.IntegerField(read_only=True)
    total_spent = serializers.DecimalField(max_digits=14, decimal_places=2, read_only=True)

    class Meta:
        model = ExpenseCategory
        fields = [
            'id', 'name', 'description', 'color', 'is_active', 'created_at',
            'expense_count', 'total_spent',
        ]
        read_only_fields = ['id', 'created_at', 'expense_count', 'total_spent']


class ExpenseSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source='category.name', read_only=True)
    category_color = serializers.CharField(source='category.color', read_only=True)
    supplier_name = serializers.CharField(source='supplier.name', read_only=True)
    submitted_by_name = serializers.CharField(source='submitted_by.full_name', read_only=True)
    approved_by_name = serializers.CharField(source='approved_by.full_name', read_only=True)
    total_amount = serializers.SerializerMethodField()
    reference = serializers.CharField(required=False, allow_blank=True)

    class Meta:
        model = Expense
        fields = [
            'id', 'reference', 'title', 'description',
            'category', 'category_name', 'category_color',
            'amount', 'tax_amount', 'total_amount',
            'expense_date', 'due_date',
            'payment_method', 'payment_reference',
            'vendor', 'supplier', 'supplier_name',
            'status', 'is_recurring', 'recurring_period',
            'receipt', 'notes',
            'submitted_by', 'submitted_by_name',
            'approved_by', 'approved_by_name', 'approved_at', 'paid_at',
            'created_at', 'updated_at',
        ]
        read_only_fields = [
            'id', 'created_at', 'updated_at', 'total_amount',
            'category_name', 'category_color', 'supplier_name',
            'submitted_by_name', 'approved_by_name',
            'approved_by', 'approved_at', 'paid_at',
        ]

    def get_total_amount(self, obj):
        return float(Decimal(str(obj.amount or 0)) + Decimal(str(obj.tax_amount or 0)))

    def _ensure_reference(self, value):
        return value or f'EXP-{uuid.uuid4().hex[:8].upper()}'

    def create(self, validated_data):
        request = self.context.get('request')
        validated_data['reference'] = self._ensure_reference(validated_data.get('reference'))
        if request and getattr(request, 'user', None) and request.user.is_authenticated:
            validated_data.setdefault('submitted_by', request.user)
        return super().create(validated_data)

    def update(self, instance, validated_data):
        if not validated_data.get('reference') and not instance.reference:
            validated_data['reference'] = self._ensure_reference(None)
        # Track timestamps for status changes
        new_status = validated_data.get('status', instance.status)
        request = self.context.get('request')
        user = getattr(request, 'user', None) if request else None
        if new_status != instance.status:
            now = timezone.now()
            if new_status == Expense.Status.APPROVED and not instance.approved_at:
                validated_data['approved_at'] = now
                if user and user.is_authenticated:
                    validated_data['approved_by'] = user
            if new_status == Expense.Status.PAID and not instance.paid_at:
                validated_data['paid_at'] = now
        return super().update(instance, validated_data)
