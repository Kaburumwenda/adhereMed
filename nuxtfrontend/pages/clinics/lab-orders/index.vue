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
      <v-tooltip
        v-if="mainTab === 'orders'"
        location="bottom"
        text="Orders reload by themselves so the bench always sees live updates"
      >
        <template #activator="{ props: liveTip }">
          <div v-bind="liveTip" class="lab-live" :class="{ 'is-syncing': autoRefreshing }">
            <v-progress-circular
              :model-value="autoRefreshProgress"
              :size="17"
              :width="2"
              :color="autoRefreshing ? 'success' : 'primary'"
              rotate="-90"
              class="lab-live-ring"
            />
            <span class="lab-live-label">
              <span class="lab-live-dot" />
              {{ autoRefreshing ? 'Syncing…' : `Live · ${fmtCountdown(autoSecondsLeft)}` }}
            </span>
          </div>
        </template>
      </v-tooltip>
      <v-btn v-if="mainTab === 'orders'" variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
             :loading="loading" @click="load()">Refresh</v-btn>
      <v-btn v-if="mainTab === 'orders'" color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus"
             to="/clinics/lab-orders/new">New Order</v-btn>
      <v-btn v-if="mainTab === 'catalog'" color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus"
             @click="openTestDialog()">Add Test</v-btn>
      <v-btn v-if="mainTab === 'catalog'" variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-database-seed"
             to="/clinics/lab-orders/seed">Seed Demo</v-btn>
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
    <!-- KPI strip — compact cards, scrolls horizontally when space is tight -->
    <div class="kpi-strip-wrap mb-4">
      <div ref="kpiStripRef" class="kpi-strip" @scroll.passive="updateKpiScroll">
        <button
          v-for="k in kpis"
          :key="k.label"
          type="button"
          class="kpi-mini"
          :class="{ 'is-active': isKpiActive(k) }"
          @click="applyKpi(k)"
        >
          <v-avatar :color="k.color" size="26" variant="tonal" class="kpi-mini-ico">
            <v-icon size="14">{{ k.icon }}</v-icon>
          </v-avatar>
          <span class="kpi-mini-body">
            <b>{{ k.value }}</b>
            <span>{{ k.label }}</span>
          </span>
        </button>
      </div>

      <button
        v-if="kpiScroll.left"
        type="button"
        class="kpi-nav is-prev"
        aria-label="Scroll statistics left"
        @click="scrollKpis(-1)"
      >
        <v-icon size="16">mdi-chevron-left</v-icon>
      </button>
      <button
        v-if="kpiScroll.right"
        type="button"
        class="kpi-nav is-next"
        aria-label="Scroll statistics right"
        @click="scrollKpis(1)"
      >
        <v-icon size="16">mdi-chevron-right</v-icon>
      </button>
    </div>

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
      <v-tab value="authorization" prepend-icon="mdi-shield-check-outline">
        Authorisation
        <v-chip size="x-small" variant="flat" color="warning" class="ml-2" v-if="unverifiedCount">
          {{ unverifiedCount }}
        </v-chip>
      </v-tab>
    </v-tabs>

    <!-- Authorisation sub-filter -->
    <div v-if="tabStatus === 'authorization'" class="auth-scope mb-3">
      <div class="auth-scope-lead">
        <span class="auth-scope-ico"><v-icon size="15">mdi-shield-check-outline</v-icon></span>
        <div>
          <b>Bench authorisation</b>
          <span>Reports stay as drafts until a verifier signs them.</span>
        </div>
      </div>
      <v-btn-toggle v-model="authFilter" mandatory density="compact" rounded="lg" color="primary" class="auth-scope-toggle">
        <v-btn value="" size="small" class="text-none">All ({{ authScopeTotals.all }})</v-btn>
        <v-btn value="unverified" size="small" class="text-none">
          Unverified ({{ authScopeTotals.unverified }})
        </v-btn>
        <v-btn value="verified" size="small" class="text-none">
          Verified ({{ authScopeTotals.verified }})
        </v-btn>
      </v-btn-toggle>
      <v-spacer />
      <div class="auth-scope-meter">
        <span>{{ authScopeTotals.verified }}/{{ authScopeTotals.all }} verified</span>
        <v-progress-linear :model-value="authScopeTotals.pct" color="success" height="6" rounded rounded-bar />
      </div>
    </div>

    <!-- TABLE VIEW -->
    <v-card v-if="viewMode === 'table'" flat rounded="xl" class="overflow-hidden">
      <v-data-table :headers="headers" :items="filtered" :search="search" :loading="loading"
        density="comfortable" hover v-model:page="ordersPage" v-model:items-per-page="ordersPerPage"
        class="orders-table"
        @click:row="(_, { item }) => $router.push(`/clinics/lab-orders/${item.id}`)">
        <template #loading><v-skeleton-loader type="table-row@6" /></template>
        <template #item.row_number="{ index }">
          <span class="row-num">{{ rowNumber(index, ordersPage, ordersPerPage) }}</span>
        </template>
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
        <template #item.authorisation="{ item }">
          <div class="auth-cell" @click.stop>
            <template v-if="item.is_verified">
              <span class="auth-pill is-good" :title="`Verified ${fmtDateTime(item.verified_at)}`">
                <v-icon size="11">mdi-check-decagram</v-icon>
                Verified
              </span>
            </template>
            <template v-else>
              <span class="auth-pill is-warn">
                <v-icon size="11">mdi-shield-alert-outline</v-icon>
                Unverified
              </span>
              <v-btn
                icon="mdi-shield-check-outline"
                size="x-small"
                variant="text"
                color="primary"
                class="auth-verify-btn"
                :loading="verifyLoadingId === item.id"
                :title="item.status === 'completed'
                  ? 'Authorise & sign this report'
                  : 'Complete the order before verification'"
                @click="openVerify(item)"
              />
            </template>
          </div>
        </template>
        <template #item.turnaround="{ item }">
          <div v-if="turnaroundOf(item)" class="tna-cell" :class="`is-${turnaroundOf(item).state}`">
            <div class="tna-head">
              <span class="tna-value">{{ fmtDuration(turnaroundOf(item).seconds) }}</span>
              <span class="tna-state">
                <v-icon size="10">{{ turnaroundOf(item).is_verified ? 'mdi-check' : 'mdi-timer-sand' }}</v-icon>
                {{ turnaroundLabel(turnaroundOf(item)) }}
              </span>
            </div>
            <v-progress-linear
              :model-value="Math.min(100, turnaroundOf(item).pct)"
              :color="turnaroundColor(turnaroundOf(item))"
              height="5"
              rounded
              rounded-bar
            />
            <span class="tna-target">Target {{ fmtDuration(turnaroundOf(item).target_seconds) }}</span>
          </div>
          <span v-else class="text-medium-emphasis">—</span>
        </template>
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
            <v-btn icon="mdi-file-pdf-box" size="x-small" variant="text"
                   :color="item.is_verified ? 'error' : 'grey'"
                   :title="item.is_verified ? 'Download laboratory report (PDF)' : 'Report not verified — download blocked'"
                   :loading="printingIds.has(item.id)"
                   @click="downloadReportPdf(item)" />
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
          density="comfortable" hover v-model:page="testsPage" v-model:items-per-page="testsPerPage"
          class="catalog-table">
          <template #loading><v-skeleton-loader type="table-row@6" /></template>
          <template #item.row_number="{ index }">
            <span class="row-num">{{ rowNumber(index, testsPage, testsPerPage) }}</span>
          </template>
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
          density="comfortable" hover v-model:page="panelsPage" v-model:items-per-page="panelsPerPage">
          <template #loading><v-skeleton-loader type="table-row@6" /></template>
          <template #item.row_number="{ index }">
            <span class="row-num">{{ rowNumber(index, panelsPage, panelsPerPage) }}</span>
          </template>
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
        <BrandDialogHeader icon="mdi-test-tube" :title="editingTest?.id ? 'Edit Test' : 'Add Lab Test'" />
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
        <BrandDialogHeader icon="mdi-test-tube-empty" :title="editingPanel?.id ? 'Edit Panel' : 'Add Lab Panel'" />
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

    <!-- Seed Result Snackbar -->
    <v-snackbar v-model="seedSnackbar" :color="seedError ? 'error' : 'success'" :timeout="6000" location="top">
      <span v-if="seedError">{{ seedError }}</span>
      <span v-else>Report exported.</span>
      <template #actions>
        <v-btn variant="text" @click="seedSnackbar = false">Close</v-btn>
      </template>
    </v-snackbar>

    <!-- Bench authorisation from the list (verify icon on unverified rows) -->
    <AuthorizationDialog
      v-model="authDialogOpen"
      :order-id="authTarget?.id || 0"
      :role="authRole"
      :order="authTarget"
      :existing="authRole === 'verified' ? authTarget?.authorization?.verified : authTarget?.authorization?.performed"
      @signed="onSigned"
    />

    <!-- Blocked-action explainer (unverified report / no results) -->
    <InfoDialog
      v-model="infoDialog.open"
      :tone="infoDialog.tone"
      :title="infoDialog.title"
      :subtitle="infoDialog.subtitle"
      :message="infoDialog.message"
      :points="infoDialog.points"
      :hint="infoDialog.hint"
      :confirm-label="infoDialog.confirm"
      :secondary-label="infoDialog.secondary ? 'Open order' : ''"
      @secondary="openOrderFromInfo"
    />
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
import { useAuthStore } from '~/stores/auth'
const auth = useAuthStore()
const router = useRouter()

