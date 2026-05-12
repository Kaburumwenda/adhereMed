<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="green-lighten-5" size="48">
        <v-icon color="green-darken-2" size="28">mdi-receipt-text</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Lab Billing</div>
        <div class="text-body-2 text-medium-emphasis">
          Invoices · payments · revenue & receivables
        </div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh"
             :loading="r.loading.value" @click="reload">Refresh</v-btn>
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-tray-arrow-down"
             @click="exportCsv">Export</v-btn>
      <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openNew">New Invoice</v-btn>
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

    <!-- Status pills -->
    <v-card flat rounded="lg" class="mt-4 pa-3">
      <div class="d-flex flex-wrap align-center ga-2">
        <v-chip
          v-for="s in statusPills" :key="s.key"
          :color="statusFilter === s.value ? (s.color || 'primary') : undefined"
          :variant="statusFilter === s.value ? 'flat' : 'tonal'"
          size="small" @click="statusFilter = s.value"
        >
          <v-icon v-if="s.icon" size="14" start>{{ s.icon }}</v-icon>
          {{ s.label }}<span class="ml-2 font-weight-bold">{{ s.count }}</span>
        </v-chip>

        <v-divider vertical class="mx-2" />

        <v-chip
          v-for="p in payerPills" :key="p.value || 'all'"
          :color="payerFilter === p.value ? 'indigo' : undefined"
          :variant="payerFilter === p.value ? 'flat' : 'tonal'"
          size="small" @click="payerFilter = p.value"
        >
          <v-icon size="14" start>{{ PAYER_META[p.value]?.icon || 'mdi-account-cash' }}</v-icon>
          {{ p.label }}
          <span v-if="p.count != null" class="ml-2 font-weight-bold">{{ p.count }}</span>
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
        <v-col cols="12" md="4">
          <v-text-field v-model="r.search.value" prepend-inner-icon="mdi-magnify"
                        placeholder="Search by invoice #, patient…"
                        variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="3">
          <v-text-field v-model="dateFrom" type="date" label="From"
                        prepend-inner-icon="mdi-calendar-start"
                        variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="3">
          <v-text-field v-model="dateTo" type="date" label="To"
                        prepend-inner-icon="mdi-calendar-end"
                        variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="12" md="2">
          <v-select v-model="sortBy" :items="sortOptions"
                    label="Sort" prepend-inner-icon="mdi-sort"
                    variant="outlined" density="compact" hide-details />
        </v-col>
      </v-row>
    </v-card>

    <!-- Bulk action bar -->
    <v-slide-y-transition>
      <v-card v-if="selected.length" flat rounded="lg" class="mt-3 pa-3 bulk-bar">
        <div class="d-flex align-center ga-2 flex-wrap">
          <v-icon color="primary">mdi-check-all</v-icon>
          <span class="font-weight-medium">{{ selected.length }} selected</span>
          <span class="text-caption text-medium-emphasis ml-2">
            Total {{ formatMoney(selectedTotals.total) }} · Outstanding
            {{ formatMoney(selectedTotals.balance) }}
          </span>
          <v-spacer />
          <v-btn size="small" variant="tonal" color="success" prepend-icon="mdi-send"
                 :loading="bulkBusy" @click="bulkSetStatus('issued')">Issue</v-btn>
          <v-btn size="small" variant="tonal" color="grey-darken-2" prepend-icon="mdi-cancel"
                 :loading="bulkBusy" @click="bulkSetStatus('void')">Void</v-btn>
          <v-btn size="small" variant="tonal" color="primary" prepend-icon="mdi-printer-outline"
                 @click="bulkPrint">Print</v-btn>
          <v-btn size="small" variant="text" @click="selected = []">Clear</v-btn>
        </div>
      </v-card>
    </v-slide-y-transition>

    <!-- Table view -->
    <v-card v-if="view === 'table'" flat rounded="lg" class="mt-3">
      <v-data-table
        v-model="selected"
        show-select
        :headers="headers"
        :items="filtered"
        :loading="r.loading.value"
        :items-per-page="20"
        item-value="id"
        hover
        class="invoice-table"
        @click:row="(_, { item }) => openDetail(item)"
      >
        <template #loading><v-skeleton-loader type="table-row@5" /></template>
        <template #item.invoice_number="{ item }">
          <div class="d-flex align-center">
            <v-avatar :color="statusColor(item.status)" size="34" class="mr-3">
              <v-icon size="16" color="white">{{ statusIcon(item.status) }}</v-icon>
            </v-avatar>
            <div class="min-width-0">
              <div class="font-weight-medium font-monospace text-truncate">
                {{ item.invoice_number }}
              </div>
              <div class="text-caption text-medium-emphasis text-truncate">
                {{ item.patient_name || '—' }}
              </div>
            </div>
          </div>
        </template>
        <template #item.payer_type="{ value, item }">
          <v-chip size="x-small" variant="tonal" :color="PAYER_META[value]?.color || 'grey'">
            <v-icon size="12" start>{{ PAYER_META[value]?.icon || 'mdi-account' }}</v-icon>
            {{ payerLabel(value) }}
          </v-chip>
          <div v-if="item.insurance_scheme" class="text-caption text-medium-emphasis mt-1">
            {{ item.insurance_scheme }}
          </div>
        </template>
        <template #item.total="{ value }">
          <span class="font-monospace">{{ formatMoney(value) }}</span>
        </template>
        <template #item.amount_paid="{ value }">
          <span class="font-monospace text-success">{{ formatMoney(value) }}</span>
        </template>
        <template #item.balance="{ item }">
          <span class="font-monospace font-weight-bold"
                :class="Number(item.balance) > 0 ? 'text-error' : 'text-medium-emphasis'">
            {{ formatMoney(item.balance) }}
          </span>
        </template>
        <template #item.status="{ value }">
          <v-chip :color="statusColor(value)" size="small" variant="flat" class="text-capitalize">
            <v-icon size="14" start>{{ statusIcon(value) }}</v-icon>{{ statusLabel(value) }}
          </v-chip>
        </template>
        <template #item.created_at="{ value }">
          <div class="text-caption">{{ formatDate(value) }}</div>
          <div class="text-caption text-medium-emphasis">{{ relativeTime(value) }}</div>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end" @click.stop>
            <v-tooltip text="Record payment" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-cash-plus" variant="text" size="small"
                       color="success" :disabled="item.status === 'paid' || item.status === 'void'"
                       @click="openPay(item)" />
              </template>
            </v-tooltip>
            <v-tooltip text="Edit" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-pencil-outline" variant="text" size="small"
                       color="primary" @click="openEdit(item)" />
              </template>
            </v-tooltip>
            <v-menu>
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" />
              </template>
              <v-list density="compact">
                <v-list-item prepend-icon="mdi-eye" title="View" @click="openDetail(item)" />
                <v-list-item prepend-icon="mdi-printer-outline" title="Print"
                             @click="printInvoice(item)" />
                <v-list-item v-if="item.status === 'draft'" prepend-icon="mdi-send"
                             title="Issue" @click="setStatus(item, 'issued')" />
                <v-list-item v-if="item.status !== 'void' && item.status !== 'paid'"
                             prepend-icon="mdi-cancel" title="Void"
                             @click="setStatus(item, 'void')" />
                <v-divider />
                <v-list-item prepend-icon="mdi-delete" title="Delete" base-color="error"
                             @click="confirmDelete(item)" />
              </v-list>
            </v-menu>
          </div>
        </template>
        <template #no-data>
          <div class="pa-8 text-center">
            <v-icon size="56" color="grey-lighten-1">mdi-receipt-text-remove</v-icon>
            <div class="text-subtitle-1 font-weight-medium mt-2">No invoices found</div>
            <div class="text-body-2 text-medium-emphasis mb-4">Adjust filters or create a new invoice.</div>
            <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openNew">New Invoice</v-btn>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- Grid view -->
    <div v-else class="mt-3">
      <div v-if="r.loading.value" class="d-flex justify-center pa-12">
        <v-progress-circular indeterminate color="primary" />
      </div>
      <div v-else-if="!filtered.length" class="pa-8 text-center">
        <v-icon size="56" color="grey-lighten-1">mdi-receipt-text-remove</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-2">No invoices found</div>
        <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" class="mt-3" @click="openNew">New Invoice</v-btn>
      </div>
      <v-row v-else dense>
        <v-col v-for="i in filtered" :key="i.id" cols="12" sm="6" md="4" lg="3">
          <v-card flat rounded="lg" class="invoice-card pa-3 h-100" hover @click="openDetail(i)">
            <div class="invoice-band" :style="{ background: statusHex(i.status) }" />
            <div class="d-flex align-center mb-2">
              <v-chip :color="statusColor(i.status)" size="x-small" variant="flat"
                      class="text-capitalize">
                <v-icon size="12" start>{{ statusIcon(i.status) }}</v-icon>{{ statusLabel(i.status) }}
              </v-chip>
              <v-spacer />
              <v-chip size="x-small" variant="tonal" :color="PAYER_META[i.payer_type]?.color">
                <v-icon size="11" start>{{ PAYER_META[i.payer_type]?.icon }}</v-icon>
                {{ payerLabel(i.payer_type) }}
              </v-chip>
            </div>
            <div class="font-monospace font-weight-bold">{{ i.invoice_number }}</div>
            <div class="text-caption text-medium-emphasis text-truncate mb-3">
              {{ i.patient_name || '—' }}
            </div>
            <v-divider class="mb-2" />
            <div class="d-flex justify-space-between text-caption">
              <span class="text-medium-emphasis">Total</span>
              <span class="font-monospace">{{ formatMoney(i.total) }}</span>
            </div>
            <div class="d-flex justify-space-between text-caption">
              <span class="text-medium-emphasis">Paid</span>
              <span class="font-monospace text-success">{{ formatMoney(i.amount_paid) }}</span>
            </div>
            <div class="d-flex justify-space-between text-caption">
              <span class="text-medium-emphasis">Balance</span>
              <span class="font-monospace font-weight-bold"
                    :class="Number(i.balance) > 0 ? 'text-error' : ''">
                {{ formatMoney(i.balance) }}
              </span>
            </div>
            <v-progress-linear :model-value="paidPct(i)" height="6" rounded
                               :color="Number(i.balance) <= 0 ? 'success' : 'amber'"
                               class="mt-2" />
            <div class="text-caption text-medium-emphasis mt-2">{{ formatDate(i.created_at) }}</div>
          </v-card>
        </v-col>
      </v-row>
    </div>

    <!-- Form dialog -->
    <v-dialog v-model="formDialog" max-width="1100" scrollable persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="green-lighten-5" size="40" class="mr-3">
            <v-icon color="green-darken-2">{{ form.id ? 'mdi-pencil' : 'mdi-plus' }}</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">INVOICE</div>
            <div class="text-h6 font-weight-bold">
              {{ form.id ? `Edit ${form.invoice_number || 'invoice'}` : 'New invoice' }}
            </div>
          </div>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" @click="formDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          <v-form ref="formRef" @submit.prevent="save">
            <v-row dense>
              <v-col cols="12" md="6">
                <v-autocomplete v-model="form.lab_order" :items="orderOptions"
                                item-title="label" item-value="id"
                                label="Lab Order *" prepend-inner-icon="mdi-clipboard-list"
                                variant="outlined" density="comfortable"
                                :rules="[required]" @update:model-value="onOrderChange" />
              </v-col>
              <v-col cols="12" md="6">
                <v-autocomplete v-model="form.patient" :items="patientOptions"
                                item-title="display" item-value="id"
                                label="Patient *" prepend-inner-icon="mdi-account"
                                variant="outlined" density="comfortable" :rules="[required]" />
              </v-col>
              <v-col cols="12" md="4">
                <v-select v-model="form.payer_type" :items="PAYERS"
                          label="Payer *" prepend-inner-icon="mdi-account-cash"
                          variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" md="4">
                <v-text-field v-model="form.insurance_scheme" label="Insurance scheme"
                              :disabled="form.payer_type !== 'insurance'"
                              prepend-inner-icon="mdi-shield-account"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" md="4">
                <v-autocomplete v-model="form.referring_facility" :items="facilities"
                                item-title="name" item-value="id"
                                label="Referring facility"
                                prepend-inner-icon="mdi-hospital-building"
                                variant="outlined" density="comfortable" clearable />
              </v-col>

              <v-col cols="12">
                <div class="d-flex align-center mb-2">
                  <v-icon color="indigo" class="mr-2">mdi-format-list-checks</v-icon>
                  <span class="text-subtitle-2 font-weight-bold">Line items</span>
                  <v-spacer />
                  <v-btn size="small" variant="tonal" color="primary"
                         prepend-icon="mdi-plus" @click="addItem()">Add line</v-btn>
                </div>
                <v-table density="compact" class="line-table">
                  <thead>
                    <tr>
                      <th style="width:36%">Description</th>
                      <th style="width:18%">Test / Panel</th>
                      <th style="width:9%">Qty</th>
                      <th style="width:12%">Unit price</th>
                      <th style="width:12%">Discount</th>
                      <th style="width:11%" class="text-end">Amount</th>
                      <th style="width:40px"></th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="(it, idx) in form.items" :key="idx">
                      <td>
                        <v-text-field v-model="it.description" density="compact"
                                      variant="plain" hide-details placeholder="Description *" />
                      </td>
                      <td>
                        <v-autocomplete v-model="it.test" :items="catalog"
                                        item-title="name" item-value="id"
                                        density="compact" variant="plain" hide-details
                                        clearable placeholder="Test"
                                        @update:model-value="v => onPickTest(it, v)" />
                      </td>
                      <td>
                        <v-text-field v-model.number="it.qty" type="number" min="1"
                                      density="compact" variant="plain" hide-details
                                      @update:model-value="recalcItem(it)" />
                      </td>
                      <td>
                        <v-text-field v-model.number="it.unit_price" type="number" step="0.01"
                                      density="compact" variant="plain" hide-details
                                      @update:model-value="recalcItem(it)" />
                      </td>
                      <td>
                        <v-text-field v-model.number="it.discount" type="number" step="0.01"
                                      density="compact" variant="plain" hide-details
                                      @update:model-value="recalcItem(it)" />
                      </td>
                      <td class="text-end font-monospace">{{ formatMoney(it.amount) }}</td>
                      <td class="text-end">
                        <v-btn icon="mdi-close" size="x-small" variant="text"
                               @click="form.items.splice(idx, 1); recalcTotals()" />
                      </td>
                    </tr>
                    <tr v-if="!form.items.length">
                      <td colspan="7" class="text-center text-medium-emphasis py-4">
                        No items. Click <strong>Add line</strong> to start.
                      </td>
                    </tr>
                  </tbody>
                </v-table>
              </v-col>

              <v-col cols="12" md="6">
                <v-textarea v-model="form.notes" label="Notes" rows="3" auto-grow
                            prepend-inner-icon="mdi-text"
                            variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" md="6">
                <v-card flat rounded="lg" class="totals pa-3">
                  <div class="d-flex justify-space-between mb-1">
                    <span class="text-medium-emphasis">Subtotal</span>
                    <span class="font-monospace">{{ formatMoney(form.subtotal) }}</span>
                  </div>
                  <div class="d-flex justify-space-between align-center mb-1">
                    <span class="text-medium-emphasis">Discount</span>
                    <v-text-field v-model.number="form.discount" type="number" step="0.01"
                                  density="compact" hide-details variant="outlined"
                                  style="max-width:130px" @update:model-value="recalcTotals" />
                  </div>
                  <div class="d-flex justify-space-between align-center mb-1">
                    <span class="text-medium-emphasis">Tax</span>
                    <v-text-field v-model.number="form.tax" type="number" step="0.01"
                                  density="compact" hide-details variant="outlined"
                                  style="max-width:130px" @update:model-value="recalcTotals" />
                  </div>
                  <v-divider class="my-2" />
                  <div class="d-flex justify-space-between">
                    <span class="text-subtitle-2 font-weight-bold">Total</span>
                    <span class="text-subtitle-1 font-weight-bold font-monospace">
                      {{ formatMoney(form.total) }}
                    </span>
                  </div>
                </v-card>
              </v-col>
            </v-row>
          </v-form>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="formDialog = false">Cancel</v-btn>
          <v-btn variant="tonal" color="grey-darken-2" :loading="r.saving.value"
                 @click="save('draft')">
            <v-icon start>mdi-content-save-outline</v-icon>Save draft
          </v-btn>
          <v-btn color="primary" rounded="lg" :loading="r.saving.value" @click="save('issued')">
            <v-icon start>mdi-send</v-icon>{{ form.id ? 'Update & Issue' : 'Save & Issue' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Detail dialog -->
    <v-dialog v-model="detailDialog" max-width="900" scrollable>
      <v-card v-if="detailItem" rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar :color="statusColor(detailItem.status)" size="44" class="mr-3">
            <v-icon size="22" color="white">{{ statusIcon(detailItem.status) }}</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">
              {{ statusLabel(detailItem.status) }} · {{ payerLabel(detailItem.payer_type) }}
            </div>
            <div class="text-h6 font-weight-bold font-monospace">{{ detailItem.invoice_number }}</div>
          </div>
          <v-spacer />
          <v-chip size="small" variant="tonal" class="mr-2">
            Balance <strong class="ml-1 font-monospace">{{ formatMoney(detailItem.balance) }}</strong>
          </v-chip>
          <v-btn icon="mdi-close" variant="text" @click="detailDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          <v-row dense>
            <v-col cols="6" md="3">
              <div class="text-caption text-medium-emphasis">Patient</div>
              <div>{{ detailItem.patient_name || '—' }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-medium-emphasis">Lab Order</div>
              <div class="font-monospace">#{{ detailItem.lab_order }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-medium-emphasis">Insurance</div>
              <div>{{ detailItem.insurance_scheme || '—' }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-medium-emphasis">Referring</div>
              <div>{{ detailItem.referring_facility_name || '—' }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-medium-emphasis">Created</div>
              <div>{{ formatDateTime(detailItem.created_at) }}</div>
            </v-col>
          </v-row>

          <v-divider class="my-4" />
          <div class="d-flex align-center mb-2">
            <v-icon color="indigo" class="mr-2">mdi-format-list-checks</v-icon>
            <span class="text-subtitle-2 font-weight-bold">Items ({{ (detailItem.items || []).length }})</span>
          </div>
          <v-table density="compact" v-if="(detailItem.items || []).length">
            <thead>
              <tr>
                <th>Description</th>
                <th class="text-end">Qty</th>
                <th class="text-end">Unit price</th>
                <th class="text-end">Discount</th>
                <th class="text-end">Amount</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="it in detailItem.items" :key="it.id">
                <td>{{ it.description }}</td>
                <td class="text-end font-monospace">{{ it.qty }}</td>
                <td class="text-end font-monospace">{{ formatMoney(it.unit_price) }}</td>
                <td class="text-end font-monospace">{{ formatMoney(it.discount) }}</td>
                <td class="text-end font-monospace font-weight-bold">{{ formatMoney(it.amount) }}</td>
              </tr>
            </tbody>
          </v-table>
          <div v-else class="text-caption text-medium-emphasis pa-3 text-center">No items.</div>

          <v-row dense class="mt-3">
            <v-col cols="12" md="6">
              <div class="d-flex align-center mb-2">
                <v-icon color="green" class="mr-2">mdi-cash-multiple</v-icon>
                <span class="text-subtitle-2 font-weight-bold">
                  Payments ({{ (detailItem.payments || []).length }})
                </span>
                <v-spacer />
                <v-btn v-if="detailItem.status !== 'paid' && detailItem.status !== 'void'"
                       size="small" variant="tonal" color="success" prepend-icon="mdi-plus"
                       @click="openPay(detailItem)">Record</v-btn>
              </div>
              <v-list v-if="(detailItem.payments || []).length" density="compact"
                      class="bg-transparent">
                <v-list-item v-for="p in detailItem.payments" :key="p.id"
                             :title="`${methodLabel(p.method)} · ${formatMoney(p.amount)}`"
                             :subtitle="`${formatDateTime(p.received_at)} · ${p.received_by_name || '—'} ${p.reference ? '· ref ' + p.reference : ''}`">
                  <template #prepend>
                    <v-avatar :color="methodColor(p.method)" size="28">
                      <v-icon size="14" color="white">{{ methodIcon(p.method) }}</v-icon>
                    </v-avatar>
                  </template>
                </v-list-item>
              </v-list>
              <div v-else class="text-caption text-medium-emphasis pa-3 text-center">
                No payments yet.
              </div>
            </v-col>
            <v-col cols="12" md="6">
              <v-card flat rounded="lg" class="totals pa-3">
                <div class="d-flex justify-space-between mb-1">
                  <span class="text-medium-emphasis">Subtotal</span>
                  <span class="font-monospace">{{ formatMoney(detailItem.subtotal) }}</span>
                </div>
                <div class="d-flex justify-space-between mb-1">
                  <span class="text-medium-emphasis">Discount</span>
                  <span class="font-monospace">−{{ formatMoney(detailItem.discount) }}</span>
                </div>
                <div class="d-flex justify-space-between mb-1">
                  <span class="text-medium-emphasis">Tax</span>
                  <span class="font-monospace">{{ formatMoney(detailItem.tax) }}</span>
                </div>
                <v-divider class="my-2" />
                <div class="d-flex justify-space-between mb-1">
                  <span class="text-subtitle-2 font-weight-bold">Total</span>
                  <span class="font-monospace font-weight-bold">{{ formatMoney(detailItem.total) }}</span>
                </div>
                <div class="d-flex justify-space-between mb-1">
                  <span class="text-medium-emphasis">Paid</span>
                  <span class="font-monospace text-success">{{ formatMoney(detailItem.amount_paid) }}</span>
                </div>
                <v-divider class="my-2" />
                <div class="d-flex justify-space-between">
                  <span class="text-subtitle-2 font-weight-bold">Balance</span>
                  <span class="font-monospace font-weight-bold"
                        :class="Number(detailItem.balance) > 0 ? 'text-error' : ''">
                    {{ formatMoney(detailItem.balance) }}
                  </span>
                </div>
                <v-progress-linear :model-value="paidPct(detailItem)" height="6" rounded
                                   :color="Number(detailItem.balance) <= 0 ? 'success' : 'amber'"
                                   class="mt-2" />
              </v-card>
            </v-col>
            <v-col v-if="detailItem.notes" cols="12">
              <v-divider class="my-2" />
              <div class="text-caption text-medium-emphasis mb-1">Notes</div>
              <div>{{ detailItem.notes }}</div>
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3 flex-wrap ga-1">
          <v-btn variant="text" prepend-icon="mdi-printer-outline" @click="printInvoice(detailItem)">Print</v-btn>
          <v-btn v-if="detailItem.status === 'draft'" variant="text" color="success"
                 prepend-icon="mdi-send" @click="setStatus(detailItem, 'issued')">Issue</v-btn>
          <v-btn v-if="detailItem.status !== 'void' && detailItem.status !== 'paid'"
                 variant="text" color="grey-darken-2"
                 prepend-icon="mdi-cancel" @click="setStatus(detailItem, 'void')">Void</v-btn>
          <v-spacer />
          <v-btn variant="text" @click="detailDialog = false">Close</v-btn>
          <v-btn v-if="detailItem.status !== 'paid' && detailItem.status !== 'void'"
                 color="success" rounded="lg" prepend-icon="mdi-cash-plus"
                 @click="openPay(detailItem)">Record payment</v-btn>
          <v-btn color="primary" rounded="lg" prepend-icon="mdi-pencil"
                 @click="openEdit(detailItem)">Edit</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Pay dialog -->
    <v-dialog v-model="payDialog.show" max-width="540" persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="green-lighten-5" size="40" class="mr-3">
            <v-icon color="green-darken-2">mdi-cash-plus</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">RECORD PAYMENT</div>
            <div class="text-h6 font-weight-bold font-monospace">
              {{ payDialog.invoice?.invoice_number }}
            </div>
          </div>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" @click="payDialog.show = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          <div class="text-caption text-medium-emphasis mb-3">
            Outstanding balance:
            <strong class="font-monospace text-error">
              {{ formatMoney(payDialog.invoice?.balance) }}
            </strong>
          </div>
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-select v-model="payDialog.method" :items="METHODS"
                        label="Method *" prepend-inner-icon="mdi-credit-card"
                        variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model.number="payDialog.amount" type="number" step="0.01"
                            label="Amount *" prepend-inner-icon="mdi-currency-usd"
                            variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12">
              <v-text-field v-model="payDialog.reference" label="Reference (M-Pesa code, txn id…)"
                            prepend-inner-icon="mdi-pound"
                            variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="payDialog.notes" label="Notes" rows="2"
                          prepend-inner-icon="mdi-text"
                          variant="outlined" density="comfortable" />
            </v-col>
          </v-row>
          <div class="d-flex flex-wrap ga-1 mt-2">
            <v-chip size="small" variant="tonal" class="cursor-pointer"
                    @click="payDialog.amount = Number(payDialog.invoice?.balance || 0)">
              Pay full
            </v-chip>
            <v-chip size="small" variant="tonal" class="cursor-pointer"
                    @click="payDialog.amount = Number(payDialog.invoice?.balance || 0) / 2">
              Pay half
            </v-chip>
          </div>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="payDialog.show = false">Cancel</v-btn>
          <v-btn color="success" rounded="lg" :loading="payBusy" @click="doPay">
            <v-icon start>mdi-cash-plus</v-icon>Record
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Delete confirm -->
    <v-dialog v-model="deleteDialog.show" max-width="420" persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center">
          <v-icon color="error" class="mr-2">mdi-alert-circle</v-icon>Delete Invoice
        </v-card-title>
        <v-card-text>
          Delete invoice <strong class="font-monospace">{{ deleteDialog.item?.invoice_number }}</strong>?
          This will also remove its items and payments.
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog.show = false">Cancel</v-btn>
          <v-btn color="error" variant="flat" :loading="deleteDialog.busy" @click="doDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'

const { $api } = useNuxtApp()

const r = useResource('/lab/invoices/')
const ordersR = useResource('/lab/orders/')
const catalogR = useResource('/lab/catalog/')
const facilitiesR = useResource('/lab/referring-facilities/')

const view = ref('table')
const statusFilter = ref(null)
const payerFilter = ref(null)
const dateFrom = ref('')
const dateTo = ref('')
const sortBy = ref('recent')
const selected = ref([])
const bulkBusy = ref(false)

const formDialog = ref(false)
const formRef = ref(null)
const form = ref(emptyForm())

const detailDialog = ref(false)
const detailItem = ref(null)

const payDialog = reactive({ show: false, invoice: null, method: 'cash', amount: 0, reference: '', notes: '' })
const payBusy = ref(false)

const deleteDialog = reactive({ show: false, item: null, busy: false })
const snack = reactive({ show: false, color: 'success', text: '' })

const patientOptions = ref([])

const STATUSES = ['draft', 'issued', 'partial', 'paid', 'void']
const PAYERS = [
  { title: 'Self / Cash', value: 'self' },
  { title: 'Insurance', value: 'insurance' },
  { title: 'Referring Facility', value: 'facility' },
  { title: 'Corporate', value: 'corporate' },
]
const PAYER_META = {
  self: { icon: 'mdi-account-cash', color: 'green' },
  insurance: { icon: 'mdi-shield-account', color: 'indigo' },
  facility: { icon: 'mdi-hospital-building', color: 'cyan' },
  corporate: { icon: 'mdi-domain', color: 'deep-purple' },
}
const METHODS = [
  { title: 'Cash', value: 'cash' },
  { title: 'M-Pesa', value: 'mpesa' },
  { title: 'Card', value: 'card' },
  { title: 'Bank Transfer', value: 'bank' },
  { title: 'Insurance', value: 'insurance' },
]

const STATUS_PILLS = [
  { label: 'All', value: null, key: 'all', icon: 'mdi-dots-grid' },
  { label: 'Draft', value: 'draft', key: 'draft', color: 'grey', icon: 'mdi-file-document-edit' },
  { label: 'Issued', value: 'issued', key: 'issued', color: 'blue', icon: 'mdi-send' },
  { label: 'Partial', value: 'partial', key: 'partial', color: 'amber', icon: 'mdi-circle-half-full' },
  { label: 'Paid', value: 'paid', key: 'paid', color: 'success', icon: 'mdi-check-circle' },
  { label: 'Void', value: 'void', key: 'void', color: 'red-darken-2', icon: 'mdi-cancel' },
  { label: 'Overdue', value: 'overdue', key: 'overdue', color: 'error', icon: 'mdi-alert' },
]

const sortOptions = [
  { title: 'Most recent', value: 'recent' },
  { title: 'Oldest first', value: 'old' },
  { title: 'Highest balance', value: 'balance_high' },
  { title: 'Largest total', value: 'total_high' },
  { title: 'Invoice # (A→Z)', value: 'num_asc' },
]

const headers = [
  { title: 'Invoice', key: 'invoice_number' },
  { title: 'Payer', key: 'payer_type', width: 150 },
  { title: 'Total', key: 'total', align: 'end', width: 130 },
  { title: 'Paid', key: 'amount_paid', align: 'end', width: 130 },
  { title: 'Balance', key: 'balance', align: 'end', width: 130 },
  { title: 'Status', key: 'status', width: 130 },
  { title: 'Created', key: 'created_at', width: 140 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 130 },
]

const list = computed(() => r.items.value || [])
const orders = computed(() => ordersR.items.value || [])
const catalog = computed(() => catalogR.items.value || [])
const facilities = computed(() => facilitiesR.items.value || [])

const orderOptions = computed(() => orders.value.map(o => ({
  ...o,
  label: `#${o.id} · ${o.patient_name || 'Patient'} · ${formatDate(o.created_at || o.ordered_at)}`,
})))

function isOverdue (inv) {
  if (Number(inv.balance) <= 0) return false
  if (inv.status === 'void' || inv.status === 'paid') return false
  const created = new Date(inv.created_at)
  if (isNaN(created)) return false
  return (Date.now() - created.getTime()) > 30 * 86400000
}

const statusPills = computed(() => {
  const arr = list.value
  return STATUS_PILLS.map(s => {
    let count
    if (s.value === null) count = arr.length
    else if (s.value === 'overdue') count = arr.filter(isOverdue).length
    else count = arr.filter(x => x.status === s.value).length
    return { ...s, count }
  })
})

const payerPills = computed(() => {
  const counts = list.value.reduce((acc, x) => {
    acc[x.payer_type] = (acc[x.payer_type] || 0) + 1; return acc
  }, {})
  return [
    { label: 'All payers', value: null },
    ...PAYERS.map(p => ({ label: p.title, value: p.value, count: counts[p.value] || 0 })),
  ]
})

const filtered = computed(() => {
  let arr = r.filtered.value || []
  if (statusFilter.value === 'overdue') arr = arr.filter(isOverdue)
  else if (statusFilter.value) arr = arr.filter(x => x.status === statusFilter.value)
  if (payerFilter.value) arr = arr.filter(x => x.payer_type === payerFilter.value)
  if (dateFrom.value) {
    const from = new Date(dateFrom.value)
    arr = arr.filter(x => new Date(x.created_at) >= from)
  }
  if (dateTo.value) {
    const to = new Date(dateTo.value); to.setHours(23, 59, 59, 999)
    arr = arr.filter(x => new Date(x.created_at) <= to)
  }
  arr = [...arr]
  switch (sortBy.value) {
    case 'old': arr.sort((a, b) => new Date(a.created_at) - new Date(b.created_at)); break
    case 'balance_high': arr.sort((a, b) => Number(b.balance) - Number(a.balance)); break
    case 'total_high': arr.sort((a, b) => Number(b.total) - Number(a.total)); break
    case 'num_asc': arr.sort((a, b) => (a.invoice_number || '').localeCompare(b.invoice_number || '')); break
    default: arr.sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
  }
  return arr
})

const selectedTotals = computed(() => {
  const items = list.value.filter(x => selected.value.includes(x.id))
  return {
    total: items.reduce((s, x) => s + Number(x.total || 0), 0),
    balance: items.reduce((s, x) => s + Number(x.balance || 0), 0),
  }
})

const kpis = computed(() => {
  const arr = list.value
  const totalBilled = arr.reduce((s, x) => s + Number(x.total || 0), 0)
  const totalPaid = arr.reduce((s, x) => s + Number(x.amount_paid || 0), 0)
  const outstanding = arr.reduce((s, x) => s + Number(x.balance || 0), 0)
  const today = new Date(); today.setHours(0, 0, 0, 0)
  const todayPayments = arr.reduce((sum, inv) => {
    return sum + (inv.payments || []).reduce((s, p) => {
      return s + (new Date(p.received_at) >= today ? Number(p.amount || 0) : 0)
    }, 0)
  }, 0)
  return [
    { label: 'Invoices', value: arr.length, icon: 'mdi-receipt', color: 'indigo',
      hint: `${arr.filter(x => x.status === 'draft').length} drafts` },
    { label: 'Billed', value: formatMoney(totalBilled), icon: 'mdi-cash-multiple', color: 'blue',
      hint: `${formatMoney(totalPaid)} collected` },
    { label: 'Outstanding', value: formatMoney(outstanding), icon: 'mdi-alert-circle', color: 'amber',
      hint: `${arr.filter(isOverdue).length} overdue` },
    { label: "Today's payments", value: formatMoney(todayPayments), icon: 'mdi-cash-register', color: 'green',
      hint: 'received today' },
  ]
})

// ─── Helpers ───
function statusLabel (v) {
  return { draft: 'Draft', issued: 'Issued', partial: 'Partial', paid: 'Paid', void: 'Void' }[v] || v
}
function statusColor (v) {
  return { draft: 'grey', issued: 'blue', partial: 'amber', paid: 'success', void: 'red-darken-2' }[v] || 'grey'
}
function statusIcon (v) {
  return { draft: 'mdi-file-document-edit', issued: 'mdi-send',
    partial: 'mdi-circle-half-full', paid: 'mdi-check-circle', void: 'mdi-cancel' }[v] || 'mdi-help'
}
function statusHex (v) {
  return { draft: '#9e9e9e', issued: '#1e88e5', partial: '#fb8c00',
    paid: '#43a047', void: '#e53935' }[v] || '#9e9e9e'
}
function payerLabel (v) { return PAYERS.find(p => p.value === v)?.title || v || '—' }
function methodLabel (v) { return METHODS.find(m => m.value === v)?.title || v || '—' }
function methodIcon (v) {
  return { cash: 'mdi-cash', mpesa: 'mdi-cellphone', card: 'mdi-credit-card',
    bank: 'mdi-bank', insurance: 'mdi-shield-account' }[v] || 'mdi-cash'
}
function methodColor (v) {
  return { cash: 'green', mpesa: 'green-darken-2', card: 'indigo',
    bank: 'blue', insurance: 'deep-purple' }[v] || 'grey'
}
function formatDate (s) {
  if (!s) return '—'
  return new Date(s).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })
}
function formatDateTime (s) {
  if (!s) return '—'
  return new Date(s).toLocaleString()
}
function relativeTime (s) {
  if (!s) return ''
  const diff = Date.now() - new Date(s).getTime()
  const d = Math.floor(diff / 86400000)
  if (d <= 0) return 'today'
  if (d === 1) return 'yesterday'
  if (d < 30) return `${d}d ago`
  if (d < 365) return `${Math.floor(d / 30)}mo ago`
  return `${Math.floor(d / 365)}y ago`
}
function formatMoney (n) {
  if (n == null) return 'KES 0.00'
  return 'KES ' + Number(n).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}
function paidPct (i) {
  const t = Number(i.total || 0); if (t <= 0) return 0
  return Math.min(100, (Number(i.amount_paid || 0) / t) * 100)
}
const required = v => (v !== null && v !== undefined && v !== '') || 'Required'

function emptyForm () {
  return {
    id: null, invoice_number: '', lab_order: null, patient: null,
    payer_type: 'self', insurance_scheme: '', referring_facility: null,
    subtotal: 0, discount: 0, tax: 0, total: 0, amount_paid: 0,
    status: 'draft', notes: '', items: [],
  }
}

function addItem (preset = {}) {
  form.value.items.push({
    description: '', test: null, panel: null,
    qty: 1, unit_price: 0, discount: 0, amount: 0, ...preset,
  })
  recalcItem(form.value.items[form.value.items.length - 1])
}
function recalcItem (it) {
  it.amount = Math.max(0, (Number(it.qty) || 0) * (Number(it.unit_price) || 0) - (Number(it.discount) || 0))
  recalcTotals()
}
function recalcTotals () {
  form.value.subtotal = (form.value.items || []).reduce((s, x) => s + Number(x.amount || 0), 0)
  form.value.total = Math.max(0,
    Number(form.value.subtotal || 0)
    - Number(form.value.discount || 0)
    + Number(form.value.tax || 0))
}
function onPickTest (it, id) {
  const t = catalog.value.find(c => c.id === id)
  if (!t) return
  if (!it.description) it.description = t.name
  if (!it.unit_price) it.unit_price = Number(t.price || t.unit_price || 0)
  recalcItem(it)
}
async function onOrderChange (id) {
  if (!id) return
  const o = orders.value.find(x => x.id === id)
  if (o && o.patient && !form.value.patient) form.value.patient = o.patient
  // Auto-load tests from order if available
  try {
    const res = await $api.get(`/lab/orders/${id}/`)
    const tests = res.data?.tests || res.data?.items || []
    if (tests.length && !form.value.items.length) {
      tests.forEach(t => addItem({
        description: t.test_name || t.name || t.description || `Test #${t.id}`,
        test: t.test || t.id || null,
        unit_price: Number(t.price || t.unit_price || 0),
      }))
    }
  } catch { /* ignore */ }
}

function openNew () {
  form.value = emptyForm()
  formDialog.value = true
}
function openEdit (it) {
  form.value = {
    ...emptyForm(),
    ...it,
    items: (it.items || []).map(x => ({ ...x })),
  }
  detailDialog.value = false
  formDialog.value = true
}
async function openDetail (it) {
  try {
    const res = await $api.get(`/lab/invoices/${it.id}/`)
    detailItem.value = res.data
  } catch {
    detailItem.value = it
  }
  detailDialog.value = true
}

async function save (status) {
  const { valid } = (await formRef.value?.validate?.()) || { valid: true }
  if (!valid) return
  recalcTotals()
  const payload = {
    lab_order: form.value.lab_order,
    patient: form.value.patient,
    payer_type: form.value.payer_type,
    insurance_scheme: form.value.insurance_scheme,
    referring_facility: form.value.referring_facility,
    subtotal: form.value.subtotal,
    discount: form.value.discount,
    tax: form.value.tax,
    total: form.value.total,
    notes: form.value.notes,
    status: status || form.value.status || 'draft',
  }
  try {
    let invoice
    if (form.value.id) {
      invoice = await r.update(form.value.id, payload)
    } else {
      invoice = await r.create(payload)
    }
    const invId = invoice?.id || form.value.id
    // Sync items: simple approach — recreate when new, otherwise patch existing
    if (invId) {
      const existing = (invoice?.items || []).map(x => x.id)
      const keepIds = form.value.items.filter(x => x.id).map(x => x.id)
      const toRemove = existing.filter(id => !keepIds.includes(id))
      for (const id of toRemove) {
        try { await $api.delete(`/lab/invoice-items/${id}/`) } catch { /* ignore */ }
      }
      for (const it of form.value.items) {
        const body = {
          invoice: invId, test: it.test || null, panel: it.panel || null,
          description: it.description || '', qty: it.qty || 1,
          unit_price: it.unit_price || 0, discount: it.discount || 0,
        }
        if (it.id) await $api.patch(`/lab/invoice-items/${it.id}/`, body)
        else await $api.post('/lab/invoice-items/', body)
      }
    }
    formDialog.value = false
    notify(`Invoice ${form.value.id ? 'updated' : 'created'} successfully`)
    await r.list()
  } catch (e) { notify(r.error.value || e?.message || 'Save failed', 'error') }
}

async function setStatus (it, status) {
  try {
    await r.update(it.id, { ...it, status })
    notify(`Marked as ${statusLabel(status)}`)
    if (detailItem.value?.id === it.id) {
      const res = await $api.get(`/lab/invoices/${it.id}/`)
      detailItem.value = res.data
    }
    await r.list()
  } catch (e) { notify(r.error.value || 'Update failed', 'error') }
}

function confirmDelete (it) { deleteDialog.item = it; deleteDialog.show = true }
async function doDelete () {
  deleteDialog.busy = true
  try {
    await r.remove(deleteDialog.item.id)
    notify('Invoice deleted')
    deleteDialog.show = false
    detailDialog.value = false
  } catch (e) { notify(r.error.value || 'Delete failed', 'error') }
  finally { deleteDialog.busy = false }
}

async function bulkSetStatus (status) {
  bulkBusy.value = true
  try {
    await Promise.all(selected.value.map(id => {
      const it = list.value.find(x => x.id === id)
      return it ? r.update(id, { ...it, status }) : null
    }))
    notify(`${selected.value.length} invoice(s) marked ${statusLabel(status)}`)
    selected.value = []
    await r.list()
  } catch (e) { notify(r.error.value || 'Bulk update failed', 'error') }
  finally { bulkBusy.value = false }
}
function bulkPrint () {
  selected.value.forEach(id => {
    const inv = list.value.find(x => x.id === id)
    if (inv) printInvoice(inv)
  })
}

// Pay
function openPay (inv) {
  payDialog.invoice = inv
  payDialog.method = 'cash'
  payDialog.amount = Number(inv.balance || 0)
  payDialog.reference = ''
  payDialog.notes = ''
  payDialog.show = true
}
async function doPay () {
  if (!payDialog.amount || payDialog.amount <= 0) {
    return notify('Enter a positive amount', 'warning')
  }
  payBusy.value = true
  try {
    await $api.post(`/lab/invoices/${payDialog.invoice.id}/add_payment/`, {
      method: payDialog.method,
      amount: payDialog.amount,
      reference: payDialog.reference,
      notes: payDialog.notes,
    })
    notify('Payment recorded')
    payDialog.show = false
    if (detailItem.value?.id === payDialog.invoice.id) {
      const res = await $api.get(`/lab/invoices/${detailItem.value.id}/`)
      detailItem.value = res.data
    }
    await r.list()
  } catch (e) { notify(e?.response?.data?.detail || 'Payment failed', 'error') }
  finally { payBusy.value = false }
}

function reload () { r.list(); ordersR.list(); catalogR.list(); facilitiesR.list(); loadPatients() }
function notify (text, color = 'success') { snack.text = text; snack.color = color; snack.show = true }

async function loadPatients () {
  try {
    const data = await $api.get('/patients/').then(r => r.data)
    const items = Array.isArray(data) ? data : (data?.results || [])
    patientOptions.value = items.map(p => ({
      ...p,
      display: `${p.user?.full_name || p.full_name || p.name || ('Patient #' + p.id)}${p.mrn ? ' · ' + p.mrn : ''}`,
    }))
  } catch { /* ignore */ }
}

function exportCsv () {
  const rows = filtered.value
  if (!rows.length) return
  const cols = ['invoice_number', 'patient_name', 'payer_type', 'insurance_scheme',
    'subtotal', 'discount', 'tax', 'total', 'amount_paid', 'balance',
    'status', 'created_at']
  const esc = v => `"${String(v ?? '').replace(/"/g, '""')}"`
  const body = rows.map(it => cols.map(c => esc(it[c])).join(',')).join('\n')
  const blob = new Blob([cols.join(',') + '\n' + body], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `lab-invoices_${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

function printInvoice (i) {
  const w = window.open('', '_blank')
  if (!w) return
  const itemsHtml = (i.items || []).map(it => `
    <tr>
      <td>${it.description}</td>
      <td style="text-align:right">${it.qty}</td>
      <td style="text-align:right">${formatMoney(it.unit_price)}</td>
      <td style="text-align:right">${formatMoney(it.discount)}</td>
      <td style="text-align:right">${formatMoney(it.amount)}</td>
    </tr>`).join('')
  const paysHtml = (i.payments || []).map(p => `
    <tr>
      <td>${formatDateTime(p.received_at)}</td>
      <td>${methodLabel(p.method)}</td>
      <td>${p.reference || '—'}</td>
      <td style="text-align:right">${formatMoney(p.amount)}</td>
    </tr>`).join('')
  w.document.write(`
    <html><head><title>${i.invoice_number}</title>
    <style>
      body{font-family:Arial,sans-serif;padding:32px;color:#222}
      h1{margin:0 0 4px;font-size:22px}
      .muted{color:#666;font-size:12px}
      table{width:100%;border-collapse:collapse;margin-top:12px}
      th,td{border-bottom:1px solid #eee;padding:8px;text-align:left;font-size:13px}
      th{background:#fafafa}
      .totals{margin-top:16px;width:280px;margin-left:auto}
      .totals tr td{padding:4px 8px;border:none}
      .badge{display:inline-block;padding:2px 8px;border-radius:6px;font-size:12px;color:#fff;background:#3949ab}
    </style></head><body>
      <div style="display:flex;justify-content:space-between;align-items:flex-start">
        <div>
          <h1>Invoice ${i.invoice_number}</h1>
          <div class="muted">${formatDateTime(i.created_at)}</div>
          <div class="muted">Patient: <strong>${i.patient_name || '—'}</strong></div>
          ${i.referring_facility_name ? `<div class="muted">Referring: ${i.referring_facility_name}</div>` : ''}
        </div>
        <div style="text-align:right">
          <span class="badge">${statusLabel(i.status)}</span><br/>
          <span class="badge" style="background:#00897b">${payerLabel(i.payer_type)}</span>
          ${i.insurance_scheme ? `<div class="muted" style="margin-top:6px">${i.insurance_scheme}</div>` : ''}
        </div>
      </div>
      <h3>Items</h3>
      <table>
        <thead><tr><th>Description</th><th style="text-align:right">Qty</th>
          <th style="text-align:right">Unit price</th><th style="text-align:right">Discount</th>
          <th style="text-align:right">Amount</th></tr></thead>
        <tbody>${itemsHtml || '<tr><td colspan="5" style="color:#888">No items</td></tr>'}</tbody>
      </table>
      <table class="totals">
        <tr><td>Subtotal</td><td style="text-align:right">${formatMoney(i.subtotal)}</td></tr>
        <tr><td>Discount</td><td style="text-align:right">−${formatMoney(i.discount)}</td></tr>
        <tr><td>Tax</td><td style="text-align:right">${formatMoney(i.tax)}</td></tr>
        <tr><td><strong>Total</strong></td>
            <td style="text-align:right"><strong>${formatMoney(i.total)}</strong></td></tr>
        <tr><td>Paid</td><td style="text-align:right">${formatMoney(i.amount_paid)}</td></tr>
        <tr><td><strong>Balance</strong></td>
            <td style="text-align:right"><strong>${formatMoney(i.balance)}</strong></td></tr>
      </table>
      ${(i.payments || []).length ? `
        <h3>Payments</h3>
        <table>
          <thead><tr><th>Date</th><th>Method</th><th>Reference</th>
            <th style="text-align:right">Amount</th></tr></thead>
          <tbody>${paysHtml}</tbody>
        </table>` : ''}
      ${i.notes ? `<h3>Notes</h3><p>${i.notes}</p>` : ''}
    </body></html>`)
  w.document.close()
  w.print()
}

onMounted(() => { reload() })
</script>

<style scoped>
.kpi { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.invoice-table :deep(tbody tr) { cursor: pointer; }
.invoice-card {
  position: relative; overflow: hidden;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  cursor: pointer;
  transition: transform 120ms ease, box-shadow 120ms ease;
}
.invoice-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.06); }
.invoice-band { position: absolute; top: 0; left: 0; right: 0; height: 3px; }
.bulk-bar {
  border: 1px solid rgba(var(--v-theme-primary), 0.2);
  background: rgba(var(--v-theme-primary), 0.04);
}
.totals { background: rgba(var(--v-theme-primary), 0.04); }
.line-table :deep(td) { padding: 4px 8px !important; }
.min-width-0 { min-width: 0; }
.font-monospace { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
.cursor-pointer { cursor: pointer; }
</style>
