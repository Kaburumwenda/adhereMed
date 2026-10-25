<template>
  <v-container fluid class="pa-4 pa-md-6 catalog-page">
    <!-- ═══════════════ HERO ═══════════════
         Brand-tinted gradient driven by the tenant palette set at
         /clinics/organization/branding, so the catalog surface reads as part
         of the clinic product rather than a generic admin table. -->
    <div class="cat-hero mb-4" :style="heroTheme">
      <span class="cat-hero-glow" />
      <span class="cat-hero-glow cat-hero-glow-2" />

      <div class="d-flex flex-wrap align-center justify-space-between ga-3">
        <div class="d-flex align-center" style="gap:16px; min-width:0">
          <div class="cat-hero-icon">
            <v-icon size="30">{{ config.icon }}</v-icon>
          </div>
          <div style="min-width:0">
            <div class="cat-hero-eyebrow">
              <v-icon size="10">mdi-circle</v-icon>
              {{ config.eyebrow }}
            </div>
            <h1 class="cat-hero-title">{{ config.title }}</h1>
            <div class="cat-hero-sub">{{ config.subtitle }}</div>
          </div>
        </div>

        <div class="d-flex flex-wrap align-center ga-2">
          <v-btn icon="mdi-refresh" variant="text" size="small" class="cat-hero-iconbtn"
                 title="Refresh" :loading="loading" @click="reloadAll" />
          <v-btn variant="flat" elevation="0" rounded="lg" class="text-none cat-hero-btn-glass"
                 prepend-icon="mdi-database-import" :disabled="!canAdmin || loading"
                 @click="seedDialog = true">Seed catalog</v-btn>
          <v-btn variant="flat" elevation="0" rounded="lg" class="text-none cat-hero-btn-strong"
                 prepend-icon="mdi-plus" :disabled="!canAdmin" @click="openForm()">
            New {{ config.singular.toLowerCase() }}
          </v-btn>
        </div>
      </div>

      <!-- Fact strip -->
      <div class="cat-hero-foot">
        <span class="cat-hero-chip">
          <v-icon size="14">{{ config.icon }}</v-icon>
          {{ num(stats.total) }} {{ config.plural.toLowerCase() }}
        </span>
        <span class="cat-hero-chip">
          <v-icon size="14">mdi-check-circle-outline</v-icon>
          {{ num(stats.active) }} active
        </span>
        <span class="cat-hero-chip">
          <v-icon size="14">mdi-shape-outline</v-icon>
          {{ num(stats.categories_count) }} categories
        </span>
        <span class="cat-hero-chip">
          <v-icon size="14">mdi-database-check-outline</v-icon>
          {{ num(stats.seeded) }} seeded · {{ num(stats.custom) }} custom
        </span>
      </div>
    </div>

    <!-- ═══════════════ KPI TILES ═══════════════ -->
    <v-row dense class="mb-4">
      <v-col v-for="k in kpiTiles" :key="k.key" cols="6" md="3">
        <div class="cat-kpi" :class="{ 'cat-kpi--active': activeFilter === k.filter }"
             :style="{ '--kpi-tone': k.tone }" @click="applyKpiFilter(k)">
          <div class="cat-kpi-icon">
            <v-icon size="20">{{ k.icon }}</v-icon>
          </div>
          <div class="min-w-0">
            <div class="cat-kpi-label">{{ k.label }}</div>
            <div class="cat-kpi-value">{{ num(k.value) }}</div>
            <div class="cat-kpi-hint">{{ k.hint }}</div>
          </div>
        </div>
      </v-col>
    </v-row>

    <!-- ═══════════════ CATEGORY CHIPS ═══════════════ -->
    <div v-if="stats.by_category?.length" class="cat-chips mb-4">
      <button type="button" class="cat-chip" :class="{ 'cat-chip--on': !filterCategory }"
              @click="setCategory('')">
        All
        <span class="cat-chip-count">{{ num(stats.total) }}</span>
      </button>
      <button v-for="c in stats.by_category" :key="c.category" type="button"
              class="cat-chip" :class="{ 'cat-chip--on': filterCategory === c.category }"
              @click="setCategory(c.category)">
        {{ prettyCategory(c.category) }}
        <span class="cat-chip-count">{{ num(c.count) }}</span>
      </button>
    </div>

    <!-- ═══════════════ TOOLBAR ═══════════════ -->
    <v-card flat rounded="xl" border class="cat-toolbar pa-3 mb-3">
      <div class="d-flex flex-wrap align-center" style="gap:10px">
        <v-text-field v-model="search" prepend-inner-icon="mdi-magnify" :placeholder="config.searchPlaceholder"
                      variant="outlined" density="compact" hide-details clearable rounded="lg"
                      style="min-width:240px; max-width:380px; flex:1;"
                      @update:model-value="debouncedLoad" />

        <v-select v-model="filterSource" :items="sourceOptions" item-title="label" item-value="value"
                  variant="outlined" density="compact" hide-details rounded="lg"
                  style="max-width:170px; flex:0 0 auto;" @update:model-value="applyFilters" />

        <v-select v-model="filterActive" :items="activeOptions" item-title="label" item-value="value"
                  variant="outlined" density="compact" hide-details rounded="lg"
                  style="max-width:150px; flex:0 0 auto;" @update:model-value="applyFilters" />

        <v-spacer />

        <v-chip size="small" variant="tonal" color="primary" class="font-weight-medium">
          {{ num(total) }} shown
        </v-chip>

        <v-btn-toggle v-model="viewMode" mandatory density="compact" variant="outlined" divided rounded="lg">
          <v-btn value="table" size="small" title="Table view"><v-icon size="18">mdi-format-list-bulleted</v-icon></v-btn>
          <v-btn value="cards" size="small" title="Card view"><v-icon size="18">mdi-view-grid-outline</v-icon></v-btn>
        </v-btn-toggle>
      </div>
    </v-card>

    <!-- ═══════════════ TABLE VIEW ═══════════════ -->
    <v-card v-if="viewMode === 'table'" flat rounded="xl" border class="cat-surface">
      <v-data-table-server v-model:items-per-page="perPage" v-model:page="page"
                           :items-length="total" :headers="headers" :items="items"
                           :loading="loading" density="comfortable" hover
                           :items-per-page-options="[25, 50, 100, 200]"
                           @update:options="onOptions">
        <template #[`item.name`]="{ item }">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar size="28" rounded="lg" :color="categoryTone(item.category)" variant="tonal">
              <v-icon size="15">{{ config.icon }}</v-icon>
            </v-avatar>
            <span class="font-weight-medium">{{ item.name }}</span>
          </div>
        </template>

        <template #[`item.category`]="{ item }">
          <v-chip v-if="item.category" size="x-small" variant="tonal"
                  :color="categoryTone(item.category)" class="text-capitalize font-weight-medium">
            {{ prettyCategory(item.category) }}
          </v-chip>
          <span v-else class="text-disabled">—</span>
        </template>

        <!-- Extra column (ICD-10 / symptoms) -->
        <template #[`item.extra`]="{ item }">
          <span :class="config.extraKey === 'icd_code' ? 'font-mono text-caption font-weight-medium' : 'text-body-2'">
            {{ item[config.extraKey] || '—' }}
          </span>
        </template>

        <template #[`item.source`]="{ item }">
          <v-chip size="x-small" variant="tonal" :color="item.source === 'seed' ? 'teal' : 'purple'"
                  :prepend-icon="item.source === 'seed' ? 'mdi-database-check' : 'mdi-pencil-outline'">
            {{ item.source === 'seed' ? 'Seeded' : 'Custom' }}
          </v-chip>
        </template>

        <template #[`item.is_active`]="{ item }">
          <v-switch :model-value="item.is_active" color="success" density="compact" hide-details inset
                    :disabled="!canAdmin || togglingId === item.id"
                    @update:model-value="(v) => toggleActive(item, v)" />
        </template>

        <template #[`item.actions`]="{ item }">
          <div class="d-flex justify-end ga-1">
            <v-btn icon="mdi-pencil" variant="text" size="small" :disabled="!canAdmin"
                   @click="openForm(item)" />
            <v-btn icon="mdi-delete-outline" variant="text" size="small" color="error"
                   :disabled="!canAdmin" @click="confirmDelete(item)" />
          </div>
        </template>

        <template #no-data>
          <div class="text-center pa-10">
            <v-avatar size="62" color="primary" variant="tonal" rounded="lg" class="mb-3">
              <v-icon size="30">{{ config.icon }}</v-icon>
            </v-avatar>
            <div class="text-subtitle-1 font-weight-bold">
              {{ hasFilters ? `No ${config.plural.toLowerCase()} match your filters` : `No ${config.plural.toLowerCase()} yet` }}
            </div>
            <div class="text-body-2 text-medium-emphasis mb-4">
              {{ hasFilters
                ? 'Try clearing the search or filters.'
                : `Seed the platform catalog or add your first ${config.singular.toLowerCase()}.` }}
            </div>
            <v-btn v-if="hasFilters" variant="tonal" color="primary" class="text-none mr-2"
                   prepend-icon="mdi-filter-remove-outline" @click="clearFilters">Clear filters</v-btn>
            <v-btn v-else-if="canAdmin" color="primary" class="text-none"
                   prepend-icon="mdi-database-import" @click="seedDialog = true">Seed catalog</v-btn>
          </div>
        </template>
      </v-data-table-server>
    </v-card>

    <!-- ═══════════════ CARD VIEW ═══════════════ -->
    <div v-else>
      <div v-if="loading" class="cat-card-grid">
        <v-skeleton-loader v-for="n in 6" :key="n" type="article" rounded="xl" />
      </div>

      <div v-else-if="items.length" class="cat-card-grid">
        <div v-for="item in items" :key="item.id" class="cat-item-card"
             :class="{ 'cat-item-card--off': !item.is_active }">
          <div class="cat-item-card-top">
            <v-avatar size="38" rounded="lg" :color="categoryTone(item.category)" variant="tonal">
              <v-icon size="20">{{ config.icon }}</v-icon>
            </v-avatar>
            <div class="min-w-0 flex-grow-1">
              <div class="cat-item-card-name" :title="item.name">{{ item.name }}</div>
              <div class="cat-item-card-cat">{{ item.category ? prettyCategory(item.category) : 'Uncategorised' }}</div>
            </div>
            <v-chip size="x-small" variant="tonal" :color="item.source === 'seed' ? 'teal' : 'purple'">
              {{ item.source === 'seed' ? 'Seeded' : 'Custom' }}
            </v-chip>
          </div>

          <div v-if="config.extraKey === 'icd_code'" class="cat-item-card-icd">
            <v-icon size="13">mdi-barcode</v-icon>
            {{ item.icd_code || 'No ICD-10 code' }}
          </div>
          <div v-else class="cat-item-card-desc">
            {{ item[config.extraKey] || item.description || 'No symptoms recorded' }}
          </div>

          <div v-if="config.extraKey === 'icd_code' && item.description" class="cat-item-card-desc">
            {{ item.description }}
          </div>

          <div class="cat-item-card-foot">
            <v-switch :model-value="item.is_active" color="success" density="compact" hide-details inset
                      :disabled="!canAdmin || togglingId === item.id"
                      :label="item.is_active ? 'Active' : 'Inactive'"
                      @update:model-value="(v) => toggleActive(item, v)" />
            <v-spacer />
            <v-btn icon="mdi-pencil" variant="text" size="x-small" :disabled="!canAdmin"
                   @click="openForm(item)" />
            <v-btn icon="mdi-delete-outline" variant="text" size="x-small" color="error"
                   :disabled="!canAdmin" @click="confirmDelete(item)" />
          </div>
        </div>
      </div>

      <!-- Card view paging -->
      <div v-if="!loading && total > perPage" class="d-flex align-center justify-center ga-3 mt-4">
        <v-btn variant="tonal" size="small" rounded="lg" class="text-none" prepend-icon="mdi-chevron-left"
               :disabled="page <= 1" @click="gotoPage(page - 1)">Previous</v-btn>
        <span class="text-caption text-medium-emphasis">
          Page {{ page }} of {{ Math.max(1, Math.ceil(total / perPage)) }}
        </span>
        <v-btn variant="tonal" size="small" rounded="lg" class="text-none" append-icon="mdi-chevron-right"
               :disabled="page >= Math.ceil(total / perPage)" @click="gotoPage(page + 1)">Next</v-btn>
      </div>

      <v-card v-if="!loading && !items.length" flat rounded="xl" border class="pa-10 text-center">
        <v-icon size="56" color="grey-lighten-1">{{ config.icon }}</v-icon>
        <div class="text-subtitle-1 font-weight-bold mt-2">
          {{ hasFilters ? 'Nothing matches your filters' : `No ${config.plural.toLowerCase()} yet` }}
        </div>
        <div class="text-body-2 text-medium-emphasis mb-4">
          {{ hasFilters ? 'Try a different search term.' : 'Start by seeding the platform catalog.' }}
        </div>
        <v-btn color="primary" class="text-none" prepend-icon="mdi-database-import"
               :disabled="!canAdmin" @click="seedDialog = true">Seed catalog</v-btn>
      </v-card>
    </div>

    <!-- ═══════════════ CREATE / EDIT DIALOG ═══════════════ -->
    <v-dialog v-model="formDialog" max-width="660" persistent scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader :icon="form.id ? 'mdi-pencil' : config.icon"
                           :title="form.id ? `Edit ${config.singular.toLowerCase()}` : `New ${config.singular.toLowerCase()}`"
                           :subtitle="form.id ? form.name : config.formSubtitle"
                           @close="formDialog = false" />

        <v-card-text class="pa-5">
          <v-row dense>
            <v-col v-for="f in config.fields" :key="f.key" :cols="12" :sm="f.col || 12">
              <v-text-field v-if="f.type === 'text' || !f.type"
                            v-model="form[f.key]" :label="f.label" :placeholder="f.placeholder"
                            :required="f.required" variant="outlined" density="comfortable"
                            :prepend-inner-icon="f.icon" :error-messages="errors[f.key]"
                            @update:model-value="clearError(f.key)" />

              <v-textarea v-else-if="f.type === 'textarea'"
                          v-model="form[f.key]" :label="f.label" :placeholder="f.placeholder"
                          :required="f.required" variant="outlined" density="comfortable"
                          rows="2" auto-grow :prepend-inner-icon="f.icon" />

              <v-combobox v-else-if="f.type === 'combobox'"
                          v-model="form[f.key]" :items="f.options" :label="f.label"
                          :required="f.required" variant="outlined" density="comfortable"
                          :prepend-inner-icon="f.icon" :hide-no-data="false"
                          :error-messages="errors[f.key]" @update:model-value="clearError(f.key)" />

              <v-select v-else-if="f.type === 'select'"
                        v-model="form[f.key]" :items="f.options" :label="f.label"
                        :required="f.required" variant="outlined" density="comfortable"
                        :prepend-inner-icon="f.icon" :error-messages="errors[f.key]" />
            </v-col>

            <v-col cols="12">
              <div class="cat-status-row">
                <div class="d-flex align-center" style="gap:10px">
                  <v-icon :color="form.is_active ? 'success' : 'grey'" size="20">
                    {{ form.is_active ? 'mdi-check-circle' : 'mdi-pause-circle' }}
                  </v-icon>
                  <div>
                    <div class="text-body-2 font-weight-medium">
                      {{ form.is_active ? 'Active in catalog' : 'Hidden from catalog' }}
                    </div>
                    <div class="text-caption text-medium-emphasis">
                      Inactive entries stay stored but are not offered during clinical entry.
                    </div>
                  </div>
                </div>
                <v-switch v-model="form.is_active" color="success" density="compact" hide-details inset />
              </div>
            </v-col>
          </v-row>
        </v-card-text>

        <v-divider />
        <div class="d-flex align-center justify-end ga-2 pa-4">
          <v-btn variant="text" class="text-none" @click="formDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none"
                 :loading="saving" :prepend-icon="form.id ? 'mdi-content-save' : 'mdi-plus'"
                 @click="save">
            {{ form.id ? 'Save changes' : `Create ${config.singular.toLowerCase()}` }}
          </v-btn>
        </div>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ DELETE CONFIRM ═══════════════ -->
    <v-dialog v-model="deleteDialog" max-width="440">
      <v-card rounded="xl">
        <v-card-item>
          <template #prepend>
            <v-avatar color="error" variant="tonal" size="44">
              <v-icon>mdi-alert-outline</v-icon>
            </v-avatar>
          </template>
          <v-card-title class="font-weight-bold">Delete {{ config.singular.toLowerCase() }}?</v-card-title>
        </v-card-item>
        <v-card-text class="text-body-2 text-medium-emphasis">
          <strong class="text-high-emphasis">{{ pendingDelete?.name }}</strong> will be permanently
          removed from this clinic's catalog. Entries already recorded against patients are not affected.
        </v-card-text>
        <v-card-actions class="pa-4 pt-0">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" variant="flat" rounded="lg" class="text-none"
                 prepend-icon="mdi-delete" :loading="deleting" @click="doDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ SEED CONFIRM ═══════════════ -->
    <v-dialog v-model="seedDialog" max-width="500">
      <v-card rounded="xl">
        <v-card-item>
          <template #prepend>
            <v-avatar color="teal" variant="tonal" size="44">
              <v-icon>mdi-database-import</v-icon>
            </v-avatar>
          </template>
          <v-card-title class="font-weight-bold">Seed {{ config.plural.toLowerCase() }}?</v-card-title>
        </v-card-item>
        <v-card-text>
          <v-alert type="info" variant="tonal" rounded="lg" density="comfortable" class="mb-3">
            Copies every {{ config.singular.toLowerCase() }} from the platform clinical catalog into
            this clinic. Existing names are skipped, so this is safe to re-run.
          </v-alert>
          <div class="text-body-2 text-medium-emphasis">
            Currently <strong>{{ num(stats.total) }}</strong> {{ config.plural.toLowerCase() }} in this clinic.
          </div>
        </v-card-text>
        <v-card-actions class="pa-4 pt-0">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="seedDialog = false">Cancel</v-btn>
          <v-btn color="teal-darken-1" variant="flat" rounded="lg" class="text-none"
                 prepend-icon="mdi-database-import" :loading="seeding" @click="runSeed">
            Yes, seed now
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3200" rounded="lg">
      <div class="d-flex align-center" style="gap:8px">
        <v-icon size="18">{{ snack.color === 'error' ? 'mdi-alert-circle' : 'mdi-check-circle' }}</v-icon>
        {{ snack.text }}
      </div>
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'

