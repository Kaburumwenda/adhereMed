// Mirrors GoRouter redirect logic from lib/core/router.dart
import { useAuthStore } from '~/stores/auth'
import { canAccessRoute } from '~/utils/permissions'

const AUTH_ROUTES = new Set([
  '/welcome',
  '/login',
  '/register',
  '/register-facility',
  '/register-doctor',
  '/forgot-password',
  '/reset-password'
])

// Routes accessible to everyone (logged in or not), without redirect.
const PUBLIC_ROUTES = new Set([
  '/docs',
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
