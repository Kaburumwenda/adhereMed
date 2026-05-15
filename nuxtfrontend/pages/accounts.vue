<template>
  <v-container fluid class="pa-3 pa-md-5">
        <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center">
        <v-avatar color="green-lighten-5" size="48" class="mr-3">
          <v-icon color="green-darken-2" size="28">mdi-bank</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 font-weight-bold mb-1">Accounts</h1>
          <div class="text-body-2 text-medium-emphasis">Income, expenses, receivables &amp; payables — your full financial position</div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn rounded="lg" variant="flat" color="primary" prepend-icon="mdi-refresh" class="text-none"
                 :loading="loading" @click="loadAll">Refresh</v-btn>
      <v-btn rounded="lg" v-bind="props" variant="flat" color="primary" class="text-none"
                     prepend-icon="mdi-download">Export</v-btn>
      </div>
    </div>

    <!-- Date Filter Chips -->
    <v-card flat rounded="xl" class="mb-4 pa-3" border>
      <div class="d-flex align-center flex-wrap ga-2">
        <v-icon size="20" color="primary" class="mr-1">mdi-calendar-filter</v-icon>
        <v-chip-group v-model="rangeKey" selected-class="text-primary" mandatory>
          <v-chip v-for="opt in rangeChips" :key="opt.key" :value="opt.key"
                  variant="outlined" size="small" rounded="lg" filter>
            {{ opt.label }}
          </v-chip>
        </v-chip-group>
        <v-spacer />
        <v-chip v-if="rangeKey === 'custom' && customStart && customEnd"
                size="small" variant="tonal" color="primary" rounded="lg"
                prepend-icon="mdi-calendar-range" closable
                @click="customDialog = true"
                @click:close="resetRange">
          {{ customStart }} — {{ customEnd }}
        </v-chip>
        <v-chip size="small" variant="tonal" color="grey" rounded="lg" prepend-icon="mdi-clock-outline">
          {{ data?.range?.label }}
        </v-chip>
      </div>
    </v-card>

    <!-- KPIs -->
    <v-row dense class="mb-4">
      <v-col v-for="k in kpiTiles" :key="k.label" cols="6" md="3">
        <v-card rounded="lg" class="pa-4 h-100 kpi-card">
          <div class="d-flex align-start justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h6 font-weight-bold mt-1">{{ k.value }}</div>
              <div v-if="k.sub" class="text-caption text-medium-emphasis mt-1">{{ k.sub }}</div>
            </div>
            <v-avatar :color="k.color" variant="tonal" rounded="lg" size="40">
              <v-icon size="20">{{ k.icon }}</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Tabs -->
    <v-card flat rounded="xl" class="mb-4" border>
      <v-tabs v-model="tab" color="emerald-darken-2" align-tabs="start" show-arrows>
        <v-tab value="overview" prepend-icon="mdi-view-dashboard-outline">Overview</v-tab>
        <v-tab value="receivables" prepend-icon="mdi-cash-fast">Receivables</v-tab>
        <v-tab value="payables" prepend-icon="mdi-cash-clock">Payables</v-tab>
        <v-tab value="transactions" prepend-icon="mdi-swap-vertical">Transactions</v-tab>
        <v-tab value="pnl" prepend-icon="mdi-chart-box">Profit &amp; Loss</v-tab>
        <v-tab value="balance" prepend-icon="mdi-scale-balance">Balance Sheet</v-tab>
        <v-tab value="ledger" prepend-icon="mdi-book-open-page-variant">General Ledger</v-tab>
      </v-tabs>
    </v-card>

    <!-- ===================== OVERVIEW ===================== -->
    <template v-if="tab === 'overview'">
      <v-row dense class="mb-3">
        <v-col cols="12" md="8">
          <v-card class="pa-4" rounded="xl" border>
            <div class="d-flex align-center mb-2">
              <v-icon color="emerald-darken-2" class="mr-2">mdi-chart-areaspline</v-icon>
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
            <div v-else class="cashflow-wrap">
              <SparkArea :values="cashflowSeries.map(p => p.income)" :height="180" color="#16a34a" />
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
          <v-card class="pa-4 h-100" rounded="xl" border>
            <div class="d-flex align-center mb-3">
              <v-icon color="indigo" class="mr-2">mdi-cash-multiple</v-icon>
              <div class="text-subtitle-1 font-weight-medium">Cash position by method</div>
            </div>
            <div v-if="!cashByMethod.length" class="text-center text-medium-emphasis py-6">No income yet</div>
            <div v-else>
              <div v-for="m in cashByMethod" :key="m.key" class="mb-3">
                <div class="d-flex align-center mb-1">
                  <v-icon :color="paymentColor(m.key)" size="18" class="mr-2">{{ paymentIcon(m.key) }}</v-icon>
                  <span class="text-body-2 font-weight-medium text-capitalize">{{ m.label }}</span>
                  <v-spacer />
                  <span class="text-body-2 font-weight-bold">{{ formatMoney(m.total) }}</span>
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
          <v-card class="pa-4 h-100" rounded="xl" border>
            <div class="d-flex align-center mb-3">
              <v-icon color="error" class="mr-2">mdi-receipt-text-outline</v-icon>
              <div class="text-subtitle-1 font-weight-medium">Top outstanding receivables</div>
              <v-spacer />
              <v-btn size="small" variant="text" color="primary" @click="tab = 'receivables'">View all</v-btn>
            </div>            <div v-if="!topReceivables.length" class="text-center text-medium-emphasis py-4">
              No outstanding receivables.
            </div>
            <v-list v-else density="compact" class="pa-0">
              <v-list-item v-for="inv in topReceivables" :key="`${inv._type}-${inv.id}`" class="px-0">
                <template #prepend>
                  <v-avatar size="32" :color="inv._isOverdue ? 'error' : 'warning'" variant="tonal">
                    <v-icon size="16">{{ inv._isOverdue ? 'mdi-alert' : 'mdi-clock-outline' }}</v-icon>
                  </v-avatar>
                </template>
                <v-list-item-title class="text-body-2 font-weight-medium">
                  {{ inv.invoice_number }}
                  <v-chip v-if="inv._type === 'credit'" size="x-small" color="orange" variant="tonal" class="ml-1">Credit</v-chip>
                  <span class="text-caption text-medium-emphasis"> · {{ inv.patient_name || '—' }}</span>
                </v-list-item-title>
                <v-list-item-subtitle class="text-caption">
                  Due {{ inv.due_date ? formatDate(inv.due_date) : 'no date' }}
                  <span v-if="inv._isOverdue" class="text-error font-weight-bold">
                    · {{ inv._daysLate }}d late
                  </span>
                </v-list-item-subtitle>
                <template #append>
                  <span class="font-weight-bold">{{ formatMoney(inv._balance) }}</span>
                </template>
              </v-list-item>
            </v-list>
          </v-card>
        </v-col>
        <v-col cols="12" md="6">
          <v-card class="pa-4 h-100" rounded="xl" border>
            <div class="d-flex align-center mb-3">
              <v-icon color="warning" class="mr-2">mdi-cash-clock</v-icon>
              <div class="text-subtitle-1 font-weight-medium">Pending payables</div>
              <v-spacer />
              <v-btn size="small" variant="text" color="primary" @click="tab = 'payables'">View all</v-btn>
            </div>
            <div v-if="!topPayables.length" class="text-center text-medium-emphasis py-4">
              Nothing pending approval or payment.
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
                  {{ ex.vendor || ex.supplier_name || '—' }} · {{ formatDate(ex.expense_date) }}
                </v-list-item-subtitle>
                <template #append>
                  <span class="font-weight-bold">{{ formatMoney(ex.amount) }}</span>
                </template>
              </v-list-item>
            </v-list>
          </v-card>
        </v-col>
      </v-row>

      <!-- API Usage & Billing -->
      <v-row v-if="apiBilling" dense class="mb-3">
        <v-col cols="12">
          <v-card class="pa-4" rounded="xl" border>
            <div class="d-flex align-center mb-3">
              <v-avatar color="deep-purple" size="36" class="mr-3">
                <v-icon color="white">mdi-api</v-icon>
              </v-avatar>
              <div>
                <div class="text-subtitle-1 font-weight-medium">API Usage &amp; Billing</div>
                <div class="text-caption text-medium-emphasis">
                  Platform consumption charges — payable to AfyaOne
                </div>
              </div>
              <v-spacer />
              <v-btn size="small" variant="text" color="primary" to="/billing/usage"
                     append-icon="mdi-arrow-right">View full dashboard</v-btn>
            </div>

            <v-row dense>
              <v-col cols="6" md="3">
                <div class="text-caption text-medium-emphasis">This month so far</div>
                <div class="text-h6 font-weight-bold">
                  {{ formatMoney(Number(apiBilling.current_month?.cost_so_far || 0)) }}
                </div>
                <div class="text-caption text-medium-emphasis">
                  {{ Number(apiBilling.current_month?.total_requests || 0).toLocaleString() }} requests
                </div>
              </v-col>
              <v-col cols="6" md="3">
                <div class="text-caption text-medium-emphasis">Projected EOM</div>
                <div class="text-h6 font-weight-bold text-warning">
                  {{ formatMoney(Number(apiBilling.current_month?.projected_cost || 0)) }}
                </div>
                <div class="text-caption text-medium-emphasis">
                  {{ apiBilling.current_month?.days_remaining }} days remaining
                </div>
              </v-col>
              <v-col cols="6" md="3">
                <div class="text-caption text-medium-emphasis">Outstanding bills</div>
                <div class="text-h6 font-weight-bold text-error">
                  {{ formatMoney(apiBillsOutstanding) }}
                </div>
                <div class="text-caption text-medium-emphasis">
                  {{ apiBillsOutstandingCount }} unpaid
                </div>
              </v-col>
              <v-col cols="6" md="3">
                <div class="text-caption text-medium-emphasis">Daily burn rate</div>
                <div class="text-h6 font-weight-bold">
                  {{ formatMoney(apiDailyBurn) }}
                </div>
                <div class="text-caption text-medium-emphasis">avg / day this month</div>
              </v-col>
            </v-row>

            <template v-if="apiBilling.recent_bills?.length">
              <v-divider class="my-3" />
              <div class="text-caption text-medium-emphasis text-uppercase mb-2">Recent bills</div>
              <v-list density="compact" class="pa-0">
                <v-list-item v-for="b in apiBilling.recent_bills.slice(0, 4)" :key="b.id" class="px-0">
                  <template #prepend>
                    <v-avatar size="32" :color="b.status === 'PAID' ? 'success' : 'warning'" variant="tonal">
                      <v-icon size="16">
                        {{ b.status === 'PAID' ? 'mdi-check' : 'mdi-clock-outline' }}
                      </v-icon>
                    </v-avatar>
                  </template>
                  <v-list-item-title class="text-body-2 font-weight-medium">
                    {{ monthLabel(b.year, b.month) }}
                    <span class="text-caption text-medium-emphasis">
                      · {{ Number(b.total_requests || 0).toLocaleString() }} requests
                    </span>
                  </v-list-item-title>
                  <v-list-item-subtitle class="text-caption">
                    <v-chip size="x-small" variant="tonal"
                            :color="b.status === 'PAID' ? 'success' : (b.status === 'CANCELLED' ? 'grey' : 'warning')">
                      {{ b.status }}
                    </v-chip>
                    <span v-if="b.paid_at" class="ml-2">paid {{ formatDate(b.paid_at) }}</span>
                  </v-list-item-subtitle>
                  <template #append>
                    <span class="font-weight-bold">{{ formatMoney(b.amount) }}</span>
                  </template>
                </v-list-item>
              </v-list>
            </template>
          </v-card>
        </v-col>
      </v-row>
    </template>

    <!-- ===================== RECEIVABLES ===================== -->
    <template v-if="tab === 'receivables'">
      <v-card flat rounded="xl" class="pa-3 mb-3" border>
        <v-row dense align="center">
          <v-col cols="12" md="5">
            <v-text-field v-model="invSearch" prepend-inner-icon="mdi-magnify"
                          placeholder="Search invoice # or patient…" density="comfortable"
                          variant="solo-filled" flat hide-details clearable />
          </v-col>
          <v-col cols="6" md="3">
            <v-select v-model="invStatus" :items="invoiceStatusItems"
                      label="Status" density="comfortable" hide-details variant="outlined" />
          </v-col>
          <v-col cols="6" md="2">
            <v-select v-model="invSort" :items="invoiceSortItems"
                      label="Sort" density="comfortable" hide-details variant="outlined" />
          </v-col>
          <v-col cols="12" md="2" class="d-flex justify-end">
            <v-btn color="primary" variant="flat" prepend-icon="mdi-cash-plus"
                   :disabled="!invoices.length" @click="openPayDialog(filteredInvoices[0])">
              Record payment
            </v-btn>
          </v-col>
        </v-row>
      </v-card>

      <!-- Aging buckets -->
      <v-row dense class="mb-3">
        <v-col v-for="b in agingBuckets" :key="b.key" cols="6" md="3">
          <v-card class="pa-3" rounded="xl" border>
            <div class="d-flex align-center mb-1">
              <v-avatar :color="b.color" size="32" class="mr-2">
                <v-icon size="16" color="white">{{ b.icon }}</v-icon>
              </v-avatar>
              <div class="text-caption text-uppercase text-medium-emphasis">{{ b.label }}</div>
            </div>
            <div class="text-h6 font-weight-bold">{{ formatMoney(b.total) }}</div>
            <div class="text-caption text-medium-emphasis">{{ b.count }} items</div>
          </v-card>
        </v-col>
      </v-row>

      <v-card flat rounded="xl" border>
        <v-data-table
          :headers="invoiceHeaders"
          :items="filteredInvoices"
          :loading="loading"
          item-value="id"
          density="comfortable" hover :items-per-page="20"
        >
          <template #item.invoice_number="{ item }">
            <div class="font-weight-medium">{{ item.invoice_number }}</div>
            <div class="text-caption text-medium-emphasis">{{ formatDate(item.created_at) }}</div>
          </template>
          <template #item.patient_name="{ item }">
            <div class="d-flex align-center">
              <v-avatar :color="avatarColor(item.patient_name)" size="32" class="mr-2">
                <span class="text-caption font-weight-bold text-white">{{ initials(item.patient_name) }}</span>
              </v-avatar>
              <div>{{ item.patient_name || '—' }}</div>
            </div>
          </template>
          <template #item.total="{ item }">
            <span class="font-weight-bold">{{ formatMoney(item.total) }}</span>
          </template>
          <template #item.amount_paid="{ item }">
            <span class="text-medium-emphasis">{{ formatMoney(item.amount_paid) }}</span>
          </template>
          <template #item.balance="{ item }">
            <span class="font-weight-bold" :class="invoiceBalance(item) > 0 ? 'text-error' : 'text-success'">
              {{ formatMoney(invoiceBalance(item)) }}
            </span>
          </template>
          <template #item.due_date="{ item }">
            <div v-if="item.due_date" class="d-flex align-center">
              <span>{{ formatDate(item.due_date) }}</span>
              <v-chip v-if="isOverdue(item)" size="x-small" color="error" variant="tonal" class="ml-2">
                {{ daysLate(item) }}d late
              </v-chip>
            </div>
            <span v-else class="text-medium-emphasis">—</span>
          </template>
          <template #item.status="{ item }">
            <v-chip :color="invoiceStatusColor(item.status)" size="small" variant="tonal" class="text-capitalize">
              {{ (item.status || '').replace('_', ' ') }}
            </v-chip>
          </template>
          <template #item.actions="{ item }">
            <v-btn v-if="invoiceBalance(item) > 0"
                   icon="mdi-cash-plus" variant="text" size="small" color="success"
                   @click="openPayDialog(item)" />
            <v-btn icon="mdi-eye" variant="text" size="small" @click="openInvoiceDetail(item)" />
          </template>
          <template #no-data>
            <EmptyState icon="mdi-receipt-text-outline" title="No invoices found"
                        message="Try widening the date range or adjusting filters." />
          </template>
        </v-data-table>
      </v-card>

      <!-- POS Credit Sales -->
      <v-card flat rounded="xl" border class="mt-4">
        <div class="d-flex align-center pa-4 pb-2">
          <v-icon color="orange" class="mr-2">mdi-account-credit-card</v-icon>
          <div class="text-subtitle-1 font-weight-medium">POS Credit Sales</div>
          <v-spacer />
          <v-chip size="small" color="orange" variant="tonal">
            {{ filteredCreditSales.filter(c => Number(c.balance_amount || 0) > 0).length }} outstanding
          </v-chip>
        </div>
        <v-data-table
          :headers="creditHeaders"
          :items="filteredCreditSales"
          :loading="loading"
          item-value="id"
          density="comfortable" hover :items-per-page="10"
        >
          <template #item.transaction_number="{ item }">
            <div class="font-weight-medium">{{ item.transaction_number || `CR-${item.id}` }}</div>
            <div class="text-caption text-medium-emphasis">{{ formatDate(item.created_at) }}</div>
          </template>
          <template #item.customer_name="{ item }">
            <div class="d-flex align-center">
              <v-avatar :color="avatarColor(item.customer_name)" size="32" class="mr-2">
                <span class="text-caption font-weight-bold text-white">{{ initials(item.customer_name) }}</span>
              </v-avatar>
              <div>
                <div>{{ item.customer_name || '—' }}</div>
                <div v-if="item.customer_phone" class="text-caption text-medium-emphasis">{{ item.customer_phone }}</div>
              </div>
            </div>
          </template>
          <template #item.total_amount="{ item }">
            <span class="font-weight-bold">{{ formatMoney(item.total_amount) }}</span>
          </template>
          <template #item.partial_paid_amount="{ item }">
            <span class="text-medium-emphasis">{{ formatMoney(item.partial_paid_amount) }}</span>
          </template>
          <template #item.balance_amount="{ item }">
            <span class="font-weight-bold" :class="Number(item.balance_amount) > 0 ? 'text-error' : 'text-success'">
              {{ formatMoney(item.balance_amount) }}
            </span>
          </template>
          <template #item.due_date="{ item }">
            <div v-if="item.due_date" class="d-flex align-center">
              <span>{{ formatDate(item.due_date) }}</span>
              <v-chip v-if="item.due_date < new Date().toISOString().slice(0, 10) && Number(item.balance_amount) > 0"
                      size="x-small" color="error" variant="tonal" class="ml-2">overdue</v-chip>
            </div>
            <span v-else class="text-medium-emphasis">—</span>
          </template>
          <template #item.status="{ item }">
            <v-chip :color="creditStatusColor(item.status)" size="small" variant="tonal" class="text-capitalize">
              {{ (item.status || '').replace('_', ' ') }}
            </v-chip>
          </template>
          <template #no-data>
            <EmptyState icon="mdi-account-credit-card" title="No credit sales"
                        message="POS credit sales will appear here." />
          </template>
        </v-data-table>
      </v-card>
    </template>

    <!-- ===================== PAYABLES ===================== -->
    <template v-if="tab === 'payables'">
      <v-card flat rounded="xl" class="pa-3 mb-3" border>
        <v-row dense align="center">
          <v-col cols="12" md="5">
            <v-text-field v-model="expSearch" prepend-inner-icon="mdi-magnify"
                          placeholder="Search title, vendor, reference…" density="comfortable"
                          variant="solo-filled" flat hide-details clearable />
          </v-col>
          <v-col cols="6" md="3">
            <v-select v-model="expStatus" :items="expenseStatusItems"
                      label="Status" density="comfortable" hide-details variant="outlined" />
          </v-col>
          <v-col cols="6" md="2">
            <v-select v-model="expSort" :items="expenseSortItems"
                      label="Sort" density="comfortable" hide-details variant="outlined" />
          </v-col>
          <v-col cols="12" md="2" class="d-flex justify-end">
            <v-btn color="primary" variant="flat" prepend-icon="mdi-plus"
                   to="/expenses/new">New expense</v-btn>
          </v-col>
        </v-row>
      </v-card>

      <v-row dense class="mb-3">
        <v-col v-for="b in payableBuckets" :key="b.key" cols="6" md="3">
          <v-card class="pa-3" rounded="xl" border>
            <div class="d-flex align-center mb-1">
              <v-avatar :color="b.color" size="32" class="mr-2">
                <v-icon size="16" color="white">{{ b.icon }}</v-icon>
              </v-avatar>
              <div class="text-caption text-uppercase text-medium-emphasis">{{ b.label }}</div>
            </div>
            <div class="text-h6 font-weight-bold">{{ formatMoney(b.total) }}</div>
            <div class="text-caption text-medium-emphasis">{{ b.count }} expenses</div>
          </v-card>
        </v-col>
      </v-row>

      <v-card flat rounded="xl" border>
        <v-data-table
          :headers="expenseHeaders"
          :items="filteredExpenses"
          :loading="loading"
          item-value="id"
          density="comfortable" hover :items-per-page="20"
        >
          <template #item.title="{ item }">
            <div class="d-flex align-center">
              <v-avatar :color="categoryColor(item)" size="32" class="mr-2" variant="tonal">
                <v-icon size="16" :color="categoryColor(item)">mdi-tag</v-icon>
              </v-avatar>
              <div>
                <div class="font-weight-medium">{{ item.title }}</div>
                <div class="text-caption text-medium-emphasis">{{ item.category_name || 'Uncategorized' }}</div>
              </div>
            </div>
          </template>
          <template #item.vendor="{ item }">
            <span>{{ item.vendor || item.supplier_name || '—' }}</span>
          </template>
          <template #item.amount="{ item }">
            <span class="font-weight-bold">{{ formatMoney(item.amount) }}</span>
          </template>
          <template #item.payment_method="{ item }">
            <v-chip size="x-small" variant="tonal" :color="paymentColor(item.payment_method)">
              <v-icon start size="12">{{ paymentIcon(item.payment_method) }}</v-icon>
              {{ item.payment_method }}
            </v-chip>
          </template>
          <template #item.expense_date="{ item }">
            {{ formatDate(item.expense_date) }}
          </template>
          <template #item.due_date="{ item }">
            <div v-if="item.due_date">
              {{ formatDate(item.due_date) }}
              <v-chip v-if="isExpenseOverdue(item)" size="x-small" color="error" variant="tonal" class="ml-1">
                Overdue
              </v-chip>
            </div>
            <span v-else class="text-medium-emphasis">—</span>
          </template>
          <template #item.status="{ item }">
            <v-chip :color="expenseStatusColor(item.status)" size="small" variant="tonal" class="text-capitalize">
              {{ (item.status || '').replace('_', ' ') }}
            </v-chip>
          </template>
          <template #item.actions="{ item }">
            <v-btn v-if="item.status === 'pending'" icon="mdi-check" variant="text" size="small"
                   color="success" @click="approveExpense(item)" />
            <v-btn v-if="item.status === 'pending'" icon="mdi-close" variant="text" size="small"
                   color="error" @click="rejectExpense(item)" />
            <v-btn v-if="item.status === 'approved'" icon="mdi-cash-check" variant="text" size="small"
                   color="primary" @click="markExpensePaid(item)" />
          </template>
          <template #no-data>
            <EmptyState icon="mdi-cash-clock" title="No expenses found"
                        message="Try widening the date range or adjusting filters." />
          </template>
        </v-data-table>
      </v-card>
    </template>

    <!-- ===================== TRANSACTIONS LEDGER ===================== -->
    <template v-if="tab === 'transactions'">
      <v-card flat rounded="xl" class="pa-3 mb-3" border>
        <v-row dense align="center">
          <v-col cols="12" md="5">
            <v-text-field v-model="ledgerSearch" prepend-inner-icon="mdi-magnify"
                          placeholder="Search description / reference…" density="comfortable"
                          variant="solo-filled" flat hide-details clearable />
          </v-col>
          <v-col cols="6" md="3">
            <v-select v-model="ledgerType" :items="ledgerTypeItems"
                      label="Type" density="comfortable" hide-details variant="outlined" />
          </v-col>
          <v-col cols="6" md="2">
            <v-select v-model="ledgerMethod" :items="ledgerMethodItems"
                      label="Method" density="comfortable" hide-details variant="outlined" />
          </v-col>
          <v-col cols="12" md="2" class="text-right">
            <v-chip color="primary" variant="tonal">{{ filteredLedger.length }} entries</v-chip>
          </v-col>
        </v-row>
      </v-card>

      <v-card flat rounded="xl" border>
        <v-data-table
          :headers="ledgerHeaders"
          :items="filteredLedger"
          :loading="loading"
          item-value="key"
          density="comfortable" hover :items-per-page="25"
          :sort-by="[{ key: 'date', order: 'desc' }]"
        >
          <template #item.type="{ item }">
            <v-chip :color="item.type === 'income' ? 'success' : 'error'" size="small" variant="tonal">
              <v-icon start size="14">{{ item.type === 'income' ? 'mdi-arrow-down-bold' : 'mdi-arrow-up-bold' }}</v-icon>
              {{ item.type === 'income' ? 'Income' : 'Expense' }}
            </v-chip>
          </template>
          <template #item.date="{ item }">
            <div>{{ formatDate(item.date) }}</div>
            <div class="text-caption text-medium-emphasis">{{ shortTime(item.date) }}</div>
          </template>
          <template #item.description="{ item }">
            <div class="font-weight-medium text-truncate" style="max-width:360px">{{ item.description }}</div>
            <div class="text-caption text-medium-emphasis">{{ item.source }}</div>
          </template>
          <template #item.method="{ item }">
            <v-chip size="x-small" variant="tonal" :color="paymentColor(item.method)">
              <v-icon start size="12">{{ paymentIcon(item.method) }}</v-icon>
              {{ item.method || '—' }}
            </v-chip>
          </template>
          <template #item.reference="{ item }">
            <span class="text-caption font-mono">{{ item.reference || '—' }}</span>
          </template>
          <template #item.amount="{ item }">
            <span class="font-weight-bold" :class="item.type === 'income' ? 'text-success' : 'text-error'">
              {{ item.type === 'income' ? '+' : '−' }} {{ formatMoney(item.amount) }}
            </span>
          </template>
          <template #no-data>
            <EmptyState icon="mdi-swap-vertical" title="No transactions"
                        message="No income or expense activity in this range." />
          </template>
        </v-data-table>
      </v-card>
    </template>

    <!-- ===================== P&L ===================== -->
    <template v-if="tab === 'pnl'">
      <v-row dense class="mb-3">
        <v-col cols="12" md="6">
          <v-card class="pa-4 h-100" rounded="xl" border>
            <div class="d-flex align-center mb-3">
              <v-icon color="success" class="mr-2">mdi-trending-up</v-icon>
              <div class="text-subtitle-1 font-weight-medium">Income</div>
              <v-spacer />
              <span class="text-h6 font-weight-bold text-success">{{ formatMoney(pnl.totalIncome) }}</span>
            </div>
            <v-table density="compact" class="pnl-table">
              <tbody>
                <tr v-for="row in pnl.incomeRows" :key="row.label">
                  <td>
                    <v-icon size="16" :color="row.color" class="mr-2">{{ row.icon }}</v-icon>
                    {{ row.label }}
                  </td>
                  <td class="text-right font-weight-medium">{{ formatMoney(row.amount) }}</td>
                  <td class="text-right text-caption text-medium-emphasis" style="width:80px">
                    {{ pnl.totalIncome ? Math.round(row.amount / pnl.totalIncome * 100) : 0 }}%
                  </td>
                </tr>
                <tr v-if="pnl.vat > 0" class="vat-row">
                  <td class="text-medium-emphasis">
                    <v-icon size="16" color="orange" class="mr-2">mdi-percent-outline</v-icon>
                    Less: VAT (per-item tax)
                  </td>
                  <td class="text-right text-medium-emphasis">− {{ formatMoney(pnl.vat) }}</td>
                  <td></td>
                </tr>
                <tr v-if="pnl.netRevenue > 0" class="net-rev-row">
                  <td class="font-weight-bold">Net revenue (ex-VAT)</td>
                  <td class="text-right font-weight-bold text-success">{{ formatMoney(pnl.netRevenue) }}</td>
                  <td></td>
                </tr>
                <tr v-if="!pnl.incomeRows.length">
                  <td colspan="3" class="text-center text-medium-emphasis py-3">No income recorded</td>
                </tr>
              </tbody>
            </v-table>
          </v-card>
        </v-col>
        <v-col cols="12" md="6">
          <v-card class="pa-4 h-100" rounded="xl" border>
            <div class="d-flex align-center mb-3">
              <v-icon color="error" class="mr-2">mdi-trending-down</v-icon>
              <div class="text-subtitle-1 font-weight-medium">Expenses</div>
              <v-spacer />
              <span class="text-h6 font-weight-bold text-error">{{ formatMoney(pnl.totalExpense) }}</span>
            </div>
            <v-table density="compact" class="pnl-table">
              <tbody>
                <tr v-for="row in pnl.expenseRows" :key="row.label">
                  <td>
                    <v-icon size="16" :color="row.color || 'error'" class="mr-2">mdi-tag</v-icon>
                    {{ row.label }}
                  </td>
                  <td class="text-right font-weight-medium">{{ formatMoney(row.amount) }}</td>
                  <td class="text-right text-caption text-medium-emphasis" style="width:80px">
                    {{ pnl.totalExpense ? Math.round(row.amount / pnl.totalExpense * 100) : 0 }}%
                  </td>
                </tr>
                <tr v-if="!pnl.expenseRows.length">
                  <td colspan="3" class="text-center text-medium-emphasis py-3">No expenses recorded</td>
                </tr>
              </tbody>
            </v-table>
          </v-card>
        </v-col>
      </v-row>

      <v-card class="pa-5 mb-3 net-card" rounded="xl">
        <v-row align="center">
          <v-col cols="12" md="3">
            <div class="text-overline text-medium-emphasis">Net profit / loss</div>
            <div class="text-h4 font-weight-bold" :class="pnl.net >= 0 ? 'text-success' : 'text-error'">
              {{ pnl.net >= 0 ? '' : '−' }}{{ formatMoney(Math.abs(pnl.net)) }}
            </div>
            <div class="text-caption text-medium-emphasis">
              {{ data?.range?.label }} · margin {{ pnl.margin.toFixed(1) }}%
            </div>
          </v-col>
          <v-col cols="6" md="3">
            <div class="text-caption text-medium-emphasis">Gross income</div>
            <div class="text-h6 font-weight-bold text-success">{{ formatMoney(pnl.totalIncome) }}</div>
          </v-col>
          <v-col cols="6" md="2">
            <div class="text-caption text-medium-emphasis">VAT (item tax)</div>
            <div class="text-h6 font-weight-bold text-warning">{{ formatMoney(pnl.vat) }}</div>
          </v-col>
          <v-col cols="6" md="2">
            <div class="text-caption text-medium-emphasis">Net revenue</div>
            <div class="text-h6 font-weight-bold">{{ formatMoney(pnl.netRevenue) }}</div>
          </v-col>
          <v-col cols="6" md="2">
            <div class="text-caption text-medium-emphasis">Expenses</div>
            <div class="text-h6 font-weight-bold text-error">{{ formatMoney(pnl.totalExpense) }}</div>
          </v-col>
        </v-row>
      </v-card>
    </template>

    <!-- ===================== BALANCE SHEET ===================== -->
    <template v-if="tab === 'balance'">
      <!-- Equation strip -->
      <v-card flat rounded="xl" class="mb-3 equation-card pa-4">
        <v-row align="center" dense>
          <v-col cols="12" md="3">
            <div class="text-overline text-medium-emphasis">As at</div>
            <div class="text-h6 font-weight-bold">{{ data?.range?.end || todayIso }}</div>
            <div class="text-caption text-medium-emphasis">{{ data?.range?.label }}</div>
          </v-col>
          <v-col cols="12" md="9">
            <v-row dense>
              <v-col cols="4">
                <div class="text-caption text-medium-emphasis">ASSETS</div>
                <div class="text-h5 font-weight-bold text-success">{{ formatMoney(balanceSheet.totals.assets) }}</div>
              </v-col>
              <v-col cols="4">
                <div class="text-caption text-medium-emphasis">LIABILITIES</div>
                <div class="text-h5 font-weight-bold text-error">{{ formatMoney(balanceSheet.totals.liabilities) }}</div>
              </v-col>
              <v-col cols="4">
                <div class="text-caption text-medium-emphasis">EQUITY</div>
                <div class="text-h5 font-weight-bold text-primary">{{ formatMoney(balanceSheet.totals.equity) }}</div>
              </v-col>
            </v-row>
            <v-progress-linear
              :model-value="balanceCheckPct" height="6" rounded class="mt-3"
              :color="balanceSheet.balanced ? 'success' : 'orange'" />
            <div class="text-caption mt-1" :class="balanceSheet.balanced ? 'text-success' : 'text-warning'">
              <v-icon size="14" class="mr-1">{{ balanceSheet.balanced ? 'mdi-check-circle' : 'mdi-alert' }}</v-icon>
              {{ balanceSheet.balanced
                ? 'Books balanced: Assets = Liabilities + Equity'
                : `Variance ${formatMoney(Math.abs(balanceSheet.variance))} — recorded as suspense / unposted` }}
            </div>
          </v-col>
        </v-row>
      </v-card>

      <v-row dense>
        <!-- ASSETS -->
        <v-col cols="12" md="6">
          <v-card flat rounded="xl" border class="h-100">
            <v-card-title class="d-flex align-center section-header section-success">
              <v-avatar color="success" size="36" class="mr-3"><v-icon color="white">mdi-bank</v-icon></v-avatar>
              <div>
                <div class="font-weight-bold">Assets</div>
                <div class="text-caption text-medium-emphasis">What the business owns</div>
              </div>
              <v-spacer />
              <span class="text-h6 font-weight-bold text-success">{{ formatMoney(balanceSheet.totals.assets) }}</span>
            </v-card-title>
            <v-divider />
            <v-list density="compact">
              <template v-for="group in balanceSheet.assets" :key="group.label">
                <v-list-subheader class="font-weight-bold">{{ group.label }}</v-list-subheader>
                <v-list-item v-for="row in group.rows" :key="row.label">
                  <template #prepend>
                    <v-icon :color="row.color || 'success'" size="20">{{ row.icon || 'mdi-circle-small' }}</v-icon>
                  </template>
                  <v-list-item-title class="text-body-2">{{ row.label }}</v-list-item-title>
                  <template #append>
                    <span class="font-weight-medium">{{ formatMoney(row.amount) }}</span>
                  </template>
                </v-list-item>
                <v-list-item class="subtotal-row">
                  <v-list-item-title class="font-weight-bold">Subtotal — {{ group.label }}</v-list-item-title>
                  <template #append>
                    <span class="font-weight-bold text-success">{{ formatMoney(group.subtotal) }}</span>
                  </template>
                </v-list-item>
              </template>
            </v-list>
          </v-card>
        </v-col>

        <!-- LIABILITIES + EQUITY -->
        <v-col cols="12" md="6">
          <v-card flat rounded="xl" border class="mb-3">
            <v-card-title class="d-flex align-center section-header section-error">
              <v-avatar color="error" size="36" class="mr-3"><v-icon color="white">mdi-cash-clock</v-icon></v-avatar>
              <div>
                <div class="font-weight-bold">Liabilities</div>
                <div class="text-caption text-medium-emphasis">What the business owes</div>
              </div>
              <v-spacer />
              <span class="text-h6 font-weight-bold text-error">{{ formatMoney(balanceSheet.totals.liabilities) }}</span>
            </v-card-title>
            <v-divider />
            <v-list density="compact">
              <template v-for="group in balanceSheet.liabilities" :key="group.label">
                <v-list-subheader class="font-weight-bold">{{ group.label }}</v-list-subheader>
                <v-list-item v-for="row in group.rows" :key="row.label">
                  <template #prepend>
                    <v-icon :color="row.color || 'error'" size="20">{{ row.icon || 'mdi-circle-small' }}</v-icon>
                  </template>
                  <v-list-item-title class="text-body-2">{{ row.label }}</v-list-item-title>
                  <template #append>
                    <span class="font-weight-medium">{{ formatMoney(row.amount) }}</span>
                  </template>
                </v-list-item>
                <v-list-item class="subtotal-row">
                  <v-list-item-title class="font-weight-bold">Subtotal — {{ group.label }}</v-list-item-title>
                  <template #append>
                    <span class="font-weight-bold text-error">{{ formatMoney(group.subtotal) }}</span>
                  </template>
                </v-list-item>
              </template>
            </v-list>
          </v-card>

          <v-card flat rounded="xl" border>
            <v-card-title class="d-flex align-center section-header section-primary">
              <v-avatar color="primary" size="36" class="mr-3"><v-icon color="white">mdi-chart-pie</v-icon></v-avatar>
              <div>
                <div class="font-weight-bold">Equity</div>
                <div class="text-caption text-medium-emphasis">Owner's stake</div>
              </div>
              <v-spacer />
              <span class="text-h6 font-weight-bold text-primary">{{ formatMoney(balanceSheet.totals.equity) }}</span>
            </v-card-title>
            <v-divider />
            <v-list density="compact">
              <v-list-item v-for="row in balanceSheet.equity" :key="row.label">
                <template #prepend>
                  <v-icon :color="row.color || 'primary'" size="20">{{ row.icon || 'mdi-circle-small' }}</v-icon>
                </template>
                <v-list-item-title class="text-body-2">{{ row.label }}</v-list-item-title>
                <template #append>
                  <span class="font-weight-medium" :class="row.amount < 0 ? 'text-error' : ''">{{ formatMoney(row.amount) }}</span>
                </template>
              </v-list-item>
            </v-list>
          </v-card>
        </v-col>
      </v-row>

      <!-- Liquidity ratios -->
      <v-card flat rounded="xl" border class="mt-3 pa-4">
        <div class="text-subtitle-1 font-weight-bold mb-3">
          <v-icon class="mr-2" color="indigo">mdi-finance</v-icon>Financial Health Ratios
        </div>
        <v-row dense>
          <v-col v-for="r in financialRatios" :key="r.label" cols="6" md="3">
            <v-card flat rounded="lg" class="pa-3" :class="`ratio-${r.tone}`">
              <div class="text-caption text-medium-emphasis">{{ r.label }}</div>
              <div class="text-h5 font-weight-bold mt-1">{{ r.value }}</div>
              <div class="text-caption" :class="`text-${r.tone}`">
                <v-icon size="14">{{ r.icon }}</v-icon> {{ r.hint }}
              </div>
            </v-card>
          </v-col>
        </v-row>
      </v-card>
    </template>

    <!-- ===================== GENERAL LEDGER ===================== -->
    <template v-if="tab === 'ledger'">
      <v-card flat rounded="xl" border class="mb-3 pa-3">
        <div class="d-flex flex-wrap align-center" style="gap:12px">
          <v-text-field v-model="glSearch" label="Search description / ref"
                        prepend-inner-icon="mdi-magnify" variant="outlined" density="comfortable"
                        hide-details style="min-width:240px" />
          <v-select v-model="glAccount" :items="glAccountOptions"
                    label="Account" variant="outlined" density="comfortable"
                    hide-details clearable style="min-width:220px" />
          <v-select v-model="glType" :items="glTypeOptions"
                    label="Source" variant="outlined" density="comfortable"
                    hide-details clearable style="min-width:180px" />
          <v-spacer />
          <v-chip color="success" variant="tonal" size="small" prepend-icon="mdi-arrow-down">
            DR: {{ formatMoney(glTotals.debit) }}
          </v-chip>
          <v-chip color="error" variant="tonal" size="small" prepend-icon="mdi-arrow-up">
            CR: {{ formatMoney(glTotals.credit) }}
          </v-chip>
          <v-chip :color="glTotals.balanced ? 'success' : 'orange'" variant="flat" size="small">
            {{ glTotals.balanced ? 'Balanced' : 'Variance ' + formatMoney(Math.abs(glTotals.variance)) }}
          </v-chip>
          <v-btn variant="text" prepend-icon="mdi-download" size="small"
                 @click="exportLedgerCsv">Export CSV</v-btn>
        </div>
      </v-card>

      <!-- Trial balance summary -->
      <v-card flat rounded="xl" border class="mb-3">
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
          <template #item.debit="{ item }">{{ item.debit ? formatMoney(item.debit) : '—' }}</template>
          <template #item.credit="{ item }">{{ item.credit ? formatMoney(item.credit) : '—' }}</template>
          <template #item.net="{ item }">
            <strong :class="item.net >= 0 ? '' : 'text-error'">{{ formatMoney(Math.abs(item.net)) }}</strong>
          </template>
        </v-data-table>
      </v-card>

      <!-- Journal entries -->
      <v-card flat rounded="xl" border>
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2" color="emerald-darken-2">mdi-book-open-page-variant</v-icon>
          <span class="font-weight-bold">Journal Entries</span>
          <v-spacer />
          <v-chip size="small" variant="tonal">{{ glFiltered.length }} entries</v-chip>
        </v-card-title>
        <v-data-table :headers="glHeaders" :items="glFiltered" :loading="loading"
                      items-per-page="25" density="comfortable" class="ledger-table">
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
            <strong v-if="item.debit > 0" class="text-success">{{ formatMoney(item.debit) }}</strong>
            <span v-else class="text-medium-emphasis">—</span>
          </template>
          <template #item.credit="{ item }">
            <strong v-if="item.credit > 0" class="text-error">{{ formatMoney(item.credit) }}</strong>
            <span v-else class="text-medium-emphasis">—</span>
          </template>
        </v-data-table>
      </v-card>

      <!-- ───────── Trial Balance Charts ───────── -->
      <v-row dense class="mt-3">
        <!-- Debit vs Credit per account -->
        <v-col cols="12" md="7">
          <v-card flat rounded="xl" border class="pa-4 h-100">
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
              <div v-for="r in trialBalance" :key="r.account" class="tb-bar-row">
                <div class="tb-bar-label">
                  <v-icon :color="r.color" size="16" class="mr-1">{{ r.icon }}</v-icon>
                  <span class="text-caption font-weight-medium">{{ r.account }}</span>
                </div>
                <div class="tb-bar-track">
                  <div class="tb-bar tb-bar-dr"
                       :style="{ width: barPct(r.debit) + '%' }"
                       :title="'Debit: ' + formatMoney(r.debit)">
                    <span v-if="r.debit > 0 && barPct(r.debit) > 12" class="tb-bar-text">
                      {{ formatMoney(r.debit) }}
                    </span>
                  </div>
                  <div class="tb-bar tb-bar-cr"
                       :style="{ width: barPct(r.credit) + '%' }"
                       :title="'Credit: ' + formatMoney(r.credit)">
                    <span v-if="r.credit > 0 && barPct(r.credit) > 12" class="tb-bar-text">
                      {{ formatMoney(r.credit) }}
                    </span>
                  </div>
                </div>
                <div class="tb-bar-net">
                  <v-chip size="x-small" variant="tonal"
                          :color="r.net >= 0 ? 'success' : 'error'">
                    {{ r.net >= 0 ? 'DR' : 'CR' }} {{ formatMoney(Math.abs(r.net)) }}
                  </v-chip>
                </div>
              </div>
            </div>
          </v-card>
        </v-col>

        <!-- Composition donut by account type -->
        <v-col cols="12" md="5">
          <v-card flat rounded="xl" border class="pa-4 h-100">
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
                  {{ formatMoney(tbComposition.total) }}
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
                    <span class="text-caption font-weight-bold mr-2">{{ formatMoney(seg.value) }}</span>
                    <v-chip size="x-small" variant="tonal" color="grey">{{ seg.pct.toFixed(1) }}%</v-chip>
                  </div>
                </div>
              </div>
            </div>
          </v-card>
        </v-col>

        <!-- Net Balance per account horizontal -->
        <v-col cols="12">
          <v-card flat rounded="xl" border class="pa-4">
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
              <div v-for="r in trialBalance" :key="r.account" class="tb-net-row">
                <div class="tb-net-label">
                  <v-icon :color="r.color" size="14" class="mr-1">{{ r.icon }}</v-icon>
                  <span class="text-caption">{{ r.account }}</span>
                </div>
                <div class="tb-net-track">
                  <div class="tb-net-axis"></div>
                  <div class="tb-net-bar"
                       :class="r.net >= 0 ? 'tb-net-dr' : 'tb-net-cr'"
                       :style="netBarStyle(r.net)">
                    <span class="tb-net-value">{{ formatMoney(Math.abs(r.net)) }}</span>
                  </div>
                </div>
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>
    </template>

    <!-- ===================== Record payment dialog ===================== -->
    <v-dialog v-model="payDialog" max-width="520" persistent>
      <v-card v-if="payTarget" rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon color="success" class="mr-2">mdi-cash-plus</v-icon>
          Record payment
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" size="small" @click="payDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pt-4">
          <div class="d-flex justify-space-between mb-2">
            <span class="text-caption text-medium-emphasis">Invoice</span>
            <span class="font-weight-medium">{{ payTarget.invoice_number }}</span>
          </div>
          <div class="d-flex justify-space-between mb-2">
            <span class="text-caption text-medium-emphasis">Patient</span>
            <span>{{ payTarget.patient_name || '—' }}</span>
          </div>
          <div class="d-flex justify-space-between mb-2">
            <span class="text-caption text-medium-emphasis">Total</span>
            <span class="font-weight-bold">{{ formatMoney(payTarget.total) }}</span>
          </div>
          <div class="d-flex justify-space-between mb-3">
            <span class="text-caption text-medium-emphasis">Outstanding balance</span>
            <span class="font-weight-bold text-error">{{ formatMoney(invoiceBalance(payTarget)) }}</span>
          </div>
          <v-divider class="mb-3" />
          <v-text-field v-model.number="payForm.amount" type="number" min="0" :max="invoiceBalance(payTarget)"
                        label="Amount *" variant="outlined" density="comfortable"
                        prepend-inner-icon="mdi-cash" :error-messages="payErrors.amount" />
          <v-select v-model="payForm.method" :items="paymentMethodItems"
                    label="Method *" variant="outlined" density="comfortable"
                    :error-messages="payErrors.method" />
          <v-text-field v-model="payForm.reference" label="Reference (M-Pesa code, cheque #…)"
                        variant="outlined" density="comfortable"
                        prepend-inner-icon="mdi-pound" />
          <v-textarea v-model="payForm.notes" label="Notes" variant="outlined"
                      density="comfortable" rows="2" auto-grow />
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-btn variant="text" @click="setFullAmount">Pay full balance</v-btn>
          <v-spacer />
          <v-btn variant="text" @click="payDialog = false">Cancel</v-btn>
          <v-btn color="success" variant="flat" :loading="saving" @click="recordPayment">
            Record payment
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Invoice detail -->
    <v-dialog v-model="invDetailDialog" max-width="640" scrollable>
      <v-card v-if="invDetail" rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon color="primary" class="mr-2">mdi-receipt-text</v-icon>
          {{ invDetail.invoice_number }}
          <v-chip class="ml-2" size="small" :color="invoiceStatusColor(invDetail.status)" variant="tonal">
            {{ invDetail.status }}
          </v-chip>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" size="small" @click="invDetailDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pt-4">
          <div class="d-flex justify-space-between mb-2">
            <span class="text-caption text-medium-emphasis">Patient</span>
            <span>{{ invDetail.patient_name || '—' }}</span>
          </div>
          <div class="d-flex justify-space-between mb-2">
            <span class="text-caption text-medium-emphasis">Created</span>
            <span>{{ formatDateTime(invDetail.created_at) }}</span>
          </div>
          <div class="d-flex justify-space-between mb-3">
            <span class="text-caption text-medium-emphasis">Due</span>
            <span>{{ invDetail.due_date ? formatDate(invDetail.due_date) : '—' }}</span>
          </div>
          <v-divider class="mb-3" />
          <div class="text-subtitle-2 mb-2">Line items</div>
          <v-table density="compact">
            <tbody>
              <tr v-for="(it, i) in (invDetail.items || [])" :key="i">
                <td>{{ it.description }}</td>
                <td class="text-right">{{ it.quantity }} × {{ formatMoney(it.unit_price) }}</td>
                <td class="text-right font-weight-medium">{{ formatMoney(it.total) }}</td>
              </tr>
            </tbody>
          </v-table>
          <v-divider class="my-3" />
          <div class="d-flex justify-space-between"><span>Subtotal</span><span>{{ formatMoney(invDetail.subtotal) }}</span></div>
          <div class="d-flex justify-space-between"><span>Tax</span><span>{{ formatMoney(invDetail.tax) }}</span></div>
          <div class="d-flex justify-space-between"><span>Discount</span><span>− {{ formatMoney(invDetail.discount) }}</span></div>
          <div class="d-flex justify-space-between font-weight-bold"><span>Total</span><span>{{ formatMoney(invDetail.total) }}</span></div>
          <div class="d-flex justify-space-between text-success"><span>Paid</span><span>{{ formatMoney(invDetail.amount_paid) }}</span></div>
          <div class="d-flex justify-space-between font-weight-bold text-error">
            <span>Balance</span><span>{{ formatMoney(invoiceBalance(invDetail)) }}</span>
          </div>

          <template v-if="invDetail.payments?.length">
            <v-divider class="my-3" />
            <div class="text-subtitle-2 mb-2">Payments</div>
            <v-list density="compact" class="pa-0">
              <v-list-item v-for="p in invDetail.payments" :key="p.id" class="px-0">
                <template #prepend>
                  <v-icon :color="paymentColor(p.method)">{{ paymentIcon(p.method) }}</v-icon>
                </template>
                <v-list-item-title class="text-body-2">{{ formatMoney(p.amount) }} · {{ p.method }}</v-list-item-title>
                <v-list-item-subtitle class="text-caption">
                  {{ formatDateTime(p.paid_at) }}{{ p.reference ? ' · ' + p.reference : '' }}
                </v-list-item-subtitle>
              </v-list-item>
            </v-list>
          </template>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="invDetailDialog = false">Close</v-btn>
          <v-btn v-if="invoiceBalance(invDetail) > 0" color="success" variant="flat"
                 prepend-icon="mdi-cash-plus"
                 @click="openPayDialog(invDetail); invDetailDialog = false">
            Record payment
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Custom range -->
    <v-dialog v-model="customDialog" max-width="400" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center ga-2 pa-4 pb-2">
          <v-avatar color="primary" variant="tonal" size="40" rounded="lg">
            <v-icon>mdi-calendar-range</v-icon>
          </v-avatar>
          <div>
            <div class="text-h6">Custom Date Range</div>
            <div class="text-caption text-medium-emphasis">Select start and end dates</div>
          </div>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-text-field v-model="customStart" type="date" label="Start *"
                        variant="outlined" density="comfortable" rounded="lg"
                        prepend-inner-icon="mdi-calendar-start" hide-details="auto" class="mb-3" />
          <v-text-field v-model="customEnd" type="date" label="End *"
                        variant="outlined" density="comfortable" rounded="lg"
                        prepend-inner-icon="mdi-calendar-end" hide-details="auto" :min="customStart" />
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-btn variant="text" @click="cancelCustom">Cancel</v-btn>
          <v-spacer />
          <v-btn color="primary" variant="flat" rounded="lg" prepend-icon="mdi-check"
                 :disabled="!customStart || !customEnd" @click="applyCustom">
            Apply
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.message }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import { formatMoney, formatDate, formatDateTime } from '~/utils/format'
import EmptyState from '~/components/EmptyState.vue'
import SparkArea from '~/components/SparkArea.vue'

