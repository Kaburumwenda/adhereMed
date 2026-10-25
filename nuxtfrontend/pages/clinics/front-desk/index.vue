<template>
  <v-container fluid class="pa-4 pa-md-6 fd-page">
    <PageHeader
      title="Front Desk"
      subtitle="Command every arrival — registration, billing, triage hand-off and discharge, live"
      icon="mdi-human-queue"
      color="primary"
    >
      <template #actions>
        <v-chip v-if="syncedLabel" size="small" variant="tonal" color="success" prepend-icon="mdi-broadcast">
          <span class="fd-live-dot" /> {{ syncedLabel }}
        </v-chip>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
               :loading="loading" @click="load">Refresh</v-btn>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-cog-outline"
               @click="openSettings">Settings</v-btn>
        <v-btn color="primary" rounded="lg" class="text-none" prepend-icon="mdi-account-plus"
               @click="openRegister">Register patient</v-btn>
      </template>
    </PageHeader>

    <!-- ═══════════ KPI stat cards ═══════════ -->
    <v-row dense class="mb-4">
      <v-col v-for="k in kpiCards" :key="k.key" cols="6" md="3">
        <v-card rounded="lg" variant="outlined" class="stat-card pa-3 pa-md-4 h-100" :loading="loading">
          <div class="d-flex align-center justify-space-between">
            <div class="min-w-0">
              <div class="text-caption text-medium-emphasis font-weight-medium">{{ k.label }}</div>
              <div class="text-h4 font-weight-bold" :class="k.tone">{{ k.value }}</div>
              <div class="text-caption text-medium-emphasis text-truncate">{{ k.hint }}</div>
            </div>
            <v-avatar :color="`${k.color}-lighten-5`" variant="tonal" size="48" class="ml-2">
              <v-icon :color="k.color" size="24">{{ k.icon }}</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════════ Analytical band ═══════════ -->
    <v-row dense class="mb-4">
      <!-- Live journey donut -->
      <v-col cols="12" md="6" lg="4">
        <v-card rounded="lg" variant="outlined" class="stat-card pa-4 h-100 d-flex flex-column">
          <div class="d-flex align-center justify-space-between mb-3">
            <span class="text-caption text-medium-emphasis font-weight-medium">LIVE JOURNEY MIX</span>
            <v-icon size="16" class="text-medium-emphasis">mdi-chart-donut</v-icon>
          </div>
          <div class="d-flex align-center justify-center flex-grow-1 ga-6">
            <DonutRing :segments="donutSegments" :size="150" :thickness="15">
              <div class="text-center">
                <div class="text-h4 font-weight-bold">{{ kpis.open || 0 }}</div>
                <div class="text-caption text-medium-emphasis">in clinic</div>
              </div>
            </DonutRing>
            <div class="fd-legend">
              <div v-for="g in journeyLegend" :key="g.key" class="fd-legend__row">
                <span class="fd-legend__dot" :style="{ background: g.color }" />
                <span class="fd-legend__label">{{ g.label }}</span>
                <span class="fd-legend__count font-weight-bold">{{ g.count }}</span>
              </div>
              <div v-if="!journeyLegend.length" class="text-caption text-medium-emphasis">
                No visits for this view.
              </div>
            </div>
          </div>
        </v-card>
      </v-col>

      <!-- Arrivals by hour -->
      <v-col cols="12" md="6" lg="4">
        <v-card rounded="lg" variant="outlined" class="stat-card pa-4 h-100 d-flex flex-column">
          <div class="d-flex align-center justify-space-between mb-3">
            <span class="text-caption text-medium-emphasis font-weight-medium">ARRIVALS BY HOUR</span>
            <v-chip size="x-small" variant="tonal" prepend-icon="mdi-ticket-confirmation">
              {{ arrivalStats.total }} today
            </v-chip>
          </div>
          <div class="d-flex align-end ga-1 flex-grow-1 fd-hour-chart">
            <div v-for="(h, i) in arrivalStats.hours" :key="h" class="fd-hour-col">
              <span class="text-caption font-weight-bold mb-1"
                    :class="isCurrentHour(h) ? 'text-primary' : 'text-medium-emphasis'">
                {{ arrivalStats.values[i] || '' }}
              </span>
              <div class="fd-hour-fill rounded-t"
                   :class="{ 'fd-hour-fill--now': isCurrentHour(h) }"
                   :style="{ height: `${arrivalHeight(i)}%` }" />
            </div>
          </div>
          <div class="d-flex ga-1 mt-2">
            <span v-for="h in arrivalStats.hours" :key="h" class="text-caption text-medium-emphasis flex-1 text-center">
              {{ h % 12 || 12 }}{{ h < 12 ? 'a' : 'p' }}
            </span>
          </div>
        </v-card>
      </v-col>

      <!-- Attention needed -->
      <v-col cols="12" lg="4">
        <v-card rounded="lg" variant="outlined" class="stat-card pa-4 h-100 d-flex flex-column">
          <div class="d-flex align-center justify-space-between mb-2">
            <span class="text-caption text-medium-emphasis font-weight-medium">ATTENTION NEEDED</span>
            <v-chip v-if="attentionList.length" size="x-small" color="error" variant="tonal"
                    prepend-icon="mdi-bell-ring">{{ attentionList.length }}</v-chip>
          </div>
          <div class="flex-grow-1 fd-attention-scroll">
            <div v-for="v in attentionList" :key="v.id" class="fd-attention-item" @click="openVisit(v)">
              <v-avatar size="32" variant="tonal" :color="attentionColor(v)">
                <v-icon size="16">{{ attentionIcon(v) }}</v-icon>
              </v-avatar>
              <div class="min-w-0 flex-grow-1">
                <div class="font-weight-medium text-truncate">{{ v.patient_name }}</div>
                <div class="text-caption text-medium-emphasis">{{ attentionReason(v) }}</div>
              </div>
              <v-chip size="x-small" variant="tonal" :color="waitColor(v.waiting_minutes)">
                {{ waitLabel(v.waiting_minutes) }}
              </v-chip>
            </div>
            <div v-if="!attentionList.length" class="fd-attention-clear">
              <v-icon size="28" color="success">mdi-check-circle</v-icon>
              <div class="text-body-2 font-weight-medium mt-1">All clear</div>
              <div class="text-caption text-medium-emphasis">
                No critical, overdue or unpaid visits in this view.
              </div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ═══════════ Command toolbar ═══════════ -->
    <v-card rounded="lg" variant="outlined" class="pa-3 mb-4">
      <div class="d-flex flex-wrap align-center ga-3">
        <v-text-field v-model="search" density="compact" variant="outlined" rounded="lg" hide-details
                      prepend-inner-icon="mdi-magnify" placeholder="Search name, visit no. or patient no."
                      style="max-width: 320px" clearable />
        <div class="d-flex align-center ga-1">
          <v-btn icon="mdi-chevron-left" variant="text" size="small" @click="shiftDay(-1)" />
          <v-text-field v-model="date" type="date" density="compact" variant="outlined" rounded="lg"
                        hide-details label="Visit date" style="max-width: 175px" @update:model-value="load" />
          <v-btn icon="mdi-chevron-right" variant="text" size="small" @click="shiftDay(1)" />
          <v-btn variant="text" size="small" class="text-none" prepend-icon="mdi-calendar-today"
                 :disabled="date === localDate()" @click="goToday">Today</v-btn>
        </div>
        <v-switch v-model="onlyOpen" color="primary" density="compact" hide-details
                  label="Open visits only" inset @update:model-value="load" />
        <v-switch v-if="isClinician" v-model="myPatients" color="primary" density="compact" hide-details
                  label="My patients" inset @update:model-value="load" />
        <v-spacer />
        <v-btn-toggle v-model="viewMode" mandatory density="compact" color="primary" rounded="lg">
          <v-btn value="board" size="small" variant="outlined" class="text-none">
            <v-icon start size="16">mdi-view-column</v-icon>Board
          </v-btn>
          <v-btn value="queue" size="small" variant="outlined" class="text-none">
            <v-icon start size="16">mdi-view-list</v-icon>Queue
          </v-btn>
        </v-btn-toggle>
      </div>
    </v-card>

    <v-alert v-if="error" type="error" variant="tonal" density="compact" rounded="lg" class="mb-4">
      {{ error }}
    </v-alert>

    <!-- ═══════════ BOARD VIEW ═══════════ -->
    <div v-if="viewMode === 'board'" class="fd-board" :class="{ 'fd-board--loading': loading }">
      <section v-for="stage in visibleStages" :key="stage.value" class="fd-column">
        <header class="fd-column__head" :style="{ borderTopColor: stageMeta(stage.value).color }">
          <div class="d-flex align-center ga-2 min-w-0">
            <v-icon size="16" :color="stageMeta(stage.value).color">{{ stageMeta(stage.value).icon }}</v-icon>
            <span class="fd-column__title">{{ stage.label }}</span>
          </div>
          <v-chip size="x-small" variant="tonal" :color="stageMeta(stage.value).color" class="font-weight-bold">
            {{ stage.visits.length }}
          </v-chip>
        </header>

        <div class="fd-column__body">
          <div v-if="!stage.visits.length" class="fd-empty">No patients</div>

          <article
            v-for="visit in stage.visits"
            :key="visit.id"
            class="fd-card"
            :class="[{ 'fd-card--late': visit.waiting_minutes >= 30, 'fd-card--critical': (visit.triage_esi || 9) <= 2 }]"
            @click="openVisit(visit)"
          >
            <div class="d-flex align-start ga-2">
              <v-avatar size="34" variant="tonal" :color="priorityColor(visit.priority)" class="mt-1">
                <span class="text-caption font-weight-bold">{{ initials(visit.patient_name) }}</span>
              </v-avatar>
              <div class="min-w-0 flex-grow-1">
                <div class="fd-card__name">{{ visit.patient_name }}</div>
                <div class="fd-card__meta">
                  {{ visit.patient_number }}
                  <span v-if="visit.patient_gender"> · {{ visit.patient_gender }}</span>
                  <span v-if="ageOf(visit) !== null"> · {{ ageOf(visit) }}y</span>
                </div>
              </div>
              <v-menu v-model="menus[visit.id]" location="bottom end" :close-on-content-click="false">
                <template #activator="{ props }">
                  <v-btn v-bind="props" icon="mdi-dots-vertical" size="x-small" variant="text"
                         @click.stop />
                </template>
                <v-list density="compact" rounded="lg">
                  <v-list-item prepend-icon="mdi-open-in-new" title="Open journey"
                               @click="openVisit(visit)" />
                  <v-list-item v-for="a in quickActions(visit)" :key="a.key"
                               :prepend-icon="a.icon" :title="a.label" @click="runQuick(visit, a)" />
                </v-list>
              </v-menu>
            </div>

            <div class="d-flex flex-wrap ga-1 mt-2">
              <v-chip size="x-small" variant="tonal" prepend-icon="mdi-ticket-confirmation">
                Q{{ visit.queue_number }}
              </v-chip>
              <v-chip v-if="visit.priority && visit.priority !== 'routine'" size="x-small" variant="tonal"
                      :color="priorityColor(visit.priority)" prepend-icon="mdi-flag">
                {{ visit.priority }}
              </v-chip>
              <v-chip size="x-small" variant="tonal"
                      :color="paymentColor(visit.payment_status)" prepend-icon="mdi-cash-check">
                {{ visit.payment_status_label }}
              </v-chip>
              <v-chip v-if="visit.triage_esi" size="x-small" variant="tonal"
                      :color="esiColor(visit.triage_esi)" prepend-icon="mdi-alert-circle-outline">
                ESI {{ visit.triage_esi }}
              </v-chip>
              <v-chip v-if="visit.doctor_name" size="x-small" variant="tonal" prepend-icon="mdi-stethoscope">
                {{ shortName(visit.doctor_name) }}
              </v-chip>
            </div>

            <div class="fd-card__wait mt-2">
              <div class="fd-card__waitbar">
                <div class="fd-card__waitfill" :class="`bg-${waitColor(visit.waiting_minutes)}`"
                     :style="{ width: `${waitPct(visit.waiting_minutes)}%` }" />
              </div>
              <span class="text-caption font-weight-bold" :class="`text-${waitColor(visit.waiting_minutes)}`">
                {{ waitLabel(visit.waiting_minutes) }} wait
              </span>
            </div>

            <div class="fd-card__foot">
              <span class="text-caption text-medium-emphasis">
                <v-icon size="13">mdi-door-open</v-icon> {{ timeOf(visit.arrived_at) }}
              </span>
              <span v-if="visit.invoice_balance && Number(visit.invoice_balance) > 0" class="fd-card__fee">
                {{ formatMoney(visit.invoice_balance, settings.currency) }} due
              </span>
              <span v-else-if="visit.consultation_fee" class="fd-card__fee">
                {{ formatMoney(visit.consultation_fee, settings.currency) }}
              </span>
            </div>
          </article>
        </div>
      </section>
    </div>

    <!-- ═══════════ QUEUE VIEW ═══════════ -->
    <v-card v-else rounded="lg" variant="outlined" :loading="loading">
      <v-data-table
        :headers="queueHeaders" :items="filteredVisits" item-value="id" :items-per-page="15"
        density="comfortable" hover class="fd-queue" :loading="loading"
        no-data-text="No visits match this view"
        @click:row="(_, { item }) => openVisit(item)"
      >
        <template #item.queue_number="{ value }">
          <v-chip size="small" variant="tonal" color="primary" class="font-weight-bold">Q{{ value }}</v-chip>
        </template>
        <template #item.patient_name="{ item }">
          <div class="d-flex align-center ga-2">
            <v-avatar size="32" variant="tonal" :color="priorityColor(item.priority)">
              <span class="text-caption font-weight-bold">{{ initials(item.patient_name) }}</span>
            </v-avatar>
            <div class="min-w-0">
              <div class="font-weight-medium">{{ item.patient_name }}</div>
              <div class="text-caption text-medium-emphasis">
                {{ item.patient_number }}
                <span v-if="item.patient_gender"> · {{ item.patient_gender }}</span>
                <span v-if="item.patient_dob"> · {{ ageOf(item) }}y</span>
              </div>
            </div>
          </div>
        </template>
        <template #item.stage_label="{ item }">
          <v-chip size="small" variant="tonal" :color="stageMeta(item.stage).color">
            <v-icon size="13" start>{{ stageMeta(item.stage).icon }}</v-icon>
            {{ item.stage_label }}
          </v-chip>
        </template>
        <template #item.acuity="{ item }">
          <div class="d-flex ga-1 flex-wrap">
            <v-chip v-if="item.priority && item.priority !== 'routine'" size="x-small" variant="tonal"
                    :color="priorityColor(item.priority)">{{ item.priority }}</v-chip>
            <v-chip v-if="item.triage_esi" size="x-small" variant="tonal" :color="esiColor(item.triage_esi)">
              ESI {{ item.triage_esi }}
            </v-chip>
            <span v-if="item.priority === 'routine' && !item.triage_esi"
                  class="text-caption text-medium-emphasis">Routine</span>
          </div>
        </template>
        <template #item.payment_status="{ item }">
          <div class="d-flex flex-column">
            <v-chip size="x-small" variant="tonal" :color="paymentColor(item.payment_status)">
              {{ item.payment_status_label }}
            </v-chip>
            <span v-if="item.invoice_balance && Number(item.invoice_balance) > 0"
                  class="text-caption text-orange-darken-2 mt-1">
              {{ formatMoney(item.invoice_balance, settings.currency) }} due
            </span>
          </div>
        </template>
        <template #item.doctor_name="{ value }">
          <span v-if="value" class="text-body-2">{{ shortName(value) }}</span>
          <span v-else class="text-caption text-medium-emphasis">Unassigned</span>
        </template>
        <template #item.waiting_minutes="{ value }">
          <span class="text-body-2 font-weight-bold" :class="`text-${waitColor(value)}`">
            {{ waitLabel(value) }}
          </span>
        </template>
        <template #item.invoice_balance="{ item }">
          <span v-if="item.invoice_balance && Number(item.invoice_balance) > 0"
                class="font-weight-bold text-orange-darken-2">
            {{ formatMoney(item.invoice_balance, settings.currency) }}
          </span>
          <span v-else class="text-caption text-medium-emphasis">Settled</span>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end" @click.stop>
            <v-btn icon="mdi-open-in-new" variant="text" size="small" @click="openVisit(item)" />
            <v-menu location="bottom end" :close-on-content-click="false">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" />
              </template>
              <v-list density="compact" rounded="lg">
                <v-list-item prepend-icon="mdi-open-in-new" title="Open journey" @click="openVisit(item)" />
                <v-list-item v-for="a in quickActions(item)" :key="a.key"
                             :prepend-icon="a.icon" :title="a.label" @click="runQuick(item, a)" />
              </v-list>
            </v-menu>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- ═══════════ Payment dialog ═══════════ -->
    <v-dialog v-model="payOpen" max-width="460">
      <v-card rounded="lg">
        <BrandDialogHeader icon="mdi-cash-register" title="Collect payment" :subtitle="payTarget?.patient_name || ''" @close="payOpen = false" />
        <div class="pa-4">
          <v-text-field v-model.number="pay.amount" type="number" min="0" :prefix="settings.currency"
                        label="Amount" variant="outlined" density="comfortable" />
          <v-select v-model="pay.method" :items="paymentMethods" label="Method"
                    variant="outlined" density="comfortable" class="mt-3" />
          <v-text-field v-model="pay.reference" label="Reference / receipt no."
                        variant="outlined" density="comfortable" class="mt-3" />
          <v-alert v-if="payError" type="error" variant="tonal" density="compact" class="mt-2">{{ payError }}</v-alert>
        </div>
        <v-divider />
        <div class="d-flex justify-end ga-2 pa-4">
          <v-btn variant="text" class="text-none" @click="payOpen = false">Cancel</v-btn>
          <v-btn color="success" class="text-none" :loading="paying" @click="submitPayment">Record payment</v-btn>
        </div>
      </v-card>
    </v-dialog>

    <!-- ═══════════ Clinic settings dialog ═══════════ -->
    <v-dialog v-model="settingsOpen" max-width="560">
      <v-card rounded="lg">
        <BrandDialogHeader icon="mdi-cog-outline" title="Front-desk settings" subtitle="Charging and workflow rules" @close="settingsOpen = false" />
        <div class="pa-4">
          <v-row dense>
            <v-col cols="8">
              <v-text-field v-model.number="settingsDraft.consultation_fee" type="number" min="0"
                            label="Default consultation fee" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="4">
              <v-text-field v-model="settingsDraft.currency" label="Currency"
                            variant="outlined" density="comfortable" />
            </v-col>
          </v-row>
          <v-switch v-model="settingsDraft.require_payment_before_triage" color="primary"
                    label="Require payment before triage" density="compact" hide-details class="mt-2" />
          <v-switch v-model="settingsDraft.require_triage_before_doctor" color="primary"
                    label="Require triage before the doctor" density="compact" hide-details />
          <v-switch v-model="settingsDraft.auto_invoice_lab_tests" color="primary"
                    label="Add lab test prices to the patient invoice" density="compact" hide-details />
          <v-switch v-model="settingsDraft.allow_fee_waiver" color="primary"
                    label="Allow fee waivers" density="compact" hide-details />
        </div>
        <v-divider />
        <div class="d-flex justify-end ga-2 pa-4">
          <v-btn variant="text" class="text-none" @click="settingsOpen = false">Close</v-btn>
          <v-btn color="primary" class="text-none" :loading="savingSettings" @click="saveSettings">
            Save settings
          </v-btn>
        </div>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3500">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { computed, onMounted, onBeforeUnmount, reactive, ref } from 'vue'
