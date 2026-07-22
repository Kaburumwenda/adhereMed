<template>
  <div>
    <HeroSection />

    <!-- ECOSYSTEM -->
    <section id="ecosystem" class="section scroll-mt-24">
      <div class="container-xl">
        <div class="grid items-center gap-14 lg:grid-cols-2">
          <SectionHeading eyebrow="The AdhereMed Ecosystem" title="Every actor. One intelligent flow.">
            Healthcare in Africa is fragmented across disconnected systems. AdhereMed links them into a
            single flow — from the patient all the way to population analytics — with secure data
            flowing into one unified cloud.
            <div class="mt-8 grid grid-cols-2 gap-4">
              <div v-for="item in highlights" :key="item.title" class="rounded-2xl border border-white/10 bg-white/[0.03] p-4">
                <p class="font-display text-2xl font-extrabold text-white">{{ item.stat }}</p>
                <p class="mt-1 text-xs text-slate-400">{{ item.title }}</p>
              </div>
            </div>
          </SectionHeading>

          <div class="reveal" style="transition-delay: 120ms">
            <EcosystemFlow />
          </div>
        </div>
      </div>
    </section>

    <!-- MISSION / VISION -->
    <section class="section">
      <div class="container-xl">
        <div class="grid gap-6 md:grid-cols-2">
          <div class="reveal card relative overflow-hidden">
            <div class="absolute -right-10 -top-10 h-40 w-40 rounded-full bg-brand-500/20 blur-2xl"></div>
            <span class="eyebrow"><span class="h-1.5 w-1.5 rounded-full bg-brand-400"></span> Our Mission</span>
            <p class="mt-5 font-display text-xl font-bold leading-relaxed text-white sm:text-2xl">
              To connect Africa's fragmented healthcare ecosystem through one intelligent digital
              platform that improves medication adherence, care coordination, telemedicine, digital
              prescriptions, patient engagement and population health.
            </p>
          </div>
          <div class="reveal card relative overflow-hidden" style="transition-delay: 100ms">
            <div class="absolute -right-10 -top-10 h-40 w-40 rounded-full bg-cyanx-500/20 blur-2xl"></div>
            <span class="eyebrow"><span class="h-1.5 w-1.5 rounded-full bg-cyanx-400"></span> Our Vision</span>
            <p class="mt-5 font-display text-xl font-bold leading-relaxed text-white sm:text-2xl">
              Become Africa's healthcare operating system — the digital infrastructure every patient,
              provider and payer relies on.
            </p>
            <p class="mt-6 font-display text-sm font-semibold text-brand-300">Connected Healthcare. Simplified.</p>
          </div>
        </div>
      </div>
    </section>

    <!-- FEATURES -->
    <section id="features" class="section scroll-mt-24">
      <div class="container-xl">
        <SectionHeading center eyebrow="Platform Capabilities" title="A full healthcare hub in one platform">
          Dashboards, workflows and integrations that simplify healthcare delivery for every actor in
          the ecosystem.
        </SectionHeading>

        <div class="mt-14 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          <FeatureCard
            v-for="(f, i) in features"
            :key="f.title"
            :title="f.title"
            :desc="f.desc"
            :icon="f.icon"
            :style="{ transitionDelay: (i % 3) * 80 + 'ms' }"
          />
        </div>
      </div>
    </section>

    <!-- DASHBOARDS -->
    <section id="dashboards" class="section scroll-mt-24">
      <div class="container-xl">
        <div class="grid items-center gap-14 lg:grid-cols-2">
          <div class="reveal order-2 lg:order-1">
            <DashboardPreview />
          </div>
          <div class="order-1 lg:order-2">
            <SectionHeading eyebrow="Clean, actionable dashboards" title="See the whole system at a glance">
              Purpose-built dashboards turn raw activity into decisions — adherence trends, API usage,
              claims throughput and population-health signals, all in real time.
              <ul class="mt-8 space-y-3">
                <li v-for="point in dashPoints" :key="point" class="flex items-start gap-3 text-slate-300">
                  <svg class="mt-0.5 h-5 w-5 shrink-0 text-brand-400" viewBox="0 0 20 20" fill="none"><path d="m5 10 3 3 7-7" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>
                  <span class="text-sm">{{ point }}</span>
                </li>
              </ul>
            </SectionHeading>
          </div>
        </div>
      </div>
    </section>

    <!-- SOLUTIONS -->
    <section id="solutions" class="section scroll-mt-24">
      <div class="container-xl">
        <SectionHeading center eyebrow="Built for every stakeholder" title="Solutions across the care continuum" />
        <div class="mt-14 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
          <NuxtLink
            v-for="(s, i) in solutions"
            :key="s.id"
            :to="`/solutions#${s.id}`"
            class="card card-hover reveal group"
            :style="{ transitionDelay: (i % 4) * 70 + 'ms' }"
          >
            <span class="flex h-11 w-11 items-center justify-center rounded-xl bg-brand-500/15 text-brand-300 ring-1 ring-inset ring-brand-400/30 transition group-hover:bg-brand-500 group-hover:text-white" v-html="s.icon"></span>
            <h3 class="mt-4 font-display text-base font-bold text-white">{{ s.audience }}</h3>
            <p class="mt-1.5 text-xs leading-relaxed text-slate-400">{{ s.headline }}</p>
            <span class="mt-3 inline-flex items-center gap-1 text-xs font-semibold text-brand-300">
              Explore
              <svg class="h-3.5 w-3.5 transition group-hover:translate-x-0.5" viewBox="0 0 20 20" fill="none"><path d="M5 10h10m0 0-4-4m4 4-4 4" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>
            </span>
          </NuxtLink>
        </div>
      </div>
    </section>

    <!-- PRICING TEASER -->
    <section class="section">
      <div class="container-xl">
        <SectionHeading center eyebrow="Usage-based pricing" title="Pay only for what you use">
          Simple, transparent API pricing at <span class="font-semibold text-white">$0.077 per 1,000 requests</span>.
          Model your costs in real time.
        </SectionHeading>
        <div class="reveal mt-12">
          <PricingCalculator />
        </div>
        <div class="reveal mt-8 text-center">
          <NuxtLink to="/pricing" class="btn-ghost">See full pricing details</NuxtLink>
        </div>
      </div>
    </section>

    <AppDownloadSection />

    <!-- FINAL CTA -->
    <section class="section">
      <div class="container-xl">
        <div class="reveal relative overflow-hidden rounded-[2rem] border border-brand-400/30 bg-gradient-to-br from-brand-600 to-brand-700 p-10 text-center sm:p-16">
          <div class="absolute inset-0 grid-pattern opacity-20"></div>
          <div class="relative">
            <h2 class="font-display text-3xl font-extrabold text-white sm:text-4xl">
              Ready to connect your healthcare?
            </h2>
            <p class="mx-auto mt-4 max-w-xl text-brand-100">
              Join the platform building Africa's healthcare operating system.
            </p>
            <div class="mt-8 flex flex-wrap justify-center gap-3">
              <a :href="webAppUrl" target="_blank" rel="noopener" class="btn bg-white text-brand-700 hover:bg-brand-50">Launch the platform</a>
              <NuxtLink to="/contact" class="btn border border-white/40 text-white hover:bg-white/10">Talk to our team</NuxtLink>
            </div>
          </div>
        </div>
      </div>
    </section>
  </div>
</template>

<script setup>
const { webAppUrl } = useAppLinks()
const features = usePlatformFeatures()
const solutions = useSolutions().slice(0, 8)

const highlights = [
  { stat: '9+', title: 'Connected actor types' },
  { stat: '1', title: 'Unified secure cloud' },
  { stat: 'Real-time', title: 'Data interoperability' },
  { stat: '24/7', title: 'Population monitoring' }
]

const dashPoints = [
  'Live medication-adherence and engagement metrics',
  'API usage and cost tracking down to the request',
  'Claims, referrals and diagnostics throughput',
  'Predictive population-health and outbreak signals'
]
</script>
