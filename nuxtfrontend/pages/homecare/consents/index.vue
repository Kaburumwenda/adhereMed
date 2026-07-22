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
                  <v-btn size="small" color="teal-darken-2" variant="text"
                         rounded="lg" class="text-none" prepend-icon="mdi-eye"
                         @click="openView(c)">View</v-btn>
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
                <v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow
                            variant="outlined" density="comfortable" rounded="lg" />
              </v-col>

              <v-col cols="12">
                <v-divider class="mb-2" />
                <div class="d-flex align-center ga-2 mb-1">
                  <v-icon icon="mdi-draw" color="teal-darken-2" size="18" />
                  <span class="text-subtitle-2 font-weight-bold">Digital signature *</span>
                  <v-chip size="x-small" variant="tonal" color="error">required</v-chip>
                </div>
                <div class="text-caption text-medium-emphasis mb-2">
                  Capture the patient / guardian signature to e-sign this consent.
                  A signature is required to record the consent.
                </div>
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.signed_by_name" label="Signer full name *"
                              variant="outlined" density="comfortable" rounded="lg"
                              prepend-inner-icon="mdi-account"
                              :rules="[v => !!(v && v.trim()) || 'Required']" />
              </v-col>
              <v-col cols="12" md="6">
                <v-select v-model="form.signed_by_relationship"
                          :items="relationshipOptions"
                          label="Relationship to patient *"
                          variant="outlined" density="comfortable" rounded="lg"
                          prepend-inner-icon="mdi-account-group"
                          :rules="[v => !!v || 'Required']" />
              </v-col>
              <v-col cols="12">
                <div class="hc-sig-wrap" rounded="lg">
                  <canvas ref="createSigCanvas" class="hc-sig-canvas"
                          @pointerdown="createSigDown" @pointermove="createSigMove"
                          @pointerup="createSigUp" @pointerleave="createSigUp" />
                </div>
                <div class="d-flex mt-2">
                  <v-btn size="small" variant="text" color="grey" prepend-icon="mdi-eraser"
                         class="text-none" @click="clearCreateSig">Clear</v-btn>
                  <v-spacer />
                  <span class="text-caption text-medium-emphasis align-self-center">
                    By signing you confirm consent under applicable laws.
                  </span>
                </div>
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
              <v-select v-model="signForm.signed_by_relationship"
                        :items="relationshipOptions"
                        label="Relationship to patient *"
                        variant="outlined" density="comfortable" rounded="lg"
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

    <!-- View consent dialog -->
    <v-dialog v-model="viewDialog" max-width="820" scrollable>
      <v-card rounded="xl" class="overflow-hidden">
        <div class="d-flex align-center pa-3 hc-view-topbar">
          <v-icon icon="mdi-file-document-check" color="teal-darken-2" class="mr-2" />
          <span class="text-subtitle-1 font-weight-bold">Consent document</span>
          <v-spacer />
          <v-btn color="teal" variant="flat" rounded="lg" class="text-none mr-1"
                 :loading="pdfLoading" prepend-icon="mdi-file-pdf-box" @click="downloadPdf">
            Download PDF
          </v-btn>
          <v-btn icon="mdi-close" variant="text" @click="viewDialog = false" />
        </div>
        <v-divider />
        <v-card-text class="pa-5 hc-doc-scroll">
          <div v-if="viewTarget" ref="docRef" class="hc-doc">
            <!-- Letterhead -->
            <div class="hc-doc-head">
              <div class="hc-doc-party">
                <img :src="tenantLogoSrc" class="hc-doc-logo" alt="tenant logo" crossorigin="anonymous" />
                <div>
                  <div class="hc-doc-party-name">{{ tenant.name }}</div>
                  <div class="hc-doc-party-meta">{{ tenant.email }}</div>
                  <div v-if="tenant.location" class="hc-doc-party-meta">{{ tenant.location }}</div>
                </div>
              </div>
              <div class="hc-doc-party hc-doc-party--right">
                <div class="text-right">
                  <div class="hc-doc-party-name">AdhereMed</div>
                  <div class="hc-doc-party-meta">info@adheremed.co</div>
                </div>
                <img :src="adhereMedLogoSrc" class="hc-doc-logo" alt="AdhereMed logo" crossorigin="anonymous" />
              </div>
            </div>

            <div class="hc-doc-rule" />

            <h2 class="hc-doc-title">Patient Consent Form</h2>
            <div class="hc-doc-sub">
              {{ scopeLabel(viewTarget.scope) }} &middot; Ref #{{ viewTarget.id }}
            </div>

            <table class="hc-doc-table">
              <tbody>
                <tr>
                  <td class="hc-doc-label">Patient</td>
                  <td class="hc-doc-value">{{ viewTarget.patient_name || '—' }}</td>
                  <td class="hc-doc-label">Scope</td>
                  <td class="hc-doc-value">{{ scopeLabel(viewTarget.scope) }}</td>
                </tr>
                <tr>
                  <td class="hc-doc-label">Granted to</td>
                  <td class="hc-doc-value">{{ viewTarget.granted_to || '—' }}</td>
                  <td class="hc-doc-label">Status</td>
                  <td class="hc-doc-value">{{ statusLabel(viewTarget) }}</td>
                </tr>
                <tr>
                  <td class="hc-doc-label">Granted at</td>
                  <td class="hc-doc-value">{{ formatDateTime(viewTarget.granted_at) }}</td>
                  <td class="hc-doc-label">Expires at</td>
                  <td class="hc-doc-value">{{ viewTarget.expires_at ? formatDate(viewTarget.expires_at) : '—' }}</td>
                </tr>
                <tr v-if="viewTarget.revoked_at">
                  <td class="hc-doc-label">Revoked at</td>
                  <td class="hc-doc-value" colspan="3">{{ formatDateTime(viewTarget.revoked_at) }}</td>
                </tr>
              </tbody>
            </table>

            <div v-if="viewTarget.notes" class="hc-doc-notes">
              <div class="hc-doc-label mb-1">Notes</div>
              <div class="hc-doc-value">{{ viewTarget.notes }}</div>
            </div>

            <div class="hc-doc-declare">
              I, the undersigned, confirm that I have read and understood the scope of this
              consent and voluntarily grant permission as described above under applicable laws.
            </div>

            <!-- Signature block -->
            <div class="hc-doc-sign">
              <div class="hc-doc-sign-box">
                <img v-if="viewTarget.signature_data_url" :src="viewTarget.signature_data_url"
                     class="hc-doc-sign-img" alt="signature" crossorigin="anonymous" />
                <div v-else class="hc-doc-sign-empty">Not signed</div>
                <div class="hc-doc-sign-line" />
                <div class="hc-doc-sign-meta">
                  <strong>{{ viewTarget.signed_by_name || '—' }}</strong>
                  <span v-if="viewTarget.signed_by_relationship"> ({{ viewTarget.signed_by_relationship }})</span>
                </div>
                <div class="hc-doc-sign-meta">
                  Signed {{ viewTarget.signed_at ? formatDateTime(viewTarget.signed_at) : '—' }}
                </div>
              </div>
              <div class="hc-doc-verify">
                <div v-if="viewTarget.signature_hash" class="hc-doc-verify-badge">
                  Digitally signed &middot; verified
                </div>
                <div v-if="viewTarget.signature_hash" class="hc-doc-hash">
                  SHA-256: {{ viewTarget.signature_hash }}
                </div>
              </div>
            </div>

            <div class="hc-doc-foot">
              Generated {{ formatDateTime(new Date()) }} &middot; AdhereMed &middot; info@adheremed.co
            </div>
          </div>
        </v-card-text>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2500">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
