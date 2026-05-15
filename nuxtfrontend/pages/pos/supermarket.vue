<template>
  <div class="smkt-shell">
    <!-- ============== TOP BAR ============== -->
    <header class="smkt-topbar">
      <div class="d-flex align-center" style="gap:12px">
        <v-avatar color="primary" rounded="lg" size="40"><v-icon>mdi-cart-variant</v-icon></v-avatar>
        <div>
          <div class="smkt-brand">{{ $t('posSupermarket.title') }}</div>
          <div class="smkt-subbrand">Lane #{{ laneId }} · {{ today }} · {{ clock }}</div>
        </div>
      </div>

      <!-- Barcode scan -->
      <div class="smkt-scan">
        <v-icon color="success" size="22" class="mr-2">mdi-barcode-scan</v-icon>
        <input
          ref="scanInput"
          v-model="scanCode"
          type="text"
          class="smkt-scan-input"
          placeholder="Scan barcode or type SKU / name and press Enter…"
          @keydown.enter.prevent="handleScan"
          @focus="searchOpen = !!scanCode"
          @blur="onScanBlur"
        />
        <v-chip size="small" color="success" variant="flat" class="ml-2">SCANNER READY</v-chip>

        <!-- Search dropdown -->
        <div v-if="searchOpen && search.trim()" class="smkt-search-dropdown" @mousedown.prevent>
          <div v-if="!searchResults.length" class="smkt-search-empty">
            <v-icon color="grey">mdi-magnify-close</v-icon>
            <span class="ml-2">No items match "{{ search }}"</span>
          </div>
          <button
            v-for="(p, idx) in searchResults" :key="p.id"
            class="smkt-search-row"
            :class="{ 'is-active': activeIdx === idx, 'is-out': stockOf(p) <= 0 }"
            :disabled="stockOf(p) <= 0"
            @click="selectFromSearch(p)"
            @mouseenter="activeIdx = idx"
          >
            <v-avatar color="primary" variant="tonal" rounded="lg" size="36">
              <v-icon>{{ catIcon(p.category_name || p.category) }}</v-icon>
            </v-avatar>
            <div class="flex-grow-1 min-width-0 text-left">
              <div class="d-flex align-center" style="gap:6px">
                <span class="font-weight-medium text-truncate smkt-result-name">{{ nameOf(p) }}</span>
                <span v-if="p.abbreviation" class="smkt-abbr-chip">{{ p.abbreviation }}</span>
              </div>
              <div class="text-caption smkt-result-meta">
                {{ p.barcode || p.sku || p.medication_id || '—' }} · {{ stockOf(p) }} in stock
              </div>
            </div>
            <div class="smkt-search-price">{{ formatMoney(p.selling_price) }}</div>
            <v-icon color="success">mdi-plus-circle</v-icon>
          </button>
        </div>
      </div>

      <div class="d-flex align-center" style="gap:8px">
        <div class="smkt-meta">
          <div class="smkt-meta-label">CASHIER</div>
          <div class="smkt-meta-value">{{ auth.user?.first_name || 'Staff' }}</div>
        </div>
        <div class="smkt-meta">
          <div class="smkt-meta-label">SALES TODAY</div>
          <div class="smkt-meta-value text-success">{{ formatMoney(todayStats.revenue) }}</div>
        </div>
        <v-btn variant="text" icon="mdi-receipt-text-outline" to="/pos/history" />
        <v-badge :content="parkedSales.length" :model-value="parkedSales.length > 0" color="warning" offset-x="6" offset-y="6">
          <v-btn variant="text" icon="mdi-tray-arrow-up" to="/pos/parked" title="Sales on hold" />
        </v-badge>
        <v-btn variant="text" icon="mdi-store" to="/pos" title="Pharmacy POS" />
      </div>
    </header>

    <!-- ============== MAIN GRID ============== -->
    <div class="smkt-main">
      <!-- LEFT (huge): receipt + idle area -->
      <section class="smkt-stage">
        <header class="smkt-stage-header">
          <div>
            <div class="text-overline" style="color:#94a3b8; line-height:1">CURRENT ORDER</div>
            <div class="smkt-order-num mt-1">#{{ orderNumber }}</div>
          </div>
          <div class="text-right">
            <div class="text-overline" style="color:#94a3b8; line-height:1">CUSTOMER</div>
            <input
              v-model="customerName"
              type="text"
              class="smkt-cust-input mt-1"
              placeholder="Walk-in customer"
            />
          </div>
          <div class="text-right">
            <div class="text-overline" style="color:#94a3b8; line-height:1">ITEMS</div>
            <div class="smkt-order-num mt-1 text-primary">{{ itemCount }}</div>
          </div>
        </header>

        <!-- Idle / Empty hero -->
        <div v-if="!cart.length" class="smkt-idle">
          <div class="smkt-idle-pulse">
            <v-icon size="120" color="primary">mdi-barcode-scan</v-icon>
          </div>
          <div class="smkt-idle-title">READY TO SCAN</div>
          <div class="smkt-idle-sub">Scan a barcode or type a product name in the search bar above</div>
          <div class="smkt-shortcuts">
            <div class="smkt-shortcut"><kbd>Enter</kbd><span>Scan / add item</span></div>
            <div class="smkt-shortcut"><kbd>F2</kbd><span>Focus search</span></div>
            <div class="smkt-shortcut"><kbd>F9</kbd><span>Open tender</span></div>
            <div class="smkt-shortcut"><kbd>F4</kbd><span>Park sale</span></div>
            <div class="smkt-shortcut"><kbd>Esc</kbd><span>Void cart</span></div>
          </div>
          <div v-if="parkedSales.length" class="smkt-parked-cta">
            <v-icon>mdi-tray-arrow-up</v-icon>
            <span>You have <strong>{{ parkedSales.length }}</strong> parked sale(s)</span>
            <v-btn variant="flat" color="warning" rounded="lg" size="small" class="text-none ml-3" @click="showParked = true">View</v-btn>
          </div>
        </div>

        <!-- Cart (when not empty) -->
        <div v-else class="smkt-cart-wrap">
          <table class="smkt-cart-table">
            <thead>
              <tr>
                <th class="num-col">#</th>
                <th>Item</th>
                <th class="text-right">Price</th>
                <th class="text-center">Qty</th>
                <th class="text-right">{{ $t('common.total') }}</th>
                <th class="act-col"></th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="(it, i) in cart" :key="it.id"
                :class="{ 'is-selected': selectedIndex === i, 'just-added': it._flash }"
                @click="selectedIndex = i"
              >
                <td class="num-col">{{ i + 1 }}</td>
                <td>
                  <div class="d-flex align-center" style="gap:10px">
                    <v-avatar color="primary" variant="tonal" rounded="lg" size="36">
                      <v-icon>{{ catIcon(it.category) }}</v-icon>
                    </v-avatar>
                    <div class="min-width-0">
                      <div class="font-weight-medium text-truncate">{{ it.name }}</div>
                      <div class="text-caption text-medium-emphasis">{{ it.sku || '—' }}</div>
                    </div>
                  </div>
                </td>
                <td class="text-right text-medium-emphasis">{{ formatMoney(it.selling_price) }}</td>
                <td class="text-center">
                  <div class="smkt-qty-stepper" @click.stop>
                    <button class="smkt-qty-btn" @click="dec(i)"><v-icon size="16">mdi-minus</v-icon></button>
                    <input
                      type="number" min="1" :max="it.max_qty || 9999"
                      class="smkt-qty-input"
                      :value="it.quantity"
                      @input="setQty(i, $event.target.value)"
                      @click.stop
                    />
                    <button class="smkt-qty-btn smkt-qty-plus" :disabled="it.quantity >= (it.max_qty || 9999)" @click="inc(i)">
                      <v-icon size="16">mdi-plus</v-icon>
                    </button>
                  </div>
                </td>
                <td class="text-right font-weight-bold">{{ formatMoney(it.quantity * Number(it.selling_price || 0)) }}</td>
                <td class="act-col">
                  <v-btn icon="mdi-close" size="x-small" variant="text" color="error" @click.stop="removeAt(i)" />
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Totals strip -->
        <footer class="smkt-stage-footer">
          <div class="smkt-totals-grid">
            <div>
              <div class="smkt-tot-label">{{ $t('common.subtotal') }}</div>
              <div class="smkt-tot-val">{{ formatMoney(subtotal) }}</div>
            </div>
            <div>
              <div class="smkt-tot-label">{{ $t('common.discount') }}</div>
              <div class="smkt-tot-val text-error">- {{ formatMoney(Number(discount) || 0) }}</div>
            </div>
            <div>
              <div class="smkt-tot-label">VAT incl. (16%)</div>
              <div class="smkt-tot-val">{{ formatMoney(tax) }}</div>
            </div>
            <div class="smkt-grand">
              <div class="smkt-tot-label" style="opacity:0.8">TOTAL</div>
              <div class="smkt-grand-val">{{ formatMoney(total) }}</div>
            </div>
          </div>
        </footer>
      </section>

      <!-- RIGHT: Payment methods + actions -->
      <aside class="smkt-side">
        <div class="smkt-side-section">
          <div class="smkt-side-title">PAYMENT METHOD</div>
          <button
            v-for="m in paymentMethods" :key="m.value"
            class="smkt-pay-row"
            :class="{ 'is-active': paymentMethod === m.value }"
            @click="selectPaymentMethod(m.value)"
          >
            <v-avatar :color="m.color" variant="tonal" rounded="lg" size="40">
              <v-icon size="22">{{ m.icon }}</v-icon>
            </v-avatar>
            <div class="flex-grow-1 text-left min-width-0">
              <div class="smkt-pay-label">{{ m.label }}</div>
              <div class="smkt-pay-hint">{{ m.hint }}</div>
            </div>
            <v-icon v-if="paymentMethod === m.value" color="success">mdi-check-circle</v-icon>
            <v-icon v-else color="grey-lighten-1">mdi-circle-outline</v-icon>
          </button>
        </div>

        <div class="smkt-side-section">
          <div class="smkt-side-title">QUICK DISCOUNT</div>
          <div class="smkt-disc-grid">
            <button v-for="d in [0, 5, 10, 15, 20]" :key="d"
              class="smkt-disc-btn"
              :class="{ 'is-active': pendingDiscPct === d }"
              @click="applyPctDiscount(d)"
            >{{ d === 0 ? 'None' : d + '%' }}</button>
          </div>
        </div>

        <div class="smkt-side-section">
          <div class="smkt-side-title">SALE ACTIONS</div>
          <div class="smkt-actions">
            <button class="smkt-act-btn" :disabled="!cart.length" @click="parkSale">
              <v-icon>mdi-pause-circle</v-icon>
              <span>Hold</span>
            </button>
            <button class="smkt-act-btn" :disabled="!parkedSales.length" @click="showParked = true">
              <v-icon>mdi-tray-arrow-up</v-icon>
              <span>Resume</span>
              <span v-if="parkedSales.length" class="smkt-act-badge">{{ parkedSales.length }}</span>
            </button>
            <button class="smkt-act-btn" :disabled="!cart.length" @click="clearCart">
              <v-icon color="error">mdi-trash-can</v-icon>
              <span>Void</span>
            </button>
          </div>
        </div>

        <button class="smkt-pay-btn" :disabled="!cart.length || checkingOut" @click="openTender">
          <v-icon size="28" class="mr-2">mdi-cash-register</v-icon>
          <div class="smkt-pay-btn-content">
            <span class="smkt-pay-btn-label">PAY NOW</span>
            <span class="smkt-pay-btn-amount">{{ formatMoney(total) }}</span>
          </div>
        </button>
      </aside>
    </div>

    <!-- ============== TENDER MODAL ============== -->
    <v-dialog v-model="tender.show" max-width="780" persistent>
      <v-card rounded="xl" class="smkt-tender-card">
        <div class="smkt-tender-header">
          <div>
            <div class="text-overline" style="color:#94a3b8">AMOUNT DUE · {{ paymentMethodLabel }}</div>
            <div class="smkt-tender-due">{{ formatMoney(total) }}</div>
          </div>
          <v-btn icon="mdi-close" variant="text" color="white" @click="tender.show = false" />
        </div>

        <div class="smkt-tender-body">
          <div>
            <div class="text-overline text-medium-emphasis mb-2">QUICK TENDER (CASH)</div>
            <div class="smkt-quick-grid">
              <button v-for="amt in quickTenders" :key="amt"
                class="smkt-quick-btn"
                @click="setTendered(amt)"
              >{{ formatMoney(amt) }}</button>
              <button class="smkt-quick-btn smkt-exact" @click="setTendered(total)">EXACT</button>
            </div>

            <div v-if="paymentMethod === 'mpesa' || paymentMethod === 'card'" class="mt-3">
              <v-text-field
                v-model="tender.reference"
                :label="paymentMethod === 'mpesa' ? 'M-Pesa code' : 'Card last 4'"
                :prepend-inner-icon="paymentMethod === 'mpesa' ? 'mdi-cellphone' : 'mdi-credit-card'"
                density="compact" variant="outlined" hide-details
              />
            </div>
          </div>

          <div>
            <div class="text-overline text-medium-emphasis mb-2">AMOUNT TENDERED</div>
            <div class="smkt-tendered-display">{{ formatMoney(Number(tender.amount) || 0) }}</div>
            <div class="smkt-numpad">
              <button v-for="k in ['1','2','3','4','5','6','7','8','9','.','0','⌫']" :key="k"
                class="smkt-numkey"
                :class="{ 'smkt-numkey-fn': k === '⌫' || k === '.' }"
                @click="numKey(k)"
              >{{ k }}</button>
            </div>

            <div class="smkt-change-box" :class="changeAmount >= 0 ? 'is-ok' : 'is-short'">
              <div>
                <div class="text-overline" style="opacity:0.7">{{ changeAmount >= 0 ? 'CHANGE DUE' : 'STILL OWED' }}</div>
                <div class="smkt-change-val">{{ formatMoney(Math.abs(changeAmount)) }}</div>
              </div>
              <v-icon size="32">{{ changeAmount >= 0 ? 'mdi-cash-check' : 'mdi-cash-remove' }}</v-icon>
            </div>
          </div>
        </div>

        <div class="smkt-tender-footer">
          <v-btn
            color="error" variant="flat" rounded="lg" size="large"
            class="text-none font-weight-bold px-6"
            prepend-icon="mdi-close"
            @click="tender.show = false"
          >{{ $t('common.cancel') }}</v-btn>
          <v-spacer />
          <v-btn
            color="success" variant="flat" rounded="lg" size="x-large"
            class="text-none font-weight-bold px-8"
            :disabled="!canCharge" :loading="checkingOut"
            prepend-icon="mdi-check-bold"
            @click="confirmCheckout(false)"
          >
            COMPLETE SALE
          </v-btn>
        </div>
      </v-card>
    </v-dialog>

    <!-- ============== CREDIT CUSTOMER PROMPT ============== -->
    <v-dialog v-model="creditPrompt.show" max-width="480" persistent>
      <v-card rounded="lg" class="pa-5">
        <div class="d-flex align-center mb-3">
          <v-avatar color="warning" variant="tonal" rounded="lg" size="40" class="mr-3">
            <v-icon>mdi-account-cash</v-icon>
          </v-avatar>
          <div>
            <h3 class="text-h6 font-weight-bold mb-0">Credit sale details</h3>
            <div class="text-caption text-medium-emphasis">Capture customer info & repayment date</div>
          </div>
        </div>
        <v-text-field
          ref="creditNameInput"
          v-model="creditPrompt.name"
          label="Customer name *"
          placeholder="e.g. John Doe"
          variant="outlined" density="comfortable" autofocus
          prepend-inner-icon="mdi-account"
          :rules="[v => !!(v && v.trim()) || 'Customer name is required']"
          @keydown.enter="confirmCredit"
        />
        <v-text-field
          v-model="creditPrompt.phone"
          label="Phone number (optional)"
          placeholder="e.g. 0712 345 678"
          variant="outlined" density="comfortable"
          prepend-inner-icon="mdi-phone"
          hide-details="auto"
          class="mb-2"
          @keydown.enter="confirmCredit"
        />
        <v-text-field
          v-model="creditPrompt.dueDate"
          label="Due date *"
          type="date"
          variant="outlined" density="comfortable"
          prepend-inner-icon="mdi-calendar"
          :rules="[v => !!v || 'Due date is required']"
          :min="todayStr"
          hide-details="auto"
          class="mb-2"
        />
        <v-text-field
          v-model.number="creditPrompt.partialPaidAmount"
          label="Partial payment"
          type="number"
          min="0"
          :max="total"
          variant="outlined"
          density="comfortable"
          prepend-inner-icon="mdi-cash-fast"
          suffix="KES"
          hide-details="auto"
          class="mb-2"
        />
        <v-select
          v-model="creditPrompt.partialPaymentMethod"
          :items="partialPaymentMethods"
          item-title="label"
          item-value="value"
          label="Partial payment method"
          variant="outlined"
          density="comfortable"
          prepend-inner-icon="mdi-credit-card-outline"
          hide-details="auto"
          class="mb-2"
          :disabled="!(Number(creditPrompt.partialPaidAmount) > 0)"
        />
        <v-textarea
          v-model="creditPrompt.notes"
          label="Notes (optional)"
          variant="outlined" density="comfortable" rows="2" auto-grow
          prepend-inner-icon="mdi-note-text-outline"
          hide-details
        />
        <div class="d-flex align-center mt-4" style="gap:8px">
          <div class="text-caption text-medium-emphasis">
            {{ itemCount }} items · {{ formatMoney(total) }} ·
            Balance: {{ formatMoney(Math.max(0, total - (Number(creditPrompt.partialPaidAmount) || 0))) }}
          </div>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="cancelCredit">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="warning" variant="flat" rounded="lg" prepend-icon="mdi-check" class="text-none"
            :loading="checkingOut"
            :disabled="!(creditPrompt.name || '').trim() || !creditPrompt.dueDate || !cart.length || (Number(creditPrompt.partialPaidAmount) > 0 && creditPrompt.partialPaymentMethod === 'none')"
            @click="confirmCredit(true)">
            Save details
          </v-btn>
        </div>
      </v-card>
    </v-dialog>

    <!-- ============== HOLD SALE PROMPT ============== -->
    <v-dialog v-model="parkPrompt.show" max-width="460" persistent>
      <v-card rounded="lg" class="pa-5">
        <div class="d-flex align-center mb-3">
          <v-avatar color="warning" variant="tonal" rounded="lg" size="40" class="mr-3">
            <v-icon>mdi-pause-circle</v-icon>
          </v-avatar>
          <div>
            <h3 class="text-h6 font-weight-bold mb-0">Hold sale</h3>
            <div class="text-caption text-medium-emphasis">Save this cart for later under a customer name</div>
          </div>
        </div>
        <v-text-field
          ref="parkNameInput"
          v-model="parkPrompt.name"
          label="Customer name"
          placeholder="e.g. John Doe"
          variant="outlined" density="comfortable" autofocus
          prepend-inner-icon="mdi-account"
          :rules="[v => !!(v && v.trim()) || 'Customer name is required']"
          @keydown.enter="confirmPark"
        />
        <v-text-field
          v-model="parkPrompt.phone"
          label="Phone number (optional)"
          placeholder="e.g. 0712 345 678"
          variant="outlined" density="comfortable"
          prepend-inner-icon="mdi-phone"
          hide-details="auto"
          class="mb-2"
          @keydown.enter="confirmPark"
        />
        <v-textarea
          v-model="parkPrompt.notes"
          label="Notes (optional)"
          variant="outlined" density="comfortable" rows="2" auto-grow
          prepend-inner-icon="mdi-note-text-outline"
          hide-details
        />
        <div class="d-flex align-center mt-4" style="gap:8px">
          <div class="text-caption text-medium-emphasis">
            {{ itemCount }} items · {{ formatMoney(total) }}
          </div>
          <v-spacer />
          <v-btn variant="text" class="text-none" :disabled="parkPrompt.saving" @click="parkPrompt.show = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="warning" variant="flat" rounded="lg" prepend-icon="mdi-pause-circle" class="text-none"
            :loading="parkPrompt.saving"
            :disabled="!(parkPrompt.name || '').trim()"
            @click="confirmPark">
            Hold sale
          </v-btn>
        </div>
      </v-card>
    </v-dialog>

    <!-- ============== PARKED SALES LIST ============== -->
    <v-dialog v-model="showParked" max-width="540">
      <v-card rounded="lg" class="pa-4">
        <h3 class="text-h6 font-weight-bold mb-3">Parked sales</h3>
        <div v-if="!parkedSales.length" class="text-center py-6 text-medium-emphasis">
          <v-icon size="48" color="grey">mdi-tray-arrow-up</v-icon>
          <div>No parked sales</div>
        </div>
        <div v-for="(p, i) in parkedSales" :key="p.id" class="d-flex align-center pa-2 mb-2 smkt-parked-row">
          <div class="flex-grow-1">
            <div class="font-weight-medium">#{{ p.id }} · {{ p.customerName || 'Walk-in' }}</div>
            <div class="text-caption text-medium-emphasis">{{ p.items.length }} items · {{ formatMoney(p.total) }} · {{ p.time }}</div>
          </div>
          <v-btn variant="tonal" color="primary" size="small" rounded="lg" class="text-none mr-2" @click="resumeSale(i)">Resume</v-btn>
          <v-btn icon="mdi-close" variant="text" size="small" color="error" @click="deleteParked(i)" />
        </div>
      </v-card>
    </v-dialog>

    <!-- ============== RECEIPT ============== -->
    <v-dialog v-model="receipt.show" max-width="380" persistent>
      <v-card rounded="lg" class="pa-4 smkt-receipt">
        <div id="smkt-receipt-print">
        <div class="text-center mb-3">
          <v-avatar color="success" variant="tonal" size="64" class="mb-2 no-print">
            <v-icon size="36">mdi-check-bold</v-icon>
          </v-avatar>
          <h3 class="text-h6 font-weight-bold">Sale Completed</h3>
          <div class="text-caption text-medium-emphasis">Receipt #{{ receipt.id }} · {{ receipt.time }}</div>
        </div>
        <v-divider class="mb-3" />
        <div class="smkt-receipt-items">
          <div v-for="it in receipt.items" :key="it.name" class="d-flex justify-space-between text-body-2 mb-1">
            <span>{{ it.quantity }} × {{ it.name }}</span>
            <span>{{ formatMoney(it.line) }}</span>
          </div>
        </div>
        <v-divider class="my-2" />
        <div class="d-flex justify-space-between text-body-2"><span>{{ $t('common.subtotal') }}</span><span>{{ formatMoney(receipt.subtotal) }}</span></div>
        <div class="d-flex justify-space-between text-body-2"><span>{{ $t('common.tax') }}</span><span>{{ formatMoney(receipt.tax) }}</span></div>
        <div class="d-flex justify-space-between font-weight-bold mt-2 text-h6">
          <span>TOTAL</span>
          <span class="text-primary">{{ formatMoney(receipt.total) }}</span>
        </div>
        <div class="d-flex justify-space-between text-body-2 mt-1">
          <span>Tendered ({{ receipt.method }})</span>
          <span>{{ formatMoney(receipt.tendered) }}</span>
        </div>
        <div class="d-flex justify-space-between font-weight-bold text-success">
          <span>Change</span>
          <span>{{ formatMoney(receipt.change) }}</span>
        </div>
        </div>
        <v-btn block color="primary" rounded="lg" class="text-none mt-4" size="large" @click="newSale">
          NEW SALE
        </v-btn>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2500">{{ snack.text }}</v-snackbar>
  </div>