const props = defineProps({
  /**
   * Page configuration. Everything that differs between Allergies and
   * Chronic Conditions lives here so the shell stays identical — same
   * premium layout, same interactions, same dialogs.
   */
  config: { type: Object, required: true },
})

const { $api } = useNuxtApp()
const auth = useAuthStore()
const brand = useBranding()

// ── Permissions ──────────────────────────────────────────────────────
const ADMIN_ROLES = ['tenant_admin', 'clinic_admin', 'admin', 'super_admin']
const canAdmin = computed(() => ADMIN_ROLES.includes(auth?.user?.role))

// ── Brand bridge (identical CSS-variable pattern as the page heroes) ──
const heroTheme = computed(() => ({
  '--hero-deep': brand.secondary.value,
  '--hero-main': brand.primary.value,
  '--hero-accent': brand.gradientStops.value[2],
  '--hero-ink': brand.ink.value,
  '--hero-glow': brand.tint('primary', 0.3),
  '--hero-glow-2': brand.tint('accent', 0.2),
  '--hero-shadow': brand.shadow.value,
}))

// ── State ────────────────────────────────────────────────────────────
const items = ref([])
const total = ref(0)
const loading = ref(false)
const page = ref(1)
const perPage = ref(25)
const ordering = ref('name')
const viewMode = ref('table')