// Doctors / clinical officers / dentists only see their own lab orders
const isDoctor = ['doctor', 'clinical_officer', 'dentist'].includes(auth.role)
const loading = ref(false)
const orders = ref([])
// Lab order ids whose premium PDF report is currently being generated.
const printingIds = reactive(new Set())
const search = ref('')
const filterPriority = ref(null)
const filterDepartment = ref(null)
const filterHome = ref(null)
const tabStatus = ref('')
/** Authorisation tab scope: '' (all) | 'unverified' | 'verified' */
const authFilter = ref('unverified')
const viewMode = ref('table')
const mainTab = ref('orders')

/* ── Live auto-refresh ────────────────────────────────────────────────────
   The bench staff should never have to hit Refresh to see a new order, a
   sample collection or a verification. A 60s clock reloads the list on its
   own and restarts as soon as the load completes.
   The deadline/clock pair (instead of a decrementing counter) stays correct
   even when the browser throttles timers in a background tab. */
const AUTO_REFRESH_SECONDS = 60
const AUTO_REFRESH_MS = AUTO_REFRESH_SECONDS * 1000
/** Epoch ms when the next automatic reload is due (0 until mounted). */
const autoRefreshDeadline = ref(0)
/** Ticking clock that drives the visible countdown. */
const autoClock = ref(0)
const autoRefreshing = ref(false)
let autoRefreshTimer = null

