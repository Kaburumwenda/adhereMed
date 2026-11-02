"""Premium PDF for the item traceability record - a chain-of-custody dossier.

This is the third rendering style in the reports package, and deliberately so:

* :mod:`inventory.reports.render`  - *tabular* sheets (many columns, landscape-ish)
* :mod:`inventory.reports.bi_render` - *board pack* documents (cover, sections)
* **this module** - an *evidence* record for one item

Why no "choose what to include" switch here (unlike the BI pack): a custody
record that omits the movements a reader did not like is not evidence. The
document is complete by design and has no presentation switches at all. Full
data still lives in the CSV export for machine use.

Layout, portrait A4:

* page 1   - branded letterhead, item identity card, verdict banner, summary
             tiles and integrity findings
* page 2+  - running header; provenance, movement ledger, lot ledger,
             signature block and the digest verification note
* every page - product footer (no watermark: an attestation someone has to sign
             should not sit behind diagonal text that reduces the legibility of
             the very figures they are signing for)

All printed text is ASCII or WinAnsi-safe: Helvetica silently renders geometric
shapes (●, ▶) as a stray ``G``, so bullets are ``*`` and separators are ``|``.
"""
from __future__ import annotations

import io

from django.utils import timezone
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_RIGHT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import (BaseDocTemplate, CondPageBreak, Flowable,
                                Frame, NextPageTemplate, PageTemplate,
                                Paragraph, Spacer, Table, TableStyle)

from config.pdf_branding import resolve_palette, tint

from .bi_render import _clip
from .render import (BORDER, CREDIT_BRAND, CREDIT_SITE, HEADER_TEXT, MUTED_TEXT,
                     _draw_logo, _org_detail_lines, _NumberedCanvas)

PAGE = A4
MARGIN = 15 * mm
CONTENT_W = PAGE[0] - 2 * MARGIN

BODY = colors.HexColor('#1E293B')
SOFT = colors.HexColor('#475569')

#: Semantic tones. Green = reconciled, red = broken, amber = not comparable.
GOOD = colors.HexColor('#15803d')
BAD = colors.HexColor('#b91c1c')
WARN = colors.HexColor('#b45309')
INFO = colors.HexColor('#1d4ed8')

#: Letterhead height on page 1, and the running header on later pages.
LETTERHEAD_H = 34 * mm
RUNNING_H = 12 * mm

#: A movement ledger longer than this is summarised at both ends; the complete
#: list is always in the CSV export.
LEDGER_SOFT_CAP = 400

#: Human labels for the event kinds, mirroring
#: ``inventory.services.traceability.EVENT_TYPES``. Duplicated on purpose: the
#: renderer must not depend on the service layer to format a title case.
KIND_LABELS = {
    'receipt': 'Goods received',
    'transfer_in': 'Transfer in',
    'transfer_out': 'Transfer out',
    'adjustment_in': 'Adjustment in',
    'adjustment_out': 'Adjustment out',
    'sale': 'Customer sale',
    'dispensed': 'Dispensed',
    'sales_order': 'Sales order',
    'quarantine': 'Quarantined',
    'writeoff': 'Written off',
    'disposed': 'Expired / disposed',
}


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


def _signed(value):
    value = int(round(float(value or 0)))
    return f'{value:+,}'


def _short_hash(value):
    return str(value or '')[:16]


# ── Styles ──────────────────────────────────────────────────────────────
def _styles():
    return {
        'doc_title': ParagraphStyle('doc_title', fontName='Helvetica-Bold',
                                    fontSize=17, leading=20, textColor=HEADER_TEXT),
        'doc_sub': ParagraphStyle('doc_sub', fontName='Helvetica', fontSize=8.6,
                                  leading=11, textColor=SOFT),
        'eyebrow': ParagraphStyle('eyebrow', fontName='Helvetica-Bold',
                                  fontSize=6.6, leading=8.4,
                                  textColor=MUTED_TEXT),
        'h2': ParagraphStyle('h2', fontName='Helvetica-Bold', fontSize=10.6,
                             leading=13, textColor=HEADER_TEXT,
                             spaceBefore=0, spaceAfter=0),
        'h3': ParagraphStyle('h3', fontName='Helvetica-Bold', fontSize=8.6,
                             leading=10.6, textColor=HEADER_TEXT),
        'body': ParagraphStyle('body', fontName='Helvetica', fontSize=8.2,
                              leading=11.4, textColor=BODY),
        'small': ParagraphStyle('small', fontName='Helvetica', fontSize=7,
                                leading=9.4, textColor=SOFT),
        'tiny': ParagraphStyle('tiny', fontName='Helvetica', fontSize=6.2,
                               leading=8.2, textColor=MUTED_TEXT),
        'label': ParagraphStyle('label', fontName='Helvetica-Bold', fontSize=6.4,
                                leading=8.2, textColor=MUTED_TEXT),
        'cell': ParagraphStyle('cell', fontName='Helvetica', fontSize=6.6,
                               leading=8.4, textColor=BODY),
        'cell_r': ParagraphStyle('cell_r', fontName='Helvetica', fontSize=6.6,
                                 leading=8.4, textColor=BODY, alignment=TA_RIGHT),
        'cell_c': ParagraphStyle('cell_c', fontName='Helvetica', fontSize=6.6,
                                 leading=8.4, textColor=BODY, alignment=TA_CENTER),
        'cell_b': ParagraphStyle('cell_b', fontName='Helvetica-Bold', fontSize=6.6,
                                 leading=8.4, textColor=HEADER_TEXT),
        'head': ParagraphStyle('head', fontName='Helvetica-Bold', fontSize=6,
                               leading=7.6, textColor=colors.white),
        'head_r': ParagraphStyle('head_r', fontName='Helvetica-Bold', fontSize=6,
                                 leading=7.6, textColor=colors.white,
                                 alignment=TA_RIGHT),
        'head_c': ParagraphStyle('head_c', fontName='Helvetica-Bold', fontSize=6,
                                 leading=7.6, textColor=colors.white,
                                 alignment=TA_CENTER),
        'mono': ParagraphStyle('mono', fontName='Courier', fontSize=5.2,
                               leading=7, textColor=SOFT),
    }


