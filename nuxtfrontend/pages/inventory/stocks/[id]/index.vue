<template>
  <v-container fluid class="pa-3 pa-md-5 sid-shell">
    <!-- ═══════════════ HERO ═══════════════
         Tinted with the tenant palette from /ims/organization/branding —
         see `heroTheme` in the script. Mirrors the inventory list header so
         moving between the list and an item feels continuous. -->
    <div class="sid-hero mb-4" :style="heroTheme">
      <span class="sid-hero-glow" />
      <span class="sid-hero-glow sid-hero-glow-2" />

      <div class="d-flex flex-wrap align-center justify-space-between ga-3">
        <div class="d-flex align-center" style="gap:16px">
          <div class="sid-hero-icon">
            <v-icon size="30">mdi-pill</v-icon>
          </div>
          <div style="min-width:0">
            <div class="sid-eyebrow">
              <v-icon size="11">mdi-circle</v-icon>
              STOCK ITEM
            </div>
            <h1 class="sid-title">{{ stock.medication_name || 'Stock item' }}</h1>
            <div class="sid-hero-chips">
              <span class="sid-hero-chip sid-hero-chip-health" :class="`sid-health-${stockHealth.key}`">
                <v-icon size="13">{{ stockHealth.icon }}</v-icon>
                {{ stockHealth.label }}
              </span>
              <span v-if="stock.medication_id" class="sid-hero-chip">{{ stock.medication_id }}</span>
              <span v-if="stock.category_name" class="sid-hero-chip">{{ stock.category_name }}</span>
              <span v-if="stock.classification_name" class="sid-hero-chip">{{ stock.classification_name }}</span>
              <span v-if="stock.branch_name" class="sid-hero-chip">{{ stock.branch_name }}</span>
              <span v-if="stock.unit_name" class="sid-hero-chip">{{ stock.unit_name }}</span>
              <span v-if="stock.barcode" class="sid-hero-chip">#{{ stock.barcode }}</span>
              <span v-if="stock.prescription_required && stock.prescription_required !== 'none'" class="sid-hero-chip">
                Rx {{ stock.prescription_required }}
              </span>
            </div>
          </div>
        </div>

        <div class="d-flex flex-wrap align-center ga-2">
          <v-btn
            icon="mdi-refresh"
            variant="text"
            size="small"
            class="sid-hero-iconbtn"
            title="Refresh"
            :loading="loading"
            @click="load"
          />
          <v-btn
            variant="flat" elevation="0" rounded="lg" class="text-none sid-hero-btn-glass"
            prepend-icon="mdi-arrow-left" to="/inventory"
          >Back</v-btn>
          <v-btn
            variant="flat" elevation="0" rounded="lg" class="text-none sid-hero-btn-glass"
            prepend-icon="mdi-file-pdf-box" :loading="pdfLoading" @click="downloadPdf"
          >Report (PDF)</v-btn>
          <v-btn
            variant="flat" elevation="0" rounded="lg" class="text-none sid-hero-btn-strong"
            prepend-icon="mdi-pencil" :to="`/inventory/stocks/${id}/edit`"
          >Edit</v-btn>
        </div>
      </div>
    </div>

    <div v-if="loading" class="text-center py-12">
      <v-progress-circular indeterminate color="primary" size="40" />
    </div>

    <template v-else>
      <!-- ═══════════════ PERIOD BAR ═══════════════ -->
      <v-card flat rounded="xl" border class="pa-3 mb-3 sid-period">
        <div class="d-flex align-center flex-wrap ga-2">
          <div class="sid-period-icon">
            <v-icon size="18">mdi-calendar-range</v-icon>
          </div>
          <div class="mr-2">
            <div class="text-caption text-medium-emphasis" style="line-height:1.1">Reporting period</div>
            <div class="text-body-2 font-weight-bold">{{ periodLabel }}</div>
          </div>
          <v-select
            v-model="datePreset" :items="dateOptions" item-title="label" item-value="value"
            variant="solo-filled" density="comfortable" hide-details flat rounded="lg"
            bg-color="surface" style="max-width: 180px"
            @update:model-value="onPeriodChange"
          />
          <template v-if="datePreset === 'custom'">
            <v-text-field
              v-model="dateFrom" type="date" label="From"
              variant="solo-filled" density="comfortable" hide-details flat rounded="lg"
              bg-color="surface" style="max-width: 165px"
              @update:model-value="onPeriodChange"
            />
            <v-text-field
              v-model="dateTo" type="date" label="To"
              variant="solo-filled" density="comfortable" hide-details flat rounded="lg"
              bg-color="surface" style="max-width: 165px"
              @update:model-value="onPeriodChange"
            />
          </template>
          <v-spacer />
          <div class="text-caption text-medium-emphasis d-none d-lg-block">
            Opening stock, sales stats and analytics follow this period
          </div>
        </div>
      </v-card>

      <!-- ═══════════════ ACCOUNT STOCK KPIs ═══════════════ -->
      <v-row dense class="mb-4">
        <v-col cols="6" md="2" v-for="k in accountCards" :key="k.label">
          <div class="sid-kpi h-100" :class="`sid-kpi-${k.key}`">
            <div class="d-flex align-center" style="gap:10px">
              <div class="sid-kpi-icon">
                <v-icon size="18">{{ k.icon }}</v-icon>
              </div>
              <div style="min-width:0">
                <div class="sid-kpi-label">{{ k.label }}</div>
                <div class="sid-kpi-value">{{ k.value.toLocaleString?.() ?? k.value }}</div>
                <div v-if="k.sub" class="sid-kpi-sub">{{ k.sub }}</div>
              </div>
            </div>
          </div>
        </v-col>
      </v-row>

      <!-- ═══════════════ TABS ═══════════════ -->
      <v-card flat rounded="xl" border class="sid-tabcard">
        <v-tabs v-model="tab" color="primary" density="comfortable" class="sid-tabs">
          <v-tab value="overview" class="text-none"><v-icon start size="18">mdi-view-dashboard-outline</v-icon>Overview</v-tab>
          <v-tab value="batches" class="text-none"><v-icon start size="18">mdi-package-variant-closed</v-icon>Batches</v-tab>
          <v-tab value="transactions" class="text-none"><v-icon start size="18">mdi-swap-vertical</v-icon>Transactions</v-tab>
          <v-tab value="history" class="text-none"><v-icon start size="18">mdi-history</v-icon>History</v-tab>
          <v-tab value="analytics" class="text-none"><v-icon start size="18">mdi-chart-line</v-icon>Analytics</v-tab>
        </v-tabs>
        <v-divider />

        <v-tabs-window v-model="tab" class="pa-4 pa-md-5 sid-panels">
          <!-- ── OVERVIEW ─────────────────────────────────────────────── -->
          <v-tabs-window-item value="overview">
            <!-- Item Details -->
            <v-card flat rounded="lg" border class="pa-4 mb-4">
              <div class="d-flex align-center mb-3">
                <v-icon color="primary" class="mr-2">mdi-tag-multiple-outline</v-icon>
                <div class="text-subtitle-1 font-weight-bold">Item Details</div>
              </div>
              <v-row dense>
                <v-col cols="6" md="3">
                  <div class="detail-label">Medication Name</div>
                  <div class="detail-value font-weight-medium">{{ stock.medication_name || '—' }}</div>
                </v-col>
                <v-col cols="6" md="3">
                  <div class="detail-label">Brand / Trade Name</div>
                  <div class="detail-value">{{ stock.brand_name || '—' }}</div>
                </v-col>
                <v-col cols="6" md="3">
                  <div class="detail-label">Generic Name</div>
                  <div class="detail-value">{{ stock.generic_name || '—' }}</div>
                </v-col>
                <v-col cols="6" md="3">
                  <div class="detail-label">Strength</div>
                  <div class="detail-value">{{ stock.strength || '—' }}</div>
                </v-col>
                <v-col cols="6" md="3">
                  <div class="detail-label">Dosage Form</div>
                  <div class="detail-value text-capitalize">{{ stock.dosage_form || '—' }}</div>
                </v-col>
                <v-col cols="6" md="3">
                  <div class="detail-label">Barcode / SKU</div>
                  <div class="detail-value">{{ stock.barcode || '—' }}</div>
                </v-col>
                <v-col cols="6" md="3">
                  <div class="detail-label">Category</div>
                  <div class="detail-value">{{ stock.category_name || '—' }}</div>
                </v-col>
                <v-col cols="6" md="3">
                  <div class="detail-label">Classification</div>
                  <div class="detail-value">{{ stock.classification_name || '—' }}</div>
                </v-col>
                <v-col cols="6" md="3">
                  <div class="detail-label">Unit of Measure</div>
                  <div class="detail-value">{{ stock.unit_name || '—' }}</div>
                </v-col>
                <v-col cols="6" md="3">
                  <div class="detail-label">Items per Unit</div>
                  <div class="detail-value">{{ stock.items_per_unit || 0 }}</div>
                </v-col>
                <v-col cols="6" md="3">
                  <div class="detail-label">Warehouse / Branch</div>
                  <div class="detail-value">{{ stock.branch_name || '—' }}</div>
                </v-col>
                <v-col cols="6" md="3">
                  <div class="detail-label">Location in Store</div>
                  <div class="detail-value">{{ stock.location_in_store || '—' }}</div>
                </v-col>
                <v-col cols="6" md="3">
                  <div class="detail-label">Prescription Required</div>
                  <div class="detail-value text-capitalize">{{ stock.prescription_required || 'none' }}</div>
                </v-col>
                <v-col cols="6" md="3">
                  <div class="detail-label">Status</div>
                  <div class="detail-value">
                    <v-chip size="small" :color="stock.is_active ? 'success' : 'grey'" variant="tonal">
                      <v-icon start size="14">{{ stock.is_active ? 'mdi-check-circle' : 'mdi-pause-circle' }}</v-icon>
                      {{ stock.is_active ? 'Active' : 'Inactive' }}
                    </v-chip>
                  </div>
                </v-col>
                <v-col cols="6" md="3">
                  <div class="detail-label">Added</div>
                  <div class="detail-value">{{ formatDate(stock.created_at) }}</div>
                </v-col>
                <v-col cols="6" md="3">
                  <div class="detail-label">Last Updated</div>
                  <div class="detail-value">{{ formatDate(stock.updated_at) }}</div>
                </v-col>
              </v-row>
            </v-card>
            <v-row dense>
              <!-- Purchase info -->
              <v-col cols="12" md="6">
                <v-card flat rounded="lg" border class="pa-4 h-100">
                  <div class="d-flex align-center mb-3">
                    <v-icon color="primary" class="mr-2">mdi-cart-outline</v-icon>
                    <div class="text-subtitle-1 font-weight-bold">Purchase info</div>
                    <v-spacer />
                    <v-chip size="x-small" variant="tonal" color="primary">
                      {{ purchase.recent.length }} lines
                    </v-chip>
                  </div>
                  <div class="d-flex flex-wrap ga-2 mb-3">
                    <v-chip size="small" variant="tonal" prepend-icon="mdi-cash">Cost {{ formatMoney(stock.cost_price) }}</v-chip>
                    <v-chip size="small" variant="tonal" color="success" prepend-icon="mdi-cash-plus">Sell {{ formatMoney(stock.selling_price) }}</v-chip>
                    <v-chip v-if="purchase.last_purchase" size="small" variant="tonal" color="info" prepend-icon="mdi-truck-delivery">
                      Last: {{ purchase.last_purchase.supplier || purchase.last_purchase.po_number }}
                    </v-chip>
                  </div>
                  <div class="text-overline text-medium-emphasis mb-1">Recent purchases</div>
                  <table v-if="purchase.recent.length" class="sid-mini-table">
                    <thead><tr><th>PO #</th><th>Date</th><th>Supplier</th><th class="text-right">Qty</th><th class="text-right">Unit cost</th></tr></thead>
                    <tbody>
                      <tr v-for="p in purchase.recent.slice(0, 8)" :key="p.po_number + p.date">
                        <td class="font-weight-medium text-primary">{{ p.po_number }}</td>
                        <td>{{ formatDate(p.date) }}</td>
                        <td>{{ p.supplier || '—' }}</td>
                        <td class="text-right">{{ p.qty }}</td>
                        <td class="text-right">{{ formatMoney(p.unit_cost) }}</td>
                      </tr>
                    </tbody>
                  </table>
                  <div v-else class="text-body-2 text-medium-emphasis">No purchase orders recorded for this item yet.</div>
                </v-card>
              </v-col>
              <!-- Sales info -->
              <v-col cols="12" md="6">
                <v-card flat rounded="lg" border class="pa-4 h-100">
                  <div class="d-flex align-center mb-3">
                    <v-icon color="success" class="mr-2">mdi-cash-register</v-icon>
                    <div class="text-subtitle-1 font-weight-bold">Sales info</div>
                    <v-spacer />
                    <v-chip size="x-small" variant="tonal" color="success">
                      Last {{ periodDays }}d
                    </v-chip>
                  </div>
                  <div class="d-flex flex-wrap ga-2 mb-3">
                    <v-chip size="small" variant="tonal" color="success" prepend-icon="mdi-pill-multiple">
                      {{ salesInfo.units_sold_period }} units sold
                    </v-chip>
                    <v-chip size="small" variant="tonal" color="info" prepend-icon="mdi-cash-multiple">
                      {{ formatMoney(salesInfo.revenue_period) }} revenue
                    </v-chip>
                    <v-chip v-if="salesInfo.last_sale_at" size="small" variant="tonal" prepend-icon="mdi-clock-outline">
                      Last sale {{ relativeTime(salesInfo.last_sale_at) }}
                    </v-chip>
                  </div>
                  <div class="text-overline text-medium-emphasis mb-1">Recent sales</div>
                  <table v-if="salesInfo.recent.length" class="sid-mini-table">
                    <thead><tr><th>Receipt</th><th>Date</th><th class="text-right">Qty</th><th class="text-right">Unit price</th><th class="text-right">Total</th></tr></thead>
                    <tbody>
                      <tr v-for="s in salesInfo.recent.slice(0, 8)" :key="s.transaction_number + s.date">
                        <td class="font-weight-medium text-primary">{{ s.transaction_number }}</td>
                        <td>{{ formatDate(s.date) }}</td>
                        <td class="text-right">{{ s.qty }}</td>
                        <td class="text-right">{{ formatMoney(s.unit_price) }}</td>
                        <td class="text-right font-weight-medium">{{ formatMoney(s.total) }}</td>
                      </tr>
                    </tbody>
                  </table>
                  <div v-else class="text-body-2 text-medium-emphasis">No sales recorded yet.</div>
                </v-card>
              </v-col>
            </v-row>
          </v-tabs-window-item>

          <!-- ── BATCHES ─────────────────────────────────────────────────── -->
          <v-tabs-window-item value="batches">
            <v-row dense class="mb-3">
              <v-col cols="6" md="3" v-for="bk in batchKpis" :key="bk.label">
                <v-card flat rounded="lg" border class="pa-3">
                  <div class="d-flex align-center" style="gap:10px">
                    <v-avatar :color="bk.color" variant="tonal" rounded="lg" size="38">
                      <v-icon size="19">{{ bk.icon }}</v-icon>
                    </v-avatar>
                    <div>
                      <div class="text-caption text-medium-emphasis text-uppercase">{{ bk.label }}</div>
                      <div class="text-h6 font-weight-bold">{{ bk.value }}</div>
                    </div>
                  </div>
                </v-card>
              </v-col>
            </v-row>

            <div class="text-subtitle-2 text-medium-emphasis mb-2">
              {{ batches.length }} batch{{ batches.length !== 1 ? 'es' : '' }} for this stock item
            </div>
            <div class="table-wrap">
              <table class="inv-table">
                <thead>
                  <tr>
                    <th class="row-num">#</th>
                    <th>Batch #</th>
                    <th>Received</th>
                    <th class="text-right">Received qty</th>
                    <th class="text-right">Remaining</th>
                    <th class="text-right">Cost/unit</th>
                    <th>Expiry</th>
                    <th>Status</th>
                    <th>Supplier</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="(b, i) in batches" :key="b.id">
                    <td class="row-num text-medium-emphasis">{{ i + 1 }}</td>
                    <td class="font-weight-medium">{{ b.batch_number || '—' }}</td>
                    <td>{{ formatDate(b.received_date) }}</td>
                    <td class="text-right">{{ b.quantity_received }}</td>
                    <td class="text-right" :class="b.quantity_remaining > 0 ? '' : 'text-disabled'">{{ b.quantity_remaining }}</td>
                    <td class="text-right">{{ formatMoney(b.cost_price_per_unit) }}</td>
                    <td>
                      <span :class="expiryClass(b)">{{ formatDate(b.expiry_date) }}</span>
                    </td>
                    <td>
                      <v-chip :color="batchStatus(b).color" size="x-small" variant="tonal">
                        <v-icon start size="12">{{ batchStatus(b).icon }}</v-icon>{{ batchStatus(b).label }}
                      </v-chip>
                    </td>
                    <td>{{ b.supplier_name || '—' }}</td>
                  </tr>
                  <tr v-if="!batches.length">
                    <td colspan="9" class="text-center text-medium-emphasis py-6">No batches recorded for this stock item.</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </v-tabs-window-item>

          <!-- ── TRANSACTIONS ──────────────────────────────────────────── -->
          <v-tabs-window-item value="transactions">
            <div class="text-subtitle-2 text-medium-emphasis mb-2">
              {{ movements.length }} stock movements · running balance
            </div>
            <div class="table-wrap">
              <table class="inv-table">
                <thead>
                  <tr>
                    <th class="row-num">#</th>
                    <th>When</th>
                    <th>Type</th>
                    <th>Detail</th>
                    <th>Reference</th>
                    <th class="text-right">Before</th>
                    <th class="text-right">Change</th>
                    <th class="text-right">After</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="(m, i) in movements" :key="i">
                    <td class="row-num text-medium-emphasis">{{ i + 1 }}</td>
                    <td>{{ formatDateTime(m.timestamp) }}</td>
                    <td>
                      <v-chip :color="movementMeta(m).color" size="x-small" variant="tonal">
                        <v-icon start size="12">{{ movementMeta(m).icon }}</v-icon>{{ movementMeta(m).label }}
                      </v-chip>
                    </td>
                    <td>{{ m.label }}</td>
                    <td class="text-caption text-medium-emphasis">{{ m.reference || '—' }}</td>
                    <td class="text-right text-medium-emphasis">{{ m.qty_before }}</td>
                    <td class="text-right font-weight-bold" :class="m.quantity_change > 0 ? 'text-success' : 'text-error'">
                      {{ m.quantity_change > 0 ? '+' : '' }}{{ m.quantity_change }}
                    </td>
                    <td class="text-right font-weight-medium">{{ m.qty_after }}</td>
                  </tr>
                  <tr v-if="!movements.length">
                    <td colspan="8" class="text-center text-medium-emphasis py-6">No stock movements recorded.</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </v-tabs-window-item>

          <!-- ── HISTORY ──────────────────────────────────────────────── -->
          <v-tabs-window-item value="history">
            <v-row dense>
              <v-col cols="12" md="7">
                <div class="text-subtitle-2 font-weight-bold mb-2">Batch history</div>
                <div class="table-wrap">
                  <table class="inv-table">
                    <thead>
                      <tr>
                        <th class="row-num">#</th>
                        <th>Batch #</th>
                        <th>Received</th>
                        <th class="text-right">Received qty</th>
                        <th class="text-right">Remaining</th>
                        <th class="text-right">Cost/unit</th>
                        <th>Expiry</th>
                        <th>Supplier</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr v-for="(b, i) in batches" :key="b.id">
                        <td class="row-num text-medium-emphasis">{{ i + 1 }}</td>
                        <td class="font-weight-medium">{{ b.batch_number || '—' }}</td>
                        <td>{{ formatDate(b.received_date) }}</td>
                        <td class="text-right">{{ b.quantity_received }}</td>
                        <td class="text-right" :class="b.quantity_remaining > 0 ? '' : 'text-disabled'">{{ b.quantity_remaining }}</td>
                        <td class="text-right">{{ formatMoney(b.cost_price_per_unit) }}</td>
                        <td>
                          <span :class="expiryClass(b)">{{ formatDate(b.expiry_date) }}</span>
                        </td>
                        <td>{{ b.supplier_name || '—' }}</td>
                      </tr>
                      <tr v-if="!batches.length">
                        <td colspan="8" class="text-center text-medium-emphasis py-6">No batches recorded.</td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </v-col>
              <v-col cols="12" md="5">
                <div class="text-subtitle-2 font-weight-bold mb-2">Purchase price history</div>
                <div v-if="priceHistory.length" class="d-flex flex-column ga-2">
                  <v-card v-for="(p, i) in priceHistory.slice().reverse()" :key="i" flat rounded="lg" border class="pa-3">
                    <div class="d-flex align-center justify-space-between">
                      <div>
                        <div class="text-caption text-medium-emphasis">{{ formatDate(p.date) || '—' }}</div>
                        <div class="text-body-2">{{ p.qty }} units @ <b>{{ formatMoney(p.unit_cost) }}</b></div>
                      </div>
                      <v-icon :color="trendIcon(p, i).color" size="20">{{ trendIcon(p, i).icon }}</v-icon>
                    </div>
                  </v-card>
                </div>
                <div v-else class="text-body-2 text-medium-emphasis">No purchase price history yet.</div>
              </v-col>
            </v-row>
          </v-tabs-window-item>

          <!-- ── ANALYTICS ─────────────────────────────────────────────── -->
          <v-tabs-window-item value="analytics">
            <v-row dense>
              <v-col cols="12" md="6">
                <v-card flat rounded="lg" border class="pa-4 h-100">
                  <div class="text-subtitle-2 font-weight-bold mb-3">Units sold per day</div>
                  <LineChart
                    :series="[{ label: 'Units sold', color: '#16a34a', values: trend.map(t => t.sold) }]"
                    :labels="trend.map(t => t.date.slice(5))"
                    :height="220"
                  />
                </v-card>
              </v-col>
              <v-col cols="12" md="6">
                <v-card flat rounded="lg" border class="pa-4 h-100">
                  <div class="text-subtitle-2 font-weight-bold mb-3">Stock received per day</div>
                  <BarChart
                    :values="trend.map(t => t.received)"
                    :labels="trend.map(t => t.date.slice(5))"
                    color="#0d9488"
                    :height="220"
                  />
                </v-card>
              </v-col>
              <v-col cols="12" md="3" v-for="a in analyticsCards" :key="a.label">
                <v-card flat rounded="lg" border class="pa-3">
                  <div class="text-caption text-medium-emphasis text-uppercase">{{ a.label }}</div>
                  <div class="text-h6 font-weight-bold">{{ a.value }}</div>
                  <div v-if="a.sub" class="text-caption text-medium-emphasis">{{ a.sub }}</div>
                </v-card>
              </v-col>
            </v-row>
          </v-tabs-window-item>
        </v-tabs-window>
      </v-card>
    </template>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
