<template>
  <v-container fluid class="pa-3 pa-md-5 rfq-page">

    <!-- ═══════════════ HERO ═══════════════ -->
    <div class="rfq-hero mb-4" :style="heroTheme">
      <span class="rfq-glow" />
      <span class="rfq-glow rfq-glow-2" />

      <div class="d-flex flex-wrap align-center justify-space-between ga-3 rfq-hero-top">
        <div class="d-flex align-center" style="gap:16px; min-width:0">
          <div class="rfq-hero-icon">
            <v-icon size="30">mdi-file-document-plus-outline</v-icon>
          </div>
          <div style="min-width:0">
            <div class="rfq-eyebrow">
              <v-icon size="10">mdi-circle</v-icon>
              PROCUREMENT · NEW REQUEST
            </div>
            <h1 class="rfq-title">New request for quotation</h1>
            <div class="rfq-sub">Capture your requirements once and invite competing supplier bids</div>
          </div>
        </div>

        <div class="d-flex flex-wrap align-center ga-2">
          <v-btn
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none rfq-btn-glass"
            prepend-icon="mdi-arrow-left"
            :to="`${ns}/purchase-orders/rfqs`"
          >Cancel</v-btn>
          <v-btn
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none rfq-btn-strong"
            prepend-icon="mdi-check"
            :loading="saving"
            :disabled="!canSubmit"
            @click="save"
          >Create RFQ</v-btn>
        </div>
      </div>

      <div class="rfq-hero-foot d-flex flex-wrap align-center" style="gap:8px">
        <span class="rfq-hero-chip"><v-icon size="14">mdi-package-variant-closed</v-icon>{{ validItems.length }} item{{ validItems.length === 1 ? '' : 's' }}</span>
        <span class="rfq-hero-chip"><v-icon size="14">mdi-counter</v-icon>{{ totalQty }} total units</span>
        <span class="rfq-hero-chip"><v-icon size="14">mdi-calendar-clock</v-icon>{{ deadlinePreview }}</span>
        <span v-if="prefillNotice" class="rfq-hero-chip"><v-icon size="14">mdi-lightning-bolt-outline</v-icon>{{ prefillNotice }}</span>
      </div>
    </div>

    <v-form ref="formRef" @submit.prevent="save">
      <v-row>
        <!-- ═══════════════ BUILDER ═══════════════ -->
        <v-col cols="12" lg="8">
          <!-- 01 · Request details -->
          <v-card rounded="lg" elevation="0" class="rfq-card mb-3">
            <div class="rfq-section-head">
              <span class="rfq-step">01</span>
              <div>
                <div class="rfq-section-title">Request details</div>
                <div class="rfq-section-sub">Name the request and describe exactly what you need</div>
              </div>
            </div>
            <v-divider />
            <div class="pa-4">
              <v-text-field
                v-model="form.title"
                label="Request title *"
                placeholder="e.g. Q4 consumables replenishment"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                prepend-inner-icon="mdi-format-title"
                :rules="[(v) => !!(v && v.trim()) || 'A request title is required']"
                class="mb-3"
              />

              <!-- Quick-select common request types. Picking one writes the
                   title and, when the description is still blank or was itself
                   auto-filled by an earlier preset, seeds the requirements too. -->
              <div class="rfq-presets mb-3">
                <div class="rfq-presets-label">
                  <v-icon size="14">mdi-lightning-bolt-outline</v-icon>
                  <span>Quick select</span>
                  <span class="text-medium-emphasis">— applies a title and fills the requirements</span>
                </div>
                <div class="rfq-presets-chips">
                  <v-chip
                    v-for="preset in titlePresets"
                    :key="preset.label"
                    :color="activePresetKey === preset.label ? 'purple' : undefined"
                    :variant="activePresetKey === preset.label ? 'flat' : 'tonal'"
                    size="small"
                    class="text-none rfq-preset-chip"
                    @click="applyPreset(preset)"
                  >
                    <v-icon start size="14">{{ preset.icon }}</v-icon>
                    {{ preset.label }}
                  </v-chip>
                </div>
                <v-expand-transition>
                  <div v-if="presetNotice" class="rfq-preset-note">
                    <v-icon size="14">mdi-information-outline</v-icon>
                    {{ presetNotice }}
                  </div>
                </v-expand-transition>
              </div>

              <v-textarea
                v-model="form.description"
                label="Description / requirements"
                placeholder="Delivery expectations, packaging, quality standards, payment terms…"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                rows="4"
                auto-grow
                hide-details
                @update:model-value="presetNotice = ''"
              />
            </div>
          </v-card>

          <!-- 02 · Logistics -->
          <v-card rounded="lg" elevation="0" class="rfq-card mb-3">
            <div class="rfq-section-head">
              <span class="rfq-step">02</span>
              <div>
                <div class="rfq-section-title">Logistics &amp; timing</div>
                <div class="rfq-section-sub">Choose the receiving branch and the bidding window</div>
              </div>
            </div>
            <v-divider />
            <div class="pa-4">
              <v-row dense>
                <v-col cols="12" sm="4">
                  <v-select
                    v-model="form.branch"
                    :items="branchOptions"
                    item-title="label"
                    item-value="value"
                    label="Branch / warehouse *"
                    density="comfortable"
                    variant="outlined"
                    rounded="lg"
                    prepend-inner-icon="mdi-store-marker"
                    :rules="[(v) => v != null || 'Choose a branch']"
                    hide-details="auto"
                  />
                </v-col>
                <v-col cols="12" sm="4">
                  <v-text-field
                    v-model="form.response_deadline"
                    type="date"
                    label="Response deadline"
                    density="comfortable"
                    variant="outlined"
                    rounded="lg"
                    prepend-inner-icon="mdi-calendar-clock"
                    hide-details
                  />
                </v-col>
                <v-col cols="12" sm="4">
                  <v-text-field
                    v-model="form.expected_delivery"
                    type="date"
                    label="Expected delivery"
                    density="comfortable"
                    variant="outlined"
                    rounded="lg"
                    prepend-inner-icon="mdi-truck-clock-outline"
                    hide-details
                  />
                </v-col>
              </v-row>

              <div class="d-flex flex-wrap align-center mt-3" style="gap:8px">
                <span class="text-caption text-medium-emphasis mr-1">Respond within</span>
                <v-chip
                  v-for="preset in deadlinePresets"
                  :key="preset.days"
                  size="small"
                  variant="tonal"
                  color="purple"
                  class="text-none rfq-preset"
                  @click="setDeadline(preset.days)"
                >{{ preset.label }}</v-chip>
              </div>
            </div>
          </v-card>

          <!-- 03 · Items -->
          <v-card rounded="lg" elevation="0" class="rfq-card mb-3">
            <div class="rfq-section-head">
              <span class="rfq-step">03</span>
              <div>
                <div class="rfq-section-title">Requested items</div>
                <div class="rfq-section-sub">Pick from the catalog as you type, or simply type a custom item and press Enter</div>
              </div>
              <v-spacer />
              <div class="d-flex flex-wrap align-center" style="gap:6px">
                <v-chip v-if="catalogCount" size="small" variant="tonal" color="purple" prepend-icon="mdi-database-search-outline">
                  {{ catalogCount }} catalog
                </v-chip>
                <v-chip v-if="manualCount" size="small" variant="tonal" color="warning" prepend-icon="mdi-pencil-outline">
                  {{ manualCount }} manual
                </v-chip>
                <v-chip size="small" variant="tonal" color="grey">{{ form.items.length }} line{{ form.items.length === 1 ? '' : 's' }}</v-chip>
              </div>
            </div>
            <v-divider />

            <div class="pa-4">
              <div class="rfq-line-head">
                <span>#</span>
                <span>Item</span>
                <span class="text-right">Qty</span>
                <span>Unit</span>
                <span />
              </div>

              <div
                v-for="(item, i) in form.items"
                :key="i"
                class="rfq-line"
              >
                <span class="rfq-line-index">
                  <span>{{ String(i + 1).padStart(2, '0') }}</span>
                  <v-icon
                    v-if="item.source"
                    size="12"
                    :color="item.source === 'manual' ? 'warning' : 'purple'"
                    :title="item.source === 'manual' ? 'Manual entry (not in the catalog)' : 'Selected from the catalog'"
                  >{{ item.source === 'manual' ? 'mdi-pencil' : 'mdi-database-check-outline' }}</v-icon>
                </span>

                <v-combobox
                  v-model="item.pick"
                  class="rfq-line-name"
                  :items="itemSearchResults"
                  item-title="label"
                  item-value="id"
                  :return-object="true"
                  placeholder="Search the catalog or type a custom item"
                  density="compact"
                  variant="outlined"
                  rounded="lg"
                  hide-details
                  clearable
                  :loading="itemSearching"
                  :hide-no-data="false"
                  :menu-props="{ maxHeight: 340 }"
                  @update:search="onItemSearch"
                  @update:model-value="onPickItem(item, $event)"
                  @keydown.enter="onItemEnter(item)"
                  @blur="onItemBlur(item)"
                >
                  <template #prepend-inner>
                    <v-icon size="17" :color="item.source === 'manual' ? 'warning' : 'grey'">
                      {{ item.source === 'manual' ? 'mdi-pencil-outline' : 'mdi-magnify' }}
                    </v-icon>
                  </template>

                  <template #item="{ props: ip, item: opt }">
                    <v-list-item v-bind="ip" :title="opt.raw.label">
                      <template #prepend>
                        <v-avatar size="30" color="purple" variant="tonal">
                          <v-icon size="15">mdi-pill</v-icon>
                        </v-avatar>
                      </template>
                      <template #subtitle>
                        <div class="d-flex flex-wrap align-center" style="gap:4px">
                          <v-chip v-if="opt.raw.category" size="x-small" variant="tonal" color="purple">{{ opt.raw.category }}</v-chip>
                          <span v-if="opt.raw.strength" class="text-caption text-medium-emphasis">{{ opt.raw.strength }}</span>
                          <span v-if="opt.raw.unit" class="text-caption text-medium-emphasis">per {{ opt.raw.unit }}</span>
                        </div>
                      </template>
                    </v-list-item>
                  </template>

                  <template #no-data>
                    <div v-if="itemSearchQuery && !itemSearching" class="pa-1">
                      <v-list-item class="rfq-manual-option rounded-lg" @click="commitManual(item, itemSearchQuery)">
                        <template #prepend>
                          <v-avatar size="30" color="warning" variant="tonal">
                            <v-icon size="15">mdi-pencil-plus-outline</v-icon>
                          </v-avatar>
                        </template>
                        <v-list-item-title class="text-body-2 font-weight-medium">
                          Add “{{ itemSearchQuery }}” as a manual item
                        </v-list-item-title>
                        <v-list-item-subtitle class="text-caption">
                          Not in the catalog — this text is used exactly as typed
                        </v-list-item-subtitle>
                      </v-list-item>
                      <div class="rfq-manual-hint">
                        <v-icon size="13">mdi-keyboard-return</v-icon>
                        Press <b>Enter</b> for the same result
                      </div>
                    </div>
                  </template>
                </v-combobox>

                <v-text-field
                  v-model.number="item.qty"
                  class="rfq-line-qty"
                  label="Qty"
                  type="number"
                  min="1"
                  density="compact"
                  variant="outlined"
                  rounded="lg"
                  hide-details
                />

                <v-combobox
                  v-model="item.unit"
                  class="rfq-line-unit"
                  :items="unitOptions"
                  label="Unit"
                  density="compact"
                  variant="outlined"
                  rounded="lg"
                  hide-details
                  clearable
                  :hide-no-data="false"
                  :menu-props="{ maxHeight: 280 }"
                >
                  <template #no-data>
                    <v-list-item>
                      <div class="text-body-2 text-medium-emphasis pa-2">
                        No matching unit — press <b>Enter</b> to use your own.
                      </div>
                    </v-list-item>
                  </template>
                </v-combobox>

                <v-btn
                  class="rfq-line-remove"
                  icon="mdi-close"
                  variant="text"
                  color="error"
                  size="small"
                  :disabled="form.items.length <= 1"
                  title="Remove line"
                  @click="removeItem(i)"
                />
              </div>

              <div class="d-flex flex-wrap align-center justify-space-between mt-2" style="gap:8px">
                <v-btn
                  variant="tonal"
                  color="purple"
                  size="small"
                  rounded="lg"
                  class="text-none"
                  prepend-icon="mdi-plus"
                  @click="addItem"
                >Add item</v-btn>
                <span class="text-caption text-medium-emphasis rfq-items-hint">
                  <v-icon size="13">mdi-information-outline</v-icon>
                  Start typing to search the catalog · type anything else and press <b>Enter</b> to add it manually
                </span>
              </div>
            </div>
          </v-card>

          <v-alert v-if="error" type="error" variant="tonal" density="compact" rounded="lg" class="mb-3">
            {{ error }}
          </v-alert>
        </v-col>

        <!-- ═══════════════ SUMMARY ═══════════════ -->
        <v-col cols="12" lg="4">
          <div class="rfq-summary-sticky">
            <v-card rounded="lg" elevation="0" class="rfq-card">
              <div class="rfq-section-head">
                <span class="rfq-step">✓</span>
                <div>
                  <div class="rfq-section-title">Request summary</div>
                  <div class="rfq-section-sub">Review before inviting suppliers</div>
                </div>
              </div>
              <v-divider />

              <div class="pa-4 d-flex flex-column" style="gap:12px">
                <div class="rfq-summary-row">
                  <span class="rfq-summary-label"><v-icon size="15" class="mr-2">mdi-package-variant-closed</v-icon>Items</span>
                  <span class="rfq-summary-value">{{ validItems.length }}</span>
                </div>
                <div class="rfq-summary-row">
                  <span class="rfq-summary-label"><v-icon size="15" class="mr-2">mdi-counter</v-icon>Total quantity</span>
                  <span class="rfq-summary-value">{{ totalQty }}</span>
                </div>
                <div class="rfq-summary-row">
                  <span class="rfq-summary-label"><v-icon size="15" class="mr-2">mdi-store-marker</v-icon>Branch</span>
                  <span class="rfq-summary-value">{{ branchLabel || '—' }}</span>
                </div>
                <div class="rfq-summary-row">
                  <span class="rfq-summary-label"><v-icon size="15" class="mr-2">mdi-calendar-clock</v-icon>Deadline</span>
                  <span class="rfq-summary-value">{{ deadlinePreview }}</span>
                </div>
                <div class="rfq-summary-row">
                  <span class="rfq-summary-label"><v-icon size="15" class="mr-2">mdi-truck-clock-outline</v-icon>Expected delivery</span>
                  <span class="rfq-summary-value">{{ form.expected_delivery ? formatDate(form.expected_delivery) : '—' }}</span>
                </div>
              </div>

              <v-divider />

              <div class="pa-4 d-flex flex-column" style="gap:8px">
                <div class="rfq-check" :class="{ 'rfq-check--ok': !!form.title.trim() }">
                  <v-icon size="16">{{ form.title.trim() ? 'mdi-check-circle' : 'mdi-circle-outline' }}</v-icon>
                  <span>Request title</span>
                </div>
                <div class="rfq-check" :class="{ 'rfq-check--ok': form.branch != null }">
                  <v-icon size="16">{{ form.branch != null ? 'mdi-check-circle' : 'mdi-circle-outline' }}</v-icon>
                  <span>Branch selected</span>
                </div>
                <div class="rfq-check" :class="{ 'rfq-check--ok': validItems.length > 0 }">
                  <v-icon size="16">{{ validItems.length ? 'mdi-check-circle' : 'mdi-circle-outline' }}</v-icon>
                  <span>At least one item line</span>
                </div>
                <div class="rfq-check" :class="{ 'rfq-check--ok': !!form.response_deadline }">
                  <v-icon size="16">{{ form.response_deadline ? 'mdi-check-circle' : 'mdi-circle-outline' }}</v-icon>
                  <span>Response deadline (recommended)</span>
                </div>
              </div>

              <v-divider />

              <div class="pa-4">
                <v-btn
                  color="purple"
                  variant="flat"
                  rounded="lg"
                  class="text-none w-100"
                  prepend-icon="mdi-send-check"
                  size="large"
                  block
                  :loading="saving"
                  :disabled="!canSubmit"
                  @click="save"
                >Create &amp; open RFQ</v-btn>
                <div class="text-caption text-medium-emphasis text-center mt-2">
                  You can review, edit quotes and award from the next screen.
                </div>
              </div>
            </v-card>
          </div>
        </v-col>
      </v-row>
    </v-form>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { useRoute } from 'vue-router'
