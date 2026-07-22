<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Patient Care Management"
      subtitle="Payment plans, equipment, supplies, medications, caregivers and billing per patient."
      eyebrow="CARE & BILLING"
      icon="mdi-hand-heart"
      :chips="[
        { icon: 'mdi-account-group', label: `${activePatients.length} active` },
        { icon: 'mdi-clipboard-check', label: `${onPlanCount} on a plan` },
        { icon: 'mdi-alert', label: `${needsPlanCount} need a plan` },
      ]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-refresh"
               class="text-none" :loading="loading" @click="load">
          <span class="text-teal-darken-2 font-weight-bold">Refresh</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row dense class="mb-1">
      <v-col cols="12" sm="6" md="3">
        <HomecareKpiCard label="Active patients" :value="activePatients.length"
                         icon="mdi-account-heart" color="#0d9488" />
      </v-col>
      <v-col cols="12" sm="6" md="3">
        <HomecareKpiCard label="On a payment plan" :value="onPlanCount"
                         icon="mdi-clipboard-check" color="#2563eb" />
      </v-col>
      <v-col cols="12" sm="6" md="3">
        <HomecareKpiCard label="Need a plan" :value="needsPlanCount"
                         icon="mdi-alert-circle" color="#f59e0b"
                         :hint="needsPlanCount ? 'Active patients without a plan' : 'All active patients covered'" />
      </v-col>
      <v-col cols="12" sm="6" md="3">
        <HomecareKpiCard label="Outstanding balance" :value="money(outstanding)"
                         icon="mdi-cash-clock" color="#ef4444"
                         hint="Across all open bills (net of payments)" />
      </v-col>
    </v-row>

    <v-alert v-if="needsPlanCount && mainTab === 'patients'" type="warning" variant="tonal"
             rounded="lg" density="comfortable" class="mb-3" icon="mdi-alert">
      <strong>{{ needsPlanCount }}</strong> active
      {{ needsPlanCount === 1 ? 'patient has' : 'patients have' }} no payment plan.
      Every active patient must be placed on a plan (daily, weekly, monthly, per visit,
      day/night shift or hourly).
    </v-alert>

    <v-card rounded="xl" :elevation="0" class="hc-tabs-card">
      <v-tabs v-model="mainTab" color="teal" density="comfortable" show-arrows grow>
        <v-tab value="patients">
          <v-icon start icon="mdi-account-multiple" />
          Patients under care
          <v-chip size="x-small" class="ml-2" color="teal" variant="tonal">
            {{ activePatients.length }}
          </v-chip>
        </v-tab>
        <v-tab value="bills">
          <v-icon start icon="mdi-receipt-text" />
          Bills
          <v-chip size="x-small" class="ml-2" color="cyan-darken-2" variant="tonal">
            {{ bills.length }}
          </v-chip>
        </v-tab>
        <v-tab value="payments">
          <v-icon start icon="mdi-cash-check" />
          Payments
          <v-chip size="x-small" class="ml-2" color="success" variant="tonal">
            {{ payments.length }}
          </v-chip>
        </v-tab>
      </v-tabs>
      <v-divider />

      <v-window v-model="mainTab">
        <!-- ─── Patients under care ─── -->
        <v-window-item value="patients">
          <HomecarePanel title="Patients under care" subtitle="Plans, caregivers and balances"
                         icon="mdi-account-multiple" color="#0284c7" class="ma-3">
            <template #actions>
              <div class="d-flex align-center ga-2 justify-end hc-filter-bar">
                <v-text-field v-model="patientSearch" density="compact" hide-details
                              variant="solo-filled" flat rounded="lg" clearable
                              placeholder="Search patient…"
                              prepend-inner-icon="mdi-magnify"
                              class="hc-search"
                              :class="{ 'hc-search--focused': patientSearchFocused }"
                              @focus="patientSearchFocused = true"
                              @blur="patientSearchFocused = false" />
                <v-menu :close-on-content-click="false" location="bottom end" offset="8">
                  <template #activator="{ props }">
                    <v-badge :model-value="patientFiltersActive" dot color="error"
                             location="top end" offset-x="4" offset-y="4">
                      <v-btn v-bind="props" size="small" variant="tonal" color="teal"
                             icon="mdi-tune-variant" rounded="lg" />
                    </v-badge>
                  </template>
                  <v-card min-width="260" rounded="xl">
                    <v-card-text class="pb-2">
                      <div class="text-caption font-weight-bold text-medium-emphasis mb-2">
                        <v-icon icon="mdi-filter" size="14" class="mr-1" />
                        Filter patients
                      </div>
                      <v-btn-toggle v-model="patientFilter" density="compact" rounded="lg"
                                    color="teal" variant="outlined" mandatory
                                    class="d-flex flex-wrap">
                        <v-btn value="all" size="small" class="text-none flex-grow-1">All</v-btn>
                        <v-btn value="on_plan" size="small" class="text-none flex-grow-1">On plan</v-btn>
                        <v-btn value="needs_plan" size="small" class="text-none flex-grow-1">Needs plan</v-btn>
                        <v-btn value="paused" size="small" class="text-none flex-grow-1">Auto-bill paused</v-btn>
                        <v-btn value="outstanding" size="small" class="text-none flex-grow-1">Has balance</v-btn>
                      </v-btn-toggle>
                    </v-card-text>
                    <v-card-actions v-if="patientFiltersActive">
                      <v-spacer />
                      <v-btn size="small" variant="text" color="error" class="text-none"
                             prepend-icon="mdi-close" @click="clearPatientFilters">
                        Clear
                      </v-btn>
                    </v-card-actions>
                  </v-card>
                </v-menu>
              </div>
            </template>

            <v-data-table :headers="patientHeaders" :items="filteredPatients" :loading="loading"
                          item-value="id" class="hc-table" density="comfortable"
                          :items-per-page="15">
              <template #[`item.patient`]="{ item }">
                <div class="d-flex align-center py-1">
                  <v-avatar size="34" color="teal-lighten-4" class="mr-2">
                    <span class="text-teal-darken-2 font-weight-bold">{{ initials(item.name) }}</span>
                  </v-avatar>
                  <div>
                    <div class="font-weight-medium">{{ item.name }}</div>
                    <div class="text-caption text-medium-emphasis">
                      {{ item.medical_record_number }}
                      <span v-if="item.adheremed_patient_id"> · {{ item.adheremed_patient_id }}</span>
                    </div>
                  </div>
                </div>
              </template>

              <template #[`item.plan`]="{ item }">
                <v-chip v-if="item.plan" size="small" color="teal" variant="tonal" label>
                  <v-icon start size="14" icon="mdi-calendar-clock" />{{ item.plan.plan_type_label }}
                </v-chip>
                <v-chip v-else size="small" color="warning" variant="tonal" label>
                  <v-icon start size="14" icon="mdi-alert" />No plan
                </v-chip>
              </template>

              <template #[`item.rate`]="{ item }">
                <span v-if="item.plan">{{ money(item.plan.rate, item.plan.currency) }}</span>
                <span v-else class="text-medium-emphasis">—</span>
              </template>

              <template #[`item.auto_bill`]="{ item }">
                <v-tooltip
                  :text="item.plan
                    ? (item.plan.auto_bill ? 'Auto-bill ON — click to pause' : 'Auto-bill PAUSED — click to resume')
                    : 'No active plan'"
                  location="top"
                >
                  <template #activator="{ props }">
                    <div v-bind="props" style="display:inline-block">
                      <v-switch
                        :model-value="!!item.plan?.auto_bill"
                        :disabled="!item.plan || autoBillSavingId === item.plan?.id"
                        :loading="autoBillSavingId === item.plan?.id"
                        color="teal"
                        density="compact"
                        hide-details
                        inset
                        @update:model-value="v => toggleAutoBill(item, v)"
                      />
                    </div>
                  </template>
                </v-tooltip>
              </template>

              <template #[`item.caregiver`]="{ item }">
                <span v-if="item.caregiver">{{ item.caregiver }}</span>
                <span v-else class="text-medium-emphasis">Unassigned</span>
              </template>

              <template #[`item.balance`]="{ item }">
                <div>
                  <span :class="Number(item.balance) > 0 ? 'text-error font-weight-bold' : 'text-medium-emphasis'">
                    {{ item.hasBills ? money(item.balance) : '—' }}
                  </span>
                  <div v-if="item.hasBills && item.totalPaid > 0"
                       class="text-caption text-success">
                    paid {{ money(item.totalPaid) }}
                  </div>
                </div>
              </template>

              <template #[`item.actions`]="{ item }">
                <v-btn size="small" color="teal" variant="flat" rounded="lg" class="text-none"
                       append-icon="mdi-arrow-right" :to="`/homecare/patient-care/${item.id}`">
                  Manage
                </v-btn>
              </template>

              <template #no-data>
                <div class="text-center py-8 text-medium-emphasis">No patients found.</div>
              </template>
            </v-data-table>
          </HomecarePanel>
        </v-window-item>

        <!-- ─── Bills (all patients) ─── -->
        <v-window-item value="bills">
          <HomecarePanel title="All patient bills" subtitle="Generated statements across every patient"
                         icon="mdi-receipt-text" color="#0891b2" class="ma-3">
            <template #actions>
              <div class="d-flex align-center ga-2 justify-end hc-filter-bar">
                <v-text-field v-model="billSearch" density="compact" hide-details
                              variant="solo-filled" flat rounded="lg" clearable
                              placeholder="Search patient / bill #…"
                              prepend-inner-icon="mdi-magnify"
                              class="hc-search"
                              :class="{ 'hc-search--focused': billSearchFocused }"
                              @focus="billSearchFocused = true"
                              @blur="billSearchFocused = false" />
                <v-menu :close-on-content-click="false" location="bottom end" offset="8">
                  <template #activator="{ props }">
                    <v-badge :model-value="billFiltersActive" dot color="error"
                             location="top end" offset-x="4" offset-y="4">
                      <v-btn v-bind="props" size="small" variant="tonal" color="cyan-darken-2"
                             icon="mdi-tune-variant" rounded="lg" />
                    </v-badge>
                  </template>
                  <v-card min-width="300" rounded="xl">
                    <v-card-text class="pb-2">
                      <div class="text-caption font-weight-bold text-medium-emphasis mb-2">
                        <v-icon icon="mdi-filter" size="14" class="mr-1" />
                        Filter bills
                      </div>
                      <v-select v-model="billStatusFilter" :items="BILL_STATUS_FILTERS"
                                density="compact" hide-details variant="outlined"
                                label="Status" class="mb-3" />
                      <v-text-field v-model="billFromDate" type="date" density="compact"
                                    hide-details variant="outlined" label="From"
                                    class="mb-3" clearable />
                      <v-text-field v-model="billToDate" type="date" density="compact"
                                    hide-details variant="outlined" label="To"
                                    clearable />
                    </v-card-text>
                    <v-card-actions v-if="billFiltersActive">
                      <v-spacer />
                      <v-btn size="small" variant="text" color="error" class="text-none"
                             prepend-icon="mdi-close" @click="clearBillFilters">
                        Clear
                      </v-btn>
                    </v-card-actions>
                  </v-card>
                </v-menu>
              </div>
            </template>

            <div class="d-flex flex-wrap ga-4 mb-3 px-1">
              <div>
                <div class="text-caption text-medium-emphasis">Bills in view</div>
                <div class="font-weight-bold">{{ filteredBills.length }}</div>
              </div>
              <div>
                <div class="text-caption text-medium-emphasis">Total billed</div>
                <div class="font-weight-bold">{{ money(billsTotal) }}</div>
              </div>
              <div>
                <div class="text-caption text-medium-emphasis">Total paid</div>
                <div class="font-weight-bold text-success">{{ money(billsPaid) }}</div>
              </div>
              <div>
                <div class="text-caption text-medium-emphasis">Outstanding</div>
                <div class="font-weight-bold text-error">{{ money(billsBalance) }}</div>
              </div>
            </div>

            <v-data-table :headers="billHeaders" :items="filteredBills" :loading="loading"
                          item-value="id" class="hc-table" density="comfortable"
                          :items-per-page="20"
                          :sort-by="[{ key: 'as_of', order: 'desc' }]">
              <template #[`item.patient_name`]="{ item }">
                <div class="d-flex align-center">
                  <v-avatar size="28" color="cyan-lighten-4" class="mr-2">
                    <span class="text-cyan-darken-2 font-weight-bold" style="font-size:12px">
                      {{ initials(item.patient_name) }}
                    </span>
                  </v-avatar>
                  <div>
                    <div class="font-weight-medium">{{ item.patient_name || '—' }}</div>
                  </div>
                </div>
              </template>
              <template #[`item.bill_number`]="{ item }">
                <div class="font-weight-medium">{{ item.bill_number }}</div>
                <div v-if="item.notes" class="text-caption text-medium-emphasis text-truncate"
                     style="max-width:220px" :title="item.notes">{{ item.notes }}</div>
              </template>
              <template #[`item.as_of`]="{ item }">
                <div>{{ formatDate(item.as_of) }}</div>
                <div class="text-caption text-medium-emphasis">{{ formatTime(item.as_of) }}</div>
              </template>
              <template #[`item.total`]="{ item }">
                <span class="font-weight-medium">{{ money(item.total) }}</span>
              </template>
              <template #[`item.amount_paid`]="{ item }">
                <span class="text-success">{{ money(item.amount_paid) }}</span>
              </template>
              <template #[`item.balance`]="{ item }">
                <span :class="Number(item.balance) > 0 ? 'text-error font-weight-bold' : 'text-medium-emphasis'">
                  {{ money(item.balance) }}
                </span>
              </template>
              <template #[`item.status`]="{ item }">
                <StatusChip :status="item.status" />
              </template>
              <template #[`item.actions`]="{ item }">
                <v-btn size="small" color="cyan-darken-2" variant="tonal" rounded="lg"
                       class="text-none" append-icon="mdi-arrow-right"
                       :to="`/homecare/patient-care/${item.patient}?tab=bills`">
                  Open
                </v-btn>
              </template>
              <template #no-data>
                <div class="text-center py-8 text-medium-emphasis">No bills match your filters.</div>
              </template>
            </v-data-table>
          </HomecarePanel>
        </v-window-item>

        <!-- ─── Payments (all patients) ─── -->
        <v-window-item value="payments">
          <HomecarePanel title="All patient payments" subtitle="Every recorded payment across patients"
                         icon="mdi-cash-check" color="#16a34a" class="ma-3">
            <template #actions>
              <div class="d-flex align-center ga-2 justify-end hc-filter-bar">
                <v-text-field v-model="paymentSearch" density="compact" hide-details
                              variant="solo-filled" flat rounded="lg" clearable
                              placeholder="Search patient / ref / bill…"
                              prepend-inner-icon="mdi-magnify"
                              class="hc-search"
                              :class="{ 'hc-search--focused': paymentSearchFocused }"
                              @focus="paymentSearchFocused = true"
                              @blur="paymentSearchFocused = false" />
                <v-menu :close-on-content-click="false" location="bottom end" offset="8">
                  <template #activator="{ props }">
                    <v-badge :model-value="paymentFiltersActive" dot color="error"
                             location="top end" offset-x="4" offset-y="4">
                      <v-btn v-bind="props" size="small" variant="tonal" color="success"
                             icon="mdi-tune-variant" rounded="lg" />
                    </v-badge>
                  </template>
                  <v-card min-width="300" rounded="xl">
                    <v-card-text class="pb-2">
                      <div class="text-caption font-weight-bold text-medium-emphasis mb-2">
                        <v-icon icon="mdi-filter" size="14" class="mr-1" />
                        Filter payments
                      </div>
                      <v-select v-model="paymentMethodFilter" :items="PAY_METHOD_FILTERS"
                                density="compact" hide-details variant="outlined"
                                label="Method" class="mb-3" />
                      <v-text-field v-model="paymentFromDate" type="date" density="compact"
                                    hide-details variant="outlined" label="From"
                                    class="mb-3" clearable />
                      <v-text-field v-model="paymentToDate" type="date" density="compact"
                                    hide-details variant="outlined" label="To"
                                    clearable />
                    </v-card-text>
                    <v-card-actions v-if="paymentFiltersActive">
                      <v-spacer />
                      <v-btn size="small" variant="text" color="error" class="text-none"
                             prepend-icon="mdi-close" @click="clearPaymentFilters">
                        Clear
                      </v-btn>
                    </v-card-actions>
                  </v-card>
                </v-menu>
              </div>
            </template>

            <div class="d-flex flex-wrap ga-4 mb-3 px-1">
              <div>
                <div class="text-caption text-medium-emphasis">Payments in view</div>
                <div class="font-weight-bold">{{ filteredPayments.length }}</div>
              </div>
              <div>
                <div class="text-caption text-medium-emphasis">Total received</div>
                <div class="font-weight-bold text-success">{{ money(paymentsTotal) }}</div>
              </div>
            </div>

            <v-data-table :headers="paymentHeaders" :items="filteredPayments" :loading="loading"
                          item-value="id" class="hc-table" density="comfortable"
                          :items-per-page="20"
                          :sort-by="[{ key: 'paid_at', order: 'desc' }]">
              <template #[`item.paid_at`]="{ item }">
                <div class="font-weight-medium">{{ formatDate(item.paid_at) }}</div>
                <div class="text-caption text-medium-emphasis">{{ formatTime(item.paid_at) }}</div>
              </template>
              <template #[`item.patient_name`]="{ item }">
                <div class="d-flex align-center">
                  <v-avatar size="28" color="green-lighten-4" class="mr-2">
                    <span class="text-green-darken-3 font-weight-bold" style="font-size:12px">
                      {{ initials(item.patient_name) }}
                    </span>
                  </v-avatar>
                  <div class="font-weight-medium">{{ item.patient_name || '—' }}</div>
                </div>
              </template>
              <template #[`item.bill_number`]="{ item }">
                <span v-if="item.bill_number" class="text-caption font-weight-medium">
                  {{ item.bill_number }}
                </span>
                <span v-else class="text-caption text-medium-emphasis">—</span>
              </template>
              <template #[`item.method_label`]="{ item }">
                <v-chip size="x-small" color="success" variant="tonal" label>
                  {{ item.method_label }}
                </v-chip>
                <span v-if="item.reference" class="text-caption text-medium-emphasis ml-1">
                  {{ item.reference }}
                </span>
              </template>
              <template #[`item.received_by_name`]="{ item }">
                <div class="d-flex align-center">
                  <v-icon icon="mdi-account-tie" size="14" class="mr-1 text-medium-emphasis" />
                  <span class="text-caption">{{ item.received_by_name || 'Unknown' }}</span>
                </div>
              </template>
              <template #[`item.amount`]="{ item }">
                <span class="font-weight-medium">{{ money(item.amount) }}</span>
              </template>
              <template #[`item.actions`]="{ item }">
                <v-btn size="small" color="success" variant="tonal" rounded="lg"
                       class="text-none" append-icon="mdi-arrow-right"
                       :to="`/homecare/patient-care/${item.patient}?tab=payments`">
                  Open
                </v-btn>
              </template>
              <template #no-data>
                <div class="text-center py-8 text-medium-emphasis">No payments match your filters.</div>
              </template>
            </v-data-table>
          </HomecarePanel>
        </v-window-item>
      </v-window>
    </v-card>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()

