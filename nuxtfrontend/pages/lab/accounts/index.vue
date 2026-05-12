<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="teal-lighten-5" size="48">
        <v-icon color="teal-darken-2" size="28">mdi-bank</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Lab accounts</div>
        <div class="text-body-2 text-medium-emphasis">
          Revenue, receivables, expenses, COGS &amp; full P&amp;L for the laboratory
        </div>
      </div>
      <v-spacer />
      <v-select
        v-model="rangeKey"
        :items="rangeOptions" item-title="label" item-value="key"
        density="compact" variant="outlined" hide-details rounded="lg"
        prepend-inner-icon="mdi-calendar-range"
        style="min-width:200px;max-width:220px"
        @update:model-value="onRangeChange"
      />
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh"
             :loading="loading" @click="loadAll">Refresh</v-btn>
      <v-menu>
        <template #activator="{ props }">
          <v-btn v-bind="props" variant="outlined" rounded="lg"
                 prepend-icon="mdi-tray-arrow-down">Export</v-btn>
        </template>
        <v-list density="compact">
          <v-list-item @click="exportCsv('pnl')">
            <template #prepend><v-icon>mdi-chart-box-outline</v-icon></template>
            <v-list-item-title>P&amp;L (CSV)</v-list-item-title>
          </v-list-item>
          <v-list-item @click="exportCsv('ledger')">
            <template #prepend><v-icon>mdi-format-list-bulleted</v-icon></template>
            <v-list-item-title>Transactions (CSV)</v-list-item-title>
          </v-list-item>
          <v-list-item @click="exportCsv('receivables')">
            <template #prepend><v-icon>mdi-receipt-text-outline</v-icon></template>
            <v-list-item-title>Receivables (CSV)</v-list-item-title>
          </v-list-item>
          <v-list-item @click="exportCsv('aging')">
            <template #prepend><v-icon>mdi-calendar-clock</v-icon></template>
            <v-list-item-title>Aging (CSV)</v-list-item-title>
          </v-list-item>
          <v-list-item @click="exportCsv('balance')">
            <template #prepend><v-icon>mdi-scale-balance</v-icon></template>
            <v-list-item-title>Balance Sheet (CSV)</v-list-item-title>
          </v-list-item>
          <v-list-item @click="exportCsv('gl')">
            <template #prepend><v-icon>mdi-book-open-variant</v-icon></template>
            <v-list-item-title>General Ledger (CSV)</v-list-item-title>
          </v-list-item>
        </v-list>
      </v-menu>
    </div>

    <!-- KPIs -->
    <v-row dense class="mb-1">
      <v-col v-for="k in kpiTiles" :key="k.label" cols="6" md="3">
        <v-card flat rounded="lg" class="kpi pa-3">
          <div class="d-flex align-center">
            <v-avatar :color="k.color + '-lighten-5'" size="40" class="mr-3">
              <v-icon :color="k.color + '-darken-2'" size="22">{{ k.icon }}</v-icon>
            </v-avatar>
            <div class="min-width-0">
              <div class="text-overline text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h6 font-weight-bold">{{ k.value }}</div>
              <div class="text-caption text-medium-emphasis">{{ k.sub }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Section pills (replaces tabs) -->
    <v-card flat rounded="lg" class="section-pills pa-2 mt-3 mb-3">
      <v-chip-group v-model="tab" mandatory selected-class="text-primary">
        <v-chip v-for="s in sectionPills" :key="s.value" :value="s.value"
                size="small" filter variant="tonal" :color="s.color">
          <v-icon size="14" start>{{ s.icon }}</v-icon>{{ s.label }}
        </v-chip>
      </v-chip-group>
    </v-card>

    <!-- ============== OVERVIEW ============== -->
    <template v-if="tab === 'overview'">
      <v-row dense class="mb-3">
        <v-col cols="12" md="8">
          <v-card flat class="pa-4 section-card" rounded="lg">
            <div class="d-flex align-center mb-2">
              <v-icon color="teal-darken-2" class="mr-2">mdi-chart-areaspline</v-icon>
              <div class="text-subtitle-1 font-weight-medium">Cash flow trend</div>
              <v-spacer />
              <div class="d-flex align-center" style="gap:8px">
                <v-chip size="x-small" color="success" variant="tonal">
                  <v-icon start size="14">mdi-arrow-up-bold</v-icon>Income
                </v-chip>
                <v-chip size="x-small" color="error" variant="tonal">
                  <v-icon start size="14">mdi-arrow-down-bold</v-icon>Expenses
                </v-chip>
              </div>
            </div>
            <div v-if="!cashflowSeries.length" class="text-center text-medium-emphasis py-8">
              No transactions in this range.
            </div>
            <div v-else>
              <SparkArea :values="cashflowSeries.map(p => p.income)" :height="180" color="#0d9488" />
              <div style="height:8px"></div>
              <SparkArea :values="cashflowSeries.map(p => p.expense)" :height="120" color="#ef4444" />
              <div class="d-flex justify-space-between text-caption text-medium-emphasis mt-2">
                <span>{{ cashflowSeries[0]?.date }}</span>
                <span>{{ cashflowSeries[cashflowSeries.length - 1]?.date }}</span>
              </div>
            </div>
          </v-card>
        </v-col>
        <v-col cols="12" md="4">
          <v-card flat class="pa-4 h-100 section-card" rounded="lg">
            <div class="d-flex align-center mb-3">
              <v-icon color="indigo" class="mr-2">mdi-cash-multiple</v-icon>
              <div class="text-subtitle-1 font-weight-medium">Cash by payment method</div>
            </div>
            <div v-if="!cashByMethod.length" class="text-center text-medium-emphasis py-6">No payments yet</div>
            <div v-else>
              <div v-for="m in cashByMethod" :key="m.key" class="mb-3">
                <div class="d-flex align-center mb-1">
                  <v-icon :color="paymentColor(m.key)" size="18" class="mr-2">{{ paymentIcon(m.key) }}</v-icon>
                  <span class="text-body-2 font-weight-medium text-capitalize">{{ m.label }}</span>
                  <v-spacer />
                  <span class="text-body-2 font-weight-bold">{{ fmtMoney(m.total) }}</span>
                </div>
                <v-progress-linear :model-value="m.pct" :color="paymentColor(m.key)" height="8" rounded />
                <div class="text-caption text-medium-emphasis mt-1">{{ m.pct }}% of total</div>
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>

      <v-row dense class="mb-3">
        <v-col cols="12" md="6">
          <v-card flat class="pa-4 h-100 section-card" rounded="lg">
            <div class="d-flex align-center mb-3">
              <v-icon color="error" class="mr-2">mdi-receipt-text-outline</v-icon>
              <div class="text-subtitle-1 font-weight-medium">Top outstanding invoices</div>
              <v-spacer />
              <v-btn size="small" variant="text" color="primary" @click="tab = 'receivables'">View all</v-btn>
            </div>
            <div v-if="!topReceivables.length" class="text-center text-medium-emphasis py-4">
              No outstanding lab invoices.
            </div>
            <v-list v-else density="compact" class="pa-0">
              <v-list-item v-for="inv in topReceivables" :key="inv.id" class="px-0">
                <template #prepend>
                  <v-avatar size="32" :color="inv._isOverdue ? 'error' : 'warning'" variant="tonal">
                    <v-icon size="16">{{ inv._isOverdue ? 'mdi-alert' : 'mdi-clock-outline' }}</v-icon>
                  </v-avatar>
                </template>
                <v-list-item-title class="text-body-2 font-weight-medium">
                  {{ inv.invoice_number }}
                  <span class="text-caption text-medium-emphasis"> · {{ patientLabel(inv) }}</span>
                </v-list-item-title>
                <v-list-item-subtitle class="text-caption">
                  Issued {{ fmtDate(inv.created_at) }}
                  <span v-if="inv._isOverdue" class="text-error font-weight-bold">
                    · {{ inv._daysLate }}d overdue
                  </span>
                </v-list-item-subtitle>
                <template #append>
                  <span class="font-weight-bold">{{ fmtMoney(invoiceBalance(inv)) }}</span>
                </template>
              </v-list-item>
            </v-list>
          </v-card>
        </v-col>
        <v-col cols="12" md="6">
          <v-card flat class="pa-4 h-100 section-card" rounded="lg">
            <div class="d-flex align-center mb-3">
              <v-icon color="warning" class="mr-2">mdi-cash-clock</v-icon>
              <div class="text-subtitle-1 font-weight-medium">Pending payables</div>
              <v-spacer />
              <v-btn size="small" variant="text" color="primary" @click="tab = 'payables'">View all</v-btn>
            </div>
            <div v-if="!topPayables.length" class="text-center text-medium-emphasis py-4">
              Nothing pending payment.
            </div>
            <v-list v-else density="compact" class="pa-0">
              <v-list-item v-for="ex in topPayables" :key="ex.id" class="px-0">
                <template #prepend>
                  <v-avatar size="32" :color="ex.status === 'pending' ? 'amber' : 'orange'" variant="tonal">
                    <v-icon size="16">{{ ex.status === 'pending' ? 'mdi-timer-sand' : 'mdi-check' }}</v-icon>
                  </v-avatar>
                </template>
                <v-list-item-title class="text-body-2 font-weight-medium text-truncate">
                  {{ ex.title }}
                </v-list-item-title>
                <v-list-item-subtitle class="text-caption">
                  {{ ex.category_name || ex.category || '—' }}
                  · {{ fmtDate(ex.expense_date || ex.created_at) }}
                </v-list-item-subtitle>
                <template #append>
                  <span class="font-weight-bold">{{ fmtMoney(ex.amount) }}</span>
                </template>
              </v-list-item>
            </v-list>
          </v-card>
        </v-col>
      </v-row>

      <!-- Aging summary -->
      <v-card flat class="pa-4 mb-3 section-card" rounded="lg">
        <div class="d-flex align-center mb-3">
          <v-icon color="deep-orange" class="mr-2">mdi-timer-sand-complete</v-icon>
          <div class="text-subtitle-1 font-weight-medium">Receivables aging snapshot</div>
        </div>
        <v-row dense>
          <v-col v-for="b in agingBuckets" :key="b.label" cols="6" md="2">
            <v-card variant="tonal" :color="b.color" rounded="lg" class="pa-3 text-center">
              <div class="text-caption text-uppercase">{{ b.label }}</div>
              <div class="text-h6 font-weight-bold">{{ fmtMoney(b.total) }}</div>
              <div class="text-caption">{{ b.count }} invoice(s)</div>
            </v-card>
          </v-col>
        </v-row>
      </v-card>
    </template>

    <!-- ============== RECEIVABLES ============== -->
    <template v-if="tab === 'receivables'">
      <v-card flat class="pa-3 mb-3 section-card" rounded="lg">
        <div class="d-flex flex-wrap align-center" style="gap:8px">
          <v-text-field
            v-model="receivableSearch"
            density="compact" hide-details variant="outlined" rounded="lg"
            prepend-inner-icon="mdi-magnify"
            placeholder="Search invoice / patient" persistent-placeholder
            style="max-width:280px"
          />
          <v-select
            v-model="receivableStatus"
            :items="invoiceStatusOptions" item-title="label" item-value="value"
            density="compact" hide-details variant="outlined" rounded="lg" clearable
            placeholder="Status" persistent-placeholder style="max-width:180px"
          />
          <v-select
            v-model="receivablePayer"
            :items="payerOptions" item-title="label" item-value="value"
            density="compact" hide-details variant="outlined" rounded="lg" clearable
            placeholder="Payer" persistent-placeholder style="max-width:180px"
          />
          <v-spacer />
          <v-chip color="primary" variant="tonal">
            Total: <strong class="ml-1">{{ fmtMoney(filteredReceivables.reduce((s,i)=>s+invoiceBalance(i),0)) }}</strong>
          </v-chip>
        </div>
      </v-card>

      <v-card flat rounded="lg" class="section-card">
        <v-data-table
          class="acct-table"
          :headers="receivableHeaders"
          :items="filteredReceivables"
          :loading="loading"
          density="comfortable"
          items-per-page="25"
        >
          <template #[`item.invoice_number`]="{ item }">
            <div class="font-weight-bold">{{ item.invoice_number }}</div>
            <div class="text-caption text-medium-emphasis">{{ fmtDate(item.created_at) }}</div>
          </template>
          <template #[`item.patient`]="{ item }">{{ patientLabel(item) }}</template>
          <template #[`item.payer_type`]="{ item }">
            <v-chip size="x-small" :color="payerColor(item.payer_type)" variant="tonal" class="text-capitalize">
              {{ payerLabel(item.payer_type) }}
            </v-chip>
          </template>
          <template #[`item.total`]="{ item }">{{ fmtMoney(item.total) }}</template>
          <template #[`item.amount_paid`]="{ item }">{{ fmtMoney(item.amount_paid) }}</template>
          <template #[`item.balance`]="{ item }">
            <strong :class="invoiceBalance(item) > 0 ? 'text-error' : 'text-success'">
              {{ fmtMoney(invoiceBalance(item)) }}
            </strong>
          </template>
          <template #[`item.status`]="{ item }">
            <v-chip size="x-small" :color="invoiceStatusColor(item.status)" variant="flat" class="text-capitalize">
              {{ (item.status || '').replace('_',' ') }}
            </v-chip>
          </template>
          <template #[`item.actions`]="{ item }">
            <v-menu>
              <template #activator="{ props }">
                <v-btn icon="mdi-dots-vertical" size="small" variant="text" v-bind="props" />
              </template>
              <v-list density="compact">
                <v-list-item :disabled="invoiceBalance(item) <= 0" @click="openPay(item)">
                  <template #prepend><v-icon>mdi-cash-plus</v-icon></template>
                  <v-list-item-title>Record payment</v-list-item-title>
                </v-list-item>
                <v-list-item @click="viewInvoice(item)">
                  <template #prepend><v-icon>mdi-eye</v-icon></template>
                  <v-list-item-title>View details</v-list-item-title>
                </v-list-item>
              </v-list>
            </v-menu>
          </template>
        </v-data-table>
      </v-card>
    </template>

    <!-- ============== PAYABLES ============== -->
    <template v-if="tab === 'payables'">
      <v-card flat class="pa-3 mb-3 section-card" rounded="lg">
        <div class="d-flex flex-wrap align-center" style="gap:8px">
          <v-text-field
            v-model="payableSearch"
            density="compact" hide-details variant="outlined" rounded="lg"
            prepend-inner-icon="mdi-magnify"
            placeholder="Search expense" persistent-placeholder
            style="max-width:280px"
          />
          <v-select
            v-model="payableStatus"
            :items="expenseStatusOptions" item-title="label" item-value="value"
            density="compact" hide-details variant="outlined" rounded="lg" clearable
            placeholder="Status" persistent-placeholder style="max-width:180px"
          />
          <v-spacer />
          <v-chip color="warning" variant="tonal">
            Total: <strong class="ml-1">{{ fmtMoney(filteredPayables.reduce((s,e)=>s+Number(e.amount||0),0)) }}</strong>
          </v-chip>
        </div>
      </v-card>

      <v-card flat rounded="lg" class="section-card">
        <v-data-table
          class="acct-table"
          :headers="payableHeaders"
          :items="filteredPayables"
          :loading="loading"
          density="comfortable"
          items-per-page="25"
        >
          <template #[`item.title`]="{ item }">
            <div class="font-weight-medium">{{ item.title }}</div>
            <div class="text-caption text-medium-emphasis">{{ item.vendor || '—' }}</div>
          </template>
          <template #[`item.category`]="{ item }">{{ item.category_name || item.category || '—' }}</template>
          <template #[`item.amount`]="{ item }">{{ fmtMoney(item.amount) }}</template>
          <template #[`item.expense_date`]="{ item }">{{ fmtDate(item.expense_date) }}</template>
          <template #[`item.status`]="{ item }">
            <v-chip size="x-small" :color="expenseStatusColor(item.status)" variant="flat" class="text-capitalize">
              {{ (item.status || '').replace('_',' ') }}
            </v-chip>
          </template>
          <template #[`item.actions`]="{ item }">
            <v-menu>
              <template #activator="{ props }">
                <v-btn icon="mdi-dots-vertical" size="small" variant="text" v-bind="props" />
              </template>
              <v-list density="compact">
                <v-list-item v-if="item.status === 'pending'" @click="approveExpense(item)">
                  <template #prepend><v-icon color="success">mdi-check</v-icon></template>
                  <v-list-item-title>Approve</v-list-item-title>
                </v-list-item>
                <v-list-item v-if="item.status === 'pending'" @click="rejectExpense(item)">
                  <template #prepend><v-icon color="error">mdi-close</v-icon></template>
                  <v-list-item-title>Reject</v-list-item-title>
                </v-list-item>
                <v-list-item v-if="item.status === 'approved'" @click="markExpensePaid(item)">
                  <template #prepend><v-icon color="primary">mdi-cash-check</v-icon></template>
                  <v-list-item-title>Mark paid</v-list-item-title>
                </v-list-item>
              </v-list>
            </v-menu>
          </template>
        </v-data-table>
      </v-card>
    </template>

    <!-- ============== TRANSACTIONS ============== -->
    <template v-if="tab === 'transactions'">
      <v-card flat class="pa-3 mb-3 section-card" rounded="lg">
        <div class="d-flex flex-wrap align-center" style="gap:8px">
          <v-text-field
            v-model="ledgerSearch"
            density="compact" hide-details variant="outlined" rounded="lg"
            prepend-inner-icon="mdi-magnify"
            placeholder="Search transactions" persistent-placeholder
            style="max-width:280px"
          />
          <v-select
            v-model="ledgerType"
            :items="ledgerTypes" item-title="label" item-value="value"
            density="compact" hide-details variant="outlined" rounded="lg" clearable
            placeholder="Type" persistent-placeholder style="max-width:200px"
          />
          <v-spacer />
          <v-chip color="success" variant="tonal" class="mr-2">
            Income <strong class="ml-1">{{ fmtMoney(ledgerTotals.income) }}</strong>
          </v-chip>
          <v-chip color="error" variant="tonal">
            Expense <strong class="ml-1">{{ fmtMoney(ledgerTotals.expense) }}</strong>
          </v-chip>
        </div>
      </v-card>

      <v-card flat rounded="lg" class="section-card">
        <v-data-table
          class="acct-table"
          :headers="ledgerHeaders"
          :items="filteredLedger"
          :loading="loading"
          density="comfortable"
          items-per-page="25"
        >
          <template #[`item.date`]="{ item }">{{ fmtDate(item.date) }}</template>
          <template #[`item.type`]="{ item }">
            <v-chip size="x-small" :color="ledgerTypeColor(item.type)" variant="tonal">
              {{ item.type }}
            </v-chip>
          </template>
          <template #[`item.reference`]="{ item }">
            <div class="font-weight-medium">{{ item.reference }}</div>
            <div class="text-caption text-medium-emphasis">{{ item.party || '' }}</div>
          </template>
          <template #[`item.method`]="{ item }">
            <span v-if="item.method" class="text-capitalize">
              <v-icon size="14" :color="paymentColor(item.method)" class="mr-1">{{ paymentIcon(item.method) }}</v-icon>
              {{ item.method }}
            </span>
            <span v-else>—</span>
          </template>
          <template #[`item.income`]="{ item }">
            <span v-if="item.direction === 'in'" class="text-success font-weight-medium">
              +{{ fmtMoney(item.amount) }}
            </span>
            <span v-else>—</span>
          </template>
          <template #[`item.expense`]="{ item }">
            <span v-if="item.direction === 'out'" class="text-error font-weight-medium">
              −{{ fmtMoney(item.amount) }}
            </span>
            <span v-else>—</span>
          </template>
        </v-data-table>
      </v-card>
    </template>

    <!-- ============== AGING ============== -->
    <template v-if="tab === 'aging'">
      <v-card flat class="pa-4 mb-3 section-card" rounded="lg">
        <div class="d-flex align-center mb-3">
          <v-icon color="deep-orange" class="mr-2">mdi-timer-sand-complete</v-icon>
          <div class="text-subtitle-1 font-weight-medium">Receivables aging</div>
        </div>
        <v-row dense>
          <v-col v-for="b in agingBuckets" :key="b.label" cols="6" md="2">
            <v-card variant="tonal" :color="b.color" rounded="lg" class="pa-3 text-center">
              <div class="text-caption text-uppercase">{{ b.label }}</div>
              <div class="text-h6 font-weight-bold">{{ fmtMoney(b.total) }}</div>
              <div class="text-caption">{{ b.count }} invoice(s)</div>
            </v-card>
          </v-col>
        </v-row>
      </v-card>

      <v-card flat rounded="lg" class="section-card">
        <v-data-table
          class="acct-table"
          :headers="agingHeaders"
          :items="agedInvoices"
          :loading="loading"
          density="comfortable"
          items-per-page="25"
        >
          <template #[`item.invoice_number`]="{ item }">
            <div class="font-weight-bold">{{ item.invoice_number }}</div>
            <div class="text-caption text-medium-emphasis">{{ fmtDate(item.created_at) }}</div>
          </template>
          <template #[`item.patient`]="{ item }">{{ patientLabel(item) }}</template>
          <template #[`item.balance`]="{ item }">
            <strong class="text-error">{{ fmtMoney(invoiceBalance(item)) }}</strong>
          </template>
          <template #[`item.bucket`]="{ item }">
            <v-chip size="x-small" :color="agingColorForDays(item._daysLate)" variant="tonal">
              {{ agingLabelForDays(item._daysLate) }}
            </v-chip>
          </template>
          <template #[`item.days`]="{ item }">{{ item._daysLate }}d</template>
        </v-data-table>
      </v-card>
    </template>

    <!-- ============== P&L ============== -->
    <template v-if="tab === 'pnl'">
      <v-row dense>
        <v-col cols="12" md="7">
          <v-card flat class="pa-4 section-card" rounded="lg">
            <div class="d-flex align-center mb-3">
              <v-icon color="teal" class="mr-2">mdi-chart-box</v-icon>
              <div class="text-subtitle-1 font-weight-medium">Profit &amp; Loss · {{ data.range.label }}</div>
            </div>
            <v-table density="comfortable" class="pnl-table">
              <tbody>
                <tr class="pnl-section">
                  <td colspan="2">REVENUE</td>
                </tr>
                <tr>
                  <td>Lab services revenue (paid)</td>
                  <td class="text-right">{{ fmtMoney(pnl.revenue) }}</td>
                </tr>
                <tr class="pnl-subtotal">
                  <td>Total Revenue</td>
                  <td class="text-right">{{ fmtMoney(pnl.revenue) }}</td>
                </tr>

                <tr class="pnl-section">
                  <td colspan="2">COST OF GOODS SOLD</td>
                </tr>
                <tr>
                  <td>Reagent consumption (estimate)</td>
                  <td class="text-right">{{ fmtMoney(pnl.cogs) }}</td>
                </tr>
                <tr class="pnl-subtotal">
                  <td>Gross Profit</td>
                  <td class="text-right" :class="pnl.grossProfit >= 0 ? 'text-success' : 'text-error'">
                    <strong>{{ fmtMoney(pnl.grossProfit) }}</strong>
                  </td>
                </tr>

                <tr class="pnl-section">
                  <td colspan="2">OPERATING EXPENSES</td>
                </tr>
                <tr v-for="row in pnl.expenseRows" :key="row.category">
                  <td>{{ row.category }}</td>
                  <td class="text-right">{{ fmtMoney(row.total) }}</td>
                </tr>
                <tr v-if="!pnl.expenseRows.length">
                  <td class="text-medium-emphasis">No expenses recorded</td>
                  <td class="text-right">—</td>
                </tr>
                <tr>
                  <td>API usage cost</td>
                  <td class="text-right">{{ fmtMoney(pnl.apiCost) }}</td>
                </tr>
                <tr class="pnl-subtotal">
                  <td>Total Operating Expenses</td>
                  <td class="text-right">{{ fmtMoney(pnl.opex + pnl.apiCost) }}</td>
                </tr>

                <tr class="pnl-total">
                  <td>NET PROFIT</td>
                  <td class="text-right">
                    <strong :class="pnl.netProfit >= 0 ? 'text-success' : 'text-error'">
                      {{ fmtMoney(pnl.netProfit) }}
                    </strong>
                  </td>
                </tr>
                <tr>
                  <td class="text-caption text-medium-emphasis">Net margin</td>
                  <td class="text-right text-caption">
                    {{ pnl.revenue > 0 ? ((pnl.netProfit / pnl.revenue) * 100).toFixed(1) + '%' : '—' }}
                  </td>
                </tr>
              </tbody>
            </v-table>
          </v-card>
        </v-col>
        <v-col cols="12" md="5">
          <v-card flat class="pa-4 h-100 section-card" rounded="lg">
            <div class="d-flex align-center mb-3">
              <v-icon color="purple" class="mr-2">mdi-shape-outline</v-icon>
              <div class="text-subtitle-1 font-weight-medium">Expense by category</div>
            </div>
            <div v-if="!pnl.expenseRows.length" class="text-medium-emphasis text-center py-6">
              No expense data
            </div>
            <div v-else>
              <div v-for="row in pnl.expenseRows" :key="row.category" class="mb-3">
                <div class="d-flex align-center mb-1">
                  <span class="text-body-2 font-weight-medium">{{ row.category }}</span>
                  <v-spacer />
                  <span class="text-body-2 font-weight-bold">{{ fmtMoney(row.total) }}</span>
                </div>
                <v-progress-linear
                  :model-value="pnl.opex ? Math.round((row.total / pnl.opex) * 100) : 0"
                  color="purple" height="8" rounded
                />
              </div>
            </div>

            <v-divider class="my-4" />
            <div class="d-flex align-center mb-2">
              <v-icon color="indigo" class="mr-2">mdi-chart-pie</v-icon>
              <div class="text-subtitle-2 font-weight-medium">Revenue by payer</div>
            </div>
            <div v-if="!revenueByPayer.length" class="text-medium-emphasis text-center py-4">No revenue</div>
            <div v-else>
              <div v-for="r in revenueByPayer" :key="r.key" class="mb-2">
                <div class="d-flex align-center mb-1">
                  <v-icon size="14" :color="payerColor(r.key)" class="mr-2">mdi-circle</v-icon>
                  <span class="text-body-2">{{ payerLabel(r.key) }}</span>
                  <v-spacer />
                  <span class="text-body-2 font-weight-medium">{{ fmtMoney(r.total) }}</span>
                </div>
                <v-progress-linear :model-value="r.pct" :color="payerColor(r.key)" height="6" rounded />
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>
    </template>

    <!-- ============== TOP PATIENTS ============== -->
    <template v-if="tab === 'patients'">
      <v-card flat rounded="lg" class="section-card">
        <v-data-table
          class="acct-table"
          :headers="topPatientHeaders"
          :items="topPatientsData"
          :loading="loading"
          density="comfortable"
          items-per-page="25"
        >
          <template #[`item.rank`]="{ index }">{{ index + 1 }}</template>
          <template #[`item.revenue`]="{ item }">{{ fmtMoney(item.revenue) }}</template>
          <template #[`item.balance`]="{ item }">
            <strong :class="item.balance > 0 ? 'text-error' : 'text-success'">
              {{ fmtMoney(item.balance) }}
            </strong>
          </template>
        </v-data-table>
      </v-card>
    </template>

    <!-- ============== TOP TESTS ============== -->
    <template v-if="tab === 'tests'">
      <v-card flat rounded="lg" class="section-card">
        <v-data-table
          class="acct-table"
          :headers="topTestHeaders"
          :items="topTestsData"
          :loading="loading"
          density="comfortable"
          items-per-page="25"
        >
          <template #[`item.rank`]="{ index }">{{ index + 1 }}</template>
          <template #[`item.revenue`]="{ item }">{{ fmtMoney(item.revenue) }}</template>
        </v-data-table>
      </v-card>
    </template>

    <!-- ============== BALANCE SHEET ============== -->
    <template v-if="tab === 'balance'">
      <v-row dense>
        <v-col cols="12" md="7">
          <v-card flat class="pa-4 section-card" rounded="lg">
            <div class="d-flex align-center mb-3">
              <v-icon color="teal" class="mr-2">mdi-scale-balance</v-icon>
              <div class="text-subtitle-1 font-weight-medium">
                Balance Sheet · as of {{ fmtDate(data.range.end) }}
              </div>
              <v-spacer />
              <v-chip size="small" :color="balanceSheet.balanced ? 'success' : 'warning'" variant="tonal">
                <v-icon start size="14">{{ balanceSheet.balanced ? 'mdi-check-circle' : 'mdi-alert' }}</v-icon>
                {{ balanceSheet.balanced ? 'Balanced' : 'Out of balance' }}
              </v-chip>
            </div>
            <v-table density="comfortable" class="pnl-table">
              <tbody>
                <tr class="pnl-section"><td colspan="2">ASSETS</td></tr>
                <tr><td>Cash on hand</td><td class="text-right">{{ fmtMoney(balanceSheet.cash) }}</td></tr>
                <tr><td>Bank accounts</td><td class="text-right">{{ fmtMoney(balanceSheet.bank) }}</td></tr>
                <tr><td>M-Pesa / mobile money</td><td class="text-right">{{ fmtMoney(balanceSheet.mpesa) }}</td></tr>
                <tr><td>Card receipts</td><td class="text-right">{{ fmtMoney(balanceSheet.card) }}</td></tr>
                <tr><td>Accounts receivable</td><td class="text-right">{{ fmtMoney(balanceSheet.receivables) }}</td></tr>
                <tr><td>Reagent inventory</td><td class="text-right">{{ fmtMoney(balanceSheet.inventory) }}</td></tr>
                <tr class="pnl-subtotal">
                  <td>Total Assets</td>
                  <td class="text-right"><strong>{{ fmtMoney(balanceSheet.totalAssets) }}</strong></td>
                </tr>

                <tr class="pnl-section"><td colspan="2">LIABILITIES</td></tr>
                <tr><td>Accounts payable (approved)</td><td class="text-right">{{ fmtMoney(balanceSheet.payables) }}</td></tr>
                <tr><td>Accrued expenses (pending)</td><td class="text-right">{{ fmtMoney(balanceSheet.accrued) }}</td></tr>
                <tr><td>API usage payable</td><td class="text-right">{{ fmtMoney(balanceSheet.apiPayable) }}</td></tr>
                <tr><td>Insurance claims payable</td><td class="text-right">{{ fmtMoney(balanceSheet.insurancePayable) }}</td></tr>
                <tr class="pnl-subtotal">
                  <td>Total Liabilities</td>
                  <td class="text-right"><strong>{{ fmtMoney(balanceSheet.totalLiabilities) }}</strong></td>
                </tr>

                <tr class="pnl-section"><td colspan="2">EQUITY</td></tr>
                <tr><td>Retained earnings (period)</td><td class="text-right">{{ fmtMoney(balanceSheet.retained) }}</td></tr>
                <tr class="pnl-subtotal">
                  <td>Total Equity</td>
                  <td class="text-right"><strong>{{ fmtMoney(balanceSheet.totalEquity) }}</strong></td>
                </tr>

                <tr class="pnl-total">
                  <td>TOTAL LIABILITIES &amp; EQUITY</td>
                  <td class="text-right">
                    <strong>{{ fmtMoney(balanceSheet.totalLiabilities + balanceSheet.totalEquity) }}</strong>
                  </td>
                </tr>
              </tbody>
            </v-table>
          </v-card>
        </v-col>
        <v-col cols="12" md="5">
          <v-card flat class="pa-4 mb-3 section-card" rounded="lg">
            <div class="d-flex align-center mb-3">
              <v-icon color="indigo" class="mr-2">mdi-chart-donut</v-icon>
              <div class="text-subtitle-1 font-weight-medium">Asset composition</div>
            </div>
            <div v-if="!assetBreakdown.length" class="text-medium-emphasis text-center py-4">
              No asset data
            </div>
            <div v-else>
              <div v-for="a in assetBreakdown" :key="a.label" class="mb-3">
                <div class="d-flex align-center mb-1">
                  <v-icon size="14" :color="a.color" class="mr-2">mdi-circle</v-icon>
                  <span class="text-body-2">{{ a.label }}</span>
                  <v-spacer />
                  <span class="text-body-2 font-weight-medium">{{ fmtMoney(a.value) }}</span>
                </div>
                <v-progress-linear :model-value="a.pct" :color="a.color" height="8" rounded />
                <div class="text-caption text-medium-emphasis mt-1">{{ a.pct }}%</div>
              </div>
            </div>
          </v-card>
          <v-card flat class="pa-4 section-card" rounded="lg">
            <div class="d-flex align-center mb-3">
              <v-icon color="orange" class="mr-2">mdi-finance</v-icon>
              <div class="text-subtitle-1 font-weight-medium">Key financial ratios</div>
            </div>
            <v-list density="compact" class="pa-0">
              <v-list-item class="px-0">
                <v-list-item-title>Current ratio</v-list-item-title>
                <template #append><strong>{{ ratios.current }}</strong></template>
              </v-list-item>
              <v-list-item class="px-0">
                <v-list-item-title>Quick ratio</v-list-item-title>
                <template #append><strong>{{ ratios.quick }}</strong></template>
              </v-list-item>
              <v-list-item class="px-0">
                <v-list-item-title>Debt-to-equity</v-list-item-title>
                <template #append><strong>{{ ratios.debtEquity }}</strong></template>
              </v-list-item>
              <v-list-item class="px-0">
                <v-list-item-title>Net profit margin</v-list-item-title>
                <template #append><strong>{{ ratios.netMargin }}</strong></template>
              </v-list-item>
              <v-list-item class="px-0">
                <v-list-item-title>Working capital</v-list-item-title>
                <template #append><strong>{{ fmtMoney(ratios.workingCapital) }}</strong></template>
              </v-list-item>
            </v-list>
          </v-card>
        </v-col>
      </v-row>
    </template>

    <!-- ============== GENERAL LEDGER ============== -->
    <template v-if="tab === 'ledger'">
      <v-card flat class="pa-3 mb-3 section-card" rounded="lg">
        <div class="d-flex flex-wrap align-center" style="gap:8px">
          <v-select
            v-model="glAccountFilter"
            :items="glAccounts" item-title="label" item-value="key"
            density="compact" hide-details variant="outlined" rounded="lg" clearable
            placeholder="Account" persistent-placeholder style="min-width:240px"
          />
          <v-text-field
            v-model="glSearch"
            density="compact" hide-details variant="outlined" rounded="lg"
            prepend-inner-icon="mdi-magnify"
            placeholder="Search reference / memo" persistent-placeholder
            style="max-width:280px"
          />
          <v-spacer />
          <v-chip color="primary" variant="tonal" class="mr-2">
            Debits <strong class="ml-1">{{ fmtMoney(glTotals.debit) }}</strong>
          </v-chip>
          <v-chip color="deep-purple" variant="tonal">
            Credits <strong class="ml-1">{{ fmtMoney(glTotals.credit) }}</strong>
          </v-chip>
        </div>
      </v-card>

      <v-row dense class="mb-3">
        <v-col v-for="a in glAccountSummary" :key="a.key" cols="6" md="3">
          <v-card variant="tonal" :color="a.color" rounded="lg" class="pa-3">
            <div class="text-caption text-uppercase">{{ a.label }}</div>
            <div class="text-h6 font-weight-bold">{{ fmtMoney(a.balance) }}</div>
            <div class="text-caption">
              Dr {{ fmtMoney(a.debit) }} · Cr {{ fmtMoney(a.credit) }}
            </div>
          </v-card>
        </v-col>
      </v-row>

      <v-card flat rounded="lg" class="section-card">
        <v-data-table
          class="acct-table"
          :headers="glHeaders"
          :items="filteredGl"
          :loading="loading"
          density="comfortable"
          items-per-page="50"
        >
          <template #[`item.date`]="{ item }">{{ fmtDate(item.date) }}</template>
          <template #[`item.account`]="{ item }">
            <v-chip size="x-small" :color="glAccountColor(item.account)" variant="tonal">
              {{ glAccountLabel(item.account) }}
            </v-chip>
          </template>
          <template #[`item.reference`]="{ item }">
            <div class="font-weight-medium">{{ item.reference }}</div>
            <div class="text-caption text-medium-emphasis">{{ item.memo }}</div>
          </template>
          <template #[`item.debit`]="{ item }">
            <span v-if="item.debit" class="text-success font-weight-medium">{{ fmtMoney(item.debit) }}</span>
            <span v-else>—</span>
          </template>
          <template #[`item.credit`]="{ item }">
            <span v-if="item.credit" class="text-deep-purple font-weight-medium">{{ fmtMoney(item.credit) }}</span>
            <span v-else>—</span>
          </template>
          <template #[`item.balance`]="{ item }">
            <strong :class="item.balance >= 0 ? 'text-success' : 'text-error'">
              {{ fmtMoney(item.balance) }}
            </strong>
          </template>
        </v-data-table>
      </v-card>
    </template>

    <!-- ── Custom range dialog ─────────────────────────────────────── -->
    <v-dialog v-model="customDialog" max-width="420" persistent>
      <v-card rounded="lg">
        <v-card-title class="pa-4 d-flex align-center ga-3">
          <v-avatar color="indigo-lighten-5" size="36">
            <v-icon color="indigo-darken-2" size="20">mdi-calendar-range</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">Date range</div>
            <div class="text-h6 font-weight-bold">Select custom range</div>
          </div>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-text-field v-model="customStart" type="date" label="From"
                        variant="outlined" density="compact" rounded="lg"
                        persistent-placeholder hide-details class="mb-3" />
          <v-text-field v-model="customEnd" type="date" label="To"
                        variant="outlined" density="compact" rounded="lg"
                        persistent-placeholder hide-details />
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" @click="customDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" prepend-icon="mdi-check"
                 :disabled="!customStart || !customEnd" @click="applyCustom">Apply</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Record payment dialog ───────────────────────────────────── -->
    <v-dialog v-model="payDialog" max-width="520" persistent>
      <v-card rounded="lg">
        <v-card-title class="pa-4 d-flex align-center ga-3">
          <v-avatar color="green-lighten-5" size="36">
            <v-icon color="green-darken-2" size="20">mdi-cash-plus</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">{{ payTarget?.invoice_number }}</div>
            <div class="text-h6 font-weight-bold">Record payment</div>
          </div>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-card flat class="pa-3 mb-3 notes-card">
            <div class="text-caption text-medium-emphasis">Balance due</div>
            <div class="text-h6 font-weight-bold">
              {{ fmtMoney(payTarget ? invoiceBalance(payTarget) : 0) }}
            </div>
          </v-card>
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-text-field v-model.number="payForm.amount" type="number" label="Amount"
                            variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="payForm.method" :items="paymentMethodOptions"
                        item-title="label" item-value="value" label="Method"
                        variant="outlined" density="compact" rounded="lg"
                        persistent-placeholder hide-details />
            </v-col>
            <v-col cols="12">
              <v-text-field v-model="payForm.reference" label="Reference"
                            placeholder="Receipt / transaction id" persistent-placeholder
                            variant="outlined" density="compact" rounded="lg" hide-details class="mt-2" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="payForm.notes" label="Notes"
                          variant="outlined" density="compact" rounded="lg"
                          rows="2" persistent-placeholder hide-details class="mt-2" />
            </v-col>
          </v-row>
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" @click="payDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" prepend-icon="mdi-content-save-outline"
                 :loading="paySaving" :disabled="!payForm.amount" @click="confirmPayment">
            Save payment
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Invoice details dialog ──────────────────────────────────── -->
    <v-dialog v-model="viewDialog" max-width="760" scrollable>
      <v-card v-if="viewInvoiceData" rounded="lg">
        <v-card-title class="pa-4 d-flex align-center ga-3">
          <v-avatar color="blue-lighten-5" size="36">
            <v-icon color="blue-darken-2" size="20">mdi-receipt-text</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">Invoice</div>
            <div class="text-h6 font-weight-bold">{{ viewInvoiceData.invoice_number }}</div>
          </div>
          <v-spacer />
          <v-chip size="small" :color="invoiceStatusColor(viewInvoiceData.status)" variant="tonal" class="text-capitalize">
            {{ viewInvoiceData.status }}
          </v-chip>
        </v-card-title>
        <v-divider />
        <v-card-text>
          <div class="text-body-2 mb-2">
            <strong>Patient:</strong> {{ patientLabel(viewInvoiceData) }}<br>
            <strong>Payer:</strong> {{ payerLabel(viewInvoiceData.payer_type) }}<br>
            <strong>Issued:</strong> {{ fmtDate(viewInvoiceData.created_at) }}
          </div>
          <v-table density="compact">
            <thead>
              <tr><th>Description</th><th class="text-right">Qty</th><th class="text-right">Price</th><th class="text-right">Amount</th></tr>
            </thead>
            <tbody>
              <tr v-for="i in (viewInvoiceData.items || [])" :key="i.id">
                <td>{{ i.description }}</td>
                <td class="text-right">{{ i.qty }}</td>
                <td class="text-right">{{ fmtMoney(i.unit_price) }}</td>
                <td class="text-right">{{ fmtMoney(i.amount) }}</td>
              </tr>
            </tbody>
          </v-table>
          <v-divider class="my-3" />
          <div class="d-flex justify-end">
            <div style="min-width:240px">
              <div class="d-flex"><span>Subtotal</span><v-spacer /><span>{{ fmtMoney(viewInvoiceData.subtotal) }}</span></div>
              <div class="d-flex"><span>Discount</span><v-spacer /><span>{{ fmtMoney(viewInvoiceData.discount) }}</span></div>
              <div class="d-flex"><span>Tax</span><v-spacer /><span>{{ fmtMoney(viewInvoiceData.tax) }}</span></div>
              <div class="d-flex font-weight-bold"><span>Total</span><v-spacer /><span>{{ fmtMoney(viewInvoiceData.total) }}</span></div>
              <div class="d-flex text-success"><span>Paid</span><v-spacer /><span>{{ fmtMoney(viewInvoiceData.amount_paid) }}</span></div>
              <div class="d-flex font-weight-bold" :class="invoiceBalance(viewInvoiceData) > 0 ? 'text-error' : 'text-success'">
                <span>Balance</span><v-spacer /><span>{{ fmtMoney(invoiceBalance(viewInvoiceData)) }}</span>
              </div>
            </div>
          </div>

          <div v-if="(viewInvoiceData.payments || []).length" class="mt-3">
            <div class="text-subtitle-2 mb-1">Payments</div>
            <v-list density="compact">
              <v-list-item v-for="p in viewInvoiceData.payments" :key="p.id">
                <template #prepend>
                  <v-icon :color="paymentColor(p.method)">{{ paymentIcon(p.method) }}</v-icon>
                </template>
                <v-list-item-title>
                  {{ fmtMoney(p.amount) }} · {{ p.method }}
                  <span v-if="p.reference" class="text-caption text-medium-emphasis"> · {{ p.reference }}</span>
                </v-list-item-title>
                <v-list-item-subtitle>{{ fmtDate(p.received_at) }}</v-list-item-subtitle>
              </v-list-item>
            </v-list>
          </div>
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" @click="viewDialog = false">Close</v-btn>
          <v-btn
            v-if="invoiceBalance(viewInvoiceData) > 0"
            color="primary" rounded="lg" prepend-icon="mdi-cash-plus"
            @click="viewDialog = false; openPay(viewInvoiceData)"
          >Record payment</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" :timeout="2400">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()

// ── Range / filters ───────────────────────────────────────────────
const rangeKey = ref('30d')
const rangeOptions = [
  { key: 'today', label: 'Today' },
  { key: '7d', label: 'Last 7 days' },
  { key: '30d', label: 'Last 30 days' },
  { key: 'mtd', label: 'Month to date' },
  { key: '90d', label: 'Last 90 days' },
  { key: 'ytd', label: 'Year to date' },
  { key: '1y', label: 'Last 365 days' },
  { key: 'custom', label: 'Custom…' },
]
const customDialog = ref(false)
const customStart = ref('')
const customEnd = ref('')

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
    case '1y': return { start: iso(sub(364)), end: iso(today), label: 'Last 365 days' }
    case 'custom':
      if (customStart.value && customEnd.value)
        return { start: customStart.value, end: customEnd.value, label: `${customStart.value} → ${customEnd.value}` }
      return { start: iso(sub(29)), end: iso(today), label: 'Last 30 days' }
    case '30d':
    default: return { start: iso(sub(29)), end: iso(today), label: 'Last 30 days' }
  }
}

