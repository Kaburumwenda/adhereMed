"""Demo data framework for the OHSMS module.

The tenant-facing **SECURITY & SETTINGS → Demo data** page lets a production
tenant load a realistic safety register so staff can explore the product, then
remove exactly what was loaded without touching data their team entered.

How it works
------------
1. :func:`seed` records the current maximum primary key of every OHS model.
2. It invokes ``seed_ohsms`` restricted to the selected dataset keys.
3. Any row whose PK is above the pre-run maximum must have been created by the
   run, so it is stored in :class:`ohs.models.DemoDataRecord`.
4. :func:`clear` resolves those records back to model instances and deletes
   them, newest dependants first.

Because the seeder blocks share a small number of parent objects (sites,
hazard categories, hazards) which live in their own datasets, every dataset
declares the prerequisites it needs. Selecting a dataset automatically pulls
its prerequisites in, so a partial seed never crashes on a missing parent.
"""
from __future__ import annotations

import io
import time
from collections import defaultdict

from django.apps import apps
from django.core.management import call_command
from django.db import connection
from django.db.models import Max

from .models import DemoDataRecord, DemoDataRun

# ─────────────────────────────────────────────────────────────────────────
#  Dataset registry
# ─────────────────────────────────────────────────────────────────────────
GROUPS = [
    'Risk & planning',
    'Operations',
    'People & health',
    'Governance',
    'Documents & partners',
]

