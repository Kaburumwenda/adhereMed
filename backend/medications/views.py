from django_filters.rest_framework import DjangoFilterBackend
from django.db.models import Q
from django.http import HttpResponse
from django.utils import timezone
from rest_framework import filters, generics, permissions, status, viewsets
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Medication, DrugInteraction
from .serializers import MedicationSerializer, MedicationSearchSerializer, DrugInteractionSerializer

import csv
import io


class MedicationListCreateView(generics.ListCreateAPIView):
    queryset = Medication.objects.all()
    serializer_class = MedicationSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['generic_name', 'brand_names', 'abbreviation', 'category', 'subcategory', 'strength']
    filterset_fields = ['category', 'dosage_form', 'requires_prescription', 'is_active']
    ordering_fields = ['generic_name', 'category', 'dosage_form', 'strength', 'created_at']
    ordering = ['generic_name']


class MedicationDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Medication.objects.all()
    serializer_class = MedicationSerializer


class MedicationSearchView(generics.ListAPIView):
    serializer_class = MedicationSearchSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = None

    def get_queryset(self):
        q = self.request.query_params.get('q', '')
        if len(q) < 2:
            return Medication.objects.none()
        return Medication.objects.filter(
            Q(generic_name__icontains=q) |
            Q(abbreviation__icontains=q) |
            Q(brand_names__icontains=q),
            is_active=True,
        )[:30]


ALLOWED_DELETE_ALL_ROLES = {"tenant_admin", "branch_admin", "pharmacist", "admin"}


