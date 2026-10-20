<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-hard-hat"
      eyebrow="OHSMS · PPE management"
      title="Personal Protective Equipment"
      subtitle="Stock levels, issue history and replacement cycles for every item of PPE on site."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-download" @click="exportData">
          Export
        </v-btn>
        <v-btn class="ohs-btn-strong text-none" rounded="lg" size="small" prepend-icon="mdi-account-plus-outline"
               @click="openIssue">
          Issue PPE
        </v-btn>
      </template>
      <span class="ohs-chip"><v-icon size="12">mdi-package-variant</v-icon>
        <b>{{ items.count.value }}</b> item types</span>
      <span class="ohs-chip"><v-icon size="12">mdi-swap-horizontal</v-icon>
        <b>{{ issues.count.value }}</b> issues logged</span>
      <span v-if="stats.low" class="ohs-chip ohs-chip-warn">
        <v-icon size="12">mdi-package-variant-remove</v-icon>
        <b>{{ stats.low }}</b> below reorder</span>
    </OhsHero>

    <div class="ohs-kpi-grid mb-3">
      <OhsKpi label="Item types" :value="items.count.value" icon="mdi-package-variant" tone="primary"
              :sub="`${stats.categories} categories`" />
      <OhsKpi label="Total stock" :value="stats.stock" icon="mdi-warehouse" tone="info" sub="units on hand" />
      <OhsKpi label="Stock value" :value="compactMoney(stats.value)" icon="mdi-cash-multiple" tone="ok"
              sub="at unit cost" />
      <OhsKpi label="Below reorder" :value="stats.low" icon="mdi-package-variant-remove"
              :tone="stats.low ? 'err' : 'ok'" sub="replenish now" />
      <OhsKpi label="Replacements due" :value="stats.replacementsDue" icon="mdi-calendar-clock"
              :tone="stats.replacementsDue ? 'warn' : 'ok'" sub="next 30 days" />
    </div>

    <v-row dense>
      <v-col cols="12" lg="7">
        <OhsPanel title="PPE inventory" :subtitle="`${filtered.length} item(s)`" icon="mdi-package-variant" flush>
          <div class="ohs-toolbar">
            <v-text-field v-model="search" placeholder="Search item or standard…" prepend-inner-icon="mdi-magnify"
                          density="compact" variant="outlined" rounded="lg" hide-details single-line clearable
                          style="max-width:260px" />
            <v-select v-model="categoryFilter" :items="categoryOptions" item-title="label" item-value="value"
                      placeholder="All categories" density="compact" variant="outlined" rounded="lg"
                      hide-details clearable style="max-width:210px" />
            <v-checkbox v-model="onlyLow" density="compact" hide-details label="Low stock only" color="error" />
          </div>
          <div class="ohs-scroll" style="max-height:64vh">
            <table class="ohs-table">
              <thead>
                <tr>
                  <th>Item</th>
                  <th style="width:130px">Category</th>
                  <th style="width:80px" class="num">Stock</th>
                  <th style="width:80px" class="num">Reorder</th>
                  <th style="width:110px" class="num">Unit cost</th>
                  <th style="width:100px" class="num">Issued</th>
                  <th style="width:110px">Status</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="p in filtered" :key="p.id" @click="selected = p">
                  <td>
                    <div class="font-weight-medium">{{ p.name }}</div>
                    <div class="text-caption text-medium-emphasis">
                      {{ p.standard || '—' }}<span v-if="p.sizes"> · {{ p.sizes }}</span>
                    </div>
                  </td>
                  <td class="text-caption">{{ p.category_display }}</td>
                  <td class="num font-weight-bold" :class="{ 'text-error': p.is_low_stock }">{{ p.stock_on_hand }}</td>
                  <td class="num text-caption">{{ p.reorder_level }}</td>
                  <td class="num text-caption">{{ compactMoney(p.unit_cost) }}</td>
                  <td class="num text-caption">{{ p.issued_count }}</td>
                  <td>
                    <span class="ohs-badge" :class="p.is_low_stock ? 'ohs-badge--err' : 'ohs-badge--ok'">
                      {{ p.is_low_stock ? 'Reorder' : 'In stock' }}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
            <div v-if="!filtered.length" class="ohs-empty">No PPE items match these filters.</div>
          </div>
        </OhsPanel>
      </v-col>

      <v-col cols="12" lg="5">
        <OhsPanel :title="selected ? `Issues · ${selected.name}` : 'Recent issues'"
                  subtitle="Latest PPE distributed to workers" icon="mdi-swap-horizontal" flush>
          <template #actions>
            <v-btn v-if="selected" size="x-small" variant="text" class="text-none" @click="selected = null">
              All items
            </v-btn>
          </template>
          <div class="ohs-scroll" style="max-height:64vh">
            <div v-for="i in visibleIssues" :key="i.id" class="ohs-list-row">
              <span class="avatar-sm" :style="avatarStyle(i.employee_name)">{{ initialsOf(i.employee_name) }}</span>
              <div class="flex-grow-1" style="min-width:0">
                <div class="text-body-2 font-weight-medium text-truncate">{{ i.employee_name }}</div>
                <div class="text-caption text-medium-emphasis">
                  {{ i.ppe_name }} · qty {{ i.quantity }}<span v-if="i.size"> · {{ i.size }}</span>
                </div>
              </div>
              <div class="text-right">
                <div class="text-caption">{{ formatDate(i.issued_on) }}</div>
                <div class="text-caption text-medium-emphasis">due {{ formatDate(i.replacement_due) }}</div>
              </div>
            </div>
            <div v-if="!visibleIssues.length" class="ohs-empty">No issues recorded.</div>
          </div>
        </OhsPanel>
      </v-col>
    </v-row>

    <!-- Issue PPE -->
    <v-dialog v-model="issueDialog" max-width="600">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-account-plus-outline" title="Issue PPE"
                           subtitle="Log what was handed out and when it needs replacing." />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-select v-model="form.ppe_item" :items="ppeOptions" item-title="label" item-value="value"
                        label="PPE item" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.employee_name" label="Employee" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.employee_ref" label="Employee ref" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.site" :items="siteOptions" item-title="label" item-value="value"
                        label="Site" variant="outlined" density="compact" rounded="lg" clearable />
            </v-col>
            <v-col cols="6" sm="4">
              <v-text-field v-model.number="form.quantity" type="number" min="1" label="Qty"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="6" sm="4">
              <v-text-field v-model="form.size" label="Size" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model="form.issued_on" type="date" label="Issued on" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
          </v-row>
          <v-alert v-if="error" type="error" variant="tonal" density="compact" rounded="lg" class="mt-3">{{ error }}</v-alert>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="issueDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="issues.saving.value"
                 :disabled="!form.ppe_item || !form.employee_name" @click="saveIssue">Issue</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="bottom right" timeout="2600">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
