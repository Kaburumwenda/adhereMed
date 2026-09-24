import uuid
from decimal import Decimal

from django.db import transaction
from rest_framework import serializers

from .models import SalesOrder


def _to_decimal(v, default='0'):
    try:
        return Decimal(str(v if v not in (None, '') else default))
    except Exception:
        return Decimal(default)


def _normalize_items(items):
    """Return (cleaned items, items subtotal). Line total = qty * unit price − line discount."""
    cleaned = []
    subtotal = Decimal('0')
    for raw in (items or []):
        if not isinstance(raw, dict):
            continue
        stock_id = raw.get('stock_id') or raw.get('medication_stock_id')
        try:
            qty = int(_to_decimal(raw.get('qty') or 0))
        except Exception:
            qty = 0
        if qty <= 0:
            continue
        unit_price = _to_decimal(raw.get('unit_price') or raw.get('selling_price') or 0)
        discount_pct = _to_decimal(raw.get('discount_percent') or 0)
        line_total = (unit_price * qty) * (1 - discount_pct / 100)
        line_total = line_total.quantize(Decimal('0.01'))
        item = {
            'stock_id': int(stock_id) if stock_id else None,
            'name': raw.get('name') or '',
            'qty': qty,
            'unit_price': float(unit_price),
            'discount_percent': float(discount_pct),
            'total': float(line_total),
        }
        # Preserve the delivery / commitment bookkeeping flags
        for flag in ('_committed', '_delivered', '_delivered_short'):
            if raw.get(flag) is not None:
                item[flag] = raw.get(flag)
        cleaned.append(item)
        subtotal += line_total
    return cleaned, subtotal.quantize(Decimal('0.01'))


# Payment statuses that trigger a stock commitment (soft reservation)
COMMITTED_PAYMENT_STATUSES = (SalesOrder.PaymentStatus.PAID, SalesOrder.PaymentStatus.PARTIAL)


def _sync_stock_commitment(so):
    """Mirror the SO payment state onto inventory `committed_qty`.

    Paid / partially paid orders reserve their item quantities as committed
    stock. Unpaid, cancelled or already-delivered lines release the
    reservation. The per-item `_committed` flag keeps this idempotent.
    """
    from inventory.models import MedicationStock

    # 1) Release everything this SO currently holds
    for it in (so.items or []):
        if it.get('_committed') and it.get('stock_id'):
            release = int(it.get('_committed_qty') or it.get('qty') or 0)
            try:
                stock = MedicationStock.objects.get(pk=it['stock_id'])
                stock.committed_qty = max(0, (stock.committed_qty or 0) - release)
                stock.save(update_fields=['committed_qty', 'updated_at'])
            except MedicationStock.DoesNotExist:
                pass
            it['_committed'] = False
            it.pop('_committed_qty', None)

    # 2) Re-commit if the order is (partially) paid and still open
    should_commit = (so.payment_status in COMMITTED_PAYMENT_STATUSES
                    and so.status != SalesOrder.Status.CANCELLED)
    if should_commit:
        for it in (so.items or []):
            if it.get('stock_id') and not it.get('_delivered'):
                try:
                    stock = MedicationStock.objects.get(pk=it['stock_id'])
                    it['_committed_qty'] = int(it.get('qty') or 0)
                    stock.committed_qty = (stock.committed_qty or 0) + it['_committed_qty']
                    stock.save(update_fields=['committed_qty', 'updated_at'])
                    it['_committed'] = True
                except MedicationStock.DoesNotExist:
                    pass

    so.save(update_fields=['items', 'updated_at'])


