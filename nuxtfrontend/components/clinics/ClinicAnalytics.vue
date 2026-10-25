<template>
  <v-container fluid class="pa-4 pa-md-6 an-page" :style="themeVars">
    <!-- ═══════════════ Page header (surface, not a brand hero) ═══════════════ -->
    <header class="an-head">
      <div class="an-head-top">
        <div class="an-head-icon">
          <v-icon size="26">mdi-chart-arc</v-icon>
        </div>

        <div class="an-head-id">
          <div class="an-head-eyebrow">
            <span class="an-live-dot"></span>
            CLINIC INTELLIGENCE
          </div>
          <h1 class="an-head-title">Analytics and insights</h1>
          <p class="an-head-sub">{{ headSub }}</p>
        </div>

        <div class="an-head-actions">
          <v-select
            v-model="sitePick"
            :items="siteOptions"
            item-title="label"
            item-value="value"
            variant="outlined"
            density="compact"
            rounded="lg"
            hide-details
            class="an-site-pick"
            :loading="siteLoading"
            @update:model-value="onSiteChange"
          />
          <div class="an-range" role="group" aria-label="Reporting window">
            <button
              v-for="r in rangeOptions"
              :key="r.key"
              type="button"
              class="an-range-btn"
              :class="{ 'is-on': rangeKey === r.key }"
              @click="setRange(r.key)"
            >
              {{ r.label }}
            </button>
          </div>

          <button type="button" class="an-btn" :disabled="!ready" @click="exportCsv">
            <v-icon size="15">mdi-download-outline</v-icon>
            <span>Export</span>
          </button>

          <button type="button" class="an-btn is-primary" :disabled="loading" @click="load()">
            <v-icon size="15" :class="{ 'an-spin': loading }">mdi-refresh</v-icon>
            <span>Refresh</span>
          </button>
        </div>
      </div>

      <div class="an-head-foot">
        <span class="an-chip">
          <span class="an-live-dot"></span>
          Live data
        </span>
        <span class="an-chip">
          <v-icon size="13">mdi-calendar-range</v-icon>
          {{ windowLabel }}
        </span>
        <span class="an-chip">
          <v-icon size="13">mdi-clock-outline</v-icon>
          {{ updatedLabel }}
        </span>
        <span class="an-chip">
          <v-icon size="13">mdi-account-group-outline</v-icon>
          {{ fmt(kpis.patients_total) }} patients
        </span>
        <button
          type="button"
          class="an-chip an-chip--btn"
          :class="{ 'is-off': !autoRefresh }"
          @click="autoRefresh = !autoRefresh"
        >
          <v-icon size="13">mdi-sync</v-icon>
          {{ autoRefresh ? 'Auto 60s' : 'Auto paused' }}
        </button>
        <span class="an-head-stamp">{{ currency }} · {{ rangeLabel }}</span>
      </div>
    </header>

    <!-- ═══════════════ Error state ═══════════════ -->
    <section v-if="error && !data" class="an-error">
      <v-icon size="26" color="error">mdi-alert-circle-outline</v-icon>
      <div>
        <strong>Analytics could not be loaded</strong>
        <span>{{ error }}</span>
      </div>
      <button type="button" class="an-btn" @click="load()">Try again</button>
    </section>

    <!-- ═══════════════ Skeleton ═══════════════ -->
    <template v-else-if="!ready">
      <div class="an-kpis">
        <div v-for="n in 8" :key="n" class="an-skel an-skel--kpi"></div>
      </div>
      <div class="an-grid">
        <div class="an-skel an-skel--chart an-col-8"></div>
        <div class="an-skel an-skel--chart an-col-4"></div>
        <div class="an-skel an-skel--chart an-col-5"></div>
        <div class="an-skel an-skel--chart an-col-7"></div>
      </div>
    </template>

    <!-- ═══════════════ Workspace ═══════════════ -->
    <template v-else>
      <!-- Signals -->
      <div v-if="insights.length" class="an-insights">
        <article
          v-for="i in insights"
          :key="i.title"
          class="an-insight"
          :class="'is-' + i.tone"
        >
          <span class="an-insight-icon"><v-icon size="16">{{ i.icon }}</v-icon></span>
          <div class="an-insight-text">
            <strong>{{ i.title }}</strong>
            <span>{{ i.detail }}</span>
          </div>
        </article>
      </div>

      <!-- KPI ribbon -->
      <div class="an-kpis">
        <article v-for="k in kpiCards" :key="k.key" class="an-kpi" :style="{ '--tone': k.tone }">
          <div class="an-kpi-top">
            <span class="an-kpi-icon"><v-icon size="16">{{ k.icon }}</v-icon></span>
            <span class="an-kpi-label">{{ k.label }}</span>
            <span
              v-if="k.delta !== null && k.delta !== undefined"
              class="an-delta"
              :class="deltaClass(k.delta, k.invert)"
            >{{ deltaText(k.delta) }}</span>
          </div>

          <div class="an-kpi-value">{{ k.value }}</div>
          <div class="an-kpi-sub">{{ k.sub }}</div>

          <svg
            v-if="k.spark"
            class="an-spark"
            viewBox="0 0 100 28"
            preserveAspectRatio="none"
            aria-hidden="true"
          >
            <path :d="sparkArea(k.spark)" :fill="k.soft"></path>
            <path
              :d="sparkLine(k.spark)"
              fill="none"
              :stroke="k.tone"
              stroke-width="1.8"
              stroke-linejoin="round"
              stroke-linecap="round"
              vector-effect="non-scaling-stroke"
            ></path>
          </svg>
          <div v-else class="an-kpi-meter">
            <span :style="{ width: k.meterPct + '%', background: k.tone }"></span>
          </div>
        </article>
      </div>

      <!-- ── Row 1: activity trend + revenue ── -->
      <div class="an-grid">
        <section class="an-card an-col-8">
          <header class="an-card-head">
            <span class="an-card-icon is-blue"><v-icon size="16">mdi-chart-timeline-variant</v-icon></span>
            <div class="an-card-title">
              <h2>Activity trend</h2>
              <p>Daily {{ metricLabel.toLowerCase() }} · last {{ trendDays }} days</p>
            </div>
            <div class="an-tabs">
              <button
                v-for="m in metricOptions"
                :key="m.key"
                type="button"
                class="an-tab"
                :class="{ 'is-on': metric === m.key }"
                @click="metric = m.key"
              >
                {{ m.label }}
              </button>
            </div>
          </header>

          <div class="an-card-body">
            <div class="an-trend-summary">
              <div class="an-trend-item">
                <span class="an-trend-big">{{ metricDisplay(metricTotal) }}</span>
                <span class="an-trend-cap">{{ metricLabel }} · last {{ trendDays }} days</span>
              </div>
              <div class="an-trend-item is-mid">
                <span class="an-trend-mid">{{ metricDisplay(metricAvg) }}</span>
                <span class="an-trend-cap">daily average</span>
              </div>
              <div class="an-trend-item is-end">
                <span class="an-delta" :class="deltaClass(metricDelta)">{{ deltaText(metricDelta) }}</span>
                <span class="an-trend-cap">second half vs first</span>
              </div>
            </div>

            <div class="an-chart" @mouseleave="hoverIndex = -1">
              <div class="an-chart-grid">
                <span v-for="g in 4" :key="g"></span>
              </div>
              <div class="an-bars">
                <div
                  v-for="(v, i) in metricSeries"
                  :key="i"
                  class="an-bar-slot"
                  @mouseenter="hoverIndex = i"
                >
                  <span class="an-bar" :style="{ height: barHeight(v) }"></span>
                  <div v-if="hoverIndex === i" class="an-tip">
                    <strong>{{ metricDisplay(v) }}</strong>
                    <span>{{ shortDate(trend.dates[i]) }}</span>
                  </div>
                </div>
              </div>
            </div>

            <div class="an-axis">
              <span v-for="(d, i) in trend.dates" :key="d + i">
                {{ showLabel(i) ? shortDate(d) : '' }}
              </span>
            </div>
          </div>
        </section>

        <section class="an-card an-col-4">
          <header class="an-card-head">
            <span class="an-card-icon is-teal"><v-icon size="16">mdi-chart-donut</v-icon></span>
            <div class="an-card-title">
              <h2>Revenue quality</h2>
              <p>Invoice mix and collection health</p>
            </div>
          </header>

          <div class="an-card-body">
            <div class="an-donut-wrap">
              <svg viewBox="0 0 140 140" class="an-donut" aria-hidden="true">
                <circle cx="70" cy="70" r="54" fill="none" stroke-width="15" class="an-donut-track"></circle>
                <circle
                  v-for="s in invoiceSegments"
                  :key="s.status"
                  cx="70"
                  cy="70"
                  r="54"
                  fill="none"
                  stroke-width="15"
                  :stroke="s.color"
                  :stroke-dasharray="s.dash"
                  :stroke-dashoffset="s.offset"
                  pathLength="100"
                  transform="rotate(-90 70 70)"
                  stroke-linecap="butt"
                ></circle>
              </svg>
              <div class="an-donut-center">
                <strong>{{ revenue.collection_rate ?? 0 }}%</strong>
                <span>collected</span>
              </div>
            </div>

            <div class="an-legend">
              <div v-for="s in invoiceSegments" :key="s.status" class="an-legend-row">
                <span class="an-dot" :style="{ background: s.color }"></span>
                <span class="an-legend-label">{{ pretty(s.status) }}</span>
                <span class="an-legend-val">{{ fmt(s.count) }}</span>
                <span class="an-legend-pct">{{ s.pct }}%</span>
              </div>
            </div>

            <div class="an-money-grid">
              <div>
                <span>Billed</span>
                <strong>{{ money(revenue.billed) }}</strong>
              </div>
              <div>
                <span>Collected</span>
                <strong class="is-good">{{ money(revenue.collected_on_invoices) }}</strong>
              </div>
              <div>
                <span>Outstanding</span>
                <strong class="is-bad">{{ money(revenue.outstanding) }}</strong>
              </div>
              <div>
                <span>Average invoice</span>
                <strong>{{ money(revenue.avg_ticket) }}</strong>
              </div>
            </div>
          </div>
        </section>
      </div>

      <!-- ── Row 2: journey + demand ── -->
      <div class="an-grid">
        <section class="an-card an-col-5">
          <header class="an-card-head">
            <span class="an-card-icon is-violet"><v-icon size="16">mdi-filter-variant</v-icon></span>
            <div class="an-card-title">
              <h2>Patient journey</h2>
              <p>Booked → triaged → consulted → billed</p>
            </div>
            <span class="an-card-tag">{{ fmt(appointments.total) }} booked</span>
          </header>

          <div class="an-card-body">
            <div v-for="(s, i) in funnel" :key="s.key" class="an-funnel">
              <div class="an-funnel-row">
                <span class="an-funnel-icon" :style="{ color: funnelColor(i) }">
                  <v-icon size="15">{{ s.icon }}</v-icon>
                </span>
                <div class="an-funnel-main">
                  <div class="an-funnel-top">
                    <span>{{ s.label }}</span>
                    <strong>{{ fmt(s.count) }}</strong>
                  </div>
                  <div class="an-track">
                    <span :style="{ width: Math.max(2, s.pct) + '%', background: funnelColor(i) }"></span>
                  </div>
                </div>
                <span class="an-funnel-pct">{{ s.pct }}%</span>
              </div>
            </div>
            <p class="an-note">
              Percentages are relative to the busiest stage, so the funnel never reads above 100%.
            </p>
          </div>
        </section>

        <section class="an-card an-col-7">
          <header class="an-card-head">
            <span class="an-card-icon is-amber"><v-icon size="16">mdi-calendar-clock</v-icon></span>
            <div class="an-card-title">
              <h2>Demand pattern</h2>
              <p>Appointment density by weekday and hour</p>
            </div>
            <span v-if="heat.peak.count" class="an-card-tag is-soft">
              Peak {{ heat.peak.day }} {{ heat.peak.hour }}
            </span>
          </header>

          <div class="an-card-body">
            <div class="an-heat-head">
              <span class="an-heat-spacer"></span>
              <div class="an-heat-hours">
                <span v-for="h in heat.hours" :key="h">{{ h }}</span>
              </div>
            </div>
            <div v-for="(row, d) in heat.matrix" :key="d" class="an-heat-line">
              <span class="an-heat-day">{{ heat.days[d] }}</span>
              <div class="an-heat-row">
                <span
                  v-for="(v, i) in row"
                  :key="i"
                  class="an-heat-cell"
                  :style="heatStyle(v)"
                  :title="`${heat.days[d]} ${heat.hours[i]}:00 · ${v} appointment${v === 1 ? '' : 's'}`"
                >
                  {{ v || '' }}
                </span>
              </div>
            </div>
            <div class="an-heat-foot">
              <span>Quiet</span>
              <span class="an-heat-scale">
                <i v-for="n in 6" :key="n" :style="heatStyle((heat.max || 0) * (n / 6))"></i>
              </span>
              <span>Busy</span>
            </div>
          </div>
        </section>
      </div>

      <!-- ── Row 3: revenue history + cash ── -->
      <div class="an-grid">
        <section class="an-card an-col-7">
          <header class="an-card-head">
            <span class="an-card-icon is-teal"><v-icon size="16">mdi-cash-multiple</v-icon></span>
            <div class="an-card-title">
              <h2>Revenue performance</h2>
              <p>Billed and collected over the last six months</p>
            </div>
            <div class="an-legend-inline">
              <span><i class="is-billed"></i>Billed</span>
              <span><i class="is-collected"></i>Collected</span>
            </div>
          </header>

          <div class="an-card-body">
            <div class="an-monthly">
              <div v-for="m in monthly" :key="m.month" class="an-month-col">
                <div class="an-month-bars">
                  <span class="an-month-bar is-billed" :style="{ height: monthlyHeight(m.billed) }"></span>
                  <span class="an-month-bar is-collected" :style="{ height: monthlyHeight(m.collected) }"></span>
                </div>
                <span class="an-month-label">{{ m.label }}</span>
                <span v-if="m.billed" class="an-month-value">{{ money(m.billed) }}</span>
              </div>
            </div>

            <div class="an-subhead">
              <span>Top billed services</span>
              <span>{{ revenue.invoice_count ?? 0 }} invoices in window</span>
            </div>
            <div class="an-services">
              <div v-for="(s, i) in topServices" :key="s.name" class="an-service">
                <span class="an-rank">{{ i + 1 }}</span>
                <span class="an-service-name">{{ s.name }}</span>
                <span class="an-service-bar">
                  <i :style="{ width: servicePct(s.amount) + '%' }"></i>
                </span>
                <span class="an-service-amount">{{ money(s.amount) }}</span>
              </div>
              <p v-if="!topServices.length" class="an-empty">No invoice line items in this window.</p>
            </div>
          </div>
        </section>

        <section class="an-card an-col-5">
          <header class="an-card-head">
            <span class="an-card-icon is-rose"><v-icon size="16">mdi-credit-card-clock-outline</v-icon></span>
            <div class="an-card-title">
              <h2>Cash and receivables</h2>
              <p>How patients pay and how old the balance is</p>
            </div>
          </header>

          <div class="an-card-body">
            <div class="an-subhead"><span>Payment methods</span><span>{{ money(cashTotal) }} received</span></div>
            <div class="an-methods">
              <div v-for="m in methods" :key="m.method" class="an-method">
                <span class="an-method-icon">
                  <v-icon size="14">{{ methodIcon(m.method) }}</v-icon>
                </span>
                <div class="an-method-main">
                  <div class="an-method-top">
                    <span>{{ methodLabel(m.method) }}</span>
                    <strong>{{ money(m.amount) }}</strong>
                  </div>
                  <div class="an-track">
                    <span :style="{ width: Math.max(3, m.pct) + '%' }"></span>
                  </div>
                </div>
                <span class="an-method-pct">{{ m.pct }}%</span>
              </div>
              <p v-if="!methods.length" class="an-empty">No payments recorded in this window.</p>
            </div>

            <div class="an-subhead is-spaced">
              <span>Outstanding ageing</span>
              <span>{{ money(revenue.outstanding) }} owed</span>
            </div>
            <div class="an-aging">
              <div v-for="b in aging" :key="b.key" class="an-aging-row">
                <span class="an-aging-label">{{ b.label }}</span>
                <span class="an-aging-bar"><i :style="{ width: agingPct(b.amount) + '%' }"></i></span>
                <span class="an-aging-amount">{{ money(b.amount) }}</span>
                <span class="an-aging-count">{{ b.count }}</span>
              </div>
            </div>
          </div>
        </section>
      </div>

      <!-- ── Row 4: departments + clinicians ── -->
      <div class="an-grid">
        <section class="an-card an-col-7">
          <header class="an-card-head">
            <span class="an-card-icon is-blue"><v-icon size="16">mdi-domain</v-icon></span>
            <div class="an-card-title">
              <h2>Department performance</h2>
              <p>Volume, consultations and attributed revenue</p>
            </div>
          </header>

          <div class="an-card-body">
            <div v-for="(d, i) in departmentsTop" :key="d.id" class="an-dept">
              <span class="an-rank">{{ i + 1 }}</span>
              <div class="an-dept-main">
                <div class="an-dept-top">
                  <span class="an-dept-name">{{ d.name }}</span>
                  <span class="an-dept-nums">
                    <strong>{{ fmt(d.appointments) }}</strong> visits · {{ fmt(d.consultations) }} consults
                  </span>
                </div>
                <div class="an-track">
                  <span :style="{ width: deptPct(d.appointments) + '%' }"></span>
                </div>
              </div>
              <span class="an-dept-rev">{{ money(d.revenue) }}</span>
            </div>
            <p v-if="!departmentsTop.length" class="an-empty">No departments configured for this clinic.</p>
          </div>
        </section>

        <section class="an-card an-col-5">
          <header class="an-card-head">
            <span class="an-card-icon is-emerald"><v-icon size="16">mdi-stethoscope</v-icon></span>
            <div class="an-card-title">
              <h2>Clinician leaderboard</h2>
              <p>Consultation volume and sign-off rate</p>
            </div>
            <span class="an-card-tag">{{ fmt(kpis.active_clinicians) }} active</span>
          </header>

          <div class="an-card-body">
            <div v-for="d in doctorsTop" :key="d.id" class="an-doctor">
              <span class="an-avatar">{{ initials(d.name) }}</span>
              <div class="an-doctor-main">
                <div class="an-doctor-top">
                  <span class="an-doctor-name">{{ d.name }}</span>
                  <strong>{{ fmt(d.consultations) }}</strong>
                </div>
                <div class="an-track">
                  <span :style="{ width: doctorPct(d.consultations) + '%' }"></span>
                </div>
                <div class="an-doctor-foot">
                  <span>{{ money(d.revenue) }} attributed</span>
                  <span class="an-pill" :class="completionClass(d.completion)">{{ d.completion }}% signed</span>
                </div>
              </div>
            </div>
            <p v-if="!doctorsTop.length" class="an-empty">No consultations recorded in this window.</p>
          </div>
        </section>
      </div>

      <!-- ── Row 5: patient mix ── -->
      <div class="an-grid">
        <section class="an-card an-col-4">
          <header class="an-card-head">
            <span class="an-card-icon is-pink"><v-icon size="16">mdi-account-group-outline</v-icon></span>
            <div class="an-card-title">
              <h2>Patient mix</h2>
              <p>Gender and age distribution</p>
            </div>
          </header>

          <div class="an-card-body">
            <div class="an-gender-bar">
              <span
                v-for="g in genderSegments"
                :key="g.key"
                :style="{ width: Math.max(2, g.pct) + '%', background: g.color }"
                :title="`${g.label}: ${g.count}`"
              ></span>
            </div>
            <div class="an-gender-legend">
              <span v-for="g in genderSegments" :key="g.key">
                <i :style="{ background: g.color }"></i>{{ g.label }} {{ g.pct }}%
              </span>
            </div>

            <div class="an-subhead is-spaced">
              <span>Age bands</span>
              <span>{{ fmt(patients.total) }} registered</span>
            </div>
            <div class="an-ages">
              <div v-for="a in ageRows" :key="a.band" class="an-age-row">
                <span class="an-age-label">{{ a.band }}</span>
                <span class="an-age-bar"><i :style="{ width: agePct(a.count) + '%' }"></i></span>
                <span class="an-age-count">{{ a.count }}</span>
              </div>
            </div>

            <div class="an-mini-grid">
              <div>
                <span>New this window</span>
                <strong>{{ fmt(patients.new_in_range) }}</strong>
              </div>
              <div>
                <span>Returning</span>
                <strong>{{ patients.returning_pct ?? 0 }}%</strong>
              </div>
            </div>
          </div>
        </section>

        <section class="an-card an-col-4">
          <header class="an-card-head">
            <span class="an-card-icon is-violet"><v-icon size="16">mdi-shield-account-outline</v-icon></span>
            <div class="an-card-title">
              <h2>Payer mix</h2>
              <p>Insurance coverage across the register</p>
            </div>
          </header>

          <div class="an-card-body">
            <div v-for="p in payers" :key="p.provider" class="an-payer">
              <div class="an-payer-top">
                <span>{{ p.provider }}</span>
                <span><strong>{{ fmt(p.count) }}</strong> · {{ p.pct }}%</span>
              </div>
              <div class="an-track">
                <span :style="{ width: payerPct(p.count) + '%' }"></span>
              </div>
            </div>
            <p v-if="!payers.length" class="an-empty">No payer information recorded.</p>

            <div class="an-callout">
              <v-icon size="15">mdi-lightbulb-on-outline</v-icon>
              <span>
                {{ payerInsight }}
              </span>
            </div>
          </div>
        </section>

        <section class="an-card an-col-4">
          <header class="an-card-head">
            <span class="an-card-icon is-amber"><v-icon size="16">mdi-calendar-check-outline</v-icon></span>
            <div class="an-card-title">
              <h2>Appointments and triage</h2>
              <p>Status mix and acuity split</p>
            </div>
          </header>

          <div class="an-card-body">
            <div v-for="s in apptStatus" :key="s.status" class="an-status-row">
              <span class="an-dot" :style="{ background: statusColor(s.status) }"></span>
              <span class="an-status-label">{{ pretty(s.status) }}</span>
              <span class="an-status-bar">
                <i :style="{ width: Math.max(2, s.pct) + '%', background: statusColor(s.status) }"></i>
              </span>
              <span class="an-status-count">{{ s.count }}</span>
              <span class="an-status-pct">{{ s.pct }}%</span>
            </div>
            <p v-if="!apptStatus.length" class="an-empty">No appointments in this window.</p>

            <div class="an-subhead is-spaced">
              <span>Triage acuity</span>
              <span>{{ fmt(triage.total) }} entries</span>
            </div>
            <div class="an-acuity">
              <div v-for="a in triage.by_acuity" :key="a.label" class="an-acuity-chip" :style="{ '--tone': acuityColor(a.level) }">
                <span class="an-acuity-n">{{ a.count }}</span>
                <span class="an-acuity-l">{{ a.label }}</span>
              </div>
              <p v-if="!triage.by_acuity.length" class="an-empty">No triage entries recorded.</p>
            </div>
          </div>
        </section>
      </div>

      <!-- ── Row 6: lab + pharmacy ── -->
      <div class="an-grid">
        <section class="an-card an-col-6">
          <header class="an-card-head">
            <span class="an-card-icon is-amber"><v-icon size="16">mdi-flask-outline</v-icon></span>
            <div class="an-card-title">
              <h2>Laboratory throughput</h2>
              <p>Worklist status, priority and test volume</p>
            </div>
            <span class="an-card-tag" :class="{ 'is-warn': aboveZero(lab.pending) }">
              {{ fmt(lab.pending) }} pending
            </span>
          </header>

          <div class="an-card-body">
            <div class="an-stats">
              <div class="an-stat">
                <span>Orders</span>
                <strong>{{ fmt(lab.total) }}</strong>
              </div>
              <div class="an-stat">
                <span>Completion</span>
                <strong>{{ lab.completion_rate ?? 0 }}%</strong>
              </div>
              <div class="an-stat">
                <span>Abnormal</span>
                <strong :class="{ 'is-bad': aboveZero(lab.abnormal) }">{{ fmt(lab.abnormal) }}</strong>
              </div>
            </div>

            <div class="an-seg">
              <span
                v-for="s in lab.by_status"
                :key="s.status"
                :style="{ width: Math.max(2, s.pct) + '%', background: statusColor(s.status) }"
                :title="`${pretty(s.status)}: ${s.count}`"
              ></span>
            </div>
            <div class="an-seg-legend">
              <span v-for="s in lab.by_status" :key="s.status">
                <i :style="{ background: statusColor(s.status) }"></i>{{ pretty(s.status) }} {{ s.count }}
              </span>
            </div>

            <div class="an-subhead is-spaced">
              <span>Most requested tests</span>
              <span>{{ fmt(lab.urgent) }} urgent</span>
            </div>
            <div class="an-test-list">
              <div v-for="t in lab.top_tests" :key="t.name" class="an-test-row">
                <span>{{ t.name }}</span>
                <span class="an-test-bar"><i :style="{ width: testPct(t.count) + '%' }"></i></span>
                <strong>{{ t.count }}</strong>
              </div>
              <p v-if="!lab.top_tests.length" class="an-empty">No lab orders in this window.</p>
            </div>
          </div>
        </section>

        <section class="an-card an-col-6">
          <header class="an-card-head">
            <span class="an-card-icon is-emerald"><v-icon size="16">mdi-pill-multiple</v-icon></span>
            <div class="an-card-title">
              <h2>Pharmacy throughput</h2>
              <p>Dispensing rate and medication demand</p>
            </div>
            <span class="an-card-tag" :class="{ 'is-warn': aboveZero(pharmacy.open) }">
              {{ fmt(pharmacy.open) }} open
            </span>
          </header>

          <div class="an-card-body">
            <div class="an-stats">
              <div class="an-stat">
                <span>Prescriptions</span>
                <strong>{{ fmt(pharmacy.total) }}</strong>
              </div>
              <div class="an-stat">
                <span>Dispensed</span>
                <strong>{{ pharmacy.dispense_rate ?? 0 }}%</strong>
              </div>
              <div class="an-stat">
                <span>Avg items</span>
                <strong>{{ pharmacy.avg_items ?? 0 }}</strong>
              </div>
            </div>

            <div class="an-seg">
              <span
                v-for="s in pharmacy.by_status"
                :key="s.status"
                :style="{ width: Math.max(2, s.pct) + '%', background: statusColor(s.status) }"
                :title="`${pretty(s.status)}: ${s.count}`"
              ></span>
            </div>
            <div class="an-seg-legend">
              <span v-for="s in pharmacy.by_status" :key="s.status">
                <i :style="{ background: statusColor(s.status) }"></i>{{ pretty(s.status) }} {{ s.count }}
              </span>
            </div>

            <div class="an-subhead is-spaced">
              <span>Most prescribed</span>
              <span>{{ fmt(pharmacy.items) }} items</span>
            </div>
            <div class="an-test-list">
              <div v-for="m in pharmacy.top_medications" :key="m.name" class="an-test-row">
                <span>{{ m.name }}</span>
                <span class="an-test-bar"><i :style="{ width: medPct(m.count) + '%' }"></i></span>
                <strong>{{ m.count }}</strong>
              </div>
              <p v-if="!pharmacy.top_medications.length" class="an-empty">No prescriptions in this window.</p>
            </div>
          </div>
        </section>
      </div>

      <!-- ── Row 7: wards ── -->
      <div class="an-grid">
        <section class="an-card an-col-12">
          <header class="an-card-head">
            <span class="an-card-icon is-rose"><v-icon size="16">mdi-bed-outline</v-icon></span>
            <div class="an-card-title">
              <h2>Inpatient utilisation</h2>
              <p>Bed occupancy, admissions and length of stay</p>
            </div>
            <span v-if="wards.available" class="an-card-tag">{{ wards.beds_occupied }} / {{ wards.beds_total }} beds</span>
          </header>

          <div class="an-card-body">
            <template v-if="wards.available">
              <div class="an-wards">
                <div class="an-ward-ring">
                  <svg viewBox="0 0 120 120" aria-hidden="true">
                    <circle cx="60" cy="60" r="46" fill="none" stroke-width="12" class="an-donut-track"></circle>
                    <circle
                      cx="60"
                      cy="60"
                      r="46"
                      fill="none"
                      stroke-width="12"
                      :stroke="wardColor"
                      :stroke-dasharray="`${wards.occupancy_pct} ${100 - wards.occupancy_pct}`"
                      pathLength="100"
                      transform="rotate(-90 60 60)"
                      stroke-linecap="round"
                    ></circle>
                  </svg>
                  <div class="an-donut-center is-small">
                    <strong>{{ wards.occupancy_pct }}%</strong>
                    <span>occupied</span>
                  </div>
                </div>

                <div class="an-ward-stats">
                  <div class="an-stat">
                    <span>Available</span>
                    <strong>{{ fmt(wards.beds_available) }}</strong>
                  </div>
                  <div class="an-stat">
                    <span>Admissions</span>
                    <strong>{{ fmt(wards.admissions) }}</strong>
                  </div>
                  <div class="an-stat">
                    <span>Discharges</span>
                    <strong>{{ fmt(wards.discharges) }}</strong>
                  </div>
                  <div class="an-stat">
                    <span>Avg stay</span>
                    <strong>{{ wards.avg_stay_days ?? 0 }}d</strong>
                  </div>
                </div>

                <div class="an-ward-list">
                  <div v-for="w in wards.by_ward" :key="w.name" class="an-ward-row">
                    <div class="an-ward-top">
                      <span>{{ w.name }}</span>
                      <span>{{ w.occupied }}/{{ w.beds }}</span>
                    </div>
                    <div class="an-track">
                      <span :style="{ width: Math.max(2, w.occupancy_pct) + '%' }"></span>
                    </div>
                  </div>
                </div>
              </div>
            </template>

            <div v-else class="an-empty-block">
              <v-icon size="30">mdi-bed-empty</v-icon>
              <strong>No inpatient wards configured</strong>
              <span>Add wards and beds to unlock occupancy, admissions and length-of-stay analytics.</span>
              <button type="button" class="an-btn" @click="navigateTo('/clinics/wards')">
                <v-icon size="15">mdi-arrow-right</v-icon>
                <span>Set up wards</span>
              </button>
            </div>
          </div>
        </section>
      </div>

      <p class="an-footnote">
        Figures are scoped to this clinic's tenant schema. Revenue is counted when an invoice is raised;
        cash received is counted when a payment is recorded. Windows always include today.
      </p>
    </template>

    <v-snackbar v-model="snack.show" :color="snack.color" location="bottom right" rounded="lg" timeout="4000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const brand = useBranding()
