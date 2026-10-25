"""Premium A4 laboratory report PDF for a lab order.

Produces a clinical-grade report laid out like a reference-laboratory document:

    ┌ branded letterhead ──────────────────────────────────────────┐
    │ logo · clinic name / address / contacts      LABORATORY REPORT │
    ├ accent rule ──────────────────────────────────────────────────┤
    │ ORDER #   ACCESSION #   COLLECTED   REPORTED   (meta cards)   │
    ├───────────────────────────┬───────────────────────────────────┤
    │ PATIENT                   │ REQUESTED BY / BILLING            │
    ├───────────────────────────┴───────────────────────────────────┤
    │ TEST RESULTS  (per department, analyte-level rows)            │
    │ SPECIMENS                                                     │
    │ CLINICAL NOTES                                                │
    │ sign-off: performed / verified / signature + disclaimer        │
    └ footer: clinic · page n of m · powered by AdhereMed ──────────┘

Handles both single-value results and panel results that were composed by the
UI as ``"Hb: 14.2 g/dL · WBC: 7.2 x10^9/L"`` — those are split back into one
row per analyte with the catalogue's reference range and a computed flag.
An unverified report carries a light ``PRELIMINARY`` watermark.
"""
import io
import re
from io import BytesIO

from reportlab.lib.colors import HexColor, Color
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas
from reportlab.platypus import (
    HRFlowable, Image as RLImage, KeepTogether, Paragraph, SimpleDocTemplate,
    Spacer, Table, TableStyle,
)

# ── Palette ─────────────────────────────────────────────────────────────────
NAVY = HexColor('#0F172A')
INK = HexColor('#1E293B')
SLATE = HexColor('#64748B')
MUTED = HexColor('#94A3B8')
BORDER = HexColor('#E2E8F0')
SOFT = HexColor('#F8FAFC')
TINT = HexColor('#EFF6FF')
ACCENT = HexColor('#2F6DFF')
ACCENT_DEEP = HexColor('#1D4ED8')
WHITE = HexColor('#FFFFFF')
GOOD = HexColor('#047857')
GOOD_BG = HexColor('#ECFDF5')
WARN = HexColor('#B45309')
WARN_BG = HexColor('#FFFBEB')
BAD = HexColor('#B91C1C')
BAD_BG = HexColor('#FEF2F2')
INFO = HexColor('#1D4ED8')
INFO_BG = HexColor('#EFF6FF')

PAGE_W = A4[0] - 30 * mm  # usable content width

# ── Reference-range helpers ─────────────────────────────────────────────────
NON_ANALYTE = re.compile(
    r'^(normal|abnormal|male|female|adult|child|children|newborn|infant|'
    r'pre-?diabetic|diabetic|non-?diabetic|undetectable|detectable|'
    r'non-?pregnant|pregnant|deficient|insufficient|sufficient|optimal|'
    r'borderline|high|low|critical|sepsis(_likely)?|morning|evening|fasting|'
    r'random|negative|positive|impaired|baseline|impaired_?2hr|normal_?2hr)$',
    re.I,
)
RANGE_RE = re.compile(r'^(-?\d+(?:\.\d+)?)\s*(?:-|–|to)\s*(-?\d+(?:\.\d+)?)\s*(.*)$', re.I)
BOUND_RE = re.compile(r'^(<=|>=|<|>)\s*(-?\d+(?:\.\d+)?)\s*(.*)$')
VALUE_UNIT_RE = re.compile(r'^(-?\d+(?:\.\d+)?)\s*(.*)$')

STATUS_LABELS = {
    'pending': 'Pending',
    'sample_collected': 'Sample collected',
    'processing': 'Processing',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
}


def _esc(value):
    """Escape text for reportlab Paragraph markup."""
    return (
        str(value if value is not None else '')
        .replace('&', '&amp;')
        .replace('<', '&lt;')
        .replace('>', '&gt;')
    )


def _fmt_date(value):
    return value.strftime('%d %b %Y') if value else '—'


def _fmt_dt(value):
    if not value:
        return '—'
    try:
        return value.strftime('%d %b %Y · %H:%M')
    except (AttributeError, ValueError):
        return '—'


def _parse_range(text):
    """Parse '12.0-17.0 g/dL', '<5.2 mmol/L', '>=7.0' into a bounds dict."""
    raw = str(text or '').strip()
    if not raw:
        return None
    match = RANGE_RE.match(raw)
    if match:
        return {
            'low': float(match.group(1)),
            'high': float(match.group(2)),
            'unit': match.group(3).strip(),
        }
    match = BOUND_RE.match(raw)
    if match:
        operator, bound, unit = match.group(1), float(match.group(2)), match.group(3).strip()
        if operator in ('<', '<='):
            return {'low': None, 'high': bound, 'unit': unit}
        return {'low': bound, 'high': None, 'unit': unit}
    return None


