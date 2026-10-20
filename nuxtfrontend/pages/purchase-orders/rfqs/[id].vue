<template>
  <v-container fluid class="pa-3 pa-md-5 rfq-page">
    <v-progress-linear v-if="loading && !rfq" color="primary" indeterminate rounded class="mb-3" />

    <!-- Not found -->
    <div v-if="!loading && !rfq" class="pa-10 text-center">
      <v-icon size="72" color="grey">mdi-file-question-outline</v-icon>
      <div class="text-h5 font-weight-bold mt-3">Request not found</div>
      <div class="text-body-2 text-medium-emphasis mt-1">It may have been deleted or belongs to another branch.</div>
      <v-btn color="purple" variant="flat" rounded="lg" class="text-none mt-4" prepend-icon="mdi-arrow-left" :to="listPath">Back to RFQs</v-btn>
    </div>

    <template v-if="rfq">
      <!-- ═══════════════ HERO ═══════════════ -->
      <div class="rfq-hero mb-4" :style="heroTheme">
        <span class="rfq-glow" />
        <span class="rfq-glow rfq-glow-2" />

        <div class="d-flex flex-wrap align-center justify-space-between ga-3 rfq-hero-top">
          <div class="d-flex align-center" style="gap:14px; min-width:0">
            <v-btn
              icon="mdi-arrow-left"
              variant="text"
              size="small"
              class="rfq-hero-iconbtn"
              title="Back to RFQs"
              :to="listPath"
            />
            <div class="rfq-hero-icon">
              <v-icon size="30">mdi-file-document-multiple-outline</v-icon>
            </div>
            <div style="min-width:0">
              <div class="rfq-eyebrow">
                <v-icon size="10">mdi-circle</v-icon>
                RFQ · {{ rfq.rfq_number }}
              </div>
              <h1 class="rfq-title">{{ rfq.title || 'Untitled request' }}</h1>
              <div class="rfq-sub">
                Created {{ formatStamp(rfq.created_at) }}
                <span v-if="rfq.created_by_name"> by {{ rfq.created_by_name }}</span>
                <span v-if="rfq.branch_name"> · {{ rfq.branch_name }}</span>
              </div>
            </div>
          </div>

          <div class="d-flex flex-wrap align-center ga-2">
            <span class="rfq-hero-status">
              <span class="rfq-hero-dot" :class="'dot-' + rfq.status" />
              {{ statusLabel(rfq.status) }}
            </span>
            <v-btn
              v-if="rfq.status === 'draft'"
              variant="flat"
              elevation="0"
              rounded="lg"
              class="text-none rfq-btn-strong"
              prepend-icon="mdi-send"
              :loading="acting === 'send'"
              @click="sendToSuppliers"
            >Send to suppliers</v-btn>
            <v-btn
              v-if="canAddQuote"
              variant="flat"
              elevation="0"
              rounded="lg"
              class="text-none rfq-btn-glass"
              prepend-icon="mdi-plus"
              @click="openQuoteDialog"
            >Add quote</v-btn>
            <v-btn
              v-if="rfq.awarded_po"
              variant="flat"
              elevation="0"
              rounded="lg"
              class="text-none rfq-btn-strong"
              prepend-icon="mdi-cart-check"
              :to="`${ns}/purchase-orders/${rfq.awarded_po}`"
            >View PO</v-btn>
            <v-btn
              v-else-if="rfq.status === 'awarded'"
              variant="flat"
              elevation="0"
              rounded="lg"
              class="text-none rfq-btn-strong"
              prepend-icon="mdi-cart-plus"
              :loading="acting === 'po'"
              @click="createPO"
            >Create PO</v-btn>
            <v-menu offset="4" location="bottom end">
              <template #activator="{ props: menuProps }">
                <v-btn v-bind="menuProps" icon="mdi-dots-vertical" variant="text" class="rfq-hero-iconbtn" />
              </template>
              <v-list density="compact" min-width="210">
                <v-list-item
                  prepend-icon="mdi-content-duplicate"
                  title="Duplicate as new RFQ"
                  @click="duplicateRfq"
                />
                <v-list-item
                  v-if="!['closed', 'cancelled'].includes(rfq.status)"
                  prepend-icon="mdi-lock-check-outline"
                  title="Close RFQ"
                  @click="updateStatus('closed')"
                />
                <v-list-item
                  v-if="!['cancelled', 'awarded'].includes(rfq.status)"
                  prepend-icon="mdi-cancel"
                  title="Cancel RFQ"
                  base-color="error"
                  @click="updateStatus('cancelled')"
                />
                <v-divider class="my-1" />
                <v-list-item
                  prepend-icon="mdi-trash-can-outline"
                  title="Delete RFQ"
                  base-color="error"
                  @click="deleteDialog = true"
                />
              </v-list>
            </v-menu>
          </div>
        </div>

        <div class="rfq-hero-foot d-flex flex-wrap align-center" style="gap:8px">
          <span class="rfq-hero-chip" :class="{ 'rfq-hero-chip-alert': deadline.color === 'error' }">
            <v-icon size="14">{{ deadline.icon }}</v-icon>{{ deadline.label }}
          </span>
          <span v-if="rfq.expected_delivery" class="rfq-hero-chip">
            <v-icon size="14">mdi-truck-clock-outline</v-icon>Expected {{ formatDate(rfq.expected_delivery) }}
          </span>
          <span class="rfq-hero-chip">
            <v-icon size="14">mdi-package-variant-closed</v-icon>{{ itemRows.length }} item{{ itemRows.length === 1 ? '' : 's' }}
          </span>
          <span v-if="rfq.awarded_supplier_name" class="rfq-hero-chip">
            <v-icon size="14">mdi-trophy-outline</v-icon>{{ rfq.awarded_supplier_name }}
          </span>
          <span v-if="isExpired" class="rfq-hero-chip rfq-hero-chip-alert">
            <v-icon size="14">mdi-alert-circle-outline</v-icon>Deadline passed
          </span>
        </div>
      </div>

      <!-- ═══════════════ KPI STRIP ═══════════════ -->
      <v-row dense class="mb-2">
        <v-col v-for="k in kpiTiles" :key="k.title" cols="12" sm="6" lg="3">
          <KpiTile v-bind="k" />
        </v-col>
      </v-row>

      <v-row>
        <!-- ═══════════════ MAIN COLUMN ═══════════════ -->
        <v-col cols="12" lg="8">
          <!-- Requested items -->
          <v-card rounded="lg" elevation="0" class="rfq-card mb-3">
            <div class="rfq-panel-head">
              <div class="d-flex align-center" style="gap:10px">
                <v-avatar size="32" color="purple" variant="tonal">
                  <v-icon size="17">mdi-package-variant-closed</v-icon>
                </v-avatar>
                <div>
                  <div class="rfq-panel-title">Requested items</div>
                  <div class="rfq-panel-sub">{{ itemRows.length }} line{{ itemRows.length === 1 ? '' : 's' }} · {{ totalQty }} unit{{ totalQty === 1 ? '' : 's' }} requested</div>
                </div>
              </div>
              <v-chip v-if="bestQuote" size="small" color="success" variant="tonal" prepend-icon="mdi-tag-check-outline">
                Best pricing from {{ bestQuote.supplier_name }}
              </v-chip>
            </div>
            <v-divider />

            <div v-if="!itemRows.length" class="pa-8 text-center text-medium-emphasis">
              <v-icon size="40" color="grey">mdi-package-variant</v-icon>
              <div class="text-body-2 mt-2">No line items were captured on this request.</div>
            </div>

            <div v-else class="rfq-table-wrap">
              <table class="rfq-table">
                <thead>
                  <tr>
                    <th class="text-center" style="width:52px">#</th>
                    <th>Item</th>
                    <th class="text-right">Qty</th>
                    <th>Unit</th>
                    <th class="text-right">Best unit price</th>
                    <th class="text-right">Best line total</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="(item, i) in itemRows" :key="i">
                    <td class="text-center text-medium-emphasis">{{ String(i + 1).padStart(2, '0') }}</td>
                    <td><span class="font-weight-medium">{{ item.name || '—' }}</span></td>
                    <td class="text-right">{{ item.qty ?? '—' }}</td>
                    <td class="text-medium-emphasis">{{ item.unit || '—' }}</td>
                    <td class="text-right">{{ bestUnitCost(item) }}</td>
                    <td class="text-right font-weight-medium">{{ bestLineTotal(item) }}</td>
                  </tr>
                </tbody>
              </table>
            </div>

            <template v-if="rfq.description">
              <v-divider />
              <div class="pa-4">
                <div class="rfq-panel-title mb-1">Description / requirements</div>
                <div class="text-body-2" style="white-space:pre-wrap; line-height:1.7">{{ rfq.description }}</div>
              </div>
            </template>
          </v-card>

          <!-- Supplier quotes -->
          <v-card rounded="lg" elevation="0" class="rfq-card">
            <div class="rfq-panel-head">
              <div class="d-flex align-center" style="gap:10px">
                <v-avatar size="32" color="info" variant="tonal">
                  <v-icon size="17">mdi-clipboard-list-outline</v-icon>
                </v-avatar>
                <div>
                  <div class="rfq-panel-title">Supplier quotes</div>
                  <div class="rfq-panel-sub">{{ quotesRanked.length }} response{{ quotesRanked.length === 1 ? '' : 's' }} · ranked by total cost</div>
                </div>
              </div>
              <v-btn
                v-if="canAddQuote"
                size="small"
                color="purple"
                variant="tonal"
                rounded="lg"
                class="text-none"
                prepend-icon="mdi-plus"
                @click="openQuoteDialog"
              >Add quote</v-btn>
            </div>
            <v-divider />

            <EmptyState
              v-if="!quotesRanked.length"
              icon="mdi-file-question-outline"
              title="No quotes received yet"
              message="Send this RFQ to suppliers, then record their responses to unlock comparison and award."
            >
              <v-btn
                v-if="rfq.status === 'draft'"
                color="purple"
                variant="flat"
                rounded="lg"
                class="text-none mt-3"
                prepend-icon="mdi-send"
                :loading="acting === 'send'"
                @click="sendToSuppliers"
              >Send to suppliers</v-btn>
            </EmptyState>

            <div v-else class="pa-4 d-flex flex-column" style="gap:12px">
              <div
                v-for="(quote, i) in quotesRanked"
                :key="quote.id"
                class="rfq-quote"
                :class="{ 'rfq-quote--best': quote.id === bestQuoteId, 'rfq-quote--awarded': quote.status === 'awarded' }"
              >
                <div class="rfq-quote-rank" :class="{ 'rfq-quote-rank--best': quote.id === bestQuoteId }">
                  <v-icon v-if="quote.id === bestQuoteId" size="18">mdi-trophy-outline</v-icon>
                  <span v-else>{{ i + 1 }}</span>
                </div>

                <div class="flex-grow-1" style="min-width:0">
                  <div class="d-flex flex-wrap align-center justify-space-between" style="gap:8px">
                    <div class="d-flex align-center" style="gap:10px; min-width:0">
                      <v-avatar size="36" :color="avatarColor(quote.supplier_name)" variant="tonal">
                        <span class="rfq-initials">{{ initials(quote.supplier_name) }}</span>
                      </v-avatar>
                      <div style="min-width:0">
                        <div class="font-weight-medium">{{ quote.supplier_name }}</div>
                        <div class="text-caption text-medium-emphasis">
                          {{ quote.delivery_days || 0 }} days lead time
                          <template v-if="quote.valid_until"> · valid until {{ formatDate(quote.valid_until) }}</template>
                        </div>
                      </div>
                    </div>
                    <div class="d-flex align-center" style="gap:8px">
                      <v-chip v-if="quote.id === bestQuoteId" size="x-small" color="success" variant="tonal" class="font-weight-bold">Best value</v-chip>
                      <v-chip size="x-small" :color="quoteStatusColor(quote.status)" variant="tonal">{{ quoteStatusLabel(quote.status) }}</v-chip>
                      <div class="rfq-quote-total">{{ formatMoney(quote.total_cost) }}</div>
                    </div>
                  </div>

                  <div v-if="quote.notes" class="text-caption text-medium-emphasis mt-2" style="line-height:1.5">
                    <v-icon size="13" class="mr-1">mdi-note-text-outline</v-icon>{{ quote.notes }}
                  </div>

                  <div class="d-flex flex-wrap align-center justify-space-between mt-3" style="gap:8px">
                    <span class="text-caption text-medium-emphasis">
                      <v-icon size="13" class="mr-1">mdi-clock-outline</v-icon>Submitted {{ formatStamp(quote.submitted_at) }}
                    </span>
                    <div class="d-flex align-center" style="gap:6px">
                      <v-chip
                        v-if="quote.status === 'pending' && quoteSavings(quote) > 0"
                        size="x-small"
                        color="teal"
                        variant="tonal"
                        prepend-icon="mdi-piggy-bank-outline"
                      >Save {{ formatMoney(quoteSavings(quote)) }}</v-chip>
                      <v-btn
                        v-if="canAward && quote.status === 'pending'"
                        size="small"
                        color="success"
                        variant="flat"
                        rounded="lg"
                        class="text-none"
                        prepend-icon="mdi-trophy"
                        @click="askAward(quote)"
                      >Award</v-btn>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </v-card>
        </v-col>

        <!-- ═══════════════ SIDEBAR ═══════════════ -->
        <v-col cols="12" lg="4">
          <!-- Summary -->
          <v-card rounded="lg" elevation="0" class="rfq-card mb-3">
            <div class="rfq-panel-head">
              <div class="d-flex align-center" style="gap:10px">
                <v-avatar size="32" color="indigo" variant="tonal">
                  <v-icon size="17">mdi-information-outline</v-icon>
                </v-avatar>
                <div class="rfq-panel-title">Request summary</div>
              </div>
            </div>
            <v-divider />
            <div class="pa-4 d-flex flex-column" style="gap:12px">
              <div v-for="row in summaryRows" :key="row.label" class="rfq-summary-row">
                <span class="rfq-summary-label"><v-icon size="15" class="mr-2">{{ row.icon }}</v-icon>{{ row.label }}</span>
                <span class="rfq-summary-value">{{ row.value }}</span>
              </div>
            </div>
            <template v-if="rfq.notes">
              <v-divider />
              <div class="pa-4">
                <div class="rfq-summary-label mb-1">Internal notes</div>
                <div class="text-body-2" style="white-space:pre-wrap; line-height:1.6">{{ rfq.notes }}</div>
              </div>
            </template>
          </v-card>

          <!-- Savings callout -->
          <v-card v-if="quoteStats.count > 1" rounded="lg" elevation="0" class="rfq-card mb-3 rfq-savings">
            <div class="pa-4">
              <div class="d-flex align-center justify-space-between">
                <div class="rfq-panel-title">Negotiation headroom</div>
                <v-icon color="teal">mdi-piggy-bank-outline</v-icon>
              </div>
              <div class="rfq-savings-value">{{ formatMoney(quoteStats.spread) }}</div>
              <div class="text-caption text-medium-emphasis">
                Difference between the best and highest quote
                <template v-if="quoteStats.spreadPct"> ({{ quoteStats.spreadPct }}%)</template>.
              </div>
              <v-divider class="my-3" />
              <div class="d-flex justify-space-between text-body-2">
                <span class="text-medium-emphasis">Lowest</span>
                <span class="font-weight-medium">{{ formatMoney(quoteStats.best) }}</span>
              </div>
              <div class="d-flex justify-space-between text-body-2 mt-1">
                <span class="text-medium-emphasis">Highest</span>
                <span class="font-weight-medium">{{ formatMoney(quoteStats.worst) }}</span>
              </div>
            </div>
          </v-card>

          <!-- Timeline -->
          <v-card rounded="lg" elevation="0" class="rfq-card">
            <div class="rfq-panel-head">
              <div class="d-flex align-center" style="gap:10px">
                <v-avatar size="32" color="teal" variant="tonal">
                  <v-icon size="17">mdi-timeline-clock-outline</v-icon>
                </v-avatar>
                <div class="rfq-panel-title">Activity timeline</div>
              </div>
            </div>
            <v-divider />
            <div class="pa-4">
              <div v-for="(ev, i) in timeline" :key="i" class="rfq-tl-item">
                <div class="rfq-tl-rail">
                  <v-avatar size="28" :color="ev.color" variant="tonal">
                    <v-icon size="14">{{ ev.icon }}</v-icon>
                  </v-avatar>
                  <span v-if="i < timeline.length - 1" class="rfq-tl-line" />
                </div>
                <div style="min-width:0; padding-bottom:14px">
                  <div class="rfq-tl-title">{{ ev.title }}</div>
                  <div class="rfq-tl-meta">{{ ev.meta }}</div>
                </div>
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>
    </template>

    <!-- ═══════════════ ADD QUOTE ═══════════════ -->
    <v-dialog v-model="addQuoteDialog" max-width="560" persistent>
      <v-card rounded="lg" class="overflow-hidden">
        <BrandDialogHeader
          icon="mdi-cash-plus"
          title="Record supplier quote"
          :subtitle="rfq ? `${rfq.rfq_number} · ${rfq.title}` : ''"
          @close="addQuoteDialog = false"
        />

        <div class="pa-5">
          <v-alert v-if="quoteError" type="error" variant="tonal" density="compact" rounded="lg" class="mb-3">
            {{ quoteError }}
          </v-alert>

          <v-select
            v-model="quoteForm.supplier"
            :items="availableSuppliers"
            item-title="label"
            item-value="value"
            label="Supplier *"
            density="compact"
            variant="outlined"
            rounded="lg"
            prepend-inner-icon="mdi-truck-delivery-outline"
            :menu-props="{ maxHeight: 320 }"
            class="mb-3"
          >
            <template #no-data>
              <div class="text-body-2 text-medium-emphasis pa-3">
                Every supplier has already quoted, or none are registered.
              </div>
            </template>
          </v-select>

          <v-row dense>
            <v-col cols="12" sm="6">
              <v-text-field
                v-model.number="quoteForm.total_cost"
                label="Total cost *"
                type="number"
                min="0"
                prefix="KES"
                density="compact"
                variant="outlined"
                rounded="lg"
                class="mb-3"
              />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field
                v-model.number="quoteForm.delivery_days"
                label="Delivery lead time (days)"
                type="number"
                min="0"
                density="compact"
                variant="outlined"
                rounded="lg"
                prepend-inner-icon="mdi-truck-fast-outline"
                class="mb-3"
              />
            </v-col>
          </v-row>

          <v-text-field
            v-model="quoteForm.valid_until"
            label="Quote valid until"
            type="date"
            density="compact"
            variant="outlined"
            rounded="lg"
            prepend-inner-icon="mdi-calendar-check-outline"
            class="mb-3"
          />

          <v-textarea
            v-model="quoteForm.notes"
            label="Supplier notes / terms"
            variant="outlined"
            density="compact"
            rounded="lg"
            rows="3"
            hide-details
          />
        </div>

        <v-card-actions class="px-5 pb-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="addQuoteDialog = false">Cancel</v-btn>
          <v-btn
            color="purple"
            variant="flat"
            rounded="lg"
            class="text-none"
            prepend-icon="mdi-check"
            :loading="savingQuote"
            :disabled="!quoteForm.supplier || !(Number(quoteForm.total_cost) > 0)"
            @click="submitQuote"
          >Save quote</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ AWARD CONFIRM ═══════════════ -->
    <v-dialog v-model="awardDialog" max-width="480" persistent>
      <v-card rounded="lg" class="overflow-hidden">
        <BrandDialogHeader
          icon="mdi-trophy-outline"
          title="Award this RFQ"
          :subtitle="awardTarget ? awardTarget.supplier_name : ''"
          @close="awardDialog = false"
        />
        <div class="pa-5">
          <div class="text-body-2">
            Awarding locks the decision to <b>{{ awardTarget?.supplier_name }}</b>
            at <b>{{ formatMoney(awardTarget?.total_cost) }}</b>. All other quotes will be marked rejected.
          </div>
          <v-alert v-if="awardError" type="error" variant="tonal" density="compact" rounded="lg" class="mt-3">
            {{ awardError }}
          </v-alert>
        </div>
        <v-card-actions class="px-5 pb-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="awardDialog = false">Cancel</v-btn>
          <v-btn
            color="success"
            variant="flat"
            rounded="lg"
            class="text-none"
            prepend-icon="mdi-trophy"
            :loading="awarding"
            @click="confirmAward"
          >Award RFQ</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ DELETE CONFIRM ═══════════════ -->
    <v-dialog v-model="deleteDialog" max-width="460" persistent>
      <v-card rounded="lg" class="overflow-hidden">
        <BrandDialogHeader
          icon="mdi-trash-can-outline"
          title="Delete request for quotation"
          :subtitle="rfq?.rfq_number"
          @close="deleteDialog = false"
        />
        <div class="pa-5 text-body-2">
          This permanently removes <b>{{ rfq?.title }}</b> and every supplier quote attached to it.
          This action cannot be undone.
        </div>
        <v-card-actions class="px-5 pb-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn
            color="error"
            variant="flat"
            rounded="lg"
            class="text-none"
            prepend-icon="mdi-trash-can"
            :loading="deleting"
            @click="confirmDelete"
          >Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3500">
      {{ snack.text }}
      <template #actions>
        <v-btn variant="text" @click="snack.show = false">Close</v-btn>
      </template>
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, computed, reactive, onMounted } from 'vue'
import { useResource } from '~/composables/useResource'
import { useBranding } from '~/composables/useBranding'
import { formatMoney, formatDate, formatStamp } from '~/utils/format'