import { useBranchStore } from '~/stores/branch'
import { useBranding } from '~/composables/useBranding'
import { formatDate } from '~/utils/format'

const { $api } = useNuxtApp()
const route = useRoute()
const brand = useBranding()
const branchStore = useBranchStore()

const saving = ref(false)
const error = ref('')
const prefillNotice = ref('')

// Distinct from `form` — `<script setup>` resolves `ref="..."` against the
// setup bindings, so a template ref named `form` would overwrite the reactive
// form object and freeze the page in a render loop.
const formRef = ref(null)

/**
 * Namespace prefix so the page works under /ims/ and /pharmacy/ as well as the
 * bare /purchase-orders tree without relying on a middleware redirect.
 */
const ns = computed(() => {
  const p = route.path
  if (p.startsWith('/ims')) return '/ims'
  if (p.startsWith('/pharmacy')) return '/pharmacy'
  return ''
})

// Tenant palette → hero CSS variables (same bridge as the RFQ list/detail).
const heroTheme = computed(() => ({
  '--hero-deep': brand.secondary.value,
  '--hero-main': brand.primary.value,
  '--hero-accent': brand.gradientStops.value[2],
  '--hero-ink': brand.ink.value,
  '--hero-glow': brand.tint('primary', 0.3),
  '--hero-glow-2': brand.tint('accent', 0.2),
  '--hero-shadow': brand.shadow.value
}))

