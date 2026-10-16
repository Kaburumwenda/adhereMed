// Mirrors lib/features/auth/providers/auth_provider.dart
//      + lib/features/auth/repository/auth_repository.dart
import { defineStore } from 'pinia'
import { AppConstants } from '~/utils/constants'

const KEYS = AppConstants.storageKeys

function readJSON(key) {
  if (typeof window === 'undefined') return null
  const raw = localStorage.getItem(key)
  if (!raw) return null
  try { return JSON.parse(raw) } catch { return null }
}

function writeJSON(key, value) {
  if (typeof window === 'undefined') return
  localStorage.setItem(key, JSON.stringify(value))
}

function setItem(key, value) {
  if (typeof window === 'undefined') return
  if (value == null) localStorage.removeItem(key)
  else localStorage.setItem(key, value)
}

// Flattens a DRF error response into a single readable message.
// Handles { detail: '...' }, { field: ['msg', ...] } and plain strings.
function extractApiError(data) {
  if (!data) return null
  if (typeof data === 'string') return data
  if (data.detail) return data.detail
  const labels = { email: 'Email', national_id: 'National ID', password: 'Password' }
  for (const [field, val] of Object.entries(data)) {
    const msg = Array.isArray(val) ? val[0] : val
    if (!msg) continue
    const label = labels[field] || null
    return label ? `${label}: ${msg}` : String(msg)
  }
  return null
}

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: null,
    loading: false,
    initialized: false,
    error: null,
    // When an org admin switches into a linked tenant, this holds the
    // override info { name, type, slug, schema_name } so the frontend knows
    // which tenant context is active.
    activeTenantOverride: null,
  }),

  getters: {
    isLoggedIn: (s) => !!s.user,
    role: (s) => s.user?.role || '',
    tenantType: (s) => s.activeTenantOverride?.type || s.user?.tenant_type || null,
    tenantSchema: (s) => s.activeTenantOverride?.schema_name || s.user?.tenant_schema || null,
    tenantName: (s) => s.activeTenantOverride?.name || s.user?.tenant_name || '',
    tenantLogo: (s) => s.user?.tenant_logo || null,
    isTenantAdmin: (s) => !!s.user?.is_tenant_admin,
    billing: (s) => s.user?.billing || null,
    billingLocked: (s) => !!s.user?.billing?.locked,
    hasOverdue: (s) => !!s.user?.billing?.has_overdue,
    overdueTotal: (s) => s.user?.billing?.total_overdue || '0',
    organizationId: (s) => s.user?.organization_id || null,
    organizationName: (s) => s.user?.organization_name || null,
    isOrgAdmin: (s) => !!s.user?.is_org_admin && !!s.user?.organization_id,
    fullName: (s) => {
      if (!s.user) return ''
      return `${s.user.first_name || ''} ${s.user.last_name || ''}`.trim()
    }
  },

  actions: {
    _api() {
      return useNuxtApp().$api
    },

    _setTokens({ access, refresh }) {
      setItem(KEYS.accessToken, access)
      setItem(KEYS.refreshToken, refresh)
    },

    _clearTokens() {
      setItem(KEYS.accessToken, null)
      setItem(KEYS.refreshToken, null)
      setItem(KEYS.user, null)
    },

    _persistUser(user) {
      writeJSON(KEYS.user, user)
      this.user = user
      const schema = this.activeTenantOverride?.schema_name || user?.tenant_schema
      if (schema) {
        setItem(KEYS.tenantSchema, schema)
      }
    },

    /** Update the tenant logo URL in the cached user object (sidebar refresh). */
    updateTenantLogo(logoUrl) {
      if (!this.user) return
      this.user = { ...this.user, tenant_logo: logoUrl }
      writeJSON(KEYS.user, this.user)
    },

    async restore() {
      if (this.initialized) return
      this.initialized = true
      this._restoreOverride()
      const token = typeof window !== 'undefined'
        ? localStorage.getItem(KEYS.accessToken) : null
      if (!token) return
      try {
        const { data } = await this._api().get('/auth/me/')
        this._persistUser(data)
      } catch (_) {
        this._clearTokens()
        this.user = null
      }
    },

    // Force a fresh /auth/me fetch (e.g. to re-check billing lock after a payment).
    async refresh() {
      const token = typeof window !== 'undefined'
        ? localStorage.getItem(KEYS.accessToken) : null
      if (!token) return null
      try {
        const { data } = await this._api().get('/auth/me/')
        this._persistUser(data)
        return data
      } catch (_) {
        return null
      }
    },

    async login(email, password) {
      this.loading = true
      this.error = null
      // Clear any stale tenant override from a previous session
      this.activeTenantOverride = null
      if (typeof window !== 'undefined') {
        sessionStorage.removeItem('org_tenant_override')
      }
      try {
        const { data } = await this._api().post('/auth/login/', { email, password })
        this._setTokens(data.tokens)
        this._persistUser(data.user)
        return true
      } catch (err) {
        const status = err?.response?.status
        if (status === 400 || status === 401) {
          this.error = 'Invalid email or password.'
        } else if (err?.code === 'ECONNABORTED' || err?.message?.includes('Network')) {
          this.error = 'Cannot connect to server.'
        } else {
          this.error = 'Login failed. Please try again.'
        }
        return false
      } finally {
        this.loading = false
      }
    },

    async register(payload) {
      this.loading = true
      this.error = null
      try {
        const body = {
          email: payload.email,
          password: payload.password,
          first_name: payload.firstName,
          last_name: payload.lastName,
          phone: payload.phone || '',
          national_id: payload.nationalId
        }
        const { data } = await this._api().post('/auth/register/', body)
        this._setTokens(data.tokens)
        this._persistUser(data.user)
        return true
      } catch (err) {
        this.error = extractApiError(err?.response?.data) || 'Registration failed.'
        return false
      } finally {
        this.loading = false
      }
    },

    async logout() {
      try {
        const refresh = typeof window !== 'undefined'
          ? localStorage.getItem(KEYS.refreshToken) : null
        if (refresh) {
          await this._api().post('/auth/logout/', { refresh })
        }
      } catch (_) {
        // ignore
      } finally {
        this._clearTokens()
        setItem(KEYS.tenantSchema, null)
        this.user = null
        this.activeTenantOverride = null
        if (typeof window !== 'undefined') {
          sessionStorage.removeItem('org_tenant_override')
        }
      }
    },

    async forgotPassword(email) {
      await this._api().post('/auth/password/forgot/', { email })
    },

    async resetPassword({ uid, token, password }) {
      await this._api().post('/auth/password/reset/', { uid, token, password })
    },

    // ── Organization Command Center: tenant switching ──

    // Restore any saved override from sessionStorage on app boot.
    _restoreOverride() {
      if (typeof window === 'undefined') return
      try {
        const raw = sessionStorage.getItem('org_tenant_override')
        if (raw) this.activeTenantOverride = JSON.parse(raw)
      } catch { /* ignore */ }
    },

    async switchTenant(tenantId) {
      const { data } = await this._api().post(
        '/organizations/switch-tenant/', { tenant_id: tenantId })
      // data = { id, name, type, slug, schema_name }
      this.activeTenantOverride = data
      if (typeof window !== 'undefined') {
        sessionStorage.setItem('org_tenant_override', JSON.stringify(data))
        setItem(KEYS.tenantSchema, data.schema_name)
      }
      return data
    },

    async switchBack() {
      try {
        const { data } = await this._api().post('/organizations/switch-back/')
        // data = { schema_name?, name?, type? }
        if (data.schema_name) {
          setItem(KEYS.tenantSchema, data.schema_name)
        } else {
          // No home tenant — reset to user's own (or clear)
          setItem(KEYS.tenantSchema,
            this.user?.tenant_schema || null)
        }
      } catch { /* ignore */ }
      this.activeTenantOverride = null
      if (typeof window !== 'undefined') {
        sessionStorage.removeItem('org_tenant_override')
      }
    }
  }
})
