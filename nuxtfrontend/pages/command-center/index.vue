<template>
  <div class="cc-page">
    <!-- ── Ambient background ── -->
    <div class="cc-ambient" aria-hidden="true">
      <span class="cc-orb cc-orb--1" />
      <span class="cc-orb cc-orb--2" />
      <span class="cc-orb cc-orb--3" />
      <span class="cc-gridlines" />
      <span class="cc-vignette" />
    </div>
    <canvas ref="particleCanvas" class="cc-particles" aria-hidden="true" />

    <div class="cc-shell">
      <!-- ── Top bar ── -->
      <header class="cc-topbar">
        <div class="cc-brand">
          <div class="cc-brand__logo">
            <img v-if="orgData?.logo" :src="orgData.logo" alt="Organization logo" />
            <BrandLogo v-else :size="40" />
          </div>
          <div class="cc-brand__text">
            <span class="cc-brand__eyebrow">Organization console</span>
            <span class="cc-brand__name">{{ orgData?.name || 'Organization' }}</span>
          </div>
          <span class="cc-live" :class="activeCount ? 'cc-live--on' : 'cc-live--off'">
            <span class="cc-live__dot" />
            {{ activeCount ? 'Live' : 'Idle' }}
          </span>
        </div>

        <div class="cc-topbar__actions">
          <button
            type="button"
            class="cc-cmdk"
            aria-label="Open command palette"
            @click="openPalette"
          >
            <v-icon size="16">mdi-magnify</v-icon>
            <span class="cc-cmdk__label">Search</span>
            <kbd class="cc-kbd">{{ isMac ? '⌘' : 'Ctrl' }} K</kbd>
          </button>

          <div class="cc-clock">
            <span class="cc-clock__time">{{ clock }}</span>
            <span class="cc-clock__date">{{ today }}</span>
          </div>

          <v-tooltip :text="autoRefresh ? `Auto-refresh in ${countdown}s — click to pause` : 'Auto-refresh paused — click to resume'" location="bottom">
            <template #activator="{ props }">
              <button
                v-bind="props"
                type="button"
                class="cc-icon-btn"
                :class="{ 'cc-icon-btn--live': autoRefresh }"
                :aria-pressed="autoRefresh"
                aria-label="Toggle auto-refresh"
                @click="toggleAutoRefresh"
              >
                <v-icon size="19">{{ autoRefresh ? 'mdi-autorenew' : 'mdi-autorenew-off' }}</v-icon>
              </button>
            </template>
          </v-tooltip>

          <v-tooltip text="Refresh data" location="bottom">
            <template #activator="{ props }">
              <button
                v-bind="props"
                type="button"
                class="cc-icon-btn"
                :class="{ 'cc-icon-btn--spin': loading }"
                aria-label="Refresh data"
                @click="load"
              >
                <v-icon size="19">mdi-refresh</v-icon>
              </button>
            </template>
          </v-tooltip>

          <v-tooltip :text="isFullscreen ? 'Exit fullscreen' : 'Enter fullscreen'" location="bottom">
            <template #activator="{ props }">
              <button
                v-bind="props"
                type="button"
                class="cc-icon-btn"
                :class="{ 'cc-icon-btn--active': isFullscreen }"
                :aria-pressed="isFullscreen"
                :aria-label="isFullscreen ? 'Exit fullscreen' : 'Enter fullscreen'"
                @click="toggleFullscreen"
              >
                <v-icon size="19">{{ isFullscreen ? 'mdi-fullscreen-exit' : 'mdi-fullscreen' }}</v-icon>
              </button>
            </template>
          </v-tooltip>

          <v-tooltip :text="isDark ? 'Switch to light theme' : 'Switch to dark theme'" location="bottom">
            <template #activator="{ props }">
              <button
                v-bind="props"
                type="button"
                class="cc-icon-btn"
                aria-label="Toggle theme"
                @click="toggleTheme"
              >
                <v-icon size="19">{{ isDark ? 'mdi-white-balance-sunny' : 'mdi-weather-night' }}</v-icon>
              </button>
            </template>
          </v-tooltip>

          <v-tooltip text="Console settings" location="bottom">
            <template #activator="{ props }">
              <button
                v-bind="props"
                type="button"
                class="cc-icon-btn"
                aria-label="Console settings"
                @click="navigateTo('/command-center/settings')"
              >
                <v-icon size="19">mdi-cog-outline</v-icon>
              </button>
            </template>
          </v-tooltip>

          <span class="cc-topbar__rule" aria-hidden="true" />

          <v-menu location="bottom end">
            <template #activator="{ props }">
              <button v-bind="props" type="button" class="cc-user" aria-label="Account menu">
                <span class="cc-user__avatar">{{ initial }}</span>
                <span class="cc-user__meta">
                  <span class="cc-user__name">{{ userLabel }}</span>
                  <span class="cc-user__role">Organization admin</span>
                </span>
                <v-icon size="15" class="cc-user__caret">mdi-chevron-down</v-icon>
              </button>
            </template>
            <v-list density="compact" class="cc-user-menu">
              <v-list-item prepend-icon="mdi-cog-outline" title="Console settings" @click="navigateTo('/command-center/settings')" />
              <v-list-item prepend-icon="mdi-logout" title="Sign out" @click="logout" />
            </v-list>
          </v-menu>
        </div>
      </header>

      <!-- ── Loading skeleton ── -->
      <div v-if="loading && !orgData" class="cc-skeleton" aria-busy="true" aria-live="polite">
        <div class="cc-skeleton__hero" />
        <div class="cc-skeleton__row">
          <div v-for="n in 6" :key="`k${n}`" class="cc-skeleton__tile" />
        </div>
        <div class="cc-skeleton__row cc-skeleton__row--cards">
          <div v-for="n in 4" :key="`c${n}`" class="cc-skeleton__card" />
        </div>
      </div>

      <template v-else>
        <!-- ── Hero ── -->
        <section class="cc-hero">
          <span class="cc-hero__mesh" aria-hidden="true" />
          <span class="cc-hero__sheen" aria-hidden="true" />

          <div class="cc-hero__main">
            <div class="cc-hero__body">
              <span class="cc-hero__eyebrow">
                <span class="cc-hero__eyebrow-dot" />
                {{ greeting }}
              </span>
              <h1 class="cc-hero__title">
                Command <span class="cc-hero__accent">Center</span>
              </h1>
              <p class="cc-hero__sub">
                {{ orgData?.motto || 'Every facility, every metric — one operational view.' }}
              </p>
              <div class="cc-hero__chips">
                <span class="cc-hero__chip">
                  <v-icon size="15">mdi-calendar-blank-outline</v-icon>{{ today }}
                </span>
                <span class="cc-hero__chip">
                  <v-icon size="15">mdi-domain-multiple</v-icon>{{ tenantList.length }} facilities
                </span>
                <span class="cc-hero__chip cc-hero__chip--ok">
                  <v-icon size="15">mdi-access-point</v-icon>{{ activeCount }} online
                </span>
                <span v-if="lastUpdated" class="cc-hero__chip cc-hero__chip--muted">
                  <v-icon size="15">mdi-clock-outline</v-icon>updated {{ timeAgo(lastUpdated) }}
                </span>
              </div>
            </div>

            <div class="cc-pulse">
              <div class="cc-pulse__ring" :style="{ '--pct': networkHealth }">
                <div class="cc-pulse__core">
                  <span class="cc-pulse__value">{{ networkHealth }}<small>%</small></span>
                  <span class="cc-pulse__label">network online</span>
                </div>
              </div>
              <div class="cc-pulse__legend">
                <span><i class="cc-dot cc-dot--on" />{{ activeCount }} online</span>
                <span><i class="cc-dot cc-dot--off" />{{ inactiveCount }} offline</span>
              </div>
            </div>
          </div>

          <!-- Hero footer: headline trends for the selected window -->
          <div class="cc-hero__strip">
            <div class="cc-hero__metric">
              <span class="cc-hero__metric-label">Events · {{ range }}d</span>
              <span class="cc-hero__metric-value">{{ formatCompact(windowActivityTotal) }}</span>
              <span class="cc-hero__metric-delta" :class="deltaTone">
                <v-icon size="13">{{ chartDelta >= 0 ? 'mdi-trending-up' : 'mdi-trending-down' }}</v-icon>
                {{ Math.abs(chartDelta).toFixed(0) }}%
              </span>
            </div>
            <div class="cc-hero__metric">
              <span class="cc-hero__metric-label">Revenue · {{ range }}d</span>
              <span class="cc-hero__metric-value">{{ formatKES(windowRevenueTotal) }}</span>
              <span class="cc-hero__metric-sub">POS sales, completed</span>
            </div>
            <div class="cc-hero__metric">
              <span class="cc-hero__metric-label">Avg activity / facility</span>
              <span class="cc-hero__metric-value">{{ perFacilityActivity }}</span>
              <span class="cc-hero__metric-sub">events per facility</span>
            </div>
            <div class="cc-hero__spark" aria-hidden="true">
              <SparkArea
                :values="heroSpark"
                :height="58"
                :show-grid="false"
                :show-y-axis="false"
                color="#7fe3ff"
              />
            </div>
          </div>
        </section>

        <!-- ── Attention strip ── -->
        <section class="cc-insights" aria-label="Attention required">
          <button
            v-for="ins in insights"
            :key="ins.key"
            type="button"
            class="cc-insight"
            :class="[`cc-insight--${ins.tone}`, { 'cc-insight--on': attention === ins.key }]"
            :aria-pressed="attention === ins.key"
            :disabled="!ins.filterable"
            @click="toggleAttention(ins.key)"
          >
            <span class="cc-insight__icon"><v-icon size="17">{{ ins.icon }}</v-icon></span>
            <span class="cc-insight__body">
              <span class="cc-insight__value">{{ ins.value }}</span>
              <span class="cc-insight__label">{{ ins.label }}</span>
            </span>
            <v-icon v-if="ins.filterable" size="14" class="cc-insight__arrow">
              {{ attention === ins.key ? 'mdi-close' : 'mdi-arrow-right' }}
            </v-icon>
          </button>
        </section>

        <!-- ── KPI grid ── -->
        <section class="cc-kpis" aria-label="Network metrics">
          <article
            v-for="(kpi, i) in kpis"
            :key="kpi.title"
            class="cc-kpi"
            :style="{ '--accent': kpi.accent, '--accent-soft': kpi.soft, '--i': i }"
          >
            <div class="cc-kpi__head">
              <span class="cc-kpi__icon"><v-icon size="19">{{ kpi.icon }}</v-icon></span>
              <span class="cc-kpi__idx">{{ String(i + 1).padStart(2, '0') }}</span>
            </div>
            <div class="cc-kpi__value">{{ kpi.display }}</div>
            <div class="cc-kpi__label">{{ kpi.title }}</div>
            <span class="cc-kpi__bar" aria-hidden="true" />
          </article>
        </section>

        <!-- ── Trend + live feed ── -->
        <section class="cc-split">
          <div class="cc-panel cc-panel--chart">
            <header class="cc-panel__head">
              <div>
                <h2 class="cc-panel__title">{{ metric === 'activity' ? 'Network activity' : 'Network revenue' }}</h2>
                <p class="cc-panel__hint">
                  {{ metric === 'activity' ? 'Recorded actions across every facility' : 'Completed POS sales across the network' }}
                  · last {{ range }} days
                </p>
              </div>
              <div class="cc-seg" role="group" aria-label="Trend window">
                <button
                  v-for="opt in [7, 14]"
                  :key="opt"
                  type="button"
                  class="cc-seg__btn"
                  :class="{ 'cc-seg__btn--on': range === opt }"
                  :aria-pressed="range === opt"
                  @click="range = opt"
                >{{ opt }}d</button>
              </div>
            </header>

            <div class="cc-panel__figure">
              <span class="cc-panel__big">
                {{ metric === 'activity' ? formatCompact(chartTotal) : formatKES(chartTotal) }}
              </span>
              <span class="cc-delta" :class="deltaTone">
                <v-icon size="14">{{ chartDelta >= 0 ? 'mdi-trending-up' : 'mdi-trending-down' }}</v-icon>
                {{ Math.abs(chartDelta).toFixed(0) }}%
              </span>
              <span class="cc-panel__vs">vs previous {{ range }}d</span>
            </div>

            <div class="cc-chart">
              <SparkArea
                :values="chartValues"
                :labels="chartLabels"
                :height="168"
                :color="chartColor"
                :y-formatter="metric === 'revenue' ? formatCompact : null"
              />
            </div>

            <footer class="cc-panel__foot">
              <div class="cc-tabs" role="tablist" aria-label="Trend metric">
                <button
                  type="button"
                  role="tab"
                  class="cc-tabs__btn"
                  :class="{ 'cc-tabs__btn--on': metric === 'activity' }"
                  :aria-selected="metric === 'activity'"
                  @click="metric = 'activity'"
                >
                  <v-icon size="15">mdi-pulse</v-icon>Activity
                </button>
                <button
                  type="button"
                  role="tab"
                  class="cc-tabs__btn"
                  :class="{ 'cc-tabs__btn--on': metric === 'revenue' }"
                  :aria-selected="metric === 'revenue'"
                  :disabled="!hasRevenueTrend"
                  @click="metric = 'revenue'"
                >
                  <v-icon size="15">mdi-cash-multiple</v-icon>Revenue
                </button>
              </div>
              <span class="cc-panel__stamp">
                <i class="cc-panel__stamp-dot" />{{ autoRefresh ? `live · ${countdown}s` : 'paused' }}
              </span>
            </footer>
          </div>

          <aside class="cc-panel cc-panel--feed">
            <header class="cc-panel__head">
              <div>
                <h2 class="cc-panel__title">Live activity</h2>
                <p class="cc-panel__hint">Newest events across the network</p>
              </div>
              <span class="cc-panel__count">{{ activityFeed.length }}</span>
            </header>

            <ol class="cc-feed">
              <li
                v-for="ev in activityFeed"
                :key="`${ev.tenant_id}-${ev.id}-${ev.created_at}`"
                class="cc-feed__item"
              >
                <span class="cc-feed__dot" :class="`cc-feed__dot--${ev.severity}`" />
                <div class="cc-feed__body">
                  <p class="cc-feed__text">{{ ev.description }}</p>
                  <div class="cc-feed__meta">
                    <span class="cc-feed__tenant">
                      <v-icon size="12">{{ typeIcon(ev.tenant_type) }}</v-icon>{{ ev.tenant_name }}
                    </span>
                    <span v-if="ev.actor_email" class="cc-feed__actor">{{ ev.actor_email }}</span>
                    <span class="cc-feed__time">{{ timeAgo(ev.created_at) }}</span>
                  </div>
                </div>
              </li>
              <li v-if="!activityFeed.length" class="cc-feed__empty">
                <v-icon size="22">mdi-inbox-outline</v-icon>
                <span>No activity recorded yet</span>
              </li>
            </ol>
          </aside>
        </section>

        <!-- ── Facilities ── -->
        <section class="cc-facilities">
          <div class="cc-facilities__head">
            <div class="cc-facilities__intro">
              <h2 class="cc-facilities__title">Linked facilities</h2>
              <p class="cc-facilities__hint">
                Showing {{ filteredTenants.length }} of {{ tenantList.length }} — pick a facility to open its workspace.
              </p>
            </div>

            <div class="cc-facilities__tools">
              <label class="cc-search">
                <v-icon size="17" class="cc-search__icon">mdi-magnify</v-icon>
                <input
                  v-model="search"
                  type="text"
                  class="cc-search__input"
                  placeholder="Search facilities"
                  aria-label="Search facilities"
                />
                <button v-if="search" type="button" class="cc-search__clear" aria-label="Clear search" @click="search = ''">
                  <v-icon size="14">mdi-close</v-icon>
                </button>
              </label>

              <label class="cc-sort">
                <v-icon size="16" class="cc-sort__icon">mdi-sort-variant</v-icon>
                <select v-model="sortBy" class="cc-sort__select" aria-label="Sort facilities">
                  <option value="status">Status</option>
                  <option value="name">Name</option>
                  <option value="activity">Activity</option>
                  <option value="alerts">Alerts</option>
                  <option value="stock">Stock value</option>
                </select>
                <v-icon size="14" class="cc-sort__caret">mdi-chevron-down</v-icon>
              </label>

              <div class="cc-filters" role="tablist" aria-label="Filter by facility type">
                <button
                  v-for="f in typeFilters"
                  :key="f.value"
                  type="button"
                  role="tab"
                  class="cc-filter"
                  :class="{ 'cc-filter--active': typeFilter === f.value }"
                  :aria-selected="typeFilter === f.value"
                  @click="typeFilter = f.value"
                >
                  {{ f.label }}
                  <span class="cc-filter__count">{{ f.count }}</span>
                </button>
              </div>
            </div>
          </div>

          <div v-if="!filteredTenants.length" class="cc-empty">
            <span class="cc-empty__glyph"><v-icon size="28">mdi-domain-off</v-icon></span>
            <p class="cc-empty__title">No facilities match your filters</p>
            <p class="cc-empty__hint">Try a different search term or clear the type filter.</p>
            <button type="button" class="cc-empty__reset" @click="resetFilters">Reset filters</button>
          </div>

          <div v-else class="cc-cards">
            <article
              v-for="(t, i) in filteredTenants"
              :key="t.id"
              class="cc-card"
              :class="{ 'cc-card--off': !t.is_active }"
              :style="{ '--accent': accentFor(t.type), '--accent-soft': accentSoft(t.type), '--i': i }"
              role="button"
              :tabindex="t.is_active ? 0 : -1"
              :aria-disabled="!t.is_active"
              :aria-label="`Enter ${t.name}`"
              @click="t.is_active && enterTenant(t)"
              @keydown.enter.prevent="t.is_active && enterTenant(t)"
            >
              <span class="cc-card__rail" aria-hidden="true" />

              <div class="cc-card__head">
                <span class="cc-card__glyph">
                  <v-icon size="23">{{ typeIcon(t.type) }}</v-icon>
                </span>
                <span class="cc-card__state" :class="t.is_active ? 'cc-card__state--on' : 'cc-card__state--off'">
                  <i />{{ t.is_active ? 'Online' : 'Offline' }}
                </span>
              </div>

              <h3 class="cc-card__name" :title="t.name">{{ t.name }}</h3>
              <span class="cc-card__type">{{ typeLabel(t.type) }}</span>

              <!-- Only the metrics that apply to this facility type -->
              <div v-if="t.stats.length" class="cc-card__stats">
                <div
                  v-for="(stat, si) in t.stats"
                  :key="stat.key"
                  class="cc-stat"
                  :class="{ 'cc-stat--wide': t.stats.length % 2 === 1 && si === t.stats.length - 1 }"
                >
                  <span class="cc-stat__label">{{ stat.label }}</span>
                  <span class="cc-stat__value" :class="{ 'cc-stat__value--warn': stat.warn }">
                    {{ stat.value }}
                  </span>
                </div>
              </div>

              <!-- Activity sparkline for this facility -->
              <div v-if="hasActivity(t)" class="cc-card__spark">
                <span class="cc-card__spark-label">{{ activityTotal(t) }} events · 14d</span>
                <SparkArea
                  :values="t.activity_14d"
                  :height="34"
                  :show-grid="false"
                  :show-y-axis="false"
                  :color="accentFor(t.type)"
                />
              </div>

              <div class="cc-card__foot">
                <span class="cc-card__cta">
                  {{ t.is_active ? 'Enter facility' : 'Unavailable' }}
                  <v-icon v-if="t.is_active" size="15">mdi-arrow-right</v-icon>
                </span>
                <span v-if="hasLowStock(t)" class="cc-card__flag">
                  <v-icon size="13">mdi-alert-circle-outline</v-icon>{{ t.low_stock_items }} low
                </span>
                <span v-else-if="t.last_event_at" class="cc-card__time">{{ timeAgo(t.last_event_at) }}</span>
              </div>
            </article>
          </div>
        </section>

        <!-- ── Facility traffic monitor ── -->
        <section class="cc-traffic" aria-label="Facility traffic monitor">
          <header class="cc-traffic__head">
            <div class="cc-traffic__intro">
              <h2 class="cc-traffic__title">
                <span class="cc-traffic__pip" :class="{ 'is-live': trafficTotals.live_per_min > 0 }" aria-hidden="true" />
                Facility traffic monitor
              </h2>
              <p class="cc-traffic__hint">
                API requests recorded per linked facility — live rate plus a {{ trafficWindow }}-day history.
              </p>
            </div>
            <div class="cc-traffic__tools">
              <!-- The range control lives once, in the trend chart below, and
                   drives both sections so they can never disagree. -->
              <span class="cc-traffic__range">
                <v-icon size="13">mdi-calendar-range</v-icon>
                {{ trafficRangeLabel || `${trafficWindow}d` }}
              </span>
              <span class="cc-traffic__stamp" :class="{ 'is-live': trafficTotals.live_per_min > 0 }">
                <i class="cc-traffic__stamp-dot" />
                {{ autoRefresh ? `refreshing in ${TRAFFIC_REFRESH_SECONDS}s` : 'paused' }}
              </span>
            </div>
          </header>

          <!-- Network summary -->
          <div class="cc-traffic__summary">
            <div class="cc-traffic__fig">
              <span class="cc-traffic__fig-label">Requests today</span>
              <span class="cc-traffic__fig-value">{{ trafficNum(trafficTotals.requests_today) }}</span>
              <span v-if="trafficTrend !== null && trafficTrend !== undefined"
                    class="cc-traffic__fig-delta"
                    :class="trafficTrend >= 0 ? 'is-up' : 'is-down'">
                <v-icon size="12">{{ trafficTrend >= 0 ? 'mdi-trending-up' : 'mdi-trending-down' }}</v-icon>
                {{ Math.abs(trafficTrend) }}% vs yesterday
              </span>
            </div>
            <div class="cc-traffic__fig">
              <span class="cc-traffic__fig-label">Live rate</span>
              <span class="cc-traffic__fig-value">
                {{ (trafficTotals.live_per_min ?? 0).toFixed(1) }}<em>/min</em>
              </span>
              <span class="cc-traffic__fig-sub">
                {{ trafficTotals.facilities_reporting ?? 0 }} of {{ trafficFacilities.length }} reporting
              </span>
            </div>
            <div class="cc-traffic__fig">
              <span class="cc-traffic__fig-label">Window total</span>
              <span class="cc-traffic__fig-value">{{ trafficNum(trafficTotals.requests_total) }}</span>
              <span class="cc-traffic__fig-sub">{{ trafficWindow }}-day request volume</span>
            </div>
            <div class="cc-traffic__fig">
              <span class="cc-traffic__fig-label">Peak day</span>
              <span class="cc-traffic__fig-value">{{ trafficPeak ? trafficNum(trafficPeak.value) : '—' }}</span>
              <span class="cc-traffic__fig-sub">{{ trafficPeak ? trafficPeak.label : 'no traffic yet' }}</span>
            </div>
            <div class="cc-traffic__fig cc-traffic__fig--chart">
              <SparkArea
                v-if="trafficSeries.length"
                :values="trafficSeries"
                :labels="trafficLabels"
                :height="52"
                :show-grid="false"
                :show-y-axis="false"
                color="#7fe3ff"
              />
            </div>
          </div>

          <!-- Per-facility monitor -->
          <div v-if="trafficLoading && !trafficFacilities.length" class="cc-traffic__loading">
            <span v-for="i in 3" :key="i" class="cc-traffic__skeleton" />
          </div>

          <div v-else-if="trafficError" class="cc-traffic__error">
            <v-icon size="18">mdi-alert-circle-outline</v-icon>
            <span>{{ trafficError }}</span>
            <button type="button" class="cc-traffic__retry" @click="loadTraffic()">Retry</button>
          </div>

          <div v-else-if="!trafficFacilities.length" class="cc-traffic__empty">
            <v-icon size="26">mdi-chart-timeline-variant-shimmer</v-icon>
            <span>No linked facilities to monitor yet</span>
          </div>

          <ul v-else class="cc-traffic__rows">
            <li
              v-for="f in trafficFacilities"
              :key="f.id"
              class="cc-monitor"
              :class="`cc-monitor--${f.status}`"
              :style="{ '--accent': accentFor(f.type), '--accent-soft': accentSoft(f.type) }"
            >
              <div class="cc-monitor__id">
                <span class="cc-monitor__glyph"><v-icon size="17">{{ typeIcon(f.type) }}</v-icon></span>
                <div class="cc-monitor__names">
                  <span class="cc-monitor__name" :title="f.name">{{ f.name }}</span>
                  <span class="cc-monitor__type">{{ typeLabel(f.type) }}</span>
                </div>
              </div>

              <span class="cc-monitor__state" :class="`cc-monitor__state--${trafficStatus(f).tone}`">
                <i />{{ trafficStatus(f).label }}
              </span>

              <div class="cc-monitor__rate">
                <span class="cc-monitor__rate-value" :class="{ 'is-flowing': f.live_per_min > 0 }">
                  {{ Number(f.live_per_min || 0).toFixed(1) }}
                </span>
                <span class="cc-monitor__rate-unit">req/min</span>
              </div>

              <div class="cc-monitor__today">
                <span class="cc-monitor__today-value">{{ trafficNum(f.requests_today) }}</span>
                <span class="cc-monitor__today-delta"
                      :class="trafficDelta(f) === null
                        ? 'is-flat'
                        : (trafficDelta(f) >= 0 ? 'is-up' : 'is-down')">
                  {{ trafficDeltaLabel(f) }}
                </span>
              </div>

              <div class="cc-monitor__spark" aria-hidden="true">
                <SparkArea
                  :values="f.series"
                  :height="38"
                  :show-grid="false"
                  :show-y-axis="false"
                  :color="accentFor(f.type)"
                />
              </div>

              <div class="cc-monitor__share">
                <div class="cc-monitor__share-bar">
                  <span :style="{ width: `${trafficShare(f)}%` }" />
                </div>
                <span class="cc-monitor__share-label">
                  {{ trafficShareLabel(f) }} of network
                </span>
              </div>

              <div class="cc-monitor__foot">
                <span class="cc-monitor__metric">{{ trafficNum(f.requests_total) }} in {{ trafficWindow }}d</span>
                <span class="cc-monitor__dot" aria-hidden="true">·</span>
                <span class="cc-monitor__metric">peak {{ trafficNum(f.requests_peak) }}</span>
                <span v-if="f.last_seen" class="cc-monitor__seen">{{ timeAgo(f.last_seen) }}</span>
              </div>
            </li>
          </ul>

          <footer v-if="trafficFacilities.length" class="cc-traffic__foot">
            <span>
              Live rate comes from the API metering window
              (last {{ traffic.value?.live_window_seconds ? Math.round(traffic.value.live_window_seconds / 60) : 15 }} min).
              Daily totals are exact.
            </span>
            <span class="cc-traffic__foot-stamp">
              updated {{ lastUpdated ? timeAgo(lastUpdated) : '—' }}
            </span>
          </footer>
        </section>

        <!-- ══ Daily traffic trend — one area per facility ══ -->
        <section class="cc-trend" aria-label="Traffic per day by facility">
          <header class="cc-trend__head">
            <div class="cc-trend__intro">
              <h2 class="cc-trend__title">Requests per day, by facility</h2>
              <p class="cc-trend__hint">
                <template v-if="trafficRangeLabel">{{ trafficRangeLabel }} · </template>
                {{ trafficDays.length }} day{{ trafficDays.length === 1 ? '' : 's' }} ·
                {{ trafficFacilities.length }} facilit{{ trafficFacilities.length === 1 ? 'y' : 'ies' }}
              </p>
            </div>

            <!-- Range filter: presets + custom -->
            <div class="cc-trend__filter">
              <div class="cc-seg" role="group" aria-label="Trend range">
                <button
                  v-for="opt in TRAFFIC_PRESETS"
                  :key="opt"
                  type="button"
                  class="cc-seg__btn"
                  :class="{ 'cc-seg__btn--on': trafficRange === opt }"
                  :aria-pressed="trafficRange === opt"
                  @click="setTrafficRange(opt)"
                >{{ opt }}</button>
                <button
                  type="button"
                  class="cc-seg__btn"
                  :class="{ 'cc-seg__btn--on': trafficIsCustom }"
                  :aria-pressed="trafficIsCustom"
                  @click="setTrafficRange('custom')"
                >Custom</button>
              </div>

              <div class="cc-trend__dates" :class="{ 'is-open': trafficIsCustom }">
                <label class="cc-date">
                  <span class="cc-date__label">From</span>
                  <input
                    v-model="customStart"
                    type="date"
                    class="cc-date__input"
                    :max="todayIso"
                    aria-label="Custom range start date"
                  />
                </label>
                <span class="cc-date__sep" aria-hidden="true">→</span>
                <label class="cc-date">
                  <span class="cc-date__label">To</span>
                  <input
                    v-model="customEnd"
                    type="date"
                    class="cc-date__input"
                    :max="todayIso"
                    aria-label="Custom range end date"
                  />
                </label>
                <button
                  type="button"
                  class="cc-date__apply"
                  :disabled="trafficLoading"
                  @click="applyCustomRange"
                >Apply</button>
              </div>
            </div>
          </header>

          <!-- Chart headline numbers -->
          <div class="cc-trend__stats">
            <div class="cc-trend__stat">
              <span class="cc-trend__stat-label">Requests</span>
              <span class="cc-trend__stat-value">{{ trafficNum(trafficTotals.requests_total) }}</span>
              <span
                class="cc-trend__stat-delta"
                :class="(trafficTrend ?? 0) >= 0 ? 'is-up' : 'is-down'"
              >
                <v-icon size="11">{{ (trafficTrend ?? 0) >= 0 ? 'mdi-trending-up' : 'mdi-trending-down' }}</v-icon>
                {{ pctLabel(trafficTrend) }} vs previous
              </span>
            </div>
            <div class="cc-trend__stat">
              <span class="cc-trend__stat-label">Daily average</span>
              <span class="cc-trend__stat-value">{{ trafficNum(trafficDailyAverage) }}</span>
              <span class="cc-trend__stat-sub">per day across the network</span>
            </div>
            <div class="cc-trend__stat">
              <span class="cc-trend__stat-label">Busiest day</span>
              <span class="cc-trend__stat-value">{{ trafficBusiestDay ? trafficNum(trafficBusiestDay.value) : '—' }}</span>
              <span class="cc-trend__stat-sub">{{ trafficBusiestDay ? trafficBusiestDay.label : 'no traffic' }}</span>
            </div>
            <div class="cc-trend__stat">
              <span class="cc-trend__stat-label">Active facilities</span>
              <span class="cc-trend__stat-value">{{ trafficActiveFacilities }}<em>/{{ trafficFacilities.length }}</em></span>
              <span class="cc-trend__stat-sub">reported traffic this range</span>
            </div>

            <div class="cc-trend__modes">
              <div class="cc-seg cc-seg--sm" role="group" aria-label="Chart style">
                <button
                  type="button"
                  class="cc-seg__btn"
                  :class="{ 'cc-seg__btn--on': trafficChartMode === 'area' }"
                  :aria-pressed="trafficChartMode === 'area'"
                  @click="trafficChartMode = 'area'"
                >Area</button>
                <button
                  type="button"
                  class="cc-seg__btn"
                  :class="{ 'cc-seg__btn--on': trafficChartMode === 'line' }"
                  :aria-pressed="trafficChartMode === 'line'"
                  @click="trafficChartMode = 'line'"
                >Line</button>
              </div>
              <button
                type="button"
                class="cc-trend__toggle"
                :class="{ 'is-on': trafficShowPrevious }"
                :aria-pressed="trafficShowPrevious"
                @click="trafficShowPrevious = !trafficShowPrevious"
              >
                <v-icon size="13">mdi-chart-bell-curve-cumulative</v-icon>
                Previous period
              </button>
            </div>
          </div>

          <!-- The chart -->
          <div class="cc-trend__canvas">
            <div v-if="trafficLoading && !trafficChartSeries.length" class="cc-trend__skeleton" />
            <TrafficTrendChart
              v-else
              :series="trafficChartSeries"
              :labels="trafficLabels"
              :previous="trafficPrevious"
              :show-previous="trafficShowPrevious"
              :mode="trafficChartMode"
              :height="300"
            />
            <p v-if="trafficShowPrevious" class="cc-trend__legend-note">
              <span class="cc-trend__ghost-key" aria-hidden="true" />
              Dashed line is the network total for the preceding
              {{ trafficDays.length }}-day period.
            </p>
          </div>

          <!-- Per-facility breakdown -->
          <div v-if="trafficChartHasData" class="cc-trend__table">
            <div class="cc-trend__table-head">
              <span>Facility</span>
              <span class="is-num">Total</span>
              <span class="is-num">Avg/day</span>
              <span class="is-num">Peak</span>
              <span class="is-num">Share</span>
              <span class="is-num">Trend</span>
            </div>
            <div
              v-for="f in trafficChartSeries"
              :key="f.id"
              class="cc-trend__row"
            >
              <span class="cc-trend__row-name">
                <i class="cc-trend__row-swatch" :style="{ background: f.color }" />
                {{ f.label }}
              </span>
              <span class="is-num">{{ trafficNum(f.total) }}</span>
              <span class="is-num">
                {{ trafficNum(Math.round(f.total / (trafficDays.length || 1))) }}
              </span>
              <span class="is-num">{{ trafficNum(f.peak) }}</span>
              <span class="is-num">
                <span class="cc-trend__share">
                  <i :style="{ width: `${f.share}%` }" />
                </span>
                {{ f.shareLabel }}
              </span>
              <span
                class="is-num cc-trend__row-trend"
                :class="f.trend === null ? 'is-flat' : (f.trend >= 0 ? 'is-up' : 'is-down')"
              >
                {{ f.trend === null ? '—' : pctLabel(f.trend) }}
              </span>
            </div>
          </div>
        </section>
      </template>

      <!-- ── Command palette ── -->
      <v-dialog v-model="paletteOpen" max-width="640" scrim="#050a18" transition="cc-pop" attach=".cc-page">
        <div class="cc-palette" role="dialog" aria-label="Command palette">
          <div class="cc-palette__search">
            <v-icon size="20" class="cc-palette__search-icon">mdi-magnify</v-icon>
            <input
              ref="paletteInput"
              v-model="paletteQuery"
              type="text"
              class="cc-palette__input"
              placeholder="Search facilities or run a command…"
              aria-label="Search facilities or commands"
              @keydown.down.prevent="movePalette(1)"
              @keydown.up.prevent="movePalette(-1)"
              @keydown.enter.prevent="runPaletteSelection"
            />
            <kbd class="cc-kbd">Esc</kbd>
          </div>

          <ul v-if="paletteItems.length" class="cc-palette__list">
            <li
              v-for="(item, idx) in paletteItems"
              :key="item.key"
              class="cc-palette__item"
              :class="{ 'cc-palette__item--active': idx === paletteIndex }"
              @mouseenter="paletteIndex = idx"
              @click="runPaletteItem(item)"
            >
              <span class="cc-palette__glyph">
                <v-icon size="17">{{ item.icon }}</v-icon>
              </span>
              <span class="cc-palette__text">
                <strong>{{ item.label }}</strong>
                <small v-if="item.hint">{{ item.hint }}</small>
              </span>
              <span v-if="item.kind === 'facility'" class="cc-palette__badge">Enter</span>
              <v-icon v-else size="14" class="cc-palette__enter">mdi-corner-down-left</v-icon>
            </li>
          </ul>
          <div v-else class="cc-palette__empty">
            <v-icon size="22">mdi-text-search</v-icon>
            <span>No matches for “{{ paletteQuery }}”</span>
          </div>

          <footer class="cc-palette__foot">
            <span><kbd class="cc-kbd">↑</kbd><kbd class="cc-kbd">↓</kbd> navigate</span>
            <span><kbd class="cc-kbd">↵</kbd> open</span>
            <span><kbd class="cc-kbd">Esc</kbd> close</span>
          </footer>
        </div>
      </v-dialog>

      <!-- ── Error snackbar ── -->
      <v-snackbar v-model="errorSnack" color="error" timeout="5000" location="top" rounded="lg">
        {{ errorMsg }}
        <template #actions>
          <v-btn variant="text" @click="errorSnack = false">Close</v-btn>
        </template>
      </v-snackbar>

      <!-- ── Switching overlay ── -->
      <v-overlay v-model="switching" class="align-center justify-center" persistent>
        <div class="cc-switch">
          <div class="cc-switch__ring" />
          <v-icon size="26" class="cc-switch__icon">mdi-swap-horizontal</v-icon>
          <div class="cc-switch__label">
            Switching to <strong>{{ switchingName }}</strong>
          </div>
        </div>
      </v-overlay>
    </div>
  </div>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'
