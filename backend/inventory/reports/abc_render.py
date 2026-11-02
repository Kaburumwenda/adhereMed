"""Premium PDF for the ABC / XYZ inventory classification.

This is the fourth rendering style in the reports package:

* :mod:`inventory.reports.render`      - *tabular* sheets (many columns)
* :mod:`inventory.reports.bi_render`   - *board pack* documents (cover, sections)
* :mod:`inventory.reports.trace_render` / ``batch_render`` - *evidence* records
* **this module** - a *classification study*: Pareto curve, value-versus-item
  shares, the ABC x XYZ matrix and the planning policy that follows from it

The generic renderer can already draw a donut and a bar chart, but neither can
answer the question this document exists for. ABC/XYZ is not a table of rows,
it is an argument:

1. a **small number of items carries most of the value** - that is a curve, not
   a chart of categories, so the first visual is a Pareto with the cumulative
   line and the 70/90 guides drawn on it;
2. **the share of items and the share of value must be read together** - one
   class that is 8% of SKUs and 74% of value is the whole point, so the class
   panel prints both bars on the same axis;
3. **the two letters only mean something combined** - "AX" is a different
   instruction from "CZ", so the matrix is a 3x3 grid with the price and the
   instruction in the same cell.

Layout, portrait A4:

* page 1 - letterhead, scope, executive tiles, Pareto curve, ABC shares
* page 2 - XYZ stability, the ABC x XYZ matrix, the policy table
* page 3+ - the per-item classification table and the method note

All printed text is ASCII or WinAnsi-safe: Helvetica silently renders geometric
shapes as a stray ``G``, so bullets are ``*`` and separators are ``|``.
"""
from __future__ import annotations

import io
import math

from django.utils import timezone
from reportlab.lib import colors
from reportlab.lib.units import mm
from reportlab.platypus import (BaseDocTemplate, CondPageBreak, Flowable,
                                Frame, NextPageTemplate, PageTemplate,
                                Paragraph, Spacer, Table, TableStyle)

from config.pdf_branding import resolve_palette, tint

from . import render as base_render
from .trace_render import (BAD, BORDER, CONTENT_W, GOOD, HEADER_TEXT,
                           LETTERHEAD_H, MARGIN, MUTED_TEXT, PAGE, RUNNING_H,
                           SOFT, WARN, _SectionHeading, _styles, _TileRow,
                           _TraceDoc, count, money)

#: Cost-bearing figures are withheld from till roles; every value-flavoured
#: block has to disappear with them rather than print zeroes.
COST_HIDDEN_NOTE = ('Purchase cost is withheld from your role, so the value '
                    'curves and money figures are omitted. Classes and counts '
                    'are unaffected.')

#: Semantic tones for the two letters. Mirrors the on-screen pages so a printed
#: copy and the screen never disagree about which class is "the vital few".
CLASS_TONES = {'A': GOOD, 'B': WARN, 'C': BAD}
XYZ_TONES = {'X': GOOD, 'Y': WARN, 'Z': BAD}

CLASS_ACTIONS = {
    'A': 'Tight control', 'B': 'Moderate control', 'C': 'Loose control',
}
CLASS_NOTES = {
    'A': 'Count often, review forecast weekly, never stock out.',
    'B': 'Standard replenishment, monthly review.',
    'C': 'Order in bulk, review quarterly, clear slow lines.',
}
XYZ_NOTES = {
    'X': 'Steady demand - forecast from the average.',
    'Y': 'Seasonal or trending - forecast from the pattern.',
    'Z': 'Erratic - hold buffer stock, do not trust the average.',
}

#: The 3x3 matrix is the actionable output: each cell pairs a value band with a
#: stability band and states the control that follows.
MATRIX_POLICY = {
    'AX': 'Forecast precisely, review daily, count monthly.',
    'AY': 'Forecast the season, review weekly, buffer lightly.',
    'AZ': 'Buffer hard, review weekly, expect surprises.',
    'BX': 'Standard replenishment, review fortnightly.',
    'BY': 'Watch the trend, review fortnightly.',
    'BZ': 'Hold safety stock, review monthly.',
    'CX': 'Bulk order, review quarterly.',
    'CY': 'Bulk order, review quarterly.',
    'CZ': 'Clear or de-list; do not carry stock.',
}


# ── Small canvas helpers ────────────────────────────────────────────────
def _clip(canv, text, font, size, limit):
    """Trim to ``limit`` points with an ellipsis."""
    text = str(text or '')
    if canv.stringWidth(text, font, size) <= limit:
        return text
    while text and canv.stringWidth(text + '...', font, size) > limit:
        text = text[:-1]
    return (text + '...') if text else ''


def _pct(value):
    try:
        return f'{float(value or 0):.1f}%'
    except (TypeError, ValueError):
        return '0.0%'


def _compact_money(value, currency='KES'):
    """KES 1.24M / KES 88.4K - keeps an axis label from wrapping."""
    try:
        number = float(value or 0)
    except (TypeError, ValueError):
        return f'{currency} 0'
    sign = '-' if number < 0 else ''
    number = abs(number)
    if number >= 1_000_000:
        return f'{sign}{currency} {number / 1_000_000:.2f}M'
    if number >= 1_000:
        return f'{sign}{currency} {number / 1_000:.1f}K'
    return f'{sign}{currency} {number:,.0f}'


