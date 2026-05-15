<template>
  <ResourceFormPage
    :resource="r"
    title="Edit Template"
    icon="mdi-printer-pos"
    back-path="/radiology/report-templates"
    :load-id="loadId"
    :initial="initial"
    @saved="() => router.push('/radiology/report-templates')"
  >
    <template #default="{ form }">
      <v-row dense>
        <v-col cols="12" sm="6"><v-text-field v-model="form.name" label="Template Name *" :rules="req" /></v-col>
        <v-col cols="12" sm="6"><v-select v-model="form.modality_type" :items="modalityTypes" label="Modality Type" clearable /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.body_region" label="Body Region" /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.signatory_name" label="Signatory Name" /></v-col>
        <v-col cols="12"><v-textarea v-model="form.template_body" label="Template Body *" rows="6" auto-grow :rules="req" /></v-col>
        <v-col cols="12" sm="6"><v-textarea v-model="form.header_html" label="Header HTML" rows="2" auto-grow /></v-col>
        <v-col cols="12" sm="6"><v-textarea v-model="form.footer_html" label="Footer HTML" rows="2" auto-grow /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.signatory_title" label="Signatory Title" /></v-col>
        <v-col cols="12" sm="6"><v-switch v-model="form.is_active" label="Active" color="success" /></v-col>
      </v-row>
    </template>
  </ResourceFormPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
const route = useRoute(); const router = useRouter()
const loadId = computed(() => route.params.id)
const r = useResource('/radiology/report-templates/')
const req = [v => !!v || 'Required']
const modalityTypes = ['xray', 'ct', 'mri', 'ultrasound', 'mammogram', 'fluoroscopy', 'pet_ct', 'dexa', 'other']
const initial = { name: '', modality_type: '', body_region: '', template_body: '', header_html: '', footer_html: '', signatory_name: '', signatory_title: '', is_active: true }
</script>
