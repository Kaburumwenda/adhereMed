// Homecare-specific composables
import { ref, onBeforeUnmount } from 'vue'
import { useRuntimeConfig } from '#imports'

export function useHomecareEvents(onEvent) {
  const config = useRuntimeConfig()
  const apiBase = config.public?.apiBase || ''
  const connected = ref(false)
  const lastError = ref(null)
  let es = null

  function connect() {
    if (typeof window === 'undefined' || !window.EventSource) return
    const token = localStorage.getItem('access_token')
    const qs = token ? `?token=${encodeURIComponent(token)}` : ''
    const url = `${apiBase}/homecare/events/stream/${qs}`
    try {
      // No credentials -> works with wildcard CORS. Auth via ?token= query param.
      es = new EventSource(url)
      es.onopen = () => { connected.value = true }
      es.onmessage = (ev) => {
        try {
          const payload = JSON.parse(ev.data)
          if (typeof onEvent === 'function') onEvent(payload)
        } catch (_) { /* ignore */ }
      }
      es.onerror = (e) => {
        lastError.value = e
        connected.value = false
        // Browser will auto-reconnect; if it closes, try again in 5s
        if (es && es.readyState === 2) {
          setTimeout(connect, 5000)
        }
      }
    } catch (e) {
      lastError.value = e
    }
  }

  function disconnect() {
    if (es) {
      es.close()
      es = null
    }
    connected.value = false
  }

  onBeforeUnmount(disconnect)

  connect()

  return { connected, lastError, disconnect, reconnect: () => { disconnect(); connect() } }
}
