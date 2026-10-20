<template>
  <v-container fluid class="pa-3 pa-md-5 lg-page">
    <LogiHero
      icon="mdi-truck-fast-outline"
      eyebrow="IMS · LOGISTICS · SHIPMENTS"
      title="Shipments"
      subtitle="Inventory transfers, customer deliveries, supplier pickups and returns — one manifest for every movement."
      :facts="heroFacts"
    >
      <template #actions>
        <v-btn icon="mdi-refresh" variant="text" size="small" class="lg-hero-iconbtn" title="Refresh" :loading="loading" @click="load" />
        <v-btn variant="flat" elevation="0" rounded="lg" class="text-none lg-hero-btn-glass" prepend-icon="mdi-file-delimited-outline" :loading="exporting" @click="exportCsv">
          Export CSV
        </v-btn>
        <v-btn variant="flat" elevation="0" rounded="lg" class="text-none lg-hero-btn-strong" prepend-icon="mdi-plus" @click="openCreate">
          New Shipment
        </v-btn>
      </template>
    </LogiHero>

    <v-row dense class="mb-4">
      <v-col v-for="k in kpis" :key="k.title" cols="6" sm="4" md="4" lg="2">
        <KpiTile :title="k.title" :value="k.value" :sub="k.sub" :icon="k.icon" :color="k.color" :hint="k.hint" flat />
      </v-col>
    </v-row>

    <v-card rounded="xl" border class="mb-3">
      <div class="d-flex flex-wrap align-center ga-3 pa-3">
        <v-text-field
          v-model="search"
          placeholder="Search reference, tracking no., origin, destination, contact…"
          prepend-inner-icon="mdi-magnify"
          density="comfortable"
          variant="solo-filled"
          rounded="lg"
          flat
          bg-color="surface"
          hide-details
          clearable
          class="lg-search"
          @keyup.enter="pageInfo.page = 1; load()"
          @click:clear="pageInfo.page = 1; load()"
        />
        <v-select
          v-model="filters.movement_type"
          :items="movementTypes"
          item-title="label"
          item-value="value"
          label="Movement"
          density="compact"
          variant="outlined"
          rounded="lg"
          hide-details
          clearable
          prepend-inner-icon="mdi-swap-horizontal-bold"
          class="lg-select"
          @update:model-value="pageInfo.page = 1; load()"
        />
        <v-select
          v-model="filters.priority"
          :items="priorityOptions"
          item-title="label"
          item-value="value"
          label="Priority"
          density="compact"
          variant="outlined"
          rounded="lg"
          hide-details
          clearable
          prepend-inner-icon="mdi-flag-outline"
          class="lg-select-sm"
          @update:model-value="pageInfo.page = 1; load()"
        />
        <v-spacer class="d-none d-md-flex" />
        <v-btn-toggle v-model="viewMode" density="comfortable" rounded="lg" variant="outlined" divided mandatory>
          <v-btn value="board" icon="mdi-view-column-outline" size="small" title="Board view" />
          <v-btn value="list" icon="mdi-format-list-bulleted" size="small" title="List view" />
        </v-btn-toggle>
      </div>

      <v-divider />

      <div class="d-flex flex-wrap align-center ga-2 pa-3">
        <v-chip-group :model-value="filters.status" selected-class="text-primary" mandatory class="lg-status-chips">
          <v-chip
            v-for="s in statusChips"
            :key="s.value"
            :value="s.value"
            size="small"
            rounded="lg"
            variant="tonal"
            class="text-none"
            @click="setStatus(s.value)"
          >
            <v-icon v-if="s.icon" start size="15">{{ s.icon }}</v-icon>
            {{ s.label }}
            <span class="ml-1 font-weight-bold">{{ s.count }}</span>
          </v-chip>
        </v-chip-group>
        <v-spacer />
        <v-btn variant="text" size="small" color="error" class="text-none" prepend-icon="mdi-filter-remove-outline" :disabled="!hasFilters" @click="clearFilters">
          Clear
        </v-btn>
      </div>
    </v-card>

    <!-- BOARD -->
    <div v-if="viewMode === 'board'" class="lg-board">
      <div v-for="col in boardColumns" :key="col.status" class="lg-board-col">
        <div class="lg-board-head">
          <div class="d-flex align-center ga-2">
            <span class="lg-board-dot" :class="`lg-dot--${col.status}`" />
            <span class="font-weight-bold text-body-2">{{ col.label }}</span>
          </div>
          <v-chip size="x-small" variant="tonal" :color="col.color" class="font-weight-bold">{{ col.count }}</v-chip>
        </div>
        <div class="lg-board-body">
          <div
            v-for="s in col.rows"
            :key="s.id"
            class="lg-ship-card"
            :class="{ 'lg-ship-card--late': s.is_late }"
            @click="openDetail(s)"
          >
            <div class="d-flex align-center justify-space-between ga-2">
              <span class="lg-ship-ref">{{ s.reference }}</span>
              <v-chip size="x-small" variant="tonal" :color="priorityOf(s.priority).color" class="font-weight-bold">
                <v-icon start size="11">{{ priorityOf(s.priority).icon }}</v-icon>
                {{ priorityOf(s.priority).label }}
              </v-chip>
            </div>
            <div class="lg-ship-route mt-2">
              <span class="lg-wh-chip">{{ s.origin_name || '—' }}</span>
              <v-icon size="13" color="medium-emphasis">mdi-arrow-right</v-icon>
              <span class="lg-wh-chip lg-wh-chip--dest">{{ s.dest_name || '—' }}</span>
            </div>
            <div class="d-flex align-center justify-space-between mt-3">
              <div class="text-caption text-medium-emphasis">
                {{ typeOf(s.movement_type).label }}
                <span v-if="s.requires_refrigeration" class="d-inline-flex align-center ga-1 ml-1">
                  <v-icon size="12" color="info">mdi-snowflake</v-icon>
                </span>
              </div>
              <div class="lg-ship-cost">{{ formatMoney(s.total_cost || 0) }}</div>
            </div>
            <div class="d-flex align-center justify-space-between mt-2 text-caption">
              <span class="d-flex align-center ga-1 text-medium-emphasis">
                <v-icon size="13">mdi-account-outline</v-icon>
                {{ s.driver_name || s.carrier_name || 'Unassigned' }}
              </span>
              <span :class="s.is_late ? 'text-error font-weight-medium' : 'text-medium-emphasis'">
                {{ etaLabel(s) }}
              </span>
            </div>
          </div>
          <div v-if="!col.rows.length" class="lg-board-empty">
            <v-icon size="30" color="medium-emphasis">mdi-tray</v-icon>
            <div class="text-caption text-medium-emphasis mt-1">Nothing here</div>
          </div>
        </div>
      </div>
    </div>

    <!-- LIST -->
    <v-card v-else rounded="xl" border>
      <v-table density="comfortable" class="lg-table">
        <thead>
          <tr>
            <th class="text-center" style="width:42px">#</th>
            <th>Reference</th>
            <th>Movement</th>
            <th>Route</th>
            <th>Driver / carrier</th>
            <th>Priority</th>
            <th>Status</th>
            <th>Scheduled</th>
            <th class="text-right">Cost</th>
            <th />
          </tr>
        </thead>
        <tbody>
          <tr v-for="(s, i) in rows" :key="s.id" class="lg-row" @click="openDetail(s)">
            <td class="text-center text-caption text-medium-emphasis">{{ i + 1 }}</td>
            <td>
              <div class="font-weight-medium">{{ s.reference }}</div>
              <div class="text-caption text-medium-emphasis">{{ s.tracking_number }}</div>
            </td>
            <td>
              <v-chip size="x-small" variant="tonal" :color="typeOf(s.movement_type).color">
                <v-icon start size="12">{{ typeOf(s.movement_type).icon }}</v-icon>
                {{ typeOf(s.movement_type).label }}
              </v-chip>
            </td>
            <td>
              <div class="d-flex align-center ga-1 text-body-2">
                <span class="text-truncate" style="max-width:160px">{{ s.origin_name || '—' }}</span>
                <v-icon size="13" color="medium-emphasis">mdi-arrow-right</v-icon>
                <span class="text-truncate" style="max-width:160px">{{ s.dest_name || '—' }}</span>
              </div>
              <div class="text-caption text-medium-emphasis">{{ s.dest_address || '' }}</div>
            </td>
            <td>
              <div class="text-body-2">{{ s.driver_name || s.carrier_name || 'Unassigned' }}</div>
              <div class="text-caption text-medium-emphasis">{{ s.vehicle_plate || '—' }}</div>
            </td>
            <td>
              <v-chip size="x-small" variant="tonal" :color="priorityOf(s.priority).color" class="font-weight-medium">
                {{ priorityOf(s.priority).label }}
              </v-chip>
            </td>
            <td>
              <v-chip size="small" variant="tonal" :color="statusOf(s.status).color">
                <v-icon start size="13">{{ statusOf(s.status).icon }}</v-icon>
                {{ statusOf(s.status).label }}
              </v-chip>
            </td>
            <td>
              <div class="text-body-2" :class="s.is_late ? 'text-error font-weight-medium' : ''">{{ etaLabel(s) }}</div>
              <div v-if="s.is_late" class="text-caption text-error">Past ETA</div>
            </td>
            <td class="text-right font-weight-medium">{{ formatMoney(s.total_cost || 0) }}</td>
            <td class="text-right">
              <v-btn icon="mdi-chevron-right" size="x-small" variant="text" />
            </td>
          </tr>
          <tr v-if="!rows.length">
            <td colspan="10">
              <div class="lg-empty pa-6">
                <v-icon size="42" color="medium-emphasis">mdi-truck-outline</v-icon>
                <div class="text-body-2 font-weight-medium mt-2">No shipments match your filters</div>
                <div class="text-caption text-medium-emphasis">Try clearing filters or create a new shipment.</div>
              </div>
            </td>
          </tr>
        </tbody>
      </v-table>
      <v-divider />
      <div class="d-flex align-center justify-space-between pa-3">
        <div class="text-caption text-medium-emphasis">
          {{ pageInfo.total }} shipment{{ pageInfo.total === 1 ? '' : 's' }}
          <span v-if="pageInfo.total"> · page {{ pageInfo.page }} of {{ pageCount }}</span>
        </div>
        <v-pagination
          v-model="pageInfo.page"
          :length="pageCount"
          :total-visible="7"
          density="comfortable"
          rounded
          @update:model-value="load()"
        />
        <v-select
          v-model="pageInfo.perPage"
          :items="[10, 15, 25, 50, 100]"
          label="Per page"
          variant="outlined"
          density="compact"
          hide-details
          style="max-width: 120px"
          @update:model-value="pageInfo.page = 1; load()"
        />
      </div>
    </v-card>

    <!-- ═════════════ CREATE WIZARD ═════════════ -->
    <v-dialog v-model="createDialog" max-width="900" persistent scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader
          icon="mdi-plus"
          title="New shipment"
          :subtitle="`Step ${createStep + 1} of ${createSteps.length} · ${createSteps[createStep].label}`"
          :closable="true"
          @close="createDialog = false"
        >
          <div class="lg-step-track mt-3">
            <template v-for="(st, i) in createSteps" :key="st.label">
              <div class="lg-step" :class="stepClass(i)">
                <v-icon size="14">{{ stepIcon(i) }}</v-icon>
                <span>{{ st.label }}</span>
              </div>
              <div v-if="i < createSteps.length - 1" class="lg-step-line" :class="{ 'lg-step-line--done': stepDone(i) }" />
            </template>
          </div>
        </BrandDialogHeader>

        <v-card-text class="pt-5">
          <!-- Step 1: movement -->
          <template v-if="createStep === 0">
            <div class="text-subtitle-2 mb-2">Movement type</div>
            <div class="lg-type-grid mb-4">
              <button
                v-for="m in movementTypes"
                :key="m.value"
                type="button"
                class="lg-type-card"
                :class="{ 'lg-type-card--on': form.movement_type === m.value }"
                @click="selectMovement(m.value)"
              >
                <v-icon :color="m.color" size="22">{{ m.icon }}</v-icon>
                <div class="text-body-2 font-weight-medium mt-1">{{ m.label }}</div>
              </button>
            </div>

            <!-- ═══ Internal transfer / Intercompany: From → To warehouse ═══ -->
            <template v-if="isWarehouseMove">
              <div class="text-subtitle-2 mb-2">
                <v-icon size="16" class="mr-1" color="primary">mdi-warehouse</v-icon>
                From warehouse → To warehouse
              </div>
              <v-row dense>
                <v-col cols="12" md="6">
                  <v-select
                    v-model="form.from_branch"
                    :items="branchOptions"
                    item-title="name"
                    item-value="id"
                    label="From warehouse *"
                    variant="outlined"
                    density="comfortable"
                    prepend-inner-icon="mdi-warehouse"
                    return-object
                    @update:model-value="onFromBranch"
                  />
                </v-col>
                <v-col cols="12" md="6">
                  <v-select
                    v-model="form.to_branch"
                    :items="branchOptions"
                    item-title="name"
                    item-value="id"
                    label="To warehouse *"
                    variant="outlined"
                    density="comfortable"
                    prepend-inner-icon="mdi-map-marker-check-outline"
                    return-object
                    @update:model-value="onToBranch"
                  />
                </v-col>
              </v-row>
              <v-alert v-if="form.from_branch && form.to_branch && form.from_branch.id === form.to_branch.id" type="warning" variant="tonal" density="compact" class="mt-2" rounded="lg">
                From and To warehouse cannot be the same.
              </v-alert>
            </template>

            <!-- ═══ Customer delivery / return: Select existing or walk-in ═══ -->
            <template v-else-if="isCustomerMove">
              <div class="text-subtitle-2 mb-2">
                <v-icon size="16" class="mr-1" color="teal">mdi-account-arrow-right-outline</v-icon>
                {{ form.movement_type === 'customer_return' ? 'Returning customer' : 'Deliver to customer' }}
              </div>
              <v-row dense>
                <v-col cols="12">
                  <v-switch
                    v-model="form.is_walkin"
                    color="primary"
                    density="compact"
                    hide-details
                    :label="form.is_walkin ? 'Walk-in customer (manual entry)' : 'Existing customer (search from CRM)'"
                    class="mb-2"
                  />
                </v-col>
              </v-row>
              <template v-if="!form.is_walkin">
                <v-row dense>
                  <v-col cols="12">
                    <v-autocomplete
                      v-model="form.customer_id"
                      :items="customerOptions"
                      item-title="label"
                      item-value="id"
                      label="Search customer *"
                      variant="outlined"
                      density="comfortable"
                      prepend-inner-icon="mdi-account-search-outline"
                      placeholder="Type name or phone…"
                      clearable
                      return-object
                      @update:model-value="onCustomerSelect"
                    />
                  </v-col>
                </v-row>
              </template>
              <v-row dense>
                <v-col cols="12" md="6">
                  <v-text-field v-model="form.dest_name" :label="form.is_walkin ? 'Customer name *' : 'Customer name'" variant="outlined" density="comfortable" prepend-inner-icon="mdi-account-outline" />
                </v-col>
                <v-col cols="12" md="6">
                  <v-text-field v-model="form.dest_contact" label="Contact person" variant="outlined" density="comfortable" prepend-inner-icon="mdi-account-check-outline" />
                </v-col>
                <v-col cols="12" md="6">
                  <v-text-field v-model="form.dest_phone" label="Phone" variant="outlined" density="comfortable" prepend-inner-icon="mdi-phone-outline" />
                </v-col>
                <v-col cols="12" md="6">
                  <v-text-field v-model="form.dest_address_1" label="Delivery address" variant="outlined" density="comfortable" prepend-inner-icon="mdi-map-marker-radius-outline" />
                </v-col>
                <v-col cols="12">
                  <v-textarea v-model="form.dest_address" label="Full address / directions" rows="2" auto-grow variant="outlined" density="comfortable" />
                </v-col>
              </v-row>
              <!-- Origin defaults to current branch for customer delivery -->
              <v-row dense>
                <v-col cols="12">
                  <v-select
                    v-model="form.from_branch"
                    :items="branchOptions"
                    item-title="name"
                    item-value="id"
                    label="Dispatch from warehouse"
                    variant="outlined"
                    density="comfortable"
                    prepend-inner-icon="mdi-warehouse"
                    return-object
                    @update:model-value="onFromBranch"
                  />
                </v-col>
              </v-row>
            </template>

            <!-- ═══ Supplier pickup / return: manual origin/dest ═══ -->
            <template v-else>
              <div class="text-subtitle-2 mb-2">
                <v-icon size="16" class="mr-1" color="amber">mdi-truck-arrow-left-outline</v-icon>
                Origin & destination details
              </div>
              <v-row dense>
                <v-col cols="12" md="6">
                  <v-text-field v-model="form.origin_name" label="Origin name *" variant="outlined" density="comfortable" prepend-inner-icon="mdi-map-marker-outline" />
                </v-col>
                <v-col cols="12" md="6">
                  <v-text-field v-model="form.dest_name" label="Destination name *" variant="outlined" density="comfortable" prepend-inner-icon="mdi-map-marker-check-outline" />
                </v-col>
                <v-col cols="12" md="6">
                  <v-textarea v-model="form.origin_address" label="Origin address" rows="2" auto-grow variant="outlined" density="comfortable" />
                </v-col>
                <v-col cols="12" md="6">
                  <v-textarea v-model="form.dest_address" label="Destination address" rows="2" auto-grow variant="outlined" density="comfortable" />
                </v-col>
                <v-col cols="12" md="6">
                  <v-text-field v-model="form.origin_contact" label="Origin contact" variant="outlined" density="comfortable" prepend-inner-icon="mdi-account-outline" />
                </v-col>
                <v-col cols="12" md="6">
                  <v-text-field v-model="form.dest_contact" label="Destination contact" variant="outlined" density="comfortable" prepend-inner-icon="mdi-account-check-outline" />
                </v-col>
                <v-col cols="12" md="6">
                  <v-text-field v-model="form.origin_phone" label="Origin phone" variant="outlined" density="comfortable" prepend-inner-icon="mdi-phone-outline" />
                </v-col>
                <v-col cols="12" md="6">
                  <v-text-field v-model="form.dest_phone" label="Destination phone" variant="outlined" density="comfortable" prepend-inner-icon="mdi-phone-check-outline" />
                </v-col>
              </v-row>
            </template>
          </template>

          <!-- Step 2: cargo + schedule -->
          <template v-else-if="createStep === 1">
            <v-row dense>
              <v-col cols="12" md="6">
                <v-select
                  v-model="form.priority"
                  :items="priorityOptions"
                  item-title="label"
                  item-value="value"
                  label="Priority"
                  variant="outlined"
                  density="comfortable"
                  prepend-inner-icon="mdi-flag-outline"
                />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field v-model.number="form.parcel_count" type="number" min="0" label="Parcels" variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field v-model.number="form.weight_kg" type="number" min="0" step="0.1" label="Weight (kg)" variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.scheduled_pickup" type="datetime-local" label="Scheduled pickup" variant="outlined" density="comfortable" prepend-inner-icon="mdi-calendar-clock" />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.scheduled_delivery" type="datetime-local" label="Scheduled delivery" variant="outlined" density="comfortable" prepend-inner-icon="mdi-calendar-check" />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field v-model.number="form.distance_km" type="number" min="0" step="0.1" label="Distance (km)" variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field v-model.number="form.freight_cost" type="number" min="0" step="0.01" label="Freight cost" variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" md="6">
                <v-switch v-model="form.requires_refrigeration" color="info" density="compact" hide-details label="Requires cold chain / refrigeration" />
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow variant="outlined" density="comfortable" />
              </v-col>
            </v-row>
          </template>

          <!-- Step 3: assignment -->
          <template v-else>
            <v-row dense>
              <v-col cols="12" md="6">
                <v-select
                  v-model="form.carrier"
                  :items="carrierOptions"
                  item-title="name"
                  item-value="id"
                  label="Carrier (optional)"
                  variant="outlined"
                  density="comfortable"
                  clearable
                  prepend-inner-icon="mdi-handshake-outline"
                />
              </v-col>
              <v-col cols="12" md="6">
                <v-select
                  v-model="form.vehicle"
                  :items="vehicleOptions"
                  item-title="display"
                  item-value="id"
                  label="Vehicle"
                  variant="outlined"
                  density="comfortable"
                  clearable
                  prepend-inner-icon="mdi-truck-cargo-container"
                />
              </v-col>
              <v-col cols="12" md="6">
                <v-select
                  v-model="form.driver"
                  :items="driverOptions"
                  item-title="full_name"
                  item-value="id"
                  label="Driver"
                  variant="outlined"
                  density="comfortable"
                  clearable
                  prepend-inner-icon="mdi-account-tie-hat-outline"
                />
              </v-col>
              <v-col cols="12" md="6">
                <v-select
                  v-model="form.zone"
                  :items="zoneOptions"
                  item-title="name"
                  item-value="id"
                  label="Delivery zone"
                  variant="outlined"
                  density="comfortable"
                  clearable
                  prepend-inner-icon="mdi-map-marker-radius"
                />
              </v-col>
              <v-col cols="12">
                <v-alert type="info" variant="tonal" density="compact" rounded="lg">
                  You can assign a driver and vehicle later from the dispatch board. Saving now creates the shipment in
                  <strong>{{ form.driver || form.vehicle ? 'Assigned' : 'Planned' }}</strong> status.
                </v-alert>
              </v-col>
            </v-row>
          </template>
        </v-card-text>

        <v-divider />
        <v-card-actions class="pa-3">
          <v-btn variant="text" class="text-none" @click="createDialog = false">Cancel</v-btn>
          <v-spacer />
          <v-btn v-if="createStep > 0" variant="text" class="text-none" prepend-icon="mdi-arrow-left" @click="createStep--">Back</v-btn>
          <v-btn
            v-if="createStep < createSteps.length - 1"
            color="primary"
            variant="flat"
            rounded="lg"
            class="text-none"
            append-icon="mdi-arrow-right"
            :disabled="!stepValid"
            @click="createStep++"
          >Continue</v-btn>
          <v-btn
            v-else
            color="primary"
            variant="flat"
            rounded="lg"
            class="text-none"
            prepend-icon="mdi-content-save-check"
            :loading="saving"
            :disabled="!stepValid"
            @click="saveShipment"
          >Create shipment</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═════════════ DETAIL ═════════════ -->
    <v-dialog v-model="detailDialog" max-width="1040" scrollable>
      <v-card v-if="active" rounded="xl">
        <BrandDialogHeader
          :icon="statusOf(active.status).icon"
          :title="active.reference"
          :subtitle="`${active.origin_name || '—'} → ${active.dest_name || '—'} · ${typeOf(active.movement_type).label} · ${active.tracking_number}`"
          @close="detailDialog = false"
        >
          <template #meta>
            <div class="d-flex flex-wrap align-center ga-2 mt-2">
              <v-chip size="small" variant="flat" class="bdh-chip-solid font-weight-bold">
                {{ statusOf(active.status).label }}
              </v-chip>
              <v-chip v-if="active.requires_refrigeration" size="small" variant="flat" class="bdh-chip-outline">
                <v-icon start size="12">mdi-snowflake</v-icon>Cold chain
              </v-chip>
            </div>
          </template>
        </BrandDialogHeader>

        <v-card-text class="pt-4">
          <v-row dense class="mb-3">
            <v-col cols="6" md="3">
              <div class="lg-stat"><div class="lg-stat-label">Parcels</div><div class="lg-stat-value">{{ active.parcel_count || 0 }}</div></div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="lg-stat"><div class="lg-stat-label">Weight</div><div class="lg-stat-value">{{ formatQty(active.weight_kg) }} kg</div></div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="lg-stat"><div class="lg-stat-label">Distance</div><div class="lg-stat-value">{{ formatQty(active.distance_km) }} km</div></div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="lg-stat"><div class="lg-stat-label">Total cost</div><div class="lg-stat-value">{{ formatMoney(active.total_cost || 0) }}</div></div>
            </v-col>
          </v-row>

          <v-row dense>
            <v-col cols="12" md="5">
              <v-card variant="outlined" rounded="lg" class="mb-3">
                <v-card-text>
                  <div class="text-subtitle-2 font-weight-bold mb-2">Route & assignment</div>
                  <div class="lg-kv"><span>Origin</span><strong>{{ active.origin_name || '—' }}</strong></div>
                  <div class="lg-kv"><span>Destination</span><strong>{{ active.dest_name || '—' }}</strong></div>
                  <div class="lg-kv"><span>Carrier</span><strong>{{ active.carrier_name || '—' }}</strong></div>
                  <div class="lg-kv"><span>Vehicle</span><strong>{{ active.vehicle_plate || '—' }}</strong></div>
                  <div class="lg-kv"><span>Driver</span><strong>{{ active.driver_name || '—' }}</strong></div>
                  <div class="lg-kv"><span>Scheduled pickup</span><strong>{{ dt(active.scheduled_pickup) }}</strong></div>
                  <div class="lg-kv"><span>Scheduled delivery</span><strong>{{ dt(active.scheduled_delivery) }}</strong></div>
                  <div class="lg-kv"><span>Actual pickup</span><strong>{{ dt(active.actual_pickup) }}</strong></div>
                  <div class="lg-kv"><span>Actual delivery</span><strong>{{ dt(active.actual_delivery) }}</strong></div>
                </v-card-text>
              </v-card>

              <v-card variant="outlined" rounded="lg">
                <v-card-text>
                  <div class="text-subtitle-2 font-weight-bold mb-2">Cargo</div>
                  <div v-if="!active.items || !active.items.length" class="text-caption text-medium-emphasis">
                    No item lines recorded.
                  </div>
                  <div v-for="it in active.items" :key="it.id" class="lg-kv">
                    <span>{{ it.description }}</span>
                    <strong>{{ formatQty(it.quantity) }} {{ it.unit }}</strong>
                  </div>
                  <v-divider class="my-2" />
                  <div class="lg-kv"><span>Freight</span><strong>{{ formatMoney(active.freight_cost) }}</strong></div>
                  <div class="lg-kv"><span>Fuel</span><strong>{{ formatMoney(active.fuel_cost) }}</strong></div>
                  <div class="lg-kv"><span>Other</span><strong>{{ formatMoney(active.other_cost) }}</strong></div>
                </v-card-text>
              </v-card>
            </v-col>

            <v-col cols="12" md="7">
              <v-card variant="outlined" rounded="lg" class="mb-3">
                <v-card-text>
                  <div class="text-subtitle-2 font-weight-bold mb-2">Shipment progress</div>
                  <div class="lg-track">
                    <div v-for="st in trackingSteps" :key="st.key" class="lg-track-step">
                      <span class="lg-track-dot" :class="{ 'lg-track-dot--on': st.done }" />
                      <div class="flex-grow-1">
                        <div class="text-body-2" :class="st.done ? 'font-weight-medium' : 'text-medium-emphasis'">{{ st.label }}</div>
                        <div class="text-caption text-medium-emphasis">{{ st.detail }}</div>
                      </div>
                    </div>
                  </div>
                </v-card-text>
              </v-card>

              <v-card variant="outlined" rounded="lg">
                <v-card-text>
                  <div class="text-subtitle-2 font-weight-bold mb-2">Tracking timeline</div>
                  <div v-if="!active.events || !active.events.length" class="text-caption text-medium-emphasis">
                    No events recorded yet.
                  </div>
                  <div class="lg-events">
                    <div v-for="e in active.events" :key="e.id" class="lg-event">
                      <span class="lg-event-dot" />
                      <div class="flex-grow-1">
                        <div class="text-body-2">{{ e.description || eventLabel(e.event_type) }}</div>
                        <div class="text-caption text-medium-emphasis">
                          {{ dt(e.occurred_at) }}<span v-if="e.location"> · {{ e.location }}</span>
                        </div>
                      </div>
                    </div>
                  </div>
                </v-card-text>
              </v-card>
            </v-col>
          </v-row>
        </v-card-text>

        <v-divider />
        <v-card-actions class="pa-3 flex-wrap">
          <v-btn variant="text" class="text-none" @click="detailDialog = false">Close</v-btn>
          <v-spacer />
          <v-btn
            v-if="active.status === 'planned' || active.status === 'draft'"
            color="primary"
            variant="tonal"
            rounded="lg"
            class="text-none"
            prepend-icon="mdi-account-check-outline"
            @click="assignDialog = true"
          >Assign</v-btn>
          <v-btn
            v-if="['draft', 'planned', 'assigned'].includes(active.status)"
            color="cyan-darken-2"
            variant="tonal"
            rounded="lg"
            class="text-none"
            prepend-icon="mdi-package-variant-closed-check"
            :loading="acting"
            @click="doPickup"
          >Mark picked up</v-btn>
          <v-btn
            v-if="active.status === 'picked_up'"
            color="teal"
            variant="tonal"
            rounded="lg"
            class="text-none"
            prepend-icon="mdi-truck-fast-outline"
            :loading="acting"
            @click="doDepart"
          >Depart</v-btn>
          <v-btn
            v-if="['picked_up', 'in_transit'].includes(active.status)"
            color="amber-darken-2"
            variant="tonal"
            rounded="lg"
            class="text-none"
            prepend-icon="mdi-map-marker-path"
            :loading="acting"
            @click="doOutForDelivery"
          >Out for delivery</v-btn>
          <v-btn
            v-if="['picked_up', 'in_transit', 'out_for_delivery', 'assigned'].includes(active.status)"
            color="success"
            variant="flat"
            rounded="lg"
            class="text-none"
            prepend-icon="mdi-check-decagram"
            @click="deliverDialog = true"
          >Deliver (POD)</v-btn>
          <v-btn
            v-if="['picked_up', 'in_transit', 'out_for_delivery'].includes(active.status)"
            color="error"
            variant="tonal"
            rounded="lg"
            class="text-none"
            prepend-icon="mdi-alert-circle-outline"
            @click="failDialog = true"
          >Report failure</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ASSIGN -->
    <v-dialog v-model="assignDialog" max-width="520">
      <v-card rounded="xl">
        <BrandDialogHeader
          icon="mdi-account-check-outline"
          title="Assign resources"
          subtitle="Carrier, vehicle and delivery schedule"
          @close="assignDialog = false"
        />
        <v-card-text>
          <v-select v-model="assignForm.carrier" :items="carrierOptions" item-title="name" item-value="id" label="Carrier" variant="outlined" density="comfortable" clearable class="mb-2" />
          <v-select v-model="assignForm.vehicle" :items="vehicleOptions" item-title="display" item-value="id" label="Vehicle" variant="outlined" density="comfortable" clearable class="mb-2" />
          <v-select v-model="assignForm.driver" :items="driverOptions" item-title="full_name" item-value="id" label="Driver" variant="outlined" density="comfortable" clearable class="mb-2" />
          <v-text-field v-model="assignForm.scheduled_pickup" type="datetime-local" label="Scheduled pickup" variant="outlined" density="comfortable" class="mb-2" />
          <v-text-field v-model="assignForm.scheduled_delivery" type="datetime-local" label="Scheduled delivery" variant="outlined" density="comfortable" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="assignDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" rounded="lg" class="text-none" :loading="acting" @click="doAssign">Assign</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- POD -->
    <v-dialog v-model="deliverDialog" max-width="520">
      <v-card rounded="xl">
        <BrandDialogHeader
          icon="mdi-check-decagram"
          title="Confirm delivery"
          subtitle="Capture proof of delivery"
          @close="deliverDialog = false"
        />
        <v-card-text>
          <v-text-field v-model="podForm.pod_received_by" label="Received by" variant="outlined" density="comfortable" class="mb-2" prepend-inner-icon="mdi-account-check-outline" />
          <v-textarea v-model="podForm.pod_notes" label="Delivery notes" rows="2" auto-grow variant="outlined" density="comfortable" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="deliverDialog = false">Cancel</v-btn>
          <v-btn color="success" variant="flat" rounded="lg" class="text-none" :loading="acting" @click="doDeliver">Confirm delivery</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- FAIL -->
    <v-dialog v-model="failDialog" max-width="480">
      <v-card rounded="xl">
        <BrandDialogHeader
          icon="mdi-alert-circle-outline"
          title="Report delivery failure"
          subtitle="Record why the delivery could not be completed"
          @close="failDialog = false"
        />
        <v-card-text>
          <v-textarea v-model="failReason" label="Reason" rows="3" auto-grow variant="outlined" density="comfortable" placeholder="e.g. Customer unavailable, address not found" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="failDialog = false">Cancel</v-btn>
          <v-btn color="error" variant="flat" rounded="lg" class="text-none" :loading="acting" @click="doFail">Report failure</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" rounded="lg" timeout="3600">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
