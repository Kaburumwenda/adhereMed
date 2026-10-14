<template>
  <v-container fluid class="pa-3 pa-md-5">
    <v-progress-linear v-if="loading" color="primary" indeterminate class="mb-3" />

    <div v-if="!loading && !doc" class="pa-10 text-center text-medium-emphasis">
      <v-icon size="64" color="grey">mdi-file-question</v-icon>
      <div class="text-h6 mt-3">Document not found</div>
      <v-btn color="primary" variant="flat" rounded="lg" class="text-none mt-3" prepend-icon="mdi-arrow-left" @click="navigateTo('/documents')">Back to Documents</v-btn>
    </div>

    <template v-if="!loading && doc">
      <!-- Breadcrumb + header -->
      <div class="d-flex flex-wrap align-center justify-space-between mb-4">
        <div class="d-flex align-center" style="gap:14px">
          <v-avatar :color="fileColor(doc.file_extension)" variant="tonal" rounded="lg" size="52">
            <v-icon size="28">{{ fileIcon(doc.file_extension) }}</v-icon>
          </v-avatar>
          <div>
            <div class="d-flex align-center" style="gap:8px">
              <h1 class="text-h5 text-md-h4 font-weight-bold mb-0">{{ doc.title }}</h1>
              <v-icon v-if="doc.is_starred" color="warning" size="20">mdi-star</v-icon>
              <v-chip v-if="doc.checked_out_by_name" color="warning" size="small" variant="tonal" prepend-icon="mdi-lock">
                Checked out by {{ doc.checked_out_by_name }}
              </v-chip>
            </div>
            <div class="text-body-2 text-medium-emphasis">
              <span v-if="doc.reference_number">{{ doc.reference_number }}</span>
              <span v-else>DOC-{{ doc.id }}</span>
              <span class="mx-1">•</span>
              {{ doc.uploaded_by_name || '—' }}
              <span class="mx-1">•</span>
              Updated {{ formatStamp(doc.updated_at) }}
            </div>
          </div>
        </div>
        <div class="d-flex align-center flex-wrap mt-2 mt-md-0" style="gap:8px">
          <v-btn variant="tonal" prepend-icon="mdi-arrow-left" rounded="lg" class="text-none" @click="navigateTo('/documents')">Back</v-btn>
          <v-btn variant="tonal" color="warning" prepend-icon="mdi-star" rounded="lg" class="text-none" @click="toggleStar">{{ doc.is_starred ? 'Unstar' : 'Star' }}</v-btn>
          <v-btn variant="tonal" color="success" prepend-icon="mdi-download" rounded="lg" class="text-none" @click="downloadDoc">Download</v-btn>
          <v-btn v-if="canEdit && !doc.checked_out_by" color="warning" variant="tonal" prepend-icon="mdi-lock" rounded="lg" class="text-none" @click="checkout">Check Out</v-btn>
          <v-btn v-if="canEdit && doc.checked_out_by_name" color="success" variant="tonal" prepend-icon="mdi-lock-open" rounded="lg" class="text-none" @click="checkin">Check In</v-btn>
          <v-btn v-if="canEdit" color="primary" prepend-icon="mdi-pencil" rounded="lg" class="text-none" @click="navigateTo(`/documents/${doc.id}/edit`)">Edit</v-btn>
          <v-menu v-if="canEdit" offset="4">
            <template #activator="{ props }">
              <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" />
            </template>
            <v-list density="compact" min-width="200">
              <v-list-item prepend-icon="mdi-share-variant" title="Share with user" @click="shareDialog = true" />
              <v-list-item prepend-icon="mdi-file-sign" title="Request signature" @click="sigDialog = true" />
              <v-list-item prepend-icon="mdi-trash-can" title="Move to trash" @click="softDelete" />
            </v-list>
          </v-menu>
        </div>
      </div>

      <!-- Status / Priority / Category chips -->
      <div class="d-flex flex-wrap mb-3" style="gap:8px">
        <v-chip :color="statusColor(doc.status)" variant="tonal" prepend-icon="mdi-circle-medium">{{ statusLabel(doc.status) }}</v-chip>
        <v-chip v-if="doc.priority !== 'normal'" :color="priorityColor(doc.priority)" variant="tonal" prepend-icon="mdi-flag">{{ priorityLabel(doc.priority) }}</v-chip>
        <v-chip v-if="doc.category_name" color="primary" variant="tonal" prepend-icon="mdi-folder">{{ doc.category_name }}</v-chip>
        <v-chip v-if="doc.branch_name" color="info" variant="tonal" prepend-icon="mdi-store">{{ doc.branch_name }}</v-chip>
        <v-chip v-for="tag in (doc.tag_names || [])" :key="tag" color="purple" size="small" variant="tonal" prepend-icon="mdi-tag">{{ tag }}</v-chip>
        <v-chip v-if="doc.expires_at" color="error" variant="tonal" prepend-icon="mdi-calendar-clock">Expires {{ formatDate(doc.expires_at) }}</v-chip>
      </div>

      <v-row>
        <!-- Left: description + versions + comments -->
        <v-col cols="12" lg="8">
          <!-- Description -->
          <v-card rounded="lg" elevation="0" class="mb-3 pa-4" style="border:1px solid rgba(0,0,0,0.06)">
            <div class="text-subtitle-1 font-weight-bold mb-2">
              <v-icon start>mdi-text</v-icon>Description
            </div>
            <div class="text-body-2 text--primary" style="white-space:pre-wrap; line-height:1.7">
              {{ doc.description || 'No description provided.' }}
            </div>
          </v-card>

          <!-- Upload new version -->
          <v-card v-if="canEdit" rounded="lg" elevation="0" class="mb-3 pa-4" style="border:1px solid rgba(0,0,0,0.06)">
            <div class="d-flex align-center mb-2">
              <span class="text-subtitle-1 font-weight-bold">
                <v-icon start>mdi-file-replace</v-icon>Upload New Version
              </span>
              <v-spacer />
              <span class="text-caption text-medium-emphasis">Current: v{{ doc.version_count || 1 }}</span>
            </div>
            <v-file-input
              v-model="newVersionFile" label="Select file" variant="outlined" density="compact" rounded="lg" hide-details
              prepend-icon="" prepend-inner-icon="mdi-paperclip" class="mb-2"
            />
            <v-textarea
              v-model="newVersionSummary" label="Change summary" variant="outlined" density="compact" rounded="lg" rows="2" hide-details class="mb-2"
            />
            <v-btn color="primary" variant="flat" rounded="lg" class="text-none" prepend-icon="mdi-upload" :loading="uploadingVersion" @click="uploadVersion">Upload Version</v-btn>
          </v-card>

          <!-- Version history -->
          <v-card rounded="lg" elevation="0" class="mb-3 pa-4" style="border:1px solid rgba(0,0,0,0.06)">
            <div class="text-subtitle-1 font-weight-bold mb-3">
              <v-icon start>mdi-history</v-icon>Version History
            </div>
            <v-timeline side="end" density="compact">
              <v-timeline-item v-for="v in (doc.versions || [])" :key="v.id" :dot-color="v.is_current ? 'primary' : 'grey'" size="x-small" fill-dot>
                <div class="d-flex align-center justify-space-between mb-1">
                  <div class="d-flex align-center" style="gap:8px">
                    <v-chip size="small" variant="tonal" :color="v.is_current ? 'primary' : 'default'">v{{ v.version_number }}</v-chip>
                    <span v-if="v.is_current" class="text-caption text-primary font-weight-bold">Current</span>
                  </div>
                  <div class="d-flex align-center" style="gap:4px">
                    <v-btn size="x-small" variant="text" icon="mdi-download" @click="downloadVersion(v)" />
                    <v-btn v-if="canEdit && !v.is_current" size="x-small" variant="text" icon="mdi-undo" @click="restoreVersion(v)" />
                  </div>
                </div>
                <div class="text-body-2 text-medium-emphasis" style="white-space:pre-wrap">{{ v.change_summary || '—' }}</div>
                <div class="text-caption text-medium-emphasis mt-1">
                  {{ v.uploaded_by_name || '—' }} • {{ formatStamp(v.created_at) }}
                  <span v-if="v.file_size">• {{ humanSize(v.file_size) }}</span>
                </div>
              </v-timeline-item>
            </v-timeline>
            <div v-if="!(doc.versions || []).length" class="text-center text-medium-emphasis pa-4">No version history.</div>
          </v-card>

          <!-- Comments -->
          <v-card rounded="lg" elevation="0" class="mb-3 pa-4" style="border:1px solid rgba(0,0,0,0.06)">
            <div class="text-subtitle-1 font-weight-bold mb-3">
              <v-icon start>mdi-comment-text-multiple</v-icon>Comments ({{ (doc.comments || []).length }})
            </div>
            <div v-for="c in (doc.comments || [])" :key="c.id" class="mb-3">
              <div class="d-flex align-start" style="gap:10px">
                <v-avatar color="primary" variant="tonal" size="36"><v-icon>mdi-account</v-icon></v-avatar>
                <div class="flex-grow-1">
                  <div class="d-flex align-center" style="gap:8px">
                    <span class="font-weight-medium">{{ c.author_name || '—' }}</span>
                    <v-chip v-if="c.is_resolved" size="x-small" variant="tonal" color="success">Resolved</v-chip>
                    <span class="text-caption text-medium-emphasis">{{ formatStamp(c.created_at) }}</span>
                  </div>
                  <div class="text-body-2 mt-1">{{ c.body }}</div>
                  <!-- Replies -->
                  <div v-for="r in (c.replies || [])" :key="r.id" class="ml-4 mt-2 d-flex align-start" style="gap:8px">
                    <v-avatar color="info" variant="tonal" size="28"><v-icon size="16">mdi-account</v-icon></v-avatar>
                    <div>
                      <div class="d-flex align-center" style="gap:6px">
                        <span class="font-weight-medium text-body-2">{{ r.author_name || '—' }}</span>
                        <span class="text-caption text-medium-emphasis">{{ formatStamp(r.created_at) }}</span>
                      </div>
                      <div class="text-body-2">{{ r.body }}</div>
                    </div>
                  </div>
                </div>
                <v-btn v-if="canEdit" size="x-small" variant="text" icon="mdi-reply" @click="replyTo = c.id; replyBody = ''" />
                <v-btn v-if="canEdit && !c.is_resolved" size="x-small" variant="text" icon="mdi-check" color="success" @click="resolveComment(c)" />
              </div>
              <div v-if="replyTo === c.id" class="d-flex align-center mt-2 ml-10" style="gap:8px">
                <v-text-field v-model="replyBody" density="compact" variant="outlined" rounded="lg" hide-details placeholder="Reply…" />
                <v-btn size="small" color="primary" variant="flat" rounded="lg" @click="postReply(c)">Send</v-btn>
                <v-btn size="small" variant="text" rounded="lg" @click="replyTo = null">Cancel</v-btn>
              </div>
            </div>
            <div v-if="!(doc.comments || []).length" class="text-center text-medium-emphasis pa-2 mb-2">No comments yet.</div>
            <v-divider class="my-3" />
            <div class="d-flex align-center" style="gap:8px">
              <v-avatar color="primary" variant="tonal" size="36"><v-icon>mdi-account</v-icon></v-avatar>
              <v-textarea v-model="newComment" label="Add a comment…" variant="outlined" density="compact" rounded="lg" rows="2" hide-details auto-grow />
              <v-btn color="primary" variant="flat" rounded="lg" class="text-none align-self-start" prepend-icon="mdi-send" @click="postComment">Post</v-btn>
            </div>
          </v-card>
        </v-col>

        <!-- Right: shares, signatures, activity -->
        <v-col cols="12" lg="4">
          <!-- Shares -->
          <v-card rounded="lg" elevation="0" class="mb-3 pa-4" style="border:1px solid rgba(0,0,0,0.06)">
            <div class="text-subtitle-1 font-weight-bold mb-3">
              <v-icon start>mdi-share-variant</v-icon>Shared with ({{ (doc.shares || []).length }})
            </div>
            <div v-for="s in (doc.shares || [])" :key="s.id" class="d-flex align-center justify-space-between py-1">
              <div class="d-flex align-center" style="gap:8px">
                <v-avatar color="info" variant="tonal" size="30"><v-icon size="16">mdi-account</v-icon></v-avatar>
                <div>
                  <div class="font-weight-medium text-body-2">{{ s.shared_with_name || '—' }}</div>
                  <div class="text-caption text-medium-emphasis">{{ s.shared_by_name || '—' }} • {{ formatStamp(s.created_at) }}</div>
                </div>
              </div>
              <v-chip size="x-small" variant="tonal" :color="shareColor(s.permission)">{{ s.permission }}</v-chip>
            </div>
            <div v-if="!(doc.shares || []).length" class="text-center text-medium-emphasis pa-2">Not shared with anyone.</div>
          </v-card>

          <!-- Signature requests -->
          <v-card rounded="lg" elevation="0" class="mb-3 pa-4" style="border:1px solid rgba(0,0,0,0.06)">
            <div class="text-subtitle-1 font-weight-bold mb-3">
              <v-icon start>mdi-file-sign</v-icon>Signature Requests ({{ (doc.signature_requests || []).length }})
            </div>
            <div v-for="sr in (doc.signature_requests || [])" :key="sr.id" class="mb-2">
              <div class="d-flex align-center justify-space-between">
                <div class="d-flex align-center" style="gap:8px">
                  <v-avatar :color="sigColor(sr.status)" variant="tonal" size="30"><v-icon size="16">mdi-account</v-icon></v-avatar>
                  <div>
                    <div class="font-weight-medium text-body-2">{{ sr.requested_from_name || '—' }}</div>
                    <div class="text-caption text-medium-emphasis">{{ formatStamp(sr.created_at) }}</div>
                  </div>
                </div>
                <v-chip size="x-small" variant="tonal" :color="sigColor(sr.status)">{{ sr.status }}</v-chip>
              </div>
            </div>
            <div v-if="!(doc.signature_requests || []).length" class="text-center text-medium-emphasis pa-2">No signature requests.</div>
          </v-card>

          <!-- Activity log -->
          <v-card rounded="lg" elevation="0" class="mb-3 pa-4" style="border:1px solid rgba(0,0,0,0.06)">
            <div class="text-subtitle-1 font-weight-bold mb-3">
              <v-icon start>mdi-chart-timeline-variant</v-icon>Activity Log
            </div>
            <v-timeline side="end" density="compact">
              <v-timeline-item v-for="a in (doc.activities || []).slice(0, 20)" :key="a.id" dot-color="primary" size="x-small" fill-dot>
                <div class="d-flex align-center" style="gap:6px">
                  <v-icon size="14">{{ activityIcon(a.action) }}</v-icon>
                  <span class="text-body-2 font-weight-medium">{{ activityLabel(a.action) }}</span>
                  <span v-if="a.detail" class="text-caption text-medium-emphasis">— {{ a.detail }}</span>
                </div>
                <div class="text-caption text-medium-emphasis">{{ a.user_name || 'System' }} • {{ formatStamp(a.created_at) }}</div>
              </v-timeline-item>
            </v-timeline>
            <div v-if="!(doc.activities || []).length" class="text-center text-medium-emphasis pa-2">No activity recorded.</div>
          </v-card>
        </v-col>
      </v-row>

      <!-- Share dialog -->
      <v-dialog v-model="shareDialog" max-width="500">
        <v-card rounded="lg">
          <v-card-title class="d-flex align-center" style="gap:8px"><v-icon color="primary">mdi-share-variant</v-icon>Share Document</v-card-title>
          <v-card-text>
            <v-select v-model="shareForm.shared_with" :items="userOptions" item-title="label" item-value="value" label="Share with" density="compact" variant="outlined" rounded="lg" class="mb-3" />
            <v-select v-model="shareForm.permission" :items="permOptions" item-title="label" item-value="value" label="Permission" density="compact" variant="outlined" rounded="lg" class="mb-3" />
            <v-textarea v-model="shareForm.message" label="Message (optional)" variant="outlined" density="compact" rounded="lg" rows="2" hide-details />
          </v-card-text>
          <v-card-actions>
            <v-spacer />
            <v-btn variant="text" class="text-none" @click="shareDialog = false">Cancel</v-btn>
            <v-btn color="primary" variant="flat" rounded="lg" class="text-none" @click="doShare">Share</v-btn>
          </v-card-actions>
        </v-card>
      </v-dialog>

      <!-- Signature request dialog -->
      <v-dialog v-model="sigDialog" max-width="500">
        <v-card rounded="lg">
          <v-card-title class="d-flex align-center" style="gap:8px"><v-icon color="error">mdi-file-sign</v-icon>Request Signature</v-card-title>
          <v-card-text>
            <v-select v-model="sigForm.requested_from" :items="userOptions" item-title="label" item-value="value" label="Request from" density="compact" variant="outlined" rounded="lg" class="mb-3" />
            <v-textarea v-model="sigForm.message" label="Message (optional)" variant="outlined" density="compact" rounded="lg" rows="2" hide-details />
          </v-card-text>
          <v-card-actions>
            <v-spacer />
            <v-btn variant="text" class="text-none" @click="sigDialog = false">Cancel</v-btn>
            <v-btn color="error" variant="flat" rounded="lg" class="text-none" @click="reqSignature">Request</v-btn>
          </v-card-actions>
        </v-card>
      </v-dialog>
    </template>
  </v-container>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useResource } from '~/composables/useResource'