/** A fresh, empty line item. `pick` backs the combobox widget only. */
function blankItem() {
  return { pick: null, name: '', qty: 1, unit: '', source: '', catalogLabel: '' }
}

const form = ref({
  title: '',
  description: '',
  expected_delivery: '',
  response_deadline: '',
  branch: null,
  items: [blankItem()]
})

// ── Quick-select request types ──────────────────────────────────────────
// Picking a chip writes the title and seeds the requirements text. The
// description is only overwritten when it is blank or was itself produced by
// an earlier preset, so hand-written requirements are never lost.
const titlePresets = [
  {
    label: 'Consumables replenishment',
    icon: 'mdi-package-variant-closed',
    title: 'Monthly consumables replenishment',
    description:
      'Routine consumable replenishment for the current cycle. Deliver in sealed, clearly labelled cartons showing batch numbers and expiry dates. Quantities must match the requested lines exactly; partial deliveries must be agreed in writing beforehand.'
  },
  {
    label: 'Pharmaceutical restock',
    icon: 'mdi-pill',
    title: 'Pharmaceutical restocking',
    description:
      'Restock fast-moving pharmaceuticals. Supply genuine, registered products only, with a minimum of 18 months shelf life remaining on delivery. Include batch numbers, expiry dates and certificates of analysis with each shipment.'
  },
  {
    label: 'Surgical & dressings',
    icon: 'mdi-medical-bag',
    title: 'Surgical supplies and dressings',
    description:
      'Surgical consumables and dressings for theatre and ward use. Sterile packaging is mandatory with full lot traceability. State brand, size and pack configuration for every quoted line.'
  },
  {
    label: 'PPE & infection control',
    icon: 'mdi-shield-check-outline',
    title: 'PPE and infection-control supplies',
    description:
      'Personal protective equipment and infection-control consumables. All items must be CE / ISO certified; provide certification with the quote. Sizes and pack quantities as per the requested lines.'
  },
  {
    label: 'Lab reagents',
    icon: 'mdi-test-tube',
    title: 'Laboratory reagents and consumables',
    description:
      'Laboratory reagents, controls and disposable consumables. Provide certificates of analysis and confirm cold-chain handling where applicable. Quote shelf life remaining for every line.'
  },
  {
    label: 'Packaging materials',
    icon: 'mdi-package-variant',
    title: 'Packaging and labelling materials',
    description:
      'Cartons, labels and packaging consumables for dispatch. Materials must be print-ready and support barcode labelling. Confirm carton dimensions, board grade and minimum order quantities.'
  },
  {
    label: 'Equipment spares',
    icon: 'mdi-cog-outline',
    title: 'Equipment spares and maintenance parts',
    description:
      'Spare parts and maintenance consumables for warehouse and dispensing equipment. Quote genuine or OEM-equivalent parts, state warranty terms and expected lead time per line.'
  },
  {
    label: 'Office & operations',
    icon: 'mdi-office-building-outline',
    title: 'Office and operational supplies',
    description:
      'Routine office and operational supplies. Delivery to the receiving bay during working hours; include delivery charges in the quoted total and state the expected lead time.'
  }
]

