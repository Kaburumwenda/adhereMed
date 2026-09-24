// Mirrors GoRouter redirect logic from lib/core/router.dart
import { useAuthStore } from '~/stores/auth'
import { canAccessRoute } from '~/utils/permissions'

const AUTH_ROUTES = new Set([
  '/welcome',
  '/login',
  '/get-started',
  '/register',
  '/register-patient',
  '/register-facility',
  '/register-pharmacy',
  '/register-inventory',
  '/register-doctor',
  '/forgot-password',
  '/reset-password'
])

// Routes accessible to everyone (logged in or not), without redirect.
const PUBLIC_ROUTES = new Set([
  '/docs',
  '/pricing',
])

function getHomePath(auth) {
  if (auth.tenantType === 'pharmacy') return '/pharmacy'
  if (auth.tenantType === 'lab') return '/lab'
  if (auth.tenantType === 'radiology_center') return '/radiology'
  if (auth.tenantType === 'hospital') return '/hos'
  if (auth.tenantType === 'clinic') return '/clinics'
  if (auth.tenantType === 'inventory') return '/ims'
  return '/dashboard'
}

// Routes that pharmacy tenants should access under /pharmacy/ prefix.
// If a pharmacy user navigates to one of these unprefixed, redirect to /pharmacy/...
const PHARMACY_PREFIXED_ROUTES = [
  '/pos', '/pharmacy-orders', '/pharmacy-rx', '/inventory', '/categories',
  '/units', '/adjustments', '/analytics', '/reports', '/invoices', '/accounts',
  '/expenses', '/deliveries', '/purchase-orders', '/dispensing', '/alerts',
  '/insurance', '/medications', '/customers', '/staff', '/specializations',
  '/staff-performance', '/suppliers', '/settings', '/branches',
]

function shouldRedirectToPharmacy(auth, path) {
  if (auth.tenantType !== 'pharmacy') return null
  if (path.startsWith('/pharmacy')) return null  // already prefixed
  for (const prefix of PHARMACY_PREFIXED_ROUTES) {
    if (path === prefix || path.startsWith(prefix + '/')) {
      // Map /pharmacy-orders -> /pharmacy/orders, /pharmacy-rx -> /pharmacy/rx
      let mapped = path
      if (path.startsWith('/pharmacy-orders')) {
        mapped = '/pharmacy/orders' + path.slice('/pharmacy-orders'.length)
      } else if (path.startsWith('/pharmacy-rx')) {
        mapped = '/pharmacy/rx' + path.slice('/pharmacy-rx'.length)
      } else {
        mapped = '/pharmacy' + path
      }
      return mapped
    }
  }
  return null
}

// Routes that hospital tenants should access under /hos/ prefix.
// If a hospital user navigates to one of these unprefixed, redirect to /hos/...
// Note: /radiology and /lab-orders keep their own paths — /radiology is shared
// with radiology_center tenants and /lab-orders is too small to namespace.
// /dashboard is excluded — dashboard.vue itself redirects hospital users to /hos.
const HOSPITAL_PREFIXED_ROUTES = [
  '/patients', '/appointments', '/consultations', '/prescriptions',
  '/triage', '/wards', '/invoices', '/accounts', '/expenses', '/departments',
  '/billing/commission', '/billing/locked', '/billing/overdue', '/billing/usage',
  '/alerts', '/messages', '/doctors', '/doctor-profile', '/my-profile',
  '/my-prescriptions', '/my-homecare', '/staff',
]

function shouldRedirectToHospital(auth, path) {
  if (auth.tenantType !== 'hospital') return null
  if (path.startsWith('/hos')) return null  // already prefixed
  // Never redirect /radiology/* — shared with radiology_center tenants.
  if (path === '/radiology' || path.startsWith('/radiology/')) return null
  for (const prefix of HOSPITAL_PREFIXED_ROUTES) {
    if (path === prefix || path.startsWith(prefix + '/')) {
      return '/hos' + path
    }
  }
  return null
}

