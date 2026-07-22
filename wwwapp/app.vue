<template>
  <div class="min-h-screen">
    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
  </div>
</template>

<script setup>
// Global reveal-on-scroll behaviour.
// Uses a single IntersectionObserver to reveal elements, plus a MutationObserver
// so content added on client-side navigation (after the page transition) is always
// observed — otherwise newly routed pages stay hidden until a manual refresh.
import { onMounted, onBeforeUnmount } from 'vue'

let io = null // IntersectionObserver
let mo = null // MutationObserver
let raf = 0

function reveal(el) {
  el.classList.add('is-visible')
}

function observeAll() {
  if (!io) return
  const nodes = document.querySelectorAll('.reveal:not(.is-visible)')
  nodes.forEach((el) => io.observe(el))
}

function scheduleObserve() {
  if (raf) cancelAnimationFrame(raf)
  raf = requestAnimationFrame(() => {
    raf = requestAnimationFrame(observeAll)
  })
}

onMounted(() => {
  if (typeof window === 'undefined') return

  // No IntersectionObserver support -> reveal everything immediately.
  if (!('IntersectionObserver' in window)) {
    document.querySelectorAll('.reveal').forEach(reveal)
    return
  }

  io = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          reveal(entry.target)
          io.unobserve(entry.target)
        }
      })
    },
    { threshold: 0.1, rootMargin: '0px 0px -6% 0px' }
  )

  observeAll()

  // Watch for nodes added by client-side navigation / transitions.
  mo = new MutationObserver(scheduleObserve)
  mo.observe(document.body, { childList: true, subtree: true })

  // Belt-and-braces: re-scan shortly after every route change.
  const router = useRouter()
  router.afterEach(() => {
    setTimeout(scheduleObserve, 50)
    setTimeout(scheduleObserve, 350)
  })
})

onBeforeUnmount(() => {
  if (io) io.disconnect()
  if (mo) mo.disconnect()
  if (raf) cancelAnimationFrame(raf)
})
</script>