const data = ref({ range: resolveRange() })

function onRangeChange(v) {
  if (v === 'custom') { customDialog.value = true; return }
  data.value.range = resolveRange()
  loadAll()
}
function applyCustom() {
  if (!customStart.value || !customEnd.value) return
  rangeKey.value = 'custom'
  customDialog.value = false
  data.value.range = resolveRange()
  loadAll()
}

// ── Data sources ──────────────────────────────────────────────────
const route = useRoute()
const tab = ref(route.query.tab || 'overview')
const sectionPills = [
  { value: 'overview',     label: 'Overview',       color: 'primary',     icon: 'mdi-view-dashboard-outline' },
  { value: 'receivables',  label: 'Receivables',    color: 'error',       icon: 'mdi-cash-fast' },
  { value: 'payables',     label: 'Payables',       color: 'warning',     icon: 'mdi-cash-clock' },
  { value: 'transactions', label: 'Transactions',   color: 'indigo',      icon: 'mdi-swap-vertical' },
  { value: 'aging',        label: 'Aging',          color: 'deep-orange', icon: 'mdi-calendar-clock' },
  { value: 'pnl',          label: 'Profit & Loss',  color: 'teal',        icon: 'mdi-chart-box' },
  { value: 'patients',     label: 'Top Patients',   color: 'pink',        icon: 'mdi-account-star' },
  { value: 'tests',        label: 'Top Tests',      color: 'cyan',        icon: 'mdi-test-tube' },
  { value: 'balance',      label: 'Balance Sheet',  color: 'green',       icon: 'mdi-scale-balance' },
  { value: 'ledger',       label: 'General Ledger', color: 'deep-purple', icon: 'mdi-book-open-variant' },
]
const loading = ref(false)
const invoices = ref([])
const payments = ref([])
const expenses = ref([])
const reagents = ref([])
const reagentLots = ref([])
const apiBilling = ref(null)