import { useThemeStore } from '~/stores/theme'

definePageMeta({ layout: false })

const auth = useAuthStore()
const themeStore = useThemeStore()
const $api = useNuxtApp().$api

const loading = ref(false)
const switching = ref(false)
const switchingName = ref('')
const errorSnack = ref(false)
const errorMsg = ref('')

const orgData = ref(null)
const tenantList = ref([])
const totals = ref({})
const activityFeed = ref([])
const lastUpdated = ref(null)

/** Facility search + type filter + sort + attention drill-down. */
const search = ref('')
const typeFilter = ref('all')
const sortBy = ref('status')
const attention = ref(null)

/** Trend controls. */
const range = ref(14)
const metric = ref('activity')

/** Live-updating clock / relative timestamps / auto-refresh countdown. */
const clock = ref('')
const now = ref(Date.now())
const dayStamp = ref('')
const autoRefresh = ref(true)
const countdown = ref(60)
const AUTO_REFRESH_SECONDS = 60
let tickTimer = null

/** Facility traffic monitor (bottom of the page). */
const traffic = ref(null)
const trafficLoading = ref(false)
const trafficError = ref('')
// Poll the traffic endpoint more often than the heavy org stats: it is a cheap
// single-table read and the whole point is that it looks live.
const TRAFFIC_REFRESH_SECONDS = 15
// One range drives both the monitor rows and the trend chart below, so the
// two never disagree about what "this window" means.
const trafficRange = ref('14d')
const TRAFFIC_PRESETS = ['7d', '14d', '30d']
let trafficCountdown = TRAFFIC_REFRESH_SECONDS