/** Seconds left before the next reload — 60 until the timer starts on mount. */
const autoSecondsLeft = computed(() => {
  if (!autoRefreshDeadline.value) return AUTO_REFRESH_SECONDS
  return Math.max(0, Math.ceil((autoRefreshDeadline.value - autoClock.value) / 1000))
})
/** 0 → 100 as the 60s window elapses, used by the ring. */
const autoRefreshProgress = computed(() => {
  if (!autoRefreshDeadline.value) return 0
  const remaining = Math.max(0, autoRefreshDeadline.value - autoClock.value)
  return Math.min(100, Math.max(0, Math.round((AUTO_REFRESH_MS - remaining) / AUTO_REFRESH_MS * 100)))
})

/** mm:ss label for the countdown. */
function fmtCountdown(seconds) {
  const total = Math.max(0, Math.round(Number(seconds) || 0))
  const mins = Math.floor(total / 60)
  return `${mins}:${String(total % 60).padStart(2, '0')}`
}

function resetAutoRefreshClock() {
  if (!import.meta.client) return
  autoClock.value = Date.now()
  autoRefreshDeadline.value = autoClock.value + AUTO_REFRESH_MS
}

function stopAutoRefresh() {
  if (autoRefreshTimer) clearInterval(autoRefreshTimer)
  autoRefreshTimer = null
}

function startAutoRefresh() {
  if (!import.meta.client) return
  stopAutoRefresh()
  resetAutoRefreshClock()
  autoRefreshTimer = setInterval(() => {
    autoClock.value = Date.now()
    if (mainTab.value !== 'orders') return
    if (autoSecondsLeft.value > 0) return
    if (loading.value || autoRefreshing.value) return
    load({ silent: true })
  }, 500)
}

/** Coming back to a background tab: reload at once if the window already lapsed. */
function onVisibilityChange() {
  if (!import.meta.client || document.visibilityState !== 'visible') return
  autoClock.value = Date.now()
  if (mainTab.value !== 'orders') return
  if (autoSecondsLeft.value > 0) return
  if (loading.value || autoRefreshing.value) return
  load({ silent: true })
}

/* ── Table pagination (kept in state so row numbering runs across pages) ── */
const ordersPage = ref(1)
const ordersPerPage = ref(25)
const testsPage = ref(1)
const testsPerPage = ref(25)
const panelsPage = ref(1)
const panelsPerPage = ref(25)

/** Continuous row number across pages: page 2 starts at perPage + 1. */
function rowNumber(index, page, perPage) {
  return (page - 1) * perPage + index + 1
}

/* ── Bench authorisation from the list ─────────────────────────────────── */
const authDialogOpen = ref(false)
const authRole = ref('verified')
const authTarget = ref(null)
const verifyLoadingId = ref(null)

/* ── Blocking-action explainer ─────────────────────────────────────────── */
const infoDialog = reactive({
  open: false,
  tone: 'info',
  title: '',
  subtitle: '',
  message: '',
  points: [],
  hint: '',
  confirm: 'Got it',
  secondary: '',
})
/** Order id the info dialog refers to (for the "Open order" shortcut). */
const infoOrderId = ref(null)

