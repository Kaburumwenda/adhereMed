"""Printable stock-take documents.

Two documents come out of this module, both on the same branded stationery:

* :func:`render_count_sheet_pdf` - the *working* sheet. Page 1 opens with the
  organisation's letterhead (logo, business name, address, contacts) and then
  prints every line with an **empty box** in the "Counted" column, so the page
  can be taken to the aisle and filled in by hand.
* :func:`render_stock_take_register_pdf` - the *record*. The board's posture,
  accuracy and variance analysis as a filed document.

Both share the page furniture of :mod:`inventory.reports.trace_render`, because
the product prints them side by side and a different letterhead would look like
a different system. Deliberate choices worth keeping:

* Page 1 carries the full letterhead; pages 2+ switch to a compact running
  header so the grid keeps its density.
* Money columns disappear entirely (not zeroed) when the caller lacks
  ``stock.cost`` - a priced column reading 0.00 is worse than no column.
* All printed text is ASCII / WinAnsi-safe: Helvetica renders a middot or a
  geometric bullet as a stray glyph, so separators are ``|`` and bullets ``*``.
"""
from __future__ import annotations

import io

from django.utils import timezone
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_RIGHT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import (BaseDocTemplate, CondPageBreak, Flowable, Frame,
                                KeepTogether, NextPageTemplate, PageTemplate,
                                Paragraph, Spacer, Table, TableStyle)

from config.pdf_branding import resolve_palette, tint

from .bi_render import _clip
from .render import (BORDER, CREDIT_BRAND, CREDIT_SITE, HEADER_TEXT, MUTED_TEXT,
                     _NumberedCanvas, _draw_logo, _org_detail_lines,
                     _readable_on)

PAGE = A4
MARGIN = 15 * mm
CONTENT_W = PAGE[0] - 2 * MARGIN

BODY = colors.HexColor('#1E293B')
SOFT = colors.HexColor('#475569')

GOOD = colors.HexColor('#15803d')
BAD = colors.HexColor('#b91c1c')
WARN = colors.HexColor('#b45309')
INFO = colors.HexColor('#1d4ed8')

#: Page 1 letterhead height; the compact running header used on later pages.
LETTERHEAD_H = 34 * mm
RUNNING_H = 12 * mm

STATUS_LABELS = {
    'draft': 'Draft',
    'in_progress': 'Counting',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
}


# ── Formatting ──────────────────────────────────────────────────────────
def money(value, currency='KES'):
    try:
        return f'{currency} {float(value or 0):,.2f}'
    except (TypeError, ValueError):
        return f'{currency} 0.00'


def count(value):
    try:
        return f'{int(round(float(value or 0))):,}'
    except (TypeError, ValueError):
        return '-'


def signed(value):
    try:
        number = int(round(float(value or 0)))
    except (TypeError, ValueError):
        return '0'
    if number == 0:
        return '0'
    return f'{number:+,}'


def pct(value, digits=0):
    try:
        return f'{float(value):.{digits}f}%'
    except (TypeError, ValueError):
        return '-'


def _status(value):
    return STATUS_LABELS.get(value, str(value or '').title())


def _date(value):
    """``iso string | datetime | None`` -> ``15 Oct 2026``."""
    if not value:
        return '-'
    try:
        if isinstance(value, str):
            from datetime import datetime
            value = datetime.fromisoformat(value.replace('Z', '+00:00'))
        local = timezone.localtime(value)
        return local.strftime('%d %b %Y')
    except Exception:
        return str(value)[:16]


def _date_time(value):
    if not value:
        return '-'
    try:
        if isinstance(value, str):
            from datetime import datetime
            value = datetime.fromisoformat(value.replace('Z', '+00:00'))
        return timezone.localtime(value).strftime('%d %b %Y, %H:%M')
    except Exception:
        return str(value)[:20]


# ── Styles ──────────────────────────────────────────────────────────────
def _styles():
    return {
        'h2': ParagraphStyle('h2', fontName='Helvetica-Bold', fontSize=10.4,
                             leading=12.6, textColor=HEADER_TEXT),
        'body': ParagraphStyle('body', fontName='Helvetica', fontSize=8.2,
                               leading=11.4, textColor=BODY),
        'small': ParagraphStyle('small', fontName='Helvetica', fontSize=7,
                                leading=9.4, textColor=SOFT),
        'tiny': ParagraphStyle('tiny', fontName='Helvetica', fontSize=6.2,
                               leading=8.4, textColor=MUTED_TEXT),
        'label': ParagraphStyle('label', fontName='Helvetica-Bold', fontSize=6.2,
                                leading=8.2, textColor=MUTED_TEXT),
        'cell': ParagraphStyle('cell', fontName='Helvetica', fontSize=6.6,
                               leading=8.4, textColor=BODY),
        'cell_r': ParagraphStyle('cell_r', fontName='Helvetica', fontSize=6.6,
                                 leading=8.4, textColor=BODY,
                                 alignment=TA_RIGHT),
        'cell_b': ParagraphStyle('cell_b', fontName='Helvetica-Bold',
                                 fontSize=6.6, leading=8.4,
                                 textColor=HEADER_TEXT),
        'cell_br': ParagraphStyle('cell_br', fontName='Helvetica-Bold',
                                  fontSize=6.6, leading=8.4,
                                  textColor=HEADER_TEXT, alignment=TA_RIGHT),
        'note': ParagraphStyle('note', fontName='Helvetica', fontSize=6.4,
                               leading=8.6, textColor=MUTED_TEXT),
    }