import { useBranding } from '~/composables/useBranding'

const route = useRoute()
const { $api } = useNuxtApp()

// Tenant palette configured at /ims/organization/branding. Exposed to the hero
// through custom properties so the stylesheet stays declarative. The third
// gradient stop is the accent mixed toward the primary — a raw accent is often
// near-white and would leave the buttons white-on-pale.
const brand = useBranding()
const heroTheme = computed(() => ({
  '--hero-deep': brand.secondary.value,
  '--hero-main': brand.primary.value,
  '--hero-accent': brand.gradientStops.value[2],
  '--hero-ink': brand.ink.value,
  '--hero-glow': brand.tint('primary', 0.3),
  '--hero-glow-2': brand.tint('accent', 0.2),
  '--hero-shadow': brand.shadow.value
}))

const id = computed(() => route.params.id)
const loading = ref(true)
const pdfLoading = ref(false)
const tab = ref('overview')
const datePreset = ref('30')
const dateFrom = ref(null)
const dateTo = ref(null)
const snack = reactive({ show: false, color: 'success', text: '' })

const dateOptions = [
  { label: 'Last 7 days', value: '7' },
  { label: 'Last 30 days', value: '30' },
  { label: 'Last 90 days', value: '90' },
  { label: 'Last 365 days', value: '365' },
  { label: 'Custom range', value: 'custom' },
]