const siteCtx = useClinicSite()

// ── Clinic network ──────────────────────────────────────────────────────
const siteLoading = siteCtx.loading
const sitePick = ref(0)
const siteOptions = computed(() => [
  { label: 'All clinics', value: 0 },
  ...siteCtx.sites.value.map(s => ({
    label: s.is_hq ? `${s.name} (HQ)` : s.name,
    value: s.id,
  })),
])

function onSiteChange(value) {
  siteCtx.setActiveSite(value || null)
  hoverIndex.value = -1
  load()
}

// ── State ───────────────────────────────────────────────────────────────
const data = ref(null)
const loading = ref(false)
const error = ref('')
const rangeKey = ref('30d')
const metric = ref('appointments')
const hoverIndex = ref(-1)
const autoRefresh = ref(true)
const updatedAt = ref(null)
const now = ref(Date.now())
let timer = null

const snack = reactive({ show: false, color: 'success', text: '' })
function notify(text, color = 'success') {
  Object.assign(snack, { show: true, color, text })
}

const rangeOptions = [
  { key: 'today', label: 'Today', long: 'Today' },
  { key: '7d', label: '7 days', long: 'Last 7 days' },
  { key: '30d', label: '30 days', long: 'Last 30 days' },
  { key: '90d', label: '90 days', long: 'Last 90 days' },
  { key: 'all', label: 'All time', long: 'All time' },
]

