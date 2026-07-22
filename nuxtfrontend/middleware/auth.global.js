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

export default defineNuxtRouteMiddleware(async (to) => {
  // Skip server-side - SPA mode means middleware only runs client-side anyway
  if (process.server) return

  const auth = useAuthStore()
  await auth.restore()

  if (PUBLIC_ROUTES.has(to.path)) return

  const isAuthRoute = AUTH_ROUTES.has(to.path)

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
    const lockPage = auth.isTenantAdmin ? '/billing/overdue' : '/billing/locked'
    if (to.path !== lockPage && to.path !== '/billing/overdue' && to.path !== '/billing/locked') {
      return navigateTo(lockPage)
    }
    // If a non-admin lands on the admin overdue screen (or vice-versa), send
    // them to the correct one.
    if (to.path === '/billing/overdue' && !auth.isTenantAdmin) return navigateTo('/billing/locked')
    if (to.path === '/billing/locked' && auth.isTenantAdmin) return navigateTo('/billing/overdue')
  }

  // When NOT locked, keep the gate pages from being visited directly.
  if (auth.isLoggedIn && !auth.billingLocked
      && (to.path === '/billing/overdue' || to.path === '/billing/locked')) {
    // Allow the overdue page for admins with any outstanding overdue balance
    // (so they can pre-empt a lock); otherwise send them home.
    if (!(to.path === '/billing/overdue' && auth.isTenantAdmin && auth.hasOverdue)) {
      return navigateTo(getHomePath(auth))
    }
  }

  // Pharmacy tenant namespace redirect: if a pharmacy user navigates to
  // an unprefixed route (e.g. /pos from a router.push inside a page),
  // redirect them to the /pharmacy/ prefixed equivalent.
  if (auth.isLoggedIn && auth.tenantType === 'pharmacy') {
    const pharmacyPath = shouldRedirectToPharmacy(auth, to.path)
    if (pharmacyPath) {
      // Preserve query string from original navigation
      const query = to.fullPath.includes('?') ? to.fullPath.slice(to.fullPath.indexOf('?')) : ''
      return navigateTo(pharmacyPath + query, { replace: true })
    }
  }

  // Role-based access guard: prevent non-admin roles (e.g. cashier)
  // from reaching admin/management screens via direct URL.
  if (auth.isLoggedIn && !canAccessRoute(auth.role, to.path)) {
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
