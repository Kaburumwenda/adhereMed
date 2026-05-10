// Mirrors the role/tenant-aware sidebar from lib/features/shell/shell_screen.dart
// Each section: { label, items: [{ icon, label, path, children? }] }

export function getNavSections(role, tenantType) {
  const sections = []
  const isSuperAdmin = role === 'super_admin'

  if (isSuperAdmin) {
    sections.push({
      label: 'SUPER ADMIN',
      items: [
        { icon: 'mdi-shield-account', label: 'Overview', path: '/superadmin' },
        { icon: 'mdi-domain', label: 'Tenants', path: '/superadmin/tenants' },
        { icon: 'mdi-account-multiple', label: 'All Users', path: '/superadmin/users' },
        {
          icon: 'mdi-cash-multiple', label: 'Usage Billing', path: '/superadmin/billing',
          children: [
            { icon: 'mdi-chart-line', label: 'Overview', path: '/superadmin/billing' },
            { icon: 'mdi-tune', label: 'Rates', path: '/superadmin/billing/rates' },
            { icon: 'mdi-stethoscope', label: 'Doctor Commissions', path: '/superadmin/billing/doctors' }
          ]
        },
        { icon: 'mdi-database', label: 'Seed Data', path: '/superadmin/seed' },
        { icon: 'mdi-hospital-box', label: 'Clinical Catalog', path: '/superadmin/clinical-catalog' },
        { icon: 'mdi-bookshelf', label: 'Catalog Manager', path: '/admin/catalog' },
        { icon: 'mdi-domain-plus', label: 'New Tenant', path: '/superadmin/tenants/new' }
      ]
    })
    return sections
  }

  sections.push({
    label: '',
    items: [{ icon: 'mdi-view-dashboard', label: 'Dashboard', path: '/dashboard' }]
  })

  const hospitalRoles = ['tenant_admin', 'hospital_admin', 'doctor', 'clinical_officer', 'dentist', 'nurse', 'midwife', 'receptionist', 'lab_tech', 'radiologist', 'pharmacist', 'cashier', 'admin']
  if (tenantType === 'hospital' && hospitalRoles.includes(role)) {
    const hospitalItems = [
        { icon: 'mdi-account-multiple', label: 'Patients', path: '/patients' },
        { icon: 'mdi-calendar', label: 'Appointments', path: '/appointments' },
        { icon: 'mdi-medical-bag', label: 'Consultations', path: '/consultations' },
        {
          icon: 'mdi-pill', label: 'Prescriptions', path: '/prescriptions',
          children: [
            { icon: 'mdi-format-list-bulleted', label: 'View Prescriptions', path: '/prescriptions' },
            { icon: 'mdi-note-edit', label: 'Write Prescription', path: '/prescriptions/new' }
          ]
        },
        { icon: 'mdi-microscope', label: 'Lab Orders', path: '/lab-orders' },
        { icon: 'mdi-image', label: 'Radiology', path: '/radiology' },
        { icon: 'mdi-heart-pulse', label: 'Triage', path: '/triage' },
        { icon: 'mdi-bed', label: 'Wards', path: '/wards' },
        { icon: 'mdi-receipt-text', label: 'Billing', path: '/invoices' },
        {
          icon: 'mdi-bank', label: 'Accounts', path: '/accounts',
          children: [
            { icon: 'mdi-view-dashboard-outline', label: 'Overview', path: '/accounts' },
            { icon: 'mdi-cash-fast', label: 'Receivables', path: '/accounts?tab=receivables' },
            { icon: 'mdi-cash-clock', label: 'Payables', path: '/accounts?tab=payables' },
            { icon: 'mdi-swap-vertical', label: 'Transactions', path: '/accounts?tab=transactions' },
            { icon: 'mdi-chart-box', label: 'Profit &amp; Loss', path: '/accounts?tab=pnl' }
          ]
        },
        {
          icon: 'mdi-cash-minus', label: 'Expenses', path: '/expenses',
          children: [
            { icon: 'mdi-format-list-bulleted', label: 'View Expenses', path: '/expenses' },
            { icon: 'mdi-plus-circle', label: 'New Expense', path: '/expenses/new' },
            { icon: 'mdi-shape', label: 'Categories', path: '/expenses/categories' }
          ]
        },
        { icon: 'mdi-domain', label: 'Departments', path: '/departments' }
    ]
    if (['doctor', 'clinical_officer', 'dentist'].includes(role)) {
      hospitalItems.splice(3, 0, { icon: 'mdi-percent', label: 'My Commission', path: '/billing/commission' })
    }
    sections.push({ label: 'HOSPITAL', items: hospitalItems })
  }

  const pharmacyRoles = ['tenant_admin', 'pharmacy_admin', 'pharmacist', 'pharmacy_tech', 'cashier', 'admin']
  if (tenantType === 'pharmacy' && pharmacyRoles.includes(role)) {
    sections.push({
      label: 'PHARMACY',
      items: [
        { icon: 'mdi-point-of-sale', label: 'POS', path: '/pos' },
        { icon: 'mdi-cash-register', label: 'Cashier Shifts', path: '/pos/shifts' },
        { icon: 'mdi-receipt-text', label: 'Patient Orders', path: '/pharmacy-orders' },
        {
          icon: 'mdi-package-variant', label: 'Inventory', path: '/inventory',
          children: [
            { icon: 'mdi-pill', label: 'Stock Items', path: '/inventory' },
            { icon: 'mdi-shape', label: 'Categories', path: '/categories' },
            { icon: 'mdi-ruler', label: 'Units', path: '/units' },
            { icon: 'mdi-tune', label: 'Adjustments', path: '/adjustments' },
            { icon: 'mdi-chart-line', label: 'Stock Analysis', path: '/inventory/stock-analysis' },
            { icon: 'mdi-clipboard-list-outline', label: 'Stock Take', path: '/inventory/stock-take' },
            { icon: 'mdi-truck-delivery-outline', label: 'Branch Transfers', path: '/inventory/transfers' },
            { icon: 'mdi-shield-lock-outline', label: 'Controlled Register', path: '/inventory/controlled-register' }
          ]
        },
        {
          icon: 'mdi-chart-bar', label: 'Analytics', path: '/analytics',
          children: [
            { icon: 'mdi-chart-bar', label: 'Overview', path: '/analytics' },
            { icon: 'mdi-shape', label: 'Category Sales', path: '/analytics/categories' },
            { icon: 'mdi-trophy', label: 'Top Products', path: '/analytics/products' }
          ]
        },
        { icon: 'mdi-clipboard-text', label: 'Reports', path: '/reports',
          children: [
            { icon: 'mdi-view-dashboard', label: 'Reports Hub', path: '/reports' },
            { icon: 'mdi-chart-box-multiple', label: 'Analytics Dashboard', path: '/reports/analytics' }
          ]
        },
        {
          icon: 'mdi-receipt-text', label: 'Invoices', path: '/invoices',
          children: [
            { icon: 'mdi-format-list-bulleted', label: 'All Invoices', path: '/invoices' },
            { icon: 'mdi-plus-circle', label: 'New Invoice', path: '/invoices/new' }
          ]
        },
        { icon: 'mdi-cash-multiple', label: 'API Billing', path: '/billing/usage' },
        {
          icon: 'mdi-bank', label: 'Accounts', path: '/accounts',
          children: [
            { icon: 'mdi-view-dashboard-outline', label: 'Overview', path: '/accounts' },
            { icon: 'mdi-cash-fast', label: 'Receivables', path: '/accounts?tab=receivables' },
            { icon: 'mdi-cash-clock', label: 'Payables', path: '/accounts?tab=payables' },
            { icon: 'mdi-swap-vertical', label: 'Transactions', path: '/accounts?tab=transactions' },
            { icon: 'mdi-chart-box', label: 'Profit &amp; Loss', path: '/accounts?tab=pnl' }
          ]
        },
        { icon: 'mdi-truck', label: 'Deliveries', path: '/deliveries' },
        { icon: 'mdi-cart', label: 'Purchase Orders', path: '/purchase-orders' },
        {
          icon: 'mdi-cash-minus', label: 'Expenses', path: '/expenses',
          children: [
            { icon: 'mdi-format-list-bulleted', label: 'View Expenses', path: '/expenses' },
            { icon: 'mdi-plus-circle', label: 'New Expense', path: '/expenses/new' },
            { icon: 'mdi-shape', label: 'Categories', path: '/expenses/categories' }
          ]
        },
        {
          icon: 'mdi-clipboard-check', label: 'Dispensing', path: '/dispensing',
          children: [
            { icon: 'mdi-clipboard-check', label: 'Dispense Records', path: '/dispensing' },
            { icon: 'mdi-keyboard-return', label: 'Returns', path: '/dispensing/returns' }
          ]
        },
        { icon: 'mdi-history', label: 'Sales History', path: '/pos/history' },
        { icon: 'mdi-tray-arrow-up', label: 'On-Hold Sales', path: '/pos/parked' },
        { icon: 'mdi-pill-multiple', label: 'Prescriptions', path: '/pharmacy-rx' },
        { icon: 'mdi-bell-alert', label: 'Alerts', path: '/alerts' },
        {
          icon: 'mdi-shield-account', label: 'Insurance', path: '/insurance',
          children: [
            { icon: 'mdi-file-document', label: 'Claims', path: '/insurance' },
            { icon: 'mdi-domain', label: 'Providers', path: '/insurance/providers' }
          ]
        },
        {
          icon: 'mdi-pill', label: 'Medications', path: '/medications',
          children: [
            { icon: 'mdi-pill', label: 'Catalog', path: '/medications' },
            { icon: 'mdi-pill-multiple', label: 'Drug Interactions', path: '/medications/interactions' }
          ]
        },
        {
          icon: 'mdi-account-cog', label: 'IAM', path: '/staff',
          children: [
            { icon: 'mdi-account-multiple', label: 'Customers', path: '/customers' },
            { icon: 'mdi-star-circle', label: 'Loyalty', path: '/pos/loyalty' },
            { icon: 'mdi-badge-account', label: 'Staff', path: '/staff' },
            { icon: 'mdi-school', label: 'Specializations', path: '/specializations' },
            { icon: 'mdi-podium', label: 'Performance', path: '/staff-performance' },
            { icon: 'mdi-truck', label: 'Suppliers', path: '/suppliers' }
          ]
        },
        { icon: 'mdi-cog', label: 'Settings', path: '/settings' },
        { icon: 'mdi-bank', label: 'Branches', path: '/branches' }
      ]
    })
  }

  if (tenantType === 'lab' && ['tenant_admin', 'lab_admin', 'lab_tech', 'admin'].includes(role)) {
    sections.push({
      label: 'LABORATORY',
      items: [{ icon: 'mdi-clock-alert', label: 'Lab Requests', path: '/lab-exchange' }]
    })
  }

  const homecareAdminRoles = ['tenant_admin', 'homecare_admin', 'admin']
  if (tenantType === 'homecare' && homecareAdminRoles.includes(role)) {
    sections.push({
      label: 'CARE OPERATIONS',
      items: [
        {
          icon: 'mdi-account-group', label: 'Patients', path: '/homecare/patients',
          children: [
            { icon: 'mdi-account-multiple',        label: 'All Patients',    path: '/homecare/patients' },
            { icon: 'mdi-account-plus',            label: 'Enrol Patient',   path: '/homecare/patients/new' },
            { icon: 'mdi-account-tie',             label: 'Care Team',       path: '/homecare/caregivers' },
            { icon: 'mdi-clipboard-text',          label: 'Treatment Plans', path: '/homecare/treatment-plans' },
            { icon: 'mdi-pill',                    label: 'Medications',     path: '/homecare/medications' },
            { icon: 'mdi-pill-multiple',           label: 'Doses',           path: '/homecare/doses' },
            { icon: 'mdi-heart-pulse',             label: 'Vitals',          path: '/homecare/vitals' },
            { icon: 'mdi-note-edit',               label: 'Care Notes',      path: '/homecare/notes' },
            { icon: 'mdi-file-document-check',     label: 'Consents',        path: '/homecare/consents' },
            { icon: 'mdi-shield-account',          label: 'Insurance',       path: '/homecare/insurance' }
          ]
        },
        { icon: 'mdi-account-heart', label: 'Caregivers', path: '/homecare/caregivers' },
        { icon: 'mdi-account-switch', label: 'Assignments', path: '/homecare/assignments' },
        {
          icon: 'mdi-calendar-clock', label: 'Schedules', path: '/homecare/schedules',
          children: [
            { icon: 'mdi-format-list-bulleted', label: 'Visit list', path: '/homecare/schedules' },
            { icon: 'mdi-calendar-month', label: 'Calendar', path: '/homecare/calendar' }
          ]
        },
        { icon: 'mdi-clipboard-text', label: 'Treatment Plans', path: '/homecare/treatment-plans' },
        { icon: 'mdi-heart-pulse', label: 'Vitals & Observations', path: '/homecare/vitals' },
        { icon: 'mdi-note-edit', label: 'Care Notes', path: '/homecare/notes' }
      ]
    })
    sections.push({
      label: 'MEDICATIONS',
      items: [
        {
          icon: 'mdi-pill', label: 'Medications', path: '/homecare/medications',
          children: [
            { icon: 'mdi-pill', label: 'Schedules', path: '/homecare/medications' },
            { icon: 'mdi-pill-multiple', label: 'Doses', path: '/homecare/doses' }
          ]
        },
        { icon: 'mdi-prescription', label: 'Prescriptions', path: '/homecare/prescriptions' }
      ]
    })
    sections.push({
      label: 'TELEHEALTH & ALERTS',
      items: [
        { icon: 'mdi-video', label: 'Teleconsult', path: '/homecare/teleconsult' },
        { icon: 'mdi-alert-octagram', label: 'Escalations', path: '/homecare/escalations' },
        { icon: 'mdi-inbox', label: 'Inbox', path: '/homecare/inbox' },
        {
          icon: 'mdi-email', label: 'Mail', path: '/homecare/mail',
          children: [
            { icon: 'mdi-inbox-multiple', label: 'Mailbox', path: '/homecare/mail' },
            { icon: 'mdi-cog', label: 'Mail Settings', path: '/homecare/mail/settings' }
          ]
        }
      ]
    })
    sections.push({
      label: 'FAMILY & ADMIN',
      items: [
        { icon: 'mdi-account-multiple-plus', label: 'Family Portal', path: '/homecare/family' },
        { icon: 'mdi-shield-account', label: 'Insurance', path: '/homecare/insurance' },
        { icon: 'mdi-cash-register', label: 'Billing', path: '/homecare/billing' },
        { icon: 'mdi-cash-multiple', label: 'API Billing', path: '/billing/usage' },
        {
          icon: 'mdi-cash-minus', label: 'Expenses', path: '/expenses',
          children: [
            { icon: 'mdi-format-list-bulleted', label: 'View Expenses', path: '/expenses' },
            { icon: 'mdi-plus-circle', label: 'New Expense', path: '/expenses/new' },
            { icon: 'mdi-shape', label: 'Categories', path: '/expenses/categories' }
          ]
        },
        { icon: 'mdi-medical-bag', label: 'Equipment', path: '/homecare/equipment' },
        { icon: 'mdi-file-document-check', label: 'Consents', path: '/homecare/consents' }
      ]
    })
    sections.push({
      label: 'ANALYTICS',
      items: [
        { icon: 'mdi-chart-box', label: 'Reports', path: '/homecare/reports' },
        { icon: 'mdi-history', label: 'Audit Log', path: '/homecare/audit' },
        { icon: 'mdi-book-cog', label: 'Clinical Catalog', path: '/homecare/catalog' },
        { icon: 'mdi-domain', label: 'Company Profile', path: '/homecare/company-profile' }
      ]
    })
    sections.push({
      label: 'CLINICAL TOOLS',
      items: [
        { icon: 'mdi-clipboard-pulse', label: 'Clinical Protocols', path: '/homecare/protocols' },
        { icon: 'mdi-pulse',           label: 'EWS Scoring',        path: '/homecare/ews' }
      ]
    })
  }

  if (tenantType === 'homecare' && role === 'caregiver') {
    sections.push({
      label: 'MY WORK',
      items: [
        { icon: 'mdi-calendar-today', label: 'My Day', path: '/homecare/my-day' },
        {
          icon: 'mdi-account-group', label: 'My Patients', path: '/homecare/patients',
          children: [
            { icon: 'mdi-account-multiple',    label: 'All Patients',    path: '/homecare/patients' },
            { icon: 'mdi-clipboard-text',      label: 'Treatment Plans', path: '/homecare/treatment-plans' },
            { icon: 'mdi-pill',                label: 'Medications',     path: '/homecare/medications' },
            { icon: 'mdi-pill-multiple',       label: 'Doses',           path: '/homecare/doses' },
            { icon: 'mdi-heart-pulse',         label: 'Vitals',          path: '/homecare/vitals' },
            { icon: 'mdi-note-edit',           label: 'Care Notes',      path: '/homecare/notes' },
            { icon: 'mdi-file-document-check', label: 'Consents',        path: '/homecare/consents' },
            { icon: 'mdi-shield-account',      label: 'Insurance',       path: '/homecare/insurance' }
          ]
        },
        { icon: 'mdi-pill-multiple', label: 'Doses', path: '/homecare/doses' },
        { icon: 'mdi-note-edit', label: 'Notes', path: '/homecare/notes' }
      ]
    })
  }

  if (tenantType === 'homecare' && role === 'patient') {
    sections.push({
      label: 'MY HOMECARE',
      items: [
        { icon: 'mdi-home-heart', label: 'My Care', path: '/my-homecare' },
        { icon: 'mdi-pill', label: 'My Doses', path: '/my-homecare?tab=doses' },
        { icon: 'mdi-video', label: 'Teleconsult', path: '/my-homecare?tab=teleconsult' },
        { icon: 'mdi-shield-account', label: 'Insurance', path: '/my-homecare?tab=insurance' }
      ]
    })
  }

  if (['patient', 'admin'].includes(role)) {
    sections.push({
      label: 'MY HEALTH',
      items: [
        { icon: 'mdi-account-circle', label: 'My Profile', path: '/my-profile' },
        { icon: 'mdi-receipt', label: 'My Prescriptions', path: '/my-prescriptions' },
        {
          icon: 'mdi-pharmacy', label: 'Pharmacies', path: '/pharmacy-store',
          children: [
            { icon: 'mdi-storefront', label: 'Browse Pharmacies', path: '/pharmacy-store' },
            { icon: 'mdi-receipt-text', label: 'My Orders', path: '/pharmacy-store/orders' }
          ]
        },
        { icon: 'mdi-magnify', label: 'Find Doctors', path: '/doctors' },
        { icon: 'mdi-chat', label: 'Messages', path: '/messages' }
      ]
    })
  }

  if (['doctor', 'clinical_officer', 'dentist'].includes(role)) {
    sections.push({
      label: 'MY PRACTICE',
      items: [
        { icon: 'mdi-account-circle', label: 'My Profile', path: '/doctor-profile' },
        { icon: 'mdi-magnify', label: 'Doctor Directory', path: '/doctors' },
        {
          icon: 'mdi-pill', label: 'Prescriptions', path: '/prescriptions',
          children: [
            { icon: 'mdi-format-list-bulleted', label: 'View Prescriptions', path: '/prescriptions' },
            { icon: 'mdi-note-edit', label: 'Write Prescription', path: '/prescriptions/new' }
          ]
        },
        { icon: 'mdi-chat', label: 'Messages', path: '/messages' }
      ]
    })
  }

  return sections
}
