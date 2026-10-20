<template>
  <v-container fluid class="pa-3 pa-md-5 br-page">

    <!-- ═══════════════ HERO ═══════════════
         Tinted live by the *draft* palette, so every colour change is visible
         in the chrome before it is saved. -->
    <div class="br-hero mb-4" :style="draftTheme">
      <span class="br-glow" />
      <span class="br-glow br-glow-2" />

      <div class="d-flex flex-wrap align-center justify-space-between ga-3 br-hero-top">
        <div class="d-flex align-center" style="gap:16px; min-width:0">
          <div class="br-hero-icon">
            <v-icon size="30">mdi-palette-swatch-outline</v-icon>
          </div>
          <div style="min-width:0">
            <div class="br-eyebrow">
              <v-icon size="10">mdi-circle</v-icon>
              ORGANIZATION · BRANDING
            </div>
            <h1 class="br-title">Brand colours</h1>
            <div class="br-sub">
              One palette drives every screen, PDF and report
              <span v-if="orgName"> · {{ orgName }}</span>
            </div>
          </div>
        </div>

        <div class="d-flex flex-wrap align-center ga-2">
          <v-btn
            icon="mdi-refresh"
            variant="text"
            size="small"
            class="br-hero-iconbtn"
            title="Reload from the server"
            :loading="loading"
            @click="load"
          />
          <v-btn
            v-if="canEdit"
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none br-btn-glass"
            prepend-icon="mdi-undo-variant"
            :disabled="!dirty"
            @click="revert"
          >Revert</v-btn>
          <v-btn
            v-if="canEdit"
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none br-btn-strong"
            prepend-icon="mdi-content-save"
            :loading="saving"
            :disabled="!dirty"
            @click="save"
          >Save palette</v-btn>
        </div>
      </div>

      <div class="br-hero-foot d-flex flex-wrap align-center" style="gap:8px">
        <span class="br-hero-chip">
          <span class="br-hero-dot" :style="{ background: brandPrimaryRaw }" />
          {{ brandPrimaryRaw }}
        </span>
        <span class="br-hero-chip">
          <span class="br-hero-dot" :style="{ background: brandSecondaryRaw }" />
          {{ brandSecondaryRaw }}
        </span>
        <span class="br-hero-chip">
          <span class="br-hero-dot" :style="{ background: brandAccentRaw }" />
          {{ brandAccentRaw }}
        </span>
        <span class="br-hero-chip" :class="primaryContrast.ratio >= 4.5 ? '' : 'br-hero-chip-alert'">
          <v-icon size="14">{{ primaryContrast.ratio >= 4.5 ? 'mdi-check-decagram' : 'mdi-alert-outline' }}</v-icon>
          {{ primaryContrast.ratio }}:1 on primary · {{ primaryContrast.grade }}
        </span>
        <span v-if="activePresetName" class="br-hero-chip">
          <v-icon size="14">mdi-check-circle-outline</v-icon>
          {{ activePresetName }}
        </span>
        <span v-if="dirty" class="br-hero-chip br-hero-chip-warn">
          <v-icon size="14">mdi-circle-edit-outline</v-icon>
          Unsaved changes
        </span>
      </div>
    </div>

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

    <v-row class="align-start">
      <!-- ═══════════════ LEFT: EDITOR ═══════════════ -->
      <v-col cols="12" lg="7">

    <!-- ═══════════════ PALETTE EDITOR ═══════════════ -->
    <v-card rounded="lg" elevation="0" class="br-card mb-3 overflow-hidden">
      <div class="br-section-head">
        <div class="d-flex align-center" style="gap:10px">
          <v-avatar size="32" color="primary" variant="tonal">
            <v-icon size="17">mdi-palette-outline</v-icon>
          </v-avatar>
          <div>
            <div class="br-section-title">Palette</div>
            <div class="br-section-sub">Primary · secondary · accent</div>
          </div>
        </div>
        <v-chip
          size="small"
          variant="tonal"
          :color="dirty ? 'warning' : 'success'"
          class="font-weight-bold"
        >{{ dirty ? 'Unsaved' : 'Saved' }}</v-chip>
      </div>
      <v-divider />

      <div class="pa-4">
        <v-row dense>
          <!-- Primary -->
          <v-col cols="12" sm="4">
            <div class="br-color">
              <div class="br-swatch" :style="{ background: brandPrimaryRaw }" @click="pickPrimary">
                <div class="br-swatch-ink" :style="{ color: contrastFor(brandPrimaryRaw).fg }">
                  <span class="br-swatch-initial">Aa</span>
                  <span class="br-swatch-ratio">{{ contrastFor(brandPrimaryRaw).ratio }}:1</span>
                </div>
                <span class="br-swatch-edit"><v-icon size="14">mdi-eyedropper</v-icon> Pick</span>
                <input ref="primaryInput" type="color" v-model="brandPrimaryRaw" class="color-hidden-input" />
              </div>
              <div class="d-flex align-center justify-space-between mt-2" style="gap:6px">
                <div style="min-width:0">
                  <div class="br-color-name">Primary</div>
                  <div class="br-color-role">Buttons, links, highlights</div>
                </div>
                <v-btn
                  icon="mdi-content-copy" size="x-small" variant="text"
                  title="Copy hex" @click="copyHex(brandPrimaryRaw)"
                />
              </div>
              <v-text-field
                v-model="brandPrimaryRaw" density="compact" variant="outlined" rounded="lg"
                hide-details class="mt-2" placeholder="#2f6dff"
                :disabled="!canEdit"
                @update:model-value="onHexInput('primary', $event)"
              />
            </div>
          </v-col>

          <!-- Secondary -->
          <v-col cols="12" sm="4">
            <div class="br-color">
              <div class="br-swatch" :style="{ background: brandSecondaryRaw }" @click="pickSecondary">
                <div class="br-swatch-ink" :style="{ color: contrastFor(brandSecondaryRaw).fg }">
                  <span class="br-swatch-initial">Aa</span>
                  <span class="br-swatch-ratio">{{ contrastFor(brandSecondaryRaw).ratio }}:1</span>
                </div>
                <span class="br-swatch-edit"><v-icon size="14">mdi-eyedropper</v-icon> Pick</span>
                <input ref="secondaryInput" type="color" v-model="brandSecondaryRaw" class="color-hidden-input" />
              </div>
              <div class="d-flex align-center justify-space-between mt-2" style="gap:6px">
                <div style="min-width:0">
                  <div class="br-color-name">Secondary</div>
                  <div class="br-color-role">Gradient start, deep surfaces</div>
                </div>
                <v-btn
                  icon="mdi-content-copy" size="x-small" variant="text"
                  title="Copy hex" @click="copyHex(brandSecondaryRaw)"
                />
              </div>
              <v-text-field
                v-model="brandSecondaryRaw" density="compact" variant="outlined" rounded="lg"
                hide-details class="mt-2" placeholder="#143ce1"
                :disabled="!canEdit"
                @update:model-value="onHexInput('secondary', $event)"
              />
            </div>
          </v-col>

          <!-- Accent -->
          <v-col cols="12" sm="4">
            <div class="br-color">
              <div class="br-swatch" :style="{ background: brandAccentRaw }" @click="pickAccent">
                <div class="br-swatch-ink" :style="{ color: contrastFor(brandAccentRaw).fg }">
                  <span class="br-swatch-initial">Aa</span>
                  <span class="br-swatch-ratio">{{ contrastFor(brandAccentRaw).ratio }}:1</span>
                </div>
                <span class="br-swatch-edit"><v-icon size="14">mdi-eyedropper</v-icon> Pick</span>
                <input ref="accentInput" type="color" v-model="brandAccentRaw" class="color-hidden-input" />
              </div>
              <div class="d-flex align-center justify-space-between mt-2" style="gap:6px">
                <div style="min-width:0">
                  <div class="br-color-name">Accent</div>
                  <div class="br-color-role">Highlights, glows, gradient tail</div>
                </div>
                <v-btn
                  icon="mdi-content-copy" size="x-small" variant="text"
                  title="Copy hex" @click="copyHex(brandAccentRaw)"
                />
              </div>
              <v-text-field
                v-model="brandAccentRaw" density="compact" variant="outlined" rounded="lg"
                hide-details class="mt-2" placeholder="#37d6ff"
                :disabled="!canEdit"
                @update:model-value="onHexInput('accent', $event)"
              />
            </div>
          </v-col>
        </v-row>

        <!-- Gradient recipe -->
        <div class="br-gradient mt-4" :style="{ background: draftGradient }">
          <span class="br-gradient-label">Signature gradient</span>
        </div>

        <!-- Derived shades (from primary) -->
        <div class="mt-4">
          <div class="d-flex align-center justify-space-between mb-2">
            <div class="br-section-sub" style="font-weight:600">Primary scale</div>
            <span class="text-caption text-medium-emphasis">click a step to copy</span>
          </div>
          <div class="br-shades">
            <button
              v-for="s in primaryShades"
              :key="s.label"
              type="button"
              class="br-shade"
              :style="{ background: s.hex }"
              :title="`${s.label} · ${s.hex}`"
              @click="copyHex(s.hex)"
            >
              <span :style="{ color: contrastFor(s.hex).fg }">{{ s.label }}</span>
            </button>
          </div>
        </div>
      </div>
    </v-card>

    <!-- ═══════════════ HEALTHCARE PRESETS ═══════════════ -->
    <v-card rounded="lg" elevation="0" class="br-card mb-3 overflow-hidden">
      <div class="br-section-head">
        <div class="d-flex align-center" style="gap:10px">
          <v-avatar size="32" color="purple" variant="tonal">
            <v-icon size="17">mdi-medical-bag</v-icon>
          </v-avatar>
          <div>
            <div class="br-section-title">Healthcare presets</div>
            <div class="br-section-sub">{{ presets.length }} palettes tuned for clinical settings</div>
          </div>
        </div>
        <span v-if="activePresetName" class="text-caption text-medium-emphasis">
          Active: <b>{{ activePresetName }}</b>
        </span>
      </div>
      <v-divider />

      <div class="pa-4">
        <v-chip-group
          v-model="presetFilter"
          mandatory
          class="br-filter mb-3"
          @update:model-value="(v) => (presetFilter = v || 'all')"
        >
          <v-chip
            v-for="c in presetCategories"
            :key="c.value"
            :value="c.value"
            size="small"
            variant="tonal"
            class="text-none"
          >
            <v-icon start size="14">{{ c.icon }}</v-icon>
            {{ c.label }}
          </v-chip>
        </v-chip-group>

        <div class="br-presets">
          <button
            v-for="preset in filteredPresets"
            :key="preset.name"
            type="button"
            class="br-preset"
            :class="{ 'br-preset--active': isPresetActive(preset) }"
            :disabled="!canEdit"
            @click="applyPreset(preset)"
          >
            <span class="br-preset-preview" :style="{ background: `linear-gradient(120deg, ${preset.secondary}, ${preset.primary} 60%, ${preset.accent})` }">
              <v-icon v-if="isPresetActive(preset)" size="16" color="#fff">mdi-check-circle</v-icon>
            </span>
            <span class="br-preset-body">
              <span class="br-preset-name">{{ preset.name }}</span>
              <span class="br-preset-desc">{{ preset.description }}</span>
              <span class="br-preset-hex">{{ preset.primary }} · {{ preset.secondary }}</span>
            </span>
          </button>
        </div>
      </div>
    </v-card>

      </v-col>

      <!-- ═══════════════ RIGHT: LIVE PREVIEW ═══════════════ -->
      <v-col cols="12" lg="5">
        <div class="br-sticky">
          <v-card rounded="lg" elevation="0" class="br-card mb-3 overflow-hidden">
            <div class="br-section-head">
              <div class="d-flex align-center" style="gap:10px">
                <v-avatar size="32" color="teal" variant="tonal">
                  <v-icon size="17">mdi-monitor-eye</v-icon>
                </v-avatar>
                <div>
                  <div class="br-section-title">Live preview</div>
                  <div class="br-section-sub">How the palette renders in the app</div>
                </div>
              </div>
            </div>
            <v-divider />

            <div class="pa-4">
              <!-- Mini hero -->
              <div class="br-prev-hero" :style="{ background: draftGradient }">
                <div class="d-flex align-center" style="gap:10px">
                  <v-avatar v-if="logoUrl" size="36" rounded="lg" class="br-prev-logo">
                    <v-img :src="logoUrl" cover />
                  </v-avatar>
                  <div v-else class="br-prev-logo br-prev-logo--letter">
                    {{ (orgName || 'O').charAt(0).toUpperCase() }}
                  </div>
                  <div style="min-width:0">
                    <div class="br-prev-org">{{ orgName || 'Organization' }}</div>
                    <div class="br-prev-org-sub">Operations</div>
                  </div>
                  <v-spacer />
                  <span class="br-prev-status">Healthy</span>
                </div>
                <div class="br-prev-chips">
                  <span>41 SKUs</span>
                  <span>KES 912K</span>
                  <span>83% healthy</span>
                </div>
              </div>

              <!-- Buttons + chips -->
              <div class="d-flex flex-wrap align-center mt-3" style="gap:8px">
                <span class="br-prev-btn-primary" :style="{ background: brandPrimaryRaw, color: contrastFor(brandPrimaryRaw).fg }">
                  <v-icon size="15" :color="contrastFor(brandPrimaryRaw).fg">mdi-plus</v-icon>
                  Add item
                </span>
                <span class="br-prev-btn-outline" :style="{ borderColor: brandPrimaryRaw, color: brandPrimaryRaw }">
                  Export
                </span>
                <span class="br-prev-chip" :style="{ background: rgbaOf(brandAccentRaw, 0.22), color: mixHex(brandAccentRaw, '#0f172a', 0.55) }">
                  <v-icon size="13" :color="mixHex(brandAccentRaw, '#0f172a', 0.55)">mdi-star-four-points</v-icon>
                  Accent
                </span>
              </div>

              <!-- Mini panel -->
              <div class="br-prev-panel mt-3">
                <div class="d-flex align-center justify-between">
                  <div>
                    <div class="br-prev-panel-title">Stock health</div>
                    <div class="br-prev-panel-sub">Availability by item</div>
                  </div>
                  <span class="br-prev-badge" :style="{ background: rgbaOf(brandPrimaryRaw, 0.14), color: brandPrimaryRaw }">
                    {{ primaryContrast.ratio }}:1
                  </span>
                </div>
                <div class="br-prev-donut-row">
                  <div
                    class="br-prev-donut"
                    :style="{ background: `conic-gradient(${brandPrimaryRaw} 0 62%, ${brandSecondaryRaw} 62% 84%, ${brandAccentRaw} 84% 100%)` }"
                  >
                    <div class="br-prev-donut-hole">
                      <span class="br-prev-donut-value" :style="{ color: brandPrimaryRaw }">62%</span>
                      <span class="br-prev-donut-label">healthy</span>
                    </div>
                  </div>
                  <div class="br-prev-legend">
                    <div v-for="l in previewLegend" :key="l.label" class="br-prev-legend-row">
                      <span class="br-prev-legend-dot" :style="{ background: l.color }" />
                      <span>{{ l.label }}</span>
                      <span class="br-prev-legend-val">{{ l.value }}</span>
                    </div>
                  </div>
                </div>
                <div class="br-prev-bars">
                  <span
                    v-for="(h, i) in [82, 64, 48, 92, 71, 56]"
                    :key="i"
                    :style="{ height: h + '%', background: i % 2 ? brandAccentRaw : brandPrimaryRaw }"
                  />
                </div>
              </div>

              <!-- Document header sample -->
              <div class="br-prev-doc mt-3">
                <div class="br-prev-doc-band" :style="{ background: draftGradient }">
                  <span>{{ orgName || 'Organization' }}</span>
                  <span class="br-prev-doc-tag">PDF · REPORT</span>
                </div>
                <div class="br-prev-doc-body">
                  <span class="br-prev-doc-line" :style="{ background: brandPrimaryRaw }" />
                  <span class="br-prev-doc-line br-prev-doc-line--muted" />
                  <span class="br-prev-doc-line br-prev-doc-line--muted" style="width: 46%" />
                </div>
              </div>
            </div>
          </v-card>

          <!-- Accessibility -->
          <v-card rounded="lg" elevation="0" class="br-card mb-3 overflow-hidden">
            <div class="br-section-head">
              <div class="d-flex align-center" style="gap:10px">
                <v-avatar size="32" color="indigo" variant="tonal">
                  <v-icon size="17">mdi-shield-check-outline</v-icon>
                </v-avatar>
                <div>
                  <div class="br-section-title">Accessibility</div>
                  <div class="br-section-sub">WCAG contrast of text on each colour</div>
                </div>
              </div>
            </div>
            <v-divider />
            <div class="pa-4 d-flex flex-column" style="gap:10px">
              <div v-for="c in contrastRows" :key="c.name" class="br-a11y-row">
                <span class="br-a11y-dot" :style="{ background: c.hex }" />
                <div style="min-width:0; flex:1">
                  <div class="br-a11y-name">{{ c.name }}</div>
                  <div class="br-a11y-hint">{{ c.hex }} · text {{ c.white ? 'white' : 'dark' }}</div>
                </div>
                <span class="br-a11y-ratio">{{ c.ratio }}:1</span>
                <v-chip size="x-small" variant="tonal" :color="c.color" class="font-weight-bold">
                  {{ c.grade }}
                </v-chip>
              </div>
              <v-alert
                v-if="primaryContrast.ratio < 4.5"
                type="warning" variant="tonal" density="compact" rounded="lg" class="mt-1"
              >
                White text on the primary colour falls below the 4.5:1 AA threshold. Darken the
                primary or expect the app to switch to dark text on solid buttons.
              </v-alert>
              <p class="text-caption text-medium-emphasis mb-0">
                Gradients are evaluated on their darkest stop, which is where white labels sit.
              </p>
            </div>
          </v-card>

          <!-- Reset -->
          <v-card rounded="lg" elevation="0" class="br-card overflow-hidden">
            <div class="br-section-head">
              <div class="d-flex align-center" style="gap:10px">
                <v-avatar size="32" color="grey" variant="tonal">
                  <v-icon size="17">mdi-restore</v-icon>
                </v-avatar>
                <div>
                  <div class="br-section-title">Reset to default</div>
                  <div class="br-section-sub">Restore the AdhereMed blue</div>
                </div>
              </div>
            </div>
            <v-divider />
            <div class="pa-4 d-flex align-center" style="gap:12px">
              <div class="br-default-swatch" />
              <p class="text-body-2 text-medium-emphasis mb-0 flex-grow-1">
                {{ DEFAULTS.primary }} · {{ DEFAULTS.secondary }} · {{ DEFAULTS.accent }}
              </p>
              <v-btn
                v-if="canEdit"
                variant="tonal" color="error" rounded="lg" class="text-none"
                prepend-icon="mdi-restore" :disabled="!hasAnyColor" @click="resetColors"
              >Reset</v-btn>
            </div>
          </v-card>
        </div>
      </v-col>
    </v-row>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000" rounded="lg">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'
