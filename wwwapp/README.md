# AdhereMed — Marketing Website

> **Connected Healthcare. Simplified.**
> The marketing & product website for **AdhereMed**, Africa's healthcare operating system.

Built with **Nuxt 3 (Vue 3)** and **Tailwind CSS**.

## About

AdhereMed's SaaS platform is a full healthcare ecosystem hub — connecting patients, doctors,
hospitals, pharmacies, labs, radiology, homecare, insurance and government into one unified system.

- **Web platform:** https://adheremed.tiktek-ex.com/welcome
- **Android app:** _coming soon_
- **iOS app:** _coming soon_

## Brand

- Colours: **blue**, **black**, **white**
- Fonts: Sora (display) + Inter (body)

## Highlights

- Animated **ecosystem identity** — Patient → Doctor → Hospital → Pharmacy → Laboratory → Insurance
  → Government → Population Analytics, with glowing blue data flowing into the AdhereMed cloud
  (`components/EcosystemDiagram.vue`, `components/EcosystemFlow.vue`).
- Interactive **API usage pricing calculator** at **$0.077 / 1,000 requests** with live cost-vs-volume
  chart analysis (`components/PricingCalculator.vue`).
- Custom dashboard, mobile and ecosystem illustrations (no stock hospital imagery).
- Pages: Home, Platform/Features, Solutions, Pricing, About, Contact.

## Getting started

```bash
npm install      # install dependencies
npm run dev      # start dev server at http://localhost:3000
npm run build    # production build
npm run preview  # preview the production build
npm run generate # static-site generation
```

## Project structure

```
components/        Reusable UI + sections (header, footer, ecosystem, pricing, dashboards)
composables/       Shared content (features, solutions) and external app links
pages/             Routes: index, features, solutions, pricing, about, contact
layouts/           Default layout (header + footer)
assets/css/        Tailwind layers, brand theme, animations
public/            Static assets (favicon)
```

External links live in `composables/useAppLinks.ts` — update the Android/iOS URLs there when the
mobile apps are published.
