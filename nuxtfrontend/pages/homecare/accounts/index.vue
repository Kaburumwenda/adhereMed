<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Accounts"
      subtitle="Revenue, receivables, expenses & full P&L for your homecare facility."
      eyebrow="FINANCE"
      icon="mdi-bank"
      :chips="[{ icon: 'mdi-receipt', label: `${bills.length} bills` }, { icon: 'mdi-cash-fast', label: `${payments.length} payments` }]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-refresh"
               class="text-none" :loading="loading" @click="loadAll">
          <span class="text-teal-darken-2 font-weight-bold">Refresh</span>
        </v-btn>
      </template>
    </HomecareHero>

    <!-- Date range + export -->
    <v-card flat rounded="xl" class="mb-4 pa-3 hc-card" border>
      <div class="d-flex align-center flex-wrap ga-2">
        <v-icon size="20" color="teal-darken-2" class="mr-1">mdi-calendar-filter</v-icon>
        <v-chip-group v-model="rangeKey" selected-class="text-teal-darken-2" mandatory>
          <v-chip v-for="opt in rangeChips" :key="opt.key" :value="opt.key"
                  variant="outlined" size="small" rounded="lg" filter>
            {{ opt.label }}
          </v-chip>
        </v-chip-group>
        <v-spacer />
        <v-chip size="small" variant="tonal" color="teal" rounded="lg" prepend-icon="mdi-clock-outline">
          {{ data.range.label }}
        </v-chip>
        <v-menu>
          <template #activator="{ props }">
            <v-btn v-bind="props" variant="outlined" rounded="lg" size="small"
                   prepend-icon="mdi-tray-arrow-down" class="text-none">Export</v-btn>
          </template>
          <v-list density="compact">
            <v-list-item @click="exportCsv('transactions')">
              <template #prepend><v-icon>mdi-swap-vertical</v-icon></template>
              <v-list-item-title>Transactions (CSV)</v-list-item-title>
            </v-list-item>
            <v-list-item @click="exportCsv('bills')">
              <template #prepend><v-icon>mdi-receipt-text-outline</v-icon></template>
              <v-list-item-title>Receivables (CSV)</v-list-item-title>
            </v-list-item>
            <v-list-item @click="exportCsv('expenses')">
              <template #prepend><v-icon>mdi-cash-clock</v-icon></template>
              <v-list-item-title>Payables (CSV)</v-list-item-title>
            </v-list-item>
            <v-list-item @click="exportCsv('ledger')">
              <template #prepend><v-icon>mdi-book-open-variant</v-icon></template>
              <v-list-item-title>General Ledger (CSV)</v-list-item-title>
            </v-list-item>
            <v-list-item @click="exportCsv('balance')">
              <template #prepend><v-icon>mdi-scale-balance</v-icon></template>
              <v-list-item-title>Balance Sheet (CSV)</v-list-item-title>
            </v-list-item>
          </v-list>
        </v-menu>
      </div>
    </v-card>

    <!-- KPIs -->
    <v-row dense class="mb-4">
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Revenue collected" :value="fmt(revenueInRange)" suffix="KSh"
                         icon="mdi-cash-multiple" color="#10b981"
                         :hint="`${paymentsInRange.length} payments`" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Outstanding" :value="fmt(outstanding)" suffix="KSh"
                         icon="mdi-clock-alert" color="#f59e0b"
                         :hint="`${openBills.length} open bills`" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Expenses" :value="fmt(expensesInRange)" suffix="KSh"
                         icon="mdi-cash-minus" color="#ef4444"
                         :hint="`${expensesInRangeList.length} entries`" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Net surplus" :value="fmt(netSurplus)" suffix="KSh"
                         icon="mdi-chart-line-variant" color="#0d9488"
                         hint="Revenue − Expenses" />
      </v-col>
    </v-row>

    <!-- Section pills -->
    <v-card flat rounded="lg" class="section-pills pa-2 mb-4 hc-card" border>
      <v-chip-group v-model="tab" mandatory selected-class="text-teal-darken-2">
        <v-chip v-for="s in sectionPills" :key="s.value" :value="s.value"
                size="small" filter variant="tonal" :color="s.color">
          <v-icon size="14" start>{{ s.icon }}</v-icon>{{ s.label }}
        </v-chip>
      </v-chip-group>
    </v-card>

    <!-- ============== OVERVIEW ============== -->
    <template v-if="tab === 'overview'">
      <v-row dense>
        <v-col cols="12" md="8">
          <HomecarePanel title="Revenue vs Expenses trend" subtitle="Collected payments against expenses"
                         icon="mdi-chart-areaspline" color="#0d9488">
            <div class="pa-4">
              <LineChart :series="chartData.series" :labels="chartData.dates" :height="240" />
              <div class="d-flex justify-center ga-6 mt-4">
                <div class="d-flex align-center"><v-icon color="#10b981" size="16" class="mr-2">mdi-rhombus</v-icon><span class="text-body-2 font-weight-medium">Revenue</span></div>
                <div class="d-flex align-center"><v-icon color="#ef4444" size="16" class="mr-2">mdi-rhombus</v-icon><span class="text-body-2 font-weight-medium">Expenses</span></div>
              </div>
            </div>
            <v-table density="comfortable">
              <tbody>
                <tr>
                  <td class="text-medium-emphasis">Payments collected (in range)</td>
                  <td class="text-right font-weight-bold text-success">{{ fmtMoney(revenueInRange) }}</td>
                </tr>
                <tr>
                  <td class="text-medium-emphasis">Billed to patients (in range)</td>
                  <td class="text-right font-weight-bold">{{ fmtMoney(billedInRange) }}</td>
                </tr>
                <tr>
                  <td class="text-medium-emphasis">Expenses (in range)</td>
                  <td class="text-right font-weight-bold text-error">({{ fmtMoney(expensesInRange) }})</td>
                </tr>
                <tr class="border-t">
                  <td class="font-weight-bold">Net surplus</td>
                  <td class="text-right font-weight-bold" :class="netSurplus >= 0 ? 'text-success' : 'text-error'">
                    {{ fmtMoney(netSurplus) }}
                  </td>
                </tr>
              </tbody>
            </v-table>
          </HomecarePanel>
        </v-col>
        <v-col cols="12" md="4">
          <HomecarePanel title="API Billing" subtitle="Platform usage" icon="mdi-chart-areaspline" color="#6366f1">
            <div v-if="apiBilling">
              <div class="d-flex justify-space-between mb-2">
                <span class="text-medium-emphasis">This month</span>
                <span class="font-weight-bold">{{ fmtMoney(apiBilling.current_month?.cost_so_far || 0) }}</span>
              </div>
              <div class="d-flex justify-space-between mb-2">
                <span class="text-medium-emphasis">Requests</span>
                <span>{{ Number(apiBilling.current_month?.total_requests || 0).toLocaleString() }}</span>
              </div>
              <div class="d-flex justify-space-between mb-2">
                <span class="text-medium-emphasis">Projected</span>
                <span class="font-weight-bold">{{ fmtMoney(apiBilling.current_month?.projected_cost || 0) }}</span>
              </div>
              <div class="d-flex justify-space-between">
                <span class="text-medium-emphasis">Days remaining</span>
                <span>{{ apiBilling.current_month?.days_remaining ?? '—' }}</span>
              </div>
              <v-btn to="/homecare/billing/usage" variant="tonal" color="indigo" size="small"
                     rounded="lg" class="text-none mt-3" block prepend-icon="mdi-open-in-new">
                View API billing
              </v-btn>
            </div>
            <div v-else class="text-center text-medium-emphasis py-4">
              <v-icon icon="mdi-chart-areaspline-variant" size="40" class="mb-2" />
              <div>No API billing data</div>
            </div>
          </HomecarePanel>
        </v-col>
      </v-row>

      <v-row dense class="mt-1">
        <v-col cols="12" md="6">
          <HomecarePanel title="Pending payables" subtitle="Operational costs awaiting payment" icon="mdi-cash-clock" color="#f97316">
            <v-list density="compact" lines="two">
              <v-list-item v-for="p in topPayables" :key="p.id" class="px-0">
                <template #prepend>
                  <v-avatar size="36" :color="p.status === 'pending' ? 'warning' : 'info'" variant="tonal">
                    <v-icon size="18">{{ p._kind.startsWith('api_bill') ? 'mdi-api' : 'mdi-cash-clock' }}</v-icon>
                  </v-avatar>
                </template>
                <v-list-item-title class="font-weight-medium">{{ p.title || '—' }}</v-list-item-title>
                <v-list-item-subtitle>
                  {{ p.vendor || '—' }} · {{ formatDate(p.expense_date) }}
                </v-list-item-subtitle>
                <template #append>
                  <span class="font-weight-bold text-error">{{ fmtMoney(p.amount) }}</span>
                </template>
              </v-list-item>
              <v-list-item v-if="!topPayables.length" class="text-medium-emphasis text-center">
                No pending payables
              </v-list-item>
            </v-list>
          </HomecarePanel>
        </v-col>
        <v-col cols="12" md="6">
          <HomecarePanel title="Open receivables" subtitle="Bills awaiting settlement" icon="mdi-receipt-text" color="#f59e0b">
            <v-list density="compact" lines="two">
              <v-list-item v-for="b in openBills.slice(0, 6)" :key="b.id" class="px-0">
                <template #prepend>
                  <v-avatar size="36" :color="billStatusColor(b.status)" variant="tonal">
                    <v-icon size="18">mdi-receipt</v-icon>
                  </v-avatar>
                </template>
                <v-list-item-title class="font-weight-medium">{{ b.patient_name || '—' }}</v-list-item-title>
                <v-list-item-subtitle>
                  {{ b.bill_number }} · {{ billStatusLabel(b.status) }}
                </v-list-item-subtitle>
                <template #append>
                  <span class="font-weight-bold text-error">{{ fmtMoney(b.balance) }}</span>
                </template>
              </v-list-item>
              <v-list-item v-if="!openBills.length" class="text-medium-emphasis text-center">
                No outstanding bills
              </v-list-item>
            </v-list>
          </HomecarePanel>
        </v-col>
      </v-row>
    </template>

    <!-- ============== RECEIVABLES (BILLS) ============== -->
    <HomecarePanel v-else-if="tab === 'receivables'" title="Patient bills" subtitle="All generated bills & outstanding balances"
                   icon="mdi-receipt-text" color="#f59e0b">
      <template #actions>
        <v-text-field v-model="billSearch" density="compact" variant="outlined" hide-details
                      placeholder="Search bills…" prepend-inner-icon="mdi-magnify"
                      rounded="lg" style="max-width: 240px" />
      </template>
      <v-data-table :headers="billHeaders" :items="filteredBills" :loading="loading" item-value="id"
                    density="comfortable" :items-per-page="15">
        <template #[`item.bill_number`]="{ item }">
          <span class="font-weight-medium">{{ item.bill_number }}</span>
        </template>
        <template #[`item.patient_name`]="{ item }">{{ item.patient_name || '—' }}</template>
        <template #[`item.total`]="{ item }">{{ fmtMoney(item.total) }}</template>
        <template #[`item.amount_paid`]="{ item }">{{ fmtMoney(item.amount_paid) }}</template>
        <template #[`item.balance`]="{ item }">
          <span :class="Number(item.balance) > 0 ? 'font-weight-bold text-error' : 'text-success'">
            {{ fmtMoney(item.balance) }}
          </span>
        </template>
        <template #[`item.created_at`]="{ item }">{{ formatDate(item.created_at) }}</template>
        <template #[`item.status`]="{ item }">
          <v-chip :color="billStatusColor(item.status)" size="small" variant="tonal" class="text-capitalize">
            {{ billStatusLabel(item.status) }}
          </v-chip>
        </template>
      </v-data-table>
    </HomecarePanel>

    <!-- ============== PAYABLES ============== -->
    <HomecarePanel v-else-if="tab === 'payables'" title="Accounts Payable" subtitle="Expenses and API charges managed in one queue"
                   icon="mdi-clock-alert-outline" color="#f97316">
      <template #actions>
        <v-btn to="/expenses" variant="tonal" color="warning" size="small" rounded="lg"
               class="text-none" prepend-icon="mdi-open-in-new">Manage</v-btn>
      </template>
      <v-row dense class="mb-4">
        <v-col cols="12" md="5">
          <v-text-field v-model="expSearch" density="comfortable" variant="solo-filled" flat hide-details clearable
                        placeholder="Search title, vendor, reference…" prepend-inner-icon="mdi-magnify" />
        </v-col>
        <v-col cols="6" md="3">
          <v-select v-model="expStatus" :items="expenseStatusItems" item-title="title" item-value="value"
                    density="comfortable" variant="outlined" hide-details label="Status" />
        </v-col>
        <v-col cols="6" md="4">
          <v-select v-model="expSort" :items="expenseSortItems" item-title="title" item-value="value"
                    density="comfortable" variant="outlined" hide-details label="Sort" />
        </v-col>
      </v-row>

      <v-row dense class="mb-4">
        <v-col v-for="bucket in payableBuckets" :key="bucket.key" cols="6" md="3">
          <v-card flat rounded="xl" class="pa-4 hc-card" border>
            <div class="d-flex align-center mb-2">
              <v-avatar :color="bucket.color" size="34" class="mr-2">
                <v-icon size="16" color="white">{{ bucket.icon }}</v-icon>
              </v-avatar>
              <div class="text-caption text-uppercase text-medium-emphasis">{{ bucket.label }}</div>
            </div>
            <div class="text-h6 font-weight-bold">{{ fmtMoney(bucket.total) }}</div>
            <div class="text-caption text-medium-emphasis">{{ bucket.count }} entries</div>
          </v-card>
        </v-col>
      </v-row>

      <v-card v-if="apiBilling" flat rounded="xl" class="mb-4 pa-4 hc-card" border>
        <div class="d-flex align-center flex-wrap ga-3">
          <v-avatar color="indigo" size="38"><v-icon color="white">mdi-api</v-icon></v-avatar>
          <div class="flex-grow-1">
            <div class="font-weight-bold">API Usage & Billing</div>
            <div class="text-caption text-medium-emphasis">Accrued platform charges are treated as payables in this tab.</div>
          </div>
          <v-btn to="/homecare/billing/usage" variant="text" color="indigo" append-icon="mdi-arrow-right">Usage</v-btn>
        </div>
        <v-row dense class="mt-3">
          <v-col cols="6" md="3">
            <div class="text-caption text-medium-emphasis">This month</div>
            <div class="text-subtitle-1 font-weight-bold">{{ fmtMoney(apiBilling.current_month?.cost_so_far || 0) }}</div>
          </v-col>
          <v-col cols="6" md="3">
            <div class="text-caption text-medium-emphasis">Projected</div>
            <div class="text-subtitle-1 font-weight-bold text-warning">{{ fmtMoney(apiBilling.current_month?.projected_cost || 0) }}</div>
          </v-col>
          <v-col cols="6" md="3">
            <div class="text-caption text-medium-emphasis">Outstanding API bills</div>
            <div class="text-subtitle-1 font-weight-bold text-error">{{ fmtMoney(apiOutstandingTotal) }}</div>
          </v-col>
          <v-col cols="6" md="3">
            <div class="text-caption text-medium-emphasis">Requests</div>
            <div class="text-subtitle-1 font-weight-bold">{{ Number(apiBilling.current_month?.total_requests || 0).toLocaleString() }}</div>
          </v-col>
        </v-row>
      </v-card>

      <v-data-table :headers="expHeaders" :items="filteredPayables" :loading="loading" item-value="id"
                    density="comfortable" :items-per-page="15">
        <template #[`item.expense_date`]="{ item }">{{ formatDate(item.expense_date) }}</template>
        <template #[`item.title`]="{ item }">
          <div class="font-weight-medium d-flex align-center ga-2">
            <span>{{ item.title }}</span>
            <v-chip v-if="item._virtual" size="x-small" color="indigo" variant="tonal">API</v-chip>
          </div>
          <div class="text-caption text-medium-emphasis">{{ item.reference || '—' }}</div>
        </template>
        <template #[`item.vendor`]="{ item }">{{ item.vendor || item.supplier_name || '—' }}</template>
        <template #[`item.category_name`]="{ item }">{{ item.category_name || '—' }}</template>
        <template #[`item.amount`]="{ item }">
          <span class="font-weight-bold text-error">{{ fmtMoney(item.amount) }}</span>
        </template>
        <template #[`item.payment_method`]="{ item }">
          <v-chip :color="paymentColor(item.payment_method)" size="small" variant="tonal">
            <v-icon size="14" start>{{ paymentIcon(item.payment_method) }}</v-icon>
            {{ item.payment_method || 'other' }}
          </v-chip>
        </template>
        <template #[`item.status`]="{ item }">
          <v-chip :color="expenseStatusColor(item.status)" size="small" variant="tonal" class="text-capitalize">
            {{ item.status }}
          </v-chip>
        </template>
      </v-data-table>
    </HomecarePanel>

    <!-- ============== TRANSACTIONS ============== -->
    <HomecarePanel v-else-if="tab === 'transactions'" title="Transactions" subtitle="Income and expense activity for the selected range"
                   icon="mdi-swap-vertical" color="#10b981">
      <template #actions>
        <div class="d-flex flex-wrap ga-2">
          <v-text-field v-model="txSearch" density="compact" variant="outlined" hide-details
                        placeholder="Search description / reference…" prepend-inner-icon="mdi-magnify"
                        rounded="lg" style="min-width: 220px" />
          <v-select v-model="txType" :items="transactionTypeItems" item-title="title" item-value="value"
                    density="compact" variant="outlined" hide-details rounded="lg" style="min-width: 140px" />
          <v-select v-model="txMethod" :items="transactionMethodItems" item-title="title" item-value="value"
                    density="compact" variant="outlined" hide-details rounded="lg" style="min-width: 160px" />
          <v-chip color="success" variant="tonal">{{ filteredTransactions.length }} entries</v-chip>
        </div>
      </template>
      <v-data-table :headers="transactionHeaders" :items="filteredTransactions" :loading="loading" item-value="id"
                    density="comfortable" :items-per-page="15">
        <template #[`item.date`]="{ item }">{{ formatDateTime(item.date) }}</template>
        <template #[`item.type`]="{ item }">
          <v-chip :color="item.type === 'income' ? 'success' : 'error'" size="small" variant="tonal">
            <v-icon size="14" start>{{ item.type === 'income' ? 'mdi-arrow-down-bold' : 'mdi-arrow-up-bold' }}</v-icon>
            {{ item.type === 'income' ? 'Income' : 'Expense' }}
          </v-chip>
        </template>
        <template #[`item.description`]="{ item }">
          <div class="font-weight-medium">{{ item.description }}</div>
          <div class="text-caption text-medium-emphasis">{{ item.source }}</div>
        </template>
        <template #[`item.method`]="{ item }">
          <v-chip :color="paymentColor(item.method)" size="small" variant="tonal">
            <v-icon size="14" start>{{ paymentIcon(item.method) }}</v-icon>
            {{ item.method || 'other' }}
          </v-chip>
        </template>
        <template #[`item.amount`]="{ item }">
          <span class="font-weight-bold" :class="item.type === 'income' ? 'text-success' : 'text-error'">
            {{ item.type === 'income' ? '+' : '-' }} {{ fmtMoney(item.amount) }}
          </span>
        </template>
      </v-data-table>
    </HomecarePanel>

    <!-- ============== P&L ============== -->
    <HomecarePanel v-else-if="tab === 'pnl'" :title="`Profit & Loss — ${data.range.label}`"
                   subtitle="Revenue less expenses for the selected period" icon="mdi-chart-box" color="#0d9488">
      <div class="pa-4 bg-teal-lighten-5 rounded-lg mb-4 border-dashed" border>
        <div class="text-overline text-teal-darken-2 font-weight-bold mb-2">Net surplus trend</div>
        <SparkArea :values="chartData.netValues" :labels="chartData.dates" :height="120" color="#0d9488" />
      </div>
      <v-table density="comfortable" class="pnl-table">
        <tbody>
          <tr><td colspan="2" class="text-overline font-weight-bold">Revenue</td></tr>
          <tr>
            <td class="pl-8 text-medium-emphasis">Patient payments collected</td>
            <td class="text-right">{{ fmtMoney(revenueInRange) }}</td>
          </tr>
          <tr class="border-t">
            <td class="font-weight-bold">Total revenue</td>
            <td class="text-right font-weight-bold text-success">{{ fmtMoney(revenueInRange) }}</td>
          </tr>
          <tr><td colspan="2" class="text-overline font-weight-bold">Expenses</td></tr>
          <tr>
            <td class="pl-8 text-medium-emphasis">Operating expenses + API charges</td>
            <td class="text-right">({{ fmtMoney(expensesInRange) }})</td>
          </tr>
          <tr class="border-t">
            <td class="font-weight-bold">Total expenses</td>
            <td class="text-right font-weight-bold text-error">({{ fmtMoney(expensesInRange) }})</td>
          </tr>
          <tr class="border-t pnl-net">
            <td class="font-weight-bold text-h6">Net surplus / (deficit)</td>
            <td class="text-right font-weight-bold text-h6" :class="netSurplus >= 0 ? 'text-success' : 'text-error'">
              {{ fmtMoney(netSurplus) }}
            </td>
          </tr>
        </tbody>
      </v-table>
    </HomecarePanel>

    <!-- ============== BALANCE SHEET ============== -->
    <template v-else-if="tab === 'balance'">
      <v-row dense>
        <v-col cols="12" md="7">
          <HomecarePanel :title="`Balance Sheet · as of ${formatDate(data.range.end)}`"
                         subtitle="Assets, Liabilities and Equity summary"
                         icon="mdi-scale-balance" color="#10b981">
            <v-table density="comfortable" class="pnl-table">
              <tbody>
                <tr class="pnl-section"><td colspan="2" class="text-overline font-weight-bold">ASSETS</td></tr>
                <tr><td class="pl-8 text-medium-emphasis">Cash / Bank (Collected)</td><td class="text-right">{{ fmtMoney(revenueInRange) }}</td></tr>
                <tr><td class="pl-8 text-medium-emphasis">Accounts Receivable (Outstanding)</td><td class="text-right">{{ fmtMoney(outstanding) }}</td></tr>
                <tr class="border-t">
                  <td class="font-weight-bold">Total Assets</td>
                  <td class="text-right font-weight-bold text-success">{{ fmtMoney(revenueInRange + outstanding) }}</td>
                </tr>

                <tr class="pnl-section pt-4"><td colspan="2" class="text-overline font-weight-bold">LIABILITIES</td></tr>
                <tr><td class="pl-8 text-medium-emphasis">Accounts Payable (Approved Expenses)</td><td class="text-right">{{ fmtMoney(payablesTotal) }}</td></tr>
                <tr><td class="pl-8 text-medium-emphasis">API Usage Payable (Included)</td><td class="text-right">{{ fmtMoney(apiOutstandingTotal) }}</td></tr>
                <tr class="border-t">
                  <td class="font-weight-bold">Total Liabilities</td>
                  <td class="text-right font-weight-bold text-error">({{ fmtMoney(payablesTotal) }})</td>
                </tr>

                <tr class="pnl-section pt-4"><td colspan="2" class="text-overline font-weight-bold">EQUITY</td></tr>
                <tr><td class="pl-8 text-medium-emphasis">Retained Earnings (Period)</td><td class="text-right">{{ fmtMoney(netSurplus) }}</td></tr>
                <tr class="border-t">
                  <td class="font-weight-bold">Total Equity</td>
                  <td class="text-right font-weight-bold text-teal">{{ fmtMoney(netSurplus) }}</td>
                </tr>
              </tbody>
            </v-table>
          </HomecarePanel>
        </v-col>
        <v-col cols="12" md="5">
          <HomecarePanel title="Financial position" icon="mdi-chart-donut" color="#6366f1">
            <div class="pa-2">
              <div v-for="r in financialRatios" :key="r.label" class="mb-4">
                <div class="d-flex justify-space-between mb-1">
                  <span class="text-body-2 text-medium-emphasis">{{ r.label }}</span>
                  <span class="font-weight-bold">{{ r.value }}</span>
                </div>
                <v-progress-linear :model-value="r.pct" :color="r.color" height="6" rounded />
              </div>
            </div>
          </HomecarePanel>
        </v-col>
      </v-row>
    </template>

    <!-- ============== GENERAL LEDGER ============== -->
    <template v-else-if="tab === 'ledger'">
      <HomecarePanel title="General Ledger" subtitle="Trial balance, journal entries and account activity for the selected period"
                     icon="mdi-book-open-variant" color="#6366f1">
        <v-card flat rounded="xl" border class="mb-4 pa-3 hc-card">
          <div class="d-flex flex-wrap align-center" style="gap:12px">
            <v-text-field v-model="ledgerSearch" label="Search description / ref"
                          prepend-inner-icon="mdi-magnify" variant="outlined" density="comfortable"
                          hide-details style="min-width:240px" />
            <v-select v-model="glAccount" :items="glAccountOptions" item-title="title" item-value="value"
                      label="Account" variant="outlined" density="comfortable"
                      hide-details clearable style="min-width:220px" />
            <v-select v-model="glType" :items="glTypeOptions" item-title="title" item-value="value"
                      label="Source" variant="outlined" density="comfortable"
                      hide-details clearable style="min-width:180px" />
            <v-spacer />
            <v-chip color="success" variant="tonal" size="small" prepend-icon="mdi-arrow-down">
              DR: {{ fmtMoney(glTotals.debit) }}
            </v-chip>
            <v-chip color="error" variant="tonal" size="small" prepend-icon="mdi-arrow-up">
              CR: {{ fmtMoney(glTotals.credit) }}
            </v-chip>
            <v-chip :color="glTotals.balanced ? 'success' : 'orange'" variant="flat" size="small">
              {{ glTotals.balanced ? 'Balanced' : 'Variance ' + fmtMoney(Math.abs(glTotals.variance)) }}
            </v-chip>
            <v-btn variant="text" prepend-icon="mdi-download" size="small"
                   @click="exportCsv('ledger')">Export CSV</v-btn>
          </div>
        </v-card>

        <v-card flat rounded="xl" border class="mb-4 hc-card">
          <v-card-title class="d-flex align-center">
            <v-icon class="mr-2" color="indigo">mdi-scale-unbalanced</v-icon>
            <span class="font-weight-bold">Trial Balance</span>
            <v-spacer />
            <v-chip size="small" variant="tonal" color="indigo">{{ data?.range?.label }}</v-chip>
          </v-card-title>
          <v-data-table :headers="trialBalanceHeaders" :items="trialBalance" hide-default-footer
                        density="comfortable" :items-per-page="-1">
            <template #item.account="{ item }">
              <div class="d-flex align-center">
                <v-avatar :color="item.color" size="28" variant="tonal" class="mr-2">
                  <v-icon size="16">{{ item.icon }}</v-icon>
                </v-avatar>
                <div>
                  <div class="font-weight-medium">{{ item.account }}</div>
                  <div class="text-caption text-medium-emphasis text-uppercase">{{ item.type }}</div>
                </div>
              </div>
            </template>
            <template #item.debit="{ item }">{{ item.debit ? fmtMoney(item.debit) : '—' }}</template>
            <template #item.credit="{ item }">{{ item.credit ? fmtMoney(item.credit) : '—' }}</template>
            <template #item.net="{ item }">
              <strong :class="item.net >= 0 ? '' : 'text-error'">{{ fmtMoney(Math.abs(item.net)) }}</strong>
            </template>
          </v-data-table>
        </v-card>

        <v-card flat rounded="xl" border class="mb-4 hc-card">
          <v-card-title class="d-flex align-center">
            <v-icon class="mr-2" color="teal-darken-2">mdi-book-open-page-variant</v-icon>
            <span class="font-weight-bold">Journal Entries</span>
            <v-spacer />
            <v-chip size="small" variant="tonal">{{ glFiltered.length }} entries</v-chip>
          </v-card-title>
          <v-data-table :headers="glHeaders" :items="glFiltered" :loading="loading"
                        density="comfortable" :items-per-page="25" class="ledger-table">
            <template #item.date="{ item }">
              <div class="text-caption text-medium-emphasis">{{ formatDate(item.date) }}</div>
            </template>
            <template #item.reference="{ item }">
              <v-chip size="x-small" variant="tonal" :color="item.source_color">{{ item.source }}</v-chip>
              <div class="text-caption font-weight-medium">{{ item.reference }}</div>
            </template>
            <template #item.description="{ item }">
              <div>{{ item.description }}</div>
              <div v-if="item.party" class="text-caption text-medium-emphasis">{{ item.party }}</div>
            </template>
            <template #item.account="{ item }">
              <v-chip size="small" variant="tonal" :color="item.account_color">{{ item.account }}</v-chip>
            </template>
            <template #item.debit="{ item }">
              <strong v-if="item.debit > 0" class="text-success">{{ fmtMoney(item.debit) }}</strong>
              <span v-else class="text-medium-emphasis">—</span>
            </template>
            <template #item.credit="{ item }">
              <strong v-if="item.credit > 0" class="text-error">{{ fmtMoney(item.credit) }}</strong>
              <span v-else class="text-medium-emphasis">—</span>
            </template>
          </v-data-table>
        </v-card>

        <v-row dense>
          <v-col cols="12" md="7">
            <v-card flat rounded="xl" border class="pa-4 h-100 hc-card">
              <div class="d-flex align-center mb-3">
                <v-icon class="mr-2" color="indigo">mdi-chart-bar</v-icon>
                <span class="font-weight-bold">Debit vs Credit by Account</span>
                <v-spacer />
                <v-chip size="x-small" variant="tonal" color="success" class="mr-1">
                  <v-icon size="12" start>mdi-square</v-icon>Debit
                </v-chip>
                <v-chip size="x-small" variant="tonal" color="error">
                  <v-icon size="12" start>mdi-square</v-icon>Credit
                </v-chip>
              </div>
              <div v-if="!trialBalance.length" class="text-center text-medium-emphasis py-6">
                <v-icon size="32">mdi-chart-bar</v-icon>
                <div class="text-caption mt-2">No journal activity in this period</div>
              </div>
              <div v-else class="tb-bars">
                <div v-for="row in trialBalance" :key="row.account" class="tb-bar-row">
                  <div class="tb-bar-label">
                    <v-icon :color="row.color" size="16" class="mr-1">{{ row.icon }}</v-icon>
                    <span class="text-caption font-weight-medium">{{ row.account }}</span>
                  </div>
                  <div class="tb-bar-track">
                    <div class="tb-bar tb-bar-dr"
                         :style="{ width: barPct(row.debit) + '%' }"
                         :title="'Debit: ' + fmtMoney(row.debit)">
                      <span v-if="row.debit > 0 && barPct(row.debit) > 12" class="tb-bar-text">
                        {{ fmtMoney(row.debit) }}
                      </span>
                    </div>
                    <div class="tb-bar tb-bar-cr"
                         :style="{ width: barPct(row.credit) + '%' }"
                         :title="'Credit: ' + fmtMoney(row.credit)">
                      <span v-if="row.credit > 0 && barPct(row.credit) > 12" class="tb-bar-text">
                        {{ fmtMoney(row.credit) }}
                      </span>
                    </div>
                  </div>
                  <div class="tb-bar-net">
                    <v-chip size="x-small" variant="tonal"
                            :color="row.net >= 0 ? 'success' : 'error'">
                      {{ row.net >= 0 ? 'DR' : 'CR' }} {{ fmtMoney(Math.abs(row.net)) }}
                    </v-chip>
                  </div>
                </div>
              </div>
            </v-card>
          </v-col>

          <v-col cols="12" md="5">
            <v-card flat rounded="xl" border class="pa-4 h-100 hc-card">
              <div class="d-flex align-center mb-3">
                <v-icon class="mr-2" color="deep-purple">mdi-chart-donut</v-icon>
                <span class="font-weight-bold">Activity by Account Type</span>
              </div>
              <div v-if="!tbComposition.total" class="text-center text-medium-emphasis py-6">
                <v-icon size="32">mdi-chart-donut</v-icon>
                <div class="text-caption mt-2">No data</div>
              </div>
              <div v-else class="d-flex align-center justify-center flex-column">
                <svg :viewBox="'0 0 120 120'" width="180" height="180" class="tb-donut">
                  <circle cx="60" cy="60" r="50" fill="none" stroke="#f1f5f9" stroke-width="16" />
                  <circle v-for="(seg, i) in tbComposition.segments" :key="i"
                          cx="60" cy="60" r="50" fill="none"
                          :stroke="seg.color" stroke-width="16"
                          :stroke-dasharray="seg.dash"
                          :stroke-dashoffset="seg.offset"
                          transform="rotate(-90 60 60)" />
                  <text x="60" y="56" text-anchor="middle" class="tb-donut-num">
                    {{ fmtMoney(tbComposition.total) }}
                  </text>
                  <text x="60" y="70" text-anchor="middle" class="tb-donut-lbl">Total Activity</text>
                </svg>
                <div class="mt-3 w-100">
                  <div v-for="seg in tbComposition.segments" :key="seg.label"
                       class="d-flex align-center justify-space-between py-1">
                    <div class="d-flex align-center">
                      <span class="tb-dot" :style="{ background: seg.color }"></span>
                      <span class="text-caption font-weight-medium ml-2">{{ seg.label }}</span>
                    </div>
                    <div>
                      <span class="text-caption font-weight-bold mr-2">{{ fmtMoney(seg.value) }}</span>
                      <v-chip size="x-small" variant="tonal" color="grey">{{ seg.pct.toFixed(1) }}%</v-chip>
                    </div>
                  </div>
                </div>
              </div>
            </v-card>
          </v-col>

          <v-col cols="12">
            <v-card flat rounded="xl" border class="pa-4 hc-card">
              <div class="d-flex align-center mb-3">
                <v-icon class="mr-2" color="teal">mdi-chart-timeline-variant</v-icon>
                <span class="font-weight-bold">Net Balance per Account</span>
                <v-spacer />
                <v-chip size="x-small" variant="tonal" color="success" class="mr-1">Debit balance →</v-chip>
                <v-chip size="x-small" variant="tonal" color="error">← Credit balance</v-chip>
              </div>
              <div v-if="!trialBalance.length" class="text-center text-medium-emphasis py-6">
                <v-icon size="32">mdi-chart-timeline-variant</v-icon>
                <div class="text-caption mt-2">No data</div>
              </div>
              <div v-else class="tb-net-chart">
                <div v-for="row in trialBalance" :key="row.account" class="tb-net-row">
                  <div class="tb-net-label">
                    <v-icon :color="row.color" size="14" class="mr-1">{{ row.icon }}</v-icon>
                    <span class="text-caption">{{ row.account }}</span>
                  </div>
                  <div class="tb-net-track">
                    <div class="tb-net-axis"></div>
                    <div class="tb-net-bar"
                         :class="row.net >= 0 ? 'tb-net-dr' : 'tb-net-cr'"
                         :style="netBarStyle(row.net)">
                      <span class="tb-net-value">{{ fmtMoney(Math.abs(row.net)) }}</span>
                    </div>
                  </div>
                </div>
              </div>
            </v-card>
          </v-col>
        </v-row>
      </HomecarePanel>
    </template>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { formatDate, formatDateTime } from '~/utils/format'

