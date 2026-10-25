"""Premium patient-facing laboratory report.

Deliberately *not* the clinician report. A patient reading this needs three
things the lab copy does not give them:

1. **A verdict** — "everything is in range" or "2 results need attention" — in
   plain words, before any numbers.
2. **Context** — what each test actually measures, and how their value sits
   against the reference band (drawn as a bar, not just a number).
3. **What to do next** — who verified it, what it does not prove, when to call.

It is rendered from the *shared* ``exchange.PatientLabRecord`` only, because a
patient has no access to the clinic schema. That record therefore carries the
catalogue descriptions and reference ranges with it (see
``lab/patient_share.py``).

Layout::

    ┌ gradient hero ────────────────────────────────────────────┐
    │  Your Laboratory Report        ● VERIFIED · 24 Oct 2026   │
    │  Prepared for Olive Otieno     CityCare Medical Clinic    │
    └───────────────────────────────────────────────────────────┘
    ┌ status banner ────────────────────────────────────────────┐
    ┌ at-a-glance cards ────────────────────────────────────────┐
    ┌ results needing attention (cards + guidance) ─────────────┐
    ┌ your results (per analyte, with reference-range bars) ─────┐
    ┌ what each test measured ──────────────────────────────────┐
    ┌ your test journey (timeline) ─────────────────────────────┐
    ┌ your care team ───────────────────────────────────────────┐
    ┌ what to do next ──────────────────────────────────────────┐
    ┌ understanding your report (glossary) ─────────────────────┘
    footer: clinic · page n of m · AdhereMed
"""

import re
from io import BytesIO

from reportlab.lib.colors import Color, HexColor
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas
from reportlab.graphics.shapes import Circle, Drawing, Rect
from reportlab.platypus import (
    BaseDocTemplate, Flowable, Frame, KeepTogether, PageTemplate,
    Paragraph, Spacer, Table, TableStyle,
)

# ── Palette ─────────────────────────────────────────────────────────────────
NAVY = HexColor('#0B1220')
INK = HexColor('#1E293B')
BODY = HexColor('#334155')
SLATE = HexColor('#64748B')
MUTED = HexColor('#94A3B8')
BORDER = HexColor('#E2E8F0')
HAIR = HexColor('#EDF1F6')
SOFT = HexColor('#F8FAFC')
WHITE = HexColor('#FFFFFF')

ACCENT = HexColor('#2F6DFF')
ACCENT_DEEP = HexColor('#143CE1')
TEAL = HexColor('#0D9488')

GOOD = HexColor('#047857')
GOOD_BG = HexColor('#ECFDF5')
GOOD_LINE = HexColor('#A7F3D0')
WARN = HexColor('#B45309')
WARN_BG = HexColor('#FFFBEB')
WARN_LINE = HexColor('#FDE68A')
BAD = HexColor('#B91C1C')
BAD_BG = HexColor('#FEF2F2')
BAD_LINE = HexColor('#FECACA')

# ── Geometry ────────────────────────────────────────────────────────────────
PAGE_W, PAGE_H = A4
MARGIN = 15 * mm
CONTENT_W = PAGE_W - 2 * MARGIN
TOP_MARGIN = 16 * mm
BOTTOM_MARGIN = 18 * mm
HERO_H = 52 * mm

# ── Text helpers ────────────────────────────────────────────────────────────
ANALYTE_SPLIT = re.compile(r'\s*[·•;]\s*|\s{3,}|\n')
ANALYTE_RE = re.compile(r'^\s*([A-Za-z][A-Za-z0-9 ()/%\.\-\'+]*?)\s*[:=]\s*(.+)$')
RANGE_RE = re.compile(r'^(-?\d+(?:\.\d+)?)\s*(?:-|–|—|to)\s*(-?\d+(?:\.\d+)?)\s*(.*)$', re.I)
BOUND_RE = re.compile(r'^(<=|≥|>=|≤|<|>)\s*(-?\d+(?:\.\d+)?)\s*(.*)$')
NUM_RE = re.compile(r'^(-?\d+(?:\.\d+)?)\s*(.*)$')

#: Plain-language meaning of the department a test belongs to.
DEPARTMENT_MEANING = {
    'hematology': 'how your blood cells are made and how they carry oxygen',
    'haematology': 'how your blood cells are made and how they carry oxygen',
    'biochemistry': 'how well your organs and metabolism are working',
    'chemistry': 'how well your organs and metabolism are working',
    'clinical chemistry': 'how well your organs and metabolism are working',
    'microbiology': 'whether an infection is present',
    'parasitology': 'whether a parasite is present',
    'serology': 'how your immune system has responded to an infection',
    'immunology': 'how your immune system is responding',
    'urinalysis': 'how your kidneys and urinary tract are working',
    'endocrinology': 'how your hormone system is working',
    'oncology': 'markers your clinician uses to monitor treatment',
    'histology': 'the structure of a tissue sample',
}

#: Compact glossary — shown only for analytes that actually appear.
GLOSSARY = {
    'hb': ('Haemoglobin', 'the protein in red cells that carries oxygen'),
    'hgb': ('Haemoglobin', 'the protein in red cells that carries oxygen'),
    'wbc': ('White blood cells', 'cells that fight infection'),
    'rbc': ('Red blood cells', 'the cells that carry oxygen'),
    'plt': ('Platelets', 'the cells that help blood to clot'),
    'platelets': ('Platelets', 'the cells that help blood to clot'),
    'mcv': ('Mean cell volume', 'the average size of your red blood cells'),
    'mch': ('Mean cell haemoglobin', 'how much haemoglobin each red cell carries'),
    'mchc': ('Mean cell haemoglobin concentration', 'how concentrated the haemoglobin is'),
    'hct': ('Haematocrit', 'the proportion of your blood made up of red cells'),
    'esr': ('Erythrocyte sedimentation rate', 'a general marker of inflammation'),
    'crp': ('C-reactive protein', 'a protein that rises with inflammation'),
    'alt': ('Alanine transaminase', 'a liver enzyme'),
    'ast': ('Aspartate transaminase', 'a liver and muscle enzyme'),
    'ggt': ('Gamma-glutamyl transferase', 'a liver and bile-duct enzyme'),
    'alp': ('Alkaline phosphatase', 'an enzyme found in liver and bone'),
    'alb': ('Albumin', 'the main protein your liver makes'),
    'tbil': ('Total bilirubin', 'a yellow pigment your liver processes'),
    'crea': ('Creatinine', 'a waste product your kidneys remove'),
    'urea': ('Urea', 'a waste product your kidneys remove'),
    'na': ('Sodium', 'a salt that balances fluid in your body'),
    'k': ('Potassium', 'a salt that helps nerves and muscles work'),
    'cl': ('Chloride', 'a salt that helps balance body fluids'),
    'rbs': ('Random blood sugar', 'your blood glucose at any time of day'),
    'fbs': ('Fasting blood sugar', 'your blood glucose after not eating'),
    'hba1c': ('Glycated haemoglobin', 'your average blood sugar over 3 months'),
    'tsh': ('Thyroid stimulating hormone', 'the hormone that drives your thyroid'),
    'ft4': ('Free thyroxine', 'the active thyroid hormone'),
    'chol': ('Total cholesterol', 'a fat in your blood'),
    'ldl': ('LDL cholesterol', 'the cholesterol that can clog arteries'),
    'hdl': ('HDL cholesterol', 'the cholesterol that protects arteries'),
    'trig': ('Triglycerides', 'a type of blood fat'),
}

