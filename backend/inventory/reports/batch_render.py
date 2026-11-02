"""PDF for the batch (lot) trace - a recall dossier.

Deliberately a *sibling* of :mod:`inventory.reports.trace_render`, not a copy:
the two documents answer different questions and should not look interchangeable.

* the item custody record answers **"what happened to this product?"** and is
  organised around stock levels and margins
* this dossier answers **"where did *these units* go?"** and is organised
  around positions and recipients

So it reuses the same page furniture, flowables and digest machinery (one house
style, one verification story) but leads with the recall question rather than
stock on hand. The recipients section is the reason the document exists: it is
the call-list a pharmacist works through when a supplier flags a lot.

Layout, portrait A4:

* page 1   - letterhead, lot identity (with branch scope), verdict banner,
             exposure tiles, integrity findings
* page 2+  - running header; positions by item and warehouse, movement ledger,
             recipients, attestation and the digest verification note
* every page - product footer (no watermark, same reasoning as the custody
             record: nobody should sign over diagonal text)

All printed text is ASCII or WinAnsi-safe. Helvetica silently renders geometric
shapes (●, ▶) as a stray ``G``, so bullets are ``*`` and separators are ``|``.
"""
from __future__ import annotations

import io

from django.utils import timezone
from reportlab.lib import colors
from reportlab.lib.units import mm
from reportlab.platypus import (BaseDocTemplate, CondPageBreak, Frame,
                                NextPageTemplate, PageTemplate, Paragraph,
                                Spacer, Table, TableStyle)

from config.pdf_branding import resolve_palette, tint

from .render import CREDIT_BRAND, MUTED_TEXT, _NumberedCanvas
from .trace_render import (BAD, BORDER, CONTENT_W, GOOD, KIND_LABELS,
                           LETTERHEAD_H, MARGIN, PAGE, RUNNING_H, WARN,
                           _digest_note, _findings_block, _SectionHeading,
                           _short_hash, _signature_block, _signed, _styles,
                           _TileRow, _TraceDoc, _VerdictBanner, count, money)

#: A movement ledger longer than this is summarised at both ends; the complete
#: list is always in the CSV export.
LEDGER_SOFT_CAP = 400


def _lot_identity_table(summary, styles, palette, scope=None):
    """Lot identity as a two-pair label/value grid, plus the branch scope."""
    scope = scope or {}
    names = summary.get('item_names') or []
    branches = summary.get('branch_names') or []
    suppliers = summary.get('suppliers') or []

    item_label = names[0] if len(names) == 1 else (
        f"{names[0]} +{len(names) - 1} more" if names else '-')

    def cell(value, bold=False):
        return Paragraph(str(value), styles['cell_b'] if bold
                         else styles['cell'])

    rows = [
        ['Lot number', summary.get('batch_number') or '-', 'Item',
         item_label],
        ['Lots on record', count(summary.get('lot_rows')), 'Warehouses',
         count(summary.get('branches'))],
        ['Suppliers', ', '.join(suppliers) or '-', 'First received',
         summary.get('first_received') or '-'],
        ['Expiry', summary.get('expiry_date') or '-', 'Days to expiry',
         (str(summary['days_to_expiry'])
          if summary.get('days_to_expiry') is not None else '-')],
    ]
    if scope:
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
        last = len(rows) - 1
        style.append(('BACKGROUND', (1, last), (1, last), tint(WARN, 0.94)))
        style.append(('BACKGROUND', (3, last), (3, last), tint(WARN, 0.94)))
    table.setStyle(TableStyle(style))
    return table


