<template>
  <v-container fluid class="pa-3 pa-md-5">
    <div class="d-flex justify-center mb-4">
      <div class="d-flex align-center mb-2" style="gap:14px">
        <v-avatar color="primary" variant="tonal" rounded="lg" size="52">
          <v-icon size="28">{{ isEdit ? 'mdi-pencil' : 'mdi-upload' }}</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 text-md-h4 font-weight-bold mb-0">{{ isEdit ? 'Edit Document' : 'Upload Document' }}</h1>
          <div class="text-body-2 text-medium-emphasis">{{ isEdit ? 'Update document metadata' : 'Add a new document to the repository' }}</div>
        </div>
      </div>
    </div>

    <v-card rounded="lg" elevation="0" class="pa-5 mx-auto" style="border:1px solid rgba(0,0,0,0.06); max-width:800px">
      <v-form ref="form" @submit.prevent="save">
        <!-- Animated drop zone for file upload (only for new) -->
        <div v-if="!isEdit" class="mb-5">
          <div
            class="dropzone"
            :class="{ 'dropzone--active': isDragging, 'dropzone--filled': file }"
            @dragover.prevent="isDragging = true"
            @dragleave.prevent="isDragging = false"
            @drop.prevent="onDrop"
            @click="$refs.fileInput.click()"
          >
            <input ref="fileInput" type="file" class="dropzone-input" @change="onFileSelect" />
            <div v-if="!file" class="dropzone-content">
              <v-icon size="48" class="dropzone-icon">mdi-cloud-upload-outline</v-icon>
              <div class="text-subtitle-1 font-weight-medium mt-2">Drop your file here or click to browse</div>
              <div class="text-caption text-medium-emphasis mt-1">PDF, Word, Excel, images — up to 50&nbsp;MB</div>
            </div>
            <div v-else class="dropzone-content">
              <v-icon size="40" :color="fileColor">{{ fileIcon }}</v-icon>
              <div class="text-subtitle-2 font-weight-medium mt-2 text-truncate" style="max-width:340px">{{ file.name }}</div>
              <div class="text-caption text-medium-emphasis mt-1">{{ humanSize(file.size) }}</div>
              <v-btn size="small" variant="text" color="error" class="mt-1" prepend-icon="mdi-close" @click.stop="file = null">Remove</v-btn>
            </div>
          </div>
        </div>

        <v-text-field
          v-model="form.title" label="Title *" variant="outlined" density="compact" rounded="lg"
          :rules="[v => !!v || 'Title is required']" class="mb-3"
        />

        <v-textarea
          v-model="form.description" label="Description" variant="outlined" density="compact" rounded="lg"
          rows="3" class="mb-3" hide-details
        />

        <v-text-field
          v-model="form.reference_number" label="Reference Number" variant="outlined" density="compact" rounded="lg"
          hint="External reference or tracking number (auto-generated if blank)"
          persistent-hint class="mb-3"
        />

        <v-row dense>
          <v-col cols="12" sm="6">
            <v-select
              v-model="form.category" :items="categoryOptions" item-title="label" item-value="value"
              label="Category *" density="compact" variant="outlined" rounded="lg"
              :rules="[v => v != null || 'Category is required']" class="mb-3"
            />
          </v-col>
          <v-col cols="12" sm="6">
            <v-select
              v-model="form.branch" :items="branchOptions" item-title="label" item-value="value"
              label="Branch / Warehouse *" density="compact" variant="outlined" rounded="lg"
              :rules="[v => v != null || 'Branch is required']" class="mb-3"
            />
          </v-col>
        </v-row>

        <!-- Category quick-select chips (below the field) -->
        <div class="mb-3">
          <div class="text-caption text-medium-emphasis mb-1">Quick select a category:</div>
          <div class="d-flex flex-wrap" style="gap:6px">
            <v-chip
              v-for="p in categoryPresets" :key="p.name"
              size="small" variant="tonal" rounded="lg"
              :color="p.color" :prepend-icon="p.icon"
              class="text-none"
              @click="applyCategoryPreset(p)"
            >{{ p.name }}</v-chip>
          </div>
        </div>

        <v-row dense>
          <v-col cols="12" sm="6">
            <v-select
              v-model="form.status" :items="statusOptions" item-title="label" item-value="value"
              label="Status *" density="compact" variant="outlined" rounded="lg" class="mb-3"
              :rules="[v => v != null || 'Status is required']"
            >
              <template #item="{ props: ip, item }">
                <v-list-item v-bind="ip" :title="item.raw.label" :subtitle="item.raw.desc">
                  <template #prepend>
                    <v-icon size="18" :color="item.raw.color">{{ item.raw.icon }}</v-icon>
                  </template>
                </v-list-item>
              </template>
            </v-select>
          </v-col>
          <v-col cols="12" sm="6">
            <v-select
              v-model="form.priority" :items="priorityOptions" item-title="label" item-value="value"
              label="Priority *" density="compact" variant="outlined" rounded="lg" class="mb-3"
              :rules="[v => v != null || 'Priority is required']"
            >
              <template #item="{ props: ip, item }">
                <v-list-item v-bind="ip" :title="item.raw.label" :subtitle="item.raw.desc">
                  <template #prepend>
                    <v-icon size="18" :color="item.raw.color">{{ item.raw.icon }}</v-icon>
                  </template>
                </v-list-item>
              </template>
            </v-select>
          </v-col>
        </v-row>

        <v-text-field
          v-model="form.expires_at" type="date" label="Expiry Date (optional)"
          variant="outlined" density="compact" rounded="lg" class="mb-3" hide-details
        />

        <!-- Tags -->
        <v-combobox
          v-model="form.tags" :items="tagOptions" item-title="name" item-value="id"
          label="Tags" chips multiple closable-chips
          density="compact" variant="outlined" rounded="lg" class="mb-3" hide-details
        />

        <v-divider class="my-4" />

        <!-- Change summary (edit only) -->
        <v-textarea
          v-if="isEdit" v-model="form.change_summary" label="Change summary (optional)"
          variant="outlined" density="compact" rounded="lg" rows="2" hide-details class="mb-3"
        />

        <div class="d-flex" style="gap:8px">
          <v-btn color="primary" variant="flat" rounded="lg" class="text-none" type="submit" :loading="saving">
            {{ isEdit ? 'Save Changes' : 'Upload Document' }}
          </v-btn>
          <v-btn variant="text" rounded="lg" class="text-none" @click="navigateTo('/documents')">Cancel</v-btn>
        </div>
      </v-form>
    </v-card>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useResource } from '~/composables/useResource'
