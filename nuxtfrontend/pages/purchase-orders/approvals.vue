<template>
  <v-container fluid class="pa-3 pa-md-5">
    <ProcToolbar
      title="Approvals"
      subtitle="Spend governance — value-based routing and release of draft commitments"
      eyebrow="PROCUREMENT · GOVERNANCE"
      icon="mdi-clipboard-check-outline"
      color="warning"
      :loading="loading"
      :branch-filter="branchFilter"
      :branch-items="branchFilterItems"
      :branch-locked="isBranchLocked"
      @refresh="load"
      @update:branch-filter="(v) => (branchFilter = v)"
    >
      <template #actions>
        <v-btn variant="tonal" color="warning" rounded="lg" class="text-none" prepend-icon="mdi-tune-variant"
               @click="policyDialog = true">Approval policy</v-btn>
        <v-btn color="success" rounded="lg" class="text-none" prepend-icon="mdi-check-all"
               :disabled="!selected.length" @click="bulkApprove">Approve selected</v-btn>
      </template>
    </ProcToolbar>

    <!-- Policy banner -->
    <v-alert :color="approvalThreshold ? 'info' : 'warning'" variant="tonal" rounded="lg" border="start" class="mb-4">
      <div class="d-flex flex-wrap align-center justify-space-between ga-3">
        <div class="d-flex align-center">
          <v-icon size="26" class="mr-3">{{ approvalThreshold ? 'mdi-shield-check-outline' : 'mdi-shield-alert-outline' }}</v-icon>
          <div>
            <div class="text-subtitle-2 font-weight-bold">
              {{ approvalThreshold
                ? `Orders of ${formatMoney(approvalThreshold)} or more require release`
                : 'No approval threshold configured' }}
            </div>
            <div class="text-body-2">
              {{ approvalThreshold
                ? 'Draft purchase orders are routed to a band based on value. Approving releases the order to the supplier.'
                : 'Set a threshold to activate value-based approval routing and stop large commitments slipping through.' }}
            </div>
          </div>
        </div>
        <v-btn variant="flat" :color="approvalThreshold ? 'info' : 'warning'" class="text-none"
               prepend-icon="mdi-tune-variant" @click="policyDialog = true">Configure</v-btn>
      </div>
    </v-alert>

    <!-- KPI strip -->
    <v-row dense>
      <v-col v-for="k in kpis" :key="k.title" cols="6" md="3">
        <KpiTile v-bind="k" />
      </v-col>
    </v-row>

    <!-- Bands -->
    <v-row class="mt-1">
      <v-col v-for="b in bands" :key="b.label" cols="12" md="4">
        <v-card rounded="lg" class="pa-4 h-100" variant="tonal" :color="b.color">
          <div class="d-flex align-center justify-space-between mb-2">
            <div class="d-flex align-center">
              <v-avatar size="34" :color="b.color" variant="flat" class="mr-2">
                <v-icon size="18">{{ b.icon }}</v-icon>
              </v-avatar>
              <div>
                <div class="text-subtitle-2 font-weight-bold">{{ b.label }}</div>
                <div class="text-caption">{{ b.range }}</div>
              </div>
            </div>
            <v-chip size="small" :color="b.color" variant="flat" class="font-weight-bold">{{ b.count }}</v-chip>
          </div>
          <div class="text-h6 font-weight-bold">{{ formatMoney(b.value) }}</div>
          <div class="text-caption">outstanding commitment</div>
          <v-progress-linear :model-value="b.pct" :color="b.color" height="5" rounded class="mt-2" />
        </v-card>
      </v-col>
    </v-row>

    <!-- Queue -->
    <v-card rounded="lg" class="mt-3" border>
      <div class="d-flex flex-wrap align-center ga-2 pa-3">
        <v-icon color="warning" class="mr-1">mdi-gavel</v-icon>
        <div class="text-subtitle-2 font-weight-bold mr-3">Approval queue</div>
        <v-text-field
          v-model="search" placeholder="Search PO or supplier…" variant="solo-filled" density="compact"
          hide-details flat rounded="lg" bg-color="surface" prepend-inner-icon="mdi-magnify" clearable
          style="max-width: 280px"
        />
        <v-select
          v-model="bandFilter" :items="bandOptions" item-title="label" item-value="value"
          variant="solo-filled" density="compact" hide-details flat rounded="lg" bg-color="surface"
          style="max-width: 200px"
        />
        <v-spacer />
        <v-chip size="small" variant="tonal" color="orange" v-if="selected.length">
          {{ selected.length }} selected · {{ formatMoney(selectedValue) }}
        </v-chip>
      </div>
      <v-divider />

      <EmptyState
        v-if="!loading && !filtered.length"
        icon="mdi-check-decagram-outline"
        title="Nothing awaiting approval"
        message="Every draft purchase order is within the delegated authority limits."
      />

      <v-data-table
        v-else
        v-model="selected"
        :headers="headers"
        :items="filtered"
        :loading="loading"
        item-value="id"
        show-select
        :items-per-page="25"
        density="comfortable"
        hover
      >
        <template #item.index="{ index }">
          <span class="text-caption text-medium-emphasis">{{ index + 1 }}</span>
        </template>
        <template #item.po_number="{ item }">
          <span class="font-weight-bold text-primary" style="cursor:pointer"
                @click="navigateTo(`/ims/purchase-orders/${item.id}`)">{{ item.po_number }}</span>
        </template>
        <template #item.supplier_name="{ item }">
          <div class="d-flex align-center ga-2">
            <v-avatar size="26" color="primary" variant="tonal">
              <span class="text-caption font-weight-bold">{{ initials(item.supplier_name) }}</span>
            </v-avatar>
            <span class="text-truncate" style="max-width: 180px">{{ item.supplier_name || '—' }}</span>
          </div>
        </template>
        <template #item.landedCost="{ item }">
          <span class="font-weight-bold">{{ formatMoney(item.landedCost) }}</span>
        </template>
        <template #item.items="{ item }">
          <v-chip size="x-small" variant="tonal" color="primary">{{ (item.items || []).length }} lines</v-chip>
        </template>
        <template #item.band="{ item }">
          <v-chip size="small" :color="item.band.color" variant="tonal">{{ item.band.label }}</v-chip>
        </template>
        <template #item.waitingDays="{ item }">
          <span :class="item.waitingDays > 7 ? 'text-error font-weight-medium' : 'text-medium-emphasis'">
            {{ item.waitingDays }}d
          </span>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end ga-1">
            <v-btn size="x-small" variant="tonal" color="warning" prepend-icon="mdi-pencil"
                   :to="`/ims/purchase-orders/${item.id}/edit`" class="text-none">Review</v-btn>
            <v-btn size="x-small" variant="tonal" color="error" :loading="busy === item.id"
                   @click="openReject(item)" class="text-none">Reject</v-btn>
            <v-btn size="x-small" variant="flat" color="success" :loading="busy === item.id"
                   @click="openApprove(item)" class="text-none">Approve</v-btn>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- Approval policy dialog -->
    <v-dialog v-model="policyDialog" max-width="560">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Approval policy</v-card-title>
        <v-card-subtitle>Set the value at which a purchase order needs formal release.</v-card-subtitle>
        <v-card-text>
          <v-text-field
            v-model.number="thresholdDraft"
            type="number"
            label="Approval threshold"
            prefix="KES"
            variant="outlined"
            density="compact"
            hide-details
            class="mb-3"
          />
          <div class="text-caption text-medium-emphasis mb-3">
            Bands are derived automatically: below 2× the threshold is the procurement manager, 2–4× the finance director,
            and 4× or more escalates to the executive.
          </div>
          <v-table density="compact">
            <thead><tr><th>Band</th><th class="text-right">Value range</th></tr></thead>
            <tbody>
              <tr><td>Procurement Manager</td><td class="text-right">up to {{ formatMoney(thresholdDraft * 2) }}</td></tr>
              <tr><td>Finance Director</td><td class="text-right">{{ formatMoney(thresholdDraft * 2) }} – {{ formatMoney(thresholdDraft * 4) }}</td></tr>
              <tr><td>Executive</td><td class="text-right">{{ formatMoney(thresholdDraft * 4) }}+</td></tr>
            </tbody>
          </v-table>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="policyDialog = false">Cancel</v-btn>
          <v-btn color="warning" variant="flat" class="text-none" @click="savePolicy">Save policy</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Approve dialog -->
    <v-dialog v-model="approveDialog" max-width="480" persistent>
      <v-card rounded="lg" class="pa-2">
        <v-card-title class="text-h6 d-flex align-center ga-2">
          <v-icon color="success">mdi-check-circle-outline</v-icon>
          Approve Purchase Order
        </v-card-title>
        <v-card-subtitle class="pb-2">
          <span v-if="activeItem">PO <strong>{{ activeItem.po_number }}</strong> · {{ activeItem.supplier_name || '—' }} · {{ formatMoney(activeItem.landedCost) }}</span>
        </v-card-subtitle>
        <v-card-text>
          <v-alert type="info" variant="tonal" density="compact" class="mb-3">
            Enter your password to confirm approval. This will release the order to the supplier.
          </v-alert>
          <div class="text-caption text-medium-emphasis mb-1 d-flex align-center ga-1">
            <v-icon size="14" color="success">mdi-lock-outline</v-icon>
            Enter your password to approve and confirm this purchase order.
          </div>
          <v-text-field
            v-model="approvePassword"
            label="Your password"
            type="password"
            variant="outlined"
            density="compact"
            prepend-inner-icon="mdi-lock-outline"
            :error-messages="approveError"
            hide-details="auto"
            @keyup.enter="confirmApprove"
          />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="closeApproveDialog">Cancel</v-btn>
          <v-btn color="success" variant="flat" class="text-none"
                 :loading="busy !== null"
                 prepend-icon="mdi-check"
                 @click="confirmApprove">Approve</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Reject dialog -->
    <v-dialog v-model="rejectDialog" max-width="520" persistent>
      <v-card rounded="lg" class="pa-2">
        <v-card-title class="text-h6 d-flex align-center ga-2">
          <v-icon color="error">mdi-close-circle-outline</v-icon>
          Reject Purchase Order
        </v-card-title>
        <v-card-subtitle class="pb-2">
          <span v-if="activeItem">PO <strong>{{ activeItem.po_number }}</strong> · {{ activeItem.supplier_name || '—' }} · {{ formatMoney(activeItem.landedCost) }}</span>
        </v-card-subtitle>
        <v-card-text>
          <v-alert type="warning" variant="tonal" density="compact" class="mb-3">
            This action cancels the purchase order. A reason is required for the audit trail.
          </v-alert>
          <v-textarea
            v-model="rejectReason"
            label="Reason for rejection"
            variant="outlined"
            density="compact"
            rows="3"
            auto-grow
            :error-messages="rejectError"
            hide-details="auto"
            placeholder="Explain why this order is being rejected…"
          />
          <div class="d-flex flex-wrap ga-1 mt-2">
            <v-chip
              v-for="r in commonReasons"
              :key="r"
              size="small"
              variant="tonal"
              color="error"
              link
              @click="rejectReason = r"
            >{{ r }}</v-chip>
          </div>
          <div class="text-caption text-medium-emphasis mt-3 mb-1 d-flex align-center ga-1">
            <v-icon size="14" color="error">mdi-lock-outline</v-icon>
            Enter your password to approve and confirm this rejection.
          </div>
          <v-text-field
            v-model="rejectPassword"
            label="Your password"
            type="password"
            variant="outlined"
            density="compact"
            prepend-inner-icon="mdi-lock-outline"
            hide-details="auto"
            @keyup.enter="confirmReject"
          />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="closeRejectDialog">Cancel</v-btn>
          <v-btn color="error" variant="flat" class="text-none"
                 :loading="busy !== null"
                 prepend-icon="mdi-close"
                 @click="confirmReject">Reject</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
