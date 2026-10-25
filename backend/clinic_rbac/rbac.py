"""Clinic Roles & Access (RBAC).

A clinic is not a warehouse and not a safety department. Its access model has
to answer a specific question: *who may touch a patient's record, and how far?*
A receptionist must register a patient but must not read a consultation note; a
lab technologist must enter results but must not authorise them; a cashier must
take money but must not refund it.

This module defines that grid: a capability catalogue grouped by the clinic's
own modules, the platform defaults for every built-in role, and the helpers the
API and the UI share so they can never disagree.
"""

# ── Role groups ──────────────────────────────────────────────────────────
ADMIN_ROLES = {'super_admin', 'tenant_admin', 'clinic_admin', 'admin'}
CLINICAL_ROLES = {'doctor', 'clinical_officer', 'dentist'}
NURSING_ROLES = {'nurse', 'midwife'}
SPECIALIST_ROLES = {'lab_tech', 'radiologist', 'pharmacist'}
FRONT_OFFICE_ROLES = {'receptionist', 'cashier'}


def _role(request):
    return getattr(getattr(request, 'user', None), 'role', '') or ''


# ── Capability catalogue (drives the Roles & Access page) ─────────────────
#
# Ordering matters: groups render in the order their first capability appears,
# and capabilities render in catalogue order inside a group.
CAPABILITY_CATALOG = [
    # ── Patients ─────────────────────────────────────────────────────
    {'key': 'patient.view', 'label': 'Open a patient record',
     'group': 'Patients',
     'description': 'Read demographics, allergies, chronic conditions and history.'},
    {'key': 'patient.create', 'label': 'Register new patients',
     'group': 'Patients',
     'description': 'Add a walk-in or a portal patient and issue a patient number.'},
    {'key': 'patient.edit', 'label': 'Edit patient details',
     'group': 'Patients',
     'description': 'Correct demographics, contacts, allergies and next of kin.'},
    {'key': 'patient.delete', 'label': 'Delete patient records',
     'group': 'Patients',
     'description': 'Destructive — archiving is almost always the right action instead.'},
    {'key': 'patient.export', 'label': 'Export patient data',
     'group': 'Patients',
     'description': 'Download patient lists and clinical data outside the clinic.'},

    # ── Appointments ─────────────────────────────────────────────────
    {'key': 'appointment.view', 'label': 'View the appointment book',
     'group': 'Appointments',
     'description': 'Read the day, week and per-clinician schedules.'},
    {'key': 'appointment.create', 'label': 'Book appointments',
     'group': 'Appointments',
     'description': 'Create a booking for a patient and a clinician.'},
    {'key': 'appointment.edit', 'label': 'Reschedule & edit bookings',
     'group': 'Appointments',
     'description': 'Move a booking or change its type and clinician.'},
    {'key': 'appointment.cancel', 'label': 'Cancel appointments',
     'group': 'Appointments',
     'description': 'Cancel a booking and free the slot.'},

    # ── Front desk ───────────────────────────────────────────────────
    {'key': 'frontdesk.view', 'label': 'Use the front desk',
     'group': 'Front desk',
     'description': 'See today\'s arrivals, the queue and the visit board.'},
    {'key': 'frontdesk.queue', 'label': 'Manage the waiting queue',
     'group': 'Front desk',
     'description': 'Check patients in, call them forward and reorder the queue.'},
    {'key': 'visit.create', 'label': 'Open a visit',
     'group': 'Front desk',
     'description': 'Start a new visit so the patient can be triaged and seen.'},
    {'key': 'visit.close', 'label': 'Discharge & close visits',
     'group': 'Front desk',
     'description': 'Complete a visit once the patient has been seen and settled.'},

    # ── Clinical encounters ──────────────────────────────────────────
    {'key': 'consult.view', 'label': 'Read consultation notes',
     'group': 'Clinical encounters',
     'description': 'Clinical notes, diagnoses, examination findings and history.'},
    {'key': 'consult.record', 'label': 'Record a consultation',
     'group': 'Clinical encounters',
     'description': 'Write notes, diagnoses, examination findings and advice.'},
    {'key': 'consult.finalise', 'label': 'Close a consultation',
     'group': 'Clinical encounters',
     'description': 'Sign off the encounter so it becomes part of the record.'},
    {'key': 'consult.amend', 'label': 'Amend a closed consultation',
     'group': 'Clinical encounters',
     'description': 'Reopen and correct a signed encounter — every change is audited.'},

    # ── Triage & vitals ──────────────────────────────────────────────
    {'key': 'triage.view', 'label': 'View triage assessments',
     'group': 'Triage & vitals',
     'description': 'Read triage category, presenting complaint and urgency.'},
    {'key': 'triage.record', 'label': 'Triage patients',
     'group': 'Triage & vitals',
     'description': 'Set the triage category and record the presenting complaint.'},
    {'key': 'vitals.view', 'label': 'View vital signs',
     'group': 'Triage & vitals',
     'description': 'Read blood pressure, temperature, weight and trends.'},
    {'key': 'vitals.record', 'label': 'Record vital signs',
     'group': 'Triage & vitals',
     'description': 'Capture a new set of observations for a patient.'},

    # ── Prescriptions ────────────────────────────────────────────────
    {'key': 'prescription.view', 'label': 'View prescriptions',
     'group': 'Prescriptions',
     'description': 'Read what a clinician prescribed and its status.'},
    {'key': 'prescription.create', 'label': 'Prescribe medication',
     'group': 'Prescriptions',
     'description': 'Write a prescription with dose, route and duration.'},
    {'key': 'prescription.void', 'label': 'Void a prescription',
     'group': 'Prescriptions',
     'description': 'Withdraw a prescription that is still open.'},

    # ── Laboratory ───────────────────────────────────────────────────
    {'key': 'lab.view', 'label': 'View lab orders & results',
     'group': 'Laboratory',
     'description': 'See the bench list, order status and entered results.'},
    {'key': 'lab.order', 'label': 'Order laboratory tests',
     'group': 'Laboratory',
     'description': 'Request tests for a patient from the clinic catalogue.'},
    {'key': 'lab.result', 'label': 'Enter laboratory results',
     'group': 'Laboratory',
     'description': 'Record analyte values, units and comments on the bench.'},
    {'key': 'lab.verify', 'label': 'Authorise lab reports',
     'group': 'Laboratory',
     'description': 'Sign off a completed order so the report can be released.'},
    {'key': 'lab.config', 'label': 'Manage the test catalogue',
     'group': 'Laboratory',
     'description': 'Add tests and panels, set prices and reference ranges.'},

    # ── Radiology ────────────────────────────────────────────────────
    {'key': 'radiology.view', 'label': 'View imaging requests',
     'group': 'Radiology',
     'description': 'Read requests, reports and linked images.'},
    {'key': 'radiology.order', 'label': 'Request imaging',
     'group': 'Radiology',
     'description': 'Order an X-ray, ultrasound or other study.'},
    {'key': 'radiology.report', 'label': 'Write imaging reports',
     'group': 'Radiology',
     'description': 'Record findings and impression for a study.'},

    # ── Pharmacy & stock ─────────────────────────────────────────────
    {'key': 'pharmacy.view', 'label': 'View the drug store',
     'group': 'Pharmacy & stock',
     'description': 'See stock on hand, batches and expiries.'},
    {'key': 'pharmacy.dispense', 'label': 'Dispense medication',
     'group': 'Pharmacy & stock',
     'description': 'Issue a prescription against stock and record the handover.'},
    {'key': 'stock.manage', 'label': 'Manage stock & batches',
     'group': 'Pharmacy & stock',
     'description': 'Receive stock, adjust quantities and record wastage.'},
    {'key': 'stock.cost', 'label': 'See purchase costs & margins',
     'group': 'Pharmacy & stock',
     'description': 'Buying price, margin and stock valuation.'},

    # ── Billing & payments ───────────────────────────────────────────
    {'key': 'billing.view', 'label': 'View invoices & payments',
     'group': 'Billing & payments',
     'description': 'Read what a patient was charged and what they paid.'},
    {'key': 'billing.invoice', 'label': 'Raise invoices',
     'group': 'Billing & payments',
     'description': 'Create an invoice from services rendered.'},
    {'key': 'billing.payment', 'label': 'Take payments',
     'group': 'Billing & payments',
     'description': 'Record cash, card or mobile-money payments against an invoice.'},
    {'key': 'billing.refund', 'label': 'Issue refunds & waivers',
     'group': 'Billing & payments',
     'description': 'Reverse a payment or waive a charge.'},
    {'key': 'billing.corporate', 'label': 'Manage corporate schemes',
     'group': 'Billing & payments',
     'description': 'Set up employer schemes, rosters and eligibility.'},

    # ── Catalogue & clinical config ──────────────────────────────────
    {'key': 'catalog.view', 'label': 'View clinical catalogues',
     'group': 'Catalogue & clinical config',
     'description': 'Read medications, allergies, chronic conditions and units.'},
    {'key': 'catalog.manage', 'label': 'Maintain clinical catalogues',
     'group': 'Catalogue & clinical config',
     'description': 'Add or retire catalogue entries used across the clinic.'},

    # ── Communication ────────────────────────────────────────────────
    {'key': 'message.view', 'label': 'Read messages',
     'group': 'Communication',
     'description': 'Open clinic threads with staff and patients.'},
    {'key': 'message.send', 'label': 'Send messages',
     'group': 'Communication',
     'description': 'Reply in a thread or start a new one.'},
    {'key': 'alert.view', 'label': 'See operational alerts',
     'group': 'Communication',
     'description': 'Low stock, overdue results and escalation notices.'},

    # ── Reporting ────────────────────────────────────────────────────
    {'key': 'analytics.view', 'label': 'View clinic analytics',
     'group': 'Reporting',
     'description': 'Patient flow, clinician activity, revenue and turnaround.'},
    {'key': 'analytics.export', 'label': 'Export reports',
     'group': 'Reporting',
     'description': 'Download analytics and register extracts.'},

    # ── Compliance & privacy ─────────────────────────────────────────
    {'key': 'consent.view', 'label': 'View patient consents',
     'group': 'Compliance & privacy',
     'description': 'Read what a patient has agreed to.'},
    {'key': 'consent.manage', 'label': 'Record patient consents',
     'group': 'Compliance & privacy',
     'description': 'Capture, renew or withdraw a consent.'},
    {'key': 'datasharing.view', 'label': 'View data-sharing settings',
     'group': 'Compliance & privacy',
     'description': 'See which categories of a patient\'s record are shared.'},
    {'key': 'datasharing.manage', 'label': 'Change data-sharing settings',
     'group': 'Compliance & privacy',
     'description': 'Decide what a patient sees on their own dashboard.'},
    {'key': 'audit.view', 'label': 'Read the audit log',
     'group': 'Compliance & privacy',
     'description': 'Every change to a clinical or financial record, by whom.'},

    # ── Administration ───────────────────────────────────────────────
    {'key': 'staff.view', 'label': 'View the staff directory',
     'group': 'Administration',
     'description': 'Read who works at the clinic, their role and workload.'},
    {'key': 'staff.manage', 'label': 'Add & remove staff',
     'group': 'Administration',
     'description': 'Create clinic logins, reset passwords and suspend access.'},
    {'key': 'clinic.settings', 'label': 'Change clinic settings',
     'group': 'Administration',
     'description': 'Name, contacts, opening hours and billing defaults.'},
    {'key': 'clinic.branding', 'label': 'Change branding',
     'group': 'Administration',
     'description': 'Logo and brand colours used on documents and the portal.'},
    {'key': 'site.manage', 'label': 'Manage clinic sites',
     'group': 'Administration',
     'description': 'Add branches and assign staff to a site.'},
    {'key': 'department.manage', 'label': 'Manage departments',
     'group': 'Administration',
     'description': 'Create the departments services are grouped under.'},
    {'key': 'rbac.manage', 'label': 'Manage roles & access',
     'group': 'Administration',
     'description': 'Assign roles and decide what each role may do.'},
    {'key': 'demo.manage', 'label': 'Seed & clear demo data',
     'group': 'Administration',
     'description': 'Load sample records into the clinic and remove them again.'},
]

