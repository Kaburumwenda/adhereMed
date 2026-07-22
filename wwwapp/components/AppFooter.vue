<template>
  <footer class="relative mt-10 border-t border-white/10 bg-ink-950">
    <div class="container-xl py-16">
      <div class="grid gap-12 lg:grid-cols-[1.4fr_1fr_1fr_1fr]">
        <div>
          <AppLogo />
          <p class="mt-5 max-w-xs text-sm leading-relaxed text-slate-400">
            Africa's healthcare operating system — connecting patients, providers and payers into one
            intelligent digital platform.
          </p>
          <p class="mt-5 font-display text-sm font-semibold text-brand-300">
            Connected Healthcare. Simplified.
          </p>

          <div class="mt-6 flex flex-col gap-3 sm:flex-row">
            <a :href="webAppUrl" target="_blank" rel="noopener" class="group flex items-center gap-3 rounded-2xl border border-white/10 bg-white/5 px-4 py-2.5 transition hover:border-brand-400/40">
              <svg class="h-6 w-6 text-brand-300" viewBox="0 0 24 24" fill="currentColor"><path d="M3 4a1 1 0 0 1 1.5-.87l15 8a1 1 0 0 1 0 1.74l-15 8A1 1 0 0 1 3 20z"/></svg>
              <span class="text-left leading-tight">
                <span class="block text-[10px] uppercase tracking-wider text-slate-400">Open the</span>
                <span class="block text-sm font-semibold text-white">Web Platform</span>
              </span>
            </a>
            <div class="group flex cursor-not-allowed items-center gap-3 rounded-2xl border border-white/10 bg-white/5 px-4 py-2.5 opacity-70">
              <svg class="h-6 w-6 text-slate-300" viewBox="0 0 24 24" fill="currentColor"><path d="M17.6 13.8c0-2 1.6-3 1.7-3a3.7 3.7 0 0 0-2.9-1.6c-1.2-.1-2.4.7-3 .7s-1.6-.7-2.6-.7A4 4 0 0 0 7.4 11c-1.5 2.6-.4 6.4 1 8.5.7 1 1.5 2.2 2.6 2.1s1.4-.7 2.7-.7 1.6.7 2.7.7 1.8-1 2.5-2a8 8 0 0 0 1.1-2.3 3.5 3.5 0 0 1-2.4-3.5M15.5 6.8A3.6 3.6 0 0 0 16.3 4a3.7 3.7 0 0 0-2.4 1.2 3.4 3.4 0 0 0-.9 2.7 3 3 0 0 0 2.5-1.1"/></svg>
              <span class="text-left leading-tight">
                <span class="block text-[10px] uppercase tracking-wider text-slate-400">Mobile apps</span>
                <span class="block text-sm font-semibold text-white">Coming soon</span>
              </span>
            </div>
          </div>
        </div>

        <div v-for="col in columns" :key="col.title">
          <h4 class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">{{ col.title }}</h4>
          <ul class="mt-4 space-y-3">
            <li v-for="link in col.links" :key="link.label">
              <component
                :is="link.external ? 'a' : 'NuxtLink'"
                v-bind="link.external ? { href: link.to, target: '_blank', rel: 'noopener' } : { to: link.to }"
                class="text-sm text-slate-400 transition hover:text-white"
              >
                {{ link.label }}
              </component>
            </li>
          </ul>
        </div>
      </div>

      <div class="mt-14 flex flex-col items-start justify-between gap-4 border-t border-white/10 pt-6 sm:flex-row sm:items-center">
        <p class="text-xs text-slate-500">© {{ year }} AdhereMed. All rights reserved.</p>
        <div class="flex items-center gap-5 text-xs text-slate-500">
          <NuxtLink to="/contact" class="hover:text-white">Privacy</NuxtLink>
          <NuxtLink to="/contact" class="hover:text-white">Terms</NuxtLink>
          <span class="inline-flex items-center gap-2">
            <span class="h-2 w-2 animate-pulseGlow rounded-full bg-emerald-400"></span>
            All systems operational
          </span>
        </div>
      </div>
    </div>
  </footer>
</template>

<script setup>
const { webAppUrl } = useAppLinks()
const year = new Date().getFullYear()

const columns = [
  {
    title: 'Platform',
    links: [
      { label: 'Features', to: '/features' },
      { label: 'Ecosystem', to: '/#ecosystem' },
      { label: 'Dashboards', to: '/features#dashboards' },
      { label: 'Integrations', to: '/features#integrations' },
      { label: 'API & Pricing', to: '/pricing' }
    ]
  },
  {
    title: 'Solutions',
    links: [
      { label: 'For Patients', to: '/solutions#patients' },
      { label: 'For Doctors', to: '/solutions#doctors' },
      { label: 'For Hospitals', to: '/solutions#hospitals' },
      { label: 'For Pharmacies', to: '/solutions#pharmacies' },
      { label: 'For Insurers', to: '/solutions#insurance' }
    ]
  },
  {
    title: 'Company',
    links: [
      { label: 'About', to: '/about' },
      { label: 'Mission & Vision', to: '/about#mission' },
      { label: 'Founders', to: '/founders' },
      { label: 'Contact', to: '/contact' },
      { label: 'Launch platform', to: 'https://adheremed.tiktek-ex.com/welcome', external: true }
    ]
  }
]
</script>
