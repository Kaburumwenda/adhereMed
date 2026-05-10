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

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: null,
    loading: false,
    initialized: false,
    error: null
  }),

  getters: {
    isLoggedIn: (s) => !!s.user,
    role: (s) => s.user?.role || '',
    tenantType: (s) => s.user?.tenant_type || null,
    tenantSchema: (s) => s.user?.tenant_schema || null,
    tenantName: (s) => s.user?.tenant_name || '',
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
      if (user?.tenant_schema) {
        setItem(KEYS.tenantSchema, user.tenant_schema)
      }
    },

    async restore() {
      if (this.initialized) return
      this.initialized = true
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

    async login(email, password) {
      this.loading = true
      this.error = null
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
        this.error = err?.response?.data?.detail || 'Registration failed.'
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
      }
    },

    async forgotPassword(email) {
      await this._api().post('/auth/password/forgot/', { email })
    },

    async resetPassword({ uid, token, password }) {
      await this._api().post('/auth/password/reset/', { uid, token, password })
    }
  }
})