const metricOptions = [
  { key: 'appointments', label: 'Visits' },
  { key: 'consultations', label: 'Consults' },
  { key: 'revenue', label: 'Revenue' },
  { key: 'patients', label: 'Patients' },
  { key: 'lab', label: 'Lab' },
]

const trendDaysFor = { today: 14, '7d': 7, '30d': 14, '90d': 30, all: 30 }
const trendDays = computed(() => trendDaysFor[rangeKey.value] || 14)
const rangeLabel = computed(() => rangeOptions.find(r => r.key === rangeKey.value)?.long || 'Last 30 days')
const windowLabel = computed(() => rangeLabel.value)
const currency = computed(() => data.value?.currency || 'KES')
const ready = computed(() => !!data.value)

const themeVars = computed(() => ({
  '--an-accent': brand.primary.value,
  '--an-on-accent': brand.onPrimary.value,
  '--an-accent-ink': brand.ink.value,
  '--an-accent-soft': brand.tint('primary', 0.2),
  '--an-accent-ring': brand.tint('primary', 0.26),
}))

// ── Payload slices ──────────────────────────────────────────────────────
const kpis = computed(() => data.value?.kpis || {})
const deltas = computed(() => data.value?.deltas || {})
const trend = computed(() => data.value?.trend || { dates: [] })
const revenue = computed(() => data.value?.revenue || { by_status: [] })
const appointments = computed(() => data.value?.appointments || { by_status: [] })
const demand = computed(() => data.value?.demand || { days: [], hours: [], matrix: [], max: 0, peak: {} })
const funnel = computed(() => data.value?.funnel || [])
const departments = computed(() => data.value?.departments || [])
const doctors = computed(() => data.value?.doctors || [])
const patients = computed(() => data.value?.patients || { gender: [], ages: [], payers: [] })
const triage = computed(() => data.value?.triage || { by_acuity: [], total: 0 })
const lab = computed(() => data.value?.lab || { by_status: [], by_priority: [], top_tests: [] })
const pharmacy = computed(() => data.value?.pharmacy || { by_status: [], top_medications: [] })
const wards = computed(() => data.value?.wards || { available: false })
const insights = computed(() => data.value?.insights || [])
const heat = computed(() => data.value?.demand || { days: [], hours: [], matrix: [], max: 0, peak: {} })