import { useRouter } from '#app'
import { useAuthStore } from '~/stores/auth'
import { formatMoney } from '~/utils/format'

const { $api } = useNuxtApp()
const router = useRouter()
const auth = useAuthStore()

const CLINICAL_ROLES = new Set(['doctor', 'clinical_officer', 'dentist'])
const isClinician = computed(() => CLINICAL_ROLES.has(auth.role))

const loading = ref(false)
const error = ref('')
const board = ref({ stages: [], kpis: {}, settings: {} })
const settings = ref({ consultation_fee: 0, currency: 'KES' })
const search = ref('')
const onlyOpen = ref(true)
const myPatients = ref(false)
const viewMode = ref('board')
const date = ref(localDate())
const menus = reactive({})

function localDate(d = new Date()) {
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

const snack = reactive({ show: false, color: 'success', text: '' })
function notify(text, color = 'success') {
  Object.assign(snack, { show: true, color, text })
}

const kpis = computed(() => board.value.kpis || {})
const settingsDraft = reactive({})
const settingsOpen = ref(false)
const savingSettings = ref(false)

// ── Board ────────────────────────────────────────────────────────────
const STAGE_META = {
  arrived: { icon: 'mdi-door-open', color: 'blue-grey' },
  registered: { icon: 'mdi-account-check', color: 'indigo' },
  awaiting_payment: { icon: 'mdi-cash-clock', color: 'orange-darken-2' },
  paid: { icon: 'mdi-cash-check', color: 'teal' },
  triage: { icon: 'mdi-heart-pulse', color: 'deep-orange' },
  awaiting_doctor: { icon: 'mdi-clock-alert-outline', color: 'amber-darken-3' },
  in_consultation: { icon: 'mdi-stethoscope', color: 'green-darken-1' },
  in_lab: { icon: 'mdi-flask-outline', color: 'purple' },
  lab_ready: { icon: 'mdi-file-check-outline', color: 'purple-darken-1' },
  review: { icon: 'mdi-clipboard-search-outline', color: 'blue' },
  prescribed: { icon: 'mdi-pill', color: 'pink' },
  discharged: { icon: 'mdi-check-decagram', color: 'green-darken-2' },
  cancelled: { icon: 'mdi-cancel', color: 'grey' }
}
function stageMeta(value) {
  return STAGE_META[value] || { icon: 'mdi-circle-outline', color: 'grey' }
}

const allVisits = computed(() =>
  (board.value.stages || []).flatMap(s => s.visits || [])
)

const filteredVisits = computed(() => {
  const q = search.value.trim().toLowerCase()
  if (!q) return allVisits.value
  return allVisits.value.filter(v =>
    (v.patient_name || '').toLowerCase().includes(q)
    || (v.visit_number || '').toLowerCase().includes(q)
    || (v.patient_number || '').toLowerCase().includes(q))
})

// Hide noise columns: arrived/cancelled unless they have patients.
const visibleStages = computed(() => {
  const q = search.value.trim().toLowerCase()
  const skip = ['arrived', 'cancelled']
  return (board.value.stages || [])
    .filter(s => !skip.includes(s.value) || s.visits.length)
    .map(s => ({
      ...s,
      visits: q
        ? s.visits.filter(v =>
            (v.patient_name || '').toLowerCase().includes(q)
            || (v.visit_number || '').toLowerCase().includes(q)
            || (v.patient_number || '').toLowerCase().includes(q))
        : s.visits
    }))
    .filter(s => s.visits.length || !['discharged', 'cancelled'].includes(s.value))
})

// ── KPI cards ────────────────────────────────────────────────────────
const outstandingTotal = computed(() =>
  filteredVisits.value.reduce((sum, v) => sum + Number(v.invoice_balance || 0), 0)
)

const kpiCards = computed(() => [
  { key: 'open', label: 'In clinic now', value: kpis.value.open || 0,
    hint: `${(kpis.value.awaiting_doctor || 0)} queued for doctor`, icon: 'mdi-account-multiple',
    color: 'primary', tone: 'text-primary' },
  { key: 'billing', label: 'Awaiting payment',
    value: kpis.value.awaiting_payment || 0,
    hint: `${formatMoney(outstandingTotal.value, settings.value.currency)} outstanding`,
    icon: 'mdi-cash-clock', color: 'orange-darken-2', tone: 'text-orange-darken-2' },
  { key: 'critical', label: 'Critical (ESI 1–2)', value: kpis.value.critical || 0,
    hint: 'high-acuity patients', icon: 'mdi-alert-circle', color: 'red-darken-3',
    tone: 'text-red-darken-3' },
  { key: 'today', label: 'Total today', value: kpis.value.total || 0,
    hint: `${kpis.value.discharged || 0} discharged · ${kpis.value.cancelled || 0} cancelled`,
    icon: 'mdi-calendar-today', color: 'info', tone: 'text-info' }
])

// ── Journey donut ────────────────────────────────────────────────────
const JOURNEY_GROUPS = [
  { key: 'reception', label: 'Reception', stages: ['arrived', 'registered'], color: '#3949AB' },
  { key: 'billing', label: 'Billing', stages: ['awaiting_payment'], color: '#FB8C00' },
  { key: 'ready', label: 'Ready', stages: ['paid'], color: '#00897B' },
  { key: 'triage', label: 'Triage', stages: ['triage'], color: '#F4511E' },
  { key: 'queue', label: 'Doctor queue', stages: ['awaiting_doctor'], color: '#FFB300' },
  { key: 'room', label: 'In room', stages: ['in_consultation'], color: '#43A047' },
  { key: 'lab', label: 'Lab', stages: ['in_lab', 'lab_ready', 'review'], color: '#8E24AA' },
  { key: 'rx', label: 'Pharmacy', stages: ['prescribed'], color: '#EC407A' },
  { key: 'done', label: 'Discharged', stages: ['discharged'], color: '#2E7D32' }
]

const journeyLegend = computed(() =>
  JOURNEY_GROUPS.map(g => ({
    ...g,
    count: (board.value.stages || [])
      .filter(s => g.stages.includes(s.value))
      .reduce((n, s) => n + s.visits.length, 0)
  })).filter(g => g.count > 0)
)

const donutSegments = computed(() =>
  journeyLegend.value.map(g => ({ value: g.count, color: g.color }))
)

// ── Arrivals by hour ─────────────────────────────────────────────────
const arrivalStats = computed(() => {
  const counts = {}
  let minH = 7
  let maxH = 19
  for (const v of allVisits.value) {
    if (!v.arrived_at) continue
    const h = new Date(v.arrived_at).getHours()
    counts[h] = (counts[h] || 0) + 1
    minH = Math.min(minH, h)
    maxH = Math.max(maxH, h)
  }
  const hours = []
  for (let h = minH; h <= maxH; h++) hours.push(h)
  const values = hours.map(h => counts[h] || 0)
  return { hours, values, max: Math.max(1, ...values), total: allVisits.value.length }
})

function arrivalHeight(i) {
  return Math.max(5, (arrivalStats.value.values[i] / arrivalStats.value.max) * 100)
}

function isCurrentHour(h) {
  if (date.value !== localDate()) return false
  return new Date().getHours() === h
}

// ── Attention needed ─────────────────────────────────────────────────
const attentionList = computed(() =>
  filteredVisits.value
    .filter(v => v.is_open)
    .map(v => ({
      visit: v,
      score: ((v.triage_esi || 9) <= 2 ? 100 : 0)
        + (v.waiting_minutes >= 30 ? 50 : 0)
        + (['unpaid', 'partial'].includes(v.payment_status) && Number(v.invoice_balance) > 0 ? 10 : 0)
    }))
    .filter(r => r.score > 0)
    .sort((a, b) => b.score - a.score || b.visit.waiting_minutes - a.visit.waiting_minutes)
    .slice(0, 7)
    .map(r => r.visit)
)

function attentionReason(v) {
  if ((v.triage_esi || 9) <= 2) return `ESI ${v.triage_esi} — high acuity`
  if (v.waiting_minutes >= 30) return `Waiting ${waitLabel(v.waiting_minutes)} — over SLA`
  return 'Payment outstanding'
}
function attentionColor(v) {
  if ((v.triage_esi || 9) <= 2) return 'error'
  if (v.waiting_minutes >= 30) return 'warning'
  return 'orange-darken-2'
}
function attentionIcon(v) {
  if ((v.triage_esi || 9) <= 2) return 'mdi-alert-circle'
  if (v.waiting_minutes >= 30) return 'mdi-timer-sand'
  return 'mdi-cash-clock'
}

// ── Presentation helpers ──────────────────────────────────────────────
function paymentColor(status) {
  return { unpaid: 'orange-darken-2', partial: 'amber-darken-3', paid: 'green-darken-2', waived: 'grey' }[status] || 'grey'
}
function esiColor(level) {
  if (level <= 2) return 'red-darken-2'
  if (level === 3) return 'orange-darken-2'
  return 'green-darken-1'
}
function priorityColor(priority) {
  return { emergency: 'error', urgent: 'warning', routine: 'primary' }[priority] || 'primary'
}
function waitColor(minutes) {
  if (minutes >= 30) return 'error'
  if (minutes >= 15) return 'warning'
  return 'success'
}
function waitPct(minutes) {
  return Math.min(100, Math.round((minutes / 30) * 100))
}
function waitLabel(minutes) {
  if (minutes == null) return '—'
  if (minutes < 60) return `${minutes}m`
  return `${Math.floor(minutes / 60)}h ${String(minutes % 60).padStart(2, '0')}m`
}
function shortName(name) {
  const parts = (name || '').split(' ')
  return parts.length > 1 ? `Dr. ${parts[parts.length - 1]}` : name
}
function initials(name) {
  const parts = (name || '').trim().split(/\s+/)
  return ((parts[0]?.[0] || '') + (parts[1]?.[0] || '')).toUpperCase() || '?'
}
function ageOf(visit) {
  if (!visit.patient_dob) return null
  const dob = new Date(visit.patient_dob)
  if (isNaN(dob)) return null
  return Math.floor((Date.now() - dob.getTime()) / 31557600000)
}
function timeOf(stamp) {
  if (!stamp) return '—'
  const d = new Date(stamp)
  if (isNaN(d)) return stamp
  let h = d.getHours()
  const ampm = h >= 12 ? 'pm' : 'am'
  h = h % 12 || 12
  return `${h}:${String(d.getMinutes()).padStart(2, '0')}${ampm}`
}

// ── Queue table ───────────────────────────────────────────────────────
const queueHeaders = [
  { title: '#', key: 'queue_number', width: 76 },
  { title: 'Patient', key: 'patient_name' },
  { title: 'Stage', key: 'stage_label', width: 168 },
  { title: 'Acuity', key: 'acuity', sortable: false, width: 140 },
  { title: 'Payment', key: 'payment_status', width: 148 },
  { title: 'Doctor', key: 'doctor_name', width: 140 },
  { title: 'Wait', key: 'waiting_minutes', width: 96 },
  { title: 'Balance', key: 'invoice_balance', sortable: false, width: 130 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 96 }
]

// ── Live sync indicator ───────────────────────────────────────────────
const nowTick = ref(Date.now())
const syncedLabel = computed(() => {
  const stamp = board.value.generated_at
  if (!stamp) return ''
  const diff = Math.max(0, Math.round((nowTick.value - new Date(stamp).getTime()) / 1000))
  if (diff < 10) return 'Live'
  if (diff < 90) return `Synced ${diff}s ago`
  return `Synced ${Math.round(diff / 60)}m ago`
})

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data } = await $api.get('/visits/board/', {
      params: {
        date: date.value,
        open: onlyOpen.value ? 1 : 0,
        mine: myPatients.value ? 1 : 0
      }
    })
    board.value = data
    settings.value = data.settings || settings.value
    Object.assign(settingsDraft, data.settings || {})
    nowTick.value = Date.now()
  } catch (e) {
    error.value = e?.response?.data?.detail || 'Failed to load the front-desk board.'
  } finally {
    loading.value = false
  }
}