const { $api } = useNuxtApp()
const route = useRoute()

const loading = ref(false)
const saving = ref(false)
const tab = ref(['overview', 'receivables', 'payables', 'transactions', 'pnl'].includes(route.query.tab)
  ? route.query.tab : 'overview')

watch(() => route.query.tab, (v) => {
  if (['overview', 'receivables', 'payables', 'transactions', 'pnl'].includes(v)) tab.value = v
})

// ────── Date range
const rangeKey = ref('30d')
const rangeChips = [
  { key: 'today', label: 'Today' },
  { key: 'yesterday', label: 'Yesterday' },
  { key: '7d', label: 'Last 7 days' },
  { key: '30d', label: 'Last 30 days' },
  { key: 'mtd', label: 'Month to date' },
  { key: '90d', label: 'Last 90 days' },
  { key: 'ytd', label: 'Year to date' },
  { key: 'custom', label: 'Custom' },
]
const rangeOptions = rangeChips
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
    case 'yesterday': return { start: iso(sub(1)), end: iso(sub(1)), label: 'Yesterday' }
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

watch(rangeKey, (v) => {
  if (v === 'custom') { customDialog.value = true; return }
  data.value.range = resolveRange()
  loadAll()
})

function applyCustom() {
  if (!customStart.value || !customEnd.value) return
  rangeKey.value = 'custom'
  customDialog.value = false
  data.value.range = resolveRange()
  loadAll()
}
function cancelCustom() {
  customDialog.value = false
  if (!customStart.value || !customEnd.value) {
    rangeKey.value = '30d'
  }
}
function resetRange() {
  customStart.value = ''
  customEnd.value = ''
  rangeKey.value = '30d'
}