const { $api } = useNuxtApp()
const route = useRoute()
const brand = useBranding()
const rfqId = route.params.id

const rfqRes = useResource('/purchase-orders/rfqs/')
const loading = computed(() => rfqRes.loading.value)
const rfq = computed(() => rfqRes.item.value)

// Stay inside the namespace the user arrived from (bare /purchase-orders,
// /pharmacy or /ims) so links never bounce them to another tenant surface.
const ns = computed(() => {
  const p = route.path
  if (p.startsWith('/ims')) return '/ims'
  if (p.startsWith('/pharmacy')) return '/pharmacy'
  return ''
})
const listPath = computed(() => `${ns.value}/purchase-orders/rfqs`)

const heroTheme = computed(() => ({
  '--hero-deep': brand.secondary.value,
  '--hero-main': brand.primary.value,
  '--hero-accent': brand.gradientStops.value[2],
  '--hero-ink': brand.ink.value,
  '--hero-glow': brand.tint('primary', 0.3),
  '--hero-glow-2': brand.tint('accent', 0.2),
  '--hero-shadow': brand.shadow.value
}))

// ── Labels / tones ──────────────────────────────────────────────────────
const CLOSED = ['awarded', 'closed', 'cancelled']

const RFQ_STATUS = {
  draft: { label: 'Draft', dot: '#94a3b8' },
  sent: { label: 'Sent to suppliers', dot: '#38bdf8' },
  quoted: { label: 'Quotes received', dot: '#f59e0b' },
  awarded: { label: 'Awarded', dot: '#22c55e' },
  closed: { label: 'Closed', dot: '#94a3b8' },
  cancelled: { label: 'Cancelled', dot: '#ef4444' }
}
function statusLabel(s) {
  return RFQ_STATUS[s]?.label || s
}

