<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      :title="hero.title"
      :subtitle="hero.subtitle"
      eyebrow="HOMECARE · NOTE DETAILS"
      :icon="hero.icon"
      :chips="hero.chips"
    >
      <template #actions>
        <v-btn variant="text" rounded="pill" color="white" prepend-icon="mdi-arrow-left"
               class="text-none" @click="goBack">
          <span class="font-weight-bold">Back to notes</span>
        </v-btn>
        <v-btn v-if="note" variant="flat" rounded="pill" color="white"
               prepend-icon="mdi-pencil-outline" class="text-none ml-2"
               @click="goEdit">
          <span class="text-teal-darken-2 font-weight-bold">Edit</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-progress-linear v-if="loading" indeterminate color="teal" class="mt-4" rounded />

    <v-alert v-if="loadError" type="error" variant="tonal" class="mt-4">{{ loadError }}</v-alert>

    <v-row v-if="note" dense class="mt-2">
      <v-col cols="12" lg="8">
        <v-card rounded="xl" elevation="0" class="hc-card pa-4 pa-md-6 mb-3">
          <div class="d-flex align-center ga-3 mb-3">
            <v-avatar size="48" :color="catMeta.color" variant="tonal">
              <v-icon :icon="catMeta.icon" />
            </v-avatar>
            <div class="flex-grow-1 min-w-0">
              <div class="text-h6 font-weight-bold">{{ catMeta.label }} note</div>
              <div class="text-caption text-medium-emphasis">
                Recorded {{ formatDateTime(note.recorded_at) }}
                <span v-if="note.created_at"> · Created {{ formatDateTime(note.created_at) }}</span>
              </div>
            </div>
            <v-chip :color="catMeta.color" variant="tonal" size="small">
              <v-icon :icon="catMeta.icon" start size="14" />
              {{ catMeta.label }}
            </v-chip>
          </div>

          <v-divider class="mb-4" />

          <div class="text-subtitle-2 font-weight-bold mb-2">Note</div>
          <div class="hc-note-content" v-html="renderedNote" />

          <template v-if="note.vitals && Object.keys(note.vitals).length">
            <v-divider class="my-4" />
            <div class="text-subtitle-2 font-weight-bold mb-2">Vitals</div>
            <div class="d-flex flex-wrap ga-2">
              <v-chip v-for="(v, k) in note.vitals" :key="k" size="small" color="teal" variant="tonal">
                <span class="text-uppercase mr-1">{{ k }}</span>: {{ v }}
              </v-chip>
            </div>
          </template>
        </v-card>

        <!-- Attachments card -->
        <v-card rounded="xl" elevation="0" class="hc-card pa-4 pa-md-6">
          <div class="d-flex align-center ga-2 mb-3">
            <v-icon icon="mdi-paperclip" color="teal-darken-2" />
            <div class="text-subtitle-1 font-weight-bold">Attachments</div>
            <v-chip size="x-small" color="grey" variant="tonal" class="ml-1">
              {{ attachments.length }}
            </v-chip>
          </div>

          <div v-if="!attachments.length" class="text-body-2 text-medium-emphasis">
            No files attached to this note.
          </div>

          <v-row v-else dense>
            <v-col v-for="(file, i) in attachments" :key="i" cols="12" sm="6" md="4">
              <v-card rounded="lg" :elevation="0" class="hc-att" @click="previewFile(file)">
                <div class="hc-att__thumb">
                  <img v-if="isImage(file)" :src="fileSrc(file)" :alt="file.name" />
                  <v-icon v-else :icon="fileIcon(file)" size="48" :color="fileColor(file)" />
                </div>
                <div class="pa-2">
                  <div class="font-weight-medium text-truncate" :title="file.name">{{ file.name || `attachment ${i + 1}` }}</div>
                  <div class="text-caption text-medium-emphasis d-flex align-center ga-2">
                    <span>{{ fileTypeLabel(file) }}</span>
                    <span v-if="file.size">· {{ formatSize(file.size) }}</span>
                  </div>
                </div>
                <v-divider />
                <div class="d-flex">
                  <v-btn variant="text" size="small" class="text-none flex-grow-1"
                         prepend-icon="mdi-eye-outline" @click.stop="previewFile(file)">
                    View
                  </v-btn>
                  <v-divider vertical />
                  <v-btn variant="text" size="small" class="text-none flex-grow-1"
                         prepend-icon="mdi-download" @click.stop="downloadFile(file)">
                    Download
                  </v-btn>
                </div>
              </v-card>
            </v-col>
          </v-row>
        </v-card>
      </v-col>

      <v-col cols="12" lg="4">
        <v-card rounded="xl" elevation="0" class="hc-card pa-4 mb-3">
          <div class="text-subtitle-2 font-weight-bold mb-3">People</div>
          <div class="d-flex align-center ga-3 mb-3">
            <v-avatar size="40" color="teal" variant="flat">
              <span class="text-caption font-weight-bold text-white">{{ initials(note.patient_name) }}</span>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis">Patient</div>
              <div class="font-weight-medium">{{ note.patient_name || '—' }}</div>
            </div>
          </div>
          <div class="d-flex align-center ga-3">
            <v-avatar size="40" color="indigo" variant="flat">
              <span class="text-caption font-weight-bold text-white">{{ initials(note.caregiver_name) }}</span>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis">Caregiver</div>
              <div class="font-weight-medium">{{ note.caregiver_name || '—' }}</div>
            </div>
          </div>
        </v-card>

        <v-card rounded="xl" elevation="0" class="hc-card pa-4">
          <div class="text-subtitle-2 font-weight-bold mb-3">Timeline</div>
          <div class="hc-meta-row">
            <v-icon icon="mdi-calendar-clock" color="teal-darken-2" />
            <div>
              <div class="text-caption text-medium-emphasis">Recorded at</div>
              <div class="font-weight-medium">{{ formatDateTime(note.recorded_at) || '—' }}</div>
            </div>
          </div>
          <v-divider class="my-3" />
          <div class="hc-meta-row">
            <v-icon icon="mdi-clock-check-outline" color="grey" />
            <div>
              <div class="text-caption text-medium-emphasis">Created at</div>
              <div class="font-weight-medium">{{ formatDateTime(note.created_at) || '—' }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Attachment preview dialog -->
    <v-dialog v-model="previewOpen" max-width="900" scrollable>
      <v-card v-if="previewing" rounded="xl">
        <v-card-title class="d-flex align-center ga-2">
          <v-icon :icon="fileIcon(previewing)" :color="fileColor(previewing)" />
          <span class="text-truncate">{{ previewing.name }}</span>
          <v-spacer />
          <v-btn variant="text" prepend-icon="mdi-download" class="text-none"
                 @click="downloadFile(previewing)">Download</v-btn>
          <v-btn icon="mdi-close" variant="text" @click="previewOpen = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-0 hc-preview">
          <img v-if="isImage(previewing)" :src="fileSrc(previewing)" :alt="previewing.name"
               class="hc-preview__img" />
          <iframe v-else-if="isPdf(previewing)" :src="fileSrc(previewing)"
                  class="hc-preview__iframe" frameborder="0" />
          <pre v-else-if="isText(previewing)" class="hc-preview__text">{{ textContent }}</pre>
          <div v-else class="pa-6 text-center">
            <v-icon icon="mdi-file-question-outline" size="64" color="grey" class="mb-2" />
            <div class="text-body-2 mb-3">Preview is not available for this file type.</div>
            <v-btn color="teal-darken-2" prepend-icon="mdi-download" class="text-none"
                   @click="downloadFile(previewing)">Download file</v-btn>
          </div>
        </v-card-text>
      </v-card>
    </v-dialog>
  </div>
</template>

<script setup>
const route = useRoute()
const { $api } = useNuxtApp()

const note = ref(null)
const loading = ref(false)
const loadError = ref('')

const previewOpen = ref(false)
const previewing = ref(null)
const textContent = ref('')

const categoryOptions = [
  { value: 'diet',         label: 'Diet',        icon: 'mdi-food-apple',     color: 'green' },
  { value: 'activity',     label: 'Activity',    icon: 'mdi-run',            color: 'blue' },
  { value: 'observation',  label: 'Observation', icon: 'mdi-eye',            color: 'teal' },
  { value: 'vitals',       label: 'Vitals',      icon: 'mdi-heart-pulse',    color: 'pink' },
  { value: 'incident',     label: 'Incident',    icon: 'mdi-alert-octagon',  color: 'red' },
  { value: 'medication',   label: 'Medication',  icon: 'mdi-pill',           color: 'purple' },
]

const catMeta = computed(() =>
  categoryOptions.find(o => o.value === note.value?.category) ||
  { label: note.value?.category || 'Note', icon: 'mdi-note', color: 'grey' }
)

const attachments = computed(() => Array.isArray(note.value?.attached_files) ? note.value.attached_files : [])

const hero = computed(() => ({
  title: note.value ? `${catMeta.value.label} note` : 'Care note',
  subtitle: note.value
    ? `For ${note.value.patient_name || 'patient'} · by ${note.value.caregiver_name || 'caregiver'}`
    : 'Detailed view of a care note.',
  icon: catMeta.value.icon,
  chips: note.value ? [
    { icon: 'mdi-calendar-clock', label: formatDateTime(note.value.recorded_at) },
    { icon: 'mdi-paperclip',      label: `${attachments.value.length} attachment${attachments.value.length === 1 ? '' : 's'}` },
  ] : [],
}))

async function load() {
  loading.value = true
  loadError.value = ''
  try {
    const { data } = await $api.get(`/homecare/notes/${route.params.id}/`)
    note.value = data
  } catch {
    loadError.value = 'Could not load this note.'
  } finally {
    loading.value = false
  }
}

function goBack() { navigateTo('/homecare/notes') }
function goEdit() { navigateTo(`/homecare/notes/${route.params.id}/edit`) }

function formatDateTime(iso) {
  return iso ? new Date(iso).toLocaleString([], { dateStyle: 'medium', timeStyle: 'short' }) : ''
}
function initials(name) {
  if (!name) return '?'
  const p = String(name).trim().split(/\s+/)
  return ((p[0]?.[0] || '') + (p[1]?.[0] || '')).toUpperCase() || name[0].toUpperCase()
}
function formatSize(bytes) {
  if (!bytes && bytes !== 0) return ''
  const units = ['B', 'KB', 'MB', 'GB']
  let n = Number(bytes), i = 0
  while (n >= 1024 && i < units.length - 1) { n /= 1024; i++ }
  return `${n.toFixed(n < 10 && i ? 1 : 0)} ${units[i]}`
}

// ── attachment helpers ────────────────────────────────────────────────
function fileSrc(file) {
  if (!file) return ''
  if (typeof file === 'string') return file
  return file.data || file.url || file.src || ''
}
function fileTypeLabel(file) {
  if (!file) return ''
  if (file.type) return file.type
  const name = file.name || ''
  const ext = name.includes('.') ? name.split('.').pop().toUpperCase() : 'FILE'
  return ext
}
function isImage(file) {
  const t = (file?.type || '').toLowerCase()
  if (t.startsWith('image/')) return true
  return /\.(png|jpe?g|gif|webp|bmp|svg)$/i.test(file?.name || '')
}
function isPdf(file) {
  return (file?.type || '').toLowerCase().includes('pdf') || /\.pdf$/i.test(file?.name || '')
}
function isText(file) {
  const t = (file?.type || '').toLowerCase()
  if (t.startsWith('text/')) return true
  return /\.(txt|md|csv|log|json)$/i.test(file?.name || '')
}
function fileIcon(file) {
  if (isImage(file)) return 'mdi-file-image-outline'
  if (isPdf(file)) return 'mdi-file-pdf-box'
  if (isText(file)) return 'mdi-file-document-outline'
  if (/\.docx?$/i.test(file?.name || '')) return 'mdi-file-word-box'
  if (/\.xlsx?$/i.test(file?.name || '')) return 'mdi-file-excel-box'
  return 'mdi-file-outline'
}
function fileColor(file) {
  if (isImage(file)) return 'teal'
  if (isPdf(file)) return 'red'
  if (/\.docx?$/i.test(file?.name || '')) return 'blue'
  if (/\.xlsx?$/i.test(file?.name || '')) return 'green'
  return 'grey'
}

async function previewFile(file) {
  previewing.value = file
  textContent.value = ''
  if (isText(file)) {
    try {
      const src = fileSrc(file)
      if (src.startsWith('data:')) {
        textContent.value = atob(src.split(',')[1] || '')
      } else if (src) {
        const r = await fetch(src)
        textContent.value = await r.text()
      }
    } catch {
      textContent.value = '(Unable to read text content)'
    }
  }
  previewOpen.value = true
}

function downloadFile(file) {
  const src = fileSrc(file)
  if (!src) return
  const a = document.createElement('a')
  a.href = src
  a.download = file.name || 'attachment'
  a.target = '_blank'
  a.rel = 'noopener'
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
}

// ── note content rendering (markdown / HTML fallback) ─────────────────
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
  if (!md) return '<p class="hc-empty">No content.</p>'
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
    if ((m = line.match(/^[-*]\s+(.*)$/)))  { if (!inUl) { close(); out.push('<ul>'); inUl = true } out.push(`<li>${inlineMd(m[1])}</li>`); continue }
    if ((m = line.match(/^\d+\.\s+(.*)$/))) { if (!inOl) { close(); out.push('<ol>'); inOl = true } out.push(`<li>${inlineMd(m[1])}</li>`); continue }
    close()
    out.push(`<p>${inlineMd(line)}</p>`)
  }
  close()
  return out.join('\n')
}
const renderedNote = computed(() => mdToHtml(note.value?.content || ''))