def _flag_for(value_text, bounds):
    """Return ('High'|'Low'|'Normal'|'Abnormal'|'', tone) for a numeric value."""
    if not bounds:
        return '', 'muted'
    match = VALUE_UNIT_RE.match(str(value_text or '').strip())
    if not match:
        return '', 'muted'
    try:
        number = float(match.group(1))
    except ValueError:
        return '', 'muted'
    if bounds['low'] is not None and number < bounds['low']:
        return 'Low', 'bad'
    if bounds['high'] is not None and number > bounds['high']:
        return 'High', 'bad'
    return 'Normal', 'good'


def _split_value_unit(text, fallback_unit=''):
    """'14.2 g/dL' → ('14.2', 'g/dL')."""
    raw = str(text or '').strip()
    match = VALUE_UNIT_RE.match(raw)
    if match:
        return match.group(1), (match.group(2) or fallback_unit).strip()
    return raw or '—', fallback_unit


def _latest_result(test_id, results):
    matches = [r for r in results if r.test_id == test_id]
    if not matches:
        return None
    return sorted(matches, key=lambda r: r.result_date or 0)[-1]


def _result_rows(test, result, st_cell, st_cell_b, st_cell_r, st_cell_m):
    """Build the analyte-level rows for one test.

    Returns a list of ``[label, value, unit, reference, flag]`` where each cell
    is ``(text, style_name, tone)`` so the caller can apply colours.
    """
    ranges = test.reference_ranges if isinstance(test.reference_ranges, dict) else {}
    analyte_keys = [k for k in ranges if not NON_ANALYTE.match(str(k).strip())]
    raw = (result.result_value if result else '') or ''
    marked_abnormal = bool(result.is_abnormal) if result else False

    # Split a UI-composed panel value ("Hb: 14.2 g/dL · WBC: 7.2 x10^9/L").
    parsed = {}
    for chunk in re.split(r'\s*[·|;]\s*', raw):
        head = re.match(r'^(.+?):\s*(.+)$', chunk)
        if head:
            parsed[head.group(1).strip().lower()] = head.group(2).strip()

    if len(analyte_keys) >= 2 and parsed:
        rows = []
        matched_any = False
        for key in analyte_keys:
            label = str(key).strip()
            value_text = parsed.get(label.lower())
            bounds = _parse_range(ranges.get(key))
            if value_text is None:
                rows.append((label, ('—', 'cell_m', 'muted'),
                             (bounds['unit'] if bounds else '', 'cell_m', 'muted'),
                             (str(ranges.get(key)), 'cell_m', 'muted'),
                             ('', 'cell_m', 'muted')))
                continue
            matched_any = True
            value, unit = _split_value_unit(value_text, bounds['unit'] if bounds else '')
            flag, tone = _flag_for(value, bounds)
            if not flag and marked_abnormal:
                flag, tone = 'Abnormal', 'bad'
            rows.append((label, (value, 'cell_b', 'ink'),
                         (unit or '—', 'cell_m', 'muted'),
                         (str(ranges.get(key)), 'cell_m', 'muted'),
                         (flag or '—', 'cell_b', tone)))
        if matched_any:
            return rows

    # Single-value test (or a result we could not decompose).
    if result is None:
        return [('', ('Awaiting result', 'cell_m', 'muted'), ('', 'cell_m', 'muted'),
                 ('', 'cell_m', 'muted'), ('Pending', 'cell_b', 'warn'))]

    # A multi-analyte test whose value is free text (e.g. "Negative") cannot be
    # attributed to one analyte, so don't quote a single analyte's range.
    ambiguous = len(analyte_keys) >= 2
    preferred = None
    if not ambiguous:
        for key in ranges:
            if str(key).strip().lower() == 'normal':
                preferred = key
                break
        if preferred is None and ranges:
            preferred = next(iter(ranges))
    bounds = _parse_range(ranges.get(preferred)) if preferred else None
    value, unit = _split_value_unit(raw, result.unit or (bounds['unit'] if bounds else ''))
    flag, tone = _flag_for(value, bounds)
    if not flag and marked_abnormal:
        flag, tone = 'Abnormal', 'bad'
    reference = str(ranges.get(preferred)) if preferred else '—'
    return [('', (value, 'cell_b', 'ink'), (unit or '—', 'cell_m', 'muted'),
             (reference, 'cell_m', 'muted'), (flag or '—', 'cell_b', tone))]