/** Custom range inputs (ISO `YYYY-MM-DD`, as produced by <input type="date">). */
function isoDaysAgo(days) {
  const d = new Date()
  d.setHours(12, 0, 0, 0)
  d.setDate(d.getDate() - days)
  return d.toISOString().slice(0, 10)
}
const customStart = ref(isoDaysAgo(20))
const customEnd = ref(isoDaysAgo(0))
const todayIso = computed(() => isoDaysAgo(0))

const trafficIsCustom = computed(() => trafficRange.value === 'custom')

/** Length of the active window, in days (inclusive). Used in copy. */
const trafficWindow = computed(() => {
  if (!trafficIsCustom.value) return parseInt(trafficRange.value, 10) || 14
  return traffic.value?.range?.days
    || Math.max(1, Math.round((new Date(customEnd.value) - new Date(customStart.value)) / 86400000) + 1)
})

/** Command palette. */
const paletteOpen = ref(false)
const paletteQuery = ref('')
const paletteIndex = ref(0)
const paletteInput = ref(null)
const isMac = ref(false)

const today = new Date().toLocaleDateString('en-US', {
  weekday: 'short', year: 'numeric', month: 'short', day: 'numeric'
})

const isDark = computed(() => themeStore.mode === 'dark')

function toggleTheme() {
  themeStore.setMode(isDark.value ? 'light' : 'dark')
}

// ── Fullscreen ─────────────────────────────────────────────────────
const isFullscreen = ref(false)

function syncFullscreen() {
  if (typeof document === 'undefined') return
  isFullscreen.value = !!document.fullscreenElement
}

function toggleFullscreen() {
  if (typeof document === 'undefined') return
  if (document.fullscreenElement) {
    document.exitFullscreen?.()?.catch?.(() => {})
    return
  }
  const el = document.documentElement
  if (!el.requestFullscreen) {
    errorMsg.value = 'Fullscreen is not supported in this browser.'
    errorSnack.value = true
    return
  }
  el.requestFullscreen().catch(() => {
    errorMsg.value = 'Your browser blocked fullscreen. Try again or press F11.'
    errorSnack.value = true
  })
}

function tick() {
  const d = new Date()
  clock.value = d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })
  now.value = d.getTime()
  // Chart axis labels only change once a day — keep them out of the 1s tick.
  dayStamp.value = d.toDateString()
  if (!autoRefresh.value || switching.value || paletteOpen.value) return
  countdown.value -= 1
  if (countdown.value <= 0) {
    countdown.value = AUTO_REFRESH_SECONDS
    load()
  }
  // The traffic monitor has its own, faster cadence.
  trafficCountdown -= 1
  if (trafficCountdown <= 0) {
    trafficCountdown = TRAFFIC_REFRESH_SECONDS
    loadTraffic({ silent: true })
  }
}

function toggleAutoRefresh() {
  autoRefresh.value = !autoRefresh.value
  countdown.value = AUTO_REFRESH_SECONDS
}

const initial = computed(() => {
  const n = auth.user?.first_name || 'U'
  return (n[0] || 'U').toUpperCase()
})

const userLabel = computed(() => {
  const u = auth.user || {}
  const full = [u.first_name, u.last_name].filter(Boolean).join(' ').trim()
  return full || u.email || u.username || 'Account'
})

const greeting = computed(() => {
  const h = new Date().getHours()
  if (h < 12) return 'Good morning'
  if (h < 17) return 'Good afternoon'
  return 'Good evening'
})

const activeCount = computed(() => tenantList.value.filter(t => t.is_active).length)
const inactiveCount = computed(() => tenantList.value.length - activeCount.value)
const networkHealth = computed(() =>
  tenantList.value.length ? Math.round((activeCount.value / tenantList.value.length) * 100) : 0
)

const TENANT_META = {
  hospital: { label: 'Hospital', icon: 'mdi-hospital-building', color: 'red', hex: '#ef4444', grad: 'linear-gradient(135deg, #ef4444, #b91c1c)' },
  clinic: { label: 'Clinic', icon: 'mdi-stethoscope', color: 'teal', hex: '#14b8a6', grad: 'linear-gradient(135deg, #14b8a6, #0d9488)' },
  pharmacy: { label: 'Pharmacy', icon: 'mdi-pill', color: 'green', hex: '#22c55e', grad: 'linear-gradient(135deg, #22c55e, #15803d)' },
  inventory: { label: 'Inventory / Warehouse', icon: 'mdi-warehouse', color: 'amber-darken-2', hex: '#f59e0b', grad: 'linear-gradient(135deg, #f59e0b, #b45309)' },
  lab: { label: 'Laboratory', icon: 'mdi-test-tube', color: 'purple', hex: '#a855f7', grad: 'linear-gradient(135deg, #a855f7, #7e22ce)' },
  homecare: { label: 'Homecare', icon: 'mdi-home-heart', color: 'pink', hex: '#ec4899', grad: 'linear-gradient(135deg, #ec4899, #be185d)' },
  radiology_center: { label: 'Radiology Centre', icon: 'mdi-xray-box', color: 'indigo', hex: '#6366f1', grad: 'linear-gradient(135deg, #6366f1, #4338ca)' },
}

/** Fallback accent for an unknown / missing facility type. */
const DEFAULT_ACCENT = '#2f6dff'

/** `#rrggbb` → `rgba(r, g, b, alpha)`. Keeps the badge tints in one place. */
function tint(hex, alpha) {
  const r = parseInt(hex.slice(1, 3), 16)
  const g = parseInt(hex.slice(3, 5), 16)
  const b = parseInt(hex.slice(5, 7), 16)
  return `rgba(${r}, ${g}, ${b}, ${alpha})`
}

function typeIcon(type) {
  return TENANT_META[type]?.icon || 'mdi-domain'
}
/** Human-readable facility type, e.g. `inventory` → "Inventory / Warehouse". */
function typeLabel(type) {
  if (TENANT_META[type]?.label) return TENANT_META[type].label
  return type ? type.replace(/_/g, ' ') : 'Facility'
}
/** Accent hex for a facility type (falls back to the brand blue). */
function accentFor(type) {
  return TENANT_META[type]?.hex || DEFAULT_ACCENT
}
/** Translucent accent wash used behind glyphs and hovers. */
function accentSoft(type) {
  return tint(accentFor(type), 0.14)
}

function hasLowStock(t) {
  return Number(t?.low_stock_items || 0) > 0
}

function activityTotal(t) {
  return (t?.activity_14d || []).reduce((a, b) => a + (Number(b) || 0), 0)
}

function hasActivity(t) {
  return activityTotal(t) > 0
}

/** Human relative time, e.g. `12m ago`. Keeps the feed feeling live. */
function timeAgo(iso) {
  if (!iso) return '—'
  const ts = new Date(iso).getTime()
  if (Number.isNaN(ts)) return '—'
  const diff = Math.max(0, now.value - ts)
  const mins = Math.floor(diff / 60000)
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins}m ago`
  const hours = Math.floor(mins / 60)
  if (hours < 24) return `${hours}h ago`
  const days = Math.floor(hours / 24)
  if (days < 30) return `${days}d ago`
  return new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
}

/** Compact number for headline metrics (`1.2K`, `3.4M`). */
function formatCompact(val) {
  const n = Number(val) || 0
  if (Math.abs(n) >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`
  if (Math.abs(n) >= 1_000) return `${(n / 1_000).toFixed(n >= 10_000 ? 0 : 1)}K`
  return String(Math.round(n))
}

/**
 * Metrics each facility type actually reports. The API returns `null` for
 * metrics that do not apply to a tenant type (e.g. `stock_value` on a
 * hospital), so null/undefined entries are filtered out per card.
 */
const STAT_DEFS = [
  { key: 'user_count', label: 'Users', format: v => v },
  { key: 'patient_count', label: 'Patients', format: v => v },
  { key: 'appointments_today', label: 'Appts today', format: v => v },
  { key: 'revenue_30d', label: 'Revenue · 30d', format: formatKES },
  { key: 'stock_value', label: 'Stock value', format: formatKES },
  { key: 'active_alerts', label: 'Alerts', format: v => v, warn: v => Number(v) > 0 },
]

function tenantStats(t) {
  if (!t) return []
  return STAT_DEFS
    .filter(def => t[def.key] !== null && t[def.key] !== undefined)
    .map(def => {
      const raw = t[def.key]
      const format = def.format || (v => v)
      return {
        key: def.key,
        label: def.label,
        value: format(raw),
        warn: Boolean(def.warn && def.warn(raw)),
      }
    })
}

function formatKES(val) {
  if (val === null || val === undefined || Number.isNaN(Number(val))) return '—'
  const n = Number(val)
  if (n >= 1_000_000) return `KSh ${(n / 1_000_000).toFixed(1)}M`
  if (n >= 1_000) return `KSh ${(n / 1_000).toFixed(0)}K`
  return `KSh ${n.toFixed(0)}`
}

/** Type filter chips, derived from the facilities actually returned. */
const typeFilters = computed(() => {
  const counts = new Map()
  for (const t of tenantList.value) {
    const key = t.type || 'other'
    counts.set(key, (counts.get(key) || 0) + 1)
  }
  const chips = [{ value: 'all', label: 'All', count: tenantList.value.length }]
  for (const [key, count] of [...counts.entries()].sort((a, b) => b[1] - a[1])) {
    chips.push({ value: key, label: typeLabel(key), count })
  }
  return chips
})

/** Search + attention + type filtered facilities, sorted, stats precomputed. */
const filteredTenants = computed(() => {
  const q = search.value.trim().toLowerCase()
  return tenantList.value
    .filter(matchesAttention)
    .filter(t => {
      if (typeFilter.value !== 'all' && (t.type || 'other') !== typeFilter.value) return false
      if (!q) return true
      return `${t.name || ''} ${typeLabel(t.type)}`.toLowerCase().includes(q)
    })
    .sort(comparatorFor(sortBy.value))
    .map(t => ({ ...t, stats: tenantStats(t) }))
})

/** Attention drill-down from the insight strip. */
function matchesAttention(t) {
  switch (attention.value) {
    case 'offline': return !t.is_active
    case 'low_stock': return hasLowStock(t)
    case 'alerts': return Number(t?.active_alerts || 0) > 0
    case 'no_users': return t.is_active && !Number(t?.user_count || 0)
    default: return true
  }
}

function toggleAttention(key) {
  attention.value = attention.value === key ? null : key
}

function comparatorFor(mode) {
  const byStatus = (a, b) => (a.is_active === b.is_active ? 0 : a.is_active ? -1 : 1)
  const byName = (a, b) => String(a.name || '').localeCompare(String(b.name || ''))
  switch (mode) {
    case 'name': return byName
    case 'activity': return (a, b) => activityTotal(b) - activityTotal(a) || byName(a, b)
    case 'alerts': return (a, b) => Number(b.active_alerts || 0) - Number(a.active_alerts || 0) || byName(a, b)
    case 'stock': return (a, b) => Number(b.stock_value || 0) - Number(a.stock_value || 0) || byName(a, b)
    default: return (a, b) => byStatus(a, b) || byName(a, b)
  }
}

function resetFilters() {
  search.value = ''
  typeFilter.value = 'all'
  attention.value = null
}

/** ── Trends ── */
const activitySeries = computed(() => totals.value?.activity_14d || [])
const revenueSeries = computed(() => totals.value?.revenue_14d || [])
const hasRevenueTrend = computed(() => revenueSeries.value.some(n => Number(n) > 0))

function windowSlice(series, size) {
  return series.slice(Math.max(0, series.length - size))
}

const chartSource = computed(() => (metric.value === 'revenue' ? revenueSeries.value : activitySeries.value))
const chartValues = computed(() => windowSlice(chartSource.value, range.value))
const chartTotal = computed(() => chartValues.value.reduce((a, b) => a + (Number(b) || 0), 0))
const previousTotal = computed(() => {
  const series = chartSource.value
  const size = range.value
  return series.slice(Math.max(0, series.length - size * 2), Math.max(0, series.length - size))
    .reduce((a, b) => a + (Number(b) || 0), 0)
})
const chartDelta = computed(() => {
  const prev = previousTotal.value
  if (!prev) return chartTotal.value > 0 ? 100 : 0
  return ((chartTotal.value - prev) / prev) * 100
})
const deltaTone = computed(() => (chartDelta.value >= 0 ? 'cc-up' : 'cc-down'))
const chartColor = computed(() => (metric.value === 'revenue' ? '#10b981' : '#2f6dff'))
const heroSpark = computed(() => windowSlice(activitySeries.value, range.value))

const chartLabels = computed(() => {
  const size = chartValues.value.length
  const out = []
  const base = new Date(dayStamp.value || Date.now())
  for (let i = size - 1; i >= 0; i -= 1) {
    const d = new Date(base)
    d.setDate(d.getDate() - i)
    out.push(d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }))
  }
  return out
})