definePageMeta({ title: 'Care note' })
onMounted(load)
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

.hc-meta-row { display: flex; align-items: flex-start; gap: 12px; }

.hc-note-content :deep(h1) { font-size: 1.5rem; font-weight: 700; margin: 0.5em 0 0.3em; }
.hc-note-content :deep(h2) { font-size: 1.25rem; font-weight: 700; margin: 0.5em 0 0.3em; }
.hc-note-content :deep(h3) { font-size: 1.1rem; font-weight: 700; margin: 0.5em 0 0.3em; }
.hc-note-content :deep(p) { margin: 0.4em 0; }
.hc-note-content :deep(ul),
.hc-note-content :deep(ol) { padding-left: 1.5em; margin: 0.4em 0; }
.hc-note-content :deep(blockquote) {
  border-left: 3px solid rgba(13,148,136,0.5);
  padding: 4px 10px; color: rgba(15,23,42,0.75); margin: 0.4em 0;
  background: rgba(13,148,136,0.05); border-radius: 4px;
}
.hc-note-content :deep(code) {
  background: rgba(15,23,42,0.06); padding: 1px 4px; border-radius: 4px;
  font-family: ui-monospace, "SFMono-Regular", Menlo, monospace; font-size: 0.85em;
}
.hc-note-content :deep(a) { color: rgb(13,148,136); text-decoration: underline; }
.hc-note-content :deep(.hc-checks) { list-style: none; padding-left: 0.2em; }
.hc-note-content :deep(.hc-empty) { color: rgba(15,23,42,0.45); font-style: italic; }