function quoteStatusColor(s) {
  return { pending: 'warning', awarded: 'success', rejected: 'error' }[s] || 'default'
}
function quoteStatusLabel(s) {
  return { pending: 'Pending', awarded: 'Awarded', rejected: 'Rejected' }[s] || s
}

// ── Deadline ────────────────────────────────────────────────────────────
function buildDeadline(date, status) {
  if (!date) {
    return { label: 'No response deadline', color: 'grey', icon: 'mdi-calendar-blank-outline', days: null }
  }
  const iso = String(date).slice(0, 10)
  const parsed = new Date(`${iso}T00:00:00`)
  if (Number.isNaN(parsed.getTime())) {
    return { label: formatDate(date), color: 'grey', icon: 'mdi-calendar', days: null }
  }
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  const days = Math.round((parsed - today) / 86400000)

  if (CLOSED.includes(status)) {
    return { label: formatDate(date), color: 'default', icon: 'mdi-calendar-check', days }
  }
  if (days < 0) return { label: `${Math.abs(days)}d overdue`, color: 'error', icon: 'mdi-calendar-alert', days }
  if (days === 0) return { label: 'Due today', color: 'warning', icon: 'mdi-calendar-clock', days }
  if (days <= 3) return { label: `${days}d left`, color: 'warning', icon: 'mdi-calendar-clock', days }
  if (days <= 7) return { label: `${days}d left`, color: 'info', icon: 'mdi-calendar-clock', days }
  return { label: `${days}d left`, color: 'success', icon: 'mdi-calendar-check', days }
}