const search = ref('')
const filterSource = ref('')
const filterActive = ref('all')
const filterCategory = ref('')

const stats = ref({ total: 0, active: 0, inactive: 0, seeded: 0, custom: 0, by_category: [], categories_count: 0 })

const snack = reactive({ show: false, text: '', color: 'success' })
function notify(text, color = 'success') {
  Object.assign(snack, { show: true, text, color })
}

const hasFilters = computed(() =>
  !!search.value || !!filterSource.value || filterActive.value !== 'all' || !!filterCategory.value
)

const activeFilter = computed(() => {
  if (filterActive.value === 'active') return 'active'
  if (filterActive.value === 'inactive') return 'inactive'
  if (filterSource.value === 'seed') return 'seeded'
  if (filterSource.value === 'custom') return 'custom'
  return ''
})

// ── KPI tiles ────────────────────────────────────────────────────────
// `filter` is the highlight key compared against `activeFilter`;
// `active` / `source` are the actual query values the API understands.
const kpiTiles = computed(() => [
  {
    key: 'total', label: `Total ${props.config.plural.toLowerCase()}`,
    value: stats.value.total, icon: props.config.icon,
    tone: brand.primary.value,
    hint: `${num(stats.value.categories_count)} categories`,
    filter: '',
  },
  {
    key: 'active', label: 'Active', value: stats.value.active,
    icon: 'mdi-check-circle-outline', tone: '#0d9488',
    hint: 'available in clinical entry',
    filter: 'active', active: 'active',
  },
  {
    key: 'seeded', label: 'Seeded', value: stats.value.seeded,
    icon: 'mdi-database-check-outline', tone: '#7c3aed',
    hint: 'from platform catalog',
    filter: 'seeded', source: 'seed',
  },
  {
    key: 'custom', label: 'Custom', value: stats.value.custom,
    icon: 'mdi-pencil-outline', tone: '#ea580c',
    hint: 'added by this clinic',
    filter: 'custom', source: 'custom',
  },
])

