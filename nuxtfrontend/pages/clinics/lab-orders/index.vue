<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="teal-lighten-5" size="48">
        <v-icon color="teal-darken-2" size="28">mdi-microscope</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Lab Orders</div>
        <div class="text-body-2 text-medium-emphasis">Manage laboratory orders, test catalog &amp; results</div>
      </div>
      <v-spacer />
      <v-btn v-if="mainTab === 'orders'" variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
             :loading="loading" @click="load">Refresh</v-btn>
      <v-btn v-if="mainTab === 'orders'" color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus"
             to="/clinics/lab-orders/new">New Order</v-btn>
      <v-btn v-if="mainTab === 'catalog'" color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus"
             @click="openTestDialog()">Add Test</v-btn>
      <v-btn v-if="mainTab === 'catalog'" variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-database-seed"
             :loading="seedingCatalog" @click="seedDialog = true">Seed Demo</v-btn>
      <v-btn v-if="mainTab === 'panels'" color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus"
             @click="openPanelDialog()">Add Panel</v-btn>
    </div>

    <!-- Main tabs -->
    <v-tabs v-model="mainTab" color="primary" density="compact" class="mb-4">
      <v-tab value="orders" prepend-icon="mdi-clipboard-text-clock">Orders ({{ orders.length }})</v-tab>
      <v-tab value="catalog" prepend-icon="mdi-test-tube">Lab Tests ({{ testCatalog.length }})</v-tab>
      <v-tab value="panels" prepend-icon="mdi-package-variant-closed">Panels ({{ panels.length }})</v-tab>
    </v-tabs>

    <!-- ───────── ORDERS TAB ───────── -->
    <template v-if="mainTab === 'orders'">
    <!-- KPI cards -->
    <v-row dense class="mb-4">
      <v-col v-for="k in kpis" :key="k.label" cols="6" sm="4" md="2">
        <v-card flat rounded="lg" class="kpi-card pa-4 text-center cursor-pointer"
                :class="{ 'kpi-card--active': tabStatus === k.filter }"
                @click="tabStatus = tabStatus === k.filter ? '' : k.filter">
          <v-avatar :color="k.color" size="40" class="mb-2" variant="tonal">
            <v-icon size="22">{{ k.icon }}</v-icon>
          </v-avatar>
          <div class="text-h5 font-weight-bold">{{ k.value }}</div>
          <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ── Stats Analysis ── -->
    <v-row dense class="mb-4">
      <v-col v-if="!orders.length" cols="12">
        <v-card flat rounded="xl" class="stat-card pa-4 text-center">
          <v-icon color="teal" size="32" class="mb-2">mdi-chart-box</v-icon>
          <div class="text-subtitle-2 font-weight-bold mb-1">Lab Order Analytics</div>
          <div class="text-caption text-medium-emphasis">
            Status, priority, weekday and department distributions will appear here once orders are created.
          </div>
        </v-card>
      </v-col>
      <template v-else>
        <!-- Status Distribution -->
        <v-col cols="12" sm="6" md="3">
          <v-card flat rounded="xl" class="stat-card pa-4 fill-height">
            <div class="d-flex align-center mb-3">
              <v-icon color="teal" size="20" class="mr-2">mdi-chart-donut</v-icon>
              <span class="text-subtitle-2 font-weight-bold">Status Distribution</span>
            </div>
            <div v-for="s in statusStats" :key="s.value" class="mb-2">
              <div class="d-flex justify-space-between text-caption mb-1">
                <span class="text-medium-emphasis">{{ s.label }}</span>
                <span class="font-weight-bold">{{ s.count }} ({{ s.pct }}%)</span>
              </div>
              <v-progress-linear :model-value="s.pct" :color="s.color" height="6" rounded rounded-bar />
            </div>
          </v-card>
        </v-col>

        <!-- Priority Distribution -->
        <v-col cols="12" sm="6" md="3">
          <v-card flat rounded="xl" class="stat-card pa-4 fill-height">
            <div class="d-flex align-center mb-3">
              <v-icon color="orange" size="20" class="mr-2">mdi-flag-variant</v-icon>
              <span class="text-subtitle-2 font-weight-bold">Priority</span>
            </div>
            <div v-for="p in priorityStats" :key="p.value" class="mb-2">
              <div class="d-flex justify-space-between text-caption mb-1">
                <span class="text-medium-emphasis">{{ p.label }}</span>
                <span class="font-weight-bold">{{ p.count }} ({{ p.pct }}%)</span>
              </div>
              <v-progress-linear :model-value="p.pct" :color="p.color" height="6" rounded rounded-bar />
            </div>
          </v-card>
        </v-col>

        <!-- Days of Week -->
        <v-col cols="12" sm="6" md="3">
          <v-card flat rounded="xl" class="stat-card pa-4 fill-height">
            <div class="d-flex align-center mb-3">
              <v-icon color="indigo" size="20" class="mr-2">mdi-calendar-blank</v-icon>
              <span class="text-subtitle-2 font-weight-bold">Orders by Weekday</span>
            </div>
            <div v-for="d in weekdayStats" :key="d.label" class="mb-1">
              <div class="d-flex justify-space-between text-caption mb-1">
                <span class="text-medium-emphasis">{{ d.label }}</span>
                <span class="font-weight-bold">{{ d.count }}</span>
              </div>
              <v-progress-linear :model-value="weekdayMax ? (d.count / weekdayMax * 100) : 0" color="indigo" height="5" rounded rounded-bar />
            </div>
          </v-card>
        </v-col>

        <!-- Department Distribution -->
        <v-col cols="12" sm="6" md="3">
          <v-card flat rounded="xl" class="stat-card pa-4 fill-height">
            <div class="d-flex align-center mb-3">
              <v-icon color="deep-purple" size="20" class="mr-2">mdi-folder-table</v-icon>
              <span class="text-subtitle-2 font-weight-bold">Top Departments</span>
            </div>
            <div v-for="d in departmentStats" :key="d.name" class="mb-2">
              <div class="d-flex align-center text-caption mb-1">
                <v-chip :color="deptColor(d.name)" size="x-small" variant="tonal" class="mr-2">{{ d.name }}</v-chip>
                <v-spacer />
                <span class="font-weight-bold">{{ d.count }}</span>
              </div>
              <v-progress-linear
                :model-value="departmentMax ? (d.count / departmentMax * 100) : 0"
                :color="deptColor(d.name)" height="5" rounded rounded-bar />
            </div>
            <div v-if="!departmentStats.length" class="text-caption text-medium-emphasis text-center pt-2">
              No department data
            </div>
          </v-card>
        </v-col>
      </template>
    </v-row>

    <!-- Filters -->
    <v-card flat rounded="xl" class="pa-3 mb-4 filter-bar">
      <v-row dense align="center">
        <v-col cols="12" sm="4" md="3">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
            placeholder="Search patient, test, accession…"
            variant="outlined" density="compact" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="6" sm="3" md="2">
          <v-select v-model="filterPriority" :items="priorityOptions" label="Priority"
                    variant="outlined" density="compact" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="6" sm="3" md="2">
          <v-select v-model="filterDepartment" :items="departmentOptions" label="Department"
                    variant="outlined" density="compact" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="6" sm="3" md="2">
          <v-select v-model="filterHome" :items="homeOptions" label="Collection"
                    variant="outlined" density="compact" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="6" sm="12" md="3" class="d-flex align-center justify-end ga-2">
          <v-btn v-if="hasFilters" variant="text" size="small" class="text-none"
                 prepend-icon="mdi-filter-off" @click="clearFilters">Clear</v-btn>
          <v-btn-toggle v-model="viewMode" mandatory density="compact" rounded="lg" color="primary">
            <v-btn value="table" icon="mdi-format-list-bulleted" size="small" />
            <v-btn value="kanban" icon="mdi-view-column" size="small" />
          </v-btn-toggle>
        </v-col>
      </v-row>
    </v-card>

    <!-- Status tabs -->
    <v-tabs v-model="tabStatus" class="mb-3" density="compact" color="primary" show-arrows>
      <v-tab value="">All ({{ orders.length }})</v-tab>
      <v-tab v-for="s in statusOptions" :key="s.value" :value="s.value">
        {{ s.title }} ({{ orders.filter(o => o.status === s.value).length }})
      </v-tab>
    </v-tabs>

    <!-- TABLE VIEW -->
    <v-card v-if="viewMode === 'table'" flat rounded="xl" class="overflow-hidden">
      <v-data-table :headers="headers" :items="filtered" :search="search" :loading="loading"
        density="comfortable" hover items-per-page="25" class="orders-table"
        @click:row="(_, { item }) => $router.push(`/clinics/lab-orders/${item.id}`)">
        <template #loading><v-skeleton-loader type="table-row@6" /></template>
        <template #item.patient_name="{ item }">
          <div class="d-flex align-center py-2">
            <v-avatar :color="avatarColor(item.patient || item.id)" size="34" class="mr-2">
              <span class="text-white text-caption font-weight-bold">{{ patientInitials(item) }}</span>
            </v-avatar>
            <div>
              <div class="font-weight-medium text-body-2">{{ item.patient_name || '—' }}</div>
              <div class="text-caption text-medium-emphasis">ID: {{ item.patient }}</div>
            </div>
          </div>
        </template>
        <template #item.test_names="{ item }">
          <div v-if="item.test_names && item.test_names.length" class="d-flex flex-wrap ga-1">
            <v-chip v-for="t in item.test_names.slice(0,2)" :key="t" size="x-small" variant="tonal" color="teal">{{ t }}</v-chip>
            <v-chip v-if="item.test_names.length > 2" size="x-small" variant="outlined">+{{ item.test_names.length - 2 }}</v-chip>
          </div>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
        <template #item.priority="{ item }">
          <v-chip size="x-small" :variant="item.priority === 'stat' ? 'flat' : 'tonal'" :color="priorityColor(item.priority)">
            <v-icon v-if="item.priority === 'stat'" size="12" start class="blink">mdi-alert</v-icon>
            {{ priorityLabel(item.priority) }}
          </v-chip>
        </template>
        <template #item.status="{ item }"><StatusChip :status="item.status" /></template>
        <template #item.is_home_collection="{ item }">
          <v-chip v-if="item.is_home_collection" size="x-small" variant="tonal" color="purple" prepend-icon="mdi-home-clock">Home</v-chip>
          <v-icon v-else size="18" color="grey-lighten-1">mdi-hospital-box</v-icon>
        </template>
        <template #item.created_at="{ value }">
          <div class="text-body-2">{{ fmtDate(value) }}</div>
          <div class="text-caption text-medium-emphasis">{{ timeAgo(value) }}</div>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end ga-1" @click.stop>
            <v-btn icon="mdi-eye" size="x-small" variant="text" :to="`/clinics/lab-orders/${item.id}`" />
            <v-btn v-if="canEdit(item)" icon="mdi-pencil" size="x-small" variant="text" :to="`/clinics/lab-orders/${item.id}/edit`" />
          </div>
        </template>
        <template #no-data>
          <div class="pa-10 text-center">
            <v-icon size="64" color="grey-lighten-1">mdi-microscope</v-icon>
            <div class="text-subtitle-1 font-weight-medium mt-3">No lab orders found</div>
            <div class="text-body-2 text-medium-emphasis mb-4">Create your first laboratory order.</div>
            <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" to="/clinics/lab-orders/new">New Order</v-btn>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- KANBAN VIEW -->
    <div v-else class="kanban-container">
      <div v-for="col in kanbanCols" :key="col.value" class="kanban-col">
        <div class="kanban-col-header pa-3 mb-2 rounded-xl" :style="{ borderTop: `3px solid ${col.hc}` }">
          <div class="d-flex align-center">
            <v-icon :color="col.hc" size="18" class="mr-2">{{ col.icon }}</v-icon>
            <span class="text-subtitle-2 font-weight-bold">{{ col.title }}</span>
            <v-spacer />
            <v-chip size="x-small" variant="tonal" :color="col.hc">{{ kanbanItems(col.value).length }}</v-chip>
          </div>
        </div>
        <div class="kanban-cards">
          <v-card v-for="o in kanbanItems(col.value)" :key="o.id" flat rounded="lg"
            class="kanban-card pa-3 mb-2 cursor-pointer" @click="$router.push(`/clinics/lab-orders/${o.id}`)">
            <div class="d-flex align-center mb-2">
              <v-avatar :color="avatarColor(o.patient || o.id)" size="28" class="mr-2">
                <span class="text-white" style="font-size:10px;font-weight:700">{{ patientInitials(o) }}</span>
              </v-avatar>
              <div class="text-body-2 font-weight-medium text-truncate flex-grow-1">{{ o.patient_name }}</div>
              <v-chip size="x-small" :variant="o.priority==='stat'?'flat':'tonal'" :color="priorityColor(o.priority)" class="ml-1">{{ priorityLabel(o.priority) }}</v-chip>
            </div>
            <div v-if="o.test_names && o.test_names.length" class="d-flex flex-wrap ga-1 mb-1">
              <v-chip v-for="t in o.test_names.slice(0,2)" :key="t" size="x-small" variant="outlined" color="teal">{{ t }}</v-chip>
              <v-chip v-if="o.test_names.length > 2" size="x-small" variant="outlined">+{{ o.test_names.length - 2 }}</v-chip>
            </div>
            <div class="text-caption text-medium-emphasis mb-1">
              <v-icon size="12" class="mr-1">mdi-test-tube</v-icon>
              {{ o.test_names?.length || 0 }} test{{ (o.test_names?.length || 0) > 1 ? 's' : '' }}
              <span v-if="o.is_home_collection" class="ml-1"><v-icon size="12" color="purple">mdi-home-clock</v-icon></span>
            </div>
            <div class="d-flex align-center justify-space-between mt-2">
              <span class="text-caption text-medium-emphasis">{{ timeAgo(o.created_at) }}</span>
              <v-chip v-if="o.results && o.results.length" size="x-small" variant="tonal" color="success">
                <v-icon size="10" start>mdi-check</v-icon>{{ o.results.length }} result{{ o.results.length > 1 ? 's' : '' }}
              </v-chip>
            </div>
          </v-card>
          <div v-if="!kanbanItems(col.value).length" class="text-center pa-4 text-caption text-medium-emphasis">No orders</div>
        </div>
      </div>
    </div>
    </template>

    <!-- ───────── LAB TESTS (CATALOG) TAB ───────── -->
    <template v-if="mainTab === 'catalog'">
      <v-card flat rounded="xl" class="pa-3 mb-4 filter-bar">
        <v-row dense align="center">
          <v-col cols="12" sm="6" md="4">
            <v-text-field v-model="testSearch" prepend-inner-icon="mdi-magnify"
              placeholder="Search test name, code…"
              variant="outlined" density="compact" hide-details clearable rounded="lg" />
          </v-col>
          <v-col cols="6" sm="3" md="2">
            <v-select v-model="testDeptFilter" :items="testDepartments" label="Department"
              variant="outlined" density="compact" hide-details clearable rounded="lg" />
          </v-col>
          <v-col cols="6" sm="3" md="2">
            <v-select v-model="testActiveFilter" :items="[{title:'Active',value:true},{title:'Inactive',value:false}]" label="Status"
              variant="outlined" density="compact" hide-details clearable rounded="lg" />
          </v-col>
        </v-row>
      </v-card>

      <v-card flat rounded="xl" class="overflow-hidden">
        <v-data-table :headers="testHeaders" :items="filteredTests" :search="testSearch" :loading="testLoading"
          density="comfortable" hover items-per-page="25" class="catalog-table">
          <template #loading><v-skeleton-loader type="table-row@6" /></template>
          <template #item.name="{ item }">
            <div class="py-2">
              <div class="font-weight-medium text-body-2">{{ item.name }}</div>
              <div class="text-caption text-medium-emphasis">{{ item.code }}</div>
            </div>
          </template>
          <template #item.department="{ value }">
            <v-chip size="x-small" variant="tonal" :color="deptColor(value)">{{ value || '—' }}</v-chip>
          </template>
          <template #item.specimen_type="{ value }">
            <div class="text-body-2"><v-icon size="14" class="mr-1" color="grey">mdi-droplet</v-icon>{{ value || '—' }}</div>
          </template>
          <template #item.reference_ranges="{ value }">
            <div v-if="value && Object.keys(value).length" class="d-flex flex-wrap ga-1">
              <v-chip v-for="(v, k) in value" :key="k" size="x-small" variant="outlined" class="text-caption">
                {{ k }}: {{ v }}
              </v-chip>
            </div>
            <span v-else class="text-medium-emphasis text-caption">—</span>
          </template>
          <template #item.price="{ value }">{{ formatMoney(value) }}</template>
          <template #item.turnaround_time="{ value }">
            <div class="text-body-2"><v-icon size="14" class="mr-1" color="grey">mdi-clock-outline</v-icon>{{ value || '—' }}</div>
          </template>
          <template #item.is_active="{ item }">
            <v-chip :color="item.is_active ? 'success' : 'grey'" size="x-small" variant="tonal">
              {{ item.is_active ? 'Active' : 'Inactive' }}
            </v-chip>
          </template>
          <template #item.actions="{ item }">
            <div class="d-flex justify-end ga-1" @click.stop>
              <v-btn icon="mdi-pencil" size="x-small" variant="text" @click="openTestDialog(item)" />
              <v-btn icon="mdi-delete" size="x-small" variant="text" color="error" @click="deleteTest(item)" />
            </div>
          </template>
          <template #no-data>
            <div class="pa-10 text-center">
              <v-icon size="64" color="grey-lighten-1">mdi-test-tube</v-icon>
              <div class="text-subtitle-1 font-weight-medium mt-3">No lab tests found</div>
              <div class="text-body-2 text-medium-emphasis mb-4">Add your first lab test to the catalog.</div>
              <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openTestDialog()">Add Test</v-btn>
            </div>
          </template>
        </v-data-table>
      </v-card>
    </template>

    <!-- ───────── PANELS TAB ───────── -->
    <template v-if="mainTab === 'panels'">
      <v-card flat rounded="xl" class="pa-3 mb-4 filter-bar">
        <v-row dense align="center">
          <v-col cols="12" sm="6" md="4">
            <v-text-field v-model="panelSearch" prepend-inner-icon="mdi-magnify"
              placeholder="Search panel name, code…"
              variant="outlined" density="compact" hide-details clearable rounded="lg" />
          </v-col>
        </v-row>
      </v-card>

      <v-card flat rounded="xl" class="overflow-hidden">
        <v-data-table :headers="panelHeaders" :items="filteredPanels" :search="panelSearch" :loading="panelLoading"
          density="comfortable" hover items-per-page="25">
          <template #loading><v-skeleton-loader type="table-row@6" /></template>
          <template #item.name="{ item }">
            <div class="py-2">
              <div class="font-weight-medium text-body-2">{{ item.name }}</div>
              <div class="text-caption text-medium-emphasis">{{ item.code }}</div>
            </div>
          </template>
          <template #item.department="{ value }">
            <v-chip size="x-small" variant="tonal" :color="deptColor(value)">{{ value || '—' }}</v-chip>
          </template>
          <template #item.test_names="{ item }">
            <div v-if="item.test_names && item.test_names.length" class="d-flex flex-wrap ga-1">
              <v-chip v-for="t in item.test_names.slice(0,3)" :key="t" size="x-small" variant="tonal" color="teal">{{ t }}</v-chip>
              <v-chip v-if="item.test_names.length > 3" size="x-small" variant="outlined">+{{ item.test_names.length - 3 }}</v-chip>
            </div>
            <span v-else class="text-medium-emphasis text-caption">—</span>
          </template>
          <template #item.price="{ value }">{{ formatMoney(value) }}</template>
          <template #item.is_active="{ item }">
            <v-chip :color="item.is_active ? 'success' : 'grey'" size="x-small" variant="tonal">
              {{ item.is_active ? 'Active' : 'Inactive' }}
            </v-chip>
          </template>
          <template #item.actions="{ item }">
            <div class="d-flex justify-end ga-1" @click.stop>
              <v-btn icon="mdi-pencil" size="x-small" variant="text" @click="openPanelDialog(item)" />
              <v-btn icon="mdi-delete" size="x-small" variant="text" color="error" @click="deletePanel(item)" />
            </div>
          </template>
          <template #no-data>
            <div class="pa-10 text-center">
              <v-icon size="64" color="grey-lighten-1">mdi-package-variant-closed</v-icon>
              <div class="text-subtitle-1 font-weight-medium mt-3">No panels found</div>
              <div class="text-body-2 text-medium-emphasis mb-4">Create a test panel to bundle tests.</div>
              <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openPanelDialog()">Add Panel</v-btn>
            </div>
          </template>
        </v-data-table>
      </v-card>
    </template>

    <!-- ── Test add/edit dialog ── -->
    <v-dialog v-model="testDialog" max-width="700">
      <v-card rounded="xl">
        <v-card-title class="text-h6">{{ editingTest?.id ? 'Edit Test' : 'Add Lab Test' }}</v-card-title>
        <v-card-text>
          <v-form ref="testFormRef">
            <v-row dense>
              <v-col cols="12" sm="7">
                <v-text-field v-model="testForm.name" label="Test Name" :rules="req" variant="outlined" density="compact" rounded="lg" />
              </v-col>
              <v-col cols="12" sm="5">
                <v-text-field v-model="testForm.code" label="Code" :rules="req" variant="outlined" density="compact" rounded="lg" />
              </v-col>
              <v-col cols="12" sm="6">
                <div class="text-caption text-medium-emphasis mb-1">Department</div>
                <div class="d-flex flex-wrap ga-1">
                  <v-chip v-for="d in testDepartments" :key="d" size="x-small" variant="outlined"
                    :color="testForm.department === d ? deptColor(d) : 'default'"
                    :class="{ 'common-chip--active': testForm.department === d }"
                    @click="testForm.department = d">
                    {{ d }}
                  </v-chip>
                </div>
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="testForm.specimen_type" label="Specimen Type"
                  variant="outlined" density="compact" rounded="lg" placeholder="e.g., Blood (EDTA)" />
                <div class="text-caption text-medium-emphasis mt-1 mb-1">
                  <v-icon size="12" class="mr-1">mdi-radiobox-marked</v-icon>Common specimens — click to select
                </div>
                <div class="d-flex flex-wrap ga-1">
                  <v-chip v-for="s in specimenOptions" :key="s" size="x-small" variant="outlined"
                    :color="testForm.specimen_type === s ? 'teal' : 'default'"
                    :class="{ 'common-chip--active': testForm.specimen_type === s }"
                    @click="testForm.specimen_type = s">
                    <v-icon size="12" start>{{ specimenIcon(s) }}</v-icon>{{ s }}
                  </v-chip>
                </div>
              </v-col>
              <v-col cols="6" sm="4">
                <v-text-field v-model="testForm.price" label="Price" type="number" prefix="KSh"
                  variant="outlined" density="compact" rounded="lg" />
              </v-col>
              <v-col cols="6" sm="4">
                <v-text-field v-model="testForm.turnaround_time" label="Turnaround Time"
                  variant="outlined" density="compact" rounded="lg" placeholder="e.g., 2 hours" />
              </v-col>
              <v-col cols="12" sm="4">
                <v-checkbox v-model="testForm.is_active" label="Active" color="success" hide-details density="compact" />
              </v-col>
              <v-col cols="12">
                <div class="text-caption text-medium-emphasis mb-1">Reference Ranges (key-value pairs)</div>
                <div v-for="(r, i) in testRanges" :key="i" class="d-flex ga-2 mb-2">
                  <v-text-field v-model="r.key" placeholder="Parameter (e.g., WBC)" density="compact" variant="outlined" hide-details rounded="lg" />
                  <v-text-field v-model="r.value" placeholder="Range (e.g., 4.0-11.0)" density="compact" variant="outlined" hide-details rounded="lg" />
                  <v-btn icon="mdi-close" variant="text" color="error" size="small" @click="testRanges.splice(i, 1)" />
                </div>
                <v-btn variant="tonal" size="small" prepend-icon="mdi-plus" @click="testRanges.push({ key: '', value: '' })">Add Range</v-btn>
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="testForm.instructions" label="Instructions" rows="2" auto-grow
                  variant="outlined" density="compact" rounded="lg" />
              </v-col>
            </v-row>
          </v-form>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="testDialog = false">Cancel</v-btn>
          <v-btn color="primary" :loading="testSaving" @click="saveTest">{{ editingTest?.id ? 'Save' : 'Add Test' }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Panel add/edit dialog ── -->
    <v-dialog v-model="panelDialog" max-width="700">
      <v-card rounded="xl">
        <v-card-title class="text-h6">{{ editingPanel?.id ? 'Edit Panel' : 'Add Lab Panel' }}</v-card-title>
        <v-card-text>
          <v-form ref="panelFormRef">
            <v-row dense>
              <v-col cols="12" sm="7">
                <v-text-field v-model="panelForm.name" label="Panel Name" :rules="req" variant="outlined" density="compact" rounded="lg" />
              </v-col>
              <v-col cols="12" sm="5">
                <v-text-field v-model="panelForm.code" label="Code" :rules="req" variant="outlined" density="compact" rounded="lg" />
              </v-col>
              <v-col cols="12" sm="6">
                <div class="text-caption text-medium-emphasis mb-1">Department</div>
                <div class="d-flex flex-wrap ga-1">
                  <v-chip v-for="d in testDepartments" :key="d" size="x-small" variant="outlined"
                    :color="panelForm.department === d ? deptColor(d) : 'default'"
                    :class="{ 'common-chip--active': panelForm.department === d }"
                    @click="panelForm.department = d">
                    {{ d }}
                  </v-chip>
                </div>
              </v-col>
              <v-col cols="6" sm="4">
                <v-text-field v-model="panelForm.price" label="Price" type="number" prefix="KSh"
                  variant="outlined" density="compact" rounded="lg" />
              </v-col>
              <v-col cols="6" sm="4">
                <v-checkbox v-model="panelForm.is_active" label="Active" color="success" hide-details density="compact" />
              </v-col>
              <v-col cols="12">
                <v-autocomplete v-model="panelForm.test_ids" :items="testCatalog" item-title="name" item-value="id"
                  label="Tests in Panel" multiple chips closable-chips clearable :rules="testCountReq"
                  variant="outlined" density="compact" rounded="lg" prepend-inner-icon="mdi-test-tube">
                  <template #item="{ item, props: p }">
                    <v-list-item v-bind="p">
                      <v-list-item-subtitle>{{ item.raw.department }} · {{ formatMoney(item.raw.price) }}</v-list-item-subtitle>
                    </v-list-item>
                  </template>
                </v-autocomplete>
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="panelForm.description" label="Description" rows="2" auto-grow
                  variant="outlined" density="compact" rounded="lg" />
              </v-col>
            </v-row>
          </v-form>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="panelDialog = false">Cancel</v-btn>
          <v-btn color="primary" :loading="panelSaving" @click="savePanel">{{ editingPanel?.id ? 'Save' : 'Add Panel' }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Seed Demo Dialog -->
    <v-dialog v-model="seedDialog" max-width="520">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center ga-2">
          <v-icon color="primary">mdi-database-seed</v-icon>
          Seed Demo Lab Tests &amp; Panels
        </v-card-title>
        <v-card-text>
          This will populate the catalog with <strong>72 common lab tests</strong> and
          <strong>21 panels</strong> (CBC, LFT, Lipid Profile, Thyroid Panel, etc.).
          <v-alert type="info" variant="tonal" density="compact" class="mt-3 mb-0" rounded="lg">
            Existing tests/panels with the same code will be updated. No data is deleted.
          </v-alert>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="seedDialog = false">Cancel</v-btn>
          <v-btn color="primary" :loading="seedingCatalog" @click="seedCatalog">Seed Now</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Seed Result Snackbar -->
    <v-snackbar v-model="seedSnackbar" :color="seedError ? 'error' : 'success'" :timeout="6000" location="top">
      <span v-if="seedError">{{ seedError }}</span>
      <span v-else>
        Seeded: {{ seedResult?.tests_created || 0 }} new tests, {{ seedResult?.tests_updated || 0 }} updated,
        {{ seedResult?.panels_created || 0 }} new panels.
      </span>
      <template #actions>
        <v-btn variant="text" @click="seedSnackbar = false">Close</v-btn>
      </template>
    </v-snackbar>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
import { useAuthStore } from '~/stores/auth'
const auth = useAuthStore()

// Doctors / clinical officers / dentists only see their own lab orders
const isDoctor = ['doctor', 'clinical_officer', 'dentist'].includes(auth.role)
const loading = ref(false)
const orders = ref([])
const search = ref('')
const filterPriority = ref(null)
const filterDepartment = ref(null)
const filterHome = ref(null)
const tabStatus = ref('')
const viewMode = ref('table')
const mainTab = ref('orders')

// ── Lab Test Catalog state ──
const testCatalog = ref([])
const testLoading = ref(false)
const testSearch = ref('')
const testDeptFilter = ref(null)
const testActiveFilter = ref(null)
const testDialog = ref(false)
const testSaving = ref(false)

// ── Seed demo state ──
const seedDialog = ref(false)
const seedingCatalog = ref(false)
const seedResult = ref(null)
const seedError = ref('')
const seedSnackbar = ref(false)
const testFormRef = ref(null)
const editingTest = ref(null)
const testRanges = ref([])
const testForm = reactive({ name: '', code: '', department: '', specimen_type: '', price: 0, turnaround_time: '', instructions: '', is_active: true })
const req = [v => (v != null && v !== '') || 'Required']
const testCountReq = [v => (Array.isArray(v) && v.length > 0) || 'Select at least one test']

// ── Panels state ──
const panels = ref([])
const panelLoading = ref(false)
const panelSearch = ref('')
const panelDialog = ref(false)
const panelSaving = ref(false)
const panelFormRef = ref(null)
const editingPanel = ref(null)
const panelForm = reactive({ name: '', code: '', department: '', price: 0, is_active: true, test_ids: [], description: '' })

const statusOptions = [
  { title: 'Pending', value: 'pending' },
  { title: 'Sample Collected', value: 'sample_collected' },
  { title: 'Processing', value: 'processing' },
  { title: 'Completed', value: 'completed' },
  { title: 'Cancelled', value: 'cancelled' },
]
const priorityOptions = [
  { title: 'Routine', value: 'routine' }, { title: 'Urgent', value: 'urgent' }, { title: 'STAT', value: 'stat' },
]
const homeOptions = [
  { title: 'Home Collection', value: true }, { title: 'In-house', value: false },
]
const departmentOptions = [
  'Hematology', 'Biochemistry', 'Microbiology', 'Pathology', 'Serology', 'Endocrinology', 'Immunology', 'Molecular', 'Urinalysis', 'Parasitology', 'Oncology', 'Other',
]
const testDepartments = computed(() => {
  const set = new Set(departmentOptions)
  for (const t of testCatalog.value) if (t.department) set.add(t.department)
  return [...set].sort()
})
const headers = [
  { title: 'Patient', key: 'patient_name', width: 200 },
  { title: 'Tests', key: 'test_names', sortable: false, width: 220 },
  { title: 'Priority', key: 'priority', align: 'center', width: 110 },
  { title: 'Status', key: 'status', width: 150 },
  { title: 'Collection', key: 'is_home_collection', align: 'center', width: 120 },
  { title: 'Created', key: 'created_at', width: 130 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 100 },
]
const kanbanCols = [
  { value: 'pending', title: 'Pending', hc: '#F59E0B', icon: 'mdi-clock-outline' },
  { value: 'sample_collected', title: 'Sample Collected', hc: '#3B82F6', icon: 'mdi-test-tube' },
  { value: 'processing', title: 'Processing', hc: '#F97316', icon: 'mdi-progress-clock' },
  { value: 'completed', title: 'Completed', hc: '#10B981', icon: 'mdi-check-circle' },
  { value: 'cancelled', title: 'Cancelled', hc: '#EF4444', icon: 'mdi-cancel' },
]

// ── Test catalog table headers ──
const testHeaders = [
  { title: 'Test', key: 'name', width: 200 },
  { title: 'Department', key: 'department', width: 140 },
  { title: 'Specimen', key: 'specimen_type', width: 160 },
  { title: 'Reference Ranges', key: 'reference_ranges', sortable: false, width: 320 },
  { title: 'TAT', key: 'turnaround_time', width: 120 },
  { title: 'Price', key: 'price', align: 'end', width: 120 },
  { title: 'Status', key: 'is_active', align: 'center', width: 100 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 90 },
]
// ── Panel table headers ──
const panelHeaders = [
  { title: 'Panel', key: 'name', width: 220 },
  { title: 'Department', key: 'department', width: 140 },
  { title: 'Tests', key: 'test_names', sortable: false, width: 280 },
  { title: 'Price', key: 'price', align: 'end', width: 120 },
  { title: 'Status', key: 'is_active', align: 'center', width: 100 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 90 },
]

const filteredTests = computed(() => {
  let list = testCatalog.value
  if (testDeptFilter.value) list = list.filter(t => t.department === testDeptFilter.value)
  if (testActiveFilter.value !== null && testActiveFilter.value !== '') list = list.filter(t => !!t.is_active === !!testActiveFilter.value)
  return list
})
const filteredPanels = computed(() => {
  let list = panels.value
  if (panelSearch.value) { const q = panelSearch.value.toLowerCase(); list = list.filter(p => JSON.stringify(p).toLowerCase().includes(q)) }
  return list
})
function deptColor(d) {
  return { Hematology: 'red', Biochemistry: 'amber', Microbiology: 'green', Serology: 'orange', Endocrinology: 'blue', Urinalysis: 'cyan', Parasitology: 'purple', Oncology: 'pink', Pathology: 'deep-purple' }[d] || 'teal'
}
function formatMoney(v) { return v != null ? `KSh ${Number(v).toLocaleString()}` : '—' }

const specimenOptions = [
  'Blood (EDTA)', 'Blood (Plain)', 'Blood (Citrate)', 'Blood (Fluoride)', 'Blood (Serum)',
  'Blood (Finger prick)', 'Blood (Aerobic/Anaerobic bottles)',
  'Urine (Mid-stream)', 'Urine (24-hour)', 'Urine', 'Stool', 'Sputum',
  'Cerebrospinal Fluid', 'Wound swab', 'Throat swab', 'Vaginal swab',
]
function specimenIcon(s) {
  if (s.toLowerCase().includes('blood')) return 'mdi-droplet'
  if (s.toLowerCase().includes('urine')) return 'mdi-water'
  if (s.toLowerCase().includes('stool')) return 'mdi-emoticon-poop'
  if (s.toLowerCase().includes('spit') || s.toLowerCase().includes('sput')) return 'mdi-lungs'
  if (s.toLowerCase().includes('swab')) return 'mdi-tshirt-crew'
  if (s.toLowerCase().includes('csf') || s.toLowerCase().includes('cerebr')) return 'mdi-brain'
  return 'mdi-test-tube-empty'
}

function openTestDialog(test = null) {
  editingTest.value = test
  if (test) {
    Object.assign(testForm, { name: test.name, code: test.code, department: test.department, specimen_type: test.specimen_type, price: test.price, turnaround_time: test.turnaround_time, instructions: test.instructions, is_active: test.is_active })
    testRanges.value = Object.entries(test.reference_ranges || {}).map(([k, v]) => ({ key: k, value: String(v) }))
  } else {
    Object.assign(testForm, { name: '', code: '', department: '', specimen_type: '', price: 0, turnaround_time: '', instructions: '', is_active: true })
    testRanges.value = []
  }
  testDialog.value = true
}
async function saveTest() {
  const { valid } = await testFormRef.value.validate()
  if (!valid) return
  testSaving.value = true
  const ranges = {}
  for (const r of testRanges.value) if (r.key.trim()) ranges[r.key.trim()] = r.value
  const payload = { ...testForm, reference_ranges: ranges }
  try {
    if (editingTest.value?.id) await $api.patch(`/lab/catalog/${editingTest.value.id}/`, payload)
    else await $api.post('/lab/catalog/', payload)
    testDialog.value = false
    await loadCatalog()
  } catch (e) { console.error(e) }
  testSaving.value = false
}
async function deleteTest(test) {
  if (!confirm(`Delete test "${test.name}"?`)) return
  try { await $api.delete(`/lab/catalog/${test.id}/`); await loadCatalog() }
  catch (e) { console.error(e) }
}

function openPanelDialog(panel = null) {
  editingPanel.value = panel
  if (panel) {
    Object.assign(panelForm, { name: panel.name, code: panel.code, department: panel.department, price: panel.price, is_active: panel.is_active, test_ids: panel.tests || [], description: panel.description || '' })
  } else {
    Object.assign(panelForm, { name: '', code: '', department: '', price: 0, is_active: true, test_ids: [], description: '' })
  }
  panelDialog.value = true
}
async function savePanel() {
  const { valid } = await panelFormRef.value.validate()
  if (!valid) return
  panelSaving.value = true
  try {
    const payload = { ...panelForm }
    if (editingPanel.value?.id) await $api.patch(`/lab/panels/${editingPanel.value.id}/`, payload)
    else await $api.post('/lab/panels/', payload)
    panelDialog.value = false
    await loadPanels()
  } catch (e) { console.error(e) }
  panelSaving.value = false
}
async function deletePanel(panel) {
  if (!confirm(`Delete panel "${panel.name}"?`)) return
  try { await $api.delete(`/lab/panels/${panel.id}/`); await loadPanels() }
  catch (e) { console.error(e) }
}

const hasFilters = computed(() => filterPriority.value != null || filterDepartment.value || filterHome.value != null || search.value)
function clearFilters() { search.value = ''; filterPriority.value = null; filterDepartment.value = null; filterHome.value = null }

const filtered = computed(() => {
  let list = orders.value
  if (tabStatus.value) list = list.filter(o => o.status === tabStatus.value)
  if (filterPriority.value) list = list.filter(o => o.priority === filterPriority.value)
  if (filterDepartment.value) list = list.filter(o => o.test_names?.some(t => t.toLowerCase().includes(filterDepartment.value.toLowerCase())))
  if (filterHome.value !== null && filterHome.value !== '') list = list.filter(o => !!o.is_home_collection === !!filterHome.value)
  return list
})
function kanbanItems(status) { return filtered.value.filter(o => o.status === status) }

const kpis = computed(() => {
  const all = orders.value
  return [
    { label: 'Total', value: all.length, color: 'teal', icon: 'mdi-microscope', filter: '' },
    { label: 'Pending', value: all.filter(o => o.status === 'pending').length, color: 'warning', icon: 'mdi-clock-outline', filter: 'pending' },
    { label: 'Sample Collected', value: all.filter(o => o.status === 'sample_collected').length, color: 'info', icon: 'mdi-test-tube', filter: 'sample_collected' },
    { label: 'Processing', value: all.filter(o => o.status === 'processing').length, color: 'orange', icon: 'mdi-progress-clock', filter: 'processing' },
    { label: 'Completed', value: all.filter(o => o.status === 'completed').length, color: 'success', icon: 'mdi-check-circle', filter: 'completed' },
    { label: 'STAT', value: all.filter(o => o.priority === 'stat').length, color: 'error', icon: 'mdi-alert', filter: '' },
  ]
})

// ── Stats Analysis ──
const statusColors = { pending: 'warning', sample_collected: 'info', processing: 'orange', completed: 'success', cancelled: 'grey' }
const statusLabels = { pending: 'Pending', sample_collected: 'Sample Collected', processing: 'Processing', completed: 'Completed', cancelled: 'Cancelled' }

const statusStats = computed(() => {
  const all = orders.value
  const total = all.length || 1
  return ['pending', 'sample_collected', 'processing', 'completed', 'cancelled'].map(v => {
    const count = all.filter(o => o.status === v).length
    return { value: v, label: statusLabels[v], count, pct: Math.round(count / total * 100), color: statusColors[v] }
  }).filter(s => s.count > 0)
})

const priorityStats = computed(() => {
  const all = orders.value
  const total = all.length || 1
  return [
    { value: 'routine', label: 'Routine', count: all.filter(o => o.priority === 'routine').length, color: 'info' },
    { value: 'urgent', label: 'Urgent', count: all.filter(o => o.priority === 'urgent').length, color: 'warning' },
    { value: 'stat', label: 'STAT', count: all.filter(o => o.priority === 'stat').length, color: 'error' },
  ].map(p => ({ ...p, pct: Math.round(p.count / total * 100) })).filter(p => p.count > 0)
})

const weekdayStats = computed(() => {
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
  const counts = [0, 0, 0, 0, 0, 0, 0]
  orders.value.forEach(o => { if (o.created_at) counts[new Date(o.created_at).getDay()]++ })
  return days.map((label, i) => ({ label, count: counts[i] }))
})
const weekdayMax = computed(() => Math.max(1, ...weekdayStats.value.map(d => d.count)))

// department stats derived from test_names → mapped to department via testCatalog lookup
function testDepartment(testName) {
  if (!testName) return null
  // try exact match by name in testCatalog
  const found = testCatalog.value.find(t => t.name === testName)
  if (found?.department) return found.department
  // Fallback: keyword guess
  const n = testName.toLowerCase()
  if (n.includes('culture') || n.includes('swab') || n.includes('sputum') || n.includes('stool') || n.includes('af ') || n.includes('gene') || n.includes('pylori') || n.includes('smear') || n.includes('widal')) return 'Microbiology'
  if (n.includes('hiv') || n.includes('hbsag') || n.includes('hcv') || n.includes('hepatitis') || n.includes('vdrl') || n.includes('syphilis') || n.includes('tpha') || n.includes('bruc') || n.includes('rheumatoid') || n.includes('aso') || n.includes('ana ') || n.includes('antibod')) return 'Serology'
  if (n.includes('malaria') || n.includes('parasite')) return 'Parasitology'
  if (n.includes('ca-') || n.includes('cea') || n.includes('afp') || n.includes('tumor')) return 'Oncology'
  if (n.includes('tsh') || n.includes('tft') || n.includes('thyroid') || n.includes('psa') || n.includes('hcg') || n.includes('prolactin') || n.includes('cortisol') || n.includes('testosterone')) return 'Endocrinology'
  if (n.includes('urine') || n.includes('urinalys')) return 'Urinalysis'
  if (n.includes('cbc') || n.includes('hemogr') || n.includes('esr') || n.includes('blood') || n.includes('coagulation') || n.includes('d-dimer') || n.includes('retic') || n.includes('sickl') || n.includes('platelet')) return 'Hematology'
  return 'Biochemistry'
}

const departmentStats = computed(() => {
  const counts = {}
  orders.value.forEach(o => {
    const depts = new Set()
    if (o.test_names && o.test_names.length) {
      o.test_names.forEach(tn => { const d = testDepartment(tn); if (d) depts.add(d) })
    }
    depts.forEach(d => { counts[d] = (counts[d] || 0) + 1 })
  })
  const entries = Object.entries(counts).map(([name, count]) => ({ name, count }))
    .sort((a, b) => b.count - a.count).slice(0, 8)
  return entries
})
const departmentMax = computed(() => Math.max(1, ...departmentStats.value.map(d => d.count)))

function canEdit(o) { return o && !['completed', 'cancelled'].includes(o.status) }
function priorityLabel(p) { return { routine: 'Routine', urgent: 'Urgent', stat: 'STAT' }[p] || p }
function priorityColor(p) { return p === 'stat' ? 'error' : p === 'urgent' ? 'warning' : 'info' }
function fmtDate(d) { if (!d) return '—'; return new Date(d).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' }) }
function timeAgo(d) { if (!d) return ''; const m = Math.floor((Date.now() - new Date(d).getTime()) / 60000); if (m < 1) return 'just now'; if (m < 60) return `${m}m ago`; const h = Math.floor(m / 60); if (h < 24) return `${h}h ago`; return `${Math.floor(h / 24)}d ago` }
function patientInitials(o) { const p = (o.patient_name || '').split(/\s+/).filter(Boolean); return ((p[0]?.[0] || '') + (p[1]?.[0] || '')).toUpperCase() || '?' }
function avatarColor(id) { return ['deep-purple','teal','indigo','pink','cyan-darken-2','amber-darken-2','green-darken-1','orange-darken-2'][(id || 0) % 8] }

async function load() {
  loading.value = true
  try {
    let url = '/lab/orders/?page_size=500&ordering=-created_at'
    if (isDoctor) url += `&ordered_by=${auth.user?.id}`
    const { data } = await $api.get(url)
    orders.value = data?.results || data || []
  } catch { orders.value = [] }
  loading.value = false
}
async function loadCatalog() {
  testLoading.value = true
  try {
    const { data } = await $api.get('/lab/catalog/?page_size=1000&ordering=name')
    testCatalog.value = data?.results || data || []
  } catch { testCatalog.value = [] }
  testLoading.value = false
}
async function loadPanels() {
  panelLoading.value = true
  try {
    const { data } = await $api.get('/lab/panels/?page_size=500&ordering=name')
    panels.value = data?.results || data || []
  } catch { panels.value = [] }
  panelLoading.value = false
}

async function seedCatalog() {
  seedingCatalog.value = true
  seedError.value = ''
  try {
    const { data } = await $api.post('/lab/catalog/seed_demo/')
    seedResult.value = data
    seedDialog.value = false
    seedSnackbar.value = true
    await Promise.all([loadCatalog(), loadPanels()])
  } catch (e) {
    seedError.value = e?.response?.data?.detail || 'Failed to seed catalog.'
    seedSnackbar.value = true
  }
  seedingCatalog.value = false
}
watch(mainTab, (val) => {
  if (val === 'catalog' && !testCatalog.value.length) loadCatalog()
  if (val === 'panels' && !panels.value.length) loadPanels()
})
onMounted(() => {
  load()
  if (!testCatalog.value.length) loadCatalog()
})
</script>

<style scoped>
.kpi-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); transition: all 0.2s ease; }
.kpi-card:hover { transform: translateY(-2px); box-shadow: 0 4px 16px rgba(0,0,0,0.06); }
.kpi-card--active { border-color: rgb(var(--v-theme-primary)); background: rgba(var(--v-theme-primary), 0.04); }
.stat-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); transition: all 0.2s ease; }
.stat-card:hover { box-shadow: 0 4px 16px rgba(0,0,0,0.06); }
.filter-bar { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.orders-table :deep(tbody tr) { cursor: pointer; }
.kanban-container { display: flex; gap: 12px; overflow-x: auto; padding-bottom: 8px; }
.kanban-col { flex: 0 0 270px; min-width: 270px; }
.kanban-col-header { background: rgba(var(--v-theme-on-surface), 0.03); border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.kanban-cards { max-height: calc(100vh - 420px); overflow-y: auto; }
.kanban-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.08); transition: all 0.15s ease; }
.kanban-card:hover { box-shadow: 0 4px 12px rgba(0,0,0,0.08); transform: translateY(-1px); }
@keyframes blink { 0%,100% { opacity: 1 } 50% { opacity: 0.3 } }
.blink { animation: blink 1.2s infinite; }
.cursor-pointer { cursor: pointer; }
.catalog-table :deep(tbody tr:hover) { background: rgba(var(--v-theme-primary), 0.02); }
.filter-bar { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
</style>
