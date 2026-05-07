# AdhereMed — Nuxt Frontend

Hospital & Pharmacy Ecosystem — Nuxt 3 + Vuetify 3 web frontend.

> This is a port of the Flutter app located in `../frontend`. **Phases 1–11
> are now complete**: foundation (theming, API client, auth, layout shell)
> plus all feature modules — dashboards, clinical workflows, billing,
> pharmacy operations, patient portal, messaging, and super admin. See
> the **Implemented routes** section below for the full route map.

## Tech stack

| Concern             | Library                          | Mirrors Flutter |
|---------------------|----------------------------------|-----------------|
| Framework           | Nuxt 3 (SPA mode)                | Flutter app     |
| UI components       | Vuetify 3 (Material Design 3)    | `material.dart` |
| State management    | Pinia                            | Riverpod        |
| HTTP                | Axios                            | Dio             |
| Routing             | Nuxt file-based router + middleware | go_router    |
| Persistence         | `localStorage`                   | flutter_secure_storage |
| Icons               | Material Design Icons (`@mdi/font`) | Material Icons |
| Fonts               | Inter (Google Fonts)             | google_fonts    |

## Project structure

```
nuxtfrontend/
├── app.vue                    # Root: <v-app><NuxtLayout/></v-app>
├── nuxt.config.js             # Modules, Vuetify, runtime config
├── package.json
├── assets/
│   └── css/main.css           # Global styles + brand utilities
├── components/
│   ├── BrandLogo.vue          # Heart icon in gradient square
│   ├── BrandMark.vue          # "Adhere" + "Med" wordmark
│   ├── SideNav.vue            # Role/tenant-aware sidebar
│   └── TopBar.vue             # App bar with theme + user menu
├── layouts/
│   ├── default.vue            # Authenticated shell (sidebar + topbar)
│   └── auth.vue               # Empty pass-through for auth pages
├── middleware/
│   └── auth.global.js         # Mirrors GoRouter redirect
├── pages/
│   ├── welcome.vue            # Landing
│   ├── login.vue              # Sign in
│   ├── register.vue           # Patient sign up
│   ├── register-facility.vue  # Tenant (hospital/pharmacy/lab) sign up
│   ├── forgot-password.vue
│   ├── reset-password.vue
│   ├── dashboard.vue          # Authenticated landing
│   └── [...slug].vue          # Placeholder for feature pages not yet built
├── plugins/
│   ├── api.client.js          # Axios instance + JWT/tenant interceptors
│   ├── theme-init.client.js   # Restore theme from localStorage
│   └── vuetify.js             # 4 themes (light, dark, ocean, sunset)
├── stores/
│   ├── auth.js                # Login / register / logout / restore session
│   └── theme.js               # Persisted theme switcher
└── utils/
    ├── constants.js           # API base URL, storage keys
    ├── nav.js                 # Sidebar sections per role + tenant
    └── palettes.js            # 4 colour palettes (matches theme.dart)
```

## Mapping to the Flutter source

| Flutter file                                              | Nuxt equivalent                              |
|-----------------------------------------------------------|----------------------------------------------|
| `lib/core/constants.dart`                                 | `utils/constants.js`                         |
| `lib/core/theme.dart` (palettes + AppThemeModeNotifier)   | `utils/palettes.js` + `stores/theme.js`      |
| `lib/core/network/api_client.dart`                        | `plugins/api.client.js`                      |
| `lib/core/router.dart` (auth redirect)                    | `middleware/auth.global.js`                  |
| `lib/features/auth/repository/auth_repository.dart`       | `stores/auth.js` (actions)                   |
| `lib/features/auth/providers/auth_provider.dart`          | `stores/auth.js` (state)                     |
| `lib/features/shell/shell_screen.dart`                    | `layouts/default.vue` + `components/SideNav.vue` + `components/TopBar.vue` |
| `lib/features/auth/screens/welcome_screen.dart`           | `pages/welcome.vue`                          |
| `lib/features/auth/screens/login_screen.dart`             | `pages/login.vue`                            |
| `lib/features/auth/screens/register_screen.dart`          | `pages/register.vue`                         |
| `lib/features/auth/screens/tenant_register_screen.dart`   | `pages/register-facility.vue`                |
| `lib/features/auth/screens/forgot_password_screen.dart`   | `pages/forgot-password.vue`                  |
| `lib/features/auth/screens/reset_password_screen.dart`    | `pages/reset-password.vue`                   |

## Themes

Four themes are ported 1:1 from `theme.dart`: **light**, **dark**
(default), **ocean**, **sunset**. Cycle through them via the palette button
in the top bar. Selection is persisted in `localStorage`.

## API integration

`plugins/api.client.js` configures axios with:

- `baseURL` from `runtimeConfig.public.apiBase` (default
  `http://127.0.0.1:8000/api` — matches the Django backend in `../backend`).
- `Authorization: Bearer <token>` automatically attached.
- `X-Tenant-Schema` automatically attached for non-public endpoints,
  identical to the Flutter `_AuthInterceptor` logic.

Override the API URL in production via env:

```
NUXT_PUBLIC_API_BASE=https://api.example.com/api
```

## Auth & routing rules

`middleware/auth.global.js` mirrors the GoRouter redirect logic:

- Unauthenticated users on protected routes → `/welcome`.
- Authenticated users on auth routes → `/dashboard`.

Auth routes: `/welcome`, `/login`, `/register`, `/register-facility`,
`/register-doctor`, `/forgot-password`, `/reset-password`.

## Sidebar navigation

`utils/nav.js` reproduces the role + tenant aware sidebar from
`shell_screen.dart`. Sections shown depend on `user.role` and
`user.tenant_type`:

