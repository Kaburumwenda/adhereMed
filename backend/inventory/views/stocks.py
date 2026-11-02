"""Stock items, batches and quantity adjustments."""
from __future__ import annotations

import csv
import io
import logging
import os
from datetime import timedelta

from django.db.models import (Sum, Count, Max, F, DecimalField, IntegerField, Q,
                              ExpressionWrapper, Prefetch)
from django.db.models.functions import Coalesce
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
                      RoleDefinition, CHANNEL_ADJUSTMENT_REASONS)
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


class MedicationStockViewSet(BranchScopedMixin, viewsets.ModelViewSet):
    queryset = MedicationStock.objects.select_related(
        'category', 'unit', 'branch', 'classification').all()
    serializer_class = MedicationStockSerializer
    permission_classes = [InventoryPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['is_active', 'category', 'unit', 'classification', 'branch']
    search_fields = ['medication_name', 'abbreviation', 'barcode']
    ordering_fields = ['medication_name', 'selling_price', 'created_at']

    def get_serializer_class(self):
        if self.action == 'list':
            return MedicationStockListSerializer
        return MedicationStockSerializer

    # ── Audit trail for catalog / price changes ──────────────────────────
    _AUDITED_FIELDS = ('medication_name', 'selling_price', 'cost_price',
                       'reorder_level', 'reorder_quantity', 'is_active',
                       'branch_id', 'classification_id', 'barcode')

    @staticmethod
    def _stock_snapshot(stock):
        snap = {}
        for field in MedicationStockViewSet._AUDITED_FIELDS:
            value = getattr(stock, field, None)
            snap[field] = None if value is None else str(value)
        return snap

    def perform_create(self, serializer):
        stock = serializer.save()
        _audit(
            self.request, 'stock_create', stock,
            description=f'Created stock item {stock.medication_name}',
            object_type='inventory',
            payload_diff=self._stock_snapshot(stock),
        )

    def perform_update(self, serializer):
        before = self._stock_snapshot(serializer.instance)
        stock = serializer.save()
        after = self._stock_snapshot(stock)
        changes = {k: [before[k], after[k]]
                   for k in before if before[k] != after[k]}
        if changes:
            _audit(
                self.request, 'stock_update', stock,
                description=f'Updated stock item {stock.medication_name}',
                payload_diff={'changes': changes},
            )

    def perform_destroy(self, instance):
        _audit(
            self.request, 'stock_delete', instance, severity='warning',
            description=f'Deleted stock item {instance.medication_name}',
            payload_diff=self._stock_snapshot(instance),
        )
        instance.delete()

    def get_queryset(self):
        # Batch quantities are aggregated in SQL: one query instead of the
        # (up to) three per-row related queries the model properties used to
        # trigger. See MedicationStockQuerySet.with_quantities().
        qs = super().get_queryset().with_quantities()
        # ?branch= filtering: items with no warehouse assigned (branch=NULL)
        # are shared stock and stay visible in every warehouse view — the same
        # convention BranchScopedMixin uses. (Handled here instead of the DRF
        # filterset, which would filter with strict equality and hide them.)
        branch = self.request.query_params.get('branch')
        if branch:
            qs = qs.filter(Q(branch_id=branch) | Q(branch__isnull=True))
        if self.action == 'list':
            # List screens only read live batches (health, expiry runway and
            # the quantity columns); shipping exhausted batches for every row
            # made the 1000-row dashboard payload needlessly huge.
            qs = qs.prefetch_related(Prefetch(
                'batches',
                queryset=StockBatch.objects.filter(quantity_remaining__gt=0),
            ))
        return qs

    @action(detail=False, methods=['get'])
    def low_stock(self, request):
        stocks = self.get_queryset().filter(is_active=True)
        low = [s for s in stocks if s.is_low_stock]
        serializer = self.get_serializer(low, many=True)
        return Response(serializer.data)

    def destroy(self, request, *args, **kwargs):
        """Deleting a stock item is a destructive action gated by the
        stock.delete capability (supervisors may deactivate instead)."""
        if not has_capability(request, 'stock.delete'):
            return Response(
                {'detail': 'You do not have permission to delete stock items. '
                           'Deactivate the item instead.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        return super().destroy(request, *args, **kwargs)

    # ── Item details / insights ──────────────────────────────────────────
    @action(detail=True, methods=['get'], url_path='insights')
    def insights(self, request, pk=None):
        """Full item account: opening stock, on-hand/committed/available,
        purchase info, sales info, movement ledger, batches, trends.

        Query params:
          ?days=30                          (rolling window)
          ?date_from=YYYY-MM-DD&date_to=YYYY-MM-DD  (explicit range)
        """
        from datetime import datetime as _dt
        stock = self.get_object()

        def _parse_date(v):
            try:
                return _dt.strptime(v, '%Y-%m-%d')
            except (TypeError, ValueError):
                return None

        now = timezone.localtime().replace(tzinfo=None)
        date_from = _parse_date(request.query_params.get('date_from'))
        date_to = _parse_date(request.query_params.get('date_to'))
        if date_from or date_to:
            period_start = date_from or (now - timedelta(days=30)).replace(
                hour=0, minute=0, second=0, microsecond=0)
            period_end = date_to or now
            period_end = period_end.replace(hour=23, minute=59, second=59)
            days = max(1, (period_end.date() - period_start.date()).days + 1)
        else:
            try:
                days = max(1, min(365, int(request.query_params.get('days', 30))))
            except (TypeError, ValueError):
                days = 30
            period_start = (now - timedelta(days=days)).replace(
                hour=0, minute=0, second=0, microsecond=0)
            period_end = now

        # ── Event-source every quantity change for this stock ───────────
        events = []  # (naive_dt, delta, type, label, ref)

        for b in (StockBatch.objects.filter(stock=stock)
                  .only('batch_number', 'quantity_received', 'received_date')):
            if (b.batch_number or '').upper().startswith('RET-'):
                continue
            d = _dt.combine(b.received_date, _dt.min.time()) if b.received_date else None
            events.append((d, int(b.quantity_received or 0), 'receipt',
                           'Stock received', b.batch_number or ''))

        try:
            from pos.models import TransactionItem
            for ti in (TransactionItem.objects
                       .filter(stock=stock, transaction__status='completed')
                       .select_related('transaction')
                       .only('quantity', 'transaction__created_at',
                             'transaction__transaction_number')):
                events.append((timezone.localtime(ti.transaction.created_at)
                                .replace(tzinfo=None),
                               -(ti.quantity or 0), 'sale', 'POS sale',
                               ti.transaction.transaction_number))
        except Exception:
            pass

        try:
            from dispensing.models import DispensingRecord, DispenseReturn
            for rec in (DispensingRecord.objects.filter(status='completed')
                        .only('dispensed_at', 'items_dispensed')):
                for it in (rec.items_dispensed or []):
                    if it.get('stock_id') == stock.pk:
                        d = timezone.localtime(rec.dispensed_at).replace(tzinfo=None) \
                            if rec.dispensed_at else None
                        events.append((d, -int(it.get('qty') or 0), 'sale',
                                       'Dispensed', f'Record #{rec.pk}'))
            for ret in (DispenseReturn.objects.filter(restock=True)
                        .only('created_at', 'items_returned')):
                for it in (ret.items_returned or []):
                    if it.get('stock_id') == stock.pk:
                        d = timezone.localtime(ret.created_at).replace(tzinfo=None) \
                            if ret.created_at else None
                        events.append((d, int(it.get('qty') or 0), 'return',
                                       'Restocked return', f'Return #{ret.pk}'))
        except Exception:
            pass

        # POS / dispensing ledger rows are excluded: those channels are
        # replayed from their own records below, so counting them here would
        # double the running balance.
        for adj in (StockAdjustment.objects.filter(stock=stock)
                    .exclude(reason__in=CHANNEL_ADJUSTMENT_REASONS)
                    .only('quantity_change', 'reason', 'created_at', 'notes')):
            d = timezone.localtime(adj.created_at).replace(tzinfo=None)
            if adj.reason == 'sales_order':
                events.append((d, int(adj.quantity_change or 0), 'so_fulfillment',
                               'Sales order delivered', adj.notes or ''))
            else:
                events.append((d, int(adj.quantity_change or 0), 'adjustment',
                               (adj.get_reason_display() if adj.reason else 'Adjustment'),
                               f'ADJ #{adj.pk}'))

        for line in (StockTransferLine.objects
                     .filter(stock=stock, transfer__shipped_at__isnull=False)
                     .select_related('transfer')
                     .only('quantity', 'transfer__shipped_at',
                           'transfer__reference')):
            d = timezone.localtime(line.transfer.shipped_at).replace(tzinfo=None)
            events.append((d, -(line.quantity or 0), 'transfer_out',
                           'Transfer out', line.transfer.reference or ''))

        events.sort(key=lambda e: e[0] or _dt.min)
        events = [e for e in events if e[0] is not None]

        on_hand = stock.total_quantity or 0

        # ── Opening stock: on-hand at the start of the period ───────────
        opening = on_hand - sum(delta for dt, delta, *_ in events if dt >= period_start)

        # ── Period aggregates ────────────────────────────────────────────
        def in_period(dt):
            return period_start <= dt <= period_end

        def sum_type(etype, op='sum'):
            deltas = [d for dt, d, t, *_ in events
                      if t == etype and in_period(dt)]
            if not deltas:
                return 0
            return sum(deltas) if op == 'sum' else max(deltas)

        received = sum_type('receipt')
        sold = -sum_type('sale')
        returned = sum_type('return')
        adjusted = sum_type('adjustment')
        transferred_out = -sum_type('transfer_out')

        # ── Movement ledger with running balance (replay forward) ────────
        movements = []
        balance = on_hand - sum(delta for _, delta, *_ in events)
        for dt, delta, etype, label, ref in events:
            balance += delta
            movements.append({
                'timestamp': dt.isoformat(timespec='seconds'),
                'type': etype,
                'label': label,
                'reference': ref,
                'quantity_change': delta,
                'qty_before': balance - delta,
                'qty_after': balance,
            })
        movements.reverse()  # newest first
        movements_limited = movements[:300]

        # ── Purchases (PO lines referencing this stock) ──────────────────
        from purchase_orders.models import PurchaseOrder
        purchases = []
        price_history = []
        scanned = 0
        for po in (PurchaseOrder.objects.select_related('supplier')
                   .only('po_number', 'supplier__name', 'order_date', 'items',
                         'total_cost', 'status', 'created_at')
                   .order_by('-created_at')):
            scanned += 1
            if scanned > 800:
                break
            for it in (po.items or []):
                if it.get('medication_stock_id') == stock.pk:
                    qty = int(it.get('qty') or 0)
                    cost = float(it.get('unit_cost') or 0)
                    purchases.append({
                        'po_number': po.po_number,
                        'date': po.order_date.isoformat() if po.order_date else None,
                        'supplier': po.supplier.name if po.supplier else '',
                        'qty': qty,
                        'unit_cost': cost,
                        'status': po.status,
                    })
                    if qty and cost:
                        price_history.append({
                            'date': po.order_date.isoformat() if po.order_date else None,
                            'unit_cost': cost,
                            'qty': qty,
                        })
                    break
            if len(purchases) >= 25:
                break

        # ── Sales detail (POS lines) ──────────────────────────────────────
        sales = []
        units_sold_period = 0
        revenue_period = 0.0
        last_sale_at = None
        try:
            from pos.models import TransactionItem
            ti_qs = (TransactionItem.objects
                     .filter(stock=stock, transaction__status='completed')
                     .select_related('transaction')
                     .order_by('-transaction__created_at')
                     .only('quantity', 'unit_price', 'total_price',
                           'transaction__created_at',
                           'transaction__transaction_number')[:500])
            for ti in ti_qs:
                dt_local = timezone.localtime(ti.transaction.created_at)
                dt_naive = dt_local.replace(tzinfo=None)
                sale_in_period = in_period(dt_naive)
                if sale_in_period:
                    units_sold_period += int(ti.quantity or 0)
                    revenue_period += float(ti.total_price or 0)
                if last_sale_at is None:
                    last_sale_at = dt_local
                if len(sales) < 25:
                    sales.append({
                        'transaction_number': ti.transaction.transaction_number,
                        'date': dt_local.isoformat(timespec='seconds'),
                        'qty': int(ti.quantity or 0),
                        'unit_price': float(ti.unit_price or 0),
                        'total': float(ti.total_price or 0),
                    })
        except Exception:
            pass

        # ── Daily trends (period) ────────────────────────────────────────
        by_day_sold = {}
        by_day_received = {}
        for dt, delta, etype, *_ in events:
            if not in_period(dt):
                continue
            key = dt.date().isoformat()
            if etype == 'sale':
                by_day_sold[key] = by_day_sold.get(key, 0) + (-delta)
            elif etype == 'receipt':
                by_day_received[key] = by_day_received.get(key, 0) + delta
        days_list = []
        cursor = period_start.date()
        trend_end = min(period_end.date(), now.date())
        while cursor <= trend_end and len(days_list) <= 366:
            key = cursor.isoformat()
            days_list.append({
                'date': key,
                'sold': by_day_sold.get(key, 0),
                'received': by_day_received.get(key, 0),
            })
            cursor += timedelta(days=1)

        return Response({
            'stock': self.get_serializer(stock).data,
            'period_days': days,
            'period_start': period_start.date().isoformat(),
            'period_end': period_end.date().isoformat(),
            'opening_stock': opening,
            'account': {
                'on_hand': on_hand,
                'committed': stock.committed_qty or 0,
                'available_for_sale': stock.available_quantity,
                # Recall / quarantine hold. Separated from `on_hand` so the
                # detail hero can say "Quarantine" instead of "Out of stock".
                'quarantined': stock.blocked_quantity,
                'sellable': stock.sellable_quantity,
                'reorder_level': stock.reorder_level or 0,
                'reorder_quantity': stock.reorder_quantity or 0,
                'low_stock': stock.is_low_stock,
            },
            'period': {
                'received': received,
                'sold': sold,
                'returned': returned,
                'adjusted': adjusted,
                'transferred_out': transferred_out,
                'units_sold': units_sold_period,
                'sales_revenue': revenue_period,
            },
            'purchase_info': {
                'current_cost': float(stock.cost_price or 0),
                'current_selling': float(stock.selling_price or 0),
                'total_purchase_lines': len(purchases),
                'last_purchase': purchases[0] if purchases else None,
                'recent': purchases,
                'price_history': price_history,
            },
            'sales_info': {
                'units_sold_period': units_sold_period,
                'revenue_period': revenue_period,
                'last_sale_at': last_sale_at.isoformat(timespec='seconds')
                                if last_sale_at else None,
                'recent': sales,
            },
            'movements': movements_limited,
            'batches': StockBatchSerializer(
                stock.batches.all(), many=True,
                context={'request': request}).data if hasattr(stock, 'batches') else [],
            'trend': days_list,
        })

    # ── Stock item PDF report ────────────────────────────────────────────
    @action(detail=True, methods=['get'], url_path='report-pdf')
    def report_pdf(self, request, pk=None):
        """Branded PDF report for a single stock item: overview, KPIs,
        batches, recent purchases, recent sales and movement ledger."""
        import io as _io
        from reportlab.lib.pagesizes import A4
        from reportlab.lib.units import mm
        from reportlab.lib.colors import HexColor, white, Color
        from reportlab.lib.styles import ParagraphStyle
        from reportlab.lib.enums import TA_RIGHT, TA_CENTER, TA_LEFT
        from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer,
                                        Table, TableStyle, Image, Flowable)
        from config.pdf_branding import resolve_branding

        stock = self.get_object()
        logo_path, business_name = resolve_branding(request)

        # Organization (tenant) details for the header
        tenant = getattr(request, 'tenant', None)
        org_name = getattr(tenant, 'name', '') or business_name or 'AdhereMed'
        org_address = getattr(tenant, 'address', '') or ''
        org_phone = getattr(tenant, 'phone', '') or ''
        org_email = getattr(tenant, 'email', '') or ''
        org_website = getattr(tenant, 'website', '') or ''

        # ── Branding colors from tenant (set via /ims/organization/branding) ─
        def _hex_color(attr, default):
            """Read a hex colour from the tenant, fall back to default."""
            val = getattr(tenant, attr, '') if tenant else ''
            if val and isinstance(val, str) and val.startswith('#') and len(val) == 7:
                try:
                    return HexColor(val)
                except Exception:
                    pass
            return HexColor(default)

        BRAND_PRIMARY   = _hex_color('brand_primary',   '#2f6dff')
        BRAND_SECONDARY = _hex_color('brand_secondary', '#143ce1')
        BRAND_ACCENT    = _hex_color('brand_accent',    '#37d6ff')

        # ── Premium palette ──────────────────────────────────────────
        NAVY      = HexColor('#0F172A')
        INDIGO    = BRAND_PRIMARY   # use brand primary for section bars etc.
        SKY       = BRAND_ACCENT     # accent for highlights
        SLATE     = HexColor('#64748B')
        SLATE_LT  = HexColor('#94A3B8')
        BORDER    = HexColor('#E2E8F0')
        BORDER_LT = HexColor('#F1F5F9')
        BG_CARD   = HexColor('#F8FAFC')
        GREEN     = HexColor('#16A34A')
        GREEN_BG  = HexColor('#F0FDF4')
        RED       = HexColor('#EF4444')
        RED_BG    = HexColor('#FEF2F2')
        AMBER     = HexColor('#F59E0B')
        AMBER_BG  = HexColor('#FFFBEB')
        BLUE_BG   = HexColor('#EFF6FF')
        PURPLE_BG = HexColor('#FAF5FF')

        # ── Styles ───────────────────────────────────────────────────
        st_report_title = ParagraphStyle('rt', fontName='Helvetica-Bold', fontSize=20,
                                          textColor=white, leading=24)
        st_report_sub   = ParagraphStyle('rs', fontName='Helvetica', fontSize=8,
                                          textColor=HexColor('#CBD5E1'), leading=12)
        st_org_name     = ParagraphStyle('on', fontName='Helvetica-Bold', fontSize=13,
                                          textColor=NAVY, leading=16)
        st_org_detail   = ParagraphStyle('od', fontName='Helvetica', fontSize=7.5,
                                          textColor=SLATE, leading=11)
        st_section       = ParagraphStyle('sec', fontName='Helvetica-Bold', fontSize=10,
                                           textColor=white, leading=13)
        st_section_alt   = ParagraphStyle('seca', fontName='Helvetica-Bold', fontSize=10,
                                           textColor=NAVY, leading=13)
        st_k    = ParagraphStyle('k',  fontName='Helvetica-Bold', fontSize=7,
                                textColor=SLATE, leading=9)
        st_v    = ParagraphStyle('v',  fontName='Helvetica', fontSize=9,
                                textColor=NAVY, leading=12)
        st_kpi_label = ParagraphStyle('kl', fontName='Helvetica-Bold', fontSize=7,
                                       textColor=SLATE_LT, leading=10, alignment=TA_CENTER)
        st_kpi_value_s = ParagraphStyle('ks', fontName='Helvetica-Bold', fontSize=16,
                                         textColor=NAVY, leading=18, alignment=TA_CENTER)
        st_kpi_value_m = ParagraphStyle('km', fontName='Helvetica-Bold', fontSize=11,
                                         textColor=NAVY, leading=14, alignment=TA_CENTER)
        st_cell    = ParagraphStyle('c',  fontName='Helvetica', fontSize=7.5, leading=10,
                                    textColor=NAVY)
        st_cell_r  = ParagraphStyle('cr', parent=st_cell, alignment=TA_RIGHT)
        st_cell_c  = ParagraphStyle('cc', parent=st_cell, alignment=TA_CENTER)
        st_th      = ParagraphStyle('th', fontName='Helvetica-Bold', fontSize=7,
                                    textColor=SLATE, leading=9)
        st_empty   = ParagraphStyle('e',  fontName='Helvetica-Oblique', fontSize=8,
                                    textColor=SLATE_LT, alignment=TA_CENTER)
        st_foot       = ParagraphStyle('foot',  fontName='Helvetica', fontSize=7,
                                       textColor=SLATE, alignment=TA_CENTER, leading=10)
        st_foot_brand = ParagraphStyle('fbr',  fontName='Helvetica-Bold', fontSize=9,
                                       textColor=INDIGO, alignment=TA_CENTER, leading=11)
        st_foot_link  = ParagraphStyle('flk',  fontName='Helvetica', fontSize=7,
                                       textColor=SKY, alignment=TA_CENTER, leading=10)

        def money(v):
            return f'KSh {float(v or 0):,.2f}'

        def stamp(d):
            if not d:
                return '—'
            from datetime import datetime as _dtc
            try:
                return _dtc.fromisoformat(str(d)).strftime('%b %d %Y')
            except (TypeError, ValueError):
                return str(d)

        # ── Data gathering (same as before) ───────────────────────────
        from datetime import timedelta
        now = timezone.localtime().replace(tzinfo=None)
        period_start = (now - timedelta(days=30)).replace(
            hour=0, minute=0, second=0, microsecond=0)
        period_end = now

        batches = list(stock.batches.all().order_by('-received_date')[:50]) if hasattr(stock, 'batches') else []

        on_hand = stock.total_quantity or 0
        committed = stock.committed_qty or 0
        available = stock.available_quantity
        reorder = stock.reorder_level or 0
        low_stock = stock.is_low_stock
        stock_value = on_hand * float(stock.cost_price or 0)

        from purchase_orders.models import PurchaseOrder
        purchases = []
        for po in (PurchaseOrder.objects.select_related('supplier')
                   .only('po_number', 'supplier__name', 'order_date', 'items')
                   .order_by('-created_at')[:200]):
            for it in (po.items or []):
                if it.get('medication_stock_id') == stock.pk:
                    purchases.append({
                        'po_number': po.po_number,
                        'date': po.order_date.isoformat() if po.order_date else '',
                        'supplier': po.supplier.name if po.supplier else '',
                        'qty': int(it.get('qty') or 0),
                        'unit_cost': float(it.get('unit_cost') or 0),
                    })
                    break
            if len(purchases) >= 15:
                break

        recent_sales = []
        try:
            from pos.models import TransactionItem
            for ti in (TransactionItem.objects
                       .filter(stock=stock, transaction__status='completed')
                       .select_related('transaction')
                       .order_by('-transaction__created_at')[:15]
                       .only('quantity', 'unit_price', 'total_price',
                             'transaction__transaction_number',
                             'transaction__created_at')):
                recent_sales.append({
                    'txn': ti.transaction.transaction_number,
                    'date': timezone.localtime(ti.transaction.created_at).strftime('%b %d %Y'),
                    'qty': int(ti.quantity or 0),
                    'price': float(ti.unit_price or 0),
                    'total': float(ti.total_price or 0),
                })
        except Exception:
            pass

        movements = []
        for adj in (StockAdjustment.objects.filter(stock=stock)
                    .only('quantity_change', 'reason', 'created_at', 'notes')
                    .order_by('-created_at')[:30]):
            movements.append({
                'date': timezone.localtime(adj.created_at).strftime('%b %d %Y'),
                'reason': adj.get_reason_display() if adj.reason else 'Adjustment',
                'change': int(adj.quantity_change or 0),
                'notes': (adj.notes or '')[:60],
            })

        # ── Helper: section header bar ───────────────────────────────
        def section_bar(title):
            """Indigo pill-bar section header with white text."""
            t = Table(
                [[Paragraph(title, st_section)]],
                colWidths=[182 * mm],
            )
            t.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, -1), INDIGO),
                ('LEFTPADDING', (0, 0), (-1, -1), 5 * mm),
                ('RIGHTPADDING', (0, 0), (-1, -1), 5 * mm),
                ('TOPPADDING', (0, 0), (-1, -1), 2.5 * mm),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 2.5 * mm),
                ('ROUNDEDCORNERS', [3, 3, 3, 3]),
            ]))
            return t

        # ── Helper: modern table style ───────────────────────────────
        def modern_table_style(num_cols, num_rows, right_cols=()):
            """Clean borderless look: header tinted, subtle row separators,
            zebra striping, right-aligned numeric columns."""
            cmds = [
                # Header row
                ('BACKGROUND', (0, 0), (-1, 0), BG_CARD),
                ('TEXTCOLOR',  (0, 0), (-1, 0), SLATE),
                ('FONTNAME',   (0, 0), (-1, 0), 'Helvetica-Bold'),
                ('FONTSIZE',   (0, 0), (-1, 0), 7),
                ('LINEBELOW',  (0, 0), (-1, 0), 1.2, INDIGO),
                # Body rows
                ('FONTSIZE',   (0, 1), (-1, -1), 7.5),
                ('TEXTCOLOR',  (0, 1), (-1, -1), NAVY),
                ('LINEBELOW',  (0, 1), (-1, -1), 0.3, BORDER_LT),
                ('ROWBACKGROUNDS', (0, 1), (-1, -1), [white, BG_CARD]),
                # Common
                ('VALIGN',     (0, 0), (-1, -1), 'MIDDLE'),
                ('TOPPADDING', (0, 0), (-1, -1), 2.5 * mm),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 2.5 * mm),
                ('LEFTPADDING', (0, 0), (-1, -1), 3 * mm),
                ('RIGHTPADDING', (0, 0), (-1, -1), 3 * mm),
            ]
            for rc in right_cols:
                cmds.append(('ALIGN', (rc, 0), (rc, -1), 'RIGHT'))
            return TableStyle(cmds)

        # ── Org logo helper ──────────────────────────────────────────
        def fit_logo(path, max_h_mm, max_w_mm):
            try:
                if path and os.path.exists(path):
                    from reportlab.lib.utils import ImageReader
                    ir = ImageReader(path)
                    iw, ih = ir.getSize()
                    th = max_h_mm * mm
                    tw = iw * (th / ih)
                    if tw > max_w_mm * mm:
                        tw = max_w_mm * mm
                        th = ih * (tw / iw)
                    return Image(path, width=tw, height=th)
            except Exception:
                pass
            return ''

        # ── Build document ───────────────────────────────────────────
        buf = _io.BytesIO()
        doc = SimpleDocTemplate(
            buf, pagesize=A4,
            leftMargin=14 * mm, rightMargin=14 * mm,
            topMargin=10 * mm, bottomMargin=16 * mm,
            title=f'Stock Report - {stock.medication_name}',
        )
        story = []

        # ═══════════════════════════════════════════════════════════════
        #  HEADER: Deep navy band with org logo + name + contact details
        # ═══════════════════════════════════════════════════════════════
        org_logo = fit_logo(logo_path, 22, 42)

        # Org contact line
        contact_parts = []
        if org_phone:
            contact_parts.append(f'Tel: {org_phone}')
        if org_email:
            contact_parts.append(f'Email: {org_email}')
        if org_website:
            contact_parts.append(f'Web: {org_website}')
        contact_str = '  ·  '.join(contact_parts)

        org_info_html = f'<font color="#0F172A"><b>{org_name}</b></font>'
        if org_address:
            org_info_html += f'<br/><font color="#64748B">{org_address}</font>'
        if contact_str:
            org_info_html += f'<br/><font color="#64748B">{contact_str}</font>'

        # Top header: navy strip
        header_inner = Table(
            [[org_logo, Paragraph(org_info_html, st_org_detail)]],
            colWidths=[44 * mm, 138 * mm],
        )
        header_inner.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (0, 0), 2 * mm),
            ('RIGHTPADDING', (1, 0), (1, 0), 2 * mm),
            ('TOPPADDING', (0, 0), (-1, -1), 3 * mm),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 3 * mm),
        ]))

        header_band = Table(
            [[header_inner]],
            colWidths=[182 * mm],
        )
        header_band.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), NAVY),
            ('TEXTCOLOR',  (0, 0), (-1, -1), white),
            ('LEFTPADDING', (0, 0), (-1, -1), 5 * mm),
            ('RIGHTPADDING', (0, 0), (-1, -1), 5 * mm),
            ('TOPPADDING', (0, 0), (-1, -1), 4 * mm),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 4 * mm),
        ]))
        # Wrap to get the org text white
        st_org_white = ParagraphStyle('ow', fontName='Helvetica', fontSize=8,
                                       textColor=white, leading=11)
        st_org_name_w = ParagraphStyle('onw', fontName='Helvetica-Bold', fontSize=12,
                                        textColor=white, leading=15)
        org_info_w = f'<font color="white"><b>{org_name}</b></font>'
        if org_address:
            org_info_w += f'<br/><font color="#94A3B8">{org_address}</font>'
        if contact_str:
            org_info_w += f'<br/><font color="#94A3B8">{contact_str}</font>'
        header_inner2 = Table(
            [[org_logo, Paragraph(org_info_w, st_org_white)]],
            colWidths=[44 * mm, 138 * mm],
        )
        header_inner2.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (0, 0), 2 * mm),
            ('RIGHTPADDING', (1, 0), (1, 0), 2 * mm),
            ('TOPPADDING', (0, 0), (-1, -1), 3 * mm),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 3 * mm),
        ]))
        header_band = Table(
            [[header_inner2]],
            colWidths=[182 * mm],
        )
        header_band.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), BRAND_SECONDARY),
            ('LEFTPADDING', (0, 0), (-1, -1), 5 * mm),
            ('RIGHTPADDING', (0, 0), (-1, -1), 5 * mm),
            ('TOPPADDING', (0, 0), (-1, -1), 5 * mm),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 5 * mm),
        ]))
        story.append(header_band)

        # Accent strip (indigo → sky → indigo thin line)
        accent = Table([['']], colWidths=[182 * mm], rowHeights=[2 * mm])
        accent.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), INDIGO),
        ]))
        story.append(accent)

        # ═══════════════════════════════════════════════════════════════
        #  REPORT TITLE BAND
        # ═══════════════════════════════════════════════════════════════
        title_data = [[
            Paragraph('Stock Item Report', st_report_title),
            Paragraph(
                timezone.localtime().strftime('%b %d, %Y  ·  %I:%M %p'),
                st_report_sub),
        ]]
        title_tbl = Table(title_data, colWidths=[120 * mm, 62 * mm])
        title_tbl.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (0, 0), 0),
            ('RIGHTPADDING', (1, 0), (1, 0), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 5 * mm),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 3 * mm),
        ]))
        story.append(title_tbl)
        story.append(Spacer(1, 4 * mm))

        # ═══════════════════════════════════════════════════════════════
        #  ITEM INFO — card with colored left-accent key column
        # ═══════════════════════════════════════════════════════════════
        story.append(section_bar('Item Details'))
        story.append(Spacer(1, 3 * mm))

        status_text = 'LOW STOCK' if low_stock else 'Healthy'
        status_color = '#EF4444' if low_stock else '#16A34A'

        def kv_row(k1, v1, k2, v2, v2_html=None):
            return [
                Paragraph(k1, st_k),
                Paragraph(v1 or '—', st_v),
                Paragraph(k2, st_k),
                Paragraph(v2_html or (v2 or '—'), st_v),
            ]

        info_rows = [
            kv_row('Item name', stock.medication_name, 'Category',
                   getattr(stock.category, 'name', None)),
            kv_row('Unit', getattr(stock.unit, 'name', None), 'Barcode', stock.barcode),
            kv_row('Branch / Warehouse', getattr(stock.branch, 'name', None),
                   'Store location', stock.location_in_store),
            kv_row('Cost price', money(stock.cost_price), 'Selling price',
                   money(stock.selling_price)),
            [Paragraph('Reorder level', st_k), Paragraph(str(reorder), st_v),
             Paragraph('Status', st_k),
             Paragraph(f'<font color="{status_color}"><b>{"●"}</b></font>  '
                        f'<font color="{status_color}"><b>{status_text}</b></font>', st_v)],
        ]
        info_tbl = Table(info_rows, colWidths=[30 * mm, 61 * mm, 30 * mm, 61 * mm])
        info_tbl.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('TOPPADDING', (0, 0), (-1, -1), 3 * mm),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 3 * mm),
            ('LEFTPADDING', (0, 0), (-1, -1), 4 * mm),
            ('BACKGROUND', (0, 0), (0, -1), BG_CARD),
            ('BACKGROUND', (2, 0), (2, -1), BG_CARD),
            ('LINEBELOW', (0, 0), (-1, -2), 0.3, BORDER_LT),
        ]))
        story.append(info_tbl)
        story.append(Spacer(1, 5 * mm))

        # ═══════════════════════════════════════════════════════════════
        #  KPI CARDS — 4 premium cards with accent borders
        # ═══════════════════════════════════════════════════════════════
        kpi_items = [
            ('ON HAND', str(on_hand), None, GREEN_BG, GREEN),
            ('COMMITTED', str(committed), None, AMBER_BG, AMBER),
            ('AVAILABLE', str(available), None, BLUE_BG, SKY),
            ('STOCK VALUE', money(stock_value), None, PURPLE_BG, INDIGO),
        ]

        def kpi_card(label, value, bg, accent):
            inner = Table(
                [
                    [Paragraph(label, st_kpi_label)],
                    [Paragraph(value, st_kpi_value_m if len(str(value)) > 14 else st_kpi_value_s)],
                ],
                colWidths=[42 * mm],
            )
            inner.setStyle(TableStyle([
                ('TOPPADDING', (0, 0), (-1, -1), 1.5 * mm),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 1.5 * mm),
            ]))
            card = Table([[inner]], colWidths=[42 * mm])
            card.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, -1), bg),
                ('LINEBEFORE', (0, 0), (0, -1), 3, accent),
                ('TOPPADDING', (0, 0), (-1, -1), 5 * mm),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 5 * mm),
            ]))
            return card

        kpi_cards = [kpi_card(lbl, val, bg, ac) for lbl, val, _, bg, ac in kpi_items]
        kpi_row = Table([kpi_cards], colWidths=[45.5 * mm] * 4)
        kpi_row.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ]))
        story.append(kpi_row)
        story.append(Spacer(1, 6 * mm))

        # ═══════════════════════════════════════════════════════════════
        #  BATCHES TABLE
        # ═══════════════════════════════════════════════════════════════
        story.append(section_bar('Batches'))
        story.append(Spacer(1, 3 * mm))
        if batches:
            bt_rows = [[
                Paragraph('#', st_th), Paragraph('Batch #', st_th),
                Paragraph('Received', st_th), Paragraph('Qty In', st_th),
                Paragraph('Remaining', st_th), Paragraph('Cost/Unit', st_th),
                Paragraph('Expiry', st_th), Paragraph('Supplier', st_th),
            ]]
            for i, b in enumerate(batches[:20], 1):
                # Colour-code remaining
                rem = b.quantity_remaining or 0
                rem_html = (f'<font color="#EF4444"><b>{rem}</b></font>' if rem <= 0
                            else str(rem))
                # Colour-code expiry
                exp_display = stamp(b.expiry_date)
                if b.expiry_date:
                    from datetime import datetime as _dtc
                    try:
                        exp_date = _dtc.fromisoformat(str(b.expiry_date)).date()
                        days_left = (exp_date - now.date()).days
                        if days_left < 0:
                            exp_display = f'<font color="#EF4444"><b>{stamp(b.expiry_date)}</b></font>'
                        elif days_left < 90:
                            exp_display = f'<font color="#F59E0B"><b>{stamp(b.expiry_date)}</b></font>'
                    except Exception:
                        pass

                bt_rows.append([
                    Paragraph(str(i), st_cell_c),
                    Paragraph(str(b.batch_number or '—'), st_cell),
                    stamp(b.received_date),
                    str(b.quantity_received or 0),
                    Paragraph(rem_html, st_cell_r),
                    Paragraph(money(b.cost_price_per_unit), st_cell_r),
                    Paragraph(exp_display, st_cell),
                    Paragraph(getattr(b.supplier, 'name', None) or '—', st_cell),
                ])
            bt_tbl = Table(bt_rows, colWidths=[8 * mm, 24 * mm, 22 * mm, 14 * mm,
                                               17 * mm, 22 * mm, 23 * mm, 52 * mm])
            bt_tbl.setStyle(modern_table_style(8, len(bt_rows), right_cols=(3, 4, 5)))
            story.append(bt_tbl)
        else:
            story.append(Paragraph('No batches recorded.', st_empty))
        story.append(Spacer(1, 6 * mm))

        # ═══════════════════════════════════════════════════════════════
        #  RECENT PURCHASES
        # ═══════════════════════════════════════════════════════════════
        if purchases:
            story.append(section_bar('Recent Purchases'))
            story.append(Spacer(1, 3 * mm))
            po_rows = [[
                Paragraph('PO #', st_th), Paragraph('Date', st_th),
                Paragraph('Supplier', st_th), Paragraph('Qty', st_th),
                Paragraph('Unit Cost', st_th),
            ]]
            for p in purchases:
                po_rows.append([
                    Paragraph(p['po_number'], st_cell),
                    stamp(p['date']),
                    Paragraph(p['supplier'] or '—', st_cell),
                    str(p['qty']),
                    Paragraph(money(p['unit_cost']), st_cell_r),
                ])
            po_tbl = Table(po_rows, colWidths=[28 * mm, 28 * mm, 58 * mm, 22 * mm, 46 * mm])
            po_tbl.setStyle(modern_table_style(5, len(po_rows), right_cols=(3, 4)))
            story.append(po_tbl)
            story.append(Spacer(1, 6 * mm))

        # ═══════════════════════════════════════════════════════════════
        #  RECENT SALES
        # ═══════════════════════════════════════════════════════════════
        if recent_sales:
            story.append(section_bar('Recent Sales'))
            story.append(Spacer(1, 3 * mm))
            sa_rows = [[
                Paragraph('Receipt', st_th), Paragraph('Date', st_th),
                Paragraph('Qty', st_th), Paragraph('Unit Price', st_th),
                Paragraph('Total', st_th),
            ]]
            for s in recent_sales:
                sa_rows.append([
                    Paragraph(s['txn'], st_cell),
                    s['date'],
                    str(s['qty']),
                    Paragraph(money(s['price']), st_cell_r),
                    Paragraph(money(s['total']), st_cell_r),
                ])
            sa_tbl = Table(sa_rows, colWidths=[40 * mm, 35 * mm, 25 * mm, 40 * mm, 42 * mm])
            sa_tbl.setStyle(modern_table_style(5, len(sa_rows), right_cols=(2, 3, 4)))
            story.append(sa_tbl)
            story.append(Spacer(1, 6 * mm))

        # ═══════════════════════════════════════════════════════════════
        #  MOVEMENT LEDGER
        # ═══════════════════════════════════════════════════════════════
        if movements:
            story.append(section_bar('Recent Stock Movements'))
            story.append(Spacer(1, 3 * mm))
            mv_rows = [[
                Paragraph('Date', st_th), Paragraph('Reason', st_th),
                Paragraph('Change', st_th), Paragraph('Notes', st_th),
            ]]
            for m in movements:
                chg = m['change']
                color_str = '#16A34A' if chg >= 0 else '#EF4444'
                sign = '+' if chg >= 0 else ''
                mv_rows.append([
                    m['date'],
                    Paragraph(m['reason'], st_cell),
                    Paragraph(f'<font color="{color_str}"><b>{sign}{chg}</b></font>', st_cell_r),
                    Paragraph(m['notes'] or '—', st_cell),
                ])
            mv_tbl = Table(mv_rows, colWidths=[28 * mm, 40 * mm, 22 * mm, 92 * mm])
            mv_tbl.setStyle(modern_table_style(4, len(mv_rows), right_cols=(2,)))
            story.append(mv_tbl)

        # ═══════════════════════════════════════════════════════════════
        #  FOOTER — Powered by AdhereMed
        # ═══════════════════════════════════════════════════════════════
        story.append(Spacer(1, 10 * mm))

        adheremed_logo_path = os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            '..', 'assets', 'logo.png')
        adheremed_logo_path = os.path.normpath(adheremed_logo_path)
        footer_logo = fit_logo(adheremed_logo_path, 10, 35)

        footer_text_block = [
            Paragraph('Powered by', st_foot),
            Paragraph('AdhereMed', st_foot_brand),
            Paragraph('www.adheremed.co', st_foot_link),
        ]

        footer_inner = Table(
            [[footer_logo, footer_text_block]],
            colWidths=[38 * mm, 80 * mm],
        )
        footer_inner.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('ALIGN', (1, 0), (1, 0), 'CENTER'),
            ('LEFTPADDING', (1, 0), (1, 0), 6 * mm),
            ('RIGHTPADDING', (0, 0), (0, 0), 4 * mm),
            ('TOPPADDING', (0, 0), (-1, -1), 3 * mm),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 3 * mm),
        ]))

        footer_wrapper = Table([[footer_inner]], colWidths=[182 * mm])
        footer_wrapper.setStyle(TableStyle([
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LINEABOVE', (0, 0), (-1, 0), 1.5, INDIGO),
            ('TOPPADDING', (0, 0), (-1, -1), 5 * mm),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 3 * mm),
        ]))
        story.append(footer_wrapper)

        story.append(Spacer(1, 3 * mm))
        story.append(Paragraph(
            f'Generated on {timezone.localtime().strftime("%b %d %Y at %I:%M %p")}  ·  '
            f'{org_name}  ·  Confidential',
            st_foot))

        doc.build(story)
        buf.seek(0)

        from django.http import HttpResponse
        resp = HttpResponse(buf.getvalue(), content_type='application/pdf')
        safe_name = (stock.medication_name or 'item').replace(' ', '_').replace('/', '-')
        resp['Content-Disposition'] = f'attachment; filename="stock_report_{safe_name}.pdf"'
        return resp

    # ── Bulk operations ───────────────────────────────────────────────────
    _BULK_EDITABLE_FIELDS = {
        'medication_name', 'category', 'unit',
        'selling_price', 'cost_price', 'discount_percent',
        'reorder_level', 'reorder_quantity',
        'location_in_store', 'barcode',
        'prescription_required', 'is_active',
    }

    @action(detail=False, methods=['post'], url_path='bulk-update')
    def bulk_update(self, request):
        """Update many stock items at once.

        Payload: { "items": [{"id": 1, "selling_price": 12.5, ...}, ...] }
        Only fields in _BULK_EDITABLE_FIELDS are accepted; unknown fields ignored.
        """
        items = request.data.get('items') or []
        if not isinstance(items, list) or not items:
            return Response({'detail': 'items must be a non-empty list.'}, status=400)

        ids = [i.get('id') for i in items if i.get('id')]
        qs = MedicationStock.objects.filter(id__in=ids)
        by_id = {s.id: s for s in qs}

        updated = []
        errors = []
        for payload in items:
            sid = payload.get('id')
            obj = by_id.get(sid)
            if not obj:
                errors.append({'id': sid, 'error': 'not found'})
                continue
            cleaned = {k: v for k, v in payload.items() if k in self._BULK_EDITABLE_FIELDS}

            # Optional inline quantity edit (creates a count-correction adjustment).
            qty_error = None
            if 'set_quantity' in payload and payload['set_quantity'] is not None:
                try:
                    new_qty = int(payload['set_quantity'])
                    if new_qty < 0:
                        raise ValueError('quantity must be ≥ 0')
                    self._apply_quantity_set(obj, new_qty, request.user)
                except (TypeError, ValueError) as exc:
                    qty_error = str(exc) or 'invalid quantity'

            if qty_error:
                errors.append({'id': sid, 'error': {'set_quantity': [qty_error]}})

            if cleaned:
                serializer = self.get_serializer(obj, data=cleaned, partial=True)
                if serializer.is_valid():
                    serializer.save()
                    updated.append(serializer.data)
                else:
                    errors.append({'id': sid, 'error': serializer.errors})
            elif 'set_quantity' in payload and not qty_error:
                updated.append(self.get_serializer(obj).data)

        return Response({'updated': len(updated), 'items': updated, 'errors': errors})

    def _apply_quantity_set(self, stock, new_qty, user):
        """Reconcile total quantity to ``new_qty`` via a StockAdjustment.

        Delegates to :func:`inventory.services.stock.reconcile_quantity` so
        bulk edits follow exactly the same rules as a manual adjustment
        (FEFO drain on decreases, synthetic batch on the first increase).
        """
        try:
            return reconcile_quantity(
                stock, int(new_qty), user=user,
                notes='Bulk edit count correction',
            )
        except InsufficientStock as exc:
            raise ValueError(str(exc))

    @action(detail=False, methods=['post'], url_path='bulk-delete')
    def bulk_delete(self, request):
        """Delete many stock items at once. Payload: { \"ids\": [1,2,3] }

        Gated by the same ``stock.delete`` capability as a single destroy —
        a branch manager (who may edit but not delete) must not be able to
        wipe stock through the bulk endpoint.
        """
        if not has_capability(request, 'stock.delete'):
            return Response(
                {'detail': 'You do not have permission to delete stock items. '
                           'Deactivate the item instead.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        ids = request.data.get('ids') or []
        if not isinstance(ids, list) or not ids:
            return Response({'detail': 'ids must be a non-empty list.'}, status=400)
        # Respect branch scope: a scoped user may only delete their own stock.
        qs = self.get_queryset().filter(id__in=ids)
        allowed_ids = list(qs.values_list('id', flat=True))
        skipped = [i for i in ids if i not in allowed_ids]
        count = len(allowed_ids)
        if allowed_ids:
            MedicationStock.objects.filter(id__in=allowed_ids).delete()
        _audit(
            # NB: AuditEvent.action is varchar(16) — keep these short.
            request, 'stock_bulk_del', str(sorted(allowed_ids)),
            severity='warning',
            description=f'Bulk deleted {count} stock item(s)',
            payload_diff={'ids': allowed_ids, 'skipped': skipped},
        )
        return Response({'deleted': count, 'ids': allowed_ids, 'skipped': skipped})

    @action(detail=False, methods=['get'])
    def expiring_soon(self, request):
        """Batches expiring inside the window — *not yet* expired.

        The previous filter had no lower bound, so already-expired batches were
        listed as "expiring soon" while the dashboard reported them separately.
        """
        days = int(request.query_params.get('days', 30))
        today = timezone.localdate()
        cutoff = today + timedelta(days=days)
        batches = StockBatch.objects.filter(
            expiry_date__gte=today,
            expiry_date__lte=cutoff,
            quantity_remaining__gt=0,
            is_blocked=False,
        ).select_related('stock').order_by('expiry_date')
        branch = request.query_params.get('branch')
        if branch:
            batches = batches.filter(Q(branch_id=branch) | Q(branch__isnull=True))
        serializer = StockBatchSerializer(batches, many=True)
        return Response(serializer.data)

    # ── Export ────────────────────────────────────────────────────────────────
    _EXPORT_HEADERS = [
        'ID', 'Medication Name', 'Brand Name', 'Generic Name', 'Strength', 'Dosage Form',
        'Category', 'Classification', 'Unit', 'Warehouse',
        'Selling Price (KSh)', 'Cost Price (KSh)',
        'Total Quantity', 'Items Per Unit', 'Reorder Level', 'Reorder Quantity',
        'Location', 'Barcode', 'Prescription Required', 'Active',
        'Created At',
    ]

    def _stock_row(self, s):
        return [
            s.id, s.medication_name,
            s.brand_name or '', s.generic_name or '', s.strength or '', s.dosage_form or '',
            s.category.name if s.category else '',
            s.classification.name if s.classification else '',
            s.unit.name if s.unit else '',
            s.branch.name if s.branch else '',
            float(s.selling_price), float(s.cost_price),
            s.total_quantity, s.items_per_unit or '', s.reorder_level, s.reorder_quantity,
            s.location_in_store or '', s.barcode or '',
            s.prescription_required, 'Yes' if s.is_active else 'No',
            s.created_at.strftime('%Y-%m-%d'),
        ]

    @action(detail=False, methods=['get'], url_path='export')
    def export(self, request):
        # NB: use ?fmt= instead of ?format= — DRF reserves the `format`
        # query param for renderer content negotiation.
        fmt = request.query_params.get('fmt', 'csv').lower()
        qs = self.filter_queryset(self.get_queryset())

        if fmt == 'excel':
            try:
                from openpyxl import Workbook
                from openpyxl.styles import Font, PatternFill, Alignment
            except ImportError:
                return Response({'detail': 'openpyxl not installed.'}, status=500)

            wb = Workbook()
            ws = wb.active
            ws.title = 'Inventory'

            header_font = Font(bold=True, color='FFFFFF')
            header_fill = PatternFill(fill_type='solid', fgColor='1565C0')
            for col_idx, header in enumerate(self._EXPORT_HEADERS, 1):
                cell = ws.cell(row=1, column=col_idx, value=header)
                cell.font = header_font
                cell.fill = header_fill
                cell.alignment = Alignment(horizontal='center')

            for row_idx, s in enumerate(qs, 2):
                for col_idx, val in enumerate(self._stock_row(s), 1):
                    ws.cell(row=row_idx, column=col_idx, value=val)

            for col in ws.columns:
                max_len = max((len(str(c.value or '')) for c in col), default=8)
                ws.column_dimensions[col[0].column_letter].width = min(max_len + 4, 40)

            buf = io.BytesIO()
            wb.save(buf)
            buf.seek(0)
            fname = f'inventory_{timezone.now().strftime("%Y%m%d")}.xlsx'
            return HttpResponse(
                buf.read(),
                content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                headers={'Content-Disposition': f'attachment; filename="{fname}"'},
            )

        elif fmt == 'pdf':
            try:
                from reportlab.lib.pagesizes import A4, landscape
                from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
                from reportlab.lib.styles import getSampleStyleSheet
                from reportlab.lib import colors
                from reportlab.lib.units import cm
            except ImportError:
                return Response({'detail': 'reportlab not installed.'}, status=500)

            buf = io.BytesIO()
            doc = SimpleDocTemplate(buf, pagesize=landscape(A4), leftMargin=1*cm, rightMargin=1*cm, topMargin=1*cm, bottomMargin=1*cm)
            styles = getSampleStyleSheet()

            elements = [
                Paragraph('Inventory Report', styles['Title']),
                Paragraph(f'Generated: {timezone.now().strftime("%Y-%m-%d %H:%M")}', styles['Normal']),
                Spacer(1, 0.4*cm),
            ]

            pdf_headers = ['Name', 'Category', 'Unit', 'Sell Price', 'Cost', 'Qty', 'Reorder', 'Location', 'Barcode', 'Rx', 'Active']
            data = [pdf_headers]
            for s in qs:
                data.append([
                    s.medication_name,
                    s.category.name if s.category else '',
                    s.unit.abbreviation if s.unit else '',
                    f'KSh {float(s.selling_price):.2f}',
                    f'KSh {float(s.cost_price):.2f}',
                    str(s.total_quantity),
                    str(s.reorder_level),
                    s.location_in_store or '',
                    s.barcode or '',
                    s.prescription_required,
                    'Yes' if s.is_active else 'No',
                ])

            table = Table(data, repeatRows=1)
            table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1565C0')),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
                ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 0), (-1, -1), 7),
                ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#F5F5F5')]),
                ('GRID', (0, 0), (-1, -1), 0.3, colors.HexColor('#CCCCCC')),
                ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LEFTPADDING', (0, 0), (-1, -1), 4),
                ('RIGHTPADDING', (0, 0), (-1, -1), 4),
                ('TOPPADDING', (0, 0), (-1, -1), 3),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
            ]))
            elements.append(table)
            doc.build(elements)
            buf.seek(0)
            fname = f'inventory_{timezone.now().strftime("%Y%m%d")}.pdf'
            return HttpResponse(
                buf.read(),
                content_type='application/pdf',
                headers={'Content-Disposition': f'attachment; filename="{fname}"'},
            )

        else:
            # Default: CSV
            fname = f'inventory_{timezone.now().strftime("%Y%m%d")}.csv'
            response = HttpResponse(content_type='text/csv')
            response['Content-Disposition'] = f'attachment; filename="{fname}"'
            writer = csv.writer(response)
            writer.writerow(self._EXPORT_HEADERS)
            for s in qs:
                writer.writerow(self._stock_row(s))
            return response

    # ── Import ────────────────────────────────────────────────────────────────
    @action(detail=False, methods=['post'], url_path='import')
    def import_stocks(self, request):
        uploaded = request.FILES.get('file')
        if not uploaded:
            return Response({'detail': 'No file provided.'}, status=status.HTTP_400_BAD_REQUEST)

        filename = uploaded.name.lower()
        created = updated = errors = 0
        error_details = []
        forced_branch = _forced_branch_id(request.user)

        def _process_row(row_num, name, branch_name, category_name, selling_price_str, cost_price_str, reorder_level_str, reorder_qty_str, location, barcode, prescription):
            nonlocal created, updated, errors
            name = (name or '').strip()
            if not name:
                errors += 1
                error_details.append(f'Row {row_num}: medication name is required.')
                return
            try:
                selling_price = float(selling_price_str or 0)
                cost_price = float(cost_price_str or 0)
                reorder_level = int(float(reorder_level_str or 10))
                reorder_qty = int(float(reorder_qty_str or 20))
            except (ValueError, TypeError):
                errors += 1
                error_details.append(f'Row {row_num}: invalid numeric value.')
                return

            category = None
            if category_name and category_name.strip():
                category, _ = Category.objects.get_or_create(name=category_name.strip())

            # Resolve branch warehouse by name (case-insensitive)
            branch_obj = None
            if branch_name and str(branch_name).strip():
                branch_obj = Branch.objects.filter(name__iexact=str(branch_name).strip()).first()

            # A branch-scoped user may only import into their own warehouse.
            if forced_branch:
                if branch_obj and branch_obj.id != forced_branch:
                    errors += 1
                    error_details.append(
                        f'Row {row_num}: you can only import into your own warehouse.')
                    return
                if not branch_obj:
                    branch_obj = Branch.objects.filter(id=forced_branch).first()

            valid_rx = {'none', 'recommended', 'required'}
            rx = (prescription or 'none').strip().lower()
            if rx not in valid_rx:
                rx = 'none'

            stock, was_created = MedicationStock.objects.update_or_create(
                medication_name=name,
                branch=branch_obj,
                defaults=dict(
                    category=category,
                    selling_price=selling_price,
                    cost_price=cost_price,
                    reorder_level=reorder_level,
                    reorder_quantity=reorder_qty,
                    location_in_store=(location or '').strip() or None,
                    barcode=(barcode or '').strip() or None,
                    prescription_required=rx,
                ),
            )
            if was_created:
                created += 1
            else:
                updated += 1

        if filename.endswith('.csv'):
            try:
                text = uploaded.read().decode('utf-8-sig')
                reader = csv.DictReader(io.StringIO(text))
                for i, row in enumerate(reader, 2):
                    _process_row(
                        i,
                        row.get('Medication Name') or row.get('medication_name', ''),
                        row.get('Branch') or row.get('Branch (Warehouse)') or row.get('branch', ''),
                        row.get('Category') or row.get('category', ''),
                        row.get('Selling Price (KSh)') or row.get('selling_price', ''),
                        row.get('Cost Price (KSh)') or row.get('cost_price', ''),
                        row.get('Reorder Level') or row.get('reorder_level', ''),
                        row.get('Reorder Quantity') or row.get('reorder_quantity', ''),
                        row.get('Location') or row.get('location', ''),
                        row.get('Barcode') or row.get('barcode', ''),
                        row.get('Prescription Required') or row.get('prescription_required', ''),
                    )
            except Exception as e:
                return Response({'detail': f'CSV parse error: {e}'}, status=status.HTTP_400_BAD_REQUEST)

        elif filename.endswith(('.xlsx', '.xls')):
            try:
                from openpyxl import load_workbook
            except ImportError:
                return Response({'detail': 'openpyxl not installed.'}, status=500)
            try:
                wb = load_workbook(io.BytesIO(uploaded.read()), read_only=True, data_only=True)
                ws = wb.active
                rows = list(ws.iter_rows(values_only=True))
                if not rows:
                    return Response({'detail': 'Empty spreadsheet.'}, status=status.HTTP_400_BAD_REQUEST)
                headers = [str(h).strip() if h else '' for h in rows[0]]
                col = {h: i for i, h in enumerate(headers)}

                def _get(row, key, fallback=''):
                    idx = col.get(key)
                    return str(row[idx] or '') if idx is not None and idx < len(row) else fallback

                for i, row in enumerate(rows[1:], 2):
                    _process_row(
                        i,
                        _get(row, 'Medication Name') or _get(row, 'medication_name'),
                        _get(row, 'Branch (Warehouse)') or _get(row, 'Branch') or _get(row, 'branch'),
                        _get(row, 'Category') or _get(row, 'category'),
                        _get(row, 'Selling Price (KSh)') or _get(row, 'selling_price'),
                        _get(row, 'Cost Price (KSh)') or _get(row, 'cost_price'),
                        _get(row, 'Reorder Level') or _get(row, 'reorder_level'),
                        _get(row, 'Reorder Quantity') or _get(row, 'reorder_quantity'),
                        _get(row, 'Location') or _get(row, 'location'),
                        _get(row, 'Barcode') or _get(row, 'barcode'),
                        _get(row, 'Prescription Required') or _get(row, 'prescription_required'),
                    )
            except Exception as e:
                return Response({'detail': f'Excel parse error: {e}'}, status=status.HTTP_400_BAD_REQUEST)
        else:
            return Response({'detail': 'Unsupported file type. Use .csv or .xlsx'}, status=status.HTTP_400_BAD_REQUEST)

        return Response({
            'created': created,
            'updated': updated,
            'errors': errors,
            'error_details': error_details[:20],
        })

    # ── Excel import/export (template, review, commit) ────────────────────────
    _IMPORT_COLUMNS = {
        'medication_name': ['Medication Name', 'medication_name', 'name'],
        'brand_name': ['Brand Name', 'brand_name', 'brand'],
        'generic_name': ['Generic Name', 'generic_name', 'generic'],
        'strength': ['Strength', 'strength'],
        'dosage_form': ['Dosage Form', 'dosage_form', 'form'],
        'branch': ['Branch (Warehouse)', 'Branch', 'Warehouse', 'branch', 'warehouse'],
        'category': ['Category', 'category'],
        'classification': ['Classification', 'classification'],
        'unit': ['Unit', 'unit'],
        'selling_price': ['Selling Price (KSh)', 'selling_price', 'Selling Price'],
        'cost_price': ['Cost Price (KSh)', 'cost_price', 'Cost Price'],
        'discount_percent': ['Discount %', 'discount_percent'],
        'tax_percent': ['Tax %', 'tax_percent'],
        'total_quantity': ['Total Quantity', 'total_quantity'],
        'items_per_unit': ['Items Per Unit', 'items_per_unit'],
        'reorder_level': ['Reorder Level', 'reorder_level'],
        'reorder_quantity': ['Reorder Quantity', 'reorder_quantity'],
        'location_in_store': ['Location', 'location_in_store', 'location'],
        'barcode': ['Barcode', 'barcode'],
        'prescription_required': ['Prescription Required', 'prescription_required'],
        'is_active': ['Active', 'is_active', 'active'],
    }

    def _normalize_import_rows(self, uploaded):
        """Parse an uploaded .xlsx/.csv into (row_num, {field: raw_value}) pairs."""
        filename = (uploaded.name or '').lower()
        if filename.endswith('.csv'):
            text = uploaded.read().decode('utf-8-sig')
            rows = [r for r in csv.reader(io.StringIO(text))]
        elif filename.endswith('.xlsx'):
            try:
                from openpyxl import load_workbook
                wb = load_workbook(io.BytesIO(uploaded.read()), read_only=True, data_only=True)
                ws = wb.active
                rows = [list(r) for r in ws.iter_rows(values_only=True)]
            except Exception:
                raise ValueError('Could not read the spreadsheet. Save it as .xlsx or .csv and try again.')
        else:
            raise ValueError('Unsupported file type. Use .xlsx or .csv')

        if not rows:
            raise ValueError('The file is empty.')
        headers = [str(h).strip() if h is not None else '' for h in rows[0]]
        col = {h: i for i, h in enumerate(headers)}
        if 'Medication Name' not in col and 'medication_name' not in col and 'name' not in col:
            raise ValueError('Missing the "Medication Name" column. Use the import template.')

        def get(row, aliases):
            for a in aliases:
                idx = col.get(a)
                if idx is not None and idx < len(row):
                    v = row[idx]
                    if v is not None and str(v).strip() != '':
                        return v
            return None

        parsed = []
        for num, row in enumerate(rows[1:], 2):
            if not row or all(v is None or str(v).strip() == '' for v in row):
                continue
            parsed.append((num, {f: get(row, aliases)
                                 for f, aliases in self._IMPORT_COLUMNS.items()}))
        return parsed

    def _clean_import_row(self, raw):
        """Validate one raw import row. Returns (cleaned, errors)."""
        cleaned, errors = {}, {}
        name = str(raw.get('medication_name') or '').strip()
        if not name:
            errors['medication_name'] = 'Required'
        cleaned['medication_name'] = name

        for f in ('selling_price', 'cost_price'):
            v = raw.get(f)
            if v in (None, ''):
                cleaned[f] = None
                continue
            try:
                n = float(v)
                if n < 0:
                    raise ValueError
                cleaned[f] = n
            except (TypeError, ValueError):
                cleaned[f] = str(v)
                errors[f] = 'Must be a number ≥ 0'

        for f in ('discount_percent', 'tax_percent'):
            v = raw.get(f)
            if v in (None, ''):
                cleaned[f] = None
                continue
            try:
                n = float(v)
                if not 0 <= n <= 100:
                    raise ValueError
                cleaned[f] = n
            except (TypeError, ValueError):
                cleaned[f] = str(v)
                errors[f] = 'Must be 0 – 100'

        for f in ('total_quantity', 'items_per_unit', 'reorder_level', 'reorder_quantity'):
            v = raw.get(f)
            if f not in ('total_quantity', 'items_per_unit') and v in (None, ''):
                continue
            if f in ('total_quantity', 'items_per_unit') and v in (None, ''):
                cleaned[f] = None
                continue
            try:
                n = int(float(v))
                if n < 0:
                    raise ValueError
                cleaned[f] = n
            except (TypeError, ValueError):
                cleaned[f] = str(v)
                errors[f] = 'Must be a whole number ≥ 0'

        rx = str(raw.get('prescription_required') or '').strip().lower()
        if rx and rx not in ('none', 'recommended', 'required'):
            errors['prescription_required'] = 'Must be none, recommended or required'
        cleaned['prescription_required'] = rx or None

        act = raw.get('is_active')
        if act in (None, ''):
            cleaned['is_active'] = None
        else:
            s = str(act).strip().lower()
            if s in ('yes', 'true', '1', 'no', 'false', '0'):
                cleaned['is_active'] = 'Yes' if s in ('yes', 'true', '1') else 'No'
            else:
                cleaned['is_active'] = str(act)
                errors['is_active'] = 'Must be Yes or No'

        for f in ('category', 'unit', 'classification', 'location_in_store', 'barcode',
                  'brand_name', 'generic_name', 'strength', 'dosage_form'):
            v = raw.get(f)
            cleaned[f] = str(v).strip() if v not in (None, '') else None

        # Branch / warehouse — required for new items, must match an
        # existing warehouse by name (case-insensitive).
        branch_name = str(raw.get('branch') or '').strip()
        if branch_name:
            match = (Branch.objects
                     .filter(name__iexact=branch_name)
                     .values_list('id', flat=True).first())
            if match is None:
                errors['branch'] = (
                    f'Unknown warehouse "{branch_name}" — use one of: '
                    + ', '.join(Branch.objects.filter(is_active=True)
                               .values_list('name', flat=True)[:10])
                )
            cleaned['branch'] = match if match is not None else branch_name
        else:
            cleaned['branch'] = None
        return cleaned, errors

    @action(detail=False, methods=['get'], url_path='import-template')
    def import_template(self, request):
        """Styled .xlsx import template with example row, dropdowns & instructions."""
        try:
            from openpyxl import Workbook
            from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
            from openpyxl.worksheet.datavalidation import DataValidation
            from openpyxl.utils import get_column_letter
        except ImportError:
            return Response({'detail': 'openpyxl not installed.'}, status=500)

        HEADERS = [
            ('Medication Name', 32, 'required'),
            ('Brand Name', 22, 'brand / trade name'),
            ('Generic Name', 22, 'generic / INN name'),
            ('Strength', 16, 'e.g. 500mg'),
            ('Dosage Form', 16, 'tablet / capsule / syrup…'),
            ('Branch (Warehouse)', 22, 'required for new items'),
            ('Category', 20, 'auto-created if missing'),
            ('Classification', 20, 'auto-created if missing'),
            ('Unit', 14, 'auto-created if missing'),
            ('Selling Price (KSh)', 18, 'number'),
            ('Cost Price (KSh)', 18, 'number'),
            ('Discount %', 12, '0 – 100'),
            ('Tax %', 12, '0 – 100'),
            ('Total Quantity', 16, 'blank = keep current stock'),
            ('Items Per Unit', 16, 'items inside one box/pack/strip'),
            ('Reorder Level', 15, 'whole number'),
            ('Reorder Quantity', 16, 'whole number'),
            ('Location', 18, 'free text'),
            ('Barcode', 18, 'free text'),
            ('Prescription Required', 22, 'none / recommended / required'),
            ('Active', 10, 'Yes / No'),
        ]
        main_branch = (Branch.objects.filter(is_main=True).first()
                       or Branch.objects.filter(is_active=True).first())
        example_branch = main_branch.name if main_branch else ''
        EXAMPLE = ['Paracetamol 500mg', 'Panadol', 'paracetamol', '500mg', 'tablet',
                   example_branch, 'Analgesics', 'Routine', 'tablets', 25.00, 15.00,
                    0, 16, 500, 24, 10, 50, 'Shelf A2', '890123456789', 'none', 'Yes']

        wb = Workbook()
        ws = wb.active
        ws.title = 'Inventory'

        header_font = Font(bold=True, color='FFFFFF', size=11)
        header_fill = PatternFill(fill_type='solid', fgColor='0EA5E9')
        thin = Side(style='thin', color='E2E8F0')
        border = Border(left=thin, right=thin, top=thin, bottom=thin)

        for c, (title, width, _) in enumerate(HEADERS, 1):
            cell = ws.cell(row=1, column=c, value=title)
            cell.font = header_font
            cell.fill = header_fill
            cell.alignment = Alignment(horizontal='center', vertical='center')
            cell.border = border
            ws.column_dimensions[get_column_letter(c)].width = width
        ws.row_dimensions[1].height = 24
        ws.freeze_panes = 'A2'

        for c, val in enumerate(EXAMPLE, 1):
            cell = ws.cell(row=2, column=c, value=val)
            cell.font = Font(italic=True, color='64748B')
            cell.border = border

        # Warehouse dropdown for the Branch column (best effort — Excel
        # formula lists are limited to 255 chars).
        branch_list = ','.join(
            Branch.objects.filter(is_active=True)
            .values_list('name', flat=True)[:20])
        if branch_list and len(branch_list) <= 250:
            dv_br = DataValidation(type='list', formula1=f'"{branch_list}"',
                                   allow_blank=True, showDropDown=False)
            dv_br.error = 'Pick one of the warehouses from the list'
            ws.add_data_validation(dv_br)
            dv_br.add('B3:B1000')

        # Classification dropdown (best effort)
        class_list = ','.join(
            Classification.objects.filter(is_active=True)
            .values_list('name', flat=True)[:20])
        if class_list and len(class_list) <= 250:
            dv_cl = DataValidation(type='list', formula1=f'"{class_list}"',
                                   allow_blank=True, showDropDown=False)
            dv_cl.error = 'Pick or type a classification (auto-created if new)'
            ws.add_data_validation(dv_cl)
            dv_cl.add('D3:D1000')

        dv_rx = DataValidation(type='list', formula1='"none,recommended,required"',
                               allow_blank=True, showDropDown=False)
        dv_rx.error = 'Must be none, recommended or required'
        ws.add_data_validation(dv_rx)
        dv_rx.add('P3:P1000')
        dv_act = DataValidation(type='list', formula1='"Yes,No"',
                                allow_blank=True, showDropDown=False)
        dv_act.error = 'Must be Yes or No'
        ws.add_data_validation(dv_act)
        dv_act.add('Q3:Q1000')

        ins = wb.create_sheet('Instructions')
        ins.column_dimensions['A'].width = 6
        ins.column_dimensions['B'].width = 96
        title_cell = ins.cell(row=1, column=2, value='AdhereMed · Inventory Excel Import')
        title_cell.font = Font(bold=True, size=14, color='0F172A')
        lines = [
            '',
            'HOW TO USE',
            '1. Fill one row per medication in the "Inventory" sheet (or edit an exported file).',
            '2. "Medication Name" is required — rows without a name are skipped.',
            '3. "Branch (Warehouse)" is required for new items — match an existing warehouse name. Existing items keep their warehouse when blank.',
            '4. Existing medications are matched by name AND warehouse (case-insensitive). The same item can exist in multiple warehouses — uploading the same name with a different warehouse creates a new entry.',
            '5. "Total Quantity" is optional — leave blank to keep current stock. A value creates a count-correction adjustment.',
            '6. "Items Per Unit" — when the unit is a box/pack/strip etc, enter how many individual items are inside one unit.',
            '7. Blank cells keep existing values on update; defaults apply to new items.',
            '8. Category, Classification and Unit are created automatically if they do not exist.',
            '9. Supported formats: .xlsx and .csv',
            '',
            'REVIEW WORKFLOW',
            '· Upload the file on the Excel Import / Export page.',
            '· Every row is checked and shown in a review table where you can edit or remove rows.',
            '· Only when you press "Submit import" is anything saved.',
        ]
        for i, line in enumerate(lines, 3):
            cell = ins.cell(row=i, column=2, value=line)
            if line.isupper():
                cell.font = Font(bold=True, size=11, color='0EA5E9')
            else:
                cell.font = Font(size=10, color='334155')

        buf = io.BytesIO()
        wb.save(buf)
        buf.seek(0)
        fname = f'inventory_import_template_{timezone.now():%Y%m%d}.xlsx'
        return HttpResponse(
            buf.read(),
            content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            headers={'Content-Disposition': f'attachment; filename="{fname}"'},
        )

    @action(detail=False, methods=['post'], url_path='import-preview')
    def import_preview(self, request):
        """Parse an uploaded spreadsheet and return the rows for review.

        Nothing is saved. The response rows can be edited on the client and
        submitted to import-commit.
        """
        uploaded = request.FILES.get('file')
        if not uploaded:
            return Response({'detail': 'No file provided.'}, status=400)
        try:
            parsed = self._normalize_import_rows(uploaded)
        except ValueError as exc:
            return Response({'detail': str(exc)}, status=400)

        existing = {
            (s.medication_name.lower(), s.branch_id): {'id': s.id, 'quantity': int(s.qty or 0)}
            for s in (MedicationStock.objects
                      .annotate(qty=Coalesce(Sum('batches__quantity_remaining',
                                                  filter=Q(batches__quantity_remaining__gt=0)), 0))
                      .only('id', 'medication_name', 'branch_id'))
        }
        branch_names = {b.id: b.name for b in Branch.objects.filter(is_active=True)}

        rows, seen = [], {}
        counts = {'new': 0, 'update': 0, 'error': 0}
        for num, raw in parsed:
            cleaned, errors = self._clean_import_row(raw)
            branch_id = cleaned['branch'] if isinstance(cleaned['branch'], int) else None
            key = (cleaned['medication_name'].lower(), branch_id)
            if cleaned['medication_name'] and key in seen:
                errors['medication_name'] = f'Duplicate of row {seen[key]}'
            elif cleaned['medication_name']:
                seen[key] = num
            ex = existing.get(key) if cleaned['medication_name'] else None
            # Branch is compulsory for new items; existing items keep their
            # current warehouse when the cell is blank.
            if not ex and not cleaned['branch']:
                errors['branch'] = 'Required - pick a warehouse'
            status_ = 'error' if errors else ('update' if ex else 'new')
            counts[status_] += 1
            rows.append({
                'row_num': num,
                **{k: v for k, v in cleaned.items() if k != 'branch'},
                'branch': branch_names.get(branch_id, None),
                'is_active': cleaned['is_active'] or ('Yes' if status_ == 'new' else None),
                'prescription_required': cleaned['prescription_required'] or ('none' if status_ == 'new' else None),
                'status': status_,
                'existing_id': ex['id'] if ex else None,
                'existing_quantity': ex['quantity'] if ex else None,
                'errors': errors,
            })
        return Response({
            'rows': rows,
            'summary': {
                'total': len(rows),
                'new': counts['new'],
                'update': counts['update'],
                'error': counts['error'],
            },
        })

    @action(detail=False, methods=['post'], url_path='import-commit')
    def import_commit(self, request):
        """Apply reviewed (and possibly edited) import rows.

        Payload: { "items": [{medication_name, category, unit, selling_price, ...}, ...] }
        Blank optional fields keep existing values on update; defaults on create.
        """
        items = request.data.get('items')
        if not isinstance(items, list) or not items:
            return Response({'detail': 'items must be a non-empty list.'}, status=400)

        forced_branch = _forced_branch_id(request.user)
        created = updated = failed = 0
        results = []
        for idx, item in enumerate(items, 1):
            row_label = item.get('row_num') or idx
            name = str(item.get('medication_name') or '').strip()
            try:
                if not name:
                    raise ValueError('Medication name is required')

                # Resolve branch FIRST so we can match stock by (name, branch)
                branch_val = item.get('branch')
                branch = None
                if branch_val not in (None, ''):
                    if isinstance(branch_val, int) or (isinstance(branch_val, str) and branch_val.isdigit()):
                        branch = Branch.objects.filter(id=int(branch_val)).first()
                    if branch is None:
                        branch = (Branch.objects
                                  .filter(name__iexact=str(branch_val).strip())
                                  .first())
                    if branch is None:
                        raise ValueError(f'Unknown warehouse "{branch_val}"')

                # A branch-scoped user may only import into their own warehouse.
                if forced_branch:
                    if branch and branch.id != forced_branch:
                        raise ValueError(
                            'You can only import into your assigned warehouse.')
                    if branch is None:
                        branch = Branch.objects.filter(id=forced_branch).first()

                # Match existing stock by (name, branch) — allows same item in multiple branches
                if branch:
                    stock = MedicationStock.objects.filter(medication_name__iexact=name, branch=branch).first()
                else:
                    stock = MedicationStock.objects.filter(medication_name__iexact=name).first()
                is_new = stock is None
                if is_new:
                    stock = MedicationStock(medication_name=name)
                if branch:
                    stock.branch = branch
                elif is_new:
                    raise ValueError('Branch (warehouse) is required for new items')

                if item.get('category'):
                    stock.category, _ = Category.objects.get_or_create(
                        name=str(item['category']).strip())
                if item.get('classification'):
                    stock.classification, _ = Classification.objects.get_or_create(
                        name=str(item['classification']).strip())
                if item.get('unit'):
                    stock.unit, _ = Unit.objects.get_or_create(name=str(item['unit']).strip())

                for f, default in (('selling_price', 0), ('cost_price', 0),
                                   ('discount_percent', 0), ('tax_percent', 0)):
                    v = item.get(f)
                    if v not in (None, ''):
                        setattr(stock, f, float(v))
                    elif is_new:
                        setattr(stock, f, default)

                for f, default in (('reorder_level', 10), ('reorder_quantity', 20)):
                    v = item.get(f)
                    if v not in (None, ''):
                        setattr(stock, f, int(float(v)))
                    elif is_new:
                        setattr(stock, f, default)

                ipu = item.get('items_per_unit')
                if ipu not in (None, ''):
                    stock.items_per_unit = int(float(ipu))
                elif is_new:
                    stock.items_per_unit = 0

                for f in ('location_in_store', 'barcode',
                          'brand_name', 'generic_name', 'strength', 'dosage_form'):
                    v = item.get(f)
                    if v not in (None, ''):
                        setattr(stock, f, str(v).strip())

                rx = str(item.get('prescription_required') or '').strip().lower()
                if rx in ('none', 'recommended', 'required'):
                    stock.prescription_required = rx
                elif is_new:
                    stock.prescription_required = 'none'

                act = item.get('is_active')
                if act not in (None, ''):
                    if isinstance(act, str):
                        stock.is_active = act.strip().lower() in ('yes', 'true', '1')
                    else:
                        stock.is_active = bool(act)

                stock.save()

                tq = item.get('total_quantity')
                if tq not in (None, ''):
                    self._apply_quantity_set(stock, int(float(tq)), request.user)

                if is_new:
                    created += 1
                else:
                    updated += 1
                results.append({'row': row_label, 'name': name, 'status': 'created' if is_new else 'updated'})
            except Exception as exc:
                failed += 1
                msg = getattr(exc, 'message', '') or str(exc)
                results.append({'row': row_label, 'name': name or '(no name)',
                                'status': 'error', 'error': msg})

        _audit(
            request, 'stock_import', 'import',
            description=f'Excel import: {created} created, {updated} updated, {failed} failed',
            payload_diff={'created': created, 'updated': updated, 'failed': failed,
                          'rows': len(items)},
        )
        return Response({'created': created, 'updated': updated,
                         'failed': failed, 'results': results})


