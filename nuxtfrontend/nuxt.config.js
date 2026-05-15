// https://nuxt.com/docs/api/configuration/nuxt-config
import { resolve } from 'path'
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
      appName: 'AdhereMed',
      googleMapsApiKey: 'AIzaSyAhiNO62geg58-WaLGeq235Lo8gySLvs_I'
    }
  },

  hooks: {
    'pages:extend'(pages) {
      // Alias existing pages under /pharmacy/ so pharmacy tenants get
      // their own URL namespace while reusing the same page components.
      const pagesDir = resolve(__dirname, 'pages')
      const aliases = [
        // POS
        ['pharmacy-pos',                      '/pharmacy/pos',                            'pos/index.vue'],
        ['pharmacy-pos-shifts',               '/pharmacy/pos/shifts',                     'pos/shifts.vue'],
        ['pharmacy-pos-history',              '/pharmacy/pos/history',                    'pos/history.vue'],
        ['pharmacy-pos-parked',               '/pharmacy/pos/parked',                     'pos/parked.vue'],
        ['pharmacy-pos-loyalty',              '/pharmacy/pos/loyalty',                    'pos/loyalty.vue'],
        ['pharmacy-pos-supermarket',          '/pharmacy/pos/supermarket',                'pos/supermarket.vue'],
        // Orders
        ['pharmacy-orders',                   '/pharmacy/orders',                         'pharmacy-orders/index.vue'],
        ['pharmacy-orders-id',                '/pharmacy/orders/:id()',                   'pharmacy-orders/[id].vue'],
        // Inventory
        ['pharmacy-inventory',                '/pharmacy/inventory',                      'inventory/index.vue'],
        ['pharmacy-inventory-bulk',           '/pharmacy/inventory/bulk',                 'inventory/bulk.vue'],
        ['pharmacy-inventory-stock-analysis', '/pharmacy/inventory/stock-analysis',       'inventory/stock-analysis.vue'],
        ['pharmacy-inventory-stock-take',     '/pharmacy/inventory/stock-take',           'inventory/stock-take.vue'],
        ['pharmacy-inventory-transfers',      '/pharmacy/inventory/transfers',            'inventory/transfers.vue'],
        ['pharmacy-inventory-controlled',     '/pharmacy/inventory/controlled-register',  'inventory/controlled-register.vue'],
        ['pharmacy-inventory-stocks-new',     '/pharmacy/inventory/stocks/new',           'inventory/stocks/new.vue'],
        ['pharmacy-inventory-stocks-id-edit', '/pharmacy/inventory/stocks/:id()/edit',    'inventory/stocks/[id]/edit.vue'],
        ['pharmacy-inventory-cats-new',       '/pharmacy/inventory/categories/new',       'inventory/categories/new.vue'],
        ['pharmacy-inventory-cats-id-edit',   '/pharmacy/inventory/categories/:id()/edit','inventory/categories/[id]/edit.vue'],
        ['pharmacy-inventory-units-new',      '/pharmacy/inventory/units/new',            'inventory/units/new.vue'],
        ['pharmacy-inventory-units-id-edit',  '/pharmacy/inventory/units/:id()/edit',     'inventory/units/[id]/edit.vue'],
        ['pharmacy-inventory-adj-new',        '/pharmacy/inventory/adjustments/new',      'inventory/adjustments/new.vue'],
        ['pharmacy-inventory-adj-id-edit',    '/pharmacy/inventory/adjustments/:id()/edit','inventory/adjustments/[id]/edit.vue'],
        // Categories / Units / Adjustments (top-level shortcuts)
        ['pharmacy-categories',               '/pharmacy/categories',                     'categories/index.vue'],
        ['pharmacy-units',                    '/pharmacy/units',                          'units/index.vue'],
        ['pharmacy-adjustments',              '/pharmacy/adjustments',                    'adjustments/index.vue'],
        // Analytics
        ['pharmacy-analytics',                '/pharmacy/analytics',                      'analytics/index.vue'],
        ['pharmacy-analytics-categories',     '/pharmacy/analytics/categories',           'analytics/categories.vue'],
        ['pharmacy-analytics-products',       '/pharmacy/analytics/products',             'analytics/products.vue'],
        // Reports
        ['pharmacy-reports',                  '/pharmacy/reports',                        'reports/index.vue'],
        ['pharmacy-reports-analytics',        '/pharmacy/reports/analytics',              'reports/analytics.vue'],
        ['pharmacy-reports-key',              '/pharmacy/reports/:key()',                 'reports/[key].vue'],
        // Invoices
        ['pharmacy-invoices',                 '/pharmacy/invoices',                       'invoices/index.vue'],
        ['pharmacy-invoices-new',             '/pharmacy/invoices/new',                   'invoices/new.vue'],
        ['pharmacy-invoices-id',              '/pharmacy/invoices/:id()',                 'invoices/[id]/index.vue'],
        ['pharmacy-invoices-id-edit',         '/pharmacy/invoices/:id()/edit',            'invoices/[id]/edit.vue'],
        // Accounts
        ['pharmacy-accounts',                 '/pharmacy/accounts',                       'accounts.vue'],
        // Expenses
        ['pharmacy-expenses',                 '/pharmacy/expenses',                       'expenses/index.vue'],
        ['pharmacy-expenses-new',             '/pharmacy/expenses/new',                   'expenses/new.vue'],
        ['pharmacy-expenses-categories',      '/pharmacy/expenses/categories',            'expenses/categories.vue'],
        ['pharmacy-expenses-id',              '/pharmacy/expenses/:id()',                 'expenses/[id]/index.vue'],
        ['pharmacy-expenses-id-edit',         '/pharmacy/expenses/:id()/edit',            'expenses/[id]/edit.vue'],
        // Deliveries
        ['pharmacy-deliveries',               '/pharmacy/deliveries',                     'deliveries/index.vue'],
        // Purchase Orders
        ['pharmacy-purchase-orders',          '/pharmacy/purchase-orders',                'purchase-orders/index.vue'],
        ['pharmacy-purchase-orders-new',      '/pharmacy/purchase-orders/new',            'purchase-orders/new.vue'],
        ['pharmacy-purchase-orders-id',       '/pharmacy/purchase-orders/:id()',          'purchase-orders/[id]/index.vue'],
        ['pharmacy-purchase-orders-id-edit',  '/pharmacy/purchase-orders/:id()/edit',     'purchase-orders/[id]/edit.vue'],
        // Dispensing
        ['pharmacy-dispensing',               '/pharmacy/dispensing',                     'dispensing/index.vue'],
        ['pharmacy-dispensing-new',           '/pharmacy/dispensing/new',                 'dispensing/new.vue'],
        ['pharmacy-dispensing-returns',       '/pharmacy/dispensing/returns',             'dispensing/returns.vue'],
        // Prescriptions (Rx)
        ['pharmacy-rx',                       '/pharmacy/rx',                             'pharmacy-rx/index.vue'],
        // Insurance
        ['pharmacy-insurance',                '/pharmacy/insurance',                      'insurance/index.vue'],
        ['pharmacy-insurance-providers',      '/pharmacy/insurance/providers',            'insurance/providers.vue'],
        // Medications
        ['pharmacy-medications',              '/pharmacy/medications',                    'medications/index.vue'],
        ['pharmacy-medications-interactions', '/pharmacy/medications/interactions',       'medications/interactions.vue'],
        // Customers
        ['pharmacy-customers',                '/pharmacy/customers',                      'customers.vue'],
        ['pharmacy-customers-index',          '/pharmacy/customers/index',                'customers/index.vue'],
        ['pharmacy-customers-new',            '/pharmacy/customers/new',                  'customers/new.vue'],
        ['pharmacy-customers-id-edit',        '/pharmacy/customers/:id()/edit',           'customers/[id]/edit.vue'],
        // Staff
        ['pharmacy-staff',                    '/pharmacy/staff',                          'staff/index.vue'],
        // Specializations
        ['pharmacy-specializations',          '/pharmacy/specializations',                'specializations.vue'],
        ['pharmacy-specializations-index',    '/pharmacy/specializations/index',          'specializations/index.vue'],
        ['pharmacy-specializations-new',      '/pharmacy/specializations/new',            'specializations/new.vue'],
        ['pharmacy-specializations-id-edit',  '/pharmacy/specializations/:id()/edit',     'specializations/[id]/edit.vue'],
        // Staff Performance
        ['pharmacy-staff-performance',        '/pharmacy/staff-performance',              'staff-performance.vue'],
        ['pharmacy-staff-performance-index',  '/pharmacy/staff-performance/index',        'staff-performance/index.vue'],
        // Suppliers
        ['pharmacy-suppliers',                '/pharmacy/suppliers',                      'suppliers/index.vue'],
        ['pharmacy-suppliers-new',            '/pharmacy/suppliers/new',                  'suppliers/new.vue'],
        ['pharmacy-suppliers-id-edit',        '/pharmacy/suppliers/:id()/edit',           'suppliers/[id]/edit.vue'],
        // Settings
        ['pharmacy-settings',                 '/pharmacy/settings',                       'settings/index.vue'],
        // Branches
        ['pharmacy-branches',                 '/pharmacy/branches',                       'branches/index.vue'],
        ['pharmacy-branches-new',             '/pharmacy/branches/new',                   'branches/new.vue'],
        ['pharmacy-branches-id-edit',         '/pharmacy/branches/:id()/edit',            'branches/[id]/edit.vue'],
      ]
      for (const [name, path, file] of aliases) {
        pages.push({ name, path, file: resolve(pagesDir, file) })
      }
    }
  }
})

// GOOGLE KEYS
// MAP API KEY: AIzaSyAhiNO62geg58-WaLGeq235Lo8gySLvs_I