# ── Flowables ───────────────────────────────────────────────────────────
class _Heading(Flowable):
    """Numbered section heading with a brand rule."""

    def __init__(self, number, title, subtitle, width, palette):
        super().__init__()
        self.number = number
        self.title = title or ''
        self.subtitle = subtitle or ''
        self.width = width
        self.palette = palette
        self.height = (13 if self.subtitle else 10) * mm

    def wrap(self, aw, ah):
        return self.width, self.height

    def draw(self):
        c = self.canv
        pal = self.palette
        c.saveState()
        c.setFillColor(pal['primary'])
        c.roundRect(0, self.height - 6.2 * mm, 9.4 * mm, 6.2 * mm, 1.2 * mm,
                    stroke=0, fill=1)
        c.setFillColor(_readable_on(pal['primary']))
        c.setFont('Helvetica-Bold', 7.4)
        c.drawCentredString(4.7 * mm, self.height - 4.4 * mm,
                            f'{self.number:02d}')

        c.setFillColor(HEADER_TEXT)
        c.setFont('Helvetica-Bold', 10)
        title = _clip(c, self.title, 'Helvetica-Bold', 10,
                      self.width - 18 * mm)
        c.drawString(12 * mm, self.height - 4.6 * mm, title)

        c.setStrokeColor(tint(pal['primary'], 0.72))
        c.setLineWidth(0.5)
        c.line(12 * mm + c.stringWidth(title, 'Helvetica-Bold', 10) + 3 * mm,
               self.height - 3 * mm, self.width, self.height - 3 * mm)

        if self.subtitle:
            c.setFillColor(SOFT)
            c.setFont('Helvetica', 6.8)
            c.drawString(12 * mm, self.height - 8.4 * mm,
                         _clip(c, self.subtitle, 'Helvetica', 6.8,
                               self.width - 12 * mm))
        c.restoreState()


class _Tiles(Flowable):
    """Summary tiles - four or six across, tone-banded at the top edge."""

    def __init__(self, tiles, width, palette, columns=4, tile_h=17 * mm):
        super().__init__()
        self.tiles = list(tiles or [])
        self.width = width
        self.palette = palette
        self.columns = max(1, min(columns, len(self.tiles) or 1))
        self.tile_h = tile_h
        rows = (len(self.tiles) + self.columns - 1) // self.columns
        self.height = rows * tile_h + max(rows - 1, 0) * 2.2 * mm

    def wrap(self, aw, ah):
        return self.width, self.height

    def draw(self):
        c = self.canv
        pal = self.palette
        gap = 2.4 * mm
        tile_w = (self.width - gap * (self.columns - 1)) / self.columns
        for index, tile in enumerate(self.tiles):
            row, col = divmod(index, self.columns)
            x = col * (tile_w + gap)
            y = self.height - (row + 1) * self.tile_h - row * 2.2 * mm
            tone = tile.get('tone') or pal['primary']

            c.setFillColor(tint(pal['primary'], 0.965))
            c.setStrokeColor(tint(pal['primary'], 0.84))
            c.setLineWidth(0.4)
            c.roundRect(x, y, tile_w, self.tile_h, 1.8 * mm, stroke=1, fill=1)
            c.setFillColor(tone)
            c.roundRect(x, y + self.tile_h - 0.7 * mm, tile_w, 0.7 * mm,
                        0.35 * mm, stroke=0, fill=1)

            c.setFillColor(MUTED_TEXT)
            c.setFont('Helvetica-Bold', 5.6)
            c.drawString(x + 2.4 * mm, y + self.tile_h - 4.6 * mm,
                         str(tile['label']).upper()[:26])

            value = str(tile.get('value', '-'))
            size = 11.6 if len(value) <= 12 else 9.4 if len(value) <= 17 else 7.6
            c.setFillColor(tile.get('value_color') or HEADER_TEXT)
            c.setFont('Helvetica-Bold', size)
            c.drawString(x + 2.4 * mm, y + self.tile_h - 9.8 * mm, value[:22])

            hint = str(tile.get('hint') or '')
            if hint:
                c.setFillColor(SOFT)
                c.setFont('Helvetica', 5.4)
                c.drawString(x + 2.4 * mm, y + 2.6 * mm,
                             _clip(c, hint, 'Helvetica', 5.4,
                                   tile_w - 4.8 * mm))


class _ProgressBar(Flowable):
    """One labelled progress bar - paperwork completion per warehouse."""

    def __init__(self, rows, width, palette):
        super().__init__()
        self.rows = list(rows or [])
        self.width = width
        self.palette = palette
        self.row_h = 9.4 * mm
        self.height = max(len(self.rows), 1) * self.row_h

    def wrap(self, aw, ah):
        return self.width, self.height

    def draw(self):
        c = self.canv
        pal = self.palette
        if not self.rows:
            c.saveState()
            c.setFillColor(SOFT)
            c.setFont('Helvetica', 7)
            c.drawString(0, self.height - 5 * mm, 'No warehouse activity yet.')
            c.restoreState()
            return

        c.saveState()
        for index, row in enumerate(self.rows):
            y = self.height - (index + 1) * self.row_h
            progress = float(row.get('pct') or 0)
            tone = GOOD if progress >= 100 else INFO if progress >= 50 \
                else WARN if progress > 0 else MUTED_TEXT

            c.setFillColor(HEADER_TEXT)
            c.setFont('Helvetica-Bold', 7)
            c.drawString(0, y + 4.6 * mm,
                         _clip(c, str(row.get('name') or ''), 'Helvetica-Bold',
                               7, self.width * 0.42))
            c.setFillColor(tone)
            c.setFont('Helvetica-Bold', 6.6)
            c.drawRightString(self.width, y + 4.6 * mm, f'{progress:.0f}%')

            bar_y = y + 1.4 * mm
            bar_h = 1.7 * mm
            c.setFillColor(tint(pal['primary'], 0.90))
            c.roundRect(0, bar_y, self.width, bar_h, bar_h / 2, stroke=0, fill=1)
            filled = max(0.0, min(1.0, progress / 100.0)) * self.width
            if filled > 0.4:
                c.setFillColor(tone)
                c.roundRect(0, bar_y, filled, bar_h, bar_h / 2, stroke=0, fill=1)

            c.setFillColor(MUTED_TEXT)
            c.setFont('Helvetica', 5.8)
            detail = str(row.get('detail') or '')
            if detail:
                c.drawString(0, y - 0.2 * mm, _clip(c, detail, 'Helvetica', 5.8,
                                                    self.width * 0.9))
        c.restoreState()


