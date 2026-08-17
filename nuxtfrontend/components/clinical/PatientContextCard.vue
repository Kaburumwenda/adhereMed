<template>
  <div class="patient-context">
    <!-- Patient header -->
    <div class="patient-hero text-center pa-4 mb-3">
      <v-avatar :color="avatarColor" size="64" class="mb-2" variant="tonal">
        <span class="text-h6 font-weight-bold text-primary">{{ initials }}</span>
      </v-avatar>
      <div class="text-subtitle-1 font-weight-bold">{{ patient.user_name || fullName }}</div>
      <div class="text-caption text-medium-emphasis d-flex align-center justify-center ga-1 flex-wrap">
        <span>{{ patient.gender || '—' }}</span>
        <span>·</span>
        <span>{{ age }}</span>
        <span v-if="patient.blood_type">·</span>
        <v-chip v-if="patient.blood_type" size="x-small" variant="tonal" color="red" label>
          <v-icon size="10" start>mdi-water</v-icon>{{ patient.blood_type }}
        </v-chip>
      </div>
      <div v-if="patient.patient_number" class="text-caption text-disabled mt-1">
        MRN: {{ patient.patient_number }}
      </div>
    </div>

    <!-- Risk score badges -->
    <div v-if="triage" class="risk-badges d-flex ga-2 mb-3 justify-center">
      <div class="risk-badge" :class="`risk-badge--${esiTone}`">
        <div class="text-caption font-weight-bold">ESI</div>
        <div class="text-h6">{{ triage.esi_level || '—' }}</div>
      </div>
      <div class="risk-badge" :class="`risk-badge--${news2Tone}`">
        <div class="text-caption font-weight-bold">NEWS2</div>
        <div class="text-h6">{{ triage.news2_score ?? 0 }}</div>
      </div>
      <div v-if="triage.pain_scale" class="risk-badge" :class="`risk-badge--${painTone}`">
        <div class="text-caption font-weight-bold">Pain</div>
        <div class="text-h6">{{ triage.pain_scale }}/10</div>
      </div>
    </div>

    <!-- Allergy block -->
    <v-alert
      :type="patient.allergies?.length ? 'error' : 'success'"
      variant="tonal"
      density="compact"
      class="mb-3 allergy-alert"
      :icon="patient.allergies?.length ? 'mdi-alert-octagon' : 'mdi-shield-check'"
    >
      <div class="font-weight-bold text-body-2">
        {{ patient.allergies?.length ? 'Allergies' : 'No Known Allergies (NKA)' }}
      </div>
      <div v-if="patient.allergies?.length" class="d-flex flex-wrap ga-1 mt-1">
        <v-chip v-for="a in patient.allergies" :key="a" size="x-small" color="error" variant="flat" label>{{ a }}</v-chip>
      </div>
    </v-alert>

    <!-- Vitals grid -->
    <div v-if="triage" class="vitals-grid mb-3">
      <div class="text-caption font-weight-bold mb-1">Triage Vitals</div>
      <div class="vitals-tile" v-for="v in vitalsTiles" :key="v.label">
        <v-icon :color="v.color" size="14">{{ v.icon }}</v-icon>
        <div class="text-caption text-medium-emphasis">{{ v.label }}</div>
        <div class="text-body-2 font-weight-bold" :class="v.abnormal ? 'text-error' : ''">{{ v.value }}</div>
      </div>
    </div>

    <!-- Active Problem List -->
    <div class="mb-3">
      <div class="text-caption font-weight-bold mb-1 d-flex align-center">
        <v-icon size="14" class="mr-1" color="warning">mdi-clipboard-list-outline</v-icon>
        Active Problems
      </div>
      <div v-if="patient.chronic_conditions?.length" class="d-flex flex-wrap ga-1">
        <v-chip v-for="c in patient.chronic_conditions" :key="c" size="small" variant="tonal" color="warning">{{ c }}</v-chip>
      </div>
      <div v-else class="text-body-2 text-medium-emphasis">None documented</div>
    </div>

    <!-- Current Medications -->
    <div class="mb-3">
      <div class="text-caption font-weight-bold mb-1 d-flex align-center">
        <v-icon size="14" class="mr-1" color="purple">mdi-pill-multiple</v-icon>
        Active Medications
      </div>
      <div v-if="activeMeds?.length" class="d-flex flex-column ga-1">
        <div v-for="(m, i) in activeMeds" :key="i" class="med-item">
          <div class="text-body-2 font-weight-bold">{{ medName(m) }}</div>
          <div class="text-caption text-medium-emphasis">
            {{ m.items?.[0]?.dosage || m.dosage || '' }} · {{ m.items?.[0]?.frequency || m.frequency || '' }}
          </div>
        </div>
      </div>
      <div v-else class="text-body-2 text-medium-emphasis">None</div>
    </div>

    <!-- Insurance -->
    <div v-if="patient.insurance_provider" class="mb-3">
      <div class="text-caption font-weight-bold mb-1 d-flex align-center">
        <v-icon size="14" class="mr-1" color="blue">mdi-shield-account</v-icon>
        Insurance
      </div>
      <div class="text-body-2">{{ patient.insurance_provider }}</div>
      <div class="text-caption text-medium-emphasis">{{ patient.insurance_number || 'No policy # provided' }}</div>
    </div>

    <!-- Past Visits Timeline -->
    <div v-if="pastVisits?.length" class="mb-3">
      <div class="text-caption font-weight-bold mb-2 d-flex align-center">
        <v-icon size="14" class="mr-1" color="teal">mdi-history</v-icon>
        Recent Visits
      </div>
      <div class="timeline">
        <div v-for="(v, i) in pastVisits" :key="i" class="timeline-item">
          <div class="timeline-dot" :class="i === 0 ? 'timeline-dot--active' : ''" />
          <div class="timeline-content">
            <div class="text-caption font-weight-bold">{{ formatDate(v.created_at) }}</div>
            <div class="text-body-2 text-medium-emphasis">
              <v-chip :color="statusColor(v.status)" size="x-small" variant="tonal" class="mr-1">{{ statusLabel(v.status) }}</v-chip>
              {{ v.chief_complaint || '—' }}
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { formatDate } from '~/utils/format'
import { esiColor, news2Color } from '~/composables/useClinicalScoring'

