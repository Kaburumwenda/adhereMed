<template>
  <v-container fluid class="pa-3 pa-md-5">
    <div class="d-flex align-center mb-4" style="gap:14px">
      <v-avatar color="purple" variant="tonal" rounded="lg" size="52">
        <v-icon size="28">mdi-file-document-plus</v-icon>
      </v-avatar>
      <div>
        <h1 class="text-h5 text-md-h4 font-weight-bold mb-0">New Request for Quotation</h1>
        <div class="text-body-2 text-medium-emphasis">Create an RFQ to send to multiple suppliers</div>
      </div>
    </div>

    <v-card rounded="lg" elevation="0" class="pa-5 mx-auto" style="border:1px solid rgba(0,0,0,0.06); max-width:800px">
      <v-form ref="form" @submit.prevent="save">
        <v-text-field v-model="form.title" label="Title *" variant="outlined" density="compact" rounded="lg" :rules="[v => !!v || 'Title is required']" class="mb-3" />
        <v-textarea v-model="form.description" label="Description / Requirements" variant="outlined" density="compact" rounded="lg" rows="3" class="mb-3" hide-details />

        <v-row dense>
          <v-col cols="12" sm="6">
            <v-text-field v-model="form.expected_delivery" type="date" label="Expected Delivery" variant="outlined" density="compact" rounded="lg" class="mb-3" hide-details />
          </v-col>
          <v-col cols="12" sm="6">
            <v-text-field v-model="form.response_deadline" type="date" label="Response Deadline" variant="outlined" density="compact" rounded="lg" class="mb-3" hide-details />
          </v-col>
        </v-row>

        <v-select v-model="form.branch" :items="branchOptions" item-title="label" item-value="value" label="Branch *" density="compact" variant="outlined" rounded="lg" :rules="[v => v != null || 'Branch is required']" class="mb-3" />

        <v-divider class="my-3" />
        <div class="text-subtitle-2 mb-2">Requested Items</div>
        <div v-for="(item, i) in form.items" :key="i" class="d-flex align-center mb-2" style="gap:8px">
          <v-text-field v-model="item.name" label="Item name" density="compact" variant="outlined" rounded="lg" hide-details style="flex:2" />
          <v-text-field v-model.number="item.qty" label="Qty" type="number" density="compact" variant="outlined" rounded="lg" hide-details style="flex:1" />
          <v-text-field v-model="item.unit" label="Unit" density="compact" variant="outlined" rounded="lg" hide-details style="flex:1" />
          <v-btn icon="mdi-close" variant="text" color="error" size="small" @click="form.items.splice(i, 1)" />
        </div>
        <v-btn variant="tonal" color="purple" size="small" rounded="lg" class="text-none mb-3" prepend-icon="mdi-plus" @click="form.items.push({ name: '', qty: 1, unit: '' })">Add Item</v-btn>

        <v-divider class="my-3" />
        <div class="d-flex" style="gap:8px">
          <v-btn color="purple" variant="flat" rounded="lg" class="text-none" type="submit" :loading="saving">Create RFQ</v-btn>
          <v-btn variant="text" rounded="lg" class="text-none" @click="navigateTo('/purchase-orders/rfqs')">Cancel</v-btn>
        </div>
      </v-form>
    </v-card>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useBranchStore } from '~/stores/branch'

const { $api } = useNuxtApp()
const branchStore = useBranchStore()
const saving = ref(false)

const form = ref({
  title: '',
  description: '',
  expected_delivery: '',
  response_deadline: '',
  branch: null,
  items: [{ name: '', qty: 1, unit: '' }],
})

const branchOptions = computed(() => {
  const source = branchStore.activeBranches
  const opts = []
  for (const b of source) opts.push({ label: b.name, value: b.id })
  return opts
})

async function save() {
  saving.value = true
  try {
    const { data } = await $api.post('/purchase-orders/rfqs/', form.value)
    navigateTo(`/purchase-orders/rfqs/${data.id}`)
  } catch (e) {
    console.error(e)
    alert('Failed: ' + (e?.response?.data?.detail || JSON.stringify(e?.response?.data) || e.message))
  } finally {
    saving.value = false
  }
}

onMounted(async () => { await branchStore.load() })
</script>
