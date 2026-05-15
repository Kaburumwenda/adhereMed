import { defineStore } from 'pinia'
import { ADMIN_ROLES } from '~/utils/permissions'

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
  }),

  getters: {
    currentBranch: (s) => s.branches.find(b => b.id === s.currentBranchId) || null,
    currentBranchName(s) { return this.currentBranch?.name || '' },
    activeBranches: (s) => s.branches.filter(b => b.is_active),
    hasBranches: (s) => s.branches.length > 0,
  },

  actions: {
    _api() { return useNuxtApp().$api },

    async load() {
      if (this.branches.length) return // already loaded
      this.loading = true
      try {
        const { data } = await this._api().get('/pharmacy-profile/branches/', { params: { page_size: 200 } })
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
      this.currentBranchId = branchId
      this.autoAssignedBranch = null
      if (typeof window === 'undefined') return
      if (branchId != null) localStorage.setItem('adheremed_branch_id', String(branchId))
      else localStorage.removeItem('adheremed_branch_id')
    },

    async autoAssignNearest(role) {
      // Admins have full access, skip auto-assign
      if (ADMIN_ROLES.has(role)) return
      // Already has a persisted branch
      if (this.currentBranchId != null) return

      const active = this.activeBranches
      if (!active.length) return

      // Try geolocation
      try {
        const pos = await new Promise((resolve, reject) => {
          if (!navigator?.geolocation) return reject(new Error('no geolocation'))
          navigator.geolocation.getCurrentPosition(resolve, reject, { timeout: 10000, maximumAge: 300000 })
        })
        const { latitude, longitude } = pos.coords
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
  },
})