const periodDays = computed(() => {
  if (datePreset.value === 'custom') {
    const from = dateFrom.value ? new Date(dateFrom.value) : null
    const to = dateTo.value ? new Date(dateTo.value) : null
    if (from && to) return Math.max(1, Math.round((to - from) / 86400000) + 1)
    return 30
  }
  return Number(datePreset.value) || 30
})

function onPeriodChange() {
  if (datePreset.value === 'custom' && !(dateFrom.value && dateTo.value)) return
  load()
}

const stock = ref({})
const account = ref({ on_hand: 0, committed: 0, available_for_sale: 0, reorder_level: 0, low_stock: false })
const openingStock = ref(0)
const period = ref({ received: 0, sold: 0, returned: 0, adjusted: 0, transferred_out: 0, units_sold: 0, sales_revenue: 0 })
const purchase = ref({ current_cost: 0, recent: [], last_purchase: null, price_history: [] })
const salesInfo = ref({ units_sold_period: 0, revenue_period: 0, last_sale_at: null, recent: [] })
const movements = ref([])
const batches = ref([])
const trend = ref([])

const accountCards = computed(() => [
  { key: 'opening', label: 'Opening stock', icon: 'mdi-package-up', color: 'indigo',
    value: openingStock.value, sub: `as of ${formatDate(periodStart.value)}` },
  { key: 'onhand', label: 'Stock on hand', icon: 'mdi-cube-outline', color: 'primary',
    value: account.value.on_hand, sub: stock.value.unit_abbreviation || '' },
  { key: 'committed', label: 'Committed stock', icon: 'mdi-lock-outline', color: 'orange',
    value: account.value.committed, sub: 'reserved by SOs' },
  { key: 'available', label: 'Available for sale', icon: 'mdi-check-circle-outline', color: 'success',
    value: account.value.available_for_sale, sub: 'on hand − committed' },
  { key: 'sold', label: `Sold (${periodDays.value}d)`, icon: 'mdi-pill-multiple', color: 'teal',
    value: period.value.sold, sub: formatMoney(period.value.sales_revenue) },
  { key: 'reorder', label: 'Reorder level', icon: 'mdi-bell-outline', color: account.value.low_stock ? 'error' : 'grey',
    value: account.value.reorder_level, sub: account.value.low_stock ? 'Low — reorder now' : 'Healthy' },
])

