<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 1200px;">
    <!-- ── Header ─────────────────────────────────────────────────── -->
    <div class="d-flex align-center flex-wrap ga-3 mb-4">
      <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left"
             :to="backPath">Back</v-btn>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-pencil"
             :to="editPath">Edit</v-btn>
      <v-btn color="primary" rounded="lg" class="text-none" prepend-icon="mdi-calendar-plus"
             :to="newAppointmentLink">New Appointment</v-btn>
      <v-menu>
        <template #activator="{ props }">
          <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" />
        </template>
        <v-list density="compact">
          <v-list-item :to="editPath" prepend-icon="mdi-account-edit">
            <v-list-item-title>Edit Patient</v-list-item-title>
          </v-list-item>
          <v-list-item :to="newAppointmentLink" prepend-icon="mdi-calendar-plus">
            <v-list-item-title>New Appointment</v-list-item-title>
          </v-list-item>
          <v-list-item :to="newConsultationLink" prepend-icon="mdi-medical-bag">
            <v-list-item-title>New Consultation</v-list-item-title>
          </v-list-item>
          <v-list-item :to="newPrescriptionLink" prepend-icon="mdi-pill">
            <v-list-item-title>Write Prescription</v-list-item-title>
          </v-list-item>
          <v-list-item :to="newLabLink" prepend-icon="mdi-microscope">
            <v-list-item-title>Order Lab Test</v-list-item-title>
          </v-list-item>
          <v-list-item :to="newInvoiceLink" prepend-icon="mdi-receipt-text">
            <v-list-item-title>Create Invoice</v-list-item-title>
          </v-list-item>
          <v-divider />
          <v-list-item @click="confirmDelete" prepend-icon="mdi-delete" base-color="error">
            <v-list-item-title>Delete Patient</v-list-item-title>
          </v-list-item>
        </v-list>
      </v-menu>
    </div>

    <!-- ── Loading state ──────────────────────────────────────────── -->
    <div v-if="loading" class="d-flex justify-center pa-12">
      <v-progress-circular indeterminate color="primary" size="48" />
    </div>

    <div v-else-if="!patient" class="pa-10 text-center">
      <v-icon size="64" color="grey-lighten-1">mdi-account-question</v-icon>
      <div class="text-h6 font-weight-medium mt-3">Patient not found</div>
      <v-btn color="primary" rounded="lg" class="text-none mt-3" :to="backPath">
        Back to Patients
      </v-btn>
    </div>

    <template v-else>
      <!-- ═══ Patient identity banner ═══════════════════════════════ -->
      <v-card flat rounded="lg" class="patient-banner pa-5 mb-4">
        <div class="d-flex align-center flex-wrap ga-4">
          <v-avatar :color="avatarColor" size="80" class="mr-2">
            <span class="text-white font-weight-bold text-h5">{{ patientInitials }}</span>
          </v-avatar>
          <div class="flex-grow-1" style="min-width: 200px;">
            <div class="text-h5 font-weight-bold">{{ displayName }}</div>
            <div class="d-flex flex-wrap align-center ga-2 text-body-2 text-medium-emphasis">
              <span class="font-monospace">{{ patient.patient_number || '—' }}</span>
              <span v-if="patient.patient_id">·</span>
              <span v-if="patient.patient_id">{{ patient.patient_id }}</span>
              <span>·</span>
              <v-chip size="x-small" variant="tonal"
                      :color="patient.gender === 'male' ? 'info' : patient.gender === 'female' ? 'pink' : 'grey'"
                      class="text-capitalize">{{ patient.gender || 'unknown' }}</v-chip>
              <span v-if="age != null">· {{ age }} yrs</span>
              <v-chip v-if="patient.blood_type" size="x-small" variant="flat" color="red-lighten-5"
                      class="text-red-darken-3 font-weight-bold">{{ patient.blood_type }}</v-chip>
            </div>
          </div>
          <div class="d-flex flex-column align-end ga-1">
            <div v-if="patient.user?.phone" class="d-flex align-center text-body-2">
              <v-icon size="16" class="mr-1" color="medium-emphasis">mdi-phone</v-icon>
              {{ patient.user.phone }}
            </div>
            <div v-if="patient.user_email || patient.user?.email"
                 class="d-flex align-center text-body-2 text-medium-emphasis">
              <v-icon size="16" class="mr-1" color="medium-emphasis">mdi-email</v-icon>
              {{ patient.user_email || patient.user?.email }}
            </div>
          </div>
        </div>

        <!-- Inline flags -->
        <div v-if="allergies.length || chronicConditions.length || patient.insurance_provider"
             class="mt-3 d-flex flex-wrap ga-2 pt-3 border-t">
          <v-chip v-if="allergies.length" size="small" variant="tonal" color="red">
            <v-icon start size="14">mdi-alert-circle</v-icon>
            Allergies: {{ allergies.join(', ') }}
          </v-chip>
          <v-chip v-if="chronicConditions.length" size="small" variant="tonal" color="amber">
            <v-icon start size="14">mdi-pulse</v-icon>
            Chronic: {{ chronicConditions.join(', ') }}
          </v-chip>
          <v-chip v-if="patient.insurance_provider" size="small" variant="tonal" color="green">
            <v-icon start size="14">mdi-shield-check</v-icon>
            {{ patient.insurance_provider }}
            <span v-if="patient.insurance_number"> · {{ patient.insurance_number }}</span>
          </v-chip>
        </div>
      </v-card>

      <!-- ═══ Quick action cards ═══════════════════════════════════ -->
      <v-row dense class="mb-4">
        <v-col v-for="stat in quickStats" :key="stat.label" cols="6" md="3">
          <v-card flat rounded="lg" class="qa-card pa-3 h-100" hover @click="stat.action ? stat.action() : null">
            <div class="d-flex align-center">
              <v-avatar :color="stat.color + '-lighten-5'" size="36" class="mr-2">
                <v-icon :color="stat.color + '-darken-2'" size="20">{{ stat.icon }}</v-icon>
              </v-avatar>
              <div>
                <div class="text-overline text-medium-emphasis" style="line-height:1.1">{{ stat.label }}</div>
                <div class="text-h6 font-weight-bold" style="line-height:1.2">{{ stat.value }}</div>
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>

      <!-- ═══ Tabbed content ════════════════════════════════════════ -->
      <v-card flat rounded="lg" class="tab-card">
        <v-tabs v-model="tab" color="primary" density="comfortable" show-arrows>
          <v-tab value="overview" class="text-none">Overview</v-tab>
          <v-tab value="medical" class="text-none">
            Medical
            <v-badge v-if="allergies.length + chronicConditions.length"
                     :content="allergies.length + chronicConditions.length"
                     color="error" offset-x="-4" offset-y="-10" />
          </v-tab>
          <v-tab value="appointments" class="text-none">
            Appointments
            <v-badge v-if="appointments.length" :content="appointments.length"
                     color="primary" offset-x="-4" offset-y="-10" />
          </v-tab>
          <v-tab value="consultations" class="text-none">
            Consultations
            <v-badge v-if="consultations.length" :content="consultations.length"
                     color="primary" offset-x="-4" offset-y="-10" />
          </v-tab>
          <v-tab value="prescriptions" class="text-none">
            Prescriptions
            <v-badge v-if="prescriptions.length" :content="prescriptions.length"
                     color="primary" offset-x="-4" offset-y="-10" />
          </v-tab>
          <v-tab value="labs" class="text-none">
            Lab Orders
            <v-badge v-if="labOrders.length" :content="labOrders.length"
                     color="primary" offset-x="-4" offset-y="-10" />
          </v-tab>
          <v-tab value="invoices" class="text-none">
            Invoices
            <v-badge v-if="invoices.length" :content="invoices.length"
                     color="primary" offset-x="-4" offset-y="-10" />
          </v-tab>
        </v-tabs>

        <v-divider />

        <v-window v-model="tab" class="pa-4 pa-md-5">
          <!-- ── Overview tab ───────────────────────────────────────── -->
          <v-window-item value="overview">
            <v-row dense>
              <v-col cols="12" md="6">
                <div class="section-title mb-3">Personal Information</div>
                <DetailField label="Full Name" :value="displayName" />
                <DetailField label="Email" :value="patient.user_email || patient.user?.email" />
                <DetailField label="Phone" :value="patient.user?.phone" />
                <DetailField label="National ID" :value="patient.national_id" />
                <DetailField label="Date of Birth" :value="formatDate(patient.date_of_birth)" />
                <DetailField label="Gender" :value="patient.gender" :capitalize="true" />
                <DetailField label="Blood Type" :value="patient.blood_type" />
              </v-col>
              <v-col cols="12" md="6">
                <div class="section-title mb-3">Address</div>
                <DetailField label="Street / Location" :value="patient.address" :full="true" />

                <div class="section-title mb-3 mt-4">Emergency Contact</div>
                <DetailField label="Contact Name" :value="patient.emergency_contact_name" />
                <DetailField label="Relationship" :value="patient.emergency_contact_relation" />
                <DetailField label="Contact Phone" :value="patient.emergency_contact_phone" />

                <div class="section-title mb-3 mt-4">Insurance</div>
                <DetailField label="Provider" :value="patient.insurance_provider" />
                <DetailField label="Policy Number" :value="patient.insurance_number" />
              </v-col>
            </v-row>
            <v-divider class="my-4" />
            <v-row dense>
              <v-col cols="12" md="6">
                <div class="section-title mb-3">Registration</div>
                <DetailField label="Patient #" :value="patient.patient_number" :mono="true" />
                <DetailField label="Patient ID" :value="patient.patient_id" :mono="true" />
                <DetailField label="Source" :value="formatSource(patient.registration_source)" :capitalize="true" />
                <DetailField label="Registered" :value="formatDateTime(patient.created_at)" />
              </v-col>
              <v-col cols="12" md="6">
                <div class="section-title mb-3">Clinical Notes</div>
                <v-alert v-if="patient.notes" variant="tonal" color="grey" class="notes-box">
                  {{ patient.notes }}
                </v-alert>
                <v-alert v-else variant="tonal" color="grey" density="compact">
                  No clinical notes recorded.
                </v-alert>
              </v-col>
            </v-row>
          </v-window-item>

          <!-- ── Medical tab ────────────────────────────────────────── -->
          <v-window-item value="medical">
            <div class="section-title mb-3">Allergies</div>
            <div v-if="allergies.length" class="d-flex flex-wrap ga-2 mb-4">
              <v-chip v-for="a in allergies" :key="a" size="small" variant="tonal" color="red"
                      prepend-icon="mdi-alert-circle">{{ a }}</v-chip>
            </div>
            <v-alert v-else variant="tonal" color="grey" density="compact" class="mb-4">
              No known allergies recorded.
            </v-alert>

            <div class="section-title mb-3">Chronic Conditions</div>
            <div v-if="chronicConditions.length" class="d-flex flex-wrap ga-2 mb-4">
              <v-chip v-for="c in chronicConditions" :key="c" size="small" variant="tonal" color="amber"
                      prepend-icon="mdi-pulse">{{ c }}</v-chip>
            </div>
            <v-alert v-else variant="tonal" color="grey" density="compact" class="mb-4">
              No chronic conditions recorded.
            </v-alert>

            <div class="section-title mb-3">Clinical Notes</div>
            <v-alert v-if="patient.notes" variant="tonal" color="grey">
              {{ patient.notes }}
            </v-alert>
            <v-alert v-else variant="tonal" color="grey" density="compact">
              No clinical notes recorded.
            </v-alert>

            <div class="section-title mb-3 mt-4">Insurance</div>
            <div v-if="patient.insurance_provider" class="d-flex flex-wrap ga-2">
              <v-chip size="small" variant="tonal" color="green" prepend-icon="mdi-shield-check">
                {{ patient.insurance_provider }}
                <span v-if="patient.insurance_number"> · {{ patient.insurance_number }}</span>
              </v-chip>
            </div>
            <v-alert v-else variant="tonal" color="grey" density="compact">
              No insurance information recorded.
            </v-alert>
          </v-window-item>

          <!-- ── Appointments tab ───────────────────────────────────── -->
          <v-window-item value="appointments">
            <div v-if="loadingRelated.appointments" class="text-center pa-6">
              <v-progress-circular indeterminate color="primary" size="32" />
            </div>
            <div v-else-if="!appointments.length" class="pa-6 text-center">
              <v-icon size="48" color="grey-lighten-1">mdi-calendar-blank</v-icon>
              <div class="text-body-2 text-medium-emphasis mt-2 mb-3">
                No appointments on record.
              </div>
              <v-btn color="primary" variant="tonal" rounded="lg" size="small"
                     :to="newAppointmentLink" prepend-icon="mdi-plus">Book Appointment</v-btn>
            </div>
            <v-timeline v-else density="compact" align="start" class="pa-2">
              <v-timeline-item v-for="appt in appointments" :key="appt.id"
                               :dot-color="apptColor(appt.status)" size="x-small" width="100%">
                <div class="d-flex align-center flex-wrap ga-2">
                  <div class="font-weight-medium">{{ appt.doctor_name || appt.doctor || 'Doctor' }}</div>
                  <v-chip size="x-small" variant="tonal" :color="apptColor(appt.status)"
                          class="text-capitalize">{{ appt.status || 'pending' }}</v-chip>
                </div>
                <div class="text-caption text-medium-emphasis">
                  {{ formatDateTime(appt.appointment_date || appt.date) }}
                  <span v-if="appt.reason"> · {{ appt.reason }}</span>
                </div>
              </v-timeline-item>
            </v-timeline>
          </v-window-item>

          <!-- ── Consultations tab ──────────────────────────────────── -->
          <v-window-item value="consultations">
            <div v-if="loadingRelated.consultations" class="text-center pa-6">
              <v-progress-circular indeterminate color="primary" size="32" />
            </div>
            <div v-else-if="!consultations.length" class="pa-6 text-center">
              <v-icon size="48" color="grey-lighten-1">mdi-medical-bag</v-icon>
              <div class="text-body-2 text-medium-emphasis mt-2 mb-3">
                No consultations on record.
              </div>
              <v-btn color="primary" variant="tonal" rounded="lg" size="small"
                     :to="newConsultationLink" prepend-icon="mdi-plus">New Consultation</v-btn>
            </div>
            <v-timeline v-else density="compact" align="start" class="pa-2">
              <v-timeline-item v-for="con in consultations" :key="con.id"
                               dot-color="primary" size="x-small" width="100%">
                <div class="font-weight-medium">
                  {{ con.doctor_name || con.doctor || 'Doctor' }}
                  <span v-if="con.chief_complaint" class="text-medium-emphasis font-weight-regular">
                    — {{ con.chief_complaint }}
                  </span>
                </div>
                <div class="text-caption text-medium-emphasis">
                  {{ formatDateTime(con.consultation_date || con.date || con.created_at) }}
                </div>
                <div v-if="con.diagnosis" class="text-body-2 mt-1">
                  <v-icon size="14" class="mr-1">mdi-clipboard-text</v-icon>{{ con.diagnosis }}
                </div>
              </v-timeline-item>
            </v-timeline>
          </v-window-item>

          <!-- ── Prescriptions tab ─────────────────────────────────── -->
          <v-window-item value="prescriptions">
            <div v-if="loadingRelated.prescriptions" class="text-center pa-6">
              <v-progress-circular indeterminate color="primary" size="32" />
            </div>
            <div v-else-if="!prescriptions.length" class="pa-6 text-center">
              <v-icon size="48" color="grey-lighten-1">mdi-pill</v-icon>
              <div class="text-body-2 text-medium-emphasis mt-2 mb-3">
                No prescriptions on record.
              </div>
              <v-btn color="primary" variant="tonal" rounded="lg" size="small"
                     :to="newPrescriptionLink" prepend-icon="mdi-plus">Write Prescription</v-btn>
            </div>
            <v-list v-else lines="three" class="bg-transparent">
              <template v-for="(rx, i) in prescriptions" :key="rx.id">
                <v-list-item>
                  <template #prepend>
                    <v-avatar color="primary-lighten-5" size="40">
                      <v-icon color="primary-darken-2">mdi-pill</v-icon>
                    </v-avatar>
                  </template>
                  <v-list-item-title class="font-weight-medium">
                    {{ rx.prescription_number || rx.rx_number || `Rx #${rx.id}` }}
                  </v-list-item-title>
                  <v-list-item-subtitle>
                    {{ formatDateTime(rx.prescribed_date || rx.date || rx.created_at) }}
                    <span v-if="rx.doctor_name"> · {{ rx.doctor_name }}</span>
                  </v-list-item-subtitle>
                  <v-list-item-subtitle v-if="rx.medications || rx.items">
                    {{ (rx.medications || rx.items || []).length }} medication(s)
                  </v-list-item-subtitle>
                  <template #append>
                    <v-chip v-if="rx.status" size="x-small" variant="tonal" color="primary"
                            class="text-capitalize">{{ rx.status }}</v-chip>
                  </template>
                </v-list-item>
                <v-divider v-if="i < prescriptions.length - 1" />
              </template>
            </v-list>
          </v-window-item>

          <!-- ── Lab Orders tab ─────────────────────────────────────── -->
          <v-window-item value="labs">
            <div v-if="loadingRelated.labs" class="text-center pa-6">
              <v-progress-circular indeterminate color="primary" size="32" />
            </div>
            <div v-else-if="!labOrders.length" class="pa-6 text-center">
              <v-icon size="48" color="grey-lighten-1">mdi-microscope</v-icon>
              <div class="text-body-2 text-medium-emphasis mt-2 mb-3">
                No lab orders on record.
              </div>
              <v-btn color="primary" variant="tonal" rounded="lg" size="small"
                     :to="newLabLink" prepend-icon="mdi-plus">Order Lab Test</v-btn>
            </div>
            <v-list v-else lines="two" class="bg-transparent">
              <template v-for="(lab, i) in labOrders" :key="lab.id">
                <v-list-item>
                  <template #prepend>
                    <v-avatar color="teal-lighten-5" size="40">
                      <v-icon color="teal-darken-2">mdi-microscope</v-icon>
                    </v-avatar>
                  </template>
                  <v-list-item-title class="font-weight-medium">
                    {{ lab.order_number || lab.test_name || `Lab #${lab.id}` }}
                  </v-list-item-title>
                  <v-list-item-subtitle>
                    {{ formatDateTime(lab.order_date || lab.created_at) }}
                    <span v-if="lab.tests"> · {{ lab.tests }}</span>
                  </v-list-item-subtitle>
                  <template #append>
                    <v-chip v-if="lab.status" size="x-small" variant="tonal" color="teal"
                            class="text-capitalize">{{ lab.status }}</v-chip>
                  </template>
                </v-list-item>
                <v-divider v-if="i < labOrders.length - 1" />
              </template>
            </v-list>
          </v-window-item>

          <!-- ── Invoices tab ────────────────────────────────────────── -->
          <v-window-item value="invoices">
            <div v-if="loadingRelated.invoices" class="text-center pa-6">
              <v-progress-circular indeterminate color="primary" size="32" />
            </div>
            <div v-else-if="!invoices.length" class="pa-6 text-center">
              <v-icon size="48" color="grey-lighten-1">mdi-receipt-text</v-icon>
              <div class="text-body-2 text-medium-emphasis mt-2 mb-3">
                No invoices on record.
              </div>
              <v-btn color="primary" variant="tonal" rounded="lg" size="small"
                     :to="newInvoiceLink" prepend-icon="mdi-plus">Create Invoice</v-btn>
            </div>
            <v-list v-else lines="two" class="bg-transparent">
              <template v-for="(inv, i) in invoices" :key="inv.id">
                <v-list-item>
                  <template #prepend>
                    <v-avatar :color="inv.status === 'paid' ? 'green-lighten-5' : 'orange-lighten-5'" size="40">
                      <v-icon :color="inv.status === 'paid' ? 'green-darken-2' : 'orange-darken-2'"
                              >mdi-receipt-text</v-icon>
                    </v-avatar>
                  </template>
                  <v-list-item-title class="font-weight-medium">
                    {{ inv.invoice_number || `Invoice #${inv.id}` }}
                  </v-list-item-title>
                  <v-list-item-subtitle>
                    {{ formatDateTime(inv.invoice_date || inv.date || inv.created_at) }}
                    <span v-if="inv.amount"> · {{ formatMoney(inv.amount) }}</span>
                    <span v-if="inv.balance != null"> · Balance: {{ formatMoney(inv.balance) }}</span>
                  </v-list-item-subtitle>
                  <template #append>
                    <v-chip :color="inv.status === 'paid' ? 'green' : 'orange'"
                            size="x-small" variant="tonal" class="text-capitalize">
                      {{ inv.status || 'unpaid' }}
                    </v-chip>
                  </template>
                </v-list-item>
                <v-divider v-if="i < invoices.length - 1" />
              </template>
            </v-list>
          </v-window-item>
        </v-window>
      </v-card>
    </template>

    <!-- ── Delete confirmation dialog ────────────────────────────── -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Delete Patient</v-card-title>
        <v-card-text>
          <div class="d-flex align-center mb-3">
            <v-avatar color="error-lighten-5" size="40" class="mr-3">
              <v-icon color="error">mdi-delete-alert</v-icon>
            </v-avatar>
            <div>
              Are you sure you want to delete
              <strong>{{ displayName }}</strong>?
              <div class="text-caption text-medium-emphasis mt-1">
                Patient #{{ patient?.patient_number || '—' }} — This action cannot be undone.
              </div>
            </div>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" :loading="deleting" @click="performDelete">
            Delete
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate, formatDateTime, formatMoney } from '~/utils/format'