# ── Page furniture ──────────────────────────────────────────────────────
class _TraceDoc:
    """Geometry and page furniture for the custody record."""

    def __init__(self, *, palette, org, logo_path, business_name, title,
                 subtitle, prepared_by='', generated_at=None, item_label='',
                 stamp='CUSTODY RECORD',
                 footer_label='Chain of custody record'):
        self.palette = palette
        self.org = org or {}
        self.logo_path = logo_path
        self.business_name = business_name or CREDIT_BRAND
        self.title = title
        self.subtitle = subtitle or ''
        self.item_label = item_label
        self.prepared_by = prepared_by
        self.generated_at = generated_at or timezone.localtime(timezone.now())
        # Every document in this family shares the page furniture, so the two
        # lines that name the document kind are parameters rather than copies.
        self.stamp = stamp
        self.footer_label = footer_label

    # ----- Page 1 letterhead -------------------------------------------
    def draw_letterhead(self, canv):
        pal = self.palette
        width, height = PAGE
        top = height - MARGIN

        canv.saveState()

        # Brand band down the left edge - a quiet, printed-document signature.
        canv.setFillColor(pal['primary'])
        canv.rect(0, height - 3.2 * mm, width, 3.2 * mm, stroke=0, fill=1)

        # Logo chip + organisation name.
        box = 15 * mm
        drawn_to = _draw_logo(canv, MARGIN, top - box / 2.0 - 2 * mm, box,
                              self.logo_path, chip_color=tint(pal['primary'], 0.55))
        text_x = max(drawn_to, MARGIN + box) + 4 * mm

        canv.setFillColor(HEADER_TEXT)
        canv.setFont('Helvetica-Bold', 11.4)
        canv.drawString(text_x, top - 6.4 * mm, self.business_name[:52])

        canv.setFillColor(MUTED_TEXT)
        canv.setFont('Helvetica', 6.6)
        y = top - 10.2 * mm
        for line in _org_detail_lines(self.org)[:2]:
            canv.drawString(text_x, y, _clip(canv, line, 'Helvetica', 6.6,
                                             width - MARGIN - text_x - 46 * mm))
            y -= 3.2 * mm

        # Right-hand document stamp.
        stamp_x = width - MARGIN
        canv.setFont('Helvetica-Bold', 6.2)
        canv.setFillColor(pal['secondary'])
        canv.drawRightString(stamp_x, top - 5.6 * mm, self.stamp)
        canv.setFont('Helvetica', 6.2)
        canv.setFillColor(MUTED_TEXT)
        canv.drawRightString(stamp_x, top - 9 * mm,
                             self.generated_at.strftime('%d %b %Y  %H:%M'))
        canv.drawRightString(stamp_x, top - 12.4 * mm,
                             str(self.org.get('website') or CREDIT_SITE)
                             .replace('https://', '').replace('http://', '')[:38])

        # Title block.
        canv.setFillColor(HEADER_TEXT)
        canv.setFont('Helvetica-Bold', 15.5)
        canv.drawString(MARGIN, top - 24 * mm, _clip(canv, self.title,
                                                     'Helvetica-Bold', 15.5,
                                                     CONTENT_W * 0.72))

        canv.setFillColor(SOFT)
        canv.setFont('Helvetica', 8)
        canv.drawString(MARGIN, top - 29 * mm,
                        _clip(canv, self.subtitle, 'Helvetica', 8,
                              CONTENT_W * 0.86))

        # Rule under the letterhead.
        canv.setStrokeColor(tint(pal['primary'], 0.55))
        canv.setLineWidth(0.7)
        canv.line(MARGIN, top - LETTERHEAD_H + 3 * mm,
                  width - MARGIN, top - LETTERHEAD_H + 3 * mm)
        canv.restoreState()

    # ----- Running header for pages 2+ ---------------------------------
    def draw_running_header(self, canv):
        pal = self.palette
        width, height = PAGE
        top = height - MARGIN + 2 * mm
        canv.saveState()
        canv.setFillColor(pal['primary'])
        canv.rect(0, height - 3.2 * mm, width, 3.2 * mm, stroke=0, fill=1)

        canv.setFillColor(HEADER_TEXT)
        canv.setFont('Helvetica-Bold', 7.6)
        canv.drawString(MARGIN, top, _clip(canv, self.title, 'Helvetica-Bold',
                                           7.6, CONTENT_W * 0.55))
        canv.setFillColor(MUTED_TEXT)
        canv.setFont('Helvetica', 6.6)
        canv.drawRightString(width - MARGIN, top,
                             _clip(canv, self.item_label or self.business_name,
                                   'Helvetica', 6.6, CONTENT_W * 0.42))
        canv.setStrokeColor(tint(pal['primary'], 0.6))
        canv.setLineWidth(0.4)
        canv.line(MARGIN, top - 2 * mm, width - MARGIN, top - 2 * mm)
        canv.restoreState()

    # ----- Footer ------------------------------------------------------
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
        left = f'{self.business_name}  |  {self.footer_label}'
        canv.drawString(MARGIN, y, _clip(canv, left, 'Helvetica', 6,
                                         CONTENT_W * 0.40))

        # Centred credit. Deliberately plain text, not a link: adding an
        # annotation from ``draw_footer`` runs after ``_endBuild`` and reportlab
        # raises "counter N doesn't match number to id dictionary".
        canv.setFillColor(tint(pal['primary'], 0.25))
        canv.setFont('Helvetica-Bold', 6)
        canv.drawCentredString(width / 2.0, y,
                               f'Powered by {CREDIT_BRAND}  |  {CREDIT_SITE}')

        canv.setFillColor(MUTED_TEXT)
        canv.setFont('Helvetica', 6)
        canv.drawRightString(width - MARGIN, y, f'Page {page} of {total}')
        canv.restoreState()


