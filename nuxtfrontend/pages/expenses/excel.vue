<template>
  <div class="excel-page">
    <v-container fluid class="pa-4 pa-md-6">
      <!-- Header -->
      <div class="d-flex align-center flex-wrap ga-3 mb-5">
        <v-btn icon="mdi-arrow-left" variant="text" to="/expenses" size="small" class="mr-1" />
        <v-avatar color="green-lighten-5" rounded="lg" size="52">
          <v-icon color="green-darken-2" size="30">mdi-microsoft-excel</v-icon>
        </v-avatar>
        <div>
          <div class="text-h5 font-weight-bold">Excel Import / Export</div>
          <div class="text-body-2 text-medium-emphasis">
            Move expenses in and out of AdhereMed with spreadsheets · review before saving
          </div>
        </div>
        <v-spacer />
      </div>

      <!-- Export card -->
      <v-card flat rounded="xl" border class="pa-4 mb-4">
        <div class="d-flex align-center flex-wrap ga-3">
          <v-avatar color="teal-lighten-5" size="44" class="mr-2">
            <v-icon color="teal-darken-2">mdi-file-export</v-icon>
          </v-avatar>
          <div class="mr-4">
            <div class="text-subtitle-1 font-weight-bold">Export</div>
            <div class="text-caption text-medium-emphasis">
              Download all expenses ({{ expenseCount.toLocaleString() }} records) as a spreadsheet
            </div>
          </div>
          <v-spacer />
          <v-btn variant="tonal" color="primary" rounded="lg" class="text-none"
                 prepend-icon="mdi-file-download-outline" :loading="busy === 'template'"
                 @click="download('template')">Import template</v-btn>
          <v-btn color="success" rounded="lg" class="text-none"
                 prepend-icon="mdi-microsoft-excel" :loading="busy === 'excel'"
                 @click="download('excel')">Export to Excel</v-btn>
          <v-btn variant="tonal" color="primary" rounded="lg" class="text-none"
                 prepend-icon="mdi-file-delimited" :loading="busy === 'csv'"
                 @click="download('csv')">Export CSV</v-btn>
        </div>
      </v-card>

      <!-- Import card -->
      <v-card flat rounded="xl" border class="pa-4">
        <div class="d-flex align-center flex-wrap ga-3 mb-3">
          <v-avatar color="green-lighten-5" size="44" class="mr-2">
            <v-icon color="green-darken-2">mdi-file-upload</v-icon>
          </v-avatar>
          <div>
            <div class="text-subtitle-1 font-weight-bold">Import</div>
            <div class="text-caption text-medium-emphasis">
              Upload .xlsx or .csv · every row is reviewed and editable before anything is saved
            </div>
          </div>
        </div>

        <!-- Drop zone -->
        <div
          v-if="!rows.length"
          class="dropzone"
          :class="{ 'dropzone-active': dragging }"
          @dragover.prevent="dragging = true"
          @dragleave.prevent="dragging = false"
          @drop.prevent="onDrop"
          @click="openPicker"
        >
          <input ref="fileInput" type="file" accept=".xlsx,.csv" class="d-none" @change="onFileInput" />
          <svg class="dropzone-ants" aria-hidden="true">
            <rect x="1.25" y="1.25" width="calc(100% - 2.5px)" height="calc(100% - 2.5px)" rx="16" />
          </svg>
          <v-avatar size="72" color="primary" variant="tonal" class="mb-3">
            <v-icon size="36">{{ dragging ? 'mdi-file-upload-outline' : 'mdi-cloud-upload-outline' }}</v-icon>
          </v-avatar>
          <div class="text-h6 mb-1">{{ dragging ? 'Drop your file here' : 'Drag & drop your spreadsheet' }}</div>
          <div class="text-body-2 text-medium-emphasis mb-3">
            or <span class="text-primary font-weight-medium">browse files</span> · .xlsx / .csv
          </div>
          <v-btn variant="tonal" color="primary" rounded="lg" class="text-none"
                 prepend-icon="mdi-file-download-outline" :loading="busy === 'template'"
                 @click.stop="download('template')">
            Download the template first
          </v-btn>
        </div>

        <v-progress-linear v-if="uploading" color="primary" indeterminate height="3" class="mb-3" />

        <!-- Parse error -->
        <v-alert v-if="parseError" type="error" variant="tonal" rounded="lg" density="compact" class="mb-3">
          <template #prepend><v-icon>mdi-alert-circle</v-icon></template>
          {{ parseError }}
        </v-alert>

        <!-- Review table -->
        <template v-if="rows.length">
          <!-- Summary chips -->
          <div class="d-flex align-center flex-wrap ga-2 mb-3">
            <v-chip size="small" variant="tonal" color="primary" prepend-icon="mdi-table">
              {{ rows.length }} rows
            </v-chip>
            <v-chip size="small" variant="tonal" color="success" prepend-icon="mdi-plus-circle-outline">
              {{ countByStatus('new') }} new
            </v-chip>
            <v-chip size="small" variant="tonal" color="info" prepend-icon="mdi-pencil-circle-outline">
              {{ countByStatus('update') }} updates
            </v-chip>
            <v-chip v-if="countByStatus('error')" size="small" variant="tonal" color="error"
                    prepend-icon="mdi-alert-circle-outline">
              {{ countByStatus('error') }} with errors
            </v-chip>
            <v-spacer />
            <v-text-field v-model="search" placeholder="Search rows…" prepend-inner-icon="mdi-magnify"
                          density="compact" variant="outlined" rounded="lg" hide-details single-line
                          clearable style="max-width: 260px" />
            <v-btn variant="text" color="primary" size="small" rounded="lg" class="text-none"
                   prepend-icon="mdi-plus" @click="addBlankRow">Add row</v-btn>
            <v-btn variant="text" color="error" size="small" rounded="lg" class="text-none"
                   prepend-icon="mdi-close-circle-outline" @click="reset">Start over</v-btn>
          </div>

          <div class="helper-strip">
            <v-icon size="14" color="primary" class="mr-1">mdi-information-outline</v-icon>
            Click any cell to edit · rows with a matching <strong>Reference</strong> update the
            existing expense · blank reference creates a new expense · fix red rows before submitting
          </div>

          <div class="sheet-wrap">
            <table class="sheet">
              <thead>
                <tr>
                  <th class="col-row">Row</th>
                  <th class="col-status">Status</th>
                  <th class="col-ref">Reference</th>
                  <th class="col-title">Title</th>
                  <th class="col-cat">Category</th>
                  <th class="col-vendor">Vendor</th>
                  <th class="col-num">Amount (KSh)</th>
                  <th class="col-num">Tax (KSh)</th>
                  <th class="col-date">Expense Date</th>
                  <th class="col-date">Due Date</th>
                  <th class="col-enum">Payment</th>
                  <th class="col-ref2">Pay Ref</th>
                  <th class="col-enum">Status</th>
                  <th class="col-enum">Recurring</th>
                  <th class="col-enum">Period</th>
                  <th class="col-notes">Notes</th>
                  <th class="col-rem"></th>
                </tr>
              </thead>
              <tbody>
                <template v-for="(row, i) in filteredRows" :key="row.uid">
                  <tr :class="{
                    'row-error': row.row_status === 'error',
                    'row-new': row.row_status === 'new',
                    'row-update': row.row_status === 'update',
                  }">
                    <td class="text-caption text-medium-emphasis">{{ i + 1 }}</td>
                    <td>
                      <v-chip :color="statusColor(row.row_status)" variant="tonal" size="x-small">
                        <v-icon start size="12">{{ statusIcon(row.row_status) }}</v-icon>
                        {{ statusLabel(row.row_status) }}
                      </v-chip>
                    </td>
                    <td><input v-model="row.reference" class="cell-input cell-mono" type="text" /></td>
                    <td>
                      <input v-model="row.title" class="cell-input cell-name" type="text"
                             placeholder="Required" @input="touchRow(row)" />
                    </td>
                    <td>
                      <v-combobox v-model="row.category" :items="categoryNames" clearable
                                  placeholder="Category" density="compact" variant="outlined"
                                  hide-details single-line class="cell-combo"
                                  :menu-props="{ maxHeight: 220 }" />
                    </td>
                    <td><input v-model="row.vendor" class="cell-input" type="text" /></td>
                    <td>
                      <input v-model.number="row.amount" class="cell-input num cell-amount" type="number"
                             min="0" step="0.01" placeholder="Required" @input="touchRow(row)" />
                    </td>
                    <td><input v-model.number="row.tax_amount" class="cell-input num" type="number" min="0" step="0.01" /></td>
                    <td>
                      <input v-model="row.expense_date" class="cell-input cell-mono" type="date"
                             @change="touchRow(row)" />
                    </td>
                    <td><input v-model="row.due_date" class="cell-input cell-mono" type="date" /></td>
                    <td>
                      <select v-model="row.payment_method" class="cell-input">
                        <option value="">—</option>
                        <option value="cash">Cash</option>
                        <option value="mpesa">M-Pesa</option>
                        <option value="bank">Bank Transfer</option>
                        <option value="card">Card</option>
                        <option value="cheque">Cheque</option>
                        <option value="other">Other</option>
                      </select>
                    </td>
                    <td><input v-model="row.payment_reference" class="cell-input cell-mono" type="text" /></td>
                    <td>
                      <select v-model="row.status" class="cell-input">
                        <option value="">—</option>
                        <option value="pending">Pending</option>
                        <option value="approved">Approved</option>
                        <option value="paid">Paid</option>
                        <option value="rejected">Rejected</option>
                        <option value="cancelled">Cancelled</option>
                      </select>
                    </td>
                    <td>
                      <select v-model="row.is_recurring" class="cell-input">
                        <option value="">—</option>
                        <option value="Yes">Yes</option>
                        <option value="No">No</option>
                      </select>
                    </td>
                    <td>
                      <select v-model="row.recurring_period" class="cell-input">
                        <option value="">—</option>
                        <option value="daily">Daily</option>
                        <option value="weekly">Weekly</option>
                        <option value="monthly">Monthly</option>
                        <option value="quarterly">Quarterly</option>
                        <option value="yearly">Yearly</option>
                      </select>
                    </td>
                    <td><input v-model="row.notes" class="cell-input" type="text" /></td>
                    <td class="text-center">
                      <v-btn icon="mdi-close" size="x-small" variant="text" color="error"
                             @click="removeRow(row)" />
                    </td>
                  </tr>
                  <tr v-if="row.errors && Object.keys(row.errors).length" class="error-row">
                    <td :colspan="17">
                      <v-icon size="13" color="error" class="mr-1">mdi-alert-circle</v-icon>
                      <span v-for="(msg, field) in row.errors" :key="field" class="error-msg">
                        <strong>{{ fieldLabel(field) }}</strong>: {{ msg }} ·
                      </span>
                    </td>
                  </tr>
                </template>
              </tbody>
            </table>
          </div>

          <!-- Submit bar -->
          <div class="submit-bar">
            <span class="text-caption text-medium-emphasis">
              {{ countByStatus('new') }} new · {{ countByStatus('update') }} updates ·
              {{ countByStatus('error') }} to fix
            </span>
            <v-spacer />
            <v-btn variant="text" rounded="lg" class="text-none" @click="reset">Cancel</v-btn>
            <v-btn color="success" rounded="lg" class="text-none" size="large"
                   prepend-icon="mdi-check-circle" :loading="submitting" :disabled="!submittable"
                   @click="submitImport">
              Submit import ({{ submittableCount }} rows)
            </v-btn>
          </div>
        </template>
      </v-card>

      <!-- Result dialog -->
      <v-dialog v-model="resultDialog" max-width="560" persistent>
        <v-card rounded="xl">
          <div class="result-banner" :class="result.failed ? 'result-warn' : 'result-ok'">
            <v-avatar size="64" :color="result.failed ? 'warning' : 'success'" variant="tonal">
              <v-icon size="32">{{ result.failed ? 'mdi-alert-circle-check' : 'mdi-check-circle' }}</v-icon>
            </v-avatar>
          </div>
          <v-card-title class="text-center pt-2">Import complete</v-card-title>
          <v-card-text class="text-center">
            <div class="d-flex justify-center ga-4 mb-3">
              <div>
                <div class="text-h5 font-weight-bold text-success">{{ result.created }}</div>
                <div class="text-caption text-medium-emphasis">created</div>
              </div>
              <div>
                <div class="text-h5 font-weight-bold text-info">{{ result.updated }}</div>
                <div class="text-caption text-medium-emphasis">updated</div>
              </div>
              <div v-if="result.failed">
                <div class="text-h5 font-weight-bold text-error">{{ result.failed }}</div>
                <div class="text-caption text-medium-emphasis">failed</div>
              </div>
            </div>
            <div v-if="failedRows.length" class="text-left">
              <div class="text-caption font-weight-bold mb-1">Failed rows:</div>
              <div v-for="f in failedRows" :key="f.row" class="text-caption text-error">
                Row {{ f.row }} · {{ f.name }} — {{ f.error }}
              </div>
            </div>
          </v-card-text>
          <v-card-actions class="pa-4">
            <v-btn variant="text" rounded="lg" class="text-none" block @click="resultDialog = false">Close</v-btn>
            <v-btn color="primary" rounded="lg" class="text-none" block to="/expenses">
              Back to expenses
            </v-btn>
          </v-card-actions>
        </v-card>
      </v-dialog>

      <v-snackbar v-model="snack.show" :color="snack.color" timeout="3500" location="bottom right" rounded="pill">
        <v-icon class="mr-2">{{ snack.icon }}</v-icon>
        {{ snack.text }}
      </v-snackbar>
    </v-container>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'

