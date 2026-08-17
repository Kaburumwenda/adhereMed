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
            { icon: 'mdi-cash-fast', label: 'Payments', path: '/superadmin/billing/payments' },
            { icon: 'mdi-tune', label: 'Rates', path: '/superadmin/billing/rates' },
            { icon: 'mdi-ticket-percent', label: 'Coupons', path: '/superadmin/billing/coupons' },
            { icon: 'mdi-stethoscope', label: 'Doctor Commissions', path: '/superadmin/billing/doctors' }
          ]
        },
        { icon: 'mdi-circle-multiple', label: 'Adhere Coins', path: '/superadmin/coins' },
        { icon: 'mdi-account-arrow-right', label: 'Referrals', path: '/superadmin/referrals' },
        { icon: 'mdi-database', label: 'Seed Data', path: '/superadmin/seed' },
        { icon: 'mdi-hospital-box', label: 'Clinical Catalog', path: '/superadmin/clinical-catalog' },
        { icon: 'mdi-bookshelf', label: 'Catalog Manager', path: '/admin/catalog' },
        { icon: 'mdi-email-cog', label: 'Mail Settings', path: '/superadmin/mail' },
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
      path: tenantType === 'lab' ? '/lab' : tenantType === 'pharmacy' ? '/pharmacy' : tenantType === 'radiology_center' ? '/radiology' : tenantType === 'hospital' ? '/hos' : tenantType === 'clinic' ? '/clinics' : '/dashboard'
    }]
  })

  const hospitalRoles = ['tenant_admin', 'hospital_admin', 'doctor', 'clinical_officer', 'dentist', 'nurse', 'midwife', 'receptionist', 'lab_tech', 'radiologist', 'pharmacist', 'cashier', 'admin']
  if (tenantType === 'hospital' && hospitalRoles.includes(role)) {
    const hospitalItems = [
        { icon: 'mdi-account-multiple', label: 'Patients', path: '/hos/patients' },
        { icon: 'mdi-calendar', label: 'Appointments', path: '/hos/appointments' },
        { icon: 'mdi-medical-bag', label: 'Consultations', path: '/hos/consultations' },
        {
          icon: 'mdi-pill', label: 'Prescriptions', path: '/hos/prescriptions',
          children: [
            { icon: 'mdi-format-list-bulleted', label: 'View Prescriptions', path: '/hos/prescriptions' },
            { icon: 'mdi-note-edit', label: 'Write Prescription', path: '/hos/prescriptions/new' }
          ]
        },
        { icon: 'mdi-microscope', label: 'Lab Orders', path: '/hos/lab-orders' },
        { icon: 'mdi-image', label: 'Radiology', path: '/radiology' },
        { icon: 'mdi-heart-pulse', label: 'Triage', path: '/hos/triage' },
        { icon: 'mdi-bed', label: 'Wards', path: '/hos/wards' },
        { icon: 'mdi-receipt-text', label: 'Billing', path: '/hos/invoices' },
        {
          icon: 'mdi-bank', label: 'Accounts', path: '/hos/accounts',
          children: [
            { icon: 'mdi-view-dashboard-outline', label: 'Overview', path: '/hos/accounts' },
            { icon: 'mdi-cash-fast', label: 'Receivables', path: '/hos/accounts?tab=receivables' },
            { icon: 'mdi-cash-clock', label: 'Payables', path: '/hos/accounts?tab=payables' },
            { icon: 'mdi-swap-vertical', label: 'Transactions', path: '/hos/accounts?tab=transactions' },
            { icon: 'mdi-chart-box', label: 'Profit &amp; Loss', path: '/hos/accounts?tab=pnl' }
          ]
        },
        {
          icon: 'mdi-cash-minus', label: 'Expenses', path: '/hos/expenses',
          children: [
            { icon: 'mdi-format-list-bulleted', label: 'View Expenses', path: '/hos/expenses' },
            { icon: 'mdi-plus-circle', label: 'New Expense', path: '/hos/expenses/new' },
            { icon: 'mdi-shape', label: 'Categories', path: '/hos/expenses/categories' }
          ]
        },
        { icon: 'mdi-domain', label: 'Departments', path: '/hos/departments' }
    ]
    if (['doctor', 'clinical_officer', 'dentist'].includes(role)) {
      hospitalItems.splice(3, 0, { icon: 'mdi-percent', label: 'My Commission', path: '/hos/billing/commission' })
    }
    sections.push({ label: 'HOSPITAL', items: hospitalItems })
  }

  // ── CLINIC tenant type ──────────────────────────────────────────────────
  // Clinic tenants get a comprehensive system covering all 9 guide modules:
  // patient management, doctor dashboard, pharmacy/labs/billing,
  // caregiver & homecare, admin & reporting, data protection, emergencies.
  const clinicRoles = ['tenant_admin', 'clinic_admin', 'doctor', 'clinical_officer', 'dentist', 'nurse', 'midwife', 'receptionist', 'lab_tech', 'radiologist', 'pharmacist', 'cashier', 'admin']
  if (tenantType === 'clinic' && clinicRoles.includes(role)) {
    const clinicItems = [
        // Patient Management
        { icon: 'mdi-account-multiple', label: 'Patients', path: '/clinics/patients' },
        { icon: 'mdi-calendar', label: 'Appointments', path: '/clinics/appointments' },
        { icon: 'mdi-medical-bag', label: 'Consultations', path: '/clinics/consultations' },
        // Prescriptions (doctor & staff dashboard) — digital prescription
        { icon: 'mdi-pill', label: 'Prescriptions', path: '/clinics/prescriptions' },
        // Pharmacy Integration
        { icon: 'mdi-pill-multiple', label: 'Medications', path: '/clinics/medications' },
        // Lab & Diagnostics
        { icon: 'mdi-microscope', label: 'Lab Orders', path: '/clinics/lab-orders' },
        { icon: 'mdi-image', label: 'Radiology', path: '/radiology' },
        // Emergency / triage + ward observation
        { icon: 'mdi-heart-pulse', label: 'Triage', path: '/clinics/triage' },
        { icon: 'mdi-bed', label: 'Wards', path: '/clinics/wards' },
        // Caregiver & Homecare (patient care, notes, vitals, escalations)
        { icon: 'mdi-home-heart', label: 'Patient Care', path: '/clinics/patient-care' },
        { icon: 'mdi-notebook-edit', label: 'Care Notes', path: '/clinics/care-notes' },
        { icon: 'mdi-heart-pulse', label: 'Vitals', path: '/clinics/vitals' },
        { icon: 'mdi-account-multiple-check', label: 'Caregivers', path: '/clinics/caregivers' },
        { icon: 'mdi-bell-alert', label: 'Escalations', path: '/clinics/escalations' },
        // Billing & Insurance
        { icon: 'mdi-receipt-text', label: 'Billing', path: '/clinics/invoices' },
        {
          icon: 'mdi-bank', label: 'Accounts', path: '/clinics/accounts',
          children: [
            { icon: 'mdi-view-dashboard-outline', label: 'Overview', path: '/clinics/accounts' },
            { icon: 'mdi-cash-fast', label: 'Receivables', path: '/clinics/accounts?tab=receivables' },
            { icon: 'mdi-cash-clock', label: 'Payables', path: '/clinics/accounts?tab=payables' },
            { icon: 'mdi-swap-vertical', label: 'Transactions', path: '/clinics/accounts?tab=transactions' },
            { icon: 'mdi-chart-box', label: 'Profit and Loss', path: '/clinics/accounts?tab=pnl' }
          ]
        },
      {
          icon: 'mdi-cash-minus', label: 'Expenses', path: '/clinics/expenses',
          children: [
            { icon: 'mdi-format-list-bulleted', label: 'View Expenses', path: '/clinics/expenses' },
            { icon: 'mdi-plus-circle', label: 'New Expense', path: '/clinics/expenses/new' },
            { icon: 'mdi-shape', label: 'Categories', path: '/clinics/expenses/categories' }
          ]
        },
        // Administration & Reporting
        { icon: 'mdi-domain', label: 'Departments', path: '/clinics/departments' },
        { icon: 'mdi-chart-arc', label: 'Analytics', path: '/clinics/analytics' },
        { icon: 'mdi-people', label: 'Staff', path: '/clinics/staff' },
        // Data Protection & Compliance + Audit logs
        {
          icon: 'mdi-shield-check', label: 'Compliance',
          children: [
            { icon: 'mdi-account-key', label: 'Patient Consents', path: '/clinics/consents' },
            { icon: 'mdi-share-variant', label: 'Data Sharing', path: '/clinics/data-sharing' },
            { icon: 'mdi-history', label: 'Audit Log', path: '/clinics/audit' }
          ]
        },
        // Emergency & Notifications
        { icon: 'mdi-bell-ring', label: 'Alerts', path: '/clinics/alerts' },
        { icon: 'mdi-chat', label: 'Messages', path: '/clinics/messages' },
        // Doctors directory
        { icon: 'mdi-stethoscope', label: 'Doctors', path: '/clinics/doctors' },
    ]
    if (['doctor', 'clinical_officer', 'dentist'].includes(role)) {
      clinicItems.splice(3, 0, { icon: 'mdi-percent', label: 'My Commission', path: '/clinics/billing/commission' })
    }
    // Doctors see a focused clinical sidebar — strip admin/finance/hr items
    if (['doctor', 'clinical_officer', 'dentist'].includes(role)) {
      const hiddenLabels = ['Patient Care', 'Caregivers', 'Billing', 'Accounts', 'Expenses', 'Departments', 'Analytics', 'Staff', 'Compliance', 'Doctors']
      for (let i = clinicItems.length - 1; i >= 0; i--) {
        if (hiddenLabels.includes(clinicItems[i].label)) clinicItems.splice(i, 1)
      }
    }
    sections.push({ label: 'CLINIC', items: clinicItems })
  }

  const pharmacyRoles = ['tenant_admin', 'pharmacy_admin', 'branch_admin', 'pharmacist', 'pharmacy_tech', 'cashier', 'admin']
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
            { icon: 'mdi-swap-vertical-bold', label: t('nav.stockMovements'), path: '/pharmacy/inventory/stock-movements' },
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
        {
          icon: 'mdi-cash-multiple', label: t('nav.apiBilling'), path: '/pharmacy/billing/usage',
          children: [
            { icon: 'mdi-chart-box', label: 'Usage & Bills', path: '/pharmacy/billing/usage' },
            { icon: 'mdi-credit-card-outline', label: 'Payments', path: '/pharmacy/billing/payments' }
          ]
        },
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
            { icon: 'mdi-truck', label: t('nav.suppliers'), path: '/pharmacy/suppliers' },
            { icon: 'mdi-shield-key', label: t('nav.rolesPermissions'), path: '/pharmacy/roles' },
            { icon: 'mdi-history', label: t('nav.auditLogs'), path: '/pharmacy/audit-logs' },
            { icon: 'mdi-heart-pulse', label: t('nav.systemHealth'), path: '/pharmacy/system-health' }
          ]
        },
        { icon: 'mdi-cog', label: t('nav.settings'), path: '/pharmacy/settings' },
        { icon: 'mdi-database-import', label: 'Setup / Seed', path: '/pharmacy/setup' },
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
            { icon: 'mdi-account-plus',            label: 'Enrol Patient',   path: '/homecare/patients/new' }
          ]
        },
        { icon: 'mdi-heart-pulse', label: 'Vitals & Observations', path: '/homecare/vitals' },
        { icon: 'mdi-note-edit', label: 'Care Notes', path: '/homecare/notes' },
        { icon: 'mdi-clipboard-list-outline', label: 'Assessments', path: '/homecare/assessments' },
        { icon: 'mdi-hand-heart', label: 'Patient Care', path: '/homecare/patient-care' }
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
        { icon: 'mdi-prescription', label: 'Prescriptions', path: '/homecare/prescriptions' },
        { icon: 'mdi-clipboard-text', label: 'Treatment Plans', path: '/homecare/treatment-plans' }
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
      label: 'ADMIN & MANAGEMENT',
      items: [
        { icon: 'mdi-account-switch', label: 'Assignments', path: '/homecare/assignments' },
        { icon: 'mdi-monitor-eye', label: 'Caregiver Monitor', path: '/homecare/caregiver-monitor' },
        {
          icon: 'mdi-calendar-clock', label: 'Schedules', path: '/homecare/schedules',
          children: [
            { icon: 'mdi-format-list-bulleted', label: 'Visit list', path: '/homecare/schedules' },
            { icon: 'mdi-calendar-month', label: 'Calendar', path: '/homecare/calendar' }
          ]
        },
        {
          icon: 'mdi-finance', label: 'Financials', path: '/homecare/accounts',
          children: [
            { icon: 'mdi-bank', label: 'Accounts', path: '/homecare/accounts' },
            { icon: 'mdi-receipt-text', label: 'Patient Bills', path: '/homecare/billing/patient-bills' },
            { icon: 'mdi-cash-register', label: 'Billing', path: '/homecare/billing' },
            { icon: 'mdi-chart-areaspline', label: 'API Billing', path: '/homecare/billing/usage' },
            { icon: 'mdi-credit-card-outline', label: 'API Payments', path: '/homecare/billing/payments' },
            { icon: 'mdi-cash-minus', label: 'Expenses', path: '/expenses' }
          ]
        },
        { icon: 'mdi-medical-bag', label: 'Equipment', path: '/homecare/equipment' },
        { icon: 'mdi-shield-account', label: 'Insurance', path: '/homecare/insurance' },
        {
          icon: 'mdi-chart-box-outline', label: 'Analytics', path: '/homecare/analytics',
          children: [
            { icon: 'mdi-view-dashboard-variant', label: 'Overview', path: '/homecare/analytics' },
            { icon: 'mdi-account-group',          label: 'Patients', path: '/homecare/analytics/patients' },
            { icon: 'mdi-account-heart',          label: 'Workforce', path: '/homecare/analytics/caregivers' },
            { icon: 'mdi-calendar-clock',         label: 'Visits', path: '/homecare/analytics/visits' },
            { icon: 'mdi-pill-multiple',          label: 'Adherence', path: '/homecare/analytics/adherence' },
            { icon: 'mdi-alert-octagram',         label: 'Escalations', path: '/homecare/analytics/escalations' },
            { icon: 'mdi-cash-multiple',          label: 'Financials', path: '/homecare/analytics/financials' },
            { icon: 'mdi-shield-account-outline', label: 'Insurance Claims', path: '/homecare/analytics/insurance' },
            { icon: 'mdi-devices',                label: 'Equipment', path: '/homecare/analytics/equipment' }
          ]
        },
        {
          icon: 'mdi-account-group', label: 'HR', path: '/homecare/hr',
          children: [
            { icon: 'mdi-view-dashboard-outline', label: 'HR Dashboard', path: '/homecare/hr' },
            { icon: 'mdi-account-heart', label: 'Caregivers', path: '/homecare/caregivers' },
            { icon: 'mdi-account-plus-outline', label: 'Recruitment', path: '/homecare/hr/recruitment' },
            { icon: 'mdi-school-outline', label: 'Onboarding & Training', path: '/homecare/hr/onboarding' },
            { icon: 'mdi-account', label: 'Employees', path: '/homecare/hr/employees' },
            { icon: 'mdi-calendar-clock-outline', label: 'Scheduling & Time', path: '/homecare/hr/scheduling' },
            { icon: 'mdi-cash-multiple', label: 'Payroll & Benefits', path: '/homecare/hr/payroll' },
            { icon: 'mdi-calendar-remove-outline', label: 'Leave Management', path: '/homecare/hr/leave' },
            { icon: 'mdi-chart-timeline-variant-shimmer', label: 'Performance', path: '/homecare/hr/performance' },
            { icon: 'mdi-file-document-multiple-outline', label: 'Documents', path: '/homecare/hr/documents' },
            { icon: 'mdi-gavel', label: 'Compliance', path: '/homecare/hr/compliance' }
          ]
        },
        { icon: 'mdi-chart-box', label: 'Reports', path: '/homecare/reports' }
      ]
    })
    sections.push({
      label: 'SECURITY & PRIVACY',
      items: [
        { icon: 'mdi-file-document-check', label: 'Consents', path: '/homecare/consents' },
        { icon: 'mdi-share-variant', label: 'Data Sharing', path: '/homecare/data-sharing' },
        { icon: 'mdi-history', label: 'Audit Log', path: '/homecare/audit' }
      ]
    })
    sections.push({
      label: 'CLINICAL TOOLS',
      items: [
        { icon: 'mdi-book-cog', label: 'Clinical Catalog', path: '/homecare/catalog' },
        { icon: 'mdi-domain', label: 'Company Profile', path: '/homecare/company-profile' },
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
    const ns = tenantType === 'hospital' ? '/hos' : tenantType === 'clinic' ? '/clinics' : ''
    sections.push({
      label: 'MY HEALTH',
      items: [
        { icon: 'mdi-account-circle', label: 'My Profile', path: ns ? `${ns}/my-profile` : '/my-profile' },
        { icon: 'mdi-receipt', label: 'My Prescriptions', path: ns ? `${ns}/my-prescriptions` : '/my-prescriptions' },
        {
          icon: 'mdi-pharmacy', label: 'Pharmacies', path: '/pharmacy-store',
          children: [
            { icon: 'mdi-storefront', label: 'Browse Pharmacies', path: '/pharmacy-store' },
            { icon: 'mdi-receipt-text', label: 'My Orders', path: '/pharmacy-store/orders' }
          ]
        },
        { icon: 'mdi-magnify', label: 'Find Doctors', path: ns ? `${ns}/doctors` : '/doctors' },
        { icon: 'mdi-chat', label: 'Messages', path: ns ? `${ns}/messages` : '/messages' }
      ]
    })
  }

  if (['doctor', 'clinical_officer', 'dentist'].includes(role)) {
    const ns = tenantType === 'hospital' ? '/hos' : tenantType === 'clinic' ? '/clinics' : ''
    const practiceItems = [
      { icon: 'mdi-monitor-dashboard', label: 'Doctor Workspace', path: ns ? `${ns}/doctor-workspace` : '/doctor-workspace' },
      { icon: 'mdi-account-circle', label: 'My Profile', path: ns ? `${ns}/doctor-profile` : '/doctor-profile' },
      { icon: 'mdi-magnify', label: 'Doctor Directory', path: ns ? `${ns}/doctors` : '/doctors' },
    ]
    // Only add Prescriptions and Messages to MY PRACTICE if they aren't
    // already in the tenant-specific CLINIC/HOSPITAL section (avoids duplicate IDs).
    const tenantItems = sections.find(s => s.label === 'CLINIC' || s.label === 'HOSPITAL')
    const existingLabels = new Set((tenantItems?.items || []).map(i => i.label))
    if (!existingLabels.has('Prescriptions')) {
      practiceItems.push({ icon: 'mdi-pill', label: 'Prescriptions', path: ns ? `${ns}/prescriptions` : '/prescriptions' })
    }
    if (!existingLabels.has('Messages')) {
      practiceItems.push({ icon: 'mdi-chat', label: 'Messages', path: ns ? `${ns}/messages` : '/messages' })
    }
    sections.push({ label: 'MY PRACTICE', items: practiceItems })
  }

  return sections
}
