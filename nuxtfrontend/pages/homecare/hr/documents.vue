<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Document Management"
      subtitle="Central repository for contracts, policies, certifications, and employee records — with versioning & access control."
      eyebrow="HR · DOCUMENTS"
      icon="mdi-file-document-multiple-outline"
      :chips="[
        { icon: 'mdi-file-multiple', label: `${items.length} documents` },
        { icon: 'mdi-shield-lock', label: `${restrictedCount} restricted` },
        { icon: 'mdi-alert', label: `${expiringCount} expiring` },
        { icon: 'mdi-folder', label: `${categories.length} categories` },
      ]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-upload"
               class="text-none" @click="openUploadDialog">
          <span class="text-teal-darken-2 font-weight-bold">Upload</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row dense>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Total Documents" :value="items.length" icon="mdi-file-multiple" color="#0d9488" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Restricted" :value="restrictedCount" icon="mdi-shield-lock" color="#ef4444" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Expiring" :value="expiringCount" icon="mdi-alert" color="#f59e0b" /></v-col>
      <v-col cols="12" sm="6" md="3"><HomecareKpiCard label="Storage Used" :value="storageUsed" suffix="MB" icon="mdi-database" color="#8b5cf6" /></v-col>
    </v-row>

    <v-row dense>
      <!-- Categories -->
      <v-col cols="12" lg="3">
        <HomecarePanel title="Categories" icon="mdi-folder-multiple" color="#0d9488">
          <v-list density="compact" class="bg-transparent pa-0" v-model:selected="selectedCategory">
            <v-list-item value="" rounded="lg" class="mb-1">
              <template #prepend><v-icon icon="mdi-file-multiple" /></template>
              <v-list-item-title>All documents</v-list-item-title>
              <template #append><v-chip size="x-small" variant="tonal">{{ items.length }}</v-chip></template>
            </v-list-item>
            <v-list-item v-for="c in categories" :key="c.value" :value="c.value" rounded="lg" class="mb-1">
              <template #prepend><v-icon :icon="c.icon" :color="c.color" /></template>
              <v-list-item-title>{{ c.label }}</v-list-item-title>
              <template #append><v-chip size="x-small" variant="tonal" :color="c.color">{{ countByCategory(c.value) }}</v-chip></template>
            </v-list-item>
          </v-list>
        </HomecarePanel>
      </v-col>

      <!-- Documents -->
      <v-col cols="12" lg="9">
        <HomecarePanel title="Document Library" subtitle="All HR documents" icon="mdi-file-document" color="#7c3aed">
          <v-row dense class="mb-2">
            <v-col cols="12" md="5">
              <v-text-field v-model="search" prepend-inner-icon="mdi-magnify" placeholder="Search documents…"
                            density="compact" variant="outlined" hide-details clearable />
            </v-col>
            <v-col cols="12" md="4">
              <v-select v-model="filterEmployee" :items="employees" item-title="name" item-value="id"
                        label="Employee" density="compact" variant="outlined" hide-details clearable />
            </v-col>
            <v-col cols="12" md="3">
              <v-select v-model="filterAccess" :items="accessLevels" item-title="label" item-value="value"
                        label="Access" density="compact" variant="outlined" hide-details clearable />
            </v-col>
          </v-row>

          <v-data-table :headers="headers" :items="filtered" :loading="loading" item-value="id" class="hc-table">
            <template #[`item.name`]="{ item }">
              <div class="d-flex align-center">
                <v-avatar size="32" :color="docColor(item.category)" variant="tonal" class="mr-2">
                  <v-icon :icon="docIcon(item.category)" size="16" />
                </v-avatar>
                <div>
                  <div class="font-weight-medium text-body-2">{{ item.name }}</div>
                  <div class="text-caption text-medium-emphasis">{{ item.file_type || 'file' }} · {{ formatSize(item.file_size) }}</div>
                </div>
              </div>
            </template>
            <template #[`item.employee_name`]="{ item }">
              {{ item.employee_name || '—' }}
            </template>
            <template #[`item.category`]="{ item }">
              <v-chip size="small" variant="tonal" :color="catColor(item.category)">{{ catLabel(item.category) }}</v-chip>
            </template>
            <template #[`item.access_level`]="{ item }">
              <v-chip size="small" variant="tonal" :color="accessColor(item.access_level)" prepend-icon="mdi-shield">
                {{ accessLabel(item.access_level) }}
              </v-chip>
            </template>
            <template #[`item.expiry_date`]="{ item }">
              <span v-if="item.expiry_date" :class="expiryClass(item.expiry_date)">{{ formatDate(item.expiry_date) }}</span>
              <span v-else class="text-medium-emphasis">—</span>
            </template>
            <template #[`item.uploaded_at`]="{ item }">{{ formatDate(item.uploaded_at) }}</template>
            <template #[`item.actions`]="{ item }">
              <v-menu location="bottom end">
                <template #activator="{ props }">
                  <v-btn icon="mdi-dots-vertical" variant="text" size="small" v-bind="props" />
                </template>
                <v-list density="compact" min-width="200">
                  <v-list-item v-if="previewType(item)" prepend-icon="mdi-eye-outline" title="View document" @click="openViewer(item)" />
                  <v-list-item prepend-icon="mdi-download" title="Download" @click="download(item)" />
                  <v-list-item prepend-icon="mdi-eye" title="View details" @click="viewItem(item)" />
                  <v-list-item prepend-icon="mdi-pencil" title="Edit" @click="openEditDialog(item)" />
                  <v-list-item prepend-icon="mdi-share-variant" title="Share" @click="share(item)" />
                  <v-divider />
                  <v-list-item prepend-icon="mdi-delete" title="Delete" base-color="error" @click="confirmDelete(item)" />
                </v-list>
              </v-menu>
            </template>
          </v-data-table>
        </HomecarePanel>
      </v-col>
    </v-row>

    <!-- Upload dialog -->
    <v-dialog v-model="uploadDialog" max-width="560" scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center"><v-icon icon="mdi-upload" class="mr-2" />Upload Document</v-card-title>
        <v-divider />
        <v-card-text style="max-height:72vh">
          <v-text-field v-model="uploadForm.name" label="Document name *" density="comfortable" variant="outlined" />
          <v-select v-model="uploadForm.category" :items="categories" item-title="label" item-value="value"
                    label="Category *" density="comfortable" variant="outlined" />
          <v-select v-model="uploadForm.employee" :items="employees" item-title="name" item-value="id"
                    label="Linked employee" density="comfortable" variant="outlined" clearable />
          <v-select v-model="uploadForm.access_level" :items="accessLevels" item-title="label" item-value="value"
                    label="Access level" density="comfortable" variant="outlined" />
          <v-text-field v-model="uploadForm.expiry_date" label="Expiry date (optional)" type="date"
                        density="comfortable" variant="outlined" />
          <v-file-input v-model="uploadForm.file" label="Select file *" prepend-icon="mdi-paperclip"
                        density="comfortable" variant="outlined" show-size />
          <v-textarea v-model="uploadForm.description" label="Description" rows="2" density="comfortable" variant="outlined" />
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="uploadDialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" :loading="saving" @click="upload">Upload</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Edit dialog -->
    <v-dialog v-model="editDialog" max-width="560" scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center"><v-icon icon="mdi-pencil" class="mr-2" />Edit Document</v-card-title>
        <v-divider />
        <v-card-text style="max-height:72vh">
          <v-text-field v-model="editForm.name" label="Document name *" density="comfortable" variant="outlined" />
          <v-select v-model="editForm.category" :items="categories" item-title="label" item-value="value"
                    label="Category *" density="comfortable" variant="outlined" />
          <v-select v-model="editForm.employee" :items="employees" item-title="name" item-value="id"
                    label="Linked employee" density="comfortable" variant="outlined" clearable />
          <v-select v-model="editForm.access_level" :items="accessLevels" item-title="label" item-value="value"
                    label="Access level" density="comfortable" variant="outlined" />
          <v-text-field v-model="editForm.expiry_date" label="Expiry date (optional)" type="date"
                        density="comfortable" variant="outlined" />
          <v-file-input v-model="editForm.file" label="Replace file (optional)" prepend-icon="mdi-paperclip"
                        density="comfortable" variant="outlined" show-size clearable />
          <div v-if="editItem && editItem.file_url && !editForm.file" class="text-caption text-medium-emphasis mb-2">
            <v-icon icon="mdi-paperclip" size="14" class="mr-1" />Current: {{ editItem.file_type || 'file' }} · {{ formatSize(editItem.file_size) }}
          </div>
          <v-textarea v-model="editForm.description" label="Description" rows="2" density="comfortable" variant="outlined" />
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="editDialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" :loading="saving" @click="saveEdit">Save changes</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Detail dialog -->
    <v-dialog v-model="detailDialog" max-width="480">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center"><v-icon icon="mdi-file-document" class="mr-2" />Document Details</v-card-title>
        <v-divider />
        <v-card-text v-if="detailItem">
          <v-row dense>
            <v-col cols="12"><div class="text-caption text-medium-emphasis">Name</div><div class="font-weight-medium">{{ detailItem.name }}</div></v-col>
            <v-col cols="6"><div class="text-caption text-medium-emphasis">Category</div><div class="font-weight-medium">{{ catLabel(detailItem.category) }}</div></v-col>
            <v-col cols="6"><div class="text-caption text-medium-emphasis">Access</div><div class="font-weight-medium">{{ accessLabel(detailItem.access_level) }}</div></v-col>
            <v-col cols="6"><div class="text-caption text-medium-emphasis">Employee</div><div class="font-weight-medium">{{ detailItem.employee_name || '—' }}</div></v-col>
            <v-col cols="6"><div class="text-caption text-medium-emphasis">Size</div><div class="font-weight-medium">{{ formatSize(detailItem.file_size) }}</div></v-col>
            <v-col cols="6"><div class="text-caption text-medium-emphasis">Uploaded</div><div class="font-weight-medium">{{ formatDate(detailItem.uploaded_at) }}</div></v-col>
            <v-col cols="6"><div class="text-caption text-medium-emphasis">Expires</div><div class="font-weight-medium">{{ detailItem.expiry_date ? formatDate(detailItem.expiry_date) : '—' }}</div></v-col>
            <v-col v-if="detailItem.description" cols="12"><div class="text-caption text-medium-emphasis">Description</div><div>{{ detailItem.description }}</div></v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions>
          <v-btn v-if="detailItem && previewType(detailItem)" variant="flat" color="teal" prepend-icon="mdi-eye-outline" @click="openViewer(detailItem)">View</v-btn>
          <v-btn variant="text" prepend-icon="mdi-pencil" @click="openEditDialog(detailItem)">Edit</v-btn>
          <v-btn variant="text" prepend-icon="mdi-download" @click="download(detailItem)">Download</v-btn>
          <v-spacer />
          <v-btn variant="text" @click="detailDialog = false">Close</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Premium document viewer -->
    <v-dialog v-model="viewerDialog" fullscreen transition="dialog-bottom-transition" scrollable
              content-class="hc-viewer-dialog">
      <v-card rounded="0" class="d-flex flex-column hc-viewer-root">
        <!-- Top toolbar -->
        <v-toolbar flat density="compact" class="hc-viewer-toolbar flex-grow-0">
          <v-icon icon="mdi-file-eye-outline" class="ml-4 mr-2" color="white" />
          <v-toolbar-title class="text-white text-body-1 font-weight-medium" style="overflow:hidden; text-overflow:ellipsis; white-space:nowrap;">
            {{ viewerItem?.name }}
          </v-toolbar-title>
          <v-chip v-if="viewerItem" size="x-small" variant="flat" color="white" class="mr-2 d-none d-sm-inline-flex text-teal-darken-2 font-weight-bold">
            {{ (viewerItem.file_type || 'file').toUpperCase() }}
          </v-chip>
          <v-spacer />
          <v-btn icon variant="text" color="white" @click="closeViewer">
            <v-icon icon="mdi-close" />
            <v-tooltip activator="parent" location="bottom">Close (Esc)</v-tooltip>
          </v-btn>
        </v-toolbar>

        <!-- Controls bar -->
        <div v-if="viewerItem && previewType(viewerItem) === 'image'" class="hc-controls-bar flex-grow-0">
          <div class="hc-controls-group">
            <v-btn icon variant="text" size="small" color="teal-darken-2" @click="zoomOut" :disabled="viewerZoom <= 0.2">
              <v-icon icon="mdi-magnify-minus" />
              <v-tooltip activator="parent" location="bottom">Zoom out (-)</v-tooltip>
            </v-btn>
            <span class="hc-zoom-label">{{ Math.round(viewerZoom * 100) }}%</span>
            <v-btn icon variant="text" size="small" color="teal-darken-2" @click="zoomIn" :disabled="viewerZoom >= 5">
              <v-icon icon="mdi-magnify-plus" />
              <v-tooltip activator="parent" location="bottom">Zoom in (+)</v-tooltip>
            </v-btn>
          </div>
          <v-divider vertical class="mx-2" />
          <div class="hc-controls-group">
            <v-btn icon variant="text" size="small" color="teal-darken-2" @click="fitToScreen">
              <v-icon icon="mdi-fit-to-screen" />
              <v-tooltip activator="parent" location="bottom">Fit to screen (0)</v-tooltip>
            </v-btn>
            <v-btn icon variant="text" size="small" color="teal-darken-2" @click="actualSize">
              <v-icon icon="mdi-arrow-expand-all" />
              <v-tooltip activator="parent" location="bottom">Actual size (1)</v-tooltip>
            </v-btn>
          </div>
          <v-divider vertical class="mx-2" />
          <div class="hc-controls-group">
            <v-btn icon variant="text" size="small" color="blue-darken-2" @click="rotateLeft">
              <v-icon icon="mdi-rotate-left" />
              <v-tooltip activator="parent" location="bottom">Rotate left (L)</v-tooltip>
            </v-btn>
            <v-btn icon variant="text" size="small" color="blue-darken-2" @click="rotateRight">
              <v-icon icon="mdi-rotate-right" />
              <v-tooltip activator="parent" location="bottom">Rotate right (R)</v-tooltip>
            </v-btn>
            <span class="hc-zoom-label">{{ viewerRotation }}°</span>
          </div>
          <v-divider vertical class="mx-2" />
          <div class="hc-controls-group">
            <v-btn icon variant="text" size="small" color="teal-darken-2" @click="resetView">
              <v-icon icon="mdi-refresh" />
              <v-tooltip activator="parent" location="bottom">Reset view</v-tooltip>
            </v-btn>
          </div>
          <v-spacer />
          <div class="hc-controls-group">
            <v-btn variant="tonal" size="small" color="teal" prepend-icon="mdi-download" @click="download(viewerItem)">Download</v-btn>
          </div>
        </div>

        <!-- PDF controls bar -->
        <div v-else-if="viewerItem && previewType(viewerItem) === 'pdf'" class="hc-controls-bar flex-grow-0">
          <v-icon icon="mdi-file-pdf-box" color="red" class="ml-2" />
          <span class="hc-zoom-label ml-2">PDF Document</span>
          <v-spacer />
          <v-progress-circular v-if="pdfLoading" indeterminate size="16" width="2" color="teal" class="mr-3" />
          <v-btn variant="tonal" size="small" color="teal" prepend-icon="mdi-open-in-new" @click="download(viewerItem)">Open in new tab</v-btn>
          <v-btn variant="tonal" size="small" color="teal" prepend-icon="mdi-download" class="ml-2" @click="download(viewerItem)">Download</v-btn>
        </div>

        <!-- Office controls bar -->
        <div v-else-if="viewerItem && previewType(viewerItem) === 'office'" class="hc-controls-bar flex-grow-0">
          <v-icon icon="mdi-file-word-box" color="blue" class="ml-2" />
          <span class="hc-zoom-label ml-2">{{ (viewerItem.file_type || 'doc').toUpperCase() }} Document</span>
          <v-spacer />
          <v-btn variant="tonal" size="small" color="teal" prepend-icon="mdi-open-in-new" @click="download(viewerItem)">Open in new tab</v-btn>
          <v-btn variant="tonal" size="small" color="teal" prepend-icon="mdi-download" class="ml-2" @click="download(viewerItem)">Download</v-btn>
        </div>

        <!-- Viewer canvas -->
        <div ref="viewerCanvas" class="hc-viewer-canvas"
             @mousedown="onDragStart" @mousemove="onDragMove" @mouseup="onDragEnd" @mouseleave="onDragEnd"
             @wheel.prevent="onWheel" @dblclick="onDoubleClick"
             :class="{ 'hc-grab': previewType(viewerItem) === 'image' && !isDragging, 'hc-grabbing': isDragging }">
          <!-- Image -->
          <img v-if="viewerItem && previewType(viewerItem) === 'image'"
               :src="viewerItem.file_url"
               :alt="viewerItem.name"
               :style="imageStyle"
               class="hc-viewer-image"
               @load="onImageLoad"
               draggable="false" />
          <!-- PDF -->
          <div v-else-if="viewerItem && previewType(viewerItem) === 'pdf'" class="hc-viewer-pdf-wrap">
            <div v-if="pdfLoading" class="hc-viewer-loading">
              <v-progress-circular indeterminate size="48" width="4" color="teal" />
              <div class="text-teal-darken-2 mt-3 text-body-2">Loading PDF…</div>
            </div>
            <iframe v-else-if="pdfBlobUrl" :src="pdfBlobUrl" class="hc-viewer-pdf" frameborder="0" />
            <div v-else class="hc-viewer-fallback">
              <v-icon icon="mdi-file-pdf-box" size="72" color="red-lighten-2" />
              <div class="text-h6 text-teal-darken-2 mt-4 font-weight-medium">PDF could not be loaded inline</div>
              <v-btn variant="flat" color="teal" prepend-icon="mdi-open-in-new" class="mt-4" @click="download(viewerItem)">Open in new tab</v-btn>
            </div>
          </div>
          <!-- Office documents (Google Docs viewer) -->
          <iframe v-else-if="viewerItem && previewType(viewerItem) === 'office'"
                  :src="officeViewerUrl(viewerItem)"
                  class="hc-viewer-pdf"
                  frameborder="0" />
          <!-- Not previewable -->
          <div v-else class="hc-viewer-fallback">
            <v-icon icon="mdi-file-question-outline" size="72" color="teal-lighten-2" />
            <div class="text-h6 text-teal-darken-2 mt-4 font-weight-medium">Preview not available for this file type</div>
            <div class="text-body-2 text-blue-grey-lighten-1 mt-1">{{ viewerItem?.file_type || 'file' }} · {{ formatSize(viewerItem?.file_size) }}</div>
            <v-btn variant="flat" color="teal" prepend-icon="mdi-download" class="mt-5" @click="download(viewerItem)">Download file</v-btn>
          </div>
        </div>

        <!-- Bottom status bar -->
        <div v-if="viewerItem && previewType(viewerItem) === 'image'" class="hc-status-bar flex-grow-0">
          <v-icon icon="mdi-gesture-tap" size="14" class="mr-1" color="teal-darken-1" />
          <span class="text-caption">Double-click to zoom · Drag to pan · Scroll to zoom · Keyboard: +/− zoom · R rotate · 0 fit · Esc close</span>
        </div>
      </v-card>
    </v-dialog>

    <!-- Delete confirm -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="xl">
        <v-card-title>Delete document?</v-card-title>
        <v-card-text>This permanently removes <b>{{ deleteTarget?.name }}</b>.</v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" variant="flat" :loading="saving" @click="doDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snackbar.show" :color="snackbar.color" location="top right" timeout="3000">
      {{ snackbar.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()
const route = useRoute()

const items = ref([])
const employees = ref([])
const loading = ref(false)
const saving = ref(false)
const search = ref('')
const filterEmployee = ref(null)
const filterAccess = ref(null)
const selectedCategory = ref([''])
const uploadDialog = ref(false)
const editDialog = ref(false)
const editItem = ref(null)
const detailDialog = ref(false)
const detailItem = ref(null)
const viewerDialog = ref(false)
const viewerItem = ref(null)
const viewerZoom = ref(1)
const viewerRotation = ref(0)
const viewerPanX = ref(0)
const viewerPanY = ref(0)
const isDragging = ref(false)
const dragStartX = ref(0)
const dragStartY = ref(0)
const dragStartPanX = ref(0)
const dragStartPanY = ref(0)
const imgNaturalW = ref(0)
const imgNaturalH = ref(0)
const viewerCanvas = ref(null)
const pdfBlobUrl = ref(null)
const pdfLoading = ref(false)
const deleteDialog = ref(false)
const deleteTarget = ref(null)

const uploadForm = reactive({ name: '', category: 'contract', employee: null, access_level: 'hr_only', expiry_date: '', file: null, description: '' })
const editForm = reactive({ name: '', category: 'contract', employee: null, access_level: 'hr_only', expiry_date: '', file: null, description: '' })

const snackbar = reactive({ show: false, color: 'success', text: '' })
function notify(text, color = 'success') { Object.assign(snackbar, { show: true, text, color }) }

const categories = [
  { value: 'contract', label: 'Employment Contracts', icon: 'mdi-file-sign', color: 'teal' },
  { value: 'policy', label: 'Policies & Procedures', icon: 'mdi-book-open-variant', color: 'blue' },
  { value: 'certification', label: 'Certifications', icon: 'mdi-certificate', color: 'purple' },
  { value: 'id_document', label: 'ID Documents', icon: 'mdi-card-account-details', color: 'amber' },
  { value: 'medical', label: 'Medical Records', icon: 'mdi-medical-bag', color: 'red' },
  { value: 'training', label: 'Training Records', icon: 'mdi-school', color: 'indigo' },
  { value: 'performance', label: 'Performance Docs', icon: 'mdi-chart-line', color: 'pink' },
  { value: 'other', label: 'Other', icon: 'mdi-file', color: 'grey' },
]
const accessLevels = [
  { value: 'public', label: 'All Staff' },
  { value: 'hr_only', label: 'HR Only' },
  { value: 'manager', label: 'Manager + HR' },
  { value: 'restricted', label: 'Restricted' },
]

const headers = [
  { title: 'Document', key: 'name' },
  { title: 'Employee', key: 'employee_name' },
  { title: 'Category', key: 'category' },
  { title: 'Access', key: 'access_level' },
  { title: 'Expires', key: 'expiry_date' },
  { title: 'Uploaded', key: 'uploaded_at' },
  { title: '', key: 'actions', sortable: false, align: 'end' },
]

const filtered = computed(() => {
  const q = search.value.toLowerCase()
  const cat = selectedCategory.value?.[0]
  return items.value.filter(i => {
    if (cat && cat !== '' && i.category !== cat) return false
    if (filterEmployee.value && i.employee !== filterEmployee.value) return false
    if (filterAccess.value && i.access_level !== filterAccess.value) return false
    if (q && !`${i.name} ${i.employee_name || ''}`.toLowerCase().includes(q)) return false
    return true
  })
})
const restrictedCount = computed(() => items.value.filter(i => i.access_level === 'restricted' || i.access_level === 'hr_only').length)
const expiringCount = computed(() => items.value.filter(i => i.expiry_date && daysUntil(i.expiry_date) <= 30 && daysUntil(i.expiry_date) >= 0).length)
const storageUsed = computed(() => Math.round(items.value.reduce((s, i) => s + (i.file_size || 0), 0) / 1024 / 1024))

function countByCategory(cat) { return items.value.filter(i => i.category === cat).length }
function daysUntil(d) { return Math.round((new Date(d) - Date.now()) / 86400000) }
function formatDate(d) { if (!d) return ''; try { return new Date(d).toLocaleDateString() } catch { return d } }
function formatSize(bytes) {
  if (!bytes) return '—'
  if (bytes < 1024) return bytes + ' B'
  if (bytes < 1048576) return (bytes / 1024).toFixed(1) + ' KB'
  return (bytes / 1048576).toFixed(1) + ' MB'
}
function catLabel(c) { return categories.find(cat => cat.value === c)?.label || c || '—' }
function catColor(c) { return categories.find(cat => cat.value === c)?.color || 'teal' }
function docColor(c) { return catColor(c) }
function docIcon(c) { return categories.find(cat => cat.value === c)?.icon || 'mdi-file' }
function accessLabel(a) { return accessLevels.find(l => l.value === a)?.label || a }
function accessColor(a) { return { public: 'success', hr_only: 'warning', manager: 'info', restricted: 'error' }[a] || 'grey' }
function expiryClass(d) {
  const days = daysUntil(d)
  if (days < 0) return 'text-red font-weight-bold'
  if (days <= 30) return 'text-orange font-weight-medium'
  return ''
}

async function load() {
  loading.value = true
  try {
    const params = { page_size: 500 }
    if (route.query.employee) params.employee = route.query.employee
    const [docs, emp] = await Promise.all([
      $api.get('/homecare/hr/documents/', { params }).catch(() => ({ data: [] })),
      $api.get('/homecare/hr/employees/', { params: { page_size: 500 } }).catch(() => ({ data: [] })),
    ])
    items.value = docs.data?.results || docs.data || []
    employees.value = (emp.data?.results || emp.data || []).map(e => ({ id: e.id, name: e.name || `${e.first_name || ''} ${e.last_name || ''}`.trim() }))
    if (route.query.employee) filterEmployee.value = Number(route.query.employee)
  } catch (e) {
    console.warn('load documents failed', e)
  } finally { loading.value = false }
}

function openUploadDialog() {
  Object.assign(uploadForm, { name: '', category: 'contract', employee: filterEmployee.value, access_level: 'hr_only', expiry_date: '', file: null, description: '' })
  uploadDialog.value = true
}
function openEditDialog(item) {
  editItem.value = item
  Object.assign(editForm, {
    name: item.name || '', category: item.category || 'contract',
    employee: item.employee || null, access_level: item.access_level || 'hr_only',
    expiry_date: item.expiry_date || '', file: null,
    description: item.description || '',
  })
  detailDialog.value = false
  editDialog.value = true
}
async function saveEdit() {
  if (!editForm.name) { notify('Name required.', 'error'); return }
  saving.value = true
  try {
    const formData = new FormData()
    formData.append('name', editForm.name)
    formData.append('category', editForm.category)
    formData.append('access_level', editForm.access_level)
    if (editForm.employee) formData.append('employee', editForm.employee)
    if (editForm.expiry_date) formData.append('expiry_date', editForm.expiry_date)
    if (editForm.description) formData.append('description', editForm.description)
    if (editForm.file) formData.append('file', editForm.file)
    await $api.patch(`/homecare/hr/documents/${editItem.value.id}/`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    })
    notify('Document updated.')
    editDialog.value = false
    load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to update.', 'error')
  } finally { saving.value = false }
}
async function upload() {
  if (!uploadForm.name || !uploadForm.file) { notify('Name and file required.', 'error'); return }
  saving.value = true
  try {
    const formData = new FormData()
    Object.keys(uploadForm).forEach(k => {
      if (uploadForm[k] !== null && uploadForm[k] !== '' && k !== 'file') formData.append(k, uploadForm[k])
    })
    formData.append('file', uploadForm.file)
    await $api.post('/homecare/hr/documents/', formData, { headers: { 'Content-Type': 'multipart/form-data' } })
    notify('Document uploaded.')
    uploadDialog.value = false
    load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to upload.', 'error')
  } finally { saving.value = false }
}

function viewItem(item) { detailItem.value = item; detailDialog.value = true }

const imageStyle = computed(() => ({
  transform: `translate(${viewerPanX.value}px, ${viewerPanY.value}px) scale(${viewerZoom.value}) rotate(${viewerRotation.value}deg)`,
  transition: isDragging.value ? 'none' : 'transform 0.2s ease',
}))

function resetView() {
  viewerZoom.value = 1
  viewerRotation.value = 0
  viewerPanX.value = 0
  viewerPanY.value = 0
}
function openViewer(item) {
  viewerItem.value = item
  detailDialog.value = false
  resetView()
  pdfBlobUrl.value = null
  pdfLoading.value = false
  viewerDialog.value = true
  nextTick(() => { window.addEventListener('keydown', onKeydown) })
  const ptype = previewType(item)
  if (ptype === 'pdf') loadPdfBlob(item)
}
function closeViewer() {
  viewerDialog.value = false
  window.removeEventListener('keydown', onKeydown)
  if (pdfBlobUrl.value) { URL.revokeObjectURL(pdfBlobUrl.value); pdfBlobUrl.value = null }
}
function previewType(item) {
  if (!item?.file_url) return null
  const ext = (item.file_type || item.file_url.split('.').pop() || '').toLowerCase()
  const imageExts = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg']
  const pdfExts = ['pdf']
  const officeExts = ['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'odt', 'ods', 'odp']
  if (imageExts.includes(ext)) return 'image'
  if (pdfExts.includes(ext)) return 'pdf'
  if (officeExts.includes(ext)) return 'office'
  return null
}
async function loadPdfBlob(item) {
  if (!item?.file_url) return
  pdfLoading.value = true
  try {
    const res = await fetch(item.file_url)
    const blob = await res.blob()
    pdfBlobUrl.value = URL.createObjectURL(blob)
  } catch (e) {
    console.warn('Failed to load PDF blob', e)
  } finally { pdfLoading.value = false }
}
function officeViewerUrl(item) {
  if (!item?.file_url) return ''
  return `https://docs.google.com/gview?url=${encodeURIComponent(item.file_url)}&embedded=true`
}
function onImageLoad(e) {
  imgNaturalW.value = e.target.naturalWidth
  imgNaturalH.value = e.target.naturalHeight
  fitToScreen()
}
function zoomIn() { viewerZoom.value = Math.min(viewerZoom.value + 0.2, 5) }
function zoomOut() { viewerZoom.value = Math.max(viewerZoom.value - 0.2, 0.2) }
function rotateLeft() { viewerRotation.value = (viewerRotation.value - 90 + 360) % 360 }
function rotateRight() { viewerRotation.value = (viewerRotation.value + 90) % 360 }
function fitToScreen() {
  if (!viewerCanvas.value || !imgNaturalW.value) { viewerZoom.value = 1; return }
  const cw = viewerCanvas.value.clientWidth
  const ch = viewerCanvas.value.clientHeight
  const scaleW = cw / imgNaturalW.value
  const scaleH = ch / imgNaturalH.value
  viewerZoom.value = Math.min(scaleW, scaleH) * 0.9
  viewerPanX.value = 0
  viewerPanY.value = 0
}
function actualSize() {
  viewerZoom.value = 1
  viewerPanX.value = 0
  viewerPanY.value = 0
}
function onWheel(e) {
  if (e.deltaY < 0) zoomIn()
  else zoomOut()
}
function onDoubleClick() {
  if (viewerZoom.value > 1.5) fitToScreen()
  else { viewerZoom.value = 2.5 }
}
function onDragStart(e) {
  if (previewType(viewerItem.value) !== 'image') return
  isDragging.value = true
  dragStartX.value = e.clientX
  dragStartY.value = e.clientY
  dragStartPanX.value = viewerPanX.value
  dragStartPanY.value = viewerPanY.value
}
function onDragMove(e) {
  if (!isDragging.value) return
  viewerPanX.value = dragStartPanX.value + (e.clientX - dragStartX.value)
  viewerPanY.value = dragStartPanY.value + (e.clientY - dragStartY.value)
}
function onDragEnd() { isDragging.value = false }
function onKeydown(e) {
  if (!viewerDialog.value) return
  switch (e.key) {
    case '+': case '=': zoomIn(); break
    case '-': case '_': zoomOut(); break
    case '0': fitToScreen(); break
    case '1': actualSize(); break
    case 'r': case 'R': rotateRight(); break
    case 'l': case 'L': rotateLeft(); break
    case 'Escape': closeViewer(); break
    case 'ArrowLeft': viewerPanX.value += 30; break
    case 'ArrowRight': viewerPanX.value -= 30; break
    case 'ArrowUp': viewerPanY.value += 30; break
    case 'ArrowDown': viewerPanY.value -= 30; break
  }
}
onBeforeUnmount(() => { window.removeEventListener('keydown', onKeydown) })
function download(item) {
  if (item?.file_url) window.open(item.file_url, '_blank')
  else notify('File not available.', 'info')
}
function share(item) { notify(`Share link for "${item.name}" copied.`, 'info') }
function confirmDelete(item) { deleteTarget.value = item; deleteDialog.value = true }
async function doDelete() {
  saving.value = true
  try {
    await $api.delete(`/homecare/hr/documents/${deleteTarget.value.id}/`)
    notify('Document deleted.')
    deleteDialog.value = false
    load()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed.', 'error')
  } finally { saving.value = false }
}

onMounted(load)
</script>

<style scoped>
.hc-bg { background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%); min-height: calc(100vh - 64px); }
.hc-table :deep(td) { vertical-align: middle; }
:global(.v-theme--dark .hc-bg) { background: linear-gradient(180deg, #0f172a 0%, #1e293b 100%); }

/* ── Premium document viewer — teal/blue/white ── */
.hc-viewer-root { background: #f0f9f8; }

.hc-viewer-toolbar {
  background: linear-gradient(135deg, #0d9488 0%, #0f766e 50%, #155e75 100%) !important;
}

.hc-controls-bar {
  display: flex; align-items: center; gap: 4px;
  padding: 6px 16px;
  background: #ffffff;
  border-bottom: 1px solid #e2e8f0;
  min-height: 48px;
  flex-wrap: wrap;
  box-shadow: 0 1px 3px rgba(13,148,136,0.06);
}
.hc-controls-group { display: flex; align-items: center; gap: 2px; }
.hc-zoom-label {
  color: #0f766e;
  font-size: 12px; font-weight: 700;
  min-width: 42px; text-align: center;
  font-variant-numeric: tabular-nums;
}
.hc-viewer-canvas {
  flex: 1; overflow: hidden;
  background: #f0fdfa;
  background-image: radial-gradient(circle, #ccfbf1 1px, transparent 1px);
  background-size: 24px 24px;
  display: flex; align-items: center; justify-content: center;
  position: relative;
  user-select: none;
}
.hc-viewer-image {
  max-width: none; max-height: none;
  will-change: transform;
  pointer-events: none;
  border-radius: 4px;
  box-shadow: 0 4px 24px rgba(13,148,136,0.15), 0 1px 4px rgba(0,0,0,0.05);
}
.hc-grab { cursor: grab; }
.hc-grabbing { cursor: grabbing; }
.hc-viewer-pdf { width: 100%; height: 100%; border: 0; flex: 1; background: white; }
.hc-viewer-pdf-wrap { width: 100%; height: 100%; flex: 1; display: flex; align-items: center; justify-content: center; background: white; }
.hc-viewer-loading { text-align: center; }
.hc-viewer-fallback {
  text-align: center; padding: 32px;
}
.hc-status-bar {
  display: flex; align-items: center;
  padding: 5px 16px;
  background: #ffffff;
  border-top: 1px solid #e2e8f0;
  color: #64748b;
  min-height: 30px;
}
</style>
