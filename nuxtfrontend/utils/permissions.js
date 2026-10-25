// Role-based route access rules.
// Restricts low-privilege roles (e.g. cashier) from admin/management screens.

// Routes that should ONLY be accessible to tenant/super admins.
// Anyone else hitting these will be redirected to /dashboard (or /pharmacy for pharmacy tenants).
const ADMIN_ONLY_PREFIXES = [
  '/superadmin',
  '/admin',
  '/staff',
  '/staff-performance',
  '/specializations',
  '/accounts',
  '/branches',
  '/settings',
  '/suppliers',
  '/purchase-orders',
  '/expenses',
  '/expenses/categories',
  '/expenses/new',
  '/reports',
  '/analytics',
  '/billing/usage',
  '/billing/rates',
  '/billing/doctors',
  '/pharmacy/billing',
  '/pharmacy/staff',
  '/pharmacy/staff-performance',
  '/pharmacy/specializations',
  '/pharmacy/accounts',
  '/pharmacy/branches',
  '/pharmacy/settings',
  '/pharmacy/suppliers',
  '/pharmacy/purchase-orders',
  '/pharmacy/expenses',
  '/pharmacy/reports',
  '/pharmacy/analytics',
  '/pharmacy/inventory/stock-analysis',
  '/pharmacy/adjustments',
  '/pharmacy/categories',
  '/pharmacy/units',
  '/pharmacy/medications',
  '/pharmacy/rbac',
  '/inventory/stock-analysis',
  '/adjustments',
  '/categories',
  '/units',
  '/medications',
  '/departments',
  '/wards',
  '/doctor-profile',
  '/radiology/staff',
  '/radiology/accounts',
  '/radiology/settings',
  '/radiology/branches',
  '/radiology/analytics',
  '/radiology/expenses',
  // Hospital namespaced admin-only routes
  '/hos/staff',
  '/hos/accounts',
  '/hos/departments',
  '/hos/wards',
  '/hos/doctor-profile',
  '/hos/billing/usage',
  '/hos/billing/commission',
  '/hos/radiology/staff',
  '/hos/radiology/accounts',
  '/hos/radiology/settings',
  '/hos/radiology/branches',
  '/hos/radiology/analytics',
  '/hos/radiology/expenses',
  // Clinic namespaced admin-only routes
  '/clinics/staff',
  '/clinics/rbac',
  '/clinics/accounts',
  '/clinics/sites',
  '/clinics/departments',
  '/clinics/drug-stores',
  '/clinics/wards',
  '/clinics/doctor-profile',
  '/clinics/billing/usage',
  '/clinics/settings',
  '/clinics/organization',
  '/clinics/billing/commission',
  // Clinic catalog (mirrors the IMS /ims catalog admin-only routes)
  '/clinics/catalog',
  // Inventory-tenant namespaced admin-only routes
  '/ims/accounts',
  '/ims/branches',
  '/ims/settings',
  '/ims/setup',
  '/ims/staff',
  '/ims/audit-logs',
  '/ims/suppliers',
  '/ims/purchase-orders',
  '/ims/expenses',
  '/ims/reports',
  '/ims/analytics',
  '/ims/billing/usage',
  '/ims/inventory/stock-analysis',
  '/ims/organization',
  '/ims/medications',
  '/ims/rbac',
  '/ims/adjustments',
  '/ims/categories',
  '/ims/units',
  '/ohs/organization',
]

// Roles considered "admins" of their tenant.
export const ADMIN_ROLES = new Set([
  'super_admin',
  'tenant_admin',
  'hospital_admin',
  'clinic_admin',
  'pharmacy_admin',
  'lab_admin',
  'radiology_admin',
  'inventory_admin',
  'hse_manager',
  'safety_officer',
  'occ_health_nurse',
  'branch_admin',
  'admin',
])

