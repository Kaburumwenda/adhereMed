<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width:980px">
    <v-btn variant="text" prepend-icon="mdi-arrow-left" class="mb-3" to="/pharmacy-orders">
      Back to Orders
    </v-btn>

    <v-card v-if="loading" flat rounded="xl" class="pa-8 text-center">
      <v-progress-circular indeterminate color="primary" />
    </v-card>

    <v-card v-else-if="!order" flat rounded="xl" class="pa-6 text-center">
      <v-icon size="40" color="grey">mdi-receipt-text-remove</v-icon>
      <div class="text-h6 mt-2">Order not found</div>
    </v-card>

    <v-card v-else flat rounded="xl">
      <v-toolbar :color="statusTone(order.status)" density="comfortable" flat>
        <v-icon class="ml-3">mdi-receipt-text</v-icon>
        <v-toolbar-title class="font-weight-bold">{{ order.order_number }}</v-toolbar-title>
        <v-spacer />
        <v-chip color="white" :text-color="statusTone(order.status)" size="small" class="mr-2">
          {{ order.status }}
        </v-chip>
      </v-toolbar>

      <v-card-text class="pa-5">
        <div class="text-overline mb-2">Lifecycle</div>
        <div class="timeline mb-4">
          <div v-for="(s, idx) in lifecycleSteps" :key="s.value"
               class="timeline-step"
               :class="{ 'step-done': lifecycleIndex(order.status) >= idx,
                         'step-current': lifecycleIndex(order.status) === idx }">
            <div class="step-dot"><v-icon size="14" color="white">{{ s.icon }}</v-icon></div>
            <div class="step-label text-caption">{{ s.label }}</div>
          </div>
        </div>

        <v-row dense>
          <v-col cols="12" md="6">
            <div class="text-caption text-medium-emphasis">Patient</div>
            <div class="d-flex align-center mt-1">
              <v-avatar :color="avatarColor(order.patient_name)" size="40" class="mr-2">
                <span class="font-weight-bold">{{ initials(order.patient_name) }}</span>
              </v-avatar>
              <div>
                <div class="font-weight-bold">{{ order.patient_name }}</div>
                <div class="text-caption">
                  <v-icon size="13">mdi-phone</v-icon> {{ order.patient_phone || '—' }}
                </div>
              </div>
            </div>
          </v-col>
          <v-col cols="12" md="6">
            <div class="text-caption text-medium-emphasis">Placed</div>
            <div class="font-weight-medium">{{ formatDateTime(order.created_at) }}</div>
            <div class="text-caption text-medium-emphasis mt-2">Updated</div>
            <div class="font-weight-medium">{{ formatDateTime(order.updated_at) }}</div>
          </v-col>
        </v-row>

        <v-row dense class="mt-3">
          <v-col cols="12" md="8">
            <v-card flat rounded="lg" class="pa-3 info-tile">
              <div class="text-caption text-medium-emphasis">Delivery Address</div>
              <div class="font-weight-medium">
                <v-icon size="16" class="mr-1">mdi-map-marker</v-icon>
                {{ order.delivery_address || 'Pickup at counter' }}
              </div>
            </v-card>
          </v-col>
          <v-col cols="12" md="4">
            <v-card flat rounded="lg" class="pa-3 info-tile">
              <div class="text-caption text-medium-emphasis">Payment</div>
              <v-chip size="small" variant="tonal" :color="paymentTone(order.payment_method)"
                      :prepend-icon="paymentIcon(order.payment_method)" class="mt-1">
                {{ order.payment_method }}
              </v-chip>
            </v-card>
          </v-col>
        </v-row>

        <div class="text-overline mt-4 mb-1">Items</div>
        <v-table density="compact" class="items-table">
          <thead>
            <tr>
              <th>Medication</th>
              <th class="text-end">Qty</th>
              <th class="text-end">Unit Price</th>
              <th class="text-end">{{ $t('common.subtotal') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(it, i) in (order.items || [])" :key="i">
              <td>{{ it.medication_name || it.product_name }}</td>
              <td class="text-end">{{ it.quantity }}</td>
              <td class="text-end">{{ formatMoney(it.unit_price) }}</td>
              <td class="text-end font-weight-medium">
                {{ formatMoney(it.total ?? (it.quantity || 0) * (it.unit_price || 0)) }}
              </td>
            </tr>
          </tbody>
        </v-table>

        <v-row dense class="mt-3">
          <v-col cols="12" md="6">
            <div v-if="order.notes" class="text-caption text-medium-emphasis">{{ $t('common.notes') }}</div>
            <div v-if="order.notes" class="text-body-2">{{ order.notes }}</div>
          </v-col>
          <v-col cols="12" md="6">
            <v-card flat rounded="lg" class="pa-3 totals-tile">
              <div class="d-flex justify-space-between text-body-2">
                <span>{{ $t('common.subtotal') }}</span><span>{{ formatMoney(order.subtotal) }}</span>
              </div>
              <div class="d-flex justify-space-between text-body-2 mt-1">
                <span>Delivery Fee</span><span>{{ formatMoney(order.delivery_fee) }}</span>
              </div>
              <v-divider class="my-2" />
              <div class="d-flex justify-space-between font-weight-bold">
                <span>{{ $t('common.total') }}</span>
                <span class="text-success text-h6">{{ formatMoney(order.total) }}</span>
              </div>
            </v-card>
          </v-col>
        </v-row>
      </v-card-text>

      <v-divider />
      <v-card-actions class="pa-3 flex-wrap" style="gap:6px">
        <v-btn variant="outlined" prepend-icon="mdi-printer" @click="printOrder(order)">Print Receipt</v-btn>
        <v-spacer />
        <v-btn v-for="a in nextActions(order)" :key="a.value"
               :color="a.color" variant="flat" :prepend-icon="a.icon"
               :loading="updating === a.value"
               @click="advance(a.value)">{{ a.label }}</v-btn>
        <v-btn v-if="order.status !== 'cancelled' && order.status !== 'completed'"
               color="error" variant="text" prepend-icon="mdi-cancel"
               :loading="updating === 'cancelled'" @click="advance('cancelled')">
          Cancel Order
        </v-btn>
      </v-card-actions>
    </v-card>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2500">
      {{ snack.message }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

import { ref, reactive, onMounted } from 'vue'
import { formatMoney, formatDateTime } from '~/utils/format'

definePageMeta({ layout: 'default' })

const route = useRoute()
const { $api } = useNuxtApp()

const order = ref(null)
const loading = ref(false)
const updating = ref(null)
const snack = reactive({ show: false, color: 'success', message: '' })

const lifecycleSteps = [
  { value: 'pending', label: 'Placed', icon: 'mdi-cart' },
  { value: 'confirmed', label: 'Confirmed', icon: 'mdi-check' },
  { value: 'processing', label: 'Processing', icon: 'mdi-cog' },
  { value: 'ready', label: 'Ready', icon: 'mdi-package' },
  { value: 'completed', label: 'Delivered', icon: 'mdi-truck-check' },
]

const TRANSITIONS = {
  pending:    [{ value: 'confirmed', label: 'Confirm', color: 'blue', icon: 'mdi-check' }],
  confirmed:  [{ value: 'processing', label: 'Start Processing', color: 'indigo', icon: 'mdi-cog' }],
  processing: [{ value: 'ready', label: 'Mark Ready', color: 'teal', icon: 'mdi-package-check' }],
  ready:      [{ value: 'completed', label: 'Complete', color: 'success', icon: 'mdi-truck-check' }],
  completed:  [],
  cancelled:  [],
}
function nextActions(o) { return TRANSITIONS[o?.status] || [] }

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/exchange/pharmacy/orders/', { params: { page_size: 500 } })
    const list = data?.results || data || []
    order.value = list.find(o => String(o.id) === String(route.params.id)) || null
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to load', 'error')
  } finally { loading.value = false }
}
onMounted(load)

async function advance(newStatus) {
  if (!order.value) return
  if (newStatus === 'cancelled' && !confirm(`Cancel order ${order.value.order_number}?`)) return
  updating.value = newStatus
  try {
    const { data } = await $api.patch(`/exchange/pharmacy/orders/${order.value.id}/status/`, { status: newStatus })
    order.value = data
    notify(`Order → ${newStatus}`)
  } catch (e) {
    notify(e?.response?.data?.detail || 'Status update failed', 'error')
  } finally { updating.value = null }
}

function lifecycleIndex(s) {
  if (s === 'cancelled') return -1
  return lifecycleSteps.findIndex(x => x.value === s)
}
function statusTone(s) {
  return ({ pending: 'orange', confirmed: 'blue', processing: 'indigo',
            ready: 'teal', completed: 'success', cancelled: 'error' })[s] || 'grey'
}
function paymentTone(m) { return ({ cash: 'success', mpesa: 'green' })[m] || 'grey' }
function paymentIcon(m) { return ({ cash: 'mdi-cash', mpesa: 'mdi-cellphone' })[m] || 'mdi-cash' }
function initials(n) {
  if (!n) return '?'
  return n.split(/\s+/).filter(Boolean).slice(0, 2).map(s => s[0].toUpperCase()).join('')
}
function avatarColor(name) {
  const palette = ['primary', 'indigo', 'teal', 'deep-purple', 'pink', 'orange', 'cyan', 'green']
  let h = 0
  for (const ch of (name || '')) h = (h * 31 + ch.charCodeAt(0)) >>> 0
  return palette[h % palette.length]
}
function notify(message, color = 'success') { Object.assign(snack, { show: true, color, message }) }

function printOrder(o) {
  const w = window.open('', '_blank', 'width=600,height=800')
  if (!w) return
  const itemRows = (o.items || []).map(it =>
    `<tr><td>${it.medication_name || it.product_name || ''}</td>
         <td style="text-align:right">${it.quantity}</td>
         <td style="text-align:right">${formatMoney(it.unit_price)}</td>
         <td style="text-align:right">${formatMoney(it.total ?? (it.quantity || 0) * (it.unit_price || 0))}</td></tr>`
  ).join('')
  w.document.write(`<html><head><title>${o.order_number}</title>
    <style>body{font-family:Arial,sans-serif;padding:20px;max-width:520px;margin:auto;color:#0f172a}
    h2{margin:0 0 4px}table{width:100%;border-collapse:collapse;margin:12px 0}
    th,td{border-bottom:1px solid #e2e8f0;padding:6px;font-size:13px}
    th{background:#f8fafc;text-align:left}.totals div{display:flex;justify-content:space-between;padding:3px 0}
    .grand{font-weight:bold;font-size:16px;border-top:2px solid #0f172a;padding-top:6px}</style></head>
    <body><h2>${o.order_number}</h2><div>${o.pharmacy_name || ''}</div>
    <div>${new Date(o.created_at).toLocaleString()}</div><hr/>
    <div><strong>Patient:</strong> ${o.patient_name}</div>
    <div><strong>Phone:</strong> ${o.patient_phone || '—'}</div>
    <div><strong>Address:</strong> ${o.delivery_address || 'Pickup'}</div>
    <div><strong>Payment:</strong> ${o.payment_method}</div>
    <table><thead><tr><th>Item</th><th style="text-align:right">Qty</th><th style="text-align:right">Unit</th><th style="text-align:right">${t('common.total')}</th></tr></thead><tbody>${itemRows}</tbody></table>
    <div class="totals"><div><span>${t('common.subtotal')}</span><span>${formatMoney(o.subtotal)}</span></div>
    <div><span>Delivery</span><span>${formatMoney(o.delivery_fee)}</span></div>
    <div class="grand"><span>${t('common.total')}</span><span>${formatMoney(o.total)}</span></div></div>
    <p style="text-align:center;margin-top:24px;font-size:12px;color:#64748b">Status: ${o.status}</p>
    </body></html>`)
  w.document.close()
  setTimeout(() => w.print(), 250)
}
</script>

<style scoped>
.info-tile, .totals-tile {
  background: rgba(0, 0, 0, 0.03);
  border: 1px solid rgba(0, 0, 0, 0.05);
}
.v-theme--dark .info-tile,
.v-theme--dark .totals-tile {
  background: rgba(255, 255, 255, 0.04);
  border-color: rgba(255, 255, 255, 0.08);
}
.items-table :deep(th) { background: rgba(0, 0, 0, 0.03); }
.v-theme--dark .items-table :deep(th) { background: rgba(255, 255, 255, 0.05); }

.timeline {
  display: flex; align-items: center; justify-content: space-between;
  position: relative; padding: 0 8px;
}
.timeline::before {
  content: ''; position: absolute; top: 14px; left: 24px; right: 24px;
  height: 2px; background: rgba(148, 163, 184, 0.3); z-index: 0;
}
.timeline-step {
  display: flex; flex-direction: column; align-items: center;
  position: relative; z-index: 1; flex: 1;
}
.step-dot {
  width: 30px; height: 30px; border-radius: 50%;
  background: rgba(148, 163, 184, 0.4);
  display: flex; align-items: center; justify-content: center;
  transition: all 0.2s ease;
}
.step-label { margin-top: 4px; opacity: 0.6; }
.step-done .step-dot { background: rgb(var(--v-theme-success)); }
.step-current .step-dot {
  background: rgb(var(--v-theme-primary));
  box-shadow: 0 0 0 4px rgba(99, 102, 241, 0.25);
  transform: scale(1.1);
}
.step-done .step-label { opacity: 1; font-weight: 600; }
</style>
