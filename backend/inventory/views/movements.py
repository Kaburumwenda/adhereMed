"""Unified stock movement report (ledger, KPIs, PDF)."""
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
    permission_classes = [InventoryPermission]

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
                # Value every movement on the same basis: cost. POS used to
                # report the selling price here while adjustments, transfers
                # and receipts reported cost, so ``value_in`` and ``value_out``
                # were sums of incompatible numbers.
                unit_val = float(
                    getattr(ti.batch, 'cost_price_per_unit', None)
                    or (ti.stock.cost_price if ti.stock else 0)
                    or ti.unit_price or 0)
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
            from ..models import MedicationStock as _MS
            disp_qs = DispensingRecord.objects.filter(
                dispensed_at__gte=start_dt,
                dispensed_at__lt=end_dt,
                status='completed',
            )
            # Cost lookup for the dispensed lines (they carry no unit cost).
            disp_stock_ids = {
                it.get('stock_id') for rec in disp_qs
                for it in (rec.items_dispensed or []) if it.get('stock_id')
            }
            rec_stock_cost = dict(
                _MS.objects.filter(id__in=disp_stock_ids)
                .values_list('id', 'cost_price'))
            if branch_id:
                # A scoped user must not see another warehouse's dispensing.
                disp_qs = disp_qs.filter(dispensed_by__staff_profile__branch_id=branch_id)
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
                    # Cost basis (see the POS block): dispensing lines store a
                    # selling price, not what the stock actually cost.
                    unit_val = float(rec_stock_cost.get(it.get('stock_id')) or 0)
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
                    unit_val = float(rec_stock_cost.get(it.get('stock_id')) or 0)
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
        # POS and dispensing write their own ledger rows now, but they are
        # enumerated above with richer context (receipt number, patient, batch),
        # so their rows are skipped here to keep the KPIs single-counted.
        adj_qs = StockAdjustment.objects.select_related(
            'stock', 'batch', 'adjusted_by'
        ).filter(created_at__gte=start_dt, created_at__lt=end_dt
                 ).exclude(reason__in=CHANNEL_ADJUSTMENT_REASONS)
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
        # Only transfers that physically moved count: a draft or cancelled
        # transfer is not a movement, and the movement happened when it
        # shipped (not when it was requested).
        tx_qs = StockTransfer.objects.select_related(
            'source_branch', 'dest_branch', 'requested_by'
        ).filter(
            status__in=[StockTransfer.Status.IN_TRANSIT,
                        StockTransfer.Status.COMPLETED],
            shipped_at__gte=start_dt, shipped_at__lt=end_dt,
        )
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
                    'date': tx.shipped_at.date().isoformat() if tx.shipped_at else '',
                    'timestamp': tx.shipped_at.isoformat() if tx.shipped_at else '',
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

        # ── Gather goods received notes (inflow) ──────────────────────
        # A purchase order counted at ``created_at`` with its *ordered* quantity
        # reported an inflow that may not have happened yet, and partial
        # receipts were dropped entirely. The GRN records what actually arrived.
        try:
            from purchase_orders.models import GoodsReceivedNote
            grn_qs = (GoodsReceivedNote.objects
                      .select_related('purchase_order',
                                      'purchase_order__supplier',
                                      'received_by')
                      .filter(received_date__gte=start, received_date__lte=end))
            if branch_id:
                grn_qs = grn_qs.filter(
                    Q(purchase_order__branch_id=branch_id)
                    | Q(purchase_order__branch__isnull=True))
            for grn in grn_qs:
                po = grn.purchase_order
                for idx, it in enumerate(grn.items_received or []):
                    if reason_filter and reason_filter != 'purchase_order':
                        continue
                    if direction_filter and 'inflow' != direction_filter:
                        continue
                    sid = it.get('medication_stock_id') or it.get('stock_id')
                    if stock_id and sid != stock_id:
                        continue
                    qty = int(it.get('qty') or it.get('quantity') or 0)
                    if qty <= 0:
                        continue
                    unit_cost = float(it.get('landed_unit_cost')
                                      or it.get('unit_cost') or 0)
                    med_name = it.get('name', 'Unknown')
                    stamp = _dt.combine(grn.received_date, _dt.min.time())
                    movements.append({
                        'id': f'GRN-{grn.id}-{idx}',
                        'date': grn.received_date.isoformat(),
                        'timestamp': stamp.isoformat(),
                        'direction': 'inflow',
                        'type': 'purchase_order',
                        'reason': 'purchase_order',
                        'source': 'Goods Received',
                        'reference': grn.grn_number or f'GRN-{grn.id}',
                        'stock_name': med_name,
                        'stock_id': sid,
                        'batch_number': it.get('batch_number') or '',
                        'quantity': qty,
                        'quantity_change': qty,
                        'unit_value': unit_cost,
                        'value_change': qty * unit_cost,
                        'user': str(grn.received_by) if grn.received_by else 'System',
                        'notes': f'PO {po.po_number}'
                                 + (f' · {po.supplier}' if po.supplier_id else ''),
                    })
        except Exception:
            pass

        # ── Sales Orders ──────────────────────────────────────────────
        # NB: sales-order fulfilment already writes a StockAdjustment with
        # reason='sales_order' (see sales_orders.serializers._fulfill_delivered_items),
        # so the adjustment block above is the single source of truth for SO
        # outflows. Aggregating SalesOrder rows here as well double-counted
        # every fulfilled order in the KPIs, donut and per-item rollups.

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

        # RBAC: roles without `stock.cost` must not see cost-derived values
        # (unit cost, movement value, inflow/outflow valuation).
        if not can_view_cost(request):
            value_in = value_out = net_value = 0.0
            for m in movements:
                m['unit_value'] = 0
                m['value_change'] = 0
            for d in items_rollup:
                d['value_in'] = 0
                d['value_out'] = 0

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