const { $api } = useNuxtApp()
const route = useRoute()

function normalizeTab(value) {
  const map = { payments: 'transactions', expenses: 'payables', api: 'payables' }
  const normalized = map[value] || value
  return ['overview', 'receivables', 'payables', 'transactions', 'pnl', 'balance', 'ledger'].includes(normalized)
    ? normalized
    : 'overview'
}

const loading = ref(false)
const tab = ref(normalizeTab(route.query.tab))
const bills = ref([])
const payments = ref([])
const expenses = ref([])
const apiBilling = ref(null)
const billSearch = ref('')
const ledgerSearch = ref('')
const expSearch = ref('')
const expStatus = ref('all')
const expSort = ref('date_desc')
const txSearch = ref('')
const txType = ref('all')
const txMethod = ref('all')
const glAccount = ref(null)
const glType = ref(null)

const snack = ref({ show: false, color: 'success', text: '' })
const notify = (text, color = 'success') => { snack.value = { show: true, color, text } }

const sectionPills = [
  { value: 'overview',    label: 'Overview',      color: 'teal',        icon: 'mdi-view-dashboard-outline' },
  { value: 'receivables', label: 'Receivables',   color: 'warning',     icon: 'mdi-receipt-text' },
  { value: 'payables',    label: 'Payables',      color: 'deep-orange', icon: 'mdi-clock-alert-outline' },
  { value: 'transactions', label: 'Transactions', color: 'success',     icon: 'mdi-swap-vertical' },
  { value: 'pnl',         label: 'Profit & Loss', color: 'indigo',      icon: 'mdi-chart-box' },
  { value: 'balance',     label: 'Balance Sheet', color: 'green',       icon: 'mdi-scale-balance' },
  { value: 'ledger',      label: 'General Ledger',color: 'deep-purple', icon: 'mdi-book-open-variant' },
]