#: Ordered exactly as the seeder executes its blocks.
DATASETS = [
    {
        'key': 'sites',
        'label': 'Sites & locations',
        'description': 'Seven operational sites with headcounts, risk profiles and emergency assembly points. Every other dataset hangs off these.',
        'icon': 'mdi-office-building-marker-outline',
        'group': 'Risk & planning',
        'models': ['ohs.Site'],
        'requires': [],
    },
    {
        'key': 'hazard_categories',
        'label': 'Hazard categories',
        'description': 'The taxonomy used to classify hazards across the register.',
        'icon': 'mdi-shape-outline',
        'group': 'Risk & planning',
        'models': ['ohs.HazardCategory'],
        'requires': [],
    },
    {
        'key': 'hazards',
        'label': 'Hazard register & controls',
        'description': 'Hazards scored severity × likelihood with the control measures in place.',
        'icon': 'mdi-alert-outline',
        'group': 'Risk & planning',
        'models': ['ohs.Hazard', 'ohs.ControlMeasure'],
        'requires': ['sites', 'hazard_categories'],
    },
    {
        'key': 'risk_assessments',
        'label': 'Risk assessments',
        'description': 'Formal assessments with scored line items and approvals.',
        'icon': 'mdi-clipboard-list-outline',
        'group': 'Risk & planning',
        'models': ['ohs.RiskAssessment', 'ohs.RiskAssessmentItem'],
        'requires': ['sites'],
    },
    {
        'key': 'legal_register',
        'label': 'Legal register',
        'description': 'Statutory and standard obligations with compliance status.',
        'icon': 'mdi-gavel',
        'group': 'Risk & planning',
        'models': ['ohs.LegalRequirement'],
        'requires': ['sites', 'hazards'],
    },
    {
        'key': 'objectives',
        'label': 'Safety objectives',
        'description': 'Annual OH&S programme targets with progress.',
        'icon': 'mdi-target',
        'group': 'Risk & planning',
        'models': ['ohs.SafetyObjective'],
        'requires': ['sites', 'hazards'],
    },
    {
        'key': 'incidents',
        'label': 'Incidents & CAPA',
        'description': 'Recordable incidents, near misses and their corrective actions.',
        'icon': 'mdi-ambulance',
        'group': 'Operations',
        'models': ['ohs.Incident', 'ohs.IncidentAction'],
        'requires': ['sites'],
    },
    {
        'key': 'inspections',
        'label': 'Inspections',
        'description': 'Completed workplace inspections with per-item findings.',
        'icon': 'mdi-clipboard-check-outline',
        'group': 'Operations',
        'models': ['ohs.Inspection', 'ohs.InspectionItem'],
        'requires': ['sites'],
    },
    {
        'key': 'permits',
        'label': 'Permits to work',
        'description': 'High-risk work permits across their full lifecycle.',
        'icon': 'mdi-file-document-check-outline',
        'group': 'Operations',
        'models': ['ohs.PermitToWork'],
        'requires': ['sites'],
    },
    {
        'key': 'observations',
        'label': 'Behaviour observations',
        'description': 'Safe and at-risk behaviour observations from the floor.',
        'icon': 'mdi-account-check-outline',
        'group': 'Operations',
        'models': ['ohs.Observation'],
        'requires': ['sites'],
    },
    {
        'key': 'drills',
        'label': 'Emergency drills',
        'description': 'Evacuation and response exercises with timings.',
        'icon': 'mdi-fire-alert',
        'group': 'Operations',
        'models': ['ohs.EmergencyDrill'],
        'requires': ['sites'],
    },
    {
        'key': 'equipment',
        'label': 'Safety equipment',
        'description': 'Extinguishers, harnesses and gas detectors with inspections and defects.',
        'icon': 'mdi-fire-extinguisher',
        'group': 'Operations',
        'models': ['ohs.SafetyEquipment', 'ohs.EquipmentInspection', 'ohs.EquipmentDefect'],
        'requires': ['sites'],
    },
    {
        'key': 'training',
        'label': 'Training & competence',
        'description': 'Courses, sessions and the resulting worker training records.',
        'icon': 'mdi-school-outline',
        'group': 'People & health',
        'models': ['ohs.TrainingCourse', 'ohs.TrainingRecord'],
        'requires': ['sites'],
    },
    {
        'key': 'ppe',
        'label': 'PPE stock & issues',
        'description': 'PPE catalogue, stock levels and issue history.',
        'icon': 'mdi-hard-hat',
        'group': 'People & health',
        'models': ['ohs.PpeItem', 'ohs.PpeIssue'],
        'requires': ['sites'],
    },
    {
        'key': 'health_surveillance',
        'label': 'Health surveillance',
        'description': 'Medicals, audiometry and respiratory fitness records.',
        'icon': 'mdi-heart-pulse',
        'group': 'People & health',
        'models': ['ohs.HealthSurveillance'],
        'requires': ['sites'],
    },
    {
        'key': 'assessments',
        'label': 'Medical assessments',
        'description': 'Pre-employment, periodic and exit medicals scored against '
                       'job demand profiles, with baselines for drift comparison.',
        'icon': 'mdi-clipboard-pulse-outline',
        'group': 'People & health',
        'models': [
            'ohs.AssessmentLabResult', 'ohs.AssessmentFinding',
            'ohs.HealthAssessment', 'ohs.JobDemandProfile',
        ],
        'requires': ['sites'],
    },
    {
        'key': 'exposure',
        'label': 'Exposure monitoring',
        'description': 'Noise, dust and chemical sampling results against limits.',
        'icon': 'mdi-weather-windy',
        'group': 'People & health',
        'models': ['ohs.ExposureMonitoring'],
        'requires': ['sites'],
    },
    {
        'key': 'certifications',
        'label': 'Certifications & licences',
        'description': 'Statutory certificates with expiry tracking.',
        'icon': 'mdi-certificate-outline',
        'group': 'People & health',
        'models': ['ohs.Certification'],
        'requires': ['sites'],
    },
    {
        'key': 'staff',
        'label': 'Staff directory',
        'description': 'Twelve HSE team members with staff profiles.',
        'icon': 'mdi-account-hard-hat',
        'group': 'People & health',
        'models': ['staff_profiles.StaffProfile', 'accounts.User'],
        'requires': [],
        'warning': 'Creates sign-in accounts on the demo domain. Only enable on a demo tenant.',
    },
    {
        'key': 'audits',
        'label': 'Compliance audits',
        'description': 'Internal and external audits with scores and findings.',
        'icon': 'mdi-clipboard-search-outline',
        'group': 'Governance',
        'models': ['ohs.ComplianceAudit'],
        'requires': ['sites'],
    },
    {
        'key': 'management_reviews',
        'label': 'Management reviews',
        'description': 'Clause 9.3 reviews with inputs, outputs and decisions.',
        'icon': 'mdi-account-supervisor-circle-outline',
        'group': 'Governance',
        'models': ['ohs.ManagementReview'],
        'requires': ['sites'],
    },
    {
        'key': 'meetings',
        'label': 'Safety committee meetings',
        'description': 'Committee and toolbox talks with attendance.',
        'icon': 'mdi-account-group-outline',
        'group': 'Governance',
        'models': ['ohs.SafetyMeeting', 'ohs.MeetingAttendance'],
        'requires': ['sites'],
    },
    {
        'key': 'documents',
        'label': 'Document control',
        'description': 'Controlled documents, revisions, acknowledgements and the SDS library.',
        'icon': 'mdi-file-document-multiple-outline',
        'group': 'Documents & partners',
        'models': [
            'ohs.Document',
            'ohs.DocumentRevision',
            'ohs.DocumentAcknowledgement',
        ],
        'requires': ['sites'],
    },
    {
        'key': 'contractors',
        'label': 'Contractors',
        'description': 'Pre-qualified contractors and their site engagements.',
        'icon': 'mdi-account-tie-hat',
        'group': 'Documents & partners',
        'models': ['ohs.Contractor', 'ohs.ContractorEngagement'],
        'requires': ['sites'],
    },
]

DATASET_BY_KEY = {d['key']: d for d in DATASETS}
DATASET_ORDER = [d['key'] for d in DATASETS]

