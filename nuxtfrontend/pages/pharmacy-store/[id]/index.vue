<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader :title="pharmacy?.name || 'Pharmacy'" icon="mdi-pharmacy" :subtitle="pharmacy?.address">
      <template #actions>
        <v-btn variant="text" prepend-icon="mdi-arrow-left" to="/pharmacy-store" class="text-none">{{ $t('common.back') }}</v-btn>
        <v-badge :content="cart.count" :model-value="cart.count > 0" color="primary" class="ml-2">
          <v-btn color="primary" rounded="lg" class="text-none" prepend-icon="mdi-cart" to="/pharmacy-store/cart">Cart</v-btn>
        </v-badge>
      </template>
    </PageHeader>

    <v-text-field v-model="search" prepend-inner-icon="mdi-magnify" placeholder="Search products…" variant="outlined" density="compact" hide-details clearable class="mb-4" />

    <EmptyState v-if="!filtered.length && !loading" icon="mdi-package-variant-remove" title="No products available" />
    <v-row v-else>
      <v-col v-for="p in filtered" :key="p.id" cols="12" sm="6" md="4" lg="3">
        <v-card rounded="lg" class="pa-3" hover>
          <v-icon size="40" color="primary">mdi-pill</v-icon>
          <h3 class="text-subtitle-1 font-weight-bold mt-2 text-truncate">{{ p.name }}</h3>
          <p class="text-caption text-medium-emphasis text-truncate">{{ p.description || '' }}</p>
          <div class="d-flex justify-space-between align-center mt-2">
            <span class="text-h6 font-weight-bold">{{ formatMoney(p.selling_price) }}</span>
            <v-btn icon="mdi-cart-plus" size="small" color="primary" variant="tonal" @click="addToCart(p)" />
          </div>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

import { useCartStore } from '~/stores/cart'
import { formatMoney } from '~/utils/format'
const route = useRoute()
const { $api } = useNuxtApp()
const cart = useCartStore()
cart.restore()

const id = computed(() => route.params.id)
const pharmacy = ref(null)
const products = ref([])
const search = ref('')
const loading = ref(true)

const filtered = computed(() => {
  const q = search.value.toLowerCase()
  return q ? products.value.filter(p => (p.name || '').toLowerCase().includes(q)) : products.value
})

function addToCart(p) {
  cart.setPharmacy(id.value, pharmacy.value?.name || '')
  cart.add(p)
}

onMounted(async () => {
  pharmacy.value = await $api.get(`/exchange/pharmacies/${id.value}/`).then(r => r.data).catch(() => null)
  products.value = await $api.get(`/exchange/pharmacies/${id.value}/products/`).then(r => r.data?.results || r.data || []).catch(() => [])
  loading.value = false
})
</script>
