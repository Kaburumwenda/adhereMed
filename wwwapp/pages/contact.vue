<template>
  <div class="pt-28 sm:pt-32">
    <section class="container-xl">
      <div class="grid gap-12 lg:grid-cols-2">
        <!-- info -->
        <div class="reveal">
          <span class="eyebrow"><span class="h-1.5 w-1.5 rounded-full bg-brand-400"></span> Contact</span>
          <h1 class="mt-5 font-display text-4xl font-extrabold leading-tight text-white sm:text-5xl">
            Let's connect your <span class="gradient-text">healthcare</span>
          </h1>
          <p class="mt-6 text-lg leading-relaxed text-slate-300">
            Talk to our team about bringing patients, providers and payers onto one platform — or
            launch the web app and explore it yourself.
          </p>

          <div class="mt-10 space-y-4">
            <a :href="`mailto:${email}`" class="flex items-center gap-4 rounded-2xl border border-white/10 bg-white/[0.03] p-4 transition hover:border-brand-400/40">
              <span class="flex h-11 w-11 items-center justify-center rounded-xl bg-brand-500/15 text-brand-300">
                <svg class="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/></svg>
              </span>
              <span>
                <span class="block text-xs text-slate-500">Email us</span>
                <span class="block text-sm font-semibold text-white">{{ email }}</span>
              </span>
            </a>
            <a :href="webAppUrl" target="_blank" rel="noopener" class="flex items-center gap-4 rounded-2xl border border-white/10 bg-white/[0.03] p-4 transition hover:border-brand-400/40">
              <span class="flex h-11 w-11 items-center justify-center rounded-xl bg-brand-500/15 text-brand-300">
                <svg class="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a15 15 0 0 1 0 18 15 15 0 0 1 0-18Z"/></svg>
              </span>
              <span>
                <span class="block text-xs text-slate-500">Web platform</span>
                <span class="block text-sm font-semibold text-white">adheremed.tiktek-ex.com</span>
              </span>
            </a>
          </div>
        </div>

        <!-- form -->
        <div class="reveal" style="transition-delay: 100ms">
          <form class="card" @submit.prevent="submit">
            <h2 class="font-display text-lg font-bold text-white">Send us a message</h2>
            <p class="mt-1 text-sm text-slate-400">We'll get back to you within one business day.</p>

            <div class="mt-6 grid gap-4 sm:grid-cols-2">
              <div>
                <label class="label">Full name</label>
                <input v-model="form.name" type="text" required class="input" placeholder="Amara Njoki" />
              </div>
              <div>
                <label class="label">Work email</label>
                <input v-model="form.email" type="email" required class="input" placeholder="you@org.com" />
              </div>
            </div>

            <div class="mt-4 grid gap-4 sm:grid-cols-2">
              <div>
                <label class="label">Organisation</label>
                <input v-model="form.org" type="text" class="input" placeholder="Hospital / Pharmacy / Insurer" />
              </div>
              <div>
                <label class="label">I represent a</label>
                <select v-model="form.role" class="input">
                  <option v-for="r in roles" :key="r" :value="r">{{ r }}</option>
                </select>
              </div>
            </div>

            <div class="mt-4">
              <label class="label">Message</label>
              <textarea v-model="form.message" rows="4" required class="input resize-none" placeholder="Tell us what you'd like to connect…"></textarea>
            </div>

            <button type="submit" class="btn-primary mt-6 w-full">
              {{ sent ? 'Message ready ✓' : 'Send message' }}
            </button>

            <p v-if="sent" class="mt-3 text-center text-xs text-emerald-400">
              Thanks, {{ form.name || 'there' }}! Your email client should open — or reach us at {{ email }}.
            </p>
          </form>
        </div>
      </div>
    </section>

    <div class="py-16"></div>
  </div>
</template>

<script setup>
import { reactive, ref } from 'vue'
useHead({ title: 'Contact — AdhereMed' })

const { webAppUrl, email } = useAppLinks()
const roles = ['Patient', 'Doctor', 'Hospital', 'Pharmacy', 'Laboratory', 'Insurance', 'Government', 'Developer', 'Other']

const form = reactive({ name: '', email: '', org: '', role: roles[2], message: '' })
const sent = ref(false)

function submit() {
  sent.value = true
  const subject = encodeURIComponent(`AdhereMed enquiry — ${form.role}`)
  const body = encodeURIComponent(
    `Name: ${form.name}\nEmail: ${form.email}\nOrganisation: ${form.org}\nRole: ${form.role}\n\n${form.message}`
  )
  if (typeof window !== 'undefined') {
    window.location.href = `mailto:${email}?subject=${subject}&body=${body}`
  }
}
</script>

<style scoped>
.label {
  @apply mb-1.5 block text-xs font-semibold text-slate-400;
}
.input {
  @apply w-full rounded-xl border border-white/10 bg-white/[0.04] px-4 py-2.5 text-sm text-white placeholder-slate-500 outline-none transition focus:border-brand-400/60 focus:ring-2 focus:ring-brand-500/30;
}
.input option {
  @apply bg-ink-950 text-white;
}
</style>