function applyKpiFilter(k) {
  if (k.active) {
    const on = filterActive.value === k.active
    filterActive.value = on ? 'all' : k.active
    filterSource.value = ''
  } else if (k.source) {
    const on = filterSource.value === k.source
    filterSource.value = on ? '' : k.source
    filterActive.value = 'all'
  } else {
    filterActive.value = 'all'
    filterSource.value = ''
  }
  filterCategory.value = ''
  applyFilters()
}

// ── Filter option lists ──────────────────────────────────────────────
const sourceOptions = [
  { value: '', label: 'All sources' },
  { value: 'seed', label: 'Seeded' },
  { value: 'custom', label: 'Custom' },
]
const activeOptions = [
  { value: 'all', label: 'All statuses' },
  { value: 'active', label: 'Active only' },
  { value: 'inactive', label: 'Inactive only' },
]

// ── Table headers (extra column configured per page) ─────────────────
const headers = computed(() => [
  { title: 'Name', key: 'name', sortable: true },
  { title: props.config.extraLabel, key: 'extra', sortable: false },
  { title: 'Category', key: 'category', sortable: true, width: 170 },
  { title: 'Source', key: 'source', sortable: true, width: 130, align: 'center' },
  { title: 'Active', key: 'is_active', sortable: true, width: 100, align: 'center' },
  { title: '', key: 'actions', sortable: false, width: 100, align: 'end' },
])

