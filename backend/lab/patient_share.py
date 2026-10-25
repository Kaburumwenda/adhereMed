"""Push a lab order snapshot into the patient portal.

``lab`` is a TENANT_APP — its tables live inside each clinic's own schema — while
the patient dashboard runs with no clinic schema at all. ``exchange`` is a
SHARED_APP (public schema only) and is therefore the cross-tenant bridge the
patient portal reads from.

Every clinic-side change calls :func:`sync_order_to_patient`, which writes a
flattened, patient-safe copy of the order into
``exchange.PatientLabRecord``. The copy is deliberately *lossy*:

* results are only shared once a verifier has signed the report;
* internal signatures, notes and audit trails never leave the clinic;
* the clinic's five states collapse into the simpler staging a patient needs.

The whole thing is best-effort. A sharing failure must never roll back the
clinical write that triggered it, so every error is swallowed and logged.
"""

import logging

from django_tenants.utils import schema_context

logger = logging.getLogger(__name__)

PUBLIC_SCHEMA = 'public'


def _iso(value):
    return value.isoformat() if value else None


def _test_entries(order):
    """The ordered tests, flattened for the portal.

    The catalogue's own description, turnaround and reference ranges travel
    with the record so the patient report can be rendered from the shared copy
    alone — the patient has no access to the clinic schema.
    """
    entries = []
    for test in order.tests.all():
        entries.append({
            'name': test.name,
            'code': test.code or '',
            'department': test.department or '',
            'specimen_type': test.specimen_type or '',
            'description': (getattr(test, 'description', '') or '')[:600],
            'instructions': (getattr(test, 'instructions', '') or '')[:400],
            'turnaround_time': getattr(test, 'turnaround_time', '') or '',
            'reference_ranges': _normalised_ranges(test),
        })
    return entries


def _normalised_ranges(test):
    """Reference ranges as a flat ``{analyte: "low–high unit"}`` map.

    Keeps the structure intact (rather than one pre-joined string) so the
    patient report can draw a value-vs-range bar per analyte.
    """
    ranges = getattr(test, 'reference_ranges', None)
    if not ranges:
        return {}
    try:
        if isinstance(ranges, dict):
            out = {}
            for key, value in ranges.items():
                if isinstance(value, dict):
                    low, high = value.get('low'), value.get('high')
                    unit = value.get('unit') or ''
                    if low not in (None, '') and high not in (None, ''):
                        out[str(key)] = f'{low} – {high} {unit}'.strip()
                    else:
                        out[str(key)] = str(value.get('label') or value)
                else:
                    out[str(key)] = str(value)
            return out
        if isinstance(ranges, list):
            out = {}
            for item in ranges:
                if isinstance(item, dict):
                    label = (
                        item.get('label') or item.get('name')
                        or item.get('analyte') or ''
                    )
                    low, high = item.get('low'), item.get('high')
                    unit = item.get('unit') or ''
                    if low not in (None, '') and high not in (None, ''):
                        out[str(label)] = f'{low} – {high} {unit}'.strip()
                    elif label:
                        out[str(label)] = str(item.get('range') or '')
                else:
                    out[str(item)] = ''
            return out
    except Exception:  # noqa: BLE001 — a malformed range must not break sharing
        return {}
    return {}


def _reference_range_for(test):
    """First reference range string for a test, if it has one.

    ``reference_ranges`` is either a list of ``{low, high, unit}`` style dicts
    or a free-form mapping — render whichever shape it holds.
    """
    ranges = getattr(test, 'reference_ranges', None)
    if not ranges:
        return ''
    try:
        if isinstance(ranges, list) and ranges:
            first = ranges[0]
            if isinstance(first, dict):
                low, high = first.get('low'), first.get('high')
                unit = first.get('unit') or ''
                if low not in (None, '') and high not in (None, ''):
                    return f'{low} – {high} {unit}'.strip()
                label = first.get('label') or first.get('name') or ''
                return str(label)
            return str(first)
        if isinstance(ranges, dict):
            if ranges:
                key, value = next(iter(ranges.items()))
                return f'{key}: {value}'
    except Exception:  # noqa: BLE001 — a malformed range must not break sharing
        return ''
    return ''


def _result_entries(order):
    """Results as the patient sees them. Only for a verified report."""
    entries = []
    for result in order.results.select_related('test').all():
        test = result.test
        entries.append({
            'test_name': test.name if test else '',
            'test_code': (test.code or '') if test else '',
            'department': (test.department or '') if test else '',
            'specimen_type': (test.specimen_type or '') if test else '',
            'result_value': result.result_value or '',
            'unit': result.unit or '',
            'reference_range': _reference_range_for(test) if test else '',
            'is_abnormal': bool(result.is_abnormal),
            'comments': result.comments or '',
            'result_date': _iso(result.result_date),
        })
    return entries