DISCLAIMER = (
    'This report is a record of laboratory measurements. It is not a diagnosis '
    'and it is not a prescription. Only your clinician can interpret these '
    'results alongside your symptoms, examination, medicines and history.'
)


# ══════════════════════════════════════════════════════════════════════════
# Small utilities
# ══════════════════════════════════════════════════════════════════════════


def _esc(value):
    """Escape text for reportlab Paragraph markup."""
    return (
        str(value if value is not None else '')
        .replace('&', '&amp;')
        .replace('<', '&lt;')
        .replace('>', '&gt;')
    )


def _fmt_date(value):
    if not value:
        return '—'
    try:
        return value.strftime('%-d %b %Y')
    except (AttributeError, ValueError):
        try:
            return value.strftime('%d %b %Y')
        except (AttributeError, ValueError):
            return '—'


def _fmt_dt(value):
    if not value:
        return '—'
    try:
        return value.strftime('%-d %b %Y · %H:%M')
    except (AttributeError, ValueError):
        try:
            return value.strftime('%d %b %Y · %H:%M')
        except (AttributeError, ValueError):
            return '—'


def _duration(seconds):
    """16785 → '4h 40m'."""
    if seconds is None:
        return '—'
    try:
        total = int(seconds)
    except (TypeError, ValueError):
        return '—'
    if total < 60:
        return f'{total}s'
    minutes = total // 60
    if minutes < 60:
        return f'{minutes}m'
    hours, mins = divmod(minutes, 60)
    if hours < 24:
        return f'{hours}h {mins:02d}m' if mins else f'{hours}h'
    days, hrs = divmod(hours, 24)
    return f'{days}d {hrs}h' if hrs else f'{days}d'


def _hex(value, fallback):
    """'#2F6DFF' or '2F6DFF' → HexColor, falling back when unusable."""
    raw = str(value or '').strip()
    if not raw:
        return fallback
    if not raw.startswith('#'):
        raw = '#' + raw
    if not re.fullmatch(r'#[0-9A-Fa-f]{6}', raw):
        return fallback
    return HexColor(raw)


def _mix(color_a, color_b, t):
    """Linear blend of two reportlab colours."""
    t = max(0.0, min(1.0, t))
    return Color(
        color_a.red + (color_b.red - color_a.red) * t,
        color_a.green + (color_b.green - color_a.green) * t,
        color_a.blue + (color_b.blue - color_a.blue) * t,
    )


def _bounded_int(value, default=0):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


# ══════════════════════════════════════════════════════════════════════════
# Result parsing
# ══════════════════════════════════════════════════════════════════════════


def _parse_bounds(text):
    """'12.0 – 17.0 g/dL' → {'low': 12.0, 'high': 17.0, 'unit': 'g/dL'}."""
    raw = str(text or '').strip()
    if not raw:
        return None
    match = RANGE_RE.match(raw)
    if match:
        return {
            'low': float(match.group(1)),
            'high': float(match.group(2)),
            'unit': (match.group(3) or '').strip(),
        }
    match = BOUND_RE.match(raw)
    if match:
        operator = match.group(1)
        bound = float(match.group(2))
        unit = (match.group(3) or '').strip()
        if operator in ('<', '<='):
            return {'low': None, 'high': bound, 'unit': unit}
        return {'low': bound, 'high': None, 'unit': unit}
    return None


def _split_number(text):
    """'14.2 g/dL' → (14.2, 'g/dL')."""
    match = NUM_RE.match(str(text or '').strip())
    if not match:
        return None, ''
    try:
        return float(match.group(1)), (match.group(2) or '').strip()
    except ValueError:
        return None, ''


def _lookup_range(ranges, label):
    """Find the reference range entry that matches an analyte label."""
    if not ranges or not label:
        return ''
    wanted = re.sub(r'[^a-z0-9]', '', str(label).lower())
    for key, value in ranges.items():
        if re.sub(r'[^a-z0-9]', '', str(key).lower()) == wanted:
            return str(value or '')
    # Fall back to a prefix match (e.g. 'Haemoglobin (Hb)' vs 'Hb').
    for key, value in ranges.items():
        norm = re.sub(r'[^a-z0-9]', '', str(key).lower())
        if norm and (norm.startswith(wanted) or wanted.startswith(norm)):
            return str(value or '')
    return ''


def _flag(value, bounds):
    """('High'|'Low'|'Normal'|'', tone) for one numeric value."""
    if bounds is None or value is None:
        return '', 'muted'
    if bounds['low'] is not None and value < bounds['low']:
        return 'Low', 'bad'
    if bounds['high'] is not None and value > bounds['high']:
        return 'High', 'bad'
    return 'Normal', 'good'