const ACC = {
  CASH:    { name: '1000 · Cash & Bank',         color: 'success',          icon: 'mdi-bank',              type: 'asset' },
  AR:      { name: '1100 · Accounts Receivable', color: 'amber-darken-2',   icon: 'mdi-receipt-text',      type: 'asset' },
  AP:      { name: '2000 · Accounts Payable',    color: 'orange',           icon: 'mdi-cash-clock',        type: 'liability' },
  REVENUE: { name: '4000 · Homecare Revenue',    color: 'teal-darken-2',    icon: 'mdi-cash-plus',         type: 'income' },
  EXPENSE: { name: '6000 · Operating Expenses',  color: 'red-darken-1',     icon: 'mdi-cash-minus',        type: 'expense' },
  APIEXP:  { name: '6100 · Platform Usage',      color: 'deep-purple',      icon: 'mdi-api',               type: 'expense' },
}

// ────── Date range
const rangeKey = ref('30d')
const rangeChips = [
  { key: 'today', label: 'Today' },
  { key: '7d', label: 'Last 7 days' },
  { key: '30d', label: 'Last 30 days' },
  { key: 'mtd', label: 'Month to date' },
  { key: '90d', label: 'Last 90 days' },
  { key: 'ytd', label: 'Year to date' },
]
const data = ref({ range: resolveRange() })