import { MOVEMENT_TYPES, PRIORITY_META, useLogistics } from '~/composables/useLogistics'

definePageMeta({ layout: 'default' })

const route = useRoute()
const { $api } = useNuxtApp()
const brand = useBranding()
const branchStore = useBranchStore()
const { branches: branchesApi } = useTenantEndpoints()
const L = useLogistics()

const {
  shipmentStats, shipmentBoard, shipments, shipment, movementType, shipmentStatus, priorityMeta,
  assign, pickup, depart, outForDelivery, deliver, failShipment,
} = L

const statusOf = shipmentStatus
const typeOf = movementType
const priorityOf = priorityMeta

const movementTypes = MOVEMENT_TYPES
const priorityOptions = Object.entries(PRIORITY_META).map(([value, m]) => ({ value, label: m.label, icon: m.icon, color: m.color }))

const heroTheme = computed(() => ({
  '--hero-deep': brand.secondary.value,
  '--hero-main': brand.primary.value,
  '--hero-accent': brand.gradientStops.value[2],
  '--hero-ink': brand.ink.value,
  '--hero-glow': brand.tint('primary', 0.3),
  '--hero-glow-2': brand.tint('accent', 0.2),
  '--hero-shadow': brand.shadow.value,
}))

const loading = ref(false)
const exporting = ref(false)
const saving = ref(false)
const acting = ref(false)
const rows = ref([])
const stats = ref({})
const board = ref({ columns: {} })
const viewMode = ref('list')
const search = ref('')
const filters = reactive({ status: 'all', movement_type: null, priority: null })
const pageInfo = reactive({ page: 1, perPage: 15, total: 0, lastPage: 1 })
const pageCount = computed(() => Math.max(1, Math.ceil(pageInfo.total / pageInfo.perPage)))
const snack = reactive({ show: false, color: 'success', text: '' })

