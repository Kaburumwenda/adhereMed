// https://nuxt.com/docs/api/configuration/nuxt-config
import vuetify, { transformAssetUrls } from 'vite-plugin-vuetify'

export default defineNuxtConfig({
  compatibilityDate: '2025-01-01',
  devtools: { enabled: true },

  // SPA mode - mirrors Flutter app behaviour and avoids SSR issues with Vuetify
  ssr: false,

  // Avoids Vite Node IPC error in SPA dev mode
  experimental: {
    spaLoadingTemplate: false
  },

  app: {
    head: {
      title: 'AdhereMed',
      meta: [
        { charset: 'utf-8' },
        { name: 'viewport', content: 'width=device-width, initial-scale=1' },
        { name: 'description', content: 'AdhereMed - Hospital & Pharmacy Ecosystem' }
      ],
      link: [
        { rel: 'icon', type: 'image/x-icon', href: '/favicon.ico' },
        { rel: 'preconnect', href: 'https://fonts.googleapis.com' },
        { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' },
        { rel: 'stylesheet', href: 'https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap' }
      ]
    }
  },

  modules: ['@pinia/nuxt'],

  css: [
    'vuetify/styles',
    '@mdi/font/css/materialdesignicons.css',
    '~/assets/css/main.css'
  ],

  build: {
    transpile: ['vuetify']
  },

  vite: {
    vue: {
      template: { transformAssetUrls }
    },
    plugins: [
      vuetify({ autoImport: true })
    ],
    ssr: {
      noExternal: ['vuetify']
    }
  },

  runtimeConfig: {
    public: {
      apiBase: 'http://127.0.0.1:8000/api',
      appName: 'AdhereMed'
    }
  }
})
