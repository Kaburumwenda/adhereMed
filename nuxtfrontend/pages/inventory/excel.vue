<template>
  <div class="excel-page">
    <v-container fluid class="pa-3 pa-md-5 xl-page">

      <!-- ═══════════════ HERO ═══════════════ -->
      <div class="xl-hero mb-4" :style="heroTheme">
        <span class="xl-glow" />
        <span class="xl-glow xl-glow-2" />

        <div class="d-flex flex-wrap align-center justify-space-between ga-3 xl-hero-top">
          <div class="d-flex align-center" style="gap:14px; min-width:0">
            <v-btn
              icon="mdi-arrow-left"
              variant="text"
              size="small"
              class="xl-hero-iconbtn"
              title="Back to inventory"
              :to="p('/inventory')"
            />
            <div class="xl-hero-icon">
              <v-icon size="30">mdi-microsoft-excel</v-icon>
            </div>
            <div style="min-width:0">
              <div class="xl-eyebrow">
                <v-icon size="10">mdi-circle</v-icon>
                INVENTORY · DATA EXCHANGE
              </div>
              <h1 class="xl-title">Excel import / export</h1>
              <div class="xl-sub">
                Move stock in and out of the system with spreadsheets — every row is reviewed before it is saved
              </div>
            </div>
          </div>

          <div class="d-flex flex-wrap align-center ga-2">
            <v-btn
              variant="flat"
              elevation="0"
              rounded="lg"
              class="text-none xl-btn-glass"
              prepend-icon="mdi-file-download-outline"
              :loading="busy === 'template'"
              @click="download('template')"
            >Import template</v-btn>
            <v-btn
              variant="flat"
              elevation="0"
              rounded="lg"
              class="text-none xl-btn-strong"
              prepend-icon="mdi-file-upload-outline"
              @click="openPicker"
            >Upload a file</v-btn>
          </div>
        </div>

        <div class="xl-hero-foot d-flex flex-wrap align-center" style="gap:8px">
          <span class="xl-hero-chip">
            <v-icon size="14">mdi-database-outline</v-icon>
            {{ stockCount.toLocaleString() }} items in stock
          </span>
          <span class="xl-hero-chip">
            <v-icon size="14">mdi-shape-outline</v-icon>
            {{ categoryNames.length }} categories
          </span>
          <span class="xl-hero-chip">
            <v-icon size="14">mdi-warehouse</v-icon>
            {{ branchList.length }} warehouses
          </span>
          <span class="xl-hero-chip">
            <v-icon size="14">mdi-counter</v-icon>
            {{ unitNames.length }} units
          </span>
          <span v-if="rows.length" class="xl-hero-chip xl-hero-chip-warn">
            <v-icon size="14">mdi-table-alert</v-icon>
            {{ rows.length }} rows pending review
          </span>
        </div>
      </div>

      <!-- ═══════════════ WORKFLOW STEPS ═══════════════ -->
      <div class="xl-steps mb-3">
        <div
          v-for="(s, i) in steps"
          :key="s.key"
          class="xl-step"
          :class="{ 'xl-step--done': s.done, 'xl-step--active': s.active }"
        >
          <span class="xl-step-num">
            <v-icon v-if="s.done" size="15">mdi-check</v-icon>
            <template v-else>{{ i + 1 }}</template>
          </span>
          <div style="min-width:0">
            <div class="xl-step-title">{{ s.title }}</div>
            <div class="xl-step-sub">{{ s.sub }}</div>
          </div>
        </div>
      </div>

      <v-row class="align-start">
        <!-- ═══════════════ LEFT: EXPORT ═══════════════ -->
        <v-col cols="12" md="4">
          <v-card rounded="lg" elevation="0" class="xl-card h-100 overflow-hidden">
            <div class="xl-section-head">
              <div class="d-flex align-center" style="gap:10px">
                <v-avatar size="32" color="teal" variant="tonal">
                  <v-icon size="17">mdi-file-export-outline</v-icon>
                </v-avatar>
                <div>
                  <div class="xl-section-title">Export</div>
                  <div class="xl-section-sub">Download your catalogue</div>
                </div>
              </div>
            </div>
            <v-divider />

            <div class="pa-3 d-flex flex-column" style="gap:8px">
              <button
                v-for="fmt in exportFormats"
                :key="fmt.kind"
                type="button"
                class="xl-format"
                :disabled="!!busy"
                @click="download(fmt.kind)"
              >
                <span class="xl-format-icon" :style="{ '--fmt-tone': fmt.tone }">
                  <v-icon size="18">{{ fmt.icon }}</v-icon>
                </span>
                <span class="xl-format-body">
                  <span class="xl-format-name">{{ fmt.name }}</span>
                  <span class="xl-format-desc">{{ fmt.description }}</span>
                </span>
                <v-progress-circular
                  v-if="busy === fmt.kind"
                  indeterminate
                  size="16"
                  width="2"
                  color="primary"
                />
                <v-icon v-else size="18" class="xl-format-go">mdi-download</v-icon>
              </button>

              <v-divider class="my-1" />

              <div class="xl-note">
                <v-icon size="15" color="teal">mdi-lightbulb-on-outline</v-icon>
                <div>
                  Exports include every column the importer accepts, so a round-trip
                  (export → edit → import) updates existing items instead of duplicating them.
                </div>
              </div>
            </div>
          </v-card>
        </v-col>

        <!-- ═══════════════ RIGHT: IMPORT ═══════════════ -->
        <v-col cols="12" md="8">
          <v-card rounded="lg" elevation="0" class="xl-card overflow-hidden">
            <div class="xl-section-head">
              <div class="d-flex align-center" style="gap:10px">
                <v-avatar size="32" color="primary" variant="tonal">
                  <v-icon size="17">mdi-file-upload-outline</v-icon>
                </v-avatar>
                <div>
                  <div class="xl-section-title">Import</div>
                  <div class="xl-section-sub">.xlsx or .csv · editable review before anything is saved</div>
                </div>
              </div>
              <v-chip
                v-if="rows.length"
                size="small"
                :color="countByStatus('error') ? 'error' : 'success'"
                variant="tonal"
                class="font-weight-bold"
              >
                {{ rows.length }} rows in review
              </v-chip>
            </div>
            <v-divider />

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
              <div class="text-h6 mb-1">{{ dragging ? 'Drop your file here' : 'Drag &amp; drop your spreadsheet' }}</div>
              <div class="text-body-2 text-medium-emphasis mb-3">
                or <span class="text-primary font-weight-medium">browse files</span> · .xlsx / .csv · up to ~5,000 rows
              </div>
              <div class="d-flex flex-wrap justify-center" style="gap:8px">
                <v-btn variant="tonal" color="primary" rounded="lg" class="text-none"
                       prepend-icon="mdi-file-download-outline" :loading="busy === 'template'"
                       @click.stop="download('template')">
                  Download the template first
                </v-btn>
              </div>
            </div>

            <v-progress-linear v-if="uploading" color="primary" indeterminate height="3" />

            <!-- Parse error -->
            <v-alert v-if="parseError" type="error" variant="tonal" rounded="lg" density="compact" class="ma-3">
              <template #prepend><v-icon>mdi-alert-circle</v-icon></template>
              {{ parseError }}
            </v-alert>

            <!-- Review table -->
            <template v-if="rows.length">
              <!-- Summary chips -->
              <div class="xl-review-bar">
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
                              clearable style="max-width: 240px" />
                <v-btn variant="text" color="primary" size="small" rounded="lg" class="text-none"
                       prepend-icon="mdi-plus" @click="addBlankRow">Add row</v-btn>
                <v-btn variant="text" color="error" size="small" rounded="lg" class="text-none"
                       prepend-icon="mdi-close-circle-outline" @click="reset">Start over</v-btn>
              </div>

              <div class="helper-strip">
                <v-icon size="14" color="primary" class="mr-1">mdi-information-outline</v-icon>
                Click any cell to edit · rows marked
                <v-chip size="x-small" variant="tonal" color="success" class="mx-1">New</v-chip>/
                <v-chip size="x-small" variant="tonal" color="info" class="mx-1">Update</v-chip>
                will be applied on submit · fix red rows before submitting
              </div>

              <div class="sheet-wrap">
                <table class="sheet">
              <thead>
                <tr>
                  <th class="col-row">Row</th>
                  <th class="col-status">Status</th>
                  <th class="col-name">Medication Name</th>
                  <th class="col-brand">Brand Name</th>
                  <th class="col-generic">Generic Name</th>
                  <th class="col-strength">Strength</th>
                  <th class="col-form">Dosage Form</th>
                  <th class="col-branch">Branch</th>
                  <th class="col-cat">Category</th>
                  <th class="col-class">Classification</th>
                  <th class="col-unit">Unit</th>
                  <th class="col-num">Sell (KSh)</th>
                  <th class="col-num">Cost (KSh)</th>
                  <th class="col-num">Disc %</th>
                  <th class="col-num">Tax %</th>
                  <th class="col-num">Qty</th>
                  <th class="col-num">Items/Unit</th>
                  <th class="col-num">Reorder Lv</th>
                  <th class="col-num">Reorder Qty</th>
                  <th class="col-loc">Location</th>
                  <th class="col-bar">Barcode</th>
                  <th class="col-rx">Rx</th>
                  <th class="col-act">Active</th>
                  <th class="col-rem"></th>
                </tr>
              </thead>
              <tbody>
                <template v-for="(row, i) in filteredRows" :key="row.uid">
                  <tr :class="{
                    'row-error': row.status === 'error',
                    'row-new': row.status === 'new',
                    'row-update': row.status === 'update',
                  }">
                    <td class="text-caption text-medium-emphasis">{{ i + 1 }}</td>
                    <td>
                      <v-chip :color="statusColor(row.status)" variant="tonal" size="x-small">
                        <v-icon start size="12">{{ statusIcon(row.status) }}</v-icon>
                        {{ statusLabel(row.status) }}
                      </v-chip>
                    </td>
                    <td>
                      <input v-model="row.medication_name" class="cell-input cell-name" type="text"
                             placeholder="Required" @input="touchRow(row, 'medication_name', row.medication_name)" />
                    </td>
                    <td>
                      <input v-model="row.brand_name" class="cell-input" type="text"
                             placeholder="e.g. Panadol" />
                    </td>
                    <td>
                      <input v-model="row.generic_name" class="cell-input" type="text"
                             placeholder="e.g. paracetamol" />
                    </td>
                    <td>
                      <input v-model="row.strength" class="cell-input" type="text"
                             placeholder="e.g. 500mg" />
                    </td>
                    <td>
                      <select v-model="row.dosage_form" class="cell-input">
                        <option value="">—</option>
                        <option v-for="df in dosageFormOptions" :key="df" :value="df">{{ df }}</option>
                      </select>
                    </td>
                    <td>
                      <select v-model="row.branch" class="cell-input" @change="touchRow(row, 'branch', row.branch)">
                        <option value="">Warehouse…</option>
                        <option v-for="b in branchList" :key="b.id" :value="b.name">{{ b.name }}</option>
                      </select>
                    </td>
                    <td>
                      <v-combobox v-model="row.category" :items="categoryNames" clearable
                                  placeholder="Category" density="compact" variant="outlined"
                                  hide-details single-line class="cell-combo"
                                  :menu-props="{ maxHeight: 220 }" />
                    </td>
                    <td>
                      <v-combobox v-model="row.classification" :items="classificationNames" clearable
                                  placeholder="Classification" density="compact" variant="outlined"
                                  hide-details single-line class="cell-combo"
                                  :menu-props="{ maxHeight: 220 }" />
                    </td>
                    <td>
                      <v-combobox v-model="row.unit" :items="unitNames" clearable
                                  placeholder="Unit" density="compact" variant="outlined"
                                  hide-details single-line class="cell-combo"
                                  :menu-props="{ maxHeight: 220 }" />
                    </td>
                    <td><input v-model.number="row.selling_price" class="cell-input num" type="number" min="0" step="0.01" /></td>
                    <td><input v-model.number="row.cost_price" class="cell-input num" type="number" min="0" step="0.01" /></td>
                    <td><input v-model.number="row.discount_percent" class="cell-input num" type="number" min="0" max="100" step="0.01" /></td>
                    <td><input v-model.number="row.tax_percent" class="cell-input num" type="number" min="0" max="100" step="0.01" /></td>
                    <td>
                      <input v-model.number="row.total_quantity" class="cell-input num cell-qty" type="number" min="0" step="1" />
                      <div v-if="row.status === 'update' && row.existing_quantity != null" class="text-caption text-medium-emphasis">
                        now: {{ row.existing_quantity }}
                      </div>
                    </td>                    <td><input v-model.number="row.items_per_unit" class="cell-input num" type="number" min="0" step="1" /></td>                    <td><input v-model.number="row.reorder_level" class="cell-input num" type="number" min="0" step="1" /></td>
                    <td><input v-model.number="row.reorder_quantity" class="cell-input num" type="number" min="0" step="1" /></td>
                    <td><input v-model="row.location_in_store" class="cell-input" type="text" /></td>
                    <td><input v-model="row.barcode" class="cell-input cell-mono" type="text" /></td>
                    <td>
                      <select v-model="row.prescription_required" class="cell-input">
                        <option value="">—</option>
                        <option value="none">None</option>
                        <option value="recommended">Recommended</option>
                        <option value="required">Required</option>
                      </select>
                    </td>
                    <td>
                      <select v-model="row.is_active" class="cell-input">
                        <option value="">—</option>
                        <option value="Yes">Yes</option>
                        <option value="No">No</option>
                      </select>
                    </td>
                    <td class="text-center">
                      <v-btn icon="mdi-close" size="x-small" variant="text" color="error"
                             @click="removeRow(row)" />
                    </td>
                  </tr>
                  <tr v-if="row.errors && Object.keys(row.errors).length" class="error-row">
                    <td :colspan="24">
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
            <div class="d-flex flex-column">
              <span class="text-body-2 font-weight-medium">
                {{ countByStatus('new') }} new · {{ countByStatus('update') }} updates
              </span>
              <span class="text-caption" :class="countByStatus('error') ? 'text-error' : 'text-medium-emphasis'">
                {{ countByStatus('error')
                  ? `${countByStatus('error')} row(s) need fixing before you can submit`
                  : 'All rows valid — ready to commit' }}
              </span>
            </div>
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
        </v-col>
      </v-row>

      <!-- Result dialog -->
      <v-dialog v-model="resultDialog" max-width="560" persistent>
        <v-card rounded="lg" class="overflow-hidden">
          <BrandDialogHeader
            :icon="result.failed ? 'mdi-alert-circle-check' : 'mdi-check-decagram'"
            :title="result.failed ? 'Import finished with issues' : 'Import complete'"
            :subtitle="`${result.created} created · ${result.updated} updated${result.failed ? ` · ${result.failed} failed` : ''}`"
            @close="resultDialog = false"
          />
          <div class="pa-5">
            <div class="xl-result-grid mb-3">
              <div class="xl-result-tile xl-result-tile--ok">
                <div class="xl-result-value">{{ result.created }}</div>
                <div class="xl-result-label">created</div>
              </div>
              <div class="xl-result-tile xl-result-tile--info">
                <div class="xl-result-value">{{ result.updated }}</div>
                <div class="xl-result-label">updated</div>
              </div>
              <div v-if="result.failed" class="xl-result-tile xl-result-tile--err">
                <div class="xl-result-value">{{ result.failed }}</div>
                <div class="xl-result-label">failed</div>
              </div>
            </div>

            <div v-if="failedRows.length" class="xl-failed">
              <div class="xl-failed-head">
                <v-icon size="15" color="error">mdi-alert-circle-outline</v-icon>
                Rows that could not be applied
              </div>
              <div v-for="f in failedRows" :key="f.row" class="xl-failed-row">
                <span class="xl-failed-num">#{{ f.row }}</span>
                <span class="xl-failed-name">{{ f.name || '—' }}</span>
                <span class="xl-failed-err">{{ f.error }}</span>
              </div>
            </div>
          </div>
          <v-card-actions class="px-5 pb-4">
            <v-btn variant="text" rounded="lg" class="text-none" @click="resultDialog = false">Close</v-btn>
            <v-spacer />
            <v-btn color="primary" rounded="lg" class="text-none" :to="p('/inventory')">
              Back to inventory
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

