<template>
  <div class="cl-page">
    <!-- ── Ambient background ── -->
    <div class="cl-ambient" aria-hidden="true">
      <span class="cl-orb cl-orb--1" />
      <span class="cl-orb cl-orb--2" />
      <span class="cl-grid" />
    </div>

    <div class="cl-shell">
      <!-- ══ Skeleton ══ -->
      <div v-if="loading && !data" class="cl-skeleton" aria-busy="true">
        <div class="cl-skeleton__hero" />
        <div class="cl-skeleton__row">
          <div v-for="n in 4" :key="`k${n}`" class="cl-skeleton__tile" />
        </div>
        <div class="cl-skeleton__row cl-skeleton__row--split">
          <div class="cl-skeleton__panel" />
          <div class="cl-skeleton__panel" />
        </div>
      </div>

      <template v-else>
        <!-- ══ Hero — calm surface panel (matches /clinics/equipment) ══ -->
        <section class="cl-hero">
          <span class="cl-hero__rule" aria-hidden="true" />

          <div class="cl-hero__top">
            <div class="cl-hero__identity">
              <div class="cl-hero__icon">
                <img v-if="auth.tenantLogo" :src="auth.tenantLogo" alt="" />
                <v-icon v-else size="26">mdi-hospital-box</v-icon>
              </div>
              <div class="cl-hero__copy">
                <div class="cl-hero__eyebrow">
                  <span class="cl-hero__pulse" aria-hidden="true" />
                  {{ greeting }} · {{ auth.tenantName || 'Clinic' }}
                </div>
                <h1 class="cl-hero__title">Clinic Overview</h1>
                <p class="cl-hero__sub">{{ heroSubtitle }}</p>
              </div>
            </div>

            <div class="cl-hero__actions">
              <v-menu location="bottom end" :close-on-content-click="true">
                <template #activator="{ props }">
                  <v-btn
                    v-bind="props"
                    class="cl-btn text-none"
                    rounded="lg"
                    size="small"
                    prepend-icon="mdi-office-building-marker"
                  >{{ siteLabel }}</v-btn>
                </template>
                <v-list density="compact" rounded="lg" class="cl-site-menu" min-width="240">
                  <v-list-subheader>Clinic</v-list-subheader>
                  <v-list-item
                    :active="!siteId"
                    title="All clinics"
                    subtitle="Tenant-wide totals"
                    @click="setSite(null)"
                  />
                  <v-list-item
                    v-for="s in siteList"
                    :key="s.id"
                    :active="siteId === s.id"
                    :title="s.name"
                    :subtitle="s.is_hq ? 'HQ · head office' : (s.code || 'Branch')"
                    @click="setSite(s.id)"
                  />
                  <v-divider class="my-1" />
                  <v-list-item
                    prepend-icon="mdi-cog-outline"
                    title="Manage clinics"
                    to="/clinics/sites"
                  />
                </v-list>
              </v-menu>
              <v-btn
                class="cl-btn text-none"
                rounded="lg"
                size="small"
                prepend-icon="mdi-magnify"
                @click="openPalette"
              >Search</v-btn>
              <v-btn
                class="cl-btn text-none"
                :class="{ 'cl-btn--on': autoRefresh }"
                rounded="lg"
                size="small"
                :prepend-icon="autoRefresh ? 'mdi-autorenew' : 'mdi-autorenew-off'"
                :aria-pressed="autoRefresh"
                @click="toggleAutoRefresh"
              >{{ autoRefresh ? `Live · ${countdown}s` : 'Paused' }}</v-btn>
              <v-btn
                class="cl-btn text-none"
                rounded="lg"
                size="small"
                prepend-icon="mdi-refresh"
                :loading="loading"
                @click="load"
              >Refresh</v-btn>
              <v-btn
                class="cl-btn text-none"
                :class="{ 'cl-btn--on': isFullscreen }"
                rounded="lg"
                size="small"
                :prepend-icon="isFullscreen ? 'mdi-fullscreen-exit' : 'mdi-fullscreen'"
                :aria-pressed="isFullscreen"
                @click="toggleFullscreen"
              >{{ isFullscreen ? 'Exit' : 'Full' }}</v-btn>
              <v-btn
                class="cl-btn text-none"
                rounded="lg"
                size="small"
                :prepend-icon="isDark ? 'mdi-white-balance-sunny' : 'mdi-weather-night'"
                @click="toggleTheme"
              >{{ isDark ? 'Light' : 'Dark' }}</v-btn>
              <v-btn
                class="cl-btn cl-btn--primary text-none"
                rounded="lg"
                size="small"
                prepend-icon="mdi-calendar-plus"
                to="/clinics/appointments/new"
              >New appointment</v-btn>
            </div>
          </div>

          <div class="cl-hero__foot">
            <span class="cl-hero__chip">
              <v-icon size="13">mdi-calendar-blank-outline</v-icon>{{ todayLabel }}
            </span>
            <span class="cl-hero__chip">
              <v-icon size="13">mdi-calendar-clock</v-icon>
              <b>{{ fmt(kpis.appointments_today) }}</b> today
            </span>
            <span class="cl-hero__chip">
              <v-icon size="13">mdi-stethoscope</v-icon>
              <b>{{ fmt(kpis.consultations) }}</b> consults
            </span>
            <span class="cl-hero__chip">
              <v-icon size="13">mdi-account-multiple</v-icon>
              <b>{{ fmt(kpis.patients_total) }}</b> patients
            </span>
            <span class="cl-hero__chip">
              <v-icon size="13">mdi-cash-multiple</v-icon>
              <b>{{ money(revenue.billed) }}</b> billed
            </span>
            <span v-if="triage.critical" class="cl-hero__chip cl-hero__chip--danger">
              <v-icon size="13">mdi-alert-octagon</v-icon>
              <b>{{ triage.critical }}</b> critical triage
            </span>
            <span v-if="kpis.alerts_open" class="cl-hero__chip cl-hero__chip--warn">
              <v-icon size="13">mdi-bell-alert</v-icon>
              <b>{{ kpis.alerts_open }}</b> open alerts
            </span>
            <NuxtLink
              v-if="security"
              to="/clinics/security"
              class="cl-hero__chip cl-hero__chip--link"
              :class="posture.tone === 'ok' ? 'cl-hero__chip--muted' : `cl-hero__chip--${posture.tone}`"
            >
              <v-icon size="13">mdi-shield-check-outline</v-icon>
              <b>{{ posture.score }}</b> security
              <v-icon size="12">mdi-arrow-right</v-icon>
            </NuxtLink>
            <span class="cl-hero__chip cl-hero__chip--muted">
              <v-icon size="13">mdi-calendar-range</v-icon>Last {{ rangeLabel }}
            </span>
            <span v-if="updatedLabel" class="cl-hero__stamp">{{ updatedLabel }}</span>
          </div>
        </section>

        <!-- ══ Module strip — palette pinned, modules loop right → left ══ -->
        <section class="cl-modules" aria-label="Clinic modules">
          <button type="button" class="cl-mod cl-mod--pinned" @click="openPalette">
            <v-icon size="17">mdi-magnify</v-icon>
            <span class="cl-mod__label">Command palette</span>
            <span class="cl-mod__kbd">{{ isMac ? '⌘' : 'Ctrl' }} K</span>
          </button>

          <div class="cl-marquee">
            <div class="cl-marquee__track">
              <div
                v-for="copy in 2"
                :key="`copy-${copy}`"
                class="cl-marquee__group"
                :aria-hidden="copy === 2 ? 'true' : undefined"
              >
                <NuxtLink
                  v-for="m in modules"
                  :key="`${copy}-${m.key}`"
                  :to="m.to"
                  class="cl-mod"
                  :aria-label="m.label"
                  :tabindex="copy === 2 ? -1 : undefined"
                >
                  <v-icon size="17">{{ m.icon }}</v-icon>
                  <span class="cl-mod__label">{{ m.label }}</span>
                  <span v-if="m.meta" class="cl-mod__meta" :class="m.tone ? `cl-mod__meta--${m.tone}` : ''">
                    {{ m.meta }}
                  </span>
                </NuxtLink>
              </div>
            </div>
          </div>
        </section>

        <!-- ══ Attention strip ══ -->
        <section class="cl-attention" aria-label="Needs attention">
          <button
            v-for="a in attention"
            :key="a.key"
            type="button"
            class="cl-attn"
            :class="[`cl-attn--${a.tone}`, { 'cl-attn--on': drill === a.key }]"
            :aria-pressed="drill === a.key"
            :disabled="!a.count"
            @click="drill = drill === a.key ? null : a.key"
          >
            <span class="cl-attn__icon"><v-icon size="17">{{ a.icon }}</v-icon></span>
            <span class="cl-attn__body">
              <span class="cl-attn__value">{{ a.count }}</span>
              <span class="cl-attn__label">{{ a.label }}</span>
            </span>
            <v-icon v-if="a.count" size="14" class="cl-attn__arrow">
              {{ drill === a.key ? 'mdi-close' : 'mdi-arrow-right' }}
            </v-icon>
          </button>
        </section>

        <!-- ══ Range switch ══ -->
        <div class="cl-range">
          <div class="cl-seg" role="group" aria-label="Time range">
            <button
              v-for="opt in rangeOptions"
              :key="opt.key"
              type="button"
              class="cl-seg__btn"
              :class="{ 'cl-seg__btn--on': rangeKey === opt.key }"
              :aria-pressed="rangeKey === opt.key"
              @click="setRange(opt.key)"
            >{{ opt.label }}</button>
          </div>
          <span class="cl-range__hint">
            Showing <strong>{{ rangeLabel }}</strong> · each KPI compares to the previous period
          </span>
        </div>

        <!-- ══ KPI grid ══ -->
        <section class="cl-kpis" aria-label="Clinic metrics">
          <article
            v-for="(k, i) in kpiTiles"
            :key="k.title"
            class="cl-kpi"
            :style="{ '--accent': k.accent, '--soft': k.soft, '--i': i }"
          >
            <div class="cl-kpi__head">
              <span class="cl-kpi__icon"><v-icon size="19">{{ k.icon }}</v-icon></span>
              <span
                v-if="k.delta !== undefined"
                class="cl-delta"
                :class="`cl-delta--${deltaTone(k.delta)}`"
              >{{ deltaText(k.delta) }}</span>
            </div>
            <div class="cl-kpi__value">{{ k.value }}</div>
            <div class="cl-kpi__label">{{ k.title }}</div>
            <div v-if="k.sub" class="cl-kpi__sub">{{ k.sub }}</div>
            <span class="cl-kpi__bar" aria-hidden="true" />
          </article>
        </section>

        <!-- ══ Clinical pipeline ══ -->
        <section class="cl-panel cl-flow">
          <header class="cl-panel__head">
            <div>
              <h2 class="cl-panel__title">Patient journey · today</h2>
              <p class="cl-panel__hint">How today's arrivals are moving through the clinic</p>
            </div>
            <span class="cl-panel__badge">{{ fmt(kpis.appointments_today) }} scheduled today</span>
          </header>
          <div class="cl-flow__track">
            <template v-for="(stage, i) in pipeline" :key="stage.key">
              <div class="cl-stage" :class="`cl-stage--${stageTone(stage.key)}`">
                <span class="cl-stage__icon"><v-icon size="16">{{ stage.icon }}</v-icon></span>
                <span class="cl-stage__count">{{ stage.count }}</span>
                <span class="cl-stage__label">{{ stage.label }}</span>
                <span class="cl-stage__pct">{{ stage.pct }}%</span>
              </div>
              <v-icon v-if="i < pipeline.length - 1" size="16" class="cl-flow__arrow">mdi-chevron-right</v-icon>
            </template>
          </div>
        </section>

        <!-- ══ Trends + revenue ══ -->
        <section class="cl-split">
          <div class="cl-panel cl-panel--chart">
            <header class="cl-panel__head">
              <div>
                <h2 class="cl-panel__title">{{ metricLabel }}</h2>
                <p class="cl-panel__hint">Last {{ trend.dates?.length || 0 }} days</p>
              </div>
              <div class="cl-tabs" role="tablist" aria-label="Trend metric">
                <button
                  v-for="m in metrics"
                  :key="m.key"
                  type="button"
                  role="tab"
                  class="cl-tabs__btn"
                  :class="{ 'cl-tabs__btn--on': metric === m.key }"
                  :aria-selected="metric === m.key"
                  @click="metric = m.key"
                >{{ m.label }}</button>
              </div>
            </header>

            <div class="cl-panel__figure">
              <span class="cl-panel__big">{{ metric === 'revenue' ? money(metricTotal) : fmt(metricTotal) }}</span>
              <span class="cl-delta" :class="`cl-delta--${deltaTone(trendDelta)}`">{{ deltaText(trendDelta) }}</span>
              <span class="cl-panel__vs">vs previous {{ trend.dates?.length || 0 }}d</span>
            </div>

            <div class="cl-chart">
              <SparkArea
                :values="metricSeries"
                :labels="trend.dates || []"
                :height="176"
                :color="metricColor"
                :y-formatter="metric === 'revenue' ? compact : null"
              />
            </div>
          </div>

          <div class="cl-panel cl-panel--money">
            <header class="cl-panel__head">
              <div>
                <h2 class="cl-panel__title">Revenue</h2>
                <p class="cl-panel__hint">{{ revenue.invoice_count || 0 }} invoices · {{ rangeLabel }}</p>
              </div>
            </header>

            <div class="cl-money">
              <div class="cl-money__row">
                <span class="cl-money__label">Billed</span>
                <span class="cl-money__value">{{ money(revenue.billed) }}</span>
              </div>
              <div class="cl-money__row">
                <span class="cl-money__label cl-money__label--ok">Collected</span>
                <span class="cl-money__value cl-money__value--ok">{{ money(revenue.collected) }}</span>
              </div>
              <div class="cl-money__row">
                <span class="cl-money__label cl-money__label--warn">Outstanding</span>
                <span class="cl-money__value cl-money__value--warn">{{ money(revenue.outstanding) }}</span>
              </div>
              <div class="cl-money__track">
                <span class="cl-money__fill" :style="{ width: `${collectionRate}%` }" />
              </div>
            </div>

            <div class="cl-statuslist">
              <div v-for="s in revenue.by_status" :key="s.status" class="cl-statusrow">
                <span class="cl-statusrow__label">{{ pretty(s.status) }}</span>
                <span class="cl-statusrow__track">
                  <span
                    class="cl-statusrow__fill"
                    :style="{ width: `${Math.max(3, s.pct)}%`, background: invoiceColor(s.status) }"
                  />
                </span>
                <span class="cl-statusrow__count">{{ s.count }}</span>
              </div>
              <p v-if="!revenue.by_status?.length" class="cl-empty-inline">No invoices in this period</p>
            </div>
          </div>
        </section>

        <!-- ══ Schedule + care team ══ -->
        <section class="cl-split">
          <div class="cl-panel">
            <header class="cl-panel__head">
              <div>
                <h2 class="cl-panel__title">Today's schedule</h2>
                <p class="cl-panel__hint">{{ filteredSchedule.length }} appointments</p>
              </div>
              <div class="cl-mini-filters">
                <button
                  v-for="f in scheduleFilters"
                  :key="f.key"
                  type="button"
                  class="cl-chipbtn"
                  :class="{ 'cl-chipbtn--on': scheduleFilter === f.key }"
                  @click="scheduleFilter = f.key"
                >{{ f.label }}</button>
              </div>
            </header>

            <ol v-if="filteredSchedule.length" class="cl-timeline">
              <li v-for="apt in filteredSchedule" :key="apt.id" class="cl-timeline__item">
                <div class="cl-timeline__time">
                  <span class="cl-timeline__clock">{{ apt.time || '--:--' }}</span>
                  <span class="cl-timeline__dur">{{ apt.duration }}m</span>
                </div>
                <span class="cl-timeline__rail" :class="`cl-timeline__rail--${apt.status}`" />
                <div class="cl-timeline__body">
                  <div class="cl-timeline__top">
                    <NuxtLink :to="`/clinics/patients/${apt.patient_id}`" class="cl-timeline__name">
                      {{ apt.patient_name }}
                    </NuxtLink>
                    <span class="cl-status" :class="`cl-status--${apt.status}`">{{ pretty(apt.status) }}</span>
                  </div>
                  <div class="cl-timeline__meta">
                    <span v-if="apt.doctor"><v-icon size="12">mdi-stethoscope</v-icon>{{ apt.doctor }}</span>
                    <span v-if="apt.department"><v-icon size="12">mdi-domain</v-icon>{{ apt.department }}</span>
                    <span v-if="apt.reason" class="cl-timeline__reason">{{ apt.reason }}</span>
                  </div>
                </div>
              </li>
            </ol>
            <div v-else class="cl-empty">
              <v-icon size="24">mdi-calendar-check-outline</v-icon>
              <p>No appointments match this filter</p>
            </div>
          </div>

          <div class="cl-panel">
            <header class="cl-panel__head">
              <div>
                <h2 class="cl-panel__title">Care team</h2>
                <p class="cl-panel__hint">Consultation load · {{ rangeLabel }}</p>
              </div>
            </header>

            <ul v-if="careTeam.length" class="cl-team">
              <li v-for="(doc, i) in careTeam" :key="doc.id" class="cl-team__item">
                <span class="cl-team__rank">{{ i + 1 }}</span>
                <span class="cl-team__avatar">{{ initials(doc.name) }}</span>
                <span class="cl-team__meta">
                  <span class="cl-team__name">{{ doc.name }}</span>
                  <span class="cl-team__sub">{{ doc.consultations }} consultations</span>
                </span>
                <span class="cl-team__bar">
                  <span class="cl-team__fill" :style="{ width: `${Math.max(4, doc.completion)}%` }" />
                </span>
                <span class="cl-team__pct">{{ doc.completion }}%</span>
              </li>
            </ul>
            <div v-else class="cl-empty">
              <v-icon size="24">mdi-account-group-outline</v-icon>
              <p>No consultations recorded in this period</p>
            </div>

            <div v-if="wards" class="cl-beds">
              <div class="cl-beds__head">
                <span>Bed occupancy</span>
                <strong>{{ wards.beds_occupied }}/{{ wards.beds_total }}</strong>
              </div>
              <div class="cl-beds__track">
                <span class="cl-beds__fill" :style="{ width: `${wards.occupancy_pct}%` }" />
              </div>
              <div class="cl-beds__legend">
                <span>{{ wards.beds_available }} available</span>
                <span>{{ wards.occupancy_pct }}% occupied</span>
              </div>
            </div>
          </div>
        </section>

        <!-- ══ Diagnostics quad ══ -->
        <section class="cl-quad">
          <div class="cl-panel">
            <header class="cl-panel__head">
              <div>
                <h2 class="cl-panel__title">Triage acuity</h2>
                <p class="cl-panel__hint">{{ triage.open }} in queue</p>
              </div>
              <span class="cl-panel__badge" :class="triage.critical ? 'cl-panel__badge--danger' : ''">
                {{ triage.critical }} critical
              </span>
            </header>
            <div class="cl-esi">
              <div v-for="a in triage.by_acuity" :key="a.level ?? 'none'" class="cl-esi__row">
                <span class="cl-esi__badge" :class="`cl-esi__badge--${a.tone}`">{{ a.label }}</span>
                <span class="cl-esi__track">
                  <span class="cl-esi__fill" :class="`cl-esi__fill--${a.tone}`" :style="{ width: `${esiPct(a.count)}%` }" />
                </span>
                <span class="cl-esi__count">{{ a.count }}</span>
              </div>
              <p v-if="!triage.by_acuity?.length" class="cl-empty-inline">No triage entries in this period</p>
            </div>
          </div>

          <div class="cl-panel">
            <header class="cl-panel__head">
              <div>
                <h2 class="cl-panel__title">Laboratory</h2>
                <p class="cl-panel__hint">{{ lab.pending || 0 }} awaiting results</p>
              </div>
            </header>
            <div class="cl-chipgrid">
              <span v-for="s in lab.by_status" :key="s.status" class="cl-pipechip" :class="`cl-pipechip--${labTone(s.status)}`">
                <v-icon size="14">{{ labIcon(s.status) }}</v-icon>
                <span>{{ pretty(s.status) }}</span>
                <strong>{{ s.count }}</strong>
              </span>
              <p v-if="!lab.by_status?.length" class="cl-empty-inline">No lab orders in this period</p>
            </div>
          </div>

          <div class="cl-panel">
            <header class="cl-panel__head">
              <div>
                <h2 class="cl-panel__title">Pharmacy</h2>
                <p class="cl-panel__hint">{{ pharmacy.open || 0 }} open scripts</p>
              </div>
            </header>
            <div class="cl-chipgrid">
              <span v-for="s in pharmacy.by_status" :key="s.status" class="cl-pipechip" :class="`cl-pipechip--${rxTone(s.status)}`">
                <v-icon size="14">{{ rxIcon(s.status) }}</v-icon>
                <span>{{ pretty(s.status) }}</span>
                <strong>{{ s.count }}</strong>
              </span>
              <p v-if="!pharmacy.by_status?.length" class="cl-empty-inline">No prescriptions in this period</p>
            </div>
          </div>

          <div class="cl-panel">
            <header class="cl-panel__head">
              <div>
                <h2 class="cl-panel__title">Departments</h2>
                <p class="cl-panel__hint">Appointment volume · {{ rangeLabel }}</p>
              </div>
            </header>
            <div class="cl-depts">
              <div v-for="d in topDepartments" :key="d.id" class="cl-dept">
                <span class="cl-dept__name">{{ d.name }}</span>
                <span class="cl-dept__track">
                  <span class="cl-dept__fill" :style="{ width: `${deptPct(d.appointments)}%` }" />
                </span>
                <span class="cl-dept__count">{{ d.appointments }}</span>
              </div>
              <p v-if="!topDepartments.length" class="cl-empty-inline">No department activity in this period</p>
            </div>
          </div>
        </section>

        <!-- ══ Alerts + activity + quick actions ══ -->
        <section class="cl-split cl-split--three">
          <div class="cl-panel">
            <header class="cl-panel__head">
              <div>
                <h2 class="cl-panel__title">Escalations</h2>
                <p class="cl-panel__hint">Open clinical alerts</p>
              </div>
              <span class="cl-panel__count" :class="alerts.length ? 'cl-panel__count--danger' : ''">{{ alerts.length }}</span>
            </header>
            <ul v-if="alerts.length" class="cl-alerts">
              <li v-for="a in alerts" :key="a.id" class="cl-alert" :class="`cl-alert--${a.severity}`">
                <span class="cl-alert__sev">{{ pretty(a.severity) }}</span>
                <div class="cl-alert__body">
                  <span class="cl-alert__name">{{ a.patient_name }}</span>
                  <span class="cl-alert__reason">{{ a.reason }}</span>
                </div>
                <span class="cl-alert__time">{{ timeAgo(a.triggered_at) }}</span>
              </li>
            </ul>
            <div v-else class="cl-empty">
              <v-icon size="24" color="#10b981">mdi-check-decagram-outline</v-icon>
              <p>All clear — no open escalations</p>
            </div>
          </div>

          <div class="cl-panel">
            <header class="cl-panel__head">
              <div>
                <h2 class="cl-panel__title">Activity</h2>
                <p class="cl-panel__hint">Newest events</p>
              </div>
            </header>
            <ol class="cl-feed">
              <li v-for="ev in activity" :key="ev.id" class="cl-feed__item">
                <span class="cl-feed__dot" :class="`cl-feed__dot--${ev.severity}`" />
                <div class="cl-feed__body">
                  <p class="cl-feed__text">{{ ev.description }}</p>
                  <div class="cl-feed__meta">
                    <span>{{ ev.actor_email || 'system' }}</span>
                    <span>{{ timeAgo(ev.created_at) }}</span>
                  </div>
                </div>
              </li>
              <li v-if="!activity.length" class="cl-empty"><p>No activity recorded</p></li>
            </ol>
          </div>

          <div class="cl-panel">
            <header class="cl-panel__head">
              <div>
                <h2 class="cl-panel__title">Quick actions</h2>
                <p class="cl-panel__hint">Jump straight in</p>
              </div>
            </header>
            <div class="cl-actions">
              <NuxtLink v-for="a in actions" :key="a.label" :to="a.to" class="cl-action" :style="{ '--accent': a.accent }">
                <span class="cl-action__icon"><v-icon size="17">{{ a.icon }}</v-icon></span>
                <span class="cl-action__label">{{ a.label }}</span>
                <v-icon size="14" class="cl-action__arrow">mdi-arrow-right</v-icon>
              </NuxtLink>
            </div>
          </div>
        </section>

        <!-- ══ Security & settings ══ -->
        <section class="cl-sec" aria-label="Security and settings">
          <header class="cl-sec__bar">
            <div class="cl-sec__id">
              <span class="cl-sec__glyph"><v-icon size="19">mdi-shield-lock-outline</v-icon></span>
              <div>
                <h2 class="cl-sec__title">Security &amp; settings</h2>
                <p class="cl-sec__hint">
                  Access control, clinical policy and the audited trail for
                  {{ auth.tenantName || 'this clinic' }}
                </p>
              </div>
            </div>

            <div class="cl-sec__posture" :class="`cl-sec__posture--${posture.tone}`">
              <span class="cl-sec__score">{{ posture.score }}</span>
              <span class="cl-sec__scopy">
                <strong>{{ posture.label }}</strong>
                <small>posture score</small>
              </span>
            </div>

            <div class="cl-sec__bar-actions">
              <v-btn
                class="cl-ghost text-none"
                rounded="lg"
                size="small"
                variant="text"
                prepend-icon="mdi-shield-lock-outline"
                to="/clinics/security"
              >Open console</v-btn>
              <v-btn
                class="cl-ghost text-none"
                rounded="lg"
                size="small"
                variant="text"
                prepend-icon="mdi-tray-arrow-down"
                :loading="exportingAudit"
                @click="exportAudit"
              >Export trail</v-btn>
              <v-btn
                class="cl-ghost text-none"
                rounded="lg"
                size="small"
                variant="text"
                prepend-icon="mdi-refresh"
                :loading="securityLoading"
                @click="loadSecurity"
              >Refresh</v-btn>
            </div>
          </header>

          <!-- Posture KPIs -->
          <div class="cl-sec__kpis">
            <article
              v-for="t in secTiles"
              :key="t.label"
              class="cl-sec__kpi"
              :style="{ '--accent': t.accent, '--soft': t.soft }"
            >
              <span class="cl-sec__kpi-icon"><v-icon size="15">{{ t.icon }}</v-icon></span>
              <span class="cl-sec__kpi-value">{{ t.value }}</span>
              <span class="cl-sec__kpi-label">{{ t.label }}</span>
            </article>
          </div>

          <div class="cl-sec__grid">
            <!-- Security signals -->
            <div class="cl-panel">
              <header class="cl-panel__head">
                <div>
                  <h2 class="cl-panel__title">Security signals</h2>
                  <p class="cl-panel__hint">Derived from the trail · highest risk first</p>
                </div>
                <NuxtLink to="/clinics/audit" class="cl-panel__link">
                  Full trail<v-icon size="14">mdi-arrow-right</v-icon>
                </NuxtLink>
              </header>

              <ul v-if="secSignals.length" class="cl-signals">
                <li
                  v-for="s in secSignals"
                  :key="s.kind"
                  class="cl-signal"
                  :class="`cl-signal--${s.severity}`"
                >
                  <span class="cl-signal__rail" />
                  <div class="cl-signal__body">
                    <span class="cl-signal__title">{{ s.title }}</span>
                    <span class="cl-signal__detail">{{ s.detail }}</span>
                  </div>
                  <span class="cl-signal__badge">{{ s.severity }}</span>
                </li>
              </ul>
              <div v-else-if="securityLoading" class="cl-empty">
                <v-icon size="22" class="cl-spin">mdi-loading</v-icon>
                <p>Reading the audit trail…</p>
              </div>
              <div v-else class="cl-empty">
                <v-icon size="24" color="#10b981">mdi-shield-check-outline</v-icon>
                <p>{{ securityError || 'No anomalies detected in this window' }}</p>
              </div>
            </div>

            <!-- Access & roles -->
            <div class="cl-panel">
              <header class="cl-panel__head">
                <div>
                  <h2 class="cl-panel__title">Access &amp; roles</h2>
                  <p class="cl-panel__hint">
                    {{ staffActive }} active · {{ staffAccounts.length }} accounts
                  </p>
                </div>
                <NuxtLink to="/clinics/staff" class="cl-panel__link">
                  Manage<v-icon size="14">mdi-arrow-right</v-icon>
                </NuxtLink>
              </header>

              <div v-if="roleMix.length" class="cl-roles">
                <div v-for="r in roleMix.slice(0, 6)" :key="r.role" class="cl-role">
                  <span class="cl-role__name">{{ pretty(r.role) }}</span>
                  <span class="cl-role__track">
                    <span class="cl-role__fill" :style="{ width: `${rolePct(r.count)}%` }" />
                  </span>
                  <span class="cl-role__count">{{ r.count }}</span>
                </div>
              </div>
              <p v-else class="cl-empty-inline">No staff accounts found</p>

              <div v-if="secModules.length" class="cl-sec__mods">
                <div class="cl-sec__mods-head">Most audited modules</div>
                <div class="cl-chipgrid">
                  <span
                    v-for="m in secModules"
                    :key="m.object_type"
                    class="cl-pipechip cl-pipechip--info"
                  >
                    <v-icon size="13">mdi-database-eye-outline</v-icon>
                    <span>{{ pretty(m.object_type) }}</span>
                    <strong>{{ m.count }}</strong>
                  </span>
                </div>
              </div>
            </div>

            <!-- Recent trail -->
            <div class="cl-panel">
              <header class="cl-panel__head">
                <div>
                  <h2 class="cl-panel__title">Recent trail</h2>
                  <p class="cl-panel__hint">Newest audited actions</p>
                </div>
                <span class="cl-panel__badge">{{ fmt(secKpis.total) }} events</span>
              </header>

              <ol v-if="securityEvents.length" class="cl-feed">
                <li v-for="ev in securityEvents" :key="ev.id" class="cl-feed__item">
                  <span class="cl-feed__dot" :class="`cl-feed__dot--${ev.severity}`" />
                  <div class="cl-feed__body">
                    <p class="cl-feed__text">{{ ev.description || pretty(ev.action) }}</p>
                    <div class="cl-feed__meta">
                      <span>{{ ev.actor_email || 'system' }}</span>
                      <span>{{ timeAgo(ev.created_at) }}</span>
                    </div>
                  </div>
                </li>
              </ol>
              <div v-else class="cl-empty">
                <v-icon size="24">mdi-shield-search</v-icon>
                <p>No audited actions recorded yet</p>
              </div>
            </div>
          </div>

          <div class="cl-sec__grid cl-sec__grid--2">
            <!-- Policy controls -->
            <div class="cl-panel">
              <header class="cl-panel__head">
                <div>
                  <h2 class="cl-panel__title">Security policy</h2>
                  <p class="cl-panel__hint">Applies to every sign-in to this clinic</p>
                </div>
                <span class="cl-panel__badge" :class="policyDirty ? 'cl-panel__badge--warn' : ''">
                  {{ policyDirty ? 'Unsaved' : 'Saved' }}
                </span>
              </header>

              <div class="cl-switches">
                <div v-for="p in policyToggles" :key="p.key" class="cl-switch">
                  <div
                    class="cl-switch__body"
                    role="button"
                    tabindex="0"
                    @click="togglePolicy(p.key)"
                    @keydown.enter.prevent="togglePolicy(p.key)"
                    @keydown.space.prevent="togglePolicy(p.key)"
                  >
                    <span class="cl-switch__label">{{ p.label }}</span>
                    <span class="cl-switch__hint">{{ p.hint }}</span>
                  </div>
                  <v-switch
                    v-model="policy[p.key]"
                    color="#2f6dff"
                    density="compact"
                    hide-details
                    inset
                    :aria-label="p.label"
                  />
                </div>
              </div>

              <div class="cl-sec__selects">
                <v-select
                  v-model="policy.idle_timeout"
                  :items="idleOptions"
                  item-title="label"
                  item-value="value"
                  label="Auto sign-out"
                  variant="outlined"
                  density="compact"
                  hide-details
                />
                <v-select
                  v-model="policy.retention_days"
                  :items="retentionOptions"
                  item-title="label"
                  item-value="value"
                  label="Audit retention"
                  variant="outlined"
                  density="compact"
                  hide-details
                />
                <v-select
                  v-model="policy.reminder_hours"
                  :items="reminderOptions"
                  item-title="label"
                  item-value="value"
                  label="Appointment reminders"
                  variant="outlined"
                  density="compact"
                  hide-details
                />
              </div>

              <div class="cl-sec__save">
                <span class="cl-sec__save-hint">
                  <v-icon size="13">mdi-information-outline</v-icon>
                  {{ policyDirty ? 'You have unsaved changes' : `Saved ${policySavedLabel}` }}
                </span>
                <v-btn
                  class="cl-primary-btn text-none"
                  rounded="lg"
                  size="small"
                  prepend-icon="mdi-content-save"
                  :loading="policySaving"
                  :disabled="!policyDirty"
                  @click="savePolicy"
                >Save policy</v-btn>
              </div>
            </div>

            <!-- Settings shortcuts -->
            <div class="cl-panel">
              <header class="cl-panel__head">
                <div>
                  <h2 class="cl-panel__title">Settings shortcuts</h2>
                  <p class="cl-panel__hint">Every control surface in one place</p>
                </div>
              </header>

              <div class="cl-shortcuts">
                <NuxtLink
                  v-for="s in settingsLinks"
                  :key="s.to"
                  :to="s.to"
                  class="cl-shortcut"
                  :style="{ '--accent': s.accent }"
                >
                  <span class="cl-shortcut__icon"><v-icon size="17">{{ s.icon }}</v-icon></span>
                  <span class="cl-shortcut__body">
                    <span class="cl-shortcut__label">{{ s.label }}</span>
                    <span class="cl-shortcut__hint">{{ s.hint }}</span>
                  </span>
                  <v-icon size="14" class="cl-shortcut__arrow">mdi-arrow-right</v-icon>
                </NuxtLink>
              </div>
            </div>
          </div>
        </section>
      </template>

      <!-- ══ Command palette ══ -->
      <v-dialog v-model="paletteOpen" max-width="620" scrim="#050a18" transition="cl-pop" attach=".cl-page">
        <div class="cl-palette" role="dialog" aria-label="Command palette">
          <div class="cl-palette__search">
            <v-icon size="20" class="cl-palette__icon">mdi-magnify</v-icon>
            <input
              ref="paletteInput"
              v-model="query"
              type="text"
              class="cl-palette__input"
              placeholder="Search patients, clinicians, pages or actions…"
              aria-label="Search"
              @keydown.down.prevent="movePalette(1)"
              @keydown.up.prevent="movePalette(-1)"
              @keydown.enter.prevent="runSelection"
            />
            <kbd class="cl-kbd">Esc</kbd>
          </div>
          <ul v-if="paletteItems.length" class="cl-palette__list">
            <li
              v-for="(item, idx) in paletteItems"
              :key="item.key"
              class="cl-palette__item"
              :class="{ 'cl-palette__item--active': idx === paletteIndex }"
              @mouseenter="paletteIndex = idx"
              @click="runItem(item)"
            >
              <span class="cl-palette__glyph"><v-icon size="17">{{ item.icon }}</v-icon></span>
              <span class="cl-palette__text">
                <strong>{{ item.label }}</strong>
                <small v-if="item.hint">{{ item.hint }}</small>
              </span>
              <v-icon size="14" class="cl-palette__enter">mdi-corner-down-left</v-icon>
            </li>
          </ul>
          <div v-else class="cl-palette__empty">
            <v-icon size="22">mdi-text-search</v-icon>
            <span>No matches for “{{ query }}”</span>
          </div>
          <footer class="cl-palette__foot">
            <span><kbd class="cl-kbd">↑</kbd><kbd class="cl-kbd">↓</kbd> navigate</span>
            <span><kbd class="cl-kbd">↵</kbd> open</span>
            <span><kbd class="cl-kbd">Esc</kbd> close</span>
          </footer>
        </div>
      </v-dialog>

      <v-snackbar v-model="snack.show" :color="snack.color" location="top" timeout="4000" rounded="lg">
        {{ snack.text }}
      </v-snackbar>
    </div>
  </div>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'