function showInfo(options = {}) {
  Object.assign(infoDialog, {
    open: true,
    tone: 'info',
    subtitle: '',
    message: '',
    points: [],
    hint: '',
    confirm: 'Got it',
    secondary: '',
  }, options)
}

function openOrderFromInfo() {
  if (infoOrderId.value) router.push(`/clinics/lab-orders/${infoOrderId.value}`)
}

// ── Lab Test Catalog state ──
const testCatalog = ref([])
const testLoading = ref(false)
const testSearch = ref('')
const testDeptFilter = ref(null)
const testActiveFilter = ref(null)
const testDialog = ref(false)
const testSaving = ref(false)

// ── Seed demo state ──
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
  { title: '#', key: 'row_number', sortable: false, align: 'center', width: 48 },
  { title: 'Patient', key: 'patient_name', width: 200 },
  { title: 'Tests', key: 'test_names', sortable: false, width: 200 },
  { title: 'Priority', key: 'priority', align: 'center', width: 105 },
  { title: 'Status', key: 'status', width: 140 },
  { title: 'Authorise', key: 'authorisation', sortable: false, align: 'center', width: 155 },
  { title: 'Turnaround', key: 'turnaround', sortable: false, width: 185 },
  { title: 'Collection', key: 'is_home_collection', align: 'center', width: 115 },
  { title: 'Created', key: 'created_at', width: 125 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 105 },
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
  { title: '#', key: 'row_number', sortable: false, align: 'center', width: 48 },
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
  { title: '#', key: 'row_number', sortable: false, align: 'center', width: 48 },
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
  if (tabStatus.value === 'authorization') {
    // Authorisation tab spans every live order; the scope toggle splits it.
    list = list.filter(o => o.status !== 'cancelled')
    if (authFilter.value === 'verified') list = list.filter(o => o.is_verified)
    else if (authFilter.value === 'unverified') list = list.filter(o => !o.is_verified)
  } else if (tabStatus.value) {
    list = list.filter(o => o.status === tabStatus.value)
  }
  if (filterPriority.value) list = list.filter(o => o.priority === filterPriority.value)
  if (filterDepartment.value) list = list.filter(o => o.test_names?.some(t => t.toLowerCase().includes(filterDepartment.value.toLowerCase())))
  if (filterHome.value !== null && filterHome.value !== '') list = list.filter(o => !!o.is_home_collection === !!filterHome.value)
  return list
})
function kanbanItems(status) { return filtered.value.filter(o => o.status === status) }

/** Orders that feed the Authorisation tab (cancelled ones are excluded). */
const authScope = computed(() => orders.value.filter(o => o.status !== 'cancelled'))
const unverifiedCount = computed(() => authScope.value.filter(o => !o.is_verified).length)
const authScopeTotals = computed(() => {
  const all = authScope.value.length
  const verified = authScope.value.filter(o => o.is_verified).length
  return { all, verified, unverified: all - verified, pct: all ? Math.round(verified / all * 100) : 0 }
})

/** KPI card click — switches the status tab (and the auth scope when given). */
function applyKpi(kpi) {
  if (kpi.priority) {
    if (tabStatus.value === 'authorization') authFilter.value = 'unverified'
    filterPriority.value = filterPriority.value === kpi.priority ? null : kpi.priority
    return
  }
  if (kpi.auth !== undefined) {
    if (tabStatus.value === 'authorization' && authFilter.value === kpi.auth) tabStatus.value = ''
    else {
      tabStatus.value = 'authorization'
      authFilter.value = kpi.auth
    }
    return
  }
  // Leaving the authorisation scope when a plain status is picked.
  if (tabStatus.value === 'authorization') authFilter.value = 'unverified'
  tabStatus.value = tabStatus.value === kpi.filter ? '' : kpi.filter
}

/** Whether a KPI card reflects the currently applied filter. */
function isKpiActive(kpi) {
  if (kpi.priority) return filterPriority.value === kpi.priority
  if (kpi.auth !== undefined) {
    return tabStatus.value === 'authorization' && authFilter.value === kpi.auth
  }
  if (tabStatus.value === 'authorization') return false
  return tabStatus.value === kpi.filter
}

/* ── KPI strip scrolling ──────────────────────────────────────────────── */
const kpiStripRef = ref(null)
const kpiScroll = reactive({ left: false, right: false, overflow: false })

function updateKpiScroll() {
  const el = kpiStripRef.value
  if (!el) return
  const max = el.scrollWidth - el.clientWidth
  kpiScroll.overflow = max > 4
  kpiScroll.left = el.scrollLeft > 4
  kpiScroll.right = max > 4 && el.scrollLeft < max - 4
}

