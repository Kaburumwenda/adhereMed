<template>
  <ClinicCatalogWorkspace :key="config.key" :config="config" />
</template>

<script setup>
// ─────────────────────────────────────────────────────────────────────────
// Clinic · Catalog · Allergies
//
// Backed by /api/clinic-catalog/allergies/ (tenant-scoped, isolated per
// clinic schema). The whole premium shell — branded hero, KPI tiles,
// category chips, table/card views and dialogs — lives in
// ClinicCatalogWorkspace; this page only describes what an allergy is.
// ─────────────────────────────────────────────────────────────────────────
const CATEGORIES = [
  { value: 'drug', label: 'Drug / Medication' },
  { value: 'food', label: 'Food' },
  { value: 'environmental', label: 'Environmental' },
  { value: 'insect', label: 'Insect / Venom' },
  { value: 'latex', label: 'Latex' },
  { value: 'contrast', label: 'Contrast / Dye' },
  { value: 'chemical', label: 'Chemical' },
  { value: 'other', label: 'Other' },
]

const config = {
  key: 'allergies',
  eyebrow: 'CLINIC · CATALOG',
  title: 'Allergies',
  subtitle: 'Clinic-scoped allergen reference used for allergy alerts during prescribing and triage.',
  icon: 'mdi-alert-octagon-outline',
  singular: 'Allergy',
  plural: 'Allergies',
  searchPlaceholder: 'Search allergen, symptom or category…',
  formSubtitle: 'Allergens available for patient allergy recording',

  endpoint: '/clinic-catalog/allergies/',
  statsEndpoint: '/clinic-catalog/allergies/stats/',
  seedEndpoint: '/clinic-catalog/allergies/seed/',

  // Extra column shown in table + card: allergies surface symptoms, not codes.
  extraKey: 'common_symptoms',
  extraLabel: 'Common symptoms',

  fields: [
    { key: 'name', label: 'Allergen name *', type: 'text', required: true, col: 12,
      icon: 'mdi-alert-circle-outline', placeholder: 'e.g. Penicillin' },
    { key: 'category', label: 'Category', type: 'combobox', options: CATEGORIES, col: 12,
      icon: 'mdi-shape-outline' },
    { key: 'common_symptoms', label: 'Common symptoms', type: 'text', col: 12,
      icon: 'mdi-stethoscope', placeholder: 'e.g. Rash, swelling, anaphylaxis' },
    { key: 'description', label: 'Clinical notes', type: 'textarea', col: 12,
      icon: 'mdi-note-text-outline', placeholder: 'Cross-reactivity, severity notes…' },
  ],
}
</script>