def _nice_ceiling(value):
    """Round an axis maximum up to 1/2/5 x 10^n so gridlines read cleanly."""
    if value <= 0:
        return 1.0
    exponent = math.floor(math.log10(value))
    magnitude = 10 ** exponent
    for step in (1, 2, 2.5, 5, 10):
        if value <= step * magnitude:
            return step * magnitude
    return 10 * magnitude


# ── Pareto curve ────────────────────────────────────────────────────────
class _ParetoChart(Flowable):
    """Value bars with the cumulative share line drawn over them.

    The whole ABC argument is the shape of that line: it climbs almost
    vertically while the A items go by, then flattens. Drawing the 70% and 90%
    guides on the same axes lets a reader *see* where the class boundary fell
    without reading a single number.
    """

    def __init__(self, curve, width, palette, *, height=68 * mm,
                 total_value=None, currency='KES', show_value=True):
        super().__init__()
        self.curve = [p for p in (curve or []) if p]
        self.width = width
        self.height = height
        self.palette = palette
        self.total_value = total_value
        self.currency = currency
        self.show_value = show_value

    def wrap(self, aw, ah):
        return self.width, self.height

    def draw(self):
        c = self.canv
        pal = self.palette
        w, h = self.width, self.height

        c.saveState()
        c.setFillColor(colors.white)
        c.setStrokeColor(BORDER)
        c.setLineWidth(0.5)
        c.roundRect(0, 0, w, h, 2 * mm, stroke=1, fill=1)

        # Card header
        c.setFillColor(HEADER_TEXT)
        c.setFont('Helvetica-Bold', 8.4)
        c.drawString(4 * mm, h - 5.6 * mm, 'Value concentration (Pareto)')
        c.setFillColor(SOFT)
        c.setFont('Helvetica', 6.4)
        c.drawString(4 * mm, h - 9.6 * mm,
                     'Bars: value per item, highest first. Line: cumulative '
                     'share of total value.')

        if len(self.curve) < 2:
            c.setFillColor(MUTED_TEXT)
            c.setFont('Helvetica', 7)
            c.drawString(4 * mm, h / 2, 'Not enough classified items to plot.')
            c.restoreState()
            return

        left = 18 * mm
        right = w - 15 * mm
        bottom = h - 44 * mm
        top = h - 15 * mm
        plot_w = right - left
        plot_h = top - bottom

        bars = [p.get('value') or 0 for p in self.curve]
        peak = _nice_ceiling(max(bars) if bars else 1)
        if not self.show_value:
            peak = _nice_ceiling(max([p.get('cumulative_pct') or 0
                                      for p in self.curve] + [1]))
            peak = max(peak, 1)

        # ── Horizontal grid + right-hand percentage axis ────────────────
        c.setLineWidth(0.3)
        for i in range(5):
            frac = i / 4.0
            y = bottom + plot_h * frac
            c.setStrokeColor(colors.HexColor('#EEF2F7'))
            c.line(left, y, right, y)
            c.setFillColor(MUTED_TEXT)
            c.setFont('Helvetica', 5.2)
            if self.show_value:
                c.drawRightString(left - 2 * mm, y - 1.6,
                                  _compact_money(peak * frac, self.currency))
            c.drawString(right + 1.6, y - 1.6, f'{int(frac * 100)}%')

        # ── Bars ────────────────────────────────────────────────────────
        n = len(self.curve)
        slot = plot_w / n
        bar_w = max(min(slot * 0.62, 6 * mm), 0.6)
        for i, point in enumerate(self.curve):
            value = point.get('value') or 0
            if self.show_value:
                bar_h = (value / peak) * plot_h if peak else 0
                x = left + i * slot + (slot - bar_w) / 2
                # Present enough to read as data, light enough that the
                # cumulative line (the actual argument) stays dominant.
                c.setFillColor(tint(pal['primary'], 0.38))
                c.roundRect(x, bottom, bar_w, max(bar_h, 1.0), 0.6,
                            stroke=0, fill=1)

        # ── Class boundary guides (70% and 90% of value) ────────────────
        for marker, label in ((70, 'A | B'), (90, 'B | C')):
            y = bottom + plot_h * (marker / 100.0)
            c.setStrokeColor(tint(WARN, 0.45))
            c.setLineWidth(0.6)
            c.setDash(1.6, 1.6)
            c.line(left, y, right, y)
            c.setDash()
            c.setFillColor(WARN)
            c.setFont('Helvetica-Bold', 5.0)
            c.drawString(left + 1.2, y + 1.2, f'{label}  {marker}%')

        # ── Cumulative line ─────────────────────────────────────────────
        coords = []
        for i, point in enumerate(self.curve):
            pct = min(max(point.get('cumulative_pct') or 0, 0), 100)
            coords.append((left + (i + 0.5) * slot,
                           bottom + plot_h * (pct / 100.0)))

        area = c.beginPath()
        area.moveTo(coords[0][0], bottom)
        for px, py in coords:
            area.lineTo(px, py)
        area.lineTo(coords[-1][0], bottom)
        area.close()
        c.setFillColor(tint(pal['secondary'], 0.90))
        c.drawPath(area, stroke=0, fill=1)

        line = c.beginPath()
        line.moveTo(*coords[0])
        for px, py in coords[1:]:
            line.lineTo(px, py)
        c.setStrokeColor(pal['secondary'])
        c.setLineWidth(1.5)
        c.drawPath(line, stroke=1, fill=0)

        # ── X axis: rank numbers, thinned so they never collide ─────────
        stride = max(1, n // 9)
        c.setFillColor(MUTED_TEXT)
        c.setFont('Helvetica', 5.0)
        for i in range(0, n, stride):
            c.drawCentredString(left + (i + 0.5) * slot, bottom - 3.4 * mm,
                                str(i + 1))
        c.drawString(right - 12 * mm, bottom - 6.6 * mm, 'item rank')

        # ── Legend ──────────────────────────────────────────────────────
        legend_y = h - 13.4 * mm
        c.setFillColor(tint(pal['primary'], 0.38))
        c.rect(right - 52 * mm, legend_y, 3 * mm, 2 * mm, stroke=0, fill=1)
        c.setFillColor(SOFT)
        c.setFont('Helvetica', 5.4)
        c.drawString(right - 48 * mm, legend_y + 0.2 * mm,
                     'Value per item' if self.show_value else 'Cumulative')

        c.setStrokeColor(pal['secondary'])
        c.setLineWidth(1.4)
        c.line(right - 26 * mm, legend_y + 1 * mm, right - 22 * mm,
               legend_y + 1 * mm)
        c.setFillColor(SOFT)
        c.drawString(right - 20 * mm, legend_y + 0.2 * mm, 'Cumulative %')

        c.restoreState()


# ── Paired share bars (items% vs value%) ────────────────────────────────
class _ShareBars(Flowable):
    """Two bars per class on one axis: share of items and share of value.

    A single-bar chart hides the entire argument of ABC. Printing both shares
    against the same 0-100% axis is what makes "8% of SKUs, 74% of value"
    legible at a glance - and the gap between the bars *is* the finding.
    """

    def __init__(self, rows, width, palette, *, height=None,
                 primary_label='Share of value', secondary_label='Share of items',
                 title='Class shares'):
        super().__init__()
        self.rows = rows or []
        self.width = width
        self.palette = palette
        self.primary_label = primary_label
        self.secondary_label = secondary_label
        self.title = title
        row_h = 11 * mm
        self.height = height or (14 * mm + row_h * max(len(self.rows), 1))

    def wrap(self, aw, ah):
        return self.width, self.height

    def draw(self):
        c = self.canv
        pal = self.palette
        w, h = self.width, self.height

        c.saveState()
        c.setFillColor(colors.white)
        c.setStrokeColor(BORDER)
        c.setLineWidth(0.5)
        c.roundRect(0, 0, w, h, 2 * mm, stroke=1, fill=1)

        c.setFillColor(HEADER_TEXT)
        c.setFont('Helvetica-Bold', 8.4)
        c.drawString(4 * mm, h - 5.6 * mm, self.title)

        # Legend for the two bar kinds.
        legend_y = h - 5.4 * mm
        c.setFillColor(tint(pal['primary'], 0.10))
        c.rect(w - 66 * mm, legend_y, 3 * mm, 2 * mm, stroke=0, fill=1)
        c.setFillColor(SOFT)
        c.setFont('Helvetica', 5.4)
        c.drawString(w - 62 * mm, legend_y + 0.2 * mm, self.primary_label)

        c.setFillColor(tint(SOFT, 0.45))
        c.rect(w - 32 * mm, legend_y, 3 * mm, 2 * mm, stroke=0, fill=1)
        c.drawString(w - 28 * mm, legend_y + 0.2 * mm, self.secondary_label)

        label_w = 14 * mm
        track_x = 4 * mm + label_w
        track_w = w - track_x - 16 * mm
        row_h = 11 * mm

        for index, row in enumerate(self.rows):
            y = h - 14 * mm - (index + 1) * row_h + 3 * mm
            tone = row.get('tone') or pal['primary']

            # Class chip
            c.setFillColor(tone)
            c.roundRect(4 * mm, y + 4.2 * mm, 6 * mm, 5.4 * mm, 1.2 * mm,
                        stroke=0, fill=1)
            c.setFillColor(colors.white)
            c.setFont('Helvetica-Bold', 7.4)
            c.drawCentredString(7 * mm, y + 6 * mm, str(row.get('label'))[:2])

            c.setFillColor(HEADER_TEXT)
            c.setFont('Helvetica-Bold', 6.4)
            c.drawString(11 * mm, y + 7.2 * mm, str(row.get('caption') or '')[:22])

            # Track + value bar
            c.setFillColor(colors.HexColor('#F1F5F9'))
            c.roundRect(track_x, y + 6.6 * mm, track_w, 2.4 * mm, 0.8 * mm,
                        stroke=0, fill=1)
            value_pct = max(0.0, min(float(row.get('value_pct') or 0), 100))
            c.setFillColor(tint(tone, 0.12))
            c.roundRect(track_x, y + 6.6 * mm,
                        max(track_w * value_pct / 100.0, 0.4), 2.4 * mm,
                        0.8 * mm, stroke=0, fill=1)

            # Track + items bar (below, thinner and muted)
            c.setFillColor(colors.HexColor('#F1F5F9'))
            c.roundRect(track_x, y + 3.0 * mm, track_w, 1.6 * mm, 0.6 * mm,
                        stroke=0, fill=1)
            item_pct = max(0.0, min(float(row.get('items_pct') or 0), 100))
            c.setFillColor(tint(SOFT, 0.45))
            c.roundRect(track_x, y + 3.0 * mm,
                        max(track_w * item_pct / 100.0, 0.4), 1.6 * mm,
                        0.6 * mm, stroke=0, fill=1)

            # Figures at the end of each bar
            c.setFillColor(HEADER_TEXT)
            c.setFont('Helvetica-Bold', 5.6)
            c.drawRightString(w - 4 * mm, y + 6.3 * mm, _pct(value_pct))
            c.setFillColor(MUTED_TEXT)
            c.setFont('Helvetica', 5.2)
            c.drawRightString(w - 4 * mm, y + 2.8 * mm, _pct(item_pct))

            # Count hint next to the caption
            c.setFillColor(MUTED_TEXT)
            c.setFont('Helvetica', 5.2)
            c.drawString(11 * mm, y + 4.6 * mm,
                         str(row.get('hint') or '')[:34])

        c.restoreState()


# ── ABC x XYZ matrix ────────────────────────────────────────────────────
class _MatrixGrid(Flowable):
    """The 3x3 grid, shaded by share of value, with the policy in each cell."""

    def __init__(self, cells, width, palette, *, show_value=True):
        super().__init__()
        self.cells = {(c.get('abc'), c.get('xyz')): c for c in (cells or [])}
        self.width = width
        self.palette = palette
        self.show_value = show_value
        header = 8 * mm
        self.height = 12 * mm + header + 3 * 21 * mm

    def wrap(self, aw, ah):
        return self.width, self.height

    def draw(self):
        c = self.canv
        w, h = self.width, self.height

        c.saveState()
        c.setFillColor(colors.white)
        c.setStrokeColor(BORDER)
        c.setLineWidth(0.5)
        c.roundRect(0, 0, w, h, 2 * mm, stroke=1, fill=1)

        c.setFillColor(HEADER_TEXT)
        c.setFont('Helvetica-Bold', 8.4)
        c.drawString(4 * mm, h - 5.6 * mm, 'ABC / XYZ matrix')
        c.setFillColor(SOFT)
        c.setFont('Helvetica', 6.2)
        c.drawString(4 * mm, h - 9.4 * mm,
                     'Every SKU lands in one cell. Value band across, demand '
                     'stability down.')

        label_col = 13 * mm
        top = h - 13 * mm
        col_w = (w - 8 * mm - label_col) / 3.0
        row_h = 21 * mm
        grid_top = top - 7 * mm        # room for the X / Y / Z headers

        # Column headers
        for col, letter in enumerate('XYZ'):
            c.setFillColor(XYZ_TONES[letter])
            c.setFont('Helvetica-Bold', 7.4)
            cx = 4 * mm + label_col + col * col_w
            c.drawCentredString(cx + col_w / 2, grid_top + 2.2 * mm,
                                f'{letter} - {XYZ_NOTES[letter].split(" -")[0]}')

        for row, abc in enumerate('ABC'):
            y = grid_top - (row + 1) * row_h

            # Row header chip
            c.setFillColor(CLASS_TONES[abc])
            c.roundRect(4 * mm, y + row_h - 9 * mm, label_col - 2 * mm,
                        7 * mm, 1.2 * mm, stroke=0, fill=1)
            c.setFillColor(colors.white)
            c.setFont('Helvetica-Bold', 7.6)
            c.drawCentredString(4 * mm + (label_col - 2 * mm) / 2,
                                y + row_h - 6.8 * mm, abc)

            for col, xyz in enumerate('XYZ'):
                cell = self.cells.get((abc, xyz)) or {'count': 0, 'value_pct': 0}
                x = 4 * mm + label_col + col * col_w
                share = float(cell.get('value_pct') or 0)
                # Shade by share so the hot corner (AX) reads immediately.
                intensity = min(0.86, 0.10 + (share / 100.0) * 0.62)
                c.setFillColor(tint(CLASS_TONES[abc], intensity))
                c.setStrokeColor(tint(CLASS_TONES[abc], 0.55))
                c.setLineWidth(0.4)
                c.roundRect(x + 0.8 * mm, y + 0.8 * mm,
                            col_w - 1.6 * mm, row_h - 1.6 * mm, 1.4 * mm,
                            stroke=1, fill=1)

                c.setFillColor(HEADER_TEXT)
                c.setFont('Helvetica-Bold', 10)
                c.drawString(x + 2.4 * mm, y + row_h - 6 * mm,
                             count(cell.get('count')))
                c.setFillColor(MUTED_TEXT)
                c.setFont('Helvetica', 5.2)
                c.drawString(x + 2.4 * mm, y + row_h - 9 * mm, 'SKU')

                if self.show_value:
                    c.setFillColor(HEADER_TEXT)
                    c.setFont('Helvetica-Bold', 6.6)
                    c.drawString(x + 2.4 * mm, y + row_h - 13.4 * mm,
                                 _pct(share))
                    c.setFillColor(MUTED_TEXT)
                    c.setFont('Helvetica', 5)
                    c.drawString(x + 2.4 * mm, y + row_h - 16 * mm,
                                 'of value')

                policy = MATRIX_POLICY.get(f'{abc}{xyz}', '')
                c.setFillColor(SOFT)
                c.setFont('Helvetica', 4.9)
                for line_index, chunk in enumerate(
                        _wrap_text(policy, 30)[:2]):
                    c.drawString(x + 2.4 * mm,
                                 y + 5.6 * mm - line_index * 2.4 * mm, chunk)

        c.restoreState()


def _wrap_text(text, limit):
    """Greedy word wrap for the tiny policy sentences inside matrix cells."""
    words, lines, current = str(text or '').split(), [], ''
    for word in words:
        candidate = f'{current} {word}'.strip()
        if len(candidate) <= limit:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


# ── Tables ──────────────────────────────────────────────────────────────
def _class_policy_table(class_summary, styles, palette, currency, show_value):
    """One row per ABC class with the control policy it earns."""
    headers = ['Class', 'Items', 'Items %', 'Value', 'Value %',
               'Avg / day', 'Control', 'What it means']

    rows = [[Paragraph(h, styles['head']) for h in headers]]

    for item in class_summary:
        cls = item['cls']
        rows.append([
            Paragraph(f'<b>{cls}</b>', styles['cell_b']),
            Paragraph(count(item.get('count')), styles['cell_r']),
            Paragraph(_pct(item.get('items_pct')), styles['cell_r']),
            Paragraph(money(item.get('value'), currency) if show_value else '-',
                      styles['cell_r']),
            Paragraph(_pct(item.get('value_pct')) if show_value else '-',
                      styles['cell_r']),
            Paragraph(f"{float(item.get('avg_daily') or 0):,.2f}",
                      styles['cell_r']),
            Paragraph(CLASS_ACTIONS.get(cls, ''), styles['cell']),
            Paragraph(CLASS_NOTES.get(cls, ''), styles['cell']),
        ])

    widths = [11 * mm, 12 * mm, 14 * mm, 26 * mm, 15 * mm, 15 * mm,
              24 * mm, CONTENT_W - 117 * mm]
    table = Table(rows, colWidths=widths, repeatRows=1, hAlign='LEFT')
    style = [
        ('BACKGROUND', (0, 0), (-1, 0), palette['primary']),
        ('GRID', (0, 0), (-1, -1), 0.3, BORDER),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 2.6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 2.6),
        ('LEFTPADDING', (0, 0), (-1, -1), 2.6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 2.6),
    ]
    for index, item in enumerate(class_summary, start=1):
        tone = CLASS_TONES.get(item['cls'], palette['primary'])
        style.append(('BACKGROUND', (0, index), (0, index), tint(tone, 0.72)))
    table.setStyle(TableStyle(style))
    return table


