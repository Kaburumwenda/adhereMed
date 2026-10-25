<template>
  <v-container fluid class="pa-4 pa-md-6 cs-page" :style="themeVars">
    <!-- ═══════════════ Header ═══════════════ -->
    <header class="cs-head">
      <div class="cs-head-top">
        <div class="cs-head-icon">
          <v-icon size="26">mdi-office-building-marker</v-icon>
        </div>

        <div class="cs-head-id">
          <div class="cs-head-eyebrow">
            <span class="cs-live-dot"></span>
            CLINIC NETWORK
          </div>
          <h1 class="cs-head-title">Clinics &amp; sites</h1>
          <p class="cs-head-sub">{{ headSub }}</p>
        </div>

        <div class="cs-head-actions">
          <button type="button" class="cs-btn" :disabled="loading || !clinics.length" @click="exportCsv">
            <v-icon size="15">mdi-tray-arrow-down</v-icon>
            <span>Export</span>
          </button>
          <button type="button" class="cs-btn" :disabled="loading" @click="loadAll">
            <v-icon size="15" :class="{ 'cs-spin': loading }">mdi-refresh</v-icon>
            <span>Refresh</span>
          </button>
          <button type="button" class="cs-btn is-primary" @click="openCreate">
            <v-icon size="16">mdi-plus</v-icon>
            <span>Add clinic</span>
          </button>
        </div>
      </div>

      <div class="cs-head-foot">
        <span class="cs-chip">
          <v-icon size="13">mdi-office-building-outline</v-icon>
          {{ fmt(clinics.length) }} clinic{{ clinics.length === 1 ? '' : 's' }}
        </span>
        <span class="cs-chip is-good">
          <v-icon size="13">mdi-check-circle-outline</v-icon>
          {{ fmt(activeCount) }} active
        </span>
        <span class="cs-chip is-hq">
          <v-icon size="13">mdi-crown-outline</v-icon>
          HQ · {{ hq?.name || 'not set' }}
        </span>
        <span class="cs-chip">
          <v-icon size="13">mdi-account-multiple-outline</v-icon>
          {{ fmt(totals.patients) }} patients
        </span>
        <span class="cs-chip">
          <v-icon size="13">mdi-calendar-check-outline</v-icon>
          {{ fmt(totals.appointments) }} appointments
        </span>
        <span class="cs-head-stamp">{{ updatedLabel }}</span>
      </div>
    </header>

    <!-- ═══════════════ KPI tiles ═══════════════ -->
    <div class="cs-kpis">
      <article
        v-for="k in kpiTiles"
        :key="k.key"
        class="cs-kpi"
        :style="{ '--tone': k.tone }"
      >
        <div class="cs-kpi-top">
          <span class="cs-kpi-icon"><v-icon size="16">{{ k.icon }}</v-icon></span>
          <span class="cs-kpi-label">{{ k.label }}</span>
        </div>
        <div class="cs-kpi-value">{{ k.value }}</div>
        <div class="cs-kpi-sub">{{ k.sub }}</div>
      </article>
    </div>

    <!-- ═══════════════ Toolbar ═══════════════ -->
    <section class="cs-toolbar">
      <v-text-field
        v-model="search"
        prepend-inner-icon="mdi-magnify"
        placeholder="Search clinics by name, code, area or phone…"
        variant="outlined"
        density="compact"
        rounded="lg"
        hide-details
        clearable
        class="cs-search"
      />

      <v-select
        v-model="statusFilter"
        :items="statusOptions"
        variant="outlined"
        density="compact"
        rounded="lg"
        hide-details
        class="cs-filter"
      />

      <div class="cs-viewtoggle">
        <button type="button" :class="{ 'is-on': view === 'grid' }" title="Card view" @click="view = 'grid'">
          <v-icon size="17">mdi-view-grid-outline</v-icon>
        </button>
        <button type="button" :class="{ 'is-on': view === 'table' }" title="Table view" @click="view = 'table'">
          <v-icon size="17">mdi-format-list-bulleted</v-icon>
        </button>
      </div>
    </section>

    <!-- ═══════════════ Loading ═══════════════ -->
    <div v-if="loading && !clinics.length" class="cs-grid">
      <div v-for="n in 3" :key="n" class="cs-skel"></div>
    </div>

    <!-- ═══════════════ Empty ═══════════════ -->
    <section v-else-if="!filtered.length" class="cs-empty">
      <div class="cs-empty-icon"><v-icon size="34">mdi-hospital-building</v-icon></div>
      <h2>{{ clinics.length ? 'No clinic matches this filter' : 'No clinics yet' }}</h2>
      <p>
        {{ clinics.length
          ? 'Try a different search term or clear the status filter.'
          : 'Add the HQ and every branch that operates under this clinic tenant.' }}
      </p>
      <button v-if="!clinics.length" type="button" class="cs-btn is-primary" @click="openCreate">
        <v-icon size="16">mdi-plus</v-icon>
        <span>Add the first clinic</span>
      </button>
      <button v-else type="button" class="cs-btn" @click="clearFilters">
        <v-icon size="15">mdi-filter-remove-outline</v-icon>
        <span>Clear filters</span>
      </button>
    </section>

    <!-- ═══════════════ Cards ═══════════════ -->
    <div v-else-if="view === 'grid'" class="cs-grid">
      <article
        v-for="site in filtered"
        :key="site.id"
        class="cs-card"
        :class="{ 'is-hq': site.is_hq, 'is-off': !site.is_active }"
      >
        <div class="cs-card-top">
          <span class="cs-card-glyph">
            <v-icon size="20">{{ site.is_hq ? 'mdi-crown' : 'mdi-office-building' }}</v-icon>
          </span>

          <div class="cs-card-titles">
            <h2 :title="site.name">{{ site.name }}</h2>
            <div class="cs-card-meta">
              <span class="cs-code">{{ site.code }}</span>
              <span>{{ kindLabel(site.kind) }}</span>
              <span v-if="site.place_name">· {{ site.place_name }}</span>
            </div>
          </div>

          <span v-if="site.is_hq" class="cs-badge is-hq">
            <v-icon size="11">mdi-crown</v-icon>HQ
          </span>
          <span v-else class="cs-badge" :class="site.is_active ? 'is-on' : 'is-off'">
            {{ site.is_active ? 'Active' : 'Inactive' }}
          </span>
        </div>

        <div class="cs-card-body">
          <div class="cs-row">
            <v-icon size="14">mdi-map-outline</v-icon>
            <span :class="{ 'is-faint': !site.address }">{{ site.address || 'No address recorded' }}</span>
          </div>
          <div class="cs-row">
            <v-icon size="14">mdi-phone-outline</v-icon>
            <span :class="{ 'is-faint': !site.phone }">{{ site.phone || 'No phone number' }}</span>
          </div>
          <div class="cs-row">
            <v-icon size="14">mdi-email-outline</v-icon>
            <span :class="{ 'is-faint': !site.email }">{{ site.email || 'No email address' }}</span>
          </div>
          <div class="cs-row">
            <v-icon size="14">mdi-account-tie-outline</v-icon>
            <span :class="{ 'is-faint': !site.manager_name }">
              {{ site.manager_name || 'No clinic manager' }}
            </span>
          </div>

          <div class="cs-stats">
            <div><span>Patients</span><strong>{{ fmt(site.counts?.patients) }}</strong></div>
            <div><span>Visits</span><strong>{{ fmt(site.counts?.appointments) }}</strong></div>
            <div><span>Consults</span><strong>{{ fmt(site.counts?.consultations) }}</strong></div>
            <div><span>Invoices</span><strong>{{ fmt(site.counts?.invoices) }}</strong></div>
          </div>

          <div v-if="site.is_hq" class="cs-hq-note">
            <v-icon size="13">mdi-information-outline</v-icon>
            <span>Headquarters owns every record created before the clinic was split.</span>
          </div>
        </div>

        <footer class="cs-card-foot">
          <v-switch
            :model-value="site.is_active"
            color="success"
            density="compact"
            hide-details
            inset
            class="cs-switch"
            :disabled="site.is_hq"
            :loading="busyId === site.id"
            @update:model-value="(v) => toggleActive(site, v)"
          />
          <span class="cs-card-foot-label">{{ site.is_active ? 'Operating' : 'Paused' }}</span>

          <v-spacer />

          <button
            type="button"
            class="cs-mini"
            :class="{ 'is-starred': site.is_hq }"
            :disabled="site.is_hq || busyId === site.id"
            :title="site.is_hq ? 'Already the HQ clinic' : 'Make this the HQ clinic'"
            @click="makeHq(site)"
          >
            <v-icon size="15">{{ site.is_hq ? 'mdi-crown' : 'mdi-crown-outline' }}</v-icon>
          </button>
          <button type="button" class="cs-mini" title="Edit clinic" @click="openEdit(site)">
            <v-icon size="15">mdi-pencil-outline</v-icon>
          </button>
          <button
            type="button"
            class="cs-mini is-danger"
            :disabled="site.is_hq"
            title="Remove clinic"
            @click="askDelete(site)"
          >
            <v-icon size="15">mdi-trash-can-outline</v-icon>
          </button>
        </footer>
      </article>
    </div>

    <!-- ═══════════════ Table ═══════════════ -->
    <v-card v-else flat rounded="lg" class="cs-table-card">
      <v-data-table
        :headers="headers"
        :items="filtered"
        :loading="loading"
        item-value="id"
        hover
        :items-per-page="25"
        :items-per-page-options="[10, 25, 50, 100]"
        @click:row="(_, { item }) => openEdit(item)"
      >
        <template #item.name="{ item }">
          <div class="cs-cell-name">
            <span class="cs-cell-glyph" :class="{ 'is-hq': item.is_hq }">
              <v-icon size="16">{{ item.is_hq ? 'mdi-crown' : 'mdi-office-building' }}</v-icon>
            </span>
            <div class="min-width-0">
              <div class="cs-cell-title">{{ item.name }}</div>
              <div class="cs-cell-sub">
                {{ item.code }} · {{ kindLabel(item.kind) }}
                <template v-if="item.place_name"> · {{ item.place_name }}</template>
              </div>
            </div>
          </div>
        </template>

        <template #item.address="{ item }">
          <span v-if="item.address" class="cs-cell-wrap">{{ item.address }}</span>
          <span v-else class="cs-dash">—</span>
        </template>

        <template #item.phone="{ item }">
          <span v-if="item.phone" class="cs-mono">{{ item.phone }}</span>
          <span v-else class="cs-dash">—</span>
        </template>

        <template #item.patients="{ item }">
          <span class="cs-mono">{{ fmt(item.counts?.patients) }}</span>
        </template>

        <template #item.appointments="{ item }">
          <span class="cs-mono">{{ fmt(item.counts?.appointments) }}</span>
        </template>

        <template #item.is_active="{ item }">
          <v-switch
            :model-value="item.is_active"
            color="success"
            density="compact"
            hide-details
            inset
            class="cs-switch"
            :disabled="item.is_hq"
            :loading="busyId === item.id"
            @update:model-value="(v) => toggleActive(item, v)"
            @click.stop
          />
        </template>

        <template #item.actions="{ item }">
          <div class="cs-cell-actions" @click.stop>
            <button
              type="button"
              class="cs-mini"
              :class="{ 'is-starred': item.is_hq }"
              :disabled="item.is_hq"
              :title="item.is_hq ? 'Already HQ' : 'Make HQ'"
              @click="makeHq(item)"
            >
              <v-icon size="15">{{ item.is_hq ? 'mdi-crown' : 'mdi-crown-outline' }}</v-icon>
            </button>
            <button type="button" class="cs-mini" title="Edit" @click="openEdit(item)">
              <v-icon size="15">mdi-pencil-outline</v-icon>
            </button>
            <button
              type="button"
              class="cs-mini is-danger"
              :disabled="item.is_hq"
              title="Remove"
              @click="askDelete(item)"
            >
              <v-icon size="15">mdi-trash-can-outline</v-icon>
            </button>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- ═══════════════ Network note ═══════════════ -->
    <section class="cs-note">
      <span class="cs-note-icon"><v-icon size="17">mdi-sitemap-outline</v-icon></span>
      <div>
        <h2>How multi-clinic data works</h2>
        <p>
          This tenant holds clinical data for every clinic in the network. The
          <strong>HQ clinic</strong> owns all records created before the clinic was split, and it is the
          default when no clinic is selected. New patients, appointments, consultations, invoices, lab
          orders and prescriptions are stamped with the clinic they were created at.
        </p>
        <div class="cs-note-links">
          <button type="button" class="cs-link" @click="navigateTo('/clinics')">Open dashboard</button>
          <span>·</span>
          <button type="button" class="cs-link" @click="navigateTo('/clinics/drug-stores')">Drug stores</button>
          <span>·</span>
          <button type="button" class="cs-link" @click="navigateTo('/clinics/settings')">Facility profile</button>
        </div>
      </div>
    </section>

    <!-- ═══════════════ Add / edit dialog ═══════════════ -->
    <v-dialog v-model="formOpen" max-width="680" persistent scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader
          :icon="editing ? 'mdi-pencil-outline' : 'mdi-office-building-plus-outline'"
          :title="editing ? 'Edit clinic' : 'Add clinic'"
          :subtitle="editing
            ? 'Update this clinic’s identity, contact details and capacity'
            : 'Register another physical clinic in this tenant'"
          @close="closeForm"
        >
          <template #actions>
            <span class="cs-dialog-chip">{{ form.is_hq ? 'Headquarters' : kindLabel(form.kind) }}</span>
          </template>
        </BrandDialogHeader>

        <v-card-text class="pt-4">
          <div class="cs-form-note">
            <v-icon size="15">mdi-information-outline</v-icon>
            <span>
              Every clinic shares this tenant's patients, staff and catalogue. The clinic you pick here
              is stamped on new appointments, consultations and bills so reporting can be split by location.
            </span>
          </div>

          <div class="cs-field-row">
            <div class="cs-field">
              <label class="cs-label">Clinic name <span class="cs-req">*</span></label>
              <v-text-field
                v-model="form.name"
                placeholder="e.g. CityCare Westlands"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                prepend-inner-icon="mdi-hospital-building"
                hide-details="auto"
                :error-messages="errors.name"
                autofocus
              />
            </div>
            <div class="cs-field is-narrow">
              <label class="cs-label">Code</label>
              <v-text-field
                v-model="form.code"
                placeholder="Auto"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                hide-details
                maxlength="12"
              />
            </div>
          </div>

          <div class="cs-field-row">
            <div class="cs-field">
              <label class="cs-label">Clinic type</label>
              <v-select
                v-model="form.kind"
                :items="kindOptions"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                hide-details
              />
            </div>
            <div class="cs-field">
              <label class="cs-label">Area / neighbourhood</label>
              <v-text-field
                v-model="form.place_name"
                placeholder="e.g. Kilimani"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                hide-details
              />
            </div>
          </div>

          <div class="cs-field-row">
            <div class="cs-field">
              <label class="cs-label">City</label>
              <v-text-field
                v-model="form.city"
                placeholder="Nairobi"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                hide-details
              />
            </div>
            <div class="cs-field">
              <label class="cs-label">Phone</label>
              <v-text-field
                v-model="form.phone"
                placeholder="+254 700 000 000"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                hide-details
              />
            </div>
          </div>

          <div class="cs-field">
            <label class="cs-label">Email</label>
            <v-text-field
              v-model="form.email"
              type="email"
              placeholder="clinic@example.co"
              variant="outlined"
              density="comfortable"
              rounded="lg"
              prepend-inner-icon="mdi-email-outline"
              hide-details="auto"
              :error-messages="errors.email"
            />
          </div>

          <div class="cs-field">
            <label class="cs-label">Address</label>
            <v-textarea
              v-model="form.address"
              rows="2"
              auto-grow
              placeholder="Street, building, floor…"
              variant="outlined"
              density="comfortable"
              rounded="lg"
              hide-details
            />
          </div>

          <div class="cs-field-row">
            <div class="cs-field">
              <label class="cs-label">Facility licence</label>
              <v-text-field
                v-model="form.license_number"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                prepend-inner-icon="mdi-card-account-details-outline"
                hide-details
              />
            </div>
            <div class="cs-field">
              <label class="cs-label">Bed capacity</label>
              <v-text-field
                v-model.number="form.bed_capacity"
                type="number"
                min="0"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                prepend-inner-icon="mdi-bed-outline"
                hide-details
              />
            </div>
          </div>

          <div class="cs-toggle-row">
            <div class="cs-toggle">
              <div>
                <strong>Operating</strong>
                <span>Inactive clinics keep their history but take no new records</span>
              </div>
              <v-switch
                v-model="form.is_active"
                color="success"
                density="compact"
                hide-details
                inset
                :disabled="form.is_hq"
              />
            </div>
            <div class="cs-toggle">
              <div>
                <strong>Headquarters</strong>
                <span>Owns pre-split records and is the default clinic</span>
              </div>
              <v-switch
                v-model="form.is_hq"
                color="amber-darken-3"
                density="compact"
                hide-details
                inset
              />
            </div>
          </div>
        </v-card-text>

        <v-divider />

        <v-card-actions class="px-5 py-3">
          <v-btn variant="text" rounded="lg" class="text-none" :disabled="saving" @click="closeForm">
            Cancel
          </v-btn>
          <v-spacer />
          <v-btn
            color="primary"
            variant="flat"
            rounded="lg"
            class="text-none"
            :loading="saving"
            :prepend-icon="editing ? 'mdi-content-save-outline' : 'mdi-plus'"
            @click="save"
          >
            {{ editing ? 'Save changes' : 'Add clinic' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ Delete confirm ═══════════════ -->
    <v-dialog v-model="deleteOpen" max-width="460">
      <v-card rounded="xl">
        <BrandDialogHeader
          icon="mdi-trash-can-outline"
          title="Remove clinic"
          :subtitle="deleteTarget?.name || ''"
          @close="deleteOpen = false"
        />
        <v-card-text class="pt-4">
          <p class="cs-confirm-text">
            This removes <strong>{{ deleteTarget?.name }}</strong> from the network. Clinics that still
            own patients, appointments or consultations cannot be removed — deactivate them instead.
          </p>
        </v-card-text>
        <v-card-actions class="px-5 py-3">
          <v-btn variant="text" rounded="lg" class="text-none" @click="deleteOpen = false">Cancel</v-btn>
          <v-spacer />
          <v-btn
            color="error"
            variant="flat"
            rounded="lg"
            class="text-none"
            :loading="deleting"
            prepend-icon="mdi-trash-can-outline"
            @click="confirmDelete"
          >
            Remove clinic
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="bottom right" rounded="lg" timeout="4200">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const brand = useBranding()
const bank = useClinicSite()

const api = '/clinic-sites/'

const clinics = ref([])
const loading = ref(false)
const saving = ref(false)
const deleting = ref(false)
const busyId = ref(null)
const updatedAt = ref(null)
const now = ref(Date.now())

const search = ref('')
const statusFilter = ref('all')
const view = ref('grid')

const formOpen = ref(false)
const editing = ref(null)
const errors = reactive({ name: '', email: '' })
const form = reactive(blankForm())

const deleteOpen = ref(false)
const deleteTarget = ref(null)

const snack = reactive({ show: false, color: 'success', text: '' })
function notify(text, color = 'success') {
  Object.assign(snack, { show: true, color, text })
}

const statusOptions = [
  { title: 'All clinics', value: 'all' },
  { title: 'Active', value: 'active' },
  { title: 'Inactive', value: 'inactive' },
  { title: 'HQ clinic', value: 'hq' },
]

const kindOptions = [
  { title: 'Headquarters', value: 'hq' },
  { title: 'Branch clinic', value: 'branch' },
  { title: 'Satellite clinic', value: 'satellite' },
  { title: 'Outreach / mobile', value: 'outreach' },
]

const headers = [
  { title: 'Clinic', key: 'name', sortable: true },
  { title: 'Address', key: 'address', sortable: false },
  { title: 'Phone', key: 'phone', sortable: false, width: 150 },
  { title: 'Patients', key: 'patients', sortable: false, width: 100 },
  { title: 'Visits', key: 'appointments', sortable: false, width: 100 },
  { title: 'Active', key: 'is_active', sortable: false, width: 100 },
  { title: '', key: 'actions', sortable: false, width: 130 },
]

const themeVars = computed(() => ({
  '--cs-accent': brand.primary.value,
  '--cs-on-accent': brand.onPrimary.value,
  '--cs-accent-ink': brand.ink.value,
  '--cs-accent-soft': brand.tint('primary', 0.18),
  '--cs-accent-ring': brand.tint('primary', 0.24),
}))

// ── Derived ─────────────────────────────────────────────────────────────
const hq = computed(() => clinics.value.find(s => s.is_hq) || null)
const activeCount = computed(() => clinics.value.filter(s => s.is_active).length)

const totals = computed(() => ({
  patients: clinics.value.reduce((n, s) => n + (Number(s.counts?.patients) || 0), 0),
  appointments: clinics.value.reduce((n, s) => n + (Number(s.counts?.appointments) || 0), 0),
  consultations: clinics.value.reduce((n, s) => n + (Number(s.counts?.consultations) || 0), 0),
}))

const headSub = computed(() => {
  if (!clinics.value.length) {
    return 'One tenant, many clinics. Register the HQ and every branch that operates under it.'
  }
  const branches = clinics.value.length - 1
  return `${clinics.value.length} clinic${clinics.value.length === 1 ? '' : 's'} · ` +
    `${branches} branch${branches === 1 ? '' : 'es'} · HQ is ${hq.value?.name || 'not set'}`
})

const updatedLabel = computed(() => {
  if (!updatedAt.value) return 'Not synced yet'
  const mins = Math.floor((now.value - updatedAt.value) / 60000)
  if (mins < 1) return 'Synced just now'
  if (mins < 60) return `Synced ${mins}m ago`
  return `Synced ${Math.floor(mins / 60)}h ago`
})

const kpiTiles = computed(() => [
  {
    key: 'total', label: 'Clinics', icon: 'mdi-office-building-marker', tone: '#2f6dff',
    value: fmt(clinics.value.length), sub: 'in this tenant',
  },
  {
    key: 'active', label: 'Operating', icon: 'mdi-check-decagram-outline', tone: '#10b981',
    value: fmt(activeCount.value), sub: 'accepting patients',
  },
  {
    key: 'hq', label: 'Headquarters', icon: 'mdi-crown-outline', tone: '#f59e0b',
    value: hq.value?.code || '—', sub: hq.value?.name || 'not set',
  },
  {
    key: 'patients', label: 'Patients', icon: 'mdi-account-multiple-outline', tone: '#8b5cf6',
    value: fmt(totals.value.patients), sub: `${fmt(totals.value.consultations)} consultations`,
  },
])

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  return clinics.value.filter((s) => {
    if (statusFilter.value === 'active' && !s.is_active) return false
    if (statusFilter.value === 'inactive' && s.is_active) return false
    if (statusFilter.value === 'hq' && !s.is_hq) return false
    if (!q) return true
    return [s.name, s.code, s.place_name, s.city, s.address, s.phone, s.email]
      .some(v => String(v || '').toLowerCase().includes(q))
  })
})