// ── Loading ──────────────────────────────────────────────────────────
async function load() {
  loading.value = true
  try {
    const params = {
      page: page.value,
      page_size: perPage.value,
      ordering: ordering.value,
      search: search.value?.trim() || undefined,
      source: filterSource.value || undefined,
      category: filterCategory.value || undefined,
      is_active: filterActive.value === 'all' ? undefined
        : String(filterActive.value === 'active'),
    }
    const { data } = await $api.get(props.config.endpoint, { params })
    if (Array.isArray(data)) {
      items.value = data
      total.value = data.length
    } else {
      items.value = data?.results || []
      total.value = data?.count ?? items.value.length
    }
  } catch {
    items.value = []
    total.value = 0
    notify(`Failed to load ${props.config.plural.toLowerCase()}`, 'error')
  } finally {
    loading.value = false
  }
}

async function loadStats() {
  try {
    const { data } = await $api.get(props.config.statsEndpoint)
    stats.value = { ...stats.value, ...data, by_category: data?.by_category || [] }
  } catch {
    /* stats are decorative — never block the page */
  }
}

function reloadAll() {
  load()
  loadStats()
}

let searchTimer = null
function debouncedLoad() {
  clearTimeout(searchTimer)
  searchTimer = setTimeout(() => { page.value = 1; load() }, 280)
}

