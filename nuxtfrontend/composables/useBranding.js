// ─────────────────────────────────────────────────────────────────────────
// useBranding — the tenant's brand palette (set at /ims/organization/branding)
// exposed to any component that needs to tint itself with it.
//
// The palette is fetched once per session from `GET /tenants/me/` and cached
// in shared `useState`, so dozens of components can call `useBranding()`
// without firing dozens of requests. Call `refresh()` after saving a new
// palette to invalidate the cache.
//
// All values are guaranteed to be usable `#rrggbb` strings — a tenant that
// never customised anything transparently gets the default teal palette.
// ─────────────────────────────────────────────────────────────────────────
import {
  BRAND_DEFAULTS, normalizeHex, rgba, luminance,
  darkerOf, lighterOf, readableOn, mix
} from '~/utils/branding'
import { useAuthStore } from '~/stores/auth'

export function useBranding() {
  const { $api } = useNuxtApp()
  const auth = useAuthStore()

  // Seeds synchronously from /auth/me/ (which `auth.restore()` awaits before
  // any route renders), so the first paint is already brand-tinted. Tenant
  // switch for org admins is picked up by the authoritative fetch below.
  const palette = useState('brand-palette', () => ({
    primary: normalizeHex(auth.user?.brand_primary) || BRAND_DEFAULTS.primary,
    secondary: normalizeHex(auth.user?.brand_secondary) || BRAND_DEFAULTS.secondary,
    accent: normalizeHex(auth.user?.brand_accent) || BRAND_DEFAULTS.accent
  }))
  const isLoaded = useState('brand-palette-loaded', () => false)

  const primary = computed(() => normalizeHex(palette.value.primary) || BRAND_DEFAULTS.primary)
  const secondary = computed(() => normalizeHex(palette.value.secondary) || BRAND_DEFAULTS.secondary)
  const accent = computed(() => normalizeHex(palette.value.accent) || BRAND_DEFAULTS.accent)

  /** True when the tenant actually customised at least one colour. */
  const isCustom = computed(() =>
    primary.value !== BRAND_DEFAULTS.primary ||
    secondary.value !== BRAND_DEFAULTS.secondary ||
    accent.value !== BRAND_DEFAULTS.accent
  )

  /**
   * The darkest brand colour. Use it for text/icons sitting on a light
   * (e.g. white) pill so contrast survives a light primary.
   */
  const ink = computed(() => darkerOf(secondary.value, primary.value))

  /** The lightest brand colour — for glows and highlights. */
  const highlight = computed(() => lighterOf(accent.value, primary.value))

  /**
   * Readable foreground for a solid `primary` surface.
   * Dark primaries get white, light primaries get near-black.
   */
  const onPrimary = computed(() => readableOn(primary.value))

  /**
   * The signature panel gradient: deep → primary → a softened accent.
   * The accent is mixed toward the primary and pushed past 100% so it only
   * tints the tail of the gradient instead of washing it out.
   */
  const gradientStops = computed(() => {
    const end = mix(accent.value, primary.value, 0.55)
    return [secondary.value, primary.value, end]
  })

  const gradient = computed(() =>
    `linear-gradient(120deg, ${gradientStops.value[0]} 0%, ${gradientStops.value[1]} 52%, ${gradientStops.value[2]} 100%)`
  )

  /**
   * A drop shadow tinted with the brand primary, so panels feel grounded
   * rather than floating on a generic grey shadow.
   */
  const shadow = computed(() => `0 14px 34px ${rgba(primary.value, 0.24)}`)

  /** Low-alpha washes for glass layers and glows on the gradient. */
  const tint = (which, alpha) => {
    const hex = which === 'secondary' ? secondary.value
      : which === 'accent' ? accent.value
        : primary.value
    return rgba(hex, alpha)
  }

  async function load(force = false) {
    if (isLoaded.value && !force) return palette.value
    try {
      const { data } = await $api.get('/tenants/me/')
      palette.value = {
        primary: normalizeHex(data?.brand_primary) || BRAND_DEFAULTS.primary,
        secondary: normalizeHex(data?.brand_secondary) || BRAND_DEFAULTS.secondary,
        accent: normalizeHex(data?.brand_accent) || BRAND_DEFAULTS.accent
      }
      isLoaded.value = true
    } catch {
      // Public/super-admin contexts have no tenant — keep the defaults and
      // don't retry on every mount.
      isLoaded.value = true
    }
    return palette.value
  }

  /** Drop the cache so the next `load()` re-fetches (call after saving). */
  function invalidate() {
    isLoaded.value = false
  }

  async function refresh() {
    return load(true)
  }

  return {
    // state
    palette, isLoaded, isCustom,
    // resolved colours
    primary, secondary, accent,
    ink, highlight, onPrimary,
    // ready-made decorations
    gradient, gradientStops, shadow, tint,
    // helpers
    rgba, luminance, darkerOf, lighterOf, readableOn, mix,
    // actions
    load, refresh, invalidate
  }
}
