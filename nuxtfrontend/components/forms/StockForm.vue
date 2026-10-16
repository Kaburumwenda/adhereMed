<template>
  <ResourceFormPage
    :resource="r"
    :title="loadId ? 'Edit Stock Item' : 'New Stock Item'"
    :subtitle="loadId ? 'Update inventory details and stock levels' : 'Register a new item in your inventory'"
    icon="mdi-package-variant-plus"
    back-path="/inventory"
    :load-id="loadId"
    :initial="initial"
    :transform="transformPayload"
    max-width="90%"
    hero
    flat
    :eyebrow="loadId ? 'Inventory · Edit item' : 'Inventory · New item'"
    @saved="onSaved"
  >
    <template #default="{ form }">
      <ClientOnly>
        <span v-if="autofill(form)" />
        <span v-if="syncEdit(form)" />
      </ClientOnly>

      <!-- ── Section 1 · Item Details ─────────────────────── -->
      <div class="stock-section">
        <div class="stock-section__header">
          <div class="stock-section__icon bg-primary">
            <v-icon size="18" color="white">mdi-tag-outline</v-icon>
          </div>
          <div>
            <div class="stock-section__title">Item Details</div>
            <div class="stock-section__sub">Name, code, and classification</div>
          </div>
          <span class="stock-section__step">01</span>
        </div>
        <v-row>
          <v-col cols="12">
            <v-combobox
              v-model="brandSelection"
              :items="catalogResults"
              :item-title="item => typeof item === 'string' ? item : (Array.isArray(item.brand_names) ? (item.brand_names[0] || item.generic_name) : (item.brand_names || item.generic_name))"
              :item-value="item => typeof item === 'string' ? item : (Array.isArray(item.brand_names) ? (item.brand_names[0] || '') : (item.brand_names || ''))"
              :search="brandQuery"
              :loading="catalogLoading"
              label="Brand / Trade Name *"
              hint="Search by brand or generic name (e.g. Panadol, paracetamol)"
              persistent-hint
              :rules="req"
              variant="outlined"
              density="comfortable"
              rounded="lg"
              no-filter
              clearable
              return-object
              placeholder="Search brand or generic name from catalog..."
              :disabled="formDisabled"
              prepend-inner-icon="mdi-tag-text-outline"
              @update:search="onBrandSearch"
              @update:model-value="onBrandSelected($event, form)"
            >
              <template #no-data><div /></template>
              <template #item="{ item, props: ip }">
                <v-list-item v-bind="ip" :title="undefined" :subtitle="undefined">
                  <template #prepend>
                    <v-icon size="18" color="primary">mdi-tag-text-outline</v-icon>
                  </template>
                  <template #title>{{ Array.isArray(item.raw?.brand_names) ? (item.raw.brand_names.join(', ') || item.raw?.generic_name) : (item.raw?.brand_names || item.raw?.generic_name || item.title) }}</template>
                  <template #subtitle>{{ [item.raw?.generic_name, item.raw?.strength, item.raw?.dosage_form].filter(Boolean).join(' · ') || 'Catalog item' }}</template>
                </v-list-item>
              </template>
            </v-combobox>

            <!-- Not in catalog warning -->
            <v-alert v-if="showNotInCatalog && !loadId" type="warning" variant="tonal" rounded="lg" class="mt-n2 mb-2">
              <template #prepend><v-icon size="18">mdi-alert-outline</v-icon></template>
              <div class="text-body-2">"<strong>{{ brandQuery }}</strong>" is not in the medication catalog. Please add it to the catalog first.</div>
              <div class="d-flex ga-2 mt-3">
                <v-btn size="small" variant="flat" color="warning" rounded="lg" class="text-none" prepend-icon="mdi-book-plus-outline" @click="router.push(catalogPath)">
                  Go to Catalog
                </v-btn>
              </div>
            </v-alert>
          </v-col>
        </v-row>
        <v-row>
          <v-col cols="12" md="6">
            <v-text-field
              v-model="form.medication_name"
              label="Medication Name *"
              hint="Auto-generated: Brand + Strength + Dosage Form"
              persistent-hint
              :rules="req"
              variant="outlined"
              density="comfortable"
              rounded="lg"
              readonly
              placeholder="Select a brand to auto-fill"
              :disabled="formDisabled"
              prepend-inner-icon="mdi-pill"
            />

            <!-- Duplicate warning (branch-specific) -->
            <v-alert v-if="existingStock && !loadId" type="warning" variant="tonal" rounded="lg" class="mt-n2 mb-2">
              <template #prepend><v-icon size="18">mdi-alert-circle-outline</v-icon></template>
              <div class="text-body-2">
                <strong>{{ existingStock.medication_name }}</strong> already exists in this warehouse
                <span v-if="existingStock.total_quantity != null" class="text-medium-emphasis">
                  · {{ existingStock.total_quantity }} in stock
                </span>
              </div>
              <div class="text-body-2 text-medium-emphasis mt-1">Choose a different warehouse, or edit the existing item.</div>
              <div class="d-flex ga-2 mt-3">
                <v-btn size="small" variant="flat" color="primary" rounded="lg" class="text-none" prepend-icon="mdi-pencil-outline" @click="goEditExisting">
                  Edit Existing Item
                </v-btn>
                <v-btn size="small" variant="tonal" color="primary" rounded="lg" class="text-none" prepend-icon="mdi-swap-vertical" @click="goAdjust">
                  Stock Adjustment
                </v-btn>
              </div>
            </v-alert>
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.barcode" :label="loadId ? 'Barcode / SKU *' : 'SKU / Code *'" :placeholder="loadId ? 'Enter barcode' : 'Auto-generated'" :persistent-hint="!loadId" :hint="loadId ? '' : 'Generated automatically'" :rules="req" variant="outlined" density="comfortable" rounded="lg" :disabled="formDisabled">
              <template #append-inner>
                <v-tooltip v-if="!loadId" text="Regenerate SKU" location="top">
                  <template #activator="{ props: tp }">
                    <v-btn v-bind="tp" icon="mdi-refresh" variant="text" density="comfortable" size="small" @click="form.barcode = generateSku()" />
                  </template>
                </v-tooltip>
              </template>
            </v-text-field>
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.generic_name" label="Generic Name *" placeholder="e.g. paracetamol" hint="Generic / INN name" persistent-hint :rules="req" variant="outlined" density="comfortable" rounded="lg" clearable :disabled="formDisabled" prepend-inner-icon="mdi-pill" />
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.strength" label="Strength *" placeholder="e.g. 500mg, 5mg/5ml" hint="Concentration or strength" persistent-hint :rules="req" variant="outlined" density="comfortable" rounded="lg" clearable :disabled="formDisabled" prepend-inner-icon="mdi-scale-balance" />
          </v-col>
          <v-col cols="12" md="6">
            <v-select v-model="form.dosage_form" :items="dosageFormChoices" item-title="label" item-value="value" label="Dosage Form *" hint="Form of the medication" persistent-hint :rules="req" variant="outlined" density="comfortable" rounded="lg" clearable :disabled="formDisabled" prepend-inner-icon="mdi-format-list-bulleted-type" />
          </v-col>
          <v-col cols="12" md="6">
            <v-autocomplete v-model="form.category" :items="categories" item-title="name" item-value="id" label="Category *" :rules="req" variant="outlined" density="comfortable" rounded="lg" clearable :disabled="formDisabled" />
          </v-col>
          <v-col cols="12" md="6">
            <v-autocomplete
              v-model="form.classification"
              :items="classifications"
              item-title="name" item-value="id"
              label="Classification *"
              hint="Operational group (Routine, Emergency, Cold Chain, …) — defaults to Routine"
              persistent-hint
              :rules="req"
              variant="outlined" density="comfortable" rounded="lg"
              clearable :disabled="formDisabled"
              prepend-inner-icon="mdi-label-multiple-outline"
            >
              <template #item="{ props: ip, item }">
                <v-list-item v-bind="ip" :title="item.raw?.name" :subtitle="item.raw?.description">
                  <template #prepend>
                    <v-icon size="18" color="primary">mdi-label-multiple-outline</v-icon>
                  </template>
                </v-list-item>
              </template>
            </v-autocomplete>
          </v-col>
          <v-col cols="12" md="6">
            <v-autocomplete
              v-model="form.unit"
              :items="units"
              item-title="name"
              item-value="id"
              label="Unit of Measure *"
              :rules="req"
              variant="outlined"
              density="comfortable"
              rounded="lg"
              clearable
              :disabled="formDisabled"
              prepend-inner-icon="mdi-ruler-square-compass"
            >
              <template #append-item>
                <v-divider />
                <v-list-item @click="unitDialog = true" class="bg-blue-lighten-5" base-color="primary">
                  <template #prepend>
                    <v-icon size="18" color="primary">mdi-plus-circle-outline</v-icon>
                  </template>
                  <v-list-item-title class="font-weight-medium text-primary">Manage Units</v-list-item-title>
                </v-list-item>
              </template>
            </v-autocomplete>
          </v-col>
          <v-col v-if="isContainerUnit" cols="12" md="6">
            <v-text-field
              v-model.number="form.items_per_unit"
              type="number" min="1" step="1"
              :label="`Items per ${selectedUnitName} *`"
              :hint="`How many individual items are inside one ${selectedUnitName} of this stock item`"
              persistent-hint
              variant="outlined" density="comfortable" rounded="lg"
              :rules="[v => (v !== null && v !== '' && v !== undefined && Number(v) > 0) || 'Required']"
              :disabled="formDisabled"
              prepend-inner-icon="mdi-package-variant"
            />
          </v-col>
          <v-col cols="12" md="6">
            <v-autocomplete v-model="form.branch" :items="branches" item-title="name" item-value="id" label="Branch *" variant="outlined" density="comfortable" rounded="lg" :rules="[v => !!v || 'Warehouse is required']" :disabled="branchLocked || (loadId ? formDisabled : false)" :readonly="branchLocked" prepend-inner-icon="mdi-store-outline" :hint="branchLocked ? 'Assigned to your branch' : 'Warehouse this stock item belongs to (required)'" persistent-hint />
            <!-- Reminder when duplicate exists in this branch -->
            <div v-if="existingStock && !loadId" class="text-caption text-error mt-1 d-flex align-center">
              <v-icon size="14" class="mr-1">mdi-information-outline</v-icon>
              Already exists in this warehouse — switch warehouse or edit existing.
            </div>
          </v-col>
          <v-col cols="12" md="6" class="d-flex align-center">
            <v-switch
              v-model="form.is_active"
              :label="form.is_active ? 'Active' : 'Inactive'"
              color="success"
              density="comfortable"
              hide-details
              inset
              :disabled="formDisabled"
            />
          </v-col>
        </v-row>
      </div>

      <!-- ── Section 2 · Stock Levels ─────────────────────── -->
      <div class="stock-section">
        <div class="stock-section__header">
          <div class="stock-section__icon bg-teal">
            <v-icon size="18" color="white">mdi-cube-outline</v-icon>
          </div>
          <div>
            <div class="stock-section__title">Stock Levels</div>
            <div class="stock-section__sub">Quantity and reorder thresholds</div>
          </div>
          <span class="stock-section__step">02</span>
          <v-chip size="x-small" variant="tonal" color="teal" class="ml-auto" label>
            <v-icon start size="12">mdi-auto-fix</v-icon> Auto-calculated
          </v-chip>
        </div>
        <div class="stock-subpanel">
          <v-row>
            <v-col cols="12" sm="4">
              <v-text-field v-model.number="form.quantity" :label="(loadId ? 'Current Stock Qty' : 'Initial Quantity') + ' *'" type="number" min="0" :rules="reqNum" :hint="loadId ? 'Edits create a Count Correction' : 'Stock on hand'" persistent-hint variant="outlined" density="comfortable" rounded="lg" :disabled="formDisabled" @update:model-value="recalc(form, $event)" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model.number="form.reorder_level" label="Reorder Level" type="number" min="0" :hint="levelTouched ? 'Custom value' : 'Auto: 30 % of qty'" persistent-hint variant="outlined" density="comfortable" rounded="lg" :disabled="formDisabled" @update:model-value="levelTouched = true">
                <template #append-inner>
                  <v-tooltip text="Reset to 30% of quantity" location="top">
                    <template #activator="{ props: tp }">
                      <v-btn v-bind="tp" icon="mdi-refresh" variant="text" density="comfortable" size="small" @click="resetLevel(form)" />
                    </template>
                  </v-tooltip>
                </template>
              </v-text-field>
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model.number="form.reorder_quantity" label="Reorder Quantity" type="number" min="0" :hint="qtyTouched ? 'Custom value' : 'Auto: 50 % of qty'" persistent-hint variant="outlined" density="comfortable" rounded="lg" :disabled="formDisabled" @update:model-value="qtyTouched = true">
                <template #append-inner>
                  <v-tooltip text="Reset to 50% of quantity" location="top">
                    <template #activator="{ props: tp }">
                      <v-btn v-bind="tp" icon="mdi-refresh" variant="text" density="comfortable" size="small" @click="resetQty(form)" />
                    </template>
                  </v-tooltip>
                </template>
              </v-text-field>
            </v-col>
          </v-row>
        </div>
      </div>

      <!-- ── Section 3 · Pricing ──────────────────────────── -->
      <div class="stock-section">
        <div class="stock-section__header">
          <div class="stock-section__icon bg-amber-darken-1">
            <v-icon size="18" color="white">mdi-cash-register</v-icon>
          </div>
          <div>
            <div class="stock-section__title">Pricing</div>
            <div class="stock-section__sub">Cost, selling price, and discounts</div>
          </div>
          <span class="stock-section__step">03</span>
        </div>
        <v-row>
          <v-col cols="12" sm="3">
            <v-text-field v-model.number="form.cost_price" label="Unit Cost (Before Tax) *" type="number" step="0.01" :rules="reqNum" variant="outlined" density="comfortable" rounded="lg" :disabled="formDisabled" />
          </v-col>
          <v-col cols="12" sm="3">
            <v-text-field v-model.number="form.tax_percent" label="VAT / Tax" type="number" min="0" max="100" step="0.01" suffix="%" hint="Applied on cost price" persistent-hint variant="outlined" density="comfortable" rounded="lg" :disabled="formDisabled" />
          </v-col>
          <v-col cols="12" sm="3">
            <v-text-field v-model.number="form.selling_price" label="Selling Price *" type="number" step="0.01" variant="outlined" density="comfortable" rounded="lg" :rules="reqNum" :hint="taxHint(form)" persistent-hint :disabled="formDisabled" />
          </v-col>
          <v-col cols="12" sm="3">
            <v-text-field v-model.number="form.discount_percent" label="Default Discount" type="number" min="0" max="100" step="0.01" suffix="%" hint="Applied at POS" persistent-hint variant="outlined" density="comfortable" rounded="lg" :disabled="formDisabled" />
          </v-col>
        </v-row>

        <!-- Profit Analysis -->
        <v-card variant="tonal" :color="marginColor(form)" rounded="xl" class="pa-5 mt-3 profit-card" :class="'profit-card--' + marginColor(form)">
          <div class="d-flex align-center mb-4">
            <v-icon :color="marginColor(form)" size="22" class="mr-2">mdi-chart-line-variant</v-icon>
            <span class="text-subtitle-2 font-weight-bold text-uppercase" style="letter-spacing:.5px">Profit Analysis</span>
            <v-spacer />
            <v-chip size="x-small" variant="outlined" :color="marginColor(form)" label>
              <v-icon start size="12">mdi-autorenew</v-icon> Live
            </v-chip>
          </div>
          <v-row dense>
            <v-col cols="12" sm="3">
              <div class="profit-metric">
                <div class="profit-metric__label">Tax per unit</div>
                <div class="profit-metric__value">{{ formatMoney(taxPerUnit(form)) }}</div>
                <div class="profit-metric__hint">Cost incl. tax: {{ formatMoney(costWithTax(form)) }}</div>
              </div>
            </v-col>
            <v-col cols="12" sm="3">
              <div class="profit-metric">
                <div class="profit-metric__label">Margin per unit</div>
                <div class="profit-metric__value">{{ formatMoney(margin(form)) }}</div>
                <div v-if="(Number(form.discount_percent) || 0) > 0" class="profit-metric__hint">
                  After {{ Number(form.discount_percent).toFixed(1) }}% disc. ({{ formatMoney(effectivePrice(form)) }} ea)
                </div>
              </div>
            </v-col>
            <v-col cols="12" sm="3">
              <div class="profit-metric">
                <div class="profit-metric__label">Margin %</div>
                <div class="profit-metric__value">{{ marginPercent(form).toFixed(1) }}%</div>
              </div>
            </v-col>
            <v-col cols="12" sm="3">
              <div class="profit-metric">
                <div class="profit-metric__label">
                  Total profit
                  <span class="text-medium-emphasis">({{ Number(form.quantity) || 0 }} units)</span>
                </div>
                <div class="profit-metric__value">{{ formatMoney(totalProfit(form)) }}</div>
                <div v-if="(Number(form.tax_percent) || 0) > 0" class="profit-metric__hint">
                  Total tax: {{ formatMoney(taxPerUnit(form) * (Number(form.quantity) || 0)) }}
                </div>
                <div v-if="(Number(form.discount_percent) || 0) > 0" class="profit-metric__hint text-error">
                  − {{ formatMoney(discountAmount(form) * (Number(form.quantity) || 0)) }} discount
                </div>
              </div>
            </v-col>
          </v-row>
        </v-card>
      </div>

      <!-- ── Section 4 · Batch & Expiry ───────────────────── -->
      <div class="stock-section">
        <div class="stock-section__header">
          <div class="stock-section__icon bg-deep-purple">
            <v-icon size="18" color="white">mdi-barcode</v-icon>
          </div>
          <div>
            <div class="stock-section__title">Batch &amp; Expiry</div>
            <div class="stock-section__sub">Tracking and shelf life</div>
          </div>
          <span class="stock-section__step">04</span>
        </div>
        <v-row>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.batch_number" label="Batch Number" placeholder="Enter batch # or auto-generate" persistent-hint hint="Type a batch number or click the refresh icon to auto-generate" variant="outlined" density="comfortable" rounded="lg" clearable :disabled="formDisabled">
              <template #append-inner>
                <v-tooltip text="Auto-generate batch #" location="top">
                  <template #activator="{ props: tp }">
                    <v-btn v-bind="tp" icon="mdi-refresh" variant="text" density="comfortable" size="small" @click="form.batch_number = generateBatch()" />
                  </template>
                </v-tooltip>
              </template>
            </v-text-field>
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.expiry_date" label="Expiry Date" type="date" variant="outlined" density="comfortable" rounded="lg" hint="Default: 5 years from today. Change if needed." persistent-hint clearable :disabled="formDisabled" />
          </v-col>
        </v-row>
      </div>

      <!-- ── Section 5 · Additional Details ───────────────── -->
      <div class="stock-section">
        <div class="stock-section__header">
          <div class="stock-section__icon bg-blue-grey">
            <v-icon size="18" color="white">mdi-text-box-outline</v-icon>
          </div>
          <div>
            <div class="stock-section__title">Additional Details</div>
            <div class="stock-section__sub">Optional notes or description</div>
          </div>
          <span class="stock-section__step">05</span>
        </div>
        <v-row>
          <v-col cols="12">
            <v-textarea v-model="form.description" label="Description" rows="3" auto-grow variant="outlined" density="comfortable" rounded="lg" :disabled="formDisabled" />
          </v-col>
        </v-row>
      </div>
    </template>

    <!-- ── Manage Units Dialog ─────────────────────────── -->
    <template #below>
      <v-dialog v-model="unitDialog" max-width="500">
        <v-card rounded="xl">
          <v-card-title class="d-flex align-center">
            <v-icon class="mr-2" color="primary">mdi-ruler-square-compass</v-icon>
            Manage Units of Measure
          </v-card-title>
          <v-card-subtitle>Create a new unit (e.g. tablets, capsules, ml, mg)</v-card-subtitle>
          <v-card-text>
            <v-text-field
              v-model="unitForm.name"
              label="Unit Name *"
              placeholder="e.g. tablets, capsules, ml"
              variant="outlined"
              density="comfortable"
              rounded="lg"
              :rules="unitNameRules"
              class="mb-1"
            />
            <!-- Quick-pick suggestion chips -->
            <div class="d-flex flex-wrap ga-1 mb-3">
              <v-chip
                v-for="s in unitSuggestions"
                :key="s"
                size="x-small"
                variant="outlined"
                color="primary"
                label
                @click="pickUnitSuggestion(s)"
              >
                {{ s }}
              </v-chip>
            </div>
            <v-text-field
              v-model="unitForm.abbreviation"
              label="Abbreviation"
              placeholder="e.g. tab, cap, ml"
              variant="outlined"
              density="comfortable"
              rounded="lg"
            />
            <!-- List existing units -->
            <div class="text-caption text-medium-emphasis mb-1 mt-3">Existing Units</div>
            <v-chip-group column>
              <v-chip v-for="u in units" :key="u.id" size="small" variant="tonal" label>
                {{ u.name }}<span v-if="u.abbreviation" class="text-medium-emphasis ms-1">({{ u.abbreviation }})</span>
              </v-chip>
            </v-chip-group>
          </v-card-text>
          <v-card-actions class="pb-4 px-4">
            <v-spacer />
            <v-btn variant="text" rounded="lg" class="text-none" @click="closeUnitDialog">Cancel</v-btn>
            <v-btn
              color="primary"
              variant="flat"
              rounded="lg"
              class="text-none"
              prepend-icon="mdi-check"
              :loading="unitSaving"
              :disabled="!unitForm.name.trim()"
              @click="saveUnit"
            >
              Create Unit
            </v-btn>
          </v-card-actions>
          <v-snackbar
            v-model="unitSnackbar.show"
            :color="unitSnackbar.color"
            location="top right"
            timeout="3000"
          >
            {{ unitSnackbar.text }}
          </v-snackbar>
        </v-card>
      </v-dialog>
    </template>
  </ResourceFormPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatMoney } from '~/utils/format'
