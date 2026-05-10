<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Consents"
      subtitle="Patient consent records governing data sharing, treatment and analytics."
      eyebrow="COMPLIANCE"
      icon="mdi-file-sign"
      :chips="[
        { icon: 'mdi-check-decagram', label: `${stats.active} active` },
        { icon: 'mdi-clock-alert',    label: `${stats.expiring} expiring` },
        { icon: 'mdi-cancel',         label: `${stats.revoked} revoked` }
      ]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white"
               prepend-icon="mdi-file-sign" class="text-none" @click="openCreate">
          <span class="text-teal-darken-2 font-weight-bold">Sign new consent</span>
        </v-btn>
      </template>
    </HomecareHero>

    <v-row class="mb-1" dense>
      <v-col v-for="s in summary" :key="s.label" cols="6" md="3">
        <v-card class="hc-stat pa-4 h-100" rounded="xl" :elevation="0">
          <div class="d-flex align-center ga-3">
            <v-avatar size="44" :color="s.color" variant="tonal">
              <v-icon :icon="s.icon" />
            </v-avatar>
            <div class="flex-grow-1">
              <div class="text-h6 font-weight-bold">{{ s.value }}</div>
              <div class="text-caption text-medium-emphasis">{{ s.label }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <v-row dense>
      <v-col cols="12" lg="8">
        <HomecarePanel title="Consent register" subtitle="All scopes, all patients"
                       icon="mdi-file-document-multiple" color="#0d9488">
          <v-row dense class="mb-2">
            <v-col cols="12" md="5">
              <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                            placeholder="Search patient or grantee…" density="compact"
                            variant="outlined" hide-details rounded="lg" />
            </v-col>
            <v-col cols="12" md="3">
              <v-select v-model="filterScope" :items="scopeOptions"
                        label="Scope" density="compact" variant="outlined"
                        hide-details clearable rounded="lg" />
            </v-col>
            <v-col cols="12" md="4">
              <v-btn-toggle v-model="filterStatus" mandatory density="comfortable"
                            rounded="lg" color="teal" class="w-100">
                <v-btn value="all"      size="small">All</v-btn>
                <v-btn value="active"   size="small">Active</v-btn>
                <v-btn value="expiring" size="small">Expiring</v-btn>
                <v-btn value="revoked"  size="small">Revoked</v-btn>
              </v-btn-toggle>
            </v-col>
          </v-row>

          <v-progress-linear v-if="loading" indeterminate color="teal" class="mb-2" rounded />

          <div v-if="filtered.length">
            <v-card v-for="c in filtered" :key="c.id" class="hc-consent-card mb-2"
                    rounded="xl" :elevation="0">
              <div class="hc-consent-band" :style="{ background: scopeColor(c.scope).hex }" />
              <div class="pa-4">
                <div class="d-flex align-center ga-3">
                  <v-avatar size="44" :color="scopeColor(c.scope).vuetify" variant="tonal">
                    <v-icon :icon="scopeIcon(c.scope)" />
                  </v-avatar>
                  <div class="flex-grow-1 min-w-0">
                    <div class="d-flex align-center ga-2 flex-wrap">
                      <div class="text-subtitle-1 font-weight-bold">{{ scopeLabel(c.scope) }}</div>
                      <v-chip size="x-small" :color="statusColor(c)" variant="tonal">
                        {{ statusLabel(c) }}
                      </v-chip>
                      <v-chip v-if="c.granted_to" size="x-small" variant="text">
                        <v-icon start icon="mdi-account-arrow-right" /> {{ c.granted_to }}
                      </v-chip>
                    </div>
                    <div class="text-caption text-medium-emphasis">
                      <v-icon icon="mdi-account" size="12" /> {{ c.patient_name }}
                      <span class="mx-1">·</span>
                      <v-icon icon="mdi-calendar-check" size="12" /> Signed {{ formatDate(c.signed_at) }}
                      <span v-if="c.expires_at" class="mx-1">·</span>
                      <span v-if="c.expires_at" :class="expiryClass(c)">
                        <v-icon icon="mdi-calendar-clock" size="12" />
                        {{ expiryLabel(c) }}
                      </span>
                    </div>
                  </div>
                  <v-btn v-if="!c.revoked_at" size="small" color="error" variant="tonal"
                         rounded="lg" class="text-none" prepend-icon="mdi-cancel"
                         @click="openRevoke(c)">Revoke</v-btn>
                  <v-btn v-if="!c.revoked_at && !c.signature_hash" size="small" color="teal"
                         variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-draw"
                         @click="openSign(c)">Sign</v-btn>
                  <v-chip v-if="c.signature_hash" size="small" color="success" variant="tonal"
                          prepend-icon="mdi-shield-check">
                    e-Signed
                  </v-chip>
                  <v-btn v-if="c.signed_document_url" size="small" variant="text"
                         icon="mdi-file-download" :href="c.signed_document_url" target="_blank" />
                </div>
                <p v-if="c.notes" class="text-body-2 text-medium-emphasis mb-0 mt-2">
                  {{ c.notes }}
                </p>
              </div>
            </v-card>
          </div>
          <EmptyState v-else icon="mdi-file-sign" title="No consents"
                      message="Sign a new consent to get started." />
        </HomecarePanel>
      </v-col>

      <v-col cols="12" lg="4">
        <HomecarePanel title="By scope" icon="mdi-chart-donut" color="#7c3aed">
          <DonutRing :segments="segments" :size="180" :thickness="18">
            <div class="text-h4 font-weight-bold">{{ items.length }}</div>
            <div class="text-caption text-medium-emphasis">consents</div>
          </DonutRing>
          <v-divider class="my-3" />
          <div v-for="r in rows" :key="r.label"
               class="d-flex align-center pa-2 rounded-lg mb-1"
               :style="{ background: r.bg }">
            <v-avatar size="28" :color="r.color" variant="flat" class="mr-2">
              <v-icon :icon="r.icon" color="white" size="14" />
            </v-avatar>
            <div class="flex-grow-1">
              <div class="text-body-2 font-weight-bold">{{ r.label }}</div>
              <div class="text-caption text-medium-emphasis">{{ r.count }} consent(s)</div>
            </div>
          </div>
        </HomecarePanel>

        <HomecarePanel title="Expiring soon" icon="mdi-clock-alert" color="#f59e0b" class="mt-3">
          <v-list density="compact" class="bg-transparent pa-0">
            <v-list-item v-for="c in expiringSoon" :key="c.id" rounded="lg">
              <template #prepend>
                <v-avatar size="32" color="warning" variant="tonal">
                  <v-icon icon="mdi-clock-alert" size="14" />
                </v-avatar>
              </template>
              <v-list-item-title class="font-weight-bold">{{ c.patient_name }}</v-list-item-title>
              <v-list-item-subtitle>
                {{ scopeLabel(c.scope) }} · expires {{ formatDate(c.expires_at) }}
              </v-list-item-subtitle>
            </v-list-item>
            <EmptyState v-if="!expiringSoon.length" icon="mdi-check-decagram"
                        title="None expiring" dense />
          </v-list>
        </HomecarePanel>
      </v-col>
    </v-row>

    <!-- New consent dialog -->
    <v-dialog v-model="dialog" max-width="640" scrollable persistent>
      <v-card rounded="xl" class="overflow-hidden">
        <div class="hc-form-hero pa-4 text-white">
          <div class="d-flex align-center ga-3">
            <v-avatar size="48" color="white" variant="flat">
              <v-icon icon="mdi-file-sign" color="teal-darken-2" />
            </v-avatar>
            <div class="flex-grow-1">
              <div class="text-overline" style="opacity:.85;">SIGN</div>
              <h3 class="text-h6 ma-0">New consent</h3>
            </div>
            <v-btn icon="mdi-close" variant="text" color="white" @click="dialog = false" />
          </div>
        </div>
        <v-card-text class="pa-5">
          <v-form ref="formRef" @submit.prevent="create">
            <v-row dense>
              <v-col cols="12" md="6">
                <v-autocomplete v-model="form.patient" :items="patients"
                                item-title="name" item-value="id"
                                label="Patient *" variant="outlined" density="comfortable"
                                rounded="lg" prepend-inner-icon="mdi-account"
                                :rules="[v => !!v || 'Required']" />
              </v-col>
              <v-col cols="12" md="6">
                <v-select v-model="form.scope" :items="scopeOptions"
                          label="Scope *" variant="outlined" density="comfortable"
                          rounded="lg" prepend-inner-icon="mdi-shield-key" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.granted_to" label="Granted to"
                              variant="outlined" density="comfortable" rounded="lg"
                              prepend-inner-icon="mdi-account-arrow-right"
                              hint="Recipient party (clinic, pharmacy, insurer…)"
                              persistent-hint />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.expires_at" label="Expires at"
                              type="date" variant="outlined" density="comfortable"
                              rounded="lg" prepend-inner-icon="mdi-calendar-clock" />
              </v-col>
              <v-col cols="12">
                <v-text-field v-model="form.signed_document_url" label="Signed document URL"
                              variant="outlined" density="comfortable" rounded="lg"
                              prepend-inner-icon="mdi-link" />
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow
                            variant="outlined" density="comfortable" rounded="lg" />
              </v-col>
            </v-row>
          </v-form>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="dialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" rounded="lg" class="text-none"
                 :loading="saving" prepend-icon="mdi-check" @click="create">
            Save consent
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Revoke dialog -->
    <v-dialog v-model="revokeDialog" max-width="480">
      <v-card rounded="xl">
        <v-card-title class="text-h6">
          <v-icon icon="mdi-cancel" color="error" class="mr-1" /> Revoke consent
        </v-card-title>
        <v-card-text>
          <p v-if="target" class="text-body-2 mb-2">
            Revoke <strong>{{ scopeLabel(target.scope) }}</strong> consent for
            <strong>{{ target.patient_name }}</strong>?
          </p>
          <v-textarea v-model="revokeNotes" label="Reason" rows="3" auto-grow
                      variant="outlined" density="comfortable" rounded="lg" />
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none"
                 @click="revokeDialog = false">Cancel</v-btn>
          <v-btn color="error" variant="flat" rounded="lg" class="text-none"
                 :loading="revoking" @click="revoke">Revoke</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Signature dialog -->
    <v-dialog v-model="signDialog" max-width="640" persistent>
      <v-card rounded="xl" class="overflow-hidden">
        <div class="hc-form-hero pa-4 text-white">
          <div class="d-flex align-center ga-3">
            <v-avatar size="48" color="white" variant="flat">
              <v-icon icon="mdi-draw" color="teal-darken-2" />
            </v-avatar>
            <div class="flex-grow-1">
              <div class="text-overline" style="opacity:.85;">E-SIGNATURE</div>
              <h3 class="text-h6 ma-0">Sign consent</h3>
            </div>
            <v-btn icon="mdi-close" variant="text" color="white" @click="signDialog = false" />
          </div>
        </div>
        <v-card-text class="pa-5">
          <p v-if="signTarget" class="text-body-2 mb-3">
            <strong>{{ scopeLabel(signTarget.scope) }}</strong> consent for
            <strong>{{ signTarget.patient_name }}</strong>.
          </p>
          <v-row dense>
            <v-col cols="12" md="6">
              <v-text-field v-model="signForm.signed_by_name" label="Signer full name *"
                            variant="outlined" density="comfortable" rounded="lg"
                            prepend-inner-icon="mdi-account" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="signForm.signed_by_relationship"
                            label="Relationship to patient"
                            variant="outlined" density="comfortable" rounded="lg"
                            placeholder="Self / Parent / Guardian"
                            prepend-inner-icon="mdi-account-group" />
            </v-col>
          </v-row>
          <div class="text-caption text-medium-emphasis mb-1">
            Sign in the box below using your mouse or touch screen *
          </div>
          <div class="hc-sig-wrap" rounded="lg">
            <canvas ref="sigCanvas" class="hc-sig-canvas"
                    @pointerdown="sigDown" @pointermove="sigMove"
                    @pointerup="sigUp" @pointerleave="sigUp" />
          </div>
          <div class="d-flex mt-2">
            <v-btn size="small" variant="text" color="grey" prepend-icon="mdi-eraser"
                   class="text-none" @click="clearSig">Clear</v-btn>
            <v-spacer />
            <span class="text-caption text-medium-emphasis align-self-center">
              By signing you confirm consent under applicable laws.
            </span>
          </div>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none"
                 @click="signDialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" rounded="lg" class="text-none"
                 :loading="signing" prepend-icon="mdi-check" @click="submitSign">
            Apply signature
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2500">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()

const items = ref([])
const patients = ref([])
const loading = ref(false)
const saving = ref(false)
const revoking = ref(false)

const search = ref('')
const filterScope = ref(null)
const filterStatus = ref('all')

const dialog = ref(false)
const revokeDialog = ref(false)
const formRef = ref(null)
const target = ref(null)
const revokeNotes = ref('')
const snack = reactive({ show: false, text: '', color: 'info' })

// Signature state
const signDialog = ref(false)
const signing = ref(false)
const signTarget = ref(null)
const sigCanvas = ref(null)
const signForm = reactive({ signed_by_name: '', signed_by_relationship: '' })
let sigCtx = null
let sigDrawing = false
let sigHasInk = false

const scopeOptions = [
  { value: 'records',        title: 'Medical records' },
  { value: 'medication',     title: 'Medication administration' },
  { value: 'insurance',      title: 'Insurance billing' },
  { value: 'teleconsult',    title: 'Teleconsult recording' },
  { value: 'data_analytics', title: 'Data analytics' }
]

const blank = () => ({
  patient: null, scope: 'records', granted_to: '',
  expires_at: '', signed_document_url: '', notes: ''
})
const form = reactive(blank())

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/consents/', { params: { page_size: 200 } })
    items.value = data?.results || data || []
  } catch {
    snack.text = 'Failed to load consents'; snack.color = 'error'; snack.show = true
  } finally { loading.value = false }
}
async function loadPatients() {
  try {
    const { data } = await $api.get('/homecare/patients/', { params: { page_size: 200 } })
    const list = data?.results || data || []
    patients.value = list.map(p => ({
      id: p.id,
      name: `${p.user?.full_name || 'Patient'}${p.medical_record_number ? ' · ' + p.medical_record_number : ''}`
    }))
  } catch { /* ignore */ }
}
onMounted(() => { load(); loadPatients() })

