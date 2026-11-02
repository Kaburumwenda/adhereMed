"""Barcode label generation (Tier 4).

Nothing in the app *printed* labels before — the ``barcode`` field was
only ever read. This builds a printable A4 sheet of GS1-style lot labels
(batch, expiry, Code128) using reportlab, which is already a project
dependency.

The Code128 symbology is implemented inline so no extra library is needed;
the encoded value is the item barcode when present, otherwise
``medication_id|batch|expiry`` which the mobile scanner can parse back.

The barcode is **scaled to the label width** before drawing. reportlab sizes
Code128 from a fixed X-dimension, so a long lot payload silently overflowed
the box and pushed bars outside the border (and off the sheet, for the last
column). ``_fit_barcode`` measures the natural width and shrinks the bar width
to whatever the label can actually hold.
"""
from __future__ import annotations

import io
import os
from datetime import date

from django.utils import timezone

from reportlab.graphics.barcode import code128
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas

from config.pdf_branding import tint

LABEL_W = 63 * mm
LABEL_H = 38 * mm
MARGIN = 10 * mm
GAP = 3 * mm

PAGE_W, PAGE_H = A4

#: Height of the first-page letterhead band (logo + org details + sheet meta).
LETTERHEAD_H = 22 * mm
#: Gap between the letterhead and the first label row.
LETTERHEAD_GAP = 3 * mm

#: Barcode geometry. ``X_MAX`` is the widest bar (1 module) we will ever draw;
#: ``X_MIN`` is the floor — below this most 1D scanners start failing, so a
#: payload longer than the label can hold is truncated instead
#: (see :func:`_fit_barcode`).
X_MAX = 0.34 * mm
X_MIN = 0.16 * mm
BAR_H = 9 * mm
QUIET = 1.2 * mm          # manual quiet zone each side (reportlab's is huge)

INK = colors.HexColor('#0F172A')
MUTED = colors.HexColor('#64748B')
RULE = colors.HexColor('#CBD5E1')

#: Fallback letterhead palette. The real one comes from the tenant's brand
#: colours (``/ims/organization/branding``) via
#: :func:`config.pdf_branding.resolve_palette`; these are only used when the
#: service is called with no request/tenant (e.g. from a test).
BAND = colors.HexColor('#0F172A')
BAND_INK = colors.white
BAND_MUTED = colors.HexColor('#CBD5E1')
BAND_ACCENT = colors.HexColor('#38BDF8')


def encode_payload(stock, batch=None) -> str:
    """Stable scan payload for a stock item or batch."""
    if batch is not None:
        expiry = batch.expiry_date.isoformat() if batch.expiry_date else ''
        return f'{stock.medication_id or stock.pk}|{batch.batch_number or ""}|{expiry}'
    return stock.barcode or (stock.medication_id or str(stock.pk))


def _fit(canv, text: str, max_width: float, font: str, size: float) -> float:
    """Shrink the font until ``text`` fits ``max_width`` (min 5pt)."""
    while size > 5:
        if canv.stringWidth(text, font, size) <= max_width:
            return size
        size -= 0.5
    return size


def _fit_barcode(payload: str, available: float,
                 bar_height: float = BAR_H) -> tuple:
    """Build a Code128 whose width is guaranteed to fit ``available``.

    Returns ``(bar, width)``. reportlab derives the width from the X-dimension,
    so the code is first measured at :data:`X_MAX` and then scaled down. When
    even :data:`X_MIN` would overflow, the payload is shortened until it fits —
    a partially-encoded code that scans is better than bars drawn outside the
    label border.
    """
    payload = (payload or '').strip()
    if not payload:
        return None, 0.0

    budget = available - 2 * QUIET
    if budget <= 0:
        return None, 0.0

    def measure(text):
        bar = code128.Code128(text, barHeight=bar_height, barWidth=X_MAX,
                              humanReadable=False, quiet=False)
        return bar, float(bar.width)  # .width triggers computeSize()

    bar, natural = measure(payload)
    if natural <= 0:
        return None, 0.0

    needed = X_MAX * (budget / natural)
    if needed >= X_MIN:
        bar.barWidth = min(X_MAX, needed)
        bar.width                                # recompute at the new size
        return bar, float(bar.width)

    # Too dense to scan: binary-search the longest prefix that still does.
    best = None
    low, high = 1, len(payload)
    while low <= high:
        mid = (low + high) // 2
        candidate, cand_natural = measure(payload[:mid])
        if cand_natural <= 0:
            high = mid - 1
            continue
        if X_MAX * (budget / cand_natural) >= X_MIN:
            best = (candidate, mid)
            low = mid + 1
        else:
            high = mid - 1

    if best is None:
        return None, 0.0

    candidate, mid = best
    _, cand_natural = measure(payload[:mid])
    candidate.barWidth = min(X_MAX, X_MAX * (budget / cand_natural))
    candidate.width
    return candidate, float(candidate.width)


