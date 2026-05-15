// Batch i18n updater for pharmacy pages
// Reads each Vue file, adds useI18n import + setup, replaces common hardcoded strings
const fs = require('fs')
const path = require('path')

const pagesDir = path.join(__dirname, '..', 'pages')

// Page files that need i18n (custom pages with <script setup>)
const customPages = [
  'pharmacy/alerts/index.vue',
  'pharmacy/billing/usage.vue',
  'pharmacy/credit/index.vue',
  'pos/index.vue',
  'pos/history.vue',
  'pos/loyalty.vue',
  'pos/parked.vue',
  'pos/shifts.vue',
  'pos/supermarket.vue',
  'inventory/index.vue',
  'inventory/bulk.vue',
  'inventory/controlled-register.vue',
  'inventory/stock-analysis.vue',
  'inventory/stock-take.vue',
  'inventory/transfers.vue',
  'dispensing/index.vue',
  'dispensing/new.vue',
  'dispensing/returns.vue',
  'medications/index.vue',
  'medications/interactions.vue',
  'analytics/index.vue',
  'analytics/products.vue',
  'analytics/categories.vue',
  'reports/index.vue',
  'reports/[key].vue',
  'reports/analytics.vue',
  'invoices/index.vue',
  'invoices/[id]/index.vue',
  'expenses/index.vue',
  'expenses/categories.vue',
  'expenses/[id]/index.vue',
  'customers/index.vue',
  'suppliers/index.vue',
  'staff/index.vue',
  'settings/index.vue',
  'insurance/index.vue',
  'insurance/providers.vue',
  'categories/index.vue',
  'units/index.vue',
  'adjustments/index.vue',
  'deliveries/index.vue',
  'pharmacy-orders/index.vue',
  'pharmacy-orders/[id].vue',
  'pharmacy-rx/index.vue',
  'pharmacy-store/index.vue',
  'pharmacy-store/cart.vue',
  'pharmacy-store/[id]/index.vue',
  'pharmacy-store/orders/index.vue',
  'pharmacy-store/orders/[id].vue',
]

// Map of page titles/subtitles to i18n keys
const titleMap = {
  // Alerts
  'Stock Alerts & Notifications': 'alerts.title',
  'Monitor stock levels and expiry dates': 'alerts.subtitle',
  // Billing
  'Usage & Billing': 'billing.title',
  'Monitor your API usage': 'billing.subtitle',
  // Credit
  'Customer Credit': 'credit.title',
  'Manage credit accounts': 'credit.subtitle',
  // POS
  'Point of Sale': 'pos.title',
  'Over-the-counter / OTC sales': 'pos.subtitle',
  // POS Shifts
  'Cashier Shifts': 'posShifts.title',
  // POS History
  'Sales History': 'posHistory.title',
  // POS Parked
  'Parked Sales': 'posParked.title',
  'Suspended sales': 'posParked.subtitle',
  // POS Loyalty
  'Customer Loyalty': 'posLoyalty.title',
  // POS Supermarket
  'Smart POS': 'posSupermarket.title',
  // Inventory
  'Inventory': 'inventory.title',
  'Items, categories, units & adjustments': 'inventory.subtitle',
  // Stock Analysis
  'Stock Analysis': 'stockAnalysis.title',
  // Stock Take
  'Stock Take': 'stockTake.title',
  // Transfers
  'Stock Transfers': 'transfers.title',
  // Controlled Register
  'Controlled-Substance Register': 'controlled.title',
  // Dispensing
  'Dispensing': 'dispensing.title',
  'New Dispense': 'newDispense.title',
  'Dispense Returns': 'dispenseReturns.title',
  // Medications
  'Medications Catalog': 'medications.title',
  'Drug Interactions': 'interactions.title',
  // Analytics
  'Pharmacy Analytics': 'analytics.title',
  'Category Sales': 'analyticsCategories.title',
  'Product Analytics': 'analyticsProducts.title',
  // Reports
  'Reports': 'reports.title',
  // Invoices
  'Invoices': 'invoices.title',
  // Expenses
  'Expenses': 'expenses.title',
  'Expense Categories': 'expenseCategories.title',
  // Customers/Suppliers/Staff
  'Customers': 'customers.title',
  'Suppliers': 'suppliers.title',
  'Pharmacy Staff': 'staff.title',
  // Settings
  'Settings': 'settingsPage.title',
  // Insurance
  'Insurance Claims': 'insuranceClaims.title',
  'Insurance Providers': 'insuranceProviders.title',
  // Categories/Units
  'Categories': 'categoriesPage.title',
  'Units of Measure': 'unitsPage.title',
  // Adjustments
  'Stock Adjustments': 'adjustments.title',
  // Deliveries
  'Deliveries': 'deliveries.title',
  // Pharmacy Orders
  'Patient Orders': 'pharmacyOrders.title',
  // Pharmacy Rx
  'Pharmacy Prescriptions': 'pharmacyRx.title',
}

