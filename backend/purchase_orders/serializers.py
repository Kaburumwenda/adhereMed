import uuid
from decimal import Decimal

from django.db import transaction
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


def _to_decimal(v, default='0'):
    try:
        return Decimal(str(v if v not in (None, '') else default))
    except Exception:
        return Decimal(default)


def _normalize_items(items):
    """Return a list of cleaned item dicts and the computed total cost."""
    cleaned = []
    total = Decimal('0')
    for raw in (items or []):
        if not isinstance(raw, dict):
            continue
        stock_id = (
            raw.get('medication_stock_id')
            or raw.get('stock')
            or raw.get('stock_id')
        )
        try:
            qty = int(_to_decimal(raw.get('qty') or raw.get('quantity') or 0))
        except Exception:
            qty = 0
        if not stock_id or qty <= 0:
            continue
        unit_cost = _to_decimal(raw.get('unit_cost') or raw.get('unit_price') or 0)
        unit_selling = _to_decimal(
            raw.get('unit_selling_price') or raw.get('selling_price') or 0
        )
        discount = _to_decimal(raw.get('discount_percent') or raw.get('discount') or 0)
        line_total = (unit_cost * qty).quantize(Decimal('0.01'))
        cleaned.append({
            'medication_stock_id': int(stock_id),
            'name': raw.get('name') or '',
            'qty': qty,
            'unit_cost': float(unit_cost),
            'unit_selling_price': float(unit_selling),
            'discount_percent': float(discount),
            'expiry_date': raw.get('expiry_date') or '',
            'batch_number': raw.get('batch_number') or '',
            'total': float(line_total),
            '_synced': bool(raw.get('_synced', False)),
        })
        total += line_total
    return cleaned, total.quantize(Decimal('0.01'))


def _sync_received_items(purchase_order):
    """Create StockBatch entries for items not yet synced and update price refs."""
    from datetime import date, timedelta

    from inventory.models import MedicationStock, StockBatch

    default_expiry = date.today() + timedelta(days=365)
    updated_items = []
    for it in (purchase_order.items or []):
        if it.get('_synced'):
            updated_items.append(it)
            continue
        try:
            stock = MedicationStock.objects.get(pk=it['medication_stock_id'])
        except (MedicationStock.DoesNotExist, KeyError, TypeError):
            updated_items.append(it)
            continue
        qty = int(it.get('qty') or 0)
        if qty <= 0:
            updated_items.append(it)
            continue
        unit_cost = _to_decimal(it.get('unit_cost'))
        expiry = it.get('expiry_date') or default_expiry.isoformat()
        batch_number = it.get('batch_number') or f"PO-{purchase_order.po_number}-{stock.pk}"
        # Snapshot previous prices BEFORE mutating so we can revert later
        it['_prev_cost_price'] = float(stock.cost_price or 0)
        it['_prev_selling_price'] = float(stock.selling_price or 0)
        it['_prev_discount_percent'] = float(stock.discount_percent or 0)
        StockBatch.objects.create(
            stock=stock,
            batch_number=batch_number,
            quantity_received=qty,
            quantity_remaining=qty,
            cost_price_per_unit=unit_cost,
            expiry_date=expiry,
            supplier=purchase_order.supplier,
        )
        changed = []
        if unit_cost > 0 and stock.cost_price != unit_cost:
            stock.cost_price = unit_cost
            changed.append('cost_price')
        unit_selling = _to_decimal(it.get('unit_selling_price'))
        if unit_selling > 0 and stock.selling_price != unit_selling:
            stock.selling_price = unit_selling
            changed.append('selling_price')
        discount = _to_decimal(it.get('discount_percent'))
        if discount >= 0 and stock.discount_percent != discount:
            stock.discount_percent = discount
            changed.append('discount_percent')
        if changed:
            changed.append('updated_at')
            stock.save(update_fields=changed)
        it['_synced'] = True
        it['batch_number'] = batch_number
        it['expiry_date'] = expiry
        updated_items.append(it)
    purchase_order.items = updated_items
    purchase_order.save(update_fields=['items'])