</template>

<script setup>
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

import { ref, reactive, computed, onMounted, onBeforeUnmount, nextTick, watch } from 'vue'
import { useAuthStore } from '~/stores/auth'
import { useBranchStore } from '~/stores/branch'
import { formatMoney } from '~/utils/format'

definePageMeta({ layout: 'default' })

const auth = useAuthStore()
const branchStore = useBranchStore()
const { $api } = useNuxtApp()

const today = new Date().toLocaleDateString(undefined, { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' })
const clock = ref(new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }))
const _clockTimer = setInterval(() => { clock.value = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) }, 30000)
onBeforeUnmount(() => clearInterval(_clockTimer))

const laneId = '01'

const products = ref([])
const search = ref('')
const scanCode = ref('')
const searchOpen = ref(false)
const activeIdx = ref(0)
const cart = ref([])
const customerName = ref('')
const discount = ref(0)
const pendingDiscPct = ref(0)
const selectedIndex = ref(-1)
const checkingOut = ref(false)
const orderNumber = ref(_genOrderNum())
const snack = reactive({ show: false, text: '', color: 'success' })
const todayStats = reactive({ count: 0, revenue: 0 })
const scanInput = ref(null)

const paymentMethod = ref('cash')
const tender = reactive({ show: false, amount: '', reference: '' })
const showParked = ref(false)
const parkedSales = ref([])
const parkPrompt = reactive({ show: false, name: '', phone: '', notes: '', saving: false })
const parkNameInput = ref(null)
const creditPrompt = reactive({
  show: false,
  name: '',
  phone: '',
  dueDate: '',
  partialPaidAmount: 0,
  partialPaymentMethod: 'none',
  notes: '',
})
const creditNameInput = ref(null)
const creditInfo = reactive({
  name: '',
  phone: '',
  dueDate: '',
  partialPaidAmount: 0,
  partialPaymentMethod: 'none',
  notes: '',
})
const receipt = reactive({ show: false, id: '', time: '', items: [], subtotal: 0, tax: 0, total: 0, tendered: 0, change: 0, method: '' })

