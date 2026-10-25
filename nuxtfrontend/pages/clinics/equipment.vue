<template>
  <v-container fluid class="pa-4 pa-md-6 eq-page" :style="themeVars">
    <!-- ═══════════════ Header ═══════════════ -->
    <header class="eq-head">
      <div class="eq-head-top">
        <div class="eq-head-icon">
          <v-icon size="26">mdi-cog-transfer</v-icon>
        </div>

        <div class="eq-head-id">
          <div class="eq-head-eyebrow">
            <span class="eq-live-dot"></span>
            CLINIC · BIOMEDICAL ASSET REGISTER
          </div>
          <h1 class="eq-head-title">Equipment</h1>
          <p class="eq-head-sub">{{ headSub }}</p>
        </div>

        <div class="eq-head-actions">
          <button type="button" class="eq-btn" :disabled="!assets.length" @click="exportCsv">
            <v-icon size="15">mdi-tray-arrow-down</v-icon>
            <span>Export</span>
          </button>
          <button type="button" class="eq-btn" :disabled="loading" @click="loadAll">
            <v-icon size="15" :class="{ 'eq-spin': loading }">mdi-refresh</v-icon>
            <span>Refresh</span>
          </button>
          <button type="button" class="eq-btn" @click="openFaultReport()">
            <v-icon size="15">mdi-alert-circle-outline</v-icon>
            <span>Report fault</span>
          </button>
          <button type="button" class="eq-btn is-primary" @click="openAsset()">
            <v-icon size="16">mdi-plus</v-icon>
            <span>Add asset</span>
          </button>
        </div>
      </div>

      <div class="eq-head-foot">
        <span class="eq-chip">
          <v-icon size="13">mdi-cube-outline</v-icon>
          {{ fmt(kpis.total) }} assets
        </span>
        <span class="eq-chip is-good">
          <v-icon size="13">mdi-check-circle-outline</v-icon>
          {{ kpis.uptime_pct }}% uptime
        </span>
        <span v-if="kpis.maintenance_overdue" class="eq-chip is-warn">
          <v-icon size="13">mdi-wrench-clock</v-icon>
          {{ fmt(kpis.maintenance_overdue) }} overdue service
        </span>
        <span v-if="kpis.open_faults" class="eq-chip is-bad">
          <v-icon size="13">mdi-alert-outline</v-icon>
          {{ fmt(kpis.open_faults) }} open faults
        </span>
        <span class="eq-chip">
          <v-icon size="13">mdi-cash-multiple</v-icon>
          {{ money(kpis.book_value) }} book value
        </span>
        <span class="eq-head-stamp">{{ updatedLabel }}</span>
      </div>
    </header>

    <!-- ═══════════════ KPI strip ═══════════════ -->
    <div class="eq-kpis">
      <article
        v-for="k in kpiTiles"
        :key="k.key"
        class="eq-kpi"
        :style="{ '--tone': k.tone }"
        role="button"
        tabindex="0"
        @click="applyKpi(k)"
        @keydown.enter.prevent="applyKpi(k)"
      >
        <div class="eq-kpi-top">
          <span class="eq-kpi-icon"><v-icon size="16">{{ k.icon }}</v-icon></span>
          <span class="eq-kpi-label">{{ k.label }}</span>
        </div>
        <div class="eq-kpi-value">{{ k.value }}</div>
        <div class="eq-kpi-sub">{{ k.sub }}</div>
      </article>
    </div>

    <!-- ═══════════════ Tabs ═══════════════ -->
    <nav class="eq-tabs" role="tablist">
      <button
        v-for="t in tabs"
        :key="t.value"
        type="button"
        role="tab"
        class="eq-tab"
        :class="{ 'is-on': tab === t.value }"
        :aria-selected="tab === t.value"
        @click="tab = t.value"
      >
        <v-icon size="15">{{ t.icon }}</v-icon>
        <span>{{ t.label }}</span>
        <span v-if="t.count" class="eq-tab-count" :class="t.tone ? `is-${t.tone}` : ''">{{ t.count }}</span>
      </button>
    </nav>

    <!-- ═══════════════════════ OVERVIEW ═══════════════════════ -->
    <div v-if="tab === 'overview'" class="eq-ov">
      <main class="eq-ov-main">
        <!-- Needs attention -->
        <section class="eq-panel">
          <header class="eq-panel-head">
            <span class="eq-panel-icon is-warn"><v-icon size="15">mdi-alert-decagram-outline</v-icon></span>
            <div class="eq-panel-titles">
              <h2>Needs attention</h2>
              <p>Assets with overdue servicing, faults or degraded condition</p>
            </div>
            <span class="eq-panel-count">{{ dashboard.attention.length }}</span>
          </header>

          <div v-if="dashboard.attention.length" class="eq-attn">
            <button
              v-for="row in dashboard.attention"
              :key="row.id"
              type="button"
              class="eq-attn-row"
              @click="openDetailById(row.id)"
            >
              <span class="eq-attn-score" :style="{ '--score-tone': healthColor(row.health_score) }">
                {{ row.health_score }}
              </span>
              <span class="eq-attn-id">
                <span class="eq-attn-name">{{ row.name }}</span>
                <span class="eq-attn-meta">{{ row.asset_tag }}<template v-if="row.site"> · {{ row.site }}</template></span>
              </span>
              <span class="eq-attn-reasons">
                <span
                  v-for="(r, i) in row.reasons"
                  :key="i"
                  class="eq-reason"
                  :class="`is-${r.type}`"
                >{{ r.label }}</span>
              </span>
              <v-icon size="16" class="eq-attn-chev">mdi-chevron-right</v-icon>
            </button>
          </div>
          <div v-else class="eq-panel-empty">
            <v-icon size="22" color="success">mdi-check-decagram-outline</v-icon>
            <span>Every asset is healthy — nothing needs attention right now.</span>
          </div>
        </section>

        <!-- Upcoming maintenance -->
        <section class="eq-panel">
          <header class="eq-panel-head">
            <span class="eq-panel-icon"><v-icon size="15">mdi-wrench-clock</v-icon></span>
            <div class="eq-panel-titles">
              <h2>Maintenance schedule</h2>
              <p>Next jobs across the network, soonest first</p>
            </div>
            <button type="button" class="eq-link" @click="tab = 'maintenance'">View all</button>
          </header>

          <div v-if="dashboard.upcoming_maintenance.length" class="eq-tablewrap">
            <table class="eq-table">
              <thead>
                <tr>
                  <th>Asset</th>
                  <th>Job</th>
                  <th>Scheduled</th>
                  <th class="eq-th-num">Due</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="j in dashboard.upcoming_maintenance" :key="j.id">
                  <td>
                    <div class="eq-cell-two">
                      <span class="eq-cell-title">{{ j.equipment }}</span>
                      <span class="eq-cell-sub">{{ j.asset_tag }}<template v-if="j.site"> · {{ j.site }}</template></span>
                    </div>
                  </td>
                  <td><span class="eq-tag">{{ j.kind_label }}</span></td>
                  <td><span class="eq-mono">{{ formatDate(j.scheduled_date) }}</span></td>
                  <td class="eq-td-num">
                    <span class="eq-pill" :class="dueTone(j.days_until_due)">
                      {{ dueLabel(j.days_until_due) }}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <div v-else class="eq-panel-empty">
            <v-icon size="22" color="medium-emphasis">mdi-calendar-check-outline</v-icon>
            <span>No maintenance scheduled. Add one from any asset.</span>
          </div>
        </section>
      </main>

      <aside class="eq-ov-rail">
        <!-- Health -->
        <section class="eq-panel">
          <header class="eq-panel-head">
            <span class="eq-panel-title">Fleet health</span>
            <v-icon size="15" color="medium-emphasis">mdi-gauge</v-icon>
          </header>
          <div class="eq-health">
            <div class="eq-health-ring" :style="{ '--pct': kpis.uptime_pct, '--ring': kpis.uptime_pct >= 80 ? '#10b981' : kpis.uptime_pct >= 60 ? '#f59e0b' : '#ef4444' }">
              <span class="eq-health-val">{{ kpis.uptime_pct }}<i>%</i></span>
              <span class="eq-health-cap">uptime</span>
            </div>
            <div class="eq-health-legend">
              <div v-for="s in statusRows" :key="s.label" class="eq-legend-row">
                <i :style="{ background: s.tone }" />
                <span>{{ s.label }}</span>
                <b>{{ s.count }}</b>
              </div>
            </div>
          </div>
        </section>

        <!-- By category -->
        <section class="eq-panel">
          <header class="eq-panel-head">
            <span class="eq-panel-title">By category</span>
            <span class="eq-panel-count">{{ dashboard.by_category.length }}</span>
          </header>
          <div v-if="dashboard.by_category.length" class="eq-bars">
            <div v-for="c in dashboard.by_category.slice(0, 8)" :key="c.name" class="eq-bar-row">
              <span class="eq-bar-label" :title="c.name">{{ c.name }}</span>
              <span class="eq-bar-track">
                <span class="eq-bar-fill" :style="{ width: barWidth(c.count, maxCategoryCount) }" />
              </span>
              <span class="eq-bar-val">{{ c.count }}</span>
            </div>
          </div>
          <div v-else class="eq-panel-empty"><span>No assets yet.</span></div>
        </section>

        <!-- By branch -->
        <section class="eq-panel">
          <header class="eq-panel-head">
            <span class="eq-panel-title">By clinic branch</span>
            <v-icon size="15" color="medium-emphasis">mdi-office-building-marker</v-icon>
          </header>
          <div v-if="dashboard.by_site.length" class="eq-sites">
            <div v-for="s in dashboard.by_site" :key="s.name" class="eq-site-row">
              <div class="eq-site-top">
                <span class="eq-site-name">{{ s.name }}</span>
                <span class="eq-site-count">{{ s.count }}</span>
              </div>
              <div class="eq-bar-track">
                <span class="eq-bar-fill is-good" :style="{ width: pct(s.operational, s.count) }" />
              </div>
              <div class="eq-site-foot">
                <span>{{ s.operational }} operational</span>
                <span v-if="s.at_risk" class="eq-site-risk">{{ s.at_risk }} at risk</span>
              </div>
            </div>
          </div>
          <div v-else class="eq-panel-empty"><span>No branch data.</span></div>
        </section>

        <!-- Spend -->
        <section class="eq-panel">
          <header class="eq-panel-head">
            <span class="eq-panel-title">Maintenance spend</span>
            <span class="eq-panel-count">12 mo</span>
          </header>
          <div class="eq-spend">
            <div class="eq-spend-val">{{ money(kpis.maintenance_spend_ytd) }}</div>
            <div class="eq-spend-cap">year to date · {{ fmt(kpis.downtime_hours_ytd) }} h downtime</div>
          </div>
          <SparkArea
            v-if="spendValues.length"
            :values="spendValues"
            :height="56"
            color="#2f6dff"
            :show-y-axis="false"
          />
          <div class="eq-spend-axis">
            <span v-for="(m, i) in dashboard.spend_trend" :key="i">{{ m.label }}</span>
          </div>
        </section>

        <!-- Open faults -->
        <section class="eq-panel">
          <header class="eq-panel-head">
            <span class="eq-panel-title">Open faults</span>
            <span class="eq-panel-count" :class="{ 'is-bad': dashboard.open_faults.length }">{{ dashboard.open_faults.length }}</span>
          </header>
          <div v-if="dashboard.open_faults.length" class="eq-fault-feed">
            <button
              v-for="f in dashboard.open_faults"
              :key="f.id"
              type="button"
              class="eq-fault-row"
              @click="tab = 'faults'"
            >
              <span class="eq-fault-dot" :class="`is-${f.severity}`" />
              <span class="eq-fault-id">
                <span class="eq-fault-title">{{ f.title }}</span>
                <span class="eq-fault-meta">{{ f.equipment }} · {{ f.days_open }}d open</span>
              </span>
              <span class="eq-pill" :class="`is-${f.severity}`">{{ f.severity }}</span>
            </button>
          </div>
          <div v-else class="eq-panel-empty">
            <v-icon size="20" color="success">mdi-shield-check-outline</v-icon>
            <span>No open faults.</span>
          </div>
        </section>
      </aside>
    </div>

    <!-- ═══════════════════════ ASSETS ═══════════════════════ -->
    <div v-else-if="tab === 'assets'">
      <section class="eq-toolbar">
        <v-text-field
          v-model="assetSearch"
          prepend-inner-icon="mdi-magnify"
          placeholder="Search name, asset tag, serial, manufacturer or location…"
          variant="outlined" density="compact" rounded="lg" hide-details clearable
          class="eq-search"
        />
        <v-select v-model="assetCategory" :items="categoryOptions" item-title="name" item-value="id"
          label="Category" variant="outlined" density="compact" rounded="lg" hide-details
          clearable class="eq-field" />
        <v-select v-model="assetStatus" :items="statusOptions" item-title="title" item-value="value"
          label="Status" variant="outlined" density="compact" rounded="lg" hide-details
          clearable class="eq-field" />
        <v-select v-model="assetCriticality" :items="criticalityOptions" item-title="title" item-value="value"
          label="Criticality" variant="outlined" density="compact" rounded="lg" hide-details
          clearable class="eq-field" />
        <v-select v-model="assetSite" :items="siteOptions" item-title="name" item-value="id"
          label="Branch" variant="outlined" density="compact" rounded="lg" hide-details
          clearable class="eq-field" />
        <div class="eq-viewtoggle">
          <button type="button" :class="{ 'is-on': assetView === 'grid' }" title="Card view" @click="setAssetView('grid')">
            <v-icon size="17">mdi-view-grid-outline</v-icon>
          </button>
          <button type="button" :class="{ 'is-on': assetView === 'table' }" title="Table view" @click="setAssetView('table')">
            <v-icon size="17">mdi-format-list-bulleted</v-icon>
          </button>
        </div>
      </section>

      <div v-if="activeAssetFilters" class="eq-hint">
        <v-icon size="14">mdi-filter-outline</v-icon>
        <span v-if="assetAttention" class="eq-hint-chip">{{ ATTENTION_LABELS[assetAttention] }}</span>
        <span>{{ filteredAssets.length }} of {{ assets.length }} shown</span>
        <button type="button" class="eq-link" @click="clearAssetFilters">Clear filters</button>
      </div>

      <div v-if="loading && !assets.length" class="eq-grid">
        <div v-for="n in 8" :key="n" class="eq-skel" />
      </div>

      <div v-else-if="!filteredAssets.length" class="eq-empty">
        <span class="eq-empty-icon"><v-icon size="30">mdi-cube-off-outline</v-icon></span>
        <h2>{{ assets.length ? 'No asset matches this view' : 'No equipment registered yet' }}</h2>
        <p>
          {{ assets.length
            ? 'Loosen the filters — or search by a different tag, model or location.'
            : 'Register your first asset to start tracking servicing, calibration and faults.' }}
        </p>
        <div class="eq-empty-actions">
          <button v-if="activeAssetFilters" type="button" class="eq-btn" @click="clearAssetFilters">
            <v-icon size="15">mdi-filter-remove-outline</v-icon><span>Clear filters</span>
          </button>
          <button v-else type="button" class="eq-btn is-primary" @click="openAsset()">
            <v-icon size="16">mdi-plus</v-icon><span>Add asset</span>
          </button>
        </div>
      </div>

      <!-- Asset cards -->
      <div v-else-if="assetView === 'grid'" class="eq-grid">
        <article
          v-for="(a, i) in filteredAssets"
          :key="a.id"
          class="eq-card"
          :class="[`eq-card--${a.health_label}`, { 'is-inactive': !a.is_active }]"
          :style="{ '--i': i }"
          @click="openDetail(a)"
        >
          <div class="eq-card-top">
            <span class="eq-card-glyph" :style="{ '--tone': healthColor(a.health_score) }">
              <v-icon size="18">{{ a.category_icon || categoryIcon(a.category_name) }}</v-icon>
            </span>
            <div class="eq-card-tags">
              <span class="eq-tag" :class="`is-${a.criticality}`">{{ shortCriticality(a.criticality) }}</span>
              <span class="eq-tag" :class="`is-status-${a.status}`">{{ a.status_label }}</span>
            </div>
          </div>

          <div class="eq-card-name">{{ a.name }}</div>
          <div class="eq-card-meta">{{ a.manufacturer || '—' }}<template v-if="a.model_number"> · {{ a.model_number }}</template></div>
          <div class="eq-card-tag">{{ a.asset_tag }}</div>

          <div class="eq-card-rows">
            <div class="eq-card-row">
              <v-icon size="13">mdi-office-building-marker</v-icon>
              <span :class="{ 'is-faint': !a.site_name }">{{ a.site_name || 'No branch' }}</span>
            </div>
            <div class="eq-card-row">
              <v-icon size="13">mdi-map-marker-outline</v-icon>
              <span :class="{ 'is-faint': !a.location }">{{ a.location || 'No location' }}</span>
            </div>
          </div>

          <div class="eq-card-health">
            <div class="eq-card-health-top">
              <span>Health</span>
              <b :style="{ color: healthColor(a.health_score) }">{{ a.health_score }}</b>
            </div>
            <span class="eq-bar-track">
              <span class="eq-bar-fill" :style="{ width: a.health_score + '%', background: healthColor(a.health_score) }" />
            </span>
          </div>

          <div class="eq-card-foot">
            <span class="eq-card-serv" :class="serviceTone(a)">
              <v-icon size="13">{{ a.maintenance_overdue ? 'mdi-wrench-clock' : 'mdi-wrench-outline' }}</v-icon>
              {{ serviceLabel(a) }}
            </span>
            <span v-if="a.open_faults" class="eq-pill is-bad">{{ a.open_faults }} fault{{ a.open_faults > 1 ? 's' : '' }}</span>
          </div>

          <div class="eq-card-actions" @click.stop>
            <button type="button" title="Details" @click="openDetail(a)"><v-icon size="16">mdi-eye-outline</v-icon></button>
            <button type="button" title="Schedule maintenance" @click="openMaintenance(a)"><v-icon size="16">mdi-wrench-clock</v-icon></button>
            <button type="button" title="Report fault" @click="openFaultReport(a)"><v-icon size="16">mdi-alert-circle-outline</v-icon></button>
            <button type="button" title="Edit" @click="openAsset(a)"><v-icon size="16">mdi-pencil-outline</v-icon></button>
            <span class="flex-1" />
            <button type="button" class="is-danger" title="Delete" @click="askDelete(a)"><v-icon size="16">mdi-trash-can-outline</v-icon></button>
          </div>
        </article>
      </div>

      <!-- Asset table -->
      <div v-else class="eq-tablecard">
        <table class="eq-table eq-table--assets">
          <thead>
            <tr>
              <th class="eq-th-name">Asset</th>
              <th>Category</th>
              <th>Branch</th>
              <th>Status</th>
              <th class="eq-th-num">Health</th>
              <th>Next service</th>
              <th class="eq-th-act" aria-label="Actions"></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="a in filteredAssets" :key="a.id" @click="openDetail(a)">
              <td>
                <div class="eq-cell-two">
                  <span class="eq-cell-title">{{ a.name }}</span>
                  <span class="eq-cell-sub">{{ a.asset_tag }}<template v-if="a.serial_number"> · {{ a.serial_number }}</template></span>
                </div>
              </td>
              <td><span class="eq-cell-body">{{ a.category_name || '—' }}</span></td>
              <td><span class="eq-cell-body">{{ a.site_name || '—' }}<template v-if="a.location"> · {{ a.location }}</template></span></td>
              <td><span class="eq-tag" :class="`is-status-${a.status}`">{{ a.status_label }}</span></td>
              <td class="eq-td-num">
                <span class="eq-health-mini">
                  <span class="eq-health-mini-val" :style="{ color: healthColor(a.health_score) }">{{ a.health_score }}</span>
                  <span class="eq-bar-track is-mini">
                    <span class="eq-bar-fill" :style="{ width: a.health_score + '%', background: healthColor(a.health_score) }" />
                  </span>
                </span>
              </td>
              <td>
                <span class="eq-pill" :class="serviceTone(a)">{{ serviceLabel(a) }}</span>
              </td>
              <td class="eq-th-act" @click.stop>
                <div class="eq-rowactions">
                  <button type="button" title="Details" @click="openDetail(a)"><v-icon size="16">mdi-eye-outline</v-icon></button>
                  <button type="button" title="Edit" @click="openAsset(a)"><v-icon size="16">mdi-pencil-outline</v-icon></button>
                  <button type="button" class="is-danger" title="Delete" @click="askDelete(a)"><v-icon size="16">mdi-trash-can-outline</v-icon></button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- ═══════════════════════ MAINTENANCE ═══════════════════════ -->
    <div v-else-if="tab === 'maintenance'">
      <section class="eq-toolbar">
        <v-text-field v-model="maintSearch" prepend-inner-icon="mdi-magnify"
          placeholder="Search asset, vendor, technician…" variant="outlined" density="compact"
          rounded="lg" hide-details clearable class="eq-search" />
        <v-select v-model="maintKind" :items="kindOptions" item-title="title" item-value="value"
          label="Job type" variant="outlined" density="compact" rounded="lg" hide-details
          clearable class="eq-field" />
        <v-select v-model="maintStatus" :items="maintStatusOptions" item-title="title" item-value="value"
          label="Status" variant="outlined" density="compact" rounded="lg" hide-details
          clearable class="eq-field" />
        <v-spacer />
        <button type="button" class="eq-btn is-primary" @click="openMaintenance()">
          <v-icon size="15">mdi-calendar-plus</v-icon><span>Schedule job</span>
        </button>
      </section>

      <div v-if="!filteredJobs.length" class="eq-empty">
        <span class="eq-empty-icon"><v-icon size="30">mdi-wrench-outline</v-icon></span>
        <h2>No maintenance jobs</h2>
        <p>Schedule preventive servicing, calibration or repairs for any asset.</p>
        <button type="button" class="eq-btn is-primary" @click="openMaintenance()">
          <v-icon size="16">mdi-calendar-plus</v-icon><span>Schedule job</span>
        </button>
      </div>

      <div v-else class="eq-tablecard">
        <table class="eq-table">
          <thead>
            <tr>
              <th class="eq-th-name">Asset</th>
              <th>Job</th>
              <th>Scheduled</th>
              <th>Assigned</th>
              <th class="eq-th-num">Cost</th>
              <th>Status</th>
              <th class="eq-th-act" aria-label="Actions"></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="j in filteredJobs" :key="j.id">
              <td>
                <div class="eq-cell-two">
                  <span class="eq-cell-title">{{ j.equipment_name }}</span>
                  <span class="eq-cell-sub">{{ j.equipment_tag }}<template v-if="j.site_name"> · {{ j.site_name }}</template></span>
                </div>
              </td>
              <td><span class="eq-tag">{{ j.kind_label }}</span></td>
              <td>
                <span class="eq-mono">{{ formatDate(j.scheduled_date) }}</span>
                <span v-if="j.is_overdue" class="eq-cell-sub is-bad">{{ Math.abs(j.days_until_due) }}d overdue</span>
              </td>
              <td><span class="eq-cell-body">{{ j.vendor_name || j.technician || '—' }}</span></td>
              <td class="eq-td-num"><span class="eq-mono">{{ moneyFull(j.cost) }}</span></td>
              <td><span class="eq-pill" :class="maintTone(j)">{{ j.status_label }}</span></td>
              <td class="eq-th-act">
                <div class="eq-rowactions">
                  <button v-if="j.status === 'scheduled'" type="button" title="Start job" @click="startJob(j)">
                    <v-icon size="16">mdi-play-circle-outline</v-icon>
                  </button>
                  <button v-if="j.status !== 'completed' && j.status !== 'cancelled'" type="button"
                    title="Complete job" @click="openComplete(j)">
                    <v-icon size="16">mdi-check-circle-outline</v-icon>
                  </button>
                  <button v-if="j.status === 'scheduled'" type="button" class="is-danger" title="Cancel" @click="cancelJob(j)">
                    <v-icon size="16">mdi-close-circle-outline</v-icon>
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- ═══════════════════════ FAULTS ═══════════════════════ -->
    <div v-else-if="tab === 'faults'">
      <section class="eq-toolbar">
        <v-text-field v-model="faultSearch" prepend-inner-icon="mdi-magnify"
          placeholder="Search fault, asset or description…" variant="outlined" density="compact"
          rounded="lg" hide-details clearable class="eq-search" />
        <v-select v-model="faultSeverity" :items="severityOptions" item-title="title" item-value="value"
          label="Severity" variant="outlined" density="compact" rounded="lg" hide-details
          clearable class="eq-field" />
        <v-select v-model="faultStatus" :items="faultStatusOptions" item-title="title" item-value="value"
          label="Status" variant="outlined" density="compact" rounded="lg" hide-details
          clearable class="eq-field" />
        <v-spacer />
        <button type="button" class="eq-btn is-primary" @click="openFaultReport()">
          <v-icon size="15">mdi-alert-plus</v-icon><span>Report fault</span>
        </button>
      </section>

      <div v-if="!filteredFaults.length" class="eq-empty">
        <span class="eq-empty-icon"><v-icon size="30">mdi-shield-check-outline</v-icon></span>
        <h2>No faults reported</h2>
        <p>Nothing to action — report a fault when a device misbehaves on the floor.</p>
        <button type="button" class="eq-btn is-primary" @click="openFaultReport()">
          <v-icon size="16">mdi-alert-plus</v-icon><span>Report fault</span>
        </button>
      </div>

      <div v-else class="eq-faultgrid">
        <article v-for="f in filteredFaults" :key="f.id" class="eq-faultcard" :class="`is-${f.severity}`">
          <div class="eq-faultcard-top">
            <span class="eq-fault-dot" :class="`is-${f.severity}`" />
            <span class="eq-pill" :class="`is-${f.severity}`">{{ f.severity_label }}</span>
            <span class="eq-pill" :class="f.is_open ? 'is-warn' : 'is-good'">{{ f.status_label }}</span>
            <v-spacer />
            <span v-if="f.is_open" class="eq-fault-age">{{ f.days_open }}d open</span>
          </div>
          <h3 class="eq-faultcard-title">{{ f.title }}</h3>
          <p class="eq-faultcard-desc">{{ f.description || 'No description supplied.' }}</p>
          <div class="eq-faultcard-meta">
            <span><v-icon size="12">mdi-cube-outline</v-icon>{{ f.equipment_name }}</span>
            <span><v-icon size="12">mdi-tag-outline</v-icon>{{ f.equipment_tag }}</span>
            <span v-if="f.site_name"><v-icon size="12">mdi-office-building-marker</v-icon>{{ f.site_name }}</span>
          </div>
          <div v-if="f.resolution" class="eq-faultcard-res">
            <v-icon size="13">mdi-check-circle-outline</v-icon>
            <span>{{ f.resolution }}</span>
          </div>
          <div class="eq-faultcard-foot">
            <span class="eq-cell-sub">Reported {{ relativeTime(f.reported_at) }}</span>
            <v-spacer />
            <button v-if="f.is_open" type="button" class="eq-btn is-sm is-primary" @click="openResolve(f)">
              <v-icon size="14">mdi-check</v-icon><span>Resolve</span>
            </button>
            <button v-if="f.is_open" type="button" class="eq-btn is-sm" @click="dismissFault(f)">Dismiss</button>
          </div>
        </article>
      </div>
    </div>

    <!-- ═══════════════════════ TRANSFERS ═══════════════════════ -->
    <div v-else>
      <section class="eq-toolbar">
        <v-text-field v-model="transferSearch" prepend-inner-icon="mdi-magnify"
          placeholder="Search asset or reason…" variant="outlined" density="compact"
          rounded="lg" hide-details clearable class="eq-search" />
        <v-spacer />
        <button type="button" class="eq-btn is-primary" @click="openTransfer()">
          <v-icon size="15">mdi-swap-horizontal</v-icon><span>Transfer asset</span>
        </button>
      </section>

      <div v-if="!filteredTransfers.length" class="eq-empty">
        <span class="eq-empty-icon"><v-icon size="30">mdi-swap-horizontal</v-icon></span>
        <h2>No transfers recorded</h2>
        <p>Move an asset between branches or departments and keep custody history intact.</p>
        <button type="button" class="eq-btn is-primary" @click="openTransfer()">
          <v-icon size="16">mdi-swap-horizontal</v-icon><span>Transfer asset</span>
        </button>
      </div>

      <div v-else class="eq-tablecard">
        <table class="eq-table">
          <thead>
            <tr>
              <th class="eq-th-name">Asset</th>
              <th>From</th>
              <th>To</th>
              <th>Reason</th>
              <th>Moved by</th>
              <th>When</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="t in filteredTransfers" :key="t.id">
              <td>
                <div class="eq-cell-two">
                  <span class="eq-cell-title">{{ t.equipment_name }}</span>
                  <span class="eq-cell-sub">{{ t.equipment_tag }}</span>
                </div>
              </td>
              <td><span class="eq-cell-body">{{ t.from_site_name || '—' }}<template v-if="t.from_department_name"> · {{ t.from_department_name }}</template></span></td>
              <td><span class="eq-cell-body">{{ t.to_site_name || '—' }}<template v-if="t.to_department_name"> · {{ t.to_department_name }}</template></span></td>
              <td><span class="eq-cell-body">{{ t.reason || '—' }}</span></td>
              <td><span class="eq-cell-body">{{ t.transferred_by_name || '—' }}</span></td>
              <td><span class="eq-mono">{{ relativeTime(t.transferred_at) }}</span></td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- ═══════════════ Asset detail dialog ═══════════════ -->
    <v-dialog v-model="detailOpen" max-width="820" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader
          :icon="detail?.category_icon || 'mdi-cog-transfer'"
          :title="detail?.name || 'Asset'"
          :subtitle="detail ? `${detail.asset_tag}${detail.site_name ? ' · ' + detail.site_name : ''}` : ''"
          @close="detailOpen = false"
        >
          <template #actions>
            <span v-if="detail" class="eq-dialog-chip">{{ detail.status_label }}</span>
          </template>
        </BrandDialogHeader>

        <v-card-text v-if="detail" class="pt-4">
          <div class="eq-dl-top">
            <div class="eq-dl-score" :style="{ '--tone': healthColor(detail.health_score) }">
              <b>{{ detail.health_score }}</b>
              <span>{{ detail.health_label.replace(/_/g, ' ') }}</span>
            </div>
            <div class="eq-dl-facts">
              <div><span>Criticality</span><b>{{ detail.criticality_label }}</b></div>
              <div><span>Condition</span><b>{{ detail.condition_label }}</b></div>
              <div><span>Ownership</span><b>{{ detail.ownership_label }}</b></div>
              <div><span>Category</span><b>{{ detail.category_name || '—' }}</b></div>
            </div>
          </div>

          <v-row dense class="mt-1">
            <v-col cols="6" md="4">
              <div class="eq-dl-k">Manufacturer</div>
              <div class="eq-dl-v">{{ detail.manufacturer || '—' }}</div>
            </v-col>
            <v-col cols="6" md="4">
              <div class="eq-dl-k">Model</div>
              <div class="eq-dl-v">{{ detail.model_number || '—' }}</div>
            </v-col>
            <v-col cols="6" md="4">
              <div class="eq-dl-k">Serial</div>
              <div class="eq-dl-v">{{ detail.serial_number || '—' }}</div>
            </v-col>
            <v-col cols="6" md="4">
              <div class="eq-dl-k">Branch</div>
              <div class="eq-dl-v">{{ detail.site_name || '—' }}</div>
            </v-col>
            <v-col cols="6" md="4">
              <div class="eq-dl-k">Department</div>
              <div class="eq-dl-v">{{ detail.department_name || '—' }}</div>
            </v-col>
            <v-col cols="6" md="4">
              <div class="eq-dl-k">Location</div>
              <div class="eq-dl-v">{{ detail.location || '—' }}</div>
            </v-col>
            <v-col cols="6" md="4">
              <div class="eq-dl-k">Custodian</div>
              <div class="eq-dl-v">{{ detail.custodian_name || '—' }}</div>
            </v-col>
            <v-col cols="6" md="4">
              <div class="eq-dl-k">Purchased</div>
              <div class="eq-dl-v">{{ detail.purchase_date ? formatDate(detail.purchase_date) : '—' }}</div>
            </v-col>
            <v-col cols="6" md="4">
              <div class="eq-dl-k">Purchase price</div>
              <div class="eq-dl-v">{{ moneyFull(detail.purchase_price) }}</div>
            </v-col>
            <v-col cols="6" md="4">
              <div class="eq-dl-k">Warranty</div>
              <div class="eq-dl-v" :class="{ 'is-bad': detail.warranty_expired }">
                {{ detail.warranty_expiry ? formatDate(detail.warranty_expiry) : '—' }}
                <span v-if="detail.warranty_expired" class="eq-dl-note">expired</span>
              </div>
            </v-col>
            <v-col cols="6" md="4">
              <div class="eq-dl-k">Next service</div>
              <div class="eq-dl-v">{{ detail.next_maintenance ? formatDate(detail.next_maintenance) : '—' }}</div>
            </v-col>
            <v-col cols="6" md="4">
              <div class="eq-dl-k">Next calibration</div>
              <div class="eq-dl-v" :class="{ 'is-bad': detail.calibration_overdue }">
                {{ detail.next_calibration ? formatDate(detail.next_calibration) : 'Not tracked' }}
              </div>
            </v-col>
          </v-row>

          <div v-if="detail.description" class="eq-dl-section">
            <div class="eq-dl-k">Description</div>
            <p class="eq-dl-text">{{ detail.description }}</p>
          </div>

          <!-- Maintenance history -->
          <div class="eq-dl-section">
            <div class="eq-dl-head">
              <span>Maintenance history</span>
              <button type="button" class="eq-link" @click="openMaintenance(detail)">Schedule job</button>
            </div>
            <div v-if="detail.maintenance && detail.maintenance.length" class="eq-mini-list">
              <div v-for="m in detail.maintenance" :key="m.id" class="eq-mini-row">
                <span class="eq-tag">{{ m.kind_label }}</span>
                <span class="eq-mini-main">{{ formatDate(m.scheduled_date) }}</span>
                <span class="eq-mini-sub">{{ m.vendor_name || m.technician || '—' }}</span>
                <span class="eq-pill" :class="maintTone(m)">{{ m.status_label }}</span>
              </div>
            </div>
            <div v-else class="eq-panel-empty"><span>No maintenance recorded.</span></div>
          </div>

          <!-- Faults -->
          <div class="eq-dl-section">
            <div class="eq-dl-head">
              <span>Faults</span>
              <button type="button" class="eq-link" @click="openFaultReport(detail)">Report fault</button>
            </div>
            <div v-if="detail.faults && detail.faults.length" class="eq-mini-list">
              <div v-for="f in detail.faults" :key="f.id" class="eq-mini-row">
                <span class="eq-pill" :class="`is-${f.severity}`">{{ f.severity }}</span>
                <span class="eq-mini-main">{{ f.title }}</span>
                <span class="eq-mini-sub">{{ relativeTime(f.reported_at) }}</span>
                <span class="eq-pill" :class="f.is_open ? 'is-warn' : 'is-good'">{{ f.status_label }}</span>
              </div>
            </div>
            <div v-else class="eq-panel-empty"><span>No faults reported.</span></div>
          </div>

          <!-- Transfers -->
          <div class="eq-dl-section">
            <div class="eq-dl-head">
              <span>Movement history</span>
              <button type="button" class="eq-link" @click="openTransfer(detail)">Transfer</button>
            </div>
            <div v-if="detail.transfers && detail.transfers.length" class="eq-mini-list">
              <div v-for="t in detail.transfers" :key="t.id" class="eq-mini-row">
                <span class="eq-mini-main">{{ t.from_site_name || '—' }} → {{ t.to_site_name || '—' }}</span>
                <span class="eq-mini-sub">{{ t.reason || 'No reason' }}</span>
                <span class="eq-mini-sub">{{ relativeTime(t.transferred_at) }}</span>
              </div>
            </div>
            <div v-else class="eq-panel-empty"><span>Never transferred.</span></div>
          </div>
        </v-card-text>

        <v-card-actions class="px-5 py-3">
          <v-btn variant="text" rounded="lg" class="text-none" @click="detailOpen = false">Close</v-btn>
          <v-spacer />
          <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-pencil-outline"
            @click="detailOpen = false; openAsset(detail)">Edit</v-btn>
          <v-btn color="primary" variant="flat" rounded="lg" class="text-none"
            prepend-icon="mdi-wrench-clock" @click="detailOpen = false; openMaintenance(detail)">
            Schedule service
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ Asset form dialog ═══════════════ -->
    <v-dialog v-model="assetOpen" max-width="940" persistent scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader
          :icon="editingAsset ? 'mdi-pencil-outline' : 'mdi-plus-circle-outline'"
          :title="editingAsset ? 'Edit asset' : 'Register equipment'"
          :subtitle="editingAsset ? 'Update this asset’s register entry' : 'Add a device to the clinic estate'"
          @close="closeAsset"
        />
        <v-card-text class="pt-4">
          <v-form ref="assetFormRef" @submit.prevent="saveAsset">
            <div class="eq-form-group">
              <div class="eq-form-group-title">Identity</div>
              <v-row dense>
                <v-col cols="12" md="6">
                  <v-text-field v-model="assetForm.name" label="Asset name" required
                    variant="outlined" density="compact" rounded="lg"
                    prepend-inner-icon="mdi-cube-outline" :rules="req"
                    placeholder="e.g. Patient Monitor 5-Parameter" />
                </v-col>
                <v-col cols="6" md="3">
                  <v-text-field v-model="assetForm.asset_tag" label="Asset tag"
                    variant="outlined" density="compact" rounded="lg"
                    prepend-inner-icon="mdi-tag-outline" placeholder="Auto-generated" />
                </v-col>
                <v-col cols="6" md="3">
                  <v-text-field v-model="assetForm.serial_number" label="Serial number"
                    variant="outlined" density="compact" rounded="lg"
                    prepend-inner-icon="mdi-barcode" />
                </v-col>
                <v-col cols="6" md="4">
                  <v-select v-model="assetForm.category" :items="categories" item-title="name"
                    item-value="id" label="Category" variant="outlined" density="compact"
                    rounded="lg" prepend-inner-icon="mdi-shape" clearable />
                </v-col>
                <v-col cols="6" md="4">
                  <v-text-field v-model="assetForm.manufacturer" label="Manufacturer"
                    variant="outlined" density="compact" rounded="lg"
                    prepend-inner-icon="mdi-factory" />
                </v-col>
                <v-col cols="6" md="4">
                  <v-text-field v-model="assetForm.model_number" label="Model"
                    variant="outlined" density="compact" rounded="lg"
                    prepend-inner-icon="mdi-cube-scan" />
                </v-col>
              </v-row>
            </div>

            <div class="eq-form-group">
              <div class="eq-form-group-title">Placement &amp; state</div>
              <v-row dense>
                <v-col cols="6" md="3">
                  <v-select v-model="assetForm.site" :items="sites" item-title="name"
                    item-value="id" label="Clinic branch" variant="outlined" density="compact"
                    rounded="lg" prepend-inner-icon="mdi-office-building-marker" clearable />
                </v-col>
                <v-col cols="6" md="3">
                  <v-select v-model="assetForm.department" :items="departments" item-title="name"
                    item-value="id" label="Department" variant="outlined" density="compact"
                    rounded="lg" prepend-inner-icon="mdi-domain" clearable />
                </v-col>
                <v-col cols="6" md="3">
                  <v-text-field v-model="assetForm.location" label="Location / room"
                    variant="outlined" density="compact" rounded="lg"
                    prepend-inner-icon="mdi-map-marker-outline" />
                </v-col>
                <v-col cols="6" md="3">
                  <v-select v-model="assetForm.status" :items="statusOptions" item-title="title"
                    item-value="value" label="Status" variant="outlined" density="compact"
                    rounded="lg" prepend-inner-icon="mdi-progress-check" />
                </v-col>
                <v-col cols="6" md="3">
                  <v-select v-model="assetForm.condition" :items="conditionOptions" item-title="title"
                    item-value="value" label="Condition" variant="outlined" density="compact"
                    rounded="lg" prepend-inner-icon="mdi-shield-check-outline" />
                </v-col>
                <v-col cols="6" md="3">
                  <v-select v-model="assetForm.criticality" :items="criticalityOptions" item-title="title"
                    item-value="value" label="Criticality" variant="outlined" density="compact"
                    rounded="lg" prepend-inner-icon="mdi-alert-decagram-outline" />
                </v-col>
                <v-col cols="6" md="3">
                  <v-select v-model="assetForm.ownership" :items="ownershipOptions" item-title="title"
                    item-value="value" label="Ownership" variant="outlined" density="compact"
                    rounded="lg" prepend-inner-icon="mdi-file-sign" />
                </v-col>
                <v-col cols="6" md="3">
                  <v-switch v-model="assetForm.is_active" label="Active" color="success"
                    density="compact" hide-details class="mt-2" />
                </v-col>
              </v-row>
            </div>

            <div class="eq-form-group">
              <div class="eq-form-group-title">Acquisition</div>
              <v-row dense>
                <v-col cols="6" md="3">
                  <v-text-field v-model="assetForm.purchase_date" label="Purchase date" type="date"
                    variant="outlined" density="compact" rounded="lg" />
                </v-col>
                <v-col cols="6" md="3">
                  <v-text-field v-model.number="assetForm.purchase_price" label="Purchase price"
                    type="number" min="0" step="0.01" variant="outlined" density="compact"
                    rounded="lg" prepend-inner-icon="mdi-cash" />
                </v-col>
                <v-col cols="6" md="3">
                  <v-text-field v-model="assetForm.supplier_name" label="Supplier"
                    variant="outlined" density="compact" rounded="lg"
                    prepend-inner-icon="mdi-truck-delivery-outline" />
                </v-col>
                <v-col cols="6" md="3">
                  <v-text-field v-model="assetForm.warranty_expiry" label="Warranty expiry" type="date"
                    variant="outlined" density="compact" rounded="lg" />
                </v-col>
                <v-col cols="6" md="3">
                  <v-text-field v-model="assetForm.commissioned_on" label="Commissioned" type="date"
                    variant="outlined" density="compact" rounded="lg" />
                </v-col>
                <v-col cols="6" md="3">
                  <v-text-field v-model.number="assetForm.expected_life_years" label="Useful life (years)"
                    type="number" min="0" variant="outlined" density="compact" rounded="lg" />
                </v-col>
              </v-row>
            </div>

            <div class="eq-form-group">
              <div class="eq-form-group-title">Servicing</div>
              <v-row dense>
                <v-col cols="6" md="3">
                  <v-text-field v-model.number="assetForm.maintenance_interval_days" label="Service interval (days)"
                    type="number" min="0" variant="outlined" density="compact" rounded="lg"
                    hint="0 = use category default" persistent-hint />
                </v-col>
                <v-col cols="6" md="3">
                  <v-text-field v-model="assetForm.last_maintenance" label="Last service" type="date"
                    variant="outlined" density="compact" rounded="lg" />
                </v-col>
                <v-col cols="6" md="3">
                  <v-text-field v-model="assetForm.next_maintenance" label="Next service" type="date"
                    variant="outlined" density="compact" rounded="lg" />
                </v-col>
                <v-col cols="6" md="3">
                  <v-switch v-model="assetForm.calibration_required" label="Requires calibration"
                    color="info" density="compact" hide-details class="mt-2" />
                </v-col>
                <v-col cols="6" md="3">
                  <v-text-field v-model="assetForm.last_calibration" label="Last calibration" type="date"
                    variant="outlined" density="compact" rounded="lg"
                    :disabled="!assetForm.calibration_required" />
                </v-col>
                <v-col cols="6" md="3">
                  <v-text-field v-model="assetForm.next_calibration" label="Next calibration" type="date"
                    variant="outlined" density="compact" rounded="lg"
                    :disabled="!assetForm.calibration_required" />
                </v-col>
                <v-col cols="6" md="3">
                  <v-text-field v-model.number="assetForm.calibration_interval_days" label="Calibration interval (days)"
                    type="number" min="0" variant="outlined" density="compact" rounded="lg"
                    :disabled="!assetForm.calibration_required" />
                </v-col>
              </v-row>
            </div>

            <div class="eq-form-group">
              <div class="eq-form-group-title">Notes</div>
              <v-textarea v-model="assetForm.description" label="Description / notes"
                variant="outlined" density="compact" rounded="lg" rows="2" auto-grow />
            </div>

            <v-alert v-if="assetError" type="error" variant="tonal" density="compact" class="mt-2">
              {{ assetError }}
            </v-alert>
          </v-form>
        </v-card-text>
        <v-divider />
        <v-card-actions class="px-5 py-3">
          <v-btn variant="text" rounded="lg" class="text-none" :disabled="saving" @click="closeAsset">Cancel</v-btn>
          <v-spacer />
          <v-btn color="primary" variant="flat" rounded="lg" class="text-none" :loading="saving"
            :prepend-icon="editingAsset ? 'mdi-content-save-outline' : 'mdi-plus'"
            @click="saveAsset">
            {{ editingAsset ? 'Save changes' : 'Register asset' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ Schedule maintenance ═══════════════ -->
    <v-dialog v-model="maintOpen" max-width="640" persistent scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-wrench-clock" title="Schedule maintenance"
          subtitle="Preventive service, calibration, inspection or repair" @close="maintOpen = false" />
        <v-card-text class="pt-4">
          <div class="eq-field">
            <label class="eq-label">Asset <span class="eq-req">*</span></label>
            <v-autocomplete v-model="maintForm.equipment" :items="assets" item-title="name"
              item-value="id" variant="outlined" density="compact" rounded="lg"
              prepend-inner-icon="mdi-cube-outline" hide-details="auto"
              :error-messages="maintForm.equipment ? '' : maintError" />
          </div>
          <v-row dense>
            <v-col cols="6">
              <v-select v-model="maintForm.kind" :items="kindOptions" item-title="title"
                item-value="value" label="Job type" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="6">
              <v-text-field v-model="maintForm.scheduled_date" label="Scheduled date" type="date"
                variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="6">
              <v-select v-model="maintForm.performed_by" :items="performedByOptions" item-title="title"
                item-value="value" label="Performed by" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="6">
              <v-text-field v-model="maintForm.vendor_name" label="Vendor / team"
                variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="6">
              <v-text-field v-model="maintForm.technician" label="Technician"
                variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="6">
              <v-text-field v-model.number="maintForm.cost" label="Estimated cost" type="number"
                min="0" step="0.01" variant="outlined" density="compact" rounded="lg"
                prepend-inner-icon="mdi-cash" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="maintForm.description" label="Work description"
                variant="outlined" density="compact" rounded="lg" rows="2" auto-grow />
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions class="px-5 py-3">
          <v-btn variant="text" rounded="lg" class="text-none" @click="maintOpen = false">Cancel</v-btn>
          <v-spacer />
          <v-btn color="primary" variant="flat" rounded="lg" class="text-none"
            :loading="saving" prepend-icon="mdi-calendar-check" @click="saveMaintenance">
            Schedule
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ Complete maintenance ═══════════════ -->
    <v-dialog v-model="completeOpen" max-width="600" persistent scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-check-circle-outline" title="Complete job"
          :subtitle="completeTarget ? `${completeTarget.equipment_name} · ${completeTarget.kind_label}` : ''"
          @close="completeOpen = false" />
        <v-card-text class="pt-4">
          <v-row dense>
            <v-col cols="6">
              <v-text-field v-model="completeForm.completed_date" label="Completion date" type="date"
                variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="6">
              <v-text-field v-model.number="completeForm.cost" label="Actual cost" type="number"
                min="0" step="0.01" variant="outlined" density="compact" rounded="lg"
                prepend-inner-icon="mdi-cash" />
            </v-col>
            <v-col cols="6">
              <v-text-field v-model.number="completeForm.downtime_hours" label="Downtime (hours)"
                type="number" min="0" step="0.1" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="6">
              <v-text-field v-model="completeForm.next_due_date" label="Next due" type="date"
                variant="outlined" density="compact" rounded="lg"
                hint="Blank = interval default" persistent-hint />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="completeForm.findings" label="Findings / work done"
                variant="outlined" density="compact" rounded="lg" rows="2" auto-grow />
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions class="px-5 py-3">
          <v-btn variant="text" rounded="lg" class="text-none" @click="completeOpen = false">Cancel</v-btn>
          <v-spacer />
          <v-btn color="success" variant="flat" rounded="lg" class="text-none"
            :loading="saving" prepend-icon="mdi-check" @click="completeJob">
            Complete
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ Report fault ═══════════════ -->
    <v-dialog v-model="faultOpen" max-width="620" persistent scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-alert-circle-outline" title="Report fault"
          subtitle="Log a device problem for the biomedical team" @close="faultOpen = false" />
        <v-card-text class="pt-4">
          <div class="eq-field">
            <label class="eq-label">Asset <span class="eq-req">*</span></label>
            <v-autocomplete v-model="faultForm.equipment" :items="assets" item-title="name"
              item-value="id" variant="outlined" density="compact" rounded="lg"
              prepend-inner-icon="mdi-cube-outline" hide-details="auto"
              :error-messages="faultError" />
          </div>
          <div class="eq-field">
            <label class="eq-label">Fault summary <span class="eq-req">*</span></label>
            <v-text-field v-model="faultForm.title" variant="outlined" density="compact"
              rounded="lg" prepend-inner-icon="mdi-alert-outline"
              placeholder="e.g. Screen flickers after warm-up" hide-details />
          </div>
          <v-row dense>
            <v-col cols="6">
              <v-select v-model="faultForm.severity" :items="severityOptions" item-title="title"
                item-value="value" label="Severity" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="6">
              <v-text-field v-model.number="faultForm.downtime_hours" label="Downtime so far (hours)"
                type="number" min="0" step="0.1" variant="outlined" density="compact" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="faultForm.description" label="What happened?"
                variant="outlined" density="compact" rounded="lg" rows="3" auto-grow />
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions class="px-5 py-3">
          <v-btn variant="text" rounded="lg" class="text-none" @click="faultOpen = false">Cancel</v-btn>
          <v-spacer />
          <v-btn color="error" variant="flat" rounded="lg" class="text-none"
            :loading="saving" prepend-icon="mdi-alert-plus" @click="saveFault">
            Report fault
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ Resolve fault ═══════════════ -->
    <v-dialog v-model="resolveOpen" max-width="560" persistent scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-check-decagram-outline" title="Resolve fault"
          :subtitle="resolveTarget?.title || ''" @close="resolveOpen = false" />
        <v-card-text class="pt-4">
          <v-textarea v-model="resolveForm.resolution" label="Resolution" variant="outlined"
            density="compact" rounded="lg" rows="3" auto-grow
            placeholder="What fixed it? Include parts replaced or verification performed." />
          <v-text-field v-model.number="resolveForm.downtime_hours" label="Total downtime (hours)"
            type="number" min="0" step="0.1" variant="outlined" density="compact"
            rounded="lg" class="mt-2" />
        </v-card-text>
        <v-divider />
        <v-card-actions class="px-5 py-3">
          <v-btn variant="text" rounded="lg" class="text-none" @click="resolveOpen = false">Cancel</v-btn>
          <v-spacer />
          <v-btn color="success" variant="flat" rounded="lg" class="text-none"
            :loading="saving" prepend-icon="mdi-check" @click="resolveFault">Resolve</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ Transfer asset ═══════════════ -->
    <v-dialog v-model="transferOpen" max-width="620" persistent scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-swap-horizontal" title="Transfer asset"
          subtitle="Move equipment between branches and departments" @close="transferOpen = false" />
        <v-card-text class="pt-4">
          <div class="eq-field">
            <label class="eq-label">Asset <span class="eq-req">*</span></label>
            <v-autocomplete v-model="transferForm.equipment" :items="assets" item-title="name"
              item-value="id" variant="outlined" density="compact" rounded="lg"
              prepend-inner-icon="mdi-cube-outline" hide-details="auto"
              :error-messages="transferError" />
          </div>
          <v-row dense>
            <v-col cols="6">
              <v-select v-model="transferForm.to_site" :items="sites" item-title="name"
                item-value="id" label="To branch" variant="outlined" density="compact"
                rounded="lg" clearable />
            </v-col>
            <v-col cols="6">
              <v-select v-model="transferForm.to_department" :items="departments" item-title="name"
                item-value="id" label="To department" variant="outlined" density="compact"
                rounded="lg" clearable />
            </v-col>
            <v-col cols="12">
              <v-text-field v-model="transferForm.reason" label="Reason" variant="outlined"
                density="compact" rounded="lg" placeholder="e.g. Theatre capacity expansion" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="transferForm.notes" label="Notes" variant="outlined"
                density="compact" rounded="lg" rows="2" auto-grow />
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <v-card-actions class="px-5 py-3">
          <v-btn variant="text" rounded="lg" class="text-none" @click="transferOpen = false">Cancel</v-btn>
          <v-spacer />
          <v-btn color="primary" variant="flat" rounded="lg" class="text-none"
            :loading="saving" prepend-icon="mdi-swap-horizontal" @click="saveTransfer">Transfer</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ Delete confirm ═══════════════ -->
    <v-dialog v-model="deleteOpen" max-width="440">
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-trash-can-outline" title="Remove asset"
          :subtitle="deleteTarget?.asset_tag || ''" @close="deleteOpen = false" />
        <v-card-text class="pt-4">
          <p class="eq-confirm">
            Remove <strong>{{ deleteTarget?.name }}</strong> from the register? Its maintenance
            history, faults and transfers are deleted with it. Retire the asset instead if you
            need the record.
          </p>
        </v-card-text>
        <v-card-actions class="px-5 py-3">
          <v-btn variant="text" rounded="lg" class="text-none" @click="deleteOpen = false">Cancel</v-btn>
          <v-spacer />
          <v-btn color="error" variant="flat" rounded="lg" class="text-none" :loading="saving"
            prepend-icon="mdi-trash-can-outline" @click="confirmDelete">Remove</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="bottom right" rounded="lg" timeout="4200">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const brand = useBranding()

const API = '/clinic-equipment'

// ── State ───────────────────────────────────────────────────────────────
const tab = ref('overview')
const loading = ref(false)
const saving = ref(false)
const updatedAt = ref(null)
const now = ref(Date.now())

const dashboard = ref({
  attention: [], upcoming_maintenance: [], open_faults: [],
  by_category: [], by_status: [], by_site: [], spend_trend: [],
})
const kpis = ref({
  total: 0, operational: 0, in_repair: 0, out_of_service: 0, retired: 0,
  maintenance_overdue: 0, calibration_overdue: 0, maintenance_due_soon: 0,
  warranty_expiring: 0, open_faults: 0, uptime_pct: 0,
  purchase_value: 0, book_value: 0,
  maintenance_spend_ytd: 0, downtime_hours_ytd: 0,
})

const assets = ref([])
const jobs = ref([])
const faults = ref([])
const transfers = ref([])
const categories = ref([])
const sites = ref([])
const departments = ref([])

// ── Filters ─────────────────────────────────────────────────────────────
const assetSearch = ref('')
const assetCategory = ref(null)
const assetStatus = ref(null)
const assetCriticality = ref(null)
const assetSite = ref(null)
const assetAttention = ref(null) // null | 'service' | 'calibration' | 'faults'
const assetView = ref('table')

const maintSearch = ref('')
const maintKind = ref(null)
const maintStatus = ref(null)

const faultSearch = ref('')
const faultSeverity = ref(null)
const faultStatus = ref(null)

const transferSearch = ref('')

// ── Static options ──────────────────────────────────────────────────────
const statusOptions = [
  { title: 'Operational', value: 'operational' },
  { title: 'Under maintenance', value: 'under_maintenance' },
  { title: 'Out of service', value: 'out_of_service' },
  { title: 'In storage', value: 'in_storage' },
  { title: 'Retired', value: 'retired' },
]
const conditionOptions = [
  { title: 'Excellent', value: 'excellent' },
  { title: 'Good', value: 'good' },
  { title: 'Fair', value: 'fair' },
  { title: 'Poor', value: 'poor' },
  { title: 'Unusable', value: 'unusable' },
]
const criticalityOptions = [
  { title: 'Life support', value: 'life_support' },
  { title: 'Critical', value: 'critical' },
  { title: 'Essential', value: 'essential' },
  { title: 'Optional', value: 'optional' },
]
const ownershipOptions = [
  { title: 'Owned', value: 'owned' },
  { title: 'Leased', value: 'leased' },
  { title: 'Donated', value: 'donated' },
  { title: 'Grant / programme', value: 'grant' },
]
const kindOptions = [
  { title: 'Preventive service', value: 'preventive' },
  { title: 'Corrective repair', value: 'corrective' },
  { title: 'Calibration', value: 'calibration' },
  { title: 'Safety inspection', value: 'inspection' },
  { title: 'Upgrade', value: 'upgrade' },
]
const maintStatusOptions = [
  { title: 'Scheduled', value: 'scheduled' },
  { title: 'In progress', value: 'in_progress' },
  { title: 'Completed', value: 'completed' },
  { title: 'Cancelled', value: 'cancelled' },
]
const performedByOptions = [
  { title: 'Biomedical team', value: 'internal' },
  { title: 'External vendor', value: 'vendor' },
  { title: 'Manufacturer', value: 'manufacturer' },
]
const severityOptions = [
  { title: 'Low', value: 'low' },
  { title: 'Medium', value: 'medium' },
  { title: 'High', value: 'high' },
  { title: 'Critical', value: 'critical' },
]
const faultStatusOptions = [
  { title: 'Open', value: 'open' },
  { title: 'Investigating', value: 'investigating' },
  { title: 'Resolved', value: 'resolved' },
  { title: 'Dismissed', value: 'dismissed' },
]

const req = [v => !!(v && String(v).trim()) || 'Required']

const themeVars = computed(() => ({
  '--eq-accent': brand.primary.value,
  '--eq-on-accent': brand.onPrimary.value,
  '--eq-accent-ink': brand.ink.value,
  '--eq-accent-soft': brand.tint('primary', 0.18),
  '--eq-accent-ring': brand.tint('primary', 0.24),
}))

// ── Tabs + KPIs ─────────────────────────────────────────────────────────
const tabs = computed(() => [
  { value: 'overview', label: 'Overview', icon: 'mdi-view-dashboard-outline', count: null },
  { value: 'assets', label: 'Assets', icon: 'mdi-cube-outline', count: assets.value.length },
  {
    value: 'maintenance', label: 'Maintenance', icon: 'mdi-wrench-outline',
    count: kpis.value.maintenance_overdue || null, tone: 'warn',
  },
  {
    value: 'faults', label: 'Faults', icon: 'mdi-alert-outline',
    count: kpis.value.open_faults || null, tone: 'bad',
  },
  { value: 'transfers', label: 'Transfers', icon: 'mdi-swap-horizontal', count: transfers.value.length || null },
])

const kpiTiles = computed(() => [
  {
    key: 'total', label: 'Total assets', icon: 'mdi-cube-outline', tone: '#2f6dff',
    value: fmt(kpis.value.total), sub: `${fmt(kpis.value.operational)} operational`,
    jump: { tab: 'assets' },
  },
  {
    key: 'uptime', label: 'Fleet uptime', icon: 'mdi-gauge', tone: uptimeTone(),
    value: `${kpis.value.uptime_pct}%`,
    sub: `${fmt(kpis.value.in_repair + kpis.value.out_of_service)} unavailable`,
    jump: { tab: 'assets' },
  },
  {
    key: 'overdue', label: 'Service overdue', icon: 'mdi-wrench-clock', tone: '#f59e0b',
    value: fmt(kpis.value.maintenance_overdue),
    sub: `${fmt(kpis.value.maintenance_due_soon)} due in 14 days`,
    jump: { tab: 'assets', attention: 'service' },
  },
  {
    key: 'calibration', label: 'Calibration', icon: 'mdi-tune-vertical', tone: '#8b5cf6',
    value: fmt(kpis.value.calibration_overdue),
    sub: 'overdue devices',
    jump: { tab: 'assets', attention: 'calibration' },
  },
  {
    key: 'faults', label: 'Open faults', icon: 'mdi-alert-circle-outline', tone: '#ef4444',
    value: fmt(kpis.value.open_faults), sub: 'awaiting repair',
    jump: { tab: 'faults', status: 'open' },
  },
  {
    key: 'value', label: 'Book value', icon: 'mdi-cash-multiple', tone: '#0d9488',
    value: money(kpis.value.book_value),
    sub: `${money(kpis.value.maintenance_spend_ytd)} service YTD`,
    jump: { tab: 'overview' },
  },
])

const statusRows = computed(() => {
  const tone = {
    Operational: '#10b981', 'Under maintenance': '#f59e0b',
    'Out of service': '#ef4444', 'In storage': '#6366f1', Retired: '#94a3b8',
  }
  return (dashboard.value.by_status || []).map(s => ({
    label: s.label, count: s.count, tone: tone[s.label] || '#94a3b8',
  }))
})

const maxCategoryCount = computed(() => {
  let max = 1
  for (const c of dashboard.value.by_category || []) max = Math.max(max, c.count)
  return max
})

const spendValues = computed(() =>
  (dashboard.value.spend_trend || []).map(m => Number(m.value) || 0),
)

const headSub = computed(() => {
  if (!kpis.value.total) {
    return 'Register the devices that keep this clinic running — servicing, calibration and faults in one place.'
  }
  return `${fmt(kpis.value.operational)} of ${fmt(kpis.value.total)} assets operational · ` +
    `${fmt(kpis.value.open_faults)} open fault${kpis.value.open_faults === 1 ? '' : 's'} · ` +
    `${money(kpis.value.book_value)} current book value.`
})

const updatedLabel = computed(() => {
  if (!updatedAt.value) return 'Not synced yet'
  const mins = Math.floor((now.value - updatedAt.value) / 60000)
  if (mins < 1) return 'Synced just now'
  if (mins < 60) return `Synced ${mins}m ago`
  return `Synced ${Math.floor(mins / 60)}h ago`
})

// ── Filtered lists ──────────────────────────────────────────────────────
const categoryOptions = computed(() => categories.value)
const siteOptions = computed(() => sites.value)

const activeAssetFilters = computed(() =>
  [assetSearch.value, assetCategory.value, assetStatus.value, assetCriticality.value, assetSite.value, assetAttention.value]
    .filter(v => v !== null && v !== '' && v !== undefined).length,
)

const ATTENTION_LABELS = {
  service: 'Service overdue',
  calibration: 'Calibration overdue',
  faults: 'Open faults',
}

const filteredAssets = computed(() => {
  const q = assetSearch.value.trim().toLowerCase()
  return assets.value.filter((a) => {
    if (assetCategory.value && a.category !== assetCategory.value) return false
    if (assetStatus.value && a.status !== assetStatus.value) return false
    if (assetCriticality.value && a.criticality !== assetCriticality.value) return false
    if (assetSite.value && a.site !== assetSite.value) return false
    if (assetAttention.value === 'service' && !a.maintenance_overdue) return false
    if (assetAttention.value === 'calibration' && !a.calibration_overdue) return false
    if (assetAttention.value === 'faults' && !a.open_faults) return false
    if (!q) return true
    return [a.name, a.asset_tag, a.serial_number, a.manufacturer, a.model_number, a.location, a.category_name]
      .some(v => String(v || '').toLowerCase().includes(q))
  })
})

const filteredJobs = computed(() => {
  const q = maintSearch.value.trim().toLowerCase()
  return jobs.value.filter((j) => {
    if (maintKind.value && j.kind !== maintKind.value) return false
    if (maintStatus.value && j.status !== maintStatus.value) return false
    if (!q) return true
    return [j.equipment_name, j.equipment_tag, j.vendor_name, j.technician, j.description]
      .some(v => String(v || '').toLowerCase().includes(q))
  })
})

const filteredFaults = computed(() => {
  const q = faultSearch.value.trim().toLowerCase()
  return faults.value.filter((f) => {
    if (faultSeverity.value && f.severity !== faultSeverity.value) return false
    if (faultStatus.value && f.status !== faultStatus.value) return false
    if (!q) return true
    return [f.title, f.description, f.equipment_name, f.equipment_tag]
      .some(v => String(v || '').toLowerCase().includes(q))
  })
})

const filteredTransfers = computed(() => {
  const q = transferSearch.value.trim().toLowerCase()
  if (!q) return transfers.value
  return transfers.value.filter(t =>
    [t.equipment_name, t.equipment_tag, t.reason, t.from_site_name, t.to_site_name]
      .some(v => String(v || '').toLowerCase().includes(q)),
  )
})

// ── Helpers ─────────────────────────────────────────────────────────────
function fmt(n) {
  return (Number(n) || 0).toLocaleString('en-US')
}
function money(n) {
  const v = Number(n) || 0
  if (!v) return 'KES 0'
  if (v >= 1_000_000) return `KES ${(v / 1_000_000).toFixed(v >= 10_000_000 ? 0 : 1)}M`
  if (v >= 1_000) return `KES ${(v / 1_000).toFixed(0)}K`
  return `KES ${v.toFixed(0)}`
}
function moneyFull(n) {
  return `KES ${(Number(n) || 0).toLocaleString('en-US', { maximumFractionDigits: 0 })}`
}
function pct(part, whole) {
  if (!whole) return '0%'
  return `${Math.round((part / whole) * 100)}%`
}
function barWidth(value, max) {
  const v = Number(value) || 0
  if (!v || !max) return '0%'
  return `${Math.max(5, Math.min(100, Math.round((v / max) * 100)))}%`
}
function formatDate(v) {
  if (!v) return '—'
  const d = new Date(v)
  if (Number.isNaN(d.getTime())) return String(v)
  return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
}
function relativeTime(v) {
  if (!v) return '—'
  const then = new Date(v).getTime()
  if (Number.isNaN(then)) return String(v)
  const mins = Math.floor((Date.now() - then) / 60000)
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins}m ago`
  const hours = Math.floor(mins / 60)
  if (hours < 24) return `${hours}h ago`
  const days = Math.floor(hours / 24)
  if (days < 30) return `${days}d ago`
  return formatDate(v)
}
function healthColor(score) {
  const s = Number(score) || 0
  if (s >= 85) return '#10b981'
  if (s >= 65) return '#f59e0b'
  if (s >= 45) return '#f97316'
  return '#ef4444'
}
function uptimeTone() {
  const v = Number(kpis.value.uptime_pct) || 0
  if (v >= 85) return '#10b981'
  if (v >= 65) return '#f59e0b'
  return '#ef4444'
}
function shortCriticality(c) {
  return { life_support: 'Life support', critical: 'Critical', essential: 'Essential', optional: 'Optional' }[c] || c || '—'
}
function dueTone(days) {
  const d = Number(days)
  if (Number.isNaN(d)) return ''
  if (d < 0) return 'is-bad'
  if (d <= 7) return 'is-warn'
  return 'is-good'
}
function dueLabel(days) {
  const d = Number(days)
  if (Number.isNaN(d)) return '—'
  if (d < 0) return `${Math.abs(d)}d late`
  if (d === 0) return 'today'
  return `in ${d}d`
}
function serviceTone(a) {
  if (!a) return ''
  if (a.maintenance_overdue) return 'is-bad'
  if (a.days_to_maintenance !== null && a.days_to_maintenance !== undefined && a.days_to_maintenance <= 14) return 'is-warn'
  return 'is-good'
}
function serviceLabel(a) {
  if (!a) return '—'
  if (a.maintenance_overdue) return `Service ${Math.abs(a.days_to_maintenance)}d late`
  if (a.days_to_maintenance === null || a.days_to_maintenance === undefined) return 'No service date'
  if (a.days_to_maintenance === 0) return 'Service today'
  return `Service in ${a.days_to_maintenance}d`
}
function maintTone(j) {
  if (!j) return ''
  if (j.is_overdue && j.status !== 'completed' && j.status !== 'cancelled') return 'is-bad'
  return {
    scheduled: 'is-info', in_progress: 'is-warn',
    completed: 'is-good', cancelled: 'is-muted',
  }[j.status] || ''
}
function categoryIcon(name) {
  const map = {
    'Diagnostic imaging': 'mdi-radiology-box-outline',
    'Patient monitoring': 'mdi-heart-pulse',
    Laboratory: 'mdi-flask-outline',
    'Surgical & theatre': 'mdi-medical-bag',
    'Life support': 'mdi-ambulance',
    'Examination room': 'mdi-stethoscope',
    Dental: 'mdi-tooth-outline',
    Sterilisation: 'mdi-autoclock',
    Physiotherapy: 'mdi-human-handsup',
    'IT & telemedicine': 'mdi-laptop',
  }
  return map[name] || 'mdi-medical-bag'
}

function setAssetView(v) {
  assetView.value = v
  try { localStorage.setItem('adheremed.clinic.equipment.view', v) } catch {}
}

function clearAssetFilters() {
  assetSearch.value = ''
  assetCategory.value = null
  assetStatus.value = null
  assetCriticality.value = null
  assetSite.value = null
  assetAttention.value = null
}

function applyKpi(kpi) {
  if (!kpi?.jump) return
  tab.value = kpi.jump.tab
  if (kpi.jump.tab === 'assets') {
    clearAssetFilters()
    if (kpi.jump.attention) assetAttention.value = kpi.jump.attention
  }
  if (kpi.jump.tab === 'faults' && kpi.jump.status) faultStatus.value = kpi.jump.status
}

// ── Data loading ────────────────────────────────────────────────────────
function rowsOf(payload) {
  if (Array.isArray(payload)) return payload
  return payload?.results || []
}

async function loadDashboard() {
  try {
    const { data } = await $api.get(`${API}/dashboard/`)
    dashboard.value = {
      attention: data?.attention || [],
      upcoming_maintenance: data?.upcoming_maintenance || [],
      open_faults: data?.open_faults || [],
      by_category: data?.by_category || [],
      by_status: data?.by_status || [],
      by_site: data?.by_site || [],
      spend_trend: data?.spend_trend || [],
    }
    kpis.value = { ...kpis.value, ...(data?.kpis || {}) }
  } catch {
    /* dashboard is additive — a failure must not blank the page */
  }
}

async function loadAssets() {
  try {
    const { data } = await $api.get(`${API}/items/`, { params: { page_size: 1000, ordering: 'name' } })
    assets.value = rowsOf(data)
  } catch (e) {
    notify(apiMessage(e, 'Could not load equipment.'), 'error')
    assets.value = []
  }
}

async function loadJobs() {
  try {
    const { data } = await $api.get(`${API}/maintenance/`, { params: { page_size: 1000 } })
    jobs.value = rowsOf(data)
  } catch { jobs.value = [] }
}

async function loadFaults() {
  try {
    const { data } = await $api.get(`${API}/faults/`, { params: { page_size: 1000 } })
    faults.value = rowsOf(data)
  } catch { faults.value = [] }
}

async function loadTransfers() {
  try {
    const { data } = await $api.get(`${API}/transfers/`, { params: { page_size: 500 } })
    transfers.value = rowsOf(data)
  } catch { transfers.value = [] }
}

async function loadLookups() {
  const [cat, site, dept] = await Promise.all([
    $api.get(`${API}/categories/`, { params: { page_size: 200 } }).catch(() => null),
    $api.get('/clinic-sites/', { params: { page_size: 200, ordering: 'name' } }).catch(() => null),
    $api.get('/departments/', { params: { page_size: 200 } }).catch(() => null),
  ])
  categories.value = cat ? rowsOf(cat.data) : []
  sites.value = site ? rowsOf(site.data) : []
  departments.value = dept ? rowsOf(dept.data) : []
}

async function loadAll() {
  loading.value = true
  try {
    await Promise.all([
      loadDashboard(), loadAssets(), loadJobs(), loadFaults(), loadTransfers(),
      loadLookups(),
    ])
    updatedAt.value = Date.now()
    now.value = Date.now()
  } finally {
    loading.value = false
  }
}

// ── Asset detail ────────────────────────────────────────────────────────
const detailOpen = ref(false)
const detail = ref(null)

async function openDetail(row) {
  if (!row?.id) return
  try {
    const { data } = await $api.get(`${API}/items/${row.id}/`)
    detail.value = data
  } catch {
    detail.value = row
  }
  detailOpen.value = true
}

async function openDetailById(id) {
  const row = assets.value.find(a => a.id === id)
  await openDetail(row || { id })
}

// ── Asset create / edit ─────────────────────────────────────────────────
const assetOpen = ref(false)
const editingAsset = ref(null)
const assetFormRef = ref(null)
const assetError = ref('')

function blankAsset() {
  return {
    name: '', asset_tag: '', serial_number: '', category: null,
    manufacturer: '', model_number: '', description: '',
    site: null, department: null, location: '', custodian: null,
    status: 'operational', condition: 'good', criticality: 'essential',
    is_active: true, ownership: 'owned',
    purchase_date: '', purchase_price: 0, supplier_name: '',
    invoice_number: '', warranty_expiry: '', lease_end: '',
    commissioned_on: '', expected_life_years: 0,
    maintenance_interval_days: 0, last_maintenance: '', next_maintenance: '',
    calibration_required: false, calibration_interval_days: 0,
    last_calibration: '', next_calibration: '',
  }
}
const assetForm = reactive(blankAsset())

function openAsset(row) {
  editingAsset.value = row?.id || null
  assetError.value = ''
  Object.assign(assetForm, blankAsset())
  if (row) {
    for (const key of Object.keys(assetForm)) {
      if (row[key] !== undefined && row[key] !== null) assetForm[key] = row[key]
    }
    // Blank the date inputs when the API returned null.
    for (const key of ['purchase_date', 'warranty_expiry', 'lease_end', 'commissioned_on',
      'last_maintenance', 'next_maintenance', 'last_calibration', 'next_calibration']) {
      assetForm[key] = row[key] || ''
    }
    assetForm.purchase_price = Number(row.purchase_price) || 0
    assetForm.expected_life_years = Number(row.expected_life_years) || 0
  } else {
    // Sensible first-run defaults.
    assetForm.site = sites.value.find(s => s.is_hq)?.id || sites.value[0]?.id || null
    const today = new Date().toISOString().slice(0, 10)
    assetForm.purchase_date = today
    assetForm.commissioned_on = today
  }
  assetOpen.value = true
}

function closeAsset() {
  if (saving.value) return
  assetOpen.value = false
  editingAsset.value = null
}

function assetPayload() {
  const body = { ...assetForm }
  // Empty strings on date fields become null so DRF accepts them.
  for (const key of ['purchase_date', 'warranty_expiry', 'lease_end', 'commissioned_on',
    'last_maintenance', 'next_maintenance', 'last_calibration', 'next_calibration']) {
    if (!body[key]) body[key] = null
  }
  if (!body.asset_tag) delete body.asset_tag
  if (!body.category) body.category = null
  if (!body.site) body.site = null
  if (!body.department) body.department = null
  if (!body.custodian) body.custodian = null
  body.purchase_price = Number(body.purchase_price) || 0
  body.expected_life_years = Number(body.expected_life_years) || 0
  body.maintenance_interval_days = Number(body.maintenance_interval_days) || 0
  body.calibration_interval_days = Number(body.calibration_interval_days) || 0
  return body
}

async function saveAsset() {
  const valid = await assetFormRef.value?.validate()
  if (valid?.valid === false) return
  saving.value = true
  assetError.value = ''
  try {
    if (editingAsset.value) {
      await $api.patch(`${API}/items/${editingAsset.value}/`, assetPayload())
      notify('Asset updated.')
    } else {
      await $api.post(`${API}/items/`, assetPayload())
      notify('Asset registered.')
    }
    assetOpen.value = false
    editingAsset.value = null
    await loadAll()
  } catch (e) {
    assetError.value = apiMessage(e, 'Could not save this asset.')
    notify(assetError.value, 'error')
  } finally {
    saving.value = false
  }
}

// ── Delete ──────────────────────────────────────────────────────────────
const deleteOpen = ref(false)
const deleteTarget = ref(null)

function askDelete(row) {
  deleteTarget.value = row
  deleteOpen.value = true
}

async function confirmDelete() {
  if (!deleteTarget.value) return
  saving.value = true
  try {
    await $api.delete(`${API}/items/${deleteTarget.value.id}/`)
    notify(`${deleteTarget.value.name} removed.`)
    deleteOpen.value = false
    deleteTarget.value = null
    await loadAll()
  } catch (e) {
    notify(apiMessage(e, 'Could not remove this asset.'), 'error')
  } finally {
    saving.value = false
  }
}

// ── Maintenance ─────────────────────────────────────────────────────────
const maintOpen = ref(false)
const maintError = ref('')
const blankMaint = () => ({
  equipment: null, kind: 'preventive', scheduled_date: new Date().toISOString().slice(0, 10),
  performed_by: 'internal', vendor_name: '', technician: '', cost: 0, description: '',
})
const maintForm = reactive(blankMaint())

function openMaintenance(row) {
  Object.assign(maintForm, blankMaint())
  maintForm.equipment = row?.id || null
  maintError.value = ''
  maintOpen.value = true
}

async function saveMaintenance() {
  if (!maintForm.equipment) {
    maintError.value = 'Choose an asset.'
    return
  }
  saving.value = true
  maintError.value = ''
  try {
    await $api.post(`${API}/maintenance/`, {
      ...maintForm,
      cost: Number(maintForm.cost) || 0,
    })
    notify('Maintenance scheduled.')
    maintOpen.value = false
    await loadAll()
  } catch (e) {
    maintError.value = apiMessage(e, 'Could not schedule this job.')
    notify(maintError.value, 'error')
  } finally {
    saving.value = false
  }
}

async function startJob(job) {
  try {
    await $api.post(`${API}/maintenance/${job.id}/start/`)
    notify(`Job started — ${job.equipment_name} parked for service.`)
    await loadAll()
  } catch (e) {
    notify(apiMessage(e, 'Could not start this job.'), 'error')
  }
}

async function cancelJob(job) {
  try {
    await $api.post(`${API}/maintenance/${job.id}/cancel/`)
    notify('Job cancelled.')
    await loadAll()
  } catch (e) {
    notify(apiMessage(e, 'Could not cancel this job.'), 'error')
  }
}

const completeOpen = ref(false)
const completeTarget = ref(null)
const completeForm = reactive({
  completed_date: new Date().toISOString().slice(0, 10),
  cost: 0, downtime_hours: 0, findings: '', next_due_date: '',
})

function openComplete(job) {
  completeTarget.value = job
  Object.assign(completeForm, {
    completed_date: new Date().toISOString().slice(0, 10),
    cost: Number(job.cost) || 0,
    downtime_hours: Number(job.downtime_hours) || 0,
    findings: '',
    next_due_date: '',
  })
  completeOpen.value = true
}

async function completeJob() {
  if (!completeTarget.value) return
  saving.value = true
  try {
    await $api.post(`${API}/maintenance/${completeTarget.value.id}/complete/`, {
      completed_date: completeForm.completed_date,
      cost: Number(completeForm.cost) || 0,
      downtime_hours: Number(completeForm.downtime_hours) || 0,
      findings: completeForm.findings,
      next_due_date: completeForm.next_due_date || null,
    })
    notify('Job completed — next service date rolled forward.')
    completeOpen.value = false
    completeTarget.value = null
    await loadAll()
  } catch (e) {
    notify(apiMessage(e, 'Could not complete this job.'), 'error')
  } finally {
    saving.value = false
  }
}

// ── Faults ──────────────────────────────────────────────────────────────
const faultOpen = ref(false)
const faultError = ref('')
const blankFault = () => ({
  equipment: null, title: '', description: '', severity: 'medium', downtime_hours: 0,
})
const faultForm = reactive(blankFault())

function openFaultReport(row) {
  Object.assign(faultForm, blankFault())
  faultForm.equipment = row?.id || null
  faultError.value = ''
  faultOpen.value = true
}

async function saveFault() {
  if (!faultForm.equipment) {
    faultError.value = 'Choose an asset.'
    return
  }
  if (!faultForm.title.trim()) {
    faultError.value = 'Add a short fault summary.'
    return
  }
  saving.value = true
  faultError.value = ''
  try {
    await $api.post(`${API}/faults/`, {
      ...faultForm,
      downtime_hours: Number(faultForm.downtime_hours) || 0,
    })
    notify('Fault reported — asset flagged for the biomedical team.')
    faultOpen.value = false
    await loadAll()
  } catch (e) {
    faultError.value = apiMessage(e, 'Could not report this fault.')
    notify(faultError.value, 'error')
  } finally {
    saving.value = false
  }
}

const resolveOpen = ref(false)
const resolveTarget = ref(null)
const resolveForm = reactive({ resolution: '', downtime_hours: 0 })

function openResolve(fault) {
  resolveTarget.value = fault
  Object.assign(resolveForm, {
    resolution: '',
    downtime_hours: Number(fault.downtime_hours) || 0,
  })
  resolveOpen.value = true
}

async function resolveFault() {
  if (!resolveTarget.value) return
  saving.value = true
  try {
    await $api.post(`${API}/faults/${resolveTarget.value.id}/resolve/`, {
      resolution: resolveForm.resolution,
      downtime_hours: Number(resolveForm.downtime_hours) || 0,
    })
    notify('Fault resolved.')
    resolveOpen.value = false
    resolveTarget.value = null
    await loadAll()
  } catch (e) {
    notify(apiMessage(e, 'Could not resolve this fault.'), 'error')
  } finally {
    saving.value = false
  }
}

async function dismissFault(fault) {
  try {
    await $api.post(`${API}/faults/${fault.id}/dismiss/`, { resolution: 'No fault found.' })
    notify('Fault dismissed.')
    await loadAll()
  } catch (e) {
    notify(apiMessage(e, 'Could not dismiss this fault.'), 'error')
  }
}

// ── Transfers ───────────────────────────────────────────────────────────
const transferOpen = ref(false)
const transferError = ref('')
const blankTransfer = () => ({
  equipment: null, to_site: null, to_department: null, reason: '', notes: '',
})
const transferForm = reactive(blankTransfer())

function openTransfer(row) {
  Object.assign(transferForm, blankTransfer())
  transferForm.equipment = row?.id || null
  transferError.value = ''
  transferOpen.value = true
}

async function saveTransfer() {
  if (!transferForm.equipment) {
    transferError.value = 'Choose an asset.'
    return
  }
  saving.value = true
  transferError.value = ''
  try {
    const asset = assets.value.find(a => a.id === transferForm.equipment)
    await $api.post(`${API}/transfers/`, {
      ...transferForm,
      from_site: asset?.site || null,
      from_department: asset?.department || null,
    })
    notify('Asset transferred.')
    transferOpen.value = false
    await loadAll()
  } catch (e) {
    transferError.value = apiMessage(e, 'Could not transfer this asset.')
    notify(transferError.value, 'error')
  } finally {
    saving.value = false
  }
}

// ── Export ──────────────────────────────────────────────────────────────
function exportCsv() {
  if (!import.meta.client) return
  const rows = [[
    'Asset tag', 'Name', 'Category', 'Manufacturer', 'Model', 'Serial',
    'Branch', 'Department', 'Location', 'Status', 'Condition', 'Criticality',
    'Health', 'Next service', 'Next calibration', 'Warranty expiry',
    'Purchase date', 'Purchase price', 'Ownership',
  ]]
  filteredAssets.value.forEach((a) => {
    rows.push([
      a.asset_tag, a.name, a.category_name || '', a.manufacturer || '', a.model_number || '',
      a.serial_number || '', a.site_name || '', a.department_name || '', a.location || '',
      a.status_label, a.condition_label, a.criticality_label, a.health_score,
      a.next_maintenance || '', a.next_calibration || '', a.warranty_expiry || '',
      a.purchase_date || '', a.purchase_price || 0, a.ownership_label,
    ])
  })
  const csv = rows
    .map(r => r.map(c => `"${String(c ?? '').replace(/"/g, '""')}"`).join(','))
    .join('\r\n')
  const blob = new Blob([`\ufeff${csv}`], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = `clinic-equipment-${new Date().toISOString().slice(0, 10)}.csv`
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
  URL.revokeObjectURL(url)
  notify('Equipment register exported.')
}