def _authorisation(order):
    """The sign-off row, or None when nobody has signed yet."""
    try:
        return order.authorization
    except Exception:  # noqa: BLE001 — RelatedObjectDoesNotExist
        return None


def build_patient_payload(order):
    """Flatten a ``LabOrder`` into the fields the portal stores."""
    patient = order.patient
    user = getattr(patient, 'user', None)
    if user is None:
        return None

    from exchange.models import PatientLabRecord

    authorisation = _authorisation(order)
    verified = bool(authorisation and authorisation.verified_at)

    patient_name = getattr(user, 'full_name', '') or ''
    if not patient_name.strip():
        patient_name = f'{user.first_name} {user.last_name}'.strip() or user.email

    # A draft report is a clinical working document — nothing reaches the
    # patient until a verifier signs it.
    results = _result_entries(order) if verified else []

    payload = {
        'source_order_id': order.id,
        'order_ref': f'LAB-{order.id:05d}',
        'patient_user_id': user.id,
        'patient_name': patient_name,
        'patient_number': getattr(patient, 'patient_number', '') or '',
        'tests': _test_entries(order),
        'priority': order.priority or 'routine',
        'clinical_notes': order.clinical_notes or '',
        'ordered_by_name': getattr(order.ordered_by, 'full_name', '') or '',
        'clinic_site_name': getattr(order.clinic_site, 'name', '') or '',
        'is_home_collection': bool(order.is_home_collection),
        'requested_on': _iso(order.created_at),
        'raw_status': order.status,
        'stage': PatientLabRecord.stage_for(order.status, verified),
        'stage_updated_at': _iso(order.updated_at),
        'results': results,
        'result_summary': PatientLabRecord.summarise(results),
        'abnormal_count': sum(1 for r in results if r.get('is_abnormal')),
        'performed_by_name': getattr(authorisation, 'performed_by_name', '') or '',
        'performed_at': _iso(getattr(authorisation, 'performed_at', None)),
        'verified_by_name': getattr(authorisation, 'verified_by_name', '') or '',
        'verified_at': _iso(getattr(authorisation, 'verified_at', None)),
        'is_verified': verified,
        'turnaround_seconds': getattr(authorisation, 'turnaround_seconds', None),
    }
    return payload


def sync_order_to_patient(order):
    """Mirror one lab order into the patient portal (best-effort).

    Returns the record id on success, ``None`` when there is nothing to share
    or when sharing failed.
    """
    if order is None:
        return None

    try:
        payload = build_patient_payload(order)
    except Exception:  # noqa: BLE001
        logger.warning('lab share: could not build payload for order %s',
                       getattr(order, 'id', '?'), exc_info=True)
        return None

    if payload is None:
        return None

    try:
        from exchange.models import PatientLabRecord
        from tenants.models import Tenant

        tenant_id = getattr(order, '_share_tenant_id', None)
        if tenant_id is None:
            # `ordered_by.tenant` is the clinic the order belongs to.
            tenant_id = getattr(order.ordered_by, 'tenant_id', None)
        tenant_name = ''
        if tenant_id:
            tenant_name = (
                Tenant.objects.filter(pk=tenant_id)
                .values_list('name', flat=True)
                .first()
                or ''
            )

        if not tenant_id:
            return None

        payload['source_tenant_id'] = tenant_id
        payload['source_tenant_name'] = tenant_name

        with schema_context(PUBLIC_SCHEMA):
            record, _ = PatientLabRecord.objects.update_or_create(
                source_tenant_id=tenant_id,
                source_order_id=order.id,
                defaults=payload,
            )
            return record.id
    except Exception:  # noqa: BLE001 — sharing must never break the clinic flow
        logger.warning('lab share: sync failed for order %s',
                       getattr(order, 'id', '?'), exc_info=True)
        return None


def refresh_order_snapshot(order_id):
    """Reload the order with everything the payload needs, then sync it."""
    from .models import LabOrder

    try:
        order = (
            LabOrder.objects
            .select_related(
                'patient__user', 'ordered_by', 'clinic_site', 'authorization',
            )
            .prefetch_related('tests', 'results__test')
            .filter(pk=order_id)
            .first()
        )
    except Exception:  # noqa: BLE001
        logger.warning('lab share: order %s not reloadable', order_id, exc_info=True)
        return None

    return sync_order_to_patient(order) if order else None