// ── Formatting ──────────────────────────────────────────────────────────
function fmt(n) {
  return (Number(n) || 0).toLocaleString('en-US')
}
function kindLabel(kind) {
  return kindOptions.find(k => k.value === kind)?.title || 'Branch clinic'
}
function blankForm() {
  return {
    name: '', code: '', kind: 'branch', place_name: '', city: '',
    address: '', phone: '', email: '', license_number: '',
    bed_capacity: 0, is_hq: false, is_active: true,
  }
}

// ── Data ────────────────────────────────────────────────────────────────
function rowsOf(payload) {
  if (Array.isArray(payload)) return payload
  return payload?.results || []
}

async function loadAll({ silent = false } = {}) {
  if (!silent) loading.value = true
  try {
    const { data } = await $api.get(api, { params: { page_size: 200, ordering: 'name' } })
    clinics.value = rowsOf(data)
    updatedAt.value = Date.now()
    now.value = Date.now()
    bank.invalidate()
    await bank.loadSites(true)
  } catch (e) {
    if (!silent) notify(apiMessage(e, 'Could not load clinics.'), 'error')
  } finally {
    if (!silent) loading.value = false
  }
}

onMounted(loadAll)

// ── Validation ──────────────────────────────────────────────────────────
function validate() {
  errors.name = form.name.trim() ? '' : 'A clinic name is required.'
  const email = form.email.trim()
  errors.email = !email || /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
    ? ''
    : 'Enter a valid email address.'
  return !errors.name && !errors.email
}