const updatedLabel = computed(() => {
  if (!updatedAt.value) return 'Awaiting data'
  const mins = Math.floor((now.value - updatedAt.value) / 60000)
  if (mins < 1) return 'Updated just now'
  if (mins < 60) return `Updated ${mins}m ago`
  return `Updated ${Math.floor(mins / 60)}h ago`
})

const headSub = computed(() => {
  if (!ready.value) {
    return 'One consolidated view of demand, revenue, clinical throughput and patient mix.'
  }
  const k = kpis.value
  return `${fmt(k.consultations)} consultations · ${money(k.revenue_billed)} billed · ${fmt(k.patients_new)} new patients in ${rangeLabel.value.toLowerCase()}.`
})

// ── KPI ribbon ──────────────────────────────────────────────────────────
const kpiCards = computed(() => {
  const k = kpis.value
  const d = deltas.value
  const t = trend.value
  return [
    {
      key: 'appointments', label: 'Appointments', icon: 'mdi-calendar-check', tone: '#2f6dff',
      value: fmt(k.appointments),
      sub: `${fmt(k.appointments_completed)} completed · ${fmt(k.appointments_cancelled)} cancelled`,
      delta: d.appointments, spark: t.appointments, soft: brand.rgba('#2f6dff', 0.16),
    },
    {
      key: 'consultations', label: 'Consultations', icon: 'mdi-stethoscope', tone: '#10b981',
      value: fmt(k.consultations),
      sub: `${fmt(k.consultations_signed)} signed off`,
      delta: d.consultations, spark: t.consultations, soft: brand.rgba('#10b981', 0.16),
    },
    {
      key: 'patients', label: 'New patients', icon: 'mdi-account-plus', tone: '#0ea5e9',
      value: fmt(k.patients_new),
      sub: `${fmt(k.patients_total)} registered in total`,
      delta: d.patients_new, spark: t.patients, soft: brand.rgba('#0ea5e9', 0.16),
    },
    {
      key: 'billed', label: 'Revenue billed', icon: 'mdi-cash-multiple', tone: '#14b8a6',
      value: money(k.revenue_billed),
      sub: `${money(k.avg_ticket)} average invoice`,
      delta: d.revenue_billed, spark: t.revenue, soft: brand.rgba('#14b8a6', 0.16),
    },
    {
      key: 'collected', label: 'Cash collected', icon: 'mdi-cash-check', tone: '#22c55e',
      value: money(k.revenue_collected),
      sub: `${money(k.revenue_outstanding)} still outstanding`,
      delta: d.revenue_collected, spark: t.collected, soft: brand.rgba('#22c55e', 0.16),
    },
    {
      key: 'outstanding', label: 'Collection rate', icon: 'mdi-percent-circle-outline', tone: '#f59e0b',
      value: `${k.collection_rate ?? 0}%`,
      sub: `${money(k.revenue_outstanding)} open balance`,
      meterPct: Math.min(100, Math.max(0, Number(k.collection_rate) || 0)),
    },
    {
      key: 'noshow', label: 'No-show rate', icon: 'mdi-account-off', tone: '#ef4444',
      value: `${k.no_show_rate ?? 0}%`,
      sub: `${fmt(k.appointments_no_show)} missed visits`,
      delta: d.no_show_rate, invert: true,
      meterPct: Math.min(100, Math.round(((Number(k.no_show_rate) || 0) / 15) * 100)),
    },
    {
      key: 'lab', label: 'Lab pending', icon: 'mdi-flask-outline', tone: '#8b5cf6',
      value: fmt(k.lab_pending),
      sub: `${fmt(k.lab_orders)} orders in window`,
      spark: t.lab, soft: brand.rgba('#8b5cf6', 0.16),
    },
  ]
})

// ── Trend chart ─────────────────────────────────────────────────────────
const metricMeta = {
  appointments: { label: 'Visits', money: false },
  consultations: { label: 'Consults', money: false },
  revenue: { label: 'Revenue', money: true },
  patients: { label: 'Patients', money: false },
  lab: { label: 'Lab orders', money: false },
}

const metricLabel = computed(() => metricMeta[metric.value]?.label || 'Activity')
const metricSeries = computed(() => (trend.value[metric.value] || []).map(v => Number(v) || 0))
const metricMax = computed(() => Math.max(1, ...metricSeries.value))
const metricTotal = computed(() => metricSeries.value.reduce((a, b) => a + b, 0))
const metricAvg = computed(() =>
  metricSeries.value.length ? metricTotal.value / metricSeries.value.length : 0)

const metricDelta = computed(() => {
  const series = metricSeries.value
  if (series.length < 4) return 0
  const mid = Math.floor(series.length / 2)
  const older = series.slice(0, mid).reduce((a, b) => a + b, 0)
  const newer = series.slice(mid).reduce((a, b) => a + b, 0)
  if (!older) return newer ? 100 : 0
  return Number((((newer - older) / older) * 100).toFixed(1))
})

const axisStep = computed(() =>
  Math.max(1, Math.ceil((trend.value.dates?.length || 0) / 7)))
function showLabel(i) {
  return i % axisStep.value === 0 || i === (trend.value.dates?.length || 0) - 1
}

function metricDisplay(v) {
  if (metricMeta[metric.value]?.money) return money(v)
  const n = Math.round((Number(v) || 0) * 10) / 10
  return fmt(n)
}
function barHeight(v) {
  const n = Number(v) || 0
  if (!n) return '2%'
  return Math.max(3, Math.round((n / metricMax.value) * 100)) + '%'
}

function sparkPoints(values) {
  const nums = (values || []).map(v => Number(v) || 0)
  if (!nums.length) return []
  const max = Math.max(...nums, 1)
  const min = Math.min(...nums, 0)
  const span = max - min || 1
  return nums.map((n, i) => {
    const x = nums.length === 1 ? 50 : (i / (nums.length - 1)) * 100
    const y = 26 - ((n - min) / span) * 22
    return [x, y]
  })
}
function sparkLine(values) {
  return sparkPoints(values)
    .map(([x, y], i) => `${i ? 'L' : 'M'}${x.toFixed(2)},${y.toFixed(2)}`)
    .join(' ')
}
function sparkArea(values) {
  const pts = sparkPoints(values)
  if (!pts.length) return ''
  const line = pts.map(([x, y], i) => `${i ? 'L' : 'M'}${x.toFixed(2)},${y.toFixed(2)}`).join(' ')
  return `${line} L100,28 L0,28 Z`
}

// ── Revenue ─────────────────────────────────────────────────────────────
const STATUS_COLORS = {
  paid: '#10b981', sent: '#2f6dff', partially_paid: '#f59e0b', draft: '#94a3b8',
  overdue: '#ef4444', cancelled: '#cbd5e1',
  completed: '#10b981', scheduled: '#2f6dff', confirmed: '#0ea5e9',
  in_progress: '#f59e0b', no_show: '#ef4444',
  pending: '#f59e0b', sample_collected: '#0ea5e9', processing: '#6366f1',
  active: '#10b981', dispensed: '#14b8a6', sent_to_exchange: '#0ea5e9',
}
function statusColor(status) {
  return STATUS_COLORS[status] || '#94a3b8'
}

const invoiceSegments = computed(() => {
  let offset = 0
  return (revenue.value.by_status || []).map((s) => {
    const pct = Number(s.pct) || 0
    const seg = {
      status: s.status,
      count: s.count,
      pct,
      color: statusColor(s.status),
      dash: `${pct} ${100 - pct}`,
      offset: -offset,
    }
    offset += pct
    return seg
  })
})

const monthly = computed(() => revenue.value.monthly || [])
const maxMonthly = computed(() =>
  Math.max(1, ...monthly.value.map(m => Number(m.billed) || 0)))
function monthlyHeight(v) {
  const n = Number(v) || 0
  if (!n) return '1%'
  return Math.max(2, Math.round((n / maxMonthly.value) * 100)) + '%'
}

const topServices = computed(() => (revenue.value.top_services || []).slice(0, 6))
const maxService = computed(() =>
  Math.max(1, ...topServices.value.map(s => Number(s.amount) || 0)))
function servicePct(v) {
  return Math.max(2, Math.round(((Number(v) || 0) / maxService.value) * 100))
}

const methods = computed(() => revenue.value.by_method || [])
const cashTotal = computed(() =>
  methods.value.reduce((sum, m) => sum + (Number(m.amount) || 0), 0))
const aging = computed(() => revenue.value.aging || [])
const maxAging = computed(() =>
  Math.max(1, ...aging.value.map(b => Number(b.amount) || 0)))
function agingPct(v) {
  return Math.max(1, Math.round(((Number(v) || 0) / maxAging.value) * 100))
}

const METHOD_ICONS = {
  cash: 'mdi-cash', card: 'mdi-credit-card-outline', mpesa: 'mdi-cellphone',
  insurance: 'mdi-shield-account-outline', bank_transfer: 'mdi-bank-outline',
}
function methodIcon(method) {
  return METHOD_ICONS[method] || 'mdi-wallet-outline'
}
function methodLabel(method) {
  return { mpesa: 'M-Pesa', bank_transfer: 'Bank Transfer', card: 'Card', cash: 'Cash', insurance: 'Insurance' }[method] || pretty(method)
}

// ── Journey / demand ────────────────────────────────────────────────────
const FUNNEL_COLORS = ['#2f6dff', '#0ea5e9', '#8b5cf6', '#10b981', '#14b8a6', '#f59e0b', '#22c55e']
function funnelColor(i) {
  return FUNNEL_COLORS[i % FUNNEL_COLORS.length]
}

function heatStyle(v) {
  const n = Number(v) || 0
  const max = Number(heat.value.max) || 1
  if (!n) {
    return {
      background: 'rgba(var(--v-theme-on-surface), 0.04)',
      color: 'rgba(var(--v-theme-on-surface), 0.4)',
    }
  }
  const ratio = Math.min(1, n / max)
  return {
    background: brand.rgba(brand.primary.value, 0.12 + ratio * 0.7),
    color: ratio > 0.55 ? '#ffffff' : 'rgba(var(--v-theme-on-surface), 0.82)',
  }
}

// ── Departments / clinicians ────────────────────────────────────────────
const departmentsTop = computed(() => {
  const rows = departments.value || []
  const active = rows.filter(d => (Number(d.appointments) || 0) > 0 || (Number(d.revenue) || 0) > 0)
  return (active.length ? active : rows).slice(0, 8)
})
const maxDept = computed(() =>
  Math.max(1, ...departmentsTop.value.map(d => Number(d.appointments) || 0)))
function deptPct(v) {
  return Math.max(2, Math.round(((Number(v) || 0) / maxDept.value) * 100))
}

const doctorsTop = computed(() => (doctors.value || []).slice(0, 6))
const maxDoctor = computed(() =>
  Math.max(1, ...doctorsTop.value.map(d => Number(d.consultations) || 0)))
function doctorPct(v) {
  return Math.max(2, Math.round(((Number(v) || 0) / maxDoctor.value) * 100))
}
function completionClass(v) {
  const n = Number(v) || 0
  if (n >= 95) return 'is-good'
  if (n >= 75) return 'is-warn'
  return 'is-bad'
}

// ── Patients ────────────────────────────────────────────────────────────
const GENDER_COLORS = {
  female: '#ec4899', male: '#2f6dff', other: '#14b8a6', unknown: '#94a3b8',
}
const genderSegments = computed(() =>
  (patients.value.gender || []).map(g => ({
    ...g,
    color: GENDER_COLORS[g.key] || '#94a3b8',
  })))

const ageRows = computed(() => patients.value.ages || [])
const maxAge = computed(() =>
  Math.max(1, ...ageRows.value.map(a => Number(a.count) || 0)))
