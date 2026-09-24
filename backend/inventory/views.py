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

from .models import (
    Category, Unit, MedicationStock, StockBatch, StockAdjustment,
    InventoryCount, InventoryCountLine,
    StockTransfer, StockTransferLine,
    ControlledSubstanceLog,
)
from .serializers import (
    CategorySerializer, UnitSerializer,
    MedicationStockSerializer, StockBatchSerializer, StockAdjustmentSerializer,
    InventoryCountSerializer, InventoryCountLineSerializer,
    StockTransferSerializer,
    ControlledSubstanceLogSerializer,
)
from config.branch_scope import BranchScopedMixin
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


class MedicationStockViewSet(BranchScopedMixin, viewsets.ModelViewSet):
    queryset = MedicationStock.objects.select_related('category', 'unit', 'branch').prefetch_related('batches').all()
    serializer_class = MedicationStockSerializer
    permission_classes = [InventoryPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['is_active', 'category', 'unit']
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
        serializer = StockBatchSerializer(batches, many=True)
        return Response(serializer.data)

    # ── Export ────────────────────────────────────────────────────────────────
    _EXPORT_HEADERS = [
        'ID', 'Medication Name', 'Category', 'Unit',
        'Selling Price (KSh)', 'Cost Price (KSh)',
        'Total Quantity', 'Reorder Level', 'Reorder Quantity',
        'Location', 'Barcode', 'Prescription Required', 'Active',
        'Created At',
    ]

    def _stock_row(self, s):
        return [
            s.id, s.medication_name,
            s.category.name if s.category else '',
            s.unit.name if s.unit else '',
            float(s.selling_price), float(s.cost_price),
            s.total_quantity, s.reorder_level, s.reorder_quantity,
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

        def _process_row(row_num, name, category_name, selling_price_str, cost_price_str, reorder_level_str, reorder_qty_str, location, barcode, prescription):
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

            valid_rx = {'none', 'recommended', 'required'}
            rx = (prescription or 'none').strip().lower()
            if rx not in valid_rx:
                rx = 'none'

            stock, was_created = MedicationStock.objects.update_or_create(
                medication_name=name,
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
        'branch': ['Branch (Warehouse)', 'Branch', 'Warehouse', 'branch', 'warehouse'],
        'category': ['Category', 'category'],
        'unit': ['Unit', 'unit'],
        'selling_price': ['Selling Price (KSh)', 'selling_price', 'Selling Price'],
        'cost_price': ['Cost Price (KSh)', 'cost_price', 'Cost Price'],
        'discount_percent': ['Discount %', 'discount_percent'],
        'tax_percent': ['Tax %', 'tax_percent'],
        'total_quantity': ['Total Quantity', 'total_quantity'],
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

        for f in ('total_quantity', 'reorder_level', 'reorder_quantity'):
            v = raw.get(f)
            if f != 'total_quantity' and v in (None, ''):
                continue
            if f == 'total_quantity' and v in (None, ''):
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

        for f in ('category', 'unit', 'location_in_store', 'barcode'):
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
            ('Branch (Warehouse)', 22, 'required for new items'),
            ('Category', 20, 'auto-created if missing'),
            ('Unit', 14, 'auto-created if missing'),
            ('Selling Price (KSh)', 18, 'number'),
            ('Cost Price (KSh)', 18, 'number'),
            ('Discount %', 12, '0 – 100'),
            ('Tax %', 12, '0 – 100'),
            ('Total Quantity', 16, 'blank = keep current stock'),
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
        EXAMPLE = ['Paracetamol 500mg', example_branch, 'Analgesics', 'tablets', 25.00, 15.00,
                    0, 16, 500, 10, 50, 'Shelf A2', '890123456789', 'none', 'Yes']

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

        dv_rx = DataValidation(type='list', formula1='"none,recommended,required"',
                               allow_blank=True, showDropDown=False)
        dv_rx.error = 'Must be none, recommended or required'
        ws.add_data_validation(dv_rx)
        dv_rx.add('N3:N1000')
        dv_act = DataValidation(type='list', formula1='"Yes,No"',
                                allow_blank=True, showDropDown=False)
        dv_act.error = 'Must be Yes or No'
        ws.add_data_validation(dv_act)
        dv_act.add('O3:O1000')

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
            '4. Existing medications are matched by name (case-insensitive) and updated. New names create new items.',
            '5. "Total Quantity" is optional — leave blank to keep current stock. A value creates a count-correction adjustment.',
            '6. Blank cells keep existing values on update; defaults apply to new items.',
            '7. Category and Unit are created automatically if they do not exist.',
            '8. Supported formats: .xlsx and .csv',
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
            s.medication_name.lower(): {'id': s.id, 'quantity': int(s.qty or 0)}
            for s in (MedicationStock.objects
                      .annotate(qty=Coalesce(Sum('batches__quantity_remaining',
                                                  filter=Q(batches__quantity_remaining__gt=0)), 0))
                      .only('id', 'medication_name'))
        }
        branch_names = {b.id: b.name for b in Branch.objects.filter(is_active=True)}

        rows, seen = [], {}
        counts = {'new': 0, 'update': 0, 'error': 0}
        for num, raw in parsed:
            cleaned, errors = self._clean_import_row(raw)
            key = cleaned['medication_name'].lower()
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
            branch_id = cleaned['branch'] if isinstance(cleaned['branch'], int) else None
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

                stock = MedicationStock.objects.filter(medication_name__iexact=name).first()
                is_new = stock is None
                if is_new:
                    stock = MedicationStock(medication_name=name)

                # Branch / warehouse (compulsory for new items).
                branch_val = item.get('branch')
                if branch_val not in (None, ''):
                    branch = None
                    if isinstance(branch_val, int) or (isinstance(branch_val, str) and branch_val.isdigit()):
                        branch = Branch.objects.filter(id=int(branch_val)).first()
                    if branch is None:
                        branch = (Branch.objects
                                  .filter(name__iexact=str(branch_val).strip())
                                  .first())
                    if branch is None:
                        raise ValueError(f'Unknown warehouse "{branch_val}"')
                    stock.branch = branch
                elif is_new:
                    raise ValueError('Branch (warehouse) is required for new items')

                if item.get('category'):
                    stock.category, _ = Category.objects.get_or_create(
                        name=str(item['category']).strip())
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

                for f in ('location_in_store', 'barcode'):
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
    queryset = StockBatch.objects.select_related('stock', 'supplier').all()
    serializer_class = StockBatchSerializer
    permission_classes = [InventoryPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['stock', 'expiry_date']
    search_fields = ['batch_number', 'stock__medication_name']
    ordering_fields = ['expiry_date', 'received_date']


class StockAdjustmentViewSet(viewsets.ModelViewSet):
    queryset = StockAdjustment.objects.select_related('stock', 'batch', 'adjusted_by').all()
    serializer_class = StockAdjustmentSerializer
    permission_classes = [AdjustmentPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['stock', 'reason']
    search_fields = ['stock__medication_name', 'notes']
    ordering_fields = ['created_at']


class InventoryAnalyticsView(APIView):
    """Aggregated inventory analytics for the pharmacy dashboard."""

    def get(self, request):
        stocks = MedicationStock.objects.prefetch_related('batches').filter(is_active=True)
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
        expiring_30 = StockBatch.objects.filter(
            expiry_date__lte=now + timedelta(days=30),
            expiry_date__gt=now,
            quantity_remaining__gt=0,
        ).count()
        expiring_90 = StockBatch.objects.filter(
            expiry_date__lte=now + timedelta(days=90),
            expiry_date__gt=now,
            quantity_remaining__gt=0,
        ).count()
        expired = StockBatch.objects.filter(
            expiry_date__lt=now,
            quantity_remaining__gt=0,
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

        stocks = MedicationStock.objects.prefetch_related('batches').filter(is_active=True)

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
        expiring_30 = StockBatch.objects.filter(
            expiry_date__lte=today + timedelta(days=30),
            expiry_date__gte=today,
            quantity_remaining__gt=0,
        ).count()
        expiring_90 = StockBatch.objects.filter(
            expiry_date__lte=today + timedelta(days=90),
            expiry_date__gte=today,
            quantity_remaining__gt=0,
        ).count()
        expired = StockBatch.objects.filter(
            expiry_date__lt=today,
            quantity_remaining__gt=0,
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
            if date_from:
                po_qs = po_qs.filter(order_date__gte=date_from)
            if date_to:
                po_qs = po_qs.filter(order_date__lte=date_to)
            open_pos = po_qs.filter(
                status__in=('draft', 'sent', 'partial')).count()

            grn_qs = GoodsReceivedNote.objects.all()
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
from django_filters import DateFilter, FilterSet


class StockTransferFilterSet(FilterSet):
    """Adds from_date / to_date (inclusive, by requested_at) on top of the
    standard status / source / destination filters."""
    from_date = DateFilter(field_name='requested_at__date', lookup_expr='gte')
    to_date = DateFilter(field_name='requested_at__date', lookup_expr='lte')

    class Meta:
        model = StockTransfer
        fields = ['status', 'source_branch', 'dest_branch', 'from_date', 'to_date']


class StockTransferViewSet(viewsets.ModelViewSet):
    queryset = StockTransfer.objects.select_related(
        'source_branch', 'dest_branch', 'requested_by', 'approved_by', 'received_by'
    ).prefetch_related('lines__stock__unit').all()
    serializer_class = StockTransferSerializer
    permission_classes = [TransferPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_class = StockTransferFilterSet
    search_fields = ['reference', 'notes']
    ordering_fields = ['requested_at', 'shipped_at', 'received_at']

    def _set_status(self, transfer, new_status, user, field):
        transfer.status = new_status
        if user and user.is_authenticated:
            setattr(transfer, field, user)
        if new_status == StockTransfer.Status.IN_TRANSIT:
            transfer.shipped_at = timezone.now()
        if new_status == StockTransfer.Status.COMPLETED:
            transfer.received_at = timezone.now()
        transfer.save()

    @action(detail=False, methods=['get'])
    def stats(self, request):
        """KPIs for the transfers dashboard header."""
        qs = self.get_queryset()
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

    @action(detail=True, methods=['post'])
    def submit(self, request, pk=None):
        """Move from draft to requested."""
        transfer = self.get_object()
        if transfer.status != StockTransfer.Status.DRAFT:
            return Response({'detail': 'Only drafts can be submitted.'}, status=400)
        transfer.status = StockTransfer.Status.REQUESTED
        transfer.save(update_fields=['status'])
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

        with db_transaction.atomic():
            # ── Pre-flight: verify on-hand stock covers every line ──────
            shortages = []
            for line in transfer.lines.select_related('stock').all():
                available = sum(
                    b.quantity_remaining for b in
                    line.stock.batches.filter(quantity_remaining__gt=0)
                )
                if line.quantity > available:
                    shortages.append({
                        'stock': line.stock.medication_name,
                        'requested': line.quantity,
                        'available': available,
                    })
            if shortages:
                return Response(
                    {'detail': 'Insufficient stock for this transfer.',
                     'shortages': shortages},
                    status=400,
                )

            # ── FEFO deduction at source branch (or any batch if unset) ──
            for line in transfer.lines.all():
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

            self._set_status(transfer, StockTransfer.Status.IN_TRANSIT, request.user, 'approved_by')
        return Response(self.get_serializer(transfer).data)

    @action(detail=True, methods=['post'])
    def receive(self, request, pk=None):
        """Receive at destination: create a new batch per line.

        Payload: {lines: [{id, quantity_received, notes}]} to record short
        receipts and per-line remarks (e.g. "2 units damaged").

        Validations: received qty must be 0 <= qty <= sent qty.
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
            if qty_received > 0:
                StockBatch.objects.create(
                    stock=line.stock,
                    batch_number=f'TRF-{transfer.reference}',
                    quantity_received=qty_received,
                    quantity_remaining=qty_received,
                    cost_price_per_unit=line.stock.cost_price or 0,
                    expiry_date=_d.today() + _td(days=365),
                    branch=transfer.dest_branch,
                )

        self._set_status(transfer, StockTransfer.Status.COMPLETED, request.user, 'received_by')

        # Lines were mutated — drop the prefetched cache so the response
        # reflects the freshly saved values (get_object() prefetches lines).
        if hasattr(transfer, '_prefetched_objects_cache'):
            transfer._prefetched_objects_cache.pop('lines', None)

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
        })

    @action(detail=True, methods=['post'])
    def cancel(self, request, pk=None):
        transfer = self.get_object()
        if transfer.status in (StockTransfer.Status.COMPLETED, StockTransfer.Status.CANCELLED):
            return Response({'detail': 'Cannot cancel this transfer.'}, status=400)
        transfer.status = StockTransfer.Status.CANCELLED
        transfer.save(update_fields=['status'])
        return Response(self.get_serializer(transfer).data)

    @action(detail=True, methods=['get'], url_path='pdf')
    def pdf(self, request, pk=None):
        """Printable, branded transfer note (portrait A4)."""
        import io as _io
        from reportlab.lib.pagesizes import A4
        from reportlab.lib.units import mm
        from reportlab.lib.colors import HexColor, white
        from reportlab.lib.styles import ParagraphStyle
        from reportlab.lib.enums import TA_CENTER, TA_RIGHT
        from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer,
                                        Table, TableStyle)
        from datetime import datetime as _dtc

        transfer = self.get_object()
        NAVY = HexColor('#0F172A')
        SKY = HexColor('#0EA5E9')
        SLATE = HexColor('#64748B')
        BORDER = HexColor('#E2E8F0')

        st_title = ParagraphStyle('t', fontName='Helvetica-Bold', fontSize=18,
                                 textColor=white)
        st_sub = ParagraphStyle('s', fontName='Helvetica', fontSize=9, textColor=white)
        st_h = ParagraphStyle('h', fontName='Helvetica-Bold', fontSize=10, textColor=NAVY)
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

        # ── Header band ─────────────────────────────────────────────
        head = Table(
            [[Paragraph('Stock Transfer Note', st_title),
              Paragraph(f'{transfer.reference}', ParagraphStyle(
                  'ref', parent=st_sub, fontSize=14, alignment=TA_RIGHT, fontName='Helvetica-Bold'))],
             [Paragraph(tenant_name, st_sub),
              Paragraph(f'Status: {status_display}', ParagraphStyle(
                  'st', parent=st_sub, alignment=TA_RIGHT))]],
            colWidths=[110 * mm, 68 * mm],
        )
        head.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), SKY),
            ('SPAN', (0, 0), (0, 1)),
            ('SPAN', (1, 0), (1, 1)),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (0, -1), 10),
            ('RIGHTPADDING', (1, 0), (1, -1), 10),
            ('TOPPADDING', (0, 0), (0, 0), 8),
        ]))
        story.append(head)
        story.append(Spacer(1, 8 * mm))

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
            ('BACKGROUND', (0, 0), (-1, 0), HexColor('#E0F2FE')),
            ('GRID', (0, 0), (-1, -1), 0.5, BORDER),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('TOPPADDING', (0, 0), (-1, -1), 4),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
            ('BACKGROUND', (0, -1), (-1, -1), HexColor('#F1F5F9')),
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
        story.append(Spacer(1, 12 * mm))
        sig = Table([[Paragraph('Received by (sign & date)', st_k),
                      Paragraph('Checked by (sign & date)', st_k)]],
                    colWidths=[89 * mm, 89 * mm])
        sig.setStyle(TableStyle([
            ('LINEBELOW', (0, 0), (0, 0), 0.75, NAVY),
            ('LINEBELOW', (1, 0), (1, 0), 0.75, NAVY),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
        ]))
        story.append(sig)

        def _page(canv, doc_):
            canv.saveState()
            canv.setFont('Helvetica', 7)
            canv.setFillColor(SLATE)
            canv.drawString(16 * mm, 8 * mm,
                            f'{tenant_name} · Stock Transfer {transfer.reference}')
            canv.drawRightString(194 * mm, 8 * mm,
                                 f'Page {canv.getPageNumber()} · Generated {timezone.now():%b %d %Y}')
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
        }
        reason_labels = {
            'damage': 'Damage', 'theft': 'Theft', 'expiry': 'Expiry',
            'count_correction': 'Count Correction', 'return_to_supplier': 'Return to Supplier',
            'other': 'Other', 'branch_transfer': 'Branch Transfer',
            'pos_sale': 'POS Sale', 'dispensing': 'Dispensing', 'return': 'Dispense Return',
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

