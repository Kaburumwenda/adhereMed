<template>
  <div class="pt-28 sm:pt-32">
    <section class="container-xl text-center">
      <div class="reveal mx-auto max-w-3xl">
        <span class="eyebrow"><span class="h-1.5 w-1.5 rounded-full bg-brand-400"></span> Pricing</span>
        <h1 class="mt-5 font-display text-4xl font-extrabold leading-tight text-white sm:text-5xl">
          Transparent, <span class="gradient-text">usage-based pricing</span>
        </h1>
        <p class="mt-6 text-lg leading-relaxed text-slate-300">
          No tiers to outgrow, no surprises. You pay only for the API requests you use — a flat
          <span class="font-semibold text-white"> $0.077 per 1,000 requests</span>.
        </p>
      </div>

      <!-- headline rate cards -->
      <div class="reveal mx-auto mt-12 grid max-w-3xl gap-4 sm:grid-cols-3">
        <div v-for="r in rateCards" :key="r.label" class="card text-center">
          <p class="text-xs uppercase tracking-wider text-slate-500">{{ r.label }}</p>
          <p class="mt-2 font-display text-2xl font-extrabold text-white">{{ r.value }}</p>
        </div>
      </div>
    </section>

    <section class="section">
      <div class="container-xl">
        <SectionHeading center eyebrow="Estimate your cost" title="Model your usage in real time">
          Drag the slider to project monthly and annual spend, and see exactly how cost scales with
          volume.
        </SectionHeading>
        <div class="reveal mt-12">
          <PricingCalculator />
        </div>
      </div>
    </section>

    <!-- What's included -->
    <section class="section">
      <div class="container-xl">
        <SectionHeading center eyebrow="Every plan includes" title="The full platform, no add-ons" />
        <div class="mt-12 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          <div v-for="(item, i) in included" :key="item.title" class="card card-hover reveal" :style="{ transitionDelay: (i % 3) * 70 + 'ms' }">
            <span class="flex h-11 w-11 items-center justify-center rounded-xl bg-brand-500/15 text-brand-300 ring-1 ring-inset ring-brand-400/30" v-html="item.icon"></span>
            <h3 class="mt-4 font-display text-base font-bold text-white">{{ item.title }}</h3>
            <p class="mt-2 text-sm text-slate-400">{{ item.desc }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- FAQ -->
    <section class="section">
      <div class="container-xl max-w-3xl">
        <SectionHeading center eyebrow="FAQ" title="Pricing questions, answered" />
        <div class="mt-10 space-y-3">
          <details v-for="(f, i) in faqs" :key="i" class="reveal group rounded-2xl border border-white/10 bg-white/[0.03] p-5">
            <summary class="flex cursor-pointer list-none items-center justify-between font-display text-base font-semibold text-white">
              {{ f.q }}
              <svg class="h-5 w-5 text-brand-400 transition group-open:rotate-45" viewBox="0 0 20 20" fill="none"><path d="M10 5v10M5 10h10" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>
            </summary>
            <p class="mt-3 text-sm leading-relaxed text-slate-400">{{ f.a }}</p>
          </details>
        </div>
      </div>
    </section>

    <PageCta title="Start building on AdhereMed" subtitle="Connect to the API and only pay for what you use." />
  </div>
</template>

<script setup>
useHead({ title: 'Pricing — AdhereMed' })

const rateCards = [
  { label: 'Per 1,000 requests', value: '$0.077' },
  { label: 'Per request', value: '$0.000077' },
  { label: 'Per 1M requests', value: '$77.00' }
]

const included = [
  { title: 'Full API access', desc: 'Every endpoint across the ecosystem with the same simple rate.', icon: ic('<path d="m8 6-6 6 6 6M16 6l6 6-6 6"/>') },
  { title: 'All dashboards', desc: 'Role-based dashboards and analytics for every stakeholder.', icon: ic('<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18M9 21V9"/>') },
  { title: 'Usage analytics', desc: 'Real-time request and cost tracking down to the endpoint.', icon: ic('<path d="M4 20V10M9 20V4M14 20v-7M19 20V8"/>') },
  { title: 'Security & compliance', desc: 'Encryption, consent management and audit logs by default.', icon: ic('<path d="M12 3l8 3v6c0 5-4 8-8 9-4-1-8-4-8-9V6z"/><path d="M9 12l2 2 4-4"/>') },
  { title: 'Webhooks & events', desc: 'Subscribe to real-time events across the care workflow.', icon: ic('<circle cx="12" cy="12" r="3"/><path d="M12 3v3M12 18v3M21 12h-3M6 12H3"/>') },
  { title: 'Support & SLAs', desc: '99.98% uptime with technical support for your integration.', icon: ic('<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>') }
]

const faqs = [
  { q: 'How is billing calculated?', a: 'Every 1,000 API requests costs $0.077. Your monthly bill is simply the number of requests you made, divided by 1,000, multiplied by $0.077.' },
  { q: 'Are there minimums or tiers?', a: 'No. Pricing is fully usage-based and linear — you pay only for what you use, whether that is a thousand requests or a hundred million.' },
  { q: 'What counts as a request?', a: 'Each API call to an AdhereMed endpoint counts as one request. Dashboards and standard analytics views are included.' },
  { q: 'Do unused requests roll over?', a: 'There is nothing to roll over — you are billed on actual usage each month, so there are never wasted prepaid credits.' },
  { q: 'Can I forecast my spend?', a: 'Yes. Use the estimator above, and inside the platform you get live usage analytics and projected monthly cost.' }
]

function ic(path) {
  return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" class="h-6 w-6">${path}</svg>`
}
</script>