def _draw_label(canv, x: float, y: float, *, title: str, lines: list[str],
                payload: str, accent: str = '#0F172A'):
    canv.saveState()
    canv.setStrokeColor(RULE)
    canv.setLineWidth(0.5)
    canv.roundRect(x, y, LABEL_W, LABEL_H, 2 * mm, stroke=1, fill=0)

    # Accent rule down the left edge (scan-stoppage-friendly).
    canv.setFillColor(colors.HexColor(accent))
    canv.rect(x, y, 2.2 * mm, LABEL_H, stroke=0, fill=1)

    # Clip everything to the inside of the border so nothing can bleed out.
    pad_left = 3.6 * mm
    pad_right = 2.6 * mm
    inner_w = LABEL_W - pad_left - pad_right

    curs = canv.beginPath()
    curs.rect(x + 1 * mm, y + 1 * mm, LABEL_W - 2 * mm, LABEL_H - 2 * mm)
    canv.clipPath(curs, stroke=0, fill=0)

    cursor = y + LABEL_H - 5.0 * mm
    size = _fit(canv, title, inner_w, 'Helvetica-Bold', 8.5)
    canv.setFillColor(INK)
    canv.setFont('Helvetica-Bold', size)
    canv.drawString(x + pad_left, cursor, title[:60])

    cursor -= 3.9 * mm
    canv.setFillColor(MUTED)
    for line in lines[:3]:
        lsize = _fit(canv, line, inner_w, 'Helvetica', 6.4)
        canv.setFont('Helvetica', lsize)
        canv.drawString(x + pad_left, cursor, line[:58])
        cursor -= 3.1 * mm

    # ── Code128 band (bottom), scaled to the label ──────────────────────
    text_payload = payload[:52]
    text_y = y + 2.6 * mm
    bar_y = y + 5.6 * mm

    bar, bar_w = _fit_barcode(payload, inner_w)
    if bar is not None:
        bx = x + pad_left + max(0.0, (inner_w - bar_w) / 2.0)
        bar.drawOn(canv, bx, bar_y)
        # Human-readable value, also fitted so it can never overflow.
        canv.setFillColor(MUTED)
        if text_payload:
            fsize = _fit(canv, text_payload, inner_w, 'Helvetica', 4.8)
            canv.setFont('Helvetica', fsize)
            tw = canv.stringWidth(text_payload, 'Helvetica', fsize)
            canv.drawString(x + pad_left + max(0.0, (inner_w - tw) / 2.0),
                            text_y, text_payload)
    else:
        canv.setFillColor(MUTED)
        canv.setFont('Helvetica', 6)
        canv.drawString(x + pad_left, bar_y + 2 * mm, text_payload[:48])

    canv.restoreState()


def _org_detail_lines(org: dict) -> list[str]:
    """Contact lines for the letterhead, most useful first.

    ``org`` accepts ``name / address / city / country / phone / email /
    website``; anything missing is simply skipped so a bare tenant still gets
    a clean band instead of stray separators.

    The address is assembled token-by-token (splitting on commas), because
    tenants commonly type the full location into ``address`` *and* fill in
    ``city``/``country`` — "3Q62+5WH, Mtwapa, Kenya" + "Kenya" must not print
    as "…, Kenya, Nairobi, Kenya". Any token repeated anywhere is dropped, not
    just an adjacent duplicate.
    """
    org = org or {}
    lines = []

    tokens: list[str] = []
    seen: set[str] = set()
    for value in (org.get('address'), org.get('city'), org.get('country')):
        for raw in str(value or '').split(','):
            token = raw.strip().strip('.').strip()
            if not token:
                continue
            key = token.lower()
            if key in seen:
                continue
            seen.add(key)
            tokens.append(token)
    if tokens:
        lines.append(', '.join(tokens))

    # Helvetica uses WinAnsiEncoding, so the separator must be ASCII-safe —
    # a U+00B7 middot round-trips as a stray glyph.
    contact = []
    if (org.get('phone') or '').strip():
        contact.append(f"Tel {org['phone'].strip()}")
    if (org.get('email') or '').strip():
        contact.append(org['email'].strip())
    if (org.get('website') or '').strip():
        contact.append(org['website'].strip().replace('https://', '')
                       .replace('http://', '').rstrip('/'))
    if contact:
        lines.append('   |   '.join(contact))

    return lines