const deadline = computed(() => buildDeadline(rfq.value?.response_deadline, rfq.value?.status))
const isExpired = computed(
  () => deadline.value.days != null && deadline.value.days < 0 && !CLOSED.includes(rfq.value?.status)
)

// ── Items ───────────────────────────────────────────────────────────────
const itemRows = computed(() => (Array.isArray(rfq.value?.items) ? rfq.value.items : []))
const totalQty = computed(() =>
  itemRows.value.reduce((n, it) => n + (Number(it?.qty) || 0), 0)
)

// ── Quotes ──────────────────────────────────────────────────────────────
const quotesRanked = computed(() => {
  const list = Array.isArray(rfq.value?.quotes) ? rfq.value.quotes.slice() : []
  return list.sort((a, b) => (Number(a.total_cost) || 0) - (Number(b.total_cost) || 0))
})

const bestQuote = computed(
  () => quotesRanked.value.find((q) => Number(q.total_cost) > 0) || null
)
const bestQuoteId = computed(() => bestQuote.value?.id ?? null)

const quoteStats = computed(() => {
  const rows = quotesRanked.value
  const costs = rows.map((q) => Number(q.total_cost) || 0).filter((n) => n > 0)
  const best = costs.length ? Math.min(...costs) : null
  const worst = costs.length ? Math.max(...costs) : null
  const spread = best != null && worst != null ? worst - best : 0
  const spreadPct = worst ? Math.round((spread / worst) * 100) : 0
  const deliveries = rows
    .map((q) => Number(q.delivery_days) || 0)
    .filter((n) => n > 0)
  const avgDelivery = deliveries.length
    ? Math.round(deliveries.reduce((a, b) => a + b, 0) / deliveries.length)
    : 0
  const pending = rows.filter((q) => q.status === 'pending').length
  return { count: rows.length, best, worst, spread, spreadPct, avgDelivery, pending }
})