const snack = ref({ show: false, color: 'success', text: '' })
const notify = (text, color = 'success') => { snack.value = { show: true, color, text } }

function pickRows(settled) {
  if (settled.status !== 'fulfilled') return []
  const d = settled.value?.data
  return d?.results || (Array.isArray(d) ? d : [])
}

async function loadAll() {
  loading.value = true
  data.value.range = resolveRange()
  try {
    const [inv, pay, exp, reag, lots, api] = await Promise.allSettled([
      $api.get('/lab/invoices/', { params: { page_size: 500, ordering: '-created_at' } }),
      $api.get('/lab/invoice-payments/', { params: { page_size: 500, ordering: '-received_at' } }),
      $api.get('/expenses/expenses/', { params: { page_size: 500, ordering: '-expense_date' } }),
      $api.get('/lab/reagents/', { params: { page_size: 500 } }),
      $api.get('/lab/reagent-lots/', { params: { page_size: 500 } }),
      $api.get('/usage-billing/lab/dashboard/'),
    ])
    invoices.value = pickRows(inv)
    payments.value = pickRows(pay)
    expenses.value = pickRows(exp)
    reagents.value = pickRows(reag)
    reagentLots.value = pickRows(lots)
    apiBilling.value = api.status === 'fulfilled' ? api.value?.data : null
  } catch (e) {
    notify('Failed to load lab accounts', 'error')
  } finally {
    loading.value = false
  }
}