const activePresetKey = computed(() => {
  const title = (form.value.title || '').trim()
  if (!title) return ''
  return titlePresets.find((p) => p.title === title)?.label || ''
})

const presetNotice = ref('')

function applyPreset(preset) {
  form.value.title = preset.title
  const current = (form.value.description || '').trim()
  const wasAutoFilled = titlePresets.some((p) => p.description.trim() === current)
  if (!current || wasAutoFilled) {
    form.value.description = preset.description
    presetNotice.value = 'Title and requirements applied — edit them to match this request.'
  } else {
    presetNotice.value = 'Title applied. Your existing requirements text was kept.'
  }
}

// ── Catalog vs manual item tracking ─────────────────────────────────────
const catalogCount = computed(() => form.value.items.filter((i) => i.source === 'catalog').length)
const manualCount = computed(() => form.value.items.filter((i) => i.source === 'manual').length)

/**
 * Commits typed text as a custom line item. Used by both the explicit
 * "Add … as a manual item" row in the dropdown and the Enter key path.
 */
function commitManual(item, text) {
  const value = String(text || '').trim()
  if (!value) return
  item.pick = value
  item.name = value
  item.source = 'manual'
  item.catalogLabel = ''
  itemSearchResults.value = []
  itemSearchQuery.value = ''
  if (import.meta.client) document.activeElement?.blur?.()
}

