import 'vuetify/styles'
import { createVuetify } from 'vuetify'
import { palettes, themeNames } from '~/utils/palettes'
import { AppConstants } from '~/utils/constants'
import { useThemeStore } from '~/stores/theme'

function readInitialTheme() {
  if (typeof window === 'undefined') return 'dark'
  try {
    const saved = localStorage.getItem(AppConstants.storageKeys.themeMode)
    if (saved && themeNames.includes(saved)) return saved
  } catch (_) { /* ignore */ }
  return 'dark'
}

export default defineNuxtPlugin((nuxtApp) => {
  const initial = readInitialTheme()

  const vuetify = createVuetify({
    locale: {
      rtl: { ar: true }
    },
    theme: {
      defaultTheme: initial,
      themes: {
        light: palettes.light,
        dark: palettes.dark,
        ocean: palettes.ocean,
        sunset: palettes.sunset
      }
    },
    defaults: {
      VBtn: {
        style: 'text-transform: none; letter-spacing: 0;',
        rounded: 'lg'
      },
      VTextField: {
        variant: 'outlined',
        density: 'comfortable',
        color: 'primary'
      },
      VSelect: {
        variant: 'outlined',
        density: 'comfortable',
        color: 'primary'
      },
      VCard: {
        rounded: 'lg',
        elevation: 0,
        border: 'thin'
      }
    }
  })

  nuxtApp.vueApp.use(vuetify)

  // Keep Vuetify in sync with the Pinia theme store. Pinia is registered as a
  // module so it's available here. Done in the same plugin to avoid the
  // unreliable `$vuetify` global-property lookup used previously.
  if (process.client) {
    const store = useThemeStore(nuxtApp.$pinia)
    store.load()
    vuetify.theme.global.name.value = store.mode
    store.$subscribe((_m, state) => {
      vuetify.theme.global.name.value = state.mode
    })
  }
})