import { useProcurement } from '~/composables/useProcurement'
import { num, sum } from '~/utils/bi'

const { $api } = useNuxtApp()
const {
  loading, approvalQueue, approvalThreshold, setApprovalThreshold, approvalBand,
  draftOrders, branchFilter, branchFilterItems, isBranchLocked, load
} = useProcurement()

const search = ref('')
const bandFilter = ref('all')
const selected = ref([])
const busy = ref(null)
const policyDialog = ref(false)
const thresholdDraft = ref(0)

watch(approvalThreshold, (v) => { thresholdDraft.value = v || 50000 }, { immediate: true })
watch(policyDialog, (open) => { if (open) thresholdDraft.value = approvalThreshold.value || 50000 })

const bandOptions = [
  { label: 'All bands', value: 'all' },
  { label: 'Procurement Manager', value: 'Procurement Manager' },
  { label: 'Finance Director', value: 'Finance Director' },
  { label: 'Executive', value: 'Executive' }
]

const filtered = computed(() =>
  approvalQueue.value.filter((o) => {
    if (bandFilter.value !== 'all' && o.band.label !== bandFilter.value) return false
    if (search.value) {
      const q = search.value.toLowerCase()
      const hay = `${o.po_number} ${o.supplier_name || ''}`.toLowerCase()
      if (!hay.includes(q)) return false
    }
    return true
  })
)