function isExpiringSoon(c) {
  if (!c.expires_at || c.revoked_at) return false
  const days = (new Date(c.expires_at).getTime() - Date.now()) / 86400000
  return days >= 0 && days <= 30
}

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  return items.value.filter(c => {
    if (filterScope.value && c.scope !== filterScope.value) return false
    if (filterStatus.value === 'active' && c.revoked_at) return false
    if (filterStatus.value === 'revoked' && !c.revoked_at) return false
    if (filterStatus.value === 'expiring' && !isExpiringSoon(c)) return false
    if (!q) return true
    return [c.patient_name, c.granted_to].filter(Boolean)
      .some(s => s.toLowerCase().includes(q))
  })
})

const stats = computed(() => {
  const list = items.value
  return {
    active: list.filter(c => !c.revoked_at).length,
    revoked: list.filter(c => c.revoked_at).length,
    expiring: list.filter(isExpiringSoon).length,
    total: list.length
  }
})
const summary = computed(() => [
  { label: 'Total',    value: stats.value.total,    color: 'teal',    icon: 'mdi-file-sign' },
  { label: 'Active',   value: stats.value.active,   color: 'success', icon: 'mdi-check-decagram' },
  { label: 'Expiring', value: stats.value.expiring, color: 'warning', icon: 'mdi-clock-alert' },
  { label: 'Revoked',  value: stats.value.revoked,  color: 'error',   icon: 'mdi-cancel' }
])