onMounted(loadAll)
watch(() => route.query.tab, v => { if (v) tab.value = v })

// ── Range filtering ──────────────────────────────────────────────
const inRange = (iso) => {
  if (!iso) return false
  const d = String(iso).slice(0, 10)
  return d >= data.value.range.start && d <= data.value.range.end
}
const invoicesInRange = computed(() => invoices.value.filter(i => inRange(i.created_at)))
const paymentsInRange = computed(() => payments.value.filter(p => inRange(p.received_at)))
const expensesInRange = computed(() => expenses.value.filter(e => inRange(e.expense_date || e.created_at)))

// ── Helpers ──────────────────────────────────────────────────────
const fmtMoney = (v) => 'KSh ' + Number(v || 0).toLocaleString(undefined, { maximumFractionDigits: 2 })
const fmtDate = (v) => v ? new Date(v).toLocaleDateString() : '—'
const invoiceBalance = (i) => Math.max(0, Number(i.total || 0) - Number(i.amount_paid || 0))
const patientLabel = (i) => {
  if (i.patient_name) return i.patient_name
  const p = i.patient || {}
  if (p.user) return `${p.user.first_name || ''} ${p.user.last_name || ''}`.trim()
  return p.full_name || p.name || `Patient #${i.patient || ''}`
}

