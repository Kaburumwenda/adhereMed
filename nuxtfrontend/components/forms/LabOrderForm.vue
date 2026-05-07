<template>
  <ResourceFormPage
    :resource="r"
    :title="loadId ? 'Edit Lab Order' : 'New Lab Order'"
    icon="mdi-microscope"
    back-path="/lab-orders"
    :load-id="loadId"
    :initial="initial"
    @saved="() => router.push('/lab-orders')"
  >
    <template #default="{ form }">
      <v-row dense>
        <v-col cols="12" sm="6">
          <v-autocomplete v-model="form.patient" :items="patients" item-title="user_email" item-value="id" label="Patient" :rules="req" />
        </v-col>
        <v-col cols="12" sm="6">
          <v-autocomplete v-model="form.test" :items="tests" item-title="name" item-value="id" label="Test" :rules="req" />
        </v-col>
        <v-col cols="12" sm="6">
          <v-select v-model="form.priority" :items="['routine','urgent','stat']" label="Priority" />
        </v-col>
        <v-col cols="12" sm="6">
          <v-select v-model="form.status" :items="['ordered','collected','resulted','cancelled']" label="Status" />
        </v-col>
        <v-col cols="12"><v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow /></v-col>
        <v-col cols="12"><v-textarea v-model="form.results" label="Results" rows="3" auto-grow /></v-col>
      </v-row>
    </template>
  </ResourceFormPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
const route = useRoute(); const router = useRouter()
const { $api } = useNuxtApp()
const loadId = computed(() => route.params.id || null)
const r = useResource('/lab/orders/')
const req = [v => !!v || 'Required']
const initial = { patient: null, test: null, priority: 'routine', status: 'ordered', notes: '', results: '' }
const patients = ref([]); const tests = ref([])
onMounted(async () => {
  const safe = (p) => $api.get(p).then(r => r.data?.results || r.data || []).catch(() => [])
  patients.value = await safe('/patients/')
  tests.value = await safe('/lab/tests/')
})
</script>
