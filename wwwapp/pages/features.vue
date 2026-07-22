<template>
  <div class="pt-28 sm:pt-32">
    <section class="container-xl text-center">
      <div class="reveal mx-auto max-w-3xl">
        <span class="eyebrow"><span class="h-1.5 w-1.5 rounded-full bg-brand-400"></span> Platform</span>
        <h1 class="mt-5 font-display text-4xl font-extrabold leading-tight text-white sm:text-5xl">
          A complete <span class="gradient-text">healthcare operating system</span>
        </h1>
        <p class="mt-6 text-lg leading-relaxed text-slate-300">
          Everything you need to deliver connected care — dashboards, workflows and integrations that
          unify the entire ecosystem.
        </p>
      </div>
    </section>

    <!-- Feature grid -->
    <section class="section">
      <div class="container-xl">
        <div class="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          <FeatureCard
            v-for="(f, i) in features"
            :key="f.title"
            :title="f.title"
            :desc="f.desc"
            :icon="f.icon"
            :style="{ transitionDelay: (i % 3) * 70 + 'ms' }"
          />
        </div>
      </div>
    </section>

    <!-- Dashboards -->
    <section id="dashboards" class="section scroll-mt-24">
      <div class="container-xl grid items-center gap-14 lg:grid-cols-2">
        <div class="reveal"><DashboardPreview /></div>
        <SectionHeading eyebrow="Dashboards" title="Decisions, not just data">
          Real-time, role-based dashboards give every actor exactly the view they need — from a
          patient's adherence streak to a ministry's outbreak map.
          <ul class="mt-8 space-y-3">
            <li v-for="p in dashPoints" :key="p" class="flex items-start gap-3 text-slate-300">
              <svg class="mt-0.5 h-5 w-5 shrink-0 text-brand-400" viewBox="0 0 20 20" fill="none"><path d="m5 10 3 3 7-7" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>
              <span class="text-sm">{{ p }}</span>
            </li>
          </ul>
        </SectionHeading>
      </div>
    </section>

    <!-- Integrations / Ecosystem -->
    <section id="integrations" class="section scroll-mt-24">
      <div class="container-xl grid items-center gap-14 lg:grid-cols-2">
        <SectionHeading eyebrow="Integrations" title="Connect anything, securely">
          An open, developer-first API layer lets hospitals, pharmacies, insurers and government
          systems plug straight into AdhereMed — with usage-based billing and full audit trails.
          <div class="mt-8 flex flex-wrap gap-2">
            <span v-for="tag in integrations" :key="tag" class="rounded-full border border-white/10 bg-white/5 px-3 py-1.5 text-xs font-semibold text-slate-300">{{ tag }}</span>
          </div>
          <NuxtLink to="/pricing" class="btn-primary mt-8">View API pricing</NuxtLink>
        </SectionHeading>
        <div class="reveal"><EcosystemFlow /></div>
      </div>
    </section>

    <PageCta />
  </div>
</template>

<script setup>
useHead({ title: 'Platform & Features — AdhereMed' })
const features = usePlatformFeatures()

const dashPoints = [
  'Medication adherence and patient-engagement metrics',
  'Live API usage and cost analytics',
  'Claims, referrals and diagnostics throughput',
  'Predictive population-health and outbreak signals'
]

const integrations = ['EMR / EHR', 'Pharmacy POS', 'Lab systems (LIS)', 'Radiology (PACS)', 'Insurance / claims', 'Payments', 'SMS & USSD', 'Government registries']
</script>