const paymentMethods = [
  { value: 'cash',      label: 'Cash',      hint: 'Notes & coins',     icon: 'mdi-cash',           color: 'success' },
  { value: 'mpesa',     label: 'M-Pesa',    hint: 'Mobile money',      icon: 'mdi-cellphone',      color: 'success' },
  { value: 'card',      label: 'Card',      hint: 'Visa / Mastercard', icon: 'mdi-credit-card',    color: 'primary' },
  { value: 'insurance', label: 'Insurance', hint: 'Approved schemes',  icon: 'mdi-shield-account', color: 'purple' },
  { value: 'credit',    label: 'Credit',    hint: 'Customer account',  icon: 'mdi-account-cash',   color: 'warning' },
]
const partialPaymentMethods = [
  { value: 'none', label: 'None' },
  { value: 'cash', label: 'Cash' },
  { value: 'mpesa', label: 'M-Pesa' },
  { value: 'card', label: 'Card' },
  { value: 'insurance', label: 'Insurance' },
]
const paymentMethodLabel = computed(() => paymentMethods.find(m => m.value === paymentMethod.value)?.label || paymentMethod.value)

const quickTenders = computed(() => {
  const t = total.value
  const base = [50, 100, 200, 500, 1000, 2000, 5000]
  const result = base.filter(b => b >= t).slice(0, 4)
  const roundTo = (n, step) => Math.ceil(n / step) * step
  for (const step of [100, 500, 1000]) {
    const v = roundTo(t, step)
    if (v > t && !result.includes(v)) result.push(v)
  }
  return [...new Set(result)].sort((a, b) => a - b).slice(0, 5)
})

