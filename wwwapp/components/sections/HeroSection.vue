<template>
  <section class="relative isolate overflow-hidden pt-28 sm:pt-36">
    <!-- background grid + glows -->
    <div class="absolute inset-0 -z-10 grid-pattern opacity-60"></div>
    <div class="absolute -top-40 right-0 -z-10 h-[40rem] w-[40rem] rounded-full bg-brand-600/20 blur-[120px]"></div>
    <div class="absolute -left-40 top-40 -z-10 h-[32rem] w-[32rem] rounded-full bg-cyanx-500/10 blur-[120px]"></div>

    <div class="container-xl">
      <div class="grid items-center gap-14 lg:grid-cols-[1.05fr_1fr]">
        <!-- copy -->
        <div class="reveal">
          <span class="eyebrow">
            <span class="h-1.5 w-1.5 rounded-full bg-emerald-400"></span>
            Africa's Healthcare Operating System
          </span>

          <h1 class="mt-6 font-display text-4xl font-extrabold leading-[1.05] tracking-tight text-white sm:text-6xl">
            Connected Healthcare.
            <span class="gradient-text">Simplified.</span>
          </h1>

          <p class="mt-6 max-w-xl text-lg leading-relaxed text-slate-300">
            AdhereMed unifies patients, doctors, hospitals, pharmacies, labs, radiology, homecare,
            insurance and government into a single intelligent platform — improving medication
            adherence, care coordination and population health across Africa.
          </p>

          <div class="mt-9 flex flex-wrap items-center gap-3">
            <a :href="webAppUrl" target="_blank" rel="noopener" class="btn-primary">
              Launch the platform
              <svg class="h-4 w-4" viewBox="0 0 20 20" fill="none">
                <path d="M5 10h10m0 0-4-4m4 4-4 4" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" />
              </svg>
            </a>
            <NuxtLink to="/#ecosystem" class="btn-ghost">Explore the ecosystem</NuxtLink>
          </div>

          <dl class="mt-12 grid max-w-lg grid-cols-3 gap-6">
            <div v-for="stat in heroStats" :key="stat.label">
              <dt class="font-display text-2xl font-extrabold text-white sm:text-3xl">{{ stat.value }}</dt>
              <dd class="mt-1 text-xs leading-snug text-slate-400">{{ stat.label }}</dd>
            </div>
          </dl>
        </div>

        <!-- ecosystem visual -->
        <div class="reveal" style="transition-delay: 120ms">
          <EcosystemDiagram />
        </div>
      </div>

      <!-- trust strip -->
      <div class="reveal mt-16 border-y border-white/10 py-6">
        <p class="text-center text-xs uppercase tracking-[0.22em] text-slate-500">
          One platform connecting every actor in the care journey
        </p>
        <div class="mt-5 flex flex-wrap items-center justify-center gap-x-8 gap-y-3 text-sm font-semibold text-slate-400">
          <span v-for="actor in actors" :key="actor" class="transition hover:text-white">{{ actor }}</span>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup>
const { webAppUrl } = useAppLinks()

const heroStats = [
  { value: '9+', label: 'Connected ecosystem actors' },
  { value: '91%', label: 'Avg. medication adherence' },
  { value: '99.98%', label: 'Platform API uptime' }
]

const actors = ['Patients', 'Doctors', 'Hospitals', 'Pharmacies', 'Laboratories', 'Radiology', 'Homecare', 'Insurance', 'Government']
</script>