import { formatDate, formatStamp } from '~/utils/format'
import { useAuthStore } from '~/stores/auth'
import { ADMIN_ROLES } from '~/utils/permissions'

const auth = useAuthStore()
const canEdit = computed(() => [...ADMIN_ROLES, 'branch_admin'].includes(auth.role))
const { $api } = useNuxtApp()
const route = useRoute()
const docId = route.params.id

const docRes = useResource('/documents/documents/')
const loading = computed(() => docRes.loading.value)
const doc = computed(() => docRes.item.value)

const newVersionFile = ref(null)
const newVersionSummary = ref('')
const uploadingVersion = ref(false)

const newComment = ref('')
const replyTo = ref(null)
const replyBody = ref('')

const shareDialog = ref(false)
const shareForm = ref({ shared_with: null, permission: 'view', message: '' })
const sigDialog = ref(false)
const sigForm = ref({ requested_from: null, message: '' })

const userOptions = ref([])
const permOptions = [
  { label: 'View only', value: 'view' },
  { label: 'View and comment', value: 'comment' },
  { label: 'View, comment and edit', value: 'edit' },
  { label: 'View and download', value: 'download' },
]

// --- Status helpers (shared with index page) ---
function statusLabel(s) {
  const map = { draft: 'Draft', in_review: 'In Review', approved: 'Approved', published: 'Published', archived: 'Archived', expired: 'Expired' }
  return map[s] || s
}
function statusColor(s) {
  const map = { draft: 'grey', in_review: 'warning', approved: 'success', published: 'primary', archived: 'default', expired: 'error' }
  return map[s] || 'grey'
}
function priorityLabel(p) { return { low: 'Low', normal: 'Normal', high: 'High', critical: 'Critical' }[p] || p }
function priorityColor(p) { return { low: 'info', normal: 'default', high: 'warning', critical: 'error' }[p] || 'default' }

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
function fileIcon(ext) { return FILE_ICONS[ext?.toLowerCase()] || 'mdi-file-document-outline' }
function fileColor(ext) { return FILE_COLORS[ext?.toLowerCase()] || 'primary' }