const paymentMethodOptions = [
  { value: 'cash', label: 'Cash' },
  { value: 'mpesa', label: 'M-Pesa' },
  { value: 'card', label: 'Card' },
  { value: 'bank', label: 'Bank Transfer' },
  { value: 'insurance', label: 'Insurance' },
]
function paymentColor(k) {
  return ({ cash: 'green', mpesa: 'teal', card: 'indigo', bank: 'blue', insurance: 'purple' })[k] || 'grey'
}
function paymentIcon(k) {
  return ({
    cash: 'mdi-cash', mpesa: 'mdi-cellphone', card: 'mdi-credit-card',
    bank: 'mdi-bank-transfer', insurance: 'mdi-shield-account',
  })[k] || 'mdi-cash-multiple'
}

const payerOptions = [
  { value: 'self', label: 'Self / Cash' },
  { value: 'insurance', label: 'Insurance' },
  { value: 'facility', label: 'Referring Facility' },
  { value: 'corporate', label: 'Corporate' },
]
const payerLabel = (k) => payerOptions.find(o => o.value === k)?.label || k || '—'
function payerColor(k) {
  return ({ self: 'green', insurance: 'purple', facility: 'blue', corporate: 'orange' })[k] || 'grey'
}

const invoiceStatusOptions = [
  { value: 'draft', label: 'Draft' },
  { value: 'issued', label: 'Issued' },
  { value: 'partial', label: 'Partially Paid' },
  { value: 'paid', label: 'Paid' },
  { value: 'void', label: 'Void' },
]
function invoiceStatusColor(s) {
  return ({ draft: 'grey', issued: 'blue', partial: 'amber', paid: 'success', void: 'error' })[s] || 'grey'
}

const expenseStatusOptions = [
  { value: 'pending', label: 'Pending' },
  { value: 'approved', label: 'Approved' },
  { value: 'paid', label: 'Paid' },
  { value: 'rejected', label: 'Rejected' },
]
function expenseStatusColor(s) {
  return ({ pending: 'amber', approved: 'orange', paid: 'success', rejected: 'error' })[s] || 'grey'
}