function quoteSavings(quote) {
  const worst = quoteStats.value.worst
  const cost = Number(quote?.total_cost) || 0
  if (!worst || !cost) return 0
  return Math.max(0, worst - cost)
}

function bestItemFor(item) {
  const source = Array.isArray(bestQuote.value?.items) ? bestQuote.value.items : []
  const key = String(item?.name || '').trim().toLowerCase()
  if (!key) return null
  return source.find((it) => String(it?.name || '').trim().toLowerCase() === key) || null
}
function bestUnitCost(item) {
  const match = bestItemFor(item)
  return match && match.unit_cost != null ? formatMoney(match.unit_cost) : '—'
}
function bestLineTotal(item) {
  const match = bestItemFor(item)
  if (!match) return '—'
  const total = match.total != null ? Number(match.total) : Number(match.unit_cost) * Number(item?.qty)
  return Number.isFinite(total) ? formatMoney(total) : '—'
}

// ── KPI tiles ───────────────────────────────────────────────────────────
const kpiTiles = computed(() => {
  const s = quoteStats.value
  return [
    {
      title: 'Quotes received',
      value: String(s.count),
      icon: 'mdi-cash-multiple',
      color: 'info',
      hint: `${s.pending} awaiting decision`,
      deltaLabel: '',
      flat: true
    },
    {
      title: 'Best quote',
      value: s.best != null ? formatMoney(s.best) : '—',
      valueNum: s.best || 0,
      icon: 'mdi-tag-check-outline',
      color: 'success',
      hint: bestQuote.value ? bestQuote.value.supplier_name : 'Awaiting quotes',
      deltaLabel: '',
      flat: true
    },
    {
      title: 'Bid spread',
      value: formatMoney(s.spread),
      valueNum: s.spread,
      icon: 'mdi-swap-horizontal-bold',
      color: 'teal',
      hint: s.spreadPct ? `${s.spreadPct}% below highest` : 'Needs two or more quotes',
      deltaLabel: '',
      flat: true
    },
    {
      title: 'Avg lead time',
      value: s.avgDelivery ? `${s.avgDelivery} days` : '—',
      icon: 'mdi-truck-fast-outline',
      color: 'indigo',
      hint: 'Across quoted suppliers',
      deltaLabel: '',
      flat: true
    }
  ]
})