# ── Flowables ───────────────────────────────────────────────────────────
class _SectionHeading(Flowable):
    """Small numbered heading with a brand rule - keeps sections legible."""

    def __init__(self, number, title, subtitle, width, palette):
        super().__init__()
        self.number = number
        self.title = title
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
        # Numbered chip
        c.setFillColor(pal['primary'])
        c.roundRect(0, self.height - 6.2 * mm, 9.4 * mm, 6.2 * mm, 1.2 * mm,
                    stroke=0, fill=1)
        c.setFillColor(colors.white)
        c.setFont('Helvetica-Bold', 7.4)
        c.drawCentredString(4.7 * mm, self.height - 4.4 * mm,
                            f'{self.number:02d}')
        # Title
        c.setFillColor(HEADER_TEXT)
        c.setFont('Helvetica-Bold', 10)
        c.drawString(12 * mm, self.height - 4.6 * mm, self.title[:70])
        # Rule to the right margin
        c.setStrokeColor(tint(pal['primary'], 0.72))
        c.setLineWidth(0.5)
        title_w = c.stringWidth(self.title[:70], 'Helvetica-Bold', 10)
        c.line(12 * mm + title_w + 3 * mm, self.height - 3 * mm,
               self.width, self.height - 3 * mm)
        if self.subtitle:
            c.setFillColor(SOFT)
            c.setFont('Helvetica', 6.8)
            c.drawString(12 * mm, self.height - 8.4 * mm,
                         _clip(c, self.subtitle, 'Helvetica', 6.8,
                               self.width - 12 * mm))
        c.restoreState()


class _VerdictBanner(Flowable):
    """Reconciliation verdict - the first thing an auditor looks for."""

    def __init__(self, reconciliation, width, palette):
        super().__init__()
        self.recon = reconciliation or {}
        self.width = width
        self.palette = palette
        self.height = 20 * mm

    def wrap(self, aw, ah):
        return self.width, self.height

    def _tone(self):
        recon = self.recon
        if recon.get('comparable') is False:
            return WARN, 'windowed'
        return (GOOD, 'ok') if recon.get('tied') else (BAD, 'bad')

    def draw(self):
        c = self.canv
        colour, state = self._tone()
        h = self.height
        c.saveState()
        c.setFillColor(tint(colour, 0.90))
        c.setStrokeColor(tint(colour, 0.55))
        c.setLineWidth(0.6)
        c.roundRect(0, 0, self.width, h, 2.4 * mm, stroke=1, fill=1)
        # Left accent bar
        c.setFillColor(colour)
        c.roundRect(0, 0, 2.2 * mm, h, 1.1 * mm, stroke=0, fill=1)

        # Status mark drawn as a filled circle with a glyph-free check/cross:
        # a plain tick/cross would need a font glyph Helvetica does not have in
        # WinAnsi, so use a simple filled badge with the state in words.
        badge_cx = 11 * mm
        badge_cy = h / 2.0
        c.setFillColor(colour)
        c.circle(badge_cx, badge_cy, 4.2 * mm, stroke=0, fill=1)
        c.setFillColor(colors.white)
        c.setFont('Helvetica-Bold', 7)
        label = {'ok': 'OK', 'bad': '!', 'windowed': 'N/A'}[state]
        c.drawCentredString(badge_cx, badge_cy - 2.4, label)

        text_x = 19 * mm
        c.setFillColor(colour)
        c.setFont('Helvetica-Bold', 9.4)
        c.drawString(text_x, h - 7.6 * mm,
                     _clip(c, str(self.recon.get('verdict') or ''),
                           'Helvetica-Bold', 9.4, self.width - text_x - 6 * mm))

        c.setFillColor(SOFT)
        c.setFont('Helvetica', 7)
        detail = (f"Explained balance {count(self.recon.get('explained'))}"
                  f"   |   Physically on hand {count(self.recon.get('on_hand'))}"
                  f"   |   Residual {_signed(self.recon.get('residual'))}")
        c.drawString(text_x, h - 12.4 * mm,
                     _clip(c, detail, 'Helvetica', 7, self.width - text_x - 6 * mm))

        digest = str(self.recon.get('_digest') or '')
        if digest:
            c.setFillColor(MUTED_TEXT)
            c.setFont('Helvetica-Bold', 6.2)
            c.drawString(text_x, h - 16.8 * mm, 'Custody digest')
            c.setFont('Courier', 6.6)
            c.setFillColor(HEADER_TEXT)
            c.drawString(text_x + 20 * mm, h - 16.8 * mm, digest)
        c.restoreState()


class _TileRow(Flowable):
    """Summary tiles, four or six across."""

    def __init__(self, tiles, width, palette, columns=4, tile_h=17 * mm):
        super().__init__()
        self.tiles = tiles
        self.width = width
        self.palette = palette
        self.columns = min(columns, max(len(tiles), 1))
        self.tile_h = tile_h
        rows = (len(tiles) + self.columns - 1) // self.columns
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

            value = str(tile['value'])
            size = 11.6 if len(value) <= 12 else 9.4 if len(value) <= 17 else 7.8
            c.setFillColor(HEADER_TEXT)
            c.setFont('Helvetica-Bold', size)
            c.drawString(x + 2.4 * mm, y + self.tile_h - 9.8 * mm, value[:22])

            hint = str(tile.get('hint') or '')
            if hint:
                c.setFillColor(SOFT)
                c.setFont('Helvetica', 5.4)
                c.drawString(x + 2.4 * mm, y + 2.6 * mm,
                             _clip(c, hint, 'Helvetica', 5.4, tile_w - 4.8 * mm))