def _logo_luminance(logo_path) -> float | None:
    """Average luminance (0–1) of a logo's opaque pixels, or ``None``.

    Used to decide whether the mark needs a white chip (dark artwork) or can
    sit straight on the navy band (light artwork). Without this, a white logo
    disappears on a white chip and a dark logo disappears on the band.
    """
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
            if not count:
                return None
            return (total / count) / 255.0
    except Exception:
        return None


def _draw_logo(canv, x, box_centre_y, box, logo_path, chip_color=None):
    """Draw the logo, choosing a background that keeps it legible.

    Light artwork goes straight on the brand band; dark artwork gets a white
    rounded chip so it stays visible (the chip carries a hairline of
    ``chip_color`` — the brand accent — so it reads as intentional).
    Returns the x where text can start.
    """
    if not logo_path or not os.path.exists(logo_path):
        return x

    luminance = _logo_luminance(logo_path)
    needs_chip = luminance is not None and luminance < 0.62

    if needs_chip:
        chip = box + 4 * mm
        chip_y = box_centre_y - chip / 2.0
        canv.setFillColor(colors.white)
        canv.roundRect(x, chip_y, chip, chip, 2.2 * mm, stroke=0, fill=1)
        if chip_color is not None:
            # Hairline in the brand accent — ties the chip to the palette.
            canv.setStrokeColor(chip_color)
            canv.setLineWidth(0.7)
            canv.roundRect(x, chip_y, chip, chip, 2.2 * mm, stroke=1, fill=0)
        inner_x, inner_y, inner_box = x, chip_y, chip
        advance = chip
    else:
        inner_x, inner_y, inner_box = x, box_centre_y - box / 2.0, box
        advance = box

    try:
        img = ImageReader(logo_path)
        iw, ih = img.getSize()
        if not iw or not ih:
            return x + advance + 3.5 * mm
        padding = 1.6 * mm if needs_chip else 0.0
        limit = inner_box - 2 * padding
        scale = min(limit / float(iw), limit / float(ih))
        lw, lh = iw * scale, ih * scale
        canv.drawImage(
            logo_path,
            inner_x + (inner_box - lw) / 2.0, inner_y + (inner_box - lh) / 2.0,
            lw, lh, mask='auto', preserveAspectRatio=True, anchor='c')
    except Exception:
        pass

    return x + advance + 3.5 * mm


def _readable_on(color):
    """White or near-black — whichever stays legible on ``color``.

    A tenant is free to pick a pale brand colour (the presets include
    "Community Olive" and "Ambulance Amber"), so the letterhead cannot assume
    white text the way the old hard-coded navy band did.
    """
    try:
        lum = (0.2126 * color.red + 0.7152 * color.green + 0.0722 * color.blue)
    except Exception:
        return colors.white
    return colors.white if lum <= 0.62 else colors.HexColor('#0F172A')


def _palette_or_defaults(palette):
    """Coerce a caller-supplied palette into ``{primary, secondary, accent}``.

    When the caller passes nothing (a test, a management command) we still use
    the AdhereMed default brand so the sheet never falls back to a bare navy
    that no tenant configured.
    """
    fallback = {
        'primary': colors.HexColor('#2f6dff'),
        'secondary': colors.HexColor('#143ce1'),
        'accent': colors.HexColor('#37d6ff'),
    }
    if not palette:
        return fallback
    out = {}
    for key in ('primary', 'secondary', 'accent'):
        out[key] = palette.get(key) or fallback[key]
    return out


