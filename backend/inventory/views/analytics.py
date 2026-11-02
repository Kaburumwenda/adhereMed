"""Dashboard analytics, the one-shot overview and the stock movement report payload."""
from __future__ import annotations

import csv
import io
import logging
import os
from datetime import timedelta

from django.db.models import (Sum, Count, Max, F, DecimalField, IntegerField, Q,
                              ExpressionWrapper, Prefetch)
from django.db.models.functions import Cast, Coalesce
from django.http import HttpResponse
from django.utils import timezone
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import serializers, status, viewsets, filters
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated, SAFE_METHODS
from rest_framework.response import Response
from rest_framework.views import APIView

from config.branch_scope import (BranchScopedMixin, get_user_branch,
                                 is_branch_scoped_user)
from pharmacy_profile.models import Branch

from ..models import (Category, Unit, Classification, MedicationStock, StockBatch,
                      StockAdjustment, InventoryCount, InventoryCountLine,
                      StockTransfer, StockTransferLine, ControlledSubstanceLog,
                      RoleDefinition)
from ..rbac import (InventoryPermission, AdjustmentPermission, StockTakePermission,
                    TransferPermission, ControlledRegisterPermission,
                    TenantAdminOnly, has_capability, can_view_cost,
                    ROLE_META, ALL_CAP_KEYS, CAPABILITY_LABELS, ASSIGNABLE_ROLES,
                    RESERVED_ROLE_KEYS, capability_matrix, BUILTIN_ROLE_CAPS,
                    EDITABLE_BUILTIN_ROLES, PROTECTED_BUILTIN_CAPS,
                    PHARMACY_ROLE_META, PHARMACY_ASSIGNABLE_ROLES,
                    PHARMACY_EDITABLE_BUILTIN_ROLES, _role_caps)
from ..serializers import (CategorySerializer, UnitSerializer,
                           ClassificationSerializer, MedicationStockSerializer,
                           MedicationStockListSerializer, StockBatchSerializer,
                           StockAdjustmentSerializer, InventoryCountSerializer,
                           InventoryCountLineSerializer, StockTransferSerializer,
                           ControlledSubstanceLogSerializer)
from ..services.stock import (InsufficientStock, apply_quantity_change,
                              reconcile_quantity)
from .base import (_assignable_roles_for, _audit, _editable_builtin_roles_for,
                   _forced_branch_id, _is_pharmacy, _parse_date, _require_branch,
                   _role_meta_for, _tenant_type)

logger = logging.getLogger(__name__)