function shiftDay(delta) {
  const d = new Date(`${date.value}T00:00:00`)
  d.setDate(d.getDate() + delta)
  date.value = localDate(d)
  load()
}
function goToday() {
  date.value = localDate()
  load()
}

function openVisit(visit) {
  router.push(`/clinics/front-desk/${visit.id}`)
}

// ── Quick actions ────────────────────────────────────────────────────
function quickActions(visit) {
  const list = []
  if (visit.stage === 'registered') {
    list.push({ key: 'charge', label: 'Charge consultation fee', icon: 'mdi-cash-plus' })
    list.push({ key: 'waive', label: 'Waive fee', icon: 'mdi-cash-off' })
  }
  if (visit.stage === 'awaiting_payment') {
    list.push({ key: 'pay', label: 'Collect payment', icon: 'mdi-cash-register' })
  }
  if (visit.stage === 'paid') {
    list.push({ key: 'triage', label: 'Send to triage', icon: 'mdi-heart-pulse' })
  }
  if (visit.stage === 'triage') {
    list.push({ key: 'triage-complete', label: 'Complete triage', icon: 'mdi-clipboard-check' })
  }
  if (visit.stage === 'awaiting_doctor' && visit.doctor) {
    list.push({ key: 'consult', label: 'Start consultation', icon: 'mdi-stethoscope' })
  }
  if (['in_consultation', 'lab_ready', 'review', 'prescribed'].includes(visit.stage)) {
    list.push({ key: 'discharge', label: 'Discharge', icon: 'mdi-check-decagram' })
  }
  list.push({ key: 'cancel', label: 'Cancel visit', icon: 'mdi-cancel' })
  return list
}

