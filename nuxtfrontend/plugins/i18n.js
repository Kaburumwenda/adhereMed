import { createI18n } from 'vue-i18n'
import en from '~/i18n/locales/en.json'
import es from '~/i18n/locales/es.json'
import fr from '~/i18n/locales/fr.json'
import ar from '~/i18n/locales/ar.json'
import zh from '~/i18n/locales/zh.json'
import de from '~/i18n/locales/de.json'
import so from '~/i18n/locales/so.json'
import am from '~/i18n/locales/am.json'

const STORAGE_KEY = 'adheremed_locale'

function getSavedLocale() {
  if (typeof window === 'undefined') return 'en'
  try {
    const saved = localStorage.getItem(STORAGE_KEY)
    if (saved && ['en', 'es', 'fr', 'ar', 'zh', 'de', 'so', 'am'].includes(saved)) return saved
  } catch {}
  return 'en'
}

export default defineNuxtPlugin((nuxtApp) => {
  const i18n = createI18n({
    legacy: false,
    globalInjection: true,
    locale: getSavedLocale(),
    fallbackLocale: 'en',
    messages: { en, es, fr, ar, zh, de, so, am }
  })

  nuxtApp.vueApp.use(i18n)

  // Apply direction on init
  if (process.client) {
    const loc = i18n.global.locale.value
    document.documentElement.dir = loc === 'ar' ? 'rtl' : 'ltr'
    document.documentElement.lang = loc
  }
})