const createDialog = ref(false)
const createStep = ref(0)
const createSteps = [
  { label: 'Route' },
  { label: 'Cargo & schedule' },
  { label: 'Assignment' },
]

const detailDialog = ref(false)
const active = ref(null)
const assignDialog = ref(false)
const deliverDialog = ref(false)
const failDialog = ref(false)
const failReason = ref('')

const form = ref(blankForm())
const assignForm = reactive({ carrier: null, vehicle: null, driver: null, scheduled_pickup: '', scheduled_delivery: '' })
const podForm = reactive({ pod_received_by: '', pod_notes: '' })

const carrierOptions = ref([])
const vehicleOptions = ref([])
const driverOptions = ref([])
const zoneOptions = ref([])

const branchOptions = computed(() => (branchStore.branches || []).filter(b => b.is_active !== false))
const customerOptions = ref([])

function blankForm() {
  return {
    movement_type: 'transfer',
    priority: 'normal',
    // warehouse selectors
    from_branch: null,
    to_branch: null,
    // customer selector
    is_walkin: false,
    customer_id: null,
    // manual origin / dest
    origin_name: '', origin_address: '', origin_contact: '', origin_phone: '',
    dest_name: '', dest_address: '', dest_address_1: '', dest_contact: '', dest_phone: '',
    scheduled_pickup: '', scheduled_delivery: '',
    parcel_count: 0, weight_kg: 0, distance_km: 0, freight_cost: 0,
    requires_refrigeration: false, notes: '',
    carrier: null, vehicle: null, driver: null, zone: null,
  }
}

