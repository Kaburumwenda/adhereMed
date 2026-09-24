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
        { name: 'theme-color', content: '#0D9488' },
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
      theme_color: '#0D9488',
      background_color: '#F8FAFC',
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
      // SPA (ssr:false) precaches the file 'index.html', not the route '/'.
      // Using '/' here causes 'non-precached-url' on post-login navigations
      // because createHandlerBoundToURL('/') can't find '/' in the precache.
      navigateFallback: 'index.html',
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
      navigateFallback: 'index.html'
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
      //  apiBase: 'http://127.0.0.1:8000/api',
      // // apiBase: 'http://ec2-3-120-129-138.eu-central-1.compute.amazonaws.com/api',
      // apiBase: 'https://adheremedapi.tiktek-ex.com/api',
      apiBase: 'https://apisys.adheremed.co/api',
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
        // POS — now uses file-system routes in pages/pharmacy/pos/
        // Orders
        ['pharmacy-orders',                   '/pharmacy/orders',                         'pharmacy-orders/index.vue'],
        ['pharmacy-orders-id',                '/pharmacy/orders/:id()',                   'pharmacy-orders/[id].vue'],
        // Inventory
        ['pharmacy-inventory',                '/pharmacy/inventory',                      'inventory/index.vue'],
        ['pharmacy-inventory-overview',       '/pharmacy/inventory/overview',             'inventory/overview.vue'],
        ['pharmacy-inventory-bulk',           '/pharmacy/inventory/bulk',                 'inventory/bulk.vue'],
        ['pharmacy-inventory-excel',          '/pharmacy/inventory/excel',                'inventory/excel.vue'],
        ['pharmacy-inventory-stock-analysis', '/pharmacy/inventory/stock-analysis',       'inventory/stock-analysis.vue'],
        ['pharmacy-inventory-stock-take',     '/pharmacy/inventory/stock-take',           'inventory/stock-take.vue'],
        ['pharmacy-inventory-transfers',      '/pharmacy/inventory/transfers',            'inventory/transfers.vue'],
        ['pharmacy-inventory-controlled',     '/pharmacy/inventory/controlled-register',  'inventory/controlled-register.vue'],
        ['pharmacy-inventory-stock-movements', '/pharmacy/inventory/stock-movements',     'inventory/stock-movements.vue'],
        ['pharmacy-inventory-stocks-new',     '/pharmacy/inventory/stocks/new',           'inventory/stocks/new.vue'],
        ['pharmacy-inventory-stocks-id',      '/pharmacy/inventory/stocks/:id()',         'inventory/stocks/[id]/index.vue'],
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
        ['pharmacy-expenses-excel',          '/pharmacy/expenses/excel',                'expenses/excel.vue'],
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
        ['pharmacy-purchase-orders-id-edit',           '/pharmacy/purchase-orders/:id()/edit',  'purchase-orders/[id]/edit.vue'],
        // Sales Orders
        ['pharmacy-sales-orders',                      '/pharmacy/sales-orders',                   'sales-orders/index.vue'],
        ['pharmacy-sales-orders-new',                  '/pharmacy/sales-orders/new',               'sales-orders/new.vue'],
        ['pharmacy-sales-orders-id',                   '/pharmacy/sales-orders/:id()',             'sales-orders/[id]/index.vue'],
        ['pharmacy-sales-orders-id-edit',              '/pharmacy/sales-orders/:id()/edit',        'sales-orders/[id]/edit.vue'],
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
        // Roles & Access (RBAC)
        ['pharmacy-rbac',                    '/pharmacy/rbac',                           'administration/rbac.vue'],
        // System Health (under IAM & Security)
        ['pharmacy-system-health',           '/pharmacy/system-health',                 'iam/system-health.vue'],
        // Suppliers
        ['pharmacy-suppliers',                '/pharmacy/suppliers',                      'suppliers/index.vue'],
        ['pharmacy-suppliers-new',            '/pharmacy/suppliers/new',                  'suppliers/new.vue'],
        ['pharmacy-suppliers-id-edit',        '/pharmacy/suppliers/:id()/edit',           'suppliers/[id]/edit.vue'],
        // Settings
        ['pharmacy-settings',                 '/pharmacy/settings',                       'settings/index.vue'],
        // Setup / Seed
        ['pharmacy-setup',                    '/pharmacy/setup',                          'setup/index.vue'],
        // Branches
        ['pharmacy-branches',                 '/pharmacy/branches',                       'branches/index.vue'],
        ['pharmacy-branches-new',             '/pharmacy/branches/new',                   'branches/new.vue'],
        ['pharmacy-branches-id-edit',         '/pharmacy/branches/:id()/edit',            'branches/[id]/edit.vue'],

        // ── Inventory / Warehouse tenant aliases (independent tenant) ────────
        // Inventory tenants get their own /ims URL namespace, reusing the same
        // shared inventory + procurement + finance page components that the
        // pharmacy tenant exposes under /pharmacy, plus their own dashboard
        // (pages/ims/index.vue is file-based).
        // Inventory
        ['ims-inventory',                     '/ims/inventory',                           'inventory/index.vue'],
        ['ims-inventory-overview',            '/ims/inventory/overview',                  'inventory/overview.vue'],
        ['ims-inventory-bulk',                '/ims/inventory/bulk',                      'inventory/bulk.vue'],
        ['ims-inventory-excel',               '/ims/inventory/excel',                     'inventory/excel.vue'],
        ['ims-inventory-stock-analysis',       '/ims/inventory/stock-analysis',            'inventory/stock-analysis.vue'],
        ['ims-inventory-stock-take',           '/ims/inventory/stock-take',                'inventory/stock-take.vue'],
        ['ims-inventory-transfers',            '/ims/inventory/transfers',                 'inventory/transfers.vue'],
        ['ims-inventory-controlled',           '/ims/inventory/controlled-register',       'inventory/controlled-register.vue'],
        ['ims-inventory-stock-movements',     '/ims/inventory/stock-movements',          'inventory/stock-movements.vue'],
        ['ims-inventory-stocks-new',           '/ims/inventory/stocks/new',                'inventory/stocks/new.vue'],
        ['ims-inventory-stocks-id',            '/ims/inventory/stocks/:id()',             'inventory/stocks/[id]/index.vue'],
        ['ims-inventory-stocks-id-edit',       '/ims/inventory/stocks/:id()/edit',         'inventory/stocks/[id]/edit.vue'],
        ['ims-inventory-cats-new',             '/ims/inventory/categories/new',            'inventory/categories/new.vue'],
        ['ims-inventory-cats-id-edit',         '/ims/inventory/categories/:id()/edit',     'inventory/categories/[id]/edit.vue'],
        ['ims-inventory-units-new',            '/ims/inventory/units/new',                'inventory/units/new.vue'],
        ['ims-inventory-units-id-edit',        '/ims/inventory/units/:id()/edit',         'inventory/units/[id]/edit.vue'],
        ['ims-inventory-adj-new',              '/ims/inventory/adjustments/new',          'inventory/adjustments/new.vue'],
        ['ims-inventory-adj-id-edit',          '/ims/inventory/adjustments/:id()/edit',   'inventory/adjustments/[id]/edit.vue'],
        // Catalog
        ['ims-categories',                    '/ims/categories',                          'categories/index.vue'],
        ['ims-units',                         '/ims/units',                               'units/index.vue'],
        ['ims-medications',                   '/ims/medications',                         'medications/index.vue'],
        ['ims-adjustments',                   '/ims/adjustments',                         'adjustments/index.vue'],
        // Stock alerts
        ['ims-alerts',                        '/ims/alerts',                              'alerts/index.vue'],
        // Sales — POS
        ['ims-pos',                           '/ims/pos',                                 'pos/index.vue'],
        ['ims-pos-history',                   '/ims/pos/history',                         'pos/history.vue'],
        ['ims-pos-parked',                    '/ims/pos/parked',                          'pos/parked.vue'],
        ['ims-pos-shifts',                    '/ims/pos/shifts',                           'pos/shifts.vue'],
        ['ims-pos-supermarket',               '/ims/pos/supermarket',                      'pos/supermarket.vue'],
        // Sales — customers
        ['ims-customers',                     '/ims/customers',                            'customers/index.vue'],
        ['ims-customers-new',                 '/ims/customers/new',                        'customers/new.vue'],
        ['ims-customers-id-edit',            '/ims/customers/:id()/edit',                'customers/[id]/edit.vue'],
        // Sales — credit management
        ['ims-credit',                        '/ims/credit',                               'pharmacy/credit/index.vue'],
        // Sales — sales orders
        ['ims-sales-orders',                  '/ims/sales-orders',                         'sales-orders/index.vue'],
        ['ims-sales-orders-new',              '/ims/sales-orders/new',                     'sales-orders/new.vue'],
        ['ims-sales-orders-id',               '/ims/sales-orders/:id()',                   'sales-orders/[id]/index.vue'],
        ['ims-sales-orders-id-edit',         '/ims/sales-orders/:id()/edit',              'sales-orders/[id]/edit.vue'],
        // Sales — deliveries
        ['ims-deliveries',                    '/ims/deliveries',                           'deliveries/index.vue'],
        // Purchase Orders
        ['ims-purchase-orders',               '/ims/purchase-orders',                     'purchase-orders/index.vue'],
        ['ims-purchase-orders-new',           '/ims/purchase-orders/new',                 'purchase-orders/new.vue'],
        ['ims-purchase-orders-id',             '/ims/purchase-orders/:id()',               'purchase-orders/[id]/index.vue'],
        ['ims-purchase-orders-id-edit',        '/ims/purchase-orders/:id()/edit',          'purchase-orders/[id]/edit.vue'],
        // Suppliers
        ['ims-suppliers',                     '/ims/suppliers',                           'suppliers/index.vue'],
        ['ims-suppliers-new',                 '/ims/suppliers/new',                       'suppliers/new.vue'],
        ['ims-suppliers-id-edit',             '/ims/suppliers/:id()/edit',                'suppliers/[id]/edit.vue'],
        // Warehouses (branches)
        ['ims-branches',                      '/ims/branches',                            'branches/index.vue'],
        ['ims-branches-new',                  '/ims/branches/new',                        'branches/new.vue'],
        ['ims-branches-id-edit',              '/ims/branches/:id()/edit',                 'branches/[id]/edit.vue'],
        // Accounts
        ['ims-accounts',                      '/ims/accounts',                             'accounts.vue'],
        // Invoices
        ['ims-invoices',                      '/ims/invoices',                             'invoices/index.vue'],
        ['ims-invoices-new',                  '/ims/invoices/new',                         'invoices/new.vue'],
        ['ims-invoices-id',                   '/ims/invoices/:id()',                       'invoices/[id]/index.vue'],
        ['ims-invoices-id-edit',              '/ims/invoices/:id()/edit',                  'invoices/[id]/edit.vue'],
        // Expenses
        ['ims-expenses',                      '/ims/expenses',                             'expenses/index.vue'],
        ['ims-expenses-excel',               '/ims/expenses/excel',                       'expenses/excel.vue'],
        ['ims-expenses-new',                 '/ims/expenses/new',                         'expenses/new.vue'],
        ['ims-expenses-categories',          '/ims/expenses/categories',                  'expenses/categories.vue'],
        ['ims-expenses-id',                  '/ims/expenses/:id()',                       'expenses/[id]/index.vue'],
        ['ims-expenses-id-edit',             '/ims/expenses/:id()/edit',                  'expenses/[id]/edit.vue'],
        // API Billing
        ['ims-billing-usage',                '/ims/billing/usage',                        'billing/usage.vue'],
        // Analytics
        ['ims-analytics',                     '/ims/analytics',                            'analytics/index.vue'],
        ['ims-analytics-categories',          '/ims/analytics/categories',                 'analytics/categories.vue'],
        ['ims-analytics-products',            '/ims/analytics/products',                   'analytics/products.vue'],
        // Reports
        ['ims-reports',                       '/ims/reports',                              'reports/index.vue'],
        ['ims-reports-analytics',             '/ims/reports/analytics',                    'reports/analytics.vue'],
        ['ims-reports-key',                   '/ims/reports/:key()',                       'reports/[key].vue'],
        // Organization (tenant profile)
        ['ims-organization-profile',          '/ims/organization/profile',               'organization/profile.vue'],
        // Staff
        ['ims-staff',                         '/ims/staff',                                'staff/index.vue'],
        // Roles & Access (RBAC)
        ['ims-rbac',                          '/ims/rbac',                                 'administration/rbac.vue'],
        // Audit logs + system health
        ['ims-audit-logs',                    '/ims/audit-logs',                           'pharmacy/audit-logs/index.vue'],
        ['ims-system-health',                 '/ims/system-health',                        'iam/system-health.vue'],
        // Settings + setup
        ['ims-settings',                      '/ims/settings',                             'settings/index.vue'],
        ['ims-setup',                         '/ims/setup',                                'setup/index.vue'],

        // ── Hospital tenant aliases ──────────────────────────────────────────
        // Hospital tenants get their own /hos URL namespace, reusing the same
        // shared page components. Radiology and lab orders keep their own
        // namespaces since those page trees are shared with radiology_center
        // and lab tenants respectively.
        // Dashboard
        ['hos-dashboard',                    '/hos',                                      'dashboard.vue'],
        // Patients
        ['hos-patients',                      '/hos/patients',                             'patients/index.vue'],
        ['hos-patients-new',                   '/hos/patients/new',                         'patients/new.vue'],
        ['hos-patients-id',                   '/hos/patients/:id()',                       'patients/[id]/index.vue'],
        ['hos-patients-id-edit',               '/hos/patients/:id()/edit',                  'patients/[id]/edit.vue'],
        // Appointments
        ['hos-appointments',                   '/hos/appointments',                         'appointments/index.vue'],
        ['hos-appointments-new',               '/hos/appointments/new',                     'appointments/new.vue'],
        ['hos-appointments-id',                '/hos/appointments/:id()',                  'appointments/[id]/index.vue'],
        ['hos-appointments-id-edit',           '/hos/appointments/:id()/edit',             'appointments/[id]/edit.vue'],
        // Consultations
        ['hos-consultations',                  '/hos/consultations',                        'consultations/index.vue'],
        ['hos-consultations-new',              '/hos/consultations/new',                    'consultations/new.vue'],
        ['hos-consultations-id',               '/hos/consultations/:id()',                 'consultations/[id]/index.vue'],
        ['hos-consultations-id-edit',          '/hos/consultations/:id()/edit',             'consultations/[id]/edit.vue'],
        // Prescriptions
        ['hos-prescriptions',                  '/hos/prescriptions',                        'prescriptions/index.vue'],
        ['hos-prescriptions-new',              '/hos/prescriptions/new',                    'prescriptions/new.vue'],
        ['hos-prescriptions-id',               '/hos/prescriptions/:id()',                  'prescriptions/[id]/index.vue'],
        ['hos-prescriptions-id-edit',          '/hos/prescriptions/:id()/edit',             'prescriptions/[id]/edit.vue'],
        // Lab Orders
        ['hos-lab-orders',                     '/hos/lab-orders',                           'lab-orders/index.vue'],
        ['hos-lab-orders-new',                 '/hos/lab-orders/new',                       'lab-orders/new.vue'],
        ['hos-lab-orders-id',                  '/hos/lab-orders/:id()',                    'lab-orders/[id]/index.vue'],
        ['hos-lab-orders-id-edit',             '/hos/lab-orders/:id()/edit',                'lab-orders/[id]/edit.vue'],
        // Triage
        ['hos-triage',                         '/hos/triage',                               'triage/index.vue'],
        ['hos-triage-new',                     '/hos/triage/new',                           'triage/new.vue'],
        ['hos-triage-id-edit',                 '/hos/triage/:id()/edit',                    'triage/[id]/edit.vue'],
        // Wards
        ['hos-wards',                          '/hos/wards',                                'wards/index.vue'],
        ['hos-wards-new',                      '/hos/wards/new',                            'wards/new.vue'],
        ['hos-wards-id',                       '/hos/wards/:id()',                          'wards/[id]/index.vue'],
        ['hos-wards-id-edit',                  '/hos/wards/:id()/edit',                     'wards/[id]/edit.vue'],
        // Invoices (Billing)
        ['hos-invoices',                       '/hos/invoices',                             'invoices/index.vue'],
        ['hos-invoices-new',                   '/hos/invoices/new',                         'invoices/new.vue'],
        ['hos-invoices-id',                    '/hos/invoices/:id()',                       'invoices/[id]/index.vue'],
        ['hos-invoices-id-edit',               '/hos/invoices/:id()/edit',                  'invoices/[id]/edit.vue'],
        // Accounts
        ['hos-accounts',                       '/hos/accounts',                             'accounts.vue'],
        // Expenses
        ['hos-expenses',                       '/hos/expenses',                             'expenses/index.vue'],
        ['hos-expenses-new',                   '/hos/expenses/new',                         'expenses/new.vue'],
        ['hos-expenses-categories',            '/hos/expenses/categories',                  'expenses/categories.vue'],
        ['hos-expenses-id',                    '/hos/expenses/:id()',                       'expenses/[id]/index.vue'],
        ['hos-expenses-id-edit',               '/hos/expenses/:id()/edit',                  'expenses/[id]/edit.vue'],
        // Departments
        ['hos-departments',                    '/hos/departments',                          'departments/index.vue'],
        ['hos-departments-new',                '/hos/departments/new',                      'departments/new.vue'],
        ['hos-departments-id-edit',            '/hos/departments/:id()/edit',              'departments/[id]/edit.vue'],
        // Billing (commission / usage / locked / overdue / bills)
        ['hos-billing-commission',             '/hos/billing/commission',                   'billing/commission.vue'],
        ['hos-billing-usage',                  '/hos/billing/usage',                        'billing/usage.vue'],
        ['hos-billing-locked',                 '/hos/billing/locked',                       'billing/locked.vue'],
        ['hos-billing-overdue',                '/hos/billing/overdue',                      'billing/overdue.vue'],
        // Alerts
        ['hos-alerts',                         '/hos/alerts',                               'alerts/index.vue'],
        // Messages
        ['hos-messages',                       '/hos/messages',                             'messages/index.vue'],
        ['hos-messages-id',                    '/hos/messages/:id()',                       'messages/[id].vue'],
        // Doctors directory
        ['hos-doctors',                        '/hos/doctors',                              'doctors/index.vue'],
        ['hos-doctors-id',                     '/hos/doctors/:id()',                        'doctors/[id].vue'],
        // Staff
        ['hos-staff',                          '/hos/staff',                                'staff/index.vue'],
        // My Profile / My Prescriptions / Doctor Profile / My Homecare
        ['hos-my-profile',                     '/hos/my-profile',                           'my-profile.vue'],
        ['hos-my-prescriptions',               '/hos/my-prescriptions',                     'my-prescriptions.vue'],
        ['hos-doctor-profile',                 '/hos/doctor-profile',                      'doctor-profile.vue'],
        ['hos-my-homecare',                    '/hos/my-homecare',                          'my-homecare.vue'],
      ]
      for (const [name, path, file] of aliases) {
        pages.push({ name, path, file: resolve(pagesDir, file) })
      }
    }
  }
})

// GOOGLE KEYS
// MAP API KEY: AIzaSyAhiNO62geg58-WaLGeq235Lo8gySLvs_I