function resolveRange() {
  const today = new Date()
  const iso = (d) => d.toISOString().slice(0, 10)
  const sub = (n) => { const d = new Date(today); d.setDate(d.getDate() - n); return d }
  const monthStart = new Date(today.getFullYear(), today.getMonth(), 1)
  const yearStart = new Date(today.getFullYear(), 0, 1)
  switch (rangeKey.value) {
    case 'today': return { start: iso(today), end: iso(today), label: 'Today' }
    case '7d': return { start: iso(sub(6)), end: iso(today), label: 'Last 7 days' }
    case 'mtd': return { start: iso(monthStart), end: iso(today), label: 'Month to date' }
    case '90d': return { start: iso(sub(89)), end: iso(today), label: 'Last 90 days' }
    case 'ytd': return { start: iso(yearStart), end: iso(today), label: 'Year to date' }
    case '30d':
    default: return { start: iso(sub(29)), end: iso(today), label: 'Last 30 days' }
  }
}

watch(rangeKey, () => { data.value.range = resolveRange() })

function pickRows(settled) {
  if (settled.status !== 'fulfilled') return []
  const d = settled.value?.data
  return d?.results || (Array.isArray(d) ? d : [])
}

async function loadAll() {
  loading.value = true
  try {
    const [b, p, e, api] = await Promise.allSettled([
      $api.get('/homecare/patient-bills/', { params: { page_size: 500, ordering: '-created_at' } }),
      $api.get('/homecare/patient-payments/', { params: { page_size: 500, ordering: '-paid_at' } }),
      $api.get('/expenses/expenses/', { params: { page_size: 500, ordering: '-expense_date' } }),
      $api.get('/usage-billing/dashboard/'),
    ])
    bills.value = pickRows(b)
    payments.value = pickRows(p)
    expenses.value = pickRows(e)
    apiBilling.value = api.status === 'fulfilled' ? api.value?.data : null
  } catch (e) {
    notify('Failed to load accounts data', 'error')
  } finally {
    loading.value = false
  }
}