import { useBranchStore } from '~/stores/branch'
const route = useRoute(); const router = useRouter()
const { $api } = useNuxtApp()
// Inventory tenants use their own /ims routes & API namespace.
const { isInventory } = useTenantEndpoints()
const catalogPath = computed(() => isInventory.value ? '/ims/medications' : '/pharmacy/medications')
const branchStore = useBranchStore()
const branchLocked = computed(() => branchStore.branchLocked)
const loadId = computed(() => route.params.id || null)
const r = useResource('/inventory/stocks/')
const req = [v => !!v || 'Required']
const reqNum = [v => (v !== null && v !== '' && v !== undefined) || 'Required']

// ── Catalog search + duplicate detection ─────────────
const nameQuery = ref('')
const nameSelection = ref(null)
const brandQuery = ref('')
const brandSelection = ref(null)
const catalogResults = ref([])
const catalogLoading = ref(false)
const existingStock = ref(null)
const showNotInCatalog = ref(false)
let searchTimer = null

// Disable all fields when brand is not in catalog
const formDisabled = computed(() => !loadId.value && showNotInCatalog.value)

// ── Category / Unit mapping from Medication catalog ──
const MEDICATION_CATEGORY_LABELS = {
  analgesic: 'Analgesic / Pain Reliever', antibiotic: 'Antibiotic', antifungal: 'Antifungal',
  antiviral: 'Antiviral', antiparasitic: 'Antiparasitic', antimalarial: 'Antimalarial',
  antihypertensive: 'Antihypertensive', antidiabetic: 'Antidiabetic', antihistamine: 'Antihistamine',
  antacid: 'Antacid / GI', cardiovascular: 'Cardiovascular', respiratory: 'Respiratory',
  cns: 'Central Nervous System', hormone: 'Hormonal', vitamin: 'Vitamin / Supplement',
  vaccine: 'Vaccine', dermatological: 'Dermatological', ophthalmic: 'Ophthalmic',
  oncology: 'Oncology', immunosuppressant: 'Immunosuppressant', nsaid: 'NSAID', other: 'Other',
}

