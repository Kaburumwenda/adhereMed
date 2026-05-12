<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="indigo-lighten-5" size="48">
        <v-icon color="indigo-darken-2" size="28">mdi-test-tube</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Lab Reagents</div>
        <div class="text-body-2 text-medium-emphasis">
          Reagent master · lot tracking · expiry & low-stock alerts
        </div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh"
             :loading="r.loading.value" @click="reload">Refresh</v-btn>
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-tray-arrow-up"
             @click="csvFile?.click()">Import</v-btn>
      <input ref="csvFile" type="file" accept=".csv" hidden @change="runImport" />
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-tray-arrow-down"
             @click="exportCsv">Export</v-btn>
      <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openNew">New Reagent</v-btn>
    </div>

    <!-- KPIs -->
    <v-row dense>
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="3">
        <v-card flat rounded="lg" class="kpi pa-4">
          <div class="d-flex align-center">
            <v-avatar :color="k.color + '-lighten-5'" size="40" class="mr-3">
              <v-icon :color="k.color + '-darken-2'">{{ k.icon }}</v-icon>
            </v-avatar>
            <div class="min-width-0">
              <div class="text-overline text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h5 font-weight-bold">{{ k.value }}</div>
              <div v-if="k.hint" class="text-caption text-medium-emphasis">{{ k.hint }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Status pills -->
    <v-card flat rounded="lg" class="mt-4 pa-3">
      <div class="d-flex flex-wrap align-center ga-2">
        <v-chip
          v-for="s in stockPills" :key="s.key"
          :color="stockFilter === s.value ? (s.color || 'primary') : undefined"
          :variant="stockFilter === s.value ? 'flat' : 'tonal'"
          size="small" @click="stockFilter = s.value"
        >
          <v-icon v-if="s.icon" size="14" start>{{ s.icon }}</v-icon>
          {{ s.label }}<span class="ml-2 font-weight-bold">{{ s.count }}</span>
        </v-chip>

        <v-divider vertical class="mx-2" />

        <v-chip
          v-for="c in categoryChips" :key="c.value || 'all-cat'"
          :color="categoryFilter === c.value ? 'indigo' : undefined"
          :variant="categoryFilter === c.value ? 'flat' : 'tonal'"
          size="small" @click="categoryFilter = c.value"
        >
          <v-icon size="14" start>{{ CAT_META[c.value]?.icon || 'mdi-shape-outline' }}</v-icon>
          {{ c.label }}
          <span v-if="c.count != null" class="ml-2 font-weight-bold">{{ c.count }}</span>
        </v-chip>

        <v-spacer />

        <v-btn-toggle v-model="view" mandatory density="compact" rounded="lg" color="primary">
          <v-btn value="table" icon="mdi-format-list-bulleted" size="small" />
          <v-btn value="grid" icon="mdi-view-grid-outline" size="small" />
        </v-btn-toggle>
      </div>
    </v-card>

    <!-- Filter bar -->
    <v-card flat rounded="lg" class="mt-3 pa-3">
      <v-row dense align="center">
        <v-col cols="12" md="4">
          <v-text-field v-model="r.search.value" prepend-inner-icon="mdi-magnify"
                        placeholder="Search by name, code, manufacturer…"
                        variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="3">
          <v-select v-model="storageFilter" :items="STORAGE" item-title="title" item-value="value"
                    label="Storage" prepend-inner-icon="mdi-thermometer"
                    variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="3">
          <v-autocomplete v-model="instrumentFilter" :items="instruments"
                          item-title="name" item-value="id"
                          label="Instrument" prepend-inner-icon="mdi-cog-transfer"
                          variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="12" md="2">
          <v-select v-model="sortBy" :items="sortOptions"
                    label="Sort" prepend-inner-icon="mdi-sort"
                    variant="outlined" density="compact" hide-details />
        </v-col>
      </v-row>
    </v-card>

    <!-- Alert ribbon -->
    <v-slide-y-transition>
      <v-alert v-if="alertItems.length" type="warning" variant="tonal"
               class="mt-3" prominent rounded="lg" icon="mdi-alert-decagram">
        <div class="font-weight-bold">{{ alertItems.length }} reagent alert(s)</div>
        <div class="text-body-2 mt-1 d-flex flex-wrap ga-1">
          <v-chip v-for="a in alertItems.slice(0, 6)" :key="a.id" size="x-small"
                  :color="a.kind === 'expired' ? 'error'
                    : a.kind === 'out' ? 'red-darken-2'
                    : a.kind === 'expiring' ? 'amber-darken-2' : 'orange'"
                  variant="flat" class="cursor-pointer" @click="openDetail(a.reagent)">
            <v-icon size="12" start>{{ a.icon }}</v-icon>{{ a.label }}
          </v-chip>
        </div>
      </v-alert>
    </v-slide-y-transition>

    <!-- Bulk action bar -->
    <v-slide-y-transition>
      <v-card v-if="selected.length" flat rounded="lg" class="mt-3 pa-3 bulk-bar">
        <div class="d-flex align-center ga-2 flex-wrap">
          <v-icon color="primary">mdi-check-all</v-icon>
          <span class="font-weight-medium">{{ selected.length }} selected</span>
          <v-spacer />
          <v-btn size="small" variant="tonal" color="success" prepend-icon="mdi-check-circle"
                 :loading="bulkBusy" @click="bulkActivate(true)">Activate</v-btn>
          <v-btn size="small" variant="tonal" color="warning" prepend-icon="mdi-pause-circle"
                 :loading="bulkBusy" @click="bulkActivate(false)">Deactivate</v-btn>
          <v-btn size="small" variant="tonal" color="error" prepend-icon="mdi-delete"
                 :loading="bulkBusy" @click="bulkDelete">Delete</v-btn>
          <v-btn size="small" variant="text" @click="selected = []">Clear</v-btn>
        </div>
      </v-card>
    </v-slide-y-transition>

    <!-- Table view -->
    <v-card v-if="view === 'table'" flat rounded="lg" class="mt-3">
      <v-data-table
        v-model="selected"
        show-select
        :headers="headers"
        :items="filtered"
        :loading="r.loading.value"
        :items-per-page="20"
        item-value="id"
        hover
        class="reagent-table"
        @click:row="(_, { item }) => openDetail(item)"
      >
        <template #loading><v-skeleton-loader type="table-row@5" /></template>
        <template #item.name="{ item }">
          <div class="d-flex align-center">
            <v-avatar :color="catColor(item.category)" size="34" class="mr-3">
              <v-icon size="16" color="white">{{ CAT_META[item.category]?.icon || 'mdi-flask' }}</v-icon>
            </v-avatar>
            <div class="min-width-0">
              <div class="font-weight-medium text-truncate">{{ item.name }}</div>
              <div class="text-caption text-medium-emphasis text-truncate">
                {{ [item.manufacturer, item.catalog_no].filter(Boolean).join(' · ') || '—' }}
              </div>
            </div>
          </div>
        </template>
        <template #item.category="{ value }">
          <v-chip size="x-small" variant="tonal" :color="catColor(value)" class="text-capitalize">
            {{ catLabel(value) }}
          </v-chip>
        </template>
        <template #item.storage="{ value }">
          <v-chip size="x-small" variant="tonal" :color="storageColor(value)">
            <v-icon size="12" start>{{ storageIcon(value) }}</v-icon>{{ storageLabel(value) }}
          </v-chip>
        </template>
        <template #item.instrument_name="{ value }">
          <span v-if="value" class="text-caption">{{ value }}</span>
          <span v-else class="text-medium-emphasis text-caption">—</span>
        </template>
        <template #item.quantity_on_hand="{ item }">
          <div class="d-flex flex-column align-end">
            <span class="font-monospace font-weight-bold" :class="stockTextClass(item)">
              {{ formatQty(item.quantity_on_hand) }} {{ item.unit }}
            </span>
            <span v-if="item.reorder_level > 0" class="text-caption text-medium-emphasis">
              reorder ≤ {{ formatQty(item.reorder_level) }}
            </span>
          </div>
        </template>
        <template #item.active_lot_count="{ item }">
          <v-chip size="x-small" variant="tonal" :color="item.active_lot_count ? 'indigo' : undefined">
            {{ item.active_lot_count || 0 }}
          </v-chip>
        </template>
        <template #item.nearest_expiry="{ item }">
          <div v-if="item.nearest_expiry" class="d-flex flex-column">
            <span class="text-caption" :class="expiryClass(item.nearest_expiry)">
              {{ formatDate(item.nearest_expiry) }}
            </span>
            <span class="text-caption text-medium-emphasis">{{ expiryLabel(item.nearest_expiry) }}</span>
          </div>
          <span v-else class="text-medium-emphasis text-caption">—</span>
        </template>
        <template #item.stock_status="{ value }">
          <v-chip :color="stockColor(value)" size="small" variant="flat" class="text-capitalize">
            <v-icon size="14" start>{{ stockIcon(value) }}</v-icon>{{ stockLabel(value) }}
          </v-chip>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end" @click.stop>
            <v-tooltip text="Receive lot" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-tray-arrow-down" variant="text" size="small"
                       color="success" @click="openReceive(item)" />
              </template>
            </v-tooltip>
            <v-tooltip text="Edit" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-pencil-outline" variant="text" size="small"
                       color="primary" @click="openEdit(item)" />
              </template>
            </v-tooltip>
            <v-menu>
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" />
              </template>
              <v-list density="compact">
                <v-list-item prepend-icon="mdi-eye" title="View / Lots" @click="openDetail(item)" />
                <v-list-item v-if="item.msds_url" prepend-icon="mdi-file-document-alert"
                             title="Open MSDS" :href="item.msds_url" target="_blank" />
                <v-list-item prepend-icon="mdi-printer-outline" title="Print spec"
                             @click="printSheet(item)" />
                <v-divider />
                <v-list-item prepend-icon="mdi-delete" title="Delete" base-color="error"
                             @click="confirmDelete(item)" />
              </v-list>
            </v-menu>
          </div>
        </template>
        <template #no-data>
          <div class="pa-8 text-center">
            <v-icon size="56" color="grey-lighten-1">mdi-test-tube-empty</v-icon>
            <div class="text-subtitle-1 font-weight-medium mt-2">No reagents found</div>
            <div class="text-body-2 text-medium-emphasis mb-4">Adjust filters or add a new reagent.</div>
            <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openNew">New Reagent</v-btn>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- Grid view -->
    <div v-else class="mt-3">
      <div v-if="r.loading.value" class="d-flex justify-center pa-12">
        <v-progress-circular indeterminate color="primary" />
      </div>
      <div v-else-if="!filtered.length" class="pa-8 text-center">
        <v-icon size="56" color="grey-lighten-1">mdi-test-tube-empty</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-2">No reagents found</div>
        <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" class="mt-3" @click="openNew">New Reagent</v-btn>
      </div>
      <v-row v-else dense>
        <v-col v-for="i in filtered" :key="i.id" cols="12" sm="6" md="4" lg="3">
          <v-card flat rounded="lg" class="reagent-card pa-3 h-100" hover @click="openDetail(i)">
            <div class="reagent-band" :style="{ background: stockHex(i.stock_status) }" />
            <div class="d-flex align-center mb-2">
              <v-chip :color="stockColor(i.stock_status)" size="x-small" variant="flat"
                      class="text-capitalize">
                <v-icon size="12" start>{{ stockIcon(i.stock_status) }}</v-icon>{{ stockLabel(i.stock_status) }}
              </v-chip>
              <v-spacer />
              <v-chip v-if="i.is_controlled" size="x-small" variant="tonal" color="error">
                <v-icon size="11" start>mdi-shield-lock</v-icon>Controlled
              </v-chip>
            </div>
            <div class="d-flex align-center">
              <v-avatar :color="catColor(i.category)" size="40" class="mr-3">
                <v-icon size="20" color="white">{{ CAT_META[i.category]?.icon || 'mdi-flask' }}</v-icon>
              </v-avatar>
              <div class="min-width-0 flex-grow-1">
                <div class="font-weight-medium text-truncate">{{ i.name }}</div>
                <div class="text-caption text-medium-emphasis text-truncate">
                  {{ [i.manufacturer, i.catalog_no].filter(Boolean).join(' · ') || '—' }}
                </div>
              </div>
            </div>
            <v-divider class="my-3" />
            <div class="d-flex justify-space-between text-caption mb-1">
              <span class="text-medium-emphasis">On hand</span>
              <span class="font-monospace font-weight-bold" :class="stockTextClass(i)">
                {{ formatQty(i.quantity_on_hand) }} {{ i.unit }}
              </span>
            </div>
            <div class="d-flex justify-space-between text-caption mb-1">
              <span class="text-medium-emphasis">Active lots</span>
              <span>{{ i.active_lot_count || 0 }}</span>
            </div>
            <div class="d-flex justify-space-between text-caption mb-1">
              <span class="text-medium-emphasis">Nearest expiry</span>
              <span :class="expiryClass(i.nearest_expiry)">
                {{ i.nearest_expiry ? formatDate(i.nearest_expiry) : '—' }}
              </span>
            </div>
            <div class="d-flex justify-space-between text-caption">
              <span class="text-medium-emphasis">Storage</span>
              <span><v-icon size="12" :color="storageColor(i.storage)">{{ storageIcon(i.storage) }}</v-icon>
                {{ storageLabel(i.storage) }}</span>
            </div>
          </v-card>
        </v-col>
      </v-row>
    </div>

    <!-- Form dialog -->
    <v-dialog v-model="formDialog" max-width="900" scrollable persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="indigo-lighten-5" size="40" class="mr-3">
            <v-icon color="indigo-darken-2">{{ form.id ? 'mdi-pencil' : 'mdi-plus' }}</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">REAGENT</div>
            <div class="text-h6 font-weight-bold">{{ form.id ? 'Edit reagent' : 'New reagent' }}</div>
          </div>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" @click="formDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          <v-form ref="formRef" @submit.prevent="save">
            <v-row dense>
              <v-col cols="12" sm="8">
                <v-text-field v-model="form.name" label="Name *" prepend-inner-icon="mdi-flask"
                              variant="outlined" density="comfortable" :rules="[required]" />
              </v-col>
              <v-col cols="12" sm="4">
                <v-text-field v-model="form.code" label="Code" prepend-inner-icon="mdi-pound"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" sm="4">
                <v-select v-model="form.category" :items="CATEGORIES"
                          label="Category" prepend-inner-icon="mdi-shape"
                          variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" sm="4">
                <v-select v-model="form.storage" :items="STORAGE"
                          label="Storage" prepend-inner-icon="mdi-thermometer"
                          variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" sm="4">
                <v-autocomplete v-model="form.instrument" :items="instruments"
                                item-title="name" item-value="id"
                                label="Instrument" prepend-inner-icon="mdi-cog-transfer"
                                variant="outlined" density="comfortable" clearable />
              </v-col>
              <v-col cols="12" sm="4">
                <v-combobox v-model="form.manufacturer" :items="manufacturerOptions"
                            label="Manufacturer" prepend-inner-icon="mdi-factory"
                            variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" sm="4">
                <v-text-field v-model="form.catalog_no" label="Catalog #"
                              prepend-inner-icon="mdi-barcode"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" sm="4">
                <v-combobox v-model="form.supplier" :items="supplierOptions"
                            label="Supplier" prepend-inner-icon="mdi-truck-delivery"
                            variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="6" sm="3">
                <v-combobox v-model="form.unit" :items="['mL', 'L', 'g', 'mg', 'tests', 'vial', 'bottle', 'pack']"
                            label="Unit" prepend-inner-icon="mdi-cup-outline"
                            variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="6" sm="3">
                <v-text-field v-model="form.pack_size" label="Pack size"
                              prepend-inner-icon="mdi-package-variant"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="6" sm="3">
                <v-text-field v-model.number="form.unit_cost" type="number" step="0.01"
                              label="Unit cost (KES)" prepend-inner-icon="mdi-cash"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="6" sm="3">
                <v-combobox v-model="form.department" :items="departmentOptions"
                            label="Department" prepend-inner-icon="mdi-domain"
                            variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="6" sm="3">
                <v-text-field v-model.number="form.reorder_level" type="number" step="0.01"
                              label="Reorder level" prepend-inner-icon="mdi-bell-alert"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="6" sm="3">
                <v-text-field v-model.number="form.reorder_qty" type="number" step="0.01"
                              label="Reorder qty" prepend-inner-icon="mdi-tray-plus"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.hazard_class" label="Hazard class"
                              prepend-inner-icon="mdi-alert-octagon"
                              variant="outlined" density="comfortable"
                              hint="e.g., Corrosive, Flammable, Biohazard" persistent-hint />
              </v-col>
              <v-col cols="12" sm="9">
                <v-text-field v-model="form.msds_url" label="MSDS URL"
                              prepend-inner-icon="mdi-link"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="6" sm="3" class="d-flex align-center">
                <v-switch v-model="form.is_controlled" color="error"
                          hide-details label="Controlled" inset />
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow
                            prepend-inner-icon="mdi-text"
                            variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" class="d-flex align-center">
                <v-switch v-model="form.is_active" color="success" hide-details inset
                          :label="form.is_active ? 'Active' : 'Inactive'" />
              </v-col>
            </v-row>
          </v-form>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="formDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" :loading="r.saving.value" @click="save">
            <v-icon start>mdi-content-save</v-icon>{{ form.id ? 'Update' : 'Save' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Detail dialog (Reagent + Lots) -->
    <v-dialog v-model="detailDialog" max-width="980" scrollable>
      <v-card v-if="detailItem" rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar :color="catColor(detailItem.category)" size="44" class="mr-3">
            <v-icon size="22" color="white">{{ CAT_META[detailItem.category]?.icon || 'mdi-flask' }}</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">
              {{ catLabel(detailItem.category) }} · {{ storageLabel(detailItem.storage) }}
            </div>
            <div class="text-h6 font-weight-bold">{{ detailItem.name }}</div>
          </div>
          <v-spacer />
          <v-chip :color="stockColor(detailItem.stock_status)" size="small" variant="flat"
                  class="mr-2 text-capitalize">
            <v-icon size="14" start>{{ stockIcon(detailItem.stock_status) }}</v-icon>
            {{ stockLabel(detailItem.stock_status) }}
          </v-chip>
          <v-btn icon="mdi-close" variant="text" @click="detailDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          <v-row dense>
            <v-col cols="6" sm="3">
              <div class="text-caption text-medium-emphasis">Code</div>
              <div class="font-monospace">{{ detailItem.code || '—' }}</div>
            </v-col>
            <v-col cols="6" sm="3">
              <div class="text-caption text-medium-emphasis">Catalog #</div>
              <div class="font-monospace">{{ detailItem.catalog_no || '—' }}</div>
            </v-col>
            <v-col cols="6" sm="3">
              <div class="text-caption text-medium-emphasis">Manufacturer</div>
              <div>{{ detailItem.manufacturer || '—' }}</div>
            </v-col>
            <v-col cols="6" sm="3">
              <div class="text-caption text-medium-emphasis">Supplier</div>
              <div>{{ detailItem.supplier || '—' }}</div>
            </v-col>
            <v-col cols="6" sm="3">
              <div class="text-caption text-medium-emphasis">Pack size</div>
              <div>{{ detailItem.pack_size || '—' }}</div>
            </v-col>
            <v-col cols="6" sm="3">
              <div class="text-caption text-medium-emphasis">Unit cost</div>
              <div>{{ formatMoney(detailItem.unit_cost) }}</div>
            </v-col>
            <v-col cols="6" sm="3">
              <div class="text-caption text-medium-emphasis">Department</div>
              <div>{{ detailItem.department || '—' }}</div>
            </v-col>
            <v-col cols="6" sm="3">
              <div class="text-caption text-medium-emphasis">Instrument</div>
              <div>{{ detailItem.instrument_name || '—' }}</div>
            </v-col>
            <v-col v-if="detailItem.hazard_class" cols="6" sm="3">
              <div class="text-caption text-medium-emphasis">Hazard</div>
              <v-chip color="error" size="x-small" variant="tonal">
                <v-icon size="12" start>mdi-alert-octagon</v-icon>{{ detailItem.hazard_class }}
              </v-chip>
            </v-col>
            <v-col v-if="detailItem.msds_url" cols="6" sm="3">
              <div class="text-caption text-medium-emphasis">MSDS</div>
              <v-btn :href="detailItem.msds_url" target="_blank" size="x-small" variant="tonal"
                     prepend-icon="mdi-file-document-alert">Open</v-btn>
            </v-col>
            <v-col v-if="detailItem.notes" cols="12">
              <v-divider class="my-2" />
              <div class="text-caption text-medium-emphasis mb-1">Notes</div>
              <div>{{ detailItem.notes }}</div>
            </v-col>
          </v-row>

          <v-divider class="my-4" />

          <div class="d-flex align-center mb-2">
            <v-icon color="indigo" class="mr-2">mdi-package-variant-closed</v-icon>
            <span class="text-subtitle-2 font-weight-bold">Lots ({{ (detailItem.lots || []).length }})</span>
            <v-spacer />
            <v-btn size="small" color="primary" variant="tonal" prepend-icon="mdi-plus"
                   @click="openReceive(detailItem)">Receive lot</v-btn>
          </div>

          <v-table density="compact" v-if="(detailItem.lots || []).length">
            <thead>
              <tr>
                <th>Lot #</th>
                <th>Status</th>
                <th>Received</th>
                <th>Opened</th>
                <th>Expiry</th>
                <th class="text-end">On hand</th>
                <th>Location</th>
                <th class="text-end">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="lot in detailItem.lots" :key="lot.id">
                <td class="font-monospace">{{ lot.lot_number }}</td>
                <td>
                  <v-chip :color="lotStatusColor(lot.status)" size="x-small" variant="tonal"
                          class="text-capitalize">{{ lotStatusLabel(lot.status) }}</v-chip>
                </td>
                <td>{{ formatDate(lot.received_date) }}</td>
                <td>{{ formatDate(lot.opened_date) }}</td>
                <td>
                  <span :class="expiryClass(lot.expiry_date)">{{ formatDate(lot.expiry_date) }}</span>
                  <span class="text-caption d-block text-medium-emphasis">
                    {{ expiryLabel(lot.expiry_date) }}
                  </span>
                </td>
                <td class="text-end font-monospace">
                  {{ formatQty(lot.quantity_on_hand) }} / {{ formatQty(lot.initial_quantity) }}
                </td>
                <td>{{ lot.location || '—' }}</td>
                <td class="text-end">
                  <v-tooltip text="Open lot" location="top">
                    <template #activator="{ props }">
                      <v-btn v-bind="props" size="x-small" icon="mdi-package-up" variant="text"
                             color="primary" :disabled="!!lot.opened_date"
                             @click="openLotAction(lot)" />
                    </template>
                  </v-tooltip>
                  <v-tooltip text="Consume" location="top">
                    <template #activator="{ props }">
                      <v-btn v-bind="props" size="x-small" icon="mdi-minus-circle-outline" variant="text"
                             color="warning" @click="openTxn(lot, 'consume')" />
                    </template>
                  </v-tooltip>
                  <v-tooltip text="Adjust" location="top">
                    <template #activator="{ props }">
                      <v-btn v-bind="props" size="x-small" icon="mdi-tune-variant" variant="text"
                             @click="openTxn(lot, 'adjust')" />
                    </template>
                  </v-tooltip>
                  <v-tooltip text="Discard" location="top">
                    <template #activator="{ props }">
                      <v-btn v-bind="props" size="x-small" icon="mdi-trash-can-outline" variant="text"
                             color="error" @click="openTxn(lot, 'discard')" />
                    </template>
                  </v-tooltip>
                </td>
              </tr>
            </tbody>
          </v-table>
          <div v-else class="text-caption text-medium-emphasis pa-3 text-center">
            No lots received yet.
          </div>

          <v-divider class="my-4" />
          <div class="d-flex align-center mb-2">
            <v-icon color="indigo" class="mr-2">mdi-history</v-icon>
            <span class="text-subtitle-2 font-weight-bold">Recent transactions</span>
          </div>
          <v-list v-if="detailTxns.length" density="compact" class="bg-transparent">
            <v-list-item v-for="t in detailTxns.slice(0, 8)" :key="t.id"
                         :title="`${txnLabel(t.txn_type)} · ${t.lot_number}`"
                         :subtitle="`${formatDateTime(t.performed_at)} · ${t.performed_by_name || '—'} ${t.reason ? '· ' + t.reason : ''}`">
              <template #prepend>
                <v-avatar :color="txnColor(t.txn_type)" size="28">
                  <v-icon size="14" color="white">{{ txnIcon(t.txn_type) }}</v-icon>
                </v-avatar>
              </template>
              <template #append>
                <span class="font-monospace" :class="Number(t.quantity) < 0 ? 'text-error' : 'text-success'">
                  {{ Number(t.quantity) > 0 ? '+' : '' }}{{ formatQty(t.quantity) }}
                </span>
              </template>
            </v-list-item>
          </v-list>
          <div v-else class="text-caption text-medium-emphasis pa-3 text-center">
            No transactions yet.
          </div>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3 flex-wrap ga-1">
          <v-btn variant="text" prepend-icon="mdi-tray-arrow-down" color="success"
                 @click="openReceive(detailItem)">Receive lot</v-btn>
          <v-btn variant="text" prepend-icon="mdi-printer-outline" @click="printSheet(detailItem)">Print</v-btn>
          <v-spacer />
          <v-btn variant="text" @click="detailDialog = false">Close</v-btn>
          <v-btn color="primary" rounded="lg" prepend-icon="mdi-pencil" @click="openEdit(detailItem)">Edit</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Receive lot dialog -->
    <v-dialog v-model="receiveDialog" max-width="640" scrollable persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="green-lighten-5" size="40" class="mr-3">
            <v-icon color="green-darken-2">mdi-tray-arrow-down</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">RECEIVE LOT</div>
            <div class="text-h6 font-weight-bold">{{ receiveTarget?.name }}</div>
          </div>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" @click="receiveDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          <v-form ref="receiveFormRef">
            <v-row dense>
              <v-col cols="12" sm="6">
                <v-text-field v-model="receiveForm.lot_number" label="Lot # *"
                              prepend-inner-icon="mdi-barcode"
                              variant="outlined" density="comfortable" :rules="[required]" />
              </v-col>
              <v-col cols="6" sm="3">
                <v-text-field v-model.number="receiveForm.quantity" type="number" step="0.01"
                              label="Quantity *" prepend-inner-icon="mdi-numeric"
                              variant="outlined" density="comfortable" :rules="[required]" />
              </v-col>
              <v-col cols="6" sm="3" class="d-flex align-center">
                <span class="text-caption text-medium-emphasis">{{ receiveTarget?.unit }}</span>
              </v-col>
              <v-col cols="6" sm="4">
                <v-text-field v-model="receiveForm.received_date" type="date"
                              label="Received date" prepend-inner-icon="mdi-calendar-arrow-right"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="6" sm="4">
                <v-text-field v-model="receiveForm.expiry_date" type="date"
                              label="Expiry date" prepend-inner-icon="mdi-calendar-alert"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="6" sm="4">
                <v-text-field v-model.number="receiveForm.open_stability_days" type="number"
                              label="Open stability (days)" prepend-inner-icon="mdi-clock-alert"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="receiveForm.location" label="Storage location"
                              prepend-inner-icon="mdi-map-marker"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="receiveForm.reference" label="Reference (PO, invoice…)"
                              prepend-inner-icon="mdi-receipt-text"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="receiveForm.reason" label="Notes" rows="2"
                            prepend-inner-icon="mdi-text"
                            variant="outlined" density="comfortable" />
              </v-col>
            </v-row>
          </v-form>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="receiveDialog = false">Cancel</v-btn>
          <v-btn color="success" rounded="lg" :loading="receiveBusy" @click="doReceive">
            <v-icon start>mdi-tray-arrow-down</v-icon>Receive
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Lot transaction dialog -->
    <v-dialog v-model="txnDialog.show" max-width="520" persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar :color="txnColor(txnDialog.kind)" size="40" class="mr-3">
            <v-icon color="white">{{ txnIcon(txnDialog.kind) }}</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">{{ txnDialog.kind?.toUpperCase() }}</div>
            <div class="text-h6 font-weight-bold">Lot {{ txnDialog.lot?.lot_number }}</div>
          </div>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" @click="txnDialog.show = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          <div class="text-caption text-medium-emphasis mb-2">
            On hand: <strong class="font-monospace">{{ formatQty(txnDialog.lot?.quantity_on_hand) }}</strong>
          </div>
          <v-text-field v-if="txnDialog.kind !== 'discard'"
                        v-model.number="txnDialog.quantity" type="number" step="0.01"
                        :label="txnDialog.kind === 'adjust' ? 'Δ Quantity (+/-)' : 'Quantity *'"
                        prepend-inner-icon="mdi-numeric"
                        variant="outlined" density="comfortable" />
          <v-text-field v-model="txnDialog.reason" label="Reason / reference"
                        prepend-inner-icon="mdi-text"
                        variant="outlined" density="comfortable" class="mt-3" />
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="txnDialog.show = false">Cancel</v-btn>
          <v-btn :color="txnColor(txnDialog.kind)" rounded="lg" :loading="txnBusy" @click="doTxn">
            <v-icon start>{{ txnIcon(txnDialog.kind) }}</v-icon>
            {{ txnLabel(txnDialog.kind) }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Delete confirm -->
    <v-dialog v-model="deleteDialog.show" max-width="420" persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center">
          <v-icon color="error" class="mr-2">mdi-alert-circle</v-icon>Delete Reagent
        </v-card-title>
        <v-card-text>
          Delete <strong>{{ deleteDialog.item?.name }}</strong>?
          <span v-if="(deleteDialog.item?.lots || []).length" class="d-block text-warning mt-2">
            <v-icon size="14" class="mr-1">mdi-alert</v-icon>
            This will also remove {{ deleteDialog.item.lots.length }} lot(s) and their transactions.
          </span>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog.show = false">Cancel</v-btn>
          <v-btn color="error" variant="flat" :loading="deleteDialog.busy" @click="doDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'

const { $api } = useNuxtApp()

const r = useResource('/lab/reagents/')
const inst = useResource('/lab/instruments/')
const txns = useResource('/lab/reagent-transactions/')

const view = ref('table')
const stockFilter = ref(null)
const categoryFilter = ref(null)
const storageFilter = ref(null)
const instrumentFilter = ref(null)
const sortBy = ref('name_asc')
const selected = ref([])
const bulkBusy = ref(false)

const formDialog = ref(false)
const formRef = ref(null)
const form = ref(emptyForm())
const detailDialog = ref(false)
const detailItem = ref(null)
const deleteDialog = reactive({ show: false, item: null, busy: false })
const snack = reactive({ show: false, color: 'success', text: '' })
const csvFile = ref(null)

const receiveDialog = ref(false)
const receiveFormRef = ref(null)
const receiveTarget = ref(null)
const receiveForm = ref(emptyReceive())
const receiveBusy = ref(false)

const txnDialog = reactive({ show: false, kind: '', lot: null, quantity: 0, reason: '' })
const txnBusy = ref(false)

const CATEGORIES = [
  { title: 'Reagent', value: 'reagent' },
  { title: 'Control', value: 'control' },
  { title: 'Calibrator', value: 'calibrator' },
  { title: 'Stain / Dye', value: 'stain' },
  { title: 'Test Kit', value: 'kit' },
  { title: 'Consumable', value: 'consumable' },
  { title: 'Buffer / Diluent', value: 'buffer' },
  { title: 'Culture Media', value: 'media' },
  { title: 'Other', value: 'other' },
]
const CAT_META = {
  reagent: { icon: 'mdi-flask', color: 'indigo' },
  control: { icon: 'mdi-bullseye-arrow', color: 'deep-purple' },
  calibrator: { icon: 'mdi-tune-vertical', color: 'cyan' },
  stain: { icon: 'mdi-palette', color: 'pink' },
  kit: { icon: 'mdi-package-variant', color: 'teal' },
  consumable: { icon: 'mdi-tray-full', color: 'amber' },
  buffer: { icon: 'mdi-water', color: 'blue' },
  media: { icon: 'mdi-bacteria', color: 'green' },
  other: { icon: 'mdi-shape-outline', color: 'grey' },
}
const STORAGE = [
  { title: 'Room (15-25°C)', value: 'room' },
  { title: 'Refrigerated (2-8°C)', value: 'fridge' },
  { title: 'Frozen (-20°C)', value: 'freezer' },
  { title: 'Ultra-low (-80°C)', value: 'ultra' },
  { title: 'Protect from light', value: 'dark' },
  { title: 'Other', value: 'other' },
]
const STOCK_PILLS = [
  { label: 'All', value: null, key: 'all', icon: 'mdi-dots-grid' },
  { label: 'In stock', value: 'ok', key: 'ok', color: 'success', icon: 'mdi-check-circle' },
  { label: 'Low', value: 'low', key: 'low', color: 'warning', icon: 'mdi-alert' },
  { label: 'Out', value: 'out', key: 'out', color: 'error', icon: 'mdi-close-octagon' },
  { label: 'Expiring ≤30d', value: 'expiring', key: 'expiring', color: 'amber', icon: 'mdi-calendar-alert' },
  { label: 'Expired', value: 'expired', key: 'expired', color: 'red-darken-3', icon: 'mdi-skull' },
]

const sortOptions = [
  { title: 'Name (A → Z)', value: 'name_asc' },
  { title: 'Name (Z → A)', value: 'name_desc' },
  { title: 'Lowest stock', value: 'stock_low' },
  { title: 'Soonest expiry', value: 'expiry_soon' },
  { title: 'Recently added', value: 'recent' },
]

const headers = [
  { title: 'Reagent', key: 'name' },
  { title: 'Category', key: 'category', width: 130 },
  { title: 'Storage', key: 'storage', width: 130 },
  { title: 'Instrument', key: 'instrument_name', width: 140 },
  { title: 'On hand', key: 'quantity_on_hand', align: 'end', width: 150 },
  { title: 'Lots', key: 'active_lot_count', align: 'center', width: 70 },
  { title: 'Nearest expiry', key: 'nearest_expiry', width: 140 },
  { title: 'Status', key: 'stock_status', width: 110 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 150 },
]

const list = computed(() => r.items.value || [])
const instruments = computed(() => inst.items.value || [])

const departmentOptions = computed(() => [...new Set(list.value.map(x => x.department).filter(Boolean))].sort())
const manufacturerOptions = computed(() => [...new Set(list.value.map(x => x.manufacturer).filter(Boolean))].sort())
const supplierOptions = computed(() => [...new Set(list.value.map(x => x.supplier).filter(Boolean))].sort())

function daysUntil (d) {
  if (!d) return null
  const t = new Date(d)
  if (isNaN(t)) return null
  const today = new Date(); today.setHours(0, 0, 0, 0)
  return Math.round((t - today) / 86400000)
}

const stockPills = computed(() => {
  const arr = list.value
  return STOCK_PILLS.map(s => {
    let count = arr.length
    if (s.value === 'ok') count = arr.filter(x => x.stock_status === 'ok').length
    else if (s.value === 'low') count = arr.filter(x => x.stock_status === 'low').length
    else if (s.value === 'out') count = arr.filter(x => x.stock_status === 'out').length
    else if (s.value === 'expiring') count = arr.filter(x => {
      const dd = daysUntil(x.nearest_expiry); return dd != null && dd >= 0 && dd <= 30
    }).length
    else if (s.value === 'expired') count = arr.filter(x => {
      const dd = daysUntil(x.nearest_expiry); return dd != null && dd < 0
    }).length
    return { ...s, count }
  })
})

const categoryChips = computed(() => {
  const counts = list.value.reduce((acc, x) => {
    acc[x.category] = (acc[x.category] || 0) + 1; return acc
  }, {})
  const tops = Object.entries(counts).sort((a, b) => b[1] - a[1]).slice(0, 6)
    .map(([v, n]) => ({ label: catLabel(v), value: v, count: n }))
  return [{ label: 'All categories', value: null }, ...tops]
})

const filtered = computed(() => {
  let arr = r.filtered.value || []
  if (stockFilter.value === 'ok') arr = arr.filter(x => x.stock_status === 'ok')
  else if (stockFilter.value === 'low') arr = arr.filter(x => x.stock_status === 'low')
  else if (stockFilter.value === 'out') arr = arr.filter(x => x.stock_status === 'out')
  else if (stockFilter.value === 'expiring') arr = arr.filter(x => {
    const dd = daysUntil(x.nearest_expiry); return dd != null && dd >= 0 && dd <= 30
  })
  else if (stockFilter.value === 'expired') arr = arr.filter(x => {
    const dd = daysUntil(x.nearest_expiry); return dd != null && dd < 0
  })
  if (categoryFilter.value) arr = arr.filter(x => x.category === categoryFilter.value)
  if (storageFilter.value) arr = arr.filter(x => x.storage === storageFilter.value)
  if (instrumentFilter.value) arr = arr.filter(x => x.instrument === instrumentFilter.value)
  arr = [...arr]
  switch (sortBy.value) {
    case 'name_desc': arr.sort((a, b) => (b.name || '').localeCompare(a.name || '')); break
    case 'stock_low': arr.sort((a, b) => Number(a.quantity_on_hand) - Number(b.quantity_on_hand)); break
    case 'expiry_soon':
      arr.sort((a, b) => {
        const da = daysUntil(a.nearest_expiry); const db = daysUntil(b.nearest_expiry)
        if (da == null && db == null) return 0
        if (da == null) return 1
        if (db == null) return -1
        return da - db
      }); break
    case 'recent': arr.sort((a, b) => new Date(b.created_at) - new Date(a.created_at)); break
    default: arr.sort((a, b) => (a.name || '').localeCompare(b.name || ''))
  }
  return arr
})

const alertItems = computed(() => {
  const out = []
  for (const reg of list.value) {
    if (reg.stock_status === 'out') {
      out.push({ id: 'o' + reg.id, kind: 'out', icon: 'mdi-close-octagon',
        label: `${reg.name} — out`, reagent: reg })
    } else if (reg.stock_status === 'low') {
      out.push({ id: 'l' + reg.id, kind: 'low', icon: 'mdi-alert',
        label: `${reg.name} — low (${formatQty(reg.quantity_on_hand)})`, reagent: reg })
    }
    const dd = daysUntil(reg.nearest_expiry)
    if (dd != null && dd < 0) {
      out.push({ id: 'x' + reg.id, kind: 'expired', icon: 'mdi-skull',
        label: `${reg.name} — expired ${Math.abs(dd)}d ago`, reagent: reg })
    } else if (dd != null && dd <= 30) {
      out.push({ id: 'e' + reg.id, kind: 'expiring', icon: 'mdi-calendar-alert',
        label: `${reg.name} — expires in ${dd}d`, reagent: reg })
    }
  }
  return out
})

const totalValue = computed(() =>
  list.value.reduce((s, r) => s + Number(r.unit_cost || 0) * Number(r.quantity_on_hand || 0), 0)
)

const kpis = computed(() => {
  const arr = list.value
  return [
    { label: 'Reagents', value: arr.length, icon: 'mdi-test-tube', color: 'indigo',
      hint: `${arr.filter(x => x.is_active).length} active` },
    { label: 'Low / Out', value: arr.filter(x => ['low', 'out'].includes(x.stock_status)).length,
      icon: 'mdi-alert', color: 'amber',
      hint: `${arr.filter(x => x.stock_status === 'out').length} out of stock` },
    { label: 'Expiring ≤30d', value: stockPills.value.find(s => s.value === 'expiring')?.count || 0,
      icon: 'mdi-calendar-alert', color: 'red',
      hint: `${stockPills.value.find(s => s.value === 'expired')?.count || 0} already expired` },
    { label: 'Stock value', value: formatMoney(totalValue.value),
      icon: 'mdi-cash-multiple', color: 'green', hint: 'cost × qty on hand' },
  ]
})

const detailTxns = computed(() => {
  if (!detailItem.value) return []
  const ids = (detailItem.value.lots || []).map(l => l.id)
  return (txns.items.value || []).filter(t => ids.includes(t.lot))
    .sort((a, b) => new Date(b.performed_at) - new Date(a.performed_at))
})

// ─── Helpers ───
function catLabel (v) { return CATEGORIES.find(c => c.value === v)?.title || v || '—' }
function catColor (v) { return CAT_META[v]?.color || 'grey' }
function storageLabel (v) { return STORAGE.find(s => s.value === v)?.title || v || '—' }
function storageIcon (v) {
  return { room: 'mdi-home-thermometer-outline', fridge: 'mdi-fridge-outline',
    freezer: 'mdi-snowflake', ultra: 'mdi-snowflake-variant',
    dark: 'mdi-weather-night', other: 'mdi-thermometer' }[v] || 'mdi-thermometer'
}
function storageColor (v) {
  return { room: 'grey', fridge: 'cyan', freezer: 'blue', ultra: 'indigo',
    dark: 'deep-purple', other: 'grey-darken-1' }[v] || 'grey'
}
function stockLabel (v) { return { ok: 'In stock', low: 'Low', out: 'Out' }[v] || v || '—' }
function stockColor (v) { return { ok: 'success', low: 'warning', out: 'error' }[v] || 'grey' }
function stockIcon (v) {
  return { ok: 'mdi-check-circle', low: 'mdi-alert', out: 'mdi-close-octagon' }[v] || 'mdi-help-circle'
}
function stockHex (v) { return { ok: '#43a047', low: '#fb8c00', out: '#e53935' }[v] || '#9e9e9e' }
function stockTextClass (item) {
  const s = item.stock_status
  if (s === 'out') return 'text-error'
  if (s === 'low') return 'text-warning'
  return ''
}
function expiryClass (d) {
  const dd = daysUntil(d)
  if (dd == null) return 'text-medium-emphasis'
  if (dd < 0) return 'text-error font-weight-bold'
  if (dd <= 30) return 'text-warning font-weight-bold'
  return ''
}
function expiryLabel (d) {
  const dd = daysUntil(d)
  if (dd == null) return ''
  if (dd < 0) return `Expired ${Math.abs(dd)}d`
  if (dd === 0) return 'Today'
  if (dd <= 30) return `In ${dd}d`
  return `In ${dd}d`
}

function lotStatusLabel (s) {
  return { active: 'Active', quarantine: 'Quarantine', expired: 'Expired',
    discarded: 'Discarded', depleted: 'Depleted' }[s] || s
}
function lotStatusColor (s) {
  return { active: 'success', quarantine: 'warning', expired: 'error',
    discarded: 'grey', depleted: 'blue-grey' }[s] || 'grey'
}

function txnLabel (k) {
  return { receive: 'Receive', consume: 'Consume', adjust: 'Adjust',
    discard: 'Discard', transfer: 'Transfer', return: 'Return' }[k] || k
}
function txnIcon (k) {
  return { receive: 'mdi-tray-arrow-down', consume: 'mdi-minus-circle',
    adjust: 'mdi-tune-variant', discard: 'mdi-trash-can',
    transfer: 'mdi-swap-horizontal', return: 'mdi-undo-variant' }[k] || 'mdi-circle'
}
function txnColor (k) {
  return { receive: 'success', consume: 'warning', adjust: 'indigo',
    discard: 'error', transfer: 'cyan', return: 'amber' }[k] || 'grey'
}

function formatDate (s) {
  if (!s) return '—'
  return new Date(s).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })
}
function formatDateTime (s) {
  if (!s) return '—'
  return new Date(s).toLocaleString()
}
function formatQty (n) {
  if (n == null || n === '') return '0'
  const v = Number(n)
  return Number.isInteger(v) ? v.toString() : v.toFixed(2)
}
function formatMoney (n) {
  if (n == null) return 'KES 0.00'
  return 'KES ' + Number(n).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

const required = v => (v !== null && v !== undefined && v !== '') || 'Required'

function emptyForm () {
  return {
    id: null, name: '', code: '', catalog_no: '',
    manufacturer: '', supplier: '',
    category: 'reagent', storage: 'room', department: '',
    instrument: null, unit: 'mL', pack_size: '', unit_cost: 0,
    reorder_level: 0, reorder_qty: 0,
    msds_url: '', hazard_class: '', is_controlled: false,
    notes: '', is_active: true,
  }
}
function emptyReceive () {
  return {
    lot_number: '', quantity: 0,
    received_date: new Date().toISOString().slice(0, 10),
    expiry_date: '', open_stability_days: null,
    location: '', reference: '', reason: '',
  }
}

function openNew () { form.value = emptyForm(); formDialog.value = true }
function openEdit (it) {
  form.value = { ...emptyForm(), ...it }
  detailDialog.value = false
  formDialog.value = true
}
async function openDetail (it) {
  // Fetch fresh detail to include lots[]
  try {
    const res = await $api.get(`/lab/reagents/${it.id}/`)
    detailItem.value = res.data
  } catch {
    detailItem.value = it
  }
  detailDialog.value = true
  txns.list()
}

async function save () {
  const { valid } = (await formRef.value?.validate?.()) || { valid: true }
  if (!valid) return
  try {
    const payload = { ...form.value }
    if (payload.id) await r.update(payload.id, payload)
    else await r.create(payload)
    formDialog.value = false
    notify(`Reagent ${form.value.id ? 'updated' : 'created'} successfully`)
    await r.list()
  } catch (e) { notify(r.error.value || 'Save failed', 'error') }
}

function confirmDelete (it) { deleteDialog.item = it; deleteDialog.show = true }
async function doDelete () {
  deleteDialog.busy = true
  try {
    await r.remove(deleteDialog.item.id)
    notify('Reagent deleted')
    deleteDialog.show = false
    detailDialog.value = false
  } catch (e) { notify(r.error.value || 'Delete failed', 'error') }
  finally { deleteDialog.busy = false }
}

async function bulkActivate (active) {
  bulkBusy.value = true
  try {
    await Promise.all(selected.value.map(id => {
      const it = list.value.find(x => x.id === id)
      return it ? r.update(id, { ...it, is_active: active }) : null
    }))
    notify(`${selected.value.length} reagent(s) ${active ? 'activated' : 'deactivated'}`)
    selected.value = []
    await r.list()
  } catch (e) { notify(r.error.value || 'Bulk update failed', 'error') }
  finally { bulkBusy.value = false }
}
async function bulkDelete () {
  if (!confirm(`Delete ${selected.value.length} reagent(s)? Lots will also be removed.`)) return
  bulkBusy.value = true
  try {
    await Promise.all(selected.value.map(id => r.remove(id)))
    notify(`${selected.value.length} reagent(s) deleted`)
    selected.value = []
  } catch (e) { notify(r.error.value || 'Bulk delete failed', 'error') }
  finally { bulkBusy.value = false }
}

// Receive flow
function openReceive (reagent) {
  receiveTarget.value = reagent
  receiveForm.value = emptyReceive()
  receiveDialog.value = true
}
async function doReceive () {
  const { valid } = (await receiveFormRef.value?.validate?.()) || { valid: true }
  if (!valid) return
  receiveBusy.value = true
  try {
    await $api.post(`/lab/reagents/${receiveTarget.value.id}/receive_lot/`, {
      ...receiveForm.value,
      open_stability_days: receiveForm.value.open_stability_days || null,
      expiry_date: receiveForm.value.expiry_date || null,
    })
    notify('Lot received')
    receiveDialog.value = false
    await r.list()
    txns.list()
    if (detailItem.value && detailItem.value.id === receiveTarget.value.id) {
      const res = await $api.get(`/lab/reagents/${detailItem.value.id}/`)
      detailItem.value = res.data
    }
  } catch (e) { notify(e?.response?.data?.detail || 'Receive failed', 'error') }
  finally { receiveBusy.value = false }
}

// Lot transactions
function openTxn (lot, kind) {
  txnDialog.lot = lot; txnDialog.kind = kind
  txnDialog.quantity = 0; txnDialog.reason = ''
  txnDialog.show = true
}
async function openLotAction (lot) {
  try {
    await $api.post(`/lab/reagent-lots/${lot.id}/open_lot/`)
    notify('Lot marked as opened')
    if (detailItem.value) {
      const res = await $api.get(`/lab/reagents/${detailItem.value.id}/`)
      detailItem.value = res.data
    }
  } catch (e) { notify(e?.response?.data?.detail || 'Open failed', 'error') }
}
async function doTxn () {
  txnBusy.value = true
  try {
    const path = `/lab/reagent-lots/${txnDialog.lot.id}/${txnDialog.kind}/`
    await $api.post(path, { quantity: txnDialog.quantity || 0, reason: txnDialog.reason })
    notify(`${txnLabel(txnDialog.kind)} recorded`)
    txnDialog.show = false
    await r.list()
    txns.list()
    if (detailItem.value) {
      const res = await $api.get(`/lab/reagents/${detailItem.value.id}/`)
      detailItem.value = res.data
    }
  } catch (e) { notify(e?.response?.data?.detail || 'Transaction failed', 'error') }
  finally { txnBusy.value = false }
}

function reload () { r.list(); inst.list(); txns.list() }
function notify (text, color = 'success') { snack.text = text; snack.color = color; snack.show = true }

function exportCsv () {
  const rows = filtered.value
  if (!rows.length) return
  const cols = ['name', 'code', 'catalog_no', 'category', 'storage', 'manufacturer', 'supplier',
    'department', 'unit', 'pack_size', 'unit_cost', 'quantity_on_hand', 'reorder_level',
    'nearest_expiry', 'stock_status', 'is_active']
  const esc = v => `"${String(v ?? '').replace(/"/g, '""')}"`
  const body = rows.map(it => cols.map(c => esc(it[c])).join(',')).join('\n')
  const blob = new Blob([cols.join(',') + '\n' + body], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `lab-reagents_${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

function parseCsv (text) {
  const lines = text.split(/\r?\n/).filter(l => l.trim().length)
  if (!lines.length) return []
  const head = splitCsv(lines[0])
  return lines.slice(1).map(l => {
    const cells = splitCsv(l)
    const o = {}
    head.forEach((h, i) => { o[h.trim()] = cells[i] })
    return o
  })
}
function splitCsv (line) {
  const out = []; let cur = ''; let inQ = false
  for (let i = 0; i < line.length; i++) {
    const c = line[i]
    if (inQ) {
      if (c === '"' && line[i + 1] === '"') { cur += '"'; i++ }
      else if (c === '"') { inQ = false }
      else cur += c
    } else {
      if (c === ',') { out.push(cur); cur = '' }
      else if (c === '"') inQ = true
      else cur += c
    }
  }
  out.push(cur)
  return out
}
async function runImport (e) {
  const file = e.target.files?.[0]
  if (!file) return
  try {
    const text = await file.text()
    const rows = parseCsv(text)
    let ok = 0; let fail = 0
    for (const row of rows) {
      try {
        await r.create({
          name: row.name || '', code: row.code || '', catalog_no: row.catalog_no || '',
          manufacturer: row.manufacturer || '', supplier: row.supplier || '',
          category: row.category || 'reagent', storage: row.storage || 'room',
          department: row.department || '', unit: row.unit || '',
          pack_size: row.pack_size || '', unit_cost: Number(row.unit_cost) || 0,
          reorder_level: Number(row.reorder_level) || 0,
          reorder_qty: Number(row.reorder_qty) || 0,
          is_active: row.is_active === 'false' ? false : true,
        })
        ok++
      } catch { fail++ }
    }
    notify(`Imported ${ok}, failed ${fail}`, fail ? 'warning' : 'success')
    await r.list()
  } catch (err) {
    notify('Import failed: ' + (err?.message || err), 'error')
  } finally {
    if (csvFile.value) csvFile.value.value = ''
  }
}

function printSheet (i) {
  const w = window.open('', '_blank')
  if (!w) return
  const lotsHtml = (i.lots || []).map(l => `
    <tr><td>${l.lot_number}</td><td>${formatDate(l.received_date)}</td>
    <td>${formatDate(l.expiry_date)}</td><td>${formatQty(l.quantity_on_hand)}</td>
    <td>${l.location || '—'}</td><td>${lotStatusLabel(l.status)}</td></tr>
  `).join('')
  w.document.write(`
    <html><head><title>${i.name} · Reagent</title>
    <style>
      body{font-family:Arial,sans-serif;padding:32px;color:#222}
      h1{margin:0 0 4px;font-size:22px}
      .muted{color:#666;font-size:12px}
      table{width:100%;border-collapse:collapse;margin-top:12px}
      th,td{border-bottom:1px solid #eee;padding:8px;text-align:left;font-size:13px}
      th{background:#fafafa}
      .badge{display:inline-block;padding:2px 8px;border-radius:6px;font-size:12px;color:#fff;background:#3949ab}
    </style></head><body>
      <h1>${i.name}</h1>
      <div class="muted">${[i.manufacturer, i.catalog_no].filter(Boolean).join(' · ')}</div>
      <p><span class="badge">${catLabel(i.category)}</span>
        <span class="badge">${storageLabel(i.storage)}</span></p>
      <table>
        <tr><th>Code</th><td>${i.code || '—'}</td><th>Supplier</th><td>${i.supplier || '—'}</td></tr>
        <tr><th>Pack size</th><td>${i.pack_size || '—'}</td>
            <th>Unit cost</th><td>${formatMoney(i.unit_cost)}</td></tr>
        <tr><th>On hand</th><td>${formatQty(i.quantity_on_hand)} ${i.unit || ''}</td>
            <th>Reorder</th><td>≤ ${formatQty(i.reorder_level)} (suggest ${formatQty(i.reorder_qty)})</td></tr>
        <tr><th>Hazard</th><td>${i.hazard_class || '—'}</td>
            <th>MSDS</th><td>${i.msds_url || '—'}</td></tr>
      </table>
      <h3>Lots</h3>
      <table>
        <tr><th>Lot</th><th>Received</th><th>Expiry</th><th>On hand</th><th>Location</th><th>Status</th></tr>
        ${lotsHtml || '<tr><td colspan="6" style="color:#888">No lots</td></tr>'}
      </table>
      ${i.notes ? `<h3>Notes</h3><p>${i.notes}</p>` : ''}
    </body></html>`)
  w.document.close()
  w.print()
}

onMounted(() => { r.list(); inst.list(); txns.list() })
</script>

<style scoped>
.kpi { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.reagent-table :deep(tbody tr) { cursor: pointer; }
.reagent-card {
  position: relative;
  overflow: hidden;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  cursor: pointer;
  transition: transform 120ms ease, box-shadow 120ms ease;
}
.reagent-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.06); }
.reagent-band { position: absolute; top: 0; left: 0; right: 0; height: 3px; }
.bulk-bar {
  border: 1px solid rgba(var(--v-theme-primary), 0.2);
  background: rgba(var(--v-theme-primary), 0.04);
}
.min-width-0 { min-width: 0; }
.font-monospace { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
.cursor-pointer { cursor: pointer; }
</style>