import { useAuthStore } from '~/stores/auth'
import { useBranchStore } from '~/stores/branch'
import { ADMIN_ROLES } from '~/utils/permissions'

const auth = useAuthStore()
const branchStore = useBranchStore()
const canEdit = computed(() => [...ADMIN_ROLES, 'branch_admin'].includes(auth.role))
const { $api } = useNuxtApp()
const route = useRoute()

const isEdit = computed(() => !!route.params.id)
const docId = route.params.id

const form = ref({
  title: '', description: '', reference_number: '',
  category: null, branch: null,
  status: 'draft', priority: 'normal',
  expires_at: '', tags: [], change_summary: '',
})
const file = ref(null)
const saving = ref(false)
const isDragging = ref(false)
const fileInput = ref(null)

// --- File icon/color helpers ---
const FILE_ICONS = {
  pdf: 'mdi-file-pdf-box', doc: 'mdi-file-word-box', docx: 'mdi-file-word-box',
  xls: 'mdi-file-excel-box', xlsx: 'mdi-file-excel-box',
  ppt: 'mdi-file-powerpoint-box', pptx: 'mdi-file-powerpoint-box',
  jpg: 'mdi-file-image', jpeg: 'mdi-file-image', png: 'mdi-file-image', gif: 'mdi-file-image',
  zip: 'mdi-folder-zip', rar: 'mdi-folder-zip', txt: 'mdi-file-document-outline', csv: 'mdi-file-delimited',
}
const FILE_COLORS = {
  pdf: 'error', doc: 'blue', docx: 'blue', xls: 'success', xlsx: 'success',
  ppt: 'orange', pptx: 'orange', jpg: 'purple', jpeg: 'purple', png: 'purple', gif: 'purple',
  zip: 'amber', rar: 'amber', txt: 'grey', csv: 'green',
}
const fileExt = computed(() => {
  if (!file.value?.name) return ''
  return file.value.name.split('.').pop()?.toLowerCase() || ''
})
const fileIcon = computed(() => FILE_ICONS[fileExt.value] || 'mdi-file-document-outline')
const fileColor = computed(() => FILE_COLORS[fileExt.value] || 'primary')

