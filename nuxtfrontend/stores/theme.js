// Mirrors AppThemeModeNotifier from lib/core/theme.dart
import { defineStore } from 'pinia'
import { AppConstants } from '~/utils/constants'
import { themeNames } from '~/utils/palettes'

export const useThemeStore = defineStore('theme', {
  state: () => ({
    mode: 'dark'
  }),
  actions: {
    load() {
      if (typeof window === 'undefined') return
      const saved = localStorage.getItem(AppConstants.storageKeys.themeMode)
      if (saved && themeNames.includes(saved)) {
        this.mode = saved
      }
    },
    setMode(mode) {
      if (!themeNames.includes(mode)) return
      this.mode = mode
      if (typeof window !== 'undefined') {
        localStorage.setItem(AppConstants.storageKeys.themeMode, mode)
      }
    },
    cycle() {
      const idx = themeNames.indexOf(this.mode)
      this.setMode(themeNames[(idx + 1) % themeNames.length])
    }
  }
})