def _detail_table(rows, styles, palette, currency, show_value, cap=400):
    """The full per-item classification, ranked A -> C then by share."""
    headers = ['#', 'Item', 'ABC', 'XYZ']
    aligns = ['cell_c', 'cell', 'cell_c', 'cell_c']
    widths = [7 * mm, 46 * mm, 9 * mm, 9 * mm]
    if show_value:
        headers.append('Share %')
        aligns.append('cell_r')
        widths.append(13 * mm)
    headers += ['Avg / day', 'ROP', 'Safety', 'EOQ', 'Lead', 'MAPE', 'Warehouse']
    aligns += ['cell_r', 'cell_r', 'cell_r', 'cell_r', 'cell_r', 'cell_r',
               'cell']
    widths += [12 * mm, 12 * mm, 12 * mm, 11 * mm, 9 * mm, 10 * mm]
    # The warehouse column takes whatever is left, and it must hold a branch
    # name on ONE line: a wrapped "HQ Warehouse" doubled every row height and
    # cut the table's capacity by half.
    widths.append(max(CONTENT_W - sum(widths), 26 * mm))

    header_row = [Paragraph(h, styles['head_r' if a == 'cell_r'
                             else 'head_c' if a == 'cell_c' else 'head'])
                  for h, a in zip(headers, aligns)]
    body = [header_row]

    for index, row in enumerate(rows[:cap], start=1):
        cells = [
            Paragraph(str(index), styles['cell_c']),
            Paragraph(_clip_text(row.get('medication_name'), 46),
                      styles['cell']),
            Paragraph(f'<b>{row.get("abc_class") or "-"}</b>', styles['cell_c']),
            Paragraph(row.get('xyz_class') or '-', styles['cell_c']),
        ]
        if show_value:
            cells.append(Paragraph(_pct(row.get('value_share_pct')),
                                   styles['cell_r']))
        cells += [
            Paragraph(f"{float(row.get('avg_daily_demand') or 0):,.2f}",
                      styles['cell_r']),
            Paragraph(f"{float(row.get('reorder_point') or 0):,.1f}",
                      styles['cell_r']),
            Paragraph(f"{float(row.get('safety_stock') or 0):,.1f}",
                      styles['cell_r']),
            Paragraph(f"{float(row.get('eoq') or 0):,.1f}", styles['cell_r']),
            Paragraph(str(row.get('lead_time_days') or 0), styles['cell_r']),
            Paragraph('-' if row.get('forecast_mape') is None
                      else _pct(row.get('forecast_mape')), styles['cell_r']),
            Paragraph(_clip_text(row.get('branch'), 26), styles['cell']),
        ]
        body.append(cells)

    table = Table(body, colWidths=widths, repeatRows=1, hAlign='LEFT')
    style = [
        ('BACKGROUND', (0, 0), (-1, 0), palette['primary']),
        ('GRID', (0, 0), (-1, -1), 0.25, BORDER),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 1.9),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 1.9),
        ('LEFTPADDING', (0, 0), (-1, -1), 2.2),
        ('RIGHTPADDING', (0, 0), (-1, -1), 2.2),
    ]
    for index, row in enumerate(rows[:cap], start=1):
        if index % 2 == 0:
            style.append(('BACKGROUND', (0, index), (-1, index),
                          colors.HexColor('#F8FAFC')))
        tone = CLASS_TONES.get(row.get('abc_class'))
        if tone:
            style.append(('BACKGROUND', (2, index), (2, index), tint(tone, 0.78)))
    table.setStyle(TableStyle(style))
    return table