// ── Shared helpers ──────────────────────────────────────────────────────
const snack = reactive({ show: false, color: 'success', text: '' })
function notify(text, color = 'success') {
  Object.assign(snack, { show: true, color, text })
}

function apiMessage(e, fallback) {
  const data = e?.response?.data
  if (typeof data === 'string' && data) return data
  if (data?.detail) return data.detail
  if (data && typeof data === 'object') {
    const first = Object.entries(data)[0]
    if (first) {
      const [field, value] = first
      return `${field.replace(/_/g, ' ')}: ${Array.isArray(value) ? value.join(', ') : value}`
    }
  }
  return e?.message || fallback
}

// ── Lifecycle ───────────────────────────────────────────────────────────
onMounted(async () => {
  try {
    const saved = localStorage.getItem('adheremed.clinic.equipment.view')
    if (saved === 'grid' || saved === 'table') assetView.value = saved
  } catch {}
  await loadAll()
})
</script>

<style scoped>
.flex-1 { flex: 1; }

/* ══ Tokens ══ */
.eq-page {
  width: 100%;
  --eq-line: rgba(var(--v-theme-on-surface), 0.09);
  --eq-line-soft: rgba(var(--v-theme-on-surface), 0.06);
  --eq-muted: rgba(var(--v-theme-on-surface), 0.6);
  --eq-faint: rgba(var(--v-theme-on-surface), 0.44);
  --eq-surface: rgb(var(--v-theme-surface));
  --eq-raise: rgba(var(--v-theme-on-surface), 0.035);
}