import { useBranding } from '~/composables/useBranding'
import { BRAND_DEFAULTS, normalizeHex as toHex, mix, rgba, luminance, readableOn } from '~/utils/branding'

const auth = useAuthStore()
const { $api } = useNuxtApp()
// The app tints its chrome with the palette below, so invalidate that cache
// whenever a new palette is saved. See composables/useBranding.js.
const brand = useBranding()

const ADMIN_EDIT_ROLES = new Set([
  'super_admin', 'tenant_admin', 'clinic_admin', 'hospital_admin',
  'pharmacy_admin', 'lab_admin', 'radiology_admin', 'homecare_admin',
  'inventory_admin', 'hse_manager', 'safety_officer', 'admin',
])
const canEdit = computed(() => ADMIN_EDIT_ROLES.has(auth.role))

const DEFAULTS = { ...BRAND_DEFAULTS }

/**
 * Healthcare-oriented palettes. Each triplet is primary / gradient-start /
 * accent-tail, chosen so the generated hero gradient stays legible (the
 * secondary is always the darkest of the three).
 * Categories power the filter chips above the grid.
 */
const presets = [
  // ── Clinical ──
  { name: 'AdhereMed Blue', category: 'clinical', description: 'The default platform palette',
    primary: '#2f6dff', secondary: '#143ce1', accent: '#37d6ff' },
  { name: 'Clinical Navy', category: 'clinical', description: 'Consultant-grade navy and sky',
    primary: '#1D4ED8', secondary: '#1E3A8A', accent: '#93C5FD' },
  { name: 'Scrubs Teal', category: 'clinical', description: 'Calm theatre teal',
    primary: '#0D9488', secondary: '#0F766E', accent: '#5EEAD4' },
  { name: 'Surgical Green', category: 'clinical', description: 'Classic surgical drape',
    primary: '#15803D', secondary: '#14532D', accent: '#86EFAC' },
  { name: 'Mercury Slate', category: 'clinical', description: 'Neutral, document-first',
    primary: '#475569', secondary: '#1E293B', accent: '#94A3B8' },
  { name: 'Telehealth Azure', category: 'clinical', description: 'Virtual care and messaging',
    primary: '#0EA5E9', secondary: '#0369A1', accent: '#7DD3FC' },

  // ── Pharmacy ──
  { name: 'Pharmacy Green', category: 'pharmacy', description: 'The universal pharmacy cross',
    primary: '#16A34A', secondary: '#15803D', accent: '#86EFAC' },
  { name: 'Wellness Mint', category: 'pharmacy', description: 'Supplements and retail shelf',
    primary: '#10B981', secondary: '#047857', accent: '#6EE7B7' },
  { name: 'Chemist Amber', category: 'pharmacy', description: 'Warm dispensary counter',
    primary: '#D97706', secondary: '#92400E', accent: '#FCD34D' },
  { name: 'Compounding Clay', category: 'pharmacy', description: 'Earthy lab-prepared tones',
    primary: '#B45309', secondary: '#78350F', accent: '#FDE68A' },

  // ── Specialties ──
  { name: 'Cardiology Crimson', category: 'specialty', description: 'Cardiac care and vitals',
    primary: '#DC2626', secondary: '#991B1B', accent: '#FCA5A5' },
  { name: 'Radiology Indigo', category: 'specialty', description: 'Imaging and diagnostics',
    primary: '#4F46E5', secondary: '#3730A3', accent: '#818CF8' },
  { name: 'Oncology Plum', category: 'specialty', description: 'Oncology and palliative',
    primary: '#9333EA', secondary: '#6B21A8', accent: '#D8B4FE' },
  { name: 'Laboratory Violet', category: 'specialty', description: 'Specimens and results',
    primary: '#7C3AED', secondary: '#5B21B6', accent: '#C4B5FD' },
  { name: 'Pediatrics Coral', category: 'specialty', description: 'Friendly child health',
    primary: '#FB7185', secondary: '#BE123C', accent: '#FDA4AF' },
  { name: 'Dental Aqua', category: 'specialty', description: 'Chairs, clean and bright',
    primary: '#0891B2', secondary: '#155E75', accent: '#67E8F9' },
  { name: 'Ophthalmology Cyan', category: 'specialty', description: 'Optical and screening',
    primary: '#0284C7', secondary: '#075985', accent: '#7DD3FC' },

  // ── Care & community ──
  { name: 'Homecare Rose', category: 'care', description: 'Warm, human home visits',
    primary: '#DB2777', secondary: '#9D174D', accent: '#F9A8D4' },
  { name: 'Midwifery Blush', category: 'care', description: 'Maternal and newborn',
    primary: '#EC4899', secondary: '#BE185D', accent: '#FBCFE8' },
  { name: 'First Aid Red', category: 'care', description: 'Emergency and triage',
    primary: '#B91C1C', secondary: '#7F1D1D', accent: '#FCA5A5' },
  { name: 'Ambulance Amber', category: 'care', description: 'Dispatch and fleet',
    primary: '#F59E0B', secondary: '#B45309', accent: '#FDE68A' },
  { name: 'Sunset', category: 'care', description: 'Warm amber sunset gradient',
    primary: '#F97316', secondary: '#C2410C', accent: '#FED7AA' },
  { name: 'Community Olive', category: 'care', description: 'Outreach and public health',
    primary: '#65A30D', secondary: '#3F6212', accent: '#BEF264' }
]