@api_view(["DELETE"])
@permission_classes([permissions.IsAuthenticated])
def delete_all_medications(request):
    """Delete ALL medications in the current tenant schema."""
    if request.user.role not in ALLOWED_DELETE_ALL_ROLES:
        return Response(
            {"detail": "You do not have permission to delete the catalog."},
            status=status.HTTP_403_FORBIDDEN,
        )
    count, _ = Medication.objects.all().delete()
    return Response({"detail": f"Deleted {count} medications.", "count": count})


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def bulk_update_medications(request):
    """Batch-update multiple Medication records.

    Payload: { "items": [ { "id": 1, "generic_name": "...", ... }, ... ] }
    Only the supplied fields are updated.
    """
    if request.user.role not in ALLOWED_DELETE_ALL_ROLES:
        return Response(
            {"detail": "You do not have permission to bulk-edit medications."},
            status=status.HTTP_403_FORBIDDEN,
        )
    items = request.data.get("items") or []
    if not isinstance(items, list) or not items:
        return Response(
            {"detail": "Expected non-empty 'items' list."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    allowed_fields = {
        "generic_name", "abbreviation", "brand_names", "category", "subcategory",
        "dosage_form", "strength", "unit", "description", "requires_prescription",
        "controlled_substance_class", "side_effects", "contraindications",
        "interactions", "is_active",
    }

    updated = 0
    errors = []
    for idx, item in enumerate(items):
        med_id = item.get("id")
        if not med_id:
            errors.append({"index": idx, "detail": "Missing id"})
            continue
        try:
            med = Medication.objects.get(pk=med_id)
        except Medication.DoesNotExist:
            errors.append({"index": idx, "id": med_id, "detail": "Not found"})
            continue
        changed = False
        for field, value in item.items():
            if field == "id":
                continue
            if field not in allowed_fields:
                continue
            if getattr(med, field) != value:
                setattr(med, field, value)
                changed = True
        if changed:
            med.save()
            updated += 1

    return Response({"updated": updated, "errors": errors})


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def bulk_delete_medications(request):
    """Batch-delete multiple Medication records by id.

    Payload: { "ids": [1, 2, 3, ...] }
    """
    if request.user.role not in ALLOWED_DELETE_ALL_ROLES:
        return Response(
            {"detail": "You do not have permission to bulk-delete medications."},
            status=status.HTTP_403_FORBIDDEN,
        )
    ids = request.data.get("ids") or []
    if not isinstance(ids, list) or not ids:
        return Response(
            {"detail": "Expected non-empty 'ids' list."},
            status=status.HTTP_400_BAD_REQUEST,
        )
    qs = Medication.objects.filter(id__in=ids)
    count, _ = qs.delete()
    return Response({"deleted": count})


# ── Excel import/export ──────────────────────────────────────────────────────

_MED_EXPORT_HEADERS = [
    'ID', 'Generic Name', 'Abbreviation', 'Brand Names',
    'Category', 'Subcategory', 'Dosage Form', 'Strength', 'Unit',
    'Requires Prescription', 'Controlled Substance Class',
    'Description', 'Side Effects', 'Contraindications',
    'Is Active', 'Created At',
]

_MED_IMPORT_COLUMNS = {
    'generic_name': ['Generic Name', 'generic_name', 'name'],
    'abbreviation': ['Abbreviation', 'abbreviation', 'abbr'],
    'brand_names': ['Brand Names', 'brand_names'],
    'category': ['Category', 'category'],
    'subcategory': ['Subcategory', 'sub_category', 'subcategory'],
    'dosage_form': ['Dosage Form', 'dosage_form'],
    'strength': ['Strength', 'strength'],
    'unit': ['Unit', 'unit'],
    'requires_prescription': ['Requires Prescription', 'requires_prescription', 'Rx'],
    'controlled_substance_class': ['Controlled Substance Class', 'controlled_substance_class'],
    'description': ['Description', 'description'],
    'side_effects': ['Side Effects', 'side_effects'],
    'contraindications': ['Contraindications', 'contraindications'],
    'is_active': ['Is Active', 'is_active', 'active'],
}


def _med_export_row(m):
    return [
        m.id, m.generic_name, m.abbreviation or '',
        '; '.join(m.brand_names) if m.brand_names else '',
        m.category or '', m.subcategory or '',
        m.dosage_form or '', m.strength or '', m.unit or '',
        'Yes' if m.requires_prescription else 'No',
        m.controlled_substance_class or '',
        m.description or '', m.side_effects or '', m.contraindications or '',
        'Yes' if m.is_active else 'No',
        m.created_at.strftime('%Y-%m-%d') if m.created_at else '',
    ]


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def export_medications(request):
    """Export all medications as Excel (.xlsx) or CSV."""
    fmt = request.query_params.get('fmt', 'csv').lower()
    qs = Medication.objects.all()

    if fmt == 'excel':
        try:
            from openpyxl import Workbook
            from openpyxl.styles import Font, PatternFill, Alignment
        except ImportError:
            return Response({'detail': 'openpyxl not installed.'}, status=500)

        wb = Workbook()
        ws = wb.active
        ws.title = 'Medications'

        header_font = Font(bold=True, color='FFFFFF')
        header_fill = PatternFill(fill_type='solid', fgColor='0D9488')
        for col_idx, header in enumerate(_MED_EXPORT_HEADERS, 1):
            cell = ws.cell(row=1, column=col_idx, value=header)
            cell.font = header_font
            cell.fill = header_fill
            cell.alignment = Alignment(horizontal='center')

        for row_idx, m in enumerate(qs, 2):
            for col_idx, val in enumerate(_med_export_row(m), 1):
                ws.cell(row=row_idx, column=col_idx, value=val)

        for col in ws.columns:
            max_len = max((len(str(c.value or '')) for c in col), default=8)
            ws.column_dimensions[col[0].column_letter].width = min(max_len + 4, 40)

        buf = io.BytesIO()
        wb.save(buf)
        buf.seek(0)
        fname = f'medications_{timezone.now():%Y%m%d}.xlsx'
        return HttpResponse(
            buf.read(),
            content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            headers={'Content-Disposition': f'attachment; filename="{fname}"'},
        )

    # Default: CSV
    fname = f'medications_{timezone.now():%Y%m%d}.csv'
    resp = HttpResponse(content_type='text/csv')
    resp['Content-Disposition'] = f'attachment; filename="{fname}"'
    writer = csv.writer(resp)
    writer.writerow(_MED_EXPORT_HEADERS)
    for m in qs:
        writer.writerow(_med_export_row(m))
    return resp


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def import_template(request):
    """Download a styled .xlsx import template with example row and dropdowns."""
    try:
        from openpyxl import Workbook
        from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
        from openpyxl.worksheet.datavalidation import DataValidation
        from openpyxl.utils import get_column_letter
    except ImportError:
        return Response({'detail': 'openpyxl not installed.'}, status=500)

    HEADERS = [
        ('Generic Name', 32, 'required'),
        ('Abbreviation', 16, 'short code e.g. PCM'),
        ('Brand Names', 40, 'semicolon-separated'),
        ('Category', 22, 'e.g. analgesic'),
        ('Subcategory', 20, ''),
        ('Dosage Form', 18, 'tablet / syrup / injection…'),
        ('Strength', 16, 'e.g. 500mg'),
        ('Unit', 14, 'tab, ml, vial…'),
        ('Requires Prescription', 22, 'Yes / No'),
        ('Controlled Substance Class', 24, 'e.g. Schedule II'),
        ('Description', 40, ''),
        ('Side Effects', 40, ''),
        ('Contraindications', 40, ''),
        ('Is Active', 12, 'Yes / No'),
    ]
    EXAMPLE = [
        'Paracetamol', 'PCM', 'Panadol; Calpol; Hedex',
        'analgesic', '', 'tablet', '500mg', 'tab',
        'No', '', 'Relieves pain and fever',
        'Nausea, rash (rare)', 'Liver disease',
        'Yes',
    ]

    wb = Workbook()
    ws = wb.active
    ws.title = 'Medications'

    header_font = Font(bold=True, color='FFFFFF', size=11)
    header_fill = PatternFill(fill_type='solid', fgColor='0D9488')
    thin = Side(style='thin', color='E2E8F0')
    border = Border(left=thin, right=thin, top=thin, bottom=thin)

    for c, (title, width, _) in enumerate(HEADERS, 1):
        cell = ws.cell(row=1, column=c, value=title)
        cell.font = header_font
        cell.fill = header_fill
        cell.alignment = Alignment(horizontal='center', vertical='center')
        cell.border = border
        ws.column_dimensions[get_column_letter(c)].width = width
    ws.row_dimensions[1].height = 24
    ws.freeze_panes = 'A2'

    for c, val in enumerate(EXAMPLE, 1):
        cell = ws.cell(row=2, column=c, value=val)
        cell.font = Font(italic=True, color='64748B')
        cell.border = border

    # Category dropdown
    cat_list = ','.join(dict(Medication.Category.choices).keys())
    if len(cat_list) <= 250:
        dv_cat = DataValidation(type='list', formula1=f'"{cat_list}"',
                                allow_blank=True, showDropDown=False)
        ws.add_data_validation(dv_cat)
        dv_cat.add('D3:D1000')

    # Dosage form dropdown
    form_list = ','.join(dict(Medication.DosageForm.choices).keys())
    if len(form_list) <= 250:
        dv_form = DataValidation(type='list', formula1=f'"{form_list}"',
                                 allow_blank=True, showDropDown=False)
        ws.add_data_validation(dv_form)
        dv_form.add('F3:F1000')

    # Yes/No dropdowns
    for col_letter in ('I', 'N'):
        dv_yn = DataValidation(type='list', formula1='"Yes,No"',
                               allow_blank=True, showDropDown=False)
        ws.add_data_validation(dv_yn)
        dv_yn.add(f'{col_letter}3:{col_letter}1000')

    # Instructions sheet
    ins = wb.create_sheet('Instructions')
    ins.column_dimensions['A'].width = 6
    ins.column_dimensions['B'].width = 96
    title_cell = ins.cell(row=1, column=2, value='AdhereMed · Medication Catalog Excel Import')
    title_cell.font = Font(bold=True, size=14, color='0F172A')
    lines = [
        '',
        'HOW TO USE',
        '1. Fill one row per medication in the "Medications" sheet (or edit an exported file).',
        '2. "Generic Name" is required — rows without a name are skipped.',
        '3. "Brand Names" — use semicolons to separate multiple brands (e.g. Panadol; Calpol; Hedex).',
        '4. Existing medications are matched by generic_name (case-insensitive).',
        '5. Blank optional cells keep existing values on update; defaults apply to new items.',
        '6. Category: analgesic, antibiotic, antifungal, antiviral, antiparasitic, antimalarial,',
        '   antihypertensive, antidiabetic, antihistamine, antacid, cardiovascular, respiratory,',
        '   cns, hormone, vitamin, vaccine, dermatological, ophthalmic, oncology,',
        '   immunosuppressant, nsaid, other.',
        '7. Dosage Form: tablet, capsule, syrup, injection, cream, ointment, drops, inhaler,',
        '   suppository, suspension, powder, gel, patch, lozenge, spray, solution, other.',
        '8. "Requires Prescription" and "Is Active" must be Yes or No.',
        '9. Supported formats: .xlsx and .csv',
        '',
        'REVIEW WORKFLOW',
        '· Upload the file on the Excel Import / Export page.',
        '· Every row is checked and shown in a review table where you can edit or remove rows.',
        '· Only when you press "Submit import" is anything saved.',
    ]
    for i, line in enumerate(lines, 3):
        cell = ins.cell(row=i, column=2, value=line)
        if line.isupper():
            cell.font = Font(bold=True, size=11, color='0D9488')
        else:
            cell.font = Font(size=10, color='334155')

    buf = io.BytesIO()
    wb.save(buf)
    buf.seek(0)
    fname = f'medications_import_template_{timezone.now():%Y%m%d}.xlsx'
    return HttpResponse(
        buf.read(),
        content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        headers={'Content-Disposition': f'attachment; filename="{fname}"'},
    )


def _med_normalize_import_rows(uploaded):
    """Parse an uploaded .xlsx/.csv into (row_num, {field: raw_value}) pairs."""
    filename = (uploaded.name or '').lower()
    if filename.endswith('.csv'):
        text = uploaded.read().decode('utf-8-sig')
        rows = [r for r in csv.reader(io.StringIO(text))]
    elif filename.endswith('.xlsx'):
        try:
            from openpyxl import load_workbook
            wb = load_workbook(io.BytesIO(uploaded.read()), read_only=True, data_only=True)
            ws = wb.active
            rows = [list(r) for r in ws.iter_rows(values_only=True)]
        except Exception:
            raise ValueError('Could not read the spreadsheet. Save it as .xlsx or .csv and try again.')
    else:
        raise ValueError('Unsupported file type. Use .xlsx or .csv')

    if not rows:
        raise ValueError('The file is empty.')

    headers = [str(h).strip() if h is not None else '' for h in rows[0]]
    col = {h: i for i, h in enumerate(headers)}
    if 'Generic Name' not in col and 'generic_name' not in col and 'name' not in col:
        raise ValueError('Missing the "Generic Name" column. Use the import template.')

    def get(row, aliases):
        for a in aliases:
            idx = col.get(a)
            if idx is not None and idx < len(row):
                v = row[idx]
                if v is not None and str(v).strip() != '':
                    return v
        return None

    parsed = []
    for num, row in enumerate(rows[1:], 2):
        if not row or all(v is None or str(v).strip() == '' for v in row):
            continue
        parsed.append((num, {f: get(row, aliases)
                             for f, aliases in _MED_IMPORT_COLUMNS.items()}))
    return parsed


def _med_clean_row(raw):
    """Validate one raw import row. Returns (cleaned, errors)."""
    cleaned, errors = {}, {}
    name = str(raw.get('generic_name') or '').strip()
    if not name:
        errors['generic_name'] = 'Required'
    cleaned['generic_name'] = name

    for f in ('abbreviation', 'subcategory', 'controlled_substance_class',
              'description', 'side_effects', 'contraindications'):
        v = raw.get(f)
        cleaned[f] = str(v).strip() if v not in (None, '') else None

    # Brand names: split on semicolons
    brands_raw = raw.get('brand_names')
    if brands_raw and str(brands_raw).strip():
        brands = [b.strip() for b in str(brands_raw).split(';') if b.strip()]
        cleaned['brand_names'] = brands
    else:
        cleaned['brand_names'] = []

    # Category
    cat = str(raw.get('category') or '').strip().lower()
    valid_cats = {c for c, _ in Medication.Category.choices}
    if cat and cat not in valid_cats:
        errors['category'] = f'Must be one of: {", ".join(sorted(valid_cats))}'
    cleaned['category'] = cat or 'other'

    # Dosage form
    form = str(raw.get('dosage_form') or '').strip().lower()
    valid_forms = {f for f, _ in Medication.DosageForm.choices}
    if form and form not in valid_forms:
        errors['dosage_form'] = f'Must be one of: {", ".join(sorted(valid_forms))}'
    cleaned['dosage_form'] = form or 'tablet'

    cleaned['strength'] = str(raw.get('strength') or '').strip() or ''
    cleaned['unit'] = str(raw.get('unit') or '').strip() or ''

    # Yes/No fields
    rx_raw = raw.get('requires_prescription')
    if rx_raw in (None, ''):
        cleaned['requires_prescription'] = None
    else:
        s = str(rx_raw).strip().lower()
        if s in ('yes', 'true', '1', 'no', 'false', '0'):
            cleaned['requires_prescription'] = 'Yes' if s in ('yes', 'true', '1') else 'No'
        else:
            cleaned['requires_prescription'] = str(rx_raw)
            errors['requires_prescription'] = 'Must be Yes or No'

    act_raw = raw.get('is_active')
    if act_raw in (None, ''):
        cleaned['is_active'] = None
    else:
        s = str(act_raw).strip().lower()
        if s in ('yes', 'true', '1', 'no', 'false', '0'):
            cleaned['is_active'] = 'Yes' if s in ('yes', 'true', '1') else 'No'
        else:
            cleaned['is_active'] = str(act_raw)
            errors['is_active'] = 'Must be Yes or No'

    return cleaned, errors


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def import_preview(request):
    """Parse an uploaded spreadsheet and return rows for review."""
    if request.user.role not in ALLOWED_DELETE_ALL_ROLES:
        return Response(
            {"detail": "You do not have permission to import medications."},
            status=status.HTTP_403_FORBIDDEN,
        )
    uploaded = request.FILES.get('file')
    if not uploaded:
        return Response({'detail': 'No file provided.'}, status=400)
    try:
        parsed = _med_normalize_import_rows(uploaded)
    except ValueError as exc:
        return Response({'detail': str(exc)}, status=400)

    existing = {m.generic_name.lower(): m.id for m in Medication.objects.only('id', 'generic_name')}

    rows, seen = [], {}
    counts = {'new': 0, 'update': 0, 'error': 0}
    for num, raw in parsed:
        cleaned, errors = _med_clean_row(raw)
        key = cleaned['generic_name'].lower() if cleaned['generic_name'] else None
        if key and key in seen:
            errors['generic_name'] = f'Duplicate of row {seen[key]}'
        elif key:
            seen[key] = num
        ex_id = existing.get(key) if key else None
        row_status = 'error' if errors else ('update' if ex_id else 'new')
        counts[row_status] += 1
        rows.append({
            'row_num': num,
            **cleaned,
            'is_active': cleaned['is_active'] or ('Yes' if row_status == 'new' else None),
            'requires_prescription': cleaned['requires_prescription'] or ('Yes' if row_status == 'new' else None),
            'status': row_status,
            'existing_id': ex_id,
            'errors': errors,
        })
    return Response({
        'rows': rows,
        'summary': {
            'total': len(rows),
            'new': counts['new'],
            'update': counts['update'],
            'error': counts['error'],
        },
    })


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def import_commit(request):
    """Apply reviewed (and possibly edited) import rows."""
    if request.user.role not in ALLOWED_DELETE_ALL_ROLES:
        return Response(
            {"detail": "You do not have permission to import medications."},
            status=status.HTTP_403_FORBIDDEN,
        )
    items = request.data.get('items')
    if not isinstance(items, list) or not items:
        return Response({'detail': 'items must be a non-empty list.'}, status=400)

    created = updated = failed = 0
    results = []
    for idx, item in enumerate(items, 1):
        row_label = item.get('row_num') or idx
        name = str(item.get('generic_name') or '').strip()
        try:
            if not name:
                raise ValueError('Generic name is required')

            med = Medication.objects.filter(generic_name__iexact=name).first()
            is_new = med is None
            if is_new:
                med = Medication(generic_name=name)

            # Only update supplied fields
            if item.get('abbreviation') is not None:
                med.abbreviation = str(item['abbreviation']).strip()
            if item.get('brand_names'):
                brands = item['brand_names']
                if isinstance(brands, str):
                    brands = [b.strip() for b in brands.split(';') if b.strip()]
                med.brand_names = brands
            if item.get('category'):
                med.category = str(item['category']).strip().lower()
            if item.get('subcategory') is not None:
                med.subcategory = str(item['subcategory']).strip()
            if item.get('dosage_form'):
                med.dosage_form = str(item['dosage_form']).strip().lower()
            if item.get('strength') is not None:
                med.strength = str(item['strength']).strip()
            if item.get('unit') is not None:
                med.unit = str(item['unit']).strip()
            if item.get('controlled_substance_class') is not None:
                med.controlled_substance_class = str(item['controlled_substance_class']).strip()
            if item.get('description') is not None:
                med.description = str(item['description']).strip()
            if item.get('side_effects') is not None:
                med.side_effects = str(item['side_effects']).strip()
            if item.get('contraindications') is not None:
                med.contraindications = str(item['contraindications']).strip()

            rx = item.get('requires_prescription')
            if rx is not None and rx != '':
                if isinstance(rx, str):
                    med.requires_prescription = rx.strip().lower() in ('yes', 'true', '1')
                else:
                    med.requires_prescription = bool(rx)

            act = item.get('is_active')
            if act is not None and act != '':
                if isinstance(act, str):
                    med.is_active = act.strip().lower() in ('yes', 'true', '1')
                else:
                    med.is_active = bool(act)

            med.save()

            if is_new:
                created += 1
            else:
                updated += 1
            results.append({'row': row_label, 'name': name,
                            'status': 'created' if is_new else 'updated'})
        except Exception as exc:
            failed += 1
            msg = getattr(exc, 'message', '') or str(exc)
            results.append({'row': row_label, 'name': name or '(no name)',
                            'status': 'error', 'error': msg})

    return Response({'created': created, 'updated': updated,
                     'failed': failed, 'results': results})


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def brand_names_catalog(request):
    """Return the full built-in brand-name dictionary grouped by generic name.

    Also reports which medications currently have brand_names set and which
    are missing, so the frontend can show a coverage summary.
    """
    from medications.management.commands.seed_medications import BRAND_NAMES

    # Build the catalog: list of {generic_name, brands[], med_id|None, current_brands[]}
    med_map = {}
    for m in Medication.objects.only('id', 'generic_name', 'brand_names'):
        med_map[m.generic_name.lower()] = m

    catalog = []
    matched = 0
    unmatched = 0
    for key, brands in sorted(BRAND_NAMES.items()):
        med = med_map.get(key)
        if med:
            matched += 1
            catalog.append({
                'key': key,
                'brands': brands,
                'med_id': med.id,
                'med_generic_name': med.generic_name,
                'current_brands': med.brand_names or [],
                'has_brands': bool(med.brand_names),
            })
        else:
            unmatched += 1
            catalog.append({
                'key': key,
                'brands': brands,
                'med_id': None,
                'med_generic_name': None,
                'current_brands': [],
                'has_brands': False,
            })

    # Count medications that already have brand names set
    total_meds = Medication.objects.count()
    meds_with_brands = Medication.objects.exclude(brand_names=[]).count()

    return Response({
        'catalog': catalog,
        'summary': {
            'total_generics_in_dict': len(BRAND_NAMES),
            'matched_to_medications': matched,
            'unmatched': unmatched,
            'total_medications': total_meds,
            'meds_with_brands': meds_with_brands,
            'meds_without_brands': total_meds - meds_with_brands,
            'total_brand_entries': sum(len(v) for v in BRAND_NAMES.values()),
        },
    })


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def seed_all_brand_names(request):
    """Seed ALL brand names from the dictionary into every matching medication.

    Unlike update_brand_names which only fills empty ones by default, this
    endpoint force-overwrites brand_names on all matched medications.
    """
    if request.user.role not in ALLOWED_DELETE_ALL_ROLES:
        return Response(
            {"detail": "You do not have permission to seed brand names."},
            status=status.HTTP_403_FORBIDDEN,
        )

    from medications.management.commands.seed_medications import _get_brand_names

    qs = Medication.objects.all()
    updated = 0
    unmatched = 0
    changes = []

    for med in qs.iterator():
        lookup_name = med.generic_name or med.name or ''
        if not lookup_name:
            unmatched += 1
            continue
        detected = _get_brand_names(lookup_name)
        if not detected:
            alt = f"{med.product_code or ''} {med.abbreviation or ''}".strip()
            if alt:
                detected = _get_brand_names(alt)
        if not detected:
            unmatched += 1
            continue

        current_lower = {b.lower() for b in (med.brand_names or [])}
        detected_lower = {b.lower() for b in detected}

        if detected_lower == current_lower:
            continue  # already up to date

        med.brand_names = detected
        med.save(update_fields=['brand_names'])
        updated += 1
        if len(changes) < 200:
            changes.append({
                'id': med.id,
                'name': med.generic_name,
                'brands': detected,
            })

    return Response({
        'updated': updated,
        'unmatched': unmatched,
        'total': qs.count(),
        'changes': changes,
    })


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def expand_brands_to_catalog(request):
    """Expand brand names for a given generic into separate Medication records.

    For each brand of the generic, build a list of variant rows (brand x strength x dosage form).

    Phase 1 (no `variants` in body):  Return suggested default variants using a built-in
    strength/form per generic.  The user edits these on the frontend and submits back.

    Phase 2 (`variants` in body):  Accept the user-edited list and create Medication records.
    Each variant: { brand, strength, dosage_form, unit }

    medication.generic_name stays as the generic (e.g. "paracetamol").
    A separate display name "Brand strength" is NOT a model field — we store brand in brand_names
    and strength in the strength field.

    Returns:
        Phase 1 preview:
        {
            "generic_name": "paracetamol",
            "category": "analgesic",
            "brands": ["Panadol", ...],
            "suggested_strengths": ["500mg", "120mg/5ml", ...],
            "suggested_forms": ["tablet", "suspension", ...],
            "variants": [{"brand": "Panadol", "strength": "500mg", "dosage_form": "tablet", "unit": ""}, ...],
        }
        Phase 2 create:
        {
            "created": 6,
            "errors": [],
            "created_items": [{"generic_name": "paracetamol", "brand": "Panadol", "strength": "500mg", ...}]
        }
    """
    if request.user.role not in ALLOWED_DELETE_ALL_ROLES:
        return Response(
            {"detail": "You do not have permission to expand brand names."},
            status=status.HTTP_403_FORBIDDEN,
        )

    from medications.management.commands.seed_medications import (
        BRAND_NAMES, SIDE_EFFECTS, CONTRAINDICATIONS,
    )

    generic = (request.data.get('generic_name') or '').strip().lower()

    if not generic:
        return Response(
            {"detail": "generic_name is required."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    brands = BRAND_NAMES.get(generic)
    if not brands:
        return Response(
            {"detail": f"No brand names found for '{generic}' in the dictionary."},
            status=status.HTTP_404_NOT_FOUND,
        )

    # ── Inferred category lookup ──
    CAT_MAP = {
        'paracetamol': 'analgesic', 'ibuprofen': 'nsaid', 'aspirin': 'analgesic',
        'diclofenac': 'nsaid', 'naproxen': 'nsaid', 'mefenamic acid': 'nsaid',
        'tramadol': 'cns', 'codeine': 'cns', 'morphine': 'cns', 'fentanyl': 'cns',
        'amoxicillin': 'antibiotic', 'ampicillin': 'antibiotic', 'cloxacillin': 'antibiotic',
        'metformin': 'antidiabetic', 'insulin': 'antidiabetic',
        'omeprazole': 'antacid', 'cetirizine': 'antihistamine',
        'artemether': 'antimalarial', 'lumefantrine': 'antimalarial',
        'sulfamethoxazole/trimethoprim': 'antibiotic',
    }
    category = CAT_MAP.get(generic, 'other')

    # ── Default strengths/forms per common generic ──
    DEFAULT_VARIANTS = {
        'paracetamol': [
            {'strength': '500mg', 'dosage_form': 'tablet', 'unit': ''},
            {'strength': '120mg/5ml', 'dosage_form': 'suspension', 'unit': 'bottle'},
            {'strength': '125mg', 'dosage_form': 'suppository', 'unit': ''},
            {'strength': '1000mg/100ml', 'dosage_form': 'injection', 'unit': 'vial'},
        ],
        'ibuprofen': [
            {'strength': '200mg', 'dosage_form': 'tablet', 'unit': ''},
            {'strength': '400mg', 'dosage_form': 'tablet', 'unit': ''},
            {'strength': '100mg/5ml', 'dosage_form': 'suspension', 'unit': 'bottle'},
        ],
        'amoxicillin': [
            {'strength': '250mg', 'dosage_form': 'capsule', 'unit': ''},
            {'strength': '500mg', 'dosage_form': 'capsule', 'unit': ''},
            {'strength': '125mg/5ml', 'dosage_form': 'suspension', 'unit': 'bottle'},
            {'strength': '250mg/5ml', 'dosage_form': 'suspension', 'unit': 'bottle'},
        ],
        'diclofenac': [
            {'strength': '50mg', 'dosage_form': 'tablet', 'unit': ''},
            {'strength': '75mg/3ml', 'dosage_form': 'injection', 'unit': 'ampoule'},
            {'strength': '1%', 'dosage_form': 'gel', 'unit': 'tube'},
        ],
        'metformin': [
            {'strength': '500mg', 'dosage_form': 'tablet', 'unit': ''},
            {'strength': '850mg', 'dosage_form': 'tablet', 'unit': ''},
            {'strength': '1000mg', 'dosage_form': 'tablet', 'unit': ''},
        ],
        'omeprazole': [
            {'strength': '20mg', 'dosage_form': 'capsule', 'unit': ''},
            {'strength': '40mg', 'dosage_form': 'capsule', 'unit': ''},
        ],
        'cetirizine': [
            {'strength': '10mg', 'dosage_form': 'tablet', 'unit': ''},
            {'strength': '5mg/5ml', 'dosage_form': 'syrup', 'unit': 'bottle'},
        ],
        'amoxicillin/clavulanic': [
            {'strength': '625mg', 'dosage_form': 'tablet', 'unit': ''},
            {'strength': '1g', 'dosage_form': 'tablet', 'unit': ''},
            {'strength': '228.5mg/5ml', 'dosage_form': 'suspension', 'unit': 'bottle'},
        ],
    }
    defaults = DEFAULT_VARIANTS.get(generic, [{'strength': '', 'dosage_form': 'tablet', 'unit': ''}])

    # ── Phase 2: User submitted edited variants to create ──
    submitted_variants = request.data.get('variants')
    if submitted_variants is not None:
        # Create medication records from submitted variants
        to_create = []
        errors = []
        created_items = []

        side_effects = SIDE_EFFECTS.get(category, '')
        contraindications = CONTRAINDICATIONS.get(category, '')

        for i, v in enumerate(submitted_variants):
            brand = (v.get('brand') or '').strip()
            strength = (v.get('strength') or '').strip()
            dosage_form = (v.get('dosage_form') or '').strip() or 'other'
            unit = (v.get('unit') or '').strip()

            if not brand:
                errors.append({'index': i, 'error': 'brand is required'})
                continue

            # medication name: "Brand strength" e.g. "Panadol 500mg"
            if strength:
                med_name = f"{brand} {strength}"
            else:
                med_name = brand
            med_name = med_name[:255]

            # Validate choices
            cat = category if category in dict(Medication.Category.choices) else 'other'
            df = dosage_form if dosage_form in dict(Medication.DosageForm.choices) else 'other'

            requires_rx = cat in (
                'oncology', 'immunosuppressant', 'cns', 'cardiovascular',
                'hormone', 'antibiotic', 'antiviral', 'antifungal', 'vaccine',
            )

            to_create.append(Medication(
                generic_name=generic,          # keep generic name on its own field
                product_code='',
                category=cat,
                dosage_form=df,
                strength=strength,
                unit=unit,
                brand_names=[brand],
                requires_prescription=requires_rx,
                side_effects=side_effects,
                contraindications=contraindications,
                description=f"Expanded from brand names dictionary: {brand} ({generic})",
                is_active=True,
            ))
            created_items.append({
                'generic_name': generic,
                'brand': brand,
                'strength': strength,
                'dosage_form': df,
                'unit': unit,
                'name': med_name,
            })

        created_count = 0
        if to_create:
            Medication.objects.bulk_create(to_create)
            created_count = len(to_create)

        return Response({
            'created': created_count,
            'errors': errors,
            'created_items': created_items,
        })

    # ── Phase 1: Return suggested variants for the user to edit ──
    # Build brand x default_strength matrix
    variants = []
    for brand in brands:
        for d in defaults:
            variants.append({
                'brand': brand,
                'strength': d['strength'],
                'dosage_form': d['dosage_form'],
                'unit': d.get('unit', ''),
                'selected': True,
            })

    # Collect all dosage form choices for the frontend dropdown
    form_choices = [{'value': c[0], 'label': c[1]} for c in Medication.DosageForm.choices]

    return Response({
        'generic_name': generic,
        'category': category,
        'brands': brands,
        'variants': variants,
        'form_choices': form_choices,
    })


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def expand_all_to_catalog(request):
    """Expand ALL brand names in the dictionary into Medication catalog entries.

    For every generic in BRAND_NAMES, generates brand x strength x dosage form
    variants using built-in defaults, and creates all of them in bulk.
    Skips brand+strength combos that already exist as medications.

    Body:
        {
            "dry_run": false,  // optional, default false
            "generics": ["paracetamol", "ibuprofen", ...]  // optional, omit for all
        }

    Returns:
        {
            "total_generics": 350,
            "total_variants": 1200,
            "created": 1100,
            "skipped": 100,
            "dry_run": false,
            "per_generic": [{"generic": "paracetamol", "created": 24, "skipped": 0}, ...]
        }
    """
    if request.user.role not in ALLOWED_DELETE_ALL_ROLES:
        return Response(
            {"detail": "You do not have permission to expand brands to catalog."},
            status=status.HTTP_403_FORBIDDEN,
        )

    from medications.management.commands.seed_medications import (
        BRAND_NAMES, SIDE_EFFECTS, CONTRAINDICATIONS,
    )

    dry_run = bool(request.data.get('dry_run', False))

    # Optionally limit to a subset of generics
    requested_generics = request.data.get('generics')
    if requested_generics and isinstance(requested_generics, list):
        requested_set = {g.strip().lower() for g in requested_generics if g.strip()}
    else:
        requested_set = None

    CAT_MAP = {
        'paracetamol': 'analgesic', 'ibuprofen': 'nsaid', 'aspirin': 'analgesic',
        'diclofenac': 'nsaid', 'naproxen': 'nsaid', 'mefenamic acid': 'nsaid',
        'tramadol': 'cns', 'codeine': 'cns', 'morphine': 'cns', 'fentanyl': 'cns',
        'amoxicillin': 'antibiotic', 'ampicillin': 'antibiotic', 'cloxacillin': 'antibiotic',
        'metformin': 'antidiabetic', 'insulin': 'antidiabetic',
        'omeprazole': 'antacid', 'cetirizine': 'antihistamine',
        'artemether': 'antimalarial', 'lumefantrine': 'antimalarial',
        'sulfamethoxazole/trimethoprim': 'antibiotic',
    }
    DEFAULT_VARIANTS = {
        'paracetamol': [
            {'strength': '500mg', 'dosage_form': 'tablet', 'unit': ''},
            {'strength': '120mg/5ml', 'dosage_form': 'suspension', 'unit': 'bottle'},
            {'strength': '125mg', 'dosage_form': 'suppository', 'unit': ''},
            {'strength': '1000mg/100ml', 'dosage_form': 'injection', 'unit': 'vial'},
        ],
        'ibuprofen': [
            {'strength': '200mg', 'dosage_form': 'tablet', 'unit': ''},
            {'strength': '400mg', 'dosage_form': 'tablet', 'unit': ''},
            {'strength': '100mg/5ml', 'dosage_form': 'suspension', 'unit': 'bottle'},
        ],
        'amoxicillin': [
            {'strength': '250mg', 'dosage_form': 'capsule', 'unit': ''},
            {'strength': '500mg', 'dosage_form': 'capsule', 'unit': ''},
            {'strength': '125mg/5ml', 'dosage_form': 'suspension', 'unit': 'bottle'},
            {'strength': '250mg/5ml', 'dosage_form': 'suspension', 'unit': 'bottle'},
        ],
        'diclofenac': [
            {'strength': '50mg', 'dosage_form': 'tablet', 'unit': ''},
            {'strength': '75mg/3ml', 'dosage_form': 'injection', 'unit': 'ampoule'},
            {'strength': '1%', 'dosage_form': 'gel', 'unit': 'tube'},
        ],
        'metformin': [
            {'strength': '500mg', 'dosage_form': 'tablet', 'unit': ''},
            {'strength': '850mg', 'dosage_form': 'tablet', 'unit': ''},
            {'strength': '1000mg', 'dosage_form': 'tablet', 'unit': ''},
        ],
        'omeprazole': [
            {'strength': '20mg', 'dosage_form': 'capsule', 'unit': ''},
            {'strength': '40mg', 'dosage_form': 'capsule', 'unit': ''},
        ],
        'cetirizine': [
            {'strength': '10mg', 'dosage_form': 'tablet', 'unit': ''},
            {'strength': '5mg/5ml', 'dosage_form': 'syrup', 'unit': 'bottle'},
        ],
        'amoxicillin/clavulanic': [
            {'strength': '625mg', 'dosage_form': 'tablet', 'unit': ''},
            {'strength': '1g', 'dosage_form': 'tablet', 'unit': ''},
            {'strength': '228.5mg/5ml', 'dosage_form': 'suspension', 'unit': 'bottle'},
        ],
    }

    # Build a set of existing (generic, brand_lower, strength_lower) to skip duplicates
    existing_keys = set()
    for m in Medication.objects.only('generic_name', 'brand_names', 'strength').iterator():
        for b in (m.brand_names or []):
            existing_keys.add((
                (m.generic_name or '').lower().strip(),
                b.lower().strip(),
                (m.strength or '').lower().strip(),
            ))

    to_create = []
    total_variants = 0
    skipped_count = 0
    per_generic = []

    for generic, brands in sorted(BRAND_NAMES.items()):
        if requested_set is not None and generic not in requested_set:
            continue
        category = CAT_MAP.get(generic, 'other')
        defaults = DEFAULT_VARIANTS.get(generic, [{'strength': '', 'dosage_form': 'tablet', 'unit': ''}])
        side_effects = SIDE_EFFECTS.get(category, '')
        contraindications = CONTRAINDICATIONS.get(category, '')
        cat = category if category in dict(Medication.Category.choices) else 'other'
        requires_rx = cat in (
            'oncology', 'immunosuppressant', 'cns', 'cardiovascular',
            'hormone', 'antibiotic', 'antiviral', 'antifungal', 'vaccine',
        )

        gen_created = 0
        gen_skipped = 0

        for brand in brands:
            for d in defaults:
                strength = d['strength']
                dosage_form = d['dosage_form'] if d['dosage_form'] in dict(Medication.DosageForm.choices) else 'other'
                unit = d.get('unit', '')
                total_variants += 1

                check_key = (generic, brand.lower().strip(), strength.lower().strip())
                if check_key in existing_keys:
                    skipped_count += 1
                    gen_skipped += 1
                    continue

                to_create.append(Medication(
                    generic_name=generic,
                    product_code='',
                    category=cat,
                    dosage_form=dosage_form,
                    strength=strength,
                    unit=unit,
                    brand_names=[brand],
                    requires_prescription=requires_rx,
                    side_effects=side_effects,
                    contraindications=contraindications,
                    description=f"Expanded from brand names dictionary: {brand} ({generic})",
                    is_active=True,
                ))
                gen_created += 1

        if gen_created or gen_skipped:
            per_generic.append({'generic': generic, 'created': gen_created, 'skipped': gen_skipped})

    created_count = 0
    if not dry_run and to_create:
        # Bulk create in batches of 500
        batch_size = 500
        for i in range(0, len(to_create), batch_size):
            Medication.objects.bulk_create(to_create[i:i + batch_size])
        created_count = len(to_create)

    return Response({
        'total_generics': len(BRAND_NAMES),
        'total_variants': total_variants,
        'created': created_count if not dry_run else len(to_create),
        'skipped': skipped_count,
        'dry_run': dry_run,
        'per_generic': per_generic[:50],
    })


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def update_brand_names(request):
    """Re-run the brand-name lookup on all Medication records in the current schema.

    Query params:
        force=true   Overwrite non-empty brand_names (default: only fill empty ones).
        dry_run=true Just report what would change.
    """
    if request.user.role not in ALLOWED_DELETE_ALL_ROLES:
        return Response(
            {"detail": "You do not have permission to update brand names."},
            status=status.HTTP_403_FORBIDDEN,
        )

    from medications.management.commands.seed_medications import _get_brand_names

    force = request.query_params.get("force", "false").lower() in ("1", "true", "yes")
    dry_run = request.query_params.get("dry_run", "false").lower() in ("1", "true", "yes")

    qs = Medication.objects.all()
    total = qs.count()
    updated = 0
    skipped = 0
    unchanged = 0
    changes_preview: list[dict] = []

    for med in qs.iterator():
        lookup_name = med.generic_name or med.name or ""
        if not lookup_name:
            skipped += 1
            continue
        detected = _get_brand_names(lookup_name)
        if not detected:
            alt = f"{med.product_code or ''} {med.abbreviation or ''}".strip()
            if alt:
                detected = _get_brand_names(alt)
        if not detected:
            unchanged += 1
            continue

        current = med.brand_names or []
        current_lower = {b.lower() for b in current}
        detected_lower = {b.lower() for b in detected}

        if not force and current:
            unchanged += 1
            continue
        if detected_lower == current_lower and not force:
            unchanged += 1
            continue

        if dry_run and len(changes_preview) < 50:
            changes_preview.append({
                "id": med.id,
                "name": med.generic_name or med.name,
                "old": current,
                "new": detected,
            })

        if not dry_run:
            med.brand_names = detected
            med.save(update_fields=["brand_names"])
        updated += 1

    return Response({
        "total": total,
        "updated": updated,
        "skipped": skipped,
        "unchanged": unchanged,
        "dry_run": dry_run,
        "preview": changes_preview,
    })


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def create_brand_entry(request):
    """Create or update a brand-name catalog entry with per-brand details.

    Payload:
        {
            "generic_name": "paracetamol",
            "entries": [
                {
                    "brand": "Panadol",
                    "strength": "500mg",
                    "dosage_form": "tablet",
                    "category": "analgesic",
                    "unit": "tab",
                    "requires_prescription": false
                },
                {
                    "brand": "Calpol",
                    "strength": "120mg/5ml",
                    "dosage_form": "suspension",
                    "category": "analgesic",
                    "unit": "ml",
                    "requires_prescription": false
                }
            ]
        }

    If a Medication with the same generic_name (case-insensitive) already exists,
    its brand_names are merged. The first entry's strength/dosage_form/category/unit
    are applied to the Medication record itself (as defaults); subsequent entries
    with different strength+form combos create additional Medication records
    (like the expand feature).
    """
    if request.user.role not in ALLOWED_DELETE_ALL_ROLES:
        return Response(
            {"detail": "You do not have permission to create brand entries."},
            status=status.HTTP_403_FORBIDDEN,
        )

    generic_name = str(request.data.get("generic_name") or "").strip()
    if not generic_name:
        return Response(
            {"detail": "Generic name is required."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    entries = request.data.get("entries")
    if not entries or not isinstance(entries, list):
        return Response(
            {"detail": "entries must be a non-empty list of brand detail objects."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    # Validate each entry
    valid_forms = {f for f, _ in Medication.DosageForm.choices}
    valid_cats = {c for c, _ in Medication.Category.choices}
    cleaned_entries = []
    for idx, e in enumerate(entries):
        brand = str(e.get("brand") or "").strip()
        if not brand:
            return Response(
                {"detail": f"Entry {idx + 1}: brand name is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        strength = str(e.get("strength") or "").strip()
        dosage_form = str(e.get("dosage_form") or "").strip().lower()
        if dosage_form and dosage_form not in valid_forms:
            return Response(
                {"detail": f"Entry {idx + 1}: invalid dosage form '{dosage_form}'."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        category = str(e.get("category") or "").strip().lower()
        if category and category not in valid_cats:
            return Response(
                {"detail": f"Entry {idx + 1}: invalid category '{category}'."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        unit = str(e.get("unit") or "").strip()
        rx = e.get("requires_prescription", None)
        cleaned_entries.append({
            "brand": brand,
            "strength": strength,
            "dosage_form": dosage_form,
            "category": category,
            "unit": unit,
            "requires_prescription": rx,
        })

    # Merge all brand names into the main Medication record (or create it)
    med = Medication.objects.filter(generic_name__iexact=generic_name).first()
    is_new = med is None
    if is_new:
        med = Medication(generic_name=generic_name)

    # Collect all brand names
    all_brands = [e["brand"] for e in cleaned_entries]
    existing_lower = {b.lower() for b in (med.brand_names or [])}
    merged = list(med.brand_names or [])
    for b in all_brands:
        if b.lower() not in existing_lower:
            merged.append(b)
            existing_lower.add(b.lower())
    med.brand_names = merged

    # Apply first entry's details as defaults on the main medication
    first = cleaned_entries[0]
    if first["strength"]:
        med.strength = first["strength"]
    if first["dosage_form"]:
        med.dosage_form = first["dosage_form"]
    if first["category"]:
        med.category = first["category"]
    if first["unit"]:
        med.unit = first["unit"]
    if first["requires_prescription"] is not None:
        rx = first["requires_prescription"]
        if isinstance(rx, str):
            med.requires_prescription = rx.strip().lower() in ("yes", "true", "1")
        else:
            med.requires_prescription = bool(rx)
    med.save()

    created_extra = 0
    created_items = [{
        "id": med.id,
        "brand": first["brand"],
        "name": med.generic_name,
        "generic_name": med.generic_name,
        "strength": med.strength,
        "dosage_form": med.dosage_form,
    }]

    # For entries with different strength+dosage_form combos, create separate Medication records
    seen_combos = {(first["strength"].lower(), first["dosage_form"].lower())}
    for e in cleaned_entries[1:]:
        combo = (e["strength"].lower(), e["dosage_form"].lower())
        if combo in seen_combos:
            continue
        seen_combos.add(combo)

        # Check if a medication with same generic + strength + form already exists
        existing = Medication.objects.filter(
            generic_name__iexact=generic_name,
            strength__iexact=e["strength"],
            dosage_form__iexact=e["dosage_form"],
        ).first()
        if existing:
            # Merge brand name into existing record
            existing_lower2 = {b.lower() for b in (existing.brand_names or [])}
            if e["brand"].lower() not in existing_lower2:
                existing.brand_names = list(existing.brand_names or []) + [e["brand"]]
                existing.save(update_fields=["brand_names"])
            created_items.append({
                "id": existing.id,
                "brand": e["brand"],
                "name": existing.generic_name,
                "generic_name": existing.generic_name,
                "strength": existing.strength,
                "dosage_form": existing.dosage_form,
            })
            continue

        extra = Medication(
            generic_name=generic_name,
            brand_names=[e["brand"]],
            strength=e["strength"],
            dosage_form=e["dosage_form"] or "tablet",
            category=e["category"] or med.category or "other",
            unit=e["unit"] or med.unit or "",
            requires_prescription=med.requires_prescription if e["requires_prescription"] is None else (
                e["requires_prescription"].strip().lower() in ("yes", "true", "1")
                if isinstance(e["requires_prescription"], str)
                else bool(e["requires_prescription"])
            ),
        )
        extra.save()
        created_extra += 1
        created_items.append({
            "id": extra.id,
            "brand": e["brand"],
            "name": extra.generic_name,
            "generic_name": extra.generic_name,
            "strength": extra.strength,
            "dosage_form": extra.dosage_form,
        })

    total_brands = len(merged)
    total_records = 1 + created_extra

    return Response({
        "created": is_new,
        "id": med.id,
        "generic_name": med.generic_name,
        "brand_names": merged,
        "extra_created": created_extra,
        "total_records": total_records,
        "created_items": created_items,
        "detail": (
            f"{'Created' if is_new else 'Updated'} '{med.generic_name}' with {total_brands} brand name(s)"
            + (f" across {total_records} medication record(s)" if created_extra else "")
            + "."
        ),
    }, status=status.HTTP_201_CREATED if is_new else status.HTTP_200_OK)


class DrugInteractionViewSet(viewsets.ModelViewSet):
    queryset = (DrugInteraction.objects
                .select_related('drug_a', 'drug_b')
                .filter(is_active=True))
    serializer_class = DrugInteractionSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = None
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['severity', 'drug_a', 'drug_b']
    search_fields = ['drug_a__generic_name', 'drug_b__generic_name', 'description']
    ordering = ['-severity']


class CheckInteractionsView(APIView):
    """POST {medication_ids: [...], names: [...]} → list of matched interactions.

    Resolves each name to a Medication by case-insensitive generic_name match
    so it works for both prescription and dispensing flows that pass names.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        ids = list(request.data.get('medication_ids') or [])
        names = list(request.data.get('names') or [])
        med_qs = Medication.objects.none()
        if ids:
            med_qs = Medication.objects.filter(id__in=ids)
        if names:
            name_q = Q()
            for n in names:
                if n:
                    name_q |= Q(generic_name__iexact=n)
            if name_q:
                med_qs = (med_qs | Medication.objects.filter(name_q)).distinct()
        med_ids = list(med_qs.values_list('id', flat=True))
        if len(med_ids) < 2:
            return Response({'count': 0, 'interactions': [], 'unresolved_names': []})

        # Find pairwise interactions among the resolved set.
        inter = (DrugInteraction.objects
                 .select_related('drug_a', 'drug_b')
                 .filter(is_active=True, drug_a_id__in=med_ids, drug_b_id__in=med_ids))
        # filter pairs entirely within set already; serialize
        results = DrugInteractionSerializer(inter, many=True).data

        # severity ranking for client convenience
        rank = {'minor': 1, 'moderate': 2, 'major': 3, 'contraindicated': 4}
        max_sev = max((rank.get(r['severity'], 0) for r in results), default=0)

        resolved_names = set(med_qs.values_list('generic_name', flat=True))
        unresolved = [n for n in names if n and n.lower() not in {r.lower() for r in resolved_names}]

        return Response({
            'count': len(results),
            'highest_severity': next((k for k, v in rank.items() if v == max_sev), None),
            'interactions': results,
            'resolved_count': len(med_ids),
            'unresolved_names': unresolved,
        })

