<template>
  <header
    :class="[
      'fixed inset-x-0 top-0 z-50 transition-all duration-300',
      scrolled ? 'border-b border-white/10 bg-ink-950/80 backdrop-blur-xl' : 'bg-transparent'
    ]"
  >
    <div class="container-xl flex h-16 items-center justify-between sm:h-20">
      <AppLogo />

      <nav class="hidden items-center gap-1 lg:flex">
        <NuxtLink
          v-for="item in nav"
          :key="item.to"
          :to="item.to"
          class="rounded-full px-4 py-2 text-sm font-medium text-slate-300 transition hover:bg-white/5 hover:text-white"
          active-class="text-white"
        >
          {{ item.label }}
        </NuxtLink>
      </nav>

      <div class="hidden items-center gap-3 lg:flex">
        <a :href="webAppUrl" target="_blank" rel="noopener" class="btn-ghost text-sm">
          Sign in
        </a>
        <a :href="webAppUrl" target="_blank" rel="noopener" class="btn-primary text-sm">
          Launch platform
          <svg class="h-4 w-4" viewBox="0 0 20 20" fill="none">
            <path d="M5 10h10m0 0-4-4m4 4-4 4" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" />
          </svg>
        </a>
      </div>

      <button
        class="inline-flex h-11 w-11 items-center justify-center rounded-xl border border-white/10 bg-white/5 text-white lg:hidden"
        aria-label="Toggle menu"
        @click="open = !open"
      >
        <svg v-if="!open" class="h-6 w-6" viewBox="0 0 24 24" fill="none">
          <path d="M4 7h16M4 12h16M4 17h16" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" />
        </svg>
        <svg v-else class="h-6 w-6" viewBox="0 0 24 24" fill="none">
          <path d="M6 6l12 12M18 6 6 18" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" />
        </svg>
      </button>
    </div>

    <!-- Mobile menu -->
    <Transition name="page">
      <div v-if="open" class="border-t border-white/10 bg-ink-950/95 backdrop-blur-xl lg:hidden">
        <div class="container-xl flex flex-col gap-1 py-4">
          <NuxtLink
            v-for="item in nav"
            :key="item.to"
            :to="item.to"
            class="rounded-xl px-4 py-3 text-base font-medium text-slate-200 hover:bg-white/5"
            @click="open = false"
          >
            {{ item.label }}
          </NuxtLink>
          <a :href="webAppUrl" target="_blank" rel="noopener" class="btn-primary mt-2 w-full">
            Launch platform
          </a>
        </div>
      </div>
    </Transition>
  </header>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue'

const { webAppUrl } = useAppLinks()
const nav = [
  { label: 'Platform', to: '/features' },
  { label: 'Solutions', to: '/solutions' },
  { label: 'Ecosystem', to: '/#ecosystem' },
  { label: 'Pricing', to: '/pricing' },
  { label: 'About', to: '/about' },
  { label: 'Founders', to: '/founders' },
  { label: 'Contact', to: '/contact' }
]

const scrolled = ref(false)
const open = ref(false)

function onScroll() {
  scrolled.value = window.scrollY > 12
}

onMounted(() => {
  onScroll()
  window.addEventListener('scroll', onScroll, { passive: true })
})
onBeforeUnmount(() => window.removeEventListener('scroll', onScroll))
</script>
