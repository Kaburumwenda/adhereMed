<template>
  <div class="pt-28 sm:pt-32">
    <section class="container-xl text-center">
      <div class="reveal mx-auto max-w-3xl">
        <span class="eyebrow"><span class="h-1.5 w-1.5 rounded-full bg-brand-400"></span> Solutions</span>
        <h1 class="mt-5 font-display text-4xl font-extrabold leading-tight text-white sm:text-5xl">
          One platform, <span class="gradient-text">tailored to every actor</span>
        </h1>
        <p class="mt-6 text-lg leading-relaxed text-slate-300">
          From patients to government, AdhereMed gives each stakeholder the tools they need — all
          working from the same connected data.
        </p>
      </div>

      <!-- quick nav -->
      <div class="reveal mt-10 flex flex-wrap justify-center gap-2">
        <a v-for="s in solutions" :key="s.id" :href="`#${s.id}`" class="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm font-semibold text-slate-300 transition hover:border-brand-400/50 hover:text-white">
          {{ s.audience }}
        </a>
      </div>
    </section>

    <section class="section">
      <div class="container-xl space-y-6">
        <div
          v-for="(s, i) in solutions"
          :id="s.id"
          :key="s.id"
          class="reveal scroll-mt-28 card grid gap-8 lg:grid-cols-[auto_1fr_1fr] lg:items-center"
        >
          <span class="flex h-16 w-16 items-center justify-center rounded-2xl bg-brand-500/15 text-brand-300 ring-1 ring-inset ring-brand-400/30" v-html="s.icon"></span>
          <div>
            <p class="text-xs font-semibold uppercase tracking-wider text-brand-300">For {{ s.audience }}</p>
            <h2 class="mt-2 font-display text-2xl font-bold text-white">{{ s.headline }}</h2>
            <p class="mt-3 text-sm leading-relaxed text-slate-400">{{ s.desc }}</p>
          </div>
          <ul class="grid gap-3 sm:grid-cols-2">
            <li v-for="point in s.points" :key="point" class="flex items-start gap-2.5 rounded-xl border border-white/10 bg-white/[0.03] p-3">
              <svg class="mt-0.5 h-4 w-4 shrink-0 text-brand-400" viewBox="0 0 20 20" fill="none"><path d="m5 10 3 3 7-7" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>
              <span class="text-xs font-medium text-slate-300">{{ point }}</span>
            </li>
          </ul>
        </div>
      </div>
    </section>

    <PageCta title="Find the right solution for your team" subtitle="See AdhereMed in action across your part of the care journey." />
  </div>
</template>

<script setup>
useHead({ title: 'Solutions — AdhereMed' })
const solutions = useSolutions()
</script>
