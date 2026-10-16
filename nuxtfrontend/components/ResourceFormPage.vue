<template>
  <v-container fluid class="pa-4 pa-md-6" :style="{ maxWidth: maxWidth }">
    <!-- ═══ Premium hero (opt-in via `hero`) ═══
         Tinted with the tenant palette from /ims/organization/branding, so a
         form matches the list/detail pages it was reached from. Falls back to
         the plain PageHeader when `hero` is not set, keeping every other form
         in the app pixel-identical. -->
    <div v-if="hero" class="rfp-hero mb-4" :style="heroTheme">
      <span class="rfp-hero-glow" />
      <span class="rfp-hero-glow rfp-hero-glow-2" />

      <div class="d-flex flex-wrap align-center justify-space-between ga-3">
        <div class="d-flex align-center" style="gap:16px">
          <div class="rfp-hero-icon">
            <v-icon size="30">{{ icon || 'mdi-file-document-outline' }}</v-icon>
          </div>
          <div style="min-width:0">
            <div class="rfp-eyebrow">
              <v-icon size="11">mdi-circle</v-icon>
              {{ eyebrow }}
            </div>
            <h1 class="rfp-title">{{ title }}</h1>
            <div v-if="subtitle" class="rfp-sub">{{ subtitle }}</div>
          </div>
        </div>

        <div class="d-flex flex-wrap align-center ga-2">
          <slot name="hero-actions" />
          <v-btn
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none rfp-hero-btn-glass"
            prepend-icon="mdi-arrow-left"
            :to="backPath"
          >{{ $t('common.back') }}</v-btn>
        </div>
      </div>
    </div>

    <PageHeader v-else :title="title" :icon="icon" :subtitle="subtitle">
      <template #actions>
        <v-btn
          variant="text"
          rounded="lg"
          class="text-none"
          prepend-icon="mdi-arrow-left"
          :to="backPath"
        >{{ $t('common.back') }}</v-btn>
      </template>
    </PageHeader>

    <!-- `flat` drops the wrapping card so the slot can render its own panels
         (used by long, sectioned forms). The default keeps the card look. -->
    <div :class="flat ? 'rfp-body-flat' : 'rfp-body pa-4 pa-md-6'">
      <v-form ref="formRef" @submit.prevent="onSubmit">
        <slot :form="model" :errors="errors" />

        <v-alert v-if="topError" type="error" variant="tonal" density="compact" class="mt-4" rounded="lg">
          {{ topError }}
        </v-alert>

        <div class="rfp-footer" :class="{ 'rfp-footer--flush': flat }">
          <v-btn variant="text" rounded="lg" class="text-none" :to="backPath">{{ $t('common.cancel') }}</v-btn>
          <v-btn
            type="submit"
            color="primary"
            rounded="lg"
            class="text-none"
            :loading="saving"
            prepend-icon="mdi-content-save"
          >{{ saveLabel || $t('common.save') }}</v-btn>
        </div>
      </v-form>
    </div>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>

    <!-- Extra slot for dialogs / overlays outside the form card -->
    <slot name="below" />
  </v-container>
</template>

<script setup>
import { useI18n } from 'vue-i18n'
import { useBranding } from '~/composables/useBranding'
const { t } = useI18n()

const props = defineProps({
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
  icon: { type: String, default: '' },
  backPath: { type: String, required: true },
  resource: { type: Object, required: true },
  initial: { type: Object, default: () => ({}) },
  loadId: { type: [String, Number, null], default: null },
  saveLabel: { type: String, default: '' },
  maxWidth: { type: String, default: '920px' },
  transform: { type: Function, default: (v) => v },
  // ── Opt-in premium presentation ──
  // `hero` swaps the PageHeader for a brand-tinted gradient hero;
  // `flat` drops the wrapping card so the slot can render its own panels.
  hero: { type: Boolean, default: false },
  eyebrow: { type: String, default: 'NEW RECORD' },
  flat: { type: Boolean, default: false }
})
const emit = defineEmits(['saved'])

// Tenant palette — same bridge the inventory list/detail heroes use. The third
// gradient stop is the accent mixed toward the primary, because a raw accent is
// usually a near-white highlight and would leave the glass button white-on-pale.
const brand = useBranding()
const heroTheme = computed(() => ({
  '--hero-deep': brand.secondary.value,
  '--hero-main': brand.primary.value,
  '--hero-accent': brand.gradientStops.value[2],
  '--hero-ink': brand.ink.value,
  '--hero-glow': brand.tint('primary', 0.3),
  '--hero-glow-2': brand.tint('accent', 0.2),
  '--hero-shadow': brand.shadow.value
}))

const model = reactive({ ...props.initial })
const errors = ref({})
const saving = computed(() => props.resource.saving.value)
const topError = ref('')
const formRef = ref(null)
const snack = reactive({ show: false, color: 'success', text: '' })

