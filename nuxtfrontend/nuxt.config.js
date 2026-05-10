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
        { name: 'description', content: 'AdhereMed - Connected Healthcare Simplified' },
        { name: 'theme-color', content: '#2DD4BF' },
        { name: 'mobile-web-app-capable', content: 'yes' },
        { name: 'apple-mobile-web-app-capable', content: 'yes' },
        { name: 'apple-mobile-web-app-status-bar-style', content: 'black-translucent' },
        { name: 'apple-mobile-web-app-title', content: 'AdhereMed' }
      ],
      link: [
        { rel: 'icon', type: 'image/x-icon', href: '/favicon.ico' },
        { rel: 'apple-touch-icon', href: '/icons/icon-192.png' },
        { rel: 'preconnect', href: 'https://fonts.googleapis.com' },
        { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' },
        { rel: 'stylesheet', href: 'https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap' }
      ]
    }
  },

  modules: ['@pinia/nuxt', '@vite-pwa/nuxt'],

  // Auto-import components from subdirectories without prefixing the
  // directory name, so e.g. components/forms/TenantForm.vue is usable
  // as <TenantForm /> rather than <FormsTenantForm />.
  components: [
    { path: '~/components', pathPrefix: false }
  ],

  pwa: {
    // Avoid Workbox "no files match" error from .nuxt/dev-sw-dist in dev
    disable: process.env.NODE_ENV === 'development',
    registerType: 'autoUpdate',
    manifest: {
      name: 'AdhereMed',
      short_name: 'AdhereMed',
      description: 'AdhereMed - Connected Healthcare Simplified.',
      theme_color: '#2DD4BF',
      background_color: '#0F172A',
      display: 'standalone',
      orientation: 'any',
      start_url: '/',
      scope: '/',
      lang: 'en',
      icons: [
        { src: '/icons/icon-192.png', sizes: '192x192', type: 'image/png' },
        { src: '/icons/icon-512.png', sizes: '512x512', type: 'image/png' },
        { src: '/icons/icon-maskable-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' }
      ]
    },
    workbox: {
      navigateFallback: '/',
      navigateFallbackDenylist: [/^\/api\//],
      globPatterns: ['**/*.{js,css,html,svg,png,ico,woff,woff2}'],
      cleanupOutdatedCaches: true,
      runtimeCaching: [
        {
          // Google Fonts stylesheet
          urlPattern: /^https:\/\/fonts\.googleapis\.com\/.*/i,
          handler: 'StaleWhileRevalidate',
          options: { cacheName: 'google-fonts-stylesheets' }
        },
        {
          // Google Fonts files
          urlPattern: /^https:\/\/fonts\.gstatic\.com\/.*/i,
          handler: 'CacheFirst',
          options: {
            cacheName: 'google-fonts-webfonts',
            expiration: { maxEntries: 30, maxAgeSeconds: 60 * 60 * 24 * 365 },
            cacheableResponse: { statuses: [0, 200] }
          }
        },
        {
          // Backend API — never cache aggressively (auth-sensitive)
          urlPattern: ({ url }) => url.pathname.includes('/api/'),
          handler: 'NetworkFirst',
          options: {
            cacheName: 'api-cache',
            networkTimeoutSeconds: 5,
            expiration: { maxEntries: 50, maxAgeSeconds: 60 * 5 },
            cacheableResponse: { statuses: [200] }
          }
        },
        {
          // Images
          urlPattern: ({ request }) => request.destination === 'image',
          handler: 'CacheFirst',
          options: {
            cacheName: 'images',
            expiration: { maxEntries: 100, maxAgeSeconds: 60 * 60 * 24 * 30 }
          }
        }
      ]
    },
    client: {
      installPrompt: true,
      periodicSyncForUpdates: 3600
    },
    devOptions: {
      enabled: true,
      type: 'module',
      navigateFallback: '/'
    }
  },

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
      // apiBase: 'http://ec2-3-120-129-138.eu-central-1.compute.amazonaws.com/api',
      // apiBase: 'https://adheremedapi.tiktek-ex.com/api',
      appName: 'AdhereMed'
    }
  }
})