// Common string replacements in templates (regex pattern -> replacement)
// These handle common UI patterns across all pages
const templateReplacements = [
  // Common button labels
  [/>\s*Save\s*</g, '>{{ $t(\'common.save\') }}<'],
  [/>\s*Cancel\s*</g, '>{{ $t(\'common.cancel\') }}<'],
  [/>\s*Delete\s*</g, '>{{ $t(\'common.delete\') }}<'],
  [/>\s*Edit\s*</g, '>{{ $t(\'common.edit\') }}<'],
  [/>\s*Back\s*</g, '>{{ $t(\'common.back\') }}<'],
  [/>\s*Close\s*</g, '>{{ $t(\'common.close\') }}<'],
  [/>\s*Add\s*</g, '>{{ $t(\'common.add\') }}<'],
  [/>\s*Create\s*</g, '>{{ $t(\'common.create\') }}<'],
  [/>\s*Confirm\s*</g, '>{{ $t(\'common.confirm\') }}<'],
  [/>\s*Export CSV\s*</g, '>{{ $t(\'common.exportCSV\') }}<'],
  [/>\s*Print\s*</g, '>{{ $t(\'common.print\') }}<'],
  [/>\s*Refresh\s*</g, '>{{ $t(\'common.refresh\') }}<'],
  [/>\s*Loading…\s*</g, '>{{ $t(\'common.loading\') }}<'],
  [/>\s*No data available\s*</g, '>{{ $t(\'common.noData\') }}<'],
  
  // Common prop values - title, subtitle, label attributes
  // title="Search…" or title="Search"
  [/title="Search…"/g, ':title="$t(\'common.searchEllipsis\')"'],
  [/title="Search"/g, ':title="$t(\'common.search\')"'],
  [/label="Save"/g, ':label="$t(\'common.save\')"'],
  [/label="Cancel"/g, ':label="$t(\'common.cancel\')"'],
  [/label="Delete"/g, ':label="$t(\'common.delete\')"'],
  [/label="Edit"/g, ':label="$t(\'common.edit\')"'],
  [/label="Back"/g, ':label="$t(\'common.back\')"'],
  [/label="Close"/g, ':label="$t(\'common.close\')"'],
  [/label="Add"/g, ':label="$t(\'common.add\')"'],
  [/label="Create"/g, ':label="$t(\'common.create\')"'],
  [/label="Export CSV"/g, ':label="$t(\'common.exportCSV\')"'],
  [/label="Submit"/g, ':label="$t(\'common.submit\')"'],
  [/label="Reset"/g, ':label="$t(\'common.reset\')"'],
  [/label="Confirm"/g, ':label="$t(\'common.confirm\')"'],
  
  // Placeholder text
  [/placeholder="Search…"/g, ':placeholder="$t(\'common.searchEllipsis\')"'],
  [/placeholder="Search"/g, ':placeholder="$t(\'common.search\')"'],
  
  // Tooltip text
  [/tooltip="Fullscreen"/g, ':tooltip="$t(\'topbar.fullscreen\')"'],
  [/tooltip="Exit Fullscreen"/g, ':tooltip="$t(\'topbar.exitFullscreen\')"'],
  
  // Common text in templates
  [/>\s*Subtotal\s*</g, '>{{ $t(\'common.subtotal\') }}<'],
  [/>\s*Discount\s*</g, '>{{ $t(\'common.discount\') }}<'],
  [/>\s*Tax\s*</g, '>{{ $t(\'common.tax\') }}<'],
  [/>\s*Grand Total\s*</g, '>{{ $t(\'common.grandTotal\') }}<'],
  [/>\s*Total\s*</g, '>{{ $t(\'common.total\') }}<'],
  [/>\s*Actions\s*</g, '>{{ $t(\'common.actions\') }}<'],
  [/>\s*Status\s*</g, '>{{ $t(\'common.status\') }}<'],
  [/>\s*Notes\s*</g, '>{{ $t(\'common.notes\') }}<'],
]

let processed = 0
let skipped = 0

for (const relPath of customPages) {
  const filePath = path.join(pagesDir, relPath)
  if (!fs.existsSync(filePath)) {
    console.log(`⚠ SKIP (not found): ${relPath}`)
    skipped++
    continue
  }
  
  let content = fs.readFileSync(filePath, 'utf8')
  let modified = false
  
  // 1. Add useI18n import if missing
  if (!content.includes("import { useI18n }") && !content.includes("from 'vue-i18n'")) {
    // Find the <script setup> tag
    const scriptSetupMatch = content.match(/<script\s+setup[^>]*>/)
    if (scriptSetupMatch) {
      const insertPos = scriptSetupMatch.index + scriptSetupMatch[0].length
      const importLine = "\nimport { useI18n } from 'vue-i18n'\nconst { t } = useI18n()\n"
      content = content.slice(0, insertPos) + importLine + content.slice(insertPos)
      modified = true
    }
  }
  
  // 2. Replace title/subtitle strings in template
  // Handle patterns like title="Stock Alerts & Notifications" or :title="'Stock Alerts'"
  for (const [engStr, i18nKey] of Object.entries(titleMap)) {
    // Static attribute: title="XYZ" -> :title="$t('key')"
    const staticPattern = new RegExp(`(title|subtitle)="${escapeRegex(engStr)}"`, 'g')
    const replacement = `:$1="$t('${i18nKey}')"`
    if (staticPattern.test(content)) {
      content = content.replace(staticPattern, replacement)
      modified = true
    }
    // Text content: >XYZ</  -> >{{ $t('key') }}</
    const textPattern = new RegExp(`>\\s*${escapeRegex(engStr)}\\s*<`, 'g')
    const textRepl = `>{{ $t('${i18nKey}') }}<`
    if (textPattern.test(content)) {
      content = content.replace(textPattern, textRepl)
      modified = true
    }
  }
  
  // 3. Apply common template replacements
  for (const [pattern, replacement] of templateReplacements) {
    if (pattern.test(content)) {
      content = content.replace(pattern, replacement)
      modified = true
      // Reset regex lastIndex
      pattern.lastIndex = 0
    }
  }
  
  if (modified) {
    fs.writeFileSync(filePath, content, 'utf8')
    console.log(`✓ ${relPath}`)
    processed++
  } else {
    console.log(`– ${relPath} (no changes needed)`)
    skipped++
  }
}

console.log(`\nDone: ${processed} files updated, ${skipped} skipped.`)

function escapeRegex(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}