function scrollKpis(direction) {
  const el = kpiStripRef.value
  if (!el) return
  const step = Math.max(200, Math.round(el.clientWidth * 0.6))
  el.scrollBy({ left: direction * step, behavior: 'smooth' })
}

let kpiObserver = null

const kpis = computed(() => {
  const all = orders.value
  return [
    { label: 'Total', value: all.length, color: 'teal', icon: 'mdi-microscope', filter: '' },
    { label: 'Pending', value: all.filter(o => o.status === 'pending').length, color: 'warning', icon: 'mdi-clock-outline', filter: 'pending' },
    { label: 'Sample Collected', value: all.filter(o => o.status === 'sample_collected').length, color: 'info', icon: 'mdi-test-tube', filter: 'sample_collected' },
    { label: 'Processing', value: all.filter(o => o.status === 'processing').length, color: 'orange', icon: 'mdi-progress-clock', filter: 'processing' },
    { label: 'Completed', value: all.filter(o => o.status === 'completed').length, color: 'success', icon: 'mdi-check-circle', filter: 'completed' },
    { label: 'Awaiting auth', value: unverifiedCount.value, color: 'deep-orange', icon: 'mdi-shield-alert-outline', filter: 'authorization', auth: 'unverified' },
    { label: 'Authorised', value: all.filter(o => o.is_verified).length, color: 'green-darken-2', icon: 'mdi-shield-check', filter: 'authorization', auth: 'verified' },
    { label: 'STAT', value: all.filter(o => o.priority === 'stat').length, color: 'error', icon: 'mdi-alert', priority: 'stat' },
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

/* ── Turnaround (pending → verified) ──────────────────────────────────── */
/** Re-renders the live timers for orders still awaiting verification. */
const nowTick = ref(Date.now())
let tickTimer = null

onMounted(() => {
  tickTimer = setInterval(() => { nowTick.value = Date.now() }, 30000)

  // Live records for the bench: reload the list every 60 seconds.
  startAutoRefresh()
  document.addEventListener('visibilitychange', onVisibilityChange)

  // Keep the KPI scroll affordances in sync with the available width.
  nextTick(updateKpiScroll)
  if (typeof ResizeObserver !== 'undefined') {
    kpiObserver = new ResizeObserver(updateKpiScroll)
    if (kpiStripRef.value) kpiObserver.observe(kpiStripRef.value)
  }
  window.addEventListener('resize', updateKpiScroll)
})
onBeforeUnmount(() => {
  if (tickTimer) clearInterval(tickTimer)
  stopAutoRefresh()
  document.removeEventListener('visibilitychange', onVisibilityChange)
  kpiObserver?.disconnect()
  kpiObserver = null
  window.removeEventListener('resize', updateKpiScroll)
})

/**
 * Turnaround block for one order.
 *
 * Verified orders use the value saved at sign-off; unverified ones are counted
 * live from the moment they entered the queue so the bar keeps moving.
 */
function turnaroundOf(order) {
  const base = order?.turnaround
  if (!base) return null
  if (base.is_verified || !base.started_at) return base
  const started = new Date(base.started_at).getTime()
  const seconds = Math.max(0, Math.round((nowTick.value - started) / 1000))
  const target = base.target_seconds || 1
  return {
    ...base,
    seconds,
    pct: Math.min(999, Math.round(seconds / target * 100)),
    state: seconds > target ? 'overdue' : 'running',
  }
}

function turnaroundColor(t) {
  if (!t) return 'grey'
  if (t.state === 'overdue') return 'error'
  if (t.pct >= 75) return 'warning'
  return t.is_verified ? 'success' : 'info'
}

function turnaroundLabel(t) {
  if (!t) return ''
  if (t.state === 'overdue') return t.is_verified ? 'late' : 'overdue'
  return t.is_verified ? 'on time' : 'in progress'
}

/** Human duration: 45s · 12m · 3h 20m · 1d 4h */
function fmtDuration(seconds) {
  if (seconds == null) return '—'
  const s = Math.max(0, Math.round(Number(seconds)))
  if (s < 60) return `${s}s`
  const m = Math.floor(s / 60)
  if (m < 60) return `${m}m`
  const h = Math.floor(m / 60)
  const rm = m % 60
  if (h < 24) return rm ? `${h}h ${rm}m` : `${h}h`
  const d = Math.floor(h / 24)
  const rh = h % 24
  return rh ? `${d}d ${rh}h` : `${d}d`
}

function fmtDateTime(value) {
  if (!value) return '—'
  return new Date(value).toLocaleString(undefined, {
    day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit',
  })
}

/* ── Verify straight from the list ────────────────────────────────────── */
const STATUS_LABELS = {
  pending: 'Pending',
  sample_collected: 'Sample collected',
  processing: 'Processing',
  completed: 'Completed',
  cancelled: 'Cancelled',
}

async function openVerify(item) {
  // Only a completed order can be verified — the report must be final first.
  if (item.status !== 'completed') {
    infoOrderId.value = item.id
    showInfo({
      tone: 'warning',
      title: 'Complete the order before verification',
      subtitle: `Order #${String(item.id).padStart(5, '0')} · ${item.patient_name || 'Patient'}`,
      message: `This order is still “${STATUS_LABELS[item.status] || item.status}”, so its report is not final and cannot be authorised yet.`,
      points: [
        'Enter every result, then mark the order completed.',
        'A performer signs the results on the bench.',
        'Verification and report release come after completion.',
      ],
      hint: 'Open the order and use “Complete order” once every result is in.',
      confirm: 'Understood',
      secondary: 'open',
    })
    return
  }
  if (!(item.results && item.results.length)) {
    infoOrderId.value = item.id
    showInfo({
      tone: 'info',
      title: 'No results to authorise yet',
      subtitle: `Order #${String(item.id).padStart(5, '0')}`,
      message: 'A report can only be authorised once at least one result has been entered for it.',
      points: [
        'Enter the results on the order first.',
        'The performer then signs, and a verifier authorises the report.',
      ],
      hint: 'Open the order to enter results.',
      confirm: 'OK',
      secondary: 'open',
    })
    return
  }
  verifyLoadingId.value = item.id
  try {
    // The dialog needs the full order (patient, tests, results) so pull it.
    const { data } = await $api.get(`/lab/orders/${item.id}/`)
    authTarget.value = data
    authRole.value = 'verified'
    authDialogOpen.value = true
  } catch {
    seedError.value = 'Could not open the authorisation dialog.'
    seedSnackbar.value = true
  } finally {
    verifyLoadingId.value = null
  }
}

async function onSigned(payload) {
  authDialogOpen.value = false
  const updated = payload?.order
  if (updated) {
    const index = orders.value.findIndex(o => o.id === updated.id)
    if (index !== -1) orders.value[index] = { ...orders.value[index], ...updated }
  } else {
    await load()
  }
}

/**
 * Download the premium laboratory report PDF for one order.
 * Unverified reports are drafts, so the download is refused with an explanation.
 */
async function downloadReportPdf(o) {
  if (!import.meta.client || printingIds.has(o.id)) return
  if (!o.is_verified) {
    infoOrderId.value = o.id
    showInfo({
      tone: 'danger',
      title: 'Report not yet verified',
      subtitle: `Order #${String(o.id).padStart(5, '0')} · ${o.patient_name || 'Patient'}`,
      message: 'This report is still a working draft — it has not been authorised by a verifier, so it cannot be downloaded or printed.',
      points: [
        'A verifier must review the results and sign the report.',
        'Their name and signature are added to the report automatically.',
        'Downloading and printing are enabled immediately after verification.',
      ],
      hint: 'Use the verify icon in the Authorise column to sign this report.',
      confirm: 'OK',
      secondary: '',
    })
    return
  }
  printingIds.add(o.id)
  try {
    const { data } = await $api.get(`/lab/orders/${o.id}/report-pdf/`, {
      responseType: 'blob',
    })
    const url = URL.createObjectURL(data)
    const anchor = document.createElement('a')
    anchor.href = url
    anchor.download = `lab_report_${String(o.id).padStart(5, '0')}.pdf`
    document.body.appendChild(anchor)
    anchor.click()
    document.body.removeChild(anchor)
    setTimeout(() => URL.revokeObjectURL(url), 4000)
  } catch {
    seedError.value = 'Could not generate the report PDF.'
    seedSnackbar.value = true
  } finally {
    printingIds.delete(o.id)
  }
}
function priorityLabel(p) { return { routine: 'Routine', urgent: 'Urgent', stat: 'STAT' }[p] || p }
function priorityColor(p) { return p === 'stat' ? 'error' : p === 'urgent' ? 'warning' : 'info' }
function fmtDate(d) { if (!d) return '—'; return new Date(d).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' }) }
function timeAgo(d) { if (!d) return ''; const m = Math.floor((Date.now() - new Date(d).getTime()) / 60000); if (m < 1) return 'just now'; if (m < 60) return `${m}m ago`; const h = Math.floor(m / 60); if (h < 24) return `${h}h ago`; return `${Math.floor(h / 24)}d ago` }
function patientInitials(o) { const p = (o.patient_name || '').split(/\s+/).filter(Boolean); return ((p[0]?.[0] || '') + (p[1]?.[0] || '')).toUpperCase() || '?' }
function avatarColor(id) { return ['deep-purple','teal','indigo','pink','cyan-darken-2','amber-darken-2','green-darken-1','orange-darken-2'][(id || 0) % 8] }

async function load(options = {}) {
  const silent = options?.silent === true
  if (silent) autoRefreshing.value = true
  else loading.value = true
  // Every refresh — manual or automatic — restarts the 60s window.
  resetAutoRefreshClock()
  try {
    let url = '/lab/orders/?page_size=500&ordering=-created_at'
    if (isDoctor) url += `&ordered_by=${auth.user?.id}`
    const { data } = await $api.get(url)
    orders.value = data?.results || data || []
  } catch {
    // A failed background poll must not wipe the board the staff are reading.
    if (!silent) orders.value = []
  }
  loading.value = false
  autoRefreshing.value = false
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
  // Coming back to Orders: give the staff a full window and fresh numbers.
  if (val === 'orders') {
    resetAutoRefreshClock()
    load({ silent: true })
  }
})
onMounted(() => {
  load()
  if (!testCatalog.value.length) loadCatalog()
})
</script>

<style scoped>
/* ══ Live auto-refresh countdown ══ */
.lab-live {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  height: 36px;
  padding: 0 11px 0 9px;
  border-radius: 12px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.12);
  cursor: default;
  user-select: none;
  /* Only the background animates. Transitioning `border-color` while it is
     derived from a CSS variable makes Chrome keep the pre-theme-change value
     (an opaque white hairline in dark mode), so the border snaps instead. */
  transition: background-color 0.2s ease;
}
.lab-live:hover { border-color: rgba(var(--v-theme-primary), 0.35); }
.lab-live.is-syncing {
  border-color: rgba(var(--v-theme-success), 0.5);
  background: rgba(var(--v-theme-success), 0.07);
}
.lab-live-ring { flex: 0 0 auto; }
.lab-live-label {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 11.5px;
  font-weight: 700;
  letter-spacing: 0.2px;
  white-space: nowrap;
  font-variant-numeric: tabular-nums;
  color: rgba(var(--v-theme-on-surface), 0.7);
}
.lab-live-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  flex: 0 0 auto;
  background: rgb(var(--v-theme-success));
  animation: lab-live-pulse 2s ease-out infinite;
}
.lab-live.is-syncing .lab-live-dot { animation-duration: 0.8s; }
@keyframes lab-live-pulse {
  0%   { box-shadow: 0 0 0 0 rgba(var(--v-theme-success), 0.45); }
  70%  { box-shadow: 0 0 0 6px rgba(var(--v-theme-success), 0); }
  100% { box-shadow: 0 0 0 0 rgba(var(--v-theme-success), 0); }
}

/* ══ Row numbering ══ */
.row-num {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 22px;
  height: 20px;
  padding: 0 5px;
  border-radius: 6px;
  font-size: 10.5px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  letter-spacing: 0.2px;
  color: rgba(var(--v-theme-on-surface), 0.45);
  background: rgba(var(--v-theme-on-surface), 0.045);
}
.orders-table :deep(tbody tr:hover) .row-num,
.catalog-table :deep(tbody tr:hover) .row-num {
  color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.1);
}