function matchCategory(catalogCategory) {
  if (!catalogCategory) return null
  const label = (MEDICATION_CATEGORY_LABELS[catalogCategory] || catalogCategory).toLowerCase()
  const key = catalogCategory.toLowerCase()
  return categories.value.find(c => {
    const n = c.name.toLowerCase()
    return n === key || n === label || n.includes(key) || label.includes(n)
  })?.id || null
}

function matchUnit(catalogUnit) {
  if (!catalogUnit) return null
  const u = catalogUnit.toLowerCase()
  return units.value.find(x => {
    const n = x.name.toLowerCase()
    const a = (x.abbreviation || '').toLowerCase()
    return n === u || a === u || n.includes(u) || u.includes(n)
  })?.id || null
}

function onBrandSearch(val) {
  brandQuery.value = val
  clearTimeout(searchTimer)
  if (!val || val.length < 2) {
    catalogResults.value = []
    showNotInCatalog.value = false
    return
  }
  catalogLoading.value = true
  searchTimer = setTimeout(() => searchCatalog(val), 300)
}

async function searchCatalog(q) {
  try {
    const catRes = await $api.get('/medications/search/', { params: { q } }).catch(() => ({ data: [] }))
    catalogResults.value = (Array.isArray(catRes.data) ? catRes.data : catRes.data?.results || []).map(m => ({ ...m, _source: 'catalog' }))
    // Show "not in catalog" alert when search returns no results
    showNotInCatalog.value = q.length >= 2 && catalogResults.value.length === 0
  } catch { /* swallow */ } finally {
    catalogLoading.value = false
  }
}