function _genOrderNum() {
  const d = new Date()
  return `${d.getFullYear().toString().slice(-2)}${String(d.getMonth() + 1).padStart(2, '0')}${String(d.getDate()).padStart(2, '0')}-${Math.floor(Math.random() * 9000 + 1000)}`
}

function nameOf(p) { return p.medication_name || p.name || 'Unnamed' }
function stockOf(p) { return Number(p.total_quantity ?? p.quantity ?? 0) }

const _catIcons = {
  'beverages': 'mdi-cup', 'drinks': 'mdi-cup', 'food': 'mdi-food', 'snacks': 'mdi-cookie',
  'bakery': 'mdi-bread-slice', 'dairy': 'mdi-cheese', 'fruits': 'mdi-fruit-cherries',
  'vegetables': 'mdi-carrot', 'meat': 'mdi-food-steak', 'cleaning': 'mdi-spray-bottle',
  'household': 'mdi-home', 'personal care': 'mdi-shower', 'toiletries': 'mdi-shower',
  'baby': 'mdi-baby-carriage', 'electronics': 'mdi-power-plug', 'stationery': 'mdi-pencil',
  'medicine': 'mdi-pill', 'pharmacy': 'mdi-pill', 'tablets': 'mdi-pill',
  'syrup': 'mdi-bottle-tonic', 'syrups': 'mdi-bottle-tonic', 'capsules': 'mdi-pill',
  'injections': 'mdi-needle', 'devices': 'mdi-medical-bag',
}
function catIcon(name) {
  if (!name) return 'mdi-tag'
  const k = String(name).toLowerCase()
  for (const key in _catIcons) if (k.includes(key)) return _catIcons[key]
  return 'mdi-tag'
}

const serverResults = ref([])
const searching = ref(false)
let _searchTimer = null

const searchResults = computed(() => {
  const q = search.value.toLowerCase().trim()
  if (!q) return []
  const allItems = [...products.value, ...serverResults.value.filter(sr => !products.value.some(p => p.id === sr.id))]
  return allItems.filter(p =>
    nameOf(p).toLowerCase().includes(q) ||
    (p.abbreviation || '').toLowerCase().includes(q) ||
    (p.barcode || '').toLowerCase().includes(q) ||
    (p.sku || '').toLowerCase().includes(q) ||
    (p.medication_id || '').toLowerCase().includes(q)
  ).slice(0, 8)
})

watch(() => search.value, (q) => {
  clearTimeout(_searchTimer)
  serverResults.value = []
  const trimmed = q.trim()
  if (trimmed.length < 2) return
  _searchTimer = setTimeout(async () => {
    const localCount = products.value.filter(p =>
      nameOf(p).toLowerCase().includes(trimmed.toLowerCase()) ||
      (p.abbreviation || '').toLowerCase().includes(trimmed.toLowerCase()) ||
      (p.barcode || '').toLowerCase().includes(trimmed.toLowerCase()) ||
      (p.sku || '').toLowerCase().includes(trimmed.toLowerCase()) ||
      (p.medication_id || '').toLowerCase().includes(trimmed.toLowerCase())
    ).length
    if (localCount > 3) return
    searching.value = true
    const results = await $api.get(`/inventory/stocks/?search=${encodeURIComponent(trimmed)}&is_active=true&page_size=20`)
      .then(r => r.data?.results || r.data || []).catch(() => [])
    serverResults.value = results
    searching.value = false
  }, 400)
})

watch(scanCode, v => { search.value = v || ''; searchOpen.value = !!(v && v.trim()); activeIdx.value = 0 })

function onScanBlur() { setTimeout(() => { searchOpen.value = false }, 180) }

const itemCount = computed(() => cart.value.reduce((s, it) => s + it.quantity, 0))
const subtotal = computed(() => cart.value.reduce((s, it) => s + it.quantity * Number(it.selling_price || 0), 0))
// Selling prices are VAT-inclusive (16%). Total = subtotal - discount; tax is the embedded VAT portion.
const total = computed(() => Math.max(0, subtotal.value - (Number(discount.value) || 0)))
const tax = computed(() => total.value * (0.16 / 1.16))
const netSubtotal = computed(() => total.value - tax.value)

const changeAmount = computed(() => (Number(tender.amount) || 0) - total.value)
const canCharge = computed(() => {
  if (!cart.value.length) return false
  if (paymentMethod.value === 'cash') return changeAmount.value >= 0
  if (paymentMethod.value === 'credit') {
    const partial = Number(creditInfo.partialPaidAmount) || 0
    if (!(creditInfo.name && creditInfo.dueDate)) return false
    if (partial > total.value) return false
    if (partial > 0 && creditInfo.partialPaymentMethod === 'none') return false
    return true
  }
  return true
})

function applyPctDiscount(p) {
  pendingDiscPct.value = p
  discount.value = +(subtotal.value * (p / 100)).toFixed(2)
}

const todayStr = computed(() => new Date().toISOString().slice(0, 10))

async function selectPaymentMethod(value) {
  paymentMethod.value = value
  if (value === 'credit') {
    creditPrompt.name = creditInfo.name || customerName.value || ''
    creditPrompt.phone = creditInfo.phone || ''
    creditPrompt.dueDate = creditInfo.dueDate || ''
    creditPrompt.partialPaidAmount = Number(creditInfo.partialPaidAmount) || 0
    creditPrompt.partialPaymentMethod = creditInfo.partialPaymentMethod || 'none'
    creditPrompt.notes = creditInfo.notes || ''
    creditPrompt.show = true
    await nextTick()
    creditNameInput.value?.focus?.()
  }
}

async function confirmCredit(autoCheckout = false) {
  const name = (creditPrompt.name || '').trim()
  if (!name) { flash('Customer name is required', 'error'); return }
  if (!creditPrompt.dueDate) { flash('Due date is required', 'error'); return }
  const partial = Math.max(0, Number(creditPrompt.partialPaidAmount) || 0)
  if (partial > total.value) { flash('Partial payment cannot exceed total', 'error'); return }
  if (partial > 0 && creditPrompt.partialPaymentMethod === 'none') {
    flash('Select partial payment method', 'error'); return
  }
  creditInfo.name = name
  creditInfo.phone = (creditPrompt.phone || '').trim()
  creditInfo.dueDate = creditPrompt.dueDate
  creditInfo.partialPaidAmount = partial
  creditInfo.partialPaymentMethod = partial > 0 ? creditPrompt.partialPaymentMethod : 'none'
  creditInfo.notes = (creditPrompt.notes || '').trim()
  customerName.value = name
  creditPrompt.show = false
  if (autoCheckout) {
    await confirmCheckout(false)
    return
  }
  flash(`Credit details saved for "${name}" (due ${creditInfo.dueDate})`)
}

function cancelCredit() {
  creditPrompt.show = false
  if (!creditInfo.name || !creditInfo.dueDate) {
    paymentMethod.value = 'cash'
  }
}

