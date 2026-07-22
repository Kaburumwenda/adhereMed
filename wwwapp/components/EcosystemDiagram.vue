<template>
  <div class="relative mx-auto w-full max-w-3xl select-none">
    <svg
      viewBox="0 0 600 600"
      class="h-auto w-full"
      role="img"
      aria-label="AdhereMed connected healthcare ecosystem diagram"
    >
      <defs>
        <radialGradient id="eco-core" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stop-color="#8ebcff" />
          <stop offset="55%" stop-color="#2f6dff" />
          <stop offset="100%" stop-color="#143ce1" />
        </radialGradient>
        <linearGradient id="eco-line" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%" stop-color="#37d6ff" stop-opacity="0.05" />
          <stop offset="100%" stop-color="#5996ff" stop-opacity="0.9" />
        </linearGradient>
        <filter id="eco-glow" x="-60%" y="-60%" width="220%" height="220%">
          <feGaussianBlur stdDeviation="6" result="b" />
          <feMerge>
            <feMergeNode in="b" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
        <radialGradient id="eco-halo" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stop-color="#2f6dff" stop-opacity="0.35" />
          <stop offset="100%" stop-color="#2f6dff" stop-opacity="0" />
        </radialGradient>
      </defs>

      <!-- ambient halo -->
      <circle cx="300" cy="300" r="290" fill="url(#eco-halo)" />

      <!-- orbit rings -->
      <g class="origin-center animate-spinSlow" style="transform-box: fill-box;">
        <circle cx="300" cy="300" r="210" fill="none" stroke="rgba(255,255,255,0.06)" stroke-width="1" stroke-dasharray="2 8" />
      </g>
      <circle cx="300" cy="300" r="150" fill="none" stroke="rgba(89,150,255,0.12)" stroke-width="1" />

      <!-- connection lines + flowing packets -->
      <g>
        <g v-for="(node, i) in nodes" :key="'line-' + i">
          <line
            :x1="node.x"
            :y1="node.y"
            x2="300"
            y2="300"
            stroke="url(#eco-line)"
            stroke-width="1.6"
            stroke-linecap="round"
          />
          <!-- glowing flow -->
          <line
            :x1="node.x"
            :y1="node.y"
            x2="300"
            y2="300"
            stroke="#37d6ff"
            stroke-width="2.4"
            stroke-linecap="round"
            stroke-dasharray="4 26"
            class="animate-dash"
            :style="{ animationDelay: i * -0.4 + 's', opacity: 0.85 }"
          />
          <!-- traveling packet -->
          <circle r="3.4" fill="#bcd7ff" filter="url(#eco-glow)">
            <animateMotion
              :path="`M ${node.x} ${node.y} L 300 300`"
              :dur="2.6 + (i % 3) * 0.5 + 's'"
              repeatCount="indefinite"
              :begin="i * 0.32 + 's'"
            />
          </circle>
        </g>
      </g>

      <!-- nodes -->
      <g v-for="(node, i) in nodes" :key="'node-' + i" class="cursor-default">
        <circle :cx="node.x" :cy="node.y" r="34" fill="url(#eco-halo)" />
        <circle
          :cx="node.x"
          :cy="node.y"
          r="26"
          fill="#0b1226"
          stroke="rgba(89,150,255,0.5)"
          stroke-width="1.5"
        />
        <g :style="{ '--d': i * 0.25 + 's' }" class="eco-icon" v-html="iconMarkup(node, node.x, node.y)" />
        <text
          :x="node.x"
          :y="node.labelBelow ? node.y + 48 : node.y - 40"
          text-anchor="middle"
          class="fill-slate-300 font-display"
          style="font-size: 13px; font-weight: 600"
        >
          {{ node.label }}
        </text>
      </g>

      <!-- central AdhereMed cloud -->
      <g filter="url(#eco-glow)">
        <circle cx="300" cy="300" r="62" fill="url(#eco-core)" />
        <circle cx="300" cy="300" r="62" fill="none" stroke="rgba(255,255,255,0.35)" stroke-width="1.5" />
      </g>
      <g class="animate-pulseGlow">
        <circle cx="300" cy="300" r="76" fill="none" stroke="#37d6ff" stroke-width="1.2" stroke-opacity="0.5" />
      </g>
      <!-- cloud glyph -->
      <path
        d="M276 308a14 14 0 0 1 4-27 18 18 0 0 1 35 3 12 12 0 0 1 1 24z"
        fill="#fff"
        fill-opacity="0.95"
        transform="translate(0 -4)"
      />
      <text x="300" y="326" text-anchor="middle" class="fill-white font-display" style="font-size: 13px; font-weight: 800; letter-spacing: 0.04em">
        AdhereMed
      </text>
    </svg>

    <p class="mt-2 text-center text-xs text-slate-500">
      Live data flowing across every node into the AdhereMed cloud
    </p>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const labels = [
  'Patient',
  'Doctor',
  'Hospital',
  'Pharmacy',
  'Laboratory',
  'Insurance',
  'Government',
  'Analytics'
]

const icons = {
  Patient: '<path d="M0 6a4 4 0 1 0 0-8 4 4 0 0 0 0 8M-7 12a7 7 0 0 1 14 0" />',
  Doctor: '<path d="M0 5a4 4 0 1 0 0-8 4 4 0 0 0 0 8M-6 12v-1a6 6 0 0 1 12 0v1" /><path d="M3 8v3a3 3 0 0 0 6 0V9" /><circle cx="9" cy="9" r="1.4" />',
  Hospital: '<rect x="-8" y="-7" width="16" height="15" rx="2" /><path d="M0 -3v8M-4 1h8" stroke-width="2" />',
  Pharmacy: '<rect x="-7" y="-7" width="14" height="14" rx="4" /><path d="M-7 0h14M0 -7v14" stroke-width="2" />',
  Laboratory: '<path d="M-3 -7h6M-2 -7v6l-4 9a2 2 0 0 0 2 3h8a2 2 0 0 0 2-3l-4-9v-6" /><circle cx="0" cy="6" r="1.2" />',
  Insurance: '<path d="M0 -8 8 -5v6c0 5-4 8-8 9-4-1-8-4-8-9v-6z" /><path d="M-3 0l2 2 4-4" stroke-width="1.8" />',
  Government: '<path d="M0 -8 9 -3H-9zM-7 -1h14v9H-7z" /><path d="M-4 -1v9M0 -1v9M4 -1v9" />',
  Analytics: '<path d="M-8 8V-2M-3 8V0M2 8V-5M7 8V-3" stroke-width="2.4" stroke-linecap="round" />'
}

const nodes = computed(() => {
  const cx = 300
  const cy = 300
  const r = 210
  return labels.map((label, i) => {
    // start at top, go clockwise
    const angle = (-90 + i * (360 / labels.length)) * (Math.PI / 180)
    const x = cx + r * Math.cos(angle)
    const y = cy + r * Math.sin(angle)
    return { label, x: Math.round(x), y: Math.round(y), labelBelow: y > cy }
  })
})

function iconMarkup(node, x, y) {
  const path = icons[node.label] || ''
  return `<g transform="translate(${x} ${y})" fill="none" stroke="#8ebcff" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round">${path}</g>`
}
</script>

<style scoped>
.eco-icon {
  animation: floaty 6s ease-in-out infinite;
  animation-delay: var(--d);
  transform-box: fill-box;
  transform-origin: center;
}
</style>
