<template>
  <ResourceFormPage
    :resource="r"
    :title="loadId ? 'Edit Category' : 'New Category'"
    icon="mdi-shape"
    back-path="/inventory"
    :load-id="loadId"
    :initial="initial"
    @saved="() => router.push('/inventory')"
  >
    <template #default="{ form }">
      <v-row dense>
        <v-col cols="12">
          <div class="text-caption text-medium-emphasis mb-1">CATEGORY DETAILS</div>
          <v-divider class="mb-3" />
        </v-col>
        <v-col cols="12">
          <v-text-field
            v-model="form.name"
            label="Category name"
            placeholder="e.g. Antibiotics, Painkillers, Vitamins"
            prepend-inner-icon="mdi-shape"
            variant="outlined"
            density="comfortable"
            rounded="lg"
            :rules="req"
          />
        </v-col>
        <v-col cols="12">
          <v-textarea
            v-model="form.description"
            label="Description"
            placeholder="Optional notes about this category"
            prepend-inner-icon="mdi-text"
            variant="outlined"
            density="comfortable"
            rounded="lg"
            rows="3"
            auto-grow
          />
        </v-col>
        <v-col cols="12">
          <v-alert type="info" variant="tonal" density="compact" border="start" class="mt-2">
            Categories help group related stock items together for easier filtering and reporting.
          </v-alert>
        </v-col>
      </v-row>
    </template>
  </ResourceFormPage>
</template>
<script setup>
import { useResource } from '~/composables/useResource'
const route = useRoute(); const router = useRouter()
const loadId = computed(() => route.params.id || null)
const r = useResource('/inventory/categories/')
const req = [v => !!v || 'Required']
const initial = { name: '', description: '' }
</script>
