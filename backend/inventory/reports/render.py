"""Branded PDF renderer for the inventory report platform.

One entry point — :func:`render_report_pdf` — turns a
``{'columns', 'rows', 'totals', 'meta'}`` payload into a print-ready document:

* **page 1** carries a letterhead band with the tenant logo, name, address and
  contact line, plus the report title and its scope on the right;
* **pages 2+** use a compact running header so the table keeps its density;
* **every page** is watermarked diagonally (tenant-configurable text, drawn
  with a low fill alpha so it never fights the data);
* the table repeats its header row on each page, wraps long cells and stripes
  alternate rows in the tenant's brand tint;
* an optional summary band, breakdown table and totals row frame the detail.

Colour comes from :func:`config.pdf_branding.resolve_palette`, so a tenant that
changes its palette at ``/ims/organization/branding`` repaints this document
too.
"""
from __future__ import annotations

import io
import os
from datetime import date, datetime

from django.utils import timezone
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas as pdf_canvas
from reportlab.platypus import (Flowable, KeepTogether, Paragraph,
                                SimpleDocTemplate, Spacer, Table, TableStyle)

from config.pdf_branding import resolve_palette, tint

MARGIN = 12 * mm
LETTERHEAD_H = 26 * mm
LETTERHEAD_GAP = 5 * mm
HEADER_TEXT = colors.HexColor('#0F172A')
MUTED_TEXT = colors.HexColor('#64748B')
BORDER = colors.HexColor('#E2E8F0')

#: Opacity of the diagonal watermark. Alpha the tenant can dial from the UI; the
#: clamp mirrors the API so a hand-crafted payload cannot erase or black out the
#: page. 0.30 is the product default — clearly legible on print without
#: obscuring the table underneath.
DEFAULT_WATERMARK_ALPHA = 0.30
MIN_WATERMARK_ALPHA = 0.05
MAX_WATERMARK_ALPHA = 0.60

#: Product attribution printed in the footer of every report.
CREDIT_BRAND = 'AdhereMed'
CREDIT_SITE = 'www.adheremed.co'
CREDIT_URL = 'https://www.adheremed.co'

#: Width of the row-number gutter prepended to PDF tables.
ROW_NUMBER_W = 19 * mm / 2

#: Alias map from the catalog's column ``type`` to a align/format behaviour.
_TYPE_ALIGN = {
    'int': TA_RIGHT, 'num': TA_RIGHT, 'money': TA_RIGHT, 'percent': TA_RIGHT,
    'date': TA_CENTER, 'datetime': TA_LEFT, 'badge': TA_CENTER, 'text': TA_LEFT,
}


# ── Value formatting ────────────────────────────────────────────────────
def format_value(value, type_, currency='KES'):
    """Render a raw dataset value for display/print."""
    if value is None or value == '':
        return '—'
    if type_ == 'money':
        try:
            return f'{currency} {float(value):,.2f}'
        except (TypeError, ValueError):
            return str(value)
    if type_ == 'int':
        try:
            return f'{int(round(float(value))):,}'
        except (TypeError, ValueError):
            return str(value)
    if type_ == 'num':
        try:
            number = float(value)
        except (TypeError, ValueError):
            return str(value)
        return f'{number:,.2f}'.rstrip('0').rstrip('.') if number % 1 else f'{int(number):,}'
    if type_ == 'percent':
        try:
            return f'{float(value):,.1f}%'
        except (TypeError, ValueError):
            return str(value)
    if type_ in ('date', 'datetime'):
        try:
            if isinstance(value, datetime):
                local = timezone.localtime(value) if timezone.is_aware(value) else value
                return local.strftime('%d %b %Y' if type_ == 'date'
                                      else '%d %b %Y %H:%M')
            if isinstance(value, date):
                return value.strftime('%d %b %Y')
        except Exception:
            pass
        return str(value)
    return str(value)


def _readable_on(color):
    """White or near-black — whichever stays legible on ``color``."""
    try:
        lum = 0.2126 * color.red + 0.7152 * color.green + 0.0722 * color.blue
    except Exception:
        return colors.white
    return colors.white if lum <= 0.62 else colors.HexColor('#0F172A')


