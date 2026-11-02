from decimal import Decimal

from django.db import transaction
from rest_framework import serializers

from .models import DispensingRecord, DispenseReturn
from inventory.models import MedicationStock, StockAdjustment
from inventory.services.stock import InsufficientStock, consume_stock, receipt_stock


class DispenseLineSerializer(serializers.Serializer):
    stock_id = serializers.IntegerField(required=False, allow_null=True)
    medication_name = serializers.CharField(max_length=255)
    qty = serializers.DecimalField(max_digits=12, decimal_places=2, min_value=Decimal('0.01'))
    unit_price = serializers.DecimalField(max_digits=12, decimal_places=2, min_value=Decimal('0'))
    line_total = serializers.DecimalField(max_digits=12, decimal_places=2, required=False)
    batch_number = serializers.CharField(max_length=120, required=False, allow_blank=True)
    notes = serializers.CharField(max_length=255, required=False, allow_blank=True)


class DispensingRecordSerializer(serializers.ModelSerializer):
    dispensed_by_name = serializers.CharField(source='dispensed_by.full_name', read_only=True)
    items = DispenseLineSerializer(many=True, write_only=True, required=False)
    items_dispensed = serializers.JSONField(required=False)
    change_due = serializers.FloatField(read_only=True)
    item_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = DispensingRecord
        fields = [
            'id', 'receipt_number',
            'prescription_exchange_id', 'patient_user_id',
            'patient_name', 'patient_phone',
            'items', 'items_dispensed',
            'subtotal', 'discount', 'total',
            'payment_method', 'paid_amount', 'status',
            'dispensed_by', 'dispensed_by_name',
            'notes', 'dispensed_at',
            'change_due', 'item_count',
        ]
        read_only_fields = ['id', 'receipt_number', 'dispensed_at', 'dispensed_by']

    @transaction.atomic
    def create(self, validated_data):
        request = self.context.get('request')
        items = validated_data.pop('items', None)
        if items is None:
            items = validated_data.get('items_dispensed') or []
        else:
            validated_data['items_dispensed'] = self._serialize_items(items)

        # Auto-compute totals if missing
        subtotal = sum(self._line_total(i) for i in items) if items else Decimal(validated_data.get('subtotal') or 0)
        discount = Decimal(validated_data.get('discount') or 0)
        total = max(Decimal('0'), subtotal - discount)
        validated_data['subtotal'] = subtotal
        validated_data['total'] = total

        if request and request.user and request.user.is_authenticated:
            validated_data['dispensed_by'] = request.user

        record = DispensingRecord.objects.create(**validated_data)

        # Stock deduction (FEFO, sellable batches only). This runs inside the
        # same transaction as the record, so a shortage rolls the whole
        # dispense back instead of silently leaving the shelf short.
        try:
            self._deduct_stock(items, user=validated_data.get('dispensed_by'))
        except InsufficientStock as exc:
            raise serializers.ValidationError({'items': str(exc)}) from exc

        # Controlled-substance auto-log
        try:
            self._log_controlled(items, record, request.user if request else None)
        except Exception:
            pass

        return record

    @staticmethod
    def _line_total(item):
        try:
            return Decimal(str(item.get('qty') or 0)) * Decimal(str(item.get('unit_price') or 0))
        except Exception:
            return Decimal('0')

    def _serialize_items(self, items):
        out = []
        for it in items:
            qty = Decimal(str(it.get('qty') or 0))
            unit_price = Decimal(str(it.get('unit_price') or 0))
            out.append({
                'stock_id': it.get('stock_id'),
                'medication_name': it.get('medication_name'),
                'qty': float(qty),
                'unit_price': float(unit_price),
                'line_total': float(qty * unit_price),
                'batch_number': it.get('batch_number') or '',
                'notes': it.get('notes') or '',
            })
        return out

    @staticmethod
    def _deduct_stock(items, user=None):
        """Drain sellable batches for each dispensed line (FEFO).

        Delegates to :func:`inventory.services.stock.consume_stock` so the
        ledger row, the batch mutation and the "cannot sell expired or
        quarantined stock" rule are shared with POS and sales orders.
        """
        for it in items:
            stock_id = it.get('stock_id')
            if not stock_id:
                continue
            qty_needed = int(Decimal(str(it.get('qty') or 0)))
            if qty_needed <= 0:
                continue
            stock = MedicationStock.objects.filter(id=stock_id).first()
            if stock is None:
                continue
            consume_stock(
                stock, qty_needed,
                reason=StockAdjustment.Reason.DISPENSING,
                notes=f'Dispensed to {it.get("medication_name") or stock.medication_name}',
                user=user,
            )

    @staticmethod
    def _log_controlled(items, record, user):
        """Write a ControlledSubstanceLog entry for any controlled item dispensed."""
        from inventory.models import MedicationStock, ControlledSubstanceLog
        try:
            from medications.models import Medication
        except Exception:
            Medication = None

        for it in items:
            stock_id = it.get('stock_id')
            if not stock_id:
                continue
            try:
                stock = MedicationStock.objects.only('id', 'medication_name').get(pk=stock_id)
            except MedicationStock.DoesNotExist:
                continue

            schedule = ''
            if Medication is not None:
                med = (
                    Medication.objects
                    .filter(generic_name__iexact=stock.medication_name.strip())
                    .exclude(controlled_substance_class='')
                    .only('controlled_substance_class')
                    .first()
                )
                if med:
                    schedule = med.controlled_substance_class
            if not schedule:
                continue  # not a controlled substance

            qty = Decimal(str(it.get('qty') or 0))
            ControlledSubstanceLog.objects.create(
                medication_name=stock.medication_name,
                schedule=schedule,
                action=ControlledSubstanceLog.Action.DISPENSED,
                quantity=qty,
                batch_number=it.get('batch_number') or '',
                patient_name=record.patient_name,
                source_type='dispense',
                source_id=record.id,
                prescription_reference=record.receipt_number or '',
                recorded_by=user if user and user.is_authenticated else None,
            )


