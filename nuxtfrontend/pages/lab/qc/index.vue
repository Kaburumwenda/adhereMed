<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="indigo-lighten-5" size="48">
        <v-icon color="indigo-darken-2" size="28">mdi-chart-bell-curve-cumulative</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Quality Control</div>
        <div class="text-body-2 text-medium-emphasis">
          Daily QC runs · Westgard rules · Levey-Jennings tracking
        </div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh"
             :loading="r.loading.value" @click="reload">Refresh</v-btn>
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-chart-line"
             @click="chartDialog = true">L-J Chart</v-btn>
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-tray-arrow-down"
             @click="exportCsv">Export</v-btn>
      <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openNew">Log QC Run</v-btn>
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
          v-for="s in statusFilters" :key="s.key"
          :color="statusFilter === s.value ? (s.color || 'primary') : undefined"
          :variant="statusFilter === s.value ? 'flat' : 'tonal'"
          size="small" @click="statusFilter = s.value"
        >
          <v-icon v-if="s.icon" size="14" start>{{ s.icon }}</v-icon>
          {{ s.label }}<span class="ml-2 font-weight-bold">{{ s.count }}</span>
        </v-chip>

        <v-divider vertical class="mx-2" />

        <v-chip
          v-for="i in topInstrumentChips" :key="i.value || 'all-inst'"
          :color="instrumentFilter === i.value ? 'indigo' : undefined"
          :variant="instrumentFilter === i.value ? 'flat' : 'tonal'"
          size="small" @click="instrumentFilter = i.value"
        >
          <v-icon size="14" start>mdi-cog-transfer</v-icon>
          {{ i.label }}
          <span v-if="i.count != null" class="ml-2 font-weight-bold">{{ i.count }}</span>
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
        <v-col cols="12" md="3">
          <v-text-field
            v-model="r.search.value"
            prepend-inner-icon="mdi-magnify"
            placeholder="Search by lot, level…"
            variant="outlined" density="compact" hide-details clearable
          />
        </v-col>
        <v-col cols="6" md="2">
          <v-autocomplete v-model="testFilter" :items="catalog" item-title="name" item-value="id"
                          label="Test" prepend-inner-icon="mdi-flask-outline"
                          variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="dateFilter" :items="dateOptions"
                    label="Date" prepend-inner-icon="mdi-calendar"
                    variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="levelFilter" :items="levelFilterOptions"
                    label="Level" prepend-inner-icon="mdi-thermometer-lines"
                    variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="sortBy" :items="sortOptions"
                    label="Sort" prepend-inner-icon="mdi-sort"
                    variant="outlined" density="compact" hide-details />
        </v-col>
        <v-col cols="12" md="1" class="d-flex justify-end">
          <v-btn variant="text" size="small" @click="resetFilters">
            <v-icon start size="16">mdi-filter-remove-outline</v-icon>
          </v-btn>
        </v-col>
      </v-row>
    </v-card>

    <!-- Westgard alert ribbon -->
    <v-slide-y-transition>
      <v-alert v-if="westgardAlerts.length" type="warning" variant="tonal"
               class="mt-3" prominent rounded="lg" icon="mdi-alert-decagram">
        <div class="font-weight-bold">Westgard rule violations detected</div>
        <div class="text-body-2">
          {{ westgardAlerts.length }} recent run(s) flagged.
          <span v-for="(w, i) in westgardAlerts.slice(0, 3)" :key="i" class="mr-2">
            <v-chip size="x-small" color="warning" variant="flat" class="ml-1">{{ w.rule }}</v-chip>
            {{ w.test_name }} · {{ w.instrument_name }}
          </span>
        </div>
      </v-alert>
    </v-slide-y-transition>

    <!-- Bulk action bar -->
    <v-slide-y-transition>
      <v-card v-if="selected.length" flat rounded="lg" class="mt-3 pa-3 bulk-bar">
        <div class="d-flex align-center ga-2">
          <v-icon color="primary">mdi-check-all</v-icon>
          <span class="font-weight-medium">{{ selected.length }} selected</span>
          <v-spacer />
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
        class="qc-table"
        @click:row="(_, { item }) => openDetail(item)"
      >
        <template #loading><v-skeleton-loader type="table-row@5" /></template>
        <template #item.run_at="{ value }">
          <div class="d-flex flex-column">
            <span class="text-caption font-weight-medium">{{ formatDate(value) }}</span>
            <span class="text-caption text-medium-emphasis">{{ formatTime(value) }}</span>
          </div>
        </template>
        <template #item.test_name="{ item }">
          <div class="d-flex align-center">
            <v-avatar color="indigo-lighten-5" size="30" class="mr-2">
              <v-icon size="14" color="indigo-darken-2">mdi-flask</v-icon>
            </v-avatar>
            <div class="min-width-0">
              <div class="font-weight-medium text-truncate">{{ item.test_name }}</div>
              <div class="text-caption text-medium-emphasis text-truncate">
                {{ item.instrument_name }}
              </div>
            </div>
          </div>
        </template>
        <template #item.qc_level="{ value }">
          <v-chip v-if="value" :color="levelColor(value)" size="x-small" variant="tonal" class="text-capitalize">
            {{ value }}
          </v-chip>
          <span v-else class="text-medium-emphasis text-caption">—</span>
        </template>
        <template #item.lot_number="{ value }">
          <span v-if="value" class="font-monospace text-caption">{{ value }}</span>
          <span v-else class="text-medium-emphasis text-caption">—</span>
        </template>
        <template #item.expected_value="{ value }">
          <span class="font-monospace text-caption">{{ value || '—' }}</span>
        </template>
        <template #item.measured_value="{ item }">
          <div class="d-flex flex-column align-end">
            <span class="font-monospace text-caption font-weight-bold">{{ item.measured_value || '—' }}</span>
            <span v-if="deviation(item) != null" class="text-caption" :class="deviationClass(item)">
              {{ deviation(item) > 0 ? '+' : '' }}{{ deviation(item).toFixed(2) }}
            </span>
          </div>
        </template>
        <template #item.sd="{ value }">
          <div class="d-flex align-center justify-end ga-1">
            <span class="font-monospace text-caption" :class="sdClass(value)">
              {{ value != null ? Number(value).toFixed(2) + ' SD' : '—' }}
            </span>
            <v-icon v-if="value != null && Math.abs(Number(value)) >= 3" size="14" color="error">mdi-alert</v-icon>
          </div>
        </template>
        <template #item.result="{ value }">
          <v-chip :color="resultColor(value)" size="small" variant="flat" class="text-capitalize">
            <v-icon size="14" start>{{ resultIcon(value) }}</v-icon>
            {{ value }}
          </v-chip>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end" @click.stop>
            <v-tooltip text="Trend chart" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-chart-line-variant" variant="text" size="small"
                       color="primary" @click="openChartFor(item)" />
              </template>
            </v-tooltip>
            <v-tooltip text="View" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-eye-outline" variant="text" size="small"
                       @click="openDetail(item)" />
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
                <v-list-item prepend-icon="mdi-printer-outline" title="Print run" @click="printRun(item)" />
                <v-divider />
                <v-list-item prepend-icon="mdi-delete" title="Delete" base-color="error"
                             @click="confirmDelete(item)" />
              </v-list>
            </v-menu>
          </div>
        </template>
        <template #no-data>
          <div class="pa-8 text-center">
            <v-icon size="56" color="grey-lighten-1">mdi-chart-bell-curve</v-icon>
            <div class="text-subtitle-1 font-weight-medium mt-2">No QC runs found</div>
            <div class="text-body-2 text-medium-emphasis mb-4">
              Adjust your filters or log a new QC run.
            </div>
            <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openNew">Log QC Run</v-btn>
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
        <v-icon size="56" color="grey-lighten-1">mdi-chart-bell-curve</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-2">No QC runs found</div>
        <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" class="mt-3" @click="openNew">Log QC Run</v-btn>
      </div>
      <v-row v-else dense>
        <v-col v-for="q in filtered" :key="q.id" cols="12" sm="6" md="4" lg="3">
          <v-card flat rounded="lg" class="qc-card pa-3 h-100" hover @click="openDetail(q)">
            <div class="qc-band" :style="{ background: resultHex(q.result) }" />
            <div class="d-flex align-center mb-2">
              <v-chip :color="resultColor(q.result)" size="x-small" variant="flat" class="text-capitalize">
                <v-icon size="12" start>{{ resultIcon(q.result) }}</v-icon>{{ q.result }}
              </v-chip>
              <v-spacer />
              <span class="text-caption text-medium-emphasis">{{ formatDate(q.run_at) }}</span>
            </div>
            <div class="d-flex align-center">
              <v-avatar color="indigo-lighten-5" size="36" class="mr-3">
                <v-icon size="18" color="indigo-darken-2">mdi-flask</v-icon>
              </v-avatar>
              <div class="min-width-0 flex-grow-1">
                <div class="font-weight-medium text-truncate">{{ q.test_name }}</div>
                <div class="text-caption text-medium-emphasis text-truncate">
                  {{ q.instrument_name }}
                </div>
              </div>
            </div>
            <v-divider class="my-3" />
            <div class="d-flex justify-space-between text-caption mb-1">
              <span class="text-medium-emphasis">Level</span>
              <span class="font-weight-medium text-capitalize">{{ q.qc_level || '—' }}</span>
            </div>
            <div class="d-flex justify-space-between text-caption mb-1">
              <span class="text-medium-emphasis">Lot</span>
              <span class="font-monospace">{{ q.lot_number || '—' }}</span>
            </div>
            <div class="d-flex justify-space-between text-caption mb-1">
              <span class="text-medium-emphasis">Expected / Measured</span>
              <span class="font-monospace font-weight-medium">
                {{ q.expected_value || '—' }} / {{ q.measured_value || '—' }}
              </span>
            </div>
            <div class="d-flex justify-space-between text-caption">
              <span class="text-medium-emphasis">Deviation</span>
              <span class="font-monospace" :class="sdClass(q.sd)">
                {{ q.sd != null ? Number(q.sd).toFixed(2) + ' SD' : '—' }}
              </span>
            </div>
          </v-card>
        </v-col>
      </v-row>
    </div>

    <!-- Create / Edit dialog -->
    <v-dialog v-model="formDialog" max-width="780" scrollable persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="indigo-lighten-5" size="40" class="mr-3">
            <v-icon color="indigo-darken-2">{{ form.id ? 'mdi-pencil' : 'mdi-plus' }}</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">QC RUN</div>
            <div class="text-h6 font-weight-bold">{{ form.id ? 'Edit QC run' : 'Log QC run' }}</div>
          </div>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" @click="formDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          <v-form ref="formRef" @submit.prevent="save">
            <v-row dense>
              <v-col cols="12" sm="6">
                <v-autocomplete v-model="form.instrument" :items="instruments" :loading="inst.loading.value"
                                item-title="name" item-value="id"
                                label="Instrument *" prepend-inner-icon="mdi-cog-transfer"
                                variant="outlined" density="comfortable" :rules="[required]" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-autocomplete v-model="form.test" :items="catalog" :loading="cat.loading.value"
                                item-title="name" item-value="id"
                                label="Test *" prepend-inner-icon="mdi-flask-outline"
                                variant="outlined" density="comfortable" :rules="[required]" />
              </v-col>
              <v-col cols="6" sm="3">
                <v-select v-model="form.qc_level" :items="levels"
                          label="QC level" prepend-inner-icon="mdi-thermometer-lines"
                          variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="6" sm="3">
                <v-text-field v-model="form.lot_number" label="Lot No."
                              prepend-inner-icon="mdi-barcode"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="6" sm="3">
                <v-text-field v-model.number="form.expected_value" type="number" step="0.01"
                              label="Expected" prepend-inner-icon="mdi-target"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="6" sm="3">
                <v-text-field v-model.number="form.measured_value" type="number" step="0.01"
                              label="Measured *" prepend-inner-icon="mdi-bullseye-arrow"
                              variant="outlined" density="comfortable" :rules="[required]" />
              </v-col>
              <v-col cols="6" sm="4">
                <v-text-field v-model.number="form.sd" type="number" step="0.01"
                              label="Std deviations" prepend-inner-icon="mdi-sigma"
                              hint="Auto-fills the result by Westgard"
                              persistent-hint
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="6" sm="4">
                <v-select v-model="form.result" :items="results"
                          label="Result" prepend-inner-icon="mdi-check-decagram"
                          variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" sm="4" class="d-flex align-center">
                <v-chip v-if="autoSuggestion" :color="resultColor(autoSuggestion)" variant="tonal" size="small">
                  <v-icon start size="14">mdi-auto-fix</v-icon>
                  Suggested: {{ autoSuggestion }}
                </v-chip>
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="form.comments" label="Comments / corrective action" rows="2" auto-grow
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
            <v-icon start>mdi-content-save</v-icon>{{ form.id ? 'Update Run' : 'Save Run' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Detail dialog -->
    <v-dialog v-model="detailDialog" max-width="780" scrollable>
      <v-card v-if="detailItem" rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar :color="resultColor(detailItem.result)" size="44" class="mr-3">
            <v-icon color="white" size="22">{{ resultIcon(detailItem.result) }}</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">{{ detailItem.test_name }}</div>
            <div class="text-h6 font-weight-bold">{{ detailItem.instrument_name }}</div>
          </div>
          <v-spacer />
          <v-chip :color="resultColor(detailItem.result)" size="small" variant="flat" class="mr-2 text-capitalize">
            {{ detailItem.result }}
          </v-chip>
          <v-btn icon="mdi-close" variant="text" @click="detailDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          <v-row dense>
            <v-col cols="6" sm="3">
              <div class="text-caption text-medium-emphasis">Level</div>
              <div class="font-weight-medium text-capitalize">{{ detailItem.qc_level || '—' }}</div>
            </v-col>
            <v-col cols="6" sm="3">
              <div class="text-caption text-medium-emphasis">Lot</div>
              <div class="font-monospace">{{ detailItem.lot_number || '—' }}</div>
            </v-col>
            <v-col cols="6" sm="3">
              <div class="text-caption text-medium-emphasis">Expected</div>
              <div class="font-monospace">{{ detailItem.expected_value || '—' }}</div>
            </v-col>
            <v-col cols="6" sm="3">
              <div class="text-caption text-medium-emphasis">Measured</div>
              <div class="font-monospace font-weight-bold">{{ detailItem.measured_value || '—' }}</div>
            </v-col>
            <v-col cols="6" sm="3">
              <div class="text-caption text-medium-emphasis">Deviation</div>
              <div class="font-monospace" :class="sdClass(detailItem.sd)">
                {{ detailItem.sd != null ? Number(detailItem.sd).toFixed(2) + ' SD' : '—' }}
              </div>
            </v-col>
            <v-col cols="6" sm="3">
              <div class="text-caption text-medium-emphasis">Performed by</div>
              <div>{{ detailItem.performed_by_name || '—' }}</div>
            </v-col>
            <v-col cols="12" sm="6">
              <div class="text-caption text-medium-emphasis">Run at</div>
              <div>{{ formatDateTime(detailItem.run_at) }}</div>
            </v-col>
            <v-col v-if="detailItem.comments" cols="12">
              <v-divider class="my-2" />
              <div class="text-caption text-medium-emphasis mb-1">Comments</div>
              <div>{{ detailItem.comments }}</div>
            </v-col>
          </v-row>

          <v-divider class="my-4" />
          <div class="d-flex align-center mb-2">
            <v-icon color="indigo" class="mr-2">mdi-chart-line-variant</v-icon>
            <span class="text-subtitle-2 font-weight-bold">Levey-Jennings (last 20 runs)</span>
          </div>
          <LjChart :runs="ljRunsFor(detailItem)" />

          <div v-if="westgardForDetail.length" class="mt-3">
            <v-alert type="warning" variant="tonal" density="compact" rounded="lg">
              <div class="font-weight-bold mb-1">Westgard rules triggered</div>
              <div class="d-flex flex-wrap ga-1">
                <v-chip v-for="(w, i) in westgardForDetail" :key="i" size="x-small"
                        color="warning" variant="flat">{{ w }}</v-chip>
              </div>
            </v-alert>
          </div>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-btn variant="text" prepend-icon="mdi-content-copy" @click="duplicate(detailItem)">Duplicate</v-btn>
          <v-btn variant="text" prepend-icon="mdi-printer-outline" @click="printRun(detailItem)">Print</v-btn>
          <v-spacer />
          <v-btn variant="text" @click="detailDialog = false">Close</v-btn>
          <v-btn color="primary" rounded="lg" prepend-icon="mdi-pencil" @click="openEdit(detailItem)">Edit</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Standalone L-J chart dialog -->
    <v-dialog v-model="chartDialog" max-width="900" scrollable>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-icon color="indigo" class="mr-2">mdi-chart-line</v-icon>
          Levey-Jennings Chart
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" @click="chartDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          <v-row dense>
            <v-col cols="12" sm="5">
              <v-autocomplete v-model="chartTest" :items="catalog" item-title="name" item-value="id"
                              label="Test" prepend-inner-icon="mdi-flask-outline"
                              variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" sm="5">
              <v-autocomplete v-model="chartInstrument" :items="instruments" item-title="name" item-value="id"
                              label="Instrument" prepend-inner-icon="mdi-cog-transfer"
                              variant="outlined" density="comfortable" clearable />
            </v-col>
            <v-col cols="12" sm="2">
              <v-text-field v-model="chartLot" label="Lot (opt.)" variant="outlined" density="comfortable" />
            </v-col>
          </v-row>
          <LjChart :runs="ljChartRuns" :height="280" />
          <div class="mt-3 d-flex align-center ga-2 flex-wrap">
            <v-chip size="x-small" color="success" variant="tonal">Pass {{ ljStats.pass }}</v-chip>
            <v-chip size="x-small" color="warning" variant="tonal">Warn {{ ljStats.warn }}</v-chip>
            <v-chip size="x-small" color="error" variant="tonal">Fail {{ ljStats.fail }}</v-chip>
            <v-divider vertical class="mx-2" />
            <v-chip size="x-small" variant="tonal">Mean SD {{ ljStats.meanSd }}</v-chip>
            <v-chip size="x-small" variant="tonal">CV {{ ljStats.cv }}%</v-chip>
            <v-chip size="x-small" variant="tonal">{{ ljStats.count }} runs</v-chip>
          </div>
        </v-card-text>
      </v-card>
    </v-dialog>

    <!-- Delete confirm -->
    <v-dialog v-model="deleteDialog.show" max-width="420" persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center">
          <v-icon color="error" class="mr-2">mdi-alert-circle</v-icon>Delete QC Run
        </v-card-title>
        <v-card-text>
          Delete this QC run for <strong>{{ deleteDialog.item?.test_name }}</strong>?
          This cannot be undone and may affect audit trails.
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

const r = useResource('/lab/qc/')
const inst = useResource('/lab/instruments/')
const cat = useResource('/lab/catalog/')

const view = ref('table')
const statusFilter = ref(null)
const instrumentFilter = ref(null)
const testFilter = ref(null)
const levelFilter = ref(null)
const dateFilter = ref('30d')
const sortBy = ref('newest')
const selected = ref([])
const bulkBusy = ref(false)

const formDialog = ref(false)
const formRef = ref(null)
const form = ref(emptyForm())
const detailDialog = ref(false)
const detailItem = ref(null)
const deleteDialog = reactive({ show: false, item: null, busy: false })
const snack = reactive({ show: false, color: 'success', text: '' })

const chartDialog = ref(false)
const chartTest = ref(null)
const chartInstrument = ref(null)
const chartLot = ref('')

const levels = [
  { title: 'Low', value: 'low' },
  { title: 'Normal', value: 'normal' },
  { title: 'High', value: 'high' },
]
const levelFilterOptions = levels
const results = [
  { title: 'Pass', value: 'pass' },
  { title: 'Warning', value: 'warn' },
  { title: 'Fail', value: 'fail' },
]
const dateOptions = [
  { title: 'Today', value: 'today' },
  { title: 'Last 7 days', value: '7d' },
  { title: 'Last 30 days', value: '30d' },
  { title: 'Last 90 days', value: '90d' },
  { title: 'All time', value: null },
]
const sortOptions = [
  { title: 'Newest', value: 'newest' },
  { title: 'Oldest', value: 'oldest' },
  { title: '|SD| (high → low)', value: 'sd_desc' },
  { title: 'Test (A → Z)', value: 'test_asc' },
]

const headers = [
  { title: 'When', key: 'run_at', width: 120 },
  { title: 'Test / Instrument', key: 'test_name' },
  { title: 'Level', key: 'qc_level', width: 90 },
  { title: 'Lot', key: 'lot_number', width: 110 },
  { title: 'Expected', key: 'expected_value', align: 'end', width: 100 },
  { title: 'Measured', key: 'measured_value', align: 'end', width: 110 },
  { title: 'Deviation', key: 'sd', align: 'end', width: 110 },
  { title: 'Result', key: 'result', width: 110 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 170 },
]

const STATUS_FILTERS = [
  { label: 'All', value: null, key: 'all', icon: 'mdi-dots-grid' },
  { label: 'Pass', value: 'pass', key: 'pass', color: 'success', icon: 'mdi-check-decagram' },
  { label: 'Warning', value: 'warn', key: 'warn', color: 'warning', icon: 'mdi-alert' },
  { label: 'Fail', value: 'fail', key: 'fail', color: 'error', icon: 'mdi-close-octagon' },
  { label: 'Today', value: 'today', key: 'today', icon: 'mdi-calendar-today' },
]

// ─── Lists ───
const list = computed(() => r.items.value || [])
const instruments = computed(() => inst.items.value || [])
const catalog = computed(() => cat.items.value || [])

const statusFilters = computed(() => {
  const arr = list.value
  const todayStr = new Date().toDateString()
  const counts = {
    all: arr.length,
    pass: arr.filter(x => x.result === 'pass').length,
    warn: arr.filter(x => x.result === 'warn').length,
    fail: arr.filter(x => x.result === 'fail').length,
    today: arr.filter(x => new Date(x.run_at).toDateString() === todayStr).length,
  }
  return STATUS_FILTERS.map(s => ({ ...s, count: counts[s.key] }))
})

const topInstrumentChips = computed(() => {
  const counts = list.value.reduce((acc, x) => {
    if (x.instrument) acc[x.instrument] = (acc[x.instrument] || 0) + 1
    return acc
  }, {})
  const tops = Object.entries(counts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([id, n]) => {
      const ins = instruments.value.find(i => i.id === Number(id))
      return { label: ins?.name || `#${id}`, value: Number(id), count: n }
    })
  return [{ label: 'All instruments', value: null }, ...tops]
})

function inDateRange (dt) {
  if (!dateFilter.value) return true
  const d = new Date(dt)
  const now = new Date()
  if (dateFilter.value === 'today') return d.toDateString() === now.toDateString()
  const days = { '7d': 7, '30d': 30, '90d': 90 }[dateFilter.value]
  if (!days) return true
  return (now - d) / 86400000 <= days
}

const filtered = computed(() => {
  let arr = r.filtered.value || []
  if (statusFilter.value === 'pass') arr = arr.filter(x => x.result === 'pass')
  else if (statusFilter.value === 'warn') arr = arr.filter(x => x.result === 'warn')
  else if (statusFilter.value === 'fail') arr = arr.filter(x => x.result === 'fail')
  else if (statusFilter.value === 'today') {
    const t = new Date().toDateString()
    arr = arr.filter(x => new Date(x.run_at).toDateString() === t)
  }
  if (instrumentFilter.value) arr = arr.filter(x => x.instrument === instrumentFilter.value)
  if (testFilter.value) arr = arr.filter(x => x.test === testFilter.value)
  if (levelFilter.value) arr = arr.filter(x => x.qc_level === levelFilter.value)
  if (dateFilter.value) arr = arr.filter(x => inDateRange(x.run_at))
  arr = [...arr]
  switch (sortBy.value) {
    case 'oldest': arr.sort((a, b) => new Date(a.run_at) - new Date(b.run_at)); break
    case 'sd_desc': arr.sort((a, b) => Math.abs(Number(b.sd || 0)) - Math.abs(Number(a.sd || 0))); break
    case 'test_asc': arr.sort((a, b) => (a.test_name || '').localeCompare(b.test_name || '')); break
    default: arr.sort((a, b) => new Date(b.run_at) - new Date(a.run_at))
  }
  return arr
})

const kpis = computed(() => {
  const arr = list.value
  const total = arr.length
  const pass = arr.filter(x => x.result === 'pass').length
  const fail = arr.filter(x => x.result === 'fail').length
  const warn = arr.filter(x => x.result === 'warn').length
  const passRate = total ? Math.round((pass / total) * 100) : 0
  const todayStr = new Date().toDateString()
  const today = arr.filter(x => new Date(x.run_at).toDateString() === todayStr).length
  return [
    { label: 'Total Runs', value: total, icon: 'mdi-chart-bell-curve-cumulative', color: 'indigo',
      hint: `${today} today` },
    { label: 'Pass Rate', value: `${passRate}%`, icon: 'mdi-check-decagram', color: 'success',
      hint: `${pass} pass` },
    { label: 'Warnings', value: warn, icon: 'mdi-alert-decagram', color: 'amber',
      hint: 'review trends' },
    { label: 'Failures', value: fail, icon: 'mdi-close-octagon', color: 'red',
      hint: 'corrective action' },
  ]
})

// ─── Westgard rules ───
// Evaluate rules on a sequence of runs (ordered oldest→newest) for a single test+instrument.
function evaluateWestgard (runs) {
  // Returns array of {idx, rule} where idx is the index of the violating run.
  const out = []
  const sds = runs.map(r => Number(r.sd))
  for (let i = 0; i < runs.length; i++) {
    const v = sds[i]
    if (Number.isNaN(v)) continue
    // 1-3s
    if (Math.abs(v) >= 3) out.push({ idx: i, rule: '1-3s' })
    // 1-2s (warning only — flagged only if next rules below confirm)
    // 2-2s
    if (i >= 1 && Math.abs(v) >= 2 && Math.sign(v) === Math.sign(sds[i - 1]) && Math.abs(sds[i - 1]) >= 2) {
      out.push({ idx: i, rule: '2-2s' })
    }
    // R-4s
    if (i >= 1 && Math.abs(v - sds[i - 1]) >= 4) out.push({ idx: i, rule: 'R-4s' })
    // 4-1s
    if (i >= 3) {
      const last4 = sds.slice(i - 3, i + 1)
      if (last4.every(x => Math.abs(x) >= 1 && Math.sign(x) === Math.sign(v))) {
        out.push({ idx: i, rule: '4-1s' })
      }
    }
    // 10x (10 consecutive on same side of mean)
    if (i >= 9) {
      const last10 = sds.slice(i - 9, i + 1)
      const sign = Math.sign(v)
      if (sign !== 0 && last10.every(x => Math.sign(x) === sign)) {
        out.push({ idx: i, rule: '10x' })
      }
    }
  }
  // Dedupe per index
  const seen = new Set()
  return out.filter(o => {
    const k = `${o.idx}-${o.rule}`
    if (seen.has(k)) return false
    seen.add(k); return true
  })
}

const westgardAlerts = computed(() => {
  // Group runs by test+instrument, eval each, return violations from last 10 runs only
  const groups = {}
  for (const x of list.value) {
    const k = `${x.test}-${x.instrument}`
    if (!groups[k]) groups[k] = []
    groups[k].push(x)
  }
  const out = []
  for (const k in groups) {
    const ordered = [...groups[k]].sort((a, b) => new Date(a.run_at) - new Date(b.run_at))
    const viols = evaluateWestgard(ordered)
    for (const v of viols) {
      const run = ordered[v.idx]
      // Only alerts from last 10 days
      if ((Date.now() - new Date(run.run_at).getTime()) / 86400000 <= 10) {
        out.push({
          rule: v.rule,
          test_name: run.test_name,
          instrument_name: run.instrument_name,
          run_at: run.run_at,
        })
      }
    }
  }
  return out
})

const westgardForDetail = computed(() => {
  if (!detailItem.value) return []
  const runs = ljRunsFor(detailItem.value)
  const viols = evaluateWestgard(runs)
  // Find violations whose run matches detailItem
  const matches = viols.filter(v => runs[v.idx].id === detailItem.value.id)
  return [...new Set(matches.map(m => m.rule))]
})

function ljRunsFor (item) {
  return [...list.value]
    .filter(x => x.test === item.test && x.instrument === item.instrument)
    .sort((a, b) => new Date(a.run_at) - new Date(b.run_at))
    .slice(-20)
}

const ljChartRuns = computed(() => {
  if (!chartTest.value) return []
  let arr = list.value.filter(x => x.test === chartTest.value)
  if (chartInstrument.value) arr = arr.filter(x => x.instrument === chartInstrument.value)
  if (chartLot.value) arr = arr.filter(x => (x.lot_number || '').toLowerCase().includes(chartLot.value.toLowerCase()))
  return arr.sort((a, b) => new Date(a.run_at) - new Date(b.run_at)).slice(-50)
})

const ljStats = computed(() => {
  const a = ljChartRuns.value
  const sds = a.map(x => Number(x.sd)).filter(n => !Number.isNaN(n))
  const meas = a.map(x => Number(x.measured_value)).filter(n => !Number.isNaN(n))
  const mean = meas.length ? meas.reduce((s, x) => s + x, 0) / meas.length : 0
  const sd = meas.length
    ? Math.sqrt(meas.reduce((s, x) => s + (x - mean) ** 2, 0) / meas.length)
    : 0
  const cv = mean ? ((sd / mean) * 100) : 0
  return {
    count: a.length,
    pass: a.filter(x => x.result === 'pass').length,
    warn: a.filter(x => x.result === 'warn').length,
    fail: a.filter(x => x.result === 'fail').length,
    meanSd: sds.length ? (sds.reduce((s, x) => s + x, 0) / sds.length).toFixed(2) : '—',
    cv: cv ? cv.toFixed(2) : '—',
  }
})

// ─── Form / actions ───
function emptyForm () {
  return {
    id: null, instrument: null, test: null, qc_level: 'normal', lot_number: '',
    expected_value: null, measured_value: null, sd: null, result: 'pass', comments: '',
  }
}
const required = v => (v !== null && v !== undefined && v !== '') || 'Required'

const autoSuggestion = computed(() => {
  const sd = Number(form.value.sd)
  if (Number.isNaN(sd) || sd === 0) return null
  if (Math.abs(sd) >= 3) return 'fail'
  if (Math.abs(sd) >= 2) return 'warn'
  return 'pass'
})
watch(autoSuggestion, (v) => { if (v && !form.value.id) form.value.result = v })

function levelColor (l) { return { low: 'cyan', normal: 'green', high: 'red' }[l] || 'grey' }
function resultColor (r) { return { pass: 'success', warn: 'warning', fail: 'error' }[r] || 'grey' }
function resultIcon (r) {
  return { pass: 'mdi-check-decagram', warn: 'mdi-alert', fail: 'mdi-close-octagon' }[r] || 'mdi-help-circle'
}
function resultHex (r) { return { pass: '#43a047', warn: '#fb8c00', fail: '#e53935' }[r] || '#9e9e9e' }
function sdClass (s) {
  if (s == null) return 'text-medium-emphasis'
  const v = Math.abs(Number(s))
  if (v >= 3) return 'text-error font-weight-bold'
  if (v >= 2) return 'text-warning font-weight-bold'
  if (v >= 1) return 'text-amber-darken-2'
  return 'text-success'
}
function deviation (item) {
  const e = Number(item.expected_value)
  const m = Number(item.measured_value)
  if (Number.isNaN(e) || Number.isNaN(m)) return null
  return m - e
}
function deviationClass (item) {
  const d = deviation(item)
  if (d == null) return 'text-medium-emphasis'
  return d > 0 ? 'text-amber-darken-2' : 'text-cyan-darken-2'
}

function formatDate (s) {
  if (!s) return '—'
  return new Date(s).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
}
function formatTime (s) {
  if (!s) return ''
  return new Date(s).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
}
function formatDateTime (s) {
  if (!s) return '—'
  return new Date(s).toLocaleString()
}

function openNew () { form.value = emptyForm(); formDialog.value = true }
function openEdit (it) {
  form.value = { ...emptyForm(), ...it }
  detailDialog.value = false
  formDialog.value = true
}
function openDetail (it) { detailItem.value = it; detailDialog.value = true }
function openChartFor (it) {
  chartTest.value = it.test
  chartInstrument.value = it.instrument
  chartLot.value = ''
  chartDialog.value = true
}
function duplicate (it) {
  form.value = { ...emptyForm(), ...it, id: null }
  detailDialog.value = false
  formDialog.value = true
}
async function save () {
  const { valid } = (await formRef.value?.validate?.()) || { valid: true }
  if (!valid) return
  try {
    const payload = {
      ...form.value,
      expected_value: form.value.expected_value != null ? String(form.value.expected_value) : '',
      measured_value: form.value.measured_value != null ? String(form.value.measured_value) : '',
    }
    if (payload.id) await r.update(payload.id, payload)
    else await r.create(payload)
    formDialog.value = false
    notify(`QC run ${form.value.id ? 'updated' : 'logged'} successfully`)
    await r.list()
  } catch (e) { notify(r.error.value || 'Save failed', 'error') }
}
function confirmDelete (it) { deleteDialog.item = it; deleteDialog.show = true }
async function doDelete () {
  deleteDialog.busy = true
  try {
    await r.remove(deleteDialog.item.id)
    notify('QC run deleted')
    deleteDialog.show = false
    detailDialog.value = false
  } catch (e) { notify(r.error.value || 'Delete failed', 'error') }
  finally { deleteDialog.busy = false }
}
async function bulkDelete () {
  if (!confirm(`Delete ${selected.value.length} QC run(s)? This cannot be undone.`)) return
  bulkBusy.value = true
  try {
    await Promise.all(selected.value.map(id => r.remove(id)))
    notify(`${selected.value.length} QC run(s) deleted`)
    selected.value = []
  } catch (e) { notify(r.error.value || 'Bulk delete failed', 'error') }
  finally { bulkBusy.value = false }
}

function resetFilters () {
  statusFilter.value = null
  instrumentFilter.value = null
  testFilter.value = null
  levelFilter.value = null
  dateFilter.value = '30d'
  sortBy.value = 'newest'
  r.search.value = ''
}
function reload () { r.list(); inst.list(); cat.list() }
function notify (text, color = 'success') { snack.text = text; snack.color = color; snack.show = true }

function exportCsv () {
  const rows = filtered.value
  if (!rows.length) return
  const cols = ['run_at', 'instrument', 'test', 'qc_level', 'lot_number',
    'expected_value', 'measured_value', 'sd', 'result', 'performed_by', 'comments']
  const esc = v => `"${String(v ?? '').replace(/"/g, '""')}"`
  const body = rows.map(q => [
    esc(q.run_at), esc(q.instrument_name), esc(q.test_name),
    esc(q.qc_level), esc(q.lot_number),
    esc(q.expected_value), esc(q.measured_value),
    q.sd ?? '', esc(q.result), esc(q.performed_by_name), esc(q.comments),
  ].join(',')).join('\n')
  const blob = new Blob([cols.join(',') + '\n' + body], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `lab-qc_${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

function printRun (q) {
  const w = window.open('', '_blank')
  if (!w) return
  w.document.write(`
    <html><head><title>QC Run · ${q.test_name}</title>
    <style>
      body{font-family:Arial,sans-serif;padding:32px;color:#222}
      h1{margin:0 0 4px;font-size:20px}
      table{width:100%;border-collapse:collapse;margin-top:8px}
      th,td{border-bottom:1px solid #eee;padding:8px;text-align:left;font-size:13px}
      .muted{color:#666;font-size:12px}
      .badge{display:inline-block;padding:2px 8px;border-radius:6px;font-size:12px;color:#fff}
      .pass{background:#43a047}.warn{background:#fb8c00}.fail{background:#e53935}
    </style></head><body>
      <h1>Quality Control Run</h1>
      <div class="muted">${formatDateTime(q.run_at)}</div>
      <p><b>${q.test_name}</b> on <b>${q.instrument_name}</b> ·
        <span class="badge ${q.result}">${q.result.toUpperCase()}</span></p>
      <table>
        <tr><th>Level</th><td>${q.qc_level || '—'}</td>
            <th>Lot</th><td>${q.lot_number || '—'}</td></tr>
        <tr><th>Expected</th><td>${q.expected_value || '—'}</td>
            <th>Measured</th><td>${q.measured_value || '—'}</td></tr>
        <tr><th>SD</th><td>${q.sd ?? '—'}</td>
            <th>Performed by</th><td>${q.performed_by_name || '—'}</td></tr>
      </table>
      ${q.comments ? `<h3>Comments</h3><p>${q.comments}</p>` : ''}
    </body></html>`)
  w.document.close()
  w.print()
}

onMounted(() => { r.list(); inst.list(); cat.list() })
</script>

<style scoped>
.kpi { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.qc-table :deep(tbody tr) { cursor: pointer; }
.qc-card {
  position: relative;
  overflow: hidden;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  cursor: pointer;
  transition: transform 120ms ease, box-shadow 120ms ease;
}
.qc-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.06); }
.qc-band { position: absolute; top: 0; left: 0; right: 0; height: 3px; }
.bulk-bar {
  border: 1px solid rgba(var(--v-theme-primary), 0.2);
  background: rgba(var(--v-theme-primary), 0.04);
}
.min-width-0 { min-width: 0; }
.font-monospace { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
</style>