// Clinic tenant namespace redirect: clinic users accessing unprefixed
// hospital-equivalent routes (e.g. /patients) are redirected to /clinics/patients.
// Clinic pages are file-based under pages/clinics/ — no aliasing needed.
const CLINIC_PREFIXED_ROUTES = [
  '/patients', '/appointments', '/consultations', '/prescriptions',
  '/triage', '/wards', '/invoices', '/accounts', '/expenses', '/departments',
  '/billing/commission', '/billing/locked', '/billing/overdue', '/billing/usage',
  '/alerts', '/messages', '/doctors', '/doctor-profile', '/my-profile',
  '/my-prescriptions', '/staff', '/analytics',
  '/caregivers', '/care-notes', '/vitals', '/patient-care', '/escalations',
  '/consents', '/data-sharing', '/audit', '/medications',
]

function shouldRedirectToClinic(auth, path) {
  if (auth.tenantType !== 'clinic') return null
  if (path.startsWith('/clinics')) return null  // already prefixed
  if (path === '/radiology' || path.startsWith('/radiology/')) return null
  for (const prefix of CLINIC_PREFIXED_ROUTES) {
    if (path === prefix || path.startsWith(prefix + '/')) {
      return '/clinics' + path
    }
  }
  return null
}

// Routes that inventory / warehouse tenants should access under /ims/.
// If an inventory user navigates to one of these unprefixed (e.g. via an
// in-page link), redirect them to the /ims/ prefixed equivalent.
const INVENTORY_PREFIXED_ROUTES = [
  '/inventory', '/categories', '/units', '/adjustments', '/alerts',
  '/purchase-orders', '/suppliers', '/branches', '/accounts', '/invoices',
  '/expenses', '/analytics', '/reports', '/staff', '/settings', '/setup',
  '/pos', '/sales-orders', '/deliveries', '/customers',
]

function shouldRedirectToInventory(auth, path) {
  if (auth.tenantType !== 'inventory') return null
  if (path.startsWith('/ims')) return null  // already prefixed
  for (const prefix of INVENTORY_PREFIXED_ROUTES) {
    if (path === prefix || path.startsWith(prefix + '/')) {
      return '/ims' + path
    }
  }
  return null
}

