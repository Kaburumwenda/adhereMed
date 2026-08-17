<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Expense Categories" subtitle="Manage expense categories" icon="mdi-shape" color="warning">
      <template #actions>
        <v-btn variant="text" to="/clinics/expenses">Back</v-btn>
        <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="dialog = true">New Category</v-btn>
      </template>
    </PageHeader>

    <v-card rounded="lg">
      <v-card-text>
        <v-text-field v-model="search" prepend-inner-icon="mdi-magnify" placeholder="Search categories…" variant="outlined" density="compact" hide-details clearable class="mb-3" />
        <v-data-table :headers="headers" :items="filteredItems" :loading="loading" density="compact" hover>
          <template #item.actions="{ item }">
            <v-btn icon="mdi-delete" size="small" variant="text" color="error" @click="confirmDelete(item)" />
          </template>
          <template #no-data>
            <div class="text-center pa-8">
              <v-icon size="64" color="grey-lighten-1">mdi-shape</v-icon>
              <div class="text-h6 mt-2">No categories yet</div>
              <v-btn color="primary" class="mt-3" @click="dialog = true">Add Category</v-btn>
            </div>
          </template>
        </v-data-table>
      </v-card-text>
    </v-card>

    <v-dialog v-model="dialog" max-width="500">
      <v-card rounded="lg">
        <v-card-title class="text-h6">New Expense Category</v-card-title>
        <v-card-text>
          <v-text-field v-model="newCategory.name" label="Name" required variant="outlined" density="compact" />
          <v-textarea v-model="newCategory.description" label="Description" variant="outlined" density="compact" rows="2" class="mt-2" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="dialog = false">Cancel</v-btn>
          <v-btn color="primary" @click="addCategory">Create</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const items = ref([])
const loading = ref(false)
const search = ref('')
const dialog = ref(false)
const newCategory = reactive({ name: '', description: '' })

const headers = [
  { title: 'Name', key: 'name' },
  { title: 'Description', key: 'description' },
  { title: 'Actions', key: 'actions', sortable: false },
]

onMounted(() => loadData())
async function loadData() {
  loading.value = true
  try {
    const { data } = await $api.get('/expenses/categories/', { params: { page_size: 1000 } })
    items.value = data?.results || data || []
  } catch { items.value = [] }
  finally { loading.value = false }
}

const filteredItems = computed(() => {
  if (!search.value) return items.value
  const q = search.value.toLowerCase()
  return items.value.filter(i => JSON.stringify(i).toLowerCase().includes(q))
})

async function addCategory() {
  try {
    await $api.post('/expenses/categories/', newCategory)
    Object.assign(newCategory, { name: '', description: '' })
    dialog.value = false
    loadData()
  } catch {}
}

const deleteDialog = ref(false)
const deleteItem = ref(null)
function confirmDelete(item) { deleteItem.value = item; deleteDialog.value = true }
async function doDelete() {
  try { await $api.delete(`/expenses/categories/${deleteItem.value.id}/`); deleteDialog.value = false; loadData() } catch {}
}
</script>