definePageMeta({ layout: 'default' })
useHead({ title: 'PPE · OHSMS' })

const ohs = useOhs()

const items = ohs.resource('ppe-items')
const issues = ohs.resource('ppe-issues')
const lookups = ref({})
const search = ref('')
const categoryFilter = ref(null)
const onlyLow = ref(false)
const selected = ref(null)
const issueDialog = ref(false)
const error = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const form = reactive({
  ppe_item: null, employee_name: '', employee_ref: '', site: null,
  quantity: 1, size: '', issued_on: new Date().toISOString().slice(0, 10),
})

const siteOptions = computed(() => (lookups.value.sites || []).map((s) => ({ label: s.name, value: s.id })))
const ppeOptions = computed(() => (items.items.value || []).map((p) => ({
  label: `${p.name} (${p.stock_on_hand} in stock)`, value: p.id,
})))
const categoryOptions = computed(() => (items.items.value || [])
  .map((p) => ({ label: p.category_display, value: p.category }))
  .filter((v, i, arr) => arr.findIndex((x) => x.value === v.value) === i))

const filtered = computed(() => (items.items.value || []).filter((p) => {
  if (categoryFilter.value && p.category !== categoryFilter.value) return false
  if (onlyLow.value && !p.is_low_stock) return false
  const q = search.value.trim().toLowerCase()
  if (q && !`${p.name} ${p.code} ${p.standard}`.toLowerCase().includes(q)) return false
  return true
}))

const stats = computed(() => {
  const all = items.items.value || []
  const due = Date.now() + 30 * 86400000
  return {
    stock: all.reduce((s, p) => s + (p.stock_on_hand || 0), 0),
    value: all.reduce((s, p) => s + (p.stock_on_hand || 0) * Number(p.unit_cost || 0), 0),
    low: all.filter((p) => p.is_low_stock).length,
    categories: new Set(all.map((p) => p.category)).size,
    replacementsDue: (issues.items.value || []).filter((i) => i.replacement_due
      && new Date(i.replacement_due).getTime() <= due).length,
  }
})

const visibleIssues = computed(() => {
  const list = selected.value
    ? issues.items.value.filter((i) => i.ppe_item === selected.value.id)
    : issues.items.value
  return list.slice(0, 60)
})

function avatarStyle(name) {
  const hue = hueOf(name)
  return { background: `hsl(${hue} 62% 92%)`, color: `hsl(${hue} 55% 32%)` }
}

async function load() {
  await Promise.all([
    items.list({ ordering: 'name' }),
    issues.list({ ordering: '-issued_on' }),
  ])
  lookups.value = await ohs.loadLookups()
}

function openIssue() {
  error.value = ''
  Object.assign(form, {
    ppe_item: ppeOptions.value[0]?.value || null, employee_name: '', employee_ref: '',
    site: null, quantity: 1, size: '', issued_on: new Date().toISOString().slice(0, 10),
  })
  issueDialog.value = true
}

async function saveIssue() {
  error.value = ''
  try {
    const payload = { ...form }
    if (!payload.site) delete payload.site
    await issues.create(payload)
    issueDialog.value = false
    snack.value = { show: true, color: 'success', text: 'PPE issued.' }
    await load()
  } catch (e) {
    error.value = issues.message(e)
  }
}

function exportData() {
  exportCsv(`ppe_inventory_${new Date().toISOString().slice(0, 10)}.csv`, filtered.value, [
    { key: 'name', label: 'Item' },
    { key: 'category_display', label: 'Category' },
    { key: 'standard', label: 'Standard' },
    { key: 'stock_on_hand', label: 'Stock' },
    { key: 'reorder_level', label: 'Reorder level' },
    { key: 'unit_cost', label: 'Unit cost' },
    { key: 'issued_count', label: 'Issued' },
    { value: (p) => (p.is_low_stock ? 'Reorder' : 'In stock'), label: 'Status' },
  ])
}

watch([categoryFilter, onlyLow], load)
onMounted(load)
</script>

<style scoped>
.avatar-sm {
  width: 26px; height: 26px; border-radius: 8px;
  display: inline-flex; align-items: center; justify-content: center;
  font-size: 10px; font-weight: 800; flex-shrink: 0;
}
</style>