const route = useRoute()
const router = useRouter()
const { $api } = useNuxtApp()

const id = computed(() => route.params.id)
const ns = computed(() => route.path.startsWith('/hos') ? '/hos' : route.path.startsWith('/clinics') ? '/clinics' : '')

const basePatients = computed(() => `${ns.value}/patients`)
const baseAppointments = computed(() => `${ns.value}/appointments`)
const baseConsultations = computed(() => `${ns.value}/consultations`)
const basePrescriptions = computed(() => `${ns.value}/prescriptions`)
const baseLabOrders = computed(() => `${ns.value}/lab-orders`)
const baseInvoices = computed(() => `${ns.value}/invoices`)

const backPath = computed(() => basePatients.value)
const editPath = computed(() => `${basePatients.value}/${id.value}/edit`)
const newAppointmentLink = computed(() => `${baseAppointments.value}/new?patient=${id.value}`)
const newConsultationLink = computed(() => `${baseConsultations.value}/new?patient=${id.value}`)
const newPrescriptionLink = computed(() => `${basePrescriptions.value}/new?patient=${id.value}`)
const newLabLink = computed(() => `${baseLabOrders.value}/new?patient=${id.value}`)
const newInvoiceLink = computed(() => `${baseInvoices.value}/new?patient=${id.value}`)

