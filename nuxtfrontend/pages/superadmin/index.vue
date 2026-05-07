<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Super Admin" icon="mdi-shield-crown" subtitle="Platform-wide administration" />

    <v-row>
      <v-col v-for="c in cards" :key="c.label" cols="12" sm="6" md="4">
        <v-card rounded="lg" class="pa-4" hover :to="c.to">
          <v-icon size="40" :color="c.color">{{ c.icon }}</v-icon>
          <h3 class="text-h6 font-weight-bold mt-2">{{ c.label }}</h3>
          <p class="text-body-2 text-medium-emphasis">{{ c.desc }}</p>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
const cards = [
  { label: 'Tenants', icon: 'mdi-domain', color: 'primary', desc: 'Manage hospitals, pharmacies, labs', to: '/superadmin/tenants' },
  { label: 'Users', icon: 'mdi-account-multiple', color: 'info', desc: 'Manage platform users', to: '/superadmin/users' },
  { label: 'Usage Billing', icon: 'mdi-cash-multiple', color: 'success', desc: 'Per-request billing & rate control', to: '/superadmin/billing' },
  { label: 'Clinical Catalog', icon: 'mdi-medical-bag', color: 'success', desc: 'Diagnoses, procedures, medications', to: '/superadmin/clinical-catalog' },
  { label: 'Admin Catalog', icon: 'mdi-tag-multiple', color: 'warning', desc: 'Lookups, taxonomies', to: '/superadmin/admin-catalog' },
  { label: 'Seed Data', icon: 'mdi-database-import', color: 'error', desc: 'Populate sample data', to: '/superadmin/seed' }
]
</script>