/* ══ KPI strip (compact, horizontally scrollable) ══ */
.kpi-strip-wrap { position: relative; }

.kpi-strip {
  display: flex;
  align-items: stretch;
  gap: 8px;
  overflow-x: auto;
  overflow-y: hidden;
  scroll-snap-type: x proximity;
  scroll-behavior: smooth;
  padding-bottom: 5px;
  scrollbar-width: thin;
  scrollbar-color: rgba(var(--v-theme-on-surface), 0.18) transparent;
}
.kpi-strip::-webkit-scrollbar { height: 5px; }
.kpi-strip::-webkit-scrollbar-track { background: transparent; }
.kpi-strip::-webkit-scrollbar-thumb {
  background: rgba(var(--v-theme-on-surface), 0.16);
  border-radius: 999px;
}
.kpi-strip::-webkit-scrollbar-thumb:hover { background: rgba(var(--v-theme-on-surface), 0.28); }

.kpi-mini {
  flex: 0 0 auto;
  min-width: 142px;
  scroll-snap-align: start;
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 7px 12px 7px 7px;
  border-radius: 12px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.07);
  background: rgb(var(--v-theme-surface));
  cursor: pointer;
  text-align: left;
  font-family: inherit;
  transition: border-color 0.16s ease, transform 0.16s ease,
              box-shadow 0.16s ease, background 0.16s ease;
}
.kpi-mini:hover { transform: translateY(-1px); box-shadow: 0 4px 14px rgba(0, 0, 0, 0.07); }
.kpi-mini.is-active {
  border-color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.05);
  box-shadow: inset 0 0 0 1px rgba(var(--v-theme-primary), 0.2);
}
.kpi-mini-ico { flex-shrink: 0; }
.kpi-mini-body {
  display: flex;
  flex-direction: column;
  line-height: 1.15;
  min-width: 0;
}
.kpi-mini-body b {
  font-size: 16px;
  font-weight: 800;
  letter-spacing: -0.4px;
  font-variant-numeric: tabular-nums;
}
.kpi-mini-body span {
  font-size: 9.5px;
  font-weight: 700;
  letter-spacing: 0.2px;
  color: rgba(var(--v-theme-on-surface), 0.5);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

/* Edge scroll affordances */
.kpi-nav {
  position: absolute;
  top: 50%;
  transform: translateY(-50%);
  width: 22px;
  height: 22px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  cursor: pointer;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.12);
  background: rgb(var(--v-theme-surface));
  color: rgb(var(--v-theme-on-surface));
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.12);
  transition: background 0.15s ease, opacity 0.15s ease;
  opacity: 0.92;
  z-index: 2;
}
.kpi-nav:hover { opacity: 1; background: rgba(var(--v-theme-primary), 0.1); }
.kpi-nav.is-prev { left: -6px; }
.kpi-nav.is-next { right: -6px; }

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