const r = useResource('/patients/')

const patient = ref(null)
const loading = ref(true)
const tab = ref('overview')

// Related records
const appointments = ref([])
const consultations = ref([])
const prescriptions = ref([])
const labOrders = ref([])
const invoices = ref([])
const loadingRelated = reactive({
  appointments: false, consultations: false, prescriptions: false,
  labs: false, invoices: false,
})

// Delete
const deleteDialog = ref(false)
const deleting = ref(false)

// ── Computed identity ─────────────────────────────────────────────
const displayName = computed(() => {
  const p = patient.value
  if (!p) return ''
  if (p.user_name) return p.user_name
  const fn = p.user?.first_name || ''
  const ln = p.user?.last_name || ''
  return `${fn} ${ln}`.trim() || p.user_email || p.user?.email || ''
})

const patientInitials = computed(() => {
  const n = displayName.value || '?'
  const parts = n.split(/\s+/).filter(Boolean)
  if (!parts.length) return '?'
  return ((parts[0][0] || '') + (parts[1]?.[0] || '')).toUpperCase()
})

const avatarColor = computed(() => {
  const colors = ['indigo', 'teal', 'pink', 'amber-darken-2', 'cyan-darken-2', 'deep-purple', 'green-darken-1', 'orange-darken-2']
  return colors[(Number(id.value) || 0) % colors.length]
})

