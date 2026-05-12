<template>
  <div class="lj-wrap" :style="{ height: height + 'px' }">
    <svg v-if="runs.length" :viewBox="`0 0 ${W} ${H}`" preserveAspectRatio="none" class="lj-svg">
      <!-- background bands -->
      <rect :x="padL" :y="yFor(2)" :width="W - padL - padR" :height="yFor(-2) - yFor(2)"
            fill="rgba(67,160,71,0.08)" />
      <rect :x="padL" :y="yFor(3)" :width="W - padL - padR" :height="yFor(2) - yFor(3)"
            fill="rgba(251,140,0,0.10)" />
      <rect :x="padL" :y="yFor(-2)" :width="W - padL - padR" :height="yFor(-3) - yFor(-2)"
            fill="rgba(251,140,0,0.10)" />
      <rect :x="padL" :y="0" :width="W - padL - padR" :height="yFor(3)"
            fill="rgba(229,57,53,0.06)" />
      <rect :x="padL" :y="yFor(-3)" :width="W - padL - padR" :height="H - yFor(-3) - padB"
            fill="rgba(229,57,53,0.06)" />

      <!-- gridlines -->
      <g stroke="rgba(0,0,0,0.10)" stroke-width="1">
        <line v-for="g in [-3,-2,-1,0,1,2,3]" :key="g"
              :x1="padL" :x2="W - padR" :y1="yFor(g)" :y2="yFor(g)"
              :stroke-dasharray="g === 0 ? '' : '4 3'" />
      </g>

      <!-- axis labels -->
      <g font-size="10" fill="#666" font-family="ui-monospace,Menlo,monospace">
        <text v-for="g in [-3,-2,-1,0,1,2,3]" :key="g"
              :x="padL - 6" :y="yFor(g) + 3" text-anchor="end">{{ g }}sd</text>
      </g>

      <!-- line -->
      <polyline :points="linePoints" fill="none" stroke="#3949ab" stroke-width="1.5" />

      <!-- points -->
      <g>
        <circle v-for="(p, i) in points" :key="i"
                :cx="p.x" :cy="p.y" :r="3.5"
                :fill="p.color" stroke="#fff" stroke-width="1.5">
          <title>{{ p.tooltip }}</title>
        </circle>
      </g>
    </svg>
    <div v-else class="lj-empty d-flex flex-column align-center justify-center text-medium-emphasis pa-6">
      <v-icon size="40" color="grey-lighten-1">mdi-chart-line-variant</v-icon>
      <div class="mt-2 text-caption">No data available for chart.</div>
    </div>
  </div>
</template>

<script setup>
const props = defineProps({
  runs: { type: Array, default: () => [] },
  height: { type: Number, default: 220 },
})

const W = 600
const H = computed(() => props.height)
const padL = 36
const padR = 12
const padT = 10
const padB = 18

function yFor (sd) {
  // map sd in [-4, 4] → pixel y
  const top = padT
  const bot = H.value - padB
  const range = 8 // -4 .. +4
  const norm = (4 - sd) / range
  return top + norm * (bot - top)
}

const points = computed(() => {
  const n = props.runs.length
  if (!n) return []
  const innerW = W - padL - padR
  return props.runs.map((r, i) => {
    const sd = Number(r.sd)
    const sdSafe = Number.isNaN(sd) ? 0 : Math.max(-4, Math.min(4, sd))
    const x = padL + (n === 1 ? innerW / 2 : (i / (n - 1)) * innerW)
    const y = yFor(sdSafe)
    const color = r.result === 'fail' ? '#e53935'
      : r.result === 'warn' ? '#fb8c00' : '#43a047'
    const tooltip = `${new Date(r.run_at).toLocaleDateString()}  ` +
      `${r.measured_value || '—'} (${r.sd != null ? Number(r.sd).toFixed(2) + ' SD' : '—'}) · ${r.result}`
    return { x, y, color, tooltip }
  })
})

const linePoints = computed(() => points.value.map(p => `${p.x},${p.y}`).join(' '))
</script>

<style scoped>
.lj-wrap {
  width: 100%;
  background: rgba(0, 0, 0, 0.02);
  border: 1px solid rgba(0, 0, 0, 0.06);
  border-radius: 8px;
}
.lj-svg { width: 100%; height: 100%; display: block; }
.lj-empty { height: 100%; }
</style>