const periodStart = ref('')
const periodEnd = ref('')

// Single at-a-glance signal for the hero: is this item safe to sell from?
// Distinct from the "Reorder level" KPI card, which reports the threshold.
const stockHealth = computed(() => {
  const on = Number(account.value.on_hand || 0)
  const reorder = Number(account.value.reorder_level || 0)
  if (on <= 0) return { key: 'out', label: 'Out of stock', icon: 'mdi-close-circle' }
  if (reorder > 0 && on <= reorder) return { key: 'low', label: 'Low stock', icon: 'mdi-alert' }
  return { key: 'ok', label: 'In stock', icon: 'mdi-check-circle' }
})

const periodLabel = computed(() => {
  const fmt = d => new Date(d).toLocaleDateString('en-KE', { day: 'numeric', month: 'short', year: 'numeric' })
  if (datePreset.value === 'custom' && periodStart.value && periodEnd.value) {
    return `${fmt(periodStart.value)} → ${fmt(periodEnd.value)}`
  }
  if (periodStart.value && periodEnd.value) {
    return `${fmt(periodStart.value)} → ${fmt(periodEnd.value)}`
  }
  return `Last ${periodDays.value} days`
})

const priceHistory = computed(() => purchase.value.price_history || [])

const analyticsCards = computed(() => {
  const days = trend.value.length || 1
  const totalSold = trend.value.reduce((s, t) => s + t.sold, 0)
  const totalReceived = trend.value.reduce((s, t) => s + t.received, 0)
  const best = trend.value.reduce((b, t) => (t.sold > b.sold ? t : b), { sold: 0, date: '—' })
  return [
    { label: 'Avg daily sales', value: (totalSold / days).toFixed(1), sub: 'units / day' },
    { label: 'Total sold', value: totalSold, sub: `in ${periodDays.value} days` },
    { label: 'Total received', value: totalReceived, sub: `${periodDays.value}-day window` },
    { label: 'Best sales day', value: `${best.sold}`, sub: best.date !== '—' ? formatDate(best.date) : 'No sales' },
  ]
})