const presetCategories = [
  { value: 'all', label: 'All', icon: 'mdi-view-grid-outline' },
  { value: 'clinical', label: 'Clinical', icon: 'mdi-stethoscope' },
  { value: 'pharmacy', label: 'Pharmacy', icon: 'mdi-pill' },
  { value: 'specialty', label: 'Specialties', icon: 'mdi-heart-pulse' },
  { value: 'care', label: 'Care', icon: 'mdi-hand-heart-outline' }
]

const presetFilter = ref('all')
const filteredPresets = computed(() =>
  presetFilter.value === 'all'
    ? presets
    : presets.filter((p) => p.category === presetFilter.value)
)

const loading = ref(false)
const saving = ref(false)
const errorMsg = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })

const orgName = ref('')
const logoUrl = ref('')

const brandPrimaryRaw = ref(DEFAULTS.primary)
const brandSecondaryRaw = ref(DEFAULTS.secondary)
const brandAccentRaw = ref(DEFAULTS.accent)

// Reactive so the `dirty` computed re-evaluates when a fresh snapshot is
// captured — assigning identical colours to the refs would otherwise leave
// the cached "Unsaved changes" state stuck on a freshly loaded page.
const snapshot = ref('')

const hasAnyColor = computed(() =>
  brandPrimaryRaw.value !== DEFAULTS.primary ||
  brandSecondaryRaw.value !== DEFAULTS.secondary ||
  brandAccentRaw.value !== DEFAULTS.accent
)