# ── Block builders ──────────────────────────────────────────────────────
def _identity_table(summary, styles, palette, scope=None):
    """Item identity as a two-pair label/value grid, plus the branch it covers."""
    scope = scope or {}

    def cell(value, bold=False):
        return Paragraph(str(value), styles['cell_b'] if bold
                         else styles['cell'])

    rows = [
        ['Item', summary.get('name') or '-', 'SKU', summary.get('medication_id') or '-'],
        ['Strength', summary.get('strength') or '-', 'Category',
         summary.get('category') or '-'],
        ['Barcode', summary.get('barcode') or '-', 'Unit of measure',
         summary.get('unit') or '-'],
        ['Warehouse', summary.get('branch') or '-', 'Lots on record',
         count(summary.get('lots'))],
    ]
    if scope:
        # Which warehouses this record covers. Without it, two exports of the
        # same item can disagree and nothing on the page says why.
        rows.append(['Branch scope', scope.get('label') or '-',
                     'Scope type',
                     'Single warehouse' if scope.get('locked')
                     else 'All warehouses'])

    body = [[Paragraph(str(label).upper(), styles['label']),
             cell(value, bold=(i % 2 == 0)),
             Paragraph(str(label2).upper(), styles['label']),
             cell(value2)]
            for i, (label, value, label2, value2) in enumerate(rows)]

    table = Table(body, colWidths=[22 * mm, (CONTENT_W / 2) - 22 * mm,
                                   26 * mm, (CONTENT_W / 2) - 26 * mm],
                  hAlign='LEFT')
    style = [
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('BACKGROUND', (0, 0), (0, -1), tint(palette['primary'], 0.965)),
        ('BACKGROUND', (2, 0), (2, -1), tint(palette['primary'], 0.965)),
        ('GRID', (0, 0), (-1, -1), 0.3, BORDER),
        ('TOPPADDING', (0, 0), (-1, -1), 2.4),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 2.4),
        ('LEFTPADDING', (0, 0), (-1, -1), 2.8),
        ('RIGHTPADDING', (0, 0), (-1, -1), 2.8),
    ]
    if scope:
        # Tint the scope pair so a reader checking "is this the whole estate or
        # just one shelf?" finds it without reading the whole card.
        last = len(rows) - 1
        style.append(('BACKGROUND', (1, last), (1, last), tint(WARN, 0.94)))
        style.append(('BACKGROUND', (3, last), (3, last), tint(WARN, 0.94)))
    table.setStyle(TableStyle(style))
    return table


def _financial_strip(summary, styles, palette, currency):
    """Revenue / cost / margin / sell-through, on one row."""
    cells = [
        ('Revenue realised', money(summary.get('revenue'), currency)),
        ('Cost of units sold', money(summary.get('cost_of_sold'), currency)),
        ('Gross margin', f"{money(summary.get('margin'), currency)}"
                         f"  ({summary.get('margin_pct', 0):.1f}%)"),
        ('Sell-through', f"{summary.get('sell_through_pct', 0):.1f}%"),
        ('Stock value on hand', money(summary.get('value_on_hand'), currency)),
        ('Oldest lot age',
         f"{summary.get('dwell_days')} days"
         if summary.get('dwell_days') is not None else '-'),
    ]
    widths = [CONTENT_W / len(cells)] * len(cells)
    body = [[Paragraph(label.upper(), styles['label']) for label, _ in cells],
            [Paragraph(value, styles['cell_b']) for _, value in cells]]
    table = Table(body, colWidths=widths, hAlign='LEFT')
    table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), tint(palette['primary'], 0.94)),
        ('BACKGROUND', (0, 1), (-1, 1), colors.white),
        ('GRID', (0, 0), (-1, -1), 0.3, BORDER),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 2.4),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 2.4),
        ('LEFTPADDING', (0, 0), (-1, -1), 2.4),
        ('RIGHTPADDING', (0, 0), (-1, -1), 2.4),
    ]))
    return table


def _findings_block(findings, styles, palette):
    """Severity-ranked integrity findings, or a clean bill of health."""
    if not findings:
        return Table(
            [[Paragraph('<b>No integrity findings.</b> Every recorded movement '
                        'is accounted for and the ledger ties out to physical '
                        'stock.', styles['body'])]],
            colWidths=[CONTENT_W], hAlign='LEFT',
            style=TableStyle([
                ('BACKGROUND', (0, 0), (-1, -1), tint(GOOD, 0.92)),
                ('BOX', (0, 0), (-1, -1), 0.5, tint(GOOD, 0.55)),
                ('LEFTPADDING', (0, 0), (-1, -1), 5),
                ('RIGHTPADDING', (0, 0), (-1, -1), 5),
                ('TOPPADDING', (0, 0), (-1, -1), 4),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
            ]))

    tone_of = {'critical': BAD, 'high': BAD, 'medium': WARN, 'low': INFO}
    # Most serious first: an auditor should not have to read past a medium
    # finding to reach a critical one.
    rank = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3}
    findings = sorted(findings, key=lambda f: rank.get(f.get('severity'), 4))
    rows = []
    for finding in findings:
        tone = tone_of.get(finding.get('severity'), INFO)
        sev = str(finding.get('severity') or '').upper()
        rows.append([
            Paragraph(f'<font color="#{str(tone.hexval())[2:]}"><b>{sev}</b></font>',
                      styles['cell_c']),
            Paragraph(f"<b>{finding.get('label') or ''}</b>", styles['cell']),
            Paragraph(str(finding.get('detail') or ''), styles['cell']),
        ])
    table = Table(rows, colWidths=[18 * mm, 44 * mm, CONTENT_W - 62 * mm],
                  hAlign='LEFT')
    style = [
        ('GRID', (0, 0), (-1, -1), 0.3, BORDER),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 3),
        ('RIGHTPADDING', (0, 0), (-1, -1), 3),
        ('TOPPADDING', (0, 0), (-1, -1), 2.6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 2.6),
    ]
    for index, finding in enumerate(findings):
        tone = tone_of.get(finding.get('severity'), INFO)
        style.append(('BACKGROUND', (0, index), (0, index), tint(tone, 0.88)))
    table.setStyle(TableStyle(style))
    return table