const MOVEMENT_META = {
  receipt: { label: 'Received', color: 'success', icon: 'mdi-arrow-down-bold' },
  sale: { label: 'Sale', color: 'error', icon: 'mdi-arrow-up-bold' },
  return: { label: 'Return', color: 'info', icon: 'mdi-keyboard-return' },
  adjustment: { label: 'Adjustment', color: 'warning', icon: 'mdi-tune' },
  transfer_out: { label: 'Transfer out', color: 'purple', icon: 'mdi-swap-horizontal' },
  so_fulfillment: { label: 'SO delivered', color: 'teal', icon: 'mdi-package-variant-closed-check' },
}
function movementMeta(m) { return MOVEMENT_META[m.type] || { label: m.type, color: 'grey', icon: 'mdi-swap-vertical' } }

function trendIcon(p, i) {
  if (i <= 0) return { icon: 'mdi-trending-neutral', color: 'grey' }
  const list = priceHistory.value.slice().reverse()
  const older = list[i - 1]
  if (!older || older.unit_cost === p.unit_cost) return { icon: 'mdi-trending-neutral', color: 'grey' }
  return p.unit_cost > older.unit_cost
    ? { icon: 'mdi-trending-up', color: 'error' }
    : { icon: 'mdi-trending-down', color: 'success' }
}