const rows = computed(() => scopeOptions.map(o => ({
  label: o.title, count: items.value.filter(c => c.scope === o.value).length,
  color: scopeColor(o.value).hex, bg: `${scopeColor(o.value).hex}14`,
  icon: scopeIcon(o.value)
})))
const segments = computed(() => scopeOptions.map(o => ({
  label: o.title, value: items.value.filter(c => c.scope === o.value).length,
  color: scopeColor(o.value).vuetify
})))
const expiringSoon = computed(() => items.value.filter(isExpiringSoon).slice(0, 5))

function scopeLabel(s) {
  return scopeOptions.find(o => o.value === s)?.title || s
}
function scopeColor(s) {
  return ({
    records:        { hex: '#0d9488', vuetify: 'teal' },
    medication:     { hex: '#7c3aed', vuetify: 'purple' },
    insurance:      { hex: '#0284c7', vuetify: 'info' },
    teleconsult:    { hex: '#10b981', vuetify: 'success' },
    data_analytics: { hex: '#f59e0b', vuetify: 'warning' }
  })[s] || { hex: '#64748b', vuetify: 'grey' }
}
function scopeIcon(s) {
  return ({
    records: 'mdi-file-document', medication: 'mdi-pill',
    insurance: 'mdi-shield', teleconsult: 'mdi-video',
    data_analytics: 'mdi-chart-line'
  })[s] || 'mdi-file-sign'
}
function statusColor(c) {
  if (c.revoked_at) return 'error'
  if (isExpiringSoon(c)) return 'warning'
  return 'success'
}
function statusLabel(c) {
  if (c.revoked_at) return 'revoked'
  if (isExpiringSoon(c)) return 'expiring'
  return 'active'
}
function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString(undefined, { day: '2-digit', month: 'short', year: 'numeric' })
}
function expiryClass(c) {
  if (!c.expires_at) return ''
  const days = (new Date(c.expires_at).getTime() - Date.now()) / 86400000
  if (days < 0) return 'text-error'
  if (days <= 30) return 'text-warning'
  return ''
}
function expiryLabel(c) {
  if (!c.expires_at) return ''
  const days = Math.round((new Date(c.expires_at).getTime() - Date.now()) / 86400000)
  if (days < 0) return `Expired ${-days}d ago`
  if (days === 0) return 'Expires today'
  return `Expires in ${days}d`
}

