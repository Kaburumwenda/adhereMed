<template>
  <div class="hc-bg pa-4 pa-md-6">
    <!-- Hero -->
    <HomecareHero
      title="Care Notes"
      subtitle="Shift notes, observations, incidents, and patient updates."
      eyebrow="HOMECARE · DOCUMENTATION"
      icon="mdi-note-edit"
      :chips="[
        { icon: 'mdi-note-multiple', label: `${notes.length} notes` },
        { icon: 'mdi-account-heart', label: `${caregiverCount} caregivers` },
        { icon: 'mdi-account-injury', label: `${patientCount} patients` }
      ]"
    >
      <template #actions>
        <v-btn variant="elevated" rounded="pill" color="teal-darken-2"
               prepend-icon="mdi-plus" class="text-none px-5 py-2" style="font-size:1.1rem;letter-spacing:0.01em;"
               @click="openCreate">
          <span class="font-weight-bold text-white">New Note</span>
        </v-btn>
      </template>
    </HomecareHero>

    <!-- Filters -->
    <v-card rounded="xl" elevation="0" class="mt-4 pa-3 hc-card">
      <div class="d-flex flex-wrap align-center ga-2">
        <v-select v-model="filters.patient" :items="patientOptions"
                  density="comfortable" variant="outlined" rounded="lg" hide-details
                  clearable placeholder="Patient" style="max-width:220px;" />
        <v-select v-model="filters.caregiver" :items="caregiverOptions"
                  density="comfortable" variant="outlined" rounded="lg" hide-details
                  clearable placeholder="Caregiver" style="max-width:220px;" />
        <v-select v-model="filters.category" :items="categoryOptions"
                  density="comfortable" variant="outlined" rounded="lg" hide-details
                  clearable placeholder="Category" style="max-width:180px;" />
        <v-text-field v-model="filters.date" type="date" density="comfortable"
                      variant="outlined" rounded="lg" hide-details clearable
                      placeholder="Date" style="max-width:160px;" />
        <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                      placeholder="Search notes…" density="comfortable"
                      variant="outlined" hide-details rounded="lg"
                      style="max-width:340px;" clearable />
        <v-spacer />
        <v-btn variant="text" size="small" prepend-icon="mdi-refresh"
               class="text-none" :loading="loading" @click="load">Refresh</v-btn>
      </div>
    </v-card>

    <!-- Notes table -->
    <v-card rounded="xl" elevation="0" class="mt-3 hc-card">
      <v-data-table :items="filteredNotes" :headers="tableHeaders" item-value="id"
                    :loading="loading" class="hc-table">
        <template #[`item.recorded_at`]="{ item }">
          <div class="font-weight-medium">{{ formatDateTime(item.recorded_at) }}</div>
        </template>
        <template #[`item.patient_name`]="{ item }">
          <div class="d-flex align-center ga-2">
            <v-avatar size="28" color="teal" variant="flat">
              <span class="text-caption font-weight-bold text-white">{{ initials(item.patient_name) }}</span>
            </v-avatar>
            <div class="font-weight-medium">{{ item.patient_name || '—' }}</div>
          </div>
        </template>
        <template #[`item.caregiver_name`]="{ item }">
          <div class="d-flex align-center ga-2">
            <v-avatar size="28" color="indigo" variant="flat">
              <span class="text-caption font-weight-bold text-white">{{ initials(item.caregiver_name) }}</span>
            </v-avatar>
            <div class="font-weight-medium">{{ item.caregiver_name || '—' }}</div>
          </div>
        </template>
        <template #[`item.category`]="{ item }">
          <v-chip size="small" :color="categoryMeta(item.category).color" variant="tonal">
            <v-icon :icon="categoryMeta(item.category).icon" start size="14" />
            {{ categoryMeta(item.category).label }}
          </v-chip>
        </template>
        <template #[`item.content`]="{ item }">
          <div class="text-truncate" style="max-width:400px;">{{ contentPreview(item.content) }}</div>
        </template>
        <template #[`item.actions`]="{ item }">
          <v-btn icon="mdi-eye-outline" size="small" variant="text" @click.stop="openDetail(item)" title="View" />
          <v-btn icon="mdi-pencil-outline" size="small" variant="text" color="primary" @click.stop="openEdit(item)" title="Edit" />
          <v-btn icon="mdi-delete" size="small" variant="text" color="error" @click.stop="remove(item)" title="Delete" />
        </template>
      </v-data-table>
    </v-card>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2200">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()