- `super_admin` → only **SUPER ADMIN** section
- `hospital` tenant → **HOSPITAL** section (patients, appointments, etc.)
- `pharmacy` tenant → **PHARMACY** section (POS, inventory, dispensing, etc.)
- `lab` tenant → **LABORATORY** section
- `patient` role → **MY HEALTH** section
- `doctor` / `clinical_officer` / `dentist` → **MY PRACTICE** section

Most of these target paths still resolve to the catch-all
`pages/[...slug].vue` placeholder until their feature modules are built.

## Run it

```bash
cd nuxtfrontend
npm install
npm run dev          # http://localhost:3000
```

Build for production:

```bash
npm run build
npm run preview
```

## Roadmap (next phases)

| Phase | Modules                                                                                  | Status |
|-------|------------------------------------------------------------------------------------------|--------|
| 1     | Foundation (theming, auth, layout, routing)                                              | ✅ Done |
| 2     | Dashboards (hospital / pharmacy / lab / doctor / patient)                                | ✅ Done |
| 3     | Patients, Appointments, Consultations, Departments                                       | ✅ Done |
| 4     | Prescriptions, Lab orders, Radiology, Triage, Wards                                      | ✅ Done |
| 5     | Billing                                                                                  | ✅ Done |
| 6     | Pharmacy: Inventory, Categories, Units, Adjustments                                      | ✅ Done |
| 7     | Pharmacy: POS, Dispensing, Purchase orders, Suppliers                                    | ✅ Done |
| 8     | Pharmacy: Analytics, Reports, Branches, Customers, Staff, Specializations                | ✅ Done |
| 9     | Patient portal: pharmacy store, cart, orders, exchange                                   | ✅ Done |
| 10    | Doctors directory, Messaging                                                             | ✅ Done |
| 11    | Super Admin: tenants, users, seed data, clinical catalog, catalog manager                | ✅ Done |

## Implemented routes

### Clinical (hospital tenant)
- `/patients`, `/patients/new`, `/patients/:id`, `/patients/:id/edit`
- `/appointments`, `/appointments/new`, `/appointments/:id`, `/appointments/:id/edit`
- `/consultations`, `/consultations/new`, `/consultations/:id`, `/consultations/:id/edit`
- `/departments`, `/departments/new`, `/departments/:id/edit`
- `/prescriptions`, `/prescriptions/new`, `/prescriptions/:id`, `/prescriptions/:id/edit`
- `/lab/orders`, `/lab/orders/new`, `/lab/orders/:id`, `/lab/orders/:id/edit`
- `/radiology`, `/radiology/new`, `/radiology/:id/edit`
- `/triage`, `/triage/new`, `/triage/:id/edit`
- `/wards/wards`, `/wards/wards/new`, `/wards/wards/:id`, `/wards/wards/:id/edit`
- `/wards/beds`, `/wards/beds/new`, `/wards/beds/:id/edit`
- `/billing/invoices`, `/billing/invoices/new`, `/billing/invoices/:id`, `/billing/invoices/:id/edit`

### Pharmacy operations
- `/inventory` — tabbed (stocks / categories / units / adjustments)
- `/inventory/stocks/new`, `/inventory/stocks/:id/edit` (also categories/units/adjustments)
- `/pos` — point of sale
- `/dispensing`, `/dispensing/new`, `/dispensing/:id/edit`
- `/purchase-orders/orders`, `/purchase-orders/orders/new`, `/purchase-orders/orders/:id`, `/purchase-orders/orders/:id/edit`
- `/suppliers`, `/suppliers/new`, `/suppliers/:id/edit`
- `/analytics`, `/reports`
- `/pharmacy_profile/branches`, `/pharmacy_profile/branches/new`, `/pharmacy_profile/branches/:id/edit`
- `/pos/customers`, `/pos/customers/new`, `/pos/customers/:id/edit`
- `/accounts/staff/performance`
- `/doctors/specializations`, `.../new`, `.../:id/edit`

### Patient portal
- `/pharmacy-store` — browse pharmacies
- `/pharmacy-store/:id` — pharmacy products
- `/pharmacy-store/cart` — checkout
- `/pharmacy-store/orders`, `/pharmacy-store/orders/:id`
- `/my-prescriptions`, `/my-profile`

### Pharmacy-side orders
- `/pharmacy-orders`, `/pharmacy-orders/:id`

### Doctors & messaging
- `/doctors`, `/doctors/:id`, `/doctor-profile`
- `/messages`, `/messages/:id` (with 8s polling)

### Super Admin
- `/superadmin`
- `/superadmin/tenants`, `.../new`, `.../:id/edit`
- `/superadmin/users`, `.../new`, `.../:id/edit`
- `/superadmin/clinical-catalog` — tabbed
- `/superadmin/admin-catalog`
- `/superadmin/seed`

## Reusable patterns

All feature modules use the same conventions:

- **`composables/useResource.js`** — generic CRUD wrapper (list/get/create/update/remove + search/filtered/loading/saving)
- **`components/ResourceListPage.vue`** — list w/ search, table, delete confirm
- **`components/ResourceFormPage.vue`** — create/edit form scaffold
- **`components/ResourceDetailPage.vue`** + **`components/InfoGrid.vue`** — detail view
- **`components/forms/<Entity>Form.vue`** — shared form definition; `pages/<x>/new.vue` and `pages/<x>/[id]/edit.vue` simply render it. Forms detect create vs edit from `route.params.id`.
- **`utils/format.js`** — `formatDate`, `formatDateTime`, `formatMoney` (KES), `formatRole`