// Per-role allow-list of route prefixes. If a role is listed here, only
// routes that start with one of these prefixes (plus the always-allowed
// list) are accessible. Roles not listed fall back to the admin rules.
const ROLE_ALLOWLIST = {
  branch_admin: [
    '/dashboard',
    '/pharmacy',
    '/pos',
    '/pharmacy-orders',
    '/pharmacy-rx',
    '/dispensing',
    '/customers',
    '/billing',
    '/invoices',
    '/alerts',
    '/messages',
    '/my-profile',
    '/notifications',
    '/profile',
    '/inventory',
    '/pharmacy/inventory',
    '/pharmacy/pos',
    '/pharmacy/staff',
    '/pharmacy/staff-performance',
    '/pharmacy/reports',
    '/pharmacy/adjustments',
    '/pharmacy/categories',
    '/pharmacy/units',
    '/pharmacy/medications',
    '/pharmacy/expenses',
    '/pharmacy/suppliers',
    '/pharmacy/purchase-orders',
    // Inventory tenant namespace equivalents
    '/ims',
    '/ims/pos',
    '/ims/sales-orders',
    '/ims/credit',
    '/ims/customers',
    '/ims/deliveries',
    '/ims/inventory',
    '/ims/alerts',
    '/ims/reports',
    '/ims/adjustments',
    '/ims/categories',
    '/ims/units',
    '/ims/medications',
  ],
  cashier: [
    '/dashboard',
    // Clinic tenant — reception / billing desk access
    '/clinics/front-desk',
    '/clinics/patients',
    '/clinics/invoices',
    '/clinics/corporate',
    '/clinics/triage',
    '/clinics/lab-orders',
    '/clinics/prescriptions',
    '/hos',
    '/hos/patients',
    '/hos/appointments',
    '/hos/consultations',
    '/hos/prescriptions',
    '/hos/lab-orders',
    '/hos/triage',
    '/hos/invoices',
    '/hos/billing',
    '/hos/billing/commission',
    '/hos/messages',
    '/hos/my-profile',
    '/hos/my-prescriptions',
    '/pharmacy',
    '/pos',
    '/pharmacy-orders',
    '/pharmacy-rx',
    '/dispensing',
    '/customers',
    '/billing',            // own till/billing screen, NOT /billing/usage
    '/invoices',           // invoice management
    '/alerts',
    '/messages',
    '/my-profile',
    '/notifications',
    '/profile',
    // Inventory tenant namespace — POS & sales for warehouse cashiers
    '/ims',
    '/ims/pos',
    '/ims/pos/history',
    '/ims/pos/parked',
    '/ims/pos/shifts',
    '/ims/pos/supermarket',
    '/ims/sales-orders',
    '/ims/credit',
    '/ims/customers',
    '/ims/deliveries',
    '/ims/inventory',
    '/ims/inventory/stocks',
    '/ims/alerts',
    '/ims/messages',
    '/ims/my-profile',
  ],
  storekeeper: [
    '/dashboard',
    '/ims',
    '/ims/inventory',
    '/ims/alerts',
    '/ims/categories',
    '/ims/units',
    '/ims/adjustments',
    '/ims/inventory/stock-take',
    '/ims/inventory/stock-movements',
    '/ims/inventory/transfers',
    '/ims/inventory/controlled-register',
    '/ims/purchase-orders',
    '/ims/suppliers',
    '/ims/branches',
    // Sales (dispatch desk)
    '/ims/pos',
    '/ims/pos/history',
    '/ims/pos/parked',
    '/ims/pos/shifts',
    '/ims/pos/supermarket',
    '/ims/sales-orders',
    '/ims/customers',
    '/ims/credit',
    '/ims/deliveries',
    '/alerts',
    '/messages',
    '/my-profile',
    '/notifications',
    '/profile',
  ],
}