// ── KPIs ────────────────────────────────────────────────────────
const totalRevenue = computed(() =>
  paymentsInRange.value.reduce((s, p) => s + Number(p.amount || 0), 0)
)
const totalOutstanding = computed(() =>
  invoices.value
    .filter(i => i.status !== 'void')
    .reduce((s, i) => s + invoiceBalance(i), 0)
)
const totalExpenses = computed(() =>
  expensesInRange.value
    .filter(e => e.status !== 'rejected')
    .reduce((s, e) => s + Number(e.amount || 0), 0)
)
const apiCost = computed(() => {
  const cm = apiBilling.value?.current_month
  return Number(cm?.cost_so_far || 0)
})
const netProfit = computed(() => totalRevenue.value - totalExpenses.value - apiCost.value - cogsEstimate.value)

// Rough COGS — sum reagent transactions of type ISSUE inside range × cost.
// We don't have direct transaction list; approximate using lots' avg unit cost × qty consumed.
const cogsEstimate = computed(() => {
  // If reagentLots include `consumed_qty` and `unit_cost`, sum proportional.
  return reagentLots.value.reduce((s, l) => {
    const consumed = Number(l.consumed_qty || 0)
    const unit = Number(l.unit_cost || 0)
    return s + consumed * unit
  }, 0)
})

const kpiTiles = computed(() => [
  {
    label: 'Revenue',
    value: fmtMoney(totalRevenue.value),
    sub: `${paymentsInRange.value.length} payments`,
    icon: 'mdi-cash-fast', color: 'success', trendClass: 'text-success',
  },
  {
    label: 'Outstanding',
    value: fmtMoney(totalOutstanding.value),
    sub: `${invoices.value.filter(i => invoiceBalance(i) > 0 && i.status !== 'void').length} open invoices`,
    icon: 'mdi-receipt-text-outline', color: 'error', trendClass: 'text-error',
  },
  {
    label: 'Expenses',
    value: fmtMoney(totalExpenses.value + apiCost.value),
    sub: `incl. ${fmtMoney(apiCost.value)} API`,
    icon: 'mdi-cash-minus', color: 'warning', trendClass: 'text-warning',
  },
  {
    label: 'Net Profit',
    value: fmtMoney(netProfit.value),
    sub: totalRevenue.value > 0
      ? `${((netProfit.value / totalRevenue.value) * 100).toFixed(1)}% margin`
      : '—',
    icon: 'mdi-chart-line', color: netProfit.value >= 0 ? 'teal' : 'error',
    trendClass: netProfit.value >= 0 ? 'text-success' : 'text-error',
  },
])

// ── Cash flow series (per-day) ───────────────────────────────────
const cashflowSeries = computed(() => {
  const map = new Map()
  const start = new Date(data.value.range.start)
  const end = new Date(data.value.range.end)
  for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
    const k = d.toISOString().slice(0, 10)
    map.set(k, { date: k, income: 0, expense: 0 })
  }
  paymentsInRange.value.forEach(p => {
    const k = String(p.received_at || '').slice(0, 10)
    if (map.has(k)) map.get(k).income += Number(p.amount || 0)
  })
  expensesInRange.value.forEach(e => {
    const k = String(e.expense_date || e.created_at || '').slice(0, 10)
    if (map.has(k)) map.get(k).expense += Number(e.amount || 0)
  })
  return Array.from(map.values())
})

// ── Cash by method ───────────────────────────────────────────────
const cashByMethod = computed(() => {
  const map = new Map()
  paymentsInRange.value.forEach(p => {
    const k = p.method || 'other'
    map.set(k, (map.get(k) || 0) + Number(p.amount || 0))
  })
  const total = Array.from(map.values()).reduce((a, b) => a + b, 0) || 1
  return Array.from(map.entries())
    .map(([key, val]) => ({
      key, label: paymentMethodOptions.find(o => o.value === key)?.label || key,
      total: val, pct: Math.round((val / total) * 100),
    }))
    .sort((a, b) => b.total - a.total)
})

// ── Receivables ──────────────────────────────────────────────────
const receivableSearch = ref('')
const receivableStatus = ref(null)
const receivablePayer = ref(null)

const receivableHeaders = [
  { title: 'Invoice', key: 'invoice_number' },
  { title: 'Patient', key: 'patient', sortable: false },
  { title: 'Payer', key: 'payer_type' },
  { title: 'Total', key: 'total', align: 'end' },
  { title: 'Paid', key: 'amount_paid', align: 'end' },
  { title: 'Balance', key: 'balance', align: 'end' },
  { title: 'Status', key: 'status' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 60 },
]
const filteredReceivables = computed(() => {
  const q = receivableSearch.value.toLowerCase()
  return invoices.value.filter(i => {
    if (receivableStatus.value && i.status !== receivableStatus.value) return false
    if (receivablePayer.value && i.payer_type !== receivablePayer.value) return false
    if (!q) return true
    return (i.invoice_number || '').toLowerCase().includes(q) ||
           patientLabel(i).toLowerCase().includes(q)
  })
})
const topReceivables = computed(() =>
  invoices.value
    .filter(i => invoiceBalance(i) > 0 && i.status !== 'void')
    .map(decorateOverdue)
    .sort((a, b) => invoiceBalance(b) - invoiceBalance(a))
    .slice(0, 5)
)

function decorateOverdue(inv) {
  const due = new Date(inv.created_at)
  due.setDate(due.getDate() + 30) // 30-day default terms
  const daysLate = Math.floor((Date.now() - due.getTime()) / 86400000)
  return { ...inv, _isOverdue: daysLate > 0, _daysLate: Math.max(0, daysLate) }
}

// ── Aging ────────────────────────────────────────────────────────
const agedInvoices = computed(() =>
  invoices.value
    .filter(i => invoiceBalance(i) > 0 && i.status !== 'void')
    .map(decorateOverdue)
    .sort((a, b) => b._daysLate - a._daysLate)
)
const agingHeaders = [
  { title: 'Invoice', key: 'invoice_number' },
  { title: 'Patient', key: 'patient', sortable: false },
  { title: 'Balance', key: 'balance', align: 'end' },
  { title: 'Bucket', key: 'bucket' },
  { title: 'Days late', key: 'days', align: 'end' },
]
function agingLabelForDays(d) {
  if (d <= 0) return 'Current'
  if (d <= 30) return '1–30'
  if (d <= 60) return '31–60'
  if (d <= 90) return '61–90'
  return '90+'
}
function agingColorForDays(d) {
  if (d <= 0) return 'success'
  if (d <= 30) return 'amber'
  if (d <= 60) return 'orange'
  if (d <= 90) return 'deep-orange'
  return 'error'
}
const agingBuckets = computed(() => {
  const buckets = [
    { label: 'Current', color: 'success', total: 0, count: 0, max: 0 },
    { label: '1–30', color: 'amber', total: 0, count: 0, max: 30 },
    { label: '31–60', color: 'orange', total: 0, count: 0, max: 60 },
    { label: '61–90', color: 'deep-orange', total: 0, count: 0, max: 90 },
    { label: '90+', color: 'error', total: 0, count: 0, max: Infinity },
  ]
  agedInvoices.value.forEach(i => {
    const d = i._daysLate
    let idx = 0
    if (d <= 0) idx = 0
    else if (d <= 30) idx = 1
    else if (d <= 60) idx = 2
    else if (d <= 90) idx = 3
    else idx = 4
    buckets[idx].total += invoiceBalance(i)
    buckets[idx].count += 1
  })
  return buckets
})

// ── Payables ─────────────────────────────────────────────────────
const payableSearch = ref('')
const payableStatus = ref(null)
const payableHeaders = [
  { title: 'Title', key: 'title' },
  { title: 'Category', key: 'category' },
  { title: 'Amount', key: 'amount', align: 'end' },
  { title: 'Date', key: 'expense_date' },
  { title: 'Status', key: 'status' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 60 },
]
const filteredPayables = computed(() => {
  const q = payableSearch.value.toLowerCase()
  return expensesInRange.value.filter(e => {
    if (payableStatus.value && e.status !== payableStatus.value) return false
    if (!q) return true
    return (e.title || '').toLowerCase().includes(q) ||
           (e.vendor || '').toLowerCase().includes(q)
  })
})
const topPayables = computed(() =>
  expenses.value
    .filter(e => ['pending', 'approved'].includes(e.status))
    .sort((a, b) => Number(b.amount || 0) - Number(a.amount || 0))
    .slice(0, 5)
)

// ── Transactions ledger ──────────────────────────────────────────
const ledgerSearch = ref('')
const ledgerType = ref(null)
const ledgerTypes = [
  { value: 'payment', label: 'Lab payment' },
  { value: 'expense', label: 'Expense' },
  { value: 'invoice', label: 'Invoice issued' },
]
const ledgerHeaders = [
  { title: 'Date', key: 'date' },
  { title: 'Type', key: 'type' },
  { title: 'Reference', key: 'reference' },
  { title: 'Method', key: 'method' },
  { title: 'Income', key: 'income', align: 'end' },
  { title: 'Expense', key: 'expense', align: 'end' },
]
const fullLedger = computed(() => {
  const rows = []
  paymentsInRange.value.forEach(p => {
    const inv = invoices.value.find(i => i.id === p.invoice) || {}
    rows.push({
      date: p.received_at,
      type: 'payment',
      reference: inv.invoice_number || `Payment #${p.id}`,
      party: patientLabel(inv),
      method: p.method,
      direction: 'in',
      amount: Number(p.amount || 0),
    })
  })
  expensesInRange.value
    .filter(e => e.status !== 'rejected')
    .forEach(e => {
      rows.push({
        date: e.expense_date || e.created_at,
        type: 'expense',
        reference: e.title,
        party: e.vendor || e.category_name || '',
        method: e.payment_method,
        direction: 'out',
        amount: Number(e.amount || 0),
      })
    })
  invoicesInRange.value.forEach(i => {
    rows.push({
      date: i.created_at,
      type: 'invoice',
      reference: i.invoice_number,
      party: patientLabel(i),
      method: '',
      direction: 'memo',
      amount: Number(i.total || 0),
    })
  })
  return rows.sort((a, b) => String(b.date).localeCompare(String(a.date)))
})
function ledgerTypeColor(t) {
  return ({ payment: 'success', expense: 'error', invoice: 'info' })[t] || 'grey'
}
const filteredLedger = computed(() => {
  const q = ledgerSearch.value.toLowerCase()
  return fullLedger.value.filter(r => {
    if (ledgerType.value && r.type !== ledgerType.value) return false
    if (!q) return true
    return (r.reference || '').toLowerCase().includes(q) ||
           (r.party || '').toLowerCase().includes(q)
  })
})
const ledgerTotals = computed(() => ({
  income: filteredLedger.value.filter(r => r.direction === 'in').reduce((s, r) => s + r.amount, 0),
  expense: filteredLedger.value.filter(r => r.direction === 'out').reduce((s, r) => s + r.amount, 0),
}))

