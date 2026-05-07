<template>
  <ResourceFormPage
    :resource="r"
    :title="loadId ? 'Edit Unit' : 'New Unit'"
    icon="mdi-ruler"
    back-path="/inventory"
    :load-id="loadId"
    :initial="initial"
    @saved="() => router.push('/inventory')"
  >
    <template #default="{ form }">
      <v-row dense>
        <v-col cols="12">
          <div class="text-caption text-medium-emphasis mb-1">UNIT DETAILS</div>
          <v-divider class="mb-3" />
        </v-col>
        <v-col cols="12" sm="8">
          <v-text-field
            v-model="form.name"
            label="Name"
            placeholder="e.g. Tablets, Capsules, Millilitres"
            prepend-inner-icon="mdi-format-text"
            variant="outlined"
            density="comfortable"
            rounded="lg"
            :rules="req"
          />
        </v-col>
        <v-col cols="12" sm="4">
          <v-text-field
            v-model="form.abbreviation"
            label="Abbreviation"
            placeholder="e.g. tab, cap, ml"
            prepend-inner-icon="mdi-tag"
            variant="outlined"
            density="comfortable"
            rounded="lg"
            maxlength="10"
            counter="10"
          />
        </v-col>
        <v-col cols="12">
          <v-alert type="info" variant="tonal" density="compact" border="start" class="mt-2">
            Units describe how a stock item is measured (per tablet, per ml, per box, etc.).
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
const r = useResource('/inventory/units/')
const req = [v => !!v || 'Required']
const initial = { name: '', abbreviation: '' }
</script>
