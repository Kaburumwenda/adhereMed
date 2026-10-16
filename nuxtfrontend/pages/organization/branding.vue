<template>
  <v-container fluid class="pa-3 pa-md-5" style="max-width: 900px;">
    <PageHeader
      title="Brand Colors"
      subtitle="Customize your organization's brand colour palette"
      icon="mdi-palette"
      color="indigo"
    >
      <template #actions>
        <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-refresh" :loading="loading" @click="load">
          Reload
        </v-btn>
        <v-btn
          v-if="canEdit"
          color="primary" rounded="lg" class="text-none"
          prepend-icon="mdi-content-save" :loading="saving" :disabled="!dirty" @click="save"
        >
          Save Colors
        </v-btn>
      </template>
    </PageHeader>

    <v-alert
      v-if="!canEdit"
      type="info" variant="tonal" density="compact" rounded="lg" class="mb-4"
    >
      You have view-only access. Contact an organization admin to make changes.
    </v-alert>

    <v-alert
      v-if="errorMsg"
      type="error" variant="tonal" density="compact" rounded="lg" class="mb-4"
    >{{ errorMsg }}</v-alert>

    <!-- ── Preview card ───────────────────────────────────────────── -->
    <v-card rounded="xl" variant="outlined" class="mb-5 overflow-hidden">
      <div class="preview-hero">
        <v-avatar v-if="logoUrl" size="64" rounded="lg" class="preview-logo">
          <v-img :src="logoUrl" cover />
        </v-avatar>
        <v-avatar v-else size="64" rounded="lg" class="preview-logo" :style="{ background: brandPrimaryRaw || '#2f6dff' }">
          <v-icon size="32" color="white">mdi-office-building</v-icon>
        </v-avatar>
        <div class="preview-text">
          <div class="text-h6 font-weight-bold text-white">{{ orgName || 'Organization' }}</div>
          <div class="text-caption text-white-70">Brand Preview</div>
        </div>
      </div>
      <div class="pa-5">
        <v-row dense>
          <v-col cols="12" sm="4">
            <div class="preview-chip" :style="{ background: brandPrimaryRaw || '#2f6dff' }">
              <v-icon color="white" size="18" class="mr-2">mdi-button-cursor</v-icon>
              <span class="text-white text-body-2 font-weight-medium">Primary</span>
            </div>
          </v-col>
          <v-col cols="12" sm="4">
            <div class="preview-chip" :style="{ background: brandSecondaryRaw || '#143ce1' }">
              <v-icon color="white" size="18" class="mr-2">mdi-format-color-fill</v-icon>
              <span class="text-white text-body-2 font-weight-medium">Secondary</span>
            </div>
          </v-col>
          <v-col cols="12" sm="4">
            <div class="preview-chip" :style="{ background: brandAccentRaw || '#37d6ff' }">
              <v-icon color="white" size="18" class="mr-2">mdi-star-four-points</v-icon>
              <span class="text-white text-body-2 font-weight-medium">Accent</span>
            </div>
          </v-col>
        </v-row>
        <p class="text-caption text-medium-emphasis mt-3 mb-0">
          These colours are used in generated PDFs, reports and branded materials.
        </p>
      </div>
    </v-card>

    <!-- ── Color pickers ──────────────────────────────────────────── -->
    <v-card rounded="xl" variant="outlined" class="mb-5 overflow-hidden">
      <div class="section-header">
        <v-icon icon="mdi-palette-outline" size="20" class="mr-2" />
        <span class="text-subtitle-2 font-weight-bold">Color Settings</span>
      </div>
      <div class="pa-5">
        <v-row dense>
          <!-- Primary -->
          <v-col cols="12" sm="4">
            <div class="color-card">
              <div class="color-swatch" :style="{ background: brandPrimaryRaw || '#2f6dff' }" @click="pickPrimary">
                <v-icon color="white" size="28">mdi-eyedropper</v-icon>
                <input ref="primaryInput" type="color" v-model="brandPrimaryRaw" class="color-hidden-input" />
              </div>
              <div class="text-body-2 font-weight-bold mt-2">Primary color</div>
              <div class="text-caption text-medium-emphasis">Main brand colour</div>
              <v-text-field
                v-model="brandPrimaryRaw" density="compact" variant="outlined" rounded="lg"
                hide-details class="mt-2" prepend-inner-icon="mdi-pound" placeholder="#2f6dff"
                :disabled="!canEdit"
                @update:model-value="onHexInput('primary', $event)"
              />
            </div>
          </v-col>
          <!-- Secondary -->
          <v-col cols="12" sm="4">
            <div class="color-card">
              <div class="color-swatch" :style="{ background: brandSecondaryRaw || '#143ce1' }" @click="pickSecondary">
                <v-icon color="white" size="28">mdi-eyedropper</v-icon>
                <input ref="secondaryInput" type="color" v-model="brandSecondaryRaw" class="color-hidden-input" />
              </div>
              <div class="text-body-2 font-weight-bold mt-2">Secondary color</div>
              <div class="text-caption text-medium-emphasis">Deep / gradient colour</div>
              <v-text-field
                v-model="brandSecondaryRaw" density="compact" variant="outlined" rounded="lg"
                hide-details class="mt-2" prepend-inner-icon="mdi-pound" placeholder="#143ce1"
                :disabled="!canEdit"
                @update:model-value="onHexInput('secondary', $event)"
              />
            </div>
          </v-col>
          <!-- Accent -->
          <v-col cols="12" sm="4">
            <div class="color-card">
              <div class="color-swatch" :style="{ background: brandAccentRaw || '#37d6ff' }" @click="pickAccent">
                <v-icon color="white" size="28">mdi-eyedropper</v-icon>
                <input ref="accentInput" type="color" v-model="brandAccentRaw" class="color-hidden-input" />
              </div>
              <div class="text-body-2 font-weight-bold mt-2">Accent color</div>
              <div class="text-caption text-medium-emphasis">Highlights / accents</div>
              <v-text-field
                v-model="brandAccentRaw" density="compact" variant="outlined" rounded="lg"
                hide-details class="mt-2" prepend-inner-icon="mdi-pound" placeholder="#37d6ff"
                :disabled="!canEdit"
                @update:model-value="onHexInput('accent', $event)"
              />
            </div>
          </v-col>
        </v-row>

        <!-- ── Preset palettes ──────────────────────────────────────── -->
        <div class="mt-6">
          <div class="text-subtitle-2 font-weight-bold mb-3">Quick Presets</div>
          <div class="d-flex flex-wrap ga-3">
            <div
              v-for="preset in presets" :key="preset.name"
              class="preset-card"
              :class="{ 'preset-active': isPresetActive(preset) }"
              @click="applyPreset(preset)"
            >
              <div class="d-flex ga-1 mb-2">
                <div class="preset-dot" :style="{ background: preset.primary }" />
                <div class="preset-dot" :style="{ background: preset.secondary }" />
                <div class="preset-dot" :style="{ background: preset.accent }" />
              </div>
              <div class="text-caption font-weight-medium">{{ preset.name }}</div>
            </div>
          </div>
        </div>
      </div>
    </v-card>

    <!-- ── Reset ───────────────────────────────────────────────────── -->
    <v-card rounded="xl" variant="outlined" class="overflow-hidden">
      <div class="section-header">
        <v-icon icon="mdi-undo-variant" size="20" class="mr-2" />
        <span class="text-subtitle-2 font-weight-bold">Reset to Default</span>
      </div>
      <div class="pa-5 d-flex align-center">
        <p class="text-body-2 text-medium-emphasis mb-0 flex-grow-1">
          Restore the default AdhereMed brand colours.
        </p>
        <v-btn
          v-if="canEdit"
          variant="tonal" color="error" rounded="lg" class="text-none"
          prepend-icon="mdi-restore" :disabled="!hasAnyColor" @click="resetColors"
        >
          Reset
        </v-btn>
      </div>
    </v-card>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000" rounded="lg">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'