function agePct(v) {
  return Math.max(2, Math.round(((Number(v) || 0) / maxAge.value) * 100))
}

const payers = computed(() => patients.value.payers || [])
const maxPayer = computed(() =>
  Math.max(1, ...payers.value.map(p => Number(p.count) || 0)))
function payerPct(v) {
  return Math.max(2, Math.round(((Number(v) || 0) / maxPayer.value) * 100))
}

const payerInsight = computed(() => {
  const rows = payers.value
  if (!rows.length) return 'Record insurance providers on patient profiles to unlock payer analysis.'
  const top = rows[0]
  if (top.provider === 'Self-pay') {
    return `${top.pct}% of patients are self-pay — the largest single payer group.`
  }
  return `${top.provider} covers ${top.pct}% of the register (${top.count} patients).`
})

// ── Status + acuity ─────────────────────────────────────────────────────
const apptStatus = computed(() => appointments.value.by_status || [])
const acuityMax = computed(() =>
  Math.max(1, ...(triage.value.by_acuity || []).map(a => Number(a.count) || 0)))
const ACUITY_COLORS = { 1: '#dc2626', 2: '#ea580c', 3: '#f59e0b', 4: '#3b82f6', 5: '#22c55e' }
function acuityColor(level) {
  return ACUITY_COLORS[Number(level)] || '#94a3b8'
}

// ── Lab / pharmacy ─────────────────────────────────────────────────────
const maxTest = computed(() =>
  Math.max(1, ...(lab.value.top_tests || []).map(t => Number(t.count) || 0)))
function testPct(v) {
  return Math.max(2, Math.round(((Number(v) || 0) / maxTest.value) * 100))
}
const maxMed = computed(() =>
  Math.max(1, ...(pharmacy.value.top_medications || []).map(m => Number(m.count) || 0)))
function medPct(v) {
  return Math.max(2, Math.round(((Number(v) || 0) / maxMed.value) * 100))
}

const wardColor = computed(() => {
  const pct = Number(wards.value.occupancy_pct) || 0
  if (pct >= 85) return '#ef4444'
  if (pct >= 60) return '#f59e0b'
  return '#10b981'
})

// ── Formatting ──────────────────────────────────────────────────────────
function fmt(n) {
  return (Number(n) || 0).toLocaleString('en-US')
}
function money(n) {
  const v = Number(n) || 0
  if (!v) return `${currency.value} 0`
  if (Math.abs(v) >= 1_000_000) return `${currency.value} ${(v / 1_000_000).toFixed(1)}M`
  if (Math.abs(v) >= 1_000) return `${currency.value} ${(v / 1_000).toFixed(v >= 10_000 ? 0 : 1)}K`
  return `${currency.value} ${Math.round(v)}`
}
function pretty(s) {
  if (!s) return '—'
  return String(s).replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())
}
function initials(name) {
  return String(name || '?')
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map(p => p[0].toUpperCase())
    .join('')
}
function shortDate(iso) {
  if (!iso) return ''
  const [y, m, d] = String(iso).slice(0, 10).split('-').map(Number)
  if (!y || !m || !d) return String(iso)
  return new Date(y, m - 1, d).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
}
function deltaText(v) {
  if (v === null || v === undefined || Number.isNaN(Number(v))) return '—'
  const n = Number(v)
  const arrow = n > 0 ? '↑' : n < 0 ? '↓' : '→'
  return `${arrow} ${Math.abs(n).toFixed(Math.abs(n) < 10 ? 1 : 0)}%`
}
function deltaClass(v, invert = false) {
  const n = Number(v)
  if (v === null || v === undefined || Number.isNaN(n) || n === 0) return 'is-flat'
  const up = n > 0
  if (invert) return up ? 'is-bad' : 'is-good'
  return up ? 'is-good' : 'is-bad'
}
function aboveZero(v) {
  return (Number(v) || 0) > 0
}

// ── Data loading ────────────────────────────────────────────────────────
async function load({ silent = false } = {}) {
  if (!silent) loading.value = true
  error.value = ''
  try {
    const { data: payload } = await $api.get('/reports/clinic-analytics/', {
      params: {
        range: rangeKey.value,
        trend_days: trendDays.value,
        ...siteCtx.siteParams.value,
      },
    })
    data.value = payload
    updatedAt.value = Date.now()
    now.value = Date.now()
  } catch (e) {
    error.value = e?.response?.data?.detail
      || e?.message
      || 'Could not load clinic analytics.'
    if (silent) notify('Background refresh failed. Showing the last successful snapshot.', 'warning')
  } finally {
    loading.value = false
  }
}

function setRange(key) {
  if (rangeKey.value === key) return
  rangeKey.value = key
  hoverIndex.value = -1
  load()
}

onMounted(async () => {
  siteCtx.restore()
  await siteCtx.loadSites()
  sitePick.value = siteCtx.activeSiteId.value || 0
  load()
  timer = setInterval(() => {
    now.value = Date.now()
    if (autoRefresh.value && document.visibilityState === 'visible') load({ silent: true })
  }, 60000)
})

onUnmounted(() => {
  if (timer) clearInterval(timer)
})

// ── Export ──────────────────────────────────────────────────────────────
function exportCsv() {
  if (!import.meta.client || !ready.value) return
  const rows = [['Section', 'Metric', 'Value']]
  const k = kpis.value

  rows.push(['KPI', 'Appointments', k.appointments ?? 0])
  rows.push(['KPI', 'Appointments completed', k.appointments_completed ?? 0])
  rows.push(['KPI', 'Consultations', k.consultations ?? 0])
  rows.push(['KPI', 'New patients', k.patients_new ?? 0])
  rows.push(['KPI', 'Revenue billed', k.revenue_billed ?? 0])
  rows.push(['KPI', 'Cash collected', k.revenue_collected ?? 0])
  rows.push(['KPI', 'Outstanding', k.revenue_outstanding ?? 0])
  rows.push(['KPI', 'Collection rate (%)', k.collection_rate ?? 0])
  rows.push(['KPI', 'No-show rate (%)', k.no_show_rate ?? 0])
  rows.push(['KPI', 'Lab pending', k.lab_pending ?? 0])
  rows.push(['KPI', 'Prescriptions open', k.rx_open ?? 0])

  monthly.value.forEach(m =>
    rows.push(['Revenue month', m.label, `${m.billed} billed / ${m.collected} collected`]))
  methods.value.forEach(m =>
    rows.push(['Payment method', pretty(m.method), `${m.amount} (${m.pct}%)`]))
  aging.value.forEach(b =>
    rows.push(['Receivable ageing', b.label, `${b.amount} (${b.count})`]))
  departmentsTop.value.forEach(d =>
    rows.push(['Department', d.name, `${d.appointments} visits / ${d.consultations} consults / ${d.revenue}`]))
  doctorsTop.value.forEach(d =>
    rows.push(['Clinician', d.name, `${d.consultations} consults / ${d.completion}% signed / ${d.revenue}`]))
  genderSegments.value.forEach(g =>
    rows.push(['Patient gender', g.label, `${g.count} (${g.pct}%)`]))
  ageRows.value.forEach(a =>
    rows.push(['Patient age band', a.band, `${a.count} (${a.pct}%)`]))
  payers.value.forEach(p =>
    rows.push(['Payer', p.provider, `${p.count} (${p.pct}%)`]))
  lab.value.top_tests?.forEach(t =>
    rows.push(['Lab test', t.name, t.count]))
  pharmacy.value.top_medications?.forEach(m =>
    rows.push(['Medication', m.name, m.count]))

  const csv = rows
    .map(row => row.map(cell => `"${String(cell ?? '').replace(/"/g, '""')}"`).join(','))
    .join('\r\n')

  const blob = new Blob([`\ufeff${csv}`], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = `clinic-analytics-${rangeKey.value}-${new Date().toISOString().slice(0, 10)}.csv`
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
  URL.revokeObjectURL(url)
  notify('Analytics export downloaded.', 'success')
}
</script>

<style scoped>
/* ══ Page tokens ═══════════════════════════════════════════════════════ */
.an-page {
  width: 100%;
  --an-line: rgba(var(--v-theme-on-surface), 0.09);
  --an-line-soft: rgba(var(--v-theme-on-surface), 0.06);
  --an-muted: rgba(var(--v-theme-on-surface), 0.6);
  --an-faint: rgba(var(--v-theme-on-surface), 0.44);
  --an-surface: rgb(var(--v-theme-surface));
  --an-raise: rgba(var(--v-theme-on-surface), 0.035);
}

/* ══ Header ════════════════════════════════════════════════════════════ */
.an-head {
  position: relative;
  border-radius: 18px;
  padding: 17px 20px 12px;
  margin-bottom: 14px;
  background: var(--an-surface);
  border: 1px solid var(--an-line);
  box-shadow: 0 10px 30px rgba(15, 23, 42, 0.055);
  overflow: hidden;
}
.an-head::before {
  content: '';
  position: absolute;
  inset: 0 auto 0 0;
  width: 4px;
  background: linear-gradient(180deg, var(--an-accent), var(--an-accent-soft));
}
.an-head-top {
  display: flex;
  align-items: center;
  gap: 14px;
  min-width: 0;
  flex-wrap: wrap;
}
.an-head-icon {
  width: 50px;
  height: 50px;
  border-radius: 15px;
  display: grid;
  place-items: center;
  flex-shrink: 0;
  color: var(--an-accent-ink);
  background: color-mix(in srgb, var(--an-accent) 12%, transparent);
  border: 1px solid color-mix(in srgb, var(--an-accent) 22%, transparent);
}
.an-head-id { flex: 1; min-width: 200px; }
.an-head-eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 1.4px;
  color: var(--an-faint);
  text-transform: uppercase;
}
.an-head-title {
  margin: 3px 0 2px;
  font-size: 24px;
  line-height: 1.15;
  font-weight: 800;
  letter-spacing: -0.4px;
}
.an-head-sub {
  margin: 0;
  font-size: 12.5px;
  color: var(--an-muted);
  line-height: 1.45;
}
.an-head-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
  justify-content: flex-end;
}
.an-head-foot {
  display: flex;
  align-items: center;
  gap: 7px;
  flex-wrap: wrap;
  margin-top: 13px;
  padding-top: 11px;
  border-top: 1px solid var(--an-line-soft);
}
.an-head-stamp {
  margin-left: auto;
  font-size: 10.5px;
  font-weight: 700;
  color: var(--an-faint);
  letter-spacing: 0.2px;
  white-space: nowrap;
}

.an-live-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: #22c55e;
  box-shadow: 0 0 0 0 rgba(34, 197, 94, 0.55);
  animation: anPulse 2s infinite;
}
@keyframes anPulse {
  0% { box-shadow: 0 0 0 0 rgba(34, 197, 94, 0.5); }
  70% { box-shadow: 0 0 0 6px rgba(34, 197, 94, 0); }
  100% { box-shadow: 0 0 0 0 rgba(34, 197, 94, 0); }
}

