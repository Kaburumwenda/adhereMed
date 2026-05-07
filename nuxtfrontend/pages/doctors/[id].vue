<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader :title="`Dr. ${doctor?.full_name || ''}`" icon="mdi-doctor" :subtitle="doctor?.specialization_name">
      <template #actions>
        <v-btn variant="text" prepend-icon="mdi-arrow-left" to="/doctors" class="text-none">Back</v-btn>
        <v-btn color="primary" rounded="lg" class="text-none ml-2" prepend-icon="mdi-message" @click="startChat">Message</v-btn>
      </template>
    </PageHeader>

    <v-row v-if="doctor">
      <v-col cols="12" md="4">
        <v-card rounded="lg" class="pa-4 text-center">
          <v-avatar size="120" color="primary" variant="tonal" class="mb-3">
            <v-img v-if="doctor.picture" :src="doctor.picture" />
            <v-icon v-else size="64">mdi-doctor</v-icon>
          </v-avatar>
          <h2 class="text-h5 font-weight-bold">Dr. {{ doctor.full_name }}</h2>
          <div class="text-body-2 text-medium-emphasis">{{ doctor.specialization_name }}</div>
          <v-rating :model-value="doctor.rating || 0" density="compact" class="mt-2" readonly half-increments />
        </v-card>
      </v-col>
      <v-col cols="12" md="8">
        <v-card rounded="lg" class="pa-4">
          <h3 class="text-h6 font-weight-bold mb-3">About</h3>
          <p class="text-body-2 mb-4">{{ doctor.bio || '—' }}</p>
          <InfoGrid :item="doctor" :fields="[
            { key: 'qualification', label: 'Qualification' },
            { key: 'experience_years', label: 'Experience (yrs)' },
            { key: 'license_number', label: 'License #' },
            { key: 'consultation_fee', label: 'Fee', format: (v) => formatMoney(v) },
            { key: 'phone', label: 'Phone' },
            { key: 'email', label: 'Email' }
          ]" />
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
const route = useRoute()
const router = useRouter()
const { $api } = useNuxtApp()
const id = computed(() => route.params.id)
const doctor = ref(null)
onMounted(async () => {
  doctor.value = await $api.get(`/doctors/${id.value}/`).then(r => r.data).catch(() => null)
})
async function startChat() {
  try {
    const res = await $api.post('/messaging/conversations/', { recipient: doctor.value?.user })
    router.push(`/messages/${res.data.id}`)
  } catch { router.push('/messages') }
}
</script>