const branchOptions = computed(() =>
  branchStore.activeBranches.map((b) => ({ label: b.name, value: b.id }))
)
const branchLabel = computed(() => {
  const found = branchOptions.value.find((b) => b.value === form.value.branch)
  return found?.label || ''
})

// ── Derived summary / validation ────────────────────────────────────────
const validItems = computed(() =>
  form.value.items.filter((i) => String(i.name || '').trim())
)
const totalQty = computed(() =>
  validItems.value.reduce((n, i) => n + (Number(i.qty) > 0 ? Number(i.qty) : 0), 0)
)
const canSubmit = computed(
  () =>
    !!String(form.value.title || '').trim() &&
    form.value.branch != null &&
    validItems.value.length > 0
)

const deadlinePreview = computed(() => {
  if (!form.value.response_deadline) return 'No deadline set'
  const parsed = new Date(`${form.value.response_deadline}T00:00:00`)
  if (Number.isNaN(parsed.getTime())) return 'No deadline set'
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  const days = Math.round((parsed - today) / 86400000)
  if (days < 0) return `${Math.abs(days)}d overdue`
  if (days === 0) return 'Due today'
  return `${days} day${days === 1 ? '' : 's'} to respond`
})

const deadlinePresets = [
  { label: '3 days', days: 3 },
  { label: '1 week', days: 7 },
  { label: '2 weeks', days: 14 },
  { label: '30 days', days: 30 }
]