def _org_detail_lines(org):
    """Address + contact lines, de-duplicated (tenants type the city twice)."""
    org = org or {}
    tokens, seen = [], set()
    for value in (org.get('address'), org.get('city'), org.get('country')):
        for raw in str(value or '').split(','):
            token = raw.strip().strip('.').strip()
            if not token or token.lower() in seen:
                continue
            seen.add(token.lower())
            tokens.append(token)

    lines = []
    if tokens:
        lines.append(', '.join(tokens))

    contact = []
    if (org.get('phone') or '').strip():
        contact.append(f"Tel {org['phone'].strip()}")
    if (org.get('email') or '').strip():
        contact.append(org['email'].strip())
    if (org.get('website') or '').strip():
        contact.append(org['website'].strip().replace('https://', '')
                       .replace('http://', '').rstrip('/'))
    if contact:
        # ASCII separator — Helvetica/WinAnsi renders a middot as a stray glyph.
        lines.append('   |   '.join(contact))
    return lines


def _draw_logo(canv, x, centre_y, box, logo_path, chip_color=None):
    """Draw the tenant mark, with a white chip when the artwork is dark."""
    from reportlab.lib.utils import ImageReader

    if not logo_path or not os.path.exists(logo_path):
        return x
    try:
        img = ImageReader(logo_path)
        iw, ih = img.getSize()
    except Exception:
        return x
    if not iw or not ih:
        return x

    luminance = _logo_luminance(logo_path)
    needs_chip = luminance is not None and luminance < 0.62
    chip = box + 3 * mm if needs_chip else box
    y = centre_y - chip / 2.0

    canv.saveState()
    if needs_chip:
        canv.setFillColor(colors.white)
        canv.roundRect(x, y, chip, chip, 2 * mm, stroke=0, fill=1)
        if chip_color is not None:
            canv.setStrokeColor(chip_color)
            canv.setLineWidth(0.7)
            canv.roundRect(x, y, chip, chip, 2 * mm, stroke=1, fill=0)
    pad = 1.4 * mm if needs_chip else 0
    limit = chip - 2 * pad
    scale = min(limit / float(iw), limit / float(ih))
    lw, lh = iw * scale, ih * scale
    try:
        canv.drawImage(logo_path, x + (chip - lw) / 2.0, y + (chip - lh) / 2.0,
                       lw, lh, mask='auto', preserveAspectRatio=True, anchor='c')
    except Exception:
        pass
    canv.restoreState()
    return x + chip + 3.5 * mm


def _logo_luminance(logo_path):
    try:
        from PIL import Image
        with Image.open(logo_path) as img:
            rgba = img.convert('RGBA')
            rgba.thumbnail((64, 64))
            total = count = 0
            for r, g, b, a in rgba.getdata():
                if a < 32:
                    continue
                total += 0.299 * r + 0.587 * g + 0.114 * b
                count += 1
            return (total / count) / 255.0 if count else None
    except Exception:
        return None