import { useThemeStore } from '~/stores/theme'

const auth = useAuthStore()
const themeStore = useThemeStore()
const { $api } = useNuxtApp()

// ── Clinic network (HQ + branches) ────────────────────────────────
const siteCtx = useClinicSite()
const siteList = siteCtx.sites
const siteId = siteCtx.activeSiteId
const siteLabel = siteCtx.activeLabel

function setSite(id) {
  siteCtx.setActiveSite(id)
  drill.value = null
  load()
}

// ── State ──────────────────────────────────────────────────────────
const loading = ref(false)
const data = ref(null)
const rangeKey = ref('30d')
const metric = ref('appointments')
const scheduleFilter = ref('all')
const drill = ref(null)

const now = ref(Date.now())
const autoRefresh = ref(true)
const countdown = ref(90)
const AUTO_REFRESH_SECONDS = 90
const isFullscreen = ref(false)
let timer = null

const paletteOpen = ref(false)
const query = ref('')
const paletteIndex = ref(0)
const paletteInput = ref(null)

const snack = reactive({ show: false, color: 'error', text: '' })

const rangeOptions = [
  { key: 'today', label: 'Today', days: 1 },
  { key: '7d', label: '7 days', days: 7 },
  { key: '30d', label: '30 days', days: 30 },
  { key: '90d', label: '90 days', days: 90 },
]

