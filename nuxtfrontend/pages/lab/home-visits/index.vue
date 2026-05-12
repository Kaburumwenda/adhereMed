<template>
  <v-container fluid class="pa-4 pa-md-6 hv-page">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-2 mb-4">
      <v-icon color="primary" size="28" class="mr-2">mdi-home-import-outline</v-icon>
      <div>
        <div class="text-h6 font-weight-bold">Home sample visits</div>
        <div class="text-caption text-medium-emphasis">Schedule, dispatch and track at-home specimen collection</div>
      </div>
      <v-spacer />
      <v-btn variant="text" prepend-icon="mdi-refresh" :loading="r.loading.value" @click="r.list()">Refresh</v-btn>
      <v-btn variant="outlined" prepend-icon="mdi-tray-arrow-down" @click="exportCsv">Export</v-btn>
      <v-btn color="primary" prepend-icon="mdi-plus" @click="openNew()">Schedule visit</v-btn>
    </div>

    <!-- KPIs -->
    <v-row dense>
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="4" lg="2">
        <v-card flat rounded="lg" class="pa-3" border
                :variant="activeKpi === k.key ? 'tonal' : 'flat'"
                :color="activeKpi === k.key ? k.color : undefined"
                style="cursor:pointer"
                @click="setKpi(k.key)">
          <div class="d-flex align-center">
            <v-avatar :color="`${k.color}-lighten-5`" size="36" class="mr-3">
              <v-icon :color="`${k.color}-darken-2`" size="20">{{ k.icon }}</v-icon>
            </v-avatar>
            <div class="min-width-0">
              <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h6 font-weight-bold">{{ k.value }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Filter bar -->
    <v-card flat rounded="lg" class="mt-4 pa-3" border>
      <v-row dense align="center">
        <v-col cols="12" md="4">
          <v-text-field v-model="r.search.value" prepend-inner-icon="mdi-magnify"
                        placeholder="Search patient, tech, addressâ€¦"
                        variant="outlined" density="comfortable" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="techFilter" :items="techOptions" item-title="title" item-value="value"
                    label="Lab tech" variant="outlined" density="comfortable" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="dateFilter" :items="dateOptions"
                    label="Date" variant="outlined" density="comfortable" hide-details clearable />
        </v-col>
        <v-col cols="12" md="4" class="d-flex justify-end ga-2">
          <v-btn variant="text" size="small" prepend-icon="mdi-filter-remove-outline" @click="resetFilters">Reset</v-btn>
          <v-btn-toggle v-model="view" mandatory density="compact" color="primary" variant="outlined">
            <v-btn value="table" size="small"><v-icon size="18">mdi-format-list-bulleted</v-icon></v-btn>
            <v-btn value="cards" size="small"><v-icon size="18">mdi-view-grid-outline</v-icon></v-btn>
            <v-btn value="schedule" size="small"><v-icon size="18">mdi-calendar-clock</v-icon></v-btn>
          </v-btn-toggle>
        </v-col>
      </v-row>

      <!-- Status pills -->
      <div class="d-flex flex-wrap ga-2 mt-3">
        <v-chip
          v-for="s in statusPills" :key="s.value || 'all'"
          :color="statusFilter === s.value ? s.color : undefined"
          :variant="statusFilter === s.value ? 'flat' : 'outlined'"
          size="small" class="text-capitalize"
          @click="statusFilter = s.value"
        >
          {{ s.label }} ({{ s.count }})
        </v-chip>
      </div>
    </v-card>

    <!-- Table view -->
    <v-card v-if="view === 'table'" flat rounded="lg" class="mt-3" border>
      <v-data-table
        :headers="headers"
        :items="filtered"
        :loading="r.loading.value"
        :items-per-page="20"
        item-value="id"
        hover
        @click:row="(_, { item }) => openEdit(item)"
      >
        <template #item.patient_name="{ item }">
          <div class="d-flex align-center py-1">
            <v-avatar :color="hashColor(item.patient || item.id)" size="32" class="mr-2">
              <span class="text-white text-caption font-weight-bold">{{ initials(item.patient_name) }}</span>
            </v-avatar>
            <div class="min-width-0">
              <div class="font-weight-medium text-truncate">{{ item.patient_name || 'â€”' }}</div>
              <div class="text-caption text-medium-emphasis font-monospace">
                REQ-{{ String(item.lab_order || 0).padStart(5, '0') }}
              </div>
            </div>
          </div>
        </template>
        <template #item.assigned_lab_tech_name="{ value }">
          <div class="d-flex align-center">
            <v-icon size="16" color="indigo" class="mr-1">mdi-doctor</v-icon>
            <span>{{ value || 'Unassigned' }}</span>
          </div>
        </template>
        <template #item.scheduled_date="{ item }">
          <div class="d-flex flex-column">
            <span class="font-weight-medium text-body-2">{{ formatDateOnly(item.scheduled_date) }}</span>
            <span class="text-caption text-medium-emphasis">{{ formatTimeOnly(item.scheduled_time) }}</span>
          </div>
        </template>
        <template #item.patient_address="{ value }">
          <div class="d-flex align-center" style="max-width:260px">
            <v-icon size="14" class="mr-1 text-medium-emphasis">mdi-map-marker-outline</v-icon>
            <span class="text-truncate">{{ value || 'â€”' }}</span>
          </div>
        </template>
        <template #item.status="{ value }">
          <v-chip size="x-small" variant="tonal" :color="statusColor(value)" class="text-capitalize">
            <v-icon size="12" start>{{ statusIcon(value) }}</v-icon>{{ statusLabel(value) }}
          </v-chip>
        </template>
        <template #item.eta="{ item }">
          <v-chip size="x-small" variant="tonal" :color="etaColor(item)">
            <v-icon size="12" start>mdi-timer-outline</v-icon>{{ etaLabel(item) }}
          </v-chip>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end" @click.stop>
            <v-tooltip text="Open in maps" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-map-marker-outline" variant="text" size="small"
                       @click="openMap(item)" />
              </template>
            </v-tooltip>
            <v-tooltip text="Edit" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-pencil-outline" variant="text" size="small"
                       @click="openEdit(item)" />
              </template>
            </v-tooltip>
            <v-menu>
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" />
              </template>
              <v-list density="compact">
                <v-list-item v-if="item.status === 'scheduled'"
                             prepend-icon="mdi-check-decagram-outline" title="Confirm"
                             @click="setStatus(item, 'confirmed')" />
                <v-list-item v-if="['scheduled','confirmed'].includes(item.status)"
                             prepend-icon="mdi-truck-outline" title="Mark in progress"
                             base-color="info" @click="setStatus(item, 'in_progress')" />
                <v-list-item v-if="['confirmed','in_progress'].includes(item.status)"
                             prepend-icon="mdi-check" title="Mark completed"
                             base-color="success" @click="setStatus(item, 'completed')" />
                <v-list-item prepend-icon="mdi-barcode-scan" title="Register specimen"
                             @click="$router.push(`/lab/accessioning?order=${item.lab_order}`)" />
                <v-list-item prepend-icon="mdi-printer-outline" title="Print job sheet"
                             @click="printJobSheet(item)" />
                <v-divider />
                <v-list-item v-if="!['cancelled','completed'].includes(item.status)"
                             prepend-icon="mdi-account-cancel-outline" title="No-show"
                             base-color="warning" @click="setStatus(item, 'no_show')" />
                <v-list-item v-if="!['cancelled','completed'].includes(item.status)"
                             prepend-icon="mdi-close-circle-outline" title="Cancel"
                             base-color="error" @click="setStatus(item, 'cancelled')" />
              </v-list>
            </v-menu>
          </div>
        </template>
        <template #no-data>
          <div class="pa-8 text-center">
            <v-icon size="56" color="grey-lighten-1">mdi-home-import-outline</v-icon>
            <div class="text-subtitle-1 font-weight-medium mt-2">No home visits scheduled</div>
            <div class="text-body-2 text-medium-emphasis mb-4">Schedule a visit for an existing lab order.</div>
            <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openNew()">Schedule visit</v-btn>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- Cards view -->
    <div v-else-if="view === 'cards'" class="mt-3">
      <div v-if="r.loading.value" class="d-flex justify-center pa-12">
        <v-progress-circular indeterminate color="primary" />
      </div>
      <div v-else-if="!filtered.length" class="pa-8 text-center">
        <v-icon size="56" color="grey-lighten-1">mdi-home-import-outline</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-2">No visits found</div>
      </div>
      <v-row v-else dense>
        <v-col v-for="v in filtered" :key="v.id" cols="12" sm="6" md="4" lg="3">
          <v-card flat rounded="lg" class="pa-3 h-100" border hover @click="openEdit(v)" style="cursor:pointer">
            <div class="d-flex align-center mb-2">
              <v-avatar :color="hashColor(v.patient || v.id)" size="40" class="mr-2">
                <span class="text-white text-caption font-weight-bold">{{ initials(v.patient_name) }}</span>
              </v-avatar>
              <div class="min-width-0 flex-grow-1">
                <div class="font-weight-bold text-body-2 text-truncate">{{ v.patient_name }}</div>
                <div class="text-caption text-medium-emphasis font-monospace">
                  REQ-{{ String(v.lab_order || 0).padStart(5, '0') }}
                </div>
              </div>
              <v-chip size="x-small" variant="tonal" :color="statusColor(v.status)" class="text-capitalize">
                {{ statusLabel(v.status) }}
              </v-chip>
            </div>
            <div>
              <div class="d-flex align-center mb-1">
                <v-icon size="14" class="mr-2 text-medium-emphasis">mdi-calendar</v-icon>
                <span class="text-body-2">{{ formatDateOnly(v.scheduled_date) }}</span>
                <v-icon size="4" class="mx-2 text-medium-emphasis">mdi-circle</v-icon>
                <v-icon size="14" class="mr-1 text-medium-emphasis">mdi-clock-outline</v-icon>
                <span class="text-body-2">{{ formatTimeOnly(v.scheduled_time) }}</span>
              </div>
              <div class="d-flex align-center mb-1">
                <v-icon size="14" class="mr-2 text-medium-emphasis">mdi-doctor</v-icon>
                <span class="text-caption">{{ v.assigned_lab_tech_name || 'Unassigned' }}</span>
              </div>
              <div class="d-flex align-start">
                <v-icon size="14" class="mr-2 text-medium-emphasis mt-1">mdi-map-marker-outline</v-icon>
                <span class="text-caption text-truncate-2">{{ v.patient_address || 'â€”' }}</span>
              </div>
            </div>
            <v-divider class="my-2" />
            <div class="d-flex align-center" @click.stop>
              <v-chip size="x-small" variant="tonal" :color="etaColor(v)">
                <v-icon size="12" start>mdi-timer-outline</v-icon>{{ etaLabel(v) }}
              </v-chip>
              <v-spacer />
              <v-btn size="x-small" variant="text" icon="mdi-map-marker-outline" @click="openMap(v)" />
              <v-btn size="x-small" variant="text" icon="mdi-printer-outline" @click="printJobSheet(v)" />
              <v-btn v-if="v.status === 'confirmed' || v.status === 'in_progress'"
                     size="x-small" variant="tonal" color="success"
                     prepend-icon="mdi-check" @click="setStatus(v, 'completed')">Complete</v-btn>
            </div>
          </v-card>
        </v-col>
      </v-row>
    </div>

    <!-- Schedule view (grouped by date) -->
    <div v-else class="mt-3">
      <div v-if="r.loading.value" class="d-flex justify-center pa-12">
        <v-progress-circular indeterminate color="primary" />
      </div>
      <div v-else-if="!groupedByDate.length" class="pa-8 text-center">
        <v-icon size="56" color="grey-lighten-1">mdi-calendar-blank-outline</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-2">No visits scheduled</div>
      </div>
      <div v-for="g in groupedByDate" :key="g.date" class="mb-5">
        <div class="d-flex align-center mb-3">
          <v-icon color="primary" class="mr-2">mdi-calendar</v-icon>
          <div class="text-subtitle-1 font-weight-bold">
            {{ g.label }}
            <v-chip v-if="g.isToday" size="x-small" color="primary" variant="flat" class="ml-2">Today</v-chip>
          </div>
          <v-chip size="x-small" variant="tonal" class="ml-2">
            {{ g.items.length }} visit{{ g.items.length === 1 ? '' : 's' }}
          </v-chip>
        </div>
        <v-row dense>
          <v-col v-for="v in g.items" :key="v.id" cols="12" md="6" lg="4">
            <v-card flat rounded="lg" class="pa-3" border hover @click="openEdit(v)" style="cursor:pointer">
              <div class="d-flex align-center">
                <div class="mr-3 text-center" style="min-width:60px">
                  <div class="text-caption text-medium-emphasis" style="line-height:1">at</div>
                  <div class="text-h6 font-weight-bold" style="line-height:1.1">{{ formatTimeOnly(v.scheduled_time) }}</div>
                </div>
                <div class="flex-grow-1 min-width-0">
                  <div class="font-weight-medium text-truncate">{{ v.patient_name }}</div>
                  <div class="text-caption text-medium-emphasis text-truncate">
                    <v-icon size="12">mdi-doctor</v-icon> {{ v.assigned_lab_tech_name || 'Unassigned' }}
                  </div>
                  <div class="text-caption text-medium-emphasis text-truncate">
                    <v-icon size="12">mdi-map-marker-outline</v-icon> {{ v.patient_address }}
                  </div>
                </div>
                <v-chip size="x-small" variant="tonal" :color="statusColor(v.status)" class="text-capitalize ml-2">
                  {{ statusLabel(v.status) }}
                </v-chip>
              </div>
            </v-card>
          </v-col>
        </v-row>
      </div>
    </div>

    <!-- Schedule / edit dialog -->
    <v-dialog v-model="dialog" max-width="820" scrollable>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-icon color="primary" class="mr-2">
            {{ form.id ? 'mdi-pencil' : 'mdi-home-import-outline' }}
          </v-icon>
          <span class="text-h6 font-weight-bold">
            {{ form.id ? 'Edit visit' : 'Schedule home visit' }}
          </span>
          <v-spacer />
          <v-chip v-if="form.id" size="small" variant="tonal"
                  :color="statusColor(form.status)" class="text-capitalize">
            {{ statusLabel(form.status) }}
          </v-chip>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4 pa-md-5">
          <v-row dense>
            <v-col cols="12">
              <v-autocomplete
                v-model="form.lab_order" :items="orderOptions"
                item-title="label" item-value="id"
                label="Lab order *" variant="outlined" density="comfortable"
                :loading="ord.loading.value"
                prepend-inner-icon="mdi-clipboard-text"
                @update:model-value="onOrderPicked"
              >
                <template #item="{ props, item }">
                  <v-list-item v-bind="props" :title="item.raw.patient_name"
                               :subtitle="item.raw.subtitle">
                    <template #append>
                      <v-chip size="x-small" variant="flat"
                              :color="priorityColor(item.raw.priority)" class="text-uppercase text-white">
                        {{ item.raw.priority }}
                      </v-chip>
                    </template>
                  </v-list-item>
                </template>
              </v-autocomplete>
            </v-col>

            <v-col cols="12" sm="6">
              <v-autocomplete v-model="form.assigned_lab_tech" :items="techOptions"
                              item-title="title" item-value="value"
                              label="Assigned lab tech *" variant="outlined" density="comfortable"
                              prepend-inner-icon="mdi-doctor" :loading="loadingTechs" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select v-model="form.status" :items="statusOptions"
                        label="Status" variant="outlined" density="comfortable"
                        prepend-inner-icon="mdi-progress-check" />
            </v-col>

            <v-col cols="12" sm="6">
              <v-text-field v-model="form.scheduled_date" type="date"
                            label="Date *" variant="outlined" density="comfortable"
                            prepend-inner-icon="mdi-calendar" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="form.scheduled_time" type="time"
                            label="Time *" variant="outlined" density="comfortable"
                            prepend-inner-icon="mdi-clock-outline" />
            </v-col>

            <v-col cols="12">
              <v-card flat rounded="lg" class="addr-card pa-3">
                <!-- Toolbar -->
                <div class="d-flex align-center flex-wrap ga-2 mb-2">
                  <v-icon size="18" color="primary">mdi-map-marker-radius</v-icon>
                  <span class="text-subtitle-2 font-weight-bold">Patient address</span>
                  <span class="text-caption text-medium-emphasis">*</span>
                  <v-spacer />
                  <v-btn-toggle
                    v-model="addrMode" mandatory density="compact" rounded="lg"
                    color="primary" variant="outlined" divided>
                    <v-btn value="search" size="x-small">
                      <v-icon size="14" start>mdi-magnify</v-icon>Search
                    </v-btn>
                    <v-btn value="manual" size="x-small">
                      <v-icon size="14" start>mdi-pencil</v-icon>Manual
                    </v-btn>
                  </v-btn-toggle>
                  <v-tooltip text="Pick on map" location="top">
                    <template #activator="{ props }">
                      <v-btn v-bind="props" icon="mdi-map-search" variant="tonal" size="x-small"
                             color="primary" @click.stop="openMapPicker" />
                    </template>
                  </v-tooltip>
                  <v-tooltip text="Use my current location" location="top">
                    <template #activator="{ props }">
                      <v-btn v-bind="props" icon="mdi-crosshairs-gps" variant="tonal" size="x-small"
                             color="indigo" :loading="locating" @click.stop="useMyLocation" />
                    </template>
                  </v-tooltip>
                </div>

                <!-- Search mode -->
                <v-autocomplete
                  v-if="addrMode === 'search'"
                  v-model="addrSelection"
                  v-model:search="addrQuery"
                  :items="addrPredictions"
                  :loading="loadingPlaces"
                  item-title="description"
                  item-value="place_id"
                  placeholder="Start typing â€” powered by Google Places"
                  variant="solo-filled" flat density="comfortable"
                  bg-color="grey-lighten-4" rounded="lg"
                  prepend-inner-icon="mdi-magnify"
                  return-object hide-no-data hide-details="auto"
                  no-filter clearable
                  @update:search="onAddrSearch"
                  @update:model-value="onAddrPicked"
                >
                  <template #item="{ props: ip, item }">
                    <v-list-item v-bind="ip" prepend-icon="mdi-map-marker-outline">
                      <v-list-item-subtitle v-if="item.raw.structured_formatting?.secondary_text">
                        {{ item.raw.structured_formatting.secondary_text }}
                      </v-list-item-subtitle>
                    </v-list-item>
                  </template>
                </v-autocomplete>

                <!-- Manual mode -->
                <v-textarea
                  v-else
                  v-model="form.patient_address" rows="2" auto-grow
                  placeholder="Type the patient's addressâ€¦"
                  variant="solo-filled" flat density="comfortable"
                  bg-color="grey-lighten-4" rounded="lg"
                  prepend-inner-icon="mdi-pencil" hide-details="auto"
                />

                <!-- Resolved address preview (when searching) -->
                <div v-if="addrMode === 'search' && form.patient_address"
                     class="addr-preview mt-2 d-flex align-start ga-2 pa-2 rounded-lg">
                  <v-icon size="16" color="primary" class="mt-1">mdi-map-marker-check</v-icon>
                  <div class="text-body-2 flex-grow-1">{{ form.patient_address }}</div>
                  <v-btn size="x-small" variant="text" prepend-icon="mdi-pencil"
                         @click="addrMode = 'manual'">Edit</v-btn>
                </div>

                <!-- Geo info card -->
                <div v-if="form.address_latitude != null && form.address_longitude != null"
                     class="addr-geo mt-3 pa-3 rounded-lg">
                  <div class="d-flex align-center mb-2">
                    <v-icon size="16" color="success" class="mr-2">mdi-check-decagram</v-icon>
                    <span class="text-caption font-weight-bold text-success">Location pinned</span>
                    <v-spacer />
                    <v-btn size="x-small" variant="text" color="error"
                           prepend-icon="mdi-close" @click="clearGeo">Clear</v-btn>
                  </div>
                  <v-row dense>
                    <v-col v-if="form.address_place_name" cols="12">
                      <div class="addr-geo-row">
                        <v-icon size="14" color="success">mdi-tag-outline</v-icon>
                        <span class="addr-geo-label">Place</span>
                        <span class="addr-geo-value">{{ form.address_place_name }}</span>
                      </div>
                    </v-col>
                    <v-col cols="6">
                      <div class="addr-geo-row">
                        <v-icon size="14" color="primary">mdi-latitude</v-icon>
                        <span class="addr-geo-label">Lat</span>
                        <span class="addr-geo-value font-monospace">
                          {{ Number(form.address_latitude).toFixed(6) }}
                        </span>
                      </div>
                    </v-col>
                    <v-col cols="6">
                      <div class="addr-geo-row">
                        <v-icon size="14" color="primary">mdi-longitude</v-icon>
                        <span class="addr-geo-label">Lng</span>
                        <span class="addr-geo-value font-monospace">
                          {{ Number(form.address_longitude).toFixed(6) }}
                        </span>
                      </div>
                    </v-col>
                  </v-row>
                  <div class="d-flex justify-end mt-1">
                    <v-btn size="x-small" variant="text" color="primary"
                           prepend-icon="mdi-open-in-new"
                           :href="`https://www.google.com/maps/search/?api=1&query=${form.address_latitude},${form.address_longitude}`"
                           target="_blank">Open in Maps</v-btn>
                  </div>
                </div>

                <!-- Empty hint -->
                <div v-else class="addr-empty mt-2 d-flex align-center pa-2 rounded-lg">
                  <v-icon size="16" color="warning" class="mr-2">mdi-map-marker-off-outline</v-icon>
                  <span class="text-caption text-medium-emphasis">
                    No coordinates pinned yet â€” search, pick on map, or use current location.
                  </span>
                </div>
              </v-card>
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.notes" label="Notes" rows="2"
                          variant="outlined" density="comfortable" auto-grow
                          prepend-inner-icon="mdi-note-text-outline" />
            </v-col>

            <v-col v-if="selectedOrder" cols="12">
              <v-card flat class="pa-3 selected-order">
                <div class="text-overline text-medium-emphasis">Order details</div>
                <div class="d-flex flex-wrap ga-1 mt-1">
                  <v-chip v-for="(t, i) in (selectedOrder.test_names || [])" :key="i"
                          size="x-small" variant="tonal" color="indigo">{{ t }}</v-chip>
                </div>
                <div v-if="selectedOrder.clinical_notes" class="text-caption text-medium-emphasis mt-2">
                  {{ selectedOrder.clinical_notes }}
                </div>
              </v-card>
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-btn v-if="form.id" variant="text" prepend-icon="mdi-printer-outline"
                 @click="printJobSheet(form)">Print job sheet</v-btn>
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">Cancel</v-btn>
          <v-btn color="primary" :loading="saving"
                 prepend-icon="mdi-content-save" @click="save">
            {{ form.id ? 'Save changes' : 'Schedule visit' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <MapPicker v-model="mapPickerOpen" :initial="mapPickerInitial" @picked="onMapPicked" />

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useResource } from '~/composables/useResource'
import { useGoogleMaps } from '~/composables/useGoogleMaps'
import MapPicker from '~/components/MapPicker.vue'
import { formatDateTime } from '~/utils/format'

const { $api } = useNuxtApp()
const { getPredictions, getPlaceDetails, reverseGeocode } = useGoogleMaps()
const r = useResource('/lab/home-visits/')
const ord = useResource('/lab/orders/')

const view = ref('table')
const statusFilter = ref(null)
const techFilter = ref(null)
const dateFilter = ref(null)
const activeKpi = ref(null)
const dialog = ref(false)
const saving = ref(false)
const techs = ref([])
const loadingTechs = ref(false)
const snack = reactive({ show: false, color: 'success', text: '' })

const STATUS_META = {
  scheduled: { label: 'Scheduled', color: 'amber-darken-2', icon: 'mdi-calendar-clock' },
  confirmed: { label: 'Confirmed', color: 'cyan-darken-2', icon: 'mdi-check-decagram-outline' },
  in_progress: { label: 'In progress', color: 'blue-darken-2', icon: 'mdi-truck-outline' },
  completed: { label: 'Completed', color: 'green-darken-2', icon: 'mdi-check' },
  cancelled: { label: 'Cancelled', color: 'grey-darken-1', icon: 'mdi-close-circle-outline' },
  no_show: { label: 'No-show', color: 'orange-darken-3', icon: 'mdi-account-cancel-outline' },
}
const PRIORITY_META = {
  routine: { color: 'grey-darken-1' },
  urgent: { color: 'orange-darken-2' },
  stat: { color: 'red-darken-2' },
}

const statusOptions = Object.entries(STATUS_META).map(([v, m]) => ({ title: m.label, value: v }))
const dateOptions = [
  { title: 'Today', value: 'today' },
  { title: 'Tomorrow', value: 'tomorrow' },
  { title: 'This week', value: 'week' },
  { title: 'Past', value: 'past' },
]

const headers = [
  { title: 'Patient', key: 'patient_name' },
  { title: 'Lab tech', key: 'assigned_lab_tech_name' },
  { title: 'Schedule', key: 'scheduled_date', width: 150 },
  { title: 'Address', key: 'patient_address' },
  { title: 'Status', key: 'status', width: 130 },
  { title: 'ETA', key: 'eta', sortable: false, width: 110 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 160 },
]

function statusColor(v) { return STATUS_META[v]?.color || 'grey' }
function statusIcon(v) { return STATUS_META[v]?.icon || 'mdi-help-circle-outline' }
function statusLabel(v) { return STATUS_META[v]?.label || v }
function priorityColor(v) { return PRIORITY_META[v]?.color || 'grey' }

const list = computed(() => r.items.value || [])

const techOptions = computed(() => techs.value.map(t => ({
  title: t.full_name || `${t.first_name || ''} ${t.last_name || ''}`.trim() || t.email,
  value: t.id,
})))

const orderOptions = computed(() => (ord.items.value || []).map(o => ({
  ...o,
  label: `${o.patient_name || 'Unknown'} â€” ${(o.test_names || []).slice(0, 3).join(', ')}`,
  subtitle: `REQ-${String(o.id).padStart(5, '0')} Â· ${(o.test_names || []).length} tests`,
})))

const selectedOrder = computed(() =>
  (ord.items.value || []).find(o => o.id === form.value.lab_order)
)

const filtered = computed(() => {
  let arr = r.filtered.value
  if (statusFilter.value) arr = arr.filter(v => v.status === statusFilter.value)
  if (techFilter.value) arr = arr.filter(v => v.assigned_lab_tech === techFilter.value)
  if (dateFilter.value) {
    const today = new Date(); today.setHours(0, 0, 0, 0)
    const tomorrow = new Date(today); tomorrow.setDate(tomorrow.getDate() + 1)
    const weekEnd = new Date(today); weekEnd.setDate(weekEnd.getDate() + 7)
    arr = arr.filter(v => {
      if (!v.scheduled_date) return false
      const d = new Date(v.scheduled_date + 'T00:00:00')
      if (dateFilter.value === 'today') return d.getTime() === today.getTime()
      if (dateFilter.value === 'tomorrow') return d.getTime() === tomorrow.getTime()
      if (dateFilter.value === 'week') return d >= today && d <= weekEnd
      if (dateFilter.value === 'past') return d < today
      return true
    })
  }
  if (activeKpi.value === 'today') {
    const t = new Date().toISOString().slice(0, 10)
    arr = arr.filter(v => v.scheduled_date === t)
  }
  if (activeKpi.value === 'overdue') arr = arr.filter(isOverdue)
  if (activeKpi.value === 'unassigned') arr = arr.filter(v => !v.assigned_lab_tech)
  return arr
})

const statusPills = computed(() => {
  const counts = list.value.reduce((acc, v) => {
    acc[v.status] = (acc[v.status] || 0) + 1
    return acc
  }, {})
  return [
    { label: 'All', value: null, count: list.value.length, color: 'primary', icon: 'mdi-format-list-bulleted' },
    ...Object.entries(STATUS_META).map(([v, m]) => ({
      label: m.label, value: v, count: counts[v] || 0, color: m.color, icon: m.icon,
    })),
  ]
})

const kpis = computed(() => {
  const arr = list.value
  const today = new Date().toISOString().slice(0, 10)
  return [
    { key: null, label: 'Active', value: arr.filter(v => !['completed', 'cancelled', 'no_show'].includes(v.status)).length,
      icon: 'mdi-home-import-outline', color: 'purple' },
    { key: 'today', label: 'Today', value: arr.filter(v => v.scheduled_date === today).length,
      icon: 'mdi-calendar-today', color: 'indigo' },
    { key: 'unassigned', label: 'Unassigned', value: arr.filter(v => !v.assigned_lab_tech).length,
      icon: 'mdi-account-question-outline', color: 'orange' },
    { key: 'overdue', label: 'Overdue', value: arr.filter(isOverdue).length,
      icon: 'mdi-alert-outline', color: 'red' },
    { key: null, label: 'Completed today', value: arr.filter(v => v.status === 'completed' && v.completed_at && new Date(v.completed_at).toDateString() === new Date().toDateString()).length,
      icon: 'mdi-check-circle', color: 'green' },
    { key: null, label: 'Total visits', value: arr.length,
      icon: 'mdi-database-outline', color: 'teal' },
  ]
})

const groupedByDate = computed(() => {
  const m = new Map()
  filtered.value.forEach(v => {
    if (!v.scheduled_date) return
    if (!m.has(v.scheduled_date)) m.set(v.scheduled_date, [])
    m.get(v.scheduled_date).push(v)
  })
  const today = new Date().toISOString().slice(0, 10)
  return Array.from(m.entries())
    .sort(([a], [b]) => (a < b ? -1 : 1))
    .map(([date, items]) => {
      const d = new Date(date + 'T00:00:00')
      return {
        date,
        items: items.sort((a, b) => (a.scheduled_time || '').localeCompare(b.scheduled_time || '')),
        label: d.toLocaleDateString(undefined, { weekday: 'long', day: 'numeric', month: 'long' }),
        day: String(d.getDate()),
        month: d.toLocaleString(undefined, { month: 'short' }).toUpperCase(),
        isToday: date === today,
      }
    })
})

const form = ref(emptyForm())
function emptyForm() {
  return {
    id: null, lab_order: null, patient: null,
    assigned_lab_tech: null,
    scheduled_date: '', scheduled_time: '',
    patient_address: '',
    address_place_name: '',
    address_latitude: null,
    address_longitude: null,
    status: 'scheduled', notes: '',
  }
}

// ----- Google Places / Maps -----
const addrQuery = ref('')
const addrSelection = ref(null)
const addrPredictions = ref([])
const addrMode = ref('search')
const loadingPlaces = ref(false)
const locating = ref(false)
const mapPickerOpen = ref(false)
const mapPickerInitial = ref({})
let _addrTimer = null

function round6(n) {
  if (n == null || n === '' || isNaN(Number(n))) return null
  return Math.round(Number(n) * 1e6) / 1e6
}

function onAddrSearch(q) {
  if (_addrTimer) clearTimeout(_addrTimer)
  if (!q || q.length < 3) { addrPredictions.value = []; return }
  loadingPlaces.value = true
  _addrTimer = setTimeout(async () => {
    try { addrPredictions.value = await getPredictions(q, { country: 'ke' }) }
    catch { addrPredictions.value = [] }
    finally { loadingPlaces.value = false }
  }, 280)
}
async function onAddrPicked(pred) {
  if (!pred?.place_id) return
  try {
    const d = await getPlaceDetails(pred.place_id)
    form.value.patient_address = d.address || pred.description
    form.value.address_latitude = round6(d.lat)
    form.value.address_longitude = round6(d.lng)
    form.value.address_place_name = d.name || (pred.structured_formatting?.main_text || '')
    addrQuery.value = form.value.patient_address
  } catch {
    form.value.patient_address = pred.description
  }
}
function openMapPicker() {
  mapPickerInitial.value = {
    lat: form.value.address_latitude,
    lng: form.value.address_longitude,
    address: form.value.patient_address,
    place_name: form.value.address_place_name,
  }
  mapPickerOpen.value = true
}
function onMapPicked(p) {
  form.value.address_latitude = round6(p.lat)
  form.value.address_longitude = round6(p.lng)
  form.value.patient_address = p.address || form.value.patient_address
  form.value.address_place_name = p.place_name || form.value.address_place_name
  addrQuery.value = form.value.patient_address
}
function useMyLocation() {
  if (!navigator.geolocation) {
    snack.text = 'Geolocation not supported'
    snack.color = 'error'
    snack.show = true
    return
  }
  locating.value = true
  navigator.geolocation.getCurrentPosition(
    async ({ coords }) => {
      try {
        const addr = await reverseGeocode(coords.latitude, coords.longitude)
        form.value.patient_address = addr
        form.value.address_latitude = round6(coords.latitude)
        form.value.address_longitude = round6(coords.longitude)
        addrQuery.value = addr
      } finally { locating.value = false }
    },
    () => { locating.value = false },
    { enableHighAccuracy: true, timeout: 10000 },
  )
}
function clearGeo() {
  form.value.address_latitude = null
  form.value.address_longitude = null
  form.value.address_place_name = ''
}

function setKpi(k) { activeKpi.value = activeKpi.value === k ? null : k }
function resetFilters() {
  statusFilter.value = null
  techFilter.value = null
  dateFilter.value = null
  activeKpi.value = null
  r.search.value = ''
}

function openNew() {
  form.value = emptyForm()
  // Default date = today
  form.value.scheduled_date = new Date().toISOString().slice(0, 10)
  form.value.scheduled_time = '09:00'
  addrQuery.value = ''
  addrSelection.value = null
  addrPredictions.value = []
  dialog.value = true
}
function openEdit(it) {
  form.value = { ...emptyForm(), ...it }
  addrQuery.value = it.patient_address || ''
  addrSelection.value = null
  addrPredictions.value = []
  dialog.value = true
}
function onOrderPicked(orderId) {
  const o = (ord.items.value || []).find(x => x.id === orderId)
  if (o) form.value.patient = o.patient
}

async function save() {
  if (!form.value.lab_order || !form.value.assigned_lab_tech
      || !form.value.scheduled_date || !form.value.scheduled_time
      || !form.value.patient_address) {
    snack.text = 'Please fill all required fields'
    snack.color = 'error'
    snack.show = true
    return
  }
  saving.value = true
  try {
    const payload = { ...form.value }
    if (!payload.patient && selectedOrder.value) payload.patient = selectedOrder.value.patient
    // Always send rounded coords (â‰¤6 decimals)
    payload.address_latitude = round6(payload.address_latitude)
    payload.address_longitude = round6(payload.address_longitude)
    if (form.value.id) await r.update(form.value.id, payload)
    else await r.create(payload)
    dialog.value = false
    snack.text = form.value.id ? 'Visit updated' : 'Visit scheduled'
    snack.color = 'success'
    snack.show = true
    r.list()
  } catch (e) {
    snack.text = e?.response?.data?.detail
      || (typeof e?.response?.data === 'object'
          ? Object.values(e.response.data).flat().join(' ')
          : 'Failed to save')
    snack.color = 'error'
    snack.show = true
  } finally {
    saving.value = false
  }
}

async function setStatus(item, status) {
  try {
    const payload = { ...item, status }
    if (status === 'completed') payload.completed_at = new Date().toISOString()
    await r.update(item.id, payload)
    snack.text = `Marked ${statusLabel(status).toLowerCase()}`
    snack.color = 'success'
    snack.show = true
    r.list()
  } catch (e) {
    snack.text = 'Failed to update status'
    snack.color = 'error'
    snack.show = true
  }
}

function openMap(v) {
  let url
  if (v.address_latitude != null && v.address_longitude != null) {
    url = `https://www.google.com/maps/search/?api=1&query=${v.address_latitude},${v.address_longitude}`
  } else if (v.patient_address) {
    url = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(v.patient_address)}`
  } else { return }
  window.open(url, '_blank')
}

function isOverdue(v) {
  if (['completed', 'cancelled', 'no_show'].includes(v.status)) return false
  if (!v.scheduled_date) return false
  const dt = new Date(`${v.scheduled_date}T${v.scheduled_time || '00:00'}:00`)
  return dt.getTime() < Date.now()
}
function etaLabel(v) {
  if (['completed', 'cancelled', 'no_show'].includes(v.status)) return statusLabel(v.status)
  if (!v.scheduled_date) return 'â€”'
  const dt = new Date(`${v.scheduled_date}T${v.scheduled_time || '00:00'}:00`)
  const diff = dt.getTime() - Date.now()
  const abs = Math.abs(diff)
  const m = Math.floor(abs / 60000)
  if (m < 60) return diff < 0 ? `${m}m late` : `in ${m}m`
  const h = Math.floor(m / 60)
  if (h < 24) return diff < 0 ? `${h}h late` : `in ${h}h`
  const d = Math.floor(h / 24)
  return diff < 0 ? `${d}d late` : `in ${d}d`
}
function etaColor(v) {
  if (v.status === 'completed') return 'success'
  if (['cancelled', 'no_show'].includes(v.status)) return 'grey'
  if (isOverdue(v)) return 'error'
  return 'grey-darken-1'
}

function initials(name) {
  if (!name) return '?'
  const parts = name.split(/\s+/).filter(Boolean)
  return ((parts[0]?.[0] || '') + (parts[1]?.[0] || '')).toUpperCase() || '?'
}
function hashColor(seed) {
  const colors = ['indigo', 'teal', 'pink', 'amber-darken-2', 'cyan-darken-2', 'deep-purple', 'green-darken-1', 'orange-darken-2']
  return colors[(Number(seed) || 0) % colors.length]
}
function formatDateOnly(iso) {
  if (!iso) return 'â€”'
  return new Date(iso + 'T00:00:00').toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' })
}
function formatTimeOnly(t) {
  if (!t) return 'â€”'
  return t.slice(0, 5)
}

function printJobSheet(v) {
  const w = window.open('', '_blank', 'width=820,height=900')
  if (!w) return
  const tests = (selectedOrderTests(v) || []).map(t => `<li>${t}</li>`).join('')
  w.document.write(`
    <html><head><title>Job Sheet</title>
    <style>
      body{font-family:Arial,sans-serif;margin:24px;color:#222}
      h1{margin:0;font-size:22px}
      .sub{color:#666;font-size:12px;margin-bottom:16px}
      .box{border:1px solid #ccc;padding:10px;border-radius:6px;margin-bottom:8px}
      .row{display:flex;gap:8px;margin-bottom:8px}
      .row .box{flex:1}
      ul{margin:6px 0 0 18px;padding:0}
      .sig{margin-top:32px;display:flex;justify-content:space-between;font-size:12px;color:#444}
    </style></head><body>
      <h1>Home Visit Job Sheet</h1>
      <div class="sub">Visit #${v.id} Â· ${(v.status || '').toUpperCase()}</div>
      <div class="row">
        <div class="box"><b>Patient:</b> ${v.patient_name || 'â€”'}</div>
        <div class="box"><b>Lab tech:</b> ${v.assigned_lab_tech_name || 'â€”'}</div>
      </div>
      <div class="row">
        <div class="box"><b>Date:</b> ${formatDateOnly(v.scheduled_date)}</div>
        <div class="box"><b>Time:</b> ${formatTimeOnly(v.scheduled_time)}</div>
      </div>
      <div class="box"><b>Address:</b><br>${v.patient_address || 'â€”'}${
        v.address_place_name ? `<br><i>Landmark:</i> ${v.address_place_name}` : ''
      }${
        v.address_latitude != null && v.address_longitude != null
          ? `<br><i>Coords:</i> ${Number(v.address_latitude).toFixed(6)}, ${Number(v.address_longitude).toFixed(6)}`
          : ''
      }</div>
      <div class="box"><b>Tests requested:</b><ul>${tests || '<li>â€”</li>'}</ul></div>
      ${v.notes ? `<div class="box"><b>Notes:</b> ${v.notes}</div>` : ''}
      <div class="sig">
        <div>Patient signature: ____________________</div>
        <div>Tech signature: ____________________</div>
        <div>Time: __________</div>
      </div>
    </body></html>`)
  w.document.close()
  setTimeout(() => w.print(), 200)
}
function selectedOrderTests(v) {
  const o = (ord.items.value || []).find(x => x.id === v.lab_order)
  return o?.test_names || []
}

function exportCsv() {
  const rows = filtered.value
  if (!rows.length) return
  const cols = ['id', 'patient', 'lab_tech', 'date', 'time', 'address', 'place_name', 'latitude', 'longitude', 'status', 'completed_at']
  const header = cols.join(',')
  const body = rows.map(v => [
    v.id,
    `"${(v.patient_name || '').replace(/"/g, '""')}"`,
    `"${(v.assigned_lab_tech_name || '').replace(/"/g, '""')}"`,
    v.scheduled_date || '',
    v.scheduled_time || '',
    `"${(v.patient_address || '').replace(/"/g, '""').replace(/\n/g, ' ')}"`,
    `"${(v.address_place_name || '').replace(/"/g, '""')}"`,
    v.address_latitude != null ? Number(v.address_latitude).toFixed(6) : '',
    v.address_longitude != null ? Number(v.address_longitude).toFixed(6) : '',
    v.status || '',
    v.completed_at || '',
  ].join(',')).join('\n')
  const blob = new Blob([header + '\n' + body], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `home_visits_${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

async function loadTechs() {
  loadingTechs.value = true
  try {
    const res = await $api.get('/accounts/users/', { params: { page_size: 200 } })
    techs.value = res.data?.results || res.data || []
  } catch {
    techs.value = []
  } finally {
    loadingTechs.value = false
  }
}

onMounted(async () => {
  await Promise.all([r.list(), ord.list(), loadTechs()])
})
</script>

<style scoped>
/* ---- Address card ---- */
.addr-card {
  background: linear-gradient(180deg, rgba(var(--v-theme-primary), 0.03), rgba(var(--v-theme-surface), 1));
  border: 1px solid rgba(var(--v-theme-primary), 0.18);
  transition: border-color .2s ease, box-shadow .2s ease;
}
.addr-card:focus-within {
  border-color: rgba(var(--v-theme-primary), 0.5);
  box-shadow: 0 0 0 3px rgba(var(--v-theme-primary), 0.08);
}
.addr-preview {
  background: rgba(var(--v-theme-primary), 0.05);
  border: 1px dashed rgba(var(--v-theme-primary), 0.25);
}
.addr-empty {
  background: rgba(var(--v-theme-warning), 0.06);
  border: 1px dashed rgba(var(--v-theme-warning), 0.35);
}
.addr-geo {
  background: linear-gradient(135deg,
    rgba(var(--v-theme-success), 0.08),
    rgba(var(--v-theme-primary), 0.06));
  border: 1px solid rgba(var(--v-theme-success), 0.28);
  position: relative;
  overflow: hidden;
}
.addr-geo::before {
  content: '';
  position: absolute;
  top: -20px; right: -20px;
  width: 80px; height: 80px;
  background: radial-gradient(circle, rgba(var(--v-theme-success), 0.18), transparent 70%);
  pointer-events: none;
}
.addr-geo-row {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 4px 8px;
  background: rgba(255,255,255,0.6);
  border-radius: 6px;
  min-height: 28px;
}
.addr-geo-label {
  font-size: 10px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .04em;
  color: rgba(var(--v-theme-on-surface), 0.55);
  margin-right: 2px;
}
.addr-geo-value {
  font-size: 12px;
  font-weight: 600;
  color: rgba(var(--v-theme-on-surface), 0.9);
  word-break: break-word;
}

/* Helpers still used by templates */
.text-truncate-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.min-width-0 { min-width: 0; }
.font-monospace { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
</style>