const headers = [
  { title: '#', key: 'index', sortable: false, align: 'center', width: '50px' },
  { title: 'PO', key: 'po_number' },
  { title: 'Supplier', key: 'supplier_name' },
  { title: 'Lines', key: 'items', align: 'center', sortable: false },
  { title: 'Value', key: 'landedCost', align: 'end' },
  { title: 'Band', key: 'band', align: 'center', sortable: false },
  { title: 'Waiting', key: 'waitingDays', align: 'end' },
  { title: '', key: 'actions', align: 'end', sortable: false }
]

const selectedRows = computed(() => approvalQueue.value.filter((o) => selected.value.includes(o.id)))
const selectedValue = computed(() => sum(selectedRows.value, (o) => o.landedCost))
const queueValue = computed(() => sum(approvalQueue.value, (o) => o.landedCost))

const kpis = computed(() => {
  const escalation = approvalQueue.value.filter((o) => o.band.level >= 2)
  const stale = approvalQueue.value.filter((o) => o.waitingDays > 7)
  const draftsOutside = draftOrders.value.filter((o) => !o.requiresApproval)
  return [
    { title: 'Awaiting approval', value: String(approvalQueue.value.length), valueNum: approvalQueue.value.length, icon: 'mdi-gavel', color: 'warning', invertDelta: true, hint: 'Draft commitments' },
    { title: 'Pending value', value: formatMoney(queueValue.value), valueNum: queueValue.value, icon: 'mdi-cash-clock', color: 'primary', hint: 'Unreleased spend' },
    { title: 'Escalated', value: String(escalation.length), valueNum: escalation.length, icon: 'mdi-account-arrow-up-outline', color: 'error', invertDelta: true, hint: 'Finance director or above' },
    { title: 'Aged over 7 days', value: String(stale.length), valueNum: stale.length, icon: 'mdi-timer-alert-outline', color: 'deep-orange', invertDelta: true, hint: 'Slipping commitments' },
    { title: 'Below threshold', value: String(draftsOutside.length), icon: 'mdi-shield-check-outline', color: 'success', hint: 'Delegated authority' },
    { title: 'Average waiting', value: `${approvalQueue.value.length ? (sum(approvalQueue.value, (o) => o.waitingDays) / approvalQueue.value.length).toFixed(1) : '0'}d`, icon: 'mdi-clock-outline', color: 'info', hint: 'Submission to decision' }
  ]
})

