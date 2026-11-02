"""Premium PDF renderer for the Business-Intelligence report.

Deliberately different from :mod:`inventory.reports.render` (which renders
*tabular* sheets): this produces a **document** - a branded cover, contents,
numbered sections, chart cards, insight call-outs and only then the supporting
tables. It is portrait A4 because it reads like a board pack rather than a
spreadsheet print-out.

Layout, per page:

* cover page   - full-bleed gradient, logo, title, period, contents list
* section page - numbered brand tab, KPI grid / chart cards / tables
* every page   - diagonal watermark (background) and the product footer
"""
from __future__ import annotations

import io

from django.utils import timezone
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import (BaseDocTemplate, Flowable, Frame, KeepTogether,
                                NextPageTemplate, PageBreak, PageTemplate,
                                Paragraph, Spacer, Table, TableStyle)

from config.pdf_branding import resolve_palette, tint

from .bi import SECTIONS_BY_ID
from .render import (BORDER, CREDIT_BRAND, CREDIT_SITE, HEADER_TEXT, MUTED_TEXT,
                     _draw_logo, _org_detail_lines, _readable_on,
                     _NumberedCanvas)

PAGE = A4
MARGIN = 15 * mm
CONTENT_W = PAGE[0] - 2 * MARGIN

BODY = colors.HexColor('#1E293B')
SOFT = colors.HexColor('#475569')


# ----- Formatting -------------------------------------------------------------------------------------------------------------------------------------------------
def money(value, currency='KES'):
    try:
        return f'{currency} {float(value or 0):,.2f}'
    except (TypeError, ValueError):
        return '-'


def compact(value):
    """Axis / label shortening: 1.2M, 34K, 512."""
    try:
        number = float(value or 0)
    except (TypeError, ValueError):
        return '-'
    sign = '-' if number < 0 else ''
    number = abs(number)
    if number >= 1e6:
        return f'{sign}{number / 1e6:.1f}M'
    if number >= 1e3:
        return f'{sign}{number / 1e3:.0f}K'
    return f'{sign}{number:.0f}'


def count(value):
    try:
        return f'{int(round(float(value or 0))):,}'
    except (TypeError, ValueError):
        return '-'


def _clip(canv, text, font, size, max_w):
    """Trim ``text`` to ``max_w`` points on a word boundary, adding an ellipsis.

    A bare ``text[:46]`` slice cuts mid-word ("...of what") and looks like a
    rendering bug, so measure with the real font metrics instead.
    """
    text = ' '.join(str(text or '').split())
    if not text:
        return ''
    if canv.stringWidth(text, font, size) <= max_w:
        return text
    ell = '...'
    budget = max_w - canv.stringWidth(ell, font, size)
    if budget <= 0:
        return ell
    words = text.split(' ')
    out = ''
    for word in words:
        candidate = word if not out else out + ' ' + word
        if canv.stringWidth(candidate, font, size) > budget:
            break
        out = candidate
    if not out:
        # Single long token - fall back to a character-wise trim.
        out = text
        while out and canv.stringWidth(out, font, size) > budget:
            out = out[:-1]
    return out.rstrip(' ,;:.') + ell



# ----- Styles -----------------------------------------------------------------------------------------------------------------------------------------------------------
def _styles():
    return {
        'h1': ParagraphStyle('h1', fontName='Helvetica-Bold', fontSize=20,
                             leading=24, textColor=HEADER_TEXT),
        'h2': ParagraphStyle('h2', fontName='Helvetica-Bold', fontSize=12.5,
                             leading=15.5, textColor=HEADER_TEXT),
        'h3': ParagraphStyle('h3', fontName='Helvetica-Bold', fontSize=9,
                             leading=12, textColor=HEADER_TEXT),
        'body': ParagraphStyle('body', fontName='Helvetica', fontSize=8.6,
                               leading=12.4, textColor=BODY),
        'body_b': ParagraphStyle('body_b', fontName='Helvetica-Bold',
                                 fontSize=8.6, leading=12.4, textColor=HEADER_TEXT),
        'small': ParagraphStyle('small', fontName='Helvetica', fontSize=7.4,
                                leading=10, textColor=SOFT),
        'caps': ParagraphStyle('caps', fontName='Helvetica-Bold', fontSize=6.4,
                               leading=8.4, textColor=MUTED_TEXT),
        'label': ParagraphStyle('label', fontName='Helvetica-Bold', fontSize=7.2,
                                leading=9.4, textColor=MUTED_TEXT),
        'value': ParagraphStyle('value', fontName='Helvetica-Bold', fontSize=12.6,
                                leading=15, textColor=HEADER_TEXT),
        'cell': ParagraphStyle('cell', fontName='Helvetica', fontSize=7.4,
                               leading=9.6, textColor=BODY),
        'cell_r': ParagraphStyle('cell_r', fontName='Helvetica', fontSize=7.4,
                                 leading=9.6, textColor=BODY, alignment=TA_RIGHT),
        'cell_c': ParagraphStyle('cell_c', fontName='Helvetica', fontSize=7.4,
                                 leading=9.6, textColor=BODY, alignment=TA_CENTER),
        'head': ParagraphStyle('head', fontName='Helvetica-Bold', fontSize=6.4,
                               leading=8.2, textColor=colors.white),
        'head_r': ParagraphStyle('head_r', fontName='Helvetica-Bold', fontSize=6.4,
                                 leading=8.2, textColor=colors.white,
                                 alignment=TA_RIGHT),
        'head_c': ParagraphStyle('head_c', fontName='Helvetica-Bold', fontSize=6.4,
                                 leading=8.2, textColor=colors.white,
                                 alignment=TA_CENTER),
    }