const heroFacts = computed(() => [
  { value: stats.value.open ?? 0, label: 'open' },
  { value: stats.value.in_transit ?? 0, label: 'in transit' },
  { value: stats.value.late ?? 0, label: 'past ETA' },
  { value: stats.value.delivered ?? 0, label: 'delivered' },
])

const kpis = computed(() => [
  { title: 'Total', value: stats.value.total ?? 0, sub: 'all shipments', icon: 'mdi-truck-fast-outline', color: 'primary', hint: 'Lifetime movements' },
  { title: 'Open', value: stats.value.open ?? 0, sub: 'in the pipeline', icon: 'mdi-progress-clock', color: 'blue', hint: 'Not yet delivered' },
  { title: 'Past ETA', value: stats.value.late ?? 0, sub: 'need follow-up', icon: 'mdi-clock-alert-outline', color: 'error', hint: 'Scheduled delivery missed' },
  { title: 'Delivered', value: stats.value.delivered ?? 0, sub: `${stats.value.on_time_pct ?? 0}% on time`, icon: 'mdi-check-decagram', color: 'success', hint: 'POD captured' },
  { title: 'Unassigned', value: stats.value.unassigned ?? 0, sub: 'no driver yet', icon: 'mdi-account-question-outline', color: 'amber', hint: 'Assign before dispatch' },
  { title: 'Freight spend', value: formatMoney(stats.value.total_cost || 0), sub: 'all time', icon: 'mdi-cash-multiple', color: 'deep-purple', hint: 'Freight + fuel + other' },
])

