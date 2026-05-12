<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="indigo-lighten-5" size="48">
        <v-icon color="indigo-darken-2" size="28">mdi-cog-transfer</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Lab Instruments</div>
        <div class="text-body-2 text-medium-emphasis">
          Analyzer registry · service schedule · QC linkage
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
      <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openNew">New Instrument</v-btn>
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
          v-for="s in statusPills" :key="s.key"
          :color="statusFilter === s.value ? (s.color || 'primary') : undefined"
          :variant="statusFilter === s.value ? 'flat' : 'tonal'"
          size="small" @click="statusFilter = s.value"
        >
          <v-icon v-if="s.icon" size="14" start>{{ s.icon }}</v-icon>
          {{ s.label }}<span class="ml-2 font-weight-bold">{{ s.count }}</span>
        </v-chip>

        <v-divider vertical class="mx-2" />

        <v-chip
          v-for="d in deptChips" :key="d.value || 'all-dept'"
          :color="deptFilter === d.value ? 'indigo' : undefined"
          :variant="deptFilter === d.value ? 'flat' : 'tonal'"
          size="small" @click="deptFilter = d.value"
        >
          <v-icon size="14" start>mdi-domain</v-icon>
          {{ d.label }}
          <span v-if="d.count != null" class="ml-2 font-weight-bold">{{ d.count }}</span>
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
        <v-col cols="12" md="5">
          <v-text-field v-model="r.search.value"
                        prepend-inner-icon="mdi-magnify"
                        placeholder="Search by name, serial, manufacturer…"
                        variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="3">
          <v-select v-model="serviceFilter" :items="serviceOptions"
                    label="Service status" prepend-inner-icon="mdi-wrench-clock"
                    variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="sortBy" :items="sortOptions"
                    label="Sort" prepend-inner-icon="mdi-sort"
                    variant="outlined" density="compact" hide-details />
        </v-col>
        <v-col cols="12" md="2" class="d-flex justify-end">
          <v-btn variant="text" size="small" @click="resetFilters">
            <v-icon start size="16">mdi-filter-remove-outline</v-icon>Reset
          </v-btn>
        </v-col>
      </v-row>
    </v-card>

    <!-- Service-due ribbon -->
    <v-slide-y-transition>
      <v-alert v-if="serviceDueList.length" type="warning" variant="tonal"
               class="mt-3" prominent rounded="lg" icon="mdi-wrench-clock">
        <div class="font-weight-bold">{{ serviceDueList.length }} instrument(s) need attention</div>
        <div class="text-body-2 d-flex flex-wrap ga-1 mt-1">
          <v-chip v-for="i in serviceDueList.slice(0, 6)" :key="i.id" size="x-small"
                  :color="serviceUrgency(i) === 'overdue' ? 'error' : 'warning'"
                  variant="flat" class="cursor-pointer" @click="openDetail(i)">
            {{ i.name }} · {{ serviceLabel(i) }}
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
          <v-menu>
            <template #activator="{ props }">
              <v-btn v-bind="props" size="small" variant="tonal" color="primary"
                     prepend-icon="mdi-tag-arrow-up">Set status</v-btn>
            </template>
            <v-list density="compact">
              <v-list-item v-for="s in STATUSES" :key="s.value"
                           :title="s.title"
                           :prepend-icon="statusIcon(s.value)"
                           @click="bulkSetStatus(s.value)" />
            </v-list>
          </v-menu>
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
        class="inst-table"
        @click:row="(_, { item }) => openDetail(item)"
      >
        <template #loading><v-skeleton-loader type="table-row@5" /></template>
        <template #item.name="{ item }">
          <div class="d-flex align-center">
            <v-avatar :color="avatarColor(item)" size="34" class="mr-3">
              <span class="text-caption font-weight-bold text-white">{{ initials(item.name) }}</span>
            </v-avatar>
            <div class="min-width-0">
              <div class="font-weight-medium text-truncate">{{ item.name }}</div>
              <div class="text-caption text-medium-emphasis text-truncate">
                {{ [item.manufacturer, item.model].filter(Boolean).join(' · ') || '—' }}
              </div>
            </div>
          </div>
        </template>
        <template #item.serial_no="{ value }">
          <span v-if="value" class="font-monospace text-caption">{{ value }}</span>
          <span v-else class="text-medium-emphasis text-caption">—</span>
        </template>
        <template #item.department="{ value }">
          <v-chip v-if="value" size="x-small" variant="tonal">{{ value }}</v-chip>
          <span v-else class="text-medium-emphasis text-caption">—</span>
        </template>
        <template #item.location="{ value }">
          <span v-if="value" class="text-caption">
            <v-icon size="12" class="mr-1">mdi-map-marker</v-icon>{{ value }}
          </span>
          <span v-else class="text-medium-emphasis text-caption">—</span>
        </template>
        <template #item.status="{ value, item }">
          <div class="d-flex align-center ga-1">
            <v-chip :color="statusColor(value)" size="small" variant="flat" class="text-capitalize">
              <v-icon size="14" start>{{ statusIcon(value) }}</v-icon>
              {{ statusLabel(value) }}
            </v-chip>
            <v-tooltip v-if="!item.is_active" text="Inactive" location="top">
              <template #activator="{ props }">
                <v-icon v-bind="props" size="14" color="grey">mdi-eye-off</v-icon>
              </template>
            </v-tooltip>
          </div>
        </template>
        <template #item.next_service_date="{ item }">
          <div class="d-flex flex-column">
            <span class="text-caption" :class="serviceClass(item)">
              {{ formatDate(item.next_service_date) }}
            </span>
            <span class="text-caption text-medium-emphasis">{{ serviceLabel(item) }}</span>
          </div>
        </template>
        <template #item.qc_count="{ item }">
          <v-chip v-if="qcCountFor(item.id)" size="x-small" variant="tonal" color="indigo">
            {{ qcCountFor(item.id) }}
          </v-chip>
          <span v-else class="text-medium-emphasis text-caption">—</span>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end" @click.stop>
            <v-tooltip text="Mark serviced today" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-wrench-check" variant="text" size="small"
                       color="success" @click="markServiced(item)" />
              </template>
            </v-tooltip>
            <v-tooltip text="View QC" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-chart-bell-curve-cumulative" variant="text" size="small"
                       color="indigo" @click="goToQc(item)" />
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
                <v-list-item prepend-icon="mdi-content-copy" title="Duplicate" @click="duplicate(item)" />
                <v-list-item prepend-icon="mdi-printer-outline" title="Print spec sheet" @click="printSheet(item)" />
                <v-divider />
                <v-list-item prepend-icon="mdi-delete" title="Delete" base-color="error"
                             @click="confirmDelete(item)" />
              </v-list>
            </v-menu>
          </div>
        </template>
        <template #no-data>
          <div class="pa-8 text-center">
            <v-icon size="56" color="grey-lighten-1">mdi-cog-off-outline</v-icon>
            <div class="text-subtitle-1 font-weight-medium mt-2">No instruments found</div>
            <div class="text-body-2 text-medium-emphasis mb-4">Adjust filters or register a new instrument.</div>
            <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openNew">New Instrument</v-btn>
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
        <v-icon size="56" color="grey-lighten-1">mdi-cog-off-outline</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-2">No instruments found</div>
        <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" class="mt-3" @click="openNew">New Instrument</v-btn>
      </div>
      <v-row v-else dense>
        <v-col v-for="i in filtered" :key="i.id" cols="12" sm="6" md="4" lg="3">
          <v-card flat rounded="lg" class="inst-card pa-3 h-100" hover @click="openDetail(i)">
            <div class="inst-band" :style="{ background: statusHex(i.status) }" />
            <div class="d-flex align-center mb-2">
              <v-chip :color="statusColor(i.status)" size="x-small" variant="flat" class="text-capitalize">
                <v-icon size="12" start>{{ statusIcon(i.status) }}</v-icon>{{ statusLabel(i.status) }}
              </v-chip>
              <v-spacer />
              <v-chip v-if="i.department" size="x-small" variant="tonal">{{ i.department }}</v-chip>
            </div>
            <div class="d-flex align-center">
              <v-avatar :color="avatarColor(i)" size="40" class="mr-3">
                <span class="text-caption font-weight-bold text-white">{{ initials(i.name) }}</span>
              </v-avatar>
              <div class="min-width-0 flex-grow-1">
                <div class="font-weight-medium text-truncate">{{ i.name }}</div>
                <div class="text-caption text-medium-emphasis text-truncate">
                  {{ [i.manufacturer, i.model].filter(Boolean).join(' · ') || '—' }}
                </div>
              </div>
            </div>
            <v-divider class="my-3" />
            <div class="d-flex justify-space-between text-caption mb-1">
              <span class="text-medium-emphasis">Serial</span>
              <span class="font-monospace">{{ i.serial_no || '—' }}</span>
            </div>
            <div class="d-flex justify-space-between text-caption mb-1">
              <span class="text-medium-emphasis">Location</span>
              <span class="text-truncate">{{ i.location || '—' }}</span>
            </div>
            <div class="d-flex justify-space-between text-caption mb-1">
              <span class="text-medium-emphasis">Last service</span>
              <span>{{ formatDate(i.last_service_date) }}</span>
            </div>
            <div class="d-flex justify-space-between text-caption">
              <span class="text-medium-emphasis">Next service</span>
              <span :class="serviceClass(i)">{{ serviceLabel(i) }}</span>
            </div>
          </v-card>
        </v-col>
      </v-row>
    </div>

    <!-- Form dialog -->
    <v-dialog v-model="formDialog" max-width="780" scrollable persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="indigo-lighten-5" size="40" class="mr-3">
            <v-icon color="indigo-darken-2">{{ form.id ? 'mdi-pencil' : 'mdi-plus' }}</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">INSTRUMENT</div>
            <div class="text-h6 font-weight-bold">{{ form.id ? 'Edit instrument' : 'New instrument' }}</div>
          </div>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" @click="formDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          <v-form ref="formRef" @submit.prevent="save">
            <v-row dense>
              <v-col cols="12" sm="8">
                <v-text-field v-model="form.name" label="Name *" prepend-inner-icon="mdi-cog"
                              variant="outlined" density="comfortable" :rules="[required]" />
              </v-col>
              <v-col cols="12" sm="4">
                <v-text-field v-model="form.serial_no" label="Serial No." prepend-inner-icon="mdi-barcode"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-combobox v-model="form.manufacturer" :items="manufacturerOptions"
                            label="Manufacturer" prepend-inner-icon="mdi-factory"
                            variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.model" label="Model" prepend-inner-icon="mdi-tag-outline"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-combobox v-model="form.department" :items="departmentOptions"
                            label="Department" prepend-inner-icon="mdi-domain"
                            variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.location" label="Location" prepend-inner-icon="mdi-map-marker"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="6" sm="6">
                <v-select v-model="form.status" :items="STATUSES" label="Status"
                          prepend-inner-icon="mdi-tag-multiple"
                          variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="6" sm="6" class="d-flex align-center">
                <v-switch v-model="form.is_active" color="success" hide-details
                          :label="form.is_active ? 'Active' : 'Inactive'" inset />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.last_service_date" label="Last service date" type="date"
                              prepend-inner-icon="mdi-calendar-check"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.next_service_date" label="Next service date" type="date"
                              prepend-inner-icon="mdi-calendar-clock"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="form.notes" label="Notes" rows="2" auto-grow
                            prepend-inner-icon="mdi-text"
                            variant="outlined" density="comfortable" />
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

    <!-- Detail dialog -->
    <v-dialog v-model="detailDialog" max-width="780" scrollable>
      <v-card v-if="detailItem" rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar :color="avatarColor(detailItem)" size="44" class="mr-3">
            <span class="font-weight-bold text-white">{{ initials(detailItem.name) }}</span>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">
              {{ [detailItem.manufacturer, detailItem.model].filter(Boolean).join(' · ') || 'INSTRUMENT' }}
            </div>
            <div class="text-h6 font-weight-bold">{{ detailItem.name }}</div>
          </div>
          <v-spacer />
          <v-chip :color="statusColor(detailItem.status)" size="small" variant="flat"
                  class="mr-2 text-capitalize">
            <v-icon size="14" start>{{ statusIcon(detailItem.status) }}</v-icon>
            {{ statusLabel(detailItem.status) }}
          </v-chip>
          <v-btn icon="mdi-close" variant="text" @click="detailDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          <v-row dense>
            <v-col cols="6" sm="4">
              <div class="text-caption text-medium-emphasis">Serial No.</div>
              <div class="font-monospace">{{ detailItem.serial_no || '—' }}</div>
            </v-col>
            <v-col cols="6" sm="4">
              <div class="text-caption text-medium-emphasis">Department</div>
              <div>{{ detailItem.department || '—' }}</div>
            </v-col>
            <v-col cols="6" sm="4">
              <div class="text-caption text-medium-emphasis">Location</div>
              <div>{{ detailItem.location || '—' }}</div>
            </v-col>
            <v-col cols="6" sm="4">
              <div class="text-caption text-medium-emphasis">Last service</div>
              <div>{{ formatDate(detailItem.last_service_date) }}</div>
            </v-col>
            <v-col cols="6" sm="4">
              <div class="text-caption text-medium-emphasis">Next service</div>
              <div :class="serviceClass(detailItem)">
                {{ formatDate(detailItem.next_service_date) }}
                <span class="text-caption d-block">{{ serviceLabel(detailItem) }}</span>
              </div>
            </v-col>
            <v-col cols="6" sm="4">
              <div class="text-caption text-medium-emphasis">Registered</div>
              <div>{{ formatDate(detailItem.created_at) }}</div>
            </v-col>
            <v-col v-if="detailItem.notes" cols="12">
              <v-divider class="my-2" />
              <div class="text-caption text-medium-emphasis mb-1">Notes</div>
              <div>{{ detailItem.notes }}</div>
            </v-col>
          </v-row>

          <v-divider class="my-4" />
          <div class="d-flex align-center mb-2">
            <v-icon color="indigo" class="mr-2">mdi-chart-bell-curve-cumulative</v-icon>
            <span class="text-subtitle-2 font-weight-bold">Recent QC ({{ qcRunsFor(detailItem.id).length }})</span>
            <v-spacer />
            <v-btn size="small" variant="text" color="indigo"
                   prepend-icon="mdi-arrow-right" @click="goToQc(detailItem)">Open QC</v-btn>
          </div>
          <div v-if="!qcRunsFor(detailItem.id).length"
               class="text-caption text-medium-emphasis pa-3 text-center">
            No QC runs logged for this instrument yet.
          </div>
          <v-list v-else density="compact" class="bg-transparent">
            <v-list-item v-for="q in qcRunsFor(detailItem.id).slice(0, 6)" :key="q.id"
                         :title="q.test_name"
                         :subtitle="`${formatDate(q.run_at)} · ${q.qc_level || '—'} · Lot ${q.lot_number || '—'}`">
              <template #prepend>
                <v-avatar :color="qcResultColor(q.result)" size="28">
                  <v-icon size="14" color="white">{{ qcResultIcon(q.result) }}</v-icon>
                </v-avatar>
              </template>
              <template #append>
                <span class="font-monospace text-caption" :class="sdClass(q.sd)">
                  {{ q.sd != null ? Number(q.sd).toFixed(2) + ' SD' : '' }}
                </span>
              </template>
            </v-list-item>
          </v-list>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3 flex-wrap ga-1">
          <v-btn variant="text" prepend-icon="mdi-wrench-check" color="success"
                 @click="markServiced(detailItem)">Mark serviced today</v-btn>
          <v-btn variant="text" prepend-icon="mdi-printer-outline" @click="printSheet(detailItem)">Print</v-btn>
          <v-spacer />
          <v-btn variant="text" @click="detailDialog = false">Close</v-btn>
          <v-btn color="primary" rounded="lg" prepend-icon="mdi-pencil" @click="openEdit(detailItem)">Edit</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Delete confirm -->
    <v-dialog v-model="deleteDialog.show" max-width="420" persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center">
          <v-icon color="error" class="mr-2">mdi-alert-circle</v-icon>Delete Instrument
        </v-card-title>
        <v-card-text>
          Delete <strong>{{ deleteDialog.item?.name }}</strong>?
          <span v-if="qcCountFor(deleteDialog.item?.id)" class="d-block text-warning mt-2">
            <v-icon size="14" class="mr-1">mdi-alert</v-icon>
            This will also remove {{ qcCountFor(deleteDialog.item?.id) }} linked QC run(s).
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