onMounted(loadAll)
watch(() => route.query.tab, v => { tab.value = normalizeTab(v) })

// ── Range filtering
const inRange = (iso) => {
  if (!iso) return false
  const d = String(iso).slice(0, 10)
  return d >= data.value.range.start && d <= data.value.range.end
}
const paymentsInRange = computed(() => payments.value.filter(p => inRange(p.paid_at)))
const billsInRange = computed(() => bills.value.filter(b => inRange(b.created_at)))

// ── Helpers
const fmt = (v) => Number(v || 0).toLocaleString(undefined, { maximumFractionDigits: 0 })
const fmtMoney = (v) => 'KSh ' + Number(v || 0).toLocaleString(undefined, { maximumFractionDigits: 2 })
const expenseAmount = (e) => Number(e?.total_amount || e?.amount || 0)
const expenseDate = (e) => e?.expense_date || e?.created_at || null

function monthLabel(year, month) {
  try {
    return new Date(year, month - 1, 1).toLocaleString(undefined, { month: 'short', year: 'numeric' })
  } catch {
    return `${year}-${month}`
  }
}

const expenseEntries = computed(() =>
  expenses.value.map(e => ({
    ...e,
    title: e.title || e.description || 'Expense',
    reference: e.reference || e.payment_reference || '',
    vendor: e.vendor || e.supplier_name || '—',
    amount: expenseAmount(e),
    payment_method: e.payment_method || 'other',
    expense_date: expenseDate(e),
    category_name: e.category_name || e.category?.name || 'Expense',
    _virtual: false,
    _kind: 'expense',
  }))
)