const loading = ref(false)
const patients = ref([])
const plans = ref([])
const bills = ref([])
const payments = ref([])

// ── main tabs ──
const mainTab = ref('patients')

// ── patients tab state ──
const patientFilter = ref('all')
const patientSearch = ref('')
const patientSearchFocused = ref(false)
const patientFiltersActive = computed(() => patientFilter.value !== 'all')
function clearPatientFilters() {
  patientFilter.value = 'all'
}
const patientHeaders = [
  { title: 'Patient', key: 'patient', sortable: false },
  { title: 'Plan', key: 'plan', sortable: false },
  { title: 'Rate', key: 'rate', sortable: false },
  { title: 'Auto-bill', key: 'auto_bill', sortable: false },
  { title: 'Caregiver', key: 'caregiver', sortable: false },
  { title: 'Outstanding balance', key: 'balance', align: 'end', sortable: false },
  { title: '', key: 'actions', align: 'end', sortable: false },
]

// ── bills tab state ──
const BILL_STATUS_FILTERS = [
  { value: 'all', title: 'All statuses' },
  { value: 'issued', title: 'Issued' },
  { value: 'partial', title: 'Partially paid' },
  { value: 'paid', title: 'Paid' },
  { value: 'draft', title: 'Draft' },
  { value: 'void', title: 'Void' },
  { value: 'open', title: 'Open (unpaid)' },
]
const billStatusFilter = ref('all')
const billFromDate = ref('')
const billToDate = ref('')
const billSearch = ref('')
const billSearchFocused = ref(false)
const billFiltersActive = computed(() =>
  (billStatusFilter.value && billStatusFilter.value !== 'all')
  || !!billFromDate.value
  || !!billToDate.value)