function applyFilters() {
  page.value = 1
  load()
}

function setCategory(cat) {
  filterCategory.value = filterCategory.value === cat ? '' : cat
  applyFilters()
}

function clearFilters() {
  search.value = ''
  filterSource.value = ''
  filterActive.value = 'all'
  filterCategory.value = ''
  applyFilters()
}

function gotoPage(p) {
  if (p < 1) return
  page.value = p
  load()
}

function onOptions({ page: p, itemsPerPage, sortBy }) {
  page.value = p
  perPage.value = itemsPerPage
  if (sortBy?.length) {
    ordering.value = (sortBy[0].order === 'desc' ? '-' : '') + sortBy[0].key
  }
  load()
}

// ── Form ─────────────────────────────────────────────────────────────
const formDialog = ref(false)
const form = ref(blankForm())
const errors = reactive({})
const saving = ref(false)

function blankForm() {
  const base = { id: null, is_active: true }
  for (const f of props.config.fields) base[f.key] = ''
  return base
}
function openForm(row = null) {
  Object.keys(errors).forEach(k => delete errors[k])
  form.value = row ? { ...blankForm(), ...row } : blankForm()
  formDialog.value = true
}
function clearError(key) {
  if (errors[key]) delete errors[key]
}

async function save() {
  Object.keys(errors).forEach(k => delete errors[k])
  for (const f of props.config.fields) {
    if (f.required && !String(form.value[f.key] || '').trim()) {
      errors[f.key] = `${f.label.replace(' *', '')} is required`
    }
  }
  if (Object.keys(errors).length) return

  saving.value = true
  try {
    const payload = {}
    for (const f of props.config.fields) payload[f.key] = form.value[f.key]
    payload.is_active = form.value.is_active

    if (form.value.id) {
      await $api.patch(`${props.config.endpoint}${form.value.id}/`, payload)
      notify(`${props.config.singular} updated`)
    } else {
      await $api.post(props.config.endpoint, payload)
      notify(`${props.config.singular} created`)
    }
    formDialog.value = false
    reloadAll()
  } catch (e) {
    const d = e?.response?.data
    // Surface per-field validation errors returned by DRF.
    if (d && typeof d === 'object' && !d.detail) {
      Object.entries(d).forEach(([k, v]) => { errors[k] = Array.isArray(v) ? v[0] : String(v) })
    }
    notify(d?.detail || `Failed to save ${props.config.singular.toLowerCase()}`, 'error')
  } finally {
    saving.value = false
  }
}

// ── Active toggle ────────────────────────────────────────────────────
const togglingId = ref(null)
async function toggleActive(row, value) {
  togglingId.value = row.id
  const previous = row.is_active
  row.is_active = value
  try {
    await $api.patch(`${props.config.endpoint}${row.id}/`, { is_active: value })
    notify(`${row.name} ${value ? 'activated' : 'deactivated'}`)
    loadStats()
  } catch {
    row.is_active = previous
    notify('Failed to update status', 'error')
  } finally {
    togglingId.value = null
  }
}

// ── Delete ───────────────────────────────────────────────────────────
const deleteDialog = ref(false)
const pendingDelete = ref(null)
const deleting = ref(false)