class _ReportDoc:
    """Holds the geometry and drawing helpers for one document."""

    def __init__(self, *, page_size, palette, logo_path, org, title, subtitle,
                 meta_lines, watermark, footer_left, business_name,
                 watermark_opacity=DEFAULT_WATERMARK_ALPHA):
        self.width, self.height = page_size
        self.palette = palette
        self.logo_path = logo_path
        self.org = org or {}
        self.title = title
        self.subtitle = subtitle or ''
        self.meta_lines = [m for m in (meta_lines or []) if m]
        self.watermark = (watermark or '').strip()
        try:
            alpha = float(watermark_opacity)
        except (TypeError, ValueError):
            alpha = DEFAULT_WATERMARK_ALPHA
        self.watermark_alpha = max(MIN_WATERMARK_ALPHA,
                                  min(alpha, MAX_WATERMARK_ALPHA))
        self.footer_left = footer_left or ''
        self.business_name = business_name or ''
        self.content_width = self.width - 2 * MARGIN

    # ── Watermark ───────────────────────────────────────────────────────
    def draw_watermark(self, canv):
        if not self.watermark:
            return
        canv.saveState()
        try:
            canv.setFillAlpha(self.watermark_alpha)
        except Exception:
            pass
        # A lightened brand tone: at 0.30 alpha the raw secondary would sit over
        # the table like a stain. Because the mark is drawn *behind* the story
        # the tone can be a mid-blue rather than near-white — it reads clearly
        # on print while the data on top stays crisp.
        canv.setFillColor(tint(self.palette['secondary'], 0.45))
        canv.translate(self.width / 2.0, self.height / 2.0)
        canv.rotate(42)
        size = 52
        text = self.watermark.upper()
        # Shrink until the diagonal band fits roughly across the page.
        while size > 14 and canv.stringWidth(text, 'Helvetica-Bold', size) > self.content_width * 0.92:
            size -= 3
        canv.setFont('Helvetica-Bold', size)
        canv.drawCentredString(0, -size / 3.0, text)
        canv.restoreState()

    # ── First page letterhead ──────────────────────────────────────────
    def draw_letterhead(self, canv):
        pal = self.palette
        band = pal['secondary']
        accent = pal['accent']
        ink = _readable_on(band)
        muted = tint(ink, 0.35, towards='#8a94a6' if ink == colors.white else '#ffffff')

        top = self.height - MARGIN
        band_y = top - LETTERHEAD_H
        pad = 5 * mm

        canv.saveState()
        canv.setFillColor(band)
        canv.roundRect(MARGIN, band_y, self.content_width, LETTERHEAD_H,
                       2.6 * mm, stroke=0, fill=1)
        canv.setFillColor(accent)
        canv.rect(MARGIN, band_y, self.content_width, 1.0 * mm, stroke=0, fill=1)
        canv.setFillColor(tint(accent, 0.55, towards='#ffffff'))
        canv.rect(MARGIN, band_y + 1.0 * mm, self.content_width, 0.35 * mm,
                  stroke=0, fill=1)

        mid = band_y + LETTERHEAD_H / 2.0 + 1.5 * mm
        text_x = _draw_logo(canv, MARGIN + pad, mid, 11 * mm, self.logo_path,
                            chip_color=accent)

        name = (self.org.get('name') or self.business_name or 'AdhereMed').strip()
        right_block = 62 * mm
        available = self.content_width - (text_x - MARGIN) - pad - right_block
        size = 12.5
        while size > 7 and canv.stringWidth(name, 'Helvetica-Bold', size) > available:
            size -= 0.5
        canv.setFillColor(ink)
        canv.setFont('Helvetica-Bold', size)
        canv.drawString(text_x, mid + 3.4 * mm, name)

        canv.setFillColor(muted)
        cursor = mid + 0.2 * mm
        for line in _org_detail_lines(self.org)[:2]:
            s = 7.0
            while s > 5 and canv.stringWidth(line, 'Helvetica', s) > available:
                s -= 0.3
            canv.setFont('Helvetica', s)
            canv.drawString(text_x, cursor, line)
            cursor -= 2.9 * mm

        right = self.width - MARGIN - pad
        canv.setFillColor(ink)
        canv.setFont('Helvetica-Bold', 10.5)
        canv.drawRightString(right, mid + 3.8 * mm, self.title.upper()[:52])
        canv.setFillColor(muted)
        canv.setFont('Helvetica', 7.2)
        cursor = mid + 0.6 * mm
        if self.subtitle:
            canv.drawRightString(right, cursor, self.subtitle[:64])
            cursor -= 2.8 * mm
        for line in self.meta_lines[:1]:
            canv.drawRightString(right, cursor, line[:64])
        canv.restoreState()
        return band_y - LETTERHEAD_GAP

    # ── Pages 2+ ───────────────────────────────────────────────────────
    def draw_running_header(self, canv):
        pal = self.palette
        top = self.height - MARGIN
        canv.saveState()
        canv.setFillColor(HEADER_TEXT)
        canv.setFont('Helvetica-Bold', 10.5)
        canv.drawString(MARGIN, top - 4 * mm, self.title)
        canv.setFillColor(MUTED_TEXT)
        canv.setFont('Helvetica', 7.4)
        canv.drawRightString(self.width - MARGIN, top - 4 * mm,
                             self.business_name or '')
        canv.setStrokeColor(pal['primary'])
        canv.setLineWidth(0.8)
        canv.line(MARGIN, top - 6.4 * mm, self.width - MARGIN, top - 6.4 * mm)
        canv.restoreState()

    # ── Footer (page x of y is added by _NumberedCanvas) ───────────────
    def _fit(self, canv, text, font, size, max_width):
        """Truncate ``text`` with an ellipsis so it cannot run into a neighbour."""
        text = str(text or '')
        if canv.stringWidth(text, font, size) <= max_width:
            return text
        while text and canv.stringWidth(text + '…', font, size) > max_width:
            text = text[:-1]
        return (text + '…') if text else ''

    def draw_footer(self, canv, page, total):
        """Tenant line left, product credit centred, page counter right.

        The three zones are laid out by hand rather than with
        ``drawCentredString`` because the credit block needs its exact
        x-extent, and the tenant line is measured and truncated so a long
        business name can never overlap it on a portrait page.

        NB: no ``linkURL`` here. The footer is drawn from
        ``_NumberedCanvas.save()``, which runs *after* the document has been
        laid out; registering an annotation at that point appends a new PDF
        object and reportlab raises
        ``ValueError: counter N doesn't match number to id dictionary``. The
        address is therefore underlined rather than hyperlinked.
        """
        canv.saveState()
        canv.setStrokeColor(BORDER)
        canv.setLineWidth(0.6)
        canv.line(MARGIN, MARGIN + 4 * mm, self.width - MARGIN, MARGIN + 4 * mm)

        baseline = MARGIN + 1.2 * mm
        centre = self.width / 2.0

        # ── Centre: "Powered by AdhereMed · www.adheremed.co" ───────────
        size = 6.4
        sep = '   ·   '
        w_credit = canv.stringWidth(f'Powered by {CREDIT_BRAND}', 'Helvetica', size)
        w_sep = canv.stringWidth(sep, 'Helvetica', size)
        w_site = canv.stringWidth(CREDIT_SITE, 'Helvetica', size)
        block = w_credit + w_sep + w_site
        credit_x = centre - block / 2.0

        canv.setFillColor(MUTED_TEXT)
        canv.setFont('Helvetica', size)
        canv.drawString(credit_x, baseline, f'Powered by {CREDIT_BRAND}')
        canv.drawString(credit_x + w_credit, baseline, sep)

        # Brand tone + hairline rule so the address reads as a link on paper.
        canv.setFillColor(self.palette['primary'])
        site_x = credit_x + w_credit + w_sep
        canv.drawString(site_x, baseline, CREDIT_SITE)
        canv.setStrokeColor(self.palette['primary'])
        canv.setLineWidth(0.3)
        canv.line(site_x, baseline - 0.9, site_x + w_site, baseline - 0.9)

        # ── Left: tenant / report label, clipped to the free space ──────
        free_left = (centre - block / 2.0) - MARGIN - 6
        canv.setFillColor(MUTED_TEXT)
        canv.setFont('Helvetica', 6.8)
        canv.drawString(MARGIN, baseline,
                        self._fit(canv, self.footer_left, 'Helvetica', 6.8,
                                  max(free_left, 40)))

        # ── Right: page counter ────────────────────────────────────────
        canv.drawRightString(self.width - MARGIN, baseline,
                             f'Page {page} of {total}')
        canv.restoreState()