function shareColor(p) { return { view: 'info', comment: 'warning', edit: 'success', download: 'primary' }[p] || 'default' }
function sigColor(s) { return { pending: 'warning', signed: 'success', rejected: 'error', expired: 'grey' }[s] || 'grey' }
function activityIcon(a) {
  const map = {
    created: 'mdi-plus-circle', viewed: 'mdi-eye', downloaded: 'mdi-download',
    version_uploaded: 'mdi-file-replace', shared: 'mdi-share-variant', commented: 'mdi-comment',
    checked_out: 'mdi-lock', checked_in: 'mdi-lock-open', restored: 'mdi-undo',
    status_changed: 'mdi-swap-horizontal', deleted: 'mdi-trash-can', restored_from_trash: 'mdi-restore',
  }
  return map[a] || 'mdi-circle-medium'
}
function activityLabel(a) { return (a || '').replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase()) }

function humanSize(bytes) {
  if (!bytes) return '—'
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`
}

async function loadDoc() {
  await docRes.get(docId)
}

async function loadUsers() {
  try {
    const { data } = await $api.get('/accounts/users/', { params: { page_size: 500 } })
    const arr = data?.results || data || []
    userOptions.value = arr.map(u => ({ label: u.name || u.email || `User #${u.id}`, value: u.id }))
  } catch (e) {
    console.error('Failed to load users', e)
  }
}