function _flashRow(item) {
  item._flash = true
  setTimeout(() => { item._flash = false }, 600)
}

function addToCart(p) {
  if (stockOf(p) <= 0) { flash(`${nameOf(p)} is out of stock`, 'error'); return }
  const found = cart.value.find(i => i.id === p.id)
  if (found) {
    if (found.quantity < stockOf(p)) { found.quantity++; _flashRow(found) }
    else flash('Stock limit reached', 'warning')
  } else {
    const newItem = {
      id: p.id, name: nameOf(p),
      sku: p.barcode || p.sku || p.medication_id || '',
      category: p.category_name || p.category || '',
      selling_price: p.selling_price, quantity: 1,
      max_qty: stockOf(p),
      _flash: true,
    }
    cart.value.push(newItem)
    setTimeout(() => { newItem._flash = false }, 600)
  }
  selectedIndex.value = cart.value.findIndex(i => i.id === p.id)
}
function inc(i) {
  const it = cart.value[i]
  if (it.quantity < (it.max_qty || 9999)) it.quantity++
  else flash('Stock limit reached', 'warning')
}
function dec(i) {
  if (cart.value[i].quantity > 1) cart.value[i].quantity--
  else cart.value.splice(i, 1)
}
function setQty(i, val) {
  const it = cart.value[i]
  let n = parseInt(val, 10)
  if (isNaN(n) || n < 1) n = 1
  const max = it.max_qty || 9999
  if (n > max) { n = max; flash('Stock limit reached', 'warning') }
  it.quantity = n
}
function removeAt(i) { cart.value.splice(i, 1) }
function clearCart() {
  cart.value = []
  customerName.value = ''
  discount.value = 0
  pendingDiscPct.value = 0
  selectedIndex.value = -1
  creditInfo.partialPaidAmount = 0
  creditInfo.partialPaymentMethod = 'none'
  orderNumber.value = _genOrderNum()
  focusScan()
}

function flash(text, color = 'success') {
  snack.text = text; snack.color = color; snack.show = true
}

function focusScan() { nextTick(() => scanInput.value?.focus()) }

function handleScan() {
  const code = (scanCode.value || '').trim()
  if (!code) return
  let p = products.value.find(x =>
    (x.barcode || '').toLowerCase() === code.toLowerCase() ||
    (x.sku || '').toLowerCase() === code.toLowerCase() ||
    (x.medication_id || '').toLowerCase() === code.toLowerCase()
  )
  if (!p && searchResults.value.length) p = searchResults.value[activeIdx.value] || searchResults.value[0]
  if (p) {
    addToCart(p)
    scanCode.value = ''
    search.value = ''
    searchOpen.value = false
  } else {
    flash(`No product matches "${code}"`, 'error')
  }
}

function selectFromSearch(p) {
  addToCart(p)
  scanCode.value = ''
  search.value = ''
  searchOpen.value = false
  focusScan()
}

function setTendered(amt) { tender.amount = String(amt) }
function numKey(k) {
  let v = String(tender.amount || '')
  if (k === '⌫') v = v.slice(0, -1)
  else if (k === '.') { if (!v.includes('.')) v = (v || '0') + '.' }
  else v = v + k
  tender.amount = v
}

function openTender() {
  if (!cart.value.length) return
  tender.amount = String(total.value.toFixed(2))
  tender.reference = ''
  tender.show = true
  tender.reference = ''
  tender.show = true
}

async function parkSale() {
  if (!cart.value.length) return
  parkPrompt.name = customerName.value || ''
  parkPrompt.phone = ''
  parkPrompt.notes = ''
  parkPrompt.show = true
  await nextTick()
  parkNameInput.value?.focus?.()
}

async function confirmPark() {
  if (!cart.value.length) return
  const name = (parkPrompt.name || '').trim()
  if (!name) { flash('Customer name is required', 'error'); return }
  parkPrompt.saving = true
  try {
    const payload = {
      customer_name: name,
      customer_phone: (parkPrompt.phone || '').trim(),
      payment_method: paymentMethod.value || '',
      discount: Number(discount.value) || 0,
      notes: parkPrompt.notes || '',
      items: cart.value.map(it => ({
        stock_id: it.id,
        name: it.name,
        sku: it.sku || '',
        category: it.category || '',
        selling_price: Number(it.selling_price) || 0,
        quantity: it.quantity,
        max_qty: it.max_qty || 9999,
      })),
    }
    const res = await $api.post('/pos/parked-sales/', payload)
    parkedSales.value.unshift(_normalizeParked(res.data))
    customerName.value = name
    flash(`Sale held under "${name}"`)
    parkPrompt.show = false
    clearCart()
  } catch (e) {
    flash(e?.response?.data?.detail || 'Failed to hold sale', 'error')
  } finally {
    parkPrompt.saving = false
  }
}
async function resumeSale(i) {
  const p = parkedSales.value[i]
  if (!p) return
  try {
    cart.value = (p.items || []).map(it => ({
      id: it.stock_id ?? it.id,
      name: it.name,
      sku: it.sku || '',
      category: it.category || '',
      selling_price: it.selling_price,
      quantity: it.quantity,
      max_qty: it.max_qty || 9999,
    }))
    customerName.value = p.customerName || ''
    discount.value = Number(p.discount) || 0
    if (p.payment_method) paymentMethod.value = p.payment_method
    if (p.serverId) {
      await $api.delete(`/pos/parked-sales/${p.serverId}/`).catch(() => {})
    }
    parkedSales.value.splice(i, 1)
    showParked.value = false
    focusScan()
  } catch (e) {
    flash('Failed to resume sale', 'error')
  }
}
async function deleteParked(i) {
  const p = parkedSales.value[i]
  if (p?.serverId) {
    await $api.delete(`/pos/parked-sales/${p.serverId}/`).catch(() => {})
  }
  parkedSales.value.splice(i, 1)
}

function _normalizeParked(srv) {
  return {
    serverId: srv.id,
    id: srv.park_number,
    customerName: srv.customer_name || '',
    discount: Number(srv.discount) || 0,
    payment_method: srv.payment_method || '',
    items: srv.items || [],
    total: Number(srv.total) || 0,
    time: new Date(srv.created_at).toLocaleString(),
    cashier_name: srv.cashier_name || '',
  }
}

async function load() {
  products.value = await $api.get('/inventory/stocks/?page_size=5000&is_active=true&ordering=-created_at')
    .then(r => r.data?.results || r.data || []).catch(() => [])
  const tx = await $api.get('/pos/transactions/?page_size=200')
    .then(r => r.data?.results || r.data || []).catch(() => [])
  const todayKey = new Date().toISOString().slice(0, 10)
  const todayTx = tx.filter(t => (t.created_at || '').startsWith(todayKey))
  todayStats.count = todayTx.length
  todayStats.revenue = todayTx.reduce((s, t) => s + Number(t.total || t.total_amount || 0), 0)
  // Load parked sales from server
  const parked = await $api.get('/pos/parked-sales/?page_size=100')
    .then(r => r.data?.results || r.data || []).catch(() => [])
  parkedSales.value = parked.map(_normalizeParked)
  // If a parked sale was selected from the parked screen, resume it now
  try {
    const raw = sessionStorage.getItem('smkt_resume_parked')
    if (raw) {
      sessionStorage.removeItem('smkt_resume_parked')
      const srv = JSON.parse(raw)
      const idx = parkedSales.value.findIndex(p => p.serverId === srv.id)
      if (idx >= 0) await resumeSale(idx)
    }
  } catch (e) {}
  focusScan()
}
onMounted(load)

// ===== Persist cart & sale state to localStorage =====
const LS_KEY = 'smkt_pos_state_v1'
onMounted(() => {
  if (typeof window === 'undefined') return
  try {
    const raw = localStorage.getItem(LS_KEY)
    if (!raw) return
    const s = JSON.parse(raw)
    if (Array.isArray(s.cart)) cart.value = s.cart
    if (typeof s.customerName === 'string') customerName.value = s.customerName
    if (typeof s.discount === 'number') discount.value = s.discount
    if (typeof s.pendingDiscPct === 'number') pendingDiscPct.value = s.pendingDiscPct
    if (typeof s.paymentMethod === 'string') paymentMethod.value = s.paymentMethod
    if (typeof s.orderNumber === 'string') orderNumber.value = s.orderNumber
    // parkedSales is fetched from server in load(); skip persisting it here
  } catch (e) { /* ignore corrupt state */ }
})
watch(
  () => ({
    cart: cart.value,
    customerName: customerName.value,
    discount: discount.value,
    pendingDiscPct: pendingDiscPct.value,
    paymentMethod: paymentMethod.value,
    orderNumber: orderNumber.value,
  }),
  (s) => {
    if (typeof window === 'undefined') return
    try { localStorage.setItem(LS_KEY, JSON.stringify(s)) } catch (e) {}
  },
  { deep: true }
)