// ── P&L ─────────────────────────────────────────────────────────
const pnl = computed(() => {
  const revenue = totalRevenue.value
  const cogs = cogsEstimate.value
  const expByCategory = new Map()
  expensesInRange.value
    .filter(e => e.status !== 'rejected')
    .forEach(e => {
      const cat = e.category_name || e.category || 'Uncategorized'
      expByCategory.set(cat, (expByCategory.get(cat) || 0) + Number(e.amount || 0))
    })
  const expenseRows = Array.from(expByCategory.entries())
    .map(([category, total]) => ({ category, total }))
    .sort((a, b) => b.total - a.total)
  const opex = expenseRows.reduce((s, r) => s + r.total, 0)
  const apiCostV = apiCost.value
  const grossProfit = revenue - cogs
  const netProfitV = grossProfit - opex - apiCostV
  return { revenue, cogs, opex, apiCost: apiCostV, expenseRows, grossProfit, netProfit: netProfitV }
})

const revenueByPayer = computed(() => {
  const map = new Map()
  paymentsInRange.value.forEach(p => {
    const inv = invoices.value.find(i => i.id === p.invoice)
    const k = inv?.payer_type || 'self'
    map.set(k, (map.get(k) || 0) + Number(p.amount || 0))
  })
  const total = Array.from(map.values()).reduce((a, b) => a + b, 0) || 1
  return Array.from(map.entries())
    .map(([key, val]) => ({ key, total: val, pct: Math.round((val / total) * 100) }))
    .sort((a, b) => b.total - a.total)
})

// ── Top patients / tests ─────────────────────────────────────────
const topPatientHeaders = [
  { title: '#', key: 'rank', sortable: false, width: 50 },
  { title: 'Patient', key: 'name' },
  { title: 'Invoices', key: 'invoices', align: 'end' },
  { title: 'Revenue', key: 'revenue', align: 'end' },
  { title: 'Outstanding', key: 'balance', align: 'end' },
]
const topPatientsData = computed(() => {
  const map = new Map()
  invoicesInRange.value.forEach(i => {
    const name = patientLabel(i)
    const cur = map.get(name) || { name, invoices: 0, revenue: 0, balance: 0 }
    cur.invoices += 1
    cur.revenue += Number(i.amount_paid || 0)
    cur.balance += invoiceBalance(i)
    map.set(name, cur)
  })
  return Array.from(map.values()).sort((a, b) => b.revenue - a.revenue).slice(0, 25)
})

const topTestHeaders = [
  { title: '#', key: 'rank', sortable: false, width: 50 },
  { title: 'Test / Description', key: 'name' },
  { title: 'Quantity', key: 'qty', align: 'end' },
  { title: 'Revenue', key: 'revenue', align: 'end' },
]
const topTestsData = computed(() => {
  const map = new Map()
  invoicesInRange.value.forEach(i => {
    (i.items || []).forEach(it => {
      const k = it.description || `Test #${it.test || it.panel || ''}`
      const cur = map.get(k) || { name: k, qty: 0, revenue: 0 }
      cur.qty += Number(it.qty || 0)
      cur.revenue += Number(it.amount || 0)
      map.set(k, cur)
    })
  })
  return Array.from(map.values()).sort((a, b) => b.revenue - a.revenue).slice(0, 25)
})

// ── Balance Sheet ────────────────────────────────────────────────
// All-time figures (not range-bound) for true point-in-time snapshot
const allCashByMethod = computed(() => {
  const map = { cash: 0, bank: 0, mpesa: 0, card: 0, insurance: 0 }
  payments.value.forEach(p => {
    const k = p.method || 'cash'
    if (map[k] !== undefined) map[k] += Number(p.amount || 0)
  })
  return map
})
const inventoryValue = computed(() =>
  reagentLots.value.reduce((s, l) => {
    const remaining = Math.max(0, Number(l.qty_received || l.initial_qty || 0) - Number(l.consumed_qty || 0))
    return s + remaining * Number(l.unit_cost || 0)
  }, 0)
)
const allReceivables = computed(() =>
  invoices.value
    .filter(i => i.status !== 'void')
    .reduce((s, i) => s + invoiceBalance(i), 0)
)
const insuranceReceivable = computed(() =>
  invoices.value
    .filter(i => i.status !== 'void' && i.payer_type === 'insurance')
    .reduce((s, i) => s + invoiceBalance(i), 0)
)
const allPayables = computed(() => ({
  approved: expenses.value.filter(e => e.status === 'approved')
    .reduce((s, e) => s + Number(e.amount || 0), 0),
  pending: expenses.value.filter(e => e.status === 'pending')
    .reduce((s, e) => s + Number(e.amount || 0), 0),
}))
const apiPayableValue = computed(() => Number(apiBilling.value?.current_month?.cost_so_far || 0))

const balanceSheet = computed(() => {
  const m = allCashByMethod.value
  const cash = m.cash
  const bank = m.bank
  const mpesa = m.mpesa
  const card = m.card
  const receivables = allReceivables.value
  const inventory = inventoryValue.value
  const totalAssets = cash + bank + mpesa + card + receivables + inventory

  const payables = allPayables.value.approved
  const accrued = allPayables.value.pending
  const apiPayable = apiPayableValue.value
  const insurancePayable = 0 // claims we owe; placeholder
  const totalLiabilities = payables + accrued + apiPayable + insurancePayable

  const retained = totalAssets - totalLiabilities
  const totalEquity = retained
  const balanced = Math.abs(totalAssets - (totalLiabilities + totalEquity)) < 0.5

  return {
    cash, bank, mpesa, card, receivables, inventory, totalAssets,
    payables, accrued, apiPayable, insurancePayable, totalLiabilities,
    retained, totalEquity, balanced,
  }
})

const assetBreakdown = computed(() => {
  const b = balanceSheet.value
  const items = [
    { label: 'Cash on hand', value: b.cash, color: 'green' },
    { label: 'Bank', value: b.bank, color: 'blue' },
    { label: 'M-Pesa', value: b.mpesa, color: 'teal' },
    { label: 'Card', value: b.card, color: 'indigo' },
    { label: 'Receivables', value: b.receivables, color: 'orange' },
    { label: 'Inventory', value: b.inventory, color: 'purple' },
  ].filter(x => x.value > 0)
  const total = items.reduce((s, x) => s + x.value, 0) || 1
  return items.map(x => ({ ...x, pct: Math.round((x.value / total) * 100) }))
})

const ratios = computed(() => {
  const b = balanceSheet.value
  const currentAssets = b.cash + b.bank + b.mpesa + b.card + b.receivables + b.inventory
  const currentLiab = b.totalLiabilities || 0
  const num = (v) => isFinite(v) ? v.toFixed(2) : '—'
  return {
    current: currentLiab ? num(currentAssets / currentLiab) : '—',
    quick: currentLiab ? num((currentAssets - b.inventory) / currentLiab) : '—',
    debtEquity: b.totalEquity ? num(b.totalLiabilities / b.totalEquity) : '—',
    netMargin: totalRevenue.value > 0
      ? ((netProfit.value / totalRevenue.value) * 100).toFixed(1) + '%'
      : '—',
    workingCapital: currentAssets - currentLiab,
  }
})

// ── General Ledger (double-entry derived) ────────────────────────
const glAccounts = [
  { key: 'cash', label: 'Cash on hand' },
  { key: 'bank', label: 'Bank' },
  { key: 'mpesa', label: 'M-Pesa' },
  { key: 'card', label: 'Card clearing' },
  { key: 'ar', label: 'Accounts receivable' },
  { key: 'revenue', label: 'Lab services revenue' },
  { key: 'ap', label: 'Accounts payable' },
  { key: 'expense', label: 'Operating expenses' },
  { key: 'cogs', label: 'Cost of goods sold' },
  { key: 'inventory', label: 'Reagent inventory' },
  { key: 'api', label: 'API usage expense' },
]
function glAccountLabel(k) { return glAccounts.find(a => a.key === k)?.label || k }
function glAccountColor(k) {
  return ({
    cash: 'green', bank: 'blue', mpesa: 'teal', card: 'indigo',
    ar: 'orange', revenue: 'success',
    ap: 'amber', expense: 'error', cogs: 'deep-orange',
    inventory: 'purple', api: 'pink',
  })[k] || 'grey'
}
function methodToAccount(m) {
  return ({ cash: 'cash', mpesa: 'mpesa', card: 'card', bank: 'bank', insurance: 'ar' })[m] || 'cash'
}