def _fulfill_delivered_items(so, user=None):
    """Deduct delivered SO items from physical stock (FEFO — earliest expiry first).

    Runs once per line: the `_delivered` flag makes it idempotent. Any
    commitment held for a delivered line is released at the same time.
    The deduction is recorded as a StockAdjustment (reason 'sales_order')
    so it appears in the movement ledger, stock-movements report and
    adjustments page.
    """
    from inventory.models import MedicationStock, StockBatch, StockAdjustment

    changed = False
    for it in (so.items or []):
        if it.get('_delivered') or not it.get('stock_id'):
            continue
        qty = int(it.get('qty') or 0)
        if qty <= 0:
            it['_delivered'] = True
            changed = True
            continue
        try:
            stock = MedicationStock.objects.get(pk=it['stock_id'])
        except MedicationStock.DoesNotExist:
            it['_delivered'] = True
            changed = True
            continue

        was_committed = bool(it.get('_committed'))
        if was_committed:
            release = int(it.get('_committed_qty') or qty)
            stock.committed_qty = max(0, (stock.committed_qty or 0) - release)

        remaining = qty
        batches = StockBatch.objects.filter(
            stock=stock, quantity_remaining__gt=0,
        ).order_by('expiry_date')
        for batch in batches:
            if remaining <= 0:
                break
            deduct = min(batch.quantity_remaining, remaining)
            batch.quantity_remaining -= deduct
            batch.save(update_fields=['quantity_remaining'])
            remaining -= deduct

        if was_committed:
            stock.save(update_fields=['committed_qty', 'updated_at'])
        it['_committed'] = False
        it['_delivered'] = True

        # Ledger record for the movement report / item insights
        deducted = qty - max(0, remaining)
        if deducted > 0:
            StockAdjustment.objects.create(
                stock=stock,
                quantity_change=-deducted,
                reason=StockAdjustment.Reason.SALES_ORDER,
                notes=f'Sales order {so.so_number} fulfilled (delivered)',
                adjusted_by=user if (user and getattr(user, 'is_authenticated', False)) else None,
            )
        if remaining > 0:
            it['_delivered_short'] = remaining
        changed = True

    if changed:
        so.save(update_fields=['items', 'updated_at'])


def _sync_delivery(so):
    """Mirror the SO lifecycle onto the Deliveries module.

    Confirming an order auto-creates a delivery record (status 'To Be
    Packed') with the order's delivery address, coordinates and customer
    details. Cancelling the order cancels the delivery unless it has
    already been delivered or failed.
    """
    from pharmacy_profile.models import Delivery

    try:
        delivery = so.delivery
    except Delivery.DoesNotExist:
        delivery = None

    if so.status == SalesOrder.Status.CONFIRMED and delivery is None:
        Delivery.objects.create(
            sales_order=so,
            delivery_address=so.delivery_address or 'To be confirmed with customer',
            latitude=so.delivery_lat,
            longitude=so.delivery_lng,
            recipient_name=so.customer_name or '—',
            recipient_phone=so.customer_phone or '',
            delivery_fee=so.delivery_fee or 0,
            status=Delivery.Status.TO_BE_PACKED,
            notes=f'Auto-created from sales order {so.so_number}',
        )
    elif so.status == SalesOrder.Status.CANCELLED and delivery is not None:
        if delivery.status not in (Delivery.Status.DELIVERED, Delivery.Status.FAILED):
            delivery.status = Delivery.Status.CANCELLED
            delivery.save(update_fields=['status', 'updated_at'])