def revert_received_items(purchase_order, force=False):
    """Reverse the effect of `_sync_received_items`.

    Returns dict {ok, warnings, used_items} where used_items are items whose
    received batches have been partially consumed. When `force` is False and
    any used items are detected, raises ValueError with details so the caller
    can warn the user.
    """
    from inventory.models import MedicationStock, StockBatch

    warnings = []
    used_items = []
    plan = []  # (item, stock, batch_or_None, consumed_qty)

    for it in (purchase_order.items or []):
        if not it.get('_synced') or it.get('_returned'):
            continue
        try:
            stock = MedicationStock.objects.get(pk=it['medication_stock_id'])
        except (MedicationStock.DoesNotExist, KeyError, TypeError):
            warnings.append(f"Stock #{it.get('medication_stock_id')} no longer exists; skipped.")
            continue
        batch = StockBatch.objects.filter(
            stock=stock, batch_number=it.get('batch_number')
        ).first()
        received_qty = int(it.get('qty') or 0)
        consumed = 0
        if batch:
            consumed = max(0, int(batch.quantity_received) - int(batch.quantity_remaining))
            if consumed > 0:
                used_items.append({
                    'name': it.get('name') or stock.medication_name,
                    'received': received_qty,
                    'consumed': consumed,
                    'remaining': int(batch.quantity_remaining),
                })
        plan.append((it, stock, batch, consumed))

    if used_items and not force:
        raise ValueError({'used_items': used_items, 'message': 'Some items have already been consumed.'})

    for it, stock, batch, consumed in plan:
        if batch:
            if consumed > 0:
                # Force path: only remove what's left in this batch
                batch.quantity_remaining = 0
                batch.quantity_received = consumed
                batch.save(update_fields=['quantity_remaining', 'quantity_received'])
                warnings.append(
                    f"{it.get('name') or stock.medication_name}: {consumed} unit(s) already consumed; "
                    f"only the remaining stock from this PO was removed."
                )
            else:
                batch.delete()
        # Restore previous prices when snapshotted
        changed = []
        prev_cost = _to_decimal(it.get('_prev_cost_price'))
        prev_sell = _to_decimal(it.get('_prev_selling_price'))
        prev_disc = _to_decimal(it.get('_prev_discount_percent'))
        if '_prev_cost_price' in it and stock.cost_price != prev_cost:
            stock.cost_price = prev_cost
            changed.append('cost_price')
        if '_prev_selling_price' in it and stock.selling_price != prev_sell:
            stock.selling_price = prev_sell
            changed.append('selling_price')
        if '_prev_discount_percent' in it and stock.discount_percent != prev_disc:
            stock.discount_percent = prev_disc
            changed.append('discount_percent')
        if changed:
            changed.append('updated_at')
            stock.save(update_fields=changed)
        it['_synced'] = False
        it['_returned'] = True

    purchase_order.status = PurchaseOrder.Status.RETURNED
    purchase_order.save(update_fields=['items', 'status'])
    return {'ok': True, 'warnings': warnings, 'used_items': used_items}


class PurchaseOrderSerializer(serializers.ModelSerializer):
    supplier_name = serializers.CharField(source='supplier.name', read_only=True)
    ordered_by_name = serializers.CharField(source='ordered_by.full_name', read_only=True)
    grns = GoodsReceivedNoteSerializer(many=True, read_only=True)
    po_number = serializers.CharField(required=False, allow_blank=True)

    class Meta:
        model = PurchaseOrder
        fields = [
            'id', 'po_number', 'supplier', 'supplier_name',
            'items', 'total_cost', 'status',
            'ordered_by', 'ordered_by_name',
            'order_date', 'expected_delivery', 'notes',
            'grns', 'created_at',
        ]
        read_only_fields = [
            'id', 'order_date', 'created_at', 'total_cost',
            'ordered_by_name', 'supplier_name', 'grns',
        ]

    def _ensure_po_number(self, value):
        return value or f'PO-{uuid.uuid4().hex[:8].upper()}'

    @transaction.atomic
    def create(self, validated_data):
        request = self.context.get('request')
        items = validated_data.pop('items', []) or []
        cleaned, total = _normalize_items(items)
        validated_data['items'] = cleaned
        validated_data['total_cost'] = total
        validated_data['po_number'] = self._ensure_po_number(validated_data.get('po_number'))
        if request and getattr(request, 'user', None) and request.user.is_authenticated:
            validated_data['ordered_by'] = request.user
        po = super().create(validated_data)
        if po.status == PurchaseOrder.Status.RECEIVED:
            _sync_received_items(po)
            po.refresh_from_db()
        return po

    @transaction.atomic
    def update(self, instance, validated_data):
        items = validated_data.pop('items', None)
        if items is not None:
            cleaned, total = _normalize_items(items)
            prev_map = {
                (i.get('medication_stock_id'), i.get('batch_number')): i
                for i in (instance.items or [])
            }
            for it in cleaned:
                key = (it['medication_stock_id'], it.get('batch_number'))
                prev = prev_map.get(key)
                if prev:
                    if prev.get('_synced'):
                        it['_synced'] = True
                    # Preserve previous-price snapshot and returned flag
                    for k in ('_prev_cost_price', '_prev_selling_price', '_prev_discount_percent', '_returned'):
                        if k in prev:
                            it[k] = prev[k]
            validated_data['items'] = cleaned
            validated_data['total_cost'] = total
        if not validated_data.get('po_number') and not instance.po_number:
            validated_data['po_number'] = self._ensure_po_number(None)
        po = super().update(instance, validated_data)
        if po.status == PurchaseOrder.Status.RECEIVED:
            _sync_received_items(po)
            po.refresh_from_db()
        return po