const r = useResource('/lab/instruments/')
const qc = useResource('/lab/qc/')
const router = useRouter()

const view = ref('table')
const statusFilter = ref(null)
const deptFilter = ref(null)
const serviceFilter = ref(null)
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

const STATUSES = [
  { title: 'Active', value: 'active' },
  { title: 'Maintenance', value: 'maintenance' },
  { title: 'Offline', value: 'offline' },
  { title: 'Retired', value: 'retired' },
]

const STATUS_PILLS = [
  { label: 'All', value: null, key: 'all', icon: 'mdi-dots-grid' },
  { label: 'Active', value: 'active', key: 'active', color: 'success', icon: 'mdi-check-circle' },
  { label: 'Maintenance', value: 'maintenance', key: 'maintenance', color: 'warning', icon: 'mdi-wrench' },
  { label: 'Offline', value: 'offline', key: 'offline', color: 'error', icon: 'mdi-power-plug-off' },
  { label: 'Retired', value: 'retired', key: 'retired', color: 'grey', icon: 'mdi-archive' },
]

const serviceOptions = [
  { title: 'Overdue', value: 'overdue' },
  { title: 'Due ≤ 14 days', value: 'soon' },
  { title: 'Scheduled', value: 'scheduled' },
  { title: 'No schedule', value: 'none' },
]