.an-chip {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  height: 25px;
  padding: 0 9px;
  border-radius: 999px;
  border: 1px solid var(--an-line);
  background: var(--an-raise);
  font-size: 10.5px;
  font-weight: 700;
  color: var(--an-muted);
  white-space: nowrap;
}
.an-chip--btn {
  cursor: pointer;
  font-family: inherit;
  transition: background 0.15s ease, color 0.15s ease;
}
.an-chip--btn:hover { background: rgba(var(--v-theme-on-surface), 0.07); }
.an-chip--btn.is-off { color: #b45309; border-color: rgba(245, 158, 11, 0.35); background: rgba(245, 158, 11, 0.08); }

.an-range {
  display: inline-flex;
  gap: 2px;
  padding: 3px;
  border-radius: 11px;
  border: 1px solid var(--an-line);
  background: rgba(var(--v-theme-on-surface), 0.045);
}
.an-site-pick {
  max-width: 190px;
  min-width: 140px;
}
.an-site-pick :deep(.v-field) { font-size: 12px; }
.an-range-btn {
  height: 30px;
  padding: 0 11px;
  border: 0;
  border-radius: 8px;
  background: transparent;
  color: var(--an-muted);
  font-family: inherit;
  font-size: 11.5px;
  font-weight: 700;
  cursor: pointer;
  white-space: nowrap;
  transition: background 0.15s ease, color 0.15s ease, box-shadow 0.15s ease;
}
.an-range-btn:hover { color: rgb(var(--v-theme-on-surface)); }
.an-range-btn.is-on {
  background: var(--an-surface);
  color: rgb(var(--v-theme-on-surface));
  box-shadow: 0 2px 8px rgba(15, 23, 42, 0.1), inset 0 -2px 0 var(--an-accent);
}

.an-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  height: 36px;
  padding: 0 13px;
  border-radius: 10px;
  border: 1px solid var(--an-line);
  background: transparent;
  color: rgb(var(--v-theme-on-surface));
  font-family: inherit;
  font-size: 12.5px;
  font-weight: 700;
  cursor: pointer;
  white-space: nowrap;
  transition: background 0.15s ease, transform 0.15s ease, opacity 0.15s ease;
}
.an-btn:hover:not(:disabled) {
  background: rgba(var(--v-theme-on-surface), 0.045);
  transform: translateY(-1px);
}
.an-btn:disabled { opacity: 0.5; cursor: not-allowed; }
.an-btn.is-primary {
  background: var(--an-accent);
  color: var(--an-on-accent);
  border-color: transparent;
  box-shadow: 0 7px 18px var(--an-accent-ring);
}
/* Keep the solid fill on hover — the generic hover rule would otherwise win
   on specificity and leave a white label on a transparent background. */
.an-btn.is-primary:hover:not(:disabled) {
  background: var(--an-accent);
  color: var(--an-on-accent);
  border-color: transparent;
  filter: brightness(1.06);
}
.an-btn.is-primary:active:not(:disabled) { filter: brightness(0.96); }
.an-spin { animation: anSpin 0.9s linear infinite; }
@keyframes anSpin { to { transform: rotate(360deg); } }

/* ══ Error / skeleton ══════════════════════════════════════════════════ */
.an-error {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 16px 18px;
  border-radius: 15px;
  border: 1px solid rgba(239, 68, 68, 0.28);
  background: rgba(239, 68, 68, 0.06);
  margin-bottom: 14px;
}
.an-error div { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px; }
.an-error strong { font-size: 13px; font-weight: 800; }
.an-error span { font-size: 12px; color: var(--an-muted); }

.an-skel {
  border-radius: 15px;
  border: 1px solid var(--an-line-soft);
  background: linear-gradient(
    100deg,
    rgba(var(--v-theme-on-surface), 0.04) 20%,
    rgba(var(--v-theme-on-surface), 0.08) 38%,
    rgba(var(--v-theme-on-surface), 0.04) 56%
  );
  background-size: 220% 100%;
  animation: anShimmer 1.4s ease-in-out infinite;
}
.an-skel--kpi { height: 118px; }
.an-skel--chart { height: 320px; }
@keyframes anShimmer {
  0% { background-position: 120% 0; }
  100% { background-position: -40% 0; }
}

