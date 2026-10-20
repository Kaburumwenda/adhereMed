from rest_framework import viewsets, filters, status, serializers
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated, SAFE_METHODS
from django_filters.rest_framework import DjangoFilterBackend
from django.db.models import Sum, Count, Max, F, DecimalField, Q
from django.db.models.functions import Coalesce
from django.utils import timezone
from django.http import HttpResponse
from datetime import timedelta
import csv
import io
import logging
import os

logger = logging.getLogger(__name__)

from .models import (
    Category, Unit, Classification, MedicationStock, StockBatch, StockAdjustment,
    InventoryCount, InventoryCountLine,
    StockTransfer, StockTransferLine,
    ControlledSubstanceLog,
)
from .serializers import (
    CategorySerializer, UnitSerializer, ClassificationSerializer,
    MedicationStockSerializer, StockBatchSerializer, StockAdjustmentSerializer,
    InventoryCountSerializer, InventoryCountLineSerializer,
    StockTransferSerializer,
    ControlledSubstanceLogSerializer,
)
from config.branch_scope import (
    BranchScopedMixin, get_user_branch, is_branch_scoped_user,
)
from pharmacy_profile.models import Branch
from .models import RoleDefinition
from .rbac import (
    InventoryPermission, AdjustmentPermission, StockTakePermission,
    TransferPermission, ControlledRegisterPermission, TenantAdminOnly,
    has_capability, can_view_cost,
    ROLE_META, ALL_CAP_KEYS, CAPABILITY_LABELS,
    ASSIGNABLE_ROLES, RESERVED_ROLE_KEYS, capability_matrix,
    BUILTIN_ROLE_CAPS, EDITABLE_BUILTIN_ROLES, PROTECTED_BUILTIN_CAPS,
    PHARMACY_ROLE_META, PHARMACY_ASSIGNABLE_ROLES, PHARMACY_EDITABLE_BUILTIN_ROLES,
    _role_caps,
)


def _tenant_type(request):
    """Return the current tenant type ('pharmacy', 'inventory', ...) or None."""
    tenant = getattr(request, 'tenant', None) or getattr(request.user, 'tenant', None)
    return getattr(tenant, 'type', None)


def _is_pharmacy(request):
    return _tenant_type(request) == 'pharmacy'


def _role_meta_for(request):
    """Built-in role list for the current tenant type."""
    return PHARMACY_ROLE_META if _is_pharmacy(request) else ROLE_META


def _assignable_roles_for(request):
    """Operational roles assignable from the Roles & Access page."""
    if _is_pharmacy(request):
        return PHARMACY_ASSIGNABLE_ROLES
    return ASSIGNABLE_ROLES


def _editable_builtin_roles_for(request):
    """Built-in roles whose capabilities the tenant may customize."""
    if _is_pharmacy(request):
        return PHARMACY_EDITABLE_BUILTIN_ROLES
    return EDITABLE_BUILTIN_ROLES


class CategoryViewSet(viewsets.ModelViewSet):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
    permission_classes = [InventoryPermission]
    pagination_class = None
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name']
    ordering_fields = ['name', 'created_at']


class UnitViewSet(viewsets.ModelViewSet):
    queryset = Unit.objects.all()
    serializer_class = UnitSerializer
    permission_classes = [InventoryPermission]
    pagination_class = None
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name', 'abbreviation']
    ordering_fields = ['name', 'created_at']


class ClassificationViewSet(viewsets.ModelViewSet):
    """Manage stock-item classifications (Routine, Emergency, Cold Chain,
    Controlled, …). Tenant-scoped lookup table seeded with "Routine" on
    first use."""
    serializer_class = ClassificationSerializer
    permission_classes = [InventoryPermission]
    pagination_class = None
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name', 'description']
    ordering_fields = ['name', 'created_at']

    def get_queryset(self):
        return Classification.objects.annotate(
            stock_count=Count('stocks'),
        ).order_by('name')