def _provenance_tables(provenance, styles, palette, currency):
    """Suppliers received from, and units in/out per warehouse."""
    suppliers = provenance.get('suppliers') or []
    branches = provenance.get('branches') or []

    # Two inner tables sharing the content width, with a 4mm gutter between.
    sup_w = CONTENT_W / 2 - 4 * mm
    br_w = CONTENT_W / 2

    sup_rows = [[Paragraph(h, styles['head']) for h in
                 ('#', 'Supplier', 'Lots', 'Units', 'First receipt')]]
    for index, supplier in enumerate(suppliers, start=1):
        sup_rows.append([
            Paragraph(str(index), styles['cell_c']),
            Paragraph(str(supplier.get('name') or '-'), styles['cell']),
            Paragraph(count(supplier.get('lots')), styles['cell_r']),
            Paragraph(count(supplier.get('units')), styles['cell_r']),
            Paragraph(str(supplier.get('first_receipt') or '-'), styles['cell']),
        ])
    if len(sup_rows) == 1:
        sup_rows.append([Paragraph('-', styles['cell_c']),
                         Paragraph('No inbound lots recorded.', styles['cell']),
                         '', '', ''])

    sup_table = Table(
        sup_rows, repeatRows=1, hAlign='LEFT',
        colWidths=[7 * mm, sup_w - 7 * mm - 9 * mm - 14 * mm - 20 * mm,
                   9 * mm, 14 * mm, 20 * mm])
    sup_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), palette['secondary']),
        ('GRID', (0, 0), (-1, -1), 0.3, BORDER),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('LEFTPADDING', (0, 0), (-1, -1), 2.6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 2.6),
        ('TOPPADDING', (0, 0), (-1, -1), 2.2),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 2.2),
    ]))

    br_rows = [[Paragraph(h, styles['head']) for h in
                ('#', 'Warehouse', 'Units in', 'Units out', 'Net')]]
    for index, branch in enumerate(branches, start=1):
        units_in = int(branch.get('in') or 0)
        units_out = int(branch.get('out') or 0)
        br_rows.append([
            Paragraph(str(index), styles['cell_c']),
            Paragraph(str(branch.get('branch') or '-'), styles['cell']),
            Paragraph(_signed(units_in), styles['cell_r']),
            Paragraph(_signed(-units_out) if units_out else '0', styles['cell_r']),
            Paragraph(_signed(units_in - units_out), styles['cell_r']),
        ])
    if len(br_rows) == 1:
        br_rows.append([Paragraph('-', styles['cell_c']),
                        Paragraph('No movements recorded.', styles['cell']),
                        '', '', ''])

    br_table = Table(
        br_rows, repeatRows=1, hAlign='LEFT',
        colWidths=[7 * mm, br_w - 7 * mm - 12 * mm - 12 * mm - 13 * mm,
                   12 * mm, 12 * mm, 13 * mm])
    br_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), palette['secondary']),
        ('GRID', (0, 0), (-1, -1), 0.3, BORDER),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('LEFTPADDING', (0, 0), (-1, -1), 2.6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 2.6),
        ('TOPPADDING', (0, 0), (-1, -1), 2.2),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 2.2),
    ]))

    pair = Table([[sup_table, br_table]],
                 colWidths=[CONTENT_W / 2, CONTENT_W / 2], hAlign='LEFT')
    pair.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 0),
        ('RIGHTPADDING', (0, 0), (0, 0), 4 * mm),
        ('RIGHTPADDING', (1, 0), (1, 0), 0),
        ('TOPPADDING', (0, 0), (-1, -1), 0),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
    ]))
    return pair