// Build journal entries from raw data within range
const journal = computed(() => {
  const entries = []
  // Invoices issued: Dr AR / Cr Revenue
  invoicesInRange.value.forEach(i => {
    const total = Number(i.total || 0)
    if (!total) return
    entries.push({
      date: i.created_at, account: 'ar',
      reference: i.invoice_number, memo: `Invoice — ${patientLabel(i)}`,
      debit: total, credit: 0,
    })
    entries.push({
      date: i.created_at, account: 'revenue',
      reference: i.invoice_number, memo: `Revenue — ${patientLabel(i)}`,
      debit: 0, credit: total,
    })
  })
  // Payments: Dr Cash/Bank/etc / Cr AR
  paymentsInRange.value.forEach(p => {
    const inv = invoices.value.find(i => i.id === p.invoice) || {}
    const acc = methodToAccount(p.method)
    const amt = Number(p.amount || 0)
    if (!amt) return
    entries.push({
      date: p.received_at, account: acc,
      reference: inv.invoice_number || `PMT-${p.id}`,
      memo: `Payment received (${p.method})`,
      debit: amt, credit: 0,
    })
    entries.push({
      date: p.received_at, account: 'ar',
      reference: inv.invoice_number || `PMT-${p.id}`,
      memo: `AR settled — ${patientLabel(inv)}`,
      debit: 0, credit: amt,
    })
  })
  // Expenses approved/paid: Dr Expense / Cr AP
  expensesInRange.value.filter(e => e.status !== 'rejected').forEach(e => {
    const amt = Number(e.amount || 0)
    if (!amt) return
    entries.push({
      date: e.expense_date || e.created_at, account: 'expense',
      reference: e.title, memo: e.category_name || e.category || '',
      debit: amt, credit: 0,
    })
    entries.push({
      date: e.expense_date || e.created_at, account: 'ap',
      reference: e.title, memo: `Payable — ${e.vendor || ''}`,
      debit: 0, credit: amt,
    })
    // If paid, also Dr AP / Cr Cash
    if (e.status === 'paid') {
      const acc = methodToAccount(e.payment_method || 'cash')
      entries.push({
        date: e.expense_date || e.created_at, account: 'ap',
        reference: e.title, memo: `AP settled`,
        debit: amt, credit: 0,
      })
      entries.push({
        date: e.expense_date || e.created_at, account: acc,
        reference: e.title, memo: `Expense paid (${e.payment_method || 'cash'})`,
        debit: 0, credit: amt,
      })
    }
  })
  // API cost: Dr API expense / Cr AP
  if (apiPayableValue.value > 0) {
    entries.push({
      date: data.value.range.end, account: 'api',
      reference: 'API-USAGE', memo: 'API usage for current period',
      debit: apiPayableValue.value, credit: 0,
    })
    entries.push({
      date: data.value.range.end, account: 'ap',
      reference: 'API-USAGE', memo: 'Payable to platform',
      debit: 0, credit: apiPayableValue.value,
    })
  }
  return entries.sort((a, b) => String(a.date).localeCompare(String(b.date)))
})

const glAccountFilter = ref(null)
const glSearch = ref('')

const glHeaders = [
  { title: 'Date', key: 'date', width: 110 },
  { title: 'Account', key: 'account', width: 180 },
  { title: 'Reference / Memo', key: 'reference' },
  { title: 'Debit', key: 'debit', align: 'end' },
  { title: 'Credit', key: 'credit', align: 'end' },
  { title: 'Running balance', key: 'balance', align: 'end' },
]

const filteredGl = computed(() => {
  const q = glSearch.value.toLowerCase()
  let running = 0
  const filterAcc = glAccountFilter.value
  return journal.value
    .filter(e => {
      if (filterAcc && e.account !== filterAcc) return false
      if (!q) return true
      return (e.reference || '').toLowerCase().includes(q) ||
             (e.memo || '').toLowerCase().includes(q)
    })
    .map(e => {
      // Running balance: only meaningful when filtered to one account
      if (filterAcc) running += (e.debit - e.credit)
      else running = (e.debit - e.credit)
      return { ...e, balance: filterAcc ? running : (e.debit - e.credit) }
    })
})

const glTotals = computed(() => ({
  debit: filteredGl.value.reduce((s, e) => s + e.debit, 0),
  credit: filteredGl.value.reduce((s, e) => s + e.credit, 0),
}))

const glAccountSummary = computed(() => {
  const map = new Map()
  glAccounts.forEach(a => map.set(a.key, { ...a, debit: 0, credit: 0 }))
  journal.value.forEach(e => {
    const cur = map.get(e.account)
    if (cur) { cur.debit += e.debit; cur.credit += e.credit }
  })
  return Array.from(map.values())
    .filter(a => a.debit > 0 || a.credit > 0)
    .map(a => ({ ...a, balance: a.debit - a.credit, color: glAccountColor(a.key) }))
    .slice(0, 8)
})

// ── Dialogs / actions ────────────────────────────────────────────
const payDialog = ref(false)
const payTarget = ref(null)
const payForm = ref({ amount: 0, method: 'cash', reference: '', notes: '' })
const paySaving = ref(false)
function openPay(inv) {
  payTarget.value = inv
  payForm.value = { amount: invoiceBalance(inv), method: 'cash', reference: '', notes: '' }
  payDialog.value = true
}
async function confirmPayment() {
  paySaving.value = true
  try {
    await $api.post(`/lab/invoices/${payTarget.value.id}/add_payment/`, payForm.value)
    notify('Payment recorded')
    payDialog.value = false
    await loadAll()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to record payment', 'error')
  } finally {
    paySaving.value = false
  }
}

const viewDialog = ref(false)
const viewInvoiceData = ref(null)
async function viewInvoice(inv) {
  try {
    const { data: full } = await $api.get(`/lab/invoices/${inv.id}/`)
    viewInvoiceData.value = full
    viewDialog.value = true
  } catch {
    viewInvoiceData.value = inv
    viewDialog.value = true
  }
}

async function approveExpense(e) {
  try {
    await $api.post(`/expenses/expenses/${e.id}/approve/`)
    notify('Expense approved')
    await loadAll()
  } catch { notify('Failed to approve', 'error') }
}
async function rejectExpense(e) {
  try {
    await $api.post(`/expenses/expenses/${e.id}/reject/`)
    notify('Expense rejected')
    await loadAll()
  } catch { notify('Failed to reject', 'error') }
}
async function markExpensePaid(e) {
  try {
    await $api.post(`/expenses/expenses/${e.id}/mark_paid/`, { payment_method: e.payment_method })
    notify('Marked paid')
    await loadAll()
  } catch { notify('Failed to mark paid', 'error') }
}

// ── Export ───────────────────────────────────────────────────────
function csvDownload(filename, rows) {
  if (!rows.length) return notify('Nothing to export', 'warning')
  const keys = Object.keys(rows[0])
  const escape = (v) => `"${String(v ?? '').replace(/"/g, '""')}"`
  const lines = [keys.join(',')].concat(rows.map(r => keys.map(k => escape(r[k])).join(',')))
  const blob = new Blob([lines.join('\n')], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = filename; a.click()
  URL.revokeObjectURL(url)
}
function exportCsv(kind) {
  if (kind === 'pnl') {
    const rows = [
      { item: 'Revenue', amount: pnl.value.revenue },
      { item: 'COGS (reagents)', amount: pnl.value.cogs },
      { item: 'Gross profit', amount: pnl.value.grossProfit },
      ...pnl.value.expenseRows.map(r => ({ item: `Expense: ${r.category}`, amount: r.total })),
      { item: 'API cost', amount: pnl.value.apiCost },
      { item: 'Net profit', amount: pnl.value.netProfit },
    ]
    return csvDownload(`lab-pnl-${data.value.range.start}-${data.value.range.end}.csv`, rows)
  }
  if (kind === 'ledger') {
    return csvDownload(`lab-ledger-${data.value.range.start}-${data.value.range.end}.csv`,
      filteredLedger.value.map(r => ({
        date: r.date, type: r.type, reference: r.reference, party: r.party,
        method: r.method, income: r.direction === 'in' ? r.amount : '',
        expense: r.direction === 'out' ? r.amount : '',
      })))
  }
  if (kind === 'receivables') {
    return csvDownload(`lab-receivables.csv`, filteredReceivables.value.map(i => ({
      invoice: i.invoice_number, patient: patientLabel(i), payer: i.payer_type,
      total: i.total, paid: i.amount_paid, balance: invoiceBalance(i), status: i.status,
    })))
  }
  if (kind === 'aging') {
    return csvDownload(`lab-aging.csv`, agedInvoices.value.map(i => ({
      invoice: i.invoice_number, patient: patientLabel(i),
      balance: invoiceBalance(i), days_late: i._daysLate,
      bucket: agingLabelForDays(i._daysLate),
    })))
  }
  if (kind === 'balance') {
    const b = balanceSheet.value
    return csvDownload(`lab-balance-sheet-${data.value.range.end}.csv`, [
      { item: 'Cash on hand', amount: b.cash },
      { item: 'Bank', amount: b.bank },
      { item: 'M-Pesa', amount: b.mpesa },
      { item: 'Card', amount: b.card },
      { item: 'Accounts receivable', amount: b.receivables },
      { item: 'Reagent inventory', amount: b.inventory },
      { item: 'TOTAL ASSETS', amount: b.totalAssets },
      { item: 'Accounts payable', amount: b.payables },
      { item: 'Accrued expenses', amount: b.accrued },
      { item: 'API payable', amount: b.apiPayable },
      { item: 'TOTAL LIABILITIES', amount: b.totalLiabilities },
      { item: 'Retained earnings', amount: b.retained },
      { item: 'TOTAL EQUITY', amount: b.totalEquity },
    ])
  }
  if (kind === 'gl') {
    return csvDownload(`lab-general-ledger-${data.value.range.start}-${data.value.range.end}.csv`,
      filteredGl.value.map(e => ({
        date: e.date, account: glAccountLabel(e.account),
        reference: e.reference, memo: e.memo,
        debit: e.debit || '', credit: e.credit || '',
        balance: e.balance,
      })))
  }
}
</script>

<style scoped>
.kpi {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.section-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.section-pills {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.notes-card {
  background: rgba(var(--v-theme-warning), 0.06);
  border: 1px solid rgba(var(--v-theme-warning), 0.2);
}
.min-width-0 { min-width: 0; }
.pnl-table tr.pnl-section td {
  background: rgba(13,148,136,0.06);
  font-weight: 700; font-size: 0.78rem; letter-spacing: 0.04em;
  color: rgb(var(--v-theme-on-surface));
}
.pnl-table tr.pnl-subtotal td {
  border-top: 1px solid rgba(0,0,0,0.08);
  font-weight: 600;
}
.pnl-table tr.pnl-total td {
  border-top: 2px solid rgba(13,148,136,0.6);
  font-weight: 700; font-size: 1rem;
}
.acct-table :deep(tbody tr) { cursor: pointer; }
.acct-table :deep(tbody tr:hover) { background:#f0f9ff !important; }
.acct-table :deep(tbody tr:hover > td),
.acct-table :deep(tbody tr:hover > td *) {
  background-color: transparent !important;
  color:#0f172a !important;
}
.acct-table :deep(tbody tr:hover > td .text-medium-emphasis),
.acct-table :deep(tbody tr:hover > td .text-caption) {
  color:#475569 !important;
}
.acct-table :deep(tbody tr:hover .v-chip) { filter: none !important; }
</style>