function clearBillFilters() {
  billStatusFilter.value = 'all'
  billFromDate.value = ''
  billToDate.value = ''
}
const billHeaders = [
  { title: 'Patient', key: 'patient_name', sortable: true },
  { title: 'Bill', key: 'bill_number', sortable: true },
  { title: 'Date', key: 'as_of', sortable: true },
  { title: 'Total', key: 'total', align: 'end', sortable: true },
  { title: 'Paid', key: 'amount_paid', align: 'end', sortable: true },
  { title: 'Balance', key: 'balance', align: 'end', sortable: true },
  { title: 'Status', key: 'status', sortable: true },
  { title: '', key: 'actions', align: 'end', sortable: false },
]

// ── payments tab state ──
const PAY_METHOD_FILTERS = [
  { value: 'all', title: 'All methods' },
  { value: 'cash', title: 'Cash' },
  { value: 'mpesa', title: 'M-Pesa' },
  { value: 'card', title: 'Card' },
  { value: 'bank', title: 'Bank Transfer' },
  { value: 'insurance', title: 'Insurance' },
  { value: 'other', title: 'Other' },
]
const paymentMethodFilter = ref('all')
const paymentFromDate = ref('')
const paymentToDate = ref('')
const paymentSearch = ref('')
const paymentSearchFocused = ref(false)
const paymentFiltersActive = computed(() =>
  (paymentMethodFilter.value && paymentMethodFilter.value !== 'all')
  || !!paymentFromDate.value
  || !!paymentToDate.value)