def _movement_table(events, styles, palette):
    """The chain itself: every movement with running balance and custody hash."""
    headers = ['#', 'When', 'Event', 'Reference', 'Lot', 'Warehouse',
               'Party', 'Qty', 'Balance', 'Custody hash']
    aligns = ['cell_c', 'cell', 'cell', 'cell', 'cell', 'cell', 'cell',
              'cell_r', 'cell_r', 'mono']
    widths = [7 * mm, 22 * mm, 20 * mm, 25 * mm, 18 * mm, 17 * mm,
              22 * mm, 11 * mm, 12 * mm, CONTENT_W - 154 * mm]

    rows = [[Paragraph(h, styles[a]) for h, a in zip(headers, aligns)]]

    shown = events
    omitted = 0
    omitted_row = None
    if len(events) > LEDGER_SOFT_CAP:
        head_count = LEDGER_SOFT_CAP // 2
        tail_count = LEDGER_SOFT_CAP - head_count
        omitted = len(events) - LEDGER_SOFT_CAP
        shown = list(events[:head_count]) + [None] + list(events[-tail_count:])

    for event in shown:
        if event is None:
            omitted_row = len(rows)
            rows.append([
                Paragraph('...', styles['cell_c']),
                Paragraph(f'<i>{count(omitted)} movements elided - export the CSV '
                          f'record for the complete ledger.</i>', styles['cell']),
                '', '', '', '', '', '', '', '',
            ])
            continue
        rows.append([
            Paragraph(str(event.get('seq') or ''), styles['cell_c']),
            Paragraph(str(event.get('at_display') or ''), styles['cell']),
            Paragraph(KIND_LABELS.get(event.get('kind'),
                                      str(event.get('kind') or '')), styles['cell']),
            Paragraph(str(event.get('reference') or ''), styles['cell']),
            Paragraph(str(event.get('batch_number') or '-'), styles['cell']),
            Paragraph(str(event.get('branch') or ''), styles['cell']),
            Paragraph(str(event.get('party') or ''), styles['cell']),
            Paragraph(_signed(event.get('quantity')), styles['cell_r']),
            Paragraph(count(event.get('balance')), styles['cell_r']),
            Paragraph(_short_hash(event.get('hash')), styles['mono']),
        ])

    if len(rows) == 1:
        rows.append([Paragraph('-', styles['cell_c']),
                     Paragraph('No movements recorded for this item.', styles['cell']),
                     '', '', '', '', '', '', '', ''])
        empty_row = 1
    else:
        empty_row = None

    table = Table(rows, repeatRows=1, hAlign='LEFT', colWidths=widths)
    style = [
        ('BACKGROUND', (0, 0), (-1, 0), palette['secondary']),
        ('GRID', (0, 0), (-1, -1), 0.25, BORDER),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('LEFTPADDING', (0, 0), (-1, -1), 2),
        ('RIGHTPADDING', (0, 0), (-1, -1), 2),
        ('TOPPADDING', (0, 0), (-1, -1), 1.8),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 1.8),
    ]
    stripe = tint(palette['primary'], 0.965)
    for index in range(1, len(rows)):
        if index % 2 == 0:
            style.append(('BACKGROUND', (0, index), (-1, index), stripe))
    if omitted_row is not None:
        style.append(('SPAN', (1, omitted_row), (-1, omitted_row)))
        style.append(('BACKGROUND', (0, omitted_row), (-1, omitted_row),
                      tint(WARN, 0.93)))
        style.append(('TEXTCOLOR', (1, omitted_row), (1, omitted_row), WARN))
    if empty_row is not None:
        style.append(('SPAN', (1, empty_row), (-1, empty_row)))
    table.setStyle(TableStyle(style))
    return table


def _lot_table(batches, styles, palette, currency):
    """Per-lot position with a totals row."""
    headers = ['#', 'Lot', 'Received', 'Expiry', 'Supplier', 'Warehouse',
               'In', 'Sold', 'Moved', 'On hand', 'Sold %', 'Status']
    aligns = ['cell_c', 'cell', 'cell', 'cell', 'cell', 'cell',
              'cell_r', 'cell_r', 'cell_r', 'cell_r', 'cell_r', 'cell']
    widths = [6 * mm, 23 * mm, 17 * mm, 18 * mm, 24 * mm, 17 * mm,
              11 * mm, 10 * mm, 11 * mm, 14 * mm, 16 * mm,
              CONTENT_W - 167 * mm]

    rows = [[Paragraph(h, styles[a]) for h, a in zip(headers, aligns)]]

    total_received = total_sold = total_moved = total_on_hand = 0
    for index, lot in enumerate(batches, start=1):
        received = int(lot.get('received') or 0)
        sold = int(lot.get('sold') or 0)
        moved = int(lot.get('moved') or 0)
        on_hand = int(lot.get('on_hand') or 0)
        total_received += received
        total_sold += sold
        total_moved += moved
        total_on_hand += on_hand

        status = str(lot.get('status') or '')
        tone = {'in stock': GOOD, 'quarantined': WARN,
                'expired': BAD, 'depleted': MUTED_TEXT}.get(status, MUTED_TEXT)
        rows.append([
            Paragraph(str(index), styles['cell_c']),
            Paragraph(str(lot.get('batch_number') or '-'), styles['cell']),
            Paragraph(str(lot.get('received_date') or '-'), styles['cell']),
            Paragraph(str(lot.get('expiry_date') or '-'), styles['cell']),
            Paragraph(str(lot.get('supplier') or '-'), styles['cell']),
            Paragraph(str(lot.get('branch') or '-'), styles['cell']),
            Paragraph(count(received), styles['cell_r']),
            Paragraph(count(sold), styles['cell_r']),
            Paragraph(count(moved), styles['cell_r']),
            Paragraph(count(on_hand), styles['cell_r']),
            Paragraph(f"{lot.get('sell_through_pct', 0):.1f}%", styles['cell_r']),
            Paragraph(f'<font color="#{str(tone.hexval())[2:]}">{status}</font>',
                      styles['cell']),
        ])

    if len(rows) == 1:
        rows.append([Paragraph('-', styles['cell_c']),
                     Paragraph('No lots recorded.', styles['cell'])]
                    + [''] * 10)
        empty_row = 1
    else:
        empty_row = None
        sell_through = (total_sold / total_received * 100) if total_received else 0
        rows.append([
            Paragraph('', styles['cell_c']),
            Paragraph('<b>Total</b>', styles['cell_b']),
            Paragraph('-', styles['cell']),
            Paragraph('', styles['cell']),
            Paragraph('', styles['cell']),
            Paragraph('', styles['cell']),
            Paragraph(f'<b>{count(total_received)}</b>', styles['cell_r']),
            Paragraph(f'<b>{count(total_sold)}</b>', styles['cell_r']),
            Paragraph(f'<b>{count(total_moved)}</b>', styles['cell_r']),
            Paragraph(f'<b>{count(total_on_hand)}</b>', styles['cell_r']),
            Paragraph(f'<b>{sell_through:.1f}%</b>', styles['cell_r']),
            Paragraph('', styles['cell']),
        ])

    table = Table(rows, repeatRows=1, hAlign='LEFT', colWidths=widths)
    style = [
        ('BACKGROUND', (0, 0), (-1, 0), palette['secondary']),
        ('GRID', (0, 0), (-1, -1), 0.25, BORDER),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('LEFTPADDING', (0, 0), (-1, -1), 2.2),
        ('RIGHTPADDING', (0, 0), (-1, -1), 2.2),
        ('TOPPADDING', (0, 0), (-1, -1), 2),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 2),
    ]
    stripe = tint(palette['primary'], 0.965)
    for index in range(1, len(rows) - (0 if len(batches) == 0 else 1)):
        if index % 2 == 0:
            style.append(('BACKGROUND', (0, index), (-1, index), stripe))
    if len(batches):
        last = len(rows) - 1
        style.append(('BACKGROUND', (0, last), (-1, last),
                      tint(palette['primary'], 0.90)))
        style.append(('LINEABOVE', (0, last), (-1, last), 0.6,
                      palette['primary']))
    if empty_row is not None:
        style.append(('SPAN', (1, empty_row), (-1, empty_row)))
    table.setStyle(TableStyle(style))
    return table


