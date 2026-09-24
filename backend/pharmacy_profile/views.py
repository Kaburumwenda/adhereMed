import csv
import io

from django.http import HttpResponse
from rest_framework import viewsets, filters, status, permissions
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend

from accounts.views import IsTenantAdminOrSuperAdmin
from .models import PharmacyDetail, Delivery, Branch
from .serializers import PharmacyDetailSerializer, DeliverySerializer, BranchSerializer


class BranchViewSet(viewsets.ModelViewSet):
    serializer_class = BranchSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['is_active', 'is_main']
    search_fields = ['name', 'address']
    ordering_fields = ['name', 'created_at']

    # RBAC: warehouses/branches are org-level structure — every member may
    # view them, but only tenant admins may create / edit / delete.
    def get_permissions(self):
        if self.request.method in permissions.SAFE_METHODS:
            return [IsAuthenticated()]
        return [IsTenantAdminOrSuperAdmin()]

    def get_queryset(self):
        # transfer / stock counts are annotated so the serializer avoids N+1 queries
        from django.db.models import Count
        return Branch.objects.annotate(
            transfer_out_count=Count('transfers_out', distinct=True),
            transfer_in_count=Count('transfers_in', distinct=True),
            stock_count=Count('stocks', distinct=True),
        )

    def destroy(self, request, *args, **kwargs):
        """Block deletion when the branch is still referenced by protected
        records (stock items, stock transfers) and return a friendly 400
        instead of crashing with ProtectedError. Deactivating is the
        recommended path."""
        branch = self.get_object()

        # Stock items belong to a warehouse (PROTECT) — the stock must be
        # moved elsewhere before the warehouse can be deleted.
        from inventory.models import MedicationStock, StockTransfer
        stock_count = MedicationStock.objects.filter(branch=branch).count()
        if stock_count:
            return Response(
                {
                    'detail': (
                        f'Cannot delete "{branch.name}" because it still holds '
                        f'{stock_count} stock item(s). Move them to another '
                        f'warehouse first, or deactivate this warehouse.'
                    ),
                    'referenced_stocks': stock_count,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Transfers protect their source/destination branches (history must
        # survive), so check them up-front for a precise message.
        from django.db.models import Q
        transfer_count = StockTransfer.objects.filter(
            Q(source_branch=branch) | Q(dest_branch=branch),
        ).count()
        if transfer_count:
            return Response(
                {
                    'detail': (
                        f'Cannot delete "{branch.name}" because it is referenced by '
                        f'{transfer_count} stock transfer(s). Transfer history must be '
                        f'preserved — deactivate the warehouse instead.'
                    ),
                    'referenced_transfers': transfer_count,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Any other protected references (safety net).
        from django.db.models import ProtectedError
        try:
            return super().destroy(request, *args, **kwargs)
        except ProtectedError as exc:
            return Response(
                {
                    'detail': (
                        f'Cannot delete "{branch.name}" because it is still referenced '
                        f'by other records ({exc}). Deactivate it instead to keep history intact.'
                    ),
                },
                status=status.HTTP_400_BAD_REQUEST,
            )


class PharmacyDetailViewSet(viewsets.ModelViewSet):
    queryset = PharmacyDetail.objects.all()
    serializer_class = PharmacyDetailSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name']
    ordering_fields = ['name', 'created_at']

    @action(detail=True, methods=['post'], parser_classes=[MultiPartParser, FormParser], url_path='upload-logo')
    def upload_logo(self, request, pk=None):
        instance = self.get_object()
        logo = request.FILES.get('logo')
        if not logo:
            return Response({'error': 'No logo file provided.'}, status=status.HTTP_400_BAD_REQUEST)
        # Basic validation: image only
        if not logo.content_type.startswith('image/'):
            return Response({'error': 'File must be an image.'}, status=status.HTTP_400_BAD_REQUEST)
        # Remove old logo if exists
        if instance.logo:
            instance.logo.delete(save=False)
        instance.logo = logo
        instance.save(update_fields=['logo'])
        serializer = self.get_serializer(instance, context={'request': request})
        return Response(serializer.data)


class DeliveryViewSet(viewsets.ModelViewSet):
    queryset = Delivery.objects.select_related('transaction', 'sales_order', 'assigned_to').all()
    serializer_class = DeliverySerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'assigned_to']
    search_fields = ['recipient_name', 'recipient_phone', 'delivery_address']
    ordering_fields = ['created_at', 'scheduled_at', 'status']
    ordering = ['-created_at']

    @staticmethod
    def _driver_display(d):
        """Mirror the serializer's driver_display (not a model property)."""
        if d.assigned_to_id and getattr(d.assigned_to, 'full_name', None):
            return d.assigned_to.full_name
        return d.assigned_driver_name or None

    @action(detail=True, methods=['post'])
    def update_status(self, request, pk=None):
        delivery = self.get_object()
        new_status = request.data.get('status')
        valid_statuses = [c[0] for c in Delivery.Status.choices]
        if new_status not in valid_statuses:
            return Response(
                {'error': f'Invalid status. Must be one of: {valid_statuses}'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        delivery.status = new_status
        if new_status == 'delivered':
            from django.utils import timezone
            delivery.delivered_at = timezone.now()
        delivery.save()

        # Keep a linked sales order in step with the delivery:
        # marking the delivery delivered fulfils the order (deducts stock).
        if (new_status == 'delivered' and delivery.sales_order_id
                and delivery.sales_order.status != 'fulfilled'):
            from sales_orders.models import SalesOrder
            from sales_orders.serializers import (
                _fulfill_delivered_items, _sync_stock_commitment,
            )
            so = delivery.sales_order
            so.status = SalesOrder.Status.FULFILLED
            so.save(update_fields=['status', 'updated_at'])
            _fulfill_delivered_items(so, user=request.user)  # FEFO deduct + ledger record
            _sync_stock_commitment(so)

        return Response(DeliverySerializer(delivery).data)

    # ── Delivery note (PDF) ───────────────────────────────────────────
    @action(detail=True, methods=['get'], url_path='note-pdf')
    def note_pdf(self, request, pk=None):
        """Generate a branded premium delivery note PDF for a delivery."""
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

        d = self.get_object()

        # ── Resolve order + items ────────────────────────────────────────
        if d.sales_order_id:
            so = d.sales_order
            order_no = so.so_number
            order_total = float(so.total_amount or 0)
            items = [(it.get('name') or '', int(it.get('qty') or 0),
                      float(it.get('unit_price') or 0), float(it.get('total') or 0))
                     for it in (so.items or [])]
        elif d.transaction_id:
            txn = d.transaction
            order_no = txn.transaction_number
            order_total = float(txn.total or 0)
            items = [(i.medication_name or '', int(i.quantity or 0),
                      float(i.unit_price or 0), float(i.total_price or 0))
                     for i in txn.items.all()]
        else:
            order_no, order_total, items = '—', 0.0, []

        from config.pdf_branding import resolve_branding
        logo_path, business_name = resolve_branding(request)
        tenant = getattr(request, 'tenant', None)

        NAVY = HexColor('#0F172A')
        TEAL = HexColor('#0D9488')
        SLATE = HexColor('#64748B')
        BORDER = HexColor('#E2E8F0')
        BG = HexColor('#F8FAFC')
        WHITE = HexColor('#FFFFFF')
        STATUS_COLORS = {
            'to_be_packed': HexColor('#0D9488'), 'to_be_shipped': HexColor('#0EA5E9'),
            'pending': HexColor('#D97706'), 'assigned': HexColor('#2563EB'),
            'in_transit': HexColor('#0EA5E9'), 'delivered': HexColor('#16A34A'),
            'failed': HexColor('#DC2626'), 'cancelled': HexColor('#64748B'),
        }

        def money(v):
            try:
                return f'KSh {float(v or 0):,.2f}'
            except (TypeError, ValueError):
                return 'KSh 0.00'

        def fmt_date(d_):
            return d_.strftime('%d %b %Y') if d_ else '—'

        PAGE_W = A4[0] - 30 * mm
        buf = io.BytesIO()
        doc = SimpleDocTemplate(
            buf, pagesize=A4,
            leftMargin=15 * mm, rightMargin=15 * mm,
            topMargin=12 * mm, bottomMargin=18 * mm,
            title=f'Delivery Note {order_no}',
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
        st_section = ParagraphStyle('section', fontName='Helvetica-Bold', fontSize=9,
                                    textColor=NAVY, leading=12)
        st_sig = ParagraphStyle('sig', fontName='Helvetica', fontSize=8.5,
                                textColor=SLATE, leading=12)

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

        def pill(text, color, width):
            t = Table([[Paragraph(text, st_pill)]], colWidths=[width])
            t.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, -1), color),
                ('TOPPADDING', (0, 0), (-1, -1), 3),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
            ]))
            return t

        story = []

        # ── Header ─────────────────────────────────────────────────────
        logo = RLImage(logo_path, width=15 * mm, height=15 * mm, kind='proportional')
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
            Paragraph('DELIVERY NOTE', st_doctitle),
            Paragraph(f'Order {order_no} · {fmt_date(d.created_at.date() if d.created_at else None)}',
                      st_docsub),
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

        # ── Meta cards ──────────────────────────────────────────────────
        gap = 3.75 * mm
        card_w = (PAGE_W - 3 * gap) / 4
        status_card = Table(
            [[Paragraph('STATUS', st_label)],
             [pill(d.get_status_display(), STATUS_COLORS.get(d.status, SLATE), 26 * mm)]],
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
            meta_card('ORDER', Paragraph(order_no, st_value), card_w),
            '',
            meta_card('DELIVERY FEE', Paragraph(money(d.delivery_fee), st_value), card_w),
            '',
            meta_card('SCHEDULED', Paragraph(fmt_date(d.scheduled_at), st_value), card_w),
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

        # ── Deliver to / driver ────────────────────────────────────────
        to_block = [
            section_heading('DELIVER TO'),
            Spacer(1, 3 * mm),
            Paragraph(d.recipient_name or '—',
                       ParagraphStyle('rname', parent=st_cell_b, fontSize=10.5, leading=13)),
        ]
        if d.recipient_phone:
            to_block.append(Paragraph(f'Phone:  {d.recipient_phone}', st_body))
        if d.delivery_address:
            to_block.append(Paragraph(d.delivery_address.replace('\n', ', '), st_body))
        if d.latitude and d.longitude:
            to_block.append(Paragraph(
                f'GPS: {float(d.latitude):.6f}, {float(d.longitude):.6f}', st_body))
        driver_block = [
            section_heading('DRIVER'),
            Spacer(1, 3 * mm),
            Paragraph(self._driver_display(d) or 'Unassigned',
                      ParagraphStyle('dname', parent=st_cell_b, fontSize=10.5, leading=13)),
        ]
        if d.scheduled_at:
            driver_block.append(Paragraph(f'Scheduled: {fmt_date(d.scheduled_at)}', st_body))
        if d.delivered_at:
            driver_block.append(Paragraph(f'Delivered: {fmt_date(d.delivered_at)}', st_body))
        half = (PAGE_W - 8 * mm) / 2
        party_tbl = Table([[to_block, driver_block]], colWidths=[half, half])
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

        # ── Items table ────────────────────────────────────────────────
        story.append(section_heading('ITEMS BEING DELIVERED'))
        story.append(Spacer(1, 3.5 * mm))
        item_rows = [[
            Paragraph('#', st_hdr), Paragraph('ITEM', st_hdr),
            Paragraph('QTY', st_hdr_r), Paragraph('UNIT PRICE', st_hdr_r),
            Paragraph('TOTAL', st_hdr_r),
        ]]
        for i, (name, qty, price, total) in enumerate(items, 1):
            item_rows.append([
                Paragraph(str(i), st_cell),
                Paragraph(name, st_cell),
                Paragraph(str(qty), st_cell_r),
                Paragraph(money(price), st_cell_r),
                Paragraph(money(total), st_cell_b_r),
            ])
        if not items:
            item_rows.append([Paragraph('No items recorded', st_cell), '', '', '', ''])
        items_tbl = Table(item_rows, colWidths=[
            8 * mm, PAGE_W - (8 + 14 + 26 + 28) * mm, 14 * mm, 26 * mm, 28 * mm,
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

        # ── Totals ──────────────────────────────────────────────────────
        grand_total = order_total + float(d.delivery_fee or 0)
        totals = [
            [Paragraph('Order value', st_body),
             Paragraph(money(order_total), ParagraphStyle('tv', parent=st_cell_r))],
            [Paragraph('Delivery fee', st_body), Paragraph(money(d.delivery_fee), st_cell_r)],
            [Paragraph('TOTAL', ParagraphStyle('tl', parent=st_cell_b, textColor=WHITE)),
             Paragraph(money(grand_total),
                       ParagraphStyle('tvw', parent=st_cell_b_r, fontSize=12, textColor=WHITE))],
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
        story.append(totals_tbl)

        if d.notes:
            story.append(Spacer(1, 6 * mm))
            story.append(section_heading('NOTES'))
            story.append(Spacer(1, 2.5 * mm))
            story.append(Paragraph(d.notes, st_body))

        # ── Proof of delivery / signature block ──────────────────────────
        story.append(Spacer(1, 10 * mm))
        pod_label = Paragraph(
            'PROOF OF DELIVERY — I confirm that I have received the items listed above in good condition.',
            ParagraphStyle('pod', fontName='Helvetica-Oblique', fontSize=8, textColor=SLATE,
                           leading=11))
        sig_cols = [55 * mm, 10 * mm, 55 * mm, 10 * mm, PAGE_W - 130 * mm]
        sig_line = Table(
            [['', '', '', '', '']],
            colWidths=sig_cols,
            rowHeights=[11 * mm],
        )
        sig_line.setStyle(TableStyle([
            ('LINEBELOW', (0, 0), (0, 0), 0.75, SLATE),
            ('LINEBELOW', (2, 0), (2, 0), 0.75, SLATE),
            ('LINEBELOW', (4, 0), (4, 0), 0.75, SLATE),
        ]))
        sig_labels = Table(
            [[Paragraph('Received by (name)', st_sig), '',
              Paragraph('Signature', st_sig), '',
              Paragraph('Date', st_sig)]],
            colWidths=sig_cols,
        )
        story.append(pod_label)
        story.append(Spacer(1, 13 * mm))
        story.append(sig_line)
        story.append(sig_labels)

        # ── Footer ──────────────────────────────────────────────────────
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
        fname = f'delivery_note_{order_no or d.pk}.pdf'
        return HttpResponse(
            buf.read(),
            content_type='application/pdf',
            headers={'Content-Disposition': f'attachment; filename="{fname}"'},
        )

    # ── Excel / CSV export ─────────────────────────────────────────────
    _EXPORT_HEADERS = ['Order', 'Source', 'Recipient', 'Phone', 'Address',
                       'Driver', 'Fee (KSh)', 'Status', 'Scheduled',
                       'Delivered At', 'Created', 'Notes']

    def _delivery_row(self, d):
        if d.sales_order_id:
            order, source = d.sales_order.so_number, 'Sales Order'
        else:
            order, source = d.transaction.transaction_number, 'POS'
        return [
            order, source,
            d.recipient_name, d.recipient_phone,
            d.delivery_address,
            self._driver_display(d) or '',
            float(d.delivery_fee or 0),
            d.get_status_display(),
            d.scheduled_at.strftime('%Y-%m-%d %H:%M') if d.scheduled_at else '',
            d.delivered_at.strftime('%Y-%m-%d %H:%M') if d.delivered_at else '',
            d.created_at.strftime('%Y-%m-%d %H:%M'),
            d.notes or '',
        ]

    @action(detail=False, methods=['get'], url_path='export')
    def export(self, request):
        """Export deliveries as .xlsx or .csv (?fmt=excel|csv), respects filters."""
        import csv
        import io
        from django.utils import timezone as _tz

        qs = self.filter_queryset(self.get_queryset())
        fmt = (request.query_params.get('fmt') or 'excel').lower()
        stamp = _tz.now().strftime('%Y%m%d')

        if fmt == 'csv':
            response = HttpResponse(content_type='text/csv')
            response['Content-Disposition'] = f'attachment; filename="deliveries_{stamp}.csv"'
            writer = csv.writer(response)
            writer.writerow(self._EXPORT_HEADERS)
            for d in qs:
                writer.writerow(self._delivery_row(d))
            return response

        try:
            from openpyxl import Workbook
            from openpyxl.styles import Font, PatternFill
            from openpyxl.utils import get_column_letter
        except ImportError:
            return Response({'detail': 'openpyxl not installed.'}, status=500)

        wb = Workbook()
        ws = wb.active
        ws.title = 'Deliveries'
        ws.append(self._EXPORT_HEADERS)
        for c in ws[1]:
            c.font = Font(bold=True, color='FFFFFF')
            c.fill = PatternFill('solid', fgColor='0D9488')
        for d in qs:
            ws.append(self._delivery_row(d))
        for i, w in enumerate([18, 14, 24, 16, 40, 24, 12, 16, 18, 18, 18, 32], 1):
            ws.column_dimensions[get_column_letter(i)].width = w
        buf = io.BytesIO()
        wb.save(buf)
        buf.seek(0)
        return HttpResponse(
            buf.read(),
            content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            headers={'Content-Disposition': f'attachment; filename="deliveries_{stamp}.xlsx"'},
        )

    # ── Premium PDF report ──────────────────────────────────────────────
    @action(detail=False, methods=['get'], url_path='report-pdf')
    def report_pdf(self, request):
        """Generate a branded premium PDF report of deliveries."""
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

        deliveries = list(self.filter_queryset(self.get_queryset()))

        from config.pdf_branding import resolve_branding
        logo_path, business_name = resolve_branding(request)

        NAVY = HexColor('#0F172A')
        TEAL = HexColor('#0D9488')
        SLATE = HexColor('#64748B')
        BORDER = HexColor('#E2E8F0')
        BG = HexColor('#F8FAFC')
        WHITE = HexColor('#FFFFFF')
        STATUS_COLORS = {
            'to_be_packed': HexColor('#0D9488'), 'pending': HexColor('#D97706'),
            'assigned': HexColor('#2563EB'), 'in_transit': HexColor('#0EA5E9'),
            'delivered': HexColor('#16A34A'), 'failed': HexColor('#DC2626'),
            'cancelled': HexColor('#64748B'),
        }

        def money(v):
            try:
                return f'KSh {float(v or 0):,.2f}'
            except (TypeError, ValueError):
                return 'KSh 0.00'

        # ── Aggregates ──────────────────────────────────────────────────
        status_agg = {}
        driver_agg = {}
        fees_collected = 0.0
        active_count = 0
        for d in deliveries:
            if d.status not in status_agg:
                status_agg[d.status] = {'count': 0, 'label': d.get_status_display()}
            status_agg[d.status]['count'] += 1
            if d.status in ('to_be_packed', 'pending', 'assigned', 'in_transit'):
                active_count += 1
            if d.status == 'delivered':
                fees_collected += float(d.delivery_fee or 0)
            driver = self._driver_display(d) or 'Unassigned'
            driver_agg[driver] = driver_agg.get(driver, 0) + 1
        top_drivers = sorted(driver_agg.items(), key=lambda x: -x[1])[:5]
        delivered_count = status_agg.get('delivered', {}).get('count', 0)

        PAGE = landscape(A4)
        PAGE_W = PAGE[0] - 30 * mm
        buf = io.BytesIO()
        doc = SimpleDocTemplate(
            buf, pagesize=PAGE,
            leftMargin=15 * mm, rightMargin=15 * mm,
            topMargin=12 * mm, bottomMargin=18 * mm,
            title='Deliveries Report',
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

        def status_pill(d):
            p = Table([[Paragraph(d.get_status_display(), st_pill)]], colWidths=[26 * mm])
            p.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, -1), STATUS_COLORS.get(d.status, SLATE)),
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
            Paragraph('DELIVERIES REPORT', st_doctitle),
            Paragraph(f'Generated {_tz.now().strftime("%d %b %Y, %H:%M")}', st_docsub),
        ]
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
            kpi_card('TOTAL DELIVERIES', str(len(deliveries)), f'{active_count} active'),
            kpi_card('TO BE PACKED', str(status_agg.get('to_be_packed', {}).get('count', 0)), 'awaiting packing'),
            kpi_card('IN TRANSIT', str(status_agg.get('in_transit', {}).get('count', 0)), 'on the road'),
            kpi_card('DELIVERED', str(delivered_count), 'completed'),
            kpi_card('FEES COLLECTED', money(fees_collected), 'from delivered orders'),
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

        # Status breakdown + top drivers
        half = (PAGE_W - 10 * mm) / 2
        status_rows = [[
            Paragraph('STATUS', st_hdr), Paragraph('DELIVERIES', st_hdr_r),
        ]]
        for key in ('to_be_packed', 'pending', 'assigned', 'in_transit',
                    'delivered', 'failed', 'cancelled'):
            agg = status_agg.get(key)
            if not agg:
                continue
            p = Table([[Paragraph(agg['label'], st_pill)]], colWidths=[30 * mm])
            p.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, -1), STATUS_COLORS.get(key, SLATE)),
                ('TOPPADDING', (0, 0), (-1, -1), 2),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 2),
            ]))
            status_rows.append([p, Paragraph(str(agg['count']), st_cell_r)])
        status_tbl = Table(status_rows, colWidths=[half - 22 * mm, 22 * mm])
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

        driver_rows = [[
            Paragraph('DRIVER', st_hdr), Paragraph('DELIVERIES', st_hdr_r),
        ]]
        for name, count in top_drivers:
            driver_rows.append([Paragraph(name, st_cell), Paragraph(str(count), st_cell_r)])
        if not top_drivers:
            driver_rows.append([Paragraph('No data', st_note), ''])
        driver_tbl = Table(driver_rows, colWidths=[half - 22 * mm, 22 * mm])
        driver_tbl.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), NAVY),
            ('LINEBELOW', (0, 1), (-1, -1), 0.4, BORDER),
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [None, BG]),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, -1), 6),
            ('RIGHTPADDING', (0, 0), (-1, -1), 6),
            ('TOPPADDING', (0, 0), (-1, -1), 4),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ]))

        panels = Table([[
            [section_heading('STATUS BREAKDOWN', half), Spacer(1, 3 * mm), status_tbl],
            '',
            [section_heading('TOP DRIVERS', half), Spacer(1, 3 * mm), driver_tbl],
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
        story.append(section_heading(f'DELIVERIES ({len(deliveries)})', PAGE_W))
        story.append(Spacer(1, 3.5 * mm))
        ledger_rows = [[
            Paragraph('#', st_hdr), Paragraph('ORDER', st_hdr),
            Paragraph('RECIPIENT', st_hdr), Paragraph('PHONE', st_hdr),
            Paragraph('ADDRESS', st_hdr), Paragraph('DRIVER', st_hdr),
            Paragraph('FEE (KSH)', st_hdr_r), Paragraph('STATUS', st_hdr),
            Paragraph('CREATED', st_hdr_r),
        ]]
        for i, d in enumerate(deliveries, 1):
            order = (d.sales_order.so_number if d.sales_order_id
                     else (d.transaction.transaction_number if d.transaction else '—'))
            ledger_rows.append([
                Paragraph(str(i), st_cell),
                Paragraph(order, st_cell_b),
                Paragraph(d.recipient_name or '—', st_cell),
                Paragraph(d.recipient_phone or '—', st_cell),
                Paragraph((d.delivery_address or '—')[:80], st_cell),
                Paragraph(self._driver_display(d) or 'Unassigned', st_cell),
                Paragraph(f'{float(d.delivery_fee or 0):,.2f}', st_cell_r),
                status_pill(d),
                Paragraph(d.created_at.strftime('%d %b %Y'), st_cell_r),
            ])
        if not deliveries:
            ledger_rows.append([Paragraph('No deliveries found.', st_note), '', '', '', '', '', '', '', ''])
        ledger_w = [8 * mm, 30 * mm, 40 * mm, 26 * mm, 62 * mm, 34 * mm, 24 * mm, 28 * mm, 24 * mm]
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
        fname = f'deliveries_report_{_tz.now().strftime("%Y%m%d")}.pdf'
        return HttpResponse(
            buf.read(),
            content_type='application/pdf',
            headers={'Content-Disposition': f'attachment; filename="{fname}"'},
        )


# ── Pharmacy Setup / Seed ────────────────────────────────────────────────────────

PHARMACY_SEED_COMMANDS = {
    "categories_units": {
        "label": "Categories & Units",
        "description": "34 stock categories and 24 measurement units (subset of full stock seed)",
        "command": "seed_pharmacy_stock",
        "args": {"skip_existing": True},
    },
    "medications": {
        "label": "Medication Catalog",
        "description": "~120 common medications (analgesics, antibiotics, etc.)",
        "command": "seed_medications",
        "args": {"skip_existing": True},
    },
    "interactions": {
        "label": "Drug Interactions",
        "description": "~30 common drug-drug interaction pairs with severity & advice",
        "command": "seed_interactions",
        "args": {"skip_existing": True},
    },
}

ALLOWED_SEED_ROLES = {"tenant_admin", "branch_admin", "pharmacist", "inventory_admin", "admin"}


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def pharmacy_seed_catalog(request):
    """Return available pharmacy seed commands for tenant/branch admins."""
    if request.user.role not in ALLOWED_SEED_ROLES:
        return Response(
            {"detail": "You do not have permission to seed data."},
            status=status.HTTP_403_FORBIDDEN,
        )
    items = []
    for key, info in PHARMACY_SEED_COMMANDS.items():
        items.append({
            "key": key,
            "label": info["label"],
            "description": info["description"],
        })
    return Response(items)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def pharmacy_run_seed(request):
    """
    Run a pharmacy seed command for the current tenant.
    Body: { "command": "pharmacy_stock" }
    """
    from django.core.management import call_command

    if request.user.role not in ALLOWED_SEED_ROLES:
        return Response(
            {"detail": "You do not have permission to seed data."},
            status=status.HTTP_403_FORBIDDEN,
        )

    cmd_key = request.data.get("command", "")
    if cmd_key not in PHARMACY_SEED_COMMANDS:
        return Response(
            {"detail": f"Unknown seed command: {cmd_key}"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    info = PHARMACY_SEED_COMMANDS[cmd_key]
    try:
        kwargs = info.get("args", {})
        call_command(info["command"], **kwargs)
        return Response({
            "detail": f"'{info['label']}' seeded successfully.",
            "command": cmd_key,
        })
    except Exception as e:
        return Response(
            {"detail": f"Seed failed: {str(e)}"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