class MedicationStockViewSet(BranchScopedMixin, viewsets.ModelViewSet):
    queryset = MedicationStock.objects.select_related('category', 'unit', 'branch').prefetch_related('batches').all()
    serializer_class = MedicationStockSerializer
    permission_classes = [InventoryPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['is_active', 'category', 'unit', 'classification', 'branch']
    search_fields = ['medication_name', 'abbreviation', 'barcode']
    ordering_fields = ['medication_name', 'selling_price', 'created_at']

    def get_queryset(self):
        qs = super().get_queryset()
        # ?branch= filtering: items with no warehouse assigned (branch=NULL)
        # are shared stock and stay visible in every warehouse view — the same
        # convention BranchScopedMixin uses. (Handled here instead of the DRF
        # filterset, which would filter with strict equality and hide them.)
        branch = self.request.query_params.get('branch')
        if branch:
            qs = qs.filter(Q(branch_id=branch) | Q(branch__isnull=True))
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

        for adj in (StockAdjustment.objects.filter(stock=stock)
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

        For increases without any existing batch, a synthetic batch is created
        (1-year expiry). For decreases, batches are drained FEFO.
        """
        from datetime import date, timedelta as _td
        current = stock.total_quantity
        delta = new_qty - current
        if delta == 0:
            return
        if delta > 0:
            batch = stock.batches.filter(quantity_remaining__gt=0).order_by('-expiry_date').first()
            if batch is None:
                batch = stock.batches.order_by('-expiry_date').first()
            if batch is None:
                batch = StockBatch.objects.create(
                    stock=stock,
                    batch_number=f'ADJ-{stock.pk}-{date.today():%Y%m%d}',
                    quantity_received=delta,
                    quantity_remaining=0,
                    cost_price_per_unit=stock.cost_price or 0,
                    expiry_date=date.today() + _td(days=365),
                )
            StockAdjustment.objects.create(
                stock=stock, batch=batch, quantity_change=delta,
                reason=StockAdjustment.Reason.COUNT_CORRECTION,
                notes='Bulk edit count correction',
                adjusted_by=user if user.is_authenticated else None,
            )
            batch.quantity_remaining = batch.quantity_remaining + delta
            batch.save(update_fields=['quantity_remaining'])
        else:
            remaining = -delta
            for batch in stock.batches.filter(quantity_remaining__gt=0).order_by('expiry_date'):
                if remaining <= 0:
                    break
                take = min(batch.quantity_remaining, remaining)
                StockAdjustment.objects.create(
                    stock=stock, batch=batch, quantity_change=-take,
                    reason=StockAdjustment.Reason.COUNT_CORRECTION,
                    notes='Bulk edit count correction',
                    adjusted_by=user if user.is_authenticated else None,
                )
                batch.quantity_remaining -= take
                batch.save(update_fields=['quantity_remaining'])
                remaining -= take

    @action(detail=False, methods=['post'], url_path='bulk-delete')
    def bulk_delete(self, request):
        """Delete many stock items at once. Payload: { \"ids\": [1,2,3] }"""
        ids = request.data.get('ids') or []
        if not isinstance(ids, list) or not ids:
            return Response({'detail': 'ids must be a non-empty list.'}, status=400)
        qs = MedicationStock.objects.filter(id__in=ids)
        count = qs.count()
        qs.delete()
        return Response({'deleted': count, 'ids': ids})

    @action(detail=False, methods=['get'])
    def expiring_soon(self, request):
        days = int(request.query_params.get('days', 30))
        cutoff = timezone.now().date() + timedelta(days=days)
        batches = StockBatch.objects.filter(
            expiry_date__lte=cutoff,
            quantity_remaining__gt=0,
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


class InventoryAnalyticsView(APIView):
    """Aggregated inventory analytics for the pharmacy dashboard."""

    def get(self, request):
        branch_id = request.query_params.get('branch_id') or request.query_params.get('branch')
        # Force non-admin users to their own branch
        from config.branch_scope import BRANCH_ADMIN_BYPASS_ROLES, get_user_branch
        role = getattr(request.user, 'role', '')
        if role not in BRANCH_ADMIN_BYPASS_ROLES and not getattr(request.user, 'is_superuser', False):
            branch_id = get_user_branch(request.user)
        stocks = MedicationStock.objects.prefetch_related('batches').filter(is_active=True)
        if branch_id:
            stocks = stocks.filter(Q(branch_id=branch_id) | Q(branch__isnull=True))
        now = timezone.now().date()

        total_items = stocks.count()
        low_stock_count = sum(1 for s in stocks if s.is_low_stock)
        out_of_stock = sum(1 for s in stocks if s.total_quantity == 0)

        # Stock valuation
        total_cost_value = 0
        total_retail_value = 0
        for s in stocks:
            qty = s.total_quantity
            total_cost_value += float(s.cost_price) * qty
            total_retail_value += float(s.selling_price) * qty

        # Expiring within 30/90 days
        batch_qs = StockBatch.objects.filter(quantity_remaining__gt=0)
        if branch_id:
            batch_qs = batch_qs.filter(Q(branch_id=branch_id) | Q(branch__isnull=True))
        expiring_30 = batch_qs.filter(
            expiry_date__lte=now + timedelta(days=30),
            expiry_date__gt=now,
        ).count()
        expiring_90 = batch_qs.filter(
            expiry_date__lte=now + timedelta(days=90),
            expiry_date__gt=now,
        ).count()
        expired = batch_qs.filter(
            expiry_date__lt=now,
        ).count()

        return Response({
            'total_items': total_items,
            'low_stock_count': low_stock_count,
            'out_of_stock': out_of_stock,
            'total_cost_value': round(total_cost_value, 2),
            'total_retail_value': round(total_retail_value, 2),
            'potential_profit': round(total_retail_value - total_cost_value, 2),
            'expiring_30_days': expiring_30,
            'expiring_90_days': expiring_90,
            'expired_batches': expired,
        })


class InventoryOverviewView(APIView):
    """One-shot snapshot of the whole inventory operation for the IMS
    overview screen: stock health, expiry, procurement, fulfilment and
    sales — all aggregated into a single lightweight payload."""

    permission_classes = [IsAuthenticated]

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

        stocks = MedicationStock.objects.prefetch_related('batches').filter(is_active=True)
        if branch_id:
            stocks = stocks.filter(branch_q)

        # ── Stock health ────────────────────────────────────────────────
        total_items = stocks.count()
        units_on_hand = 0
        low_stock = 0
        out_of_stock = 0
        for s in stocks:
            qty = s.total_quantity
            units_on_hand += qty
            if qty <= 0:
                out_of_stock += 1
            elif s.is_low_stock:
                low_stock += 1

        # ── Expiry ──────────────────────────────────────────────────────
        batch_qs = StockBatch.objects.filter(quantity_remaining__gt=0)
        if branch_id:
            batch_qs = batch_qs.filter(branch_q)
        expiring_30 = batch_qs.filter(
            expiry_date__lte=today + timedelta(days=30),
            expiry_date__gte=today,
        ).count()
        expiring_90 = batch_qs.filter(
            expiry_date__lte=today + timedelta(days=90),
            expiry_date__gte=today,
        ).count()
        expired = batch_qs.filter(
            expiry_date__lt=today,
        ).count()

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
                total=Coalesce(Sum('quantity'), 0))['total'] or 0
            revenue = txn_qs.aggregate(
                total=Coalesce(Sum('total'), 0))['total'] or 0
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
                            qty=Coalesce(Sum('quantity'), 0),
                            revenue=Coalesce(Sum('total_price'), 0),
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
            for s in stocks:
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


# ─────────────────────────────────────────────────────────────────────────
#  Stock Take
# ─────────────────────────────────────────────────────────────────────────
class InventoryCountViewSet(viewsets.ModelViewSet):
    queryset = InventoryCount.objects.select_related('branch', 'category', 'created_by', 'completed_by').prefetch_related('lines__stock__unit').all()
    serializer_class = InventoryCountSerializer
    permission_classes = [StockTakePermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'branch', 'category']
    search_fields = ['reference', 'name', 'notes']
    ordering_fields = ['created_at', 'completed_at']

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user if self.request.user.is_authenticated else None)

    @action(detail=True, methods=['post'], url_path='generate-sheet')
    def generate_sheet(self, request, pk=None):
        """Populate count lines with current expected qty from active stocks."""
        count = self.get_object()
        if count.status not in (InventoryCount.Status.DRAFT, InventoryCount.Status.IN_PROGRESS):
            return Response({'detail': 'Sheet can only be generated while draft / in progress.'}, status=400)

        qs = MedicationStock.objects.filter(is_active=True).prefetch_related('batches')
        if count.category_id:
            qs = qs.filter(category_id=count.category_id)

        # Wipe old lines and rebuild
        count.lines.all().delete()
        lines = []
        for s in qs:
            lines.append(InventoryCountLine(
                count=count, stock=s,
                expected_quantity=s.total_quantity,
            ))
        InventoryCountLine.objects.bulk_create(lines)
        count.status = InventoryCount.Status.IN_PROGRESS
        count.save(update_fields=['status'])
        return Response(self.get_serializer(count).data)

    @action(detail=True, methods=['post'], url_path='save-counts')
    def save_counts(self, request, pk=None):
        """Bulk-update counted quantities. Payload: {lines: [{id, counted_quantity, notes}]}"""
        count = self.get_object()
        if count.status == InventoryCount.Status.COMPLETED:
            return Response({'detail': 'Count is completed and cannot be edited.'}, status=400)
        lines = request.data.get('lines') or []
        by_id = {l.id: l for l in count.lines.all()}
        for payload in lines:
            line = by_id.get(payload.get('id'))
            if not line:
                continue
            cq = payload.get('counted_quantity')
            line.counted_quantity = int(cq) if cq is not None and cq != '' else None
            line.notes = payload.get('notes', line.notes) or ''
            line.save(update_fields=['counted_quantity', 'notes'])
        return Response(self.get_serializer(count).data)

    @action(detail=True, methods=['post'])
    def complete(self, request, pk=None):
        """Finalise the count: create StockAdjustments for any variance."""
        count = self.get_object()
        if count.status == InventoryCount.Status.COMPLETED:
            return Response({'detail': 'Already completed.'}, status=400)

        adjustments_created = 0
        for line in count.lines.exclude(counted_quantity__isnull=True):
            variance = line.variance
            if variance == 0:
                continue
            stock = line.stock
            if variance > 0:
                # Add to most recent batch (or create a synthetic one)
                batch = stock.batches.order_by('-expiry_date').first()
                if batch is None:
                    from datetime import date as _d, timedelta as _td
                    batch = StockBatch.objects.create(
                        stock=stock,
                        batch_number=f'CNT-{count.pk}-{stock.pk}',
                        quantity_received=variance,
                        quantity_remaining=0,
                        cost_price_per_unit=stock.cost_price or 0,
                        expiry_date=_d.today() + _td(days=365),
                    )
                StockAdjustment.objects.create(
                    stock=stock, batch=batch, quantity_change=variance,
                    reason=StockAdjustment.Reason.COUNT_CORRECTION,
                    notes=f'Stock take {count.reference}',
                    adjusted_by=request.user if request.user.is_authenticated else None,
                )
                batch.quantity_remaining += variance
                batch.save(update_fields=['quantity_remaining'])
                adjustments_created += 1
            else:
                remaining = -variance
                for batch in stock.batches.filter(quantity_remaining__gt=0).order_by('expiry_date'):
                    if remaining <= 0:
                        break
                    take = min(batch.quantity_remaining, remaining)
                    StockAdjustment.objects.create(
                        stock=stock, batch=batch, quantity_change=-take,
                        reason=StockAdjustment.Reason.COUNT_CORRECTION,
                        notes=f'Stock take {count.reference}',
                        adjusted_by=request.user if request.user.is_authenticated else None,
                    )
                    batch.quantity_remaining -= take
                    batch.save(update_fields=['quantity_remaining'])
                    remaining -= take
                adjustments_created += 1

        count.status = InventoryCount.Status.COMPLETED
        count.completed_at = timezone.now()
        count.completed_by = request.user if request.user.is_authenticated else None
        count.save(update_fields=['status', 'completed_at', 'completed_by'])
        return Response({**self.get_serializer(count).data, 'adjustments_created': adjustments_created})


# ─────────────────────────────────────────────────────────────────────────
#  Stock Transfers
# ─────────────────────────────────────────────────────────────────────────
from django_filters import DateFilter, FilterSet, CharFilter


class StockTransferFilterSet(FilterSet):
    """Adds from_date / to_date (inclusive, by requested_at) on top of the
    standard status / source / destination filters."""
    from_date = DateFilter(field_name='requested_at__date', lookup_expr='gte')
    to_date = DateFilter(field_name='requested_at__date', lookup_expr='lte')
    branch = CharFilter(method='filter_branch', help_text='Filter by either source or dest branch')

    class Meta:
        model = StockTransfer
        fields = ['status', 'source_branch', 'dest_branch', 'from_date', 'to_date']

    def filter_branch(self, queryset, name, value):
        from django.db.models import Q
        if not value:
            return queryset
        return queryset.filter(Q(source_branch_id=value) | Q(dest_branch_id=value))


class StockTransferViewSet(viewsets.ModelViewSet):
    queryset = StockTransfer.objects.select_related(
        'source_branch', 'dest_branch', 'requested_by', 'approved_by', 'received_by'
    ).prefetch_related('lines__stock__unit', 'lines__batch').all()
    serializer_class = StockTransferSerializer
    permission_classes = [TransferPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_class = StockTransferFilterSet
    search_fields = ['reference', 'notes']
    ordering_fields = ['requested_at', 'shipped_at', 'received_at']

    def get_queryset(self):
        """Branch-scoped visibility.

        Non-admin users (storekeepers, branch_admins, etc.) see only:
          * transfers their branch initiated (source = my branch, any status)
          * transfers addressed to their branch that are in transit or
            completed (i.e. actually moving stock toward them)
        Admins / super-admins see every transfer (the existing behaviour).
        """
        qs = super().get_queryset()
        user = self.request.user
        if not user or not getattr(user, 'is_authenticated', False):
            return qs
        role = getattr(user, 'role', '')
        if role in {'super_admin', 'tenant_admin', 'inventory_admin'} \
                or getattr(user, 'is_superuser', False):
            return qs
        branch_id = get_user_branch(user)
        if not branch_id:
            return qs
        return qs.filter(
            Q(source_branch_id=branch_id)
            | Q(
                dest_branch_id=branch_id,
                status__in=[
                    StockTransfer.Status.IN_TRANSIT,
                    StockTransfer.Status.COMPLETED,
                ],
            )
        )

    @staticmethod
    def _find_or_create_dest_stock(source_stock, dest_branch):
        """Find an existing MedicationStock at `dest_branch` representing the
        same medication as `source_stock`, otherwise clone one.

        Match key is the medication name (case-insensitive) within the
        destination branch — a brand-new branch may never have carried this
        item, in which case we clone the source's catalog fields so the
        destination's records are consistent.
        """
        if not source_stock or not dest_branch:
            return None, False
        existing = (
            MedicationStock.objects
            .filter(branch=dest_branch, medication_name__iexact=source_stock.medication_name)
            .exclude(pk=source_stock.pk)
            .first()
        )
        if existing:
            return existing, False
        clone = MedicationStock(
            medication_name=source_stock.medication_name,
            abbreviation=source_stock.abbreviation or '',
            brand_name=source_stock.brand_name or '',
            generic_name=source_stock.generic_name or '',
            strength=source_stock.strength or '',
            dosage_form=source_stock.dosage_form or '',
            category=source_stock.category,
            unit=source_stock.unit,
            classification=source_stock.classification,
            branch=dest_branch,
            selling_price=source_stock.selling_price,
            cost_price=source_stock.cost_price,
            tax_percent=source_stock.tax_percent,
            discount_percent=source_stock.discount_percent,
            reorder_level=source_stock.reorder_level or 0,
            reorder_quantity=source_stock.reorder_quantity or 0,
            location_in_store='',
            barcode=source_stock.barcode,
            prescription_required=source_stock.prescription_required,
            items_per_unit=source_stock.items_per_unit or 0,
            is_active=True,
        )
        clone.save()
        return clone, True

    def _set_status(self, transfer, new_status, user, field):
        transfer.status = new_status
        if user and user.is_authenticated:
            setattr(transfer, field, user)
        if new_status == StockTransfer.Status.IN_TRANSIT:
            transfer.shipped_at = timezone.now()
        if new_status == StockTransfer.Status.COMPLETED:
            transfer.received_at = timezone.now()
        transfer.save()

    @staticmethod
    def _clean_signature(raw):
        """Normalise a captured signature payload.

        Returns:
          * ``''``  — no signature supplied (allowed; the UI requires one).
          * the data-URL string when valid.
          * ``None`` — payload present but not a base64 image data-URL, so the
            caller can answer 400 instead of storing garbage.
        """
        if raw in (None, ''):
            return ''
        if not isinstance(raw, str):
            return None
        value = raw.strip()
        if not value:
            return ''
        # Accept only image data-URLs (PNG/JPEG/SVG) and cap the size so a
        # malicious client cannot bloat the row.
        if not value.startswith('data:image/'):
            return None
        if ';base64,' not in value:
            return None
        if len(value) > 2_000_000:  # ~2 MB of base64 text
            return None
        return value

    # ── Notification helper for transfer status changes ──
    def _notify_transfer(self, transfer, new_status, actor):
        """Create a system notification about a transfer status change.

        Notifies the transfer's requester (and approver/receiver if
        different from the actor) so they can track progress.
        """
        from notifications.models import Notification

        status_labels = {
            'draft': 'saved as draft',
            'requested': 'submitted for approval',
            'in_transit': 'approved and shipped',
            'completed': 'received and completed',
            'cancelled': 'cancelled',
        }
        label = status_labels.get(new_status, new_status)
        title = f'Transfer {transfer.reference} — {label.title()}'
        message = (
            f'Stock transfer {transfer.reference} ({transfer.source_branch.name} → '
            f'{transfer.dest_branch.name}) has been {label}.'
        )
        # Build recipient set: requester, approver, receiver — but not the actor
        recipients = set()
        for u in [transfer.requested_by, transfer.approved_by]:
            if u and u != actor:
                recipients.add(u)
        # Always notify the requester unless they are the actor
        if transfer.requested_by and transfer.requested_by != actor:
            recipients.add(transfer.requested_by)
        for user in recipients:
            Notification.objects.create(
                recipient=user,
                type=Notification.NotificationType.SYSTEM,
                title=title,
                message=message,
                data={
                    'transfer_id': transfer.id,
                    'reference': transfer.reference,
                    'status': new_status,
                    'source_branch': transfer.source_branch.name,
                    'dest_branch': transfer.dest_branch.name,
                },
            )

    @action(detail=False, methods=['get'])
    def stats(self, request):
        """KPIs for the transfers dashboard header."""
        qs = self.filter_queryset(self.get_queryset())
        by_status = {s: qs.filter(status=s).count() for s in
                     ['draft', 'requested', 'in_transit', 'completed', 'cancelled']}
        in_transit = qs.filter(status='in_transit').prefetch_related('lines__stock')
        transit_value = sum(
            float(l.stock.cost_price or 0) * l.quantity
            for t in in_transit for l in t.lines.all() if l.stock
        )
        month_start = timezone.now().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        completed_month = qs.filter(status='completed', received_at__gte=month_start).count()
        completed = qs.filter(status='completed').prefetch_related('lines')
        variance_units = sum(l.variance for t in completed for l in t.lines.all())
        durations = [(t.received_at - t.requested_at).total_seconds() / 3600
                     for t in completed
                     if t.received_at and t.requested_at and t.received_at > t.requested_at]
        avg_cycle_hours = round(sum(durations) / len(durations), 1) if durations else None
        return Response({
            'total': qs.count(),
            'by_status': by_status,
            'in_transit_value': round(transit_value, 2),
            'completed_this_month': completed_month,
            'variance_units': variance_units,
            'avg_cycle_hours': avg_cycle_hours,
        })

    @action(detail=False, methods=['get'])
    def analytics(self, request):
        """Comprehensive analytics for the transfers analytics page."""
        return Response(self._analytics_payload(request))

    def _analytics_payload(self, request):
        """Build the analytics payload shared by the JSON endpoint and the PDF.

        Query params:
          ?date_from=&date_to=  ISO dates filtering ``requested_at``
          ?branch=              branch id — transfers leaving or entering it
          ?granularity=         day|week|month (trend buckets, default week)
          ?buckets=             number of trend buckets (default 12, max 52)

        Everything is derived from this tenant's transfers so the page needs a
        single round-trip. Volume is expected to be modest (hundreds to a few
        thousand rows), so aggregation happens in Python after a single
        prefetch rather than in a dozen separate queries.
        """
        from datetime import date as _date, timedelta as _td
        from collections import defaultdict

        def _parse_date(value):
            try:
                return _date.fromisoformat(str(value))
            except (TypeError, ValueError):
                return None

        qs = StockTransfer.objects.select_related(
            'source_branch', 'dest_branch', 'requested_by', 'approved_by',
            'received_by', 'assigned_driver', 'assigned_carrier',
        ).prefetch_related('lines__stock')

        branch_id = request.query_params.get('branch')
        if branch_id:
            qs = qs.filter(Q(source_branch_id=branch_id) | Q(dest_branch_id=branch_id))

        date_from = _parse_date(request.query_params.get('date_from'))
        date_to = _parse_date(request.query_params.get('date_to'))
        if date_from:
            qs = qs.filter(requested_at__date__gte=date_from)
        if date_to:
            qs = qs.filter(requested_at__date__lte=date_to)

        granularity = (request.query_params.get('granularity') or 'week').lower()
        if granularity not in ('day', 'week', 'month'):
            granularity = 'week'
        try:
            bucket_count = int(request.query_params.get('buckets') or 12)
        except (TypeError, ValueError):
            bucket_count = 12
        bucket_count = max(2, min(52, bucket_count))

        transfers = list(qs.order_by('requested_at'))

        STATUS_META = {
            'draft': ('Draft', 'pencil-outline', 'grey'),
            'requested': ('Requested', 'clock-outline', 'blue'),
            'in_transit': ('In transit', 'truck-fast-outline', 'indigo'),
            'completed': ('Completed', 'check-circle-outline', 'green'),
            'cancelled': ('Cancelled', 'cancel', 'red'),
        }

        def line_value(line):
            try:
                return float(line.stock.cost_price or 0) * (line.quantity or 0)
            except Exception:
                return 0.0

        def hours_between(a, b):
            if not a or not b:
                return None
            delta = (b - a).total_seconds() / 3600
            return delta if delta >= 0 else None

        # ── Per-transfer rollups ────────────────────────────────────────
        by_status = defaultdict(int)
        priority_stats = defaultdict(lambda: {'count': 0, 'units': 0, 'value': 0.0,
                                              'cycles': [], 'on_time': [], })
        routes = defaultdict(lambda: {'count': 0, 'units': 0, 'value': 0.0, 'transits': []})
        warehouses = defaultdict(lambda: {'out': 0, 'out_value': 0.0,
                                          'in': 0, 'in_value': 0.0})
        items = defaultdict(lambda: {'units': 0, 'value': 0.0, 'transfers': 0,
                                     'variance': 0, 'name': ''})
        carriers = defaultdict(lambda: {'count': 0, 'units': 0, 'value': 0.0,
                                        'transits': [], 'on_time': [], 'variance': 0})
        discrepancies = []

        totals = {
            'value': 0.0, 'units': 0, 'items': 0,
            'sent_units': 0, 'received_units': 0,
            'variance_units': 0, 'variance_value': 0.0,
        }
        cycle_hours, approval_hours, transit_hours = [], [], []
        on_time_flags = []
        completed_this_month = 0
        month_start = timezone.now().replace(day=1, hour=0, minute=0, second=0, microsecond=0)

        for t in transfers:
            by_status[t.status] += 1
            lines = list(t.lines.all())
            t_units = sum(l.quantity or 0 for l in lines)
            t_value = sum(line_value(l) for l in lines)

            totals['value'] += t_value
            totals['units'] += t_units
            totals['items'] += len(lines)

            if t.status == 'completed':
                completed_this_month += 1 if (t.received_at and t.received_at >= month_start) else 0
                totals['sent_units'] += t_units
                totals['received_units'] += sum(l.quantity_received or 0 for l in lines)
                var_u = sum((l.quantity_received or 0) - (l.quantity or 0) for l in lines)
                var_v = sum(((l.quantity_received or 0) - (l.quantity or 0))
                            * float(l.stock.cost_price or 0) for l in lines if l.stock)
                totals['variance_units'] += var_u
                totals['variance_value'] += var_v
                if var_u:
                    discrepancies.append({
                        'reference': t.reference,
                        'id': t.id,
                        'route': f'{t.source_branch.name} → {t.dest_branch.name}',
                        'units_sent': t_units,
                        'units_received': sum(l.quantity_received or 0 for l in lines),
                        'variance_units': var_u,
                        'variance_value': round(var_v, 2),
                        'received_at': t.received_at,
                        'priority': t.priority,
                    })

            # Durations
            appr = hours_between(t.requested_at, t.shipped_at)
            transit = hours_between(t.shipped_at, t.received_at)
            cycle = hours_between(t.requested_at, t.received_at)
            if appr is not None:
                approval_hours.append(appr)
            if transit is not None:
                transit_hours.append(transit)
            if cycle is not None:
                cycle_hours.append(cycle)

            # On-time delivery vs. the scheduled delivery date
            otm = None
            if t.status == 'completed' and t.scheduled_delivery and t.received_at:
                otm = t.received_at <= t.scheduled_delivery
                on_time_flags.append(otm)

            # Priority bucket
            p = priority_stats[t.priority or 'normal']
            p['count'] += 1
            p['units'] += t_units
            p['value'] += t_value
            if cycle is not None:
                p['cycles'].append(cycle)
            if otm is not None:
                p['on_time'].append(otm)

            # Route bucket
            key = (t.source_branch.name, t.dest_branch.name)
            r = routes[key]
            r['count'] += 1
            r['units'] += t_units
            r['value'] += t_value
            if transit is not None:
                r['transits'].append(transit)

            # Warehouse throughput (out = dispatched, in = completed receipts)
            src = warehouses[t.source_branch.name]
            if t.status in ('in_transit', 'completed'):
                src['out'] += 1
                src['out_value'] += t_value
            dst = warehouses[t.dest_branch.name]
            if t.status == 'completed':
                dst['in'] += 1
                dst['in_value'] += t_value

            # Item rollup
            for l in lines:
                if not l.stock:
                    continue
                it = items[l.stock_id]
                it['name'] = l.stock.medication_name
                it['units'] += l.quantity or 0
                it['value'] += line_value(l)
                it['transfers'] += 1
                it['variance'] += (l.quantity_received or 0) - (l.quantity or 0)

            # Carrier / driver performance
            carrier_name = None
            if t.assigned_carrier_id:
                carrier_name = t.assigned_carrier.name if t.assigned_carrier else 'Carrier'
            elif t.assigned_driver_id:
                carrier_name = (t.assigned_driver.full_name
                                if t.assigned_driver else 'Internal driver')
            if carrier_name:
                c = carriers[carrier_name]
                c['count'] += 1
                c['units'] += t_units
                c['value'] += t_value
                if transit is not None:
                    c['transits'].append(transit)
                if otm is not None:
                    c['on_time'].append(otm)
                if t.status == 'completed':
                    c['variance'] += sum(
                        (l.quantity_received or 0) - (l.quantity or 0) for l in lines)

        def avg(values, nd=1):
            return round(sum(values) / len(values), nd) if values else None

        def pct(part, whole, nd=1):
            return round((part / whole) * 100, nd) if whole else 0.0

        total = len(transfers)
        status_rows = []
        for key, (label, icon, color) in STATUS_META.items():
            count = by_status.get(key, 0)
            status_rows.append({
                'status': key, 'label': label, 'icon': icon, 'color': color,
                'count': count, 'pct': pct(count, total),
            })

        priority_rows = []
        for key in ('low', 'normal', 'high', 'urgent'):
            data = priority_stats.get(key)
            if not data:
                continue
            priority_rows.append({
                'priority': key,
                'count': data['count'],
                'units': data['units'],
                'value': round(data['value'], 2),
                'avg_cycle_hours': avg(data['cycles']),
                'on_time_pct': (pct(data['on_time'].count(True), len(data['on_time']))
                                if data['on_time'] else None),
            })

        route_rows = sorted(
            ({
                'route': f'{src} → {dst}',
                'source': src,
                'dest': dst,
                'count': v['count'],
                'units': v['units'],
                'value': round(v['value'], 2),
                'avg_transit_hours': avg(v['transits']),
            } for (src, dst), v in routes.items()),
            key=lambda x: (-x['count'], -x['value']),
        )[:8]

        warehouse_rows = sorted(
            ({
                'branch': name,
                'dispatched': v['out'],
                'dispatched_value': round(v['out_value'], 2),
                'received': v['in'],
                'received_value': round(v['in_value'], 2),
                'total': v['out'] + v['in'],
            } for name, v in warehouses.items()),
            key=lambda x: -x['total'],
        )

        top_items = sorted(
            ({
                'name': v['name'],
                'units': v['units'],
                'value': round(v['value'], 2),
                'transfers': v['transfers'],
                'variance': v['variance'],
            } for v in items.values()),
            key=lambda x: (-x['units'], -x['value']),
        )[:10]

        carrier_rows = sorted(
            ({
                'name': name,
                'shipments': v['count'],
                'units': v['units'],
                'value': round(v['value'], 2),
                'avg_transit_hours': avg(v['transits']),
                'on_time_pct': (pct(v['on_time'].count(True), len(v['on_time']))
                                if v['on_time'] else None),
                'variance_units': v['variance'],
            } for name, v in carriers.items()),
            key=lambda x: (-x['shipments'], -x['units']),
        )[:10]

        # ── Trend buckets ───────────────────────────────────────────────
        def bucket_start(d, gran):
            if gran == 'day':
                return d
            if gran == 'week':
                return d - _td(days=d.weekday())
            return d.replace(day=1)

        def next_bucket(d, gran):
            if gran == 'day':
                return d + _td(days=1)
            if gran == 'week':
                return d + _td(days=7)
            return (d.replace(day=28) + _td(days=4)).replace(day=1)

        def bucket_label(d, gran):
            if gran == 'day':
                return d.strftime('%b %d')
            if gran == 'week':
                return f'wk {d.strftime("%b %d")}'
            return d.strftime('%b %Y')

        today = timezone.localdate()
        end_bucket = bucket_start(today, granularity)
        bucket_starts = []
        cursor = end_bucket
        for _ in range(bucket_count):
            bucket_starts.append(cursor)
            if granularity == 'day':
                cursor -= _td(days=1)
            elif granularity == 'week':
                cursor -= _td(days=7)
            else:
                cursor = (cursor - _td(days=1)).replace(day=1)
        bucket_starts.reverse()

        trend_map = {
            d: {'created': 0, 'completed': 0, 'cancelled': 0,
                'units': 0, 'value': 0.0, 'received_units': 0}
            for d in bucket_starts
        }

        for t in transfers:
            if not t.requested_at:
                continue
            req_local = timezone.localtime(t.requested_at)
            b = bucket_start(req_local.date(), granularity)
            if b not in trend_map:
                continue
            row = trend_map[b]
            row['created'] += 1
            row['units'] += sum(l.quantity or 0 for l in t.lines.all())
            row['value'] += sum(line_value(l) for l in t.lines.all())
            if t.status == 'cancelled':
                row['cancelled'] += 1
            if t.status == 'completed':
                row['completed'] += 1
                row['received_units'] += sum(l.quantity_received or 0
                                             for l in t.lines.all())

        trend_rows = [{
            'label': bucket_label(d, granularity),
            'date': d.isoformat(),
            **trend_map[d],
            'value': round(trend_map[d]['value'], 2),
        } for d in bucket_starts]

        # ── Aging of open transfers ─────────────────────────────────────
        now = timezone.now()
        aging_buckets = [
            ('0–1 day', 0, 1),
            ('1–3 days', 1, 3),
            ('3–7 days', 3, 7),
            ('7+ days', 7, None),
        ]
        aging_counts = {label: 0 for label, _, _ in aging_buckets}
        aging_value = {label: 0.0 for label, _, _ in aging_buckets}
        for t in transfers:
            if t.status not in ('requested', 'in_transit'):
                continue
            age_days = (now - t.requested_at).total_seconds() / 86400
            for label, lo, hi in aging_buckets:
                if age_days >= lo and (hi is None or age_days < hi):
                    aging_counts[label] += 1
                    aging_value[label] += sum(line_value(l) for l in t.lines.all())
                    break
        aging_rows = [{
            'label': label,
            'count': aging_counts[label],
            'value': round(aging_value[label], 2),
        } for label, _, _ in aging_buckets]

        fill_rate = pct(totals['received_units'], totals['sent_units'])
        on_time_pct = (pct(on_time_flags.count(True), len(on_time_flags))
                       if on_time_flags else None)

        return {
            'filters': {
                'date_from': date_from.isoformat() if date_from else None,
                'date_to': date_to.isoformat() if date_to else None,
                'branch': int(branch_id) if branch_id and str(branch_id).isdigit() else None,
                'granularity': granularity,
                'buckets': bucket_count,
            },
            'kpis': {
                'total': total,
                'completed': by_status.get('completed', 0),
                'in_transit': by_status.get('in_transit', 0),
                'requested': by_status.get('requested', 0),
                'draft': by_status.get('draft', 0),
                'cancelled': by_status.get('cancelled', 0),
                'completion_pct': pct(by_status.get('completed', 0), total),
                'cancel_pct': pct(by_status.get('cancelled', 0), total),
                'units': totals['units'],
                'items': totals['items'],
                'value': round(totals['value'], 2),
                'sent_units': totals['sent_units'],
                'received_units': totals['received_units'],
                'fill_rate_pct': fill_rate,
                'variance_units': totals['variance_units'],
                'variance_value': round(totals['variance_value'], 2),
                'avg_cycle_hours': avg(cycle_hours),
                'avg_approval_hours': avg(approval_hours),
                'avg_transit_hours': avg(transit_hours),
                'on_time_pct': on_time_pct,
                'completed_this_month': completed_this_month,
                'discrepancy_count': len(discrepancies),
            },
            'status_breakdown': status_rows,
            'priority_breakdown': priority_rows,
            'trend': trend_rows,
            'top_routes': route_rows,
            'warehouse_throughput': warehouse_rows,
            'top_items': top_items,
            'partner_performance': carrier_rows,
            'discrepancies': sorted(discrepancies, key=lambda x: x['received_at'],
                                    reverse=True)[:12],
            'aging': aging_rows,
        }

    @action(detail=False, methods=['get'], url_path='analytics-pdf')
    def analytics_pdf(self, request):
        """Premium PDF report of the transfer analytics dashboard.

        Accepts the same query params as :meth:`analytics` and renders the whole
        dashboard — KPI strip, volume trend, pipeline mix, service quality,
        aging, priority performance, busiest lanes, warehouse throughput, top
        items, carrier performance and receipt discrepancies — as a branded
        landscape-A4 document.
        """
        import io as _io
        from reportlab.lib.pagesizes import A4, landscape
        from reportlab.lib.units import mm
        from reportlab.lib.colors import HexColor, white
        from reportlab.lib.styles import ParagraphStyle
        from reportlab.lib.enums import TA_CENTER, TA_RIGHT, TA_LEFT
        from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer,
                                        Table, TableStyle, HRFlowable)
        from reportlab.graphics.shapes import (Drawing, Rect, Circle, Wedge,
                                               Line as GLine, PolyLine,
                                               String as GString)

        payload = self._analytics_payload(request)
        kpis = payload['kpis']
        filters = payload['filters']
        status_rows = payload['status_breakdown']
        priority_rows = payload['priority_breakdown']
        trend_rows = payload['trend']
        route_rows = payload['top_routes']
        warehouse_rows = payload['warehouse_throughput']
        item_rows = payload['top_items']
        partner_rows = payload['partner_performance']
        discrepancy_rows = payload['discrepancies']
        aging_rows = payload['aging']

        # ── Branding / scope ────────────────────────────────────────────
        from config.pdf_branding import resolve_branding

        logo_path, business_name = None, ''
        try:
            logo_path, business_name = resolve_branding(request)
        except (ImportError, NotImplementedError, OSError, ValueError,
                AttributeError) as exc:  # branding is best-effort
            logger.warning('Transfer analytics PDF: branding unavailable (%s)', exc)
            logo_path, business_name = None, ''
        business_name = (business_name
                         or getattr(getattr(request, 'tenant', None), 'name', '')
                         or 'AdhereMed')

        branch_label = 'All branches'
        if filters.get('branch'):
            try:
                branch_obj = Branch.objects.filter(id=filters['branch']).first()
                branch_label = branch_obj.name if branch_obj else f"Branch #{filters['branch']}"
            except Exception:
                branch_label = f"Branch #{filters['branch']}"

        period_label = 'All time'
        if filters.get('date_from'):
            def _pretty(iso):
                try:
                    from datetime import datetime as _dtp
                    return _dtp.strptime(str(iso), '%Y-%m-%d').strftime('%b %d %Y')
                except (TypeError, ValueError):
                    return str(iso)
            period_label = (f"{_pretty(filters['date_from'])} – "
                            f"{_pretty(filters.get('date_to') or timezone.localdate())}")
        gran_label = {'day': 'Daily', 'week': 'Weekly',
                      'month': 'Monthly'}.get(filters.get('granularity'), 'Weekly')

        # ── Palette ─────────────────────────────────────────────────────
        NAVY = '#0F172A'
        SLATE = '#64748B'
        BORDER = '#E2E8F0'
        TRACK = '#EDF1F7'
        GREEN = '#16A34A'
        RED = '#DC2626'
        AMBER = '#F59E0B'
        INDIGO = '#6366F1'
        GREY = '#94A3B8'
        TEAL = '#14B8A6'
        BLUE = '#3B82F6'

        # Brand palette — read live from the tenant so a palette change at
        # /ims/organization/branding repaints this document too. Mirrors
        # `useBranding()` on the web app (same defaults, same accent softening).
        tenant = getattr(request, 'tenant', None)

        def _brand_hex(attr, default):
            """Hex colour configured at /ims/organization/branding."""
            raw = getattr(tenant, attr, '') if tenant else ''
            if isinstance(raw, str):
                raw = raw.strip()
                if len(raw) == 7 and raw.startswith('#'):
                    try:
                        int(raw[1:], 16)
                        return '#' + raw[1:].upper()
                    except ValueError:
                        pass
            return default

        BRAND = _brand_hex('brand_primary', '#2F6DFF')
        DEEP = _brand_hex('brand_secondary', '#143CE1')
        ACCENT_SOURCE = _brand_hex('brand_accent', '#37D6FF')

        def _rgb(hex_color):
            h = str(hex_color).lstrip('#')
            return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

        def mix(hex_color, factor):
            """Blend a hex colour toward white (factor > 0) or black (factor < 0)."""
            r, g, b = _rgb(hex_color)
            if factor >= 0:
                r, g, b = (round(v + (255 - v) * factor) for v in (r, g, b))
            else:
                r, g, b = (round(v * (1 + factor)) for v in (r, g, b))
            return '#%02X%02X%02X' % (r, g, b)

        def blend(a_hex, b_hex, amount):
            """Blend two hex colours; ``amount`` 0 = a, 1 = b."""
            a, b = _rgb(a_hex), _rgb(b_hex)
            t = min(max(amount, 0.0), 1.0)
            return '#%02X%02X%02X' % tuple(
                round(a[i] + (b[i] - a[i]) * t) for i in range(3))

        # Third gradient stop: accent softened toward the primary, exactly like
        # `gradientStops` in the web `useBranding()` composable.
        ACCENT = blend(ACCENT_SOURCE, BRAND, 0.55)

        COLOR_MAP = {'grey': GREY, 'blue': BLUE, 'indigo': INDIGO, 'green': GREEN,
                     'red': RED, 'amber': AMBER, 'teal': TEAL, 'primary': BRAND,
                     'error': RED, 'success': GREEN}

        def _grad_at(t):
            stops = ((0.0, _rgb(DEEP)), (0.52, _rgb(BRAND)), (1.0, _rgb(ACCENT)))
            if t <= stops[0][0]:
                return stops[0][1]
            for i in range(len(stops) - 1):
                t0, c0 = stops[i]
                t1, c1 = stops[i + 1]
                if t <= t1:
                    f = (t - t0) / (t1 - t0) if t1 > t0 else 0
                    return tuple(c0[k] + (c1[k] - c0[k]) * f for k in range(3))
            return stops[-1][1]

        # ── Formatters ──────────────────────────────────────────────────
        def money(v):
            try:
                return f'KES {float(v or 0):,.2f}'
            except (TypeError, ValueError):
                return 'KES 0.00'

        def ints(v):
            try:
                return f'{int(v or 0):,}'
            except (TypeError, ValueError):
                return '0'

        def pct(v):
            return '—' if v is None else f'{float(v):.1f}%'

        def hours(v):
            if v is None:
                return '—'
            try:
                h = float(v)
            except (TypeError, ValueError):
                return '—'
            if h < 1:
                return f'{round(h * 60)}m'
            if h < 48:
                return f'{h:.1f}h'
            return f'{h / 24:.1f}d'

        def stamp(value):
            if not value:
                return '—'
            try:
                return timezone.localtime(value).strftime('%b %d %Y, %I:%M %p')
            except Exception:
                return str(value)

        PRIORITY_META = {
            'low': ('Low', GREY),
            'normal': ('Normal', BRAND),
            'high': ('High', AMBER),
            'urgent': ('Urgent', RED),
        }

        # ── Styles ──────────────────────────────────────────────────────
        st_card_title = ParagraphStyle('ct', fontName='Helvetica-Bold', fontSize=9.5,
                                       textColor=HexColor(NAVY), leading=12)
        st_card_sub = ParagraphStyle('cs', fontName='Helvetica', fontSize=6.5,
                                     textColor=HexColor(SLATE), leading=8.5)
        st_cap = ParagraphStyle('cap', fontName='Helvetica', fontSize=6,
                                textColor=HexColor(SLATE), leading=8)
        st_cap_r = ParagraphStyle('capr', parent=st_cap, alignment=TA_RIGHT)
        st_cell = ParagraphStyle('cell', fontName='Helvetica', fontSize=7,
                                 textColor=HexColor(NAVY), leading=9)
        st_cell_b = ParagraphStyle('cellb', parent=st_cell, fontName='Helvetica-Bold')
        st_cell_r = ParagraphStyle('cellr', parent=st_cell, alignment=TA_RIGHT)
        st_cell_c = ParagraphStyle('cellc', parent=st_cell, alignment=TA_CENTER)
        st_colhead = ParagraphStyle('ch', fontName='Helvetica-Bold', fontSize=6,
                                    textColor=HexColor(SLATE), leading=8)
        st_colhead_r = ParagraphStyle('chr', parent=st_colhead, alignment=TA_RIGHT)
        st_colhead_c = ParagraphStyle('chc', parent=st_colhead, alignment=TA_CENTER)
        st_scope_label = ParagraphStyle('sl', fontName='Helvetica-Bold', fontSize=5.6,
                                        textColor=HexColor(SLATE), leading=7.5)
        st_scope_value = ParagraphStyle('sv', fontName='Helvetica-Bold', fontSize=8,
                                        textColor=HexColor(NAVY), leading=10.5)
        st_note = ParagraphStyle('note', fontName='Helvetica-Oblique', fontSize=6.5,
                                 textColor=HexColor(SLATE), leading=9)
        st_body = ParagraphStyle('body', fontName='Helvetica', fontSize=7.2,
                                 textColor=HexColor(NAVY), leading=10.5)

        def chip(text, color_hex, size=6):
            style = ParagraphStyle(
                f'chip{size}', fontName='Helvetica-Bold', fontSize=size,
                leading=size + 2.2, alignment=TA_CENTER,
                textColor=HexColor(mix(color_hex, -0.25)),
                backColor=HexColor(mix(color_hex, 0.84)), borderPadding=1.7,
            )
            return Paragraph(str(text), style)

        def dot(color_hex, size=5.4):
            d = Drawing(size, size)
            d.add(Circle(size / 2, size / 2, size / 2, fillColor=HexColor(color_hex),
                         strokeWidth=0))
            return d

        def bar(frac, color_hex, width, height=4.4):
            d = Drawing(width, height)
            d.add(Rect(0, 0, width, height, fillColor=HexColor(TRACK), strokeWidth=0))
            filled = max(1.4, width * min(1.0, max(0.0, frac or 0)))
            d.add(Rect(0, 0, filled, height, fillColor=HexColor(color_hex), strokeWidth=0))
            return d

        # ── Geometry ────────────────────────────────────────────────────
        W, H = landscape(A4)
        MARGIN = 14 * mm
        CONTENT_W = W - 2 * MARGIN
        GAP = 5 * mm
        HALF_W = (CONTENT_W - GAP) / 2

        # ── Page furniture ──────────────────────────────────────────────
        def _has_logo():
            return bool(logo_path) and os.path.exists(logo_path)

        def _fit(canv, text, font_name, font_size, max_width):
            """Truncate ``text`` with an ASCII ellipsis so it fits ``max_width``."""
            if not text:
                return ''
            if canv.stringWidth(text, font_name, font_size) <= max_width:
                return text
            ell = '...'
            lo, hi = 0, len(text)
            while lo < hi:
                mid = (lo + hi + 1) // 2
                if canv.stringWidth(text[:mid] + ell, font_name, font_size) <= max_width:
                    lo = mid
                else:
                    hi = mid - 1
            return (text[:lo].rstrip() + ell) if lo else ''

        def _draw_trailing_logo(canv, band_bottom, band_h, box, pad=1.5 * mm):
            """Tenant logo flush against the right edge of the header band.

            Returns the drawn tile width (0 when there is no usable logo) so
            callers can pull the company details clear of it.
            """
            if not _has_logo():
                return 0.0
            tile = box + 2 * pad
            x = W - MARGIN - 5 * mm - tile
            y = band_bottom + (band_h - tile) / 2
            canv.saveState()
            canv.setFillColor(white)
            canv.roundRect(x, y, tile, tile, 2.2 * mm, stroke=0, fill=1)
            try:
                canv.drawImage(logo_path, x + pad, y + pad, box, box,
                               preserveAspectRatio=True, anchor='c', mask='auto')
            except (OSError, ValueError, TypeError):
                canv.restoreState()
                return 0.0
            canv.restoreState()
            return tile

        def _page(canv, doc):
            canv.saveState()
            page_no = canv.getPageNumber()
            right_edge = W - MARGIN - 5 * mm
            left_x = MARGIN + 5 * mm
            if page_no == 1:
                band_top = H - 10 * mm
                band_h = 24 * mm
                band_bottom = band_top - band_h
                canv.saveState()
                path = canv.beginPath()
                path.roundRect(MARGIN, band_bottom, CONTENT_W, band_h, 3 * mm)
                canv.clipPath(path, stroke=0, fill=0)
                steps = 150
                slice_w = CONTENT_W / steps
                for i in range(steps):
                    r, g, b = _grad_at(i / (steps - 1))
                    canv.setFillColorRGB(r / 255, g / 255, b / 255)
                    canv.rect(MARGIN + i * slice_w, band_bottom,
                              slice_w + 0.8, band_h, stroke=0, fill=1)
                canv.restoreState()

                # Tenant logo — last element on the right, after the details.
                tile = _draw_trailing_logo(canv, band_bottom, band_h, 15 * mm)
                text_right = right_edge - (tile + 6 * mm if tile else 0)

                canv.setFillColor(white)
                canv.setFont('Helvetica-Bold', 5.8)
                canv.drawString(left_x, H - 15.6 * mm,
                                'INVENTORY · LOGISTICS · ANALYTICS', charSpace=1.1)
                canv.setFont('Helvetica-Bold', 16)
                canv.drawString(left_x, H - 22.4 * mm, 'Transfer Analytics')
                canv.setFont('Helvetica', 7)
                subtitle = ('Throughput, cycle time, fill rate and partner performance '
                            'across every warehouse move')
                canv.drawString(left_x, H - 27.4 * mm,
                                _fit(canv, subtitle, 'Helvetica', 7,
                                     text_right - left_x - 6 * mm))

                # Company details — right-aligned, sitting left of the logo
                canv.setFont('Helvetica-Bold', 9.5)
                canv.setFillColor(white)
                canv.drawRightString(text_right, H - 16.4 * mm, business_name[:52])
                canv.setFont('Helvetica', 6.6)
                canv.drawRightString(text_right, H - 21.2 * mm,
                                     f'Period: {period_label}')
                canv.drawRightString(text_right, H - 25 * mm,
                                     f'Scope: {branch_label}')
                canv.drawRightString(text_right, H - 28.8 * mm,
                                     'Generated '
                                     + timezone.localtime(timezone.now())
                                     .strftime('%b %d %Y, %I:%M %p'))
            else:
                band_top = H - 10 * mm
                band_h = 17 * mm
                band_bottom = band_top - band_h
                canv.setFillColor(HexColor('#F6F8FC'))
                canv.rect(MARGIN, band_bottom, CONTENT_W, band_h, stroke=0, fill=1)
                canv.setFillColor(HexColor(BRAND))
                canv.rect(MARGIN, band_bottom, 2.6 * mm, band_h, stroke=0, fill=1)

                tile = _draw_trailing_logo(canv, band_bottom, band_h, 11 * mm,
                                           pad=1.2 * mm)
                text_right = right_edge - (tile + 5 * mm if tile else 0)

                canv.setFillColor(HexColor(NAVY))
                canv.setFont('Helvetica-Bold', 10)
                canv.drawString(left_x, H - 17.6 * mm, 'Transfer Analytics')
                canv.setFillColor(HexColor(SLATE))
                canv.setFont('Helvetica', 6.6)
                meta = f'{business_name} · {branch_label} · {period_label}'
                canv.drawString(left_x, H - 22.6 * mm,
                                _fit(canv, meta, 'Helvetica', 6.6,
                                     text_right - left_x - 6 * mm))

                canv.setFillColor(HexColor(NAVY))
                canv.setFont('Helvetica-Bold', 7)
                canv.drawRightString(text_right, H - 18 * mm, business_name[:52])
                canv.setFillColor(HexColor(SLATE))
                canv.setFont('Helvetica', 6.6)
                canv.drawRightString(text_right, H - 23 * mm,
                                     'Analytics report · continued')

            # Footer band
            canv.setStrokeColor(HexColor(BORDER))
            canv.setLineWidth(0.6)
            canv.line(MARGIN, 12 * mm, W - MARGIN, 12 * mm)
            canv.setFillColor(HexColor(SLATE))
            canv.setFont('Helvetica', 6.8)
            canv.drawString(MARGIN, 7.6 * mm, f'{business_name} · Transfer Analytics Report')
            canv.setFont('Helvetica-Bold', 6.8)
            canv.setFillColor(HexColor(BRAND))
            canv.drawCentredString(W / 2, 7.6 * mm,
                                   'Powered by AdhereMed · www.adheremed.co')
            canv.setFont('Helvetica', 6.8)
            canv.setFillColor(HexColor(SLATE))
            canv.drawRightString(W - MARGIN, 7.6 * mm, f'Page {page_no}')
            canv.restoreState()

        buf = _io.BytesIO()
        doc = SimpleDocTemplate(
            buf, pagesize=landscape(A4),
            leftMargin=MARGIN, rightMargin=MARGIN,
            topMargin=34 * mm, bottomMargin=16 * mm,
            title='Transfer Analytics Report',
            author=business_name, subject='Stock transfer analytics',
        )
        flow = [Spacer(1, 1 * mm)]

        # ── Reusable blocks ─────────────────────────────────────────────
        def card(title, subtitle, content, width):
            rows = [[Paragraph(title, st_card_title)]]
            if subtitle:
                rows.append([Paragraph(subtitle, st_card_sub)])
            rows += [[item] for item in content]
            tbl = Table(rows, colWidths=[width], hAlign='LEFT')
            tbl.setStyle(TableStyle([
                ('BOX', (0, 0), (-1, -1), 0.7, HexColor(BORDER)),
                ('BACKGROUND', (0, 0), (-1, -1), white),
                ('LEFTPADDING', (0, 0), (-1, -1), 8),
                ('RIGHTPADDING', (0, 0), (-1, -1), 8),
                ('TOPPADDING', (0, 0), (-1, -1), 1.5),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 1.5),
                ('TOPPADDING', (0, 0), (0, 0), 7),
                ('BOTTOMPADDING', (0, 0), (-1, 0), 0 if subtitle else 4),
                ('BOTTOMPADDING', (0, -1), (-1, -1), 7),
            ]))
            return tbl

        def two_col(left, right, left_w=None):
            lw = left_w or HALF_W
            rw = CONTENT_W - lw - GAP
            tbl = Table([[left, '', right]], colWidths=[lw, GAP, rw], hAlign='LEFT')
            tbl.setStyle(TableStyle([
                ('VALIGN', (0, 0), (-1, -1), 'TOP'),
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 0),
                ('TOPPADDING', (0, 0), (-1, -1), 0),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
            ]))
            return tbl

        def kpi_tile(label, value, sub, color_hex, width):
            value_style = ParagraphStyle('kv', fontName='Helvetica-Bold', fontSize=11.5,
                                         textColor=HexColor(color_hex), leading=14)
            body = [Paragraph(label, st_scope_label),
                    Paragraph(value, value_style),
                    Paragraph(sub, st_cap)]
            tbl = Table([[body]], colWidths=[width], hAlign='LEFT')
            tbl.setStyle(TableStyle([
                ('BOX', (0, 0), (-1, -1), 0.7, HexColor(BORDER)),
                ('LINEBEFORE', (0, 0), (0, -1), 2.6, HexColor(color_hex)),
                ('BACKGROUND', (0, 0), (-1, -1), white),
                ('LEFTPADDING', (0, 0), (-1, -1), 7),
                ('RIGHTPADDING', (0, 0), (-1, -1), 5),
                ('TOPPADDING', (0, 0), (-1, -1), 6),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
            ]))
            return tbl

        def stat_tile(label, value, sub, color_hex, width):
            value_style = ParagraphStyle('sv2', fontName='Helvetica-Bold', fontSize=12.5,
                                         textColor=HexColor(mix(color_hex, -0.15)),
                                         leading=15)
            body = [Paragraph(value, value_style),
                    Paragraph(label, st_scope_label),
                    Paragraph(sub, st_cap)]
            tbl = Table([[body]], colWidths=[width], hAlign='LEFT')
            tbl.setStyle(TableStyle([
                ('BOX', (0, 0), (-1, -1), 0.7, HexColor(mix(color_hex, 0.62))),
                ('BACKGROUND', (0, 0), (-1, -1), HexColor(mix(color_hex, 0.9))),
                ('LEFTPADDING', (0, 0), (-1, -1), 7),
                ('RIGHTPADDING', (0, 0), (-1, -1), 6),
                ('TOPPADDING', (0, 0), (-1, -1), 6),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
            ]))
            return tbl

        def data_table(header, rows, widths, aligns=None):
            aligns = aligns or ['LEFT'] * len(header)
            head = []
            for i, label in enumerate(header):
                style = (st_colhead_r if aligns[i] == 'RIGHT'
                         else st_colhead_c if aligns[i] == 'CENTER' else st_colhead)
                head.append(Paragraph(label, style))
            body = [head] + rows
            tbl = Table(body, colWidths=widths, hAlign='LEFT')
            tbl.setStyle(TableStyle([
                ('LINEBELOW', (0, 0), (-1, 0), 0.7, HexColor(BORDER)),
                ('LINEBELOW', (0, 1), (-1, -2), 0.4, HexColor('#F1F5F9')),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LEFTPADDING', (0, 0), (-1, -1), 3),
                ('RIGHTPADDING', (0, 0), (-1, -1), 3),
                ('TOPPADDING', (0, 0), (-1, -1), 3),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
            ]))
            return tbl

        def empty_note(text):
            return Paragraph(text, st_note)

        # ── 1. Scope bar ────────────────────────────────────────────────
        def scope_cell(label, value):
            return [Paragraph(label, st_scope_label), Paragraph(value, st_scope_value)]

        scope = Table([[
            scope_cell('REPORTING PERIOD', period_label),
            scope_cell('BRANCH SCOPE', branch_label),
            scope_cell('GRANULARITY', f'{gran_label} · {len(trend_rows)} buckets'),
            scope_cell('DATASET', f'{ints(kpis["total"])} transfers · '
                                  f'{ints(kpis["items"])} line items'),
        ]], colWidths=[CONTENT_W / 4] * 4, hAlign='LEFT')
        scope.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), HexColor('#F6F8FC')),
            ('BOX', (0, 0), (-1, -1), 0.7, HexColor(BORDER)),
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 8),
            ('RIGHTPADDING', (0, 0), (-1, -1), 6),
            ('TOPPADDING', (0, 0), (-1, -1), 6),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ]))
        flow += [scope, Spacer(1, 4 * mm)]

        # ── 2. KPI strip ────────────────────────────────────────────────
        tile_gap = 4.4 * mm
        tile_w = (CONTENT_W - 5 * tile_gap) / 6
        fill_color = GREEN if (kpis.get('fill_rate_pct') or 100) >= 98 else AMBER
        on_time = kpis.get('on_time_pct')
        on_time_color = GREY if on_time is None else (GREEN if on_time >= 90 else AMBER)
        tiles = [
            kpi_tile('TRANSFERS', ints(kpis['total']),
                     f"{ints(kpis['completed'])} completed · "
                     f"{ints(kpis['cancelled'])} cancelled", BRAND, tile_w),
            kpi_tile('VALUE MOVED', money(kpis['value']),
                     f"{ints(kpis['units'])} units at cost", TEAL, tile_w),
            kpi_tile('IN TRANSIT', ints(kpis['in_transit']),
                     f"{ints(kpis['requested'])} awaiting approval", INDIGO, tile_w),
            kpi_tile('FILL RATE', pct(kpis.get('fill_rate_pct')),
                     f"{ints(kpis['variance_units'])} units variance", fill_color, tile_w),
            kpi_tile('AVG CYCLE', hours(kpis.get('avg_cycle_hours')),
                     f"{hours(kpis.get('avg_approval_hours'))} to approve · "
                     f"{hours(kpis.get('avg_transit_hours'))} transit", BLUE, tile_w),
            kpi_tile('ON TIME', pct(on_time),
                     'vs scheduled delivery' if on_time is not None else 'no ETA recorded',
                     on_time_color, tile_w),
        ]
        tile_row, tile_widths = [], []
        for idx, tile in enumerate(tiles):
            tile_row.append(tile)
            tile_widths.append(tile_w)
            if idx < len(tiles) - 1:
                tile_row.append('')
                tile_widths.append(tile_gap)
        kpi_tbl = Table([tile_row], colWidths=tile_widths, hAlign='LEFT')
        kpi_tbl.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ]))
        flow += [kpi_tbl, Spacer(1, 4 * mm)]

        # ── 3. Executive summary ────────────────────────────────────────
        summary_bits = []
        summary_bits.append(
            f"Moved <b>{ints(kpis['units'])} units</b> worth <b>{money(kpis['value'])}</b> "
            f"across <b>{ints(kpis['total'])} transfers</b>, completing "
            f"<b>{ints(kpis['completed'])}</b> ({pct(kpis.get('completion_pct'))}).")
        if route_rows:
            top = route_rows[0]
            summary_bits.append(
                f"The busiest lane is <b>{top['source']} → {top['dest']}</b> with "
                f"{ints(top['count'])} transfers ({ints(top['units'])} units).")
        if kpis.get('fill_rate_pct') is not None:
            summary_bits.append(
                f"Receipts ran at <b>{pct(kpis['fill_rate_pct'])} fill rate</b> "
                f"({ints(kpis['received_units'])} of {ints(kpis['sent_units'])} units)")
            if kpis.get('discrepancy_count'):
                summary_bits.append(
                    f"with <b>{ints(kpis['discrepancy_count'])} discrepanc"
                    f"{'y' if kpis['discrepancy_count'] == 1 else 'ies'}</b> logged.")
            else:
                summary_bits.append('with no discrepancies logged.')
        stale = sum(a['count'] for a in aging_rows if a['label'] in ('3–7 days', '7+ days'))
        open_count = sum(a['count'] for a in aging_rows)
        if open_count:
            summary_bits.append(
                f"<b>{ints(open_count)} open transfer"
                f"{'' if open_count == 1 else 's'}</b> remain in the pipeline"
                + (f", {ints(stale)} of them aged 3+ days." if stale
                   else ', all under 3 days old.'))
        summary = ' '.join(summary_bits)
        flow += [card('At a glance', 'Live figures for the selected scope',
                      [Paragraph(summary, st_body)], CONTENT_W),
                 Spacer(1, 4 * mm)]

        # ── 4. Volume trend chart ───────────────────────────────────────
        trend_show = trend_rows[-26:]
        chart_w = CONTENT_W - 16
        chart_h = 54 * mm
        if trend_show:
            dr = Drawing(chart_w, chart_h)
            n = len(trend_show)
            pad_l, pad_r, pad_t, pad_b = 22, 5, 6, 14
            iw, ih = chart_w - pad_l - pad_r, chart_h - pad_t - pad_b
            maxv = max([1] + [max(r['created'], r['completed'], r.get('cancelled') or 0)
                              for r in trend_show])
            for i in range(4):
                gy = pad_b + i * ih / 3
                dr.add(GLine(pad_l, gy, pad_l + iw, gy, strokeColor=HexColor('#EEF2F7'),
                             strokeWidth=0.6))
                tick = f'{maxv * i / 3:.0f}'
                if i == 0 or tick != f'{maxv * (i - 1) / 3:.0f}':
                    dr.add(GString(pad_l - 3, gy - 2, tick,
                                   fontName='Helvetica', fontSize=5.4,
                                   fillColor=HexColor(SLATE), textAnchor='end'))
            gw = iw / max(1, n)
            bw = max(1.8, min(2.9 * mm, gw * 0.2))
            for i, row in enumerate(trend_show):
                gx = pad_l + i * gw + gw / 2
                for k, (key, colr) in enumerate((('created', BRAND),
                                                 ('completed', GREEN),
                                                 ('cancelled', RED))):
                    val = row.get(key) or 0
                    if not val:
                        continue
                    bar_h = max(1.2, (val / maxv) * ih)
                    x = gx - 1.5 * bw + k * bw
                    dr.add(Rect(x, pad_b, bw * 0.86, bar_h,
                                fillColor=HexColor(colr), strokeWidth=0))
            step = max(1, int(round(n / 13)))
            for i, row in enumerate(trend_show):
                if i % step == 0 or i == n - 1:
                    label = str(row['label']).replace('wk ', '')
                    dr.add(GString(pad_l + i * gw + gw / 2, 2.5, label,
                                   fontName='Helvetica', fontSize=5.2,
                                   fillColor=HexColor(SLATE), textAnchor='middle'))
            dr.add(GLine(pad_l, pad_b, pad_l + iw, pad_b, strokeColor=HexColor(BORDER),
                         strokeWidth=0.7))

            legend = Table([[
                dot(BRAND), Paragraph('Created', st_cap), '',
                dot(GREEN), Paragraph('Completed', st_cap), '',
                dot(RED), Paragraph('Cancelled', st_cap),
            ]], colWidths=[7, 34, 8, 7, 40, 8, 7, 40], hAlign='RIGHT')
            legend.setStyle(TableStyle([
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 0),
                ('TOPPADDING', (0, 0), (-1, -1), 0),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
            ]))
            peak = max(trend_show, key=lambda r: r['created'])
            total_value = sum(r.get('value') or 0 for r in trend_show)
            total_units = sum(r.get('units') or 0 for r in trend_show)
            footer_bits = (f"Peak bucket <b>{peak['label']}</b> ({ints(peak['created'])} created)"
                           f" · {ints(total_units)} units · {money(total_value)} in window")
            if len(trend_rows) > len(trend_show):
                footer_bits += f" · showing last {len(trend_show)} of {len(trend_rows)} buckets"
            trend_content = [legend, Spacer(1, 1.5 * mm), dr, Spacer(1, 1 * mm),
                             Paragraph(footer_bits, st_cap)]
            flow += [card('Transfer volume & value',
                          f'Created, completed and cancelled transfers per '
                          f'{gran_label.lower().rstrip("ly")} bucket',
                          trend_content, CONTENT_W),
                     Spacer(1, 4 * mm)]
        else:
            flow += [card('Transfer volume & value', 'No activity in this window',
                          [empty_note('Widen the reporting period to see history.')],
                          CONTENT_W),
                     Spacer(1, 4 * mm)]

        # ── 5. Pipeline mix + service quality ───────────────────────────
        donut_size = 34 * mm
        segments = [{'label': s['label'], 'value': s['count'],
                     'color': COLOR_MAP.get(s['color'], BLUE)}
                    for s in status_rows if s['count'] > 0]
        donut_drawing = None
        if segments:
            donut_drawing = Drawing(donut_size, donut_size)
            seg_total = sum(s['value'] for s in segments)
            radius = donut_size / 2 - 1
            angle = 90.0
            for seg in segments:
                sweep = 360.0 * seg['value'] / seg_total
                donut_drawing.add(Wedge(donut_size / 2, donut_size / 2, radius,
                                        angle - sweep, angle,
                                        fillColor=HexColor(seg['color']),
                                        strokeColor=white, strokeWidth=1))
                angle -= sweep
            donut_drawing.add(Circle(donut_size / 2, donut_size / 2, radius * 0.62,
                                     fillColor=white, strokeWidth=0))
            donut_drawing.add(GString(donut_size / 2, donut_size / 2 - 1,
                                      ints(kpis['total']), fontName='Helvetica-Bold',
                                      fontSize=13, fillColor=HexColor(NAVY),
                                      textAnchor='middle'))
            donut_drawing.add(GString(donut_size / 2, donut_size / 2 - 9, 'transfers',
                                      fontName='Helvetica', fontSize=5,
                                      fillColor=HexColor(SLATE), textAnchor='middle'))

        legend_rows = []
        for row in status_rows:
            legend_rows.append([
                dot(COLOR_MAP.get(row['color'], BLUE)),
                Paragraph(row['label'], st_cell),
                Paragraph(ints(row['count']), st_cell_b),
                Paragraph(f"{row['pct']}%", st_cap_r),
            ])
        legend_tbl = Table(legend_rows, colWidths=[8, 52, 26, 24], hAlign='LEFT')
        legend_tbl.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, -1), 1),
            ('RIGHTPADDING', (0, 0), (-1, -1), 1),
            ('TOPPADDING', (0, 0), (-1, -1), 2.2),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 2.2),
        ]))

        mini_gap = 3 * mm
        mini_w = (HALF_W - 16 - mini_gap) / 2
        mini_row = Table([[
            stat_tile('COMPLETION RATE', pct(kpis.get('completion_pct')),
                      f"{ints(kpis['completed'])} of {ints(kpis['total'])}", BRAND, mini_w),
            '',
            stat_tile('CANCELLATION', pct(kpis.get('cancel_pct')),
                      f"{ints(kpis['cancelled'])} cancelled", RED, mini_w),
        ]], colWidths=[mini_w, mini_gap, mini_w], hAlign='LEFT')
        mini_row.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ]))

        pipeline_content = []
        if donut_drawing:
            holder = Table([[donut_drawing]], colWidths=[HALF_W - 16], hAlign='CENTER')
            holder.setStyle(TableStyle([
                ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 0),
                ('TOPPADDING', (0, 0), (-1, -1), 2),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 2),
            ]))
            pipeline_content += [holder, Spacer(1, 2 * mm)]
        pipeline_content += [legend_tbl, Spacer(1, 3 * mm),
                             HRFlowable(width='100%', thickness=0.5,
                                        color=HexColor(BORDER), spaceAfter=3),
                             mini_row]
        pipeline_card = card('Pipeline mix', 'Where every transfer sits today',
                             pipeline_content, HALF_W)

        quality_gap = 3 * mm
        quality_w = (HALF_W - 16 - quality_gap) / 2
        quality_tiles = [
            ('FILL RATE', pct(kpis.get('fill_rate_pct')),
             f"{ints(kpis['received_units'])} / {ints(kpis['sent_units'])} units",
             fill_color),
            ('ON-TIME DELIVERY', pct(on_time),
             'vs scheduled' if on_time is not None else 'no ETA set', on_time_color),
            ('TO APPROVE', hours(kpis.get('avg_approval_hours')),
             'request → dispatch', BLUE),
            ('IN TRANSIT', hours(kpis.get('avg_transit_hours')),
             'dispatch → receipt', INDIGO),
        ]
        quality_rows = []
        for i in range(0, 4, 2):
            quality_rows.append([
                stat_tile(*quality_tiles[i], quality_w),
                '',
                stat_tile(*quality_tiles[i + 1], quality_w),
            ])
        quality_grid = Table(quality_rows, colWidths=[quality_w, quality_gap, quality_w],
                             hAlign='LEFT')
        quality_grid.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
        ]))

        kv_rows = [
            ('Units moved', ints(kpis['units'])),
            ('Line items', ints(kpis['items'])),
            ('Sent units', ints(kpis['sent_units'])),
            ('Received units', ints(kpis['received_units'])),
            ('Variance (units)', ints(kpis['variance_units'])),
            ('Variance (value)', money(kpis['variance_value'])),
            ('Discrepancies', ints(kpis['discrepancy_count'])),
            ('Completed this month', ints(kpis['completed_this_month'])),
        ]
        kv_table = Table(
            [[Paragraph(label, st_cap), Paragraph(value, st_cell_r)]
             for label, value in kv_rows],
            colWidths=[(HALF_W - 16) * 0.58, (HALF_W - 16) * 0.42], hAlign='LEFT')
        kv_table.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 1.6),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 1.6),
        ]))
        quality_card = card('Service quality', 'Accuracy, punctuality and speed',
                            [quality_grid, Spacer(1, 2 * mm),
                             HRFlowable(width='100%', thickness=0.5,
                                        color=HexColor(BORDER), spaceAfter=3),
                             kv_table], HALF_W)

        flow += [two_col(pipeline_card, quality_card), Spacer(1, 4 * mm)]

        # ── 6. Aging + priority ─────────────────────────────────────────
        aging_max = max([1] + [a['count'] for a in aging_rows])
        aging_inner = HALF_W - 16
        aging_label_w = 42
        aging_count_w = 18
        aging_value_w = 60
        aging_bar_w = aging_inner - aging_label_w - aging_count_w - aging_value_w - 10
        aging_rows_tbl = []
        for row in aging_rows:
            tone = (RED if row['label'] == '7+ days'
                    else AMBER if row['label'] == '3–7 days'
                    else BLUE if row['label'] == '1–3 days' else TEAL)
            aging_rows_tbl.append([
                Paragraph(str(row['label']), st_cell),
                bar(row['count'] / aging_max, tone, aging_bar_w),
                Paragraph(f"{ints(row['count'])}", st_cell_b),
                Paragraph(money(row['value']), st_cap_r),
            ])
        aging_table = Table(
            aging_rows_tbl,
            colWidths=[aging_label_w, aging_bar_w + 10, aging_count_w, aging_value_w],
            hAlign='LEFT')
        aging_table.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 2),
            ('TOPPADDING', (0, 0), (-1, -1), 3),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
        ]))
        stale_note = ('Nothing is aging — open transfers are all recent.'
                      if not stale else
                      f'{ints(stale)} transfer{"s" if stale != 1 else ""} have been '
                      f'open for 3+ days — worth chasing.')
        aging_card = card('Open transfer aging', 'Awaiting approval or still in transit',
                          [aging_table, Spacer(1, 2 * mm),
                           Paragraph(f'<font color="{RED if stale else GREEN}">'
                                     f'<b>{stale_note}</b></font>', st_cap)],
                          HALF_W)

        priority_max = max([1] + [p['count'] for p in priority_rows]) if priority_rows else 1
        priority_bar_w = HALF_W - 16 - 6
        priority_tbl_rows = []
        for row in priority_rows:
            label, tone = PRIORITY_META.get(row['priority'], ('Normal', BRAND))
            meta_bits = [f"{ints(row['units'])} unit"
                         f"{'' if row['units'] == 1 else 's'}",
                         f"cycle {hours(row.get('avg_cycle_hours'))}"]
            if row.get('on_time_pct') is not None:
                meta_bits.append(f"{pct(row['on_time_pct'])} on time")
            priority_tbl_rows.append([
                [chip(label, tone),
                 Paragraph(f"<b>{ints(row['count'])}</b> transfer"
                           f"{'' if row['count'] == 1 else 's'} · "
                           + ' · '.join(meta_bits) + f" · {money(row['value'])}", st_cap),
                 Spacer(1, 1.4 * mm),
                 bar(row['count'] / priority_max, tone, priority_bar_w, 4.2)],
            ])
        if priority_tbl_rows:
            priority_table = Table(priority_tbl_rows, colWidths=[HALF_W - 16], hAlign='LEFT')
            priority_table.setStyle(TableStyle([
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 0),
                ('TOPPADDING', (0, 0), (-1, -1), 2),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
                ('LINEBELOW', (0, 0), (-1, -2), 0.4, HexColor('#F1F5F9')),
            ]))
            priority_content = [priority_table]
        else:
            priority_content = [empty_note('No priority data recorded yet.')]
        priority_card = card('Priority performance', 'Volume and cycle time by urgency',
                             priority_content, HALF_W)

        flow += [two_col(aging_card, priority_card), Spacer(1, 4 * mm)]

        # ── 7. Busiest lanes + warehouse throughput ─────────────────────
        lanes_w = CONTENT_W * 0.6 - GAP / 2
        lane_rows = []
        for row in route_rows:
            lane_rows.append([
                [Paragraph(str(row['source']), st_cell_b),
                 Paragraph(f"→ {row['dest']}", st_cap)],
                Paragraph(ints(row['count']), st_cell_b),
                Paragraph(ints(row['units']), st_cell),
                Paragraph(money(row['value']), st_cell_r),
                Paragraph(hours(row.get('avg_transit_hours')), st_cap_r),
            ])
        if lane_rows:
            inner = lanes_w - 16
            lanes_table = data_table(
                ['LANE', 'TRANSFERS', 'UNITS', 'VALUE', 'TRANSIT'], lane_rows,
                [inner * 0.44, inner * 0.14, inner * 0.13, inner * 0.17, inner * 0.12],
                ['LEFT', 'RIGHT', 'RIGHT', 'RIGHT', 'RIGHT'])
            lanes_content = [lanes_table]
        else:
            lanes_content = [empty_note('No routes recorded in this window.')]
        lanes_card = card('Busiest lanes', 'Top warehouse-to-warehouse routes',
                          lanes_content, lanes_w)

        wh_w = CONTENT_W - lanes_w - GAP
        wh_inner = wh_w - 16
        wh_max = max([1] + [max(w['dispatched'], w['received']) for w in warehouse_rows]) \
            if warehouse_rows else 1
        wh_rows = []
        for row in warehouse_rows[:6]:
            wh_rows.append([[
                Paragraph(f"<b>{row['branch']}</b>", st_cell),
                Paragraph(f"{ints(row['total'])} moves", st_cap),
                Spacer(1, 1.4 * mm),
                Paragraph(f"Dispatched {ints(row['dispatched'])} · "
                          f"{money(row['dispatched_value'])}", st_cap),
                bar(row['dispatched'] / wh_max, BRAND, wh_inner - 2, 3.6),
                Spacer(1, 1.2 * mm),
                Paragraph(f"Received {ints(row['received'])} · "
                          f"{money(row['received_value'])}", st_cap),
                bar(row['received'] / wh_max, TEAL, wh_inner - 2, 3.6),
            ]])
        if wh_rows:
            wh_table = Table(wh_rows, colWidths=[wh_inner], hAlign='LEFT')
            wh_table.setStyle(TableStyle([
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 0),
                ('TOPPADDING', (0, 0), (-1, -1), 2),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
                ('LINEBELOW', (0, 0), (-1, -2), 0.4, HexColor('#F1F5F9')),
            ]))
            wh_content = [wh_table]
        else:
            wh_content = [empty_note('No warehouse activity recorded yet.')]
        wh_card = card('Warehouse throughput', 'Dispatched out vs. received in',
                       wh_content, wh_w)

        flow += [two_col(lanes_card, wh_card, lanes_w), Spacer(1, 4 * mm)]

        # ── 8. Top items + carrier performance ──────────────────────────
        item_inner = HALF_W - 16
        item_rows_tbl = []
        item_max = max([1] + [i['units'] for i in item_rows]) if item_rows else 1
        for idx, row in enumerate(item_rows[:8], 1):
            meta = f"{money(row['value'])} · {ints(row['transfers'])} line" \
                   f"{'' if row['transfers'] == 1 else 's'}"
            if row.get('variance'):
                meta += f" · {row['variance']:+d} variance"
            item_rows_tbl.append([
                Paragraph(f'<b>{idx}</b>', st_cap),
                [Paragraph(str(row['name'])[:46], st_cell_b),
                 Paragraph(meta, st_cap),
                 Spacer(1, 1.2 * mm),
                 bar(row['units'] / item_max, BRAND, item_inner - 14, 3.6)],
                Paragraph(f"<b>{ints(row['units'])}</b>", st_cell_r),
            ])
        if item_rows_tbl:
            items_table = Table(item_rows_tbl, colWidths=[10, item_inner - 48, 34],
                                hAlign='LEFT')
            items_table.setStyle(TableStyle([
                ('VALIGN', (0, 0), (-1, -1), 'TOP'),
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 2),
                ('TOPPADDING', (0, 0), (-1, -1), 3),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
                ('LINEBELOW', (0, 0), (-1, -2), 0.4, HexColor('#F1F5F9')),
            ]))
            items_content = [items_table]
        else:
            items_content = [empty_note('No item movement recorded in this window.')]
        items_card = card('Most transferred items', 'Ranked by units moved',
                          items_content, HALF_W)

        partner_rows_tbl = []
        for row in partner_rows[:8]:
            on_time_val = row.get('on_time_pct')
            partner_rows_tbl.append([
                Paragraph(str(row['name'])[:34], st_cell_b),
                Paragraph(ints(row['shipments']), st_cell_b),
                Paragraph(ints(row['units']), st_cell),
                Paragraph(hours(row.get('avg_transit_hours')), st_cap_r),
                chip(pct(on_time_val),
                     GREEN if (on_time_val or 0) >= 90 else
                     AMBER if (on_time_val or 0) >= 70 else RED)
                if on_time_val is not None else Paragraph('—', st_cap_r),
            ])
        if partner_rows_tbl:
            p_inner = HALF_W - 16
            partners_table = data_table(
                ['PARTNER', 'MOVES', 'UNITS', 'TRANSIT', 'ON TIME'], partner_rows_tbl,
                [p_inner * 0.4, p_inner * 0.14, p_inner * 0.16,
                 p_inner * 0.15, p_inner * 0.15],
                ['LEFT', 'RIGHT', 'RIGHT', 'RIGHT', 'CENTER'])
            partners_content = [partners_table]
        else:
            partners_content = [empty_note('No carrier or driver assignments recorded.')]
        partners_card = card('Carrier & driver performance', 'Who moves the stock, and how well',
                             partners_content, HALF_W)

        flow += [two_col(items_card, partners_card), Spacer(1, 4 * mm)]

        # ── 9. Receipt discrepancies ────────────────────────────────────
        disc_rows = []
        for row in discrepancy_rows[:10]:
            label, tone = PRIORITY_META.get(row.get('priority'), ('Normal', BRAND))
            disc_rows.append([
                Paragraph(str(row['reference']), st_cell_b),
                Paragraph(str(row['route'])[:56], st_cell),
                chip(label, tone),
                Paragraph(ints(row['units_sent']), st_cell_r),
                Paragraph(ints(row['units_received']), st_cell_r),
                Paragraph(f"<font color='{RED if row['variance_units'] < 0 else GREEN}'>"
                          f"<b>{row['variance_units']:+d}</b></font>", st_cell_r),
                Paragraph(money(row['variance_value']), st_cap_r),
                Paragraph(stamp(row.get('received_at')), st_cap),
            ])
        disc_inner = CONTENT_W - 16
        if disc_rows:
            disc_table = data_table(
                ['REFERENCE', 'ROUTE', 'PRIORITY', 'SENT', 'RECEIVED',
                 'VARIANCE', 'VALUE', 'RECEIVED AT'], disc_rows,
                [disc_inner * 0.12, disc_inner * 0.28, disc_inner * 0.1,
                 disc_inner * 0.08, disc_inner * 0.1, disc_inner * 0.1,
                 disc_inner * 0.11, disc_inner * 0.14],
                ['LEFT', 'LEFT', 'CENTER', 'RIGHT', 'RIGHT', 'RIGHT', 'RIGHT', 'LEFT'])
            disc_content = [disc_table]
        else:
            disc_content = [Paragraph(
                f'<font color="{GREEN}"><b>No discrepancies</b></font> — every completed '
                'receipt matched exactly what was dispatched.', st_cap)]
        disc_card = card('Receipt discrepancies',
                         'Short or over receipts recorded at destination',
                         disc_content, CONTENT_W)

        flow += [disc_card, Spacer(1, 3 * mm)]

        # ── 10. Metric definitions ──────────────────────────────────────
        definitions = [
            ('Transfers', 'Every stock transfer created in the reporting period, '
                          'regardless of status.'),
            ('Value at cost', 'Units moved multiplied by the item cost price.'),
            ('Fill rate', 'Units received divided by units dispatched on completed transfers.'),
            ('On-time delivery', 'Completed receipts landing on or before the '
                                 'scheduled delivery date.'),
            ('Cycle time', 'Hours from the request being raised to the goods being received.'),
            ('Approval time', 'Hours from request raised to approved and dispatched.'),
            ('Transit time', 'Hours from dispatch to receipt at the destination branch.'),
            ('Variance', 'Units received minus units dispatched ' '(negative = short receipt).'),
            ('Aging', 'Days an open requested or in-transit transfer has been waiting.'),
            ('Discrepancy', 'A completed receipt where received units differ from dispatched.'),
        ]
        def_gap = 8
        def_w = (CONTENT_W - 16 - def_gap) / 2
        def_rows = []
        for i in range(0, len(definitions), 2):
            pair = definitions[i:i + 2]
            row = []
            for j in range(2):
                if j < len(pair):
                    term, desc = pair[j]
                    row.append([Paragraph(term, st_cell_b), Paragraph(desc, st_cap)])
                else:
                    row.append('')
                if j == 0:
                    row.append('')
            def_rows.append(row)
        def_table = Table(def_rows, colWidths=[def_w, def_gap, def_w], hAlign='LEFT')
        def_table.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 2.5),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 3.5),
        ]))
        flow += [card('How these figures are calculated',
                      'Definitions used throughout this report',
                      [def_table], CONTENT_W),
                 Spacer(1, 3 * mm)]

        # ── 11. Footnote ────────────────────────────────────────────────
        scope_phrase = (f'over {period_label} scoped to {branch_label}'
                        if filters.get('date_from')
                        else f'across all time, scoped to {branch_label}')
        flow.append(Paragraph(
            f'Figures cover {ints(kpis["total"])} transfers {scope_phrase} and are '
            'computed live from transfer, line and batch records at the time of '
            'generation.', st_note))

        doc.build(flow, onFirstPage=_page, onLaterPages=_page)
        buf.seek(0)
        stamp_str = timezone.localtime(timezone.now()).strftime('%Y%m%d')
        return HttpResponse(
            buf.read(),
            content_type='application/pdf',
            headers={
                'Content-Disposition':
                    f'attachment; filename="transfer-analytics_{stamp_str}.pdf"',
            },
        )

    @action(detail=False, methods=['get'])
    def suggestions(self, request):
        """Cross-branch rebalancing suggestions.

        Scans every active branch's usable stock and proposes transfers that
        move supply from branches holding more than their fair share toward
        branches that are short. Fair share is weighted by real POS demand
        (units sold per branch in the lookback window), so the proposal reads
        "send it where it actually sells" instead of a blind equal split.

        Query params:
          ?cover_days=   target days of cover per branch (default 30)
          ?window=       sales lookback window in days (default 90)
          ?branch=       only return suggestions touching this branch
          ?expiry_days=  window for expiry-rescue suggestions (default 90)
          ?limit=        max suggestions (default 40, max 200)
        """
        return Response(self._suggestions_payload(request))

    def _suggestions_payload(self, request):
        """Build the rebalancing plan shared by the JSON endpoint and the PDF."""
        from collections import defaultdict
        from datetime import timedelta as _td

        def _int_param(name, default, lo, hi):
            try:
                value = int(request.query_params.get(name) or default)
            except (TypeError, ValueError):
                return default
            return max(lo, min(hi, value))

        cover_days = _int_param('cover_days', 30, 7, 180)
        window_days = _int_param('window', 90, 7, 730)
        expiry_days = _int_param('expiry_days', 90, 7, 365)
        limit = _int_param('limit', 40, 1, 200)
        focus_branch = request.query_params.get('branch')

        today = timezone.localdate()
        window_start = timezone.now() - _td(days=window_days)
        expiry_cutoff = today + _td(days=expiry_days)

        branches = list(Branch.objects.filter(is_active=True)
                        .order_by('-is_main', 'name'))
        branch_meta = {b.id: {'id': b.id, 'name': b.name, 'is_main': b.is_main}
                       for b in branches}
        branch_ids = set(branch_meta)
        if not branch_ids:
            return {
                'filters': {'cover_days': cover_days, 'window': window_days,
                            'expiry_days': expiry_days, 'branch': None},
                'scope': {'branches': [], 'items': 0, 'window_days': window_days,
                          'cover_days': cover_days},
                'score': {'overall': 100.0, 'grade': 'A', 'label': 'Balanced'},
                'summary': {}, 'branch_health': [], 'suggestions': [],
                'expiry_rescue': [], 'dead_stock': [], 'imbalances': [],
            }

        # ── Demand signal: units sold per (item, branch) in the window ──
        demand_by_item = defaultdict(dict)
        demand_available = True
        try:
            from pos.models import TransactionItem
            rows = (TransactionItem.objects
                    .filter(transaction__status='completed',
                            transaction__created_at__gte=window_start,
                            transaction__branch_id__isnull=False,
                            stock__isnull=False)
                    .values('stock__medication_name', 'transaction__branch_id')
                    .annotate(units=Sum('quantity')))
            for row in rows:
                key = (row['stock__medication_name'] or '').strip().lower()
                if not key:
                    continue
                demand_by_item[key][row['transaction__branch_id']] = \
                    demand_by_item[key].get(row['transaction__branch_id'], 0.0) \
                    + float(row['units'] or 0)
        except Exception as exc:  # POS may not be installed for this tenant
            demand_available = False
            logger.warning('Transfer suggestions: POS demand unavailable (%s)', exc)

        # ── Inventory snapshot across every branch ─────────────────────
        stocks = (MedicationStock.objects
                  .filter(is_active=True, branch_id__in=branch_ids)
                  .select_related('branch', 'category', 'unit')
                  .prefetch_related('batches'))

        items = {}
        for st in stocks:
            key = (st.medication_name or '').strip().lower()
            if not key:
                continue

            usable = 0
            expired = 0
            batch_rows = []
            for batch in st.batches.all():
                remaining = int(batch.quantity_remaining or 0)
                if remaining <= 0:
                    continue
                if batch.expiry_date and batch.expiry_date < today:
                    expired += remaining
                    continue
                usable += remaining
                days_left = ((batch.expiry_date - today).days
                             if batch.expiry_date else None)
                batch_rows.append({
                    'id': batch.id,
                    'batch_number': batch.batch_number,
                    'quantity': remaining,
                    'expiry_date': (batch.expiry_date.isoformat()
                                    if batch.expiry_date else None),
                    'days_to_expiry': days_left,
                })
            # FEFO — earliest expiry first, undated batches last.
            batch_rows.sort(key=lambda r: (r['days_to_expiry'] is None,
                                           r['days_to_expiry'] or 0))

            entry = items.setdefault(key, {
                'key': key,
                'name': st.medication_name,
                'category': st.category.name if st.category_id else '',
                'unit': (st.unit.name if st.unit_id else 'unit'),
                'cost': float(st.cost_price or 0),
                'price': float(st.selling_price or 0),
                'branches': {},
            })
            entry['branches'][st.branch_id] = {
                'stock_id': st.id,
                'branch_id': st.branch_id,
                'branch': st.branch.name,
                'qty': usable,
                'expired': expired,
                'committed': int(st.committed_qty or 0),
                'reorder_level': int(st.reorder_level or 0),
                'reorder_quantity': int(st.reorder_quantity or 0),
                'batches': batch_rows,
            }

        def pct_label(value, digits=0):
            return '—' if value is None else f'{float(value):.{digits}f}%'

        def cover_days_for(qty, velocity):
            if velocity and velocity > 0:
                return round(qty / velocity, 1)
            return None

        def best_demand_destination(item_key, exclude_bid):
            """Branch with the greatest demand for ``item_key`` (excluding one)."""
            rows = demand_by_item.get(item_key) or {}
            best_bid, best_units = None, 0.0
            for bid, units in rows.items():
                if bid == exclude_bid or bid not in branch_ids:
                    continue
                if units > best_units:
                    best_bid, best_units = bid, units
            return best_bid, best_units

        # ── Per-item network analysis ──────────────────────────────────
        suggestions = []
        imbalances = []
        branch_health = {
            bid: {'branch_id': bid, 'branch': branch_meta[bid]['name'],
                  'items': 0, 'units': 0, 'value': 0.0,
                  'below_reorder': 0, 'zero_stock': 0, 'overstocked': 0,
                  'deficit_units': 0, 'surplus_units': 0, 'expiring_units': 0,
                  'expired_units': 0, 'coverage_days': None}
            for bid in branch_ids
        }
        velocity_total_by_branch = defaultdict(float)
        units_total_by_branch = defaultdict(float)
        deviation_sum = 0.0
        ideal_sum = 0.0

        for item_key, item in items.items():
            per_branch = item['branches']
            demand_rows = demand_by_item.get(item_key) or {}

            total_qty = sum(v['qty'] for v in per_branch.values())
            velocities = {bid: units / window_days
                          for bid, units in demand_rows.items() if bid in branch_ids}

            candidate_bids = set(per_branch) | set(velocities)
            if not candidate_bids:
                continue

            total_velocity = sum(velocities.values())
            if total_velocity > 0:
                share = {b: (velocities.get(b, 0.0) / total_velocity)
                         for b in candidate_bids}
            else:
                share = {b: 1.0 / len(candidate_bids) for b in candidate_bids}

            target = {b: share[b] * total_qty for b in candidate_bids}
            # A branch also needs at least `cover_days` of its own demand, so a
            # busy branch is never drained just because the network average is
            # low. This is what makes the target "balanced" rather than merely
            # "proportional".
            fair_share = {b: max(target[b], velocities.get(b, 0.0) * cover_days)
                          for b in candidate_bids}
            deviation_sum += sum(abs(per_branch.get(b, {}).get('qty', 0) - fair_share[b])
                                 for b in candidate_bids)
            ideal_sum += sum(fair_share.values())

            needs, movables = {}, {}
            for bid in candidate_bids:
                row = per_branch.get(bid) or {}
                qty = float(row.get('qty', 0))
                reorder = float(row.get('reorder_level', 0) or 0)
                fair = fair_share[bid]
                velocity = velocities.get(bid, 0.0)

                need = max(0.0, fair - qty)
                if reorder and qty < reorder:
                    need = max(need, reorder - qty)
                if velocity <= 0 and reorder > 0:
                    # No sales history here, so a fair-share target would be a
                    # guess. Respect the branch's declared minimum instead and
                    # never ship more than it takes to clear its reorder level.
                    need = min(need, max(0.0, reorder - qty))
                if need >= 1:
                    needs[bid] = need

                # Never strip a branch below either its fair share or its own
                # reorder level — whichever it can actually afford.
                keep = max(fair, min(reorder, qty))
                movable = max(0.0, qty - keep)
                if movable >= 1:
                    movables[bid] = movable

            # ── Branch health rollup ───────────────────────────────────
            for bid, row in per_branch.items():
                h = branch_health[bid]
                h['items'] += 1
                h['units'] += row['qty']
                h['value'] += row['qty'] * item['cost']
                h['expired_units'] += row['expired']
                h['expiring_units'] += sum(
                    b['quantity'] for b in row['batches']
                    if b['days_to_expiry'] is not None
                    and 0 <= b['days_to_expiry'] <= expiry_days)
                if row['qty'] <= 0:
                    h['zero_stock'] += 1
                elif row['reorder_level'] and row['qty'] < row['reorder_level']:
                    h['below_reorder'] += 1
                if row['reorder_level'] and row['qty'] > row['reorder_level'] * 2:
                    h['overstocked'] += 1
                units_total_by_branch[bid] += row['qty']
                velocity_total_by_branch[bid] += velocities.get(bid, 0.0)

            for bid, need in needs.items():
                branch_health[bid]['deficit_units'] += int(round(need))
            for bid, movable in movables.items():
                branch_health[bid]['surplus_units'] += int(round(movable))

            if not needs or not movables:
                # Record the imbalance even when nothing can be moved yet.
                if needs:
                    imbalances.append({
                        'medication': item['name'],
                        'category': item['category'],
                        'total_qty': int(total_qty),
                        'branches': [{
                            'branch': (per_branch.get(b) or {}).get('branch')
                                      or branch_meta[b]['name'],
                            'qty': int((per_branch.get(b) or {}).get('qty', 0)),
                            'share_pct': round(share[b] * 100, 1),
                            'need': int(round(needs.get(b, 0))),
                            'surplus': 0,
                        } for b in sorted(needs)],
                        'blocked': 'No branch holds a movable surplus.',
                    })
                continue

            # ── Greedy pairing: biggest surplus → biggest need ─────────
            remaining = dict(movables)
            # Only branches that already carry a stock row can receive a
            # transfer line, so a branch that simply does not stock the item is
            # reported as an imbalance instead of a transfer.
            pending = {b: n for b, n in needs.items() if b in per_branch}
            for src in sorted(movables, key=lambda b: -movables[b]):
                while remaining.get(src, 0) >= 1:
                    dest = max((b for b in pending if b != src and pending[b] >= 1),
                               key=lambda b: pending[b], default=None)
                    if dest is None:
                        break
                    move = int(min(remaining[src], pending[dest]))
                    if move < 1:
                        break
                    remaining[src] -= move
                    pending[dest] -= move

                    src_row = per_branch[src]
                    dst_row = per_branch.get(dest) or {}
                    src_qty = int(src_row['qty'])
                    dst_qty = int(dst_row.get('qty', 0))
                    dst_reorder = int(dst_row.get('reorder_level', 0) or 0)
                    src_vel = velocities.get(src, 0.0)
                    dst_vel = velocities.get(dest, 0.0)

                    if dst_qty <= 0:
                        urgency = 'critical'
                        reason = 'Destination is out of stock'
                        detail = (f"{dst_row.get('branch') or branch_meta[dest]['name']} "
                                  f"holds none of this item while {src_row['branch']} "
                                  f"holds {src_qty}.")
                    elif dst_reorder and dst_qty < dst_reorder:
                        ratio = dst_qty / dst_reorder if dst_reorder else 0
                        urgency = 'high' if ratio < 0.5 or dst_vel > 0 else 'medium'
                        reason = 'Destination is below its reorder level'
                        detail = (f"{dst_row['branch']} holds {dst_qty} against a "
                                  f"reorder level of {dst_reorder}.")
                    else:
                        urgency = 'medium' if dst_vel > 0 else 'low'
                        reason = 'Rebalance toward demand share'
                        detail = (f"{dst_row['branch']} accounts for "
                                  f"{pct_label(share[dest] * 100)} of demand but only "
                                  f"holds {pct_label((dst_qty / total_qty * 100) if total_qty else 0)} "
                                  f"of the network stock.")

                    # FEFO source batch for the draft transfer.
                    src_batches = [b for b in src_row['batches'] if b['quantity'] > 0]
                    pick_batch = src_batches[0] if src_batches else None
                    expiring_pick = (pick_batch if pick_batch
                                     and pick_batch['days_to_expiry'] is not None
                                     and pick_batch['days_to_expiry'] <= expiry_days
                                     else None)

                    suggestions.append({
                        'kind': 'rebalance',
                        'medication': item['name'],
                        'category': item['category'],
                        'unit': item['unit'],
                        'source_stock_id': src_row['stock_id'],
                        'source_branch_id': src,
                        'source_branch': src_row['branch'],
                        'dest_stock_id': dst_row.get('stock_id'),
                        'dest_branch_id': dest,
                        'dest_branch': dst_row.get('branch') or branch_meta[dest]['name'],
                        'units': move,
                        'value': round(move * item['cost'], 2),
                        'urgency': urgency,
                        'reason': reason,
                        'detail': detail,
                        'source_qty': src_qty,
                        'dest_qty': dst_qty,
                        'dest_reorder': dst_reorder,
                        'demand_share_pct': round(share[dest] * 100, 1),
                        'velocity_per_day': round(dst_vel, 2),
                        'coverage_before': cover_days_for(dst_qty, dst_vel),
                        'coverage_after': cover_days_for(dst_qty + move, dst_vel),
                        'priority': {'critical': 'urgent', 'high': 'high',
                                     'medium': 'normal', 'low': 'low'}[urgency],
                        'batch_id': pick_batch['id'] if pick_batch else None,
                        'batch_number': pick_batch['batch_number'] if pick_batch else None,
                        'expiry_date': pick_batch['expiry_date'] if pick_batch else None,
                        'days_to_expiry': (pick_batch['days_to_expiry']
                                           if pick_batch else None),
                        'expiring': bool(expiring_pick),
                    })

            imbalances.append({
                'medication': item['name'],
                'category': item['category'],
                'total_qty': int(total_qty),
                'branches': sorted(({
                    'branch': (per_branch.get(bid) or {}).get('branch')
                              or branch_meta[bid]['name'],
                    'qty': int((per_branch.get(bid) or {}).get('qty', 0)),
                    'share_pct': round(share.get(bid, 0) * 100, 1),
                    'need': int(round(needs.get(bid, 0))),
                    'surplus': int(round(movables.get(bid, 0))),
                    'not_stocked': bid not in per_branch,
                } for bid in (set(per_branch) | set(needs))),
                    key=lambda r: (-r['qty'], r['branch'])),
            })

        # ── Expiry rescue: stock that will die where it currently sits ──
        expiry_rescue = []
        for item_key, item in items.items():
            for bid, row in item['branches'].items():
                velocity = (demand_by_item.get(item_key) or {}).get(bid, 0.0) / window_days
                for batch in row['batches']:
                    days_left = batch['days_to_expiry']
                    if days_left is None or days_left > expiry_days:
                        continue
                    consumable = velocity * max(1, days_left)
                    excess = batch['quantity'] - consumable
                    if excess < 1:
                        continue
                    dest, dest_units = best_demand_destination(item_key, bid)
                    if dest is None:
                        continue
                    move = int(min(excess, max(1, dest_units)))
                    expiry_rescue.append({
                        'medication': item['name'],
                        'source_stock_id': row['stock_id'],
                        'source_branch_id': bid,
                        'source_branch': row['branch'],
                        'dest_branch_id': dest,
                        'dest_branch': branch_meta[dest]['name'],
                        'batch_id': batch['id'],
                        'batch_number': batch['batch_number'],
                        'expiry_date': batch['expiry_date'],
                        'days_to_expiry': days_left,
                        'quantity': batch['quantity'],
                        'units': move,
                        'value': round(move * item['cost'], 2),
                        'local_velocity': round(velocity, 2),
                        'urgency': 'critical' if days_left <= 14 else 'high',
                    })
        expiry_rescue.sort(key=lambda r: (r['days_to_expiry'], -r['value']))

        # ── Dead stock: stock with no local movement at all ────────────
        dead_stock = []
        for item_key, item in items.items():
            demand_rows = demand_by_item.get(item_key) or {}
            if not demand_rows:
                continue
            for bid, row in item['branches'].items():
                if row['qty'] < 10:
                    continue
                if demand_rows.get(bid, 0.0) > 0:
                    continue
                dest, dest_units = best_demand_destination(item_key, bid)
                if dest is None:
                    continue
                dest_qty = (item['branches'].get(dest) or {}).get('qty', 0)
                dest_velocity = dest_units / window_days
                room = max(0, int(round(dest_velocity * cover_days)) - int(dest_qty))
                if room < 1:
                    continue
                move = int(min(row['qty'], room))
                dead_stock.append({
                    'medication': item['name'],
                    'source_stock_id': row['stock_id'],
                    'source_branch_id': bid,
                    'source_branch': row['branch'],
                    'dest_branch_id': dest,
                    'dest_branch': branch_meta[dest]['name'],
                    'units': move,
                    'held': row['qty'],
                    'value': round(move * item['cost'], 2),
                    'dest_velocity_per_day': round(dest_velocity, 2),
                    'urgency': 'high' if row['qty'] >= 50 else 'medium',
                })
        dead_stock.sort(key=lambda r: -r['value'])

        # ── Filtering / ordering ───────────────────────────────────────
        if focus_branch:
            suggestions = [s for s in suggestions
                           if str(s['source_branch_id']) == str(focus_branch)
                           or str(s['dest_branch_id']) == str(focus_branch)]

        SEVERITY_ORDER = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3}
        suggestions.sort(key=lambda s: (SEVERITY_ORDER.get(s['urgency'], 9),
                                        -s['value'], -s['units']))
        total_found = len(suggestions)
        suggestions = suggestions[:limit]
        for idx, sug in enumerate(suggestions, 1):
            sug['id'] = f'SUG-{idx:03d}'

        # ── Branch health scoring ──────────────────────────────────────
        for bid, h in branch_health.items():
            h['value'] = round(h['value'], 2)
            velocity = velocity_total_by_branch.get(bid, 0.0)
            h['demand_units'] = int(round(velocity * window_days))
            h['has_demand'] = velocity > 0
            raw_cover = (units_total_by_branch[bid] / velocity) if velocity > 0 else None
            h['coverage_days'] = (round(min(raw_cover, 3650), 1)
                                  if raw_cover is not None else None)
            h['coverage_capped'] = bool(raw_cover is not None and raw_cover > 3650)
            tracked = max(1, h['items'])
            penalty = ((h['below_reorder'] * 1.0 + h['zero_stock'] * 1.6
                        + h['overstocked'] * 0.6) / tracked) * 100
            h['score'] = round(max(0.0, min(100.0, 100 - penalty)), 1)
            h['status'] = ('healthy' if h['score'] >= 80
                           else 'watch' if h['score'] >= 55 else 'at_risk')

        branch_health_rows = sorted(branch_health.values(), key=lambda h: h['score'])

        # ── Network balance score ──────────────────────────────────────
        if ideal_sum > 0:
            balance = 100.0 * (1 - (deviation_sum / (2 * ideal_sum)))
        else:
            balance = 100.0
        balance = round(max(0.0, min(100.0, balance)), 1)
        if balance >= 90:
            grade, label = 'A', 'Balanced'
        elif balance >= 80:
            grade, label = 'B', 'Healthy'
        elif balance >= 70:
            grade, label = 'C', 'Drifting'
        elif balance >= 55:
            grade, label = 'D', 'Unbalanced'
        else:
            grade, label = 'F', 'Fragmented'

        totals = {
            'suggestions': len(suggestions),
            'found': total_found,
            'units': sum(s['units'] for s in suggestions),
            'value': round(sum(s['value'] for s in suggestions), 2),
            'critical': sum(1 for s in suggestions if s['urgency'] == 'critical'),
            'high': sum(1 for s in suggestions if s['urgency'] == 'high'),
            'medium': sum(1 for s in suggestions if s['urgency'] == 'medium'),
            'low': sum(1 for s in suggestions if s['urgency'] == 'low'),
            'items': len({s['medication'] for s in suggestions}),
            'lanes': len({(s['source_branch_id'], s['dest_branch_id'])
                          for s in suggestions}),
            'expiry_moves': len(expiry_rescue),
            'expiry_units': sum(r['units'] for r in expiry_rescue),
            'dead_stock_moves': len(dead_stock),
            'dead_stock_units': sum(r['units'] for r in dead_stock),
            'branches_scanned': len(branch_ids),
            'branches_with_demand': sum(1 for h in branch_health_rows if h['has_demand']),
            'branches_short': sum(1 for h in branch_health_rows if h['status'] != 'healthy'),
            'zero_stock_items': sum(h['zero_stock'] for h in branch_health_rows),
            'below_reorder_items': sum(h['below_reorder'] for h in branch_health_rows),
            'expired_units': sum(h['expired_units'] for h in branch_health_rows),
            'expiring_units': sum(h['expiring_units'] for h in branch_health_rows),
            'demand_signal': demand_available,
        }

        return {
            'filters': {
                'cover_days': cover_days,
                'window': window_days,
                'expiry_days': expiry_days,
                'branch': (int(focus_branch)
                           if focus_branch and str(focus_branch).isdigit() else None),
            },
            'scope': {
                'branches': [branch_meta[b] for b in branch_meta],
                'items': len(items),
                'window_days': window_days,
                'cover_days': cover_days,
            },
            'score': {'overall': balance, 'grade': grade, 'label': label},
            'summary': totals,
            'branch_health': branch_health_rows,
            'suggestions': suggestions,
            'expiry_rescue': expiry_rescue[:12],
            'dead_stock': dead_stock[:12],
            'imbalances': sorted(
                imbalances,
                key=lambda i: -sum(b['need'] for b in i['branches']),
            )[:15],
        }

    @action(detail=False, methods=['get'], url_path='suggestions-pdf')
    def suggestions_pdf(self, request):
        """Branded PDF of the cross-branch rebalancing suggestions."""
        import io as _io
        from reportlab.lib.pagesizes import A4, landscape
        from reportlab.lib.units import mm
        from reportlab.lib.colors import HexColor, white
        from reportlab.lib.styles import ParagraphStyle
        from reportlab.lib.enums import TA_CENTER, TA_RIGHT
        from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer,
                                        Table, TableStyle)
        from reportlab.graphics.shapes import Drawing, Circle, Rect

        payload = self._suggestions_payload(request)
        score = payload['score']
        summ = payload['summary']
        scope = payload['scope']
        health_rows = payload['branch_health']
        suggestions = payload['suggestions']
        expiry_rows = payload['expiry_rescue']
        dead_rows = payload['dead_stock']
        imbalance_rows = payload['imbalances']
        filters = payload['filters']

        from config.pdf_branding import resolve_branding

        logo_path, business_name = None, ''
        try:
            logo_path, business_name = resolve_branding(request)
        except (ImportError, NotImplementedError, OSError, ValueError,
                AttributeError) as exc:
            logger.warning('Suggestions PDF: branding unavailable (%s)', exc)
        tenant = getattr(request, 'tenant', None)
        business_name = (business_name or getattr(tenant, 'name', '') or 'AdhereMed')

        branch_label = 'All branches'
        if filters.get('branch'):
            try:
                obj = Branch.objects.filter(id=filters['branch']).first()
                branch_label = obj.name if obj else f"Branch #{filters['branch']}"
            except Exception:
                branch_label = f"Branch #{filters['branch']}"

        # ── Palette (live from the tenant) ──────────────────────────────
        NAVY = '#0F172A'
        SLATE = '#64748B'
        BORDER = '#E2E8F0'
        GREEN = '#16A34A'
        RED = '#DC2626'
        AMBER = '#F59E0B'
        BLUE = '#3B82F6'
        GREY = '#94A3B8'
        TEAL = '#14B8A6'

        def _brand_hex(attr, default):
            raw = getattr(tenant, attr, '') if tenant else ''
            if isinstance(raw, str) and len(raw.strip()) == 7 and raw.strip().startswith('#'):
                try:
                    int(raw.strip()[1:], 16)
                    return '#' + raw.strip()[1:].upper()
                except ValueError:
                    pass
            return default

        BRAND = _brand_hex('brand_primary', '#2F6DFF')
        DEEP = _brand_hex('brand_secondary', '#143CE1')
        ACCENT_SRC = _brand_hex('brand_accent', '#37D6FF')

        def _rgb(hex_color):
            h = str(hex_color).lstrip('#')
            return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

        def blend(a_hex, b_hex, amount):
            a, b = _rgb(a_hex), _rgb(b_hex)
            t = min(max(amount, 0.0), 1.0)
            return '#%02X%02X%02X' % tuple(round(a[i] + (b[i] - a[i]) * t)
                                           for i in range(3))

        ACCENT = blend(ACCENT_SRC, BRAND, 0.55)

        def _grad_at(t):
            stops = ((0.0, _rgb(DEEP)), (0.52, _rgb(BRAND)), (1.0, _rgb(ACCENT)))
            for i in range(len(stops) - 1):
                t0, c0 = stops[i]
                t1, c1 = stops[i + 1]
                if t <= t1:
                    f = (t - t0) / (t1 - t0) if t1 > t0 else 0
                    return tuple(c0[k] + (c1[k] - c0[k]) * f for k in range(3))
            return stops[-1][1]

        URGENCY_COLOR = {'critical': RED, 'high': '#EA580C',
                         'medium': AMBER, 'low': BLUE}
        STATUS_COLOR = {'healthy': GREEN, 'watch': AMBER, 'at_risk': RED}

        def money(v):
            try:
                return f'KES {float(v or 0):,.0f}'
            except (TypeError, ValueError):
                return 'KES 0'

        def ints(v):
            try:
                return f'{int(v or 0):,}'
            except (TypeError, ValueError):
                return '0'

        def cover_txt(days, capped=False):
            if days is None:
                return '—'
            if capped or days > 3650:
                return '>10y'
            d = float(days)
            if d < 1:
                return '<1d'
            if d < 60:
                return f'{d:.1f}d'.replace('.0d', 'd')
            if d < 365:
                return f'{round(d / 30)}mo'
            return '>1y'

        # ── Styles ──────────────────────────────────────────────────────
        st_card_title = ParagraphStyle('ct', fontName='Helvetica-Bold', fontSize=9.5,
                                       textColor=HexColor(NAVY), leading=12)
        st_card_sub = ParagraphStyle('cs', fontName='Helvetica', fontSize=6.5,
                                     textColor=HexColor(SLATE), leading=8.5)
        st_cap = ParagraphStyle('cap', fontName='Helvetica', fontSize=6,
                                textColor=HexColor(SLATE), leading=8)
        st_cap_r = ParagraphStyle('capr', parent=st_cap, alignment=TA_RIGHT)
        st_cell = ParagraphStyle('cell', fontName='Helvetica', fontSize=7,
                                 textColor=HexColor(NAVY), leading=9)
        st_cell_b = ParagraphStyle('cellb', parent=st_cell, fontName='Helvetica-Bold')
        st_cell_r = ParagraphStyle('cellr', parent=st_cell, alignment=TA_RIGHT)
        st_colhead = ParagraphStyle('ch', fontName='Helvetica-Bold', fontSize=6,
                                    textColor=HexColor(SLATE), leading=8)
        st_colhead_r = ParagraphStyle('chr', parent=st_colhead, alignment=TA_RIGHT)
        st_colhead_c = ParagraphStyle('chc', parent=st_colhead, alignment=TA_CENTER)
        st_scope_label = ParagraphStyle('sl', fontName='Helvetica-Bold', fontSize=5.6,
                                        textColor=HexColor(SLATE), leading=7.5)
        st_scope_value = ParagraphStyle('sv', fontName='Helvetica-Bold', fontSize=8,
                                        textColor=HexColor(NAVY), leading=10.5)
        st_note = ParagraphStyle('note', fontName='Helvetica-Oblique', fontSize=6.5,
                                 textColor=HexColor(SLATE), leading=9)
        st_body = ParagraphStyle('body', fontName='Helvetica', fontSize=7.2,
                                 textColor=HexColor(NAVY), leading=10.5)

        def chip(text, color_hex, size=5.6):
            style = ParagraphStyle(
                f'chp{size}', fontName='Helvetica-Bold', fontSize=size,
                leading=size + 2.2, alignment=TA_CENTER,
                textColor=HexColor(blend(color_hex, '#000000', 0.25)),
                backColor=HexColor(blend(color_hex, '#FFFFFF', 0.84)),
                borderPadding=1.7,
            )
            return Paragraph(str(text), style)

        def dot(color_hex, size=5.4):
            d = Drawing(size, size)
            d.add(Circle(size / 2, size / 2, size / 2,
                         fillColor=HexColor(color_hex), strokeWidth=0))
            return d

        # ── Geometry / furniture ────────────────────────────────────────
        W, H = landscape(A4)
        MARGIN = 14 * mm
        CONTENT_W = W - 2 * MARGIN
        GAP = 5 * mm
        HALF_W = (CONTENT_W - GAP) / 2

        period_label = f'Last {filters.get("window", 90)} days of demand'

        def _has_logo():
            return bool(logo_path) and os.path.exists(logo_path)

        def _draw_trailing_logo(canv, band_bottom, band_h, box, pad=1.5 * mm):
            if not _has_logo():
                return 0.0
            tile = box + 2 * pad
            x = W - MARGIN - 5 * mm - tile
            y = band_bottom + (band_h - tile) / 2
            canv.saveState()
            canv.setFillColor(white)
            canv.roundRect(x, y, tile, tile, 2.2 * mm, stroke=0, fill=1)
            try:
                canv.drawImage(logo_path, x + pad, y + pad, box, box,
                               preserveAspectRatio=True, anchor='c', mask='auto')
            except (OSError, ValueError, TypeError):
                canv.restoreState()
                return 0.0
            canv.restoreState()
            return tile

        def _page(canv, doc):
            canv.saveState()
            page_no = canv.getPageNumber()
            right_edge = W - MARGIN - 5 * mm
            left_x = MARGIN + 5 * mm
            if page_no == 1:
                band_bottom = H - 34 * mm
                band_h = 24 * mm
                canv.saveState()
                path = canv.beginPath()
                path.roundRect(MARGIN, band_bottom, CONTENT_W, band_h, 3 * mm)
                canv.clipPath(path, stroke=0, fill=0)
                steps = 150
                slice_w = CONTENT_W / steps
                for i in range(steps):
                    r, g, b = _grad_at(i / (steps - 1))
                    canv.setFillColorRGB(r / 255, g / 255, b / 255)
                    canv.rect(MARGIN + i * slice_w, band_bottom,
                              slice_w + 0.8, band_h, stroke=0, fill=1)
                canv.restoreState()

                tile = _draw_trailing_logo(canv, band_bottom, band_h, 15 * mm)
                text_right = right_edge - (tile + 6 * mm if tile else 0)

                canv.setFillColor(white)
                canv.setFont('Helvetica-Bold', 5.8)
                canv.drawString(left_x, H - 15.6 * mm,
                                'INVENTORY · LOGISTICS · SUGGESTIONS', charSpace=1.1)
                canv.setFont('Helvetica-Bold', 16)
                canv.drawString(left_x, H - 22.4 * mm, 'Transfer Suggestions')
                canv.setFont('Helvetica', 7)
                canv.drawString(left_x, H - 27.4 * mm,
                                'Every branch scanned against its own demand — where to move '
                                'stock to balance the network')

                canv.setFont('Helvetica-Bold', 9.5)
                canv.drawRightString(text_right, H - 16.4 * mm, business_name[:52])
                canv.setFont('Helvetica', 6.6)
                canv.drawRightString(text_right, H - 21.2 * mm, period_label)
                canv.drawRightString(text_right, H - 25 * mm, f'Scope: {branch_label}')
                canv.drawRightString(text_right, H - 28.8 * mm,
                                     'Generated ' + timezone.localtime(timezone.now())
                                     .strftime('%b %d %Y, %I:%M %p'))
            else:
                band_bottom = H - 27 * mm
                band_h = 17 * mm
                canv.setFillColor(HexColor('#F6F8FC'))
                canv.rect(MARGIN, band_bottom, CONTENT_W, band_h, stroke=0, fill=1)
                canv.setFillColor(HexColor(BRAND))
                canv.rect(MARGIN, band_bottom, 2.6 * mm, band_h, stroke=0, fill=1)
                tile = _draw_trailing_logo(canv, band_bottom, band_h, 11 * mm,
                                           pad=1.2 * mm)
                text_right = right_edge - (tile + 5 * mm if tile else 0)
                canv.setFillColor(HexColor(NAVY))
                canv.setFont('Helvetica-Bold', 10)
                canv.drawString(left_x, H - 17.6 * mm, 'Transfer Suggestions')
                canv.setFillColor(HexColor(SLATE))
                canv.setFont('Helvetica', 6.6)
                canv.drawString(left_x, H - 22.6 * mm,
                                f'{business_name} · {branch_label} · {period_label}')
                canv.setFillColor(HexColor(NAVY))
                canv.setFont('Helvetica-Bold', 7)
                canv.drawRightString(text_right, H - 18 * mm, business_name[:52])
                canv.setFillColor(HexColor(SLATE))
                canv.setFont('Helvetica', 6.6)
                canv.drawRightString(text_right, H - 23 * mm,
                                     'Rebalancing plan · continued')

            canv.setStrokeColor(HexColor(BORDER))
            canv.setLineWidth(0.6)
            canv.line(MARGIN, 12 * mm, W - MARGIN, 12 * mm)
            canv.setFillColor(HexColor(SLATE))
            canv.setFont('Helvetica', 6.8)
            canv.drawString(MARGIN, 7.6 * mm,
                            f'{business_name} · Transfer Suggestions')
            canv.setFont('Helvetica-Bold', 6.8)
            canv.setFillColor(HexColor(BRAND))
            canv.drawCentredString(W / 2, 7.6 * mm,
                                   'Powered by AdhereMed · www.adheremed.co')
            canv.setFont('Helvetica', 6.8)
            canv.setFillColor(HexColor(SLATE))
            canv.drawRightString(W - MARGIN, 7.6 * mm, f'Page {page_no}')
            canv.restoreState()

        buf = _io.BytesIO()
        doc = SimpleDocTemplate(
            buf, pagesize=landscape(A4),
            leftMargin=MARGIN, rightMargin=MARGIN,
            topMargin=34 * mm, bottomMargin=16 * mm,
            title='Transfer Suggestions', author=business_name,
            subject='Cross-branch stock rebalancing',
        )
        flow = [Spacer(1, 1 * mm)]

        def card(title, subtitle, content, width):
            rows = [[Paragraph(title, st_card_title)]]
            if subtitle:
                rows.append([Paragraph(subtitle, st_card_sub)])
            rows += [[item] for item in content]
            tbl = Table(rows, colWidths=[width], hAlign='LEFT')
            tbl.setStyle(TableStyle([
                ('BOX', (0, 0), (-1, -1), 0.7, HexColor(BORDER)),
                ('BACKGROUND', (0, 0), (-1, -1), white),
                ('LEFTPADDING', (0, 0), (-1, -1), 8),
                ('RIGHTPADDING', (0, 0), (-1, -1), 8),
                ('TOPPADDING', (0, 0), (-1, -1), 1.5),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 1.5),
                ('TOPPADDING', (0, 0), (0, 0), 7),
                ('BOTTOMPADDING', (0, 0), (-1, 0), 0 if subtitle else 4),
                ('BOTTOMPADDING', (0, -1), (-1, -1), 7),
            ]))
            return tbl

        def data_table(header, rows, widths, aligns=None):
            aligns = aligns or ['LEFT'] * len(header)
            head = []
            for i, label in enumerate(header):
                style = (st_colhead_r if aligns[i] == 'RIGHT'
                         else st_colhead_c if aligns[i] == 'CENTER' else st_colhead)
                head.append(Paragraph(label, style))
            tbl = Table([head] + rows, colWidths=widths, hAlign='LEFT')
            tbl.setStyle(TableStyle([
                ('LINEBELOW', (0, 0), (-1, 0), 0.7, HexColor(BORDER)),
                ('LINEBELOW', (0, 1), (-1, -2), 0.4, HexColor('#F1F5F9')),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LEFTPADDING', (0, 0), (-1, -1), 3),
                ('RIGHTPADDING', (0, 0), (-1, -1), 3),
                ('TOPPADDING', (0, 0), (-1, -1), 3),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
            ]))
            return tbl

        def stat_tile(label, value, sub, color_hex, width):
            value_style = ParagraphStyle('sv2', fontName='Helvetica-Bold', fontSize=12.5,
                                         textColor=HexColor(blend(color_hex, '#000000', 0.15)),
                                         leading=15)
            body = [Paragraph(value, value_style),
                    Paragraph(label, st_scope_label),
                    Paragraph(sub, st_cap)]
            tbl = Table([[body]], colWidths=[width], hAlign='LEFT')
            tbl.setStyle(TableStyle([
                ('BOX', (0, 0), (-1, -1), 0.7, HexColor(blend(color_hex, '#FFFFFF', 0.62))),
                ('BACKGROUND', (0, 0), (-1, -1), HexColor(blend(color_hex, '#FFFFFF', 0.9))),
                ('LEFTPADDING', (0, 0), (-1, -1), 7),
                ('RIGHTPADDING', (0, 0), (-1, -1), 6),
                ('TOPPADDING', (0, 0), (-1, -1), 6),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
            ]))
            return tbl

        # ── 1. Scope bar ────────────────────────────────────────────────
        def scope_cell(label, value):
            return [Paragraph(label, st_scope_label), Paragraph(value, st_scope_value)]

        scope_tbl = Table([[
            scope_cell('SALES WINDOW', f'Last {filters.get("window")} days'),
            scope_cell('BALANCE TARGET', f'{filters.get("cover_days")} days cover'),
            scope_cell('BRANCHES', str(len(scope.get('branches') or []))),
            scope_cell('ITEMS TRACKED', ints(scope.get('items'))),
        ]], colWidths=[CONTENT_W / 4] * 4, hAlign='LEFT')
        scope_tbl.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), HexColor('#F6F8FC')),
            ('BOX', (0, 0), (-1, -1), 0.7, HexColor(BORDER)),
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 8),
            ('RIGHTPADDING', (0, 0), (-1, -1), 6),
            ('TOPPADDING', (0, 0), (-1, -1), 6),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ]))
        flow += [scope_tbl, Spacer(1, 4 * mm)]

        # ── 2. Headline tiles ───────────────────────────────────────────
        tile_gap = 4.4 * mm
        tile_w = (CONTENT_W - 3 * tile_gap) / 4
        score_color = (GREEN if score.get('overall', 0) >= 80
                       else AMBER if score.get('overall', 0) >= 55 else RED)
        tiles = [
            stat_tile('NETWORK BALANCE', f"{score.get('overall')}/100",
                      f"Grade {score.get('grade')} · {score.get('label')}",
                      score_color, tile_w),
            stat_tile('SUGGESTIONS', ints(summ.get('suggestions')),
                      f"{ints(summ.get('items'))} items · {ints(summ.get('lanes'))} lanes",
                      BRAND, tile_w),
            stat_tile('UNITS TO MOVE', ints(summ.get('units')),
                      money(summ.get('value')) + ' at cost', TEAL, tile_w),
            stat_tile('URGENCY', f"{ints(summ.get('critical'))} / {ints(summ.get('high'))}",
                      'critical / high priority moves',
                      RED if summ.get('critical') else AMBER, tile_w),
        ]
        row_items, row_widths = [], []
        for idx, tile in enumerate(tiles):
            row_items.append(tile)
            row_widths.append(tile_w)
            if idx < len(tiles) - 1:
                row_items.append('')
                row_widths.append(tile_gap)
        strip = Table([row_items], colWidths=row_widths, hAlign='LEFT')
        strip.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ]))
        flow += [strip, Spacer(1, 4 * mm)]

        # ── 3. Executive read-out ───────────────────────────────────────
        bits = [
            f"<b>{ints(summ.get('suggestions'))} transfer"
            f"{'' if summ.get('suggestions') == 1 else 's'}</b> would move "
            f"<b>{ints(summ.get('units'))} units</b> worth "
            f"<b>{money(summ.get('value'))}</b> across "
            f"<b>{ints(summ.get('lanes'))} lane"
            f"{'' if summ.get('lanes') == 1 else 's'}</b>."
        ]
        if summ.get('zero_stock_items'):
            bits.append(f"{ints(summ.get('zero_stock_items'))} item/branch pairs are "
                        f"completely out of stock and {ints(summ.get('below_reorder_items'))} "
                        f"sit below their reorder level.")
        if summ.get('expiring_units'):
            bits.append(f"{ints(summ.get('expiring_units'))} units expire within "
                        f"{filters.get('expiry_days')} days and "
                        f"{ints(summ.get('expired_units'))} units have already lapsed.")
        if summ.get('dead_stock_moves'):
            bits.append(f"{ints(summ.get('dead_stock_moves'))} dormant stock moves are "
                        f"flagged where the item sells elsewhere but not locally.")
        if summ.get('branches_with_demand', 0) < summ.get('branches_scanned', 0):
            bits.append(f"Only {ints(summ.get('branches_with_demand'))} of "
                        f"{ints(summ.get('branches_scanned'))} branches have sales "
                        f"history; the rest are topped up to their declared reorder levels.")
        flow += [card('Executive summary', 'What this scan found across the network',
                      [Paragraph(' '.join(bits), st_body)], CONTENT_W),
                 Spacer(1, 4 * mm)]

        # ── 4. Branch health ────────────────────────────────────────────
        health_pdf_rows = []
        for h in health_rows:
            health_pdf_rows.append([
                [Paragraph(str(h['branch']), st_cell_b),
                 Paragraph(f"{ints(h['items'])} items · {ints(h['units'])} units", st_cap)],
                chip(str(h.get('status', 'watch')).replace('_', ' ').title(),
                     STATUS_COLOR.get(h.get('status'), AMBER)),
                Paragraph(f"<b>{h['score']}</b>", st_cell_r),
                Paragraph(cover_txt(h.get('coverage_days'), h.get('coverage_capped')),
                          st_cell_r),
                Paragraph(ints(h.get('below_reorder')), st_cell_r),
                Paragraph(ints(h.get('zero_stock')), st_cell_r),
                Paragraph(ints(h.get('overstocked')), st_cell_r),
                Paragraph(ints(h.get('expiring_units')), st_cell_r),
                Paragraph(money(h.get('value')), st_cap_r),
            ])
        if health_pdf_rows:
            inner = CONTENT_W - 16
            health_tbl = data_table(
                ['BRANCH', 'STATUS', 'SCORE', 'COVER', 'BELOW REORDER',
                 'OUT OF STOCK', 'OVERSTOCKED', 'EXPIRING', 'VALUE'],
                health_pdf_rows,
                [inner * 0.24, inner * 0.11, inner * 0.08, inner * 0.09,
                 inner * 0.11, inner * 0.1, inner * 0.1, inner * 0.08, inner * 0.09],
                ['LEFT', 'CENTER', 'RIGHT', 'RIGHT', 'RIGHT', 'RIGHT', 'RIGHT',
                 'RIGHT', 'RIGHT'])
            flow += [card('Branch health', 'Weakest branch first', [health_tbl],
                          CONTENT_W),
                     Spacer(1, 4 * mm)]

        # ── 5. Suggestions ──────────────────────────────────────────────
        sug_rows = []
        for idx, s in enumerate(suggestions, 1):
            sug_rows.append([
                Paragraph(str(idx), st_cap),
                [Paragraph(str(s['medication']), st_cell_b),
                 Paragraph(f"{s.get('category') or 'Uncategorised'} · {s.get('unit')}",
                           st_cap)],
                [Paragraph(f"{s['source_branch']} → {s['dest_branch']}", st_cell),
                 Paragraph(str(s['reason']), st_cap)],
                Paragraph(f"<b>{ints(s['units'])}</b>", st_cell_r),
                Paragraph(money(s['value']), st_cap_r),
                chip(str(s['urgency']).title(),
                     URGENCY_COLOR.get(s['urgency'], BLUE)),
                Paragraph(f"{ints(s['source_qty'])} / {ints(s['dest_qty'])}", st_cap_r),
                Paragraph(cover_txt(s.get('coverage_after')), st_cap_r),
                Paragraph(str(s.get('batch_number') or '—'), st_cap),
            ])
        if sug_rows:
            inner = CONTENT_W - 16
            sug_tbl = data_table(
                ['#', 'ITEM', 'LANE & REASON', 'UNITS', 'VALUE', 'URGENCY',
                 'FROM / TO', 'COVER AFTER', 'FEFO BATCH'],
                sug_rows,
                [inner * 0.03, inner * 0.2, inner * 0.25, inner * 0.07,
                 inner * 0.09, inner * 0.08, inner * 0.11, inner * 0.08,
                 inner * 0.09],
                ['LEFT', 'LEFT', 'LEFT', 'RIGHT', 'RIGHT', 'CENTER', 'RIGHT',
                 'RIGHT', 'LEFT'])
            flow += [card('Recommended transfers',
                          'Ranked by urgency, then by the value it unlocks',
                          [sug_tbl], CONTENT_W),
                     Spacer(1, 4 * mm)]
        else:
            flow += [card('Recommended transfers', 'Nothing to move',
                          [Paragraph('Every branch is already holding stock in line '
                                     'with its demand.', st_note)], CONTENT_W),
                     Spacer(1, 4 * mm)]

        # ── 6. Expiry rescue + dead stock ───────────────────────────────
        def mini_table(rows, columns, widths, aligns):
            return data_table(columns, rows, widths, aligns)

        expiry_pdf = []
        for r in expiry_rows:
            expiry_pdf.append([
                [Paragraph(str(r['medication']), st_cell_b),
                 Paragraph(f"{r['source_branch']} → {r['dest_branch']}", st_cap)],
                Paragraph(str(r['batch_number']), st_cap),
                Paragraph(f"<b>{ints(r['units'])}</b>", st_cell_r),
                Paragraph(f"{r['days_to_expiry']}d", st_cap_r),
            ])
        dead_pdf = []
        for r in dead_rows:
            dead_pdf.append([
                [Paragraph(str(r['medication']), st_cell_b),
                 Paragraph(f"{r['source_branch']} → {r['dest_branch']}", st_cap)],
                Paragraph(ints(r['held']), st_cap_r),
                Paragraph(f"<b>{ints(r['units'])}</b>", st_cell_r),
                Paragraph(money(r['value']), st_cap_r),
            ])

        side_gap = 5 * mm
        lw = (CONTENT_W - side_gap) / 2
        lwin = lw - 16

        left_card = card(
            'Expiry rescue',
            'Short-dated batches this branch cannot sell in time',
            [mini_table(expiry_pdf, ['ITEM', 'BATCH', 'MOVE', 'LEFT'],
                        [lwin * 0.46, lwin * 0.24, lwin * 0.16, lwin * 0.14],
                        ['LEFT', 'LEFT', 'RIGHT', 'RIGHT'])]
            if expiry_pdf else
            [Paragraph('Nothing short-dated in the pipeline.', st_note)],
            lw)
        right_card = card(
            'Dead stock',
            'Held here, selling there',
            [mini_table(dead_pdf, ['ITEM', 'HELD', 'MOVE', 'VALUE'],
                        [lwin * 0.5, lwin * 0.16, lwin * 0.16, lwin * 0.18],
                        ['LEFT', 'RIGHT', 'RIGHT', 'RIGHT'])]
            if dead_pdf else
            [Paragraph('No dormant stock in this window.', st_note)],
            lw)

        pair = Table([[left_card, '', right_card]],
                     colWidths=[lw, side_gap, lw], hAlign='LEFT')
        pair.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ]))
        flow += [pair, Spacer(1, 4 * mm)]

        # ── 7. Imbalance matrix ─────────────────────────────────────────
        imb_rows = []
        for item in imbalance_rows[:12]:
            spread = ' · '.join(
                f"{b['branch']}: {ints(b['qty'])}"
                for b in item['branches'][:4])
            imb_rows.append([
                [Paragraph(str(item['medication']), st_cell_b),
                 Paragraph(str(item.get('category') or ''), st_cap)],
                Paragraph(spread, st_cap),
                Paragraph(ints(item['total_qty']), st_cell_r),
                Paragraph(ints(sum(b['need'] for b in item['branches'])), st_cell_r),
                Paragraph(ints(sum(b['surplus'] for b in item['branches'])), st_cell_r),
            ])
        if imb_rows:
            inner = CONTENT_W - 16
            flow += [card('Where the imbalance sits',
                          'Stock spread per item versus demand',
                          [data_table(['ITEM', 'BRANCH SPREAD', 'TOTAL', 'NEEDED', 'SPARE'],
                                      imb_rows,
                                      [inner * 0.26, inner * 0.44, inner * 0.1,
                                       inner * 0.1, inner * 0.1],
                                      ['LEFT', 'LEFT', 'RIGHT', 'RIGHT', 'RIGHT'])],
                          CONTENT_W),
                     Spacer(1, 3 * mm)]

        flow.append(Paragraph(
            f"Fair share blends each branch's share of demand over the last "
            f"{filters.get('window')} days with {filters.get('cover_days')} days of "
            f"cover and its own reorder level. Expired batches are excluded from every "
            f"calculation. Scanned {len(scope.get('branches') or [])} active branches "
            f"covering {ints(scope.get('items'))} stock items.", st_note))

        doc.build(flow, onFirstPage=_page, onLaterPages=_page)
        buf.seek(0)
        stamp_str = timezone.localtime(timezone.now()).strftime('%Y%m%d')
        return HttpResponse(
            buf.read(),
            content_type='application/pdf',
            headers={
                'Content-Disposition':
                    f'attachment; filename="transfer-suggestions_{stamp_str}.pdf"',
            },
        )

    @action(detail=False, methods=['get'])
    def optimization(self, request):
        """Optimisation plan for the stock-transfer network.

        Turns the raw transfer history into a ranked, actionable backlog:
        a weighted health score, stage bottlenecks, and a set of scored
        recommendations (severity × impact × ease) covering approval lag,
        aging, carrier assignment, receipt accuracy, lane imbalance,
        consolidation, priority discipline, expiry risk and value
        concentration.

        Accepts the same filters as :meth:`analytics` so the page and the
        dashboard never disagree about the scope.
        """
        return Response(self._optimization_payload(request))

    def _optimization_payload(self, request):
        """Build the optimization plan shared by the JSON endpoint and the PDF."""
        from collections import defaultdict
        from datetime import date as _date
        from datetime import timedelta as _td

        def _parse_date(value):
            try:
                return _date.fromisoformat(str(value))
            except (TypeError, ValueError):
                return None

        def clamp(value, lo=0.0, hi=100.0):
            return max(lo, min(hi, value))

        def pct_label(value, digits=1):
            return '—' if value is None else f'{float(value):.{digits}f}%'

        def avg(values, nd=1):
            return round(sum(values) / len(values), nd) if values else None

        def hours_between(a, b):
            if not a or not b:
                return None
            delta = (b - a).total_seconds() / 3600
            return delta if delta >= 0 else None

        def line_value(line):
            try:
                return float(line.stock.cost_price or 0) * (line.quantity or 0)
            except Exception:
                return 0.0

        # ── Baseline (shared with the analytics dashboard) ──────────────
        base = self._analytics_payload(request)
        kpis = base['kpis']
        filters = base['filters']

        # ── Entity set (same scope, richer prefetch) ────────────────────
        qs = StockTransfer.objects.select_related(
            'source_branch', 'dest_branch', 'assigned_driver',
            'assigned_carrier', 'assigned_vehicle',
            'requested_by', 'approved_by', 'received_by',
        ).prefetch_related('lines__stock', 'lines__batch')

        branch_id = request.query_params.get('branch')
        if branch_id:
            qs = qs.filter(Q(source_branch_id=branch_id) | Q(dest_branch_id=branch_id))
        date_from = _parse_date(request.query_params.get('date_from'))
        date_to = _parse_date(request.query_params.get('date_to'))
        if date_from:
            qs = qs.filter(requested_at__date__gte=date_from)
        if date_to:
            qs = qs.filter(requested_at__date__lte=date_to)

        transfers = list(qs.order_by('requested_at'))
        now = timezone.now()
        today = timezone.localdate()

        OPEN = ('draft', 'requested', 'approved', 'in_transit')

        # Per-transfer rollups, computed once and reused by every rule.
        rows = []
        for t in transfers:
            lines = list(t.lines.all())
            units = sum(l.quantity or 0 for l in lines)
            value = sum(line_value(l) for l in lines)
            received = sum(l.quantity_received or 0 for l in lines)
            variance = received - units
            rows.append({
                'id': t.id,
                'reference': t.reference,
                'status': t.status,
                'priority': t.priority or 'normal',
                'source': t.source_branch.name,
                'dest': t.dest_branch.name,
                'lane': f'{t.source_branch.name} → {t.dest_branch.name}',
                'units': units,
                'value': value,
                'received': received,
                'variance': variance,
                'lines': len(lines),
                'requested_at': t.requested_at,
                'shipped_at': t.shipped_at,
                'received_at': t.received_at,
                'scheduled_delivery': t.scheduled_delivery,
                'has_carrier': bool(t.assigned_carrier_id or t.assigned_driver_id),
                'has_vehicle': bool(t.assigned_vehicle_id or (t.assigned_vehicle_note or '').strip()),
                'has_signature': bool((t.approved_signature or '') and (t.received_signature or '')),
                'approval_h': hours_between(t.requested_at, t.shipped_at),
                'transit_h': hours_between(t.shipped_at, t.received_at),
                'cycle_h': hours_between(t.requested_at, t.received_at),
                'age_days': ((now - t.requested_at).total_seconds() / 86400
                             if t.requested_at else 0.0),
                'carrier': (t.assigned_carrier.name if t.assigned_carrier_id else
                            (t.assigned_driver.full_name if t.assigned_driver_id else '')),
                'batches': [l.batch for l in lines if l.batch_id],
            })

        completed = [r for r in rows if r['status'] == 'completed']
        open_rows = [r for r in rows if r['status'] in OPEN]
        total = len(rows)

        # Aggregate durations for the funnel.
        approval_hours = [r['approval_h'] for r in rows if r['approval_h'] is not None]
        transit_hours = [r['transit_h'] for r in rows if r['transit_h'] is not None]
        cycle_hours = [r['cycle_h'] for r in rows if r['cycle_h'] is not None]

        # ═══════════════════ HEALTH SCORE ══════════════════════════════
        APPROVAL_TARGET_H = 6.0
        TRANSIT_TARGET_H = 30.0
        CYCLE_TARGET_H = 48.0

        avg_approval = avg(approval_hours) or 0.0
        avg_transit = avg(transit_hours) or 0.0
        avg_cycle = avg(cycle_hours) or 0.0

        def speed_score(hours_val, target):
            """100 at ≤ target, 0 at ≥ 5× target."""
            if hours_val <= 0:
                return 100.0
            return clamp(100.0 * (5 * target - hours_val) / (4 * target))

        speed = round(speed_score(avg_cycle, CYCLE_TARGET_H), 1)

        fill = kpis.get('fill_rate_pct')
        accuracy = round(clamp(fill if fill is not None else 100.0), 1)

        # Reliability: on-time where an ETA exists, else completion rate.
        eta_rows = [r for r in completed if r['scheduled_delivery'] and r['received_at']]
        if eta_rows:
            on_time = sum(1 for r in eta_rows
                          if r['received_at'] <= r['scheduled_delivery'])
            reliability = round(clamp(100.0 * on_time / len(eta_rows)), 1)
            reliability_basis = f'{on_time} of {len(eta_rows)} deliveries on time'
        else:
            reliability = round(clamp(kpis.get('completion_pct') or 0), 1)
            reliability_basis = 'no delivery ETAs recorded — using completion rate'

        # Discipline: paperwork/fleet completeness across non-draft transfers.
        actionable = [r for r in rows if r['status'] != 'draft'] or rows
        discipline_parts = []
        if actionable:
            discipline_parts.append(
                100.0 * sum(1 for r in actionable if r['has_carrier']) / len(actionable))
            discipline_parts.append(
                100.0 * sum(1 for r in actionable if r['scheduled_delivery']) / len(actionable))
            done = [r for r in completed]
            if done:
                discipline_parts.append(
                    100.0 * sum(1 for r in done if r['has_signature']) / len(done))
        discipline = round(clamp(sum(discipline_parts) / len(discipline_parts)
                                 if discipline_parts else 100.0), 1)

        # Balance: how two-way each lane pair is (1.0 = perfectly balanced).
        pair_totals = defaultdict(lambda: defaultdict(int))
        for r in rows:
            pair_totals[tuple(sorted((r['source'], r['dest'])))][(r['source'], r['dest'])] += 1
        imbalances = []
        for pair, directions in pair_totals.items():
            counts = list(directions.values())
            if len(counts) == 1:
                imbalances.append(1.0)
            else:
                imbalances.append(1.0 - min(counts) / max(counts))
        balance = round(clamp(100.0 * (1.0 - (sum(imbalances) / len(imbalances))
                                       if imbalances else 0.0)), 1)

        pillars = [
            {'key': 'speed', 'label': 'Cycle speed', 'score': speed, 'weight': 0.24,
             'note': f'avg cycle {avg_cycle:.1f}h vs {CYCLE_TARGET_H:.0f}h target',
             'target': CYCLE_TARGET_H},
            {'key': 'accuracy', 'label': 'Receipt accuracy', 'score': accuracy, 'weight': 0.24,
             'note': f'fill rate {pct_label(fill)}',
             'target': 100.0},
            {'key': 'reliability', 'label': 'On-time reliability', 'score': reliability,
             'weight': 0.20, 'note': reliability_basis, 'target': 100.0},
            {'key': 'discipline', 'label': 'Process discipline', 'score': discipline,
             'weight': 0.18,
             'note': 'carrier assigned · delivery scheduled · signatures captured',
             'target': 100.0},
            {'key': 'balance', 'label': 'Network balance', 'score': balance, 'weight': 0.14,
             'note': 'how evenly freight flows in both directions',
             'target': 100.0},
        ]
        overall = round(sum(p['score'] * p['weight'] for p in pillars), 1)
        grade = ('A+' if overall >= 92 else 'A' if overall >= 84 else
                 'B' if overall >= 74 else 'C' if overall >= 62 else
                 'D' if overall >= 50 else 'E')
        grade_label = ('Excellent' if overall >= 92 else 'Strong' if overall >= 84 else
                       'Good' if overall >= 74 else 'Fair' if overall >= 62 else
                       'Weak' if overall >= 50 else 'Critical')

        # ═══════════════════ RULES → RECOMMENDATIONS ═══════════════════
        SEVERITY_W = {'critical': 1.0, 'high': 0.78, 'medium': 0.52, 'low': 0.28}
        IMPACT_W = {'high': 1.0, 'medium': 0.62, 'low': 0.32}
        EFFORT_W = {'low': 1.0, 'medium': 0.62, 'high': 0.3}
        CATEGORY_META = {
            'speed': ('Cycle speed', 'mdi-timer-sand'),
            'accuracy': ('Receipt accuracy', 'mdi-shield-check-outline'),
            'cost': ('Cost efficiency', 'mdi-cash-multiple'),
            'risk': ('Risk control', 'mdi-alert-decagram-outline'),
            'balance': ('Network balance', 'mdi-scale-balance'),
            'process': ('Process discipline', 'mdi-clipboard-check-outline'),
        }

        recs = []

        def add(rec_id, title, category, severity, impact, effort, summary, detail,
                actions, metrics, affected=None, save_hours=0.0, save_value=0.0,
                save_units=0, quick_win=False):
            score = round(100 * (0.45 * SEVERITY_W[severity] +
                                 0.35 * IMPACT_W[impact] +
                                 0.20 * EFFORT_W[effort]), 1)
            cat_label, cat_icon = CATEGORY_META[category]
            recs.append({
                'id': rec_id,
                'title': title,
                'category': category,
                'category_label': cat_label,
                'category_icon': cat_icon,
                'severity': severity,
                'impact': impact,
                'effort': effort,
                'score': score,
                'quick_win': quick_win or (effort == 'low' and impact in ('high', 'medium')),
                'summary': summary,
                'detail': detail,
                'actions': actions,
                'metrics': metrics,
                'affected': (affected or [])[:8],
                'save_hours': round(save_hours, 1),
                'save_value': round(save_value, 2),
                'save_units': save_units,
            })

        # ── 1. Approval bottleneck ─────────────────────────────────────
        slow_approvals = [r for r in rows
                          if r['approval_h'] is not None and r['approval_h'] > 8]
        if slow_approvals:
            excess = sum(r['approval_h'] - APPROVAL_TARGET_H for r in slow_approvals)
            worst = sorted(slow_approvals, key=lambda r: -r['approval_h'])[:5]
            add('approval-lag', 'Approvals are holding stock back',
                'speed',
                'critical' if len(slow_approvals) / max(1, len(approval_hours)) > 0.4 else 'high',
                'high', 'low',
                f'{len(slow_approvals)} transfers waited more than 8h between request '
                f'and dispatch (avg {avg_approval:.1f}h overall).',
                'Every hour between request and dispatch is an hour the destination '
                f'branch sits under-stocked. Against a {APPROVAL_TARGET_H:.0f}h target, '
                f'this queue has cost about {excess:.0f} hours of delay.',
                ['Set a 4-hour approval SLA with an auto-escalation after 8 hours.',
                 'Let branch admins auto-approve transfers below a value threshold.',
                 'Show a live "awaiting approval" queue on the approver dashboard.'],
                [{'label': 'Avg approval', 'value': f'{avg_approval:.1f}h'},
                 {'label': 'Over SLA', 'value': str(len(slow_approvals))},
                 {'label': 'Delay cost', 'value': f'{excess:.0f}h'}],
                [{'reference': r['reference'], 'label': r['lane'],
                  'detail': f"{r['approval_h']:.1f}h to dispatch",
                  'value': f"KES {r['value']:,.0f}"} for r in worst],
                save_hours=excess)

        # ── 2. Aging / stalled pipeline ────────────────────────────────
        stalled = [r for r in open_rows if r['age_days'] >= 3]
        if stalled:
            at_risk = sum(r['value'] for r in stalled)
            units_risk = sum(r['units'] for r in stalled)
            oldest = sorted(stalled, key=lambda r: -r['age_days'])[:5]
            add('aging-pipeline', 'Stalled transfers are tying up stock and cash',
                'risk',
                'critical' if any(r['age_days'] >= 7 for r in stalled) else 'high',
                'high', 'low',
                f'{len(stalled)} open transfer{"s" if len(stalled) != 1 else ""} '
                f'have been waiting 3+ days, holding '
                f'{units_risk:,} units worth KES {at_risk:,.0f}.',
                'Open transfers are committed stock: the destination cannot sell it '
                'and the source has already ring-fenced it. Ageing past three days is '
                'the clearest signal of a stuck hand-off.',
                ['Chase the oldest transfers first — oldest first, value second.',
                 'Auto-cancel drafts that never get submitted within 48 hours.',
                 'Add a daily digest to the branch admin listing transfers older than 3 days.'],
                [{'label': 'Stalled', 'value': str(len(stalled))},
                 {'label': 'Units held', 'value': f'{units_risk:,}'},
                 {'label': 'Value held', 'value': f'KES {at_risk:,.0f}'}],
                [{'reference': r['reference'], 'label': r['lane'],
                  'detail': f"{r['age_days']:.1f} days · {r['status'].replace('_', ' ')}",
                  'value': f"KES {r['value']:,.0f}"} for r in oldest],
                save_value=at_risk, save_units=units_risk, quick_win=True)

        # ── 3. Carrier / fleet assignment gaps ─────────────────────────
        unassigned = [r for r in rows
                      if r['status'] in ('requested', 'approved', 'in_transit')
                      and not r['has_carrier']]
        if unassigned:
            add('unassigned-fleet', 'Shipments go out without a carrier',
                'process',
                'high' if len(unassigned) > 2 else 'medium',
                'medium', 'low',
                f'{len(unassigned)} active transfer'
                f'{"s" if len(unassigned) != 1 else ""} '
                'have no driver or carrier assigned.',
                'Unassigned freight is the single biggest predictor of a late receipt — '
                'nobody owns the journey, so delays surface only when the destination '
                'chases the load.',
                ['Require a carrier or driver before a transfer can move to in-transit.',
                 'Default to the lane\'s most-used carrier when the approver does not pick one.',
                 'Surface unassigned transfers as a badge on the logistics dashboard.'],
                [{'label': 'Unassigned', 'value': str(len(unassigned))},
                 {'label': 'Of active', 'value': f'{100 * len(unassigned) / max(1, len([r for r in rows if r["status"] in ("requested", "approved", "in_transit")])):.0f}%'}],
                [{'reference': r['reference'], 'label': r['lane'],
                  'detail': f"{r['units']:,} units · {r['priority']}",
                  'value': f"KES {r['value']:,.0f}"} for r in unassigned[:5]],
                quick_win=True)

        # ── 4. Missing delivery ETAs ───────────────────────────────────
        no_eta = [r for r in rows
                  if r['status'] in ('requested', 'approved', 'in_transit')
                  and not r['scheduled_delivery']]
        if no_eta:
            add('missing-eta', 'Most transfers carry no delivery ETA',
                'process',
                'high' if (kpis.get('on_time_pct') is None) else 'medium',
                'medium', 'low',
                f'{len(no_eta)} active transfer'
                f'{"s" if len(no_eta) != 1 else ""} have no scheduled delivery date, '
                'so on-time performance cannot be measured.',
                'Without an ETA there is no commitment to hold anyone to — the platform '
                'reports "no ETA recorded" instead of a real reliability figure. Setting '
                'even a default lead time turns that into a measurable target.',
                ['Default the delivery date to request + 2 days based on lane history.',
                 'Capture the ETA in the transfer wizard as a required field.',
                 'Flag ETA-less transfers on the analytics dashboard.'],
                [{'label': 'No ETA', 'value': str(len(no_eta))},
                 {'label': 'On-time', 'value': pct_label(kpis.get('on_time_pct'))}],
                [{'reference': r['reference'], 'label': r['lane'],
                  'detail': f"{r['priority']} · {r['status'].replace('_', ' ')}",
                  'value': f"KES {r['value']:,.0f}"} for r in no_eta[:5]],
                quick_win=True)

        # ── 5. Receipt accuracy ────────────────────────────────────────
        disc = [r for r in completed if r['variance'] != 0]
        if disc:
            value_gap = sum(abs(r['variance']) *
                            (r['value'] / r['units'] if r['units'] else 0) for r in disc)
            rate = 100.0 * len(disc) / max(1, len(completed))
            add('receipt-accuracy', 'Receipts keep coming up short',
                'accuracy',
                'critical' if rate > 25 else 'high' if rate > 12 else 'medium',
                'high', 'medium',
                f'{len(disc)} of {len(completed)} completed transfers '
                f'({rate:.0f}%) closed with a unit variance, '
                f'a combined gap of {sum(abs(r["variance"]) for r in disc):,} units.',
                'Short receipts usually mean the load was split, damaged, or counted '
                'in a hurry at the destination. Each one silently corrupts stock '
                'levels at both ends of the lane.',
                ['Require a variance reason and photo on any receipt that does not match.',
                 'Scan batch barcodes at dispatch and receipt instead of counting by hand.',
                 'Recount any line with a variance the next working day.'],
                [{'label': 'Variance rate', 'value': f'{rate:.0f}%'},
                 {'label': 'Units missing', 'value': f'{sum(abs(r["variance"]) for r in disc):,}'},
                 {'label': 'Value gap', 'value': f'KES {value_gap:,.0f}'}],
                [{'reference': r['reference'], 'label': r['lane'],
                  'detail': f"{r['received']:,} of {r['units']:,} units received",
                  'value': f"{r['variance']:+d}"} for r in disc[:5]],
                save_value=value_gap)

        # ── 6. Lane imbalance ──────────────────────────────────────────
        lane_pairs = defaultdict(lambda: {'out': 0, 'back': 0,
                                          'out_units': 0, 'back_units': 0,
                                          'out_value': 0.0, 'transit': []})
        for r in rows:
            key = tuple(sorted((r['source'], r['dest'])))
            entry = lane_pairs[key]
            if r['source'] == key[0]:
                entry['out'] += 1
                entry['out_units'] += r['units']
                entry['out_value'] += r['value']
            else:
                entry['back'] += 1
                entry['back_units'] += r['units']
            if r['transit_h'] is not None:
                entry['transit'].append(r['transit_h'])

        imbalanced = []
        for (a, b), v in lane_pairs.items():
            heavy, light = max(v['out'], v['back']), min(v['out'], v['back'])
            if heavy >= 3 and (light == 0 or heavy / max(1, light) >= 2.5):
                imbalanced.append({
                    'lane': f'{a} ⇄ {b}',
                    'dominant': a if v['out'] >= v['back'] else b,
                    'dominant_count': heavy,
                    'return_count': light,
                    'units': v['out_units'] + v['back_units'],
                    'value': round(v['out_value'], 2),
                    'ratio': round(heavy / max(1, light), 1),
                    'avg_transit_hours': avg(v['transit']),
                })
        imbalanced.sort(key=lambda x: -x['dominant_count'])
        if imbalanced:
            top = imbalanced[:5]
            add('lane-imbalance', 'One-way lanes mean empty return trips',
                'balance',
                'high' if imbalanced[0]['ratio'] >= 4 else 'medium',
                'high', 'high',
                f'{len(imbalanced)} lane pair'
                f'{"s" if len(imbalanced) != 1 else ""} move freight almost entirely '
                f'in one direction — the worst runs {imbalanced[0]["ratio"]:.1f}:1.',
                'A lane that only flows one way pays for a full return journey with '
                'nothing on board. Rebalancing the return leg — even partially — '
                'cuts cost per unit without buying new capacity.',
                ['Batch return loads: hold non-urgent transfers to the dominant '
                 'destination until a return leg is available.',
                 'Quote the empty return leg to neighbouring branches as cheap capacity.',
                 'Review whether the dominant direction is caused by over-ordering.'],
                [{'label': 'Imbalanced lanes', 'value': str(len(imbalanced))},
                 {'label': 'Worst ratio', 'value': f'{imbalanced[0]["ratio"]:.1f}:1'},
                 {'label': 'Trips involved', 'value': f'{sum(x["dominant_count"] for x in imbalanced)}'}],
                [{'reference': x['lane'],
                  'label': f"{x['dominant_count']} out · {x['return_count']} back",
                  'detail': f"ratio {x['ratio']:.1f}:1 · {x['units']:,} units",
                  'value': f"KES {x['value']:,.0f}"} for x in top])

        # ── 7. Consolidation opportunities ─────────────────────────────
        consolidated = []
        lane_windows = defaultdict(list)
        for r in rows:
            if r['status'] == 'completed':
                continue
            lane_windows[r['lane']].append(r)
        for lane, group in lane_windows.items():
            group.sort(key=lambda r: r['requested_at'])
            cluster = []
            for r in group:
                if cluster and (r['requested_at'] - cluster[-1]['requested_at']).days <= 2:
                    cluster.append(r)
                else:
                    if len(cluster) >= 2:
                        consolidated.append({'lane': lane, 'transfers': cluster})
                    cluster = [r]
            if len(cluster) >= 2:
                consolidated.append({'lane': lane, 'transfers': cluster})
        consolidated = [c for c in consolidated if len(c['transfers']) >= 2]
        if consolidated:
            trips_saved = sum(len(c['transfers']) - 1 for c in consolidated)
            units = sum(sum(r['units'] for r in c['transfers']) for c in consolidated)
            value = sum(sum(r['value'] for r in c['transfers']) for c in consolidated)
            add('consolidation', 'Open transfers on the same lane can share a trip',
                'cost',
                'high' if trips_saved >= 3 else 'medium',
                'high', 'medium',
                f'{trips_saved} trip{"s" if trips_saved != 1 else ""} could be saved by '
                f'merging {sum(len(c["transfers"]) for c in consolidated)} open transfers '
                f'into {len(consolidated)} consolidated run'
                f'{"s" if len(consolidated) != 1 else ""}.',
                'Two or three small transfers dispatched to the same branch within a '
                'couple of days each pay the full fixed cost of a journey. Merging them '
                'into one run cuts fuel, handling and driver time with no loss of service.',
                ['Group open transfers by lane and only dispatch when a full load '
                 'or the SLA deadline is reached, whichever comes first.',
                 'Offer a "merge into next run" option when creating a transfer.',
                 'Set a minimum load size per lane before a dedicated trip is allowed.'],
                [{'label': 'Trips saved', 'value': str(trips_saved)},
                 {'label': 'Transfers merged', 'value': f'{sum(len(c["transfers"]) for c in consolidated)}'},
                 {'label': 'Units involved', 'value': f'{units:,}'}],
                [{'reference': c['lane'],
                  'label': f"{len(c['transfers'])} transfers",
                  'detail': ' · '.join(r['reference'] for r in c['transfers'][:4]),
                  'value': f"KES {sum(r['value'] for r in c['transfers']):,.0f}"}
                 for c in consolidated[:5]],
                save_value=value)

        # ── 8. Priority discipline ─────────────────────────────────────
        urgent = [r for r in rows if r['priority'] in ('high', 'urgent')]
        if urgent:
            urgent_slow = [r for r in urgent
                           if (r['cycle_h'] is not None and r['cycle_h'] > CYCLE_TARGET_H)
                           or (r['status'] in OPEN and r['age_days'] > 2)]
            share = 100.0 * len(urgent) / max(1, total)
            if urgent_slow or share > 40:
                add('priority-discipline', 'Priority flags have stopped meaning anything',
                    'process',
                    'high' if len(urgent_slow) >= 3 else 'medium',
                    'medium', 'low',
                    f'{share:.0f}% of transfers are flagged high or urgent, and '
                    f'{len(urgent_slow)} of them still ran past the '
                    f'{CYCLE_TARGET_H:.0f}h cycle target.',
                    'When most work is urgent, nothing is. Priority should reserve '
                    'expedited handling for genuine stock-outs — otherwise the fast '
                    'path gets as congested as the normal one.',
                    ['Reserve "urgent" for lines that would stock out within 48 hours.',
                     'Report the share of urgent volume per branch every week.',
                     'Auto-downgrade urgent flags that were not actioned within a day.'],
                    [{'label': 'High/urgent', 'value': f'{len(urgent)} ({share:.0f}%)'},
                     {'label': 'Missed target', 'value': str(len(urgent_slow))}],
                    [{'reference': r['reference'], 'label': r['lane'],
                      'detail': f"{r['priority']} · {r['status'].replace('_', ' ')}",
                      'value': (f"{r['cycle_h']:.0f}h" if r['cycle_h'] is not None
                                else f"{r['age_days']:.0f}d open")}
                     for r in (urgent_slow or urgent)[:5]],
                    quick_win=True)

        # ── 9. Draft backlog ───────────────────────────────────────────
        drafts = [r for r in rows if r['status'] == 'draft']
        if len(drafts) >= 2:
            add('draft-backlog', 'Drafts are piling up and never get submitted',
                'process',
                'medium' if len(drafts) < 5 else 'high',
                'low', 'low',
                f'{len(drafts)} transfers were created but never submitted, worth '
                f'KES {sum(r["value"] for r in drafts):,.0f}.',
                'Abandoned drafts clutter the list and hide the real workload. They also '
                'suggest the wizard is being used as a scratchpad rather than a '
                'commitment.',
                ['Auto-expire drafts after 7 days with a notification to the creator.',
                 'Show a "finish or discard" prompt the next time the author opens the page.',
                 'Pre-fill drafts from the last transfer on the same lane.'],
                [{'label': 'Drafts', 'value': str(len(drafts))},
                 {'label': 'Value', 'value': f'KES {sum(r["value"] for r in drafts):,.0f}'}],
                [{'reference': r['reference'], 'label': r['lane'],
                  'detail': f"{r['age_days']:.0f} days old",
                  'value': f"KES {r['value']:,.0f}"} for r in drafts[:5]],
                quick_win=True)

        # ── 10. Expiry risk ────────────────────────────────────────────
        expiring = []
        horizon = today + _td(days=90)
        for r in rows:
            if r['status'] not in OPEN:
                continue
            for batch in r['batches']:
                if not batch or not batch.expiry_date:
                    continue
                if batch.expiry_date <= horizon:
                    days_left = (batch.expiry_date - today).days
                    expiring.append({
                        'reference': r['reference'],
                        'lane': r['lane'],
                        'stock': batch.stock.medication_name,
                        'batch': batch.batch_number,
                        'expiry': batch.expiry_date.isoformat(),
                        'days_left': days_left,
                        'quantity': batch.quantity_remaining,
                    })
        expiring.sort(key=lambda x: x['days_left'])
        if expiring:
            add('expiry-risk', 'In-flight stock is close to expiry',
                'risk',
                'critical' if expiring[0]['days_left'] <= 30 else 'high',
                'medium', 'low',
                f'{len(expiring)} batch pick'
                f'{"s" if len(expiring) != 1 else ""} on open transfers expire within '
                f'90 days — the soonest in {max(0, expiring[0]["days_left"])} days.',
                'Sending near-expiry stock to another branch just moves the problem. '
                'Either the receiving branch sells it fast or it expires on their '
                'shelf instead of yours.',
                ['Prioritise dispatching these batches and flag them as short-dated '
                 'at the destination.',
                 'Offer short-dated stock to high-velocity branches first.',
                 'Block transfers of batches under 30 days to expiry without approval.'],
                [{'label': 'Batches at risk', 'value': str(len(expiring))},
                 {'label': 'Soonest', 'value': f'{max(0, expiring[0]["days_left"])} days'},
                 {'label': 'Units', 'value': f'{sum(x["quantity"] or 0 for x in expiring):,}'}],
                [{'reference': x['reference'], 'label': x['stock'],
                  'detail': f"Batch {x['batch']} · expires {x['expiry']}",
                  'value': f"{x['days_left']}d"} for x in expiring[:5]],
                quick_win=True)

        # ── 11. Carrier performance spread ─────────────────────────────
        carrier_stats = defaultdict(lambda: {'count': 0, 'transit': [], 'on_time': []})
        for r in rows:
            if not r['carrier']:
                continue
            c = carrier_stats[r['carrier']]
            c['count'] += 1
            if r['transit_h'] is not None:
                c['transit'].append(r['transit_h'])
            if r['scheduled_delivery'] and r['received_at']:
                c['on_time'].append(r['received_at'] <= r['scheduled_delivery'])
        carriers = []
        for name, c in carrier_stats.items():
            carriers.append({
                'name': name,
                'shipments': c['count'],
                'avg_transit_hours': avg(c['transit']),
                'on_time_pct': (100.0 * c['on_time'].count(True) / len(c['on_time'])
                                if c['on_time'] else None),
            })
        carriers.sort(key=lambda x: -x['shipments'])
        slow_carriers = [c for c in carriers
                         if c['avg_transit_hours'] is not None
                         and avg_transit and c['avg_transit_hours'] > avg_transit * 1.4]
        if len(carriers) >= 2 and slow_carriers:
            add('carrier-spread', 'Carrier performance varies widely by lane',
                'cost',
                'medium', 'medium', 'medium',
                f'{len(slow_carriers)} of {len(carriers)} carriers run at least 40% '
                f'slower than the network average of {avg_transit:.1f}h in transit.',
                'Transit time differences of this size usually come from route choice '
                'and load scheduling rather than distance. Shifting volume to the '
                'faster carriers is the cheapest speed improvement available.',
                ['Review the slowest carrier first and confirm the delays are theirs, '
                 'not queue time at the dock.',
                 'Weight carrier selection by measured transit time per lane.',
                 'Set a maximum acceptable transit time per lane and alert on breaches.'],
                [{'label': 'Carriers', 'value': str(len(carriers))},
                 {'label': 'Below avg', 'value': str(len(slow_carriers))},
                 {'label': 'Network transit', 'value': f'{avg_transit:.1f}h'}],
                [{'reference': c['name'], 'label': f"{c['shipments']} shipments",
                  'detail': f"{c['avg_transit_hours']:.1f}h transit",
                  'value': pct_label(c['on_time_pct'])} for c in slow_carriers[:5]])

        # ── 12. Value concentration ────────────────────────────────────
        lane_value = defaultdict(float)
        for r in rows:
            lane_value[tuple(sorted((r['source'], r['dest'])))] += r['value']
        total_value = sum(lane_value.values()) or 1.0
        top_lane, top_value = max(lane_value.items(), key=lambda kv: kv[1])
        concentration = 100.0 * top_value / total_value
        if concentration >= 45 and len(lane_value) > 1:
            add('value-concentration', 'One lane carries most of the transfer value',
                'risk',
                'medium', 'medium', 'high',
                f'{concentration:.0f}% of transferred value moves on a single lane '
                f'({top_lane[0]} ⇄ {top_lane[1]}).',
                'A network that depends on one corridor has no slack: a road closure, '
                'a fleet breakdown or a stock-out at either end stops the bulk of the '
                'flow. Secondary lanes are also where the cheaper consolidation '
                'opportunities hide.',
                ['Build a secondary supply path for the top three items on that lane.',
                 'Keep a safety stock buffer at both ends of the dominant corridor.',
                 'Track lane-level value concentration as a monthly resilience metric.'],
                [{'label': 'Top lane share', 'value': f'{concentration:.0f}%'},
                 {'label': 'Lane value', 'value': f'KES {top_value:,.0f}'},
                 {'label': 'Active lanes', 'value': str(len(lane_value))}])

        # ── 13. Small-load dispatch ────────────────────────────────────
        small = [r for r in rows if r['status'] == 'completed' and r['units'] > 0
                 and r['units'] <= 25]
        if len(small) >= 3 and len(small) / max(1, len(completed)) >= 0.3:
            add('small-loads', 'Many trips carry very small loads',
                'cost',
                'medium', 'medium', 'medium',
                f'{len(small)} of {len(completed)} completed transfers moved 25 units '
                f'or fewer ({100 * len(small) / max(1, len(completed)):.0f}% of all runs).',
                'Fixed trip costs — driver time, fuel, dock handling — dominate the '
                'economics of a short run. Consolidating or scheduling small loads onto '
                'shared runs usually beats dispatching them on demand.',
                ['Introduce a scheduled milk-run for small loads on high-frequency lanes.',
                 'Show the estimated cost per unit at the point of creating a transfer.',
                 'Encourage branches to order in fewer, larger batches.'],
                [{'label': 'Small runs', 'value': str(len(small))},
                 {'label': 'Avg load', 'value': f'{avg([r["units"] for r in small]) or 0:.0f} units'},
                 {'label': 'Share of runs', 'value': f'{100 * len(small) / max(1, len(completed)):.0f}%'}],
                [{'reference': r['reference'], 'label': r['lane'],
                  'detail': f"{r['units']:,} units",
                  'value': f"KES {r['value']:,.0f}"} for r in small[:5]])

        # ── 14. Weekday concentration ──────────────────────────────────
        weekday_counts = defaultdict(int)
        for r in rows:
            if r['requested_at']:
                weekday_counts[timezone.localtime(r['requested_at']).strftime('%A')] += 1
        if weekday_counts and total >= 6:
            top_day, top_count = max(weekday_counts.items(), key=lambda kv: kv[1])
            day_share = 100.0 * top_count / total
            if day_share >= 45:
                add('weekday-peak', f'{top_day} concentration is straining dispatch',
                    'process',
                    'medium', 'low', 'low',
                    f'{day_share:.0f}% of all transfers are raised on {top_day}.',
                    'A sharp weekly peak means the dispatch desk and the fleet are '
                    'idle most of the week and overloaded on one day — which is '
                    'exactly when approval and loading delays creep in.',
                    ['Spread replenishment requests across the week per branch.',
                     'Schedule approval cover for the peak day.',
                     'Pre-build peak-day loads the afternoon before.'],
                    [{'label': 'Peak day', 'value': top_day},
                     {'label': 'Share', 'value': f'{day_share:.0f}%'},
                     {'label': 'Volume', 'value': str(top_count)}],
                    quick_win=True)

        recs.sort(key=lambda r: -r['score'])
        for idx, rec in enumerate(recs, 1):
            rec['rank'] = idx

        # ═══════════════════ STAGE FUNNEL ══════════════════════════════
        funnel = [
            {'key': 'draft', 'label': 'Draft', 'count': 0, 'target_hours': None},
            {'key': 'requested', 'label': 'Awaiting approval', 'count': 0,
             'target_hours': APPROVAL_TARGET_H},
            {'key': 'in_transit', 'label': 'In transit', 'count': 0,
             'target_hours': TRANSIT_TARGET_H},
            {'key': 'completed', 'label': 'Received', 'count': 0, 'target_hours': None},
        ]
        funnel_by_key = {f['key']: f for f in funnel}
        for r in rows:
            key = 'completed' if r['status'] == 'completed' else (
                'draft' if r['status'] == 'draft' else (
                    'in_transit' if r['status'] == 'in_transit' else 'requested'))
            if key in funnel_by_key:
                funnel_by_key[key]['count'] += 1
        funnel_by_key['requested']['avg_hours'] = avg_approval
        funnel_by_key['in_transit']['avg_hours'] = avg_transit
        funnel_by_key['completed']['avg_hours'] = avg_cycle
        funnel_by_key['draft']['avg_hours'] = None

        # ═══════════════════ LANE TABLE ════════════════════════════════
        lane_rows = []
        for (a, b), v in lane_pairs.items():
            total_lane = v['out'] + v['back']
            heavy = max(v['out'], v['back'])
            lane_rows.append({
                'lane': f'{a} ⇄ {b}',
                'forward': v['out'],
                'reverse': v['back'],
                'total': total_lane,
                'units': v['out_units'] + v['back_units'],
                'value': round(v['out_value'], 2),
                'avg_transit_hours': avg(v['transit']),
                'balance_pct': round(100.0 * min(v['out'], v['back']) / max(1, heavy), 0),
            })
        lane_rows.sort(key=lambda x: -x['total'])

        # ═══════════════════ BRANCH SCORECARD ══════════════════════════
        branch_stats = defaultdict(lambda: {
            'out': 0, 'in': 0, 'cycles': [], 'variances': 0, 'completed': 0,
            'on_time': [], 'value': 0.0,
        })
        for r in rows:
            out_b = branch_stats[r['source']]
            in_b = branch_stats[r['dest']]
            out_b['out'] += 1
            out_b['value'] += r['value']
            in_b['in'] += 1
            if r['cycle_h'] is not None:
                in_b['cycles'].append(r['cycle_h'])
            if r['status'] == 'completed':
                in_b['completed'] += 1
                if r['variance']:
                    in_b['variances'] += 1
                if r['scheduled_delivery'] and r['received_at']:
                    in_b['on_time'].append(r['received_at'] <= r['scheduled_delivery'])

        scorecard = []
        network_accuracy = accuracy
        network_reliability = reliability
        for name, s in branch_stats.items():
            # Small samples are noisy: a branch with one short receipt should not
            # be scored 0% accuracy. Blend toward the network figure instead.
            if s['completed'] >= 3:
                accuracy_b = 100.0 * (s['completed'] - s['variances']) / s['completed']
            elif s['completed'] == 0:
                accuracy_b = network_accuracy
            else:
                own = 100.0 * (s['completed'] - s['variances']) / s['completed']
                weight = s['completed'] / 3.0
                accuracy_b = own * weight + network_accuracy * (1 - weight)

            speed_b = speed_score(avg(s['cycles']) or 0, CYCLE_TARGET_H)
            if len(s['on_time']) >= 3:
                rel_b = 100.0 * s['on_time'].count(True) / len(s['on_time'])
            elif s['on_time']:
                own = 100.0 * s['on_time'].count(True) / len(s['on_time'])
                weight = len(s['on_time']) / 3.0
                rel_b = own * weight + network_reliability * (1 - weight)
            else:
                rel_b = network_reliability

            score_b = round(clamp(0.45 * speed_b + 0.35 * accuracy_b + 0.20 * rel_b), 1)
            scorecard.append({
                'branch': name,
                'dispatched': s['out'],
                'received': s['in'],
                'completed': s['completed'],
                'value': round(s['value'], 2),
                'avg_cycle_hours': avg(s['cycles']),
                'accuracy_pct': round(accuracy_b, 1),
                'reliability_pct': round(rel_b, 1),
                'score': score_b,
                'grade': ('A' if score_b >= 85 else 'B' if score_b >= 72 else
                          'C' if score_b >= 58 else 'D'),
            })
        scorecard.sort(key=lambda x: -x['score'])

        # ═══════════════════ TOTALS ════════════════════════════════════
        quick_wins = [r for r in recs if r['quick_win']]
        return {
            'filters': filters,
            'scope': {
                'transfers': total,
                'open': len(open_rows),
                'completed': len(completed),
                'units': kpis.get('units') or 0,
                'value': kpis.get('value') or 0,
                'lanes': len(lane_rows),
                'avg_approval_hours': avg_approval,
                'avg_transit_hours': avg_transit,
                'avg_cycle_hours': avg_cycle,
            },
            'score': {
                'overall': overall,
                'grade': grade,
                'label': grade_label,
                'pillars': pillars,
            },
            'summary': {
                'recommendations': len(recs),
                'quick_wins': len(quick_wins),
                'critical': sum(1 for r in recs if r['severity'] == 'critical'),
                'high': sum(1 for r in recs if r['severity'] == 'high'),
                'potential_hours': round(sum(r['save_hours'] for r in recs), 1),
                'potential_value': round(sum(r['save_value'] for r in recs), 2),
                'value_at_risk': round(sum(r['value'] for r in open_rows), 2),
                'units_at_risk': sum(r['units'] for r in open_rows),
            },
            'recommendations': recs,
            'funnel': funnel,
            'lanes': lane_rows[:10],
            'consolidation': [{
                'lane': c['lane'],
                'count': len(c['transfers']),
                'units': sum(r['units'] for r in c['transfers']),
                'value': round(sum(r['value'] for r in c['transfers']), 2),
                'references': [r['reference'] for r in c['transfers']],
            } for c in consolidated[:6]],
            'expiry_risk': expiring[:8],
            'carriers': carriers[:8],
            'scorecard': scorecard,
        }

    @action(detail=False, methods=['get'], url_path='optimization-pdf')
    def optimization_pdf(self, request):
        """Branded PDF of the transfer optimisation plan.

        Page 1 summarises the health score, pillars and stage funnel; page 2
        lists the ranked recommendations with their action plans; page 3 closes
        with lanes, consolidation, expiry risk and the branch scorecard.
        """
        import io as _io
        from reportlab.lib.pagesizes import A4, landscape
        from reportlab.lib.units import mm
        from reportlab.lib.colors import HexColor, white
        from reportlab.lib.styles import ParagraphStyle
        from reportlab.lib.enums import TA_CENTER, TA_RIGHT, TA_LEFT
        from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer,
                                        Table, TableStyle, HRFlowable, PageBreak)
        from reportlab.graphics.shapes import (Drawing, Rect, Circle, Wedge,
                                               String as GString)

        payload = self._optimization_payload(request)
        scope = payload['scope']
        score = payload['score']
        summary = payload['summary']
        recs = payload['recommendations']
        funnel = payload['funnel']
        lane_rows = payload['lanes']
        consolidation = payload['consolidation']
        expiry_risk = payload['expiry_risk']
        carrier_rows = payload['carriers']
        scorecard = payload['scorecard']
        filters = payload['filters']

        # ── Branding ────────────────────────────────────────────────────
        from config.pdf_branding import resolve_branding

        logo_path, business_name = None, ''
        try:
            logo_path, business_name = resolve_branding(request)
        except (ImportError, NotImplementedError, OSError, ValueError,
                AttributeError) as exc:
            logger.warning('Optimization PDF: branding unavailable (%s)', exc)
        tenant = getattr(request, 'tenant', None)
        business_name = business_name or getattr(tenant, 'name', '') or 'AdhereMed'

        def _brand_hex(attr, default):
            raw = getattr(tenant, attr, '') if tenant else ''
            if isinstance(raw, str):
                raw = raw.strip()
                if len(raw) == 7 and raw.startswith('#'):
                    try:
                        int(raw[1:], 16)
                        return '#' + raw[1:].upper()
                    except ValueError:
                        pass
            return default

        BRAND = _brand_hex('brand_primary', '#2F6DFF')
        DEEP = _brand_hex('brand_secondary', '#143CE1')
        ACCENT_SOURCE = _brand_hex('brand_accent', '#37D6FF')

        NAVY = '#0F172A'
        SLATE = '#64748B'
        BORDER = '#E2E8F0'
        TRACK = '#EDF1F7'
        GREEN = '#16A34A'
        RED = '#DC2626'
        AMBER = '#F59E0B'
        TEAL = '#14B8A6'
        GREY = '#94A3B8'

        def _rgb(hex_color):
            h = str(hex_color).lstrip('#')
            return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

        def mix(hex_color, factor):
            r, g, b = _rgb(hex_color)
            if factor >= 0:
                r, g, b = (round(v + (255 - v) * factor) for v in (r, g, b))
            else:
                r, g, b = (round(v * (1 + factor)) for v in (r, g, b))
            return '#%02X%02X%02X' % (r, g, b)

        def blend(a_hex, b_hex, amount):
            a, b = _rgb(a_hex), _rgb(b_hex)
            t = min(max(amount, 0.0), 1.0)
            return '#%02X%02X%02X' % tuple(
                round(a[i] + (b[i] - a[i]) * t) for i in range(3))

        ACCENT = blend(ACCENT_SOURCE, BRAND, 0.55)

        def _grad_at(t):
            stops = ((0.0, _rgb(DEEP)), (0.52, _rgb(BRAND)), (1.0, _rgb(ACCENT)))
            if t <= stops[0][0]:
                return stops[0][1]
            for i in range(len(stops) - 1):
                t0, c0 = stops[i]
                t1, c1 = stops[i + 1]
                if t <= t1:
                    f = (t - t0) / (t1 - t0) if t1 > t0 else 0
                    return tuple(c0[k] + (c1[k] - c0[k]) * f for k in range(3))
            return stops[-1][1]

        def money(v):
            try:
                return f'KES {float(v or 0):,.0f}'
            except (TypeError, ValueError):
                return 'KES 0'

        def ints(v):
            try:
                return f'{int(v or 0):,}'
            except (TypeError, ValueError):
                return '0'

        def fmt_hours(v):
            if v is None:
                return '—'
            try:
                h = float(v)
            except (TypeError, ValueError):
                return '—'
            if h < 1:
                return f'{round(h * 60)}m'
            if h < 48:
                return f'{h:.1f}h'
            return f'{h / 24:.1f}d'

        def tone_for(value):
            try:
                v = float(value)
            except (TypeError, ValueError):
                return GREY
            if v >= 84:
                return GREEN
            if v >= 70:
                return TEAL
            if v >= 58:
                return AMBER
            return RED

        SEV_HEX = {'critical': RED, 'high': '#EA580C', 'medium': AMBER, 'low': GREY}

        period_label = 'All time'
        if filters.get('date_from'):
            def _pretty(iso):
                try:
                    from datetime import datetime as _dtp
                    return _dtp.strptime(str(iso), '%Y-%m-%d').strftime('%b %d %Y')
                except (TypeError, ValueError):
                    return str(iso)
            period_label = (f"{_pretty(filters['date_from'])} – "
                            f"{_pretty(filters.get('date_to') or timezone.localdate())}")

        branch_label = 'All branches'
        if filters.get('branch'):
            try:
                obj = Branch.objects.filter(id=filters['branch']).first()
                branch_label = obj.name if obj else f"Branch #{filters['branch']}"
            except Exception:
                branch_label = f"Branch #{filters['branch']}"

        # ── Styles ──────────────────────────────────────────────────────
        st_card_title = ParagraphStyle('oct', fontName='Helvetica-Bold', fontSize=9.5,
                                       textColor=HexColor(NAVY), leading=12)
        st_card_sub = ParagraphStyle('ocs', fontName='Helvetica', fontSize=6.5,
                                     textColor=HexColor(SLATE), leading=8.5)
        st_cap = ParagraphStyle('ocap', fontName='Helvetica', fontSize=6,
                                textColor=HexColor(SLATE), leading=8)
        st_cap_r = ParagraphStyle('ocapr', parent=st_cap, alignment=TA_RIGHT)
        st_cell = ParagraphStyle('ocell', fontName='Helvetica', fontSize=7,
                                 textColor=HexColor(NAVY), leading=9)
        st_cell_b = ParagraphStyle('ocellb', parent=st_cell, fontName='Helvetica-Bold')
        st_cell_r = ParagraphStyle('ocellr', parent=st_cell, alignment=TA_RIGHT)
        st_body = ParagraphStyle('obody', fontName='Helvetica', fontSize=7.2,
                                 textColor=HexColor(NAVY), leading=10.5)
        st_colhead = ParagraphStyle('och', fontName='Helvetica-Bold', fontSize=6,
                                    textColor=HexColor(SLATE), leading=8)
        st_colhead_r = ParagraphStyle('ochr', parent=st_colhead, alignment=TA_RIGHT)
        st_scope_label = ParagraphStyle('osl', fontName='Helvetica-Bold', fontSize=5.6,
                                        textColor=HexColor(SLATE), leading=7.5)
        st_scope_value = ParagraphStyle('osv', fontName='Helvetica-Bold', fontSize=9,
                                        textColor=HexColor(NAVY), leading=11.5)
        st_note = ParagraphStyle('onote', fontName='Helvetica-Oblique', fontSize=6.5,
                                 textColor=HexColor(SLATE), leading=9)
        st_rec_title = ParagraphStyle('ort', fontName='Helvetica-Bold', fontSize=9.5,
                                      textColor=HexColor(NAVY), leading=11.5)
        st_rec_summary = ParagraphStyle('ors', fontName='Helvetica', fontSize=7,
                                        textColor=HexColor('#334155'), leading=9.6)
        st_action = ParagraphStyle('oac', fontName='Helvetica', fontSize=6.6,
                                   textColor=HexColor('#334155'), leading=9,
                                   leftIndent=7, bulletIndent=0)

        def chip(text, color_hex, size=5.8):
            style = ParagraphStyle(
                f'ochip{size}{color_hex}', fontName='Helvetica-Bold', fontSize=size,
                leading=size + 2.2, alignment=TA_CENTER,
                textColor=HexColor(mix(color_hex, -0.28)),
                backColor=HexColor(mix(color_hex, 0.84)), borderPadding=1.7,
            )
            return Paragraph(str(text).upper(), style)

        def dot(color_hex, size=5.2):
            d = Drawing(size, size)
            d.add(Circle(size / 2, size / 2, size / 2, fillColor=HexColor(color_hex),
                         strokeWidth=0))
            return d

        def bar(frac, color_hex, width, height=4.2, target=None):
            d = Drawing(width, height)
            d.add(Rect(0, 0, width, height, fillColor=HexColor(TRACK), strokeWidth=0))
            filled = max(1.2, width * min(1.0, max(0.0, frac or 0)))
            d.add(Rect(0, 0, filled, height, fillColor=HexColor(color_hex), strokeWidth=0))
            if target is not None:
                tx = width * min(1.0, max(0.0, target))
                d.add(Rect(tx - 0.4, -0.7, 0.9, height + 1.4,
                           fillColor=HexColor('#94A3B8'), strokeWidth=0))
            return d

        # ── Geometry ────────────────────────────────────────────────────
        W, H = landscape(A4)
        MARGIN = 14 * mm
        CONTENT_W = W - 2 * MARGIN
        GAP = 5 * mm
        HALF_W = (CONTENT_W - GAP) / 2

        def _has_logo():
            return bool(logo_path) and os.path.exists(logo_path)

        def _draw_trailing_logo(canv, band_bottom, band_h, box, pad=1.5 * mm):
            if not _has_logo():
                return 0.0
            tile = box + 2 * pad
            x = W - MARGIN - 5 * mm - tile
            y = band_bottom + (band_h - tile) / 2
            canv.saveState()
            canv.setFillColor(white)
            canv.roundRect(x, y, tile, tile, 2.2 * mm, stroke=0, fill=1)
            try:
                canv.drawImage(logo_path, x + pad, y + pad, box, box,
                               preserveAspectRatio=True, anchor='c', mask='auto')
            except (OSError, ValueError, TypeError):
                canv.restoreState()
                return 0.0
            canv.restoreState()
            return tile

        def _fit(canv, text, font_name, font_size, max_width):
            if not text:
                return ''
            if canv.stringWidth(text, font_name, font_size) <= max_width:
                return text
            ell = '...'
            lo, hi = 0, len(text)
            while lo < hi:
                mid = (lo + hi + 1) // 2
                if canv.stringWidth(text[:mid] + ell, font_name, font_size) <= max_width:
                    lo = mid
                else:
                    hi = mid - 1
            return (text[:lo].rstrip() + ell) if lo else ''

        def _page(canv, doc):
            canv.saveState()
            page_no = canv.getPageNumber()
            right_edge = W - MARGIN - 5 * mm
            left_x = MARGIN + 5 * mm
            if page_no == 1:
                band_top = H - 10 * mm
                band_h = 24 * mm
                band_bottom = band_top - band_h
                canv.saveState()
                path = canv.beginPath()
                path.roundRect(MARGIN, band_bottom, CONTENT_W, band_h, 3 * mm)
                canv.clipPath(path, stroke=0, fill=0)
                steps = 150
                slice_w = CONTENT_W / steps
                for i in range(steps):
                    r, g, b = _grad_at(i / (steps - 1))
                    canv.setFillColorRGB(r / 255, g / 255, b / 255)
                    canv.rect(MARGIN + i * slice_w, band_bottom,
                              slice_w + 0.8, band_h, stroke=0, fill=1)
                canv.restoreState()
            else:
                band_top = H - 10 * mm
                band_h = 17 * mm
                band_bottom = band_top - band_h
                canv.setFillColor(HexColor('#F6F8FC'))
                canv.rect(MARGIN, band_bottom, CONTENT_W, band_h, stroke=0, fill=1)
                canv.setFillColor(HexColor(BRAND))
                canv.rect(MARGIN, band_bottom, 2.6 * mm, band_h, stroke=0, fill=1)

            tile = _draw_trailing_logo(canv, band_bottom, band_h,
                                       15 * mm if page_no == 1 else 11 * mm,
                                       pad=1.5 * mm if page_no == 1 else 1.2 * mm)
            text_right = right_edge - (tile + (6 * mm if page_no == 1 else 5 * mm)
                                       if tile else 0)

            if page_no == 1:
                canv.setFillColor(white)
                canv.setFont('Helvetica-Bold', 5.8)
                canv.drawString(left_x, H - 15.6 * mm,
                                'INVENTORY · LOGISTICS · OPTIMIZATION', charSpace=1.1)
                canv.setFont('Helvetica-Bold', 16)
                canv.drawString(left_x, H - 22.4 * mm, 'Transfer Optimization')
                canv.setFont('Helvetica', 7)
                canv.drawString(left_x, H - 27.4 * mm,
                                _fit(canv,
                                     'A ranked plan to cut cycle time, tighten receipts '
                                     'and stop paying for empty return trips',
                                     'Helvetica', 7, text_right - left_x - 6 * mm))

                canv.setFont('Helvetica-Bold', 9.5)
                canv.drawRightString(text_right, H - 16.4 * mm, business_name[:52])
                canv.setFont('Helvetica', 6.6)
                canv.drawRightString(text_right, H - 21.2 * mm, f'Period: {period_label}')
                canv.drawRightString(text_right, H - 25 * mm, f'Scope: {branch_label}')
                canv.drawRightString(text_right, H - 28.8 * mm,
                                     'Generated '
                                     + timezone.localtime(timezone.now())
                                     .strftime('%b %d %Y, %I:%M %p'))
            else:
                canv.setFillColor(HexColor(NAVY))
                canv.setFont('Helvetica-Bold', 10)
                canv.drawString(left_x, H - 17.6 * mm, 'Transfer Optimization')
                canv.setFillColor(HexColor(SLATE))
                canv.setFont('Helvetica', 6.6)
                canv.drawString(left_x, H - 22.6 * mm,
                                _fit(canv,
                                     f'{business_name} · {branch_label} · {period_label}',
                                     'Helvetica', 6.6, text_right - left_x - 6 * mm))
                canv.setFillColor(HexColor(NAVY))
                canv.setFont('Helvetica-Bold', 7)
                canv.drawRightString(text_right, H - 18 * mm, business_name[:52])
                canv.setFillColor(HexColor(SLATE))
                canv.setFont('Helvetica', 6.6)
                canv.drawRightString(text_right, H - 23 * mm,
                                     'Optimization plan · continued')

            canv.setStrokeColor(HexColor(BORDER))
            canv.setLineWidth(0.6)
            canv.line(MARGIN, 12 * mm, W - MARGIN, 12 * mm)
            canv.setFillColor(HexColor(SLATE))
            canv.setFont('Helvetica', 6.8)
            canv.drawString(MARGIN, 7.6 * mm,
                            f'{business_name} · Transfer Optimization Plan')
            canv.setFont('Helvetica-Bold', 6.8)
            canv.setFillColor(HexColor(BRAND))
            canv.drawCentredString(W / 2, 7.6 * mm,
                                   'Powered by AdhereMed · www.adheremed.co')
            canv.setFont('Helvetica', 6.8)
            canv.setFillColor(HexColor(SLATE))
            canv.drawRightString(W - MARGIN, 7.6 * mm, f'Page {page_no}')
            canv.restoreState()

        buf = _io.BytesIO()
        doc = SimpleDocTemplate(
            buf, pagesize=landscape(A4),
            leftMargin=MARGIN, rightMargin=MARGIN,
            topMargin=34 * mm, bottomMargin=16 * mm,
            title='Transfer Optimization Plan',
            author=business_name,
        )
        flow = [Spacer(1, 1 * mm)]

        def card(title, subtitle, content, width):
            rows = [[Paragraph(title, st_card_title)]]
            if subtitle:
                rows.append([Paragraph(subtitle, st_card_sub)])
            rows += [[item] for item in content]
            tbl = Table(rows, colWidths=[width], hAlign='LEFT')
            tbl.setStyle(TableStyle([
                ('BOX', (0, 0), (-1, -1), 0.7, HexColor(BORDER)),
                ('BACKGROUND', (0, 0), (-1, -1), white),
                ('LEFTPADDING', (0, 0), (-1, -1), 8),
                ('RIGHTPADDING', (0, 0), (-1, -1), 8),
                ('TOPPADDING', (0, 0), (-1, -1), 1.5),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 1.5),
                ('TOPPADDING', (0, 0), (0, 0), 7),
                ('BOTTOMPADDING', (0, 0), (-1, 0), 0 if subtitle else 4),
                ('BOTTOMPADDING', (0, -1), (-1, -1), 7),
            ]))
            return tbl

        def two_col(left, right, left_w=None):
            lw = left_w or HALF_W
            rw = CONTENT_W - lw - GAP
            tbl = Table([[left, '', right]], colWidths=[lw, GAP, rw], hAlign='LEFT')
            tbl.setStyle(TableStyle([
                ('VALIGN', (0, 0), (-1, -1), 'TOP'),
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 0),
                ('TOPPADDING', (0, 0), (-1, -1), 0),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
            ]))
            return tbl

        # ── 1. Score + pillars + summary ────────────────────────────────
        gauge_size = 40 * mm
        gauge = Drawing(gauge_size, gauge_size)
        gauge_value = float(score.get('overall') or 0)
        gauge_color = tone_for(gauge_value)
        cx = gauge_size / 2
        radius = gauge_size / 2 - 3
        ring_w = 7
        gauge.add(Circle(cx, cx, radius - ring_w / 2, fillColor=HexColor(TRACK),
                         strokeWidth=0))
        gauge.add(Circle(cx, cx, radius - ring_w, fillColor=white, strokeWidth=0))
        sweep = 360.0 * min(100.0, max(0.0, gauge_value)) / 100.0
        if sweep > 0:
            gauge.add(Wedge(cx, cx, radius, 90 - sweep, 90,
                            fillColor=HexColor(gauge_color), strokeWidth=0))
            gauge.add(Circle(cx, cx, radius - ring_w, fillColor=white, strokeWidth=0))
        from reportlab.graphics.shapes import String as GString
        gauge.add(GString(cx, cx + 1, f'{gauge_value:.1f}', fontName='Helvetica-Bold',
                          fontSize=17, fillColor=HexColor(gauge_color),
                          textAnchor='middle'))
        gauge.add(GString(cx, cx - 8, f"GRADE {score.get('grade', '-')}",
                          fontName='Helvetica-Bold', fontSize=6,
                          fillColor=HexColor(SLATE), textAnchor='middle'))
        gauge.add(GString(cx, cx - 15, str(score.get('label') or ''),
                          fontName='Helvetica', fontSize=5.6,
                          fillColor=HexColor(SLATE), textAnchor='middle'))

        pillar_rows = []
        p_width = HALF_W - 16 - 46
        for p in score.get('pillars', []):
            pillar_rows.append([
                [Paragraph(p['label'], st_cell_b),
                 Paragraph(p['note'], st_cap),
                 Spacer(1, 1.2 * mm),
                 bar((p['score'] or 0) / 100, tone_for(p['score']), p_width, 4.0,
                     target=(p.get('target') or 100) / 100)],
                Paragraph(f"<b>{p['score']}</b>", st_cell_r),
                Paragraph(f"{round(p['weight'] * 100)}%", st_cap_r),
            ])
        pillars_tbl = Table(pillar_rows,
                            colWidths=[p_width + 10, 22, 18], hAlign='LEFT')
        pillars_tbl.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 2),
            ('TOPPADDING', (0, 0), (-1, -1), 2.5),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 3.5),
            ('LINEBELOW', (0, 0), (-1, -2), 0.4, HexColor('#F1F5F9')),
        ]))

        score_holder = Table([[gauge, pillars_tbl]],
                             colWidths=[gauge_size + 6, HALF_W - 16 - gauge_size - 12],
                             hAlign='LEFT')
        score_holder.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 2),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ]))
        score_card = card('Network health', 'Weighted across five operational pillars',
                          [score_holder], HALF_W)

        tile_gap = 3 * mm
        tile_w = (HALF_W - 16 - tile_gap) / 2
        summary_defs = [
            ('RECOMMENDATIONS', str(summary.get('recommendations', 0)),
             f"{summary.get('critical', 0)} critical · {summary.get('high', 0)} high",
             BRAND),
            ('QUICK WINS', str(summary.get('quick_wins', 0)),
             'low effort, measurable', GREEN),
            ('VALUE HELD', money(summary.get('value_at_risk')),
             f"{ints(summary.get('units_at_risk'))} units in open transfers", AMBER),
            ('POTENTIAL UNLOCK', money(summary.get('potential_value')),
             (f"+ {fmt_hours(summary.get('potential_hours'))} recovered"
              if summary.get('potential_hours') else 'from flagged fixes'), TEAL),
        ]

        def stat_tile(label, value, sub, color_hex, width):
            value_style = ParagraphStyle(
                f'osv{label}', fontName='Helvetica-Bold', fontSize=11.5,
                textColor=HexColor(mix(color_hex, -0.15)), leading=14)
            body = [Paragraph(value, value_style),
                    Paragraph(label, st_scope_label),
                    Paragraph(sub, st_cap)]
            tbl = Table([[body]], colWidths=[width], hAlign='LEFT')
            tbl.setStyle(TableStyle([
                ('BOX', (0, 0), (-1, -1), 0.7, HexColor(mix(color_hex, 0.62))),
                ('BACKGROUND', (0, 0), (-1, -1), HexColor(mix(color_hex, 0.9))),
                ('LEFTPADDING', (0, 0), (-1, -1), 7),
                ('RIGHTPADDING', (0, 0), (-1, -1), 6),
                ('TOPPADDING', (0, 0), (-1, -1), 6),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
            ]))
            return tbl

        summary_rows = []
        for i in range(0, 4, 2):
            summary_rows.append([
                stat_tile(*summary_defs[i], tile_w),
                '',
                stat_tile(*summary_defs[i + 1], tile_w),
            ])
        summary_grid = Table(summary_rows, colWidths=[tile_w, tile_gap, tile_w],
                             hAlign='LEFT')
        summary_grid.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
        ]))

        scope_line = (
            f"<b>{ints(scope.get('transfers'))}</b> transfers moved "
            f"<b>{ints(scope.get('units'))}</b> units worth "
            f"<b>{money(scope.get('value'))}</b> across "
            f"<b>{scope.get('lanes', 0)}</b> lane"
            f"{'' if scope.get('lanes') == 1 else 's'}, with "
            f"{scope.get('open', 0)} still in the pipeline. Average cycle time is "
            f"<b>{fmt_hours(scope.get('avg_cycle_hours'))}</b>.")
        worst_pillar = min(score.get('pillars', []),
                           key=lambda p: p['score'], default=None)
        worst_line = ''
        if worst_pillar:
            worst_line = (
                f" The biggest single gain is lifting <b>{worst_pillar['label'].lower()}</b> "
                f"from <b>{worst_pillar['score']}</b> toward "
                f"{round(worst_pillar.get('target') or 100)}.")

        summary_card = card('Executive read-out', 'What the numbers say about this network',
                            [summary_grid, Spacer(1, 2.5 * mm),
                             Paragraph(scope_line + worst_line, st_body)], HALF_W)

        flow += [two_col(score_card, summary_card), Spacer(1, 4 * mm)]

        # ── 2. Funnel + lanes ───────────────────────────────────────────
        funnel_max = max([1] + [f['count'] for f in funnel])
        funnel_w = HALF_W - 16 - 74
        funnel_rows = []
        for f in funnel:
            tone = (AMBER if (f.get('target_hours') and f.get('avg_hours') is not None
                              and f['avg_hours'] > f['target_hours'])
                    else {'draft': GREY, 'completed': GREEN}.get(f['key'], BRAND))
            meta = fmt_hours(f.get('avg_hours'))
            if f.get('target_hours'):
                meta += f"  /  target {fmt_hours(f['target_hours'])}"
            funnel_rows.append([
                [Paragraph(f['label'], st_cell_b), Paragraph(meta, st_cap),
                 Spacer(1, 1.2 * mm),
                 bar(f['count'] / funnel_max, tone, funnel_w, 4.4)],
                Paragraph(f"<b>{f['count']}</b>", st_cell_r),
            ])
        funnel_tbl = Table(funnel_rows, colWidths=[funnel_w + 10, 24], hAlign='LEFT')
        funnel_tbl.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 2),
            ('TOPPADDING', (0, 0), (-1, -1), 3),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
            ('LINEBELOW', (0, 0), (-1, -2), 0.4, HexColor('#F1F5F9')),
        ]))
        funnel_card = card('Stage funnel', 'Volume and dwell time at each stage',
                           [funnel_tbl], HALF_W)

        lane_w = HALF_W - 16
        lane_bar_w = lane_w - 118
        lane_max = max([1] + [max(l['forward'], l['reverse']) for l in lane_rows]) \
            if lane_rows else 1
        lane_table_rows = []
        for l in lane_rows[:7]:
            lane_table_rows.append([
                [Paragraph(str(l['lane'])[:44], st_cell_b),
                 Paragraph(f"{ints(l['units'])} units · {money(l['value'])} · "
                           f"transit {fmt_hours(l.get('avg_transit_hours'))}", st_cap)],
                [Paragraph(f"out {l['forward']}", st_cap),
                 bar(l['forward'] / lane_max, BRAND, lane_bar_w * 0.62, 3.4),
                 Paragraph(f"back {l['reverse']}", st_cap),
                 bar(l['reverse'] / lane_max, TEAL, lane_bar_w * 0.62, 3.4)],
                chip(f"{l['balance_pct']:.0f}% balanced",
                     GREEN if l['balance_pct'] >= 70 else
                     AMBER if l['balance_pct'] >= 40 else RED),
            ])
        if lane_table_rows:
            lanes_tbl = Table(lane_table_rows,
                              colWidths=[lane_w * 0.44, lane_w * 0.36, lane_w * 0.20],
                              hAlign='LEFT')
            lanes_tbl.setStyle(TableStyle([
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 3),
                ('TOPPADDING', (0, 0), (-1, -1), 3),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
                ('LINEBELOW', (0, 0), (-1, -2), 0.4, HexColor('#F1F5F9')),
            ]))
            lanes_content = [lanes_tbl]
        else:
            lanes_content = [Paragraph('No lanes recorded in this scope.', st_note)]
        lanes_card = card('Lane balance', 'How evenly freight flows in both directions',
                          lanes_content, HALF_W)

        flow += [two_col(funnel_card, lanes_card), Spacer(1, 4 * mm)]

        # ── 3. Priority recommendations (page 2) ────────────────────────
        flow.append(PageBreak())
        flow.append(Paragraph('Priority action plan',
                              ParagraphStyle('ortitle', fontName='Helvetica-Bold',
                                             fontSize=11, textColor=HexColor(NAVY),
                                             leading=14)))
        flow.append(Paragraph(
            f'{len(recs)} recommendation'
            f'{"s" if len(recs) != 1 else ""} ranked by severity (45%), impact (35%) '
            'and ease of implementation (20%).', st_card_sub))
        flow.append(Spacer(1, 3 * mm))

        def rec_block(rec, width):
            sev_hex = SEV_HEX.get(rec['severity'], GREY)
            inner = width - 16
            head = Table([[
                Paragraph(f"<b>{rec['rank']}</b>", ParagraphStyle(
                    'orank', fontName='Helvetica-Bold', fontSize=11,
                    textColor=HexColor(sev_hex), leading=13, alignment=TA_CENTER)),
                [Paragraph(rec['title'], st_rec_title),
                 Paragraph(rec['summary'], st_rec_summary)],
                Paragraph(f"<b>{rec['score']}</b>", ParagraphStyle(
                    'oscore', fontName='Helvetica-Bold', fontSize=13,
                    textColor=HexColor(sev_hex), leading=15, alignment=TA_RIGHT)),
            ]], colWidths=[9 * mm, inner - 9 * mm - 13 * mm, 13 * mm], hAlign='LEFT')
            head.setStyle(TableStyle([
                ('VALIGN', (0, 0), (-1, -1), 'TOP'),
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 0),
                ('TOPPADDING', (0, 0), (-1, -1), 0),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
            ]))

            meta_cells = [chip(rec['severity'], sev_hex),
                          chip(rec['category_label'], BRAND)]
            if rec.get('quick_win'):
                meta_cells.append(chip('Quick win', GREEN))
            meta_cells.append(Paragraph(
                f'<font color="{SLATE}" size="6">impact {rec["impact"]} '
                f'· effort {rec["effort"]}</font>', st_cap))
            meta_row = Table([meta_cells], hAlign='LEFT')
            meta_row.setStyle(TableStyle([
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 3),
                ('TOPPADDING', (0, 0), (-1, -1), 0),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
            ]))
            # Simple metric strip
            metric_cells = []
            for m in rec['metrics'][:3]:
                metric_cells.append([Paragraph(f"<b>{m['value']}</b>",
                                               ParagraphStyle('omv', parent=st_cell,
                                                              fontName='Helvetica-Bold',
                                                              fontSize=8.5, leading=10)),
                                     Paragraph(m['label'], st_cap)])
            metric_tbl = None
            if metric_cells:
                metric_tbl = Table([metric_cells],
                                   colWidths=[inner / max(1, len(metric_cells))] *
                                   max(1, len(metric_cells)), hAlign='LEFT')
                metric_tbl.setStyle(TableStyle([
                    ('VALIGN', (0, 0), (-1, -1), 'TOP'),
                    ('LEFTPADDING', (0, 0), (-1, -1), 0),
                    ('RIGHTPADDING', (0, 0), (-1, -1), 6),
                    ('TOPPADDING', (0, 0), (-1, -1), 0),
                    ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
                ]))

            actions = [Paragraph(f'• {a}', st_action) for a in rec['actions']]
            affected_txt = ''
            if rec['affected']:
                refs = ', '.join(str(a['reference']) for a in rec['affected'][:5])
                affected_txt = f'<font color="{SLATE}" size="6">Affected: {refs}</font>'

            body = [head, Spacer(1, 1.6 * mm), meta_row, Spacer(1, 2 * mm)]
            if metric_tbl is not None:
                body += [metric_tbl, Spacer(1, 2 * mm)]
            body += actions
            if affected_txt:
                body += [Spacer(1, 1.2 * mm), Paragraph(affected_txt, st_cap)]

            tbl = Table([[body]], colWidths=[width], hAlign='LEFT')
            tbl.setStyle(TableStyle([
                ('BOX', (0, 0), (-1, -1), 0.7, HexColor(BORDER)),
                ('LINEBEFORE', (0, 0), (0, -1), 2.8, HexColor(sev_hex)),
                ('BACKGROUND', (0, 0), (-1, -1), white),
                ('LEFTPADDING', (0, 0), (-1, -1), 8),
                ('RIGHTPADDING', (0, 0), (-1, -1), 8),
                ('TOPPADDING', (0, 0), (-1, -1), 7),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 7),
            ]))
            return tbl

        if recs:
            # Pair the cards left/right so reportlab can page-break between
            # rows — a single tall column would overflow the frame.
            for i in range(0, min(len(recs), 10), 2):
                left_rec = rec_block(recs[i], HALF_W)
                right_rec = (rec_block(recs[i + 1], HALF_W)
                             if i + 1 < min(len(recs), 10)
                             else Paragraph('', st_note))
                flow.append(two_col(left_rec, right_rec))
                if i + 2 < min(len(recs), 10):
                    flow.append(Spacer(1, 3 * mm))
            if len(recs) > 10:
                flow.append(Spacer(1, 2 * mm))
                flow.append(Paragraph(
                    f'Showing the top 10 of {len(recs)} recommendations — '
                    'the Optimization page lists the full plan.', st_note))
        else:
            flow.append(Paragraph(
                f'<font color="{GREEN}"><b>No open recommendations</b></font> — '
                'this network is running clean for the selected scope.', st_cap))

        # ── 4. Closing detail (page 3) ──────────────────────────────────
        flow.append(PageBreak())

        consol_rows = []
        for c in consolidation[:5]:
            consol_rows.append([
                Paragraph(str(c['lane'])[:42], st_cell_b),
                Paragraph(str(c['count']), st_cell_r),
                Paragraph(ints(c['units']), st_cell_r),
                Paragraph(money(c['value']), st_cell_r),
                chip(f"-{c['count'] - 1} trip" + ('' if c['count'] - 1 == 1 else 's'), GREEN),
            ])
        inner_w = HALF_W - 16
        if consol_rows:
            consol_tbl = Table(
                [[Paragraph('LANE', st_colhead), Paragraph('COUNT', st_colhead_r),
                  Paragraph('UNITS', st_colhead_r), Paragraph('VALUE', st_colhead_r),
                  Paragraph('SAVE', st_colhead)]] + consol_rows,
                colWidths=[inner_w * 0.42, inner_w * 0.12, inner_w * 0.14,
                           inner_w * 0.18, inner_w * 0.14], hAlign='LEFT')
            consol_tbl.setStyle(TableStyle([
                ('LINEBELOW', (0, 0), (-1, 0), 0.7, HexColor(BORDER)),
                ('LINEBELOW', (0, 1), (-1, -2), 0.4, HexColor('#F1F5F9')),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LEFTPADDING', (0, 0), (-1, -1), 2),
                ('RIGHTPADDING', (0, 0), (-1, -1), 2),
                ('TOPPADDING', (0, 0), (-1, -1), 3),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
            ]))
            consol_content = [consol_tbl]
        else:
            consol_content = [Paragraph(
                f'<font color="{GREEN}"><b>No merge candidates</b></font> — every open '
                'transfer is on its own lane or timeline.', st_cap)]
        consol_card = card('Consolidation opportunities',
                           'Open transfers that could share a single run',
                           consol_content, HALF_W)

        exp_rows = []
        for e in expiry_risk[:6]:
            tone = RED if e['days_left'] <= 30 else AMBER if e['days_left'] <= 60 else SLATE
            exp_rows.append([
                Paragraph(f"<font color='{tone}'><b>{e['days_left']}d</b></font>", st_cell),
                [Paragraph(str(e['stock'])[:40], st_cell_b),
                 Paragraph(f"Batch {e['batch']} · expires {e['expiry']} · "
                           f"{e['reference']}", st_cap)],
                Paragraph(ints(e['quantity']), st_cell_r),
            ])
        if exp_rows:
            exp_tbl = Table(exp_rows,
                            colWidths=[14, inner_w - 14 - 22, 22], hAlign='LEFT')
            exp_tbl.setStyle(TableStyle([
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 2),
                ('TOPPADDING', (0, 0), (-1, -1), 3),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
                ('LINEBELOW', (0, 0), (-1, -2), 0.4, HexColor('#F1F5F9')),
            ]))
            exp_content = [exp_tbl]
        else:
            exp_content = [Paragraph(
                f'<font color="{GREEN}"><b>No short-dated stock</b></font> — nothing in '
                'the pipeline expires within 90 days.', st_cap)]
        exp_card = card('Expiry risk in flight',
                        'Batches on open transfers expiring within 90 days',
                        exp_content, HALF_W)

        flow += [two_col(consol_card, exp_card), Spacer(1, 4 * mm)]

        carrier_rows_pdf = []
        for c in carrier_rows[:6]:
            carrier_rows_pdf.append([
                Paragraph(str(c['name'])[:30], st_cell_b),
                Paragraph(str(c['shipments']), st_cell_r),
                Paragraph(fmt_hours(c.get('avg_transit_hours')), st_cell_r),
                chip(f"{c['on_time_pct']:.0f}%",
                     GREEN if (c['on_time_pct'] or 0) >= 90 else
                     AMBER if (c['on_time_pct'] or 0) >= 70 else RED)
                if c.get('on_time_pct') is not None else Paragraph('—', st_cap_r),
            ])
        if carrier_rows_pdf:
            carrier_tbl = Table(
                [[Paragraph('CARRIER', st_colhead), Paragraph('MOVES', st_colhead_r),
                  Paragraph('TRANSIT', st_colhead_r), Paragraph('ON TIME', st_colhead)]] +
                carrier_rows_pdf,
                colWidths=[inner_w * 0.5, inner_w * 0.16, inner_w * 0.18,
                           inner_w * 0.16], hAlign='LEFT')
            carrier_tbl.setStyle(TableStyle([
                ('LINEBELOW', (0, 0), (-1, 0), 0.7, HexColor(BORDER)),
                ('LINEBELOW', (0, 1), (-1, -2), 0.4, HexColor('#F1F5F9')),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LEFTPADDING', (0, 0), (-1, -1), 2),
                ('RIGHTPADDING', (0, 0), (-1, -1), 2),
                ('TOPPADDING', (0, 0), (-1, -1), 3),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
            ]))
            carrier_content = [carrier_tbl]
        else:
            carrier_content = [Paragraph('No carrier assignments recorded.', st_note)]
        carrier_card = card('Carrier performance', 'Measured transit time per carrier',
                            carrier_content, HALF_W)

        branch_rows_pdf = []
        for b in scorecard[:6]:
            tone = tone_for(b['score'])
            branch_rows_pdf.append([
                chip(b['grade'], tone),
                [Paragraph(str(b['branch'])[:34], st_cell_b),
                 Paragraph(f"{b['dispatched']} out · {b['received']} in · "
                           f"cycle {fmt_hours(b.get('avg_cycle_hours'))}", st_cap),
                 Spacer(1, 1 * mm),
                 bar(b['score'] / 100, tone, inner_w - 54, 3.4)],
                Paragraph(f"<b>{b['score']}</b>", st_cell_r),
            ])
        if branch_rows_pdf:
            branch_tbl = Table(branch_rows_pdf,
                               colWidths=[14, inner_w - 14 - 24, 24], hAlign='LEFT')
            branch_tbl.setStyle(TableStyle([
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 2),
                ('TOPPADDING', (0, 0), (-1, -1), 3),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
                ('LINEBELOW', (0, 0), (-1, -2), 0.4, HexColor('#F1F5F9')),
            ]))
            branch_content = [branch_tbl]
        else:
            branch_content = [Paragraph('No branch activity recorded.', st_note)]
        branch_card = card('Branch scorecard', 'Speed, accuracy and reliability per site',
                           branch_content, HALF_W)

        flow += [two_col(carrier_card, branch_card), Spacer(1, 3 * mm)]
        flow.append(Paragraph(
            f'Derived from {ints(scope.get("transfers"))} transfers over '
            f'{period_label.lower()} scoped to {branch_label.lower()}. Recommendation '
            'scores weight severity (45%), impact (35%) and ease of implementation '
            '(20%).', st_note))

        doc.build(flow, onFirstPage=_page, onLaterPages=_page)
        buf.seek(0)
        stamp_str = timezone.localtime(timezone.now()).strftime('%Y%m%d')
        return HttpResponse(
            buf.read(),
            content_type='application/pdf',
            headers={
                'Content-Disposition':
                    f'attachment; filename="transfer-optimization_{stamp_str}.pdf"',
            },
        )

    @action(detail=True, methods=['post'])
    def submit(self, request, pk=None):
        """Move from draft to requested."""
        transfer = self.get_object()
        if transfer.status != StockTransfer.Status.DRAFT:
            return Response({'detail': 'Only drafts can be submitted.'}, status=400)
        transfer.status = StockTransfer.Status.REQUESTED
        transfer.save(update_fields=['status'])
        self._notify_transfer(transfer, 'requested', request.user)
        return Response(self.get_serializer(transfer).data)

    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        """Approve and ship: deduct from source-branch stock immediately.

        Fails with a shortage report if any line exceeds the on-hand stock,
        leaving all quantities untouched (atomic)."""
        from django.db import transaction as db_transaction

        transfer = self.get_object()
        if transfer.status not in (StockTransfer.Status.REQUESTED, StockTransfer.Status.DRAFT):
            return Response({'detail': 'Only requested transfers can be approved.'}, status=400)
        if not has_capability(request, 'transfer.approve'):
            return Response(
                {'detail': 'You do not have permission to approve and ship '
                           'transfers (transfer.approve capability required).'},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Validate the signature payload before touching stock so an invalid
        # value cannot leave a half-applied transfer behind.
        signature = self._clean_signature(request.data.get('signature'))
        if signature is None:
            return Response(
                {'detail': 'Invalid signature data — expected a base64 image data-URL.'},
                status=400,
            )

        with db_transaction.atomic():
            # ── Pre-flight: verify on-hand stock covers every line ──────
            shortages = []
            for line in transfer.lines.select_related('stock', 'batch').all():
                if line.batch_id:
                    available = line.batch.quantity_remaining if line.batch else 0
                else:
                    available = sum(
                        b.quantity_remaining for b in
                        line.stock.batches.filter(quantity_remaining__gt=0)
                    )
                if line.quantity > available:
                    shortages.append({
                        'stock': line.stock.medication_name,
                        'requested': line.quantity,
                        'available': available,
                        'batch': line.batch.batch_number if line.batch else None,
                    })
            if shortages:
                return Response(
                    {'detail': 'Insufficient stock for this transfer.',
                     'shortages': shortages},
                    status=400,
                )

            # ── Deduction ─────────────────────────────────────────────────
            # When the line has a pinned batch, deduct exactly from it
            # (validation above guarantees enough quantity). When no batch is
            # pinned, fall back to FEFO across the source branch first.
            for line in transfer.lines.select_related('stock', 'batch').all():
                if line.batch_id:
                    take = min(line.batch.quantity_remaining, line.quantity)
                    line.batch.quantity_remaining -= take
                    line.batch.save(update_fields=['quantity_remaining'])
                    continue

                remaining = line.quantity
                batches = line.stock.batches.filter(
                    quantity_remaining__gt=0,
                ).order_by('expiry_date')
                # Prefer batches at source branch first
                src_batches = list(batches.filter(branch=transfer.source_branch))
                other = [b for b in batches if b.branch_id != transfer.source_branch_id]
                for batch in src_batches + other:
                    if remaining <= 0:
                        break
                    take = min(batch.quantity_remaining, remaining)
                    batch.quantity_remaining -= take
                    batch.save(update_fields=['quantity_remaining'])
                    remaining -= take

            # ── Digital signature (captured in the approval dialog) ───────
            if signature:
                transfer.approved_signature = signature

            self._set_status(transfer, StockTransfer.Status.IN_TRANSIT, request.user, 'approved_by')
        self._notify_transfer(transfer, 'in_transit', request.user)
        return Response(self.get_serializer(transfer).data)

    @action(detail=True, methods=['post'])
    def receive(self, request, pk=None):
        """Receive at destination: create a new batch per line.

        Payload: {lines: [{id, quantity_received, notes}]} to record short
        receipts and per-line remarks (e.g. "2 units damaged").

        Validations: received qty must be 0 <= qty <= sent qty.

        If the source-branch stock item does not exist in the destination
        branch's inventory yet, a new MedicationStock is created there
        (cloning the source's catalog fields), and the line is reported back
        via ``added_to_inventory`` so the UI can confirm to the receiver.
        """
        transfer = self.get_object()
        if transfer.status != StockTransfer.Status.IN_TRANSIT:
            return Response({'detail': 'Only in-transit transfers can be received.'}, status=400)
        if not has_capability(request, 'transfer.receive'):
            return Response(
                {'detail': 'You do not have permission to receive transfers '
                           '(transfer.receive capability required).'},
                status=status.HTTP_403_FORBIDDEN,
            )

        received_map = {}
        notes_map = {}
        for payload in (request.data.get('lines') or []):
            received_map[payload.get('id')] = payload.get('quantity_received')
            if payload.get('notes'):
                notes_map[payload.get('id')] = str(payload['notes']).strip()

        # Validate the signature before mutating stock/batches.
        signature = self._clean_signature(request.data.get('signature'))
        if signature is None:
            return Response(
                {'detail': 'Invalid signature data — expected a base64 image data-URL.'},
                status=400,
            )

        # ── Validate before touching anything ──────────────────────────
        errors = []
        for line in transfer.lines.select_related('stock').all():
            qr = received_map.get(line.id)
            qty_received = int(qr) if qr not in (None, '') else line.quantity
            if qty_received < 0:
                errors.append(f'{line.stock.medication_name}: received quantity cannot be negative.')
            elif qty_received > line.quantity:
                errors.append(
                    f'{line.stock.medication_name}: received ({qty_received}) exceeds sent ({line.quantity}).')
        if errors:
            return Response({'detail': ' '.join(errors)}, status=400)

        # ── Apply receipt ────────────────────────────────────────────────
        from datetime import date as _d, timedelta as _td
        total_sent = total_received = 0
        value_received = 0.0
        new_items = []
        for line in transfer.lines.select_related('stock').all():
            qr = received_map.get(line.id)
            qty_received = int(qr) if qr not in (None, '') else line.quantity
            line.quantity_received = qty_received
            if line.id in notes_map:
                line.notes = notes_map[line.id]
            line.save(update_fields=['quantity_received', 'notes'])
            total_sent += line.quantity
            total_received += qty_received
            if line.stock:
                value_received += float(line.stock.cost_price or 0) * qty_received
            if qty_received > 0 and line.stock:
                dest_stock, was_created = self._find_or_create_dest_stock(
                    line.stock, transfer.dest_branch,
                )
                if was_created and dest_stock:
                    new_items.append({
                        'medication_name': dest_stock.medication_name,
                        'stock_id': dest_stock.id,
                        'generic_name': dest_stock.generic_name,
                        'brand_name': dest_stock.brand_name,
                        'strength': dest_stock.strength,
                        'quantity_received': qty_received,
                    })
                batch_stock = dest_stock or line.stock
                StockBatch.objects.create(
                    stock=batch_stock,
                    batch_number=f'TRF-{transfer.reference}',
                    quantity_received=qty_received,
                    quantity_remaining=qty_received,
                    cost_price_per_unit=line.stock.cost_price or 0,
                    expiry_date=_d.today() + _td(days=365),
                    branch=transfer.dest_branch,
                )

        # ── Digital signature (captured in the receive dialog) ───────────
        if signature:
            transfer.received_signature = signature

        self._set_status(transfer, StockTransfer.Status.COMPLETED, request.user, 'received_by')

        # ── Notify the receiver (and any other recipients) that new stock
        #    items were created in the destination branch's inventory.
        if new_items:
            from notifications.models import Notification
            title = f'{len(new_items)} new item(s) added to {transfer.dest_branch.name} inventory'
            message = (
                f'Receiving transfer {transfer.reference} introduced '
                f'{len(new_items)} new medication item(s) to the '
                f'{transfer.dest_branch.name} inventory: '
                + ', '.join(i['medication_name'] for i in new_items[:5])
                + (' …' if len(new_items) > 5 else '')
                + '.'
            )
            recipients = {transfer.received_by, transfer.requested_by}
            for u in recipients:
                if u and u == request.user:
                    continue
                Notification.objects.create(
                    recipient=u,
                    type=Notification.NotificationType.SYSTEM,
                    title=title,
                    message=message,
                    data={
                        'transfer_id': transfer.id,
                        'reference': transfer.reference,
                        'branch_id': transfer.dest_branch_id,
                        'branch_name': transfer.dest_branch.name,
                        'new_items': new_items,
                    },
                )

        # Lines were mutated — drop the prefetched cache so the response
        # reflects the freshly saved values (get_object() prefetches lines).
        if hasattr(transfer, '_prefetched_objects_cache'):
            transfer._prefetched_objects_cache.pop('lines', None)

        self._notify_transfer(transfer, 'completed', request.user)
        return Response({
            **self.get_serializer(transfer).data,
            'receipt_summary': {
                'units_sent': total_sent,
                'units_received': total_received,
                'variance': total_received - total_sent,
                'value_received': round(value_received, 2),
                'discrepancy_value': round(
                    value_received - sum(
                        float(l.stock.cost_price or 0) * l.quantity
                        for l in transfer.lines.select_related('stock').all() if l.stock
                    ), 2),
            },
            'added_to_inventory': {
                'branch_id': transfer.dest_branch_id,
                'branch_name': transfer.dest_branch.name,
                'count': len(new_items),
                'items': new_items,
            },
        })

    @action(detail=True, methods=['get'], url_path='preview-receive')
    def preview_receive(self, request, pk=None):
        """Per-line inventory status at the destination branch.

        Returns, for every shipped line, whether the item already exists in
        the destination branch's inventory and how many units are on hand
        there. The Receive dialog uses this to flag items that will be
        auto-created as new MedicationStock records on confirmation.
        """
        transfer = self.get_object()
        if transfer.status != StockTransfer.Status.IN_TRANSIT:
            return Response({'detail': 'Only in-transit transfers can be previewed.'},
                            status=400)
        lines_data = []
        for line in transfer.lines.select_related('stock').all():
            exists = False
            dest_stock_id = None
            qty_at_dest = 0
            if line.stock:
                dest_stock = (
                    MedicationStock.objects
                    .filter(branch=transfer.dest_branch_id,
                            medication_name__iexact=line.stock.medication_name)
                    .exclude(pk=line.stock_id)
                    .first()
                )
                if dest_stock:
                    exists = True
                    dest_stock_id = dest_stock.id
                    qty_at_dest = dest_stock.total_quantity
            lines_data.append({
                'id': line.id,
                'medication_name': line.stock.medication_name if line.stock else '',
                'exists_at_dest': exists,
                'dest_stock_id': dest_stock_id,
                'quantity_at_dest': qty_at_dest,
                'quantity_sent': line.quantity,
            })
        return Response({
            'dest_branch_id': transfer.dest_branch_id,
            'dest_branch_name': transfer.dest_branch.name,
            'lines': lines_data,
        })

    @action(detail=True, methods=['post'])
    def cancel(self, request, pk=None):
        transfer = self.get_object()
        if transfer.status in (StockTransfer.Status.COMPLETED, StockTransfer.Status.CANCELLED):
            return Response({'detail': 'Cannot cancel this transfer.'}, status=400)
        transfer.status = StockTransfer.Status.CANCELLED
        transfer.save(update_fields=['status'])
        self._notify_transfer(transfer, 'cancelled', request.user)
        return Response(self.get_serializer(transfer).data)

    @action(detail=True, methods=['get'], url_path='pdf')
    def pdf(self, request, pk=None):
        """Printable, branded transfer note (portrait A4).

        Uses the organisation logo uploaded at /ims/organization/profile and
        the brand palette configured at /ims/organization/branding.
        """
        import io as _io
        from reportlab.lib.pagesizes import A4
        from reportlab.lib.units import mm
        from reportlab.lib.colors import HexColor, white
        from reportlab.lib.styles import ParagraphStyle
        from reportlab.lib.enums import TA_CENTER, TA_RIGHT
        from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer,
                                        Table, TableStyle, Image)
        from reportlab.lib.utils import ImageReader
        from datetime import datetime as _dtc
        from config.pdf_branding import resolve_branding

        transfer = self.get_object()
        tenant = getattr(request, 'tenant', None)
        # Logo uploaded at /ims/organization/profile; falls back to a bundled
        # default when the tenant has not uploaded one.
        logo_path, business_name = resolve_branding(request)

        def _brand(attr, default):
            """Brand colour configured at /ims/organization/branding."""
            val = getattr(tenant, attr, '') if tenant else ''
            if isinstance(val, str) and val.startswith('#') and len(val) == 7:
                try:
                    return HexColor(val)
                except Exception:
                    pass
            return HexColor(default)

        BRAND_PRIMARY = _brand('brand_primary', '#2f6dff')
        BRAND_SECONDARY = _brand('brand_secondary', '#143ce1')
        BRAND_ACCENT = _brand('brand_accent', '#37d6ff')

        def _tint(color, alpha):
            """Blend a brand colour toward white for soft backgrounds."""
            r = int(round(color.red * 255 * alpha + 255 * (1 - alpha)))
            g = int(round(color.green * 255 * alpha + 255 * (1 - alpha)))
            b = int(round(color.blue * 255 * alpha + 255 * (1 - alpha)))
            return HexColor('#%02X%02X%02X' % (r, g, b))

        NAVY = HexColor('#0F172A')
        SLATE = HexColor('#64748B')
        BORDER = HexColor('#E2E8F0')

        st_title = ParagraphStyle('t', fontName='Helvetica-Bold', fontSize=17,
                                 textColor=white, leading=20, alignment=TA_RIGHT)
        st_sub = ParagraphStyle('s', fontName='Helvetica', fontSize=9, textColor=white,
                                leading=12, alignment=TA_RIGHT)
        st_org_name = ParagraphStyle('on', fontName='Helvetica-Bold', fontSize=11,
                                     textColor=white, leading=14)
        st_org_meta = ParagraphStyle('om', fontName='Helvetica', fontSize=7,
                                     textColor=HexColor('#E2E8F0'), leading=10)
        st_h = ParagraphStyle('h', fontName='Helvetica-Bold', fontSize=10,
                              textColor=BRAND_SECONDARY)
        st_k = ParagraphStyle('k', fontName='Helvetica-Bold', fontSize=7,
                              textColor=SLATE, leading=9)
        st_v = ParagraphStyle('v', fontName='Helvetica', fontSize=9,
                              textColor=NAVY, leading=11)
        st_cell = ParagraphStyle('c', fontName='Helvetica', fontSize=8, leading=10)
        st_cell_r = ParagraphStyle('cr', parent=st_cell, alignment=TA_RIGHT)
        st_empty = ParagraphStyle('e', fontName='Helvetica-Oblique', fontSize=8,
                                  textColor=SLATE, alignment=TA_CENTER)

        def money(v):
            return f'KSh {float(v or 0):,.2f}'

        def stamp(d):
            try:
                return _dtc.fromisoformat(str(d)).strftime('%b %d %Y, %I:%M %p')
            except (TypeError, ValueError):
                return str(d or '—')

        tenant_name = getattr(getattr(request, 'tenant', None), 'name', '') or 'AdhereMed'
        status_display = transfer.get_status_display()

        buf = _io.BytesIO()
        doc = SimpleDocTemplate(
            buf, pagesize=A4,
            leftMargin=16 * mm, rightMargin=16 * mm, topMargin=14 * mm, bottomMargin=16 * mm,
            title=f'Transfer Note {transfer.reference}',
        )
        story = []

        # ── Header band: logo + organisation + document identity ────
        def fit_logo(path, max_h_mm, max_w_mm):
            try:
                if path and os.path.exists(path):
                    iw, ih = ImageReader(path).getSize()
                    th = max_h_mm * mm
                    tw = iw * (th / ih)
                    if tw > max_w_mm * mm:
                        tw = max_w_mm * mm
                        th = ih * (tw / iw)
                    return Image(path, width=tw, height=th)
            except Exception:
                pass
            return ''

        def _tv(attr):
            return (getattr(tenant, attr, '') or '') if tenant else ''

        org_logo = fit_logo(logo_path, 15, 36)
        org_addr = ', '.join(p for p in (_tv('address'), _tv('city')) if p)
        contact_bits = []
        if _tv('phone'):
            contact_bits.append(f'Tel: {_tv("phone")}')
        if _tv('email'):
            contact_bits.append(f'Email: {_tv("email")}')
        if _tv('website'):
            contact_bits.append(f'Web: {_tv("website")}')

        org_cell = [Paragraph(tenant_name, st_org_name)]
        meta_parts = [p for p in (org_addr, ' · '.join(contact_bits)) if p]
        if meta_parts:
            org_cell.append(Paragraph('<br/>'.join(meta_parts), st_org_meta))

        doc_cell = [
            Paragraph('Stock Transfer Note', st_title),
            Paragraph(f'{transfer.reference} · {status_display}',
                      ParagraphStyle('ref', parent=st_sub, fontSize=10,
                                     fontName='Helvetica-Bold')),
        ]

        head = Table([[org_logo, org_cell, doc_cell]],
                     colWidths=[40 * mm, 74 * mm, 68 * mm])
        head.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), BRAND_SECONDARY),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (0, 0), 5 * mm),
            ('RIGHTPADDING', (2, 0), (2, 0), 5 * mm),
            ('TOPPADDING', (0, 0), (-1, -1), 5 * mm),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 5 * mm),
        ]))
        story.append(head)

        # Brand accent strip under the header
        accent = Table([['']], colWidths=[182 * mm], rowHeights=[1.8 * mm])
        accent.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), BRAND_ACCENT),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ]))
        story.append(accent)
        story.append(Spacer(1, 7 * mm))

        # ── Route + parties ─────────────────────────────────────────
        meta = [
            ('From (source)', transfer.source_branch.name if transfer.source_branch else '—'),
            ('To (destination)', transfer.dest_branch.name if transfer.dest_branch else '—'),
            ('Requested by', str(transfer.requested_by) if transfer.requested_by else '—'),
            ('Requested at', stamp(transfer.requested_at)),
            ('Approved / shipped by', str(transfer.approved_by) if transfer.approved_by else '—'),
            ('Shipped at', stamp(transfer.shipped_at)),
            ('Received by', str(transfer.received_by) if transfer.received_by else '—'),
            ('Received at', stamp(transfer.received_at)),
        ]
        meta_rows = [
            [Paragraph(k, st_k), Paragraph(v, st_v), Paragraph(k2, st_k), Paragraph(v2, st_v)]
            for (k, v), (k2, v2) in zip(meta[:4], meta[4:])
        ]
        meta_t = Table(meta_rows, colWidths=[32 * mm, 52 * mm, 32 * mm, 52 * mm])
        meta_t.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
            ('LINEBELOW', (0, -1), (-1, -1), 0.75, BORDER),
        ]))
        story.append(meta_t)
        story.append(Spacer(1, 5 * mm))

        # ── Cargo, schedule & assignment ────────────────────────────
        def _or(value):
            return value if value not in (None, '') else '—'

        driver_label = (transfer.assigned_driver.full_name
                        if transfer.assigned_driver_id and transfer.assigned_driver else '—')
        carrier_label = (transfer.assigned_carrier.name
                         if transfer.assigned_carrier_id and transfer.assigned_carrier else '—')
        vehicle_label = (str(transfer.assigned_vehicle)
                         if transfer.assigned_vehicle_id and transfer.assigned_vehicle
                         else (getattr(transfer, 'assigned_vehicle_note', '') or '—'))
        cargo_rows = [
            ('Priority', _or(transfer.get_priority_display()),
             'Parcels / boxes', _or(transfer.parcel_count)),
            ('Weight', f'{transfer.weight_kg} kg' if transfer.weight_kg is not None else '—',
             'Vehicle', vehicle_label),
            ('Scheduled pickup', stamp(transfer.scheduled_pickup) if transfer.scheduled_pickup else '—',
             'Scheduled delivery', stamp(transfer.scheduled_delivery) if transfer.scheduled_delivery else '—'),
            ('Assigned driver', driver_label, 'Assigned carrier', carrier_label),
        ]
        story.append(Paragraph('Cargo, schedule &amp; assignment', st_h))
        story.append(Spacer(1, 2 * mm))
        cargo_t = Table(
            [[Paragraph(k, st_k), Paragraph(str(v), st_v),
              Paragraph(k2, st_k), Paragraph(str(v2), st_v)]
             for (k, v, k2, v2) in cargo_rows],
            colWidths=[32 * mm, 52 * mm, 32 * mm, 52 * mm],
        )
        cargo_t.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
            ('BACKGROUND', (0, 0), (-1, -1), _tint(BRAND_PRIMARY, 0.06)),
            ('BOX', (0, 0), (-1, -1), 0.5, _tint(BRAND_PRIMARY, 0.35)),
            ('LEFTPADDING', (0, 0), (-1, -1), 5),
            ('RIGHTPADDING', (0, 0), (-1, -1), 5),
            ('TOPPADDING', (0, 0), (-1, -1), 5),
        ]))
        story.append(cargo_t)
        story.append(Spacer(1, 6 * mm))

        # ── Lines ───────────────────────────────────────────────────
        story.append(Paragraph('Items transferred', st_h))
        story.append(Spacer(1, 2 * mm))
        rows = [[Paragraph('Item', st_k), Paragraph('Unit', st_k),
                 Paragraph('Qty sent', st_k), Paragraph('Qty received', st_k),
                 Paragraph('Variance', st_k), Paragraph('Value (cost)', st_k)]]
        for line in transfer.lines.select_related('stock__unit').all():
            rows.append([
                Paragraph(line.stock.medication_name if line.stock else '—', st_cell),
                Paragraph(line.stock.unit.abbreviation if line.stock and line.stock.unit else '', st_cell),
                Paragraph(str(line.quantity), st_cell_r),
                Paragraph(str(line.quantity_received if line.quantity_received is not None else '—'), st_cell_r),
                Paragraph(f'{line.variance:+d}' if line.quantity_received is not None else '—', st_cell_r),
                Paragraph(money(float(line.stock.cost_price or 0) * line.quantity) if line.stock else '—', st_cell_r),
            ])
        if len(rows) == 1:
            rows.append([Paragraph('No line items on this transfer.', st_empty),
                         '', '', '', '', ''])
        total_value = sum(float(l.stock.cost_price or 0) * l.quantity
                          for l in transfer.lines.select_related('stock').all() if l.stock)
        rows.append([Paragraph('Totals', st_h), '',
                     Paragraph(str(transfer.total_quantity), ParagraphStyle('tv', parent=st_h, alignment=TA_RIGHT)),
                     Paragraph(str(sum(l.quantity_received or 0 for l in transfer.lines.all())),
                               ParagraphStyle('tv2', parent=st_h, alignment=TA_RIGHT)),
                     '', Paragraph(money(total_value), ParagraphStyle('tv3', parent=st_h, alignment=TA_RIGHT))])
        lines_t = Table(rows, colWidths=[74 * mm, 14 * mm, 20 * mm, 22 * mm, 18 * mm, 30 * mm],
                        repeatRows=1)
        lines_t.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), _tint(BRAND_PRIMARY, 0.16)),
            ('GRID', (0, 0), (-1, -1), 0.5, BORDER),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('TOPPADDING', (0, 0), (-1, -1), 4),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
            ('BACKGROUND', (0, -1), (-1, -1), _tint(BRAND_PRIMARY, 0.08)),
            ('LINEABOVE', (0, 0), (-1, 0), 1, BRAND_PRIMARY),
            ('LINEBELOW', (0, -1), (-1, -1), 1, BRAND_PRIMARY),
        ]))
        story.append(lines_t)

        if transfer.notes:
            story.append(Spacer(1, 5 * mm))
            story.append(Paragraph('Notes', st_h))
            story.append(Paragraph(transfer.notes, st_cell))

        story.append(Spacer(1, 8 * mm))
        story.append(Paragraph(
            'Received in good condition — quantities verified against this note.',
            ParagraphStyle('sig', parent=st_cell, fontSize=8)))
        story.append(Spacer(1, 6 * mm))

        # ── Digital signatures captured in the approval / receive dialogs ──
        import base64 as _b64

        def _sig_image(data_url):
            """Decode a base64 image data-URL into a ReportLab flowable."""
            if not data_url or ';base64,' not in data_url:
                return None
            try:
                raw = _b64.b64decode(data_url.split(';base64,', 1)[1])
                return Image(_io.BytesIO(raw), width=56 * mm, height=17 * mm,
                             kind='proportional')
            except Exception:
                return None

        st_sig_meta = ParagraphStyle('sigm', parent=st_cell, fontSize=7.5,
                                     textColor=NAVY, leading=9.5)
        st_sig_label = ParagraphStyle('sigl', parent=st_k, fontSize=7)

        def _sig_block(label, data_url, person, when):
            img = _sig_image(data_url)
            stack = [img] if img is not None else [
                Spacer(1, 15 * mm),
                Paragraph('Not signed', st_empty),
            ]
            meta = person or '—'
            if when:
                meta = f'{meta} · {stamp(when)}'
            stack.append(Paragraph(meta, st_sig_meta))
            stack.append(Paragraph(label, st_sig_label))
            return stack

        sig = Table(
            [[
                _sig_block('Approved &amp; shipped by', transfer.approved_signature,
                           str(transfer.approved_by) if transfer.approved_by else '',
                           transfer.shipped_at),
                _sig_block('Received by', transfer.received_signature,
                           str(transfer.received_by) if transfer.received_by else '',
                           transfer.received_at),
            ]],
            colWidths=[89 * mm, 89 * mm],
        )
        sig.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'BOTTOM'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 8),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
            ('LINEBELOW', (0, 0), (0, 0), 0.75, BRAND_SECONDARY),
            ('LINEBELOW', (1, 0), (1, 0), 0.75, BRAND_SECONDARY),
        ]))
        story.append(sig)

        def _page(canv, doc_):
            canv.saveState()
            # Thin brand rule above the footer text
            canv.setStrokeColor(BRAND_ACCENT)
            canv.setLineWidth(1.2)
            canv.line(16 * mm, 11.5 * mm, 194 * mm, 11.5 * mm)

            canv.setFont('Helvetica', 7)
            canv.setFillColor(SLATE)
            canv.drawString(16 * mm, 8 * mm,
                            f'{tenant_name} · Stock Transfer {transfer.reference}')
            canv.drawRightString(194 * mm, 8 * mm,
                                 f'Page {canv.getPageNumber()} · Generated {timezone.now():%b %d %Y}')

            # Centre the platform credit between the two footer strings.
            from reportlab.pdfbase.pdfmetrics import stringWidth
            p_lead = 'Powered by '
            p_brand = 'AdhereMed'
            p_tail = '  ·  www.adheremed.co'
            w_lead = stringWidth(p_lead, 'Helvetica', 6.5)
            w_brand = stringWidth(p_brand, 'Helvetica-Bold', 6.5)
            w_tail = stringWidth(p_tail, 'Helvetica', 6.5)
            x = (210 * mm - (w_lead + w_brand + w_tail)) / 2
            canv.setFont('Helvetica', 6.5)
            canv.setFillColor(SLATE)
            canv.drawString(x, 8 * mm, p_lead)
            canv.setFont('Helvetica-Bold', 6.5)
            canv.setFillColor(BRAND_PRIMARY)
            canv.drawString(x + w_lead, 8 * mm, p_brand)
            canv.setFont('Helvetica', 6.5)
            canv.setFillColor(SLATE)
            canv.drawString(x + w_lead + w_brand, 8 * mm, p_tail)
            canv.restoreState()

        doc.build(story, onFirstPage=_page, onLaterPages=_page)
        buf.seek(0)
        return HttpResponse(
            buf.read(),
            content_type='application/pdf',
            headers={'Content-Disposition':
                     f'attachment; filename="transfer_{transfer.reference}.pdf"'},
        )

    @action(detail=False, methods=['get'])
    def export(self, request):
        """CSV export of the (filtered) transfer list."""
        qs = self.filter_queryset(self.get_queryset())

        def money(v):
            try:
                return f'{float(v or 0):.2f}'
            except (TypeError, ValueError):
                return '0.00'

        out = io.StringIO()
        writer = csv.writer(out)
        writer.writerow(['reference', 'status', 'source', 'destination',
                         'items', 'units', 'value (KSh)', 'variance',
                         'requested_by', 'requested_at', 'shipped_at', 'received_at'])
        for t in qs:
            writer.writerow([
                t.reference, t.status,
                t.source_branch.name if t.source_branch else '',
                t.dest_branch.name if t.dest_branch else '',
                t.total_items, t.total_quantity,
                money(sum(float(l.stock.cost_price or 0) * l.quantity
                          for l in t.lines.select_related('stock').all() if l.stock)),
                sum(l.variance for l in t.lines.all()),
                str(t.requested_by) if t.requested_by else '',
                t.requested_at or '', t.shipped_at or '', t.received_at or '',
            ])
        return HttpResponse(
            out.getvalue(),
            content_type='text/csv',
            headers={'Content-Disposition':
                     f'attachment; filename="stock_transfers_{timezone.now():%Y%m%d}.csv"'},
        )