async function confirmCheckout(autoPrint = false) {
  if (!canCharge.value) return
  checkingOut.value = true
  try {
    const items = cart.value.map(c => ({ stock_id: c.id, quantity: c.quantity }))
    const payload = {
      payment_method: paymentMethod.value,
      customer_name: customerName.value || 'Walk-in',
      discount: Number(discount.value) || 0,
      items,
      branch_id: branchStore.currentBranchId,
    }
    if (tender.reference) payload.payment_reference = tender.reference
    if (paymentMethod.value === 'credit') {
      payload.customer_name = creditInfo.name || customerName.value || 'Walk-in'
      payload.customer_phone = creditInfo.phone || ''
      payload.credit_due_date = creditInfo.dueDate || null
      payload.credit_notes = creditInfo.notes || ''
      payload.partial_paid_amount = Number(creditInfo.partialPaidAmount) || 0
      payload.partial_payment_method = (Number(creditInfo.partialPaidAmount) || 0) > 0
        ? creditInfo.partialPaymentMethod
        : 'none'
      const ref = `Due: ${creditInfo.dueDate}`
        + ((Number(creditInfo.partialPaidAmount) || 0) > 0 ? ` | Partial: ${Number(creditInfo.partialPaidAmount)} via ${creditInfo.partialPaymentMethod}` : '')
        + (creditInfo.notes ? ` - ${creditInfo.notes}` : '')
      payload.payment_reference = ref
    }
    const res = await $api.post('/pos/transactions/', payload)
    const tend = paymentMethod.value === 'cash' ? (Number(tender.amount) || total.value) : total.value
    receipt.id = res.data?.receipt_number || res.data?.transaction_number || res.data?.id || orderNumber.value
    receipt.time = new Date().toLocaleTimeString()
    receipt.items = cart.value.map(c => ({ name: c.name, quantity: c.quantity, line: c.quantity * Number(c.selling_price || 0) }))
    receipt.subtotal = subtotal.value
    receipt.tax = tax.value
    receipt.total = total.value
    receipt.tendered = tend
    receipt.change = Math.max(0, tend - total.value)
    receipt.method = paymentMethodLabel.value
    tender.show = false
    receipt.show = true
    clearCart()
    await load()
    if (autoPrint) {
      await nextTick()
      setTimeout(() => printReceipt(), 200)
    }
  } catch (e) {
    const data = e?.response?.data
    let msg = data?.detail
    if (!msg && data && typeof data === 'object') {
      const parts = []
      for (const [k, v] of Object.entries(data)) {
        const text = Array.isArray(v) ? v.join(', ') : (typeof v === 'string' ? v : JSON.stringify(v))
        parts.push(k === 'non_field_errors' ? text : `${k}: ${text}`)
      }
      if (parts.length) msg = parts.join(' \u2014 ')
    }
    flash(msg || 'Failed to complete sale', 'error')
  } finally {
    checkingOut.value = false
  }
}

function newSale() {
  receipt.show = false
  focusScan()
}

function printReceipt() {
  const node = document.getElementById('smkt-receipt-print')
  if (!node) { try { window.print() } catch (_) {} ; return }
  const html = node.innerHTML
  const w = window.open('', 'PRINT', 'width=400,height=600')
  if (!w) return
  w.document.write(`<!doctype html><html><head><title>Receipt ${receipt.id || ''}</title>
<style>
  *{box-sizing:border-box}
  body{font-family:'Courier New',monospace;font-size:12px;color:#000;margin:0;padding:12px;width:300px}
  h3{font-size:14px;margin:4px 0;text-align:center}
  .text-center{text-align:center}
  .text-caption{font-size:10px;color:#444}
  .d-flex{display:flex}
  .justify-space-between{justify-content:space-between}
  .font-weight-bold{font-weight:bold}
  .text-h6{font-size:14px}
  .text-success,.text-primary{color:#000}
  .mb-1{margin-bottom:2px}.mb-2{margin-bottom:4px}.mb-3{margin-bottom:8px}.mt-1{margin-top:2px}.mt-2{margin-top:4px}.my-2{margin:4px 0}
  hr,.v-divider{border:none;border-top:1px dashed #000;margin:6px 0}
  .smkt-receipt-items{margin:6px 0}
  .no-print{display:none !important}
</style></head><body>${html}</body></html>`)
  w.document.close()
  w.focus()
  setTimeout(() => { try { w.print() } catch (_) {} ; try { w.close() } catch (_) {} }, 250)
}

function onKey(e) {
  if (e.key === 'F2') { e.preventDefault(); focusScan(); return }
  if (e.target?.tagName === 'INPUT' || e.target?.tagName === 'TEXTAREA') {
    if (e.key === 'ArrowDown' && searchOpen.value) {
      e.preventDefault()
      activeIdx.value = Math.min(activeIdx.value + 1, searchResults.value.length - 1)
    } else if (e.key === 'ArrowUp' && searchOpen.value) {
      e.preventDefault()
      activeIdx.value = Math.max(activeIdx.value - 1, 0)
    } else if (e.key === 'Escape' && searchOpen.value) {
      searchOpen.value = false
    }
    return
  }
  if (e.key === 'F9' && cart.value.length) { e.preventDefault(); openTender() }
  else if (e.key === 'F4') { e.preventDefault(); parkSale() }
  else if (e.key === 'Escape' && cart.value.length) { e.preventDefault(); clearCart() }
}
onMounted(() => window.addEventListener('keydown', onKey))
onBeforeUnmount(() => window.removeEventListener('keydown', onKey))
</script>

<style scoped>
/* ===== Theme-aware palette =====
   Defaults below are the DARK palette. The LIGHT palette is supplied by
   the unscoped `<style>` block at the bottom of this file, which targets
   `.v-theme--light .smkt-shell`. */