const DOSAGE_FORM_LABELS = {
  tablet: 'Tablet', capsule: 'Capsule', syrup: 'Syrup', injection: 'Injection',
  cream: 'Cream', ointment: 'Ointment', drops: 'Drops', inhaler: 'Inhaler',
  suppository: 'Suppository', suspension: 'Suspension', powder: 'Powder',
  gel: 'Gel', patch: 'Patch', lozenge: 'Lozenge', spray: 'Spray',
}

function buildMedicationName(form) {
  const parts = [form.brand_name, form.strength, form.dosage_form ? (DOSAGE_FORM_LABELS[form.dosage_form] || form.dosage_form) : '']
  return parts.filter(Boolean).join(' ')
}

function onBrandSelected(val, form) {
  if (!val) {
    form.brand_name = ''
    return
  }
  if (typeof val === 'object' && val.generic_name) {
    // Selected from catalog
    const bn = val.brand_names
    form.brand_name = Array.isArray(bn) ? (bn[0] || '') : (typeof bn === 'string' ? bn : '')
    if (!form.generic_name) form.generic_name = val.generic_name
    if (!form.strength && val.strength) form.strength = val.strength
    if (!form.dosage_form && val.dosage_form) form.dosage_form = val.dosage_form
    if (!form.description && val.description) form.description = val.description
    // Sync medication name combobox selection
    if (!nameSelection.value) nameSelection.value = val
    // Auto-generate medication name: Brand + Strength + Dosage Form
    form.medication_name = buildMedicationName(form)
    const cat = matchCategory(val.category)
    if (cat) form.category = cat
    const unit = matchUnit(val.unit || val.dosage_form)
    if (unit) form.unit = unit
    showNotInCatalog.value = false
    checkInventoryDuplicate(form.medication_name)
  } else {
    const text = typeof val === 'string' ? val : String(val)
    form.brand_name = text
    if (activeForm.value) {
      form.medication_name = buildMedicationName(form)
    }
  }
}