const statusChips = computed(() => {
  const byStatus = {}
  for (const row of stats.value.by_status || []) byStatus[row.status] = row.count
  const total = stats.value.total || 0
  const chips = [{ value: 'all', label: 'All', icon: 'mdi-view-grid-outline', count: total }]
  for (const s of ['planned', 'assigned', 'picked_up', 'in_transit', 'out_for_delivery', 'delivered', 'failed']) {
    const meta = statusOf(s)
    chips.push({ value: s, label: meta.label, icon: meta.icon, count: byStatus[s] || 0 })
  }
  return chips
})

const boardColumns = computed(() => {
  const order = ['draft', 'planned', 'assigned', 'picked_up', 'in_transit', 'out_for_delivery', 'delivered', 'failed']
  const cols = board.value.columns || {}
  return order.map((s) => {
    const meta = statusOf(s)
    const col = cols[s] || { shipments: [], count: 0 }
    return { status: s, label: meta.label, color: meta.color, count: col.count || 0, rows: col.shipments || [] }
  })
})

const hasFilters = computed(() =>
  filters.status !== 'all' || !!filters.movement_type || !!filters.priority || !!search.value)

const stepValid = computed(() => {
  if (createStep.value === 0) {
    if (isWarehouseMove.value) {
      return !!form.value.from_branch && !!form.value.to_branch && form.value.from_branch.id !== form.value.to_branch.id
    }
    if (isCustomerMove.value) {
      if (form.value.is_walkin) return !!form.value.dest_name
      return !!form.value.customer_id || !!form.value.dest_name
    }
    return !!form.value.origin_name && !!form.value.dest_name
  }
  if (createStep.value === 1) return true
  return true
})