onMounted(async () => {
  if (props.hero) brand.load()
  if (props.loadId) {
    const data = await props.resource.get(props.loadId)
    if (data) {
      Object.keys(props.initial).forEach(k => {
        if (data[k] !== undefined) model[k] = data[k]
      })
      // include any extra fields
      Object.keys(data).forEach(k => {
        if (model[k] === undefined) model[k] = data[k]
      })
    }
  }
})

async function onSubmit() {
  topError.value = ''
  errors.value = {}
  const v = await formRef.value.validate()
  if (v?.valid === false) return
  try {
    const payload = props.transform({ ...model })
    const result = props.loadId
      ? await props.resource.update(props.loadId, payload)
      : await props.resource.create(payload)
    snack.text = t('common.saved')
    snack.color = 'success'
    snack.show = true
    emit('saved', result)
  } catch (e) {
    const data = e?.response?.data
    if (data && typeof data === 'object') {
      // Field-level errors from DRF 400
      errors.value = data
      // Build a readable top error from the field errors
      const parts = Object.entries(data).map(([k, v]) => {
        const val = Array.isArray(v) ? v.join(', ') : String(v)
        return `${k}: ${val}`
      })
      topError.value = parts.join(' | ')
    } else {
      topError.value = props.resource.error.value || t('common.saveFailed')
    }
  }
}
</script>

<style scoped>
/* ─────────────── Premium hero ───────────────
   Colours come from the tenant palette (see `heroTheme`); the var() fallbacks
   mirror BRAND_DEFAULTS in utils/branding.js. */
.rfp-hero {
  position: relative;
  overflow: hidden;
  border-radius: 18px;
  padding: 20px 22px;
  color: #fff;
  background: linear-gradient(
    120deg,
    var(--hero-deep, #143ce1) 0%,
    var(--hero-main, #2f6dff) 52%,
    var(--hero-accent, #37d6ff) 100%
  );
  box-shadow: var(--hero-shadow, 0 14px 34px rgba(47, 109, 255, 0.24));
}
.rfp-hero-glow {
  position: absolute;
  width: 340px;
  height: 340px;
  border-radius: 50%;
  right: -110px;
  top: -170px;
  background: radial-gradient(circle, var(--hero-glow, rgba(255, 255, 255, 0.28)), transparent 68%);
  pointer-events: none;
}
.rfp-hero-glow-2 {
  right: auto;
  left: -140px;
  top: auto;
  bottom: -220px;
  width: 300px;
  height: 300px;
  background: radial-gradient(circle, var(--hero-glow-2, rgba(55, 214, 255, 0.24)), transparent 70%);
}
.rfp-hero-icon {
  width: 56px;
  height: 56px;
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.16);
  border: 1px solid rgba(255, 255, 255, 0.28);
  backdrop-filter: blur(6px);
  flex-shrink: 0;
}
.rfp-eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: rgba(255, 255, 255, 0.78);
}
.rfp-title {
  font-size: 25px;
  line-height: 1.15;
  font-weight: 800;
  letter-spacing: -0.2px;
  margin: 2px 0 2px;
  overflow-wrap: anywhere;
}
.rfp-sub {
  font-size: 13px;
  color: rgba(255, 255, 255, 0.82);
}

/* A saturated brand gradient washes out tonal/primary fills, so the hero
   buttons carry their own glass / solid treatment. */
.rfp-hero-btn-glass {
  background: rgba(255, 255, 255, 0.16) !important;
  color: #ffffff !important;
  font-weight: 600 !important;
  border: 1px solid rgba(255, 255, 255, 0.34) !important;
  backdrop-filter: blur(6px);
}
.rfp-hero-btn-glass:hover {
  background: rgba(255, 255, 255, 0.26) !important;
  border-color: rgba(255, 255, 255, 0.6) !important;
}
.rfp-hero-btn-glass :deep(.v-icon) { color: #ffffff !important; opacity: 1 !important; }

/* ─────────────── Body ─────────────── */
/* Default card look — reproduces the previous `<v-card rounded="lg">` exactly
   (radius 8px + Vuetify elevation 1), so the ~20 other forms that use this
   shell are visually unchanged now that the v-card is a plain element. */
.rfp-body {
  border-radius: 8px;
  background: rgb(var(--v-theme-surface));
  box-shadow:
    0 2px 1px -1px rgba(0, 0, 0, 0.2),
    0 1px 1px 0 rgba(0, 0, 0, 0.14),
    0 1px 3px 0 rgba(0, 0, 0, 0.12);
}
/* Bare look — the slot supplies its own panels. */
.rfp-body-flat { display: block; }

/* ─────────────── Footer ─────────────── */
.rfp-footer {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  margin-top: 24px;
  padding-top: 16px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.08);
}
/* With no wrapping card there is nothing to separate the actions from, so give
   the bar its own surface to read as a deliberate commit step. */
.rfp-footer--flush {
  margin-top: 20px;
  padding: 14px 18px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  border-radius: 14px;
  background: rgb(var(--v-theme-surface));
  box-shadow: 0 6px 18px rgba(15, 23, 42, 0.05);
}
</style>