function humanSize(bytes) {
  if (!bytes) return '—'
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`
}

function onFileSelect(e) {
  const f = e.target.files?.[0]
  if (f) file.value = f
}
function onDrop(e) {
  isDragging.value = false
  const f = e.dataTransfer.files?.[0]
  if (f) file.value = f
}

const categoryRes = useResource('/documents/categories/')
const tagRes = useResource('/documents/tags/')
const categoryOptions = computed(() =>
  (categoryRes.items.value || []).map(c => ({ label: c.name, value: c.id }))
)
const tagOptions = computed(() => tagRes.items.value || [])

const branchOptions = computed(() => {
  const source = branchStore.activeBranches
  const opts = []
  for (const b of source) opts.push({ label: b.name, value: b.id })
  return opts
})

const statusOptions = [
  { label: 'Draft', value: 'draft', desc: 'Work in progress, not yet finalized', color: 'grey', icon: 'mdi-pencil' },
  { label: 'In Review', value: 'in_review', desc: 'Awaiting approval or review', color: 'warning', icon: 'mdi-clock-outline' },
  { label: 'Approved', value: 'approved', desc: 'Reviewed and formally approved', color: 'success', icon: 'mdi-check-circle' },
  { label: 'Published', value: 'published', desc: 'Live and available to all users', color: 'primary', icon: 'mdi-cloud-upload' },
  { label: 'Archived', value: 'archived', desc: 'No longer active, kept for records', color: 'brown', icon: 'mdi-archive' },
]

const priorityOptions = [
  { label: 'Low', value: 'low', desc: 'Non-urgent, no deadline pressure', color: 'info', icon: 'mdi-arrow-down-thin' },
  { label: 'Normal', value: 'normal', desc: 'Standard priority for routine documents', color: 'grey', icon: 'mdi-equal' },
  { label: 'High', value: 'high', desc: 'Important — should be addressed soon', color: 'warning', icon: 'mdi-arrow-up-thin' },
  { label: 'Critical', value: 'critical', desc: 'Urgent — requires immediate attention', color: 'error', icon: 'mdi-arrow-up-bold' },
]

const categoryPresets = [
  { name: 'SOPs', icon: 'mdi-clipboard-list-outline', color: 'primary', desc: 'Standard Operating Procedures' },
  { name: 'Policies', icon: 'mdi-shield-book-outline', color: 'success', desc: 'Organizational policies and rules' },
  { name: 'Licenses', icon: 'mdi-certificate-outline', color: 'warning', desc: 'Regulatory licenses and permits' },
  { name: 'Invoices', icon: 'mdi-receipt-text-outline', color: 'info', desc: 'Billing and invoice records' },
  { name: 'Contracts', icon: 'mdi-file-sign', color: 'purple', desc: 'Agreements and legal contracts' },
  { name: 'MSDS', icon: 'mdi-chemistry', color: 'error', desc: 'Material Safety Data Sheets' },
  { name: 'Manuals', icon: 'mdi-book-open-variant', color: 'teal', desc: 'Equipment and user manuals' },
  { name: 'Reports', icon: 'mdi-chart-box-outline', color: 'indigo', desc: 'Analytical and audit reports' },
  { name: 'Training', icon: 'mdi-school-outline', color: 'deep-orange', desc: 'Training materials and guides' },
  { name: 'Inspections', icon: 'mdi-clipboard-check-outline', color: 'brown', desc: 'Inspection and compliance records' },
]

async function applyCategoryPreset(preset) {
  // Check if a category with this name already exists
  const existing = (categoryRes.items.value || []).find(c => c.name.toLowerCase() === preset.name.toLowerCase())
  if (existing) {
    form.value.category = existing.id
    return
  }
  // Create a new category on the fly
  try {
    const { data } = await $api.post('/documents/categories/', {
      name: preset.name,
      description: preset.desc,
      is_active: true,
    })
    await categoryRes.list({ page_size: 500 })
    form.value.category = data.id
  } catch (e) {
    console.error('Failed to create category', e)
    alert('Failed to create category: ' + (e?.response?.data?.detail || e.message))
  }
}

async function save() {
  saving.value = true
  try {
    if (isEdit.value) {
      const payload = { ...form.value }
      // Tags may be objects from combobox
      if (Array.isArray(payload.tags)) {
        payload.tags = payload.tags.map(t => typeof t === 'object' ? t.id : t)
      }
      await $api.patch(`/documents/documents/${docId}/`, payload)
      navigateTo(`/documents/${docId}`)
    } else {
      if (!file.value) {
        alert('Please select a file to upload.')
        return
      }
      const fd = new FormData()
      fd.append('file', file.value)
      const keys = ['title', 'description', 'reference_number', 'category', 'branch', 'status', 'priority', 'expires_at']
      for (const k of keys) {
        if (form.value[k] != null && form.value[k] !== '') {
          fd.append(k, form.value[k])
        }
      }
      // Tags
      if (Array.isArray(form.value.tags)) {
        for (const t of form.value.tags) {
          fd.append('tags', typeof t === 'object' ? t.id : t)
        }
      }
      const { data } = await $api.post('/documents/documents/', fd, { headers: { 'Content-Type': 'multipart/form-data' } })
      navigateTo(`/documents/${data.id}`)
    }
  } catch (e) {
    console.error(e)
    alert('Save failed: ' + (e?.response?.data?.detail || JSON.stringify(e?.response?.data) || e.message))
  } finally {
    saving.value = false
  }
}

onMounted(async () => {
  await branchStore.load()
  categoryRes.list({ page_size: 500 })
  tagRes.list({ page_size: 500 })

  if (isEdit.value) {
    try {
      const { data } = await $api.get(`/documents/documents/${docId}/`)
      form.value = {
        title: data.title || '',
        description: data.description || '',
        reference_number: data.reference_number || '',
        category: data.category || null,
        branch: data.branch || null,
        status: data.status || 'draft',
        priority: data.priority || 'normal',
        expires_at: data.expires_at || '',
        tags: (data.tags_detail || []).map(t => ({ id: t.id, name: t.name })),
        change_summary: '',
      }
    } catch (e) {
      console.error('Failed to load document', e)
    }
  }
})
</script>

<style scoped>
.dropzone {
  position: relative;
  border: 3px dashed rgba(13, 148, 136, 0.3);
  border-radius: 16px;
  padding: 40px 20px;
  text-align: center;
  cursor: pointer;
  transition: all 0.3s ease;
  background: rgba(13, 148, 136, 0.02);
  overflow: hidden;
}
.dropzone::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: 16px;
  padding: 3px;
  background: linear-gradient(90deg, transparent, #0D9488, transparent);
  background-size: 200% 100%;
  -webkit-mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
  -webkit-mask-composite: xor;
  mask-composite: exclude;
  animation: dashborder 3s linear infinite;
  pointer-events: none;
  opacity: 0.5;
}
@keyframes dashborder {
  0%   { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}
.dropzone:hover {
  background: rgba(13, 148, 136, 0.05);
  border-color: rgba(13, 148, 136, 0.5);
}
.dropzone:hover::before {
  opacity: 1;
}
.dropzone--active {
  background: rgba(13, 148, 136, 0.08);
  border-color: #0D9488;
  transform: scale(1.01);
}
.dropzone--active::before {
  opacity: 1;
  animation-duration: 1s;
}
.dropzone--filled {
  border-style: solid;
  border-color: rgba(13, 148, 136, 0.4);
  background: rgba(13, 148, 136, 0.04);
}
.dropzone--filled::before {
  display: none;
}
.dropzone-input {
  display: none;
}
.dropzone-content {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  pointer-events: none;
}
.dropzone-content .v-btn {
  pointer-events: auto;
}
.dropzone-icon {
  animation: bounce 2s ease-in-out infinite;
}
@keyframes bounce {
  0%, 100% { transform: translateY(0); }
  50%      { transform: translateY(-6px); }
}
</style>