// ── CRUD ────────────────────────────────────────────────────────────────
function openCreate() {
  editing.value = null
  Object.assign(form, blankForm(), { is_hq: !clinics.value.some(s => s.is_hq) })
  errors.name = ''
  errors.email = ''
  formOpen.value = true
}

function openEdit(site) {
  editing.value = site
  Object.assign(form, blankForm(), {
    name: site.name || '',
    code: site.code || '',
    kind: site.kind || 'branch',
    place_name: site.place_name || '',
    city: site.city || '',
    address: site.address || '',
    phone: site.phone || '',
    email: site.email || '',
    license_number: site.license_number || '',
    bed_capacity: site.bed_capacity || 0,
    is_hq: !!site.is_hq,
    is_active: site.is_active !== false,
  })
  errors.name = ''
  errors.email = ''
  formOpen.value = true
}

function closeForm() {
  if (saving.value) return
  formOpen.value = false
  editing.value = null
}

function payload() {
  return {
    name: form.name.trim(),
    code: form.code.trim(),
    kind: form.is_hq ? 'hq' : form.kind,
    place_name: form.place_name.trim(),
    city: form.city.trim(),
    address: form.address.trim(),
    phone: form.phone.trim(),
    email: form.email.trim(),
    license_number: form.license_number.trim(),
    bed_capacity: Number(form.bed_capacity) || 0,
    is_hq: !!form.is_hq,
    is_active: !!form.is_active,
  }
}

