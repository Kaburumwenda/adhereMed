<template>
  <v-container fluid class="pa-3 pa-md-5">
    <div class="d-flex align-center mb-4" style="gap:14px">
      <v-avatar color="purple" variant="tonal" rounded="lg" size="52">
        <v-icon size="28">mdi-file-document-plus</v-icon>
      </v-avatar>
      <div>
        <h1 class="text-h5 text-md-h4 font-weight-bold mb-0">New Request for Quotation</h1>
        <div class="text-body-2 text-medium-emphasis">Create an RFQ to send to multiple suppliers</div>
      </div>
    </div>

    <v-card rounded="lg" elevation="0" class="pa-5 mx-auto" style="border:1px solid rgba(0,0,0,0.06); max-width:800px">
      <!--
        NOTE: the template ref MUST NOT be called `form`.
        `<script setup>` resolves `ref="..."` against the setup bindings, so a
        ref named `form` would be assigned straight over the reactive form
        object below (the compiler writes `form.value = <VForm instance>`),
        wiping `form.value.items` and sending the render loop into a spin that
        freezes the whole page. Always use a distinct name like `formRef`.
      -->
      <v-form ref="formRef" @submit.prevent="save">
        <v-text-field v-model="form.title" label="Title *" variant="outlined" density="compact" rounded="lg" :rules="[v => !!v || 'Title is required']" class="mb-3" />
        <v-textarea v-model="form.description" label="Description / Requirements" variant="outlined" density="compact" rounded="lg" rows="3" class="mb-3" hide-details />

        <v-row dense>
          <v-col cols="12" sm="6">
            <v-text-field v-model="form.expected_delivery" type="date" label="Expected Delivery" variant="outlined" density="compact" rounded="lg" class="mb-3" hide-details />
          </v-col>
          <v-col cols="12" sm="6">
            <v-text-field v-model="form.response_deadline" type="date" label="Response Deadline" variant="outlined" density="compact" rounded="lg" class="mb-3" hide-details />
          </v-col>
        </v-row>

        <v-select v-model="form.branch" :items="branchOptions" item-title="label" item-value="value" label="Branch *" density="compact" variant="outlined" rounded="lg" :rules="[v => v != null || 'Branch is required']" class="mb-3" />

        <v-divider class="my-3" />
        <div class="d-flex align-center flex-wrap mb-1" style="gap:8px">
          <div class="text-subtitle-2">Requested Items</div>
          <v-chip size="x-small" variant="tonal" color="purple">{{ form.items.length }}</v-chip>
        </div>
        <div class="text-caption text-medium-emphasis mb-3">
          Search the medication catalog, or just type a name and press <b>Enter</b> to enter it manually.
        </div>

        <div v-for="(item, i) in form.items" :key="i" class="d-flex align-center mb-2" style="gap:8px">
          <v-combobox
            v-model="item.pick"
            :items="itemSearchResults"
            item-title="label"
            item-value="id"
            :return-object="true"
            label="Item name"
            density="compact"
            variant="outlined"
            rounded="lg"
            hide-details
            clearable
            style="flex:2; min-width:0"
            :loading="itemSearching"
            :menu-props="{ maxHeight: 320 }"
            @update:search="onItemSearch"
            @update:model-value="onPickItem(item, $event)"
          >
            <template #item="{ props: ip, item: opt }">
              <v-list-item v-bind="ip" :title="opt.raw.label">
                <template #subtitle>
                  <div class="d-flex flex-wrap align-center" style="gap:4px">
                    <v-chip v-if="opt.raw.category" size="x-small" variant="tonal" color="purple">{{ opt.raw.category }}</v-chip>
                    <span v-if="opt.raw.unit" class="text-caption text-medium-emphasis">per {{ opt.raw.unit }}</span>
                  </div>
                </template>
              </v-list-item>
            </template>
            <template #no-data>
              <v-list-item v-if="itemSearchQuery && !itemSearching">
                <div class="text-body-2 text-medium-emphasis pa-2">
                  No catalog match — press <b>Enter</b> to add
                  <b>{{ itemSearchQuery }}</b> as a manual item.
                </div>
              </v-list-item>
            </template>
          </v-combobox>
          <v-text-field v-model.number="item.qty" label="Qty" type="number" density="compact" variant="outlined" rounded="lg" hide-details style="flex:1; min-width:0" />
          <v-combobox
            v-model="item.unit"
            :items="unitOptions"
            label="Unit"
            density="compact"
            variant="outlined"
            rounded="lg"
            hide-details
            clearable
            style="flex:1; min-width:0"
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
          <v-btn icon="mdi-close" variant="text" color="error" size="small" :disabled="form.items.length <= 1" @click="removeItem(i)" />
        </div>
        <v-btn variant="tonal" color="purple" size="small" rounded="lg" class="text-none mb-3" prepend-icon="mdi-plus" @click="addItem">Add Item</v-btn>

        <v-divider class="my-3" />
        <v-alert v-if="error" type="error" variant="tonal" density="compact" rounded="lg" class="mb-3">{{ error }}</v-alert>
        <div class="d-flex" style="gap:8px">
          <v-btn color="purple" variant="flat" rounded="lg" class="text-none" type="submit" :loading="saving">Create RFQ</v-btn>
          <v-btn variant="text" rounded="lg" class="text-none" @click="navigateTo(`${ns}/purchase-orders/rfqs`)">Cancel</v-btn>
        </div>
      </v-form>
    </v-card>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { useRoute } from 'vue-router'