const dirty = computed(() =>
  JSON.stringify({
    primary: brandPrimaryRaw.value,
    secondary: brandSecondaryRaw.value,
    accent: brandAccentRaw.value
  }) !== snapshot.value
)

// ── Live palette derivations ────────────────────────────────────────────
function safeHex(v, fallback) {
  return toHex(v) || fallback
}

/** Signature gradient — accent mixed toward primary so the tail stays legible. */
const draftGradient = computed(() => {
  const p = safeHex(brandPrimaryRaw.value, DEFAULTS.primary)
  const s = safeHex(brandSecondaryRaw.value, DEFAULTS.secondary)
  const a = mix(safeHex(brandAccentRaw.value, DEFAULTS.accent), p, 0.55)
  return `linear-gradient(120deg, ${s} 0%, ${p} 52%, ${a} 100%)`
})

/** CSS custom properties so the hero can reuse the same gradient + glow recipe. */
const draftTheme = computed(() => {
  const p = safeHex(brandPrimaryRaw.value, DEFAULTS.primary)
  const s = safeHex(brandSecondaryRaw.value, DEFAULTS.secondary)
  const a = safeHex(brandAccentRaw.value, DEFAULTS.accent)
  return {
    '--hero-deep': s,
    '--hero-main': p,
    '--hero-accent': mix(a, p, 0.55),
    '--hero-ink': darkerHex(s, p),
    '--hero-glow': rgba(p, 0.32),
    '--hero-glow-2': rgba(a, 0.22),
    '--hero-shadow': `0 14px 34px ${rgba(p, 0.24)}`
  }
})

