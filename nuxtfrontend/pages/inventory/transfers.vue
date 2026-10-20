<template>
  <v-container fluid class="pa-3 pa-md-5 trf-page">

    <!-- ═════════════════════════ HERO ═════════════════════════ -->
    <div class="trf-hero mb-4" :style="heroTheme">
      <span class="trf-hero-glow" />
      <span class="trf-hero-glow trf-hero-glow-2" />

      <div class="d-flex flex-wrap align-center justify-space-between ga-3">
        <div class="d-flex align-center" style="gap:16px">
          <div class="trf-hero-icon">
            <v-icon size="30">mdi-truck-delivery-outline</v-icon>
          </div>
          <div>
            <div class="trf-eyebrow">
              <v-icon size="11">mdi-circle</v-icon>
              INVENTORY · LOGISTICS
            </div>
            <h1 class="trf-title">Stock Transfers</h1>
            <div class="trf-sub">
              Move stock between warehouses with approvals, live tracking and receipt verification
              <span v-if="branchStore.currentBranch"> · {{ branchStore.currentBranch.name }}</span>
            </div>
          </div>
        </div>

        <div class="d-flex flex-wrap align-center ga-2">
          <v-btn
            icon="mdi-refresh"
            variant="text"
            size="small"
            class="trf-hero-iconbtn"
            title="Refresh"
            :loading="loading"
            @click="load"
          />
          <v-btn
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none trf-hero-btn-glass"
            prepend-icon="mdi-transfer-right"
            :to="suggestionsPath"
          >Suggestions</v-btn>
          <v-btn
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none trf-hero-btn-glass"
            prepend-icon="mdi-tune-variant"
            :to="optimizePath"
          >Optimize</v-btn>
          <v-btn
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none trf-hero-btn-glass"
            prepend-icon="mdi-chart-box-outline"
            :to="analyticsPath"
          >Analytics</v-btn>
          <v-btn
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none trf-hero-btn-glass"
            prepend-icon="mdi-file-delimited-outline"
            :loading="exporting"
            @click="exportCsv"
          >Export CSV</v-btn>
          <v-btn
            variant="flat"
            elevation="0"
            rounded="lg"
            class="text-none trf-hero-btn-strong"
            prepend-icon="mdi-plus"
            @click="openCreate"
          >New Transfer</v-btn>
        </div>
      </div>

      <!-- Live pipeline summary -->
      <div class="trf-hero-facts">
        <div class="trf-hero-fact">
          <div class="trf-hero-fact-value">{{ statusCounts.requested }}</div>
          <div class="trf-hero-fact-label">awaiting approval</div>
        </div>
        <span class="trf-hero-divider" />
        <div class="trf-hero-fact">
          <div class="trf-hero-fact-value">{{ statusCounts.in_transit }}</div>
          <div class="trf-hero-fact-label">in transit</div>
        </div>
        <span class="trf-hero-divider" />
        <div class="trf-hero-fact">
          <div class="trf-hero-fact-value">{{ formatMoney(inTransitValue) }}</div>
          <div class="trf-hero-fact-label">value on the road</div>
        </div>
        <span class="trf-hero-divider trf-hero-divider-lg" />
        <div class="trf-hero-fact">
          <div class="trf-hero-fact-value">{{ transfers.length }}</div>
          <div class="trf-hero-fact-label">transfers in view</div>
        </div>
      </div>
    </div>

    <!-- ═════════════════════════ KPIs ═════════════════════════ -->
    <v-row dense class="mb-4">
      <v-col v-for="k in kpis" :key="k.title" cols="6" sm="4" md="4" lg="2">
        <KpiTile
          :title="k.title"
          :value="k.value"
          :sub="k.sub"
          :icon="k.icon"
          :color="k.color"
          :hint="k.hint"
          :spark="k.spark"
          flat
        />
      </v-col>
    </v-row>

    <!-- ═════════════════════════ TOOLBAR ═════════════════════════ -->
    <v-card rounded="xl" border class="mb-3 trf-toolbar">
      <!-- Search + view -->
      <div class="d-flex flex-wrap align-center ga-3 pa-3">
        <v-text-field
          v-model="search"
          placeholder="Search reference, warehouse, requester or notes…"
          prepend-inner-icon="mdi-magnify"
          density="comfortable"
          variant="solo-filled"
          rounded="lg"
          flat
          bg-color="surface"
          hide-details
          clearable
          class="trf-search"
        />

        <v-chip-group
          v-if="viewMode === 'list'"
          :model-value="statusFilter"
          selected-class="text-primary"
          mandatory
          class="trf-status-chips"
          @update:model-value="setStatus"
        >
          <v-chip
            v-for="s in statusChips"
            :key="s.value"
            :value="s.value"
            size="small"
            rounded="lg"
            variant="tonal"
            class="text-none"
          >
            <v-icon v-if="s.icon" start size="15">{{ s.icon }}</v-icon>
            {{ s.label }}
            <span class="ml-1 font-weight-bold">{{ s.count }}</span>
          </v-chip>
        </v-chip-group>

        <v-spacer class="d-none d-md-flex" />

        <v-btn-toggle
          v-model="viewMode"
          mandatory
          density="comfortable"
          rounded="lg"
          variant="outlined"
          color="primary"
        >
          <v-btn value="board" icon="mdi-view-column-outline" size="small" title="Board view" />
          <v-btn value="list" icon="mdi-format-list-bulleted" size="small" title="List view" />
        </v-btn-toggle>
      </div>

      <v-divider />

      <!-- Date range + warehouses -->
      <div class="d-flex flex-wrap align-center ga-2 pa-3">
        <v-chip-group v-model="datePreset" selected-class="text-primary" mandatory class="trf-date-chips">
          <v-chip
            v-for="d in datePresets"
            :key="d.value"
            :value="d.value"
            size="small"
            rounded="lg"
            variant="tonal"
            class="text-none"
          >{{ d.label }}</v-chip>
        </v-chip-group>

        <v-spacer class="d-none d-lg-flex" />

        <v-select
          v-model="sourceFilter"
          :items="branchFilterItems"
          item-title="name"
          item-value="id"
          label="From warehouse"
          density="compact"
          variant="outlined"
          rounded="lg"
          hide-details
          clearable
          prepend-inner-icon="mdi-warehouse"
          class="trf-select"
        />
        <v-select
          v-model="destFilter"
          :items="branchFilterItems"
          item-title="name"
          item-value="id"
          label="To warehouse"
          density="compact"
          variant="outlined"
          rounded="lg"
          hide-details
          clearable
          prepend-inner-icon="mdi-map-marker-radius"
          class="trf-select"
        />
        <v-btn
          variant="text"
          size="small"
          color="error"
          class="text-none"
          prepend-icon="mdi-filter-remove-outline"
          :disabled="!hasActiveFilters"
          @click="clearFilters"
        >Clear</v-btn>
      </div>

      <!-- Custom dates -->
      <template v-if="datePreset === 'custom'">
        <v-divider />
        <div class="d-flex flex-wrap align-center ga-2 pa-3">
          <v-text-field
            v-model="fromDate"
            type="date"
            label="From date"
            density="compact"
            variant="outlined"
            rounded="lg"
            hide-details
            clearable
            prepend-inner-icon="mdi-calendar-start"
            class="trf-date-field"
          />
          <v-text-field
            v-model="toDate"
            type="date"
            label="To date"
            density="compact"
            variant="outlined"
            rounded="lg"
            hide-details
            clearable
            prepend-inner-icon="mdi-calendar-end"
            class="trf-date-field"
          />
          <span class="text-caption text-medium-emphasis">{{ dateFilterSummary }}</span>
        </div>
      </template>

      <!-- Active filters -->
      <template v-if="activeFilterChips.length">
        <v-divider />
        <div class="d-flex flex-wrap align-center ga-2 pa-3">
          <span class="text-caption text-medium-emphasis mr-1">Active:</span>
          <v-chip
            v-for="f in activeFilterChips"
            :key="f.key"
            size="small"
            rounded="lg"
            color="primary"
            variant="tonal"
            closable
            @click:close="f.clear()"
          >{{ f.label }}</v-chip>
          <v-spacer />
          <span class="text-caption text-medium-emphasis">
            <strong>{{ filtered.length }}</strong> of {{ transfers.length }} transfers
          </span>
        </div>
      </template>
    </v-card>

    <!-- ═════════════════════════ BOARD VIEW ═════════════════════════ -->
    <div v-if="viewMode === 'board'" class="trf-board">
      <section v-for="col in boardColumns" :key="col.status" class="trf-col">
        <header class="trf-col-head">
          <span class="trf-col-dot" :style="{ background: col.color }" />
          <div class="trf-col-title">{{ col.label }}</div>
          <v-chip size="x-small" variant="tonal" :color="col.color" class="font-weight-bold">
            {{ col.items.length }}
          </v-chip>
          <v-spacer />
          <span class="trf-col-value">{{ formatMoney(col.value) }}</span>
        </header>

        <div class="trf-col-body">
          <div
            v-for="t in col.items"
            :key="t.id"
            class="trf-card"
            @click="openDetail(t)"
          >
            <div class="d-flex align-center justify-space-between ga-2">
              <div class="trf-card-ref">{{ t.reference }}</div>
              <span class="trf-status" :class="`trf-status-${t.status}`">
                <v-icon size="12">{{ statusIcon(t.status) }}</v-icon>
                {{ statusLabel(t.status) }}
              </span>
            </div>

            <div class="trf-card-route mt-2">
              <span class="trf-wh-chip">{{ t.source_branch_name }}</span>
              <v-icon size="14" class="trf-route-arrow">mdi-arrow-right</v-icon>
              <span class="trf-wh-chip trf-wh-chip-dest">{{ t.dest_branch_name }}</span>
            </div>

            <div class="d-flex align-center justify-space-between mt-3">
              <div class="text-caption text-medium-emphasis">
                {{ itemsLabel(t.total_items) }} · {{ unitsLabel(t.total_quantity) }}
              </div>
              <div class="trf-card-value">{{ formatMoney(t.total_value) }}</div>
            </div>

            <v-progress-linear
              :model-value="stageInfo(t).pct"
              :color="stageInfo(t).color"
              height="5"
              rounded
              class="mt-2"
            />

            <div class="d-flex align-center justify-space-between mt-2">
              <div class="d-flex align-center ga-2 text-caption text-medium-emphasis" style="min-width:0">
                <v-icon size="13">mdi-account-outline</v-icon>
                <span class="text-truncate">{{ t.requested_by_name || '—' }}</span>
              </div>
              <div class="d-flex align-center ga-1">
                <span v-if="isAtRisk(t)" class="trf-risk" title="This transfer is taking longer than expected">
                  <v-icon size="11">mdi-alert</v-icon>
                  {{ ageLabel(t.requested_at) }}
                </span>
                <span v-else class="text-caption text-medium-emphasis">{{ ageLabel(t.requested_at) }} old</span>

                <v-menu offset="4" location="bottom end">
                  <template #activator="{ props: mp }">
                    <v-btn
                      v-bind="mp"
                      icon="mdi-dots-vertical"
                      variant="text"
                      size="x-small"
                      @click.stop
                    />
                  </template>
                  <v-list density="compact" min-width="210">
                    <v-list-item prepend-icon="mdi-eye-outline" title="View details" @click="openDetail(t)" />
                    <v-list-item
                      v-if="t.status === 'draft'"
                      prepend-icon="mdi-pencil-outline"
                      title="Edit transfer"
                      @click="openEdit(t)"
                    />
                    <v-list-item
                      v-if="t.status === 'draft'"
                      prepend-icon="mdi-send-outline"
                      title="Submit for approval"
                      @click="submitTransfer(t)"
                    />
                    <v-list-item
                      v-if="t.status === 'requested' && canApprove"
                      prepend-icon="mdi-check-bold"
                      title="Approve and ship"
                      @click="approve(t)"
                    />
                    <v-list-item
                      v-if="t.status === 'in_transit'"
                      prepend-icon="mdi-package-down"
                      title="Receive at destination"
                      @click="openReceive(t)"
                    />
                    <v-list-item
                      prepend-icon="mdi-file-pdf-box"
                      title="Print transfer note"
                      @click="printTransfer(t)"
                    />
                    <v-divider class="my-1" />
                    <v-list-item
                      v-if="canCancel(t)"
                      prepend-icon="mdi-cancel"
                      title="Cancel transfer"
                      base-color="error"
                      @click="cancelTransfer(t)"
                    />
                  </v-list>
                </v-menu>
              </div>
            </div>
          </div>

          <div v-if="!col.items.length" class="trf-col-empty">
            <v-icon size="26" color="grey-lighten-1">{{ col.icon }}</v-icon>
            <div class="text-caption mt-1">No transfers</div>
          </div>
        </div>
      </section>
    </div>

    <!-- ═════════════════════════ LIST VIEW ═════════════════════════ -->
    <v-card v-else rounded="xl" border class="overflow-hidden">
      <div class="trf-table-wrap">
        <table class="trf-table">
          <thead>
            <tr>
              <th class="trf-rownum">#</th>
              <th>Transfer</th>
              <th>Route</th>
              <th>Priority</th>
              <th>Items</th>
              <th class="text-right">Value (cost)</th>
              <th>Requested by</th>
              <th>Progress</th>
              <th>Status</th>
              <th class="text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(t, i) in pagedTransfers" :key="t.id" class="trf-row" @click="openDetail(t)">
              <td class="trf-rownum text-medium-emphasis">{{ rowNumber(i) }}</td>
              <td>
                <div class="d-flex align-center" style="gap:10px">
                  <div class="trf-avatar" :class="`trf-av-${t.status}`">
                    <v-icon size="16">{{ statusIcon(t.status) }}</v-icon>
                  </div>
                  <div style="min-width:0">
                    <div class="font-weight-bold">{{ t.reference }}</div>
                    <div class="text-caption text-medium-emphasis">{{ formatDateTime(t.requested_at) }}</div>
                  </div>
                </div>
              </td>
              <td>
                <div class="trf-route-cell">
                  <span class="trf-wh-chip">{{ t.source_branch_name }}</span>
                  <v-icon size="14" class="trf-route-arrow">mdi-arrow-right</v-icon>
                  <span class="trf-wh-chip trf-wh-chip-dest">{{ t.dest_branch_name }}</span>
                </div>
              </td>
              <td>
                <v-chip
                  size="small"
                  variant="flat"
                  :color="priorityMeta(t.priority).color"
                  class="trf-priority-chip"
                >
                  <v-icon size="13" start :class="priorityIconClass(t.priority)">{{ priorityMeta(t.priority).icon }}</v-icon>
                  {{ priorityMeta(t.priority).label }}
                </v-chip>
              </td>
              <td>
                <div class="font-weight-medium">{{ itemsLabel(t.total_items) }}</div>
                <div class="text-caption text-medium-emphasis">{{ unitsLabel(t.total_quantity) }}</div>
              </td>
              <td class="text-right">
                <div class="font-weight-bold">{{ formatMoney(t.total_value) }}</div>
                <div
                  v-if="t.status === 'completed' && t.total_variance !== 0"
                  class="text-caption"
                  :class="varianceClass(t.total_variance)"
                >{{ signed(t.total_variance) }} variance</div>
              </td>
              <td>
                <div class="text-body-2">{{ t.requested_by_name || '—' }}</div>
                <div class="d-flex align-center ga-1 text-caption text-medium-emphasis">
                  <v-icon v-if="isAtRisk(t)" size="12" color="warning">mdi-alert</v-icon>
                  {{ ageLabel(t.requested_at) }} old
                </div>
              </td>
              <td style="min-width: 150px">
                <v-progress-linear
                  :model-value="stageInfo(t).pct"
                  :color="stageInfo(t).color"
                  height="6"
                  rounded
                />
                <div class="text-caption text-medium-emphasis mt-1">{{ stageInfo(t).label }}</div>
              </td>
              <td>
                <span class="trf-status" :class="`trf-status-${t.status}`">
                  <v-icon size="13">{{ statusIcon(t.status) }}</v-icon>
                  {{ statusLabel(t.status) }}
                </span>
              </td>
              <td class="text-right" @click.stop>
                <v-menu offset="4" location="bottom end">
                  <template #activator="{ props: mp }">
                    <v-btn v-bind="mp" icon="mdi-dots-vertical" variant="text" size="small" />
                  </template>
                  <v-list density="compact" min-width="210">
                    <v-list-item prepend-icon="mdi-eye-outline" title="View details" @click="openDetail(t)" />
                    <v-list-item
                      v-if="t.status === 'draft'"
                      prepend-icon="mdi-pencil-outline"
                      title="Edit transfer"
                      @click="openEdit(t)"
                    />
                    <v-list-item
                      v-if="t.status === 'draft'"
                      prepend-icon="mdi-send-outline"
                      title="Submit for approval"
                      @click="submitTransfer(t)"
                    />
                    <v-list-item
                      v-if="t.status === 'requested' && canApprove"
                      prepend-icon="mdi-check-bold"
                      title="Approve and ship"
                      @click="approve(t)"
                    />
                    <v-list-item
                      v-if="t.status === 'in_transit'"
                      prepend-icon="mdi-package-down"
                      title="Receive at destination"
                      @click="openReceive(t)"
                    />
                    <v-list-item prepend-icon="mdi-file-pdf-box" title="Print transfer note" @click="printTransfer(t)" />
                    <v-divider class="my-1" />
                    <v-list-item
                      v-if="canCancel(t)"
                      prepend-icon="mdi-cancel"
                      title="Cancel transfer"
                      base-color="error"
                      @click="cancelTransfer(t)"
                    />
                  </v-list>
                </v-menu>
              </td>
            </tr>
            <tr v-if="!pagedTransfers.length">
              <td colspan="9">
                <div class="text-center pa-8">
                  <v-icon size="52" color="grey-lighten-1">mdi-truck-remove-outline</v-icon>
                  <div class="text-subtitle-1 font-weight-medium mt-3">No transfers match these filters</div>
                  <div class="text-body-2 text-medium-emphasis mt-1">
                    Try a wider date range, clear the warehouse filters, or create a new transfer.
                  </div>
                  <v-btn color="primary" variant="flat" rounded="lg" class="text-none mt-4" prepend-icon="mdi-plus" @click="openCreate">
                    New transfer
                  </v-btn>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <template v-if="filtered.length">
        <v-divider />
        <div class="d-flex flex-wrap align-center pa-3" style="gap:12px">
          <span class="text-caption text-medium-emphasis">
            Showing <strong>{{ rangeStart }}–{{ rangeEnd }}</strong> of
            <strong>{{ filtered.length }}</strong> transfers
          </span>
          <v-spacer />
          <div class="d-flex align-center" style="gap:8px">
            <span class="text-caption text-medium-emphasis">Rows</span>
            <v-select
              v-model="pageSize"
              :items="pageSizeOptions"
              density="compact"
              variant="outlined"
              rounded="lg"
              hide-details
              style="width: 88px"
            />
          </div>
          <v-pagination
            v-if="pageCount > 1"
            v-model="page"
            :length="pageCount"
            :total-visible="5"
            density="comfortable"
            rounded="lg"
            color="primary"
          />
        </div>
      </template>
    </v-card>

    <!-- ═════════════════════════ CREATE WIZARD ═════════════════════════ -->
    <v-dialog v-model="createDialog" max-width="1040" persistent scrollable>
      <v-card rounded="xl" class="overflow-hidden">
        <div class="trf-create-head" :style="heroTheme">
          <span class="trf-hero-glow" />
          <div class="d-flex align-center flex-wrap ga-2 text-white">
            <v-icon size="22">{{ editingId ? 'mdi-pencil-outline' : 'mdi-swap-horizontal-bold' }}</v-icon>
            <span class="text-h6 font-weight-bold">{{ editingId ? 'Edit stock transfer' : 'New stock transfer' }}</span>
            <v-chip v-if="editingId" size="small" variant="flat" class="trf-head-chip">{{ editingReference }}</v-chip>
            <v-chip size="small" variant="flat" class="trf-head-chip">{{ createStep + 1 }} / 5</v-chip>
            <v-spacer />
            <v-btn icon="mdi-close" variant="text" size="small" class="trf-hero-iconbtn" @click="createDialog = false" />
          </div>
          <div class="text-caption mt-1" style="opacity: .85">
            {{ editingId
              ? 'Update the route, items or logistics details for this draft.'
              : 'Choose the route, add items and submit for approval — stock moves only after sign-off.' }}
          </div>
        </div>

        <!-- Step rail -->
        <div class="trf-steps px-4 pt-4">
          <template v-for="(s, i) in createSteps" :key="s.key">
            <div class="trf-step" :class="{ 'trf-step-active': stepActive(i), 'trf-step-done': stepDone(i) }">
              <div class="trf-step-dot">
                <v-icon size="15">{{ stepIcon(s, i) }}</v-icon>
              </div>
              <div class="trf-step-text">{{ s.label }}</div>
            </div>
            <div v-if="hasStepLine(i)" class="trf-step-line" :class="{ 'trf-step-line-done': stepDone(i) }" />
          </template>
        </div>

        <v-card-text class="pt-3">
          <!-- ── STEP 1: ROUTE ── -->
          <div v-if="createStep === 0">
            <div class="trf-section-head">
              <span class="trf-section-index">01</span>
              <div>
                <div class="text-subtitle-1 font-weight-bold">Choose the route</div>
                <div class="text-caption text-medium-emphasis">Pick a source warehouse and the destination that needs the stock.</div>
              </div>
              <v-spacer />
              <v-btn
                variant="tonal"
                size="small"
                rounded="lg"
                class="text-none"
                prepend-icon="mdi-swap-horizontal"
                :disabled="!form.source_branch && !form.dest_branch"
                @click="swapBranches"
              >Swap</v-btn>
            </div>

            <v-alert v-if="!branches.length" type="info" variant="tonal" rounded="lg" density="compact" class="mt-3">
              No warehouses are available. Add a branch before creating transfers.
            </v-alert>

            <v-row dense class="mt-1">
              <v-col cols="12" md="6">
                <div class="trf-pick-label">
                  <v-icon size="13">mdi-warehouse</v-icon> FROM WAREHOUSE
                </div>
                <div class="trf-wh-grid">
                  <button
                    v-for="b in branches"
                    :key="`src-${b.id}`"
                    type="button"
                    class="trf-wh-card"
                    :class="{ 'trf-wh-selected': form.source_branch === b.id }"
                    @click="selectSource(b.id)"
                  >
                    <div class="trf-wh-card-head">
                      <div class="trf-wh-icon"><v-icon size="19">mdi-warehouse</v-icon></div>
                      <v-chip v-if="b.is_main" size="x-small" variant="tonal" color="primary">Main</v-chip>
                      <v-icon v-if="form.source_branch === b.id" class="ml-auto" color="success" size="19">mdi-check-circle</v-icon>
                    </div>
                    <div class="trf-wh-name">{{ b.name }}</div>
                    <div class="trf-wh-meta">{{ b.place_name || b.address || 'Warehouse' }}</div>
                    <div class="trf-wh-stock">
                      <v-icon size="12">mdi-package-variant</v-icon>
                      {{ b.stock_count ?? 0 }} stock items
                    </div>
                  </button>
                </div>
              </v-col>

              <v-col cols="12" md="6">
                <div class="trf-pick-label trf-pick-label-dest">
                  <v-icon size="13">mdi-map-marker-radius</v-icon> TO WAREHOUSE
                </div>
                <div class="trf-wh-grid">
                  <button
                    v-for="b in destBranches"
                    :key="`dst-${b.id}`"
                    type="button"
                    class="trf-wh-card trf-wh-card-dest"
                    :class="{ 'trf-wh-selected trf-wh-selected-dest': form.dest_branch === b.id }"
                    @click="selectDest(b.id)"
                  >
                    <div class="trf-wh-card-head">
                      <div class="trf-wh-icon trf-wh-icon-dest"><v-icon size="19">mdi-store-marker-outline</v-icon></div>
                      <v-chip v-if="b.is_main" size="x-small" variant="tonal" color="primary">Main</v-chip>
                      <v-icon v-if="form.dest_branch === b.id" class="ml-auto" color="success" size="19">mdi-check-circle</v-icon>
                    </div>
                    <div class="trf-wh-name">{{ b.name }}</div>
                    <div class="trf-wh-meta">{{ b.place_name || b.address || 'Warehouse' }}</div>
                    <div class="trf-wh-stock">
                      <v-icon size="12">mdi-package-variant</v-icon>
                      {{ b.stock_count ?? 0 }} stock items
                    </div>
                  </button>
                  <div v-if="!destBranches.length" class="trf-col-empty trf-wh-empty">
                    <v-icon size="24" color="grey-lighten-1">mdi-store-off-outline</v-icon>
                    <div class="text-caption mt-1">Select a source warehouse first</div>
                  </div>
                </div>
              </v-col>
            </v-row>

            <div class="trf-section-head mt-5">
              <span class="trf-section-index">02</span>
              <div>
                <div class="text-subtitle-1 font-weight-bold">Reason for the move</div>
                <div class="text-caption text-medium-emphasis">This is recorded on the transfer note and audit trail.</div>
              </div>
            </div>

            <v-textarea
              v-model="form.notes"
              label="Notes / reason for transfer *"
              rows="2"
              auto-grow
              variant="outlined"
              density="comfortable"
              class="mt-2"
              :rules="[v => !!v?.trim() || 'Reason for transfer is required']"
            />
            <div class="d-flex flex-wrap ga-1 mt-1">
              <v-chip
                v-for="r in transferReasons"
                :key="r"
                size="small"
                variant="outlined"
                color="primary"
                class="text-none"
                @click="form.notes = r"
              >{{ r }}</v-chip>
            </div>
          </div>

          <!-- ── STEP 2: ITEMS ── -->
          <div v-else-if="createStep === 1">
            <div class="trf-section-head">
              <span class="trf-section-index">03</span>
              <div>
                <div class="text-subtitle-1 font-weight-bold">Add the items</div>
                <div class="text-caption text-medium-emphasis">
                  Search the source warehouse stock and set the quantity to send.
                </div>
              </div>
              <v-spacer />
              <v-chip size="small" variant="tonal" color="primary" prepend-icon="mdi-warehouse">
                {{ sourceBranchName || 'No source selected' }}
              </v-chip>
            </div>

            <!-- Search mode: by item name, or by batch number -->
            <div class="trf-mode-switch mt-3">
              <button
                type="button"
                class="trf-mode-btn"
                :class="{ 'is-on': itemSearchMode === 'item' }"
                @click="setSearchMode('item')"
              >
                <v-icon size="16">mdi-pill</v-icon>
                <span>By item</span>
              </button>
              <button
                type="button"
                class="trf-mode-btn"
                :class="{ 'is-on': itemSearchMode === 'batch' }"
                @click="setSearchMode('batch')"
              >
                <v-icon size="16">mdi-barcode-scan</v-icon>
                <span>By batch number</span>
              </button>
            </div>

            <v-autocomplete
              v-if="itemSearchMode === 'item'"
              ref="stockPickerRef"
              v-model="picker"
              v-model:search="stockSearch"
              :items="stockOptions"
              :loading="stockLoading"
              :disabled="!form.source_branch"
              item-title="medication_name"
              item-value="id"
              return-object
              label="Search stock by name or barcode…"
              prepend-inner-icon="mdi-magnify"
              variant="outlined"
              density="comfortable"
              rounded="lg"
              clearable
              hide-no-data
              class="mt-3"
              @update:search="onStockSearch"
              @update:model-value="onPickStock"
            >
              <template #item="{ props: ip, item }">
                <v-list-item v-bind="ip">
                  <v-list-item-subtitle>
                    {{ item.raw.generic_name || item.raw.barcode || 'Inventory item' }}
                    · On hand {{ formatQty(item.raw.total_quantity) }}
                    {{ item.raw.unit_abbreviation || item.raw.unit_name || '' }}
                    · {{ availableBatchCount(item.raw) }} batch(es)
                    · Cost {{ formatMoney(item.raw.cost_price) }}
                  </v-list-item-subtitle>
                </v-list-item>
              </template>
            </v-autocomplete>

            <!-- ── Batch-number search ─────────────────────────────────── -->
            <div v-else class="mt-3">
              <v-text-field
                v-model="batchSearch"
                :loading="batchSearchLoading"
                :disabled="!form.source_branch"
                label="Search by batch number, item or barcode…"
                prepend-inner-icon="mdi-barcode"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                clearable
                hide-details
                @update:model-value="onBatchSearch"
              />

              <div v-if="!form.source_branch" class="text-caption text-medium-emphasis mt-2">
                Choose a source warehouse in the previous step to search its batches.
              </div>

              <div v-else-if="!batchSearch.trim()" class="trf-bs-hint">
                <v-icon size="16">mdi-information-outline</v-icon>
                <span>Type a batch number (e.g. <code>PCM-2402</code>) to list every item held in that batch.</span>
              </div>

              <div
                v-else-if="!batchSearchLoading && !batchSearchResults.length"
                class="trf-bs-hint"
              >
                <v-icon size="16">mdi-magnify-close</v-icon>
                <span>No batches matched “{{ batchSearch }}” at this warehouse.</span>
              </div>

              <div v-if="batchSearchResults.length" class="trf-bp mt-2">
                <div class="trf-bp-head">
                  <div class="trf-bp-head-icon">
                    <v-icon size="20">mdi-barcode-scan</v-icon>
                  </div>
                  <div class="trf-bp-head-text">
                    <div class="trf-bp-title">
                      {{ batchSearchResults.length }} batch{{ batchSearchResults.length === 1 ? '' : 'es' }} found
                    </div>
                    <div class="trf-bp-sub">
                      {{ batchSearchItemCount }} item{{ batchSearchItemCount === 1 ? '' : 's' }}
                      <span class="trf-bp-sep">•</span>
                      {{ formatQty(batchSearchTotalUnits) }} units on hand
                    </div>
                  </div>
                  <v-spacer />
                  <v-btn
                    size="small"
                    variant="tonal"
                    color="primary"
                    rounded="lg"
                    prepend-icon="mdi-check-all"
                    class="text-none"
                    @click="selectAllBatchSearch"
                  >Select all</v-btn>
                  <v-btn
                    size="small"
                    variant="text"
                    color="grey"
                    rounded="lg"
                    class="text-none"
                    @click="clearBatchSearchSelection"
                  >Clear</v-btn>
                </div>

                <div class="trf-bp-thead">
                  <span />
                  <span>Item &amp; batch</span>
                  <span>Expiry</span>
                  <span class="text-right">On hand</span>
                  <span class="text-right">Quantity to send</span>
                </div>

                <div class="trf-bp-tbody">
                  <div
                    v-for="b in batchSearchResults"
                    :key="b.id"
                    class="trf-bp-trow"
                    :class="{ 'is-on': b.selected }"
                    @click="toggleBatchSearchRow(b)"
                  >
                    <div class="trf-bp-check" @click.stop>
                      <v-checkbox-btn
                        v-model="b.selected"
                        density="compact"
                        hide-details
                        color="primary"
                        @update:model-value="onBatchSearchToggle(b)"
                      />
                    </div>

                    <div class="trf-bp-name">
                      <div class="trf-bp-name-main">{{ b.stock_name }}</div>
                      <div class="trf-bp-name-sub trf-bs-sub">
                        <span class="trf-bs-batch">
                          <v-icon size="11">mdi-lot-outline</v-icon>{{ b.batch_number || '—' }}
                        </span>
                        <span class="trf-item-dot">·</span>
                        <span>{{ formatMoney(b.cost_price_per_unit) }}/unit</span>
                      </div>
                    </div>

                    <div class="trf-bp-exp">
                      <v-chip
                        v-if="b.expiry_date"
                        size="x-small"
                        variant="tonal"
                        :color="b.is_expired ? 'error' : isExpiringSoon(b) ? 'warning' : 'default'"
                        class="trf-bp-exp-chip"
                      >{{ formatDate(b.expiry_date) }}</v-chip>
                      <span v-else class="trf-bp-none">No expiry</span>
                    </div>

                    <div class="trf-bp-avail">
                      <span class="trf-bp-avail-num">{{ formatQty(b.quantity_remaining) }}</span>
                      <span class="trf-bp-avail-unit">{{ b.stock_unit || 'units' }}</span>
                    </div>

                    <div class="trf-bp-send" @click.stop>
                      <v-btn
                        icon="mdi-minus"
                        size="x-small"
                        variant="flat"
                        color="surface-variant"
                        :disabled="!b.selected || b.quantity <= 1"
                        @click="b.quantity = Math.max(1, b.quantity - 1)"
                      />
                      <v-text-field
                        v-model.number="b.quantity"
                        type="number"
                        min="1"
                        :max="b.quantity_remaining"
                        :disabled="!b.selected"
                        density="compact"
                        variant="outlined"
                        hide-details
                        class="trf-bp-qty-input"
                        @change="clampBatchSearchQty(b)"
                      />
                      <v-btn
                        icon="mdi-plus"
                        size="x-small"
                        variant="flat"
                        color="surface-variant"
                        :disabled="!b.selected || b.quantity >= b.quantity_remaining"
                        @click="b.quantity = Math.min(b.quantity_remaining, b.quantity + 1)"
                      />
                      <v-btn
                        size="x-small"
                        variant="text"
                        color="primary"
                        class="text-none trf-bp-all"
                        :disabled="!b.selected"
                        title="Take the entire batch"
                        @click="b.quantity = b.quantity_remaining"
                      >All</v-btn>
                    </div>
                  </div>
                </div>

                <div class="trf-bp-foot">
                  <div class="trf-bp-sel">
                    <v-icon size="15">mdi-check-circle-outline</v-icon>
                    <span><strong>{{ batchSearchSelected.length }}</strong> selected</span>
                    <span class="trf-bp-sep">•</span>
                    <span><strong>{{ formatQty(batchSearchSelectedUnits) }}</strong> units</span>
                  </div>
                  <v-spacer />
                  <v-btn
                    color="primary"
                    variant="flat"
                    size="small"
                    rounded="lg"
                    class="text-none"
                    prepend-icon="mdi-check-bold"
                    :disabled="!batchSearchSelected.length"
                    @click="addSelectedBatchSearch"
                  >
                    {{ batchSearchSelected.length
                      ? `Add ${batchSearchSelected.length} item${batchSearchSelected.length === 1 ? '' : 's'}`
                      : 'Select an item' }}
                  </v-btn>
                </div>
              </div>
            </div>

            <div
              v-if="!form.source_branch && itemSearchMode === 'item'"
              class="text-caption text-medium-emphasis mt-2"
            >
              Choose a source warehouse in the previous step to search its stock.
            </div>

            <!-- ── Batch picker drawer ─────────────────────────────────── -->
            <v-expand-transition>
              <div v-if="batchPickerOpen" class="trf-bp mt-3">
                <!-- Header -->
                <div class="trf-bp-head">
                  <div class="trf-bp-head-icon">
                    <v-icon size="20">mdi-package-variant-closed</v-icon>
                  </div>
                  <div class="trf-bp-head-text">
                    <div class="trf-bp-title">{{ batchStock?.medication_name }}</div>
                    <div class="trf-bp-sub">
                      {{ availableBatches.length }} batch{{ availableBatches.length === 1 ? '' : 'es' }}
                      <span class="trf-bp-sep">•</span>
                      {{ formatQty(batchTotalAvailable) }} {{ batchUnitLabel }} on hand
                    </div>
                  </div>
                  <v-spacer />
                  <v-btn
                    v-if="availableBatches.length"
                    size="small"
                    variant="tonal"
                    color="primary"
                    rounded="lg"
                    prepend-icon="mdi-check-all"
                    class="text-none"
                    @click="selectAllBatches"
                  >Select all</v-btn>
                  <v-btn
                    v-if="availableBatches.length"
                    size="small"
                    variant="text"
                    color="grey"
                    rounded="lg"
                    class="text-none"
                    @click="clearBatchSelection"
                  >Clear</v-btn>
                  <v-btn
                    icon="mdi-close"
                    size="small"
                    variant="text"
                    title="Close batch picker"
                    @click="closeBatchPicker"
                  />
                </div>

                <v-alert
                  v-if="!availableBatches.length"
                  type="info"
                  variant="tonal"
                  density="compact"
                  rounded="lg"
                  class="ma-3"
                >
                  No individual batches with remaining stock at the source warehouse.
                  Use “Add full item” to send units regardless of batch.
                </v-alert>

                <template v-else>
                  <!-- Column header -->
                  <div class="trf-bp-thead">
                    <span />
                    <span>Batch / lot</span>
                    <span>Expiry</span>
                    <span class="text-right">On hand</span>
                    <span class="text-right">Quantity to send</span>
                  </div>

                  <!-- Rows -->
                  <div class="trf-bp-tbody">
                    <div
                      v-for="b in availableBatches"
                      :key="b.id"
                      class="trf-bp-trow"
                      :class="{ 'is-on': b.selected }"
                      @click="toggleBatchRow(b)"
                    >
                      <div class="trf-bp-check" @click.stop>
                        <v-checkbox-btn
                          v-model="b.selected"
                          density="compact"
                          hide-details
                          color="primary"
                          @update:model-value="onBatchToggle(b)"
                        />
                      </div>

                      <div class="trf-bp-name">
                        <div class="trf-bp-name-main">{{ b.batch_number || '—' }}</div>
                        <div class="trf-bp-name-sub">
                          {{ formatMoney(b.cost_price_per_unit || batchStock?.cost_price) }} per unit
                        </div>
                      </div>

                      <div class="trf-bp-exp">
                        <v-chip
                          v-if="b.expiry_date"
                          size="x-small"
                          variant="tonal"
                          :color="b.is_expired ? 'error' : isExpiringSoon(b) ? 'warning' : 'default'"
                          class="trf-bp-exp-chip"
                        >
                          {{ formatDate(b.expiry_date) }}
                        </v-chip>
                        <span v-else class="trf-bp-none">No expiry</span>
                      </div>

                      <div class="trf-bp-avail">
                        <span class="trf-bp-avail-num">{{ formatQty(b.quantity_remaining) }}</span>
                        <span class="trf-bp-avail-unit">{{ batchUnitLabel }}</span>
                      </div>

                      <div class="trf-bp-send" @click.stop>
                        <v-btn
                          icon="mdi-minus"
                          size="x-small"
                          variant="flat"
                          color="surface-variant"
                          :disabled="!b.selected || b.quantity <= 1"
                          @click="b.quantity = Math.max(1, b.quantity - 1)"
                        />
                        <v-text-field
                          v-model.number="b.quantity"
                          type="number"
                          min="1"
                          :max="b.quantity_remaining"
                          :disabled="!b.selected"
                          density="compact"
                          variant="outlined"
                          hide-details
                          class="trf-bp-qty-input"
                          @change="clampBatchQty(b)"
                        />
                        <v-btn
                          icon="mdi-plus"
                          size="x-small"
                          variant="flat"
                          color="surface-variant"
                          :disabled="!b.selected || b.quantity >= b.quantity_remaining"
                          @click="b.quantity = Math.min(b.quantity_remaining, b.quantity + 1)"
                        />
                        <v-btn
                          size="x-small"
                          variant="text"
                          color="primary"
                          class="text-none trf-bp-all"
                          :disabled="!b.selected"
                          title="Take the entire batch"
                          @click="b.quantity = b.quantity_remaining"
                        >All</v-btn>
                      </div>
                    </div>
                  </div>

                  <v-alert
                    v-if="batchPickerError"
                    type="error"
                    variant="tonal"
                    density="compact"
                    rounded="lg"
                    class="mx-3 mt-2"
                  >{{ batchPickerError }}</v-alert>

                  <!-- Footer -->
                  <div class="trf-bp-foot">
                    <div class="trf-bp-sel">
                      <v-icon size="15">mdi-check-circle-outline</v-icon>
                      <span><strong>{{ selectedBatchCount }}</strong> selected</span>
                      <span class="trf-bp-sep">•</span>
                      <span><strong>{{ formatQty(selectedBatchUnits) }}</strong> {{ batchUnitLabel }}</span>
                    </div>
                    <v-spacer />
                    <v-btn
                      variant="text"
                      color="grey"
                      size="small"
                      rounded="lg"
                      class="text-none"
                      prepend-icon="mdi-package-plus"
                      :disabled="!batchStock"
                      @click="addFullItem"
                    >Add without batch</v-btn>
                    <v-btn
                      color="primary"
                      variant="flat"
                      size="small"
                      rounded="lg"
                      class="text-none"
                      prepend-icon="mdi-check-bold"
                      :disabled="!selectedBatchCount"
                      @click="addSelectedBatches"
                    >
                      {{ selectedBatchCount
                        ? `Add ${selectedBatchCount} batch${selectedBatchCount === 1 ? '' : 'es'}`
                        : 'Select a batch' }}
                    </v-btn>
                  </div>
                </template>
              </div>
            </v-expand-transition>

            <v-alert
              v-if="shortageWarnings.length"
              type="error"
              variant="tonal"
              density="compact"
              rounded="lg"
              class="mt-3"
            >
              <div v-for="w in shortageWarnings" :key="w" class="text-body-2">{{ w }}</div>
            </v-alert>

            <div v-if="form.lines.length" class="trf-lines mt-3">
              <div class="trf-lines-head">
                <span>Item</span>
                <span class="text-center">Quantity to send</span>
                <span class="text-right">Line value</span>
                <span />
              </div>
              <div
                v-for="(l, i) in form.lines"
                :key="l._key"
                class="trf-item-row"
                :class="{ 'trf-item-over': isOver(l) }"
              >
                <div class="trf-item-main">
                  <div class="trf-item-icon"><v-icon size="17">mdi-package-variant-closed</v-icon></div>
                  <div style="min-width:0">
                    <div class="trf-item-name">{{ l._name }}</div>
                    <div class="trf-item-sub">
                      <span v-if="l._batch_id" class="trf-item-batch">
                        <v-icon size="11">mdi-lot-outline</v-icon>{{ l._batch_no || '—' }}
                      </span>
                      <span v-else class="trf-item-nobatch">No batch</span>
                      <template v-if="l._batch_exp">
                        <span class="trf-item-dot">·</span>
                        <span>Exp {{ formatDate(l._batch_exp) }}</span>
                      </template>
                      <span class="trf-item-dot">·</span>
                      <span>{{ formatQty(l.available) }} available</span>
                      <span class="trf-item-dot">·</span>
                      <span>{{ formatMoney(l._cost) }}/unit</span>
                    </div>
                  </div>
                </div>

                <div class="trf-qty">
                  <v-btn
                    icon="mdi-minus"
                    size="x-small"
                    variant="tonal"
                    :disabled="atMin(l)"
                    @click="stepQty(l, -1)"
                  />
                  <v-text-field
                    v-model.number="l.quantity"
                    type="number"
                    min="1"
                    density="compact"
                    variant="outlined"
                    hide-details
                    class="trf-qty-input"
                    @change="clampQty(l)"
                  />
                  <v-btn
                    icon="mdi-plus"
                    size="x-small"
                    variant="tonal"
                    :disabled="atMax(l)"
                    @click="stepQty(l, 1)"
                  />
                </div>

                <div class="trf-item-value">{{ formatMoney(lineValue(l)) }}</div>
                <v-btn
                  icon="mdi-delete-outline"
                  variant="text"
                  size="small"
                  color="error"
                  title="Remove item"
                  @click="removeLine(i)"
                />
              </div>
            </div>

            <div v-else class="trf-empty-lines mt-3">
              <v-icon size="38" color="grey-lighten-1">mdi-package-variant-plus</v-icon>
              <div class="text-body-2 font-weight-medium mt-2">No items added yet</div>
              <div class="text-caption text-medium-emphasis">Search above to add stock to this transfer.</div>
            </div>

            <div class="trf-summary-strip mt-3">
              <div class="trf-sum-item">
                <span>Items</span>
                <strong>{{ form.lines.length }}</strong>
              </div>
              <div class="trf-sum-item">
                <span>Units</span>
                <strong>{{ totalUnits }}</strong>
              </div>
              <div class="trf-sum-item">
                <span>Value at cost</span>
                <strong>{{ formatMoney(totalValue) }}</strong>
              </div>
            </div>
          </div>

          <!-- ── STEP 3 (index 2): CARGO AND SCHEDULE ── -->
          <div v-else-if="createStep === 2">
            <div class="trf-section-head">
              <span class="trf-section-index">03</span>
              <div>
                <div class="text-subtitle-1 font-weight-bold">Cargo &amp; schedule</div>
                <div class="text-caption text-medium-emphasis">Set the priority, packaging and timelines for this transfer.</div>
              </div>
            </div>

            <!-- Priority selector -->
            <div class="text-caption text-medium-emphasis mt-3 mb-2">Priority level</div>
            <div class="d-flex flex-wrap ga-2">
              <v-card
                v-for="opt in priorityOptions"
                :key="opt.value"
                :color="form.priority === opt.value ? opt.color : 'surface'"
                :variant="form.priority === opt.value ? 'flat' : 'outlined'"
                rounded="lg"
                class="pa-3 cursor-pointer trf-priority-card"
                style="flex:1; min-width:140px; max-width:220px"
                @click="form.priority = opt.value"
              >
                <div class="d-flex align-center ga-2">
                  <v-icon
                    :color="form.priority === opt.value ? 'white' : opt.color"
                    size="20"
                    :class="priorityIconClass(opt.value)"
                  >{{ opt.icon }}</v-icon>
                  <span class="font-weight-bold" :class="form.priority === opt.value ? 'text-white' : ''">{{ opt.label }}</span>
                </div>
                <div class="text-caption mt-1" :class="form.priority === opt.value ? 'text-white' : 'text-medium-emphasis'">
                  {{ opt.desc }}
                </div>
              </v-card>
            </div>

            <!-- Parcel count with chips -->
            <div class="text-caption text-medium-emphasis mt-4 mb-2">Number of parcels / boxes</div>
            <div class="d-flex align-center flex-wrap ga-2">
              <v-chip-group v-model="form.parcel_count" color="primary">
                <v-chip
                  v-for="n in parcelChipOptions"
                  :key="n"
                  :value="n"
                  filter
                  variant="outlined"
                  rounded="lg"
                >{{ n }} {{ n === 1 ? 'box' : 'boxes' }}</v-chip>
              </v-chip-group>
              <v-text-field
                v-model.number="form.parcel_count"
                type="number"
                label="Manual entry"
                prepend-inner-icon="mdi-package-variant-closed"
                density="compact"
                hide-details
                filled
                rounded="lg"
                style="max-width:140px"
                min="0"
              />
            </div>

            <!-- Weight -->
            <div class="text-caption text-medium-emphasis mt-4 mb-2">Weight (if known)</div>
            <v-text-field
              v-model.number="form.weight_kg"
              type="number"
              prepend-inner-icon="mdi-scale"
              label="Total weight in kg"
              density="compact"
              hide-details
              filled
              rounded="lg"
              min="0"
              step="0.01"
              style="max-width:240px"
            />

            <!-- Scheduled pickup & delivery -->
            <div class="d-flex flex-wrap ga-4 mt-4">
              <div style="flex:1; min-width:240px">
                <div class="text-caption text-medium-emphasis mb-2">Scheduled pickup</div>
                <v-text-field
                  v-model="form.scheduled_pickup"
                  type="datetime-local"
                  prepend-inner-icon="mdi-truck-fast"
                  label="Pickup date & time"
                  density="compact"
                  hide-details
                  filled
                  rounded="lg"
                />
              </div>
              <div style="flex:1; min-width:240px">
                <div class="text-caption text-medium-emphasis mb-2">Scheduled delivery</div>
                <v-text-field
                  v-model="form.scheduled_delivery"
                  type="datetime-local"
                  prepend-inner-icon="mdi-package-down"
                  label="Delivery date & time"
                  density="compact"
                  hide-details
                  filled
                  rounded="lg"
                />
              </div>
            </div>

            <v-alert type="info" variant="tonal" rounded="lg" density="compact" class="mt-4">
              These fields are optional. Leave blank if the transfer does not yet have a definite schedule.
            </v-alert>
          </div>

          <!-- ── STEP 4 (index 3): ASSIGNMENT ── -->
          <div v-else-if="createStep === 3">
            <div class="trf-section-head">
              <span class="trf-section-index">04</span>
              <div>
                <div class="text-subtitle-1 font-weight-bold">Assignment</div>
                <div class="text-caption text-medium-emphasis">Choose who will carry this transfer — internal drivers or 3PL partners.</div>
              </div>
            </div>

            <!-- Assignment type toggle -->
            <div class="d-flex flex-wrap ga-3 mt-3">
              <v-card
                :color="form.assignment_type === 'internal' ? 'primary' : 'surface'"
                :variant="form.assignment_type === 'internal' ? 'flat' : 'outlined'"
                rounded="lg"
                class="pa-4 cursor-pointer trf-assign-card"
                style="flex:1; min-width:200px"
                @click="form.assignment_type = 'internal'; form.carrier_id = null"
              >
                <div class="d-flex align-center ga-2">
                  <v-icon :color="form.assignment_type === 'internal' ? 'white' : 'primary'" size="24">mdi-account-group</v-icon>
                  <span class="text-subtitle-2 font-weight-bold" :class="form.assignment_type === 'internal' ? 'text-white' : ''">Internal drivers</span>
                </div>
                <div class="text-caption mt-1" :class="form.assignment_type === 'internal' ? 'text-white' : 'text-medium-emphasis'">
                  Assign your own company driver.
                </div>
              </v-card>

              <v-card
                :color="form.assignment_type === 'carrier' ? 'primary' : 'surface'"
                :variant="form.assignment_type === 'carrier' ? 'flat' : 'outlined'"
                rounded="lg"
                class="pa-4 cursor-pointer trf-assign-card"
                style="flex:1; min-width:200px"
                @click="form.assignment_type = 'carrier'; form.driver_id = null"
              >
                <div class="d-flex align-center ga-2">
                  <v-icon :color="form.assignment_type === 'carrier' ? 'white' : 'primary'" size="24">mdi-truck-fast</v-icon>
                  <span class="text-subtitle-2 font-weight-bold" :class="form.assignment_type === 'carrier' ? 'text-white' : ''">Carriers &amp; 3PL Partners</span>
                </div>
                <div class="text-caption mt-1" :class="form.assignment_type === 'carrier' ? 'text-white' : 'text-medium-emphasis'">
                  Use an external logistics partner.
                </div>
              </v-card>
            </div>

            <!-- Internal driver selection -->
            <div v-if="form.assignment_type === 'internal'" class="mt-4">
              <div class="text-caption text-medium-emphasis mb-2">Select a driver</div>
              <v-autocomplete
                v-model="form.driver_id"
                :items="driverOptions"
                item-title="full_name"
                item-value="id"
                prepend-inner-icon="mdi-account-tie-hat"
                label="Search drivers"
                density="compact"
                filled
                rounded="lg"
                clearable
                hide-details
              >
                <template #item="{ item: i, props: p }">
                  <v-list-item v-bind="p">
                    <template #prepend>
                      <v-icon :color="i.raw.status === 'available' ? 'success' : 'grey'">
                        {{
                          i.raw.status === 'available' ? 'mdi-account-check' : 'mdi-account-off'
                        }}
                      </v-icon>
                    </template>
                    <template #title>
                      <span>{{ i.raw.full_name }}</span>
                      <v-chip size="x-small" variant="flat" class="ml-2" :color="i.raw.status === 'available' ? 'success' : 'grey'">
                        {{ i.raw.status }}
                      </v-chip>
                    </template>
                  </v-list-item>
                </template>
              </v-autocomplete>

              <!-- Driver availability cards -->
              <div class="text-caption text-medium-emphasis mt-4 mb-2">Availability overview</div>
              <div class="d-flex flex-wrap ga-2">
                <v-chip
                  v-for="d in availableDrivers"
                  :key="d.id"
                  size="small"
                  variant="outlined"
                  color="success"
                  rounded="lg"
                  @click="form.driver_id = d.id"
                >
                  <v-icon size="14" class="mr-1">mdi-account-check</v-icon>{{ d.full_name }}
                </v-chip>
                <div v-if="!availableDrivers.length" class="text-caption text-medium-emphasis">
                  No drivers currently available.
                </div>
              </div>

              <!-- Selected driver availability calendar -->
              <div v-if="selectedDriver" class="mt-4">
                <div class="text-caption text-medium-emphasis mb-2">
                  {{ selectedDriver.full_name }} — status
                  <v-chip size="x-small" variant="flat" :color="selectedDriver.status === 'available' ? 'success' : 'grey'">
                    {{ selectedDriver.status }}
                  </v-chip>
                </div>
                <v-sheet rounded="lg" border class="pa-3">
                  <div class="d-flex flex-wrap ga-2 mb-3">
                    <v-chip size="small" variant="outlined" label>
                      <v-icon size="14" class="mr-1">mdi-phone</v-icon>{{ selectedDriver.phone || 'No phone' }}
                    </v-chip>
                    <v-chip size="small" variant="outlined" label>
                      <v-icon size="14" class="mr-1">mdi-license</v-icon>{{ selectedDriver.license_number || 'N/A' }}
                    </v-chip>
                    <v-chip size="small" variant="outlined" label>
                      <v-icon size="14" class="mr-1">mdi-step-forward</v-icon>{{ selectedDriver.total_trips || 0 }} trips
                    </v-chip>
                    <v-chip size="small" variant="outlined" label>
                      <v-icon size="14" class="mr-1">mdi-star</v-icon>{{ selectedDriver.rating || 'N/A' }}
                    </v-chip>
                  </div>
                  <v-alert
                    :type="selectedDriver.status === 'available' ? 'success' : 'warning'"
                    variant="tonal"
                    rounded="lg"
                    density="compact"
                  >
                    {{
                      selectedDriver.status === 'available'
                        ? 'This driver is available and can be assigned.'
                        : 'This driver is currently unavailable.'
                    }}
                  </v-alert>
                </v-sheet>
              </div>
            </div>

            <!-- Carrier selection -->
            <div v-else-if="form.assignment_type === 'carrier'" class="mt-4">
              <div class="text-caption text-medium-emphasis mb-2">Select a carrier / 3PL partner</div>
              <v-autocomplete
                v-model="form.carrier_id"
                :items="carrierOptions"
                item-title="name"
                item-value="id"
                prepend-inner-icon="mdi-truck-fast"
                label="Search carriers"
                density="compact"
                filled
                rounded="lg"
                clearable
                hide-details
              >
                <template #item="{ item: i, props: p }">
                  <v-list-item v-bind="p">
                    <template #prepend>
                      <v-icon>{{ i.raw.is_active ? 'mdi-truck-check' : 'mdi-truck-remove' }}</v-icon>
                    </template>
                    <template #subtitle>
                      <span class="text-caption">{{ i.raw.service_level || '' }}</span>
                    </template>
                  </v-list-item>
                </template>
              </v-autocomplete>

              <!-- Selected carrier detail -->
              <div v-if="selectedCarrier" class="mt-3">
                <v-sheet rounded="lg" border class="pa-3">
                  <div class="d-flex flex-wrap ga-2">
                    <v-chip size="small" variant="outlined" label>
                      <v-icon size="14" class="mr-1">mdi-phone</v-icon>{{ selectedCarrier.phone || 'No phone' }}
                    </v-chip>
                    <v-chip size="small" variant="outlined" label v-if="selectedCarrier.service_area">
                      <v-icon size="14" class="mr-1">mdi-map-marker-radius</v-icon>{{ selectedCarrier.service_area }}
                    </v-chip>
                    <v-chip size="small" variant="outlined" label>
                      <v-icon size="14" class="mr-1">mdi-speedometer</v-icon>{{ selectedCarrier.service_level || 'N/A' }}
                    </v-chip>
                    <v-chip size="small" variant="outlined" label>
                      <v-icon size="14" class="mr-1">mdi-star</v-icon>{{ selectedCarrier.rating || 'N/A' }}
                    </v-chip>
                  </div>
                </v-sheet>
              </div>
            </div>

            <v-alert v-else type="info" variant="tonal" rounded="lg" density="compact" class="mt-4">
              Assignment is optional. You can skip this step and assign a driver or carrier later.
            </v-alert>

            <!-- Vehicle -->
            <div v-if="form.assignment_type" class="mt-5">
              <div class="d-flex align-center flex-wrap ga-2 mb-2">
                <span class="text-caption text-medium-emphasis">Vehicle</span>
                <v-chip v-if="vehicleAutoFilled" size="x-small" variant="tonal" color="success" prepend-icon="mdi-auto-fix">
                  auto-filled from driver
                </v-chip>
                <v-spacer />
                <v-btn
                  v-if="form.vehicle_id || form.vehicle_manual"
                  size="x-small"
                  variant="text"
                  class="text-none"
                  prepend-icon="mdi-close-circle-outline"
                  @click="clearVehicle"
                >Clear</v-btn>
              </div>
              <v-combobox
                v-model="vehicleSelection"
                :items="vehicleOptions"
                item-title="label"
                return-object
                prepend-inner-icon="mdi-truck-outline"
                label="Select a fleet vehicle or type a description"
                hint="Pick a vehicle from your fleet, or type any vehicle (e.g. “Toyota Hilux KDJ 123X”) for a manual entry."
                persistent-hint
                density="compact"
                filled
                rounded="lg"
                clearable
                :menu-props="{ maxHeight: 320 }"
              >
                <template #item="{ item: i, props: p }">
                  <v-list-item v-bind="p" :title="i.raw.label">
                    <template #prepend>
                      <v-icon :color="i.raw.status === 'available' ? 'success' : 'grey'">
                        {{ VEHICLE_ICONS[i.raw.vehicle_type] || 'mdi-truck-outline' }}
                      </v-icon>
                    </template>
                    <template #append>
                      <v-chip
                        size="x-small"
                        variant="flat"
                        :color="i.raw.status === 'available' ? 'success' : 'grey'"
                      >{{ i.raw.status }}</v-chip>
                    </template>
                  </v-list-item>
                </template>
              </v-combobox>
              <div v-if="form.vehicle_manual" class="d-flex align-center text-caption text-medium-emphasis mt-2">
                <v-icon size="14" class="mr-1">mdi-pencil-outline</v-icon>
                Manual entry — this vehicle is not linked to a fleet record.
              </div>
            </div>
          </div>

          <!-- ── STEP 5 (index 4): REVIEW ── -->
          <div v-else-if="createStep === 4">
            <div class="trf-section-head">
              <span class="trf-section-index">05</span>
              <div>
                <div class="text-subtitle-1 font-weight-bold">Review and submit</div>
                <div class="text-caption text-medium-emphasis">Check the route, items and totals before saving.</div>
              </div>
            </div>

            <div class="trf-review-grid mt-3">
              <div class="trf-review-card">
                <div class="trf-review-label">Route</div>
                <div class="d-flex align-center flex-wrap ga-2 mt-1">
                  <span class="trf-wh-chip">{{ sourceBranchName }}</span>
                  <v-icon size="15" class="trf-route-arrow">mdi-arrow-right</v-icon>
                  <span class="trf-wh-chip trf-wh-chip-dest">{{ destBranchName }}</span>
                </div>
              </div>
              <div class="trf-review-card">
                <div class="trf-review-label">Shipment</div>
                <div class="d-flex flex-wrap ga-4 mt-1">
                  <div>
                    <div class="text-caption text-medium-emphasis">Items</div>
                    <div class="text-h6 font-weight-bold">{{ form.lines.length }}</div>
                  </div>
                  <div>
                    <div class="text-caption text-medium-emphasis">Units</div>
                    <div class="text-h6 font-weight-bold">{{ totalUnits }}</div>
                  </div>
                  <div>
                    <div class="text-caption text-medium-emphasis">Value at cost</div>
                    <div class="text-h6 font-weight-bold">{{ formatMoney(totalValue) }}</div>
                  </div>
                </div>
              </div>
              <div class="trf-review-card">
                <div class="trf-review-label">Cargo &amp; schedule</div>
                <div class="d-flex flex-wrap ga-4 mt-1">
                  <div>
                    <div class="text-caption text-medium-emphasis">Priority</div>
                    <div class="font-weight-bold">
                      <v-chip size="x-small" variant="flat" :color="priorityMeta(form.priority).color">
                        <v-icon size="12" start :class="priorityIconClass(form.priority)">{{ priorityMeta(form.priority).icon }}</v-icon>
                        {{ priorityMeta(form.priority).label }}
                      </v-chip>
                    </div>
                  </div>
                  <div v-if="form.parcel_count">
                    <div class="text-caption text-medium-emphasis">Parcels</div>
                    <div class="font-weight-bold">{{ form.parcel_count }}</div>
                  </div>
                  <div v-if="form.weight_kg">
                    <div class="text-caption text-medium-emphasis">Weight</div>
                    <div class="font-weight-bold">{{ form.weight_kg }} kg</div>
                  </div>
                  <div v-if="form.scheduled_pickup">
                    <div class="text-caption text-medium-emphasis">Pickup</div>
                    <div class="font-weight-bold text-body-2">{{ form.scheduled_pickup }}</div>
                  </div>
                  <div v-if="form.scheduled_delivery">
                    <div class="text-caption text-medium-emphasis">Delivery</div>
                    <div class="font-weight-bold text-body-2">{{ form.scheduled_delivery }}</div>
                  </div>
                  <div v-if="!form.parcel_count && !form.weight_kg && !form.scheduled_pickup && !form.scheduled_delivery">
                    <div class="text-caption text-medium-emphasis font-italic">No cargo details specified</div>
                  </div>
                </div>
              </div>
              <div class="trf-review-card">
                <div class="trf-review-label">Assignment</div>
                <div class="mt-1">
                  <template v-if="form.assignment_type === 'internal' && selectedDriver">
                    <v-icon size="16" class="mr-1">mdi-account-tie-hat</v-icon>
                    <span class="font-weight-bold">{{ selectedDriver.full_name }}</span>
                    <v-chip size="x-small" variant="flat" class="ml-2" :color="selectedDriver.status === 'available' ? 'success' : 'grey'">
                      {{ selectedDriver.status }}
                    </v-chip>
                  </template>
                  <template v-else-if="form.assignment_type === 'carrier' && selectedCarrier">
                    <v-icon size="16" class="mr-1">mdi-truck-fast</v-icon>
                    <span class="font-weight-bold">{{ selectedCarrier.name }}</span>
                  </template>
                  <span v-else class="text-caption text-medium-emphasis font-italic">No assignment — unassigned</span>
                </div>
                <div v-if="selectedVehicleLabel" class="mt-2">
                  <div class="text-caption text-medium-emphasis">Vehicle</div>
                  <div class="text-body-2 font-weight-medium d-flex align-center flex-wrap ga-1">
                    <v-icon size="15">mdi-truck-outline</v-icon>{{ selectedVehicleLabel }}
                    <v-chip v-if="form.vehicle_manual" size="x-small" variant="tonal" color="info">manual</v-chip>
                  </div>
                </div>
              </div>
            </div>

            <div class="trf-review-lines mt-3">
              <div v-for="l in form.lines" :key="l.stock" class="trf-review-line">
                <div class="d-flex align-center" style="gap:10px; min-width:0">
                  <div class="trf-item-icon"><v-icon size="16">mdi-package-variant-closed</v-icon></div>
                  <div style="min-width:0">
                    <div class="font-weight-medium text-truncate">{{ l._name }}</div>
                    <div class="text-caption text-medium-emphasis">{{ formatMoney(l._cost) }} per unit</div>
                  </div>
                </div>
                <div class="text-right">
                  <div class="font-weight-bold">{{ formatQty(l.quantity) }}</div>
                  <div class="text-caption text-medium-emphasis">{{ formatMoney(lineValue(l)) }}</div>
                </div>
              </div>
            </div>

            <v-alert
              v-if="shortageWarnings.length"
              type="error"
              variant="tonal"
              rounded="lg"
              density="compact"
              class="mt-3"
            >
              <div v-for="w in shortageWarnings" :key="w">{{ w }}</div>
            </v-alert>
            <v-alert v-else type="success" variant="tonal" rounded="lg" density="compact" class="mt-3">
              Stock levels verified — every line is available at the source warehouse.
            </v-alert>

            <div v-if="form.notes" class="trf-review-notes mt-3">
              <div class="trf-review-label">Reason / notes</div>
              <div class="text-body-2 mt-1">{{ form.notes }}</div>
            </div>
          </div>
        </v-card-text>

        <v-divider />
        <v-card-actions class="pa-3">
          <v-btn
            v-if="hasPrevStep"
            variant="text"
            class="text-none"
            prepend-icon="mdi-arrow-left"
            @click="prevStep"
          >Back</v-btn>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="createDialog = false">Cancel</v-btn>
          <v-btn
            v-if="hasNextStep"
            color="primary"
            variant="flat"
            rounded="lg"
            class="text-none"
            append-icon="mdi-arrow-right"
            :disabled="!stepValid"
            @click="nextStep"
          >Continue</v-btn>
          <template v-else>
            <v-btn
              color="primary"
              variant="tonal"
              rounded="lg"
              class="text-none"
              prepend-icon="mdi-content-save-outline"
              :loading="saving"
              :disabled="!canSave"
              @click="saveTransfer(false)"
            >{{ editingId ? 'Save changes' : 'Save as draft' }}</v-btn>
            <v-btn
              color="success"
              variant="flat"
              rounded="lg"
              class="text-none"
              prepend-icon="mdi-send"
              :loading="saving"
              :disabled="!canSave"
              @click="saveTransfer(true)"
            >{{ editingId ? 'Save and submit' : 'Submit for approval' }}</v-btn>
          </template>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═════════════════════════ DETAIL DIALOG ═════════════════════════ -->
    <v-dialog v-model="detailDialog" max-width="1040" scrollable>
      <v-card v-if="active" rounded="xl" class="overflow-hidden">
        <div class="trf-detail-head" :style="heroTheme">
          <span class="trf-hero-glow" />
          <div class="d-flex align-center flex-wrap ga-2">
            <v-icon size="22">mdi-truck-delivery</v-icon>
            <span class="text-h6 font-weight-bold">{{ active.reference }}</span>
            <span class="trf-detail-status" :class="`trf-detail-status-${active.status}`">
              <v-icon size="12">{{ statusIcon(active.status) }}</v-icon>
              {{ statusLabel(active.status) }}
            </span>
            <v-spacer />
            <v-btn
              icon="mdi-file-pdf-box"
              variant="text"
              size="small"
              class="trf-hero-iconbtn"
              title="Print transfer note"
              @click="printTransfer(active)"
            />
            <v-btn
              icon="mdi-close"
              variant="text"
              size="small"
              class="trf-hero-iconbtn"
              @click="detailDialog = false"
            />
          </div>
          <div class="d-flex flex-wrap align-center ga-2 mt-2 text-caption" style="opacity: .9">
            <span class="trf-detail-route">{{ active.source_branch_name }}</span>
            <v-icon size="14">mdi-arrow-right</v-icon>
            <span class="trf-detail-route">{{ active.dest_branch_name }}</span>
            <span>·</span>
            <span>Requested {{ formatDateTime(active.requested_at) }}</span>
            <span v-if="detailAgeText">· {{ detailAgeText }} ago</span>
          </div>
        </div>

        <v-progress-linear v-if="detailLoading" indeterminate color="primary" />

        <v-card-text class="pt-4">
          <!-- Snapshot stats -->
          <div class="trf-detail-stats">
            <div class="trf-detail-stat">
              <div class="trf-detail-stat-label">Items</div>
              <div class="trf-detail-stat-value">{{ active.total_items }}</div>
            </div>
            <div class="trf-detail-stat">
              <div class="trf-detail-stat-label">Units</div>
              <div class="trf-detail-stat-value">{{ formatQty(active.total_quantity) }}</div>
            </div>
            <div class="trf-detail-stat">
              <div class="trf-detail-stat-label">Value at cost</div>
              <div class="trf-detail-stat-value">{{ formatMoney(active.total_value) }}</div>
            </div>
            <div class="trf-detail-stat">
              <div class="trf-detail-stat-label">Receipt variance</div>
              <div
                class="trf-detail-stat-value"
                :class="active.status === 'completed' ? varianceClass(active.total_variance) : ''"
              >
                {{ active.status === 'completed' ? signed(active.total_variance) : '—' }}
              </div>
            </div>
          </div>

          <v-row class="mt-1">
            <v-col cols="12" lg="7">
              <div class="trf-panel h-100">
                <div class="trf-panel-title">
                  <v-icon size="16">mdi-timeline-clock-outline</v-icon>
                  Shipment timeline
                </div>
                <div class="trf-timeline mt-3">
                  <template v-for="(step, i) in timeline" :key="step.key">
                    <div class="trf-tl-step">
                      <div class="trf-tl-node" :class="{ 'trf-tl-node-done': step.done }">
                        <v-icon size="15">{{ step.icon }}</v-icon>
                      </div>
                      <div class="trf-tl-body">
                        <div class="d-flex align-center flex-wrap ga-2">
                          <span class="trf-tl-label" :class="{ 'text-disabled': !step.done }">{{ step.label }}</span>
                          <v-chip size="x-small" variant="tonal" :color="step.done ? step.color : 'grey'">
                            {{ step.done ? 'Done' : 'Pending' }}
                          </v-chip>
                        </div>
                        <div class="text-caption text-medium-emphasis mt-1">{{ step.meta }}</div>
                        <div v-if="step.time" class="text-caption text-medium-emphasis">{{ formatDateTime(step.time) }}</div>
                      </div>
                    </div>
                    <div v-if="hasTimelineLine(i)" class="trf-tl-line" :class="{ 'trf-tl-line-done': timeline[i + 1].done }" />
                  </template>
                </div>
              </div>
            </v-col>

            <v-col cols="12" lg="5">
              <div class="trf-panel h-100">
                <div class="trf-panel-title">
                  <v-icon size="16">mdi-clipboard-text-outline</v-icon>
                  Movement summary
                </div>
                <div class="trf-meta-row">
                  <span>Requested by</span>
                  <strong>{{ active.requested_by_name || '—' }}</strong>
                </div>
                <div class="trf-meta-row">
                  <span>Approved by</span>
                  <strong>{{ active.approved_by_name || '—' }}</strong>
                </div>
                <div class="trf-meta-row">
                  <span>Received by</span>
                  <strong>{{ active.received_by_name || '—' }}</strong>
                </div>
                <div class="trf-meta-row">
                  <span>Shipped</span>
                  <strong>{{ active.shipped_at ? formatDateTime(active.shipped_at) : '—' }}</strong>
                </div>
                <div class="trf-meta-row">
                  <span>Received</span>
                  <strong>{{ active.received_at ? formatDateTime(active.received_at) : '—' }}</strong>
                </div>
                <div v-if="transitHours != null" class="trf-meta-row">
                  <span>Time in transit</span>
                  <strong>{{ transitHours }} h</strong>
                </div>
                <div v-if="isAtRisk(active)" class="trf-risk-banner mt-2">
                  <v-icon size="15">mdi-alert</v-icon>
                  <span>This transfer is ageing — follow up with the {{ active.status === 'in_transit' ? 'destination' : 'approver' }}.</span>
                </div>
              </div>
            </v-col>
          </v-row>

          <!-- Cargo & Schedule -->
          <div class="trf-panel mt-3">
            <div class="trf-panel-title">
              <v-icon size="16">mdi-calendar-clock-outline</v-icon>
              Cargo &amp; schedule
            </div>
            <div class="trf-detail-meta-grid mt-2">
              <div class="trf-detail-meta-item">
                <div class="trf-detail-meta-label">Priority</div>
                <div class="trf-detail-meta-value">
                  <v-chip size="small" variant="flat" :color="detailPriorityMeta.color">
                    <v-icon size="14" class="mr-1" :class="priorityIconClass(active?.priority)">{{ detailPriorityMeta.icon }}</v-icon>
                    {{ detailPriorityMeta.label }}
                  </v-chip>
                </div>
              </div>
              <div class="trf-detail-meta-item">
                <div class="trf-detail-meta-label">Parcels / boxes</div>
                <div class="trf-detail-meta-value">{{ active.parcel_count ?? '—' }}</div>
              </div>
              <div class="trf-detail-meta-item">
                <div class="trf-detail-meta-label">Weight</div>
                <div class="trf-detail-meta-value">{{ active.weight_kg != null ? `${active.weight_kg} kg` : '—' }}</div>
              </div>
              <div class="trf-detail-meta-item">
                <div class="trf-detail-meta-label">Scheduled pickup</div>
                <div class="trf-detail-meta-value">{{ active.scheduled_pickup ? formatDateTime(active.scheduled_pickup) : '—' }}</div>
              </div>
              <div class="trf-detail-meta-item">
                <div class="trf-detail-meta-label">Scheduled delivery</div>
                <div class="trf-detail-meta-value">{{ active.scheduled_delivery ? formatDateTime(active.scheduled_delivery) : '—' }}</div>
              </div>
            </div>
          </div>

          <!-- Assignment -->
          <div class="trf-panel mt-3">
            <div class="trf-panel-title">
              <v-icon size="16">mdi-account-group-outline</v-icon>
              Assignment
            </div>
            <div class="trf-detail-meta-grid mt-2">
              <div class="trf-detail-meta-item">
                <div class="trf-detail-meta-label">Assigned driver</div>
                <div class="trf-detail-meta-value">
                  <template v-if="active.assigned_driver_name">
                    <v-icon size="15" class="mr-1">mdi-account-tie-hat</v-icon>{{ active.assigned_driver_name }}
                  </template>
                  <span v-else>—</span>
                </div>
              </div>
              <div class="trf-detail-meta-item">
                <div class="trf-detail-meta-label">Assigned carrier</div>
                <div class="trf-detail-meta-value">
                  <template v-if="active.assigned_carrier_name">
                    <v-icon size="15" class="mr-1">mdi-truck-fast</v-icon>{{ active.assigned_carrier_name }}
                  </template>
                  <span v-else>—</span>
                </div>
              </div>
              <div class="trf-detail-meta-item">
                <div class="trf-detail-meta-label">Vehicle</div>
                <div class="trf-detail-meta-value">
                  {{ active.assigned_vehicle_label || active.assigned_vehicle_note || '—' }}
                </div>
              </div>
            </div>
            <v-alert
              v-if="!active.assigned_driver && !active.assigned_carrier"
              type="info"
              variant="tonal"
              rounded="lg"
              density="compact"
              class="mt-3"
            >No driver or carrier assigned.</v-alert>
          </div>

          <!-- Digital signatures -->
          <div v-if="active.approved_signature || active.received_signature" class="trf-panel mt-3">
            <div class="trf-panel-title">
              <v-icon size="16">mdi-draw</v-icon>
              Digital signatures
            </div>
            <div class="trf-sig-grid mt-2">
              <div class="trf-sig-card">
                <div class="trf-detail-meta-label">Approved &amp; shipped by</div>
                <img
                  v-if="active.approved_signature"
                  :src="active.approved_signature"
                  alt="Approval signature"
                  class="trf-sig-img"
                />
                <div v-else class="trf-sig-missing">Not signed</div>
                <div class="trf-sig-meta">
                  {{ active.approved_by_name || '—' }}
                  <template v-if="active.shipped_at"> · {{ formatDateTime(active.shipped_at) }}</template>
                </div>
              </div>
              <div class="trf-sig-card">
                <div class="trf-detail-meta-label">Received by</div>
                <img
                  v-if="active.received_signature"
                  :src="active.received_signature"
                  alt="Receipt signature"
                  class="trf-sig-img"
                />
                <div v-else class="trf-sig-missing">Not signed</div>
                <div class="trf-sig-meta">
                  {{ active.received_by_name || '—' }}
                  <template v-if="active.received_at"> · {{ formatDateTime(active.received_at) }}</template>
                </div>
              </div>
            </div>
          </div>

          <!-- Lines -->
          <div class="trf-panel mt-3">
            <div class="trf-panel-title">
              <v-icon size="16">mdi-package-variant-closed</v-icon>
              Items
              <v-spacer />
              <span class="text-caption text-medium-emphasis">{{ active.lines?.length || 0 }} line(s)</span>
            </div>
            <div class="trf-table-wrap mt-2">
              <table class="trf-table trf-detail-table">
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
                    <td>
                      <div class="font-weight-medium">{{ l.stock_name }}</div>
                      <div class="text-caption text-medium-emphasis">
                        <span v-if="l.stock_unit">{{ l.stock_unit }} · </span>
                        <span v-if="l.batch_number">
                          Batch <strong>{{ l.batch_number }}</strong>
                          <template v-if="l.batch_expiry"> · Exp {{ formatDate(l.batch_expiry) }}</template>
                        </span>
                        <span v-else>No specific batch</span>
                      </div>
                    </td>
                    <td class="text-right font-weight-medium">{{ formatQty(l.quantity) }}</td>
                    <td class="text-right">{{ l.quantity_received == null ? '—' : formatQty(l.quantity_received) }}</td>
                    <td class="text-right" :class="varianceClass(l.variance)">
                      {{ l.quantity_received == null ? '—' : signed(l.variance) }}
                    </td>
                    <td class="text-right font-weight-medium">{{ formatMoney(l.line_value) }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <v-alert
            v-if="isShortReceipt(active)"
            type="warning"
            variant="tonal"
            rounded="lg"
            density="compact"
            class="mt-3"
          >
            Short receipt: <strong>{{ -active.total_variance }}</strong> unit(s) missing on arrival.
            Investigate and record the discrepancy.
          </v-alert>

          <div v-if="active.notes" class="trf-review-notes mt-3">
            <div class="trf-review-label">Reason / notes</div>
            <div class="text-body-2 mt-1">{{ active.notes }}</div>
          </div>
        </v-card-text>

        <v-divider />
        <v-card-actions class="pa-3">
          <v-btn
            v-if="active.status === 'draft'"
            color="primary"
            variant="tonal"
            rounded="lg"
            class="text-none"
            prepend-icon="mdi-pencil-outline"
            @click="openEdit(active)"
          >Edit</v-btn>
          <v-btn
            v-if="active.status === 'draft'"
            color="info"
            variant="tonal"
            rounded="lg"
            class="text-none"
            prepend-icon="mdi-send-outline"
            @click="submitTransfer(active)"
          >Submit</v-btn>
          <v-btn
            v-if="active.status === 'requested' && canApprove"
            color="success"
            variant="flat"
            rounded="lg"
            class="text-none"
            prepend-icon="mdi-check-bold"
            @click="approve(active)"
          >Approve and ship</v-btn>
          <v-btn
            v-if="active.status === 'in_transit'"
            color="primary"
            variant="flat"
            rounded="lg"
            class="text-none"
            prepend-icon="mdi-package-down"
            @click="openReceive(active)"
          >Receive</v-btn>
          <v-spacer />
          <v-btn
            v-if="canCancel(active)"
            color="error"
            variant="text"
            class="text-none"
            prepend-icon="mdi-cancel"
            @click="cancelTransfer(active)"
          >Cancel transfer</v-btn>
          <v-btn variant="text" class="text-none" @click="detailDialog = false">Close</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═════════════════════════ RECEIVE DIALOG ═════════════════════════ -->
    <v-dialog v-model="receiveDialog" max-width="940" persistent scrollable>
      <v-card v-if="active" rounded="xl" class="overflow-hidden">
        <div class="trf-receive-head" :style="heroTheme">
          <span class="trf-hero-glow" />
          <div class="d-flex align-center flex-wrap ga-2 text-white">
            <v-icon size="22">mdi-package-down</v-icon>
            <span class="text-h6 font-weight-bold">Receive {{ active.reference }}</span>
            <v-chip size="small" variant="flat" class="trf-head-chip">
              {{ active.source_branch_name }} → {{ active.dest_branch_name }}
            </v-chip>
            <v-spacer />
            <v-btn icon="mdi-close" variant="text" size="small" class="trf-hero-iconbtn" @click="receiveDialog = false" />
          </div>
          <div class="text-caption mt-1" style="opacity: .88">
            Shipped {{ formatDateTime(active.shipped_at) }}
            <template v-if="transitHours != null"> · in transit for {{ transitHours }}h</template>
            · goods worth {{ formatMoney(active.total_value) }} at cost
          </div>
        </div>

        <v-card-text class="pt-4">
          <v-alert type="info" variant="tonal" density="compact" rounded="lg" class="mb-3">
            Received quantities are booked into <strong>{{ active.dest_branch_name }}</strong> as batch
            <code>TRF-{{ active.reference }}</code>. Record any short or damaged units per item below.
          </v-alert>

          <!-- New items warning: items the destination branch doesn't carry yet. -->
          <v-alert
            v-if="newItemsPreview.length"
            type="success"
            variant="tonal"
            density="compact"
            rounded="lg"
            class="mb-3 trf-newitems-banner"
            icon="mdi-package-variant-plus"
          >
            <div class="text-body-2 font-weight-medium">
              {{ newItemsCount }} item(s) will be added as new stock in
              <strong>{{ active.dest_branch_name }}</strong> inventory when you confirm.
            </div>
            <div class="text-caption text-medium-emphasis mt-1">
              {{ newItemsPreview.map((l) => l.stock_name).join(', ') }}
            </div>
          </v-alert>

          <div v-for="l in receiveLines" :key="l.id" class="trf-receive-line" :class="lineState(l).cls">
            <div class="d-flex align-center flex-wrap ga-3">
              <div class="flex-grow-1" style="min-width:220px">
                <div class="d-flex align-center flex-wrap ga-1">
                  <span class="font-weight-medium">{{ l.stock_name }}</span>
                  <span v-if="l.stock_unit" class="text-caption text-medium-emphasis">({{ l.stock_unit }})</span>
                  <v-chip
                    v-if="!l.exists_at_dest"
                    size="x-small"
                    variant="tonal"
                    color="success"
                    class="font-weight-bold"
                  >
                    <v-icon start size="12">mdi-package-variant-plus</v-icon>
                    New to {{ active.dest_branch_name }}
                  </v-chip>
                  <span
                    v-else
                    class="text-caption text-medium-emphasis ml-1"
                  >· {{ formatQty(l.quantity_at_dest) }} on hand at destination</span>
                </div>
                <div class="text-caption text-medium-emphasis">
                  sent {{ formatQty(l.quantity) }} · {{ formatMoney(l.quantity * l._cost) }}
                </div>
              </div>

              <div class="d-flex align-center ga-2">
                <v-btn size="x-small" variant="tonal" class="text-none" @click="setLineFull(l)">All</v-btn>
                <v-btn size="x-small" variant="tonal" color="error" class="text-none" @click="setLineNone(l)">None</v-btn>
                <v-btn icon="mdi-minus" size="x-small" variant="tonal" :disabled="atReceiveMin(l)" @click="stepReceive(l, -1)" />
                <v-text-field
                  v-model.number="l.quantity_received"
                  type="number"
                  density="compact"
                  variant="outlined"
                  hide-details
                  min="0"
                  class="trf-qty-input trf-receive-qty"
                  @change="clampReceive(l)"
                />
                <v-btn icon="mdi-plus" size="x-small" variant="tonal" :disabled="atReceiveMax(l)" @click="stepReceive(l, 1)" />
              </div>

              <v-chip size="small" variant="tonal" :color="lineState(l).color">
                <v-icon start size="13">{{ lineState(l).icon }}</v-icon>
                {{ lineState(l).label }}
              </v-chip>
            </div>

            <div class="d-flex align-center flex-wrap ga-2 mt-2">
              <v-text-field
                v-model="l.notes"
                density="compact"
                variant="outlined"
                hide-details
                placeholder="Remark (e.g. 2 units damaged in transit)"
                prepend-inner-icon="mdi-comment-text-outline"
                class="flex-grow-1"
              />
              <div class="text-caption text-medium-emphasis text-no-wrap">
                receiving {{ formatMoney((Number(l.quantity_received) || 0) * l._cost) }}
              </div>
            </div>
          </div>

          <div class="trf-receive-summary mt-3">
            <div class="d-flex flex-wrap ga-4 align-center justify-space-between">
              <div class="d-flex flex-wrap ga-4">
                <div>
                  <div class="text-caption text-medium-emphasis">Units sent</div>
                  <div class="text-h6 font-weight-bold">{{ formatQty(receiveSummary.sent) }}</div>
                </div>
                <div>
                  <div class="text-caption text-medium-emphasis">Units received</div>
                  <div class="text-h6 font-weight-bold text-primary">{{ formatQty(receiveSummary.received) }}</div>
                </div>
                <div>
                  <div class="text-caption text-medium-emphasis">Variance</div>
                  <div class="text-h6 font-weight-bold" :class="varianceClass(receiveSummary.variance)">
                    {{ signed(receiveSummary.variance) }}
                  </div>
                </div>
                <div>
                  <div class="text-caption text-medium-emphasis">Value received</div>
                  <div class="text-h6 font-weight-bold">{{ formatMoney(receiveSummary.value) }}</div>
                </div>
              </div>
              <v-btn size="small" variant="text" class="text-none" color="primary" prepend-icon="mdi-backup-restore" @click="receiveAll">
                Reset to full receipt
              </v-btn>
            </div>
            <v-alert v-if="isNeg(receiveSummary.variance)" type="warning" variant="tonal" density="compact" rounded="lg" class="mt-3">
              Shortfall of <strong>{{ -receiveSummary.variance }}</strong> unit(s) worth
              <strong>{{ formatMoney(-receiveSummary.discrepancyValue) }}</strong>. Add a remark on the affected
              item(s); the discrepancy is recorded on the transfer history.
            </v-alert>
          </div>

          <!-- Receiver digital signature -->
          <v-divider class="my-4" />
          <div class="d-flex align-center flex-wrap ga-2 mb-1">
            <v-icon size="18" color="primary">mdi-draw</v-icon>
            <span class="text-subtitle-2 font-weight-bold">Receiver's digital signature</span>
            <v-chip size="x-small" variant="tonal" :color="receiveSigned ? 'success' : 'error'">
              {{ receiveSigned ? 'captured' : 'required' }}
            </v-chip>
          </div>
          <div class="text-caption text-medium-emphasis mb-2">
            Signing as <strong>{{ auth.fullName || 'your account' }}</strong>.
            This confirms the quantities recorded above and is printed on the transfer note.
          </div>
          <SignaturePad
            v-model="receiveSignature"
            :height="150"
            @update:has-ink="receiveSigned = $event"
          />
        </v-card-text>

        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="receiveDialog = false">Cancel</v-btn>
          <v-btn
            color="success"
            variant="flat"
            rounded="lg"
            class="text-none"
            size="large"
            :loading="saving"
            :disabled="!receiveValid || receiveSummary.received === 0 || !receiveSigned"
            prepend-icon="mdi-package-down"
            @click="confirmReceive"
          >
            Confirm receipt ({{ receiveSummary.received }} units)
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═════════════════════════ RE-AUTH CONFIRM (approve / cancel) ═════════════════════════ -->
    <v-dialog v-model="confirmDialog" max-width="580" persistent>
      <v-card v-if="pendingAction && confirmMeta" rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon :color="confirmMeta.iconColor" class="mr-2">{{ confirmMeta.icon }}</v-icon>
          {{ confirmMeta.title }}
        </v-card-title>
        <v-card-text>
          <div class="text-body-2 mb-3">
            <strong>{{ pendingAction.transfer.reference }}</strong>
            ({{ pendingAction.transfer.source_branch_name }} → {{ pendingAction.transfer.dest_branch_name }})
            {{ confirmMeta.bodyProduct }}.
          </div>
          <v-alert :type="confirmMeta.iconColor === 'error' ? 'error' : 'success'" variant="tonal" density="compact" rounded="lg" class="mb-4">
            {{ confirmMeta.note }}
          </v-alert>
          <div class="text-subtitle-2 text-medium-emphasis mb-2">
            Enter your password to authorise this action.
          </div>
          <v-text-field
            v-model="confirmPwd"
            :type="confirmPwdVisible ? 'text' : 'password'"
            :append-inner-icon="confirmPwdVisible ? 'mdi-eye-off' : 'mdi-eye'"
            variant="outlined"
            density="comfortable"
            autocomplete="current-password"
            placeholder="Your account password"
            :error-messages="confirmPwdError"
            hide-details="auto"
            @click:append-inner="confirmPwdVisible = !confirmPwdVisible"
            @keyup.enter="doConfirmAction"
          />

          <!-- Digital signature — required to authorise the shipment. -->
          <template v-if="pendingAction.type === 'approve'">
            <v-divider class="my-4" />
            <div class="d-flex align-center flex-wrap ga-2 mb-1">
              <v-icon size="18" color="primary">mdi-draw</v-icon>
              <span class="text-subtitle-2 font-weight-bold">Digital signature</span>
              <v-chip
                size="x-small"
                variant="tonal"
                :color="approveSigned ? 'success' : 'error'"
              >
                {{ approveSigned ? 'captured' : 'required' }}
              </v-chip>
            </div>
            <div class="text-caption text-medium-emphasis mb-2">
              Signing as <strong>{{ auth.fullName || 'your account' }}</strong>.
              The signature is stored on the transfer and printed on the transfer note.
            </div>
            <SignaturePad
              v-model="approveSignature"
              :height="140"
              @update:has-ink="approveSigned = $event"
            />
          </template>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" :disabled="saving" @click="confirmDialog = false">Keep it</v-btn>
          <v-btn
            :color="confirmMeta.actionColor"
            variant="flat"
            rounded="lg"
            class="text-none"
            :loading="saving"
            :prepend-icon="confirmMeta.actionIcon"
            :disabled="pendingAction.type === 'approve' && !approveSigned"
            @click="doConfirmAction"
          >
            {{ confirmMeta.actionLabel }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Legacy cancel dialog kept for any references; renders nothing when no action is set. -->
    <v-dialog v-model="cancelDialog" max-width="460">
      <v-card v-if="active" rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon color="error" class="mr-2">mdi-cancel</v-icon>
          Cancel transfer?
        </v-card-title>
        <v-card-text>
          <strong>{{ active.reference }}</strong> ({{ active.source_branch_name }} → {{ active.dest_branch_name }})
          will be cancelled{{ active.status === 'in_transit' ? ' — stock already deducted at source will remain there' : '' }}.
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="cancelDialog = false">Keep it</v-btn>
          <v-btn color="error" variant="flat" rounded="lg" class="text-none" :loading="saving" @click="doCancelTransfer(active)">
            Cancel transfer
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" rounded="lg" timeout="3200">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, onMounted, watch } from 'vue'
import { formatMoney } from '~/utils/format'
import { useAuthStore } from '~/stores/auth'
import { useBranchStore } from '~/stores/branch'
import { ADMIN_ROLES } from '~/utils/permissions'

const { $api } = useNuxtApp()
const { branches: branchesApi } = useTenantEndpoints()
const auth = useAuthStore()
const branchStore = useBranchStore()
const brand = useBranding()

// ── Branded hero (same CSS-variable bridge as the inventory list page) ──
const heroTheme = computed(() => ({
  '--hero-deep': brand.secondary.value,
  '--hero-main': brand.primary.value,
  '--hero-accent': brand.gradientStops.value[2],
  '--hero-ink': brand.ink.value,
  '--hero-glow': brand.tint('primary', 0.3),
  '--hero-glow-2': brand.tint('accent', 0.2),
  '--hero-shadow': brand.shadow.value
}))

// RBAC: supervisors approve and ship; storekeepers create, submit and receive.
const canApprove = computed(() => [...ADMIN_ROLES, 'branch_admin'].includes(auth.role))

// Analytics lives in the same URL namespace the user is browsing: pharmacy
// tenants under /pharmacy, inventory tenants under /ims.
const route = useRoute()
const analyticsPath = computed(() =>
  route.path.startsWith('/pharmacy')
    ? '/pharmacy/inventory/transfers/analytics'
    : '/ims/inventory/transfers/analytics',
)
const optimizePath = computed(() =>
  route.path.startsWith('/pharmacy')
    ? '/pharmacy/inventory/transfers/optimization'
    : '/ims/inventory/transfers/optimization',
)
const suggestionsPath = computed(() =>
  route.path.startsWith('/pharmacy')
    ? '/pharmacy/inventory/transfers/suggestions'
    : '/ims/inventory/transfers/suggestions',
)

const loading = ref(false)
const exporting = ref(false)
const saving = ref(false)
const detailLoading = ref(false)

const transfers = ref([])
const branches = ref([])
const stats = ref(null)

const search = ref('')
const statusFilter = ref('all')
const sourceFilter = ref(null)
const destFilter = ref(null)
const datePreset = ref('all')
const fromDate = ref(null)
const toDate = ref(null)
const viewMode = ref('board')
if (import.meta.client) {
  const savedView = localStorage.getItem('ims-transfers-view')
  if (savedView === 'board' || savedView === 'list') viewMode.value = savedView
}
const page = ref(1)
const pageSize = ref(12)
const pageSizeOptions = [8, 12, 24, 50]

const createDialog = ref(false)
const createStep = ref(0)
// When set, the wizard is editing an existing draft instead of creating one.
const editingId = ref(null)
const editingReference = ref('')
const detailDialog = ref(false)
const receiveDialog = ref(false)
const cancelDialog = ref(false)
// Unified re-auth dialog for destructive actions (approve / cancel / receive transfer).
const confirmDialog = ref(false)
const pendingAction = ref(null) // { type: 'approve' | 'cancel' | 'receive', transfer }
const confirmPwd = ref('')
const confirmPwdVisible = ref(false)
const confirmPwdError = ref('')
const active = ref(null)
const receiveLines = ref([])
// Digital signatures captured in the approve / receive dialogs.
const approveSignature = ref('')
const approveSigned = ref(false)
const receiveSignature = ref('')
const receiveSigned = ref(false)
const snack = reactive({ show: false, color: 'success', text: '' })

// Theme + label metadata per pending action, consumed by the dialog template.
const confirmMeta = computed(() => {
  const t = pendingAction.value?.type
  if (t === 'approve') {
    return {
      icon: 'mdi-check-bold',
      iconColor: 'success',
      title: 'Confirm approval & shipment',
      bodyProduct: 'will be approved and shipped',
      note: 'Stock will be deducted from the source branch immediately.',
      actionColor: 'success',
      actionLabel: 'Confirm and ship',
      actionIcon: 'mdi-send-outline',
      loading: false,
    }
  }
  if (t === 'cancel') {
    const tr = pendingAction.value?.transfer
    const inTransit = tr?.status === 'in_transit'
    return {
      icon: 'mdi-cancel',
      iconColor: 'error',
      title: 'Cancel this transfer?',
      bodyProduct: 'will be cancelled',
      note: inTransit
        ? 'Stock already deducted at source will remain there.'
        : 'No stock movements have occurred yet.',
      actionColor: 'error',
      actionLabel: 'Cancel transfer',
      actionIcon: 'mdi-cancel',
      loading: false,
    }
  }
  if (t === 'receive') {
    return {
      icon: 'mdi-package-down',
      iconColor: 'primary',
      title: 'Confirm receipt at destination',
      bodyProduct: 'will be received and booked into the destination inventory',
      note: 'Stock will be added to the destination branch; new items may be created there on receipt.',
      actionColor: 'primary',
      actionLabel: 'Confirm receipt',
      actionIcon: 'mdi-package-down',
      loading: false,
    }
  }
  return null
})

const form = ref({
  source_branch: null, dest_branch: null, notes: '', lines: [],
  // cargo & schedule
  priority: 'normal',
  // 1 box is preselected by default; the user can change or clear it.
  parcel_count: 1,
  weight_kg: null,
  scheduled_pickup: null,
  scheduled_delivery: null,
  // assignment
  assignment_type: null,  // 'internal' | 'carrier'
  driver_id: null,
  carrier_id: null,
  vehicle_id: null,
  vehicle_manual: '',
})
const picker = ref(null)
const stockPickerRef = ref(null)
const stockOptions = ref([])
const stockLoading = ref(false)
const stockSearch = ref('')
let stockTimer = null

// ── Step 2 search mode ─────────────────────────────────────────────────────
// 'item'  → search stock by name/barcode, then pick batches (batch drawer)
// 'batch' → search by batch number and list every item held in that batch
const itemSearchMode = ref('item')
const batchSearch = ref('')
const batchSearchLoading = ref(false)
const batchSearchResults = ref([])
let batchSearchTimer = null

const batchSearchSelected = computed(
  () => batchSearchResults.value.filter(b => b.selected),
)
const batchSearchTotalUnits = computed(
  () => batchSearchResults.value.reduce((s, b) => s + (Number(b.quantity_remaining) || 0), 0),
)
const batchSearchSelectedUnits = computed(
  () => batchSearchSelected.value.reduce((s, b) => s + (Number(b.quantity) || 0), 0),
)
const batchSearchItemCount = computed(
  () => new Set(batchSearchResults.value.map(b => b.stock)).size,
)

// ── Batch picker state ─────────────────────────────────────────────────────
// When the user selects a stock from the autocomplete, we open a drawer that
// lists every available batch at the source warehouse. They can pick batches
// individually (“user pick items from a batch”) or hit “Select all” to take
// every remaining unit (“selection of all batch items”). Each checked batch
// becomes its own line, pinned to that batch via the `batch` FK.
const batchPickerOpen = ref(false)
const batchStock = ref(null)        // the MedicationStock whose batches we show
const batchRows = ref([])           // [{ id, batch_number, expiry_date, quantity_remaining, cost_price_per_unit, selected, quantity }]
const batchPickerError = ref('')
const lineKeySeq = ref(0)

const availableBatches = computed(() => batchRows.value.filter(b => b.quantity_remaining > 0))
const selectedBatchCount = computed(
  () => batchRows.value.filter(b => b.selected).length,
)
const batchTotalAvailable = computed(
  () => availableBatches.value.reduce((s, b) => s + (Number(b.quantity_remaining) || 0), 0),
)
const selectedBatchUnits = computed(
  () => batchRows.value
    .filter(b => b.selected)
    .reduce((s, b) => s + (Number(b.quantity) || 0), 0),
)
const batchUnitLabel = computed(() => {
  const s = batchStock.value
  return s?.unit_abbreviation || s?.unit_name || 'units'
})

function availableBatchCount(s) {
  if (!s) return 0
  return (s.batches || []).filter(b => Number(b.quantity_remaining) > 0).length
}

function isExpiringSoon(b) {
  if (!b || !b.expiry_date) return false
  const d = new Date(b.expiry_date)
  if (isNaN(d)) return false
  const days = (d - Date.now()) / 86400000
  return days <= 60 && days >= 0
}

const createSteps = [
  { key: 'route',    label: 'Route and reason',     icon: 'mdi-map-marker-path' },
  { key: 'items',    label: 'Items',                 icon: 'mdi-package-variant' },
  { key: 'cargo',    label: 'Cargo and schedule',    icon: 'mdi-calendar-clock-outline' },
  { key: 'assign',   label: 'Assignment',            icon: 'mdi-account-group-outline' },
  { key: 'review',   label: 'Review',                icon: 'mdi-check-decagram-outline' },
]

// ── Cargo & schedule constants ───────────────────────────────────────────
const priorityOptions = [
  { value: 'low',    label: 'Low',    desc: 'No urgency — schedule within the week.',     icon: 'mdi-arrow-down',          color: 'grey' },
  { value: 'normal', label: 'Normal', desc: 'Standard timeline — ship within 2–3 days.',  icon: 'mdi-circle-medium',       color: 'primary' },
  { value: 'high',   label: 'High',   desc: 'Time-sensitive — dispatch same or next day.', icon: 'mdi-arrow-up',            color: 'amber' },
  { value: 'urgent', label: 'Urgent', desc: 'Critical — immediate dispatch required.',     icon: 'mdi-alert-decagram',      color: 'error' },
]
const parcelChipOptions = [1, 2, 3, 5, 10, 20]

// Shared lookup so the table, detail dialog and wizard render priority
// consistently (label + icon + brand-safe colour).
function priorityMeta(p) {
  return priorityOptions.find(o => o.value === (p || 'normal'))
    || { value: p, label: 'Normal', icon: 'mdi-circle-medium', color: 'primary', desc: '' }
}

// Urgent gets a pulsing icon so it stands out in dense lists. The animation
// is disabled under prefers-reduced-motion (see .trf-urgent-blink in CSS).
function priorityIconClass(p) {
  return (p || 'normal') === 'urgent' ? 'trf-urgent-blink' : ''
}

// ── Assignment lookups (drivers, carriers, vehicles) ─────────────────────
const driverOptions = ref([])
const carrierOptions = ref([])
const vehicleOptions = ref([])
// True while the vehicle field holds a value auto-filled from the driver.
const vehicleAutoFilled = ref(false)

const VEHICLE_ICONS = {
  lorry: 'mdi-truck-cargo-container',
  truck: 'mdi-truck',
  van: 'mdi-van-utility',
  pickup: 'mdi-car-pickup',
  refrigerated: 'mdi-snowflake',
  motorbike: 'mdi-motorbike',
  bicycle: 'mdi-bicycle',
  other: 'mdi-truck-outline',
}

const selectedDriver = computed(() =>
  driverOptions.value.find(d => d.id === form.value.driver_id) || null
)
const selectedCarrier = computed(() =>
  carrierOptions.value.find(c => c.id === form.value.carrier_id) || null
)
const availableDrivers = computed(() =>
  driverOptions.value.filter(d => d.status === 'available' && d.is_active)
)

// Label shown in the review step / summary for the chosen vehicle.
const selectedVehicleLabel = computed(() => {
  if (form.value.vehicle_id) {
    const v = vehicleOptions.value.find(x => x.id === form.value.vehicle_id)
    return v?.label || `Vehicle #${form.value.vehicle_id}`
  }
  return form.value.vehicle_manual || ''
})

// Two-way binding for the vehicle combobox: a fleet vehicle object when one is
// picked from the list, or a plain string for manual entry.
const vehicleSelection = computed({
  get() {
    if (form.value.vehicle_id) {
      const v = vehicleOptions.value.find(x => x.id === form.value.vehicle_id)
      if (v) return v
    }
    return form.value.vehicle_manual || null
  },
  set(val) {
    if (val && typeof val === 'object') {
      form.value.vehicle_id = val.id
      form.value.vehicle_manual = ''
      vehicleAutoFilled.value = false
      return
    }
    const text = typeof val === 'string' ? val.trim() : ''
    if (!text) {
      form.value.vehicle_id = null
      form.value.vehicle_manual = ''
      vehicleAutoFilled.value = false
      return
    }
    // Typed text that exactly matches a fleet vehicle links to it instead.
    const match = vehicleOptions.value.find(
      v => v.label.toLowerCase() === text.toLowerCase() ||
           (v.plate_number || '').toLowerCase() === text.toLowerCase()
    )
    if (match) {
      form.value.vehicle_id = match.id
      form.value.vehicle_manual = ''
      vehicleAutoFilled.value = false
    } else {
      form.value.vehicle_id = null
      form.value.vehicle_manual = text
      vehicleAutoFilled.value = false
    }
  },
})

function clearVehicle() {
  form.value.vehicle_id = null
  form.value.vehicle_manual = ''
  vehicleAutoFilled.value = false
}

// Auto-populate the vehicle whenever a driver with a default vehicle is chosen.
watch(() => form.value.driver_id, (id) => {
  if (!id) {
    if (vehicleAutoFilled.value) clearVehicle()
    return
  }
  const driver = driverOptions.value.find(d => d.id === id)
  if (driver?.assigned_vehicle) {
    form.value.vehicle_id = driver.assigned_vehicle
    form.value.vehicle_manual = ''
    vehicleAutoFilled.value = true
  }
})

const detailPriorityMeta = computed(() => priorityMeta(active.value?.priority))

const statusOptions = [
  { value: 'all', label: 'All', icon: 'mdi-view-grid-outline' },
  { value: 'draft', label: 'Draft', icon: 'mdi-pencil-outline' },
  { value: 'requested', label: 'Requested', icon: 'mdi-clock-outline' },
  { value: 'in_transit', label: 'In transit', icon: 'mdi-truck-fast-outline' },
  { value: 'completed', label: 'Completed', icon: 'mdi-check-all' },
  { value: 'cancelled', label: 'Cancelled', icon: 'mdi-cancel' }
]

const datePresets = [
  { value: 'all', label: 'All time' },
  { value: 'today', label: 'Today' },
  { value: '7d', label: 'Last 7 days' },
  { value: '30d', label: 'Last 30 days' },
  { value: 'month', label: 'This month' },
  { value: 'year', label: 'This year' },
  { value: 'custom', label: 'Custom' }
]

const transferReasons = [
  'Stock replenishment — branch running low',
  'New branch opening — initial allocation',
  'Emergency supply — urgent need at destination',
  'Seasonal demand adjustment',
  'Rebalance inventory across warehouses',
  'Customer order fulfilment from another branch',
  'Damaged stock replacement',
  'Return of unused stock to source warehouse'
]

const branchFilterItems = computed(() => branches.value)
const sourceBranchName = computed(() => branchName(form.value.source_branch))
const destBranchName = computed(() => branchName(form.value.dest_branch))
const destBranches = computed(() => branches.value.filter(b => b.id !== form.value.source_branch))

function branchName(id) {
  const b = branches.value.find(x => x.id === id)
  return b ? b.name : ''
}

// ── Date presets ────────────────────────────────────────────────────────
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

const effectiveFrom = computed(() => {
  if (datePreset.value === 'custom') return fromDate.value || null
  const p = presetRange(datePreset.value)
  return p.from ? isoDay(p.from) : null
})

const effectiveTo = computed(() => {
  if (datePreset.value === 'custom') return toDate.value || null
  const p = presetRange(datePreset.value)
  return p.to ? isoDay(p.to) : null
})

const dateFilterSummary = computed(() => {
  if (!effectiveFrom.value && !effectiveTo.value) return ''
  const fmt = (iso) => new Date(iso).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' })
  const from = effectiveFrom.value ? fmt(effectiveFrom.value) : 'start'
  const to = effectiveTo.value ? fmt(effectiveTo.value) : 'today'
  return `Showing transfers requested between ${from} and ${to}.`
})

// ── Filtering ───────────────────────────────────────────────────────────
const baseFiltered = computed(() => {
  const s = (search.value || '').toLowerCase().trim()
  const from = effectiveFrom.value
  const to = effectiveTo.value
  return transfers.value.filter(t => {
    if (sourceFilter.value && t.source_branch !== sourceFilter.value) return false
    if (destFilter.value && t.dest_branch !== destFilter.value) return false
    if (from || to) {
      const d = t.requested_at ? String(t.requested_at).slice(0, 10) : ''
      if (from && (!d || d < from)) return false
      if (to && (!d || d > to)) return false
    }
    if (!s) return true
    return [t.reference, t.source_branch_name, t.dest_branch_name, t.notes, t.requested_by_name]
      .filter(Boolean)
      .some(v => v.toLowerCase().includes(s))
  })
})

const statusCounts = computed(() => {
  const counts = { all: baseFiltered.value.length, draft: 0, requested: 0, approved: 0, in_transit: 0, completed: 0, cancelled: 0 }
  for (const t of baseFiltered.value) {
    if (counts[t.status] != null) counts[t.status]++
  }
  return counts
})

const statusChips = computed(() =>
  statusOptions.map(o => ({ ...o, count: statusCounts.value[o.value] ?? 0 })))

const filtered = computed(() =>
  statusFilter.value === 'all'
    ? baseFiltered.value
    : baseFiltered.value.filter(t => t.status === statusFilter.value))

const hasActiveFilters = computed(() =>
  statusFilter.value !== 'all' ||
  !!sourceFilter.value ||
  !!destFilter.value ||
  datePreset.value !== 'all' ||
  !!fromDate.value ||
  !!toDate.value)

const activeFilterChips = computed(() => {
  const chips = []
  if (statusFilter.value !== 'all') {
    chips.push({
      key: 'status',
      label: `Status: ${statusLabel(statusFilter.value)}`,
      clear: () => { statusFilter.value = 'all' }
    })
  }
  if (sourceFilter.value) {
    chips.push({
      key: 'source',
      label: `From: ${branchName(sourceFilter.value)}`,
      clear: () => { sourceFilter.value = null }
    })
  }
  if (destFilter.value) {
    chips.push({
      key: 'dest',
      label: `To: ${branchName(destFilter.value)}`,
      clear: () => { destFilter.value = null }
    })
  }
  if (datePreset.value !== 'all') {
    const preset = datePresets.find(d => d.value === datePreset.value)
    chips.push({
      key: 'date',
      label: datePreset.value === 'custom'
        ? `Dates: ${fromDate.value || 'start'} → ${toDate.value || 'today'}`
        : `Date: ${preset?.label || datePreset.value}`,
      clear: () => { datePreset.value = 'all'; fromDate.value = null; toDate.value = null }
    })
  }
  return chips
})

function clearFilters() {
  statusFilter.value = 'all'
  sourceFilter.value = null
  destFilter.value = null
  datePreset.value = 'all'
  fromDate.value = null
  toDate.value = null
  search.value = ''
}

function setStatus(v) {
  statusFilter.value = v || 'all'
}

// ── Aggregates ──────────────────────────────────────────────────────────
const openTransfers = computed(() =>
  transfers.value.filter(t => ['draft', 'requested', 'in_transit'].includes(t.status)))

const openPipelineValue = computed(() =>
  openTransfers.value.reduce((s, t) => s + (Number(t.total_value) || 0), 0))

const openRequestedValue = computed(() =>
  transfers.value.filter(t => t.status === 'requested')
    .reduce((s, t) => s + (Number(t.total_value) || 0), 0))

const inTransitValue = computed(() =>
  transfers.value.filter(t => t.status === 'in_transit')
    .reduce((s, t) => s + (Number(t.total_value) || 0), 0))

const weeklySpark = computed(() => {
  const out = []
  for (let i = 6; i >= 0; i--) {
    const d = new Date()
    d.setHours(0, 0, 0, 0)
    d.setDate(d.getDate() - i)
    const key = isoDay(d)
    out.push(transfers.value.filter(t => t.requested_at && String(t.requested_at).slice(0, 10) === key).length)
  }
  return out
})

const kpis = computed(() => {
  const s = stats.value
  const by = s?.by_status || {}
  return [
    {
      title: 'Total transfers',
      value: Number(s?.total ?? transfers.value.length).toLocaleString(),
      sub: `${by.draft || 0} drafts · ${by.completed || 0} completed`,
      icon: 'mdi-swap-horizontal-bold',
      color: 'teal',
      hint: `${weeklySpark.value.reduce((a, b) => a + b, 0)} created in 7 days`,
      spark: weeklySpark.value
    },
    {
      title: 'Awaiting approval',
      value: by.requested || 0,
      sub: 'requested by branches',
      icon: 'mdi-clock-alert-outline',
      color: 'amber',
      hint: `${formatMoney(openRequestedValue.value)} pending release`
    },
    {
      title: 'In transit',
      value: by.in_transit || 0,
      sub: 'on the road now',
      icon: 'mdi-truck-fast-outline',
      color: 'blue',
      hint: `${formatMoney(inTransitValue.value)} at cost`
    },
    {
      title: 'Completed this month',
      value: Number(s?.completed_this_month ?? 0),
      sub: s?.avg_cycle_hours != null ? `avg cycle ${s.avg_cycle_hours}h` : 'no cycle data',
      icon: 'mdi-check-all',
      color: 'green',
      hint: 'approved, shipped and received'
    },
    {
      title: 'Open pipeline',
      value: formatMoney(openPipelineValue.value),
      sub: `${openTransfers.value.length} active transfer(s)`,
      icon: 'mdi-cash-multiple',
      color: 'purple',
      hint: 'value at cost'
    },
    {
      title: 'Receipt variance',
      value: `${s?.variance_units ?? 0}`,
      sub: 'units short or over',
      icon: 'mdi-chart-timeline-variant',
      color: 'red',
      hint: 'across completed transfers'
    }
  ]
})

// ── Board ───────────────────────────────────────────────────────────────
const boardColumns = computed(() => {
  const cols = [
    { status: 'draft', label: 'Drafts', color: 'grey', icon: 'mdi-pencil-outline' },
    { status: 'requested', label: 'Awaiting approval', color: 'amber', icon: 'mdi-clock-outline' },
    { status: 'in_transit', label: 'In transit', color: 'blue', icon: 'mdi-truck-fast-outline' },
    { status: 'completed', label: 'Completed', color: 'green', icon: 'mdi-check-all' }
  ]
  if (statusCounts.value.approved) {
    cols.push({ status: 'approved', label: 'Approved', color: 'blue', icon: 'mdi-check-circle-outline' })
  }
  if (statusCounts.value.cancelled) {
    cols.push({ status: 'cancelled', label: 'Cancelled', color: 'red', icon: 'mdi-cancel' })
  }
  // Board items ignore the status chip (the column IS the status).
  return cols.map(c => {
    const items = baseFiltered.value.filter(t => t.status === c.status)
    return {
      ...c,
      items,
      value: items.reduce((s, t) => s + (Number(t.total_value) || 0), 0)
    }
  })
})

// ── List pagination ─────────────────────────────────────────────────────
const pageCount = computed(() => Math.max(1, Math.ceil(filtered.value.length / pageSize.value)))
const pagedTransfers = computed(() => {
  const start = (page.value - 1) * pageSize.value
  return filtered.value.slice(start, start + pageSize.value)
})
const rangeStart = computed(() => filtered.value.length ? ((page.value - 1) * pageSize.value) + 1 : 0)
const rangeEnd = computed(() => Math.min(filtered.value.length, page.value * pageSize.value))
function rowNumber(i) { return (page.value - 1) * pageSize.value + i + 1 }

// ── Create form helpers ─────────────────────────────────────────────────
const totalUnits = computed(() =>
  form.value.lines.reduce((s, l) => s + (Number(l.quantity) || 0), 0))

const totalValue = computed(() =>
  form.value.lines.reduce((s, l) => s + lineValue(l), 0))

const shortageWarnings = computed(() =>
  form.value.lines
    .filter(l => Number(l.quantity) > l.available)
    .map(l => `${l._name}: only ${l.available} on hand — requested ${l.quantity}.`))

const canRoute = computed(() =>
  !!form.value.source_branch && !!form.value.dest_branch &&
  form.value.source_branch !== form.value.dest_branch &&
  !!form.value.notes?.trim())

const itemsValid = computed(() =>
  form.value.lines.length > 0 &&
  form.value.lines.every(l => {
    const q = Number(l.quantity)
    return Number.isFinite(q) && q >= 1 && q <= l.available
  }))

const canSave = computed(() => canRoute.value && itemsValid.value)

const stepValid = computed(() => {
  const s = createStep.value
  if (s === 0) return canRoute.value
  if (s === 1) return itemsValid.value
  // steps 2 (cargo) and 3 (assignment) are always valid — all fields optional
  return true
})
const hasNextStep = computed(() => createStep.value < createSteps.length - 1)
const hasPrevStep = computed(() => createStep.value > 0)
const stepDone = (i) => createStep.value > i
const stepActive = (i) => createStep.value === i
const stepIcon = (s, i) => stepDone(i) ? 'mdi-check' : s.icon
const hasStepLine = (i) => i < createSteps.length - 1

function nextStep() {
  if (!stepValid.value) return
  if (createStep.value < createSteps.length - 1) createStep.value++
}
function prevStep() {
  if (createStep.value > 0) createStep.value--
}

function selectSource(id) {
  if (form.value.source_branch === id) return
  if (form.value.lines.length) {
    form.value.lines = []
    showSnack('Source changed — item lines were cleared. Add them again from the new source.', 'info')
  }
  form.value.source_branch = id
  if (form.value.dest_branch === id) form.value.dest_branch = null
  stockOptions.value = []
  picker.value = null
  batchSearchResults.value = []
  batchSearch.value = ''
}

function selectDest(id) {
  form.value.dest_branch = id
}

function swapBranches() {
  const s = form.value.source_branch
  form.value.source_branch = form.value.dest_branch
  form.value.dest_branch = s
  if (form.value.lines.length) {
    form.value.lines = []
    showSnack('Route swapped — item lines were cleared because availability changed.', 'info')
  }
  stockOptions.value = []
  picker.value = null
  batchSearchResults.value = []
  batchSearch.value = ''
}

function lineValue(l) {
  return (Number(l.quantity) || 0) * (Number(l._cost) || 0)
}

function isOver(l) { return Number(l.quantity) > Number(l.available) }
function atMin(l) { return Number(l.quantity) <= 1 }
function atMax(l) { return Number(l.quantity) >= Number(l.available) }

function stepQty(l, delta) {
  const next = (Number(l.quantity) || 1) + delta
  l.quantity = Math.max(1, Math.min(Number(l.available) || 1, next))
}
function clampQty(l) {
  const max = Number(l.available) || 1
  const q = Number(l.quantity)
  l.quantity = Number.isFinite(q) ? Math.max(1, Math.min(max, Math.round(q))) : 1
}
function removeLine(i) {
  form.value.lines.splice(i, 1)
}

function onStockSearch(q) {
  stockSearch.value = q || ''
  clearTimeout(stockTimer)
  stockTimer = setTimeout(async () => {
    if (!q || q.length < 1) { stockOptions.value = []; return }
    stockLoading.value = true
    try {
      const params = { search: q, is_active: true, page_size: 20 }
      if (form.value.source_branch) params.branch = form.value.source_branch
      const data = await $api.get('/inventory/stocks/', { params }).then(r => r.data?.results || r.data || [])
      stockOptions.value = Array.isArray(data) ? data : []
    } catch {
      stockOptions.value = []
    } finally {
      stockLoading.value = false
    }
  }, 250)
}

// Dismiss the search dropdown and blank the field so the next item can be
// searched immediately. Vuetify writes the selected item's title into its
// internal search state right after emitting the selection, so we also clear
// on the next tick to guarantee the field ends up empty.
function closeStockMenu() {
  stockOptions.value = []
  picker.value = null
  stockSearch.value = ''
  if (import.meta.client) {
    const field = stockPickerRef.value
    field?.blur?.()
    nextTick(() => {
      stockSearch.value = ''
    })
  }
}

// ── Batch-number search ────────────────────────────────────────────────────
function setSearchMode(mode) {
  if (itemSearchMode.value === mode) return
  itemSearchMode.value = mode
  batchSearch.value = ''
  batchSearchResults.value = []
  closeBatchPicker()
  closeStockMenu()
}

function onBatchSearch(q) {
  batchSearch.value = q || ''
  clearTimeout(batchSearchTimer)
  batchSearchTimer = setTimeout(async () => {
    const term = (q || '').trim()
    if (!term) { batchSearchResults.value = []; return }
    batchSearchLoading.value = true
    try {
      const params = { search: term, in_stock: 1, page_size: 50 }
      if (form.value.source_branch) params.branch = form.value.source_branch
      const data = await $api
        .get('/inventory/batches/', { params })
        .then(r => r.data?.results || r.data || [])
      batchSearchResults.value = (Array.isArray(data) ? data : []).map(b => ({
        ...b,
        selected: false,
        quantity: 1,
      }))
    } catch {
      batchSearchResults.value = []
    } finally {
      batchSearchLoading.value = false
    }
  }, 300)
}

function onBatchSearchToggle(b) {
  if (b.selected && (!b.quantity || b.quantity < 1)) b.quantity = 1
  if (b.selected && b.quantity > b.quantity_remaining) b.quantity = b.quantity_remaining
}

function toggleBatchSearchRow(b) {
  b.selected = !b.selected
  onBatchSearchToggle(b)
}

function clampBatchSearchQty(b) {
  const max = Number(b.quantity_remaining) || 1
  const q = Number(b.quantity)
  b.quantity = Number.isFinite(q) ? Math.max(1, Math.min(max, Math.round(q))) : 1
}

function selectAllBatchSearch() {
  batchSearchResults.value.forEach(b => {
    b.selected = true
    b.quantity = Number(b.quantity_remaining) || 1
  })
}

function clearBatchSearchSelection() {
  batchSearchResults.value.forEach(b => {
    b.selected = false
    b.quantity = 1
  })
}

function addSelectedBatchSearch() {
  const chosen = batchSearchSelected.value
  if (!chosen.length) return
  let added = 0
  chosen.forEach(b => {
    const stock = {
      id: b.stock,
      medication_name: b.stock_name,
      cost_price: b.cost_price_per_unit,
      total_quantity: b.stock_total_quantity ?? b.quantity_remaining,
      unit_abbreviation: b.stock_unit,
      batches: [],
    }
    const batch = {
      id: b.id,
      batch_number: b.batch_number,
      expiry_date: b.expiry_date,
      quantity_remaining: b.quantity_remaining,
      cost_price_per_unit: b.cost_price_per_unit,
    }
    const qty = Math.max(
      1,
      Math.min(Number(b.quantity) || 1, Number(b.quantity_remaining) || 1),
    )
    if (addStockLine(stock, batch, qty)) added += 1
  })
  if (added) {
    showSnack(
      `Added ${added} item line(s) from batch search`,
      'success',
    )
  }
  clearBatchSearchSelection()
}

// Replaces the old onAddStock (which dropped a single stock-level line).
// Now selecting a stock opens the batch picker so the user can either
// “select all” from one batch or pick items across batches.
function onPickStock(s) {
  if (!s) return
  batchPickerError.value = ''
  batchStock.value = s
  const srcBranch = form.value.source_branch
  const rows = ((s.batches || [])
    .filter(b => Number(b.quantity_remaining) > 0)
    // Prefer batches pinned to this warehouse — null/undefined branch is
    // treated as “any branch” (unspecified), still usable.
    .filter(b => !b.branch || b.branch === srcBranch)
    .sort((a, b) => (a.expiry_date || '').localeCompare(b.expiry_date || ''))
    .map(b => ({
      id: b.id,
      batch_number: b.batch_number || '—',
      expiry_date: b.expiry_date,
      is_expired: b.is_expired,
      quantity_remaining: Number(b.quantity_remaining) || 0,
      cost_price_per_unit: Number(b.cost_price_per_unit) || 0,
      selected: false,
      // Default each line to 1 unit; the user can raise it or press “All”.
      quantity: 1,
    }))
  )
  batchRows.value = rows

  if (!rows.length) {
    // Legacy item with no usable batches — give a one-line stock-level line.
    addStockLine(s, null, Math.min(1, Number(s.total_quantity) || 0))
    closeStockMenu()
    batchPickerOpen.value = false
    return
  }

  batchPickerOpen.value = true
  closeStockMenu()
}

function selectAllBatches() {
  batchRows.value.forEach(b => {
    b.selected = true
    b.quantity = b.quantity_remaining
  })
  batchPickerError.value = ''
}

function clearBatchSelection() {
  batchRows.value.forEach(b => { b.selected = false })
  batchPickerError.value = ''
}

function onBatchToggle(b) {
  if (b.selected && (!b.quantity || b.quantity < 1)) b.quantity = 1
  if (b.selected && b.quantity > b.quantity_remaining) b.quantity = b.quantity_remaining
  batchPickerError.value = ''
}

// Clicking anywhere on the row toggles the batch (nicer than hitting the
// small checkbox), except when the click lands on the quantity controls.
function toggleBatchRow(b) {
  b.selected = !b.selected
  onBatchToggle(b)
}

function clampBatchQty(b) {
  const max = b.quantity_remaining || 1
  const q = Number(b.quantity)
  b.quantity = Number.isFinite(q) ? Math.max(1, Math.min(max, Math.round(q))) : 1
}

function closeBatchPicker() {
  batchPickerOpen.value = false
  batchStock.value = null
  batchRows.value = []
  batchPickerError.value = ''
}

function addStockLine(stock, batch, quantity) {
  if (!stock) return null
  const available = batch ? Number(batch.quantity_remaining) || 0 : Number(stock.total_quantity) || 0
  if (available <= 0) {
    showSnack(`${stock.medication_name} has no stock available at the source warehouse`, 'warning')
    return null
  }
  const key = `${stock.id}:${batch ? batch.id : 'n'}:${++lineKeySeq.value}`
  const exists = form.value.lines.find(l =>
    l.stock === stock.id && (l._batch_id || null) === (batch ? batch.id : null))
  if (exists) {
    showSnack(
      `${stock.medication_name}${batch ? ' — Batch ' + (batch.batch_number || '') : ''} is already on this transfer — adjust its quantity instead`,
      'warning',
    )
    return null
  }
  form.value.lines.push({
    stock: stock.id,
    _key: key,
    _name: stock.medication_name,
    _cost: Number(stock.cost_price) || Number(batch?.cost_price_per_unit) || 0,
    _batch_id: batch ? batch.id : null,
    _batch_no: batch ? (batch.batch_number || '—') : null,
    _batch_exp: batch ? batch.expiry_date : null,
    _batch_remaining: batch ? Number(batch.quantity_remaining) || 0 : null,
    available,
    quantity: Math.max(1, Math.min(available, Number(quantity) || 1)),
  })
  return key
}

function addFullItem() {
  if (!batchStock.value) return
  addStockLine(batchStock.value, null, 1)
  closeBatchPicker()
}

function addSelectedBatches() {
  const chosen = batchRows.value.filter(b => b.selected)
  if (!chosen.length) {
    batchPickerError.value = 'Pick at least one batch to add.'
    return
  }
  let added = 0
  chosen.forEach(b => {
    const qty = Math.max(1, Math.min(b.quantity, b.quantity_remaining))
    if (addStockLine(batchStock.value, b, qty)) added += 1
  })
  if (added) {
    showSnack(`Added ${added} item line(s) from selected batches`, 'success')
  }
  closeBatchPicker()
}

// ── Load ────────────────────────────────────────────────────────────────
async function load() {
  loading.value = true
  try {
    const transferParams = { page_size: 500 }
    if (branchStore.currentBranchId) transferParams.branch = branchStore.currentBranchId
    const statsParams = {}
    if (branchStore.currentBranchId) statsParams.branch = branchStore.currentBranchId
    const [t, b, s] = await Promise.all([
      $api.get('/inventory/transfers/', { params: transferParams })
        .then(r => r.data?.results || r.data || []),
      $api.get(branchesApi.value).then(r => r.data?.results || r.data || []).catch(() => []),
      $api.get('/inventory/transfers/stats/', { params: statsParams }).then(r => r.data).catch(() => null)
    ])
    transfers.value = Array.isArray(t) ? t : []
    branches.value = Array.isArray(b) ? b : []
    stats.value = s

    // Load logistics resources for the assignment step (fire-and-forget).
    $api.get('/logistics/drivers/').then(r => { driverOptions.value = r.data?.results || r.data || [] }).catch(() => {})
    $api.get('/logistics/carriers/').then(r => { carrierOptions.value = r.data?.results || r.data || [] }).catch(() => {})
    $api.get('/logistics/vehicles/').then(r => {
      const list = r.data?.results || r.data || []
      vehicleOptions.value = (Array.isArray(list) ? list : []).map(v => ({
        id: v.id,
        label: v.display_name || `${v.plate_number}${v.name ? ' · ' + v.name : ''}`,
        plate_number: v.plate_number || '',
        vehicle_type: v.vehicle_type || 'other',
        status: v.status || 'available',
        is_active: v.is_active !== false,
      }))
    }).catch(() => {})
  } catch {
    showSnack('Failed to load transfers', 'error')
  } finally {
    loading.value = false
  }
}

function openCreate() {
  editingId.value = null
  editingReference.value = ''
  form.value = {
    source_branch: branchStore.currentBranchId || null,
    dest_branch: null,
    notes: '',
    lines: [],
    priority: 'normal',
    // 1 box preselected by default in the Cargo & schedule step.
    parcel_count: 1,
    weight_kg: null,
    scheduled_pickup: null,
    scheduled_delivery: null,
    assignment_type: null,
    driver_id: null,
    carrier_id: null,
    vehicle_id: null,
    vehicle_manual: '',
  }
  createStep.value = 0
  stockOptions.value = []
  picker.value = null
  stockSearch.value = ''
  itemSearchMode.value = 'item'
  batchSearch.value = ''
  batchSearchResults.value = []
  vehicleAutoFilled.value = false
  // Reset batch picker state so the drawer doesn't leak between sessions.
  batchPickerOpen.value = false
  batchStock.value = null
  batchRows.value = []
  batchPickerError.value = ''
  createDialog.value = true
}

// ── Edit an existing draft ─────────────────────────────────────────────
// Converts an ISO timestamp into the value a <input type="datetime-local">
// expects (local time, no seconds/timezone suffix).
function toLocalInput(iso) {
  if (!iso) return null
  const d = new Date(iso)
  if (isNaN(d)) return null
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}` +
         `T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

async function openEdit(t) {
  if (!t || t.status !== 'draft') {
    showSnack('Only draft transfers can be edited.', 'warning')
    return
  }
  let transfer = t
  // The list payload already carries lines, but re-fetch so edits always start
  // from the freshest server state (and include batch details).
  try {
    transfer = await $api.get(`/inventory/transfers/${t.id}/`).then(r => r.data)
  } catch {
    showSnack('Could not load this transfer for editing.', 'error')
    return
  }

  detailDialog.value = false
  editingId.value = transfer.id
  editingReference.value = transfer.reference

  const lines = (transfer.lines || []).map((l, i) => {
    const qty = Number(l.quantity) || 1
    const available = Number(
      l.batch ? (l.batch_quantity_remaining ?? l.in_stock) : l.in_stock
    ) || qty
    return {
      stock: l.stock,
      _key: `edit-${l.id ?? i}`,
      _name: l.stock_name,
      // Derive unit cost from the line value so the review totals stay exact.
      _cost: qty ? Number(l.line_value || 0) / qty : 0,
      _batch_id: l.batch || null,
      _batch_no: l.batch_number || null,
      _batch_exp: l.batch_expiry || null,
      _batch_remaining: l.batch ? Number(l.batch_quantity_remaining) || 0 : null,
      available,
      quantity: qty,
    }
  })

  form.value = {
    source_branch: transfer.source_branch,
    dest_branch: transfer.dest_branch,
    notes: transfer.notes || '',
    lines,
    priority: transfer.priority || 'normal',
    parcel_count: transfer.parcel_count ?? null,
    weight_kg: transfer.weight_kg != null ? Number(transfer.weight_kg) : null,
    scheduled_pickup: toLocalInput(transfer.scheduled_pickup),
    scheduled_delivery: toLocalInput(transfer.scheduled_delivery),
    assignment_type: transfer.assigned_driver
      ? 'internal'
      : transfer.assigned_carrier ? 'carrier' : null,
    driver_id: transfer.assigned_driver || null,
    carrier_id: transfer.assigned_carrier || null,
    vehicle_id: transfer.assigned_vehicle || null,
    vehicle_manual: transfer.assigned_vehicle ? '' : (transfer.assigned_vehicle_note || ''),
  }

  createStep.value = 0
  stockOptions.value = []
  picker.value = null
  stockSearch.value = ''
  itemSearchMode.value = 'item'
  batchSearch.value = ''
  batchSearchResults.value = []
  batchPickerOpen.value = false
  batchStock.value = null
  batchRows.value = []
  batchPickerError.value = ''
  vehicleAutoFilled.value = false

  // The driver watcher auto-fills the driver's default vehicle. Wait for it,
  // then restore whatever vehicle was actually saved on the transfer.
  await nextTick()
  form.value.vehicle_id = transfer.assigned_vehicle || null
  form.value.vehicle_manual = transfer.assigned_vehicle
    ? ''
    : (transfer.assigned_vehicle_note || '')
  vehicleAutoFilled.value = false

  createDialog.value = true
}

async function saveTransfer(submit) {
  if (!canSave.value || saving.value) return
  saving.value = true
  try {
    const payload = {
      source_branch: form.value.source_branch,
      dest_branch: form.value.dest_branch,
      notes: form.value.notes,
      priority: form.value.priority,
      parcel_count: form.value.parcel_count || null,
      weight_kg: form.value.weight_kg || null,
      scheduled_pickup: form.value.scheduled_pickup || null,
      scheduled_delivery: form.value.scheduled_delivery || null,
      assigned_driver: form.value.assignment_type === 'internal' ? form.value.driver_id : null,
      assigned_carrier: form.value.assignment_type === 'carrier' ? form.value.carrier_id : null,
      assigned_vehicle: form.value.vehicle_id || null,
      assigned_vehicle_note: form.value.vehicle_manual || '',
      lines: form.value.lines.map(l => ({
        stock: l.stock,
        quantity: Number(l.quantity),
        batch: l._batch_id || null,
      }))
    }
    const isEdit = !!editingId.value
    const saved = isEdit
      ? await $api.patch(`/inventory/transfers/${editingId.value}/`, payload).then(r => r.data)
      : await $api.post('/inventory/transfers/', payload).then(r => r.data)
    if (submit) {
      try {
        await $api.post(`/inventory/transfers/${saved.id}/submit/`)
      } catch (e2) {
        // The transfer exists as a draft; close the wizard so the user does
        // not accidentally create a duplicate by pressing submit again.
        showSnack(
          `${saved.reference} was saved as a draft, but could not be submitted: ` +
          (e2?.response?.data?.detail || 'please submit it from the list.'),
          'warning'
        )
        createDialog.value = false
        await load()
        return
      }
    }
    showSnack(
      submit
        ? `${saved.reference} submitted for approval`
        : isEdit
          ? `${saved.reference} updated`
          : `${saved.reference} saved as a draft`,
      'success'
    )
    createDialog.value = false
    // Keep the edit context until the dialog has finished closing so the
    // header doesn't flash back to "New stock transfer" mid-animation.
    // openCreate()/openEdit() reset it on the next open.
    await load()
  } catch (e) {
    const d = e?.response?.data
    if (d?.lines || d?.dest_branch || d?.detail) {
      const first = d.detail ?? Object.values(d)[0]
      showSnack(Array.isArray(first) ? first[0] : String(first), 'error')
    } else {
      showSnack('Failed to save transfer', 'error')
    }
  } finally {
    saving.value = false
  }
}

// ── Detail ──────────────────────────────────────────────────────────────
async function openDetail(t) {
  active.value = t
  detailDialog.value = true
  detailLoading.value = true
  try {
    active.value = await $api.get(`/inventory/transfers/${t.id}/`).then(r => r.data)
  } catch {
    showSnack('Failed to load transfer details', 'error')
  } finally {
    detailLoading.value = false
  }
}

const timeline = computed(() => {
  const a = active.value
  if (!a) return []
  const cancelled = a.status === 'cancelled'
  return [
    {
      key: 'requested',
      label: 'Requested',
      icon: 'mdi-file-document-outline',
      color: 'indigo',
      done: true,
      time: a.requested_at,
      meta: a.requested_by_name ? `Raised by ${a.requested_by_name}` : 'Raised'
    },
    {
      key: 'shipped',
      label: 'Approved and shipped',
      icon: 'mdi-truck-fast-outline',
      color: 'blue',
      done: !!a.shipped_at,
      time: a.shipped_at,
      meta: a.approved_by_name ? `Released by ${a.approved_by_name}` : 'Awaiting approval'
    },
    {
      key: 'received',
      label: cancelled ? 'Cancelled' : 'Received at destination',
      icon: cancelled ? 'mdi-cancel' : 'mdi-package-down',
      color: cancelled ? 'red' : 'green',
      done: cancelled || a.status === 'completed',
      time: a.received_at,
      meta: cancelled
        ? 'Cancelled before receipt'
        : (a.received_by_name ? `Received by ${a.received_by_name}` : 'Awaiting receipt')
    }
  ]
})

const transitHours = computed(() => {
  const a = active.value
  if (!a?.shipped_at) return null
  const hours = Math.round((Date.now() - new Date(a.shipped_at).getTime()) / 3600000)
  return hours >= 0 ? hours : null
})

const detailAgeText = computed(() => {
  const a = active.value
  if (!a?.requested_at) return ''
  return ageLabel(a.requested_at)
})

// ── Actions ─────────────────────────────────────────────────────────────
async function submitTransfer(t) {
  try {
    await $api.post(`/inventory/transfers/${t.id}/submit/`)
    showSnack(`${t.reference} submitted for approval`, 'success')
    detailDialog.value = false
    await load()
  } catch (e) {
    showSnack(e?.response?.data?.detail || 'Failed to submit transfer', 'error')
  }
}

function approve(t) {
  // Open the re-authentication dialog — password is required before the
  // approve-and-ship action is sent to the server.
  pendingAction.value = { type: 'approve', transfer: t }
  confirmPwd.value = ''
  confirmPwdVisible.value = false
  confirmPwdError.value = ''
  approveSignature.value = ''
  approveSigned.value = false
  detailDialog.value = false
  confirmDialog.value = true
}

async function doApprove(t) {
  try {
    await $api.post(`/inventory/transfers/${t.id}/approve/`, {
      signature: approveSignature.value || '',
    })
    showSnack(`${t.reference} approved — stock deducted from ${t.source_branch_name}`, 'success')
    confirmDialog.value = false
    detailDialog.value = false
    await load()
  } catch (e) {
    const d = e?.response?.data
    if (d?.shortages?.length) {
      showSnack(
        `Insufficient stock: ${d.shortages.map(s => `${s.stock} (need ${s.requested}, have ${s.available})`).join(', ')}`,
        'error'
      )
    } else {
      showSnack(d?.detail || 'Failed to approve transfer', 'error')
    }
  }}

function openReceive(t) {
  Promise.all([
    $api.get(`/inventory/transfers/${t.id}/`),
    $api.get(`/inventory/transfers/${t.id}/preview-receive/`).catch(() => null),
  ]).then(([res, preview]) => {
    active.value = res.data
    const previewMap = {}
    if (preview && preview.data && Array.isArray(preview.data.lines)) {
      preview.data.lines.forEach((p) => { previewMap[p.id] = p })
    }
    receiveLines.value = (res.data.lines || []).map(l => ({
      id: l.id,
      stock_name: l.stock_name,
      stock_unit: l.stock_unit,
      quantity: l.quantity,
      quantity_received: l.quantity,
      notes: l.notes || '',
      _cost: l.quantity > 0 ? (Number(l.line_value) || 0) / l.quantity : 0,
      exists_at_dest: previewMap[l.id]?.exists_at_dest ?? true,
      dest_stock_id: previewMap[l.id]?.dest_stock_id ?? null,
      quantity_at_dest: previewMap[l.id]?.quantity_at_dest ?? 0
    }))
    receiveSignature.value = ''
    receiveSigned.value = false
    detailDialog.value = false
    receiveDialog.value = true
  }).catch(() => showSnack('Failed to load transfer', 'error'))
}

// Items that are not currently stocked at the destination branch — they will
// be auto-created as new MedicationStock records on receipt.
const newItemsPreview = computed(() =>
  receiveLines.value.filter((l) => l.exists_at_dest === false)
)
const newItemsCount = computed(() => newItemsPreview.value.length)

function lineState(l) {
  const received = Number(l.quantity_received) || 0
  const diff = received - l.quantity
  if (received > l.quantity) {
    return { label: 'Exceeds sent', color: 'error', icon: 'mdi-alert', cls: 'trf-receive-line--error' }
  }
  if (diff === 0) return { label: 'Complete', color: 'success', icon: 'mdi-check', cls: '' }
  if (received === 0) return { label: 'Missing', color: 'error', icon: 'mdi-close', cls: 'trf-receive-line--missing' }
  return { label: `Short ${-diff}`, color: 'amber', icon: 'mdi-alert', cls: 'trf-receive-line--short' }
}

const receiveSummary = computed(() => {
  let sent = 0, received = 0, value = 0, sentValue = 0
  for (const l of receiveLines.value) {
    sent += Number(l.quantity) || 0
    sentValue += (Number(l.quantity) || 0) * l._cost
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

function atReceiveMin(l) { return Number(l.quantity_received) <= 0 }
function atReceiveMax(l) { return Number(l.quantity_received) >= l.quantity }

function stepReceive(l, delta) {
  const next = (Number(l.quantity_received) || 0) + delta
  l.quantity_received = Math.max(0, Math.min(l.quantity, next))
}
function clampReceive(l) {
  const q = Number(l.quantity_received)
  l.quantity_received = Number.isFinite(q) ? Math.max(0, Math.min(l.quantity, Math.round(q))) : 0
}
function setLineFull(l) { l.quantity_received = l.quantity }
function setLineNone(l) { l.quantity_received = 0 }

function receiveAll() {
  receiveLines.value.forEach(l => { l.quantity_received = l.quantity; l.notes = '' })
}

// Open the re-authentication dialog — password is required before the
// receive-and-book action is sent to the server. The Receive dialog stays open
// underneath so that line quantities are preserved in `receiveLines`.
function confirmReceive() {
  if (!active.value || !receiveValid.value) return
  if (!receiveSigned.value) {
    showSnack('Please sign in the signature box to confirm the receipt.', 'warning')
    return
  }
  pendingAction.value = { type: 'receive', transfer: active.value }
  confirmPwd.value = ''
  confirmPwdVisible.value = false
  confirmPwdError.value = ''
  confirmDialog.value = true
}

async function doReceive(t) {
  if (!receiveValid.value) return
  saving.value = true
  try {
    const res = await $api.post(`/inventory/transfers/${t.id}/receive/`, {
      signature: receiveSignature.value || '',
      lines: receiveLines.value.map(l => ({
        id: l.id,
        quantity_received: Number(l.quantity_received),
        ...(l.notes ? { notes: l.notes } : {})
      }))
    })
    const v = receiveSummary.value.variance
    const data = res?.data || {}
    const added = data.added_to_inventory || { count: 0, items: [] }
    const base =
      `${t.reference} received — ${receiveSummary.value.received} unit(s) booked into ${t.dest_branch_name}` +
      (v < 0 ? ` (shortfall ${-v})` : '')
    if (added.count > 0) {
      const names = (added.items || []).map(i => i.medication_name).slice(0, 3).join(', ')
      const suffix = added.count > 3 ? ` +${added.count - 3} more` : ''
      showSnack(
        `${base}
${added.count} new item${added.count === 1 ? '' : 's'} added to ${added.branch_name} inventory: ${names}${suffix}.`,
        'success'
      )
    } else {
      showSnack(base, 'success')
    }
    confirmDialog.value = false
    receiveDialog.value = false
    await load()
  } catch (e) {
    showSnack(e?.response?.data?.detail || 'Failed to receive transfer', 'error')
  } finally {
    saving.value = false
  }
}

function cancelTransfer(t) {
  // Open the re-authentication dialog — password is required before the
  // cancel-transfer action is sent to the server.
  pendingAction.value = { type: 'cancel', transfer: t }
  confirmPwd.value = ''
  confirmPwdVisible.value = false
  confirmPwdError.value = ''
  detailDialog.value = false
  confirmDialog.value = true
}

async function doCancelTransfer(t) {
  try {
    await $api.post(`/inventory/transfers/${t.id}/cancel/`)
    showSnack(`${t.reference} cancelled`, 'success')
    confirmDialog.value = false
    detailDialog.value = false
    await load()
  } catch (e) {
    showSnack(e?.response?.data?.detail || 'Failed to cancel transfer', 'error')
  }
}

async function doConfirmAction() {
  const action = pendingAction.value
  if (!action?.transfer) return
  if (!confirmPwd.value) {
    confirmPwdError.value = 'Enter your password to confirm.'
    return
  }
  if (action.type === 'approve' && !approveSigned.value) {
    showSnack('Please sign in the signature box before approving.', 'warning')
    return
  }
  confirmPwdError.value = ''
  saving.value = true
  try {
    await $api.post('/auth/verify-password/', { password: confirmPwd.value })
  } catch (e) {
    const msg = e?.response?.data?.detail
    confirmPwdError.value = msg || 'Password verification failed.'
    saving.value = false
    return
  }
  try {
    if (action.type === 'approve') {
      await doApprove(action.transfer)
    } else if (action.type === 'cancel') {
      await doCancelTransfer(action.transfer)
    } else if (action.type === 'receive') {
      await doReceive(action.transfer)
    }
  } finally {
    saving.value = false
  }
}

function canCancel(t) {
  return t && !['completed', 'cancelled'].includes(t.status)
}

// ── Exports ─────────────────────────────────────────────────────────────
async function printTransfer(t) {
  try {
    const blob = (await $api.get(`/inventory/transfers/${t.id}/pdf/`, { responseType: 'blob' })).data
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `transfer_${t.reference}.pdf`
    a.click()
    URL.revokeObjectURL(url)
  } catch {
    showSnack('Failed to generate the transfer PDF', 'error')
  }
}

async function exportCsv() {
  exporting.value = true
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
  } catch {
    showSnack('Export failed', 'error')
  } finally {
    exporting.value = false
  }
}

// ── Presentation helpers ────────────────────────────────────────────────
function statusLabel(s) {
  return ({
    draft: 'Draft',
    requested: 'Requested',
    approved: 'Approved',
    in_transit: 'In Transit',
    completed: 'Completed',
    cancelled: 'Cancelled'
  })[s] || s
}

function statusIcon(s) {
  return ({
    draft: 'mdi-pencil',
    requested: 'mdi-clock-outline',
    approved: 'mdi-check-circle-outline',
    in_transit: 'mdi-truck-fast',
    completed: 'mdi-check-all',
    cancelled: 'mdi-cancel'
  })[s] || 'mdi-circle-outline'
}

function stageInfo(t) {
  return ({
    draft: { pct: 15, color: 'grey', label: 'Draft' },
    requested: { pct: 40, color: 'amber', label: 'Awaiting approval' },
    approved: { pct: 55, color: 'blue', label: 'Approved' },
    in_transit: { pct: 75, color: 'blue', label: 'In transit' },
    completed: { pct: 100, color: 'success', label: 'Completed' },
    cancelled: { pct: 100, color: 'error', label: 'Cancelled' }
  })[t.status] || { pct: 0, color: 'grey', label: '—' }
}

function hoursSince(iso) {
  if (!iso) return null
  return (Date.now() - new Date(iso).getTime()) / 3600000
}

function ageLabel(iso) {
  const h = hoursSince(iso)
  if (h == null) return '—'
  if (h < 1) return 'just now'
  if (h < 24) return `${Math.floor(h)}h`
  const d = Math.floor(h / 24)
  const r = Math.floor(h % 24)
  return `${d}d${r ? ` ${r}h` : ''}`
}

function isAtRisk(t) {
  if (!t) return false
  if (t.status === 'requested') return (hoursSince(t.requested_at) ?? 0) > 24
  if (t.status === 'in_transit') return (hoursSince(t.shipped_at) ?? 0) > 48
  return false
}

function varianceClass(v) {
  const n = Number(v) || 0
  if (n < 0) return 'text-error'
  if (n > 0) return 'text-success'
  return 'text-medium-emphasis'
}

const isNeg = (v) => Number(v) < 0
const hasTimelineLine = (i) => i < timeline.value.length - 1
function isShortReceipt(t) {
  return !!t && t.status === 'completed' && Number(t.total_variance) < 0
}

function signed(v) {
  const n = Number(v) || 0
  return n > 0 ? `+${n}` : `${n}`
}

function itemsLabel(n) {
  return `${n} item${Number(n) === 1 ? '' : 's'}`
}

function unitsLabel(n) {
  return `${n} unit${Number(n) === 1 ? '' : 's'}`
}

function formatQty(v) {
  return Number(v ?? 0).toLocaleString()
}

function formatDateTime(d) {
  return d
    ? new Date(d).toLocaleString(undefined, {
        day: 'numeric',
        month: 'short',
        hour: '2-digit',
        minute: '2-digit'
      })
    : '—'
}

function formatDate(d) {
  if (!d) return '—'
  const date = new Date(d)
  if (isNaN(date)) return String(d)
  return date.toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' })
}

function showSnack(text, color = 'success') {
  Object.assign(snack, { show: true, color, text })
}

// ── Lifecycle ───────────────────────────────────────────────────────────
onMounted(load)

watch(() => branchStore.currentBranchId, () => load())

watch([search, statusFilter, sourceFilter, destFilter, datePreset, fromDate, toDate], () => {
  page.value = 1
})

// The board already groups by status, so a status chip would hide every column
// except one. Clear it whenever the user switches back to the board.
watch(viewMode, (v) => {
  if (v === 'board') statusFilter.value = 'all'
  if (import.meta.client) localStorage.setItem('ims-transfers-view', v)
})
</script>

<style scoped>
/* ═══════════════════════════ HERO ═══════════════════════════ */
.trf-hero {
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
.trf-hero-glow {
  position: absolute;
  width: 340px;
  height: 340px;
  border-radius: 50%;
  right: -110px;
  top: -170px;
  background: radial-gradient(circle, var(--hero-glow, rgba(255, 255, 255, 0.28)), transparent 68%);
  pointer-events: none;
}
.trf-hero-glow-2 {
  right: auto;
  left: -140px;
  top: auto;
  bottom: -220px;
  width: 300px;
  height: 300px;
  background: radial-gradient(circle, var(--hero-glow-2, rgba(55, 214, 255, 0.24)), transparent 70%);
}
.trf-hero-icon {
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
.trf-eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: rgba(255, 255, 255, 0.78);
}
.trf-title {
  font-size: 26px;
  line-height: 1.15;
  font-weight: 800;
  letter-spacing: -0.2px;
  margin: 2px 0;
}
.trf-sub {
  font-size: 13px;
  color: rgba(255, 255, 255, 0.82);
}
.trf-hero-iconbtn {
  color: #fff !important;
}
.trf-hero-btn-strong {
  background: #ffffff !important;
  color: var(--hero-ink, #143ce1) !important;
  font-weight: 700 !important;
  border: 1px solid rgba(255, 255, 255, 0.95) !important;
  box-shadow: 0 6px 18px rgba(6, 44, 40, 0.28) !important;
}
.trf-hero-btn-strong:hover {
  filter: brightness(0.94);
  box-shadow: 0 9px 24px rgba(6, 44, 40, 0.34) !important;
}
.trf-hero-btn-strong :deep(.v-icon) {
  color: var(--hero-ink, #143ce1) !important;
  opacity: 1 !important;
}
.trf-hero-btn-glass {
  background: rgba(255, 255, 255, 0.16) !important;
  color: #ffffff !important;
  font-weight: 600 !important;
  border: 1px solid rgba(255, 255, 255, 0.34) !important;
  backdrop-filter: blur(6px);
}
.trf-hero-btn-glass:hover {
  background: rgba(255, 255, 255, 0.26) !important;
  border-color: rgba(255, 255, 255, 0.6) !important;
}
.trf-hero-btn-glass :deep(.v-icon) {
  color: #ffffff !important;
  opacity: 1 !important;
}

.trf-hero-facts {
  position: relative;
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 18px;
  margin-top: 16px;
  padding-top: 14px;
  border-top: 1px solid rgba(255, 255, 255, 0.22);
}
.trf-hero-fact-value {
  font-size: 18px;
  font-weight: 800;
  line-height: 1.1;
}
.trf-hero-fact-label {
  font-size: 11px;
  color: rgba(255, 255, 255, 0.78);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
.trf-hero-divider {
  width: 1px;
  height: 26px;
  background: rgba(255, 255, 255, 0.24);
}

/* ═══════════════════════════ TOOLBAR ═══════════════════════════ */
.trf-search {
  flex: 1 1 320px;
  max-width: 460px;
}
.trf-select {
  width: 190px;
  flex: 0 0 auto;
}
.trf-date-field {
  width: 170px;
}
.trf-date-chips {
  overflow-x: auto;
  flex-wrap: nowrap;
}
.trf-toolbar {
  background: rgb(var(--v-theme-surface));
}

/* ═══════════════════════════ BOARD ═══════════════════════════ */
.trf-board {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
  gap: 14px;
  align-items: start;
}
.trf-col {
  display: flex;
  flex-direction: column;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
  border-radius: 16px;
  background: rgba(var(--v-theme-on-surface), 0.025);
  min-height: 180px;
}
.trf-col-head {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 13px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.07);
}
.trf-col-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}
.trf-col-title {
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.3px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.72);
}
.trf-col-value {
  font-size: 11px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.55);
  white-space: nowrap;
}
.trf-col-body {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 10px;
  flex-grow: 1;
}
.trf-col-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 26px 10px;
  border: 1px dashed rgba(var(--v-theme-on-surface), 0.14);
  border-radius: 12px;
  color: rgba(var(--v-theme-on-surface), 0.5);
}
.trf-card {
  padding: 12px;
  border-radius: 13px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
  background: rgb(var(--v-theme-surface));
  cursor: pointer;
  transition: transform 0.14s ease, box-shadow 0.14s ease, border-color 0.14s ease;
}
.trf-card:hover {
  transform: translateY(-1px);
  border-color: rgba(var(--v-theme-primary), 0.45);
  box-shadow: 0 10px 24px rgba(15, 23, 42, 0.09);
}
.trf-card-ref {
  font-size: 13px;
  font-weight: 800;
  letter-spacing: 0.2px;
}
.trf-card-route {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 6px;
}
.trf-route-arrow {
  color: rgba(var(--v-theme-on-surface), 0.4);
  flex-shrink: 0;
}
.trf-card-value {
  font-size: 13px;
  font-weight: 800;
}
.trf-risk {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  font-size: 10px;
  font-weight: 700;
  color: #b45309;
  background: rgba(245, 158, 11, 0.16);
  border-radius: 999px;
  padding: 1px 7px;
}

/* ═══════════════════════════ CHIPS + STATUS ═══════════════════════════ */
.trf-wh-chip {
  display: inline-flex;
  align-items: center;
  max-width: 190px;
  padding: 2px 8px;
  border-radius: 8px;
  font-size: 12px;
  font-weight: 600;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.09);
}
.trf-wh-chip-dest {
  color: #047857;
  background: rgba(16, 185, 129, 0.13);
}
.trf-status {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 11px;
  font-weight: 700;
  padding: 3px 9px;
  border-radius: 999px;
  white-space: nowrap;
}
.trf-status-draft {
  color: #475569;
  background: rgba(100, 116, 139, 0.15);
}
.trf-status-requested {
  color: #b45309;
  background: rgba(245, 158, 11, 0.16);
}
.trf-status-approved {
  color: #1d4ed8;
  background: rgba(59, 130, 246, 0.14);
}
.trf-status-in_transit {
  color: #0369a1;
  background: rgba(14, 165, 233, 0.16);
}
.trf-status-completed {
  color: #047857;
  background: rgba(16, 185, 129, 0.16);
}
.trf-status-cancelled {
  color: #b91c1c;
  background: rgba(239, 68, 68, 0.14);
}
.trf-route-cell {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 6px;
}

/* ═══════════════════════════ TABLE ═══════════════════════════ */
.trf-table-wrap {
  overflow-x: auto;
}
.trf-table {
  width: 100%;
  border-collapse: collapse;
}
.trf-table thead th {
  padding: 11px 14px;
  text-align: left;
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  white-space: nowrap;
  color: rgba(var(--v-theme-on-surface), 0.55);
  background: rgba(var(--v-theme-on-surface), 0.03);
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.08);
}
.trf-table tbody td {
  padding: 12px 14px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  vertical-align: middle;
}
.trf-table tbody tr:last-child td {
  border-bottom: none;
}
.trf-row {
  cursor: pointer;
  transition: background 0.12s ease;
}
.trf-row:hover {
  background: rgba(var(--v-theme-primary), 0.05);
}
.trf-rownum {
  width: 48px;
  color: rgba(var(--v-theme-on-surface), 0.5);
}
.trf-priority-chip {
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.01em;
  text-transform: none;
}

/* Urgent priority icon — pulses so it reads instantly in dense rows. */
.trf-urgent-blink {
  animation: trf-urgent-blink 1.1s ease-in-out infinite;
}
@keyframes trf-urgent-blink {
  0%, 100% {
    opacity: 1;
    transform: scale(1);
  }
  50% {
    opacity: 0.25;
    transform: scale(0.86);
  }
}
@media (prefers-reduced-motion: reduce) {
  .trf-urgent-blink {
    animation: none;
  }
}
.trf-avatar {
  width: 34px;
  height: 34px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.trf-av-draft { color: #475569; background: rgba(100, 116, 139, 0.14); }
.trf-av-requested { color: #b45309; background: rgba(245, 158, 11, 0.16); }
.trf-av-approved { color: #1d4ed8; background: rgba(59, 130, 246, 0.14); }
.trf-av-in_transit { color: #0369a1; background: rgba(14, 165, 233, 0.16); }
.trf-av-completed { color: #047857; background: rgba(16, 185, 129, 0.16); }
.trf-av-cancelled { color: #b91c1c; background: rgba(239, 68, 68, 0.14); }

/* ═══════════════════════════ CREATE WIZARD ═══════════════════════════ */
.trf-create-head,
.trf-receive-head,
.trf-detail-head {
  position: relative;
  overflow: hidden;
  padding: 16px 20px;
  color: #fff;
  background: linear-gradient(
    120deg,
    var(--hero-deep, #143ce1) 0%,
    var(--hero-main, #2f6dff) 52%,
    var(--hero-accent, #37d6ff) 100%
  );
}
.trf-head-chip {
  background: rgba(255, 255, 255, 0.2) !important;
  color: #fff !important;
  font-weight: 700;
  border: 1px solid rgba(255, 255, 255, 0.3);
}
.trf-steps {
  display: flex;
  align-items: center;
  padding-bottom: 4px;
}
.trf-step {
  display: flex;
  align-items: center;
  gap: 8px;
  opacity: 0.5;
  transition: opacity 0.18s ease;
}
.trf-step-active,
.trf-step-done {
  opacity: 1;
}
.trf-step-dot {
  width: 30px;
  height: 30px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(var(--v-theme-on-surface), 0.08);
  color: rgba(var(--v-theme-on-surface), 0.7);
  flex-shrink: 0;
}
.trf-step-active .trf-step-dot {
  background: rgb(var(--v-theme-primary));
  color: #fff;
  box-shadow: 0 4px 12px rgba(var(--v-theme-primary), 0.35);
}
.trf-step-done .trf-step-dot {
  background: rgba(16, 185, 129, 0.16);
  color: #047857;
}
.trf-step-text {
  font-size: 12px;
  font-weight: 700;
  white-space: nowrap;
}
.trf-step-line {
  flex: 1;
  height: 2px;
  margin: 0 12px;
  border-radius: 2px;
  background: rgba(var(--v-theme-on-surface), 0.12);
}
.trf-step-line-done {
  background: rgba(16, 185, 129, 0.45);
}
.trf-section-head {
  display: flex;
  align-items: center;
  gap: 12px;
}
.trf-section-index {
  width: 30px;
  height: 30px;
  border-radius: 9px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 11px;
  font-weight: 800;
  color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.1);
  flex-shrink: 0;
}
.trf-pick-label {
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 1px;
  text-transform: uppercase;
  color: rgb(var(--v-theme-primary));
  margin-bottom: 8px;
}
.trf-pick-label-dest {
  color: #047857;
}
.trf-wh-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(170px, 1fr));
  gap: 8px;
}
.trf-wh-card {
  text-align: left;
  border: 1.5px solid rgba(var(--v-theme-on-surface), 0.1);
  border-radius: 12px;
  background: rgb(var(--v-theme-surface));
  color: inherit;
  font: inherit;
  appearance: none;
  padding: 10px 11px;
  transition: border-color 0.14s ease, box-shadow 0.14s ease, transform 0.14s ease;
  cursor: pointer;
}
.trf-wh-card:hover {
  border-color: rgba(var(--v-theme-primary), 0.45);
  box-shadow: 0 6px 16px rgba(15, 23, 42, 0.07);
  transform: translateY(-1px);
}
.trf-wh-selected {
  border-color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.06);
}
.trf-wh-selected-dest {
  border-color: #10b981;
  background: rgba(16, 185, 129, 0.07);
}
.trf-wh-card-head {
  display: flex;
  align-items: center;
  gap: 6px;
}
.trf-wh-icon {
  width: 32px;
  height: 32px;
  border-radius: 9px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.11);
}
.trf-wh-icon-dest {
  color: #047857;
  background: rgba(16, 185, 129, 0.14);
}
.trf-wh-name {
  margin-top: 6px;
  font-size: 13px;
  font-weight: 700;
  line-height: 1.2;
}
.trf-wh-meta {
  font-size: 11px;
  color: rgba(var(--v-theme-on-surface), 0.55);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.trf-wh-stock {
  display: flex;
  align-items: center;
  gap: 4px;
  margin-top: 5px;
  font-size: 10.5px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.6);
}
.trf-wh-empty {
  min-height: 122px;
}

/* Lines editor */
.trf-lines {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
  border-radius: 13px;
  overflow: hidden;
}
.trf-lines-head,
.trf-item-row {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 168px 112px 40px;
  align-items: center;
  gap: 12px;
  padding: 10px 14px;
}
.trf-lines-head {
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.55);
  background: rgba(var(--v-theme-on-surface), 0.035);
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.08);
}
.trf-item-row {
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.trf-item-row:last-child {
  border-bottom: none;
}
.trf-item-over {
  background: rgba(239, 68, 68, 0.05);
}
.trf-item-main {
  display: flex;
  align-items: center;
  gap: 10px;
  min-width: 0;
}
.trf-item-name {
  font-size: 13px;
  font-weight: 600;
  line-height: 1.3;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.trf-item-sub {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 4px;
  margin-top: 2px;
  font-size: 11px;
  line-height: 1.5;
  color: rgba(var(--v-theme-on-surface), 0.56);
  white-space: nowrap;
}
.trf-item-batch {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  padding: 1px 7px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.01em;
  color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.1);
  border: 1px solid rgba(var(--v-theme-primary), 0.16);
}
.trf-item-nobatch {
  font-style: italic;
  opacity: 0.7;
}
.trf-item-dot {
  opacity: 0.4;
}
.trf-item-icon {
  width: 32px;
  height: 32px;
  border-radius: 9px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.1);
  flex-shrink: 0;
}
.trf-qty {
  display: flex;
  align-items: center;
  gap: 4px;
}
.trf-qty-input {
  width: 74px;
}
.trf-qty-input :deep(input) {
  text-align: center;
}
.trf-item-value {
  text-align: right;
  font-weight: 700;
  font-size: 13px;
}

/* ── Batch picker (step 2) ────────────────────────────────────────────── */
.trf-mode-switch {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 4px;
  border-radius: 13px;
  background: rgba(var(--v-theme-on-surface), 0.05);
  border: 1px solid rgba(var(--v-theme-on-surface), 0.07);
}
.trf-mode-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 7px 14px;
  border: none;
  border-radius: 10px;
  background: transparent;
  font-family: inherit;
  font-size: 12.5px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.66);
  cursor: pointer;
  transition: background 0.15s ease, color 0.15s ease, box-shadow 0.15s ease;
}
.trf-mode-btn:hover {
  color: rgba(var(--v-theme-on-surface), 0.9);
  background: rgba(var(--v-theme-on-surface), 0.05);
}
.trf-mode-btn.is-on {
  color: rgb(var(--v-theme-on-primary));
  background: rgb(var(--v-theme-primary));
  box-shadow: 0 3px 10px -5px rgba(var(--v-theme-primary), 0.95);
}
.trf-bs-hint {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  margin-top: 10px;
  padding: 10px 12px;
  border-radius: 11px;
  font-size: 12px;
  line-height: 1.5;
  color: rgba(var(--v-theme-on-surface), 0.62);
  background: rgba(var(--v-theme-on-surface), 0.035);
  border: 1px dashed rgba(var(--v-theme-on-surface), 0.12);
}
.trf-bs-hint code {
  padding: 1px 5px;
  border-radius: 5px;
  font-size: 11px;
  background: rgba(var(--v-theme-primary), 0.12);
  color: rgb(var(--v-theme-primary));
}
.trf-bs-sub { gap: 5px; }
.trf-bs-batch {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  padding: 1px 7px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.01em;
  color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.1);
  border: 1px solid rgba(var(--v-theme-primary), 0.16);
}

/* Batch picker panel */
.trf-bp {
  border: 1px solid rgba(var(--v-theme-primary), 0.18);
  border-radius: 16px;
  background: rgb(var(--v-theme-surface));
  overflow: hidden;
  box-shadow: 0 6px 22px -14px rgba(15, 23, 42, 0.35);
}

/* Header */
.trf-bp-head {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 14px;
  background: linear-gradient(
    90deg,
    rgba(var(--v-theme-primary), 0.1) 0%,
    rgba(var(--v-theme-primary), 0.03) 55%,
    transparent 100%
  );
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.07);
}
.trf-bp-head-icon {
  width: 38px;
  height: 38px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  color: rgb(var(--v-theme-on-primary));
  background: rgb(var(--v-theme-primary));
  box-shadow: 0 4px 12px -6px rgba(var(--v-theme-primary), 0.9);
}
.trf-bp-head-text { min-width: 0; }
.trf-bp-title {
  font-size: 14.5px;
  font-weight: 700;
  line-height: 1.25;
  letter-spacing: -0.01em;
  color: rgba(var(--v-theme-on-surface), 0.95);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.trf-bp-sub {
  font-size: 11.5px;
  color: rgba(var(--v-theme-on-surface), 0.58);
  margin-top: 1px;
}
.trf-bp-sep {
  display: inline-block;
  margin: 0 5px;
  opacity: 0.45;
}

/* Table head */
.trf-bp-thead,
.trf-bp-trow {
  display: grid;
  grid-template-columns:
    44px
    minmax(180px, 1fr)
    132px
    104px
    286px;
  align-items: center;
  column-gap: 12px;
  padding: 0 14px;
}
.trf-bp-thead {
  height: 34px;
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.07em;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.48);
  background: rgba(var(--v-theme-on-surface), 0.028);
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.07);
}
.trf-bp-thead > span {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

/* Rows */
.trf-bp-tbody { max-height: 258px; overflow-y: auto; }
.trf-bp-trow {
  min-height: 56px;
  padding-top: 7px;
  padding-bottom: 7px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.055);
  cursor: pointer;
  transition: background 0.14s ease, box-shadow 0.14s ease;
}
.trf-bp-trow:last-child { border-bottom: none; }
.trf-bp-trow:hover { background: rgba(var(--v-theme-primary), 0.035); }
.trf-bp-trow.is-on {
  background: rgba(var(--v-theme-primary), 0.06);
  box-shadow: inset 3px 0 0 rgb(var(--v-theme-primary));
}