function clearPaymentFilters() {
  paymentMethodFilter.value = 'all'
  paymentFromDate.value = ''
  paymentToDate.value = ''
}
const paymentHeaders = [
  { title: 'Date & time', key: 'paid_at', sortable: true },
  { title: 'Patient', key: 'patient_name', sortable: true },
  { title: 'Bill', key: 'bill_number', sortable: true },
  { title: 'Method', key: 'method_label', sortable: true },
  { title: 'Recorded by', key: 'received_by_name', sortable: true },
  { title: 'Amount', key: 'amount', align: 'end', sortable: true },
  { title: '', key: 'actions', align: 'end', sortable: false },
]

const activePatients = computed(() => patients.value.filter(p => p.is_active))

const planByPatient = computed(() => {
  const map = {}
  for (const pl of plans.value) {
    if (!pl.is_active) continue
    // keep the most recent active plan per patient
    const cur = map[pl.patient]
    if (!cur || new Date(pl.start_date) >= new Date(cur.start_date)) map[pl.patient] = pl
  }
  return map
})

const lastBillByPatient = computed(() => {
  const map = {}
  for (const b of bills.value) {
    if (b.status === 'void') continue
    const cur = map[b.patient]
    if (!cur || new Date(b.created_at) > new Date(cur.created_at)) map[b.patient] = b
  }
  return map
})

