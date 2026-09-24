import { defineStore } from 'pinia'
import { ADMIN_ROLES } from '~/utils/permissions'
import { AppConstants } from '~/utils/constants'

// Roles that can freely switch between branches.
// branch_admin is in ADMIN_ROLES for route access but is locked to their branch.
const BRANCH_SWITCH_ROLES = new Set(['super_admin', 'tenant_admin'])

// Roles that get auto-assigned to their branch but can still switch freely.
const SOFT_ASSIGN_ROLES = new Set(['cashier', 'pharmacist', 'pharmacy_tech', 'storekeeper'])

function haversineKm(lat1, lon1, lat2, lon2) {
  const toRad = v => (v * Math.PI) / 180
  const R = 6371
  const dLat = toRad(lat2 - lat1)
  const dLon = toRad(lon2 - lon1)
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}

export const useBranchStore = defineStore('branch', {
  state: () => ({
    branches: [],
    currentBranchId: null,
    loading: false,
    autoAssignedBranch: null, // branch name string shown in popup, null = no popup
    branchLocked: false, // true when user cannot switch branches (branch_admin, staff)
    userLat: null,
    userLon: null,
    userBranchId: null, // the branch assigned to this user via staff_profile
  }),

  getters: {
    currentBranch: (s) => s.branches.find(b => b.id === s.currentBranchId) || null,
    currentBranchName(s) { return this.currentBranch?.name || '' },
    activeBranches: (s) => s.branches.filter(b => b.is_active),
    hasBranches: (s) => s.branches.length > 0,
    canSwitchBranch: (s) => !s.branchLocked,

    /**
     * For soft-assign roles: returns branches within 1km radius + the assigned branch.
     * For admins: returns all active branches.
     */
    allowedBranches(s) {
      const active = s.branches.filter(b => b.is_active)
      // If no geo data, return only assigned branch (or all if admin)
      if (s.userLat == null || s.userLon == null) {
        if (s.userBranchId) return active.filter(b => b.id === s.userBranchId)
        return active
      }
      const nearby = active.filter(b => {
        // Always include user's assigned branch
        if (b.id === s.userBranchId) return true
        if (b.latitude == null || b.longitude == null) return false
        return haversineKm(s.userLat, s.userLon, Number(b.latitude), Number(b.longitude)) <= 1
      })
      return nearby.length ? nearby : (s.userBranchId ? active.filter(b => b.id === s.userBranchId) : active)
    },
  },

  actions: {
    _api() { return useNuxtApp().$api },

    async load() {
      if (this.branches.length) return // already loaded
      // Skip if no tenant schema is set (e.g. super_admin on public schema)
      const schema = typeof window !== 'undefined' ? localStorage.getItem(AppConstants.storageKeys.tenantSchema) : null
      if (!schema) return
      this.loading = true
      try {
        // Inventory tenants use their own /ims API namespace.
        const tenantType = useNuxtApp().$pinia?.state?.value?.auth?.user?.tenant_type
        const base = tenantType === 'inventory' ? '/ims/branches/' : '/pharmacy-profile/branches/'
        const { data } = await this._api().get(base, { params: { page_size: 200 } })
        this.branches = data?.results || data || []
        // Restore persisted selection
        const saved = typeof window !== 'undefined' ? localStorage.getItem('adheremed_branch_id') : null
        if (saved && this.branches.some(b => b.id === Number(saved))) {
          this.currentBranchId = Number(saved)
        }
      } catch { /* silent */ }
      finally { this.loading = false }
    },

    select(branchId) {
      if (this.branchLocked) return // cannot switch
      // Soft-assign roles can only select from allowed branches
      const role = useNuxtApp().$pinia?.state?.value?.auth?.user?.role
      if (SOFT_ASSIGN_ROLES.has(role) && branchId != null) {
        const allowed = this.allowedBranches
        if (allowed.length && !allowed.some(b => b.id === branchId)) return
      }
      this.currentBranchId = branchId
      this.autoAssignedBranch = null
      if (typeof window === 'undefined') return
      if (branchId != null) localStorage.setItem('adheremed_branch_id', String(branchId))
      else localStorage.removeItem('adheremed_branch_id')
    },

    /**
     * Lock the branch for users who have an assigned branch (branch_admin, pharmacist, cashier, etc.)
     * Called after auth + branch load. Tenant admins can always switch freely.
     */
    lockToUserBranch(role, userBranchId) {
      if (BRANCH_SWITCH_ROLES.has(role)) {
        this.branchLocked = false
        return
      }
      if (userBranchId) {
        this.userBranchId = userBranchId
        this.currentBranchId = userBranchId
        if (typeof window !== 'undefined') localStorage.setItem('adheremed_branch_id', String(userBranchId))
        // Soft-assign roles can still switch; others are locked
        this.branchLocked = !SOFT_ASSIGN_ROLES.has(role)
      }
    },

    async autoAssignNearest(role) {
      // Admins have full access, skip auto-assign
      if (BRANCH_SWITCH_ROLES.has(role)) return
      // Already has a persisted branch
      if (this.currentBranchId != null) {
        // Still grab location for allowedBranches filtering
        this._captureLocation()
        return
      }

      const active = this.activeBranches
      if (!active.length) return

      // Try geolocation
      try {
        const pos = await new Promise((resolve, reject) => {
          if (!navigator?.geolocation) return reject(new Error('no geolocation'))
          navigator.geolocation.getCurrentPosition(resolve, reject, { timeout: 10000, maximumAge: 300000 })
        })
        const { latitude, longitude } = pos.coords
        this.userLat = latitude
        this.userLon = longitude
        let nearest = active[0], minDist = Infinity
        for (const b of active) {
          if (b.latitude == null || b.longitude == null) continue
          const d = haversineKm(latitude, longitude, Number(b.latitude), Number(b.longitude))
          if (d < minDist) { minDist = d; nearest = b }
        }
        this.currentBranchId = nearest.id
        this.autoAssignedBranch = nearest.name
        if (typeof window !== 'undefined') localStorage.setItem('adheremed_branch_id', String(nearest.id))
      } catch {
        // Fallback: main branch or first active
        const main = active.find(b => b.is_main) || active[0]
        this.currentBranchId = main.id
        this.autoAssignedBranch = main.name
        if (typeof window !== 'undefined') localStorage.setItem('adheremed_branch_id', String(main.id))
      }
    },

    /** Silently capture user location for allowedBranches filtering */
    _captureLocation() {
      if (this.userLat != null) return // already captured
      if (typeof navigator === 'undefined' || !navigator.geolocation) return
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          this.userLat = pos.coords.latitude
          this.userLon = pos.coords.longitude
        },
        () => {},
        { timeout: 10000, maximumAge: 300000 }
      )
    },
  },
})