class InventoryAnalyticsView(APIView):
    """Aggregated inventory analytics for the pharmacy dashboard."""

    permission_classes = [InventoryPermission]

    def get(self, request):
        branch_id = request.query_params.get('branch_id') or request.query_params.get('branch')
        # Force non-admin users to their own branch
        from config.branch_scope import BRANCH_ADMIN_BYPASS_ROLES, get_user_branch
        role = getattr(request.user, 'role', '')
        if role not in BRANCH_ADMIN_BYPASS_ROLES and not getattr(request.user, 'is_superuser', False):
            branch_id = get_user_branch(request.user)
        stocks = MedicationStock.objects.with_quantities().filter(is_active=True)
        if branch_id:
            stocks = stocks.filter(Q(branch_id=branch_id) | Q(branch__isnull=True))
        today = timezone.localdate()

        # One aggregate query replaces the per-row Python loop (which used to
        # fire up to three extra queries per stock item).
        qty_dec = Cast('annotated_total_quantity',
                       output_field=DecimalField(max_digits=20, decimal_places=2))
        totals = stocks.aggregate(
            total_items=Count('id'),
            # NB: no Coalesce(x, 0) here — mixing a Decimal aggregate with an
            # integer 0 raises "Expression contains mixed types".
            cost_value=Sum(qty_dec * F('cost_price')),
            retail_value=Sum(qty_dec * F('selling_price')),
        )
        sellable_now = ExpressionWrapper(
            F('annotated_sellable_quantity') - F('committed_qty'),
            output_field=IntegerField(),
        )
        # One rule, shared with the UI (nuxtfrontend/utils/stockStatus.js):
        #   quarantine = nothing sellable AND units are on a recall /
        #                auto-quarantine hold (physically here, not for sale)
        #   out        = nothing sellable for any other reason
        #   low        = some sellable, but at or below the reorder level
        #   healthy    = the rest
        # Folding quarantine into `out` told the warehouse to reorder stock it
        # already owns, and hid every open recall behind a restock alert.
        quarantined_q = Q(annotated_blocked_quantity__gt=0) & Q(_sellable_now__lte=0)
        health = stocks.annotate(_sellable_now=sellable_now).aggregate(
            low_stock_count=Count(
                'id', filter=Q(_sellable_now__gt=0,
                               _sellable_now__lte=F('reorder_level'))),
            out_of_stock=Count(
                'id', filter=Q(_sellable_now__lte=0) & ~quarantined_q),
            quarantined=Count('id', filter=quarantined_q),
        )
        total_items = totals['total_items'] or 0
        low_stock_count = health['low_stock_count'] or 0
        out_of_stock = health['out_of_stock'] or 0
        quarantined = health['quarantined'] or 0
        total_cost_value = float(totals['cost_value'] or 0)
        total_retail_value = float(totals['retail_value'] or 0)

        # Expiring within 30/90 days — three filtered counts in one query.
        batch_qs = StockBatch.objects.filter(quantity_remaining__gt=0)
        if branch_id:
            batch_qs = batch_qs.filter(Q(branch_id=branch_id) | Q(branch__isnull=True))
        expiry = batch_qs.aggregate(
            expiring_30=Count('id', filter=Q(
                expiry_date__gte=today, expiry_date__lte=today + timedelta(days=30))),
            expiring_90=Count('id', filter=Q(
                expiry_date__gte=today, expiry_date__lte=today + timedelta(days=90))),
            expired=Count('id', filter=Q(expiry_date__lt=today)),
        )
        expiring_30 = expiry['expiring_30'] or 0
        expiring_90 = expiry['expiring_90'] or 0
        expired = expiry['expired'] or 0

        # RBAC: cost-based valuation is hidden from till roles.
        if not can_view_cost(request):
            total_cost_value = 0.0

        return Response({
            'total_items': total_items,
            'low_stock_count': low_stock_count,
            'out_of_stock': out_of_stock,
            'quarantined_count': quarantined,
            'total_cost_value': round(total_cost_value, 2),
            'total_retail_value': round(total_retail_value, 2),
            'potential_profit': (round(total_retail_value - total_cost_value, 2)
                                 if can_view_cost(request) else None),
            'expiring_30_days': expiring_30,
            'expiring_90_days': expiring_90,
            'expired_batches': expired,
        })


