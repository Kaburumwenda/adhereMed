<template>
  <v-container fluid class="pa-3 pa-md-5">
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div>
        <h1 class="text-h5 font-weight-bold"><v-icon class="mr-1">mdi-account-group</v-icon>Radiology Staff</h1>
        <div class="text-body-2 text-medium-emphasis">Manage radiologists, technologists &amp; staff</div>
      </div>
      <div class="d-flex" style="gap:8px">
        <v-btn variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-refresh" :loading="loading" @click="load">Refresh</v-btn>
        <v-btn color="primary" variant="flat" rounded="lg" class="text-none" prepend-icon="mdi-account-plus" to="/radiology/staff/new">Add Staff</v-btn>
      </div>
    </div>

    <v-row dense class="mb-4">
      <v-col cols="6" sm="3">
        <v-card rounded="lg" class="pa-3 text-center" color="primary" variant="tonal" border>
          <div class="text-h5 font-weight-bold">{{ staff.length }}</div>
          <div class="text-caption">Total Staff</div>
        </v-card>
      </v-col>
      <v-col cols="6" sm="3">
        <v-card rounded="lg" class="pa-3 text-center" color="success" variant="tonal" border>
          <div class="text-h5 font-weight-bold">{{ staff.filter(s => s.is_active).length }}</div>
          <div class="text-caption">Active</div>
        </v-card>
      </v-col>
    </v-row>

    <v-card rounded="lg" class="pa-3 mb-4" border>
      <v-text-field v-model="search" prepend-inner-icon="mdi-magnify" label="Search staff..." density="compact" hide-details clearable variant="outlined" rounded="lg" style="max-width:300px" />
    </v-card>

    <v-card rounded="lg" border>
      <v-data-table :headers="headers" :items="staff" :search="search" :loading="loading" density="comfortable" hover items-per-page="25" class="bg-transparent">
        <template #item.name="{ item }">
          <div class="d-flex align-center">
            <v-avatar color="primary" variant="tonal" size="32" class="mr-2">
              <span class="text-caption font-weight-bold">{{ (item.first_name?.[0] || '') + (item.last_name?.[0] || '') }}</span>
            </v-avatar>
            <span class="font-weight-medium">{{ item.first_name }} {{ item.last_name }}</span>
          </div>
        </template>
        <template #item.is_active="{ item }">
          <v-chip size="x-small" :color="item.is_active ? 'success' : 'grey'" variant="tonal">{{ item.is_active ? 'Active' : 'Inactive' }}</v-chip>
        </template>
      </v-data-table>
    </v-card>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const loading = ref(false)
const staff = ref([])
const search = ref('')

const headers = [
  { title: 'Name', key: 'name' }, { title: 'Email', key: 'email' },
  { title: 'Role', key: 'role' }, { title: 'Status', key: 'is_active' },
]

async function load() {
  loading.value = true
  try {
    const res = await $api.get('/accounts/users/?page_size=500')
    staff.value = res.data?.results || res.data || []
  } catch { staff.value = [] }
  loading.value = false
}
onMounted(load)
</script>
