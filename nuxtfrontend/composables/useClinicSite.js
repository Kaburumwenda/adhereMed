// Active clinic-site context for a clinic tenant.
//
// A clinic tenant can own several physical clinics (an HQ plus branches). The
// selection is shared through `useState` so every page that accepts `?site=`
// stays in sync, and it survives reloads via localStorage.
//
// `activeSiteId` is `null` for "all clinics" (tenant-wide numbers).
import { ref, computed, watch } from 'vue'

const STORAGE_KEY = 'adheremed.clinic.site'

export function useClinicSite() {
  const { $api } = useNuxtApp()

  const sites = useState('clinic-sites', () => [])
  const activeSiteId = useState('clinic-site-id', () => null)
  const loading = useState('clinic-sites-loading', () => false)
  const loaded = useState('clinic-sites-loaded', () => false)

  const activeSite = computed(
    () => sites.value.find(s => s.id === activeSiteId.value) || null,
  )
  const hqSite = computed(() => sites.value.find(s => s.is_hq) || null)
  const activeCount = computed(() => sites.value.filter(s => s.is_active).length)

  const activeLabel = computed(() => {
    if (!sites.value.length) return 'All clinics'
    if (!activeSite.value) return 'All clinics'
    return activeSite.value.name
  })

  /** Query params to spread into a `/reports/*` request. */
  const siteParams = computed(() =>
    activeSiteId.value ? { site: activeSiteId.value } : {},
  )

  function restore() {
    if (!import.meta.client) return
    try {
      const raw = localStorage.getItem(STORAGE_KEY)
      if (!raw) return
      if (raw === 'all') { activeSiteId.value = null; return }
      const id = Number(raw)
      if (!Number.isNaN(id)) activeSiteId.value = id
    } catch { /* ignore blocked storage */ }
  }

  function persist(id) {
    if (!import.meta.client) return
    try {
      localStorage.setItem(STORAGE_KEY, id ? String(id) : 'all')
    } catch { /* ignore */ }
  }

  watch(activeSiteId, (id) => persist(id))

  function rowsOf(payload) {
    if (Array.isArray(payload)) return payload
    return payload?.results || []
  }

  async function loadSites(force = false) {
    if (loaded.value && !force) return sites.value
    loading.value = true
    try {
      const { data } = await $api.get('/clinic-sites/', {
        params: { page_size: 200, ordering: 'name' },
      })
      sites.value = rowsOf(data)
      loaded.value = true
      // Drop a stale selection that no longer exists.
      if (activeSiteId.value && !sites.value.some(s => s.id === activeSiteId.value)) {
        activeSiteId.value = null
      }
    } catch {
      sites.value = []
    } finally {
      loading.value = false
    }
    return sites.value
  }

  function setActiveSite(id) {
    activeSiteId.value = id ? Number(id) : null
  }

  function invalidate() {
    loaded.value = false
  }

  return {
    sites, activeSiteId, activeSite, hqSite, activeCount, activeLabel,
    loading, loaded, siteParams,
    loadSites, setActiveSite, restore, invalidate,
  }
}