function openCreate() { Object.assign(form, blank()); dialog.value = true }
async function create() {
  if (!form.patient) {
    snack.text = 'Patient required'; snack.color = 'warning'; snack.show = true; return
  }
  saving.value = true
  try {
    const { data } = await $api.post('/homecare/consents/', form)
    items.value.unshift(data)
    dialog.value = false
    snack.text = 'Consent recorded'; snack.color = 'success'; snack.show = true
  } catch (e) {
    snack.text = e?.response?.data ? JSON.stringify(e.response.data).slice(0, 200) : 'Save failed'
    snack.color = 'error'; snack.show = true
  } finally { saving.value = false }
}

function openRevoke(c) { target.value = c; revokeNotes.value = ''; revokeDialog.value = true }
async function revoke() {
  if (!target.value) return
  revoking.value = true
  try {
    const { data } = await $api.post(
      `/homecare/consents/${target.value.id}/revoke/`, { reason: revokeNotes.value })
    const i = items.value.findIndex(x => x.id === target.value.id)
    if (i >= 0) items.value.splice(i, 1, data)
    revokeDialog.value = false
    snack.text = 'Consent revoked'; snack.color = 'warning'; snack.show = true
  } catch {
    snack.text = 'Revoke failed'; snack.color = 'error'; snack.show = true
  } finally { revoking.value = false }
}