async function save() {
  if (!validate()) return
  saving.value = true
  try {
    if (editing.value) {
      const { data } = await $api.patch(`${api}${editing.value.id}/`, payload())
      notify(`${data?.name || 'Clinic'} updated.`)
    } else {
      const { data } = await $api.post(api, payload())
      notify(`${data?.name || 'Clinic'} added to the network.`)
    }
    formOpen.value = false
    editing.value = null
    await loadAll({ silent: true })
  } catch (e) {
    notify(apiMessage(e, 'Could not save the clinic.'), 'error')
  } finally {
    saving.value = false
  }
}

async function toggleActive(site, value) {
  busyId.value = site.id
  try {
    await $api.patch(`${api}${site.id}/`, { is_active: !!value })
    site.is_active = !!value
    notify(`${site.name} is ${value ? 'now operating' : 'paused'}.`)
  } catch (e) {
    notify(apiMessage(e, 'Could not update this clinic.'), 'error')
  } finally {
    busyId.value = null
  }
}

async function makeHq(site) {
  if (site.is_hq) return
  busyId.value = site.id
  try {
    await $api.post(`${api}${site.id}/set-hq/`)
    notify(`${site.name} is now the HQ clinic.`)
    await loadAll({ silent: true })
  } catch (e) {
    notify(apiMessage(e, 'Could not promote this clinic.'), 'error')
  } finally {
    busyId.value = null
  }
}