const metrics = [
  { key: 'appointments', label: 'Appointments' },
  { key: 'consultations', label: 'Consultations' },
  { key: 'patients', label: 'Patients' },
  { key: 'revenue', label: 'Revenue' },
]

const scheduleFilters = [
  { key: 'all', label: 'All' },
  { key: 'scheduled', label: 'Scheduled' },
  { key: 'in_progress', label: 'In room' },
  { key: 'completed', label: 'Done' },
]

const actions = [
  { icon: 'mdi-human-queue', label: 'Front desk', to: '/clinics/front-desk', accent: '#f97316' },
  { icon: 'mdi-account-plus', label: 'Register patient', to: '/clinics/patients/new', accent: '#2f6dff' },
  { icon: 'mdi-calendar-plus', label: 'Book appointment', to: '/clinics/appointments/new', accent: '#0ea5e9' },
  { icon: 'mdi-stethoscope', label: 'Start consultation', to: '/clinics/consultations/new', accent: '#10b981' },
  { icon: 'mdi-heart-pulse', label: 'Triage patient', to: '/clinics/triage/new', accent: '#ef4444' },
  { icon: 'mdi-pill', label: 'Write prescription', to: '/clinics/prescriptions/new', accent: '#a855f7' },
  { icon: 'mdi-flask-outline', label: 'Order lab test', to: '/clinics/lab-orders/new', accent: '#f59e0b' },
  { icon: 'mdi-receipt-text-plus', label: 'Create invoice', to: '/clinics/invoices/new', accent: '#14b8a6' },
  { icon: 'mdi-chart-arc', label: 'Analytics', to: '/clinics/analytics', accent: '#6366f1' },
]

// ── Derived ────────────────────────────────────────────────────────
const kpis = computed(() => data.value?.kpis || {})
const deltas = computed(() => data.value?.deltas || {})
const trend = computed(() => data.value?.trend || { dates: [] })
const pipeline = computed(() => data.value?.pipeline || [])
const revenue = computed(() => data.value?.revenue || { by_status: [] })
const appointments = computed(() => data.value?.appointments || { today: [], by_status: [] })
const triage = computed(() => data.value?.triage || { by_acuity: [], open: 0, critical: 0 })
const lab = computed(() => data.value?.lab || { by_status: [] })
const pharmacy = computed(() => data.value?.pharmacy || { by_status: [] })
const careTeam = computed(() => data.value?.care_team || [])
const departments = computed(() => data.value?.departments || [])
const wards = computed(() => data.value?.wards || null)
const alerts = computed(() => data.value?.alerts || [])
const activity = computed(() => data.value?.activity || [])

// ── Security & settings ────────────────────────────────────────────
const security = ref(null)
const securityEvents = ref([])
const staffAccounts = ref([])
const securityLoading = ref(false)
const securityError = ref('')
const exportingAudit = ref(false)

const policyDefaults = {
  mfa_required: false,
  log_patient_access: true,
  require_override_reason: true,
  restrict_export: true,
  idle_timeout: 30,
  retention_days: 180,
  reminder_hours: 24,
}

const policy = reactive({ ...policyDefaults })
const policySavedJson = ref(JSON.stringify(policyDefaults))
const policySaving = ref(false)
const policySavedLabel = ref('just now')

const policyToggles = [
  {
    key: 'mfa_required',
    label: 'Require MFA for clinical staff',
    hint: 'Two-factor challenge on every new device',
  },
  {
    key: 'log_patient_access',
    label: 'Log every patient record view',
    hint: 'Writes an audit entry when a chart is opened',
  },
  {
    key: 'require_override_reason',
    label: 'Reason required for overrides',
    hint: 'Staff must justify breaking a clinical rule',
  },
  {
    key: 'restrict_export',
    label: 'Restrict bulk exports',
    hint: 'Only clinic admins may export patient data',
  },
]

const idleOptions = [
  { label: '15 minutes', value: 15 },
  { label: '30 minutes', value: 30 },
  { label: '1 hour', value: 60 },
  { label: '2 hours', value: 120 },
]

const retentionOptions = [90, 180, 365, 730].map(d => ({ label: `${d} days`, value: d }))

const reminderOptions = [1, 6, 12, 24, 48].map(h => ({ label: `${h} hours before`, value: h }))

const settingsLinks = [
  { icon: 'mdi-shield-lock-outline', label: 'Security centre', hint: 'Posture, policy and access', to: '/clinics/security', accent: '#2f6dff' },
  { icon: 'mdi-store', label: 'Drug stores', hint: 'Pharmacy outlets and dispensing', to: '/clinics/drug-stores', accent: '#14b8a6' },
  { icon: 'mdi-account-hard-hat', label: 'Staff & access', hint: 'Invite, suspend and assign roles', to: '/clinics/staff', accent: '#6366f1' },
  { icon: 'mdi-shield-search', label: 'Audit trail', hint: 'Every recorded action', to: '/clinics/audit', accent: '#8b5cf6' },
  { icon: 'mdi-account-key', label: 'Patient consents', hint: 'Signed permissions on file', to: '/clinics/consents', accent: '#10b981' },
  { icon: 'mdi-share-variant', label: 'Data sharing', hint: 'Who can see this clinic data', to: '/clinics/data-sharing', accent: '#0ea5e9' },
  { icon: 'mdi-cog', label: 'Clinic settings', hint: 'Profile, hours and billing', to: '/clinics/settings', accent: '#f59e0b' },
  { icon: 'mdi-database-plus', label: 'Demo data', hint: 'Load a sample register', to: '/clinics/seed-data', accent: '#a855f7' },
]

const todayLabel = new Date().toLocaleDateString('en-US', {
  weekday: 'short', month: 'short', day: 'numeric',
})

const greeting = computed(() => {
  const h = new Date().getHours()
  if (h < 12) return 'Good morning'
  if (h < 17) return 'Good afternoon'
  return 'Good evening'
})

const rangeLabel = computed(
  () => rangeOptions.find(r => r.key === rangeKey.value)?.label?.toLowerCase() || 'today',
)

const collectionRate = computed(() => Number(revenue.value.collection_rate || 0))

const heroSubtitle = computed(() => {
  if (!data.value) return 'Loading clinic operations…'
  const todayCount = kpis.value.appointments_today || 0
  const consult = kpis.value.consultations || 0
  if (todayCount) {
    return `${todayCount} appointment${todayCount === 1 ? '' : 's'} on today's board and ${consult} consultation${consult === 1 ? '' : 's'} recorded in ${rangeLabel.value}.`
  }
  return `${consult} consultation${consult === 1 ? '' : 's'} recorded in ${rangeLabel.value}. The board is clear for new arrivals.`
})

const isDark = computed(() => themeStore.mode === 'dark')

const isMac = computed(() => {
  if (!import.meta.client) return false
  return /mac|iphone|ipad|ipod/i.test(navigator.platform || navigator.userAgent || '')
})