export default defineNuxtRouteMiddleware(async (to) => {
  // Skip server-side - SPA mode means middleware only runs client-side anyway
  if (process.server) return

  const auth = useAuthStore()
  await auth.restore()

  // The static host serves directory-style URLs (e.g. /register-inventory/)
  // and 301-redirects the bare path to it. Normalize the trailing slash so
  // the route-set lookups below still match on direct URL entry.
  const path = to.path && to.path !== '/' ? to.path.replace(/\/+$/, '') : to.path

  if (PUBLIC_ROUTES.has(path)) return

  const isAuthRoute = AUTH_ROUTES.has(path)

  if (!auth.isLoggedIn && !isAuthRoute) {
    return navigateTo('/welcome')
  }
  if (auth.isLoggedIn && isAuthRoute) {
    return navigateTo(getHomePath(auth))
  }

  // ── Billing lock gate ──
  // When a tenant is past due (or hard-suspended) the whole app is blocked
  // until the bills are cleared. Tenant admins get the "clear bills" screen;
  // other staff get a "contact your admin" screen. Super admins bypass.
  if (auth.isLoggedIn && auth.billingLocked && auth.role !== 'super_admin' && auth.tenantType) {
    const tenantPrefix = auth.tenantType === 'hospital' ? '/hos' : auth.tenantType === 'clinic' ? '/clinics' : ''
    const overduePage = tenantPrefix ? `${tenantPrefix}/billing/overdue` : '/billing/overdue'
    const lockedPage = tenantPrefix ? `${tenantPrefix}/billing/locked` : '/billing/locked'
    const lockPage = auth.isTenantAdmin ? overduePage : lockedPage
    const lockPages = [overduePage, lockedPage, '/billing/overdue', '/billing/locked']
    if (!lockPages.includes(path)) {
      return navigateTo(lockPage)
    }
    // If a non-admin lands on the admin overdue screen (or vice-versa), send
    // them to the correct one.
    if ((path === overduePage || path === '/billing/overdue') && !auth.isTenantAdmin) return navigateTo(lockedPage)
    if ((path === lockedPage || path === '/billing/locked') && auth.isTenantAdmin) return navigateTo(overduePage)
  }

  // When NOT locked, keep the gate pages from being visited directly.
  if (auth.isLoggedIn && !auth.billingLocked
      && (path === '/billing/overdue' || path === '/billing/locked'
          || path === '/hos/billing/overdue' || path === '/hos/billing/locked'
          || path === '/clinics/billing/overdue' || path === '/clinics/billing/locked')) {
    // Allow the overdue page for admins with any outstanding overdue balance
    // (so they can pre-empt a lock); otherwise send them home.
    const isOverdue = path === '/billing/overdue' || path === '/hos/billing/overdue' || path === '/clinics/billing/overdue'
    if (!(isOverdue && auth.isTenantAdmin && auth.hasOverdue)) {
      return navigateTo(getHomePath(auth))
    }
  }

  // Pharmacy tenant namespace redirect: if a pharmacy user navigates to
  // an unprefixed route (e.g. /pos from a router.push inside a page),
  // redirect them to the /pharmacy/ prefixed equivalent.
  if (auth.isLoggedIn && auth.tenantType === 'pharmacy') {
    const pharmacyPath = shouldRedirectToPharmacy(auth, path)
    if (pharmacyPath) {
      // Preserve query string from original navigation
      const query = to.fullPath.includes('?') ? to.fullPath.slice(to.fullPath.indexOf('?')) : ''
      return navigateTo(pharmacyPath + query, { replace: true })
    }
  }

  // Hospital tenant namespace redirect: if a hospital user navigates to
  // an unprefixed route (e.g. /patients from a router.push inside a page),
  // redirect them to the /hos/ prefixed equivalent.
  if (auth.isLoggedIn && auth.tenantType === 'hospital') {
    const hosPath = shouldRedirectToHospital(auth, path)
    if (hosPath) {
      // Preserve query string from original navigation
      const query = to.fullPath.includes('?') ? to.fullPath.slice(to.fullPath.indexOf('?')) : ''
      return navigateTo(hosPath + query, { replace: true })
    }
  }

  // Clinic tenant namespace redirect: clinic users accessing unprefixed
  // routes are sent to the /clinics/ prefixed equivalent.
  if (auth.isLoggedIn && auth.tenantType === 'clinic') {
    const clinicPath = shouldRedirectToClinic(auth, path)
    if (clinicPath) {
      const query = to.fullPath.includes('?') ? to.fullPath.slice(to.fullPath.indexOf('?')) : ''
      return navigateTo(clinicPath + query, { replace: true })
    }
  }

  // Inventory tenant namespace redirect: inventory users accessing unprefixed
  // inventory routes are sent to the /ims/ prefixed equivalent.
  if (auth.isLoggedIn && auth.tenantType === 'inventory') {
    const imsPath = shouldRedirectToInventory(auth, path)
    if (imsPath) {
      const query = to.fullPath.includes('?') ? to.fullPath.slice(to.fullPath.indexOf('?')) : ''
      return navigateTo(imsPath + query, { replace: true })
    }
  }

  // Role-based access guard: prevent non-admin roles (e.g. cashier)
  // from reaching admin/management screens via direct URL.
  if (auth.isLoggedIn && !canAccessRoute(auth.role, path)) {
    if (process.client) {
      // Surface a friendly toast if the snackbar plugin is available.
      try {
        const { $toast } = useNuxtApp()
        $toast?.warning?.('You do not have permission to view that page.')
      } catch {}
    }
    return navigateTo(getHomePath(auth))
  }
})
