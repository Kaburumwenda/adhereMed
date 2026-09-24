import csv
import io
import uuid
from datetime import date
from decimal import Decimal

from django.http import HttpResponse
from django.utils import timezone
from rest_framework import viewsets, filters, status
from rest_framework.decorators import action
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend

from config.branch_scope import BranchScopedMixin
from config.pdf_branding import resolve_branding
from .models import SalesOrder
from .serializers import SalesOrderSerializer


class SalesOrderViewSet(BranchScopedMixin, viewsets.ModelViewSet):
    queryset = SalesOrder.objects.select_related('customer', 'branch', 'created_by').all()
    serializer_class = SalesOrderSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'payment_status', 'branch', 'customer']
    search_fields = ['so_number', 'customer_name', 'customer_phone', 'notes']
    ordering_fields = ['created_at', 'expected_delivery', 'total_amount']

    def get_queryset(self):
        """Extend the base queryset with optional date range filters."""
        qs = super().get_queryset()
        params = self.request.query_params
        date_from = params.get('date_from')
        date_to = params.get('date_to')
        if date_from:
            qs = qs.filter(created_at__date__gte=date_from)
        if date_to:
            qs = qs.filter(created_at__date__lte=date_to)
        return qs

    @action(detail=True, methods=['post'], url_path='record-payment')
    def record_payment(self, request, pk=None):
        """Add a payment to the order. Payload: { "amount": 5000, "payment_method": "mpesa" }"""
        so = self.get_object()
        try:
            amount = Decimal(str(request.data.get('amount')))
        except Exception:
            return Response({'detail': 'amount must be a number.'}, status=400)
        if amount <= 0:
            return Response({'detail': 'amount must be greater than zero.'}, status=400)
        so.amount_paid = (so.amount_paid or 0) + amount
        method = request.data.get('payment_method')
        if method and method in dict(SalesOrder.PaymentMethod.choices):
            so.payment_method = method
        so.recompute_payment_status()
        so.save(update_fields=['amount_paid', 'payment_method', 'payment_status', 'updated_at'])
        # Paid / partially paid orders commit stock for their items
        from .serializers import _sync_stock_commitment
        _sync_stock_commitment(so)
        return Response(self.get_serializer(so).data)

    # ── Excel / CSV export ─────────────────────────────────────────────
    _EXPORT_HEADERS = ['SO Number', 'Customer', 'Phone', 'Branch', 'Status',
                       'Payment Status', 'Payment Method', 'Items', 'Total (KSh)',
                       'Discount (KSh)', 'Delivery Fee (KSh)',
                       'Paid (KSh)', 'Balance (KSh)',
                       'Expected Delivery', 'Created', 'Notes']

    def _so_row(self, so):
        return [
            so.so_number,
            so.customer_name,
            so.customer_phone,
            so.branch.name if so.branch else '',
            so.get_status_display(),
            so.get_payment_status_display(),
            so.get_payment_method_display(),
            len(so.items or []),
            float(so.total_amount or 0),
            float(so.discount_amount or 0),
            float(so.delivery_fee or 0),
            float(so.total_amount or 0),
            float(so.discount_amount or 0),
            float(so.amount_paid or 0),
            float(so.balance_due),
            so.expected_delivery.isoformat() if so.expected_delivery else '',
            so.created_at.strftime('%Y-%m-%d'),
            so.notes or '',
        ]

    @action(detail=False, methods=['get'], url_path='export')
    def export(self, request):
        """Export sales orders as .xlsx or .csv (?fmt=excel|csv)."""
        qs = self.filter_queryset(self.get_queryset())
        fmt = (request.query_params.get('fmt') or 'excel').lower()
        stamp = timezone.now().strftime('%Y%m%d')

        if fmt == 'csv':
            fname = f'sales_orders_{stamp}.csv'
            response = HttpResponse(content_type='text/csv')
            response['Content-Disposition'] = f'attachment; filename="{fname}"'
            writer = csv.writer(response)
            writer.writerow(self._EXPORT_HEADERS)
            for so in qs:
                writer.writerow(self._so_row(so))
            return response

        try:
            from openpyxl import Workbook
            from openpyxl.styles import Font, PatternFill
            from openpyxl.utils import get_column_letter
        except ImportError:
            return Response({'detail': 'openpyxl not installed.'}, status=500)

        wb = Workbook()
        ws = wb.active
        ws.title = 'Sales Orders'
        ws.append(self._EXPORT_HEADERS)
        for c in ws[1]:
            c.font = Font(bold=True, color='FFFFFF')
            c.fill = PatternFill('solid', fgColor='0D9488')
        for so in qs:
            ws.append(self._so_row(so))
        for i, w in enumerate([16, 28, 16, 20, 18, 16, 8, 16, 16, 14, 14, 18, 12, 40], 1):
            ws.column_dimensions[get_column_letter(i)].width = w
        buf = io.BytesIO()
        wb.save(buf)
        buf.seek(0)
        fname = f'sales_orders_{stamp}.xlsx'
        return HttpResponse(
            buf.read(),
            content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            headers={'Content-Disposition': f'attachment; filename="{fname}"'},
        )

    # ── Premium PDF: single sales order ──────────────────────────────────
    @action(detail=True, methods=['get'], url_path='so-pdf')
    def so_pdf(self, request, pk=None):
        """Generate a branded premium PDF of the Sales Order (SO)."""
        try:
            from reportlab.lib.pagesizes import A4
            from reportlab.lib.units import mm
            from reportlab.lib.colors import HexColor
            from reportlab.lib.styles import ParagraphStyle
            from reportlab.lib.enums import TA_RIGHT, TA_CENTER
            from reportlab.platypus import (
                SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image as RLImage,
            )
        except ImportError:
            return Response({'detail': 'reportlab not installed.'}, status=500)

        so = self.get_object()
        logo_path, business_name = resolve_branding(request)

        NAVY = HexColor('#0F172A')
        TEAL = HexColor('#0D9488')
        SLATE = HexColor('#64748B')
        BORDER = HexColor('#E2E8F0')
        BG = HexColor('#F8FAFC')
        WHITE = HexColor('#FFFFFF')
        STATUS_COLORS = {
            'draft': HexColor('#64748B'),
            'confirmed': HexColor('#2563EB'),
            'partial': HexColor('#D97706'),
            'fulfilled': HexColor('#16A34A'),
            'cancelled': HexColor('#DC2626'),
        }
        PAY_COLORS = {
            'unpaid': HexColor('#DC2626'),
            'partial': HexColor('#D97706'),
            'paid': HexColor('#16A34A'),
        }
        status_color = STATUS_COLORS.get(so.status, SLATE)
        pay_color = PAY_COLORS.get(so.payment_status, SLATE)

        def money(v):
            try:
                return f'KSh {float(v or 0):,.2f}'
            except (TypeError, ValueError):
                return 'KSh 0.00'

        def fmt_date(d):
            return d.strftime('%d %b %Y') if d else '—'

        PAGE_W = A4[0] - 30 * mm
        buf = io.BytesIO()
        doc = SimpleDocTemplate(
            buf, pagesize=A4,
            leftMargin=15 * mm, rightMargin=15 * mm,
            topMargin=12 * mm, bottomMargin=18 * mm,
            title=f'Sales Order {so.so_number}',
        )

        st_brand = ParagraphStyle('brand', fontName='Helvetica-Bold', fontSize=13,
                                  textColor=NAVY, leading=16)
        st_brand_sub = ParagraphStyle('brandsub', fontName='Helvetica', fontSize=8,
                                      textColor=SLATE, leading=11)
        st_doctitle = ParagraphStyle('doctitle', fontName='Helvetica-Bold', fontSize=20,
                                     textColor=TEAL, leading=24, alignment=TA_RIGHT)
        st_docsub = ParagraphStyle('docsub', fontName='Helvetica', fontSize=9,
                                   textColor=SLATE, leading=12, alignment=TA_RIGHT)
        st_label = ParagraphStyle('label', fontName='Helvetica-Bold', fontSize=6.5,
                                  textColor=SLATE, leading=9)
        st_value = ParagraphStyle('value', fontName='Helvetica-Bold', fontSize=10,
                                  textColor=NAVY, leading=13)
        st_section = ParagraphStyle('section', fontName='Helvetica-Bold', fontSize=9,
                                    textColor=NAVY, leading=12)
        st_body = ParagraphStyle('body', fontName='Helvetica', fontSize=8.5,
                                 textColor=SLATE, leading=12)
        st_cell = ParagraphStyle('cell', fontName='Helvetica', fontSize=8.5, leading=12,
                                 textColor=NAVY)
        st_cell_r = ParagraphStyle('cellr', parent=st_cell, alignment=TA_RIGHT)
        st_cell_b = ParagraphStyle('cellb', parent=st_cell, fontName='Helvetica-Bold')
        st_cell_b_r = ParagraphStyle('cellbr', parent=st_cell_b, alignment=TA_RIGHT)
        st_hdr = ParagraphStyle('hdr', parent=st_cell_b, textColor=WHITE, fontSize=8)
        st_hdr_r = ParagraphStyle('hdrr', parent=st_hdr, alignment=TA_RIGHT)
        st_pill = ParagraphStyle('pill', fontName='Helvetica-Bold', fontSize=8,
                                 textColor=WHITE, alignment=TA_CENTER)
        st_tot_lbl = ParagraphStyle('totlbl', fontName='Helvetica', fontSize=9,
                                    textColor=SLATE, leading=13)
        st_tot_lbl_w = ParagraphStyle('totlblw', parent=st_tot_lbl,
                                      fontName='Helvetica-Bold', textColor=WHITE)
        st_tot_val = ParagraphStyle('totval', fontName='Helvetica', fontSize=9,
                                    textColor=NAVY, leading=13, alignment=TA_RIGHT)
        st_tot_val_w = ParagraphStyle('totvalw', fontName='Helvetica-Bold', fontSize=12,
                                      textColor=WHITE, leading=15, alignment=TA_RIGHT)

        def section_heading(text):
            bar = Table([['']], colWidths=[1.2 * mm], rowHeights=[3.6 * mm])
            bar.setStyle(TableStyle([('BACKGROUND', (0, 0), (-1, -1), TEAL)]))
            t = Table([[bar, Paragraph(text, st_section)]], colWidths=[3 * mm, PAGE_W - 3 * mm])
            t.setStyle(TableStyle([
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 0),
                ('TOPPADDING', (0, 0), (-1, -1), 0),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
            ]))
            return t

        def pill(text, color, width):
            t = Table([[Paragraph(text, st_pill)]], colWidths=[width])
            t.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, -1), color),
                ('TOPPADDING', (0, 0), (-1, -1), 3),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
            ]))
            return t

        def meta_card(label, value_flowable, card_w):
            t = Table([[label], [value_flowable]], colWidths=[card_w])
            t.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, -1), BG),
                ('BOX', (0, 0), (-1, -1), 0.75, BORDER),
                ('LEFTPADDING', (0, 0), (-1, -1), 9),
                ('RIGHTPADDING', (0, 0), (-1, -1), 9),
                ('TOPPADDING', (0, 0), (-1, 0), 7),
                ('BOTTOMPADDING', (0, 0), (-1, 0), 1),
                ('TOPPADDING', (0, 1), (-1, 1), 1),
                ('BOTTOMPADDING', (0, 1), (-1, 1), 7),
            ]))
            return t

        story = []

        # Header
        logo = RLImage(logo_path, width=15 * mm, height=15 * mm, kind='proportional')
        tenant = getattr(request, 'tenant', None)
        tenant_subs = []
        if tenant:
            addr = ', '.join(x for x in [getattr(tenant, 'address', '') or '',
                                         getattr(tenant, 'city', '') or ''] if x)
            if addr:
                tenant_subs.append(addr)
            contact = ' · '.join(x for x in [getattr(tenant, 'phone', '') or '',
                                             getattr(tenant, 'email', '') or ''] if x)
            if contact:
                tenant_subs.append(contact)
        left_block = [Paragraph(business_name, st_brand)] + \
            [Paragraph(s, st_brand_sub) for s in tenant_subs]
        right_block = [
            Paragraph('SALES ORDER', st_doctitle),
            Paragraph(f'SO · {so.so_number}', st_docsub),
        ]
        header_tbl = Table([[logo, left_block, right_block]],
                           colWidths=[17 * mm, PAGE_W - 17 * mm - 64 * mm, 64 * mm])
        header_tbl.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (0, 0), 8),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ]))
        story.append(header_tbl)
        story.append(Spacer(1, 4 * mm))
        strip = Table([['']], colWidths=[PAGE_W], rowHeights=[1.6 * mm])
        strip.setStyle(TableStyle([('BACKGROUND', (0, 0), (-1, -1), TEAL)]))
        story.append(strip)
        story.append(Spacer(1, 5 * mm))

        # Meta cards
        gap = 3.75 * mm
        card_w = (PAGE_W - 3 * gap) / 4
        status_card = Table(
            [[Paragraph('STATUS', st_label)], [pill(so.get_status_display(), status_color, 24 * mm)]],
            colWidths=[card_w],
            style=TableStyle([
                ('BACKGROUND', (0, 0), (-1, -1), BG),
                ('BOX', (0, 0), (-1, -1), 0.75, BORDER),
                ('LEFTPADDING', (0, 0), (-1, -1), 9),
                ('RIGHTPADDING', (0, 0), (-1, -1), 9),
                ('TOPPADDING', (0, 0), (-1, 0), 7),
                ('BOTTOMPADDING', (0, 0), (-1, 0), 1),
                ('TOPPADDING', (0, 1), (-1, 1), 2),
                ('BOTTOMPADDING', (0, 1), (-1, 1), 6),
            ]),
        )
        meta_row = Table([[
            meta_card('SO NUMBER', Paragraph(so.so_number, st_value), card_w),
            '',
            meta_card('EXPECTED DELIVERY', Paragraph(fmt_date(so.expected_delivery), st_value), card_w),
            '',
            meta_card('CREATED', Paragraph(fmt_date(so.created_at.date() if so.created_at else None), st_value), card_w),
            '',
            status_card,
        ]], colWidths=[card_w, gap, card_w, gap, card_w, gap, card_w])
        meta_row.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ]))
        story.append(meta_row)
        story.append(Spacer(1, 7 * mm))

        # Customer / delivery
        customer_block = [
            section_heading('CUSTOMER'),
            Spacer(1, 3 * mm),
            Paragraph(so.customer_name or '—', ParagraphStyle('cname', parent=st_cell_b, fontSize=10.5, leading=13)),
        ]
        if so.customer_phone:
            customer_block.append(Paragraph(f'Phone:  {so.customer_phone}', st_body))
        delivery_block = [
            section_heading('DELIVER TO'),
            Spacer(1, 3 * mm),
            Paragraph((so.delivery_address or '—').replace('\n', ', '), st_body),
        ]
        if so.expected_delivery:
            delivery_block.append(Paragraph(f'Expected: {fmt_date(so.expected_delivery)}', st_body))
        half = (PAGE_W - 8 * mm) / 2
        party_tbl = Table([[customer_block, delivery_block]], colWidths=[half, half])
        party_tbl.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (0, 0), 0),
            ('LEFTPADDING', (1, 0), (1, 0), 8 * mm),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ]))
        story.append(party_tbl)
        story.append(Spacer(1, 6 * mm))

        # Items table
        story.append(section_heading('ORDER ITEMS'))
        story.append(Spacer(1, 3.5 * mm))
        item_rows = [[
            Paragraph('#', st_hdr), Paragraph('ITEM', st_hdr),
            Paragraph('QTY', st_hdr_r), Paragraph('UNIT PRICE', st_hdr_r),
            Paragraph('DISC %', st_hdr_r), Paragraph('LINE TOTAL', st_hdr_r),
        ]]
        items_subtotal = Decimal('0')
        for i, it in enumerate(so.items or [], 1):
            items_subtotal += Decimal(str(it.get('total') or 0))
            item_rows.append([
                Paragraph(str(i), st_cell),
                Paragraph(it.get('name') or '', st_cell),
                Paragraph(str(int(it.get('qty') or 0)), st_cell_r),
                Paragraph(money(it.get('unit_price')), st_cell_r),
                Paragraph(str(float(it.get('discount_percent') or 0)), st_cell_r),
                Paragraph(money(it.get('total')), st_cell_b_r),
            ])
        if not (so.items or []):
            item_rows.append([Paragraph('No items on this order', st_cell), '', '', '', '', ''])
        items_tbl = Table(item_rows, colWidths=[
            8 * mm, PAGE_W - (8 + 14 + 26 + 16 + 28) * mm,
            14 * mm, 26 * mm, 16 * mm, 28 * mm,
        ], repeatRows=1)
        items_tbl.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), NAVY),
            ('LINEBELOW', (0, 0), (-1, 0), 1, TEAL),
            ('LINEBELOW', (0, 1), (-1, -1), 0.4, BORDER),
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [None, BG]),
            ('LEFTPADDING', (0, 0), (-1, -1), 6),
            ('RIGHTPADDING', (0, 0), (-1, -1), 6),
            ('TOPPADDING', (0, 0), (-1, -1), 5),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ]))
        story.append(items_tbl)
        story.append(Spacer(1, 5 * mm))

        # Totals + payment card
        totals = [
            [Paragraph('Items subtotal', st_tot_lbl), Paragraph(money(items_subtotal), st_tot_val)],
            [Paragraph('Order discount', st_tot_lbl), Paragraph(money(so.discount_amount), st_tot_val)],
            [Paragraph('Delivery fee', st_tot_lbl), Paragraph(money(so.delivery_fee), st_tot_val)],
            [Paragraph('Paid to date', st_tot_lbl), Paragraph(money(so.amount_paid), st_tot_val)],
            [Paragraph('Balance due', st_tot_lbl),
             Paragraph(money(so.balance_due), ParagraphStyle('bal', parent=st_tot_val,
                                                            fontName='Helvetica-Bold',
                                                            textColor=HexColor('#DC2626') if float(so.balance_due) > 0 else HexColor('#16A34A')))],
            [Paragraph('TOTAL', st_tot_lbl_w), Paragraph(money(so.total_amount), st_tot_val_w)],
        ]
        totals_tbl = Table(totals, colWidths=[46 * mm, 42 * mm], hAlign='RIGHT')
        totals_tbl.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -2), BG),
            ('BOX', (0, 0), (-1, -2), 0.75, BORDER),
            ('BACKGROUND', (0, -1), (-1, -1), TEAL),
            ('LEFTPADDING', (0, 0), (-1, -1), 10),
            ('RIGHTPADDING', (0, 0), (-1, -1), 10),
            ('TOPPADDING', (0, 0), (-1, -1), 5),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ]))
        pay_pill = pill(so.get_payment_status_display(), pay_color, 28 * mm)
        method_line = Paragraph(f'Via {so.get_payment_method_display()}', st_label)
        pay_card = Table(
            [[Paragraph('PAYMENT STATUS', st_label)], [pay_pill], [method_line]],
            colWidths=[34 * mm],
            style=TableStyle([
                ('BACKGROUND', (0, 0), (-1, -1), BG),
                ('BOX', (0, 0), (-1, -1), 0.75, BORDER),
                ('LEFTPADDING', (0, 0), (-1, -1), 9),
                ('RIGHTPADDING', (0, 0), (-1, -1), 9),
                ('TOPPADDING', (0, 0), (-1, 0), 7),
                ('BOTTOMPADDING', (0, 0), (-1, 0), 1),
                ('TOPPADDING', (0, 1), (-1, 1), 3),
                ('BOTTOMPADDING', (0, 1), (-1, 1), 1),
                ('TOPPADDING', (0, 2), (-1, 2), 1),
                ('BOTTOMPADDING', (0, 2), (-1, 2), 7),
            ]),
        )
        bottom_row = Table([[pay_card, totals_tbl]], colWidths=[PAGE_W - 92 * mm, 92 * mm])
        bottom_row.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ]))
        story.append(bottom_row)

        if so.notes:
            story.append(Spacer(1, 6 * mm))
            story.append(section_heading('NOTES'))
            story.append(Spacer(1, 2.5 * mm))
            story.append(Paragraph(so.notes, st_body))

        # Footer
        def draw_footer(canvas, doc_):
            canvas.saveState()
            canvas.setFillColor(NAVY)
            canvas.rect(0, A4[1] - 4 * mm, A4[0], 4 * mm, stroke=0, fill=1)
            canvas.setFillColor(TEAL)
            canvas.rect(0, A4[1] - 5.2 * mm, A4[0], 1.2 * mm, stroke=0, fill=1)
            canvas.setStrokeColor(BORDER)
            canvas.setLineWidth(0.5)
            canvas.line(15 * mm, 13 * mm, A4[0] - 15 * mm, 13 * mm)
            canvas.setFont('Helvetica', 7.5)
            canvas.setFillColor(SLATE)
            canvas.drawCentredString(A4[0] / 2, 8.5 * mm, 'Powered by AdhereMed')
            canvas.setFont('Helvetica-Bold', 8)
            canvas.setFillColor(TEAL)
            canvas.drawCentredString(A4[0] / 2, 4.5 * mm, 'www.adheremed.co')
            canvas.linkURL(
                'https://www.adheremed.co',
                (A4[0] / 2 - 60, 3.5 * mm, A4[0] / 2 + 60, 7.5 * mm),
            )
            canvas.restoreState()

        doc.build(story, onFirstPage=draw_footer, onLaterPages=draw_footer)
        buf.seek(0)
        fname = f'sales_order_{so.so_number}.pdf'
        return HttpResponse(
            buf.read(),
            content_type='application/pdf',
            headers={'Content-Disposition': f'attachment; filename="{fname}"'},
        )

    # ── Premium PDF: sales orders report ─────────────────────────────────
    @action(detail=False, methods=['get'], url_path='report-pdf')
    def report_pdf(self, request):
        """Generate a branded premium PDF report of sales orders."""
        try:
            from reportlab.lib.pagesizes import A4, landscape
            from reportlab.lib.units import mm
            from reportlab.lib.colors import HexColor
            from reportlab.lib.styles import ParagraphStyle
            from reportlab.lib.enums import TA_RIGHT, TA_CENTER
            from reportlab.platypus import (
                SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image as RLImage,
            )
            from django.utils import timezone as _tz
        except ImportError:
            return Response({'detail': 'reportlab not installed.'}, status=500)

        qs = self.filter_queryset(self.get_queryset())
        sos = list(qs)
        logo_path, business_name = resolve_branding(request)

        NAVY = HexColor('#0F172A')
        TEAL = HexColor('#0D9488')
        SLATE = HexColor('#64748B')
        BORDER = HexColor('#E2E8F0')
        BG = HexColor('#F8FAFC')
        WHITE = HexColor('#FFFFFF')
        STATUS_COLORS = {
            'draft': HexColor('#64748B'), 'confirmed': HexColor('#2563EB'),
            'partial': HexColor('#D97706'), 'fulfilled': HexColor('#16A34A'),
            'cancelled': HexColor('#DC2626'),
        }

        def money(v):
            try:
                return f'KSh {float(v or 0):,.2f}'
            except (TypeError, ValueError):
                return 'KSh 0.00'

        def fmt_date(d):
            return d.strftime('%d %b %Y') if d else '—'

        total_value = total_paid = total_discount = 0.0
        status_agg = {}
        for so in sos:
            total_value += float(so.total_amount or 0)
            total_paid += float(so.amount_paid or 0)
            total_discount += float(so.discount_amount or 0)
            key = so.status
            if key not in status_agg:
                status_agg[key] = {'count': 0, 'value': 0.0, 'label': so.get_status_display()}
            status_agg[key]['count'] += 1
            status_agg[key]['value'] += float(so.total_amount or 0)
        open_count = sum(v['count'] for k, v in status_agg.items()
                         if k in ('draft', 'confirmed', 'partial'))
        fulfilled_count = status_agg.get('fulfilled', {}).get('count', 0)
        outstanding = max(0.0, total_value - total_paid)

        PAGE = landscape(A4)
        PAGE_W = PAGE[0] - 30 * mm
        buf = io.BytesIO()
        doc = SimpleDocTemplate(
            buf, pagesize=PAGE,
            leftMargin=15 * mm, rightMargin=15 * mm,
            topMargin=12 * mm, bottomMargin=18 * mm,
            title='Sales Orders Report',
        )

        st_brand = ParagraphStyle('brand', fontName='Helvetica-Bold', fontSize=13,
                                  textColor=NAVY, leading=16)
        st_brand_sub = ParagraphStyle('brandsub', fontName='Helvetica', fontSize=8,
                                      textColor=SLATE, leading=11)
        st_doctitle = ParagraphStyle('doctitle', fontName='Helvetica-Bold', fontSize=20,
                                     textColor=TEAL, leading=24, alignment=TA_RIGHT)
        st_docsub = ParagraphStyle('docsub', fontName='Helvetica', fontSize=8.5,
                                   textColor=SLATE, leading=12, alignment=TA_RIGHT)
        st_label = ParagraphStyle('label', fontName='Helvetica-Bold', fontSize=6.5,
                                  textColor=SLATE, leading=9)
        st_value = ParagraphStyle('value', fontName='Helvetica-Bold', fontSize=11,
                                  textColor=NAVY, leading=14)
        st_value_sub = ParagraphStyle('valuesub', fontName='Helvetica', fontSize=7,
                                      textColor=SLATE, leading=9)
        st_section = ParagraphStyle('section', fontName='Helvetica-Bold', fontSize=9,
                                    textColor=NAVY, leading=12)
        st_cell = ParagraphStyle('cell', fontName='Helvetica', fontSize=8, leading=11,
                                 textColor=NAVY)
        st_cell_r = ParagraphStyle('cellr', parent=st_cell, alignment=TA_RIGHT)
        st_cell_b = ParagraphStyle('cellb', parent=st_cell, fontName='Helvetica-Bold')
        st_cell_b_r = ParagraphStyle('cellbr', parent=st_cell_b, alignment=TA_RIGHT)
        st_hdr = ParagraphStyle('hdr', parent=st_cell_b, textColor=WHITE)
        st_hdr_r = ParagraphStyle('hdrr', parent=st_hdr, alignment=TA_RIGHT)
        st_pill = ParagraphStyle('pill', fontName='Helvetica-Bold', fontSize=7.5,
                                 textColor=WHITE, alignment=TA_CENTER)
        st_note = ParagraphStyle('note', fontName='Helvetica-Oblique', fontSize=7.5,
                                 textColor=SLATE, leading=10)

        def section_heading(text, width):
            bar = Table([['']], colWidths=[1.2 * mm], rowHeights=[3.6 * mm])
            bar.setStyle(TableStyle([('BACKGROUND', (0, 0), (-1, -1), TEAL)]))
            t = Table([[bar, Paragraph(text, st_section)]], colWidths=[3 * mm, width - 3 * mm])
            t.setStyle(TableStyle([
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('LEFTPADDING', (0, 0), (-1, -1), 0),
                ('RIGHTPADDING', (0, 0), (-1, -1), 0),
                ('TOPPADDING', (0, 0), (-1, -1), 0),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
            ]))
            return t

        def status_pill(so_status, width):
            p = Table([[Paragraph(so.get_status_display(), st_pill)]], colWidths=[width])
            p.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, -1), STATUS_COLORS.get(so_status, SLATE)),
                ('TOPPADDING', (0, 0), (-1, -1), 2),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 2),
            ]))
            return p

        story = []

        # Header
        logo = RLImage(logo_path, width=15 * mm, height=15 * mm, kind='proportional')
        tenant = getattr(request, 'tenant', None)
        header_subs = []
        if tenant:
            addr = ', '.join(x for x in [getattr(tenant, 'address', '') or '',
                                         getattr(tenant, 'city', '') or ''] if x)
            if addr:
                header_subs.append(addr)
            contact = ' · '.join(x for x in [getattr(tenant, 'phone', '') or '',
                                             getattr(tenant, 'email', '') or ''] if x)
            if contact:
                header_subs.append(contact)
        left_block = [Paragraph(business_name, st_brand)] + \
            [Paragraph(s, st_brand_sub) for s in header_subs]
        right_block = [
            Paragraph('SALES ORDERS REPORT', st_doctitle),
            Paragraph(f'Generated {_tz.now().strftime("%d %b %Y, %H:%M")}', st_docsub),
        ]
        date_range = ''
        if request.query_params.get('date_from') or request.query_params.get('date_to'):
            date_range = (f"Date range: {request.query_params.get('date_from') or '—'}"
                          f" to {request.query_params.get('date_to') or '—'}")
            right_block.append(Paragraph(date_range, st_docsub))
        header_tbl = Table([[logo, left_block, right_block]],
                           colWidths=[17 * mm, PAGE_W - 17 * mm - 80 * mm, 80 * mm])
        header_tbl.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (0, 0), 8),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ]))
        story.append(header_tbl)
        story.append(Spacer(1, 4 * mm))
        strip = Table([['']], colWidths=[PAGE_W], rowHeights=[1.6 * mm])
        strip.setStyle(TableStyle([('BACKGROUND', (0, 0), (-1, -1), TEAL)]))
        story.append(strip)
        story.append(Spacer(1, 5 * mm))

        # KPI cards
        def kpi_card(label, value, sub=''):
            rows = [[Paragraph(label, st_label)], [Paragraph(value, st_value)]]
            if sub:
                rows.append([Paragraph(sub, st_value_sub)])
            return rows

        kpis = [
            kpi_card('TOTAL ORDERS', str(len(sos)), f'{open_count} open'),
            kpi_card('FULFILLED', str(fulfilled_count), 'completed orders'),
            kpi_card('TOTAL VALUE', money(total_value), 'order value'),
            kpi_card('COLLECTED', money(total_paid), 'payments received'),
            kpi_card('OUTSTANDING', money(outstanding), 'balance due'),
        ]
        gap = 4 * mm
        kpi_w = (PAGE_W - 4 * gap) / 5
        kpi_tbl = Table(
            [[kpis[0], '', kpis[1], '', kpis[2], '', kpis[3], '', kpis[4]]],
            colWidths=[kpi_w, gap, kpi_w, gap, kpi_w, gap, kpi_w, gap, kpi_w],
        )
        kpi_tbl.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('BACKGROUND', (0, 0), (0, 0), BG), ('BOX', (0, 0), (0, 0), 0.75, BORDER),
            ('BACKGROUND', (2, 0), (2, 0), BG), ('BOX', (2, 0), (2, 0), 0.75, BORDER),
            ('BACKGROUND', (4, 0), (4, 0), BG), ('BOX', (4, 0), (4, 0), 0.75, BORDER),
            ('BACKGROUND', (6, 0), (6, 0), BG), ('BOX', (6, 0), (6, 0), 0.75, BORDER),
            ('BACKGROUND', (8, 0), (8, 0), BG), ('BOX', (8, 0), (8, 0), 0.75, BORDER),
            ('LEFTPADDING', (0, 0), (-1, -1), 9),
            ('RIGHTPADDING', (0, 0), (-1, -1), 9),
            ('TOPPADDING', (0, 0), (-1, -1), 7),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 7),
        ]))
        story.append(kpi_tbl)
        story.append(Spacer(1, 6 * mm))

        # Status breakdown panel
        half = (PAGE_W - 10 * mm) / 2
        status_rows = [[
            Paragraph('STATUS', st_hdr), Paragraph('ORDERS', st_hdr_r),
            Paragraph('VALUE (KSH)', st_hdr_r),
        ]]
        for key in ('draft', 'confirmed', 'partial', 'fulfilled', 'cancelled'):
            agg = status_agg.get(key)
            if not agg:
                continue
            p = Table([[Paragraph(agg['label'], st_pill)]], colWidths=[30 * mm])
            p.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, -1), STATUS_COLORS.get(key, SLATE)),
                ('TOPPADDING', (0, 0), (-1, -1), 2),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 2),
            ]))
            status_rows.append([
                p,
                Paragraph(str(agg['count']), st_cell_r),
                Paragraph(f"{agg['value']:,.2f}", st_cell_r),
            ])
        status_tbl = Table(status_rows, colWidths=[half - 44 * mm, 22 * mm, 22 * mm])
        status_tbl.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), NAVY),
            ('LINEBELOW', (0, 1), (-1, -1), 0.4, BORDER),
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [None, BG]),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, -1), 6),
            ('RIGHTPADDING', (0, 0), (-1, -1), 6),
            ('TOPPADDING', (0, 0), (-1, -1), 4),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ]))

        discount_note = (
            f'Total order-level discounts applied: KSh {total_discount:,.2f}. '
            f'Payments collected to date: KSh {total_paid:,.2f}. '
            f'Outstanding balance across all orders: KSh {outstanding:,.2f}.'
        )
        info_card = Table([[Paragraph('PAYMENTS SUMMARY', st_section)],
                           [Paragraph(discount_note, st_note)]], colWidths=[half])
        info_card.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), BG),
            ('BOX', (0, 0), (-1, -1), 0.75, BORDER),
            ('LEFTPADDING', (0, 0), (-1, -1), 9),
            ('RIGHTPADDING', (0, 0), (-1, -1), 9),
            ('TOPPADDING', (0, 0), (-1, -1), 7),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 7),
        ]))

        panels = Table([[
            [section_heading('STATUS BREAKDOWN', half), Spacer(1, 3 * mm), status_tbl],
            '',
            [section_heading('PAYMENTS SUMMARY', half), Spacer(1, 3 * mm), info_card],
        ]], colWidths=[half, 10 * mm, half])
        panels.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ]))
        story.append(panels)
        story.append(Spacer(1, 6 * mm))

        # Ledger
        story.append(section_heading(f'SALES ORDERS ({len(sos)})', PAGE_W))
        story.append(Spacer(1, 3.5 * mm))
        ledger_rows = [[
            Paragraph('#', st_hdr), Paragraph('SO NUMBER', st_hdr),
            Paragraph('CUSTOMER', st_hdr), Paragraph('STATUS', st_hdr),
            Paragraph('PAYMENT', st_hdr), Paragraph('DELIVERY', st_hdr_r),
            Paragraph('ITEMS', st_hdr_r), Paragraph('PAID (KSH)', st_hdr_r),
            Paragraph('BALANCE (KSH)', st_hdr_r), Paragraph('TOTAL (KSH)', st_hdr_r),
        ]]
        PAY_COLORS = {
            'unpaid': HexColor('#DC2626'), 'partial': HexColor('#D97706'),
            'paid': HexColor('#16A34A'),
        }
        for i, so in enumerate(sos, 1):
            pay_pill = Table([[Paragraph(so.get_payment_status_display(), st_pill)]],
                             colWidths=[24 * mm])
            pay_pill.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, -1), PAY_COLORS.get(so.payment_status, SLATE)),
                ('TOPPADDING', (0, 0), (-1, -1), 2),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 2),
            ]))
            ledger_rows.append([
                Paragraph(str(i), st_cell),
                Paragraph(so.so_number, st_cell_b),
                Paragraph(so.customer_name or '—', st_cell),
                status_pill(so.status, 26 * mm),
                pay_pill,
                Paragraph(fmt_date(so.expected_delivery), st_cell_r),
                Paragraph(str(len(so.items or [])), st_cell_r),
                Paragraph(f'{float(so.amount_paid or 0):,.2f}', st_cell_r),
                Paragraph(f'{float(so.balance_due):,.2f}', st_cell_r),
                Paragraph(f'{float(so.total_amount or 0):,.2f}', st_cell_b_r),
            ])
        if not sos:
            ledger_rows.append([Paragraph('No sales orders found for the selected filters.', st_note), '', '', '', '', '', '', '', '', ''])
        ledger_w = [8 * mm, 30 * mm, 46 * mm, 28 * mm, 24 * mm, 26 * mm, 14 * mm, 28 * mm, 28 * mm, 30 * mm]
        ledger_tbl = Table(ledger_rows, colWidths=ledger_w, repeatRows=1)
        ledger_tbl.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), NAVY),
            ('LINEBELOW', (0, 0), (-1, 0), 1, TEAL),
            ('LINEBELOW', (0, 1), (-1, -1), 0.4, BORDER),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [None, BG]),
            ('LEFTPADDING', (0, 0), (-1, -1), 6),
            ('RIGHTPADDING', (0, 0), (-1, -1), 6),
            ('TOPPADDING', (0, 0), (-1, -1), 4.5),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 4.5),
        ]))
        story.append(ledger_tbl)

        # Footer
        def draw_footer(canvas, doc_):
            canvas.saveState()
            canvas.setFillColor(NAVY)
            canvas.rect(0, PAGE[1] - 4 * mm, PAGE[0], 4 * mm, stroke=0, fill=1)
            canvas.setFillColor(TEAL)
            canvas.rect(0, PAGE[1] - 5.2 * mm, PAGE[0], 1.2 * mm, stroke=0, fill=1)
            canvas.setStrokeColor(BORDER)
            canvas.setLineWidth(0.5)
            canvas.line(15 * mm, 13 * mm, PAGE[0] - 15 * mm, 13 * mm)
            canvas.setFont('Helvetica', 7.5)
            canvas.setFillColor(SLATE)
            canvas.drawCentredString(PAGE[0] / 2, 8.5 * mm, 'Powered by AdhereMed')
            canvas.setFont('Helvetica-Bold', 8)
            canvas.setFillColor(TEAL)
            canvas.drawCentredString(PAGE[0] / 2, 4.5 * mm, 'www.adheremed.co')
            canvas.linkURL(
                'https://www.adheremed.co',
                (PAGE[0] / 2 - 60, 3.5 * mm, PAGE[0] / 2 + 60, 7.5 * mm),
            )
            canvas.restoreState()

        doc.build(story, onFirstPage=draw_footer, onLaterPages=draw_footer)
        buf.seek(0)
        stamp = _tz.now().strftime('%Y%m%d')
        fname = f'sales_orders_report_{stamp}.pdf'
        return HttpResponse(
            buf.read(),
            content_type='application/pdf',
            headers={'Content-Disposition': f'attachment; filename="{fname}"'},
        )