/* ══ Authorisation sub-filter bar ══ */
.auth-scope {
  display: flex;
  align-items: center;
  gap: 14px;
  flex-wrap: wrap;
  padding: 10px 14px;
  border-radius: 14px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.07);
  background: rgba(var(--v-theme-on-surface), 0.022);
}
.auth-scope-lead { display: flex; align-items: center; gap: 9px; }
.auth-scope-ico {
  width: 30px; height: 30px; border-radius: 9px;
  display: grid; place-items: center;
  color: rgb(var(--v-theme-primary));
  background: rgba(var(--v-theme-primary), 0.1);
  border: 1px solid rgba(var(--v-theme-primary), 0.2);
}
.auth-scope-lead > div { display: flex; flex-direction: column; line-height: 1.3; }
.auth-scope-lead b { font-size: 12px; font-weight: 800; }
.auth-scope-lead span { font-size: 10px; font-weight: 600; color: rgba(var(--v-theme-on-surface), 0.5); }
.auth-scope-toggle :deep(.v-btn) { text-transform: none; font-size: 11.5px; font-weight: 700; }
.auth-scope-meter { min-width: 168px; display: flex; flex-direction: column; gap: 4px; }
.auth-scope-meter span {
  font-size: 10px;
  font-weight: 700;
  color: rgba(var(--v-theme-on-surface), 0.55);
  text-align: right;
}