async function toggleStar() {
  try {
    await $api.post(`/documents/documents/${docId}/star/`)
    doc.value.is_starred = !doc.value.is_starred
  } catch (e) { console.error(e) }
}

async function downloadDoc() {
  try {
    const { data } = await $api.get(`/documents/documents/${docId}/download/`, { responseType: 'blob' })
    const url = URL.createObjectURL(data)
    const a = document.createElement('a')
    a.href = url
    a.download = doc.value.title || `document-${docId}`
    a.click()
    URL.revokeObjectURL(url)
  } catch (e) {
    console.error('Download failed', e)
  }
}

async function downloadVersion(v) {
  try {
    const { data } = await $api.get(`/documents/documents/${docId}/download/?version=${v.version_number}`, { responseType: 'blob' })
    const url = URL.createObjectURL(data)
    const a = document.createElement('a')
    a.href = url
    a.download = `${doc.value.title}_v${v.version_number}`
    a.click()
    URL.revokeObjectURL(url)
  } catch (e) { console.error(e) }
}

async function checkout() {
  try {
    await $api.post(`/documents/documents/${docId}/checkout/`)
    loadDoc()
  } catch (e) {
    console.error(e)
    alert('Check-out failed: ' + (e?.response?.data?.detail || e.message))
  }
}

