<template>
  <ClinicCatalogWorkspace :key="config.key" :config="config" />
</template>

<script setup>
// ─────────────────────────────────────────────────────────────────────────
// Clinic · Catalog · Chronic Conditions
//
// Backed by /api/clinic-catalog/chronic-conditions/ (tenant-scoped, isolated
// per clinic schema). Shares the ClinicCatalogWorkspace shell with the
// Allergies page so the two catalog surfaces feel like one product — only
// the ICD-10 column and category vocabulary differ here.
// ─────────────────────────────────────────────────────────────────────────
const CATEGORIES = [
  { value: 'cardiovascular', label: 'Cardiovascular' },
  { value: 'endocrine', label: 'Endocrine / Metabolic' },
  { value: 'respiratory', label: 'Respiratory' },
  { value: 'neurological', label: 'Neurological' },
  { value: 'musculoskeletal', label: 'Musculoskeletal' },
  { value: 'gastrointestinal', label: 'Gastrointestinal' },
  { value: 'renal', label: 'Renal / Urological' },
  { value: 'hematological', label: 'Hematological' },
  { value: 'immunological', label: 'Immunological / Infectious' },
  { value: 'mental_health', label: 'Mental Health' },
  { value: 'oncological', label: 'Oncological' },
  { value: 'dermatological', label: 'Dermatological' },
  { value: 'ophthalmological', label: 'Ophthalmological' },
  { value: 'other', label: 'Other' },
]

const config = {
  key: 'chronic-conditions',
  eyebrow: 'CLINIC · CATALOG',
  title: 'Chronic Conditions',
  subtitle: 'ICD-10 coded condition reference used for problem lists, risk flags and care plans.',
  icon: 'mdi-heart-pulse',
  singular: 'Condition',
  plural: 'Conditions',
  searchPlaceholder: 'Search condition, ICD-10 code or category…',
  formSubtitle: 'Conditions available for patient problem lists',

  endpoint: '/clinic-catalog/chronic-conditions/',
  statsEndpoint: '/clinic-catalog/chronic-conditions/stats/',
  seedEndpoint: '/clinic-catalog/chronic-conditions/seed/',

  // Extra column shown in table + card: conditions are identified by ICD-10.
  extraKey: 'icd_code',
  extraLabel: 'ICD-10',

  fields: [
    { key: 'name', label: 'Condition name *', type: 'text', required: true, col: 8,
      icon: 'mdi-heart-pulse', placeholder: 'e.g. Type 2 Diabetes Mellitus' },
    { key: 'icd_code', label: 'ICD-10 code', type: 'text', col: 4,
      icon: 'mdi-barcode', placeholder: 'e.g. E11' },
    { key: 'category', label: 'Category', type: 'combobox', options: CATEGORIES, col: 12,
      icon: 'mdi-shape-outline' },
    { key: 'description', label: 'Clinical notes', type: 'textarea', col: 12,
      icon: 'mdi-note-text-outline', placeholder: 'Diagnostic criteria, monitoring notes…' },
  ],
}
</script>
