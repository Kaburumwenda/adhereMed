// Generic CRUD composable. Returns reactive state + helpers for any REST resource.
// Backend convention: list returns { count, results } or array; detail returns object.
import { ref, computed } from 'vue'

export function useResource(endpoint) {
  const { $api } = useNuxtApp()
  const items = ref([])
  const item = ref(null)
  const count = ref(0)
  const loading = ref(false)
  const saving = ref(false)
  const error = ref(null)
  const search = ref('')
  const page = ref(1)

  function _normalize(data) {
    if (Array.isArray(data)) return { results: data, count: data.length }
    return { results: data?.results || [], count: data?.count ?? data?.results?.length ?? 0 }
  }

  async function list(params = {}) {
    loading.value = true
    error.value = null
    try {
      const { data } = await $api.get(endpoint, { params })
      const n = _normalize(data)
      items.value = n.results
      count.value = n.count
      return n.results
    } catch (e) {
      error.value = _msg(e)
      items.value = []
      return []
    } finally {
      loading.value = false
    }
  }

  async function get(id) {
    loading.value = true
    error.value = null
    try {
      const { data } = await $api.get(`${endpoint}${id}/`)
      item.value = data
      return data
    } catch (e) {
      error.value = _msg(e)
      return null
    } finally {
      loading.value = false
    }
  }

  async function create(payload) {
    saving.value = true
    error.value = null
    try {
      const { data } = await $api.post(endpoint, payload)
      return data
    } catch (e) {
      error.value = _msg(e)
      throw e
    } finally {
      saving.value = false
    }
  }

  async function update(id, payload) {
    saving.value = true
    error.value = null
    try {
      const { data } = await $api.patch(`${endpoint}${id}/`, payload)
      return data
    } catch (e) {
      error.value = _msg(e)
      throw e
    } finally {
      saving.value = false
    }
  }

  async function remove(id) {
    saving.value = true
    error.value = null
    try {
      await $api.delete(`${endpoint}${id}/`)
      items.value = items.value.filter(x => x.id !== id)
      return true
    } catch (e) {
      error.value = _msg(e)
      throw e
    } finally {
      saving.value = false
    }
  }

  function _msg(e) {
    return e?.response?.data?.detail
      || e?.response?.data?.message
      || (typeof e?.response?.data === 'string' ? e.response.data : null)
      || e?.message
      || 'Request failed.'
  }

  const filtered = computed(() => {
    if (!search.value) return items.value
    const q = search.value.toLowerCase()
    return items.value.filter(x => JSON.stringify(x).toLowerCase().includes(q))
  })

  return {
    items, item, count, loading, saving, error, search, page,
    list, get, create, update, remove, filtered
  }
}
