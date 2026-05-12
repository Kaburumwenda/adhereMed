<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Hero -->
    <v-card flat rounded="xl" class="hero text-white pa-5 pa-md-6 mb-4">
      <v-row align="center" no-gutters>
        <v-col cols="12" md="8">
          <div class="d-flex align-center">
            <v-avatar color="white" size="56" class="mr-4 elevation-2">
              <v-icon color="indigo-darken-3" size="32">mdi-truck-fast</v-icon>
            </v-avatar>
            <div>
              <div class="text-h5 text-md-h4 font-weight-bold">Deliveries</div>
              <div class="text-body-2" style="opacity:0.9">
                Manage POS order deliveries, drivers and live status updates.
              </div>
            </div>
          </div>
        </v-col>
        <v-col
          cols="12" md="4"
          class="d-flex justify-md-end mt-3 mt-md-0"
          style="gap:8px"
        >
          <v-btn
            color="white" variant="elevated" class="text-indigo-darken-3"
            prepend-icon="mdi-plus" @click="openCreate"
          >
            New Delivery
          </v-btn>
          <v-btn
            color="white" variant="outlined" prepend-icon="mdi-refresh"
            :loading="loading" @click="load"
          >
            Refresh
          </v-btn>
        </v-col>
      </v-row>

      <v-row class="mt-4" dense>
        <v-col v-for="k in kpis" :key="k.label" cols="6" md="3">
          <v-card flat rounded="lg" class="stat-card pa-3">
            <div class="d-flex align-center">
              <v-avatar :color="k.color" size="36" class="mr-3">
                <v-icon color="white" size="20">{{ k.icon }}</v-icon>
              </v-avatar>
              <div>
                <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
                <div class="text-h6 font-weight-bold">{{ k.value }}</div>
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>
    </v-card>

    <!-- Filters -->
    <v-card flat rounded="xl" class="pa-3 mb-3" border>
      <v-row dense align="center">
        <v-col cols="12" md="5">
          <v-text-field
            v-model="search"
            prepend-inner-icon="mdi-magnify"
            placeholder="Search by recipient, phone or address…"
            density="comfortable" hide-details
            variant="solo-filled" flat clearable
          />
        </v-col>
        <v-col cols="6" md="3">
          <v-select
            v-model="filterStatus" :items="statusItems" label="Status"
            density="comfortable" hide-details variant="outlined"
            prepend-inner-icon="mdi-filter-variant"
          />
        </v-col>
        <v-col cols="6" md="2">
          <v-select
            v-model="viewMode" :items="viewItems" label="View"
            density="comfortable" hide-details variant="outlined"
            prepend-inner-icon="mdi-view-grid-outline"
          />
        </v-col>
        <v-col cols="12" md="2" class="d-flex justify-end">
          <v-btn variant="text" prepend-icon="mdi-download" @click="exportCsv">
            CSV
          </v-btn>
        </v-col>
      </v-row>

      <!-- Status quick chips -->
      <v-chip-group
        v-model="filterStatus" mandatory class="mt-2"
        selected-class="text-white"
      >
        <v-chip
          v-for="s in statusChips" :key="s.value || 'all'" :value="s.value"
          :color="s.color" variant="tonal" size="small"
        >
          <v-icon start size="14">{{ s.icon }}</v-icon>
          {{ s.title }}
          <span class="ml-2 font-weight-bold">{{ countFor(s.value) }}</span>
        </v-chip>
      </v-chip-group>
    </v-card>

    <!-- Card / grid view -->
    <div v-if="viewMode === 'grid'">
      <div v-if="loading" class="text-center py-12">
        <v-progress-circular indeterminate color="primary" />
      </div>
      <EmptyState
        v-else-if="!filteredItems.length"
        icon="mdi-truck-outline"
        title="No deliveries found"
        :message="search || filterStatus !== 'all'
          ? 'Try adjusting your search or filters.'
          : 'Delivery records from POS sales will appear here.'"
      />
      <v-row v-else dense>
        <v-col
          v-for="d in filteredItems" :key="d.id"
          cols="12" sm="6" md="4" lg="3"
        >
          <v-card class="delivery-card pa-4 h-100" rounded="xl" border>
            <div class="d-flex align-center mb-3">
              <v-avatar :color="avatarColor(d.recipient_name)" size="44" class="mr-3">
                <span class="text-subtitle-2 font-weight-bold text-white">
                  {{ initials(d.recipient_name) }}
                </span>
              </v-avatar>
              <div class="flex-grow-1 min-width-0">
                <div class="text-subtitle-1 font-weight-bold text-truncate">
                  {{ d.recipient_name }}
                </div>
                <div class="text-caption text-medium-emphasis text-truncate">
                  <v-icon size="12">mdi-receipt</v-icon>
                  {{ d.transaction_number || `#${d.transaction}` }}
                </div>
              </div>
              <v-chip
                :color="statusMeta(d.status).color" size="x-small" variant="tonal"
              >
                {{ statusMeta(d.status).title }}
              </v-chip>
            </div>
            <v-divider class="mb-2" />
            <div class="text-caption text-medium-emphasis mb-1">
              <v-icon size="14" class="mr-1">mdi-phone</v-icon>{{ d.recipient_phone || '—' }}
            </div>
            <div class="text-caption text-medium-emphasis mb-1 text-truncate-2">
              <v-icon size="14" class="mr-1">mdi-map-marker</v-icon>
              {{ d.delivery_address || '—' }}
              <v-icon
                v-if="d.latitude && d.longitude"
                size="12" color="success" class="ml-1"
                title="GPS pinned"
              >mdi-crosshairs-gps</v-icon>
            </div>
            <div class="text-caption text-medium-emphasis mb-2">
              <v-icon size="14" class="mr-1">mdi-account-tie</v-icon>
              <span v-if="d.driver_display">{{ d.driver_display }}</span>
              <em v-else class="text-medium-emphasis">Unassigned</em>
            </div>
            <div class="d-flex align-center justify-space-between">
              <v-chip size="x-small" color="success" variant="tonal">
                <v-icon start size="12">mdi-cash</v-icon>
                KSh {{ formatNumber(d.delivery_fee) }}
              </v-chip>
              <span class="text-caption text-medium-emphasis">
                {{ relativeTime(d.created_at) }}
              </span>
            </div>
            <v-divider class="my-2" />
            <div class="d-flex justify-end" style="gap: 4px">
              <v-btn
                icon="mdi-eye-outline" variant="text" size="small"
                @click="openDetail(d)"
              />
              <v-btn
                icon="mdi-account-arrow-right" variant="text" size="small"
                color="indigo" @click="openAssign(d)"
              />
              <v-menu>
                <template #activator="{ props }">
                  <v-btn
                    icon="mdi-dots-vertical" variant="text" size="small"
                    v-bind="props"
                  />
                </template>
                <v-list density="compact">
                  <v-list-item
                    v-for="t in nextTransitions(d)"
                    :key="t.value"
                    :prepend-icon="t.icon"
                    :title="t.label"
                    @click="updateStatus(d, t.value)"
                  />
                  <v-divider />
                  <v-list-item
                    prepend-icon="mdi-content-copy"
                    title="Copy address"
                    @click="copyAddress(d)"
                  />
                  <v-list-item
                    prepend-icon="mdi-delete-outline"
                    title="Delete" base-color="error"
                    @click="confirmDelete(d)"
                  />
                </v-list>
              </v-menu>
            </div>
          </v-card>
        </v-col>
      </v-row>
    </div>

    <!-- Table view -->
    <v-card v-else flat rounded="xl" border>
      <v-data-table
        :headers="headers"
        :items="filteredItems"
        :loading="loading"
        :items-per-page="20"
        item-value="id"
        density="comfortable"
        hover
      >
        <template #item.transaction="{ item }">
          <div>
            <div class="font-weight-medium">
              {{ item.transaction_number || `#${item.transaction}` }}
            </div>
            <div class="text-caption text-medium-emphasis">
              {{ relativeTime(item.created_at) }}
            </div>
          </div>
        </template>
        <template #item.recipient_name="{ item }">
          <div class="d-flex align-center">
            <v-avatar
              :color="avatarColor(item.recipient_name)" size="32" class="mr-2"
            >
              <span class="text-caption font-weight-bold text-white">
                {{ initials(item.recipient_name) }}
              </span>
            </v-avatar>
            <div>
              <div class="font-weight-medium">{{ item.recipient_name }}</div>
              <div class="text-caption text-medium-emphasis">
                <v-icon size="11">mdi-phone</v-icon> {{ item.recipient_phone }}
              </div>
            </div>
          </div>
        </template>
        <template #item.delivery_address="{ item }">
          <div
            class="text-body-2 text-truncate-2"
            style="max-width: 240px"
            :title="item.delivery_address"
          >
            <v-icon size="13">mdi-map-marker</v-icon>
            {{ item.delivery_address }}
            <v-icon
              v-if="item.latitude && item.longitude"
              size="12" color="success" class="ml-1"
              title="GPS pinned"
            >mdi-crosshairs-gps</v-icon>
          </div>
        </template>
        <template #item.assigned_to_name="{ item }">
          <span v-if="item.driver_display">
            <v-icon size="14" color="indigo">mdi-account-tie</v-icon>
            {{ item.driver_display }}
            <v-icon
              v-if="!item.assigned_to && item.assigned_driver_name"
              size="11" color="grey" class="ml-1"
              title="Manual entry"
            >mdi-pencil</v-icon>
          </span>
          <em v-else class="text-medium-emphasis">Unassigned</em>
        </template>
        <template #item.scheduled_at="{ item }">
          <span v-if="item.scheduled_at" class="text-body-2">
            {{ formatDate(item.scheduled_at) }}
          </span>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.status="{ item }">
          <v-chip
            :color="statusMeta(item.status).color" size="small" variant="tonal"
          >
            <v-icon start size="13">{{ statusMeta(item.status).icon }}</v-icon>
            {{ statusMeta(item.status).title }}
          </v-chip>
        </template>
        <template #item.delivery_fee="{ item }">
          <span class="font-weight-medium">KSh {{ formatNumber(item.delivery_fee) }}</span>
        </template>
        <template #item.actions="{ item }">
          <v-btn
            icon="mdi-eye-outline" variant="text" size="small"
            @click="openDetail(item)"
          />
          <v-btn
            icon="mdi-account-arrow-right" variant="text" size="small"
            color="indigo" @click="openAssign(item)"
          />
          <v-menu>
            <template #activator="{ props }">
              <v-btn
                icon="mdi-dots-vertical" variant="text" size="small"
                v-bind="props"
              />
            </template>
            <v-list density="compact">
              <v-list-item
                v-for="t in nextTransitions(item)"
                :key="t.value"
                :prepend-icon="t.icon"
                :title="t.label"
                @click="updateStatus(item, t.value)"
              />
              <v-divider />
              <v-list-item
                prepend-icon="mdi-content-copy" title="Copy address"
                @click="copyAddress(item)"
              />
              <v-list-item
                prepend-icon="mdi-delete-outline" title="Delete"
                base-color="error" @click="confirmDelete(item)"
              />
            </v-list>
          </v-menu>
        </template>
        <template #no-data>
          <EmptyState
            icon="mdi-truck-outline" title="No deliveries found"
            message="Delivery records from POS sales will appear here."
          />
        </template>
      </v-data-table>
    </v-card>

    <!-- Create dialog -->
    <v-dialog v-model="createDialog" max-width="640" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon color="indigo" class="mr-2">mdi-truck-plus</v-icon>
          New Delivery
          <v-spacer />
          <v-btn
            icon="mdi-close" variant="text" size="small"
            @click="createDialog = false"
          />
        </v-card-title>
        <v-divider />
        <v-card-text class="pt-4">
          <v-row dense>
            <v-col cols="12">
              <v-autocomplete
                v-model="txnSelection"
                v-model:search="txnQuery"
                :items="txnResults"
                :loading="loadingTxn"
                item-title="display"
                item-value="id"
                return-object hide-no-data hide-details="auto"
                no-filter clearable
                label="POS Transaction *"
                placeholder="Search by number, customer, or paste ID…"
                variant="outlined" density="comfortable"
                prepend-inner-icon="mdi-receipt-text"
                :error-messages="formErrors.transaction"
                @update:search="onTxnSearch"
                @update:model-value="onTxnPicked"
              >
                <template #item="{ props, item }">
                  <v-list-item v-bind="props" prepend-icon="mdi-receipt">
                    <template #subtitle>
                      <span class="text-caption">
                        {{ item.raw.customer_name || 'Walk-in' }}
                        · KSh {{ formatNumber(item.raw.total) }}
                        · {{ relativeTime(item.raw.created_at) }}
                      </span>
                    </template>
                  </v-list-item>
                </template>
                <template #append-inner>
                  <v-tooltip text="Enter transaction ID manually" location="top">
                    <template #activator="{ props }">
                      <v-btn
                        v-bind="props" icon="mdi-keyboard-outline"
                        variant="text" size="small"
                        :color="manualTxn ? 'indigo' : undefined"
                        @click.stop="manualTxn = !manualTxn"
                      />
                    </template>
                  </v-tooltip>
                </template>
              </v-autocomplete>
              <v-text-field
                v-if="manualTxn"
                v-model.number="form.transaction"
                label="Transaction ID (manual)"
                hint="Numeric primary key of the POS transaction"
                persistent-hint type="number"
                variant="outlined" density="comfortable" class="mt-2"
                prepend-inner-icon="mdi-pound"
                :error-messages="formErrors.transaction"
              />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field
                v-model="form.recipient_name" label="Recipient name *"
                variant="outlined" density="comfortable"
                prepend-inner-icon="mdi-account"
                :error-messages="formErrors.recipient_name"
              />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field
                v-model="form.recipient_phone" label="Recipient phone *"
                variant="outlined" density="comfortable"
                prepend-inner-icon="mdi-phone"
                :error-messages="formErrors.recipient_phone"
              />
            </v-col>
            <v-col cols="12">
              <v-autocomplete
                v-model="addressSelection"
                v-model:search="addressQuery"
                :items="addressPredictions"
                :loading="loadingPlaces"
                item-title="description"
                item-value="place_id"
                label="Delivery address *"
                placeholder="Start typing an address…"
                variant="outlined" density="comfortable"
                prepend-inner-icon="mdi-map-marker"
                return-object hide-no-data hide-details="auto"
                no-filter clearable
                :error-messages="formErrors.delivery_address"
                @update:search="onAddressSearch"
                @update:model-value="onAddressPicked"
              >
                <template #append-inner>
                  <v-tooltip text="Use my current location" location="top">
                    <template #activator="{ props }">
                      <v-btn
                        v-bind="props" icon="mdi-crosshairs-gps"
                        variant="text" size="small" color="indigo"
                        :loading="locating" @click.stop="useMyLocation"
                      />
                    </template>
                  </v-tooltip>
                </template>
                <template #item="{ props, item }">
                  <v-list-item v-bind="props" prepend-icon="mdi-map-marker-outline">
                    <v-list-item-subtitle v-if="item.raw.structured_formatting?.secondary_text">
                      {{ item.raw.structured_formatting.secondary_text }}
                    </v-list-item-subtitle>
                  </v-list-item>
                </template>
              </v-autocomplete>
              <v-textarea
                v-if="form.delivery_address"
                v-model="form.delivery_address"
                label="Address (editable)"
                variant="outlined" density="comfortable" rows="2" auto-grow
                prepend-inner-icon="mdi-pencil" class="mt-2"
                hide-details="auto"
              />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field
                v-model.number="form.delivery_fee" label="Delivery fee (KSh)"
                type="number" variant="outlined" density="comfortable"
                prepend-inner-icon="mdi-cash"
                :error-messages="formErrors.delivery_fee"
              />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field
                v-model="form.scheduled_at" label="Schedule (optional)"
                type="datetime-local" variant="outlined" density="comfortable"
                prepend-inner-icon="mdi-calendar-clock"
                :error-messages="formErrors.scheduled_at"
              />
            </v-col>
            <v-col cols="12">
              <v-combobox
                v-model="driverInput"
                :items="staffOptions"
                item-title="name"
                return-object
                label="Assign driver (optional)"
                hint="Pick a staff member or type any name"
                persistent-hint clearable
                variant="outlined" density="comfortable"
                prepend-inner-icon="mdi-account-tie"
                :loading="loadingStaff"
              />
            </v-col>
            <v-col cols="12">
              <v-textarea
                v-model="form.notes" label="Notes (optional)"
                variant="outlined" density="comfortable" rows="2" auto-grow
                prepend-inner-icon="mdi-note-text"
              />
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="createDialog = false">Cancel</v-btn>
          <v-btn
            color="primary" variant="flat" :loading="saving" @click="saveCreate"
          >
            Create delivery
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Detail dialog -->
    <v-dialog v-model="detailDialog" max-width="720">
      <v-card v-if="selected" rounded="xl">
        <div
          class="detail-hero pa-5"
          :style="{
            background:
              `linear-gradient(135deg, ${heroColor(selected.status, 0.95)} 0%, ${heroColor(selected.status, 0.55)} 100%)`,
          }"
        >
          <div class="d-flex align-center">
            <v-avatar color="white" size="52" class="mr-4 elevation-2">
              <v-icon
                :color="statusMeta(selected.status).color + '-darken-2'"
                size="28"
              >
                {{ statusMeta(selected.status).icon }}
              </v-icon>
            </v-avatar>
            <div class="flex-grow-1">
              <div class="text-h6 font-weight-bold text-white">
                {{ selected.transaction_number || `Transaction #${selected.transaction}` }}
              </div>
              <div class="text-body-2 text-white" style="opacity: 0.9">
                {{ statusMeta(selected.status).title }}
                · created {{ relativeTime(selected.created_at) }}
              </div>
            </div>
            <v-btn
              icon="mdi-close" variant="text" color="white"
              @click="detailDialog = false"
            />
          </div>
        </div>

        <v-card-text class="pt-4">
          <!-- Timeline -->
          <div class="mb-5">
            <div class="text-overline text-medium-emphasis mb-2">Status timeline</div>
            <div
              v-if="['failed','cancelled'].includes(selected.status)"
              class="pa-3 rounded-lg"
              :class="`bg-${statusMeta(selected.status).color}-lighten-5`"
            >
              <v-icon :color="statusMeta(selected.status).color" class="mr-2">
                {{ statusMeta(selected.status).icon }}
              </v-icon>
              This delivery was
              <strong>{{ statusMeta(selected.status).title.toLowerCase() }}</strong>.
            </div>
            <div v-else class="d-flex align-center">
              <template v-for="(step, i) in flowSteps" :key="step.value">
                <div class="flex-grow-0 d-flex flex-column align-center" style="min-width: 60px">
                  <v-avatar
                    :color="i <= flowIndex ? statusMeta(step.value).color : 'grey-lighten-2'"
                    size="32"
                  >
                    <v-icon color="white" size="16">
                      {{ i <= flowIndex ? 'mdi-check' : step.icon }}
                    </v-icon>
                  </v-avatar>
                  <div
                    class="text-caption mt-1"
                    :class="i === flowIndex ? 'font-weight-bold' : 'text-medium-emphasis'"
                  >
                    {{ step.title }}
                  </div>
                </div>
                <div
                  v-if="i < flowSteps.length - 1"
                  class="flex-grow-1 mx-1"
                  style="height: 3px; border-radius: 3px"
                  :style="{
                    background: i < flowIndex
                      ? 'rgb(var(--v-theme-primary))'
                      : 'rgb(var(--v-theme-on-surface) / 0.12)',
                  }"
                />
              </template>
            </div>
          </div>

          <v-row dense>
            <v-col cols="12" md="6">
              <div class="info-tile pa-3 rounded-lg">
                <div class="text-overline text-medium-emphasis">Recipient</div>
                <div class="font-weight-medium">{{ selected.recipient_name }}</div>
                <div class="text-body-2">
                  <v-icon size="14">mdi-phone</v-icon>
                  {{ selected.recipient_phone }}
                </div>
              </div>
            </v-col>
            <v-col cols="12" md="6">
              <div class="info-tile pa-3 rounded-lg">
                <div class="text-overline text-medium-emphasis">Driver</div>
                <div v-if="selected.driver_display" class="font-weight-medium">
                  <v-icon size="16" color="indigo">mdi-account-tie</v-icon>
                  {{ selected.driver_display }}
                  <v-chip
                    v-if="!selected.assigned_to && selected.assigned_driver_name"
                    size="x-small" variant="tonal" color="grey" class="ml-1"
                  >
                    Manual
                  </v-chip>
                </div>
                <em v-else class="text-medium-emphasis">Unassigned</em>
                <v-btn
                  size="x-small" variant="text" color="indigo" class="mt-1"
                  prepend-icon="mdi-swap-horizontal"
                  @click="openAssign(selected); detailDialog = false"
                >
                  Change
                </v-btn>
              </div>
            </v-col>
            <v-col cols="12">
              <div class="info-tile pa-3 rounded-lg">
                <div class="d-flex align-center justify-space-between mb-1">
                  <div class="text-overline text-medium-emphasis">Delivery address</div>
                  <v-chip
                    v-if="selected.latitude && selected.longitude"
                    size="x-small" color="success" variant="tonal"
                    prepend-icon="mdi-crosshairs-gps"
                  >
                    Pinned
                  </v-chip>
                </div>
                <div>
                  <v-icon size="16" color="indigo">mdi-map-marker</v-icon>
                  {{ selected.delivery_address }}
                </div>
                <div
                  v-if="selected.latitude && selected.longitude"
                  class="text-caption text-medium-emphasis mt-1 d-flex align-center"
                  style="gap: 8px"
                >
                  <span>
                    {{ Number(selected.latitude).toFixed(6) }},
                    {{ Number(selected.longitude).toFixed(6) }}
                  </span>
                  <v-btn
                    size="x-small" variant="text" color="indigo"
                    prepend-icon="mdi-open-in-new"
                    :href="mapsLink(selected)" target="_blank"
                  >
                    Open in Maps
                  </v-btn>
                </div>
              </div>
            </v-col>
            <v-col cols="6" md="4">
              <div class="info-tile pa-3 rounded-lg">
                <div class="text-overline text-medium-emphasis">Scheduled</div>
                <div class="text-body-2">{{ formatDate(selected.scheduled_at) }}</div>
              </div>
            </v-col>
            <v-col cols="6" md="4">
              <div class="info-tile pa-3 rounded-lg">
                <div class="text-overline text-medium-emphasis">Delivered at</div>
                <div class="text-body-2">{{ formatDate(selected.delivered_at) }}</div>
              </div>
            </v-col>
            <v-col cols="12" md="4">
              <div class="info-tile pa-3 rounded-lg">
                <div class="text-overline text-medium-emphasis">Delivery fee</div>
                <div class="text-h6 font-weight-bold text-success">
                  KSh {{ formatNumber(selected.delivery_fee) }}
                </div>
              </div>
            </v-col>
            <v-col v-if="selected.notes" cols="12">
              <div class="info-tile pa-3 rounded-lg">
                <div class="text-overline text-medium-emphasis">Notes</div>
                <div class="text-body-2">{{ selected.notes }}</div>
              </div>
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3 flex-wrap" style="gap: 6px">
          <v-btn
            variant="outlined" prepend-icon="mdi-content-copy"
            @click="copyAddress(selected)"
          >
            Copy address
          </v-btn>
          <v-spacer />
          <v-btn
            v-for="t in nextTransitions(selected)" :key="t.value"
            :color="t.color" variant="flat" :prepend-icon="t.icon"
            @click="updateStatus(selected, t.value); detailDialog = false"
          >
            {{ t.label }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Assign driver dialog -->
    <v-dialog v-model="assignDialog" max-width="480" persistent>
      <v-card v-if="selected" rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon color="indigo" class="mr-2">mdi-account-tie</v-icon>
          Assign driver
          <v-spacer />
          <v-btn
            icon="mdi-close" variant="text" size="small"
            @click="assignDialog = false"
          />
        </v-card-title>
        <v-divider />
        <v-card-text class="pt-4">
          <div class="text-body-2 text-medium-emphasis mb-3">
            For delivery to <strong>{{ selected.recipient_name }}</strong>
            ({{ selected.transaction_number || `#${selected.transaction}` }})
          </div>
          <v-combobox
            v-model="assignSelection"
            :items="staffOptions"
            item-title="name" return-object
            label="Driver"
            hint="Pick a staff member or type any name"
            persistent-hint :loading="loadingStaff"
            variant="outlined" density="comfortable"
            prepend-inner-icon="mdi-account"
          />
          <v-alert
            v-if="!staffOptions.length && !loadingStaff" type="info"
            density="compact" variant="tonal"
          >
            No staff found — you can still type a driver name above.
          </v-alert>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="assignDialog = false">Cancel</v-btn>
          <v-btn
            color="primary" variant="flat" :loading="saving"
            :disabled="!assignSelection" @click="saveAssign"
          >
            Assign
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Delete confirm -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="xl">
        <v-card-title>Delete delivery?</v-card-title>
        <v-card-text v-if="target">
          The delivery for
          <strong>{{ target.recipient_name }}</strong>
          ({{ target.transaction_number || `#${target.transaction}` }})
          will be permanently removed.
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" variant="flat" :loading="saving" @click="doDelete">
            Delete
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar
      v-model="snack.show" :color="snack.color" location="top right" timeout="3000"
    >
      {{ snack.message }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import EmptyState from '~/components/EmptyState.vue'

const { $api } = useNuxtApp()
const { getPredictions, getPlaceDetails, reverseGeocode } = useGoogleMaps()

// ─── State ───────────────────────────────────────────────────────────
const items = ref([])
const staff = ref([])
const loading = ref(false)
const loadingStaff = ref(false)
const saving = ref(false)
const search = ref('')
const filterStatus = ref('all')
const viewMode = ref('grid')

const viewItems = [
  { title: 'Grid', value: 'grid' },
  { title: 'Table', value: 'table' },
]

const STATUSES = [
  { value: 'pending',    title: 'Pending',    color: 'orange',  icon: 'mdi-clock-outline' },
  { value: 'assigned',   title: 'Assigned',   color: 'indigo',  icon: 'mdi-account-check' },
  { value: 'in_transit', title: 'In Transit', color: 'blue',    icon: 'mdi-truck-fast' },
  { value: 'delivered',  title: 'Delivered',  color: 'success', icon: 'mdi-check-circle' },
  { value: 'failed',     title: 'Failed',     color: 'error',   icon: 'mdi-alert-circle' },
  { value: 'cancelled',  title: 'Cancelled',  color: 'grey',    icon: 'mdi-cancel' },
]

const statusItems = [
  { title: 'All statuses', value: 'all' },
  ...STATUSES.map(s => ({ title: s.title, value: s.value })),
]

const statusChips = [
  { value: 'all', title: 'All', color: 'primary', icon: 'mdi-format-list-bulleted' },
  ...STATUSES,
]

const headers = [
  { title: 'Transaction',  key: 'transaction',        sortable: true },
  { title: 'Recipient',    key: 'recipient_name',     sortable: true },
  { title: 'Address',      key: 'delivery_address',   sortable: false },
  { title: 'Driver',       key: 'assigned_to_name',   sortable: false },
  { title: 'Scheduled',    key: 'scheduled_at',       sortable: true },
  { title: 'Status',       key: 'status',             sortable: true },
  { title: 'Fee',          key: 'delivery_fee',       sortable: true, align: 'end' },
  { title: '',             key: 'actions',            sortable: false, align: 'end', width: 150 },
]

const TRANSITIONS = {
  pending:    [{ value: 'assigned',   label: 'Mark Assigned',   color: 'indigo',  icon: 'mdi-account-check' }],
  assigned:   [
    { value: 'in_transit', label: 'Start Delivery', color: 'blue',  icon: 'mdi-truck-fast' },
    { value: 'cancelled',  label: 'Cancel',         color: 'grey',  icon: 'mdi-cancel' },
  ],
  in_transit: [
    { value: 'delivered',  label: 'Complete',       color: 'success', icon: 'mdi-check-circle' },
    { value: 'failed',     label: 'Mark Failed',    color: 'error',   icon: 'mdi-alert-circle' },
  ],
  delivered:  [],
  failed:     [{ value: 'pending', label: 'Retry', color: 'orange', icon: 'mdi-refresh' }],
  cancelled:  [],
}

const flowSteps = STATUSES.filter(s =>
  ['pending', 'assigned', 'in_transit', 'delivered'].includes(s.value),
)

// ─── Dialogs ─────────────────────────────────────────────────────────
const createDialog = ref(false)
const detailDialog = ref(false)
const assignDialog = ref(false)
const deleteDialog = ref(false)
const selected = ref(null)
const target = ref(null)
const assignSelection = ref(null)
const driverInput = ref(null)

// Convert combobox value (object | string | null) into
// { assigned_to, assigned_driver_name }.
function resolveDriver(val) {
  if (val == null || val === '') {
    return { assigned_to: null, assigned_driver_name: '' }
  }
  if (typeof val === 'object') {
    if (val.id) return { assigned_to: val.id, assigned_driver_name: '' }
    if (val.name) return { assigned_to: null, assigned_driver_name: String(val.name).trim() }
    return { assigned_to: null, assigned_driver_name: '' }
  }
  return { assigned_to: null, assigned_driver_name: String(val).trim() }
}

const form = reactive({
  transaction: null,
  recipient_name: '',
  recipient_phone: '',
  delivery_address: '',
  latitude: null,
  longitude: null,
  delivery_fee: 0,
  scheduled_at: '',
  assigned_to: null,
  notes: '',
})
const formErrors = reactive({})

// ─── POS Transaction search ─────────────────────────────────────
const txnQuery = ref('')
const txnSelection = ref(null)
const txnResults = ref([])
const loadingTxn = ref(false)
const manualTxn = ref(false)
let _txnTimer = null

function decorateTxn(t) {
  return {
    ...t,
    display: `${t.transaction_number} · ${t.customer_name || 'Walk-in'} · KSh ${formatNumber(t.total)}`,
  }
}

function onTxnSearch(q) {
  if (_txnTimer) clearTimeout(_txnTimer)
  if (!q || q.length < 2) {
    txnResults.value = []
    return
  }
  loadingTxn.value = true
  _txnTimer = setTimeout(async () => {
    try {
      const { data } = await $api.get('/pos/transactions/', {
        params: { search: q, page_size: 25, ordering: '-created_at' },
      })
      const list = data?.results || (Array.isArray(data) ? data : [])
      txnResults.value = list.map(decorateTxn)
    } catch {
      txnResults.value = []
    } finally {
      loadingTxn.value = false
    }
  }, 280)
}

function onTxnPicked(t) {
  if (!t) {
    form.transaction = null
    return
  }
  form.transaction = t.id
  // Autofill recipient details if empty
  if (!form.recipient_name && t.customer_name) form.recipient_name = t.customer_name
  if (!form.recipient_phone && t.customer_phone) form.recipient_phone = t.customer_phone
  formErrors.transaction = undefined
}

// ─── Google Places autocomplete ──────────────────────────────────────
const addressQuery = ref('')
const addressSelection = ref(null)
const addressPredictions = ref([])
const loadingPlaces = ref(false)
const locating = ref(false)
let _searchTimer = null

function round6(n) {
  if (n == null || n === '' || isNaN(Number(n))) return null
  return Math.round(Number(n) * 1e6) / 1e6
}

function onAddressSearch(q) {
  if (_searchTimer) clearTimeout(_searchTimer)
  if (!q || q.length < 3) {
    addressPredictions.value = []
    return
  }
  loadingPlaces.value = true
  _searchTimer = setTimeout(async () => {
    try {
      addressPredictions.value = await getPredictions(q, { country: 'ke' })
    } catch (e) {
      addressPredictions.value = []
      notify(e?.message || 'Places lookup failed', 'error')
    } finally {
      loadingPlaces.value = false
    }
  }, 280)
}

async function onAddressPicked(pred) {
  if (!pred?.place_id) return
  try {
    const details = await getPlaceDetails(pred.place_id)
    form.delivery_address = details.address || pred.description
    form.latitude = round6(details.lat)
    form.longitude = round6(details.lng)
    formErrors.delivery_address = undefined
  } catch (e) {
    form.delivery_address = pred.description
    notify(e?.message || 'Could not resolve place', 'error')
  }
}

async function useMyLocation() {
  if (!navigator.geolocation) {
    notify('Geolocation not supported by this browser', 'error'); return
  }
  locating.value = true
  navigator.geolocation.getCurrentPosition(
    async ({ coords }) => {
      try {
        const addr = await reverseGeocode(coords.latitude, coords.longitude)
        form.delivery_address = addr
        form.latitude = round6(coords.latitude)
        form.longitude = round6(coords.longitude)
        addressQuery.value = addr
        formErrors.delivery_address = undefined
        notify('Address detected from your location')
      } catch (e) {
        notify(e?.message || 'Reverse geocoding failed', 'error')
      } finally {
        locating.value = false
      }
    },
    (err) => {
      locating.value = false
      notify(err.message || 'Could not get location', 'error')
    },
    { enableHighAccuracy: true, timeout: 10000 },
  )
}

const snack = reactive({ show: false, color: 'success', message: '' })
function notify(message, color = 'success') {
  Object.assign(snack, { show: true, color, message })
}

// ─── Computed ────────────────────────────────────────────────────────
const filteredItems = computed(() => {
  const q = (search.value || '').toLowerCase().trim()
  return items.value.filter(d => {
    if (filterStatus.value !== 'all' && d.status !== filterStatus.value) return false
    if (!q) return true
    return ['recipient_name', 'recipient_phone', 'delivery_address', 'transaction_number']
      .some(k => (d[k] || '').toString().toLowerCase().includes(q))
  })
})

const kpis = computed(() => {
  const pending = items.value.filter(d => d.status === 'pending').length
  const inTransit = items.value.filter(d => d.status === 'in_transit').length
  const delivered = items.value.filter(d => d.status === 'delivered').length
  const revenue = items.value
    .filter(d => d.status === 'delivered')
    .reduce((s, d) => s + Number(d.delivery_fee || 0), 0)
  return [
    { label: 'Pending',          value: pending,                            icon: 'mdi-clock-outline', color: 'orange' },
    { label: 'In Transit',       value: inTransit,                          icon: 'mdi-truck-fast',    color: 'blue' },
    { label: 'Delivered',        value: delivered,                          icon: 'mdi-check-circle',  color: 'success' },
    { label: 'Delivery Revenue', value: `KSh ${formatNumber(revenue)}`,     icon: 'mdi-cash',          color: 'teal' },
  ]
})

const staffOptions = computed(() =>
  staff.value.map(s => ({
    id: s.id,
    name: [
      s.first_name || '',
      s.last_name || '',
    ].filter(Boolean).join(' ').trim()
      || s.full_name
      || s.username
      || `Staff #${s.id}`,
  })),
)

const flowIndex = computed(() => {
  if (!selected.value) return 0
  const i = flowSteps.findIndex(s => s.value === selected.value.status)
  return i < 0 ? 0 : i
})

// ─── Helpers ─────────────────────────────────────────────────────────
function statusMeta(s) {
  return STATUSES.find(x => x.value === s)
    || { value: s, title: s || '—', color: 'grey', icon: 'mdi-help-circle' }
}
function nextTransitions(d) { return TRANSITIONS[d.status] || [] }
function countFor(value) {
  if (value === 'all') return items.value.length
  return items.value.filter(d => d.status === value).length
}
function heroColor(status, opacity = 1) {
  const map = {
    pending: '249, 168, 37', assigned: '63, 81, 181', in_transit: '33, 150, 243',
    delivered: '76, 175, 80', failed: '244, 67, 54', cancelled: '120, 144, 156',
  }
  return `rgba(${map[status] || '120, 144, 156'}, ${opacity})`
}
function formatNumber(n) {
  const v = Number(n || 0)
  return v.toLocaleString('en-KE', { maximumFractionDigits: 2 })
}
function formatDate(d) {
  if (!d) return '—'
  const dt = new Date(d)
  return dt.toLocaleString('en-KE', {
    weekday: 'short', month: 'short', day: 'numeric',
    hour: '2-digit', minute: '2-digit',
  })
}
function relativeTime(d) {
  if (!d) return ''
  const diff = Date.now() - new Date(d).getTime()
  const s = Math.floor(diff / 1000)
  if (s < 60) return 'just now'
  const m = Math.floor(s / 60)
  if (m < 60) return `${m}m ago`
  const h = Math.floor(m / 60)
  if (h < 24) return `${h}h ago`
  const days = Math.floor(h / 24)
  if (days < 7) return `${days}d ago`
  return new Date(d).toLocaleDateString('en-KE', { month: 'short', day: 'numeric' })
}
function initials(name) {
  if (!name) return '?'
  return name.split(/\s+/).filter(Boolean).slice(0, 2).map(s => s[0].toUpperCase()).join('')
}
function avatarColor(name) {
  const palette = ['teal', 'indigo', 'deep-purple', 'pink', 'orange', 'cyan', 'green', 'blue']
  let h = 0
  for (const ch of (name || '')) h = (h * 31 + ch.charCodeAt(0)) >>> 0
  return palette[h % palette.length]
}
function copyAddress(d) {
  if (!d?.delivery_address) return
  navigator.clipboard?.writeText(d.delivery_address)
  notify('Address copied to clipboard')
}

function mapsLink(d) {
  if (d?.latitude && d?.longitude) {
    return `https://www.google.com/maps/search/?api=1&query=${d.latitude},${d.longitude}`
  }
  return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(d?.delivery_address || '')}`
}

// ─── Load ────────────────────────────────────────────────────────────
async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/pharmacy-profile/deliveries/', {
      params: { ordering: '-created_at', page_size: 200 },
    })
    items.value = data?.results || (Array.isArray(data) ? data : [])
  } catch (e) {
    notify(extractError(e) || 'Failed to load deliveries', 'error')
    items.value = []
  } finally {
    loading.value = false
  }
}

async function loadStaff() {
  loadingStaff.value = true
  try {
    const { data } = await $api.get('/staff/', { params: { page_size: 500 } })
    staff.value = data?.results || (Array.isArray(data) ? data : [])
  } catch {
    staff.value = []
  } finally {
    loadingStaff.value = false
  }
}

// ─── Create ──────────────────────────────────────────────────────────
function openCreate() {
  Object.assign(form, {
    transaction: null,
    recipient_name: '', recipient_phone: '',
    delivery_address: '', latitude: null, longitude: null,
    delivery_fee: 0,
    scheduled_at: '', assigned_to: null, notes: '',
  })
  Object.keys(formErrors).forEach(k => delete formErrors[k])
  addressQuery.value = ''
  addressSelection.value = null
  addressPredictions.value = []
  driverInput.value = null
  txnQuery.value = ''
  txnSelection.value = null
  txnResults.value = []
  manualTxn.value = false
  createDialog.value = true
}

async function saveCreate() {
  Object.keys(formErrors).forEach(k => delete formErrors[k])
  if (!form.transaction) formErrors.transaction = 'POS Transaction ID is required'
  if (!form.recipient_name?.trim()) formErrors.recipient_name = 'Required'
  if (!form.recipient_phone?.trim()) formErrors.recipient_phone = 'Required'
  if (!form.delivery_address?.trim()) formErrors.delivery_address = 'Required'
  if (Object.keys(formErrors).length) return

  saving.value = true
  try {
    const payload = {
      transaction: form.transaction,
      recipient_name: form.recipient_name.trim(),
      recipient_phone: form.recipient_phone.trim(),
      delivery_address: form.delivery_address.trim(),
      delivery_fee: form.delivery_fee || 0,
    }
    if (form.latitude != null) payload.latitude = form.latitude
    if (form.longitude != null) payload.longitude = form.longitude
    const drv = resolveDriver(driverInput.value)
    if (drv.assigned_to) payload.assigned_to = drv.assigned_to
    if (drv.assigned_driver_name) payload.assigned_driver_name = drv.assigned_driver_name
    if (form.notes?.trim()) payload.notes = form.notes.trim()
    if (form.scheduled_at) {
      payload.scheduled_at = new Date(form.scheduled_at).toISOString()
    }
    await $api.post('/pharmacy-profile/deliveries/', payload)
    notify('Delivery created')
    createDialog.value = false
    await load()
  } catch (e) {
    const data = e?.response?.data
    if (data && typeof data === 'object') {
      for (const [k, v] of Object.entries(data)) {
        formErrors[k] = Array.isArray(v) ? v.join(' ') : String(v)
      }
    }
    notify(extractError(e) || 'Save failed', 'error')
  } finally {
    saving.value = false
  }
}

// ─── Detail / status ─────────────────────────────────────────────────
function openDetail(d) {
  selected.value = d
  detailDialog.value = true
}

async function updateStatus(d, status) {
  try {
    await $api.post(`/pharmacy-profile/deliveries/${d.id}/update_status/`, { status })
    notify(`Marked as ${status.replace('_', ' ')}`)
    await load()
  } catch (e) {
    notify(extractError(e) || 'Failed to update status', 'error')
  }
}

// ─── Assign ──────────────────────────────────────────────────────────
function openAssign(d) {
  selected.value = d
  if (d.assigned_to) {
    assignSelection.value = staffOptions.value.find(s => s.id === d.assigned_to)
      || { id: d.assigned_to, name: d.assigned_to_name || `Staff #${d.assigned_to}` }
  } else if (d.assigned_driver_name) {
    assignSelection.value = d.assigned_driver_name
  } else {
    assignSelection.value = null
  }
  assignDialog.value = true
}