function expiryClass(b) {
  if (!b.expiry_date || b.is_expired) return 'text-error font-weight-medium'
  const days = (new Date(b.expiry_date) - new Date()) / 86400000
  if (days < 90) return 'text-warning'
  return ''
}

function batchStatus(b) {
  if (b.is_expired || (b.expiry_date && new Date(b.expiry_date) < new Date()))
    return { label: 'Expired', color: 'error', icon: 'mdi-alert-octagon' }
  if (b.quantity_remaining <= 0)
    return { label: 'Depleted', color: 'grey', icon: 'mdi-package-variant-remove' }
  if (b.expiry_date) {
    const days = (new Date(b.expiry_date) - new Date()) / 86400000
    if (days < 90)
      return { label: 'Expiring soon', color: 'warning', icon: 'mdi-clock-alert' }
  }
  return { label: 'Active', color: 'success', icon: 'mdi-check-circle' }
}

const batchKpis = computed(() => {
  const total = batches.value.length
  const active = batches.value.filter(b => (b.quantity_remaining || 0) > 0 && !b.is_expired).length
  const expiring = batches.value.filter(b => {
    if (!b.expiry_date || b.is_expired) return false
    const days = (new Date(b.expiry_date) - new Date()) / 86400000
    return days > 0 && days < 90
  }).length
  const expired = batches.value.filter(b => b.is_expired || (b.expiry_date && new Date(b.expiry_date) < new Date())).length
  return [
    { label: 'Total Batches', value: total, color: 'primary', icon: 'mdi-package-variant-closed' },
    { label: 'Active', value: active, color: 'success', icon: 'mdi-check-circle' },
    { label: 'Expiring Soon', value: expiring, color: 'warning', icon: 'mdi-clock-alert' },
    { label: 'Expired', value: expired, color: 'error', icon: 'mdi-alert-octagon' },
  ]
})

async function load() {
  loading.value = true
  try {
    const params = {}
    if (datePreset.value === 'custom') {
      if (dateFrom.value) params.date_from = dateFrom.value
      if (dateTo.value) params.date_to = dateTo.value
    } else {
      params.days = periodDays.value
    }
    const { data } = await $api.get(`/inventory/stocks/${id.value}/insights/`, { params })
    stock.value = data.stock || {}
    account.value = data.account || {}
    openingStock.value = data.opening_stock ?? 0
    periodStart.value = data.period_start || ''
    periodEnd.value = data.period_end || ''
    period.value = data.period || {}
    purchase.value = data.purchase_info || {}
    salesInfo.value = data.sales_info || {}
    movements.value = data.movements || []
    batches.value = (data.batches || []).slice().sort((a, b) => {
      const da = a.received_date || ''
      const db = b.received_date || ''
      return db.localeCompare(da)
    })
    trend.value = data.trend || []
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to load item details.'
    snack.color = 'error'
    snack.show = true
  } finally {
    loading.value = false
  }
}