def _draw_letterhead(canv, *, logo_path, org, title, meta, palette=None) -> float:
    """Draw the first-page letterhead band; return the y below it.

    Left: logo chip + organisation name + address/contact.
    Right: the sheet title and its meta lines (count, generated timestamp).

    The band uses the tenant's brand colours from
    ``/ims/organization/branding``: ``brand_secondary`` for the deep fill,
    ``brand_accent`` for the rule along the bottom edge and for the logo chip
    fallback. Text colour is derived from the band's luminance, so a pale
    palette does not end up with invisible white text.
    """
    top = PAGE_H - MARGIN
    band_y = top - LETTERHEAD_H
    width = PAGE_W - 2 * MARGIN
    pad = 5 * mm
    org = org or {}

    pal = _palette_or_defaults(palette)
    band = pal['secondary']
    accent = pal['accent']
    ink = _readable_on(band)
    # Secondary text on the band: the ink colour, softened toward the band.
    muted = tint(ink, 0.35, towards='#8a94a6' if ink == colors.white else '#ffffff')

    canv.saveState()

    # Branded band with a thin accent rule along the bottom edge.
    canv.setFillColor(band)
    canv.roundRect(MARGIN, band_y, width, LETTERHEAD_H, 2.6 * mm, stroke=0, fill=1)
    canv.setFillColor(accent)
    canv.rect(MARGIN, band_y, width, 1.0 * mm, stroke=0, fill=1)
    # A second, softer accent stripe keeps the rule from looking like a bug.
    canv.setFillColor(tint(accent, 0.55, towards='#ffffff'))
    canv.rect(MARGIN, band_y + 1.0 * mm, width, 0.35 * mm, stroke=0, fill=1)

    mid = band_y + LETTERHEAD_H / 2.0 + 1.5 * mm

    # ── Left: mark + organisation ───────────────────────────────────────
    text_x = _draw_logo(canv, MARGIN + pad, mid, 11 * mm, logo_path,
                        chip_color=accent)

    name = (org.get('name') or '').strip() or 'AdhereMed'
    meta_lines = [m for m in (meta or []) if m]
    # Reserve room on the right for the title/meta block.
    available = width - (text_x - MARGIN) - pad - 52 * mm
    name_size = 12.5
    while name_size > 7 and canv.stringWidth(name, 'Helvetica-Bold', name_size) > available:
        name_size -= 0.5

    canv.setFillColor(ink)
    canv.setFont('Helvetica-Bold', name_size)
    canv.drawString(text_x, mid + 3.2 * mm, name)

    canv.setFillColor(muted)
    cursor = mid + 0.2 * mm
    for line in _org_detail_lines(org)[:2]:
        size = 7.0
        while size > 5 and canv.stringWidth(line, 'Helvetica', size) > available:
            size -= 0.3
        canv.setFont('Helvetica', size)
        canv.drawString(text_x, cursor, line)
        cursor -= 2.9 * mm

    # ── Right: sheet title + meta ───────────────────────────────────────
    right = PAGE_W - MARGIN - pad
    canv.setFillColor(ink)
    canv.setFont('Helvetica-Bold', 10.5)
    canv.drawRightString(right, mid + 3.4 * mm, title.upper())

    canv.setFillColor(muted)
    canv.setFont('Helvetica', 7.2)
    cursor = mid + 0.0 * mm
    for line in meta_lines[:2]:
        canv.drawRightString(right, cursor, line)
        cursor -= 2.9 * mm

    canv.restoreState()
    return band_y - LETTERHEAD_GAP


def _draw_running_header(canv, *, title, business_name, palette=None):
    """Compact header for pages 2+ — no logo, just context, in brand colours."""
    top = PAGE_H - MARGIN
    pal = _palette_or_defaults(palette)

    canv.setFillColor(INK)
    canv.setFont('Helvetica-Bold', 11)
    canv.drawString(MARGIN, top - 4 * mm, title)
    canv.setFillColor(MUTED)
    canv.setFont('Helvetica', 7.5)
    canv.drawRightString(PAGE_W - MARGIN, top - 4 * mm, business_name or '')

    # Brand-tinted rule instead of a hard-coded slate.
    canv.setStrokeColor(pal['primary'])
    canv.setLineWidth(0.8)
    canv.line(MARGIN, top - 6.2 * mm, PAGE_W - MARGIN, top - 6.2 * mm)