import { useBranding } from '~/composables/useBranding'

const auth = useAuthStore()
const { $api } = useNuxtApp()
// The app tints its chrome with the palette below, so invalidate that cache
// whenever a new palette is saved. See composables/useBranding.js.
const brand = useBranding()

const ADMIN_EDIT_ROLES = new Set([
  'super_admin', 'tenant_admin', 'clinic_admin', 'hospital_admin',
  'pharmacy_admin', 'lab_admin', 'radiology_admin', 'homecare_admin',
  'inventory_admin', 'admin',
])
const canEdit = computed(() => ADMIN_EDIT_ROLES.has(auth.role))

const DEFAULTS = {
  primary: '#2f6dff',
  secondary: '#143ce1',
  accent: '#37d6ff',
}

const presets = [
  { name: 'AdhereMed',  primary: '#2f6dff', secondary: '#143ce1', accent: '#37d6ff' },
  { name: 'Teal',       primary: '#0D9488', secondary: '#0F766E', accent: '#5EEAD4' },
  { name: 'Indigo',     primary: '#4F46E5', secondary: '#3730A3', accent: '#818CF8' },
  { name: 'Rose',       primary: '#DB2777', secondary: '#9D174D', accent: '#F9A8D4' },
  { name: 'Emererald',  primary: '#16A34A', secondary: '#15803D', accent: '#86EFAC' },
  { name: 'Sunset',     primary: '#F97316', secondary: '#C2410C', accent: '#FED7AA' },
]