# ----- Page furniture ---------------------------------------------------------------------------------------------------------------------------------------
class _BiDoc:
    """Geometry + page furniture for the BI pack."""

    def __init__(self, *, palette, org, logo_path, business_name, title,
                 subtitle, watermark, watermark_opacity=0.30):
        self.palette = palette
        self.org = org or {}
        self.logo_path = logo_path
        self.business_name = business_name or 'AdhereMed'
        self.title = title
        self.subtitle = subtitle or ''
        self.watermark = (watermark or '').strip()
        self.watermark_alpha = watermark_opacity

    # ----- Watermark (background layer) ------------------------------------------------------------------------------------------
    def draw_watermark(self, canv, page_size=PAGE):
        if not self.watermark:
            return
        width, height = page_size
        canv.saveState()
        try:
            canv.setFillAlpha(self.watermark_alpha)
        except Exception:
            pass
        canv.setFillColor(tint(self.palette['secondary'], 0.45))
        canv.translate(width / 2.0, height / 2.0)
        canv.rotate(42)
        size = 46
        text = self.watermark.upper()
        while size > 14 and canv.stringWidth(text, 'Helvetica-Bold', size) > CONTENT_W * 0.92:
            size -= 3
        canv.setFont('Helvetica-Bold', size)
        canv.drawCentredString(0, -size / 3.0, text)
        canv.restoreState()

    # ----- Cover page ---------------------------------------------------------------------------------------------------------------------------------------
    def draw_cover(self, canv, sections, dataset):
        pal = self.palette
        width, height = PAGE
        ink = colors.white

        canv.saveState()
        # Full-bleed brand gradient, built from stacked translucent bands so it
        # needs no image support and prints identically everywhere.
        canv.setFillColor(pal['secondary'])
        canv.rect(0, height * 0.42, width, height * 0.58, stroke=0, fill=1)
        canv.setFillColor(pal['primary'])
        canv.rect(0, height * 0.52, width, height * 0.30, stroke=0, fill=1)
        canv.setFillColor(tint(pal['primary'], 0.30))
        canv.rect(0, height * 0.62, width, height * 0.10, stroke=0, fill=1)
        canv.setFillColor(pal['accent'])
        canv.rect(0, height * 0.415, width, 1.6 * mm, stroke=0, fill=1)

        # Logo on a white chip so dark artwork stays visible.
        logo_x = MARGIN
        top = height - MARGIN - 6 * mm
        box = 15 * mm
        drawn_to = _draw_logo(canv, logo_x, top - box / 2, box,
                              self.logo_path, chip_color=colors.white)
        canv.setFillColor(ink)
        canv.setFont('Helvetica-Bold', 11)
        canv.drawString(max(drawn_to, logo_x + box) + 4 * mm, top - 4.4 * mm,
                        self.business_name[:44])

        # Eyebrow + title
        canv.setFillColor(tint(ink, 0.28))
        canv.setFont('Helvetica-Bold', 8.4)
        canv.drawString(MARGIN, height * 0.60, 'BUSINESS INTELLIGENCE')

        canv.setFillColor(ink)
        canv.setFont('Helvetica-Bold', 30)
        canv.drawString(MARGIN, height * 0.545, 'Performance Report')

        canv.setFillColor(tint(ink, 0.22))
        canv.setFont('Helvetica', 10.4)
        subtitles = dataset['scope']
        y = height * 0.505
        for line in subtitles[:3]:
            canv.drawString(MARGIN, y, line)
            y -= 5 * mm

        # Cover KPI ribbon - only the four headline measures.
        headline = [k for k in dataset['kpis']
                    if k['id'] in ('revenue', 'orders', 'aov', 'units')][:4]
        if headline:
            ribbon_y = height * 0.335
            gap = 4 * mm
            tile_w = (CONTENT_W - gap * (len(headline) - 1)) / len(headline)
            for index, kpi in enumerate(headline):
                x = MARGIN + index * (tile_w + gap)
                canv.setFillColor(tint(pal['secondary'], 0.12))
                canv.setStrokeColor(tint(ink, 0.30))
                canv.setLineWidth(0.4)
                canv.roundRect(x, ribbon_y, tile_w, 20 * mm, 2.4 * mm,
                               stroke=1, fill=1)
                canv.setFillColor(tint(ink, 0.42))
                canv.setFont('Helvetica-Bold', 6.2)
                canv.drawString(x + 4 * mm, ribbon_y + 14.4 * mm,
                                str(kpi['label']).upper()[:26])
                canv.setFillColor(ink)
                canv.setFont('Helvetica-Bold', 12)
                canv.drawString(x + 4 * mm, ribbon_y + 7.4 * mm,
                                str(kpi['value'])[:22])
                canv.setFillColor(tint(ink, 0.40))
                canv.setFont('Helvetica', 5.8)
                canv.drawString(x + 4 * mm, ribbon_y + 3.4 * mm,
                                str(kpi.get('hint') or '')[:30])

        # Contents. The column count and the row pitch both adapt to how many
        # sections survived, so a two-section brief and a fourteen-section board
        # pack are each laid out deliberately instead of one of them overflowing
        # into the confidential strip.
        y = height * 0.265
        canv.setFillColor(pal['secondary'])
        canv.setFont('Helvetica-Bold', 7.4)
        canv.drawString(MARGIN, y, 'CONTENTS')
        canv.setStrokeColor(tint(pal['primary'], 0.65))
        canv.setLineWidth(0.5)
        canv.line(MARGIN, y - 2.2 * mm, width - MARGIN, y - 2.2 * mm)

        entries = list(sections)
        total = len(entries)
        columns = 1 if total <= 5 else 2 if total <= 10 else 3
        per_column = -(-total // columns)          # ceiling division
        gap = (6 * mm) if columns == 3 else (8 * mm)
        column_w = (CONTENT_W - gap * (columns - 1)) / columns

        top = y - 10 * mm
        floor = MARGIN + 12 * mm                  # stay clear of the strip
        pitch = min(11.2 * mm, (top - floor) / max(per_column, 1))
        label_size = 8 if columns < 3 else 6.8
        desc_size = 6.4 if columns < 3 else 5.4

        for index, section in enumerate(entries):
            column, slot = divmod(index, per_column)
            x = MARGIN + column * (column_w + gap)
            row_y = top - slot * pitch
            canv.setFillColor(pal['primary'])
            canv.setFont('Helvetica-Bold', 7.6)
            canv.drawString(x, row_y, f'{index + 1:02d}')
            avail = column_w - 6 * mm
            canv.setFillColor(BODY)
            canv.setFont('Helvetica-Bold', label_size)
            canv.drawString(x + 6.4 * mm, row_y,
                            _clip(canv, section['label'], 'Helvetica-Bold',
                                  label_size, avail))
            canv.setFillColor(MUTED_TEXT)
            canv.setFont('Helvetica', desc_size)
            canv.drawString(x + 6.4 * mm, row_y - (pitch * 0.32),
                            _clip(canv, section['description'], 'Helvetica',
                                  desc_size, avail))

        # Confidential strip at the very bottom.
        canv.setFillColor(tint(pal['primary'], 0.94))
        canv.rect(MARGIN, MARGIN, CONTENT_W, 7 * mm, stroke=0, fill=1)
        canv.setFillColor(pal['secondary'])
        canv.setFont('Helvetica-Bold', 6.4)
        canv.drawString(MARGIN + 3 * mm, MARGIN + 2.6 * mm,
                        'CONFIDENTIAL * for internal distribution only')
        canv.drawRightString(width - MARGIN - 3 * mm, MARGIN + 2.6 * mm,
                             timezone.localtime(timezone.now()).strftime('%d %b %Y, %H:%M'))
        canv.restoreState()

    # ----- Section page header ---------------------------------------------------------------------------------------------------------------
    def draw_section_header(self, canv, number, section):
        pal = self.palette
        width, height = PAGE
        top = height - MARGIN
        canv.saveState()
        canv.setFillColor(pal['primary'])
        canv.rect(MARGIN, top - 11 * mm, CONTENT_W, 11 * mm, stroke=0, fill=1)
        canv.setFillColor(colors.white)
        canv.setFont('Helvetica-Bold', 13)
        canv.drawString(MARGIN + 4 * mm, top - 7.6 * mm, f'{number:02d}')
        canv.setStrokeColor(tint(colors.white, 0.55))
        canv.setLineWidth(0.5)
        canv.line(MARGIN + 15 * mm, top - 3 * mm, MARGIN + 15 * mm, top - 8.6 * mm)
        canv.setFont('Helvetica-Bold', 10.4)
        canv.drawString(MARGIN + 18 * mm, top - 7.2 * mm, section['label'])
        canv.setFillColor(tint(colors.white, 0.30))
        canv.setFont('Helvetica', 7)
        label_w = canv.stringWidth(section['label'], 'Helvetica-Bold', 10.4)
        desc_w = (width - MARGIN - 4 * mm) - (MARGIN + 18 * mm + label_w + 6 * mm)
        canv.drawRightString(width - MARGIN - 4 * mm, top - 7.2 * mm,
                             _clip(canv, section['description'], 'Helvetica', 7, desc_w))
        canv.restoreState()

    def draw_running_header(self, canv):
        pal = self.palette
        width, height = PAGE
        top = height - MARGIN + 4 * mm
        canv.saveState()
        canv.setFillColor(HEADER_TEXT)
        canv.setFont('Helvetica-Bold', 8)
        canv.drawString(MARGIN, top, self.title)
        canv.setFillColor(MUTED_TEXT)
        canv.setFont('Helvetica', 7)
        canv.drawRightString(width - MARGIN, top, self.business_name)
        canv.setStrokeColor(tint(pal['primary'], 0.6))
        canv.setLineWidth(0.4)
        canv.line(MARGIN, top - 2 * mm, width - MARGIN, top - 2 * mm)
        canv.restoreState()

    # ----- Footer -------------------------------------------------------------------------------------------------------------------------------------------------
    def draw_footer(self, canv, page, total):
        width, _ = PAGE
        baseline = MARGIN - 6 * mm
        canv.saveState()
        canv.setStrokeColor(BORDER)
        canv.setLineWidth(0.5)
        canv.line(MARGIN, baseline + 3 * mm, width - MARGIN, baseline + 3 * mm)

        size = 6.4
        sep = '   *   '
        w_credit = canv.stringWidth(f'Powered by {CREDIT_BRAND}', 'Helvetica', size)
        w_sep = canv.stringWidth(sep, 'Helvetica', size)
        w_site = canv.stringWidth(CREDIT_SITE, 'Helvetica', size)
        block = w_credit + w_sep + w_site
        x = (width - block) / 2.0

        canv.setFillColor(MUTED_TEXT)
        canv.setFont('Helvetica', size)
        canv.drawString(x, baseline, f'Powered by {CREDIT_BRAND}')
        canv.drawString(x + w_credit, baseline, sep)
        canv.setFillColor(self.palette['primary'])
        canv.drawString(x + w_credit + w_sep, baseline, CREDIT_SITE)
        canv.setStrokeColor(self.palette['primary'])
        canv.setLineWidth(0.3)
        canv.line(x + w_credit + w_sep, baseline - 0.9,
                  x + w_credit + w_sep + w_site, baseline - 0.9)

        canv.setFillColor(MUTED_TEXT)
        canv.setFont('Helvetica', 6.8)
        canv.drawString(MARGIN, baseline, self.subtitle[:60])
        canv.drawRightString(width - MARGIN, baseline, f'Page {page} of {total}')
        canv.restoreState()


# ----- Flowables --------------------------------------------------------------------------------------------------------------------------------------------------
class _SectionTab(Flowable):
    """Numbered brand tab that opens every section.

    A flowable rather than canvas furniture: the tab then travels with its
    section, so adding or omitting a section earlier in the pack can never leave
    a tab on the wrong page.
    """

    HEIGHT = 11 * mm

    def __init__(self, number, section, width, palette):
        super().__init__()
        self.number = number
        self.section = section
        self.width = width
        self.palette = palette
        self.height = self.HEIGHT

    def wrap(self, aw, ah):
        return self.width, self.height

    def draw(self):
        c = self.canv
        pal = self.palette
        h = self.height
        c.saveState()
        c.setFillColor(pal['primary'])
        c.rect(0, 0, self.width, h, stroke=0, fill=1)
        c.setFillColor(colors.white)
        c.setFont('Helvetica-Bold', 13)
        c.drawString(4 * mm, h - 7.6 * mm, f'{self.number:02d}')
        c.setStrokeColor(tint(colors.white, 0.55))
        c.setLineWidth(0.5)
        c.line(15 * mm, 3 * mm, 15 * mm, 8.6 * mm)
        c.setFont('Helvetica-Bold', 10.4)
        c.drawString(18 * mm, h - 7.2 * mm, self.section['label'])
        c.setFillColor(tint(colors.white, 0.34))
        c.setFont('Helvetica', 7)
        label_w = c.stringWidth(self.section['label'], 'Helvetica-Bold', 10.4)
        desc_w = (self.width - 4 * mm) - (18 * mm + label_w + 5 * mm)
        c.drawRightString(self.width - 4 * mm, h - 7.2 * mm,
                          _clip(c, self.section['description'], 'Helvetica', 7, desc_w))
        c.restoreState()


class _KpiGrid(Flowable):
    """KPI tiles laid out three-up with a period delta chip."""

    def __init__(self, kpis, width, palette, styles, columns=3):
        super().__init__()
        self.kpis = kpis
        self.width = width
        self.palette = palette
        self.styles = styles
        self.columns = columns
        rows = (len(kpis) + columns - 1) // columns
        self.height = rows * 20 * mm + (rows - 1) * 2.4 * mm

    def wrap(self, aw, ah):
        return self.width, self.height

    def draw(self):
        c = self.canv
        pal = self.palette
        gap = 2.6 * mm
        tile_w = (self.width - gap * (self.columns - 1)) / self.columns
        tile_h = 20 * mm
        for index, kpi in enumerate(self.kpis):
            row, col = divmod(index, self.columns)
            x = col * (tile_w + gap)
            y = self.height - (row + 1) * tile_h - row * 2.4 * mm

            c.setFillColor(tint(pal['primary'], 0.955))
            c.setStrokeColor(tint(pal['primary'], 0.80))
            c.setLineWidth(0.4)
            c.roundRect(x, y, tile_w, tile_h, 2 * mm, stroke=1, fill=1)
            c.setFillColor(pal['primary'])
            c.roundRect(x, y + tile_h - 0.8 * mm, tile_w, 0.8 * mm, 0.4 * mm,
                        stroke=0, fill=1)

            c.setFillColor(MUTED_TEXT)
            c.setFont('Helvetica-Bold', 6)
            c.drawString(x + 3 * mm, y + tile_h - 5 * mm,
                         str(kpi['label']).upper()[:28])

            value = str(kpi['value'])
            size = 12.4 if len(value) <= 14 else 10.4 if len(value) <= 18 else 8.8
            c.setFillColor(HEADER_TEXT)
            c.setFont('Helvetica-Bold', size)
            c.drawString(x + 3 * mm, y + tile_h - 10.4 * mm, value[:22])

            hint = str(kpi.get('hint') or '')
            c.setFillColor(SOFT)
            c.setFont('Helvetica', 5.8)
            c.drawString(x + 3 * mm, y + 3.2 * mm, hint[:34])

            delta = kpi.get('delta_pct')
            if delta is not None:
                up = delta >= 0
                chip = f'{"^" if up else "v"} {abs(delta):.1f}%'
                c.setFillColor(colors.HexColor('#15803d' if up
                                               else '#b91c1c'))
                c.setFont('Helvetica-Bold', 6.4)
                c.drawRightString(x + tile_w - 3 * mm, y + 3.2 * mm, chip)


class _ChartCard(Flowable):
    """One bordered card: title, subtitle and a drawn chart."""

    def __init__(self, title, subtitle, width, height, palette, drawer):
        super().__init__()
        self.title = title
        self.subtitle = subtitle
        self.width = width
        self.height = height
        self.palette = palette
        self.drawer = drawer   # callable(canvas, x, y, w, h)

    def wrap(self, aw, ah):
        return self.width, self.height

    def draw(self):
        c = self.canv
        pal = self.palette
        c.saveState()
        c.setFillColor(colors.white)
        c.setStrokeColor(BORDER)
        c.setLineWidth(0.5)
        c.roundRect(0, 0, self.width, self.height, 2.4 * mm, stroke=1, fill=1)
        c.setFillColor(pal['primary'])
        c.roundRect(0, self.height - 0.9 * mm, self.width, 0.9 * mm,
                    0.45 * mm, stroke=0, fill=1)

        c.setFillColor(HEADER_TEXT)
        c.setFont('Helvetica-Bold', 7.8)
        c.drawString(3.4 * mm, self.height - 5.6 * mm, self.title[:58])
        c.setFillColor(MUTED_TEXT)
        c.setFont('Helvetica', 5.9)
        c.drawString(3.4 * mm, self.height - 9.2 * mm, self.subtitle[:76])

        self.drawer(c, 3.4 * mm, 4 * mm,
                    self.width - 6.8 * mm, self.height - 15 * mm)
        c.restoreState()


def _series_colors(palette, count):
    base = [palette['primary'], palette['secondary'], palette['accent'],
            colors.HexColor('#0ea5e9'), colors.HexColor('#8b5cf6'),
            colors.HexColor('#f59e0b'), colors.HexColor('#10b981'),
            colors.HexColor('#ef4444'), colors.HexColor('#64748b')]
    out = []
    for i in range(count):
        colour = base[i % len(base)]
        out.append(tint(colour, min(0.55, 0.16 * (i // len(base)))))
    return out


def _draw_area(c, points, x, y, w, h, palette, trend=None):
    """Area + line with an optional fitted trend, plus y-axis ticks."""
    if not points:
        return
    values = [float(p['value']) for p in points]
    top = max(values + [0]) or 1
    low = min(values + [0])
    span = (top - low) or abs(top) or 1
    n = len(values)
    step = w / max(n - 1, 1)

    def px(i):
        return x + i * step

    def py(v):
        return y + ((v - low) / span) * h

    # Gridlines + axis labels
    c.setFont('Helvetica', 5.4)
    for tick in range(4):
        value = low + span * tick / 3
        gy = py(value)
        c.setStrokeColor(colors.HexColor('#E2E8F0'))
        c.setLineWidth(0.3)
        c.line(x, gy, x + w, gy)
        c.setFillColor(MUTED_TEXT)
        c.drawRightString(x - 1.4 * mm, gy - 1.2, compact(value))

    # Area fill
    area = c.beginPath()
    area.moveTo(px(0), py(low))
    for i, v in enumerate(values):
        area.lineTo(px(i), py(v))
    area.lineTo(px(n - 1), py(low))
    area.close()
    c.setFillColor(tint(palette['primary'], 0.84))
    c.drawPath(area, stroke=0, fill=1)

    # Line
    line = c.beginPath()
    line.moveTo(px(0), py(values[0]))
    for i, v in enumerate(values[1:], start=1):
        line.lineTo(px(i), py(v))
    c.setStrokeColor(palette['secondary'])
    c.setLineWidth(1.5)
    c.drawPath(line, stroke=1, fill=0)

    # Points
    c.setFillColor(palette['secondary'])
    for i, v in enumerate(values):
        c.circle(px(i), py(v), 1.5, stroke=0, fill=1)

    # Fitted trend (dashed)
    if trend and n >= 2:
        t = c.beginPath()
        t.moveTo(px(0), py(trend['intercept']))
        t.lineTo(px(n - 1), py(trend['intercept'] + trend['slope'] * (n - 1)))
        c.setStrokeColor(colors.HexColor('#f59e0b'))
        c.setLineWidth(1.1)
        c.setDash(2.4, 1.8)
        c.drawPath(t, stroke=1, fill=0)
        c.setDash()

    # X labels (thin out when crowded)
    c.setFillColor(MUTED_TEXT)
    c.setFont('Helvetica', 5.4)
    every = max(1, n // 8)
    for i, point in enumerate(points):
        if i % every and i != n - 1:
            continue
        c.drawCentredString(px(i), y - 3.4 * mm, str(point['label'])[:9])


def _wrap_label(c, text, max_w, font='Helvetica', size=5.2, lines=2):
    """Wrap a chart label onto at most ``lines`` lines, ellipsising the last.

    Product names ("Surgical Face Mask (Box of 50)") are far wider than a bar
    slot; drawing them on one line made neighbouring labels collide.
    """
    words = str(text or '').split()
    out, current = [], ''
    for word in words:
        candidate = f'{current} {word}'.strip()
        if c.stringWidth(candidate, font, size) <= max_w or not current:
            current = candidate
        else:
            out.append(current)
            current = word
            if len(out) == lines:
                break
    if current and len(out) < lines:
        out.append(current)
    if not out:
        return ['']
    last = out[-1]
    while last and c.stringWidth(last, font, size) > max_w:
        last = last[:-1]
    out[-1] = last
    return out


def _draw_bars(c, points, x, y, w, h, palette, money_fmt=False):
    """Vertical bars with a value label above each and two-line x labels.

    The drawable height is split into ``label_band`` (x labels), ``value_band``
    (the figure above the tallest bar) and the plot itself - without that
    reservation the tallest bar's label printed on top of the card border.
    """
    if not points:
        return
    values = [float(p['value']) for p in points]
    top = max(values + [1])
    n = len(points)
    slot = w / n
    bar_w = min(slot * 0.56, 16 * mm)
    label_band = 9 * mm
    value_band = 4 * mm
    plot = max(h - label_band - value_band, 4 * mm)
    colours = _series_colors(palette, n)

    def fit(text, px):
        text = str(text)
        while text and c.stringWidth(text, 'Helvetica', 5.2) > px:
            text = text[:-1]
        return text

    for i, point in enumerate(points):
        bar_h = (values[i] / top) * plot if top else 0
        bx = x + i * slot + (slot - bar_w) / 2
        c.setFillColor(colours[i])
        c.roundRect(bx, y + label_band, bar_w, max(bar_h, 0.8),
                    0.8 * mm, stroke=0, fill=1)
        c.setFillColor(HEADER_TEXT)
        c.setFont('Helvetica-Bold', 5.2)
        c.drawCentredString(bx + bar_w / 2, y + label_band + bar_h + 1.4,
                            compact(values[i]))
        c.setFillColor(MUTED_TEXT)
        c.setFont('Helvetica', 5.2)
        lines = _wrap_label(c, point['label'], slot - 3.4)
        line_y = y + 5.4 * mm
        for line in lines[:2]:
            c.drawCentredString(bx + bar_w / 2, line_y, line)
            line_y -= 5.4


def _draw_donut(c, points, x, y, w, h, palette, currency='KES'):
    points = [p for p in points if float(p['value']) > 0][:8]
    if not points:
        return
    total = sum(float(p['value']) for p in points) or 1
    size = min(h, w * 0.40)
    cx = x + size / 2 + 1 * mm
    cy = y + h / 2
    radius = max(size / 2 - 2 * mm, 4)
    thickness = min(9 * mm, radius * 0.42)
    colours = _series_colors(palette, len(points))

    c.setStrokeColor(colors.HexColor('#EEF2F7'))
    c.setLineWidth(thickness)
    c.circle(cx, cy, radius, stroke=1, fill=0)

    c.setLineWidth(thickness)
    angle = 90.0
    for i, point in enumerate(points):
        extent = -360.0 * (float(point['value']) / total)
        if abs(extent) < 0.4:
            angle += extent
            continue
        c.setStrokeColor(colours[i])
        if abs(extent) >= 359.4:
            c.circle(cx, cy, radius, stroke=1, fill=0)
            angle += extent
            continue
        arc = c.beginPath()
        arc.arc(cx - radius, cy - radius, cx + radius, cy + radius,
                angle, extent)
        c.drawPath(arc, stroke=1, fill=0)
        angle += extent

    # Legend: label, value and share. Spaced by the available height so eight
    # rows still fit inside the card instead of running past its bottom edge.
    legend_x = x + size + 5 * mm
    available_w = w - size - 5 * mm
    row_h = min(4.6 * mm, (h - 2 * mm) / max(len(points), 1))
    row_y = y + h - 3 * mm
    for i, point in enumerate(points):
        share = 100.0 * float(point['value']) / total
        c.setFillColor(colours[i])
        c.circle(legend_x + 1.4, row_y + 1.6, 1.6, stroke=0, fill=1)
        c.setFillColor(BODY)
        c.setFont('Helvetica', 5.9)
        label = str(point['label'])
        max_w = available_w * 0.46
        while label and c.stringWidth(label, 'Helvetica', 5.9) > max_w:
            label = label[:-1]
        c.drawString(legend_x + 4.4, row_y, label)
        c.setFillColor(MUTED_TEXT)
        c.setFont('Helvetica', 5.4)
        c.drawString(legend_x + 4.4 + max_w + 1.5 * mm, row_y,
                     money(point['value'], currency)[:18])
        c.setFillColor(HEADER_TEXT)
        c.setFont('Helvetica-Bold', 5.6)
        c.drawRightString(x + w, row_y, f'{share:.0f}%')
        row_y -= row_h
        if row_y < y:
            break


def _good_bad(palette):
    """Positive / negative / neutral colours used by the signed charts."""
    return {
        'up': colors.HexColor('#15803d'),
        'down': colors.HexColor('#b91c1c'),
        'flat': palette['secondary'],
    }


def _draw_waterfall(c, rows, x, y, w, h, palette, currency='KES'):
    """Opening -> driver steps -> closing, drawn as floating bars.

    Each step starts where the previous one finished, so the shape of the chart
    *is* the argument: a reader can see which driver pushed revenue up and which
    one gave it back. The step heights are the numbers in the table below it.
    """
    if not rows:
        return
    tones = _good_bad(palette)
    n = len(rows)
    slot = w / n
    bar_w = min(slot * 0.58, 18 * mm)
    label_band = 10 * mm
    value_band = 5 * mm
    plot = max(h - label_band - value_band, 6 * mm)

    runs = [float(r.get('running', 0)) for r in rows]
    low = min(runs + [0.0])
    high = max(runs + [0.0])
    span = (high - low) or 1.0

    def level(value):
        return y + label_band + ((value - low) / span) * plot

    baseline = level(0.0)
    c.setStrokeColor(colors.HexColor('#CBD5E1'))
    c.setLineWidth(0.5)
    c.line(x, baseline, x + w, baseline)

    previous_top = None
    for index, row in enumerate(rows):
        running = float(row.get('running', 0))
        impact = float(row.get('impact', 0))
        kind = row.get('kind')
        bx = x + index * slot + (slot - bar_w) / 2

        if kind == 'open':
            start, end = 0.0, running
            colour = tones['flat']
        elif kind == 'close':
            start, end = 0.0, running
            colour = palette['primary']
        else:
            start, end = running - impact, running
            colour = tones['up'] if impact >= 0 else tones['down']

        y0, y1 = level(min(start, end)), level(max(start, end))
        height = max(y1 - y0, 1.2)
        c.setFillColor(colour)
        c.rect(bx, y0, bar_w, height, stroke=0, fill=1)

        # Connector from this bar to the next one - the visual thread that makes
        # the sequence read as a single walk rather than unrelated columns.
        if previous_top is not None:
            c.setStrokeColor(colors.HexColor('#94A3B8'))
            c.setLineWidth(0.4)
            c.line(previous_top, level(running), bx, level(running))
        previous_top = bx + bar_w

        # Value label: the impact for steps, the balance for open/close.
        c.setFillColor(HEADER_TEXT)
        c.setFont('Helvetica-Bold', 5.4)
        if kind == 'step':
            text = f'{impact:+,.0f}' if abs(impact) >= 1 else '0'
        else:
            text = compact(running)
        c.drawCentredString(bx + bar_w / 2,
                            max(y1, baseline) + 1.6, text)

        c.setFillColor(MUTED_TEXT)
        c.setFont('Helvetica', 5.2)
        lines = _wrap_label(c, row.get('label', ''), slot - 2.4, size=5.2, lines=2)
        line_y = y + 6.2 * mm
        for line in lines[:2]:
            c.drawCentredString(bx + bar_w / 2, line_y, line)
            line_y -= 5.2


def _draw_forecast_chart(c, forecast, x, y, w, h, palette):
    """History, fitted line, projection and the confidence cone.

    The projection is dashed and the band is drawn *behind* the lines so the
    point forecast stays legible even when the interval is wide.
    """
    history = [float(p['value']) for p in forecast.get('history') or []]
    fitted = [float(v) for v in forecast.get('fitted') or []]
    future = forecast.get('forecast') or []
    if not history:
        return

    actual = [float(p['value']) for p in future]
    highs = [float(p.get('high', 0)) for p in future]
    lows = [float(p.get('low', 0)) for p in future]

    n_hist = len(history)
    n_all = n_hist + len(actual)
    if n_all < 2:
        return

    top = max(highs + history + fitted + [1.0])
    label_band = 9 * mm
    plot = max(h - label_band, 6 * mm)
    step = w / max(n_all - 1, 1)

    def px(i):
        return x + i * step

    def py(v):
        return y + label_band + (v / (top or 1)) * plot

    c.setFont('Helvetica', 5.4)
    for tick in range(4):
        value = top * tick / 3
        gy = py(value)
        c.setStrokeColor(colors.HexColor('#E2E8F0'))
        c.setLineWidth(0.3)
        c.line(x, gy, x + w, gy)
        c.setFillColor(MUTED_TEXT)
        c.drawRightString(x - 1.4 * mm, gy - 1.2, compact(value))

    # Confidence cone (filled behind everything).
    if highs and lows:
        band = c.beginPath()
        band.moveTo(px(n_hist - 1), py(history[-1]))
        for i, high in enumerate(highs):
            band.lineTo(px(n_hist + i), py(high))
        for i in range(len(lows) - 1, -1, -1):
            band.lineTo(px(n_hist + i), py(lows[i]))
        band.close()
        c.setFillColor(tint(palette['secondary'], 0.80))
        c.drawPath(band, stroke=0, fill=1)

    # History area.
    area = c.beginPath()
    area.moveTo(px(0), py(0))
    for i, value in enumerate(history):
        area.lineTo(px(i), py(value))
    area.lineTo(px(n_hist - 1), py(0))
    area.close()
    c.setFillColor(tint(palette['primary'], 0.86))
    c.drawPath(area, stroke=0, fill=1)

    def polyline(values, offset, colour, dashed=False, width=1.0):
        if len(values) < 2:
            return
        path = c.beginPath()
        path.moveTo(px(offset), py(values[0]))
        for i, value in enumerate(values[1:], start=1):
            path.lineTo(px(offset + i), py(value))
        c.setStrokeColor(colour)
        c.setLineWidth(width)
        c.setDash(2.4, 1.8) if dashed else c.setDash()
        c.drawPath(path, stroke=1, fill=0)
        c.setDash()

    polyline(history, 0, palette['primary'], width=1.4)
    if len(fitted) == n_hist:
        polyline(fitted, 0, tint(palette['secondary'], 0.25), dashed=True,
                 width=0.8)
    if actual:
        bridge = [history[-1]] + actual
        polyline(bridge, n_hist - 1, palette['accent'], dashed=True, width=1.4)

    # Divider between observed and projected.
    c.setStrokeColor(colors.HexColor('#94A3B8'))
    c.setLineWidth(0.5)
    c.setDash(1.6, 1.6)
    c.line(px(n_hist - 1), py(0), px(n_hist - 1), py(top))
    c.setDash()
    c.setFillColor(MUTED_TEXT)
    c.setFont('Helvetica-Bold', 5)
    c.drawString(px(n_hist - 1) + 1.4, py(top) + 1.4, 'forecast')

    # X labels: first, a middle tick and the last projection.
    c.setFillColor(MUTED_TEXT)
    c.setFont('Helvetica', 4.8)
    marks = {0, max(n_hist - 1, 0), n_all - 1}
    if n_hist > 3:
        marks.add(n_hist // 2)
    labels = [p.get('label', '') for p in (forecast.get('history') or [])]
    labels += [p.get('label', '') for p in future]
    for index in sorted(marks):
        if 0 <= index < len(labels):
            c.drawCentredString(px(index), y + 2.2 * mm,
                                str(labels[index])[:9])


def _draw_seasonal(c, seasonal, x, y, w, h, palette):
    """Seasonal index as bars around the 1.0 reference line."""
    points = [s for s in seasonal if s.get('samples')]
    if not points:
        return
    tones = _good_bad(palette)
    indices = [float(p['index']) for p in points]
    high = max(indices + [1.0])
    low = min(indices + [1.0])
    span = (high - low) or 1.0
    slot = w / len(points)
    bar_w = min(slot * 0.5, 12 * mm)
    label_band = 5 * mm
    plot = max(h - label_band, 5 * mm)

    def level(value):
        return y + label_band + ((value - low) / span) * plot

    reference = level(1.0)
    c.setStrokeColor(colors.HexColor('#94A3B8'))
    c.setLineWidth(0.5)
    c.setDash(1.8, 1.4)
    c.line(x, reference, x + w, reference)
    c.setDash()

    for index, point in enumerate(points):
        value = indices[index]
        bx = x + index * slot + (slot - bar_w) / 2
        y0, y1 = level(min(1.0, value)), level(max(1.0, value))
        c.setFillColor(tones['up'] if value >= 1.0 else tones['down'])
        c.rect(bx, y0, bar_w, max(y1 - y0, 1.0), stroke=0, fill=1)
        c.setFillColor(HEADER_TEXT)
        c.setFont('Helvetica-Bold', 4.8)
        c.drawCentredString(bx + bar_w / 2, max(y0, y1) + 1.2,
                            f'{value:.2f}')
        c.setFillColor(MUTED_TEXT)
        c.setFont('Helvetica', 4.8)
        c.drawCentredString(bx + bar_w / 2, y + 1.6 * mm, point['label'])


class _NumberedTable(Flowable):
    """Table with a `#` gutter, brand header, zebra rows and optional totals."""

    def __init__(self, headers, rows, widths, palette, styles,
                 aligns=None, total_row=None):
        super().__init__()
        self.headers = headers
        self.rows = rows
        self.widths = widths
        self.palette = palette
        self.styles = styles
        self.aligns = aligns or ['left'] * len(headers)
        self.total_row = total_row

    def _style_for(self, index):
        align = self.aligns[index] if index < len(self.aligns) else 'left'
        return {'left': self.styles['cell'], 'right': self.styles['cell_r'],
                'center': self.styles['cell_c']}[align]

    def _head_for(self, index):
        align = self.aligns[index] if index < len(self.aligns) else 'left'
        return {'left': self.styles['head'], 'right': self.styles['head_r'],
                'center': self.styles['head_c']}[align]

    def build(self):
        body = [[Paragraph(str(h), self._head_for(i))
                 for i, h in enumerate(self.headers)]]
        for number, row in enumerate(self.rows, start=1):
            cells = [Paragraph(str(number), self.styles['cell_c'])]
            for i, value in enumerate(row):
                cells.append(Paragraph(str(value), self._style_for(i + 1)))
            body.append(cells)
        if self.total_row:
            cells = [Paragraph('', self.styles['cell_c'])]
            for i, value in enumerate(self.total_row):
                style = ParagraphStyle('tot', parent=self._style_for(i + 1),
                                       fontName='Helvetica-Bold')
                cells.append(Paragraph(str(value), style))
            body.append(cells)
        self._body = body
        return body

    def wrap(self, aw, ah):
        body = self.build()
        table = Table(body, colWidths=self.widths, repeatRows=1, hAlign='LEFT')
        style = [
            ('BACKGROUND', (0, 0), (-1, 0), self.palette['secondary']),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LINEBELOW', (0, 0), (-1, 0), 0.6, self.palette['accent']),
            ('GRID', (0, 0), (-1, -1), 0.25, BORDER),
            ('TOPPADDING', (0, 0), (-1, -1), 2.2),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 2.2),
            ('LEFTPADDING', (0, 0), (-1, -1), 2.6),
            ('RIGHTPADDING', (0, 0), (-1, -1), 2.6),
        ]
        stripe = tint(self.palette['primary'], 0.955)
        for i in range(1, len(body)):
            if i % 2 == 0:
                style.append(('BACKGROUND', (0, i), (-1, i), stripe))
        if self.total_row:
            last = len(body) - 1
            style.append(('BACKGROUND', (0, last), (-1, last),
                          tint(self.palette['primary'], 0.88)))
            style.append(('LINEABOVE', (0, last), (-1, last), 0.6,
                          self.palette['primary']))
        table.setStyle(TableStyle(style))
        self._table = table
        w, h = table.wrap(aw, ah)
        self.width, self.height = w, h
        return w, h

    def draw(self):
        self._table.drawOn(self.canv, 0, 0)


def _bullet(kind, text, palette, styles):
    """A findings / recommendation line with a coloured marker.

    The marker is ``*`` (U+2022) rather than ``*``/``>``: Helvetica is encoded
    WinAnsi, which has the bullet but *not* the geometric shapes - those printed
    as a stray ``G``.
    """
    colour = {'finding': palette['primary'],
              'action': colors.HexColor('#15803d')}[kind]
    return Paragraph(f'<font color="#{str(colour.hexval())[2:]}">*</font>'
                     f'&nbsp;&nbsp;{text}', styles['body'])


# ----- Public entry point -----------------------------------------------------------------------------------------------------------------------------
def render_bi_pdf(*, dataset, sections, org=None, logo_path=None, palette=None,
                  business_name='', title='Business Intelligence Report',
                  subtitle='', watermark='', watermark_opacity=0.30,
                  currency='KES') -> bytes:
    """Render the BI pack to PDF bytes."""
    palette = palette or resolve_palette(None)
    styles = _styles()

    doc = _BiDoc(palette=palette, org=org, logo_path=logo_path,
                 business_name=business_name, title=title, subtitle=subtitle,
                 watermark=watermark, watermark_opacity=watermark_opacity)

    buf = io.BytesIO()
    template = BaseDocTemplate(
        buf, pagesize=PAGE,
        leftMargin=MARGIN, rightMargin=MARGIN,
        topMargin=MARGIN, bottomMargin=MARGIN + 6 * mm,
        title=title, author=business_name or 'AdhereMed',
        subject=subtitle or title,
    )

    cover_frame = Frame(MARGIN, MARGIN + 6 * mm, CONTENT_W,
                        PAGE[1] - 2 * MARGIN - 6 * mm, id='cover')
    body_frame = Frame(MARGIN, MARGIN + 6 * mm, CONTENT_W,
                       PAGE[1] - 2 * MARGIN - 12 * mm, id='body')

    # ``sections`` arrives as a list of ids; drop anything unknown so a stale
    # client cannot make the renderer raise on a missing section.
    section_titles = [SECTIONS_BY_ID[s] for s in sections if s in SECTIONS_BY_ID]

    def _cover_page(canv, _doc):
        doc.draw_cover(canv, section_titles, dataset)
        doc.draw_watermark(canv)

    def _body_page(canv, _doc):
        doc.draw_watermark(canv)
        doc.draw_running_header(canv)

    template.addPageTemplates([
        PageTemplate(id='cover', frames=[cover_frame], onPage=_cover_page),
        PageTemplate(id='body', frames=[body_frame], onPage=_body_page),
    ])

    flow = [NextPageTemplate('body'), Spacer(1, 1)]

    numbered = enumerate(section_titles, start=1)
    for number, section in numbered:
        sid = section['id']
        block = _section_flow(sid, section, dataset, palette, styles,
                              number, currency)
        if block is None:
            continue
        flow.append(PageBreak())
        # Section tab is a flowable so it always opens its own section.
        flow.append(_SectionTab(number, section, CONTENT_W, palette))
        flow.append(Spacer(1, 5 * mm))
        flow.extend(block)

    template.build(
        flow,
        canvasmaker=lambda *a, **kw: _NumberedCanvas(*a, report_doc=doc, **kw),
    )
    return buf.getvalue()


def _section_flow(sid, section, dataset, palette, styles, number, currency):
    """Story for one section, or ``None`` when it has no data to show."""
    out = []

    def heading(text, sub=None):
        out.append(Paragraph(text, styles['h2']))
        if sub:
            out.append(Spacer(1, 1.2 * mm))
            out.append(Paragraph(sub, styles['small']))
        out.append(Spacer(1, 3.4 * mm))

    if sid == 'executive_summary':
        from .bi import build_narrative
        findings = build_narrative(dataset)
        heading('What happened',
                f'{dataset["span_days"]} days analysed * '
                f'{count(dataset["totals"]["orders"])} completed orders')
        for line in findings:
            out += [_bullet('finding', line, palette, styles), Spacer(1, 2 * mm)]

    elif sid == 'kpi_scorecard':
        heading('Commercial measures',
                'Change is measured against the immediately preceding period '
                'of the same length.')
        grid = _KpiGrid(dataset['kpis'], CONTENT_W, palette, styles, columns=3)
        out.append(grid)

    elif sid == 'revenue_trajectory':
        history = dataset['history']
        if not history:
            return None
        heading('Revenue trajectory',
                'Monthly collected revenue with the least-squares trend.')
        points = history
        card = _ChartCard(
            'Monthly revenue', f'{len(history)} months * trend shown dashed',
            CONTENT_W, 78 * mm, palette,
            lambda c, x, y, w, h: _draw_area(c, points, x, y, w, h, palette,
                                             dataset['trend']))
        out += [card, Spacer(1, 4 * mm)]

        rows = []
        for point in history:
            delta = point.get('delta_pct')
            rows.append([
                point['label'],
                money(point['value'], currency),
                count(point['orders']),
                '-' if delta is None else f'{delta:+.1f}%',
            ])
        short = len(history) > 14
        table_rows = rows[-14:] if short else rows
        out.append(_NumberedTable(
            ['#', 'Month', 'Revenue', 'Orders', 'MoM'],
            [[r[0], r[1], r[2], r[3]] for r in table_rows],
            [CONTENT_W * 0.07, CONTENT_W * 0.28, CONTENT_W * 0.32,
             CONTENT_W * 0.16, CONTENT_W * 0.17],
            palette, styles,
            aligns=['center', 'left', 'right', 'right', 'right'],
            total_row=['Total', money(dataset['totals']['revenue'], currency),
                       count(dataset['totals']['orders']), ''],
        ))
        if short:
            out += [Spacer(1, 2 * mm),
                    Paragraph(f'Showing the most recent 14 of {len(history)} '
                              f'months; the totals cover the full period.',
                              styles['small'])]

        trend = dataset['trend']
        if trend:
            out += [Spacer(1, 4 * mm),
                    Paragraph(
                        f'Fitted trend: <b>{money(trend["slope"], currency)}</b> '
                        f'of revenue per month. At that rate the next month '
                        f'would land at <b>{money(trend["next"], currency)}</b>.',
                        styles['body'])]

    elif sid == 'category_mix':
        items = dataset['categories']
        if not items:
            return None
        heading('Category mix',
                'Share of revenue by product category for the period.')
        card = _ChartCard(
            'Revenue share', f'{len(items)} categories',
            CONTENT_W, 72 * mm, palette,
            lambda c, x, y, w, h: _draw_donut(c, items, x, y, w, h, palette, currency))
        out += [card, Spacer(1, 4 * mm)]
        by_value = sorted(items, key=lambda i: -float(i['value']))
        out.append(_NumberedTable(
            ['#', 'Category', 'Revenue', 'Share'],
            [[i['label'], money(i['value'], currency), f'{i["share_pct"]:.1f}%']
             for i in by_value],
            [CONTENT_W * 0.07, CONTENT_W * 0.55, CONTENT_W * 0.24,
             CONTENT_W * 0.14],
            palette, styles,
            aligns=['center', 'left', 'right', 'right'],
            total_row=['Total', money(sum(float(i['value']) for i in items),
                                      currency),
                       '100.0%'],
        ))

    elif sid == 'branch_comparison':
        items = dataset['branches']
        if not items:
            return None
        heading('Warehouse comparison',
                'Revenue by warehouse, with order count and average basket.')
        card = _ChartCard(
            'Revenue by warehouse', f'{len(items)} warehouses',
            CONTENT_W, 66 * mm, palette,
            lambda c, x, y, w, h: _draw_bars(c, items, x, y, w, h, palette))
        out += [card, Spacer(1, 4 * mm)]
        out.append(_NumberedTable(
            ['#', 'Warehouse', 'Revenue', 'Orders', 'Avg basket'],
            [[i['label'], money(i['value'], currency), count(i['orders']),
              money(i['aov'], currency)] for i in items],
            [CONTENT_W * 0.07, CONTENT_W * 0.41, CONTENT_W * 0.22,
             CONTENT_W * 0.13, CONTENT_W * 0.17],
            palette, styles,
            aligns=['center', 'left', 'right', 'right', 'right'],
            total_row=['Total', money(sum(float(i['value']) for i in items),
                                      currency),
                       count(sum(i['orders'] for i in items)), ''],
        ))

    elif sid == 'top_products':
        items = dataset['products']
        if not items:
            return None
        heading('Top products',
                'Ranked by revenue, with the cumulative contribution that '
                'drives the 80/20 rule.')
        card = _ChartCard(
            'Revenue by product', f'Top {len(items)}',
            CONTENT_W, 62 * mm, palette,
            lambda c, x, y, w, h: _draw_bars(c, items[:8], x, y, w, h, palette))
        out += [card, Spacer(1, 4 * mm)]
        out.append(_NumberedTable(
            ['#', 'Product', 'Units', 'Revenue', 'Share', 'Cum.'],
            [[i['label'][:44], count(i['quantity']), money(i['value'], currency),
              f'{i["share_pct"]:.1f}%', f'{i["cumulative_pct"]:.1f}%']
             for i in items],
            [CONTENT_W * 0.06, CONTENT_W * 0.42, CONTENT_W * 0.10,
             CONTENT_W * 0.20, CONTENT_W * 0.11, CONTENT_W * 0.11],
            palette, styles,
            aligns=['center', 'left', 'right', 'right', 'right', 'right'],
        ))

    elif sid == 'payment_mix':
        items = dataset['payments']
        if not items:
            return None
        heading('Payment mix',
                'Collected value by settlement method - a proxy for cash-flow '
                'risk and bank charges.')
        card = _ChartCard(
            'Settlement split', f'{len(items)} methods',
            CONTENT_W, 66 * mm, palette,
            lambda c, x, y, w, h: _draw_donut(c, items, x, y, w, h, palette, currency))
        out += [card, Spacer(1, 4 * mm)]
        out.append(_NumberedTable(
            ['#', 'Method', 'Revenue', 'Orders', 'Share'],
            [[i['label'], money(i['value'], currency), count(i['orders']),
              f'{i["share_pct"]:.1f}%'] for i in items],
            [CONTENT_W * 0.07, CONTENT_W * 0.35, CONTENT_W * 0.26,
             CONTENT_W * 0.16, CONTENT_W * 0.16],
            palette, styles,
            aligns=['center', 'left', 'right', 'right', 'right'],
        ))

    elif sid == 'customer_segments':
        items = [i for i in dataset['segments'] if i['customers']]
        if not items:
            heading('Customer segments',
                    'No transactions in this period were linked to a customer '
                    'profile, so no segmentation is possible.')
        else:
            heading('Customer segments',
                    'Spend concentration by purchase frequency - identifies '
                    'reliance on one-off buyers.')
            card = _ChartCard(
                'Revenue by visit frequency', f'{len(items)} segments',
                CONTENT_W, 62 * mm, palette,
                lambda c, x, y, w, h: _draw_donut(c, items, x, y, w, h, palette, currency))
            out += [card, Spacer(1, 4 * mm)]
            out.append(_NumberedTable(
                ['#', 'Segment', 'Customers', 'Revenue', 'Share'],
                [[i['label'], count(i['customers']), money(i['value'], currency),
                  f'{i["share_pct"]:.1f}%'] for i in items],
                [CONTENT_W * 0.07, CONTENT_W * 0.35, CONTENT_W * 0.16,
                 CONTENT_W * 0.26, CONTENT_W * 0.16],
                palette, styles,
                aligns=['center', 'left', 'right', 'right', 'right'],
            ))

    elif sid == 'stock_health':
        totals = dataset['stock_totals']
        heading('Stock health',
                'Capital employed, cover and stock-out exposure at the end of '
                'the period.')
        tiles = [
            {'label': 'Inventory at cost',
             'value': money(totals['inventory_cost'], currency),
             'hint': f'{money(totals["inventory_retail"], currency)} at retail'},
            {'label': 'Units on hand', 'value': count(totals['units_on_hand']),
             'hint': f'{count(totals["items"])} active items'},
            {'label': 'Out of stock', 'value': count(totals['out_of_stock']),
             'hint': f'{count(totals["low_stock"])} at/below reorder'},
            {'label': 'Expired units', 'value': count(totals['expired_units']),
             'hint': 'write-off exposure'},
        ]
        out.append(_KpiGrid(tiles, CONTENT_W, palette, styles, columns=4))
        out.append(Spacer(1, 4 * mm))
        health = dataset['stock_health']
        if health:
            out.append(_NumberedTable(
                ['#', 'Item', 'On hand', 'Reorder at', 'Value'],
                [[r['label'][:40], count(r['on_hand']), count(r['reorder_level']),
                  money(r['value'], currency)] for r in health],
                [CONTENT_W * 0.06, CONTENT_W * 0.52, CONTENT_W * 0.13,
                 CONTENT_W * 0.13, CONTENT_W * 0.16],
                palette, styles,
                aligns=['center', 'left', 'right', 'right', 'right'],
            ))
        else:
            out.append(Paragraph('No items are at or below their reorder level.',
                                 styles['body']))

    elif sid == 'root_cause':
        root = dataset.get('root_cause')
        if not root:
            heading('Root-cause analysis',
                    'The movement could not be attributed for this selection.')
            out.append(Paragraph(
                'Without a comparable prior period there is nothing to '
                'decompose. Widen the period so a like-for-like window '
                'exists behind it.', styles['body']))
            return out

        heading('Root-cause analysis',
                'Opening position walked to closing position by driver. '
                'Discount and stock-out cost are measured separately because '
                'they are already inside the price and volume steps.')

        tones = _good_bad(palette)
        delta = root['delta_pct']
        tiles = [
            {'label': 'Opening revenue',
             'value': money(root['previous']['revenue'], currency),
             'hint': f'{count(root["previous"]["orders"])} orders'},
            {'label': 'Closing revenue',
             'value': money(root['current']['revenue'], currency),
             'hint': f'{count(root["current"]["orders"])} orders'},
            {'label': 'Net movement',
             'value': f'{"" if root["net_change"] >= 0 else "-"}'
                      f'{money(abs(root["net_change"]), currency)}',
             'hint': ('no prior period' if delta is None
                      else f'{delta:+.1f}% vs previous'),
             'delta_pct': delta},
            {'label': 'Stock-out cost',
             'value': money(root['lost_revenue'], currency),
             'hint': f'{count(len(root["stockouts"]))} items short'},
        ]
        out.append(_KpiGrid(tiles, CONTENT_W, palette, styles, columns=4))
        out += [Spacer(1, 4 * mm),
                Paragraph(f'<b>{root["verdict"]["headline"]}.</b> '
                          f'{root["verdict"]["detail"]}', styles['body']),
                Spacer(1, 4 * mm)]

        card = _ChartCard(
            'Revenue bridge',
            'Each step starts where the previous one ended',
            CONTENT_W, 76 * mm, palette,
            lambda c, x, y, w, h: _draw_waterfall(c, root['bridge'], x, y, w, h,
                                                  palette, currency))
        out += [card, Spacer(1, 4 * mm)]

        out.append(_NumberedTable(
            ['#', 'Step', 'Impact', 'Running total'],
            [[row['label'],
              '-' if not row['impact'] else f'{row["impact"]:+,.2f}',
              money(row['running'], currency)]
             for row in root['bridge']],
            [CONTENT_W * 0.07, CONTENT_W * 0.38, CONTENT_W * 0.27,
             CONTENT_W * 0.28],
            palette, styles,
            aligns=['center', 'left', 'right', 'right'],
        ))

        out += [Spacer(1, 5 * mm),
                Paragraph('Driver ranking', styles['h3']),
                Spacer(1, 2 * mm)]
        out.append(_NumberedTable(
            ['#', 'Driver', 'Impact', 'Share of movement', 'Reading'],
            [[row['label'], f'{row["impact"]:+,.2f}',
              f'{row["weight_pct"]:.1f}%', row['hint']]
             for row in root['drivers']],
            [CONTENT_W * 0.06, CONTENT_W * 0.15, CONTENT_W * 0.20,
             CONTENT_W * 0.17, CONTENT_W * 0.42],
            palette, styles,
            aligns=['center', 'left', 'right', 'right', 'left'],
        ))

        out += [Spacer(1, 5 * mm),
                Paragraph('Leakage measured separately', styles['h3']),
                Spacer(1, 2 * mm)]
        out.append(_NumberedTable(
            ['#', 'Leak', 'Value in period', 'Movement', 'Note'],
            [[row['label'], money(row['value'], currency),
              f'{row["change"]:+,.2f}', row['note']]
             for row in root['leakage']],
            [CONTENT_W * 0.06, CONTENT_W * 0.20, CONTENT_W * 0.22,
             CONTENT_W * 0.16, CONTENT_W * 0.36],
            palette, styles,
            aligns=['center', 'left', 'right', 'right', 'left'],
        ))

        if root['stockouts']:
            out += [Spacer(1, 5 * mm),
                    Paragraph('Largest stock-out exposures', styles['h3']),
                    Spacer(1, 2 * mm)]
            out.append(_NumberedTable(
                ['#', 'Item', 'On hand', 'Reorder at', 'Value at risk'],
                [[row['label'][:44], count(row['on_hand']),
                  count(row['reorder']),
                  money(row['value_at_risk'], currency)]
                 for row in root['stockouts']],
                [CONTENT_W * 0.06, CONTENT_W * 0.46, CONTENT_W * 0.14,
                 CONTENT_W * 0.15, CONTENT_W * 0.19],
                palette, styles,
                aligns=['center', 'left', 'right', 'right', 'right'],
                total_row=['Total', '', '', '',
                           money(root['lost_revenue'], currency)],
            ))

        if root.get('anomalies'):
            out += [Spacer(1, 5 * mm),
                    Paragraph('Outlier periods', styles['h3']),
                    Spacer(1, 2 * mm)]
            for anomaly in root['anomalies'][:4]:
                out.append(_bullet(
                    'finding',
                    f'{anomaly["label"]} sits at '
                    f'{money(anomaly["value"], currency)}, {abs(anomaly["z"]):.1f} '
                    f'standard deviations from the period mean.',
                    palette, styles))
                out.append(Spacer(1, 2 * mm))

    elif sid == 'forecast_trends':
        forecast = dataset.get('forecast') or {}
        heading('Forecasts & trends',
                'Projection fitted on the monthly revenue series, with the '
                'confidence band widening by horizon.')

        history = dataset['history']
        if not forecast.get('available'):
            if history:
                card = _ChartCard(
                    'Observed revenue',
                    f'{len(history)} monthly periods on record',
                    CONTENT_W, 70 * mm, palette,
                    lambda c, x, y, w, h: _draw_area(c, history, x, y, w, h,
                                                     palette, dataset['trend']))
                out += [card, Spacer(1, 4 * mm)]
            reason = forecast.get('reason') or 'No projection is available.'
            out.append(Paragraph(f'<b>No projection was fitted.</b> {reason}',
                                 styles['body']))
            out += [Spacer(1, 3 * mm),
                    Paragraph(
                        'Widen the reporting period or wait for more months to '
                        'close before relying on a forecast. The report '
                        'deliberately does not print a projected figure it '
                        'cannot support.', styles['small'])]
            for line in dataset.get('forecast_findings') or []:
                out += [_bullet('finding', line, palette, styles), Spacer(1, 2 * mm)]
            return out

        accuracy = forecast['accuracy']
        tiles = [
            {'label': 'Next period', 'value': money(forecast['next_value'], currency),
             'hint': forecast['forecast'][0]['label'] if forecast['forecast'] else ''},
            {'label': f'Next {forecast["horizon"]} periods',
             'value': money(forecast['total_forecast'], currency),
             'hint': f'avg {money(forecast["total_forecast"] / forecast["horizon"], currency)}'},
            {'label': 'Back-test error', 'value': f'{accuracy["mape"]:.1f}%',
             'hint': f'MAPE, R2 {accuracy["r2"]:.2f}'},
            {'label': 'Monthly trend',
             'value': money(forecast['slope'], currency),
             'hint': f'{forecast["direction"]} slope'},
        ]
        out.append(_KpiGrid(tiles, CONTENT_W, palette, styles, columns=4))
        out += [Spacer(1, 4 * mm)]

        card = _ChartCard(
            'Projection with confidence band',
            f'{forecast["method"]} * {forecast["confidence"]:.0f}% interval * '
            f'fitted on {len(forecast["history"])} periods',
            CONTENT_W, 82 * mm, palette,
            lambda c, x, y, w, h: _draw_forecast_chart(c, forecast, x, y, w, h,
                                                       palette))
        out += [card, Spacer(1, 4 * mm)]

        out.append(_NumberedTable(
            ['#', 'Period', 'Forecast', 'Low', 'High'],
            [[point['label'], money(point['value'], currency),
              money(point['low'], currency), money(point['high'], currency)]
             for point in forecast['forecast']],
            [CONTENT_W * 0.07, CONTENT_W * 0.22, CONTENT_W * 0.25,
             CONTENT_W * 0.23, CONTENT_W * 0.23],
            palette, styles,
            aligns=['center', 'left', 'right', 'right', 'right'],
            total_row=['Total', f'{forecast["horizon"]} periods',
                       money(forecast['total_forecast'], currency), '', ''],
        ))

        out += [Spacer(1, 5 * mm),
                Paragraph('What-if scenarios', styles['h3']),
                Spacer(1, 1.4 * mm),
                Paragraph('The base projection shifted by a flat percentage - '
                          'so the assumption behind each column is visible.',
                          styles['small']),
                Spacer(1, 2 * mm)]
        out.append(_NumberedTable(
            ['#', 'Scenario', 'Total over horizon', 'Average per period'],
            [[row['label'], money(row['value'], currency),
              money(row['per_month'], currency)]
             for row in forecast['scenarios']],
            [CONTENT_W * 0.07, CONTENT_W * 0.25, CONTENT_W * 0.36,
             CONTENT_W * 0.32],
            palette, styles,
            aligns=['center', 'left', 'right', 'right'],
        ))

        seasonal = [s for s in forecast.get('seasonal') or [] if s['samples']]
        if seasonal:
            out += [Spacer(1, 5 * mm),
                    Paragraph('Seasonal profile', styles['h3']),
                    Spacer(1, 2 * mm)]
            out.append(_ChartCard(
                'Calendar-month index', 'Bars above 1.00 run hotter than an '
                'average month',
                CONTENT_W, 56 * mm, palette,
                lambda c, x, y, w, h: _draw_seasonal(c, seasonal, x, y, w, h,
                                                     palette)))
            peak = max(seasonal, key=lambda s: s['index'])
            trough = min(seasonal, key=lambda s: s['index'])
            out += [Spacer(1, 2.4 * mm),
                    Paragraph(
                        f'{peak["label"]} is the strongest month at '
                        f'{peak["index"]:.2f}x the mean and {trough["label"]} '
                        f'the weakest at {trough["index"]:.2f}x. Plan the '
                        f'purchase calendar against this shape rather than a '
                        f'flat monthly run rate.', styles['body'])]

        out += [Spacer(1, 5 * mm),
                Paragraph('How to read this forecast', styles['h3']),
                Spacer(1, 2 * mm)]
        for line in dataset.get('forecast_findings') or []:
            out += [_bullet('finding', line, palette, styles), Spacer(1, 2 * mm)]

    elif sid == 'optimization':
        optimization = dataset.get('optimization')
        if not optimization:
            heading('Optimization & actions',
                    'Prescriptive recommendations are unavailable for this '
                    'selection.')
            out.append(Paragraph(
                'This section needs recorded purchase costs and at least one '
                'item with sales in the period.', styles['body']))
            return out

        assumptions = optimization['assumptions']
        heading('Optimization & actions',
                'Prescriptive recommendations derived from current prices, '
                'costs, cover and expiry dates.')

        tiles = [
            {'label': 'Replenishment spend',
             'value': money(optimization['replenishment_value'], currency),
             'hint': f'{count(len(optimization["replenishment"]))} items to order'},
            {'label': 'Clearance recovery',
             'value': money(optimization['markdown_recovery'], currency),
             'hint': f'{count(len(optimization["markdown"]))} near-expiry items'},
            {'label': 'Pricing upside',
             'value': money(optimization['pricing_upside'], currency),
             'hint': f'{count(len(optimization["pricing"]))} price moves'},
            {'label': 'At target margin',
             'value': f'{count(optimization["at_target"])} / '
                      f'{count(len(optimization["ladder"]))}',
             'hint': 'lines needing no price change'},
        ]
        out.append(_KpiGrid(tiles, CONTENT_W, palette, styles, columns=4))
        out += [Spacer(1, 4 * mm)]

        out.append(Paragraph('Pricing recommendations', styles['h3']))
        out.append(Spacer(1, 1.4 * mm))
        if optimization['pricing']:
            out.append(Paragraph(
                'Only upward moves toward the target margin are ever '
                'recommended. Net impact is revenue after an assumed own-price '
                'elasticity of -1.2.', styles['small']))
            out.append(Spacer(1, 2 * mm))
            out.append(_NumberedTable(
                ['#', 'Product', 'ABC', 'Now', 'Recommended', 'Move',
                 'Net impact'],
                [[row['label'][:38], row['abc'],
                  money(row['current'], currency),
                  money(row['recommended'], currency),
                  f'{row["delta_pct"]:+.1f}%',
                  money(row['impact'], currency)]
                 for row in optimization['pricing']],
                [CONTENT_W * 0.06, CONTENT_W * 0.33, CONTENT_W * 0.06,
                 CONTENT_W * 0.14, CONTENT_W * 0.16, CONTENT_W * 0.10,
                 CONTENT_W * 0.15],
                palette, styles,
                aligns=['center', 'left', 'center', 'right', 'right', 'right',
                        'right'],
                total_row=['Total', '', '', '', '', '',
                           money(optimization['pricing_upside'], currency)],
            ))
        else:
            out.append(Paragraph(
                f'Every priced line already clears its target margin '
                f'({optimization["at_target"]} of '
                f'{len(optimization["ladder"])}), so no price move is '
                f'recommended. The ladder below is shown so the decision is '
                f'visible rather than merely absent.', styles['small']))
            out.append(Spacer(1, 2 * mm))
            out.append(_NumberedTable(
                ['#', 'Product', 'ABC', 'Price', 'Cost', 'Margin', 'Target',
                 'Status'],
                [[row['label'][:34], row['abc'],
                  money(row['price'], currency), money(row['cost'], currency),
                  f'{row["margin_pct"]:.1f}%', f'{row["target_margin_pct"]:.1f}%',
                  row['status']]
                 for row in optimization['ladder']],
                [CONTENT_W * 0.06, CONTENT_W * 0.31, CONTENT_W * 0.06,
                 CONTENT_W * 0.13, CONTENT_W * 0.13, CONTENT_W * 0.09,
                 CONTENT_W * 0.09, CONTENT_W * 0.13],
                palette, styles,
                aligns=['center', 'left', 'center', 'right', 'right', 'right',
                        'right', 'left'],
            ))

        if optimization['guardrails']:
            out += [Spacer(1, 5 * mm),
                    Paragraph('Discount guardrails', styles['h3']),
                    Spacer(1, 1.4 * mm),
                    Paragraph(
                        f'The maximum discount before the line falls through '
                        f'the {assumptions["min_margin_pct"]:.0f}% margin '
                        f'floor.', styles['small']),
                    Spacer(1, 2 * mm)]
            out.append(_NumberedTable(
                ['#', 'Product', 'Margin', 'Max discount', 'Guidance'],
                [[row['label'][:36], f'{row["margin_pct"]:.1f}%',
                  f'{row["room_pct"]:.1f}%', row['note']]
                 for row in optimization['guardrails']],
                [CONTENT_W * 0.06, CONTENT_W * 0.34, CONTENT_W * 0.10,
                 CONTENT_W * 0.13, CONTENT_W * 0.37],
                palette, styles,
                aligns=['center', 'left', 'right', 'right', 'left'],
            ))

        if optimization['replenishment']:
            out += [Spacer(1, 5 * mm),
                    Paragraph('Replenishment plan', styles['h3']),
                    Spacer(1, 1.4 * mm),
                    Paragraph(
                        f'Economic order quantity at a {assumptions["order_cost"]:,.0f} '
                        f'cost per order, {assumptions["holding_rate"]:.0f}% '
                        f'annual holding cost and a '
                        f'{assumptions["lead_time_days"]:.0f}-day supplier lead '
                        f'time.', styles['small']),
                    Spacer(1, 2 * mm)]
            out.append(_NumberedTable(
                ['#', 'Item', 'On hand', 'Cover', 'Reorder pt', 'Order qty',
                 'Order value'],
                [[row['label'][:32], count(row['on_hand']),
                  ('-' if row['cover_days'] is None else f'{row["cover_days"]}d'),
                  f'{row["reorder_point"]:.0f}', count(row['order_qty']),
                  money(row['order_value'], currency)]
                 for row in optimization['replenishment']],
                [CONTENT_W * 0.06, CONTENT_W * 0.34, CONTENT_W * 0.11,
                 CONTENT_W * 0.10, CONTENT_W * 0.13, CONTENT_W * 0.12,
                 CONTENT_W * 0.14],
                palette, styles,
                aligns=['center', 'left', 'right', 'right', 'right', 'right',
                        'right'],
                total_row=['Total', '', '', '', '', '', 
                           money(optimization['replenishment_value'], currency)],
            ))

        if optimization['markdown']:
            out += [Spacer(1, 5 * mm),
                    Paragraph('Markdown and clearance', styles['h3']),
                    Spacer(1, 1.4 * mm),
                    Paragraph(
                        'Ranked by clearance score (expiry urgency, cover and '
                        'sell-through). The markdown never exceeds the margin '
                        'room on the line.', styles['small']),
                    Spacer(1, 2 * mm)]
            out.append(_NumberedTable(
                ['#', 'Item', 'Expires in', 'Units', 'At cost', 'Score',
                 'Markdown', 'Recovery'],
                [[row['label'][:30], f'{row["days_to_expiry"]}d',
                  count(row['units']), money(row['value'], currency),
                  f'{row["score"]:.0f}', f'{row["markdown_pct"]:.1f}%',
                  money(row['recovery'], currency)]
                 for row in optimization['markdown']],
                [CONTENT_W * 0.05, CONTENT_W * 0.28, CONTENT_W * 0.11,
                 CONTENT_W * 0.10, CONTENT_W * 0.13, CONTENT_W * 0.08,
                 CONTENT_W * 0.11, CONTENT_W * 0.14],
                palette, styles,
                aligns=['center', 'left', 'right', 'right', 'right', 'right',
                        'right', 'right'],
                total_row=['Total', '', '', money(optimization['markdown_at_risk'],
                                                  currency), '', '', '',
                           money(optimization['markdown_recovery'], currency)],
            ))

        if optimization['allocation']:
            out += [Spacer(1, 5 * mm),
                    Paragraph('Stock allocation', styles['h3']),
                    Spacer(1, 2 * mm)]
            out.append(_NumberedTable(
                ['#', 'Location', 'Revenue', 'Index', 'Action', 'Reading'],
                [[row['label'], money(row['value'], currency),
                  f'{row["index"]:.2f}', row['action'], row['detail']]
                 for row in optimization['allocation']],
                [CONTENT_W * 0.06, CONTENT_W * 0.19, CONTENT_W * 0.16,
                 CONTENT_W * 0.08, CONTENT_W * 0.11, CONTENT_W * 0.40],
                palette, styles,
                aligns=['center', 'left', 'right', 'right', 'left', 'left'],
            ))

        if optimization['actions']:
            out += [Spacer(1, 5 * mm),
                    Paragraph('Prioritised action plan', styles['h3']),
                    Spacer(1, 1.4 * mm),
                    Paragraph('Ranked by expected financial impact.',
                              styles['small']),
                    Spacer(1, 2 * mm)]
            for action in optimization['actions']:
                block = (f'<b>{action["rank"]}. {action["title"]}</b> '
                         f'&nbsp;&nbsp;<font color="#1f6f4a">'
                         f'{action["impact_label"]}</font> '
                         f'&nbsp;·&nbsp;{action["effort"]} effort '
                         f'&nbsp;·&nbsp;{action["owner"]}')
                out.append(Paragraph(block, styles['body_b']))
                out.append(Spacer(1, 1 * mm))
                out.append(Paragraph(action['detail'], styles['body']))
                out.append(Spacer(1, 2.6 * mm))

        out += [Spacer(1, 2 * mm),
                Paragraph(
                    f'Assumptions: {assumptions["lead_time_days"]:.0f}-day lead '
                    f'time, {assumptions["order_cost"]:,.0f} cost per order, '
                    f'{assumptions["holding_rate"]:.0f}% holding cost, '
                    f'{assumptions["min_margin_pct"]:.0f}% margin floor, '
                    f'{assumptions["service_level"]:.0f}% service level, '
                    f'{assumptions["target_margin_pct"]:.0f}% target margin. '
                    f'{count(optimization["excluded_unpriced"])} item(s) without '
                    f'a purchase cost were excluded rather than estimated.',
                    styles['small'])]

    elif sid == 'operational_reports':
        operational = dataset.get('operational')
        if not operational:
            return None
        heading('Operational report index',
                operational.get('period_note') or
                'Every report this workspace can produce for the period.')
        out.append(_KpiGrid(
            [{'label': tile['label'], 'value': tile['value'],
              'hint': tile['hint']} for tile in operational['tiles']],
            CONTENT_W, palette, styles, columns=4))
        out += [Spacer(1, 4 * mm),
                Paragraph('Analytical reports', styles['h3']),
                Spacer(1, 1.4 * mm),
                Paragraph('Each figure is the live headline this report would '
                          'show for the selected period, not an example.',
                          styles['small']),
                Spacer(1, 2.4 * mm)]

        for group in operational['analytical_groups']:
            out.append(Paragraph(group['label'], styles['label']))
            out.append(Spacer(1, 1.2 * mm))
            out.append(_NumberedTable(
                ['#', 'Report', 'Live headline', 'Reading'],
                [[row['label'], str(row['headline']), row['note']]
                 for row in group['items']],
                [CONTENT_W * 0.06, CONTENT_W * 0.33, CONTENT_W * 0.26,
                 CONTENT_W * 0.35],
                palette, styles,
                aligns=['center', 'left', 'right', 'left'],
            ))
            out.append(Spacer(1, 4 * mm))

        if operational['tabular_groups']:
            out += [Paragraph('Export-ready report library', styles['h3']),
                    Spacer(1, 1.4 * mm),
                    Paragraph(
                        'Available from the Report Centre with letterhead, '
                        'watermark and totals. Formats: '
                        + ', '.join(operational['formats']) + '.',
                        styles['small']),
                    Spacer(1, 2.4 * mm)]
            for group in operational['tabular_groups']:
                out.append(Paragraph(group['label'], styles['label']))
                out.append(Spacer(1, 1.2 * mm))
                out.append(_NumberedTable(
                    ['#', 'Report', 'What it answers', 'Columns'],
                    [[row['label'], row['description'][:90],
                      str(row['columns'])] for row in group['items']],
                    [CONTENT_W * 0.06, CONTENT_W * 0.30, CONTENT_W * 0.55,
                     CONTENT_W * 0.09],
                    palette, styles,
                    aligns=['center', 'left', 'left', 'center'],
                ))
                out.append(Spacer(1, 3.4 * mm))

    elif sid == 'recommendations':
        from .bi import build_recommendations
        actions = build_recommendations(dataset)
        heading('Findings & recommendations',
                'Each action is triggered by a threshold breached in the '
                'figures above.')
        for index, line in enumerate(actions, start=1):
            number = ParagraphStyle(f'act{index}', parent=styles['body'])
            out.append(Paragraph(
                f'<b>{index}.</b>&nbsp;&nbsp;{line}', number))
            out.append(Spacer(1, 2.4 * mm))

    return out or None