class StockBatchViewSet(viewsets.ModelViewSet):
    queryset = StockBatch.objects.select_related('stock', 'supplier', 'branch').all()
    serializer_class = StockBatchSerializer
    permission_classes = [InventoryPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['stock', 'expiry_date', 'branch']
    search_fields = ['batch_number', 'stock__medication_name', 'stock__barcode']
    ordering_fields = ['expiry_date', 'received_date', 'quantity_remaining']

    def get_queryset(self):
        """Batch lookups used by the stock-transfer wizard.

        Extra query params beyond the standard filterset:
          ?branch=<id>   batches pinned to that warehouse (plus unassigned)
          ?in_stock=1    only batches with remaining quantity
        """
        qs = super().get_queryset()
        branch = self.request.query_params.get('branch')
        if branch:
            qs = qs.filter(Q(branch_id=branch) | Q(branch__isnull=True))
        if self.request.query_params.get('in_stock') in ('1', 'true', 'True'):
            qs = qs.filter(quantity_remaining__gt=0)
        return qs


class StockAdjustmentViewSet(viewsets.ModelViewSet):
    queryset = StockAdjustment.objects.select_related('stock', 'batch', 'adjusted_by').all()
    serializer_class = StockAdjustmentSerializer
    permission_classes = [AdjustmentPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['stock', 'reason', 'stock__branch']
    search_fields = ['stock__medication_name', 'notes']
    ordering_fields = ['created_at']

    def get_queryset(self):
        qs = super().get_queryset()
        forced = _forced_branch_id(self.request.user)
        if forced:
            qs = qs.filter(Q(stock__branch_id=forced) | Q(stock__branch__isnull=True))
        return qs

    def perform_create(self, serializer):
        """Reject adjustments against stock outside the user's warehouse."""
        stock = serializer.validated_data.get('stock')
        error = _require_branch(self.request, stock.branch_id if stock else None)
        if error:
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied(error)
        qty_before = stock.total_quantity if stock else 0
        adjustment = serializer.save(adjusted_by=self.request.user)

        # A damage/expiry write-off above the tenant threshold needs a second
        # signature — open the approval request here so the valuation screen
        # is never empty just because nobody remembered to raise it.
        try:
            from ..services import quality as quality_service
            if quality_service.needs_approval(adjustment):
                quality_service.request_writeoff(adjustment,
                                                 user=self.request.user)
        except Exception:  # never block the adjustment on the approval flow
            logger.exception('could not open a write-off request')

        _audit(
            self.request, 'stock_adjust', adjustment,
            description=(f'{adjustment.get_reason_display()} ' if adjustment.reason else '')
                        + f'{adjustment.quantity_change:+d} × {stock.medication_name}',
            payload_diff={
                'stock_id': adjustment.stock_id,
                'batch_id': adjustment.batch_id,
                'quantity_change': adjustment.quantity_change,
                'quantity_before': qty_before,
                'quantity_after': stock.total_quantity,
                'reason': adjustment.reason,
            },
        )