# ── Document wrapper (letterhead + footer) ──────────────────────────────
class _SheetDoc:
    """Letterhead, running header and footer for the stock-take documents."""

    def __init__(self, *, palette, org, logo_path, business_name, title,
                 subtitle, stamp, footer_label, prepared_by='',
                 generated_at=None, right_label=''):
        self.palette = palette
        self.org = org or {}
        self.logo_path = logo_path
        self.business_name = business_name or CREDIT_BRAND
        self.title = title or ''
        self.subtitle = subtitle or ''
        self.stamp = stamp
        self.footer_label = footer_label
        self.prepared_by = prepared_by or ''
        self.right_label = right_label or self.business_name
        self.generated_at = generated_at or timezone.localtime(timezone.now())

    # ----- page 1: full letterhead, logo + business details ------------
    def draw_letterhead(self, canv):
        pal = self.palette
        width, height = PAGE
        top = height - MARGIN

        canv.saveState()

        # Brand rule along the top edge - the printed-document signature.
        canv.setFillColor(pal['primary'])
        canv.rect(0, height - 3.2 * mm, width, 3.2 * mm, stroke=0, fill=1)
        canv.setFillColor(pal['accent'])
        canv.rect(0, height - 4.1 * mm, width, 0.9 * mm, stroke=0, fill=1)

        # Logo chip + organisation identity.
        box = 15 * mm
        centre_y = top - box / 2.0 - 2 * mm
        text_x = _draw_logo(canv, MARGIN, centre_y, box, self.logo_path,
                            chip_color=tint(pal['primary'], 0.55))
        text_x = max(text_x, MARGIN + box) + 4 * mm

        canv.setFillColor(HEADER_TEXT)
        canv.setFont('Helvetica-Bold', 11.6)
        canv.drawString(text_x, top - 6.4 * mm,
                        _clip(canv, self.business_name, 'Helvetica-Bold', 11.6,
                              width - MARGIN - text_x))

        canv.setFillColor(MUTED_TEXT)
        canv.setFont('Helvetica', 6.6)
        y = top - 10.4 * mm
        for line in _org_detail_lines(self.org)[:2]:
            canv.drawString(text_x, y,
                            _clip(canv, line, 'Helvetica', 6.6,
                                  width - MARGIN - text_x - 40 * mm))
            y -= 3.2 * mm

        # Right-hand document stamp.
        stamp_x = width - MARGIN
        canv.setFillColor(pal['secondary'])
        canv.setFont('Helvetica-Bold', 6.2)
        canv.drawRightString(stamp_x, top - 5.6 * mm, self.stamp)
        canv.setFillColor(MUTED_TEXT)
        canv.setFont('Helvetica', 6.2)
        canv.drawRightString(stamp_x, top - 9 * mm,
                             self.generated_at.strftime('%d %b %Y  %H:%M'))
        website = str(self.org.get('website') or CREDIT_SITE)
        canv.drawRightString(stamp_x, top - 12.4 * mm,
                             website.replace('https://', '')
                             .replace('http://', '').rstrip('/')[:38])

        # Document title + scope line.
        canv.setFillColor(HEADER_TEXT)
        canv.setFont('Helvetica-Bold', 15.5)
        canv.drawString(MARGIN, top - 24 * mm,
                        _clip(canv, self.title, 'Helvetica-Bold', 15.5,
                              CONTENT_W * 0.74))

        canv.setFillColor(SOFT)
        canv.setFont('Helvetica', 8)
        canv.drawString(MARGIN, top - 29 * mm,
                        _clip(canv, self.subtitle, 'Helvetica', 8,
                              CONTENT_W * 0.9))

        canv.setStrokeColor(tint(pal['primary'], 0.55))
        canv.setLineWidth(0.7)
        canv.line(MARGIN, top - LETTERHEAD_H + 3 * mm,
                  width - MARGIN, top - LETTERHEAD_H + 3 * mm)
        canv.restoreState()

    # ----- pages 2+: compact running header ----------------------------
    def draw_running_header(self, canv):
        pal = self.palette
        width, height = PAGE
        top = height - MARGIN + 2 * mm
        canv.saveState()
        canv.setFillColor(pal['primary'])
        canv.rect(0, height - 3.2 * mm, width, 3.2 * mm, stroke=0, fill=1)

        canv.setFillColor(HEADER_TEXT)
        canv.setFont('Helvetica-Bold', 7.6)
        canv.drawString(MARGIN, top,
                        _clip(canv, self.title, 'Helvetica-Bold', 7.6,
                              CONTENT_W * 0.55))
        canv.setFillColor(MUTED_TEXT)
        canv.setFont('Helvetica', 6.6)
        canv.drawRightString(width - MARGIN, top,
                             _clip(canv, self.right_label, 'Helvetica', 6.6,
                                   CONTENT_W * 0.42))
        canv.setStrokeColor(tint(pal['primary'], 0.6))
        canv.setLineWidth(0.4)
        canv.line(MARGIN, top - 2 * mm, width - MARGIN, top - 2 * mm)
        canv.restoreState()

    # ----- footer ------------------------------------------------------
    def draw_footer(self, canv, page, total):
        pal = self.palette
        width, _height = PAGE
        y = MARGIN - 5 * mm
        canv.saveState()
        canv.setStrokeColor(tint(pal['primary'], 0.7))
        canv.setLineWidth(0.35)
        canv.line(MARGIN, y + 3.4 * mm, width - MARGIN, y + 3.4 * mm)

        canv.setFillColor(MUTED_TEXT)
        canv.setFont('Helvetica', 6)
        canv.drawString(MARGIN, y,
                        _clip(canv, f'{self.business_name}  |  {self.footer_label}',
                              'Helvetica', 6, CONTENT_W * 0.40))

        # Plain text, not a link: an annotation added from draw_footer runs after
        # _endBuild and reportlab raises a counter/id mismatch.
        canv.setFillColor(tint(pal['primary'], 0.25))
        canv.setFont('Helvetica-Bold', 6)
        canv.drawCentredString(width / 2.0, y,
                               f'Powered by {CREDIT_BRAND}  |  {CREDIT_SITE}')

        canv.setFillColor(MUTED_TEXT)
        canv.setFont('Helvetica', 6)
        canv.drawRightString(width - MARGIN, y, f'Page {page} of {total}')
        canv.restoreState()


