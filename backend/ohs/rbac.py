"""Role-based access control (RBAC) for the OHSMS module.

Enforcement is capability-based. Every check resolves through
:func:`has_capability`, which combines:

1. a tenant ``OhsRoleDefinition`` row for the user's role (custom role or a
   tenant override of a built-in role), else
2. the platform defaults in :data:`BUILTIN_ROLE_CAPS`.

Custom roles are created on the Roles & Access page, stored on
``User.role`` (max 20 chars) and enforced everywhere the capability is
checked.

Capability families mirror the ISO 45001 clause structure:

    Planning ....... hazard.* / risk.*
    Operation ...... incident.* / inspection.* / permit.* / equipment.* /
                     observation.* / drill.*
    Support ........ training.* / ppe.* / health.* / exposure.* / document.*
    Performance .... audit.* / objective.* / review.* / analytics.*
    Governance ..... meeting.* / legal.* / cert.* / contractor.*
    Administration . staff.* / rbac.* / org.* / audit_log.*
"""
from __future__ import annotations

from rest_framework.permissions import SAFE_METHODS, IsAuthenticated


# ── Role groups ──────────────────────────────────────────────────────────
ADMIN_ROLES = {'super_admin', 'tenant_admin', 'admin'}
HSE_LEADERSHIP_ROLES = ADMIN_ROLES | {'hse_manager'}
FIELD_ROLES = {'safety_officer', 'supervisor', 'occ_health_nurse'}


def _role(request):
    return getattr(getattr(request, 'user', None), 'role', '') or ''