const bands = computed(() => {
  const t = approvalThreshold.value || 0
  const defs = t
    ? [
        { label: 'Procurement Manager', range: `under ${formatMoney(t * 2)}`, color: 'info', icon: 'mdi-account-outline', test: (o) => o.band.level === 1 },
        { label: 'Finance Director', range: `${formatMoney(t * 2)} – ${formatMoney(t * 4)}`, color: 'warning', icon: 'mdi-account-tie-outline', test: (o) => o.band.level === 2 },
        { label: 'Executive', range: `${formatMoney(t * 4)} and above`, color: 'error', icon: 'mdi-crown-outline', test: (o) => o.band.level >= 3 }
      ]
    : [
        { label: 'Unclassified', range: 'set a threshold to route', color: 'grey', icon: 'mdi-shield-alert-outline', test: () => true }
      ]
  const maxValue = Math.max(1, ...defs.map((d) => sum(approvalQueue.value.filter(d.test), (o) => o.landedCost)))
  return defs.map((d) => {
    const rows = approvalQueue.value.filter(d.test)
    const value = sum(rows, (o) => o.landedCost)
    return { ...d, count: rows.length, value, pct: (value / maxValue) * 100 }
  })
})

function initials(name) {
  return String(name || '?').split(/\s+/).map((p) => p[0]).slice(0, 2).join('').toUpperCase()
}