async function checkInventoryDuplicate(name) {
  if (!name || name.length < 2) { existingStock.value = null; return }
  try {
    const branchId = activeForm.value?.branch
    const params = { search: name, page_size: 10 }
    if (branchId) params.branch = branchId
    const res = await $api.get('/inventory/stocks/', { params })
    const items = res.data?.results || res.data || []
    const exact = items.find(s =>
      s.medication_name?.toLowerCase() === name.toLowerCase() &&
      (!branchId || s.branch === branchId || s.branch_id === branchId)
    )
    existingStock.value = exact || null
  } catch { existingStock.value = null }
}

function goEditExisting() {
  if (existingStock.value?.id) {
    router.push(`/inventory/stocks/${existingStock.value.id}/edit`)
  }
}

function goAdjust() {
  if (existingStock.value?.id) {
    router.push(`/inventory/adjustments/new?stock=${existingStock.value.id}`)
  } else {
    router.push('/inventory/adjustments/new')
  }
}

function costWithTax(form) {
  const cost = Number(form.cost_price) || 0
  const tax = Math.min(Math.max(Number(form.tax_percent) || 0, 0), 100)
  return cost * (1 + tax / 100)
}
function taxPerUnit(form) {
  return costWithTax(form) - (Number(form.cost_price) || 0)
}
function taxHint(form) {
  const tax = Number(form.tax_percent) || 0
  if (tax > 0) return `Cost + ${tax}% tax = ${formatMoney(costWithTax(form))}`
  return ''
}
function margin(form) {
  return effectivePrice(form) - costWithTax(form)
}
function effectivePrice(form) {
  const sp = Number(form.selling_price) || 0
  const d = Math.min(Math.max(Number(form.discount_percent) || 0, 0), 100)
  return sp * (1 - d / 100)
}
function discountAmount(form) {
  return (Number(form.selling_price) || 0) - effectivePrice(form)
}
function marginPercent(form) {
  const cost = costWithTax(form)
  if (cost <= 0) return 0
  return (margin(form) / cost) * 100
}
function totalProfit(form) {
  return margin(form) * (Number(form.quantity) || 0)
}
function marginColor(form) {
  const m = margin(form)
  if (m < 0) return 'error'
  if (m === 0) return 'warning'
  return 'success'
}

