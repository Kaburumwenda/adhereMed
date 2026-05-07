<template>
  <ResourceFormPage
    :resource="r"
    :title="loadId ? 'Edit Department' : 'New Department'"
    icon="mdi-domain"
    back-path="/departments"
    :load-id="loadId"
    :initial="initial"
    @saved="() => router.push('/departments')"
  >
    <template #default="{ form }">
      <v-row dense>
        <v-col cols="12" sm="6"><v-text-field v-model="form.name" label="Name" :rules="req" /></v-col>
        <v-col cols="12" sm="6">
          <v-autocomplete v-model="form.head" :items="staff" item-title="full_name" item-value="id" label="Head" clearable />
        </v-col>
        <v-col cols="12"><v-textarea v-model="form.description" label="Description" rows="3" auto-grow /></v-col>
        <v-col cols="12"><v-switch v-model="form.is_active" label="Active" color="primary" inset /></v-col>
      </v-row>
    </template>
  </ResourceFormPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
const route = useRoute(); const router = useRouter()
const { $api } = useNuxtApp()
const loadId = computed(() => route.params.id || null)
const r = useResource('/departments/')
const req = [v => !!v || 'Required']
const initial = { name: '', head: null, description: '', is_active: true }
const staff = ref([])
onMounted(async () => {
  staff.value = await $api.get('/accounts/staff/').then(r => r.data?.results || r.data || []).catch(() => [])
})
</script>