async function checkin() {
  try {
    await $api.post(`/documents/documents/${docId}/checkin/`)
    loadDoc()
  } catch (e) {
    console.error(e)
    alert('Check-in failed: ' + (e?.response?.data?.detail || e.message))
  }
}

async function uploadVersion() {
  if (!newVersionFile.value) return
  uploadingVersion.value = true
  try {
    const form = new FormData()
    form.append('file', newVersionFile.value)
    form.append('change_summary', newVersionSummary.value)
    await $api.post(`/documents/documents/${docId}/upload_version/`, form, { headers: { 'Content-Type': 'multipart/form-data' } })
    newVersionFile.value = null
    newVersionSummary.value = ''
    loadDoc()
  } catch (e) {
    console.error(e)
    alert('Upload failed: ' + (e?.response?.data?.detail || e.message))
  } finally {
    uploadingVersion.value = false
  }
}

async function restoreVersion(v) {
  try {
    await $api.post(`/documents/documents/${docId}/restore_version/`, { version_number: v.version_number })
    loadDoc()
  } catch (e) {
    console.error(e)
    alert('Restore failed: ' + (e?.response?.data?.detail || e.message))
  }
}

async function postComment() {
  if (!newComment.value.trim()) return
  try {
    await $api.post('/documents/comments/', { document: docId, body: newComment.value })
    newComment.value = ''
    loadDoc()
  } catch (e) { console.error(e) }
}