import adhereMedLogoUrl from '~/assets/images/logo.png'
import defaultLogoUrl from '~/assets/images/hos_default.png'

const { $api } = useNuxtApp()
const runtimeConfig = useRuntimeConfig()

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

// Signature state (existing consent)
const signDialog = ref(false)
const signing = ref(false)
const signTarget = ref(null)
const sigCanvas = ref(null)
const signForm = reactive({ signed_by_name: '', signed_by_relationship: '' })
let sigCtx = null
let sigDrawing = false
let sigHasInk = false

// Signature state (new consent dialog)
const createSigCanvas = ref(null)
let createSigCtx = null
let createSigDrawing = false
let createSigHasInk = false

// View / PDF state
const viewDialog = ref(false)
const viewTarget = ref(null)
const docRef = ref(null)
const pdfLoading = ref(false)
const DEFAULT_TENANT = { name: 'Tenant Name', email: 'tenant email', location: '' }
const tenant = ref({ ...DEFAULT_TENANT })
const tenantLogoSrc = ref(defaultLogoUrl)
const adhereMedLogoSrc = ref(adhereMedLogoUrl)

const scopeOptions = [
  { value: 'records',        title: 'Medical records' },
  { value: 'medication',     title: 'Medication administration' },
  { value: 'insurance',      title: 'Insurance billing' },
  { value: 'teleconsult',    title: 'Teleconsult recording' },
  { value: 'data_analytics', title: 'Data analytics' }
]