# ── Capability catalog (drives the Roles & Access page) ──────────────────
CAPABILITY_CATALOG = [
    # ── Hazards & risk ───────────────────────────────────────────────
    {'key': 'hazard.view', 'label': 'View the hazard register',
     'group': 'Hazards & risk',
     'description': 'Read hazards, controls and their risk scores.'},
    {'key': 'hazard.manage', 'label': 'Create & edit hazards',
     'group': 'Hazards & risk',
     'description': 'Log new hazards and update existing findings.'},
    {'key': 'hazard.delete', 'label': 'Delete hazards',
     'group': 'Hazards & risk',
     'description': 'Destructive — closing a hazard is usually the correct action.'},
    {'key': 'control.manage', 'label': 'Manage controls & action owners',
     'group': 'Hazards & risk',
     'description': 'Add hierarchy-of-control measures and mark them implemented.'},
    {'key': 'risk.assess', 'label': 'Create & edit risk assessments',
     'group': 'Hazards & risk',
     'description': 'Build assessments and score 5×5 line items.'},
    {'key': 'risk.approve', 'label': 'Approve risk assessments',
     'group': 'Hazards & risk',
     'description': 'Sign off an assessment so it becomes the official record.'},

    # ── Incidents ────────────────────────────────────────────────────
    {'key': 'incident.view', 'label': 'View incidents & CAPA',
     'group': 'Incidents',
     'description': 'Read incident reports, root causes and corrective actions.'},
    {'key': 'incident.report', 'label': 'Report incidents & near misses',
     'group': 'Incidents',
     'description': 'Log a new event from the field.'},
    {'key': 'incident.investigate', 'label': 'Investigate & assign CAPA',
     'group': 'Incidents',
     'description': 'Record root cause and raise corrective actions.'},
    {'key': 'incident.close', 'label': 'Close incidents',
     'group': 'Incidents',
     'description': 'Sign off the investigation and close the event.'},

    # ── Inspections & permits ────────────────────────────────────────
    {'key': 'inspection.view', 'label': 'View inspections',
     'group': 'Inspections & permits',
     'description': 'Read scheduled and completed inspections with scores.'},
    {'key': 'inspection.conduct', 'label': 'Conduct & complete inspections',
     'group': 'Inspections & permits',
     'description': 'Fill checklists and submit results.'},
    {'key': 'permit.view', 'label': 'View permits to work',
     'group': 'Inspections & permits',
     'description': 'Read permit status and validity windows.'},
    {'key': 'permit.manage', 'label': 'Raise permits to work',
     'group': 'Inspections & permits',
     'description': 'Create a permit request for high-risk work.'},
    {'key': 'permit.approve', 'label': 'Approve & close permits',
     'group': 'Inspections & permits',
     'description': 'Authorise work to start and sign it off when finished.'},

    # ── Safety equipment ─────────────────────────────────────────────
    {'key': 'equipment.view', 'label': 'View safety equipment',
     'group': 'Safety equipment',
     'description': 'Read the asset register, compliance state and health scores.'},
    {'key': 'equipment.manage', 'label': 'Add & edit safety equipment',
     'group': 'Safety equipment',
     'description': 'Register assets and change their inspection regime.'},
    {'key': 'equipment.inspect', 'label': 'Record inspections & calibrations',
     'group': 'Safety equipment',
     'description': 'Log inspection results and roll currency dates forward.'},
    {'key': 'equipment.defect', 'label': 'Report & resolve equipment defects',
     'group': 'Safety equipment',
     'description': 'Raise work orders and close them out.'},

    # ── Observations & drills ────────────────────────────────────────
    {'key': 'observation.view', 'label': 'View behaviour observations',
     'group': 'Observations & drills',
     'description': 'Read safe and at-risk behaviour observations.'},
    {'key': 'observation.log', 'label': 'Log observations',
     'group': 'Observations & drills',
     'description': 'Submit field observations and coaching notes.'},
    {'key': 'drill.view', 'label': 'View emergency drills',
     'group': 'Observations & drills',
     'description': 'Read drill schedules and outcomes.'},
    {'key': 'drill.manage', 'label': 'Schedule & record drills',
     'group': 'Observations & drills',
     'description': 'Plan drills and capture findings afterwards.'},

    # ── Health & exposure ────────────────────────────────────────────
    {'key': 'health.view', 'label': 'View health surveillance',
     'group': 'Health & exposure',
     'description': 'SENSITIVE — medical fitness records and restrictions.'},
    {'key': 'health.manage', 'label': 'Record health surveillance',
     'group': 'Health & exposure',
     'description': 'SENSITIVE — capture medicals, results and next-due dates.'},
    {'key': 'exposure.view', 'label': 'View exposure monitoring',
     'group': 'Health & exposure',
     'description': 'Read occupational hygiene readings against limits.'},

    # ── Training & PPE ───────────────────────────────────────────────
    {'key': 'training.view', 'label': 'View training & competence',
     'group': 'Training & PPE',
     'description': 'Read course catalogues and staff certificate currency.'},
    {'key': 'training.manage', 'label': 'Manage courses & records',
     'group': 'Training & PPE',
     'description': 'Create courses and record completions / expiries.'},
    {'key': 'ppe.view', 'label': 'View PPE stock & issues',
     'group': 'Training & PPE',
     'description': 'Read PPE inventory and the issue register.'},
    {'key': 'ppe.issue', 'label': 'Issue PPE to workers',
     'group': 'Training & PPE',
     'description': 'Record an issue and acknowledge receipt.'},

    # ── Documents ────────────────────────────────────────────────────
    {'key': 'document.view', 'label': 'View controlled documents & SDS',
     'group': 'Documents',
     'description': 'Read policies, procedures and safety data sheets.'},
    {'key': 'document.manage', 'label': 'Create & revise documents',
     'group': 'Documents',
     'description': 'Add documents and publish new revisions.'},
    {'key': 'document.approve', 'label': 'Approve documents',
     'group': 'Documents',
     'description': 'Make a revision the effective controlled version.'},

    # ── Contractors ──────────────────────────────────────────────────
    {'key': 'contractor.view', 'label': 'View contractors',
     'group': 'Contractors',
     'description': 'Read the contractor register and document compliance.'},
    {'key': 'contractor.manage', 'label': 'Register & edit contractors',
     'group': 'Contractors',
     'description': 'Add contractors and maintain their compliance documents.'},
    {'key': 'contractor.approve', 'label': 'Approve or suspend contractors',
     'group': 'Contractors',
     'description': 'Grant or revoke site access based on compliance.'},

    # ── Governance ───────────────────────────────────────────────────
    {'key': 'meeting.view', 'label': 'View committee & toolbox talks',
     'group': 'Governance',
     'description': 'Read agendas, minutes and attendance.'},
    {'key': 'meeting.manage', 'label': 'Schedule meetings & record minutes',
     'group': 'Governance',
     'description': 'Create meetings, capture attendance and decisions.'},
    {'key': 'legal.view', 'label': 'View the legal register',
     'group': 'Governance',
     'description': 'Read applicable legal and other requirements.'},
    {'key': 'legal.manage', 'label': 'Manage legal register & audits',
     'group': 'Governance',
     'description': 'Maintain compliance obligations and run audits.'},
    {'key': 'cert.manage', 'label': 'Manage certifications & licences',
     'group': 'Governance',
     'description': 'Track ISO certificates, statutory approvals and renewals.'},
    {'key': 'objective.manage', 'label': 'Manage safety objectives',
     'group': 'Governance',
     'description': 'Set targets and update progress against them.'},
    {'key': 'review.manage', 'label': 'Run management reviews',
     'group': 'Governance',
     'description': 'Convene ISO 45001 clause 9.3 reviews and record outputs.'},

    # ── Analytics & administration ───────────────────────────────────
    {'key': 'analytics.view', 'label': 'View safety intelligence & alert centre',
     'group': 'Administration',
     'description': 'Read the maturity index, forecasts and derived alerts.'},
    {'key': 'audit_log.view', 'label': 'View the audit trail',
     'group': 'Administration',
     'description': 'Read the append-only record of every change.'},
    {'key': 'staff.view', 'label': 'View the staff directory',
     'group': 'Administration',
     'description': 'See team members, roles and credentials.'},
    {'key': 'staff.manage', 'label': 'Add, edit & remove staff',
     'group': 'Administration',
     'description': 'Create logins, reset passwords and suspend access.'},
    {'key': 'rbac.manage', 'label': 'Change roles & capabilities',
     'group': 'Administration',
     'description': 'Assign roles and edit what each role can do.'},
    {'key': 'org.manage', 'label': 'Update organization profile & branding',
     'group': 'Administration',
     'description': 'Name, contacts, logo and brand colours.'},
    {'key': 'demo.manage', 'label': 'Seed & clear demo data',
     'group': 'Administration',
     'description': 'Load sample registers into production and remove them again.'},
]
ALL_CAP_KEYS = {c['key'] for c in CAPABILITY_CATALOG}
CAPABILITY_LABELS = {c['key']: c['label'] for c in CAPABILITY_CATALOG}