def _rows_that_fit(top_of_grid: float) -> int:
    """How many label rows fit between ``top_of_grid`` and the bottom margin."""
    available = top_of_grid - MARGIN
    return max(1, int((available + GAP) // (LABEL_H + GAP)))


def build_label_pdf(rows: list[dict], *, title: str = 'Stock labels',
                    business_name: str = '', logo_path: str | None = None,
                    org: dict | None = None,
                    meta_extra: list[str] | None = None,
                    palette: dict | None = None) -> bytes:
    """Render a sheet of labels.

    ``rows`` items accept either a stock+batch pair or a plain dict:
    ``{title, lines, payload, accent}``.

    Page 1 carries a full letterhead (logo, organisation details, sheet meta);
    pages 2+ use a compact running header so the label grid keeps its density.
    ``meta_extra`` appends caller-supplied lines to the letterhead's right-hand
    block (e.g. the warehouse the sheet was filtered to). ``palette`` is the
    tenant's brand colours (:func:`config.pdf_branding.resolve_palette`); omit
    it and the letterhead falls back to the AdhereMed default.
    """
    buf = io.BytesIO()
    canv = canvas.Canvas(buf, pagesize=A4)
    org = org or {}
    canv.setTitle(title)
    canv.setAuthor(org.get('name') or business_name or 'AdhereMed')

    cols = max(1, int((PAGE_W - 2 * MARGIN + GAP) // (LABEL_W + GAP)))

    first_grid_top = PAGE_H - MARGIN - LETTERHEAD_H - LETTERHEAD_GAP
    other_grid_top = PAGE_H - MARGIN - 8 * mm

    first_capacity = _rows_that_fit(first_grid_top) * cols
    other_capacity = _rows_that_fit(other_grid_top) * cols

    generated = timezone.localtime().strftime('%d %b %Y, %H:%M')
    count_label = f'{len(rows)} label' + ('s' if len(rows) != 1 else '')
    meta = [count_label]
    meta.extend(line for line in (meta_extra or []) if line)
    meta.append(f'Generated {generated}')

    index = 0
    page = 0
    while index < len(rows):
        if page:
            canv.showPage()
            _draw_running_header(canv, title=title,
                                 business_name=business_name,
                                 palette=palette)
            grid_top = other_grid_top
            capacity = other_capacity
        else:
            _draw_letterhead(canv, logo_path=logo_path, org=org,
                             title=title, meta=meta, palette=palette)
            grid_top = first_grid_top
            capacity = first_capacity

        for slot in range(capacity):
            if index >= len(rows):
                break
            row = rows[index]
            index += 1
            row_i, col_i = divmod(slot, cols)
            x = MARGIN + col_i * (LABEL_W + GAP)
            y = grid_top - LABEL_H - row_i * (LABEL_H + GAP)
            _draw_label(
                canv, x, y,
                title=row.get('title', ''),
                lines=row.get('lines', []),
                payload=row.get('payload', ''),
                accent=row.get('accent', '#0F172A'),
            )

        page += 1

    # An empty selection still produces a valid (blank) sheet.
    if page == 0:
        _draw_letterhead(canv, logo_path=logo_path, org=org,
                         title=title, meta=meta, palette=palette)
        canv.setFillColor(MUTED)
        canv.setFont('Helvetica-Oblique', 9)
        canv.drawCentredString(PAGE_W / 2.0, PAGE_H / 2.0,
                               'No labels selected.')

    canv.showPage()
    canv.save()
    return buf.getvalue()


def stock_label_rows(stocks, *, exclude_expired: bool = True) -> list[dict]:
    """Build label rows for one stock item *per live batch*.

    Each label carries only what a picker needs at the shelf: the item name,
    its lot and its expiry. Warehouse and quantity are deliberately omitted —
    both change between print time and scan time, so printing them is noise
    (and on a mixed-lot sheet, actively misleading).
    """
    today = date.today()
    rows = []
    for stock in stocks:
        batches = list(stock.batches.filter(quantity_remaining__gt=0))
        if exclude_expired:
            batches = [b for b in batches
                       if not b.expiry_date or b.expiry_date >= today]
        if not batches:
            rows.append({
                'title': stock.medication_name,
                'lines': [
                    f'SKU {stock.medication_id or stock.pk}',
                    'No live batch',
                ],
                'payload': encode_payload(stock),
                'accent': '#64748B',
            })
            continue
        for batch in batches:
            expired = batch.expiry_date and batch.expiry_date < today
            rows.append({
                'title': stock.medication_name,
                'lines': [
                    f'Lot {batch.batch_number or "—"}',
                    f'Exp {batch.expiry_date or "—"}',
                ],
                'payload': encode_payload(stock, batch),
                'accent': '#DC2626' if expired else '#0F172A',
            })
    return rows