const props = defineProps({
  patient: { type: Object, required: true },
  triage: { type: Object, default: null },
  activeMeds: { type: Array, default: () => [] },
  pastVisits: { type: Array, default: () => [] },
})

const fullName = computed(() => {
  const u = props.patient?.user
  if (u) return `${u.first_name || ''} ${u.last_name || ''}`.trim()
  return `${props.patient?.first_name || ''} ${props.patient?.last_name || ''}`.trim() || 'Patient'
})
const initials = computed(() => {
  const n = (fullName.value || '').split(/\s+/).filter(Boolean)
  return ((n[0]?.[0] || '') + (n[1]?.[0] || '')).toUpperCase() || '?'
})
const avatarColor = computed(() => {
  const colors = ['deep-purple', 'teal', 'indigo', 'pink', 'cyan-darken-2', 'amber-darken-2', 'green-darken-1', 'orange-darken-2']
  return colors[(props.patient?.id || 0) % 8]
})
const age = computed(() => {
  if (!props.patient?.date_of_birth) return '—'
  const d = new Date(props.patient.date_of_birth)
  const yrs = Math.floor((Date.now() - d) / 315576000000)
  return `${yrs}y`
})

function medName(m) {
  return m.items?.[0]?.medication_name || m.medication_name || m.items?.[0]?.custom_medication_name || '—'
}