const relationshipOptions = [
  'Self',
  'Parent',
  'Guardian',
  'Spouse',
  'Child',
  'Sibling',
  'Next of kin',
  'Legal representative',
  'Power of attorney',
  'Caregiver',
  'Other'
]

const blank = () => ({
  patient: null, scope: 'records', granted_to: '',
  expires_at: '', notes: '',
  signed_by_name: '', signed_by_relationship: 'Self'
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
function absoluteUrl(u) {
  if (!u) return null
  if (/^https?:\/\//i.test(u)) return u
  const base = (runtimeConfig.public?.apiBase || '').replace(/\/api\/?$/, '').replace(/\/$/, '')
  return base + (u.startsWith('/') ? u : '/' + u)
}
async function loadTenant() {
  try {
    const { data } = await $api.get('/homecare/company-profile/current/')
    tenant.value = {
      name: data?.legal_name || DEFAULT_TENANT.name,
      email: data?.contact_email || DEFAULT_TENANT.email,
      location: [data?.city, data?.country].filter(Boolean).join(', ')
    }
    const logo = data?.logo_url || absoluteUrl(data?.logo)
    tenantLogoSrc.value = logo || defaultLogoUrl
  } catch {
    tenant.value = { ...DEFAULT_TENANT }
    tenantLogoSrc.value = defaultLogoUrl
  }
}
onMounted(() => { load(); loadPatients(); loadTenant() })

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
function formatDateTime(d) {
  if (!d) return '—'
  return new Date(d).toLocaleString(undefined, {
    day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit'
  })
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

function openView(c) {
  viewTarget.value = c
  viewDialog.value = true
}
async function loadImageDataUrl(url) {
  if (!url) return null
  try {
    const r = await fetch(url, { credentials: 'omit' })
    if (!r.ok) return null
    const blob = await r.blob()
    return await new Promise((resolve, reject) => {
      const fr = new FileReader()
      fr.onload = () => resolve(fr.result)
      fr.onerror = reject
      fr.readAsDataURL(blob)
    })
  } catch { return null }
}
async function downloadPdf() {
  if (!viewTarget.value) return
  pdfLoading.value = true
  try {
    const [tenantLogo, amLogo] = await Promise.all([
      loadImageDataUrl(tenantLogoSrc.value),
      loadImageDataUrl(adhereMedLogoSrc.value),
    ])
    const sigImg = viewTarget.value.signature_data_url || null

    const { jsPDF } = await import('jspdf')
    const pdf = new jsPDF({ orientation: 'p', unit: 'pt', format: 'a4' })
    const pageW = pdf.internal.pageSize.getWidth()
    const margin = 40
    const c = viewTarget.value

    const C = {
      teal: [13, 148, 136],
      dark: [15, 23, 42],
      heading: [30, 41, 59],
      body: [51, 65, 85],
      muted: [100, 116, 139],
      border: [226, 232, 240],
      bg: [248, 250, 252],
    }

    pdf.setFillColor(...C.teal)
    pdf.rect(0, 0, pageW, 5, 'F')

    const logoSize = 44
    const logoY = 22

    let leftTextX = margin
    if (tenantLogo) {
      try { pdf.addImage(tenantLogo, 'PNG', margin, logoY, logoSize, logoSize, undefined, 'FAST'); leftTextX = margin + logoSize + 12 } catch (_) {}
    }
    pdf.setFont('helvetica', 'bold'); pdf.setFontSize(13); pdf.setTextColor(...C.dark)
    pdf.text(tenant.value.name || 'Tenant', leftTextX, logoY + 14)
    pdf.setFont('helvetica', 'normal'); pdf.setFontSize(8); pdf.setTextColor(...C.body)
    pdf.text(tenant.value.email || '', leftTextX, logoY + 28)
    if (tenant.value.location) pdf.text(tenant.value.location, leftTextX, logoY + 40)

    const amLogoX = pageW - margin - logoSize
    if (amLogo) {
      try { pdf.addImage(amLogo, 'PNG', amLogoX, logoY, logoSize, logoSize, undefined, 'FAST') } catch (_) {}
    }
    pdf.setFont('helvetica', 'bold'); pdf.setFontSize(13); pdf.setTextColor(...C.dark)
    pdf.text('AdhereMed', amLogoX - 12, logoY + 14, { align: 'right' })
    pdf.setFont('helvetica', 'normal'); pdf.setFontSize(8); pdf.setTextColor(...C.body)
    pdf.text('info@adheremed.co', amLogoX - 12, logoY + 28, { align: 'right' })

    let y = logoY + logoSize + 16
    pdf.setDrawColor(...C.border); pdf.setLineWidth(1)
    pdf.line(margin, y, pageW - margin, y)
    y += 26

    pdf.setFont('helvetica', 'bold'); pdf.setFontSize(16); pdf.setTextColor(...C.heading)
    pdf.text('Patient Consent Form', margin, y)
    y += 16
    pdf.setFont('helvetica', 'normal'); pdf.setFontSize(9); pdf.setTextColor(...C.muted)
    pdf.text(`${scopeLabel(c.scope)}  ·  Ref #${c.id}`, margin, y)
    y += 24

    const rowsData = [
      ['Patient', c.patient_name || '—', 'Scope', scopeLabel(c.scope)],
      ['Granted to', c.granted_to || '—', 'Status', statusLabel(c)],
      ['Granted at', formatDateTime(c.granted_at), 'Expires at', c.expires_at ? formatDate(c.expires_at) : '—'],
    ]
    if (c.revoked_at) rowsData.push(['Revoked at', formatDateTime(c.revoked_at), '', ''])

    const colLabelW = 90
    const colValW = (pageW - margin * 2 - colLabelW * 2) / 2
    const rowH = 22
    rowsData.forEach((r, i) => {
      const ry = y + i * rowH
      if (i % 2 === 0) { pdf.setFillColor(...C.bg); pdf.rect(margin, ry - 12, pageW - margin * 2, rowH, 'F') }
      pdf.setFont('helvetica', 'bold'); pdf.setFontSize(9); pdf.setTextColor(...C.muted)
      pdf.text(r[0], margin + 6, ry + 3)
      pdf.setFont('helvetica', 'normal'); pdf.setTextColor(...C.body)
      pdf.text(String(r[1]), margin + 6 + colLabelW, ry + 3, { maxWidth: colValW - 6 })
      if (r[2]) {
        pdf.setFont('helvetica', 'bold'); pdf.setTextColor(...C.muted)
        pdf.text(r[2], margin + 6 + colLabelW + colValW, ry + 3)
        pdf.setFont('helvetica', 'normal'); pdf.setTextColor(...C.body)
        pdf.text(String(r[3]), margin + 6 + colLabelW * 2 + colValW, ry + 3, { maxWidth: colValW - 6 })
      }
    })
    y += rowsData.length * rowH + 14

    if (c.notes) {
      pdf.setFont('helvetica', 'bold'); pdf.setFontSize(9); pdf.setTextColor(...C.muted)
      pdf.text('Notes', margin, y); y += 14
      pdf.setFont('helvetica', 'normal'); pdf.setTextColor(...C.body)
      const noteLines = pdf.splitTextToSize(c.notes, pageW - margin * 2)
      pdf.text(noteLines, margin, y); y += noteLines.length * 12 + 8
    }

    pdf.setFont('helvetica', 'italic'); pdf.setFontSize(9); pdf.setTextColor(...C.body)
    const decl = pdf.splitTextToSize(
      'I, the undersigned, confirm that I have read and understood the scope of this consent and voluntarily grant permission as described above under applicable laws.',
      pageW - margin * 2)
    pdf.text(decl, margin, y); y += decl.length * 12 + 20

    pdf.setDrawColor(...C.border); pdf.setLineWidth(0.5)
    pdf.roundedRect(margin, y, 240, 110, 6, 6, 'S')
    if (sigImg) {
      try { pdf.addImage(sigImg, 'PNG', margin + 10, y + 8, 220, 60, undefined, 'FAST') } catch (_) {}
    } else {
      pdf.setFont('helvetica', 'italic'); pdf.setFontSize(9); pdf.setTextColor(...C.muted)
      pdf.text('Not signed', margin + 90, y + 40)
    }
    pdf.setDrawColor(...C.muted); pdf.line(margin + 10, y + 76, margin + 230, y + 76)
    pdf.setFont('helvetica', 'bold'); pdf.setFontSize(9); pdf.setTextColor(...C.heading)
    const signer = `${c.signed_by_name || '—'}${c.signed_by_relationship ? ' (' + c.signed_by_relationship + ')' : ''}`
    pdf.text(signer, margin + 10, y + 90)
    pdf.setFont('helvetica', 'normal'); pdf.setFontSize(8); pdf.setTextColor(...C.muted)
    pdf.text(`Signed ${c.signed_at ? formatDateTime(c.signed_at) : '—'}`, margin + 10, y + 102)

    if (c.signature_hash) {
      pdf.setFont('helvetica', 'bold'); pdf.setFontSize(9); pdf.setTextColor(...C.teal)
      pdf.text('Digitally signed · verified', pageW - margin, y + 14, { align: 'right' })
      pdf.setFont('helvetica', 'normal'); pdf.setFontSize(6.5); pdf.setTextColor(...C.muted)
      const hashLines = pdf.splitTextToSize('SHA-256: ' + c.signature_hash, 250)
      pdf.text(hashLines, pageW - margin, y + 28, { align: 'right' })
    }
    y += 130

    pdf.setDrawColor(...C.border); pdf.setLineWidth(0.5)
    pdf.line(margin, y, pageW - margin, y); y += 14
    pdf.setFont('helvetica', 'normal'); pdf.setFontSize(7.5); pdf.setTextColor(...C.muted)
    pdf.text(`Generated ${formatDateTime(new Date())}  ·  AdhereMed  ·  info@adheremed.co`, margin, y)

    const safeName = (c.patient_name || 'patient').replace(/[^a-z0-9]+/gi, '_')
    pdf.save(`consent_${safeName}_${c.id}.pdf`)
  } catch (e) {
    snack.text = 'PDF generation failed'; snack.color = 'error'; snack.show = true
  } finally { pdfLoading.value = false }
}

function openCreate() {
  Object.assign(form, blank())
  createSigHasInk = false
  dialog.value = true
  nextTick(() => initCreateSig())
}
async function create() {
  if (!form.patient) {
    snack.text = 'Patient required'; snack.color = 'warning'; snack.show = true; return
  }
  if (!form.signed_by_name || !form.signed_by_name.trim()) {
    snack.text = 'Signer name is required'
    snack.color = 'warning'; snack.show = true; return
  }
  if (!form.signed_by_relationship) {
    snack.text = 'Relationship to patient is required'
    snack.color = 'warning'; snack.show = true; return
  }
  if (!createSigHasInk) {
    snack.text = 'Please sign in the box to record consent'
    snack.color = 'warning'; snack.show = true; return
  }
  saving.value = true
  try {
    const payload = {
      patient: form.patient,
      scope: form.scope,
      granted_to: form.granted_to,
      expires_at: form.expires_at || null,
      notes: form.notes,
    }
    let { data } = await $api.post('/homecare/consents/', payload)
    try {
      const dataUrl = createSigCanvas.value.toDataURL('image/png')
      const resp = await $api.post(
        `/homecare/consents/${data.id}/sign/`,
        {
          signature_data_url: dataUrl,
          signed_by_name: form.signed_by_name.trim(),
          signed_by_relationship: form.signed_by_relationship,
        }
      )
      data = resp.data
    } catch (sigErr) {
      items.value.unshift(data)
      dialog.value = false
      snack.text = 'Consent saved but signature failed'
      snack.color = 'warning'; snack.show = true
      return
    }
    items.value.unshift(data)
    dialog.value = false
    snack.text = 'Consent signed'
    snack.color = 'success'; snack.show = true
  } catch (e) {
    snack.text = e?.response?.data ? JSON.stringify(e.response.data).slice(0, 200) : 'Save failed'
    snack.color = 'error'; snack.show = true
  } finally { saving.value = false }
}

// ===== Create-dialog signature pad =====
function initCreateSig() {
  const cv = createSigCanvas.value
  if (!cv) return
  const rect = cv.getBoundingClientRect()
  const dpr = window.devicePixelRatio || 1
  cv.width = Math.max(1, Math.floor(rect.width * dpr))
  cv.height = Math.max(1, Math.floor(180 * dpr))
  cv.style.height = '180px'
  createSigCtx = cv.getContext('2d')
  createSigCtx.scale(dpr, dpr)
  createSigCtx.lineWidth = 2
  createSigCtx.lineCap = 'round'
  createSigCtx.lineJoin = 'round'
  createSigCtx.strokeStyle = '#0f172a'
  clearCreateSig()
}
function createSigPos(e) {
  const r = createSigCanvas.value.getBoundingClientRect()
  return { x: e.clientX - r.left, y: e.clientY - r.top }
}
function createSigDown(e) {
  if (!createSigCtx) return
  createSigDrawing = true
  createSigCanvas.value.setPointerCapture?.(e.pointerId)
  const p = createSigPos(e)
  createSigCtx.beginPath(); createSigCtx.moveTo(p.x, p.y)
}
function createSigMove(e) {
  if (!createSigDrawing || !createSigCtx) return
  const p = createSigPos(e)
  createSigCtx.lineTo(p.x, p.y); createSigCtx.stroke()
  createSigHasInk = true
}
function createSigUp() { createSigDrawing = false }
function clearCreateSig() {
  if (!createSigCtx || !createSigCanvas.value) return
  const cv = createSigCanvas.value
  createSigCtx.save()
  createSigCtx.setTransform(1, 0, 0, 1, 0, 0)
  createSigCtx.fillStyle = '#ffffff'
  createSigCtx.fillRect(0, 0, cv.width, cv.height)
  createSigCtx.restore()
  createSigHasInk = false
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
:global(.v-theme--dark .hc-stat),
:global(.v-theme--dark .hc-consent-card) { background: rgba(30,41,59,0.7); border-color: rgba(255,255,255,0.06); }

/* ── Consent document view ── */
.hc-view-topbar { background: linear-gradient(135deg, rgba(13,148,136,0.08), rgba(124,58,237,0.05)); }
.hc-doc-scroll { background: #eef2f5; }
.hc-doc {
  background: #fff;
  color: #0f172a;
  max-width: 720px;
  margin: 0 auto;
  padding: 32px 36px;
  border: 1px solid rgba(15,23,42,0.08);
  border-radius: 8px;
  box-shadow: 0 4px 24px rgba(15,23,42,0.08);
}
.hc-doc-head { display: flex; justify-content: space-between; align-items: flex-start; gap: 16px; }
.hc-doc-party { display: flex; align-items: center; gap: 12px; }
.hc-doc-party--right { justify-content: flex-end; }
.hc-doc-logo { width: 52px; height: 52px; object-fit: contain; border-radius: 8px; }
.hc-doc-party-name { font-size: 15px; font-weight: 800; color: #0f172a; }
.hc-doc-party-meta { font-size: 11px; color: #475569; }
.hc-doc-rule { height: 3px; background: linear-gradient(90deg,#0d9488,#7c3aed); border-radius: 3px; margin: 16px 0 20px; }
.hc-doc-title { font-size: 22px; font-weight: 800; margin: 0 0 2px; color: #1e293b; }
.hc-doc-sub { font-size: 12px; color: #64748b; margin-bottom: 18px; }
.hc-doc-table { width: 100%; border-collapse: collapse; margin-bottom: 16px; }
.hc-doc-table tr:nth-child(odd) td { background: #f8fafc; }
.hc-doc-label { font-size: 11px; font-weight: 700; color: #64748b; padding: 8px 10px; width: 110px; vertical-align: top; }
.hc-doc-value { font-size: 12px; color: #334155; padding: 8px 10px; vertical-align: top; }
.hc-doc-notes { margin-bottom: 16px; }
.hc-doc-declare { font-size: 12px; font-style: italic; color: #475569; line-height: 1.6; margin: 8px 0 24px; }
.hc-doc-sign { display: flex; justify-content: space-between; align-items: flex-end; gap: 24px; flex-wrap: wrap; }
.hc-doc-sign-box { flex: 0 0 260px; }
.hc-doc-sign-img { display: block; max-width: 240px; max-height: 70px; }
.hc-doc-sign-empty { height: 70px; display: flex; align-items: center; color: #94a3b8; font-style: italic; font-size: 12px; }
.hc-doc-sign-line { border-top: 1px solid #94a3b8; margin: 6px 0; width: 240px; }
.hc-doc-sign-meta { font-size: 11px; color: #475569; }
.hc-doc-verify { flex: 1; text-align: right; min-width: 180px; }
.hc-doc-verify-badge { font-size: 12px; font-weight: 700; color: #0d9488; }
.hc-doc-hash { font-size: 8px; color: #94a3b8; word-break: break-all; margin-top: 4px; }
.hc-doc-foot { margin-top: 24px; padding-top: 12px; border-top: 1px solid #e2e8f0; font-size: 10px; color: #94a3b8; }
</style>