ALL_CAP_KEYS = {c['key'] for c in CAPABILITY_CATALOG}
CAPABILITY_LABELS = {c['key']: c['label'] for c in CAPABILITY_CATALOG}

#: Every capability that only reads. Handy for composing the front-office roles.
_READ_ONLY = {c['key'] for c in CAPABILITY_CATALOG if c['key'].endswith('.view')}

# ── Capability bundles ───────────────────────────────────────────────────
# Composing roles from named bundles keeps the defaults readable and makes it
# obvious what a role is *for*, instead of a wall of keys.
_PATIENT_READ = {'patient.view'}
_PATIENT_WRITE = _PATIENT_READ | {'patient.create', 'patient.edit'}
_BOOKING = {
    'appointment.view', 'appointment.create', 'appointment.edit',
    'appointment.cancel',
}
_FRONT_DESK = {
    'frontdesk.view', 'frontdesk.queue', 'visit.create', 'visit.close',
}
_CLINICAL_READ = {
    'consult.view', 'triage.view', 'vitals.view', 'prescription.view',
    'lab.view', 'radiology.view',
}
_CLINICAL_WRITE = {
    'consult.record', 'consult.finalise', 'triage.record', 'vitals.record',
    'prescription.create', 'lab.order', 'radiology.order',
}
_NURSING = {
    'triage.record', 'vitals.record', 'frontdesk.queue', 'visit.create',
}
_COMMS = {'message.view', 'message.send', 'alert.view'}