// ── Sidebar summary / timeline ──────────────────────────────────────────
const summaryRows = computed(() => {
  const r = rfq.value || {}
  return [
    { icon: 'mdi-store-marker', label: 'Branch', value: r.branch_name || 'All branches' },
    { icon: 'mdi-account-outline', label: 'Requested by', value: r.created_by_name || '—' },
    { icon: 'mdi-calendar-blank', label: 'Created', value: formatStamp(r.created_at) },
    { icon: 'mdi-calendar-clock', label: 'Response deadline', value: r.response_deadline ? formatDate(r.response_deadline) : '—' },
    { icon: 'mdi-truck-clock-outline', label: 'Expected delivery', value: r.expected_delivery ? formatDate(r.expected_delivery) : '—' },
    { icon: 'mdi-trophy-outline', label: 'Awarded supplier', value: r.awarded_supplier_name || '—' },
    { icon: 'mdi-cart-check', label: 'Purchase order', value: r.awarded_po ? `#${r.awarded_po}` : '—' }
  ]
})

const timeline = computed(() => {
  const r = rfq.value
  if (!r) return []
  const events = [
    {
      icon: 'mdi-file-document-plus-outline',
      color: 'purple',
      title: 'RFQ created',
      meta: `${formatStamp(r.created_at)}${r.created_by_name ? ' · ' + r.created_by_name : ''}`,
      at: r.created_at
    }
  ]
  for (const q of r.quotes || []) {
    events.push({
      icon: 'mdi-cash-multiple',
      color: 'info',
      title: `Quote from ${q.supplier_name}`,
      meta: `${formatMoney(q.total_cost)} · ${formatStamp(q.submitted_at)}`,
      at: q.submitted_at
    })
  }
  if (r.awarded_supplier_name) {
    events.push({
      icon: 'mdi-trophy-outline',
      color: 'success',
      title: `Awarded to ${r.awarded_supplier_name}`,
      meta: formatStamp(r.updated_at),
      at: r.updated_at
    })
  }
  if (r.awarded_po) {
    events.push({
      icon: 'mdi-cart-check',
      color: 'teal',
      title: 'Purchase order created',
      meta: `Linked PO #${r.awarded_po}`,
      at: r.updated_at
    })
  }
  return events.sort((a, b) => new Date(b.at) - new Date(a.at))
})

// ── Avatars ─────────────────────────────────────────────────────────────
const AVATAR_COLORS = ['purple', 'indigo', 'teal', 'deep-orange', 'blue', 'green', 'pink', 'cyan']
function avatarColor(name) {
  let h = 0
  for (const ch of String(name || '')) h = (h * 31 + ch.charCodeAt(0)) % 997
  return AVATAR_COLORS[h % AVATAR_COLORS.length]
}
function initials(name) {
  return String(name || '?')
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0])
    .join('')
    .toUpperCase()
}

// ── Snackbar ────────────────────────────────────────────────────────────
const snack = reactive({ show: false, text: '', color: 'success' })
function notify(text, color = 'success') {
  snack.text = text
  snack.color = color
  snack.show = true
}
function errorMessage(e) {
  const data = e?.response?.data
  return data?.detail || (data ? JSON.stringify(data) : e?.message) || 'Something went wrong.'
}

// ── Loading ─────────────────────────────────────────────────────────────
async function loadRFQ() {
  await rfqRes.get(rfqId)
}

// ── Supplier quotes ─────────────────────────────────────────────────────
const supplierOptions = ref([])
const addQuoteDialog = ref(false)
const savingQuote = ref(false)
const quoteError = ref('')
const quoteForm = ref({ supplier: null, total_cost: null, delivery_days: 7, valid_until: '', notes: '' })

const availableSuppliers = computed(() => {
  const quoted = new Set((rfq.value?.quotes || []).map((q) => q.supplier))
  return supplierOptions.value.filter((s) => !quoted.has(s.value))
})

const canAddQuote = computed(() =>
  ['draft', 'sent', 'quoted'].includes(rfq.value?.status)
)
const canAward = computed(() =>
  ['sent', 'quoted'].includes(rfq.value?.status)
)

async function loadSuppliers() {
  try {
    const { data } = await $api.get('/suppliers/', { params: { page_size: 500 } })
    const rows = data?.results || data || []
    const seen = new Set()
    const opts = []
    for (const s of rows) {
      if (!s?.name || seen.has(s.id)) continue
      seen.add(s.id)
      opts.push({ label: s.name, value: s.id })
    }
    supplierOptions.value = opts
  } catch {
    supplierOptions.value = []
  }
}

function openQuoteDialog() {
  quoteError.value = ''
  addQuoteDialog.value = true
}

function resetQuoteForm() {
  quoteForm.value = { supplier: null, total_cost: null, delivery_days: 7, valid_until: '', notes: '' }
}

async function submitQuote() {
  quoteError.value = ''
  if (!quoteForm.value.supplier) {
    quoteError.value = 'Choose the supplier who submitted this quote.'
    return
  }
  if (!(Number(quoteForm.value.total_cost) > 0)) {
    quoteError.value = 'Enter a total cost greater than zero.'
    return
  }
  savingQuote.value = true
  try {
    await $api.post('/purchase-orders/quotes/', {
      rfq: rfqId,
      supplier: quoteForm.value.supplier,
      total_cost: Number(quoteForm.value.total_cost),
      delivery_days: Number(quoteForm.value.delivery_days) || 0,
      valid_until: quoteForm.value.valid_until || null,
      notes: quoteForm.value.notes || ''
    })
    notify('Supplier quote recorded.')
    addQuoteDialog.value = false
    resetQuoteForm()
    await loadRFQ()
  } catch (e) {
    quoteError.value = errorMessage(e)
  } finally {
    savingQuote.value = false
  }
}

