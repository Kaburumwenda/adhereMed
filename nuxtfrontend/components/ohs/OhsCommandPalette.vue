<template>
  <v-dialog
    :model-value="modelValue"
    max-width="640"
    :scrim="true"
    class="ohs-palette-dialog"
    @update:model-value="$emit('update:modelValue', $event)"
  >
    <div class="palette" @keydown.esc="$emit('update:modelValue', false)">
      <div class="palette-search">
        <v-icon size="18" class="ml-3">mdi-magnify</v-icon>
        <input
          ref="inputEl"
          v-model="query"
          class="palette-input"
          placeholder="Search hazards, incidents, documents, contractors…"
          autocomplete="off"
          @keydown.down.prevent="move(1)"
          @keydown.up.prevent="move(-1)"
          @keydown.enter.prevent="open(activeIndex)"
        />
        <v-progress-circular v-if="loading" indeterminate size="16" width="2" color="primary" class="mr-3" />
        <span v-else class="palette-kbd mr-3">ESC</span>
      </div>

      <v-divider />

      <div class="palette-body">
        <!-- Quick navigation when the query is empty -->
        <template v-if="!query.trim()">
          <div class="palette-section">Jump to</div>
          <div
            v-for="(item, i) in quickLinks"
            :key="item.path"
            class="palette-item"
            :class="{ 'palette-item--active': i === activeIndex }"
            @mouseenter="activeIndex = i"
            @click="go(item.path)"
          >
            <v-icon size="16" class="palette-icon">{{ item.icon }}</v-icon>
            <span class="flex-grow-1">{{ item.label }}</span>
            <span class="palette-hint">{{ item.section }}</span>
          </div>
        </template>

        <!-- Search results grouped by kind -->
        <template v-else>
          <div v-if="!results.length && !loading" class="palette-empty">
            No matches for “{{ query }}”.
          </div>
          <template v-for="group in grouped" :key="group.kind">
            <div class="palette-section">{{ group.label }}</div>
            <div
              v-for="r in group.items"
              :key="`${r.kind}-${r.id}`"
              class="palette-item"
              :class="{ 'palette-item--active': flatIndex(r) === activeIndex }"
              @mouseenter="activeIndex = flatIndex(r)"
              @click="go(r.href)"
            >
              <v-icon size="16" class="palette-icon">{{ kindIcon(r.kind) }}</v-icon>
              <div class="flex-grow-1" style="min-width:0">
                <div class="palette-title">{{ r.title }}</div>
                <div class="palette-meta">{{ r.meta }}</div>
              </div>
              <v-icon size="14" class="palette-go">mdi-arrow-right</v-icon>
            </div>
          </template>
        </template>
      </div>

      <div class="palette-foot">
        <span><b>↑↓</b> navigate</span>
        <span><b>↵</b> open</span>
        <span><b>esc</b> close</span>
        <v-spacer />
        <span class="palette-brand">OHSMS Command Palette</span>
      </div>
    </div>
  </v-dialog>
</template>

<script setup>
const props = defineProps({
  modelValue: { type: Boolean, default: false },
})
const emit = defineEmits(['update:modelValue'])

const { $api } = useNuxtApp()
const router = useRouter()

const inputEl = ref(null)
const query = ref('')
const results = ref([])
const loading = ref(false)
const activeIndex = ref(0)
let debounce = null

const quickLinks = [
  { label: 'Safety Command Centre', path: '/ohs', icon: 'mdi-view-dashboard-outline', section: 'Dashboard' },
  { label: 'Safety Intelligence', path: '/ohs/intelligence', icon: 'mdi-chart-timeline-variant-shimmer', section: 'Analytics' },
  { label: 'Alert Centre', path: '/ohs/alerts', icon: 'mdi-bell-alert', section: 'Actions' },
  { label: 'Hazard Register', path: '/ohs/hazards', icon: 'mdi-alert-outline', section: 'Risk' },
  { label: 'Risk Assessments', path: '/ohs/risk-assessments', icon: 'mdi-clipboard-text-outline', section: 'Risk' },
  { label: 'Incidents & CAPA', path: '/ohs/incidents', icon: 'mdi-alert-circle-outline', section: 'Operations' },
  { label: 'Inspections', path: '/ohs/inspections', icon: 'mdi-clipboard-check-outline', section: 'Operations' },
  { label: 'Safety Equipment', path: '/ohs/equipment', icon: 'mdi-fire-extinguisher', section: 'Operations' },
  { label: 'Permits to Work', path: '/ohs/permits', icon: 'mdi-file-document-check-outline', section: 'Operations' },
  { label: 'Document Control & SDS', path: '/ohs/documents', icon: 'mdi-file-document-multiple-outline', section: 'Information' },
  { label: 'Contractors', path: '/ohs/contractors', icon: 'mdi-account-hard-hat', section: 'People' },
  { label: 'Training & Competence', path: '/ohs/training', icon: 'mdi-school-outline', section: 'People' },
  { label: 'PPE Management', path: '/ohs/ppe', icon: 'mdi-hard-hat', section: 'People' },
  { label: 'Health & Exposure', path: '/ohs/health', icon: 'mdi-heart-pulse', section: 'People' },
  { label: 'Observations', path: '/ohs/observations', icon: 'mdi-eye-check-outline', section: 'Culture' },
  { label: 'Safety Committee', path: '/ohs/committee', icon: 'mdi-account-voice', section: 'Culture' },
  { label: 'Emergency Drills', path: '/ohs/drills', icon: 'mdi-fire-alert', section: 'Preparedness' },
  { label: 'Legal & Audits', path: '/ohs/compliance', icon: 'mdi-gavel', section: 'Governance' },
  { label: 'Management Reviews', path: '/ohs/reviews', icon: 'mdi-clipboard-text-clock-outline', section: 'Governance' },
  { label: 'Certifications', path: '/ohs/certifications', icon: 'mdi-certificate-outline', section: 'Governance' },
  { label: 'Objectives', path: '/ohs/objectives', icon: 'mdi-target', section: 'Governance' },
  { label: 'Sites', path: '/ohs/sites', icon: 'mdi-office-building-outline', section: 'Context' },
]

