<template>
  <v-menu offset="8" :close-on-content-click="true">
    <template #activator="{ props }">
      <v-btn v-bind="props" icon variant="text">
        <v-icon>mdi-translate</v-icon>
        <v-tooltip activator="parent" location="bottom">{{ $t('language.label') }}</v-tooltip>
      </v-btn>
    </template>
    <v-list density="compact" min-width="180" max-height="400">
      <v-list-subheader>{{ $t('language.label') }}</v-list-subheader>
      <v-list-item
        v-for="loc in locales"
        :key="loc.code"
        :active="locale === loc.code"
        @click="switchLocale(loc.code)"
      >
        <template #prepend>
          <span class="text-body-2 mr-3" style="min-width: 28px">{{ flagEmoji(loc.code) }}</span>
        </template>
        <v-list-item-title class="text-body-2">{{ loc.name }}</v-list-item-title>
        <template #append>
          <v-icon v-if="locale === loc.code" size="18" color="primary">mdi-check</v-icon>
        </template>
      </v-list-item>
    </v-list>
  </v-menu>
</template>

<script setup>
import { useI18n } from 'vue-i18n'

const { locale } = useI18n()

const locales = [
  { code: 'en', name: 'English' },
  { code: 'es', name: 'Español' },
  { code: 'fr', name: 'Français' },
  { code: 'ar', name: 'العربية' },
  { code: 'zh', name: '中文' },
  { code: 'de', name: 'Deutsch' },
  { code: 'so', name: 'Soomaali' },
  { code: 'am', name: 'አማርኛ' }
]

const flagEmoji = (code) => {
  const map = { en: '🇬🇧', es: '🇪🇸', fr: '🇫🇷', ar: '🇸🇦', zh: '🇨🇳', de: '🇩🇪', so: '🇸🇴', am: '🇪🇹' }
  return map[code] || '🌐'
}

function switchLocale(code) {
  locale.value = code
  // Set document direction for RTL languages
  if (typeof document !== 'undefined') {
    document.documentElement.dir = code === 'ar' ? 'rtl' : 'ltr'
    document.documentElement.lang = code
  }
  // Persist to localStorage
  try { localStorage.setItem('adheremed_locale', code) } catch {}
}

// Restore direction on mount
onMounted(() => {
  if (typeof document !== 'undefined') {
    document.documentElement.dir = locale.value === 'ar' ? 'rtl' : 'ltr'
    document.documentElement.lang = locale.value
  }
})
</script>
