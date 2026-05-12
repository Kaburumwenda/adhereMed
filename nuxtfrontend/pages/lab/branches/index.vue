<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="teal-lighten-5" size="48">
        <v-icon color="teal-darken-2" size="28">mdi-bank</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Lab branches</div>
        <div class="text-body-2 text-medium-emphasis">
          Manage your lab locations, contact details &amp; coverage map
        </div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh"
             :loading="loading" @click="loadAll">Refresh</v-btn>
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-tray-arrow-down"
             @click="exportCsv">Export</v-btn>
      <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus"
             @click="openCreate">New branch</v-btn>
    </div>

    <!-- KPIs -->
    <v-row dense class="mb-1">
      <v-col v-for="k in kpiTiles" :key="k.label" cols="6" md="3">
        <v-card flat rounded="lg" class="kpi pa-3"
                @click="k.filter && (activeFilter = k.filter)" style="cursor: pointer">
          <div class="d-flex align-center">
            <v-avatar :color="k.color + '-lighten-5'" size="36" class="mr-2">
              <v-icon :color="k.color + '-darken-2'" size="20">{{ k.icon }}</v-icon>
            </v-avatar>
            <div class="min-width-0">
              <div class="text-overline text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h6 font-weight-bold">{{ k.value }}</div>
              <div v-if="k.sub" class="text-caption text-medium-emphasis">{{ k.sub }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Section pills -->
    <v-card flat rounded="lg" class="section-pills pa-2 my-3">
      <v-chip-group v-model="tab" mandatory selected-class="text-primary">
        <v-chip v-for="s in sectionPills" :key="s.value" :value="s.value"
                filter variant="tonal" :color="s.color">
          <v-icon size="16" start>{{ s.icon }}</v-icon>{{ s.label }}
        </v-chip>
      </v-chip-group>
    </v-card>

    <!-- ────────── Directory tab ────────── -->
    <template v-if="tab === 'directory'">
      <v-card flat rounded="lg" class="pa-3 mb-3 section-card">
        <v-row dense align="center">
          <v-col cols="12" md="6">
            <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                          placeholder="Search by name, address, phone or email…"
                          persistent-placeholder
                          variant="outlined" density="compact" rounded="lg"
                          hide-details clearable />
          </v-col>
          <v-col cols="6" md="3">
            <v-select v-model="activeFilter" :items="activeItems" label="Status"
                      variant="outlined" density="compact" rounded="lg"
                      persistent-placeholder hide-details />
          </v-col>
          <v-col cols="6" md="3" class="text-right">
            <v-chip color="teal" variant="tonal" rounded="lg">
              {{ filtered.length }} shown
            </v-chip>
          </v-col>
        </v-row>
      </v-card>

      <v-card flat rounded="lg" class="section-card">
        <v-data-table :headers="headers" :items="filtered" :loading="loading"
                      item-value="id" class="acct-table"
                      :items-per-page="25"
                      :items-per-page-options="[10, 25, 50, 100]">
          <template #item.name="{ item }">
            <div class="d-flex align-center py-1">
              <v-avatar :color="item.is_main ? 'amber-lighten-5' : 'teal-lighten-5'" size="36" class="mr-3">
                <v-icon :color="item.is_main ? 'amber-darken-2' : 'teal-darken-2'" size="20">
                  {{ item.is_main ? 'mdi-star' : 'mdi-bank' }}
                </v-icon>
              </v-avatar>
              <div class="min-width-0">
                <div class="font-weight-medium text-truncate">{{ item.name }}</div>
                <div v-if="item.is_main" class="text-caption text-amber-darken-2 font-weight-medium">
                  <v-icon size="12">mdi-star</v-icon> Main branch
                </div>
                <div v-else-if="item.place_name" class="text-caption text-medium-emphasis text-truncate">
                  {{ item.place_name }}
                </div>
              </div>
            </div>
          </template>

          <template #item.address="{ item }">
            <div class="address-cell">
              <span v-if="item.address" class="text-body-2">{{ item.address }}</span>
              <span v-else class="text-disabled">—</span>
              <div v-if="item.latitude != null && item.longitude != null"
                   class="text-caption text-medium-emphasis font-monospace">
                <v-icon size="12">mdi-map-marker</v-icon>
                {{ Number(item.latitude).toFixed(4) }}, {{ Number(item.longitude).toFixed(4) }}
              </div>
            </div>
          </template>

          <template #item.phone="{ item }">
            <span v-if="item.phone" class="font-monospace">{{ item.phone }}</span>
            <span v-else class="text-disabled">—</span>
          </template>

          <template #item.email="{ item }">
            <span v-if="item.email" class="text-caption">{{ item.email }}</span>
            <span v-else class="text-disabled">—</span>
          </template>

          <template #item.is_active="{ item }">
            <v-switch :model-value="item.is_active" color="success" inset hide-details density="compact"
                      class="mt-0" @update:model-value="(v) => toggleActive(item, v)" />
          </template>

          <template #item.actions="{ item }">
            <v-btn icon size="small" variant="text"
                   :disabled="item.is_main" @click="setMain(item)">
              <v-icon size="20" :color="item.is_main ? 'amber-darken-2' : ''">
                {{ item.is_main ? 'mdi-star' : 'mdi-star-outline' }}
              </v-icon>
              <v-tooltip activator="parent" location="top">
                {{ item.is_main ? 'Already main' : 'Set as main branch' }}
              </v-tooltip>
            </v-btn>
            <v-btn icon size="small" variant="text" @click="openEdit(item)">
              <v-icon size="20">mdi-pencil</v-icon>
              <v-tooltip activator="parent" location="top">Edit</v-tooltip>
            </v-btn>
            <v-btn icon size="small" variant="text" color="error" @click="confirmDelete(item)">
              <v-icon size="20">mdi-delete</v-icon>
              <v-tooltip activator="parent" location="top">Delete</v-tooltip>
            </v-btn>
          </template>

          <template #no-data>
            <div class="text-center pa-6 text-medium-emphasis">
              <v-icon size="48" color="grey-lighten-1">mdi-store-off</v-icon>
              <div class="mt-2">No branches yet.</div>
              <v-btn class="mt-3" color="primary" rounded="lg" variant="text"
                     prepend-icon="mdi-plus" @click="openCreate">
                Add your first branch
              </v-btn>
            </div>
          </template>
        </v-data-table>
      </v-card>
    </template>

    <!-- ────────── Cards tab ────────── -->
    <template v-if="tab === 'cards'">
      <v-card flat rounded="lg" class="pa-3 mb-3 section-card">
        <v-row dense align="center">
          <v-col cols="12" md="6">
            <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                          placeholder="Search…" persistent-placeholder
                          variant="outlined" density="compact" rounded="lg"
                          hide-details clearable />
          </v-col>
          <v-col cols="6" md="3">
            <v-select v-model="activeFilter" :items="activeItems" label="Status"
                      variant="outlined" density="compact" rounded="lg"
                      persistent-placeholder hide-details />
          </v-col>
        </v-row>
      </v-card>

      <v-row dense>
        <v-col v-for="b in filtered" :key="b.id" cols="12" sm="6" md="4" lg="3">
          <v-card flat rounded="lg" class="branch-card pa-3 h-100" :class="{ 'is-main': b.is_main, 'is-inactive': !b.is_active }">
            <div class="d-flex align-center mb-2">
              <v-avatar :color="b.is_main ? 'amber-lighten-5' : 'teal-lighten-5'" size="40" class="mr-3">
                <v-icon :color="b.is_main ? 'amber-darken-2' : 'teal-darken-2'" size="22">
                  {{ b.is_main ? 'mdi-star' : 'mdi-bank' }}
                </v-icon>
              </v-avatar>
              <div class="min-width-0 flex-grow-1">
                <div class="font-weight-bold text-truncate">{{ b.name }}</div>
                <div class="text-caption text-medium-emphasis">
                  <v-chip v-if="b.is_main" size="x-small" color="amber-darken-2" variant="tonal" class="mr-1">Main</v-chip>
                  <v-chip size="x-small" :color="b.is_active ? 'success' : 'grey'" variant="tonal">
                    {{ b.is_active ? 'Active' : 'Inactive' }}
                  </v-chip>
                </div>
              </div>
              <v-menu>
                <template #activator="{ props }">
                  <v-btn v-bind="props" icon size="small" variant="text">
                    <v-icon size="20">mdi-dots-vertical</v-icon>
                  </v-btn>
                </template>
                <v-list density="compact">
                  <v-list-item @click="openEdit(b)" prepend-icon="mdi-pencil" title="Edit" />
                  <v-list-item v-if="!b.is_main" @click="setMain(b)" prepend-icon="mdi-star" title="Set as main" />
                  <v-list-item @click="toggleActive(b, !b.is_active)"
                               :prepend-icon="b.is_active ? 'mdi-pause-circle' : 'mdi-play-circle'"
                               :title="b.is_active ? 'Deactivate' : 'Activate'" />
                  <v-divider />
                  <v-list-item @click="confirmDelete(b)" prepend-icon="mdi-delete"
                               base-color="error" title="Delete" />
                </v-list>
              </v-menu>
            </div>
            <v-divider class="mb-2" />
            <div class="text-body-2 mb-1" style="min-height: 40px">
              <v-icon size="14" color="grey-darken-1">mdi-map-marker-outline</v-icon>
              {{ b.address || '—' }}
            </div>
            <div v-if="b.phone" class="text-caption">
              <v-icon size="14" color="grey-darken-1">mdi-phone</v-icon>
              <span class="font-monospace ml-1">{{ b.phone }}</span>
            </div>
            <div v-if="b.email" class="text-caption text-truncate">
              <v-icon size="14" color="grey-darken-1">mdi-email-outline</v-icon>
              <span class="ml-1">{{ b.email }}</span>
            </div>
            <div v-if="b.latitude != null && b.longitude != null" class="text-caption text-medium-emphasis mt-2 font-monospace">
              <v-icon size="12">mdi-crosshairs-gps</v-icon>
              {{ Number(b.latitude).toFixed(5) }}, {{ Number(b.longitude).toFixed(5) }}
            </div>
          </v-card>
        </v-col>
        <v-col v-if="!filtered.length" cols="12">
          <v-card flat rounded="lg" class="pa-12 text-center section-card">
            <v-icon size="64" color="grey-lighten-1">mdi-store-off</v-icon>
            <div class="text-subtitle-1 font-weight-medium mt-3">No branches match your filters</div>
          </v-card>
        </v-col>
      </v-row>
    </template>

    <!-- ────────── Map tab ────────── -->
    <template v-if="tab === 'map'">
      <v-card flat rounded="lg" class="section-card pa-3">
        <div class="d-flex align-center flex-wrap ga-2 mb-3">
          <v-icon color="teal-darken-2">mdi-map</v-icon>
          <div class="text-subtitle-1 font-weight-bold">Branch coverage</div>
          <v-spacer />
          <v-chip size="small" variant="tonal" color="teal">
            {{ branchesWithGeo.length }} of {{ branches.length }} geocoded
          </v-chip>
        </div>

        <v-alert v-if="!branchesWithGeo.length" type="info" variant="tonal" density="compact" class="mb-3">
          No branches have coordinates yet. Edit a branch and pick its location on the map or via address search.
        </v-alert>

        <v-row dense>
          <v-col v-for="b in branchesWithGeo" :key="b.id" cols="12" sm="6" md="4">
            <v-card flat rounded="lg" class="map-row pa-3"
                    :href="mapsLink(b)" target="_blank">
              <div class="d-flex align-center">
                <v-avatar :color="b.is_main ? 'amber-lighten-5' : 'teal-lighten-5'" size="36" class="mr-3">
                  <v-icon :color="b.is_main ? 'amber-darken-2' : 'teal-darken-2'" size="20">
                    {{ b.is_main ? 'mdi-star' : 'mdi-map-marker' }}
                  </v-icon>
                </v-avatar>
                <div class="min-width-0 flex-grow-1">
                  <div class="font-weight-medium text-truncate">{{ b.name }}</div>
                  <div class="text-caption text-medium-emphasis text-truncate">{{ b.address || '—' }}</div>
                  <div class="text-caption font-monospace text-medium-emphasis">
                    {{ Number(b.latitude).toFixed(5) }}, {{ Number(b.longitude).toFixed(5) }}
                  </div>
                </div>
                <v-icon size="20" color="grey-darken-1">mdi-open-in-new</v-icon>
              </div>
            </v-card>
          </v-col>
        </v-row>
      </v-card>
    </template>

    <!-- ────────── Branch dialog ────────── -->
    <v-dialog v-model="formDialog" max-width="780" persistent scrollable>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="teal-lighten-5" size="40" class="mr-3">
            <v-icon color="teal-darken-2">mdi-bank</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">
              {{ form.id ? 'Edit branch' : 'New branch' }}
            </div>
            <div class="text-h6 font-weight-bold">
              {{ form.id ? form.name || 'Edit branch' : 'Create lab branch' }}
            </div>
          </div>
          <v-spacer />
          <v-btn icon variant="text" size="small" @click="formDialog = false">
            <v-icon>mdi-close</v-icon>
          </v-btn>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-row dense>
            <v-col cols="12">
              <v-text-field v-model="form.name" label="Branch name *"
                            placeholder="e.g. Westlands Diagnostic Centre"
                            variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details="auto"
                            :error-messages="errors.name">
                <template #prepend-inner>
                  <v-icon size="18" color="teal-darken-2">mdi-bank</v-icon>
                </template>
              </v-text-field>
            </v-col>

            <v-col cols="12">
              <v-autocomplete
                v-model="addressSelection"
                v-model:search="addressQuery"
                :items="addressPredictions"
                :loading="loadingPlaces"
                item-title="description"
                item-value="place_id"
                label="Search address (Google Places)"
                placeholder="Start typing an address…"
                variant="outlined" density="compact" rounded="lg"
                persistent-placeholder hide-details="auto"
                prepend-inner-icon="mdi-map-marker"
                return-object hide-no-data
                no-filter clearable
                @update:search="onAddressSearch"
                @update:model-value="onAddressPicked"
              >
                <template #append-inner>
                  <v-tooltip text="Pick on map" location="top">
                    <template #activator="{ props }">
                      <v-btn v-bind="props" icon="mdi-map-search" variant="text" size="small" color="teal"
                             @click.stop="openMapPicker" />
                    </template>
                  </v-tooltip>
                  <v-tooltip text="Use my current location" location="top">
                    <template #activator="{ props }">
                      <v-btn v-bind="props" icon="mdi-crosshairs-gps"
                             variant="text" size="small" color="indigo"
                             :loading="locating" @click.stop="useMyLocation" />
                    </template>
                  </v-tooltip>
                </template>
                <template #item="{ props: ip, item }">
                  <v-list-item v-bind="ip" prepend-icon="mdi-map-marker-outline">
                    <v-list-item-subtitle v-if="item.raw.structured_formatting?.secondary_text">
                      {{ item.raw.structured_formatting.secondary_text }}
                    </v-list-item-subtitle>
                  </v-list-item>
                </template>
              </v-autocomplete>
            </v-col>

            <v-col cols="12">
              <v-textarea v-model="form.address" label="Address (editable)"
                          placeholder="Street, building, city…"
                          rows="2" auto-grow
                          variant="outlined" density="compact" rounded="lg"
                          persistent-placeholder hide-details="auto"
                          prepend-inner-icon="mdi-pencil" />
            </v-col>

            <v-col v-if="form.latitude != null && form.longitude != null" cols="12">
              <v-card flat rounded="lg" class="pa-2 notes-card d-flex flex-wrap align-center ga-2">
                <v-chip size="small" variant="tonal" color="teal" prepend-icon="mdi-map-marker">
                  {{ Number(form.latitude).toFixed(6) }}, {{ Number(form.longitude).toFixed(6) }}
                </v-chip>
                <v-chip v-if="form.place_name" size="small" variant="tonal" color="success" prepend-icon="mdi-tag">
                  {{ form.place_name }}
                </v-chip>
                <v-spacer />
                <v-btn size="x-small" variant="text" color="error" prepend-icon="mdi-close" @click="clearGeo">
                  Clear coordinates
                </v-btn>
              </v-card>
            </v-col>

            <v-col cols="12" md="6">
              <v-text-field v-model="form.phone" label="Phone"
                            placeholder="+254…"
                            variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details>
                <template #prepend-inner>
                  <v-icon size="18" color="teal-darken-2">mdi-phone</v-icon>
                </template>
              </v-text-field>
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.email" label="Email" type="email"
                            placeholder="branch@lab.co.ke"
                            variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details>
                <template #prepend-inner>
                  <v-icon size="18" color="teal-darken-2">mdi-email-outline</v-icon>
                </template>
              </v-text-field>
            </v-col>

            <v-col cols="12" md="6" class="d-flex align-center">
              <v-switch v-model="form.is_main" label="Main branch" color="amber-darken-2"
                        inset density="compact" hide-details />
            </v-col>
            <v-col cols="12" md="6" class="d-flex align-center">
              <v-switch v-model="form.is_active" label="Active" color="success"
                        inset density="compact" hide-details />
            </v-col>

            <v-col v-if="form.is_main && hasOtherMain" cols="12">
              <v-alert type="warning" variant="tonal" density="compact" class="mt-1">
                Another branch is already marked as main. Saving will leave both flagged —
                consider unmarking the previous main branch.
              </v-alert>
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" @click="formDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" :loading="saving"
                 prepend-icon="mdi-content-save-outline" @click="save">
            {{ form.id ? 'Update branch' : 'Create branch' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ────────── Delete confirm ────────── -->
    <v-dialog v-model="deleteDialog" max-width="440" persistent>
      <v-card v-if="deleteTarget" rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="error-lighten-5" size="40" class="mr-3">
            <v-icon color="error">mdi-delete-alert</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">Confirm delete</div>
            <div class="text-h6 font-weight-bold">Delete branch?</div>
          </div>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          This will permanently remove <strong>{{ deleteTarget.name }}</strong>
          and may detach any staff or transactions linked to it.
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" :loading="saving"
                 prepend-icon="mdi-delete" @click="doDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" :timeout="2400">
      {{ snack.message }}
    </v-snackbar>

    <MapPicker v-model="mapPickerOpen" :initial="mapPickerInitial" @picked="onMapPicked" />
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'

const { $api } = useNuxtApp()

// ── State ───────────────────────────────────────────────
const loading = ref(false)
const saving = ref(false)
const branches = ref([])
const search = ref('')
const activeFilter = ref('all')
const tab = ref('directory')

const sectionPills = [
  { value: 'directory',       label: 'Directory',     color: 'teal',        icon: 'mdi-format-list-bulleted' },
  { value: 'cards',           label: 'Cards',         color: 'indigo',      icon: 'mdi-view-grid' },
  { value: 'map',             label: 'Coverage map',  color: 'deep-purple', icon: 'mdi-map' },
]

const activeItems = [
  { title: 'All', value: 'all' },
  { title: 'Active', value: 'active' },
  { title: 'Inactive', value: 'inactive' },
  { title: 'Main', value: 'main' },
]

const headers = [
  { title: 'Branch',       key: 'name' },
  { title: 'Address',      key: 'address' },
  { title: 'Phone',        key: 'phone' },
  { title: 'Email',        key: 'email' },
  { title: 'Active',       key: 'is_active', sortable: false, align: 'center', width: 100 },
  { title: '',             key: 'actions',   sortable: false, align: 'end',    width: 160 },
]

// ── Data loading ────────────────────────────────────────
async function loadAll() {
  loading.value = true
  try {
    const { data } = await $api.get('/pharmacy-profile/branches/', { params: { page_size: 200 } })
    branches.value = data?.results || data || []
  } catch (e) {
    notify(extractError(e) || 'Failed to load branches', 'error')
  } finally { loading.value = false }
}
onMounted(loadAll)

// ── Filtering ───────────────────────────────────────────
const filtered = computed(() => {
  const q = search.value.toLowerCase().trim()
  return branches.value.filter(b => {
    if (activeFilter.value === 'active'   && !b.is_active) return false
    if (activeFilter.value === 'inactive' &&  b.is_active) return false
    if (activeFilter.value === 'main'     && !b.is_main)   return false
    if (!q) return true
    return [b.name, b.address, b.phone, b.email, b.place_name]
      .some(v => (v || '').toString().toLowerCase().includes(q))
  })
})

const branchesWithGeo = computed(() =>
  branches.value.filter(b => b.latitude != null && b.longitude != null),
)

const kpiTiles = computed(() => {
  const total = branches.value.length
  const active = branches.value.filter(b => b.is_active).length
  const main = branches.value.filter(b => b.is_main).length
  const geo = branchesWithGeo.value.length
  return [
    { label: 'Total branches', value: total, icon: 'mdi-bank',          color: 'teal',          filter: 'all' },
    { label: 'Active',         value: active, icon: 'mdi-check-circle', color: 'green',         sub: `${total - active} inactive`, filter: 'active' },
    { label: 'Main branch',    value: main,  icon: 'mdi-star',          color: 'amber',         filter: 'main' },
    { label: 'Geocoded',       value: geo,   icon: 'mdi-map-marker-check', color: 'deep-purple', sub: `${total - geo} missing coords` },
  ]
})

const hasOtherMain = computed(() =>
  branches.value.some(b => b.is_main && b.id !== form.id),
)

// ── Form / dialog ───────────────────────────────────────
const formDialog = ref(false)
const form = reactive(blankForm())
const errors = reactive({})

function blankForm() {
  return {
    id: null, name: '', address: '', place_name: '',
    latitude: null, longitude: null,
    phone: '', email: '',
    is_main: false, is_active: true,
  }
}
function clearErrors() { Object.keys(errors).forEach(k => delete errors[k]) }
function clearGeo() { form.latitude = null; form.longitude = null; form.place_name = '' }

function openCreate() {
  Object.assign(form, blankForm())
  if (!branches.value.some(b => b.is_main)) form.is_main = true
  clearErrors(); resetAddressPicker(); formDialog.value = true
}
function openEdit(b) {
  Object.assign(form, blankForm(), b)
  clearErrors(); resetAddressPicker(b?.address || ''); formDialog.value = true
}

function round6(n) {
  if (n == null || n === '' || isNaN(Number(n))) return null
  return Math.round(Number(n) * 1e6) / 1e6
}

async function save() {
  clearErrors()
  if (!form.name?.trim()) { errors.name = 'Branch name is required'; return }
  saving.value = true
  try {
    const payload = { ...form }; delete payload.id
    if (form.id) await $api.put(`/pharmacy-profile/branches/${form.id}/`, payload)
    else         await $api.post('/pharmacy-profile/branches/', payload)
    notify(form.id ? 'Branch updated' : 'Branch created', 'success')
    formDialog.value = false
    await loadAll()
  } catch (e) {
    notify(extractError(e) || 'Save failed', 'error')
  } finally { saving.value = false }
}

// ── Quick actions ───────────────────────────────────────
async function toggleActive(item, value) {
  try {
    await $api.patch(`/pharmacy-profile/branches/${item.id}/`, { is_active: value })
    item.is_active = value
    notify(value ? 'Branch activated' : 'Branch deactivated', 'success')
  } catch (e) { notify(extractError(e) || 'Update failed', 'error') }
}
async function setMain(item) {
  if (item.is_main) return
  try {
    // Unset previous main(s) first.
    const prev = branches.value.filter(b => b.is_main && b.id !== item.id)
    await Promise.all(prev.map(b => $api.patch(`/pharmacy-profile/branches/${b.id}/`, { is_main: false })))
    await $api.patch(`/pharmacy-profile/branches/${item.id}/`, { is_main: true })
    notify(`${item.name} is now the main branch`, 'success')
    await loadAll()
  } catch (e) { notify(extractError(e) || 'Could not set main branch', 'error') }
}

// ── Delete ──────────────────────────────────────────────
const deleteDialog = ref(false)
const deleteTarget = ref(null)
function confirmDelete(b) { deleteTarget.value = b; deleteDialog.value = true }
async function doDelete() {
  saving.value = true
  try {
    await $api.delete(`/pharmacy-profile/branches/${deleteTarget.value.id}/`)
    notify('Branch deleted', 'success')
    deleteDialog.value = false
    await loadAll()
  } catch (e) { notify(extractError(e) || 'Delete failed', 'error') }
  finally { saving.value = false }
}

// ── Map picker ──────────────────────────────────────────
const mapPickerOpen = ref(false)
const mapPickerInitial = ref({})
function openMapPicker() {
  mapPickerInitial.value = {
    lat: form.latitude, lng: form.longitude,
    address: form.address, place_name: form.place_name,
  }
  mapPickerOpen.value = true
}
function onMapPicked(p) {
  form.latitude = round6(p.lat)
  form.longitude = round6(p.lng)
  if (p.address) { form.address = p.address; addressQuery.value = p.address }
  if (p.place_name) form.place_name = p.place_name
}

// ── Google Places autocomplete ─────────────────────────
const { getPredictions, getPlaceDetails, reverseGeocode } = useGoogleMaps()
const addressQuery = ref('')
const addressSelection = ref(null)
const addressPredictions = ref([])
const loadingPlaces = ref(false)
const locating = ref(false)
let _addrTimer = null

function resetAddressPicker(initial = '') {
  addressQuery.value = initial
  addressSelection.value = null
  addressPredictions.value = []
}
function onAddressSearch(q) {
  if (_addrTimer) clearTimeout(_addrTimer)
  if (!q || q.length < 3) { addressPredictions.value = []; return }
  loadingPlaces.value = true
  _addrTimer = setTimeout(async () => {
    try { addressPredictions.value = await getPredictions(q, { country: 'ke' }) }
    catch (e) { addressPredictions.value = []; notify(e?.message || 'Places lookup failed', 'error') }
    finally { loadingPlaces.value = false }
  }, 280)
}
async function onAddressPicked(pred) {
  if (!pred?.place_id) return
  try {
    const details = await getPlaceDetails(pred.place_id)
    form.address = details.address || pred.description
    form.latitude = round6(details.lat)
    form.longitude = round6(details.lng)
    form.place_name = details.name || (pred.structured_formatting?.main_text || '')
    addressQuery.value = form.address
  } catch (e) {
    form.address = pred.description
    notify(e?.message || 'Could not resolve place', 'error')
  }
}
function useMyLocation() {
  if (!navigator.geolocation) { notify('Geolocation not supported', 'error'); return }
  locating.value = true
  navigator.geolocation.getCurrentPosition(
    async ({ coords }) => {
      try {
        const addr = await reverseGeocode(coords.latitude, coords.longitude)
        form.address = addr
        form.latitude = round6(coords.latitude)
        form.longitude = round6(coords.longitude)
        addressQuery.value = addr
        notify('Address detected from your location', 'success')
      } catch (e) { notify(e?.message || 'Reverse geocoding failed', 'error') }
      finally { locating.value = false }
    },
    (err) => { locating.value = false; notify(err.message || 'Could not get location', 'error') },
    { enableHighAccuracy: true, timeout: 10000 },
  )
}

// ── Misc helpers ────────────────────────────────────────
function mapsLink(b) {
  if (b.latitude == null || b.longitude == null) return '#'
  return `https://www.google.com/maps/search/?api=1&query=${b.latitude},${b.longitude}`
}

function exportCsv() {
  const rows = filtered.value
  if (!rows.length) { notify('Nothing to export', 'warning'); return }
  const headers = ['Name', 'Address', 'Place', 'Phone', 'Email', 'Latitude', 'Longitude', 'Main', 'Active']
  const csv = [headers.join(',')]
  for (const b of rows) {
    csv.push([
      b.name, b.address || '', b.place_name || '', b.phone || '', b.email || '',
      b.latitude ?? '', b.longitude ?? '',
      b.is_main ? 'Yes' : 'No', b.is_active ? 'Yes' : 'No',
    ].map(v => `"${String(v).replace(/"/g, '""')}"`).join(','))
  }
  const blob = new Blob([csv.join('\n')], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = `lab-branches-${new Date().toISOString().slice(0, 10)}.csv`
  a.click(); URL.revokeObjectURL(url)
}

function extractError(e) {
  const d = e?.response?.data
  if (!d) return e?.message || ''
  if (typeof d === 'string') return d
  if (d.detail) return d.detail
  return Object.entries(d).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(' ') : v}`).join(' · ')
}

const snack = reactive({ show: false, color: 'success', message: '' })
function notify(message, color = 'success') { Object.assign(snack, { show: true, color, message }) }
</script>

<style scoped>
.kpi {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.kpi:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0, 0, 0, 0.06); }
.section-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.section-pills {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.notes-card {
  background: rgba(var(--v-theme-warning), 0.06);
  border: 1px solid rgba(var(--v-theme-warning), 0.2);
}
.branch-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.branch-card:hover { transform: translateY(-2px); box-shadow: 0 8px 22px rgba(0, 0, 0, 0.08); }
.branch-card.is-main { border-color: rgba(var(--v-theme-warning), 0.4); }
.branch-card.is-inactive { opacity: 0.7; }
.map-row {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  text-decoration: none;
  color: inherit;
  display: block;
  transition: transform 0.15s ease, box-shadow 0.15s ease, border-color 0.15s ease;
}
.map-row:hover {
  transform: translateY(-1px);
  border-color: rgba(var(--v-theme-teal), 0.4);
  box-shadow: 0 6px 18px rgba(0, 0, 0, 0.06);
}
.address-cell { line-height: 1.3; }
.min-width-0 { min-width: 0; }
.font-monospace { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
.acct-table :deep(tbody tr:hover) {
  background: #e0f2f1 !important;
}
</style>