const loading = ref(false)
const saving = ref(false)
const errorMsg = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const orgName = ref('')
const logoUrl = ref('')

const brandPrimaryRaw = ref(DEFAULTS.primary)
const brandSecondaryRaw = ref(DEFAULTS.secondary)
const brandAccentRaw = ref(DEFAULTS.accent)

let snapshot = ''

const hasAnyColor = computed(() =>
  brandPrimaryRaw.value !== DEFAULTS.primary ||
  brandSecondaryRaw.value !== DEFAULTS.secondary ||
  brandAccentRaw.value !== DEFAULTS.accent
)

const dirty = computed(() =>
  JSON.stringify({
    primary: brandPrimaryRaw.value,
    secondary: brandSecondaryRaw.value,
    accent: brandAccentRaw.value,
  }) !== snapshot
)

const primaryInput = ref(null)
const secondaryInput = ref(null)
const accentInput = ref(null)

function pickPrimary() { primaryInput.value?.click() }
function pickSecondary() { secondaryInput.value?.click() }
function pickAccent() { accentInput.value?.click() }

function onHexInput(which, val) {
  // Ensure hex format
  const normalized = normalizeHex(val)
  if (normalized) {
    if (which === 'primary') brandPrimaryRaw.value = normalized
    else if (which === 'secondary') brandSecondaryRaw.value = normalized
    else if (which === 'accent') brandAccentRaw.value = normalized
  }
}