// ── Approve / Reject dialog state ────────────────────────────────────────────
const approveDialog = ref(false)
const rejectDialog = ref(false)
const activeItem = ref(null)
const approvePassword = ref('')
const approveError = ref('')
const rejectReason = ref('')
const rejectPassword = ref('')
const rejectError = ref('')
const actionError = ref('')

const commonReasons = [
  'Prices not competitive',
  'Duplicate order',
  'Budget exceeded',
  'Supplier blacklisted',
  'Items no longer required',
  'Incorrect quantities',
  'Pending quotation from alternative supplier',
]

function openApprove(item) {
  activeItem.value = item
  approvePassword.value = ''
  approveError.value = ''
  approveDialog.value = true
}

function closeApproveDialog() {
  approveDialog.value = false
  activeItem.value = null
  approvePassword.value = ''
  approveError.value = ''
}

async function confirmApprove() {
  if (!activeItem.value) return
  if (!approvePassword.value) { approveError.value = 'Password is required.'; return }
  busy.value = activeItem.value.id
  approveError.value = ''
  try {
    await $api.post(`/purchase-orders/orders/${activeItem.value.id}/approve/`, {
      password: approvePassword.value,
    })
    activeItem.value.status = 'sent'
    selected.value = selected.value.filter((id) => id !== activeItem.value.id)
    closeApproveDialog()
    await load()
  } catch (err) {
    approveError.value = err?.response?.data?.detail || 'Failed to approve order.'
  } finally {
    busy.value = null
  }
}

function openReject(item) {
  activeItem.value = item
  rejectReason.value = ''
  rejectPassword.value = ''
  rejectError.value = ''
  rejectDialog.value = true
}

function closeRejectDialog() {
  rejectDialog.value = false
  activeItem.value = null
  rejectReason.value = ''
  rejectPassword.value = ''
  rejectError.value = ''
}

async function confirmReject() {
  if (!activeItem.value) return
  if (!rejectReason.value.trim()) { rejectError.value = 'A rejection reason is required.'; return }
  if (!rejectPassword.value) { rejectError.value = 'Password is required.'; return }
  busy.value = activeItem.value.id
  rejectError.value = ''
  try {
    await $api.post(`/purchase-orders/orders/${activeItem.value.id}/reject/`, {
      password: rejectPassword.value,
      reason: rejectReason.value.trim(),
    })
    activeItem.value.status = 'cancelled'
    selected.value = selected.value.filter((id) => id !== activeItem.value.id)
    closeRejectDialog()
    await load()
  } catch (err) {
    rejectError.value = err?.response?.data?.detail || 'Failed to reject order.'
  } finally {
    busy.value = null
  }
}

async function bulkApprove() {
  actionError.value = ''
  for (const o of selectedRows.value) {
    // eslint-disable-next-line no-await-in-loop
    await $api.post(`/purchase-orders/orders/${o.id}/approve/`, {
      password: approvePassword.value || undefined,
    }).catch((e) => { actionError.value = e?.response?.data?.detail || 'Some orders failed to approve.' })
  }
  selected.value = []
  await load()
}

function savePolicy() {
  setApprovalThreshold(thresholdDraft.value)
  policyDialog.value = false
}

void approvalBand
</script>
