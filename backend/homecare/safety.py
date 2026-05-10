"""Clinical safety checks at prescribe time.

Two layers:

1. **Allergy conflict** — patient's `allergies` free-text field is tokenised
   and matched (substring, case-insensitive) against each Rx item name.
2. **Drug-drug interaction (DDI)** — pairwise lookup against the curated
   :class:`homecare.models.DrugInteraction` table, plus a built-in seed of
   well-known dangerous combinations as a safety net for fresh tenants.
3. **Duplicate therapy** — same drug name appearing more than once across
   the prescription items or the patient's currently active medication
   schedules.

The checker is *advisory*: it returns a list of alert dicts; it does not
block the save. Persisting an alert and tracking overrides is done by the
view layer (see ``HomecarePrescriptionViewSet.safety_check``).
"""
from __future__ import annotations

import re
from typing import Iterable

# Curated fall-back rules used when the tenant has no DrugInteraction rows
# yet. Keyed as sorted lowercase pairs.
_BUILTIN_INTERACTIONS = {
    ('aspirin', 'warfarin'): ('major',
        'Increased bleeding risk',
        'Concomitant use significantly raises risk of GI and intracranial '
        'bleeding. Avoid or monitor INR closely.'),
    ('clopidogrel', 'warfarin'): ('major',
        'Increased bleeding risk',
        'Combined antiplatelet + anticoagulant therapy. Use only with strict '
        'monitoring.'),
    ('ibuprofen', 'warfarin'): ('major',
        'Bleeding risk + reduced renal clearance',
        'NSAIDs displace warfarin from albumin and impair platelet function.'),
    ('amiodarone', 'warfarin'): ('major',
        'Potentiates warfarin',
        'Amiodarone inhibits warfarin metabolism; reduce warfarin dose by '
        '30-50% and monitor INR.'),
    ('simvastatin', 'clarithromycin'): ('contraindicated',
        'Rhabdomyolysis risk',
        'Macrolide CYP3A4 inhibition raises statin levels dramatically.'),
    ('simvastatin', 'erythromycin'): ('contraindicated',
        'Rhabdomyolysis risk',
        'Macrolide CYP3A4 inhibition raises statin levels dramatically.'),
    ('atorvastatin', 'clarithromycin'): ('major',
        'Rhabdomyolysis risk',
        'Reduce statin dose; consider alternative antibiotic.'),
    ('metformin', 'iohexol'): ('major',
        'Lactic acidosis risk with IV contrast',
        'Hold metformin around contrast administration.'),
    ('metformin', 'iodinated contrast'): ('major',
        'Lactic acidosis risk with IV contrast',
        'Hold metformin around contrast administration.'),
    ('digoxin', 'amiodarone'): ('major',
        'Doubled digoxin levels',
        'Reduce digoxin dose by 50% and monitor levels.'),
    ('digoxin', 'verapamil'): ('major',
        'Increased digoxin levels',
        'Risk of bradycardia and AV block.'),
    ('ssri', 'maoi'): ('contraindicated',
        'Serotonin syndrome',
        'Combination of SSRI/SNRI with MAOI can be fatal.'),
    ('fluoxetine', 'tramadol'): ('major',
        'Serotonin syndrome + lowered seizure threshold',
        'Avoid combination if possible.'),
    ('sertraline', 'tramadol'): ('major',
        'Serotonin syndrome', ''),
    ('linezolid', 'fluoxetine'): ('contraindicated',
        'Serotonin syndrome',
        'Linezolid is a reversible MAOI. Wash-out required.'),
    ('linezolid', 'sertraline'): ('contraindicated',
        'Serotonin syndrome', ''),
    ('ciprofloxacin', 'tizanidine'): ('contraindicated',
        'Severe hypotension and sedation',
        'Ciprofloxacin inhibits CYP1A2 metabolism of tizanidine.'),
    ('amlodipine', 'simvastatin'): ('moderate',
        'Increased statin exposure',
        'Limit simvastatin to 20 mg/day.'),
    ('lisinopril', 'spironolactone'): ('moderate',
        'Hyperkalaemia',
        'Monitor potassium closely.'),
    ('lisinopril', 'potassium chloride'): ('moderate',
        'Hyperkalaemia', ''),
    ('nitrate', 'sildenafil'): ('contraindicated',
        'Severe hypotension',
        'PDE5 inhibitors with any nitrate are contraindicated.'),
    ('isosorbide', 'sildenafil'): ('contraindicated',
        'Severe hypotension', ''),
}

