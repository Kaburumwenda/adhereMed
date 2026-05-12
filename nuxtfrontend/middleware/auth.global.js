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
    return navigateTo('/dashboard')
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
    return navigateTo('/dashboard')
  }
})
