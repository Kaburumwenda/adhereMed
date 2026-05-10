"""FHIR R4 resource builders for homecare interoperability.

Produces minimal but spec-conformant FHIR R4 JSON for the resources we
care about. Designed to be embedded in DRF responses or wrapped in a
Bundle for batch export. No external deps.
"""
from __future__ import annotations

from datetime import date, datetime, timezone as _tz
from typing import Any, Iterable

from django.utils import timezone

from .loinc import LOINC_VITALS, vital_unit


def _iso(dt) -> str | None:
    if not dt:
        return None
    if isinstance(dt, datetime):
        if timezone.is_naive(dt):
            dt = timezone.make_aware(dt, _tz.utc)
        return dt.isoformat()
    if isinstance(dt, date):
        return dt.isoformat()
    return str(dt)


def _ref(resource_type: str, ident) -> dict | None:
    if ident in (None, ''):
        return None
    return {'reference': f'{resource_type}/{ident}'}


# ─────────────────────────────────────────────────────────
# Patient
# ─────────────────────────────────────────────────────────
def patient_resource(p) -> dict:
    full = (p.user.full_name or '').strip()
    parts = full.split(' ', 1)
    given = [parts[0]] if parts else []
    family = parts[1] if len(parts) > 1 else ''
    name = {'use': 'official', 'text': full or 'Unknown'}
    if family:
        name['family'] = family
    if given:
        name['given'] = given

    telecom = []
    if getattr(p.user, 'email', None):
        telecom.append({'system': 'email', 'value': p.user.email})
    if getattr(p.user, 'phone_number', None):
        telecom.append({'system': 'phone', 'value': p.user.phone_number})

    address = []
    if p.address:
        a = {'use': 'home', 'text': p.address}
        if p.nationality:
            a['country'] = p.nationality
        address.append(a)

    contact = []
    for c in (p.emergency_contacts or []):
        contact.append({
            'name': {'text': c.get('name', '')},
            'telecom': [{'system': 'phone', 'value': c.get('phone', '')}] if c.get('phone') else [],
            'relationship': [{'text': c.get('relationship', '')}] if c.get('relationship') else [],
        })

    return {
        'resourceType': 'Patient',
        'id': str(p.id),
        'identifier': [{
            'system': 'urn:afyaone:homecare:mrn',
            'value': p.medical_record_number,
        }],
        'active': p.is_active,
        'name': [name],
        'gender': (p.gender or 'unknown').lower(),
        'birthDate': _iso(p.date_of_birth),
        'telecom': telecom,
        'address': address,
        'contact': contact,
    }


# ─────────────────────────────────────────────────────────
# MedicationRequest (from HomecarePrescription items)
# ─────────────────────────────────────────────────────────
def medication_request_resources(rx) -> list[dict]:
    out = []
    items = rx.items or []
    for idx, it in enumerate(items):
        out.append({
            'resourceType': 'MedicationRequest',
            'id': f'{rx.id}-{idx}',
            'status': 'active' if rx.status == 'active' else rx.status,
            'intent': 'order',
            'medicationCodeableConcept': {'text': it.get('medication_name', '')},
            'subject': _ref('Patient', rx.patient_id),
            'authoredOn': _iso(rx.issued_at or rx.created_at),
            'dosageInstruction': [{
                'text': ' '.join(filter(None, [
                    f"{it.get('dose','')} {it.get('dose_unit','')}".strip(),
                    it.get('frequency', ''),
                    it.get('route', ''),
                ])).strip() or '—',
                'route': {'text': it.get('route', 'oral')},
                'doseAndRate': [{
                    'doseQuantity': {
                        'value': _to_float(it.get('dose')),
                        'unit': it.get('dose_unit', ''),
                    },
                }] if _to_float(it.get('dose')) is not None else [],
            }],
            'dispenseRequest': {
                'quantity': {'value': it.get('quantity')} if it.get('quantity') else None,
                'expectedSupplyDuration': (
                    {'value': it.get('duration_days'), 'unit': 'd', 'system': 'http://unitsofmeasure.org', 'code': 'd'}
                    if it.get('duration_days') else None
                ),
            },
            'note': [{'text': rx.notes}] if rx.notes else [],
        })
    return out