const apiPayableEntries = computed(() => {
  const rows = []
  const ab = apiBilling.value
  if (!ab) return rows

  for (const bill of (ab.recent_bills || [])) {
    rows.push({
      id: `apibill-${bill.id}`,
      title: `API Usage - ${monthLabel(bill.year, bill.month)}`,
      reference: `Bill #${bill.id}`,
      vendor: 'AfyaOne Platform',
      amount: Number(bill.amount || 0),
      payment_method: 'bank_transfer',
      expense_date: `${bill.year}-${String(bill.month).padStart(2, '0')}-01`,
      due_date: null,
      status: bill.status === 'PAID' ? 'paid' : bill.status === 'CANCELLED' ? 'cancelled' : 'approved',
      category_name: 'API Usage & Billing',
      paid_at: bill.paid_at,
      _virtual: true,
      _kind: 'api_bill',
    })
  }

  const current = ab.current_month
  if (current && Number(current.cost_so_far || 0) > 0) {
    rows.push({
      id: `apibill-current-${current.year}-${current.month}`,
      title: `API Usage - ${monthLabel(current.year, current.month)} (accruing)`,
      reference: `${Number(current.total_requests || 0).toLocaleString()} requests`,
      vendor: 'AfyaOne Platform',
      amount: Number(current.cost_so_far || 0),
      payment_method: 'bank_transfer',
      expense_date: `${current.year}-${String(current.month).padStart(2, '0')}-01`,
      due_date: null,
      status: 'pending',
      category_name: 'API Usage & Billing',
      _virtual: true,
      _kind: 'api_bill_current',
      _projected_cost: Number(current.projected_cost || 0),
    })
  }

  return rows
})

const payableEntries = computed(() => [...expenseEntries.value, ...apiPayableEntries.value])
const expensesInRangeList = computed(() =>
  payableEntries.value.filter(e => inRange(e.expense_date) && !['rejected', 'cancelled'].includes(e.status)))

const revenueInRange = computed(() =>
  paymentsInRange.value.reduce((s, p) => s + Number(p.amount || 0), 0))
const expensesInRange = computed(() =>
  expensesInRangeList.value.reduce((s, e) => s + expenseAmount(e), 0))
const billedInRange = computed(() =>
  billsInRange.value.reduce((s, b) => s + Number(b.total || 0), 0))
const openBills = computed(() =>
  bills.value.filter(b => b.status !== 'paid' && b.status !== 'void' && Number(b.balance || 0) > 0))
const outstanding = computed(() =>
  openBills.value.reduce((s, b) => s + Number(b.balance || 0), 0))
const netSurplus = computed(() => revenueInRange.value - expensesInRange.value)

// ── Chart data
const chartData = computed(() => {
  const dates = []
  const start = new Date(data.value.range.start)
  const end = new Date(data.value.range.end)
  for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
    dates.push(d.toISOString().slice(0, 10))
  }

  const revValues = [], expValues = [], netValues = []
  dates.forEach(date => {
    const rev = payments.value.filter(p => (p.paid_at || '').slice(0, 10) === date)
      .reduce((s, p) => s + Number(p.amount || 0), 0)
    const exp = payableEntries.value
      .filter(e => !['rejected', 'cancelled'].includes(e.status) && (e.expense_date || '').slice(0, 10) === date)
      .reduce((s, e) => s + expenseAmount(e), 0)

    revValues.push(rev)
    expValues.push(exp)
    netValues.push(rev - exp)
  })

  return {
    dates,
    netValues,
    series: [
      { label: 'Revenue', color: '#10b981', values: revValues },
      { label: 'Expenses', color: '#ef4444', values: expValues }
    ]
  }
})

const payablesTotal = computed(() =>
  payableEntries.value
    .filter(e => ['pending', 'approved'].includes(e.status))
    .reduce((s, e) => s + expenseAmount(e), 0))

const topPayables = computed(() =>
  payableEntries.value
    .filter(e => ['pending', 'approved'].includes(e.status))
    .sort((a, b) => expenseAmount(b) - expenseAmount(a))
    .slice(0, 6))

const apiOutstandingTotal = computed(() =>
  apiPayableEntries.value
    .filter(e => ['pending', 'approved'].includes(e.status))
    .reduce((s, e) => s + expenseAmount(e), 0))

const payableBuckets = computed(() => {
  const rows = payableEntries.value
  const totalOf = (statuses, kind = null) => rows
    .filter(e => statuses.includes(e.status) && (!kind || e._kind.startsWith(kind)))
    .reduce((s, e) => s + expenseAmount(e), 0)
  const countOf = (statuses, kind = null) => rows
    .filter(e => statuses.includes(e.status) && (!kind || e._kind.startsWith(kind))).length

  return [
    { key: 'pending', label: 'Pending', total: totalOf(['pending']), count: countOf(['pending']), color: '#f59e0b', icon: 'mdi-timer-sand' },
    { key: 'approved', label: 'Approved', total: totalOf(['approved']), count: countOf(['approved']), color: '#3b82f6', icon: 'mdi-check-decagram' },
    { key: 'paid', label: 'Paid', total: totalOf(['paid']), count: countOf(['paid']), color: '#10b981', icon: 'mdi-cash-check' },
    { key: 'api', label: 'API Charges', total: totalOf(['pending', 'approved', 'paid'], 'api_bill'), count: countOf(['pending', 'approved', 'paid'], 'api_bill'), color: '#6366f1', icon: 'mdi-api' },
  ]
})

const filteredPayables = computed(() => {
  const q = expSearch.value.toLowerCase().trim()
  const filtered = payableEntries.value.filter(e => {
    if (!inRange(e.expense_date)) return false
    if (expStatus.value !== 'all' && e.status !== expStatus.value) return false
    if (!q) return true
    return [e.title, e.vendor, e.reference, e.category_name]
      .some(v => String(v || '').toLowerCase().includes(q))
  })

  return [...filtered].sort((a, b) => {
    switch (expSort.value) {
      case 'amount_desc': return expenseAmount(b) - expenseAmount(a)
      case 'amount_asc': return expenseAmount(a) - expenseAmount(b)
      case 'date_asc': return String(a.expense_date || '').localeCompare(String(b.expense_date || ''))
      case 'date_desc':
      default: return String(b.expense_date || '').localeCompare(String(a.expense_date || ''))
    }
  })
})

const financialRatios = computed(() => {
  const assets = revenueInRange.value + outstanding.value
  const liab = payablesTotal.value
  const currentRatio = liab > 0 ? (assets / liab).toFixed(2) : '∞'
  const margin = billedInRange.value > 0 ? ((netSurplus.value / billedInRange.value) * 100).toFixed(1) : '0'
  return [
    { label: 'Current Ratio', value: currentRatio, pct: Math.min(100, Number(currentRatio) * 20), color: Number(currentRatio) > 1.5 ? 'success' : 'warning' },
    { label: 'Net Margin', value: margin + '%', pct: Math.min(100, Math.abs(Number(margin))), color: Number(margin) > 0 ? 'teal' : 'error' },
    { label: 'Collection Efficiency', value: billedInRange.value > 0 ? ((revenueInRange.value / billedInRange.value) * 100).toFixed(1) + '%' : '0%', pct: billedInRange.value > 0 ? (revenueInRange.value / billedInRange.value) * 100 : 0, color: 'info' }
  ]
})

function jentry(date, source, sourceColor, reference, description, account, debit, credit, party = '') {
  return {
    date: String(date || data.value.range.end).slice(0, 10),
    source,
    source_color: sourceColor,
    reference,
    description,
    party,
    account: account.name,
    account_color: account.color,
    account_meta: account,
    debit: Number(debit || 0),
    credit: Number(credit || 0),
  }
}

const journalEntries = computed(() => {
  const entries = []

  bills.value
    .filter(b => inRange(b.created_at) && !['draft', 'void'].includes(b.status))
    .forEach(b => {
      const total = Number(b.total || 0)
      const ref = b.bill_number || `BILL-${b.id}`
      const patient = b.patient_name || 'Patient'
      entries.push(jentry(b.created_at, 'BILL', 'amber', ref, 'Patient bill issued', ACC.AR, total, 0, patient))
      entries.push(jentry(b.created_at, 'BILL', 'amber', ref, 'Homecare service revenue', ACC.REVENUE, 0, total, patient))
    })

  paymentsInRange.value.forEach(p => {
    const amount = Number(p.amount || 0)
    const ref = p.reference || p.bill_number || `PAY-${p.id}`
    const patient = p.patient_name || 'Patient'
    entries.push(jentry(p.paid_at, 'PAY', 'blue', ref, `Payment received (${p.method || 'cash'})`, ACC.CASH, amount, 0, patient))
    entries.push(jentry(p.paid_at, 'PAY', 'blue', ref, 'Settlement against receivable', ACC.AR, 0, amount, patient))
  })

  payableEntries.value
    .filter(e => inRange(e.expense_date) && !['rejected', 'cancelled'].includes(e.status))
    .forEach(e => {
      const amount = expenseAmount(e)
      const ref = e.reference || `EXP-${e.id}`
      const party = e.vendor || e.supplier_name || 'Vendor'
      const expenseAccount = e._kind.startsWith('api_bill') ? ACC.APIEXP : ACC.EXPENSE
      const source = e._kind.startsWith('api_bill') ? 'API' : 'EXP'
      const sourceColor = e.status === 'paid' ? 'error' : 'orange'

      entries.push(jentry(e.expense_date, source, sourceColor, ref, e.title, expenseAccount, amount, 0, party))
      if (e.status === 'paid') {
        entries.push(jentry(e.paid_at || e.expense_date, source, sourceColor, ref, `Paid via ${e.payment_method || 'cash'}`, ACC.CASH, 0, amount, party))
      } else {
        entries.push(jentry(e.expense_date, source, sourceColor, ref, 'Vendor / platform payable', ACC.AP, 0, amount, party))
      }
    })

  return entries.sort((a, b) => (b.date > a.date ? 1 : -1))
})

