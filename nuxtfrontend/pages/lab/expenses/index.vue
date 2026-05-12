<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="rose-lighten-5" size="48">
        <v-icon color="rose-darken-2" size="28">mdi-cash-minus</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Lab Expenses</div>
        <div class="text-body-2 text-medium-emphasis">
          Track spend · Approve & pay · Categorise · Recurring · Reports
        </div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh"
             :loading="loading" @click="loadAll">Refresh</v-btn>
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-shape-plus" @click="openCategory()">Category</v-btn>
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-tray-arrow-down" @click="exportExpenses">Export</v-btn>
      <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openExpense()">New Expense</v-btn>
    </div>

    <!-- KPIs -->
    <v-row dense>
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="3">
        <v-card flat rounded="lg" class="kpi pa-4">
          <div class="d-flex align-center">
            <v-avatar :color="k.color + '-lighten-5'" size="40" class="mr-3">
              <v-icon :color="k.color + '-darken-2'">{{ k.icon }}</v-icon>
            </v-avatar>
            <div class="min-width-0">
              <div class="text-overline text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h5 font-weight-bold">{{ k.value }}</div>
              <div v-if="k.hint" class="text-caption text-medium-emphasis">{{ k.hint }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Section pills -->
    <v-card flat rounded="lg" class="mt-4 pa-3">
      <div class="d-flex flex-wrap align-center ga-2">
        <v-chip
          v-for="s in sectionFilters" :key="s.value"
          :color="section === s.value ? (s.color || 'primary') : undefined"
          :variant="section === s.value ? 'flat' : 'tonal'"
          size="small" @click="section = s.value"
        >
          <v-icon v-if="s.icon" size="14" start>{{ s.icon }}</v-icon>
          {{ s.label }}<span v-if="s.count != null" class="ml-2 font-weight-bold">{{ s.count }}</span>
        </v-chip>

        <v-divider vertical class="mx-2" />

        <v-chip
          v-for="c in topCategoryChips" :key="c.value || 'all-cat'"
          :color="categoryFilter === c.value ? 'rose' : undefined"
          :variant="categoryFilter === c.value ? 'flat' : 'tonal'"
          size="small" @click="categoryFilter = c.value"
        >
          <v-icon size="14" start>mdi-tag</v-icon>
          {{ c.label }}
          <span v-if="c.count != null" class="ml-2 font-weight-bold">{{ c.count }}</span>
        </v-chip>

        <v-spacer />

        <v-btn-toggle v-model="view" mandatory density="compact" rounded="lg" color="primary">
          <v-btn value="table" icon="mdi-format-list-bulleted" size="small" />
          <v-btn value="grid" icon="mdi-view-grid-outline" size="small" />
        </v-btn-toggle>
      </div>
    </v-card>

    <!-- Filter bar -->
    <v-card flat rounded="lg" class="mt-3 pa-3">
      <v-row dense align="center">
        <v-col cols="12" md="3">
          <v-text-field
            v-model="search"
            prepend-inner-icon="mdi-magnify"
            placeholder="Search title, ref, vendor…"
            variant="outlined" density="compact" hide-details clearable
          />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="statusFilter" :items="statusFilterOptions"
                    label="Status" prepend-inner-icon="mdi-progress-check"
                    variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="methodFilter" :items="methodFilterOptions"
                    label="Method" prepend-inner-icon="mdi-credit-card-outline"
                    variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="dateFilter" :items="dateOptions"
                    label="Date" prepend-inner-icon="mdi-calendar"
                    variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="sortBy" :items="sortOptions"
                    label="Sort" prepend-inner-icon="mdi-sort"
                    variant="outlined" density="compact" hide-details />
        </v-col>
        <v-col cols="12" md="1" class="d-flex justify-end">
          <v-btn variant="text" size="small" @click="resetFilters">
            <v-icon start size="16">mdi-filter-remove-outline</v-icon>
          </v-btn>
        </v-col>
      </v-row>
    </v-card>

    <!-- Overdue ribbon -->
    <v-slide-y-transition>
      <v-alert v-if="overdueExpenses.length" type="error" variant="tonal"
               class="mt-3" prominent rounded="lg" icon="mdi-clock-alert">
        <div class="font-weight-bold">{{ overdueExpenses.length }} overdue expense(s)</div>
        <div class="text-body-2">
          {{ fmtMoney(overdueTotal) }} past due ·
          <span v-for="(e, i) in overdueExpenses.slice(0, 3)" :key="e.id" class="mr-2">
            <v-chip size="x-small" color="error" variant="flat" class="ml-1">{{ daysOverdue(e) }}d</v-chip>
            {{ e.title }}<span v-if="i < Math.min(2, overdueExpenses.length - 1)">,</span>
          </span>
        </div>
      </v-alert>
    </v-slide-y-transition>

    <!-- Bulk action bar -->
    <v-slide-y-transition>
      <v-card v-if="selected.length && (section === 'all' || section === 'pending')" flat rounded="lg"
              class="mt-3 pa-3 bulk-bar">
        <div class="d-flex align-center ga-2">
          <v-icon color="primary">mdi-check-all</v-icon>
          <span class="font-weight-medium">{{ selected.length }} selected</span>
          <v-spacer />
          <v-btn size="small" variant="tonal" color="success" prepend-icon="mdi-check"
                 :loading="bulkBusy" @click="bulkAction('approve')">Approve</v-btn>
          <v-btn size="small" variant="tonal" color="info" prepend-icon="mdi-cash"
                 :loading="bulkBusy" @click="bulkAction('mark_paid')">Mark paid</v-btn>
          <v-btn size="small" variant="tonal" color="error" prepend-icon="mdi-close"
                 :loading="bulkBusy" @click="bulkAction('reject')">Reject</v-btn>
          <v-btn size="small" variant="text" @click="selected = []">Clear</v-btn>
        </div>
      </v-card>
    </v-slide-y-transition>

    <!-- ====================== EXPENSES (all / pending / paid / overdue / recurring) ====================== -->
    <template v-if="['all','pending','paid','overdue','recurring'].includes(section)">
      <!-- Table view -->
      <v-card v-if="view === 'table'" flat rounded="lg" class="mt-3">
        <v-data-table
          v-model="selected"
          show-select
          :headers="headers"
          :items="filtered"
          :loading="loading"
          :items-per-page="20"
          item-value="id"
          hover
          class="exp-table"
          @click:row="(_, { item }) => openDetail(item)"
        >
          <template #loading><v-skeleton-loader type="table-row@5" /></template>

          <template #item.expense_date="{ item }">
            <div class="d-flex flex-column">
              <span class="text-caption font-weight-medium">{{ fmtDate(item.expense_date) }}</span>
              <span v-if="item.due_date" class="text-caption" :class="isOverdue(item) ? 'text-error' : 'text-medium-emphasis'">
                Due {{ fmtDate(item.due_date) }}
              </span>
            </div>
          </template>

          <template #item.title="{ item }">
            <div class="d-flex align-center">
              <v-avatar :color="(item.category_color || '#94a3b8')" size="30" class="mr-2 cat-dot">
                <v-icon size="14" color="white">mdi-tag</v-icon>
              </v-avatar>
              <div class="min-width-0">
                <div class="font-weight-medium text-truncate">{{ item.title }}</div>
                <div class="text-caption text-medium-emphasis text-truncate">
                  {{ item.reference }}<span v-if="item.vendor"> · {{ item.vendor }}</span>
                </div>
              </div>
            </div>
          </template>

          <template #item.category_name="{ item }">
            <v-chip v-if="item.category_name" size="x-small" variant="tonal" class="text-truncate"
                    :color="item.category_color ? undefined : 'grey'"
                    :style="item.category_color ? `color:${item.category_color};` : ''">
              {{ item.category_name }}
            </v-chip>
            <span v-else class="text-medium-emphasis text-caption">Uncategorised</span>
          </template>

          <template #item.payment_method="{ value }">
            <div class="d-flex align-center">
              <v-icon size="14" :color="methodColor(value)" class="mr-1">{{ methodIcon(value) }}</v-icon>
              <span class="text-caption">{{ methodLabel(value) }}</span>
            </div>
          </template>

          <template #item.amount="{ item }">
            <div class="d-flex flex-column align-end">
              <span class="font-monospace font-weight-bold">{{ fmtMoney(item.amount) }}</span>
              <span v-if="Number(item.tax_amount) > 0" class="text-caption text-medium-emphasis">
                +{{ fmtMoney(item.tax_amount) }} tax
              </span>
            </div>
          </template>

          <template #item.status="{ value }">
            <v-chip :color="statusColor(value)" size="small" variant="flat" class="text-capitalize">
              <v-icon size="14" start>{{ statusIcon(value) }}</v-icon>
              {{ statusLabel(value) }}
            </v-chip>
          </template>

          <template #item.actions="{ item }">
            <div class="d-flex justify-end" @click.stop>
              <v-tooltip text="View" location="top">
                <template #activator="{ props }">
                  <v-btn v-bind="props" icon="mdi-eye-outline" variant="text" size="small"
                         @click="openDetail(item)" />
                </template>
              </v-tooltip>
              <v-tooltip text="Edit" location="top">
                <template #activator="{ props }">
                  <v-btn v-bind="props" icon="mdi-pencil-outline" variant="text" size="small"
                         color="primary" @click="openExpense(item)" />
                </template>
              </v-tooltip>
              <v-menu>
                <template #activator="{ props }">
                  <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" />
                </template>
                <v-list density="compact">
                  <v-list-item v-if="item.status === 'pending'" prepend-icon="mdi-check"
                               title="Approve" base-color="success"
                               @click="quickAction(item, 'approve')" />
                  <v-list-item v-if="['pending','approved'].includes(item.status)"
                               prepend-icon="mdi-cash" title="Mark paid"
                               @click="openPay(item)" />
                  <v-list-item v-if="item.status === 'pending'" prepend-icon="mdi-close"
                               title="Reject" base-color="error" @click="openReject(item)" />
                  <v-list-item prepend-icon="mdi-content-copy" title="Duplicate"
                               @click="duplicateExpense(item)" />
                  <v-list-item v-if="item.receipt" prepend-icon="mdi-paperclip"
                               title="View receipt" :href="item.receipt" target="_blank" />
                  <v-divider />
                  <v-list-item prepend-icon="mdi-delete" title="Delete" base-color="error"
                               @click="confirmDelete(item)" />
                </v-list>
              </v-menu>
            </div>
          </template>

          <template #no-data>
            <div class="pa-8 text-center">
              <v-icon size="56" color="grey-lighten-1">mdi-cash-remove</v-icon>
              <div class="text-subtitle-1 font-weight-medium mt-2">No expenses found</div>
              <div class="text-body-2 text-medium-emphasis mb-4">
                Adjust your filters or log a new expense.
              </div>
              <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openExpense()">New Expense</v-btn>
            </div>
          </template>
        </v-data-table>
      </v-card>

      <!-- Grid view -->
      <div v-else class="mt-3">
        <div v-if="loading" class="d-flex justify-center pa-12">
          <v-progress-circular indeterminate color="primary" />
        </div>
        <div v-else-if="!filtered.length" class="pa-8 text-center">
          <v-icon size="56" color="grey-lighten-1">mdi-cash-remove</v-icon>
          <div class="text-subtitle-1 font-weight-medium mt-2">No expenses found</div>
          <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" class="mt-3" @click="openExpense()">
            New Expense
          </v-btn>
        </div>
        <v-row v-else dense>
          <v-col v-for="e in filtered" :key="e.id" cols="12" sm="6" md="4" lg="3">
            <v-card flat rounded="lg" class="exp-card pa-3 h-100" hover @click="openDetail(e)">
              <div class="exp-band" :style="{ background: statusHex(e.status) }" />
              <div class="d-flex align-center mb-2">
                <v-chip :color="statusColor(e.status)" size="x-small" variant="flat" class="text-capitalize">
                  <v-icon size="12" start>{{ statusIcon(e.status) }}</v-icon>{{ statusLabel(e.status) }}
                </v-chip>
                <v-spacer />
                <span class="text-caption text-medium-emphasis">{{ fmtDate(e.expense_date) }}</span>
              </div>
              <div class="d-flex align-center">
                <v-avatar :color="e.category_color || '#94a3b8'" size="36" class="mr-3">
                  <v-icon size="18" color="white">mdi-tag</v-icon>
                </v-avatar>
                <div class="min-width-0 flex-grow-1">
                  <div class="font-weight-medium text-truncate">{{ e.title }}</div>
                  <div class="text-caption text-medium-emphasis text-truncate">
                    {{ e.category_name || 'Uncategorised' }}
                  </div>
                </div>
              </div>
              <v-divider class="my-3" />
              <div class="d-flex justify-space-between text-caption mb-1">
                <span class="text-medium-emphasis">Reference</span>
                <span class="font-monospace">{{ e.reference || '—' }}</span>
              </div>
              <div class="d-flex justify-space-between text-caption mb-1">
                <span class="text-medium-emphasis">Vendor</span>
                <span class="text-truncate" style="max-width:60%">{{ e.vendor || '—' }}</span>
              </div>
              <div class="d-flex justify-space-between text-caption mb-1">
                <span class="text-medium-emphasis">Method</span>
                <span>
                  <v-icon size="12" :color="methodColor(e.payment_method)">{{ methodIcon(e.payment_method) }}</v-icon>
                  {{ methodLabel(e.payment_method) }}
                </span>
              </div>
              <div class="d-flex justify-space-between align-center mt-2">
                <span class="text-caption text-medium-emphasis">Amount</span>
                <span class="font-monospace font-weight-bold text-h6">{{ fmtMoney(e.amount) }}</span>
              </div>
            </v-card>
          </v-col>
        </v-row>
      </div>

      <!-- Total bar under list -->
      <v-card v-if="filtered.length" flat rounded="lg" class="mt-3 pa-3 d-flex align-center">
        <v-icon color="rose-darken-2" class="mr-2">mdi-sigma</v-icon>
        <span class="text-body-2 text-medium-emphasis">
          Showing <strong>{{ filtered.length }}</strong> of {{ expenses.length }}
        </span>
        <v-spacer />
        <span class="text-body-2 text-medium-emphasis mr-2">Total</span>
        <span class="text-h6 font-weight-bold">{{ fmtMoney(filteredTotal) }}</span>
      </v-card>
    </template>

    <!-- ====================== CATEGORIES ====================== -->
    <template v-if="section === 'categories'">
      <v-row dense class="mt-3">
        <v-col v-for="c in categoriesEnriched" :key="c.id" cols="12" sm="6" md="4" lg="3">
          <v-card flat rounded="lg" class="cat-card pa-4 h-100">
            <div class="exp-band" :style="{ background: c.color || '#94a3b8' }" />
            <div class="d-flex align-center mb-3">
              <v-avatar :color="c.color || '#94a3b8'" size="40" class="mr-3">
                <v-icon color="white">mdi-tag</v-icon>
              </v-avatar>
              <div class="min-width-0 flex-grow-1">
                <div class="font-weight-bold text-truncate">{{ c.name }}</div>
                <div class="text-caption text-medium-emphasis">
                  {{ c.expense_count || 0 }} expense(s)
                </div>
              </div>
              <v-menu>
                <template #activator="{ props }">
                  <v-btn icon="mdi-dots-vertical" size="small" variant="text" v-bind="props" />
                </template>
                <v-list density="compact">
                  <v-list-item prepend-icon="mdi-pencil" title="Edit" @click="openCategory(c)" />
                  <v-list-item prepend-icon="mdi-magnify" title="View expenses" @click="filterByCategory(c)" />
                  <v-divider />
                  <v-list-item prepend-icon="mdi-delete" title="Delete" base-color="error"
                               @click="deleteCategory(c)" />
                </v-list>
              </v-menu>
            </div>
            <div class="text-overline text-medium-emphasis">Total spent</div>
            <div class="text-h6 font-weight-bold">{{ fmtMoney(c.total_spent || 0) }}</div>
            <div class="text-caption text-medium-emphasis mb-2 text-truncate">
              {{ c.description || 'No description' }}
            </div>
            <v-progress-linear :model-value="categoryShare(c)" :color="c.color || 'rose'"
                               height="6" rounded />
            <div class="d-flex align-center mt-2">
              <v-chip size="x-small" :color="c.is_active ? 'success' : 'grey'" variant="tonal">
                {{ c.is_active ? 'Active' : 'Inactive' }}
              </v-chip>
              <v-spacer />
              <span class="text-caption text-medium-emphasis">{{ categoryShare(c).toFixed(1) }}% share</span>
            </div>
          </v-card>
        </v-col>
        <v-col v-if="!categories.length" cols="12">
          <v-card class="pa-8 text-center text-medium-emphasis" rounded="lg" flat>
            <v-icon size="56" color="grey-lighten-1">mdi-shape-outline</v-icon>
            <div class="text-subtitle-1 font-weight-medium mt-2">No categories yet</div>
            <div class="text-body-2 mb-3">Create one to start grouping expenses.</div>
            <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openCategory()">
              New category
            </v-btn>
          </v-card>
        </v-col>
      </v-row>
    </template>

    <!-- ====================== REPORTS ====================== -->
    <template v-if="section === 'reports'">
      <v-row dense class="mt-3">
        <v-col v-for="r in reportTiles" :key="r.label" cols="6" md="3">
          <v-card flat rounded="lg" class="kpi pa-4">
            <div class="text-overline text-medium-emphasis">{{ r.label }}</div>
            <div class="text-h5 font-weight-bold mt-1">{{ r.value }}</div>
            <div class="text-caption" :class="r.deltaClass">{{ r.delta }}</div>
          </v-card>
        </v-col>
      </v-row>

      <v-row dense class="mt-3">
        <v-col cols="12" md="8">
          <v-card flat rounded="lg" class="pa-4 h-100">
            <div class="d-flex align-center mb-3">
              <v-avatar color="rose-lighten-5" size="36" class="mr-2">
                <v-icon color="rose-darken-2">mdi-chart-line</v-icon>
              </v-avatar>
              <div>
                <div class="text-overline text-medium-emphasis">12-MONTH TREND</div>
                <div class="text-subtitle-1 font-weight-medium">Spend trend</div>
              </div>
              <v-spacer />
              <v-chip size="small" variant="tonal" color="rose">{{ fmtMoney(trendTotal) }} total</v-chip>
              <v-btn class="ml-2" size="small" variant="text" prepend-icon="mdi-tray-arrow-down"
                     @click="exportTrend">CSV</v-btn>
            </div>
            <SparkArea
              v-if="trendSeries.length"
              :data="trendSeries"
              :categories="['total']"
              index="month"
              :colors="['#e11d48']"
              :value-formatter="fmtMoney"
              :height="220"
            />
            <div v-else class="text-medium-emphasis text-center py-8">
              <v-icon size="48" color="grey">mdi-chart-line-variant</v-icon>
              <div class="mt-2">No trend data yet</div>
            </div>
          </v-card>
        </v-col>

        <v-col cols="12" md="4">
          <v-card flat rounded="lg" class="pa-4 h-100">
            <div class="d-flex align-center mb-3">
              <v-avatar color="indigo-lighten-5" size="36" class="mr-2">
                <v-icon color="indigo-darken-2">mdi-chart-pie</v-icon>
              </v-avatar>
              <div>
                <div class="text-overline text-medium-emphasis">BREAKDOWN</div>
                <div class="text-subtitle-1 font-weight-medium">By status</div>
              </div>
            </div>
            <div v-if="!expenses.length" class="text-medium-emphasis text-center py-6">
              No expenses yet.
            </div>
            <div v-else>
              <div v-for="row in expensesByStatus" :key="row.key" class="mb-3">
                <div class="d-flex align-center mb-1">
                  <v-icon size="12" :color="statusColor(row.key)" class="mr-2">mdi-circle</v-icon>
                  <span class="text-body-2 font-weight-medium">{{ statusLabel(row.key) }}</span>
                  <v-spacer />
                  <span class="text-caption">{{ row.count }} · <strong>{{ fmtMoney(row.amount) }}</strong></span>
                </div>
                <v-progress-linear :model-value="row.pct" :color="statusColor(row.key)" height="6" rounded />
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>

      <v-row dense class="mt-3">
        <v-col cols="12" md="6">
          <v-card flat rounded="lg" class="pa-4 h-100">
            <div class="d-flex align-center mb-3">
              <v-avatar color="purple-lighten-5" size="36" class="mr-2">
                <v-icon color="purple-darken-2">mdi-shape</v-icon>
              </v-avatar>
              <div>
                <div class="text-overline text-medium-emphasis">CATEGORIES</div>
                <div class="text-subtitle-1 font-weight-medium">Spend by category</div>
              </div>
            </div>
            <table class="report-table">
              <thead>
                <tr>
                  <th>Category</th>
                  <th class="text-right">Count</th>
                  <th class="text-right">Total</th>
                  <th class="text-right">Share</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="row in topCategories" :key="row.id || row.name">
                  <td>
                    <v-icon size="10" :color="row.color || 'grey'" class="mr-1">mdi-circle</v-icon>
                    {{ row.name }}
                  </td>
                  <td class="text-right">{{ row.count }}</td>
                  <td class="text-right font-monospace">{{ fmtMoney(row.total) }}</td>
                  <td class="text-right">{{ row.pct.toFixed(1) }}%</td>
                </tr>
                <tr v-if="!topCategories.length">
                  <td colspan="4" class="text-center text-medium-emphasis py-4">No data</td>
                </tr>
              </tbody>
            </table>
          </v-card>
        </v-col>
        <v-col cols="12" md="6">
          <v-card flat rounded="lg" class="pa-4 h-100">
            <div class="d-flex align-center mb-3">
              <v-avatar color="teal-lighten-5" size="36" class="mr-2">
                <v-icon color="teal-darken-2">mdi-store</v-icon>
              </v-avatar>
              <div>
                <div class="text-overline text-medium-emphasis">VENDORS</div>
                <div class="text-subtitle-1 font-weight-medium">Top vendors</div>
              </div>
            </div>
            <table class="report-table">
              <thead>
                <tr>
                  <th>Vendor</th>
                  <th class="text-right">Count</th>
                  <th class="text-right">Total</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="v in topVendors" :key="v.name">
                  <td>{{ v.name }}</td>
                  <td class="text-right">{{ v.count }}</td>
                  <td class="text-right font-monospace">{{ fmtMoney(v.total) }}</td>
                </tr>
                <tr v-if="!topVendors.length">
                  <td colspan="3" class="text-center text-medium-emphasis py-4">No vendor data</td>
                </tr>
              </tbody>
            </table>
          </v-card>
        </v-col>
      </v-row>

      <v-card flat rounded="lg" class="pa-4 mt-3">
        <div class="d-flex align-center mb-3">
          <v-avatar color="amber-lighten-5" size="36" class="mr-2">
            <v-icon color="amber-darken-2">mdi-calendar-month</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">MONTHLY</div>
            <div class="text-subtitle-1 font-weight-medium">Monthly breakdown</div>
          </div>
          <v-spacer />
          <v-btn size="small" variant="tonal" color="rose" prepend-icon="mdi-tray-arrow-down"
                 @click="exportTrend">CSV</v-btn>
        </div>
        <table class="report-table">
          <thead>
            <tr>
              <th>Month</th>
              <th class="text-right">Total</th>
              <th class="text-right">Δ vs prior</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(m, i) in trendSeries" :key="m.month">
              <td>{{ fmtMonth(m.month) }}</td>
              <td class="text-right font-monospace">{{ fmtMoney(m.total) }}</td>
              <td class="text-right" :class="trendDeltaClass(trendSeries, i)">
                {{ trendDelta(trendSeries, i) }}
              </td>
            </tr>
            <tr v-if="!trendSeries.length">
              <td colspan="3" class="text-center text-medium-emphasis py-4">No data</td>
            </tr>
          </tbody>
        </table>
      </v-card>
    </template>

    <!-- ====================== EXPENSE DIALOG ====================== -->
    <v-dialog v-model="expenseDialog.show" max-width="780" scrollable persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="rose-lighten-5" size="40" class="mr-3">
            <v-icon color="rose-darken-2">{{ expenseDialog.editing ? 'mdi-pencil' : 'mdi-plus' }}</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">EXPENSE</div>
            <div class="text-h6 font-weight-bold">
              {{ expenseDialog.editing ? 'Edit expense' : 'New expense' }}
            </div>
          </div>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" @click="expenseDialog.show = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          <v-form ref="expenseForm" v-model="expenseFormValid" @submit.prevent="saveExpense">
            <v-row dense>
              <v-col cols="12" sm="8">
                <v-text-field v-model="expenseDialog.data.title"
                              label="Title *" prepend-inner-icon="mdi-text-box-outline"
                              :rules="[v => !!v || 'Title is required']"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" sm="4">
                <v-text-field v-model="expenseDialog.data.reference"
                              label="Reference" prepend-inner-icon="mdi-barcode"
                              hint="Auto-generated if blank" persistent-hint
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-autocomplete v-model="expenseDialog.data.category" :items="categories"
                                item-title="name" item-value="id"
                                label="Category" prepend-inner-icon="mdi-tag"
                                variant="outlined" density="comfortable" clearable />
              </v-col>
              <v-col cols="6" sm="3">
                <v-text-field v-model.number="expenseDialog.data.amount" type="number" step="0.01" prefix="KSh"
                              label="Amount *" prepend-inner-icon="mdi-cash"
                              :rules="[v => (v != null && v !== '') || 'Required', v => Number(v) >= 0 || 'Must be ≥ 0']"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="6" sm="3">
                <v-text-field v-model.number="expenseDialog.data.tax_amount" type="number" step="0.01" prefix="KSh"
                              label="Tax" prepend-inner-icon="mdi-percent"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="6" sm="6">
                <v-text-field v-model="expenseDialog.data.expense_date" type="date"
                              label="Expense date *" prepend-inner-icon="mdi-calendar"
                              :rules="[v => !!v || 'Required']"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="6" sm="6">
                <v-text-field v-model="expenseDialog.data.due_date" type="date"
                              label="Due date" prepend-inner-icon="mdi-calendar-clock"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-select v-model="expenseDialog.data.payment_method" :items="methodOptions"
                          label="Payment method" prepend-inner-icon="mdi-credit-card-outline"
                          variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="expenseDialog.data.payment_reference"
                              label="Payment reference" prepend-inner-icon="mdi-pound"
                              placeholder="MPESA code, cheque #, txn ref"
                              persistent-placeholder
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="expenseDialog.data.vendor"
                              label="Vendor / payee" prepend-inner-icon="mdi-store"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-autocomplete v-model="expenseDialog.data.supplier" :items="suppliers"
                                item-title="name" item-value="id"
                                label="Supplier" prepend-inner-icon="mdi-truck-delivery"
                                variant="outlined" density="comfortable" clearable />
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="expenseDialog.data.description"
                            label="Description" prepend-inner-icon="mdi-text"
                            rows="2" auto-grow variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-switch v-model="expenseDialog.data.is_recurring" color="rose"
                          density="compact" inset hide-details label="Recurring expense" />
              </v-col>
              <v-col v-if="expenseDialog.data.is_recurring" cols="12" sm="6">
                <v-select v-model="expenseDialog.data.recurring_period"
                          :items="['daily','weekly','monthly','quarterly','yearly']"
                          label="Period" prepend-inner-icon="mdi-repeat"
                          variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12">
                <v-file-input v-model="expenseDialog.receiptFile" prepend-icon=""
                              prepend-inner-icon="mdi-paperclip" label="Receipt"
                              accept="image/*,application/pdf"
                              variant="outlined" density="comfortable" />
                <div v-if="expenseDialog.data.receipt && !expenseDialog.receiptFile" class="text-caption">
                  Current: <a :href="expenseDialog.data.receipt" target="_blank">view</a>
                </div>
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="expenseDialog.data.notes"
                            label="Internal notes" prepend-inner-icon="mdi-note-text-outline"
                            rows="2" auto-grow variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12">
                <v-card flat color="rose-lighten-5" rounded="lg" class="pa-3 d-flex align-center">
                  <v-icon color="rose-darken-2" class="mr-2">mdi-sigma</v-icon>
                  <span class="text-body-2 text-medium-emphasis">Total</span>
                  <v-spacer />
                  <span class="text-h6 font-weight-bold text-rose-darken-2">
                    {{ fmtMoney(Number(expenseDialog.data.amount || 0) + Number(expenseDialog.data.tax_amount || 0)) }}
                  </span>
                </v-card>
              </v-col>
            </v-row>
          </v-form>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="expenseDialog.show = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" :loading="expenseDialog.saving"
                 :disabled="!expenseFormValid" @click="saveExpense">
            <v-icon start>mdi-content-save</v-icon>
            {{ expenseDialog.editing ? 'Update' : 'Save' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ====================== DETAIL DIALOG ====================== -->
    <v-dialog v-model="detailDialog" max-width="780" scrollable>
      <v-card v-if="detailItem" rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar :color="statusColor(detailItem.status)" size="44" class="mr-3">
            <v-icon color="white" size="22">{{ statusIcon(detailItem.status) }}</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">{{ detailItem.reference }}</div>
            <div class="text-h6 font-weight-bold">{{ detailItem.title }}</div>
          </div>
          <v-spacer />
          <v-chip :color="statusColor(detailItem.status)" size="small" variant="flat" class="mr-2 text-capitalize">
            {{ statusLabel(detailItem.status) }}
          </v-chip>
          <v-btn icon="mdi-close" variant="text" @click="detailDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          <v-row dense>
            <v-col cols="6" sm="3">
              <div class="text-caption text-medium-emphasis">Category</div>
              <div class="font-weight-medium">{{ detailItem.category_name || 'Uncategorised' }}</div>
            </v-col>
            <v-col cols="6" sm="3">
              <div class="text-caption text-medium-emphasis">Date</div>
              <div>{{ fmtDate(detailItem.expense_date) }}</div>
            </v-col>
            <v-col cols="6" sm="3">
              <div class="text-caption text-medium-emphasis">Due</div>
              <div :class="isOverdue(detailItem) ? 'text-error font-weight-bold' : ''">
                {{ fmtDate(detailItem.due_date) }}
              </div>
            </v-col>
            <v-col cols="6" sm="3">
              <div class="text-caption text-medium-emphasis">Method</div>
              <div>
                <v-icon size="14" :color="methodColor(detailItem.payment_method)">{{ methodIcon(detailItem.payment_method) }}</v-icon>
                {{ methodLabel(detailItem.payment_method) }}
              </div>
            </v-col>
            <v-col cols="6" sm="3">
              <div class="text-caption text-medium-emphasis">Vendor</div>
              <div>{{ detailItem.vendor || '—' }}</div>
            </v-col>
            <v-col cols="6" sm="3">
              <div class="text-caption text-medium-emphasis">Supplier</div>
              <div>{{ detailItem.supplier_name || '—' }}</div>
            </v-col>
            <v-col cols="6" sm="3">
              <div class="text-caption text-medium-emphasis">Submitted by</div>
              <div>{{ detailItem.submitted_by_name || '—' }}</div>
            </v-col>
            <v-col cols="6" sm="3">
              <div class="text-caption text-medium-emphasis">Approved by</div>
              <div>{{ detailItem.approved_by_name || '—' }}</div>
            </v-col>
            <v-col cols="12">
              <v-divider class="my-3" />
              <v-card flat color="rose-lighten-5" rounded="lg" class="pa-3 d-flex align-center">
                <div>
                  <div class="text-overline text-medium-emphasis">AMOUNT</div>
                  <div class="text-h5 font-weight-bold text-rose-darken-2">{{ fmtMoney(detailItem.amount) }}</div>
                </div>
                <v-divider vertical class="mx-4" />
                <div>
                  <div class="text-overline text-medium-emphasis">TAX</div>
                  <div class="text-h6 font-weight-bold">{{ fmtMoney(detailItem.tax_amount || 0) }}</div>
                </div>
                <v-spacer />
                <div class="text-right">
                  <div class="text-overline text-medium-emphasis">TOTAL</div>
                  <div class="text-h5 font-weight-bold">
                    {{ fmtMoney(Number(detailItem.amount || 0) + Number(detailItem.tax_amount || 0)) }}
                  </div>
                </div>
              </v-card>
            </v-col>
            <v-col v-if="detailItem.description" cols="12">
              <div class="text-caption text-medium-emphasis">Description</div>
              <div class="text-body-2">{{ detailItem.description }}</div>
            </v-col>
            <v-col v-if="detailItem.notes" cols="12">
              <div class="text-caption text-medium-emphasis">Notes</div>
              <div class="text-body-2">{{ detailItem.notes }}</div>
            </v-col>
            <v-col v-if="detailItem.receipt" cols="12">
              <v-btn variant="tonal" color="primary" prepend-icon="mdi-paperclip"
                     :href="detailItem.receipt" target="_blank">View receipt</v-btn>
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-btn v-if="detailItem.status === 'pending'" color="success" variant="tonal"
                 prepend-icon="mdi-check" @click="quickAction(detailItem, 'approve'); detailDialog = false">
            Approve
          </v-btn>
          <v-btn v-if="['pending','approved'].includes(detailItem.status)" color="info" variant="tonal"
                 prepend-icon="mdi-cash" @click="openPay(detailItem); detailDialog = false">
            Mark paid
          </v-btn>
          <v-btn v-if="detailItem.status === 'pending'" color="error" variant="text"
                 prepend-icon="mdi-close" @click="openReject(detailItem); detailDialog = false">
            Reject
          </v-btn>
          <v-spacer />
          <v-btn variant="text" @click="detailDialog = false">Close</v-btn>
          <v-btn color="primary" rounded="lg" prepend-icon="mdi-pencil"
                 @click="openExpense(detailItem); detailDialog = false">Edit</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ====================== CATEGORY DIALOG ====================== -->
    <v-dialog v-model="categoryDialog.show" max-width="500" persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="rose-lighten-5" size="40" class="mr-3">
            <v-icon color="rose-darken-2">mdi-tag</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">CATEGORY</div>
            <div class="text-h6 font-weight-bold">
              {{ categoryDialog.editing ? 'Edit category' : 'New category' }}
            </div>
          </div>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" @click="categoryDialog.show = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          <v-text-field v-model="categoryDialog.data.name" label="Name *"
                        prepend-inner-icon="mdi-format-text"
                        placeholder="Type or pick a suggestion below"
                        persistent-placeholder
                        variant="outlined" density="comfortable" />

          <div class="text-overline text-medium-emphasis mb-1">Suggestions</div>
          <div class="d-flex flex-wrap mb-3" style="gap:6px">
            <v-chip
              v-for="s in categorySuggestions" :key="s.name"
              :color="categoryDialog.data.name === s.name ? 'rose' : undefined"
              :variant="categoryDialog.data.name === s.name ? 'flat' : 'tonal'"
              size="small"
              @click="applyCategorySuggestion(s)"
            >
              <v-icon size="14" start>{{ s.icon }}</v-icon>{{ s.name }}
            </v-chip>
          </div>

          <v-textarea v-model="categoryDialog.data.description" label="Description"
                      prepend-inner-icon="mdi-text"
                      rows="2" auto-grow variant="outlined" density="comfortable" />

          <div class="text-overline text-medium-emphasis mb-1">Color</div>
          <div class="d-flex flex-wrap" style="gap:6px">
            <v-chip
              v-for="c in colorPalette" :key="c"
              :variant="categoryDialog.data.color === c ? 'flat' : 'outlined'"
              size="small"
              :style="categoryDialog.data.color === c
                ? `background:${c};color:#fff;border-color:${c};`
                : `border-color:${c};color:${c};`"
              @click="categoryDialog.data.color = c"
            >
              <v-icon size="14" start>
                {{ categoryDialog.data.color === c ? 'mdi-check-circle' : 'mdi-circle' }}
              </v-icon>
              {{ c.toUpperCase() }}
            </v-chip>
          </div>

          <v-switch v-model="categoryDialog.data.is_active" color="rose" inset
                    density="compact" hide-details class="mt-3" label="Active" />
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="categoryDialog.show = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" :loading="categoryDialog.saving" @click="saveCategory">
            <v-icon start>mdi-content-save</v-icon>
            {{ categoryDialog.editing ? 'Update' : 'Save' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ====================== ACTION DIALOG ====================== -->
    <v-dialog v-model="actionDialog.show" max-width="480" persistent>
      <v-card v-if="actionDialog.target" rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar :color="actionDialog.kind === 'mark_paid' ? 'success-lighten-5' : 'error-lighten-5'"
                    size="40" class="mr-3">
            <v-icon :color="actionDialog.kind === 'mark_paid' ? 'success-darken-2' : 'error-darken-2'">
              {{ actionDialog.kind === 'mark_paid' ? 'mdi-cash' : 'mdi-close-octagon' }}
            </v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">{{ actionDialog.target.reference }}</div>
            <div class="text-h6 font-weight-bold">
              {{ actionDialog.kind === 'mark_paid' ? 'Mark as paid' : 'Reject expense' }}
            </div>
          </div>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" @click="actionDialog.show = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          <div class="mb-3">
            <div class="font-weight-medium">{{ actionDialog.target.title }}</div>
            <div class="text-h6 font-weight-bold mt-1">
              {{ fmtMoney(Number(actionDialog.target.amount || 0) + Number(actionDialog.target.tax_amount || 0)) }}
            </div>
          </div>
          <template v-if="actionDialog.kind === 'mark_paid'">
            <v-select v-model="actionDialog.payload.payment_method" :items="methodOptions"
                      label="Payment method" prepend-inner-icon="mdi-credit-card-outline"
                      variant="outlined" density="comfortable" />
            <v-text-field v-model="actionDialog.payload.payment_reference"
                          label="Payment reference" prepend-inner-icon="mdi-pound"
                          variant="outlined" density="comfortable" />
          </template>
          <template v-else>
            <v-textarea v-model="actionDialog.payload.reason"
                        label="Reason" prepend-inner-icon="mdi-text"
                        rows="3" auto-grow variant="outlined" density="comfortable" />
          </template>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="actionDialog.show = false">Cancel</v-btn>
          <v-btn :color="actionDialog.kind === 'mark_paid' ? 'success' : 'error'"
                 rounded="lg" :loading="actionDialog.saving" @click="confirmAction">
            <v-icon start>mdi-check</v-icon>Confirm
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ====================== DELETE CONFIRM ====================== -->
    <v-dialog v-model="deleteDialog.show" max-width="420">
      <v-card v-if="deleteDialog.target" rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="error-lighten-5" size="40" class="mr-3">
            <v-icon color="error-darken-2">mdi-delete</v-icon>
          </v-avatar>
          <div class="text-h6 font-weight-bold">Delete expense?</div>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          This will permanently remove
          <strong>{{ deleteDialog.target.reference }}</strong> ({{ fmtMoney(deleteDialog.target.amount) }}).
        </v-card-text>
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog.show = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" :loading="deleteDialog.saving" @click="doDelete">
            <v-icon start>mdi-delete</v-icon>Delete
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" :timeout="2400">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const route = useRoute()

// ── State ────────────────────────────────────────────────────────
const loading = ref(false)
const bulkBusy = ref(false)
const expenses = ref([])
const categories = ref([])
const suppliers = ref([])
const stats = ref(null)
const selected = ref([])

const view = ref('table')
const section = ref(route.query.section || 'all')

const search = ref('')
const statusFilter = ref(null)
const methodFilter = ref(null)
const categoryFilter = ref(null)
const dateFilter = ref(null)
const sortBy = ref('date_desc')

const snack = ref({ show: false, color: 'success', text: '' })
const notify = (text, color = 'success') => { snack.value = { show: true, color, text } }

// ── Loading ──────────────────────────────────────────────────────
function pickRows(settled) {
  if (settled.status !== 'fulfilled') return []
  const d = settled.value?.data
  return d?.results || (Array.isArray(d) ? d : [])
}
async function loadAll() {
  loading.value = true
  try {
    const [ex, cat, sup, st] = await Promise.allSettled([
      $api.get('/expenses/expenses/', { params: { page_size: 1000, ordering: '-expense_date' } }),
      $api.get('/expenses/categories/', { params: { page_size: 200 } }),
      $api.get('/suppliers/', { params: { page_size: 200 } }),
      $api.get('/expenses/expenses/summary/'),
    ])
    expenses.value = pickRows(ex)
    categories.value = pickRows(cat)
    suppliers.value = pickRows(sup)
    stats.value = st.status === 'fulfilled' ? (st.value?.data || null) : null
  } catch {
    notify('Failed to load expenses', 'error')
  } finally {
    loading.value = false
  }
}
onMounted(loadAll)

// ── Helpers ──────────────────────────────────────────────────────
const fmtMoney = (v) => 'KSh ' + Number(v || 0).toLocaleString(undefined, { maximumFractionDigits: 2 })
const fmtDate = (v) => v ? new Date(v).toLocaleDateString() : '—'
const fmtMonth = (v) => v ? new Date(v).toLocaleDateString(undefined, { year: 'numeric', month: 'short' }) : '—'

const statusOptions = [
  { value: 'pending', label: 'Pending' },
  { value: 'approved', label: 'Approved' },
  { value: 'paid', label: 'Paid' },
  { value: 'rejected', label: 'Rejected' },
  { value: 'cancelled', label: 'Cancelled' },
]
const statusLabel = (s) => statusOptions.find(o => o.value === s)?.label || s
const statusColor = (s) => ({
  pending: 'warning', approved: 'info', paid: 'success',
  rejected: 'error', cancelled: 'grey',
})[s] || 'grey'
const statusIcon = (s) => ({
  pending: 'mdi-clock-outline', approved: 'mdi-check', paid: 'mdi-cash-check',
  rejected: 'mdi-close-octagon', cancelled: 'mdi-cancel',
})[s] || 'mdi-help-circle-outline'
const statusHex = (s) => ({
  pending: '#f59e0b', approved: '#0ea5e9', paid: '#22c55e',
  rejected: '#ef4444', cancelled: '#94a3b8',
})[s] || '#94a3b8'
const statusFilterOptions = statusOptions.map(o => ({ title: o.label, value: o.value }))

const methodOptions = [
  { title: 'Cash', value: 'cash' },
  { title: 'M-Pesa', value: 'mpesa' },
  { title: 'Bank Transfer', value: 'bank' },
  { title: 'Card', value: 'card' },
  { title: 'Cheque', value: 'cheque' },
  { title: 'Other', value: 'other' },
]
const methodFilterOptions = methodOptions
const methodLabel = (m) => methodOptions.find(o => o.value === m)?.title || m
const methodColor = (m) => ({ cash: 'green', mpesa: 'light-green', bank: 'indigo', card: 'purple', cheque: 'amber', other: 'grey' })[m] || 'grey'
const methodIcon = (m) => ({
  cash: 'mdi-cash', mpesa: 'mdi-cellphone', bank: 'mdi-bank',
  card: 'mdi-credit-card', cheque: 'mdi-note-text', other: 'mdi-dots-horizontal',
})[m] || 'mdi-cash'

const dateOptions = [
  { title: 'Today', value: 'today' },
  { title: 'This week', value: 'week' },
  { title: 'This month', value: 'month' },
  { title: 'Last 30 days', value: '30d' },
  { title: 'This quarter', value: 'quarter' },
  { title: 'This year', value: 'year' },
]
function dateFloor(kind) {
  const d = new Date(); d.setHours(0, 0, 0, 0)
  if (kind === 'today') return d
  if (kind === 'week') { d.setDate(d.getDate() - d.getDay()); return d }
  if (kind === 'month') { d.setDate(1); return d }
  if (kind === '30d') { d.setDate(d.getDate() - 30); return d }
  if (kind === 'quarter') { const q = Math.floor(d.getMonth() / 3) * 3; return new Date(d.getFullYear(), q, 1) }
  if (kind === 'year') return new Date(d.getFullYear(), 0, 1)
  return null
}

const sortOptions = [
  { title: 'Newest first', value: 'date_desc' },
  { title: 'Oldest first', value: 'date_asc' },
  { title: 'Highest amount', value: 'amt_desc' },
  { title: 'Lowest amount', value: 'amt_asc' },
  { title: 'Title (A → Z)', value: 'title_asc' },
]

function isOverdue(e) {
  if (!e.due_date) return false
  if (['paid', 'cancelled', 'rejected'].includes(e.status)) return false
  return new Date(e.due_date) < new Date(new Date().toDateString())
}
function daysOverdue(e) {
  if (!e.due_date) return 0
  const ms = new Date().setHours(0, 0, 0, 0) - new Date(e.due_date).setHours(0, 0, 0, 0)
  return Math.max(0, Math.floor(ms / 86400000))
}

// ── Section + filters ────────────────────────────────────────────
const sectionFilters = computed(() => [
  { value: 'all', label: 'All', icon: 'mdi-format-list-bulleted', count: expenses.value.length, color: 'primary' },
  { value: 'pending', label: 'Pending', icon: 'mdi-clock-outline',
    count: expenses.value.filter(e => e.status === 'pending').length, color: 'warning' },
  { value: 'paid', label: 'Paid', icon: 'mdi-cash-check',
    count: expenses.value.filter(e => e.status === 'paid').length, color: 'success' },
  { value: 'overdue', label: 'Overdue', icon: 'mdi-clock-alert',
    count: overdueExpenses.value.length, color: 'error' },
  { value: 'recurring', label: 'Recurring', icon: 'mdi-repeat',
    count: expenses.value.filter(e => e.is_recurring).length, color: 'purple' },
  { value: 'categories', label: 'Categories', icon: 'mdi-shape',
    count: categories.value.length, color: 'rose' },
  { value: 'reports', label: 'Reports', icon: 'mdi-chart-box', color: 'indigo' },
])

const topCategoryChips = computed(() => {
  const counts = new Map()
  expenses.value.forEach(e => {
    if (!e.category) return
    counts.set(e.category, (counts.get(e.category) || 0) + 1)
  })
  const top = categories.value
    .map(c => ({ id: c.id, name: c.name, count: counts.get(c.id) || 0 }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 4)
    .map(c => ({ value: c.id, label: c.name, count: c.count }))
  return [{ value: null, label: 'All', count: null }, ...top]
})

const filtered = computed(() => {
  let rows = [...expenses.value]
  // Section
  if (section.value === 'pending') rows = rows.filter(e => e.status === 'pending')
  else if (section.value === 'paid') rows = rows.filter(e => e.status === 'paid')
  else if (section.value === 'overdue') rows = rows.filter(isOverdue)
  else if (section.value === 'recurring') rows = rows.filter(e => e.is_recurring)
  // Search
  if (search.value) {
    const q = search.value.toLowerCase()
    rows = rows.filter(e =>
      (e.title || '').toLowerCase().includes(q) ||
      (e.reference || '').toLowerCase().includes(q) ||
      (e.vendor || '').toLowerCase().includes(q) ||
      (e.description || '').toLowerCase().includes(q) ||
      (e.payment_reference || '').toLowerCase().includes(q)
    )
  }
  if (statusFilter.value) rows = rows.filter(e => e.status === statusFilter.value)
  if (methodFilter.value) rows = rows.filter(e => e.payment_method === methodFilter.value)
  if (categoryFilter.value != null) rows = rows.filter(e => e.category === categoryFilter.value)
  if (dateFilter.value) {
    const floor = dateFloor(dateFilter.value)
    if (floor) rows = rows.filter(e => new Date(e.expense_date) >= floor)
  }
  // Sort
  const cmp = ({
    date_desc: (a, b) => new Date(b.expense_date) - new Date(a.expense_date),
    date_asc: (a, b) => new Date(a.expense_date) - new Date(b.expense_date),
    amt_desc: (a, b) => Number(b.amount) - Number(a.amount),
    amt_asc: (a, b) => Number(a.amount) - Number(b.amount),
    title_asc: (a, b) => (a.title || '').localeCompare(b.title || ''),
  })[sortBy.value]
  if (cmp) rows.sort(cmp)
  return rows
})
const filteredTotal = computed(() => filtered.value.reduce((s, e) => s + Number(e.amount || 0), 0))

function resetFilters() {
  search.value = ''
  statusFilter.value = null
  methodFilter.value = null
  categoryFilter.value = null
  dateFilter.value = null
  sortBy.value = 'date_desc'
}
function filterByCategory(c) {
  categoryFilter.value = c.id
  section.value = 'all'
}

// ── Derived KPIs ────────────────────────────────────────────────
const monthStart = () => { const d = new Date(); d.setDate(1); d.setHours(0, 0, 0, 0); return d }
const totalThisMonth = computed(() =>
  expenses.value.filter(e => new Date(e.expense_date) >= monthStart())
    .reduce((s, e) => s + Number(e.amount || 0), 0))
const pendingExpenses = computed(() => expenses.value.filter(e => e.status === 'pending'))
const pendingTotal = computed(() => pendingExpenses.value.reduce((s, e) => s + Number(e.amount || 0), 0))
const paidThisMonth = computed(() =>
  expenses.value.filter(e => e.status === 'paid' && new Date(e.expense_date) >= monthStart())
    .reduce((s, e) => s + Number(e.amount || 0), 0))
const overdueExpenses = computed(() => expenses.value.filter(isOverdue))
const overdueTotal = computed(() => overdueExpenses.value.reduce((s, e) => s + Number(e.amount || 0), 0))

const kpis = computed(() => [
  { label: 'This month', value: fmtMoney(totalThisMonth.value), icon: 'mdi-calendar-month', color: 'rose', hint: 'all expenses' },
  { label: 'Pending', value: fmtMoney(pendingTotal.value), icon: 'mdi-clock-outline', color: 'amber', hint: `${pendingExpenses.value.length} item(s)` },
  { label: 'Paid (MTD)', value: fmtMoney(paidThisMonth.value), icon: 'mdi-cash-check', color: 'green', hint: 'this month' },
  { label: 'Overdue', value: fmtMoney(overdueTotal.value), icon: 'mdi-clock-alert', color: 'red', hint: `${overdueExpenses.value.length} item(s)` },
])

// ── Reports derived data ────────────────────────────────────────
const expensesByStatus = computed(() => {
  const totalAmt = expenses.value.reduce((s, e) => s + Number(e.amount || 0), 0) || 1
  return statusOptions.map(o => {
    const rows = expenses.value.filter(e => e.status === o.value)
    const amount = rows.reduce((s, e) => s + Number(e.amount || 0), 0)
    return { key: o.value, count: rows.length, amount, pct: (amount / totalAmt) * 100 }
  }).filter(r => r.count > 0)
})
const topCategories = computed(() => {
  const totalAmt = expenses.value.reduce((s, e) => s + Number(e.amount || 0), 0) || 1
  const map = new Map()
  expenses.value.forEach(e => {
    const key = e.category || 0
    const cur = map.get(key) || { id: e.category, name: e.category_name || 'Uncategorised', color: e.category_color || '', count: 0, total: 0 }
    cur.count += 1
    cur.total += Number(e.amount || 0)
    map.set(key, cur)
  })
  return [...map.values()]
    .map(r => ({ ...r, pct: (r.total / totalAmt) * 100 }))
    .sort((a, b) => b.total - a.total).slice(0, 8)
})
const topVendors = computed(() => {
  const map = new Map()
  expenses.value.forEach(e => {
    const k = (e.vendor || '').trim()
    if (!k) return
    const cur = map.get(k) || { name: k, count: 0, total: 0 }
    cur.count += 1
    cur.total += Number(e.amount || 0)
    map.set(k, cur)
  })
  return [...map.values()].sort((a, b) => b.total - a.total).slice(0, 10)
})
const categoriesEnriched = computed(() => {
  const totalAmt = expenses.value.reduce((s, e) => s + Number(e.amount || 0), 0) || 1
  return categories.value.map(c => ({ ...c, _share: (Number(c.total_spent || 0) / totalAmt) * 100 }))
})
const categoryShare = (c) => Math.min(100, c._share || 0)

const trendSeries = computed(() => {
  if (stats.value?.trend?.length) {
    return stats.value.trend.map(t => ({ month: t.month, total: Number(t.total || 0) }))
  }
  const out = []
  const now = new Date()
  for (let i = 11; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1)
    const next = new Date(d.getFullYear(), d.getMonth() + 1, 1)
    const total = expenses.value
      .filter(e => { const ed = new Date(e.expense_date); return ed >= d && ed < next })
      .reduce((s, e) => s + Number(e.amount || 0), 0)
    out.push({ month: d.toISOString().slice(0, 10), total })
  }
  return out
})
const trendTotal = computed(() => trendSeries.value.reduce((s, m) => s + Number(m.total || 0), 0))

const reportTiles = computed(() => {
  const last = trendSeries.value.at(-1)?.total || 0
  const prev = trendSeries.value.at(-2)?.total || 0
  const delta = prev ? ((last - prev) / prev) * 100 : 0
  const avg = trendSeries.value.length
    ? trendSeries.value.reduce((s, m) => s + m.total, 0) / trendSeries.value.length
    : 0
  return [
    { label: 'Last month', value: fmtMoney(last),
      delta: prev ? `${delta >= 0 ? '+' : ''}${delta.toFixed(1)}% vs prior` : '—',
      deltaClass: delta >= 0 ? 'text-error' : 'text-success' },
    { label: 'Avg / month', value: fmtMoney(avg), delta: '12-mo average', deltaClass: 'text-medium-emphasis' },
    { label: 'Vendors', value: topVendors.value.length, delta: 'unique vendors', deltaClass: 'text-medium-emphasis' },
    { label: 'Categories', value: categories.value.length,
      delta: `${categoriesEnriched.value.filter(c => c.is_active).length} active`, deltaClass: 'text-medium-emphasis' },
  ]
})
function trendDelta(series, i) {
  if (i === 0) return '—'
  const cur = series[i].total, prev = series[i - 1].total
  if (!prev) return cur ? '+∞' : '—'
  const d = ((cur - prev) / prev) * 100
  return `${d >= 0 ? '+' : ''}${d.toFixed(1)}%`
}
function trendDeltaClass(series, i) {
  if (i === 0) return 'text-medium-emphasis'
  const cur = series[i].total, prev = series[i - 1].total
  if (!prev) return 'text-medium-emphasis'
  return cur > prev ? 'text-error' : 'text-success'
}

// ── Table headers ────────────────────────────────────────────────
const headers = [
  { title: 'Date', key: 'expense_date', sortable: true, width: 130 },
  { title: 'Title', key: 'title', sortable: true },
  { title: 'Category', key: 'category_name' },
  { title: 'Method', key: 'payment_method' },
  { title: 'Amount', key: 'amount', align: 'end', sortable: true },
  { title: 'Status', key: 'status', sortable: true },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 130 },
]

// ── Detail dialog ────────────────────────────────────────────────
const detailDialog = ref(false)
const detailItem = ref(null)
function openDetail(item) { detailItem.value = item; detailDialog.value = true }

// ── Expense dialog ───────────────────────────────────────────────
const expenseForm = ref(null)
const expenseFormValid = ref(false)
const blankExpense = () => ({
  reference: '', title: '', description: '',
  category: null, amount: 0, tax_amount: 0,
  expense_date: new Date().toISOString().slice(0, 10),
  due_date: '', payment_method: 'cash', payment_reference: '',
  vendor: '', supplier: null, status: 'pending',
  is_recurring: false, recurring_period: 'monthly',
  receipt: null, notes: '',
})
const expenseDialog = ref({ show: false, editing: false, saving: false, data: blankExpense(), receiptFile: null })

function openExpense(item = null) {
  expenseDialog.value = {
    show: true, editing: !!item, saving: false,
    data: item ? { ...item } : blankExpense(),
    receiptFile: null,
  }
}
function duplicateExpense(item) {
  openExpense({
    ...item, id: undefined, reference: '',
    expense_date: new Date().toISOString().slice(0, 10),
    status: 'pending', approved_at: null, paid_at: null,
  })
}
async function saveExpense() {
  if (!expenseForm.value) return
  const { valid } = await expenseForm.value.validate()
  if (!valid) return
  expenseDialog.value.saving = true
  try {
    const d = expenseDialog.value.data
    const file = expenseDialog.value.receiptFile
    let payload, headers = {}
    const f = Array.isArray(file) ? file[0] : file
    if (f) {
      const fd = new FormData()
      Object.entries(d).forEach(([k, v]) => {
        if (k === 'receipt') return
        if (v === null || v === undefined || v === '') return
        fd.append(k, v)
      })
      fd.append('receipt', f)
      payload = fd
      headers['Content-Type'] = 'multipart/form-data'
    } else {
      payload = { ...d }
      delete payload.receipt
    }
    if (expenseDialog.value.editing && d.id) {
      await $api.patch(`/expenses/expenses/${d.id}/`, payload, { headers })
      notify('Expense updated')
    } else {
      await $api.post('/expenses/expenses/', payload, { headers })
      notify('Expense created')
    }
    expenseDialog.value.show = false
    await loadAll()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Save failed', 'error')
  } finally {
    expenseDialog.value.saving = false
  }
}

// ── Category dialog ──────────────────────────────────────────────
const colorPalette = ['#ef4444','#f97316','#f59e0b','#eab308','#84cc16','#22c55e','#10b981','#14b8a6','#06b6d4','#3b82f6','#6366f1','#8b5cf6','#a855f7','#d946ef','#ec4899','#64748b']
const categorySuggestions = [
  { name: 'Reagents',          icon: 'mdi-flask',                 color: '#3b82f6', description: 'Lab reagents & chemicals' },
  { name: 'Consumables',       icon: 'mdi-test-tube',             color: '#06b6d4', description: 'Tubes, tips, gloves, swabs' },
  { name: 'Equipment',         icon: 'mdi-cog',                   color: '#6366f1', description: 'Lab equipment purchases' },
  { name: 'Maintenance',       icon: 'mdi-wrench',                color: '#f59e0b', description: 'Equipment service & repair' },
  { name: 'Calibration / QC',  icon: 'mdi-target',                color: '#8b5cf6', description: 'Calibrators & QC materials' },
  { name: 'Utilities',         icon: 'mdi-flash',                 color: '#eab308', description: 'Power, water, gas' },
  { name: 'Rent',              icon: 'mdi-home-city',             color: '#64748b', description: 'Premises rent' },
  { name: 'Salaries',          icon: 'mdi-account-cash',          color: '#10b981', description: 'Staff payroll' },
  { name: 'Training',          icon: 'mdi-school',                color: '#a855f7', description: 'Staff training & CME' },
  { name: 'Licenses',          icon: 'mdi-certificate',           color: '#ec4899', description: 'Regulatory & licensing fees' },
  { name: 'Software',          icon: 'mdi-laptop',                color: '#14b8a6', description: 'Software & subscriptions' },
  { name: 'Transport',         icon: 'mdi-truck',                 color: '#f97316', description: 'Sample transport & logistics' },
  { name: 'Waste Disposal',    icon: 'mdi-delete-variant',        color: '#84cc16', description: 'Biohazard & waste disposal' },
  { name: 'Marketing',         icon: 'mdi-bullhorn',              color: '#d946ef', description: 'Marketing & promotion' },
  { name: 'Insurance',         icon: 'mdi-shield-check',          color: '#0ea5e9', description: 'Insurance premiums' },
  { name: 'Miscellaneous',     icon: 'mdi-dots-horizontal-circle',color: '#94a3b8', description: 'Other expenses' },
]
function applyCategorySuggestion(s) {
  categoryDialog.value.data.name = s.name
  if (!categoryDialog.value.data.description) categoryDialog.value.data.description = s.description
  categoryDialog.value.data.color = s.color
}
const categoryDialog = ref({ show: false, editing: false, saving: false, data: { name: '', description: '', color: '#e11d48', is_active: true } })
function openCategory(item = null) {
  categoryDialog.value = {
    show: true, editing: !!item, saving: false,
    data: item ? { ...item } : { name: '', description: '', color: '#e11d48', is_active: true },
  }
}
async function saveCategory() {
  const d = categoryDialog.value.data
  if (!d.name) { notify('Name is required', 'error'); return }
  categoryDialog.value.saving = true
  try {
    if (categoryDialog.value.editing && d.id) {
      await $api.patch(`/expenses/categories/${d.id}/`, d)
      notify('Category updated')
    } else {
      await $api.post('/expenses/categories/', d)
      notify('Category created')
    }
    categoryDialog.value.show = false
    await loadAll()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Save failed', 'error')
  } finally {
    categoryDialog.value.saving = false
  }
}
async function deleteCategory(c) {
  if (!confirm(`Delete category "${c.name}"?`)) return
  try {
    await $api.delete(`/expenses/categories/${c.id}/`)
    notify('Category deleted')
    await loadAll()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Delete failed', 'error')
  }
}

// ── Action dialog (pay/reject) ───────────────────────────────────
const actionDialog = ref({ show: false, kind: '', target: null, payload: {}, saving: false })
function openPay(item) {
  actionDialog.value = { show: true, kind: 'mark_paid', target: item, saving: false,
    payload: { payment_method: item.payment_method || 'cash', payment_reference: item.payment_reference || '' } }
}
function openReject(item) {
  actionDialog.value = { show: true, kind: 'reject', target: item, payload: { reason: '' }, saving: false }
}
async function quickAction(item, kind) {
  try {
    await $api.post(`/expenses/expenses/${item.id}/${kind === 'mark_paid' ? 'mark_paid' : kind}/`, {})
    notify(`Expense ${kind === 'approve' ? 'approved' : kind}`)
    await loadAll()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Action failed', 'error')
  }
}
async function confirmAction() {
  actionDialog.value.saving = true
  try {
    const url = `/expenses/expenses/${actionDialog.value.target.id}/${actionDialog.value.kind}/`
    await $api.post(url, actionDialog.value.payload || {})
    notify('Done')
    actionDialog.value.show = false
    await loadAll()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Action failed', 'error')
  } finally {
    actionDialog.value.saving = false
  }
}
async function bulkAction(kind) {
  if (!selected.value.length) return
  if (!confirm(`${kind.replace('_', ' ')} ${selected.value.length} expense(s)?`)) return
  bulkBusy.value = true
  for (const id of selected.value) {
    try { await $api.post(`/expenses/expenses/${id}/${kind}/`, {}) } catch { /* ignore */ }
  }
  bulkBusy.value = false
  selected.value = []
  notify('Bulk action complete')
  await loadAll()
}

// ── Delete ───────────────────────────────────────────────────────
const deleteDialog = ref({ show: false, target: null, saving: false })
function confirmDelete(item) { deleteDialog.value = { show: true, target: item, saving: false } }
async function doDelete() {
  deleteDialog.value.saving = true
  try {
    await $api.delete(`/expenses/expenses/${deleteDialog.value.target.id}/`)
    notify('Expense deleted')
    deleteDialog.value.show = false
    await loadAll()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Delete failed', 'error')
  } finally {
    deleteDialog.value.saving = false
  }
}

// ── Export ───────────────────────────────────────────────────────
function csvEscape(v) {
  const s = v == null ? '' : String(v)
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s
}
function downloadCsv(filename, rows) {
  const csv = rows.map(r => r.map(csvEscape).join(',')).join('\n')
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = filename; a.click()
  URL.revokeObjectURL(url)
}
function exportExpenses() {
  const rows = [['Reference','Title','Category','Vendor','Date','Due','Method','Amount','Tax','Total','Status']]
  filtered.value.forEach(e => rows.push([
    e.reference, e.title, e.category_name || '', e.vendor || '',
    e.expense_date, e.due_date || '', methodLabel(e.payment_method),
    e.amount, e.tax_amount || 0,
    Number(e.amount || 0) + Number(e.tax_amount || 0),
    statusLabel(e.status),
  ]))
  downloadCsv(`lab-expenses-${new Date().toISOString().slice(0,10)}.csv`, rows)
}
function exportTrend() {
  const rows = [['Month','Total']]
  trendSeries.value.forEach(m => rows.push([m.month, m.total]))
  downloadCsv('lab-expenses-trend.csv', rows)
}
</script>

<style scoped>
.kpi { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.exp-table :deep(tbody tr) { cursor: pointer; }
.exp-card,
.cat-card {
  position: relative;
  overflow: hidden;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  transition: transform 120ms ease, box-shadow 120ms ease;
}
.exp-card { cursor: pointer; }
.exp-card:hover,
.cat-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.06); }
.exp-band { position: absolute; top: 0; left: 0; right: 0; height: 3px; }
.bulk-bar {
  border: 1px solid rgba(var(--v-theme-primary), 0.2);
  background: rgba(var(--v-theme-primary), 0.04);
}
.cat-dot { box-shadow: 0 0 0 2px rgba(255,255,255,0.6); }
.min-width-0 { min-width: 0; }
.font-monospace { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }

.report-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.875rem;
}
.report-table th,
.report-table td {
  padding: 8px 10px;
  border-bottom: 1px solid rgba(0,0,0,0.06);
}
.report-table th {
  font-weight: 600;
  text-align: left;
  color: rgba(0,0,0,0.6);
  text-transform: uppercase;
  font-size: 0.72rem;
  letter-spacing: 0.04em;
}
.report-table tr:hover td { background: rgba(244,63,94,0.04); }
</style>
