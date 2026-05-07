<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Admin Catalog" icon="mdi-tag-multiple" subtitle="Lookups and taxonomies" />
    <v-row>
      <v-col v-for="c in catalogs" :key="c.label" cols="12" sm="6" md="4">
        <v-card rounded="lg" class="pa-4" hover :to="c.to">
          <v-icon size="32" :color="c.color">{{ c.icon }}</v-icon>
          <h3 class="text-subtitle-1 font-weight-bold mt-2">{{ c.label }}</h3>
          <p class="text-body-2 text-medium-emphasis">{{ c.desc }}</p>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>
<script setup>
const catalogs = [
  { label: 'Departments', icon: 'mdi-domain', color: 'primary', desc: 'Hospital departments', to: '/departments' },
  { label: 'Specializations', icon: 'mdi-stethoscope', color: 'info', desc: 'Doctor specializations', to: '/specializations' },
  { label: 'Inventory Categories', icon: 'mdi-tag', color: 'success', desc: 'Stock categories', to: '/inventory' },
  { label: 'Suppliers', icon: 'mdi-truck', color: 'warning', desc: 'Master supplier list', to: '/suppliers' }
]
</script>