# ── Built-in role → capabilities ─────────────────────────────────────────
BUILTIN_ROLE_CAPS = {
    # Owners. These are platform-managed and cannot be restricted.
    'tenant_admin': ALL_CAP_KEYS,
    'clinic_admin': ALL_CAP_KEYS,
    'admin': ALL_CAP_KEYS,

    # A site lead runs the building, but does not own the brand or the
    # destructive patient actions.
    'branch_admin': ALL_CAP_KEYS - {
        'patient.delete', 'rbac.manage', 'clinic.branding', 'demo.manage',
    },

    # ── Clinical ──
    'doctor': (
        _PATIENT_WRITE | _BOOKING | _CLINICAL_READ | _CLINICAL_WRITE
        | {'consult.amend', 'prescription.void', 'pharmacy.view', 'stock.cost',
           'billing.view', 'catalog.view', 'analytics.view',
           'consent.view', 'datasharing.view', 'staff.view', 'lab.verify'}
        | _COMMS
    ),
    'clinical_officer': (
        _PATIENT_WRITE | _BOOKING | _CLINICAL_READ | _CLINICAL_WRITE
        | {'prescription.void', 'pharmacy.view', 'billing.view',
           'catalog.view', 'consent.view', 'datasharing.view', 'staff.view'}
        | _COMMS
    ),
    'dentist': (
        _PATIENT_WRITE | _BOOKING | _CLINICAL_READ | _CLINICAL_WRITE
        | {'pharmacy.view', 'billing.view', 'catalog.view', 'consent.view',
           'staff.view'}
        | _COMMS
    ),

    # ── Nursing ──
    'nurse': (
        _PATIENT_WRITE | _BOOKING | _CLINICAL_READ | _NURSING
        | {'lab.order', 'pharmacy.view', 'billing.view', 'catalog.view',
           'triage.view', 'consent.view'}
        | _COMMS
    ),
    'midwife': (
        _PATIENT_WRITE | _BOOKING | _CLINICAL_READ | _NURSING
        | {'consult.record', 'lab.order', 'pharmacy.view', 'billing.view',
           'catalog.view', 'consent.view'}
        | _COMMS
    ),

    # ── Specialists ──
    'lab_tech': (
        _PATIENT_READ
        | {'lab.view', 'lab.order', 'lab.result', 'lab.verify', 'lab.config',
           'appointment.view', 'consult.view', 'catalog.view', 'analytics.view',
           'pharmacy.view'}
        | _COMMS
    ),
    'radiologist': (
        _PATIENT_READ
        | {'radiology.view', 'radiology.order', 'radiology.report',
           'appointment.view', 'consult.view', 'analytics.view'}
        | _COMMS
    ),
    'pharmacist': (
        _PATIENT_READ
        | {'prescription.view', 'pharmacy.view', 'pharmacy.dispense',
           'stock.manage', 'stock.cost', 'catalog.view', 'billing.view',
           'analytics.view'}
        | _COMMS
    ),

    # ── Front office ──
    'pharmacy_tech': (
        _PATIENT_READ
        | {'prescription.view', 'pharmacy.view', 'pharmacy.dispense',
           'catalog.view', 'alert.view'}
    ),
    'receptionist': (
        _PATIENT_WRITE | _BOOKING | _FRONT_DESK
        | {'billing.view', 'billing.invoice', 'billing.payment',
           'lab.view', 'lab.order', 'radiology.view', 'catalog.view',
           'message.view', 'message.send', 'alert.view'}
    ),
    'cashier': (
        _PATIENT_READ
        | {'frontdesk.view', 'billing.view', 'billing.invoice',
           'billing.payment', 'billing.refund', 'message.view', 'alert.view'}
    ),
}

