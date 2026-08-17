<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="New Expense" subtitle="Record a new expense" icon="mdi-cash-minus" color="warning">
      <template #actions>
        <v-btn variant="text" to="/clinics/expenses">Cancel</v-btn>
        <v-btn color="primary" :loading="r.saving.value" @click="save">Save</v-btn>
      </template>
    </PageHeader>

    <v-alert v-if="r.error.value" type="error" variant="tonal" class="mb-4">{{ r.error.value }}</v-alert>

    <v-card rounded="lg" max-width="700">
      <v-card-text>
        <v-form>
          <v-text-field v-model="form.description" label="Description" required variant="outlined" density="compact" class="mb-3" />
          <v-select v-model="form.category" :items="['utilities','supplies','salaries','rent','equipment','maintenance','other']" label="Category" required variant="outlined" density="compact" class="mb-3" />
          <v-text-field v-model="form.amount" label="Amount (KES)" type="number" required variant="outlined" density="compact" class="mb-3" />
          <v-text-field v-model="form.expense_date" type="date" label="Date" variant="outlined" density="compact" class="mb-3" />
          <v-textarea v-model="form.notes" label="Notes" variant="outlined" density="compact" rows="2" />
        </v-form>
      </v-card-text>
    </v-card>
  </v-container>
</template>

<script setup>
const router = useRouter()
const r = useResource('/expenses/')

const form = reactive({
  description: '',
  category: '',
  amount: 0,
  expense_date: new Date().toISOString().slice(0, 10),
  notes: '',
})

async function save() {
  try {
    await r.create(form)
    router.push('/clinics/expenses')
  } catch {}
}
</script>