const balanceByPatient = computed(() => {
  // Sum of open (non-void) bill balances for each patient. Backend keeps
  // bill.balance in sync whenever a payment is created / updated / deleted
  // (payments auto-link to the oldest open bill when unassigned).
  const map = {}
  for (const b of bills.value) {
    if (b.status === 'void') continue
    const bal = Number(b.balance || 0)
    map[b.patient] = (map[b.patient] || 0) + (bal > 0 ? bal : 0)
  }
  return map
})

const paidByPatient = computed(() => {
  const map = {}
  for (const b of bills.value) {
    if (b.status === 'void') continue
    map[b.patient] = (map[b.patient] || 0) + Number(b.amount_paid || 0)
  }
  return map
})

const hasBillsByPatient = computed(() => {
  const map = {}
  for (const b of bills.value) {
    if (b.status === 'void') continue
    map[b.patient] = true
  }
  return map
})

const rows = computed(() => activePatients.value.map(p => {
  const plan = planByPatient.value[p.id] || null
  const lastBill = lastBillByPatient.value[p.id] || null
  return {
    id: p.id,
    name: p.patient_name || p.user?.full_name || '—',
    medical_record_number: p.medical_record_number,
    adheremed_patient_id: p.adheremed_patient_id,
    is_active: p.is_active,
    caregiver: p.assigned_caregiver_name,
    plan,
    lastBill,
    hasBills: !!hasBillsByPatient.value[p.id],
    balance: balanceByPatient.value[p.id] || 0,
    totalPaid: paidByPatient.value[p.id] || 0,
  }
}))

