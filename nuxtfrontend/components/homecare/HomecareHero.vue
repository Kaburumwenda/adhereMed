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
              <div class="text-overline text-white-soft">{{ eyebrow }}</div>
              <h1 class="text-h4 text-md-h3 font-weight-bold text-white ma-0">{{ title }}</h1>
            </div>
          </div>
          <p v-if="subtitle" class="text-body-1 text-white-soft mb-4 mt-2">{{ subtitle }}</p>
          <div class="d-flex flex-wrap ga-2">
            <slot name="chips" />
            <v-chip v-for="c in chips" :key="c.label" size="small"
                    color="rgba(255,255,255,0.18)" variant="flat" class="text-white">
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
  background:
    radial-gradient(circle at 0% 0%, rgba(255,255,255,0.18) 0%, transparent 45%),
    radial-gradient(circle at 100% 100%, rgba(255,255,255,0.08) 0%, transparent 50%),
    linear-gradient(135deg, #0d9488 0%, #0ea5a4 35%, #0284c7 100%);
  box-shadow: 0 18px 40px -18px rgba(13,148,136,0.55);
}
.hc-hero-inner { position: relative; z-index: 2; }
.hc-hero-icon {
  background: rgba(255,255,255,0.18) !important;
  backdrop-filter: blur(12px);
  border: 1px solid rgba(255,255,255,0.28);
}
.text-white-soft { color: rgba(255,255,255,0.82) !important; }
.hc-hero-clock {
  display: inline-flex; align-items: center;
  padding: 4px 10px; border-radius: 999px;
  background: rgba(255,255,255,0.16);
  color: white; font-size: 12px; font-weight: 500;
  backdrop-filter: blur(8px);
  border: 1px solid rgba(255,255,255,0.22);
}
.hc-hero-decor {
  position: absolute; right: -120px; top: -120px;
  width: 360px; height: 360px; border-radius: 50%;
  background: radial-gradient(circle, rgba(255,255,255,0.12), transparent 70%);
  pointer-events: none;
}
</style>
