// Returns the active tenant namespace prefix based on the current route.
// Examples: '/hos' (hospital), '/clinics' (clinic), or '' (unprefixed).
// Used to build correct internal links when a page is reused under multiple
// tenant namespaces (e.g. consultations/ is mounted under both /hos and
// /clinics).
export function useTenantPrefix() {
  const route = useRoute()
  const ns = computed(() => {
    if (route.path.startsWith('/hos')) return '/hos'
    if (route.path.startsWith('/clinics')) return '/clinics'
    return ''
  })
  return ns
}

// Helper: build a namespaced path for a given section.
//   namespacedPath('/patients') → '/hos/patients' | '/clinics/patients' | '/patients'
export function useNamespacedPath() {
  const ns = useTenantPrefix()
  return (section) => {
    const root = section.startsWith('/') ? section : `/${section}`
    return ns.value ? `${ns.value}${root}` : root
  }
}