const age = computed(() => {
  const dob = patient.value?.date_of_birth
  if (!dob) return null
  const d = new Date(dob)
  if (isNaN(d)) return null
  const t = new Date()
  let a = t.getFullYear() - d.getFullYear()
  const m = t.getMonth() - d.getMonth()
  if (m < 0 || (m === 0 && t.getDate() < d.getDate())) a--
  return a
})

const allergies = computed(() => patient.value?.allergies || [])
const chronicConditions = computed(() => patient.value?.chronic_conditions || [])

const quickStats = computed(() => [
  { label: 'Appointments', value: appointments.value.length, icon: 'mdi-calendar', color: 'indigo',
    action: () => { tab.value = 'appointments' } },
  { label: 'Consultations', value: consultations.value.length, icon: 'mdi-medical-bag', color: 'teal',
    action: () => { tab.value = 'consultations' } },
  { label: 'Prescriptions', value: prescriptions.value.length, icon: 'mdi-pill', color: 'primary',
    action: () => { tab.value = 'prescriptions' } },
  { label: 'Invoices', value: invoices.value.length, icon: 'mdi-receipt-text', color: 'green',
    action: () => { tab.value = 'invoices' } },
])

// ── Load patient + related ────────────────────────────────────────
onMounted(async () => {
  loading.value = true
  try {
    const data = await r.get(id.value)
    patient.value = data
    // Load related records in parallel
    loadRelated()
  } catch {
    patient.value = null
  } finally {
    loading.value = false
  }
})

