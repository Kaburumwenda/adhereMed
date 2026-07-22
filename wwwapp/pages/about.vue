<template>
  <div class="pt-28 sm:pt-32">
    <section class="container-xl">
      <div class="grid items-center gap-12 lg:grid-cols-2">
        <div class="reveal">
          <span class="eyebrow"><span class="h-1.5 w-1.5 rounded-full bg-brand-400"></span> About AdhereMed</span>
          <h1 class="mt-5 font-display text-4xl font-extrabold leading-tight text-white sm:text-5xl">
            The digital infrastructure connecting <span class="gradient-text">healthcare across Africa</span>
          </h1>
          <p class="mt-6 text-lg leading-relaxed text-slate-300">
            AdhereMed's SaaS platform is a full healthcare ecosystem hub — connecting patients,
            doctors, hospitals, pharmacies, labs, radiology, homecare and insurance into one unified
            system. We replace fragmented, paper-based processes with intelligent, connected workflows.
          </p>
        </div>
        <div class="reveal" style="transition-delay: 120ms">
          <EcosystemDiagram />
        </div>
      </div>
    </section>

    <!-- Mission / Vision -->
    <section id="mission" class="section scroll-mt-24">
      <div class="container-xl grid gap-6 md:grid-cols-2">
        <div class="reveal card relative overflow-hidden">
          <div class="absolute -right-10 -top-10 h-40 w-40 rounded-full bg-brand-500/20 blur-2xl"></div>
          <span class="eyebrow"><span class="h-1.5 w-1.5 rounded-full bg-brand-400"></span> Mission</span>
          <p class="mt-5 font-display text-xl font-bold leading-relaxed text-white sm:text-2xl">
            To connect Africa's fragmented healthcare ecosystem through one intelligent digital
            platform that improves medication adherence, care coordination, telemedicine, digital
            prescriptions, patient engagement and population health.
          </p>
        </div>
        <div class="reveal card relative overflow-hidden" style="transition-delay: 100ms">
          <div class="absolute -right-10 -top-10 h-40 w-40 rounded-full bg-cyanx-500/20 blur-2xl"></div>
          <span class="eyebrow"><span class="h-1.5 w-1.5 rounded-full bg-cyanx-400"></span> Vision</span>
          <p class="mt-5 font-display text-xl font-bold leading-relaxed text-white sm:text-2xl">
            Become Africa's healthcare operating system — the digital backbone every patient, provider
            and payer relies on.
          </p>
        </div>
      </div>
    </section>

    <!-- Values -->
    <section class="section">
      <div class="container-xl">
        <SectionHeading center eyebrow="What drives us" title="Principles behind the platform" />
        <div class="mt-14 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
          <div v-for="(v, i) in values" :key="v.title" class="card card-hover reveal" :style="{ transitionDelay: (i % 4) * 70 + 'ms' }">
            <span class="flex h-12 w-12 items-center justify-center rounded-2xl bg-brand-500/15 text-brand-300 ring-1 ring-inset ring-brand-400/30" v-html="v.icon"></span>
            <h3 class="mt-5 font-display text-base font-bold text-white">{{ v.title }}</h3>
            <p class="mt-2 text-sm text-slate-400">{{ v.desc }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- Impact stats -->
    <section class="section">
      <div class="container-xl">
        <div class="reveal grid gap-6 rounded-[2rem] border border-white/10 bg-white/[0.03] p-10 sm:grid-cols-4">
          <div v-for="s in stats" :key="s.label" class="text-center">
            <p class="font-display text-4xl font-extrabold text-white">{{ s.value }}</p>
            <p class="mt-2 text-sm text-slate-400">{{ s.label }}</p>
          </div>
        </div>
      </div>
    </section>

    <PageCta />
  </div>
</template>

<script setup>
useHead({ title: 'About — AdhereMed' })

const values = [
  { title: 'Interoperability', desc: 'Open standards so every system can connect and share data securely.', icon: ic('<path d="m8 6-6 6 6 6M16 6l6 6-6 6"/>') },
  { title: 'Patient-first', desc: 'Every workflow is designed to improve real patient outcomes and access.', icon: ic('<path d="M12 21s-7-4.5-9-9a4.5 4.5 0 0 1 9-2 4.5 4.5 0 0 1 9 2c-2 4.5-9 9-9 9Z"/>') },
  { title: 'Trust & security', desc: 'Privacy, consent and compliance built into the core of the platform.', icon: ic('<path d="M12 3l8 3v6c0 5-4 8-8 9-4-1-8-4-8-9V6z"/><path d="M9 12l2 2 4-4"/>') },
  { title: 'Built for Africa', desc: 'Designed for local realities — connectivity, languages and care models.', icon: ic('<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a15 15 0 0 1 0 18 15 15 0 0 1 0-18Z"/>') }
]

const stats = [
  { value: '9+', label: 'Ecosystem actors connected' },
  { value: '91%', label: 'Average adherence achieved' },
  { value: '99.98%', label: 'Platform uptime' },
  { value: '1', label: 'Unified healthcare cloud' }
]

function ic(path) {
  return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" class="h-6 w-6">${path}</svg>`
}
</script>