/* ══ Authorise column ══ */
.auth-cell { display: inline-flex; align-items: center; gap: 2px; justify-content: center; }
.auth-pill {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  height: 21px;
  padding: 0 8px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.2px;
  white-space: nowrap;
}
.auth-pill.is-good {
  color: #047857;
  background: rgba(16, 185, 129, 0.11);
  border: 1px solid rgba(16, 185, 129, 0.28);
}
.auth-pill.is-warn {
  color: #b45309;
  background: rgba(245, 158, 11, 0.11);
  border: 1px solid rgba(245, 158, 11, 0.3);
}
.auth-verify-btn { opacity: 0.9; }
.auth-verify-btn:hover { opacity: 1; }

/* ══ Turnaround column ══ */
.tna-cell { display: flex; flex-direction: column; gap: 4px; min-width: 0; }
.tna-head { display: flex; align-items: baseline; gap: 6px; }
.tna-value {
  font-size: 12.5px;
  font-weight: 800;
  letter-spacing: -0.2px;
  font-variant-numeric: tabular-nums;
}
.tna-state {
  display: inline-flex;
  align-items: center;
  gap: 2px;
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.3px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.48);
}
.tna-target { font-size: 9px; font-weight: 600; color: rgba(var(--v-theme-on-surface), 0.42); }
.tna-cell.is-verified .tna-value { color: #047857; }
.tna-cell.is-overdue .tna-value { color: #b91c1c; }
.tna-cell.is-overdue .tna-state { color: #b91c1c; }

:global(.v-theme--dark .auth-pill.is-good) { color: #34d399; border-color: rgba(52, 211, 153, 0.34); background: rgba(16, 185, 129, 0.14); }
:global(.v-theme--dark .auth-pill.is-warn) { color: #fbbf24; border-color: rgba(251, 191, 36, 0.34); background: rgba(245, 158, 11, 0.14); }
:global(.v-theme--dark .tna-cell.is-verified .tna-value) { color: #34d399; }
:global(.v-theme--dark .tna-cell.is-overdue .tna-value) { color: #f87171; }
</style>
