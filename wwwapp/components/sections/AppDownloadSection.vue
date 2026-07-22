<template>
  <section class="section">
    <div class="container-xl">
      <div class="relative overflow-hidden rounded-[2rem] border border-white/10 bg-gradient-to-br from-brand-600/20 via-ink-950 to-ink-950 p-8 sm:p-14">
        <div class="absolute -right-20 -top-20 h-72 w-72 rounded-full bg-brand-500/20 blur-3xl"></div>
        <div class="grid items-center gap-10 lg:grid-cols-2">
          <div class="reveal">
            <span class="eyebrow"><span class="h-1.5 w-1.5 rounded-full bg-brand-400"></span> Available everywhere</span>
            <h2 class="mt-5 font-display text-3xl font-extrabold leading-tight text-white sm:text-4xl">
              One platform. <span class="gradient-text">Web & mobile.</span>
            </h2>
            <p class="mt-4 max-w-md text-slate-300">
              Access the full AdhereMed ecosystem from your browser today. Native Android and iOS apps
              are on the way for care on the go.
            </p>

            <div class="mt-8 flex flex-wrap gap-3">
              <a :href="webAppUrl" target="_blank" rel="noopener" class="store-btn">
                <svg class="h-7 w-7 text-brand-300" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><rect x="2" y="4" width="20" height="14" rx="2"/><path d="M8 21h8M12 18v3"/></svg>
                <span>
                  <span class="block text-[10px] uppercase tracking-wider text-slate-400">Open the</span>
                  <span class="block text-sm font-bold text-white">Web Platform</span>
                </span>
              </a>

              <div class="store-btn cursor-not-allowed opacity-60">
                <svg class="h-7 w-7 text-slate-300" viewBox="0 0 24 24" fill="currentColor"><path d="M3 4.5 14.5 12 3 19.5zM15.5 12.8l3 1.9-3 1.9-2-1.9zM3 21l11-7 2 1.3L4.6 22A1.2 1.2 0 0 1 3 21M4.6 2 16 8.7l-2 1.3L3 3a1.2 1.2 0 0 1 1.6-1"/></svg>
                <span>
                  <span class="block text-[10px] uppercase tracking-wider text-slate-400">Coming soon to</span>
                  <span class="block text-sm font-bold text-white">Google Play</span>
                </span>
              </div>

              <div class="store-btn cursor-not-allowed opacity-60">
                <svg class="h-7 w-7 text-slate-300" viewBox="0 0 24 24" fill="currentColor"><path d="M17.6 13.8c0-2 1.6-3 1.7-3a3.7 3.7 0 0 0-2.9-1.6c-1.2-.1-2.4.7-3 .7s-1.6-.7-2.6-.7A4 4 0 0 0 7.4 11c-1.5 2.6-.4 6.4 1 8.5.7 1 1.5 2.2 2.6 2.1s1.4-.7 2.7-.7 1.6.7 2.7.7 1.8-1 2.5-2a8 8 0 0 0 1.1-2.3 3.5 3.5 0 0 1-2.4-3.5M15.5 6.8A3.6 3.6 0 0 0 16.3 4a3.7 3.7 0 0 0-2.4 1.2 3.4 3.4 0 0 0-.9 2.7 3 3 0 0 0 2.5-1.1"/></svg>
                <span>
                  <span class="block text-[10px] uppercase tracking-wider text-slate-400">Coming soon to</span>
                  <span class="block text-sm font-bold text-white">App Store</span>
                </span>
              </div>
            </div>
          </div>

          <!-- phone mockup -->
          <div class="reveal flex justify-center lg:justify-end" style="transition-delay: 120ms">
            <div class="relative">
              <div class="absolute -inset-6 -z-10 rounded-[3rem] bg-brand-500/25 blur-3xl"></div>
              <div class="h-[28rem] w-56 rounded-[2.5rem] border border-white/15 bg-ink-950 p-3 shadow-card animate-floaty">
                <div class="flex h-full flex-col overflow-hidden rounded-[2rem] border border-white/10 bg-gradient-to-b from-brand-600/20 to-ink-950">
                  <div class="flex items-center justify-between px-5 py-4">
                    <AppLogo icon-only />
                    <span class="h-2 w-2 rounded-full bg-emerald-400"></span>
                  </div>
                  <div class="px-5">
                    <p class="text-[11px] text-slate-400">Good morning,</p>
                    <p class="font-display text-base font-bold text-white">Amara N.</p>
                  </div>
                  <div class="mt-4 space-y-3 px-5">
                    <div class="rounded-2xl border border-white/10 bg-white/5 p-3">
                      <p class="text-[10px] text-brand-200">Next dose · 2:00 PM</p>
                      <p class="text-xs font-semibold text-white">Metformin 500mg</p>
                      <div class="mt-2 h-1.5 w-full rounded-full bg-white/10">
                        <div class="h-full w-3/4 rounded-full bg-gradient-to-r from-brand-400 to-cyanx-400"></div>
                      </div>
                    </div>
                    <div class="grid grid-cols-2 gap-3">
                      <div class="rounded-2xl border border-white/10 bg-white/5 p-3">
                        <p class="text-[9px] text-slate-400">Adherence</p>
                        <p class="font-display text-sm font-bold text-white">94%</p>
                      </div>
                      <div class="rounded-2xl border border-white/10 bg-white/5 p-3">
                        <p class="text-[9px] text-slate-400">Teleconsult</p>
                        <p class="font-display text-sm font-bold text-white">Today</p>
                      </div>
                    </div>
                    <div class="rounded-2xl bg-gradient-to-r from-brand-500 to-brand-600 p-3 text-center">
                      <p class="text-xs font-bold text-white">Book appointment</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup>
const { webAppUrl } = useAppLinks()
</script>

<style scoped>
.store-btn {
  display: inline-flex;
  align-items: center;
  gap: 0.75rem;
  border-radius: 1rem;
  border: 1px solid rgba(255, 255, 255, 0.12);
  background: rgba(255, 255, 255, 0.05);
  padding: 0.6rem 1rem;
  transition: all 0.2s;
}
.store-btn:not(.cursor-not-allowed):hover {
  border-color: rgba(89, 150, 255, 0.5);
  background: rgba(255, 255, 255, 0.08);
}
</style>