const stockCount = ref(0)
const categories = ref([])
const classifications = ref([])
const units = ref([])
const branchList = ref([])
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

// Inventory tenants use their own /ims API namespace.
const { branches: branchesApi, isInventory } = useTenantEndpoints()

// Keep every link inside the tenant namespace this page was reached from
// (/ims for warehouses, /pharmacy for pharmacies).
const base = computed(() => (isInventory.value ? '/ims' : '/pharmacy'))
const p = (suffix) => `${base.value}${suffix}`

// Tenant palette → hero CSS variables (same bridge as the rest of the IMS UI).
const brand = useBranding()
const heroTheme = computed(() => ({
  '--hero-deep': brand.secondary.value,
  '--hero-main': brand.primary.value,
  '--hero-accent': brand.gradientStops.value[2],
  '--hero-ink': brand.ink.value,
  '--hero-glow': brand.tint('primary', 0.3),
  '--hero-glow-2': brand.tint('accent', 0.2),
  '--hero-shadow': brand.shadow.value
}))

// ── Export formats ──────────────────────────────────────────────────
// Rendered as selectable tiles rather than three loose buttons.
const exportFormats = [
  {
    kind: 'excel',
    name: 'Excel workbook (.xlsx)',
    description: 'Full catalogue, formatted for editing',
    icon: 'mdi-microsoft-excel',
    tone: '#16A34A'
  },
  {
    kind: 'csv',
    name: 'CSV (.csv)',
    description: 'Plain text, ideal for other systems',
    icon: 'mdi-file-delimited-outline',
    tone: '#0284C7'
  },
  {
    kind: 'template',
    name: 'Blank import template',
    description: 'Column headers only — start from scratch',
    icon: 'mdi-file-document-outline',
    tone: '#7C3AED'
  }
]