const KIND_LABELS = {
  hazard: 'Hazards', incident: 'Incidents', inspection: 'Inspections', permit: 'Permits',
  document: 'Documents', contractor: 'Contractors', site: 'Sites',
  certification: 'Certifications', training: 'Training', ppe: 'PPE',
  equipment: 'Safety equipment',
}

const grouped = computed(() => {
  const order = ['hazard', 'incident', 'inspection', 'permit', 'document',
                 'contractor', 'certification', 'training', 'ppe', 'equipment', 'site']
  const map = new Map()
  for (const r of results.value) {
    if (!map.has(r.kind)) map.set(r.kind, [])
    map.get(r.kind).push(r)
  }
  return order
    .filter((k) => map.has(k))
    .map((k) => ({ kind: k, label: KIND_LABELS[k] || k, items: map.get(k) }))
})

const flatList = computed(() => grouped.value.flatMap((g) => g.items))

function flatIndex(r) {
  return flatList.value.findIndex((x) => x.kind === r.kind && x.id === r.id)
}

function kindIcon(kind) {
  return {
    hazard: 'mdi-alert-outline', incident: 'mdi-alert-circle-outline',
    inspection: 'mdi-clipboard-check-outline', permit: 'mdi-file-document-check-outline',
    document: 'mdi-file-document-multiple-outline', contractor: 'mdi-account-hard-hat',
    site: 'mdi-office-building-outline', certification: 'mdi-certificate-outline',
    training: 'mdi-school-outline', ppe: 'mdi-hard-hat',
  }[kind] || 'mdi-magnify'
}

function move(delta) {
  if (query.value.trim()) {
    const n = flatList.value.length
    if (!n) return
    activeIndex.value = (activeIndex.value + delta + n) % n
  } else {
    const n = quickLinks.length
    activeIndex.value = (activeIndex.value + delta + n) % n
  }
}

function go(path) {
  if (!path) return
  emit('update:modelValue', false)
  router.push(path)
}

function open(index) {
  if (query.value.trim()) {
    const item = flatList.value[index]
    if (item) go(item.href)
  } else {
    const item = quickLinks[index]
    if (item) go(item.path)
  }
}

async function search(q) {
  loading.value = true
  try {
    const { data } = await $api.get('/ohs/search/', { params: { q } })
    results.value = data.results || []
  } catch {
    results.value = []
  } finally {
    loading.value = false
  }
}

watch(query, (q) => {
  activeIndex.value = 0
  if (debounce) clearTimeout(debounce)
  if (!q.trim() || q.trim().length < 2) {
    results.value = []
    loading.value = false
    return
  }
  loading.value = true
  debounce = setTimeout(() => search(q.trim()), 220)
})

watch(() => props.modelValue, async (open) => {
  if (open) {
    query.value = ''
    results.value = []
    activeIndex.value = 0
    await nextTick()
    inputEl.value?.focus()
  }
})
</script>

<style scoped>
.palette {
  background: rgb(var(--v-theme-surface));
  border-radius: 14px;
  overflow: hidden;
  box-shadow: 0 24px 60px rgba(15, 23, 42, 0.28);
  border: 1px solid rgba(15, 23, 42, 0.1);
}
.palette-search {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 0;
}
.palette-input {
  flex: 1;
  border: none;
  outline: none;
  background: transparent;
  font-size: 14.5px;
  color: rgb(var(--v-theme-on-surface));
}
.palette-input::placeholder { color: rgba(var(--v-theme-on-surface), .42); }
.palette-kbd {
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.5px;
  padding: 3px 7px;
  border-radius: 6px;
  color: rgba(var(--v-theme-on-surface), .5);
  background: rgba(15, 23, 42, 0.06);
}
.palette-body { max-height: 380px; overflow: auto; padding: 6px 0 8px; }
.palette-section {
  padding: 7px 16px 3px;
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.7px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), .45);
}
.palette-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 7px 16px;
  cursor: pointer;
  font-size: 13px;
}
.palette-item--active { background: rgba(var(--v-theme-primary), 0.09); }
.palette-icon { color: rgb(var(--v-theme-primary)); flex-shrink: 0; }
.palette-title { font-weight: 600; line-height: 1.25; }
.palette-meta { font-size: 11px; color: rgba(var(--v-theme-on-surface), .55); }
.palette-hint { font-size: 10.5px; color: rgba(var(--v-theme-on-surface), .45); }
.palette-go { color: rgba(var(--v-theme-on-surface), .3); }
.palette-item--active .palette-go { color: rgb(var(--v-theme-primary)); }
.palette-empty {
  padding: 26px 16px;
  text-align: center;
  font-size: 12.5px;
  color: rgba(var(--v-theme-on-surface), .55);
}
.palette-foot {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 7px 16px;
  font-size: 10.5px;
  color: rgba(var(--v-theme-on-surface), .5);
  border-top: 1px solid rgba(var(--v-theme-on-surface), .07);
  background: rgba(15, 23, 42, 0.02);
}
.palette-foot b { font-weight: 800; }
.palette-brand { font-weight: 700; letter-spacing: .3px; text-transform: uppercase; font-size: 9.5px; }
</style>