const glFiltered = computed(() => {
  const q = ledgerSearch.value.toLowerCase().trim()
  return journalEntries.value.filter(e => {
    if (glAccount.value && e.account !== glAccount.value) return false
    if (glType.value && e.source !== glType.value) return false
    if (!q) return true
    return (e.description || '').toLowerCase().includes(q)
      || (e.reference || '').toLowerCase().includes(q)
      || (e.party || '').toLowerCase().includes(q)
  })
})

const glTotals = computed(() => {
  const debit = glFiltered.value.reduce((sum, entry) => sum + entry.debit, 0)
  const credit = glFiltered.value.reduce((sum, entry) => sum + entry.credit, 0)
  return { debit, credit, variance: debit - credit, balanced: Math.abs(debit - credit) < 1 }
})

const trialBalance = computed(() => {
  const rows = new Map()
  journalEntries.value.forEach(entry => {
    const current = rows.get(entry.account) || {
      account: entry.account,
      debit: 0,
      credit: 0,
      color: entry.account_color,
      icon: entry.account_meta.icon,
      type: entry.account_meta.type,
    }
    current.debit += entry.debit
    current.credit += entry.credit
    rows.set(entry.account, current)
  })
  return [...rows.values()]
    .map(row => ({ ...row, net: row.debit - row.credit }))
    .sort((a, b) => a.account.localeCompare(b.account))
})

const tbMaxValue = computed(() =>
  Math.max(1, ...trialBalance.value.flatMap(row => [row.debit, row.credit])))

function barPct(value) {
  return Math.min(100, (Number(value || 0) / tbMaxValue.value) * 100)
}

const tbNetMax = computed(() =>
  Math.max(1, ...trialBalance.value.map(row => Math.abs(row.net))))

function netBarStyle(net) {
  const pct = Math.min(48, (Math.abs(Number(net || 0)) / tbNetMax.value) * 48)
  return net >= 0
    ? { left: '50%', width: pct + '%' }
    : { right: '50%', width: pct + '%' }
}

const TYPE_COLORS = {
  asset: '#10b981',
  liability: '#f97316',
  income: '#3b82f6',
  expense: '#ef4444',
  equity: '#8b5cf6',
}

const TYPE_LABELS = {
  asset: 'Assets',
  liability: 'Liabilities',
  income: 'Revenue',
  expense: 'Expenses',
  equity: 'Equity',
}

const tbComposition = computed(() => {
  const groups = {}
  trialBalance.value.forEach(row => {
    const type = row.type || 'other'
    groups[type] = (groups[type] || 0) + row.debit + row.credit
  })
  const total = Object.values(groups).reduce((sum, value) => sum + value, 0)
  if (!total) return { total: 0, segments: [] }
  const circumference = 2 * Math.PI * 50
  let offset = 0
  const segments = Object.entries(groups)
    .sort((a, b) => b[1] - a[1])
    .map(([key, value]) => {
      const pct = (value / total) * 100
      const length = (value / total) * circumference
      const segment = {
        label: TYPE_LABELS[key] || key,
        value,
        pct,
        color: TYPE_COLORS[key] || '#94a3b8',
        dash: `${length} ${circumference - length}`,
        offset: -offset,
      }
      offset += length
      return segment
    })
  return { total, segments }
})

const transactionItems = computed(() => {
  const incomeRows = payments.value
    .filter(p => inRange(p.paid_at))
    .map(p => ({
      id: `tx-pay-${p.id}`,
      date: p.paid_at,
      type: 'income',
      description: `Payment from ${p.patient_name || 'Patient'}`,
      source: p.bill_number || 'Patient payment',
      method: p.method || 'other',
      reference: p.reference || p.bill_number || '—',
      amount: Number(p.amount || 0),
    }))

  const expenseRows = payableEntries.value
    .filter(e => inRange(e.expense_date) && !['rejected', 'cancelled'].includes(e.status))
    .map(e => ({
      id: `tx-exp-${e.id}`,
      date: e.paid_at || e.expense_date,
      type: 'expense',
      description: e.title,
      source: e.vendor || e.category_name || 'Expense',
      method: e.payment_method || 'other',
      reference: e.reference || '—',
      amount: expenseAmount(e),
    }))

  return [...incomeRows, ...expenseRows]
    .sort((a, b) => new Date(b.date) - new Date(a.date))
})

const filteredTransactions = computed(() => {
  const q = txSearch.value.toLowerCase().trim()
  return transactionItems.value.filter(item => {
    if (txType.value !== 'all' && item.type !== txType.value) return false
    if (txMethod.value !== 'all' && (item.method || 'other') !== txMethod.value) return false
    if (!q) return true
    return [item.description, item.reference, item.source]
      .some(v => String(v || '').toLowerCase().includes(q))
  })
})

// ── Filters
const filteredBills = computed(() => {
  const q = billSearch.value.toLowerCase().trim()
  if (!q) return bills.value
  return bills.value.filter(b =>
    (b.bill_number || '').toLowerCase().includes(q) ||
    (b.patient_name || '').toLowerCase().includes(q))
})

// ── Status / method helpers
const billStatusColor = (s) => ({
  draft: 'grey', issued: 'warning', partial: 'orange', paid: 'success', void: 'grey-darken-1'
})[s] || 'grey'
const billStatusLabel = (s) => ({
  draft: 'Draft', issued: 'Issued', partial: 'Partial', paid: 'Paid', void: 'Void'
})[s] || s
function paymentColor(k) {
  return ({ cash: 'green', mpesa: 'teal', card: 'indigo', bank: 'blue', bank_transfer: 'blue', insurance: 'purple', other: 'grey' })[k] || 'grey'
}
function paymentIcon(k) {
  return ({
    cash: 'mdi-cash', mpesa: 'mdi-cellphone', card: 'mdi-credit-card',
    bank: 'mdi-bank-transfer', bank_transfer: 'mdi-bank-transfer', insurance: 'mdi-shield-account', other: 'mdi-cash-multiple'
  })[k] || 'mdi-cash-multiple'
}
function expenseStatusColor(s) {
  return ({ pending: 'warning', approved: 'info', paid: 'success', rejected: 'error', cancelled: 'grey' })[s] || 'grey'
}

// ── Table headers
const billHeaders = [
  { title: 'Bill #', key: 'bill_number' },
  { title: 'Patient', key: 'patient_name' },
  { title: 'Total', key: 'total', align: 'end' },
  { title: 'Paid', key: 'amount_paid', align: 'end' },
  { title: 'Balance', key: 'balance', align: 'end' },
  { title: 'Date', key: 'created_at' },
  { title: 'Status', key: 'status' },
]
const expHeaders = [
  { title: 'Date', key: 'expense_date' },
  { title: 'Title', key: 'title' },
  { title: 'Vendor', key: 'vendor' },
  { title: 'Category', key: 'category_name' },
  { title: 'Method', key: 'payment_method' },
  { title: 'Status', key: 'status' },
  { title: 'Amount', key: 'amount', align: 'end' },
]
const transactionHeaders = [
  { title: 'Date', key: 'date' },
  { title: 'Type', key: 'type' },
  { title: 'Description', key: 'description' },
  { title: 'Method', key: 'method' },
  { title: 'Reference', key: 'reference' },
  { title: 'Amount', key: 'amount', align: 'end' },
]
const expenseStatusItems = [
  { title: 'All statuses', value: 'all' },
  { title: 'Pending', value: 'pending' },
  { title: 'Approved', value: 'approved' },
  { title: 'Paid', value: 'paid' },
  { title: 'Rejected', value: 'rejected' },
  { title: 'Cancelled', value: 'cancelled' },
]
const expenseSortItems = [
  { title: 'Newest first', value: 'date_desc' },
  { title: 'Oldest first', value: 'date_asc' },
  { title: 'Highest amount', value: 'amount_desc' },
  { title: 'Lowest amount', value: 'amount_asc' },
]
const transactionTypeItems = [
  { title: 'All types', value: 'all' },
  { title: 'Income', value: 'income' },
  { title: 'Expense', value: 'expense' },
]
const transactionMethodItems = [
  { title: 'All methods', value: 'all' },
  { title: 'Cash', value: 'cash' },
  { title: 'Mpesa', value: 'mpesa' },
  { title: 'Card', value: 'card' },
  { title: 'Bank', value: 'bank' },
  { title: 'Bank transfer', value: 'bank_transfer' },
  { title: 'Insurance', value: 'insurance' },
  { title: 'Other', value: 'other' },
]
const glAccountOptions = Object.values(ACC).map(account => ({ title: account.name, value: account.name }))
const glTypeOptions = [
  { title: 'Bill', value: 'BILL' },
  { title: 'Payment', value: 'PAY' },
  { title: 'Expense', value: 'EXP' },
  { title: 'API Charge', value: 'API' },
]
const glHeaders = [
  { title: 'Date', key: 'date', width: 110 },
  { title: 'Reference', key: 'reference', width: 160 },
  { title: 'Description', key: 'description' },
  { title: 'Account', key: 'account', width: 220 },
  { title: 'Debit', key: 'debit', align: 'end', width: 130 },
  { title: 'Credit', key: 'credit', align: 'end', width: 130 },
]
const trialBalanceHeaders = [
  { title: 'Account', key: 'account' },
  { title: 'Debit', key: 'debit', align: 'end' },
  { title: 'Credit', key: 'credit', align: 'end' },
  { title: 'Net', key: 'net', align: 'end' },
]