def _clip_text(value, limit):
    """Escape for Paragraph and trim long labels."""
    text = str(value or '-')
    text = text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
    return text if len(text) <= limit else text[:limit - 3] + '...'


def _method_note(meta, styles, palette, show_value, scope_lines):
    """How the letters were derived - a report a planner can defend."""
    windowed = meta.get('windowed')
    basis = meta.get('value_basis')
    thresholds = meta.get('thresholds') or {}
    basis_label = {'consumption': 'consumption value',
                   'on_hand': 'on-hand capital'}.get(basis, 'value')

    if windowed:
        period = (f"{meta.get('window_start') or '?'} to "
                  f"{meta.get('window_end') or '?'}")
        source = (f'Consumption inside {period}: units issued (sales, '
                  f'dispensing, sales orders) multiplied by the unit cost.')
    else:
        source = ('Stored planning snapshot: units on hand multiplied by the '
                  'unit cost (the basis the nightly planner classifies on).')

    lines = [
        f'<b>ABC (value).</b> Items are ranked by {basis_label} '
        f'and cut at {thresholds.get("a", 70)}% and '
        f'{thresholds.get("b", 90)}% of cumulative value: A is the vital few '
        f'that carry the first {thresholds.get("a", 70)}%, B the next band, C '
        f'the long tail. A class is decided on the cumulative share '
        f'<i>before</i> the item is counted, so the single item that makes up '
        f'most of the value is not demoted to C.',
        '<b>XYZ (stability).</b> The coefficient of variation of daily demand '
        'over the same window: X is CV &lt;= 0.25 (steady), Y is CV &lt;= 0.5 '
        '(seasonal or trending), Z is anything above (erratic).',
        f'<b>Basis.</b> {source}',
        '<b>Reading it.</b> ABC sets how much attention an item deserves; XYZ '
        'sets how much uncertainty you must buffer for. The letter pair in the '
        'matrix is the actionable unit - AX is "forecast hard and never run '
        'out", CZ is "stop carrying stock".',
    ]
    if scope_lines:
        lines.append('<b>Scope.</b> ' + ' '.join(
            str(line) for line in scope_lines))

    body = [[Paragraph('Method and definitions', styles['h3'])],
            [Paragraph('<br/><br/>'.join(lines), styles['small'])]]
    table = Table(body, colWidths=[CONTENT_W], hAlign='LEFT')
    table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), tint(palette['primary'], 0.965)),
        ('BOX', (0, 0), (-1, -1), 0.4, tint(palette['primary'], 0.82)),
        ('LEFTPADDING', (0, 0), (-1, -1), 4 * mm),
        ('RIGHTPADDING', (0, 0), (-1, -1), 4 * mm),
        ('TOPPADDING', (0, 0), (-1, -1), 3 * mm),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 3 * mm),
    ]))
    return table