function confirmDelete(row) {
  pendingDelete.value = row
  deleteDialog.value = true
}
async function doDelete() {
  deleting.value = true
  try {
    await $api.delete(`${props.config.endpoint}${pendingDelete.value.id}/`)
    notify(`${props.config.singular} deleted`)
    deleteDialog.value = false
    if (items.value.length === 1 && page.value > 1) page.value -= 1
    reloadAll()
  } catch {
    notify('Delete failed', 'error')
  } finally {
    deleting.value = false
  }
}

// ── Seeding ──────────────────────────────────────────────────────────
const seedDialog = ref(false)
const seeding = ref(false)
async function runSeed() {
  seeding.value = true
  try {
    const { data } = await $api.post(props.config.seedEndpoint)
    notify(data?.detail || 'Catalog seeded')
    seedDialog.value = false
    reloadAll()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Seed failed (admins only)', 'error')
  } finally {
    seeding.value = false
  }
}

// ── Presentation helpers ─────────────────────────────────────────────
function num(v) {
  return Number(v || 0).toLocaleString()
}

function prettyCategory(c) {
  return String(c || '').replace(/_/g, ' ')
}

// Deterministic tone per category so the same category always gets the same
// colour across table, cards and chips.
const CATEGORY_TONES = ['primary', 'teal', 'purple', 'orange-darken-2', 'blue-darken-1',
  'pink-darken-1', 'green-darken-2', 'indigo', 'cyan-darken-2', 'deep-orange']
function categoryTone(c) {
  if (!c) return 'grey'
  let h = 0
  for (let i = 0; i < c.length; i++) h = (h * 31 + c.charCodeAt(i)) % 9973
  return CATEGORY_TONES[h % CATEGORY_TONES.length]
}

onMounted(() => {
  load()
  loadStats()
})
</script>

<style scoped>
.min-w-0 { min-width: 0; }
.catalog-page { max-width: 1400px; margin: 0 auto; }

/* ── Hero ── */
.cat-hero {
  position: relative;
  overflow: hidden;
  border-radius: 18px;
  padding: 20px 22px 16px;
  color: #fff;
  background: linear-gradient(
    120deg,
    var(--hero-deep, #0f766e) 0%,
    var(--hero-main, #0d9488) 52%,
    var(--hero-accent, #14b8a6) 100%
  );
  box-shadow: var(--hero-shadow, 0 14px 34px rgba(13, 148, 136, 0.24));
}
.cat-hero-glow {
  position: absolute;
  width: 340px;
  height: 340px;
  border-radius: 50%;
  right: -110px;
  top: -170px;
  background: radial-gradient(circle, var(--hero-glow, rgba(255, 255, 255, 0.28)), transparent 68%);
  pointer-events: none;
}
.cat-hero-glow-2 {
  right: auto;
  left: -140px;
  top: auto;
  bottom: -220px;
  width: 300px;
  height: 300px;
  background: radial-gradient(circle, var(--hero-glow-2, rgba(20, 184, 166, 0.24)), transparent 70%);
}
.cat-hero-icon {
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
.cat-hero-eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: rgba(255, 255, 255, 0.78);
}
.cat-hero-title {
  font-size: 26px;
  line-height: 1.15;
  font-weight: 800;
  letter-spacing: -0.2px;
  margin: 2px 0;
}
.cat-hero-sub {
  font-size: 13px;
  color: rgba(255, 255, 255, 0.82);
  max-width: 680px;
}
.cat-hero-iconbtn {
  color: #fff;
}
.cat-hero-btn-glass,
.cat-hero-btn-strong {
  background: rgba(255, 255, 255, 0.16);
  color: #fff;
  border: 1px solid rgba(255, 255, 255, 0.3);
  backdrop-filter: blur(6px);
  transition: background 0.18s ease, transform 0.15s ease;
}
.cat-hero-btn-glass:hover {
  background: rgba(255, 255, 255, 0.26);
  transform: translateY(-1px);
}
.cat-hero-btn-strong {
  background: #fff;
  color: var(--hero-main, #0d9488);
  border-color: #fff;
  font-weight: 700;
}
.cat-hero-btn-strong:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 18px rgba(0, 0, 0, 0.16);
}
.cat-hero-foot {
  position: relative;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
  margin-top: 16px;
  padding-top: 14px;
  border-top: 1px solid rgba(255, 255, 255, 0.22);
}
.cat-hero-chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 5px 11px;
  border-radius: 999px;
  font-size: 11.5px;
  font-weight: 600;
  background: rgba(255, 255, 255, 0.14);
  border: 1px solid rgba(255, 255, 255, 0.22);
  backdrop-filter: blur(4px);
}

/* ── KPI tiles ── */
.cat-kpi {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 14px;
  height: 100%;
  border-radius: 14px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  background: rgb(var(--v-theme-surface));
  cursor: pointer;
  transition: transform 0.16s ease, box-shadow 0.16s ease, border-color 0.16s ease;
}
.cat-kpi:hover {
  transform: translateY(-2px);
  box-shadow: 0 10px 24px rgba(15, 23, 42, 0.09);
  border-color: color-mix(in srgb, var(--kpi-tone) 40%, transparent);
}
.cat-kpi--active {
  border-color: var(--kpi-tone);
  background: color-mix(in srgb, var(--kpi-tone) 7%, rgb(var(--v-theme-surface)));
}
.cat-kpi-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 38px;
  height: 38px;
  border-radius: 11px;
  flex-shrink: 0;
  color: #fff;
  background: var(--kpi-tone);
  box-shadow: 0 4px 12px color-mix(in srgb, var(--kpi-tone) 40%, transparent);
}
.cat-kpi-label {
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.6);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.cat-kpi-value {
  font-size: 23px;
  font-weight: 800;
  line-height: 1.15;
  letter-spacing: -0.3px;
}
.cat-kpi-hint {
  font-size: 11px;
  color: rgba(var(--v-theme-on-surface), 0.5);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

/* ── Category chips ── */
.cat-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 7px;
}
.cat-chip {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  padding: 6px 12px;
  border-radius: 999px;
  font-size: 12.5px;
  font-weight: 600;
  text-transform: capitalize;
  cursor: pointer;
  color: rgba(var(--v-theme-on-surface), 0.72);
  background: rgba(var(--v-theme-on-surface), 0.04);
  border: 1px solid rgba(var(--v-theme-on-surface), 0.1);
  transition: all 0.15s ease;
}
.cat-chip:hover {
  border-color: color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 45%, transparent);
  color: var(--brand-primary, rgb(var(--v-theme-primary)));
}
.cat-chip--on {
  background: var(--brand-primary, rgb(var(--v-theme-primary)));
  border-color: var(--brand-primary, rgb(var(--v-theme-primary)));
  color: #fff;
  box-shadow: 0 4px 12px color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 38%, transparent);
}
.cat-chip-count {
  font-size: 10.5px;
  font-weight: 800;
  padding: 1px 6px;
  border-radius: 999px;
  background: rgba(var(--v-theme-on-surface), 0.09);
}
.cat-chip--on .cat-chip-count {
  background: rgba(255, 255, 255, 0.28);
  color: #fff;
}

