// ─────────────────────────────────────────────────────────────────────────
// branding-vars.client — publishes the tenant palette as GLOBAL CSS custom
// properties on <html>.
//
// `useBranding()` returns a reactive object but every consumer has to bind it
// through `:style="heroTheme"`. That works for hand-built heroes, but global
// stylesheets (e.g. the branded dialog header applied to every `v-dialog`
// `v-card-title` in `assets/css/main.css`) cannot reach a scoped Vue binding.
//
// This plugin mirrors the palette onto `document.documentElement`, so any
// plain CSS rule can use `var(--brand-primary)` / `var(--brand-gradient)` and
// automatically follow the tenant's brand — including live changes after a
// palette save, because a `watchEffect` re-applies it.
// ─────────────────────────────────────────────────────────────────────────
import { mix } from '~/utils/branding'

export default defineNuxtPlugin(() => {
  const brand = useBranding()
  const root = document.documentElement

  function apply() {
    const primary = brand.primary.value
    const secondary = brand.secondary.value
    const accent = brand.accent.value
    const s = root.style

    s.setProperty('--brand-primary', primary)
    s.setProperty('--brand-secondary', secondary)
    s.setProperty('--brand-accent', accent)
    // Tail stop of the gradient, softened toward the primary (same maths as
    // `gradientStops` in useBranding) so the accent never washes the panel out.
    s.setProperty('--brand-accent-soft', mix(accent, primary, 0.55))
    s.setProperty('--brand-ink', brand.ink.value)
    s.setProperty('--brand-gradient', brand.gradient.value)
    s.setProperty('--brand-glow', brand.tint('primary', 0.3))
    s.setProperty('--brand-glow-2', brand.tint('accent', 0.2))
    s.setProperty('--brand-shadow', brand.shadow.value)
  }

  apply()
  // Re-runs after `useBranding().refresh()` or a tenant palette change.
  watchEffect(apply)
})