const sortOptions = [
  { title: 'Name (A → Z)', value: 'name_asc' },
  { title: 'Name (Z → A)', value: 'name_desc' },
  { title: 'Next service (soonest)', value: 'service_soon' },
  { title: 'Recently added', value: 'recent' },
]

const headers = [
  { title: 'Instrument', key: 'name' },
  { title: 'Serial', key: 'serial_no', width: 130 },
  { title: 'Department', key: 'department', width: 130 },
  { title: 'Location', key: 'location', width: 150 },
  { title: 'Status', key: 'status', width: 150 },
  { title: 'Next service', key: 'next_service_date', width: 150 },
  { title: 'QC', key: 'qc_count', width: 70, align: 'center', sortable: false },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 180 },
]

const PALETTE = ['indigo', 'teal', 'deep-purple', 'cyan', 'pink', 'amber', 'green', 'blue', 'red', 'brown']
function hashIdx (s) {
  const t = String(s || '')
  let h = 0
  for (let i = 0; i < t.length; i++) h = (h * 31 + t.charCodeAt(i)) >>> 0
  return h % PALETTE.length
}
function avatarColor (i) { return PALETTE[hashIdx(i?.name || i?.id)] }
function initials (name) {
  return String(name || '?').split(/\s+/).filter(Boolean).slice(0, 2)
    .map(w => w[0].toUpperCase()).join('') || '?'
}