#: model label -> dataset key
MODEL_OWNER = {}
for _ds in DATASETS:
    for _label in _ds['models']:
        MODEL_OWNER[_label] = _ds['key']

#: Deletion order: dependants before the rows they point at.
DELETE_ORDER = [
    'staff_profiles.StaffProfile',
    'ohs.EquipmentDefect', 'ohs.EquipmentInspection', 'ohs.SafetyEquipment',
    'ohs.Certification', 'ohs.ManagementReview', 'ohs.MeetingAttendance',
    'ohs.SafetyMeeting', 'ohs.ContractorEngagement', 'ohs.Contractor',
    'ohs.DocumentAcknowledgement', 'ohs.DocumentRevision', 'ohs.Document',
    'ohs.ComplianceAudit', 'ohs.SafetyObjective', 'ohs.LegalRequirement',
    'ohs.EmergencyDrill', 'ohs.Observation', 'ohs.ExposureMonitoring',
    'ohs.AssessmentLabResult', 'ohs.AssessmentFinding',
    'ohs.HealthAssessment', 'ohs.JobDemandProfile',
    'ohs.HealthSurveillance', 'ohs.PpeIssue', 'ohs.PpeItem',
    'ohs.TrainingRecord', 'ohs.TrainingCourse', 'ohs.PermitToWork',
    'ohs.InspectionItem', 'ohs.Inspection', 'ohs.IncidentAction', 'ohs.Incident',
    'ohs.RiskAssessmentItem', 'ohs.RiskAssessment', 'ohs.ControlMeasure',
    'ohs.Hazard', 'ohs.HazardCategory', 'ohs.Site',
    'accounts.User',
]


# ─────────────────────────────────────────────────────────────────────────
#  Helpers
# ─────────────────────────────────────────────────────────────────────────
def _model(label):
    app_label, model_name = label.split('.')
    return apps.get_model(app_label, model_name)


def _max_pk(label):
    try:
        model = _model(label)
    except LookupError:
        return 0
    return model.objects.aggregate(m=Max('pk'))['m'] or 0


def expand(keys):
    """Return the requested keys plus prerequisites, in execution order."""
    wanted = set()
    stack = [k for k in keys if k]
    unknown = [k for k in stack if k not in DATASET_BY_KEY]
    if unknown:
        raise ValueError(f'Unknown dataset(s): {", ".join(sorted(unknown))}')
    while stack:
        key = stack.pop()
        if key in wanted:
            continue
        wanted.add(key)
        stack.extend(DATASET_BY_KEY[key]['requires'])
    return [k for k in DATASET_ORDER if k in wanted]


def _actor_name(user):
    if user is None:
        return ''
    name = f'{getattr(user, "first_name", "")} {getattr(user, "last_name", "")}'.strip()
    return name or getattr(user, 'email', '') or ''


# ─────────────────────────────────────────────────────────────────────────
#  Seed
# ─────────────────────────────────────────────────────────────────────────
def seed(dataset_keys, *, user=None, rand_seed=4507, reset=False):
    """Seed the selected datasets and record everything created.

    ``reset`` removes the demo objects for the *requested* datasets first, so a
    tenant can re-seed without tripping the seeder's unique reference codes.
    Prerequisite datasets are deliberately left alone — they're often seeded by
    an earlier run that other data still depends on.

    Returns the :class:`DemoDataRun`. Failures are captured on the run rather
    than raised so the UI can show what was partially created and offer to
    clear it.
    """
    requested = [k for k in dict.fromkeys(dataset_keys or []) if k]
    keys = expand(requested)
    if not keys:
        raise ValueError('Select at least one dataset.')

    if reset:
        clear(datasets=requested)

    schema = connection.schema_name
    run = DemoDataRun.objects.create(
        datasets=keys,
        created_by=user if getattr(user, 'pk', None) else None,
        created_by_name=_actor_name(user),
    )

    owned_labels = [label for label in MODEL_OWNER]
    before = {label: _max_pk(label) for label in owned_labels}

    started = time.monotonic()
    buffer = io.StringIO()
    status = DemoDataRun.Status.COMPLETE
    error = ''
    try:
        call_command(
            'seed_ohsms',
            schema=schema,
            only=','.join(keys),
            seed=rand_seed,
            stdout=buffer,
            stderr=buffer,
        )
    except Exception as exc:  # noqa: BLE001 - surfaced to the operator
        status = DemoDataRun.Status.FAILED
        error = f'{type(exc).__name__}: {exc}'
    finally:
        # `seed_ohsms` switches the connection schema; restore the tenant's.
        try:
            if connection.schema_name != schema:
                connection.set_schema(schema)
        except Exception:  # noqa: BLE001 - best effort
            pass

    # Whatever made it in is tracked, even on a failed run, so Clear works.
    summary = defaultdict(dict)
    records = []
    created_total = 0
    for label in owned_labels:
        try:
            model = _model(label)
            new_ids = list(
                model.objects.filter(pk__gt=before[label]).values_list('pk', flat=True)
            )
        except Exception:  # noqa: BLE001 - table missing in this schema
            continue
        if not new_ids:
            continue
        dataset = MODEL_OWNER[label]
        summary[dataset][label] = len(new_ids)
        created_total += len(new_ids)
        records.extend(
            DemoDataRecord(run=run, dataset=dataset, model_label=label, object_id=pk)
            for pk in new_ids
        )

    if records:
        DemoDataRecord.objects.bulk_create(records, batch_size=1000)

    if status == DemoDataRun.Status.COMPLETE and error:
        status = DemoDataRun.Status.PARTIAL

    run.summary = {k: dict(v) for k, v in summary.items()}
    run.objects_created = created_total
    run.status = status
    run.error = error[:4000]
    run.duration_ms = int((time.monotonic() - started) * 1000)
    run.save(update_fields=[
        'summary', 'objects_created', 'status', 'error', 'duration_ms', 'updated_at',
    ])
    return run