async function runQuick(visit, action) {
  menus[visit.id] = false
  if (['triage-complete', 'discharge', 'cancel'].includes(action.key)) {
    openVisit(visit)
    return
  }
  try {
    if (action.key === 'charge') {
      await $api.post(`/visits/${visit.id}/charge-fee/`, {})
      notify('Consultation fee charged')
    } else if (action.key === 'waive') {
      await $api.post(`/visits/${visit.id}/waive-fee/`, { reason: 'Waived at reception' })
      notify('Fee waived')
    } else if (action.key === 'pay') {
      openPayment(visit)
      return
    } else if (action.key === 'triage') {
      await $api.post(`/visits/${visit.id}/start-triage/`, {})
      notify('Patient sent to triage')
    } else if (action.key === 'consult') {
      await $api.post(`/visits/${visit.id}/start-consultation/`, {})
      notify('Consultation started')
    }
    await load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Action failed', 'error')
  }
}

// ── Registration ─────────────────────────────────────────────────────
function openRegister() {
  router.push('/clinics/front-desk/register')
}

// ── Payment ──────────────────────────────────────────────────────────
const paymentMethods = [
  { title: 'Cash', value: 'cash' },
  { title: 'Card', value: 'card' },
  { title: 'M-Pesa', value: 'mpesa' },
  { title: 'Insurance', value: 'insurance' },
  { title: 'Bank transfer', value: 'bank_transfer' }
]
const payOpen = ref(false)
const paying = ref(false)
const payError = ref('')
const payTarget = ref(null)
const pay = reactive({ amount: 0, method: 'cash', reference: '' })