const onPlanCount = computed(() => rows.value.filter(r => r.plan).length)
const needsPlanCount = computed(() => rows.value.filter(r => !r.plan).length)
const outstanding = computed(() =>
  rows.value.reduce((s, r) => s + Number(r.balance || 0), 0))

const filteredPatients = computed(() => {
  let list = rows.value
  const f = patientFilter.value
  if (f === 'on_plan') list = list.filter(r => r.plan)
  else if (f === 'needs_plan') list = list.filter(r => !r.plan)
  else if (f === 'paused') list = list.filter(r => r.plan && !r.plan.auto_bill)
  else if (f === 'outstanding') list = list.filter(r => Number(r.balance || 0) > 0)
  const q = patientSearch.value.trim().toLowerCase()
  if (q) list = list.filter(r =>
    (r.name || '').toLowerCase().includes(q)
    || (r.medical_record_number || '').toLowerCase().includes(q)
    || (r.adheremed_patient_id || '').toLowerCase().includes(q)
    || (r.caregiver || '').toLowerCase().includes(q))
  return list
})

// ── Bills tab (all patients) ──
const patientNameById = computed(() => {
  const map = {}
  for (const p of patients.value) {
    map[p.id] = p.patient_name || p.user?.full_name || ''
  }
  return map
})