function setDeadline(days) {
  const d = new Date()
  d.setDate(d.getDate() + days)
  form.value.response_deadline = d.toISOString().slice(0, 10)
}

// ── Units of measure ──
// Sourced from the tenant's own unit list (`/inventory/units/`, the same
// lookup the medications and stock pages use). A combobox rather than a plain
// select, so a unit that isn't registered can still be typed in by hand.
const unitOptions = ref([])

async function loadUnits() {
  try {
    const { data } = await $api.get('/inventory/units/', { params: { page_size: 1000 } })
    const rows = data?.results || data || []
    unitOptions.value = rows.map((u) => u.name).filter(Boolean)
  } catch {
    unitOptions.value = []
  }
}

// ── Medication catalog search ───────────────────────────────────────────
// One shared result list (mirrors PurchaseOrderForm). The combobox allows free
// text, so an unmatched query simply becomes a manual item on Enter.
const itemSearchResults = ref([])
const itemSearching = ref(false)
const itemSearchQuery = ref('')
let itemSearchTimer = null

function addItem() {
  form.value.items.push(blankItem())
}

function removeItem(i) {
  if (form.value.items.length <= 1) return
  form.value.items.splice(i, 1)
}

async function onItemSearch(query) {
  itemSearchQuery.value = query || ''
  clearTimeout(itemSearchTimer)
  if (!query || query.trim().length < 2) {
    itemSearchResults.value = []
    return
  }
  // Debounce so we don't hit the API on every keystroke.
  itemSearchTimer = setTimeout(async () => {
    itemSearching.value = true
    try {
      const { data } = await $api.get('/medications/search/', {
        params: { q: query.trim() }
      })
      itemSearchResults.value = dedupeCatalog(data?.results || data || [])
    } catch {
      itemSearchResults.value = []
    } finally {
      itemSearching.value = false
    }
  }, 300)
}

/**
 * The catalog can contain several rows with an identical `label` (the same
 * generic/strength/form registered more than once). Left in, Vuetify warns
 * "Multiple nodes with the same ID" and the dropdown shows confusing repeats,
 * so collapse them by id and then by label.
 */
function dedupeCatalog(rows) {
  const byId = new Map()
  for (const row of rows) {
    const key = row.id != null ? 'id:' + row.id : 'label:' + (row.label || row.generic_name || '')
    if (!byId.has(key)) byId.set(key, row)
  }
  const byLabel = new Map()
  for (const row of byId.values()) {
    const label = row.label || row.generic_name || ''
    if (!byLabel.has(label)) byLabel.set(label, row)
  }
  return [...byLabel.values()]
}

/**
 * Handles both a catalog pick (object) and free text (string).
 * Either way `item.name` is the field we submit; `item.source` only drives
 * UI hints (catalog badge vs manual badge) and is never sent to the API.
 *
 * A combobox emits its model value on every keystroke, so a plain string is
 * NOT treated as a committed manual entry here — that would badge a line as
 * "manual" while the user is still typing a catalog search. Commit happens on
 * Enter, blur, or the explicit "Add … as a manual item" row.
 */
function onPickItem(item, value) {
  if (value && typeof value === 'object') {
    item.name = value.label || value.generic_name || ''
    item.catalogLabel = item.name
    item.source = 'catalog'
    // Pre-fill the unit from the catalog; the user can still change it.
    if (value.unit) item.unit = value.unit
  } else if (typeof value === 'string') {
    item.name = value.trim()
    // Typing over a catalog selection downgrades it to a custom line.
    if (item.source === 'catalog' && item.name !== item.catalogLabel) item.source = ''
  } else {
    item.name = ''
    item.source = ''
    item.catalogLabel = ''
  }
}

/** Enter on free text commits the typed name as a manual item. */
function onItemEnter(item) {
  const text = typeof item.pick === 'string' ? item.pick.trim() : ''
  if (!text) return
  const exactMatch = itemSearchResults.value.some(
    (r) => String(r.label || '').toLowerCase() === text.toLowerCase()
  )
  if (!exactMatch) {
    item.name = text
    item.source = 'manual'
  }
}

/** Blur finalises the source badge for whatever the field ended up holding. */
function onItemBlur(item) {
  if (item.pick && typeof item.pick === 'object') {
    item.source = 'catalog'
    return
  }
  const text = String(item.pick || '').trim()
  item.source = text ? 'manual' : ''
}

onBeforeUnmount(() => clearTimeout(itemSearchTimer))

/**
 * The procurement flows hand lines over through sessionStorage:
 *   - reorder suggestions store a bare array of { name, qty }
 *   - "Duplicate RFQ" (detail page) stores { title, description, branch, items }
 * Accept both shapes, pre-fill the builder once, then clear the key.
 */