# ─────────────────────────────────────────────────────────────────────────
#  RBAC management (Roles & Access admin page)
# ─────────────────────────────────────────────────────────────────────────
class RBACMatrixView(APIView):
    """Serves the live role/capability matrix plus the staff grouped by role
    for the Roles & Access administration page. Includes tenant-created
    custom roles."""

    permission_classes = [TenantAdminOnly]

    def get(self, request):
        tenant = getattr(request, 'tenant', None) or getattr(request.user, 'tenant', None)

        users = []
        if tenant is not None:
            from accounts.models import User
            qs = (User.objects
                  .filter(tenant=tenant, is_active=True)
                  .exclude(role__in=['patient', 'caregiver', 'super_admin']))
            for u in qs:
                branch_name = None
                try:
                    sp = u.staff_profile
                    branch_name = sp.branch.name if sp.branch else None
                except Exception:
                    pass
                users.append({
                    'id': u.id,
                    'name': f'{u.first_name} {u.last_name}'.strip() or u.email,
                    'email': u.email,
                    'role': u.role,
                    'branch_name': branch_name,
                })

        # Built-in roles (with any tenant capability overrides applied).
        # RoleDefinition lookups are guarded so a schema whose tenant
        # migrations are still pending renders the built-in matrix instead
        # of a 500.
        try:
            override_keys = set(RoleDefinition.objects
                                .filter(is_system=True, is_active=True)
                                .values_list('key', flat=True))
        except Exception:
            override_keys = set()
        role_meta = _role_meta_for(request)
        editable_roles = _editable_builtin_roles_for(request)
        roles = []
        for meta in role_meta:
            role_users = [u for u in users if u['role'] == meta['key']]
            is_override = meta['key'] in override_keys
            roles.append({**meta, 'user_count': len(role_users),
                          'users': role_users, 'is_custom': False,
                          'is_override': is_override,
                          'capabilities': sorted(_role_caps(meta['key'])),
                          'editable': meta['key'] in editable_roles})

        # Tenant-created custom roles
        custom_roles = []
        try:
            rd_qs = RoleDefinition.objects.filter(is_active=True, is_system=False)
        except Exception:
            rd_qs = RoleDefinition.objects.none()
        for rd in rd_qs:
            role_users = [u for u in users if u['role'] == rd.key]
            custom_roles.append({
                'key': rd.key, 'label': rd.label, 'tier': 'custom',
                'icon': rd.icon or 'mdi-badge-account-horizontal-outline',
                'description': rd.description or '',
                'user_count': len(role_users), 'users': role_users,
                'is_custom': True, 'is_override': False, 'editable': True,
                'capabilities': sorted(rd.capabilities or []),
                'id': rd.id,
            })

        # Assignable roles = built-in operational roles + custom role keys
        assignable = list(_assignable_roles_for(request)) + [r['key'] for r in custom_roles]

        return Response({
            'roles': roles + custom_roles,
            'custom_roles': custom_roles,
            'capabilities': capability_matrix(),
            'assignable_roles': assignable,
            'can_change': True,
        })