function darkerHex(a, b) {
  const ca = safeHex(a, DEFAULTS.secondary)
  const cb = safeHex(b, DEFAULTS.primary)
  return luminance(ca) <= luminance(cb) ? ca : cb
}

/**
 * Contrast of the best foreground (white or near-black) against a colour.
 * `grade` follows WCAG 2.1 AA thresholds for normal text.
 */
function contrastFor(hex) {
  const h = safeHex(hex, DEFAULTS.primary)
  const L = luminance(h)
  const onWhite = 1.05 / (L + 0.05)
  const onBlack = (L + 0.05) / 0.05
  const useWhite = onWhite >= onBlack
  const ratio = Number(Math.max(onWhite, onBlack).toFixed(2))
  const grade = ratio >= 7 ? 'AAA' : ratio >= 4.5 ? 'AA' : ratio >= 3 ? 'AA large' : 'Fail'
  return { fg: useWhite ? '#ffffff' : '#0f172a', white: useWhite, ratio, grade }
}

const primaryContrast = computed(() => contrastFor(brandPrimaryRaw.value))

function rgbaOf(hex, alpha) {
  return rgba(safeHex(hex, DEFAULTS.primary), alpha)
}
function mixHex(a, b, amount) {
  return mix(safeHex(a, DEFAULTS.primary), safeHex(b, DEFAULTS.secondary), amount)
}

/** Tints (50–400) and shades (600–900) derived from the current primary. */
const primaryShades = computed(() => {
  const base = safeHex(brandPrimaryRaw.value, DEFAULTS.primary)
  const steps = [
    { label: '50', amount: 0.9, to: '#ffffff' },
    { label: '100', amount: 0.74, to: '#ffffff' },
    { label: '200', amount: 0.56, to: '#ffffff' },
    { label: '300', amount: 0.36, to: '#ffffff' },
    { label: '400', amount: 0.17, to: '#ffffff' },
    { label: '500', amount: 0, to: '#ffffff' },
    { label: '600', amount: 0.17, to: '#000000' },
    { label: '700', amount: 0.35, to: '#000000' },
    { label: '800', amount: 0.53, to: '#000000' },
    { label: '900', amount: 0.7, to: '#000000' }
  ]
  return steps.map((s) => ({
    label: s.label,
    hex: s.amount ? mix(base, s.to, s.amount) : base
  }))
})

