<template>
  <ResourceFormPage
    :resource="r"
    :title="loadId ? 'Edit Classification' : 'New Classification'"
    icon="mdi-label-multiple-outline"
    back-path="/inventory"
    :load-id="loadId"
    :initial="initial"
    @saved="() => router.push('/inventory')"
  >
    <template #default="{ form }">
      <v-row dense>
        <v-col cols="12">
          <div class="text-caption text-medium-emphasis mb-1">CLASSIFICATION DETAILS</div>
          <v-divider class="mb-3" />
        </v-col>
        <v-col cols="12">
          <v-text-field
            v-model="form.name"
            label="Classification name"
            placeholder="e.g. Routine, Emergency, Cold Chain, Controlled"
            prepend-inner-icon="mdi-label-multiple-outline"
            variant="outlined"
            density="comfortable"
            rounded="lg"
            :rules="req"
          />
          <!-- Quick-select chips -->
          <div class="d-flex flex-wrap align-center mt-2" style="gap:6px">
            <span class="text-caption text-medium-emphasis mr-1">Quick select:</span>
            <v-chip
              v-for="preset in presets"
              :key="preset.name"
              size="small"
              variant="tonal"
              :color="preset.color"
              :disabled="form.name === preset.name"
              rounded="lg"
              class="text-none"
              @click="applyPreset(form, preset)"
            >
              <v-icon start size="14">{{ preset.icon }}</v-icon>
              {{ preset.name }}
            </v-chip>
          </div>
          <!-- Short descriptions for each preset -->
          <div class="mt-2 text-body-2">
            <div
              v-for="preset in presets"
              :key="'desc-' + preset.name"
              class="d-flex align-start mb-1"
              style="gap:8px"
            >
              <v-icon :color="preset.color" size="16" class="mt-1 flex-shrink-0">{{ preset.icon }}</v-icon>
              <span>
                <strong :class="`text-${preset.color}`">{{ preset.name }}</strong>
                <span class="text-medium-emphasis"> — {{ preset.description }}</span>
              </span>
            </div>
          </div>
        </v-col>
        <v-col cols="12">
          <v-textarea
            v-model="form.description"
            label="Description"
            placeholder="Optional notes about this classification"
            prepend-inner-icon="mdi-text"
            variant="outlined"
            density="comfortable"
            rounded="lg"
            rows="3"
            auto-grow
          />
        </v-col>
        <v-col cols="12">
          <v-switch
            v-model="form.is_active"
            :label="form.is_active ? 'Active' : 'Inactive'"
            color="success"
            density="comfortable"
            inset
            hide-details
          />
        </v-col>
        <v-col cols="12">
          <v-alert type="info" variant="tonal" density="compact" border="start" class="mt-2">
            Classifications group stock items by their operational handling
            (routine supply, emergency stock, cold-chain storage, controlled
            substances, …). The default classification seeded for every
            warehouse is <strong>Routine</strong>.
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
const r = useResource('/inventory/classifications/')
const req = [v => !!v || 'Required']
const initial = { name: '', description: '', is_active: true }

const presets = [
  { name: 'Routine',      color: 'primary',  icon: 'mdi-package-variant-closed',  description: 'Standard stock items carried as part of routine inventory.' },
  { name: 'Emergency',    color: 'error',    icon: 'mdi-alert-circle-outline',    description: 'Critical stock reserved for emergency or urgent use.' },
  { name: 'Cold Chain',   color: 'info',     icon: 'mdi-snowflake',               description: 'Items requiring refrigerated or temperature-controlled storage.' },
  { name: 'Controlled',   color: 'purple',   icon: 'mdi-shield-lock-outline',     description: 'Controlled substances subject to regulatory tracking.' },
  { name: 'High Value',   color: 'warning',  icon: 'mdi-cash-lock',               description: 'High-value items requiring additional security and audit.' },
  { name: 'Hazardous',    color: 'deep-orange', icon: 'mdi-biohazard',           description: 'Hazardous materials requiring special handling and disposal.' },
  { name: 'Consumable',   color: 'success',  icon: 'mdi-paperclip',              description: 'Non-reusable consumables that are depleted with use.' },
  { name: 'Capital',      color: 'indigo',   icon: 'mdi-bank-outline',           description: 'Capital equipment or durable assets, not routinely sold.' },
  { name: 'Social',       color: 'teal',     icon: 'mdi-handshake-outline',      description: 'Items distributed through social, community, or subsidy programs.' },
]

function applyPreset(form, preset) {
  form.name = preset.name
  if (!form.description) form.description = preset.description
}
</script>
