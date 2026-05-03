from rest_framework import viewsets, filters, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from django_filters.rest_framework import DjangoFilterBackend
from django.db.models import Sum, F, DecimalField
from django.db.models.functions import Coalesce
from django.utils import timezone
from django.http import HttpResponse
from datetime import timedelta
import csv
import io

from .models import Category, Unit, MedicationStock, StockBatch, StockAdjustment
from .serializers import (
    CategorySerializer, UnitSerializer,
    MedicationStockSerializer, StockBatchSerializer, StockAdjustmentSerializer,
)


class CategoryViewSet(viewsets.ModelViewSet):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name']
    ordering_fields = ['name', 'created_at']


class UnitViewSet(viewsets.ModelViewSet):
    queryset = Unit.objects.all()
    serializer_class = UnitSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name', 'abbreviation']
    ordering_fields = ['name', 'created_at']


class MedicationStockViewSet(viewsets.ModelViewSet):
    queryset = MedicationStock.objects.select_related('category', 'unit').prefetch_related('batches').all()
    serializer_class = MedicationStockSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['is_active', 'category', 'unit']
    search_fields = ['medication_name', 'barcode']
    ordering_fields = ['medication_name', 'selling_price', 'created_at']

    @action(detail=False, methods=['get'])
    def low_stock(self, request):
        stocks = self.get_queryset().filter(is_active=True)
        low = [s for s in stocks if s.is_low_stock]
        serializer = self.get_serializer(low, many=True)
        return Response(serializer.data)

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
        fmt = request.query_params.get('format', 'csv').lower()
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


class StockBatchViewSet(viewsets.ModelViewSet):
    queryset = StockBatch.objects.select_related('stock', 'supplier').all()
    serializer_class = StockBatchSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['stock', 'expiry_date']
    search_fields = ['batch_number', 'stock__medication_name']
    ordering_fields = ['expiry_date', 'received_date']


class StockAdjustmentViewSet(viewsets.ModelViewSet):
    queryset = StockAdjustment.objects.select_related('stock', 'batch', 'adjusted_by').all()
    serializer_class = StockAdjustmentSerializer
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