async function saveAssign() {
  if (!selected.value) return
  const drv = resolveDriver(assignSelection.value)
  if (!drv.assigned_to && !drv.assigned_driver_name) return
  saving.value = true
  try {
    const patch = {
      assigned_to: drv.assigned_to,
      assigned_driver_name: drv.assigned_driver_name,
    }
    if (selected.value.status === 'pending') patch.status = 'assigned'
    await $api.patch(`/pharmacy-profile/deliveries/${selected.value.id}/`, patch)
    notify('Driver assigned')
    assignDialog.value = false
    await load()
  } catch (e) {
    notify(extractError(e) || 'Failed to assign driver', 'error')
  } finally {
    saving.value = false
  }
}

// ─── Delete ──────────────────────────────────────────────────────────
function confirmDelete(d) { target.value = d; deleteDialog.value = true }
async function doDelete() {
  if (!target.value) return
  saving.value = true
  try {
    await $api.delete(`/pharmacy-profile/deliveries/${target.value.id}/`)
    notify('Delivery deleted')
    deleteDialog.value = false
    await load()
  } catch (e) {
    notify(extractError(e) || 'Delete failed', 'error')
  } finally {
    saving.value = false
  }
}

// ─── Export ──────────────────────────────────────────────────────────
function exportCsv() {
  const rows = filteredItems.value
  if (!rows.length) { notify('Nothing to export', 'warning'); return }
  const lines = ['Transaction,Recipient,Phone,Address,Driver,Status,Scheduled,DeliveredAt,Fee,Created']
  rows.forEach(d => {
    lines.push([
      JSON.stringify(d.transaction_number || `#${d.transaction}`),
      JSON.stringify(d.recipient_name || ''),
      JSON.stringify(d.recipient_phone || ''),
      JSON.stringify(d.delivery_address || ''),
      JSON.stringify(d.driver_display || ''),
      d.status,
      d.scheduled_at || '',
      d.delivered_at || '',
      d.delivery_fee || 0,
      d.created_at || '',
    ].join(','))
  })
  const blob = new Blob([lines.join('\n')], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `deliveries-${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

function extractError(e) {
  const d = e?.response?.data
  if (!d) return e?.message || ''
  if (typeof d === 'string') return d
  if (d.detail) return d.detail
  return Object.entries(d)
    .map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(' ') : v}`).join(' · ')
}

onMounted(() => {
  load()
  loadStaff()
})
</script>

<style scoped>
.hero {
  background: linear-gradient(135deg, #312e81 0%, #4f46e5 50%, #06b6d4 100%);
  border-radius: 20px !important;
  box-shadow: 0 12px 32px rgba(49, 46, 129, 0.25);
}
.stat-card {
  background: rgba(255, 255, 255, 0.95);
  color: rgba(0, 0, 0, 0.85);
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.stat-card:hover { transform: translateY(-2px); box-shadow: 0 8px 22px rgba(0, 0, 0, 0.12); }

.delivery-card { transition: transform 0.15s ease, box-shadow 0.15s ease; }
.delivery-card:hover { transform: translateY(-2px); box-shadow: 0 10px 24px rgba(79, 70, 229, 0.15); }

.detail-hero {
  border-top-left-radius: 12px;
  border-top-right-radius: 12px;
}

.info-tile {
  background: rgb(var(--v-theme-surface-variant) / 0.4);
  border: 1px solid rgb(var(--v-theme-on-surface) / 0.06);
}

.text-truncate-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
