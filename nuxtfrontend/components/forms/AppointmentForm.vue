<template>
  <ResourceFormPage
    :resource="r"
    :title="loadId ? 'Edit Appointment' : 'New Appointment'"
    icon="mdi-calendar-plus"
    back-path="/appointments"
    :load-id="loadId"
    :initial="initial"
    @saved="() => router.push('/appointments')"
  >
    <template #default="{ form }">
      <v-row dense>
        <v-col cols="12" sm="6">
          <v-autocomplete v-model="form.patient" :items="patients" item-title="user_email" item-value="id" label="Patient" :rules="req" />
        </v-col>
        <v-col cols="12" sm="6">
          <v-autocomplete v-model="form.staff" :items="staff" item-title="full_name" item-value="id" label="Doctor / Staff" />
        </v-col>
        <v-col cols="12" sm="6">
          <v-autocomplete v-model="form.department" :items="depts" item-title="name" item-value="id" label="Department" />
        </v-col>
        <v-col cols="12" sm="6">
          <v-select v-model="form.status" :items="['scheduled','confirmed','completed','cancelled','no_show']" label="Status" />
        </v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.appointment_date" label="Date" type="date" :rules="req" /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.appointment_time" label="Time" type="time" :rules="req" /></v-col>
        <v-col cols="12"><v-textarea v-model="form.reason" label="Reason" rows="2" auto-grow /></v-col>
      </v-row>
    </template>
  </ResourceFormPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'

const route = useRoute()
const router = useRouter()
const { $api } = useNuxtApp()
const loadId = computed(() => route.params.id || null)
const r = useResource('/appointments/')
const req = [v => !!v || 'Required']

const initial = { patient: null, staff: null, department: null, appointment_date: '', appointment_time: '', status: 'scheduled', reason: '' }
const patients = ref([]); const staff = ref([]); const depts = ref([])

async function loadOptions() {
  const safe = (p) => $api.get(p).then(r => r.data?.results || r.data || []).catch(() => [])
  patients.value = await safe('/patients/')
  staff.value = await safe('/accounts/staff/')
  depts.value = await safe('/departments/')
}
onMounted(loadOptions)
</script>
