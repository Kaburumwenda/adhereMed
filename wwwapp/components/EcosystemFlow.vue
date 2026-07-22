<template>
  <div class="reveal relative mx-auto max-w-md">
    <!-- vertical glowing spine -->
    <div class="pointer-events-none absolute left-1/2 top-0 h-full w-px -translate-x-1/2 bg-gradient-to-b from-brand-500/10 via-brand-400/60 to-cyanx-400/80"></div>
    <div class="pointer-events-none absolute left-1/2 top-0 h-full w-px -translate-x-1/2 overflow-hidden">
      <span class="flow-spark"></span>
    </div>

    <ol class="relative space-y-3">
      <li
        v-for="(step, i) in steps"
        :key="step.label"
        class="reveal"
        :style="{ transitionDelay: i * 70 + 'ms' }"
      >
        <div class="group relative flex items-center gap-4 rounded-2xl border border-white/10 bg-white/[0.04] p-4 backdrop-blur transition hover:border-brand-400/40 hover:bg-white/[0.07]">
          <span class="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-brand-500/15 text-brand-300 ring-1 ring-inset ring-brand-400/30" v-html="step.icon"></span>
          <div class="min-w-0">
            <p class="font-display text-sm font-bold text-white">{{ step.label }}</p>
            <p class="truncate text-xs text-slate-400">{{ step.desc }}</p>
          </div>
          <span class="ml-auto text-[10px] font-semibold uppercase tracking-wider text-slate-600">{{ String(i + 1).padStart(2, '0') }}</span>
        </div>
      </li>
    </ol>

    <!-- cloud sink -->
    <div class="reveal relative mt-3 flex justify-center" style="transition-delay: 600ms">
      <div class="flex items-center gap-3 rounded-2xl border border-brand-400/40 bg-gradient-to-r from-brand-600 to-brand-500 px-6 py-4 shadow-glow">
        <svg class="h-7 w-7 text-white" viewBox="0 0 24 24" fill="currentColor"><path d="M6 19a4 4 0 0 1-.6-7.95 5.5 5.5 0 0 1 10.7-1.2A4 4 0 1 1 17 19z"/></svg>
        <div>
          <p class="font-display text-sm font-extrabold text-white">AdhereMed Cloud</p>
          <p class="text-xs text-brand-100">Unified, secure, interoperable</p>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
const steps = [
  { label: 'Patient', desc: 'Engagement, reminders & adherence', icon: '<svg class="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><circle cx="12" cy="8" r="4"/><path d="M5 21a7 7 0 0 1 14 0"/></svg>' },
  { label: 'Doctor', desc: 'Telemedicine & digital prescriptions', icon: '<svg class="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><circle cx="12" cy="7" r="3.5"/><path d="M6 21v-1a6 6 0 0 1 12 0v1"/><path d="M16 12v3a3 3 0 0 0 6 0v-2"/><circle cx="22" cy="13" r="1"/></svg>' },
  { label: 'Hospital', desc: 'Admissions, EMR & care coordination', icon: '<svg class="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><rect x="4" y="5" width="16" height="16" rx="2"/><path d="M12 9v6M9 12h6"/></svg>' },
  { label: 'Pharmacy', desc: 'e-Prescriptions & dispensing', icon: '<svg class="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><rect x="4" y="4" width="16" height="16" rx="5"/><path d="M5 5l14 14"/></svg>' },
  { label: 'Laboratory', desc: 'Orders, results & diagnostics', icon: '<svg class="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M9 3h6M10 3v6l-4 9a2 2 0 0 0 2 3h8a2 2 0 0 0 2-3l-4-9V3"/></svg>' },
  { label: 'Insurance', desc: 'Claims, approvals & coverage', icon: '<svg class="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M12 3l8 3v6c0 5-4 8-8 9-4-1-8-4-8-9V6z"/><path d="M9 12l2 2 4-4"/></svg>' },
  { label: 'Government', desc: 'Regulation, reporting & policy', icon: '<svg class="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M12 3l9 5H3z"/><path d="M5 8v9h14V8M9 8v9M15 8v9"/></svg>' },
  { label: 'Population Analytics', desc: 'Insights, trends & public health', icon: '<svg class="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M4 20V10M9 20V4M14 20v-7M19 20V8"/></svg>' }
]
</script>

<style scoped>
.flow-spark {
  position: absolute;
  left: 50%;
  top: -20%;
  height: 22%;
  width: 100%;
  transform: translateX(-50%);
  background: linear-gradient(to bottom, transparent, #37d6ff, transparent);
  filter: blur(1px);
  animation: flowDown 2.8s linear infinite;
}
@keyframes flowDown {
  0% { top: -25%; opacity: 0; }
  15% { opacity: 1; }
  85% { opacity: 1; }
  100% { top: 100%; opacity: 0; }
}
</style>
