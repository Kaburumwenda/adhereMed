<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center" style="gap:14px">
        <v-avatar color="primary" variant="tonal" rounded="lg" size="52">
          <v-icon size="28">mdi-file-document-multiple-outline</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 text-md-h4 font-weight-bold mb-0">Document Management</h1>
          <div class="text-body-2 text-medium-emphasis">Centralized repository for policies, procedures, records &amp; more</div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn variant="tonal" color="primary" prepend-icon="mdi-refresh" rounded="lg" class="text-none" :loading="loading" @click="reload">Refresh</v-btn>
        <v-btn variant="tonal" color="warning" prepend-icon="mdi-star" rounded="lg" class="text-none" to="/documents/starred">Starred</v-btn>
        <v-btn variant="tonal" color="info" prepend-icon="mdi-share-variant" rounded="lg" class="text-none" to="/documents/shared">Shared with me</v-btn>
        <v-btn variant="tonal" color="error" prepend-icon="mdi-trash-can" rounded="lg" class="text-none" to="/documents/trash">Trash</v-btn>
        <v-btn v-if="canEdit" color="primary" prepend-icon="mdi-plus" rounded="lg" class="text-none" to="/documents/new">Upload Document</v-btn>
      </div>
    </div>

    <!-- KPI strip -->
    <v-row dense class="mb-2">
      <v-col cols="6" md="3">
        <v-card rounded="lg" elevation="0" class="pa-3 kpi-card kpi-blue">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="primary" variant="tonal" rounded="lg" size="40"><v-icon>mdi-file-multiple</v-icon></v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Total documents</div>
              <div class="text-h6 font-weight-bold">{{ kpis.total.toLocaleString() }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" elevation="0" class="pa-3 kpi-card kpi-green">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="success" variant="tonal" rounded="lg" size="40"><v-icon>mdi-check-circle-outline</v-icon></v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Approved / Published</div>
              <div class="text-h6 font-weight-bold">{{ kpis.approved.toLocaleString() }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" elevation="0" class="pa-3 kpi-card kpi-amber">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="warning" variant="tonal" rounded="lg" size="40"><v-icon>mdi-clock-outline</v-icon></v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">In review</div>
              <div class="text-h6 font-weight-bold">{{ kpis.inReview.toLocaleString() }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" md="3">
        <v-card rounded="lg" elevation="0" class="pa-3 kpi-card kpi-red">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="error" variant="tonal" rounded="lg" size="40"><v-icon>mdi-alert-outline</v-icon></v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis text-uppercase">Expired</div>
              <div class="text-h6 font-weight-bold">{{ kpis.expired.toLocaleString() }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Toolbar -->
    <v-card rounded="lg" elevation="0" class="pa-3 mb-3" style="border:1px solid rgba(0,0,0,0.06)">
      <div class="d-flex flex-wrap align-center" style="gap:10px">
        <v-text-field
          v-model="search"
          placeholder="Search documents…"
          prepend-inner-icon="mdi-magnify"
          density="compact" variant="outlined" rounded="lg" hide-details
          clearable
          style="min-width: 240px; max-width: 360px; flex:1"
        />
        <v-select
          v-model="categoryFilter"
          :items="categoryOptions"
          item-title="label" item-value="value"
          density="compact" variant="outlined" rounded="lg" hide-details
          prepend-inner-icon="mdi-folder-outline" style="min-width: 180px"
        />
        <v-select
          v-model="statusFilter"
          :items="statusOptions"
          item-title="label" item-value="value"
          density="compact" variant="outlined" rounded="lg" hide-details
          prepend-inner-icon="mdi-filter-variant" style="min-width: 160px"
        />
        <v-select
          v-model="priorityFilter"
          :items="priorityOptions"
          item-title="label" item-value="value"
          density="compact" variant="outlined" rounded="lg" hide-details
          prepend-inner-icon="mdi-flag-outline" style="min-width: 160px"
        />
        <v-select
          v-if="branchOptions.length > 1"
          v-model="branchFilter"
          :items="branchOptions"
          item-title="label" item-value="value"
          density="compact" variant="outlined" rounded="lg" hide-details
          prepend-inner-icon="mdi-store-outline" style="min-width: 180px"
        />
        <v-btn-toggle v-model="viewMode" mandatory density="compact" rounded="lg">
          <v-btn value="grid" icon="mdi-view-grid" size="small" />
          <v-btn value="table" icon="mdi-table" size="small" />
        </v-btn-toggle>
        <v-spacer />
        <span class="text-caption text-medium-emphasis">{{ filteredItems.length }} of {{ items.length }}</span>
      </div>
    </v-card>

    <!-- Grid View -->
    <div v-if="viewMode === 'grid'" class="mb-3">
      <v-progress-linear v-if="loading" color="primary" indeterminate class="mb-2" />
      <div v-if="!loading && !filteredItems.length" class="pa-10 text-center text-medium-emphasis">
        <v-icon size="64" color="grey">mdi-file-document-outline</v-icon>
        <div class="text-h6 mt-3">No documents found</div>
        <div class="text-body-2 mb-4">{{ search ? 'Try a different search.' : 'Upload your first document to get started.' }}</div>
        <v-btn v-if="canEdit" color="primary" variant="flat" rounded="lg" class="text-none" prepend-icon="mdi-plus" to="/documents/new">Upload Document</v-btn>
      </div>
      <v-row v-else dense>
        <v-col v-for="row in pagedItems" :key="row.id" cols="12" sm="6" md="4" lg="3">
          <v-card
            rounded="lg" elevation="0" class="doc-card h-100 cursor-pointer"
            style="border:1px solid rgba(0,0,0,0.08)"
            @click="navigateTo(`/documents/${row.id}`)"
          >
            <v-card-text class="pa-4">
              <div class="d-flex align-start justify-space-between mb-2">
                <v-avatar :color="fileColor(row.file_extension)" variant="tonal" rounded="lg" size="44">
                  <v-icon size="24">{{ fileIcon(row.file_extension) }}</v-icon>
                </v-avatar>
                <div class="d-flex" style="gap:4px">
                  <v-icon v-if="row.is_starred" size="18" color="warning">mdi-star</v-icon>
                  <v-chip :color="statusColor(row.status)" size="x-small" variant="tonal">{{ statusLabel(row.status) }}</v-chip>
                </div>
              </div>
              <div class="font-weight-medium text-truncate" style="font-size:0.95rem">{{ row.title }}</div>
              <div v-if="row.reference_number" class="text-caption text-medium-emphasis text-truncate">{{ row.reference_number }}</div>
              <div class="text-caption text-medium-emphasis mt-1" style="min-height:36px; display:-webkit-box; -webkit-line-clamp:2; -webkit-box-orient:vertical; overflow:hidden">
                {{ row.description || 'No description' }}
              </div>
              <div class="d-flex flex-wrap align-center mt-2" style="gap:4px">
                <v-chip v-if="row.category_name" size="x-small" variant="tonal" color="primary">{{ row.category_name }}</v-chip>
                <v-chip v-if="row.priority !== 'normal'" :color="priorityColor(row.priority)" size="x-small" variant="tonal">{{ priorityLabel(row.priority) }}</v-chip>
                <v-chip v-if="row.version_count > 1" size="x-small" variant="tonal"><v-icon start size="12">mdi-file-replace</v-icon>{{ row.version_count }} versions</v-chip>
              </div>
              <v-divider class="my-2" />
              <div class="d-flex align-center justify-space-between">
                <div class="text-caption text-medium-emphasis">{{ row.uploaded_by_name || '—' }}</div>
                <div class="text-caption text-medium-emphasis">{{ formatDate(row.updated_at) }}</div>
              </div>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>
    </div>

    <!-- Table View -->
    <v-card v-else rounded="lg" elevation="0" class="overflow-hidden mb-3" style="border:1px solid rgba(0,0,0,0.06)">
      <v-progress-linear v-if="loading" color="primary" indeterminate />
      <div v-if="!loading && !filteredItems.length" class="pa-10 text-center text-medium-emphasis">
        <v-icon size="64" color="grey">mdi-file-document-outline</v-icon>
        <div class="text-h6 mt-3">No documents found</div>
        <div class="text-body-2 mb-4">{{ search ? 'Try a different search.' : 'Upload your first document to get started.' }}</div>
        <v-btn v-if="canEdit" color="primary" variant="flat" rounded="lg" class="text-none" prepend-icon="mdi-plus" to="/documents/new">Upload Document</v-btn>
      </div>
      <div v-else class="table-wrap">
        <table class="inv-table">
          <thead>
            <tr>
              <th class="row-num">#</th>
              <th>Document</th>
              <th>Category</th>
              <th>Status</th>
              <th>Priority</th>
              <th>Tags</th>
              <th>Uploaded by</th>
              <th>Updated</th>
              <th class="text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(row, i) in pagedItems" :key="row.id" class="inv-row-click" @click="navigateTo(`/documents/${row.id}`)">
              <td class="row-num text-medium-emphasis">{{ rowNumber(i) }}</td>
              <td>
                <div class="d-flex align-center" style="gap:10px">
                  <v-avatar :color="fileColor(row.file_extension)" variant="tonal" rounded="lg" size="34">
                    <v-icon size="18">{{ fileIcon(row.file_extension) }}</v-icon>
                  </v-avatar>
                  <div>
                    <div class="font-weight-medium d-flex align-center" style="gap:4px">
                      {{ row.title }}
                      <v-icon v-if="row.is_starred" size="14" color="warning">mdi-star</v-icon>
                    </div>
                    <div class="text-caption text-medium-emphasis">
                      <span v-if="row.reference_number">{{ row.reference_number }}</span>
                      <span v-else>DOC-{{ row.id }}</span>
                    </div>
                  </div>
                </div>
              </td>
              <td>
                <v-chip v-if="row.category_name" size="x-small" variant="tonal" color="primary">{{ row.category_name }}</v-chip>
                <span v-else class="text-medium-emphasis text-caption">—</span>
              </td>
              <td>
                <span class="status-pill" :class="`status-${row.status}`">
                  <v-icon size="14">{{ statusIcon(row.status) }}</v-icon>
                  {{ statusLabel(row.status) }}
                </span>
              </td>
              <td>
                <v-chip v-if="row.priority !== 'normal'" :color="priorityColor(row.priority)" size="x-small" variant="tonal">{{ priorityLabel(row.priority) }}</v-chip>
                <span v-else class="text-medium-emphasis text-caption">Normal</span>
              </td>
              <td>
                <div v-if="row.tag_names && row.tag_names.length" class="d-flex flex-wrap" style="gap:4px">
                  <v-chip v-for="tag in row.tag_names" :key="tag" size="x-small" variant="tonal" color="info">{{ tag }}</v-chip>
                </div>
                <span v-else class="text-medium-emphasis text-caption">—</span>
              </td>
              <td class="text-medium-emphasis">{{ row.uploaded_by_name || '—' }}</td>
              <td class="text-medium-emphasis">{{ formatDate(row.updated_at) }}</td>
              <td class="text-right">
                <v-menu offset="4">
                  <template #activator="{ props }">
                    <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" @click.stop />
                  </template>
                  <v-list density="compact" min-width="180">
                    <v-list-item prepend-icon="mdi-eye-outline" title="View details" @click="navigateTo(`/documents/${row.id}`)" />
                    <v-list-item prepend-icon="mdi-download" title="Download" @click="downloadDoc(row)" />
                    <v-list-item v-if="canEdit" prepend-icon="mdi-pencil" title="Edit" @click="navigateTo(`/documents/${row.id}/edit`)" />
                    <v-list-item prepend-icon="mdi-star" :title="row.is_starred ? 'Unstar' : 'Star'" @click="toggleStar(row)" />
                  </v-list>
                </v-menu>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </v-card>

    <!-- Pagination -->
    <div v-if="filteredItems.length" class="d-flex flex-wrap align-center pa-3 pagination-bar" style="gap:12px">
      <span class="text-caption text-medium-emphasis">
        Showing <strong>{{ rangeStart }}–{{ rangeEnd }}</strong> of <strong>{{ filteredItems.length }}</strong>
      </span>
      <v-spacer />
      <div class="d-flex align-center" style="gap:6px">
        <span class="text-caption text-medium-emphasis">Rows per page</span>
        <v-select v-model="pageSize" :items="pageSizeOptions" density="compact" variant="outlined" rounded="lg" hide-details style="width: 92px" />
      </div>
      <v-pagination v-if="totalPages > 1" v-model="page" :length="totalPages" :total-visible="5" density="comfortable" rounded="lg" color="primary" />
    </div>
  </v-container>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useResource } from '~/composables/useResource'
import { formatDate } from '~/utils/format'
import { useBranchStore } from '~/stores/branch'
import { useAuthStore } from '~/stores/auth'
import { ADMIN_ROLES } from '~/utils/permissions'

const branchStore = useBranchStore()
const auth = useAuthStore()

const canEdit = computed(() => [...ADMIN_ROLES, 'branch_admin'].includes(auth.role))

const { $api } = useNuxtApp()

const docRes = useResource('/documents/documents/')
const categoryRes = useResource('/documents/categories/')
const loading = computed(() => docRes.loading.value)
const items = computed(() => docRes.items.value || [])

const search = ref('')
const categoryFilter = ref('all')
const statusFilter = ref('all')
const priorityFilter = ref('all')
const branchFilter = ref('all')
const viewMode = ref('grid')
const page = ref(1)
const pageSize = ref(24)
const pageSizeOptions = [12, 24, 50, 100]

const statusOptions = [
  { label: 'All status', value: 'all' },
  { label: 'Draft', value: 'draft' },
  { label: 'In Review', value: 'in_review' },
  { label: 'Approved', value: 'approved' },
  { label: 'Published', value: 'published' },
  { label: 'Archived', value: 'archived' },
  { label: 'Expired', value: 'expired' },
]

const priorityOptions = [
  { label: 'All priority', value: 'all' },
  { label: 'Low', value: 'low' },
  { label: 'Normal', value: 'normal' },
  { label: 'High', value: 'high' },
  { label: 'Critical', value: 'critical' },
]

const categoryOptions = computed(() => {
  const opts = [{ label: 'All categories', value: 'all' }]
  for (const c of categoryRes.items.value || []) opts.push({ label: c.name, value: c.id })
  return opts
})

const branchOptions = computed(() => {
  const source = branchStore.activeBranches
  const opts = source.length > 1 ? [{ label: 'All branches', value: 'all' }] : []
  for (const b of source) opts.push({ label: b.name, value: b.id })
  return opts
})

const filteredItems = computed(() => {
  const q = (search.value || '').toLowerCase().trim()
  let arr = items.value.slice()
  if (categoryFilter.value !== 'all') arr = arr.filter(d => d.category === categoryFilter.value)
  if (statusFilter.value !== 'all') arr = arr.filter(d => d.status === statusFilter.value)
  if (priorityFilter.value !== 'all') arr = arr.filter(d => d.priority === priorityFilter.value)
  if (branchFilter.value !== 'all') arr = arr.filter(d => d.branch === branchFilter.value)
  if (!q) return arr
  return arr.filter(row => Object.values(row).some(v => {
    if (v == null) return false
    if (typeof v === 'object') return false
    return String(v).toLowerCase().includes(q)
  }))
})

const totalPages = computed(() => Math.max(1, Math.ceil(filteredItems.value.length / pageSize.value)))
const pagedItems = computed(() => {
  const s = (page.value - 1) * pageSize.value
  return filteredItems.value.slice(s, s + pageSize.value)
})
const rangeStart = computed(() => filteredItems.value.length === 0 ? 0 : (page.value - 1) * pageSize.value + 1)
const rangeEnd = computed(() => Math.min(page.value * pageSize.value, filteredItems.value.length))
function rowNumber(i) { return (page.value - 1) * pageSize.value + i + 1 }

watch([search, categoryFilter, statusFilter, priorityFilter, branchFilter, pageSize], () => { page.value = 1 })

const kpis = computed(() => {
  const all = items.value
  return {
    total: all.length,
    approved: all.filter(d => ['approved', 'published'].includes(d.status)).length,
    inReview: all.filter(d => d.status === 'in_review').length,
    expired: all.filter(d => d.status === 'expired').length,
  }
})

// --- Status helpers ---
function statusLabel(s) { return statusOptions.find(o => o.value === s)?.label || s }
function statusColor(s) {
  const map = { draft: 'grey', in_review: 'warning', approved: 'success', published: 'primary', archived: 'default', expired: 'error' }
  return map[s] || 'grey'
}
function statusIcon(s) {
  const map = { draft: 'mdi-pencil', in_review: 'mdi-clock-outline', approved: 'mdi-check-circle', published: 'mdi-cloud-upload', archived: 'mdi-archive', expired: 'mdi-alert' }
  return map[s] || 'mdi-file'
}

// --- Priority helpers ---
function priorityLabel(p) {
  const map = { low: 'Low', normal: 'Normal', high: 'High', critical: 'Critical' }
  return map[p] || p
}
function priorityColor(p) {
  const map = { low: 'info', normal: 'default', high: 'warning', critical: 'error' }
  return map[p] || 'default'
}

// --- File helpers ---
const FILE_ICONS = {
  pdf: 'mdi-file-pdf-box',
  doc: 'mdi-file-word-box', docx: 'mdi-file-word-box',
  xls: 'mdi-file-excel-box', xlsx: 'mdi-file-excel-box',
  ppt: 'mdi-file-powerpoint-box', pptx: 'mdi-file-powerpoint-box',
  jpg: 'mdi-file-image', jpeg: 'mdi-file-image', png: 'mdi-file-image', gif: 'mdi-file-image',
  zip: 'mdi-folder-zip', rar: 'mdi-folder-zip',
  txt: 'mdi-file-document-outline',
  csv: 'mdi-file-delimited',
}
const FILE_COLORS = {
  pdf: 'error', doc: 'blue', docx: 'blue', xls: 'success', xlsx: 'success',
  ppt: 'orange', pptx: 'orange', jpg: 'purple', jpeg: 'purple', png: 'purple', gif: 'purple',
  zip: 'amber', rar: 'amber', txt: 'grey', csv: 'green',
}
function fileIcon(ext) {
  if (!ext) return 'mdi-file-document-outline'
  return FILE_ICONS[ext.toLowerCase()] || 'mdi-file-document-outline'
}
function fileColor(ext) {
  if (!ext) return 'primary'
  return FILE_COLORS[ext.toLowerCase()] || 'primary'
}

async function toggleStar(row) {
  try {
    await $api.post(`/documents/documents/${row.id}/star/`)
    row.is_starred = !row.is_starred
  } catch (e) {
    console.error('Star failed', e)
  }
}

async function downloadDoc(row) {
  try {
    const { data } = await $api.get(`/documents/documents/${row.id}/download/`, { responseType: 'blob' })
    const url = URL.createObjectURL(data)
    const a = document.createElement('a')
    a.href = url
    a.download = row.title || `document-${row.id}`
    a.click()
    URL.revokeObjectURL(url)
  } catch (e) {
    console.error('Download failed', e)
  }
}

function reload() {
  const params = { page_size: 2000 }
  if (branchStore.currentBranchId) params.branch = branchStore.currentBranchId
  docRes.list(params)
}

onMounted(async () => {
  await branchStore.load()
  reload()
  categoryRes.list({ page_size: 2000 })
})

watch(() => branchStore.currentBranchId, () => reload())
</script>

<style scoped>
.doc-card { transition: all 0.2s ease; }
.doc-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 20px rgba(0,0,0,0.08) !important;
  border-color: rgba(13,148,136,0.3) !important;
}
.cursor-pointer { cursor: pointer; }
.status-pill {
  display: inline-flex; align-items: center; gap: 4px;
  padding: 2px 10px; border-radius: 20px; font-size: 0.75rem; font-weight: 600; white-space: nowrap;
}
.status-draft { background: #f5f5f5; color: #666; }
.status-in_review { background: #fff8e1; color: #f57c00; }
.status-approved { background: #e8f5e9; color: #2e7d32; }
.status-published { background: #e3f2fd; color: #1565c0; }
.status-archived { background: #efebe9; color: #795548; }
.status-expired { background: #ffebee; color: #c62828; }
</style>