const windowActivityTotal = computed(() =>
  windowSlice(activitySeries.value, range.value).reduce((a, b) => a + (Number(b) || 0), 0))
const windowRevenueTotal = computed(() =>
  windowSlice(revenueSeries.value, range.value).reduce((a, b) => a + (Number(b) || 0), 0))
const perFacilityActivity = computed(() => {
  const n = tenantList.value.length || 1
  return Math.round((windowActivityTotal.value / n) * 10) / 10
})

/** ── Attention strip ── */
const insights = computed(() => {
  const t = totals.value || {}
  const offline = tenantList.value.filter(x => !x.is_active).length
  const lowStock = Number(t.low_stock_items || 0)
  const alerts = Number(t.active_alerts || 0)
  const noUsers = tenantList.value.filter(x => x.is_active && !Number(x.user_count || 0)).length
  return [
    { key: 'offline', icon: 'mdi-lan-disconnect', label: 'Facilities offline', value: offline, tone: offline ? 'danger' : 'ok' },
    { key: 'low_stock', icon: 'mdi-package-variant-remove', label: 'Low stock items', value: lowStock, tone: lowStock ? 'warn' : 'ok' },
    { key: 'alerts', icon: 'mdi-bell-alert', label: 'Unread alerts', value: alerts, tone: alerts ? 'danger' : 'ok' },
    { key: 'no_users', icon: 'mdi-account-off-outline', label: 'Facilities without users', value: noUsers, tone: noUsers ? 'warn' : 'ok' },
  ].map(row => ({ ...row, filterable: row.value > 0 }))
})

const kpis = computed(() => {
  const t = totals.value || {}
  return [
    { title: 'Total users', display: t.user_count ?? 0, icon: 'mdi-account-group', accent: '#2f6dff', soft: 'rgba(47,109,255,0.12)' },
    { title: 'Patients', display: t.patient_count ?? 0, icon: 'mdi-account-injury', accent: '#0ea5e9', soft: 'rgba(14,165,233,0.12)' },
    { title: 'Revenue · 30d', display: formatKES(t.revenue_30d), icon: 'mdi-cash-multiple', accent: '#10b981', soft: 'rgba(16,185,129,0.12)' },
    { title: 'Stock value', display: formatKES(t.stock_value), icon: 'mdi-package-variant-closed', accent: '#f59e0b', soft: 'rgba(245,158,11,0.12)' },
    { title: 'Appointments today', display: t.appointments_today ?? 0, icon: 'mdi-calendar-check', accent: '#14b8a6', soft: 'rgba(20,184,166,0.12)' },
    { title: 'Active alerts', display: t.active_alerts ?? 0, icon: 'mdi-bell-alert', accent: '#ef4444', soft: 'rgba(239,68,68,0.12)' },
  ]
})

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/organizations/stats/')
    orgData.value = data.org
    tenantList.value = data.tenants || []
    totals.value = data.totals || {}
    activityFeed.value = data.activity || []
    lastUpdated.value = data.generated_at || new Date().toISOString()
    countdown.value = AUTO_REFRESH_SECONDS
  } catch (err) {
    errorMsg.value = err?.response?.data?.detail || 'Failed to load organization stats.'
    errorSnack.value = true
  } finally {
    loading.value = false
  }
}

/**
 * Facility traffic monitor.
 *
 * Backed by `GET /organizations/traffic/`, which merges the durable per-day
 * request counters (`DailyUsage`) with the API middleware's rolling window.
 * Kept separate from `load()` because it polls four times faster.
 */
async function loadTraffic({ silent = false } = {}) {
  if (!silent) trafficLoading.value = true
  trafficError.value = ''
  try {
    const { data } = await $api.get('/organizations/traffic/', {
      params: trafficQuery()
    })
    traffic.value = data
    trafficCountdown = TRAFFIC_REFRESH_SECONDS
  } catch (err) {
    trafficError.value = err?.response?.data?.detail || 'Traffic data unavailable.'
  } finally {
    trafficLoading.value = false
  }
}

/** Query params for the active range — presets use `window`, custom uses dates. */
function trafficQuery() {
  if (trafficIsCustom.value) {
    // Guard against half-filled inputs: the pickers are optional-looking but
    // the endpoint needs both ends.
    const start = customStart.value || isoDaysAgo(20)
    const end = customEnd.value || todayIso.value
    return { range: 'custom', start, end }
  }
  return { window: parseInt(trafficRange.value, 10) || 14 }
}

function setTrafficRange(next) {
  if (trafficRange.value === next && !trafficIsCustom.value) return
  trafficRange.value = next
  if (next !== 'custom') loadTraffic()
}

function applyCustomRange() {
  // Keep the pickers honest: end never in the future, start never after end.
  if (customEnd.value > todayIso.value) customEnd.value = todayIso.value
  if (customStart.value && customEnd.value && customStart.value > customEnd.value) {
    const swap = customStart.value
    customStart.value = customEnd.value
    customEnd.value = swap
  }
  trafficRange.value = 'custom'
  loadTraffic()
}

function setTrafficWindow(days) {
  setTrafficRange(`${days}d`)
}

const trafficFacilities = computed(() => traffic.value?.facilities || [])
const trafficTotals = computed(() => traffic.value?.totals || {})
const trafficDays = computed(() => traffic.value?.range?.dates || [])
const trafficSeries = computed(() => trafficTotals.value.series || [])
const trafficPrevious = computed(() => trafficTotals.value.previous_series || [])

/** Axis labels as `d MMM`, so a 30-day window still reads cleanly. */
const trafficLabels = computed(() => trafficDays.value.map(iso => {
  const d = new Date(iso)
  return Number.isNaN(d.getTime()) ? '' : d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
}))

/** Delta vs the previous period, for the headline card. */
const trafficTrend = computed(() => trafficTotals.value.trend_pct)

/**
 * Very small comparison periods produce absurd deltas (`+73277%`). Cap the
 * display rather than lying about precision.
 */
function pctLabel(value) {
  if (value === null || value === undefined) return '—'
  const n = Number(value)
  if (!Number.isFinite(n)) return '—'
  if (Math.abs(n) >= 1000) return n >= 0 ? '> +999%' : '< −999%'
  return `${n >= 0 ? '+' : '−'}${Math.abs(Math.round(n))}%`
}

/** Peak day inside the window, surfaced as `14 Oct · 4.5K requests`. */
const trafficPeak = computed(() => {
  const series = trafficSeries.value
  if (!series.length) return null
  let idx = 0
  series.forEach((v, i) => { if (Number(v) > Number(series[idx])) idx = i })
  if (!Number(series[idx])) return null
  const iso = trafficDays.value[idx]
  const d = iso ? new Date(iso) : null
  return {
    label: d && !Number.isNaN(d.getTime())
      ? d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
      : '—',
    value: Number(series[idx])
  }
})

/** Exact share of network requests, as a percentage (may be fractional). */
function trafficShareRaw(f) {
  const total = Number(trafficTotals.value.requests_total || 0)
  const own = Number(f?.requests_total || 0)
  if (!total || !own) return 0
  return (own / total) * 100
}

/** Bar width — floored at 1% so a tiny-but-nonzero share stays visible. */
function trafficShare(f) {
  const pct = trafficShareRaw(f)
  return pct ? Math.max(1, Math.round(pct)) : 0
}

/**
 * Human share label. Sub-1% shares read `<1%` rather than being floored to a
 * misleading `1%`.
 */
function trafficShareLabel(f) {
  const pct = trafficShareRaw(f)
  if (!pct) return '0%'
  if (pct < 1) return '<1%'
  return `${Math.round(pct)}%`
}

/** Day-over-day change for a single facility. `null` when there is no basis. */
function trafficDelta(f) {
  const today = Number(f.requests_today || 0)
  const yesterday = Number(f.requests_yesterday || 0)
  if (!yesterday) return null
  return Math.round(((today - yesterday) / yesterday) * 100)
}

/** Label for the day-over-day cell: a delta, or a quiet-state hint. */
function trafficDeltaLabel(f) {
  const delta = trafficDelta(f)
  if (delta !== null) return `${delta >= 0 ? '+' : '−'}${Math.abs(delta)}%`
  return Number(f.requests_today || 0) > 0 ? 'new' : 'no traffic'
}

const TRAFFIC_STATUS_META = {
  flowing: { label: 'Flowing', tone: 'live', icon: 'mdi-pulse' },
  idle: { label: 'Idle', tone: 'idle', icon: 'mdi-timer-sand' },
  silent: { label: 'Silent', tone: 'silent', icon: 'mdi-circle-off-outline' },
  offline: { label: 'Offline', tone: 'off', icon: 'mdi-lan-disconnect' },
}

function trafficStatus(f) {
  return TRAFFIC_STATUS_META[f?.status] || TRAFFIC_STATUS_META.silent
}

/** Compact `950` → `950`, `4520` → `4.5K`. Reuses formatCompact. */
function trafficNum(v) {
  return formatCompact(Number(v) || 0)
}

/* ── Trend chart (per-tenant daily traffic) ─────────────────────────────
   The chart plots one smooth area per facility over the shared range. Series
   colours come from the facility type so they match the cards and monitor
   rows above; a second facility of the same type gets a shifted hue so the
   two lines stay distinguishable. */
const TRAFFIC_CHART_PALETTE = [
  '#2f6dff', '#10b981', '#f59e0b', '#ec4899',
  '#8b5cf6', '#06b6d4', '#ef4444', '#84cc16',
]

const trafficChartSeries = computed(() =>
  trafficFacilities.value.map((f, i) => {
    const values = (f.series || []).map(v => Number(v) || 0)
    return {
      id: f.id,
      label: f.name,
      color: TRAFFIC_CHART_PALETTE[i % TRAFFIC_CHART_PALETTE.length],
      values,
      total: Number(f.requests_total || 0),
      peak: values.length ? Math.max(...values) : 0,
      share: trafficShare(f),
      shareLabel: trafficShareLabel(f),
      type: f.type,
      trend: f.trend_pct ?? null
    }
  })
)

const trafficChartMode = ref('area')
const trafficShowPrevious = ref(false)
const trafficChartHasData = computed(() =>
  trafficChartSeries.value.some(s => s.values.some(v => v > 0))
)

/** Active facilities in the window — a useful headline next to the chart. */
const trafficActiveFacilities = computed(
  () => trafficFacilities.value.filter(f => Number(f.requests_total || 0) > 0).length
)

/** Average daily network requests across the window. */
const trafficDailyAverage = computed(() => {
  const total = Number(trafficTotals.value.requests_total || 0)
  const days = trafficDays.value.length || 1
  return Math.round(total / days)
})

/** Busiest single day, from the aggregated network series. */
const trafficBusiestDay = computed(() => {
  const series = trafficSeries.value
  if (!series.length) return null
  let idx = 0
  series.forEach((v, i) => { if (Number(v) > Number(series[idx])) idx = i })
  if (!Number(series[idx])) return null
  const iso = trafficDays.value[idx]
  const d = iso ? new Date(iso) : null
  return {
    label: d && !Number.isNaN(d.getTime())
      ? d.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })
      : '—',
    value: Number(series[idx]),
    iso
  }
})

/** Human description of the active range, e.g. `5 Oct → 24 Oct 2026`. */
const trafficRangeLabel = computed(() => {
  const r = traffic.value?.range
  if (!r?.start || !r?.end) return ''
  const opts = { day: 'numeric', month: 'short' }
  const s = new Date(r.start)
  const e = new Date(r.end)
  if (Number.isNaN(s.getTime()) || Number.isNaN(e.getTime())) return ''
  const sameYear = s.getFullYear() === e.getFullYear()
  return `${s.toLocaleDateString('en-US', opts)} → ${e.toLocaleDateString('en-US', opts)} ${e.getFullYear()}`
    + (sameYear ? '' : '')
})

async function enterTenant(tenant) {
  switching.value = true
  switchingName.value = tenant.name
  try {
    await auth.switchTenant(tenant.id)
    // Navigate to the tenant's home path
    const homePath = getTenantHomePath(tenant.type)
    await navigateTo(homePath, { replace: true })
  } catch (err) {
    errorMsg.value = err?.response?.data?.detail || 'Failed to switch tenant.'
    errorSnack.value = true
  } finally {
    switching.value = false
  }
}

function getTenantHomePath(type) {
  if (type === 'pharmacy') return '/pharmacy'
  if (type === 'lab') return '/lab'
  if (type === 'radiology_center') return '/radiology'
  if (type === 'hospital') return '/hos'
  if (type === 'clinic') return '/clinics'
  if (type === 'inventory') return '/ims'
  return '/dashboard'
}

async function logout() {
  await auth.logout()
  navigateTo('/welcome', { replace: true })
}

// ── Command palette ────────────────────────────────────────────────
const paletteActions = computed(() => [
  { key: 'act-refresh', kind: 'action', icon: 'mdi-refresh', label: 'Refresh data', hint: 'Reload every facility metric', run: load },
  { key: 'act-theme', kind: 'action', icon: isDark.value ? 'mdi-white-balance-sunny' : 'mdi-weather-night', label: isDark.value ? 'Switch to light theme' : 'Switch to dark theme', run: toggleTheme },
  { key: 'act-auto', kind: 'action', icon: 'mdi-autorenew', label: autoRefresh.value ? 'Pause auto-refresh' : 'Resume auto-refresh', run: toggleAutoRefresh },
  { key: 'act-settings', kind: 'action', icon: 'mdi-cog-outline', label: 'Console settings', hint: 'Branding, contact details', run: () => navigateTo('/command-center/settings') },
])

const paletteItems = computed(() => {
  const q = paletteQuery.value.trim().toLowerCase()
  const facilities = tenantList.value.map(t => ({
    key: `t-${t.id}`,
    kind: 'facility',
    icon: typeIcon(t.type),
    label: t.name,
    hint: `${typeLabel(t.type)} · ${t.is_active ? 'Online' : 'Offline'}`,
    tenant: t,
  }))
  const items = [...facilities, ...paletteActions.value]
  if (!q) return items
  return items.filter(i => `${i.label} ${i.hint || ''}`.toLowerCase().includes(q))
})

function openPalette() {
  paletteQuery.value = ''
  paletteIndex.value = 0
  paletteOpen.value = true
  nextTick(() => paletteInput.value?.focus())
}

function movePalette(step) {
  const n = paletteItems.value.length
  if (!n) return
  paletteIndex.value = (paletteIndex.value + step + n) % n
}

function runPaletteItem(item) {
  paletteOpen.value = false
  if (!item) return
  if (item.kind === 'facility') {
    if (item.tenant?.is_active) enterTenant(item.tenant)
    return
  }
  item.run?.()
}

function runPaletteSelection() {
  runPaletteItem(paletteItems.value[paletteIndex.value])
}

function onKeydown(e) {
  if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
    e.preventDefault()
    if (!paletteOpen.value) openPalette()
    return
  }
  if (e.key === 'Escape' && paletteOpen.value) {
    paletteOpen.value = false
  }
}

watch(paletteQuery, () => { paletteIndex.value = 0 })

onMounted(() => {
  if (!auth.isOrgAdmin) {
    navigateTo(getHomePathForUser(), { replace: true })
    return
  }
  themeStore.load()
  isMac.value = /mac|iphone|ipad/i.test(navigator.platform || navigator.userAgent || '')
  tick()
  tickTimer = setInterval(tick, 1000)
  window.addEventListener('keydown', onKeydown)
  document.addEventListener('fullscreenchange', syncFullscreen)
  syncFullscreen()
  load()
  loadTraffic()
  if (particleCanvas.value) {
    cleanupParticles = startParticleNetwork(particleCanvas.value)
  }
})
onBeforeUnmount(() => {
  if (tickTimer) clearInterval(tickTimer)
  window.removeEventListener('keydown', onKeydown)
  document.removeEventListener('fullscreenchange', syncFullscreen)
  if (cleanupParticles) cleanupParticles()
})

// ── Particle network background ──
const particleCanvas = ref(null)
let cleanupParticles = null