function formatDate(d) {
  if (!d) return '—'
  const dt = new Date(d)
  return dt.toLocaleDateString('en-KE', { month: 'short', day: 'numeric', year: 'numeric' })
}

function formatDateTime(d) {
  if (!d) return '—'
  return new Date(d).toLocaleString('en-KE', {
    month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit',
  })
}

function relativeTime(d) {
  if (!d) return ''
  const diff = Date.now() - new Date(d).getTime()
  const mins = Math.floor(diff / 60000)
  if (mins < 60) return `${Math.max(1, mins)}m ago`
  const h = Math.floor(mins / 60)
  if (h < 24) return `${h}h ago`
  return `${Math.floor(h / 24)}d ago`
}

async function downloadPdf() {
  pdfLoading.value = true
  try {
    const res = await $api.get(`/inventory/stocks/${id.value}/report-pdf/`, {
      responseType: 'blob',
    })
    const blob = new Blob([res.data], { type: 'application/pdf' })
    const url = window.URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    const safe = (stock.value.medication_name || 'item').replace(/\s+/g, '_').replace(/\//g, '-')
    a.download = `stock_report_${safe}.pdf`
    document.body.appendChild(a)
    a.click()
    a.remove()
    window.URL.revokeObjectURL(url)
  } catch (e) {
    snack.text = 'Failed to generate PDF report.'
    snack.color = 'error'
    snack.show = true
  } finally {
    pdfLoading.value = false
  }
}

onMounted(() => {
  // Deep-linking straight to an item means nothing has fetched the tenant
  // palette yet (useBranding caches in shared state, so this is a no-op when
  // the inventory list already loaded it).
  brand.load()
  load()
})
</script>

<style scoped>
.sid-shell { max-width: 1500px; margin: 0 auto; }

/* ─────────────── Hero ───────────────
   Colours come from the tenant palette (see `heroTheme`); the var() fallbacks
   mirror BRAND_DEFAULTS in utils/branding.js. */
.sid-hero {
  position: relative;
  overflow: hidden;
  border-radius: 18px;
  padding: 20px 22px;
  color: #fff;
  background: linear-gradient(
    120deg,
    var(--hero-deep, #143ce1) 0%,
    var(--hero-main, #2f6dff) 52%,
    var(--hero-accent, #37d6ff) 100%
  );
  box-shadow: var(--hero-shadow, 0 14px 34px rgba(47, 109, 255, 0.24));
}
.sid-hero-glow {
  position: absolute;
  width: 340px;
  height: 340px;
  border-radius: 50%;
  right: -110px;
  top: -170px;
  background: radial-gradient(circle, var(--hero-glow, rgba(255, 255, 255, 0.28)), transparent 68%);
  pointer-events: none;
}
.sid-hero-glow-2 {
  right: auto;
  left: -140px;
  top: auto;
  bottom: -220px;
  width: 300px;
  height: 300px;
  background: radial-gradient(circle, var(--hero-glow-2, rgba(55, 214, 255, 0.24)), transparent 70%);
}
.sid-hero-icon {
  width: 56px;
  height: 56px;
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.16);
  border: 1px solid rgba(255, 255, 255, 0.28);
  backdrop-filter: blur(6px);
  flex-shrink: 0;
}
.sid-eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: rgba(255, 255, 255, 0.78);
}
.sid-title {
  font-size: 25px;
  line-height: 1.15;
  font-weight: 800;
  letter-spacing: -0.2px;
  margin: 2px 0 6px;
  overflow-wrap: anywhere;
}

/* Metadata chips sit *on* the gradient, so they get a translucent white
   treatment instead of Vuetify tonal colours (which wash out). */
.sid-hero-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.sid-hero-chip {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 2px 9px;
  border-radius: 999px;
  font-size: 11.5px;
  font-weight: 600;
  color: #fff;
  background: rgba(255, 255, 255, 0.16);
  border: 1px solid rgba(255, 255, 255, 0.3);
  backdrop-filter: blur(4px);
  white-space: nowrap;
}
.sid-hero-chip-health {
  font-weight: 700;
}
/* Health pill keeps a solid tint so it reads as a status, not a label. */
.sid-health-ok { background: rgba(34, 197, 94, 0.9); border-color: rgba(255, 255, 255, 0.5); }
.sid-health-low { background: rgba(245, 158, 11, 0.95); border-color: rgba(255, 255, 255, 0.5); }
.sid-health-out { background: rgba(239, 68, 68, 0.95); border-color: rgba(255, 255, 255, 0.5); }

.sid-hero-iconbtn { color: #fff !important; opacity: 0.9; }

/* Hero action buttons — three high-contrast tiers. A saturated brand gradient
   washes out tonal/primary fills, so each tier carries its own fill. */
.sid-hero-btn-strong {
  background: #ffffff !important;
  color: var(--hero-ink, #143ce1) !important;
  font-weight: 700 !important;
  letter-spacing: 0.1px;
  border: 1px solid rgba(255, 255, 255, 0.95) !important;
  box-shadow: 0 6px 18px rgba(6, 44, 40, 0.28) !important;
}
.sid-hero-btn-strong:hover {
  background: #ffffff !important;
  filter: brightness(0.94);
  box-shadow: 0 9px 24px rgba(6, 44, 40, 0.34) !important;
}
.sid-hero-btn-strong :deep(.v-icon) { color: var(--hero-ink, #143ce1) !important; opacity: 1 !important; }

.sid-hero-btn-glass {
  background: rgba(255, 255, 255, 0.16) !important;
  color: #ffffff !important;
  font-weight: 600 !important;
  border: 1px solid rgba(255, 255, 255, 0.34) !important;
  backdrop-filter: blur(6px);
}
.sid-hero-btn-glass:hover {
  background: rgba(255, 255, 255, 0.26) !important;
  border-color: rgba(255, 255, 255, 0.6) !important;
}
.sid-hero-btn-glass :deep(.v-icon) { color: #ffffff !important; opacity: 1 !important; }

/* ─────────────── Period bar ─────────────── */
.sid-period-icon {
  width: 34px;
  height: 34px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.12);
}

/* ─────────────── KPI cards ───────────────
   Tone is carried by `color` so the top accent bar and icon chip can both use
   currentColor / a tint of it. */
.sid-kpi {
  position: relative;
  overflow: hidden;
  border-radius: 14px;
  padding: 12px 14px;
  border: 1px solid rgba(15, 23, 42, 0.07);
  background: rgb(var(--v-theme-surface));
  transition: transform 0.18s ease, box-shadow 0.18s ease;
}
.sid-kpi::after {
  content: '';
  position: absolute;
  inset: 0 0 auto 0;
  height: 3px;
  background: currentColor;
  opacity: 0.85;
}
.sid-kpi:hover {
  transform: translateY(-2px);
  box-shadow: 0 10px 24px rgba(15, 23, 42, 0.1);
}
.sid-kpi-icon {
  width: 36px;
  height: 36px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  color: currentColor;
  background: color-mix(in srgb, currentColor 14%, transparent);
}
.sid-kpi-label {
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.6px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.6);
  line-height: 1.3;
}
.sid-kpi-value {
  font-size: 19px;
  font-weight: 800;
  line-height: 1.2;
  letter-spacing: -0.3px;
}
.sid-kpi-sub {
  font-size: 11px;
  color: rgba(var(--v-theme-on-surface), 0.6);
  line-height: 1.3;
}

.sid-kpi-opening { color: #6366f1; }
.sid-kpi-onhand { color: #0d9488; }
.sid-kpi-committed { color: #f59e0b; }
.sid-kpi-available { color: #16a34a; }
.sid-kpi-sold { color: #0ea5e9; }
.sid-kpi-reorder { color: #dc2626; }

/* ─────────────── Tab shell ─────────────── */
.sid-tabcard { overflow: hidden; }
.sid-tabs :deep(.v-tab) { font-weight: 600; }

/* Inner content cards get one consistent treatment instead of the default
   heavy outlined look, so the tab content reads as panels on a page. */
.sid-panels :deep(.v-card) {
  border-radius: 14px !important;
  border-color: rgba(15, 23, 42, 0.08) !important;
  transition: box-shadow 0.18s ease;
}
.sid-panels :deep(.v-card:hover) { box-shadow: 0 6px 18px rgba(15, 23, 42, 0.06); }

/* ─────────────── Tables ─────────────── */
.table-wrap {
  overflow-x: auto;
  border-radius: 12px;
  border: 1px solid rgba(15, 23, 42, 0.07);
}
.inv-table { width: 100%; border-collapse: separate; border-spacing: 0; font-size: 13.5px; }
.inv-table th {
  position: sticky;
  top: 0;
  z-index: 1;
  text-align: left;
  padding: 10px;
  white-space: nowrap;
  background: rgb(var(--v-theme-surface));
  border-bottom: 2px solid rgba(var(--v-border-color), var(--v-border-opacity));
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: rgba(var(--v-theme-on-surface), 0.6);
}
.inv-table td {
  padding: 9px 10px;
  border-bottom: 1px solid rgba(var(--v-border-color), 0.35);
  white-space: nowrap;
}
.inv-table tbody tr:last-child td { border-bottom: none; }
.inv-table tbody tr { transition: background 0.14s ease; }
.inv-table tbody tr:hover { background: rgba(var(--v-theme-primary), 0.045); }
.row-num { width: 44px; color: rgba(var(--v-theme-on-surface), 0.45); text-align: right; }

.sid-mini-table { width: 100%; border-collapse: collapse; font-size: 13px; }
.sid-mini-table th {
  text-align: left;
  padding: 6px 8px;
  font-size: 10.5px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.4px;
  color: rgba(var(--v-theme-on-surface), 0.55);
  border-bottom: 1px solid rgba(var(--v-border-color), 0.5);
}
.sid-mini-table td { padding: 7px 8px; border-bottom: 1px solid rgba(var(--v-border-color), 0.25); }
.sid-mini-table tbody tr:last-child td { border-bottom: none; }
.sid-mini-table tbody tr:hover { background: rgba(var(--v-theme-primary), 0.045); }

/* ─────────────── Detail grid ─────────────── */
.detail-label {
  font-size: 10.5px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.55px;
  color: rgba(var(--v-theme-on-surface), 0.5);
  margin-bottom: 3px;
}
.detail-value {
  font-size: 14px;
  line-height: 1.4;
  overflow-wrap: anywhere;
}
/* Give each detail cell its own rhythm rather than one dense block of rows. */
.sid-panels :deep(.detail-value) { min-height: 22px; }
</style>