// ────── Data sources
const sales = ref([])         // POS transactions (income)
const invoices = ref([])      // billing invoices
const payments = ref([])      // billing payments (income)
const expenses = ref([])      // expenses (outflow)
const creditSales = ref([])   // POS credit sales (receivables)
const apiBilling = ref(null)  // /usage-billing/dashboard/ response
const inventoryValuation = ref(null) // /reports/inventory-valuation/ snapshot

async function loadAll() {
  loading.value = true
  data.value.range = resolveRange()
  const { start, end } = data.value.range
  try {
    const params = { date_from: start, date_to: end, page_size: 500, ordering: '-created_at' }
    const [s, inv, pay, exp, cred, api, invVal] = await Promise.allSettled([
      $api.get('/pos/transactions/', { params: { ...params, status: 'completed' } }),
      $api.get('/billing/invoices/', { params: { page_size: 500, ordering: '-created_at' } }),
      $api.get('/billing/payments/', { params: { page_size: 500, ordering: '-paid_at' } }),
      $api.get('/expenses/expenses/', { params: { page_size: 500, ordering: '-expense_date' } }),
      $api.get('/pos/credits/', { params: { page_size: 500, ordering: '-created_at' } }),
      $api.get('/usage-billing/dashboard/'),
      $api.get('/reports/inventory-valuation/'),
    ])
    sales.value = pickRows(s)
    invoices.value = pickRows(inv)
    payments.value = pickRows(pay)
    expenses.value = pickRows(exp)
    creditSales.value = pickRows(cred)
    apiBilling.value = api.status === 'fulfilled' ? api.value?.data : null
    inventoryValuation.value = invVal.status === 'fulfilled' ? invVal.value?.data : null
  } catch (e) {
    notify('Failed to load accounts data', 'error')
  } finally {
    loading.value = false
  }
}

