// Axios client - mirrors lib/core/network/api_client.dart
import axios from 'axios'
import { AppConstants } from '~/utils/constants'

const PUBLIC_ENDPOINTS = [
  '/tenants/register',
  '/auth/login',
  '/auth/register/'
]

function isPublicEndpoint(url = '') {
  return PUBLIC_ENDPOINTS.some((p) => url.includes(p))
}

export default defineNuxtPlugin((nuxtApp) => {
  const config = useRuntimeConfig()

  const api = axios.create({
    baseURL: config.public.apiBase,
    timeout: 30000,
    headers: { 'Content-Type': 'application/json' }
  })

  // Request interceptor: attach token + tenant schema
  api.interceptors.request.use((req) => {
    if (typeof window !== 'undefined') {
      const token = localStorage.getItem(AppConstants.storageKeys.accessToken)
      if (token) {
        req.headers.Authorization = `Bearer ${token}`
      }
      if (!isPublicEndpoint(req.url || '')) {
        const schema = localStorage.getItem(AppConstants.storageKeys.tenantSchema)
        if (schema) {
          req.headers['X-Tenant-Schema'] = schema
        }
      }
    }
    return req
  })

  // Response interceptor: pass errors through (matches Flutter behaviour)
  api.interceptors.response.use(
    (res) => res,
    (err) => Promise.reject(err)
  )

  return {
    provide: {
      api
    }
  }
})
