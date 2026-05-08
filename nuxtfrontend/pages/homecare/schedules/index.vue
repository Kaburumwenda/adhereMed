<template>
  <ResourceListPage
    title="Schedules"
    subtitle="Caregiver visits and shifts"
    icon="mdi-calendar-clock"
    :resource="resource"
    :headers="headers"
    singular="schedule"
    empty-icon="mdi-calendar-blank"
    empty-title="No schedules yet"
  >
    <template #create-action>
      <v-btn color="teal" rounded="lg" class="text-none" prepend-icon="mdi-plus" @click="openDialog()">New schedule</v-btn>
    </template>
    <template #cell-when="{ item }">
      <div class="font-weight-medium">{{ formatRange(item.start_at, item.end_at) }}</div>
      <div class="text-caption text-medium-emphasis">{{ item.shift_type }}</div>
    </template>
    <template #cell-status="{ item }"><StatusChip :status="item.status" /></template>
    <template #actions="{ item }">
      <v-btn v-if="item.status === 'scheduled'" size="small" color="teal" variant="text"
             prepend-icon="mdi-login-variant" @click="action(item.id, 'check_in')">Check-in</v-btn>
      <v-btn v-if="item.status === 'checked_in'" size="small" color="success" variant="text"
             prepend-icon="mdi-logout-variant" @click="action(item.id, 'check_out')">Check-out</v-btn>
    </template>
  </ResourceListPage>

  <v-dialog v-model="dialog" max-width="600">
    <v-card rounded="xl">
      <v-card-title>New schedule</v-card-title>
      <v-card-text>
        <v-row>
          <v-col cols="12" md="6">
            <v-select v-model="form.caregiver" :items="caregivers" item-title="name" item-value="id" label="Caregiver" />
          </v-col>
          <v-col cols="12" md="6">
            <v-select v-model="form.patient" :items="patients" item-title="name" item-value="id" label="Patient" />
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.start_at" label="Start" type="datetime-local" />
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field v-model="form.end_at" label="End" type="datetime-local" />
          </v-col>
          <v-col cols="12" md="6">
            <v-select v-model="form.shift_type" :items="['visit','overnight','live_in','on_call']" label="Shift type" />
          </v-col>
          <v-col cols="12"><v-textarea v-model="form.notes" label="Notes" rows="2" /></v-col>
        </v-row>
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn variant="text" @click="dialog = false">Cancel</v-btn>
        <v-btn color="teal" :loading="saving" @click="save">Save</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>
<script setup>
const { $api } = useNuxtApp()
const resource = useResource('/homecare/schedules/')
const headers = [
  { title: 'When', key: 'when', sortable: false },
  { title: 'Caregiver', key: 'caregiver_name' },
  { title: 'Patient', key: 'patient_name' },
  { title: 'Status', key: 'status' },
  { title: '', key: 'actions', sortable: false, align: 'end' }
]
const dialog = ref(false)
const saving = ref(false)
const form = reactive({ caregiver: null, patient: null, start_at: '', end_at: '', shift_type: 'visit', notes: '' })
const caregivers = ref([])
const patients = ref([])
function formatRange(a, b) {
  const f = (i) => i ? new Date(i).toLocaleString([], { dateStyle: 'short', timeStyle: 'short' }) : ''
  return `${f(a)} – ${f(b).split(', ')[1] || f(b)}`
}
async function action(id, verb) {
  await $api.post(`/homecare/schedules/${id}/${verb}/`)
  resource.list()
}
async function openDialog() {
  dialog.value = true
  if (!caregivers.value.length) {
    const { data: cs } = await $api.get('/homecare/caregivers/')
    caregivers.value = (cs?.results || cs || []).map(c => ({ id: c.id, name: c.user?.full_name || c.user?.email }))
  }
  if (!patients.value.length) {
    const { data: ps } = await $api.get('/homecare/patients/')
    patients.value = (ps?.results || ps || []).map(p => ({ id: p.id, name: p.patient_name || p.user?.full_name }))
  }
}
async function save() {
  saving.value = true
  try {
    await resource.create(form)
    dialog.value = false
    resource.list()
  } finally { saving.value = false }
}
</script>
