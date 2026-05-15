<template>
  <v-container fluid class="pa-3 pa-md-5">
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <h1 class="text-h5 font-weight-bold">New QC Record</h1>
      <v-btn variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left" to="/radiology/qc">Back</v-btn>
    </div>

    <v-form ref="formRef" @submit.prevent="submit">
      <v-card rounded="lg" class="pa-5 mb-4" border>
        <v-row dense>
          <v-col cols="12" sm="6">
            <v-autocomplete v-model="form.modality" :items="modalities" item-title="name" item-value="id" label="Modality *" :rules="req" variant="outlined" density="compact" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-text-field v-model="form.qc_date" label="QC Date *" type="date" :rules="req" variant="outlined" density="compact" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-select v-model="form.status" :items="statusOpts" label="Status *" :rules="req" variant="outlined" density="compact" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-text-field v-model.number="form.dose_output" label="Dose Output" type="number" step="0.001" variant="outlined" density="compact" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-text-field v-model.number="form.image_quality_score" label="Image Quality Score" type="number" step="0.01" variant="outlined" density="compact" />
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="form.notes" label="Notes" rows="3" auto-grow variant="outlined" density="compact" />
          </v-col>
        </v-row>
      </v-card>
      <div class="d-flex justify-end" style="gap:8px">
        <v-btn variant="tonal" rounded="lg" class="text-none" to="/radiology/qc">Cancel</v-btn>
        <v-btn type="submit" color="primary" variant="flat" rounded="lg" class="text-none" :loading="saving">Save</v-btn>
      </div>
    </v-form>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const router = useRouter()
const formRef = ref(null)
const saving = ref(false)
const req = [v => !!v || 'Required']
const modalities = ref([])
const statusOpts = [{ title: 'Pass', value: 'pass' }, { title: 'Warning', value: 'warn' }, { title: 'Fail', value: 'fail' }]
const form = reactive({ modality: null, qc_date: new Date().toISOString().slice(0, 10), status: '', dose_output: null, image_quality_score: null, notes: '' })

onMounted(async () => {
  try {
    const res = await $api.get('/radiology/modalities/?page_size=200')
    modalities.value = res.data?.results || res.data || []
  } catch { }
})

async function submit() {
  const { valid } = await formRef.value.validate()
  if (!valid) return
  saving.value = true
  try {
    await $api.post('/radiology/qc/', form)
    router.push('/radiology/qc')
  } catch (e) { console.error(e) }
  saving.value = false
}
</script>