def _build(*, doc_info, story):
    """Assemble the document: page-1 letterhead, running header elsewhere."""
    buffer = io.BytesIO()
    doc = BaseDocTemplate(
        buffer, pagesize=PAGE,
        leftMargin=MARGIN, rightMargin=MARGIN,
        topMargin=MARGIN, bottomMargin=MARGIN + 4 * mm,
        title=doc_info.title,
        author=doc_info.business_name,
        subject=doc_info.subtitle or doc_info.title,
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

    doc.addPageTemplates([
        PageTemplate(id='first', frames=[first_frame],
                     onPage=lambda canv, _doc: doc_info.draw_letterhead(canv)),
        PageTemplate(id='later', frames=[later_frame],
                     onPage=lambda canv, _doc: doc_info.draw_running_header(canv)),
    ])

    def _canvas(*args, **kwargs):
        return _NumberedCanvas(*args, report_doc=doc_info, **kwargs)

    doc.build([NextPageTemplate('later')] + story, canvasmaker=_canvas)
    return buffer.getvalue()


# ── Shared table styling ────────────────────────────────────────────────
def _table(data, widths, palette, *, align_rows=None, box_column=None,
           header_rows=1, font_size=6.6):
    """Brand-tinted table with an optional per-cell write-in box column.

    ``box_column`` draws a border around every *body* cell in that column so a
    printed sheet has something to write in.
    """
    table = Table(data, colWidths=widths, repeatRows=header_rows)
    style = [
        ('BACKGROUND', (0, 0), (-1, header_rows - 1),
         tint(palette['primary'], 0.90)),
        ('TEXTCOLOR', (0, 0), (-1, header_rows - 1), HEADER_TEXT),
        ('FONTNAME', (0, 0), (-1, header_rows - 1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, header_rows - 1), 6.1),
        ('FONTSIZE', (0, header_rows), (-1, -1), font_size),
        ('FONTNAME', (0, header_rows), (-1, -1), 'Helvetica'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 2.4),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 2.4),
        ('LEFTPADDING', (0, 0), (-1, -1), 3.4),
        ('RIGHTPADDING', (0, 0), (-1, -1), 3.4),
        ('LINEBELOW', (0, 0), (-1, header_rows - 1), 0.5,
         tint(palette['primary'], 0.45)),
        ('LINEBELOW', (0, header_rows), (-1, -1), 0.25, BORDER),
        ('ROWBACKGROUNDS', (0, header_rows), (-1, -1),
         [colors.white, tint(palette['primary'], 0.975)]),
    ]
    for row_index, alignments in (align_rows or {}).items():
        for col_index, align in alignments.items():
            style.append(('ALIGN', (col_index, row_index),
                          (col_index, row_index), align))

    if box_column is not None:
        for row_index in range(header_rows, len(data)):
            style.append(('BOX', (box_column, row_index),
                          (box_column, row_index), 0.5,
                          colors.HexColor('#94A3B8')))
    table.setStyle(TableStyle(style))
    return table


def _kpi_value_tone(value):
    """Green when a variance is zero, amber/red when it is not."""
    try:
        number = float(value or 0)
    except (TypeError, ValueError):
        return None
    if abs(number) < 0.0001:
        return GOOD
    return WARN if abs(number) < 1000 else BAD