// ── Workflow steps ──────────────────────────────────────────────────
// Reflects the live state of the review sheet, so the strip doubles as a
// progress indicator instead of static decoration.
const steps = computed(() => {
  const hasRows = rows.value.length > 0
  const errors = countByStatus('error')
  return [
    {
      key: 'upload',
      title: 'Upload',
      sub: hasRows ? 'File parsed' : 'Choose or drop a spreadsheet',
      done: hasRows,
      active: !hasRows
    },
    {
      key: 'review',
      title: 'Review & fix',
      sub: hasRows ? `${rows.value.length} rows loaded` : 'Nothing loaded yet',
      done: hasRows && !errors,
      active: hasRows && !!errors
    },
    {
      key: 'commit',
      title: 'Commit',
      sub: hasRows && !errors ? 'Ready to submit' : 'Resolve errors first',
      done: false,
      active: hasRows && !errors
    }
  ]
})

onMounted(async () => {
  brand.load()
  try {
    const [stocksRes, catsRes, classRes, unitsRes, branchesRes] = await Promise.all([
      $api.get('/inventory/stocks/', { params: { page_size: 1 } }),
      $api.get('/inventory/categories/', { params: { page_size: 1000 } }),
      $api.get('/inventory/classifications/', { params: { page_size: 1000 } }),
      $api.get('/inventory/units/', { params: { page_size: 1000 } }),
      $api.get(branchesApi.value, { params: { page_size: 200 } }),
    ])
    stockCount.value = stocksRes.data?.count ?? (stocksRes.data?.length ?? 0)
    categories.value = catsRes.data?.results ?? catsRes.data
    classifications.value = classRes.data?.results ?? classRes.data
    units.value = unitsRes.data?.results ?? unitsRes.data
    branchList.value = branchesRes.data?.results ?? branchesRes.data
  } catch { /* count is cosmetic */ }
})

