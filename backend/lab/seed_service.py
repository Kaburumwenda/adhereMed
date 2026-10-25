"""Preview + selective seeding for the demo lab catalogue.

The demo catalogue in ``seed_data.py`` is an immutable, shared template. Every
clinic reviews it on its own page and can:

* pick which tests/panels to add,
* edit any field for its own copy,
* hide entries it never wants.

Those choices are stored per tenant in :class:`LabSeedCustomization`, and this
module is the single place that merges template + tenant overrides so the
preview API, the apply API and any future surface stay consistent.
"""
from decimal import Decimal, InvalidOperation

from django.db import transaction
from django.utils import timezone

from .models import LabPanel, LabSeedCustomization, LabTestCatalog
from .seed_data import PANELS, TESTS

#: Template fields a clinic is allowed to override, per kind.
TEST_FIELDS = (
    'name', 'department', 'specimen_type', 'turnaround_time',
    'instructions', 'reference_ranges', 'price',
)
PANEL_FIELDS = ('name', 'department', 'description', 'price', 'test_codes')


def _decimal(value, fallback=None):
    """Best-effort decimal cast that never explodes on bad input."""
    if value in (None, ''):
        return fallback
    try:
        return Decimal(str(value))
    except (InvalidOperation, TypeError, ValueError):
        return fallback


def _template_tests():
    return {t['code']: t for t in TESTS}


def _template_panels():
    return {p['code']: p for p in PANELS}


def _overrides(row, fields):
    """Only the fields the clinic actually set, as a plain dict."""
    data = {}
    for field in fields:
        value = getattr(row, field, None)
        if value is None or value == '':
            continue
        if field == 'price':
            data[field] = float(value)
        elif field == 'reference_ranges':
            if value:
                data[field] = value
        elif field == 'test_codes':
            if value:
                data[field] = value
        else:
            data[field] = value
    return data


def _merge_test(template, custom):
    """Template values with this clinic's overrides applied on top."""
    merged = {
        'code': template['code'],
        'name': template.get('name', ''),
        'department': template.get('department', ''),
        'specimen_type': template.get('specimen_type', ''),
        'turnaround_time': template.get('turnaround_time', ''),
        'instructions': template.get('instructions', ''),
        'reference_ranges': template.get('reference_ranges', {}) or {},
        'price': template.get('price', 0),
    }
    if custom is not None:
        for field in TEST_FIELDS:
            value = getattr(custom, field, None)
            if value is None or value == '':
                continue
            merged[field] = float(value) if field == 'price' else value
    return merged


def _merge_panel(template, custom):
    merged = {
        'code': template['code'],
        'name': template.get('name', ''),
        'department': template.get('department', ''),
        'description': template.get('description', ''),
        'price': template.get('price', 0),
        'test_codes': list(template.get('test_codes', [])),
    }
    if custom is not None:
        for field in PANEL_FIELDS:
            value = getattr(custom, field, None)
            if value is None or value == '':
                continue
            if field == 'price':
                merged[field] = float(value)
            elif field == 'test_codes':
                if value:
                    merged[field] = list(value)
            else:
                merged[field] = value
    return merged


def _differs(merged, template, fields):
    """True when the clinic changed anything away from the template."""
    for field in fields:
        a = merged.get(field)
        b = template.get(field, {} if field == 'reference_ranges' else '')
        if field == 'price':
            a = _decimal(a, Decimal('0'))
            b = _decimal(b, Decimal('0'))
            if a != b:
                return True
            continue
        if field == 'reference_ranges':
            if (a or {}) != (b or {}):
                return True
            continue
        if field == 'test_codes':
            if list(a or []) != list(b or []):
                return True
            continue
        if (a or '') != (b or ''):
            return True
    return False