const list = computed(() => r.items.value || [])
const qcList = computed(() => qc.items.value || [])

const departmentOptions = computed(() => {
  const set = new Set(list.value.map(x => x.department).filter(Boolean))
  return [...set].sort()
})
const manufacturerOptions = computed(() => {
  const set = new Set(list.value.map(x => x.manufacturer).filter(Boolean))
  return [...set].sort()
})

const statusPills = computed(() => {
  const arr = list.value
  return STATUS_PILLS.map(s => ({
    ...s,
    count: s.value == null ? arr.length : arr.filter(x => x.status === s.value).length,
  }))
})

const deptChips = computed(() => {
  const counts = list.value.reduce((acc, x) => {
    if (x.department) acc[x.department] = (acc[x.department] || 0) + 1
    return acc
  }, {})
  const tops = Object.entries(counts).sort((a, b) => b[1] - a[1]).slice(0, 5)
    .map(([d, n]) => ({ label: d, value: d, count: n }))
  return [{ label: 'All depts', value: null }, ...tops]
})

function daysUntil (d) {
  if (!d) return null
  const t = new Date(d)
  if (isNaN(t)) return null
  const today = new Date(); today.setHours(0, 0, 0, 0)
  return Math.round((t - today) / 86400000)
}
function serviceUrgency (i) {
  const dd = daysUntil(i.next_service_date)
  if (dd == null) return null
  if (dd < 0) return 'overdue'
  if (dd <= 14) return 'soon'
  return 'scheduled'
}
function serviceLabel (i) {
  const dd = daysUntil(i.next_service_date)
  if (dd == null) return 'No schedule'
  if (dd < 0) return `Overdue ${Math.abs(dd)}d`
  if (dd === 0) return 'Due today'
  if (dd <= 14) return `Due in ${dd}d`
  return `In ${dd}d`
}
function serviceClass (i) {
  const u = serviceUrgency(i)
  if (u === 'overdue') return 'text-error font-weight-bold'
  if (u === 'soon') return 'text-warning font-weight-bold'
  if (u === 'scheduled') return 'text-success'
  return 'text-medium-emphasis'
}