function normalizeHex(v) {
  if (!v) return ''
  let s = v.trim()
  if (!s.startsWith('#')) s = '#' + s
  if (/^#[0-9A-Fa-f]{6}$/.test(s)) return s.toLowerCase()
  return ''
}

function applyPreset(preset) {
  if (!canEdit.value) return
  brandPrimaryRaw.value = preset.primary
  brandSecondaryRaw.value = preset.secondary
  brandAccentRaw.value = preset.accent
}

function isPresetActive(preset) {
  return brandPrimaryRaw.value.toLowerCase() === preset.primary &&
         brandSecondaryRaw.value.toLowerCase() === preset.secondary &&
         brandAccentRaw.value.toLowerCase() === preset.accent
}

function resetColors() {
  brandPrimaryRaw.value = DEFAULTS.primary
  brandSecondaryRaw.value = DEFAULTS.secondary
  brandAccentRaw.value = DEFAULTS.accent
}

async function load() {
  loading.value = true
  errorMsg.value = ''
  try {
    const { data } = await $api.get('/tenants/me/')
    orgName.value = data.name || ''
    logoUrl.value = data.logo || null
    brandPrimaryRaw.value = data.brand_primary || DEFAULTS.primary
    brandSecondaryRaw.value = data.brand_secondary || DEFAULTS.secondary
    brandAccentRaw.value = data.brand_accent || DEFAULTS.accent
    snapshot = JSON.stringify({
      primary: brandPrimaryRaw.value,
      secondary: brandSecondaryRaw.value,
      accent: brandAccentRaw.value,
    })
  } catch (e) {
    errorMsg.value = e?.response?.data?.detail || 'Failed to load brand settings.'
  } finally {
    loading.value = false
  }
}

async function save() {
  saving.value = true
  errorMsg.value = ''
  try {
    const payload = {
      brand_primary: brandPrimaryRaw.value,
      brand_secondary: brandSecondaryRaw.value,
      brand_accent: brandAccentRaw.value,
    }
    const { data } = await $api.patch('/tenants/me/', payload)
    brandPrimaryRaw.value = data.brand_primary || DEFAULTS.primary
    brandSecondaryRaw.value = data.brand_secondary || DEFAULTS.secondary
    brandAccentRaw.value = data.brand_accent || DEFAULTS.accent
    snapshot = JSON.stringify({
      primary: brandPrimaryRaw.value,
      secondary: brandSecondaryRaw.value,
      accent: brandAccentRaw.value,
    })
    // Push the new palette to the rest of the app (heroes, panels, …).
    brand.palette.value = {
      primary: brandPrimaryRaw.value,
      secondary: brandSecondaryRaw.value,
      accent: brandAccentRaw.value,
    }
    brand.isLoaded.value = true
    snack.text = 'Brand colors saved successfully.'
    snack.color = 'success'
    snack.show = true
  } catch (e) {
    errorMsg.value = e?.response?.data?.detail || 'Failed to save brand colors.'
  } finally {
    saving.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.preview-hero {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 24px;
  background: linear-gradient(135deg, v-bind(brandPrimaryRaw) 0%, v-bind(brandSecondaryRaw) 100%);
  min-height: 120px;
}
.text-white-70 {
  color: rgba(255, 255, 255, 0.7);
}
.preview-logo {
  border: 2px solid rgba(255, 255, 255, 0.3);
  flex-shrink: 0;
}
.preview-chip {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 12px 16px;
  border-radius: 12px;
  min-height: 48px;
  text-align: center;
}
.section-header {
  padding: 14px 20px;
  display: flex;
  align-items: center;
  background: linear-gradient(135deg, rgba(var(--v-theme-primary), 0.10), rgba(var(--v-theme-primary), 0.03));
  color: rgb(var(--v-theme-primary));
}
.color-card {
  text-align: center;
  padding: 12px;
  border: 1px solid rgba(0, 0, 0, 0.08);
  border-radius: 16px;
  transition: border-color 0.2s;
}
.color-card:hover {
  border-color: rgba(var(--v-theme-primary), 0.4);
}
.color-swatch {
  width: 100%;
  height: 80px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: transform 0.15s;
  position: relative;
}
.color-swatch:hover {
  transform: scale(1.03);
}
.color-hidden-input {
  position: absolute;
  opacity: 0;
  width: 0;
  height: 0;
  pointer-events: none;
}
.preset-card {
  width: 110px;
  padding: 10px;
  border: 2px solid transparent;
  border-radius: 12px;
  cursor: pointer;
  text-align: center;
  background: rgba(0, 0, 0, 0.02);
  transition: all 0.2s;
}
.preset-card:hover {
  background: rgba(0, 0, 0, 0.05);
}
.preset-active {
  border-color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.08);
}
.preset-dot {
  width: 20px;
  height: 20px;
  border-radius: 50%;
  border: 1px solid rgba(255, 255, 255, 0.3);
}
</style>