/** Rows for the accessibility card. */
const contrastRows = computed(() => {
  const entries = [
    { name: 'Primary', hex: safeHex(brandPrimaryRaw.value, DEFAULTS.primary) },
    { name: 'Secondary', hex: safeHex(brandSecondaryRaw.value, DEFAULTS.secondary) },
    { name: 'Accent', hex: safeHex(brandAccentRaw.value, DEFAULTS.accent) }
  ]
  return entries.map((e) => {
    const c = contrastFor(e.hex)
    return {
      ...e,
      ...c,
      color: c.ratio >= 4.5 ? 'success' : c.ratio >= 3 ? 'warning' : 'error'
    }
  })
})

const previewLegend = computed(() => [
  { label: 'Healthy', color: safeHex(brandPrimaryRaw.value, DEFAULTS.primary), value: '62%' },
  { label: 'Low', color: safeHex(brandSecondaryRaw.value, DEFAULTS.secondary), value: '22%' },
  { label: 'Out', color: safeHex(brandAccentRaw.value, DEFAULTS.accent), value: '16%' }
])

/** Name of the preset currently matching the draft colours, if any. */
const activePresetName = computed(() => {
  const p = safeHex(brandPrimaryRaw.value, '').toLowerCase()
  const s = safeHex(brandSecondaryRaw.value, '').toLowerCase()
  const a = safeHex(brandAccentRaw.value, '').toLowerCase()
  if (!p || !s || !a) return ''
  return presets.find(
    (x) =>
      x.primary.toLowerCase() === p &&
      x.secondary.toLowerCase() === s &&
      x.accent.toLowerCase() === a
  )?.name || ''
})

// ── Editing helpers ─────────────────────────────────────────────────────
const primaryInput = ref(null)
const secondaryInput = ref(null)
const accentInput = ref(null)

function pickPrimary() {
  if (canEdit.value) primaryInput.value?.click()
}
function pickSecondary() {
  if (canEdit.value) secondaryInput.value?.click()
}
function pickAccent() {
  if (canEdit.value) accentInput.value?.click()
}

function onHexInput(which, val) {
  const normalized = normalizeHex(val)
  if (!normalized) return
  if (which === 'primary') brandPrimaryRaw.value = normalized
  else if (which === 'secondary') brandSecondaryRaw.value = normalized
  else if (which === 'accent') brandAccentRaw.value = normalized
}

function normalizeHex(v) {
  return toHex(v)
}

async function copyHex(hex) {
  const value = safeHex(hex, DEFAULTS.primary)
  try {
    await navigator.clipboard.writeText(value)
    snack.text = `${value} copied.`
    snack.color = 'success'
    snack.show = true
  } catch {
    snack.text = value
    snack.color = 'info'
    snack.show = true
  }
}

function applyPreset(preset) {
  if (!canEdit.value) return
  brandPrimaryRaw.value = preset.primary
  brandSecondaryRaw.value = preset.secondary
  brandAccentRaw.value = preset.accent
}

function isPresetActive(preset) {
  return (
    brandPrimaryRaw.value.toLowerCase() === preset.primary.toLowerCase() &&
    brandSecondaryRaw.value.toLowerCase() === preset.secondary.toLowerCase() &&
    brandAccentRaw.value.toLowerCase() === preset.accent.toLowerCase()
  )
}