class _NumberedCanvas(pdf_canvas.Canvas):
    """Canvas that knows the total page count, so the footer can say 'of N'."""

    def __init__(self, *args, **kwargs):
        # NB: ``Canvas.__init__`` assigns ``self._doc`` (the PDFDocument), so the
        # renderer context must live on a differently-named attribute or it is
        # silently replaced and the footer explodes.
        report_doc = kwargs.pop('report_doc', None)
        self._defer = []
        super().__init__(*args, **kwargs)
        self._report_doc = report_doc

    def showPage(self):
        self._defer.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        total = len(self._defer)
        for index, state in enumerate(self._defer, start=1):
            self.__dict__.update(state)
            renderer = getattr(self, '_report_doc', None)
            if renderer is not None:
                renderer.draw_footer(self, index, total)
            super().showPage()
        super().save()


# ── Charts ──────────────────────────────────────────────────────────────
def _cut(text, limit):
    """Truncate with an ellipsis — chart labels have no room to wrap."""
    text = str(text or '')
    return text if len(text) <= limit else text[:limit - 1] + '…'


class _ChartPanel(Flowable):
    """One chart card: brand rule, title, subtitle and the plotted marks.

    Drawn with raw canvas primitives rather than ``reportlab.graphics.charts``:
    the chart package's ``Pie``/``Legend`` imports are easy to get wrong and the
    panels here sit inside a table cell, where a Drawing's fixed size fights the
    layout. Hand-drawn marks always fill the card exactly.
    """

    def __init__(self, chart, width, height, palette):
        super().__init__()
        self.chart = chart
        self.width = width
        self.height = height
        self.palette = palette

    def wrap(self, available_width, available_height):
        return self.width, self.height

    def _color(self, index):
        pal = self.palette
        base = [pal['primary'], pal['secondary'], pal['accent']]
        colour = base[index % len(base)]
        # Lighten each repeat of the cycle so neighbouring marks separate.
        return tint(colour, min(0.55, 0.14 * (index // len(base))))

    def draw(self):
        c = self.canv
        w, h = self.width, self.height
        c.saveState()

        c.setFillColor(colors.white)
        c.setStrokeColor(BORDER)
        c.setLineWidth(0.5)
        c.roundRect(0, 0, w, h, 6, stroke=1, fill=1)
        c.setFillColor(self.palette['primary'])
        c.roundRect(0, h - 2.2, w, 2.2, 1.1, stroke=0, fill=1)

        c.setFillColor(HEADER_TEXT)
        c.setFont('Helvetica-Bold', 8)
        c.drawString(7, h - 15, _cut(self.chart.get('title'), 46))
        c.setFillColor(MUTED_TEXT)
        c.setFont('Helvetica', 6.2)
        c.drawString(7, h - 24, _cut(self.chart.get('subtitle'), 62))

        points = [p for p in (self.chart.get('points') or []) if p]
        if not points:
            c.restoreState()
            return

        left, bottom = 8, 14
        box_w = w - left - 8
        box_h = h - 34 - bottom
        kind = self.chart.get('kind')
        if kind == 'donut':
            self._donut(c, points, left, bottom, box_w, box_h)
        elif kind == 'line':
            self._line(c, points, left, bottom, box_w, box_h)
        else:
            self._bars(c, points, left, bottom, box_w, box_h)
        c.restoreState()

    def _bars(self, c, points, x, y, w, h):
        peak = max([p['value'] for p in points] + [1])
        slot = w / max(len(points), 1)
        bar_w = min(slot * 0.6, 34)
        label_band = 11      # category names under the bars
        value_band = 9       # figures above the tallest bar
        plot_h = max(h - label_band - value_band, 6)
        for i, point in enumerate(points):
            bar_h = (point['value'] / peak) * plot_h
            bx = x + i * slot + (slot - bar_w) / 2
            c.setFillColor(self._color(i))
            c.roundRect(bx, y + label_band, bar_w, max(bar_h, 1.2), 2,
                        stroke=0, fill=1)
            c.setFillColor(MUTED_TEXT)
            c.setFont('Helvetica', 5.0)
            c.drawCentredString(bx + bar_w / 2, y + label_band + bar_h + 2,
                                _cut(point.get('display') or '', 15))
            c.drawCentredString(bx + bar_w / 2, y + 2,
                                _cut(point.get('label'), 14))

    def _donut(self, c, points, x, y, w, h):
        total = sum(p['value'] for p in points) or 1
        size = min(h, w * 0.46)
        cx = x + size / 2 + 2
        cy = y + h / 2
        radius = max(size / 2 - 3, 4)
        c.setLineWidth(min(10, radius * 0.42))
        angle = 90.0
        for i, point in enumerate(points):
            extent = -360.0 * (point['value'] / total)
            # ``bezierArc`` divides by sin(extent/2): a full circle or a
            # hairline slice both blow up, so both are handled explicitly.
            if abs(extent) < 0.4:
                continue
            c.setStrokeColor(self._color(i))
            if abs(extent) >= 359.4:
                c.circle(cx, cy, radius, stroke=1, fill=0)
                angle += extent
                continue
            # ``Canvas.arc`` only appends to the current path — it needs an
            # explicit path object to stroke (there is no ``Canvas.stroke``).
            arc = c.beginPath()
            arc.arc(cx - radius, cy - radius, cx + radius, cy + radius,
                    angle, extent)
            c.drawPath(arc, stroke=1, fill=0)
            angle += extent

        # Legend to the right of the ring.
        legend_x = x + size + 12
        row_y = y + h - 4
        for i, point in enumerate(points[:7]):
            share = 100.0 * point['value'] / total
            c.setFillColor(self._color(i))
            c.circle(legend_x + 2, row_y + 2, 2.1, stroke=0, fill=1)
            c.setFillColor(HEADER_TEXT)
            c.setFont('Helvetica', 5.8)
            c.drawString(legend_x + 7, row_y,
                         _cut(point.get('label'), 22))
            c.setFillColor(MUTED_TEXT)
            c.setFont('Helvetica', 5.4)
            c.drawRightString(x + w, row_y, f'{share:.0f}%')
            row_y -= 8.4

    def _line(self, c, points, x, y, w, h):
        values = [p['value'] for p in points]
        top, low = max(values), min(values)
        span = (top - low) or (top or 1)
        step = w / max(len(points) - 1, 1)
        base = y + 10
        coords = [(x + i * step,
                   base + ((value - low) / span) * max(h - 20, 6))
                  for i, value in enumerate(values)]

        area = c.beginPath()
        area.moveTo(coords[0][0], base)
        for px, py in coords:
            area.lineTo(px, py)
        area.lineTo(coords[-1][0], base)
        area.close()
        c.setFillColor(tint(self.palette['primary'], 0.86))
        c.drawPath(area, stroke=0, fill=1)

        line = c.beginPath()
        line.moveTo(*coords[0])
        for px, py in coords[1:]:
            line.lineTo(px, py)
        c.setStrokeColor(self.palette['primary'])
        c.setLineWidth(1.6)
        c.drawPath(line, stroke=1, fill=0)

        for i, (px, py) in enumerate(coords):
            c.setFillColor(self.palette['primary'])
            c.circle(px, py, 1.8, stroke=0, fill=1)
            c.setFillColor(MUTED_TEXT)
            c.setFont('Helvetica', 5.0)
            c.drawCentredString(px, y + 1, _cut(points[i]['label'], 9))


def _charts_block(doc, charts, palette):
    """Chart cards laid out two-up, 46 mm tall."""
    charts = [c for c in (charts or []) if c.get('points')]
    if not charts:
        return None
    gap = 4 * mm
    column = (doc.content_width - gap) / 2
    height = 46 * mm

    rows = []
    for start in range(0, min(len(charts), 4), 2):
        chunk = charts[start:start + 2]
        panels = [_ChartPanel(chart, column, height, palette) for chart in chunk]
        while len(panels) < 2:
            panels.append('')
        rows.append([panels[0], '', panels[1]])

    table = Table(rows, colWidths=[column, gap, column], hAlign='LEFT')
    table.setStyle(TableStyle([
        ('LEFTPADDING', (0, 0), (-1, -1), 0),
        ('RIGHTPADDING', (0, 0), (-1, -1), 0),
        ('TOPPADDING', (0, 0), (-1, -1), 0),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 3 * mm),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    return table


# ── Story builders ──────────────────────────────────────────────────────
def _styles(palette):
    head = ParagraphStyle('head', fontName='Helvetica-Bold', fontSize=6.6,
                          textColor=colors.white, leading=8.2,
                          alignment=TA_LEFT)
    return {
        'head': head,
        'cell': ParagraphStyle('cell', fontName='Helvetica', fontSize=7.0,
                               textColor=HEADER_TEXT, leading=9.0),
        'caps': ParagraphStyle('caps', fontName='Helvetica-Bold', fontSize=6.2,
                               textColor=MUTED_TEXT, leading=8.0),
        'value': ParagraphStyle('value', fontName='Helvetica-Bold', fontSize=12,
                                textColor=palette['secondary'], leading=14),
        'note': ParagraphStyle('note', fontName='Helvetica-Oblique', fontSize=6.8,
                               textColor=MUTED_TEXT, leading=9.0),
        'h': ParagraphStyle('h', fontName='Helvetica-Bold', fontSize=9,
                            textColor=HEADER_TEXT, leading=11),
    }


def _summary_band(doc, summaries, palette, styles):
    """Row of bordered KPI tiles above the table."""
    tiles = [
        [Paragraph(str(item['label']).upper(), styles['caps']),
         Paragraph(str(item['value']), styles['value'])]
        for item in summaries
    ]
    if not tiles:
        return None
    gap = 4 * mm
    count = len(tiles)
    width = (doc.content_width - gap * (count - 1)) / count
    row, widths = [], []
    for i, tile in enumerate(tiles):
        row.append(tile)
        widths.append(width)
        if i < count - 1:
            row.append('')
            widths.append(gap)
    table = Table([row], colWidths=widths, hAlign='LEFT')
    edge = tint(palette['primary'], 0.72)
    style = [
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 0),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ('LEFTPADDING', (0, 0), (-1, -1), 0),
        ('RIGHTPADDING', (0, 0), (-1, -1), 0),
    ]
    # Each tile gets its own box + brand tint so the figures never blur into
    # one long strip; the spacer columns stay transparent.
    tile_indexes = [i for i in range(0, len(row), 2)]
    for idx in tile_indexes:
        style += [
            ('BACKGROUND', (idx, 0), (idx, 0), tint(palette['primary'], 0.94)),
            ('BOX', (idx, 0), (idx, 0), 0.5, edge),
            ('LINEABOVE', (idx, 0), (idx, 0), 1.6, palette['primary']),
            ('LEFTPADDING', (idx, 0), (idx, 0), 6),
            ('RIGHTPADDING', (idx, 0), (idx, 0), 6),
            ('TOPPADDING', (idx, 0), (idx, 0), 5),
            ('BOTTOMPADDING', (idx, 0), (idx, 0), 5),
        ]
    table.setStyle(TableStyle(style))
    return table


def _breakdown_table(doc, breakdown, palette, styles):
    if not breakdown:
        return None
    label = Paragraph(str(breakdown.get('label') or 'Breakdown'), styles['h'])
    head = ParagraphStyle('bh', parent=styles['head'], alignment=TA_LEFT)
    head_r = ParagraphStyle('bhr', parent=styles['head'], alignment=TA_RIGHT)
    head_c = ParagraphStyle('bhc', parent=styles['head'], alignment=TA_CENTER)
    num_cell = ParagraphStyle('numb', parent=styles['cell'], alignment=TA_CENTER)
    rows = [[
        Paragraph('#', head_c),
        Paragraph(str(breakdown.get('dimension') or 'Group').upper(), head),
        Paragraph('LINES', head_r),
        Paragraph('VALUE', head_r),
    ]]
    for index, item in enumerate(breakdown.get('items', [])[:24], start=1):
        right = ParagraphStyle('r', parent=styles['cell'], alignment=TA_RIGHT)
        rows.append([
            Paragraph(str(index), num_cell),
            Paragraph(str(item.get('label') or '—'), styles['cell']),
            Paragraph(f"{int(item.get('count') or 0):,}", right),
            Paragraph(str(item.get('value') or '—'), right),
        ])
    gutter = ROW_NUMBER_W
    span = doc.content_width - gutter
    table = Table(rows, colWidths=[gutter, span * 0.56, span * 0.16, span * 0.28],
                  hAlign='LEFT', repeatRows=1)
    table.setStyle(TableStyle([
        # Same header treatment as the detail table — white on brand, not grey
        # on a pale tint (which printed as near-invisible).
        ('BACKGROUND', (0, 0), (-1, 0), palette['secondary']),
        ('TEXTCOLOR', (0, 0), (-1, 0), _readable_on(palette['secondary'])),
        ('LINEBELOW', (0, 0), (-1, 0), 0.6, palette['accent']),
        ('GRID', (0, 0), (-1, -1), 0.25, BORDER),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 2.6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 2.6),
        ('LEFTPADDING', (0, 0), (-1, -1), 3),
        ('RIGHTPADDING', (0, 0), (-1, -1), 3),
        ('LEFTPADDING', (0, 0), (0, -1), 1),
        ('RIGHTPADDING', (0, 0), (0, -1), 1),
    ]))
    return KeepTogether([label, Spacer(1, 2 * mm), table, Spacer(1, 4 * mm)])


def _detail_table(doc, columns, rows, palette, styles, totals=None):
    """The main data table: numbered rows, repeated header, zebra stripes.

    The row number is baked into the flowable at build time, so it keeps
    counting straight through a page break instead of restarting at 1 on every
    page the table spills onto.
    """
    head_style = styles['head']
    # The gutter is a fixed width and stays out of the weight calculation, so
    # adding it does not squeeze a twelve-column sheet.
    number_w = ROW_NUMBER_W
    num_head = ParagraphStyle('h_num', parent=head_style, alignment=TA_CENTER)
    num_cell = ParagraphStyle('c_num', parent=styles['cell'], alignment=TA_CENTER)
    num_total = ParagraphStyle('t_num', parent=styles['cell'],
                               fontName='Helvetica-Bold', alignment=TA_CENTER)

    header_cells = [Paragraph('#', num_head)]
    for col in columns:
        style = ParagraphStyle(f"h_{col['key']}", parent=head_style,
                               alignment=_TYPE_ALIGN.get(col['type'], TA_LEFT))
        header_cells.append(Paragraph(str(col['label']).upper(), style))

    body = [header_cells]
    for index, row in enumerate(rows, start=1):
        line = [Paragraph(str(index), num_cell)]
        for col in columns:
            style = ParagraphStyle(
                f"c_{col['key']}", parent=styles['cell'],
                alignment=_TYPE_ALIGN.get(col['type'], TA_LEFT),
            )
            text = format_value(row.get(col['key']), col['type'])
            line.append(Paragraph(text, style))
        body.append(line)

    if totals:
        # The gutter stays blank on the totals row so the label can carry the
        # first data column and the figures still line up under their own
        # headers. When the caller kept only *one* column there is no spare
        # column for the label — putting it there printed "TOTAL" instead of
        # the total — so it moves into the gutter cell.
        single = len(columns) == 1
        line = [Paragraph('TOTAL' if single else '', num_total)]
        for index, col in enumerate(columns):
            style = ParagraphStyle(
                f"t_{col['key']}", parent=styles['cell'],
                fontName='Helvetica-Bold',
                alignment=_TYPE_ALIGN.get(col['type'], TA_LEFT),
            )
            if index == 0 and not single:
                text = 'TOTAL'
            else:
                text = format_value(totals.get(col['key']), col['type'])
            line.append(Paragraph(text, style))
        body.append(line)

    weights = sum(float(c.get('width') or 1) for c in columns) or 1.0
    data_width = max(doc.content_width - number_w, number_w * 2)
    widths = [number_w] + [data_width * (float(c.get('width') or 1) / weights)
                           for c in columns]

    table = Table(body, colWidths=widths, repeatRows=1, hAlign='LEFT')
    style = [
        ('BACKGROUND', (0, 0), (-1, 0), palette['secondary']),
        ('TEXTCOLOR', (0, 0), (-1, 0), _readable_on(palette['secondary'])),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('LINEBELOW', (0, 0), (-1, 0), 0.6, palette['accent']),
        ('GRID', (0, 0), (-1, -1), 0.25, BORDER),
        ('TOPPADDING', (0, 0), (-1, -1), 2.6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 2.6),
        ('LEFTPADDING', (0, 0), (-1, -1), 3),
        ('RIGHTPADDING', (0, 0), (-1, -1), 3),
        # Tighter gutter so the digits sit centred in a narrow column.
        ('LEFTPADDING', (0, 1), (0, -1), 1),
        ('RIGHTPADDING', (0, 1), (0, -1), 1),
    ]
    stripe = tint(palette['primary'], 0.945)
    for i in range(1, len(body)):
        if i % 2 == 0:
            style.append(('BACKGROUND', (0, i), (-1, i), stripe))
    if totals:
        style.append(('BACKGROUND', (0, len(body) - 1), (-1, len(body) - 1),
                      tint(palette['primary'], 0.84)))
        style.append(('LINEABOVE', (0, len(body) - 1), (-1, len(body) - 1),
                      0.6, palette['primary']))
    table.setStyle(TableStyle(style))
    return table


# ── Public entry point ──────────────────────────────────────────────────
def render_report_pdf(*, columns, rows, totals=None, meta=None, title,
                      subtitle='', org=None, logo_path=None, palette=None,
                      business_name='', watermark='', notes='',
                      watermark_opacity=DEFAULT_WATERMARK_ALPHA,
                      orientation='landscape', include_summary=True,
                      include_breakdown=True, include_totals=True,
                      include_columns_note=True, summaries=None,
                      breakdown=None, charts=None, currency='KES') -> bytes:
    """Render a report payload to PDF bytes."""
    palette = palette or resolve_palette(None)
    page_size = landscape(A4) if orientation == 'landscape' else A4

    generated = timezone.localtime(timezone.now()).strftime('%d %b %Y, %H:%M')
    meta_lines = [m for m in (meta or {}).get('lines', []) if m]
    if not meta_lines:
        meta_lines = [f'Generated {generated}']
    if include_columns_note:
        meta_lines.append(f'{len(columns)} columns · {len(rows):,} rows')

    doc = _ReportDoc(
        page_size=page_size, palette=palette, logo_path=logo_path, org=org,
        title=title, subtitle=subtitle, meta_lines=meta_lines,
        watermark=watermark, business_name=business_name,
        watermark_opacity=watermark_opacity,
        footer_left=(business_name or 'AdhereMed') + ' · Inventory report',
    )
    styles = _styles(palette)

    buf = io.BytesIO()
    template = SimpleDocTemplate(
        buf, pagesize=page_size,
        leftMargin=MARGIN, rightMargin=MARGIN,
        topMargin=LETTERHEAD_H + MARGIN + 2 * mm, bottomMargin=MARGIN + 8 * mm,
        title=title, author=business_name or 'AdhereMed',
        subject=subtitle or title,
    )

    first_page = {'done': False}

    def _on_first(canv, _doc):
        # Background layer: painted before the letterhead and the story, so the
        # data always sits on top of the mark and stays fully legible. It is
        # still visible across the detail table because reportlab leaves body
        # cells unfilled — only the header, zebra stripes and KPI tiles are
        # opaque.
        doc.draw_watermark(canv)
        doc.draw_letterhead(canv)
        first_page['done'] = True

    def _on_later(canv, _doc):
        doc.draw_watermark(canv)
        doc.draw_running_header(canv)

    flow = []
    if include_summary and summaries:
        band = _summary_band(doc, summaries, palette, styles)
        if band is not None:
            flow += [band, Spacer(1, 4 * mm)]

    if charts:
        block = _charts_block(doc, charts, palette)
        if block is not None:
            flow += [block, Spacer(1, 1 * mm)]

    if include_breakdown and breakdown:
        table = _breakdown_table(doc, breakdown, palette, styles)
        if table is not None:
            flow.append(table)

    if rows:
        flow.append(_detail_table(doc, columns, rows, palette, styles,
                                  totals=totals if include_totals else None))
    else:
        flow.append(Paragraph('No records match the selected filters.', styles['note']))

    if notes:
        flow += [Spacer(1, 3 * mm),
                 Paragraph(str(notes).replace('\n', '<br/>'), styles['note'])]

    flow += [Spacer(1, 2 * mm),
             Paragraph(f'Generated {generated} · {business_name or "AdhereMed"}',
                       styles['note'])]

    template.build(
        flow,
        onFirstPage=_on_first,
        onLaterPages=_on_later,
        canvasmaker=lambda *a, **kw: _NumberedCanvas(*a, report_doc=doc, **kw),
    )
    return buf.getvalue()