// ── Award / purchasing actions ──────────────────────────────────────────
const acting = ref(null)
const awardDialog = ref(false)
const awardTarget = ref(null)
const awarding = ref(false)
const awardError = ref('')

function askAward(quote) {
  awardTarget.value = quote
  awardError.value = ''
  awardDialog.value = true
}

async function confirmAward() {
  if (!awardTarget.value) return
  awarding.value = true
  awardError.value = ''
  try {
    await $api.post(`/purchase-orders/rfqs/${rfqId}/award/`, {
      quote_id: awardTarget.value.id
    })
    notify(`Awarded to ${awardTarget.value.supplier_name}.`)
    awardDialog.value = false
    awardTarget.value = null
    await loadRFQ()
  } catch (e) {
    awardError.value = errorMessage(e)
  } finally {
    awarding.value = false
  }
}

async function sendToSuppliers() {
  if (acting.value) return
  acting.value = 'send'
  try {
    await $api.post(`/purchase-orders/rfqs/${rfqId}/send_to_suppliers/`)
    notify('RFQ marked as sent to suppliers.')
    await loadRFQ()
  } catch (e) {
    notify(errorMessage(e), 'error')
  } finally {
    acting.value = null
  }
}

async function createPO() {
  if (acting.value) return
  acting.value = 'po'
  try {
    const { data } = await $api.post(`/purchase-orders/rfqs/${rfqId}/create_po/`)
    notify('Purchase order created from the awarded quote.')
    navigateTo(`${ns.value}/purchase-orders/${data.id}`)
  } catch (e) {
    notify(errorMessage(e), 'error')
    acting.value = null
  }
}

async function updateStatus(status) {
  try {
    await $api.patch(`/purchase-orders/rfqs/${rfqId}/`, { status })
    notify(`RFQ marked as ${status}.`)
    await loadRFQ()
  } catch (e) {
    notify(errorMessage(e), 'error')
  }
}

/**
 * Copy the header + line items into the builder via the same sessionStorage
 * hand-off the reorder-suggestion flow uses. Quotes are deliberately not
 * carried over — a duplicate starts a fresh bidding round.
 */
function duplicateRfq() {
  if (!import.meta.client || !rfq.value) return
  sessionStorage.setItem(
    'procurement.rfqDraft',
    JSON.stringify({
      title: `${rfq.value.title || 'Request'} (copy)`,
      description: rfq.value.description || '',
      branch: rfq.value.branch ?? null,
      items: itemRows.value.map((i) => ({
        name: i.name,
        qty: i.qty,
        unit: i.unit
      }))
    })
  )
  navigateTo(`${ns.value}/purchase-orders/rfqs/new`)
}

// ── Delete ──────────────────────────────────────────────────────────────
const deleteDialog = ref(false)
const deleting = ref(false)

async function confirmDelete() {
  deleting.value = true
  try {
    await $api.delete(`/purchase-orders/rfqs/${rfqId}/`)
    navigateTo(listPath.value)
  } catch (e) {
    notify(errorMessage(e), 'error')
    deleting.value = false
  }
}

onMounted(async () => {
  brand.load()
  await Promise.all([loadRFQ(), loadSuppliers()])
})
</script>

