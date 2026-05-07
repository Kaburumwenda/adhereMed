// Shared metadata for the Reports module.
export const REPORT_CATALOG = [
  { key: 'sales_summary', label: 'Sales Summary', desc: 'Daily sales totals, revenue, AOV and order counts', icon: 'mdi-chart-bar', color: 'primary', scope: 'POS' },
  { key: 'sales_by_product', label: 'Sales by Product', desc: 'Quantity sold, revenue and share per product', icon: 'mdi-pill', color: 'info', scope: 'POS' },
  { key: 'sales_by_category', label: 'Sales by Category', desc: 'Revenue grouped by product category', icon: 'mdi-shape', color: 'success', scope: 'POS' },
  { key: 'sales_by_cashier', label: 'Cashier Performance', desc: 'Transactions, revenue and AOV per cashier', icon: 'mdi-account-tie', color: 'warning', scope: 'POS' },
  { key: 'payment_methods', label: 'Payments Report', desc: 'Breakdown by payment method (cash, M-Pesa…)', icon: 'mdi-credit-card-outline', color: 'pink', scope: 'POS' },
  { key: 'tax_report', label: 'Tax & Discounts', desc: 'Tax collected and discounts given', icon: 'mdi-receipt-text-check-outline', color: 'deep-purple', scope: 'POS' },
  { key: 'voided_refunded', label: 'Voids & Refunds', desc: 'Voided / refunded transactions in period', icon: 'mdi-receipt-text-remove-outline', color: 'red', scope: 'POS' },
  { key: 'top_customers', label: 'Top Customers', desc: 'Customers by spend and visit frequency', icon: 'mdi-account-star', color: 'amber', scope: 'CRM' },
  { key: 'stock_on_hand', label: 'Stock on Hand', desc: 'Current quantity & inventory value per item', icon: 'mdi-package-variant', color: 'indigo', scope: 'Inventory' },
  { key: 'low_stock', label: 'Low Stock', desc: 'Items at or below reorder level', icon: 'mdi-alert-circle-outline', color: 'orange', scope: 'Inventory' },
  { key: 'expiring_soon', label: 'Expiring Soon', desc: 'Items expiring within 90 days', icon: 'mdi-clock-alert-outline', color: 'warning', scope: 'Inventory' },
  { key: 'purchases', label: 'Purchase Orders', desc: 'Supplier purchases in period', icon: 'mdi-cart-outline', color: 'teal', scope: 'Procurement' }
]

export const RANGE_OPTIONS = [
  { key: 'today', label: 'Today' },
  { key: 'yesterday', label: 'Yesterday' },
  { key: '7d', label: 'Last 7 days' },
  { key: '30d', label: 'Last 30 days' },
  { key: '90d', label: 'Last 90 days' },
  { key: 'thisMonth', label: 'This month' },
  { key: 'lastMonth', label: 'Last month' },
  { key: 'thisYear', label: 'This year' },
  { key: 'lastYear', label: 'Last year' },
  { key: '1y', label: 'Last 365 days' },
  { key: 'all', label: 'All time' },
  { key: 'custom', label: 'Custom range…' }
]

export function startOfDay(d) { const x = new Date(d); x.setHours(0, 0, 0, 0); return x }
export function addDays(d, n) { const x = new Date(d); x.setDate(x.getDate() + n); return x }

export function resolveRange(key, custom = null) {
  const t = startOfDay(new Date())
  const tomorrow = addDays(t, 1)
  switch (key) {
    case 'today': return { start: t, end: tomorrow, label: 'Today' }
    case 'yesterday': return { start: addDays(t, -1), end: t, label: 'Yesterday' }
    case '7d': return { start: addDays(t, -6), end: tomorrow, label: 'Last 7 days' }
    case '30d': return { start: addDays(t, -29), end: tomorrow, label: 'Last 30 days' }
    case '90d': return { start: addDays(t, -89), end: tomorrow, label: 'Last 90 days' }
    case '1y': return { start: addDays(t, -364), end: tomorrow, label: 'Last 365 days' }
    case 'thisMonth': return { start: new Date(t.getFullYear(), t.getMonth(), 1), end: tomorrow, label: 'This month' }
    case 'lastMonth': return { start: new Date(t.getFullYear(), t.getMonth() - 1, 1), end: new Date(t.getFullYear(), t.getMonth(), 1), label: 'Last month' }
    case 'thisYear': return { start: new Date(t.getFullYear(), 0, 1), end: tomorrow, label: 'This year' }
    case 'lastYear': return { start: new Date(t.getFullYear() - 1, 0, 1), end: new Date(t.getFullYear(), 0, 1), label: 'Last year' }
    case 'all': return { start: new Date(2000, 0, 1), end: tomorrow, label: 'All time' }
    case 'custom': return custom || { start: addDays(t, -29), end: tomorrow, label: 'Custom' }
    default: return { start: addDays(t, -29), end: tomorrow, label: 'Last 30 days' }
  }
}