# ─────────────────────────────────────────────────────────────────────────
#  Clear
# ─────────────────────────────────────────────────────────────────────────
def clear(*, datasets=None, run=None):
    """Delete demo objects created by previous runs.

    ``datasets`` limits the clear to specific dataset keys; ``run`` limits it to
    a single run. With neither, every demo object in the tenant is removed.
    Real, tenant-entered records are never touched because only tracked PKs are
    deleted.
    """
    qs = DemoDataRecord.objects.all()
    if run is not None:
        qs = qs.filter(run=run)
    if datasets:
        wanted = [k for k in datasets if k in DATASET_BY_KEY]
        qs = qs.filter(dataset__in=wanted)

    by_model = defaultdict(set)
    for label, object_id in qs.values_list('model_label', 'object_id'):
        by_model[label].add(object_id)
    if not by_model:
        return {'deleted': 0, 'models': {}, 'errors': []}

    deleted = 0
    per_model = {}
    errors = []

    ordered = [m for m in DELETE_ORDER if m in by_model]
    ordered += [m for m in by_model if m not in DELETE_ORDER]

    for label in ordered:
        ids = list(by_model[label])
        try:
            model = _model(label)
        except LookupError:
            errors.append(f'{label}: unknown model')
            continue
        try:
            for chunk in range(0, len(ids), 500):
                batch = ids[chunk:chunk + 500]
                result = model.objects.filter(pk__in=batch).delete()
                n = result[0] if isinstance(result, tuple) else 0
                deleted += n
                per_model[label] = per_model.get(label, 0) + n
        except Exception as exc:  # noqa: BLE001 - report, keep going
            errors.append(f'{label}: {type(exc).__name__}: {exc}')

    # Drop the tracking rows (a cascade may already have removed some).
    qs.delete()
    return {'deleted': deleted, 'models': per_model, 'errors': errors}


# ─────────────────────────────────────────────────────────────────────────
#  Reporting
# ─────────────────────────────────────────────────────────────────────────
def demo_counts():
    """{dataset_key: live demo object count} for everything still tracked."""
    counts = {}
    for dataset in DemoDataRecord.objects.values_list('dataset', flat=True):
        counts[dataset] = counts.get(dataset, 0) + 1
    return counts


def catalog():
    """Dataset registry decorated with live demo counts."""
    counts = demo_counts()
    out = []
    for ds in DATASETS:
        item = dict(ds)
        item['demo_count'] = counts.get(ds['key'], 0)
        item['prerequisites'] = [
            {'key': k, 'label': DATASET_BY_KEY[k]['label']} for k in ds['requires']
        ]
        out.append(item)
    return out


def overview():
    runs = list(DemoDataRun.objects.all()[:20])
    total_demo = DemoDataRecord.objects.count()
    total_created = sum(r.objects_created for r in runs)
    return {
        'datasets': catalog(),
        'groups': GROUPS,
        'runs': [
            {
                'run_id': str(r.run_id),
                'datasets': r.datasets,
                'summary': r.summary,
                'objects_created': r.objects_created,
                'status': r.status,
                'error': r.error,
                'duration_ms': r.duration_ms,
                'created_at': r.created_at.isoformat() if r.created_at else None,
                'created_by_name': r.created_by_name,
                'live_objects': r.records.count(),
            }
            for r in runs
        ],
        'totals': {
            'demo_objects': total_demo,
            'objects_seeded': total_created,
            'runs': DemoDataRun.objects.count(),
            'datasets_with_data': len(counts_nonzero()),
        },
    }


def counts_nonzero():
    return [k for k, v in demo_counts().items() if v]