def _signature_block(styles, palette, prepared_by, generated_at):
    """Attestation lines - what makes this a record rather than a printout."""
    body = [[
        Paragraph('<b>Prepared by</b><br/><br/>____________________________<br/>'
                  f'{prepared_by or "Name and signature"}', styles['small']),
        Paragraph('<b>Verified by</b><br/><br/>____________________________<br/>'
                  'Name and signature', styles['small']),
        Paragraph('<b>Date</b><br/><br/>____________________________<br/>'
                  f'{generated_at.strftime("%d %b %Y")}', styles['small']),
    ]]
    table = Table(body, colWidths=[CONTENT_W / 3] * 3, hAlign='LEFT')
    table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('BACKGROUND', (0, 0), (-1, -1), tint(palette['primary'], 0.97)),
        ('BOX', (0, 0), (-1, -1), 0.4, BORDER),
        ('INNERGRID', (0, 0), (-1, -1), 0.3, BORDER),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
    ]))
    return table


def _digest_note(summary, styles, palette):
    """Explain how the digest is built, so a recipient can verify the file."""
    digest = str(summary.get('custody_digest') or '')
    if not digest:
        return Spacer(1, 0)
    text = (
        'Each movement above carries a custody hash: the first 16 hex digits of '
        'a SHA-256 digest over that movement\'s own fields plus the hash of the '
        'movement before it. The final hash, <b>%s</b>, therefore fixes the whole '
        'sequence - re-running the trace on unchanged data reproduces it exactly, '
        'and any inserted, removed or edited row changes it. Verify a copy by '
        'regenerating the record and comparing this value.' % digest)
    table = Table([[Paragraph(text, styles['small'])]], colWidths=[CONTENT_W],
                  hAlign='LEFT')
    table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), tint(palette['secondary'], 0.94)),
        ('BOX', (0, 0), (-1, -1), 0.4, tint(palette['secondary'], 0.6)),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
    ]))
    return table