class SalesOrderSerializer(serializers.ModelSerializer):
    customer_id = serializers.IntegerField(write_only=True, required=False, allow_null=True)
    created_by_name = serializers.CharField(source='created_by.full_name', read_only=True)
    branch_name = serializers.CharField(source='branch.name', read_only=True)
    so_number = serializers.CharField(required=False, allow_blank=True)
    balance_due = serializers.SerializerMethodField()

    class Meta:
        model = SalesOrder
        fields = [
            'id', 'so_number', 'customer', 'customer_id', 'customer_name', 'customer_phone',
            'items', 'total_amount', 'discount_amount', 'delivery_fee', 'amount_paid',
            'balance_due', 'status', 'payment_status', 'payment_method',
            'expected_delivery', 'delivery_address', 'delivery_place_name',
            'delivery_lat', 'delivery_lng', 'notes',
            'branch', 'branch_name', 'created_by', 'created_by_name',
            'created_at', 'updated_at',
        ]
        read_only_fields = [
            'id', 'total_amount', 'payment_status', 'balance_due',
            'branch_name', 'created_by_name', 'created_at', 'updated_at',
        ]

    def get_balance_due(self, obj):
        return float(obj.balance_due)

    def _round_coord(self, value):
        """Google coordinates can carry >6 decimal places; quantize silently."""
        if value is None:
            return value
        return Decimal(value).quantize(Decimal('0.000001'))

    def validate_delivery_lat(self, value):
        return self._round_coord(value)

    def validate_delivery_lng(self, value):
        return self._round_coord(value)

    def _ensure_so_number(self, value):
        return value or f'SO-{uuid.uuid4().hex[:8].upper()}'

    @transaction.atomic
    def create(self, validated_data):
        request = self.context.get('request')
        # Support both FK customer id and free-text customer name
        customer_id = validated_data.pop('customer_id', None)
        if customer_id:
            validated_data['customer_id'] = customer_id
        items = validated_data.pop('items', []) or []
        cleaned, subtotal = _normalize_items(items)
        validated_data['items'] = cleaned
        validated_data['so_number'] = self._ensure_so_number(validated_data.get('so_number'))
        discount = _to_decimal(validated_data.get('discount_amount') or 0)
        delivery = _to_decimal(validated_data.get('delivery_fee') or 0)
        validated_data['total_amount'] = max(Decimal('0'), subtotal - discount + delivery)
        if request and getattr(request, 'user', None) and request.user.is_authenticated:
            validated_data['created_by'] = request.user
        so = super().create(validated_data)
        so.recompute_payment_status()
        so.save(update_fields=['payment_status', 'updated_at'])
        if so.status == SalesOrder.Status.FULFILLED:
            _fulfill_delivered_items(so, user=request.user if request else None)
        _sync_stock_commitment(so)
        _sync_delivery(so)
        return so

    @transaction.atomic
    def update(self, instance, validated_data):
        customer_id = validated_data.pop('customer_id', None)
        if customer_id:
            validated_data['customer_id'] = customer_id
        items = validated_data.pop('items', None)
        if items is not None:
            cleaned, subtotal = _normalize_items(items)
            # Preserve delivery / commitment bookkeeping flags from the saved order
            prev_map = {i.get('stock_id'): i for i in (instance.items or [])}
            for it in cleaned:
                prev = prev_map.get(it['stock_id'])
                if prev:
                    for k in ('_committed', '_committed_qty', '_delivered', '_delivered_short'):
                        if k in prev:
                            it[k] = prev[k]
            validated_data['items'] = cleaned
            discount = _to_decimal(validated_data.get('discount_amount', instance.discount_amount) or 0)
            delivery = _to_decimal(validated_data.get('delivery_fee', instance.delivery_fee) or 0)
            validated_data['total_amount'] = max(Decimal('0'), subtotal - discount + delivery)
        elif 'delivery_fee' in validated_data or 'discount_amount' in validated_data:
            # Fee/discount changed without new items — recompute from saved line totals
            existing_subtotal = sum((Decimal(str(it.get('total') or 0))
                                     for it in (instance.items or [])), Decimal('0'))
            discount = _to_decimal(validated_data.get('discount_amount', instance.discount_amount) or 0)
            delivery = _to_decimal(validated_data.get('delivery_fee', instance.delivery_fee) or 0)
            validated_data['total_amount'] = max(Decimal('0'), existing_subtotal - discount + delivery)
        if not validated_data.get('so_number') and not instance.so_number:
            validated_data['so_number'] = self._ensure_so_number(None)
        so = super().update(instance, validated_data)
        so.recompute_payment_status()
        so.save(update_fields=['payment_status', 'updated_at'])
        if so.status == SalesOrder.Status.FULFILLED:
            request = self.context.get('request')
            _fulfill_delivered_items(so, user=request.user if request else None)
        _sync_stock_commitment(so)
        _sync_delivery(so)
        return so
