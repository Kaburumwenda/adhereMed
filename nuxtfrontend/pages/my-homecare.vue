<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader :title="`Hi ${auth.user?.first_name || ''} 💙`" subtitle="Your homecare at a glance." icon="mdi-home-heart" />

    <!-- Enrolled-homecare banner -->
    <v-card v-if="record" rounded="xl" class="pa-4 mb-4 hc-enrol-banner">
      <div class="d-flex align-center flex-wrap ga-4">
        <v-avatar size="56" color="teal" variant="flat">
          <v-icon icon="mdi-home-heart" color="white" size="30" />
        </v-avatar>
        <div class="min-w-0">
          <div class="text-caption text-medium-emphasis">You are enrolled with</div>
          <div class="text-h6 font-weight-bold">{{ company?.legal_name || 'Your homecare provider' }}</div>
          <div class="text-caption text-medium-emphasis">
            Patient ID: <strong>{{ record.medical_record_number }}</strong>
            <span v-if="record.primary_diagnosis"> · {{ record.primary_diagnosis }}</span>
          </div>
        </div>
        <v-spacer />
        <v-chip :color="riskColor(record.risk_level)" variant="tonal" size="small" class="text-capitalize">
          {{ record.risk_level }} risk
        </v-chip>
      </div>
    </v-card>

    <v-row dense class="mb-1">
      <v-col v-for="s in statCards" :key="s.label" cols="6" md="3">
        <v-card rounded="xl" :elevation="0" class="stat-card pa-4 h-100">
          <div class="d-flex align-center ga-3">
            <v-avatar size="52" :color="s.color" variant="tonal">
              <v-icon :icon="s.icon" size="26" />
            </v-avatar>
            <div class="min-w-0">
              <div class="text-h5 font-weight-bold">{{ s.value }}</div>
              <div class="text-caption text-medium-emphasis">{{ s.label }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <v-card rounded="xl" class="mt-4 hc-panel" :elevation="0">
      <v-tabs v-model="tab" bg-color="transparent" color="teal" show-arrows
              slider-color="teal" class="hc-tabs px-2">
        <v-tab value="overview" prepend-icon="mdi-view-dashboard" class="text-none">Overview</v-tab>
        <v-tab v-if="canSee('share_vitals')" value="vitals" prepend-icon="mdi-heart-pulse" class="text-none">Vitals</v-tab>
        <v-tab v-if="canSee('share_medications')" value="doses" prepend-icon="mdi-pill-multiple" class="text-none">My doses</v-tab>
        <v-tab v-if="canSee('share_medications')" value="medications" prepend-icon="mdi-pill" class="text-none">Medications</v-tab>
        <v-tab v-if="canSee('share_adherence')" value="adherence" prepend-icon="mdi-chart-donut" class="text-none">Adherence</v-tab>
        <v-tab v-if="canSee('share_escalations')" value="alerts" prepend-icon="mdi-bell-alert" class="text-none">Alerts</v-tab>
        <v-tab value="teleconsult" prepend-icon="mdi-video" class="text-none">Teleconsult</v-tab>
        <v-tab v-if="canSee('share_documents')" value="documents" prepend-icon="mdi-folder-account" class="text-none">Documents</v-tab>
        <v-tab value="insurance" prepend-icon="mdi-shield-account" class="text-none">Insurance</v-tab>
        <v-tab v-if="canSee('share_consents')" value="consents" prepend-icon="mdi-file-sign" class="text-none">Consents</v-tab>
      </v-tabs>
      <v-divider />
      <v-window v-model="tab" class="pa-4">
        <v-window-item value="overview">
          <v-row>
            <!-- Care team -->
            <v-col v-if="canSee('share_care_team')" cols="12" md="6">
              <div class="text-subtitle-2 font-weight-bold mb-2">
                <v-icon size="18" class="mr-1">mdi-account-group</v-icon> My care team
              </div>
              <v-list>
                <v-list-item v-if="record?.assigned_caregiver_name"
                             :title="record.assigned_caregiver_name" subtitle="Primary caregiver">
                  <template #prepend>
                    <v-avatar color="teal" variant="tonal"><v-icon icon="mdi-account-star" /></v-avatar>
                  </template>
                </v-list-item>
                <v-list-item v-for="c in (record?.additional_caregivers_detail || [])" :key="c.id"
                             :title="c.full_name" subtitle="Caregiver">
                  <template #prepend>
                    <v-avatar color="purple" variant="tonal"><v-icon icon="mdi-account-tie" /></v-avatar>
                  </template>
                </v-list-item>
                <v-list-item v-if="doctorName" :title="doctorName" subtitle="Responsible doctor">
                  <template #prepend>
                    <v-avatar color="indigo" variant="tonal"><v-icon icon="mdi-doctor" /></v-avatar>
                  </template>
                </v-list-item>
                <EmptyState v-if="!record?.assigned_caregiver_name && !(record?.additional_caregivers_detail || []).length && !doctorName"
                            icon="mdi-account-off" title="No care team assigned yet" />
              </v-list>
            </v-col>

            <!-- Medical record -->
            <v-col v-if="canSee('share_profile')" cols="12" md="6">
              <div class="text-subtitle-2 font-weight-bold mb-2">
                <v-icon size="18" class="mr-1">mdi-clipboard-text</v-icon> My medical record
              </div>
              <v-list density="comfortable">
                <v-list-item title="Primary diagnosis"
                             :subtitle="record?.primary_diagnosis || '—'" />
                <v-list-item title="Allergies" :subtitle="record?.allergies || 'None recorded'" />
                <v-list-item title="Age / gender"
                             :subtitle="`${record?.age ?? '—'} · ${record?.gender || '—'}`" />
              </v-list>
              <div v-if="record?.medical_history" class="text-caption text-medium-emphasis mt-2"
                   style="white-space: pre-line;">
                {{ record.medical_history }}
              </div>
            </v-col>
          </v-row>
        </v-window-item>

        <v-window-item value="vitals">
          <div class="d-flex align-center justify-space-between mb-3 flex-wrap ga-2">
            <div class="text-subtitle-1 font-weight-bold">
              <v-icon size="20" class="mr-1" color="teal">mdi-heart-pulse</v-icon>
              Latest vitals &amp; measurements
            </div>
            <span class="text-caption text-medium-emphasis">Last 30 days</span>
          </div>
          <v-row dense>
            <v-col v-for="m in vitalCards" :key="m.key" cols="6" md="4" lg="3">
              <v-card rounded="xl" :elevation="0" class="vital-card pa-4 h-100">
                <div class="d-flex align-center justify-space-between">
                  <v-avatar size="40" color="teal" variant="tonal"><v-icon :icon="vitalIcon(m.key)" /></v-avatar>
                  <v-icon v-if="m.delta" :icon="m.delta > 0 ? 'mdi-trending-up' : 'mdi-trending-down'"
                          :color="m.delta > 0 ? 'orange' : 'green'" size="18" />
                </div>
                <div class="text-h5 font-weight-bold mt-2">
                  {{ m.value }}<span class="text-caption text-medium-emphasis ml-1">{{ m.unit }}</span>
                </div>
                <div class="text-caption text-medium-emphasis text-truncate">{{ m.display }}</div>
                <div class="text-caption text-disabled">{{ formatDate(m.at) }}</div>
              </v-card>
            </v-col>
          </v-row>
          <EmptyState v-if="!vitalCards.length" icon="mdi-heart-off" title="No vitals recorded yet"
                      subtitle="Measurements taken by your care team will appear here." />
        </v-window-item>

        <v-window-item value="doses">
          <v-list>
            <v-list-item v-for="d in doses" :key="d.id"
              :title="`${d.medication_name} · ${d.dose}`"
              :subtitle="formatTime(d.scheduled_at)">
              <template #prepend>
                <v-avatar :color="dotColor(d.status)" size="36">
                  <v-icon icon="mdi-pill" color="white" />
                </v-avatar>
              </template>
              <template #append>
                <div class="d-flex ga-1">
                  <v-btn v-if="d.status === 'pending'" size="small" color="success" variant="tonal"
                         prepend-icon="mdi-check" @click="confirm(d)">I took it</v-btn>
                  <StatusChip v-else :status="d.status" />
                </div>
              </template>
            </v-list-item>
            <EmptyState v-if="!doses.length" icon="mdi-pill-off" title="No doses scheduled" />
          </v-list>
        </v-window-item>
        <v-window-item value="medications">
          <v-list>
            <v-list-item v-for="m in medications" :key="m.id"
              :title="`${m.medication_name} · ${m.dose || ''}`"
              :subtitle="`${m.frequency_cron || ''}${m.instructions ? ' · ' + m.instructions : ''}`">
              <template #prepend>
                <v-avatar color="teal" variant="tonal"><v-icon icon="mdi-pill" /></v-avatar>
              </template>
              <template #append>
                <v-chip size="x-small" :color="m.is_active ? 'success' : 'grey'" variant="tonal">
                  {{ m.is_active ? 'Active' : 'Stopped' }}
                </v-chip>
              </template>
            </v-list-item>
            <EmptyState v-if="!medications.length" icon="mdi-pill-off" title="No medications on file" />
          </v-list>
        </v-window-item>

        <v-window-item value="adherence">
          <div v-if="adherence && adherence.total">
            <v-row align="center">
              <v-col cols="12" md="4" class="text-center">
                <v-progress-circular :model-value="adherenceRate || 0" :size="164" :width="14"
                                     :color="adherenceRate >= 80 ? 'success' : adherenceRate >= 50 ? 'warning' : 'error'">
                  <span class="text-h4 font-weight-bold">{{ adherenceRate }}%</span>
                </v-progress-circular>
                <div class="text-body-2 text-medium-emphasis mt-2">Overall adherence</div>
              </v-col>
              <v-col cols="12" md="8">
                <v-row dense>
                  <v-col cols="12" sm="4">
                    <v-card rounded="xl" :elevation="0" class="adh-tile pa-4 text-center">
                      <div class="text-h5 font-weight-bold text-success">{{ adherence.taken || 0 }}</div>
                      <div class="text-caption text-medium-emphasis">Doses taken</div>
                    </v-card>
                  </v-col>
                  <v-col cols="12" sm="4">
                    <v-card rounded="xl" :elevation="0" class="adh-tile pa-4 text-center">
                      <div class="text-h5 font-weight-bold text-error">{{ adherence.missed || 0 }}</div>
                      <div class="text-caption text-medium-emphasis">Doses missed</div>
                    </v-card>
                  </v-col>
                  <v-col cols="12" sm="4">
                    <v-card rounded="xl" :elevation="0" class="adh-tile pa-4 text-center">
                      <div class="text-h5 font-weight-bold">{{ adherence.total || 0 }}</div>
                      <div class="text-caption text-medium-emphasis">Total doses</div>
                    </v-card>
                  </v-col>
                </v-row>
                <v-alert v-if="adherenceRate != null && adherenceRate < 80" type="warning" variant="tonal"
                         density="comfortable" rounded="lg" class="mt-3" icon="mdi-lightbulb-on">
                  Taking your medicines on time improves your recovery. Tap “I took it” on the My doses tab.
                </v-alert>
              </v-col>
            </v-row>
          </div>
          <EmptyState v-else icon="mdi-chart-donut" title="No adherence data yet"
                      subtitle="Your dose history will build your adherence score." />
        </v-window-item>

        <v-window-item value="alerts">
          <v-card v-for="e in escalations" :key="e.id" rounded="xl" :elevation="0"
                  class="alert-card mb-2 pa-3">
            <div class="d-flex align-center ga-3">
              <v-avatar size="42" :color="severityColor(e.severity)" variant="tonal">
                <v-icon icon="mdi-alert" />
              </v-avatar>
              <div class="flex-grow-1 min-w-0">
                <div class="font-weight-bold text-truncate">{{ e.reason || e.rule_name || 'Health alert' }}</div>
                <div v-if="e.detail" class="text-caption text-medium-emphasis">{{ e.detail }}</div>
                <div class="text-caption text-disabled">{{ formatDate(e.triggered_at) }}</div>
              </div>
              <v-chip size="x-small" :color="severityColor(e.severity)" variant="tonal" class="text-capitalize">
                {{ e.severity }}
              </v-chip>
            </div>
          </v-card>
          <EmptyState v-if="!escalations.length" icon="mdi-bell-check" title="No active alerts"
                      subtitle="You're all good — no health alerts right now." />
        </v-window-item>

        <v-window-item value="teleconsult">
          <v-list>
            <v-list-item v-for="r in rooms" :key="r.id"
              :title="`Doctor visit · ${formatDate(r.scheduled_at)}`"
              :subtitle="`Status: ${r.status}`">
              <template #append>
                <v-btn color="teal" variant="tonal" prepend-icon="mdi-video"
                       :loading="joining === r.id" @click="join(r)">Join</v-btn>
              </template>
            </v-list-item>
            <EmptyState v-if="!rooms.length" icon="mdi-video-off" title="No teleconsults scheduled" />
          </v-list>
          <v-card v-if="joinUrl" rounded="xl" class="pa-2 mt-3">
            <iframe :src="joinUrl" allow="camera; microphone; fullscreen" allowfullscreen
                    style="width:100%; height:520px; border:0; border-radius:12px;" />
          </v-card>
        </v-window-item>

        <v-window-item value="documents">
          <v-card rounded="xl" :elevation="0" class="doc-summary pa-4 mb-3">
            <div class="d-flex align-center ga-3 flex-wrap">
              <v-avatar size="44" color="teal" variant="tonal"><v-icon icon="mdi-file-download" /></v-avatar>
              <div class="flex-grow-1 min-w-0">
                <div class="font-weight-bold">Health summary</div>
                <div class="text-caption text-medium-emphasis">
                  Download your record (profile, vitals &amp; consents) as a portable file.
                </div>
              </div>
              <v-btn color="teal" variant="flat" rounded="pill" prepend-icon="mdi-download"
                     class="text-none" @click="downloadFhir">Download</v-btn>
            </div>
          </v-card>
          <v-list class="py-0 bg-transparent">
            <v-list-item v-for="d in documents" :key="d.id" class="doc-row mb-2 rounded-xl" lines="two"
                         :title="d.name" :subtitle="formatDate(d.at)">
              <template #prepend>
                <v-avatar color="indigo" variant="tonal"><v-icon icon="mdi-file-document" /></v-avatar>
              </template>
              <template #append>
                <v-btn size="small" color="teal" variant="tonal" prepend-icon="mdi-open-in-new"
                       class="text-none" @click="openUrl(d.url)">View</v-btn>
              </template>
            </v-list-item>
          </v-list>
          <EmptyState v-if="!documents.length" icon="mdi-folder-open-outline" title="No documents yet"
                      subtitle="Signed consents and shared files will show up here." />
        </v-window-item>

        <v-window-item value="insurance">
          <v-list>
            <v-list-item v-for="c in claims" :key="c.id"
              :title="`Claim ${c.claim_number} · ${c.policy_provider}`"
              :subtitle="`KSh ${c.amount_requested} · ${c.claim_type}`">
              <template #append><StatusChip :status="c.status" /></template>
            </v-list-item>
            <EmptyState v-if="!claims.length" icon="mdi-shield-off" title="No claims yet" />
          </v-list>
        </v-window-item>
        <v-window-item value="consents">
          <v-card v-for="c in consents" :key="c.id" rounded="xl" :elevation="0"
                  class="consent-card mb-2 pa-3">
            <div class="d-flex align-center ga-3">
              <v-avatar size="42" :color="c.revoked_at ? 'grey' : (c.is_active ? 'teal' : 'amber')" variant="tonal">
                <v-icon icon="mdi-file-sign" />
              </v-avatar>
              <div class="flex-grow-1 min-w-0">
                <div class="font-weight-bold">{{ scopeLabel(c.scope) }}</div>
                <div class="text-caption text-medium-emphasis text-truncate">
                  {{ c.granted_to || 'Homecare provider' }} · {{ formatDate(c.granted_at) }}
                </div>
              </div>
              <v-chip size="x-small"
                      :color="c.revoked_at ? 'grey' : (c.is_active ? 'success' : 'warning')" variant="tonal">
                {{ c.revoked_at ? 'Revoked' : (c.is_active ? 'Active' : 'Inactive') }}
              </v-chip>
            </div>
            <div class="d-flex justify-end ga-1 mt-2">
              <v-btn size="small" variant="text" class="text-none" prepend-icon="mdi-eye"
                     @click="openConsent(c)">View</v-btn>
              <v-btn v-if="c.signed_document_url || c.signature_data_url" size="small" variant="tonal"
                     color="teal" class="text-none" prepend-icon="mdi-download"
                     @click="downloadConsent(c)">Download</v-btn>
              <v-btn v-if="!c.revoked_at" size="small" color="error" variant="text" class="text-none"
                     prepend-icon="mdi-cancel" @click="revoke(c)">Revoke</v-btn>
            </div>
          </v-card>
          <EmptyState v-if="!consents.length" icon="mdi-file-document-outline" title="No consents on file" />
        </v-window-item>
      </v-window>
    </v-card>

    <!-- Consent viewer -->
    <v-dialog v-model="consentDialog.show" max-width="560">
      <v-card v-if="consentDialog.item" rounded="xl">
        <v-card-title class="d-flex align-center ga-2 py-4">
          <v-icon color="teal">mdi-file-sign</v-icon>
          {{ scopeLabel(consentDialog.item.scope) }}
        </v-card-title>
        <v-divider />
        <v-card-text>
          <v-list density="compact" class="bg-transparent">
            <v-list-item title="Granted to" :subtitle="consentDialog.item.granted_to || 'Homecare provider'" />
            <v-list-item title="Granted on" :subtitle="formatDate(consentDialog.item.granted_at)" />
            <v-list-item v-if="consentDialog.item.expires_at" title="Expires"
                         :subtitle="formatDate(consentDialog.item.expires_at)" />
            <v-list-item v-if="consentDialog.item.signed_by_name" title="Signed by"
                         :subtitle="`${consentDialog.item.signed_by_name}${consentDialog.item.signed_by_relationship ? ' (' + consentDialog.item.signed_by_relationship + ')' : ''}`" />
            <v-list-item title="Status"
                         :subtitle="consentDialog.item.revoked_at ? 'Revoked' : (consentDialog.item.is_active ? 'Active' : 'Inactive')" />
          </v-list>
          <div v-if="consentDialog.item.notes" class="text-body-2 mt-2 px-4" style="white-space: pre-line;">
            {{ consentDialog.item.notes }}
          </div>
          <div v-if="consentDialog.item.signature_data_url" class="mt-3 px-4">
            <div class="text-caption text-medium-emphasis mb-1">Signature</div>
            <v-img :src="consentDialog.item.signature_data_url" max-height="120"
                   class="sig-img rounded-lg" contain />
          </div>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-btn v-if="consentDialog.item.signed_document_url || consentDialog.item.signature_data_url"
                 variant="tonal" color="teal" prepend-icon="mdi-download" class="text-none"
                 @click="downloadConsent(consentDialog.item)">Download</v-btn>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="consentDialog.show = false">Close</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>
<script setup>
import { useAuthStore } from '~/stores/auth'
import { useHomecareEvents } from '~/composables/useHomecare'

const auth = useAuthStore()
const { $api } = useNuxtApp()
const route = useRoute()
const tab = ref(route.query.tab || 'overview')
const doses = ref([])
const rooms = ref([])
const claims = ref([])
const consents = ref([])
const medications = ref([])
const record = ref(null)
const company = ref(null)
const sharing = ref(null)
const vitals = ref(null)
const adherence = ref(null)
const escalations = ref([])
const consentDialog = reactive({ show: false, item: null })
const joinUrl = ref('')
const joining = ref(null)

const pendingCount = computed(() => doses.value.filter(d => d.status === 'pending').length)
const doctorName = computed(() => record.value?.assigned_doctor_info?.name || null)
// When sharing is null (not yet loaded) default to visible; once loaded, respect flags.
function canSee(key) { return !sharing.value || sharing.value[key] !== false }

const adherenceRate = computed(() => {
  const a = adherence.value
  if (!a || !a.total) return null
  return Math.round((a.taken / a.total) * 100)
})

const vitalCards = computed(() => {
  const v = vitals.value
  if (!v || !v.series) return []
  return Object.keys(v.series).map((k) => {
    const arr = v.series[k] || []
    if (!arr.length) return null
    const last = arr[arr.length - 1]
    const prev = arr.length > 1 ? arr[arr.length - 2] : null
    const meta = (v.metrics && v.metrics[k]) || {}
    return {
      key: k,
      display: meta.display || k,
      unit: meta.unit || '',
      value: last.v,
      at: last.t,
      delta: prev != null ? +(last.v - prev.v).toFixed(1) : null
    }
  }).filter(Boolean)
})

const statCards = computed(() => {
  const cards = [
    { label: 'Doses to take today', value: pendingCount.value, icon: 'mdi-pill', color: 'teal' }
  ]
  if (canSee('share_adherence')) {
    cards.push({ label: 'Medication adherence', value: adherenceRate.value != null ? adherenceRate.value + '%' : '—', icon: 'mdi-chart-donut', color: 'green' })
  }
  if (canSee('share_escalations')) {
    cards.push({ label: 'Open alerts', value: escalations.value.length, icon: 'mdi-bell-alert', color: 'orange' })
  }
  cards.push({ label: 'Teleconsults', value: rooms.value.length, icon: 'mdi-video', color: 'indigo' })
  return cards
})

const documents = computed(() => {
  const docs = []
  consents.value.forEach((c) => {
    if (c.signed_document_url) {
      docs.push({ id: 'c' + c.id, name: `Signed consent \u2014 ${scopeLabel(c.scope)}`, url: c.signed_document_url, at: c.signed_at || c.granted_at })
    }
  })
  return docs
})

function vitalIcon(k) {
  return {
    systolic: 'mdi-heart-pulse', diastolic: 'mdi-heart-pulse', bp: 'mdi-heart-pulse',
    hr: 'mdi-heart', pulse: 'mdi-heart', temp: 'mdi-thermometer', temperature: 'mdi-thermometer',
    spo2: 'mdi-water-percent', rr: 'mdi-lungs', resp: 'mdi-lungs',
    weight: 'mdi-scale-bathroom', glucose: 'mdi-water', sugar: 'mdi-water',
    height: 'mdi-human-male-height', bmi: 'mdi-scale'
  }[k] || 'mdi-chart-line'
}
function scopeLabel(s) {
  return { records: 'Medical Records', medication: 'Medication Plan', insurance: 'Insurance Sharing', teleconsult: 'Teleconsult', data_analytics: 'Data Analytics' }[s] || s
}
function severityColor(s) { return { low: 'info', medium: 'warning', high: 'orange', critical: 'error' }[s] || 'grey' }
function openUrl(u) { if (u) window.open(u, '_blank') }
function openConsent(c) { consentDialog.item = c; consentDialog.show = true }
function downloadConsent(c) {
  if (c.signed_document_url) { window.open(c.signed_document_url, '_blank'); return }
  if (c.signature_data_url) {
    const a = document.createElement('a')
    a.href = c.signature_data_url
    a.download = `consent-${c.scope}-${c.id}.png`
    document.body.appendChild(a); a.click(); a.remove()
  }
}
async function downloadFhir() {
  if (!record.value?.id) return
  try {
    const { data } = await $api.get(`/homecare/patients/${record.value.id}/fhir/`)
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url; a.download = `health-summary-${record.value.medical_record_number || 'record'}.json`
    document.body.appendChild(a); a.click(); a.remove(); URL.revokeObjectURL(url)
  } catch (e) { /* ignore */ }
}

function dotColor(s) { return { taken: 'success', missed: 'error', skipped: 'grey', pending: 'info' }[s] || 'grey' }
function riskColor(r) { return { low: 'success', medium: 'warning', high: 'orange', critical: 'error' }[r] || 'grey' }
function formatTime(iso) { return iso ? new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '' }
function formatDate(iso) { return iso ? new Date(iso).toLocaleString() : '' }

async function load() {
  const safe = (p) => $api.get(p).then(r => r.data?.results || r.data || []).catch(() => [])
  doses.value = await safe('/homecare/doses/today/')
  rooms.value = await safe('/homecare/teleconsult-rooms/')
  claims.value = await safe('/homecare/insurance-claims/')
  consents.value = await safe('/homecare/consents/')
  // Patient's own homecare record (role=patient filters to self).
  const mine = await safe('/homecare/patients/')
  record.value = Array.isArray(mine) ? mine[0] || null : null
  company.value = await $api.get('/homecare/company-profile/current/')
    .then(r => r.data).catch(() => null)
  if (record.value?.id) {
    const ov = await $api.get(`/homecare/patients/${record.value.id}/overview/`)
      .then(r => r.data).catch(() => null)
    medications.value = ov?.medication_schedules || []
    sharing.value = ov?.sharing || null
    adherence.value = ov?.adherence || null
    escalations.value = ov?.open_escalations || []
    vitals.value = await $api.get(`/homecare/patients/${record.value.id}/vital-trend/?days=30`)
      .then(r => r.data).catch(() => null)
  }
}
async function confirm(d) {
  await $api.post(`/homecare/doses/${d.id}/mark_taken/`, {
    patient_confirmation: { method: 'self', at: new Date().toISOString() }
  })
  load()
}
async function join(r) {
  joining.value = r.id
  try {
    const { data } = await $api.post(`/homecare/teleconsult-rooms/${r.id}/join/`)
    joinUrl.value = data.join_url
  } finally { joining.value = null }
}
async function revoke(c) {
  await $api.post(`/homecare/consents/${c.id}/revoke/`)
  load()
}

onMounted(load)
useHomecareEvents(() => load())
</script>
<style scoped>
.dash-card {
  background: linear-gradient(160deg, rgba(20,184,166,0.05), rgba(56,189,248,0.05));
  border: 1px solid rgba(20,184,166,0.12);
}
.hc-enrol-banner {
  background: linear-gradient(160deg, rgba(20,184,166,0.08), rgba(56,189,248,0.06));
  border: 1px solid rgba(20,184,166,0.18);
}
.stat-card {
  background: linear-gradient(160deg, rgba(20,184,166,0.06), rgba(56,189,248,0.05));
  border: 1px solid rgba(20,184,166,0.14);
  transition: transform .18s ease, box-shadow .18s ease;
}
.stat-card:hover { transform: translateY(-2px); box-shadow: 0 10px 26px rgba(20,184,166,0.14); }
.hc-panel {
  border: 1px solid rgba(20,184,166,0.10);
  overflow: hidden;
}
.hc-tabs { border-bottom: 1px solid rgba(20,184,166,0.10); }
.vital-card,
.adh-tile,
.alert-card,
.consent-card,
.doc-summary,
.doc-row {
  background: rgba(255,255,255,0.7);
  border: 1px solid rgba(20,184,166,0.12);
  transition: box-shadow .18s ease;
}
.vital-card:hover,
.consent-card:hover,
.doc-row:hover { box-shadow: 0 8px 22px rgba(20,184,166,0.12); }
.doc-summary {
  background: linear-gradient(160deg, rgba(20,184,166,0.08), rgba(56,189,248,0.05));
  border: 1px solid rgba(20,184,166,0.18);
}
.sig-img { border: 1px solid rgba(0,0,0,0.08); background: #fff; }

:global(.v-theme--dark .stat-card),
:global(.v-theme--dark .hc-enrol-banner),
:global(.v-theme--dark .dash-card),
:global(.v-theme--dark .doc-summary) {
  background: linear-gradient(160deg, rgba(20,184,166,0.14), rgba(30,41,59,0.5));
  border: 1px solid rgba(20,184,166,0.22);
}
:global(.v-theme--dark .hc-panel) {
  background: rgba(30,41,59,0.55);
  border: 1px solid rgba(20,184,166,0.16);
}
:global(.v-theme--dark .vital-card),
:global(.v-theme--dark .adh-tile),
:global(.v-theme--dark .alert-card),
:global(.v-theme--dark .consent-card),
:global(.v-theme--dark .doc-row) {
  background: rgba(30,41,59,0.6);
  border: 1px solid rgba(20,184,166,0.18);
}
:global(.v-theme--dark .sig-img) { background: #e2e8f0; border-color: rgba(255,255,255,0.12); }
</style>