async function loadRelated() {
  const pid = id.value
  const safe = async (url, target, label) => {
    loadingRelated[label] = true
    try {
      const { data } = await $api.get(url, { params: { patient: pid, page_size: 50 } })
      if (Array.isArray(data)) target.value = data
      else target.value = data?.results || []
    } catch { target.value = [] }
    finally { loadingRelated[label] = false }
  }
  // Fire all in parallel
  safe('/appointments/', appointments, 'appointments')
  safe('/consultations/', consultations, 'consultations')
  safe('/prescriptions/', prescriptions, 'prescriptions')
  safe('/lab-orders/', labOrders, 'labs')
  safe('/invoices/', invoices, 'invoices')
}

// ── Helpers ────────────────────────────────────────────────────────
function formatSource(s) {
  if (!s) return '—'
  return s.replace(/_/g, ' ')
}

function apptColor(status) {
  const map = {
    confirmed: 'success', completed: 'primary', cancelled: 'error',
    pending: 'warning', scheduled: 'info', no_show: 'grey',
  }
  return map[status] || 'grey'
}

function confirmDelete() {
  deleteDialog.value = true
}

async function performDelete() {
  deleting.value = true
  try {
    await r.remove(id.value)
    router.push(backPath.value)
  } catch {
    // stay on page
  } finally {
    deleting.value = false
  }
}
</script>

<style scoped>
.patient-banner {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.tab-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  overflow: hidden;
}
.qa-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  cursor: pointer;
  transition: box-shadow 150ms ease, transform 100ms ease;
}
.qa-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.05);
}
.section-title {
  font-weight: 600;
  font-size: 0.875rem;
  letter-spacing: 0.5px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.6);
}
.border-t { border-top: 1px solid rgba(var(--v-theme-on-surface), 0.08); }
.font-monospace { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
.notes-box { white-space: pre-wrap; }
</style>