const isWarehouseMove = computed(() => ['transfer', 'intercompany'].includes(form.value.movement_type))
const isCustomerMove = computed(() => ['customer_delivery', 'customer_return'].includes(form.value.movement_type))

function selectMovement(v) {
  form.value.movement_type = v
  // reset relevant fields
  form.value.from_branch = null
  form.value.to_branch = null
  form.value.customer_id = null
  form.value.is_walkin = false
  // pre-fill dispatch warehouse for customer moves
  if (isCustomerMove.value && branchStore.currentBranch) {
    form.value.from_branch = branchStore.currentBranch
    onFromBranch(form.value.from_branch)
  }
}

function onFromBranch(b) {
  if (!b) return
  form.value.origin_name = b.name
  form.value.origin_address = b.address || ''
  form.value.origin_phone = b.phone || ''
}

function onToBranch(b) {
  if (!b) return
  form.value.dest_name = b.name
  form.value.dest_address = b.address || ''
  form.value.dest_phone = b.phone || ''
}

function onCustomerSelect(c) {
  if (!c) return
  form.value.dest_name = c.name || ''
  form.value.dest_contact = c.name || ''
  form.value.dest_phone = c.phone || ''
  form.value.dest_address = c.address || ''
  form.value.dest_address_1 = c.address || ''
}

const trackingSteps = computed(() => {
  const a = active.value
  if (!a) return []
  const order = ['created', 'assigned', 'picked_up', 'in_transit', 'delivered']
  const reach = {
    created: true,
    assigned: !!a.driver,
    picked_up: !!a.actual_pickup,
    in_transit: ['in_transit', 'out_for_delivery', 'delivered'].includes(a.status),
    delivered: a.status === 'delivered',
  }
  return [
    { key: 'created', label: 'Created', detail: dt(a.created_at), done: reach.created },
    { key: 'assigned', label: 'Assigned', detail: a.driver_name || a.carrier_name || 'Awaiting assignment', done: reach.assigned },
    { key: 'picked_up', label: 'Picked up', detail: dt(a.actual_pickup), done: reach.picked_up },
    { key: 'in_transit', label: 'In transit', detail: a.status === 'out_for_delivery' ? 'Out for delivery' : 'On the road', done: reach.in_transit },
    { key: 'delivered', label: 'Delivered', detail: dt(a.actual_delivery), done: reach.delivered },
  ]
})

function stepDone(i) { return createStep.value > i }
function stepClass(i) {
  if (createStep.value === i) return 'lg-step--on'
  return createStep.value > i ? 'lg-step--done' : ''
}
function stepIcon(i) {
  if (createStep.value > i) return 'mdi-check'
  return String(i + 1)
}

function formatQty(v) {
  return (Number(v) || 0).toLocaleString(undefined, { maximumFractionDigits: 2 })
}

function dt(v) {
  if (!v) return '—'
  const d = new Date(v)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
}

function etaLabel(s) {
  if (s.status === 'delivered') return 'Delivered'
  if (!s.scheduled_delivery) return '—'
  return dt(s.scheduled_delivery)
}

function eventLabel(t) {
  return (t || '').replace(/_/g, ' ').replace(/\w/g, (c) => c.toUpperCase())
}

function setStatus(value) {
  filters.status = value
  pageInfo.page = 1
  load()
}

function clearFilters() {
  filters.status = 'all'
  filters.movement_type = null
  filters.priority = null
  search.value = ''
  pageInfo.page = 1
  load()
}

function queryParams() {
  const p = { page: pageInfo.page, page_size: pageInfo.perPage, ordering: '-created_at' }
  if (filters.status !== 'all') p.status = filters.status
  if (filters.movement_type) p.movement_type = filters.movement_type
  if (filters.priority) p.priority = filters.priority
  if (search.value) p.search = search.value
  return p
}

async function load() {
  loading.value = true
  try {
    const params = queryParams()
    const [st, listRes, boardRes] = await Promise.all([
      shipmentStats(params),
      shipments(params),
      shipmentBoard(params),
    ])
    stats.value = st.data || {}
    rows.value = listRes.data?.results || listRes.data || []
    pageInfo.total = listRes.data?.count || rows.value.length
    pageInfo.lastPage = Math.max(1, Math.ceil(pageInfo.total / pageInfo.perPage))
    board.value = boardRes.data || { columns: {} }
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Failed to load shipments' }
  } finally {
    loading.value = false
  }
}