.trf-bp-check {
  display: flex;
  align-items: center;
  justify-content: center;
}
.trf-bp-name { min-width: 0; }
.trf-bp-name-main {
  font-size: 12.5px;
  font-weight: 700;
  line-height: 1.3;
  color: rgba(var(--v-theme-on-surface), 0.92);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.trf-bp-name-sub {
  font-size: 11px;
  color: rgba(var(--v-theme-on-surface), 0.52);
  margin-top: 1px;
  white-space: nowrap;
}

.trf-bp-exp { min-width: 0; }
.trf-bp-exp-chip {
  font-weight: 600;
  letter-spacing: 0.01em;
}
.trf-bp-none {
  font-size: 11px;
  color: rgba(var(--v-theme-on-surface), 0.4);
}

.trf-bp-avail {
  text-align: right;
  white-space: nowrap;
}
.trf-bp-avail-num {
  font-size: 13px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  color: rgba(var(--v-theme-on-surface), 0.88);
}
.trf-bp-avail-unit {
  font-size: 10.5px;
  color: rgba(var(--v-theme-on-surface), 0.5);
  margin-left: 4px;
}

.trf-bp-send {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 4px;
}
.trf-bp-qty-input {
  width: 96px;
  flex: 0 0 96px;
}
.trf-bp-qty-input :deep(input) {
  text-align: center;
  font-variant-numeric: tabular-nums;
  font-weight: 600;
  font-size: 12.5px;
}
.trf-bp-all {
  min-width: 40px;
  padding: 0 8px;
  font-weight: 600;
}

/* Footer */
.trf-bp-foot {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 14px;
  background: rgba(var(--v-theme-on-surface), 0.025);
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.07);
}
.trf-bp-sel {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 11.5px;
  color: rgba(var(--v-theme-on-surface), 0.62);
}
.trf-bp-sel strong {
  color: rgba(var(--v-theme-on-surface), 0.9);
  font-variant-numeric: tabular-nums;
}
.trf-empty-lines {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 30px 12px;
  border: 1px dashed rgba(var(--v-theme-on-surface), 0.16);
  border-radius: 13px;
}
.trf-summary-strip {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 22px;
  padding: 12px 15px;
  border-radius: 13px;
  border: 1px solid rgba(var(--v-theme-primary), 0.18);
  background: rgba(var(--v-theme-primary), 0.045);
}
.trf-sum-item span {
  display: block;
  font-size: 10.5px;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.trf-sum-item strong {
  font-size: 16px;
  font-weight: 800;
}

/* Review */
.trf-review-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
  gap: 12px;
}
.trf-review-card {
  padding: 14px;
  border-radius: 13px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
  background: rgba(var(--v-theme-on-surface), 0.025);
}
.trf-review-label {
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.trf-review-lines {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
  border-radius: 13px;
  overflow: hidden;
}
.trf-review-line {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 10px 13px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.trf-review-line:last-child {
  border-bottom: none;
}
.trf-review-notes {
  padding: 12px 14px;
  border-radius: 12px;
  background: rgba(var(--v-theme-on-surface), 0.04);
}

/* ═══════════════════════════ DETAIL ═══════════════════════════ */
.trf-detail-status {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 11px;
  font-weight: 800;
  padding: 3px 10px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.2);
  border: 1px solid rgba(255, 255, 255, 0.32);
  color: #fff;
}
.trf-detail-route {
  padding: 2px 8px;
  border-radius: 7px;
  background: rgba(255, 255, 255, 0.16);
  font-weight: 700;
}
.trf-detail-stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  gap: 10px;
}
.trf-detail-stat {
  padding: 11px 14px;
  border-radius: 12px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  background: rgba(var(--v-theme-on-surface), 0.025);
}
.trf-detail-stat-label {
  font-size: 10px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.trf-detail-stat-value {
  font-size: 19px;
  font-weight: 800;
  line-height: 1.2;
  margin-top: 2px;
}
.trf-panel {
  padding: 14px;
  border-radius: 14px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
  background: rgb(var(--v-theme-surface));
}
.trf-panel-title {
  display: flex;
  align-items: center;
  gap: 7px;
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.02em;
  color: rgba(var(--v-theme-on-surface), 0.78);
}
.trf-meta-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 7px 0;
  font-size: 12.5px;
  border-bottom: 1px dashed rgba(var(--v-theme-on-surface), 0.08);
}
.trf-meta-row:last-child {
  border-bottom: none;
}
.trf-meta-row span {
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.trf-meta-row strong {
  font-weight: 700;
  text-align: right;
}
.trf-risk-banner {
  display: flex;
  align-items: center;
  gap: 7px;
  padding: 8px 11px;
  border-radius: 10px;
  font-size: 11.5px;
  font-weight: 600;
  color: #92400e;
  background: rgba(245, 158, 11, 0.14);
}
.trf-timeline {
  display: flex;
  flex-direction: column;
}
.trf-tl-step {
  display: flex;
  gap: 12px;
}
.trf-tl-node {
  width: 30px;
  height: 30px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  color: rgba(var(--v-theme-on-surface), 0.45);
  background: rgba(var(--v-theme-on-surface), 0.07);
}
.trf-tl-node-done {
  color: #fff;
  background: linear-gradient(135deg, #0ea5e9, #2563eb);
  box-shadow: 0 4px 10px rgba(37, 99, 235, 0.28);
}
.trf-tl-label {
  font-size: 13px;
  font-weight: 700;
}
.trf-tl-body {
  padding-bottom: 10px;
  min-width: 0;
}
.trf-tl-line {
  width: 2px;
  height: 18px;
  margin-left: 14px;
  border-radius: 2px;
  background: rgba(var(--v-theme-on-surface), 0.12);
}
.trf-tl-line-done {
  background: rgba(37, 99, 235, 0.35);
}
.trf-detail-table thead th {
  background: rgba(var(--v-theme-on-surface), 0.03);
}

/* ═══════════════════════════ RECEIVE ═══════════════════════════ */
.trf-receive-line {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.1);
  border-radius: 12px;
  padding: 11px 13px;
  margin-bottom: 10px;
  background: rgba(var(--v-theme-on-surface), 0.015);
}
.trf-receive-line--short {
  border-color: rgba(245, 158, 11, 0.55);
  background: rgba(245, 158, 11, 0.05);
}
.trf-receive-line--missing {
  border-color: rgba(239, 68, 68, 0.55);
  background: rgba(239, 68, 68, 0.05);
}
.trf-receive-line--error {
  border-color: rgba(239, 68, 68, 0.8);
}
.trf-receive-qty {
  width: 86px;
}
.trf-receive-summary {
  padding: 14px;
  border-radius: 13px;
  border: 1px solid rgba(var(--v-theme-primary), 0.2);
  background: rgba(var(--v-theme-primary), 0.04);
}
.trf-newitems-banner {
  border: 1px solid rgba(16, 185, 129, 0.35);
  background: rgba(16, 185, 129, 0.08);
}

/* ═══════════════════════════ RESPONSIVE ═══════════════════════════ */
@media (max-width: 960px) {
  .trf-hero-divider-lg {
    display: none;
  }
  .trf-lines-head,
  .trf-item-row {
    grid-template-columns: minmax(0, 1fr) 150px 96px 36px;
  }
  .trf-bp-thead,
  .trf-bp-trow {
    grid-template-columns:
      36px
      minmax(0, 1fr)
      102px
      72px
      232px;
    column-gap: 8px;
    padding: 0 10px;
  }
  .trf-bp-qty-input {
    width: 82px;
    flex: 0 0 82px;
  }
  .trf-bp-all {
    min-width: 32px;
    padding: 0 5px;
  }
}
@media (max-width: 760px) {
  .trf-bp-thead { display: none; }
  .trf-bp-trow {
    grid-template-columns: 36px minmax(0, 1fr) auto;
    row-gap: 6px;
    padding: 9px 10px;
  }
  .trf-bp-exp { grid-column: 2 / 3; }
  .trf-bp-avail { grid-column: 3 / 4; }
  .trf-bp-send {
    grid-column: 2 / -1;
    justify-content: flex-start;
  }
  .trf-bp-foot {
    flex-wrap: wrap;
  }
}
@media (max-width: 700px) {
  .trf-search,
  .trf-select {
    width: 100%;
    max-width: none;
    flex: 1 1 100%;
  }
  .trf-lines-head {
    display: none;
  }
  .trf-item-row {
    grid-template-columns: minmax(0, 1fr) auto;
    row-gap: 8px;
  }
  .trf-item-value {
    text-align: left;
  }
  .trf-step-text {
    display: none;
  }
  .trf-step-line {
    margin: 0 6px;
  }
}

/* ── Cargo & Assignment cards ──────────────────────────────────────────── */
.trf-priority-card,
.trf-assign-card {
  transition: border-color .15s ease, box-shadow .15s ease;
}
.trf-priority-card:hover,
.trf-assign-card:hover {
  box-shadow: 0 4px 16px rgba(0, 0, 0, .10);
}
.cursor-pointer {
  cursor: pointer;
}

/* ── Detail dialog meta grid ────────────────────────────────────────────── */
.trf-detail-meta-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
  gap: 12px;
}
.trf-detail-meta-item {
  min-width: 0;
}
.trf-detail-meta-label {
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: .05em;
  color: rgba(var(--v-theme-on-surface), .55);
  margin-bottom: 2px;
}
.trf-detail-meta-value {
  font-weight: 500;
  font-size: 14px;
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 4px;
}

/* ── Saved digital signatures (detail dialog) ───────────────────────────── */
.trf-sig-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 12px;
}
.trf-sig-card {
  padding: 10px 12px;
  border-radius: 12px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
  background: rgba(var(--v-theme-on-surface), 0.025);
}
.trf-sig-img {
  display: block;
  max-width: 100%;
  max-height: 64px;
  margin: 4px 0 6px;
  padding: 4px;
  border-radius: 8px;
  background: #fff;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  object-fit: contain;
}
.trf-sig-missing {
  margin: 6px 0;
  font-size: 12px;
  font-style: italic;
  color: rgba(var(--v-theme-on-surface), 0.42);
}
.trf-sig-meta {
  font-size: 11.5px;
  font-weight: 500;
  color: rgba(var(--v-theme-on-surface), 0.66);
}
</style>