function pickRows(settled) {
  if (settled.status !== 'fulfilled') return []
  const d = settled.value?.data
  return d?.results || (Array.isArray(d) ? d : [])
}

onMounted(loadAll)

// ────── Derived: filter by date range (client-side for invoices/expenses)
const inRange = (iso) => {
  if (!iso) return false
  const d = String(iso).slice(0, 10)
  return d >= data.value.range.start && d <= data.value.range.end
}
const salesInRange = computed(() => sales.value.filter(s => inRange(s.created_at)))
const paymentsInRange = computed(() => payments.value.filter(p => inRange(p.paid_at)))
// Always use expense_date as the effective date.
const expenseEffectiveDate = (e) => e?.expense_date || null
const expensesInRange = computed(() => expenses.value.filter(e => inRange(expenseEffectiveDate(e))))
// Recognised expenses for KPIs/P&L: everything incurred except rejected/cancelled (accrual view).
const expensesPaidInRange = computed(() =>
  expensesInRange.value.filter(e => !['rejected', 'cancelled'].includes(e.status)))

// ────── API Usage & Billing → normalized as expense rows
// Past months come from `recent_bills`; current month is synthesized from `current_month.cost_so_far`.
const apiBillExpenses = computed(() => {
  const out = []
  const ab = apiBilling.value
  if (!ab) return out
  const today = new Date().toISOString().slice(0, 10)
  const currency = ab.rate?.currency || 'KSH'
  // Historical bills
  for (const b of (ab.recent_bills || [])) {
    const monthStart = `${b.year}-${String(b.month).padStart(2, '0')}-01`
    const status = b.status === 'PAID' ? 'paid' : (b.status === 'CANCELLED' ? 'cancelled' : 'approved')
    out.push({
      id: `apibill-${b.id}`,
      title: `API Usage — ${monthLabel(b.year, b.month)}`,
      vendor: 'AfyaOne Platform',
      category_name: 'API Usage & Billing',
      amount: Number(b.amount || 0),
      payment_method: 'bank_transfer',
      payment_reference: `Bill #${b.id}`,
      expense_date: monthStart,
      paid_at: b.paid_at,
      status,
      _virtual: true,
      _kind: 'api_bill',
    })
  }
  // Current month accrued so far
  const cm = ab.current_month
  if (cm && Number(cm.cost_so_far) > 0) {
    out.push({
      id: `apibill-current-${cm.year}-${cm.month}`,
      title: `API Usage — ${monthLabel(cm.year, cm.month)} (accruing)`,
      vendor: 'AfyaOne Platform',
      category_name: 'API Usage & Billing',
      amount: Number(cm.cost_so_far || 0),
      payment_method: 'bank_transfer',
      payment_reference: `${(cm.total_requests || 0).toLocaleString()} requests`,
      expense_date: `${cm.year}-${String(cm.month).padStart(2, '0')}-01`,
      due_date: null,
      status: 'pending',
      _virtual: true,
      _kind: 'api_bill_current',
      _projectedCost: Number(cm.projected_cost || 0),
    })
  }
  return out
})

