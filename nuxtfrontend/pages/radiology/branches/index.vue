<template>
  <v-container fluid class="pa-3 pa-md-5">
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <h1 class="text-h5 font-weight-bold"><v-icon class="mr-1">mdi-bank</v-icon>Radiology Branches</h1>
      <v-btn color="primary" variant="flat" rounded="lg" class="text-none" prepend-icon="mdi-plus" @click="openNew">Add Branch</v-btn>
    </div>

    <v-card rounded="lg" border>
      <v-data-table :headers="headers" :items="branches" :loading="loading" density="comfortable" hover items-per-page="25" class="bg-transparent">
        <template #item.is_active="{ item }">
          <v-chip size="x-small" :color="item.is_active ? 'success' : 'grey'" variant="tonal">{{ item.is_active ? 'Active' : 'Inactive' }}</v-chip>
        </template>
        <template #item.actions="{ item }">
          <v-btn icon="mdi-pencil" size="small" variant="text" @click="edit(item)" />
        </template>
      </v-data-table>
    </v-card>

    <v-dialog v-model="dlg" max-width="500" persistent>
      <v-card rounded="lg" class="pa-5">
        <h3 class="text-h6 font-weight-bold mb-3">{{ editId ? 'Edit' : 'New' }} Branch</h3>
        <v-form ref="dlgForm" @submit.prevent="save">
          <v-text-field v-model="form.name" label="Branch Name *" :rules="req" variant="outlined" density="compact" class="mb-2" />
          <v-textarea v-model="form.address" label="Address" rows="2" auto-grow variant="outlined" density="compact" class="mb-2" />
          <v-text-field v-model="form.phone" label="Phone" variant="outlined" density="compact" class="mb-2" />
          <v-text-field v-model="form.email" label="Email" type="email" variant="outlined" density="compact" class="mb-2" />
          <v-switch v-model="form.is_active" label="Active" color="success" density="compact" />
          <div class="d-flex justify-end mt-3" style="gap:8px">
            <v-btn variant="tonal" class="text-none" @click="dlg=false">Cancel</v-btn>
            <v-btn type="submit" color="primary" variant="flat" class="text-none" :loading="saving">Save</v-btn>
          </div>
        </v-form>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const loading = ref(false)
const saving = ref(false)
const branches = ref([])
const dlg = ref(false)
const dlgForm = ref(null)
const editId = ref(null)
const req = [v => !!v || 'Required']
const form = reactive({ name: '', address: '', phone: '', email: '', is_active: true })

const headers = [
  { title: 'Name', key: 'name' }, { title: 'Phone', key: 'phone' },
  { title: 'Email', key: 'email' }, { title: 'Status', key: 'is_active' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 60 },
]

function openNew() {
  editId.value = null
  Object.assign(form, { name: '', address: '', phone: '', email: '', is_active: true })
  dlg.value = true
}

function edit(item) {
  editId.value = item.id
  Object.assign(form, { name: item.name, address: item.address, phone: item.phone, email: item.email, is_active: item.is_active })
  dlg.value = true
}

async function save() {
  const { valid } = await dlgForm.value.validate()
  if (!valid) return
  saving.value = true
  try {
    if (editId.value) await $api.patch(`/tenants/branches/${editId.value}/`, form)
    else await $api.post('/tenants/branches/', form)
    dlg.value = false; await load()
  } catch (e) { console.error(e) }
  saving.value = false
}

async function load() {
  loading.value = true
  try {
    const res = await $api.get('/tenants/branches/?page_size=100')
    branches.value = res.data?.results || res.data || []
  } catch { branches.value = [] }
  loading.value = false
}
onMounted(load)
</script>