function consumeDraft() {
  if (!import.meta.client) return
  const raw = sessionStorage.getItem('procurement.rfqDraft')
  if (!raw) return
  try {
    const parsed = JSON.parse(raw)
    const rows = Array.isArray(parsed) ? parsed : parsed?.items
    if (!Array.isArray(rows) || !rows.length) return

    form.value.items = rows.map((r) => {
      const name = r.name || r.itemName || ''
      return {
        // The combobox is bound to `pick`, so seed it with the text as well —
        // otherwise a prefilled line renders as an empty field.
        pick: name,
        name,
        qty: Number(r.qty) > 0 ? Number(r.qty) : 1,
        unit: r.unit || '',
        source: name ? 'manual' : '',
        catalogLabel: ''
      }
    })

    if (!Array.isArray(parsed)) {
      if (parsed.title) form.value.title = parsed.title
      if (parsed.description) form.value.description = parsed.description
      if (parsed.branch != null) form.value.branch = parsed.branch
      prefillNotice.value = 'Duplicated from an existing RFQ'
    } else {
      prefillNotice.value = `${rows.length} line${rows.length === 1 ? '' : 's'} from reorder suggestions`
    }
    sessionStorage.removeItem('procurement.rfqDraft')
  } catch {
    /* ignore malformed drafts */
  }
}

async function save() {
  error.value = ''
  if (!canSubmit.value) {
    error.value = 'Add a request title, choose a branch and include at least one item line.'
    return
  }
  const validation = await formRef.value?.validate()
  if (validation && validation.valid === false) return

  saving.value = true
  try {
    // Build items explicitly: the model stores them as a raw JSONField, so any
    // UI-only key (`pick`) spread in here would be persisted verbatim.
    const items = validItems.value.map((i) => ({
      name: String(i.name).trim(),
      qty: Number(i.qty) > 0 ? Number(i.qty) : 1,
      unit: String(i.unit || '').trim()
    }))

    const payload = {
      title: String(form.value.title).trim(),
      description: form.value.description,
      expected_delivery: form.value.expected_delivery || null,
      response_deadline: form.value.response_deadline || null,
      branch: form.value.branch,
      items
    }

    const { data } = await $api.post('/purchase-orders/rfqs/', payload)
    navigateTo(`${ns.value}/purchase-orders/rfqs/${data.id}`)
  } catch (e) {
    const detail = e?.response?.data
    error.value = 'Failed: ' + (detail?.detail || (detail ? JSON.stringify(detail) : e.message))
  } finally {
    saving.value = false
  }
}

onMounted(async () => {
  consumeDraft()
  await Promise.all([branchStore.load(), loadUnits(), brand.load()])
  // Convenience for single-branch tenants: pre-select the only option.
  if (form.value.branch == null && branchStore.activeBranches.length === 1) {
    form.value.branch = branchStore.activeBranches[0].id
  }
})
</script>