const enrichedBills = computed(() =>
  bills.value.map(b => ({
    ...b,
    patient_name: b.patient_name || patientNameById.value[b.patient] || '',
  })))

const filteredBills = computed(() => {
  let list = enrichedBills.value
  const status = billStatusFilter.value
  if (status === 'open') {
    list = list.filter(b => b.status !== 'void' && Number(b.balance || 0) > 0)
  } else if (status && status !== 'all') {
    list = list.filter(b => b.status === status)
  }
  if (billFromDate.value) {
    const from = new Date(billFromDate.value)
    list = list.filter(b => b.as_of && new Date(b.as_of) >= from)
  }
  if (billToDate.value) {
    const to = new Date(billToDate.value)
    to.setHours(23, 59, 59, 999)
    list = list.filter(b => b.as_of && new Date(b.as_of) <= to)
  }
  const q = billSearch.value.trim().toLowerCase()
  if (q) list = list.filter(b =>
    (b.patient_name || '').toLowerCase().includes(q)
    || (b.bill_number || '').toLowerCase().includes(q)
    || (b.notes || '').toLowerCase().includes(q))
  return list
})

const billsTotal = computed(() =>
  filteredBills.value.reduce((s, b) => s + Number(b.total || 0), 0))
const billsPaid = computed(() =>
  filteredBills.value.reduce((s, b) => s + Number(b.amount_paid || 0), 0))
const billsBalance = computed(() =>
  filteredBills.value.reduce((s, b) => s + Math.max(Number(b.balance || 0), 0), 0))

// ── Payments tab (all patients) ──
const enrichedPayments = computed(() =>
  payments.value.map(p => ({
    ...p,
    patient_name: p.patient_name || patientNameById.value[p.patient] || '',
  })))