/** Module row under the hero — the palette tile is rendered separately. */
const modules = computed(() => [
  {
    key: 'front-desk', icon: 'mdi-human-queue', label: 'Front desk', to: '/clinics/front-desk',
    meta: `${fmt(kpis.value.appointments_today ?? 0)} arrivals`,
  },
  {
    key: 'appointments', icon: 'mdi-calendar-check', label: 'Appointments', to: '/clinics/appointments',
    meta: `${fmt(appointments.value.today?.length ?? 0)} on board`,
  },
  {
    key: 'consultations', icon: 'mdi-stethoscope', label: 'Consultations', to: '/clinics/consultations',
    meta: `${fmt(kpis.value.consultations ?? 0)} signed`,
  },
  {
    key: 'triage', icon: 'mdi-heart-pulse', label: 'Triage', to: '/clinics/triage',
    meta: `${fmt(triage.value.open ?? 0)} queued`,
    tone: triage.value.critical ? 'danger' : '',
  },
  {
    key: 'patients', icon: 'mdi-account-multiple', label: 'Patients', to: '/clinics/patients',
    meta: `${fmt(kpis.value.patients_total ?? 0)} registered`,
  },
  {
    key: 'lab', icon: 'mdi-flask-outline', label: 'Lab orders', to: '/clinics/lab-orders',
    meta: `${fmt(lab.value.pending ?? 0)} awaiting`,
    tone: lab.value.pending ? 'warn' : '',
  },
  {
    key: 'pharmacy', icon: 'mdi-pill', label: 'Pharmacy', to: '/clinics/prescriptions',
    meta: `${fmt(pharmacy.value.open ?? 0)} scripts`,
    tone: pharmacy.value.open ? 'warn' : '',
  },
  {
    key: 'billing', icon: 'mdi-receipt-text-outline', label: 'Billing', to: '/clinics/invoices',
    meta: `${money(revenue.value.outstanding)} due`,
    tone: revenue.value.outstanding ? 'warn' : '',
  },
  {
    key: 'wards', icon: 'mdi-bed', label: 'Wards', to: '/clinics/wards',
    meta: wards.value ? `${wards.value.beds_occupied}/${wards.value.beds_total} beds` : 'Bed board',
  },
  {
    key: 'alerts', icon: 'mdi-bell-alert', label: 'Alerts', to: '/clinics/alerts',
    meta: `${fmt(kpis.value.alerts_open ?? 0)} open`,
    tone: kpis.value.alerts_open ? 'danger' : '',
  },
  {
    key: 'analytics', icon: 'mdi-chart-arc', label: 'Analytics', to: '/clinics/analytics',
    meta: 'Insights',
  },
])

const updatedLabel = computed(() => {
  if (!data.value?.generated_at) return ''
  return `updated ${timeAgo(data.value.generated_at)}`
})

const attention = computed(() => [
  { key: 'critical', icon: 'mdi-alert-octagon', label: 'Critical triage', count: triage.value.critical || 0, tone: 'danger' },
  { key: 'alerts', icon: 'mdi-bell-alert', label: 'Open escalations', count: kpis.value.alerts_open || 0, tone: 'danger' },
  { key: 'lab', icon: 'mdi-flask-outline', label: 'Lab awaiting', count: lab.value.pending || 0, tone: 'warn' },
  { key: 'rx', icon: 'mdi-pill', label: 'Open scripts', count: kpis.value.rx_open || 0, tone: 'warn' },
])

const kpiTiles = computed(() => [
  {
    title: "Today's appointments", value: fmt(kpis.value.appointments_today ?? 0),
    icon: 'mdi-calendar-clock', accent: '#2f6dff', soft: 'rgba(47,109,255,0.12)',
    sub: `${appointments.value.today?.length || 0} on the board`,
  },
  {
    title: 'Consultations', value: fmt(kpis.value.consultations ?? 0),
    icon: 'mdi-stethoscope', accent: '#10b981', soft: 'rgba(16,185,129,0.12)',
    delta: deltas.value.consultations, sub: 'Signed & drafted',
  },
  {
    title: 'Triage entries', value: fmt(kpis.value.triage ?? 0),
    icon: 'mdi-heart-pulse', accent: '#ef4444', soft: 'rgba(239,68,68,0.12)',
    delta: deltas.value.triage, sub: `${triage.value.open || 0} in queue`,
  },
  {
    title: 'New patients', value: fmt(kpis.value.patients_new ?? 0),
    icon: 'mdi-account-plus', accent: '#0ea5e9', soft: 'rgba(14,165,233,0.12)',
    delta: deltas.value.patients_new, sub: `${fmt(kpis.value.patients_total ?? 0)} total registered`,
  },
  {
    title: 'Revenue billed', value: money(kpis.value.revenue_billed),
    icon: 'mdi-cash-multiple', accent: '#14b8a6', soft: 'rgba(20,184,166,0.12)',
    delta: deltas.value.revenue_billed, sub: `${money(kpis.value.revenue_outstanding)} outstanding`,
  },
  {
    title: 'Collection rate', value: `${collectionRate.value}%`,
    icon: 'mdi-percent-circle-outline', accent: '#f59e0b', soft: 'rgba(245,158,11,0.12)',
    sub: `${money(revenue.value.collected)} collected`,
  },
  {
    title: 'Lab pending', value: fmt(lab.value.pending ?? 0),
    icon: 'mdi-flask-outline', accent: '#a855f7', soft: 'rgba(168,85,247,0.12)',
    sub: `${fmt(lab.value.today ?? 0)} ordered today`,
  },
  {
    title: 'Open alerts', value: fmt(kpis.value.alerts_open ?? 0),
    icon: 'mdi-bell-alert', accent: '#e11d48', soft: 'rgba(225,29,72,0.12)',
    sub: `${triage.value.critical || 0} critical triage`,
  },
])

const metricLabel = computed(() => {
  const label = metrics.find(m => m.key === metric.value)?.label || 'Activity'
  return `${label} trend`
})

const metricSeries = computed(() => trend.value[metric.value] || [])
const metricTotal = computed(() =>
  metricSeries.value.reduce((a, b) => a + (Number(b) || 0), 0))

const metricColor = computed(() => ({
  appointments: '#2f6dff',
  consultations: '#10b981',
  patients: '#0ea5e9',
  revenue: '#f59e0b',
})[metric.value] || '#2f6dff')

/** Compare the newest half of the window with the older half. */
const trendDelta = computed(() => {
  const series = metricSeries.value
  if (series.length < 4) return 0
  const mid = Math.floor(series.length / 2)
  const older = series.slice(0, mid).reduce((a, b) => a + (Number(b) || 0), 0)
  const newer = series.slice(mid).reduce((a, b) => a + (Number(b) || 0), 0)
  if (!older) return newer ? 100 : 0
  return Number((((newer - older) / older) * 100).toFixed(1))
})

const filteredSchedule = computed(() => {
  const rows = appointments.value.today || []
  if (scheduleFilter.value === 'all') return rows
  return rows.filter(a => a.status === scheduleFilter.value)
})

const topDepartments = computed(() =>
  [...departments.value].filter(d => d.appointments > 0).slice(0, 6))

const maxDeptAppointments = computed(() =>
  Math.max(1, ...topDepartments.value.map(d => d.appointments)))

const maxEsi = computed(() =>
  Math.max(1, ...(triage.value.by_acuity || []).map(a => a.count)))

// ── Security derived ───────────────────────────────────────────────
const secKpis = computed(() => security.value?.kpis || {})
const secSignals = computed(() => security.value?.signals || [])
const secModules = computed(() => (security.value?.module_mix || []).slice(0, 5))

const secTiles = computed(() => {
  const k = secKpis.value
  return [
    { label: 'Audited events', value: fmt(k.total), icon: 'mdi-database-eye-outline', accent: '#2f6dff', soft: 'rgba(47,109,255,0.1)' },
    { label: 'Last 24 hours', value: fmt(k.last_24h), icon: 'mdi-clock-fast', accent: '#0ea5e9', soft: 'rgba(14,165,233,0.1)' },
    { label: 'Critical', value: fmt(k.critical), icon: 'mdi-alert-octagon-outline', accent: '#ef4444', soft: 'rgba(239,68,68,0.1)' },
    { label: 'Failed requests', value: fmt(k.failures), icon: 'mdi-cancel', accent: '#f59e0b', soft: 'rgba(245,158,11,0.1)' },
    { label: 'Active actors', value: fmt(k.distinct_actors), icon: 'mdi-account-multiple-outline', accent: '#6366f1', soft: 'rgba(99,102,241,0.1)' },
    { label: 'Retention', value: `${fmt(k.retention_days)}d`, icon: 'mdi-history', accent: '#14b8a6', soft: 'rgba(20,184,166,0.1)' },
  ]
})

const staffActive = computed(() => staffAccounts.value.filter(u => u.is_active).length)

const roleMix = computed(() => {
  const counts = {}
  for (const u of staffAccounts.value) {
    const role = u.role || 'unassigned'
    counts[role] = (counts[role] || 0) + 1
  }
  return Object.entries(counts)
    .map(([role, count]) => ({ role, count }))
    .sort((a, b) => b.count - a.count)
})

const maxRoleCount = computed(() => Math.max(1, ...roleMix.value.map(r => r.count)))

function rolePct(count) {
  return Math.max(4, Math.round(((count || 0) / maxRoleCount.value) * 100))
}

/**
 * Composite posture score — starts at 100 and subtracts for critical events,
 * failed requests and high-severity signals in the window. Deliberately
 * coarse: this is an at-a-glance indicator, not an audit of the audit.
 */
const posture = computed(() => {
  const k = secKpis.value
  const high = secSignals.value.filter(s => s.severity === 'high').length
  let score = 100
  score -= Math.min(30, (Number(k.critical) || 0) * 4)
  score -= Math.min(18, Math.floor((Number(k.failures) || 0) / 3))
  score -= high * 7
  score = Math.max(15, Math.min(100, Math.round(score)))
  const tone = score >= 85 ? 'ok' : score >= 65 ? 'warn' : 'danger'
  const label = score >= 85 ? 'Strong' : score >= 65 ? 'Watch' : 'At risk'
  return { score, tone, label }
})

const policyDirty = computed(() => JSON.stringify({ ...policy }) !== policySavedJson.value)

const paletteItems = computed(() => {
  const q = query.value.trim().toLowerCase()
  const pages = actions.map(a => ({
    key: `a-${a.label}`, icon: a.icon, label: a.label, hint: a.to, to: a.to,
  }))
  const patients = (appointments.value.today || []).map(p => ({
    key: `p-${p.id}`, icon: 'mdi-account', label: p.patient_name,
    hint: `${p.patient_number || 'Patient'} · ${p.time || ''}`.trim(),
    to: `/clinics/patients/${p.patient_id}`,
  }))
  const doctors = careTeam.value.map(d => ({
    key: `d-${d.id}`, icon: 'mdi-stethoscope', label: d.name,
    hint: `${d.consultations} consultations`, to: '/clinics/doctors',
  }))
  const settings = settingsLinks.map(s => ({
    key: `s-${s.to}`, icon: s.icon, label: s.label, hint: s.hint, to: s.to,
  }))
  const all = [...pages, ...patients, ...doctors, ...settings]
  if (!q) return all.slice(0, 9)
  return all.filter(i => `${i.label} ${i.hint || ''}`.toLowerCase().includes(q)).slice(0, 12)
})

// ── Formatting ─────────────────────────────────────────────────────
function fmt(n) {
  return (Number(n) || 0).toLocaleString('en-US')
}

function compact(n) {
  const v = Number(n) || 0
  if (Math.abs(v) >= 1_000_000) return `${(v / 1_000_000).toFixed(1)}M`
  if (Math.abs(v) >= 1_000) return `${(v / 1_000).toFixed(v >= 10_000 ? 0 : 1)}K`
  return String(Math.round(v))
}

function money(n) {
  const v = Number(n) || 0
  if (!v) return 'KES 0'
  if (Math.abs(v) >= 1_000_000) return `KES ${(v / 1_000_000).toFixed(1)}M`
  if (Math.abs(v) >= 1_000) return `KES ${(v / 1_000).toFixed(0)}K`
  return `KES ${v.toFixed(0)}`
}

function pretty(s) {
  if (!s) return '—'
  return String(s).replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())
}

// ── Delta pills ────────────────────────────────────────────────────
function deltaTone(value) {
  const n = Number(value)
  if (value === null || value === undefined || Number.isNaN(n) || n === 0) return 'flat'
  return n > 0 ? 'up' : 'down'
}

function deltaText(value) {
  const n = Number(value)
  if (value === null || value === undefined || Number.isNaN(n)) return '—'
  const arrow = n > 0 ? '↑' : n < 0 ? '↓' : '→'
  return `${arrow} ${Math.abs(n).toFixed(Math.abs(n) < 10 ? 1 : 0)}%`
}

function initials(name) {
  return String(name || '?')
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map(p => p[0].toUpperCase())
    .join('')
}