/* ══ Insights ══════════════════════════════════════════════════════════ */
.an-insights {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 9px;
  margin-bottom: 14px;
}
.an-insight {
  display: flex;
  gap: 9px;
  padding: 10px 12px;
  border-radius: 13px;
  border: 1px solid var(--an-line);
  background: var(--an-raise);
}
.an-insight-icon {
  width: 28px;
  height: 28px;
  border-radius: 9px;
  display: grid;
  place-items: center;
  flex-shrink: 0;
}
.an-insight-text { min-width: 0; display: flex; flex-direction: column; gap: 1px; }
.an-insight-text strong {
  font-size: 11.5px;
  font-weight: 800;
  line-height: 1.3;
  overflow-wrap: anywhere;
}
.an-insight-text span {
  font-size: 10.5px;
  line-height: 1.4;
  color: var(--an-muted);
  overflow-wrap: anywhere;
}
.an-insight.is-good { border-color: rgba(16, 185, 129, 0.26); background: rgba(16, 185, 129, 0.06); }
.an-insight.is-good .an-insight-icon { color: #059669; background: rgba(16, 185, 129, 0.13); }
.an-insight.is-warn { border-color: rgba(245, 158, 11, 0.28); background: rgba(245, 158, 11, 0.06); }
.an-insight.is-warn .an-insight-icon { color: #b45309; background: rgba(245, 158, 11, 0.14); }
.an-insight.is-bad { border-color: rgba(239, 68, 68, 0.26); background: rgba(239, 68, 68, 0.06); }
.an-insight.is-bad .an-insight-icon { color: #dc2626; background: rgba(239, 68, 68, 0.12); }
.an-insight.is-info { border-color: rgba(47, 109, 255, 0.24); background: rgba(47, 109, 255, 0.05); }
.an-insight.is-info .an-insight-icon { color: #2f6dff; background: rgba(47, 109, 255, 0.12); }

/* ══ KPI ribbon ════════════════════════════════════════════════════════ */
.an-kpis {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 11px;
  margin-bottom: 14px;
}
.an-kpi {
  position: relative;
  padding: 12px 14px 9px;
  border-radius: 15px;
  border: 1px solid var(--an-line);
  background: var(--an-surface);
  overflow: hidden;
  transition: transform 0.16s ease, box-shadow 0.16s ease, border-color 0.16s ease;
}
.an-kpi::before {
  content: '';
  position: absolute;
  inset: 0 auto 0 0;
  width: 3px;
  background: var(--tone);
  opacity: 0.75;
}
.an-kpi:hover {
  transform: translateY(-2px);
  border-color: color-mix(in srgb, var(--tone) 36%, transparent);
  box-shadow: 0 10px 24px color-mix(in srgb, var(--tone) 14%, transparent);
}
.an-kpi-top { display: flex; align-items: center; gap: 7px; margin-bottom: 6px; }
.an-kpi-icon {
  width: 27px;
  height: 27px;
  border-radius: 9px;
  display: grid;
  place-items: center;
  flex-shrink: 0;
  color: var(--tone);
  background: color-mix(in srgb, var(--tone) 12%, transparent);
}
.an-kpi-label {
  flex: 1;
  min-width: 0;
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.7px;
  text-transform: uppercase;
  color: var(--an-faint);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.an-kpi-value {
  font-size: 25px;
  font-weight: 800;
  line-height: 1.05;
  letter-spacing: -0.5px;
  color: var(--tone);
  font-variant-numeric: tabular-nums;
}
.an-kpi-sub {
  margin-top: 3px;
  font-size: 10.5px;
  font-weight: 600;
  color: var(--an-muted);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.an-spark { display: block; width: 100%; height: 28px; margin-top: 6px; overflow: visible; }
.an-kpi-meter {
  height: 5px;
  margin-top: 11px;
  border-radius: 999px;
  background: rgba(var(--v-theme-on-surface), 0.08);
  overflow: hidden;
}
.an-kpi-meter span { display: block; height: 100%; border-radius: 999px; }

.an-delta {
  display: inline-flex;
  align-items: center;
  height: 19px;
  padding: 0 7px;
  border-radius: 999px;
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.2px;
  white-space: nowrap;
  font-variant-numeric: tabular-nums;
}
.an-delta.is-good { color: #047857; background: rgba(16, 185, 129, 0.14); }
.an-delta.is-bad { color: #b91c1c; background: rgba(239, 68, 68, 0.13); }
.an-delta.is-flat { color: var(--an-muted); background: rgba(var(--v-theme-on-surface), 0.07); }

/* ══ Grid / cards ══════════════════════════════════════════════════════ */
.an-grid {
  display: grid;
  grid-template-columns: repeat(12, minmax(0, 1fr));
  gap: 13px;
  margin-bottom: 13px;
}
.an-col-4 { grid-column: span 4; }
.an-col-5 { grid-column: span 5; }
.an-col-6 { grid-column: span 6; }
.an-col-7 { grid-column: span 7; }
.an-col-8 { grid-column: span 8; }
.an-col-12 { grid-column: span 12; }

.an-card {
  display: flex;
  flex-direction: column;
  min-width: 0;
  border-radius: 16px;
  border: 1px solid var(--an-line);
  background: var(--an-surface);
  box-shadow: 0 6px 20px rgba(15, 23, 42, 0.035);
}
.an-card-head {
  display: flex;
  align-items: center;
  gap: 9px;
  flex-wrap: wrap;
  padding: 11px 14px;
  border-bottom: 1px solid var(--an-line-soft);
  background: linear-gradient(180deg, rgba(var(--v-theme-on-surface), 0.025), transparent);
  border-radius: 16px 16px 0 0;
}
.an-card-icon {
  width: 30px;
  height: 30px;
  border-radius: 9px;
  display: grid;
  place-items: center;
  flex-shrink: 0;
}
.an-card-icon.is-blue { color: #2f6dff; background: rgba(47, 109, 255, 0.11); }
.an-card-icon.is-teal { color: #0d9488; background: rgba(13, 148, 136, 0.11); }
.an-card-icon.is-violet { color: #7c3aed; background: rgba(124, 58, 237, 0.11); }
.an-card-icon.is-amber { color: #b45309; background: rgba(245, 158, 11, 0.13); }
.an-card-icon.is-rose { color: #e11d48; background: rgba(225, 29, 72, 0.1); }
.an-card-icon.is-emerald { color: #059669; background: rgba(16, 185, 129, 0.11); }
.an-card-icon.is-pink { color: #db2777; background: rgba(236, 72, 153, 0.11); }
.an-card-title { flex: 1; min-width: 120px; }
.an-card-title h2 {
  margin: 0;
  font-size: 13px;
  font-weight: 800;
  line-height: 1.25;
  letter-spacing: -0.1px;
}
.an-card-title p {
  margin: 1px 0 0;
  font-size: 10.5px;
  color: var(--an-faint);
  line-height: 1.35;
}
.an-card-tag {
  display: inline-flex;
  align-items: center;
  height: 22px;
  padding: 0 8px;
  border-radius: 999px;
  border: 1px solid var(--an-line);
  background: var(--an-raise);
  font-size: 9.5px;
  font-weight: 800;
  color: var(--an-muted);
  white-space: nowrap;
}
.an-card-tag.is-soft { color: #2f6dff; border-color: rgba(47, 109, 255, 0.25); background: rgba(47, 109, 255, 0.07); }
.an-card-tag.is-warn { color: #b45309; border-color: rgba(245, 158, 11, 0.3); background: rgba(245, 158, 11, 0.09); }
.an-card-body { padding: 13px 14px 15px; flex: 1; min-height: 0; }

.an-tabs { display: inline-flex; gap: 2px; padding: 2px; border-radius: 9px; background: rgba(var(--v-theme-on-surface), 0.045); }
.an-tab {
  height: 26px;
  padding: 0 9px;
  border: 0;
  border-radius: 7px;
  background: transparent;
  color: var(--an-muted);
  font-family: inherit;
  font-size: 10.5px;
  font-weight: 700;
  cursor: pointer;
  white-space: nowrap;
  transition: background 0.15s ease, color 0.15s ease;
}
.an-tab.is-on { background: var(--an-surface); color: rgb(var(--v-theme-on-surface)); box-shadow: 0 1px 5px rgba(15, 23, 42, 0.1); }

/* ══ Trend chart ═══════════════════════════════════════════════════════ */
.an-trend-summary {
  display: flex;
  align-items: flex-end;
  gap: 22px;
  flex-wrap: wrap;
  margin-bottom: 4px;
}
.an-trend-item { display: flex; flex-direction: column; gap: 1px; }
.an-trend-item.is-end { margin-left: auto; align-items: flex-end; }
.an-trend-big { font-size: 28px; font-weight: 800; letter-spacing: -0.6px; line-height: 1; }
.an-trend-mid { font-size: 17px; font-weight: 800; letter-spacing: -0.2px; line-height: 1; }
.an-trend-cap { font-size: 10px; font-weight: 700; color: var(--an-faint); letter-spacing: 0.3px; }

.an-chart { position: relative; height: 190px; margin-top: 12px; }
.an-chart-grid {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  pointer-events: none;
}
.an-chart-grid span { border-top: 1px dashed rgba(var(--v-theme-on-surface), 0.08); }
.an-bars {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: flex-end;
  gap: 4px;
}
.an-bar-slot {
  position: relative;
  flex: 1;
  height: 100%;
  display: flex;
  align-items: flex-end;
  justify-content: center;
}
.an-bar {
  width: 100%;
  max-width: 36px;
  border-radius: 5px 5px 2px 2px;
  background: linear-gradient(180deg, var(--an-accent), var(--an-accent-soft));
  transition: height 0.35s ease, filter 0.15s ease;
}
.an-bar-slot:hover .an-bar { filter: brightness(1.12); }
.an-tip {
  position: absolute;
  bottom: calc(100% + 4px);
  left: 50%;
  transform: translateX(-50%);
  z-index: 5;
  display: flex;
  flex-direction: column;
  gap: 1px;
  padding: 5px 8px;
  border-radius: 8px;
  background: rgb(var(--v-theme-surface));
  border: 1px solid var(--an-line);
  box-shadow: 0 8px 20px rgba(15, 23, 42, 0.16);
  pointer-events: none;
  white-space: nowrap;
}
.an-tip strong { font-size: 11px; font-weight: 800; }
.an-tip span { font-size: 9.5px; color: var(--an-faint); }
.an-axis { display: flex; gap: 4px; margin-top: 7px; }
.an-axis span {
  flex: 1;
  min-width: 0;
  text-align: center;
  font-size: 9px;
  font-weight: 600;
  color: var(--an-faint);
  white-space: nowrap;
  overflow: hidden;
}

/* ══ Donut / revenue ═══════════════════════════════════════════════════ */
.an-donut-wrap { position: relative; width: 150px; height: 150px; margin: 4px auto 10px; }
.an-donut { width: 100%; height: 100%; display: block; }
.an-donut-track { stroke: rgba(var(--v-theme-on-surface), 0.07); }
.an-donut-center {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0;
  pointer-events: none;
}
.an-donut-center strong { font-size: 24px; font-weight: 800; letter-spacing: -0.5px; line-height: 1; }
.an-donut-center span { font-size: 9.5px; font-weight: 700; color: var(--an-faint); text-transform: uppercase; letter-spacing: 0.7px; }
.an-donut-center.is-small strong { font-size: 20px; }

.an-legend { display: flex; flex-direction: column; gap: 4px; margin-bottom: 11px; }
.an-legend-row { display: flex; align-items: center; gap: 6px; font-size: 10.5px; }
.an-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
.an-legend-label { flex: 1; min-width: 0; color: var(--an-muted); font-weight: 600; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.an-legend-val { font-weight: 800; font-variant-numeric: tabular-nums; }
.an-legend-pct { width: 42px; text-align: right; color: var(--an-faint); font-weight: 700; font-variant-numeric: tabular-nums; }

.an-money-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 7px; }
.an-money-grid > div {
  display: flex;
  flex-direction: column;
  gap: 1px;
  padding: 7px 9px;
  border-radius: 9px;
  background: var(--an-raise);
  border: 1px solid var(--an-line-soft);
  min-width: 0;
}
.an-money-grid span { font-size: 9px; font-weight: 800; letter-spacing: 0.5px; text-transform: uppercase; color: var(--an-faint); }
.an-money-grid strong { font-size: 13px; font-weight: 800; font-variant-numeric: tabular-nums; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.is-good { color: #059669; }
.is-bad { color: #dc2626; }

/* ══ Funnel ════════════════════════════════════════════════════════════ */
.an-funnel + .an-funnel { margin-top: 7px; }
.an-funnel-row { display: flex; align-items: center; gap: 9px; }
.an-funnel-icon {
  width: 26px;
  height: 26px;
  border-radius: 8px;
  display: grid;
  place-items: center;
  flex-shrink: 0;
  background: rgba(var(--v-theme-on-surface), 0.05);
}
.an-funnel-main { flex: 1; min-width: 0; }
.an-funnel-top { display: flex; align-items: center; justify-content: space-between; gap: 8px; margin-bottom: 3px; }
.an-funnel-top span { font-size: 10.5px; font-weight: 700; color: var(--an-muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.an-funnel-top strong { font-size: 11.5px; font-weight: 800; font-variant-numeric: tabular-nums; }
.an-funnel-pct { width: 38px; text-align: right; font-size: 10px; font-weight: 800; color: var(--an-faint); font-variant-numeric: tabular-nums; }

.an-track {
  height: 6px;
  border-radius: 999px;
  background: rgba(var(--v-theme-on-surface), 0.07);
  overflow: hidden;
}
.an-track span {
  display: block;
  height: 100%;
  border-radius: 999px;
  background: var(--an-accent);
  transition: width 0.35s ease;
}

.an-note { margin: 10px 0 0; font-size: 9.5px; color: var(--an-faint); line-height: 1.45; }

/* ══ Heatmap ═══════════════════════════════════════════════════════════ */
.an-heat-head { display: flex; align-items: center; gap: 6px; margin-bottom: 4px; }
.an-heat-spacer { flex: 0 0 34px; }
.an-heat-hours { flex: 1; display: grid; grid-template-columns: repeat(13, minmax(0, 1fr)); gap: 4px; }
.an-heat-hours span { text-align: center; font-size: 8px; font-weight: 700; color: var(--an-faint); }
.an-heat-line { display: flex; align-items: center; gap: 6px; margin-bottom: 4px; }
.an-heat-day { flex: 0 0 34px; font-size: 9.5px; font-weight: 800; color: var(--an-faint); }
.an-heat-row { flex: 1; display: grid; grid-template-columns: repeat(13, minmax(0, 1fr)); gap: 4px; }
.an-heat-cell {
  height: 24px;
  border-radius: 5px;
  display: grid;
  place-items: center;
  font-size: 8.5px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  transition: transform 0.12s ease;
  cursor: default;
}
.an-heat-cell:hover { transform: scale(1.08); }
.an-heat-foot { display: flex; align-items: center; gap: 7px; justify-content: flex-end; margin-top: 8px; font-size: 9px; color: var(--an-faint); font-weight: 700; }
.an-heat-scale { display: inline-flex; gap: 2px; }
.an-heat-scale i { width: 13px; height: 9px; border-radius: 2px; }

/* ══ Monthly revenue ═══════════════════════════════════════════════════ */
.an-legend-inline { display: inline-flex; gap: 10px; font-size: 9.5px; font-weight: 700; color: var(--an-faint); }
.an-legend-inline span { display: inline-flex; align-items: center; gap: 4px; }
.an-legend-inline i { width: 9px; height: 9px; border-radius: 2px; }
.an-legend-inline i.is-billed { background: rgba(var(--v-theme-on-surface), 0.16); }
.an-legend-inline i.is-collected { background: var(--an-accent); }

.an-monthly { display: flex; align-items: flex-end; gap: 8px; height: 132px; margin: 2px 0 4px; }
.an-month-col {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-end;
  height: 100%;
  gap: 4px;
}
.an-month-bars { display: flex; align-items: flex-end; justify-content: center; gap: 3px; width: 100%; flex: 1; min-height: 0; }
.an-month-bar { width: 40%; max-width: 18px; border-radius: 4px 4px 2px 2px; transition: height 0.35s ease; }
.an-month-bar.is-billed { background: rgba(var(--v-theme-on-surface), 0.16); }
.an-month-bar.is-collected { background: linear-gradient(180deg, var(--an-accent), var(--an-accent-soft)); }
.an-month-label { font-size: 9px; font-weight: 800; color: var(--an-faint); white-space: nowrap; }
.an-month-value { font-size: 8.5px; font-weight: 700; color: var(--an-muted); white-space: nowrap; }

.an-subhead {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  margin: 10px 0 7px;
  font-size: 9.5px;
  font-weight: 800;
  letter-spacing: 0.5px;
  text-transform: uppercase;
  color: var(--an-faint);
}
.an-subhead.is-spaced { margin-top: 15px; padding-top: 12px; border-top: 1px solid var(--an-line-soft); }
.an-subhead > span:last-child { font-weight: 700; letter-spacing: 0; text-transform: none; color: var(--an-muted); }

.an-services { display: flex; flex-direction: column; gap: 6px; }
.an-service { display: flex; align-items: center; gap: 7px; font-size: 10.5px; }
.an-service-name { flex: 1; min-width: 0; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.an-service-bar { flex: 0 0 22%; height: 5px; border-radius: 999px; background: rgba(var(--v-theme-on-surface), 0.07); overflow: hidden; }
.an-service-bar i { display: block; height: 100%; border-radius: 999px; background: var(--an-accent); }
.an-service-amount { flex-shrink: 0; font-weight: 800; font-variant-numeric: tabular-nums; }

.an-rank {
  width: 18px;
  height: 18px;
  border-radius: 6px;
  display: grid;
  place-items: center;
  flex-shrink: 0;
  font-size: 9px;
  font-weight: 800;
  color: var(--an-faint);
  background: rgba(var(--v-theme-on-surface), 0.055);
}

/* ══ Methods / ageing ══════════════════════════════════════════════════ */
.an-methods { display: flex; flex-direction: column; gap: 8px; }
.an-method { display: flex; align-items: center; gap: 7px; }
.an-method-icon {
  width: 25px;
  height: 25px;
  border-radius: 8px;
  display: grid;
  place-items: center;
  flex-shrink: 0;
  color: var(--an-accent-ink);
  background: color-mix(in srgb, var(--an-accent) 11%, transparent);
}
.an-method-main { flex: 1; min-width: 0; }
.an-method-top { display: flex; align-items: center; justify-content: space-between; gap: 8px; margin-bottom: 3px; font-size: 10.5px; }
.an-method-top span { color: var(--an-muted); font-weight: 700; }
.an-method-top strong { font-weight: 800; font-variant-numeric: tabular-nums; }
.an-method-pct { width: 34px; text-align: right; font-size: 9.5px; font-weight: 800; color: var(--an-faint); }

.an-aging { display: flex; flex-direction: column; gap: 6px; }
.an-aging-row { display: flex; align-items: center; gap: 7px; font-size: 10.5px; }
.an-aging-label { flex: 0 0 66px; font-weight: 700; color: var(--an-muted); }
.an-aging-bar { flex: 1; height: 5px; border-radius: 999px; background: rgba(var(--v-theme-on-surface), 0.07); overflow: hidden; }
.an-aging-bar i { display: block; height: 100%; border-radius: 999px; background: linear-gradient(90deg, #f59e0b, #ef4444); }
.an-aging-amount { flex: 0 0 62px; text-align: right; font-weight: 800; font-variant-numeric: tabular-nums; }
.an-aging-count {
  flex: 0 0 22px;
  text-align: center;
  font-size: 9px;
  font-weight: 800;
  color: var(--an-faint);
  background: rgba(var(--v-theme-on-surface), 0.055);
  border-radius: 999px;
  padding: 1px 0;
}

/* ══ Departments / doctors ═════════════════════════════════════════════ */
.an-dept { display: flex; align-items: center; gap: 9px; padding: 6px 0; }
.an-dept + .an-dept { border-top: 1px dashed var(--an-line-soft); }
.an-dept-main { flex: 1; min-width: 0; }
.an-dept-top { display: flex; align-items: baseline; justify-content: space-between; gap: 10px; margin-bottom: 4px; }
.an-dept-name { font-size: 11.5px; font-weight: 700; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.an-dept-nums { font-size: 9.5px; color: var(--an-faint); white-space: nowrap; }
.an-dept-nums strong { font-size: 11px; font-weight: 800; color: rgb(var(--v-theme-on-surface)); }
.an-dept-rev {
  flex: 0 0 auto;
  font-size: 10.5px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}

.an-doctor { display: flex; gap: 9px; padding: 6px 0; }
.an-doctor + .an-doctor { border-top: 1px dashed var(--an-line-soft); }
.an-avatar {
  width: 30px;
  height: 30px;
  border-radius: 9px;
  display: grid;
  place-items: center;
  flex-shrink: 0;
  font-size: 10px;
  font-weight: 800;
  color: var(--an-accent-ink);
  background: color-mix(in srgb, var(--an-accent) 12%, transparent);
  border: 1px solid color-mix(in srgb, var(--an-accent) 20%, transparent);
}
.an-doctor-main { flex: 1; min-width: 0; }
.an-doctor-top { display: flex; align-items: center; justify-content: space-between; gap: 8px; margin-bottom: 4px; }
.an-doctor-name { font-size: 11.5px; font-weight: 700; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.an-doctor-top strong { font-size: 11.5px; font-weight: 800; font-variant-numeric: tabular-nums; }
.an-doctor-foot { display: flex; align-items: center; justify-content: space-between; gap: 8px; margin-top: 3px; }
.an-doctor-foot > span:first-child { font-size: 9px; color: var(--an-faint); font-weight: 600; }
.an-pill {
  display: inline-flex;
  align-items: center;
  height: 17px;
  padding: 0 6px;
  border-radius: 999px;
  font-size: 8.5px;
  font-weight: 800;
  white-space: nowrap;
}
.an-pill.is-good { color: #047857; background: rgba(16, 185, 129, 0.14); }
.an-pill.is-warn { color: #b45309; background: rgba(245, 158, 11, 0.14); }
.an-pill.is-bad { color: #b91c1c; background: rgba(239, 68, 68, 0.13); }

/* ══ Patient mix ═══════════════════════════════════════════════════════ */
.an-gender-bar { display: flex; height: 13px; border-radius: 999px; overflow: hidden; gap: 2px; background: rgba(var(--v-theme-on-surface), 0.06); }
.an-gender-bar span { height: 100%; }
.an-gender-legend { display: flex; flex-wrap: wrap; gap: 10px; margin-top: 7px; }
.an-gender-legend span { display: inline-flex; align-items: center; gap: 4px; font-size: 9.5px; font-weight: 700; color: var(--an-muted); }
.an-gender-legend i { width: 8px; height: 8px; border-radius: 50%; }

.an-ages { display: flex; flex-direction: column; gap: 5px; }
.an-age-row { display: flex; align-items: center; gap: 7px; font-size: 10.5px; }
.an-age-label { flex: 0 0 42px; font-weight: 700; color: var(--an-muted); }
.an-age-bar { flex: 1; height: 5px; border-radius: 999px; background: rgba(var(--v-theme-on-surface), 0.07); overflow: hidden; }
.an-age-bar i { display: block; height: 100%; border-radius: 999px; background: var(--an-accent); }
.an-age-count { flex: 0 0 22px; text-align: right; font-weight: 800; font-variant-numeric: tabular-nums; }

.an-mini-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 7px; margin-top: 12px; }
.an-mini-grid > div { display: flex; flex-direction: column; gap: 1px; padding: 7px 9px; border-radius: 9px; background: var(--an-raise); border: 1px solid var(--an-line-soft); }
.an-mini-grid span { font-size: 8.5px; font-weight: 800; letter-spacing: 0.5px; text-transform: uppercase; color: var(--an-faint); }
.an-mini-grid strong { font-size: 14px; font-weight: 800; font-variant-numeric: tabular-nums; }

.an-payer + .an-payer { margin-top: 7px; }
.an-payer-top { display: flex; align-items: baseline; justify-content: space-between; gap: 8px; margin-bottom: 3px; font-size: 10.5px; }
.an-payer-top > span:first-child { font-weight: 700; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.an-payer-top > span:last-child { font-size: 9.5px; color: var(--an-faint); white-space: nowrap; }
.an-payer-top strong { color: rgb(var(--v-theme-on-surface)); font-weight: 800; }

.an-callout {
  display: flex;
  gap: 7px;
  align-items: flex-start;
  margin-top: 14px;
  padding: 9px 10px;
  border-radius: 10px;
  border: 1px solid var(--an-line-soft);
  background: var(--an-raise);
  font-size: 10px;
  line-height: 1.45;
  color: var(--an-muted);
}
.an-callout .v-icon { color: #f59e0b; flex-shrink: 0; margin-top: 1px; }

/* ══ Status / acuity ═══════════════════════════════════════════════════ */
.an-status-row { display: flex; align-items: center; gap: 7px; font-size: 10.5px; padding: 2px 0; }
.an-status-label { flex: 0 0 74px; font-weight: 700; color: var(--an-muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.an-status-bar { flex: 1; height: 5px; border-radius: 999px; background: rgba(var(--v-theme-on-surface), 0.07); overflow: hidden; }
.an-status-bar i { display: block; height: 100%; border-radius: 999px; }
.an-status-count { flex: 0 0 26px; text-align: right; font-weight: 800; font-variant-numeric: tabular-nums; }
.an-status-pct { flex: 0 0 36px; text-align: right; font-size: 9.5px; color: var(--an-faint); font-weight: 700; }

.an-acuity { display: flex; flex-wrap: wrap; gap: 6px; }
.an-acuity-chip {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 4px 8px;
  border-radius: 8px;
  border: 1px solid color-mix(in srgb, var(--tone) 30%, transparent);
  background: color-mix(in srgb, var(--tone) 8%, transparent);
}
.an-acuity-n { font-size: 12px; font-weight: 800; color: var(--tone); font-variant-numeric: tabular-nums; }
.an-acuity-l { font-size: 9px; font-weight: 800; color: var(--an-muted); text-transform: uppercase; letter-spacing: 0.4px; }

/* ══ Lab / pharmacy ════════════════════════════════════════════════════ */
.an-stats { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 7px; margin-bottom: 11px; }
.an-stat { display: flex; flex-direction: column; gap: 1px; padding: 7px 9px; border-radius: 9px; background: var(--an-raise); border: 1px solid var(--an-line-soft); min-width: 0; }
.an-stat span { font-size: 8.5px; font-weight: 800; letter-spacing: 0.5px; text-transform: uppercase; color: var(--an-faint); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.an-stat strong { font-size: 15px; font-weight: 800; font-variant-numeric: tabular-nums; line-height: 1.2; }

.an-seg { display: flex; height: 11px; border-radius: 999px; overflow: hidden; gap: 2px; background: rgba(var(--v-theme-on-surface), 0.05); }
.an-seg span { height: 100%; }
.an-seg-legend { display: flex; flex-wrap: wrap; gap: 9px; margin-top: 7px; }
.an-seg-legend span { display: inline-flex; align-items: center; gap: 4px; font-size: 9px; font-weight: 700; color: var(--an-muted); }
.an-seg-legend i { width: 7px; height: 7px; border-radius: 50%; }

.an-test-list { display: flex; flex-direction: column; gap: 5px; }
.an-test-row { display: flex; align-items: center; gap: 8px; font-size: 10.5px; }
.an-test-row > span:first-child { flex: 1; min-width: 0; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.an-test-bar { flex: 0 0 22%; height: 5px; border-radius: 999px; background: rgba(var(--v-theme-on-surface), 0.07); overflow: hidden; }
.an-test-bar i { display: block; height: 100%; border-radius: 999px; background: var(--an-accent); }
.an-test-row strong { flex: 0 0 22px; text-align: right; font-weight: 800; font-variant-numeric: tabular-nums; }

/* ══ Wards ═════════════════════════════════════════════════════════════ */
.an-wards { display: grid; grid-template-columns: 150px minmax(0, 1fr) minmax(0, 1.2fr); gap: 18px; align-items: center; }
.an-ward-ring { position: relative; width: 130px; height: 130px; justify-self: center; }
.an-ward-ring svg { width: 100%; height: 100%; }
.an-ward-stats { display: grid; grid-template-columns: 1fr 1fr; gap: 7px; }
.an-ward-list { display: flex; flex-direction: column; gap: 7px; }
.an-ward-row .an-ward-top { display: flex; align-items: baseline; justify-content: space-between; gap: 8px; margin-bottom: 3px; font-size: 10.5px; }
.an-ward-row .an-ward-top span:first-child { font-weight: 700; }
.an-ward-row .an-ward-top span:last-child { font-size: 9.5px; color: var(--an-faint); font-weight: 700; }

.an-empty-block {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 5px;
  padding: 22px 16px;
  text-align: center;
  color: var(--an-muted);
}
.an-empty-block .v-icon { color: var(--an-faint); margin-bottom: 2px; }
.an-empty-block strong { font-size: 12.5px; font-weight: 800; color: rgb(var(--v-theme-on-surface)); }
.an-empty-block span { font-size: 11px; max-width: 420px; line-height: 1.5; }
.an-empty-block .an-btn { margin-top: 7px; }

.an-empty { margin: 4px 0 0; font-size: 10.5px; color: var(--an-faint); font-style: italic; }

.an-footnote {
  margin: 4px 2px 0;
  font-size: 9.5px;
  line-height: 1.5;
  color: var(--an-faint);
}

/* ══ Responsive ════════════════════════════════════════════════════════ */
@media (max-width: 1279px) {
  .an-col-5, .an-col-7, .an-col-8 { grid-column: span 12; }
  .an-wards { grid-template-columns: 150px minmax(0, 1fr); }
  .an-ward-list { grid-column: span 2; }
}
@media (max-width: 1099px) {
  .an-col-4, .an-col-6 { grid-column: span 6; }
  .an-kpis { grid-template-columns: repeat(2, minmax(0, 1fr)); }
}
@media (max-width: 899px) {
  .an-head-actions { width: 100%; justify-content: flex-start; }
  .an-head-stamp { margin-left: 0; }
  .an-trend-item.is-end { margin-left: 0; align-items: flex-start; }
  .an-col-4, .an-col-5, .an-col-6, .an-col-7, .an-col-8, .an-col-12 { grid-column: span 12; }
}
@media (max-width: 767px) {
  .an-kpi-value { font-size: 21px; }
  .an-trend-big { font-size: 23px; }
  .an-head-title { font-size: 20px; }
  .an-heat-cell { height: 19px; font-size: 7.5px; }
  .an-heat-hours span { font-size: 7px; }
  .an-heat-day, .an-heat-spacer { flex-basis: 28px; }
  .an-wards { grid-template-columns: minmax(0, 1fr); }
  .an-ward-list { grid-column: span 1; }
  .an-ward-ring { justify-self: start; }
}
</style>