const categoryNames = computed(() => categories.value.map(c => c.name))
const classificationNames = computed(() => classifications.value.map(c => c.name))
const unitNames = computed(() => units.value.map(u => u.name))

const dosageFormOptions = ['tablet', 'capsule', 'syrup', 'injection', 'cream',
  'ointment', 'drops', 'inhaler', 'suppository', 'suspension', 'powder',
  'gel', 'patch', 'lozenge', 'spray']

// ── Download helpers ───────────────────────────────────────────────
async function download(kind) {
  busy.value = kind
  try {
    let url, name, blob
    if (kind === 'template') {
      url = '/inventory/stocks/import-template/'
      name = `inventory_import_template_${new Date().toISOString().slice(0, 10)}.xlsx`
    } else if (kind === 'excel') {
      url = '/inventory/stocks/export/?fmt=excel'
      name = `inventory_${new Date().toISOString().slice(0, 10)}.xlsx`
    } else {
      url = '/inventory/stocks/export/?fmt=csv'
      name = `inventory_${new Date().toISOString().slice(0, 10)}.csv`
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
    const { data } = await $api.post('/inventory/stocks/import-preview/', fd)
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
  medication_name: 'Medication Name',
  brand_name: 'Brand Name',
  generic_name: 'Generic Name',
  strength: 'Strength',
  dosage_form: 'Dosage Form',
  branch: 'Branch (Warehouse)',
  category: 'Category', unit: 'Unit',
  classification: 'Classification',
  selling_price: 'Selling Price', cost_price: 'Cost Price',
  discount_percent: 'Discount %', tax_percent: 'Tax %',
  total_quantity: 'Total Quantity',
  items_per_unit: 'Items Per Unit',
  reorder_level: 'Reorder Level', reorder_quantity: 'Reorder Quantity',
  location_in_store: 'Location', barcode: 'Barcode',
  prescription_required: 'Prescription Required', is_active: 'Active',
}
function fieldLabel(f) { return FIELD_LABELS[f] || f }
function statusColor(s) { return { new: 'success', update: 'info', error: 'error' }[s] || 'grey' }
function statusIcon(s) { return { new: 'mdi-plus', update: 'mdi-pencil', error: 'mdi-alert' }[s] || 'mdi-help' }
function statusLabel(s) { return { new: 'New', update: 'Update', error: 'Error' }[s] || s }

const filteredRows = computed(() => {
  const q = (search.value || '').toLowerCase().trim()
  if (!q) return rows.value
  return rows.value.filter(r =>
    (r.medication_name || '').toLowerCase().includes(q) ||
    (r.brand_name || '').toLowerCase().includes(q) ||
    (r.generic_name || '').toLowerCase().includes(q) ||
    (r.strength || '').toLowerCase().includes(q) ||
    (r.dosage_form || '').toLowerCase().includes(q) ||
    (r.category || '').toLowerCase().includes(q) ||
    (r.classification || '').toLowerCase().includes(q) ||
    (r.barcode || '').toLowerCase().includes(q))
})

function countByStatus(s) { return rows.value.filter(r => r.status === s).length }

// Re-validate a row client-side as it is edited
function touchRow(row) {
  const errors = {}
  if (!(row.medication_name || '').trim()) errors.medication_name = 'Required'
  // Branch (warehouse) is compulsory for new items
  if (!row.existing_id && !(row.branch || '').trim()) errors.branch = 'Required - pick a warehouse'
  for (const f of ['selling_price', 'cost_price', 'discount_percent', 'tax_percent',
                   'total_quantity', 'reorder_level', 'reorder_quantity']) {
    const v = row[f]
    if (v === null || v === undefined || v === '') continue
    if (Number.isNaN(Number(v))) errors[f] = 'Must be a number'
    else if (Number(v) < 0) errors[f] = 'Must be ≥ 0'
    else if ((f === 'discount_percent' || f === 'tax_percent') && Number(v) > 100) errors[f] = 'Max 100'
  }
  row.errors = errors
  row.status = Object.keys(errors).length ? 'error' : (row.existing_id ? 'update' : 'new')
}

function addBlankRow() {
  rows.value.push({
    uid: uidSeq++,
    row_num: rows.value.length + 2,
    medication_name: '', brand_name: '', generic_name: '', strength: '', dosage_form: '',
    branch: '', category: '', classification: '', unit: '',
    selling_price: null, cost_price: null, discount_percent: null, tax_percent: null,
    total_quantity: null, items_per_unit: null, reorder_level: null, reorder_quantity: null,
    location_in_store: '', barcode: '',
    prescription_required: 'none', is_active: 'Yes',
    status: 'error', existing_id: null, existing_quantity: null,
    errors: { medication_name: 'Required', branch: 'Required - pick a warehouse' },
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
  rows.value.length > 0 && !rows.value.some(r => r.status === 'error'))

// ── Submit ────────────────────────────────────────────────────────
async function submitImport() {
  submitting.value = true
  try {
    const items = rows.value.map(r => {
      const out = { row_num: r.row_num, medication_name: r.medication_name }
      if (r.branch) out.branch = r.branch
      for (const f of ['category', 'classification', 'unit', 'location_in_store', 'barcode',
                       'prescription_required', 'is_active',
                       'brand_name', 'generic_name', 'strength', 'dosage_form']) {
        if (r[f] !== null && r[f] !== undefined && r[f] !== '') out[f] = r[f]
      }
      for (const f of ['selling_price', 'cost_price', 'discount_percent', 'tax_percent',
                       'total_quantity', 'items_per_unit', 'reorder_level', 'reorder_quantity']) {
        if (r[f] !== null && r[f] !== undefined && r[f] !== '') out[f] = Number(r[f])
      }
      return out
    })
    const { data } = await $api.post('/inventory/stocks/import-commit/', { items })
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
.xl-page { max-width: 1600px; margin: 0 auto; }

/* ═══════════════ Hero ═══════════════ */
.xl-hero {
  position: relative;
  overflow: hidden;
  border-radius: 18px;
  padding: 20px 22px 16px;
  color: #fff;
  background: linear-gradient(
    120deg,
    var(--hero-deep, #143ce1) 0%,
    var(--hero-main, #2f6dff) 52%,
    var(--hero-accent, #37d6ff) 100%
  );
  box-shadow: var(--hero-shadow, 0 14px 34px rgba(47, 109, 255, 0.24));
}
.xl-glow {
  position: absolute;
  width: 340px;
  height: 340px;
  border-radius: 50%;
  right: -110px;
  top: -170px;
  background: radial-gradient(circle, var(--hero-glow, rgba(255, 255, 255, 0.28)), transparent 68%);
  pointer-events: none;
}
.xl-glow-2 {
  right: auto;
  left: -140px;
  top: auto;
  bottom: -220px;
  width: 300px;
  height: 300px;
  background: radial-gradient(circle, var(--hero-glow-2, rgba(55, 214, 255, 0.24)), transparent 70%);
}
.xl-hero-top { position: relative; }
.xl-hero-icon {
  width: 56px;
  height: 56px;
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  background: rgba(255, 255, 255, 0.16);
  border: 1px solid rgba(255, 255, 255, 0.28);
  backdrop-filter: blur(6px);
}
.xl-eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: rgba(255, 255, 255, 0.78);
}
.xl-title {
  font-size: 26px;
  line-height: 1.15;
  font-weight: 800;
  letter-spacing: -0.2px;
  margin: 2px 0;
}
.xl-sub {
  font-size: 13px;
  color: rgba(255, 255, 255, 0.82);
  max-width: 760px;
}
.xl-hero-iconbtn { color: #fff !important; }

.xl-btn-strong {
  background: #ffffff !important;
  color: var(--hero-ink, #143ce1) !important;
  font-weight: 700 !important;
  border: 1px solid rgba(255, 255, 255, 0.95) !important;
  box-shadow: 0 6px 18px rgba(6, 44, 40, 0.28) !important;
}
.xl-btn-strong:hover { background: #ffffff !important; filter: brightness(0.94); }
.xl-btn-strong :deep(.v-icon) { color: var(--hero-ink, #143ce1) !important; opacity: 1 !important; }
.xl-btn-glass {
  background: rgba(255, 255, 255, 0.16) !important;
  color: #ffffff !important;
  font-weight: 600 !important;
  border: 1px solid rgba(255, 255, 255, 0.34) !important;
  backdrop-filter: blur(6px);
}
.xl-btn-glass:hover {
  background: rgba(255, 255, 255, 0.26) !important;
  border-color: rgba(255, 255, 255, 0.6) !important;
}
.xl-btn-glass :deep(.v-icon) { color: #fff !important; opacity: 1 !important; }

.xl-hero-foot {
  position: relative;
  margin-top: 14px;
  padding-top: 12px;
  border-top: 1px solid rgba(255, 255, 255, 0.2);
}
.xl-hero-chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 4px 10px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 600;
  color: rgba(255, 255, 255, 0.94);
  background: rgba(255, 255, 255, 0.14);
  border: 1px solid rgba(255, 255, 255, 0.24);
}
.xl-hero-chip-warn {
  background: rgba(245, 158, 11, 0.34);
  border-color: rgba(255, 255, 255, 0.42);
}

/* ═══════════════ Workflow steps ═══════════════ */
.xl-steps {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 10px;
}
.xl-step {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 11px 14px;
  border-radius: 12px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: rgb(var(--v-theme-surface));
  transition: border-color 0.18s ease, background 0.18s ease;
}
.xl-step--done {
  border-color: rgba(34, 197, 94, 0.32);
  background: rgba(34, 197, 94, 0.055);
}
.xl-step--active {
  border-color: rgba(var(--v-theme-primary), 0.42);
  background: rgba(var(--v-theme-primary), 0.055);
}
.xl-step-num {
  width: 28px;
  height: 28px;
  border-radius: 9px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-size: 12px;
  font-weight: 800;
  color: rgba(var(--v-theme-on-surface), 0.55);
  background: rgba(15, 23, 42, 0.05);
}
.xl-step--done .xl-step-num { color: #15803d; background: rgba(34, 197, 94, 0.16); }
.xl-step--active .xl-step-num {
  color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.14);
}
.xl-step-title {
  font-size: 13px;
  font-weight: 700;
  line-height: 1.2;
}
.xl-step-sub {
  font-size: 11.5px;
  color: rgba(var(--v-theme-on-surface), 0.58);
  line-height: 1.3;
}

/* ═══════════════ Cards / section heads ═══════════════ */
.xl-card {
  border: 1px solid rgba(15, 23, 42, 0.08) !important;
  background: rgb(var(--v-theme-surface));
}
.xl-section-head {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  padding: 12px 16px;
}
.xl-section-title {
  font-size: 14.5px;
  font-weight: 700;
  line-height: 1.2;
}
.xl-section-sub {
  font-size: 11.5px;
  color: rgba(var(--v-theme-on-surface), 0.55);
}

/* ═══════════════ Export format tiles ═══════════════ */
.xl-format {
  display: flex;
  align-items: center;
  gap: 11px;
  width: 100%;
  padding: 10px 12px;
  border-radius: 11px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: rgb(var(--v-theme-surface));
  text-align: left;
  cursor: pointer;
  transition: transform 0.16s ease, box-shadow 0.16s ease, border-color 0.16s ease;
}
.xl-format:hover:not(:disabled) {
  transform: translateY(-1px);
  border-color: color-mix(in srgb, var(--fmt-tone, #2563eb) 40%, transparent);
  box-shadow: 0 8px 18px rgba(15, 23, 42, 0.08);
}
.xl-format:disabled { cursor: wait; opacity: 0.65; }
.xl-format-icon {
  width: 34px;
  height: 34px;
  border-radius: 10px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  color: var(--fmt-tone, #2563eb);
  background: color-mix(in srgb, var(--fmt-tone, #2563eb) 14%, transparent);
}
.xl-format-body {
  display: flex;
  flex-direction: column;
  min-width: 0;
  flex: 1;
}
.xl-format-name {
  font-size: 13px;
  font-weight: 700;
  line-height: 1.25;
}
.xl-format-desc {
  font-size: 11px;
  line-height: 1.3;
  color: rgba(var(--v-theme-on-surface), 0.58);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.xl-format-go { color: rgba(var(--v-theme-on-surface), 0.35); flex-shrink: 0; }
.xl-format:hover:not(:disabled) .xl-format-go { color: rgb(var(--v-theme-primary)); }

.xl-note {
  display: flex;
  gap: 9px;
  padding: 10px 12px;
  border-radius: 10px;
  font-size: 11.5px;
  line-height: 1.45;
  color: rgba(var(--v-theme-on-surface), 0.62);
  background: rgba(13, 148, 136, 0.06);
  border: 1px solid rgba(13, 148, 136, 0.16);
}

/* ── Drop zone ──────────────────────────────────────────────────────── */
.dropzone {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  padding: 44px 16px;
  margin: 12px;
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

/* Marching-ants dotted border (animated) */
.dropzone-ants {
  position: absolute;
  inset: -2px; /* cover the static border */
  width: calc(100% + 4px);
  height: calc(100% + 4px);
  pointer-events: none;
}
.dropzone-ants rect {
  fill: none;
  stroke: rgb(var(--v-theme-primary));
  stroke-width: 2.5;
  stroke-linecap: round;
  stroke-dasharray: 0.5 14; /* round caps turn this into dots */
  opacity: 0.55;
  animation: dz-march 1.2s linear infinite;
}
.dropzone:hover .dropzone-ants rect,
.dropzone-active .dropzone-ants rect {
  opacity: 1;
  animation-duration: 0.45s;
}
@keyframes dz-march {
  to { stroke-dashoffset: -29; } /* 2 pattern lengths (0.5 + 14) = seamless loop */
}
@media (prefers-reduced-motion: reduce) {
  .dropzone-ants rect { animation: none; }
}

/* ═══════════════ Review bar ═══════════════ */
.xl-review-bar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
  padding: 10px 16px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
  background: rgba(var(--v-theme-primary), 0.02);
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
.col-name { min-width: 220px; }
.col-branch { min-width: 150px; }
.col-cat, .col-unit, .col-loc, .col-bar, .col-rx { min-width: 120px; }
.col-num { width: 108px; min-width: 108px; }
.col-act { min-width: 86px; }
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
.cell-input.cell-qty { font-weight: 600; color: rgb(var(--v-theme-success)); }
.cell-mono { font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: 12px; }

/* Vuetify comboboxes sized to fit the sheet cells */
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
  background: rgba(15, 23, 42, 0.015);
}

/* ═══════════════ Result dialog ═══════════════ */
.xl-result-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(96px, 1fr));
  gap: 10px;
}
.xl-result-tile {
  padding: 12px;
  border-radius: 11px;
  text-align: center;
  border: 1px solid rgba(15, 23, 42, 0.07);
  background: rgba(var(--v-theme-surface-variant), 0.2);
}
.xl-result-tile--ok { border-color: rgba(34, 197, 94, 0.3); background: rgba(34, 197, 94, 0.08); }
.xl-result-tile--info { border-color: rgba(14, 165, 233, 0.3); background: rgba(14, 165, 233, 0.08); }
.xl-result-tile--err { border-color: rgba(239, 68, 68, 0.3); background: rgba(239, 68, 68, 0.08); }
.xl-result-value {
  font-size: 22px;
  font-weight: 800;
  line-height: 1.15;
  letter-spacing: -0.4px;
}
.xl-result-label {
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.5px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.xl-failed {
  border-radius: 10px;
  border: 1px solid rgba(239, 68, 68, 0.24);
  background: rgba(239, 68, 68, 0.05);
  overflow: hidden;
}
.xl-failed-head {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 11px;
  font-size: 11.5px;
  font-weight: 700;
  color: #b91c1c;
  border-bottom: 1px solid rgba(239, 68, 68, 0.18);
}
.xl-failed-row {
  display: flex;
  align-items: baseline;
  gap: 8px;
  padding: 6px 11px;
  font-size: 11.5px;
  border-bottom: 1px solid rgba(239, 68, 68, 0.1);
}
.xl-failed-row:last-child { border-bottom: none; }
.xl-failed-num {
  font-weight: 800;
  color: #b91c1c;
  flex-shrink: 0;
}
.xl-failed-name {
  font-weight: 600;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 40%;
}
.xl-failed-err {
  color: rgba(var(--v-theme-on-surface), 0.62);
  margin-left: auto;
  text-align: right;
}

@media (max-width: 700px) {
  .xl-title { font-size: 21px; }
  .xl-hero { padding: 16px 16px 14px; border-radius: 16px; }
  .dropzone { padding: 32px 14px; margin: 10px; }
}
</style>