function ymd(d = new Date()) {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}${m}${day}`
}
function rand(n = 4) {
  return Math.random().toString(36).toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, n).padEnd(n, '0')
}
function generateSku()   { return `SKU-${ymd()}-${rand(4)}` }
function generateBatch() { return `BN-${ymd()}-${rand(4)}` }

// Auto-fill on create only; never overwrite existing values (e.g. when editing)
const filled = ref(false)
const activeForm = ref(null)   // stash of the live form object (template render)
function autofill(form) {
  activeForm.value = form
  if (filled.value || loadId.value) return false
  if (!form.barcode) form.barcode = generateSku()
  if (!form.batch_number) form.batch_number = generateBatch()
  // Default classification to this tenant's "Routine" lookup
  if (!form.classification) form.classification = routineClassificationId.value
  // Branch is compulsory — default to the locked branch, else main warehouse
  if (!form.branch) {
    if (branchStore.branchLocked && branchStore.currentBranchId) {
      form.branch = branchStore.currentBranchId
    } else if (branches.value.length) {
      const main = branches.value.find(b => b.is_main)
      form.branch = main ? main.id : branches.value[0].id
    }
  }
  filled.value = true
  return false
}

const categories = ref([]); const units = ref([]); const branches = ref([]); const classifications = ref([])
const routineClassificationId = computed(() =>
  (classifications.value.find(c => c.name?.toLowerCase() === 'routine') || {}).id || null
)

// ── Container-type units (box, pack, strip, …) ──
// When the selected unit is one of these, ask the user how many
// individual items are inside one unit.
const CONTAINER_UNIT_KEYWORDS = [
  'box', 'pack', 'strip', 'carton', 'case', 'bottle', 'bag', 'drum',
  'tin', 'crate', 'tray', 'blister', 'roll', 'tube', 'tub', 'jar',
  'can', 'sachet', 'bundle', 'dozen', 'ream',
]
const selectedUnitName = computed(() => {
  if (!form_unitId.value) return ''
  const u = units.value.find(x => x.id === form_unitId.value)
  return u ? u.name : ''
})
// We need to watch the form's unit value, but since form is passed via
// template slot we access it through activeForm (stashed during render).
const form_unitId = computed(() => activeForm.value?.unit ?? null)
const isContainerUnit = computed(() => {
  const name = (selectedUnitName.value || '').toLowerCase()
  if (!name) return false
  return CONTAINER_UNIT_KEYWORDS.some(k => name.includes(k))
})

// Once branches finish loading, default any new-item form that still has
// no warehouse selected (autofill may have run before the list resolved).
watch(branches, (list) => {
  if (!list.length || loadId.value) return
  const f = activeForm.value
  if (f && !f.branch) {
    const main = list.find(b => b.is_main)
    f.branch = (branchStore.branchLocked ? branchStore.currentBranchId : null)
      || (main ? main.id : list[0].id)
  }
}, { immediate: true })

// Re-run duplicate check when branch changes (same item can exist in other branches)
watch(() => activeForm.value?.branch, () => {
  if (loadId.value) return
  const name = activeForm.value?.medication_name || nameQuery.value
  if (name && name.length >= 2) {
    checkInventoryDuplicate(name)
  }
})

// On edit: mirror server-computed total_quantity into the displayed quantity field once loaded.
// total_quantity is NOT in `initial`, so it is undefined until the API response populates it.
const synced = ref(false)
const originalQty = ref(0)
const latestBatchId = ref(null)
function syncEdit(form) {
  if (!loadId.value || synced.value) return false
  if (form.total_quantity !== undefined) {
    const qty = Number(form.total_quantity) || 0
    form.quantity = qty
    originalQty.value = qty
    // Populate the combobox with the loaded medication name
    if (form.medication_name && !nameSelection.value) {
      nameSelection.value = form.medication_name
    }
    // Mirror latest batch info (batch_number/expiry_date are write-only on the serializer,
    // so they only come back nested under `batches`).
    const batches = Array.isArray(form.batches) ? form.batches.slice() : []
    if (batches.length) {
      // Pick the most recently received (or latest expiry) batch
      batches.sort((a, b) => {
        const ar = a.received_date || a.expiry_date || ''
        const br = b.received_date || b.expiry_date || ''
        return br.localeCompare(ar)
      })
      const latest = batches[0]
      latestBatchId.value = latest.id || null
      if (!form.batch_number) form.batch_number = latest.batch_number || ''
      if (!form.expiry_date)  form.expiry_date  = latest.expiry_date  || ''
    }
    if (!form.barcode) form.barcode = '' // ensure reactive key exists
    synced.value = true
  }
  return false
}

async function onSaved() {
  // If editing and quantity changed, create a count-correction adjustment to apply the delta.
  if (loadId.value && desiredQty.value != null && latestBatchId.value) {
    const delta = desiredQty.value - originalQty.value
    if (delta !== 0) {
      try {
        await $api.post('/inventory/adjustments/', {
          stock: loadId.value,
          batch: latestBatchId.value,
          quantity_change: delta,
          reason: 'count_correction',
          notes: 'Adjusted from stock edit form',
        })
      } catch (e) {
        console.warn('Failed to create stock adjustment:', e)
      }
    }
  }
  router.push('/inventory')
}

// Track the desired quantity entered by the user (captured in transformPayload)
const desiredQty = ref(null)

// Auto-calculate reorder level (30%) and reorder quantity (50%) from quantity.
// User overrides flip the *touched* flags, after which auto recalc stops.
const levelTouched = ref(false)
const qtyTouched = ref(false)
function recalc(form, raw) {
  const q = Math.max(0, Number(raw) || 0)
  if (!levelTouched.value) form.reorder_level = Math.round(q * 0.30)
  if (!qtyTouched.value)   form.reorder_quantity = Math.round(q * 0.50)
}
function resetLevel(form) {
  levelTouched.value = false
  form.reorder_level = Math.round((Number(form.quantity) || 0) * 0.30)
}
function resetQty(form) {
  qtyTouched.value = false
  form.reorder_quantity = Math.round((Number(form.quantity) || 0) * 0.50)
}

function defaultExpiry() {
  const d = new Date()
  d.setFullYear(d.getFullYear() + 5)
  return d.toISOString().slice(0, 10)
}
const dosageFormChoices = [
  { label: 'Tablet', value: 'tablet' },
  { label: 'Capsule', value: 'capsule' },
  { label: 'Syrup', value: 'syrup' },
  { label: 'Injection', value: 'injection' },
  { label: 'Cream', value: 'cream' },
  { label: 'Ointment', value: 'ointment' },
  { label: 'Drops', value: 'drops' },
  { label: 'Inhaler', value: 'inhaler' },
  { label: 'Suppository', value: 'suppository' },
  { label: 'Suspension', value: 'suspension' },
  { label: 'Powder', value: 'powder' },
  { label: 'Gel', value: 'gel' },
  { label: 'Patch', value: 'patch' },
  { label: 'Lozenge', value: 'lozenge' },
  { label: 'Spray', value: 'spray' },
]

const initial = { medication_name: '', barcode: '', brand_name: '', generic_name: '', strength: '', dosage_form: '', category: null, classification: null, unit: null, branch: null, is_active: true, quantity: 0, reorder_level: 0, reorder_quantity: 0, cost_price: 0, tax_percent: 0, selling_price: 0, discount_percent: 0, items_per_unit: 0, batch_number: '', expiry_date: defaultExpiry(), description: '' }

// Sync nameSelection when editing an existing item
watch(loadId, (id) => { if (id) { showNotInCatalog.value = false } }, { immediate: true })

// Map form fields to backend payload. Strip read-only/derived fields.
function transformPayload(data) {
  const payload = { ...data }
  // total_quantity is server-computed and read-only
  delete payload.total_quantity
  // description is not a MedicationStock field — strip it
  delete payload.description
  // Strip empty expiry_date so backend doesn't reject it
  if (!payload.expiry_date) delete payload.expiry_date
  if (loadId.value) {
    // Capture the desired quantity for post-save adjustment, but don't send it
    desiredQty.value = Number(payload.quantity) || 0
    delete payload.quantity
    delete payload.initial_quantity
  } else {
    // On create: rename quantity -> initial_quantity for the first batch
    if (payload.quantity != null) {
      payload.initial_quantity = payload.quantity
      delete payload.quantity
    }
  }
  return payload
}

// ── Manage Units dialog ─────────────────────────────
const unitDialog = ref(false)
const unitSaving = ref(false)
const unitForm = reactive({ name: '', abbreviation: '' })
const unitNameRules = [v => !!v?.trim() || 'Unit name is required']
const unitSnackbar = reactive({ show: false, text: '', color: 'success' })

// Common unit suggestions users can pick from
const unitSuggestions = [
  'tablets', 'capsules', 'ml', 'mg', 'grams', 'liters', 'drops',
  'puffs', 'units', 'vials', 'ampoules', 'sachets', 'pieces',
  'boxes', 'packs', 'strips', 'bottles', 'tubes', 'bags',
  'scoops', 'patches', 'suppositories',
]

function pickUnitSuggestion(name) {
  unitForm.name = name
  // Auto-fill common abbreviations
  const abbrevs = {
    tablets: 'tab', capsules: 'cap', millilitres: 'ml', grams: 'g',
    liters: 'L', drops: 'gtt', pieces: 'pc', boxes: 'box',
    packs: 'pck', strips: 'str', bottles: 'btl', tubes: 'tub',
    bags: 'bag', vials: 'vl', ampoules: 'amp', sachets: 'sch',
    scoops: 'scp', patches: 'ptc', suppositories: 'sup',
  }
  unitForm.abbreviation = abbrevs[name] || ''
}

function closeUnitDialog() {
  unitDialog.value = false
  unitForm.name = ''
  unitForm.abbreviation = ''
}

async function saveUnit() {
  const name = unitForm.name.trim()
  if (!name) return
  unitSaving.value = true
  try {
    const { data } = await $api.post('/inventory/units/', {
      name,
      abbreviation: unitForm.abbreviation.trim(),
    })
    // Add to units list and auto-select
    if (!units.value.find(u => u.id === data.id)) {
      units.value.push(data)
    }
    units.value.sort((a, b) => a.name.localeCompare(b.name))
    if (activeForm.value) activeForm.value.unit = data.id
    unitSnackbar.show = true
    unitSnackbar.text = `Unit "${data.name}" created`
    unitSnackbar.color = 'success'
    closeUnitDialog()
  } catch (e) {
    const msg = e?.response?.data?.name?.[0] || e?.response?.data?.detail || 'Failed to create unit'
    unitSnackbar.show = true
    unitSnackbar.text = msg
    unitSnackbar.color = 'error'
  } finally {
    unitSaving.value = false
  }
}

onMounted(async () => {
  const safe = (p) => $api.get(p).then(r => r.data?.results || r.data || []).catch(() => [])
  // Inventory tenants use their own /ims API namespace.
  const { branches: branchesApi } = useTenantEndpoints()
  categories.value = await safe('/inventory/categories/')
  classifications.value = await safe('/inventory/classifications/')
  units.value = await safe('/inventory/units/')
  branches.value = await safe(branchesApi.value)
  // If a new-item form is open before classifications load fills in, fall
  // back to the Routine classification once it's available.
  if (!loadId.value && activeForm.value && !activeForm.value.classification) {
    activeForm.value.classification = routineClassificationId.value
  }
})
</script>

<style scoped>
/* ═══════════════ Section panels ═══════════════
   The form is rendered `flat` inside ResourceFormPage, so each section supplies
   its own card. This keeps the five steps visually separated and lets a long
   form read as a sequence rather than one undifferentiated block. */
.stock-section {
  position: relative;
  border-radius: 16px;
  padding: 20px 22px 22px;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  box-shadow: 0 2px 10px rgba(15, 23, 42, 0.035);
}
.stock-section + .stock-section { margin-top: 16px; }

.stock-section__header {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 18px;
  padding-bottom: 14px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.07);
}
.stock-section__icon {
  width: 38px;
  height: 38px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  box-shadow: 0 4px 12px rgba(15, 23, 42, 0.16);
}
.stock-section__title {
  font-size: 0.98rem;
  font-weight: 700;
  line-height: 1.2;
  letter-spacing: -0.1px;
}
.stock-section__sub {
  font-size: 0.78rem;
  opacity: 0.55;
  margin-top: 1px;
}
/* Faded step ordinal — a quiet progress cue that costs no vertical space. */
.stock-section__step {
  margin-left: auto;
  font-size: 26px;
  font-weight: 800;
  line-height: 1;
  letter-spacing: -1px;
  color: rgba(var(--v-theme-on-surface), 0.09);
  user-select: none;
}
/* When a trailing chip is present it already claims `margin-left:auto`, so the
   ordinal must not push past it. */
.stock-section__step + .v-chip { margin-left: 0 !important; }

/* ═══════════════ Sub-panel ═══════════════
   Soft inset well for the stock-level inputs. */
.stock-subpanel {
  border-radius: 13px;
  padding: 16px 16px 6px;
  background: rgba(var(--v-theme-surface-variant), 0.28);
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}

/* ═══════════════ Profit analysis ═══════════════ */
.profit-card {
  position: relative;
  overflow: hidden;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08) !important;
  transition: box-shadow 0.2s ease;
}
.profit-card:hover { box-shadow: 0 10px 26px rgba(15, 23, 42, 0.09); }
/* A tinted left rail keeps the health signal even though the card is tonal. */
.profit-card::before {
  content: '';
  position: absolute;
  inset: 0 auto 0 0;
  width: 4px;
  background: currentColor;
  opacity: 0.9;
}
.profit-card--success { color: rgb(var(--v-theme-success)); }
.profit-card--warning { color: rgb(var(--v-theme-warning)); }
.profit-card--error { color: rgb(var(--v-theme-error)); }

.profit-metric {
  padding: 6px 0;
}
.profit-metric__label {
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.55px;
  opacity: 0.62;
  margin-bottom: 5px;
}
.profit-metric__value {
  font-size: 1.45rem;
  font-weight: 800;
  line-height: 1.25;
  letter-spacing: -0.4px;
  /* Inherits the card's tone so the numbers themselves carry the health signal. */
  color: currentColor;
}
.profit-metric__hint {
  font-size: 0.74rem;
  opacity: 0.58;
  margin-top: 3px;
}
</style>
