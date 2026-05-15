// Phase 2: Page-specific i18n replacements for key pharmacy pages
// Handles page-specific strings that the batch script couldn't cover
const fs = require('fs')
const path = require('path')

const pagesDir = path.join(__dirname, '..', 'pages')

function escapeRegex(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

// Page-specific replacements: [file, [[find, replace], ...]]
const pageReplacements = [
  // === ALERTS ===
  ['pharmacy/alerts/index.vue', [
    ['title="Stock Alerts"', ':title="$t(\'alerts.stockAlerts\')"'],
    ['title="Expiry Alerts"', ':title="$t(\'alerts.expiryAlerts\')"'],
    ['>Stock Alerts<', '>{{ $t(\'alerts.stockAlerts\') }}<'],
    ['>Expiry Alerts<', '>{{ $t(\'alerts.expiryAlerts\') }}<'],
    ['>Out of Stock<', '>{{ $t(\'alerts.outOfStock\') }}<'],
    ['>Low Stock<', '>{{ $t(\'alerts.lowStock\') }}<'],
    ['>Expired<', '>{{ $t(\'alerts.expired\') }}<'],
    ['>Expiring Soon<', '>{{ $t(\'alerts.expiringSoon\') }}<'],
    ['placeholder="Search by name…"', ':placeholder="$t(\'alerts.searchItems\')"'],
    ['>Item<', '>{{ $t(\'alerts.item\') }}<'],
    ['>Qty on Hand<', '>{{ $t(\'alerts.qtyOnHand\') }}<'],
    ['>Reorder Level<', '>{{ $t(\'alerts.reorderLevel\') }}<'],
    ['>Deficit<', '>{{ $t(\'alerts.deficit\') }}<'],
    ['>Batch #<', '>{{ $t(\'alerts.batchNo\') }}<'],
    ['>Qty Remaining<', '>{{ $t(\'alerts.qtyRemaining\') }}<'],
    ['>Expiry Date<', '>{{ $t(\'alerts.expiryDate\') }}<'],
    ['>Mark All Read<', '>{{ $t(\'alerts.markAllRead\') }}<'],
    ['title="Pending Orders"', ':title="$t(\'alerts.pendingOrders\')"'],
    ['>Pending Orders<', '>{{ $t(\'alerts.pendingOrders\') }}<'],
    ['>Notifications<', '>{{ $t(\'common.notifications\') }}<'],
    ['>Sort by<', '>{{ $t(\'alerts.sortBy\') }}<'],
  ]],
  
  // === POS ===
  ['pos/index.vue', [
    ['>Checkout<', '>{{ $t(\'pos.checkout\') }}<'],
    ['>Pay Now<', '>{{ $t(\'pos.payNow\') }}<'],
    ['>Park Sale<', '>{{ $t(\'pos.parkSale\') }}<'],
    ['>Clear Cart<', '>{{ $t(\'pos.clearCart\') }}<'],
    ['>Cash<', '>{{ $t(\'common.cash\') }}<'],
    ['>Card<', '>{{ $t(\'common.card\') }}<'],
    ['>M-Pesa<', '>{{ $t(\'common.mpesa\') }}<'],
    ['>Insurance<', '>{{ $t(\'pos.insurance\') }}<'],
    ['>Credit<', '>{{ $t(\'pos.credit\') }}<'],
    ['>Current Sale<', '>{{ $t(\'pos.currentSale\') }}<'],
    ['>Walk-in Customer<', '>{{ $t(\'common.walkIn\') }}<'],
    ['placeholder="Search by name or SKU…"', ':placeholder="$t(\'pos.searchProducts\')"'],
    ['>All Categories<', '>{{ $t(\'pos.allCategories\') }}<'],
    ['>Grid<', '>{{ $t(\'common.grid\') }}<'],
    ['>List<', '>{{ $t(\'common.list\') }}<'],
    ['>Payment Method<', '>{{ $t(\'pos.paymentMethod\') }}<'],
    ['>Stock<', '>{{ $t(\'pos.stock\') }}<'],
    ['>Cart is empty<', '>{{ $t(\'pos.cartIsEmpty\') }}<'],
    ['>No products found<', '>{{ $t(\'pos.noProductsFound\') }}<'],
    ['>Hold Sale<', '>{{ $t(\'pos.holdSale\') }}<'],
    ['>Complete<', '>{{ $t(\'common.completed\') }}<'],
    ['>Out of stock<', '>{{ $t(\'pos.outOfStock\') }}<'],
  ]],
  
  // === INVENTORY ===
  ['inventory/index.vue', [
    ['>New Stock<', '>{{ $t(\'inventory.newStock\') }}<'],
    ['>Add Stock<', '>{{ $t(\'inventory.addStock\') }}<'],
    ['>Bulk<', '>{{ $t(\'inventory.bulk\') }}<'],
    ['>Medication<', '>{{ $t(\'inventory.medication\') }}<'],
    ['>Batch #<', '>{{ $t(\'inventory.batchNumber\') }}<'],
    ['>Expiry<', '>{{ $t(\'inventory.expiryDate\') }}<'],
    ['>Qty<', '>{{ $t(\'common.quantity\') }}<'],
    ['>Selling Price<', '>{{ $t(\'inventory.sellingPrice\') }}<'],
    ['>Cost Price<', '>{{ $t(\'inventory.costPrice\') }}<'],
    ['>Supplier<', '>{{ $t(\'inventory.supplier\') }}<'],
    ['>Location<', '>{{ $t(\'inventory.location\') }}<'],
    ['>Out of Stock<', '>{{ $t(\'inventory.outOfStock\') }}<'],
    ['>Low<', '>{{ $t(\'inventory.low\') }}<'],
    ['>In Stock<', '>{{ $t(\'inventory.inStock\') }}<'],
    ['>All Categories<', '>{{ $t(\'inventory.allCategories\') }}<'],
    ['placeholder="Search by name, barcode…"', ':placeholder="$t(\'inventory.searchByNameBarcode\')"'],
    ['>Stocks<', '>{{ $t(\'inventory.stocks\') }}<'],
  ]],
  
  // === DISPENSING ===
  ['dispensing/index.vue', [
    ['>New Dispense<', '>{{ $t(\'dispensing.newDispense\') }}<'],
    ['>Returns<', '>{{ $t(\'dispensing.returns\') }}<'],
    ['>Patient<', '>{{ $t(\'dispensing.patient\') }}<'],
    ['>Prescriber<', '>{{ $t(\'dispensing.prescriber\') }}<'],
    ['>Medication<', '>{{ $t(\'dispensing.medication\') }}<'],
    ['>Dosage<', '>{{ $t(\'dispensing.dosage\') }}<'],
    ['>Payment<', '>{{ $t(\'dispensing.payment\') }}<'],
    ['>Dispensed<', '>{{ $t(\'dispensing.dispensed\') }}<'],
    ['placeholder="Search by patient…"', ':placeholder="$t(\'dispensing.searchByPatient\')"'],
  ]],
  
  // === MEDICATIONS ===
  ['medications/index.vue', [
    ['>New Medication<', '>{{ $t(\'medications.newMedication\') }}<'],
    ['placeholder="Search by name, brand…"', ':placeholder="$t(\'medications.searchMedications\')"'],
    ['>Dosage Form<', '>{{ $t(\'medications.dosageForm\') }}<'],
    ['>Generic Name<', '>{{ $t(\'medications.genericName\') }}<'],
    ['>Rx<', '>{{ $t(\'medications.rx\') }}<'],
    ['>OTC<', '>{{ $t(\'medications.otc\') }}<'],
    ['>Category<', '>{{ $t(\'common.category\') }}<'],
    ['>Strength<', '>{{ $t(\'medications.strength\') }}<'],
  ]],
  
  // === INVOICES ===
  ['invoices/index.vue', [
    ['>New Invoice<', '>{{ $t(\'invoices.newInvoice\') }}<'],
    ['>Record Payment<', '>{{ $t(\'invoices.recordPayment\') }}<'],
    ['>Outstanding Only<', '>{{ $t(\'invoices.outstandingOnly\') }}<'],
    ['>Fully Paid<', '>{{ $t(\'invoices.fullyPaid\') }}<'],
    ['>Due Date<', '>{{ $t(\'invoices.dueDate\') }}<'],
    ['>Customer<', '>{{ $t(\'common.customer\') }}<'],
    ['>Amount<', '>{{ $t(\'common.amount\') }}<'],
    ['>Balance<', '>{{ $t(\'common.balance\') }}<'],
    ['>Paid<', '>{{ $t(\'common.paid\') }}<'],
    ['>Unpaid<', '>{{ $t(\'common.unpaid\') }}<'],
    ['>Overdue<', '>{{ $t(\'common.overdue\') }}<'],
    ['>Pending<', '>{{ $t(\'common.pending\') }}<'],
    ['placeholder="Search invoice #…"', ':placeholder="$t(\'invoices.searchInvoice\')"'],
  ]],
  
  // === EXPENSES ===
  ['expenses/index.vue', [
    ['>New Expense<', '>{{ $t(\'expenses.newExpense\') }}<'],
    ['>Approve<', '>{{ $t(\'expenses.approve\') }}<'],
    ['>Mark Paid<', '>{{ $t(\'expenses.markPaid\') }}<'],
    ['placeholder="Search…"', ':placeholder="$t(\'common.searchEllipsis\')"'],
  ]],
  
  ['expenses/categories.vue', [
    ['>New Category<', '>{{ $t(\'expenseCategories.newCategory\') }}<'],
    ['placeholder="Search…"', ':placeholder="$t(\'common.searchEllipsis\')"'],
    ['>Total Spent<', '>{{ $t(\'expenseCategories.totalSpent\') }}<'],
  ]],
  
  // === SUPPLIERS ===
  ['suppliers/index.vue', [
    ['>New Supplier<', '>{{ $t(\'suppliers.newSupplier\') }}<'],
    ['placeholder="Search…"', ':placeholder="$t(\'common.searchEllipsis\')"'],
    ['>Contact<', '>{{ $t(\'insuranceProviders.contact\') }}<'],
    ['>Phone<', '>{{ $t(\'common.phone\') }}<'],
    ['>Email<', '>{{ $t(\'common.email\') }}<'],
    ['>Payment Terms<', '>{{ $t(\'suppliers.paymentTerms\') }}<'],
  ]],
  
  // === STAFF ===
  ['staff/index.vue', [
    ['>Add Staff<', '>{{ $t(\'staff.addStaff\') }}<'],
    ['>Team<', '>{{ $t(\'staff.team\') }}<'],
    ['>Specializations<', '>{{ $t(\'staff.specializations\') }}<'],
    ['>Weekly Schedule<', '>{{ $t(\'staff.weeklySchedule\') }}<'],
    ['placeholder="Search by name, email…"', ':placeholder="$t(\'staff.searchByNameEmail\')"'],
    ['>Role<', '>{{ $t(\'staff.role\') }}<'],
    ['>Specialization<', '>{{ $t(\'staff.specialization\') }}<'],
    ['>License<', '>{{ $t(\'staff.license\') }}<'],
    ['>Available<', '>{{ $t(\'staff.available\') }}<'],
    ['>Reset Password<', '>{{ $t(\'staff.resetPassword\') }}<'],
    ['>First Name<', '>{{ $t(\'staff.firstName\') }}<'],
    ['>Last Name<', '>{{ $t(\'staff.lastName\') }}<'],
  ]],
  
  // === SETTINGS ===
  ['settings/index.vue', [
    ['>Profile<', '>{{ $t(\'settingsPage.profileTab\') }}<'],
    ['>Operating Hours<', '>{{ $t(\'settingsPage.operatingHours\') }}<'],
    ['>Delivery & Services<', '>{{ $t(\'settingsPage.deliveryServices\') }}<'],
    ['>Insurance<', '>{{ $t(\'settingsPage.insuranceTab\') }}<'],
    ['>Upload Logo<', '>{{ $t(\'settingsPage.uploadLogo\') }}<'],
    ['>Save Profile<', '>{{ $t(\'settingsPage.saveProfile\') }}<'],
    ['>Pharmacy Name<', '>{{ $t(\'settingsPage.pharmacyName\') }}<'],
    ['>License Number<', '>{{ $t(\'settingsPage.licenseNumber\') }}<'],
    ['>Save Hours<', '>{{ $t(\'settingsPage.saveHours\') }}<'],
  ]],
  
  // === INSURANCE ===
  ['insurance/index.vue', [
    ['>New Claim<', '>{{ $t(\'insuranceClaims.newClaim\') }}<'],
    ['>Provider<', '>{{ $t(\'insuranceClaims.provider\') }}<'],
    ['>Member<', '>{{ $t(\'insuranceClaims.member\') }}<'],
    ['>Submitted<', '>{{ $t(\'insuranceClaims.submitted\') }}<'],
    ['>Under Review<', '>{{ $t(\'insuranceClaims.underReview\') }}<'],
    ['>Approved<', '>{{ $t(\'common.approved\') }}<'],
    ['>Rejected<', '>{{ $t(\'common.rejected\') }}<'],
  ]],
  
  ['insurance/providers.vue', [
    ['>New Provider<', '>{{ $t(\'insuranceProviders.newProvider\') }}<'],
    ['>Claims<', '>{{ $t(\'insuranceProviders.claims\') }}<'],
    ['>Contact<', '>{{ $t(\'insuranceProviders.contact\') }}<'],
    ['>Discount Rate<', '>{{ $t(\'insuranceProviders.discountRate\') }}<'],
    ['>Terms<', '>{{ $t(\'insuranceProviders.terms\') }}<'],
  ]],
  
  // === CATEGORIES ===
  ['categories/index.vue', [
    ['>New Category<', '>{{ $t(\'categoriesPage.newCategory\') }}<'],
    ['placeholder="Search…"', ':placeholder="$t(\'common.searchEllipsis\')"'],
  ]],
  
  // === UNITS ===
  ['units/index.vue', [
    ['>New Unit<', '>{{ $t(\'unitsPage.newUnit\') }}<'],
    ['placeholder="Search…"', ':placeholder="$t(\'common.searchEllipsis\')"'],
  ]],
  
  // === ADJUSTMENTS ===
  ['adjustments/index.vue', [
    ['>New Adjustment<', '>{{ $t(\'adjustments.newAdjustment\') }}<'],
    ['placeholder="Search…"', ':placeholder="$t(\'common.searchEllipsis\')"'],
    ['>Reason<', '>{{ $t(\'adjustments.reason\') }}<'],
    ['>Adjusted By<', '>{{ $t(\'adjustments.adjustedBy\') }}<'],
    ['>Damage<', '>{{ $t(\'adjustments.damage\') }}<'],
    ['>Theft<', '>{{ $t(\'adjustments.theft\') }}<'],
    ['>Expiry<', '>{{ $t(\'adjustments.expiry\') }}<'],
  ]],
  
  // === DELIVERIES ===
  ['deliveries/index.vue', [
    ['>New Delivery<', '>{{ $t(\'deliveries.newDelivery\') }}<'],
    ['placeholder="Search…"', ':placeholder="$t(\'common.searchEllipsis\')"'],
    ['>Delivery Address<', '>{{ $t(\'deliveries.deliveryAddress\') }}<'],
    ['>Driver<', '>{{ $t(\'deliveries.driver\') }}<'],
    ['>Delivery Fee<', '>{{ $t(\'deliveries.deliveryFee\') }}<'],
    ['>Recipient<', '>{{ $t(\'deliveries.recipient\') }}<'],
    ['>Scheduled<', '>{{ $t(\'deliveries.scheduled\') }}<'],
    ['>Use My Location<', '>{{ $t(\'deliveries.useMyLocation\') }}<'],
  ]],
  
  // === PHARMACY ORDERS ===
  ['pharmacy-orders/index.vue', [
    ['placeholder="Search order #…"', ':placeholder="$t(\'pharmacyOrders.searchOrders\')"'],
    ['>Confirmed<', '>{{ $t(\'pharmacyOrders.confirmed\') }}<'],
    ['>Processing<', '>{{ $t(\'pharmacyOrders.processing\') }}<'],
    ['>Ready<', '>{{ $t(\'pharmacyOrders.ready\') }}<'],
    ['>Cancel Order<', '>{{ $t(\'pharmacyOrders.cancelOrder\') }}<'],
    ['>Delivery Address<', '>{{ $t(\'pharmacyOrders.deliveryAddress\') }}<'],
    ['>Delivery Fee<', '>{{ $t(\'pharmacyOrders.deliveryFee\') }}<'],
  ]],
  
  // === PHARMACY RX ===
  ['pharmacy-rx/index.vue', [
    ['>New Prescription<', '>{{ $t(\'pharmacyRx.newPrescription\') }}<'],
    ['placeholder="Search…"', ':placeholder="$t(\'common.searchEllipsis\')"'],
  ]],
  
  // === POS SHIFTS ===
  ['pos/shifts.vue', [
    ['>Open Shift<', '>{{ $t(\'posShifts.openShift\') }}<'],
    ['>Close Shift<', '>{{ $t(\'posShifts.closeShift\') }}<'],
    ['>Cashier<', '>{{ $t(\'posShifts.cashier\') }}<'],
    ['>Transactions<', '>{{ $t(\'posShifts.transactions\') }}<'],
    ['>Cash Sales<', '>{{ $t(\'posShifts.cashSales\') }}<'],
    ['>Variance<', '>{{ $t(\'posShifts.variance\') }}<'],
    ['>Opening Float<', '>{{ $t(\'posShifts.openingFloat\') }}<'],
    ['>Duration<', '>{{ $t(\'posShifts.duration\') }}<'],
    ['>Z-REPORT<', '>{{ $t(\'posShifts.zReport\') }}<'],
    ['>Expected<', '>{{ $t(\'posShifts.expected\') }}<'],
  ]],
  
  // === POS HISTORY ===
  ['pos/history.vue', [
    ['>Receipt #<', '>{{ $t(\'posHistory.receiptNo\') }}<'],
    ['>Payment<', '>{{ $t(\'posHistory.payment\') }}<'],
    ['>Date / Time<', '>{{ $t(\'posHistory.dateTime\') }}<'],
    ['>All Payments<', '>{{ $t(\'posHistory.allPayments\') }}<'],
    ['>All Cashiers<', '>{{ $t(\'posHistory.allCashiers\') }}<'],
    ['>My Sales Only<', '>{{ $t(\'posHistory.mySalesOnly\') }}<'],
    ['>Net Revenue<', '>{{ $t(\'posHistory.netRevenue\') }}<'],
    ['>Items Sold<', '>{{ $t(\'posHistory.itemsSold\') }}<'],
    ['placeholder="Search receipt #…"', ':placeholder="$t(\'posHistory.searchReceipt\')"'],
  ]],
  
  // === POS PARKED ===
  ['pos/parked.vue', [
    ['>Resume<', '>{{ $t(\'posParked.resume\') }}<'],
    ['placeholder="Search by # / customer"', ':placeholder="$t(\'posParked.searchParked\')"'],
  ]],
  
  // === POS LOYALTY ===
  ['pos/loyalty.vue', [
    ['>Adjust Points<', '>{{ $t(\'posLoyalty.adjustPoints\') }}<'],
    ['>Points<', '>{{ $t(\'posLoyalty.points\') }}<'],
    ['>Earn<', '>{{ $t(\'posLoyalty.earn\') }}<'],
    ['>Redeem<', '>{{ $t(\'posLoyalty.redeem\') }}<'],
  ]],
  
  // === STOCK ANALYSIS ===
  ['inventory/stock-analysis.vue', [
    ['>Stock Health<', '>{{ $t(\'stockAnalysis.stockHealth\') }}<'],
    ['>Value by Category<', '>{{ $t(\'stockAnalysis.valueByCategory\') }}<'],
    ['>Stock Movement<', '>{{ $t(\'stockAnalysis.stockMovement\') }}<'],
    ['>Reorder Priority<', '>{{ $t(\'stockAnalysis.reorderPriority\') }}<'],
    ['>Potential Profit<', '>{{ $t(\'stockAnalysis.potentialProfit\') }}<'],
  ]],
  
  // === STOCK TAKE ===
  ['inventory/stock-take.vue', [
    ['>New Count<', '>{{ $t(\'stockTake.newCount\') }}<'],
    ['>In Progress<', '>{{ $t(\'stockTake.inProgress\') }}<'],
    ['>Counted<', '>{{ $t(\'stockTake.counted\') }}<'],
    ['>Total Variance<', '>{{ $t(\'stockTake.totalVariance\') }}<'],
  ]],
  
  // === TRANSFERS ===
  ['inventory/transfers.vue', [
    ['>New Transfer<', '>{{ $t(\'transfers.newTransfer\') }}<'],
    ['>Route<', '>{{ $t(\'transfers.route\') }}<'],
    ['>From Branch<', '>{{ $t(\'transfers.fromBranch\') }}<'],
    ['>To Branch<', '>{{ $t(\'transfers.toBranch\') }}<'],
    ['>Save Draft<', '>{{ $t(\'transfers.saveDraft\') }}<'],
    ['>Submit Request<', '>{{ $t(\'transfers.submitRequest\') }}<'],
  ]],
  
  // === CONTROLLED REGISTER ===
  ['inventory/controlled-register.vue', [
    ['>Manual Entry<', '>{{ $t(\'controlled.manualEntry\') }}<'],
    ['>Action<', '>{{ $t(\'controlled.action\') }}<'],
    ['>Schedule<', '>{{ $t(\'controlled.schedule\') }}<'],
    ['>Quantity<', '>{{ $t(\'common.quantity\') }}<'],
    ['>Patient Name<', '>{{ $t(\'controlled.patientName\') }}<'],
    ['>Prescriber<', '>{{ $t(\'controlled.prescriber\') }}<'],
  ]],
  
  // === DISPENSING NEW ===
  ['dispensing/new.vue', [
    ['>Search Patient<', '>{{ $t(\'newDispense.searchPatient\') }}<'],
    ['>Patient Name<', '>{{ $t(\'newDispense.patientName\') }}<'],
    ['>Add Line<', '>{{ $t(\'newDispense.addManualLine\') }}<'],
    ['>Qty<', '>{{ $t(\'newDispense.qty\') }}<'],
    ['>Unit Price<', '>{{ $t(\'newDispense.unitPrice\') }}<'],
    ['>Amount Paid<', '>{{ $t(\'newDispense.amountPaid\') }}<'],
    ['>Complete Dispense<', '>{{ $t(\'newDispense.completeDispense\') }}<'],
    ['>Change Due<', '>{{ $t(\'newDispense.changeDue\') }}<'],
  ]],
  
  // === DISPENSING RETURNS ===
  ['dispensing/returns.vue', [
    ['>New Return<', '>{{ $t(\'dispenseReturns.newReturn\') }}<'],
    ['>Reason<', '>{{ $t(\'dispenseReturns.reason\') }}<'],
    ['>Refund<', '>{{ $t(\'dispenseReturns.refund\') }}<'],
    ['>Process Return<', '>{{ $t(\'dispenseReturns.processReturn\') }}<'],
    ['>Damaged<', '>{{ $t(\'dispenseReturns.damaged\') }}<'],
    ['>Wrong Item<', '>{{ $t(\'dispenseReturns.wrongItem\') }}<'],
  ]],
  
  // === MEDICATIONS INTERACTIONS ===
  ['medications/interactions.vue', [
    ['>New Interaction<', '>{{ $t(\'interactions.newInteraction\') }}<'],
    ['>Severity<', '>{{ $t(\'interactions.severity\') }}<'],
    ['>Drug A<', '>{{ $t(\'interactions.drugA\') }}<'],
    ['>Drug B<', '>{{ $t(\'interactions.drugB\') }}<'],
    ['>Check<', '>{{ $t(\'interactions.checkDrugs\') }}<'],
    ['>Run Check<', '>{{ $t(\'interactions.runCheck\') }}<'],
    ['>Minor<', '>{{ $t(\'interactions.minor\') }}<'],
    ['>Moderate<', '>{{ $t(\'interactions.moderate\') }}<'],
    ['>Major<', '>{{ $t(\'interactions.major\') }}<'],
  ]],
  
  // === ANALYTICS ===
  ['analytics/index.vue', [
    ['>Revenue Trend<', '>{{ $t(\'analytics.revenueTrend\') }}<'],
    ['>Payment Methods<', '>{{ $t(\'analytics.paymentMethods\') }}<'],
    ['>Top Selling Products<', '>{{ $t(\'analytics.topSellingProducts\') }}<'],
    ['>Top Customers<', '>{{ $t(\'analytics.topCustomers\') }}<'],
    ['>Cashier Performance<', '>{{ $t(\'analytics.cashierPerformance\') }}<'],
    ['>Inventory Value<', '>{{ $t(\'analytics.inventoryValue\') }}<'],
    ['>Low Stock Alerts<', '>{{ $t(\'analytics.lowStockAlerts\') }}<'],
  ]],
  
  ['analytics/categories.vue', [
    ['>Total Revenue<', '>{{ $t(\'analyticsCategories.totalRevenue\') }}<'],
    ['>Total Units<', '>{{ $t(\'analyticsCategories.totalUnits\') }}<'],
    ['>Slow Moving<', '>{{ $t(\'analyticsCategories.slowMoving\') }}<'],
    ['>Never Sold<', '>{{ $t(\'analyticsCategories.neverSold\') }}<'],
    ['>Dead Stock<', '>{{ $t(\'analyticsCategories.deadStock\') }}<'],
    ['>ABC Analysis<', '>{{ $t(\'analyticsCategories.abcAnalysis\') }}<'],
  ]],
  
  ['analytics/products.vue', [
    ['>Total Revenue<', '>{{ $t(\'analyticsProducts.totalRevenue\') }}<'],
    ['>Total Units<', '>{{ $t(\'analyticsProducts.totalUnits\') }}<'],
    ['>Slow Moving<', '>{{ $t(\'analyticsProducts.slowMoving\') }}<'],
    ['>Never Sold<', '>{{ $t(\'analyticsProducts.neverSold\') }}<'],
    ['>Dead Stock<', '>{{ $t(\'analyticsProducts.deadStock\') }}<'],
    ['>ABC Analysis<', '>{{ $t(\'analyticsProducts.abcAnalysis\') }}<'],
  ]],
  
  // === CREDIT ===
  ['pharmacy/credit/index.vue', [
    ['>Total Outstanding<', '>{{ $t(\'credit.totalOutstanding\') }}<'],
    ['>Overdue Amount<', '>{{ $t(\'credit.overdueAmount\') }}<'],
    ['>Record Payment<', '>{{ $t(\'credit.recordPayment\') }}<'],
    ['>Credit Limit<', '>{{ $t(\'credit.creditLimit\') }}<'],
    ['>Last Payment<', '>{{ $t(\'credit.lastPayment\') }}<'],
    ['>Days Overdue<', '>{{ $t(\'credit.daysOverdue\') }}<'],
    ['>Payment Amount<', '>{{ $t(\'credit.paymentAmount\') }}<'],
    ['>Payment Method<', '>{{ $t(\'credit.paymentMethod\') }}<'],
    ['>Payment Date<', '>{{ $t(\'credit.paymentDate\') }}<'],
    ['placeholder="Search customers…"', ':placeholder="$t(\'credit.searchCustomers\')"'],
  ]],
  
  // === BILLING ===
  ['pharmacy/billing/usage.vue', [
    ['>Total Requests<', '>{{ $t(\'billing.totalRequests\') }}<'],
    ['>Current Bill<', '>{{ $t(\'billing.currentBill\') }}<'],
    ['>Daily Average<', '>{{ $t(\'billing.dailyAverage\') }}<'],
    ['>Peak Day<', '>{{ $t(\'billing.peakDay\') }}<'],
    ['>Daily Breakdown<', '>{{ $t(\'billing.dailyBreakdown\') }}<'],
    ['>Monthly History<', '>{{ $t(\'billing.monthlyHistory\') }}<'],
    ['>Requests<', '>{{ $t(\'billing.requests\') }}<'],
    ['>Period<', '>{{ $t(\'billing.period\') }}<'],
  ]],
]

let totalUpdated = 0
for (const [relPath, replacements] of pageReplacements) {
  const filePath = path.join(pagesDir, relPath)
  if (!fs.existsSync(filePath)) {
    console.log(`⚠ SKIP: ${relPath}`)
    continue
  }
  
  let content = fs.readFileSync(filePath, 'utf8')
  let changes = 0
  
  for (const [find, replace] of replacements) {
    if (content.includes(find)) {
      content = content.split(find).join(replace)
      changes++
    }
  }
  
  if (changes > 0) {
    fs.writeFileSync(filePath, content, 'utf8')
    console.log(`✓ ${relPath} (${changes} replacements)`)
    totalUpdated++
  } else {
    console.log(`– ${relPath} (no matches)`)
  }
}

console.log(`\nDone: ${totalUpdated} files updated.`)