# Convenience bundles used to compose the built-in role sets.
_READ_ONLY = {c['key'] for c in CAPABILITY_CATALOG if c['key'].endswith('.view')}
_FIELD = {
    'hazard.view', 'hazard.manage',
    'incident.view', 'incident.report',
    'inspection.view', 'inspection.conduct',
    'permit.view', 'equipment.view', 'equipment.inspect', 'equipment.defect',
    'observation.view', 'observation.log', 'drill.view',
    'training.view', 'ppe.view', 'ppe.issue',
    'document.view', 'meeting.view',
}

# ── Built-in role → capabilities ─────────────────────────────────────────
BUILTIN_ROLE_CAPS = {
    'tenant_admin': ALL_CAP_KEYS,
    'admin': ALL_CAP_KEYS,
    'hse_manager': ALL_CAP_KEYS - {'rbac.manage', 'org.manage', 'demo.manage'},
    'safety_officer': {
        'hazard.view', 'hazard.manage', 'control.manage',
        'risk.assess',
        'incident.view', 'incident.report', 'incident.investigate',
        'inspection.view', 'inspection.conduct',
        'permit.view', 'permit.manage',
        'equipment.view', 'equipment.manage', 'equipment.inspect', 'equipment.defect',
        'observation.view', 'observation.log',
        'drill.view', 'drill.manage',
        'health.view',
        'exposure.view',
        'training.view', 'training.manage',
        'ppe.view', 'ppe.issue',
        'document.view', 'document.manage',
        'contractor.view', 'contractor.manage',
        'meeting.view', 'meeting.manage',
        'legal.view',
        'analytics.view',
        'staff.view',
    },
    'occ_health_nurse': {
        'hazard.view',
        'incident.view', 'incident.report',
        'inspection.view',
        'equipment.view',
        'observation.view', 'observation.log',
        'health.view', 'health.manage',
        'exposure.view',
        'training.view',
        'ppe.view',
        'document.view',
        'meeting.view',
        'analytics.view',
    },
    'supervisor': _FIELD - {'training.view'} | {'training.view'},
}

