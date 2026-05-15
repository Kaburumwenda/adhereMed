<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Cart" icon="mdi-cart" :subtitle="cart.pharmacyName" />

    <EmptyState v-if="!cart.items.length" icon="mdi-cart-outline" title="Cart is empty" message="Browse a pharmacy to add items." />
    <v-row v-else>
      <v-col cols="12" md="8">
        <v-card rounded="lg">
          <v-list>
            <v-list-item v-for="it in cart.items" :key="it.id">
              <v-list-item-title>{{ it.name }}</v-list-item-title>
              <v-list-item-subtitle>{{ formatMoney(it.price) }} each</v-list-item-subtitle>
              <template #append>
                <div class="d-flex align-center">
                  <v-btn icon="mdi-minus" size="small" variant="text" @click="cart.dec(it.id)" />
                  <span class="mx-2">{{ it.quantity }}</span>
                  <v-btn icon="mdi-plus" size="small" variant="text" @click="cart.inc(it.id)" />
                  <v-btn icon="mdi-delete" size="small" variant="text" color="error" @click="cart.remove(it.id)" />
                </div>
              </template>
            </v-list-item>
          </v-list>
        </v-card>
      </v-col>
      <v-col cols="12" md="4">
        <v-card rounded="lg" class="pa-4">
          <h3 class="text-h6 font-weight-bold mb-3">Summary</h3>
          <div class="d-flex justify-space-between mb-2"><span>{{ $t('common.subtotal') }}</span><span>{{ formatMoney(cart.total) }}</span></div>
          <v-divider class="my-2" />
          <div class="d-flex justify-space-between mb-3"><span class="text-subtitle-1 font-weight-bold">{{ $t('common.total') }}</span><span class="text-h6 font-weight-bold">{{ formatMoney(cart.total) }}</span></div>
          <v-textarea v-model="deliveryAddress" label="Delivery address" rows="2" auto-grow density="compact" />
          <v-text-field v-model="contactPhone" label="Contact phone" density="compact" />
          <v-btn color="primary" block rounded="lg" class="text-none mt-2" :loading="placing" @click="checkout">Place Order</v-btn>
        </v-card>
      </v-col>
    </v-row>
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

import { useCartStore } from '~/stores/cart'
import { formatMoney } from '~/utils/format'
const cart = useCartStore()
const { $api } = useNuxtApp()
const router = useRouter()
cart.restore()

const deliveryAddress = ref('')
const contactPhone = ref('')
const placing = ref(false)
const snack = reactive({ show: false, text: '', color: 'success' })

async function checkout() {
  placing.value = true
  try {
    const res = await $api.post('/exchange/orders/', {
      pharmacy: cart.pharmacyId,
      delivery_address: deliveryAddress.value,
      contact_phone: contactPhone.value,
      items: cart.items.map(i => ({ product: i.id, quantity: i.quantity, unit_price: i.price }))
    })
    cart.clear()
    snack.text = 'Order placed!'
    snack.color = 'success'
    snack.show = true
    setTimeout(() => router.push(`/pharmacy-store/orders/${res.data.id || ''}`), 800)
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to place order'
    snack.color = 'error'
    snack.show = true
  } finally {
    placing.value = false
  }
}
</script>