# ── Public entry point ──────────────────────────────────────────────────
def render_trace_pdf(*, payload, org=None, logo_path=None, palette=None,
                     business_name='', title='Chain of Custody Record',
                     subtitle='', currency='KES', prepared_by='',
                     scope=None) -> bytes:
    """Render a completed ``traceability.trace_stock`` payload to PDF bytes.

    ``scope`` is the branch-scope block the view builds (``locked``, ``branch``,
    ``label``). It is printed on the identity card so a filed copy states which
    warehouses it covers - otherwise two exports of the same item can disagree
    with nothing on the page explaining why.
    """
    palette = palette or resolve_palette(None)
    styles = _styles()
    summary = payload.get('summary') or {}
    reconciliation = dict(payload.get('reconciliation') or {})
    reconciliation['_digest'] = summary.get('custody_digest')

    if not subtitle:
        parts = [summary.get('name') or 'Item',
                 summary.get('medication_id') or '',
                 summary.get('branch') or '',
                 'complete movement history, receipt to customer']
        subtitle = '  |  '.join(part for part in parts if part)

    doc_info = _TraceDoc(
        palette=palette, org=org, logo_path=logo_path,
        business_name=business_name, title=title, subtitle=subtitle,
        prepared_by=prepared_by,
        item_label=f"{summary.get('name') or ''}"
                   f"  |  {summary.get('medication_id') or ''}")

    buffer = io.BytesIO()
    doc = BaseDocTemplate(
        buffer, pagesize=PAGE,
        leftMargin=MARGIN, rightMargin=MARGIN,
        topMargin=MARGIN, bottomMargin=MARGIN + 4 * mm,
        title=title,
        author=business_name or CREDIT_BRAND,
        subject=f"Chain of custody - {summary.get('name') or ''}",
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
        doc_info.draw_letterhead(canv)

    def _later(canv, _doc):
        doc_info.draw_running_header(canv)

    doc.addPageTemplates([
        PageTemplate(id='first', frames=[first_frame], onPage=_first),
        PageTemplate(id='later', frames=[later_frame], onPage=_later),
    ])

    section = 1
    story = [NextPageTemplate('later')]

    # ── 01 Identity ─────────────────────────────────────────────────────
    story += [
        _SectionHeading(section, 'Item under trace',
                        'The stock item, its catalogue identity and where it '
                        'physically sits.', CONTENT_W, palette),
        Spacer(1, 1.6 * mm),
        _identity_table(summary, styles, palette, scope),
        Spacer(1, 3 * mm),
        _financial_strip(summary, styles, palette, currency),
    ]
    section += 1

    # ── 02 Verdict ──────────────────────────────────────────────────────
    story += [
        CondPageBreak(42 * mm),
        Spacer(1, 4 * mm),
        _SectionHeading(section, 'Reconciliation',
                        'Whether the recorded movements account for the stock '
                        'physically on hand.', CONTENT_W, palette),
        Spacer(1, 1.6 * mm),
        _VerdictBanner(reconciliation, CONTENT_W, palette),
    ]
    section += 1

    # ── 03 Stock position ───────────────────────────────────────────────
    tiles = [
        {'label': 'Units received', 'value': count(summary.get('received')),
         'hint': f"{count(summary.get('lots'))} lots", 'tone': GOOD},
        {'label': 'Sold / dispensed', 'value': count(summary.get('sold')),
         'hint': f"{summary.get('sell_through_pct', 0):.1f}% sell-through"},
        {'label': 'On hand', 'value': count(summary.get('on_hand')),
         'hint': f"{count(summary.get('sellable'))} sellable"},
        {'label': 'Expired', 'value': count(summary.get('expired')),
         'hint': 'cannot be sold' if summary.get('expired') else 'none',
         'tone': BAD if summary.get('expired') else None},
        {'label': 'Quarantined', 'value': count(summary.get('quarantined')),
         'hint': 'blocked from sale' if summary.get('quarantined') else 'none',
         'tone': WARN if summary.get('quarantined') else None},
        {'label': 'Committed', 'value': count(summary.get('committed')),
         'hint': 'reserved by orders'},
        {'label': 'Movements', 'value': count(summary.get('events')),
         'hint': 'recorded events'},
        {'label': 'Transferred out', 'value': count(summary.get('moved_out')),
         'hint': 'units to other sites'},
    ]
    story += [
        CondPageBreak(46 * mm),
        Spacer(1, 5 * mm),
        _SectionHeading(section, 'Stock position',
                        'What was received, what left, and what is left - '
                        'split by the condition each unit is in.',
                        CONTENT_W, palette),
        Spacer(1, 1.6 * mm),
        _TileRow(tiles, CONTENT_W, palette, columns=4),
    ]
    section += 1

    # ── 04 Integrity findings ───────────────────────────────────────────
    findings = payload.get('anomalies') or []
    story += [
        CondPageBreak(42 * mm),
        Spacer(1, 5 * mm),
        _SectionHeading(section, 'Integrity findings',
                        ('Exceptions worth a human eye' if findings
                         else 'No exceptions detected'),
                        CONTENT_W, palette),
        Spacer(1, 1.6 * mm),
        _findings_block(findings, styles, palette),
    ]
    section += 1

    # ── 05 Provenance ───────────────────────────────────────────────────
    provenance = payload.get('provenance') or {}
    story += [
        CondPageBreak(42 * mm),
        Spacer(1, 5 * mm),
        _SectionHeading(section, 'Provenance and movement by location',
                        f"First movement {provenance.get('first_event') or '-'}"
                        f"   |   Last movement "
                        f"{provenance.get('last_event') or '-'}"
                        f"   |   Span {provenance.get('span_days') or 0} day(s)",
                        CONTENT_W, palette),
        Spacer(1, 1.6 * mm),
        _provenance_tables(provenance, styles, palette, currency),
    ]
    section += 1

    # ── 06 Movement ledger ──────────────────────────────────────────────
    events = payload.get('events') or []
    story += [
        CondPageBreak(42 * mm),
        Spacer(1, 5 * mm),
        _SectionHeading(section, 'Movement ledger',
                        'Every recorded movement in order, with the running '
                        'balance and its custody hash.',
                        CONTENT_W, palette),
        Spacer(1, 1.6 * mm),
        _movement_table(events, styles, palette),
    ]
    if len(events) > LEDGER_SOFT_CAP:
        story += [Spacer(1, 1.4 * mm),
                  Paragraph(f'This PDF shows {count(LEDGER_SOFT_CAP)} of '
                            f'{count(len(events))} movements (the earliest and '
                            f'latest are kept and the middle is elided). Export '
                            f'the CSV record for the complete ledger.', styles['tiny'])]
    section += 1

    # ── 07 Lot ledger ───────────────────────────────────────────────────
    batches = payload.get('batches') or []
    story += [
        CondPageBreak(42 * mm),
        Spacer(1, 5 * mm),
        _SectionHeading(section, 'Lot ledger',
                        'Each lot with its receipt, disposal, remaining balance '
                        'and expiry position.',
                        CONTENT_W, palette),
        Spacer(1, 1.6 * mm),
        _lot_table(batches, styles, palette, currency),
    ]
    section += 1

    # ── 08 Attestation ──────────────────────────────────────────────────
    story += [
        CondPageBreak(62 * mm),
        Spacer(1, 6 * mm),
        _SectionHeading(section, 'Attestation and verification',
                        'Sign to attest the record; compare the digest to '
                        'verify a copy.', CONTENT_W, palette),
        Spacer(1, 1.6 * mm),
        _signature_block(styles, palette, prepared_by, doc_info.generated_at),
        Spacer(1, 3 * mm),
        _digest_note(summary, styles, palette),
        Spacer(1, 2 * mm),
        Paragraph(
            f'Generated {doc_info.generated_at.strftime("%d %b %Y at %H:%M")} '
            f'by {CREDIT_BRAND}. This record is read-only: it states the '
            f'movements the system holds, and does not itself alter stock.',
            styles['tiny']),
    ]

    doc.build(story,
              canvasmaker=lambda *a, **kw: _NumberedCanvas(*a, report_doc=doc_info, **kw))
    body = buffer.getvalue()
    buffer.close()
    return body