const { $api } = useNuxtApp()

const expenseCount = ref(0)
const categories = ref([])
const busy = ref('')
const uploading = ref(false)
const submitting = ref(false)
const dragging = ref(false)
const parseError = ref('')
const rows = ref([])
const search = ref('')
const resultDialog = ref(false)
const result = ref({ created: 0, updated: 0, failed: 0, results: [] })
const snack = ref({ show: false, text: '', color: 'success', icon: 'mdi-check-circle' })
let uidSeq = 1

onMounted(async () => {
  try {
    const [exRes, catRes] = await Promise.all([
      $api.get('/expenses/expenses/', { params: { page_size: 1 } }),
      $api.get('/expenses/categories/', { params: { page_size: 1000 } }),
    ])
    expenseCount.value = exRes.data?.count ?? (exRes.data?.length ?? 0)
    categories.value = catRes.data?.results ?? catRes.data
  } catch { /* count is cosmetic */ }
})

const categoryNames = computed(() => categories.value.map(c => c.name))

// ── Download helpers ───────────────────────────────────────────────
async function download(kind) {
  busy.value = kind
  try {
    let url, name, blob
    if (kind === 'template') {
      url = '/expenses/expenses/import-template/'
      name = `expenses_import_template_${new Date().toISOString().slice(0, 10)}.xlsx`
    } else if (kind === 'excel') {
      url = '/expenses/expenses/export/?fmt=excel'
      name = `expenses_${new Date().toISOString().slice(0, 10)}.xlsx`
    } else {
      url = '/expenses/expenses/export/?fmt=csv'
      name = `expenses_${new Date().toISOString().slice(0, 10)}.csv`
    }
    blob = (await $api.get(url, { responseType: 'blob' })).data
    const objectUrl = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = objectUrl
    a.download = name
    a.click()
    URL.revokeObjectURL(objectUrl)
    snack.value = { show: true, color: 'success', icon: 'mdi-check-circle', text: 'Download started.' }
  } catch {
    snack.value = { show: true, color: 'error', icon: 'mdi-alert', text: 'Download failed.' }
  } finally {
    busy.value = ''
  }
}

