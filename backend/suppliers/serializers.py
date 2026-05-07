from rest_framework import serializers

from .models import Supplier, SupplierItem


class SupplierItemSerializer(serializers.ModelSerializer):
    stock_name = serializers.CharField(source='stock.medication_name', read_only=True)
    stock_quantity = serializers.IntegerField(source='stock.total_quantity', read_only=True)

    class Meta:
        model = SupplierItem
        fields = [
            'id', 'stock', 'stock_name', 'stock_quantity',
            'item_name', 'unit_cost', 'unit_price', 'quantity', 'notes',
        ]
        read_only_fields = ['id']


class SupplierSerializer(serializers.ModelSerializer):
    items = SupplierItemSerializer(many=True, required=False)

    class Meta:
        model = Supplier
        fields = [
            'id', 'name', 'contact_person', 'phone', 'email',
            'address', 'payment_terms', 'is_active', 'created_at',
            'items',
        ]
        read_only_fields = ['id', 'created_at']

    def create(self, validated_data):
        items = validated_data.pop('items', [])
        supplier = Supplier.objects.create(**validated_data)
        for item in items:
            SupplierItem.objects.create(supplier=supplier, **item)
        return supplier

    def update(self, instance, validated_data):
        items = validated_data.pop('items', None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        if items is not None:
            instance.items.all().delete()
            for item in items:
                SupplierItem.objects.create(supplier=instance, **item)
        return instance