class InventoryOverviewView(APIView):
    """One-shot snapshot of the whole inventory operation for the IMS
    overview screen: stock health, expiry, procurement, fulfilment and
    sales — all aggregated into a single lightweight payload."""

    permission_classes = [InventoryPermission]

    @staticmethod
    def _parse_date(value):
        """Parse a YYYY-MM-DD query value into a date (or None)."""
        if not value:
            return None
        try:
            return timezone.datetime.strptime(str(value)[:10], '%Y-%m-%d').date()
        except (TypeError, ValueError):
            return None

    def get(self, request):
        now = timezone.now()
        today = now.date()

        # Optional date range (YYYY-MM-DD). Scopes the time-based metrics:
        # deliveries, procurement (GRNs / POs) and sales. Stock health and
        # expiry are "as of now" snapshots and stay unfiltered.
        date_from = self._parse_date(request.query_params.get('date_from'))
        date_to = self._parse_date(request.query_params.get('date_to'))

        # Optional branch filter — restricts all data to the given branch.
        # Items with branch=NULL are shared/unassigned and always included.
        branch_id = request.query_params.get('branch_id') or request.query_params.get('branch')
        # Force non-admin users to their own branch
        from config.branch_scope import BRANCH_ADMIN_BYPASS_ROLES, get_user_branch
        role = getattr(request.user, 'role', '')
        if role not in BRANCH_ADMIN_BYPASS_ROLES and not getattr(request.user, 'is_superuser', False):
            branch_id = get_user_branch(request.user)
        branch_q = None
        if branch_id:
            branch_q = Q(branch_id=branch_id) | Q(branch__isnull=True)

        stocks = MedicationStock.objects.with_quantities().filter(is_active=True)
        if branch_id:
            stocks = stocks.filter(branch_q)

        # ── Stock health ────────────────────────────────────────────────
        # Same mutually-exclusive rule as InventoryAnalyticsView and the UI:
        # out = nothing sellable, low = sellable but at/below reorder.
        stock_rows = list(stocks)
        total_items = len(stock_rows)
        units_on_hand = 0
        low_stock = 0
        out_of_stock = 0
        for s in stock_rows:
            qty = s.total_quantity
            units_on_hand += qty
            if s.available_quantity <= 0:
                out_of_stock += 1
            elif s.available_quantity <= (s.reorder_level or 0):
                low_stock += 1

        # ── Expiry (three filtered counts in one query) ──────────────────
        batch_qs = StockBatch.objects.filter(quantity_remaining__gt=0)
        if branch_id:
            batch_qs = batch_qs.filter(branch_q)
        expiry = batch_qs.aggregate(
            expiring_30=Count('id', filter=Q(
                expiry_date__gte=today, expiry_date__lte=today + timedelta(days=30))),
            expiring_90=Count('id', filter=Q(
                expiry_date__gte=today, expiry_date__lte=today + timedelta(days=90))),
            expired=Count('id', filter=Q(expiry_date__lt=today)),
        )
        expiring_30 = expiry['expiring_30'] or 0
        expiring_90 = expiry['expiring_90'] or 0
        expired = expiry['expired'] or 0

        # ── Deliveries (outbound fulfilment) ────────────────────────────
        try:
            from pharmacy_profile.models import Delivery
            delivery_qs = Delivery.objects.all()
            if date_from:
                delivery_qs = delivery_qs.filter(created_at__date__gte=date_from)
            if date_to:
                delivery_qs = delivery_qs.filter(created_at__date__lte=date_to)
            delivery_agg = {
                row['status']: row['c']
                for row in delivery_qs.values('status').annotate(c=Count('id'))
            }
            to_be_packed = sum(
                c for k, c in delivery_agg.items() if k in ('to_be_packed', 'pending'))
            to_be_shipped = sum(
                c for k, c in delivery_agg.items()
                if k in ('to_be_shipped', 'assigned', 'in_transit'))
        except Exception:
            to_be_packed = 0
            to_be_shipped = 0

        # ── Procurement (inbound) ───────────────────────────────────────
        try:
            from purchase_orders.models import PurchaseOrder, GoodsReceivedNote
            po_qs = PurchaseOrder.objects.all()
            if branch_id:
                po_qs = po_qs.filter(Q(branch_id=branch_id) | Q(branch__isnull=True))
            if date_from:
                po_qs = po_qs.filter(order_date__gte=date_from)
            if date_to:
                po_qs = po_qs.filter(order_date__lte=date_to)
            open_pos = po_qs.filter(
                status__in=('draft', 'sent', 'partial')).count()

            grn_qs = GoodsReceivedNote.objects.all()
            if branch_id:
                grn_qs = grn_qs.filter(
                    Q(purchase_order__branch_id=branch_id) | Q(purchase_order__branch__isnull=True))
            if date_from:
                grn_qs = grn_qs.filter(received_date__gte=date_from)
            if date_to:
                grn_qs = grn_qs.filter(received_date__lte=date_to)
            received_grns = grn_qs.count()
            # GRNs represent received goods; each GRN line records a qty.
            items_received = 0
            for grn in grn_qs:
                for it in (grn.items_received or []):
                    try:
                        items_received += int(it.get('qty') or it.get('quantity') or 0)
                    except (TypeError, ValueError):
                        continue
        except Exception:
            open_pos = 0
            received_grns = 0
            items_received = 0

        # ── Sales ───────────────────────────────────────────────────────
        try:
            from pos.models import POSTransaction, TransactionItem
            txn_qs = POSTransaction.objects.filter(status='completed')
            if branch_id:
                txn_qs = txn_qs.filter(Q(branch_id=branch_id) | Q(branch__isnull=True))
            if date_from:
                txn_qs = txn_qs.filter(created_at__date__gte=date_from)
            if date_to:
                txn_qs = txn_qs.filter(created_at__date__lte=date_to)

            sold_qty = TransactionItem.objects.filter(
                transaction__in=txn_qs).aggregate(
                total=Sum('quantity'))['total'] or 0
            # ``total`` is a Decimal column — coalescing it with an integer 0
            # raised a FieldError that the surrounding except turned into a
            # silent revenue of 0.
            revenue = txn_qs.aggregate(total=Sum('total'))['total'] or 0
            recent_transactions = txn_qs.order_by('-created_at')[:6]
            recent = [{
                'transaction_number': t.transaction_number,
                'customer_name': t.customer_name or (t.customer.name if t.customer else '') or 'Walk-in',
                'total': float(t.total or 0),
                'payment_method': t.payment_method,
                'created_at': t.created_at.isoformat(timespec='seconds'),
            } for t in recent_transactions]
        except Exception:
            sold_qty = 0
            revenue = 0
            recent = []

        # ── Top moving items (units sold in the filtered window) ────────
        top_moving = []
        try:
            from pos.models import TransactionItem
            mover_qs = (TransactionItem.objects
                        .filter(transaction__in=txn_qs, stock__isnull=False)
                        .values('stock_id', 'stock__medication_name',
                                'stock__unit__abbreviation')
                        .annotate(
                            qty=Sum('quantity'),
                            revenue=Sum('total_price'),
                        )
                        .order_by('-qty')[:8])
            top_moving = [{
                'stock_id': m['stock_id'],
                'name': m['stock__medication_name'],
                'unit': m['stock__unit__abbreviation'] or '',
                'qty': int(m['qty'] or 0),
                'revenue': float(m['revenue'] or 0),
            } for m in mover_qs]
        except Exception:
            top_moving = []

        # ── Dead stock (on-hand items with no sale in the last 90 days) ──
        dead_stock = []
        try:
            from pos.models import TransactionItem
            threshold = today - timedelta(days=90)
            recently_sold = set(
                TransactionItem.objects
                .filter(stock__isnull=False,
                        transaction__status='completed',
                        transaction__created_at__date__gte=threshold)
                .values_list('stock_id', flat=True)
                .distinct()
            )
            last_sale = {
                row['stock_id']: row['last']
                for row in (TransactionItem.objects
                            .filter(stock__isnull=False,
                                    transaction__status='completed')
                            .values('stock_id')
                            .annotate(last=Max('transaction__created_at')))
            }
            for s in stock_rows:
                if s.total_quantity <= 0 or s.id in recently_sold:
                    continue
                last = last_sale.get(s.id)
                ref = last if last else s.created_at
                days_idle = (today - ref.date()).days if ref else None
                dead_stock.append({
                    'stock_id': s.id,
                    'name': s.medication_name,
                    'qty': s.total_quantity,
                    'unit': s.unit.abbreviation if s.unit else '',
                    'last_sale_at': last.isoformat(timespec='seconds') if last else None,
                    'days_idle': days_idle,
                })
            dead_stock.sort(key=lambda x: x['qty'], reverse=True)
            dead_stock = dead_stock[:10]
        except Exception:
            dead_stock = []

        return Response({
            'stock': {
                'total_items': total_items,
                'units_on_hand': units_on_hand,
                'low_stock': low_stock,
                'out_of_stock': out_of_stock,
                'healthy': max(0, total_items - low_stock - out_of_stock),
            },
            'expiry': {
                'expiring_30': expiring_30,
                'expiring_90': expiring_90,
                'expired': expired,
            },
            'deliveries': {
                'to_be_packed': to_be_packed,
                'to_be_shipped': to_be_shipped,
            },
            'procurement': {
                'open_purchase_orders': open_pos,
                'received_grns': received_grns,
                'items_received': items_received,
            },
            'sales': {
                'units_sold': sold_qty,
                'revenue': float(revenue),
                'recent': recent,
            },
            'top_moving': top_moving,
            'dead_stock': dead_stock,
        })
