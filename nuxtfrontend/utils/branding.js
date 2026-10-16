// ─────────────────────────────────────────────────────────────────────────
// Tenant brand-colour helpers.
//
// The palette lives on the Tenant model (brand_primary / brand_secondary /
// brand_accent) and is edited at /ims/organization/branding (and the
// /pharmacy equivalent). `GET /tenants/me/` returns the raw hex strings.
//
// Every helper here is dependency-free and defensive: an empty string, a
// partial colour or an "rgb()" value must never crash a page, so all
// functions take a hex string and fall back to a safe default.
// ─────────────────────────────────────────────────────────────────────────

/**
 * Fallbacks used when a tenant has not customised its palette.
 *
 * These MUST stay in sync with the backend, which falls back to the AdhereMed
 * blue in the PDF/branding helpers (`inventory/views.py` →
 * `_hex_color('brand_primary', '#2f6dff')`) and with `DEFAULTS` in
 * `pages/organization/branding.vue`, so the UI and generated documents never
 * disagree about what "no brand configured" looks like.
 */
export const BRAND_DEFAULTS = {
  primary: '#2f6dff',
  secondary: '#143ce1',
  accent: '#37d6ff'
}

/**
 * Palettes offered by the branding page. Kept in sync with
 * `pages/organization/branding.vue` so a tenant that never saved a palette
 * still gets a coherent one.
 */
export const BRAND_PRESETS = [
  { name: 'AdhereMed', primary: '#2f6dff', secondary: '#143ce1', accent: '#37d6ff' },
  { name: 'Teal', primary: '#0D9488', secondary: '#0F766E', accent: '#5EEAD4' },
  { name: 'Indigo', primary: '#4F46E5', secondary: '#3730A3', accent: '#818CF8' },
  { name: 'Rose', primary: '#DB2777', secondary: '#9D174D', accent: '#F9A8D4' },
  { name: 'Emerald', primary: '#16A34A', secondary: '#15803D', accent: '#86EFAC' },
  { name: 'Sunset', primary: '#F97316', secondary: '#C2410C', accent: '#FED7AA' }
]

/**
 * Normalise any user-typed colour into `#rrggbb` (lowercase).
 * Accepts `#abc`, `abc`, `#AABBCC`. Returns '' when unparseable.
 */
export function normalizeHex(value) {
  if (typeof value !== 'string') return ''
  let s = value.trim().toLowerCase()
  if (!s) return ''
  if (!s.startsWith('#')) s = `#${s}`
  if (/^#[0-9a-f]{6}$/.test(s)) return s
  // Expand shorthand: #abc -> #aabbcc
  if (/^#[0-9a-f]{3}$/.test(s)) {
    const [, r, g, b] = s
    return `#${r}${r}${g}${g}${b}${b}`
  }
  return ''
}

/** Hex string → `{ r, g, b }`, or null when unparseable. */
export function hexToRgb(hex) {
  const h = normalizeHex(hex)
  if (!h) return null
  return {
    r: parseInt(h.slice(1, 3), 16),
    g: parseInt(h.slice(3, 5), 16),
    b: parseInt(h.slice(5, 7), 16)
  }
}

/** `rgba(r, g, b, alpha)` from a hex colour. Falls back to the raw colour. */
export function rgba(hex, alpha = 1) {
  const rgb = hexToRgb(hex)
  if (!rgb) return hex || 'transparent'
  return `rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, ${alpha})`
}

/**
 * WCAG relative luminance (0 = black, 1 = white). Used to decide whether a
 * brand colour is light or dark, so text on it stays readable.
 */
export function luminance(hex) {
  const rgb = hexToRgb(hex)
  if (!rgb) return 0.5
  const channel = (v) => {
    const c = v / 255
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4
  }
  return 0.2126 * channel(rgb.r) + 0.7152 * channel(rgb.g) + 0.0722 * channel(rgb.b)
}

/** The darker of two colours — useful for text sitting on a light surface. */
export function darkerOf(a, b) {
  const ca = normalizeHex(a)
  const cb = normalizeHex(b)
  if (!ca) return cb || a
  if (!cb) return ca
  return luminance(ca) <= luminance(cb) ? ca : cb
}

/** The lighter of two colours. */
export function lighterOf(a, b) {
  const ca = normalizeHex(a)
  const cb = normalizeHex(b)
  if (!ca) return cb || a
  if (!cb) return ca
  return luminance(ca) >= luminance(cb) ? ca : cb
}

/**
 * Pick a readable foreground for a given background.
 * Returns near-white or near-black depending on the background luminance.
 */
export function readableOn(background, light = '#ffffff', dark = '#0f172a') {
  return luminance(background) > 0.55 ? dark : light
}

/**
 * Blend `color` toward `target` by `amount` (0..1). Used to build the third
 * gradient stop so an accent colour never washes the panel out.
 */
export function mix(color, target, amount = 0.5) {
  const a = hexToRgb(color)
  const b = hexToRgb(target)
  if (!a || !b) return normalizeHex(color) || color
  const t = Math.min(Math.max(amount, 0), 1)
  const blend = (x, y) => Math.round(x + (y - x) * t)
  const toHex = (n) => n.toString(16).padStart(2, '0')
  return `#${toHex(blend(a.r, b.r))}${toHex(blend(a.g, b.g))}${toHex(blend(a.b, b.b))}`
}