# ══════════════════════════════════════════════════════════════════════
#  Document 1 - the count sheet
# ══════════════════════════════════════════════════════════════════════
def render_count_sheet_pdf(*, sheet, lines, org=None, logo_path=None,
                           palette=None, business_name='', prepared_by='',
                           show_cost=True, currency='KES') -> bytes:
    """The sheet as a printable count form.

    ``sheet`` is the row :func:`inventory.services.stock_take._sheet` builds;
    ``lines`` are plain dicts (``name``, ``unit``, ``category``, ``expected``,
    ``counted``, ``variance``, ``value``, ``note``) so the renderer never
    touches the database.
    """
    palette = palette or resolve_palette(None)
    styles = _styles()
    sheet = sheet or {}
    lines = list(lines or [])

    subtitle_parts = [
        sheet.get('branch_name') or 'All warehouses',
        sheet.get('category_name') or 'All categories',
        _status(sheet.get('status')),
    ]
    doc_info = _SheetDoc(
        palette=palette, org=org, logo_path=logo_path,
        business_name=business_name,
        title=f"{sheet.get('reference') or 'Count sheet'}  -  "
              f"{sheet.get('name') or 'Stock take'}",
        subtitle='  |  '.join(part for part in subtitle_parts if part),
        stamp='PHYSICAL COUNT',
        footer_label='Stock take count sheet',
        prepared_by=prepared_by,
        right_label=f"{sheet.get('reference') or ''}  |  "
                    f"{sheet.get('branch_name') or 'All warehouses'}",
    )

    story = []
    section = 1

    # ── 01 · Sheet identity ────────────────────────────────────────────
    identity = [
        ['Reference', sheet.get('reference') or '-',
         'Warehouse', sheet.get('branch_name') or 'All warehouses'],
        ['Status', _status(sheet.get('status')),
         'Category', sheet.get('category_name') or 'All categories'],
        ['Opened by', sheet.get('created_by_name') or '-',
         'Opened', _date_time(sheet.get('created_at'))],
        ['Completed by', sheet.get('completed_by_name') or '-',
         'Completed', _date_time(sheet.get('completed_at'))],
    ]
    if sheet.get('notes'):
        identity.append(['Notes', str(sheet['notes'])[:160], '', ''])

    identity_data = []
    span_rows = []
    for row_index, (left_label, left_value, right_label, right_value) in enumerate(identity):
        identity_data.append([
            Paragraph(left_label, styles['label']),
            Paragraph(_escape(str(left_value)), styles['cell_b']),
            Paragraph(right_label, styles['label']) if right_label else '',
            Paragraph(_escape(str(right_value)), styles['cell_b']) if right_label else '',
        ])
        if not right_label:
            span_rows.append(row_index)

    col_w = [26 * mm, CONTENT_W / 2 - 26 * mm - 2 * mm,
             26 * mm, CONTENT_W / 2 - 26 * mm - 2 * mm]
    identity_table = Table(identity_data, colWidths=col_w)
    identity_style = [
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 2.2),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 2.2),
        ('LEFTPADDING', (0, 0), (-1, -1), 3),
        ('RIGHTPADDING', (0, 0), (-1, -1), 3),
        ('BACKGROUND', (0, 0), (-1, -1), tint(palette['primary'], 0.975)),
        ('BOX', (0, 0), (-1, -1), 0.4, tint(palette['primary'], 0.82)),
        ('LINEBELOW', (0, 0), (-1, -2), 0.25, tint(palette['primary'], 0.88)),
        ('LINEAFTER', (1, 0), (1, -1), 0.25, tint(palette['primary'], 0.88)),
    ]
    for row_index in span_rows:
        # A note is one wide value, not a label/value/label/value quad.
        identity_style.append(('SPAN', (1, row_index), (3, row_index)))
    identity_table.setStyle(TableStyle(identity_style))

    story += [
        _Heading(section, 'Sheet identity',
                 'What this document covers and who is accountable for it.',
                 CONTENT_W, palette),
        Spacer(1, 1.8 * mm),
        identity_table,
    ]
    section += 1

    # ── 02 · Posture tiles ─────────────────────────────────────────────
    counted = int(sheet.get('counted') or 0)
    total = int(sheet.get('lines') or 0)
    outstanding = max(total - counted, 0)
    tiles = [
        {'label': 'Lines on sheet', 'value': count(total),
         'hint': f"{sheet.get('progress_pct', 0)}% counted"},
        {'label': 'Counted', 'value': count(counted),
         'hint': 'with a physical figure', 'tone': GOOD},
        {'label': 'Still blank', 'value': count(outstanding),
         'hint': 'awaiting a count',
         'tone': WARN if outstanding else GOOD},
        {'label': 'Net variance', 'value': signed(sheet.get('net_variance')),
         'hint': f"{count(sheet.get('abs_variance'))} units absolute",
         'tone': _kpi_value_tone(sheet.get('net_variance'))},
    ]
    if show_cost:
        tiles += [
            {'label': 'Value impact',
             'value': money(sheet.get('variance_value'), currency),
             'hint': 'net overage less shortage',
             'tone': _kpi_value_tone(sheet.get('variance_value'))},
            {'label': 'Overage', 'value': money(sheet.get('overage_value'), currency),
             'hint': 'counted above the book', 'tone': GOOD},
            {'label': 'Shortage',
             'value': money(sheet.get('shortage_value'), currency),
             'hint': 'counted below the book', 'tone': BAD},
            {'label': 'Value at stake',
             'value': money(sheet.get('value_at_stake'), currency),
             'hint': 'book quantity at cost'},
        ]

    if sheet.get('accuracy_pct') is not None:
        tiles.append({
            'label': 'Quantity accuracy',
            'value': pct(sheet.get('accuracy_pct'), 1),
            'hint': f"{sheet.get('mismatched', 0)} line(s) off the book",
            'tone': INFO,
        })

    story += [
        CondPageBreak(58 * mm),
        Spacer(1, 5 * mm),
        _Heading(section, 'Count summary',
                 'The posture of this sheet at the moment it was printed.',
                 CONTENT_W, palette),
        Spacer(1, 1.8 * mm),
        _Tiles(tiles, CONTENT_W, palette, columns=4),
    ]
    section += 1

    # ── 03 · The counting grid ─────────────────────────────────────────
    # Column order matters: ``Counted`` is the write-in column, so its index is
    # looked up by header rather than hard-coded below.
    headers = ['#', 'Item', 'Unit', 'Book qty', 'Counted', 'Variance']
    if show_cost:
        headers += ['Value', 'Note']
        note_w = 34 * mm
        fixed_w = [9 * mm, None, 13 * mm, 17 * mm, 24 * mm, 17 * mm,
                   22 * mm, note_w]
    else:
        headers += ['Note']
        note_w = 46 * mm
        fixed_w = [9 * mm, None, 13 * mm, 17 * mm, 24 * mm, 17 * mm, note_w]

    # The item column absorbs whatever is left after the fixed columns.
    item_w = CONTENT_W - sum(width for width in fixed_w if width is not None)
    widths = [item_w if width is None else width for width in fixed_w]

    data = [headers]
    blank_boxes = []
    for index, line in enumerate(lines, start=1):
        counted_value = line.get('counted')
        row = [
            str(index),
            Paragraph(str(line.get('name') or ''), styles['cell']),
            str(line.get('unit') or ''),
            count(line.get('expected')),
            '' if counted_value is None else count(counted_value),
            '' if line.get('variance') is None else signed(line.get('variance')),
        ]
        if show_cost:
            row += ['' if line.get('value') is None
                    else money(line.get('value'), currency),
                    Paragraph(str(line.get('note') or ''), styles['cell'])]
        else:
            row += [Paragraph(str(line.get('note') or ''), styles['cell'])]
        if counted_value is None:
            blank_boxes.append(index)
        data.append(row)

    if not lines:
        data.append(['', Paragraph('This sheet has no count lines.', styles['cell']),
                     '', '', '', '']
                    + (['', ''] if show_cost else ['']))

    box_column = headers.index('Counted')
    numeric_cols = [3, 4, 5]
    align = {}
    for row_index in range(1, len(data)):
        align[row_index] = {col: 'RIGHT' for col in numeric_cols
                            if col < len(headers)}
        if show_cost:
            align[row_index][headers.index('Value')] = 'RIGHT'
    align[0] = {}

    grid = _table(data, widths, palette, align_rows=align,
                  box_column=box_column)
    # KeepTogether: a section heading alone at the foot of a page reads as a
    # rendering bug. If the grid is taller than a whole page reportlab emits it
    # normally and splits it, which is exactly right for a long catalogue.
    story += [
        KeepTogether([
            Spacer(1, 5 * mm),
            _Heading(
                section, 'Count lines',
                'Write the physical quantity in the Counted column, then '
                'reconcile in the application.' if blank_boxes
                else 'Every line already carries a physical count.',
                CONTENT_W, palette),
            Spacer(1, 1.8 * mm),
            grid,
        ]),
        Spacer(1, 2 * mm),
        Paragraph(
            'Variance = counted minus book quantity. Nothing is posted to the '
            'ledger until the sheet is completed, so a variance written on this '
            'page has no effect on stock.', styles['note']),
    ]
    section += 1

    # ── 04 · Sign-off ──────────────────────────────────────────────────
    sign_data = [[
        Paragraph('Counted by', styles['label']),
        Paragraph('Verified by', styles['label']),
        Paragraph('Date', styles['label']),
    ], ['', '', '']]
    sign = Table(sign_data, colWidths=[CONTENT_W * 0.4, CONTENT_W * 0.4,
                                       CONTENT_W * 0.2], rowHeights=[6 * mm, 12 * mm])
    sign.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'BOTTOM'),
        ('LINEBELOW', (0, 1), (-1, 1), 0.6, colors.HexColor('#94A3B8')),
        ('LEFTPADDING', (0, 0), (-1, -1), 0),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
    ]))

    printed_by = prepared_by or sheet.get('created_by_name') or ''
    story += [
        CondPageBreak(46 * mm),
        Spacer(1, 6 * mm),
        _Heading(section, 'Sign-off',
                 'A filed count sheet needs two signatures and a date.',
                 CONTENT_W, palette),
        Spacer(1, 2 * mm),
        sign,
        Spacer(1, 1.5 * mm),
        Paragraph(
            f'Printed {doc_info.generated_at.strftime("%d %b %Y, %H:%M")}'
            + (f' by {printed_by}' if printed_by else '')
            + f'  |  {len(lines)} line(s) on this sheet.', styles['note']),
    ]

    return _build(doc_info=doc_info, story=story)


