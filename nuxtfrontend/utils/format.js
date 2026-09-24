// Common formatters used across detail/list pages
export function formatDate(v) {
  if (!v) return '—'
  try {
    const d = new Date(v)
    if (isNaN(d)) return v
    return d.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })
  } catch { return v }
}

export function formatDateTime(v) {
  if (!v) return '—'
  try {
    const d = new Date(v)
    if (isNaN(d)) return v
    return d.toLocaleString(undefined, { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
  } catch { return v }
}

// e.g. "Aug 09 2026, 11:40 AM"
export function formatStamp(v) {
  if (!v) return '—'
  const d = new Date(v)
  if (isNaN(d)) return v
  const mons = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
  let h = d.getHours()
  const ampm = h >= 12 ? 'PM' : 'AM'
  h = h % 12 || 12
  return `${mons[d.getMonth()]} ${String(d.getDate()).padStart(2, '0')} ${d.getFullYear()}, ${h}:${String(d.getMinutes()).padStart(2, '0')} ${ampm}`
}

export function formatMoney(v, currency = 'KES') {
  if (v == null || v === '') return '—'
  const n = Number(v)
  if (isNaN(n)) return v
  return `${currency} ${n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
}

export function formatRole(r) {
  if (!r) return ''
  return r.split('_').map(w => w[0].toUpperCase() + w.slice(1)).join(' ')
}