// ── Upload & preview ──────────────────────────────────────────────
const fileInput = ref(null)

function openPicker() {
  fileInput.value?.click()
}

function onDrop(e) {
  dragging.value = false
  const file = e.dataTransfer?.files?.[0]
  if (file) upload(file)
}

function onFileInput(e) {
  const file = e.target?.files?.[0]
  if (file) upload(file)
  e.target.value = ''
}

async function upload(file) {
  if (!/\.(xlsx|csv)$/i.test(file.name)) {
    parseError.value = 'Unsupported file type. Use .xlsx or .csv'
    return
  }
  uploading.value = true
  parseError.value = ''
  try {
    const fd = new FormData()
    fd.append('file', file)
    const { data } = await $api.post('/expenses/expenses/import-preview/', fd)
    rows.value = data.rows.map(r => ({ ...r, uid: uidSeq++ }))
    if (!rows.value.length) parseError.value = 'No data rows found in the file.'
  } catch (err) {
    const status = err?.response?.status
    const detail = err?.response?.data?.detail
    if (detail) {
      parseError.value = typeof detail === 'string' ? detail : JSON.stringify(detail)
      if (status) parseError.value += ` (HTTP ${status})`
    } else if (status) {
      parseError.value = `Upload failed (HTTP ${status}). Check the console for details.`
    } else {
      parseError.value = err?.message || 'Could not read the file.'
    }
  } finally {
    uploading.value = false
  }
}

