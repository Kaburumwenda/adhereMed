<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="rose-lighten-5" size="48">
        <v-icon color="rose-darken-2" size="28">mdi-flask-outline</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Test Catalog</div>
        <div class="text-body-2 text-medium-emphasis">
          Manage all lab tests · Pricing · Specimens · Turnaround time · Reference ranges
        </div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh"
             :loading="loading" @click="loadAll">Refresh</v-btn>
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-tray-arrow-down" @click="exportCsv">Export</v-btn>
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-tray-arrow-up" @click="$refs.importInput.click()">
        Import
      </v-btn>
      <input ref="importInput" type="file" accept=".csv" hidden @change="importCsv" />
      <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openTest()">New Test</v-btn>
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

    <!-- Section pills + view toggle -->
    <v-card flat rounded="lg" class="mt-4 pa-3">
      <div class="d-flex flex-wrap align-center ga-2">
        <v-chip
          v-for="s in sectionFilters" :key="s.value"
          :color="section === s.value ? (s.color || 'primary') : undefined"
          :variant="section === s.value ? 'flat' : 'tonal'"
          size="small" @click="section = s.value"
        >
          <v-icon v-if="s.icon" size="14" start>{{ s.icon }}</v-icon>
          {{ s.label }}<span v-if="s.count != null" class="ml-2 font-weight-bold">{{ s.count }}</span>
        </v-chip>

        <v-divider vertical class="mx-2" />

        <v-chip
          v-for="d in topDeptChips" :key="d.value || 'all-dept'"
          :color="deptFilter === d.value ? 'rose' : undefined"
          :variant="deptFilter === d.value ? 'flat' : 'tonal'"
          size="small" @click="deptFilter = d.value"
        >
          <v-icon size="14" start>{{ deptIcon(d.value) }}</v-icon>
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
        <v-col cols="12" md="4">
          <v-text-field
            v-model="search"
            prepend-inner-icon="mdi-magnify"
            placeholder="Search code, name, specimen…"
            variant="outlined" density="compact" hide-details clearable
          />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="specimenFilter" :items="specimenOptions"
                    label="Specimen" prepend-inner-icon="mdi-water"
                    variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="statusFilter" :items="statusFilterOptions"
                    label="Status" prepend-inner-icon="mdi-progress-check"
                    variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="priceBand" :items="priceBandOptions"
                    label="Price" prepend-inner-icon="mdi-cash"
                    variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="sortBy" :items="sortOptions"
                    label="Sort" prepend-inner-icon="mdi-sort"
                    variant="outlined" density="compact" hide-details />
        </v-col>
      </v-row>
    </v-card>

    <!-- Bulk action bar -->
    <v-slide-y-transition>
      <v-card v-if="selected.length" flat rounded="lg" class="mt-3 pa-3 bulk-bar">
        <div class="d-flex align-center ga-2">
          <v-icon color="primary">mdi-check-all</v-icon>
          <span class="font-weight-medium">{{ selected.length }} selected</span>
          <v-spacer />
          <v-btn size="small" variant="tonal" color="success" prepend-icon="mdi-check-circle"
                 :loading="bulkBusy" @click="bulkSetActive(true)">Activate</v-btn>
          <v-btn size="small" variant="tonal" color="amber-darken-2" prepend-icon="mdi-pause-circle"
                 :loading="bulkBusy" @click="bulkSetActive(false)">Deactivate</v-btn>
          <v-btn size="small" variant="tonal" color="error" prepend-icon="mdi-delete"
                 :loading="bulkBusy" @click="bulkDelete">Delete</v-btn>
          <v-btn size="small" variant="text" @click="selected = []">Clear</v-btn>
        </div>
      </v-card>
    </v-slide-y-transition>

    <!-- ============= LIST (all / active / inactive) ============= -->
    <template v-if="['all','active','inactive'].includes(section)">
      <!-- Table view -->
      <v-card v-if="view === 'table'" flat rounded="lg" class="mt-3">
        <v-data-table
          v-model="selected"
          show-select
          :headers="headers"
          :items="filtered"
          :loading="loading"
          :items-per-page="20"
          item-value="id"
          hover
          class="cat-table"
          @click:row="(_, { item }) => openDetail(item)"
        >
          <template #loading><v-skeleton-loader type="table-row@5" /></template>

          <template #item.code="{ item }">
            <v-chip size="x-small" variant="tonal" color="rose" class="font-monospace">
              {{ item.code }}
            </v-chip>
          </template>

          <template #item.name="{ item }">
            <div class="d-flex align-center">
              <v-avatar :color="deptColor(item.department)" size="30" class="mr-2">
                <v-icon size="14" color="white">{{ deptIcon(item.department) }}</v-icon>
              </v-avatar>
              <div class="min-width-0">
                <div class="font-weight-medium text-truncate">{{ item.name }}</div>
                <div class="text-caption text-medium-emphasis text-truncate">
                  {{ item.specimen_type || '—' }}
                </div>
              </div>
            </div>
          </template>

          <template #item.department="{ value }">
            <v-chip v-if="value" size="x-small" variant="tonal" :color="deptColor(value)">
              {{ value }}
            </v-chip>
            <span v-else class="text-medium-emphasis text-caption">—</span>
          </template>

          <template #item.specimen_type="{ value }">
            <div class="d-flex align-center">
              <v-icon size="14" :color="specimenColor(value)" class="mr-1">{{ specimenIcon(value) }}</v-icon>
              <span class="text-caption">{{ value || '—' }}</span>
            </div>
          </template>

          <template #item.turnaround_time="{ value }">
            <v-chip v-if="value" size="x-small" variant="tonal" color="indigo">
              <v-icon size="12" start>mdi-clock-outline</v-icon>{{ value }}
            </v-chip>
            <span v-else class="text-medium-emphasis text-caption">—</span>
          </template>

          <template #item.price="{ value }">
            <span class="font-monospace font-weight-bold">{{ fmtMoney(value) }}</span>
          </template>

          <template #item.is_active="{ value }">
            <v-chip :color="value ? 'success' : 'grey'" size="small" variant="flat">
              <v-icon size="14" start>{{ value ? 'mdi-check' : 'mdi-pause' }}</v-icon>
              {{ value ? 'Active' : 'Inactive' }}
            </v-chip>
          </template>

          <template #item.actions="{ item }">
            <div class="d-flex justify-end" @click.stop>
              <v-tooltip text="View" location="top">
                <template #activator="{ props }">
                  <v-btn v-bind="props" icon="mdi-eye-outline" variant="text" size="small"
                         @click="openDetail(item)" />
                </template>
              </v-tooltip>
              <v-tooltip text="Edit" location="top">
                <template #activator="{ props }">
                  <v-btn v-bind="props" icon="mdi-pencil-outline" variant="text" size="small"
                         color="primary" @click="openTest(item)" />
                </template>
              </v-tooltip>
              <v-menu>
                <template #activator="{ props }">
                  <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" />
                </template>
                <v-list density="compact">
                  <v-list-item :prepend-icon="item.is_active ? 'mdi-pause' : 'mdi-check'"
                               :title="item.is_active ? 'Deactivate' : 'Activate'"
                               @click="toggleActive(item)" />
                  <v-list-item prepend-icon="mdi-content-copy" title="Duplicate"
                               @click="duplicate(item)" />
                  <v-divider />
                  <v-list-item prepend-icon="mdi-delete" title="Delete" base-color="error"
                               @click="confirmDelete(item)" />
                </v-list>
              </v-menu>
            </div>
          </template>

          <template #no-data>
            <div class="pa-8 text-center">
              <v-icon size="56" color="grey-lighten-1">mdi-flask-empty-outline</v-icon>
              <div class="text-subtitle-1 font-weight-medium mt-2">No tests found</div>
              <div class="text-body-2 text-medium-emphasis mb-4">
                Adjust your filters or add a new test.
              </div>
              <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openTest()">New Test</v-btn>
            </div>
          </template>
        </v-data-table>
      </v-card>

      <!-- Grid view -->
      <div v-else class="mt-3">
        <div v-if="loading" class="d-flex justify-center pa-12">
          <v-progress-circular indeterminate color="primary" />
        </div>
        <div v-else-if="!filtered.length" class="pa-8 text-center">
          <v-icon size="56" color="grey-lighten-1">mdi-flask-empty-outline</v-icon>
          <div class="text-subtitle-1 font-weight-medium mt-2">No tests found</div>
          <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" class="mt-3" @click="openTest()">
            New Test
          </v-btn>
        </div>
        <v-row v-else dense>
          <v-col v-for="t in filtered" :key="t.id" cols="12" sm="6" md="4" lg="3">
            <v-card flat rounded="lg" class="cat-card pa-3 h-100" hover @click="openDetail(t)">
              <div class="cat-band" :style="{ background: deptHex(t.department) }" />
              <div class="d-flex align-center mb-2">
                <v-chip size="x-small" variant="tonal" color="rose" class="font-monospace">{{ t.code }}</v-chip>
                <v-spacer />
                <v-chip :color="t.is_active ? 'success' : 'grey'" size="x-small" variant="flat">
                  <v-icon size="12" start>{{ t.is_active ? 'mdi-check' : 'mdi-pause' }}</v-icon>
                  {{ t.is_active ? 'Active' : 'Inactive' }}
                </v-chip>
              </div>
              <div class="d-flex align-center">
                <v-avatar :color="deptColor(t.department)" size="36" class="mr-3">
                  <v-icon size="18" color="white">{{ deptIcon(t.department) }}</v-icon>
                </v-avatar>
                <div class="min-width-0 flex-grow-1">
                  <div class="font-weight-medium text-truncate">{{ t.name }}</div>
                  <div class="text-caption text-medium-emphasis text-truncate">
                    {{ t.department || 'Uncategorised' }}
                  </div>
                </div>
              </div>
              <v-divider class="my-3" />
              <div class="d-flex justify-space-between text-caption mb-1">
                <span class="text-medium-emphasis">Specimen</span>
                <span>
                  <v-icon size="12" :color="specimenColor(t.specimen_type)">{{ specimenIcon(t.specimen_type) }}</v-icon>
                  {{ t.specimen_type || '—' }}
                </span>
              </div>
              <div class="d-flex justify-space-between text-caption mb-1">
                <span class="text-medium-emphasis">TAT</span>
                <span>{{ t.turnaround_time || '—' }}</span>
              </div>
              <div class="d-flex justify-space-between align-center mt-2">
                <span class="text-caption text-medium-emphasis">Price</span>
                <span class="font-monospace font-weight-bold text-h6">{{ fmtMoney(t.price) }}</span>
              </div>
            </v-card>
          </v-col>
        </v-row>
      </div>

      <!-- Total bar -->
      <v-card v-if="filtered.length" flat rounded="lg" class="mt-3 pa-3 d-flex align-center">
        <v-icon color="rose-darken-2" class="mr-2">mdi-sigma</v-icon>
        <span class="text-body-2 text-medium-emphasis">
          Showing <strong>{{ filtered.length }}</strong> of {{ tests.length }}
        </span>
        <v-spacer />
        <span class="text-body-2 text-medium-emphasis mr-2">Avg price</span>
        <span class="text-h6 font-weight-bold">{{ fmtMoney(avgFilteredPrice) }}</span>
      </v-card>
    </template>

    <!-- ============= DEPARTMENTS ============= -->
    <template v-if="section === 'departments'">
      <v-row dense class="mt-3">
        <v-col v-for="d in deptStats" :key="d.name" cols="12" sm="6" md="4" lg="3">
          <v-card flat rounded="lg" class="cat-card pa-4 h-100" hover @click="filterByDept(d.name)">
            <div class="cat-band" :style="{ background: d.color }" />
            <div class="d-flex align-center mb-3">
              <v-avatar :color="d.color" size="40" class="mr-3">
                <v-icon color="white">{{ d.icon }}</v-icon>
              </v-avatar>
              <div class="min-width-0 flex-grow-1">
                <div class="font-weight-bold text-truncate">{{ d.name }}</div>
                <div class="text-caption text-medium-emphasis">
                  {{ d.count }} test(s)
                </div>
              </div>
              <v-icon color="grey" size="18">mdi-chevron-right</v-icon>
            </div>
            <div class="d-flex justify-space-between text-caption mb-1">
              <span class="text-medium-emphasis">Active</span>
              <span class="font-weight-medium">{{ d.active }} / {{ d.count }}</span>
            </div>
            <div class="d-flex justify-space-between text-caption mb-1">
              <span class="text-medium-emphasis">Avg price</span>
              <span class="font-monospace">{{ fmtMoney(d.avg) }}</span>
            </div>
            <div class="d-flex justify-space-between text-caption mb-2">
              <span class="text-medium-emphasis">Range</span>
              <span class="font-monospace">{{ fmtMoney(d.min) }} – {{ fmtMoney(d.max) }}</span>
            </div>
            <v-progress-linear :model-value="d.share" :color="d.color" height="6" rounded />
            <div class="text-caption text-medium-emphasis text-right mt-1">
              {{ d.share.toFixed(1) }}% of catalog
            </div>
          </v-card>
        </v-col>
        <v-col v-if="!deptStats.length" cols="12">
          <v-card class="pa-8 text-center text-medium-emphasis" rounded="lg" flat>
            <v-icon size="56" color="grey-lighten-1">mdi-shape-outline</v-icon>
            <div class="text-subtitle-1 font-weight-medium mt-2">No departments yet</div>
            <div class="text-body-2 mb-3">Departments are created automatically when you add tests.</div>
            <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openTest()">New Test</v-btn>
          </v-card>
        </v-col>
      </v-row>
    </template>

    <!-- ============= TEST DIALOG ============= -->
    <v-dialog v-model="testDialog.show" max-width="780" scrollable persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="rose-lighten-5" size="40" class="mr-3">
            <v-icon color="rose-darken-2">{{ testDialog.editing ? 'mdi-pencil' : 'mdi-plus' }}</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">CATALOG TEST</div>
            <div class="text-h6 font-weight-bold">
              {{ testDialog.editing ? 'Edit test' : 'New test' }}
            </div>
          </div>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" @click="testDialog.show = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          <v-form ref="testForm" v-model="testFormValid" @submit.prevent="saveTest">
            <v-row dense>
              <v-col cols="12" sm="4">
                <v-text-field v-model="testDialog.data.code" label="Code *"
                              prepend-inner-icon="mdi-barcode"
                              placeholder="e.g. CBC, U&E, HBA1C"
                              persistent-placeholder
                              :rules="[v => !!v || 'Code is required']"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" sm="8">
                <v-text-field v-model="testDialog.data.name" label="Test name *"
                              prepend-inner-icon="mdi-text-box-outline"
                              placeholder="e.g. Complete Blood Count"
                              persistent-placeholder
                              :rules="[v => !!v || 'Name is required']"
                              variant="outlined" density="comfortable" />
              </v-col>

              <v-col cols="12">
                <div class="text-overline text-medium-emphasis mb-1">Test suggestions</div>
                <div class="d-flex flex-wrap mb-1" style="gap:6px">
                  <v-chip
                    v-for="s in testSuggestions" :key="s.code"
                    size="small"
                    :variant="testDialog.data.code === s.code ? 'flat' : 'tonal'"
                    :color="testDialog.data.code === s.code ? deptColor(s.department) : undefined"
                    @click="applyTestSuggestion(s)"
                  >
                    <v-icon size="14" start>{{ deptIcon(s.department) }}</v-icon>
                    {{ s.code }} · {{ s.name }}
                  </v-chip>
                </div>
              </v-col>

              <v-col cols="12" sm="6">
                <v-combobox v-model="testDialog.data.department" :items="depts"
                            label="Department" prepend-inner-icon="mdi-shape"
                            variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-combobox v-model="testDialog.data.specimen_type" :items="specimenItems"
                            label="Specimen type" prepend-inner-icon="mdi-water"
                            variant="outlined" density="comfortable" />
              </v-col>

              <v-col cols="12">
                <div class="text-overline text-medium-emphasis mb-1">Department</div>
                <div class="d-flex flex-wrap mb-1" style="gap:6px">
                  <v-chip
                    v-for="d in depts" :key="d"
                    size="small"
                    :variant="testDialog.data.department === d ? 'flat' : 'outlined'"
                    :color="deptColor(d)"
                    :style="testDialog.data.department === d ? `color:#fff;border-color:${deptHex(d)};` : ''"
                    @click="testDialog.data.department = d"
                  >
                    <v-icon size="14" start>{{ deptIcon(d) }}</v-icon>{{ d }}
                  </v-chip>
                </div>
              </v-col>

              <v-col cols="12">
                <div class="text-overline text-medium-emphasis mb-1">Specimen</div>
                <div class="d-flex flex-wrap mb-1" style="gap:6px">
                  <v-chip
                    v-for="s in specimenItems" :key="s"
                    size="small"
                    :variant="testDialog.data.specimen_type === s ? 'flat' : 'outlined'"
                    :color="specimenColor(s)"
                    :style="testDialog.data.specimen_type === s ? `color:#fff;border-color:${specimenHex(s)};` : ''"
                    @click="testDialog.data.specimen_type = s"
                  >
                    <v-icon size="14" start>{{ specimenIcon(s) }}</v-icon>{{ s }}
                  </v-chip>
                </div>
              </v-col>

              <v-col cols="6" sm="4">
                <v-text-field v-model.number="testDialog.data.price" type="number" step="0.01" prefix="KSh"
                              label="Price *" prepend-inner-icon="mdi-cash"
                              :rules="[v => (v != null && v !== '') || 'Required', v => Number(v) >= 0 || 'Must be ≥ 0']"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="6" sm="4">
                <v-combobox v-model="testDialog.data.turnaround_time" :items="tatItems"
                            label="Turnaround time" prepend-inner-icon="mdi-clock-outline"
                            placeholder="e.g. 2 hrs"
                            persistent-placeholder
                            variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" sm="4" class="d-flex align-center justify-end">
                <v-switch v-model="testDialog.data.is_active" color="success" inset
                          density="compact" hide-details
                          :label="testDialog.data.is_active ? 'Active' : 'Inactive'" />
              </v-col>

              <v-col cols="12">
                <v-textarea v-model="testDialog.data.instructions" label="Patient / sample instructions"
                            prepend-inner-icon="mdi-clipboard-text"
                            rows="2" auto-grow variant="outlined" density="comfortable" />
              </v-col>

              <v-col cols="12">
                <v-card flat color="rose-lighten-5" rounded="lg" class="pa-3">
                  <div class="d-flex align-center mb-2">
                    <v-icon color="rose-darken-2" class="mr-2">mdi-ruler</v-icon>
                    <div class="text-overline text-medium-emphasis">REFERENCE RANGES</div>
                    <v-spacer />
                    <v-btn size="x-small" variant="tonal" color="rose" prepend-icon="mdi-plus"
                           @click="addRangeRow">Add row</v-btn>
                  </div>
                  <v-row v-for="(row, i) in rangeRows" :key="i" dense>
                    <v-col cols="12" sm="4">
                      <v-text-field v-model="row.label" label="Label"
                                    placeholder="e.g. Adult, Female, 0-12y"
                                    persistent-placeholder
                                    variant="outlined" density="compact" hide-details />
                    </v-col>
                    <v-col cols="12" sm="6">
                      <v-text-field v-model="row.range" label="Range"
                                    placeholder="e.g. 12.0–16.0 g/dL"
                                    persistent-placeholder
                                    variant="outlined" density="compact" hide-details />
                    </v-col>
                    <v-col cols="12" sm="2" class="d-flex align-center">
                      <v-btn icon="mdi-delete" size="x-small" variant="text" color="error"
                             @click="removeRangeRow(i)" />
                    </v-col>
                  </v-row>
                  <div v-if="!rangeRows.length" class="text-caption text-medium-emphasis text-center py-2">
                    No reference ranges. Click <strong>Add row</strong> to define one.
                  </div>
                </v-card>
              </v-col>
            </v-row>
          </v-form>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="testDialog.show = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" :loading="testDialog.saving"
                 :disabled="!testFormValid" @click="saveTest">
            <v-icon start>mdi-content-save</v-icon>
            {{ testDialog.editing ? 'Update' : 'Save' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ============= DETAIL DIALOG ============= -->
    <v-dialog v-model="detailDialog" max-width="640" scrollable>
      <v-card v-if="detailItem" rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar :color="deptColor(detailItem.department)" size="44" class="mr-3">
            <v-icon color="white" size="22">{{ deptIcon(detailItem.department) }}</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">{{ detailItem.code }}</div>
            <div class="text-h6 font-weight-bold">{{ detailItem.name }}</div>
          </div>
          <v-spacer />
          <v-chip :color="detailItem.is_active ? 'success' : 'grey'" size="small" variant="flat" class="mr-2">
            {{ detailItem.is_active ? 'Active' : 'Inactive' }}
          </v-chip>
          <v-btn icon="mdi-close" variant="text" @click="detailDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          <v-row dense>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Department</div>
              <div class="font-weight-medium">{{ detailItem.department || '—' }}</div>
            </v-col>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Specimen</div>
              <div class="font-weight-medium">
                <v-icon size="14" :color="specimenColor(detailItem.specimen_type)">{{ specimenIcon(detailItem.specimen_type) }}</v-icon>
                {{ detailItem.specimen_type || '—' }}
              </div>
            </v-col>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Turnaround</div>
              <div class="font-weight-medium">{{ detailItem.turnaround_time || '—' }}</div>
            </v-col>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Price</div>
              <div class="font-weight-bold font-monospace">{{ fmtMoney(detailItem.price) }}</div>
            </v-col>
            <v-col cols="12">
              <v-divider class="my-3" />
              <div class="text-overline text-medium-emphasis mb-1">Reference ranges</div>
              <div v-if="detailRanges.length">
                <div v-for="(r, i) in detailRanges" :key="i"
                     class="d-flex justify-space-between align-center py-1 ref-row">
                  <span class="text-body-2">{{ r.label || '—' }}</span>
                  <span class="font-monospace">{{ r.range || '—' }}</span>
                </div>
              </div>
              <div v-else class="text-caption text-medium-emphasis">None defined.</div>
            </v-col>
            <v-col v-if="detailItem.instructions" cols="12">
              <div class="text-caption text-medium-emphasis mt-2">Instructions</div>
              <div class="text-body-2">{{ detailItem.instructions }}</div>
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-btn variant="tonal" :color="detailItem.is_active ? 'amber-darken-2' : 'success'"
                 :prepend-icon="detailItem.is_active ? 'mdi-pause' : 'mdi-check'"
                 @click="toggleActive(detailItem); detailDialog = false">
            {{ detailItem.is_active ? 'Deactivate' : 'Activate' }}
          </v-btn>
          <v-btn variant="text" prepend-icon="mdi-content-copy"
                 @click="duplicate(detailItem); detailDialog = false">Duplicate</v-btn>
          <v-spacer />
          <v-btn variant="text" @click="detailDialog = false">Close</v-btn>
          <v-btn color="primary" rounded="lg" prepend-icon="mdi-pencil"
                 @click="openTest(detailItem); detailDialog = false">Edit</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ============= DELETE CONFIRM ============= -->
    <v-dialog v-model="deleteDialog.show" max-width="420">
      <v-card v-if="deleteDialog.target" rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="error-lighten-5" size="40" class="mr-3">
            <v-icon color="error-darken-2">mdi-delete</v-icon>
          </v-avatar>
          <div class="text-h6 font-weight-bold">Delete test?</div>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          This will permanently remove
          <strong>{{ deleteDialog.target.code }}</strong> – {{ deleteDialog.target.name }}.
        </v-card-text>
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog.show = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" :loading="deleteDialog.saving" @click="doDelete">
            <v-icon start>mdi-delete</v-icon>Delete
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" :timeout="2400">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()

// ── State ────────────────────────────────────────────────────────
const loading = ref(false)
const bulkBusy = ref(false)
const tests = ref([])
const selected = ref([])
const importInput = ref(null)

const view = ref('table')
const section = ref('all')
const search = ref('')
const statusFilter = ref(null)
const specimenFilter = ref(null)
const deptFilter = ref(null)
const priceBand = ref(null)
const sortBy = ref('name_asc')

const snack = ref({ show: false, color: 'success', text: '' })
const notify = (text, color = 'success') => { snack.value = { show: true, color, text } }

// ── Loading ──────────────────────────────────────────────────────
function pickRows(settled) {
  if (settled.status !== 'fulfilled') return []
  const d = settled.value?.data
  return d?.results || (Array.isArray(d) ? d : [])
}
async function loadAll() {
  loading.value = true
  try {
    const [r] = await Promise.allSettled([
      $api.get('/lab/catalog/', { params: { page_size: 1000, ordering: 'name' } }),
    ])
    tests.value = pickRows(r)
  } catch {
    notify('Failed to load catalog', 'error')
  } finally {
    loading.value = false
  }
}
onMounted(loadAll)

// ── Helpers ──────────────────────────────────────────────────────
const fmtMoney = (v) => 'KSh ' + Number(v || 0).toLocaleString(undefined, { maximumFractionDigits: 2 })

const depts = [
  'Hematology', 'Chemistry', 'Microbiology', 'Serology', 'Immunology',
  'Histology', 'Cytology', 'Parasitology', 'Molecular', 'Endocrinology',
  'Toxicology', 'Other',
]
const deptIconMap = {
  Hematology: 'mdi-water', Chemistry: 'mdi-flask', Microbiology: 'mdi-bacteria',
  Serology: 'mdi-virus', Immunology: 'mdi-shield-bug', Histology: 'mdi-microscope',
  Cytology: 'mdi-microscope', Parasitology: 'mdi-bug', Molecular: 'mdi-dna',
  Endocrinology: 'mdi-pulse', Toxicology: 'mdi-skull-outline', Other: 'mdi-flask-outline',
}
const deptColorMap = {
  Hematology: 'red', Chemistry: 'blue', Microbiology: 'green', Serology: 'purple',
  Immunology: 'indigo', Histology: 'pink', Cytology: 'deep-purple',
  Parasitology: 'amber-darken-2', Molecular: 'cyan', Endocrinology: 'teal',
  Toxicology: 'brown', Other: 'grey',
}
const deptHexMap = {
  Hematology: '#ef4444', Chemistry: '#3b82f6', Microbiology: '#22c55e', Serology: '#a855f7',
  Immunology: '#6366f1', Histology: '#ec4899', Cytology: '#8b5cf6',
  Parasitology: '#d97706', Molecular: '#06b6d4', Endocrinology: '#14b8a6',
  Toxicology: '#7c2d12', Other: '#94a3b8',
}
const deptIcon = (d) => deptIconMap[d] || 'mdi-flask-outline'
const deptColor = (d) => deptColorMap[d] || 'grey'
const deptHex = (d) => deptHexMap[d] || '#94a3b8'

const specimenItems = ['Blood', 'Serum', 'Plasma', 'Urine', 'Stool', 'CSF', 'Sputum', 'Swab', 'Tissue', 'Other']
const specimenIconMap = {
  Blood: 'mdi-water', Serum: 'mdi-test-tube', Plasma: 'mdi-test-tube',
  Urine: 'mdi-cup-water', Stool: 'mdi-toilet', CSF: 'mdi-water-outline',
  Sputum: 'mdi-lungs', Swab: 'mdi-cotton-swab', Tissue: 'mdi-microscope', Other: 'mdi-flask',
}
const specimenColorMap = {
  Blood: 'red', Serum: 'amber-darken-2', Plasma: 'amber',
  Urine: 'yellow-darken-2', Stool: 'brown', CSF: 'cyan',
  Sputum: 'teal', Swab: 'pink', Tissue: 'deep-purple', Other: 'grey',
}
const specimenHexMap = {
  Blood: '#ef4444', Serum: '#d97706', Plasma: '#f59e0b',
  Urine: '#eab308', Stool: '#7c2d12', CSF: '#06b6d4',
  Sputum: '#14b8a6', Swab: '#ec4899', Tissue: '#8b5cf6', Other: '#94a3b8',
}
const specimenIcon = (s) => specimenIconMap[s] || 'mdi-flask'
const specimenColor = (s) => specimenColorMap[s] || 'grey'
const specimenHex = (s) => specimenHexMap[s] || '#94a3b8'

const tatItems = ['30 mins', '1 hr', '2 hrs', '4 hrs', '6 hrs', 'Same day', '24 hrs', '2 days', '3 days', '1 week']

const statusFilterOptions = [
  { title: 'Active', value: true },
  { title: 'Inactive', value: false },
]
const specimenOptions = computed(() => specimenItems.map(s => ({ title: s, value: s })))
const priceBandOptions = [
  { title: '< KSh 500', value: 'lt500' },
  { title: 'KSh 500 – 2,000', value: 'mid' },
  { title: 'KSh 2,000 – 10,000', value: 'high' },
  { title: '> KSh 10,000', value: 'gt10k' },
]

const testSuggestions = [
  { code: 'CBC',    name: 'Complete Blood Count',     department: 'Hematology',   specimen_type: 'Blood',  price: 800,  turnaround_time: '2 hrs' },
  { code: 'HB',     name: 'Hemoglobin',               department: 'Hematology',   specimen_type: 'Blood',  price: 300,  turnaround_time: '1 hr' },
  { code: 'ESR',    name: 'ESR',                      department: 'Hematology',   specimen_type: 'Blood',  price: 350,  turnaround_time: '2 hrs' },
  { code: 'GLU-F',  name: 'Fasting Glucose',          department: 'Chemistry',    specimen_type: 'Blood',  price: 400,  turnaround_time: '1 hr' },
  { code: 'HBA1C',  name: 'HbA1c',                    department: 'Chemistry',    specimen_type: 'Blood',  price: 1500, turnaround_time: '4 hrs' },
  { code: 'U&E',    name: 'Urea & Electrolytes',      department: 'Chemistry',    specimen_type: 'Serum',  price: 1200, turnaround_time: '4 hrs' },
  { code: 'LFT',    name: 'Liver Function Tests',     department: 'Chemistry',    specimen_type: 'Serum',  price: 2000, turnaround_time: '4 hrs' },
  { code: 'LIPID',  name: 'Lipid Profile',            department: 'Chemistry',    specimen_type: 'Serum',  price: 1800, turnaround_time: '6 hrs' },
  { code: 'TSH',    name: 'Thyroid Stimulating Hormone', department: 'Endocrinology', specimen_type: 'Serum', price: 1800, turnaround_time: '24 hrs' },
  { code: 'URIN',   name: 'Urinalysis',               department: 'Microbiology', specimen_type: 'Urine',  price: 500,  turnaround_time: '1 hr' },
  { code: 'STOOL',  name: 'Stool Microscopy',         department: 'Parasitology', specimen_type: 'Stool',  price: 400,  turnaround_time: '2 hrs' },
  { code: 'MAL',    name: 'Malaria Smear',            department: 'Parasitology', specimen_type: 'Blood',  price: 350,  turnaround_time: '1 hr' },
  { code: 'HIV',    name: 'HIV Screening',            department: 'Serology',     specimen_type: 'Blood',  price: 600,  turnaround_time: '1 hr' },
  { code: 'HEP-B',  name: 'Hepatitis B Surface Ag',   department: 'Serology',     specimen_type: 'Serum',  price: 1200, turnaround_time: '4 hrs' },
  { code: 'PSA',    name: 'Prostate Specific Antigen',department: 'Immunology',   specimen_type: 'Serum',  price: 2500, turnaround_time: '24 hrs' },
  { code: 'PCR',    name: 'PCR Panel',                department: 'Molecular',    specimen_type: 'Swab',   price: 5000, turnaround_time: '2 days' },
]
function applyTestSuggestion(s) {
  const d = testDialog.value.data
  d.code = s.code
  d.name = s.name
  d.department = s.department
  d.specimen_type = s.specimen_type
  if (!d.price) d.price = s.price
  if (!d.turnaround_time) d.turnaround_time = s.turnaround_time
}

// ── Section + filters ────────────────────────────────────────────
const sectionFilters = computed(() => [
  { value: 'all',         label: 'All',         icon: 'mdi-format-list-bulleted', count: tests.value.length, color: 'primary' },
  { value: 'active',      label: 'Active',      icon: 'mdi-check-circle',
    count: tests.value.filter(t => t.is_active).length, color: 'success' },
  { value: 'inactive',    label: 'Inactive',    icon: 'mdi-pause-circle',
    count: tests.value.filter(t => !t.is_active).length, color: 'grey' },
  { value: 'departments', label: 'Departments', icon: 'mdi-shape',
    count: deptStats.value.length, color: 'rose' },
])

const topDeptChips = computed(() => {
  const counts = new Map()
  tests.value.forEach(t => {
    const k = t.department || 'Other'
    counts.set(k, (counts.get(k) || 0) + 1)
  })
  const top = [...counts.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([name, count]) => ({ value: name, label: name, count }))
  return [{ value: null, label: 'All depts', count: null }, ...top]
})

const filtered = computed(() => {
  let rows = [...tests.value]
  if (section.value === 'active')   rows = rows.filter(t => t.is_active)
  if (section.value === 'inactive') rows = rows.filter(t => !t.is_active)

  if (search.value) {
    const q = search.value.toLowerCase()
    rows = rows.filter(t =>
      (t.name || '').toLowerCase().includes(q) ||
      (t.code || '').toLowerCase().includes(q) ||
      (t.department || '').toLowerCase().includes(q) ||
      (t.specimen_type || '').toLowerCase().includes(q)
    )
  }
  if (statusFilter.value !== null && statusFilter.value !== undefined)
    rows = rows.filter(t => t.is_active === statusFilter.value)
  if (specimenFilter.value) rows = rows.filter(t => t.specimen_type === specimenFilter.value)
  if (deptFilter.value)     rows = rows.filter(t => (t.department || 'Other') === deptFilter.value)
  if (priceBand.value) {
    rows = rows.filter(t => {
      const p = Number(t.price || 0)
      if (priceBand.value === 'lt500') return p < 500
      if (priceBand.value === 'mid')   return p >= 500 && p < 2000
      if (priceBand.value === 'high')  return p >= 2000 && p < 10000
      if (priceBand.value === 'gt10k') return p >= 10000
      return true
    })
  }
  const cmp = ({
    name_asc:  (a, b) => (a.name || '').localeCompare(b.name || ''),
    name_desc: (a, b) => (b.name || '').localeCompare(a.name || ''),
    code_asc:  (a, b) => (a.code || '').localeCompare(b.code || ''),
    price_desc:(a, b) => Number(b.price) - Number(a.price),
    price_asc: (a, b) => Number(a.price) - Number(b.price),
  })[sortBy.value]
  if (cmp) rows.sort(cmp)
  return rows
})
const sortOptions = [
  { title: 'Name (A → Z)',   value: 'name_asc' },
  { title: 'Name (Z → A)',   value: 'name_desc' },
  { title: 'Code (A → Z)',   value: 'code_asc' },
  { title: 'Price (high → low)', value: 'price_desc' },
  { title: 'Price (low → high)', value: 'price_asc' },
]
const avgFilteredPrice = computed(() =>
  filtered.value.length
    ? filtered.value.reduce((s, t) => s + Number(t.price || 0), 0) / filtered.value.length
    : 0
)

function filterByDept(name) { deptFilter.value = name; section.value = 'all' }

// ── KPIs ────────────────────────────────────────────────────────
const kpis = computed(() => {
  const total = tests.value.length
  const active = tests.value.filter(t => t.is_active).length
  const avg = total ? tests.value.reduce((s, t) => s + Number(t.price || 0), 0) / total : 0
  const deptCount = new Set(tests.value.map(t => t.department || 'Other')).size
  return [
    { label: 'Total tests',  value: total,  icon: 'mdi-flask-outline', color: 'rose',   hint: 'in catalog' },
    { label: 'Active',       value: active, icon: 'mdi-check-circle',  color: 'green',  hint: `${total - active} inactive` },
    { label: 'Departments',  value: deptCount, icon: 'mdi-shape',      color: 'indigo', hint: 'unique groups' },
    { label: 'Avg price',    value: fmtMoney(avg), icon: 'mdi-cash',   color: 'amber',  hint: 'across all' },
  ]
})

// ── Department stats ────────────────────────────────────────────
const deptStats = computed(() => {
  const total = tests.value.length || 1
  const map = new Map()
  tests.value.forEach(t => {
    const k = t.department || 'Other'
    const cur = map.get(k) || { name: k, count: 0, active: 0, sum: 0, min: Infinity, max: 0 }
    cur.count += 1
    if (t.is_active) cur.active += 1
    const p = Number(t.price || 0)
    cur.sum += p
    cur.min = Math.min(cur.min, p)
    cur.max = Math.max(cur.max, p)
    map.set(k, cur)
  })
  return [...map.values()]
    .map(d => ({
      ...d,
      avg: d.count ? d.sum / d.count : 0,
      min: d.min === Infinity ? 0 : d.min,
      share: (d.count / total) * 100,
      icon: deptIcon(d.name),
      color: deptHex(d.name),
    }))
    .sort((a, b) => b.count - a.count)
})

// ── Headers ─────────────────────────────────────────────────────
const headers = [
  { title: 'Code',       key: 'code', width: 110, sortable: true },
  { title: 'Name',       key: 'name', sortable: true },
  { title: 'Department', key: 'department' },
  { title: 'Specimen',   key: 'specimen_type' },
  { title: 'TAT',        key: 'turnaround_time' },
  { title: 'Price',      key: 'price', align: 'end', sortable: true },
  { title: 'Status',     key: 'is_active', width: 110 },
  { title: '',           key: 'actions', sortable: false, align: 'end', width: 130 },
]

// ── Detail dialog ────────────────────────────────────────────────
const detailDialog = ref(false)
const detailItem = ref(null)
function openDetail(item) { detailItem.value = item; detailDialog.value = true }
const detailRanges = computed(() => {
  const r = detailItem.value?.reference_ranges || {}
  if (Array.isArray(r)) return r
  return Object.entries(r).map(([label, range]) => ({ label, range }))
})

// ── Test dialog ──────────────────────────────────────────────────
const testForm = ref(null)
const testFormValid = ref(false)
const blankTest = () => ({
  code: '', name: '', department: '', specimen_type: '',
  price: 0, turnaround_time: '', instructions: '',
  is_active: true, reference_ranges: {},
})
const testDialog = ref({ show: false, editing: false, saving: false, data: blankTest() })
const rangeRows = ref([])

function openTest(item = null) {
  testDialog.value = {
    show: true, editing: !!item, saving: false,
    data: item ? { ...blankTest(), ...item } : blankTest(),
  }
  const ref_ = (item && item.reference_ranges) || {}
  rangeRows.value = Array.isArray(ref_)
    ? ref_.map(r => ({ label: r.label || '', range: r.range || '' }))
    : Object.entries(ref_).map(([label, range]) => ({ label, range: String(range) }))
}
function addRangeRow() { rangeRows.value.push({ label: '', range: '' }) }
function removeRangeRow(i) { rangeRows.value.splice(i, 1) }

function rangesToObject() {
  const out = {}
  rangeRows.value.forEach(r => {
    const k = (r.label || '').trim()
    const v = (r.range || '').trim()
    if (k && v) out[k] = v
  })
  return out
}

function duplicate(item) {
  openTest({ ...item, id: undefined, code: (item.code || '') + '-COPY' })
}
async function toggleActive(item) {
  try {
    await $api.patch(`/lab/catalog/${item.id}/`, { is_active: !item.is_active })
    notify(`Marked ${!item.is_active ? 'active' : 'inactive'}`)
    await loadAll()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Update failed', 'error')
  }
}
async function saveTest() {
  if (!testForm.value) return
  const { valid } = await testForm.value.validate()
  if (!valid) return
  testDialog.value.saving = true
  try {
    const payload = { ...testDialog.value.data, reference_ranges: rangesToObject() }
    if (testDialog.value.editing && payload.id) {
      await $api.patch(`/lab/catalog/${payload.id}/`, payload)
      notify('Test updated')
    } else {
      delete payload.id
      await $api.post('/lab/catalog/', payload)
      notify('Test created')
    }
    testDialog.value.show = false
    await loadAll()
  } catch (e) {
    notify(e?.response?.data?.detail || e?.response?.data?.code?.[0] || 'Save failed', 'error')
  } finally {
    testDialog.value.saving = false
  }
}

// ── Bulk actions ────────────────────────────────────────────────
async function bulkSetActive(active) {
  if (!selected.value.length) return
  if (!confirm(`${active ? 'Activate' : 'Deactivate'} ${selected.value.length} test(s)?`)) return
  bulkBusy.value = true
  for (const id of selected.value) {
    try { await $api.patch(`/lab/catalog/${id}/`, { is_active: active }) } catch { /* ignore */ }
  }
  bulkBusy.value = false
  selected.value = []
  notify('Bulk update complete')
  await loadAll()
}
async function bulkDelete() {
  if (!selected.value.length) return
  if (!confirm(`Delete ${selected.value.length} test(s)? This cannot be undone.`)) return
  bulkBusy.value = true
  for (const id of selected.value) {
    try { await $api.delete(`/lab/catalog/${id}/`) } catch { /* ignore */ }
  }
  bulkBusy.value = false
  selected.value = []
  notify('Bulk delete complete')
  await loadAll()
}

// ── Delete ──────────────────────────────────────────────────────
const deleteDialog = ref({ show: false, target: null, saving: false })
function confirmDelete(item) { deleteDialog.value = { show: true, target: item, saving: false } }
async function doDelete() {
  deleteDialog.value.saving = true
  try {
    await $api.delete(`/lab/catalog/${deleteDialog.value.target.id}/`)
    notify('Test deleted')
    deleteDialog.value.show = false
    await loadAll()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Delete failed', 'error')
  } finally {
    deleteDialog.value.saving = false
  }
}

// ── Import / Export ─────────────────────────────────────────────
function csvEscape(v) {
  const s = v == null ? '' : String(v)
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s
}
function exportCsv() {
  const rows = [['Code','Name','Department','Specimen','TAT','Price','Active','Instructions']]
  filtered.value.forEach(t => rows.push([
    t.code, t.name, t.department || '', t.specimen_type || '',
    t.turnaround_time || '', t.price, t.is_active ? 'yes' : 'no', t.instructions || '',
  ]))
  const csv = rows.map(r => r.map(csvEscape).join(',')).join('\n')
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = `lab-catalog-${new Date().toISOString().slice(0, 10)}.csv`; a.click()
  URL.revokeObjectURL(url)
}
async function importCsv(e) {
  const file = e.target.files?.[0]
  if (!file) return
  const text = await file.text()
  const lines = text.split(/\r?\n/).filter(Boolean)
  if (!lines.length) return
  const header = lines.shift().split(',').map(h => h.trim().toLowerCase())
  const idx = (n) => header.indexOf(n)
  let ok = 0, fail = 0
  for (const line of lines) {
    const cells = parseCsvLine(line)
    const payload = {
      code: cells[idx('code')] || '',
      name: cells[idx('name')] || '',
      department: cells[idx('department')] || '',
      specimen_type: cells[idx('specimen')] || cells[idx('specimen_type')] || '',
      turnaround_time: cells[idx('tat')] || cells[idx('turnaround_time')] || '',
      price: Number(cells[idx('price')] || 0),
      instructions: cells[idx('instructions')] || '',
      is_active: !/^(no|false|0)$/i.test((cells[idx('active')] || 'yes').trim()),
    }
    if (!payload.code || !payload.name) { fail++; continue }
    try { await $api.post('/lab/catalog/', payload); ok++ } catch { fail++ }
  }
  notify(`Imported ${ok} test(s)${fail ? `, ${fail} failed` : ''}`, fail ? 'warning' : 'success')
  e.target.value = ''
  await loadAll()
}
function parseCsvLine(line) {
  const out = []; let cur = ''; let q = false
  for (let i = 0; i < line.length; i++) {
    const c = line[i]
    if (q) {
      if (c === '"' && line[i + 1] === '"') { cur += '"'; i++ }
      else if (c === '"') q = false
      else cur += c
    } else {
      if (c === ',') { out.push(cur); cur = '' }
      else if (c === '"') q = true
      else cur += c
    }
  }
  out.push(cur)
  return out
}
</script>

<style scoped>
.kpi { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.cat-table :deep(tbody tr) { cursor: pointer; }
/* Kill Vuetify's default dark hover overlay that washes out text */
.cat-table :deep(tbody tr:hover) {
  background: #fff1f2 !important;
}
.cat-table :deep(tbody tr:hover > td),
.cat-table :deep(tbody tr:hover > td *) {
  background-color: transparent !important;
  color: #0f172a !important;
}
.cat-table :deep(tbody tr:hover > td .text-medium-emphasis),
.cat-table :deep(tbody tr:hover > td .text-caption) {
  color: #475569 !important;
}
.cat-table :deep(tbody tr:hover .v-chip) {
  filter: none !important;
}
.cat-card {
  position: relative;
  overflow: hidden;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  transition: transform 120ms ease, box-shadow 120ms ease;
  cursor: pointer;
}
.cat-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.06); }
.cat-band { position: absolute; top: 0; left: 0; right: 0; height: 3px; }
.bulk-bar {
  border: 1px solid rgba(var(--v-theme-primary), 0.2);
  background: rgba(var(--v-theme-primary), 0.04);
}
.min-width-0 { min-width: 0; }
.font-monospace { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
.ref-row + .ref-row { border-top: 1px dashed rgba(0,0,0,0.06); }
</style>