.smkt-shell {
  --smkt-bg: linear-gradient(180deg, #0f172a 0%, #1e293b 100%);
  --smkt-panel: rgba(15, 23, 42, 0.5);
  --smkt-panel-strong: rgba(15, 23, 42, 0.85);
  --smkt-stage-header: linear-gradient(135deg, #1e293b, #334155);
  --smkt-stage-footer: linear-gradient(135deg, #0f172a, #1e293b);
  --smkt-cart-header: #1e293b;
  --smkt-input-bg: rgba(15, 23, 42, 0.6);
  --smkt-border: rgba(255, 255, 255, 0.08);
  --smkt-border-soft: rgba(255, 255, 255, 0.06);
  --smkt-divider-dash: rgba(255, 255, 255, 0.06);
  --smkt-row-hover: rgba(255, 255, 255, 0.03);
  --smkt-row-soft: rgba(255, 255, 255, 0.03);
  --smkt-row-soft-hover: rgba(255, 255, 255, 0.08);
  --smkt-text: #f1f5f9;
  --smkt-text-soft: #cbd5e1;
  --smkt-text-mute: #94a3b8;
  --smkt-text-faint: #64748b;
  --smkt-kbd-bg: #0f172a;
  --smkt-tendered-bg: #0f172a;

  height: calc(100vh - 64px);
  display: flex;
  flex-direction: column;
  background: var(--smkt-bg);
  color: var(--smkt-text);
}

/* ===== TOP BAR ===== */
.smkt-topbar {
  height: 64px;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 0 16px;
  background: var(--smkt-panel-strong);
  border-bottom: 1px solid var(--smkt-border);
  backdrop-filter: blur(8px);
  z-index: 5;
}
.smkt-brand { font-size: 14px; font-weight: 800; letter-spacing: 0.12em; color: var(--smkt-text); }
.smkt-subbrand { font-size: 11px; color: var(--smkt-text-mute); margin-top: 2px; }

.smkt-scan {
  flex: 1;
  position: relative;
  display: flex;
  align-items: center;
  background: rgba(34, 197, 94, 0.08);
  border: 1px solid rgba(34, 197, 94, 0.35);
  border-radius: 10px;
  padding: 8px 14px;
  max-width: 720px;
  animation: scan-pulse 2.5s ease-in-out infinite;
}
@keyframes scan-pulse {
  0%, 100% { box-shadow: 0 0 0 0 rgba(34, 197, 94, 0.0); }
  50% { box-shadow: 0 0 0 6px rgba(34, 197, 94, 0.15); }
}
.smkt-scan-input {
  flex: 1;
  background: transparent;
  border: none;
  outline: none;
  color: var(--smkt-text);
  font-size: 16px;
  font-family: 'Courier New', monospace;
  letter-spacing: 0.04em;
}
.smkt-scan-input::placeholder { color: var(--smkt-text-faint); }

.smkt-search-dropdown {
  position: absolute;
  top: calc(100% + 6px);
  left: 0;
  right: 0;
  background: var(--smkt-cart-header);
  border: 1px solid rgba(34, 197, 94, 0.35);
  border-radius: 12px;
  box-shadow: 0 16px 40px rgba(0, 0, 0, 0.35);
  max-height: 420px;
  overflow-y: auto;
  z-index: 30;
  padding: 6px;
}
.smkt-search-empty {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
  color: var(--smkt-text-mute);
  font-size: 14px;
}
.smkt-search-row {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 12px;
  background: transparent;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-family: inherit;
  transition: background 0.1s;
}
.smkt-search-row:hover, .smkt-search-row.is-active {
  background: rgba(34, 197, 94, 0.15);
}
.smkt-search-row.is-out { opacity: 0.4; cursor: not-allowed; }
.smkt-result-name { color: var(--smkt-text); }
.smkt-result-meta { color: var(--smkt-text-mute); }
.smkt-abbr-chip {
  display: inline-flex;
  align-items: center;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.4px;
  padding: 1px 7px;
  border-radius: 6px;
  background: rgba(99, 102, 241, 0.22);
  color: #a5b4fc;
  border: 1px solid rgba(99, 102, 241, 0.45);
  text-transform: uppercase;
  flex-shrink: 0;
  line-height: 1.4;
}
.smkt-search-price {
  font-size: 16px;
  font-weight: 800;
  color: #4ade80;
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
  flex-shrink: 0;
  min-width: 90px;
  text-align: right;
  padding: 4px 10px;
  background: rgba(74, 222, 128, 0.12);
  border-radius: 6px;
}

.smkt-meta {
  text-align: right;
  padding: 0 10px;
  border-left: 1px solid var(--smkt-border);
}
.smkt-meta-label { font-size: 9px; letter-spacing: 0.12em; color: var(--smkt-text-mute); }
.smkt-meta-value { font-size: 14px; font-weight: 700; color: var(--smkt-text); }

/* ===== MAIN GRID ===== */
.smkt-main {
  flex: 1;
  display: grid;
  grid-template-columns: 80% 20%;
  gap: 12px;
  padding: 12px;
  overflow: hidden;
}
@media (max-width: 1100px) {
  .smkt-main { grid-template-columns: 1fr; grid-template-rows: 1fr auto; }
}

/* ===== STAGE (left, big empty area) ===== */
.smkt-stage {
  display: flex;
  flex-direction: column;
  background: var(--smkt-panel);
  border: 1px solid var(--smkt-border-soft);
  border-radius: 14px;
  overflow: hidden;
}
.smkt-stage-header {
  flex-shrink: 0;
  display: grid;
  grid-template-columns: 1fr 1fr auto;
  gap: 24px;
  padding: 18px 24px;
  background: var(--smkt-stage-header);
  align-items: center;
}
.smkt-order-num {
  font-size: 22px;
  font-weight: 800;
  color: var(--smkt-text);
  font-variant-numeric: tabular-nums;
  letter-spacing: 0.03em;
}
.smkt-cust-input {
  background: var(--smkt-input-bg);
  border: 1px solid var(--smkt-border);
  border-radius: 8px;
  padding: 6px 12px;
  color: var(--smkt-text);
  font-size: 14px;
  font-weight: 600;
  text-align: right;
  outline: none;
  width: 240px;
}
.smkt-cust-input::placeholder { color: var(--smkt-text-faint); font-weight: normal; }
.smkt-cust-input:focus { border-color: #3b82f6; }

/* Idle hero */
.smkt-idle {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 40px;
  text-align: center;
  color: var(--smkt-text-faint);
}
.smkt-idle-pulse { animation: idle-pulse 2.5s ease-in-out infinite; }
@keyframes idle-pulse {
  0%, 100% { transform: scale(1); opacity: 0.6; }
  50% { transform: scale(1.05); opacity: 1; }
}
.smkt-idle-title {
  font-size: 28px;
  font-weight: 800;
  letter-spacing: 0.2em;
  color: var(--smkt-text-mute);
  margin-top: 24px;
}
.smkt-idle-sub {
  font-size: 15px;
  color: var(--smkt-text-faint);
  margin-top: 8px;
  max-width: 420px;
}
.smkt-shortcuts {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
  gap: 10px;
  margin-top: 36px;
  width: 100%;
  max-width: 720px;
}
.smkt-shortcut {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  background: var(--smkt-row-soft);
  border: 1px solid var(--smkt-border-soft);
  border-radius: 10px;
  font-size: 13px;
  color: var(--smkt-text-mute);
}
.smkt-shortcut kbd {
  font-family: 'Courier New', monospace;
  font-weight: 800;
  background: var(--smkt-kbd-bg);
  color: #4ade80;
  padding: 4px 8px;
  border-radius: 6px;
  border: 1px solid rgba(74, 222, 128, 0.3);
  min-width: 36px;
  text-align: center;
}
.smkt-parked-cta {
  margin-top: 28px;
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 20px;
  background: rgba(245, 158, 11, 0.15);
  border: 1px solid rgba(245, 158, 11, 0.4);
  border-radius: 10px;
  color: #fbbf24;
}

/* Cart table — theme-aware */
.smkt-cart-wrap {
  flex: 1;
  overflow-y: auto;
  background: var(--smkt-panel);
  color: var(--smkt-text);
}
.smkt-cart-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 14px;
}
.smkt-cart-table thead th {
  position: sticky;
  top: 0;
  background: var(--smkt-cart-header);
  text-align: left;
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  padding: 12px 16px;
  color: var(--smkt-text-mute);
  border-bottom: 2px solid var(--smkt-border);
  z-index: 1;
}
.smkt-cart-table tbody td {
  padding: 12px 16px;
  border-bottom: 1px dashed var(--smkt-divider-dash);
  vertical-align: middle;
  color: var(--smkt-text);
}
.smkt-cart-table tbody td.text-medium-emphasis { color: var(--smkt-text-soft) !important; }
.smkt-cart-table tbody .text-caption { color: var(--smkt-text-mute) !important; }
.smkt-cart-table tbody tr { cursor: pointer; transition: background 0.1s; }
.smkt-cart-table tbody tr:hover { background: var(--smkt-row-hover); }
.smkt-cart-table tbody tr.is-selected { background: rgba(59, 130, 246, 0.12); }
.smkt-cart-table tbody tr.just-added { animation: row-flash 0.6s ease-out; }
@keyframes row-flash {
  0% { background: rgba(74, 222, 128, 0.35); }
  100% { background: transparent; }
}
.num-col { width: 56px; text-align: center; color: var(--smkt-text-faint); font-weight: 700; }
.act-col { width: 48px; text-align: right; }
.smkt-qty-stepper {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  background: var(--smkt-input-bg);
  border-radius: 8px;
  padding: 3px;
  border: 1px solid var(--smkt-border);
}
.smkt-qty-btn {
  width: 28px; height: 28px;
  display: flex; align-items: center; justify-content: center;
  background: var(--smkt-row-soft);
  border: 1px solid var(--smkt-border);
  border-radius: 6px;
  cursor: pointer;
  color: var(--smkt-text-soft);
}
.smkt-qty-btn:hover:not(:disabled) { background: var(--smkt-row-soft-hover); }
.smkt-qty-btn:disabled { opacity: 0.4; cursor: not-allowed; }
.smkt-qty-plus { background: #3b82f6; border-color: #2563eb; color: white; }
.smkt-qty-plus:hover:not(:disabled) { background: #2563eb; }
.smkt-qty-input {
  width: 48px;
  text-align: center;
  font-weight: 700;
  font-size: 14px;
  font-variant-numeric: tabular-nums;
  background: transparent;
  border: none;
  outline: none;
  color: var(--smkt-text);
  -moz-appearance: textfield;
}
.smkt-qty-input::-webkit-outer-spin-button,
.smkt-qty-input::-webkit-inner-spin-button { -webkit-appearance: none; margin: 0; }
.smkt-qty-input:focus { background: rgba(59, 130, 246, 0.15); border-radius: 4px; }

/* Stage footer (totals) */
.smkt-stage-footer {
  flex-shrink: 0;
  background: var(--smkt-stage-footer);
  padding: 14px 24px;
  border-top: 2px solid var(--smkt-border);
}
.smkt-totals-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr) 1.4fr;
  gap: 16px;
  align-items: center;
}
.smkt-tot-label {
  font-size: 10px;
  letter-spacing: 0.14em;
  color: var(--smkt-text-mute);
  text-transform: uppercase;
}
.smkt-tot-val {
  font-size: 16px;
  font-weight: 700;
  color: var(--smkt-text);
  font-variant-numeric: tabular-nums;
  margin-top: 2px;
}
.smkt-grand {
  text-align: right;
  border-left: 1px dashed var(--smkt-border);
  padding-left: 16px;
}
.smkt-grand-val {
  font-size: 32px;
  font-weight: 800;
  color: #4ade80;
  font-variant-numeric: tabular-nums;
  letter-spacing: 0.01em;
  margin-top: 2px;
}

/* ===== SIDE (right) ===== */
.smkt-side {
  display: flex;
  flex-direction: column;
  background: var(--smkt-panel);
  border: 1px solid var(--smkt-border-soft);
  border-radius: 14px;
  padding: 14px;
  overflow-y: auto;
  gap: 14px;
  min-width: 0;
}
.smkt-side-title {
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.16em;
  color: var(--smkt-text-faint);
  text-transform: uppercase;
  margin-bottom: 8px;
  padding-left: 4px;
}

.smkt-pay-row {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 12px;
  margin-bottom: 6px;
  background: var(--smkt-row-soft);
  border: 1px solid var(--smkt-border-soft);
  border-radius: 10px;
  cursor: pointer;
  transition: all 0.15s;
  color: var(--smkt-text);
  font-family: inherit;
  text-align: left;
}
.smkt-pay-row:hover {
  background: rgba(59, 130, 246, 0.1);
  border-color: rgba(59, 130, 246, 0.3);
}
.smkt-pay-row.is-active {
  background: linear-gradient(135deg, rgba(34, 197, 94, 0.18), rgba(34, 197, 94, 0.06));
  border-color: #22c55e;
  box-shadow: 0 4px 14px rgba(34, 197, 94, 0.15);
}
.smkt-pay-label { font-size: 14px; font-weight: 700; color: var(--smkt-text); }
.smkt-pay-hint { font-size: 11px; color: var(--smkt-text-mute); }

/* Quick discount */
.smkt-disc-grid {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 4px;
}
.smkt-disc-btn {
  padding: 8px 4px;
  font-size: 12px;
  font-weight: 700;
  background: var(--smkt-row-soft);
  border: 1px solid var(--smkt-border);
  border-radius: 8px;
  color: var(--smkt-text-soft);
  cursor: pointer;
  transition: all 0.15s;
  font-family: inherit;
}
.smkt-disc-btn:hover { background: var(--smkt-row-soft-hover); }
.smkt-disc-btn.is-active {
  background: #f59e0b;
  border-color: #d97706;
  color: white;
}

/* Actions */
.smkt-actions {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 6px;
}
.smkt-act-btn {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
  padding: 10px 4px;
  font-size: 11px;
  font-weight: 600;
  background: var(--smkt-row-soft);
  border: 1px solid var(--smkt-border);
  border-radius: 10px;
  color: var(--smkt-text-soft);
  cursor: pointer;
  transition: all 0.15s;
  font-family: inherit;
}
.smkt-act-btn:hover:not(:disabled) {
  background: var(--smkt-row-soft-hover);
  transform: translateY(-1px);
}
.smkt-act-btn:disabled { opacity: 0.35; cursor: not-allowed; }
.smkt-act-badge {
  position: absolute;
  top: 4px;
  right: 4px;
  background: #f59e0b;
  color: white;
  font-size: 10px;
  padding: 1px 6px;
  border-radius: 8px;
}

/* Pay button */
.smkt-pay-btn {
  margin-top: auto;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  padding: 18px;
  background: linear-gradient(135deg, #16a34a, #15803d);
  border: none;
  border-radius: 12px;
  color: white;
  cursor: pointer;
  transition: all 0.15s;
  font-family: inherit;
  box-shadow: 0 8px 24px rgba(22, 163, 74, 0.3);
}
.smkt-pay-btn:hover:not(:disabled) {
  background: linear-gradient(135deg, #15803d, #166534);
  transform: translateY(-2px);
  box-shadow: 0 12px 28px rgba(22, 163, 74, 0.45);
}
.smkt-pay-btn:disabled {
  background: #475569;
  cursor: not-allowed;
  box-shadow: none;
}
.smkt-pay-btn-content {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
}
.smkt-pay-btn-label {
  font-size: 11px;
  letter-spacing: 0.16em;
  font-weight: 700;
  opacity: 0.85;
}
.smkt-pay-btn-amount {
  font-size: 22px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  line-height: 1;
}

/* ===== TENDER MODAL ===== */
.smkt-tender-card { overflow: hidden; }
.smkt-tender-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 18px 24px;
  background: linear-gradient(135deg, #1e293b, #334155);
  color: white;
}
.smkt-tender-due {
  font-size: 36px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  margin-top: 2px;
}
.smkt-tender-body {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24px;
  padding: 20px 24px;
  background: #f8fafc;
}
@media (max-width: 700px) {
  .smkt-tender-body { grid-template-columns: 1fr; }
}
.smkt-quick-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 6px;
}
.smkt-quick-btn {
  padding: 14px;
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  font-size: 13px;
  font-weight: 700;
  color: #1e293b;
  cursor: pointer;
  font-variant-numeric: tabular-nums;
  transition: all 0.15s;
}
.smkt-quick-btn:hover { background: #f1f5f9; border-color: #94a3b8; }
.smkt-quick-btn.smkt-exact {
  background: #eab308;
  color: white;
  border-color: #ca8a04;
}
.smkt-tendered-display {
  background: var(--smkt-tendered-bg);
  color: #4ade80;
  font-family: 'Courier New', monospace;
  font-size: 28px;
  font-weight: 800;
  text-align: right;
  padding: 14px 18px;
  border-radius: 10px;
  margin-bottom: 10px;
  font-variant-numeric: tabular-nums;
}
.smkt-numpad {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 6px;
}
.smkt-numkey {
  padding: 16px;
  font-size: 20px;
  font-weight: 700;
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  cursor: pointer;
  color: #1e293b;
  transition: all 0.1s;
}
.smkt-numkey:hover { background: #f1f5f9; }
.smkt-numkey:active { transform: scale(0.97); background: #e2e8f0; }
.smkt-numkey-fn { background: #f1f5f9; color: #64748b; }
.smkt-change-box {
  margin-top: 12px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 14px 18px;
  border-radius: 10px;
  color: white;
}
.smkt-change-box.is-ok { background: linear-gradient(135deg, #16a34a, #15803d); }
.smkt-change-box.is-short { background: linear-gradient(135deg, #dc2626, #991b1b); }
.smkt-change-val {
  font-size: 28px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
}
.smkt-tender-footer {
  display: flex;
  align-items: center;
  padding: 14px 24px;
  background: white;
  border-top: 1px solid rgba(0, 0, 0, 0.06);
}

/* ===== PARKED & RECEIPT ===== */
.smkt-parked-row { border: 1px solid rgba(0, 0, 0, 0.06); border-radius: 8px; }
.smkt-receipt { font-family: 'Courier New', monospace; }
.smkt-receipt-items { max-height: 240px; overflow-y: auto; }
</style>

<!-- Light theme overrides for the supermarket POS shell.
     Unscoped so it can target the global Vuetify theme class. -->
<style>
.v-theme--light .smkt-shell {
  --smkt-bg: linear-gradient(180deg, #f1f5f9 0%, #e2e8f0 100%);
  --smkt-panel: rgba(255, 255, 255, 0.75);
  --smkt-panel-strong: rgba(255, 255, 255, 0.92);
  --smkt-stage-header: linear-gradient(135deg, #ffffff, #f1f5f9);
  --smkt-stage-footer: linear-gradient(135deg, #f8fafc, #e2e8f0);
  --smkt-cart-header: #f1f5f9;
  --smkt-input-bg: #ffffff;
  --smkt-border: rgba(15, 23, 42, 0.10);
  --smkt-border-soft: rgba(15, 23, 42, 0.06);
  --smkt-divider-dash: rgba(15, 23, 42, 0.08);
  --smkt-row-hover: rgba(15, 23, 42, 0.04);
  --smkt-row-soft: rgba(15, 23, 42, 0.03);
  --smkt-row-soft-hover: rgba(15, 23, 42, 0.07);
  --smkt-text: #0f172a;
  --smkt-text-soft: #334155;
  --smkt-text-mute: #64748b;
  --smkt-text-faint: #94a3b8;
  --smkt-kbd-bg: #1e293b;
  --smkt-tendered-bg: #0f172a;
}
</style>