class DispenseReturnSerializer(serializers.ModelSerializer):
    processed_by_name = serializers.CharField(source='processed_by.full_name', read_only=True, default=None)
    original_reference = serializers.CharField(source='original.receipt_number', read_only=True)
    original_patient = serializers.CharField(source='original.patient_name', read_only=True)
    item_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = DispenseReturn
        fields = ['id', 'reference', 'original', 'original_reference', 'original_patient',
                  'items_returned', 'refund_amount', 'refund_method',
                  'reason', 'notes', 'restock',
                  'processed_by', 'processed_by_name', 'item_count', 'created_at']
        read_only_fields = ['id', 'reference', 'processed_by', 'created_at']

    def create(self, validated_data):
        request = self.context.get('request')
        if request and request.user and request.user.is_authenticated:
            validated_data['processed_by'] = request.user
        ret = super().create(validated_data)

        # Restock if requested. A returned item is a *new* lot: adding it back
        # into the batch it left (often expired by now) would make the units
        # permanently unsellable.
        if ret.restock:
            try:
                for it in (ret.items_returned or []):
                    stock_id = it.get('stock_id')
                    qty = int(float(it.get('qty') or 0))
                    if not stock_id or qty <= 0:
                        continue
                    stock = MedicationStock.objects.filter(id=stock_id).first()
                    if stock is None:
                        continue
                    receipt_stock(
                        stock, qty,
                        reason=StockAdjustment.Reason.DISPENSE_RETURN,
                        notes=f'Return {ret.reference or ret.pk}',
                        user=ret.processed_by,
                        batch_number=f'RET-{ret.pk}',
                        create_new_lot=True,
                    )
            except Exception:
                pass
        return ret