def build_seed_preview():
    """Everything the seed page needs, merged for the current tenant."""
    customizations = {
        (row.kind, row.code): row
        for row in LabSeedCustomization.objects.all()
    }

    existing_tests = {
        row.code: row
        for row in LabTestCatalog.objects.filter(
            code__in=[t['code'] for t in TESTS],
        ).only('id', 'code', 'name', 'price')
    }
    existing_panels = {
        row.code: row
        for row in LabPanel.objects.filter(
            code__in=[p['code'] for p in PANELS],
        ).only('id', 'code', 'name', 'price')
    }

    tests = []
    for template in TESTS:
        custom = customizations.get((LabSeedCustomization.Kind.TEST, template['code']))
        merged = _merge_test(template, custom)
        live = existing_tests.get(template['code'])
        # A row the clinic created by hand owns this code — never overwrite it.
        locked = bool(
            live is not None
            and not (custom and custom.is_applied)
            and live.name != template.get('name')
        )
        tests.append({
            'kind': LabSeedCustomization.Kind.TEST,
            **merged,
            'price': float(merged['price'] or 0),
            # Nothing is preselected — the clinic opts in entry by entry.
            'is_selected': bool(custom and custom.is_selected),
            'is_customized': _differs(merged, template, TEST_FIELDS),
            'is_dismissed': bool(custom and custom.is_dismissed),
            'is_applied': bool(custom and custom.is_applied) or live is not None,
            'is_locked': locked,
            'existing_id': live.id if live else None,
            'existing_name': live.name if live else None,
            'defaults': {
                'name': template.get('name', ''),
                'department': template.get('department', ''),
                'specimen_type': template.get('specimen_type', ''),
                'turnaround_time': template.get('turnaround_time', ''),
                'instructions': template.get('instructions', ''),
                'reference_ranges': template.get('reference_ranges', {}) or {},
                'price': float(template.get('price', 0) or 0),
            },
        })

    panels = []
    for template in PANELS:
        custom = customizations.get((LabSeedCustomization.Kind.PANEL, template['code']))
        merged = _merge_panel(template, custom)
        live = existing_panels.get(template['code'])
        locked = bool(
            live is not None
            and not (custom and custom.is_applied)
            and live.name != template.get('name')
        )
        panels.append({
            'kind': LabSeedCustomization.Kind.PANEL,
            **merged,
            'price': float(merged['price'] or 0),
            # Nothing is preselected — the clinic opts in entry by entry.
            'is_selected': bool(custom and custom.is_selected),
            'is_customized': _differs(merged, template, PANEL_FIELDS),
            'is_dismissed': bool(custom and custom.is_dismissed),
            'is_applied': bool(custom and custom.is_applied) or live is not None,
            'is_locked': locked,
            'existing_id': live.id if live else None,
            'existing_name': live.name if live else None,
            'defaults': {
                'name': template.get('name', ''),
                'department': template.get('department', ''),
                'description': template.get('description', ''),
                'price': float(template.get('price', 0) or 0),
                'test_codes': list(template.get('test_codes', [])),
            },
        })

    return {
        'tests': tests,
        'panels': panels,
        'meta': {
            'total_tests': len(tests),
            'total_panels': len(panels),
            'departments': sorted({t['department'] for t in tests if t['department']}),
            'specimens': sorted({t['specimen_type'] for t in tests if t['specimen_type']}),
            'generated_at': timezone.now(),
        },
    }


def _upsert_customization(code, kind, payload, fields):
    """Save this clinic's version of one template entry."""
    row, _ = LabSeedCustomization.objects.get_or_create(code=code, kind=kind)
    row.is_selected = bool(payload.get('is_selected', True))
    row.is_dismissed = bool(payload.get('is_dismissed', False))

    for field in fields:
        if field not in payload:
            continue
        value = payload.get(field)
        if field == 'price':
            row.price = _decimal(value, None)
        elif field == 'reference_ranges':
            row.reference_ranges = value or None
        elif field == 'test_codes':
            row.test_codes = list(value) if value else None
        else:
            setattr(row, field, value if value is not None else '')
    return row


