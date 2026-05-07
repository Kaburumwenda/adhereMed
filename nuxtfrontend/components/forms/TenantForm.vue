<template>
  <ResourceFormPage :resource="r" :title="loadId ? 'Edit Tenant' : 'New Tenant'" icon="mdi-domain" back-path="/superadmin/tenants" :load-id="loadId" :initial="initial" @saved="() => router.push('/superadmin/tenants')">
    <template #default="{ form }">
      <v-row dense>
        <v-col cols="12" sm="6"><v-text-field v-model="form.name" label="Name" :rules="req" /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.schema_name" label="Schema name" :rules="req" :disabled="!!loadId" /></v-col>
        <v-col cols="12" sm="6">
          <v-select v-model="form.tenant_type" :items="['hospital','pharmacy','lab']" label="Type" :rules="req" />
        </v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.domain" label="Domain" /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.email" label="Contact email" type="email" /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model="form.phone" label="Contact phone" /></v-col>
        <v-col cols="12"><v-textarea v-model="form.address" label="Address" rows="2" auto-grow /></v-col>
        <v-col cols="12"><v-switch v-model="form.is_active" label="Active" color="primary" inset /></v-col>
      </v-row>
    </template>
  </ResourceFormPage>
</template>
<script setup>
import { useResource } from '~/composables/useResource'
const route = useRoute(); const router = useRouter()
const loadId = computed(() => route.params.id || null)
const r = useResource('/tenants/')
const req = [v => !!v || 'Required']
const initial = { name: '', schema_name: '', tenant_type: 'hospital', domain: '', email: '', phone: '', address: '', is_active: true }
</script>