# Built-in roles whose capabilities this clinic may customise. The owner roles
# are deliberately excluded — they are an entitlement of the subscription.
EDITABLE_BUILTIN_ROLES = {
    'branch_admin', 'doctor', 'clinical_officer', 'dentist', 'nurse', 'midwife',
    'lab_tech', 'radiologist', 'pharmacist', 'pharmacy_tech', 'receptionist',
    'cashier',
}

# Roles assignable from the Roles & Access page.
ASSIGNABLE_ROLES = [
    'clinic_admin', 'branch_admin', 'doctor', 'clinical_officer', 'dentist',
    'nurse', 'midwife', 'lab_tech', 'radiologist', 'pharmacist',
    'pharmacy_tech', 'receptionist', 'cashier',
]

# Capabilities that can never be stripped from a role, or the person could not
# open a single record.
PROTECTED_BUILTIN_CAPS = {'patient.view'}

# Keys reserved for built-in / platform roles — a custom role may not reuse
# them, and they cannot be deleted from the UI.
RESERVED_ROLE_KEYS = set(BUILTIN_ROLE_CAPS) | {
    'super_admin', 'patient', 'caregiver', 'supervisor',
    'hospital_admin', 'pharmacy_admin', 'lab_admin', 'radiology_admin',
    'inventory_admin', 'homecare_admin', 'storekeeper',
    'hse_manager', 'safety_officer', 'occ_health_nurse',
}

