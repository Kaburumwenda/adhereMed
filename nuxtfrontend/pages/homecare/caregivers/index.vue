<template>
  <ResourceListPage
    title="Caregivers"
    subtitle="Field caregivers and nurses"
    icon="mdi-account-heart"
    :resource="resource"
    :headers="headers"
    create-path="/homecare/caregivers/new"
    create-label="Add caregiver"
    :detail-path="(c) => `/homecare/caregivers/${c.id}`"
    singular="caregiver"
    empty-icon="mdi-account-off"
    empty-title="No caregivers yet"
  >
    <template #cell-name="{ item }">
      <div class="d-flex align-center">
        <v-avatar size="32" color="indigo" variant="tonal" class="mr-2">
          <v-icon icon="mdi-account-heart" />
        </v-avatar>
        <div>
          <div class="font-weight-medium">{{ item.user?.full_name || item.user?.email }}</div>
          <div class="text-caption text-medium-emphasis">{{ (item.specialties || []).join(', ') }}</div>
        </div>
      </div>
    </template>
    <template #cell-rating="{ item }">
      <v-icon icon="mdi-star" color="amber" size="16" /> {{ item.rating || 0 }}
    </template>
    <template #cell-is_available="{ item }">
      <StatusChip :status="item.is_available ? 'active' : 'closed'" :label="item.is_available ? 'Available' : 'Off duty'" />
    </template>
    <template #cell-employment_status="{ item }">
      <StatusChip :status="item.employment_status" />
    </template>
  </ResourceListPage>
</template>

<script setup>
const resource = useResource('/homecare/caregivers/')
const headers = [
  { title: 'Caregiver', key: 'name', sortable: false },
  { title: 'License', key: 'license_number' },
  { title: 'Patients', key: 'active_patients_count' },
  { title: 'Rating', key: 'rating' },
  { title: 'Visits', key: 'total_visits' },
  { title: 'Available', key: 'is_available' },
  { title: 'Status', key: 'employment_status' },
  { title: '', key: 'actions', sortable: false, align: 'end' }
]
</script>