# ── Canvas with "page n of m" ───────────────────────────────────────────────
class _NumberedCanvas(canvas.Canvas):
    """Two-pass canvas so the footer can say ``Page n of m``."""

    def __init__(self, *args, footer=None, **kwargs):
        self._footer = footer
        canvas.Canvas.__init__(self, *args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        total = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            if self._footer:
                self._footer(self, self._pageNumber, total)
            canvas.Canvas.showPage(self)
        canvas.Canvas.save(self)


def build_lab_order_report(order, *, request=None):
    """Render a premium laboratory report for ``order`` and return PDF bytes."""
    from config.pdf_branding import resolve_branding

    tenant = getattr(request, 'tenant', None)
    logo_path, business_name = resolve_branding(request) if request else (None, '')

    tests = list(order.tests.all())
    results = list(order.results.select_related('test', 'performed_by', 'verified_by'))
    specimens = list(order.specimens.all())
    extra = getattr(order, 'extra', None)
    patient = order.patient
    patient_user = getattr(patient, 'user', None)
    patient_name = (
        getattr(patient_user, 'full_name', '') if patient_user else ''
    ) or f'Patient #{getattr(patient, "patient_number", '')}'

    resulted_tests = [t for t in tests if _latest_result(t.id, results)]
    abnormal_results = [r for r in results if r.is_abnormal]
    unverified = [r for r in results if not r.verified_by]
    preliminary = bool(results) and bool(unverified)

    # ── Styles ──────────────────────────────────────────────────────────────
    st_brand = ParagraphStyle('brand', fontName='Helvetica-Bold', fontSize=13.5,
                              textColor=NAVY, leading=17)
    st_brand_sub = ParagraphStyle('brandsub', fontName='Helvetica', fontSize=8,
                                  textColor=SLATE, leading=11)
    st_doctitle = ParagraphStyle('doctitle', fontName='Helvetica-Bold', fontSize=18,
                                 textColor=ACCENT, leading=21, alignment=TA_RIGHT)
    st_docsub = ParagraphStyle('docsub', fontName='Helvetica', fontSize=8.5,
                               textColor=SLATE, leading=12, alignment=TA_RIGHT)
    st_label = ParagraphStyle('label', fontName='Helvetica-Bold', fontSize=6.5,
                              textColor=SLATE, leading=9)
    st_value = ParagraphStyle('value', fontName='Helvetica-Bold', fontSize=10,
                              textColor=NAVY, leading=13)
    st_section = ParagraphStyle('section', fontName='Helvetica-Bold', fontSize=9,
                                textColor=NAVY, leading=12)
    st_body = ParagraphStyle('body', fontName='Helvetica', fontSize=8.5,
                             textColor=INK, leading=12.5)
    st_body_s = ParagraphStyle('bodys', parent=st_body, fontSize=8, textColor=SLATE)
    st_dept = ParagraphStyle('dept', fontName='Helvetica-Bold', fontSize=7,
                             textColor=ACCENT_DEEP, leading=9)
    st_cell = ParagraphStyle('cell', fontName='Helvetica', fontSize=8.5, leading=11.5,
                             textColor=INK)
    st_cell_b = ParagraphStyle('cellb', parent=st_cell, fontName='Helvetica-Bold',
                               textColor=NAVY)
    st_cell_r = ParagraphStyle('cellr', parent=st_cell, alignment=TA_RIGHT)
    st_cell_m = ParagraphStyle('cellm', parent=st_cell, textColor=SLATE, fontSize=8)
    st_hdr = ParagraphStyle('hdr', parent=st_cell_b, textColor=WHITE, fontSize=7.5)
    st_hdr_r = ParagraphStyle('hdrr', parent=st_hdr, alignment=TA_RIGHT)
    st_pill = ParagraphStyle('pill', fontName='Helvetica-Bold', fontSize=7,
                             textColor=WHITE, alignment=TA_CENTER)
    st_test_name = ParagraphStyle('testname', fontName='Helvetica-Bold', fontSize=9,
                                  textColor=NAVY, leading=12)
    st_note = ParagraphStyle('note', fontName='Helvetica-Oblique', fontSize=7.2,
                             textColor=SLATE, leading=10.5)
    st_sign_name = ParagraphStyle('signname', fontName='Helvetica-Bold', fontSize=8.5,
                                  textColor=NAVY, leading=11)
    st_sign_role = ParagraphStyle('signrole', fontName='Helvetica', fontSize=7.2,
                                  textColor=SLATE, leading=10)

    def tone_color(tone):
        return {
            'ink': NAVY, 'bad': BAD, 'good': GOOD, 'warn': WARN, 'muted': SLATE,
        }.get(tone, INK)

    def section_heading(text):
        bar = Table([['']], colWidths=[1.2 * mm], rowHeights=[3.6 * mm])
        bar.setStyle(TableStyle([('BACKGROUND', (0, 0), (-1, -1), ACCENT)]))
        block = Table([[bar, Paragraph(_esc(text), st_section)]],
                      colWidths=[3.2 * mm, PAGE_W - 3.2 * mm])
        block.setStyle(TableStyle([
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ]))
        return block

    def chip(text, fg, bg, width=30 * mm):
        table = Table([[Paragraph(_esc(text), ParagraphStyle(
            'chip', fontName='Helvetica-Bold', fontSize=7.5, textColor=fg,
            alignment=TA_CENTER, leading=10))]], colWidths=[width])
        table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), bg),
            ('TOPPADDING', (0, 0), (-1, -1), 3),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
            ('LEFTPADDING', (0, 0), (-1, -1), 4),
            ('RIGHTPADDING', (0, 0), (-1, -1), 4),
        ]))
        return table

    def meta_card(label, value_flowable, width=42 * mm):
        card = Table([[Paragraph(_esc(label), st_label)], [value_flowable]],
                     colWidths=[width])
        card.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), SOFT),
            ('BOX', (0, 0), (-1, -1), 0.7, BORDER),
            ('LEFTPADDING', (0, 0), (-1, -1), 8),
            ('RIGHTPADDING', (0, 0), (-1, -1), 8),
            ('TOPPADDING', (0, 0), (-1, 0), 6),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 1),
            ('TOPPADDING', (0, 1), (-1, 1), 2),
            ('BOTTOMPADDING', (0, 1), (-1, 1), 6),
        ]))
        return card

    story = []

    # ── Letterhead ──────────────────────────────────────────────────────────
    tenant_lines = []
    if tenant:
        addr = ', '.join(x for x in [
            getattr(tenant, 'address', '') or '',
            getattr(tenant, 'city', '') or '',
        ] if x)
        if addr:
            tenant_lines.append(addr)
        contact = ' · '.join(x for x in [
            getattr(tenant, 'phone', '') or '',
            getattr(tenant, 'email', '') or '',
        ] if x)
        if contact:
            tenant_lines.append(contact)
    if order.clinic_site:
        tenant_lines.append(f'Laboratory: {order.clinic_site.name}')

    left_block = [Paragraph(_esc(business_name or 'Laboratory'), st_brand)]
    left_block += [Paragraph(_esc(line), st_brand_sub) for line in tenant_lines]

    right_block = [
        Paragraph('LABORATORY REPORT', st_doctitle),
        Paragraph(f'Report · {order.id:05d}', st_docsub),
        Spacer(1, 2),
        Paragraph(
            'FINAL REPORT' if not preliminary else 'PRELIMINARY · NOT YET VERIFIED',
            ParagraphStyle(
                'final', fontName='Helvetica-Bold', fontSize=7.5,
                textColor=GOOD if not preliminary else WARN,
                alignment=TA_RIGHT, leading=10,
            ),
        ),
    ]

    header_cells = [left_block, right_block]
    right_w = 72 * mm
    header_widths = [PAGE_W - right_w, right_w]
    if logo_path:
        try:
            header_cells.insert(0, RLImage(logo_path, width=15 * mm, height=15 * mm,
                                           kind='proportional'))
            header_widths = [17 * mm, PAGE_W - 17 * mm - right_w, right_w]
        except Exception:
            pass
    header_tbl = Table([header_cells], colWidths=header_widths)
    header_tbl.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 0),
        ('RIGHTPADDING', (0, 0), (0, 0), 8),
        ('RIGHTPADDING', (-1, 0), (-1, 0), 0),
        ('TOPPADDING', (0, 0), (-1, -1), 0),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
    ]))
    story.append(header_tbl)
    story.append(Spacer(1, 3.5 * mm))
    story.append(HRFlowable(width='100%', thickness=1.6, color=ACCENT,
                            spaceBefore=0, spaceAfter=4 * mm))

    # ── Meta cards ──────────────────────────────────────────────────────────
    gap = 4 * mm
    card_w = (PAGE_W - 3 * gap) / 4
    accession = (getattr(extra, 'accession_number', '') or '').strip()
    priority = (order.priority or 'routine')
    status_label = STATUS_LABELS.get(order.status, order.status)

    row_one = Table([[
        meta_card('ORDER NUMBER', Paragraph(f'#{order.id:05d}', st_value), card_w),
        '', meta_card('ACCESSION NUMBER', Paragraph(_esc(accession or '—'), st_value), card_w),
        '', meta_card('COLLECTED', Paragraph(
            _fmt_dt(specimens[0].collected_at) if specimens and specimens[0].collected_at
            else '—', ParagraphStyle('v2', parent=st_value, fontSize=9)), card_w),
        '', meta_card('REPORTED', Paragraph(
            _fmt_dt(order.updated_at), ParagraphStyle('v3', parent=st_value, fontSize=9)), card_w),
    ]], colWidths=[card_w, gap, card_w, gap, card_w, gap, card_w])
    row_one.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 0),
        ('RIGHTPADDING', (0, 0), (-1, -1), 0),
        ('TOPPADDING', (0, 0), (-1, -1), 0),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
    ]))
    story.append(row_one)
    story.append(Spacer(1, gap))

    priority_colors = {
        'stat': (BAD, BAD_BG), 'urgent': (WARN, WARN_BG), 'routine': (INFO, INFO_BG),
    }
    prio_fg, prio_bg = priority_colors.get(priority, (SLATE, SOFT))
    status_colors = {
        'completed': (GOOD, GOOD_BG), 'cancelled': (BAD, BAD_BG),
        'processing': (INFO, INFO_BG), 'sample_collected': (INFO, INFO_BG),
        'pending': (WARN, WARN_BG),
    }
    stat_fg, stat_bg = status_colors.get(order.status, (SLATE, SOFT))

    row_two = Table([[
        meta_card('PRIORITY', chip(priority.upper(), prio_fg, prio_bg, card_w - 16), card_w),
        '', meta_card('STATUS', chip(status_label, stat_fg, stat_bg, card_w - 16), card_w),
        '', meta_card('TESTS', Paragraph(
            f'{len(resulted_tests)} of {len(tests)} resulted',
            ParagraphStyle('v4', parent=st_value, fontSize=9)), card_w),
        '', meta_card('ABNORMAL FLAGS', Paragraph(
            str(len(abnormal_results)),
            ParagraphStyle('v5', parent=st_value, fontSize=9,
                           textColor=BAD if abnormal_results else NAVY)), card_w),
    ]], colWidths=[card_w, gap, card_w, gap, card_w, gap, card_w])
    row_two.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 0),
        ('RIGHTPADDING', (0, 0), (-1, -1), 0),
        ('TOPPADDING', (0, 0), (-1, -1), 0),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
    ]))
    story.append(row_two)
    story.append(Spacer(1, 7 * mm))

    # ── Patient / requester ─────────────────────────────────────────────────
    age_text = ''
    if getattr(patient, 'date_of_birth', None):
        today = order.updated_at.date() if order.updated_at else None
        if today:
            born = patient.date_of_birth
            years = today.year - born.year - ((today.month, today.day) < (born.month, born.day))
            age_text = f'{years} yrs'
    gender = (getattr(patient, 'gender', '') or '').capitalize()

    patient_lines = [Paragraph(_esc(patient_name),
                               ParagraphStyle('pname', parent=st_cell_b, fontSize=10.5,
                                              leading=13))]
    demographics = ' · '.join(x for x in [
        f'Patient #{getattr(patient, "patient_number", "")}' if getattr(patient, 'patient_number', '') else '',
        age_text,
        gender,
        (getattr(patient, 'blood_type', '') or ''),
    ] if x)
    if demographics:
        patient_lines.append(Paragraph(_esc(demographics), st_body_s))
    phone = getattr(patient_user, 'phone', '') if patient_user else ''
    if phone:
        patient_lines.append(Paragraph(f'Phone: {_esc(phone)}', st_body_s))
    if getattr(patient, 'national_id', ''):
        patient_lines.append(Paragraph(f'ID: {_esc(patient.national_id)}', st_body_s))

    requester_lines = [Paragraph(_esc(order.ordered_by.full_name if order.ordered_by else '—'),
                                 ParagraphStyle('rname', parent=st_cell_b, fontSize=10.5,
                                                leading=13))]
    if getattr(extra, 'referring_doctor_name', None):
        requester_lines.append(Paragraph(f'Referring: {_esc(extra.referring_doctor_name)}', st_body_s))
    if getattr(extra, 'referring_facility_name', None):
        requester_lines.append(Paragraph(_esc(extra.referring_facility_name), st_body_s))
    if extra and getattr(extra, 'payer_type', ''):
        requester_lines.append(Paragraph(f'Payer: {_esc(extra.payer_type)}', st_body_s))
    requester_lines.append(Paragraph(
        f'Ordered {_fmt_dt(order.created_at)}', st_body_s))

    half = (PAGE_W - 8 * mm) / 2
    party_tbl = Table([[
        [section_heading('PATIENT'), Spacer(1, 3 * mm), *patient_lines],
        [section_heading('REQUESTED BY'), Spacer(1, 3 * mm), *requester_lines],
    ]], colWidths=[half, half])
    party_tbl.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (0, 0), 0),
        ('LEFTPADDING', (1, 0), (1, 0), 8 * mm),
        ('RIGHTPADDING', (0, 0), (-1, -1), 0),
        ('TOPPADDING', (0, 0), (-1, -1), 0),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
    ]))
    story.append(party_tbl)
    story.append(Spacer(1, 7 * mm))

    # ── Test results ────────────────────────────────────────────────────────
    story.append(section_heading('TEST RESULTS'))
    story.append(Spacer(1, 3 * mm))

    widths = [58 * mm, 34 * mm, 20 * mm, 48 * mm, 20 * mm]
    rows = [[
        Paragraph('TEST / ANALYTE', st_hdr),
        Paragraph('RESULT', st_hdr_r),
        Paragraph('UNIT', st_hdr),
        Paragraph('REFERENCE RANGE', st_hdr),
        Paragraph('FLAG', st_hdr),
    ]]
    styles = [
        ('BACKGROUND', (0, 0), (-1, 0), NAVY),
        ('LINEBELOW', (0, 0), (-1, 0), 1, ACCENT),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
        ('TOPPADDING', (0, 0), (-1, 0), 6),
        ('BOTTOMPADDING', (0, 0), (-1, 0), 6),
        ('TOPPADDING', (0, 1), (-1, -1), 4),
        ('BOTTOMPADDING', (0, 1), (-1, -1), 4),
    ]

    # Group tests by department, preserving catalogue order within a group.
    grouped = {}
    for test in tests:
        grouped.setdefault((test.department or 'General').strip(), []).append(test)

    if not tests:
        rows.append([Paragraph('No tests recorded on this order.', st_note), '', '', '', ''])

    for department, dept_tests in grouped.items():
        dept_row = len(rows)
        rows.append([Paragraph(_esc(department.upper()), st_dept), '', '', '', ''])
        styles += [
            ('SPAN', (0, dept_row), (-1, dept_row)),
            ('BACKGROUND', (0, dept_row), (-1, dept_row), TINT),
            ('TOPPADDING', (0, dept_row), (-1, dept_row), 7),
            ('BOTTOMPADDING', (0, dept_row), (-1, dept_row), 3),
            ('LINEABOVE', (0, dept_row), (-1, dept_row), 0.6, BORDER),
        ]

        for test in dept_tests:
            result = _latest_result(test.id, results)
            cell_rows = _result_rows(test, result, st_cell, st_cell_b, st_cell_r, st_cell_m)
            is_panel = bool(result) and len(cell_rows) > 1

            if is_panel:
                name_row = len(rows)
                status_word = 'ABNORMAL' if result.is_abnormal else 'RESULTED'
                status_hex = (BAD if result.is_abnormal else GOOD).hexval()
                rows.append([
                    Paragraph(
                        f'{_esc(test.name)}'
                        + (f'  <font color="#64748B" size="7">({_esc(test.code)})</font>'
                           if test.code else '')
                        + f'  <font color="{status_hex}" size="6.6"><b>{status_word}</b></font>',
                        st_test_name,
                    ), '', '', '', '',
                ])
                styles += [
                    ('SPAN', (0, name_row), (-1, name_row)),
                    ('TOPPADDING', (0, name_row), (-1, name_row), 7),
                    ('BOTTOMPADDING', (0, name_row), (-1, name_row), 2),
                    ('LINEABOVE', (0, name_row), (-1, name_row), 0.5, BORDER),
                ]
                for label, value, unit, reference, flag in cell_rows:
                    row_index = len(rows)
                    rows.append([
                        Paragraph(_esc(label), st_cell),
                        Paragraph(f'<font color="{tone_color(value[2]).hexval()}">'
                                  f'<b>{_esc(value[0])}</b></font>', st_cell_r),
                        Paragraph(_esc(unit[0]), st_cell_m),
                        Paragraph(_esc(reference[0]), st_cell_m),
                        Paragraph(f'<font color="{tone_color(flag[2]).hexval()}">'
                                  f'<b>{_esc(flag[0] or "—")}</b></font>', st_cell),
                    ])
                    if flag[2] == 'bad':
                        styles.append(('BACKGROUND', (4, row_index), (4, row_index), BAD_BG))
            else:
                label, value, unit, reference, flag = cell_rows[0]
                row_index = len(rows)
                rows.append([
                    Paragraph(
                        f'{_esc(test.name)}'
                        + (f'  <font color="#64748B" size="7">({_esc(test.code)})</font>'
                           if test.code else ''),
                        st_test_name,
                    ),
                    Paragraph(f'<font color="{tone_color(value[2]).hexval()}">'
                              f'<b>{_esc(value[0])}</b></font>', st_cell_r),
                    Paragraph(_esc(unit[0]), st_cell_m),
                    Paragraph(_esc(reference[0]), st_cell_m),
                    Paragraph(f'<font color="{tone_color(flag[2]).hexval()}">'
                              f'<b>{_esc(flag[0] or "—")}</b></font>', st_cell),
                ])
                styles.append(('LINEABOVE', (0, row_index), (-1, row_index), 0.5, BORDER))
                if flag[2] == 'bad':
                    styles.append(('BACKGROUND', (4, row_index), (4, row_index), BAD_BG))

    results_tbl = Table(rows, colWidths=widths, repeatRows=1)
    results_tbl.setStyle(TableStyle(styles))
    story.append(results_tbl)

    # ── Specimens ───────────────────────────────────────────────────────────
    if specimens:
        story.append(Spacer(1, 7 * mm))
        story.append(KeepTogether([
            section_heading('SPECIMENS'),
            Spacer(1, 3 * mm),
            Table(
                [[
                    Paragraph('ACCESSION', st_hdr),
                    Paragraph('TYPE', st_hdr),
                    Paragraph('CONTAINER', st_hdr),
                    Paragraph('COLLECTED', st_hdr),
                    Paragraph('STATUS', st_hdr),
                ]] + [[
                    Paragraph(_esc(s.accession_number or '—'), st_cell_b),
                    Paragraph(_esc(s.specimen_type or '—'), st_cell),
                    Paragraph(_esc(s.container_type or '—'), st_cell),
                    Paragraph(_fmt_dt(s.collected_at), st_cell_m),
                    Paragraph(_esc((s.status or '').replace('_', ' ').title()), st_cell),
                ] for s in specimens],
                colWidths=[46 * mm, 42 * mm, 34 * mm, 38 * mm, 20 * mm],
                style=TableStyle([
                    ('BACKGROUND', (0, 0), (-1, 0), NAVY),
                    ('LINEBELOW', (0, 0), (-1, 0), 1, ACCENT),
                    ('LINEBELOW', (0, 1), (-1, -1), 0.4, BORDER),
                    ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                    ('LEFTPADDING', (0, 0), (-1, -1), 6),
                    ('RIGHTPADDING', (0, 0), (-1, -1), 6),
                    ('TOPPADDING', (0, 0), (-1, -1), 4.5),
                    ('BOTTOMPADDING', (0, 0), (-1, -1), 4.5),
                ]),
            ),
        ]))

    # ── Notes ───────────────────────────────────────────────────────────────
    notes = []
    if order.clinical_notes:
        notes.append(('CLINICAL NOTES', order.clinical_notes))
    if extra and getattr(extra, 'notes_for_lab', ''):
        notes.append(('NOTES FOR THE LABORATORY', extra.notes_for_lab))
    if notes:
        story.append(Spacer(1, 7 * mm))
        blocks = [section_heading('NOTES'), Spacer(1, 3 * mm)]
        for heading, text in notes:
            blocks.append(Paragraph(_esc(heading), st_label))
            blocks.append(Spacer(1, 1.2 * mm))
            blocks.append(Paragraph(_esc(text).replace('\n', '<br/>'), st_body))
            blocks.append(Spacer(1, 3 * mm))
        story.append(KeepTogether(blocks))

    # ── Sign-off ────────────────────────────────────────────────────────────
    # Prefer the signed authorisation record (it snapshots the signature that
    # was actually used); fall back to whoever was recorded on the results.
    authorization = getattr(order, 'authorization', None)
    performed = next((r.performed_by for r in results if r.performed_by), None)
    verified = next((r.verified_by for r in results if r.verified_by), None)
    template = None
    try:
        from .models import ReportTemplate
        template = (ReportTemplate.objects.filter(is_active=True, is_default=True).first()
                    or ReportTemplate.objects.filter(is_active=True).first())
    except Exception:
        template = None

    def _signature_flowable(field, width=40 * mm, height=15 * mm):
        """Inline the stored handwritten signature, or None when unsigned."""
        data = _signature_bytes(field)
        if not data:
            return None
        try:
            from reportlab.lib.utils import ImageReader

            intrinsic_w, intrinsic_h = ImageReader(BytesIO(data)).getSize()
            if not intrinsic_w or not intrinsic_h:
                return None
            scale = min(width / intrinsic_w, height / intrinsic_h)
            image = RLImage(
                BytesIO(data),
                width=intrinsic_w * scale,
                height=intrinsic_h * scale,
                lazy=0,
            )
            image.hAlign = 'LEFT'
            return image
        except Exception:
            return None

    sign_cells = []
    sign_specs = [
        (
            'PERFORMED BY',
            getattr(authorization, 'performed_by_name', '') or
            (getattr(performed, 'full_name', '') if performed else ''),
            getattr(authorization, 'performed_by_title', '') or 'Medical Laboratory Scientist',
            getattr(authorization, 'performed_signature', None) if authorization else None,
            getattr(authorization, 'performed_at', None),
            bool(authorization and authorization.performed_at),
            getattr(authorization, 'performed_identity', '') if authorization else '',
        ),
        (
            'VERIFIED BY',
            getattr(authorization, 'verified_by_name', '') or
            (getattr(verified, 'full_name', '') if verified else ''),
            (getattr(authorization, 'verified_by_title', '') or
             (getattr(template, 'signatory_title', '') if template else '')
             or 'Pathologist / Lab Supervisor'),
            getattr(authorization, 'verified_signature', None) if authorization else None,
            getattr(authorization, 'verified_at', None),
            bool(authorization and authorization.verified_at),
            getattr(authorization, 'verified_identity', '') if authorization else '',
        ),
    ]

    # How each signature was proved, so the closing statement is factual.
    identity_label = {
        'password': 'password re-entry',
        'session': 'own signed-in session',
    }
    identities = set()

    for title, name, role_title, signature_field, signed_at, is_signed, identity in sign_specs:
        if is_signed and identity:
            identities.add(identity)
        image = _signature_flowable(signature_field)
        block = [Paragraph(_esc(title), st_label)]
        if image is not None:
            # A real signature sits on (and slightly above) the rule.
            block += [Spacer(1, 1 * mm), image, Spacer(1, 1 * mm)]
        else:
            block += [Spacer(1, 8 * mm), Paragraph(
                _esc('Not signed' if not is_signed else 'Signature on file missing'),
                ParagraphStyle('nosig', parent=st_sign_role, fontSize=6.8, textColor=MUTED),
            ), Spacer(1, 1.5 * mm)]
        block += [
            HRFlowable(width=42 * mm, thickness=0.7, color=MUTED,
                       spaceBefore=0, spaceAfter=2 * mm),
            Paragraph(_esc(name or '—'), st_sign_name),
            Paragraph(_esc(role_title), st_sign_role),
        ]
        if signed_at:
            block.append(Paragraph(
                f'Signed {_fmt_dt(signed_at)}',
                ParagraphStyle('signedat', parent=st_sign_role, fontSize=6.8),
            ))
        if is_signed and identity:
            block.append(Paragraph(
                f'Identity proven by {identity_label.get(identity, identity)}',
                ParagraphStyle('identity', parent=st_sign_role, fontSize=6.4, textColor=MUTED),
            ))
        sign_cells.append(block)

    signature_block = []
    if template is not None:
        signature_block.append(Paragraph(_esc(template.signatory_name or ''), st_sign_name))
        signature_block.append(Paragraph(_esc(template.signatory_title or ''), st_sign_role))
    signature_block.append(Paragraph(
        _fmt_dt(order.updated_at), ParagraphStyle('stamp', parent=st_sign_role, fontSize=7)))
    if authorization is not None and getattr(authorization, 'is_complete', False):
        signature_block.insert(0, Paragraph(
            'AUTHORISED', ParagraphStyle('authorised', parent=st_label, textColor=GOOD)))
        signature_block.insert(1, Spacer(1, 1.2 * mm))
    signature_block.append(Spacer(1, 1.5 * mm))
    if not identities:
        esign_text = 'Not yet electronically signed.'
    elif identities == {'session'}:
        esign_text = 'Electronically signed by the account currently logged in to the bench.'
    elif identities == {'password'}:
        esign_text = 'Electronically signed. Each signer re-entered their account password.'
    else:
        esign_text = 'Electronically signed. Identity proven by account password or signed-in session.'
    signature_block.append(Paragraph(
        esign_text,
        ParagraphStyle('esign', parent=st_sign_role, fontSize=6.6, textColor=MUTED),
    ))

    sign_tbl = Table([[sign_cells[0], sign_cells[1], signature_block]],
                     colWidths=[60 * mm, 60 * mm, PAGE_W - 120 * mm])
    sign_tbl.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 0),
        ('RIGHTPADDING', (0, 0), (-1, -1), 0),
        ('TOPPADDING', (0, 0), (-1, -1), 0),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
    ]))

    # Framed panel so the sign-off reads as a deliberate closing block.
    auth_panel = Table([[[
        section_heading('AUTHORISATION'),
        Spacer(1, 5 * mm),
        sign_tbl,
    ]]], colWidths=[PAGE_W])
    auth_panel.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), SOFT),
        ('BOX', (0, 0), (-1, -1), 0.8, BORDER),
        ('LEFTPADDING', (0, 0), (-1, -1), 12),
        ('RIGHTPADDING', (0, 0), (-1, -1), 12),
        ('TOPPADDING', (0, 0), (-1, -1), 11),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 12),
    ]))

    story.append(Spacer(1, 2 * mm))
    story.append(KeepTogether([
        auth_panel,
        Spacer(1, 5 * mm),
        Paragraph(
            'This report contains confidential clinical information and is intended solely for '
            'the named patient and the requesting clinician. Reference ranges are those of the '
            'issuing laboratory and may differ between analysers and methods. Results should be '
            f'interpreted alongside the clinical picture. Report ID '
            f'LAB-{order.id:05d}-{order.updated_at.strftime("%Y%m%d") if order.updated_at else "00000000"}.',
            st_note,
        ),
    ]))

    # ── Page furniture ──────────────────────────────────────────────────────
    def draw_footer(canv, page_number, total_pages):
        canv.saveState()
        canv.setStrokeColor(BORDER)
        canv.setLineWidth(0.6)
        canv.line(15 * mm, 14 * mm, A4[0] - 15 * mm, 14 * mm)
        canv.setFont('Helvetica', 7)
        canv.setFillColor(SLATE)
        canv.drawString(15 * mm, 9.5 * mm, _strip_markup(business_name or 'Laboratory'))
        canv.drawCentredString(A4[0] / 2, 9.5 * mm, f'Page {page_number} of {total_pages}')
        canv.setFont('Helvetica-Bold', 7)
        canv.setFillColor(ACCENT)
        canv.drawRightString(A4[0] - 15 * mm, 9.5 * mm, 'Powered by AdhereMed')
        canv.restoreState()

    def draw_watermark(canv, doc_):
        if not preliminary:
            return
        canv.saveState()
        canv.setFillColor(Color(0.62, 0.70, 0.82, alpha=0.40))
        canv.setFont('Helvetica-Bold', 62)
        canv.translate(A4[0] / 2, A4[1] / 2)
        canv.rotate(38)
        canv.drawCentredString(0, 0, 'PRELIMINARY')
        canv.restoreState()

    buf = io.BytesIO()
    doc = SimpleDocTemplate(
        buf, pagesize=A4,
        leftMargin=15 * mm, rightMargin=15 * mm,
        topMargin=13 * mm, bottomMargin=20 * mm,
        title=f'Laboratory Report · Order {order.id:05d}',
        author=business_name or 'AdhereMed',
        subject=f'Laboratory results for {patient_name}',
    )
    doc.build(
        story,
        onFirstPage=draw_watermark,
        onLaterPages=draw_watermark,
        canvasmaker=lambda *a, **kw: _NumberedCanvas(*a, footer=draw_footer, **kw),
    )
    return buf.getvalue()


def _strip_markup(value):
    return re.sub(r'[&<>]', '', str(value or ''))


def _signature_bytes(field):
    """Pull a stored signature into memory.

    Signatures live on the configured default storage (local disk in dev, S3 in
    production), which has no filesystem path, so the bytes are read through the
    storage backend rather than relying on ``.path``.
    """
    if not field:
        return None
    try:
        field.open('rb')
        try:
            data = field.read()
        finally:
            field.close()
        return data or None
    except Exception:
        return None
