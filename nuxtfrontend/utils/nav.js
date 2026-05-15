// Mirrors the role/tenant-aware sidebar from lib/features/shell/shell_screen.dart
// Each section: { label, items: [{ icon, label, path, children? }] }

export function getNavSections(role, tenantType, t = (x) => x) {
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
    items: [{
      icon: 'mdi-view-dashboard',
      label: 'Dashboard',
      path: tenantType === 'lab' ? '/lab' : tenantType === 'pharmacy' ? '/pharmacy' : tenantType === 'radiology_center' ? '/radiology' : '/dashboard'
    }]
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
      label: t('nav.pharmacy'),
      items: [
        { icon: 'mdi-point-of-sale', label: t('nav.pos'), path: '/pharmacy/pos' },
        {
          icon: 'mdi-bank', label: t('nav.accountsFinance'), path: '/pharmacy/accounts',
          children: [
            { icon: 'mdi-view-dashboard-outline', label: t('nav.overview'), path: '/pharmacy/accounts' },
            { icon: 'mdi-history', label: t('nav.salesHistory'), path: '/pharmacy/pos/history' },
            { icon: 'mdi-account-cash-outline', label: t('nav.credits'), path: '/pharmacy/credit' },
            { icon: 'mdi-cart', label: t('nav.purchaseOrders'), path: '/pharmacy/purchase-orders' },
            { icon: 'mdi-receipt-text', label: t('nav.invoices'), path: '/pharmacy/invoices' },
            { icon: 'mdi-cash-minus', label: t('nav.expenses'), path: '/pharmacy/expenses' },
            { icon: 'mdi-tray-arrow-up', label: t('nav.onHoldSales'), path: '/pharmacy/pos/parked' },
          ]
        },
        { icon: 'mdi-cash-register', label: t('nav.cashierShifts'), path: '/pharmacy/pos/shifts' },
        { icon: 'mdi-receipt-text', label: t('nav.orders'), path: '/pharmacy/orders' },
        {
          icon: 'mdi-package-variant', label: t('nav.inventory'), path: '/pharmacy/inventory',
          children: [
            { icon: 'mdi-pill', label: t('nav.stockItems'), path: '/pharmacy/inventory' },
            { icon: 'mdi-shape', label: t('nav.categories'), path: '/pharmacy/categories' },
            { icon: 'mdi-ruler', label: t('nav.units'), path: '/pharmacy/units' },
            { icon: 'mdi-tune', label: t('nav.adjustments'), path: '/pharmacy/adjustments' },
            { icon: 'mdi-chart-line', label: t('nav.stockAnalysis'), path: '/pharmacy/inventory/stock-analysis' },
            { icon: 'mdi-clipboard-list-outline', label: t('nav.stockTake'), path: '/pharmacy/inventory/stock-take' },
            { icon: 'mdi-truck-delivery-outline', label: t('nav.branchTransfers'), path: '/pharmacy/inventory/transfers' },
            { icon: 'mdi-shield-lock-outline', label: t('nav.controlledRegister'), path: '/pharmacy/inventory/controlled-register' }
          ]
        },
        {
          icon: 'mdi-chart-bar', label: t('nav.analytics'), path: '/pharmacy/analytics',
          children: [
            { icon: 'mdi-chart-bar', label: t('nav.overview'), path: '/pharmacy/analytics' },
            { icon: 'mdi-shape', label: t('nav.categorySales'), path: '/pharmacy/analytics/categories' },
            { icon: 'mdi-trophy', label: t('nav.products'), path: '/pharmacy/analytics/products' }
          ]
        },
        { icon: 'mdi-clipboard-text', label: t('nav.reports'), path: '/pharmacy/reports' },
        { icon: 'mdi-cash-multiple', label: t('nav.apiBilling'), path: '/pharmacy/billing/usage' },
        { icon: 'mdi-truck', label: t('nav.deliveries'), path: '/pharmacy/deliveries' },
        {
          icon: 'mdi-clipboard-check', label: t('nav.dispensing'), path: '/pharmacy/dispensing',
          children: [
            { icon: 'mdi-clipboard-check', label: t('nav.dispenseRecords'), path: '/pharmacy/dispensing' },
            { icon: 'mdi-keyboard-return', label: t('nav.returns'), path: '/pharmacy/dispensing/returns' }
          ]
        },
        { icon: 'mdi-pill-multiple', label: t('nav.prescriptions'), path: '/pharmacy/rx' },
        { icon: 'mdi-bell-alert', label: t('nav.alerts'), path: '/pharmacy/alerts' },
        { icon: 'mdi-shield-account', label: t('nav.insurance'), path: '/pharmacy/insurance' },
        {
          icon: 'mdi-pill', label: t('nav.medications'), path: '/pharmacy/medications',
          children: [
            { icon: 'mdi-pill', label: t('nav.catalog'), path: '/pharmacy/medications' },
            { icon: 'mdi-pill-multiple', label: t('nav.drugInteractions'), path: '/pharmacy/medications/interactions' }
          ]
        },
        {
          icon: 'mdi-account-cog', label: t('nav.iam'), path: '/pharmacy/staff',
          children: [
            { icon: 'mdi-account-multiple', label: t('nav.customers'), path: '/pharmacy/customers' },
            { icon: 'mdi-star-circle', label: t('nav.loyalty'), path: '/pharmacy/pos/loyalty' },
            { icon: 'mdi-badge-account', label: t('nav.staff'), path: '/pharmacy/staff' },
            { icon: 'mdi-school', label: t('nav.specializations'), path: '/pharmacy/specializations' },
            { icon: 'mdi-podium', label: t('nav.performance'), path: '/pharmacy/staff-performance' },
            { icon: 'mdi-truck', label: t('nav.suppliers'), path: '/pharmacy/suppliers' }
          ]
        },
        { icon: 'mdi-cog', label: t('nav.settings'), path: '/pharmacy/settings' },
        {
          icon: 'mdi-gift', label: 'Referrals', path: '/pharmacy/referral',
          children: [
            { icon: 'mdi-view-dashboard', label: 'Dashboard', path: '/pharmacy/referral' },
            { icon: 'mdi-chart-line', label: 'Performance', path: '/pharmacy/referral/performance' }
          ]
        },
        { icon: 'mdi-bank', label: t('nav.branches'), path: '/pharmacy/branches' }
      ]
    })
  }

  if (tenantType === 'lab' && ['tenant_admin', 'lab_admin', 'lab_tech', 'admin'].includes(role)) {
    sections.push({
      label: 'LAB OPERATIONS',
      items: [
        { icon: 'mdi-account-multiple', label: 'Patients', path: '/patients' },
        {
          icon: 'mdi-clipboard-text-clock', label: 'Requisitions', path: '/lab/requisitions',
          children: [
            { icon: 'mdi-format-list-bulleted', label: 'All Requisitions', path: '/lab/requisitions' },
            { icon: 'mdi-plus-circle', label: 'New Requisition', path: '/lab/requisitions/new' },
            { icon: 'mdi-clock-alert', label: 'External (Exchange)', path: '/lab-exchange' }
          ]
        },
        { icon: 'mdi-barcode-scan', label: 'Accessioning', path: '/lab/accessioning' },
        { icon: 'mdi-test-tube', label: 'Worklist', path: '/lab/worklist' },
        { icon: 'mdi-file-chart', label: 'Results & Reports', path: '/lab/results' },
        { icon: 'mdi-home-import-outline', label: 'Home Visits', path: '/lab/home-visits' }
      ]
    })
    sections.push({
      label: 'CATALOG & REFERRING',
      items: [
        { icon: 'mdi-flask-outline', label: 'Tests', path: '/lab/catalog' },
        { icon: 'mdi-package-variant', label: 'Test Panels', path: '/lab/panels' },
        { icon: 'mdi-stethoscope', label: 'Referring Doctors', path: '/lab/referring/doctors' },
        { icon: 'mdi-hospital-building', label: 'Referring Facilities', path: '/lab/referring/facilities' }
      ]
    })
    sections.push({
      label: 'QUALITY & EQUIPMENT',
      items: [
        { icon: 'mdi-chart-bell-curve-cumulative', label: 'Quality Control', path: '/lab/qc' },
        { icon: 'mdi-cog-transfer', label: 'Instruments', path: '/lab/instruments' },
        { icon: 'mdi-test-tube', label: 'Reagents', path: '/lab/reagents' }
      ]
    })
    sections.push({
      label: 'BILLING & FINANCE',
      items: [
        { icon: 'mdi-receipt-text', label: 'Invoices', path: '/lab/billing' },
        { icon: 'mdi-bank', label: 'Accounts', path: '/lab/accounts' },
        { icon: 'mdi-cash-minus', label: 'Expenses', path: '/lab/expenses' },
        { icon: 'mdi-shield-account', label: 'Insurance', path: '/lab/insurance' },
        { icon: 'mdi-cash-multiple', label: 'API Billing', path: '/lab/api/billing' }
      ]
    })
    sections.push({
      label: 'ADMIN & ANALYTICS',
      items: [
        { icon: 'mdi-account-group', label: 'Staff', path: '/lab/staff' },
        { icon: 'mdi-bank', label: 'Branches', path: '/lab/branches' },
        { icon: 'mdi-printer-pos', label: 'Report Templates', path: '/lab/report-templates' },
        { icon: 'mdi-bell', label: 'Notifications', path: '/lab/notifications' },
        { icon: 'mdi-cog', label: 'Settings', path: '/lab/settings' }
      ]
    })
  }

  // ── Radiology Center ──────────────────────────────────────────────
  const radiologyRoles = ['tenant_admin', 'radiology_admin', 'radiologist', 'lab_tech', 'admin']
  if (tenantType === 'radiology_center' && radiologyRoles.includes(role)) {
    sections.push({
      label: 'WORKLIST & ORDERS',
      items: [
        { icon: 'mdi-account-multiple', label: 'Patients', path: '/radiology/patients' },
        {
          icon: 'mdi-clipboard-text-clock', label: 'Orders', path: '/radiology/orders',
          children: [
            { icon: 'mdi-format-list-bulleted', label: 'All Orders', path: '/radiology/orders' },
            { icon: 'mdi-plus-circle', label: 'New Order', path: '/radiology/orders/new' }
          ]
        },
        { icon: 'mdi-clipboard-list-outline', label: 'Worklist', path: '/radiology/worklist' },
        { icon: 'mdi-calendar-clock', label: 'Scheduling', path: '/radiology/scheduling' }
      ]
    })
    sections.push({
      label: 'REPORTING',
      items: [
        { icon: 'mdi-file-chart', label: 'Reports', path: '/radiology/reports' },
        { icon: 'mdi-printer-pos', label: 'Report Templates', path: '/radiology/report-templates' },
        { icon: 'mdi-alert-octagram', label: 'Critical Findings', path: '/radiology/critical-findings' }
      ]
    })
    sections.push({
      label: 'CATALOG & REFERRING',
      items: [
        { icon: 'mdi-flask-outline', label: 'Exam Catalog', path: '/radiology/catalog' },
        { icon: 'mdi-package-variant', label: 'Exam Panels', path: '/radiology/panels' },
        { icon: 'mdi-stethoscope', label: 'Referring Doctors', path: '/radiology/referring/doctors' },
        { icon: 'mdi-hospital-building', label: 'Referring Facilities', path: '/radiology/referring/facilities' }
      ]
    })
    sections.push({
      label: 'EQUIPMENT & QC',
      items: [
        { icon: 'mdi-cog-transfer', label: 'Modalities / Equipment', path: '/radiology/equipment' },
        { icon: 'mdi-chart-bell-curve-cumulative', label: 'Quality Control', path: '/radiology/qc' }
      ]
    })
    sections.push({
      label: 'BILLING & FINANCE',
      items: [
        { icon: 'mdi-receipt-text', label: 'Invoices', path: '/radiology/billing' },
        { icon: 'mdi-bank', label: 'Accounts', path: '/radiology/accounts' },
        { icon: 'mdi-cash-minus', label: 'Expenses', path: '/radiology/expenses' },
        { icon: 'mdi-cash-multiple', label: 'API Billing', path: '/radiology/api/billing' }
      ]
    })
    sections.push({
      label: 'ADMIN & ANALYTICS',
      items: [
        { icon: 'mdi-account-group', label: 'Staff', path: '/radiology/staff' },
        { icon: 'mdi-chart-bar', label: 'Analytics', path: '/radiology/analytics' },
        { icon: 'mdi-bank', label: 'Branches', path: '/radiology/branches' },
        { icon: 'mdi-bell', label: 'Notifications', path: '/radiology/notifications' },
        { icon: 'mdi-cog', label: 'Settings', path: '/radiology/settings' }
      ]
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