def _analytes(record):
    """Flatten the record's results into one row per measured analyte.

    A panel result arrives as ``"Hb: 14.2 g/dL · WBC: 7.2 x10^9/L"`` — split it
    so each analyte gets its own reference band and flag. Non-panel values pass
    through as a single row.
    """
    tests_by_name = {
        str(t.get('name') or '').lower(): t for t in (record.tests or [])
    }
    rows = []

    for result in record.results or []:
        test_name = result.get('test_name') or ''
        meta = tests_by_name.get(test_name.lower(), {})
        ranges = meta.get('reference_ranges') or {}
        raw_value = result.get('result_value') or ''
        fallback_unit = result.get('unit') or ''
        chunks = [c for c in ANALYTE_SPLIT.split(str(raw_value)) if c.strip()]

        if len(chunks) <= 1:
            # Single measurement — use the record's own reference range text.
            number, unit = _split_number(raw_value)
            range_text = result.get('reference_range') or _lookup_range(ranges, test_name)
            bounds = _parse_bounds(range_text)
            flag, tone = _flag(number, bounds)
            rows.append({
                'test': test_name,
                'test_code': result.get('test_code') or '',
                'department': result.get('department') or meta.get('department') or '',
                'label': test_name,
                'value_text': str(raw_value) or '—',
                'number': number,
                'unit': unit or fallback_unit,
                'range_text': range_text,
                'bounds': bounds,
                'flag': flag,
                'tone': tone,
                'is_abnormal': bool(result.get('is_abnormal')),
                'comments': result.get('comments') or '',
            })
            continue

        any_abnormal = False
        for chunk in chunks:
            match = ANALYTE_RE.match(chunk)
            if match:
                label = match.group(1).strip()
                value_part = match.group(2).strip()
            else:
                label = ''
                value_part = chunk.strip()

            number, unit = _split_number(value_part)
            range_text = _lookup_range(ranges, label or test_name) or result.get('reference_range') or ''
            bounds = _parse_bounds(range_text)
            flag, tone = _flag(number, bounds)
            if flag in ('High', 'Low'):
                any_abnormal = True
            rows.append({
                'test': test_name,
                'test_code': result.get('test_code') or '',
                'department': result.get('department') or meta.get('department') or '',
                'label': label or test_name,
                'value_text': str(value_part) or '—',
                'number': number,
                'unit': unit or fallback_unit,
                'range_text': range_text,
                'bounds': bounds,
                'flag': flag,
                'tone': tone,
                'is_abnormal': bool(result.get('is_abnormal')) or flag in ('High', 'Low'),
                'comments': result.get('comments') or '',
            })
        # The panel's own flag applies to all of its analytes.
        if result.get('is_abnormal') and not any_abnormal:
            for row in rows[-len(chunks):]:
                row['is_abnormal'] = True
                row['tone'] = 'bad'
                if not row['flag']:
                    row['flag'] = 'Abnormal'

    return rows


# ══════════════════════════════════════════════════════════════════════════
# Flowables
# ══════════════════════════════════════════════════════════════════════════


class _Rule(Flowable):
    """Thin divider that never breaks across pages."""

    def __init__(self, width, color=HAIR, thickness=0.7):
        Flowable.__init__(self)
        self.width = width
        self.color = color
        self.thickness = thickness
        self.height = thickness

    def draw(self):
        self.canv.setStrokeColor(self.color)
        self.canv.setLineWidth(self.thickness)
        self.canv.line(0, 0, self.width, 0)


def _range_bar(value, bounds, width=58 * mm, height=9 * mm, tone='good'):
    """Draw the value's position inside (or outside) its reference band.

    A patient cannot tell whether ``13.1`` is good from the number alone; a bar
    makes the answer visual. The band is green, the marker turns red when the
    value falls outside it.
    """
    drawing = Drawing(width, height)
    pad_x = 3
    track_y = height / 2 - 1.7
    track_h = 3.4

    if bounds is None or value is None:
        drawing.add(Rect(pad_x, track_y, width - 2 * pad_x, track_h,
                         fillColor=HexColor('#F1F5F9'), strokeColor=None, rx=1.7, ry=1.7))
        return drawing

    low, high = bounds['low'], bounds['high']
    anchor_low = low if low is not None else (high - 1 if high is not None else 0)
    anchor_high = high if high is not None else (low + 1 if low is not None else 1)
    span = max(anchor_high - anchor_low, 1e-6)
    pad = span * 0.55

    scale_low = min(anchor_low, value) - pad
    scale_high = max(anchor_high, value) + pad
    if scale_high - scale_low <= 0:
        scale_high = scale_low + 1

    def x_of(v):
        ratio = (v - scale_low) / (scale_high - scale_low)
        return pad_x + max(0.0, min(1.0, ratio)) * (width - 2 * pad_x)

    # Track
    drawing.add(Rect(pad_x, track_y, width - 2 * pad_x, track_h,
                     fillColor=HexColor('#F1F5F9'), strokeColor=None, rx=1.7, ry=1.7))

    # Normal band
    x1 = x_of(anchor_low)
    x2 = x_of(anchor_high)
    band_color = HexColor('#A7F3D0') if tone != 'bad' else HexColor('#E2E8F0')
    drawing.add(Rect(x1, track_y, max(1.5, x2 - x1), track_h,
                     fillColor=band_color, strokeColor=None, rx=1.7, ry=1.7))

    # Band edges
    for edge_x in (x1, x2):
        drawing.add(Rect(edge_x - 0.35, track_y - 0.6, 0.7, track_h + 1.2,
                         fillColor=HexColor('#94A3B8'), strokeColor=None))

    # Marker
    marker_x = x_of(value)
    marker_color = HexColor('#B91C1C') if tone == 'bad' else HexColor('#0D9488')
    drawing.add(Circle(marker_x, height / 2, 3.1,
                       fillColor=marker_color, strokeColor=WHITE, strokeWidth=1.1))
    return drawing