/** Discard unsaved edits, returning to the last loaded/saved palette. */
function revert() {
  if (!snapshot.value) return
  const s = JSON.parse(snapshot.value)
  brandPrimaryRaw.value = s.primary
  brandSecondaryRaw.value = s.secondary
  brandAccentRaw.value = s.accent
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
    snapshot.value = JSON.stringify({
      primary: brandPrimaryRaw.value,
      secondary: brandSecondaryRaw.value,
      accent: brandAccentRaw.value
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
      brand_accent: brandAccentRaw.value
    }
    const { data } = await $api.patch('/tenants/me/', payload)
    brandPrimaryRaw.value = data.brand_primary || DEFAULTS.primary
    brandSecondaryRaw.value = data.brand_secondary || DEFAULTS.secondary
    brandAccentRaw.value = data.brand_accent || DEFAULTS.accent
    snapshot.value = JSON.stringify({
      primary: brandPrimaryRaw.value,
      secondary: brandSecondaryRaw.value,
      accent: brandAccentRaw.value
    })
    // Push the new palette to the rest of the app (heroes, panels, …).
    brand.palette.value = {
      primary: brandPrimaryRaw.value,
      secondary: brandSecondaryRaw.value,
      accent: brandAccentRaw.value
    }
    brand.isLoaded.value = true
    snack.text = 'Brand colours saved — the whole app has been updated.'
    snack.color = 'success'
    snack.show = true
  } catch (e) {
    errorMsg.value = e?.response?.data?.detail || 'Failed to save brand colours.'
  } finally {
    saving.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.br-page { max-width: 1560px; margin: 0 auto; }

/* ═══════════════ Hero ═══════════════
   Driven by --hero-* custom properties built from the DRAFT palette, so the
   chrome recolours live as the user picks. */
.br-hero {
  position: relative;
  overflow: hidden;
  border-radius: 18px;
  padding: 20px 22px 16px;
  color: #fff;
  background: linear-gradient(
    120deg,
    var(--hero-deep, #143ce1) 0%,
    var(--hero-main, #2f6dff) 52%,
    var(--hero-accent, #37d6ff) 100%
  );
  box-shadow: var(--hero-shadow, 0 14px 34px rgba(47, 109, 255, 0.24));
  transition: background 0.25s ease, box-shadow 0.25s ease;
}
.br-glow {
  position: absolute;
  width: 340px;
  height: 340px;
  border-radius: 50%;
  right: -110px;
  top: -170px;
  background: radial-gradient(circle, var(--hero-glow, rgba(255, 255, 255, 0.28)), transparent 68%);
  pointer-events: none;
}
.br-glow-2 {
  right: auto;
  left: -140px;
  top: auto;
  bottom: -220px;
  width: 300px;
  height: 300px;
  background: radial-gradient(circle, var(--hero-glow-2, rgba(55, 214, 255, 0.24)), transparent 70%);
}
.br-hero-top { position: relative; }
.br-hero-icon {
  width: 56px;
  height: 56px;
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  background: rgba(255, 255, 255, 0.16);
  border: 1px solid rgba(255, 255, 255, 0.28);
  backdrop-filter: blur(6px);
}
.br-eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: rgba(255, 255, 255, 0.78);
}
.br-title {
  font-size: 26px;
  line-height: 1.15;
  font-weight: 800;
  letter-spacing: -0.2px;
  margin: 2px 0;
}
.br-sub {
  font-size: 13px;
  color: rgba(255, 255, 255, 0.82);
}
.br-hero-iconbtn { color: #fff !important; }

.br-btn-strong {
  background: #ffffff !important;
  color: var(--hero-ink, #143ce1) !important;
  font-weight: 700 !important;
  border: 1px solid rgba(255, 255, 255, 0.95) !important;
  box-shadow: 0 6px 18px rgba(6, 44, 40, 0.28) !important;
}
.br-btn-strong:hover { background: #ffffff !important; filter: brightness(0.94); }
.br-btn-strong :deep(.v-icon) { color: var(--hero-ink, #143ce1) !important; opacity: 1 !important; }
.br-btn-glass {
  background: rgba(255, 255, 255, 0.16) !important;
  color: #ffffff !important;
  font-weight: 600 !important;
  border: 1px solid rgba(255, 255, 255, 0.34) !important;
  backdrop-filter: blur(6px);
}
.br-btn-glass:hover {
  background: rgba(255, 255, 255, 0.26) !important;
  border-color: rgba(255, 255, 255, 0.6) !important;
}
.br-btn-glass :deep(.v-icon) { color: #fff !important; opacity: 1 !important; }

.br-hero-foot {
  position: relative;
  margin-top: 14px;
  padding-top: 12px;
  border-top: 1px solid rgba(255, 255, 255, 0.2);
}
.br-hero-chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 4px 10px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
  color: rgba(255, 255, 255, 0.95);
  background: rgba(255, 255, 255, 0.14);
  border: 1px solid rgba(255, 255, 255, 0.24);
}
.br-hero-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  box-shadow: 0 0 0 2px rgba(255, 255, 255, 0.4);
}
.br-hero-chip-warn {
  background: rgba(245, 158, 11, 0.34);
  border-color: rgba(255, 255, 255, 0.42);
}
.br-hero-chip-alert {
  background: rgba(239, 68, 68, 0.32);
  border-color: rgba(255, 255, 255, 0.45);
}

/* ═══════════════ Cards / section heads ═══════════════ */
.br-card {
  border: 1px solid rgba(15, 23, 42, 0.08) !important;
  background: rgb(var(--v-theme-surface));
}
.br-section-head {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  padding: 12px 16px;
}
.br-section-title {
  font-size: 14.5px;
  font-weight: 700;
  line-height: 1.2;
}
.br-section-sub {
  font-size: 11.5px;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.br-sticky { position: sticky; top: 16px; }

/* ═══════════════ Colour tiles ═══════════════ */
.br-color {
  padding: 10px;
  border-radius: 14px;
  border: 1px solid rgba(15, 23, 42, 0.07);
  background: rgba(var(--v-theme-surface-variant), 0.18);
  transition: border-color 0.18s ease, box-shadow 0.18s ease;
}
.br-color:hover {
  border-color: rgba(var(--v-theme-primary), 0.3);
  box-shadow: 0 8px 20px rgba(15, 23, 42, 0.06);
}
.br-swatch {
  position: relative;
  height: 92px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  overflow: hidden;
  transition: transform 0.18s ease;
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.18);
}
.br-swatch:hover { transform: scale(1.015); }
.br-swatch-ink {
  display: flex;
  flex-direction: column;
  align-items: center;
  line-height: 1.1;
}
.br-swatch-initial { font-size: 24px; font-weight: 800; letter-spacing: -0.5px; }
.br-swatch-ratio { font-size: 10.5px; font-weight: 700; opacity: 0.8; }
.br-swatch-edit {
  position: absolute;
  bottom: 7px;
  right: 9px;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 700;
  color: rgba(255, 255, 255, 0.95);
  background: rgba(15, 23, 42, 0.32);
  backdrop-filter: blur(4px);
  opacity: 0;
  transition: opacity 0.18s ease;
}
.br-swatch:hover .br-swatch-edit { opacity: 1; }
.br-color-name {
  font-size: 13px;
  font-weight: 700;
  line-height: 1.2;
}
.br-color-role {
  font-size: 11px;
  line-height: 1.3;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.color-hidden-input {
  position: absolute;
  opacity: 0;
  width: 0;
  height: 0;
  pointer-events: none;
}

/* Gradient + scale */
.br-gradient {
  position: relative;
  height: 54px;
  border-radius: 12px;
  display: flex;
  align-items: flex-end;
  justify-content: flex-end;
  padding: 8px 12px;
  transition: background 0.25s ease;
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.16);
}
.br-gradient-label {
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.9px;
  text-transform: uppercase;
  color: rgba(255, 255, 255, 0.85);
}
.br-shades {
  display: grid;
  grid-template-columns: repeat(10, 1fr);
  gap: 4px;
}
.br-shade {
  height: 38px;
  border: none;
  border-radius: 7px;
  display: flex;
  align-items: flex-end;
  justify-content: center;
  padding-bottom: 3px;
  font-size: 9px;
  font-weight: 800;
  cursor: pointer;
  transition: transform 0.14s ease;
}
.br-shade:hover { transform: translateY(-2px); }

/* ═══════════════ Presets ═══════════════ */
.br-filter :deep(.v-chip) { margin-inline-end: 6px; }
.br-presets {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: 10px;
}
.br-preset {
  display: flex;
  align-items: stretch;
  gap: 10px;
  padding: 10px;
  border-radius: 12px;
  border: 1.5px solid rgba(15, 23, 42, 0.08);
  background: rgb(var(--v-theme-surface));
  text-align: left;
  cursor: pointer;
  transition: transform 0.16s ease, box-shadow 0.16s ease, border-color 0.16s ease;
}
.br-preset:hover:not(:disabled) {
  transform: translateY(-2px);
  border-color: rgba(var(--v-theme-primary), 0.35);
  box-shadow: 0 10px 22px rgba(15, 23, 42, 0.08);
}
.br-preset:disabled { cursor: not-allowed; opacity: 0.6; }
.br-preset--active {
  border-color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.05);
}
.br-preset-preview {
  width: 46px;
  border-radius: 9px;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.18);
}
.br-preset-body {
  display: flex;
  flex-direction: column;
  justify-content: center;
  min-width: 0;
  gap: 1px;
}
.br-preset-name {
  font-size: 13px;
  font-weight: 700;
  line-height: 1.2;
}
.br-preset-desc {
  font-size: 11px;
  line-height: 1.3;
  color: rgba(var(--v-theme-on-surface), 0.6);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.br-preset-hex {
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.2px;
  font-variant-numeric: tabular-nums;
  color: rgba(var(--v-theme-on-surface), 0.45);
}

/* ═══════════════ Live preview ═══════════════ */
.br-prev-hero {
  position: relative;
  padding: 14px;
  border-radius: 14px;
  color: #fff;
  overflow: hidden;
  transition: background 0.25s ease;
}
.br-prev-logo {
  width: 36px;
  height: 36px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.18);
  border: 1px solid rgba(255, 255, 255, 0.3);
  flex-shrink: 0;
}
.br-prev-logo--letter {
  font-size: 17px;
  font-weight: 800;
}
.br-prev-org {
  font-size: 14px;
  font-weight: 800;
  line-height: 1.2;
}
.br-prev-org-sub {
  font-size: 11px;
  color: rgba(255, 255, 255, 0.82);
}
.br-prev-status {
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.4px;
  text-transform: uppercase;
  padding: 3px 9px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.2);
  border: 1px solid rgba(255, 255, 255, 0.34);
}
.br-prev-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 12px;
  padding-top: 10px;
  border-top: 1px solid rgba(255, 255, 255, 0.22);
}
.br-prev-chips span {
  font-size: 11px;
  font-weight: 600;
  padding: 3px 9px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.15);
  border: 1px solid rgba(255, 255, 255, 0.22);
}

.br-prev-btn-primary,
.br-prev-btn-outline {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 6px 13px;
  border-radius: 9px;
  font-size: 12.5px;
  font-weight: 700;
}
.br-prev-btn-outline {
  border: 1.5px solid transparent;
  background: transparent;
}
.br-prev-chip {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 5px 11px;
  border-radius: 999px;
  font-size: 11.5px;
  font-weight: 700;
}

.br-prev-panel {
  padding: 12px;
  border-radius: 12px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: rgba(var(--v-theme-surface-variant), 0.16);
}
.br-prev-panel-title {
  font-size: 13px;
  font-weight: 700;
  line-height: 1.2;
}
.br-prev-panel-sub {
  font-size: 10.5px;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.br-prev-badge {
  font-size: 10.5px;
  font-weight: 800;
  padding: 3px 9px;
  border-radius: 999px;
  font-variant-numeric: tabular-nums;
}
.br-prev-donut-row {
  display: flex;
  align-items: center;
  gap: 14px;
  margin-top: 10px;
}
.br-prev-donut {
  width: 84px;
  height: 84px;
  border-radius: 50%;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: background 0.25s ease;
}
.br-prev-donut-hole {
  width: 60px;
  height: 60px;
  border-radius: 50%;
  background: rgb(var(--v-theme-surface));
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  line-height: 1.1;
}
.br-prev-donut-value {
  font-size: 15px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
}
.br-prev-donut-label {
  font-size: 9px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.br-prev-legend {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.br-prev-legend-row {
  display: flex;
  align-items: center;
  gap: 7px;
  font-size: 11.5px;
  color: rgba(var(--v-theme-on-surface), 0.72);
}
.br-prev-legend-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}
.br-prev-legend-val {
  margin-left: auto;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.9);
}
.br-prev-bars {
  display: flex;
  align-items: flex-end;
  gap: 5px;
  height: 44px;
  margin-top: 12px;
}
.br-prev-bars span {
  flex: 1;
  border-radius: 3px 3px 1px 1px;
  opacity: 0.85;
  transition: background 0.25s ease;
}

.br-prev-doc {
  border-radius: 10px;
  overflow: hidden;
  border: 1px solid rgba(15, 23, 42, 0.1);
}
.br-prev-doc-band {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 7px 11px;
  font-size: 10.5px;
  font-weight: 700;
  color: #fff;
  transition: background 0.25s ease;
}
.br-prev-doc-tag {
  font-size: 9px;
  letter-spacing: 0.8px;
  opacity: 0.82;
}
.br-prev-doc-body {
  display: flex;
  flex-direction: column;
  gap: 5px;
  padding: 10px 11px;
}
.br-prev-doc-line {
  height: 5px;
  width: 72%;
  border-radius: 3px;
  opacity: 0.35;
}
.br-prev-doc-line--muted {
  background: rgba(15, 23, 42, 0.22);
  width: 88%;
}

/* ═══════════════ Accessibility ═══════════════ */
.br-a11y-row {
  display: flex;
  align-items: center;
  gap: 10px;
}
.br-a11y-dot {
  width: 26px;
  height: 26px;
  border-radius: 8px;
  flex-shrink: 0;
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.2);
}
.br-a11y-name {
  font-size: 12.5px;
  font-weight: 700;
  line-height: 1.2;
}
.br-a11y-hint {
  font-size: 10.5px;
  font-variant-numeric: tabular-nums;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.br-a11y-ratio {
  font-size: 12.5px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
}
.br-default-swatch {
  width: 28px;
  height: 28px;
  border-radius: 8px;
  flex-shrink: 0;
  background: linear-gradient(120deg, #143ce1, #2f6dff 60%, #37d6ff);
}

@media (max-width: 700px) {
  .br-title { font-size: 21px; }
  .br-hero { padding: 16px 16px 14px; border-radius: 16px; }
  .br-sticky { position: static; }
  .br-shades { grid-template-columns: repeat(5, 1fr); }
  .br-presets { grid-template-columns: 1fr; }
}
</style>