def apply_seed(tests=None, panels=None, *, user=None):
    """Write the chosen entries into the clinic's own catalogue.

    The template stays untouched: only this tenant's ``LabTestCatalog`` /
    ``LabPanel`` rows are created or updated, and only for the codes the clinic
    selected. Manual catalogue rows that merely share a code are never
    overwritten unless they were previously seeded here.
    """
    tests = tests or []
    panels = panels or []
    template_tests = _template_tests()
    template_panels = _template_panels()

    created_tests = updated_tests = skipped_tests = 0
    created_panels = updated_panels = skipped_panels = 0
    touched_codes = []

    with transaction.atomic():
        # ── Tests ──────────────────────────────────────────────────────────
        for payload in tests:
            code = (payload.get('code') or '').strip()
            template = template_tests.get(code)
            if not template:
                continue  # unknown code — ignore rather than invent data

            custom = _upsert_customization(
                code, LabSeedCustomization.Kind.TEST, payload, TEST_FIELDS,
            )
            merged = _merge_test(template, custom)

            if not payload.get('is_selected', True):
                custom.is_customized = _differs(merged, template, TEST_FIELDS)
                custom.save()
                continue

            live = LabTestCatalog.objects.filter(code=code).first()
            adoptable = live is None or custom.is_applied or live.name == template.get('name')
            if live is not None and not adoptable:
                # A hand-made test owns this code — leave it alone.
                skipped_tests += 1
                custom.is_customized = _differs(merged, template, TEST_FIELDS)
                custom.save()
                continue

            if live is None:
                LabTestCatalog.objects.create(
                    code=code,
                    name=merged['name'] or code,
                    department=merged['department'] or '',
                    specimen_type=merged['specimen_type'] or '',
                    reference_ranges=merged['reference_ranges'] or {},
                    price=_decimal(merged['price'], Decimal('0')),
                    turnaround_time=merged['turnaround_time'] or '',
                    instructions=merged['instructions'] or '',
                    is_active=True,
                )
                created_tests += 1
            else:
                live.name = merged['name'] or live.name
                live.department = merged['department'] or ''
                live.specimen_type = merged['specimen_type'] or live.specimen_type
                live.reference_ranges = merged['reference_ranges'] or {}
                live.price = _decimal(merged['price'], live.price)
                live.turnaround_time = merged['turnaround_time'] or ''
                live.instructions = merged['instructions'] or ''
                live.save(update_fields=[
                    'name', 'department', 'specimen_type', 'reference_ranges',
                    'price', 'turnaround_time', 'instructions',
                ])
                updated_tests += 1

            custom.is_applied = True
            custom.is_customized = _differs(merged, template, TEST_FIELDS)
            # Applied entries drop back out of the selection so the page always
            # returns to \u201cnothing selected \u2014 pick what to add\u201d.
            custom.is_selected = False
            custom.save()
            touched_codes.append(code)

        # ── Panels ─────────────────────────────────────────────────────────
        for payload in panels:
            code = (payload.get('code') or '').strip()
            template = template_panels.get(code)
            if not template:
                continue

            custom = _upsert_customization(
                code, LabSeedCustomization.Kind.PANEL, payload, PANEL_FIELDS,
            )
            merged = _merge_panel(template, custom)

            if not payload.get('is_selected', True):
                custom.is_customized = _differs(merged, template, PANEL_FIELDS)
                custom.save()
                continue

            live = LabPanel.objects.filter(code=code).first()
            adoptable = live is None or custom.is_applied or live.name == template.get('name')
            if live is not None and not adoptable:
                skipped_panels += 1
                custom.is_customized = _differs(merged, template, PANEL_FIELDS)
                custom.save()
                continue

            if live is None:
                live = LabPanel.objects.create(
                    code=code,
                    name=merged['name'] or code,
                    department=merged['department'] or '',
                    description=merged['description'] or '',
                    price=_decimal(merged['price'], Decimal('0')),
                    is_active=True,
                )
                created_panels += 1
            else:
                live.name = merged['name'] or live.name
                live.department = merged['department'] or ''
                live.description = merged['description'] or ''
                live.price = _decimal(merged['price'], live.price)
                live.save(update_fields=['name', 'department', 'description', 'price'])
                updated_panels += 1

            # Only link tests that actually exist in this clinic's catalogue.
            codes = merged['test_codes'] or []
            live.tests.set(LabTestCatalog.objects.filter(code__in=codes))

            custom.is_applied = True
            custom.is_customized = _differs(merged, template, PANEL_FIELDS)
            # Same as tests: an applied panel leaves the selection.
            custom.is_selected = False
            custom.save()

    return {
        'tests_created': created_tests,
        'tests_updated': updated_tests,
        'tests_skipped': skipped_tests,
        'panels_created': created_panels,
        'panels_updated': updated_panels,
        'panels_skipped': skipped_panels,
        'total_touched': created_tests + updated_tests + created_panels + updated_panels,
        'detail': (
            f'{created_tests + created_panels} added, '
            f'{updated_tests + updated_panels} updated to your clinic lab.'
        ),
    }


def reset_customization(code=None, kind=None):
    """Forget this clinic's edits (all of them, or a single entry)."""
    queryset = LabSeedCustomization.objects.all()
    if code:
        queryset = queryset.filter(code=code)
    if kind:
        queryset = queryset.filter(kind=kind)
    count = queryset.count()
    queryset.delete()
    return count