function startParticleNetwork(canvas) {
  if (!import.meta.client || !canvas) return null
  const ctx = canvas.getContext('2d')
  if (!ctx) return null
  const PARTICLE_COUNT = 140
  const MAX_DISTANCE = 140
  const MOUSE_RADIUS = 180
  let mouse = { x: -9999, y: -9999 }
  let rafId = null
  const particles = []

  function resize() {
    canvas.width = canvas.clientWidth
    canvas.height = canvas.clientHeight
  }
  resize()
  const ro = new ResizeObserver(resize)
  ro.observe(canvas)
  window.addEventListener('resize', resize)

  for (let i = 0; i < PARTICLE_COUNT; i++) {
    particles.push({
      x: Math.random() * canvas.width,
      y: Math.random() * canvas.height,
      vx: (Math.random() - 0.5) * 0.35,
      vy: (Math.random() - 0.5) * 0.35,
      r: Math.random() * 1.8 + 0.8,
    })
  }

  function onMouseMove(e) {
    mouse.x = e.clientX
    mouse.y = e.clientY
  }
  function onMouseLeave() { mouse.x = -9999; mouse.y = -9999 }
  window.addEventListener('mousemove', onMouseMove)
  window.addEventListener('mouseout', onMouseLeave)

  function draw() {
    ctx.clearRect(0, 0, canvas.width, canvas.height)
    for (const p of particles) {
      p.x += p.vx; p.y += p.vy
      if (p.x < 0 || p.x > canvas.width) p.vx *= -1
      if (p.y < 0 || p.y > canvas.height) p.vy *= -1
      const dx = p.x - mouse.x, dy = p.y - mouse.y
      const dist = Math.hypot(dx, dy)
      if (dist < MOUSE_RADIUS && dist > 0) {
 const force = (MOUSE_RADIUS - dist) / MOUSE_RADIUS * 0.6
 p.x += (dx / dist) * force
 p.y += (dy / dist) * force
      }
    }
    // Connection lines
    for (let i = 0; i < particles.length; i++) {
      for (let j = i + 1; j < particles.length; j++) {
 const dx = particles[i].x - particles[j].x
 const dy = particles[i].y - particles[j].y
 const dist = Math.hypot(dx, dy)
 if (dist < MAX_DISTANCE) {
   const alpha = (1 - dist / MAX_DISTANCE) * 0.22
   ctx.strokeStyle = `rgba(47,109,255,${alpha})`
   ctx.lineWidth = 0.7
   ctx.beginPath()
   ctx.moveTo(particles[i].x, particles[i].y)
   ctx.lineTo(particles[j].x, particles[j].y)
   ctx.stroke()
 }
      }
      // Mouse connections
      const mdx = particles[i].x - mouse.x
      const mdy = particles[i].y - mouse.y
      const mdist = Math.hypot(mdx, mdy)
      if (mdist < MOUSE_RADIUS) {
 const alpha = (1 - mdist / MOUSE_RADIUS) * 0.35
 ctx.strokeStyle = `rgba(55,214,255,${alpha})`
 ctx.lineWidth = 0.8
 ctx.beginPath()
 ctx.moveTo(particles[i].x, particles[i].y)
 ctx.lineTo(mouse.x, mouse.y)
 ctx.stroke()
      }
    }
    // Particle dots
    for (const p of particles) {
      ctx.beginPath()
      ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2)
      ctx.fillStyle = 'rgba(47,109,255,0.45)'
      ctx.fill()
    }
    rafId = requestAnimationFrame(draw)
  }
  draw()

  return () => {
    if (rafId) cancelAnimationFrame(rafId)
    ro.disconnect()
    window.removeEventListener('resize', resize)
    window.removeEventListener('mousemove', onMouseMove)
    window.removeEventListener('mouseout', onMouseLeave)
  }
}

function getHomePathForUser() {
  if (auth.tenantType === 'pharmacy') return '/pharmacy'
  if (auth.tenantType === 'lab') return '/lab'
  if (auth.tenantType === 'radiology_center') return '/radiology'
  if (auth.tenantType === 'hospital') return '/hos'
  if (auth.tenantType === 'clinic') return '/clinics'
  if (auth.tenantType === 'inventory') return '/ims'
  return '/dashboard'
}
</script>

<style scoped>
/* ══════════════════════════════════════════════════════════
   Design tokens
   ══════════════════════════════════════════════════════════ */
.cc-page {
  --cc-bg: #eef2f9;
  --cc-surface: #ffffff;
  --cc-surface-2: #f6f8fd;
  --cc-glass: rgba(255, 255, 255, 0.72);
  --cc-line: rgba(15, 23, 42, 0.08);
  --cc-line-2: rgba(15, 23, 42, 0.14);
  --cc-ink: #0a0f1f;
  --cc-ink-2: #334155;
  --cc-muted: #64748b;
  --cc-primary: #2f6dff;
  --cc-primary-deep: #143ce1;
  --cc-cyan: #37d6ff;
  --cc-shadow-1: 0 1px 2px rgba(15, 23, 42, 0.04), 0 14px 30px -20px rgba(15, 23, 42, 0.30);
  --cc-shadow-2: 0 28px 60px -28px rgba(15, 23, 42, 0.42);
  --cc-radius: 20px;

  min-height: 100vh;
  position: relative;
  overflow-x: hidden;
  background: var(--cc-bg);
  color: var(--cc-ink);
  font-feature-settings: 'tnum' 1;
  -webkit-font-smoothing: antialiased;
}
:global(.v-theme--dark .cc-page) {
  --cc-bg: #070c1a;
  --cc-surface: #0f172b;
  --cc-surface-2: #131d34;
  --cc-glass: rgba(15, 23, 43, 0.66);
  --cc-line: rgba(148, 163, 184, 0.14);
  --cc-line-2: rgba(148, 163, 184, 0.24);
  --cc-ink: #eef2ff;
  --cc-ink-2: #cbd5e1;
  --cc-muted: #93a3bb;
  --cc-shadow-1: 0 1px 2px rgba(0, 0, 0, 0.45), 0 16px 34px -22px rgba(0, 0, 0, 0.9);
  --cc-shadow-2: 0 30px 70px -30px rgba(0, 0, 0, 0.95);
}

/* ══ Ambient background ══ */
.cc-ambient {
  position: fixed;
  inset: 0;
  z-index: 0;
  pointer-events: none;
  overflow: hidden;
}
.cc-orb {
  position: absolute;
  border-radius: 50%;
  filter: blur(90px);
  opacity: 0.55;
}
.cc-orb--1 {
  top: -240px; right: -150px; width: 580px; height: 580px;
  background: radial-gradient(circle, rgba(47, 109, 255, 0.55), transparent 65%);
  animation: cc-drift-a 22s ease-in-out infinite;
}
.cc-orb--2 {
  top: 32%; left: -240px; width: 540px; height: 540px;
  background: radial-gradient(circle, rgba(55, 214, 255, 0.42), transparent 65%);
  animation: cc-drift-b 28s ease-in-out infinite;
}
.cc-orb--3 {
  bottom: -280px; right: 16%; width: 640px; height: 640px;
  background: radial-gradient(circle, rgba(20, 60, 225, 0.30), transparent 65%);
  animation: cc-drift-a 34s ease-in-out infinite reverse;
}
.cc-gridlines {
  position: absolute;
  inset: 0;
  background-image:
    linear-gradient(rgba(15, 23, 42, 0.055) 1px, transparent 1px),
    linear-gradient(90deg, rgba(15, 23, 42, 0.055) 1px, transparent 1px);
  background-size: 64px 64px;
  mask-image: radial-gradient(circle at 50% 0%, #000 0%, transparent 72%);
  -webkit-mask-image: radial-gradient(circle at 50% 0%, #000 0%, transparent 72%);
}
:global(.v-theme--dark .cc-gridlines) {
  background-image:
    linear-gradient(rgba(148, 163, 184, 0.10) 1px, transparent 1px),
    linear-gradient(90deg, rgba(148, 163, 184, 0.10) 1px, transparent 1px);
}
.cc-vignette {
  position: absolute;
  inset: 0;
  background: radial-gradient(120% 80% at 50% 0%, transparent 42%, rgba(15, 23, 42, 0.07) 100%);
}
:global(.v-theme--dark .cc-vignette) {
  background: radial-gradient(120% 80% at 50% 0%, transparent 36%, rgba(0, 0, 0, 0.62) 100%);
}
.cc-particles {
  position: fixed;
  inset: 0;
  width: 100%;
  height: 100%;
  pointer-events: none;
  z-index: 0;
  opacity: 0.45;
}
@keyframes cc-drift-a {
  0%, 100% { transform: translate3d(0, 0, 0) scale(1); }
  50%      { transform: translate3d(-40px, 50px, 0) scale(1.08); }
}
@keyframes cc-drift-b {
  0%, 100% { transform: translate3d(0, 0, 0) scale(1); }
  50%      { transform: translate3d(50px, -40px, 0) scale(1.12); }
}

/* ══ Shell ══ */
.cc-shell {
  position: relative;
  z-index: 1;
  width: 100%;
  max-width: none;
  margin: 0 auto;
  padding: 18px 16px 64px;
}
@media (min-width: 960px) {
  .cc-shell { padding: 24px clamp(20px, 1.6vw, 40px) 80px; }
}

/* ══ Top bar ══ */
.cc-topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
  flex-wrap: wrap;
  padding: 10px 12px 10px 14px;
  border-radius: 18px;
  background: var(--cc-glass);
  border: 1px solid var(--cc-line);
  box-shadow: var(--cc-shadow-1);
  backdrop-filter: blur(18px) saturate(150%);
  -webkit-backdrop-filter: blur(18px) saturate(150%);
}
.cc-brand {
  display: flex;
  align-items: center;
  gap: 12px;
  min-width: 0;
}
.cc-brand__logo {
  width: 44px;
  height: 44px;
  border-radius: 13px;
  overflow: hidden;
  flex-shrink: 0;
  display: grid;
  place-items: center;
  background: linear-gradient(140deg, var(--cc-primary), var(--cc-primary-deep));
  box-shadow: 0 10px 22px -12px rgba(47, 109, 255, 0.85);
}
.cc-brand__logo img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.cc-brand__text {
  display: flex;
  flex-direction: column;
  min-width: 0;
  line-height: 1.25;
}
.cc-brand__eyebrow {
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--cc-muted);
}
.cc-brand__name {
  font-size: 0.95rem;
  font-weight: 700;
  color: var(--cc-ink);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 42vw;
}
.cc-live {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  margin-left: 4px;
  padding: 5px 11px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.02em;
  border: 1px solid transparent;
}
.cc-live--on {
  color: #0f9d58;
  background: rgba(16, 185, 129, 0.12);
  border-color: rgba(16, 185, 129, 0.28);
}
.cc-live--off {
  color: var(--cc-muted);
  background: rgba(148, 163, 184, 0.14);
  border-color: var(--cc-line);
}
.cc-live__dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: currentColor;
  box-shadow: 0 0 0 0 currentColor;
}
.cc-live--on .cc-live__dot {
  animation: cc-blink 1.9s ease-in-out infinite;
}
@keyframes cc-blink {
  0%, 100% { opacity: 1; }
  50%      { opacity: 0.25; }
}

.cc-topbar__actions {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-left: auto;
}
.cc-clock {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  line-height: 1.15;
  padding-right: 6px;
}
.cc-clock__time {
  font-size: 1rem;
  font-weight: 700;
  letter-spacing: -0.01em;
  color: var(--cc-ink);
  font-variant-numeric: tabular-nums;
}
.cc-clock__date {
  font-size: 11px;
  font-weight: 600;
  color: var(--cc-muted);
  white-space: nowrap;
}
.cc-icon-btn {
  width: 38px;
  height: 38px;
  display: grid;
  place-items: center;
  border-radius: 11px;
  border: 1px solid var(--cc-line);
  background: var(--cc-surface);
  color: var(--cc-ink-2);
  cursor: pointer;
  transition: transform 0.2s, border-color 0.2s, color 0.2s, box-shadow 0.2s;
}
.cc-icon-btn:hover {
  color: var(--cc-primary);
  border-color: rgba(47, 109, 255, 0.35);
  box-shadow: 0 8px 18px -12px rgba(47, 109, 255, 0.8);
  transform: translateY(-1px);
}
.cc-icon-btn--spin :deep(.v-icon) {
  animation: cc-spin 1.1s linear infinite;
}
@keyframes cc-spin { to { transform: rotate(360deg); } }
.cc-icon-btn--live {
  color: #0f9d58;
  border-color: rgba(16, 185, 129, 0.34);
  background: rgba(16, 185, 129, 0.09);
}
.cc-icon-btn--live:hover { color: #0f9d58; border-color: rgba(16, 185, 129, 0.55); }
.cc-icon-btn--active {
  color: var(--cc-primary);
  border-color: rgba(47, 109, 255, 0.40);
  background: rgba(47, 109, 255, 0.10);
}

/* ── Search / command-palette trigger ── */
.cc-cmdk {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  height: 38px;
  padding: 0 8px 0 11px;
  border-radius: 11px;
  border: 1px solid var(--cc-line);
  background: var(--cc-surface);
  color: var(--cc-muted);
  cursor: pointer;
  transition: border-color 0.2s, box-shadow 0.2s, color 0.2s;
}
.cc-cmdk:hover {
  color: var(--cc-primary);
  border-color: rgba(47, 109, 255, 0.4);
  box-shadow: 0 8px 18px -14px rgba(47, 109, 255, 0.9);
}
.cc-cmdk__label {
  font-size: 12.5px;
  font-weight: 600;
}
.cc-kbd {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 20px;
  height: 20px;
  padding: 0 5px;
  border-radius: 5px;
  border: 1px solid var(--cc-line-2);
  background: var(--cc-surface-2);
  color: var(--cc-muted);
  font-family: inherit;
  font-size: 10px;
  font-weight: 700;
  line-height: 1;
}
.cc-topbar__rule {
  width: 1px;
  height: 26px;
  background: var(--cc-line-2);
}
.cc-user {
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 5px 10px 5px 5px;
  border-radius: 12px;
  border: 1px solid var(--cc-line);
  background: var(--cc-surface);
  cursor: pointer;
  transition: border-color 0.2s, box-shadow 0.2s;
}
.cc-user:hover {
  border-color: rgba(47, 109, 255, 0.35);
  box-shadow: 0 8px 18px -14px rgba(47, 109, 255, 0.9);
}
.cc-user__avatar {
  width: 30px;
  height: 30px;
  display: grid;
  place-items: center;
  border-radius: 9px;
  font-size: 12px;
  font-weight: 800;
  color: #fff;
  background: linear-gradient(140deg, var(--cc-primary), var(--cc-primary-deep));
}
.cc-user__meta {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  line-height: 1.2;
  max-width: 130px;
}
.cc-user__name {
  font-size: 12.5px;
  font-weight: 700;
  color: var(--cc-ink);
  max-width: 130px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.cc-user__role {
  font-size: 10.5px;
  color: var(--cc-muted);
}
.cc-user__caret { color: var(--cc-muted); }
.cc-user-menu { min-width: 200px; }

@media (max-width: 719px) {
  .cc-clock, .cc-user__meta, .cc-brand__eyebrow { display: none; }
  .cc-brand__name { max-width: 46vw; }
}

/* ══ Hero ══ */
.cc-hero {
  position: relative;
  overflow: hidden;
  margin-top: 18px;
  padding: 34px 38px 26px;
  border-radius: 28px;
  color: #fff;
  background:
    radial-gradient(720px 380px at 88% -30%, rgba(55, 214, 255, 0.34), transparent 62%),
    radial-gradient(620px 360px at 6% 130%, rgba(47, 109, 255, 0.55), transparent 62%),
    linear-gradient(135deg, #0a1029 0%, #111f52 52%, #143ce1 128%);
  box-shadow: 0 34px 70px -34px rgba(20, 60, 225, 0.65);
  animation: cc-rise 0.6s cubic-bezier(0.16, 1, 0.3, 1) both;
}
.cc-hero__main {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 32px;
}
.cc-hero__mesh {
  position: absolute;
  inset: 0;
  background-image:
    linear-gradient(rgba(255, 255, 255, 0.06) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255, 255, 255, 0.06) 1px, transparent 1px);
  background-size: 46px 46px;
  mask-image: radial-gradient(90% 120% at 20% 0%, #000 0%, transparent 75%);
  -webkit-mask-image: radial-gradient(90% 120% at 20% 0%, #000 0%, transparent 75%);
  pointer-events: none;
}
.cc-hero__sheen {
  position: absolute;
  top: -60%;
  left: -10%;
  width: 70%;
  height: 220%;
  transform: rotate(18deg);
  background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.10), transparent);
  pointer-events: none;
}
.cc-hero__body { position: relative; z-index: 1; min-width: 0; }
.cc-hero__eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: rgba(226, 238, 255, 0.72);
}
.cc-hero__eyebrow-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--cc-cyan);
  box-shadow: 0 0 0 4px rgba(55, 214, 255, 0.18);
}
.cc-hero__title {
  margin: 10px 0 6px;
  font-size: clamp(2rem, 4.2vw, 3rem);
  font-weight: 800;
  letter-spacing: -0.035em;
  line-height: 1.04;
}
/* Solid accent is the fallback; the gradient-text layer is opt-in via
   @supports so unsupported engines still paint a visible word. */