// ── Export
function exportCsv(kind) {
  let rows = [], name = kind
  if (kind === 'payments') {
    rows = payments.value.map(p => ({
      date: p.paid_at, patient: p.patient_name, bill: p.bill_number,
      method: p.method_label || p.method, reference: p.reference, amount: p.amount
    }))
    name = 'homecare-payments'
  } else if (kind === 'bills') {
    rows = bills.value.map(b => ({
      bill: b.bill_number, patient: b.patient_name, total: b.total,
      paid: b.amount_paid, balance: b.balance, status: b.status_label || b.status, date: b.created_at
    }))
    name = 'homecare-receivables'
  } else if (kind === 'expenses') {
    rows = payableEntries.value.map(e => ({
      date: e.expense_date, reference: e.reference, title: e.title,
      vendor: e.vendor, category: e.category_name, amount: expenseAmount(e), method: e.payment_method, status: e.status
    }))
    name = 'homecare-expenses'
  } else if (kind === 'transactions') {
    rows = filteredTransactions.value.map(t => ({
      date: t.date, type: t.type, description: t.description,
      source: t.source, method: t.method, reference: t.reference, amount: t.amount
    }))
    name = 'homecare-transactions'
  } else if (kind === 'ledger') {
    rows = glFiltered.value.map(e => ({
      date: e.date, source: e.source, reference: e.reference,
      description: e.description, party: e.party, account: e.account, debit: e.debit, credit: e.credit
    }))
    name = 'homecare-ledger'
  } else if (kind === 'balance') {
    rows = [
      { section: 'ASSETS', label: 'Cash / Bank', value: revenueInRange.value },
      { section: 'ASSETS', label: 'Accounts Receivable', value: outstanding.value },
      { section: 'ASSETS', label: 'Total Assets', value: revenueInRange.value + outstanding.value },
      { section: 'LIABILITIES', label: 'Accounts Payable', value: payablesTotal.value },
      { section: 'LIABILITIES', label: 'API Usage Payable', value: apiOutstandingTotal.value },
      { section: 'LIABILITIES', label: 'Total Liabilities', value: payablesTotal.value },
      { section: 'EQUITY', label: 'Retained Earnings', value: netSurplus.value },
      { section: 'EQUITY', label: 'Total Equity', value: netSurplus.value }
    ]
    name = 'homecare-balance-sheet'
  }
  if (!rows.length) { notify('Nothing to export', 'warning'); return }
  const cols = Object.keys(rows[0])
  const csv = [cols.join(','), ...rows.map(r => cols.map(c => `"${String(r[c] ?? '').replace(/"/g, '""')}"`).join(','))].join('\n')
  const blob = new Blob([csv], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = `${name}-${new Date().toISOString().slice(0, 10)}.csv`
  a.click(); URL.revokeObjectURL(url)
  notify('Export ready', 'success')
}
</script>

<style scoped>
.hc-bg { background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%); min-height: calc(100vh - 64px); }
.hc-card { background: white; border: 1px solid rgba(15,23,42,0.06); }
.section-pills { background: white; border: 1px solid rgba(15,23,42,0.06); }
.border-t td { border-top: 1px solid rgba(15,23,42,0.08); }
.pnl-table tbody tr:hover { background: rgba(13,148,136,0.03); }
.pnl-net td { padding-top: 14px !important; padding-bottom: 14px !important; }
.tb-bars { display: flex; flex-direction: column; gap: 10px; }
.tb-bar-row {
  display: grid;
  grid-template-columns: 200px 1fr 130px;
  align-items: center;
  gap: 12px;
}
.tb-bar-track {
  display: flex;
  height: 24px;
  border-radius: 8px;
  overflow: hidden;
  background: #f1f5f9;
  box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.04);
}
.tb-bar {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  padding: 0 8px;
  font-size: 0.7rem;
  color: white;
  font-weight: 600;
  transition: width 0.4s cubic-bezier(.4, 0, .2, 1);
  white-space: nowrap;
  position: relative;
}
.tb-bar-dr { background: linear-gradient(90deg, #34d399, #059669); }
.tb-bar-cr { background: linear-gradient(90deg, #f87171, #dc2626); margin-left: 2px; }
.tb-bar-text { text-shadow: 0 1px 2px rgba(0, 0, 0, 0.25); }
.tb-bar-net { text-align: right; }
.tb-bar-label { display: flex; align-items: center; min-width: 0; }
.tb-donut { display: block; }
.tb-donut circle:first-of-type { stroke: #e2e8f0; }
.tb-donut-num {
  font-size: 9px;
  font-weight: 700;
  fill: #0f172a;
  font-family: ui-monospace, Menlo, monospace;
}
.tb-donut-lbl { font-size: 6px; fill: #64748b; }
.tb-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  display: inline-block;
  box-shadow: 0 0 0 2px rgba(255, 255, 255, 0.6);
}
.tb-net-chart { display: flex; flex-direction: column; gap: 8px; }
.tb-net-row {
  display: grid;
  grid-template-columns: 220px 1fr;
  align-items: center;
  gap: 12px;
}
.tb-net-label { display: flex; align-items: center; }
.tb-net-track {
  position: relative;
  height: 26px;
  background: #f1f5f9;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.04);
}
.tb-net-axis {
  position: absolute;
  top: 4px;
  bottom: 4px;
  left: 50%;
  width: 2px;
  background: #cbd5e1;
  border-radius: 2px;
}
.tb-net-bar {
  position: absolute;
  top: 4px;
  bottom: 4px;
  display: flex;
  align-items: center;
  padding: 0 6px;
  font-size: 0.7rem;
  color: white;
  font-weight: 600;
  border-radius: 4px;
  transition: width 0.4s cubic-bezier(.4, 0, .2, 1);
}
.tb-net-dr {
  background: linear-gradient(90deg, #10b981, #059669);
  justify-content: flex-end;
}
.tb-net-cr {
  background: linear-gradient(90deg, #dc2626, #ef4444);
  justify-content: flex-start;
}
.tb-net-value { text-shadow: 0 1px 2px rgba(0, 0, 0, 0.25); }
:global(.v-theme--dark .hc-bg) { background: linear-gradient(180deg, #0b1220 0%, #0f172a 100%); }
:global(.v-theme--dark .hc-card) { background: #1e293b; border-color: rgba(255,255,255,0.08); }
:global(.v-theme--dark .section-pills) { background: #1e293b; border-color: rgba(255,255,255,0.08); }
:global(.v-theme--dark .tb-bar-track) { background: rgba(255,255,255,0.06); }
:global(.v-theme--dark .tb-net-track) { background: rgba(255,255,255,0.06); }
:global(.v-theme--dark .tb-net-axis) { background: rgba(255,255,255,0.18); }
:global(.v-theme--dark .tb-donut circle:first-of-type) { stroke: rgba(255,255,255,0.08); }
:global(.v-theme--dark .tb-donut-num) { fill: #e2e8f0; }
:global(.v-theme--dark .tb-donut-lbl) { fill: #94a3b8; }
:global(.v-theme--dark .tb-dot) { box-shadow: 0 0 0 2px rgba(255,255,255,0.04); }

@media (max-width: 600px) {
  .tb-bar-row, .tb-net-row { grid-template-columns: 1fr; }
  .tb-bar-net { text-align: left; }
}
</style>