# ══════════════════════════════════════════════════════════════════════
#  Document 2 - the register
# ══════════════════════════════════════════════════════════════════════
def render_stock_take_register_pdf(*, payload, org=None, logo_path=None,
                                   palette=None, business_name='',
                                   prepared_by='', show_cost=True,
                                   currency='KES', branch_label='',
                                   window_days=365) -> bytes:
    """The board as a document: posture, accuracy, sheets and variance."""
    palette = palette or resolve_palette(None)
    styles = _styles()
    payload = payload or {}
    summary = dict(payload.get('summary') or {})
    sheets = list(payload.get('sheets') or [])
    leaders = list(payload.get('variance_leaders') or [])
    by_category = list(payload.get('by_category') or [])
    by_branch = list(payload.get('by_branch') or [])
    trend = list(payload.get('accuracy_trend') or [])

    window_days = int(window_days or summary.get('window_days') or 365)
    scope = branch_label or 'All warehouses'

    doc_info = _SheetDoc(
        palette=palette, org=org, logo_path=logo_path,
        business_name=business_name,
        title='Stock Take Register',
        subtitle=f'{scope}  |  Physical inventory counts  |  '
                 f'Accuracy window {window_days} days',
        stamp='STOCK TAKE',
        footer_label='Stock take register',
        prepared_by=prepared_by,
        right_label=f'{scope}  |  {len(sheets)} sheet(s)',
    )

    story = []
    section = 1

    # ── 01 · Posture ───────────────────────────────────────────────────
    open_sheets = int(summary.get('open_sheets') or 0)
    outstanding = int(summary.get('open_outstanding') or 0)
    accuracy = summary.get('accuracy_pct')

    tiles = [
        {'label': 'Sheets on file', 'value': count(summary.get('sheets_total')),
         'hint': f"{int(summary.get('completed_sheets') or 0)} completed"},
        {'label': 'Open sheets', 'value': count(open_sheets),
         'hint': 'paperwork still counting',
         'tone': WARN if open_sheets else GOOD},
        {'label': 'Paperwork done', 'value': pct(summary.get('open_progress_pct')),
         'hint': f"{count(summary.get('open_counted'))} of "
                 f"{count(summary.get('open_lines'))} line(s)",
         'tone': _paper_tone(summary.get('open_progress_pct'))},
        {'label': 'Still uncounted', 'value': count(outstanding),
         'hint': 'lines awaiting a physical count',
         'tone': BAD if outstanding else GOOD},
    ]
    if show_cost:
        tiles += [
            {'label': 'Value on the tables',
             'value': money(summary.get('open_value_at_stake'), currency),
             'hint': 'book quantity at cost, open sheets'},
            {'label': 'Open variance',
             'value': money(summary.get('open_variance_value'), currency),
             'hint': 'counted so far, net',
             'tone': _kpi_value_tone(summary.get('open_variance_value'))},
            {'label': 'Overage (window)',
             'value': money(summary.get('overage_value'), currency),
             'hint': 'counted above the book', 'tone': GOOD},
            {'label': 'Shortage (window)',
             'value': money(summary.get('shortage_value'), currency),
             'hint': 'counted below the book', 'tone': BAD},
        ]
    tiles.append({
        'label': 'Quantity accuracy',
        'value': pct(accuracy, 1) if accuracy is not None else '-',
        'hint': f"{pct(summary.get('exact_pct'), 1)} exact over "
                f"{count(summary.get('scored_lines'))} line(s)"
                if summary.get('scored_lines') else 'no completed counts yet',
        'tone': _accuracy_tone(accuracy),
    })
    tiles.append({
        'label': 'Average count time',
        'value': _duration(summary.get('avg_duration_hours')),
        'hint': 'opened to completed',
    })

    story += [
        _Heading(section, 'Posture',
                 'Where the count programme stands right now.', CONTENT_W,
                 palette),
        Spacer(1, 1.8 * mm),
        _Tiles(tiles, CONTENT_W, palette, columns=4),
    ]
    section += 1

    # ── 02 · Sheets ────────────────────────────────────────────────────
    headers = ['#', 'Sheet', 'Warehouse', 'Status', 'Lines', 'Counted',
               'Blank', 'Net var.']
    if show_cost:
        headers += ['Value']
    headers += ['Opened', 'Completed']

    # Sheet name is the flexible column: everything else is a fixed measure.
    fixed_w = [8 * mm, None, 24 * mm, 15 * mm, 10 * mm, 12 * mm, 10 * mm,
               13 * mm]
    if show_cost:
        fixed_w.append(19 * mm)
    fixed_w += [17 * mm, 17 * mm]
    sheet_w = max(CONTENT_W - sum(w for w in fixed_w if w is not None), 30 * mm)
    widths = [sheet_w if w is None else w for w in fixed_w]

    data = [headers]
    for index, sheet in enumerate(sheets, start=1):
        row = [
            str(index),
            Paragraph(f"{sheet.get('reference') or ''}<br/>"
                      f"<font size=5.6 color='#64748B'>"
                      f"{_escape(sheet.get('name') or '')}</font>",
                      styles['cell']),
            Paragraph(_escape(sheet.get('branch_name') or 'All warehouses'),
                      styles['cell']),
            _status(sheet.get('status')),
            count(sheet.get('lines')),
            count(sheet.get('counted')),
            count(sheet.get('outstanding')),
            signed(sheet.get('net_variance')),
        ]
        if show_cost:
            row.append(money(sheet.get('variance_value'), currency))
        row += [_date(sheet.get('created_at')),
                _date(sheet.get('completed_at'))]
        data.append(row)

    if not sheets:
        empty = ['', Paragraph('No count sheet has been opened yet.',
                               styles['cell'])]
        empty += [''] * (len(headers) - 2)
        data.append(empty)

    align = {}
    for row_index in range(1, len(data)):
        align[row_index] = {
            headers.index('Lines'): 'RIGHT',
            headers.index('Counted'): 'RIGHT',
            headers.index('Blank'): 'RIGHT',
            headers.index('Net var.'): 'RIGHT',
        }
        if show_cost:
            align[row_index][headers.index('Value')] = 'RIGHT'

    story += [
        KeepTogether([
            Spacer(1, 5 * mm),
            _Heading(section, 'Count sheets',
                     'Open paperwork first, then the most recently closed '
                     'sheets.', CONTENT_W, palette),
            Spacer(1, 1.8 * mm),
            _table(data, widths, palette, align_rows=align),
        ]),
    ]
    section += 1

    # ── 03 · Accuracy trend ────────────────────────────────────────────
    if trend:
        trend_headers = ['#', 'Sheet', 'Completed', 'Accuracy', 'Exact lines',
                         'Units off']
        if show_cost:
            trend_headers.append('Value')
        trend_fixed = [8 * mm, None, 30 * mm, 20 * mm, 24 * mm, 22 * mm]
        if show_cost:
            trend_fixed.append(24 * mm)
        trend_sheet = max(
            CONTENT_W - sum(w for w in trend_fixed if w is not None), 34 * mm)
        trend_widths = [trend_sheet if w is None else w for w in trend_fixed]

        trend_data = [trend_headers]
        for index, point in enumerate(trend, start=1):
            row = [
                str(index),
                Paragraph(f"{point.get('reference') or ''}<br/>"
                          f"<font size=5.6 color='#64748B'>"
                          f"{_escape(point.get('name') or '')}</font>",
                          styles['cell']),
                _date(point.get('completed_at')),
                pct(point.get('accuracy_pct'), 1)
                if point.get('accuracy_pct') is not None else '-',
                pct(point.get('exact_pct'), 1)
                if point.get('exact_pct') is not None else '-',
                count(point.get('abs_variance')),
            ]
            if show_cost:
                row.append(money(point.get('variance_value'), currency))
            trend_data.append(row)

        trend_align = {}
        for row_index in range(1, len(trend_data)):
            trend_align[row_index] = {
                trend_headers.index('Accuracy'): 'RIGHT',
                trend_headers.index('Exact lines'): 'RIGHT',
                trend_headers.index('Units off'): 'RIGHT',
            }
            if show_cost:
                trend_align[row_index][trend_headers.index('Value')] = 'RIGHT'

        story += [
            KeepTogether([
                Spacer(1, 5 * mm),
                _Heading(section, 'Accuracy by completed count',
                         'Quantity accuracy = 100 less the absolute variance as a '
                         'share of the book. Exact lines matched to the digit.',
                         CONTENT_W, palette),
                Spacer(1, 1.8 * mm),
                _table(trend_data, trend_widths, palette, align_rows=trend_align),
            ]),
        ]
        section += 1

    # ── 04 · Largest variances ─────────────────────────────────────────
    leader_headers = ['#', 'Item', 'Sheet', 'Book', 'Counted', 'Variance']
    if show_cost:
        leader_headers.append('Value')
    leader_fixed = [8 * mm, None, 22 * mm, 17 * mm, 19 * mm, 19 * mm]
    if show_cost:
        leader_fixed.append(24 * mm)
    leader_item = max(
        CONTENT_W - sum(w for w in leader_fixed if w is not None), 40 * mm)
    leader_widths = [leader_item if w is None else w for w in leader_fixed]

    leader_data = [leader_headers]
    for index, row in enumerate(leaders[:20], start=1):
        entry = [
            str(index),
            Paragraph(f"{_escape(row.get('name') or '')}<br/>"
                      f"<font size=5.6 color='#64748B'>"
                      f"{_escape(row.get('category_name') or '')}</font>",
                      styles['cell']),
            row.get('reference') or '',
            count(row.get('expected')),
            count(row.get('counted')),
            signed(row.get('variance')),
        ]
        if show_cost:
            entry.append(money(row.get('variance_value'), currency))
        leader_data.append(entry)

    if not leaders:
        empty = ['', Paragraph('No variance recorded in the window.',
                               styles['cell'])]
        empty += [''] * (len(leader_headers) - 2)
        leader_data.append(empty)

    leader_align = {}
    for row_index in range(1, len(leader_data)):
        leader_align[row_index] = {
            leader_headers.index('Book'): 'RIGHT',
            leader_headers.index('Counted'): 'RIGHT',
            leader_headers.index('Variance'): 'RIGHT',
        }
        if show_cost:
            leader_align[row_index][leader_headers.index('Value')] = 'RIGHT'

    story += [
        KeepTogether([
            Spacer(1, 5 * mm),
            _Heading(section, 'Largest variances',
                     'Where the shelf and the book disagreed most, largest '
                     'first.', CONTENT_W, palette),
            Spacer(1, 1.8 * mm),
            _table(leader_data, leader_widths, palette, align_rows=leader_align),
        ]),
    ]
    section += 1

    # ── 05 · Variance by category ──────────────────────────────────────
    if by_category:
        cat_headers = ['#', 'Category', 'Lines', 'Off', 'Accuracy']
        if show_cost:
            cat_headers.append('Value impact')
        cat_fixed = [8 * mm, None, 16 * mm, 14 * mm, 22 * mm]
        if show_cost:
            cat_fixed.append(30 * mm)
        cat_name = max(
            CONTENT_W - sum(w for w in cat_fixed if w is not None), 40 * mm)
        cat_widths = [cat_name if w is None else w for w in cat_fixed]

        cat_data = [cat_headers]
        for index, row in enumerate(by_category[:14], start=1):
            entry = [
                str(index),
                Paragraph(_escape(row.get('category_name') or 'Uncategorised'),
                          styles['cell']),
                count(row.get('lines')),
                count(row.get('mismatched')),
                pct(row.get('accuracy_pct'), 1)
                if row.get('accuracy_pct') is not None else '-',
            ]
            if show_cost:
                entry.append(money(row.get('variance_value'), currency))
            cat_data.append(entry)

        cat_align = {}
        for row_index in range(1, len(cat_data)):
            cat_align[row_index] = {
                cat_headers.index('Lines'): 'RIGHT',
                cat_headers.index('Off'): 'RIGHT',
                cat_headers.index('Accuracy'): 'RIGHT',
            }
            if show_cost:
                cat_align[row_index][cat_headers.index('Value impact')] = 'RIGHT'

        story += [
            KeepTogether([
                Spacer(1, 5 * mm),
                _Heading(section, 'Variance by category',
                         'Which parts of the catalogue drift away from the book.',
                         CONTENT_W, palette),
                Spacer(1, 1.8 * mm),
                _table(cat_data, cat_widths, palette, align_rows=cat_align),
            ]),
        ]
        section += 1

    # ── 06 · Warehouse progress ────────────────────────────────────────
    progress_rows = [
        {
            'name': branch.get('name') or 'Unassigned',
            'pct': branch.get('progress_pct') or 0,
            'detail': (
                f"{int(branch.get('open_sheets') or 0)} open sheet(s)  |  "
                f"{int(branch.get('open_counted') or 0)} of "
                f"{int(branch.get('open_lines') or 0)} line(s) counted  |  "
                f"{int(branch.get('completed_sheets') or 0)} completed"
                + (f"  |  variance {money(branch.get('variance_value'), currency)}"
                   if show_cost else '')
            ),
        }
        for branch in by_branch[:12]
    ]

    story += [
        KeepTogether([
            Spacer(1, 5 * mm),
            _Heading(section, 'Warehouse progress',
                     'Open paperwork completed per warehouse, with filed '
                     'variance.', CONTENT_W, palette),
            Spacer(1, 1.8 * mm),
            _ProgressBar(progress_rows, CONTENT_W, palette),
        ]),
        Spacer(1, 4 * mm),
        Paragraph(
            'Accuracy is measured only on completed counts inside the window; '
            'open sheets contribute to the paperwork figures but not to '
            'variance. Money columns are omitted for roles without cost access.'
            if not show_cost else
            'Accuracy is measured only on completed counts inside the window; '
            'open sheets contribute to the paperwork figures but not to '
            'variance.', styles['note']),
        Spacer(1, 1.5 * mm),
        Paragraph(
            f'Prepared by {prepared_by or "-"}  |  Printed '
            f'{doc_info.generated_at.strftime("%d %b %Y, %H:%M")}  |  '
            f'{scope}', styles['note']),
    ]

    return _build(doc_info=doc_info, story=story)


# ── Small helpers ───────────────────────────────────────────────────────
def _escape(text):
    """Minimal XML escaping for the Paragraph markup we build inline."""
    return (str(text or '').replace('&', '&amp;').replace('<', '&lt;')
            .replace('>', '&gt;'))


def _duration(hours):
    try:
        value = float(hours)
    except (TypeError, ValueError):
        return '-'
    if value < 1:
        return f'{max(1, int(round(value * 60)))} min'
    if value < 48:
        return f'{value:.1f} h'
    return f'{value / 24:.1f} d'


def _accuracy_tone(value):
    try:
        number = float(value)
    except (TypeError, ValueError):
        return MUTED_TEXT
    if number >= 99:
        return GOOD
    if number >= 97:
        return INFO
    if number >= 95:
        return WARN
    return BAD


def _paper_tone(value):
    try:
        number = float(value or 0)
    except (TypeError, ValueError):
        return MUTED_TEXT
    if number >= 100:
        return GOOD
    if number >= 50:
        return INFO
    if number > 0:
        return WARN
    return MUTED_TEXT