.cc-hero__accent {
  color: #6fd4ff;
}
@supports ((-webkit-background-clip: text) or (background-clip: text)) {
  .cc-hero__accent {
    background: linear-gradient(100deg, #7fb3ff 0%, #37d6ff 60%, #b6ecff 100%);
    -webkit-background-clip: text;
    background-clip: text;
    -webkit-text-fill-color: transparent;
  }
}
.cc-hero__sub {
  margin: 0;
  max-width: 48ch;
  font-size: 0.95rem;
  line-height: 1.55;
  color: rgba(226, 238, 255, 0.74);
}
.cc-hero__chips {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 22px;
}
.cc-hero__chip {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  padding: 7px 13px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 600;
  color: rgba(240, 247, 255, 0.92);
  background: rgba(255, 255, 255, 0.09);
  border: 1px solid rgba(255, 255, 255, 0.16);
  backdrop-filter: blur(6px);
  -webkit-backdrop-filter: blur(6px);
}
.cc-hero__chip--ok {
  color: #b7f7dc;
  background: rgba(16, 185, 129, 0.16);
  border-color: rgba(16, 185, 129, 0.32);
}
.cc-hero__chip--muted {
  color: rgba(226, 238, 255, 0.62);
  background: rgba(255, 255, 255, 0.05);
  border-color: rgba(255, 255, 255, 0.10);
}

/* ── Hero trend strip ── */
.cc-hero__strip {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: center;
  gap: 30px;
  margin-top: 28px;
  padding-top: 20px;
  border-top: 1px solid rgba(255, 255, 255, 0.13);
}
.cc-hero__metric {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}
.cc-hero__metric-label {
  font-size: 9.5px;
  font-weight: 700;
  letter-spacing: 0.13em;
  text-transform: uppercase;
  color: rgba(226, 238, 255, 0.52);
}
.cc-hero__metric-value {
  font-size: 1.35rem;
  font-weight: 800;
  letter-spacing: -0.03em;
  line-height: 1.2;
  font-variant-numeric: tabular-nums;
}
.cc-hero__metric-delta {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  font-size: 11px;
  font-weight: 700;
}
.cc-hero__metric-sub {
  font-size: 10.5px;
  font-weight: 500;
  color: rgba(226, 238, 255, 0.5);
}
.cc-hero__spark {
  flex: 1 1 auto;
  min-width: 120px;
  max-width: 620px;
  margin-left: auto;
  color: rgba(226, 238, 255, 0.5);
  opacity: 0.9;
}
.cc-up { color: #6ee7b7; }
.cc-down { color: #fca5a5; }
.cc-hero__spark :deep(.v-icon) { color: inherit; }

/* ── Network pulse gauge ── */
.cc-pulse {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 14px;
  flex-shrink: 0;
}
.cc-pulse__ring {
  --pct: 0;
  width: 148px;
  height: 148px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  background: conic-gradient(
    from -90deg,
    #37d6ff 0deg,
    #2f6dff calc(var(--pct) * 3.6deg),
    rgba(255, 255, 255, 0.14) calc(var(--pct) * 3.6deg)
  );
  box-shadow: 0 0 42px -12px rgba(55, 214, 255, 0.55);
}
.cc-pulse__core {
  width: 118px;
  height: 118px;
  border-radius: 50%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 1px;
  background: radial-gradient(circle at 50% 30%, #16255e, #0a1029 75%);
  border: 1px solid rgba(255, 255, 255, 0.10);
}
.cc-pulse__value {
  font-size: 1.9rem;
  font-weight: 800;
  letter-spacing: -0.04em;
  line-height: 1;
  font-variant-numeric: tabular-nums;
}
.cc-pulse__value small {
  font-size: 0.85rem;
  font-weight: 700;
  margin-left: 1px;
  color: rgba(226, 238, 255, 0.7);
}
.cc-pulse__label {
  font-size: 9.5px;
  font-weight: 700;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: rgba(226, 238, 255, 0.6);
}
.cc-pulse__legend {
  display: flex;
  gap: 14px;
  font-size: 11.5px;
  font-weight: 600;
  color: rgba(226, 238, 255, 0.78);
}
.cc-pulse__legend span {
  display: inline-flex;
  align-items: center;
  gap: 6px;
}
.cc-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  display: inline-block;
}
.cc-dot--on  { background: #34d399; }
.cc-dot--off { background: rgba(226, 238, 255, 0.35); }

/* ══ KPI grid ══ */
.cc-kpis {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 14px;
  margin-top: 18px;
}
@media (min-width: 720px) {
  .cc-kpis { grid-template-columns: repeat(3, minmax(0, 1fr)); }
}
@media (min-width: 1180px) {
  .cc-kpis { grid-template-columns: repeat(6, minmax(0, 1fr)); }
}
@media (min-width: 1900px) {
  .cc-kpis { grid-template-columns: repeat(6, minmax(0, 1fr)); }
  .cc-kpi__value { font-size: 1.8rem; }
}
.cc-kpi {
  --accent: #2f6dff;
  --accent-soft: rgba(47, 109, 255, 0.12);
  position: relative;
  overflow: hidden;
  padding: 16px 16px 18px;
  border-radius: 18px;
  background: var(--cc-surface);
  border: 1px solid var(--cc-line);
  box-shadow: var(--cc-shadow-1);
  transition: transform 0.3s cubic-bezier(0.16, 1, 0.3, 1), box-shadow 0.3s, border-color 0.3s;
  animation: cc-rise 0.5s cubic-bezier(0.16, 1, 0.3, 1) both;
  animation-delay: calc(var(--i, 0) * 55ms);
}
.cc-kpi::before {
  content: '';
  position: absolute;
  top: -60px;
  right: -50px;
  width: 140px;
  height: 140px;
  border-radius: 50%;
  background: var(--accent-soft);
  filter: blur(26px);
  opacity: 0.7;
  transition: opacity 0.3s, transform 0.4s;
  pointer-events: none;
}
.cc-kpi:hover {
  transform: translateY(-3px);
  box-shadow: var(--cc-shadow-2);
  border-color: var(--accent-soft);
}
.cc-kpi:hover::before { opacity: 1; transform: scale(1.12); }
.cc-kpi__head {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 14px;
}
.cc-kpi__icon {
  width: 34px;
  height: 34px;
  display: grid;
  place-items: center;
  border-radius: 10px;
  color: var(--accent);
  background: var(--accent-soft);
}
.cc-kpi__idx {
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.12em;
  color: var(--cc-muted);
  opacity: 0.65;
}
.cc-kpi__value {
  position: relative;
  z-index: 1;
  font-size: 1.62rem;
  font-weight: 800;
  letter-spacing: -0.035em;
  line-height: 1.1;
  color: var(--cc-ink);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.cc-kpi__label {
  position: relative;
  z-index: 1;
  margin-top: 4px;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--cc-muted);
}
.cc-kpi__bar {
  position: absolute;
  left: 16px;
  right: 16px;
  bottom: 0;
  height: 2px;
  border-radius: 2px 2px 0 0;
  background: var(--accent);
  transform: scaleX(0);
  transform-origin: left;
  transition: transform 0.35s cubic-bezier(0.16, 1, 0.3, 1);
}
.cc-kpi:hover .cc-kpi__bar { transform: scaleX(1); }

@keyframes cc-rise {
  from { opacity: 0; transform: translateY(14px); }
  to   { opacity: 1; transform: translateY(0); }
}

/* ══ Attention strip ══ */
.cc-insights {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
  margin-top: 18px;
}
@media (min-width: 900px) {
  .cc-insights { grid-template-columns: repeat(4, minmax(0, 1fr)); }
}
.cc-insight {
  --tone: #64748b;
  --tone-soft: rgba(100, 116, 139, 0.12);
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 13px 14px;
  border-radius: 16px;
  border: 1px solid var(--cc-line);
  background: var(--cc-surface);
  box-shadow: var(--cc-shadow-1);
  text-align: left;
  cursor: pointer;
  transition: transform 0.25s cubic-bezier(0.16, 1, 0.3, 1), border-color 0.25s, box-shadow 0.25s;
}
.cc-insight:disabled { cursor: default; }
.cc-insight:not(:disabled):hover {
  transform: translateY(-2px);
  border-color: var(--tone-soft);
  box-shadow: var(--cc-shadow-2);
}
.cc-insight--ok { --tone: #10b981; --tone-soft: rgba(16, 185, 129, 0.20); }
.cc-insight--warn { --tone: #d97706; --tone-soft: rgba(245, 158, 11, 0.24); }
.cc-insight--danger { --tone: #e11d48; --tone-soft: rgba(225, 29, 72, 0.20); }
.cc-insight--on {
  border-color: var(--tone);
  box-shadow: 0 0 0 3px var(--tone-soft);
}
.cc-insight__icon {
  width: 34px;
  height: 34px;
  flex-shrink: 0;
  display: grid;
  place-items: center;
  border-radius: 10px;
  color: var(--tone);
  background: var(--tone-soft);
}
.cc-insight__body {
  display: flex;
  flex-direction: column;
  gap: 1px;
  min-width: 0;
}
.cc-insight__value {
  font-size: 1.05rem;
  font-weight: 800;
  letter-spacing: -0.02em;
  line-height: 1.15;
  color: var(--cc-ink);
  font-variant-numeric: tabular-nums;
}
.cc-insight__label {
  font-size: 11px;
  font-weight: 600;
  color: var(--cc-muted);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.cc-insight__arrow {
  margin-left: auto;
  color: var(--cc-muted);
  opacity: 0.6;
}
.cc-insight--on .cc-insight__arrow { color: var(--tone); opacity: 1; }

/* ══ Trend + feed panels ══ */
.cc-split {
  display: grid;
  grid-template-columns: minmax(0, 1.55fr) minmax(0, 1fr);
  gap: 16px;
  margin-top: 18px;
  align-items: stretch;
}
@media (min-width: 1700px) {
  .cc-split { grid-template-columns: minmax(0, 1.9fr) minmax(0, 1fr); }
  .cc-feed { max-height: 330px; }
}
@media (max-width: 1023px) {
  .cc-split { grid-template-columns: minmax(0, 1fr); }
}
.cc-panel {
  display: flex;
  flex-direction: column;
  padding: 20px 22px;
  border-radius: var(--cc-radius);
  background: var(--cc-surface);
  border: 1px solid var(--cc-line);
  box-shadow: var(--cc-shadow-1);
}
.cc-panel--feed { padding-bottom: 10px; }
.cc-panel__head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 14px;
  margin-bottom: 14px;
}
.cc-panel__title {
  margin: 0;
  font-size: 1rem;
  font-weight: 750;
  letter-spacing: -0.015em;
  color: var(--cc-ink);
}
.cc-panel__hint {
  margin: 3px 0 0;
  font-size: 12px;
  color: var(--cc-muted);
}
.cc-panel__count {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 26px;
  height: 24px;
  padding: 0 8px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 800;
  color: var(--cc-primary);
  background: rgba(47, 109, 255, 0.10);
}
.cc-panel__figure {
  display: flex;
  align-items: baseline;
  gap: 10px;
  flex-wrap: wrap;
  margin-bottom: 8px;
}
.cc-panel__big {
  font-size: 2rem;
  font-weight: 800;
  letter-spacing: -0.04em;
  line-height: 1.1;
  color: var(--cc-ink);
  font-variant-numeric: tabular-nums;
}
.cc-delta {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  padding: 3px 8px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 800;
  background: transparent;
}
.cc-delta.cc-up { color: #047857; background: rgba(16, 185, 129, 0.14); }
.cc-delta.cc-down { color: #b91c1c; background: rgba(239, 68, 68, 0.13); }
.cc-panel__vs {
  font-size: 11.5px;
  font-weight: 500;
  color: var(--cc-muted);
}
.cc-chart {
  flex: 1 1 auto;
  margin: 4px -6px 6px;
  color: var(--cc-muted);
  min-height: 168px;
}
.cc-panel__foot {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding-top: 12px;
  margin-top: auto;
  border-top: 1px solid var(--cc-line);
}
.cc-seg {
  display: inline-flex;
  padding: 3px;
  border-radius: 10px;
  background: var(--cc-surface-2);
  border: 1px solid var(--cc-line);
}
.cc-seg__btn {
  border: 0;
  background: transparent;
  color: var(--cc-muted);
  font-size: 11.5px;
  font-weight: 700;
  padding: 4px 10px;
  border-radius: 7px;
  cursor: pointer;
  transition: background 0.2s, color 0.2s;
}
.cc-seg__btn--on {
  color: var(--cc-primary);
  background: var(--cc-surface);
  box-shadow: 0 2px 6px -2px rgba(15, 23, 42, 0.2);
}
.cc-tabs {
  display: inline-flex;
  gap: 4px;
}
.cc-tabs__btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  border: 1px solid transparent;
  background: transparent;
  color: var(--cc-muted);
  font-size: 12px;
  font-weight: 650;
  padding: 6px 11px;
  border-radius: 9px;
  cursor: pointer;
  transition: all 0.2s;
}
.cc-tabs__btn:hover:not(:disabled) { color: var(--cc-primary); background: rgba(47, 109, 255, 0.07); }
.cc-tabs__btn--on {
  color: var(--cc-primary);
  background: rgba(47, 109, 255, 0.10);
  border-color: rgba(47, 109, 255, 0.22);
}
.cc-tabs__btn:disabled { opacity: 0.45; cursor: not-allowed; }
.cc-panel__stamp {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 11px;
  font-weight: 650;
  color: var(--cc-muted);
  font-variant-numeric: tabular-nums;
}
.cc-panel__stamp-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #10b981;
  animation: cc-blink 2s ease-in-out infinite;
}

/* ── Live feed ── */
.cc-feed {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 2px;
  overflow-y: auto;
  max-height: 306px;
}
.cc-feed__item {
  display: flex;
  gap: 11px;
  padding: 10px 4px;
  border-bottom: 1px solid var(--cc-line);
}
.cc-feed__item:last-child { border-bottom: 0; }
.cc-feed__dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  margin-top: 6px;
  flex-shrink: 0;
  background: #94a3b8;
}
.cc-feed__dot--info { background: #2f6dff; }
.cc-feed__dot--notice { background: #0ea5e9; }
.cc-feed__dot--warning { background: #f59e0b; }
.cc-feed__dot--critical {
  background: #ef4444;
  box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.16);
}
.cc-feed__body { min-width: 0; }
.cc-feed__text {
  margin: 0;
  font-size: 12.5px;
  font-weight: 600;
  line-height: 1.35;
  color: var(--cc-ink);
  overflow: hidden;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}
.cc-feed__meta {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 4px 10px;
  margin-top: 4px;
  font-size: 10.5px;
  color: var(--cc-muted);
}
.cc-feed__tenant {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-weight: 700;
  color: var(--cc-ink-2);
}
.cc-feed__actor {
  max-width: 150px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.cc-feed__time { margin-left: auto; font-variant-numeric: tabular-nums; }
.cc-feed__empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  padding: 34px 0;
  color: var(--cc-muted);
  font-size: 12.5px;
}

/* ══ Facilities section ══ */
.cc-facilities { margin-top: 34px; }
.cc-facilities__head {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 18px;
  flex-wrap: wrap;
  margin-bottom: 18px;
}
.cc-facilities__title {
  margin: 0;
  font-size: 1.22rem;
  font-weight: 800;
  letter-spacing: -0.02em;
  color: var(--cc-ink);
}
.cc-facilities__hint {
  margin: 4px 0 0;
  font-size: 12.5px;
  color: var(--cc-muted);
}
.cc-facilities__tools {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
}

/* ── Search ── */
.cc-search {
  display: flex;
  align-items: center;
  gap: 8px;
  height: 38px;
  padding: 0 11px;
  border-radius: 11px;
  background: var(--cc-surface);
  border: 1px solid var(--cc-line);
  transition: border-color 0.2s, box-shadow 0.2s;
}
.cc-search:focus-within {
  border-color: rgba(47, 109, 255, 0.45);
  box-shadow: 0 0 0 4px rgba(47, 109, 255, 0.10);
}
.cc-search__icon { color: var(--cc-muted); }
.cc-search__input {
  width: 190px;
  border: 0;
  outline: 0;
  background: transparent;
  font-size: 13px;
  color: var(--cc-ink);
}
.cc-search__input::placeholder { color: var(--cc-muted); }
.cc-search__clear {
  display: grid;
  place-items: center;
  border: 0;
  background: transparent;
  color: var(--cc-muted);
  cursor: pointer;
  padding: 0;
}

/* ── Sort select ── */
.cc-sort {
  position: relative;
  display: inline-flex;
  align-items: center;
  gap: 7px;
  height: 38px;
  padding: 0 9px 0 11px;
  border-radius: 11px;
  background: var(--cc-surface);
  border: 1px solid var(--cc-line);
  transition: border-color 0.2s, box-shadow 0.2s;
}
.cc-sort:focus-within {
  border-color: rgba(47, 109, 255, 0.45);
  box-shadow: 0 0 0 4px rgba(47, 109, 255, 0.10);
}
.cc-sort__icon { color: var(--cc-muted); flex-shrink: 0; }
.cc-sort__select {
  appearance: none;
  -webkit-appearance: none;
  border: 0;
  outline: 0;
  background: transparent;
  padding: 0 18px 0 0;
  font-family: inherit;
  font-size: 12.5px;
  font-weight: 650;
  color: var(--cc-ink-2);
  cursor: pointer;
}
.cc-sort__caret {
  position: absolute;
  right: 8px;
  color: var(--cc-muted);
  pointer-events: none;
}

/* ── Type filter chips ── */
.cc-filters {
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
}
.cc-filter {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  height: 38px;
  padding: 0 12px;
  border-radius: 11px;
  border: 1px solid var(--cc-line);
  background: var(--cc-surface);
  color: var(--cc-ink-2);
  font-size: 12px;
  font-weight: 650;
  cursor: pointer;
  transition: all 0.2s;
}
.cc-filter:hover { border-color: rgba(47, 109, 255, 0.4); color: var(--cc-primary); }
.cc-filter--active {
  color: #fff;
  background: linear-gradient(135deg, var(--cc-primary), var(--cc-primary-deep));
  border-color: transparent;
  box-shadow: 0 10px 22px -14px rgba(47, 109, 255, 0.95);
}
.cc-filter--active:hover { color: #fff; }
.cc-filter__count {
  font-size: 10.5px;
  font-weight: 800;
  padding: 1px 6px;
  border-radius: 999px;
  background: rgba(148, 163, 184, 0.18);
  color: inherit;
}
.cc-filter--active .cc-filter__count { background: rgba(255, 255, 255, 0.22); }

/* ── Empty state ── */
.cc-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 4px;
  padding: 56px 24px;
  border-radius: var(--cc-radius);
  border: 1px dashed var(--cc-line-2);
  background: var(--cc-surface);
  text-align: center;
}
.cc-empty__glyph {
  width: 54px;
  height: 54px;
  display: grid;
  place-items: center;
  border-radius: 16px;
  color: var(--cc-primary);
  background: rgba(47, 109, 255, 0.10);
  margin-bottom: 8px;
}
.cc-empty__title { margin: 0; font-size: 0.95rem; font-weight: 700; color: var(--cc-ink); }
.cc-empty__hint { margin: 0 0 12px; font-size: 12.5px; color: var(--cc-muted); }
.cc-empty__reset {
  border: 1px solid rgba(47, 109, 255, 0.35);
  background: rgba(47, 109, 255, 0.08);
  color: var(--cc-primary);
  font-size: 12px;
  font-weight: 700;
  padding: 7px 14px;
  border-radius: 10px;
  cursor: pointer;
  transition: background 0.2s;
}
.cc-empty__reset:hover { background: rgba(47, 109, 255, 0.16); }

/* ══ Facility cards ══ */
.cc-cards {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(258px, 1fr));
  gap: 16px;
}
@media (min-width: 1700px) {
  .cc-cards { grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 18px; }
}
@media (min-width: 2200px) {
  .cc-cards { grid-template-columns: repeat(auto-fill, minmax(340px, 1fr)); }
}
.cc-card {
  --accent: #2f6dff;
  --accent-soft: rgba(47, 109, 255, 0.14);
  position: relative;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  padding: 18px;
  border-radius: var(--cc-radius);
  background: var(--cc-surface);
  border: 1px solid var(--cc-line);
  box-shadow: var(--cc-shadow-1);
  cursor: pointer;
  outline: none;
  transition: transform 0.32s cubic-bezier(0.16, 1, 0.3, 1), box-shadow 0.32s, border-color 0.32s;
  animation: cc-rise 0.5s cubic-bezier(0.16, 1, 0.3, 1) both;
  animation-delay: calc(var(--i, 0) * 45ms);
}
.cc-card::before {
  content: '';
  position: absolute;
  top: -70px;
  left: -40px;
  width: 190px;
  height: 190px;
  border-radius: 50%;
  background: var(--accent-soft);
  filter: blur(34px);
  opacity: 0;
  transition: opacity 0.4s, transform 0.6s;
  pointer-events: none;
}
.cc-card:hover,
.cc-card:focus-visible {
  transform: translateY(-5px);
  box-shadow: var(--cc-shadow-2);
  border-color: var(--accent-soft);
}
.cc-card:hover::before,
.cc-card:focus-visible::before { opacity: 1; transform: scale(1.15); }
.cc-card--off {
  opacity: 0.58;
  cursor: not-allowed;
}
.cc-card--off:hover {
  transform: none;
  box-shadow: var(--cc-shadow-1);
  border-color: var(--cc-line);
}
.cc-card--off:hover::before { opacity: 0; }
.cc-card__rail {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 3px;
  background: linear-gradient(90deg, var(--accent), transparent 72%);
  opacity: 0.75;
  transition: opacity 0.3s, height 0.3s;
}
.cc-card:hover .cc-card__rail { opacity: 1; height: 4px; }
.cc-card__head {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 10px;
  margin-bottom: 14px;
}
.cc-card__glyph {
  width: 46px;
  height: 46px;
  display: grid;
  place-items: center;
  border-radius: 14px;
  color: var(--accent);
  background: var(--accent-soft);
  border: 1px solid var(--accent-soft);
  transition: transform 0.35s cubic-bezier(0.16, 1, 0.3, 1);
}
.cc-card:hover .cc-card__glyph { transform: scale(1.06) rotate(-3deg); }
.cc-card__state {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 4px 9px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.03em;
  border: 1px solid transparent;
  white-space: nowrap;
}
.cc-card__state i {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: currentColor;
}
.cc-card__state--on {
  color: #0f9d58;
  background: rgba(16, 185, 129, 0.11);
  border-color: rgba(16, 185, 129, 0.26);
}
.cc-card__state--on i { animation: cc-blink 2s ease-in-out infinite; }
.cc-card__state--off {
  color: var(--cc-muted);
  background: rgba(148, 163, 184, 0.14);
  border-color: var(--cc-line);
}
.cc-card__name {
  position: relative;
  z-index: 1;
  margin: 0;
  font-size: 1rem;
  font-weight: 750;
  letter-spacing: -0.015em;
  line-height: 1.3;
  color: var(--cc-ink);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.cc-card__type {
  position: relative;
  z-index: 1;
  margin-top: 3px;
  font-size: 11.5px;
  font-weight: 600;
  color: var(--accent);
}
.cc-card__stats {
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 1px;
  margin: 16px 0 0;
  border-radius: 12px;
  overflow: hidden;
  background: var(--cc-line);
  border: 1px solid var(--cc-line);
}
.cc-stat {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 9px 11px;
  background: var(--cc-surface-2);
}
/* Odd number of metrics: let the last one fill the row instead of leaving a gap */
.cc-stat--wide { grid-column: 1 / -1; }
.cc-stat__label {
  font-size: 9.5px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--cc-muted);
}
.cc-stat__value {
  font-size: 0.9rem;
  font-weight: 750;
  color: var(--cc-ink);
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.cc-stat__value--warn { color: #ef4444; }
.cc-card__foot {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  margin-top: auto;
  padding-top: 14px;
}
.cc-card__cta {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 12.5px;
  font-weight: 750;
  color: var(--accent);
}
.cc-card__cta :deep(.v-icon) {
  transition: transform 0.25s cubic-bezier(0.16, 1, 0.3, 1);
}
.cc-card:hover .cc-card__cta :deep(.v-icon) { transform: translateX(4px); }
.cc-card__flag {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 10.5px;
  font-weight: 700;
  color: #d97706;
  background: rgba(245, 158, 11, 0.13);
  border-radius: 999px;
  padding: 3px 8px;
}

/* ── Per-card activity sparkline ── */
.cc-card__spark {
  position: relative;
  z-index: 1;
  margin-top: 12px;
  padding-top: 10px;
  border-top: 1px dashed var(--cc-line);
  color: var(--cc-muted);
}
.cc-card__spark-label {
  display: block;
  margin-bottom: 2px;
  font-size: 9.5px;
  font-weight: 700;
  letter-spacing: 0.07em;
  text-transform: uppercase;
  color: var(--cc-muted);
}
.cc-card__time {
  font-size: 10.5px;
  font-weight: 600;
  color: var(--cc-muted);
  font-variant-numeric: tabular-nums;
}

/* ══ Facility traffic monitor ══════════════════════════════════════════
   The bottom-of-page telemetry block. A little denser than the facility
   cards above it on purpose: this is a monitor, read top-down, not a
   navigation surface. */
.cc-traffic {
  margin-top: 34px;
  padding: 20px 22px 18px;
  border-radius: 20px;
  border: 1px solid var(--cc-line);
  background: var(--cc-surface);
  box-shadow: 0 20px 44px -34px rgba(2, 6, 23, 0.4);
}
.cc-traffic__head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  flex-wrap: wrap;
}
.cc-traffic__intro { min-width: 0; }
.cc-traffic__title {
  display: flex;
  align-items: center;
  gap: 9px;
  margin: 0 0 4px;
  font-size: 1.02rem;
  font-weight: 800;
  letter-spacing: -0.4px;
  color: var(--cc-ink);
}
.cc-traffic__pip {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex: 0 0 auto;
  background: var(--cc-muted);
  opacity: 0.5;
}
.cc-traffic__pip.is-live {
  background: #10b981;
  opacity: 1;
  box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.55);
  animation: cc-traffic-pulse 2s ease-out infinite;
}
@keyframes cc-traffic-pulse {
  0% { box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.55); }
  70% { box-shadow: 0 0 0 8px rgba(16, 185, 129, 0); }
  100% { box-shadow: 0 0 0 0 rgba(16, 185, 129, 0); }
}
.cc-traffic__hint {
  margin: 0;
  font-size: 12.5px;
  color: var(--cc-muted);
}
.cc-traffic__tools { display: flex; align-items: center; gap: 12px; }
.cc-traffic__stamp {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  color: var(--cc-muted);
  font-variant-numeric: tabular-nums;
}
.cc-traffic__stamp-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--cc-muted);
  opacity: 0.5;
}
.cc-traffic__stamp.is-live .cc-traffic__stamp-dot { background: #10b981; opacity: 1; }

/* Summary strip */
.cc-traffic__summary {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr)) 1.5fr;
  align-items: center;
  gap: 14px;
  margin: 16px 0 4px;
  padding: 14px 16px;
  border-radius: 14px;
  border: 1px solid var(--cc-line);
  background: var(--cc-surface-2);
}
.cc-traffic__fig { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
.cc-traffic__fig--chart { color: var(--cc-muted); }
.cc-traffic__fig-label {
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--cc-muted);
}
.cc-traffic__fig-value {
  font-size: 1.22rem;
  font-weight: 800;
  letter-spacing: -0.7px;
  line-height: 1.15;
  color: var(--cc-ink);
  font-variant-numeric: tabular-nums;
}
.cc-traffic__fig-value em {
  margin-left: 2px;
  font-style: normal;
  font-size: 0.62rem;
  font-weight: 700;
  opacity: 0.5;
}
.cc-traffic__fig-delta,
.cc-traffic__fig-sub {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  font-size: 10.5px;
  font-weight: 650;
  color: var(--cc-muted);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.cc-traffic__fig-delta.is-up { color: #10b981; }
.cc-traffic__fig-delta.is-down { color: #ef4444; }

/* Per-facility rows */
.cc-traffic__rows {
  list-style: none;
  margin: 12px 0 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.cc-monitor {
  display: grid;
  grid-template-columns: minmax(140px, 1.5fr) 92px 92px 96px minmax(90px, 1.1fr) 116px;
  align-items: center;
  gap: 14px;
  padding: 11px 14px;
  border-radius: 13px;
  border: 1px solid var(--cc-line);
  border-left: 3px solid var(--accent);
  background: var(--cc-surface);
  transition: border-color 0.2s ease, box-shadow 0.2s ease, transform 0.2s ease;
}
.cc-monitor:hover {
  transform: translateY(-1px);
  border-color: var(--cc-line-2);
  box-shadow: 0 12px 26px -22px rgba(2, 6, 23, 0.55);
}
.cc-monitor--offline { opacity: 0.62; }
.cc-monitor--offline { border-left-color: var(--cc-muted); }

.cc-monitor__id { display: flex; align-items: center; gap: 9px; min-width: 0; }
.cc-monitor__glyph {
  display: grid;
  place-items: center;
  width: 30px;
  height: 30px;
  flex: 0 0 auto;
  border-radius: 9px;
  color: var(--accent);
  background: var(--accent-soft);
}
.cc-monitor__names { display: flex; flex-direction: column; min-width: 0; }
.cc-monitor__name {
  font-size: 12.5px;
  font-weight: 750;
  color: var(--cc-ink);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cc-monitor__type {
  font-size: 10.5px;
  font-weight: 600;
  color: var(--cc-muted);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.cc-monitor__state {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  justify-self: start;
  padding: 3px 8px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  white-space: nowrap;
  background: rgba(148, 163, 184, 0.18);
  color: var(--cc-muted);
}
.cc-monitor__state i {
  width: 5px;
  height: 5px;
  border-radius: 50%;
  background: currentColor;
}
.cc-monitor__state--live {
  background: rgba(16, 185, 129, 0.15);
  color: #10b981;
}
.cc-monitor__state--live i { animation: cc-traffic-pulse 2s ease-out infinite; }
.cc-monitor__state--idle { background: rgba(245, 158, 11, 0.15); color: #d97706; }
.cc-monitor__state--silent { background: rgba(148, 163, 184, 0.16); color: var(--cc-muted); }
.cc-monitor__state--off { background: rgba(239, 68, 68, 0.13); color: #ef4444; }

.cc-monitor__rate { display: flex; flex-direction: column; line-height: 1.15; }
.cc-monitor__rate-value {
  font-size: 0.94rem;
  font-weight: 800;
  letter-spacing: -0.4px;
  color: var(--cc-muted);
  font-variant-numeric: tabular-nums;
}
.cc-monitor__rate-value.is-flowing { color: var(--cc-ink); }
.cc-monitor__rate-unit {
  font-size: 9px;
  font-weight: 700;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  color: var(--cc-muted);
}

.cc-monitor__today { display: flex; flex-direction: column; line-height: 1.15; }
.cc-monitor__today-value {
  font-size: 0.94rem;
  font-weight: 800;
  letter-spacing: -0.4px;
  color: var(--cc-ink);
  font-variant-numeric: tabular-nums;
}
.cc-monitor__today-delta {
  font-size: 9.5px;
  font-weight: 750;
  font-variant-numeric: tabular-nums;
}
.cc-monitor__today-delta.is-up { color: #10b981; }
.cc-monitor__today-delta.is-down { color: #ef4444; }
.cc-monitor__today-delta.is-flat { color: var(--cc-muted); }

.cc-monitor__spark { color: var(--cc-muted); min-width: 0; }

.cc-monitor__share { display: flex; flex-direction: column; gap: 3px; }
.cc-monitor__share-bar {
  height: 5px;
  border-radius: 999px;
  overflow: hidden;
  background: rgba(148, 163, 184, 0.2);
}
.cc-monitor__share-bar span {
  display: block;
  height: 100%;
  border-radius: 999px;
  background: var(--accent);
  transition: width 0.4s cubic-bezier(0.16, 1, 0.3, 1);
}
.cc-monitor__share-label {
  font-size: 9.5px;
  font-weight: 650;
  color: var(--cc-muted);
  white-space: nowrap;
}

.cc-monitor__foot {
  grid-column: 1 / -1;
  display: flex;
  align-items: center;
  gap: 6px;
  padding-top: 7px;
  margin-top: -2px;
  border-top: 1px dashed var(--cc-line);
  font-size: 10px;
  font-weight: 600;
  color: var(--cc-muted);
  font-variant-numeric: tabular-nums;
}
.cc-monitor__dot { opacity: 0.45; }
.cc-monitor__seen { margin-left: auto; white-space: nowrap; }

/* States */
.cc-traffic__loading { display: flex; flex-direction: column; gap: 8px; margin-top: 12px; }
.cc-traffic__skeleton {
  height: 62px;
  border-radius: 13px;
  background: linear-gradient(90deg,
    rgba(148, 163, 184, 0.1) 25%,
    rgba(148, 163, 184, 0.18) 50%,
    rgba(148, 163, 184, 0.1) 75%);
  background-size: 200% 100%;
  animation: cc-traffic-shimmer 1.4s linear infinite;
}
@keyframes cc-traffic-shimmer {
  to { background-position: -200% 0; }
}
.cc-traffic__error,
.cc-traffic__empty {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  margin-top: 12px;
  padding: 26px 16px;
  border-radius: 13px;
  border: 1px dashed var(--cc-line-2);
  font-size: 12.5px;
  font-weight: 600;
  color: var(--cc-muted);
}
.cc-traffic__error { color: #ef4444; border-color: rgba(239, 68, 68, 0.35); }
.cc-traffic__retry {
  margin-left: 4px;
  border: 1px solid currentColor;
  background: transparent;
  color: inherit;
  font-size: 11px;
  font-weight: 750;
  padding: 3px 10px;
  border-radius: 999px;
  cursor: pointer;
}
.cc-traffic__foot {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
  margin-top: 14px;
  padding-top: 12px;
  border-top: 1px solid var(--cc-line);
  font-size: 10.5px;
  color: var(--cc-muted);
}
.cc-traffic__foot-stamp { font-weight: 700; white-space: nowrap; }

/* ══ Daily traffic trend chart ═════════════════════════════════════════ */
.cc-traffic__range {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 4px 10px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  color: var(--cc-muted);
  background: var(--cc-surface-2);
  border: 1px solid var(--cc-line);
  white-space: nowrap;
}

.cc-trend {
  margin-top: 16px;
  padding: 20px 22px 18px;
  border-radius: 20px;
  border: 1px solid var(--cc-line);
  background: var(--cc-surface);
  box-shadow: 0 20px 44px -34px rgba(2, 6, 23, 0.4);
}
.cc-trend__head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  flex-wrap: wrap;
}
.cc-trend__intro { min-width: 0; }
.cc-trend__title {
  margin: 0 0 4px;
  font-size: 1.02rem;
  font-weight: 800;
  letter-spacing: -0.4px;
  color: var(--cc-ink);
}
.cc-trend__hint {
  margin: 0;
  font-size: 12.5px;
  color: var(--cc-muted);
  font-variant-numeric: tabular-nums;
}
.cc-trend__filter {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
}
.cc-seg--sm .cc-seg__btn { padding: 3px 9px; font-size: 10.5px; }

/* ── Custom date pickers ── */
.cc-trend__dates {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 3px;
  border-radius: 11px;
  border: 1px dashed transparent;
  transition: border-color 0.2s ease, background-color 0.2s ease;
}
.cc-trend__dates.is-open {
  border-color: rgba(var(--v-theme-primary), 0.35);
  background: rgba(var(--v-theme-primary), 0.05);
}
.cc-date {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 2px 7px;
  border-radius: 8px;
  background: var(--cc-surface-2);
  border: 1px solid var(--cc-line);
  cursor: text;
}
.cc-date:focus-within { border-color: rgb(var(--v-theme-primary)); }
.cc-date__label {
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--cc-muted);
}
.cc-date__input {
  border: 0;
  outline: 0;
  background: transparent;
  font-family: inherit;
  font-size: 11px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  color: var(--cc-ink);
  width: 108px;
  cursor: pointer;
  color-scheme: light dark;
}
/* Native date inputs render a chunky calendar chrome on WebKit — slim it. */
.cc-date__input::-webkit-calendar-picker-indicator {
  opacity: 0.5;
  cursor: pointer;
  padding: 0;
  margin-left: 2px;
}
.cc-date__input::-webkit-calendar-picker-indicator:hover { opacity: 0.85; }
.cc-date__sep { font-size: 11px; color: var(--cc-muted); }
.cc-date__apply {
  padding: 5px 11px;
  border-radius: 8px;
  border: 0;
  cursor: pointer;
  font-family: inherit;
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: 0.02em;
  color: #fff;
  background: linear-gradient(135deg, #2f6dff, #143ce1);
  transition: filter 0.15s ease, opacity 0.15s ease;
}
.cc-date__apply:hover:not(:disabled) { filter: brightness(1.1); }
.cc-date__apply:disabled { opacity: 0.55; cursor: default; }

/* ── Chart headline stats ── */
.cc-trend__stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr)) auto;
  align-items: center;
  gap: 14px;
  margin: 16px 0 6px;
  padding: 14px 16px;
  border-radius: 14px;
  border: 1px solid var(--cc-line);
  background: var(--cc-surface-2);
}
.cc-trend__stat { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
.cc-trend__stat-label {
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--cc-muted);
}
.cc-trend__stat-value {
  font-size: 1.22rem;
  font-weight: 800;
  letter-spacing: -0.7px;
  line-height: 1.15;
  color: var(--cc-ink);
  font-variant-numeric: tabular-nums;
}
.cc-trend__stat-value em {
  font-style: normal;
  font-size: 0.72rem;
  font-weight: 700;
  opacity: 0.45;
}
.cc-trend__stat-delta,
.cc-trend__stat-sub {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  font-size: 10.5px;
  font-weight: 650;
  color: var(--cc-muted);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.cc-trend__stat-delta.is-up { color: #10b981; }
.cc-trend__stat-delta.is-down { color: #ef4444; }

.cc-trend__modes {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-wrap: wrap;
  justify-self: end;
}
.cc-trend__toggle {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 5px 10px;
  border-radius: 9px;
  border: 1px dashed var(--cc-line-2);
  background: transparent;
  font-family: inherit;
  font-size: 10.5px;
  font-weight: 700;
  color: var(--cc-muted);
  cursor: pointer;
  transition: all 0.16s ease;
}
.cc-trend__toggle:hover { color: var(--cc-ink); border-color: var(--cc-muted); }
.cc-trend__toggle.is-on {
  color: rgb(var(--v-theme-primary));
  border-style: solid;
  border-color: rgba(var(--v-theme-primary), 0.4);
  background: rgba(var(--v-theme-primary), 0.08);
}

.cc-trend__canvas {
  margin-top: 10px;
  padding: 10px 4px 2px;
  color: var(--cc-muted);
  min-height: 260px;
}
.cc-trend__skeleton {
  height: 300px;
  border-radius: 14px;
  background: linear-gradient(90deg,
    rgba(148, 163, 184, 0.08) 25%,
    rgba(148, 163, 184, 0.16) 50%,
    rgba(148, 163, 184, 0.08) 75%);
  background-size: 200% 100%;
  animation: cc-traffic-shimmer 1.4s linear infinite;
}
.cc-trend__legend-note {
  display: flex;
  align-items: center;
  gap: 7px;
  margin: 10px 0 0;
  font-size: 10.5px;
  font-weight: 600;
  color: var(--cc-muted);
}
.cc-trend__ghost-key {
  width: 22px;
  height: 0;
  border-top: 1.5px dashed currentColor;
  opacity: 0.55;
}

/* ── Breakdown table ── */
.cc-trend__table {
  margin-top: 14px;
  border-top: 1px solid var(--cc-line);
  padding-top: 10px;
}
.cc-trend__table-head,
.cc-trend__row {
  display: grid;
  grid-template-columns: minmax(120px, 1.6fr) 84px 84px 84px 130px 76px;
  align-items: center;
  gap: 10px;
  padding: 7px 8px;
}
.cc-trend__table-head {
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.07em;
  text-transform: uppercase;
  color: var(--cc-muted);
}
.cc-trend__table-head .is-num,
.cc-trend__row .is-num {
  text-align: right;
  font-variant-numeric: tabular-nums;
}
.cc-trend__row {
  border-radius: 9px;
  font-size: 11.5px;
  font-weight: 650;
  color: rgba(var(--v-theme-on-surface), 0.8);
  transition: background-color 0.15s ease;
}
.cc-trend__row:hover { background: rgba(var(--v-theme-on-surface), 0.035); }
.cc-trend__row-name {
  display: flex;
  align-items: center;
  gap: 7px;
  font-weight: 750;
  color: var(--cc-ink);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cc-trend__row-swatch {
  width: 8px;
  height: 8px;
  border-radius: 2.5px;
  flex: 0 0 auto;
}
.cc-trend__share {
  display: inline-block;
  vertical-align: middle;
  width: 56px;
  height: 4px;
  margin-right: 5px;
  border-radius: 999px;
  overflow: hidden;
  background: rgba(148, 163, 184, 0.2);
}
.cc-trend__share i {
  display: block;
  height: 100%;
  border-radius: 999px;
  background: currentColor;
  opacity: 0.65;
}
.cc-trend__row-trend.is-up { color: #10b981; }
.cc-trend__row-trend.is-down { color: #ef4444; }
.cc-trend__row-trend.is-flat { color: var(--cc-muted); }

@media (max-width: 1180px) {
  .cc-trend__stats { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .cc-trend__modes { grid-column: 1 / -1; justify-self: start; }
  .cc-trend__table-head,
  .cc-trend__row { grid-template-columns: minmax(110px, 1.5fr) 76px 76px 76px 70px; }
  .cc-trend__table-head > :nth-child(4),
  .cc-trend__row > :nth-child(4) { display: none; }
}
@media (max-width: 820px) {
  .cc-trend { padding: 16px 14px; }
  .cc-trend__stats { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .cc-trend__filter { width: 100%; }
  .cc-trend__dates { flex-wrap: wrap; }
  .cc-trend__table-head,
  .cc-trend__row { grid-template-columns: minmax(90px, 1.4fr) 66px 76px; }
  .cc-trend__table-head > :nth-child(3),
  .cc-trend__table-head > :nth-child(5),
  .cc-trend__row > :nth-child(3),
  .cc-trend__row > :nth-child(5) { display: none; }
}

@media (prefers-reduced-motion: reduce) {
  .cc-traffic__pip.is-live,
  .cc-monitor__state--live i,
  .cc-traffic__skeleton { animation: none; }
  .cc-monitor:hover { transform: none; }
}

@media (max-width: 1180px) {
  .cc-traffic__summary { grid-template-columns: repeat(4, minmax(0, 1fr)); }
  .cc-traffic__fig--chart { grid-column: 1 / -1; }
  .cc-monitor {
    grid-template-columns: minmax(130px, 1.4fr) 88px 88px 88px minmax(80px, 1fr);
  }
  .cc-monitor__share { display: none; }
}
@media (max-width: 820px) {
  .cc-traffic { padding: 16px 14px; }
  .cc-traffic__summary { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  /* Two-line layout: identity across the top, then state · rate · today on
     one row, then the sparkline and the footnote full width. */
  .cc-monitor {
    grid-template-columns: auto auto auto;
    gap: 8px 14px;
    row-gap: 10px;
  }
  .cc-monitor__id { grid-column: 1 / -1; }
  .cc-monitor__state { justify-self: start; }
  .cc-monitor__spark { grid-column: 1 / -1; }
  .cc-monitor__foot { grid-column: 1 / -1; }
}

/* ══ Command palette ══ */
.cc-palette {
  overflow: hidden;
  border-radius: 18px;
  background: var(--cc-surface);
  border: 1px solid var(--cc-line-2);
  box-shadow: 0 40px 90px -30px rgba(2, 6, 23, 0.65);
}
.cc-palette__search {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 14px 16px;
  border-bottom: 1px solid var(--cc-line);
}
.cc-palette__search-icon { color: var(--cc-muted); flex-shrink: 0; }
.cc-palette__input {
  flex: 1 1 auto;
  min-width: 0;
  border: 0;
  outline: 0;
  background: transparent;
  font-family: inherit;
  font-size: 14.5px;
  font-weight: 500;
  color: var(--cc-ink);
}
.cc-palette__input::placeholder { color: var(--cc-muted); }
.cc-palette__list {
  list-style: none;
  margin: 0;
  padding: 6px;
  max-height: 52vh;
  overflow-y: auto;
}
.cc-palette__item {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 9px 10px;
  border-radius: 11px;
  cursor: pointer;
  transition: background 0.12s;
}
.cc-palette__item--active { background: rgba(47, 109, 255, 0.09); }
.cc-palette__glyph {
  width: 30px;
  height: 30px;
  flex-shrink: 0;
  display: grid;
  place-items: center;
  border-radius: 9px;
  color: var(--cc-primary);
  background: rgba(47, 109, 255, 0.10);
}
.cc-palette__text {
  display: flex;
  flex-direction: column;
  min-width: 0;
  line-height: 1.3;
}
.cc-palette__text strong {
  font-size: 13px;
  font-weight: 700;
  color: var(--cc-ink);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.cc-palette__text small {
  font-size: 11px;
  color: var(--cc-muted);
}
.cc-palette__badge {
  margin-left: auto;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
  color: var(--cc-primary);
  background: rgba(47, 109, 255, 0.10);
}
.cc-palette__enter {
  margin-left: auto;
  color: var(--cc-muted);
  opacity: 0.7;
}
.cc-palette__empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  padding: 36px 16px;
  color: var(--cc-muted);
  font-size: 12.5px;
}
.cc-palette__foot {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 9px 14px;
  border-top: 1px solid var(--cc-line);
  background: var(--cc-surface-2);
  font-size: 10.5px;
  font-weight: 600;
  color: var(--cc-muted);
}
.cc-palette__foot span {
  display: inline-flex;
  align-items: center;
  gap: 4px;
}

.cc-pop-enter-active,
.cc-pop-leave-active { transition: opacity 0.18s ease, transform 0.18s ease; }
.cc-pop-enter-from,
.cc-pop-leave-to { opacity: 0; transform: translateY(-8px) scale(0.98); }

/* ══ Loading skeleton ══ */
.cc-skeleton { display: flex; flex-direction: column; gap: 16px; padding-top: 18px; }
.cc-skeleton__hero {
  height: 210px;
  border-radius: 28px;
}
.cc-skeleton__row {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 14px;
}
@media (min-width: 720px) { .cc-skeleton__row { grid-template-columns: repeat(3, minmax(0, 1fr)); } }
@media (min-width: 1180px) { .cc-skeleton__row { grid-template-columns: repeat(6, minmax(0, 1fr)); } }
.cc-skeleton__tile { height: 118px; border-radius: 18px; }
.cc-skeleton__row--cards {
  grid-template-columns: repeat(auto-fill, minmax(258px, 1fr));
  gap: 16px;
  margin-top: 18px;
}
.cc-skeleton__card { height: 230px; border-radius: var(--cc-radius); }
.cc-skeleton__hero,
.cc-skeleton__tile,
.cc-skeleton__card {
  position: relative;
  overflow: hidden;
  background: var(--cc-surface);
  border: 1px solid var(--cc-line);
}
.cc-skeleton__hero::after,
.cc-skeleton__tile::after,
.cc-skeleton__card::after {
  content: '';
  position: absolute;
  inset: 0;
  transform: translateX(-100%);
  background: linear-gradient(90deg, transparent, rgba(148, 163, 184, 0.20), transparent);
  animation: cc-shimmer 1.5s infinite;
}
@keyframes cc-shimmer { to { transform: translateX(100%); } }

/* ══ Switching overlay ══ */
.cc-switch {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 14px;
  padding: 34px 44px;
  border-radius: 24px;
  color: #fff;
  background: linear-gradient(150deg, rgba(10, 16, 41, 0.97), rgba(20, 60, 225, 0.92));
  box-shadow: 0 40px 90px -30px rgba(0, 0, 0, 0.7);
  position: relative;
  overflow: hidden;
}
.cc-switch::before {
  content: '';
  position: absolute;
  top: -80px;
  right: -60px;
  width: 200px;
  height: 200px;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(55, 214, 255, 0.5), transparent 65%);
  filter: blur(24px);
}
.cc-switch__ring {
  position: absolute;
  top: 24px;
  width: 62px;
  height: 62px;
  border-radius: 50%;
  border: 2px solid rgba(255, 255, 255, 0.18);
  border-top-color: #37d6ff;
  animation: cc-spin 0.9s linear infinite;
}
.cc-switch__icon { position: relative; z-index: 1; opacity: 0.9; }
.cc-switch__label {
  position: relative;
  z-index: 1;
  margin-top: 34px;
  font-size: 0.9rem;
  font-weight: 500;
  color: rgba(255, 255, 255, 0.82);
}
.cc-switch__label strong { font-weight: 800; color: #fff; }

/* ══ Responsive ══ */
@media (max-width: 900px) {
  .cc-hero__main {
    flex-direction: column;
    align-items: flex-start;
    gap: 26px;
  }
  .cc-hero { padding: 28px 24px 22px; }
  .cc-pulse { align-self: center; }
  .cc-hero__strip {
    flex-wrap: wrap;
    gap: 18px 26px;
  }
  .cc-hero__spark {
    order: 9;
    flex: 1 1 100%;
    max-width: none;
    margin-left: 0;
  }
}
@media (max-width: 719px) {
  .cc-cmdk__label { display: none; }
  .cc-cmdk { padding: 0 8px; }
  /* Drop the action cluster onto its own row so 7 controls never spill
     outside the glass bar on narrow phones. */
  .cc-topbar { padding: 10px; }
  .cc-topbar__actions {
    flex: 1 1 100%;
    flex-wrap: wrap;
    justify-content: flex-end;
    gap: 6px;
    margin-left: 0;
  }
  .cc-icon-btn { width: 34px; height: 34px; }
  .cc-cmdk { height: 34px; }
  .cc-topbar__rule { display: none; }
  .cc-facilities__head { align-items: flex-start; }
  .cc-facilities__tools { width: 100%; }
  .cc-search { flex: 1 1 100%; }
  .cc-search__input { width: 100%; }
  .cc-sort { flex: 1 1 auto; }
  .cc-filters { overflow-x: auto; flex-wrap: nowrap; padding-bottom: 2px; }
  .cc-filter { flex-shrink: 0; }
  .cc-panel { padding: 16px; }
}
@media (prefers-reduced-motion: reduce) {
  .cc-orb,
  .cc-live--on .cc-live__dot,
  .cc-card__state--on i,
  .cc-panel__stamp-dot,
  .cc-kpi,
  .cc-card,
  .cc-hero { animation: none; }
  .cc-kpi:hover,
  .cc-card:hover,
  .cc-insight:hover { transform: none; }
}

/* ── Vue Transitions ── */
.slide-fade-enter-active {
  transition: all 0.5s cubic-bezier(0.16, 1, 0.3, 1);
}
.slide-fade-enter-from {
  opacity: 0;
  transform: translateX(-30px);
}
.fade-enter-active {
  transition: opacity 0.5s ease;
}
.fade-enter-from {
  opacity: 0;
}
.fade-up-enter-active {
  transition: all 0.5s cubic-bezier(0.16, 1, 0.3, 1);
}
.fade-up-enter-from {
  opacity: 0;
  transform: translateY(20px);
}
.scale-in-enter-active {
  transition: all 0.45s cubic-bezier(0.16, 1, 0.3, 1);
}
.scale-in-enter-from {
  opacity: 0;
  transform: scale(0.85);
}
.card-in-enter-active {
  transition: all 0.5s cubic-bezier(0.16, 1, 0.3, 1);
}
.card-in-enter-from {
  opacity: 0;
  transform: translateY(30px) scale(0.95);
}
</style>