function askDelete(site) {
  deleteTarget.value = site
  deleteOpen.value = true
}

async function confirmDelete() {
  if (!deleteTarget.value) return
  deleting.value = true
  try {
    await $api.delete(`${api}${deleteTarget.value.id}/`)
    notify(`${deleteTarget.value.name} removed.`)
    deleteOpen.value = false
    deleteTarget.value = null
    await loadAll({ silent: true })
  } catch (e) {
    notify(apiMessage(e, 'Could not remove this clinic.'), 'error')
  } finally {
    deleting.value = false
  }
}

function apiMessage(e, fallback) {
  const data = e?.response?.data
  if (typeof data === 'string' && data) return data
  if (data?.detail) return data.detail
  if (data && typeof data === 'object') {
    const first = Object.entries(data)[0]
    if (first) {
      const [field, value] = first
      return `${field.replace(/_/g, ' ')}: ${Array.isArray(value) ? value.join(', ') : value}`
    }
  }
  return e?.message || fallback
}

function clearFilters() {
  search.value = ''
  statusFilter.value = 'all'
}

// ── Export ──────────────────────────────────────────────────────────────
function exportCsv() {
  if (!import.meta.client || !filtered.value.length) return
  const rows = [['Clinic', 'Code', 'Type', 'HQ', 'Active', 'Area', 'City', 'Address', 'Phone', 'Email', 'Patients', 'Visits', 'Consults']]
  filtered.value.forEach((s) => {
    rows.push([
      s.name || '', s.code || '', kindLabel(s.kind), s.is_hq ? 'Yes' : 'No',
      s.is_active ? 'Yes' : 'No', s.place_name || '', s.city || '', s.address || '',
      s.phone || '', s.email || '',
      s.counts?.patients ?? 0, s.counts?.appointments ?? 0, s.counts?.consultations ?? 0,
    ])
  })
  const csv = rows
    .map(row => row.map(cell => `"${String(cell ?? '').replace(/"/g, '""')}"`).join(','))
    .join('\r\n')
  const blob = new Blob([`\ufeff${csv}`], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = `clinic-network-${new Date().toISOString().slice(0, 10)}.csv`
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
  URL.revokeObjectURL(url)
  notify('Clinic network exported.', 'success')
}
</script>

<style scoped>
/* ══ Page tokens ═══════════════════════════════════════════════════════ */
.cs-page {
  width: 100%;
  --cs-line: rgba(var(--v-theme-on-surface), 0.09);
  --cs-line-soft: rgba(var(--v-theme-on-surface), 0.06);
  --cs-muted: rgba(var(--v-theme-on-surface), 0.6);
  --cs-faint: rgba(var(--v-theme-on-surface), 0.44);
  --cs-surface: rgb(var(--v-theme-surface));
  --cs-raise: rgba(var(--v-theme-on-surface), 0.035);
}

/* ══ Header ════════════════════════════════════════════════════════════ */
.cs-head {
  position: relative;
  border-radius: 18px;
  padding: 17px 20px 12px;
  margin-bottom: 14px;
  background: var(--cs-surface);
  border: 1px solid var(--cs-line);
  box-shadow: 0 10px 30px rgba(15, 23, 42, 0.055);
  overflow: hidden;
}
.cs-head::before {
  content: '';
  position: absolute;
  inset: 0 auto 0 0;
  width: 4px;
  background: linear-gradient(180deg, var(--cs-accent), var(--cs-accent-soft));
}
.cs-head-top { display: flex; align-items: center; gap: 14px; flex-wrap: wrap; min-width: 0; }
.cs-head-icon {
  width: 50px; height: 50px;
  border-radius: 15px;
  display: grid; place-items: center;
  flex-shrink: 0;
  color: var(--cs-accent-ink);
  background: color-mix(in srgb, var(--cs-accent) 12%, transparent);
  border: 1px solid color-mix(in srgb, var(--cs-accent) 22%, transparent);
}
.cs-head-id { flex: 1; min-width: 220px; }
.cs-head-eyebrow {
  display: inline-flex; align-items: center; gap: 6px;
  font-size: 9.5px; font-weight: 800; letter-spacing: 1.4px;
  text-transform: uppercase; color: var(--cs-faint);
}
.cs-head-title {
  margin: 3px 0 2px;
  font-size: 24px; line-height: 1.15; font-weight: 800; letter-spacing: -0.4px;
}
.cs-head-sub { margin: 0; font-size: 12.5px; line-height: 1.45; color: var(--cs-muted); }
.cs-head-actions { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; justify-content: flex-end; }
.cs-head-foot {
  display: flex; align-items: center; gap: 7px; flex-wrap: wrap;
  margin-top: 13px; padding-top: 11px; border-top: 1px solid var(--cs-line-soft);
}
.cs-head-stamp { margin-left: auto; font-size: 10.5px; font-weight: 700; color: var(--cs-faint); white-space: nowrap; }

.cs-live-dot {
  width: 7px; height: 7px; border-radius: 50%;
  background: #22c55e;
  box-shadow: 0 0 0 0 rgba(34, 197, 94, 0.55);
  animation: csPulse 2s infinite;
}
@keyframes csPulse {
  0% { box-shadow: 0 0 0 0 rgba(34, 197, 94, 0.5); }
  70% { box-shadow: 0 0 0 6px rgba(34, 197, 94, 0); }
  100% { box-shadow: 0 0 0 0 rgba(34, 197, 94, 0); }
}

.cs-chip {
  display: inline-flex; align-items: center; gap: 5px;
  height: 25px; padding: 0 9px;
  border-radius: 999px;
  border: 1px solid var(--cs-line);
  background: var(--cs-raise);
  font-size: 10.5px; font-weight: 700; color: var(--cs-muted);
  white-space: nowrap; max-width: 280px; overflow: hidden; text-overflow: ellipsis;
}
.cs-chip.is-good { color: #047857; border-color: rgba(16, 185, 129, 0.28); background: rgba(16, 185, 129, 0.08); }
.cs-chip.is-hq { color: #92400e; border-color: rgba(245, 158, 11, 0.3); background: rgba(245, 158, 11, 0.09); }

.cs-btn {
  display: inline-flex; align-items: center; gap: 6px;
  height: 36px; padding: 0 13px;
  border-radius: 10px;
  border: 1px solid var(--cs-line);
  background: transparent;
  color: rgb(var(--v-theme-on-surface));
  font-family: inherit; font-size: 12.5px; font-weight: 700;
  cursor: pointer; white-space: nowrap;
  transition: background 0.15s ease, transform 0.15s ease, opacity 0.15s ease;
}
.cs-btn:hover:not(:disabled) { background: rgba(var(--v-theme-on-surface), 0.045); transform: translateY(-1px); }
.cs-btn:disabled { opacity: 0.5; cursor: not-allowed; }
.cs-btn.is-primary {
  background: var(--cs-accent);
  color: var(--cs-on-accent);
  border-color: transparent;
  box-shadow: 0 7px 18px var(--cs-accent-ring);
}
/* Keep the solid fill on hover — the generic hover rule would otherwise win
   on specificity and leave a white label on a transparent background. */
.cs-btn.is-primary:hover:not(:disabled) {
  background: var(--cs-accent);
  color: var(--cs-on-accent);
  border-color: transparent;
  filter: brightness(1.06);
}
.cs-btn.is-primary:active:not(:disabled) { filter: brightness(0.96); }
.cs-spin { animation: csSpin 0.9s linear infinite; }
@keyframes csSpin { to { transform: rotate(360deg); } }

/* ══ KPIs ══════════════════════════════════════════════════════════════ */
.cs-kpis {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 11px;
  margin-bottom: 14px;
}
.cs-kpi {
  position: relative;
  padding: 12px 14px 11px;
  border-radius: 15px;
  background: var(--cs-surface);
  border: 1px solid var(--cs-line);
  overflow: hidden;
}
.cs-kpi::before {
  content: '';
  position: absolute;
  inset: 0 auto 0 0;
  width: 3px;
  background: var(--tone);
  opacity: 0.72;
}
.cs-kpi-top { display: flex; align-items: center; gap: 7px; margin-bottom: 6px; }
.cs-kpi-icon {
  width: 27px; height: 27px; border-radius: 9px;
  display: grid; place-items: center; flex-shrink: 0;
  color: var(--tone);
  background: color-mix(in srgb, var(--tone) 12%, transparent);
}
.cs-kpi-label {
  font-size: 9.5px; font-weight: 800; letter-spacing: 0.7px;
  text-transform: uppercase; color: var(--cs-faint);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.cs-kpi-value {
  font-size: 23px; font-weight: 800; line-height: 1.1;
  letter-spacing: -0.4px; color: var(--tone);
  font-variant-numeric: tabular-nums;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.cs-kpi-sub {
  margin-top: 2px; font-size: 10.5px; font-weight: 600; color: var(--cs-muted);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}

/* ══ Toolbar ═══════════════════════════════════════════════════════════ */
.cs-toolbar {
  display: flex; align-items: center; gap: 9px; flex-wrap: wrap;
  padding: 10px 12px; margin-bottom: 14px;
  border-radius: 14px;
  border: 1px solid var(--cs-line);
  background: var(--cs-surface);
}
.cs-search { flex: 1 1 320px; min-width: 200px; }
.cs-filter { flex: 0 1 168px; min-width: 132px; }
.cs-toolbar :deep(.v-field) { font-size: 12.5px; }

.cs-viewtoggle {
  display: inline-flex; gap: 2px; padding: 3px;
  border-radius: 10px;
  border: 1px solid var(--cs-line);
  background: var(--cs-raise);
}
.cs-viewtoggle button {
  width: 30px; height: 28px;
  display: grid; place-items: center;
  border: 0; border-radius: 8px;
  background: transparent; color: var(--cs-muted);
  cursor: pointer;
  transition: background 0.15s ease, color 0.15s ease;
}
.cs-viewtoggle button.is-on {
  background: var(--cs-surface);
  color: var(--cs-accent);
  box-shadow: 0 1px 5px rgba(15, 23, 42, 0.12);
}

/* ══ Grid + cards ══════════════════════════════════════════════════════ */
.cs-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 12px;
  margin-bottom: 14px;
}
.cs-skel {
  height: 260px;
  border-radius: 15px;
  border: 1px solid var(--cs-line-soft);
  background: linear-gradient(
    100deg,
    rgba(var(--v-theme-on-surface), 0.04) 20%,
    rgba(var(--v-theme-on-surface), 0.08) 38%,
    rgba(var(--v-theme-on-surface), 0.04) 56%
  );
  background-size: 220% 100%;
  animation: csShimmer 1.4s ease-in-out infinite;
}
@keyframes csShimmer {
  0% { background-position: 120% 0; }
  100% { background-position: -40% 0; }
}

.cs-card {
  display: flex; flex-direction: column;
  border-radius: 15px;
  border: 1px solid var(--cs-line);
  background: var(--cs-surface);
  overflow: hidden;
  transition: transform 0.16s ease, box-shadow 0.16s ease, border-color 0.16s ease;
}
.cs-card:hover {
  transform: translateY(-2px);
  border-color: color-mix(in srgb, var(--cs-accent) 30%, transparent);
  box-shadow: 0 12px 26px rgba(15, 23, 42, 0.09);
}
.cs-card.is-hq { border-color: rgba(245, 158, 11, 0.42); }
.cs-card.is-off { opacity: 0.84; }

.cs-card-top {
  display: flex; align-items: flex-start; gap: 10px;
  padding: 12px 13px 10px;
  border-bottom: 1px solid var(--cs-line-soft);
  background: linear-gradient(180deg, rgba(var(--v-theme-on-surface), 0.022), transparent);
}
.cs-card-glyph {
  width: 38px; height: 38px; border-radius: 11px;
  display: grid; place-items: center; flex-shrink: 0;
  color: var(--cs-accent-ink);
  background: color-mix(in srgb, var(--cs-accent) 12%, transparent);
  border: 1px solid color-mix(in srgb, var(--cs-accent) 20%, transparent);
}
.cs-card.is-hq .cs-card-glyph {
  color: #b45309;
  background: rgba(245, 158, 11, 0.14);
  border-color: rgba(245, 158, 11, 0.28);
}
.cs-card-titles { flex: 1; min-width: 0; }
.cs-card-titles h2 {
  margin: 0; font-size: 13.5px; font-weight: 800; line-height: 1.25; letter-spacing: -0.1px;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.cs-card-meta {
  display: flex; align-items: center; gap: 5px; flex-wrap: nowrap;
  margin-top: 2px; font-size: 10.5px; font-weight: 700; color: var(--cs-muted);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.cs-code {
  display: inline-flex; align-items: center; height: 17px; padding: 0 5px;
  border-radius: 5px; font-size: 8.5px; font-weight: 800; letter-spacing: 0.6px;
  color: var(--cs-muted);
  background: rgba(var(--v-theme-on-surface), 0.07);
}

.cs-badge {
  display: inline-flex; align-items: center; gap: 3px;
  height: 21px; padding: 0 7px;
  border-radius: 999px;
  font-size: 9px; font-weight: 800; letter-spacing: 0.3px;
  text-transform: uppercase; white-space: nowrap; flex-shrink: 0;
  border: 1px solid transparent;
}
.cs-badge.is-hq { color: #92400e; background: rgba(245, 158, 11, 0.16); border-color: rgba(245, 158, 11, 0.3); }
.cs-badge.is-on { color: #047857; background: rgba(16, 185, 129, 0.13); border-color: rgba(16, 185, 129, 0.25); }
.cs-badge.is-off { color: var(--cs-faint); background: rgba(var(--v-theme-on-surface), 0.06); border-color: var(--cs-line-soft); }

.cs-card-body { display: flex; flex-direction: column; gap: 6px; padding: 11px 13px; flex: 1; min-width: 0; }
.cs-row {
  display: flex; align-items: flex-start; gap: 7px;
  font-size: 11px; line-height: 1.45; color: var(--cs-muted); min-width: 0;
}
.cs-row .v-icon { color: var(--cs-faint); flex-shrink: 0; margin-top: 1px; }
.cs-row span { min-width: 0; overflow-wrap: anywhere; }
.cs-row span.is-faint { color: var(--cs-faint); font-style: italic; }

.cs-stats {
  display: grid; grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 6px; margin-top: 4px; padding-top: 9px;
  border-top: 1px solid var(--cs-line-soft);
}
.cs-stats > div { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
.cs-stats span {
  font-size: 8.5px; font-weight: 800; letter-spacing: 0.5px;
  text-transform: uppercase; color: var(--cs-faint);
}
.cs-stats strong { font-size: 12px; font-weight: 800; font-variant-numeric: tabular-nums; }

.cs-hq-note {
  display: flex; align-items: flex-start; gap: 6px;
  margin-top: 7px; padding: 7px 9px;
  border-radius: 9px;
  border: 1px solid rgba(245, 158, 11, 0.22);
  background: rgba(245, 158, 11, 0.07);
  font-size: 9.5px; line-height: 1.45; color: var(--cs-muted);
}
.cs-hq-note .v-icon { color: #b45309; flex-shrink: 0; margin-top: 1px; }

.cs-card-foot {
  display: flex; align-items: center; gap: 6px;
  padding: 7px 11px 8px;
  border-top: 1px solid var(--cs-line-soft);
  background: rgba(var(--v-theme-on-surface), 0.02);
}
.cs-card-foot-label {
  font-size: 9.5px; font-weight: 800; letter-spacing: 0.4px;
  text-transform: uppercase; color: var(--cs-faint);
}
.cs-switch { flex-shrink: 0; }

.cs-mini {
  width: 28px; height: 28px;
  display: grid; place-items: center;
  border-radius: 8px;
  border: 1px solid transparent;
  background: transparent;
  color: var(--cs-muted);
  cursor: pointer;
  transition: background 0.15s ease, color 0.15s ease, border-color 0.15s ease;
}
.cs-mini:hover:not(:disabled) {
  background: rgba(var(--v-theme-on-surface), 0.06);
  border-color: var(--cs-line);
  color: rgb(var(--v-theme-on-surface));
}
.cs-mini:disabled { opacity: 0.42; cursor: not-allowed; }
.cs-mini.is-starred { color: #d97706; }
.cs-mini.is-danger:hover:not(:disabled) { color: #dc2626; background: rgba(239, 68, 68, 0.1); border-color: rgba(239, 68, 68, 0.22); }

/* ══ Table ═════════════════════════════════════════════════════════════ */
.cs-table-card { margin-bottom: 14px; overflow: hidden; }
.cs-table-card :deep(.v-data-table__th) { font-size: 10.5px !important; }
.cs-cell-name { display: flex; align-items: center; gap: 9px; min-width: 0; padding: 2px 0; }
.cs-cell-glyph {
  width: 30px; height: 30px; border-radius: 9px;
  display: grid; place-items: center; flex-shrink: 0;
  color: var(--cs-muted);
  background: rgba(var(--v-theme-on-surface), 0.06);
}
.cs-cell-glyph.is-hq { color: #b45309; background: rgba(245, 158, 11, 0.14); }
.cs-cell-title { font-size: 12px; font-weight: 700; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cs-cell-sub { font-size: 9.5px; font-weight: 700; color: var(--cs-faint); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cs-cell-wrap { font-size: 11px; color: var(--cs-muted); overflow-wrap: anywhere; }
.cs-cell-actions { display: flex; align-items: center; gap: 2px; }
.cs-mono { font-size: 11px; font-weight: 700; font-variant-numeric: tabular-nums; }
.cs-dash { color: var(--cs-faint); }

/* ══ Empty ═════════════════════════════════════════════════════════════ */
.cs-empty {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: 6px; padding: 44px 20px; margin-bottom: 14px;
  border-radius: 16px;
  border: 1px dashed var(--cs-line);
  background: var(--cs-raise);
  text-align: center;
}
.cs-empty-icon {
  width: 62px; height: 62px; border-radius: 18px;
  display: grid; place-items: center; margin-bottom: 4px;
  color: var(--cs-accent);
  background: color-mix(in srgb, var(--cs-accent) 10%, transparent);
  border: 1px solid color-mix(in srgb, var(--cs-accent) 20%, transparent);
}
.cs-empty h2 { margin: 0; font-size: 16px; font-weight: 800; letter-spacing: -0.2px; }
.cs-empty p { margin: 0 0 8px; max-width: 520px; font-size: 12px; line-height: 1.55; color: var(--cs-muted); }

/* ══ Network note ══════════════════════════════════════════════════════ */
.cs-note {
  display: flex; gap: 11px;
  padding: 14px 16px;
  border-radius: 15px;
  border: 1px solid var(--cs-line);
  background: var(--cs-surface);
}
.cs-note-icon {
  width: 32px; height: 32px; border-radius: 10px;
  display: grid; place-items: center; flex-shrink: 0;
  color: var(--cs-accent-ink);
  background: color-mix(in srgb, var(--cs-accent) 11%, transparent);
}
.cs-note h2 { margin: 0 0 2px; font-size: 12.5px; font-weight: 800; }
.cs-note p { margin: 0; font-size: 11.5px; line-height: 1.55; color: var(--cs-muted); max-width: 900px; }
.cs-note-links { display: flex; align-items: center; gap: 6px; margin-top: 6px; font-size: 10.5px; color: var(--cs-faint); }
.cs-link {
  border: 0; background: none; padding: 0;
  font-family: inherit; font-size: inherit; font-weight: 800;
  color: var(--cs-accent); cursor: pointer;
  text-decoration: underline; text-underline-offset: 2px;
}

/* ══ Dialog ════════════════════════════════════════════════════════════ */
.cs-dialog-chip {
  display: inline-flex; align-items: center;
  height: 22px; padding: 0 8px;
  border-radius: 999px;
  font-size: 9.5px; font-weight: 800; letter-spacing: 0.3px; text-transform: uppercase;
  background: rgba(255, 255, 255, 0.18);
  border: 1px solid rgba(255, 255, 255, 0.32);
  color: #fff; white-space: nowrap;
}
.cs-form-note {
  display: flex; align-items: flex-start; gap: 8px;
  padding: 9px 11px; margin-bottom: 14px;
  border-radius: 10px;
  border: 1px solid var(--cs-line-soft);
  background: var(--cs-raise);
  font-size: 11px; line-height: 1.5; color: var(--cs-muted);
}
.cs-form-note .v-icon { color: var(--cs-accent); flex-shrink: 0; margin-top: 1px; }

.cs-field { margin-bottom: 12px; min-width: 0; }
.cs-field-row { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
.cs-field-row .cs-field.is-narrow { max-width: 150px; }
.cs-label {
  display: block; margin-bottom: 5px;
  font-size: 10.5px; font-weight: 800; letter-spacing: 0.5px;
  text-transform: uppercase; color: var(--cs-faint);
}
.cs-req { color: #dc2626; }

.cs-toggle-row { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-top: 2px; }
.cs-toggle {
  display: flex; align-items: center; justify-content: space-between; gap: 10px;
  padding: 9px 11px;
  border-radius: 11px;
  border: 1px solid var(--cs-line-soft);
  background: var(--cs-raise);
  min-width: 0;
}
.cs-toggle div { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
.cs-toggle strong { font-size: 11.5px; font-weight: 800; }
.cs-toggle span { font-size: 9.5px; line-height: 1.35; color: var(--cs-faint); }

.cs-confirm-text { margin: 0; font-size: 12.5px; line-height: 1.6; color: var(--cs-muted); }
.cs-confirm-text strong { color: rgb(var(--v-theme-on-surface)); }

/* ══ Responsive ════════════════════════════════════════════════════════ */
@media (max-width: 959px) {
  .cs-kpis { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .cs-head-actions { width: 100%; justify-content: flex-start; }
  .cs-head-stamp { margin-left: 0; }
}
@media (max-width: 767px) {
  .cs-kpi-value { font-size: 19px; }
  .cs-head-title { font-size: 20px; }
  .cs-search { flex-basis: 100%; }
  .cs-filter { flex: 1 1 140px; }
  .cs-grid { grid-template-columns: minmax(0, 1fr); }
  .cs-field-row, .cs-toggle-row { grid-template-columns: minmax(0, 1fr); }
  .cs-field-row .cs-field.is-narrow { max-width: none; }
}
</style>
