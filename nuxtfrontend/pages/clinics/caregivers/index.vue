<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Caregivers" subtitle="Patient caregiver assignments"
      icon="mdi-account-heart" color="pink">
      <template #actions>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
          :loading="r.loading.value" @click="r.list({ page_size: 1000 })">Refresh</v-btn>
        <v-btn color="pink" rounded="lg" class="text-none" prepend-icon="mdi-plus"
          @click="navigateTo(`${ns}/caregivers/new`)">New Caregiver</v-btn>
      </template>
    </PageHeader>

    <!-- ── Filter bar ────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="filter-bar mb-3 pa-3">
      <v-text-field v-model="r.search.value" prepend-inner-icon="mdi-magnify"
        placeholder="Search by patient, caregiver, phone…"
        variant="outlined" density="compact" hide-details clearable />
    </v-card>

    <!-- ── Results ───────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="results-card">
      <div v-if="r.loading.value" class="d-flex justify-center pa-12">
        <v-progress-circular indeterminate color="pink" size="48" />
      </div>

      <!-- Empty state -->
      <div v-else-if="!r.filtered.value.length" class="pa-10 text-center">
        <v-icon size="64" color="grey-lighten-1">mdi-account-heart</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-3">No caregivers found</div>
        <div class="text-body-2 text-medium-emphasis mb-4">
          {{ r.search.value ? 'Try adjusting your search.' : 'Assign a caregiver to a patient to get started.' }}
        </div>
        <v-btn v-if="!r.search.value" color="pink" rounded="lg" prepend-icon="mdi-plus"
          class="text-none" @click="navigateTo(`${ns}/caregivers/new`)">New Caregiver</v-btn>
      </div>

      <!-- Table -->
      <v-data-table v-else :headers="headers" :items="r.filtered.value"
        :items-per-page="20" item-value="id" hover
        @click:row="(_, { item }) => goTo(item.id)" class="caregivers-table">
        <template #item.patient_name="{ item }">
          <span class="font-weight-medium">{{ item.patient_name || '—' }}</span>
        </template>
        <template #item.caregiver_name="{ value }">
          <span class="font-weight-medium">{{ value || '—' }}</span>
        </template>
        <template #item.is_active="{ value }">
          <v-chip size="small" variant="tonal" :color="value ? 'success' : 'grey'">
            {{ value ? 'Active' : 'Inactive' }}
          </v-chip>
        </template>
        <template #item.assigned_date="{ value }">{{ formatDate(value) }}</template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end" @click.stop>
            <v-btn icon="mdi-eye" variant="text" size="small"
              @click="goTo(item.id)" />
            <v-btn icon="mdi-pencil" variant="text" size="small"
              @click="navigateTo(`${ns}/caregivers/${item.id}/edit`)" />
            <v-btn icon="mdi-delete" variant="text" size="small" color="error"
              @click="confirmDelete(item)" />
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- ── Delete dialog ─────────────────────────────────────────── -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Delete Caregiver?</v-card-title>
        <v-card-text>
          <div class="d-flex align-center mb-3">
            <v-avatar color="error-lighten-5" size="40" class="mr-3">
              <v-icon color="error">mdi-delete-alert</v-icon>
            </v-avatar>
            <div>
              Are you sure you want to delete the caregiver assignment for
              <strong>{{ deleteTarget?.patient_name || '—' }}</strong>?
              <div class="text-caption text-medium-emphasis mt-1">This action cannot be undone.</div>
            </div>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" :loading="deleting" @click="performDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Snackbar ─────────────────────────────────────────────── -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate } from '~/utils/format'

const ns = '/clinics'

const r = useResource('/homecare/caregivers/')
onMounted(() => r.list({ page_size: 1000 }))

const headers = [
  { title: 'Patient', key: 'patient_name', sortable: false },
  { title: 'Caregiver', key: 'caregiver_name', sortable: false },
  { title: 'Relationship', key: 'relationship', sortable: false },
  { title: 'Phone', key: 'phone', sortable: false },
  { title: 'Status', key: 'is_active', sortable: false, width: 100 },
  { title: 'Assigned', key: 'assigned_date', width: 120 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 130 },
]

const snack = reactive({ show: false, color: 'success', text: '' })
const deleting = ref(false)
const deleteDialog = ref(false)
const deleteTarget = ref(null)

function goTo(id) { navigateTo(`${ns}/caregivers/${id}`) }

function confirmDelete(item) { deleteTarget.value = item; deleteDialog.value = true }

async function performDelete() {
  if (!deleteTarget.value) return
  deleting.value = true
  try {
    await r.remove(deleteTarget.value.id)
    snack.text = 'Caregiver deleted'
    snack.color = 'success'
    snack.show = true
    deleteDialog.value = false
    deleteTarget.value = null
  } catch {
    snack.text = r.error.value || 'Failed to delete caregiver'
    snack.color = 'error'
    snack.show = true
  } finally {
    deleting.value = false
  }
}
</script>

<style scoped>
.filter-bar { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.results-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); overflow: hidden; }
.caregivers-table :deep(tbody tr) { cursor: pointer; }
</style>