const filteredPayments = computed(() => {
  let list = enrichedPayments.value
  const method = paymentMethodFilter.value
  if (method && method !== 'all') list = list.filter(p => p.method === method)
  if (paymentFromDate.value) {
    const from = new Date(paymentFromDate.value)
    list = list.filter(p => p.paid_at && new Date(p.paid_at) >= from)
  }
  if (paymentToDate.value) {
    const to = new Date(paymentToDate.value)
    to.setHours(23, 59, 59, 999)
    list = list.filter(p => p.paid_at && new Date(p.paid_at) <= to)
  }
  const q = paymentSearch.value.trim().toLowerCase()
  if (q) list = list.filter(p =>
    (p.patient_name || '').toLowerCase().includes(q)
    || (p.reference || '').toLowerCase().includes(q)
    || (p.bill_number || '').toLowerCase().includes(q)
    || (p.received_by_name || '').toLowerCase().includes(q)
    || (p.notes || '').toLowerCase().includes(q))
  return list
})

const paymentsTotal = computed(() =>
  filteredPayments.value.reduce((s, p) => s + Number(p.amount || 0), 0))

function initials(name) {
  return (name || '?').split(' ').filter(Boolean).slice(0, 2).map(n => n[0]).join('').toUpperCase()
}
function money(v, currency = 'KES') {
  const n = Number(v || 0)
  const prefix = currency === 'KES' ? 'KSh ' : `${currency} `
  return prefix + n.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 2 })
}
function formatDate(v) {
  if (!v) return '—'
  return new Date(v).toLocaleDateString(undefined, { day: '2-digit', month: 'short', year: 'numeric' })
}
function formatTime(v) {
  if (!v) return ''
  return new Date(v).toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' })
}

async function fetchAll(url) {
  const out = []
  let next = url
  let guard = 0
  while (next && guard < 20) {
    const { data } = await $api.get(next)
    if (Array.isArray(data)) { out.push(...data); break }
    out.push(...(data.results || []))
    next = data.next
    guard++
  }
  return out
}

async function load() {
  loading.value = true
  try {
    const [pt, pl, bl, py] = await Promise.all([
      fetchAll('/homecare/patients/?is_active=true&page_size=200'),
      fetchAll('/homecare/care-plans/?page_size=200'),
      fetchAll('/homecare/patient-bills/?page_size=200'),
      fetchAll('/homecare/patient-payments/?page_size=200'),
    ])
    patients.value = pt
    plans.value = pl
    bills.value = bl
    payments.value = py
  } catch (e) {
    console.error('patient-care load failed', e)
  } finally {
    loading.value = false
  }
}

const autoBillSavingId = ref(null)
async function toggleAutoBill(row, next) {
  if (!row.plan?.id) return
  const planId = row.plan.id
  autoBillSavingId.value = planId
  try {
    const { data } = await $api.post(
      `/homecare/care-plans/${planId}/toggle-auto-bill/`,
      { auto_bill: !!next },
    )
    // Update the local plan record in place so the switch reflects the
    // new state without a full round-trip.
    const idx = plans.value.findIndex(p => p.id === planId)
    if (idx !== -1) plans.value[idx] = { ...plans.value[idx], ...data }
  } catch (e) {
    console.error('toggle-auto-bill failed', e)
    // Roll back local state by forcing a reload.
    load()
  } finally {
    autoBillSavingId.value = null
  }
}

onMounted(load)
</script>

<style scoped>
.hc-bg {
  background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%);
  min-height: calc(100vh - 64px);
}
.hc-tabs-card {
  background: white;
  border: 1px solid rgba(15, 23, 42, 0.06);
}
.hc-table :deep(td) { vertical-align: middle; }

/* Compact toolbar with a search that grows on focus and a 3-dot filter menu. */
.hc-filter-bar { min-width: 0; }
.hc-search {
  width: 200px;
  transition: width 220ms cubic-bezier(0.4, 0, 0.2, 1);
}
.hc-search.hc-search--focused {
  width: 380px;
}
@media (max-width: 640px) {
  .hc-search { width: 140px; }
  .hc-search.hc-search--focused { width: 100%; }
}

:global(.v-theme--dark .hc-bg) {
  background: linear-gradient(180deg, #0f172a 0%, #1e293b 100%);
}
:global(.v-theme--dark .hc-tabs-card) { background: #1e293b; }
</style>
