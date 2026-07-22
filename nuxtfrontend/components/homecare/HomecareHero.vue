<template>
  <div class="hc-hero pa-5 pa-md-7 mb-5">
    <div class="hc-hero-inner">
      <div class="d-flex align-center flex-wrap ga-4">
        <div class="flex-grow-1">
          <div class="d-flex align-center mb-2">
            <v-avatar size="46" class="hc-hero-icon mr-3">
              <v-icon :icon="icon" color="white" />
            </v-avatar>
            <div>
              <div class="text-overline text-teal-darken-2 font-weight-bold">{{ eyebrow }}</div>
              <h1 class="text-h4 text-md-h3 font-weight-bold text-slate-900 ma-0">{{ title }}</h1>
            </div>
          </div>
          <p v-if="subtitle" class="text-body-1 text-medium-emphasis mb-4 mt-2">{{ subtitle }}</p>
          <div class="d-flex flex-wrap ga-2">
            <slot name="chips" />
            <v-chip v-for="c in chips" :key="c.label" size="small"
                    color="teal-lighten-4" variant="flat" class="text-teal-darken-4">
              <v-icon v-if="c.icon" :icon="c.icon" size="14" class="mr-1" />
              {{ c.label }}
            </v-chip>
          </div>
        </div>
        <div class="d-flex flex-column align-end ga-2">
          <slot name="actions" />
          <div v-if="showClock" class="hc-hero-clock">
            <v-icon icon="mdi-clock-outline" size="14" class="mr-1" />
            {{ clock }}
          </div>
        </div>
      </div>
    </div>
    <div class="hc-hero-decor"></div>
  </div>
</template>

<script setup>
const props = defineProps({
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
  eyebrow: { type: String, default: 'HOMECARE' },
  icon: { type: String, default: 'mdi-home-heart' },
  chips: { type: Array, default: () => [] },
  showClock: { type: Boolean, default: true }
})

const clock = ref('')
let timer = null
function tick() {
  clock.value = new Date().toLocaleString([], {
    weekday: 'short', month: 'short', day: 'numeric',
    hour: '2-digit', minute: '2-digit'
  })
}
onMounted(() => { tick(); timer = setInterval(tick, 30000) })
onBeforeUnmount(() => { if (timer) clearInterval(timer) })
</script>

<style scoped>
.hc-hero {
  position: relative;
  border-radius: 24px;
  overflow: hidden;
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
  box-shadow: 0 1px 3px rgba(15,23,42,0.04);
}
.hc-hero-inner { position: relative; z-index: 2; }
.hc-hero-icon {
  background: rgba(13,148,136,0.12) !important;
  border: 1px solid rgba(13,148,136,0.22);
}
.hc-hero-icon .v-icon { color: #0d9488 !important; }
.text-slate-900 { color: #0f172a; }
.hc-hero-clock {
  display: inline-flex; align-items: center;
  padding: 4px 10px; border-radius: 999px;
  background: rgba(15,23,42,0.04);
  color: #64748b; font-size: 12px; font-weight: 500;
  border: 1px solid rgba(15,23,42,0.08);
}
.hc-hero-decor {
  position: absolute; right: -80px; top: -80px;
  width: 280px; height: 280px; border-radius: 50%;
  background: radial-gradient(circle, rgba(13,148,136,0.04), transparent 70%);
  pointer-events: none;
}
:global(.v-theme--dark .hc-hero) {
  background: #1e293b;
  border-color: rgba(255,255,255,0.08);
}
:global(.v-theme--dark .text-slate-900) { color: white; }
:global(.v-theme--dark .hc-hero-clock) {
  background: rgba(255,255,255,0.04);
  color: #94a3b8;
  border-color: rgba(255,255,255,0.1);
}
</style>