// ── Row helpers ───────────────────────────────────────────────────
const FIELD_LABELS = {
  reference: 'Reference', title: 'Title', category: 'Category', vendor: 'Vendor',
  amount: 'Amount', tax_amount: 'Tax', expense_date: 'Expense Date', due_date: 'Due Date',
  payment_method: 'Payment Method', payment_reference: 'Payment Reference',
  status: 'Status', is_recurring: 'Recurring', recurring_period: 'Recurring Period',
  notes: 'Notes',
}
function fieldLabel(f) { return FIELD_LABELS[f] || f }
function statusColor(s) { return { new: 'success', update: 'info', error: 'error' }[s] || 'grey' }
function statusIcon(s) { return { new: 'mdi-plus', update: 'mdi-pencil', error: 'mdi-alert' }[s] || 'mdi-help' }
function statusLabel(s) { return { new: 'New', update: 'Update', error: 'Error' }[s] || s }

const filteredRows = computed(() => {
  const q = (search.value || '').toLowerCase().trim()
  if (!q) return rows.value
  return rows.value.filter(r =>
    (r.title || '').toLowerCase().includes(q) ||
    (r.reference || '').toLowerCase().includes(q) ||
    (r.vendor || '').toLowerCase().includes(q))
})

function countByStatus(s) { return rows.value.filter(r => r.row_status === s).length }