function monthLabel(year, month) {
  try { return new Date(year, month - 1, 1).toLocaleString(undefined, { month: 'short', year: 'numeric' }) }
  catch { return `${year}-${month}` }
}

// API expenses recognised in current range (use expense_date inclusion)
const apiBillExpensesInRange = computed(() =>
  apiBillExpenses.value.filter(e => inRange(e.expense_date)
    && !['rejected', 'cancelled'].includes(e.status)))

// Convenience computed for the Overview API panel
const apiBillsOutstanding = computed(() =>
  apiBillExpenses.value.filter(e => ['pending', 'approved'].includes(e.status))
    .reduce((s, e) => s + Number(e.amount || 0), 0))
const apiBillsOutstandingCount = computed(() =>
  apiBillExpenses.value.filter(e => ['pending', 'approved'].includes(e.status)).length)
const apiDailyBurn = computed(() => {
  const cm = apiBilling.value?.current_month
  if (!cm) return 0
  const days = Math.max(1, Number(cm.days_elapsed || 1))
  return Number(cm.cost_so_far || 0) / days
})

// ────── KPI tiles
const totalSalesIncome = computed(() => sumBy(salesInRange.value, 'total'))
const totalPaymentsIncome = computed(() => sumBy(paymentsInRange.value, 'amount'))
const totalIncome = computed(() => totalSalesIncome.value + totalPaymentsIncome.value)
const totalExpensePaid = computed(() => sumBy(expensesPaidInRange.value, 'amount') + sumBy(apiBillExpensesInRange.value, 'amount'))
const netCash = computed(() => totalIncome.value - totalExpensePaid.value)
const outstandingReceivables = computed(() =>
  invoices.value.filter(i => invoiceBalance(i) > 0)
    .reduce((s, i) => s + invoiceBalance(i), 0)
  + creditSales.value.filter(c => Number(c.balance_amount || 0) > 0)
    .reduce((s, c) => s + Number(c.balance_amount || 0), 0))
const pendingPayables = computed(() =>
  expenses.value.filter(e => ['pending', 'approved'].includes(e.status))
    .reduce((s, e) => s + Number(e.amount || 0), 0)
  + apiBillExpenses.value.filter(e => ['pending', 'approved'].includes(e.status))
    .reduce((s, e) => s + Number(e.amount || 0), 0))

const kpiTiles = computed(() => [
  { label: 'Income', value: formatMoney(totalIncome.value), icon: 'mdi-arrow-down-bold-circle',
    color: 'success',
    sub: `${formatMoney(vatIncome.value)} VAT (per-item)`, trendClass: 'text-success' },
  { label: 'Expenses', value: formatMoney(totalExpensePaid.value), icon: 'mdi-arrow-up-bold-circle',
    color: 'error', sub: `${expensesPaidInRange.value.length} recorded`, trendClass: 'text-error' },
  { label: 'Net cash flow', value: formatMoney(netCash.value), icon: netCash.value >= 0 ? 'mdi-trending-up' : 'mdi-trending-down',
    color: netCash.value >= 0 ? 'teal' : 'orange',
    sub: `${data.value?.range?.label || ''}`,
    trendClass: netCash.value >= 0 ? 'text-success' : 'text-error' },
  { label: 'Outstanding', value: formatMoney(outstandingReceivables.value), icon: 'mdi-cash-fast',
    color: 'amber-darken-2',
    sub: `${creditSales.value.filter(c => Number(c.balance_amount || 0) > 0).length} credits · ${formatMoney(pendingPayables.value)} payables`, trendClass: 'text-medium-emphasis' },
])

// ────── Cash position by method
const cashByMethod = computed(() => {
  const map = new Map()
  const add = (k, v) => map.set(k || 'unknown', (map.get(k || 'unknown') || 0) + Number(v || 0))
  salesInRange.value.forEach(s => add(s.payment_method, s.total))
  paymentsInRange.value.forEach(p => add(p.method, p.amount))
  const total = [...map.values()].reduce((a, b) => a + b, 0) || 1
  return [...map.entries()].map(([k, v]) => ({
    key: k, label: (k || 'Unknown').replace('_', ' '),
    total: v, pct: Math.round(v / total * 100),
  })).sort((a, b) => b.total - a.total)
})

// ────── Cashflow trend (daily buckets)
const cashflowSeries = computed(() => {
  const start = new Date(data.value.range.start)
  const end = new Date(data.value.range.end)
  const days = Math.max(1, Math.round((end - start) / 86400000) + 1)
  const buckets = []
  for (let i = 0; i < days; i++) {
    const d = new Date(start); d.setDate(start.getDate() + i)
    buckets.push({ date: d.toISOString().slice(0, 10), income: 0, expense: 0 })
  }
  const idx = Object.fromEntries(buckets.map((b, i) => [b.date, i]))
  salesInRange.value.forEach(s => { const i = idx[String(s.created_at).slice(0, 10)]; if (i != null) buckets[i].income += Number(s.total || 0) })
  paymentsInRange.value.forEach(p => { const i = idx[String(p.paid_at).slice(0, 10)]; if (i != null) buckets[i].income += Number(p.amount || 0) })
  expensesPaidInRange.value.forEach(e => { const i = idx[String(expenseEffectiveDate(e)).slice(0, 10)]; if (i != null) buckets[i].expense += Number(e.amount || 0) })
  apiBillExpensesInRange.value.forEach(e => { const i = idx[String(e.expense_date).slice(0, 10)]; if (i != null) buckets[i].expense += Number(e.amount || 0) })
  return buckets
})

// ────── Receivables
const invSearch = ref('')
const invStatus = ref('outstanding')
const invSort = ref('balance_desc')
const invoiceStatusItems = [
  { title: 'Outstanding only', value: 'outstanding' },
  { title: 'All', value: 'all' },
  { title: 'Draft', value: 'draft' },
  { title: 'Sent', value: 'sent' },
  { title: 'Partially paid', value: 'partially_paid' },
  { title: 'Paid', value: 'paid' },
  { title: 'Overdue', value: 'overdue' },
  { title: 'Cancelled', value: 'cancelled' },
]
const invoiceSortItems = [
  { title: 'Balance ↓', value: 'balance_desc' },
  { title: 'Total ↓', value: 'total_desc' },
  { title: 'Newest', value: 'newest' },
  { title: 'Oldest', value: 'oldest' },
  { title: 'Due date', value: 'due' },
]
const invoiceHeaders = [
  { title: 'Invoice', key: 'invoice_number', sortable: true },
  { title: 'Patient', key: 'patient_name', sortable: true },
  { title: 'Total', key: 'total', sortable: true, align: 'end' },
  { title: 'Paid', key: 'amount_paid', sortable: true, align: 'end' },
  { title: 'Balance', key: 'balance', sortable: true, align: 'end' },
  { title: 'Due', key: 'due_date', sortable: true },
  { title: 'Status', key: 'status', sortable: true },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 100 },
]
function invoiceBalance(i) { return Number(i?.total || 0) - Number(i?.amount_paid || 0) }
function isOverdue(i) {
  if (!i?.due_date) return false
  if (['paid', 'cancelled'].includes(i.status)) return false
  return new Date(i.due_date) < new Date(new Date().toISOString().slice(0, 10))
}
function daysLate(i) {
  if (!isOverdue(i)) return 0
  return Math.floor((new Date() - new Date(i.due_date)) / 86400000)
}
function invoiceStatusColor(s) {
  return ({ draft: 'grey', sent: 'info', paid: 'success', partially_paid: 'amber', overdue: 'error', cancelled: 'grey' })[s] || 'grey'
}
const filteredInvoices = computed(() => {
  const q = (invSearch.value || '').toLowerCase().trim()
  let rows = invoices.value.filter(i => {
    if (invStatus.value === 'outstanding' && invoiceBalance(i) <= 0) return false
    if (!['outstanding', 'all'].includes(invStatus.value) && i.status !== invStatus.value) return false
    if (!q) return true
    return (i.invoice_number || '').toLowerCase().includes(q)
        || (i.patient_name || '').toLowerCase().includes(q)
  })
  const sorters = {
    balance_desc: (a, b) => invoiceBalance(b) - invoiceBalance(a),
    total_desc: (a, b) => Number(b.total) - Number(a.total),
    newest: (a, b) => (b.created_at || '').localeCompare(a.created_at || ''),
    oldest: (a, b) => (a.created_at || '').localeCompare(b.created_at || ''),
    due: (a, b) => (a.due_date || '9999').localeCompare(b.due_date || '9999'),
  }
  return [...rows].sort(sorters[invSort.value] || sorters.balance_desc)
})

const topReceivables = computed(() => {
  const fromInvoices = invoices.value.filter(i => invoiceBalance(i) > 0)
    .map(i => ({ ...i, _balance: invoiceBalance(i), _isOverdue: isOverdue(i), _daysLate: daysLate(i), _type: 'invoice' }))
  const fromCredit = creditSales.value.filter(c => Number(c.balance_amount || 0) > 0)
    .map(c => {
      const overdue = c.due_date && !['settled'].includes(c.status) && new Date(c.due_date) < new Date(new Date().toISOString().slice(0, 10))
      const late = overdue ? Math.floor((new Date() - new Date(c.due_date)) / 86400000) : 0
      return {
        ...c,
        _balance: Number(c.balance_amount),
        _isOverdue: overdue,
        _daysLate: late,
        _type: 'credit',
        invoice_number: c.transaction_number || `CR-${c.id}`,
        patient_name: c.customer_name,
      }
    })
  return [...fromInvoices, ...fromCredit]
    .sort((a, b) => b._balance - a._balance)
    .slice(0, 5)
})

const agingBuckets = computed(() => {
  const buckets = [
    { key: 'current', label: 'Not yet due', icon: 'mdi-calendar-clock', color: 'info', total: 0, count: 0 },
    { key: '1-30', label: '1-30 days', icon: 'mdi-calendar-alert', color: 'amber-darken-2', total: 0, count: 0 },
    { key: '31-60', label: '31-60 days', icon: 'mdi-alert', color: 'orange-darken-2', total: 0, count: 0 },
    { key: '60+', label: '60+ days', icon: 'mdi-alert-octagon', color: 'error', total: 0, count: 0 },
  ]
  // Invoice receivables
  invoices.value.filter(i => invoiceBalance(i) > 0).forEach(i => {
    const bal = invoiceBalance(i)
    if (!isOverdue(i)) { buckets[0].total += bal; buckets[0].count++; return }
    const d = daysLate(i)
    const idx = d <= 30 ? 1 : d <= 60 ? 2 : 3
    buckets[idx].total += bal; buckets[idx].count++
  })
  // Credit sale receivables
  const todayStr = new Date().toISOString().slice(0, 10)
  creditSales.value.filter(c => Number(c.balance_amount || 0) > 0).forEach(c => {
    const bal = Number(c.balance_amount)
    const overdue = c.due_date && !['settled'].includes(c.status) && c.due_date < todayStr
    if (!overdue) { buckets[0].total += bal; buckets[0].count++; return }
    const d = Math.floor((new Date() - new Date(c.due_date)) / 86400000)
    const idx = d <= 30 ? 1 : d <= 60 ? 2 : 3
    buckets[idx].total += bal; buckets[idx].count++
  })
  return buckets
})

// ────── Credit sales table
const creditHeaders = [
  { title: 'Receipt', key: 'transaction_number', sortable: true },
  { title: 'Customer', key: 'customer_name', sortable: true },
  { title: 'Total', key: 'total_amount', sortable: true, align: 'end' },
  { title: 'Paid', key: 'partial_paid_amount', sortable: true, align: 'end' },
  { title: 'Balance', key: 'balance_amount', sortable: true, align: 'end' },
  { title: 'Due', key: 'due_date', sortable: true },
  { title: 'Status', key: 'status', sortable: true },
]
const filteredCreditSales = computed(() => {
  const q = (invSearch.value || '').toLowerCase().trim()
  let rows = creditSales.value
  if (invStatus.value === 'outstanding') rows = rows.filter(c => Number(c.balance_amount || 0) > 0)
  if (q) rows = rows.filter(c =>
    (c.customer_name || '').toLowerCase().includes(q) ||
    (c.transaction_number || '').toLowerCase().includes(q) ||
    (c.customer_phone || '').toLowerCase().includes(q))
  return [...rows].sort((a, b) => Number(b.balance_amount || 0) - Number(a.balance_amount || 0))
})
function creditStatusColor(s) {
  return ({ open: 'info', partial: 'amber', settled: 'success', overdue: 'error' })[s] || 'grey'
}