def _to_float(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


# ─────────────────────────────────────────────────────────
# MedicationAdministration (from DoseEvent)
# ─────────────────────────────────────────────────────────
def medication_administration_resource(dose) -> dict:
    sched = dose.schedule
    return {
        'resourceType': 'MedicationAdministration',
        'id': str(dose.id),
        'status': {
            'taken': 'completed', 'missed': 'not-done',
            'skipped': 'not-done', 'refused': 'not-done',
            'pending': 'in-progress',
        }.get(dose.status, 'unknown'),
        'medicationCodeableConcept': {'text': sched.medication_name},
        'subject': _ref('Patient', sched.patient_id),
        'effectiveDateTime': _iso(dose.administered_at or dose.scheduled_at),
        'dosage': {
            'text': f'{sched.dose} via {sched.route}',
            'route': {'text': sched.route},
        },
        'note': [{'text': dose.notes}] if dose.notes else [],
    }


# ─────────────────────────────────────────────────────────
# Observation (from CaregiverNote vitals)
# ─────────────────────────────────────────────────────────
def observation_resources_from_note(note) -> list[dict]:
    out = []
    vitals = note.vitals or {}
    if not isinstance(vitals, dict):
        return out
    for key, raw in vitals.items():
        if raw in (None, ''):
            continue
        loinc = LOINC_VITALS.get(key)
        if not loinc:
            continue
        # Blood pressure as compound observation
        if key == 'bp' and isinstance(raw, str) and '/' in raw:
            try:
                sys_v, dia_v = [float(x.strip()) for x in raw.split('/')[:2]]
            except ValueError:
                continue
            out.append({
                'resourceType': 'Observation',
                'id': f'{note.id}-bp',
                'status': 'final',
                'category': [{'coding': [{'system': 'http://terminology.hl7.org/CodeSystem/observation-category',
                                          'code': 'vital-signs'}]}],
                'code': {'coding': [{'system': 'http://loinc.org',
                                     'code': loinc['code'], 'display': loinc['display']}]},
                'subject': _ref('Patient', note.patient_id),
                'effectiveDateTime': _iso(note.recorded_at),
                'component': [
                    {'code': {'coding': [{'system': 'http://loinc.org', 'code': '8480-6',
                                          'display': 'Systolic blood pressure'}]},
                     'valueQuantity': {'value': sys_v, 'unit': 'mmHg',
                                       'system': 'http://unitsofmeasure.org', 'code': 'mm[Hg]'}},
                    {'code': {'coding': [{'system': 'http://loinc.org', 'code': '8462-4',
                                          'display': 'Diastolic blood pressure'}]},
                     'valueQuantity': {'value': dia_v, 'unit': 'mmHg',
                                       'system': 'http://unitsofmeasure.org', 'code': 'mm[Hg]'}},
                ],
            })
            continue
        val = _to_float(raw)
        if val is None:
            continue
        out.append({
            'resourceType': 'Observation',
            'id': f'{note.id}-{key}',
            'status': 'final',
            'category': [{'coding': [{'system': 'http://terminology.hl7.org/CodeSystem/observation-category',
                                      'code': 'vital-signs'}]}],
            'code': {'coding': [{'system': 'http://loinc.org',
                                 'code': loinc['code'], 'display': loinc['display']}]},
            'subject': _ref('Patient', note.patient_id),
            'effectiveDateTime': _iso(note.recorded_at),
            'valueQuantity': {
                'value': val, 'unit': vital_unit(key),
                'system': 'http://unitsofmeasure.org',
            },
        })
    return out


# ─────────────────────────────────────────────────────────
# Consent
# ─────────────────────────────────────────────────────────
def consent_resource(c) -> dict:
    status_v = 'inactive' if c.revoked_at else 'active'
    return {
        'resourceType': 'Consent',
        'id': str(c.id),
        'status': status_v,
        'scope': {'coding': [{'system': 'http://terminology.hl7.org/CodeSystem/consentscope',
                              'code': 'patient-privacy'}]},
        'category': [{'text': c.scope}],
        'patient': _ref('Patient', c.patient_id),
        'dateTime': _iso(c.signed_at or c.created_at),
        'performer': [{'display': c.signed_by_name}] if c.signed_by_name else [],
        'organization': [{'display': c.granted_to}] if c.granted_to else [],
        'sourceAttachment': (
            {'contentType': 'image/png', 'data': c.signature_data_url.split(',', 1)[-1]}
            if c.signature_data_url else None
        ),
        'provision': {
            'type': 'permit',
            'period': {'end': _iso(c.expires_at)} if c.expires_at else None,
        },
        'extension': [{
            'url': 'urn:afyaone:consent:signatureHash',
            'valueString': c.signature_hash,
        }] if c.signature_hash else [],
    }


# ─────────────────────────────────────────────────────────
# Bundle
# ─────────────────────────────────────────────────────────
def bundle(resources: Iterable[dict], bundle_type: str = 'collection') -> dict:
    entries = []
    for r in resources:
        if not r:
            continue
        entries.append({
            'fullUrl': f"urn:uuid:{r.get('resourceType','Resource')}-{r.get('id','')}",
            'resource': r,
        })
    return {
        'resourceType': 'Bundle',
        'type': bundle_type,
        'timestamp': _iso(timezone.now()),
        'total': len(entries),
        'entry': entries,
    }