def _mini_stat(label, value, tone='ink', width=41 * mm):
    """Small label/value card used on the at-a-glance row."""
    colors = {
        'ink': NAVY, 'good': GOOD, 'warn': WARN, 'bad': BAD, 'accent': ACCENT_DEEP,
    }
    value_style = ParagraphStyle(
        f'msv-{label}', fontName='Helvetica-Bold', fontSize=13,
        textColor=colors.get(tone, NAVY), leading=15, alignment=TA_LEFT,
    )
    label_style = ParagraphStyle(
        f'msl-{label}', fontName='Helvetica-Bold', fontSize=6.2,
        textColor=MUTED, leading=8.5,
    )
    card = Table(
        [[Paragraph(_esc(value), value_style)],
         [Paragraph(_esc(label.upper()), label_style)]],
        colWidths=[width],
    )
    card.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), SOFT),
        ('BOX', (0, 0), (-1, -1), 0.6, BORDER),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
        ('RIGHTPADDING', (0, 0), (-1, -1), 7),
        ('TOPPADDING', (0, 0), (-1, 0), 6),
        ('BOTTOMPADDING', (0, 0), (-1, 0), 0),
        ('TOPPADDING', (0, 1), (-1, 1), 1),
        ('BOTTOMPADDING', (0, 1), (-1, 1), 6),
    ]))
    return card


# ══════════════════════════════════════════════════════════════════════════
# Document
# ══════════════════════════════════════════════════════════════════════════


class _PatientReportDoc(BaseDocTemplate):
    """Single frame; page 1 carries the hero band, later pages a slim header."""

    def __init__(self, buffer, *, decorate_first, decorate_later, footer):
        BaseDocTemplate.__init__(
            self, buffer, pagesize=A4,
            leftMargin=MARGIN, rightMargin=MARGIN,
            topMargin=TOP_MARGIN, bottomMargin=BOTTOM_MARGIN,
            title='Laboratory report', author='AdhereMed',
        )
        self._decorate_first = decorate_first
        self._decorate_later = decorate_later
        self._footer = footer

        frame = Frame(
            MARGIN, BOTTOM_MARGIN, CONTENT_W,
            PAGE_H - TOP_MARGIN - BOTTOM_MARGIN,
            id='body', leftPadding=0, rightPadding=0,
            topPadding=0, bottomPadding=0,
        )
        # One template, dispatched by page number: the hero belongs to the
        # first page only, every later page gets the slim running header.
        self.addPageTemplates([
            PageTemplate(id='report', frames=[frame], onPage=self._on_page),
        ])

    def _on_page(self, canv, doc):
        if doc.page == 1:
            self._decorate_first(canv, doc)
        else:
            self._decorate_later(canv, doc)


class _NumberedCanvas(canvas.Canvas):
    """Two-pass canvas so the footer can print ``Page n of m``."""

    def __init__(self, *args, footer=None, **kwargs):
        self._footer = footer
        canvas.Canvas.__init__(self, *args, **kwargs)
        self._states = []

    def showPage(self):
        self._states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        total = len(self._states)
        for state in self._states:
            self.__dict__.update(state)
            if self._footer:
                self._footer(self, self._pageNumber, total)
            canvas.Canvas.showPage(self)
        canvas.Canvas.save(self)


# ══════════════════════════════════════════════════════════════════════════
# Main entry point
# ══════════════════════════════════════════════════════════════════════════