/* ══ Header ══ */
.eq-head {
  position: relative;
  border-radius: 18px;
  padding: 17px 20px 12px;
  margin-bottom: 14px;
  background: var(--eq-surface);
  border: 1px solid var(--eq-line);
  box-shadow: 0 10px 30px rgba(15, 23, 42, 0.055);
  overflow: hidden;
}
.eq-head::before {
  content: '';
  position: absolute;
  inset: 0 auto 0 0;
  width: 4px;
  background: linear-gradient(180deg, var(--eq-accent), var(--eq-accent-soft));
}
.eq-head-top { display: flex; align-items: center; gap: 14px; flex-wrap: wrap; min-width: 0; }
.eq-head-icon {
  width: 50px; height: 50px; border-radius: 15px;
  display: grid; place-items: center; flex-shrink: 0;
  color: var(--eq-accent-ink);
  background: color-mix(in srgb, var(--eq-accent) 12%, transparent);
  border: 1px solid color-mix(in srgb, var(--eq-accent) 22%, transparent);
}
.eq-head-id { flex: 1; min-width: 220px; }
.eq-head-eyebrow {
  display: inline-flex; align-items: center; gap: 6px;
  font-size: 9.5px; font-weight: 800; letter-spacing: 1.4px;
  text-transform: uppercase; color: var(--eq-faint);
}
.eq-head-title { margin: 3px 0 2px; font-size: 24px; line-height: 1.15; font-weight: 800; letter-spacing: -0.4px; }
.eq-head-sub { margin: 0; font-size: 12.5px; line-height: 1.45; color: var(--eq-muted); max-width: 90ch; }
.eq-head-actions { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; justify-content: flex-end; }
.eq-head-foot {
  display: flex; align-items: center; gap: 7px; flex-wrap: wrap;
  margin-top: 13px; padding-top: 11px;
  border-top: 1px solid var(--eq-line-soft);
}
.eq-head-stamp { margin-left: auto; font-size: 10.5px; font-weight: 700; color: var(--eq-faint); white-space: nowrap; }
.eq-live-dot { width: 7px; height: 7px; border-radius: 50%; background: #22c55e; animation: eqPulse 2s infinite; }
@keyframes eqPulse {
  0% { box-shadow: 0 0 0 0 rgba(34, 197, 94, 0.5); }
  70% { box-shadow: 0 0 0 6px rgba(34, 197, 94, 0); }
  100% { box-shadow: 0 0 0 0 rgba(34, 197, 94, 0); }
}

.eq-chip {
  display: inline-flex; align-items: center; gap: 5px;
  height: 25px; padding: 0 9px; border-radius: 999px;
  border: 1px solid var(--eq-line); background: var(--eq-raise);
  font-size: 10.5px; font-weight: 700; color: var(--eq-muted);
  white-space: nowrap; max-width: 280px; overflow: hidden; text-overflow: ellipsis;
}
.eq-chip.is-good { color: #047857; border-color: rgba(16, 185, 129, 0.28); background: rgba(16, 185, 129, 0.08); }
.eq-chip.is-warn { color: #b45309; border-color: rgba(245, 158, 11, 0.3); background: rgba(245, 158, 11, 0.09); }
.eq-chip.is-bad { color: #b91c1c; border-color: rgba(239, 68, 68, 0.26); background: rgba(239, 68, 68, 0.08); }

.eq-btn {
  display: inline-flex; align-items: center; gap: 6px;
  height: 36px; padding: 0 13px; border-radius: 10px;
  border: 1px solid var(--eq-line); background: transparent;
  color: rgb(var(--v-theme-on-surface));
  font-family: inherit; font-size: 12.5px; font-weight: 700;
  cursor: pointer; white-space: nowrap;
  transition: background 0.15s ease, transform 0.15s ease, opacity 0.15s ease;
}
.eq-btn:hover:not(:disabled) { background: rgba(var(--v-theme-on-surface), 0.045); transform: translateY(-1px); }
.eq-btn:disabled { opacity: 0.5; cursor: not-allowed; }
.eq-btn.is-primary {
  background: var(--eq-accent); color: var(--eq-on-accent);
  border-color: transparent; box-shadow: 0 7px 18px var(--eq-accent-ring);
}
/* Keep the solid fill on hover — the generic hover rule would otherwise win
   on specificity and leave a white label on a transparent background. */
.eq-btn.is-primary:hover:not(:disabled) {
  background: var(--eq-accent);
  color: var(--eq-on-accent);
  border-color: transparent;
  filter: brightness(1.06);
}
.eq-btn.is-primary:active:not(:disabled) { filter: brightness(0.96); }
.eq-btn.is-sm { height: 28px; padding: 0 10px; font-size: 11.5px; border-radius: 8px; }
.eq-spin { animation: eqSpin 0.9s linear infinite; }
@keyframes eqSpin { to { transform: rotate(360deg); } }

/* ══ KPIs ══ */
.eq-kpis {
  display: grid; grid-template-columns: repeat(6, minmax(0, 1fr));
  gap: 10px; margin-bottom: 14px;
}
.eq-kpi {
  position: relative; padding: 12px 13px 11px;
  border-radius: 15px; background: var(--eq-surface);
  border: 1px solid var(--eq-line); cursor: pointer; overflow: hidden;
  transition: transform 0.16s ease, box-shadow 0.16s ease, border-color 0.16s ease;
}
.eq-kpi::before {
  content: ''; position: absolute; inset: 0 auto 0 0;
  width: 3px; background: var(--tone); opacity: 0.72;
}
.eq-kpi:hover {
  transform: translateY(-2px);
  border-color: color-mix(in srgb, var(--tone) 36%, transparent);
  box-shadow: 0 10px 24px color-mix(in srgb, var(--tone) 13%, transparent);
}
.eq-kpi-top { display: flex; align-items: center; gap: 7px; margin-bottom: 6px; }
.eq-kpi-icon {
  width: 26px; height: 26px; border-radius: 9px;
  display: grid; place-items: center; flex-shrink: 0;
  color: var(--tone); background: color-mix(in srgb, var(--tone) 12%, transparent);
}
.eq-kpi-label {
  font-size: 9px; font-weight: 800; letter-spacing: 0.7px;
  text-transform: uppercase; color: var(--eq-faint);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.eq-kpi-value {
  font-size: 21px; font-weight: 800; line-height: 1.1; letter-spacing: -0.4px;
  color: var(--tone); font-variant-numeric: tabular-nums;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.eq-kpi-sub {
  margin-top: 2px; font-size: 10px; font-weight: 600; color: var(--eq-muted);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}

/* ══ Tabs ══ */
.eq-tabs {
  display: flex; align-items: center; gap: 4px; flex-wrap: wrap;
  padding: 5px; margin-bottom: 14px;
  border-radius: 13px; border: 1px solid var(--eq-line); background: var(--eq-surface);
}
.eq-tab {
  display: inline-flex; align-items: center; gap: 6px;
  height: 32px; padding: 0 13px; border-radius: 9px;
  border: 1px solid transparent; background: transparent;
  color: var(--eq-muted); font-family: inherit;
  font-size: 12px; font-weight: 700; cursor: pointer;
  transition: background 0.15s ease, color 0.15s ease;
}
.eq-tab:hover { background: rgba(var(--v-theme-on-surface), 0.045); color: rgb(var(--v-theme-on-surface)); }
.eq-tab.is-on {
  background: color-mix(in srgb, var(--eq-accent) 10%, transparent);
  border-color: color-mix(in srgb, var(--eq-accent) 26%, transparent);
  color: var(--eq-accent);
}
.eq-tab-count {
  display: inline-flex; align-items: center; justify-content: center;
  min-width: 18px; height: 17px; padding: 0 5px; border-radius: 999px;
  font-size: 9.5px; font-weight: 800;
  background: rgba(var(--v-theme-on-surface), 0.07); color: var(--eq-muted);
}
.eq-tab-count.is-warn { background: rgba(245, 158, 11, 0.18); color: #b45309; }
.eq-tab-count.is-bad { background: rgba(239, 68, 68, 0.14); color: #b91c1c; }

/* ══ Overview layout ══ */
.eq-ov { display: grid; grid-template-columns: minmax(0, 1fr) 320px; gap: 14px; align-items: start; }
@media (max-width: 1279px) { .eq-ov { grid-template-columns: minmax(0, 1fr); } }
.eq-ov-main { display: flex; flex-direction: column; gap: 14px; min-width: 0; }
.eq-ov-rail { display: flex; flex-direction: column; gap: 12px; }

/* ══ Panels ══ */
.eq-panel {
  border-radius: 15px; border: 1px solid var(--eq-line);
  background: var(--eq-surface); overflow: hidden;
}
.eq-panel-head {
  display: flex; align-items: center; gap: 9px; flex-wrap: wrap;
  padding: 11px 13px; border-bottom: 1px solid var(--eq-line-soft);
  background: linear-gradient(180deg, rgba(var(--v-theme-on-surface), 0.02), transparent);
}
.eq-panel-icon {
  width: 26px; height: 26px; border-radius: 8px;
  display: grid; place-items: center; flex-shrink: 0;
  color: var(--eq-accent);
  background: color-mix(in srgb, var(--eq-accent) 11%, transparent);
}
.eq-panel-icon.is-warn { color: #b45309; background: rgba(245, 158, 11, 0.14); }
.eq-panel-titles { flex: 1; min-width: 150px; }
.eq-panel-titles h2 { margin: 0; font-size: 13px; font-weight: 800; letter-spacing: -0.1px; }
.eq-panel-titles p { margin: 1px 0 0; font-size: 10.5px; color: var(--eq-faint); line-height: 1.35; }
.eq-panel-title {
  flex: 1;
  font-size: 10px; font-weight: 800; letter-spacing: 0.9px;
  text-transform: uppercase; color: var(--eq-faint);
}
.eq-panel-count {
  display: inline-flex; align-items: center; justify-content: center;
  min-width: 22px; height: 19px; padding: 0 7px; border-radius: 999px;
  font-size: 10px; font-weight: 800;
  background: rgba(var(--v-theme-on-surface), 0.07); color: var(--eq-muted);
}
.eq-panel-count.is-bad { background: rgba(239, 68, 68, 0.14); color: #b91c1c; }
.eq-panel-body { padding: 12px 13px; }
.eq-panel-empty {
  display: flex; align-items: center; gap: 8px;
  padding: 18px 13px;
  font-size: 11.5px; line-height: 1.45; color: var(--eq-muted);
}
.eq-link {
  border: 0; background: none; padding: 0; cursor: pointer;
  font-family: inherit; font-size: 11px; font-weight: 800;
  color: var(--eq-accent);
  text-decoration: underline; text-underline-offset: 2px;
  white-space: nowrap;
}

/* ══ Attention list ══ */
.eq-attn { display: flex; flex-direction: column; }
.eq-attn-row {
  display: flex; align-items: center; gap: 10px;
  padding: 9px 13px; width: 100%;
  border: 0; border-bottom: 1px solid var(--eq-line-soft);
  background: transparent; cursor: pointer;
  font-family: inherit; text-align: left;
  transition: background 0.14s ease;
}
.eq-attn-row:last-child { border-bottom: 0; }
.eq-attn-row:hover { background: rgba(var(--v-theme-on-surface), 0.03); }
.eq-attn-score {
  --score-tone: #10b981;
  width: 34px; height: 34px; flex-shrink: 0;
  display: grid; place-items: center;
  border-radius: 10px;
  font-size: 12px; font-weight: 800;
  color: var(--score-tone);
  background: color-mix(in srgb, var(--score-tone) 13%, transparent);
  border: 1px solid color-mix(in srgb, var(--score-tone) 26%, transparent);
  font-variant-numeric: tabular-nums;
}
.eq-attn-id { display: flex; flex-direction: column; gap: 1px; min-width: 0; flex: 1; }
.eq-attn-name {
  font-size: 12px; font-weight: 700;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.eq-attn-meta { font-size: 10px; color: var(--eq-faint); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.eq-attn-reasons { display: flex; align-items: center; gap: 4px; flex-wrap: wrap; justify-content: flex-end; max-width: 52%; }
.eq-attn-chev { color: var(--eq-faint); flex-shrink: 0; }
.eq-reason {
  display: inline-flex; align-items: center;
  height: 19px; padding: 0 7px; border-radius: 999px;
  font-size: 9px; font-weight: 800; letter-spacing: 0.2px;
  white-space: nowrap;
  color: var(--eq-muted); background: rgba(var(--v-theme-on-surface), 0.06);
}
.eq-reason.is-maintenance, .eq-reason.is-warranty { color: #b45309; background: rgba(245, 158, 11, 0.15); }
.eq-reason.is-calibration { color: #6d28d9; background: rgba(139, 92, 246, 0.13); }
.eq-reason.is-status, .eq-reason.is-condition { color: #b91c1c; background: rgba(239, 68, 68, 0.11); }

/* ══ Tables ══ */
.eq-tablewrap { overflow-x: auto; }
.eq-tablecard {
  border-radius: 15px; border: 1px solid var(--eq-line);
  background: var(--eq-surface); overflow: hidden;
}
.eq-table { width: 100%; border-collapse: collapse; }
.eq-table thead th {
  padding: 9px 12px; text-align: left;
  font-size: 9px; font-weight: 800; letter-spacing: 0.7px; text-transform: uppercase;
  color: var(--eq-faint); border-bottom: 1px solid var(--eq-line); white-space: nowrap;
  background: rgba(var(--v-theme-on-surface), 0.015);
}
.eq-table tbody tr {
  border-bottom: 1px solid var(--eq-line-soft);
  transition: background 0.13s ease;
  cursor: pointer;
}
.eq-table tbody tr:last-child { border-bottom: 0; }
.eq-table tbody tr:hover { background: rgba(var(--v-theme-on-surface), 0.028); }
.eq-table td { padding: 8px 12px; vertical-align: middle; }
.eq-table--assets td { height: auto !important; }
.eq-th-name { width: 26%; }
.eq-th-num { text-align: right; }
.eq-td-num { text-align: right; white-space: nowrap; }
.eq-th-act { width: 104px; }

.eq-cell-two { display: flex; flex-direction: column; gap: 0; min-width: 0; }
.eq-cell-title {
  font-size: 12px; font-weight: 700;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.eq-cell-sub {
  font-size: 9.5px; font-weight: 600; color: var(--eq-faint);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.eq-cell-sub.is-bad { color: #b91c1c; }
.eq-cell-body { font-size: 11px; color: var(--eq-muted); }
.eq-mono { font-size: 11px; font-weight: 700; font-variant-numeric: tabular-nums; }

/* ══ Tags / pills ══ */
.eq-tag {
  display: inline-flex; align-items: center;
  height: 19px; padding: 0 7px; border-radius: 6px;
  font-size: 9.5px; font-weight: 800; letter-spacing: 0.2px;
  white-space: nowrap;
  color: var(--eq-muted); background: rgba(var(--v-theme-on-surface), 0.06);
  border: 1px solid transparent;
}
.eq-tag.is-life_support { color: #b91c1c; background: rgba(239, 68, 68, 0.12); border-color: rgba(239, 68, 68, 0.24); }
.eq-tag.is-critical { color: #c2410c; background: rgba(249, 115, 22, 0.12); border-color: rgba(249, 115, 22, 0.24); }
.eq-tag.is-essential { color: #0369a1; background: rgba(14, 165, 233, 0.11); border-color: rgba(14, 165, 233, 0.22); }
.eq-tag.is-optional { color: var(--eq-faint); }
.eq-tag.is-status-operational { color: #047857; background: rgba(16, 185, 129, 0.12); border-color: rgba(16, 185, 129, 0.24); }
.eq-tag.is-status-under_maintenance { color: #b45309; background: rgba(245, 158, 11, 0.15); border-color: rgba(245, 158, 11, 0.28); }
.eq-tag.is-status-out_of_service { color: #b91c1c; background: rgba(239, 68, 68, 0.12); border-color: rgba(239, 68, 68, 0.24); }
.eq-tag.is-status-in_storage { color: #4338ca; background: rgba(99, 102, 241, 0.12); border-color: rgba(99, 102, 241, 0.24); }
.eq-tag.is-status-retired { color: var(--eq-faint); }

.eq-pill {
  display: inline-flex; align-items: center;
  height: 19px; padding: 0 7px; border-radius: 999px;
  font-size: 9px; font-weight: 800; letter-spacing: 0.3px;
  white-space: nowrap;
  color: var(--eq-muted); background: rgba(var(--v-theme-on-surface), 0.06);
}
.eq-pill.is-good { color: #047857; background: rgba(16, 185, 129, 0.13); }
.eq-pill.is-warn { color: #b45309; background: rgba(245, 158, 11, 0.16); }
.eq-pill.is-bad, .eq-pill.is-critical, .eq-pill.is-high { color: #b91c1c; background: rgba(239, 68, 68, 0.12); }
.eq-pill.is-info { color: #0369a1; background: rgba(14, 165, 233, 0.12); }
.eq-pill.is-muted { color: var(--eq-faint); }
.eq-pill.is-medium { color: #b45309; background: rgba(245, 158, 11, 0.16); }
.eq-pill.is-low { color: var(--eq-muted); background: rgba(var(--v-theme-on-surface), 0.07); }

/* ══ Bars ══ */
.eq-bar-track {
  display: block; height: 5px; border-radius: 999px;
  background: rgba(var(--v-theme-on-surface), 0.07); overflow: hidden;
}
.eq-bar-track.is-mini { width: 48px; height: 4px; }
.eq-bar-fill {
  display: block; height: 100%; border-radius: 999px;
  background: var(--eq-accent); transition: width 0.3s ease;
}
.eq-bar-fill.is-good { background: #10b981; }

.eq-bars { display: flex; flex-direction: column; gap: 8px; padding: 12px 13px; }
.eq-bar-row { display: grid; grid-template-columns: minmax(0, 1fr) 68px 26px; align-items: center; gap: 8px; }
.eq-bar-label {
  font-size: 11px; font-weight: 650; color: var(--eq-muted);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.eq-bar-val { font-size: 11px; font-weight: 800; text-align: right; font-variant-numeric: tabular-nums; }

/* ══ Health ring ══ */
.eq-health { display: flex; align-items: center; gap: 14px; padding: 12px 13px; }
.eq-health-ring {
  --pct: 0;
  --ring: #10b981;
  width: 84px; height: 84px; flex-shrink: 0;
  border-radius: 50%;
  display: grid; place-items: center; align-content: center; gap: 0;
  background:
    radial-gradient(closest-side, var(--eq-surface) 76%, transparent 77% 100%),
    conic-gradient(var(--ring) calc(var(--pct) * 1%), rgba(var(--v-theme-on-surface), 0.08) 0);
}
.eq-health-val { font-size: 19px; font-weight: 800; letter-spacing: -0.6px; line-height: 1; font-variant-numeric: tabular-nums; }
.eq-health-val i { font-size: 10px; font-style: normal; color: var(--eq-faint); }
.eq-health-cap {
  font-size: 8px; font-weight: 800; letter-spacing: 0.7px;
  text-transform: uppercase; color: var(--eq-faint); margin-top: 2px;
}
.eq-health-legend { flex: 1; display: flex; flex-direction: column; gap: 4px; min-width: 0; }
.eq-legend-row { display: flex; align-items: center; gap: 6px; font-size: 10.5px; color: var(--eq-muted); }
.eq-legend-row i { width: 7px; height: 7px; border-radius: 50%; flex-shrink: 0; }
.eq-legend-row span { flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.eq-legend-row b { font-variant-numeric: tabular-nums; color: rgb(var(--v-theme-on-surface)); }

/* ══ Sites ══ */
.eq-sites { display: flex; flex-direction: column; gap: 9px; padding: 12px 13px; }
.eq-site-top { display: flex; align-items: baseline; justify-content: space-between; gap: 8px; margin-bottom: 4px; }
.eq-site-name { font-size: 11.5px; font-weight: 700; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.eq-site-count { font-size: 11px; font-weight: 800; font-variant-numeric: tabular-nums; }
.eq-site-foot {
  display: flex; align-items: center; justify-content: space-between;
  margin-top: 3px; font-size: 9.5px; color: var(--eq-faint);
}
.eq-site-risk { color: #b45309; font-weight: 700; }

/* ══ Spend ══ */
.eq-spend { padding: 12px 13px 4px; }
.eq-spend-val { font-size: 20px; font-weight: 800; letter-spacing: -0.5px; font-variant-numeric: tabular-nums; }
.eq-spend-cap { font-size: 10px; color: var(--eq-faint); margin-top: 1px; }
.eq-spend-axis {
  display: flex; justify-content: space-between; gap: 2px;
  padding: 2px 13px 12px;
  font-size: 8.5px; font-weight: 700; color: var(--eq-faint);
}
.eq-spend-axis span { flex: 1; text-align: center; }

/* ══ Fault feed (rail) ══ */
.eq-fault-feed { display: flex; flex-direction: column; }
.eq-fault-row {
  display: flex; align-items: center; gap: 8px;
  padding: 8px 13px; width: 100%;
  border: 0; border-bottom: 1px solid var(--eq-line-soft);
  background: transparent; cursor: pointer;
  font-family: inherit; text-align: left;
  transition: background 0.14s ease;
}
.eq-fault-row:last-child { border-bottom: 0; }
.eq-fault-row:hover { background: rgba(var(--v-theme-on-surface), 0.03); }
.eq-fault-dot {
  width: 7px; height: 7px; border-radius: 50%; flex-shrink: 0;
  background: var(--eq-faint);
}
.eq-fault-dot.is-low { background: #94a3b8; }
.eq-fault-dot.is-medium { background: #f59e0b; }
.eq-fault-dot.is-high { background: #f97316; }
.eq-fault-dot.is-critical { background: #ef4444; box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.16); }
.eq-fault-id { display: flex; flex-direction: column; gap: 0; min-width: 0; flex: 1; }
.eq-fault-title {
  font-size: 11.5px; font-weight: 700;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.eq-fault-meta { font-size: 9.5px; color: var(--eq-faint); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

/* ══ Toolbar ══ */
.eq-toolbar {
  display: flex; align-items: center; gap: 9px; flex-wrap: wrap;
  padding: 10px 12px; margin-bottom: 12px;
  border-radius: 14px; border: 1px solid var(--eq-line); background: var(--eq-surface);
}
.eq-search { flex: 1 1 320px; min-width: 190px; }
.eq-field { flex: 0 1 168px; min-width: 132px; }
.eq-toolbar :deep(.v-field) { font-size: 12.5px; }
.eq-viewtoggle {
  display: inline-flex; gap: 2px; padding: 3px;
  border-radius: 10px; border: 1px solid var(--eq-line); background: var(--eq-raise);
}
.eq-viewtoggle button {
  width: 30px; height: 28px; display: grid; place-items: center;
  border: 0; border-radius: 8px; background: transparent;
  color: var(--eq-muted); cursor: pointer;
  transition: background 0.15s ease, color 0.15s ease;
}
.eq-viewtoggle button.is-on {
  background: var(--eq-surface); color: var(--eq-accent);
  box-shadow: 0 1px 5px rgba(15, 23, 42, 0.12);
}
.eq-hint {
  display: flex; align-items: center; gap: 7px;
  margin: -4px 2px 10px;
  font-size: 11px; color: var(--eq-muted);
}
.eq-hint-chip {
  display: inline-flex; align-items: center;
  height: 20px; padding: 0 8px; border-radius: 999px;
  font-size: 10px; font-weight: 800;
  color: #b45309; background: rgba(245, 158, 11, 0.16);
  border: 1px solid rgba(245, 158, 11, 0.28);
}

/* ══ Asset cards ══ */
.eq-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(268px, 1fr));
  gap: 11px;
}
.eq-skel {
  height: 232px; border-radius: 15px;
  border: 1px solid var(--eq-line-soft);
  background: linear-gradient(100deg,
    rgba(var(--v-theme-on-surface), 0.04) 20%,
    rgba(var(--v-theme-on-surface), 0.08) 38%,
    rgba(var(--v-theme-on-surface), 0.04) 56%);
  background-size: 220% 100%;
  animation: eqShimmer 1.4s ease-in-out infinite;
}
@keyframes eqShimmer {
  0% { background-position: 120% 0; }
  100% { background-position: -40% 0; }
}

.eq-card {
  position: relative; display: flex; flex-direction: column;
  padding: 12px 13px 10px;
  border-radius: 15px; border: 1px solid var(--eq-line);
  background: var(--eq-surface); cursor: pointer; overflow: hidden;
  transition: transform 0.16s ease, box-shadow 0.16s ease, border-color 0.16s ease;
  animation: eqRise 0.3s ease both;
  animation-delay: calc(var(--i, 0) * 18ms);
}
@keyframes eqRise {
  from { opacity: 0; transform: translateY(6px); }
  to { opacity: 1; transform: translateY(0); }
}
.eq-card:hover {
  transform: translateY(-2px);
  border-color: color-mix(in srgb, var(--eq-accent) 30%, transparent);
  box-shadow: 0 12px 26px rgba(15, 23, 42, 0.09);
}
.eq-card::before {
  content: ''; position: absolute; left: 0; top: 12px; bottom: 12px;
  width: 2px; border-radius: 0 2px 2px 0; opacity: 0.85;
  background: var(--eq-faint);
}
.eq-card--healthy::before { background: #10b981; }
.eq-card--watch::before { background: #f59e0b; }
.eq-card--at_risk::before { background: #f97316; }
.eq-card--critical::before { background: #ef4444; }
.eq-card.is-inactive { opacity: 0.66; }

.eq-card-top { display: flex; align-items: flex-start; justify-content: space-between; gap: 8px; }
.eq-card-glyph {
  --tone: #2f6dff;
  width: 32px; height: 32px; flex-shrink: 0;
  display: grid; place-items: center; border-radius: 10px;
  color: var(--tone);
  background: color-mix(in srgb, var(--tone) 12%, transparent);
  border: 1px solid color-mix(in srgb, var(--tone) 22%, transparent);
}
.eq-card-tags { display: flex; align-items: center; gap: 4px; flex-wrap: wrap; justify-content: flex-end; }

.eq-card-name {
  margin-top: 9px;
  font-size: 13px; font-weight: 800; letter-spacing: -0.2px;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.eq-card-meta {
  margin-top: 1px; font-size: 11px; color: var(--eq-muted);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.eq-card-tag {
  margin-top: 3px;
  font-size: 9.5px; font-weight: 800; letter-spacing: 0.4px;
  color: var(--eq-faint);
}

.eq-card-rows {
  display: flex; flex-direction: column; gap: 3px;
  margin-top: 9px; padding-top: 8px;
  border-top: 1px solid var(--eq-line-soft);
}
.eq-card-row {
  display: flex; align-items: center; gap: 6px;
  font-size: 10.5px; color: var(--eq-muted); min-width: 0;
}
.eq-card-row .v-icon { color: var(--eq-faint); flex-shrink: 0; }
.eq-card-row span { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.eq-card-row span.is-faint { color: var(--eq-faint); font-style: italic; }

.eq-card-health { margin-top: 9px; }
.eq-card-health-top {
  display: flex; align-items: baseline; justify-content: space-between;
  margin-bottom: 4px;
  font-size: 9px; font-weight: 800; letter-spacing: 0.7px;
  text-transform: uppercase; color: var(--eq-faint);
}
.eq-card-health-top b { font-size: 12px; letter-spacing: 0; font-variant-numeric: tabular-nums; }

.eq-card-foot {
  display: flex; align-items: center; gap: 6px; flex-wrap: wrap;
  margin-top: 9px;
}
.eq-card-serv {
  display: inline-flex; align-items: center; gap: 5px;
  font-size: 10px; font-weight: 700; color: var(--eq-muted);
}
.eq-card-serv.is-good { color: #047857; }
.eq-card-serv.is-warn { color: #b45309; }
.eq-card-serv.is-bad { color: #b91c1c; }

.eq-card-actions {
  display: flex; align-items: center; gap: 1px;
  margin-top: 8px; padding-top: 7px;
  border-top: 1px solid var(--eq-line-soft);
  opacity: 0; transition: opacity 0.16s ease;
}
.eq-card:hover .eq-card-actions { opacity: 1; }
.eq-card-actions button, .eq-rowactions button {
  width: 27px; height: 27px; display: grid; place-items: center;
  border: 0; border-radius: 7px; background: transparent; cursor: pointer;
  color: var(--eq-muted);
  transition: background 0.14s ease, color 0.14s ease;
}
.eq-card-actions button:hover, .eq-rowactions button:hover {
  color: rgb(var(--v-theme-on-surface));
  background: rgba(var(--v-theme-on-surface), 0.07);
}
.eq-card-actions button.is-danger:hover, .eq-rowactions button.is-danger:hover {
  color: #b91c1c; background: rgba(239, 68, 68, 0.1);
}
.eq-rowactions { display: flex; align-items: center; gap: 1px; justify-content: flex-end; }

.eq-health-mini { display: inline-flex; align-items: center; gap: 7px; justify-content: flex-end; }
.eq-health-mini-val { font-size: 12px; font-weight: 800; font-variant-numeric: tabular-nums; }

/* ══ Empty ══ */
.eq-empty {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: 6px; padding: 46px 20px;
  border-radius: 16px; border: 1px dashed var(--eq-line);
  background: var(--eq-raise); text-align: center;
}
.eq-empty-icon {
  width: 60px; height: 60px; border-radius: 18px;
  display: grid; place-items: center; margin-bottom: 4px;
  color: var(--eq-accent);
  background: color-mix(in srgb, var(--eq-accent) 10%, transparent);
  border: 1px solid color-mix(in srgb, var(--eq-accent) 20%, transparent);
}
.eq-empty h2 { margin: 0; font-size: 15px; font-weight: 800; letter-spacing: -0.2px; }
.eq-empty p { margin: 0 0 8px; max-width: 520px; font-size: 12px; line-height: 1.55; color: var(--eq-muted); }
.eq-empty-actions { display: flex; gap: 8px; flex-wrap: wrap; justify-content: center; }

/* ══ Fault cards ══ */
.eq-faultgrid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 11px;
}
.eq-faultcard {
  display: flex; flex-direction: column; gap: 7px;
  padding: 12px 13px 10px;
  border-radius: 15px; border: 1px solid var(--eq-line);
  background: var(--eq-surface);
  position: relative; overflow: hidden;
}
.eq-faultcard::before {
  content: ''; position: absolute; left: 0; top: 12px; bottom: 12px;
  width: 2px; border-radius: 0 2px 2px 0; background: var(--eq-faint);
}
.eq-faultcard.is-low::before { background: #94a3b8; }
.eq-faultcard.is-medium::before { background: #f59e0b; }
.eq-faultcard.is-high::before { background: #f97316; }
.eq-faultcard.is-critical::before { background: #ef4444; }
.eq-faultcard-top { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; }
.eq-fault-age { font-size: 10px; font-weight: 700; color: var(--eq-faint); }
.eq-faultcard-title {
  margin: 0; font-size: 13px; font-weight: 800; letter-spacing: -0.15px;
  line-height: 1.3;
}
.eq-faultcard-desc {
  margin: 0; font-size: 11.5px; line-height: 1.5; color: var(--eq-muted);
  display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden;
}
.eq-faultcard-meta {
  display: flex; align-items: center; gap: 9px; flex-wrap: wrap;
  font-size: 10px; color: var(--eq-faint);
}
.eq-faultcard-meta span { display: inline-flex; align-items: center; gap: 3px; }
.eq-faultcard-res {
  display: flex; align-items: flex-start; gap: 6px;
  padding: 7px 9px; border-radius: 9px;
  background: rgba(16, 185, 129, 0.08);
  border: 1px solid rgba(16, 185, 129, 0.2);
  font-size: 11px; line-height: 1.45; color: #047857;
}
.eq-faultcard-res .v-icon { flex-shrink: 0; margin-top: 1px; }
.eq-faultcard-foot {
  display: flex; align-items: center; gap: 7px;
  margin-top: 2px; padding-top: 8px;
  border-top: 1px solid var(--eq-line-soft);
}

/* ══ Detail dialog ══ */
.eq-dialog-chip {
  display: inline-flex; align-items: center;
  height: 22px; padding: 0 8px; border-radius: 999px;
  font-size: 9.5px; font-weight: 800; letter-spacing: 0.3px; text-transform: uppercase;
  background: rgba(255, 255, 255, 0.18);
  border: 1px solid rgba(255, 255, 255, 0.32);
  color: #fff; white-space: nowrap;
}
.eq-dl-top { display: flex; align-items: center; gap: 14px; flex-wrap: wrap; }
.eq-dl-score {
  --tone: #10b981;
  width: 74px; height: 74px; flex-shrink: 0;
  display: grid; place-items: center; align-content: center; gap: 0;
  border-radius: 18px;
  color: var(--tone);
  background: color-mix(in srgb, var(--tone) 11%, transparent);
  border: 1px solid color-mix(in srgb, var(--tone) 26%, transparent);
}
.eq-dl-score b { font-size: 22px; font-weight: 800; letter-spacing: -0.8px; line-height: 1; font-variant-numeric: tabular-nums; }
.eq-dl-score span { font-size: 8px; font-weight: 800; letter-spacing: 0.6px; text-transform: uppercase; margin-top: 2px; }
.eq-dl-facts { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; flex: 1; min-width: 0; }
.eq-dl-facts div { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
.eq-dl-facts span {
  font-size: 8.5px; font-weight: 800; letter-spacing: 0.6px;
  text-transform: uppercase; color: var(--eq-faint);
}
.eq-dl-facts b { font-size: 12px; font-weight: 700; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.eq-dl-k {
  font-size: 9px; font-weight: 800; letter-spacing: 0.7px;
  text-transform: uppercase; color: var(--eq-faint);
}
.eq-dl-v { font-size: 12px; font-weight: 650; }
.eq-dl-v.is-bad { color: #b91c1c; }
.eq-dl-note {
  font-size: 9px; font-weight: 800; text-transform: uppercase;
  color: #b91c1c; margin-left: 4px;
}
.eq-dl-section {
  margin-top: 14px; padding-top: 12px;
  border-top: 1px solid var(--eq-line-soft);
}
.eq-dl-head {
  display: flex; align-items: center; justify-content: space-between; gap: 8px;
  margin-bottom: 8px;
  font-size: 9px; font-weight: 800; letter-spacing: 0.9px;
  text-transform: uppercase; color: var(--eq-faint);
}
.eq-dl-text { margin: 4px 0 0; font-size: 12px; line-height: 1.55; color: var(--eq-muted); }

.eq-mini-list { display: flex; flex-direction: column; gap: 5px; }
.eq-mini-row {
  display: flex; align-items: center; gap: 8px;
  padding: 6px 8px; border-radius: 9px;
  background: rgba(var(--v-theme-on-surface), 0.025);
  border: 1px solid var(--eq-line-soft);
  font-size: 11px;
}
.eq-mini-main { font-weight: 700; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.eq-mini-sub { font-size: 10px; color: var(--eq-faint); white-space: nowrap; }
.eq-mini-row .eq-pill { margin-left: auto; }

/* ══ Form ══ */
.eq-form-group { margin-bottom: 14px; }
.eq-form-group-title {
  font-size: 9px; font-weight: 800; letter-spacing: 1px;
  text-transform: uppercase; color: var(--eq-faint);
  margin-bottom: 7px;
}
.eq-field { margin-bottom: 12px; min-width: 0; }
.eq-label {
  display: block; margin-bottom: 5px;
  font-size: 10.5px; font-weight: 800; letter-spacing: 0.5px;
  text-transform: uppercase; color: var(--eq-faint);
}
.eq-req { color: #dc2626; }
.eq-confirm { margin: 0; font-size: 12.5px; line-height: 1.6; color: var(--eq-muted); }
.eq-confirm strong { color: rgb(var(--v-theme-on-surface)); }

/* ══ Responsive ══ */
@media (max-width: 1439px) {
  .eq-kpis { grid-template-columns: repeat(3, minmax(0, 1fr)); }
}
@media (max-width: 959px) {
  .eq-kpis { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .eq-head-actions { width: 100%; justify-content: flex-start; }
  .eq-head-stamp { margin-left: 0; }
  .eq-dl-facts { grid-template-columns: repeat(2, minmax(0, 1fr)); }
}
@media (max-width: 767px) {
  .eq-head-title { font-size: 20px; }
  .eq-search { flex-basis: 100%; }
  .eq-field { flex: 1 1 140px; }
  .eq-grid, .eq-faultgrid { grid-template-columns: minmax(0, 1fr); }
}
</style>