def _unit_strip(summary, styles, palette):
    """The lot's quantities on one row: in, out, held, downstream."""
    cells = [
        ('Units received', count(summary.get('received'))),
        ('Sold / dispensed', count(summary.get('sold'))),
        ('Transferred out', count(summary.get('moved_out'))),
        ('Still on hand', count(summary.get('on_hand'))),
        ('Units downstream', count(summary.get('units_downstream'))),
        ('Value on hand', money(summary.get('value_on_hand'))),
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


def _position_table(positions, styles, palette):
    """Where this lot physically sits: one row per item and warehouse."""
    headers = ['#', 'Item', 'Warehouse', 'Received', 'Expiry', 'Supplier',
               'In', 'Sold', 'Moved', 'On hand', 'Sold %', 'Status']
    aligns = ['cell_c', 'cell', 'cell', 'cell', 'cell', 'cell',
              'cell_r', 'cell_r', 'cell_r', 'cell_r', 'cell_r', 'cell']
    widths = [6 * mm, 34 * mm, 22 * mm, 17 * mm, 17 * mm, 22 * mm,
              11 * mm, 10 * mm, 11 * mm, 13 * mm, 14 * mm,
              CONTENT_W - 177 * mm]

    rows = [[Paragraph(h, styles[a]) for h, a in zip(headers, aligns)]]

    total_received = total_sold = total_moved = total_on_hand = 0
    for index, row in enumerate(positions, start=1):
        received = int(row.get('received') or 0)
        sold = int(row.get('sold') or 0)
        moved = int(row.get('moved') or 0)
        on_hand = int(row.get('on_hand') or 0)
        total_received += received
        total_sold += sold
        total_moved += moved
        total_on_hand += on_hand

        status = str(row.get('status') or '')
        tone = {'in stock': GOOD, 'quarantined': WARN,
                'expired': BAD, 'depleted': MUTED_TEXT}.get(status, MUTED_TEXT)
        rows.append([
            Paragraph(str(index), styles['cell_c']),
            Paragraph(str(row.get('item') or '-'), styles['cell']),
            Paragraph(str(row.get('branch') or '-'), styles['cell']),
            Paragraph(str(row.get('received_date') or '-'), styles['cell']),
            Paragraph(str(row.get('expiry_date') or '-'), styles['cell']),
            Paragraph(str(row.get('supplier') or '-'), styles['cell']),
            Paragraph(count(received), styles['cell_r']),
            Paragraph(count(sold), styles['cell_r']),
            Paragraph(count(moved), styles['cell_r']),
            Paragraph(count(on_hand), styles['cell_r']),
            Paragraph(f"{row.get('sell_through_pct', 0):.1f}%", styles['cell_r']),
            Paragraph(f'<font color="#{str(tone.hexval())[2:]}">{status}</font>',
                      styles['cell']),
        ])

    if len(rows) == 1:
        rows.append([Paragraph('-', styles['cell_c']),
                     Paragraph('No positions recorded.', styles['cell'])]
                    + [''] * 10)
        empty_row = 1
    else:
        empty_row = None
        sell_through = (total_sold / total_received * 100) if total_received else 0
        rows.append([
            Paragraph('', styles['cell_c']),
            Paragraph('<b>Total</b>', styles['cell_b']),
            Paragraph('', styles['cell']),
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
    last_total = len(rows) - (0 if empty_row is not None else 1)
    for index in range(1, last_total):
        if index % 2 == 0:
            style.append(('BACKGROUND', (0, index), (-1, index), stripe))
    if empty_row is None:
        last = len(rows) - 1
        style.append(('BACKGROUND', (0, last), (-1, last),
                      tint(palette['primary'], 0.90)))
        style.append(('LINEABOVE', (0, last), (-1, last), 0.6,
                      palette['primary']))
    else:
        style.append(('SPAN', (1, empty_row), (-1, empty_row)))
    table.setStyle(TableStyle(style))
    return table


def _movement_table(events, styles, palette):
    """The chain itself: every movement of this lot with running balance."""
    headers = ['#', 'When', 'Event', 'Reference', 'Item', 'Warehouse',
               'Party', 'Qty', 'Balance', 'Custody hash']
    aligns = ['cell_c', 'cell', 'cell', 'cell', 'cell', 'cell', 'cell',
              'cell_r', 'cell_r', 'mono']
    widths = [6 * mm, 22 * mm, 19 * mm, 23 * mm, 22 * mm, 17 * mm,
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
                Paragraph(f'<i>{count(omitted)} movements elided - export the '
                          f'CSV record for the complete ledger.</i>',
                          styles['cell']),
                '', '', '', '', '', '', '', '',
            ])
            continue
        rows.append([
            Paragraph(str(event.get('seq') or ''), styles['cell_c']),
            Paragraph(str(event.get('at_display') or ''), styles['cell']),
            Paragraph(KIND_LABELS.get(event.get('kind'),
                                      str(event.get('kind') or '')),
                      styles['cell']),
            Paragraph(str(event.get('reference') or ''), styles['cell']),
            Paragraph(str(event.get('item') or '-'), styles['cell']),
            Paragraph(str(event.get('branch') or ''), styles['cell']),
            Paragraph(str(event.get('party') or ''), styles['cell']),
            Paragraph(_signed(event.get('quantity')), styles['cell_r']),
            Paragraph(count(event.get('balance')), styles['cell_r']),
            Paragraph(_short_hash(event.get('hash')), styles['mono']),
        ])

    if len(rows) == 1:
        rows.append([Paragraph('-', styles['cell_c']),
                     Paragraph('No movements recorded for this lot.',
                               styles['cell']),
                     '', '', '', '', '', '', '', ''])
        omitted_row = 1

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
    table.setStyle(TableStyle(style))
    return table


def _exposure_table(exposure, styles, palette):
    """Who received units of this lot - the recall call-list."""
    if not exposure:
        table = Table(
            [[Paragraph('<b>No units have left this lot yet.</b> Every unit is '
                        'still in the warehouse, so there is nobody to contact.',
                        styles['body'])]],
            colWidths=[CONTENT_W], hAlign='LEFT',
            style=TableStyle([
                ('BACKGROUND', (0, 0), (-1, -1), tint(GOOD, 0.92)),
                ('BOX', (0, 0), (-1, -1), 0.5, tint(GOOD, 0.55)),
                ('LEFTPADDING', (0, 0), (-1, -1), 5),
                ('RIGHTPADDING', (0, 0), (-1, -1), 5),
                ('TOPPADDING', (0, 0), (-1, -1), 4),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
            ]))
        return table

    headers = ['#', 'Recipient', 'Channel', 'Units', 'Last movement',
               'References']
    widths = [7 * mm, 52 * mm, 26 * mm, 14 * mm, 26 * mm,
              CONTENT_W - 125 * mm]
    rows = [[Paragraph(h, styles['head']) for h in headers]]

    for index, row in enumerate(exposure, start=1):
        rows.append([
            Paragraph(str(index), styles['cell_c']),
            Paragraph(str(row.get('party') or '-'), styles['cell']),
            Paragraph(str(row.get('kind_label') or ''), styles['cell']),
            Paragraph(count(row.get('quantity')), styles['cell_r']),
            Paragraph(str(row.get('last') or ''), styles['cell']),
            Paragraph(' '.join(row.get('references') or [])[:60],
                      styles['mono']),
        ])

    total = sum(int(r.get('quantity') or 0) for r in exposure)
    rows.append([
        Paragraph('', styles['cell_c']),
        Paragraph('<b>Total downstream</b>', styles['cell_b']),
        Paragraph('', styles['cell']),
        Paragraph(f'<b>{count(total)}</b>', styles['cell_r']),
        Paragraph('', styles['cell']),
        Paragraph('', styles['cell']),
    ])

    table = Table(rows, repeatRows=1, hAlign='LEFT', colWidths=widths)
    style = [
        ('BACKGROUND', (0, 0), (-1, 0), palette['secondary']),
        ('GRID', (0, 0), (-1, -1), 0.25, BORDER),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('LEFTPADDING', (0, 0), (-1, -1), 2.4),
        ('RIGHTPADDING', (0, 0), (-1, -1), 2.4),
        ('TOPPADDING', (0, 0), (-1, -1), 2),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 2),
    ]
    stripe = tint(palette['primary'], 0.965)
    last = len(rows) - 1
    for index in range(1, last):
        if index % 2 == 0:
            style.append(('BACKGROUND', (0, index), (-1, index), stripe))
    style.append(('BACKGROUND', (0, last), (-1, last),
                  tint(palette['primary'], 0.90)))
    style.append(('LINEABOVE', (0, last), (-1, last), 0.6, palette['primary']))
    table.setStyle(TableStyle(style))
    return table


# ── Public entry point ──────────────────────────────────────────────────
def render_batch_pdf(*, payload, org=None, logo_path=None, palette=None,
                     business_name='', title='Batch Trace Record',
                     subtitle='', currency='KES', prepared_by='',
                     scope=None) -> bytes:
    """Render a completed ``traceability.trace_batch`` payload to PDF bytes.

    ``scope`` is the branch-scope block the view builds. It is printed on the
    identity card so a filed copy states which warehouses it covers.
    """
    palette = palette or resolve_palette(None)
    styles = _styles()
    summary = payload.get('summary') or {}
    reconciliation = dict(payload.get('reconciliation') or {})
    reconciliation['_digest'] = summary.get('custody_digest')

    if not subtitle:
        parts = [
            f"Lot {summary.get('batch_number') or ''}",
            (', '.join(summary.get('item_names') or [])[:60]
             or 'item unknown'),
            (', '.join(summary.get('branch_names') or [])[:40]
             or 'warehouse unknown'),
            'complete movement history, receipt to recipient',
        ]
        subtitle = '  |  '.join(part for part in parts if part)

    doc_info = _TraceDoc(
        palette=palette, org=org, logo_path=logo_path,
        business_name=business_name, title=title, subtitle=subtitle,
        prepared_by=prepared_by,
        item_label=f"Lot {summary.get('batch_number') or ''}")

    buffer = io.BytesIO()
    doc = BaseDocTemplate(
        buffer, pagesize=PAGE,
        leftMargin=MARGIN, rightMargin=MARGIN,
        topMargin=MARGIN, bottomMargin=MARGIN + 4 * mm,
        title=title,
        author=business_name or CREDIT_BRAND,
        subject=f"Batch trace - lot {summary.get('batch_number') or ''}",
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

    # ── 01 Lot identity ─────────────────────────────────────────────────
    story += [
        _SectionHeading(section, 'Lot under trace',
                        'The lot number, the items and warehouses it spans, and '
                        'where the units came from.', CONTENT_W, palette),
        Spacer(1, 1.6 * mm),
        _lot_identity_table(summary, styles, palette, scope),
        Spacer(1, 3 * mm),
        _unit_strip(summary, styles, palette),
    ]
    section += 1

    # ── 02 Reconciliation ───────────────────────────────────────────────
    story += [
        CondPageBreak(42 * mm),
        Spacer(1, 4 * mm),
        _SectionHeading(section, 'Reconciliation',
                        'Whether every unit of this lot is accounted for - in '
                        'stock, sold, dispensed or transferred.', CONTENT_W,
                        palette),
        Spacer(1, 1.6 * mm),
        _VerdictBanner(reconciliation, CONTENT_W, palette),
    ]
    section += 1

    # ── 03 Exposure ─────────────────────────────────────────────────────
    tiles = [
        {'label': 'Recipients', 'value': count(summary.get('recipients')),
         'hint': 'people or accounts to contact',
         'tone': BAD if summary.get('recipients') else None},
        {'label': 'Units downstream',
         'value': count(summary.get('units_downstream')),
         'hint': 'left the warehouse'},
        {'label': 'Still sellable', 'value': count(
            max(int(summary.get('on_hand') or 0)
                - int(summary.get('expired') or 0)
                - int(summary.get('quarantined') or 0), 0)),
         'hint': 'on the shelf and clear'},
        {'label': 'Quarantined', 'value': count(summary.get('quarantined')),
         'hint': 'blocked from sale',
         'tone': WARN if summary.get('quarantined') else None},
        {'label': 'Expired held', 'value': count(summary.get('expired')),
         'hint': 'cannot be sold',
         'tone': BAD if summary.get('expired') else None},
        {'label': 'Items affected', 'value': count(summary.get('items')),
         'hint': f"{count(summary.get('lot_rows'))} lot row(s)"},
        {'label': 'Movements', 'value': count(summary.get('events')),
         'hint': 'recorded events'},
        {'label': 'Sell-through',
         'value': f"{summary.get('sell_through_pct', 0):.1f}%",
         'hint': 'of units received'},
    ]
    story += [
        CondPageBreak(46 * mm),
        Spacer(1, 5 * mm),
        _SectionHeading(section, 'Recall exposure',
                        'How far this lot has travelled, and how many people '
                        'hold units of it.', CONTENT_W, palette),
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

    # ── 05 Positions ────────────────────────────────────────────────────
    positions = payload.get('positions') or []
    story += [
        CondPageBreak(42 * mm),
        Spacer(1, 5 * mm),
        _SectionHeading(section, 'Positions by item and warehouse',
                        'Where the remaining units physically sit. A lot can '
                        'span several items and shelves.',
                        CONTENT_W, palette),
        Spacer(1, 1.6 * mm),
        _position_table(positions, styles, palette),
    ]
    section += 1

    # ── 06 Movement ledger ──────────────────────────────────────────────
    events = payload.get('events') or []
    story += [
        CondPageBreak(42 * mm),
        Spacer(1, 5 * mm),
        _SectionHeading(section, 'Movement ledger',
                        'Every recorded movement of this lot in order, with the '
                        'running balance and its custody hash.',
                        CONTENT_W, palette),
        Spacer(1, 1.6 * mm),
        _movement_table(events, styles, palette),
    ]
    if len(events) > LEDGER_SOFT_CAP:
        story += [Spacer(1, 1.4 * mm),
                  Paragraph(f'This PDF shows {count(LEDGER_SOFT_CAP)} of '
                            f'{count(len(events))} movements (the earliest and '
                            f'latest are kept and the middle is elided). Export '
                            f'the CSV record for the complete ledger.',
                            styles['tiny'])]
    section += 1

    # ── 07 Recipients ───────────────────────────────────────────────────
    exposure = payload.get('exposure') or []
    story += [
        CondPageBreak(46 * mm),
        Spacer(1, 5 * mm),
        _SectionHeading(section, 'Recipients and exit points',
                        'The recall call-list: everyone who received units of '
                        'this lot, grouped by recipient.',
                        CONTENT_W, palette),
        Spacer(1, 1.6 * mm),
        _exposure_table(exposure, styles, palette),
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
            f'movements the system holds for this lot and does not itself '
            f'quarantine or adjust stock.', styles['tiny']),
    ]

    doc.build(story,
              canvasmaker=lambda *a, **kw: _NumberedCanvas(*a, report_doc=doc_info, **kw))
    body = buffer.getvalue()
    buffer.close()
    return body