async function loadLookups() {
  try {
    const [c, v, d, z, cust] = await Promise.all([
      $api.get('/logistics/carriers/', { params: { page_size: 200, is_active: true } }),
      $api.get('/logistics/vehicles/', { params: { page_size: 300, is_active: true } }),
      $api.get('/logistics/drivers/', { params: { page_size: 300, is_active: true } }),
      $api.get('/logistics/zones/', { params: { page_size: 200, is_active: true } }),
      $api.get('/crm/customers/', { params: { page_size: 500 } }),
    ])
    const unpack = (r) => r.data?.results || r.data || []
    carrierOptions.value = unpack(c)
    vehicleOptions.value = unpack(v).map((x) => ({ ...x, display: x.display_name || x.plate_number }))
    driverOptions.value = unpack(d)
    zoneOptions.value = unpack(z)
    customerOptions.value = unpack(cust).map(x => ({ ...x, label: `${x.name}${x.phone ? ' · ' + x.phone : ''}` }))
  } catch {
    /* lookups are optional for the list view */
  }
  // Ensure branch store is loaded for warehouse selectors
  if (!branchStore.branches.length) branchStore.load?.().catch(() => {})
}

function openCreate() {
  form.value = blankForm()
  createStep.value = 0
  // Pre-fill dispatch warehouse for default 'transfer' from the current branch
  if (branchStore.currentBranch) {
    form.value.from_branch = branchStore.currentBranch
    onFromBranch(form.value.from_branch)
  }
  createDialog.value = true
}

async function openDetail(row) {
  try {
    const { data } = await shipment(row.id)
    active.value = data
    detailDialog.value = true
    assignForm.carrier = data.carrier || null
    assignForm.vehicle = data.vehicle || null
    assignForm.driver = data.driver || null
    assignForm.scheduled_pickup = toLocalInput(data.scheduled_pickup)
    assignForm.scheduled_delivery = toLocalInput(data.scheduled_delivery)
    podForm.pod_received_by = data.dest_contact || ''
    podForm.pod_notes = ''
  } catch {
    snack.value = { show: true, color: 'error', text: 'Failed to load shipment' }
  }
}

function toLocalInput(v) {
  if (!v) return ''
  const d = new Date(v)
  if (Number.isNaN(d.getTime())) return ''
  const pad = (n) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

function payload() {
  const f = form.value
  const body = {
    movement_type: f.movement_type,
    priority: f.priority,
    // For warehouse moves, origin/dest are already mapped from branch objects
    origin_name: f.origin_name,
    origin_address: f.origin_address,
    origin_contact: f.origin_contact,
    origin_phone: f.origin_phone,
    // For customer moves, merge dest_address_1 + dest_address
    dest_name: f.dest_name,
    dest_address: f.dest_address_1 ? `${f.dest_address_1}\n${f.dest_address || ''}`.trim() : f.dest_address,
    dest_contact: f.dest_contact,
    dest_phone: f.dest_phone,
    parcel_count: Number(f.parcel_count) || 0,
    weight_kg: Number(f.weight_kg) || 0,
    distance_km: Number(f.distance_km) || 0,
    freight_cost: Number(f.freight_cost) || 0,
    requires_refrigeration: !!f.requires_refrigeration,
    notes: f.notes,
    status: f.driver || f.vehicle || f.carrier ? 'assigned' : 'planned',
  }
  if (f.scheduled_pickup) body.scheduled_pickup = new Date(f.scheduled_pickup).toISOString()
  if (f.scheduled_delivery) body.scheduled_delivery = new Date(f.scheduled_delivery).toISOString()
  if (f.carrier) body.carrier = f.carrier
  if (f.vehicle) body.vehicle = f.vehicle
  if (f.driver) body.driver = f.driver
  if (f.zone) body.zone = f.zone
  return body
}

async function saveShipment() {
  saving.value = true
  try {
    const { data } = await $api.post('/logistics/shipments/', payload())
    createDialog.value = false
    snack.value = { show: true, color: 'success', text: `Shipment ${data.reference} created` }
    await load()
  } catch (e) {
    const d = e?.response?.data
    const msg = d && typeof d === 'object' ? Object.values(d).flat().join(' ') : 'Failed to create shipment'
    snack.value = { show: true, color: 'error', text: msg }
  } finally {
    saving.value = false
  }
}

async function doAssign() {
  if (!active.value) return
  acting.value = true
  try {
    const body = {
      carrier: assignForm.carrier || null,
      vehicle: assignForm.vehicle || null,
      driver: assignForm.driver || null,
    }
    if (assignForm.scheduled_pickup) body.scheduled_pickup = new Date(assignForm.scheduled_pickup).toISOString()
    if (assignForm.scheduled_delivery) body.scheduled_delivery = new Date(assignForm.scheduled_delivery).toISOString()
    await assign(active.value.id, body)
    await refreshActive()
    assignDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Resources assigned' }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Assign failed' }
  } finally {
    acting.value = false
  }
}

async function doPickup() {
  acting.value = true
  try {
    await pickup(active.value.id)
    await refreshActive()
    snack.value = { show: true, color: 'success', text: 'Marked as picked up' }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Action failed' }
  } finally { acting.value = false }
}

async function doDepart() {
  acting.value = true
  try {
    await depart(active.value.id)
    await refreshActive()
    snack.value = { show: true, color: 'success', text: 'Shipment departed' }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Action failed' }
  } finally { acting.value = false }
}

async function doOutForDelivery() {
  acting.value = true
  try {
    await outForDelivery(active.value.id)
    await refreshActive()
    snack.value = { show: true, color: 'success', text: 'Out for delivery' }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Action failed' }
  } finally { acting.value = false }
}

async function doDeliver() {
  acting.value = true
  try {
    await deliver(active.value.id, {
      pod_received_by: podForm.pod_received_by,
      pod_notes: podForm.pod_notes,
    })
    await refreshActive()
    deliverDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Delivery confirmed' }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Delivery failed' }
  } finally { acting.value = false }
}

async function doFail() {
  acting.value = true
  try {
    await failShipment(active.value.id, { reason: failReason.value })
    await refreshActive()
    failDialog.value = false
    failReason.value = ''
    snack.value = { show: true, color: 'info', text: 'Failure reported' }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Action failed' }
  } finally { acting.value = false }
}

async function refreshActive() {
  if (!active.value) return
  const { data } = await shipment(active.value.id)
  active.value = data
}