// ===== E-signature =====
function openSign(c) {
  signTarget.value = c
  signForm.signed_by_name = c.patient_name || ''
  signForm.signed_by_relationship = 'Self'
  sigHasInk = false
  signDialog.value = true
  nextTick(() => initSig())
}
function initSig() {
  const cv = sigCanvas.value
  if (!cv) return
  const rect = cv.getBoundingClientRect()
  const dpr = window.devicePixelRatio || 1
  cv.width = Math.max(1, Math.floor(rect.width * dpr))
  cv.height = Math.max(1, Math.floor(180 * dpr))
  cv.style.height = '180px'
  sigCtx = cv.getContext('2d')
  sigCtx.scale(dpr, dpr)
  sigCtx.lineWidth = 2
  sigCtx.lineCap = 'round'
  sigCtx.lineJoin = 'round'
  sigCtx.strokeStyle = '#0f172a'
  clearSig()
}
function sigPos(e) {
  const r = sigCanvas.value.getBoundingClientRect()
  return { x: e.clientX - r.left, y: e.clientY - r.top }
}
function sigDown(e) {
  if (!sigCtx) return
  sigDrawing = true
  sigCanvas.value.setPointerCapture?.(e.pointerId)
  const p = sigPos(e)
  sigCtx.beginPath(); sigCtx.moveTo(p.x, p.y)
}
function sigMove(e) {
  if (!sigDrawing || !sigCtx) return
  const p = sigPos(e)
  sigCtx.lineTo(p.x, p.y); sigCtx.stroke()
  sigHasInk = true
}
function sigUp() { sigDrawing = false }
function clearSig() {
  if (!sigCtx || !sigCanvas.value) return
  const cv = sigCanvas.value
  sigCtx.save()
  sigCtx.setTransform(1, 0, 0, 1, 0, 0)
  sigCtx.fillStyle = '#ffffff'
  sigCtx.fillRect(0, 0, cv.width, cv.height)
  sigCtx.restore()
  sigHasInk = false
}
async function submitSign() {
  if (!signTarget.value) return
  if (!signForm.signed_by_name.trim()) {
    snack.text = 'Signer name required'; snack.color = 'warning'; snack.show = true; return
  }
  if (!sigHasInk) {
    snack.text = 'Please sign in the box'; snack.color = 'warning'; snack.show = true; return
  }
  signing.value = true
  try {
    const dataUrl = sigCanvas.value.toDataURL('image/png')
    const { data } = await $api.post(
      `/homecare/consents/${signTarget.value.id}/sign/`,
      {
        signature_data_url: dataUrl,
        signed_by_name: signForm.signed_by_name.trim(),
        signed_by_relationship: signForm.signed_by_relationship.trim()
      }
    )
    const i = items.value.findIndex(x => x.id === signTarget.value.id)
    if (i >= 0) items.value.splice(i, 1, data)
    signDialog.value = false
    snack.text = 'Consent signed'; snack.color = 'success'; snack.show = true
  } catch (e) {
    snack.text = e?.response?.data ? JSON.stringify(e.response.data).slice(0, 200) : 'Signature failed'
    snack.color = 'error'; snack.show = true
  } finally { signing.value = false }
}
</script>