// Re-validate a row client-side as it is edited
function touchRow(row) {
  const errors = {}
  if (!(row.title || '').trim()) errors.title = 'Required'
  for (const f of ['amount', 'tax_amount']) {
    const v = row[f]
    if (v === null || v === undefined || v === '') continue
    if (Number.isNaN(Number(v))) errors[f] = 'Must be a number'
    else if (Number(v) < 0) errors[f] = 'Must be ≥ 0'
  }
  if (!row.existing_id && !(row.expense_date || '')) errors.expense_date = 'Required'
  row.errors = errors
  row.row_status = Object.keys(errors).length ? 'error' : (row.existing_id ? 'update' : 'new')
}

function addBlankRow() {
  rows.value.push({
    uid: uidSeq++,
    row_num: rows.value.length + 2,
    reference: '', title: '', category: '', vendor: '',
    amount: null, tax_amount: null, expense_date: '', due_date: '',
    payment_method: 'cash', payment_reference: '', status: 'pending',
    is_recurring: 'No', recurring_period: '', notes: '',
    existing_id: null,
    row_status: 'error',
    errors: { title: 'Required', amount: 'Required', expense_date: 'Required' },
  })
}

function removeRow(row) {
  rows.value = rows.value.filter(r => r.uid !== row.uid)
}