import { useBranchStore } from '~/stores/branch'

const { $api } = useNuxtApp()
const route = useRoute()
const branchStore = useBranchStore()

const saving = ref(false)
const error = ref('')

// Distinct from `form` — see the template comment above.
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

/** A fresh, empty line item. `pick` backs the combobox widget only. */
function blankItem() {
  return { pick: null, name: '', qty: 1, unit: '' }
}

const form = ref({
  title: '',
  description: '',
  expected_delivery: '',
  response_deadline: '',
  branch: null,
  items: [blankItem()],
})

const branchOptions = computed(() => {
  const source = branchStore.activeBranches
  const opts = []
  for (const b of source) opts.push({ label: b.name, value: b.id })
  return opts
})

// ── Units of measure ──
// Sourced from the tenant's own unit list (`/inventory/units/`, the same
// lookup the medications and stock pages use). A combobox rather than a plain
// select, so a unit that isn't registered can still be typed in by hand.
const unitOptions = ref([])

async function loadUnits() {
  try {
    const { data } = await $api.get('/inventory/units/', { params: { page_size: 1000 } })
    const rows = data?.results || data || []
    unitOptions.value = rows.map(u => u.name).filter(Boolean)
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
  form.items.push(blankItem())
}

function removeItem(i) {
  if (form.items.length <= 1) return
  form.items.splice(i, 1)
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
        params: { q: query.trim() },
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
 * Either way `item.name` is the field we submit.
 */
function onPickItem(item, value) {
  if (value && typeof value === 'object') {
    item.name = value.label || value.generic_name || ''
    // Pre-fill the unit from the catalog; the user can still change it.
    if (value.unit) item.unit = value.unit
  } else if (typeof value === 'string') {
    item.name = value.trim()
  } else {
    item.name = ''
  }
}

onBeforeUnmount(() => clearTimeout(itemSearchTimer))

async function save() {
  error.value = ''
  saving.value = true
  try {
    // Build items explicitly: the model stores them as a raw JSONField, so any
    // UI-only key (`pick`) spread in here would be persisted verbatim.
    const items = form.value.items
      .filter(i => (i.name || '').trim())
      .map(i => ({
        name: i.name.trim(),
        qty: Number(i.qty) > 0 ? Number(i.qty) : 1,
        unit: (i.unit || '').trim(),
      }))

    if (!items.length) {
      error.value = 'Add at least one item before creating the RFQ.'
      return
    }

    const payload = {
      title: form.value.title,
      description: form.value.description,
      expected_delivery: form.value.expected_delivery || null,
      response_deadline: form.value.response_deadline || null,
      branch: form.value.branch,
      items,
    }

    const { data } = await $api.post('/purchase-orders/rfqs/', payload)
    navigateTo(`${ns.value}/purchase-orders/rfqs/${data.id}`)
  } catch (e) {
    console.error(e)
    const detail = e?.response?.data
    error.value = 'Failed: ' + (detail?.detail || (detail ? JSON.stringify(detail) : e.message))
  } finally {
    saving.value = false
  }
}

onMounted(async () => {
  await Promise.all([branchStore.load(), loadUnits()])
})
</script>