// ────── Payables
const expSearch = ref('')
const expStatus = ref('open')
const expSort = ref('amount_desc')
const expenseStatusItems = [
  { title: 'Open (pending + approved)', value: 'open' },
  { title: 'All', value: 'all' },
  { title: 'Pending', value: 'pending' },
  { title: 'Approved', value: 'approved' },
  { title: 'Paid', value: 'paid' },
  { title: 'Rejected', value: 'rejected' },
  { title: 'Cancelled', value: 'cancelled' },
]
const expenseSortItems = [
  { title: 'Amount ↓', value: 'amount_desc' },
  { title: 'Newest', value: 'newest' },
  { title: 'Oldest', value: 'oldest' },
  { title: 'Due date', value: 'due' },
]
const expenseHeaders = [
  { title: 'Expense', key: 'title', sortable: true },
  { title: 'Vendor', key: 'vendor', sortable: false },
  { title: 'Amount', key: 'amount', sortable: true, align: 'end' },
  { title: 'Method', key: 'payment_method', sortable: false },
  { title: 'Date', key: 'expense_date', sortable: true },
  { title: 'Due', key: 'due_date', sortable: true },
  { title: 'Status', key: 'status', sortable: true },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 130 },
]
function isExpenseOverdue(e) {
  if (!e?.due_date) return false
  if (['paid', 'cancelled', 'rejected'].includes(e.status)) return false
  return new Date(e.due_date) < new Date(new Date().toISOString().slice(0, 10))
}
function expenseStatusColor(s) {
  return ({ pending: 'amber', approved: 'info', paid: 'success', rejected: 'error', cancelled: 'grey' })[s] || 'grey'
}
// ────── Combined expense list (real + virtual API bills) for Payables tab
const combinedExpenses = computed(() => [...expenses.value, ...apiBillExpenses.value])

const filteredExpenses = computed(() => {
  const q = (expSearch.value || '').toLowerCase().trim()
  let rows = combinedExpenses.value.filter(e => {
    if (expStatus.value === 'open' && !['pending', 'approved'].includes(e.status)) return false
    if (!['open', 'all'].includes(expStatus.value) && e.status !== expStatus.value) return false
    if (!q) return true
    return (e.title || '').toLowerCase().includes(q)
        || (e.vendor || '').toLowerCase().includes(q)
        || (e.supplier_name || '').toLowerCase().includes(q)
        || (e.reference || '').toLowerCase().includes(q)
        || (e.payment_reference || '').toLowerCase().includes(q)
  })
  const sorters = {
    amount_desc: (a, b) => Number(b.amount) - Number(a.amount),
    newest: (a, b) => (b.expense_date || '').localeCompare(a.expense_date || ''),
    oldest: (a, b) => (a.expense_date || '').localeCompare(b.expense_date || ''),
    due: (a, b) => (a.due_date || '9999').localeCompare(b.due_date || '9999'),
  }
  return [...rows].sort(sorters[expSort.value] || sorters.amount_desc)
})

const topPayables = computed(() =>
  combinedExpenses.value.filter(e => ['pending', 'approved'].includes(e.status))
    .sort((a, b) => Number(b.amount) - Number(a.amount))
    .slice(0, 5))

const payableBuckets = computed(() => {
  const open = combinedExpenses.value.filter(e => ['pending', 'approved'].includes(e.status))
  const pending = open.filter(e => e.status === 'pending')
  const approved = open.filter(e => e.status === 'approved')
  const overdue = open.filter(e => isExpenseOverdue(e))
  const paidAll = [...expensesPaidInRange.value, ...apiBillExpensesInRange.value.filter(e => e.status === 'paid')]
  return [
    { key: 'pending', label: 'Pending approval', icon: 'mdi-timer-sand', color: 'amber',
      total: sumBy(pending, 'amount'), count: pending.length },
    { key: 'approved', label: 'Approved (to pay)', icon: 'mdi-check', color: 'info',
      total: sumBy(approved, 'amount'), count: approved.length },
    { key: 'overdue', label: 'Overdue', icon: 'mdi-alert', color: 'error',
      total: sumBy(overdue, 'amount'), count: overdue.length },
    { key: 'paid_period', label: 'Recorded (in range)', icon: 'mdi-cash-check', color: 'success',
      total: sumBy(paidAll, 'amount'), count: paidAll.length },
  ]
})

// ────── Transactions ledger
const ledgerSearch = ref('')
const ledgerType = ref('all')
const ledgerMethod = ref('all')
const ledgerTypeItems = [
  { title: 'All', value: 'all' },
  { title: 'Income only', value: 'income' },
  { title: 'Expense only', value: 'expense' },
]
const ledgerMethodItems = computed(() => {
  const m = new Set(['all'])
  ledger.value.forEach(t => t.method && m.add(t.method))
  return [...m].map(v => ({ title: v === 'all' ? 'All methods' : v, value: v }))
})
const ledgerHeaders = [
  { title: 'Type', key: 'type', sortable: true, width: 110 },
  { title: 'Date', key: 'date', sortable: true },
  { title: 'Description', key: 'description', sortable: false },
  { title: 'Method', key: 'method', sortable: true },
  { title: 'Reference', key: 'reference', sortable: false },
  { title: 'Amount', key: 'amount', sortable: true, align: 'end' },
]

const ledger = computed(() => {
  const rows = []
  salesInRange.value.forEach(s => rows.push({
    key: `pos-${s.id}`, type: 'income', date: s.created_at,
    description: s.transaction_number + (s.customer_name ? ` · ${s.customer_name}` : ''),
    source: 'POS sale', method: s.payment_method,
    reference: s.payment_reference || s.transaction_number,
    amount: Number(s.total || 0),
  }))
  paymentsInRange.value.forEach(p => rows.push({
    key: `pay-${p.id}`, type: 'income', date: p.paid_at,
    description: `Invoice payment #${p.invoice}${p.received_by_name ? ' · ' + p.received_by_name : ''}`,
    source: 'Invoice payment', method: p.method,
    reference: p.reference, amount: Number(p.amount || 0),
  }))
  expensesPaidInRange.value.forEach(e => rows.push({
    key: `exp-${e.id}`, type: 'expense', date: e.paid_at || e.expense_date || e.created_at,
    description: e.title, source: e.category_name || 'Expense',
    method: e.payment_method, reference: e.payment_reference || e.reference,
    amount: Number(e.amount || 0),
  }))
  apiBillExpensesInRange.value.forEach(e => rows.push({
    key: `apibill-${e.id}`, type: 'expense', date: e.paid_at || e.expense_date,
    description: e.title, source: 'API Usage & Billing',
    method: e.payment_method, reference: e.payment_reference,
    amount: Number(e.amount || 0),
  }))
  return rows
})

const filteredLedger = computed(() => {
  const q = (ledgerSearch.value || '').toLowerCase().trim()
  return ledger.value.filter(t => {
    if (ledgerType.value !== 'all' && t.type !== ledgerType.value) return false
    if (ledgerMethod.value !== 'all' && t.method !== ledgerMethod.value) return false
    if (!q) return true
    return (t.description || '').toLowerCase().includes(q)
        || (t.reference || '').toLowerCase().includes(q)
        || (t.source || '').toLowerCase().includes(q)
  })
})

// ────── VAT (computed from per-item tax_percent stored in transaction.tax field)
const vatIncome = computed(() => sumBy(salesInRange.value, 'tax'))
const netIncomeExVat = computed(() => totalIncome.value - vatIncome.value)

// ────── P&L
const pnl = computed(() => {
  const incomeRows = []
  if (totalSalesIncome.value > 0)
    incomeRows.push({ label: 'POS sales (gross)', amount: totalSalesIncome.value, icon: 'mdi-cart', color: 'success' })
  if (totalPaymentsIncome.value > 0)
    incomeRows.push({ label: 'Invoice payments (gross)', amount: totalPaymentsIncome.value, icon: 'mdi-receipt', color: 'primary' })

  const grossIncome = incomeRows.reduce((s, r) => s + r.amount, 0)
  const vat = vatIncome.value
  const netRevenue = grossIncome - vat

  const byCat = new Map()
  expensesPaidInRange.value.forEach(e => {
    const k = e.category_name || 'Uncategorized'
    byCat.set(k, (byCat.get(k) || 0) + Number(e.amount || 0))
  })
  apiBillExpensesInRange.value.forEach(e => {
    const k = e.category_name || 'API Usage & Billing'
    byCat.set(k, (byCat.get(k) || 0) + Number(e.amount || 0))
  })
  const expenseRows = [...byCat.entries()]
    .sort((a, b) => b[1] - a[1])
    .map(([label, amount]) => ({ label, amount }))

  const totalExpense = expenseRows.reduce((s, r) => s + r.amount, 0)
  const net = netRevenue - totalExpense
  const margin = netRevenue > 0 ? (net / netRevenue) * 100 : 0
  return { incomeRows, expenseRows, totalIncome: grossIncome, vat, netRevenue, totalExpense, net, margin }
})

// ────── Record payment dialog
const payDialog = ref(false)
const payTarget = ref(null)
const payForm = reactive({ amount: 0, method: 'cash', reference: '', notes: '' })
const payErrors = reactive({})
const paymentMethodItems = [
  { title: 'Cash', value: 'cash' },
  { title: 'M-Pesa', value: 'mpesa' },
  { title: 'Card', value: 'card' },
  { title: 'Bank Transfer', value: 'bank_transfer' },
  { title: 'Insurance', value: 'insurance' },
]
function openPayDialog(inv) {
  if (!inv) return
  payTarget.value = inv
  Object.assign(payForm, { amount: invoiceBalance(inv), method: 'cash', reference: '', notes: '' })
  Object.keys(payErrors).forEach(k => delete payErrors[k])
  payDialog.value = true
}
function setFullAmount() { payForm.amount = invoiceBalance(payTarget.value) }
async function recordPayment() {
  Object.keys(payErrors).forEach(k => delete payErrors[k])
  if (!payForm.amount || payForm.amount <= 0) { payErrors.amount = 'Enter an amount > 0'; return }
  if (payForm.amount > invoiceBalance(payTarget.value)) { payErrors.amount = 'Cannot exceed outstanding balance'; return }
  if (!payForm.method) { payErrors.method = 'Select a method'; return }
  saving.value = true
  try {
    await $api.post(`/billing/invoices/${payTarget.value.id}/record_payment/`, payForm)
    notify('Payment recorded')
    payDialog.value = false
    await loadAll()
  } catch (e) {
    notify(extractError(e) || 'Failed to record payment', 'error')
  } finally { saving.value = false }
}

// ────── Invoice detail
const invDetailDialog = ref(false)
const invDetail = ref(null)
async function openInvoiceDetail(inv) {
  invDetail.value = inv
  invDetailDialog.value = true
  try {
    const { data: full } = await $api.get(`/billing/invoices/${inv.id}/`)
    invDetail.value = full
  } catch { /* keep summary */ }
}

// ────── Expense actions
async function approveExpense(e) {
  saving.value = true
  try {
    await $api.post(`/expenses/expenses/${e.id}/approve/`)
    notify('Expense approved')
    await loadAll()
  } catch (err) { notify(extractError(err) || 'Approve failed', 'error') }
  finally { saving.value = false }
}
async function rejectExpense(e) {
  saving.value = true
  try {
    await $api.post(`/expenses/expenses/${e.id}/reject/`)
    notify('Expense rejected')
    await loadAll()
  } catch (err) { notify(extractError(err) || 'Reject failed', 'error') }
  finally { saving.value = false }
}
async function markExpensePaid(e) {
  saving.value = true
  try {
    await $api.post(`/expenses/expenses/${e.id}/mark_paid/`, { payment_method: e.payment_method })
    notify('Marked as paid')
    await loadAll()
  } catch (err) { notify(extractError(err) || 'Failed to mark paid', 'error') }
  finally { saving.value = false }
}

