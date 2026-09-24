<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center">
        <v-avatar color="cyan-lighten-5" size="48" class="mr-3">
          <v-icon color="cyan-darken-2" size="28">mdi-truck-delivery-outline</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 font-weight-bold mb-1">Stock Transfers</h1>
          <div class="text-body-2 text-medium-emphasis">Move stock between warehouses with approval, receipt verification &amp; full audit trail</div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-btn rounded="lg" variant="tonal" class="text-none" color="cyan-darken-2"
               prepend-icon="mdi-file-download-outline" :loading="loading" @click="exportCsv">
          Export CSV
        </v-btn>
        <v-btn rounded="lg" color="primary" variant="flat" class="text-none"
               prepend-icon="mdi-plus" @click="openCreate">New Transfer</v-btn>
        <v-btn rounded="lg" color="primary" variant="tonal" prepend-icon="mdi-refresh"
               :loading="loading" @click="load">Refresh</v-btn>
      </div>
    </div>

    <!-- KPIs -->
    <v-row dense class="mb-4">
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="3" lg="2">
        <v-card rounded="lg" class="pa-4 h-100 kpi-card">
          <div class="d-flex align-start justify-space-between">
            <div class="text-truncate">
              <div class="text-caption text-medium-emphasis text-truncate">{{ k.label }}</div>
              <div class="text-h6 font-weight-bold mt-1">{{ k.value }}</div>
              <div v-if="k.sub" class="text-caption text-medium-emphasis mt-1 text-truncate">{{ k.sub }}</div>
            </div>
            <v-avatar :color="k.color" variant="tonal" rounded="lg" size="40">
              <v-icon size="20">{{ k.icon }}</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Filters -->
    <v-card flat rounded="xl" border class="pa-3 mb-3">
      <v-row dense align="center">
        <v-col cols="12" md="4">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                        placeholder="Search by reference, warehouse or notes…"
                        density="comfortable" hide-details variant="solo-filled" flat clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="statusFilter" :items="statusOptions" item-title="label" item-value="value"
                    label="Status" variant="outlined" density="comfortable" hide-details />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="datePreset" :items="presetOptions" item-title="label" item-value="value"
                    label="Date range" variant="outlined" density="comfortable" hide-details
                    prepend-inner-icon="mdi-calendar-range" />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="sourceFilter" :items="branchFilterItems" item-title="name" item-value="id"
                    label="From warehouse" variant="outlined" density="comfortable" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="destFilter" :items="branchFilterItems" item-title="name" item-value="id"
                    label="To warehouse" variant="outlined" density="comfortable" hide-details clearable />
        </v-col>
      </v-row>
      <v-row v-if="datePreset === 'custom'" dense align="center" class="mt-1">
        <v-col cols="6" md="3">
          <v-text-field v-model="fromDate" type="date" label="From date"
                        variant="outlined" density="comfortable" hide-details clearable />
        </v-col>
        <v-col cols="6" md="3">
          <v-text-field v-model="toDate" type="date" label="To date"
                        variant="outlined" density="comfortable" hide-details clearable />
        </v-col>
        <v-col cols="12" md="6" class="d-flex align-center">
          <div class="text-caption text-medium-emphasis">
            {{ dateFilterSummary }}
          </div>
        </v-col>
      </v-row>
    </v-card>

    <!-- Table -->
    <v-card flat rounded="xl" border>
      <v-data-table :headers="headers" :items="filtered" :loading="loading" items-per-page="15"
                    :sort-by="[{ key: 'requested_at', order: 'desc' }]">
        <template #item.reference="{ item }">
          <div class="font-weight-bold">{{ item.reference }}</div>
          <div class="text-caption text-medium-emphasis">{{ formatDateTime(item.requested_at) }}</div>
        </template>
        <template #item.route="{ item }">
          <div class="d-flex align-center flex-wrap ga-1">
            <v-chip size="small" variant="tonal" color="blue">{{ item.source_branch_name }}</v-chip>
            <v-icon size="16" color="grey">mdi-arrow-right</v-icon>
            <v-chip size="small" variant="tonal" color="green">{{ item.dest_branch_name }}</v-chip>
          </div>
        </template>
        <template #item.totals="{ item }">
          <div class="text-body-2">{{ item.total_items }} items · <strong>{{ item.total_quantity }}</strong> units</div>
        </template>
        <template #item.total_value="{ item }">
          <div class="font-weight-medium">{{ formatMoney(item.total_value) }}</div>
          <div v-if="item.status === 'completed' && item.total_variance !== 0"
               class="text-caption" :class="item.total_variance < 0 ? 'text-error' : 'text-success'">
            variance {{ item.total_variance > 0 ? '+' : '' }}{{ item.total_variance }}
          </div>
        </template>
        <template #item.requested_by_name="{ item }">
          <div class="text-body-2">{{ item.requested_by_name || '—' }}</div>
        </template>
        <template #item.status="{ item }">
          <v-chip size="small" variant="flat" :color="statusColor(item.status)">
            <v-icon start size="14">{{ statusIcon(item.status) }}</v-icon>
            {{ statusLabel(item.status) }}
          </v-chip>
        </template>
        <template #item.actions="{ item }">
          <v-tooltip text="View details" location="top">
            <template #activator="{ props }">
              <v-btn v-bind="props" icon="mdi-eye" variant="text" size="small" @click="openDetail(item)" />
            </template>
          </v-tooltip>
          <v-tooltip v-if="item.status === 'requested' && canApprove" text="Approve & ship" location="top">
            <template #activator="{ props }">
              <v-btn v-bind="props" icon="mdi-check-bold" color="success" variant="text" size="small" @click="approve(item)" />
            </template>
          </v-tooltip>
          <v-tooltip v-if="item.status === 'in_transit'" text="Receive" location="top">
            <template #activator="{ props }">
              <v-btn v-bind="props" icon="mdi-package-down" color="primary" variant="text" size="small" @click="openReceive(item)" />
            </template>
          </v-tooltip>
          <v-tooltip v-if="item.status === 'draft'" text="Submit" location="top">
            <template #activator="{ props }">
              <v-btn v-bind="props" icon="mdi-send" color="info" variant="text" size="small" @click="submitTransfer(item)" />
            </template>
          </v-tooltip>
          <v-tooltip v-if="!['completed', 'cancelled'].includes(item.status)" text="Cancel" location="top">
            <template #activator="{ props }">
              <v-btn v-bind="props" icon="mdi-cancel" color="error" variant="text" size="small" @click="cancelTransfer(item)" />
            </template>
          </v-tooltip>
          <v-tooltip text="Print note (PDF)" location="top">
            <template #activator="{ props }">
              <v-btn v-bind="props" icon="mdi-file-pdf-box" color="red-darken-1" variant="text" size="small" @click="printTransfer(item)" />
            </template>
          </v-tooltip>
        </template>
        <template #no-data>
          <div class="text-center pa-6">
            <v-icon size="48" color="grey-lighten-1">mdi-truck-remove</v-icon>
            <div class="text-body-2 mt-2">No transfers match your filters.</div>
            <v-btn color="primary" class="mt-3" prepend-icon="mdi-plus" @click="openCreate">Create your first transfer</v-btn>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- ══════════ Create dialog ══════════ -->
    <v-dialog v-model="createDialog" max-width="880" persistent scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon class="mr-2" color="primary">mdi-swap-horizontal</v-icon>New Stock Transfer
          <v-spacer /><v-btn icon="mdi-close" variant="text" size="small" @click="createDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pt-4">
          <v-row dense>
            <v-col cols="12" md="6">
              <v-select v-model="form.source_branch" :items="branches" item-title="name" item-value="id"
                        label="From warehouse *" variant="outlined" density="comfortable"
                        :rules="req" prepend-inner-icon="mdi-warehouse" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="form.dest_branch" :items="destBranches" item-title="name" item-value="id"
                        label="To warehouse *" variant="outlined" density="comfortable"
                        :rules="req" prepend-inner-icon="mdi-map-marker-radius" />
            </v-col>
          </v-row>

          <div class="d-flex align-center mt-4 mb-2">
            <div class="text-subtitle-2 font-weight-bold">Items</div>
            <v-spacer />
            <div v-if="form.lines.length" class="text-caption text-medium-emphasis">
              {{ form.lines.length }} item(s) · {{ totalUnits }} units · {{ formatMoney(totalValue) }}
            </div>
          </div>
          <v-autocomplete v-model="picker" :items="stockOptions" :loading="stockLoading"
                          :search="stockSearch" @update:search="onStockSearch"
                          item-title="medication_name" item-value="id" return-object
                          label="Search stock items by name or barcode…" prepend-inner-icon="mdi-magnify"
                          variant="outlined" density="comfortable" clearable hide-no-data
                          @update:model-value="onAddStock">
            <template #item="{ props, item }">
              <v-list-item v-bind="props">
                <v-list-item-subtitle>
                  On hand: {{ item.raw.total_quantity }} {{ item.raw.unit_abbreviation || item.raw.unit_name || '' }}
                  · Cost: {{ formatMoney(item.raw.cost_price) }}
                </v-list-item-subtitle>
              </v-list-item>
            </template>
          </v-autocomplete>

          <v-alert v-if="shortageWarnings.length" type="error" variant="tonal" density="compact" rounded="lg" class="mt-2">
            <div v-for="w in shortageWarnings" :key="w" class="text-body-2">{{ w }}</div>
          </v-alert>

          <v-table v-if="form.lines.length" density="compact" class="mt-2 lines-table">
            <thead>
              <tr>
                <th>Item</th>
                <th class="text-right" style="width:110px">On hand</th>
                <th style="width:130px">Qty to send *</th>
                <th class="text-right" style="width:120px">Value</th>
                <th style="width:52px"></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(l, i) in form.lines" :key="l.stock" :class="{ 'row-over': l.quantity > l.available }">
                <td>{{ l._name }}</td>
                <td class="text-right text-medium-emphasis">{{ l.available }}</td>
                <td>
                  <v-text-field v-model.number="l.quantity" type="number" min="1" density="compact"
                                variant="outlined" hide-details />
                </td>
                <td class="text-right font-weight-medium">{{ formatMoney(l.quantity * l._cost) }}</td>
                <td><v-btn icon="mdi-delete" variant="text" size="small" color="error" @click="form.lines.splice(i, 1)" /></td>
              </tr>
            </tbody>
          </v-table>
          <div v-else class="text-caption text-medium-emphasis text-center py-3">
            No items added — search above to add stock to this transfer.
          </div>

          <v-textarea v-model="form.notes" label="Notes / reason for transfer" rows="2" auto-grow
                      variant="outlined" density="comfortable" hide-details class="mt-3" />
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="createDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="tonal" :loading="saving" :disabled="!canSave"
                 prepend-icon="mdi-content-save" @click="saveTransfer(false)">Save Draft</v-btn>
          <v-btn color="success" variant="flat" :loading="saving" :disabled="!canSave"
                 prepend-icon="mdi-send" @click="saveTransfer(true)">Submit for Approval</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ══════════ Detail dialog ══════════ -->
    <v-dialog v-model="detailDialog" max-width="780" scrollable>
      <v-card v-if="active" rounded="xl">
        <v-card-title class="d-flex align-center flex-wrap ga-2">
          <v-icon color="primary">mdi-truck-delivery</v-icon>
          <span class="font-weight-bold">{{ active.reference }}</span>
          <v-chip size="small" variant="flat" :color="statusColor(active.status)">
            <v-icon start size="14">{{ statusIcon(active.status) }}</v-icon>
            {{ statusLabel(active.status) }}
          </v-chip>
          <v-spacer />
          <v-btn icon="mdi-file-pdf-box" variant="text" size="small" color="red-darken-1"
                 title="Print note (PDF)" @click="printTransfer(active)" />
          <v-btn icon="mdi-close" variant="text" size="small" @click="detailDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pt-4">
          <!-- Route + totals -->
          <v-row dense class="mb-3">
            <v-col cols="6" md="3">
              <div class="text-caption text-medium-emphasis">From</div>
              <div class="text-body-2 font-weight-medium">{{ active.source_branch_name }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-medium-emphasis">To</div>
              <div class="text-body-2 font-weight-medium">{{ active.dest_branch_name }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-medium-emphasis">Value (at cost)</div>
              <div class="text-body-2 font-weight-medium">{{ formatMoney(active.total_value) }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-medium-emphasis">Units</div>
              <div class="text-body-2 font-weight-medium">{{ active.total_quantity }}</div>
            </v-col>
          </v-row>

          <!-- Timeline -->
          <div class="mb-4 timeline-wrap">
            <div class="d-flex align-center">
              <template v-for="(step, i) in timeline" :key="step.key">
                <div class="d-flex flex-column align-center step-node">
                  <v-avatar :color="step.done ? step.color : 'grey-lighten-2'" size="34">
                    <v-icon size="17" :color="step.done ? 'white' : 'grey'">{{ step.icon }}</v-icon>
                  </v-avatar>
                  <div class="text-caption mt-1 font-weight-medium" :class="step.done ? '' : 'text-disabled'">{{ step.label }}</div>
                  <div class="text-caption text-medium-emphasis text-center step-meta">{{ step.meta }}</div>
                </div>
                <div v-if="i < timeline.length - 1" class="step-connector"
                     :class="{ 'step-connector--done': timeline[i + 1].done }" />
              </template>
            </div>
          </div>

          <!-- Lines -->
          <v-table density="compact" class="lines-table">
            <thead>
              <tr>
                <th>Item</th>
                <th class="text-right">Sent</th>
                <th class="text-right">Received</th>
                <th class="text-right">Variance</th>
                <th class="text-right">Value</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="l in active.lines" :key="l.id">
                <td>{{ l.stock_name }}<span v-if="l.stock_unit" class="text-caption text-medium-emphasis ml-1">({{ l.stock_unit }})</span></td>
                <td class="text-right">{{ l.quantity }}</td>
                <td class="text-right">{{ l.quantity_received ?? '—' }}</td>
                <td class="text-right font-weight-medium"
                    :class="l.quantity_received == null ? '' : l.variance < 0 ? 'text-error' : l.variance > 0 ? 'text-success' : ''">
                  {{ l.quantity_received == null ? '—' : (l.variance > 0 ? '+' : '') + l.variance }}
                </td>
                <td class="text-right">{{ formatMoney(l.line_value) }}</td>
              </tr>
            </tbody>
          </v-table>

          <v-alert v-if="active.status === 'completed' && active.total_variance < 0" type="warning"
                   variant="tonal" density="compact" rounded="lg" class="mt-3">
            Short receipt recorded: <strong>{{ active.total_variance }}</strong> unit(s) missing on arrival. Investigate and record the discrepancy.
          </v-alert>

          <div v-if="active.notes" class="mt-3 pa-2 rounded notes-box">
            <div class="text-caption text-medium-emphasis">Notes</div>
            <div class="text-body-2">{{ active.notes }}</div>
          </div>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-btn v-if="active.status === 'draft'" color="info" variant="tonal" prepend-icon="mdi-send"
                 @click="submitTransfer(active)">Submit</v-btn>
          <v-btn v-if="active.status === 'requested' && canApprove" color="success" variant="flat" prepend-icon="mdi-check-bold"
                 @click="approve(active)">Approve &amp; Ship</v-btn>
          <v-btn v-if="active.status === 'in_transit'" color="primary" variant="flat" prepend-icon="mdi-package-down"
                 @click="openReceive(active)">Receive</v-btn>
          <v-spacer />
          <v-btn v-if="!['completed', 'cancelled'].includes(active.status)" color="error" variant="text"
                 prepend-icon="mdi-cancel" @click="cancelTransfer(active)">Cancel</v-btn>
          <v-btn variant="text" @click="detailDialog = false">Close</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ══════════ Receive dialog ══════════ -->
    <v-dialog v-model="receiveDialog" max-width="780" persistent scrollable>
      <v-card v-if="active" rounded="xl">
        <!-- Header -->
        <div class="receive-hero pa-4">
          <div class="d-flex align-center flex-wrap ga-2 text-white">
            <v-icon size="22">mdi-package-down</v-icon>
            <span class="text-h6 font-weight-bold">Receive {{ active.reference }}</span>
            <v-chip size="small" variant="flat" color="cyan">
              <v-icon start size="13">mdi-truck-delivery-outline</v-icon>
              {{ active.source_branch_name }} → {{ active.dest_branch_name }}
            </v-chip>
            <v-spacer />
            <v-btn icon="mdi-close" variant="text" size="small" @click="receiveDialog = false" />
          </div>
          <div class="text-caption mt-1" style="opacity:.85">
            Shipped {{ formatDateTime(active.shipped_at) }}
            <template v-if="inTransitHours != null"> · in transit for {{ inTransitHours }}h</template>
            · goods worth {{ formatMoney(active.total_value) }} at cost
          </div>
        </div>

        <v-card-text class="pt-4">
          <v-alert type="info" variant="tonal" density="compact" rounded="lg" class="mb-4">
            Received quantities are booked into <strong>{{ active.dest_branch_name }}</strong> as batch
            <code>TRF-{{ active.reference }}</code>. Record any short or damaged units per item below.
          </v-alert>

          <!-- Lines -->
          <div class="receive-lines">
            <div v-for="l in receiveLines" :key="l.id" class="receive-line pa-3 mb-3" :class="lineState(l).cls">
              <div class="d-flex align-center flex-wrap">
                <div class="flex-grow-1 text-truncate">
                  <div class="text-body-2 font-weight-medium">{{ l.stock_name }}
                    <span v-if="l.stock_unit" class="text-caption text-medium-emphasis">({{ l.stock_unit }})</span>
                  </div>
                  <div class="text-caption text-medium-emphasis">
                    sent {{ l.quantity }} · {{ formatMoney(l.quantity * l._cost) }}
                  </div>
                </div>
                <div class="d-flex align-center ga-2">
                  <v-btn size="x-small" variant="tonal" class="text-none" @click="l.quantity_received = l.quantity">All</v-btn>
                  <v-btn size="x-small" variant="tonal" color="error" class="text-none"
                         @click="l.quantity_received = 0">None</v-btn>
                  <v-text-field v-model.number="l.quantity_received" type="number" density="compact"
                                variant="outlined" hide-details :min="0" :max="l.quantity"
                                class="receive-qty" :error="l.quantity_received > l.quantity" />
                </div>
                <v-chip size="small" variant="tonal" :color="lineState(l).color" class="ml-2">
                  <v-icon start size="13">{{ lineState(l).icon }}</v-icon>
                  {{ lineState(l).label }}
                </v-chip>
              </div>
              <div class="d-flex align-center mt-2 ga-2">
                <v-text-field v-model="l.notes" density="compact" variant="outlined" hide-details
                              placeholder="Remark (e.g. 2 units damaged in transit)"
                              prepend-inner-icon="mdi-comment-text-outline" class="receive-note" />
                <div class="text-caption text-medium-emphasis text-no-wrap">
                  receiving {{ formatMoney((Number(l.quantity_received) || 0) * l._cost) }}
                </div>
              </div>
            </div>
          </div>

          <!-- Summary -->
          <div class="receive-summary pa-3 mt-2">
            <div class="d-flex flex-wrap ga-4 align-center justify-space-between">
              <div class="d-flex flex-wrap ga-4">
                <div>
                  <div class="text-caption text-medium-emphasis">Units sent</div>
                  <div class="text-h6 font-weight-bold">{{ receiveSummary.sent }}</div>
                </div>
                <div>
                  <div class="text-caption text-medium-emphasis">Units received</div>
                  <div class="text-h6 font-weight-bold text-primary">{{ receiveSummary.received }}</div>
                </div>
                <div>
                  <div class="text-caption text-medium-emphasis">Variance</div>
                  <div class="text-h6 font-weight-bold"
                       :class="receiveSummary.variance < 0 ? 'text-error' : receiveSummary.variance > 0 ? 'text-success' : ''">
                    {{ receiveSummary.variance > 0 ? '+' : '' }}{{ receiveSummary.variance }}
                  </div>
                </div>
                <div>
                  <div class="text-caption text-medium-emphasis">Value received</div>
                  <div class="text-h6 font-weight-bold">{{ formatMoney(receiveSummary.value) }}</div>
                </div>
              </div>
              <v-btn size="small" variant="text" class="text-none" color="primary"
                     prepend-icon="mdi-backup-restore" @click="receiveAll">Reset to full receipt</v-btn>
            </div>
            <v-alert v-if="receiveSummary.variance < 0" type="warning" variant="tonal" density="compact"
                     rounded="lg" class="mt-3">
              Shortfall of <strong>{{ -receiveSummary.variance }}</strong> unit(s) worth
              <strong>{{ formatMoney(-receiveSummary.discrepancyValue) }}</strong>. Add a remark on the affected
              item(s); the discrepancy is recorded on the transfer history.
            </v-alert>
          </div>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="receiveDialog = false">Cancel</v-btn>
          <v-btn color="success" variant="flat" size="large" :loading="saving"
                 :disabled="!receiveValid || receiveSummary.received === 0"
                 prepend-icon="mdi-package-down" @click="confirmReceive">
            Confirm Receipt ({{ receiveSummary.received }} units)
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Cancel confirm -->
    <v-dialog v-model="cancelDialog" max-width="440">
      <v-card v-if="active" rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon color="error" class="mr-2">mdi-cancel</v-icon>Cancel transfer?
        </v-card-title>
        <v-card-text>
          <strong>{{ active.reference }}</strong> ({{ active.source_branch_name }} → {{ active.dest_branch_name }})
          will be cancelled{{ active.status === 'in_transit' ? ' — stock already deducted at source will remain there' : '' }}.
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="cancelDialog = false">Keep it</v-btn>
          <v-btn color="error" variant="flat" :loading="saving" @click="doCancelTransfer">Cancel transfer</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" rounded="lg" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { formatMoney } from '~/utils/format'
import { useAuthStore } from '~/stores/auth'
import { ADMIN_ROLES } from '~/utils/permissions'

const { $api } = useNuxtApp()
const { branches: branchesApi } = useTenantEndpoints()
const auth = useAuthStore()

// RBAC: only supervisors (tenant/branch admins) approve & ship transfers;
// storekeepers can create, submit and receive them.
const canApprove = computed(() =>
  [...ADMIN_ROLES, 'branch_admin'].includes(auth.role))

const loading = ref(false)
const saving = ref(false)
const transfers = ref([])
const branches = ref([])
const stats = ref(null)
const search = ref('')
const statusFilter = ref('all')
const sourceFilter = ref(null)
const destFilter = ref(null)
const datePreset = ref('all')
const fromDate = ref(null)   // 'YYYY-MM-DD' (custom range only)
const toDate = ref(null)     // 'YYYY-MM-DD' (custom range only)

const createDialog = ref(false)
const detailDialog = ref(false)
const receiveDialog = ref(false)
const cancelDialog = ref(false)
const active = ref(null)
const receiveLines = ref([])
const snack = reactive({ show: false, color: 'success', text: '' })
const req = [v => !!v || 'Required']

const form = ref({ source_branch: null, dest_branch: null, notes: '', lines: [] })

const statusOptions = [
  { label: 'All statuses', value: 'all' },
  { label: 'Draft', value: 'draft' },
  { label: 'Requested', value: 'requested' },
  { label: 'In Transit', value: 'in_transit' },
  { label: 'Completed', value: 'completed' },
  { label: 'Cancelled', value: 'cancelled' },
]

const headers = [
  { title: 'Reference', key: 'reference', width: 170 },
  { title: 'Route', key: 'route', sortable: false },
  { title: 'Items', key: 'totals', width: 140, sortable: false },
  { title: 'Value (cost)', key: 'total_value', width: 140, sortable: false },
  { title: 'Requested by', key: 'requested_by_name', width: 140 },
  { title: 'Status', key: 'status', width: 140 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 200 },
]

const branchFilterItems = computed(() => branches.value)

// ── KPIs (from the backend stats endpoint) ──────────────────────────────
const kpis = computed(() => {
  const s = stats.value
  const by = s?.by_status || {}
  return [
    { label: 'Total Transfers', value: s?.total ?? transfers.value.length,
      sub: `${by.draft || 0} draft(s)`, icon: 'mdi-swap-horizontal', color: 'cyan' },
    { label: 'Pending Approval', value: by.requested || 0,
      sub: 'awaiting sign-off', icon: 'mdi-clock-alert', color: 'amber' },
    { label: 'In Transit', value: by.in_transit || 0,
      sub: `worth ${formatMoney(s?.in_transit_value || 0)}`, icon: 'mdi-truck-fast', color: 'blue' },
    { label: 'Completed (this month)', value: s?.completed_this_month ?? 0,
      sub: s?.avg_cycle_hours != null ? `avg cycle ${s.avg_cycle_hours}h` : '',
      icon: 'mdi-check-all', color: 'green' },
    { label: 'Discrepancies', value: s?.variance_units ?? 0,
      sub: 'units of receipt variance', icon: 'mdi-chart-timeline-variant', color: 'red' },
  ]
})

// ── Date range (presets + custom) ───────────────────────────────────────
const presetOptions = [
  { label: 'All time', value: 'all' },
  { label: 'Today', value: 'today' },
  { label: 'Last 7 days', value: '7d' },
  { label: 'Last 30 days', value: '30d' },
  { label: 'This month', value: 'month' },
  { label: 'This year', value: 'year' },
  { label: 'Custom range', value: 'custom' },
]

function isoDay(d) { return d.toISOString().slice(0, 10) }

function presetRange(v) {
  const now = new Date()
  const start = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  switch (v) {
    case 'today': return { from: start, to: null }
    case '7d': { const d = new Date(start); d.setDate(d.getDate() - 6); return { from: d, to: null } }
    case '30d': { const d = new Date(start); d.setDate(d.getDate() - 29); return { from: d, to: null } }
    case 'month': return { from: new Date(now.getFullYear(), now.getMonth(), 1), to: null }
    case 'year': return { from: new Date(now.getFullYear(), 0, 1), to: null }
    default: return { from: null, to: null }
  }
}

// Effective from/to as 'YYYY-MM-DD' (or null when unbounded)
const effectiveFrom = computed(() => {
  if (datePreset.value === 'custom') return fromDate.value || null
  const p = presetRange(datePreset.value)
  return p.from ? isoDay(p.from) : null
})
const effectiveTo = computed(() => {
  if (datePreset.value === 'custom') return toDate.value || null
  const p = presetRange(datePreset.value)
  return p.to ? isoDay(p.to) : null   // presets are open-ended (up to now)
})

const dateFilterSummary = computed(() => {
  if (!effectiveFrom.value && !effectiveTo.value) return ''
  const fmt = (iso) => new Date(iso).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' })
  const from = effectiveFrom.value ? fmt(effectiveFrom.value) : 'start'
  const to = effectiveTo.value ? fmt(effectiveTo.value) : 'today'
  return `Showing transfers requested between ${from} and ${to}.`
})

// ── Filtering ──────────────────────────────────────────────────────────
const filtered = computed(() => {
  const s = (search.value || '').toLowerCase().trim()
  const from = effectiveFrom.value
  const to = effectiveTo.value
  return transfers.value.filter(t => {
    if (statusFilter.value !== 'all' && t.status !== statusFilter.value) return false
    if (sourceFilter.value && t.source_branch !== sourceFilter.value) return false
    if (destFilter.value && t.dest_branch !== destFilter.value) return false
    if (from || to) {
      const d = t.requested_at ? String(t.requested_at).slice(0, 10) : ''
      if (from && (!d || d < from)) return false
      if (to && (!d || d > to)) return false
    }
    if (!s) return true
    return [t.reference, t.source_branch_name, t.dest_branch_name, t.notes,
            t.requested_by_name].filter(Boolean)
      .some(v => v.toLowerCase().includes(s))
  })
})

// ── Create form helpers ────────────────────────────────────────────────
const destBranches = computed(() => branches.value.filter(b => b.id !== form.value.source_branch))
const totalUnits = computed(() => form.value.lines.reduce((s, l) => s + (Number(l.quantity) || 0), 0))
const totalValue = computed(() => form.value.lines.reduce((s, l) => s + (Number(l.quantity) || 0) * l._cost, 0))
const shortageWarnings = computed(() =>
  form.value.lines
    .filter(l => Number(l.quantity) > l.available)
    .map(l => `${l._name}: only ${l.available} on hand — requested ${l.quantity}.`))
const canSave = computed(() => form.value.source_branch && form.value.dest_branch &&
  form.value.source_branch !== form.value.dest_branch &&
  form.value.lines.length > 0 &&
  form.value.lines.every(l => Number(l.quantity) >= 1 && Number(l.quantity) <= l.available))

const picker = ref(null)
const stockOptions = ref([])
const stockLoading = ref(false)
const stockSearch = ref('')
let stockTimer = null
function onStockSearch(q) {
  stockSearch.value = q || ''
  clearTimeout(stockTimer)
  stockTimer = setTimeout(async () => {
    if (!q || q.length < 1) { stockOptions.value = []; return }
    stockLoading.value = true
    try {
      stockOptions.value = await $api.get('/inventory/stocks/', {
        params: { search: q, is_active: true, page_size: 20 },
      }).then(r => r.data?.results || r.data || [])
    } catch { stockOptions.value = [] }
    finally { stockLoading.value = false }
  }, 250)
}
function onAddStock(s) {
  if (!s) return
  if (form.value.lines.find(l => l.stock === s.id)) {
    showSnack(`${s.medication_name} is already on this transfer`, 'warning')
    picker.value = null
    return
  }
  form.value.lines.push({
    stock: s.id, _name: s.medication_name, _cost: Number(s.cost_price) || 0,
    available: Number(s.total_quantity ?? 0), quantity: 1,
  })
  picker.value = null
  stockOptions.value = []
}

// ── Load ────────────────────────────────────────────────────────────────
async function load() {
  loading.value = true
  try {
    const [t, b, s] = await Promise.all([
      $api.get('/inventory/transfers/', { params: { page_size: 500 } })
        .then(r => r.data?.results || r.data || []),
      $api.get(branchesApi.value).then(r => r.data?.results || r.data || []).catch(() => []),
      $api.get('/inventory/transfers/stats/').then(r => r.data).catch(() => null),
    ])
    transfers.value = t
    branches.value = b
    stats.value = s
  } catch { showSnack('Failed to load transfers', 'error') }
  finally { loading.value = false }
}

function openCreate() {
  form.value = { source_branch: null, dest_branch: null, notes: '', lines: [] }
  stockOptions.value = []
  createDialog.value = true
}

async function saveTransfer(submit) {
  if (!canSave.value) return
  saving.value = true
  try {
    const payload = {
      source_branch: form.value.source_branch,
      dest_branch: form.value.dest_branch,
      notes: form.value.notes,
      lines: form.value.lines.map(l => ({ stock: l.stock, quantity: Number(l.quantity) })),
    }
    const created = await $api.post('/inventory/transfers/', payload).then(r => r.data)
    if (submit) await $api.post(`/inventory/transfers/${created.id}/submit/`)
    showSnack(submit ? `${created.reference} submitted for approval` : `${created.reference} saved as draft`, 'success')
    createDialog.value = false
    await load()
  } catch (e) {
    const d = e?.response?.data
    if (d?.lines || d?.dest_branch) {
      const first = Object.values(d)[0]
      showSnack(Array.isArray(first) ? first[0] : String(first), 'error')
    } else {
      showSnack(d?.detail || 'Failed to save transfer', 'error')
    }
  } finally { saving.value = false }
}

// ── Detail / timeline ───────────────────────────────────────────────────
async function openDetail(t) {
  try {
    active.value = await $api.get(`/inventory/transfers/${t.id}/`).then(r => r.data)
    detailDialog.value = true
  } catch { showSnack('Failed to load transfer', 'error') }
}

const timeline = computed(() => {
  const a = active.value
  if (!a) return []
  const cancelled = a.status === 'cancelled'
  const done = a.status === 'completed'
  return [
    { key: 'requested', label: 'Requested', icon: 'mdi-file-document-outline',
      color: 'primary', done: true,
      meta: `${a.requested_by_name ? a.requested_by_name + ' · ' : ''}${formatDateTime(a.requested_at)}` },
    { key: 'shipped', label: 'Approved & Shipped', icon: 'mdi-truck-fast-outline',
      color: 'info', done: !!a.shipped_at,
      meta: a.shipped_at ? `${a.approved_by_name ? a.approved_by_name + ' · ' : ''}${formatDateTime(a.shipped_at)}` : 'pending' },
    { key: 'received', label: cancelled ? 'Cancelled' : 'Received', icon: cancelled ? 'mdi-cancel' : 'mdi-package-down',
      color: cancelled ? 'error' : 'success', done: cancelled ? true : done,
      meta: cancelled ? 'cancelled before receipt'
        : a.received_at ? `${a.received_by_name ? a.received_by_name + ' · ' : ''}${formatDateTime(a.received_at)}` : 'pending' },
  ]
})

// ── Actions ─────────────────────────────────────────────────────────────
async function submitTransfer(t) {
  try {
    await $api.post(`/inventory/transfers/${t.id}/submit/`)
    showSnack(`${t.reference} submitted`, 'success')
    detailDialog.value = false
    await load()
  } catch (e) { showSnack(e?.response?.data?.detail || 'Failed', 'error') }
}

async function approve(t) {
  try {
    await $api.post(`/inventory/transfers/${t.id}/approve/`)
    showSnack(`${t.reference} approved — stock deducted from ${t.source_branch_name}`, 'success')
    detailDialog.value = false
    await load()
  } catch (e) {
    const d = e?.response?.data
    if (d?.shortages?.length) {
      showSnack(`Insufficient stock: ${d.shortages.map(s => `${s.stock} (need ${s.requested}, have ${s.available})`).join(', ')}`, 'error')
    } else {
      showSnack(d?.detail || 'Failed to approve', 'error')
    }
  }
}

function openReceive(t) {
  // Fetch the fresh detail so shipped_at / line values are current
  $api.get(`/inventory/transfers/${t.id}/`).then(r => {
    active.value = r.data
    receiveLines.value = (r.data.lines || []).map(l => ({
      id: l.id,
      stock_name: l.stock_name,
      stock_unit: l.stock_unit,
      quantity: l.quantity,
      quantity_received: l.quantity,
      notes: l.notes || '',
      _cost: l.quantity > 0 ? (Number(l.line_value) || 0) / l.quantity : 0,
    }))
    detailDialog.value = false
    receiveDialog.value = true
  }).catch(() => showSnack('Failed to load transfer', 'error'))
}

const inTransitHours = computed(() => {
  const a = active.value
  if (!a?.shipped_at) return null
  const hours = Math.round((Date.now() - new Date(a.shipped_at).getTime()) / 3600000)
  return hours >= 0 ? hours : null
})

function lineState(l) {
  const v = (Number(l.quantity_received) || 0) - l.quantity
  if (l.quantity_received > l.quantity) {
    return { label: 'Exceeds sent', color: 'error', icon: 'mdi-alert', cls: 'receive-line--error' }
  }
  if (v === 0) return { label: 'Complete', color: 'success', icon: 'mdi-check', cls: '' }
  if (Number(l.quantity_received) === 0) {
    return { label: 'Missing', color: 'error', icon: 'mdi-close', cls: 'receive-line--missing' }
  }
  return { label: `Short ${-v}`, color: 'amber', icon: 'mdi-alert', cls: 'receive-line--short' }
}

const receiveSummary = computed(() => {
  let sent = 0, received = 0, value = 0, sentValue = 0
  for (const l of receiveLines.value) {
    sent += l.quantity
    sentValue += l.quantity * l._cost
    const r = Number(l.quantity_received) || 0
    received += r
    value += r * l._cost
  }
  return { sent, received, variance: received - sent, value, discrepancyValue: value - sentValue }
})
const receiveValid = computed(() =>
  receiveLines.value.every(l => {
    const r = Number(l.quantity_received)
    return Number.isFinite(r) && r >= 0 && r <= l.quantity
  }))

function receiveAll() {
  receiveLines.value.forEach(l => { l.quantity_received = l.quantity; l.notes = '' })
}

async function confirmReceive() {
  if (!active.value || !receiveValid.value) return
  saving.value = true
  try {
    await $api.post(`/inventory/transfers/${active.value.id}/receive/`, {
      lines: receiveLines.value.map(l => ({
        id: l.id,
        quantity_received: Number(l.quantity_received),
        ...(l.notes ? { notes: l.notes } : {}),
      })),
    })
    const v = receiveSummary.value.variance
    showSnack(
      `${active.value.reference} received — ${receiveSummary.value.received} unit(s) booked into ${active.value.dest_branch_name}` +
      (v < 0 ? ` (shortfall ${-v})` : ''),
      'success',
    )
    receiveDialog.value = false
    await load()
  } catch (e) { showSnack(e?.response?.data?.detail || 'Failed to receive', 'error') }
  finally { saving.value = false }
}

function cancelTransfer(t) {
  active.value = t
  cancelDialog.value = true
}
async function doCancelTransfer() {
  if (!active.value) return
  saving.value = true
  try {
    await $api.post(`/inventory/transfers/${active.value.id}/cancel/`)
    showSnack(`${active.value.reference} cancelled`, 'success')
    cancelDialog.value = false
    detailDialog.value = false
    await load()
  } catch (e) { showSnack(e?.response?.data?.detail || 'Failed to cancel', 'error') }
  finally { saving.value = false }
}

// ── Exports ──────────────────────────────────────────────────────────────
async function printTransfer(t) {
  try {
    const blob = (await $api.get(`/inventory/transfers/${t.id}/pdf/`, { responseType: 'blob' })).data
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `transfer_${t.reference}.pdf`
    a.click()
    URL.revokeObjectURL(url)
  } catch { showSnack('Failed to generate PDF', 'error') }
}

async function exportCsv() {
  try {
    const params = {}
    if (statusFilter.value !== 'all') params.status = statusFilter.value
    if (sourceFilter.value) params.source_branch = sourceFilter.value
    if (destFilter.value) params.dest_branch = destFilter.value
    if (search.value) params.search = search.value
    if (effectiveFrom.value) params.from_date = effectiveFrom.value
    if (effectiveTo.value) params.to_date = effectiveTo.value
    const blob = (await $api.get('/inventory/transfers/export/', { params, responseType: 'blob' })).data
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `stock_transfers_${new Date().toISOString().slice(0, 10)}.csv`
    a.click()
    URL.revokeObjectURL(url)
  } catch { showSnack('Export failed', 'error') }
}

// ── Presentation helpers ─────────────────────────────────────────────────
function statusLabel(s) {
  return ({ draft: 'Draft', requested: 'Requested', in_transit: 'In Transit',
            completed: 'Completed', cancelled: 'Cancelled' })[s] || s
}
function statusColor(s) {
  return ({ draft: 'grey', requested: 'amber', in_transit: 'cyan',
            completed: 'success', cancelled: 'error' })[s] || 'grey'
}
function statusIcon(s) {
  return ({ draft: 'mdi-pencil', requested: 'mdi-clock', in_transit: 'mdi-truck-fast',
            completed: 'mdi-check-all', cancelled: 'mdi-cancel' })[s] || 'mdi-circle-outline'
}
function formatDateTime(d) {
  return d ? new Date(d).toLocaleString(undefined, { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }) : ''
}
function showSnack(text, color = 'success') { Object.assign(snack, { show: true, color, text }) }

onMounted(load)
</script>

<style scoped>
.kpi-card { transition: transform 0.15s ease, box-shadow 0.15s ease; border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.kpi-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.06); }

.lines-table { border: 1px solid rgba(var(--v-theme-on-surface), 0.08); border-radius: 10px; }
.lines-table thead th {
  font-size: 11px; text-transform: uppercase; letter-spacing: 0.06em; color: rgba(var(--v-theme-on-surface), 0.6);
  background: rgba(var(--v-theme-primary), 0.05); border-bottom: 2px solid rgba(var(--v-theme-primary), 0.2);
  padding: 8px 12px; white-space: nowrap;
}
.lines-table tbody td { padding: 8px 12px; border-bottom: 1px solid rgba(0,0,0,0.05); }
.lines-table tbody tr.row-over { background: rgba(var(--v-theme-error), 0.06); }

.notes-box { background: rgba(var(--v-theme-on-surface), 0.04); }

/* Receive modal */
.receive-hero {
  background: linear-gradient(135deg, #0e7490 0%, #0891b2 55%, #06b6d4 100%);
  border-radius: 12px 12px 0 0;
}
.receive-line {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.1);
  border-radius: 12px;
  background: rgba(var(--v-theme-surface), 0.6);
}
.receive-line--short { border-color: rgba(var(--v-theme-warning), 0.55); background: rgba(var(--v-theme-warning), 0.06); }
.receive-line--missing { border-color: rgba(var(--v-theme-error), 0.55); background: rgba(var(--v-theme-error), 0.06); }
.receive-line--error { border-color: rgba(var(--v-theme-error), 0.8); }
.receive-qty { max-width: 110px; }
.receive-note { flex-grow: 1; }
.receive-summary {
  border: 1px solid rgba(var(--v-theme-primary), 0.2);
  border-radius: 12px;
  background: rgba(var(--v-theme-primary), 0.04);
}

/* Timeline */
.timeline-wrap { overflow-x: auto; }
.step-node { min-width: 150px; }
.step-meta { max-width: 150px; line-height: 1.2; font-size: 11px; }
.step-connector {
  flex: 1; height: 2px; min-width: 24px; margin: 0 4px 34px;
  background: rgba(var(--v-theme-on-surface), 0.12); border-radius: 2px;
}
.step-connector--done { background: rgba(var(--v-theme-primary), 0.5); }
</style>