# ── Document ────────────────────────────────────────────────────────────
def _draw_watermark(canv, text, palette, opacity):
    """Diagonal mark, drawn under the content on every page.

    A solid tint rather than a real alpha: ``setFillAlpha`` needs an ExtGState
    entry, and when the canvas has none the mark is silently dropped - a
    watermark that sometimes prints and sometimes vanishes is worse than none.
    """
    text = str(text or '').strip()
    if not text:
        return
    width, height = PAGE
    canv.saveState()
    # ``opacity`` still shifts the tint so the operator's choice is honoured.
    strength = 0.90 + (1.0 - max(0.05, min(float(opacity or 0.3), 0.60))) * 0.07
    canv.setFillColor(tint(palette['primary'], min(0.97, strength)))
    canv.setFont('Helvetica-Bold', 40)
    canv.translate(width / 2.0, height / 2.0)
    canv.rotate(32)
    canv.drawCentredString(0, 0, text[:32])
    canv.restoreState()


def render_abc_pdf(*, rows, meta=None, org=None, logo_path=None, palette=None,
                   business_name='', title='ABC / XYZ Classification',
                   subtitle='', scope_lines=None, notes='', watermark='',
                   watermark_opacity=0.30, currency='KES', prepared_by='',
                   can_view_cost=True) -> bytes:
    """Render the ABC/XYZ study to PDF bytes.

    ``rows`` and ``meta`` are exactly what
    :func:`inventory.reports.datasets.build_abc_analysis` produced, so the
    document can never disagree with the preview table it was exported from.
    """
    meta = meta or {}
    rows = rows or []
    palette = palette or resolve_palette(None)
    styles = _styles()
    show_value = bool(can_view_cost)

    class_summary = meta.get('class_summary') or []
    xyz_summary = meta.get('xyz_summary') or []
    concentration = meta.get('concentration') or {}
    total_value = meta.get('total_value') or 0

    if not subtitle:
        parts = [
            f"{count(len(rows))} items classified",
            ('consumption basis' if meta.get('windowed')
             else 'on-hand capital basis'),
        ]
        if show_value:
            parts.append(_compact_money(total_value, currency))
        subtitle = '  |  '.join(parts)

    doc_info = _TraceDoc(
        palette=palette, org=org, logo_path=logo_path,
        business_name=business_name, title=title, subtitle=subtitle,
        prepared_by=prepared_by, item_label='ABC / XYZ',
        stamp='CLASSIFICATION STUDY',
        footer_label='ABC / XYZ classification study')

    buffer = io.BytesIO()
    doc = BaseDocTemplate(
        buffer, pagesize=PAGE,
        leftMargin=MARGIN, rightMargin=MARGIN,
        topMargin=MARGIN, bottomMargin=MARGIN + 4 * mm,
        title=title, author=business_name or base_render.CREDIT_BRAND,
        subject='ABC / XYZ inventory classification',
        creator='AdhereMed',
    )

    first_frame = Frame(
        MARGIN, MARGIN + 4 * mm, CONTENT_W,
        PAGE[1] - 2 * MARGIN - LETTERHEAD_H - 4 * mm,
        id='first', leftPadding=0, rightPadding=0,
        topPadding=0, bottomPadding=0)
    later_frame = Frame(
        MARGIN, MARGIN + 4 * mm, CONTENT_W,
        PAGE[1] - 2 * MARGIN - RUNNING_H - 4 * mm,
        id='later', leftPadding=0, rightPadding=0,
        topPadding=0, bottomPadding=0)

    def _first(canv, _doc):
        _draw_watermark(canv, watermark, palette, watermark_opacity)
        doc_info.draw_letterhead(canv)

    def _later(canv, _doc):
        _draw_watermark(canv, watermark, palette, watermark_opacity)
        doc_info.draw_running_header(canv)

    doc.addPageTemplates([
        PageTemplate(id='first', frames=[first_frame], onPage=_first),
        PageTemplate(id='later', frames=[later_frame], onPage=_later),
    ])

    section = 1
    story = [NextPageTemplate('later')]

    # ── 01 Executive summary ────────────────────────────────────────────
    a = next((c for c in class_summary if c['cls'] == 'A'), {})
    b = next((c for c in class_summary if c['cls'] == 'B'), {})
    c_ = next((c for c in class_summary if c['cls'] == 'C'), {})
    x = next((s for s in xyz_summary if s['cls'] == 'X'), {})
    z = next((s for s in xyz_summary if s['cls'] == 'Z'), {})

    tiles = [
        {'label': 'Items classified', 'value': count(len(rows)),
         'hint': 'stock items with a policy'},
        {'label': 'Class A', 'value': count(a.get('count')),
         'hint': f"{_pct(a.get('value_pct'))} of value" if show_value
                 else 'tight control', 'tone': GOOD},
        {'label': 'Class B', 'value': count(b.get('count')),
         'hint': f"{_pct(b.get('value_pct'))} of value" if show_value
                 else 'moderate control', 'tone': WARN},
        {'label': 'Class C', 'value': count(c_.get('count')),
         'hint': f"{_pct(c_.get('value_pct'))} of value" if show_value
                 else 'loose control', 'tone': BAD},
    ]
    if show_value:
        tiles += [
            {'label': 'Classified value',
             'value': _compact_money(total_value, currency),
             'hint': ('consumption in window' if meta.get('windowed')
                      else 'capital on the shelf')},
            {'label': 'Items for 80%',
             'value': count(concentration.get('items_for_80')),
             'hint': f"{_pct(concentration.get('pct_for_80'))} of the catalogue"},
        ]
    tiles += [
        {'label': 'Steady demand (X)', 'value': count(x.get('count')),
         'hint': 'forecast from the average', 'tone': GOOD},
        {'label': 'Erratic demand (Z)', 'value': count(z.get('count')),
         'hint': 'buffer, do not trust the mean',
         'tone': BAD if z.get('count') else None},
    ]

    scope_note = ' '.join(str(line) for line in (scope_lines or []) if line)
    story += [
        _SectionHeading(section, 'Classification at a glance',
                        scope_note or
                        'Value band (ABC) and demand stability (XYZ) for the '
                        'whole catalogue.', CONTENT_W, palette),
        Spacer(1, 1.8 * mm),
        _TileRow(tiles, CONTENT_W, palette, columns=4),
    ]
    section += 1

    if not show_value:
        story += [
            Spacer(1, 3 * mm),
            Paragraph(COST_HIDDEN_NOTE, styles['small']),
        ]

    # ── 02 Pareto curve ─────────────────────────────────────────────────
    if show_value and meta.get('pareto') and total_value > 0:
        story += [
            CondPageBreak(64 * mm),
            Spacer(1, 4.5 * mm),
            _SectionHeading(section, 'Value concentration',
                            'How few items carry how much of the value - the '
                            'shape that justifies ABC at all.', CONTENT_W,
                            palette),
            Spacer(1, 1.6 * mm),
            _ParetoChart(meta.get('pareto'), CONTENT_W, palette,
                         total_value=total_value, currency=currency),
        ]
        section += 1
    elif show_value and total_value <= 0:
        # A Pareto of zeroes is worse than no chart: it looks like a rendering
        # fault. Say plainly that the window carried no value instead.
        reason = ('No consumption was recorded in the selected window, so there '
                  'is no value to rank and every item falls to class C.'
                  if meta.get('windowed') else
                  'No stock is valued yet (items have no cost price or no '
                  'units on hand), so there is no value to rank.')
        story += [
            Spacer(1, 4 * mm),
            Paragraph(reason, styles['body']),
        ]

    # ── 03 ABC class shares ─────────────────────────────────────────────
    if class_summary:
        share_rows = [{
            'label': item['cls'],
            'caption': f"Class {item['cls']} - {count(item.get('count'))} items",
            'hint': CLASS_ACTIONS.get(item['cls'], ''),
            'value_pct': item.get('value_pct') if show_value else 0,
            'items_pct': item.get('items_pct'),
            'tone': CLASS_TONES.get(item['cls']),
        } for item in class_summary]
        story += [
            CondPageBreak(52 * mm),
            Spacer(1, 4.5 * mm),
            _SectionHeading(section, 'ABC shares',
                            ('Share of items against share of value - the gap '
                             'between the bars is the finding.'
                             if show_value else
                             'Share of the catalogue in each value band.'),
                            CONTENT_W, palette),
            Spacer(1, 1.6 * mm),
            _ShareBars(share_rows, CONTENT_W, palette,
                       title='Items versus value by class'),
        ]
        section += 1

    # ── 04 XYZ stability ────────────────────────────────────────────────
    if xyz_summary:
        xyz_rows = [{
            'label': item['cls'],
            'caption': f"Class {item['cls']} - {count(item.get('count'))} items",
            'hint': XYZ_NOTES.get(item['cls'], ''),
            'value_pct': item.get('items_pct'),
            'items_pct': item.get('value_pct') if show_value else 0,
            'tone': XYZ_TONES.get(item['cls']),
        } for item in xyz_summary]
        story += [
            CondPageBreak(52 * mm),
            Spacer(1, 4.5 * mm),
            _SectionHeading(section, 'Demand stability (XYZ)',
                            'Coefficient of variation of daily demand: how '
                            'forecastable each band is.', CONTENT_W, palette),
            Spacer(1, 1.6 * mm),
            _ShareBars(xyz_rows, CONTENT_W, palette, height=52 * mm,
                       title='Demand stability by band',
                       primary_label='Share of items',
                       secondary_label='Share of value' if show_value
                                       else ''),
        ]
        section += 1

    # ── 05 Matrix ───────────────────────────────────────────────────────
    if meta.get('matrix'):
        story += [
            CondPageBreak(84 * mm),
            Spacer(1, 4.5 * mm),
            _SectionHeading(section, 'The combined matrix',
                            'Both letters together, with the control each cell '
                            'earns.', CONTENT_W, palette),
            Spacer(1, 1.6 * mm),
            _MatrixGrid(meta['matrix'], CONTENT_W, palette,
                        show_value=show_value),
        ]
        section += 1

    # ── 06 Class policy ─────────────────────────────────────────────────
    if class_summary:
        story += [
            CondPageBreak(42 * mm),
            Spacer(1, 4.5 * mm),
            _SectionHeading(section, 'Control policy by class',
                            'What follows from the letter: how hard to look and '
                            'how often.', CONTENT_W, palette),
            Spacer(1, 1.6 * mm),
            _class_policy_table(class_summary, styles, palette, currency,
                                show_value),
        ]
        section += 1

    # ── 07 Item detail ──────────────────────────────────────────────────
    if rows:
        story += [
            CondPageBreak(42 * mm),
            Spacer(1, 4.5 * mm),
            _SectionHeading(section, 'Classification by item',
                            f'{count(len(rows))} item(s), A first then by '
                            'share. Warehouse column shows the owning site.',
                            CONTENT_W, palette),
            Spacer(1, 1.6 * mm),
            _detail_table(rows, styles, palette, currency, show_value),
        ]
        if len(rows) > 400:
            story += [Spacer(1, 1.6 * mm),
                      Paragraph(f'Showing the first 400 of {count(len(rows))} '
                                f'items. The complete list is in the CSV or '
                                f'Excel export.', styles['tiny'])]
        section += 1

    # ── 08 Method ───────────────────────────────────────────────────────
    story += [
        CondPageBreak(50 * mm),
        Spacer(1, 4.5 * mm),
        _method_note(meta, styles, palette, show_value, scope_lines),
    ]

    if notes:
        story += [Spacer(1, 3 * mm),
                  Paragraph(str(notes).replace('\n', '<br/>'), styles['small'])]

    story += [
        Spacer(1, 3 * mm),
        Paragraph(
            f'Generated {timezone.localtime(timezone.now()).strftime("%d %b %Y, %H:%M")}'
            f'  |  {business_name or "AdhereMed"}  |  '
            f'{prepared_by or "Prepared by the warehouse team"}',
            styles['tiny']),
    ]

    doc.build(
        story,
        canvasmaker=lambda *args, **kwargs: base_render._NumberedCanvas(
            *args, report_doc=doc_info, **kwargs),
    )
    return buffer.getvalue()