def build_patient_lab_report(record, *, tenant=None):
    """Render a premium patient report for ``record`` and return PDF bytes."""
    rows = _analytes(record)
    abnormal_rows = [r for r in rows if r['is_abnormal'] or r['flag'] in ('High', 'Low')]
    tests = record.tests or []

    # Branding — the patient should recognise their clinic.
    brand_primary = _hex(getattr(tenant, 'brand_primary', '') if tenant else '', ACCENT)
    brand_secondary = _hex(getattr(tenant, 'brand_secondary', '') if tenant else '', ACCENT_DEEP)
    brand_accent = _hex(getattr(tenant, 'brand_accent', '') if tenant else '', TEAL)
    clinic_name = record.source_tenant_name or getattr(tenant, 'name', '') or 'Your clinic'

    clinic_lines = []
    if tenant is not None:
        addr = ', '.join(x for x in [
            getattr(tenant, 'address', '') or '', getattr(tenant, 'city', '') or '',
        ] if x)
        if addr:
            clinic_lines.append(addr)
        contact = ' · '.join(x for x in [
            getattr(tenant, 'phone', '') or '', getattr(tenant, 'email', '') or '',
        ] if x)
        if contact:
            clinic_lines.append(contact)
    if record.clinic_site_name and record.clinic_site_name != clinic_name:
        clinic_lines.append(record.clinic_site_name)

    reference = record.order_ref or f'LAB-{record.source_order_id:05d}'
    requested = record.requested_on
    verified_at = record.verified_at

    # ── Decorators ─────────────────────────────────────────────────────────
    def _draw_gradient(canv, x, y, w, h, stops):
        steps = 220
        for i in range(steps):
            t = i / (steps - 1)
            if t < 0.55:
                color = _mix(stops[0], stops[1], t / 0.55)
            else:
                color = _mix(stops[1], stops[2], (t - 0.55) / 0.45)
            canv.setFillColor(color)
            canv.rect(x + w * i / steps, y, w / steps + 0.7, h, stroke=0, fill=1)

    def decorate_first(canv, _doc):
        top = PAGE_H
        _draw_gradient(canv, 0, top - HERO_H, PAGE_W, HERO_H,
                       (brand_secondary, brand_primary, brand_accent))

        # A faint diagonal sheen. Drawn as one translucent parallelogram at very
        # low alpha: a stack of strips leaves visible vertical banding.
        canv.saveState()
        try:
            canv.setFillAlpha(0.07)
            canv.setFillColor(WHITE)
            path = canv.beginPath()
            path.moveTo(PAGE_W * 0.55, top - HERO_H)
            path.lineTo(PAGE_W * 0.72, top - HERO_H)
            path.lineTo(PAGE_W * 0.60, top)
            path.lineTo(PAGE_W * 0.43, top)
            path.close()
            canv.drawPath(path, stroke=0, fill=1)
        except Exception:  # noqa: BLE001
            pass
        canv.restoreState()

        x = MARGIN
        canv.setFillColor(WHITE)

        # Kicker
        canv.setFont('Helvetica-Bold', 7)
        canv.drawString(x, top - 13 * mm, 'L A B O R A T O R Y   R E P O R T')

        # Title
        canv.setFont('Helvetica-Bold', 22)
        canv.drawString(x, top - 22.5 * mm, 'Your Lab Report')

        # Patient line
        canv.setFont('Helvetica', 9.5)
        patient_line = f'Prepared for {record.patient_name or "you"}'
        if record.patient_number:
            patient_line += f'   -   Patient no. {record.patient_number}'
        canv.drawString(x, top - 30 * mm, patient_line[:95])

        canv.setFont('Helvetica-Bold', 8.2)
        canv.drawString(x, top - 37 * mm, clinic_name[:70])

        canv.setFont('Helvetica', 7.4)
        for index, line in enumerate(clinic_lines[:2]):
            canv.drawString(x, top - (42 + index * 4.4) * mm, line[:86])

        # Right-hand status block
        right = PAGE_W - MARGIN
        verified = bool(record.is_verified)
        badge_text = 'VERIFIED  -  RELEASED TO YOU' if verified else 'IN PROGRESS'
        canv.setFont('Helvetica-Bold', 6.8)
        badge_w = canv.stringWidth(badge_text, 'Helvetica-Bold', 6.8) + 13
        badge_x = right - badge_w
        try:
            canv.setFillAlpha(0.2)
        except Exception:  # noqa: BLE001
            pass
        canv.setFillColor(WHITE)
        canv.roundRect(badge_x, top - 15.5 * mm, badge_w, 6.6 * mm, 3.3 * mm, stroke=0, fill=1)
        try:
            canv.setFillAlpha(1)
        except Exception:  # noqa: BLE001
            pass
        canv.setFont('Helvetica-Bold', 6.8)
        canv.drawString(badge_x + 6.5, top - 13.2 * mm, badge_text)

        canv.setFont('Helvetica-Bold', 11)
        canv.drawRightString(right, top - 23 * mm, reference)
        canv.setFont('Helvetica', 7.6)
        canv.drawRightString(right, top - 28.5 * mm, f'Requested {_fmt_date(requested)}')
        if verified_at:
            canv.drawRightString(right, top - 33 * mm, f'Released {_fmt_date(verified_at)}')

        try:
            canv.setStrokeAlpha(0.32)
        except Exception:  # noqa: BLE001
            pass
        canv.setStrokeColor(WHITE)
        canv.setLineWidth(0.6)
        canv.line(MARGIN, top - HERO_H + 5 * mm, PAGE_W - MARGIN, top - HERO_H + 5 * mm)

    def decorate_later(canv, _doc):
        top = PAGE_H
        canv.saveState()
        canv.setFillColor(NAVY)
        canv.setFont('Helvetica-Bold', 8.2)
        canv.drawString(MARGIN, top - 10 * mm, 'Your Lab Report')
        canv.setFillColor(SLATE)
        canv.setFont('Helvetica', 7.6)
        canv.drawString(MARGIN + 26 * mm, top - 10 * mm,
                        f'{reference}   ·   {record.patient_name or ""}'.strip())
        canv.drawRightString(PAGE_W - MARGIN, top - 10 * mm, clinic_name[:52])

        canv.setStrokeColor(HAIR)
        canv.setLineWidth(0.8)
        canv.line(MARGIN, top - 12.5 * mm, PAGE_W - MARGIN, top - 12.5 * mm)
        canv.setFillColor(brand_primary)
        canv.rect(MARGIN, top - 13.2 * mm, 18 * mm, 0.9 * mm, stroke=0, fill=1)
        canv.restoreState()

    def footer(canv, page, total):
        canv.saveState()
        y = 10 * mm
        canv.setStrokeColor(HAIR)
        canv.setLineWidth(0.6)
        canv.line(MARGIN, y + 4 * mm, PAGE_W - MARGIN, y + 4 * mm)
        canv.setFillColor(MUTED)
        canv.setFont('Helvetica', 6.6)
        canv.drawString(MARGIN, y, f'{clinic_name[:50]}   ·   {reference}')
        canv.drawCentredString(PAGE_W / 2, y, 'This report does not replace advice from your clinician.')
        canv.drawRightString(PAGE_W - MARGIN, y, f'Page {page} of {total}')
        canv.restoreState()

    buffer = BytesIO()
    doc = _PatientReportDoc(
        buffer, decorate_first=decorate_first,
        decorate_later=decorate_later, footer=footer,
    )

    # ── Styles ─────────────────────────────────────────────────────────────
    st_h1 = ParagraphStyle('h1', fontName='Helvetica-Bold', fontSize=13,
                           textColor=NAVY, leading=16)
    st_h2 = ParagraphStyle('h2', fontName='Helvetica-Bold', fontSize=10.5,
                           textColor=NAVY, leading=14)
    st_section = ParagraphStyle('section', fontName='Helvetica-Bold', fontSize=9,
                                textColor=NAVY, leading=12)
    st_body = ParagraphStyle('body', fontName='Helvetica', fontSize=8.6,
                             textColor=BODY, leading=12.6)
    st_body_s = ParagraphStyle('bodys', parent=st_body, fontSize=8, textColor=SLATE)
    st_label = ParagraphStyle('label', fontName='Helvetica-Bold', fontSize=6.4,
                              textColor=MUTED, leading=8.4)
    st_cell = ParagraphStyle('cell', fontName='Helvetica', fontSize=8.2, leading=11,
                             textColor=BODY)
    st_cell_b = ParagraphStyle('cellb', parent=st_cell, fontName='Helvetica-Bold',
                               textColor=NAVY)
    st_cell_r = ParagraphStyle('cellr', parent=st_cell, alignment=TA_RIGHT)
    st_cell_m = ParagraphStyle('cellm', parent=st_cell, textColor=SLATE, fontSize=7.6)
    st_hdr = ParagraphStyle('hdr', parent=st_cell_b, textColor=WHITE, fontSize=7)
    st_hdr_r = ParagraphStyle('hdrr', parent=st_hdr, alignment=TA_RIGHT)
    st_note = ParagraphStyle('note', fontName='Helvetica', fontSize=7.4,
                             textColor=SLATE, leading=10.4)

    def section(title, subtitle=None):
        block = [[
            Table([['']], colWidths=[1.3 * mm], rowHeights=[4 * mm],
                  style=TableStyle([('BACKGROUND', (0, 0), (-1, -1), brand_primary)])),
            Paragraph(_esc(title), st_section),
        ]]
        tbl = Table(block, colWidths=[3.4 * mm, CONTENT_W - 3.4 * mm])
        tbl.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ]))
        out = [tbl]
        if subtitle:
            out.append(Spacer(1, 1.4 * mm))
            out.append(Paragraph(_esc(subtitle), st_body_s))
        out.append(Spacer(1, 2.6 * mm))
        return out

    story = []
    story.append(Spacer(1, HERO_H - TOP_MARGIN - 3 * mm))

    # ── Status banner ───────────────────────────────────────────────────────
    if abnormal_rows:
        banner_bg, banner_fg, banner_line = WARN_BG, WARN, WARN_LINE
        headline = (
            f'{len(abnormal_rows)} result'
            f'{"s" if len(abnormal_rows) != 1 else ""} outside the reference range'
        )
        subline = (
            'These are flagged for your clinician to interpret — a single value '
            'outside the band is common and is not automatically a problem.'
        )
    else:
        banner_bg, banner_fg, banner_line = GOOD_BG, GOOD, GOOD_LINE
        headline = 'Everything measured is within the reference range'
        subline = (
            'No value in this report fell outside the range expected for you. '
            'Your clinician will still review it alongside your symptoms.'
        )

    banner = Table(
        [[Paragraph(
            f'<font size="10"><b>{_esc(headline)}</b></font><br/>'
            f'<font size="8" color="#475569">{_esc(subline)}</font>',
            ParagraphStyle('bn', fontName='Helvetica', fontSize=9, leading=13.5,
                           textColor=banner_fg),
        )]],
        colWidths=[CONTENT_W],
    )
    banner.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), banner_bg),
        ('BOX', (0, 0), (-1, -1), 0.8, banner_line),
        ('LEFTPADDING', (0, 0), (-1, -1), 12),
        ('RIGHTPADDING', (0, 0), (-1, -1), 12),
        ('TOPPADDING', (0, 0), (-1, -1), 9),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 9),
    ]))
    story.append(banner)
    story.append(Spacer(1, 5 * mm))

    # ── At a glance ────────────────────────────────────────────────────────
    story += section('At a glance')
    # Four equal columns; the gap comes from cell padding so the row can never
    # be wider than the frame (reportlab does not wrap an over-wide table, it
    # just pushes it off the page).
    gap = 3 * mm
    col_w = CONTENT_W / 4
    card_w = col_w - gap
    stats = [
        _mini_stat('Tests run', str(len(tests) or len(rows)), 'accent', card_w),
        _mini_stat(
            'Outside range', str(len(abnormal_rows)),
            'bad' if abnormal_rows else 'good', card_w,
        ),
        _mini_stat('Turnaround', _duration(record.turnaround_seconds), 'ink', card_w),
        _mini_stat(
            'Released', _fmt_date(verified_at) if verified_at else 'Pending',
            'good' if verified_at else 'warn', card_w,
        ),
    ]
    stats_row = Table([stats], colWidths=[col_w] * 4)
    stats_row.setStyle(TableStyle([
        ('LEFTPADDING', (0, 0), (-1, -1), 0),
        ('RIGHTPADDING', (0, 0), (-1, -1), gap),
        ('TOPPADDING', (0, 0), (-1, -1), 0),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    story.append(stats_row)
    story.append(Spacer(1, 6 * mm))

    # ── What this report is ────────────────────────────────────────────────
    intro = (
        f'This report contains <b>{len(tests) or len(rows)}</b> '
        f'test{"s" if (len(tests) or len(rows)) != 1 else ""} requested by '
        f'<b>{_esc(record.ordered_by_name or "your clinician")}</b>'
        + (f' on {_fmt_date(requested)}' if requested else '')
        + f'. The report was verified by <b>{_esc(record.verified_by_name or "the laboratory")}</b>'
        + (f' on {_fmt_date(verified_at)}' if verified_at else '')
        + '. Every measurement below is shown next to the range we expect for you, '
        'so you can see where your value sits.'
    )
    about = Table([[Paragraph(intro, st_body)]], colWidths=[CONTENT_W])
    about.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), SOFT),
        ('BOX', (0, 0), (-1, -1), 0.6, BORDER),
        ('LEFTPADDING', (0, 0), (-1, -1), 11),
        ('RIGHTPADDING', (0, 0), (-1, -1), 11),
        ('TOPPADDING', (0, 0), (-1, -1), 9),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 9),
    ]))
    story.append(about)
    story.append(Spacer(1, 6 * mm))

    # ── Results needing attention ──────────────────────────────────────────
    if abnormal_rows:
        story += section(
            'Results that need attention',
            'These values sit outside the reference range. They are highlighted '
            'so you can raise them with your clinician — not to alarm you.',
        )
        for row in abnormal_rows[:8]:
            direction = 'above' if row['flag'] == 'High' else 'below'
            meaning = DEPARTMENT_MEANING.get(
                (row['department'] or '').lower(),
                'how that part of your body is working',
            )
            left = [
                Paragraph(_esc(row['label']), st_cell_b),
                Spacer(1, 1),
                Paragraph(
                    _esc(f'{row["test"]} · {row["department"]}'.strip(' ·')),
                    st_note,
                ),
            ]
            value_block = [
                Paragraph(
                    f'<font size="13"><b>{_esc(row["value_text"])}</b></font>',
                    ParagraphStyle('v', fontName='Helvetica-Bold', fontSize=13,
                                   textColor=BAD, leading=15, alignment=TA_RIGHT),
                ),
                Paragraph(_esc(f'reference {row["range_text"] or "—"}'),
                          ParagraphStyle('vr', fontName='Helvetica', fontSize=7,
                                         textColor=MUTED, leading=9, alignment=TA_RIGHT)),
            ]
            guidance = (
                f'This is <b>{_esc(direction)}</b> the expected range. '
                f'It reflects {_esc(meaning)}. A single out-of-range value is '
                'common and is read together with your symptoms and history.'
            )
            card = Table(
                [[left, value_block],
                 [Paragraph(guidance, st_note), '']],
                colWidths=[CONTENT_W - 40 * mm, 40 * mm],
            )
            card.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, -1), BAD_BG),
                ('BOX', (0, 0), (-1, -1), 0.7, BAD_LINE),
                ('LINEBEFORE', (0, 0), (0, -1), 2.4, BAD),
                ('VALIGN', (0, 0), (-1, 0), 'TOP'),
                ('LEFTPADDING', (0, 0), (-1, -1), 10),
                ('RIGHTPADDING', (0, 0), (-1, -1), 10),
                ('TOPPADDING', (0, 0), (-1, 0), 8),
                ('BOTTOMPADDING', (0, 0), (-1, 0), 2),
                ('TOPPADDING', (0, 1), (-1, 1), 3),
                ('BOTTOMPADDING', (0, 1), (-1, 1), 8),
                ('SPAN', (0, 1), (1, 1)),
            ]))
            story.append(KeepTogether([card, Spacer(1, 2.4 * mm)]))

        if len(abnormal_rows) > 8:
            story.append(Paragraph(
                _esc(f'… and {len(abnormal_rows) - 8} more flagged value(s) in the '
                     'table below.'),
                st_body_s,
            ))
            story.append(Spacer(1, 3 * mm))
        story.append(Spacer(1, 3 * mm))

    # ── Full results ───────────────────────────────────────────────────────
    story += section(
        'Your results',
        'The bar shows where your result sits. The green band is the expected '
        'range; the dot is you.',
    )

    if not rows:
        story.append(Paragraph(
            'No results have been recorded for this request yet.', st_body_s,
        ))
    else:
        col_widths = [
            CONTENT_W - (24 * mm + 30 * mm + 30 * mm + 26 * mm),
            24 * mm, 30 * mm, 30 * mm, 26 * mm,
        ]
        header = [
            Paragraph('TEST', st_hdr),
            Paragraph('RESULT', st_hdr_r),
            Paragraph('REFERENCE', st_hdr_r),
            Paragraph('WHERE YOU SIT', st_hdr),
            Paragraph('FLAG', st_hdr_r),
        ]
        data = [header]
        flagged_rows = []
        for index, row in enumerate(rows):
            flag_text = row['flag'] or ('Abnormal' if row['is_abnormal'] else 'In range')
            flag_color = BAD if row['flag'] in ('High', 'Low') or row['is_abnormal'] else GOOD
            label_cell = [Paragraph(_esc(row['label']), st_cell_b)]
            if row['label'] != row['test']:
                label_cell.append(Paragraph(_esc(row['test']), st_cell_m))
            data.append([
                label_cell,
                Paragraph(_esc(row['value_text']), ParagraphStyle(
                    'val', parent=st_cell_r, fontName='Helvetica-Bold',
                    textColor=BAD if row['flag'] in ('High', 'Low') else NAVY,
                )),
                Paragraph(_esc(row['range_text'] or '—'), st_cell_r),
                _range_bar(row['number'], row['bounds'], width=28 * mm, height=8 * mm,
                           tone=row['tone']),
                Paragraph(_esc(flag_text), ParagraphStyle(
                    'flag', parent=st_cell_r, fontName='Helvetica-Bold',
                    fontSize=7.2, textColor=flag_color,
                )),
            ])
            if row['flag'] in ('High', 'Low') or row['is_abnormal']:
                flagged_rows.append(index + 1)

        table = Table(data, colWidths=col_widths, repeatRows=1)
        table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), NAVY),
            ('TEXTCOLOR', (0, 0), (-1, 0), WHITE),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, -1), 7),
            ('RIGHTPADDING', (0, 0), (-1, -1), 7),
            ('TOPPADDING', (0, 0), (-1, -1), 5),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
            ('LINEBELOW', (0, 0), (-1, -2), 0.4, HAIR),
            ('LINEBELOW', (0, -1), (-1, -1), 0.8, BORDER),
            *[('BACKGROUND', (0, i), (-1, i), BAD_BG) for i in flagged_rows],
        ]))
        story.append(table)

    story.append(Spacer(1, 6 * mm))

    # ── What each test measured ────────────────────────────────────────────
    described = [t for t in tests if (t.get('description') or '').strip()]
    if described:
        story += section('What each test measured')
        for test in described:
            card = Table(
                [[Paragraph(
                    f'<b>{_esc(test.get("name"))}</b>'
                    + (f'  <font color="#94A3B8" size="6.6">{_esc(test.get("code"))}</font>'
                       if test.get('code') else ''),
                    st_cell,
                )],
                 [Paragraph(_esc(test.get('description')), st_note)]],
                colWidths=[CONTENT_W],
            )
            card.setStyle(TableStyle([
                ('LINEBEFORE', (0, 0), (0, -1), 1.6, brand_primary),
                ('LEFTPADDING', (0, 0), (-1, -1), 9),
                ('RIGHTPADDING', (0, 0), (-1, -1), 8),
                ('TOPPADDING', (0, 0), (-1, 0), 5),
                ('BOTTOMPADDING', (0, 0), (-1, 0), 1),
                ('TOPPADDING', (0, 1), (-1, 1), 1),
                ('BOTTOMPADDING', (0, 1), (-1, 1), 5),
            ]))
            story.append(KeepTogether([card, Spacer(1, 2 * mm)]))
        story.append(Spacer(1, 4 * mm))

    # ── Journey ────────────────────────────────────────────────────────────
    story += section('Your test journey')
    steps = [('Requested', requested)]
    if record.stage in ('sample_collected', 'processing', 'ready', 'released'):
        steps.append(('Sample collected', record.stage_updated_at if record.stage == 'sample_collected' else None))
    if record.stage in ('processing', 'ready', 'released'):
        steps.append(('Analysed', record.performed_at))
    if record.stage in ('ready', 'released'):
        steps.append(('Report verified', verified_at))

    journey_cells = []
    for label, when in steps:
        journey_cells.append([
            Paragraph(_esc(label), ParagraphStyle(
                'js', fontName='Helvetica-Bold', fontSize=7, textColor=MUTED, leading=9,
            )),
            Paragraph(_esc(_fmt_dt(when) if when else '—'), ParagraphStyle(
                'jv', fontName='Helvetica-Bold', fontSize=8.2, textColor=NAVY, leading=11,
            )),
        ])
    if journey_cells:
        cell_w = CONTENT_W / len(journey_cells)
        journey = Table([journey_cells], colWidths=[cell_w] * len(journey_cells))
        journey.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), SOFT),
            ('BOX', (0, 0), (-1, -1), 0.6, BORDER),
            ('INNERGRID', (0, 0), (-1, -1), 0.4, HAIR),
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 8),
            ('RIGHTPADDING', (0, 0), (-1, -1), 6),
            ('TOPPADDING', (0, 0), (-1, -1), 7),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 7),
        ]))
        story.append(journey)
        story.append(Spacer(1, 6 * mm))

    # ── Care team ──────────────────────────────────────────────────────────
    people = []
    if record.ordered_by_name:
        people.append(('Requested by', record.ordered_by_name, _fmt_dt(requested)))
    if record.performed_by_name:
        people.append(('Analysed by', record.performed_by_name,
                       _fmt_dt(record.performed_at) if record.performed_at else '—'))
    if record.verified_by_name:
        people.append(('Verified by', record.verified_by_name,
                       _fmt_dt(verified_at) if verified_at else '—'))
    if people:
        story += section('Your care team')
        rows_people = [[
            Paragraph('ROLE', st_label),
            Paragraph('NAME', st_label),
            Paragraph('WHEN', ParagraphStyle('wl', parent=st_label, alignment=TA_RIGHT)),
        ]]
        for role, name, when in people:
            rows_people.append([
                Paragraph(_esc(role), st_body_s),
                Paragraph(_esc(name), st_cell_b),
                Paragraph(_esc(when), st_cell_r),
            ])
        pt = Table(rows_people, colWidths=[38 * mm, CONTENT_W - 38 * mm - 42 * mm, 42 * mm])
        pt.setStyle(TableStyle([
            ('LINEBELOW', (0, 0), (-1, 0), 0.7, BORDER),
            ('LINEBELOW', (0, 1), (-1, -1), 0.4, HAIR),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 5),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ]))
        story.append(pt)
        story.append(Spacer(1, 6 * mm))

    # ── Notes ──────────────────────────────────────────────────────────────
    if (record.clinical_notes or '').strip():
        story += section('Notes from your clinician')
        note = Table([[Paragraph(_esc(record.clinical_notes), st_body)]],
                     colWidths=[CONTENT_W])
        note.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), SOFT),
            ('BOX', (0, 0), (-1, -1), 0.6, BORDER),
            ('LEFTPADDING', (0, 0), (-1, -1), 11),
            ('RIGHTPADDING', (0, 0), (-1, -1), 11),
            ('TOPPADDING', (0, 0), (-1, -1), 9),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 9),
        ]))
        story.append(note)
        story.append(Spacer(1, 6 * mm))

    # ── Next steps ─────────────────────────────────────────────────────────
    story += section('What to do next')
    next_steps = [
        'Take this report to your next appointment — your clinician will read it '
        'together with your symptoms and examination.',
        'If any result is flagged and you feel unwell, contact your clinic rather '
        'than waiting for the appointment.',
        'Do not start, stop or change any medicine based on this report alone.',
        'If you need a printed copy, download this report again from your patient '
        'dashboard at any time.',
    ]
    for index, line in enumerate(next_steps, start=1):
        story.append(Table(
            [[Paragraph(str(index), ParagraphStyle(
                'n', fontName='Helvetica-Bold', fontSize=7.6,
                textColor=brand_primary, alignment=TA_CENTER, leading=10)),
              Paragraph(_esc(line), st_body)]],
            colWidths=[6 * mm, CONTENT_W - 8 * mm],
            style=TableStyle([
                ('BACKGROUND', (0, 0), (0, 0), HexColor('#EEF3FF')),
                ('VALIGN', (0, 0), (-1, -1), 'TOP'),
                ('LEFTPADDING', (0, 0), (0, 0), 0),
                ('RIGHTPADDING', (0, 0), (0, 0), 0),
                ('TOPPADDING', (0, 0), (0, 0), 2),
                ('BOTTOMPADDING', (0, 0), (0, 0), 2),
                ('LEFTPADDING', (1, 0), (1, 0), 8),
                ('TOPPADDING', (1, 0), (1, 0), 1),
                ('BOTTOMPADDING', (1, 0), (1, 0), 5),
            ]),
        ))
    story.append(Spacer(1, 6 * mm))

    # ── Glossary ───────────────────────────────────────────────────────────
    terms = []
    seen = set()
    for row in rows:
        for candidate in (row['label'], row['test_code'], row['test']):
            key = re.sub(r'[^a-z0-9]', '', str(candidate or '').lower())
            if key in GLOSSARY and key not in seen:
                seen.add(key)
                terms.append((candidate, GLOSSARY[key]))
                break
    if terms:
        story += section('Understanding your report')
        gdata = [[
            Paragraph('TERM', st_label),
            Paragraph('WHAT IT MEANS', st_label),
        ]]
        for term, (full, meaning) in terms[:14]:
            gdata.append([
                Paragraph(f'<b>{_esc(term)}</b>  <font color="#94A3B8" size="6.6">'
                          f'{_esc(full)}</font>', st_body_s),
                Paragraph(_esc(meaning), st_body_s),
            ])
        gt = Table(gdata, colWidths=[62 * mm, CONTENT_W - 62 * mm])
        gt.setStyle(TableStyle([
            ('LINEBELOW', (0, 0), (-1, 0), 0.7, BORDER),
            ('LINEBELOW', (0, 1), (-1, -1), 0.35, HAIR),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 6),
            ('TOPPADDING', (0, 0), (-1, -1), 4),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ]))
        story.append(gt)
        story.append(Spacer(1, 6 * mm))

    # ── Disclaimer ─────────────────────────────────────────────────────────
    disclaimer = Table(
        [[Paragraph(
            f'<b>Important</b> — {_esc(DISCLAIMER)}',
            ParagraphStyle('dis', fontName='Helvetica', fontSize=7.2,
                           textColor=SLATE, leading=10.4),
        )]],
        colWidths=[CONTENT_W],
    )
    disclaimer.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), HexColor('#F8FAFC')),
        ('BOX', (0, 0), (-1, -1), 0.6, BORDER),
        ('LEFTPADDING', (0, 0), (-1, -1), 10),
        ('RIGHTPADDING', (0, 0), (-1, -1), 10),
        ('TOPPADDING', (0, 0), (-1, -1), 8),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
    ]))
    story.append(KeepTogether([disclaimer]))

    doc.build(story, canvasmaker=lambda *a, **kw: _NumberedCanvas(
        *a, footer=footer, **kw,
    ))
    return buffer.getvalue()