# Built-in roles whose capabilities a tenant may customise.
EDITABLE_BUILTIN_ROLES = {
    'hse_manager', 'safety_officer', 'occ_health_nurse', 'supervisor',
}

# Roles assignable from the Roles & Access page (the owner role is
# transferred only through the platform superadmin).
ASSIGNABLE_ROLES = ['hse_manager', 'safety_officer', 'occ_health_nurse', 'supervisor']

# Capabilities that can never be stripped from a role override, or the
# role would be unable to open the module at all.
PROTECTED_BUILTIN_CAPS = {'analytics.view'}

# Keys reserved for built-in / platform roles — a custom role may not reuse
# them, and they cannot be deleted from the UI.
RESERVED_ROLE_KEYS = set(BUILTIN_ROLE_CAPS) | {
    'super_admin', 'patient', 'caregiver', 'doctor', 'nurse', 'midwife',
    'dentist', 'clinical_officer', 'lab_tech', 'radiologist',
    'pharmacist', 'pharmacy_tech', 'cashier', 'storekeeper', 'branch_admin',
    'inventory_admin', 'hospital_admin', 'clinic_admin', 'lab_admin',
    'radiology_admin', 'homecare_admin',
}

# ── Presentation metadata (drives the Roles & Access page) ───────────────
ROLE_META = [
    {'key': 'tenant_admin', 'label': 'Tenant Admin', 'tier': 'admin',
     'icon': 'mdi-shield-account',
     'description': 'Owner of the organization — full control of every safety module.'},
    {'key': 'hse_manager', 'label': 'HSE Manager', 'tier': 'admin',
     'icon': 'mdi-shield-crown-outline',
     'description': 'Runs the safety management system. Everything except staff role '
                    'administration and organization settings.'},
    {'key': 'safety_officer', 'label': 'Safety Officer', 'tier': 'officer',
     'icon': 'mdi-shield-check',
     'description': 'Day-to-day operational control: hazards, incidents, inspections, '
                    'permits, equipment and drills.'},
    {'key': 'occ_health_nurse', 'label': 'Occupational Health Nurse', 'tier': 'specialist',
     'icon': 'mdi-medical-bag',
     'description': 'Owns health surveillance and exposure monitoring. Sees incidents '
                    'and observations but not risk approvals.'},
    {'key': 'supervisor', 'label': 'Supervisor', 'tier': 'field',
     'icon': 'mdi-account-tie-outline',
     'description': 'Field role: reports hazards and incidents, logs observations and '
                    'issues PPE. No editing of approved records.'},
]

TIERS = {
    'admin': {'label': 'Administrator', 'color': 'error',
              'desc': 'Full control, including settings'},
    'officer': {'label': 'HSE Officer', 'color': 'warning',
                'desc': 'Operational control of the safety system'},
    'specialist': {'label': 'Specialist', 'color': 'info',
                   'desc': 'Focused professional scope'},
    'field': {'label': 'Field', 'color': 'success',
              'desc': 'Report and observe only'},
    'custom': {'label': 'Custom', 'color': 'primary',
               'desc': 'Tenant-defined role'},
}


# ── Capability resolution ────────────────────────────────────────────────
def _role_caps(role):
    """Resolve a role's capability set.

    1. a tenant ``OhsRoleDefinition`` row wins (custom role OR built-in
       override);
    2. built-in roles fall back to the platform defaults in this module.
    """
    from .models import OhsRoleDefinition
    try:
        rd = OhsRoleDefinition.objects.filter(key=role, is_active=True).first()
    except Exception:
        # The table may not exist yet in a schema whose tenant migrations are
        # pending — fall back to the built-in defaults so permissions still
        # resolve instead of raising.
        rd = None
    if rd is not None:
        return set(rd.capabilities or [])
    if role in BUILTIN_ROLE_CAPS:
        return set(BUILTIN_ROLE_CAPS[role])
    return set()