function openPayment(visit) {
  payTarget.value = visit
  pay.amount = Number(visit.invoice_balance || visit.consultation_fee || 0)
  pay.method = 'cash'
  pay.reference = ''
  payError.value = ''
  payOpen.value = true
}

async function submitPayment() {
  paying.value = true
  payError.value = ''
  try {
    await $api.post(`/visits/${payTarget.value.id}/collect-payment/`, {
      amount: pay.amount, method: pay.method, reference: pay.reference
    })
    payOpen.value = false
    notify('Payment recorded')
    await load()
  } catch (e) {
    payError.value = extractError(e)
  } finally {
    paying.value = false
  }
}

// ── Settings ─────────────────────────────────────────────────────────
function openSettings() {
  Object.assign(settingsDraft, settings.value)
  settingsOpen.value = true
}


async function saveSettings() {
  savingSettings.value = true
  try {
    const { data } = await $api.patch('/visits/settings/', settingsDraft)
    settings.value = data
    Object.assign(settingsDraft, data)
    settingsOpen.value = false
    notify('Front-desk settings saved')
  } catch (e) {
    notify(extractError(e), 'error')
  } finally {
    savingSettings.value = false
  }
}

function extractError(e) {
  const d = e?.response?.data
  if (!d) return e?.message || 'Something went wrong'
  if (typeof d === 'string') return d
  if (d.detail) return d.detail
  return Object.entries(d).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(' ') : v}`).join(' · ')
}

// ── Auto refresh ─────────────────────────────────────────────────────
let timer = null
let ticker = null
onMounted(() => {
  load()
  timer = setInterval(load, 60000)
  ticker = setInterval(() => { nowTick.value = Date.now() }, 10000)
})
onBeforeUnmount(() => {
  clearInterval(timer)
  clearInterval(ticker)
})
</script>

<style scoped>
.min-w-0 { min-width: 0; }

.stat-card {
  transition: box-shadow 0.2s ease, transform 0.15s ease;
}
.stat-card:hover {
  box-shadow: 0 6px 16px rgba(0, 0, 0, 0.08);
}

/* Live pulse dot */
.fd-live-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: rgb(var(--v-theme-success));
  display: inline-block;
  margin-right: 2px;
  animation: fd-pulse 1.8s ease-in-out infinite;
}
@keyframes fd-pulse {
  0%, 100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.4; transform: scale(0.8); }
}

/* Journey legend */
.fd-legend {
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-width: 150px;
}
.fd-legend__row {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 0.74rem;
}
.fd-legend__dot {
  width: 9px;
  height: 9px;
  border-radius: 3px;
  flex-shrink: 0;
}
.fd-legend__label {
  color: rgba(var(--v-theme-on-surface), 0.7);
  flex: 1;
  white-space: nowrap;
}
.fd-legend__count {
  font-size: 0.76rem;
}

/* Arrivals by hour */
.fd-hour-chart {
  min-height: 110px;
  align-items: flex-end;
}
.fd-hour-col {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-end;
  height: 100%;
  min-width: 14px;
}
.fd-hour-fill {
  width: 100%;
  min-height: 4px;
  background: rgb(var(--v-theme-primary));
  opacity: 0.35;
  border-radius: 4px 4px 0 0;
  transition: height 0.3s ease, opacity 0.2s ease;
}
.fd-hour-fill:hover { opacity: 0.65; }
.fd-hour-fill--now { opacity: 0.85; }
.rounded-t { border-radius: 4px 4px 0 0; }

/* Attention needed */
.fd-attention-scroll {
  max-height: 240px;
  overflow-y: auto;
}
.fd-attention-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 7px 8px;
  border-radius: 10px;
  cursor: pointer;
  transition: background 0.15s ease;
}
.fd-attention-item:hover {
  background: rgba(var(--v-theme-on-surface), 0.05);
}
.fd-attention-item + .fd-attention-item {
  margin-top: 2px;
}
.fd-attention-clear {
  text-align: center;
  padding: 28px 12px;
}

/* ── Journey board ── */
.fd-board {
  display: grid;
  grid-auto-flow: column;
  grid-auto-columns: minmax(255px, 1fr);
  gap: 12px;
  overflow-x: auto;
  padding-bottom: 12px;
  align-items: start;
  transition: opacity 0.2s ease;
}
.fd-board--loading { opacity: 0.55; }

.fd-column {
  background: rgba(var(--v-theme-on-surface), 0.03);
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  border-radius: 14px;
  padding: 10px;
  min-height: 140px;
}
.fd-column__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 6px 6px 10px;
  border-top: 3px solid transparent;
  border-radius: 4px;
  margin-bottom: 4px;
}
.fd-column__title {
  font-size: 0.72rem;
  font-weight: 800;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.fd-column__body {
  max-height: 58vh;
  overflow-y: auto;
}
.fd-empty {
  font-size: 0.75rem;
  color: rgba(var(--v-theme-on-surface), 0.45);
  text-align: center;
  padding: 18px 0;
}

.fd-card {
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  border-radius: 12px;
  padding: 10px 12px;
  margin-bottom: 8px;
  cursor: pointer;
  transition: transform 0.15s ease, box-shadow 0.15s ease, border-color 0.15s ease;
}
.fd-card:hover {
  transform: translateY(-1px);
  box-shadow: 0 8px 20px rgba(15, 23, 42, 0.1);
}
.fd-card--late { border-color: rgba(239, 68, 68, 0.45); }
.fd-card--critical {
  border-color: rgba(211, 47, 47, 0.55);
  box-shadow: inset 3px 0 0 #d32f2f;
}
.fd-card__name {
  font-weight: 700;
  font-size: 0.86rem;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.fd-card__meta {
  font-size: 0.7rem;
  color: rgba(var(--v-theme-on-surface), 0.55);
  text-transform: capitalize;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.fd-card__wait {
  display: flex;
  align-items: center;
  gap: 8px;
}
.fd-card__waitbar {
  flex: 1;
  height: 4px;
  border-radius: 2px;
  background: rgba(var(--v-theme-on-surface), 0.08);
  overflow: hidden;
}
.fd-card__waitfill {
  height: 100%;
  border-radius: 2px;
  transition: width 0.3s ease;
}
.fd-card__foot {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 6px;
  margin-top: 8px;
  padding-top: 6px;
  border-top: 1px dashed rgba(var(--v-theme-on-surface), 0.1);
  font-size: 0.7rem;
  color: rgba(var(--v-theme-on-surface), 0.6);
}
.fd-card__fee { font-weight: 700; white-space: nowrap; }

/* Queue table */
.fd-queue {
  font-size: 0.82rem;
}
.fd-queue :deep(tbody tr) {
  cursor: pointer;
}

.fd-dialog-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 18px;
}
</style>