.hc-att {
  border: 1px solid rgba(15,23,42,0.08);
  cursor: pointer;
  transition: transform 0.15s ease, box-shadow 0.15s ease, border-color 0.15s ease;
  overflow: hidden;
}
.hc-att:hover {
  transform: translateY(-2px);
  border-color: rgba(13,148,136,0.4);
  box-shadow: 0 6px 18px rgba(13,148,136,0.12);
}
.hc-att__thumb {
  height: 120px;
  background: rgba(15,23,42,0.04);
  display: flex; align-items: center; justify-content: center;
  overflow: hidden;
}
.hc-att__thumb img { width: 100%; height: 100%; object-fit: cover; }

.hc-preview { background: rgba(15,23,42,0.03); }
.hc-preview__img {
  display: block; max-width: 100%; max-height: 75vh; margin: 0 auto;
}
.hc-preview__iframe { width: 100%; height: 75vh; background: white; }
.hc-preview__text {
  margin: 0; padding: 16px; max-height: 75vh; overflow: auto;
  font-family: ui-monospace, "SFMono-Regular", Menlo, monospace;
  font-size: 0.85rem; white-space: pre-wrap; word-break: break-word;
}

:global(.v-theme--dark) .hc-att { border-color: rgba(255,255,255,0.08); }
:global(.v-theme--dark) .hc-att__thumb { background: rgba(255,255,255,0.04); }
:global(.v-theme--dark) .hc-preview { background: rgba(0,0,0,0.2); }
</style>
