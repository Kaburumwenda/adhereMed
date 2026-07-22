// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2025-01-01',
  devtools: { enabled: true },
  modules: ['@nuxtjs/tailwindcss'],
  components: [{ path: '~/components', pathPrefix: false }],
  css: ['~/assets/css/main.css'],
  app: {
    head: {
      title: 'AdhereMed — Connected Healthcare. Simplified.',
      htmlAttrs: { lang: 'en' },
      meta: [
        { charset: 'utf-8' },
        { name: 'viewport', content: 'width=device-width, initial-scale=1' },
        {
          name: 'description',
          content:
            "AdhereMed is Africa's healthcare operating system — one intelligent digital platform connecting patients, doctors, hospitals, pharmacies, labs, radiology, homecare, insurance and government."
        },
        { name: 'theme-color', content: '#0A0F1F' },
        { property: 'og:title', content: 'AdhereMed — Connected Healthcare. Simplified.' },
        {
          property: 'og:description',
          content: "Africa's intelligent digital health ecosystem hub."
        },
        { property: 'og:type', content: 'website' }
      ],
      link: [
        { rel: 'icon', type: 'image/svg+xml', href: '/favicon.svg' },
        { rel: 'preconnect', href: 'https://fonts.googleapis.com' },
        { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' },
        {
          rel: 'stylesheet',
          href: 'https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&family=Sora:wght@400;500;600;700;800&display=swap'
        }
      ]
    },
    pageTransition: { name: 'page', mode: 'out-in' }
  }
})