function exportCsv() {
  const cols = ['reference', 'tracking_number', 'movement_type', 'status', 'priority', 'origin_name', 'dest_name', 'driver_name', 'carrier_name', 'scheduled_delivery', 'total_cost']
  const lines = [cols.join(',')]
  for (const r of rows.value) {
    lines.push(cols.map((c) => `"${String(r[c] ?? '').replace(/"/g, '""')}"`).join(','))
  }
  const blob = new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `shipments_${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

watch(viewMode, (v) => {
  if (v === 'board') filters.status = 'all'
  if (import.meta.client) localStorage.setItem('ims-logistics-view', v)
})

onMounted(async () => {
  if (import.meta.client) {
    const saved = localStorage.getItem('ims-logistics-view')
    if (saved) viewMode.value = saved
  }
  await loadLookups()
  await load()
  if (route.query.new) openCreate()
  if (route.query.status) {
    filters.status = String(route.query.status)
    await load()
  }
  if (route.query.focus) {
    try {
      const { data } = await shipment(String(route.query.focus))
      active.value = data
      detailDialog.value = true
    } catch { /* ignore */ }
  }
})
</script>

<style scoped>
.lg-page { max-width: 1680px; margin: 0 auto; }
.lg-hero-iconbtn { color: #fff !important; }
.lg-hero-btn-strong {
  background: #ffffff !important;
  color: var(--hero-ink, #143ce1) !important;
  font-weight: 700 !important;
  border: 1px solid rgba(255, 255, 255, 0.95) !important;
  box-shadow: 0 6px 18px rgba(6, 44, 40, 0.28) !important;
}
.lg-hero-btn-glass {
  background: rgba(255, 255, 255, 0.16) !important;
  color: #ffffff !important;
  font-weight: 600 !important;
  border: 1px solid rgba(255, 255, 255, 0.34) !important;
  backdrop-filter: blur(6px);
}
.lg-hero-btn-glass:hover { background: rgba(255, 255, 255, 0.26) !important; }
.lg-search { flex: 1 1 320px; max-width: 460px; }
.lg-select { width: 190px; }
.lg-select-sm { width: 150px; }
.lg-status-chips { overflow-x: auto; flex-wrap: nowrap; }

/* board */
.lg-board {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(255px, 1fr));
  gap: 14px;
  align-items: start;
}
.lg-board-col {
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-border-color), 0.16);
  border-radius: 16px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  max-height: 70vh;
}
.lg-board-head {
  display: flex; align-items: center; justify-content: space-between;
  padding: 10px 14px;
  border-bottom: 1px solid rgba(var(--v-border-color), 0.14);
  background: rgba(var(--v-theme-surface-variant), 0.4);
}
.lg-board-dot { width: 8px; height: 8px; border-radius: 50%; background: rgba(var(--v-theme-primary), 0.7); }
.lg-dot--delivered { background: #16a34a; }
.lg-dot--failed { background: #dc2626; }
.lg-dot--in_transit { background: #0d9488; }
.lg-dot--out_for_delivery { background: #d97706; }
.lg-dot--assigned { background: #2563eb; }
.lg-dot--picked_up { background: #0891b2; }
.lg-dot--planned { background: #4f46e5; }
.lg-dot--draft { background: #6b7280; }
.lg-board-body { padding: 10px; display: flex; flex-direction: column; gap: 10px; overflow-y: auto; }
.lg-board-empty { text-align: center; padding: 22px 0; }
.lg-ship-card {
  border: 1px solid rgba(var(--v-border-color), 0.18);
  border-radius: 13px;
  padding: 12px;
  cursor: pointer;
  transition: box-shadow .16s, transform .16s;
  background: rgb(var(--v-theme-surface));
}
.lg-ship-card:hover { box-shadow: 0 6px 18px rgba(0, 0, 0, .09); transform: translateY(-1px); }
.lg-ship-card--late { border-color: rgba(239, 68, 68, 0.42); }
.lg-ship-ref { font-size: 12.5px; font-weight: 800; letter-spacing: .2px; }
.lg-ship-route { display: flex; align-items: center; flex-wrap: wrap; gap: 6px; }
.lg-wh-chip {
  font-size: 11px; font-weight: 600; padding: 2px 8px; border-radius: 8px;
  background: rgba(var(--v-theme-primary), 0.1); color: rgb(var(--v-theme-primary));
  max-width: 46%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.lg-wh-chip--dest { background: rgba(16, 185, 129, 0.13); color: #0f766e; }
.lg-ship-cost { font-size: 12px; font-weight: 700; }

/* table */
.lg-table :deep(th) { font-size: 11px; text-transform: uppercase; letter-spacing: .4px; }
.lg-row { cursor: pointer; }
.lg-row:hover { background: rgba(var(--v-theme-primary), 0.04); }
.lg-empty { display: flex; flex-direction: column; align-items: center; text-align: center; }

/* dialogs */
.lg-dialog-head {
  position: relative; overflow: hidden;
  padding: 16px 20px;
  color: #fff;
  background: linear-gradient(120deg, var(--hero-deep, #143ce1) 0%, var(--hero-main, #2f6dff) 52%, var(--hero-accent, #37d6ff) 100%);
}
.lg-dialog-icon {
  width: 44px; height: 44px; border-radius: 13px;
  display: flex; align-items: center; justify-content: center;
  background: rgba(255, 255, 255, .18);
  border: 1px solid rgba(255, 255, 255, .3);
}
.lg-step-track { display: flex; align-items: center; gap: 6px; }
.lg-step {
  display: inline-flex; align-items: center; gap: 6px;
  font-size: 11px; font-weight: 600; padding: 4px 10px; border-radius: 999px;
  background: rgba(255, 255, 255, .12); color: rgba(255, 255, 255, .82);
}
.lg-step--on { background: #fff; color: var(--hero-ink, #143ce1); }
.lg-step--done { background: rgba(255, 255, 255, .3); color: #fff; }
.lg-step-line { flex: 1; height: 2px; background: rgba(255, 255, 255, .22); }
.lg-step-line--done { background: rgba(255, 255, 255, .62); }

.lg-type-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 10px; }
.lg-type-card {
  border: 1px solid rgba(var(--v-border-color), 0.24);
  border-radius: 13px; padding: 12px; text-align: left; background: rgb(var(--v-theme-surface));
  transition: border-color .15s, box-shadow .15s;
}
.lg-type-card:hover { border-color: rgba(var(--v-theme-primary), 0.42); }
.lg-type-card--on { border-color: rgb(var(--v-theme-primary)); box-shadow: 0 0 0 2px rgba(var(--v-theme-primary), .16); }

.lg-stat {
  border: 1px solid rgba(var(--v-border-color), 0.16);
  border-radius: 12px; padding: 10px 12px;
}
.lg-stat-label { font-size: 10px; text-transform: uppercase; letter-spacing: .5px; color: rgba(var(--v-theme-on-surface), .6); }
.lg-stat-value { font-size: 17px; font-weight: 800; }
.lg-kv { display: flex; align-items: center; justify-content: space-between; gap: 10px; padding: 4px 0; font-size: 13px; }
.lg-kv span { color: rgba(var(--v-theme-on-surface), .62); }
.lg-track { display: flex; flex-direction: column; gap: 10px; }
.lg-track-step { display: flex; align-items: flex-start; gap: 10px; }
.lg-track-dot {
  width: 10px; height: 10px; border-radius: 50%; margin-top: 5px;
  background: rgba(var(--v-border-color), .5); flex-shrink: 0;
}
.lg-track-dot--on { background: rgb(var(--v-theme-primary)); box-shadow: 0 0 0 3px rgba(var(--v-theme-primary), .18); }
.lg-events { display: flex; flex-direction: column; gap: 10px; max-height: 240px; overflow-y: auto; }
.lg-event { display: flex; gap: 10px; }
.lg-event-dot { width: 8px; height: 8px; border-radius: 50%; background: rgb(var(--v-theme-primary)); margin-top: 6px; flex-shrink: 0; }
</style>