// Per-role deny-list of route prefixes. Checked BEFORE the allow-list so
// you can grant a broad area (e.g. /pharmacy) but block sub-pages.
const ROLE_DENYLIST = {
  branch_admin: [
    '/billing/usage',
    '/billing/rates',
    '/pharmacy/billing',
    '/pharmacy/branches',
    '/pharmacy/settings',
    '/pharmacy/rbac',
    // Inventory tenant namespace equivalents
    '/ims/billing',
    '/ims/branches',
    '/ims/settings',
    '/ims/organization',
    '/ims/setup',
    '/ims/staff',
    '/ims/rbac',
    '/ims/audit-logs',
    '/ims/system-health',
  ],
  cashier: [
    '/billing/usage',     // API Billing — admin only
    '/billing/rates',
    '/billing/doctors',
    '/billing/commission',
    '/pharmacy/billing',
    '/pharmacy/staff',
    '/pharmacy/staff-performance',
    '/pharmacy/specializations',
    '/pharmacy/accounts',
    '/pharmacy/branches',
    '/pharmacy/settings',
    '/pharmacy/suppliers',
    '/pharmacy/purchase-orders',
    '/pharmacy/expenses',
    '/pharmacy/reports',
    '/pharmacy/analytics',
    '/pharmacy/rbac',
    '/pharmacy/inventory/stock-analysis',
    '/pharmacy/inventory/stock-take',
    '/pharmacy/inventory/transfers',
    '/pharmacy/referral',
    '/pharmacy/adjustments',
    '/pharmacy/categories',
    '/pharmacy/units',
    '/pharmacy/medications',
    // Inventory tenant namespace equivalents
    '/ims/billing',
    '/ims/staff',
    '/ims/settings',
    '/ims/setup',
    '/ims/organization',
    '/ims/accounts',
    '/ims/invoices',
    '/ims/expenses',
    '/ims/analytics',
    '/ims/reports',
    '/ims/suppliers',
    '/ims/purchase-orders',
    '/ims/audit-logs',
    '/ims/system-health',
    '/ims/rbac',
    '/ims/inventory/stock-analysis',
    '/ims/inventory/stock-take',
    '/ims/inventory/transfers',
    '/ims/inventory/controlled-register',
    '/ims/adjustments',
    '/ims/categories',
    '/ims/units',
    '/ims/medications',
    '/ims/branches',
  ],
  storekeeper: [
    // Admin-only areas of the IMS namespace
    '/ims/billing',
    '/ims/staff',
    '/ims/settings',
    '/ims/setup',
    '/ims/organization',
    '/ims/accounts',
    '/ims/invoices',
    '/ims/expenses',
    '/ims/analytics',
    '/ims/reports',
    '/ims/audit-logs',
    '/ims/system-health',
    '/ims/rbac',
    '/ims/inventory/stock-analysis',
  ],
  pharmacist: [
    '/pharmacy/inventory/stock-take',
    '/pharmacy/inventory/transfers',
    '/pharmacy/referral',
  ],
  pharmacy_tech: [
    '/pharmacy/inventory/stock-take',
    '/pharmacy/inventory/transfers',
    '/pharmacy/referral',
  ],
}

