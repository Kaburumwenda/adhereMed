// Role-based route access rules.
// Restricts low-privilege roles (e.g. cashier) from admin/management screens.

// Routes that should ONLY be accessible to tenant/super admins.
// Anyone else hitting these will be redirected to /dashboard.
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
  '/inventory/stock-analysis',
  '/adjustments',
  '/categories',
  '/units',
  '/medications',
  '/departments',
  '/wards',
  '/doctor-profile',
]

// Roles considered "admins" of their tenant.
const ADMIN_ROLES = new Set([
  'super_admin',
  'tenant_admin',
  'hospital_admin',
  'pharmacy_admin',
  'lab_admin',
  'admin',
])

// Per-role allow-list of route prefixes. If a role is listed here, only
// routes that start with one of these prefixes (plus the always-allowed
// list) are accessible. Roles not listed fall back to the admin rules.
const ROLE_ALLOWLIST = {
  cashier: [
    '/dashboard',
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
  ],
}

// Per-role deny-list of route prefixes. Checked BEFORE the allow-list so
// you can grant a broad area (e.g. /billing) but block sub-pages
// (e.g. /billing/usage = API Billing dashboard).
const ROLE_DENYLIST = {
  cashier: [
    '/billing/usage',     // API Billing — admin only
    '/billing/rates',
    '/billing/doctors',
    '/billing/commission',
  ],
}

const ALWAYS_ALLOWED = [
  '/welcome', '/login', '/register', '/register-facility', '/register-doctor',
  '/forgot-password', '/reset-password',
  '/dashboard', '/profile', '/my-profile', '/notifications', '/messages',
]

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
 * recursively filtered; sections with no remaining items are dropped.
 */
export function filterNavSections(sections, role) {
  const out = []
  for (const section of sections || []) {
    const items = []
    for (const item of section.items || []) {
      const allowed = canAccessRoute(role, item.path)
      let children
      if (item.children) {
        children = item.children.filter(c => canAccessRoute(role, c.path))
        if (!children.length) children = undefined
      }
      if (allowed || (children && children.length)) {
        items.push(children ? { ...item, children } : item)
      }
    }
    if (items.length) out.push({ ...section, items })
  }
  return out
}
