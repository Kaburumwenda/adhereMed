<template>
  <div class="ohs-page">
    <OhsHero
      icon="mdi-file-document-multiple-outline"
      eyebrow="OHSMS · Clause 7.5 documented information"
      title="Document Control & SDS Library"
      subtitle="Controlled policies, procedures, work instructions and safety data sheets with version history, review cycles and workforce acknowledgement."
    >
      <template #actions>
        <v-btn class="ohs-btn-glass text-none" rounded="lg" size="small" prepend-icon="mdi-download"
               @click="exportData">Export</v-btn>
        <v-btn class="ohs-btn-strong text-none" rounded="lg" size="small" prepend-icon="mdi-plus"
               @click="openCreate">New document</v-btn>
      </template>
      <span class="ohs-chip"><v-icon size="12">mdi-file-document-multiple</v-icon>
        <b>{{ docs.count.value }}</b> controlled</span>
      <span class="ohs-chip"><v-icon size="12">mdi-flask-outline</v-icon>
        <b>{{ stats.sds }}</b> safety data sheets</span>
      <span v-if="stats.reviewDue" class="ohs-chip ohs-chip-warn">
        <v-icon size="12">mdi-calendar-alert</v-icon>
        <b>{{ stats.reviewDue }}</b> reviews overdue</span>
      <span v-if="stats.pendingAck" class="ohs-chip ohs-chip-warn">
        <v-icon size="12">mdi-account-clock</v-icon>
        <b>{{ stats.pendingAck }}</b> awaiting acknowledgement</span>
    </OhsHero>

    <div class="ohs-kpi-grid mb-3">
      <OhsKpi label="Controlled documents" :value="docs.count.value" icon="mdi-file-document-multiple-outline"
              tone="primary" :sub="`${stats.approved} approved`" />
      <OhsKpi label="SDS library" :value="stats.sds" icon="mdi-flask-outline" tone="info"
              sub="chemical safety data" />
      <OhsKpi label="Review overdue" :value="stats.reviewDue" icon="mdi-calendar-alert"
              :tone="stats.reviewDue ? 'err' : 'ok'" sub="past review date" />
      <OhsKpi label="Due in 60 days" :value="stats.dueSoon" icon="mdi-calendar-clock" tone="warn"
              sub="upcoming reviews" />
      <OhsKpi label="Acknowledgements" :value="stats.acks" icon="mdi-account-check-outline" tone="ok"
              sub="signed off by workers" />
    </div>

    <v-tabs v-model="tab" color="primary" density="compact" class="mb-3">
      <v-tab value="all" class="text-none">
        <v-icon start size="16">mdi-file-document-multiple</v-icon> All documents
      </v-tab>
      <v-tab value="sds" class="text-none">
        <v-icon start size="16">mdi-flask-outline</v-icon> SDS library
      </v-tab>
      <v-tab value="reviews" class="text-none">
        <v-icon start size="16">mdi-calendar-clock</v-icon> Review schedule
      </v-tab>
    </v-tabs>

    <OhsPanel :title="panelTitle" :subtitle="`${filtered.length} shown`"
              icon="mdi-file-document-multiple-outline" flush>
      <div class="ohs-toolbar">
        <v-text-field v-model="search" placeholder="Search reference, title, chemical…"
                      prepend-inner-icon="mdi-magnify" density="compact" variant="outlined" rounded="lg"
                      hide-details single-line clearable style="max-width:270px" />
        <v-select v-model="typeFilter" :items="typeOptions" item-title="label" item-value="value"
                  placeholder="All types" density="compact" variant="outlined" rounded="lg"
                  hide-details clearable style="max-width:185px" />
        <v-select v-model="statusFilter" :items="statusOptions" item-title="label" item-value="value"
                  placeholder="Any status" density="compact" variant="outlined" rounded="lg"
                  hide-details clearable style="max-width:165px" />
        <v-select v-model="siteFilter" :items="siteOptions" item-title="label" item-value="value"
                  placeholder="All sites" density="compact" variant="outlined" rounded="lg"
                  hide-details clearable style="max-width:180px" />
        <v-spacer />
        <v-checkbox v-model="onlyAck" density="compact" hide-details label="Needs acknowledgement"
                    color="warning" />
      </div>

      <v-progress-linear v-if="docs.loading.value" indeterminate color="primary" height="2" />

      <div class="ohs-scroll" style="max-height:62vh">
        <table class="ohs-table">
          <thead>
            <tr>
              <th style="width:112px">Ref</th>
              <th>Document</th>
              <th style="width:130px">Type</th>
              <th style="width:70px">Version</th>
              <th style="width:105px">Status</th>
              <th style="width:112px">Effective</th>
              <th style="width:130px">Next review</th>
              <th style="width:100px" class="num">Acks</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="d in filtered" :key="d.id" @click="openDetail(d)">
              <td class="ohs-mono">{{ d.reference }}</td>
              <td>
                <div class="font-weight-medium text-truncate" style="max-width:340px">{{ d.title }}</div>
                <div class="text-caption text-medium-emphasis">
                  {{ d.owner_name || 'Unowned' }}
                  <span v-if="d.chemical_name"> · {{ d.chemical_name }}</span>
                  <span v-if="d.site_name"> · {{ d.site_name }}</span>
                </div>
              </td>
              <td class="text-caption">{{ d.doc_type_display }}</td>
              <td class="text-caption ohs-mono">v{{ d.version }}</td>
              <td>
                <span class="ohs-badge" :class="`ohs-badge--${toneFor(d.status)}`">{{ d.status_display }}</span>
              </td>
              <td class="text-caption">{{ formatDate(d.effective_date) }}</td>
              <td>
                <span class="text-caption">{{ formatDate(d.review_due) }}</span>
                <span v-if="d.is_review_overdue" class="ohs-badge ohs-badge--err ml-1">late</span>
                <span v-else-if="d.days_to_review !== null && d.days_to_review <= 60"
                      class="ohs-badge ohs-badge--warn ml-1">{{ d.days_to_review }}d</span>
              </td>
              <td class="num">
                <span v-if="d.requires_acknowledgement" class="text-caption font-weight-bold">
                  {{ d.acknowledged_count }}
                </span>
                <span v-else class="text-caption text-medium-emphasis">—</span>
              </td>
            </tr>
          </tbody>
        </table>
        <div v-if="!filtered.length && !docs.loading.value" class="ohs-empty">
          No documents match these filters.
        </div>
      </div>
    </OhsPanel>

    <!-- ═════ DETAIL DRAWER ═════ -->
    <v-navigation-drawer v-model="drawer" temporary location="right" width="600">
      <div v-if="detail" class="d-flex flex-column h-100">
        <div class="drawer-head">
          <div class="d-flex align-center justify-space-between" style="gap:10px">
            <div>
              <div class="ohs-mono text-caption" style="color:rgba(255,255,255,.8)">
                {{ detail.reference }} · v{{ detail.version }}
              </div>
              <div class="text-h6 font-weight-bold" style="line-height:1.25">{{ detail.title }}</div>
            </div>
            <v-btn icon="mdi-close" variant="text" size="small" style="color:#fff" @click="drawer = false" />
          </div>
          <div class="d-flex flex-wrap mt-2" style="gap:6px">
            <span class="glass-chip">{{ detail.doc_type_display }}</span>
            <span class="glass-chip">{{ detail.status_display }}</span>
            <span class="glass-chip">{{ detail.classification_display }}</span>
            <span v-if="detail.requires_acknowledgement" class="ohs-badge ohs-badge--warn">
              Acknowledgement required
            </span>
          </div>
        </div>

        <div class="pa-4 flex-grow-1" style="overflow:auto">
          <v-row dense>
            <v-col cols="6"><div class="meta"><span>Owner</span><b>{{ detail.owner_name || '—' }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Site</span><b>{{ detail.site_name || 'All sites' }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Effective</span><b>{{ formatDate(detail.effective_date) }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Review due</span><b>{{ formatDate(detail.review_due) }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Approved by</span><b>{{ detail.approved_by || '—' }}</b></div></v-col>
            <v-col cols="6"><div class="meta"><span>Revisions</span><b>{{ detail.revision_count || 1 }}</b></div></v-col>
            <v-col v-if="detail.chemical_name" cols="6">
              <div class="meta"><span>Chemical</span><b>{{ detail.chemical_name }}</b></div>
            </v-col>
            <v-col v-if="detail.hazard_class" cols="6">
              <div class="meta"><span>Hazard class</span><b>{{ detail.hazard_class }}</b></div>
            </v-col>
          </v-row>

          <div v-if="detail.summary" class="text-body-2 mt-2">{{ detail.summary }}</div>
          <div v-if="detail.tags" class="d-flex flex-wrap mt-2" style="gap:4px">
            <span v-for="t in detail.tags.split(',')" :key="t" class="ohs-badge ohs-badge--muted">
              {{ t.trim() }}
            </span>
          </div>

          <div class="d-flex align-center justify-space-between mt-4 mb-2">
            <span class="section-title" style="margin:0">Revision history</span>
            <v-btn size="x-small" variant="tonal" color="primary" rounded="lg" class="text-none"
                   prepend-icon="mdi-plus" @click="revisionDialog = true">New version</v-btn>
          </div>
          <div class="timeline">
            <div v-for="r in detail.revisions" :key="r.id" class="tl-item">
              <div class="tl-dot" />
              <div class="flex-grow-1">
                <div class="d-flex align-center justify-space-between">
                  <span class="text-body-2 font-weight-bold">v{{ r.version }}</span>
                  <span class="text-caption text-medium-emphasis">{{ formatDate(r.revised_on) }}</span>
                </div>
                <div class="text-caption">{{ r.change_summary || 'No change note.' }}</div>
                <div class="text-caption text-medium-emphasis">
                  Revised by {{ r.revised_by || '—' }}
                  <span v-if="r.approved_by"> · approved by {{ r.approved_by }}</span>
                </div>
              </div>
            </div>
            <div v-if="!detail.revisions?.length" class="text-caption text-medium-emphasis">
              No revisions recorded.
            </div>
          </div>

          <template v-if="detail.requires_acknowledgement">
            <div class="d-flex align-center justify-space-between mt-4 mb-2">
              <span class="section-title" style="margin:0">Acknowledgements</span>
              <v-btn size="x-small" variant="tonal" color="success" rounded="lg" class="text-none"
                     prepend-icon="mdi-account-check" @click="ackDialog = true">Record acknowledgement</v-btn>
            </div>
            <div class="ack-summary">
              <div class="ack-count">{{ detail.acknowledged_count }}</div>
              <div class="text-caption text-medium-emphasis">workers have signed this version</div>
            </div>
          </template>
        </div>

        <div class="drawer-actions">
          <v-btn v-if="detail.status !== 'approved'" variant="tonal" color="success" rounded="lg"
                 class="text-none" @click="approve">Approve</v-btn>
          <v-spacer />
          <v-btn variant="text" class="text-none" prepend-icon="mdi-download"
                 :href="detail.file_url || undefined" target="_blank" :disabled="!detail.file_url">
            Download
          </v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" @click="drawer = false">Done</v-btn>
        </div>
      </div>
    </v-navigation-drawer>

    <!-- ═════ CREATE DOCUMENT ═════ -->
    <v-dialog v-model="createDialog" max-width="720" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-file-document-plus-outline" title="New controlled document"
                           subtitle="Every revision is version-tracked with a review date." />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" sm="8">
              <v-text-field v-model="form.title" label="Document title" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model="form.version" label="Version" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.doc_type" :items="typeOptions" item-title="label" item-value="value"
                        label="Document type" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.site" :items="siteOptions" item-title="label" item-value="value"
                        label="Site (blank = all)" variant="outlined" density="compact" rounded="lg" clearable />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.owner_name" label="Document owner" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.classification" :items="classificationOptions" item-title="label"
                        item-value="value" label="Classification" variant="outlined"
                        density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.effective_date" type="date" label="Effective date"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.review_due" type="date" label="Review due"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.summary" label="Summary" rows="2" variant="outlined"
                          density="compact" rounded="lg" />
            </v-col>
            <v-col v-if="form.doc_type === 'sds'" cols="12" sm="6">
              <v-text-field v-model="form.chemical_name" label="Chemical name" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col v-if="form.doc_type === 'sds'" cols="12" sm="6">
              <v-text-field v-model="form.hazard_class" label="Hazard class" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-checkbox v-model="form.requires_acknowledgement" density="compact" hide-details
                          label="Workers must acknowledge this document" />
            </v-col>
          </v-row>
          <v-alert v-if="error" type="error" variant="tonal" density="compact" rounded="lg" class="mt-3">
            {{ error }}
          </v-alert>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="createDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="docs.saving.value"
                 :disabled="!form.title" @click="save">Create</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═════ NEW REVISION ═════ -->
    <v-dialog v-model="revisionDialog" max-width="520">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-file-document-refresh-outline" title="Publish a new revision"
                           subtitle="The change note is kept permanently in the audit trail." />
        <v-card-text>
          <v-text-field v-model="revisionForm.version" label="New version" variant="outlined"
                        density="compact" rounded="lg" class="mb-2" />
          <v-textarea v-model="revisionForm.change_summary" label="What changed" rows="2"
                      variant="outlined" density="compact" rounded="lg" class="mb-2" />
          <v-text-field v-model="revisionForm.revised_by" label="Revised by" variant="outlined"
                        density="compact" rounded="lg" />
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="revisionDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="savingRevision"
                 :disabled="!revisionForm.version" @click="saveRevision">Publish</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═════ ACKNOWLEDGE ═════ -->
    <v-dialog v-model="ackDialog" max-width="500">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-account-check" title="Record acknowledgement"
                           subtitle="Confirms the worker has read and understood this version." />
        <v-card-text>
          <v-text-field v-model="ackForm.employee_name" label="Employee name" variant="outlined"
                        density="compact" rounded="lg" class="mb-2" />
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-text-field v-model="ackForm.employee_ref" label="Employee ref" variant="outlined"
                            density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="ackForm.acknowledged_on" type="date" label="Date"
                            variant="outlined" density="compact" rounded="lg" />
            </v-col>
          </v-row>
        </v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="ackDialog = false">Cancel</v-btn>
          <v-btn color="success" rounded="lg" class="text-none" :loading="savingAck"
                 :disabled="!ackForm.employee_name" @click="saveAck">Record</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="bottom right" timeout="2600">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
import { toneFor } from '~/composables/useOhs'

definePageMeta({ layout: 'default' })
useHead({ title: 'Document Control · OHSMS' })

const ohs = useOhs()
const { $api } = useNuxtApp()
const route = useRoute()

const docs = ohs.resource('documents')
const lookups = ref({})
const tab = ref(['all', 'sds', 'reviews'].includes(route.query.tab)
  ? String(route.query.tab) : 'all')
const search = ref('')
const typeFilter = ref(null)
const statusFilter = ref(null)
const siteFilter = ref(null)
const onlyAck = ref(false)

const drawer = ref(false)
const detail = ref(null)
const createDialog = ref(false)
const revisionDialog = ref(false)
const ackDialog = ref(false)
const savingRevision = ref(false)
const savingAck = ref(false)
const error = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const form = reactive({
  title: '', doc_type: 'procedure', site: null, owner_name: '', version: '1.0',
  classification: 'internal', summary: '', effective_date: new Date().toISOString().slice(0, 10),
  review_due: '', chemical_name: '', hazard_class: '', requires_acknowledgement: false,
})
const revisionForm = reactive({ version: '', change_summary: '', revised_by: '' })
const ackForm = reactive({
  employee_name: '', employee_ref: '', acknowledged_on: new Date().toISOString().slice(0, 10),
})

const siteOptions = computed(() => (lookups.value.sites || []).map((s) => ({ label: s.name, value: s.id })))
const typeOptions = computed(() => lookups.value.doc_types || [])
const statusOptions = computed(() => lookups.value.doc_status || [])
const classificationOptions = computed(() => lookups.value.classifications || [])

const panelTitle = computed(() => ({
  all: 'All controlled documents',
  sds: 'Safety data sheet library',
  reviews: 'Review schedule',
}[tab.value] || 'Documents'))

const rows = computed(() => docs.items.value || [])

const filtered = computed(() => {
  const today = new Date().toISOString().slice(0, 10)
  return rows.value.filter((d) => {
    if (tab.value === 'sds' && d.doc_type !== 'sds') return false
    if (tab.value === 'reviews' && !(d.review_due && d.review_due <= today)) return false
    if (typeFilter.value && d.doc_type !== typeFilter.value) return false
    if (statusFilter.value && d.status !== statusFilter.value) return false
    if (siteFilter.value && d.site !== siteFilter.value) return false
    if (onlyAck.value && !d.requires_acknowledgement) return false
    const q = search.value.trim().toLowerCase()
    if (q) {
      const hay = `${d.reference} ${d.title} ${d.owner_name} ${d.chemical_name} ${d.hazard_class} ${d.tags}`.toLowerCase()
      if (!hay.includes(q)) return false
    }
    return true
  })
})

const stats = computed(() => {
  const all = rows.value
  const soon = new Date(Date.now() + 60 * 86400000).toISOString().slice(0, 10)
  return {
    sds: all.filter((d) => d.doc_type === 'sds').length,
    approved: all.filter((d) => d.status === 'approved').length,
    reviewDue: all.filter((d) => d.is_review_overdue).length,
    dueSoon: all.filter((d) => d.days_to_review !== null && d.days_to_review >= 0
      && d.review_due <= soon).length,
    acks: all.reduce((s, d) => s + (d.acknowledged_count || 0), 0),
    pendingAck: all.filter((d) => d.requires_acknowledgement && d.status === 'approved').length,
  }
})

async function load() {
  await docs.list({ ordering: '-updated_at' })
  lookups.value = await ohs.loadLookups()
}

async function openDetail(d) {
  drawer.value = true
  detail.value = d
  try {
    const { data } = await $api.get(`/ohs/documents/${d.id}/`)
    detail.value = data
  } catch { /* keep list payload */ }
}

function openCreate() {
  error.value = ''
  Object.assign(form, {
    title: '', doc_type: 'procedure', site: null, owner_name: '', version: '1.0',
    classification: 'internal', summary: '',
    effective_date: new Date().toISOString().slice(0, 10), review_due: '',
    chemical_name: '', hazard_class: '', requires_acknowledgement: false,
  })
  createDialog.value = true
}

async function save() {
  error.value = ''
  try {
    const payload = { ...form }
    if (!payload.site) delete payload.site
    if (!payload.review_due) delete payload.review_due
    await docs.create(payload)
    createDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Document created.' }
    await load()
  } catch (e) {
    error.value = docs.message(e)
  }
}

async function approve() {
  if (!detail.value) return
  try {
    const { data } = await $api.post(`/ohs/documents/${detail.value.id}/approve/`)
    detail.value = data
    snack.value = { show: true, color: 'success', text: 'Document approved.' }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: docs.message(e) }
  }
}

async function saveRevision() {
  if (!detail.value) return
  savingRevision.value = true
  try {
    const { data } = await $api.post(`/ohs/documents/${detail.value.id}/add_revision/`, {
      ...revisionForm,
    })
    detail.value = data
    revisionDialog.value = false
    Object.assign(revisionForm, { version: '', change_summary: '', revised_by: '' })
    snack.value = { show: true, color: 'success', text: 'Revision published.' }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: docs.message(e) }
  } finally {
    savingRevision.value = false
  }
}

async function saveAck() {
  if (!detail.value) return
  savingAck.value = true
  try {
    await $api.post(`/ohs/documents/${detail.value.id}/acknowledge/`, { ...ackForm })
    ackDialog.value = false
    Object.assign(ackForm, {
      employee_name: '', employee_ref: '',
      acknowledged_on: new Date().toISOString().slice(0, 10),
    })
    snack.value = { show: true, color: 'success', text: 'Acknowledgement recorded.' }
    await openDetail(detail.value)
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: docs.message(e) }
  } finally {
    savingAck.value = false
  }
}

function exportData() {
  exportCsv(`document_register_${new Date().toISOString().slice(0, 10)}.csv`, filtered.value, [
    { key: 'reference', label: 'Reference' },
    { key: 'title', label: 'Document' },
    { key: 'doc_type_display', label: 'Type' },
    { key: 'version', label: 'Version' },
    { key: 'status_display', label: 'Status' },
    { key: 'owner_name', label: 'Owner' },
    { key: 'site_name', label: 'Site' },
    { key: 'effective_date', label: 'Effective' },
    { key: 'review_due', label: 'Review due' },
    { key: 'requires_acknowledgement', label: 'Needs ack' },
    { key: 'acknowledged_count', label: 'Acknowledgements' },
    { key: 'chemical_name', label: 'Chemical' },
  ])
}

watch([tab, typeFilter, statusFilter, siteFilter, onlyAck], load)
onMounted(load)
</script>

<style scoped>
.drawer-head { padding: 16px; color: #fff; background: var(--brand-gradient); }
.glass-chip {
  display: inline-flex; align-items: center; padding: 2px 9px; border-radius: 999px;
  font-size: 10.5px; font-weight: 700; text-transform: uppercase; letter-spacing: .3px;
  background: rgba(255, 255, 255, 0.16); border: 1px solid rgba(255, 255, 255, 0.3); color: #fff;
}
.meta { display: flex; flex-direction: column; gap: 1px; }
.meta span { font-size: 10.5px; font-weight: 700; letter-spacing: .4px; text-transform: uppercase; color: rgba(var(--v-theme-on-surface), .5); }
.meta b { font-size: 12.5px; font-weight: 600; }
.section-title {
  font-size: 11px; font-weight: 800; letter-spacing: .6px; text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), .55); margin: 16px 0 8px;
}
.timeline { position: relative; padding-left: 16px; }
.timeline::before {
  content: ''; position: absolute; left: 4px; top: 4px; bottom: 4px; width: 2px;
  background: rgba(var(--v-theme-on-surface), .1);
}
.tl-item { display: flex; gap: 10px; padding-bottom: 12px; position: relative; }
.tl-dot {
  position: absolute; left: -16px; top: 4px;
  width: 9px; height: 9px; border-radius: 50%;
  background: var(--brand-primary); border: 2px solid rgb(var(--v-theme-surface));
}
.ack-summary {
  display: flex; align-items: baseline; gap: 8px;
  padding: 10px 12px; border-radius: 10px;
  background: rgba(34, 197, 94, .08); border: 1px solid rgba(34, 197, 94, .2);
}
.ack-count { font-size: 22px; font-weight: 800; color: #15803d; }
.drawer-actions {
  display: flex; align-items: center; gap: 8px;
  padding: 10px 16px; border-top: 1px solid rgba(15, 23, 42, 0.08);
}
</style>