function reset() {
  rows.value = []
  search.value = ''
  parseError.value = ''
}

const submittableCount = computed(() => rows.value.length)
const submittable = computed(() =>
  rows.value.length > 0 && !rows.value.some(r => r.row_status === 'error'))

// ── Submit ────────────────────────────────────────────────────────
async function submitImport() {
  submitting.value = true
  try {
    const items = rows.value.map(r => {
      const out = { row_num: r.row_num, title: r.title }
      for (const f of ['reference', 'category', 'vendor', 'payment_reference',
                       'notes', 'expense_date', 'due_date',
                       'payment_method', 'status', 'is_recurring', 'recurring_period']) {
        if (r[f] !== null && r[f] !== undefined && r[f] !== '') out[f] = r[f]
      }
      for (const f of ['amount', 'tax_amount']) {
        if (r[f] !== null && r[f] !== undefined && r[f] !== '') out[f] = Number(r[f])
      }
      return out
    })
    const { data } = await $api.post('/expenses/expenses/import-commit/', { items })
    result.value = data
    resultDialog.value = true
    if (!data.failed) reset()
  } catch (err) {
    snack.value = {
      show: true, color: 'error', icon: 'mdi-alert',
      text: err?.response?.data?.detail || 'Import failed.',
    }
  } finally {
    submitting.value = false
  }
}

const failedRows = computed(() =>
  (result.value.results || []).filter(r => r.status === 'error'))
</script>

<style scoped>
.excel-page {
  min-height: 100vh;
  background: rgb(var(--v-theme-background));
}

/* ── Drop zone ──────────────────────────────────────────────────────── */
.dropzone {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  padding: 48px 16px;
  border: 2px dashed rgba(var(--v-theme-primary), 0.18);
  border-radius: 16px;
  background: rgba(var(--v-theme-primary), 0.02);
  cursor: pointer;
  transition: all 0.15s ease;
}
.dropzone-active {
  border-color: transparent;
  background: rgba(var(--v-theme-primary), 0.06);
}
.dropzone-ants {
  position: absolute;
  inset: -2px;
  width: calc(100% + 4px);
  height: calc(100% + 4px);
  pointer-events: none;
}
.dropzone-ants rect {
  fill: none;
  stroke: rgb(var(--v-theme-primary));
  stroke-width: 2.5;
  stroke-linecap: round;
  stroke-dasharray: 0.5 14;
  opacity: 0.55;
  animation: dz-march 1.2s linear infinite;
}
.dropzone:hover .dropzone-ants rect,
.dropzone-active .dropzone-ants rect {
  opacity: 1;
  animation-duration: 0.45s;
}
@keyframes dz-march {
  to { stroke-dashoffset: -29; }
}
@media (prefers-reduced-motion: reduce) {
  .dropzone-ants rect { animation: none; }
}

/* ── Review sheet ───────────────────────────────────────────────────── */
.helper-strip {
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 8px 16px;
  font-size: 12px;
  color: rgba(var(--v-theme-on-surface), 0.6);
  background: rgba(var(--v-theme-primary), 0.03);
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.04);
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.04);
  flex-wrap: wrap;
}

.sheet-wrap {
  overflow: auto;
  max-height: 62vh;
  min-height: 240px;
}