// Roles & Access is capability-gated on the server (`rbac.manage` or
// `staff.view`). The bare `/clinics` entry in ALWAYS_ALLOWED would otherwise
// let every clinic user open the page and hit an empty 403, so those roles are
// denied here — the deny-list is checked before ALWAYS_ALLOWED.
//
// Clinical roles (doctor / clinical_officer / dentist) already never receive
// the SECURITY & SETTINGS section, so they are not listed.
for (const clinicRole of [
  'receptionist', 'cashier', 'nurse', 'midwife',
  'lab_tech', 'radiologist', 'pharmacist', 'pharmacy_tech',
]) {
  ROLE_DENYLIST[clinicRole] = [
    ...(ROLE_DENYLIST[clinicRole] || []),
    '/clinics/rbac',
  ]
}
// ── Clinic clinicians: practice-only route scope ──────────────────────────
// `ALWAYS_ALLOWED` contains the `/clinics` prefix, so every `/clinics/*`
// route is reachable by everyone and `ADMIN_ONLY_PREFIXES` never applies.
// These deny entries give a doctor a practice-scoped sidebar and a direct-URL
// guard: registering walk-ins, maintaining catalogues, managing sites and the
// security console are all back-office work.
const CLINIC_CLINICIAN_DENIED = [
  '/clinics/front-desk',
  '/clinics/catalog',
  '/clinics/sites',
  '/clinics/departments',
  '/clinics/drug-stores',
  '/clinics/equipment',
  '/clinics/corporate',
  '/clinics/analytics',
  '/clinics/staff',
  '/clinics/rbac',
  '/clinics/accounts',
  '/clinics/security',
  '/clinics/audit',
  '/clinics/settings',
  '/clinics/organization',
  '/clinics/seed-data',
  '/clinics/consents',
  '/clinics/data-sharing',
  '/clinics/wards',
  '/clinics/escalations',
  '/clinics/vitals',
]
for (const clinicianRole of ['doctor', 'clinical_officer', 'dentist']) {
  ROLE_DENYLIST[clinicianRole] = [
    ...(ROLE_DENYLIST[clinicianRole] || []),
    ...CLINIC_CLINICIAN_DENIED,
  ]
}
const ALWAYS_ALLOWED = [
  '/welcome', '/login', '/register', '/register-facility', '/register-doctor',
  '/forgot-password', '/reset-password',
  '/dashboard', '/profile', '/my-profile', '/notifications', '/messages',
  '/my-lab-results',
  // Hospital-namespace equivalents of personal routes
  '/hos', '/hos/my-profile', '/hos/messages', '/hos/my-prescriptions',
  '/hos/my-lab-results',
  '/hos/doctor-profile', '/hos/my-homecare',
  // Clinic-namespace equivalents of personal routes
  '/clinics', '/clinics/my-profile', '/clinics/messages', '/clinics/my-prescriptions',
  '/clinics/my-lab-results',
  '/clinics/doctor-profile',
  '/clinics/doctor-workspace',
  '/hos/doctor-workspace',
]

// Exact-match always-allowed paths (not prefix-matched).
const ALWAYS_ALLOWED_EXACT = new Set([
  '/pharmacy',
  '/radiology',
  '/hos',
  '/clinics',
  '/ims',
  '/ohs',
])

function startsWithAny(path, prefixes) {
  return prefixes.some(p => path === p || path.startsWith(p + '/'))
}

/**
 * Returns true if the given role is allowed to navigate to `path`.
 */
export function canAccessRoute(role, path) {
  if (!path) return true

  // Deny-list wins over everything (incl. ALWAYS_ALLOWED).
  const denyList = ROLE_DENYLIST[role]
  if (denyList && startsWithAny(path, denyList)) return false

  if (ALWAYS_ALLOWED_EXACT.has(path)) return true
  if (startsWithAny(path, ALWAYS_ALLOWED)) return true

  const allowList = ROLE_ALLOWLIST[role]
  if (allowList) {
    // Restricted role: must match the allow-list explicitly.
    return startsWithAny(path, allowList)
  }

  // Non-admin roles cannot enter admin-only areas.
  if (!ADMIN_ROLES.has(role) && startsWithAny(path, ADMIN_ONLY_PREFIXES)) {
    return false
  }
  return true
}

/**
 * Filters a nav-section array (from utils/nav.js) so that items the
 * current role cannot reach are hidden. Items with `children` are
 * recursively filtered (supports nested submenus); sections with no
 * remaining items are dropped.
 */
export function filterNavSections(sections, role) {
  const filterItems = (items) => {
    const out = []
    for (const item of items || []) {
      const allowed = canAccessRoute(role, item.path)
      let children
      if (item.children) {
        children = filterItems(item.children)
        if (!children.length) children = undefined
      }
      if (allowed || (children && children.length)) {
        out.push(children ? { ...item, children } : item)
      }
    }
    return out
  }

  const out = []
  for (const section of sections || []) {
    const items = filterItems(section.items)
    if (items.length) out.push({ ...section, items })
  }
  return out
}
