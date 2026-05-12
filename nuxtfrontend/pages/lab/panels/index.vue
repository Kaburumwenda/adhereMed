<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="indigo-lighten-5" size="48">
        <v-icon color="indigo-darken-2" size="28">mdi-package-variant-closed</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Test Panels</div>
        <div class="text-body-2 text-medium-emphasis">
          Bundle multiple lab tests into a single orderable panel
        </div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh"
             :loading="r.loading.value" @click="reload">Refresh</v-btn>
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-tray-arrow-down"
             @click="exportCsv">Export</v-btn>
      <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openNew">New Panel</v-btn>
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

    <!-- Status pills (quick filter) -->
    <v-card flat rounded="lg" class="mt-4 pa-3">
      <div class="d-flex flex-wrap align-center ga-2">
        <v-chip
          v-for="s in statusFilters"
          :key="s.value || 'all'"
          :color="statusFilter === s.value ? 'primary' : undefined"
          :variant="statusFilter === s.value ? 'flat' : 'tonal'"
          size="small"
          class="text-capitalize"
          @click="statusFilter = s.value"
        >
          {{ s.label }}
          <span class="ml-2 font-weight-bold">{{ s.count }}</span>
        </v-chip>

        <v-divider vertical class="mx-2" />

        <v-chip
          v-for="d in departmentChips"
          :key="d.value || 'all-dept'"
          :color="deptFilter === d.value ? d.color : undefined"
          :variant="deptFilter === d.value ? 'flat' : 'tonal'"
          size="small"
          class="text-capitalize"
          @click="deptFilter = d.value"
        >
          <v-icon v-if="d.icon" size="14" start>{{ d.icon }}</v-icon>
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
          <v-text-field
            v-model="r.search.value"
            prepend-inner-icon="mdi-magnify"
            placeholder="Search by name, code, department or test…"
            variant="outlined" density="compact" hide-details clearable
          />
        </v-col>
        <v-col cols="6" md="3">
          <v-select
            v-model="sortBy" :items="sortOptions"
            label="Sort" variant="outlined" density="compact"
            prepend-inner-icon="mdi-sort" hide-details
          />
        </v-col>
        <v-col cols="6" md="2">
          <v-select
            v-model="sizeFilter" :items="sizeOptions"
            label="Panel size" variant="outlined" density="compact" hide-details clearable
          />
        </v-col>
        <v-col cols="12" md="2" class="d-flex justify-end">
          <v-btn variant="text" size="small" @click="resetFilters">
            <v-icon start size="16">mdi-filter-remove-outline</v-icon>Reset
          </v-btn>
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
          <v-btn size="small" variant="tonal" color="warning" prepend-icon="mdi-cancel"
                 :loading="bulkBusy" @click="bulkSetActive(false)">Deactivate</v-btn>
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
        class="panel-table"
        @click:row="(_, { item }) => openDetail(item)"
      >
        <template #loading><v-skeleton-loader type="table-row@5" /></template>
        <template #item.code="{ item }">
          <span class="font-monospace text-caption font-weight-bold">{{ item.code }}</span>
        </template>
        <template #item.name="{ item }">
          <div class="d-flex align-center py-1">
            <v-avatar :color="deptColor(item.department)" size="32" class="mr-2">
              <v-icon size="16" color="white">{{ deptIcon(item.department) }}</v-icon>
            </v-avatar>
            <div class="min-width-0">
              <div class="font-weight-medium text-truncate">{{ item.name }}</div>
              <div v-if="item.description" class="text-caption text-medium-emphasis text-truncate" style="max-width:280px">
                {{ item.description }}
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
        <template #item.test_names="{ item }">
          <div class="d-flex flex-wrap ga-1" style="max-width: 380px">
            <v-chip
              v-for="(t, i) in (item.test_names || []).slice(0, 3)"
              :key="i" size="x-small" variant="tonal" color="indigo"
            >{{ t }}</v-chip>
            <v-chip
              v-if="(item.test_names || []).length > 3"
              size="x-small" variant="tonal"
            >+{{ item.test_names.length - 3 }}</v-chip>
            <span v-if="!item.test_names?.length" class="text-medium-emphasis text-caption">no tests</span>
          </div>
        </template>
        <template #item.price="{ item }">
          <div class="text-end">
            <div class="font-weight-bold">{{ formatMoney(item.price) }}</div>
            <div v-if="savings(item) > 0" class="text-caption text-success">
              saves {{ formatMoney(savings(item)) }}
            </div>
          </div>
        </template>
        <template #item.is_active="{ item }">
          <v-switch
            :model-value="item.is_active" color="success" hide-details density="compact" inset
            class="mt-0" @click.stop @update:model-value="(v) => toggleActive(item, v)"
          />
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
                       color="primary" @click="openEdit(item)" />
              </template>
            </v-tooltip>
            <v-menu>
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" />
              </template>
              <v-list density="compact">
                <v-list-item prepend-icon="mdi-content-copy" title="Duplicate" @click="duplicate(item)" />
                <v-list-item prepend-icon="mdi-printer-outline" title="Print panel" @click="printPanel(item)" />
                <v-list-item
                  :prepend-icon="item.is_active ? 'mdi-cancel' : 'mdi-check-circle'"
                  :title="item.is_active ? 'Deactivate' : 'Activate'"
                  @click="toggleActive(item)"
                />
                <v-divider />
                <v-list-item prepend-icon="mdi-delete" title="Delete" base-color="error"
                             @click="confirmDelete(item)" />
              </v-list>
            </v-menu>
          </div>
        </template>
        <template #no-data>
          <div class="pa-8 text-center">
            <v-icon size="56" color="grey-lighten-1">mdi-package-variant-remove</v-icon>
            <div class="text-subtitle-1 font-weight-medium mt-2">No panels found</div>
            <div class="text-body-2 text-medium-emphasis mb-4">
              Adjust your filters or create a new panel.
            </div>
            <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openNew">New Panel</v-btn>
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
        <v-icon size="56" color="grey-lighten-1">mdi-package-variant-remove</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-2">No panels found</div>
        <div class="text-body-2 text-medium-emphasis mb-4">
          Adjust your filters or create your first panel.
        </div>
        <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openNew">New Panel</v-btn>
      </div>
      <v-row v-else dense>
        <v-col v-for="p in filtered" :key="p.id" cols="12" sm="6" md="4" lg="3">
          <v-card flat rounded="lg" class="panel-card pa-3 h-100" hover @click="openDetail(p)">
            <div class="panel-band" :style="{ background: deptHex(p.department) }" />
            <div class="d-flex align-center mb-2">
              <span class="font-monospace text-caption text-medium-emphasis">{{ p.code }}</span>
              <v-spacer />
              <v-chip size="x-small" :color="p.is_active ? 'success' : 'grey'" variant="tonal">
                {{ p.is_active ? 'Active' : 'Inactive' }}
              </v-chip>
            </div>
            <div class="d-flex align-center">
              <v-avatar :color="deptColor(p.department)" size="38" class="mr-3">
                <v-icon color="white">{{ deptIcon(p.department) }}</v-icon>
              </v-avatar>
              <div class="min-width-0 flex-grow-1">
                <div class="font-weight-medium text-truncate">{{ p.name }}</div>
                <div v-if="p.department" class="text-caption text-medium-emphasis text-truncate">
                  {{ p.department }}
                </div>
              </div>
            </div>
            <p v-if="p.description" class="text-body-2 text-medium-emphasis panel-desc mt-2 mb-0">
              {{ p.description }}
            </p>
            <v-divider class="my-3" />
            <div class="d-flex flex-wrap ga-1 mb-2" style="min-height: 28px">
              <v-chip v-for="(t, i) in (p.test_names || []).slice(0, 3)"
                      :key="i" size="x-small" variant="tonal" color="indigo">{{ t }}</v-chip>
              <v-chip v-if="(p.test_names || []).length > 3" size="x-small" variant="tonal">
                +{{ p.test_names.length - 3 }}
              </v-chip>
              <v-chip v-if="!(p.test_names || []).length" size="x-small" variant="tonal" color="error">
                no tests
              </v-chip>
            </div>
            <div class="d-flex align-center justify-space-between">
              <div>
                <div class="text-caption text-medium-emphasis">Price</div>
                <div class="font-weight-bold text-indigo-darken-2">{{ formatMoney(p.price) }}</div>
              </div>
              <div class="text-end" v-if="savings(p) > 0">
                <div class="text-caption text-medium-emphasis">Saves</div>
                <div class="font-weight-medium text-success">{{ formatMoney(savings(p)) }}</div>
              </div>
              <div class="d-flex" @click.stop>
                <v-btn icon="mdi-pencil-outline" variant="text" size="small" color="primary"
                       @click="openEdit(p)" />
                <v-btn icon="mdi-delete-outline" variant="text" size="small" color="error"
                       @click="confirmDelete(p)" />
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>
    </div>

    <!-- Create / Edit dialog -->
    <v-dialog v-model="formDialog" max-width="900" scrollable persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="indigo-lighten-5" size="40" class="mr-3">
            <v-icon color="indigo-darken-2">{{ form.id ? 'mdi-pencil' : 'mdi-plus' }}</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">PANEL</div>
            <div class="text-h6 font-weight-bold">{{ form.id ? 'Edit panel' : 'New panel' }}</div>
          </div>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" @click="formDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          <v-form ref="formRef" @submit.prevent="save">
            <v-row dense>
              <v-col cols="12" sm="4">
                <v-text-field v-model="form.code" label="Code *" placeholder="e.g. CBC"
                              variant="outlined" density="comfortable" :rules="[required]"
                              prepend-inner-icon="mdi-barcode" />
              </v-col>
              <v-col cols="12" sm="8">
                <v-text-field v-model="form.name" label="Panel name *"
                              placeholder="e.g. Complete Blood Count"
                              variant="outlined" density="comfortable" :rules="[required]" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-combobox v-model="form.department" :items="departmentList" label="Department"
                            variant="outlined" density="comfortable"
                            prepend-inner-icon="mdi-stethoscope" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model.number="form.price" type="number" min="0" step="0.01"
                              label="Panel price *" variant="outlined" density="comfortable"
                              :rules="[required]" prepend-inner-icon="mdi-cash">
                  <template #append-inner>
                    <v-tooltip text="Auto-fill with sum of selected test prices" location="top">
                      <template #activator="{ props }">
                        <v-btn v-bind="props" size="x-small" variant="text" color="indigo"
                               icon="mdi-calculator" @click="form.price = sumOfSelectedPrices" />
                      </template>
                    </v-tooltip>
                  </template>
                </v-text-field>
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="form.description" label="Description / clinical use"
                            rows="2" auto-grow variant="outlined" density="comfortable" />
              </v-col>

              <!-- Test selector -->
              <v-col cols="12">
                <div class="d-flex align-center mb-2">
                  <v-icon color="indigo" class="mr-2">mdi-flask-outline</v-icon>
                  <div class="text-subtitle-2 font-weight-bold">Tests included</div>
                  <v-spacer />
                  <v-chip size="small" color="indigo" variant="tonal">
                    {{ form.test_ids.length }} selected
                  </v-chip>
                </div>
                <v-autocomplete
                  v-model="form.test_ids"
                  :items="catalogList"
                  :loading="cat.loading.value"
                  item-title="name" item-value="id"
                  label="Add tests to this panel"
                  multiple chips closable-chips
                  variant="outlined" density="comfortable"
                  prepend-inner-icon="mdi-flask-plus"
                  :menu-props="{ maxHeight: 380 }"
                >
                  <template #chip="{ props, item }">
                    <v-chip v-bind="props" size="small" color="indigo" variant="tonal" closable>
                      <span class="font-weight-medium">{{ item.raw.code }}</span>
                      <span class="ml-1">{{ item.raw.name }}</span>
                    </v-chip>
                  </template>
                  <template #item="{ props, item }">
                    <v-list-item v-bind="props" :title="undefined">
                      <template #prepend>
                        <v-avatar color="indigo-lighten-5" size="32">
                          <v-icon color="indigo-darken-2" size="16">mdi-flask</v-icon>
                        </v-avatar>
                      </template>
                      <v-list-item-title class="font-weight-medium">
                        {{ item.raw.code }} · {{ item.raw.name }}
                      </v-list-item-title>
                      <v-list-item-subtitle class="text-caption">
                        <span v-if="item.raw.specimen_type">{{ item.raw.specimen_type }} · </span>
                        <span v-if="item.raw.department">{{ item.raw.department }} · </span>
                        <span class="font-weight-bold text-indigo-darken-2">
                          {{ formatMoney(item.raw.price) }}
                        </span>
                      </v-list-item-subtitle>
                    </v-list-item>
                  </template>
                </v-autocomplete>

                <v-card v-if="selectedTests.length" variant="outlined" rounded="lg" class="mt-2">
                  <v-list density="compact" class="pa-0">
                    <template v-for="(t, i) in selectedTests" :key="t.id">
                      <v-list-item>
                        <template #prepend>
                          <v-avatar color="indigo-lighten-5" size="28">
                            <span class="text-caption font-weight-bold text-indigo-darken-2">{{ i + 1 }}</span>
                          </v-avatar>
                        </template>
                        <v-list-item-title class="font-weight-medium">
                          {{ t.code }} · {{ t.name }}
                        </v-list-item-title>
                        <v-list-item-subtitle class="text-caption">
                          {{ [t.department, t.specimen_type, t.turnaround_time].filter(Boolean).join(' · ') || '—' }}
                        </v-list-item-subtitle>
                        <template #append>
                          <span class="font-weight-medium mr-2">{{ formatMoney(t.price) }}</span>
                          <v-btn icon="mdi-close" size="x-small" variant="text" @click="removeTest(t.id)" />
                        </template>
                      </v-list-item>
                      <v-divider v-if="i < selectedTests.length - 1" />
                    </template>
                  </v-list>
                  <v-divider />
                  <div class="d-flex align-center pa-3" style="background:rgba(var(--v-theme-indigo),0.04)">
                    <v-icon color="indigo" class="mr-2">mdi-sigma</v-icon>
                    <span class="text-subtitle-2 font-weight-bold">Sum of test prices</span>
                    <v-spacer />
                    <span class="text-h6 font-weight-bold text-indigo-darken-2">
                      {{ formatMoney(sumOfSelectedPrices) }}
                    </span>
                  </div>
                  <div v-if="form.price && sumOfSelectedPrices > Number(form.price)"
                       class="d-flex align-center px-3 pb-3">
                    <v-icon color="success" size="16" class="mr-1">mdi-tag-heart</v-icon>
                    <span class="text-caption text-success font-weight-medium">
                      Patient saves {{ formatMoney(sumOfSelectedPrices - Number(form.price)) }}
                      ({{ Math.round((1 - Number(form.price) / sumOfSelectedPrices) * 100) }}% off)
                    </span>
                  </div>
                </v-card>
              </v-col>

              <v-col cols="12">
                <v-switch v-model="form.is_active" color="success" inset hide-details
                          label="Active — available for ordering" />
              </v-col>
            </v-row>
          </v-form>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="formDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" :loading="r.saving.value" @click="save">
            <v-icon start>mdi-content-save</v-icon>{{ form.id ? 'Update Panel' : 'Create Panel' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Detail dialog -->
    <v-dialog v-model="detailDialog" max-width="720" scrollable>
      <v-card v-if="detailItem" rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar :color="deptColor(detailItem.department)" size="44" class="mr-3">
            <v-icon color="white" size="22">{{ deptIcon(detailItem.department) }}</v-icon>
          </v-avatar>
          <div>
            <div class="font-monospace text-caption text-medium-emphasis">{{ detailItem.code }}</div>
            <div class="text-h6 font-weight-bold">{{ detailItem.name }}</div>
          </div>
          <v-spacer />
          <v-chip size="small" :color="detailItem.is_active ? 'success' : 'grey'" variant="tonal" class="mr-2">
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
              <div class="text-caption text-medium-emphasis">Tests</div>
              <div class="font-weight-medium">{{ detailTests.length }}</div>
            </v-col>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Panel price</div>
              <div class="text-h6 font-weight-bold text-indigo-darken-2">
                {{ formatMoney(detailItem.price) }}
              </div>
            </v-col>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Sum of test prices</div>
              <div class="font-weight-bold">{{ formatMoney(detailSum) }}</div>
              <div v-if="detailSum > Number(detailItem.price || 0)" class="text-caption text-success">
                saves {{ formatMoney(detailSum - Number(detailItem.price || 0)) }}
              </div>
            </v-col>
            <v-col v-if="detailItem.description" cols="12">
              <v-divider class="my-2" />
              <div class="text-caption text-medium-emphasis mb-1">Description</div>
              <div>{{ detailItem.description }}</div>
            </v-col>
          </v-row>

          <v-divider class="my-4" />
          <div class="d-flex align-center mb-2">
            <v-icon color="indigo" class="mr-2">mdi-flask-outline</v-icon>
            <span class="text-subtitle-2 font-weight-bold">Included tests</span>
            <v-spacer />
            <v-chip size="small" color="indigo" variant="tonal">{{ detailTests.length }}</v-chip>
          </div>

          <v-list v-if="detailTests.length" density="compact" class="pa-0">
            <template v-for="(t, i) in detailTests" :key="t.id">
              <v-list-item>
                <template #prepend>
                  <v-avatar color="indigo-lighten-5" size="30">
                    <v-icon color="indigo-darken-2" size="16">mdi-flask</v-icon>
                  </v-avatar>
                </template>
                <v-list-item-title class="font-weight-medium">
                  {{ t.code }} · {{ t.name }}
                </v-list-item-title>
                <v-list-item-subtitle class="text-caption">
                  {{ [t.department, t.specimen_type, t.turnaround_time].filter(Boolean).join(' · ') || '—' }}
                </v-list-item-subtitle>
                <template #append>
                  <span class="font-weight-medium">{{ formatMoney(t.price) }}</span>
                </template>
              </v-list-item>
              <v-divider v-if="i < detailTests.length - 1" />
            </template>
          </v-list>
          <div v-else class="text-center pa-6 text-medium-emphasis">
            <v-icon size="40" color="grey-lighten-1">mdi-flask-empty-outline</v-icon>
            <div class="mt-2 text-caption">No tests linked. Edit this panel to add tests.</div>
          </div>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-btn variant="text" prepend-icon="mdi-content-copy" @click="duplicate(detailItem)">
            Duplicate
          </v-btn>
          <v-btn variant="text" prepend-icon="mdi-printer-outline" @click="printPanel(detailItem)">
            Print
          </v-btn>
          <v-spacer />
          <v-btn variant="text" @click="detailDialog = false">Close</v-btn>
          <v-btn color="primary" rounded="lg" prepend-icon="mdi-pencil" @click="openEdit(detailItem)">
            Edit
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Delete confirm -->
    <v-dialog v-model="deleteDialog.show" max-width="420" persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center">
          <v-icon color="error" class="mr-2">mdi-alert-circle</v-icon>Delete Panel
        </v-card-title>
        <v-card-text>
          Delete <strong>{{ deleteDialog.item?.name }}</strong>? This cannot be undone.
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
import { formatMoney } from '~/utils/format'

const r = useResource('/lab/panels/')
const cat = useResource('/lab/catalog/')

const view = ref('table')
const statusFilter = ref(null)
const deptFilter = ref(null)
const sizeFilter = ref(null)
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

const departmentList = ['Hematology', 'Chemistry', 'Microbiology', 'Serology', 'Immunology',
  'Histology', 'Cytology', 'Parasitology', 'Molecular', 'Endocrinology', 'Other']

const sortOptions = [
  { title: 'Name (A → Z)', value: 'name_asc' },
  { title: 'Name (Z → A)', value: 'name_desc' },
  { title: 'Code', value: 'code_asc' },
  { title: 'Price (low → high)', value: 'price_asc' },
  { title: 'Price (high → low)', value: 'price_desc' },
  { title: 'Most tests', value: 'tests_desc' },
  { title: 'Newest', value: 'newest' },
]
const sizeOptions = [
  { title: 'Empty (no tests)', value: 'empty' },
  { title: 'Small (1–3 tests)', value: 'small' },
  { title: 'Medium (4–7 tests)', value: 'medium' },
  { title: 'Large (8+ tests)', value: 'large' },
]

const headers = [
  { title: 'Code', key: 'code', width: 120 },
  { title: 'Panel', key: 'name' },
  { title: 'Department', key: 'department', width: 140 },
  { title: 'Tests', key: 'test_names', sortable: false },
  { title: 'Price', key: 'price', align: 'end', width: 140 },
  { title: 'Active', key: 'is_active', width: 90, sortable: false },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 140 },
]

const STATUS_FILTERS = [
  { label: 'All', value: null, key: 'all' },
  { label: 'Active', value: 'active', key: 'active' },
  { label: 'Inactive', value: 'inactive', key: 'inactive' },
]

const DEPT_META = {
  Hematology: { color: 'red-darken-2', icon: 'mdi-water', hex: '#e53935' },
  Chemistry: { color: 'blue-darken-2', icon: 'mdi-flask-round-bottom', hex: '#1e88e5' },
  Microbiology: { color: 'green-darken-2', icon: 'mdi-bacteria', hex: '#43a047' },
  Serology: { color: 'orange-darken-2', icon: 'mdi-shield-cross', hex: '#fb8c00' },
  Immunology: { color: 'purple-darken-2', icon: 'mdi-shield-cross', hex: '#8e24aa' },
  Histology: { color: 'brown-darken-2', icon: 'mdi-microscope', hex: '#6d4c41' },
  Cytology: { color: 'teal-darken-2', icon: 'mdi-microscope', hex: '#00897b' },
  Parasitology: { color: 'light-green-darken-2', icon: 'mdi-bug', hex: '#7cb342' },
  Molecular: { color: 'indigo-darken-2', icon: 'mdi-dna', hex: '#3949ab' },
  Endocrinology: { color: 'pink-darken-2', icon: 'mdi-pulse', hex: '#d81b60' },
  Other: { color: 'blue-grey-darken-2', icon: 'mdi-package-variant-closed', hex: '#546e7a' },
}
function deptColor (d) { return DEPT_META[d]?.color || 'indigo-darken-2' }
function deptIcon (d) { return DEPT_META[d]?.icon || 'mdi-package-variant-closed' }
function deptHex (d) { return DEPT_META[d]?.hex || '#3949ab' }

const list = computed(() => r.items.value || [])
const catalogList = computed(() => cat.items.value || [])
const catalogById = computed(() => {
  const m = {}
  for (const t of catalogList.value) m[t.id] = t
  return m
})

const statusFilters = computed(() => {
  const arr = list.value
  const active = arr.filter(p => p.is_active).length
  const inactive = arr.length - active
  return STATUS_FILTERS.map(s => ({
    ...s,
    count: s.value === 'active' ? active : s.value === 'inactive' ? inactive : arr.length,
  }))
})

const departmentChips = computed(() => {
  const counts = list.value.reduce((acc, p) => {
    if (p.department) acc[p.department] = (acc[p.department] || 0) + 1
    return acc
  }, {})
  const tops = Object.entries(counts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 6)
    .map(([d, n]) => ({
      label: d, value: d, count: n,
      icon: DEPT_META[d]?.icon, color: DEPT_META[d]?.color || 'indigo',
    }))
  return [{ label: 'All depts', value: null }, ...tops]
})

const filtered = computed(() => {
  let arr = r.filtered.value || []
  if (statusFilter.value === 'active') arr = arr.filter(p => p.is_active)
  if (statusFilter.value === 'inactive') arr = arr.filter(p => !p.is_active)
  if (deptFilter.value) arr = arr.filter(p => p.department === deptFilter.value)
  if (sizeFilter.value) {
    arr = arr.filter(p => {
      const n = (p.test_names || []).length
      if (sizeFilter.value === 'empty') return n === 0
      if (sizeFilter.value === 'small') return n >= 1 && n <= 3
      if (sizeFilter.value === 'medium') return n >= 4 && n <= 7
      if (sizeFilter.value === 'large') return n >= 8
      return true
    })
  }
  arr = [...arr]
  switch (sortBy.value) {
    case 'name_desc': arr.sort((a, b) => (b.name || '').localeCompare(a.name || '')); break
    case 'code_asc': arr.sort((a, b) => (a.code || '').localeCompare(b.code || '')); break
    case 'price_asc': arr.sort((a, b) => Number(a.price || 0) - Number(b.price || 0)); break
    case 'price_desc': arr.sort((a, b) => Number(b.price || 0) - Number(a.price || 0)); break
    case 'tests_desc': arr.sort((a, b) => (b.test_names?.length || 0) - (a.test_names?.length || 0)); break
    case 'newest': arr.sort((a, b) => new Date(b.created_at || 0) - new Date(a.created_at || 0)); break
    default: arr.sort((a, b) => (a.name || '').localeCompare(b.name || ''))
  }
  return arr
})

const kpis = computed(() => {
  const arr = list.value
  const active = arr.filter(p => p.is_active).length
  const depts = new Set(arr.map(p => p.department).filter(Boolean)).size
  const totalTests = arr.reduce((s, p) => s + (p.test_names?.length || 0), 0)
  const avgTests = arr.length ? (totalTests / arr.length).toFixed(1) : '0'
  const prices = arr.map(p => Number(p.price || 0)).filter(n => n > 0)
  const avg = prices.length ? prices.reduce((a, b) => a + b, 0) / prices.length : 0
  return [
    { label: 'Total Panels', value: arr.length, icon: 'mdi-package-variant-closed', color: 'indigo',
      hint: `${active} active` },
    { label: 'Departments', value: depts, icon: 'mdi-stethoscope', color: 'cyan',
      hint: `${avgTests} tests / panel` },
    { label: 'Tests bundled', value: totalTests, icon: 'mdi-flask-outline', color: 'teal',
      hint: 'across all panels' },
    { label: 'Avg. price', value: formatMoney(avg), icon: 'mdi-cash-multiple', color: 'amber',
      hint: 'per panel' },
  ]
})

// ─── Form helpers ───
function emptyForm () {
  return { id: null, code: '', name: '', department: '', price: 0, description: '', is_active: true, test_ids: [] }
}
const required = v => (!!v && String(v).trim() !== '') || 'Required'
const selectedTests = computed(() => form.value.test_ids
  .map(id => catalogById.value[id]).filter(Boolean))
const sumOfSelectedPrices = computed(() => selectedTests.value
  .reduce((s, t) => s + Number(t.price || 0), 0))

const detailTests = computed(() => {
  if (!detailItem.value) return []
  const ids = (detailItem.value.tests || []).map(t => typeof t === 'object' ? t.id : t)
  return ids.map(id => catalogById.value[id]).filter(Boolean)
})
const detailSum = computed(() => detailTests.value.reduce((s, t) => s + Number(t.price || 0), 0))

function savings (p) {
  const ids = (p.tests || []).map(t => typeof t === 'object' ? t.id : t)
  const sum = ids.reduce((s, id) => s + Number(catalogById.value[id]?.price || 0), 0)
  return Math.max(0, sum - Number(p.price || 0))
}

// ─── Actions ───
function openNew () { form.value = emptyForm(); formDialog.value = true }
function openEdit (it) {
  form.value = {
    ...emptyForm(), ...it,
    test_ids: (it.tests || []).map(t => typeof t === 'object' ? t.id : t),
  }
  detailDialog.value = false
  formDialog.value = true
}
function openDetail (it) { detailItem.value = it; detailDialog.value = true }
function removeTest (id) { form.value.test_ids = form.value.test_ids.filter(x => x !== id) }
function duplicate (it) {
  form.value = {
    ...emptyForm(), ...it, id: null,
    code: `${it.code}-COPY`,
    name: `${it.name} (Copy)`,
    test_ids: (it.tests || []).map(t => typeof t === 'object' ? t.id : t),
  }
  detailDialog.value = false
  formDialog.value = true
}
async function save () {
  const { valid } = (await formRef.value?.validate?.()) || { valid: true }
  if (!valid) return
  try {
    const payload = { ...form.value, price: Number(form.value.price || 0) }
    if (payload.id) await r.update(payload.id, payload)
    else await r.create(payload)
    formDialog.value = false
    notify(`Panel ${form.value.id ? 'updated' : 'created'} successfully`)
    await r.list()
  } catch (e) { notify(r.error.value || 'Save failed', 'error') }
}
async function toggleActive (it, value) {
  const next = value === undefined ? !it.is_active : value
  try {
    await r.update(it.id, { is_active: next })
    it.is_active = next
    notify(`Panel ${next ? 'activated' : 'deactivated'}`)
  } catch (e) { notify(r.error.value || 'Update failed', 'error') }
}
function confirmDelete (it) { deleteDialog.item = it; deleteDialog.show = true }
async function doDelete () {
  deleteDialog.busy = true
  try {
    await r.remove(deleteDialog.item.id)
    notify('Panel deleted')
    deleteDialog.show = false
    detailDialog.value = false
  } catch (e) { notify(r.error.value || 'Delete failed', 'error') }
  finally { deleteDialog.busy = false }
}

// ─── Bulk ───
async function bulkSetActive (active) {
  bulkBusy.value = true
  try {
    await Promise.all(selected.value.map(id => r.update(id, { is_active: active })))
    notify(`${selected.value.length} panel(s) ${active ? 'activated' : 'deactivated'}`)
    selected.value = []
    await r.list()
  } catch (e) { notify(r.error.value || 'Bulk update failed', 'error') }
  finally { bulkBusy.value = false }
}
async function bulkDelete () {
  if (!confirm(`Delete ${selected.value.length} panel(s)? This cannot be undone.`)) return
  bulkBusy.value = true
  try {
    await Promise.all(selected.value.map(id => r.remove(id)))
    notify(`${selected.value.length} panel(s) deleted`)
    selected.value = []
  } catch (e) { notify(r.error.value || 'Bulk delete failed', 'error') }
  finally { bulkBusy.value = false }
}

// ─── Misc ───
function resetFilters () {
  statusFilter.value = null
  deptFilter.value = null
  sizeFilter.value = null
  sortBy.value = 'name_asc'
  r.search.value = ''
}
function reload () { r.list(); cat.list() }
function notify (text, color = 'success') { snack.text = text; snack.color = color; snack.show = true }

function exportCsv () {
  const rows = filtered.value
  if (!rows.length) return
  const cols = ['code', 'name', 'department', 'tests', 'tests_count', 'price', 'sum_of_tests', 'savings', 'active']
  const header = cols.join(',')
  const body = rows.map(p => [
    `"${(p.code || '').replace(/"/g, '""')}"`,
    `"${(p.name || '').replace(/"/g, '""')}"`,
    `"${(p.department || '').replace(/"/g, '""')}"`,
    `"${(p.test_names || []).join('; ').replace(/"/g, '""')}"`,
    (p.test_names || []).length,
    Number(p.price || 0),
    (p.tests || []).reduce((s, t) => s + Number(catalogById.value[typeof t === 'object' ? t.id : t]?.price || 0), 0),
    savings(p),
    p.is_active ? 'yes' : 'no',
  ].join(',')).join('\n')
  const blob = new Blob([header + '\n' + body], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `lab-panels_${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

function printPanel (item) {
  const w = window.open('', '_blank')
  if (!w) return
  const ids = (item.tests || []).map(t => typeof t === 'object' ? t.id : t)
  const tests = ids.map(id => catalogById.value[id]).filter(Boolean)
  const sum = tests.reduce((s, t) => s + Number(t.price || 0), 0)
  const rows = tests.map(t => `
    <tr>
      <td>${t.code || ''}</td>
      <td>${t.name || ''}</td>
      <td>${t.specimen_type || ''}</td>
      <td style="text-align:right">${formatMoney(t.price)}</td>
    </tr>`).join('')
  w.document.write(`
    <html><head><title>${item.code} — ${item.name}</title>
    <style>
      body{font-family:Arial,sans-serif;padding:32px;color:#222}
      h1{margin:0 0 4px;font-size:22px}
      .muted{color:#666;font-size:13px}
      .row{display:flex;justify-content:space-between;margin:12px 0}
      table{width:100%;border-collapse:collapse;margin-top:8px}
      th,td{border-bottom:1px solid #eee;padding:8px;text-align:left;font-size:13px}
      th{background:#f8f8fc;color:#333}
      .badge{display:inline-block;padding:2px 8px;border-radius:6px;background:#eef;color:#225;font-size:12px}
      .total{font-weight:700;font-size:16px}
    </style></head>
    <body>
      <h1>Lab Test Panel</h1>
      <div class="muted">${item.code} · ${new Date().toLocaleString()}</div>
      <div class="row"><div><b>${item.name}</b></div>
        <div><span class="badge">${item.department || 'General'}</span></div></div>
      ${item.description ? `<p class="muted">${item.description}</p>` : ''}
      <h3>Tests included (${tests.length})</h3>
      <table>
        <thead><tr><th>Code</th><th>Test</th><th>Specimen</th><th style="text-align:right">Price</th></tr></thead>
        <tbody>${rows || '<tr><td colspan="4" class="muted">No tests linked.</td></tr>'}</tbody>
      </table>
      <div class="row"><div>Sum of test prices</div><div>${formatMoney(sum)}</div></div>
      <div class="row total"><div>Panel price</div><div>${formatMoney(item.price)}</div></div>
      ${sum > Number(item.price || 0) ? `<div class="row" style="color:#2e7d32"><div>Patient saves</div><div>${formatMoney(sum - Number(item.price || 0))}</div></div>` : ''}
    </body></html>
  `)
  w.document.close()
  w.print()
}

onMounted(() => { r.list(); cat.list() })
</script>

<style scoped>
.kpi { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.panel-table :deep(tbody tr) { cursor: pointer; }
.panel-card {
  position: relative;
  overflow: hidden;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  cursor: pointer;
  transition: transform 120ms ease, box-shadow 120ms ease;
}
.panel-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.06); }
.panel-band {
  position: absolute; top: 0; left: 0; right: 0;
  height: 3px;
}
.panel-desc {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.bulk-bar { border: 1px solid rgba(var(--v-theme-primary), 0.2); background: rgba(var(--v-theme-primary), 0.04); }
.min-width-0 { min-width: 0; }
.font-monospace { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
</style>