.sheet {
  width: 100%;
  border-collapse: separate;
  border-spacing: 0;
  font-size: 13px;
}
.sheet thead th {
  position: sticky;
  top: 0;
  background: rgb(var(--v-theme-surface));
  border-bottom: 2px solid rgba(var(--v-theme-on-surface), 0.08);
  padding: 10px 10px;
  font-weight: 600;
  font-size: 11.5px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: rgba(var(--v-theme-on-surface), 0.6);
  text-align: left;
  white-space: nowrap;
  z-index: 2;
}
.sheet tbody td {
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.05);
  padding: 5px 6px;
  white-space: nowrap;
  vertical-align: middle;
  background: rgb(var(--v-theme-surface));
}
.sheet tbody tr:hover td { background: rgba(var(--v-theme-primary), 0.035); }

.row-new td { background: rgba(var(--v-theme-success), 0.05) !important; }
.row-update td { background: rgba(var(--v-theme-info), 0.05) !important; }
.row-error td { background: rgba(var(--v-theme-error), 0.07) !important; }

.error-row td {
  background: rgba(var(--v-theme-error), 0.06) !important;
  color: rgb(var(--v-theme-error));
  font-size: 11.5px;
  white-space: normal;
  padding: 4px 12px !important;
}
.error-msg strong { text-transform: capitalize; }

.col-row { width: 44px; color: rgba(var(--v-theme-on-surface), 0.4); }
.col-status { width: 86px; }
.col-ref, .col-ref2 { min-width: 110px; }
.col-title { min-width: 200px; }
.col-cat, .col-vendor { min-width: 140px; }
.col-num { width: 110px; min-width: 110px; }
.col-date { min-width: 130px; }
.col-enum { min-width: 110px; }
.col-notes { min-width: 160px; }
.col-rem { width: 44px; }

.cell-input {
  width: 100%;
  border: 1px solid transparent;
  background: transparent;
  padding: 5px 7px;
  border-radius: 8px;
  font-size: 13px;
  color: inherit;
  outline: none;
  transition: all 0.12s ease;
}
.cell-input:hover { border-color: rgba(var(--v-theme-on-surface), 0.12); }
.cell-input:focus {
  border-color: rgb(var(--v-theme-primary));
  background: rgb(var(--v-theme-surface));
  box-shadow: 0 0 0 3px rgba(var(--v-theme-primary), 0.18);
}
select.cell-input {
  background-color: rgb(var(--v-theme-surface));
  color: rgb(var(--v-theme-on-surface));
  color-scheme: light dark;
  appearance: auto;
}
select.cell-input option {
  background-color: rgb(var(--v-theme-surface));
  color: rgb(var(--v-theme-on-surface));
}
.cell-input.num { text-align: right; font-variant-numeric: tabular-nums; }
.cell-input.cell-name { font-weight: 500; }
.cell-input.cell-amount { font-weight: 600; }
.cell-mono { font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: 12px; }

.cell-combo { width: 100%; }
.cell-combo :deep(.v-field) {
  border-radius: 8px;
  font-size: 13px;
  border-color: transparent;
  background: transparent;
  transition: all 0.12s ease;
}
.cell-combo :deep(.v-field__input) {
  min-height: 26px;
  padding: 0 8px;
  font-size: 13px;
}
.cell-combo:hover :deep(.v-field) {
  border-color: rgba(var(--v-theme-on-surface), 0.12);
}
.cell-combo :deep(.v-field--focused) {
  background: rgb(var(--v-theme-surface));
}

/* ── Submit bar ─────────────────────────────────────────────────────── */
.submit-bar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 12px;
  padding: 12px 16px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}

.result-banner {
  display: flex;
  justify-content: center;
  padding-top: 24px;
}
.result-warn { color: rgb(var(--v-theme-warning)); }
.result-ok { color: rgb(var(--v-theme-success)); }
</style>