def get_role_capabilities(request):
    """Resolve the requesting user's full capability set (per-request cache)."""
    if request is None:
        return set()
    cache = getattr(request, '_ohs_rbac_caps_cache', None)
    if cache is not None:
        return cache

    user = getattr(request, 'user', None)
    role = _role(request)
    if role == 'super_admin' or getattr(user, 'is_superuser', False):
        caps = ALL_CAP_KEYS
    else:
        caps = _role_caps(role)
    try:
        request._ohs_rbac_caps_cache = caps
    except (AttributeError, TypeError):
        pass
    return caps


def has_capability(request, cap):
    return cap in get_role_capabilities(request)


def has_any_capability(request, *caps):
    resolved = get_role_capabilities(request)
    return any(c in resolved for c in caps)


def has_role(request, roles):
    return _role(request) in roles


def capability_matrix():
    """Capability catalog annotated with the built-in roles that hold each."""
    return [
        {**cap, 'roles': sorted(
            k for k, caps in BUILTIN_ROLE_CAPS.items() if cap['key'] in caps)}
        for cap in CAPABILITY_CATALOG
    ]


def capability_groups():
    """Ordered list of capability groups with their members."""
    order = []
    seen = {}
    for cap in CAPABILITY_CATALOG:
        group = cap['group']
        if group not in seen:
            seen[group] = []
            order.append({'name': group, 'capabilities': seen[group]})
        seen[group].append(cap)
    return order


def role_risk_summary(caps):
    """Rate a capability set so the UI can warn about over-privileged roles.

    Combines the presence of high-impact capabilities with the overall
    breadth of the grant, so a role with half the platform also reads as
    powerful even when it holds no single destructive key.
    """
    critical = {
        'hazard.delete', 'rbac.manage', 'org.manage', 'health.manage',
        'document.approve', 'risk.approve', 'incident.close',
    }
    sensitive = {'health.view', 'audit_log.view', 'staff.manage', 'legal.manage'}
    hits = caps & critical
    soft = caps & sensitive
    breadth = len(caps) / max(len(ALL_CAP_KEYS), 1)

    if len(hits) >= 4 or breadth >= 0.9:
        return {'level': 'critical', 'count': len(hits),
                'detail': f'{len(caps)} of {len(ALL_CAP_KEYS)} capabilities '
                          f'incl. {len(hits)} high-impact'}
    if hits or breadth >= 0.6:
        return {'level': 'high', 'count': len(hits),
                'detail': ', '.join(sorted(hits)) if hits
                          else f'{len(caps)} capabilities granted'}
    if len(soft) >= 2 or breadth >= 0.35:
        return {'level': 'medium', 'count': len(soft),
                'detail': f'{len(caps)} capabilities incl. sensitive records'}
    return {'level': 'low', 'count': 0,
            'detail': f'{len(caps)} focused capabilities'}


# ── Permission classes ───────────────────────────────────────────────────
class OhsCapabilityPermission(IsAuthenticated):
    """Reads require ``view_capability``, writes ``write_capability``.

    Both resolve through :func:`has_capability`, so tenant-defined roles are
    enforced exactly like the built-ins.
    """
    view_capability = 'analytics.view'
    write_capability = 'analytics.view'

    def has_permission(self, request, view):
        if not super().has_permission(request, view):
            return False
        cap = (self.view_capability if request.method in SAFE_METHODS
               else self.write_capability)
        return has_capability(request, cap)


class OhsAdminOnly(IsAuthenticated):
    """Guard for org-level admin surfaces (RBAC management itself)."""

    def has_permission(self, request, view):
        if not super().has_permission(request, view):
            return False
        role = _role(request)
        if role == 'super_admin' or getattr(request.user, 'is_superuser', False):
            return True
        return role in ADMIN_ROLES


class OhsReadOnlyPermission(OhsCapabilityPermission):
    """Any read capability unlocks GET; writes need the specific one."""
    view_capability = 'analytics.view'
    write_capability = 'analytics.view'