_SEVERITY_ORDER = {'info': 0, 'minor': 1, 'moderate': 2, 'major': 3, 'contraindicated': 4}


def _normalise(name: str) -> str:
    return re.sub(r'[^a-z0-9 ]+', '', (name or '').lower()).strip()


def _drug_names(items: Iterable[dict]) -> list[str]:
    out = []
    for it in items or []:
        if not isinstance(it, dict):
            continue
        n = _normalise(it.get('name') or it.get('medication_name') or '')
        if n:
            out.append(n)
    return out


def _allergy_tokens(text: str) -> list[str]:
    if not text:
        return []
    parts = re.split(r'[,;\n/]+', text.lower())
    return [p.strip() for p in parts if p and p.strip()]


def check_allergies(patient, drug_names: list[str]) -> list[dict]:
    alerts = []
    tokens = _allergy_tokens(getattr(patient, 'allergies', '') or '')
    if not tokens:
        return alerts
    for drug in drug_names:
        for tok in tokens:
            # Either side may be a substring of the other (e.g. patient lists
            # "penicillin" and the Rx is "amoxicillin/clavulanate").
            if not tok or len(tok) < 3:
                continue
            if tok in drug or any(tok in w for w in drug.split()):
                alerts.append({
                    'kind': 'allergy',
                    'severity': 'major',
                    'message': f'Patient is allergic to "{tok}"',
                    'detail': f'Prescribed item "{drug}" matches a recorded allergy.',
                    'drugs': [drug],
                })
                break
    return alerts


def _lookup_interaction(a: str, b: str):
    """Return (severity, message, detail) or None."""
    from .models import DrugInteraction

    key = tuple(sorted((a, b)))
    # 1. tenant-curated table
    row = DrugInteraction.objects.filter(
        drug_a=key[0], drug_b=key[1], is_active=True
    ).first()
    if row:
        return row.severity, row.summary, row.detail
    # 2. built-in seed
    return _BUILTIN_INTERACTIONS.get(key)


def check_interactions(drug_names: list[str],
                       extra_drug_names: list[str] | None = None) -> list[dict]:
    alerts = []
    seen = set()
    rx = list(drug_names)
    extra = list(extra_drug_names or [])
    # Cross-product Rx-with-Rx and Rx-with-active.
    pairs = []
    for i, a in enumerate(rx):
        for b in rx[i + 1:]:
            pairs.append((a, b))
        for b in extra:
            pairs.append((a, b))
    for a, b in pairs:
        if a == b:
            continue
        key = tuple(sorted((a, b)))
        if key in seen:
            continue
        seen.add(key)
        hit = _lookup_interaction(a, b)
        if not hit:
            continue
        sev, msg, detail = hit
        alerts.append({
            'kind': 'interaction',
            'severity': sev,
            'message': f'{a} + {b}: {msg}',
            'detail': detail,
            'drugs': [a, b],
        })
    return alerts


def check_duplicates(drug_names: list[str],
                     extra_drug_names: list[str] | None = None) -> list[dict]:
    alerts = []
    counts: dict[str, int] = {}
    for d in drug_names:
        counts[d] = counts.get(d, 0) + 1
    for d in (extra_drug_names or []):
        if d in counts:
            counts[d] = counts.get(d, 0) + 1
    for d, c in counts.items():
        if c > 1:
            alerts.append({
                'kind': 'duplicate',
                'severity': 'moderate',
                'message': f'Duplicate therapy: {d}',
                'detail': f'"{d}" appears {c} times in the prescription or '
                          f'active medication schedules.',
                'drugs': [d],
            })
    return alerts


def evaluate_prescription(prescription) -> list[dict]:
    """Return a sorted list of alert dicts (most severe first)."""
    rx_drugs = _drug_names(prescription.items or [])
    # Active medication schedules for the same patient.
    active_drugs = []
    for sch in prescription.patient.medication_schedules.filter(is_active=True):
        n = _normalise(getattr(sch, 'medication_name', '') or '')
        if n:
            active_drugs.append(n)
    alerts = []
    alerts += check_allergies(prescription.patient, rx_drugs)
    alerts += check_interactions(rx_drugs, active_drugs)
    alerts += check_duplicates(rx_drugs, active_drugs)
    alerts.sort(key=lambda a: _SEVERITY_ORDER.get(a['severity'], 0), reverse=True)
    return alerts
