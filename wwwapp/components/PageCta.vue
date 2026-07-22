<template>
  <section class="section">
    <div class="container-xl">
      <div class="reveal relative overflow-hidden rounded-[2rem] border border-brand-400/30 bg-gradient-to-br from-brand-600 to-brand-700 p-10 text-center sm:p-16">
        <div class="absolute inset-0 grid-pattern opacity-20"></div>
        <div class="relative">
          <h2 class="font-display text-3xl font-extrabold text-white sm:text-4xl">{{ title }}</h2>
          <p class="mx-auto mt-4 max-w-xl text-brand-100">{{ subtitle }}</p>
          <div class="mt-8 flex flex-wrap justify-center gap-3">
            <a :href="webAppUrl" target="_blank" rel="noopener" class="btn bg-white text-brand-700 hover:bg-brand-50">Launch the platform</a>
            <NuxtLink to="/contact" class="btn border border-white/40 text-white hover:bg-white/10">Talk to our team</NuxtLink>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup>
const { webAppUrl } = useAppLinks()
defineProps({
  title: { type: String, default: 'Ready to connect your healthcare?' },
  subtitle: { type: String, default: "Join the platform building Africa's healthcare operating system." }
})
</script>