const notes = ref([])
const caregivers = ref([])
const patients = ref([])
const loading = ref(false)
const search = ref('')
const filters = reactive({ patient: null, caregiver: null, category: null, date: null })

const detailDialog = ref(false)
const selected = ref(null)
const snack = reactive({ show: false, text: '', color: 'info' })
const categoryOptions = [
  { value: 'diet',      label: 'Diet',        icon: 'mdi-food-apple',      color: 'green' },
  { value: 'activity',  label: 'Activity',    icon: 'mdi-run',            color: 'blue' },
  { value: 'observation',label: 'Observation',icon: 'mdi-eye',            color: 'teal' },
  { value: 'vitals',    label: 'Vitals',      icon: 'mdi-heart-pulse',    color: 'pink' },
  { value: 'incident',  label: 'Incident',    icon: 'mdi-alert-octagon',  color: 'red' },
  { value: 'medication',label: 'Medication',  icon: 'mdi-pill',           color: 'purple' },
]
function categoryMeta(v) { return categoryOptions.find(o => o.value === v) || { label: v, icon: 'mdi-note', color: 'grey' } }

const tableHeaders = [
  { title: 'Recorded',    key: 'recorded_at' },
  { title: 'Patient',     key: 'patient_name' },
  { title: 'Caregiver',   key: 'caregiver_name' },
  { title: 'Category',    key: 'category' },
  { title: 'Note',        key: 'content', sortable: false },
  { title: '',            key: 'actions', sortable: false, align: 'end' },
]

const caregiverOptions = computed(() =>
  caregivers.value.map(c => ({ title: c.user?.full_name || c.user?.email, value: c.id }))
)
const patientOptions = computed(() =>
  patients.value.map(p => ({ title: p.user?.full_name || p.medical_record_number, value: p.id }))
)
const caregiverCount = computed(() => caregivers.value.length)
const patientCount = computed(() => patients.value.length)

const filteredNotes = computed(() => {
  let out = notes.value
  if (filters.patient) out = out.filter(n => n.patient === filters.patient)
  if (filters.caregiver) out = out.filter(n => n.caregiver === filters.caregiver)
  if (filters.category) out = out.filter(n => n.category === filters.category)
  if (filters.date) out = out.filter(n => (n.recorded_at || '').slice(0,10) === filters.date)
  if (search.value) {
    const q = search.value.toLowerCase()
    out = out.filter(n => (n.content || '').toLowerCase().includes(q))
  }
  return out
})

function formatDateTime(iso) {
  return iso ? new Date(iso).toLocaleString([], { dateStyle: 'medium', timeStyle: 'short' }) : ''
}
function initials(name) {
  if (!name) return '?'
  const p = name.trim().split(/\s+/)
  return ((p[0]?.[0] || '') + (p[1]?.[0] || '')).toUpperCase() || name[0].toUpperCase()
}

// ── CRUD ───────────────────────────────────────────────────────────────
async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/notes/', { params: { page_size: 1000 } })
    notes.value = data?.results || data || []
  } catch { notes.value = [] }
  finally { loading.value = false }
}
async function loadOptions() {
  try {
    const [c, p] = await Promise.all([
      $api.get('/homecare/caregivers/', { params: { page_size: 500 } }),
      $api.get('/homecare/patients/',   { params: { page_size: 500 } }),
    ])
    caregivers.value = c.data?.results || c.data || []
    patients.value   = p.data?.results || p.data || []
  } catch { caregivers.value = []; patients.value = [] }
}