<style scoped>
/* ═══════════════ Hero ═══════════════ */
.rfq-hero {
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
.rfq-glow {
  position: absolute;
  width: 340px;
  height: 340px;
  border-radius: 50%;
  right: -110px;
  top: -170px;
  background: radial-gradient(circle, var(--hero-glow, rgba(255, 255, 255, 0.28)), transparent 68%);
  pointer-events: none;
}
.rfq-glow-2 {
  right: auto;
  left: -140px;
  top: auto;
  bottom: -220px;
  width: 300px;
  height: 300px;
  background: radial-gradient(circle, var(--hero-glow-2, rgba(55, 214, 255, 0.24)), transparent 70%);
}
.rfq-hero-top {
  position: relative;
}
.rfq-hero-icon {
  width: 56px;
  height: 56px;
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.16);
  border: 1px solid rgba(255, 255, 255, 0.28);
  backdrop-filter: blur(6px);
  flex-shrink: 0;
}
.rfq-eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: rgba(255, 255, 255, 0.78);
}
.rfq-title {
  font-size: 25px;
  line-height: 1.15;
  font-weight: 800;
  letter-spacing: -0.2px;
  margin: 2px 0;
}
.rfq-sub {
  font-size: 13px;
  color: rgba(255, 255, 255, 0.82);
}
.rfq-btn-strong {
  background: #ffffff !important;
  color: var(--hero-ink, #143ce1) !important;
  font-weight: 700 !important;
  border: 1px solid rgba(255, 255, 255, 0.95) !important;
  box-shadow: 0 6px 18px rgba(6, 44, 40, 0.28) !important;
}
.rfq-btn-strong:hover {
  background: #ffffff !important;
  filter: brightness(0.94);
}
.rfq-btn-strong :deep(.v-icon) {
  color: var(--hero-ink, #143ce1) !important;
  opacity: 1 !important;
}
.rfq-btn-glass {
  background: rgba(255, 255, 255, 0.16) !important;
  color: #ffffff !important;
  font-weight: 600 !important;
  border: 1px solid rgba(255, 255, 255, 0.34) !important;
  backdrop-filter: blur(6px);
}
.rfq-btn-glass:hover {
  background: rgba(255, 255, 255, 0.26) !important;
  border-color: rgba(255, 255, 255, 0.6) !important;
}
.rfq-btn-glass :deep(.v-icon) {
  color: #ffffff !important;
  opacity: 1 !important;
}
.rfq-hero-foot {
  position: relative;
  margin-top: 14px;
  padding-top: 12px;
  border-top: 1px solid rgba(255, 255, 255, 0.2);
}
.rfq-hero-chip {
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

/* ═══════════════ Sections ═══════════════ */
.rfq-card {
  border: 1px solid rgba(15, 23, 42, 0.08) !important;
  background: rgb(var(--v-theme-surface));
}
.rfq-section-head {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 14px 16px;
}
.rfq-step {
  width: 34px;
  height: 34px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-size: 12px;
  font-weight: 800;
  color: rgba(var(--v-theme-on-surface), 0.55);
  background: rgba(15, 23, 42, 0.05);
  border: 1px solid rgba(15, 23, 42, 0.07);
}
.rfq-section-title {
  font-size: 15px;
  font-weight: 700;
  line-height: 1.2;
}
.rfq-section-sub {
  font-size: 12px;
  color: rgba(var(--v-theme-on-surface), 0.55);
}

/* ═══════════════ Quick-select presets ═══════════════ */
.rfq-presets {
  border: 1px dashed rgba(15, 23, 42, 0.14);
  border-radius: 12px;
  padding: 10px 12px;
  background: rgba(var(--v-theme-primary), 0.025);
}
.rfq-presets-label {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 5px;
  margin-bottom: 8px;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.4px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.6);
}
.rfq-presets-label .text-medium-emphasis {
  font-weight: 500;
  letter-spacing: 0;
  text-transform: none;
}
.rfq-presets-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.rfq-preset-chip {
  cursor: pointer;
  transition: transform 0.15s ease;
}
.rfq-preset-chip:hover {
  transform: translateY(-1px);
}
.rfq-preset-note {
  display: flex;
  align-items: center;
  gap: 5px;
  padding-top: 8px;
  font-size: 11.5px;
  color: rgba(var(--v-theme-on-surface), 0.6);
}

/* ═══════════════ Item lines ═══════════════ */
.rfq-line-head,
.rfq-line {
  display: grid;
  grid-template-columns: 44px minmax(0, 2.4fr) 90px minmax(0, 1fr) 40px;
  gap: 10px;
  align-items: center;
}
.rfq-line-head {
  padding: 0 2px 6px;
  font-size: 10.5px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: rgba(var(--v-theme-on-surface), 0.5);
}
.rfq-line + .rfq-line {
  margin-top: 8px;
}
.rfq-line-index {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1px;
  font-size: 11px;
  font-weight: 800;
  color: rgba(var(--v-theme-on-surface), 0.4);
  text-align: center;
}
.rfq-line-remove {
  justify-self: center;
}
.rfq-manual-option {
  cursor: pointer;
}
.rfq-manual-hint {
  display: flex;
  align-items: center;
  gap: 5px;
  padding: 2px 12px 6px 46px;
  font-size: 11px;
  color: rgba(var(--v-theme-on-surface), 0.5);
}
.rfq-items-hint {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  flex-wrap: wrap;
}

/* ═══════════════ Summary ═══════════════ */
.rfq-summary-sticky {
  position: sticky;
  top: 16px;
}
.rfq-summary-row {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  font-size: 13px;
}
.rfq-summary-label {
  display: inline-flex;
  align-items: center;
  color: rgba(var(--v-theme-on-surface), 0.58);
  white-space: nowrap;
}
.rfq-summary-value {
  font-weight: 600;
  text-align: right;
  overflow-wrap: anywhere;
}
.rfq-check {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12.5px;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.rfq-check--ok {
  color: #15803d;
}
.rfq-preset {
  cursor: pointer;
}

@media (max-width: 700px) {
  .rfq-title {
    font-size: 21px;
  }
  .rfq-line-head {
    display: none;
  }
  .rfq-line {
    grid-template-columns: 30px 1fr 1fr;
    grid-template-areas:
      'idx name name'
      'idx qty unit'
      'idx remove remove';
    row-gap: 8px;
    padding-bottom: 10px;
    border-bottom: 1px dashed rgba(15, 23, 42, 0.09);
  }
  .rfq-line-index { grid-area: idx; }
  .rfq-line-name { grid-area: name; }
  .rfq-line-qty { grid-area: qty; }
  .rfq-line-unit { grid-area: unit; }
  .rfq-line-remove {
    grid-area: remove;
    justify-self: end;
  }
}
</style>