function timeAgo(iso) {
  if (!iso) return ''
  const ts = new Date(iso).getTime()
  if (Number.isNaN(ts)) return ''
  const mins = Math.floor(Math.max(0, now.value - ts) / 60000)
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins}m ago`
  const hours = Math.floor(mins / 60)
  if (hours < 24) return `${hours}h ago`
  const days = Math.floor(hours / 24)
  if (days < 30) return `${days}d ago`
  return new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
}

function esiPct(count) {
  return Math.max(3, Math.round(((count || 0) / maxEsi.value) * 100))
}

function deptPct(count) {
  return Math.max(3, Math.round(((count || 0) / maxDeptAppointments.value) * 100))
}

function stageTone(key) {
  return {
    scheduled: 'muted', checked_in: 'info', triaged: 'warn', seen: 'primary',
    referred: 'violet', billed: 'teal', completed: 'ok', lost: 'danger',
  }[key] || 'muted'
}

function invoiceColor(status) {
  return {
    paid: '#10b981', sent: '#2f6dff', partially_paid: '#f59e0b',
    overdue: '#ef4444', draft: '#94a3b8', cancelled: '#cbd5e1',
  }[status] || '#94a3b8'
}

function labTone(status) {
  return {
    pending: 'warn', sample_collected: 'info', processing: 'primary',
    in_progress: 'primary', completed: 'ok', cancelled: 'danger',
  }[status] || 'muted'
}

function labIcon(status) {
  return {
    pending: 'mdi-clock-outline', sample_collected: 'mdi-test-tube',
    processing: 'mdi-flask-outline', in_progress: 'mdi-flask-outline',
    completed: 'mdi-check-circle', cancelled: 'mdi-close-circle',
  }[status] || 'mdi-circle-medium'
}

function rxTone(status) {
  return {
    active: 'ok', sent_to_exchange: 'info', dispensed: 'primary', cancelled: 'danger',
  }[status] || 'muted'
}

function rxIcon(status) {
  return {
    active: 'mdi-pill', sent_to_exchange: 'mdi-send',
    dispensed: 'mdi-check-circle', cancelled: 'mdi-close-circle',
  }[status] || 'mdi-circle-medium'
}

// ── Data ───────────────────────────────────────────────────────────
async function load() {
  loading.value = true
  try {
    const { data: payload } = await $api.get('/reports/clinic-dashboard/', {
      params: { range: rangeKey.value, trend_days: 14, ...siteCtx.siteParams.value },
    })
    data.value = payload
    countdown.value = AUTO_REFRESH_SECONDS
  } catch (err) {
    snack.text = err?.response?.data?.detail || 'Failed to load the clinic dashboard.'
    snack.color = 'error'
    snack.show = true
  } finally {
    loading.value = false
  }
}

function setRange(key) {
  if (rangeKey.value === key) return
  rangeKey.value = key
  drill.value = null
  load()
}

// ── Security & settings ────────────────────────────────────────────
function fetchRows(res) {
  const payload = res?.data
  if (Array.isArray(payload)) return payload
  return payload?.results || []
}

async function loadSecurity() {
  securityLoading.value = true
  securityError.value = ''
  await Promise.allSettled([
    $api.get('/audit/events/security-overview/', { params: { since_days: 30 } })
      .then((res) => { security.value = res.data })
      .catch(() => {
        security.value = null
        securityError.value = 'Security insights need administrator access.'
      }),
    $api.get('/audit/events/', { params: { page_size: 6, ordering: '-created_at' } })
      .then((res) => { securityEvents.value = fetchRows(res).slice(0, 6) })
      .catch(() => { securityEvents.value = [] }),
    $api.get('/auth/users/', { params: { page_size: 500 } })
      .then((res) => { staffAccounts.value = fetchRows(res) })
      .catch(() => { staffAccounts.value = [] }),
  ])
  securityLoading.value = false
}

function policyStorageKey() {
  return `adheremed.clinic.security.${auth.tenantSchema || 'default'}`
}

function loadPolicy() {
  if (!import.meta.client) return
  try {
    const raw = localStorage.getItem(policyStorageKey())
    if (raw) Object.assign(policy, { ...policyDefaults, ...JSON.parse(raw) })
  } catch {
    /* corrupt or blocked storage — keep the defaults */
  }
  policySavedJson.value = JSON.stringify({ ...policy })
}

function togglePolicy(key) {
  policy[key] = !policy[key]
}

async function savePolicy() {
  policySaving.value = true
  try {
    if (import.meta.client) {
      localStorage.setItem(policyStorageKey(), JSON.stringify({ ...policy }))
    }
    policySavedJson.value = JSON.stringify({ ...policy })
    policySavedLabel.value = new Date().toLocaleTimeString('en-US', {
      hour: '2-digit', minute: '2-digit',
    })
    snack.text = 'Security policy saved for this clinic.'
    snack.color = 'success'
    snack.show = true
  } catch {
    snack.text = 'Could not save the policy in this browser.'
    snack.color = 'error'
    snack.show = true
  } finally {
    policySaving.value = false
  }
}

async function exportAudit() {
  exportingAudit.value = true
  try {
    const res = await $api.get('/audit/events/export/', {
      params: { fmt: 'csv', limit: 5000, since_days: 30 },
      responseType: 'blob',
    })
    const blob = new Blob([res.data], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `clinic-audit-${new Date().toISOString().slice(0, 10)}.csv`
    document.body.appendChild(link)
    link.click()
    link.remove()
    URL.revokeObjectURL(url)
    snack.text = 'Audit export downloaded.'
    snack.color = 'success'
    snack.show = true
  } catch {
    snack.text = 'Export failed — administrator access is required.'
    snack.color = 'error'
    snack.show = true
  } finally {
    exportingAudit.value = false
  }
}

// ── Timers ─────────────────────────────────────────────────────────
function tick() {
  now.value = Date.now()
  if (!autoRefresh.value || paletteOpen.value || loading.value) return
  countdown.value -= 1
  if (countdown.value <= 0) load()
}

function toggleAutoRefresh() {
  autoRefresh.value = !autoRefresh.value
  countdown.value = AUTO_REFRESH_SECONDS
}

// ── Theme / fullscreen ─────────────────────────────────────────────
function toggleTheme() {
  themeStore.setMode(isDark.value ? 'light' : 'dark')
}

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
  if (!document.documentElement.requestFullscreen) {
    snack.text = 'Fullscreen is not supported in this browser.'
    snack.color = 'error'
    snack.show = true
    return
  }
  document.documentElement.requestFullscreen().catch(() => {
    snack.text = 'Your browser blocked fullscreen. Try again or press F11.'
    snack.color = 'error'
    snack.show = true
  })
}

// ── Command palette ────────────────────────────────────────────────
function openPalette() {
  query.value = ''
  paletteIndex.value = 0
  paletteOpen.value = true
  nextTick(() => paletteInput.value?.focus())
}

function movePalette(step) {
  const n = paletteItems.value.length
  if (!n) return
  paletteIndex.value = (paletteIndex.value + step + n) % n
}

function runItem(item) {
  paletteOpen.value = false
  if (item?.to) navigateTo(item.to)
}

function runSelection() {
  runItem(paletteItems.value[paletteIndex.value])
}

function onKeydown(e) {
  if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
    e.preventDefault()
    if (!paletteOpen.value) openPalette()
    return
  }
  if (e.key === 'Escape' && paletteOpen.value) paletteOpen.value = false
}

watch(query, () => { paletteIndex.value = 0 })

onMounted(() => {
  themeStore.load()
  loadPolicy()
  tick()
  timer = setInterval(tick, 1000)
  window.addEventListener('keydown', onKeydown)
  document.addEventListener('fullscreenchange', syncFullscreen)
  syncFullscreen()
  // Restore the clinic selection before the first fetch so the dashboard
  // opens on the clinic the user was last looking at.
  siteCtx.restore()
  siteCtx.loadSites()
  load()
  loadSecurity()
})

onBeforeUnmount(() => {
  if (timer) clearInterval(timer)
  window.removeEventListener('keydown', onKeydown)
  document.removeEventListener('fullscreenchange', syncFullscreen)
})
</script>

<style scoped>
/* ══════════════════════════════════════════════════════════
   Tokens
   ══════════════════════════════════════════════════════════ */
.cl-page {
  --cl-bg: #eef3fb;
  --cl-surface: #ffffff;
  --cl-surface-2: #f6f9fe;
  --cl-glass: rgba(255, 255, 255, 0.74);
  --cl-line: rgba(15, 23, 42, 0.08);
  --cl-line-2: rgba(15, 23, 42, 0.14);
  --cl-ink: #0a0f1f;
  --cl-ink-2: #334155;
  --cl-muted: #64748b;
  --cl-primary: #2f6dff;
  --cl-deep: #143ce1;
  --cl-cyan: #37d6ff;
  --cl-shadow-1: 0 1px 2px rgba(15, 23, 42, 0.04), 0 14px 30px -20px rgba(15, 23, 42, 0.3);
  --cl-shadow-2: 0 28px 60px -28px rgba(15, 23, 42, 0.42);
  --cl-radius: 20px;

  min-height: 100vh;
  position: relative;
  overflow-x: hidden;
  background: var(--cl-bg);
  color: var(--cl-ink);
  font-feature-settings: 'tnum' 1;
  -webkit-font-smoothing: antialiased;
}
:global(.v-theme--dark .cl-page) {
  --cl-bg: #070c1a;
  --cl-surface: #0f172b;
  --cl-surface-2: #131d34;
  --cl-glass: rgba(15, 23, 43, 0.66);
  --cl-line: rgba(148, 163, 184, 0.14);
  --cl-line-2: rgba(148, 163, 184, 0.24);
  --cl-ink: #eef2ff;
  --cl-ink-2: #cbd5e1;
  --cl-muted: #93a3bb;
  --cl-shadow-1: 0 1px 2px rgba(0, 0, 0, 0.45), 0 16px 34px -22px rgba(0, 0, 0, 0.9);
  --cl-shadow-2: 0 30px 70px -30px rgba(0, 0, 0, 0.95);
}

/* ══ Ambient ══ */
.cl-ambient { position: fixed; inset: 0; z-index: 0; pointer-events: none; overflow: hidden; }
.cl-orb { position: absolute; border-radius: 50%; filter: blur(90px); opacity: 0.5; }
.cl-orb--1 {
  top: -240px; right: -160px; width: 560px; height: 560px;
  background: radial-gradient(circle, rgba(47, 109, 255, 0.5), transparent 65%);
}
.cl-orb--2 {
  top: 34%; left: -220px; width: 520px; height: 520px;
  background: radial-gradient(circle, rgba(20, 184, 166, 0.32), transparent 65%);
}
.cl-grid {
  position: absolute; inset: 0;
  background-image:
    linear-gradient(rgba(15, 23, 42, 0.05) 1px, transparent 1px),
    linear-gradient(90deg, rgba(15, 23, 42, 0.05) 1px, transparent 1px);
  background-size: 64px 64px;
  mask-image: radial-gradient(circle at 50% 0%, #000 0%, transparent 72%);
  -webkit-mask-image: radial-gradient(circle at 50% 0%, #000 0%, transparent 72%);
}
:global(.v-theme--dark .cl-grid) {
  background-image:
    linear-gradient(rgba(148, 163, 184, 0.09) 1px, transparent 1px),
    linear-gradient(90deg, rgba(148, 163, 184, 0.09) 1px, transparent 1px);
}

/* ══ Shell ══ */
.cl-shell { position: relative; z-index: 1; width: 100%; max-width: none; padding: 18px 16px 64px; }
@media (min-width: 960px) {
  .cl-shell { padding: 24px clamp(20px, 1.6vw, 40px) 80px; }
}

/* ══ Hero — calm surface panel, mirrors the /clinics/equipment header ══ */
.cl-hero {
  position: relative;
  overflow: hidden;
  border-radius: 18px;
  padding: 17px 20px 12px;
  color: var(--cl-ink);
  background:
    radial-gradient(120% 140% at 100% 0%, color-mix(in srgb, var(--cl-primary) 7%, transparent), transparent 58%),
    var(--cl-surface);
  border: 1px solid var(--cl-line);
  box-shadow: 0 10px 30px rgba(15, 23, 42, 0.055);
  animation: cl-rise 0.5s cubic-bezier(0.16, 1, 0.3, 1) both;
}
.cl-hero__rule {
  position: absolute;
  inset: 0 auto 0 0;
  width: 4px;
  pointer-events: none;
  background: linear-gradient(
    180deg,
    var(--cl-primary),
    color-mix(in srgb, var(--cl-primary) 18%, transparent)
  );
}
.cl-hero__top {
  position: relative;
  z-index: 1;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
}
.cl-hero__identity { display: flex; align-items: center; gap: 14px; min-width: 0; }
.cl-hero__icon {
  width: 50px;
  height: 50px;
  border-radius: 15px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  overflow: hidden;
  color: var(--cl-primary);
  background: color-mix(in srgb, var(--cl-primary) 12%, transparent);
  border: 1px solid color-mix(in srgb, var(--cl-primary) 22%, transparent);
}
.cl-hero__icon img { width: 100%; height: 100%; object-fit: cover; }
.cl-hero__copy { min-width: 0; }
.cl-hero__eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: var(--cl-muted);
}
.cl-hero__pulse {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  flex-shrink: 0;
  background: #22c55e;
  animation: cl-pulse 2s infinite;
}
@keyframes cl-pulse {
  0% { box-shadow: 0 0 0 0 rgba(34, 197, 94, 0.5); }
  70% { box-shadow: 0 0 0 6px rgba(34, 197, 94, 0); }
  100% { box-shadow: 0 0 0 0 rgba(34, 197, 94, 0); }
}
.cl-hero__title {
  margin: 3px 0 2px;
  font-size: 24px;
  line-height: 1.15;
  font-weight: 800;
  letter-spacing: -0.4px;
  color: var(--cl-ink);
}
.cl-hero__sub {
  margin: 0;
  font-size: 12.5px;
  line-height: 1.45;
  color: var(--cl-muted);
  max-width: 90ch;
}
.cl-hero__actions { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; }
.cl-hero__foot {
  position: relative;
  z-index: 1;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 7px;
  margin-top: 13px;
  padding-top: 11px;
  border-top: 1px solid var(--cl-line);
}
.cl-hero__chip {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  height: 25px;
  padding: 0 9px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 700;
  color: var(--cl-muted);
  background: var(--cl-surface-2);
  border: 1px solid var(--cl-line);
  white-space: nowrap;
}
.cl-hero__chip b { font-weight: 800; color: var(--cl-ink); }
.cl-hero__chip :deep(.v-icon) { color: inherit !important; opacity: 0.85; }
.cl-hero__chip--warn {
  color: #b45309;
  background: rgba(245, 158, 11, 0.09);
  border-color: rgba(245, 158, 11, 0.3);
}
.cl-hero__chip--danger {
  color: #b91c1c;
  background: rgba(239, 68, 68, 0.08);
  border-color: rgba(239, 68, 68, 0.26);
}
.cl-hero__chip--warn b,
.cl-hero__chip--danger b { color: inherit; }
.cl-hero__chip--muted {
  color: var(--cl-muted);
  background: transparent;
  border-color: var(--cl-line);
}
.cl-hero__chip--muted b { color: var(--cl-muted); }
.cl-hero__chip--link {
  text-decoration: none;
  cursor: pointer;
  transition: background 0.16s, border-color 0.16s, transform 0.16s;
}
.cl-hero__chip--link:hover {
  transform: translateY(-1px);
  background: var(--cl-surface);
  border-color: var(--cl-line-2);
}
:global(.v-theme--dark .cl-hero) {
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.45), 0 16px 34px -22px rgba(0, 0, 0, 0.9);
}
:global(.v-theme--dark .cl-hero__chip--warn) {
  color: #fcd34d;
  background: rgba(245, 158, 11, 0.16);
  border-color: rgba(245, 158, 11, 0.36);
}
:global(.v-theme--dark .cl-hero__chip--danger) {
  color: #fca5a5;
  background: rgba(239, 68, 68, 0.16);
  border-color: rgba(239, 68, 68, 0.36);
}
.cl-hero__stamp {
  margin-left: auto;
  font-size: 10.5px;
  font-weight: 700;
  color: var(--cl-muted);
  white-space: nowrap;
}

/* Hero action buttons — same tiers as the equipment header */
.cl-hero__actions :deep(.v-btn) {
  height: 36px !important;
  min-height: 36px !important;
  padding: 0 12px !important;
  border-radius: 10px !important;
  font-family: inherit !important;
  font-size: 12.5px !important;
  font-weight: 700 !important;
  letter-spacing: 0 !important;
  text-transform: none !important;
  box-shadow: none !important;
}
.cl-btn {
  border: 1px solid var(--cl-line) !important;
  background: transparent !important;
  color: var(--cl-ink) !important;
  transition: background 0.15s ease, border-color 0.15s ease, transform 0.15s ease !important;
}
.cl-btn:hover {
  background: var(--cl-surface-2) !important;
  border-color: var(--cl-line-2) !important;
  transform: translateY(-1px);
}
.cl-btn :deep(.v-icon) { color: var(--cl-muted) !important; opacity: 1 !important; }
.cl-btn--on {
  background: color-mix(in srgb, var(--cl-primary) 9%, transparent) !important;
  border-color: color-mix(in srgb, var(--cl-primary) 34%, transparent) !important;
  color: var(--cl-primary) !important;
}
.cl-btn--on :deep(.v-icon) { color: var(--cl-primary) !important; }
.cl-btn--primary {
  background: var(--cl-primary) !important;
  color: #fff !important;
  border-color: transparent !important;
  box-shadow: 0 7px 18px color-mix(in srgb, var(--cl-primary) 32%, transparent) !important;
}
.cl-btn--primary:hover {
  filter: brightness(1.05);
  background: var(--cl-primary) !important;
}
.cl-btn--primary :deep(.v-icon) { color: #fff !important; opacity: 1 !important; }

/* ── Delta pill ── */
.cl-delta {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  padding: 2px 7px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 800;
  line-height: 1.5;
}
.cl-delta--up { color: #047857; background: rgba(16, 185, 129, 0.14); }
.cl-delta--down { color: #b91c1c; background: rgba(239, 68, 68, 0.13); }
.cl-delta--flat { color: var(--cl-muted); background: rgba(148, 163, 184, 0.16); }
:global(.v-theme--dark .cl-delta--up) { color: #6ee7b7; background: rgba(16, 185, 129, 0.18); }
:global(.v-theme--dark .cl-delta--down) { color: #fca5a5; background: rgba(239, 68, 68, 0.18); }

/* ══ Module strip — palette pinned, modules loop right → left ══ */
.cl-modules {
  display: flex;
  align-items: stretch;
  gap: 8px;
  margin-top: 12px;
}
.cl-mod {
  flex: 0 0 auto;
  width: 196px;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 9px 12px;
  border-radius: 11px;
  border: 1px solid var(--cl-line);
  background: var(--cl-surface);
  text-align: left;
  text-decoration: none;
  cursor: pointer;
  appearance: none;
  font-family: inherit;
  font-size: 12px;
  font-weight: 600;
  color: var(--cl-ink);
  transition: transform 0.15s ease, box-shadow 0.15s ease, border-color 0.15s ease;
}
.cl-mod:hover {
  transform: translateY(-1px);
  box-shadow: 0 8px 18px rgba(15, 23, 42, 0.08);
  border-color: color-mix(in srgb, var(--cl-primary) 32%, transparent);
}
.cl-mod:focus-visible {
  outline: 2px solid var(--cl-primary);
  outline-offset: 2px;
}
.cl-mod :deep(.v-icon) {
  color: var(--cl-primary);
  flex-shrink: 0;
}
.cl-mod__label {
  flex: 1;
  min-width: 0;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.cl-mod__kbd {
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.4px;
  padding: 2px 6px;
  border-radius: 5px;
  color: color-mix(in srgb, var(--cl-ink) 55%, transparent);
  background: color-mix(in srgb, var(--cl-ink) 6%, transparent);
}
.cl-mod__meta {
  font-size: 10.5px;
  font-weight: 700;
  color: color-mix(in srgb, var(--cl-ink) 50%, transparent);
  white-space: nowrap;
}
.cl-mod__meta--warn { color: #b45309; }
.cl-mod__meta--danger { color: #e11d48; }

/* The palette tile never moves — it sits outside the scrolling viewport. */
.cl-mod--pinned {
  position: relative;
  z-index: 2;
  border-color: color-mix(in srgb, var(--cl-primary) 30%, var(--cl-line));
  background: color-mix(in srgb, var(--cl-primary) 6%, var(--cl-surface));
  box-shadow: 6px 0 16px -12px rgba(15, 23, 42, 0.55);
}

/* Marquee viewport */
.cl-marquee {
  position: relative;
  flex: 1 1 auto;
  min-width: 0;
  overflow: hidden;
  -webkit-mask-image: linear-gradient(90deg, #000 0, #000 calc(100% - 44px), transparent 100%);
  mask-image: linear-gradient(90deg, #000 0, #000 calc(100% - 44px), transparent 100%);
}
.cl-marquee__track {
  display: flex;
  width: max-content;
  animation: cl-marquee 42s linear infinite;
  will-change: transform;
}
/* Two identical groups + matching padding = seamless wrap at -50%. */
.cl-marquee__group {
  display: flex;
  gap: 8px;
  padding-right: 8px;
}
.cl-marquee:hover .cl-marquee__track,
.cl-marquee:focus-within .cl-marquee__track {
  animation-play-state: paused;
}
@keyframes cl-marquee {
  from { transform: translateX(0); }
  to { transform: translateX(-50%); }
}
@media (prefers-reduced-motion: reduce) {
  .cl-marquee { overflow-x: auto; mask-image: none; -webkit-mask-image: none; }
  .cl-marquee__track { animation: none; }
  .cl-marquee__group[aria-hidden='true'] { display: none; }
}
@media (max-width: 600px) {
  .cl-mod { width: 168px; }
}
:global(.v-theme--dark .cl-mod:hover) { box-shadow: 0 8px 18px rgba(0, 0, 0, 0.55); }
:global(.v-theme--dark .cl-mod__meta--warn) { color: #fcd34d; }
:global(.v-theme--dark .cl-mod__meta--danger) { color: #fca5a5; }

/* ══ Attention strip ══ */
.cl-attention { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; margin-top: 18px; }
@media (min-width: 900px) { .cl-attention { grid-template-columns: repeat(4, minmax(0, 1fr)); } }
.cl-attn {
  --tone: #64748b; --tone-soft: rgba(100, 116, 139, 0.12);
  display: flex; align-items: center; gap: 12px;
  padding: 13px 14px; border-radius: 16px;
  border: 1px solid var(--cl-line); background: var(--cl-surface);
  box-shadow: var(--cl-shadow-1); text-align: left; cursor: pointer;
  transition: transform 0.25s cubic-bezier(0.16, 1, 0.3, 1), border-color 0.25s, box-shadow 0.25s;
}
.cl-attn:disabled { cursor: default; }
.cl-attn:not(:disabled):hover { transform: translateY(-2px); box-shadow: var(--cl-shadow-2); }
.cl-attn--ok { --tone: #10b981; --tone-soft: rgba(16, 185, 129, 0.2); }
.cl-attn--warn { --tone: #d97706; --tone-soft: rgba(245, 158, 11, 0.22); }
.cl-attn--danger { --tone: #e11d48; --tone-soft: rgba(225, 29, 72, 0.2); }
.cl-attn--on { border-color: var(--tone); box-shadow: 0 0 0 3px var(--tone-soft); }
.cl-attn__icon { width: 34px; height: 34px; flex-shrink: 0; display: grid; place-items: center; border-radius: 10px; color: var(--tone); background: var(--tone-soft); }
.cl-attn__body { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
.cl-attn__value { font-size: 1.05rem; font-weight: 800; line-height: 1.15; color: var(--cl-ink); }
.cl-attn__label { font-size: 11px; font-weight: 600; color: var(--cl-muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cl-attn__arrow { margin-left: auto; color: var(--cl-muted); opacity: 0.6; }
.cl-attn--on .cl-attn__arrow { color: var(--tone); opacity: 1; }

/* ══ Range ══ */
.cl-range { display: flex; align-items: center; justify-content: space-between; gap: 12px; flex-wrap: wrap; margin: 22px 0 12px; }
.cl-seg { display: inline-flex; padding: 3px; border-radius: 11px; background: var(--cl-surface); border: 1px solid var(--cl-line); box-shadow: var(--cl-shadow-1); }
.cl-seg__btn {
  border: 0; background: transparent; color: var(--cl-muted);
  font-size: 12px; font-weight: 700; padding: 6px 14px; border-radius: 8px; cursor: pointer;
  transition: background 0.2s, color 0.2s;
}
.cl-seg__btn--on { color: #fff; background: linear-gradient(135deg, var(--cl-primary), var(--cl-deep)); box-shadow: 0 8px 18px -12px rgba(47, 109, 255, 0.9); }
.cl-range__hint { font-size: 11.5px; color: var(--cl-muted); }
.cl-range__hint strong { color: var(--cl-ink-2); }

/* ══ KPI grid ══ */
.cl-kpis { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 14px; }
@media (min-width: 720px) { .cl-kpis { grid-template-columns: repeat(4, minmax(0, 1fr)); } }
@media (min-width: 1500px) { .cl-kpis { grid-template-columns: repeat(8, minmax(0, 1fr)); } }
.cl-kpi {
  --accent: #2f6dff; --soft: rgba(47, 109, 255, 0.12);
  position: relative; overflow: hidden; padding: 15px 16px 17px;
  border-radius: 18px; background: var(--cl-surface);
  border: 1px solid var(--cl-line); box-shadow: var(--cl-shadow-1);
  transition: transform 0.3s cubic-bezier(0.16, 1, 0.3, 1), box-shadow 0.3s, border-color 0.3s;
  animation: cl-rise 0.5s cubic-bezier(0.16, 1, 0.3, 1) both;
  animation-delay: calc(var(--i, 0) * 45ms);
}
.cl-kpi::before {
  content: ''; position: absolute; top: -60px; right: -50px;
  width: 140px; height: 140px; border-radius: 50%;
  background: var(--soft); filter: blur(26px); opacity: 0.7;
  transition: opacity 0.3s, transform 0.4s; pointer-events: none;
}
.cl-kpi:hover { transform: translateY(-3px); box-shadow: var(--cl-shadow-2); border-color: var(--soft); }
.cl-kpi:hover::before { opacity: 1; transform: scale(1.12); }
.cl-kpi__head { position: relative; z-index: 1; display: flex; align-items: center; justify-content: space-between; gap: 6px; margin-bottom: 12px; }
.cl-kpi__icon { width: 32px; height: 32px; display: grid; place-items: center; border-radius: 10px; color: var(--accent); background: var(--soft); }
.cl-kpi__value { position: relative; z-index: 1; font-size: 1.42rem; font-weight: 800; letter-spacing: -0.035em; line-height: 1.1; color: var(--cl-ink); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cl-kpi__label { position: relative; z-index: 1; margin-top: 3px; font-size: 10.5px; font-weight: 650; letter-spacing: 0.04em; text-transform: uppercase; color: var(--cl-muted); }
.cl-kpi__sub { position: relative; z-index: 1; margin-top: 5px; font-size: 11px; font-weight: 500; color: var(--cl-muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cl-kpi__bar { position: absolute; left: 16px; right: 16px; bottom: 0; height: 2px; border-radius: 2px 2px 0 0; background: var(--accent); transform: scaleX(0); transform-origin: left; transition: transform 0.35s cubic-bezier(0.16, 1, 0.3, 1); }
.cl-kpi:hover .cl-kpi__bar { transform: scaleX(1); }
@keyframes cl-rise { from { opacity: 0; transform: translateY(14px); } to { opacity: 1; transform: translateY(0); } }

/* ══ Panels ══ */
.cl-panel {
  display: flex; flex-direction: column;
  padding: 20px 22px; border-radius: var(--cl-radius);
  background: var(--cl-surface); border: 1px solid var(--cl-line);
  box-shadow: var(--cl-shadow-1);
}
.cl-panel__head { display: flex; align-items: flex-start; justify-content: space-between; gap: 14px; margin-bottom: 14px; }
.cl-panel__title { margin: 0; font-size: 1rem; font-weight: 750; letter-spacing: -0.015em; color: var(--cl-ink); }
.cl-panel__hint { margin: 3px 0 0; font-size: 11.5px; color: var(--cl-muted); }
.cl-panel__badge { display: inline-flex; align-items: center; gap: 5px; padding: 4px 10px; border-radius: 999px; font-size: 11px; font-weight: 700; color: var(--cl-primary); background: rgba(47, 109, 255, 0.1); }
.cl-panel__badge--danger { color: #e11d48; background: rgba(225, 29, 72, 0.12); }
.cl-panel__count { display: inline-flex; align-items: center; justify-content: center; min-width: 26px; height: 24px; padding: 0 8px; border-radius: 999px; font-size: 11px; font-weight: 800; color: var(--cl-primary); background: rgba(47, 109, 255, 0.1); }
.cl-panel__count--danger { color: #e11d48; background: rgba(225, 29, 72, 0.12); }

/* ══ Pipeline ══ */
.cl-flow { margin-top: 18px; }
.cl-flow__track { display: flex; align-items: stretch; gap: 4px; overflow-x: auto; padding-bottom: 4px; }
.cl-stage {
  --tone: #64748b; --tone-soft: rgba(100, 116, 139, 0.1);
  flex: 1 1 0; min-width: 104px;
  display: flex; flex-direction: column; align-items: flex-start; gap: 1px;
  padding: 11px 12px; border-radius: 13px;
  background: var(--cl-surface-2); border: 1px solid var(--cl-line);
  transition: transform 0.2s, border-color 0.2s;
}
.cl-stage:hover { transform: translateY(-2px); border-color: var(--tone-soft); }
.cl-stage__icon { width: 24px; height: 24px; display: grid; place-items: center; border-radius: 7px; color: var(--tone); background: var(--tone-soft); margin-bottom: 4px; }
.cl-stage__count { font-size: 1.15rem; font-weight: 800; letter-spacing: -0.03em; color: var(--cl-ink); line-height: 1.1; }
.cl-stage__label { font-size: 10.5px; font-weight: 650; color: var(--cl-ink-2); white-space: nowrap; }
.cl-stage__pct { font-size: 9.5px; font-weight: 700; color: var(--tone); }
.cl-stage--muted { --tone: #64748b; --tone-soft: rgba(100, 116, 139, 0.12); }
.cl-stage--info { --tone: #0284c7; --tone-soft: rgba(2, 132, 199, 0.12); }
.cl-stage--warn { --tone: #d97706; --tone-soft: rgba(245, 158, 11, 0.14); }
.cl-stage--primary { --tone: #2f6dff; --tone-soft: rgba(47, 109, 255, 0.12); }
.cl-stage--violet { --tone: #7c3aed; --tone-soft: rgba(124, 58, 237, 0.12); }
.cl-stage--teal { --tone: #0d9488; --tone-soft: rgba(13, 148, 136, 0.12); }
.cl-stage--ok { --tone: #10b981; --tone-soft: rgba(16, 185, 129, 0.14); }
.cl-stage--danger { --tone: #e11d48; --tone-soft: rgba(225, 29, 72, 0.12); }
.cl-flow__arrow { color: var(--cl-muted); opacity: 0.5; align-self: center; flex-shrink: 0; }

/* ══ Split ══ */
.cl-split { display: grid; grid-template-columns: minmax(0, 1.5fr) minmax(0, 1fr); gap: 16px; margin-top: 18px; align-items: stretch; }
.cl-split--three { grid-template-columns: minmax(0, 1fr) minmax(0, 1fr) minmax(0, 1fr); }
@media (max-width: 1220px) { .cl-split--three { grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); } }
@media (max-width: 1023px) { .cl-split, .cl-split--three { grid-template-columns: minmax(0, 1fr); } }

.cl-panel__figure { display: flex; align-items: baseline; gap: 10px; flex-wrap: wrap; margin-bottom: 6px; }
.cl-panel__big { font-size: 2rem; font-weight: 800; letter-spacing: -0.04em; line-height: 1.1; color: var(--cl-ink); }
.cl-panel__vs { font-size: 11px; font-weight: 500; color: var(--cl-muted); }
.cl-chart { flex: 1 1 auto; margin: 4px -6px 0; color: var(--cl-muted); min-height: 176px; }

.cl-tabs { display: inline-flex; gap: 3px; flex-wrap: wrap; }
.cl-tabs__btn {
  border: 1px solid transparent; background: transparent; color: var(--cl-muted);
  font-size: 11.5px; font-weight: 650; padding: 5px 10px; border-radius: 8px; cursor: pointer;
  transition: all 0.2s;
}
.cl-tabs__btn:hover { color: var(--cl-primary); background: rgba(47, 109, 255, 0.07); }
.cl-tabs__btn--on { color: var(--cl-primary); background: rgba(47, 109, 255, 0.1); border-color: rgba(47, 109, 255, 0.22); }

.cl-mini-filters { display: inline-flex; gap: 4px; flex-wrap: wrap; }
.cl-chipbtn {
  border: 1px solid var(--cl-line); background: var(--cl-surface-2); color: var(--cl-muted);
  font-size: 11px; font-weight: 650; padding: 4px 9px; border-radius: 999px; cursor: pointer;
  transition: all 0.2s;
}
.cl-chipbtn--on { color: var(--cl-primary); border-color: rgba(47, 109, 255, 0.3); background: rgba(47, 109, 255, 0.08); }

/* ══ Money ══ */
.cl-money { display: flex; flex-direction: column; gap: 8px; }
.cl-money__row { display: flex; align-items: center; justify-content: space-between; gap: 10px; }
.cl-money__label { font-size: 12px; font-weight: 600; color: var(--cl-muted); }
.cl-money__label--ok { color: #047857; }
.cl-money__label--warn { color: #b45309; }
.cl-money__value { font-size: 0.98rem; font-weight: 800; color: var(--cl-ink); }
.cl-money__value--ok { color: #047857; }
.cl-money__value--warn { color: #b45309; }
.cl-money__track { height: 8px; border-radius: 999px; background: var(--cl-surface-2); overflow: hidden; margin-top: 2px; }
.cl-money__fill { display: block; height: 100%; border-radius: 999px; background: linear-gradient(90deg, #34d399, #10b981); transition: width 0.4s ease; }
.cl-statuslist { display: flex; flex-direction: column; gap: 7px; margin-top: 16px; padding-top: 14px; border-top: 1px solid var(--cl-line); }
.cl-statusrow { display: grid; grid-template-columns: 96px 1fr 30px; align-items: center; gap: 8px; }
.cl-statusrow__label { font-size: 11px; font-weight: 600; color: var(--cl-ink-2); }
.cl-statusrow__track { height: 7px; border-radius: 999px; background: var(--cl-surface-2); overflow: hidden; }
.cl-statusrow__fill { display: block; height: 100%; border-radius: 999px; transition: width 0.35s ease; }
.cl-statusrow__count { font-size: 11.5px; font-weight: 800; text-align: right; color: var(--cl-ink); }

/* ══ Timeline ══ */
.cl-timeline { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; max-height: 420px; overflow-y: auto; }
.cl-timeline__item { display: flex; align-items: stretch; gap: 10px; padding: 9px 2px; border-bottom: 1px solid var(--cl-line); }
.cl-timeline__item:last-child { border-bottom: 0; }
.cl-timeline__time { display: flex; flex-direction: column; align-items: flex-end; width: 58px; flex-shrink: 0; padding-top: 2px; }
.cl-timeline__clock { font-size: 12.5px; font-weight: 800; color: var(--cl-ink); }
.cl-timeline__dur { font-size: 10px; color: var(--cl-muted); }
.cl-timeline__rail { width: 3px; border-radius: 3px; background: var(--cl-line-2); flex-shrink: 0; }
.cl-timeline__rail--scheduled { background: #0ea5e9; }
.cl-timeline__rail--confirmed { background: #2f6dff; }
.cl-timeline__rail--in_progress { background: #f59e0b; }
.cl-timeline__rail--completed { background: #10b981; }
.cl-timeline__rail--cancelled, .cl-timeline__rail--no_show { background: #ef4444; }
.cl-timeline__body { min-width: 0; flex: 1; }
.cl-timeline__top { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
.cl-timeline__name { font-size: 12.5px; font-weight: 700; color: var(--cl-ink); text-decoration: none; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cl-timeline__name:hover { color: var(--cl-primary); }
.cl-timeline__meta { display: flex; align-items: center; flex-wrap: wrap; gap: 4px 10px; margin-top: 3px; font-size: 10.5px; color: var(--cl-muted); }
.cl-timeline__meta span { display: inline-flex; align-items: center; gap: 4px; }
.cl-timeline__reason { font-style: italic; opacity: 0.85; }

.cl-status { padding: 2px 8px; border-radius: 999px; font-size: 9.5px; font-weight: 800; letter-spacing: 0.02em; text-transform: uppercase; white-space: nowrap; background: rgba(148, 163, 184, 0.16); color: #475569; }
.cl-status--scheduled { background: rgba(14, 165, 233, 0.14); color: #0369a1; }
.cl-status--confirmed { background: rgba(47, 109, 255, 0.14); color: #1d4ed8; }
.cl-status--in_progress { background: rgba(245, 158, 11, 0.16); color: #b45309; }
.cl-status--completed { background: rgba(16, 185, 129, 0.14); color: #047857; }
.cl-status--cancelled, .cl-status--no_show { background: rgba(239, 68, 68, 0.14); color: #b91c1c; }

/* ══ Care team ══ */
.cl-team { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 6px; }
.cl-team__item { display: grid; grid-template-columns: 18px 30px 1fr 74px 36px; align-items: center; gap: 9px; padding: 6px 2px; }
.cl-team__rank { font-size: 10px; font-weight: 800; color: var(--cl-muted); }
.cl-team__avatar { width: 30px; height: 30px; border-radius: 9px; display: grid; place-items: center; font-size: 10.5px; font-weight: 800; color: #fff; background: linear-gradient(140deg, var(--cl-primary), var(--cl-deep)); }
.cl-team__meta { display: flex; flex-direction: column; min-width: 0; line-height: 1.25; }
.cl-team__name { font-size: 12px; font-weight: 700; color: var(--cl-ink); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cl-team__sub { font-size: 10px; color: var(--cl-muted); }
.cl-team__bar { height: 6px; border-radius: 999px; background: var(--cl-surface-2); overflow: hidden; }
.cl-team__fill { display: block; height: 100%; border-radius: 999px; background: linear-gradient(90deg, #34d399, #10b981); }
.cl-team__pct { font-size: 10.5px; font-weight: 800; color: var(--cl-ink-2); text-align: right; }

.cl-beds { margin-top: 16px; padding-top: 14px; border-top: 1px solid var(--cl-line); }
.cl-beds__head { display: flex; align-items: center; justify-content: space-between; font-size: 11.5px; font-weight: 650; color: var(--cl-muted); }
.cl-beds__head strong { color: var(--cl-ink); font-size: 12px; }
.cl-beds__track { height: 8px; border-radius: 999px; background: var(--cl-surface-2); overflow: hidden; margin: 7px 0 5px; }
.cl-beds__fill { display: block; height: 100%; border-radius: 999px; background: linear-gradient(90deg, #fbbf24, #f59e0b); }
.cl-beds__legend { display: flex; justify-content: space-between; font-size: 10.5px; color: var(--cl-muted); }

/* ══ Quad ══ */
.cl-quad { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 16px; margin-top: 18px; }
@media (max-width: 1220px) { .cl-quad { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
@media (max-width: 680px) { .cl-quad { grid-template-columns: minmax(0, 1fr); } }

.cl-esi { display: flex; flex-direction: column; gap: 8px; }
.cl-esi__row { display: grid; grid-template-columns: 62px 1fr 26px; align-items: center; gap: 8px; }
.cl-esi__badge { padding: 2px 7px; border-radius: 6px; font-size: 10px; font-weight: 800; text-align: center; background: rgba(148, 163, 184, 0.16); color: #475569; }
.cl-esi__badge--critical { background: rgba(190, 18, 60, 0.14); color: #be123c; }
.cl-esi__badge--danger { background: rgba(239, 68, 68, 0.14); color: #b91c1c; }
.cl-esi__badge--warn { background: rgba(245, 158, 11, 0.16); color: #b45309; }
.cl-esi__badge--info { background: rgba(14, 165, 233, 0.14); color: #0369a1; }
.cl-esi__badge--ok { background: rgba(16, 185, 129, 0.14); color: #047857; }
.cl-esi__track { height: 7px; border-radius: 999px; background: var(--cl-surface-2); overflow: hidden; }
.cl-esi__fill { display: block; height: 100%; border-radius: 999px; background: #94a3b8; }
.cl-esi__fill--critical { background: #be123c; }
.cl-esi__fill--danger { background: #ef4444; }
.cl-esi__fill--warn { background: #f59e0b; }
.cl-esi__fill--info { background: #0ea5e9; }
.cl-esi__fill--ok { background: #10b981; }
.cl-esi__count { font-size: 11.5px; font-weight: 800; text-align: right; color: var(--cl-ink); }

.cl-chipgrid { display: flex; flex-wrap: wrap; gap: 6px; }
.cl-pipechip { display: inline-flex; align-items: center; gap: 5px; padding: 5px 10px; border-radius: 999px; font-size: 10.5px; font-weight: 650; text-transform: capitalize; background: rgba(148, 163, 184, 0.14); color: #475569; }
.cl-pipechip strong { font-size: 11px; font-weight: 800; }
.cl-pipechip--ok { background: rgba(16, 185, 129, 0.13); color: #047857; }
.cl-pipechip--info { background: rgba(14, 165, 233, 0.13); color: #0369a1; }
.cl-pipechip--primary { background: rgba(47, 109, 255, 0.12); color: #1d4ed8; }
.cl-pipechip--warn { background: rgba(245, 158, 11, 0.15); color: #b45309; }
.cl-pipechip--danger { background: rgba(239, 68, 68, 0.13); color: #b91c1c; }

.cl-depts { display: flex; flex-direction: column; gap: 8px; }
.cl-dept { display: grid; grid-template-columns: 88px 1fr 28px; align-items: center; gap: 8px; }
.cl-dept__name { font-size: 11px; font-weight: 600; color: var(--cl-ink-2); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cl-dept__track { height: 7px; border-radius: 999px; background: var(--cl-surface-2); overflow: hidden; }
.cl-dept__fill { display: block; height: 100%; border-radius: 999px; background: linear-gradient(90deg, #60a5fa, #2f6dff); }
.cl-dept__count { font-size: 11.5px; font-weight: 800; text-align: right; color: var(--cl-ink); }

/* ══ Alerts / feed / actions ══ */
.cl-alerts { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 8px; }
.cl-alert { display: flex; gap: 10px; align-items: flex-start; padding: 9px 10px; border-radius: 12px; background: var(--cl-surface-2); border-left: 3px solid #94a3b8; }
.cl-alert--low { border-left-color: #0ea5e9; }
.cl-alert--medium { border-left-color: #f59e0b; }
.cl-alert--high { border-left-color: #ef4444; }
.cl-alert--critical { border-left-color: #be123c; }
.cl-alert__sev { font-size: 9px; font-weight: 800; text-transform: uppercase; letter-spacing: 0.05em; padding: 2px 6px; border-radius: 5px; background: rgba(148, 163, 184, 0.18); color: #475569; white-space: nowrap; margin-top: 1px; }
.cl-alert--critical .cl-alert__sev { background: rgba(190, 18, 60, 0.14); color: #be123c; }
.cl-alert--high .cl-alert__sev { background: rgba(239, 68, 68, 0.14); color: #b91c1c; }
.cl-alert--medium .cl-alert__sev { background: rgba(245, 158, 11, 0.16); color: #b45309; }
.cl-alert__body { display: flex; flex-direction: column; min-width: 0; flex: 1; }
.cl-alert__name { font-size: 12px; font-weight: 700; color: var(--cl-ink); }
.cl-alert__reason { font-size: 11px; color: var(--cl-muted); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.cl-alert__time { font-size: 10px; color: var(--cl-muted); white-space: nowrap; }

.cl-feed { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; max-height: 300px; overflow-y: auto; }
.cl-feed__item { display: flex; gap: 10px; padding: 8px 2px; border-bottom: 1px solid var(--cl-line); }
.cl-feed__item:last-child { border-bottom: 0; }
.cl-feed__dot { width: 7px; height: 7px; border-radius: 50%; margin-top: 5px; flex-shrink: 0; background: #94a3b8; }
.cl-feed__dot--info { background: #2f6dff; }
.cl-feed__dot--notice { background: #0ea5e9; }
.cl-feed__dot--warning { background: #f59e0b; }
.cl-feed__dot--critical { background: #ef4444; box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.16); }
.cl-feed__body { min-width: 0; }
.cl-feed__text { margin: 0; font-size: 12px; font-weight: 600; line-height: 1.35; color: var(--cl-ink); display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }
.cl-feed__meta { display: flex; justify-content: space-between; gap: 8px; margin-top: 3px; font-size: 10.5px; color: var(--cl-muted); }
.cl-feed__meta span:first-child { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 62%; }

.cl-actions { display: flex; flex-direction: column; gap: 6px; }
.cl-action {
  --accent: #2f6dff;
  display: flex; align-items: center; gap: 9px;
  padding: 8px 10px; border-radius: 11px;
  border: 1px solid var(--cl-line); background: var(--cl-surface-2);
  text-decoration: none; color: var(--cl-ink);
  transition: transform 0.2s, border-color 0.2s, background 0.2s;
}
.cl-action:hover {
  transform: translateX(2px);
  border-color: color-mix(in srgb, var(--accent) 40%, transparent);
  background: color-mix(in srgb, var(--accent) 7%, var(--cl-surface));
}
.cl-action__icon { width: 28px; height: 28px; display: grid; place-items: center; border-radius: 8px; color: var(--accent); background: color-mix(in srgb, var(--accent) 13%, transparent); }
.cl-action__label { flex: 1; font-size: 12px; font-weight: 650; }
.cl-action__arrow { color: var(--cl-muted); transition: transform 0.2s; }
.cl-action:hover .cl-action__arrow { transform: translateX(3px); color: var(--accent); }

/* ══ Empty ══ */
.cl-empty { display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px; padding: 28px 12px; color: var(--cl-muted); text-align: center; }
.cl-empty p { margin: 0; font-size: 12px; }
.cl-empty-inline { margin: 0; font-size: 11.5px; color: var(--cl-muted); }

/* ══ Skeleton ══ */
.cl-skeleton { display: flex; flex-direction: column; gap: 16px; padding-top: 18px; }
.cl-skeleton__hero { height: 220px; border-radius: 28px; }
.cl-skeleton__row { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 14px; }
@media (max-width: 900px) { .cl-skeleton__row { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
.cl-skeleton__tile { height: 118px; border-radius: 18px; }
.cl-skeleton__row--split { grid-template-columns: minmax(0, 1.5fr) minmax(0, 1fr); }
.cl-skeleton__panel { height: 320px; border-radius: var(--cl-radius); }
.cl-skeleton__hero, .cl-skeleton__tile, .cl-skeleton__panel { position: relative; overflow: hidden; background: var(--cl-surface); border: 1px solid var(--cl-line); }
.cl-skeleton__hero::after, .cl-skeleton__tile::after, .cl-skeleton__panel::after {
  content: ''; position: absolute; inset: 0; transform: translateX(-100%);
  background: linear-gradient(90deg, transparent, rgba(148, 163, 184, 0.2), transparent);
  animation: cl-shimmer 1.5s infinite;
}
@keyframes cl-shimmer { to { transform: translateX(100%); } }

/* ══ Command palette ══ */
.cl-palette { overflow: hidden; border-radius: 18px; background: var(--cl-surface); border: 1px solid var(--cl-line-2); box-shadow: 0 40px 90px -30px rgba(2, 6, 23, 0.65); }
.cl-palette__search { display: flex; align-items: center; gap: 10px; padding: 14px 16px; border-bottom: 1px solid var(--cl-line); }
.cl-palette__icon { color: var(--cl-muted); flex-shrink: 0; }
.cl-palette__input { flex: 1 1 auto; min-width: 0; border: 0; outline: 0; background: transparent; font-family: inherit; font-size: 14px; color: var(--cl-ink); }
.cl-palette__input::placeholder { color: var(--cl-muted); }
.cl-palette__list { list-style: none; margin: 0; padding: 6px; max-height: 52vh; overflow-y: auto; }
.cl-palette__item { display: flex; align-items: center; gap: 11px; padding: 9px 10px; border-radius: 11px; cursor: pointer; transition: background 0.12s; }
.cl-palette__item--active { background: rgba(47, 109, 255, 0.09); }
.cl-palette__glyph { width: 30px; height: 30px; flex-shrink: 0; display: grid; place-items: center; border-radius: 9px; color: var(--cl-primary); background: rgba(47, 109, 255, 0.1); }
.cl-palette__text { display: flex; flex-direction: column; min-width: 0; line-height: 1.3; }
.cl-palette__text strong { font-size: 13px; font-weight: 700; color: var(--cl-ink); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cl-palette__text small { font-size: 11px; color: var(--cl-muted); }
.cl-palette__enter { margin-left: auto; color: var(--cl-muted); opacity: 0.7; }
.cl-palette__empty { display: flex; flex-direction: column; align-items: center; gap: 8px; padding: 34px 16px; color: var(--cl-muted); font-size: 12.5px; }
.cl-palette__foot { display: flex; align-items: center; gap: 14px; padding: 9px 14px; border-top: 1px solid var(--cl-line); background: var(--cl-surface-2); font-size: 10.5px; font-weight: 600; color: var(--cl-muted); }
.cl-palette__foot span { display: inline-flex; align-items: center; gap: 4px; }
.cl-kbd {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 20px;
  height: 20px;
  padding: 0 5px;
  border-radius: 5px;
  border: 1px solid var(--cl-line-2);
  background: var(--cl-surface);
  color: var(--cl-muted);
  font-family: inherit;
  font-size: 10px;
  font-weight: 700;
  line-height: 1;
}

.cl-pop-enter-active, .cl-pop-leave-active { transition: opacity 0.18s ease, transform 0.18s ease; }
.cl-pop-enter-from, .cl-pop-leave-to { opacity: 0; transform: translateY(-8px) scale(0.98); }

/* ══ Security & settings ══ */
.cl-sec { margin-top: 16px; }

.cl-sec__bar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 12px;
  padding: 14px 16px;
  border-radius: var(--cl-radius);
  background: var(--cl-surface);
  border: 1px solid var(--cl-line);
  box-shadow: var(--cl-shadow-1);
}
.cl-sec__id { display: flex; align-items: center; gap: 12px; flex: 1 1 300px; min-width: 0; }
.cl-sec__glyph {
  width: 40px; height: 40px; flex-shrink: 0;
  display: grid; place-items: center;
  border-radius: 12px; color: #fff;
  background: linear-gradient(135deg, #1e3a8a, #2f6dff);
  box-shadow: 0 8px 18px -8px rgba(47, 109, 255, 0.7);
}
.cl-sec__title { margin: 0; font-size: 15px; font-weight: 800; letter-spacing: -0.1px; color: var(--cl-ink); }
.cl-sec__hint { margin: 1px 0 0; font-size: 11.5px; line-height: 1.4; color: var(--cl-muted); }

.cl-sec__posture {
  --tone: #10b981;
  --tone-soft: rgba(16, 185, 129, 0.12);
  display: flex; align-items: center; gap: 9px;
  padding: 6px 13px 6px 9px; border-radius: 999px;
  background: var(--tone-soft);
  border: 1px solid color-mix(in srgb, var(--tone) 26%, transparent);
}
.cl-sec__posture--ok { --tone: #10b981; --tone-soft: rgba(16, 185, 129, 0.12); }
.cl-sec__posture--warn { --tone: #d97706; --tone-soft: rgba(245, 158, 11, 0.16); }
.cl-sec__posture--danger { --tone: #e11d48; --tone-soft: rgba(225, 29, 72, 0.14); }
.cl-sec__score { font-size: 17px; font-weight: 800; line-height: 1; color: var(--tone); }
.cl-sec__scopy { display: flex; flex-direction: column; line-height: 1.15; }
.cl-sec__scopy strong { font-size: 11.5px; font-weight: 750; color: var(--cl-ink); }
.cl-sec__scopy small {
  font-size: 9px; font-weight: 750; letter-spacing: 0.7px;
  text-transform: uppercase; color: var(--cl-muted);
}
.cl-sec__bar-actions { display: flex; align-items: center; gap: 2px; margin-left: auto; }

.cl-ghost { color: var(--cl-ink-2) !important; font-weight: 650 !important; letter-spacing: 0; }
.cl-ghost:hover { background: var(--cl-surface-2) !important; }

.cl-sec__kpis { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px; margin-top: 12px; }
@media (min-width: 760px) { .cl-sec__kpis { grid-template-columns: repeat(3, minmax(0, 1fr)); } }
@media (min-width: 1240px) { .cl-sec__kpis { grid-template-columns: repeat(6, minmax(0, 1fr)); } }
.cl-sec__kpi {
  --accent: #2f6dff;
  --soft: rgba(47, 109, 255, 0.1);
  display: flex; flex-direction: column; gap: 3px;
  padding: 11px 12px; border-radius: 14px;
  background: var(--cl-surface);
  border: 1px solid var(--cl-line);
  box-shadow: var(--cl-shadow-1);
}
.cl-sec__kpi-icon {
  width: 24px; height: 24px; display: grid; place-items: center;
  border-radius: 8px; color: var(--accent); background: var(--soft);
}
.cl-sec__kpi-value { font-size: 17px; font-weight: 800; letter-spacing: -0.3px; color: var(--cl-ink); }
.cl-sec__kpi-label { font-size: 10.5px; font-weight: 650; color: var(--cl-muted); }

.cl-sec__grid { display: grid; grid-template-columns: minmax(0, 1fr); gap: 14px; margin-top: 12px; }
@media (min-width: 1024px) {
  .cl-sec__grid { grid-template-columns: minmax(0, 1.1fr) minmax(0, 1fr) minmax(0, 1fr); }
  .cl-sec__grid--2 { grid-template-columns: minmax(0, 1.3fr) minmax(0, 1fr); }
}

.cl-panel__link {
  display: inline-flex; align-items: center; gap: 4px;
  font-size: 11.5px; font-weight: 700;
  color: var(--cl-primary); text-decoration: none;
  white-space: nowrap;
}
.cl-panel__link:hover { text-decoration: underline; }
.cl-panel__badge--warn { color: #b45309; background: rgba(245, 158, 11, 0.16); }

/* Signals */
.cl-signals { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 8px; }
.cl-signal {
  --tone: #94a3b8;
  display: flex; align-items: center; gap: 10px;
  padding: 8px 10px; border-radius: 11px;
  background: var(--cl-surface-2);
  border: 1px solid var(--cl-line);
}
.cl-signal--high { --tone: #ef4444; }
.cl-signal--medium { --tone: #f59e0b; }
.cl-signal--low { --tone: #0ea5e9; }
.cl-signal__rail { width: 3px; align-self: stretch; min-height: 26px; border-radius: 3px; background: var(--tone); }
.cl-signal__body { display: flex; flex-direction: column; gap: 1px; min-width: 0; flex: 1 1 auto; }
.cl-signal__title { font-size: 11.5px; font-weight: 700; color: var(--cl-ink); line-height: 1.3; }
.cl-signal__detail { font-size: 10.5px; color: var(--cl-muted); line-height: 1.35; }
.cl-signal__badge {
  flex-shrink: 0; padding: 2px 7px; border-radius: 999px;
  font-size: 9px; font-weight: 800; letter-spacing: 0.6px; text-transform: uppercase;
  color: var(--tone);
  background: color-mix(in srgb, var(--tone) 14%, transparent);
}

/* Roles */
.cl-roles { display: flex; flex-direction: column; gap: 7px; }
.cl-role { display: flex; align-items: center; gap: 9px; }
.cl-role__name {
  width: 112px; flex-shrink: 0; font-size: 11px; font-weight: 650; color: var(--cl-ink-2);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.cl-role__track { flex: 1 1 auto; height: 6px; border-radius: 999px; background: var(--cl-surface-2); overflow: hidden; }
.cl-role__fill {
  display: block; height: 100%; border-radius: 999px;
  background: linear-gradient(90deg, #2f6dff, #37d6ff);
}
.cl-role__count { flex-shrink: 0; font-size: 11px; font-weight: 800; color: var(--cl-ink); min-width: 18px; text-align: right; }

.cl-sec__mods { margin-top: 14px; padding-top: 12px; border-top: 1px solid var(--cl-line); }
.cl-sec__mods-head {
  font-size: 9.5px; font-weight: 800; letter-spacing: 0.8px;
  text-transform: uppercase; color: var(--cl-muted); margin-bottom: 8px;
}

/* Policy switches */
.cl-switches { display: flex; flex-direction: column; gap: 2px; }
.cl-switch {
  display: flex; align-items: center; gap: 10px;
  padding: 7px 0; border-bottom: 1px solid var(--cl-line);
}
.cl-switch:last-child { border-bottom: 0; }
.cl-switch__body {
  flex: 1 1 auto; min-width: 0; display: flex; flex-direction: column; gap: 1px;
  cursor: pointer; border-radius: 8px; outline: none;
}
.cl-switch__body:focus-visible { box-shadow: 0 0 0 3px rgba(47, 109, 255, 0.22); }
.cl-switch__label { font-size: 12px; font-weight: 650; color: var(--cl-ink); }
.cl-switch__hint { font-size: 10.5px; color: var(--cl-muted); }
.cl-switch :deep(.v-switch) { flex-shrink: 0; }
.cl-switch :deep(.v-switch .v-selection-control) { min-height: 28px; }

.cl-sec__selects {
  display: grid; grid-template-columns: minmax(0, 1fr); gap: 10px;
  margin-top: 14px; padding-top: 14px; border-top: 1px solid var(--cl-line);
}
@media (min-width: 560px) { .cl-sec__selects { grid-template-columns: repeat(3, minmax(0, 1fr)); } }
.cl-sec__selects :deep(.v-field) { border-radius: 11px; }
.cl-sec__selects :deep(.v-label) { font-size: 12px; }

.cl-sec__save {
  display: flex; align-items: center; justify-content: space-between;
  gap: 10px; flex-wrap: wrap; margin-top: 14px;
}
.cl-sec__save-hint {
  display: inline-flex; align-items: center; gap: 5px;
  font-size: 10.5px; font-weight: 600; color: var(--cl-muted);
}
.cl-primary-btn {
  background: linear-gradient(120deg, #2f6dff, #1d4ed8) !important;
  color: #fff !important;
  font-weight: 700 !important;
  letter-spacing: 0 !important;
  box-shadow: 0 10px 22px -12px rgba(47, 109, 255, 0.9) !important;
}
.cl-primary-btn:disabled { opacity: 0.45; box-shadow: none !important; }

/* Shortcuts */
.cl-shortcuts { display: grid; grid-template-columns: minmax(0, 1fr); gap: 6px; }
@media (min-width: 560px) { .cl-shortcuts { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
.cl-shortcut {
  --accent: #2f6dff;
  display: flex; align-items: center; gap: 9px;
  padding: 9px 10px; border-radius: 12px;
  border: 1px solid var(--cl-line);
  background: var(--cl-surface-2);
  color: var(--cl-ink); text-decoration: none;
  transition: transform 0.2s, border-color 0.2s, background 0.2s;
}
.cl-shortcut:hover {
  transform: translateY(-1px);
  border-color: color-mix(in srgb, var(--accent) 40%, transparent);
  background: color-mix(in srgb, var(--accent) 7%, var(--cl-surface));
}
.cl-shortcut__icon {
  width: 30px; height: 30px; flex-shrink: 0; display: grid; place-items: center;
  border-radius: 9px; color: var(--accent);
  background: color-mix(in srgb, var(--accent) 13%, transparent);
}
.cl-shortcut__body { display: flex; flex-direction: column; min-width: 0; line-height: 1.25; }
.cl-shortcut__label { font-size: 12px; font-weight: 700; color: var(--cl-ink); }
.cl-shortcut__hint {
  font-size: 10.5px; color: var(--cl-muted);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.cl-shortcut__arrow { margin-left: auto; flex-shrink: 0; color: var(--cl-muted); transition: transform 0.2s, color 0.2s; }
.cl-shortcut:hover .cl-shortcut__arrow { transform: translateX(3px); color: var(--accent); }

.cl-spin { animation: cl-rot 0.9s linear infinite; }
@keyframes cl-rot { to { transform: rotate(360deg); } }

/* ══ Responsive ══ */
@media (max-width: 900px) {
  .cl-hero { padding: 18px 16px 14px; }
  .cl-hero__top { align-items: flex-start; }
  .cl-hero__actions { width: 100%; }
  .cl-hero__title { font-size: 21px; }
}
@media (max-width: 719px) {
  .cl-hero__identity { gap: 10px; }
  .cl-hero__icon { width: 44px; height: 44px; border-radius: 13px; }
  .cl-hero__actions :deep(.v-btn) { flex: 1 1 auto; }
  .cl-panel { padding: 16px; }
}
@media (prefers-reduced-motion: reduce) {
  .cl-kpi, .cl-hero { animation: none; }
  .cl-kpi:hover, .cl-attn:hover, .cl-stage:hover { transform: none; }
}
</style>