class RBACSetUserRoleView(APIView):
    """Change a member's role from the Roles & Access page.

    Tenant-admin ownership cannot be granted/revoked here — only the four
    operational inventory roles and tenant-created custom roles are
    assignable.
    """
    permission_classes = [TenantAdminOnly]

    def patch(self, request, user_id=None):
        tenant = getattr(request, 'tenant', None) or getattr(request.user, 'tenant', None)
        if tenant is None:
            return Response({'detail': 'No organization context.'},
                            status=status.HTTP_400_BAD_REQUEST)

        new_role = (request.data.get('role') or '').strip()
        custom_keys = set(RoleDefinition.objects
                          .filter(is_active=True)
                          .values_list('key', flat=True))
        assignable = _assignable_roles_for(request)
        if new_role not in assignable and new_role not in custom_keys:
            return Response(
                {'detail': 'Unknown or non-assignable role. Assignable roles are '
                           'the operational roles and your custom roles.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        # A deactivated/renamed custom role can no longer be re-assigned.
        if new_role in custom_keys and new_role not in assignable and \
                not RoleDefinition.objects.filter(key=new_role, is_active=True).exists():
            return Response({'detail': 'This custom role is no longer active.'},
                            status=status.HTTP_400_BAD_REQUEST)

        from accounts.models import User
        user = User.objects.filter(id=user_id, tenant=tenant).first()
        if not user:
            return Response({'detail': 'Member not found in this organization.'},
                            status=status.HTTP_404_NOT_FOUND)
        if user.role == 'tenant_admin':
            return Response(
                {'detail': 'The tenant owner role can only be changed by the '
                           'platform superadmin.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if user.id == request.user.id:
            return Response(
                {'detail': 'You cannot change your own role from here.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if user.role == new_role:
            return Response({'detail': f'{user} already has this role.',
                             'user': {'id': user.id, 'name': str(user),
                                      'email': user.email, 'role': user.role}},
                            status=status.HTTP_200_OK)

        old_role = user.role
        user.role = new_role
        user.save(update_fields=['role'])

        # Audit trail
        try:
            from audit.utils import log_event
            log_event(request, action='role_change', object_type='user',
                      object_id=user.id,
                      details={'from': old_role, 'to': new_role,
                               'member': user.email})
        except Exception:
            pass

        return Response({
            'detail': f'{user} role updated to {new_role.replace("_", " ")}.',
            'user': {'id': user.id, 'name': str(user), 'email': user.email,
                     'role': new_role},
        })


# ── Custom role CRUD (add / edit / remove roles) ──────────────────────────
def _slugify_role(label):
    import re
    key = re.sub(r'[^a-z0-9]+', '_', (label or '').strip().lower()).strip('_')
    return key[:20]


class RoleDefinitionSerializer(serializers.Serializer):
    """Read/write serializer for tenant-created roles."""
    id = serializers.IntegerField(read_only=True)
    key = serializers.SlugField(read_only=True)
    label = serializers.CharField(max_length=100)
    description = serializers.CharField(required=False, allow_blank=True, default='')
    icon = serializers.CharField(required=False, allow_blank=True,
                                 default='mdi-badge-account-horizontal-outline')
    capabilities = serializers.ListField(
        child=serializers.CharField(), required=False, default=list)
    is_active = serializers.BooleanField(required=False, default=True)

    def validate_label(self, value):
        label = value.strip()
        if not label:
            raise serializers.ValidationError('Label is required.')
        key = _slugify_role(label)
        if key in RESERVED_ROLE_KEYS:
            raise serializers.ValidationError(
                f'"{label}" collides with a reserved built-in role.')
        if not key:
            raise serializers.ValidationError('Label must contain letters or digits.')
        return label

    def validate_capabilities(self, value):
        unknown = [c for c in (value or []) if c not in ALL_CAP_KEYS]
        if unknown:
            raise serializers.ValidationError(
                f'Unknown capabilities: {", ".join(unknown)}.')
        caps = list(dict.fromkeys(value or []))  # dedupe, keep order
        return caps

    def create(self, validated_data):
        label = validated_data['label']
        key = _slugify_role(label)
        # Ensure key uniqueness for this tenant schema
        base, suffix = key, 2
        while RoleDefinition.objects.filter(key=key).exists():
            suffix_str = str(suffix)
            key = base[:20 - len(suffix_str)] + suffix_str
            suffix += 1
        rd = RoleDefinition.objects.create(
            key=key, label=label,
            description=validated_data.get('description', ''),
            icon=validated_data.get('icon') or 'mdi-badge-account-horizontal-outline',
            capabilities=validated_data.get('capabilities', []),
            is_active=validated_data.get('is_active', True),
        )
        return rd

    def update(self, instance, validated_data):
        for f in ('label', 'description', 'icon', 'capabilities', 'is_active'):
            if f in validated_data:
                setattr(instance, f, validated_data[f])
        instance.save()
        return instance


class RoleDefinitionViewSet(viewsets.ModelViewSet):
    """CRUD for tenant-created custom roles (Roles & Access page).

    * create  — add a role with a chosen capability list
    * update  — rename / re-icon / toggle capabilities
    * delete  — remove the role (blocked while members still hold it)
    """
    queryset = RoleDefinition.objects.all()
    serializer_class = RoleDefinitionSerializer
    permission_classes = [TenantAdminOnly]
    filter_backends = [filters.OrderingFilter]
    ordering = ['label']
    http_method_names = ['get', 'post', 'patch', 'delete', 'head', 'options']

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        rd = serializer.save()
        return Response(self.get_serializer(rd).data,
                        status=status.HTTP_201_CREATED)

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', True)
        instance = self.get_object()
        if instance.is_system:
            return Response(
                {'detail': 'Built-in role overrides are managed through their '
                           'own action (edit via the role editor).'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        serializer = self.get_serializer(instance, data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        rd = serializer.save()
        return Response(self.get_serializer(rd).data)

    def destroy(self, request, *args, **kwargs):
        """Remove a custom role — blocked while any member still holds it."""
        role = self.get_object()
        if role.is_system:
            return Response(
                {'detail': 'Built-in roles cannot be removed. Use the reset '
                           'action to restore platform defaults.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        tenant = getattr(request, 'tenant', None) or getattr(request.user, 'tenant', None)
        if tenant is not None:
            from accounts.models import User
            members = list(User.objects
                           .filter(tenant=tenant, role=role.key, is_active=True)
                           .values_list('email', flat=True))
            if members:
                return Response(
                    {'detail': f'Cannot remove "{role.label}" while members still '
                               f'hold it: {", ".join(members[:5])}. Reassign them first.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
        role.delete()
        return Response({'detail': f'Role "{role.label}" removed.'},
                        status=status.HTTP_200_OK)


class RBACBuiltinRoleOverrideView(APIView):
    """Customize (or reset) the capabilities of a built-in role.

    PATCH   {capabilities: [...]}  — stores a tenant override (is_system row)
    DELETE                            — removes the override, restoring the
                                        platform defaults
    The tenant owner role is platform-managed and cannot be overridden.
    """
    permission_classes = [TenantAdminOnly]

    def _validate_caps(self, caps):
        if not isinstance(caps, list) or not caps:
            return 'A non-empty capability list is required.'
        unknown = [c for c in caps if c not in ALL_CAP_KEYS]
        if unknown:
            return f'Unknown capabilities: {", ".join(unknown)}.'
        missing = PROTECTED_BUILTIN_CAPS - set(caps)
        if missing:
            return (f'Cannot remove required capabilities: {", ".join(sorted(missing))}. '
                    f'Every role must keep basic stock visibility.')
        return None

    def patch(self, request, key):
        editable_roles = _editable_builtin_roles_for(request)
        if key not in editable_roles:
            return Response(
                {'detail': 'This role is managed by the platform and cannot '
                           'be customized.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        err = self._validate_caps(request.data.get('capabilities'))
        if err:
            return Response({'detail': err}, status=status.HTTP_400_BAD_REQUEST)

        meta = next((m for m in _role_meta_for(request) if m['key'] == key), None)
        caps = list(dict.fromkeys(request.data['capabilities']))
        rd, _ = RoleDefinition.objects.update_or_create(
            key=key,
            defaults={
                'label': meta['label'] if meta else key.title(),
                'icon': meta['icon'] if meta else 'mdi-badge-account-horizontal-outline',
                'description': (meta['description'] if meta else '') + ' (customized)',
                'capabilities': caps,
                'is_system': True,
                'is_active': True,
            },
        )
        try:
            from audit.utils import log_event
            log_event(request, action='role_capability_override', object_type='role',
                      object_id=rd.id,
                      details={'role': key, 'capabilities': caps})
        except Exception:
            pass
        return Response({
            'detail': f'"{rd.label}" capabilities updated — effective immediately.',
            'key': key, 'capabilities': sorted(caps), 'is_override': True,
        })

    def delete(self, request, key):
        editable_roles = _editable_builtin_roles_for(request)
        if key not in editable_roles:
            return Response(
                {'detail': 'This role is managed by the platform.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        deleted, _ = RoleDefinition.objects.filter(key=key, is_system=True).delete()
        if deleted:
            try:
                from audit.utils import log_event
                log_event(request, action='role_capability_reset', object_type='role',
                          object_id=None, details={'role': key})
            except Exception:
                pass
            return Response({
                'detail': 'Platform defaults restored.',
                'key': key,
                'capabilities': sorted(BUILTIN_ROLE_CAPS.get(key, [])),
                'is_override': False,
            })
        return Response({'detail': 'No override existed — already on defaults.',
                         'key': key,
                         'capabilities': sorted(BUILTIN_ROLE_CAPS.get(key, [])),
                         'is_override': False},
                        status=status.HTTP_200_OK)


# ─────────────────────────────────────────────────────────────────────────
#  Controlled Substance Register
# ─────────────────────────────────────────────────────────────────────────
class ControlledSubstanceLogViewSet(viewsets.ModelViewSet):
    queryset = ControlledSubstanceLog.objects.select_related('recorded_by').all()
    serializer_class = ControlledSubstanceLogSerializer
    permission_classes = [ControlledRegisterPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['action', 'medication_name', 'schedule']
    search_fields = ['medication_name', 'patient_name', 'patient_id_number',
                     'prescriber_name', 'prescription_reference', 'batch_number']
    ordering_fields = ['created_at', 'medication_name']

    def get_queryset(self):
        qs = super().get_queryset()
        df = self.request.query_params.get('date_from')
        dt = self.request.query_params.get('date_to')
        if df:
            qs = qs.filter(created_at__date__gte=df)
        if dt:
            qs = qs.filter(created_at__date__lte=dt)
        return qs

    def perform_create(self, serializer):
        serializer.save(recorded_by=self.request.user if self.request.user.is_authenticated else None)

    @action(detail=False, methods=['get'])
    def stats(self, request):
        from django.db.models import Sum
        qs = self.get_queryset()
        by_action = {}
        for row in qs.values('action').annotate(c=Sum('quantity')):
            by_action[row['action']] = float(row['c'] or 0)
        by_med = list(
            qs.values('medication_name')
              .annotate(total=Sum('quantity'))
              .order_by('-total')[:10]
        )
        return Response({
            'total_records': qs.count(),
            'by_action': by_action,
            'top_medications': by_med,
        })


class StockMovementReportView(APIView):
    """Unified stock movement report aggregating all inventory movements.

    Combines StockAdjustment ledger entries (damage/theft/expiry/correction/etc.)
    and StockTransfer line items (branch-to-branch movements) into a single
    view with KPIs, per-day trend, reason breakdown, top movers, and a
    detailed transactions list.

    Query params:
      ?date_from=&date_to=  (YYYY-MM-DD range filter)
      ?reason=              (filter by adjustment reason)
      ?direction=inflow|outflow
      ?branch_id=           (filter by branch)
    """
    permission_classes = [IsAuthenticated]

    @staticmethod
    def _attach_qty_balances(movements):
        """Attach qty_before / qty_after (total on-hand quantity of the stock
        item) to each movement by replaying every quantity-changing event per
        stock: batch receipts, POS sales, dispensing, restocked returns,
        adjustments and transfer shipments."""
        from datetime import datetime as _dtc, time as _tc
        try:
            from pos.models import TransactionItem
            from dispensing.models import DispensingRecord, DispenseReturn
        except Exception:
            return

        def naive(d):
            if d is None:
                return None
            return timezone.localtime(d).replace(tzinfo=None) if timezone.is_aware(d) else d

        stock_ids = {m.get('stock_id') for m in movements if m.get('stock_id')}
        if not stock_ids:
            return

        # Current on-hand quantity per stock (positive batches only)
        current_qty = {
            row['stock_id']: int(row['total'] or 0)
            for row in (StockBatch.objects
                        .filter(stock_id__in=stock_ids, quantity_remaining__gt=0)
                        .values('stock_id')
                        .annotate(total=Sum('quantity_remaining')))
        }

        events = {}  # stock_id -> [(naive datetime, delta)]

        def add(sid, d, delta):
            d = naive(d)
            if d is not None and delta:
                events.setdefault(sid, []).append((d, int(delta)))

        # Batch receipts (initial stock, PO receipts, transfer receives).
        # Batches auto-created by dispense returns are skipped: the return
        # event itself accounts for that quantity.
        for b in (StockBatch.objects.filter(stock_id__in=stock_ids)
                  .only('stock_id', 'batch_number', 'quantity_received', 'received_date')):
            if (b.batch_number or '').upper().startswith('RET-'):
                continue
            add(b.stock_id,
                _dtc.combine(b.received_date, _tc.min) if b.received_date else None,
                b.quantity_received)

        for ti in (TransactionItem.objects
                   .filter(stock_id__in=stock_ids, transaction__status='completed')
                   .select_related('transaction')
                   .only('stock_id', 'quantity', 'transaction__created_at')):
            add(ti.stock_id, ti.transaction.created_at, -(ti.quantity or 0))

        for rec in (DispensingRecord.objects.filter(status='completed')
                   .only('id', 'dispensed_at', 'items_dispensed')):
            for it in (rec.items_dispensed or []):
                sid = it.get('stock_id')
                if sid in stock_ids:
                    add(sid, rec.dispensed_at, -int(it.get('qty', 0) or 0))

        for ret in (DispenseReturn.objects.filter(restock=True)
                    .only('id', 'created_at', 'items_returned')):
            for it in (ret.items_returned or []):
                sid = it.get('stock_id')
                if sid in stock_ids:
                    add(sid, ret.created_at, int(it.get('qty', 0) or 0))

        for adj in (StockAdjustment.objects.filter(stock_id__in=stock_ids)
                    .only('stock_id', 'created_at', 'quantity_change')):
            add(adj.stock_id, adj.created_at, adj.quantity_change)

        # Transfer shipments deduct source stock at approve time
        # (received stock arrives via the TRF- batches counted above)
        for line in (StockTransferLine.objects
                     .filter(stock_id__in=stock_ids, transfer__shipped_at__isnull=False)
                     .select_related('transfer')
                     .only('stock_id', 'quantity', 'transfer__shipped_at')):
            add(line.stock_id, line.transfer.shipped_at, -(line.quantity or 0))

        for sid in events:
            events[sid].sort(key=lambda e: e[0])

        for m in movements:
            sid = m.get('stock_id')
            if not sid or sid not in current_qty or not m.get('timestamp'):
                continue
            try:
                t = naive(_dtc.fromisoformat(m['timestamp']))
            except (ValueError, TypeError):
                continue
            if t is None:
                continue
            after = current_qty[sid] - sum(d for ts, d in events.get(sid, []) if ts > t)
            m['qty_after'] = after
            m['qty_before'] = after - int(m.get('quantity_change') or 0)

    def _render_pdf(self, start, end, movements, kpis, trend, reason_segments, top_movers,
                    reason_labels, reason_colors=None, business_name=''):
        """Premium PDF export of the stock movement report (landscape A4,
        branded header/footer band, KPI cards, daily flow chart, reason
        breakdown, top movers and the full movement ledger)."""
        import io as _io
        from reportlab.lib.pagesizes import A4, landscape
        from reportlab.lib.units import mm
        from reportlab.lib.colors import HexColor, white
        from reportlab.lib.styles import ParagraphStyle
        from reportlab.lib.enums import TA_RIGHT, TA_CENTER
        from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak
        from reportlab.graphics.shapes import Drawing, String as GString, Circle, Polygon, PolyLine, Line as GLine
        from datetime import datetime as _dtc

        NAVY = HexColor('#0F172A')
        SKY = HexColor('#0EA5E9')
        SLATE = HexColor('#64748B')
        BORDER = HexColor('#E2E8F0')

        def money(v):
            try:
                return f'KSh {float(v or 0):,.2f}'
            except (TypeError, ValueError):
                return 'KSh 0.00'

        def stamp(iso):
            try:
                return _dtc.fromisoformat(iso).strftime('%b %d %Y, %I:%M %p')
            except (ValueError, TypeError):
                return iso or '-'

        # ── Styles (mirroring the web UI) ──────────────────────────────
        def _mix(color_hex, f):
            """Blend a hex color toward white (f > 0) or black (f < 0)."""
            h = color_hex.lstrip('#')
            r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
            if f >= 0:
                r, g, b = (round(c + (255 - c) * f) for c in (r, g, b))
            else:
                r, g, b = (round(c * (1 + f)) for c in (r, g, b))
            return f'#{r:02X}{g:02X}{b:02X}'

        st_klabel = ParagraphStyle('klabel', fontName='Helvetica-Bold', fontSize=6.5,
                                   textColor=SLATE, leading=8)
        st_ksub = ParagraphStyle('ksub', fontName='Helvetica', fontSize=6.5,
                                 textColor=SLATE, leading=9)
        st_cardtitle = ParagraphStyle('cardtitle', fontName='Helvetica-Bold', fontSize=9.5,
                                      textColor=NAVY, leading=12)
        st_note = ParagraphStyle('note', fontName='Helvetica-Oblique', fontSize=7,
                                 textColor=SLATE, leading=9)
        st_cell = ParagraphStyle('cell', fontName='Helvetica', fontSize=7, leading=9)
        st_cell_b = ParagraphStyle('cellb', fontName='Helvetica-Bold', fontSize=7, leading=9)
        st_cell_r = ParagraphStyle('cellr', parent=st_cell, alignment=TA_RIGHT)
        st_cap = ParagraphStyle('cap', fontName='Helvetica', fontSize=6, textColor=SLATE,
                                leading=8)
        st_cap_r = ParagraphStyle('capr', parent=st_cap, alignment=TA_RIGHT)
        st_colhead = ParagraphStyle('colhead', fontName='Helvetica-Bold', fontSize=6.5,
                                    textColor=SLATE, leading=8)
        st_colhead_r = ParagraphStyle('colheadr', parent=st_colhead, alignment=TA_RIGHT)

        def chip(text, color_hex):
            """Tonal chip like the web v-chip variant='tonal'."""
            st = ParagraphStyle(f'chip{text}', fontName='Helvetica-Bold', fontSize=6,
                                leading=8, alignment=TA_CENTER,
                                textColor=HexColor(_mix(color_hex, -0.2)),
                                backColor=HexColor(_mix(color_hex, 0.85)),
                                borderPadding=1.6)
            return Paragraph(text, st)

        def icon_drawing(color_hex, kind):
            """Tonal circular avatar with a simple arrow icon (v-avatar look)."""
            d = Drawing(30, 30)
            d.add(Circle(15, 15, 14, fillColor=HexColor(_mix(color_hex, 0.85)), strokeWidth=0))
            c = HexColor(color_hex)
            if kind == 'down':
                d.add(Polygon([15, 7, 23, 22, 7, 22], fillColor=c, strokeWidth=0))
            elif kind == 'swap':
                d.add(Polygon([5, 15, 14, 21, 14, 9], fillColor=c, strokeWidth=0))
                d.add(Polygon([25, 15, 16, 21, 16, 9], fillColor=c, strokeWidth=0))
            else:  # up
                d.add(Polygon([15, 23, 23, 8, 7, 8], fillColor=c, strokeWidth=0))
            return d

        def avatar_drawing(name, color_hex):
            """Tonal circular avatar with initials (web Top movers list)."""
            d = Drawing(26, 26)
            d.add(Circle(13, 13, 12, fillColor=HexColor(_mix(color_hex, 0.85)), strokeWidth=0))
            initials = ''.join(w[:1] for w in (name or '?').split()[:2]).upper() or '?'
            d.add(GString(13, 9, initials, fontName='Helvetica-Bold', fontSize=9,
                          fillColor=HexColor(color_hex), textAnchor='middle'))
            return d

        AVATAR_PALETTE = ['#0EA5E9', '#16A34A', '#DC2626', '#8B5CF6',
                          '#F59E0B', '#14B8A6', '#2563EB', '#D97706']

        def avatar_color(name):
            h = 0
            for ch_ in (name or ''):
                h = ord(ch_) + ((h << 5) - h)
            return AVATAR_PALETTE[abs(h) % len(AVATAR_PALETTE)]

        # ── Page furniture ────────────────────────────────────────────
        W, H = landscape(A4)

        def _page(canv, doc):
            canv.saveState()
            # Web-style header: cyan avatar square + swap-vertical icon,
            # page title + subtitle (mirrors the page header on the web app)
            canv.setFillColor(HexColor('#E0F2FE'))
            canv.roundRect(15 * mm, H - 30 * mm, 13 * mm, 13 * mm, 2.5 * mm, stroke=0, fill=1)
            canv.setFillColor(HexColor('#0E7490'))
            cx = 21.5 * mm
            p = canv.beginPath()
            p.moveTo(cx - 1.8 * mm, H - 20.6 * mm)
            p.lineTo(cx, H - 19 * mm)
            p.lineTo(cx + 1.8 * mm, H - 20.6 * mm)
            p.close()
            canv.drawPath(p, stroke=0, fill=1)
            p = canv.beginPath()
            p.moveTo(cx - 1.8 * mm, H - 26.4 * mm)
            p.lineTo(cx, H - 28 * mm)
            p.lineTo(cx + 1.8 * mm, H - 26.4 * mm)
            p.close()
            canv.drawPath(p, stroke=0, fill=1)
            canv.setFillColor(NAVY)
            canv.setFont('Helvetica-Bold', 15)
            canv.drawString(32 * mm, H - 21.5 * mm, 'Stock Movements')
            canv.setFillColor(SLATE)
            canv.setFont('Helvetica', 8)
            canv.drawString(32 * mm, H - 26 * mm,
                            'Track every stock inflow, outflow, and transfer with full audit trail')
            if business_name:
                canv.setFillColor(NAVY)
                canv.setFont('Helvetica-Bold', 10)
                canv.drawRightString(W - 15 * mm, H - 21.5 * mm, business_name)
            canv.setFillColor(SLATE)
            canv.setFont('Helvetica', 7.5)
            canv.drawRightString(W - 15 * mm, H - 25.5 * mm,
                                 f'Period: {start.strftime("%b %d %Y")} - {end.strftime("%b %d %Y")}')
            now = timezone.localtime(timezone.now())
            canv.drawRightString(W - 15 * mm, H - 29.5 * mm,
                                 f'Generated {now.strftime("%b %d %Y, %I:%M %p")}')
            # Footer
            canv.setStrokeColor(BORDER)
            canv.setLineWidth(0.6)
            canv.line(15 * mm, 12 * mm, W - 15 * mm, 12 * mm)
            canv.setFont('Helvetica', 7)
            canv.setFillColor(SLATE)
            canv.drawString(15 * mm, 7.5 * mm,
                            f'{business_name} · Stock Movement Report' if business_name
                            else 'Stock Movement Report')
            canv.drawRightString(W - 15 * mm, 7.5 * mm,
                                 f'Powered by AdhereMed · Page {canv.getPageNumber()}')
            canv.restoreState()

        doc = SimpleDocTemplate(
            buf := _io.BytesIO(), pagesize=landscape(A4),
            leftMargin=15 * mm, rightMargin=15 * mm,
            topMargin=35 * mm, bottomMargin=17 * mm,
            title='Stock Movement Report',
            author=business_name or 'AdhereMed',
        )
        flow = []

        # ── KPI tiles (mirroring the web KPI cards) ───────────────────
        def kpi_tile(label, value, sub, color_hex, kind):
            value_style = ParagraphStyle('kv', fontName='Helvetica-Bold', fontSize=11,
                                         textColor=HexColor(color_hex), leading=14)
            text_cell = [Paragraph(label, st_klabel), Paragraph(value, value_style),
                         Paragraph(sub, st_ksub)]
            t = Table([[text_cell, icon_drawing(color_hex, kind)]],
                      colWidths=[46 * mm, 14 * mm], hAlign='LEFT')
            t.setStyle(TableStyle([
                ('BOX', (0, 0), (-1, -1), 0.8, BORDER),
                ('VALIGN', (0, 0), (-1, -1), 'TOP'),
                ('LEFTPADDING', (0, 0), (0, 0), 7),
                ('RIGHTPADDING', (0, 0), (0, 0), 2),
                ('LEFTPADDING', (1, 0), (1, 0), 0),
                ('RIGHTPADDING', (1, 0), (1, 0), 6),
                ('TOPPADDING', (0, 0), (-1, -1), 6),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
            ]))
            return t

        net = int(kpis.get('net_change') or 0)
        net_col = '#16A34A' if net >= 0 else '#DC2626'
        tiles = [
            kpi_tile('TOTAL INFLOW', f"{kpis.get('total_in') or 0} units",
                     money(kpis.get('value_in')), '#16A34A', 'up'),
            kpi_tile('TOTAL OUTFLOW', f"{kpis.get('total_out') or 0} units",
                     money(kpis.get('value_out')), '#DC2626', 'down'),
            kpi_tile('NET CHANGE', f"{'+' if net >= 0 else ''}{net} units",
                     money(kpis.get('net_value')), net_col, 'up' if net >= 0 else 'down'),
            kpi_tile('TRANSFERS', f"{kpis.get('total_transfer') or 0} units",
                     f"{kpis.get('count') or 0} total movements", '#0EA5E9', 'swap'),
        ]
        tiles_row, tile_widths = [], []
        for i, t_ in enumerate(tiles):
            tiles_row.append(t_)
            tile_widths.append(60 * mm)
            if i < 3:
                tiles_row.append('')
                tile_widths.append(3.5 * mm)
        tiles_tbl = Table([tiles_row], colWidths=tile_widths, hAlign='LEFT')
        tiles_tbl.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
        ]))
        flow.append(tiles_tbl)

        def card(title, content):
            """Bordered white card with a bold title row (mirrors v-card)."""
            rows = [[Paragraph(title, st_cardtitle)]] + [[c] for c in content]
            t = Table(rows, colWidths=[267 * mm], hAlign='LEFT')
            t.setStyle(TableStyle([
                ('BOX', (0, 0), (-1, -1), 0.8, BORDER),
                ('BACKGROUND', (0, 0), (-1, -1), white),
                ('LEFTPADDING', (0, 0), (-1, -1), 10),
                ('RIGHTPADDING', (0, 0), (-1, -1), 10),
                ('TOPPADDING', (0, 0), (-1, -1), 2),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 2),
                ('TOPPADDING', (0, 0), (0, 0), 8),
                ('BOTTOMPADDING', (0, 0), (0, 0), 2),
                ('BOTTOMPADDING', (0, -1), (-1, -1), 8),
            ]))
            return t

        # ── Daily movement trend chart (own row, full width) ─────────
        # Area chart of net units per day, mirroring the web SparkArea
        show = trend[-30:]
        chart_content = []
        if show:
            chart_w, chart_h = 247 * mm, 55 * mm
            dr = Drawing(chart_w, chart_h + 5 * mm)
            values = [int(t.get('net') or 0) for t in show]
            labels = [(t['date'] or '')[5:] for t in show]
            n = len(values)
            lo = min([0] + values)
            hi = max([1] + values)
            span = (hi - lo) or 1
            pad_l, pad_r, pad_t, pad_b = 26, 10, 6, 16
            iw, ih = chart_w - pad_l - pad_r, chart_h - pad_t - pad_b
            base_y = pad_t + ih

            def xv(i):
                return pad_l + (iw / 2 if n == 1 else i / (n - 1) * iw)

            def yv(v):
                return pad_t + (1 - (v - lo) / span) * ih

            # Grid lines (4 horizontal, like the web chart)
            grid_col = HexColor('#F1F5F9')
            for i in range(4):
                gy = pad_t + i * ih / 3
                dr.add(GLine(pad_l, gy, pad_l + iw, gy, strokeColor=grid_col, strokeWidth=0.5))
            # Y tick labels: [hi, lo+2/3, lo+1/3, lo] like the web yTicks
            for i, tick in enumerate([hi, lo + span * 2 / 3, lo + span / 3, lo]):
                dr.add(GString(pad_l - 4, pad_t + i * ih / 3 - 2, f'{tick:g}',
                               fontName='Helvetica', fontSize=6, fillColor=SLATE,
                               textAnchor='end'))
            # Area fill (curve down to baseline, like the web areaPath)
            pts = [xv(i) for i in range(n)] + [yv(v) for v in values]
            area_pairs = [(pad_l, base_y)] + list(zip(pts[:n], pts[n:])) + [(pad_l + iw, base_y)]
            dr.add(Polygon([c for pair in area_pairs for c in pair],
                           fillColor=HexColor(_mix('#0EA5E9', 0.72)), strokeWidth=0))
            # Line + dots on top (like the web linePath)
            line_flat = [c for pair in zip(pts[:n], pts[n:]) for c in pair]
            dr.add(PolyLine(line_flat, strokeColor=SKY, strokeWidth=1.4))
            for i in range(n):
                dr.add(Circle(xv(i), yv(values[i]), 1.3, fillColor=SKY, strokeWidth=0))
            # Baseline
            dr.add(GLine(pad_l, base_y, pad_l + iw, base_y, strokeColor=BORDER, strokeWidth=0.7))
            # X labels (~8 evenly spaced, like the web displayLabels)
            step = max(1, (n + 7) // 8)
            for i, l in enumerate(labels):
                if i % step == 0 or i == n - 1:
                    dr.add(GString(xv(i), 4, l, fontName='Helvetica', fontSize=6,
                                   fillColor=SLATE, textAnchor='middle'))
            chart_content.append(dr)
            chart_content.append(Spacer(1, 1 * mm))
            chart_content.append(Paragraph(
                'Net units moved per day (inflow minus outflow). Positive bars indicate stock gains.',
                ParagraphStyle('cap2', parent=st_cap, fontSize=6.5)))
        else:
            chart_content.append(Paragraph('No daily trend data in this range.', st_note))
        flow += [Spacer(1, 5 * mm),
                 card('Daily Movement Trend', chart_content)]

        # ── Movement reasons (mirrors the web donut legend rows) ──────
        reason_rows = []
        for s in reason_segments:
            dot = Drawing(10, 10)
            dot.add(Circle(5, 5, 4, fillColor=HexColor(s['color']), strokeWidth=0))
            reason_rows.append([
                dot,
                Paragraph(str(s['label']), st_cell),
                Paragraph(f"{s['value']} units", ParagraphStyle(
                    'rb', parent=st_cell_r, fontName='Helvetica-Bold')),
            ])
        reasons_content = []
        if reason_rows:
            reasons_tbl = Table(reason_rows, colWidths=[6 * mm, 215 * mm, 26 * mm],
                               hAlign='LEFT')
            reasons_tbl.setStyle(TableStyle([
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LEFTPADDING', (0, 0), (-1, -1), 2),
                ('RIGHTPADDING', (0, 0), (-1, -1), 2),
                ('TOPPADDING', (0, 0), (-1, -1), 1.5),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 1.5),
            ]))
            reasons_content.append(reasons_tbl)
        else:
            reasons_content.append(Paragraph('No movements in this range.', st_note))
        flow += [Spacer(1, 5 * mm),
                 card('Movement Reasons', reasons_content)]

        # ── Top movers (own page, mirrors the web list) ───────────────
        movers_content = []
        if top_movers:
            movers_rows = []
            for m in top_movers:
                name = str(m['name'])
                netv = int(m['net'] or 0)
                caption = (f"{m['count']} movements · net "
                           f"{'+' if netv >= 0 else ''}{netv} units")
                movers_rows.append([
                    avatar_drawing(name, avatar_color(name)),
                    [Paragraph(name, st_cell_b), Paragraph(caption, st_cap)],
                    chip(f"{m['inflow']} in / {m['outflow']} out",
                         '#16A34A' if netv >= 0 else '#DC2626'),
                ])
            movers_tbl = Table(movers_rows, colWidths=[12 * mm, 195 * mm, 40 * mm],
                               hAlign='LEFT')
            movers_tbl.setStyle(TableStyle([
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LEFTPADDING', (0, 0), (-1, -1), 4),
                ('RIGHTPADDING', (0, 0), (-1, -1), 4),
                ('TOPPADDING', (0, 0), (-1, -1), 2.5),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 2.5),
            ]))
            movers_content.append(movers_tbl)
        else:
            movers_content.append(Paragraph('No stock adjustments recorded in this range.',
                                            st_note))
        flow += [PageBreak(), card('Top Movers', movers_content)]

        # ── Movement ledger (own page, mirrors the web data table) ────
        flow += [PageBreak(), Paragraph('Movement Ledger', st_cardtitle), Spacer(1, 4 * mm)]
        PDF_MAX_ROWS = 500
        rows_shown = movements[:PDF_MAX_ROWS]
        if rows_shown:
            if len(movements) > PDF_MAX_ROWS:
                flow.append(Paragraph(
                    f'Showing the first {PDF_MAX_ROWS} of {len(movements)} movements.',
                    st_note))
                flow.append(Spacer(1, 2 * mm))
            ledger_rows = [[
                Paragraph('#', st_colhead), Paragraph('DATE', st_colhead),
                Paragraph('TYPE', st_colhead), Paragraph('REFERENCE', st_colhead),
                Paragraph('PRODUCT', st_colhead), Paragraph('REASON', st_colhead),
                Paragraph('QTY', st_colhead_r), Paragraph('BEFORE', st_colhead_r),
                Paragraph('AFTER', st_colhead_r), Paragraph('VALUE', st_colhead_r),
                Paragraph('BY', st_colhead), Paragraph('NOTES', st_colhead),
            ]]
            type_map = {'inflow': ('IN', '#16A34A'), 'outflow': ('OUT', '#DC2626'),
                        'transfer': ('TRANSFER', '#0EA5E9')}
            for i, m in enumerate(rows_shown, 1):
                t_txt, t_col = type_map.get(m.get('direction'),
                                            (str(m.get('direction') or '-').upper(), '#64748B'))
                qty = int(m.get('quantity_change') or 0)
                qty_html = (f"<font color='#16A34A'><b>+{qty} units</b></font>" if qty >= 0
                            else f"<font color='#DC2626'><b>-{abs(qty)} units</b></font>")
                before, after = m.get('qty_before'), m.get('qty_after')
                reason = reason_labels.get(m.get('reason'),
                                            (m.get('reason') or '-').replace('_', ' ').title())
                r_col = reason_colors.get(m.get('reason'), '#64748B')
                product_cell = [Paragraph(str(m.get('stock_name') or '-'), st_cell_b)]
                if m.get('batch_number'):
                    product_cell.append(Paragraph(f"Batch {m['batch_number']}", st_cap))
                reference_cell = [Paragraph(str(m.get('reference') or '-'), st_cell_b)]
                if m.get('source'):
                    reference_cell.append(Paragraph(str(m['source']), st_cap))
                ledger_rows.append([
                    Paragraph(str(i), st_cell),
                    Paragraph(stamp(m.get('timestamp') or m.get('date')), st_cap),
                    chip(t_txt, t_col),
                    reference_cell,
                    product_cell,
                    chip(str(reason), r_col),
                    Paragraph(qty_html, st_cell_r),
                    Paragraph(str(before) if before is not None else '-', st_cell_r),
                    Paragraph(f"<b>{after}</b>" if after is not None else '-', st_cell_r),
                    Paragraph(money(m.get('value_change')), st_cap_r),
                    Paragraph(str(m.get('user') or '-'), st_cap),
                    Paragraph(str(m.get('notes') or '-'), st_cap),
                ])
            ledger = Table(ledger_rows,
                           colWidths=[7 * mm, 30 * mm, 16 * mm, 24 * mm, 46 * mm,
                                      24 * mm, 14 * mm, 13 * mm, 13 * mm, 20 * mm,
                                      20 * mm, 32 * mm],
                           repeatRows=1, hAlign='LEFT')
            ledger.setStyle(TableStyle([
                ('LINEBELOW', (0, 0), (-1, 0), 0.8, BORDER),
                ('LINEBELOW', (0, 1), (-1, -2), 0.4, HexColor('#F1F5F9')),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LEFTPADDING', (0, 0), (-1, -1), 4),
                ('RIGHTPADDING', (0, 0), (-1, -1), 4),
                ('TOPPADDING', (0, 0), (-1, -1), 3),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
            ]))
            flow.append(ledger)
        else:
            flow.append(Paragraph('No stock movements recorded in this range.', st_note))

        doc.build(flow, onFirstPage=_page, onLaterPages=_page)
        buf.seek(0)
        fname = f'stock-movements_{start:%Y%m%d}_{end:%Y%m%d}.pdf'
        return HttpResponse(
            buf.read(),
            content_type='application/pdf',
            headers={'Content-Disposition': f'attachment; filename="{fname}"'},
        )

    def get(self, request):
        from datetime import datetime as _dt
        from django.db.models.functions import TruncDate

        today = timezone.now().date()
        # Parse date range
        df = request.query_params.get('date_from')
        dt = request.query_params.get('date_to')
        if df and dt:
            try:
                start = _dt.strptime(df, '%Y-%m-%d').date()
                end = _dt.strptime(dt, '%Y-%m-%d').date()
            except ValueError:
                start = today - timedelta(days=29)
                end = today
        else:
            start = today - timedelta(days=29)
            end = today
        start_dt = _dt.combine(start, _dt.min.time())
        end_dt = _dt.combine(end + timedelta(days=1), _dt.min.time())

        reason_filter = request.query_params.get('reason')
        direction_filter = request.query_params.get('direction')
        branch_id = request.query_params.get('branch_id')
        # Force non-admin users to their own branch
        from config.branch_scope import BRANCH_ADMIN_BYPASS_ROLES, get_user_branch
        role = getattr(request.user, 'role', '')
        if role not in BRANCH_ADMIN_BYPASS_ROLES and not getattr(request.user, 'is_superuser', False):
            branch_id = get_user_branch(request.user)
        # Optional per-item scoping: every section (POS, dispensing, returns,
        # adjustments, transfer lines) is filtered down to this stock item.
        try:
            stock_id = int(request.query_params.get('stock_id') or 0) or None
        except (TypeError, ValueError):
            stock_id = None

        movements = []  # unified list

        # ── Gather POS sales (TransactionItem → outflow) ───────────────
        try:
            from pos.models import POSTransaction, TransactionItem
            pos_qs = TransactionItem.objects.select_related(
                'transaction', 'stock', 'batch'
            ).filter(
                transaction__created_at__gte=start_dt,
                transaction__created_at__lt=end_dt,
                transaction__status='completed',
            )
            if branch_id:
                pos_qs = pos_qs.filter(transaction__branch_id=branch_id)
            if stock_id:
                pos_qs = pos_qs.filter(stock_id=stock_id)
            for ti in pos_qs:
                if reason_filter and reason_filter != 'pos_sale':
                    continue
                if direction_filter and 'outflow' != direction_filter:
                    continue
                qty = int(ti.quantity or 0)
                unit_val = float(ti.unit_price or ti.stock.selling_price or 0) if ti.stock else float(ti.unit_price or 0)
                movements.append({
                    'id': f'POS-{ti.id}',
                    'date': ti.transaction.created_at.date().isoformat() if ti.transaction.created_at else '',
                    'timestamp': ti.transaction.created_at.isoformat() if ti.transaction.created_at else '',
                    'direction': 'outflow',
                    'type': 'pos_sale',
                    'reason': 'pos_sale',
                    'source': 'POS Sale',
                    'reference': ti.transaction.transaction_number or '',
                    'stock_name': ti.medication_name or (ti.stock.medication_name if ti.stock else 'Unknown'),
                    'stock_id': ti.stock_id,
                    'batch_number': ti.batch.batch_number if ti.batch else '',
                    'quantity': qty,
                    'quantity_change': -qty,
                    'unit_value': unit_val,
                    'value_change': qty * unit_val,
                    'user': str(ti.transaction.cashier) if ti.transaction.cashier else 'System',
                    'notes': f'Payment: {ti.transaction.get_payment_method_display() if ti.transaction else ""}',
                })
        except Exception:
            pass

        # ── Gather Dispensing records (outflow) ───────────────────────
        try:
            from dispensing.models import DispensingRecord, DispenseReturn
            disp_qs = DispensingRecord.objects.filter(
                dispensed_at__gte=start_dt,
                dispensed_at__lt=end_dt,
                status='completed',
            )
            for rec in disp_qs:
                items = rec.items_dispensed or []
                for idx, it in enumerate(items):
                    if reason_filter and reason_filter != 'dispensing':
                        continue
                    if direction_filter and 'outflow' != direction_filter:
                        continue
                    if stock_id and it.get('stock_id') != stock_id:
                        continue
                    qty = int(it.get('qty', 0) or 0)
                    unit_val = float(it.get('unit_price', 0) or 0)
                    med_name = it.get('medication_name', 'Unknown')
                    movements.append({
                        'id': f'DISP-{rec.id}-{idx}',
                        'date': rec.dispensed_at.date().isoformat() if rec.dispensed_at else '',
                        'timestamp': rec.dispensed_at.isoformat() if rec.dispensed_at else '',
                        'direction': 'outflow',
                        'type': 'dispensing',
                        'reason': 'dispensing',
                        'source': 'Dispensing',
                        'reference': rec.receipt_number or f'RCP-{rec.id}',
                        'stock_name': med_name,
                        'stock_id': it.get('stock_id'),
                        'batch_number': it.get('batch_number', '') or '',
                        'quantity': qty,
                        'quantity_change': -qty,
                        'unit_value': unit_val,
                        'value_change': qty * unit_val,
                        'user': str(rec.dispensed_by) if rec.dispensed_by else 'System',
                        'notes': rec.notes or f'Patient: {rec.patient_name}',
                    })
        except Exception:
            pass

        # ── Gather Dispense Returns (inflow) ──────────────────────────
        try:
            from dispensing.models import DispenseReturn
            ret_qs = DispenseReturn.objects.select_related('original', 'processed_by').filter(
                created_at__gte=start_dt,
                created_at__lt=end_dt,
                restock=True,
            )
            for ret in ret_qs:
                for idx, it in enumerate(ret.items_returned or []):
                    if reason_filter and reason_filter != 'return':
                        continue
                    if direction_filter and 'inflow' != direction_filter:
                        continue
                    if stock_id and it.get('stock_id') != stock_id:
                        continue
                    qty = int(it.get('qty', 0) or 0)
                    unit_val = float(it.get('unit_price', 0) or 0)
                    med_name = it.get('medication_name', 'Unknown')
                    movements.append({
                        'id': f'RET-{ret.id}-{idx}',
                        'date': ret.created_at.date().isoformat() if ret.created_at else '',
                        'timestamp': ret.created_at.isoformat() if ret.created_at else '',
                        'direction': 'inflow',
                        'type': 'return',
                        'reason': 'return',
                        'source': 'Dispense Return',
                        'reference': ret.reference or f'RET-{ret.id}',
                        'stock_name': med_name,
                        'stock_id': it.get('stock_id'),
                        'batch_number': '',
                        'quantity': qty,
                        'quantity_change': qty,
                        'unit_value': unit_val,
                        'value_change': qty * unit_val,
                        'user': str(ret.processed_by) if ret.processed_by else 'System',
                        'notes': ret.reason or '',
                    })
        except Exception:
            pass

        # ── Gather StockAdjustment rows ────────────────────────────────
        adj_qs = StockAdjustment.objects.select_related(
            'stock', 'batch', 'adjusted_by'
        ).filter(created_at__gte=start_dt, created_at__lt=end_dt)
        if reason_filter:
            adj_qs = adj_qs.filter(reason=reason_filter)
        if branch_id:
            adj_qs = adj_qs.filter(stock__branch_id=branch_id)
        if stock_id:
            adj_qs = adj_qs.filter(stock_id=stock_id)

        for adj in adj_qs:
            qty = int(adj.quantity_change or 0)
            direction = 'inflow' if qty >= 0 else 'outflow'
            if direction_filter and direction != direction_filter:
                continue
            movements.append({
                'id': f'ADJ-{adj.id}',
                'date': adj.created_at.date().isoformat() if adj.created_at else '',
                'timestamp': adj.created_at.isoformat() if adj.created_at else '',
                'direction': direction,
                'type': 'adjustment',
                'reason': adj.reason or 'other',
                'source': 'Stock Adjustment',
                'reference': f'ADJ-{adj.id}',
                'stock_name': adj.stock.medication_name if adj.stock else 'Unknown',
                'stock_id': adj.stock_id,
                'batch_number': adj.batch.batch_number if adj.batch else '',
                'quantity': abs(qty),
                'quantity_change': qty,
                'unit_value': float(adj.stock.cost_price or 0) if adj.stock else 0,
                'value_change': abs(qty) * float(adj.stock.cost_price or 0) if adj.stock else 0,
                'user': str(adj.adjusted_by) if adj.adjusted_by else 'System',
                'notes': adj.notes or '',
            })

        # ── Gather StockTransfer line items (one movement per item) ────
        tx_qs = StockTransfer.objects.select_related(
            'source_branch', 'dest_branch', 'requested_by'
        ).filter(requested_at__gte=start_dt, requested_at__lt=end_dt)
        if branch_id:
            tx_qs = tx_qs.filter(
                Q(source_branch_id=branch_id) | Q(dest_branch_id=branch_id)
            )
        for tx in tx_qs.prefetch_related('lines__stock'):
            if branch_id and tx.source_branch_id == int(branch_id):
                direction = 'outflow'
            elif branch_id and tx.dest_branch_id == int(branch_id):
                direction = 'inflow'
            else:
                direction = 'transfer'
            if direction_filter and direction != direction_filter:
                continue
            for line in tx.lines.all():
                if stock_id and line.stock_id != stock_id:
                    continue
                qty = int(line.quantity or 0)
                unit_cost = float(line.stock.cost_price or 0) if line.stock else 0
                movements.append({
                    'id': f'TRF-{tx.id}-{line.id}',
                    'date': tx.requested_at.date().isoformat() if tx.requested_at else '',
                    'timestamp': tx.requested_at.isoformat() if tx.requested_at else '',
                    'direction': direction,
                    'type': 'transfer',
                    'reason': 'branch_transfer',
                    'source': 'Branch Transfer',
                    'reference': tx.reference or f'TRF-{tx.id}',
                    'stock_name': line.stock.medication_name if line.stock else 'Unknown',
                    'stock_id': line.stock_id,
                    'batch_number': '',
                    'quantity': qty,
                    'quantity_change': qty if direction == 'inflow' else (-qty if direction == 'outflow' else 0),
                    'unit_value': unit_cost,
                    'value_change': qty * unit_cost,
                    'user': str(tx.requested_by) if tx.requested_by else 'System',
                    'notes': tx.notes or '',
                })

        # ── Gather Purchase Orders (received → inflow) ────────────────
        try:
            from purchase_orders.models import PurchaseOrder
            po_qs = PurchaseOrder.objects.filter(
                created_at__gte=start_dt,
                created_at__lt=end_dt,
                status=PurchaseOrder.Status.RECEIVED,
            )
            if branch_id:
                po_qs = po_qs.filter(branch_id=branch_id)
            for po in po_qs:
                for idx, it in enumerate((po.items or [])):
                    if reason_filter and reason_filter != 'purchase_order':
                        continue
                    if direction_filter and 'inflow' != direction_filter:
                        continue
                    sid = it.get('medication_stock_id') or it.get('stock_id')
                    if stock_id and sid != stock_id:
                        continue
                    qty = int(it.get('qty', 0) or 0)
                    unit_cost = float(it.get('unit_cost', 0) or 0)
                    med_name = it.get('name', 'Unknown')
                    movements.append({
                        'id': f'PO-{po.id}-{idx}',
                        'date': po.created_at.date().isoformat() if po.created_at else '',
                        'timestamp': po.created_at.isoformat() if po.created_at else '',
                        'direction': 'inflow',
                        'type': 'purchase_order',
                        'reason': 'purchase_order',
                        'source': 'Purchase Order',
                        'reference': po.po_number or f'PO-{po.id}',
                        'stock_name': med_name,
                        'stock_id': sid,
                        'batch_number': '',
                        'quantity': qty,
                        'quantity_change': qty,
                        'unit_value': unit_cost,
                        'value_change': qty * unit_cost,
                        'user': str(po.ordered_by) if po.ordered_by else 'System',
                        'notes': f'Supplier: {po.supplier}' if po.supplier_id else '',
                    })
        except Exception:
            pass

        # ── Gather Sales Orders (fulfilled → outflow) ──────────────────
        try:
            from sales_orders.models import SalesOrder
            so_qs = SalesOrder.objects.filter(
                created_at__gte=start_dt,
                created_at__lt=end_dt,
                status=SalesOrder.Status.FULFILLED,
            )
            if branch_id:
                so_qs = so_qs.filter(branch_id=branch_id)
            for so in so_qs:
                for idx, it in enumerate((so.items or [])):
                    if reason_filter and reason_filter != 'sales_order':
                        continue
                    if direction_filter and 'outflow' != direction_filter:
                        continue
                    sid = it.get('stock_id')
                    if stock_id and sid != stock_id:
                        continue
                    qty = int(it.get('qty', 0) or 0)
                    unit_price = float(it.get('unit_price', 0) or 0)
                    med_name = it.get('name', 'Unknown')
                    movements.append({
                        'id': f'SO-{so.id}-{idx}',
                        'date': so.created_at.date().isoformat() if so.created_at else '',
                        'timestamp': so.created_at.isoformat() if so.created_at else '',
                        'direction': 'outflow',
                        'type': 'sales_order',
                        'reason': 'sales_order',
                        'source': 'Sales Order',
                        'reference': so.so_number or f'SO-{so.id}',
                        'stock_name': med_name,
                        'stock_id': sid,
                        'batch_number': '',
                        'quantity': qty,
                        'quantity_change': -qty,
                        'unit_value': unit_price,
                        'value_change': qty * unit_price,
                        'user': str(so.created_by) if so.created_by else 'System',
                        'notes': f'Customer: {so.customer_name}' if so.customer_name else '',
                    })
        except Exception:
            pass

        # Sort by timestamp descending
        movements.sort(key=lambda x: x.get('timestamp') or x.get('date') or '', reverse=True)

        # Attach before/after on-hand quantities
        self._attach_qty_balances(movements)

        # ── KPIs ───────────────────────────────────────────────────────
        total_in = sum(m['quantity'] for m in movements if m['direction'] == 'inflow')
        total_out = sum(m['quantity'] for m in movements if m['direction'] == 'outflow')
        total_transfer = sum(m['quantity'] for m in movements if m['direction'] == 'transfer')
        net_change = total_in - total_out
        value_in = sum(m['value_change'] for m in movements if m['direction'] == 'inflow')
        value_out = sum(m['value_change'] for m in movements if m['direction'] == 'outflow')
        net_value = value_in - value_out

        # ── Per-day trend ──────────────────────────────────────────────
        day_index = []
        d0 = start
        num_days = max(1, (end - start).days + 1)
        for k in range(num_days):
            day_index.append((d0 + timedelta(days=k)).isoformat())
        daily_map = {}
        for m in movements:
            ds = m['date']
            if not ds:
                continue
            d = daily_map.setdefault(ds, {'in': 0, 'out': 0, 'transfer': 0})
            if m['direction'] == 'inflow':
                d['in'] += m['quantity']
            elif m['direction'] == 'outflow':
                d['out'] += m['quantity']
            else:
                d['transfer'] += m['quantity']
        trend = []
        for ds in day_index:
            d = daily_map.get(ds, {'in': 0, 'out': 0, 'transfer': 0})
            trend.append({
                'date': ds,
                'inflow': d['in'],
                'outflow': d['out'],
                'transfer': d['transfer'],
                'net': d['in'] - d['out'],
            })

        # ── Reason breakdown (donut) ──────────────────────────────────
        reason_map = {}
        for m in movements:
            r = m['reason'] or 'other'
            reason_map[r] = reason_map.get(r, 0) + m['quantity']
        reason_colors = {
            'damage': '#ef4444', 'theft': '#dc2626', 'expiry': '#f59e0b',
            'count_correction': '#3b82f6', 'return_to_supplier': '#8b5cf6',
            'other': '#64748b', 'branch_transfer': '#0ea5e9',
            'pos_sale': '#10b981', 'dispensing': '#14b8a6', 'return': '#f97316',
            'purchase_order': '#6366f1', 'sales_order': '#ec4899',
        }
        reason_labels = {
            'damage': 'Damage', 'theft': 'Theft', 'expiry': 'Expiry',
            'count_correction': 'Count Correction', 'return_to_supplier': 'Return to Supplier',
            'other': 'Other', 'branch_transfer': 'Branch Transfer',
            'pos_sale': 'POS Sale', 'dispensing': 'Dispensing', 'return': 'Dispense Return',
            'purchase_order': 'Purchase Order', 'sales_order': 'Sales Order',
        }
        reason_segments = [
            {'label': reason_labels.get(r, r.title()),
             'value': v, 'color': reason_colors.get(r, '#64748b')}
            for r, v in sorted(reason_map.items(), key=lambda x: -x[1])
            if v > 0
        ]

        # ── Top movers (by absolute quantity) ────────────────────────
        mover_map = {}
        for m in movements:
            if m['type'] == 'transfer':
                continue
            name = m['stock_name']
            if not name or name == 'Unknown':
                continue
            d = mover_map.setdefault(name, {'in': 0, 'out': 0, 'count': 0})
            if m['direction'] == 'inflow':
                d['in'] += m['quantity']
            elif m['direction'] == 'outflow':
                d['out'] += m['quantity']
            d['count'] += 1
        top_movers = [
            {'name': name, 'inflow': v['in'], 'outflow': v['out'],
             'net': v['in'] - v['out'], 'count': v['count']}
            for name, v in sorted(mover_map.items(),
                                  key=lambda x: abs(x[1]['in'] - x[1]['out']),
                                  reverse=True)
        ][:10]

        # ── Per-item rollup (each item individually) ──────────────────
        item_map = {}
        for m in movements:
            sid = m.get('stock_id')
            key = sid if sid is not None else f"name:{m.get('stock_name')}"
            d = item_map.setdefault(key, {
                'stock_id': sid,
                'name': m.get('stock_name') or 'Unknown',
                'in': 0, 'out': 0, 'transfer': 0, 'count': 0,
                'value_in': 0.0, 'value_out': 0.0,
            })
            if m['direction'] == 'inflow':
                d['in'] += m['quantity']
                d['value_in'] += m['value_change']
            elif m['direction'] == 'outflow':
                d['out'] += m['quantity']
                d['value_out'] += m['value_change']
            else:
                d['transfer'] += m['quantity']
            d['count'] += 1
        items_rollup = sorted(item_map.values(),
                             key=lambda x: abs(x['in'] - x['out']) + x['transfer'],
                             reverse=True)[:500]
        for d in items_rollup:
            d['net'] = d['in'] - d['out']
            d['value_in'] = round(d['value_in'], 2)
            d['value_out'] = round(d['value_out'], 2)

        fmt = (request.query_params.get('format') or request.query_params.get('fmt') or 'json').lower()
        if fmt == 'pdf':
            business_name = getattr(getattr(request, 'tenant', None), 'name', '') or ''
            return self._render_pdf(
                start, end, movements,
                {
                    'total_in': total_in, 'total_out': total_out,
                    'total_transfer': total_transfer, 'net_change': net_change,
                    'value_in': value_in, 'value_out': value_out,
                    'net_value': net_value, 'count': len(movements),
                },
                trend, reason_segments, top_movers, reason_labels,
                reason_colors=reason_colors,
                business_name=business_name,
            )

        return Response({
            'range': {'start': start.isoformat(), 'end': end.isoformat()},
            'kpis': {
                'total_in': total_in,
                'total_out': total_out,
                'total_transfer': total_transfer,
                'net_change': net_change,
                'value_in': round(value_in, 2),
                'value_out': round(value_out, 2),
                'net_value': round(net_value, 2),
                'count': len(movements),
            },
            'trend': trend,
            'reason_segments': reason_segments,
            'top_movers': top_movers,
            'items': items_rollup,
            'movements': movements[:200],
        })

