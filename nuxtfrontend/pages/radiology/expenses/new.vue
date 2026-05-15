<template>
  <ResourceFormPage
    :resource="r"
    title="New Expense"
    icon="mdi-cash-minus"
    back-path="/radiology/expenses"
    :initial="initial"
    @saved="() => router.push('/radiology/expenses')"
  >
    <template #default="{ form }">
      <v-row dense>
        <v-col cols="12" sm="6"><v-text-field v-model="form.date" label="Date *" type="date" :rules="req" /></v-col>
        <v-col cols="12" sm="6"><v-text-field v-model.number="form.amount" label="Amount *" type="number" :rules="req" /></v-col>
        <v-col cols="12" sm="6">
          <v-autocomplete v-model="form.category" :items="categories" item-title="name" item-value="id" label="Category" clearable />
        </v-col>
        <v-col cols="12"><v-textarea v-model="form.description" label="Description" rows="2" auto-grow /></v-col>
      </v-row>
    </template>
  </ResourceFormPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
const router = useRouter()
const { $api } = useNuxtApp()
const r = useResource('/expenses/')
const req = [v => !!v || 'Required']
const initial = { date: new Date().toISOString().slice(0, 10), amount: 0, category: null, description: '' }
const categories = ref([])
onMounted(async () => {
  try { const res = await $api.get('/expenses/categories/'); categories.value = res.data?.results || res.data || [] } catch { }
})
</script>