async function postReply(parent) {
  if (!replyBody.value.trim()) return
  try {
    await $api.post('/documents/comments/', { document: docId, parent: parent.id, body: replyBody.value })
    replyTo.value = null
    replyBody.value = ''
    loadDoc()
  } catch (e) { console.error(e) }
}

async function resolveComment(c) {
  try {
    await $api.patch(`/documents/comments/${c.id}/`, { is_resolved: true })
    loadDoc()
  } catch (e) { console.error(e) }
}

async function doShare() {
  if (!shareForm.value.shared_with) return
  try {
    await $api.post('/documents/shares/', { document: docId, ...shareForm.value })
    shareDialog.value = false
    shareForm.value = { shared_with: null, permission: 'view', message: '' }
    loadDoc()
  } catch (e) {
    console.error(e)
    alert('Share failed: ' + (e?.response?.data?.detail || e.message))
  }
}

async function reqSignature() {
  if (!sigForm.value.requested_from) return
  try {
    await $api.post('/documents/signatures/', { document: docId, ...sigForm.value })
    sigDialog.value = false
    sigForm.value = { requested_from: null, message: '' }
    loadDoc()
  } catch (e) {
    console.error(e)
    alert('Signature request failed: ' + (e?.response?.data?.detail || e.message))
  }
}

async function softDelete() {
  if (!confirm('Move this document to trash?')) return
  try {
    await $api.post(`/documents/documents/${docId}/soft_delete/`)
    navigateTo('/documents')
  } catch (e) { console.error(e) }
}

onMounted(() => {
  loadDoc()
  loadUsers()
})
</script>

<style scoped>
.status-pill {
  display: inline-flex; align-items: center; gap: 4px;
  padding: 2px 10px; border-radius: 20px; font-size: 0.75rem; font-weight: 600; white-space: nowrap;
}
.text--primary { color: inherit; }
</style>