# ── Presentation metadata (drives the Roles & Access page) ───────────────
ROLE_META = [
    {'key': 'tenant_admin', 'label': 'Clinic Owner', 'tier': 'admin',
     'icon': 'mdi-shield-account',
     'description': 'Owns the clinic. Full control of every module — '
                    'platform-managed and cannot be restricted.'},
    {'key': 'clinic_admin', 'label': 'Clinic Manager', 'tier': 'admin',
     'icon': 'mdi-shield-crown-outline',
     'description': 'Runs the clinic day to day with full clinical and '
                    'financial access.'},
    {'key': 'branch_admin', 'label': 'Site Lead', 'tier': 'admin',
     'icon': 'mdi-source-branch',
     'description': 'Runs one site. Everything except branding, role '
                    'administration and deleting patient records.'},
    {'key': 'doctor', 'label': 'Doctor', 'tier': 'clinical',
     'icon': 'mdi-doctor',
     'description': 'Full clinical scope: sees patients, prescribes, orders '
                    'tests and can authorise lab reports.'},
    {'key': 'clinical_officer', 'label': 'Clinical Officer', 'tier': 'clinical',
     'icon': 'mdi-stethoscope',
     'description': 'Same patient-facing scope as a doctor, without amending a '
                    'closed encounter.'},
    {'key': 'dentist', 'label': 'Dentist', 'tier': 'clinical',
     'icon': 'mdi-tooth-outline',
     'description': 'Clinical scope focused on dental encounters.'},
    {'key': 'nurse', 'label': 'Nurse', 'tier': 'nursing',
     'icon': 'mdi-hand-heart',
     'description': 'Triages, records observations and opens visits. Reads '
                    'prescriptions but cannot write them.'},
    {'key': 'midwife', 'label': 'Midwife', 'tier': 'nursing',
     'icon': 'mdi-human-pregnant',
     'description': 'Maternity-focused nursing scope with the ability to '
                    'record consultations.'},
    {'key': 'lab_tech', 'label': 'Lab Technologist', 'tier': 'specialist',
     'icon': 'mdi-test-tube',
     'description': 'Owns the bench: enters and authorises results, maintains '
                    'the test catalogue.'},
    {'key': 'radiologist', 'label': 'Radiologist', 'tier': 'specialist',
     'icon': 'mdi-radiobox-marked',
     'description': 'Imaging only — requests studies and writes the report.'},
    {'key': 'pharmacist', 'label': 'Pharmacist', 'tier': 'specialist',
     'icon': 'mdi-pill',
     'description': 'Dispenses prescriptions and manages drug stock and cost.'},
    {'key': 'pharmacy_tech', 'label': 'Pharmacy Technician', 'tier': 'specialist',
     'icon': 'mdi-pill-multiple',
     'description': 'Dispenses against stock but cannot adjust quantities or '
                    'see purchase cost.'},
    {'key': 'receptionist', 'label': 'Receptionist', 'tier': 'front_office',
     'icon': 'mdi-deskphone',
     'description': 'Registers patients, books appointments, runs the queue '
                    'and raises invoices.'},
    {'key': 'cashier', 'label': 'Cashier', 'tier': 'front_office',
     'icon': 'mdi-cash-register',
     'description': 'Handles money only: invoices, payments and refunds. No '
                    'clinical access.'},
]