<style scoped>
.hc-bg {
  background: linear-gradient(135deg, rgba(13,148,136,0.06) 0%, rgba(124,58,237,0.04) 100%);
  min-height: calc(100vh - 64px);
}
.hc-stat {
  background: rgba(255,255,255,0.85);
  backdrop-filter: blur(8px);
  border: 1px solid rgba(15,23,42,0.05);
}
.hc-consent-card {
  position: relative;
  background: white;
  border: 1px solid rgba(15,23,42,0.05);
  overflow: hidden;
}
.hc-consent-band { position: absolute; left: 0; top: 0; bottom: 0; width: 4px; }
.hc-form-hero { background: linear-gradient(135deg,#0d9488 0%,#0f766e 100%); }
.hc-sig-wrap {
  border: 2px dashed rgba(13,148,136,0.45);
  border-radius: 12px;
  background:
    linear-gradient(rgba(13,148,136,0.04), rgba(13,148,136,0.04)),
    repeating-linear-gradient(0deg, transparent 0 28px, rgba(15,23,42,0.06) 28px 29px);
  width: 100%;
  overflow: hidden;
}
.hc-sig-canvas {
  display: block;
  width: 100%;
  height: 180px;
  touch-action: none;
  cursor: crosshair;
}
:global(.v-theme--dark) .hc-stat,
:global(.v-theme--dark) .hc-consent-card { background: rgba(30,41,59,0.7); border-color: rgba(255,255,255,0.06); }
</style>