function openCreate() {
  navigateTo('/homecare/notes/new')
}
function openEdit(item) {
  navigateTo(`/homecare/notes/${item.id}/edit`)
}
function openDetail(item) {
  navigateTo(`/homecare/notes/${item.id}`)
}
function contentPreview(html) {
  if (!html) return ''
  const text = String(html).replace(/<[^>]*>/g, ' ').replace(/[`*_~>#\[\]()]/g, '').replace(/\s+/g, ' ').trim()
  return text
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;')
}
function inlineMd(s) {
  let t = escapeHtml(s)
  t = t.replace(/`([^`]+)`/g, '<code>$1</code>')
  t = t.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
  t = t.replace(/(^|[^*])\*([^*]+)\*/g, '$1<em>$2</em>')
  t = t.replace(/~~([^~]+)~~/g, '<del>$1</del>')
  t = t.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>')
  return t
}
function mdToHtml(md) {
  if (!md) return ''
  // If looks like HTML (legacy notes), pass through.
  if (/<\/?(p|div|span|ul|ol|li|h[1-6]|br|strong|em|a|blockquote)\b/i.test(md)) return md
  const lines = String(md).split('\n')
  const out = []
  let inUl = false, inOl = false, inQuote = false
  const close = () => {
    if (inUl) { out.push('</ul>'); inUl = false }
    if (inOl) { out.push('</ol>'); inOl = false }
    if (inQuote) { out.push('</blockquote>'); inQuote = false }
  }
  for (const line of lines) {
    if (/^\s*$/.test(line)) { close(); continue }
    let m
    if ((m = line.match(/^###\s+(.*)$/))) { close(); out.push(`<h3>${inlineMd(m[1])}</h3>`); continue }
    if ((m = line.match(/^##\s+(.*)$/)))  { close(); out.push(`<h2>${inlineMd(m[1])}</h2>`); continue }
    if ((m = line.match(/^#\s+(.*)$/)))   { close(); out.push(`<h1>${inlineMd(m[1])}</h1>`); continue }
    if (/^---+$/.test(line))              { close(); out.push('<hr />'); continue }
    if ((m = line.match(/^>\s?(.*)$/)))   { if (!inQuote) { close(); out.push('<blockquote>'); inQuote = true } out.push(`<p>${inlineMd(m[1])}</p>`); continue }
    if ((m = line.match(/^-\s+\[( |x|X)\]\s+(.*)$/))) {
      if (!inUl) { close(); out.push('<ul class="hc-checks">'); inUl = true }
      const checked = m[1].toLowerCase() === 'x'
      out.push(`<li><input type="checkbox" disabled ${checked ? 'checked' : ''} /> ${inlineMd(m[2])}</li>`)
      continue
    }
    if ((m = line.match(/^[-*]\s+(.*)$/))) { if (!inUl) { close(); out.push('<ul>'); inUl = true } out.push(`<li>${inlineMd(m[1])}</li>`); continue }
    if ((m = line.match(/^\d+\.\s+(.*)$/))) { if (!inOl) { close(); out.push('<ol>'); inOl = true } out.push(`<li>${inlineMd(m[1])}</li>`); continue }
    close()
    out.push(`<p>${inlineMd(line)}</p>`)
  }
  close()
  return out.join('\n')
}
const renderedNote = computed(() => mdToHtml(selected.value?.content || ''))

async function remove(item) {
  if (!confirm('Delete this note?')) return
  try {
    await $api.delete(`/homecare/notes/${item.id}/`)
    Object.assign(snack, { show: true, text: 'Note deleted', color: 'success' })
    await load()
  } catch {
    Object.assign(snack, { show: true, text: 'Failed to delete', color: 'error' })
  }
}

onMounted(async () => { await loadOptions(); await load() })
</script>

<style scoped>
.hc-bg { min-height: calc(100vh - 64px); }
.hc-card {
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
}
:global(.v-theme--dark) .hc-card {
  background: rgb(30,41,59);
  border-color: rgba(255,255,255,0.08);
}
.hc-table :deep(th) { background: rgba(0,0,0,0.025); font-weight: 600; }
.hc-note-content :deep(h1) { font-size: 1.4rem; font-weight: 700; margin: 0.4em 0; }
.hc-note-content :deep(h2) { font-size: 1.2rem; font-weight: 700; margin: 0.4em 0; }
.hc-note-content :deep(ul),
.hc-note-content :deep(ol) { padding-left: 1.5em; margin: 0.4em 0; }
.hc-note-content :deep(blockquote) {
  border-left: 3px solid rgba(13,148,136,0.5);
  padding-left: 10px; color: rgba(15,23,42,0.7); margin: 0.4em 0;
}
.hc-note-content :deep(a) { color: rgb(13,148,136); text-decoration: underline; }
</style>