TIERS = {
    'admin': {'label': 'Administrator', 'color': 'error',
              'desc': 'Full control of the clinic'},
    'clinical': {'label': 'Clinician', 'color': 'primary',
                 'desc': 'Sees and treats patients'},
    'nursing': {'label': 'Nursing', 'color': 'info',
                'desc': 'Observations and patient flow'},
    'specialist': {'label': 'Specialist', 'color': 'warning',
                   'desc': 'One discipline, deeply'},
    'front_office': {'label': 'Front office', 'color': 'success',
                     'desc': 'Reception and cashiering'},
    'custom': {'label': 'Custom', 'color': 'secondary',
               'desc': 'Clinic-defined role'},
}


# ── Capability resolution ────────────────────────────────────────────────
def role_caps(role):
    """Resolve a role's capability set.

    1. a tenant ``ClinicRoleDefinition`` row wins (custom role OR built-in
       override);
    2. built-in roles fall back to the platform defaults in this module.
    """
    from .models import ClinicRoleDefinition

    try:
        definition = ClinicRoleDefinition.objects.filter(
            key=role, is_active=True).first()
    except Exception:  # noqa: BLE001
        # The table may not exist yet in a schema whose tenant migrations are
        # still pending — fall back to defaults rather than raising.
        definition = None
    if definition is not None:
        return set(definition.capabilities or [])
    if role in BUILTIN_ROLE_CAPS:
        return set(BUILTIN_ROLE_CAPS[role])
    return set()


def get_role_capabilities(request):
    """Resolve the requesting user's full capability set (per-request cache)."""
    if request is None:
        return set()
    cached = getattr(request, '_clinic_rbac_caps_cache', None)
    if cached is not None:
        return cached

    user = getattr(request, 'user', None)
    role = _role(request)
    if role == 'super_admin' or getattr(user, 'is_superuser', False):
        caps = set(ALL_CAP_KEYS)
    else:
        caps = role_caps(role)
    try:
        request._clinic_rbac_caps_cache = caps
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
    """Capability catalogue annotated with the built-in roles that hold each."""
    return [
        {**cap, 'roles': sorted(
            key for key, caps in BUILTIN_ROLE_CAPS.items()
            if cap['key'] in caps)}
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


#: Capabilities that can destroy data, move money, or hand data outside the
#: clinic. Holding one of these is what makes a role genuinely dangerous.
CRITICAL_CAPS = {
    'patient.delete', 'patient.export', 'billing.refund', 'rbac.manage',
    'clinic.branding', 'demo.manage', 'datasharing.manage',
}

#: Capabilities that touch the record or the till in a way that needs care, but
#: are a normal part of the job for the role that holds them. A doctor amending
#: a note is expected; a receptionist amending one is not.
SENSITIVE_CAPS = {
    'consult.amend', 'prescription.void', 'lab.verify', 'stock.manage',
    'stock.cost', 'audit.view', 'consent.manage', 'staff.manage',
    'billing.view', 'patient.edit', 'consult.view', 'clinic.settings',
    'visit.close',
}


def role_risk_summary(caps):
    """Rate a capability set so the UI can warn about over-privileged roles.

    Two independent signals are combined:

    * **impact** — does the role hold anything destructive (money, deletion,
      export, role administration)?
    * **breadth** — how much of the clinic does it span?

    Weighting breadth low and impact high keeps a clinician's ordinary
    authority out of the red, while still flagging a role that could, say,
    delete patients *and* move money.
    """
    caps = set(caps or [])
    critical = sorted(caps & CRITICAL_CAPS)
    sensitive = sorted(caps & SENSITIVE_CAPS)
    total = max(1, len(ALL_CAP_KEYS))
    breadth = len(caps) / total

    score = len(critical) * 5 + len(sensitive)
    if breadth >= 0.9:
        score += 6
    elif breadth >= 0.75:
        score += 4
    elif breadth >= 0.5:
        score += 1

    if score >= 14:
        level = 'critical'
    elif score >= 8:
        level = 'high'
    elif score >= 3:
        level = 'medium'
    else:
        level = 'low'

    if critical:
        detail = (f'{len(critical)} destructive capabilit'
                  f'{"y" if len(critical) == 1 else "ies"} across '
                  f'{round(breadth * 100)}% of the clinic')
    elif sensitive:
        detail = (f'No destructive access, but {len(sensitive)} sensitive '
                  f'capabilit{"y" if len(sensitive) == 1 else "ies"}')
    else:
        detail = 'Task-focused access with no destructive powers'

    return {
        'level': level,
        'count': len(caps),
        'breadth_pct': round(breadth * 100),
        'critical': critical,
        'sensitive': sensitive,
        'detail': detail,
    }