// ────── Helpers
function sumBy(arr, key) { return arr.reduce((s, x) => s + Number(x?.[key] || 0), 0) }
function paymentColor(m) {
  return ({ cash: 'success', mpesa: 'green', card: 'indigo', credit: 'orange',
    insurance: 'purple', bank: 'blue', bank_transfer: 'blue', cheque: 'teal', other: 'grey' })[(m || '').toLowerCase()] || 'grey'
}
function paymentIcon(m) {
  return ({ cash: 'mdi-cash', mpesa: 'mdi-cellphone', card: 'mdi-credit-card-outline',
    credit: 'mdi-account-credit-card-outline', insurance: 'mdi-shield-account',
    bank: 'mdi-bank', bank_transfer: 'mdi-bank-transfer', cheque: 'mdi-checkbook', other: 'mdi-help-circle' })[(m || '').toLowerCase()] || 'mdi-cash'
}
function categoryColor(e) {
  if (e.category_color) return e.category_color
  const palette = ['indigo', 'teal', 'pink', 'orange', 'cyan', 'green', 'purple', 'amber']
  let h = 0
  for (const ch of (e.category_name || '')) h = (h * 31 + ch.charCodeAt(0)) >>> 0
  return palette[h % palette.length]
}
function initials(n) { if (!n) return '?'; return n.split(/\s+/).filter(Boolean).slice(0, 2).map(s => s[0].toUpperCase()).join('') }
function avatarColor(name) {
  const palette = ['primary', 'indigo', 'teal', 'deep-purple', 'pink', 'orange', 'cyan', 'green']
  let h = 0
  for (const ch of (name || '')) h = (h * 31 + ch.charCodeAt(0)) >>> 0
  return palette[h % palette.length]
}
function shortTime(iso) { try { return new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) } catch { return '' } }
function extractError(e) {
  const d = e?.response?.data
  if (!d) return e?.message || ''
  if (typeof d === 'string') return d
  if (d.detail) return d.detail
  return Object.entries(d).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(' ') : v}`).join(' · ')
}

// ────── Snackbar
const snack = reactive({ show: false, color: 'success', message: '' })
function notify(message, color = 'success') { Object.assign(snack, { show: true, color, message }) }

// ────── CSV exports
function downloadCsv(name, header, rows) {
  if (!rows.length) { notify('Nothing to export', 'warning'); return }
  const lines = [header.join(',')]
  rows.forEach(r => lines.push(r.map(c => typeof c === 'string' ? JSON.stringify(c) : c).join(',')))
  const blob = new Blob([lines.join('\n')], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = `${name}-${new Date().toISOString().slice(0, 10)}.csv`; a.click()
  URL.revokeObjectURL(url)
}
function exportCsv(kind) {
  if (kind === 'pnl') {
    const rows = [
      ['Income', '', ''],
      ...pnl.value.incomeRows.map(r => [r.label, r.amount, '']),
      ['Total gross income', pnl.value.totalIncome, ''],
      ['Less: VAT (per-item tax)', -pnl.value.vat, ''],
      ['Net revenue (ex-VAT)', pnl.value.netRevenue, ''],
      ['', '', ''],
      ['Expenses', '', ''],
      ...pnl.value.expenseRows.map(r => [r.label, r.amount, '']),
      ['Total expenses', pnl.value.totalExpense, ''],
      ['', '', ''],
      ['Net profit / loss', pnl.value.net, `${pnl.value.margin.toFixed(1)}%`],
    ]
    downloadCsv('profit-loss', ['Item', 'Amount', 'Margin'], rows)
  } else if (kind === 'ledger') {
    downloadCsv('transactions', ['Type', 'Date', 'Description', 'Source', 'Method', 'Reference', 'Amount'],
      filteredLedger.value.map(t => [t.type, t.date, t.description, t.source, t.method || '', t.reference || '', t.amount]))
  } else if (kind === 'receivables') {
    downloadCsv('receivables', ['Invoice', 'Patient', 'Total', 'Paid', 'Balance', 'Due', 'Status'],
      filteredInvoices.value.map(i => [i.invoice_number, i.patient_name || '', i.total, i.amount_paid, invoiceBalance(i), i.due_date || '', i.status]))
  } else if (kind === 'payables') {
    downloadCsv('payables', ['Title', 'Vendor', 'Amount', 'Method', 'Date', 'Due', 'Status'],
      filteredExpenses.value.map(e => [e.title, e.vendor || e.supplier_name || '', e.amount, e.payment_method, e.expense_date, e.due_date || '', e.status]))
  }
}

// ════════════════ BALANCE SHEET ════════════════
const todayIso = new Date().toISOString().slice(0, 10)

// Cash position derived from POS sales + payments by method (within range)
const cashByMethodAll = computed(() => {
  const m = new Map()
  const add = (k, v) => m.set((k || 'other').toLowerCase(), (m.get((k || 'other').toLowerCase()) || 0) + Number(v || 0))
  salesInRange.value.forEach(s => add(s.payment_method, s.total))
  paymentsInRange.value.forEach(p => add(p.method, p.amount))
  return m
})

const balanceSheet = computed(() => {
  const cm = cashByMethodAll.value
  const cashOnHand = (cm.get('cash') || 0)
  const mobileMoney = (cm.get('mpesa') || 0) + (cm.get('mobile_money') || 0)
  const bank = (cm.get('bank') || 0) + (cm.get('bank_transfer') || 0) + (cm.get('cheque') || 0) + (cm.get('card') || 0)
  const insuranceFloat = (cm.get('insurance') || 0)

  const cashGroup = {
    label: 'Current Assets — Cash & Equivalents',
    rows: [
      { label: 'Cash on hand (till)', amount: cashOnHand, icon: 'mdi-cash', color: 'success' },
      { label: 'Mobile money (M-Pesa)', amount: mobileMoney, icon: 'mdi-cellphone', color: 'green' },
      { label: 'Bank & cards', amount: bank, icon: 'mdi-bank', color: 'blue' },
      { label: 'Insurance receipts in transit', amount: insuranceFloat, icon: 'mdi-shield-account', color: 'purple' },
    ].filter(r => r.amount > 0),
  }
  cashGroup.subtotal = cashGroup.rows.reduce((s, r) => s + r.amount, 0)

  const ar = invoices.value.filter(i => invoiceBalance(i) > 0).reduce((s, i) => s + invoiceBalance(i), 0)
  const arOverdue = invoices.value.filter(i => isOverdue(i)).reduce((s, i) => s + invoiceBalance(i), 0)

  // POS credit sale receivables
  const todayStr = new Date().toISOString().slice(0, 10)
  const creditAr = creditSales.value.filter(c => Number(c.balance_amount || 0) > 0).reduce((s, c) => s + Number(c.balance_amount), 0)
  const creditArOverdue = creditSales.value.filter(c => Number(c.balance_amount || 0) > 0 && c.due_date && c.due_date < todayStr)
    .reduce((s, c) => s + Number(c.balance_amount), 0)

  const arGroup = {
    label: 'Accounts Receivable',
    rows: [
      { label: 'Customer invoices (current)', amount: Math.max(0, ar - arOverdue), icon: 'mdi-receipt-text', color: 'amber-darken-2' },
      { label: 'Overdue invoice receivables', amount: arOverdue, icon: 'mdi-clock-alert', color: 'error' },
      { label: 'POS credit sales (current)', amount: Math.max(0, creditAr - creditArOverdue), icon: 'mdi-account-credit-card', color: 'orange' },
      { label: 'Overdue credit receivables', amount: creditArOverdue, icon: 'mdi-clock-alert', color: 'red-darken-2' },
    ].filter(r => r.amount > 0),
  }
  arGroup.subtotal = arGroup.rows.reduce((s, r) => s + r.amount, 0)

  const invCost = Number(inventoryValuation.value?.cost_value || 0)
  const invSale = Number(inventoryValuation.value?.sale_value || inventoryValuation.value?.potential_revenue || 0)
  const invGroup = {
    label: 'Inventory',
    rows: [
      { label: 'Inventory at cost', amount: invCost, icon: 'mdi-package-variant', color: 'blue-darken-2' },
      ...(invSale > invCost ? [{ label: 'Potential margin (memo)', amount: invSale - invCost, icon: 'mdi-trending-up', color: 'success' }] : []),
    ].filter(r => r.amount > 0),
  }
  invGroup.subtotal = invCost // only cost counts as asset value

  const assets = [cashGroup, arGroup, invGroup].filter(g => g.rows.length)
  const totalAssets = cashGroup.subtotal + arGroup.subtotal + invGroup.subtotal

  // Liabilities
  const apPending = expenses.value.filter(e => ['pending', 'approved'].includes(e.status)).reduce((s, e) => s + Number(e.amount || 0), 0)
  const apOverdue = expenses.value.filter(e => {
    if (!['pending', 'approved'].includes(e.status)) return false
    if (!e.due_date) return false
    return new Date(e.due_date) < new Date(todayIso)
  }).reduce((s, e) => s + Number(e.amount || 0), 0)
  const apiBillsDue = apiBillExpenses.value.filter(e => ['pending', 'approved'].includes(e.status))
    .reduce((s, e) => s + Number(e.amount || 0), 0)
  const vatPayable = vatIncome.value

  const apGroup = {
    label: 'Accounts Payable',
    rows: [
      { label: 'Vendor invoices (current)', amount: Math.max(0, apPending - apOverdue), icon: 'mdi-truck', color: 'orange' },
      { label: 'Overdue payables', amount: apOverdue, icon: 'mdi-alert', color: 'error' },
      { label: 'API & SaaS bills', amount: apiBillsDue, icon: 'mdi-api', color: 'indigo' },
    ].filter(r => r.amount > 0),
  }
  apGroup.subtotal = apGroup.rows.reduce((s, r) => s + r.amount, 0)

  const taxGroup = {
    label: 'Tax Liabilities',
    rows: [
      { label: 'VAT collected (per-item tax)', amount: vatPayable, icon: 'mdi-percent', color: 'orange-darken-2' },
    ].filter(r => r.amount > 0),
  }
  taxGroup.subtotal = taxGroup.rows.reduce((s, r) => s + r.amount, 0)

  const liabilities = [apGroup, taxGroup].filter(g => g.rows.length)
  const totalLiabilities = apGroup.subtotal + taxGroup.subtotal

  // Equity = Assets - Liabilities (computed). Show retained earnings = period net.
  const retained = pnl.value.net
  const computedEquity = totalAssets - totalLiabilities
  const openingCapital = computedEquity - retained
  const equity = [
    { label: 'Opening capital (derived)', amount: openingCapital, icon: 'mdi-flag', color: 'primary' },
    { label: 'Retained earnings (period)', amount: retained, icon: retained >= 0 ? 'mdi-trending-up' : 'mdi-trending-down', color: retained >= 0 ? 'success' : 'error' },
  ]
  const totalEquity = openingCapital + retained
  const variance = totalAssets - (totalLiabilities + totalEquity)

  return {
    assets, liabilities, equity,
    totals: { assets: totalAssets, liabilities: totalLiabilities, equity: totalEquity },
    variance, balanced: Math.abs(variance) < 1,
  }
})

const balanceCheckPct = computed(() => {
  const a = balanceSheet.value.totals.assets
  const le = balanceSheet.value.totals.liabilities + balanceSheet.value.totals.equity
  if (!a) return 0
  return Math.min(100, Math.round((Math.min(a, le) / Math.max(a, le)) * 100))
})

const financialRatios = computed(() => {
  const t = balanceSheet.value.totals
  const currentAssets = (balanceSheet.value.assets[0]?.subtotal || 0) + (balanceSheet.value.assets[1]?.subtotal || 0)
  const currentLiab = (balanceSheet.value.liabilities[0]?.subtotal || 0) + (balanceSheet.value.liabilities[1]?.subtotal || 0)
  const currentRatio = currentLiab ? currentAssets / currentLiab : null
  const debtEquity = t.equity ? t.liabilities / t.equity : null
  const grossMargin = totalIncome.value ? (pnl.value.net / pnl.value.netRevenue) * 100 : 0
  const arDays = totalIncome.value ? (outstandingReceivables.value / (totalIncome.value || 1)) * 30 : 0
  return [
    { label: 'Current Ratio', value: currentRatio == null ? '—' : currentRatio.toFixed(2),
      tone: currentRatio == null ? 'medium-emphasis' : currentRatio >= 1.5 ? 'success' : currentRatio >= 1 ? 'warning' : 'error',
      icon: currentRatio >= 1 ? 'mdi-check' : 'mdi-alert',
      hint: currentRatio == null ? 'No data' : currentRatio >= 1.5 ? 'Healthy liquidity' : 'Watch liquidity' },
    { label: 'Debt / Equity', value: debtEquity == null ? '—' : debtEquity.toFixed(2),
      tone: debtEquity == null ? 'medium-emphasis' : debtEquity <= 1 ? 'success' : debtEquity <= 2 ? 'warning' : 'error',
      icon: 'mdi-scale-balance',
      hint: debtEquity == null ? '' : debtEquity <= 1 ? 'Low leverage' : 'High leverage' },
    { label: 'Net Margin', value: grossMargin.toFixed(1) + '%',
      tone: grossMargin >= 15 ? 'success' : grossMargin >= 0 ? 'warning' : 'error',
      icon: grossMargin >= 0 ? 'mdi-trending-up' : 'mdi-trending-down',
      hint: grossMargin >= 15 ? 'Strong margin' : grossMargin >= 0 ? 'Thin margin' : 'Loss-making' },
    { label: 'AR Days (est.)', value: Math.round(arDays) + 'd',
      tone: arDays <= 30 ? 'success' : arDays <= 60 ? 'warning' : 'error',
      icon: 'mdi-clock-outline',
      hint: arDays <= 30 ? 'Collected promptly' : 'Slow collection' },
  ]
})

// ════════════════ GENERAL LEDGER ════════════════
const ACC = {
  CASH:      { name: '1000 · Cash & Bank',          color: 'success', icon: 'mdi-bank',           type: 'asset' },
  AR:        { name: '1100 · Accounts Receivable',  color: 'amber-darken-2', icon: 'mdi-receipt-text', type: 'asset' },
  INVENTORY: { name: '1200 · Inventory',            color: 'blue',    icon: 'mdi-package-variant', type: 'asset' },
  AP:        { name: '2000 · Accounts Payable',     color: 'orange',  icon: 'mdi-truck',          type: 'liability' },
  VAT:       { name: '2100 · VAT Payable',          color: 'orange-darken-2', icon: 'mdi-percent',  type: 'liability' },
  REVENUE:   { name: '4000 · Sales Revenue',        color: 'success', icon: 'mdi-cash-multiple',  type: 'income' },
  COGS:      { name: '5000 · Cost of Goods Sold',   color: 'red',     icon: 'mdi-cart-minus',     type: 'expense' },
  EXPENSE:   { name: '6000 · Operating Expenses',   color: 'red-darken-1', icon: 'mdi-tag',       type: 'expense' },
}

const glSearch = ref('')
const glAccount = ref(null)
const glType = ref(null)

const glAccountOptions = Object.values(ACC).map(a => ({ title: a.name, value: a.name }))
const glTypeOptions = [
  { title: 'POS Sale', value: 'POS' },
  { title: 'Invoice', value: 'INV' },
  { title: 'Payment', value: 'PAY' },
  { title: 'Expense', value: 'EXP' },
  { title: 'Credit Payment', value: 'CRPAY' },
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

function jentry(date, source, sourceColor, reference, description, account, debit, credit, party = '') {
  return {
    date: String(date || todayIso).slice(0, 10),
    source, source_color: sourceColor, reference, description, party,
    account: account.name, account_color: account.color, account_meta: account,
    debit: Number(debit || 0), credit: Number(credit || 0),
  }
}

const journalEntries = computed(() => {
  const entries = []
  // POS Sales: DR Cash/AR, CR Revenue (split VAT from per-item tax)
  // Build credit sale lookup by transaction id for credit split
  const creditByTxn = new Map()
  creditSales.value.forEach(c => { if (c.transaction) creditByTxn.set(c.transaction, c) })

  salesInRange.value.forEach(s => {
    const total = Number(s.total || 0)
    const vat = Number(s.tax || 0)
    const net = total - vat
    const ref = s.transaction_number || s.reference || `POS-${s.id}`
    const isCredit = s.payment_method === 'credit'
    const credit = isCredit ? creditByTxn.get(s.id) : null
    if (isCredit && credit) {
      const paidUpfront = Number(credit.partial_paid_amount || 0)
      const balance = Number(credit.balance_amount || 0)
      if (paidUpfront > 0) {
        const pm = credit.partial_payment_method || 'cash'
        entries.push(jentry(s.created_at, 'POS', 'green', ref, `POS credit sale – upfront (${pm})`, ACC.CASH, paidUpfront, 0))
      }
      if (balance > 0) {
        entries.push(jentry(s.created_at, 'POS', 'orange', ref, `POS credit sale – receivable (${credit.customer_name})`, ACC.AR, balance, 0, credit.customer_name))
      }
    } else {
      entries.push(jentry(s.created_at, 'POS', 'green', ref, `POS sale (${s.payment_method || 'cash'})`, ACC.CASH, total, 0))
    }
    entries.push(jentry(s.created_at, 'POS', 'green', ref, 'Sales revenue (ex-VAT)', ACC.REVENUE, 0, net))
    if (vat > 0) entries.push(jentry(s.created_at, 'POS', 'green', ref, 'VAT collected', ACC.VAT, 0, vat))
  })
  // Invoices issued: DR AR, CR Revenue (only those in range, treat as accrual)
  invoices.value.filter(i => inRange(i.created_at) && !['cancelled', 'draft'].includes(i.status)).forEach(i => {
    const total = Number(i.total || 0)
    const vat = Number(i.tax || 0)
    const net = total - vat
    const ref = i.invoice_number
    entries.push(jentry(i.created_at, 'INV', 'amber', ref, `Invoice issued`, ACC.AR, total, 0, i.patient_name))
    entries.push(jentry(i.created_at, 'INV', 'amber', ref, 'Sales revenue (ex-VAT)', ACC.REVENUE, 0, net, i.patient_name))
    if (vat > 0) entries.push(jentry(i.created_at, 'INV', 'amber', ref, 'VAT collected', ACC.VAT, 0, vat))
  })
  // Payments received: DR Cash, CR AR
  paymentsInRange.value.forEach(p => {
    const amt = Number(p.amount || 0)
    const ref = p.reference || `PAY-${p.id}`
    entries.push(jentry(p.paid_at, 'PAY', 'blue', ref, `Payment received (${p.method || 'cash'})`, ACC.CASH, amt, 0, p.payer_name))
    entries.push(jentry(p.paid_at, 'PAY', 'blue', ref, 'Settlement against AR', ACC.AR, 0, amt, p.payer_name))
  })
  // Expenses: DR Expense, CR Cash (paid) or AP (pending)
  expensesPaidInRange.value.forEach(e => {
    const amt = Number(e.amount || 0)
    const date = expenseEffectiveDate(e)
    const ref = e.reference || `EXP-${e.id}`
    entries.push(jentry(date, 'EXP', 'red', ref, `${e.title} (${e.category_name || 'misc'})`, ACC.EXPENSE, amt, 0, e.vendor || e.supplier_name))
    entries.push(jentry(date, 'EXP', 'red', ref, `Paid via ${e.payment_method || 'cash'}`, ACC.CASH, 0, amt, e.vendor || e.supplier_name))
  })
  expenses.value.filter(e => inRange(e.expense_date) && ['pending', 'approved'].includes(e.status)).forEach(e => {
    const amt = Number(e.amount || 0)
    const ref = e.reference || `EXP-${e.id}`
    entries.push(jentry(e.expense_date, 'EXP', 'orange', ref, `${e.title} (accrued)`, ACC.EXPENSE, amt, 0, e.vendor || e.supplier_name))
    entries.push(jentry(e.expense_date, 'EXP', 'orange', ref, 'Vendor payable', ACC.AP, 0, amt, e.vendor || e.supplier_name))
  })

  return entries.sort((a, b) => (b.date > a.date ? 1 : -1))
})

const glFiltered = computed(() => {
  const q = glSearch.value.toLowerCase().trim()
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
  const debit = glFiltered.value.reduce((s, e) => s + e.debit, 0)
  const credit = glFiltered.value.reduce((s, e) => s + e.credit, 0)
  return { debit, credit, variance: debit - credit, balanced: Math.abs(debit - credit) < 1 }
})

const trialBalance = computed(() => {
  const m = new Map()
  journalEntries.value.forEach(e => {
    const key = e.account
    const cur = m.get(key) || { account: e.account, debit: 0, credit: 0, color: e.account_color, icon: e.account_meta.icon, type: e.account_meta.type }
    cur.debit += e.debit
    cur.credit += e.credit
    m.set(key, cur)
  })
  return [...m.values()].map(r => ({ ...r, net: r.debit - r.credit }))
    .sort((a, b) => a.account.localeCompare(b.account))
})

function exportLedgerCsv() {
  downloadCsv('general-ledger',
    ['Date', 'Source', 'Reference', 'Description', 'Party', 'Account', 'Debit', 'Credit'],
    glFiltered.value.map(e => [e.date, e.source, e.reference, e.description, e.party, e.account, e.debit, e.credit]))
}

// ────── Trial Balance chart helpers
const tbMaxValue = computed(() =>
  Math.max(1, ...trialBalance.value.flatMap(r => [r.debit, r.credit])))
function barPct(v) {
  return Math.min(100, (Number(v || 0) / tbMaxValue.value) * 100)
}
const tbNetMax = computed(() =>
  Math.max(1, ...trialBalance.value.map(r => Math.abs(r.net))))
function netBarStyle(net) {
  const pct = Math.min(48, (Math.abs(net) / tbNetMax.value) * 48)
  return net >= 0
    ? { left: '50%', width: pct + '%' }
    : { right: '50%', width: pct + '%' }
}

const TYPE_COLORS = {
  asset:     '#10b981',
  liability: '#f97316',
  income:    '#3b82f6',
  expense:   '#ef4444',
  equity:    '#8b5cf6',
}
const TYPE_LABELS = {
  asset: 'Assets', liability: 'Liabilities',
  income: 'Revenue', expense: 'Expenses', equity: 'Equity',
}
const tbComposition = computed(() => {
  const groups = {}
  trialBalance.value.forEach(r => {
    const t = r.type || 'other'
    groups[t] = (groups[t] || 0) + r.debit + r.credit
  })
  const total = Object.values(groups).reduce((s, v) => s + v, 0)
  if (!total) return { total: 0, segments: [] }
  const C = 2 * Math.PI * 50 // circumference for r=50
  let acc = 0
  const segments = Object.entries(groups)
    .sort((a, b) => b[1] - a[1])
    .map(([k, v]) => {
      const pct = (v / total) * 100
      const len = (v / total) * C
      const seg = {
        label: TYPE_LABELS[k] || k,
        value: v,
        pct,
        color: TYPE_COLORS[k] || '#94a3b8',
        dash: `${len} ${C - len}`,
        offset: -acc,
      }
      acc += len
      return seg
    })
  return { total, segments }
})
</script>

<style scoped>
.kpi-card { transition: transform 0.15s ease, box-shadow 0.15s ease; border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.kpi-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.06); }

.cashflow-wrap { padding-top: 4px; }

.pnl-table :deep(td) { padding: 8px 12px !important; border-bottom: 1px solid rgba(0,0,0,0.05); }
.pnl-table :deep(tr:last-child td) { border-bottom: none; }

.net-card {
  background: linear-gradient(135deg, rgba(16, 185, 129, 0.06), rgba(6, 182, 212, 0.04));
  border: 1px solid rgba(16, 185, 129, 0.15);
}
.font-mono { font-family: ui-monospace, 'SF Mono', Menlo, Consolas, monospace; }

/* ───────── Balance Sheet (theme-aware) ───────── */
.equation-card {
  background: linear-gradient(135deg,
    rgba(16, 185, 129, 0.08) 0%,
    rgba(59, 130, 246, 0.06) 100%);
  border: 1px solid rgba(16, 185, 129, 0.25);
}
.v-theme--dark .equation-card {
  background: linear-gradient(135deg,
    rgba(16, 185, 129, 0.12) 0%,
    rgba(59, 130, 246, 0.10) 100%);
  border-color: rgba(16, 185, 129, 0.35);
}

.section-header {
  background: rgba(0, 0, 0, 0.02);
}
.v-theme--dark .section-header {
  background: rgba(255, 255, 255, 0.03);
}
.section-success { border-left: 4px solid rgb(var(--v-theme-success)); }
.section-error   { border-left: 4px solid rgb(var(--v-theme-error)); }
.section-primary { border-left: 4px solid rgb(var(--v-theme-primary)); }

.subtotal-row {
  background: rgba(0, 0, 0, 0.03) !important;
  border-top: 1px solid rgba(0, 0, 0, 0.06);
}
.v-theme--dark .subtotal-row {
  background: rgba(255, 255, 255, 0.04) !important;
  border-top-color: rgba(255, 255, 255, 0.08);
}

.ratio-success {
  background: linear-gradient(135deg,
    rgba(16, 185, 129, 0.10),
    rgba(16, 185, 129, 0.04));
  border: 1px solid rgba(16, 185, 129, 0.20);
}
.ratio-warning {
  background: linear-gradient(135deg,
    rgba(245, 158, 11, 0.10),
    rgba(245, 158, 11, 0.04));
  border: 1px solid rgba(245, 158, 11, 0.20);
}
.ratio-error {
  background: linear-gradient(135deg,
    rgba(239, 68, 68, 0.10),
    rgba(239, 68, 68, 0.04));
  border: 1px solid rgba(239, 68, 68, 0.20);
}
.ratio-medium-emphasis {
  background: rgba(148, 163, 184, 0.08);
  border: 1px solid rgba(148, 163, 184, 0.20);
}

/* Ledger */
.ledger-table :deep(tbody tr:hover) { background: rgba(16, 185, 129, 0.08); }
.ledger-table :deep(td) { font-size: 0.85rem; }

/* ───────── Trial Balance Charts (theme-aware) ───────── */
/* Default (light) tokens */
:root {
  --tb-track-bg: #f1f5f9;
  --tb-axis: #cbd5e1;
  --tb-text: #0f172a;
  --tb-text-muted: #64748b;
  --tb-empty-ring: #e2e8f0;
  --tb-bar-text-shadow: 0 1px 2px rgba(0, 0, 0, 0.25);
  --tb-card-bg: rgba(255, 255, 255, 0.6);
}
/* Vuetify dark theme override */
.v-theme--dark {
  --tb-track-bg: rgba(255, 255, 255, 0.06);
  --tb-axis: rgba(255, 255, 255, 0.18);
  --tb-text: #e2e8f0;
  --tb-text-muted: #94a3b8;
  --tb-empty-ring: rgba(255, 255, 255, 0.08);
  --tb-bar-text-shadow: 0 1px 2px rgba(0, 0, 0, 0.6);
  --tb-card-bg: rgba(255, 255, 255, 0.02);
}

/* Debit vs Credit bars */
.tb-bars { display: flex; flex-direction: column; gap: 10px; }
.tb-bar-row {
  display: grid;
  grid-template-columns: 200px 1fr 130px;
  align-items: center;
  gap: 12px;
}
.tb-bar-track {
  display: flex; height: 24px; border-radius: 8px; overflow: hidden;
  background: var(--tb-track-bg);
  box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.04);
}
.tb-bar {
  display: flex; align-items: center; justify-content: flex-end;
  padding: 0 8px; font-size: 0.7rem; color: white; font-weight: 600;
  transition: width 0.4s cubic-bezier(.4,0,.2,1);
  white-space: nowrap;
  position: relative;
}
.tb-bar-dr { background: linear-gradient(90deg, #34d399, #059669); }
.tb-bar-cr { background: linear-gradient(90deg, #f87171, #dc2626); margin-left: 2px; }
.tb-bar:hover { filter: brightness(1.08); }
.tb-bar-text { text-shadow: var(--tb-bar-text-shadow); }
.tb-bar-net { text-align: right; }
.tb-bar-label { display: flex; align-items: center; min-width: 0; }
.tb-bar-label .text-caption { color: var(--tb-text); }

/* Donut */
.tb-donut { display: block; }
.tb-donut circle:first-of-type { stroke: var(--tb-empty-ring); }
.tb-donut-num {
  font-size: 9px; font-weight: 700; fill: var(--tb-text);
  font-family: ui-monospace, Menlo, monospace;
}
.tb-donut-lbl { font-size: 6px; fill: var(--tb-text-muted); }
.tb-dot {
  width: 10px; height: 10px; border-radius: 50%; display: inline-block;
  box-shadow: 0 0 0 2px var(--tb-card-bg);
}
.tb-legend-row {
  border-radius: 6px; transition: background 0.15s ease;
}
.tb-legend-row:hover { background: var(--tb-track-bg); }

/* Net balance horizontal */
.tb-net-chart { display: flex; flex-direction: column; gap: 8px; }
.tb-net-row {
  display: grid;
  grid-template-columns: 220px 1fr;
  align-items: center;
  gap: 12px;
}
.tb-net-label { display: flex; align-items: center; }
.tb-net-label .text-caption { color: var(--tb-text); }
.tb-net-track {
  position: relative; height: 26px; background: var(--tb-track-bg);
  border-radius: 8px; overflow: hidden;
  box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.04);
}
.tb-net-axis {
  position: absolute; top: 4px; bottom: 4px; left: 50%; width: 2px;
  background: var(--tb-axis); border-radius: 2px;
}
.tb-net-bar {
  position: absolute; top: 4px; bottom: 4px;
  display: flex; align-items: center; padding: 0 6px;
  font-size: 0.7rem; color: white; font-weight: 600;
  border-radius: 4px;
  transition: width 0.4s cubic-bezier(.4,0,.2,1);
}
.tb-net-dr {
  background: linear-gradient(90deg, #10b981, #059669);
  justify-content: flex-end;
}
.tb-net-cr {
  background: linear-gradient(90deg, #dc2626, #ef4444);
  justify-content: flex-start;
}
.tb-net-bar:hover { filter: brightness(1.08); }
.tb-net-value { text-shadow: var(--tb-bar-text-shadow); }

@media (max-width: 600px) {
  .tb-bar-row, .tb-net-row { grid-template-columns: 1fr; }
  .tb-bar-net { text-align: left; }
}
</style>