<style scoped>
/* ═══════════════ Hero ═══════════════ */
.rfq-hero {
  position: relative;
  overflow: hidden;
  border-radius: 18px;
  padding: 20px 22px 16px;
  color: #fff;
  background: linear-gradient(
    120deg,
    var(--hero-deep, #143ce1) 0%,
    var(--hero-main, #2f6dff) 52%,
    var(--hero-accent, #37d6ff) 100%
  );
  box-shadow: var(--hero-shadow, 0 14px 34px rgba(47, 109, 255, 0.24));
}
.rfq-glow {
  position: absolute;
  width: 340px;
  height: 340px;
  border-radius: 50%;
  right: -110px;
  top: -170px;
  background: radial-gradient(circle, var(--hero-glow, rgba(255, 255, 255, 0.28)), transparent 68%);
  pointer-events: none;
}
.rfq-glow-2 {
  right: auto;
  left: -140px;
  top: auto;
  bottom: -220px;
  width: 300px;
  height: 300px;
  background: radial-gradient(circle, var(--hero-glow-2, rgba(55, 214, 255, 0.24)), transparent 70%);
}
.rfq-hero-top {
  position: relative;
}
.rfq-hero-icon {
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
.rfq-eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: rgba(255, 255, 255, 0.78);
}
.rfq-title {
  font-size: 25px;
  line-height: 1.15;
  font-weight: 800;
  letter-spacing: -0.2px;
  margin: 2px 0;
}
.rfq-sub {
  font-size: 13px;
  color: rgba(255, 255, 255, 0.82);
}
.rfq-hero-iconbtn {
  color: #fff !important;
}
.rfq-hero-status {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  padding: 6px 12px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 700;
  color: #fff;
  background: rgba(255, 255, 255, 0.16);
  border: 1px solid rgba(255, 255, 255, 0.32);
  backdrop-filter: blur(6px);
}
.rfq-hero-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #cbd5e1;
}
.dot-draft { background: #cbd5e1; }
.dot-sent { background: #38bdf8; }
.dot-quoted { background: #fbbf24; }
.dot-awarded { background: #4ade80; }
.dot-closed { background: #cbd5e1; }
.dot-cancelled { background: #f87171; }

.rfq-btn-strong {
  background: #ffffff !important;
  color: var(--hero-ink, #143ce1) !important;
  font-weight: 700 !important;
  border: 1px solid rgba(255, 255, 255, 0.95) !important;
  box-shadow: 0 6px 18px rgba(6, 44, 40, 0.28) !important;
}
.rfq-btn-strong:hover {
  background: #ffffff !important;
  filter: brightness(0.94);
}
.rfq-btn-strong :deep(.v-icon) {
  color: var(--hero-ink, #143ce1) !important;
  opacity: 1 !important;
}
.rfq-btn-glass {
  background: rgba(255, 255, 255, 0.16) !important;
  color: #ffffff !important;
  font-weight: 600 !important;
  border: 1px solid rgba(255, 255, 255, 0.34) !important;
  backdrop-filter: blur(6px);
}
.rfq-btn-glass:hover {
  background: rgba(255, 255, 255, 0.26) !important;
  border-color: rgba(255, 255, 255, 0.6) !important;
}
.rfq-btn-glass :deep(.v-icon) {
  color: #ffffff !important;
  opacity: 1 !important;
}
.rfq-hero-foot {
  position: relative;
  margin-top: 14px;
  padding-top: 12px;
  border-top: 1px solid rgba(255, 255, 255, 0.2);
}
.rfq-hero-chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 4px 10px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 600;
  color: rgba(255, 255, 255, 0.94);
  background: rgba(255, 255, 255, 0.14);
  border: 1px solid rgba(255, 255, 255, 0.24);
}
.rfq-hero-chip-alert {
  background: rgba(239, 68, 68, 0.3);
  border-color: rgba(255, 255, 255, 0.45);
}

/* ═══════════════ Panels ═══════════════ */
.rfq-card {
  border: 1px solid rgba(15, 23, 42, 0.08) !important;
  background: rgb(var(--v-theme-surface));
}
.rfq-panel-head {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  padding: 12px 16px;
}
.rfq-panel-title {
  font-size: 14px;
  font-weight: 700;
  line-height: 1.2;
}
.rfq-panel-sub {
  font-size: 11.5px;
  color: rgba(var(--v-theme-on-surface), 0.55);
}

/* ═══════════════ Items table ═══════════════ */
.rfq-table-wrap {
  overflow-x: auto;
}
.rfq-table {
  width: 100%;
  min-width: 640px;
  border-collapse: separate;
  border-spacing: 0;
  font-size: 13.5px;
}
.rfq-table thead th {
  text-align: left;
  font-size: 10.5px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: rgba(var(--v-theme-on-surface), 0.55);
  background: rgba(15, 23, 42, 0.02);
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
  padding: 10px 16px;
  white-space: nowrap;
}
.rfq-table thead th.text-right { text-align: right; }
.rfq-table thead th.text-center { text-align: center; }
.rfq-table tbody td {
  padding: 11px 16px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.055);
  vertical-align: middle;
}
.rfq-table tbody td.text-right { text-align: right; }
.rfq-table tbody td.text-center { text-align: center; }
.rfq-table tbody tr:last-child td { border-bottom: none; }
.rfq-table tbody tr:hover { background: rgba(var(--v-theme-primary), 0.03); }

/* ═══════════════ Quote cards ═══════════════ */
.rfq-quote {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 14px;
  border-radius: 12px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: rgb(var(--v-theme-surface));
  transition: box-shadow 0.16s ease, border-color 0.16s ease;
}
.rfq-quote:hover {
  border-color: rgba(var(--v-theme-primary), 0.25);
  box-shadow: 0 8px 22px rgba(15, 23, 42, 0.07);
}
.rfq-quote--best {
  border-color: rgba(34, 197, 94, 0.45);
  background: rgba(34, 197, 94, 0.045);
}
.rfq-quote--awarded {
  border-color: rgba(34, 197, 94, 0.65);
}
.rfq-quote-rank {
  width: 34px;
  height: 34px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-weight: 800;
  font-size: 13px;
  color: rgba(var(--v-theme-on-surface), 0.6);
  background: rgba(15, 23, 42, 0.05);
}
.rfq-quote-rank--best {
  color: #15803d;
  background: rgba(34, 197, 94, 0.14);
}
.rfq-quote-total {
  font-size: 17px;
  font-weight: 800;
  letter-spacing: -0.2px;
  white-space: nowrap;
}
.rfq-initials {
  font-size: 11px;
  font-weight: 800;
}

/* ═══════════════ Sidebar ═══════════════ */
.rfq-summary-row {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  font-size: 13px;
}
.rfq-summary-label {
  display: inline-flex;
  align-items: center;
  color: rgba(var(--v-theme-on-surface), 0.58);
  white-space: nowrap;
}
.rfq-summary-value {
  font-weight: 600;
  text-align: right;
  overflow-wrap: anywhere;
}
.rfq-savings {
  border: 1px solid rgba(13, 148, 136, 0.28) !important;
  background: linear-gradient(160deg, rgba(13, 148, 136, 0.07), transparent 60%);
}
.rfq-savings-value {
  font-size: 26px;
  font-weight: 800;
  letter-spacing: -0.4px;
  color: #0f766e;
  margin: 2px 0 2px;
}

/* ═══════════════ Timeline ═══════════════ */
.rfq-tl-item {
  display: flex;
  gap: 12px;
}
.rfq-tl-rail {
  display: flex;
  flex-direction: column;
  align-items: center;
  flex-shrink: 0;
}
.rfq-tl-line {
  flex: 1;
  width: 2px;
  min-height: 14px;
  margin: 3px 0;
  background: rgba(15, 23, 42, 0.09);
}
.rfq-tl-title {
  font-size: 13px;
  font-weight: 600;
  line-height: 1.3;
}
.rfq-tl-meta {
  font-size: 11.5px;
  color: rgba(var(--v-theme-on-surface), 0.55);
}

@media (max-width: 600px) {
  .rfq-title {
    font-size: 21px;
  }
  .rfq-quote-total {
    font-size: 15px;
  }
}
</style>