const filtered = computed(() => {
  let arr = r.filtered.value || []
  if (statusFilter.value) arr = arr.filter(x => x.status === statusFilter.value)
  if (deptFilter.value) arr = arr.filter(x => x.department === deptFilter.value)
  if (serviceFilter.value) arr = arr.filter(x => (serviceUrgency(x) || 'none') === serviceFilter.value)
  arr = [...arr]
  switch (sortBy.value) {
    case 'name_desc': arr.sort((a, b) => (b.name || '').localeCompare(a.name || '')); break
    case 'service_soon':
      arr.sort((a, b) => {
        const da = daysUntil(a.next_service_date); const db = daysUntil(b.next_service_date)
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

const serviceDueList = computed(() =>
  list.value.filter(i => ['overdue', 'soon'].includes(serviceUrgency(i)))
    .sort((a, b) => daysUntil(a.next_service_date) - daysUntil(b.next_service_date))
)

const kpis = computed(() => {
  const arr = list.value
  return [
    { label: 'Total', value: arr.length, icon: 'mdi-cog-transfer', color: 'indigo',
      hint: `${departmentOptions.value.length} depts` },
    { label: 'Active', value: arr.filter(x => x.status === 'active').length,
      icon: 'mdi-check-circle', color: 'green', hint: `${arr.filter(x => x.is_active).length} enabled` },
    { label: 'Maintenance', value: arr.filter(x => x.status === 'maintenance' || x.status === 'offline').length,
      icon: 'mdi-wrench', color: 'amber', hint: 'maint + offline' },
    { label: 'Service due', value: serviceDueList.value.length,
      icon: 'mdi-wrench-clock', color: 'red', hint: 'overdue + ≤14d' },
  ]
})

// QC linkage helpers
const qcCountByInstrument = computed(() => {
  const m = {}
  for (const q of qcList.value) m[q.instrument] = (m[q.instrument] || 0) + 1
  return m
})
function qcCountFor (id) { return qcCountByInstrument.value[id] || 0 }
function qcRunsFor (id) {
  return qcList.value.filter(q => q.instrument === id)
    .sort((a, b) => new Date(b.run_at) - new Date(a.run_at))
}
function qcResultColor (r) { return { pass: 'success', warn: 'warning', fail: 'error' }[r] || 'grey' }
function qcResultIcon (r) {
  return { pass: 'mdi-check', warn: 'mdi-alert', fail: 'mdi-close' }[r] || 'mdi-help'
}
function sdClass (s) {
  if (s == null) return 'text-medium-emphasis'
  const v = Math.abs(Number(s))
  if (v >= 3) return 'text-error font-weight-bold'
  if (v >= 2) return 'text-warning font-weight-bold'
  return 'text-success'
}

function statusLabel (s) { return STATUSES.find(x => x.value === s)?.title || s || '—' }
function statusColor (s) {
  return { active: 'success', maintenance: 'warning', offline: 'error', retired: 'grey' }[s] || 'grey'
}
function statusIcon (s) {
  return {
    active: 'mdi-check-circle', maintenance: 'mdi-wrench',
    offline: 'mdi-power-plug-off', retired: 'mdi-archive',
  }[s] || 'mdi-circle-outline'
}
function statusHex (s) {
  return { active: '#43a047', maintenance: '#fb8c00', offline: '#e53935', retired: '#9e9e9e' }[s] || '#9e9e9e'
}

function emptyForm () {
  return {
    id: null, name: '', serial_no: '', manufacturer: '', model: '',
    department: '', status: 'active', location: '',
    last_service_date: null, next_service_date: null,
    notes: '', is_active: true,
  }
}
const required = v => (v !== null && v !== undefined && v !== '') || 'Required'

function formatDate (s) {
  if (!s) return '—'
  return new Date(s).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })
}

function openNew () { form.value = emptyForm(); formDialog.value = true }
function openEdit (it) {
  form.value = { ...emptyForm(), ...it }
  detailDialog.value = false
  formDialog.value = true
}
function openDetail (it) { detailItem.value = it; detailDialog.value = true }
function duplicate (it) {
  form.value = { ...emptyForm(), ...it, id: null, name: `${it.name} (copy)`, serial_no: '' }
  formDialog.value = true
}
function goToQc (it) {
  router.push({ path: '/lab/qc', query: { instrument: it.id } })
}

async function save () {
  const { valid } = (await formRef.value?.validate?.()) || { valid: true }
  if (!valid) return
  try {
    const payload = { ...form.value }
    if (!payload.last_service_date) payload.last_service_date = null
    if (!payload.next_service_date) payload.next_service_date = null
    if (payload.id) await r.update(payload.id, payload)
    else await r.create(payload)
    formDialog.value = false
    notify(`Instrument ${form.value.id ? 'updated' : 'created'} successfully`)
    await r.list()
  } catch (e) { notify(r.error.value || 'Save failed', 'error') }
}

async function markServiced (it) {
  try {
    const today = new Date().toISOString().slice(0, 10)
    // default next service = +90d if no schedule
    let next = it.next_service_date
    if (!next || daysUntil(next) <= 0) {
      const d = new Date(); d.setDate(d.getDate() + 90)
      next = d.toISOString().slice(0, 10)
    }
    await r.update(it.id, { ...it, last_service_date: today, next_service_date: next })
    notify(`Marked serviced today · next due ${formatDate(next)}`)
    await r.list()
  } catch (e) { notify(r.error.value || 'Update failed', 'error') }
}

function confirmDelete (it) { deleteDialog.item = it; deleteDialog.show = true }
async function doDelete () {
  deleteDialog.busy = true
  try {
    await r.remove(deleteDialog.item.id)
    notify('Instrument deleted')
    deleteDialog.show = false
    detailDialog.value = false
  } catch (e) { notify(r.error.value || 'Delete failed', 'error') }
  finally { deleteDialog.busy = false }
}

async function bulkSetStatus (status) {
  bulkBusy.value = true
  try {
    await Promise.all(selected.value.map(id => {
      const it = list.value.find(x => x.id === id)
      return it ? r.update(id, { ...it, status }) : null
    }))
    notify(`${selected.value.length} instrument(s) set to ${status}`)
    selected.value = []
    await r.list()
  } catch (e) { notify(r.error.value || 'Bulk update failed', 'error') }
  finally { bulkBusy.value = false }
}
async function bulkActivate (active) {
  bulkBusy.value = true
  try {
    await Promise.all(selected.value.map(id => {
      const it = list.value.find(x => x.id === id)
      return it ? r.update(id, { ...it, is_active: active }) : null
    }))
    notify(`${selected.value.length} instrument(s) ${active ? 'activated' : 'deactivated'}`)
    selected.value = []
    await r.list()
  } catch (e) { notify(r.error.value || 'Bulk update failed', 'error') }
  finally { bulkBusy.value = false }
}
async function bulkDelete () {
  if (!confirm(`Delete ${selected.value.length} instrument(s)? This may also remove linked QC runs.`)) return
  bulkBusy.value = true
  try {
    await Promise.all(selected.value.map(id => r.remove(id)))
    notify(`${selected.value.length} instrument(s) deleted`)
    selected.value = []
  } catch (e) { notify(r.error.value || 'Bulk delete failed', 'error') }
  finally { bulkBusy.value = false }
}

function resetFilters () {
  statusFilter.value = null
  deptFilter.value = null
  serviceFilter.value = null
  sortBy.value = 'name_asc'
  r.search.value = ''
}
function reload () { r.list(); qc.list() }
function notify (text, color = 'success') { snack.text = text; snack.color = color; snack.show = true }

function exportCsv () {
  const rows = filtered.value
  if (!rows.length) return
  const cols = ['name', 'serial_no', 'manufacturer', 'model', 'department',
    'status', 'location', 'last_service_date', 'next_service_date', 'is_active', 'notes']
  const esc = v => `"${String(v ?? '').replace(/"/g, '""')}"`
  const body = rows.map(it => cols.map(c => esc(it[c])).join(',')).join('\n')
  const blob = new Blob([cols.join(',') + '\n' + body], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `lab-instruments_${new Date().toISOString().slice(0, 10)}.csv`
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
  const out = []
  let cur = ''; let inQ = false
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
          name: row.name || row.Name || '',
          serial_no: row.serial_no || '',
          manufacturer: row.manufacturer || '',
          model: row.model || '',
          department: row.department || '',
          status: row.status || 'active',
          location: row.location || '',
          last_service_date: row.last_service_date || null,
          next_service_date: row.next_service_date || null,
          notes: row.notes || '',
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
  w.document.write(`
    <html><head><title>${i.name} · Spec Sheet</title>
    <style>
      body{font-family:Arial,sans-serif;padding:32px;color:#222}
      h1{margin:0 0 4px;font-size:22px}
      .muted{color:#666;font-size:12px}
      table{width:100%;border-collapse:collapse;margin-top:12px}
      th,td{border-bottom:1px solid #eee;padding:8px;text-align:left;font-size:13px}
      th{width:30%}
      .badge{display:inline-block;padding:2px 8px;border-radius:6px;font-size:12px;color:#fff;background:#3949ab}
    </style></head><body>
      <h1>${i.name}</h1>
      <div class="muted">${[i.manufacturer, i.model].filter(Boolean).join(' · ') || ''}</div>
      <p><span class="badge">${statusLabel(i.status)}</span></p>
      <table>
        <tr><th>Serial No.</th><td>${i.serial_no || '—'}</td></tr>
        <tr><th>Department</th><td>${i.department || '—'}</td></tr>
        <tr><th>Location</th><td>${i.location || '—'}</td></tr>
        <tr><th>Last service</th><td>${formatDate(i.last_service_date)}</td></tr>
        <tr><th>Next service</th><td>${formatDate(i.next_service_date)} (${serviceLabel(i)})</td></tr>
        <tr><th>Active</th><td>${i.is_active ? 'Yes' : 'No'}</td></tr>
        <tr><th>Registered</th><td>${formatDate(i.created_at)}</td></tr>
      </table>
      ${i.notes ? `<h3>Notes</h3><p>${i.notes}</p>` : ''}
    </body></html>`)
  w.document.close()
  w.print()
}

onMounted(() => { r.list(); qc.list() })
</script>

<style scoped>
.kpi { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.inst-table :deep(tbody tr) { cursor: pointer; }
.inst-card {
  position: relative;
  overflow: hidden;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  cursor: pointer;
  transition: transform 120ms ease, box-shadow 120ms ease;
}
.inst-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.06); }
.inst-band { position: absolute; top: 0; left: 0; right: 0; height: 3px; }
.bulk-bar {
  border: 1px solid rgba(var(--v-theme-primary), 0.2);
  background: rgba(var(--v-theme-primary), 0.04);
}
.min-width-0 { min-width: 0; }
.font-monospace { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
.cursor-pointer { cursor: pointer; }
</style>