/* ── Surfaces ── */
.cat-toolbar,
.cat-surface {
  border-color: rgba(var(--v-theme-on-surface), 0.08) !important;
}
.cat-surface :deep(tbody tr) {
  transition: background 0.15s ease;
}

/* ── Card grid ── */
.cat-card-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(285px, 1fr));
  gap: 12px;
}
.cat-item-card {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 14px;
  border-radius: 14px;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
  transition: transform 0.16s ease, box-shadow 0.16s ease, border-color 0.16s ease;
}
.cat-item-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 12px 26px rgba(15, 23, 42, 0.1);
  border-color: color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 35%, transparent);
}
.cat-item-card--off {
  opacity: 0.62;
}
.cat-item-card-top {
  display: flex;
  align-items: flex-start;
  gap: 11px;
}
.cat-item-card-name {
  font-weight: 700;
  font-size: 0.92rem;
  line-height: 1.25;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.cat-item-card-cat {
  font-size: 11.5px;
  text-transform: capitalize;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.cat-item-card-icd {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  align-self: flex-start;
  padding: 3px 9px;
  border-radius: 7px;
  font-size: 11.5px;
  font-weight: 700;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  color: var(--brand-primary, rgb(var(--v-theme-primary)));
  background: color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 9%, transparent);
}
.cat-item-card-desc {
  font-size: 12px;
  line-height: 1.4;
  color: rgba(var(--v-theme-on-surface), 0.66);
  display: -webkit-box;
  -webkit-line-clamp: 2;
  line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.cat-item-card-foot {
  display: flex;
  align-items: center;
  gap: 4px;
  margin-top: auto;
  padding-top: 8px;
  border-top: 1px dashed rgba(var(--v-theme-on-surface), 0.12);
}
.cat-item-card-foot :deep(.v-label) {
  font-size: 11.5px;
  opacity: 0.8;
}

/* ── Status row in the form ── */
.cat-status-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 12px 14px;
  border-radius: 12px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.1);
  background: rgba(var(--v-theme-on-surface), 0.03);
}

@media (max-width: 600px) {
  .cat-hero-title { font-size: 21px; }
  .cat-card-grid { grid-template-columns: 1fr; }
}
</style>