const vitalsTiles = computed(() => {
  const vs = props.triage?.vital_signs || {}
  const out = []
  const push = (label, value, icon, color, abnormal) => out.push({ label, value: value ?? '—', icon, color: abnormal ? 'error' : color, abnormal: !!abnormal })
  push('Temp', vs.temperature ? `${vs.temperature}°C` : '—', 'mdi-thermometer', 'orange', vs.temperature && (vs.temperature > 38 || vs.temperature < 35))
  push('BP', `${vs.bp_systolic ?? '—'}/${vs.bp_diastolic ?? '—'}`, 'mdi-heart-pulse', 'red', vs.bp_systolic > 140 || vs.bp_diastolic > 90)
  push('HR', vs.heart_rate ?? '—', 'mdi-heart', 'pink', vs.heart_rate && (vs.heart_rate > 100 || vs.heart_rate < 50))
  push('RR', vs.respiratory_rate ?? '—', 'mdi-lungs', 'teal', vs.respiratory_rate && (vs.respiratory_rate > 20 || vs.respiratory_rate < 12))
  push('SpO2', vs.oxygen_saturation != null ? `${vs.oxygen_saturation}%` : '—', 'mdi-water-percent', 'cyan', vs.oxygen_saturation != null && vs.oxygen_saturation < 92)
  push('Glucose', vs.blood_sugar ?? '—', 'mdi-water', 'amber', vs.blood_sugar != null && vs.blood_sugar > 11)
  return out
})

const esiTone = computed(() => toneFromColor(esiColor(props.triage?.esi_level)))
const news2Tone = computed(() => toneFromColor(news2Color(props.triage?.news2_score)))
const painTone = computed(() => {
  const p = props.triage?.pain_scale ?? 0
  return toneFromColor(p >= 7 ? 'error' : p >= 4 ? 'warning' : 'success')
})

function toneFromColor(c) {
  return ({ error: 'danger', warning: 'warn', success: 'good', info: 'info', grey: 'neutral' })[c] || 'neutral'
}

function statusColor(s) { return ({ draft: 'info', signed: 'primary', locked: 'grey-darken-1' })[s] || 'grey' }
function statusLabel(s) { return ({ draft: 'Draft', signed: 'Signed', locked: 'Locked' })[s] || s || '—' }
</script>

<style scoped>
.patient-context { font-size: 0.875rem; }
.patient-hero { border-radius: 12px; background: rgba(var(--v-theme-primary), 0.04); }
.risk-badges .risk-badge {
  flex: 1; text-align: center; border-radius: 8px; padding: 4px 2px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
}
.risk-badge--danger { background: rgba(var(--v-theme-error), 0.08); border-color: rgba(var(--v-theme-error), 0.3); }
.risk-badge--warn { background: rgba(var(--v-theme-warning), 0.08); border-color: rgba(var(--v-theme-warning), 0.3); }
.risk-badge--good { background: rgba(var(--v-theme-success), 0.08); border-color: rgba(var(--v-theme-success), 0.3); }
.risk-badge--info { background: rgba(var(--v-theme-info), 0.08); border-color: rgba(var(--v-theme-info), 0.3); }
.allergy-alert { border-left: 4px solid currentColor; }
.vitals-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 6px; }
.vitals-tile {
  padding: 6px 4px; border-radius: 8px; text-align: center;
  background: rgba(var(--v-theme-on-surface), 0.03); border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.med-item { padding: 4px 6px; border-radius: 6px; background: rgba(var(--v-theme-on-surface), 0.03); }
.timeline { position: relative; padding-left: 14px; }
.timeline::before { content: ''; position: absolute; left: 5px; top: 4px; bottom: 4px; width: 2px; background: rgba(var(--v-theme-primary), 0.2); }
.timeline-item { position: relative; padding-bottom: 8px; }
.timeline-dot {
  position: absolute; left: -14px; top: 4px; width: 10px; height: 10px; border-radius: 50%;
  background: rgba(var(--v-theme-primary), 0.3); border: 2px solid rgb(var(--v-theme-primary));
}
.timeline-dot--active { background: rgb(var(--v-theme-primary)); box-shadow: 0 0 0 3px rgba(var(--v-theme-primary), 0.2); }
</style>
