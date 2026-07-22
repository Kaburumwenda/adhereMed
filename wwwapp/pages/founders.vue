<template>
  <div class="pt-28 sm:pt-32">
    <!-- Hero -->
    <section class="container-xl text-center">
      <div class="reveal mx-auto max-w-3xl">
        <span class="eyebrow"><span class="h-1.5 w-1.5 rounded-full bg-brand-400"></span> Leadership</span>
        <h1 class="mt-5 font-display text-4xl font-extrabold leading-tight text-white sm:text-5xl">
          Meet the <span class="gradient-text">founders</span>
        </h1>
        <p class="mt-6 text-lg leading-relaxed text-slate-300">
          A multidisciplinary team uniting clinical excellence, engineering and healthcare quality —
          building Africa's healthcare operating system under one motto:
          <span class="font-semibold text-white">“Connected Healthcare. Simplified.”</span>
        </p>
      </div>

      <!-- quick nav -->
      <div class="reveal mt-10 flex flex-wrap justify-center gap-2">
        <a
          v-for="f in founders"
          :key="f.id"
          :href="`#${f.id}`"
          class="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm font-semibold text-slate-300 transition hover:border-brand-400/50 hover:text-white"
        >
          {{ f.name }}
        </a>
      </div>
    </section>

    <!-- Founders -->
    <section class="section">
      <div class="container-xl space-y-8">
        <article
          v-for="f in founders"
          :id="f.id"
          :key="f.id"
          class="reveal scroll-mt-28 card grid gap-8 lg:grid-cols-[300px_1fr] lg:items-start"
        >
          <!-- Portrait / monogram -->
          <div class="flex flex-col items-center text-center">
            <div class="relative">
              <div class="absolute -inset-3 -z-10 rounded-[2rem] bg-brand-500/20 blur-2xl"></div>
              <div class="flex h-44 w-44 items-center justify-center rounded-[2rem] border border-white/10 bg-gradient-to-br from-brand-600/30 via-ink-950 to-ink-950">
                <span class="font-display text-5xl font-extrabold tracking-tight text-white">{{ f.initials }}</span>
              </div>
            </div>
            <h2 class="mt-6 font-display text-xl font-bold text-white">{{ f.name }}</h2>
            <p class="mt-1 text-sm font-semibold text-brand-300">{{ f.role }}</p>
            <p class="mt-3 inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-3 py-1 text-[11px] font-semibold uppercase tracking-wider text-slate-400">
              <span class="h-1.5 w-1.5 rounded-full bg-emerald-400"></span>
              Co-founder
            </p>
          </div>

          <!-- Bio -->
          <div>
            <span class="flex h-12 w-12 items-center justify-center rounded-2xl bg-brand-500/15 text-brand-300 ring-1 ring-inset ring-brand-400/30" v-html="f.icon"></span>
            <div class="mt-5 space-y-4">
              <p
                v-for="(para, p) in f.bio"
                :key="p"
                class="text-sm leading-relaxed text-slate-300 sm:text-base"
              >
                {{ para }}
              </p>
            </div>

            <div class="mt-6 flex flex-wrap gap-2">
              <span
                v-for="tag in f.tags"
                :key="tag"
                class="rounded-full border border-white/10 bg-white/5 px-3 py-1.5 text-xs font-semibold text-slate-300"
              >
                {{ tag }}
              </span>
            </div>
          </div>
        </article>
      </div>
    </section>

    <PageCta
      title="Building the future of African healthcare"
      subtitle="Partner with our team to bring connected, patient-centred care to your organisation."
    />
  </div>
</template>

<script setup>
useHead({ title: 'Founders — AdhereMed' })

const icDoctor =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" class="h-6 w-6"><circle cx="12" cy="7" r="3.5"/><path d="M6 21v-1a6 6 0 0 1 12 0v1"/><path d="M16 12v3a3 3 0 0 0 6 0v-2"/><circle cx="22" cy="13" r="1"/></svg>'
const icTech =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" class="h-6 w-6"><path d="m8 6-6 6 6 6M16 6l6 6-6 6M14 4l-4 16"/></svg>'
const icHeart =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" class="h-6 w-6"><path d="M12 21s-7-4.5-9-9a4.5 4.5 0 0 1 9-2 4.5 4.5 0 0 1 9 2c-2 4.5-9 9-9 9Z"/></svg>'

const founders = [
  {
    id: 'martin-muriithi',
    name: 'Martin Muriithi',
    initials: 'MM',
    role: 'Founder & Chief Executive Officer',
    icon: icHeart,
    bio: [
      'Martin Muriithi is the Founder of AdhereMed, a digital health innovator combining healthcare expertise and technology to improve medication adherence and access to care across Africa.',
      'With experience in critical care, healthcare quality improvement, and clinical operations, Martin is building solutions that connect patients, providers, pharmacies, and healthcare systems to deliver more coordinated and patient-centred care.'
    ],
    tags: ['Critical Care', 'Healthcare Quality Improvement', 'Clinical Operations', 'Digital Health']
  },
  {
    id: 'dominic-kaburu',
    name: 'Eng. Dominic Kaburu',
    initials: 'DK',
    role: 'Founder & Chief Technology Officer',
    icon: icTech,
    bio: [
      'Dominic is the founder of AdhereMed, a healthcare platform that connects patients, providers, hospitals, pharmacies, labs, and insurers into a single ecosystem. He holds an Electrical & Electronic Engineering degree and is a Certified Offensive Security Professional (OSCP), blending technical engineering with cybersecurity expertise.',
      'With experience in software development and full-stack system design across mobile, cloud, and enterprise platforms, he builds secure, scalable, and compliant solutions. At AdhereMed, he focuses on simplifying care delivery and improving patient adherence, guided by the motto “Connected Healthcare. Simplified.”',
      'His leadership drives innovation, transparency, and collaboration, with a commitment to making healthcare more accessible and empowering for all stakeholders.'
    ],
    tags: ['Electrical & Electronic Engineering', 'OSCP', 'Cybersecurity', 'Full-Stack Development', 'Cloud & Enterprise']
  },
  {
    id: 'muthoni-njuguna',
    name: 'Dr. Muthoni Njuguna',
    initials: 'MN',
    role: 'Founder & Chief Medical Officer',
    icon: icDoctor,
    bio: [
      'Dr. Muthoni Njuguna is a Physician, Certified Professional in Healthcare Quality (CPHQ), and Health Systems Specialist with over 10 years of experience in clinical excellence, patient safety, and healthcare transformation.',
      'With expertise in JCI, SafeCare, and ISQua quality frameworks, she brings strategic insight into building safer, data-driven, and patient-centred healthcare systems. At AdhereMed, Dr. Njuguna supports the development of healthcare solutions that strengthen quality, continuity of care, and improved patient outcomes across Africa.'
    ],
    tags: ['Physician', 'CPHQ', 'Patient Safety', 'JCI · SafeCare · ISQua', 'Health Systems']
  }
]
</script>
