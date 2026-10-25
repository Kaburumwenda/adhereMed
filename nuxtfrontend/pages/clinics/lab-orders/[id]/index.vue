<template>
  <v-container fluid class="pa-4 pa-md-6 lo-page" :style="themeVars">
    <template v-if="order">
      <!-- ═══════════════ Header ═══════════════ -->
      <header class="lo-head">
        <div class="lo-head-top">
          <NuxtLink to="/clinics/lab-orders" class="lo-back" title="Back to lab orders" aria-label="Back to lab orders">
            <v-icon size="18">mdi-arrow-left</v-icon>
          </NuxtLink>

          <div class="lo-head-icon">
            <v-icon size="26">mdi-microscope</v-icon>
          </div>

          <div class="lo-head-id">
            <div class="lo-head-eyebrow">
              <span class="lo-live-dot"></span>
              LABORATORY · ORDER #{{ order.id }}
            </div>
            <h1 class="lo-head-title">{{ order.patient_name }}</h1>
            <p class="lo-head-sub">{{ headSub }}</p>
          </div>

          <div class="lo-head-actions">
            <button type="button" class="lo-btn" :disabled="loading" @click="load">
              <v-icon size="15" :class="{ 'lo-spin': loading }">mdi-refresh</v-icon>
              <span>Refresh</span>
            </button>
            <button type="button" class="lo-btn" :disabled="downloadingPdf" @click="downloadReport">
              <v-icon size="15" :class="{ 'lo-spin': downloadingPdf }">
                {{ downloadingPdf ? 'mdi-loading' : verifiedSigner ? 'mdi-file-pdf-box' : 'mdi-file-lock-outline' }}
              </v-icon>
              <span>{{ downloadingPdf ? 'Building…' : 'Report PDF' }}</span>
            </button>
            <NuxtLink v-if="canEdit" class="lo-btn" :to="`/clinics/lab-orders/${orderId}/edit`">
              <v-icon size="15">mdi-pencil-outline</v-icon>
              <span>Edit</span>
            </NuxtLink>

            <button v-if="order.status === 'pending'" type="button" class="lo-btn"
              :disabled="busy" @click="updateStatus('sample_collected')">
              <v-icon size="15">mdi-test-tube</v-icon>
              <span>Mark collected</span>
            </button>
            <button v-else-if="order.status === 'sample_collected'" type="button" class="lo-btn"
              :disabled="busy" @click="updateStatus('processing')">
              <v-icon size="15">mdi-progress-clock</v-icon>
              <span>Start processing</span>
            </button>

            <button v-if="canEnterResults && pendingTests.length" type="button" class="lo-btn is-primary"
              @click="openResult()">
              <v-icon size="16">mdi-flask-plus-outline</v-icon>
              <span>Enter results</span>
            </button>
            <button v-else-if="order.status === 'processing'" type="button" class="lo-btn is-primary"
              :disabled="busy" @click="updateStatus('completed')">
              <v-icon size="16">mdi-check-circle-outline</v-icon>
              <span>Complete order</span>
            </button>

            <button v-if="canCancel" type="button" class="lo-btn is-danger" :disabled="busy" @click="cancelOrder">
              <v-icon size="15">mdi-cancel</v-icon>
              <span>Cancel</span>
            </button>
          </div>
        </div>

        <div class="lo-head-foot">
          <span class="lo-pill" :class="`is-${statusMeta(order.status).tone}`">
            <v-icon size="12">{{ statusMeta(order.status).icon }}</v-icon>
            {{ statusMeta(order.status).label }}
          </span>
          <span class="lo-pill" :class="priorityTone(order.priority)">
            <v-icon size="12">{{ priorityIcon(order.priority) }}</v-icon>
            {{ priorityLabel(order.priority) }} priority
          </span>
          <span class="lo-chip">
            <v-icon size="13">mdi-test-tube</v-icon>
            {{ testsTotal }} test{{ testsTotal === 1 ? '' : 's' }}
          </span>
          <span class="lo-chip" :class="resultedCount === testsTotal && testsTotal ? 'is-good' : ''">
            <v-icon size="13">mdi-flask-outline</v-icon>
            {{ resultedCount }}/{{ testsTotal }} resulted
          </span>
          <span v-if="abnormalCount" class="lo-chip is-bad">
            <v-icon size="13">mdi-alert-outline</v-icon>
            {{ abnormalCount }} abnormal
          </span>
          <span v-if="order.is_home_collection" class="lo-chip is-info">
            <v-icon size="13">mdi-home-clock-outline</v-icon>
            Home collection
          </span>
          <span class="lo-chip">
            <v-icon size="13">mdi-map-marker-outline</v-icon>
            {{ order.clinic_site_name || 'Head office' }}
          </span>
          <span class="lo-head-stamp">{{ updatedLabel }}</span>
        </div>
      </header>

      <!-- ═══════════════ Workflow ═══════════════ -->
      <section v-if="order.status === 'cancelled'" class="lo-cancel-banner">
        <v-icon size="18">mdi-cancel</v-icon>
        <div>
          <b>This order was cancelled.</b>
          <span>No further collection, processing or result entry is expected. Re-open it from the edit page if this was a mistake.</span>
        </div>
      </section>

      <section v-else class="lo-flow">
        <template v-for="(step, index) in FLOW" :key="step.value">
          <div class="lo-step" :class="`is-${stepState(index)}`">
            <span class="lo-step-node">
              <v-icon size="15">{{ step.icon }}</v-icon>
            </span>
            <span class="lo-step-text">
              <b>{{ step.label }}</b>
              <em>{{ step.hint }}</em>
            </span>
          </div>
          <span v-if="index < FLOW.length - 1" class="lo-step-rail">
            <i :class="{ 'is-on': stepState(index) === 'done' }"></i>
          </span>
        </template>
        <span class="lo-flow-progress">{{ progressPct }}%</span>
      </section>

      <!-- ═══════════════ KPIs ═══════════════ -->
      <div class="lo-kpis">
        <div class="lo-kpi">
          <span class="lo-kpi-ico"><v-icon size="15">mdi-test-tube</v-icon></span>
          <b>{{ testsTotal }}</b>
          <span class="lo-kpi-l">Tests ordered</span>
        </div>
        <div class="lo-kpi" :class="resultedCount === testsTotal && testsTotal ? 'is-good' : ''">
          <span class="lo-kpi-ico"><v-icon size="15">mdi-flask-outline</v-icon></span>
          <b>{{ resultedCount }}<i>/{{ testsTotal }}</i></b>
          <span class="lo-kpi-l">Results entered</span>
        </div>
        <div class="lo-kpi" :class="abnormalCount ? 'is-bad' : 'is-good'">
          <span class="lo-kpi-ico"><v-icon size="15">mdi-alert-outline</v-icon></span>
          <b>{{ abnormalCount }}</b>
          <span class="lo-kpi-l">Abnormal flags</span>
        </div>
        <div class="lo-kpi">
          <span class="lo-kpi-ico"><v-icon size="15">mdi-check-decagram-outline</v-icon></span>
          <b>{{ verifiedCount }}<i>/{{ results.length }}</i></b>
          <span class="lo-kpi-l">Verified</span>
        </div>
        <div class="lo-kpi">
          <span class="lo-kpi-ico"><v-icon size="15">mdi-cube-outline</v-icon></span>
          <b>{{ specimens.length }}</b>
          <span class="lo-kpi-l">Specimens</span>
        </div>
        <div class="lo-kpi">
          <span class="lo-kpi-ico"><v-icon size="15">mdi-timer-sand</v-icon></span>
          <b>{{ expectedTat }}</b>
          <span class="lo-kpi-l">Expected turnaround</span>
        </div>
        <div class="lo-kpi">
          <span class="lo-kpi-ico"><v-icon size="15">mdi-cash-multiple</v-icon></span>
          <b>{{ money(orderValue) }}</b>
          <span class="lo-kpi-l">Order value</span>
        </div>
      </div>

      <v-row dense>
        <!-- ═══════════════ Main column ═══════════════ -->
        <v-col cols="12" lg="8">
          <!-- Clinical context -->
          <section v-if="order.clinical_notes || orderExtra?.notes_for_lab" class="lo-panel lo-note">
            <header class="lo-panel-head">
              <span class="lo-panel-ico is-amber"><v-icon size="15">mdi-note-text-outline</v-icon></span>
              <h2>Clinical context</h2>
            </header>
            <div class="lo-panel-body">
              <div v-if="order.clinical_notes" class="lo-note-block">
                <span>Requesting notes</span>
                <p>{{ order.clinical_notes }}</p>
              </div>
              <div v-if="orderExtra?.notes_for_lab" class="lo-note-block">
                <span>Notes for the laboratory</span>
                <p>{{ orderExtra.notes_for_lab }}</p>
              </div>
            </div>
          </section>

          <!-- Test results -->
          <section class="lo-panel">
            <header class="lo-panel-head">
              <span class="lo-panel-ico"><v-icon size="15">mdi-flask-outline</v-icon></span>
              <h2>Test results</h2>
              <span class="lo-panel-count">{{ resultedCount }}/{{ testsTotal }}</span>
              <div class="lo-panel-tools">
                <div class="lo-seg">
                  <button v-for="filter in resultFilters" :key="filter.value" type="button"
                    :class="{ 'is-on': resultFilter === filter.value }" @click="resultFilter = filter.value">
                    {{ filter.label }}<em v-if="filter.count">{{ filter.count }}</em>
                  </button>
                </div>
              </div>
            </header>

            <div class="lo-panel-body">
              <div v-if="!orderedTests.length" class="lo-empty">
                <v-icon size="30">mdi-test-tube-off</v-icon>
                <b>No tests on this order</b>
                <span>The order has no catalogue tests attached yet.</span>
              </div>

              <article v-for="test in filteredTests" :key="test.id" class="lo-test"
                :class="{ 'is-done': resultsFor(test.id).length, 'is-bad': hasAbnormal(test.id) }">
                <div class="lo-test-head">
                  <span class="lo-test-dept">{{ test.department || 'General' }}</span>
                  <div class="lo-test-id">
                    <b>{{ test.name }}</b>
                    <span v-if="test.code" class="lo-code">{{ test.code }}</span>
                  </div>
                  <span class="lo-pill" :class="testTone(test)">
                    <v-icon size="12">{{ testToneIcon(test) }}</v-icon>
                    {{ testToneLabel(test) }}
                  </span>
                  <button type="button" class="lo-btn is-sm" @click="openResult(test)">
                    <v-icon size="14">{{ resultsFor(test.id).length ? 'mdi-pencil-outline' : 'mdi-flask-plus-outline' }}</v-icon>
                    <span>{{ resultsFor(test.id).length ? 'Amend' : 'Enter result' }}</span>
                  </button>
                </div>

                <div class="lo-test-meta">
                  <span><v-icon size="12">mdi-test-tube</v-icon>{{ test.specimen_type || 'Specimen n/a' }}</span>
                  <span><v-icon size="12">mdi-timer-outline</v-icon>{{ test.turnaround_time || 'Turnaround n/a' }}</span>
                  <span><v-icon size="12">mdi-cash</v-icon>{{ money(test.price) }}</span>
                  <span v-if="rangeCount(test)" class="lo-test-refcount">
                    {{ rangeCount(test) }} analyte{{ rangeCount(test) === 1 ? '' : 's' }}
                  </span>
                </div>

                <!-- entered results -->
                <div v-if="resultsFor(test.id).length" class="lo-result-list">
                  <div v-for="result in resultsFor(test.id)" :key="result.id" class="lo-result">
                    <div class="lo-result-main">
                      <div class="lo-result-value">
                        {{ result.result_value }}<em v-if="result.unit">{{ result.unit }}</em>
                      </div>
                      <div class="lo-result-note">
                        <span>{{ result.performed_by_name || 'Unknown performer' }}</span>
                        <span>·</span>
                        <span>{{ fmtDateTime(result.result_date) }}</span>
                        <template v-if="result.comments">
                          <span>·</span>
                          <span class="lo-result-comment">{{ result.comments }}</span>
                        </template>
                      </div>
                    </div>
                    <div class="lo-result-side">
                      <span class="lo-pill" :class="result.is_abnormal ? 'is-bad' : 'is-good'">
                        {{ result.is_abnormal ? 'Abnormal' : 'Within range' }}
                      </span>
                      <span class="lo-pill" :class="result.verified_by ? 'is-good' : 'is-warn'">
                        <v-icon size="11">{{ result.verified_by ? 'mdi-check-decagram' : 'mdi-clock-outline' }}</v-icon>
                        {{ result.verified_by ? 'Verified' : 'Unverified' }}
                      </span>
                      <a
                        v-if="result.attachment"
                        class="lo-pill is-accent lo-attach-pill"
                        :href="result.attachment"
                        target="_blank"
                        rel="noopener"
                        :title="`Open ${result.attachment_name || 'attached report'}`"
                      >
                        <v-icon size="11">{{ result.attachment_kind === 'pdf' ? 'mdi-file-pdf-box' : 'mdi-file-image-outline' }}</v-icon>
                        {{ result.attachment_kind === 'pdf' ? 'PDF report' : 'Scanned report' }}
                      </a>
                      <button
                        v-if="!result.verified_by"
                        type="button"
                        class="lo-link"
                        :disabled="!authEnabled"
                        @click="openAuthDialog('verified')"
                      >
                        Authorise
                      </button>
                    </div>
                  </div>
                </div>

                <!-- reference preview -->
                <div v-else class="lo-test-empty">
                  <template v-if="rangeEntries(test).length">
                    <span class="lo-test-empty-label">Reference</span>
                    <span v-for="[key, value] in rangeEntries(test).slice(0, 3)" :key="key" class="lo-range-chip">
                      {{ key }} <b>{{ value }}</b>
                    </span>
                    <span v-if="rangeEntries(test).length > 3" class="lo-range-chip is-more">
                      +{{ rangeEntries(test).length - 3 }} more
                    </span>
                  </template>
                  <span v-else class="lo-test-empty-label">No reference range defined for this test.</span>
                </div>
              </article>

              <div v-if="orderedTests.length && !filteredTests.length" class="lo-empty">
                <v-icon size="30">mdi-filter-off-outline</v-icon>
                <b>Nothing in this filter</b>
                <span>Switch back to “All” to see the full panel.</span>
              </div>
            </div>

            <footer v-if="allResultsIn && order.status !== 'completed' && order.status !== 'cancelled'" class="lo-panel-foot">
              <span class="lo-foot-hint">
                <v-icon size="14">mdi-check-all</v-icon>
                Every test has a result. Authorise the order to close the loop.
              </span>
              <button type="button" class="lo-btn is-primary is-sm" :disabled="busy" @click="updateStatus('completed')">
                <v-icon size="14">mdi-check-circle-outline</v-icon>
                <span>Mark order completed</span>
              </button>
            </footer>
          </section>

          <!-- Referring and billing -->
          <section v-if="orderExtra" class="lo-panel">
            <header class="lo-panel-head">
              <span class="lo-panel-ico is-indigo"><v-icon size="15">mdi-hospital-building</v-icon></span>
              <h2>Referring and billing</h2>
            </header>
            <div class="lo-panel-body">
              <div v-if="hasReferringDetails" class="lo-dl lo-dl-grid">
                <div v-if="orderExtra.referring_doctor_name">
                  <span>Referring doctor</span>
                  <b>{{ orderExtra.referring_doctor_name }}</b>
                </div>
                <div v-if="orderExtra.referring_facility_name">
                  <span>Referring facility</span>
                  <b>{{ orderExtra.referring_facility_name }}</b>
                </div>
                <div v-if="orderExtra.payer_type">
                  <span>Payer</span>
                  <b class="is-cap">{{ orderExtra.payer_type }}</b>
                </div>
                <div v-if="orderExtra.accession_number">
                  <span>Accession number</span>
                  <b class="lo-mono">{{ orderExtra.accession_number }}</b>
                </div>
              </div>
              <p v-else class="lo-muted-line">No referring details recorded for this order.</p>
            </div>
          </section>

          <!-- Activity -->
          <section class="lo-panel">
            <header class="lo-panel-head">
              <span class="lo-panel-ico is-slate"><v-icon size="15">mdi-history</v-icon></span>
              <h2>Activity</h2>
              <span class="lo-panel-count">{{ activity.length }}</span>
            </header>
            <div class="lo-panel-body">
              <ul v-if="activity.length" class="lo-tl">
                <li v-for="event in activity" :key="event.key" :class="`is-${event.tone}`">
                  <span class="lo-tl-dot"><v-icon size="12">{{ event.icon }}</v-icon></span>
                  <div class="lo-tl-main">
                    <b>{{ event.title }}</b>
                    <span>{{ event.detail }}</span>
                  </div>
                  <span class="lo-tl-time" :title="fmtDateTime(event.at)">{{ relativeTime(event.at) }}</span>
                </li>
              </ul>
              <div v-else class="lo-empty is-tight">
                <v-icon size="26">mdi-history</v-icon>
                <b>Nothing recorded yet</b>
                <span>Collection and result events will appear here.</span>
              </div>
            </div>
          </section>
        </v-col>

        <!-- ═══════════════ Sidebar ═══════════════ -->
        <v-col cols="12" lg="4">
          <!-- Authorisation -->
          <section class="lo-panel lo-auth">
            <header class="lo-panel-head">
              <span class="lo-panel-ico" :class="authComplete ? 'is-good' : 'is-amber'">
                <v-icon size="15">mdi-shield-check-outline</v-icon>
              </span>
              <h2>Authorisation</h2>
              <span class="lo-pill" :class="authComplete ? 'is-good' : 'is-warn'">
                {{ authComplete ? 'Signed off' : 'Pending' }}
              </span>
            </header>

            <div class="lo-panel-body">
              <div v-for="slot in authSlots" :key="slot.role" class="lo-auth-slot">
                <div class="lo-auth-head">
                  <span class="lo-auth-label">{{ slot.label }}</span>
                  <span v-if="slot.data" class="lo-pill is-good">
                    <v-icon size="11">mdi-check-decagram</v-icon>
                    signed
                  </span>
                  <span v-else class="lo-pill is-warn">awaiting</span>
                </div>

                <template v-if="slot.data">
                  <img
                    v-if="slot.data.signature"
                    :src="slot.data.signature"
                    :alt="`${slot.data.name} signature`"
                    class="lo-auth-sig"
                  />
                  <div v-else class="lo-auth-nosig">No signature image recorded</div>
                  <div class="lo-auth-person">
                    <b>{{ slot.data.name }}</b>
                    <span>{{ slot.data.title || '—' }}</span>
                    <span>{{ fmtDateTime(slot.data.signed_at) }}</span>
                  </div>
                  <button type="button" class="lo-link is-quiet" @click="revokeSignoff(slot.role)">
                    Withdraw signature
                  </button>
                </template>

                <template v-else>
                  <button
                    type="button"
                    class="lo-btn is-sm lo-auth-cta"
                    :disabled="!authEnabled"
                    @click="openAuthDialog(slot.role)"
                  >
                    <v-icon size="14">{{ slot.role === 'verified' ? 'mdi-shield-check-outline' : 'mdi-flask-outline' }}</v-icon>
                    <span>{{ slot.role === 'verified' ? 'Authorise & sign' : 'Sign as performer' }}</span>
                  </button>
                </template>
              </div>

              <p v-if="!authEnabled" class="lo-auth-hint">
                <v-icon size="12">mdi-information-outline</v-icon>
                Results must be entered before the report can be signed off.
              </p>
              <p v-else-if="!isOrderCompleted && !verifiedSigner" class="lo-auth-hint">
                <v-icon size="12">mdi-progress-clock</v-icon>
                Complete the order before the report can be verified.
              </p>
            </div>
          </section>

          <!-- Patient -->
          <section class="lo-panel">
            <div class="lo-panel-body">
              <div class="lo-patient">
                <span class="lo-avatar">{{ initials(order.patient_name) }}</span>
                <div class="lo-patient-id">
                  <b>{{ order.patient_name }}</b>
                  <span>Patient #{{ order.patient }}</span>
                </div>
              </div>
              <div class="lo-patient-actions">
                <NuxtLink class="lo-btn is-sm" :to="`/clinics/patients/${order.patient}`">
                  <v-icon size="14">mdi-account-outline</v-icon>
                  <span>Open profile</span>
                </NuxtLink>
                <NuxtLink v-if="order.consultation" class="lo-btn is-sm"
                  :to="`/clinics/consultations/${order.consultation}`">
                  <v-icon size="14">mdi-stethoscope</v-icon>
                  <span>Consultation</span>
                </NuxtLink>
              </div>
            </div>
          </section>

          <!-- Order information -->
          <section class="lo-panel">
            <header class="lo-panel-head">
              <span class="lo-panel-ico is-slate"><v-icon size="15">mdi-information-outline</v-icon></span>
              <h2>Order information</h2>
            </header>
            <div class="lo-panel-body">
              <div class="lo-dl">
                <div><span>Ordered by</span><b>{{ order.ordered_by_name || '—' }}</b></div>
                <div><span>Created</span><b>{{ fmtDateTime(order.created_at) }}</b></div>
                <div><span>Last update</span><b>{{ fmtDateTime(order.updated_at) }}</b></div>
                <div><span>Collection</span><b>{{ order.is_home_collection ? 'Home collection' : 'In-house' }}</b></div>
                <div><span>Branch</span><b>{{ order.clinic_site_name || 'Head office' }}</b></div>
                <div v-if="order.recurrence_frequency_days">
                  <span>Recurrence</span><b>Every {{ order.recurrence_frequency_days }} days</b>
                </div>
                <div v-if="order.next_collection_date">
                  <span>Next collection</span><b>{{ fmtDate(order.next_collection_date) }}</b>
                </div>
              </div>
            </div>
          </section>

          <!-- Specimens -->
          <section class="lo-panel">
            <header class="lo-panel-head">
              <span class="lo-panel-ico is-info"><v-icon size="15">mdi-test-tube-empty</v-icon></span>
              <h2>Specimens</h2>
              <span class="lo-panel-count">{{ specimens.length }}</span>
            </header>
            <div class="lo-panel-body">
              <div v-if="!specimens.length" class="lo-empty is-tight">
                <v-icon size="26">mdi-test-tube-empty</v-icon>
                <b>No specimens logged</b>
                <span>Accession numbers appear once a sample is collected.</span>
              </div>
              <div v-for="specimen in specimens" :key="specimen.id" class="lo-mini-card">
                <div class="lo-mini-top">
                  <b class="lo-mono">{{ specimen.accession_number }}</b>
                  <span class="lo-pill" :class="specimenTone(specimen.status)">{{ specimen.status }}</span>
                </div>
                <div class="lo-mini-meta">
                  <span><v-icon size="12">mdi-droplet-outline</v-icon>{{ specimen.specimen_type || '—' }}</span>
                  <span v-if="specimen.container_type">
                    <v-icon size="12">mdi-cup-outline</v-icon>{{ specimen.container_type }}
                  </span>
                  <span v-if="specimen.volume_ml">
                    <v-icon size="12">mdi-water-outline</v-icon>{{ specimen.volume_ml }} ml
                  </span>
                </div>
                <div v-if="specimen.collected_at" class="lo-mini-foot">
                  <v-icon size="12">mdi-clock-outline</v-icon>
                  Collected {{ fmtDateTime(specimen.collected_at) }}
                </div>
                <div v-if="specimen.rejection_reason" class="lo-mini-alert">
                  Rejected: {{ specimen.rejection_reason }}
                </div>
              </div>
            </div>
          </section>

          <!-- Home visits -->
          <section v-if="homeVisits.length" class="lo-panel">
            <header class="lo-panel-head">
              <span class="lo-panel-ico is-purple"><v-icon size="15">mdi-home-clock</v-icon></span>
              <h2>Home visits</h2>
              <span class="lo-panel-count">{{ homeVisits.length }}</span>
            </header>
            <div class="lo-panel-body">
              <div v-for="visit in homeVisits" :key="visit.id" class="lo-mini-card">
                <div class="lo-mini-top">
                  <b>{{ fmtDate(visit.scheduled_date) }} · {{ shortTime(visit.scheduled_time) }}</b>
                  <span class="lo-pill" :class="specimenTone(visit.status)">{{ visit.status }}</span>
                </div>
                <div class="lo-mini-meta">
                  <span>
                    <v-icon size="12">mdi-account-outline</v-icon>{{ visit.assigned_lab_tech_name || 'Unassigned' }}
                  </span>
                </div>
                <div class="lo-mini-foot">
                  <v-icon size="12">mdi-map-marker-outline</v-icon>
                  {{ visit.address_place_name || visit.patient_address || '—' }}
                </div>
              </div>
            </div>
          </section>

          <!-- Invoice -->
          <section v-if="invoice" class="lo-panel">
            <header class="lo-panel-head">
              <span class="lo-panel-ico is-good"><v-icon size="15">mdi-receipt-text-outline</v-icon></span>
              <h2>Invoice</h2>
              <span class="lo-pill" :class="invoiceTone">{{ invoice.status }}</span>
            </header>
            <div class="lo-panel-body">
              <div class="lo-invoice-id">
                <b class="lo-mono">{{ invoice.invoice_number }}</b>
                <span v-if="invoice.payer_type" class="lo-pill is-muted">{{ invoice.payer_type }}</span>
              </div>

              <div class="lo-invoice-rows">
                <div><span>Subtotal</span><b>{{ money(invoice.subtotal) }}</b></div>
                <div v-if="Number(invoice.discount)">
                  <span>Discount</span><b class="is-bad">-{{ money(invoice.discount) }}</b>
                </div>
                <div v-if="Number(invoice.tax)"><span>Tax</span><b>{{ money(invoice.tax) }}</b></div>
              </div>

              <div class="lo-invoice-total">
                <span>Total</span>
                <b>{{ money(invoice.total) }}</b>
              </div>

              <div class="lo-invoice-bar"><i :style="{ width: paidPct + '%' }"></i></div>

              <div class="lo-invoice-rows">
                <div><span>Paid</span><b class="is-good">{{ money(invoice.amount_paid) }}</b></div>
                <div>
                  <span>Balance</span>
                  <b :class="Number(invoice.balance) > 0 ? 'is-bad' : 'is-good'">{{ money(invoice.balance) }}</b>
                </div>
              </div>
            </div>
          </section>
        </v-col>
      </v-row>

      <!-- ═══════════════ Result dialog ═══════════════ -->
      <v-dialog v-model="resultDialog" max-width="1000" persistent>
        <v-card rounded="xl" class="lo-dlg" :style="themeVars">
          <BrandDialogHeader
            icon="mdi-flask-plus-outline"
            :title="amendResult ? 'Amend laboratory result' : 'Enter laboratory result'"
            :subtitle="dialogSubtitle"
            @close="closeResultDialog"
          >
            <template #actions>
              <span class="lo-pill is-accent">{{ resultedCount }}/{{ testsTotal }} resulted</span>
            </template>
          </BrandDialogHeader>

          <v-card-text class="lo-dlg-body">
            <div class="lo-dlg-grid">
              <!-- left: test context -->
              <div class="lo-dlg-col">
                <div class="lo-field">
                  <label>Test</label>
                  <v-select
                    v-model="resultForm.test"
                    :items="testOptions"
                    item-title="label"
                    item-value="id"
                    placeholder="Select a test on this order"
                    variant="outlined"
                    density="comfortable"
                    hide-details="auto"
                    @update:model-value="onTestChange"
                  />
                </div>

                <div v-if="selectedTest" class="lo-dlg-meta">
                  <div><span>Code</span><b class="lo-mono">{{ selectedTest.code || '—' }}</b></div>
                  <div><span>Department</span><b>{{ selectedTest.department || '—' }}</b></div>
                  <div><span>Specimen</span><b>{{ selectedTest.specimen_type || '—' }}</b></div>
                  <div><span>Turnaround</span><b>{{ selectedTest.turnaround_time || '—' }}</b></div>
                </div>

                <div v-if="rangeEntries(selectedTest).length" class="lo-ref">
                  <div class="lo-ref-head">Reference ranges</div>
                  <div v-for="[key, value] in rangeEntries(selectedTest)" :key="key" class="lo-ref-row">
                    <span>{{ key }}</span>
                    <b>{{ value }}</b>
                  </div>
                </div>

                <p v-if="selectedTest?.instructions" class="lo-hint">
                  <v-icon size="13">mdi-information-outline</v-icon>
                  {{ selectedTest.instructions }}
                </p>

                <div v-if="amendResult" class="lo-amend-note">
                  <v-icon size="14">mdi-history</v-icon>
                  <span>A result already exists for this test. Saving amends it and records an audit entry.</span>
                </div>
              </div>

              <!-- right: capture -->
              <div class="lo-dlg-col">
                <div v-if="analytes.length" class="lo-mode">
                  <button type="button" :class="{ 'is-on': entryMode === 'panel' }" @click="entryMode = 'panel'">
                    Panel · {{ analytes.length }} analytes
                  </button>
                  <button type="button" :class="{ 'is-on': entryMode === 'single' }" @click="entryMode = 'single'">
                    Single value
                  </button>
                </div>

                <template v-if="entryMode === 'panel' && analytes.length">
                  <div class="lo-analyte-list">
                    <div v-for="analyte in analytes" :key="analyte.name" class="lo-analyte">
                      <div class="lo-analyte-top">
                        <span class="lo-analyte-name">{{ analyte.name }}</span>
                        <span class="lo-analyte-range">{{ analyte.range }}</span>
                      </div>
                      <div class="lo-analyte-input">
                        <input v-model="analyte.value" type="text" inputmode="decimal" :placeholder="analyte.range" />
                        <span class="lo-analyte-unit">{{ analyte.unit || 'no unit' }}</span>
                        <span v-if="analyteVerdict(analyte)" class="lo-pill" :class="`is-${analyteVerdict(analyte).tone}`">
                          {{ analyteVerdict(analyte).label }}
                        </span>
                      </div>
                    </div>
                  </div>
                </template>

                <template v-else>
                  <div class="lo-field">
                    <label>Result value</label>
                    <v-text-field
                      v-model="resultForm.result_value"
                      placeholder="e.g. 12.5"
                      variant="outlined"
                      density="comfortable"
                      hide-details="auto"
                    />
                  </div>
                  <div class="lo-field">
                    <label>Unit</label>
                    <v-text-field
                      v-model="resultForm.unit"
                      placeholder="e.g. g/dL"
                      variant="outlined"
                      density="comfortable"
                      hide-details="auto"
                    />
                  </div>
                  <div v-if="singleVerdict" class="lo-verdict" :class="`is-${singleVerdict.tone}`">
                    <v-icon size="14">{{ singleVerdict.icon }}</v-icon>
                    {{ singleVerdict.label }}<template v-if="singleRange"> · reference {{ singleRange.text }}</template>
                  </div>
                </template>

                <div class="lo-field">
                  <label>Interpretation</label>
                  <div class="lo-flagseg">
                    <button type="button" :class="{ 'is-on': flagMode === 'auto' }" @click="flagMode = 'auto'">
                      Auto<em>{{ derivedAbnormal ? 'abnormal' : 'normal' }}</em>
                    </button>
                    <button type="button" :class="{ 'is-on': flagMode === 'normal' }" @click="flagMode = 'normal'">
                      Normal
                    </button>
                    <button type="button" :class="{ 'is-on': flagMode === 'abnormal' }" @click="flagMode = 'abnormal'">
                      Abnormal
                    </button>
                  </div>
                </div>

                <div class="lo-field">
                  <label>Comments</label>
                  <v-textarea
                    v-model="resultForm.comments"
                    placeholder="Method, analyser, dilution factor, remarks…"
                    variant="outlined"
                    density="comfortable"
                    hide-details="auto"
                    rows="3"
                    auto-grow
                  />
                </div>

                <!-- Optional scanned report / analyser printout -->
                <div class="lo-field">
                  <label>
                    Scanned report
                    <em class="lo-opt">optional</em>
                  </label>

                  <!-- nothing attached yet -->
                  <div
                    v-if="!attachmentFile && !keptAttachment"
                    class="lo-drop"
                    :class="{ 'is-over': dragOver }"
                    role="button"
                    tabindex="0"
                    @click="pickAttachment"
                    @keydown.enter.prevent="pickAttachment"
                    @keydown.space.prevent="pickAttachment"
                    @dragover.prevent="dragOver = true"
                    @dragenter.prevent="dragOver = true"
                    @dragleave.prevent="dragOver = false"
                    @drop.prevent="onDrop"
                  >
                    <span class="lo-drop-ico"><v-icon size="19">mdi-cloud-upload-outline</v-icon></span>
                    <b>Drop a PDF or image</b>
                    <span>or click to browse · PDF, JPG, PNG, WEBP, TIFF · max 15 MB</span>
                  </div>

                  <!-- attached (either newly picked or already stored) -->
                  <div v-else class="lo-attach" :class="`is-${attachmentKind}`">
                    <button
                      v-if="attachmentKind === 'image' && attachmentSrc"
                      type="button"
                      class="lo-attach-thumb"
                      title="Preview image"
                      @click="previewOpen = true"
                    >
                      <img :src="attachmentSrc" alt="Attached scan preview" />
                    </button>
                    <span v-else class="lo-attach-ico">
                      <v-icon size="19">{{ attachmentKind === 'pdf' ? 'mdi-file-pdf-box' : 'mdi-file-image-outline' }}</v-icon>
                    </span>

                    <span class="lo-attach-meta">
                      <b :title="attachmentName">{{ attachmentName }}</b>
                      <span>
                        {{ attachmentKind === 'pdf' ? 'PDF document' : attachmentKind === 'image' ? 'Image' : 'File' }}
                        <template v-if="attachmentSize"> · {{ humanSize(attachmentSize) }}</template>
                        <template v-if="!attachmentFile"> · already attached</template>
                      </span>
                    </span>

                    <span class="lo-attach-acts">
                      <button v-if="attachmentSrc" type="button" class="lo-link" @click="openAttachment">
                        Open
                      </button>
                      <button type="button" class="lo-link" @click="pickAttachment">Replace</button>
                      <button type="button" class="lo-link is-quiet" @click="clearAttachment">Remove</button>
                    </span>
                  </div>

                  <input
                    ref="fileInputRef"
                    type="file"
                    class="lo-file-hidden"
                    accept="application/pdf,image/jpeg,image/png,image/webp,image/tiff,image/heic"
                    @change="onPick"
                  />

                  <p v-if="attachmentError" class="lo-field-err">
                    <v-icon size="13">mdi-alert-circle-outline</v-icon>
                    {{ attachmentError }}
                  </p>
                </div>

                <div class="lo-preview">
                  <span>Result preview</span>
                  <code>{{ previewValue || '—' }}</code>
                </div>
              </div>
            </div>
          </v-card-text>

          <v-card-actions class="lo-dlg-actions">
            <span class="lo-dlg-queue">
              <v-icon size="13">mdi-playlist-check</v-icon>
              {{ pendingTests.length }} test{{ pendingTests.length === 1 ? '' : 's' }} still awaiting a result
            </span>
            <v-spacer />
            <button type="button" class="lo-btn" @click="closeResultDialog">Cancel</button>
            <button v-if="pendingTests.length > 1" type="button" class="lo-btn"
              :disabled="savingResult || !canSaveResult" @click="saveResult(true)">
              Save and next
            </button>
            <button type="button" class="lo-btn is-primary" :disabled="savingResult || !canSaveResult"
              @click="saveResult(false)">
              <v-icon size="15">{{ amendResult ? 'mdi-content-save-check' : 'mdi-flask-plus-outline' }}</v-icon>
              <span>{{ savingResult ? 'Saving…' : amendResult ? 'Update result' : 'Save result' }}</span>
            </button>
          </v-card-actions>
        </v-card>
      </v-dialog>

      <!-- toast -->
      <transition name="loToast">
        <div v-if="notice" class="lo-notice" :class="`is-${notice.tone}`">
          <v-icon size="15">{{ notice.tone === 'bad' ? 'mdi-alert-circle-outline' : 'mdi-check-circle-outline' }}</v-icon>
          <span>{{ notice.message }}</span>
        </div>
      </transition>

      <!-- lightbox for the attached scan -->
      <v-dialog v-model="previewOpen" max-width="960">
        <v-card rounded="xl" class="lo-lightbox">
          <div class="lo-lightbox-bar">
            <v-icon size="16">mdi-file-image-outline</v-icon>
            <b>{{ attachmentName }}</b>
            <span v-if="attachmentSize">{{ humanSize(attachmentSize) }}</span>
            <v-spacer />
            <button type="button" class="lo-btn is-sm" @click="openAttachmentRaw">Open in new tab</button>
            <button type="button" class="lo-btn is-sm" @click="previewOpen = false">Close</button>
          </div>
          <div class="lo-lightbox-body">
            <img v-if="attachmentSrc" :src="attachmentSrc" :alt="attachmentName" />
          </div>
        </v-card>
      </v-dialog>

      <!-- bench sign-off: name + password + handwritten signature -->
      <AuthorizationDialog
        v-model="authDialog.open"
        :order-id="orderId"
        :role="authDialog.role"
        :order="order"
        :existing="authDialog.role === 'verified' ? verifiedSigner : performedSigner"
        @signed="onSigned"
      />

      <!-- blocking-action explainer (performer required / report unverified) -->
      <InfoDialog
        v-model="infoDialog.open"
        :tone="infoDialog.tone"
        :title="infoDialog.title"
        :subtitle="infoDialog.subtitle"
        :message="infoDialog.message"
        :points="infoDialog.points"
        :hint="infoDialog.hint"
        :confirm-label="infoDialog.confirm"
        :secondary-label="secondaryLabel"
        @secondary="onInfoSecondary"
      />
    </template>

    <div v-else class="lo-loading">
      <v-progress-circular indeterminate color="primary" size="42" width="3" />
      <span>Loading laboratory order…</span>
    </div>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const route = useRoute()
const brand = useBranding()

const orderId = route.params.id

const order = ref(null)
const orderExtra = ref(null)
const orderedTests = ref([])
const results = ref([])
const specimens = ref([])
const homeVisits = ref([])
const invoice = ref(null)

const loading = ref(false)
const busy = ref(false)
const loadedAt = ref(null)

const resultFilter = ref('all')
const resultDialog = ref(false)
const savingResult = ref(false)
const entryMode = ref('single')
const analytes = ref([])
const flagMode = ref('auto')
const resultForm = reactive({ test: null, result_value: '', unit: '', comments: '' })

// Optional scanned report attached to the result.
const fileInputRef = ref(null)
const attachmentFile = ref(null)
const attachmentObjectUrl = ref('')
const attachmentRemoved = ref(false)
const attachmentError = ref('')
const dragOver = ref(false)
const previewOpen = ref(false)

const MAX_ATTACHMENT_BYTES = 15 * 1024 * 1024
const ATTACHMENT_MIMES = [
  'application/pdf',
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
  'image/tiff',
  'image/heic',
]

const notice = ref(null)
let noticeTimer = null

const themeVars = computed(() => ({
  '--lo-accent': brand.primary.value,
  '--lo-on-accent': brand.onPrimary.value,
  '--lo-accent-ink': brand.ink.value,
  '--lo-accent-soft': brand.tint('primary', 0.18),
  '--lo-accent-ring': brand.tint('primary', 0.24),
}))

/* ── Workflow ─────────────────────────────────────────────────────────── */
const FLOW = [
  { value: 'pending', label: 'Ordered', hint: 'Awaiting collection', icon: 'mdi-clipboard-text-outline' },
  { value: 'sample_collected', label: 'Collected', hint: 'Sample in hand', icon: 'mdi-test-tube' },
  { value: 'processing', label: 'Processing', hint: 'On the analyser', icon: 'mdi-progress-clock' },
  { value: 'completed', label: 'Completed', hint: 'Results authorised', icon: 'mdi-check-circle-outline' },
]

const STATUS = {
  pending: { label: 'Pending', tone: 'warn', icon: 'mdi-clock-outline' },
  sample_collected: { label: 'Sample collected', tone: 'info', icon: 'mdi-test-tube' },
  processing: { label: 'Processing', tone: 'accent', icon: 'mdi-progress-clock' },
  completed: { label: 'Completed', tone: 'good', icon: 'mdi-check-circle' },
  cancelled: { label: 'Cancelled', tone: 'bad', icon: 'mdi-cancel' },
}

function statusMeta(status) {
  return STATUS[status] || { label: status || 'Unknown', tone: 'muted', icon: 'mdi-help-circle-outline' }
}

function stepState(index) {
  const current = FLOW.findIndex((step) => step.value === order.value?.status)
  if (current < 0) return 'todo'
  if (index < current) return 'done'
  if (index === current) return 'current'
  return 'todo'
}

const progressPct = computed(() => {
  const current = FLOW.findIndex((step) => step.value === order.value?.status)
  if (current < 0) return 0
  return Math.round(((current + 1) / FLOW.length) * 100)
})

/* ── Permissions ──────────────────────────────────────────────────────── */
const canEdit = computed(() => !!order.value && !['completed', 'cancelled'].includes(order.value.status))
const canEnterResults = computed(
  () => !!order.value && ['sample_collected', 'processing'].includes(order.value.status),
)
const canCancel = computed(
  () => !!order.value && ['pending', 'sample_collected', 'processing'].includes(order.value.status),
)

/* ── Totals ───────────────────────────────────────────────────────────── */
const testsTotal = computed(() => orderedTests.value.length)

function resultsFor(testId) {
  return results.value
    .filter((result) => result.test === testId)
    .slice()
    .sort((a, b) => new Date(b.result_date || 0) - new Date(a.result_date || 0))
}

function hasAbnormal(testId) {
  return resultsFor(testId).some((result) => result.is_abnormal)
}

const resultedCount = computed(() => orderedTests.value.filter((test) => resultsFor(test.id).length).length)
const pendingTests = computed(() => orderedTests.value.filter((test) => !resultsFor(test.id).length))
const allResultsIn = computed(() => testsTotal.value > 0 && pendingTests.value.length === 0)
const abnormalCount = computed(() => results.value.filter((result) => result.is_abnormal).length)
const verifiedCount = computed(() => results.value.filter((result) => result.verified_by).length)

const orderValue = computed(() =>
  orderedTests.value.reduce((sum, test) => sum + (Number.parseFloat(test.price) || 0), 0),
)

const hasReferringDetails = computed(() => {
  const extra = orderExtra.value
  if (!extra) return false
  return Boolean(extra.referring_doctor_name || extra.referring_facility_name || extra.accession_number)
})

function parseTat(text) {
  const match = String(text || '').match(/(\d+(?:\.\d+)?)\s*(minute|hour|day|week)/i)
  if (!match) return null
  const amount = Number.parseFloat(match[1])
  const unit = match[2].toLowerCase()
  if (unit.startsWith('minute')) return amount
  if (unit.startsWith('hour')) return amount * 60
  if (unit.startsWith('day')) return amount * 1440
  return amount * 10080
}

function fmtTat(minutes) {
  if (!minutes) return '—'
  if (minutes < 60) return `${Math.round(minutes)} min`
  if (minutes < 1440) {
    const hours = minutes / 60
    return `${Number.isInteger(hours) ? hours : hours.toFixed(1)} hrs`
  }
  const days = minutes / 1440
  return `${Number.isInteger(days) ? days : days.toFixed(1)} days`
}

const expectedTat = computed(() => {
  const durations = orderedTests.value.map((test) => parseTat(test.turnaround_time)).filter((value) => value != null)
  if (!durations.length) return '—'
  return fmtTat(Math.max(...durations))
})

const paidPct = computed(() => {
  const total = Number(invoice.value?.total || 0)
  const paid = Number(invoice.value?.amount_paid || 0)
  if (!total) return paid > 0 ? 100 : 0
  return Math.max(0, Math.min(100, Math.round((paid / total) * 100)))
})

const invoiceTone = computed(() => {
  const status = invoice.value?.status
  if (status === 'paid') return 'is-good'
  if (status === 'partial') return 'is-warn'
  if (status === 'void') return 'is-muted'
  return 'is-info'
})

/* ── Filters ──────────────────────────────────────────────────────────── */
const resultFilters = computed(() => [
  { value: 'all', label: 'All', count: testsTotal.value },
  { value: 'pending', label: 'Pending', count: pendingTests.value.length },
  { value: 'resulted', label: 'Resulted', count: resultedCount.value },
  { value: 'abnormal', label: 'Abnormal', count: orderedTests.value.filter((test) => hasAbnormal(test.id)).length },
])

const filteredTests = computed(() => {
  const list = orderedTests.value
  if (resultFilter.value === 'pending') return list.filter((test) => !resultsFor(test.id).length)
  if (resultFilter.value === 'resulted') return list.filter((test) => resultsFor(test.id).length)
  if (resultFilter.value === 'abnormal') return list.filter((test) => hasAbnormal(test.id))
  return list
})

function testTone(test) {
  if (hasAbnormal(test.id)) return 'is-bad'
  if (resultsFor(test.id).length) return 'is-good'
  return 'is-muted'
}

function testToneLabel(test) {
  if (hasAbnormal(test.id)) return 'Flagged'
  if (resultsFor(test.id).length) return 'Resulted'
  return 'Awaiting result'
}

function testToneIcon(test) {
  if (hasAbnormal(test.id)) return 'mdi-alert'
  if (resultsFor(test.id).length) return 'mdi-check'
  return 'mdi-clock-outline'
}

/* ── Formatting ───────────────────────────────────────────────────────── */
function fmtDate(value) {
  if (!value) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '—'
  return date.toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' })
}

function fmtDateTime(value) {
  if (!value) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '—'
  return date.toLocaleString(undefined, {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

function shortTime(value) {
  if (!value) return '—'
  return String(value).slice(0, 5)
}

function money(value) {
  if (value == null || value === '') return '—'
  const number = Number(value)
  if (Number.isNaN(number)) return '—'
  return `KSh ${number.toLocaleString(undefined, { maximumFractionDigits: 2 })}`
}

function relativeTime(value) {
  if (!value) return '—'
  const stamp = new Date(value).getTime()
  if (Number.isNaN(stamp)) return '—'
  const diff = Date.now() - stamp
  const minutes = Math.round(Math.abs(diff) / 60000)
  if (minutes < 1) return diff >= 0 ? 'just now' : 'moments'
  if (minutes < 60) return diff >= 0 ? `${minutes}m ago` : `in ${minutes}m`
  const hours = Math.round(minutes / 60)
  if (hours < 24) return diff >= 0 ? `${hours}h ago` : `in ${hours}h`
  const days = Math.round(hours / 24)
  if (days < 30) return diff >= 0 ? `${days}d ago` : `in ${days}d`
  return fmtDate(value)
}

const updatedLabel = computed(() => {
  if (!loadedAt.value) return '—'
  return `updated ${relativeTime(loadedAt.value)}`
})

function priorityLabel(value) {
  return { routine: 'Routine', urgent: 'Urgent', stat: 'STAT' }[value] || value || 'Routine'
}

function priorityTone(value) {
  if (value === 'stat') return 'is-bad'
  if (value === 'urgent') return 'is-warn'
  return 'is-muted'
}

function priorityIcon(value) {
  if (value === 'stat') return 'mdi-alert-circle'
  if (value === 'urgent') return 'mdi-alert'
  return 'mdi-clock-outline'
}

function specimenTone(status) {
  const map = {
    received: 'is-good',
    collected: 'is-info',
    processing: 'is-accent',
    rejected: 'is-bad',
    completed: 'is-good',
    confirmed: 'is-info',
    in_progress: 'is-accent',
    scheduled: 'is-muted',
    cancelled: 'is-bad',
    no_show: 'is-bad',
  }
  return map[status] || 'is-muted'
}

function initials(name) {
  return String(name || '?')
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((word) => word[0].toUpperCase())
    .join('')
}

const headSub = computed(() => {
  const current = order.value
  if (!current) return ''
  const count = `${testsTotal.value} test${testsTotal.value === 1 ? '' : 's'}`
  return `${current.patient_name} · ${count} · ordered ${fmtDateTime(current.created_at)}`
})

/* ── Reference ranges ─────────────────────────────────────────────────── */
const NON_ANALYTE = /^(normal|abnormal|male|female|adult|child|children|newborn|infant|pre-?diabetic|diabetic|non-?diabetic|undetectable|detectable|non-?pregnant|pregnant|deficient|insufficient|sufficient|optimal|borderline|high|low|critical|sepsis(_likely)?|morning|evening|fasting|random|negative|positive|impaired|baseline|impaired_?2hr|normal_?2hr)$/i

function rangeEntries(test) {
  return Object.entries(test?.reference_ranges || {})
}

function rangeCount(test) {
  return rangeEntries(test).length
}

function parseRange(text) {
  const raw = String(text ?? '').trim()
  if (!raw) return null
  let match = raw.match(/^(-?\d+(?:\.\d+)?)\s*(?:-|–|to)\s*(-?\d+(?:\.\d+)?)\s*(.*)$/i)
  if (match) {
    return { low: Number.parseFloat(match[1]), high: Number.parseFloat(match[2]), unit: match[3].trim() }
  }
  match = raw.match(/^(<=|>=|<|>)\s*(-?\d+(?:\.\d+)?)\s*(.*)$/)
  if (match) {
    const operator = match[1]
    const bound = Number.parseFloat(match[2])
    const unit = match[3].trim()
    if (operator === '<' || operator === '<=') return { low: null, high: bound, unit }
    return { low: bound, high: null, unit }
  }
  return null
}

function verdictFor(raw, range) {
  if (!range) return null
  const number = Number.parseFloat(String(raw).replace(/[^0-9.-]/g, ''))
  if (Number.isNaN(number)) return null
  if (range.low != null && number < range.low) {
    return { tone: 'bad', label: 'Below range', icon: 'mdi-arrow-down-bold' }
  }
  if (range.high != null && number > range.high) {
    return { tone: 'bad', label: 'Above range', icon: 'mdi-arrow-up-bold' }
  }
  if (range.low == null && range.high == null) return null
  return { tone: 'good', label: 'Within range', icon: 'mdi-check' }
}

function buildAnalytes(test) {
  const ranges = test?.reference_ranges || {}
  const keys = Object.keys(ranges)
  if (keys.length < 2 || !keys.every((key) => !NON_ANALYTE.test(key.trim()))) return []
  return keys.map((key) => {
    const parsed = parseRange(ranges[key]) || {}
    return {
      name: key,
      range: ranges[key],
      unit: parsed.unit || '',
      low: parsed.low ?? null,
      high: parsed.high ?? null,
      value: '',
    }
  })
}

function analyteVerdict(row) {
  if (!row || !row.value || String(row.value).trim() === '') return null
  return verdictFor(row.value, { low: row.low, high: row.high })
}

/* ── Dialog state ─────────────────────────────────────────────────────── */
const selectedTest = computed(() => orderedTests.value.find((test) => test.id === resultForm.test) || null)

const existingResult = computed(() => results.value.find((result) => result.test === resultForm.test) || null)
const amendResult = computed(() => Boolean(existingResult.value))

/* ── Attachment state ─────────────────────────────────────────────────── */
const keptAttachment = computed(() => {
  if (attachmentFile.value || attachmentRemoved.value) return null
  return existingResult.value?.attachment ? existingResult.value : null
})

const attachmentKind = computed(() => {
  if (attachmentFile.value) {
    const mime = attachmentFile.value.type || ''
    if (mime === 'application/pdf') return 'pdf'
    if (mime.startsWith('image/')) return 'image'
    return 'file'
  }
  return keptAttachment.value?.attachment_kind || 'file'
})

const attachmentName = computed(() => {
  if (attachmentFile.value) return attachmentFile.value.name
  return keptAttachment.value?.attachment_name || 'Attached report'
})

const attachmentSize = computed(() => {
  if (attachmentFile.value) return attachmentFile.value.size || 0
  return keptAttachment.value?.attachment_size || 0
})

const attachmentSrc = computed(() => {
  if (attachmentObjectUrl.value) return attachmentObjectUrl.value
  return keptAttachment.value?.attachment || ''
})

const dialogSubtitle = computed(() => {
  if (!selectedTest.value) return 'Choose a test on this order to record its result'
  const parts = [selectedTest.value.name]
  if (selectedTest.value.code) parts.push(selectedTest.value.code)
  if (order.value?.patient_name) parts.push(order.value.patient_name)
  return parts.join(' · ')
})

const testOptions = computed(() =>
  orderedTests.value.map((test) => ({
    id: test.id,
    label: `${test.name}${test.code ? ` · ${test.code}` : ''}${resultsFor(test.id).length ? '  (resulted)' : ''}`,
  })),
)

const singleRange = computed(() => {
  const ranges = selectedTest.value?.reference_ranges || {}
  const keys = Object.keys(ranges)
  if (!keys.length) return null
  const preferred = keys.find((key) => /^normal$/i.test(key)) ?? keys[0]
  return { key: preferred, text: ranges[preferred], parsed: parseRange(ranges[preferred]) }
})

const singleVerdict = computed(() => {
  if (entryMode.value === 'panel' && analytes.value.length) return null
  if (!singleRange.value || !resultForm.result_value) return null
  return verdictFor(resultForm.result_value, singleRange.value.parsed)
})

const derivedAbnormal = computed(() => {
  if (entryMode.value === 'panel' && analytes.value.length) {
    return analytes.value.some((row) => (analyteVerdict(row) || {}).tone === 'bad')
  }
  return (singleVerdict.value || {}).tone === 'bad'
})

const composedValue = computed(() => {
  if (entryMode.value === 'panel' && analytes.value.length) {
    return analytes.value
      .filter((row) => String(row.value ?? '').trim() !== '')
      .map((row) => `${row.name}: ${String(row.value).trim()}${row.unit ? ` ${row.unit}` : ''}`)
      .join(' · ')
  }
  return String(resultForm.result_value ?? '').trim()
})

const previewValue = computed(() => {
  if (entryMode.value === 'panel' && analytes.value.length) return composedValue.value
  const value = composedValue.value
  if (!value) return ''
  return `${value}${resultForm.unit ? ` ${resultForm.unit}` : ''}`
})

const canSaveResult = computed(() => Boolean(resultForm.test) && composedValue.value !== '')

function resetCapture() {
  resultForm.result_value = ''
  resultForm.unit = ''
  resultForm.comments = ''
  flagMode.value = 'auto'
  analytes.value = []
  entryMode.value = 'single'
  clearAttachmentState()
}

/* ── Attachment helpers ───────────────────────────────────────────────── */
function releaseObjectUrl() {
  if (attachmentObjectUrl.value && import.meta.client) {
    URL.revokeObjectURL(attachmentObjectUrl.value)
  }
  attachmentObjectUrl.value = ''
}

function clearAttachmentState() {
  releaseObjectUrl()
  attachmentFile.value = null
  attachmentRemoved.value = false
  attachmentError.value = ''
  dragOver.value = false
  if (fileInputRef.value) fileInputRef.value.value = ''
}

function pickAttachment() {
  fileInputRef.value?.click()
}

function acceptAttachment(file) {
  if (!file) return
  attachmentError.value = ''

  const mime = (file.type || '').toLowerCase()
  const name = (file.name || '').toLowerCase()
  const looksPdf = mime === 'application/pdf' || name.endsWith('.pdf')
  const looksImage = mime.startsWith('image/') || /\.(jpe?g|png|webp|tiff?|heic)$/.test(name)

  if (!looksPdf && !looksImage) {
    attachmentError.value = 'Upload a PDF or an image (JPG, PNG, WEBP, TIFF, HEIC).'
    return
  }
  if (mime && !ATTACHMENT_MIMES.includes(mime) && !looksPdf && !looksImage) {
    attachmentError.value = 'That file type is not supported.'
    return
  }
  if (file.size > MAX_ATTACHMENT_BYTES) {
    attachmentError.value = 'File is larger than 15 MB.'
    return
  }

  releaseObjectUrl()
  attachmentFile.value = file
  attachmentRemoved.value = false
  // Keep an object URL for both kinds so the preview / open action works
  // before the file has been uploaded.
  attachmentObjectUrl.value = URL.createObjectURL(file)
}

function onPick(event) {
  acceptAttachment(event.target.files?.[0])
  event.target.value = ''
}

function onDrop(event) {
  dragOver.value = false
  acceptAttachment(event.dataTransfer?.files?.[0])
}

function clearAttachment() {
  const hadStored = Boolean(existingResult.value?.attachment)
  clearAttachmentState()
  // Only flag for deletion when there is actually a stored file to drop.
  attachmentRemoved.value = hadStored
}

function openAttachment() {
  const src = attachmentSrc.value
  if (!src || !import.meta.client) return
  if (attachmentKind.value === 'image') {
    previewOpen.value = true
    return
  }
  window.open(src, '_blank', 'noopener')
}

function openAttachmentRaw() {
  const src = attachmentSrc.value
  if (src && import.meta.client) window.open(src, '_blank', 'noopener')
}

function humanSize(bytes) {
  const value = Number(bytes) || 0
  if (!value) return ''
  if (value < 1024) return `${value} B`
  if (value < 1024 * 1024) return `${(value / 1024).toFixed(0)} KB`
  return `${(value / (1024 * 1024)).toFixed(1)} MB`
}

function hydrateFromResult(result) {
  if (!result) return
  resultForm.comments = result.comments || ''
  const value = String(result.result_value || '')
  if (entryMode.value === 'panel' && analytes.value.length) {
    const parts = value.split(/\s*[·|;]\s*/)
    let matched = 0
    parts.forEach((part) => {
      const split = part.match(/^(.+?):\s*(.+)$/)
      if (!split) return
      const row = analytes.value.find((analyte) => analyte.name.toLowerCase() === split[1].trim().toLowerCase())
      if (!row) return
      let rest = split[2].trim()
      if (row.unit && rest.toLowerCase().endsWith(row.unit.toLowerCase())) {
        rest = rest.slice(0, rest.length - row.unit.length).trim()
      }
      row.value = rest
      matched += 1
    })
    if (matched) return
  }
  entryMode.value = 'single'
  resultForm.result_value = value
  resultForm.unit = result.unit || resultForm.unit
}

function applyTest(testId) {
  resetCapture()
  const test = orderedTests.value.find((item) => item.id === testId) || null
  if (!test) return
  const rows = buildAnalytes(test)
  if (rows.length) {
    analytes.value = rows
    entryMode.value = 'panel'
  } else {
    resultForm.unit = singleRange.value?.parsed?.unit || ''
  }
  const existing = results.value.find((result) => result.test === testId)
  if (existing) hydrateFromResult(existing)
}

function onTestChange(testId) {
  applyTest(testId)
}

function openResult(test = null) {
  const target = test || pendingTests.value[0] || orderedTests.value[0] || null
  resultForm.test = target?.id ?? null
  applyTest(target?.id ?? null)
  resultDialog.value = true
}

function closeResultDialog() {
  resultDialog.value = false
  resetCapture()
  resultForm.test = null
}

function savePayload() {
  let abnormal = derivedAbnormal.value
  if (flagMode.value === 'abnormal') abnormal = true
  if (flagMode.value === 'normal') abnormal = false
  return {
    result_value: composedValue.value,
    unit: entryMode.value === 'panel' && analytes.value.length ? '' : resultForm.unit || '',
    is_abnormal: abnormal,
    comments: resultForm.comments || '',
  }
}

/**
 * Build the outgoing request body.
 *
 * JSON is used unless a file is involved, because multipart is the only way
 * to ship the optional scan. Removing a stored file has to be a JSON `null`,
 * since an empty multipart part would fail FileField validation.
 */
function buildSaveRequest(extra = {}) {
  const removingAttachment = attachmentRemoved.value && !attachmentFile.value
  const hasNewFile = Boolean(attachmentFile.value)

  if (hasNewFile) {
    const data = new FormData()
    Object.entries({ ...savePayload(), ...extra }).forEach(([key, value]) => {
      if (value === undefined || value === null) return
      if (typeof value === 'boolean') data.append(key, value ? 'true' : 'false')
      else data.append(key, value)
    })
    data.append('attachment', attachmentFile.value, attachmentFile.value.name)
    return { data, multipart: true }
  }

  const data = { ...savePayload(), ...extra }
  if (removingAttachment) data.attachment = null
  return { data, multipart: false }
}

async function saveResult(keepOpen = false) {
  if (!canSaveResult.value) return
  const amending = amendResult.value
  savingResult.value = true
  try {
    const { data, multipart } = buildSaveRequest(
      amending ? {} : { test: resultForm.test },
    )
    const config = multipart ? { headers: { 'Content-Type': 'multipart/form-data' } } : undefined

    if (amending) {
      await $api.patch(`/lab/results/${existingResult.value.id}/`, data, config)
    } else {
      await $api.post(`/lab/orders/${orderId}/add_result/`, data, config)
    }
    await load()

    if (keepOpen) {
      const next = pendingTests.value[0]
      if (next) {
        resultForm.test = next.id
        applyTest(next.id)
        notify(`Saved. Next up: ${next.name}`)
      } else {
        closeResultDialog()
        notify('All results entered — the order is ready to be completed.')
      }
      return
    }

    const finished = pendingTests.value.length === 0
    const verb = amending ? 'Result updated' : 'Result saved'
    closeResultDialog()
    if (amending) notify(`${verb}. An amendment entry was added to the audit trail.`)
    else notify(finished ? `${verb}. Every test now has a result.` : `${verb}.`)
  } catch (error) {
    notify(apiError(error, 'Could not save the result.'), 'bad')
  } finally {
    savingResult.value = false
  }
}

/* ── Bench authorisation ──────────────────────────────────────────────── */
const authDialog = reactive({ open: false, role: 'verified' })

const authorization = computed(() => order.value?.authorization || null)
const performedSigner = computed(() => authorization.value?.performed || null)
const verifiedSigner = computed(() => authorization.value?.verified || null)
const authComplete = computed(
  () => Boolean(performedSigner.value && verifiedSigner.value) || Boolean(authorization.value?.is_complete),
)
/** Nothing can be signed until at least one result exists. */
const authEnabled = computed(() => (order.value?.results?.length || 0) > 0)

const authSlots = computed(() => [
  { role: 'performed', label: 'Performed by', data: performedSigner.value },
  { role: 'verified', label: 'Verified by', data: verifiedSigner.value },
])

/* ── Blocking-action explainer ────────────────────────────────────────── */
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

function onInfoSecondary() {
  if (infoDialog.secondary === 'sign-performed') openAuthDialog('performed')
  else if (infoDialog.secondary === 'sign-verified') openAuthDialog('verified')
  else if (infoDialog.secondary === 'complete-order') updateStatus('completed')
}

const SECONDARY_LABELS = {
  'sign-performed': 'Sign as performer',
  'sign-verified': 'Authorise report',
  'complete-order': 'Complete order',
}
const secondaryLabel = computed(
  () => SECONDARY_LABELS[infoDialog.secondary] || '',
)

/**
 * An order must be completed before its report can be verified — a report on an
 * order that is still being processed is not final.
 */
const isOrderCompleted = computed(() => order.value?.status === 'completed')

function requireCompleted(action = 'verify this report') {
  if (isOrderCompleted.value) return true
  const current = order.value?.status
  showInfo({
    tone: 'warning',
    title: 'Complete the order first',
    subtitle: `Cannot ${action} yet`,
    message: 'Only completed orders can be verified. This order is still in progress, so its report is not final.',
    points: [
      'Enter every result, then mark the order completed.',
      'A performer signs the results on the bench.',
      'Verification and release come after completion.',
    ],
    hint: current === 'processing'
      ? 'Use “Complete order” once every result is in.'
      : 'Advance the order through collection and processing first.',
    confirm: 'Understood',
    // Offer the next step; if the performer has not signed yet, that flow
    // explains itself in the following dialog.
    secondary: authEnabled.value ? 'complete-order' : '',
  })
  return false
}

/**
 * An order cannot be marked completed until a bench technologist has signed as
 * the performer — otherwise the report has results nobody is accountable for.
 */
function requirePerformer(action = 'complete this order') {
  if (performedSigner.value) return true
  showInfo({
    tone: 'warning',
    title: 'Performer sign-off required',
    subtitle: `Cannot ${action} yet`,
    message: 'No laboratory staff member has signed as the performer for this order, so it cannot be closed.',
    points: [
      'Sign as performer to record who ran the assay and when.',
      'The performer’s name and signature are printed on the report.',
      'Verification can only follow a performer sign-off.',
    ],
    hint: 'Use “Sign as performer” in the Authorisation panel to record it.',
    confirm: 'Understood',
    secondary: 'sign-performed',
  })
  return false
}

/** Unverified reports are working drafts — they must not leave the lab. */
function requireVerified(action = 'download this report') {
  if (verifiedSigner.value) return true
  showInfo({
    tone: 'danger',
    title: 'Report not yet verified',
    subtitle: `Cannot ${action}`,
    message: 'This report has not been authorised by a verifier, so it is still a working draft and cannot be released.',
    points: [
      'A verifier must review the results and sign the report.',
      'Downloading or printing is blocked until verification is complete.',
      'The verifier’s name and signature are added to the report automatically.',
    ],
    hint: 'Authorise the report from the Authorisation panel once every result is in.',
    confirm: 'OK',
    secondary: authEnabled.value ? 'sign-verified' : '',
  })
  return false
}

function openAuthDialog(role = 'verified') {
  if (!authEnabled.value) {
    notify('Enter at least one result before signing off.', 'bad')
    return
  }
  // Verification only makes sense once the order is finalised.
  if (role === 'verified' && !requireCompleted('verify this report')) return
  authDialog.role = role
  authDialog.open = true
}

/** Re-read the result rows (their performed/verified stamps follow the sign-off). */
async function refreshResults() {
  try {
    const { data } = await $api.get(`/lab/results/?order=${orderId}&page_size=500`)
    results.value = unwrap(data)
  } catch {
    /* the panel already reflects the change; keep the previous rows */
  }
}

async function onSigned(payload) {
  if (payload?.order) {
    order.value = payload.order
  } else {
    await load()
  }
  await refreshResults()
  notify(payload?.detail || 'Signature recorded.')
}

async function revokeSignoff(role) {
  if (!import.meta.client) return
  const label = role === 'verified' ? 'verification' : 'performer signature'
  if (!window.confirm(`Withdraw the ${label} from this order? This is recorded in the audit trail.`)) {
    return
  }
  busy.value = true
  try {
    const { data } = await $api.post(`/lab/orders/${orderId}/revoke-signoff/`, { role })
    if (data?.order) order.value = data.order
    else await load()
    await refreshResults()
    notify('Signature withdrawn.')
  } catch (error) {
    notify(apiError(error, 'Could not withdraw the signature.'), 'bad')
  } finally {
    busy.value = false
  }
}

/* ── Mutations ────────────────────────────────────────────────────────── */
async function updateStatus(status) {
  // Completing an order requires an accountable performer first.
  if (status === 'completed' && !requirePerformer('mark this order completed')) return
  busy.value = true
  try {
    await $api.patch(`/lab/orders/${orderId}/`, { status })
    await load()
    notify(`Order moved to ${statusMeta(status).label.toLowerCase()}.`)
  } catch (error) {
    notify(apiError(error, 'Could not update the order status.'), 'bad')
  } finally {
    busy.value = false
  }
}

async function cancelOrder() {
  busy.value = true
  try {
    await $api.post(`/lab/orders/${orderId}/cancel/`)
    await load()
    notify('Order cancelled.')
  } catch (error) {
    notify(apiError(error, 'Could not cancel the order.'), 'bad')
  } finally {
    busy.value = false
  }
}

/* ── Activity feed ────────────────────────────────────────────────────── */
const activity = computed(() => {
  const current = order.value
  if (!current) return []
  const events = []

  events.push({
    key: 'created',
    at: current.created_at,
    tone: 'accent',
    icon: 'mdi-clipboard-plus-outline',
    title: 'Order placed',
    detail: `${current.ordered_by_name || 'Unknown requester'} · ${testsTotal.value} test${testsTotal.value === 1 ? '' : 's'}`,
  })

  results.value.forEach((result) => {
    events.push({
      key: `result-${result.id}`,
      at: result.result_date,
      tone: result.is_abnormal ? 'bad' : 'good',
      icon: 'mdi-flask-outline',
      title: `Result entered · ${result.test_name || 'Test'}`,
      detail: `${result.performed_by_name || 'Unknown performer'}${result.is_abnormal ? ' · flagged abnormal' : ''}`,
    })
    if (result.verified_by) {
      events.push({
        key: `verified-${result.id}`,
        at: result.result_date,
        tone: 'good',
        icon: 'mdi-check-decagram',
        title: `Result verified · ${result.test_name || 'Test'}`,
        detail: result.verified_by_name || 'Verified',
      })
    }
  })

  specimens.value.forEach((specimen) => {
    if (!specimen.collected_at) return
    events.push({
      key: `specimen-${specimen.id}`,
      at: specimen.collected_at,
      tone: 'info',
      icon: 'mdi-test-tube',
      title: `Specimen collected · ${specimen.accession_number || '—'}`,
      detail: `${specimen.specimen_type || 'Specimen'}${specimen.container_type ? ` · ${specimen.container_type}` : ''}`,
    })
  })

  if (performedSigner.value?.signed_at) {
    events.push({
      key: 'signed-performed',
      at: performedSigner.value.signed_at,
      tone: 'accent',
      icon: 'mdi-draw-pen',
      title: 'Result signed as performer',
      detail: `${performedSigner.value.name}${performedSigner.value.title ? ` · ${performedSigner.value.title}` : ''}`,
    })
  }
  if (verifiedSigner.value?.signed_at) {
    events.push({
      key: 'signed-verified',
      at: verifiedSigner.value.signed_at,
      tone: 'good',
      icon: 'mdi-shield-check',
      title: 'Report authorised & signed',
      detail: `${verifiedSigner.value.name}${verifiedSigner.value.title ? ` · ${verifiedSigner.value.title}` : ''}`,
    })
  }

  homeVisits.value.forEach((visit) => {
    if (!visit.scheduled_date) return
    const time = visit.scheduled_time ? String(visit.scheduled_time).slice(0, 8) : '09:00:00'
    events.push({
      key: `visit-${visit.id}`,
      at: `${visit.scheduled_date}T${time}`,
      tone: 'info',
      icon: 'mdi-home-clock',
      title: 'Home visit scheduled',
      detail: `${visit.assigned_lab_tech_name || 'Unassigned'} · ${String(visit.status || '').replace(/_/g, ' ')}`,
    })
  })

  if (current.status === 'cancelled') {
    events.push({
      key: 'cancelled',
      at: current.updated_at,
      tone: 'bad',
      icon: 'mdi-cancel',
      title: 'Order cancelled',
      detail: 'No further processing is expected',
    })
  }

  return events
    .filter((event) => event.at)
    .sort((a, b) => new Date(b.at).getTime() - new Date(a.at).getTime())
})

/* ── Feedback ─────────────────────────────────────────────────────────── */
function notify(message, tone = 'good') {
  notice.value = { message, tone }
  if (noticeTimer) clearTimeout(noticeTimer)
  noticeTimer = setTimeout(() => {
    notice.value = null
  }, 4400)
}

function apiError(error, fallback) {
  const data = error?.response?.data
  if (!data) return error?.message || fallback
  if (typeof data === 'string') return data
  if (data.detail) return data.detail
  const first = Object.entries(data)[0]
  if (!first) return fallback
  const [field, value] = first
  return `${field.replace(/_/g, ' ')}: ${Array.isArray(value) ? value.join(', ') : value}`
}

/* ── Premium PDF report ───────────────────────────────────────────────── */
const downloadingPdf = ref(false)

async function downloadReport() {
  if (!import.meta.client || downloadingPdf.value) return
  // An unverified report is a draft — keep it inside the laboratory.
  if (!requireVerified('download this report')) return
  downloadingPdf.value = true
  try {
    const { data } = await $api.get(`/lab/orders/${orderId}/report-pdf/`, {
      responseType: 'blob',
    })
    const url = URL.createObjectURL(data)
    const anchor = document.createElement('a')
    anchor.href = url
    anchor.download = `lab_report_${String(orderId).padStart(5, '0')}.pdf`
    document.body.appendChild(anchor)
    anchor.click()
    document.body.removeChild(anchor)
    setTimeout(() => URL.revokeObjectURL(url), 4000)
    notify('Laboratory report downloaded.')
  } catch (error) {
    notify(apiError(error, 'Could not generate the report PDF.'), 'bad')
  } finally {
    downloadingPdf.value = false
  }
}

/* ── Data ─────────────────────────────────────────────────────────────── */
function unwrap(payload) {
  if (!payload) return []
  if (Array.isArray(payload)) return payload
  if (Array.isArray(payload.results)) return payload.results
  return []
}

function placeholderTest(id, index, names) {
  return {
    id,
    name: names[index] || `Test #${id}`,
    code: '',
    department: '',
    specimen_type: '',
    turnaround_time: '',
    reference_ranges: {},
    price: 0,
  }
}

async function load() {
  loading.value = true
  try {
    const [orderRes, extraRes, resultRes, specimenRes, visitRes, invoiceRes] = await Promise.allSettled([
      $api.get(`/lab/orders/${orderId}/`),
      $api.get(`/lab/order-extras/?lab_order=${orderId}`),
      $api.get(`/lab/results/?order=${orderId}&page_size=500`),
      $api.get(`/lab/specimens/?lab_order=${orderId}&page_size=200`),
      $api.get(`/lab/home-visits/?lab_order=${orderId}`),
      $api.get(`/lab/invoices/?lab_order=${orderId}`),
    ])

    order.value = orderRes.status === 'fulfilled' ? orderRes.value.data : order.value
    orderExtra.value = extraRes.status === 'fulfilled' ? unwrap(extraRes.value.data)[0] || null : null
    results.value = resultRes.status === 'fulfilled' ? unwrap(resultRes.value.data) : []
    specimens.value = specimenRes.status === 'fulfilled' ? unwrap(specimenRes.value.data) : []
    homeVisits.value = visitRes.status === 'fulfilled' ? unwrap(visitRes.value.data) : []
    invoice.value = invoiceRes.status === 'fulfilled' ? unwrap(invoiceRes.value.data)[0] || null : null

    const testIds = Array.isArray(order.value?.tests) ? order.value.tests : []
    const names = order.value?.test_names || []
    if (testIds.length) {
      try {
        const { data } = await $api.get('/lab/catalog/?page_size=500')
        const byId = new Map(unwrap(data).map((test) => [test.id, test]))
        orderedTests.value = testIds.map((id, index) => byId.get(id) || placeholderTest(id, index, names))
      } catch {
        orderedTests.value = testIds.map((id, index) => placeholderTest(id, index, names))
      }
    } else {
      orderedTests.value = []
    }

    loadedAt.value = new Date()
  } catch (error) {
    notify(apiError(error, 'Could not load this laboratory order.'), 'bad')
  } finally {
    loading.value = false
  }
}

onMounted(load)

onBeforeUnmount(() => {
  if (noticeTimer) clearTimeout(noticeTimer)
  releaseObjectUrl()
})
</script>

<style scoped>
/* ══ Tokens ══ */
.lo-page,
.lo-dlg {
  --lo-line: rgba(var(--v-theme-on-surface), 0.09);
  --lo-line-soft: rgba(var(--v-theme-on-surface), 0.06);
  --lo-muted: rgba(var(--v-theme-on-surface), 0.6);
  --lo-faint: rgba(var(--v-theme-on-surface), 0.44);
  --lo-surface: rgb(var(--v-theme-surface));
  --lo-raise: rgba(var(--v-theme-on-surface), 0.035);
}
.lo-page { width: 100%; }

/* ══ Header ══ */
.lo-head {
  position: relative;
  border-radius: 18px;
  padding: 17px 20px 12px;
  margin-bottom: 14px;
  background: var(--lo-surface);
  border: 1px solid var(--lo-line);
  box-shadow: 0 10px 30px rgba(15, 23, 42, 0.055);
  overflow: hidden;
}
.lo-head::before {
  content: '';
  position: absolute;
  inset: 0 auto 0 0;
  width: 4px;
  background: linear-gradient(180deg, var(--lo-accent), var(--lo-accent-soft));
}
.lo-head-top { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; min-width: 0; }
.lo-back {
  width: 34px; height: 34px; flex-shrink: 0;
  display: grid; place-items: center;
  border-radius: 10px; border: 1px solid var(--lo-line);
  background: transparent; color: var(--lo-muted);
  text-decoration: none;
  transition: background 0.15s ease, color 0.15s ease, transform 0.15s ease;
}
.lo-back:hover { background: var(--lo-raise); color: rgb(var(--v-theme-on-surface)); transform: translateX(-1px); }
.lo-head-icon {
  width: 50px; height: 50px; border-radius: 15px;
  display: grid; place-items: center; flex-shrink: 0;
  color: var(--lo-accent-ink);
  background: color-mix(in srgb, var(--lo-accent) 12%, transparent);
  border: 1px solid color-mix(in srgb, var(--lo-accent) 22%, transparent);
}
.lo-head-id { flex: 1; min-width: 220px; }
.lo-head-eyebrow {
  display: inline-flex; align-items: center; gap: 6px;
  font-size: 9.5px; font-weight: 800; letter-spacing: 1.4px;
  text-transform: uppercase; color: var(--lo-faint);
}
.lo-head-title {
  margin: 3px 0 2px; font-size: 24px; line-height: 1.15;
  font-weight: 800; letter-spacing: -0.4px;
}
.lo-head-sub { margin: 0; font-size: 12.5px; line-height: 1.45; color: var(--lo-muted); max-width: 90ch; }
.lo-head-actions { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; justify-content: flex-end; }
.lo-head-foot {
  display: flex; align-items: center; gap: 7px; flex-wrap: wrap;
  margin-top: 13px; padding-top: 11px;
  border-top: 1px solid var(--lo-line-soft);
}
.lo-head-stamp { margin-left: auto; font-size: 10.5px; font-weight: 700; color: var(--lo-faint); white-space: nowrap; }
.lo-live-dot { width: 7px; height: 7px; border-radius: 50%; background: #22c55e; animation: loPulse 2s infinite; }
@keyframes loPulse {
  0% { box-shadow: 0 0 0 0 rgba(34, 197, 94, 0.5); }
  70% { box-shadow: 0 0 0 6px rgba(34, 197, 94, 0); }
  100% { box-shadow: 0 0 0 0 rgba(34, 197, 94, 0); }
}

/* ══ Chips and pills ══ */
.lo-chip {
  display: inline-flex; align-items: center; gap: 5px;
  height: 25px; padding: 0 9px; border-radius: 999px;
  border: 1px solid var(--lo-line); background: var(--lo-raise);
  font-size: 10.5px; font-weight: 700; color: var(--lo-muted);
  white-space: nowrap; max-width: 260px; overflow: hidden; text-overflow: ellipsis;
}
.lo-chip.is-good { color: #047857; border-color: rgba(16, 185, 129, 0.28); background: rgba(16, 185, 129, 0.08); }
.lo-chip.is-warn { color: #b45309; border-color: rgba(245, 158, 11, 0.3); background: rgba(245, 158, 11, 0.09); }
.lo-chip.is-bad { color: #b91c1c; border-color: rgba(239, 68, 68, 0.26); background: rgba(239, 68, 68, 0.08); }
.lo-chip.is-info { color: #1d4ed8; border-color: rgba(37, 99, 235, 0.26); background: rgba(37, 99, 235, 0.08); }

.lo-pill {
  display: inline-flex; align-items: center; gap: 4px;
  height: 21px; padding: 0 8px; border-radius: 999px;
  border: 1px solid var(--lo-line); background: var(--lo-raise);
  font-size: 10px; font-weight: 800; letter-spacing: 0.2px;
  color: var(--lo-muted); white-space: nowrap; text-transform: capitalize;
}
.lo-pill.is-good { color: #047857; border-color: rgba(16, 185, 129, 0.3); background: rgba(16, 185, 129, 0.09); }
.lo-pill.is-warn { color: #b45309; border-color: rgba(245, 158, 11, 0.32); background: rgba(245, 158, 11, 0.1); }
.lo-pill.is-bad { color: #b91c1c; border-color: rgba(239, 68, 68, 0.3); background: rgba(239, 68, 68, 0.09); }
.lo-pill.is-info { color: #1d4ed8; border-color: rgba(37, 99, 235, 0.28); background: rgba(37, 99, 235, 0.09); }
.lo-pill.is-accent {
  color: var(--lo-accent-ink);
  border-color: color-mix(in srgb, var(--lo-accent) 34%, transparent);
  background: color-mix(in srgb, var(--lo-accent) 11%, transparent);
}
.lo-pill.is-muted { text-transform: capitalize; }

/* ══ Buttons ══ */
.lo-btn {
  display: inline-flex; align-items: center; gap: 6px;
  height: 36px; padding: 0 13px; border-radius: 10px;
  border: 1px solid var(--lo-line); background: transparent;
  color: rgb(var(--v-theme-on-surface));
  font-family: inherit; font-size: 12.5px; font-weight: 700;
  cursor: pointer; white-space: nowrap; text-decoration: none;
  transition: background 0.15s ease, transform 0.15s ease, opacity 0.15s ease;
}
.lo-btn:hover:not(:disabled) { background: var(--lo-raise); transform: translateY(-1px); }
.lo-btn:disabled { opacity: 0.45; cursor: not-allowed; }
.lo-btn.is-primary {
  background: var(--lo-accent); color: var(--lo-on-accent);
  border-color: transparent; box-shadow: 0 7px 18px var(--lo-accent-ring);
}
/* Re-assert the solid fill on hover: the generic .lo-btn:hover rule above has a
   heavier selector, so without this the background falls back to a near-
   transparent tint and the white label disappears. */
.lo-btn.is-primary:hover:not(:disabled) {
  background: var(--lo-accent);
  color: var(--lo-on-accent);
  border-color: transparent;
  filter: brightness(1.06);
}
.lo-btn.is-primary:active:not(:disabled) { filter: brightness(0.96); }
.lo-btn.is-primary :deep(.v-icon) { color: currentColor; }
.lo-btn.is-danger { color: #b91c1c; border-color: rgba(239, 68, 68, 0.32); }
.lo-btn.is-danger:hover:not(:disabled) { background: rgba(239, 68, 68, 0.08); }
.lo-btn.is-sm { height: 28px; padding: 0 10px; font-size: 11.5px; border-radius: 8px; }
.lo-spin { animation: loSpin 0.9s linear infinite; }
@keyframes loSpin { to { transform: rotate(360deg); } }

.lo-link {
  border: 0; background: none; padding: 0 2px;
  font-family: inherit; font-size: 11px; font-weight: 800;
  color: var(--lo-accent); cursor: pointer;
}
.lo-link:hover { text-decoration: underline; }
.lo-link.is-quiet { color: var(--lo-muted); }

/* ══ Workflow ══ */
.lo-flow {
  display: flex; align-items: center; gap: 0;
  background: var(--lo-surface); border: 1px solid var(--lo-line);
  border-radius: 16px; padding: 13px 18px; margin-bottom: 14px;
  position: relative;
}
.lo-step { display: flex; align-items: center; gap: 9px; flex: 0 0 auto; }
.lo-step-node {
  width: 28px; height: 28px; border-radius: 9px;
  display: grid; place-items: center; flex-shrink: 0;
  border: 1px solid var(--lo-line); background: var(--lo-raise); color: var(--lo-faint);
}
.lo-step-text { display: flex; flex-direction: column; line-height: 1.25; }
.lo-step-text b { font-size: 11.5px; font-weight: 800; color: var(--lo-faint); }
.lo-step-text em { font-size: 10px; font-style: normal; font-weight: 600; color: var(--lo-faint); opacity: 0.85; }
.lo-step.is-done .lo-step-node { color: #047857; background: rgba(16, 185, 129, 0.1); border-color: rgba(16, 185, 129, 0.3); }
.lo-step.is-done .lo-step-text b { color: rgba(var(--v-theme-on-surface), 0.75); }
.lo-step.is-current .lo-step-node {
  color: var(--lo-on-accent); background: var(--lo-accent);
  border-color: transparent; box-shadow: 0 6px 14px var(--lo-accent-ring);
}
.lo-step.is-current .lo-step-text b { color: rgb(var(--v-theme-on-surface)); }
.lo-step-rail {
  flex: 1 1 auto; min-width: 18px; height: 2px; border-radius: 2px;
  background: var(--lo-line); margin: 0 12px; position: relative;
}
.lo-step-rail i {
  position: absolute; inset: 0 auto 0 0; width: 0;
  border-radius: 2px; background: #10b981; transition: width 0.3s ease;
}
.lo-step-rail i.is-on { width: 100%; }
.lo-flow-progress {
  position: absolute; top: 10px; right: 12px;
  font-size: 9.5px; font-weight: 800; letter-spacing: 0.6px;
  color: var(--lo-faint);
}

.lo-cancel-banner {
  display: flex; align-items: flex-start; gap: 10px;
  padding: 12px 15px; margin-bottom: 14px;
  border-radius: 14px; border: 1px solid rgba(239, 68, 68, 0.28);
  background: rgba(239, 68, 68, 0.07); color: #b91c1c;
}
.lo-cancel-banner b { display: block; font-size: 12.5px; font-weight: 800; }
.lo-cancel-banner span { display: block; font-size: 11.5px; line-height: 1.5; opacity: 0.86; }

/* ══ KPIs ══ */
.lo-kpis {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  gap: 10px; margin-bottom: 14px;
}
.lo-kpi {
  display: flex; flex-direction: column; gap: 1px;
  padding: 12px 14px; border-radius: 14px;
  background: var(--lo-surface); border: 1px solid var(--lo-line);
  transition: transform 0.18s ease, box-shadow 0.18s ease;
}
.lo-kpi:hover { transform: translateY(-2px); box-shadow: 0 12px 26px rgba(15, 23, 42, 0.07); }
.lo-kpi-ico {
  width: 26px; height: 26px; border-radius: 8px; margin-bottom: 6px;
  display: grid; place-items: center;
  color: var(--lo-accent);
  background: color-mix(in srgb, var(--lo-accent) 10%, transparent);
  border: 1px solid color-mix(in srgb, var(--lo-accent) 20%, transparent);
}
.lo-kpi b { font-size: 19px; font-weight: 800; letter-spacing: -0.4px; line-height: 1.15; }
.lo-kpi b i { font-size: 11.5px; font-style: normal; font-weight: 700; color: var(--lo-faint); }
.lo-kpi-l {
  font-size: 9.5px; font-weight: 800; letter-spacing: 0.5px;
  text-transform: uppercase; color: var(--lo-faint);
}
.lo-kpi.is-good .lo-kpi-ico { color: #047857; background: rgba(16, 185, 129, 0.1); border-color: rgba(16, 185, 129, 0.26); }
.lo-kpi.is-bad .lo-kpi-ico { color: #b91c1c; background: rgba(239, 68, 68, 0.1); border-color: rgba(239, 68, 68, 0.26); }
.lo-kpi.is-bad b { color: #b91c1c; }

/* ══ Panels ══ */
.lo-panel {
  background: var(--lo-surface); border: 1px solid var(--lo-line);
  border-radius: 16px; margin-bottom: 14px; overflow: hidden;
}
.lo-panel-head {
  display: flex; align-items: center; gap: 8px;
  padding: 12px 16px; border-bottom: 1px solid var(--lo-line-soft);
  flex-wrap: wrap;
}
.lo-panel-ico {
  width: 26px; height: 26px; border-radius: 8px; flex-shrink: 0;
  display: grid; place-items: center; color: var(--lo-accent);
  background: color-mix(in srgb, var(--lo-accent) 10%, transparent);
  border: 1px solid color-mix(in srgb, var(--lo-accent) 20%, transparent);
}
.lo-panel-ico.is-amber { color: #b45309; background: rgba(245, 158, 11, 0.1); border-color: rgba(245, 158, 11, 0.24); }
.lo-panel-ico.is-indigo { color: #4338ca; background: rgba(79, 70, 229, 0.1); border-color: rgba(79, 70, 229, 0.24); }
.lo-panel-ico.is-info { color: #1d4ed8; background: rgba(37, 99, 235, 0.1); border-color: rgba(37, 99, 235, 0.24); }
.lo-panel-ico.is-purple { color: #7e22ce; background: rgba(147, 51, 234, 0.1); border-color: rgba(147, 51, 234, 0.24); }
.lo-panel-ico.is-good { color: #047857; background: rgba(16, 185, 129, 0.1); border-color: rgba(16, 185, 129, 0.24); }
.lo-panel-ico.is-slate { color: rgba(var(--v-theme-on-surface), 0.65); background: var(--lo-raise); border-color: var(--lo-line); }
.lo-panel-head h2 { font-size: 13px; font-weight: 800; letter-spacing: -0.1px; margin: 0; }
.lo-panel-count {
  font-size: 10px; font-weight: 800; color: var(--lo-muted);
  padding: 1px 7px; border-radius: 999px;
  background: var(--lo-raise); border: 1px solid var(--lo-line);
}
.lo-panel-tools { margin-left: auto; display: flex; align-items: center; gap: 6px; }
.lo-panel-body { padding: 14px 16px; }
.lo-panel-foot {
  display: flex; align-items: center; gap: 10px; flex-wrap: wrap;
  padding: 11px 16px; border-top: 1px solid var(--lo-line-soft);
  background: rgba(16, 185, 129, 0.06);
}
.lo-foot-hint {
  display: inline-flex; align-items: center; gap: 6px;
  font-size: 11.5px; font-weight: 700; color: #047857;
}

.lo-seg {
  display: inline-flex; padding: 2px; gap: 2px;
  border-radius: 9px; border: 1px solid var(--lo-line); background: var(--lo-raise);
}
.lo-seg button {
  display: inline-flex; align-items: center; gap: 5px;
  height: 22px; padding: 0 9px; border: 0; border-radius: 7px;
  background: transparent; cursor: pointer;
  font-family: inherit; font-size: 10.5px; font-weight: 800;
  color: var(--lo-muted); transition: background 0.15s ease, color 0.15s ease;
}
.lo-seg button em { font-style: normal; font-size: 9px; font-weight: 800; color: var(--lo-faint); }
.lo-seg button:hover { color: rgb(var(--v-theme-on-surface)); }
.lo-seg button.is-on {
  background: var(--lo-surface); color: rgb(var(--v-theme-on-surface));
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.12);
}

/* ══ Test cards ══ */
.lo-test {
  border: 1px solid var(--lo-line); border-radius: 13px;
  padding: 11px 13px; margin-bottom: 10px;
  background: var(--lo-surface);
  transition: border-color 0.15s ease, box-shadow 0.15s ease;
}
.lo-test:last-child { margin-bottom: 0; }
.lo-test:hover { box-shadow: 0 8px 20px rgba(15, 23, 42, 0.06); }
.lo-test.is-done { border-left: 3px solid #10b981; }
.lo-test.is-bad { border-left: 3px solid #ef4444; }
.lo-test-head { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
.lo-test-dept {
  font-size: 9px; font-weight: 800; letter-spacing: 0.6px; text-transform: uppercase;
  color: var(--lo-faint); padding: 2px 6px; border-radius: 6px;
  border: 1px solid var(--lo-line); background: var(--lo-raise); white-space: nowrap;
}
.lo-test-id { flex: 1; min-width: 140px; display: flex; align-items: baseline; gap: 7px; flex-wrap: wrap; }
.lo-test-id b { font-size: 13px; font-weight: 800; letter-spacing: -0.15px; }
.lo-code {
  font-size: 9.5px; font-weight: 800; letter-spacing: 0.5px;
  color: var(--lo-muted); padding: 1px 5px; border-radius: 5px;
  background: var(--lo-raise); border: 1px solid var(--lo-line);
}
.lo-test-meta {
  display: flex; align-items: center; gap: 12px; flex-wrap: wrap;
  margin-top: 7px; font-size: 11px; font-weight: 600; color: var(--lo-muted);
}
.lo-test-meta span { display: inline-flex; align-items: center; gap: 4px; }
.lo-test-refcount { color: var(--lo-faint) !important; }

.lo-result-list { margin-top: 10px; display: flex; flex-direction: column; gap: 8px; }
.lo-result {
  display: flex; align-items: flex-start; gap: 12px; flex-wrap: wrap;
  padding: 10px 12px; border-radius: 11px;
  background: rgba(16, 185, 129, 0.055);
  border: 1px solid rgba(16, 185, 129, 0.2);
}
.lo-result-main { flex: 1; min-width: 170px; }
.lo-result-value {
  font-size: 14px; font-weight: 800; letter-spacing: -0.2px;
  color: rgb(var(--v-theme-on-surface)); word-break: break-word;
}
.lo-result-value em { font-style: normal; font-size: 11px; font-weight: 700; color: var(--lo-muted); margin-left: 5px; }
.lo-result-note {
  display: flex; align-items: center; gap: 5px; flex-wrap: wrap;
  margin-top: 3px; font-size: 10.5px; font-weight: 600; color: var(--lo-muted);
}
.lo-result-comment { font-style: italic; color: var(--lo-faint); }
.lo-result-side { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; }

.lo-test-empty {
  display: flex; align-items: center; gap: 6px; flex-wrap: wrap;
  margin-top: 9px; padding-top: 9px; border-top: 1px dashed var(--lo-line);
}
.lo-test-empty-label { font-size: 10.5px; font-weight: 700; color: var(--lo-faint); }
.lo-range-chip {
  display: inline-flex; align-items: center; gap: 4px;
  font-size: 10px; font-weight: 700; color: var(--lo-muted);
  padding: 2px 7px; border-radius: 999px;
  border: 1px solid var(--lo-line); background: var(--lo-raise);
}
.lo-range-chip b { color: rgb(var(--v-theme-on-surface)); font-weight: 800; }
.lo-range-chip.is-more { color: var(--lo-faint); border-style: dashed; }

/* ══ Notes ══ */
.lo-note { border-left: 3px solid rgba(245, 158, 11, 0.5); }
.lo-note .lo-panel-body { display: grid; gap: 10px; }
.lo-note-block span {
  display: block; font-size: 9.5px; font-weight: 800; letter-spacing: 0.6px;
  text-transform: uppercase; color: var(--lo-faint); margin-bottom: 3px;
}
.lo-note-block p {
  margin: 0; font-size: 12px; line-height: 1.6;
  color: rgba(var(--v-theme-on-surface), 0.8); white-space: pre-wrap;
}

/* ══ Definition lists ══ */
.lo-dl { display: grid; gap: 9px; }
.lo-dl > div { display: flex; align-items: baseline; justify-content: space-between; gap: 10px; }
.lo-dl span {
  font-size: 10.5px; font-weight: 700; letter-spacing: 0.3px;
  text-transform: uppercase; color: var(--lo-faint);
}
.lo-dl b { font-size: 11.5px; font-weight: 800; text-align: right; word-break: break-word; }
.lo-dl b.is-cap { text-transform: capitalize; }
.lo-dl-grid { grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; }
.lo-dl-grid > div { flex-direction: column; align-items: flex-start; gap: 2px; }
.lo-dl-grid b { text-align: left; }
.lo-mono { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; letter-spacing: -0.2px; }
.lo-muted-line { margin: 0; font-size: 11.5px; font-weight: 600; color: var(--lo-faint); }

/* ══ Bench sign-off ══ */
.lo-auth .lo-panel-body { display: grid; gap: 11px; }
.lo-auth-slot {
  display: grid; gap: 7px;
  padding: 11px 12px; border-radius: 12px;
  border: 1px solid var(--lo-line); background: var(--lo-raise);
}
.lo-auth-slot + .lo-auth-slot { margin-top: 0; }
.lo-auth-head { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
.lo-auth-label {
  font-size: 9.5px; font-weight: 800; letter-spacing: 0.7px;
  text-transform: uppercase; color: var(--lo-faint);
}
.lo-auth-sig {
  display: block; width: 100%; max-height: 52px; object-fit: contain;
  padding: 5px 7px; border-radius: 9px;
  background: #fff; border: 1px solid var(--lo-line-soft);
}
.lo-auth-nosig {
  display: grid; place-items: center; min-height: 44px;
  border-radius: 9px; border: 1px dashed var(--lo-line);
  font-size: 9.5px; font-weight: 700; letter-spacing: 0.2px;
  color: var(--lo-faint); text-align: center; padding: 6px;
}
.lo-auth-person { display: grid; gap: 1px; }
.lo-auth-person b { font-size: 11.5px; font-weight: 800; letter-spacing: -0.1px; }
.lo-auth-person span { font-size: 10px; font-weight: 600; color: var(--lo-faint); }
.lo-auth-cta { width: 100%; justify-content: center; }
.lo-auth-hint {
  display: flex; align-items: flex-start; gap: 5px; margin: 0;
  font-size: 10.5px; font-weight: 600; line-height: 1.5; color: var(--lo-faint);
}
.lo-auth-hint .v-icon { margin-top: 1px; opacity: 0.8; }

/* ══ Patient ══ */
.lo-patient { display: flex; align-items: center; gap: 11px; }
.lo-avatar {
  width: 44px; height: 44px; border-radius: 13px; flex-shrink: 0;
  display: grid; place-items: center;
  font-size: 14px; font-weight: 800; letter-spacing: 0.3px;
  color: var(--lo-accent-ink);
  background: color-mix(in srgb, var(--lo-accent) 13%, transparent);
  border: 1px solid color-mix(in srgb, var(--lo-accent) 24%, transparent);
}
.lo-patient-id { display: flex; flex-direction: column; line-height: 1.3; min-width: 0; }
.lo-patient-id b { font-size: 13.5px; font-weight: 800; letter-spacing: -0.2px; }
.lo-patient-id span { font-size: 10.5px; font-weight: 700; color: var(--lo-faint); }
.lo-patient-actions { display: flex; gap: 7px; flex-wrap: wrap; margin-top: 12px; }

/* ══ Mini cards ══ */
.lo-mini-card {
  padding: 9px 11px; border-radius: 11px; margin-bottom: 8px;
  border: 1px solid var(--lo-line); background: var(--lo-raise);
}
.lo-mini-card:last-child { margin-bottom: 0; }
.lo-mini-top { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
.lo-mini-top b { font-size: 11.5px; font-weight: 800; }
.lo-mini-meta {
  display: flex; align-items: center; gap: 9px; flex-wrap: wrap;
  margin-top: 4px; font-size: 10.5px; font-weight: 600; color: var(--lo-muted);
}
.lo-mini-meta span { display: inline-flex; align-items: center; gap: 3px; }
.lo-mini-foot {
  display: flex; align-items: center; gap: 4px;
  margin-top: 4px; font-size: 10px; font-weight: 600; color: var(--lo-faint);
}
.lo-mini-alert {
  margin-top: 6px; padding: 5px 8px; border-radius: 8px;
  font-size: 10.5px; font-weight: 700; color: #b91c1c;
  background: rgba(239, 68, 68, 0.08); border: 1px solid rgba(239, 68, 68, 0.24);
}

/* ══ Invoice ══ */
.lo-invoice-id { display: flex; align-items: center; justify-content: space-between; gap: 8px; margin-bottom: 10px; }
.lo-invoice-id b { font-size: 12px; font-weight: 800; }
.lo-invoice-rows { display: grid; gap: 5px; }
.lo-invoice-rows > div { display: flex; align-items: baseline; justify-content: space-between; gap: 10px; }
.lo-invoice-rows span { font-size: 10.5px; font-weight: 700; color: var(--lo-faint); }
.lo-invoice-rows b { font-size: 11.5px; font-weight: 800; }
.lo-invoice-rows b.is-good { color: #047857; }
.lo-invoice-rows b.is-bad { color: #b91c1c; }
.lo-invoice-total {
  display: flex; align-items: baseline; justify-content: space-between;
  margin: 9px 0 7px; padding-top: 8px; border-top: 1px solid var(--lo-line);
}
.lo-invoice-total span {
  font-size: 10.5px; font-weight: 800; letter-spacing: 0.4px;
  text-transform: uppercase; color: var(--lo-muted);
}
.lo-invoice-total b { font-size: 15px; font-weight: 800; letter-spacing: -0.4px; }
.lo-invoice-bar {
  height: 6px; border-radius: 999px; overflow: hidden;
  background: var(--lo-raise); border: 1px solid var(--lo-line); margin-bottom: 8px;
}
.lo-invoice-bar i {
  display: block; height: 100%; border-radius: 999px;
  background: linear-gradient(90deg, #10b981, #34d399);
  transition: width 0.3s ease;
}

/* ══ Timeline ══ */
.lo-tl { list-style: none; margin: 0; padding: 0; display: grid; gap: 2px; }
.lo-tl li { display: flex; align-items: flex-start; gap: 10px; padding: 7px 0; }
.lo-tl li + li { border-top: 1px dashed var(--lo-line-soft); }
.lo-tl-dot {
  width: 24px; height: 24px; border-radius: 8px; flex-shrink: 0;
  display: grid; place-items: center; color: var(--lo-accent);
  background: color-mix(in srgb, var(--lo-accent) 10%, transparent);
  border: 1px solid color-mix(in srgb, var(--lo-accent) 20%, transparent);
}
.lo-tl-main { flex: 1; min-width: 0; display: flex; flex-direction: column; line-height: 1.35; }
.lo-tl-main b { font-size: 11.5px; font-weight: 800; }
.lo-tl-main span { font-size: 10.5px; font-weight: 600; color: var(--lo-muted); }
.lo-tl-time { font-size: 10px; font-weight: 700; color: var(--lo-faint); white-space: nowrap; padding-top: 2px; }
.lo-tl li.is-good .lo-tl-dot { color: #047857; background: rgba(16, 185, 129, 0.1); border-color: rgba(16, 185, 129, 0.26); }
.lo-tl li.is-bad .lo-tl-dot { color: #b91c1c; background: rgba(239, 68, 68, 0.1); border-color: rgba(239, 68, 68, 0.26); }
.lo-tl li.is-info .lo-tl-dot { color: #1d4ed8; background: rgba(37, 99, 235, 0.1); border-color: rgba(37, 99, 235, 0.24); }

/* ══ Empty states ══ */
.lo-empty {
  display: flex; flex-direction: column; align-items: center; gap: 4px;
  padding: 26px 14px; text-align: center; color: var(--lo-faint);
}
.lo-empty.is-tight { padding: 16px 8px; }
.lo-empty b { font-size: 12px; font-weight: 800; color: var(--lo-muted); }
.lo-empty span { font-size: 11px; font-weight: 600; }

.lo-loading {
  display: flex; flex-direction: column; align-items: center; gap: 12px;
  padding: 90px 20px; color: var(--lo-faint); font-size: 12px; font-weight: 700;
}

/* ══ Dialog ══ */
.lo-dlg {
  display: flex;
  flex-direction: column;
  max-height: calc(100vh - 48px);
  overflow: hidden;
}
.lo-dlg-body {
  flex: 1 1 auto;
  min-height: 0;
  overflow-y: auto;
  padding: 16px 20px 4px;
}
.lo-dlg-grid { display: grid; grid-template-columns: 300px minmax(0, 1fr); gap: 18px; }
.lo-dlg-col { display: flex; flex-direction: column; gap: 12px; min-width: 0; }
.lo-field { display: flex; flex-direction: column; gap: 5px; }
.lo-field > label {
  font-size: 9.5px; font-weight: 800; letter-spacing: 0.7px;
  text-transform: uppercase; color: var(--lo-faint);
}
.lo-field :deep(.v-field) { border-radius: 10px; }
.lo-field :deep(.v-field__input) { font-size: 12.5px; font-weight: 600; }

.lo-dlg-meta {
  display: grid; grid-template-columns: 1fr 1fr; gap: 8px;
  padding: 10px 12px; border-radius: 11px;
  border: 1px solid var(--lo-line); background: var(--lo-raise);
}
.lo-dlg-meta > div { display: flex; flex-direction: column; line-height: 1.3; min-width: 0; }
.lo-dlg-meta span { font-size: 9px; font-weight: 800; letter-spacing: 0.5px; text-transform: uppercase; color: var(--lo-faint); }
.lo-dlg-meta b { font-size: 11.5px; font-weight: 800; overflow: hidden; text-overflow: ellipsis; }

.lo-ref { border: 1px solid var(--lo-line); border-radius: 11px; overflow: hidden; }
.lo-ref-head {
  padding: 7px 11px; font-size: 9.5px; font-weight: 800;
  letter-spacing: 0.7px; text-transform: uppercase; color: var(--lo-faint);
  background: var(--lo-raise); border-bottom: 1px solid var(--lo-line-soft);
}
.lo-ref-row { display: flex; align-items: baseline; justify-content: space-between; gap: 10px; padding: 6px 11px; font-size: 11px; }
.lo-ref-row + .lo-ref-row { border-top: 1px dashed var(--lo-line-soft); }
.lo-ref-row span { font-weight: 700; color: var(--lo-muted); }
.lo-ref-row b { font-weight: 800; font-size: 11px; }

.lo-hint {
  display: flex; align-items: flex-start; gap: 5px; margin: 0;
  font-size: 10.5px; font-weight: 600; line-height: 1.5; color: var(--lo-muted);
}
.lo-amend-note {
  display: flex; align-items: flex-start; gap: 6px;
  padding: 8px 10px; border-radius: 10px;
  font-size: 10.5px; font-weight: 700; line-height: 1.45;
  color: #b45309; background: rgba(245, 158, 11, 0.09);
  border: 1px solid rgba(245, 158, 11, 0.28);
}

.lo-mode {
  display: inline-flex; padding: 2px; gap: 2px; align-self: flex-start;
  border-radius: 9px; border: 1px solid var(--lo-line); background: var(--lo-raise);
}
.lo-mode button {
  height: 24px; padding: 0 10px; border: 0; border-radius: 7px;
  background: transparent; cursor: pointer; font-family: inherit;
  font-size: 10.5px; font-weight: 800; color: var(--lo-muted);
  transition: background 0.15s ease, color 0.15s ease;
}
.lo-mode button.is-on {
  background: var(--lo-surface); color: rgb(var(--v-theme-on-surface));
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.12);
}

.lo-analyte-list { display: flex; flex-direction: column; gap: 8px; }
.lo-analyte { padding: 8px 11px; border-radius: 11px; border: 1px solid var(--lo-line); background: var(--lo-raise); }
.lo-analyte-top { display: flex; align-items: baseline; justify-content: space-between; gap: 10px; }
.lo-analyte-name { font-size: 11.5px; font-weight: 800; }
.lo-analyte-range { font-size: 10px; font-weight: 700; color: var(--lo-faint); }
.lo-analyte-input { display: flex; align-items: center; gap: 8px; margin-top: 5px; }
.lo-analyte-input input {
  flex: 1; min-width: 0; height: 30px; padding: 0 9px;
  border-radius: 8px; border: 1px solid var(--lo-line);
  background: var(--lo-surface); color: rgb(var(--v-theme-on-surface));
  font-family: inherit; font-size: 12.5px; font-weight: 700;
}
.lo-analyte-input input:focus {
  outline: none;
  border-color: color-mix(in srgb, var(--lo-accent) 55%, transparent);
  box-shadow: 0 0 0 3px color-mix(in srgb, var(--lo-accent) 14%, transparent);
}
.lo-analyte-unit { font-size: 10.5px; font-weight: 800; color: var(--lo-muted); white-space: nowrap; }

.lo-verdict {
  display: inline-flex; align-items: center; gap: 5px; align-self: flex-start;
  padding: 4px 9px; border-radius: 999px; font-size: 10.5px; font-weight: 800;
}
.lo-verdict.is-good { color: #047857; background: rgba(16, 185, 129, 0.1); border: 1px solid rgba(16, 185, 129, 0.28); }
.lo-verdict.is-bad { color: #b91c1c; background: rgba(239, 68, 68, 0.1); border: 1px solid rgba(239, 68, 68, 0.28); }

.lo-flagseg {
  display: inline-flex; padding: 2px; gap: 2px; align-self: flex-start;
  border-radius: 9px; border: 1px solid var(--lo-line); background: var(--lo-raise);
}
.lo-flagseg button {
  display: inline-flex; align-items: center; gap: 5px;
  height: 24px; padding: 0 10px; border: 0; border-radius: 7px;
  background: transparent; cursor: pointer; font-family: inherit;
  font-size: 10.5px; font-weight: 800; color: var(--lo-muted);
  transition: background 0.15s ease, color 0.15s ease;
}
.lo-flagseg button em {
  font-style: normal; font-size: 9px; font-weight: 800;
  color: var(--lo-faint); text-transform: uppercase; letter-spacing: 0.3px;
}
.lo-flagseg button.is-on {
  background: var(--lo-surface); color: rgb(var(--v-theme-on-surface));
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.12);
}

.lo-preview {
  display: flex; flex-direction: column; gap: 4px;
  padding: 9px 12px; border-radius: 11px;
  border: 1px dashed var(--lo-line); background: var(--lo-raise);
}
.lo-preview span {
  font-size: 9px; font-weight: 800; letter-spacing: 0.7px;
  text-transform: uppercase; color: var(--lo-faint);
}
.lo-preview code {
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 11.5px; font-weight: 700; line-height: 1.5;
  color: rgb(var(--v-theme-on-surface)); word-break: break-word;
}

/* ══ Optional attachment uploader ══ */
.lo-opt {
  margin-left: 5px; font-style: normal; font-size: 8.5px; font-weight: 800;
  letter-spacing: 0.6px; text-transform: uppercase;
  color: var(--lo-faint); padding: 1px 5px; border-radius: 5px;
  border: 1px solid var(--lo-line); background: var(--lo-raise);
}
.lo-drop {
  display: flex; flex-direction: column; align-items: center; gap: 3px;
  padding: 14px 12px; border-radius: 11px; cursor: pointer;
  border: 1.5px dashed var(--lo-line); background: var(--lo-raise);
  text-align: center;
  transition: border-color 0.15s ease, background 0.15s ease;
}
.lo-drop:hover,
.lo-drop.is-over {
  border-color: color-mix(in srgb, var(--lo-accent) 55%, transparent);
  background: color-mix(in srgb, var(--lo-accent) 7%, transparent);
}
.lo-drop-ico { color: var(--lo-accent); }
.lo-drop b { font-size: 11.5px; font-weight: 800; }
.lo-drop span { font-size: 10px; font-weight: 600; color: var(--lo-faint); }
.lo-drop > span:last-child { max-width: 34ch; line-height: 1.45; }

.lo-attach {
  display: flex; align-items: center; gap: 10px;
  padding: 8px 10px; border-radius: 11px;
  border: 1px solid var(--lo-line); background: var(--lo-raise);
}
.lo-attach.is-pdf { border-color: rgba(239, 68, 68, 0.28); background: rgba(239, 68, 68, 0.055); }
.lo-attach.is-image { border-color: rgba(16, 185, 129, 0.28); background: rgba(16, 185, 129, 0.055); }
.lo-attach-thumb {
  width: 38px; height: 38px; flex-shrink: 0; padding: 0;
  border-radius: 8px; overflow: hidden; cursor: zoom-in;
  border: 1px solid var(--lo-line); background: var(--lo-surface);
}
.lo-attach-thumb img { width: 100%; height: 100%; object-fit: cover; display: block; }
.lo-attach-ico {
  width: 38px; height: 38px; flex-shrink: 0;
  display: grid; place-items: center; border-radius: 8px;
  color: #b91c1c; background: rgba(239, 68, 68, 0.1);
  border: 1px solid rgba(239, 68, 68, 0.24);
}
.lo-attach-meta { flex: 1; min-width: 0; display: flex; flex-direction: column; line-height: 1.35; }
.lo-attach-meta b {
  font-size: 11.5px; font-weight: 800;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.lo-attach-meta span { font-size: 10px; font-weight: 600; color: var(--lo-faint); }
.lo-attach-acts { display: flex; align-items: center; gap: 6px; flex-shrink: 0; flex-wrap: wrap; }

.lo-file-hidden { display: none; }
.lo-field-err {
  display: flex; align-items: center; gap: 4px; margin: 0;
  font-size: 10.5px; font-weight: 700; color: #b91c1c;
}

.lo-attach-pill { text-decoration: none; cursor: pointer; }
.lo-attach-pill:hover {
  filter: brightness(0.97);
  border-color: color-mix(in srgb, var(--lo-accent) 55%, transparent);
}

/* ══ Lightbox ══ */
.lo-lightbox { display: flex; flex-direction: column; max-height: calc(100vh - 80px); overflow: hidden; }
.lo-lightbox-bar {
  display: flex; align-items: center; gap: 8px; flex-wrap: wrap;
  padding: 10px 14px; border-bottom: 1px solid var(--lo-line-soft);
}
.lo-lightbox-bar b { font-size: 12px; font-weight: 800; }
.lo-lightbox-bar > span { font-size: 10.5px; font-weight: 700; color: var(--lo-faint); }
.lo-lightbox-body {
  flex: 1 1 auto; min-height: 0; overflow: auto;
  display: grid; place-items: center; padding: 12px; background: rgba(15, 23, 42, 0.9);
}
.lo-lightbox-body img { max-width: 100%; max-height: calc(100vh - 190px); display: block; border-radius: 6px; }

.lo-dlg-actions {
  display: flex; align-items: center; gap: 8px; flex-wrap: wrap;
  flex: 0 0 auto;
  padding: 12px 20px 16px; border-top: 1px solid var(--lo-line-soft);
}
.lo-dlg-queue {
  display: inline-flex; align-items: center; gap: 5px;
  font-size: 10.5px; font-weight: 700; color: var(--lo-faint);
}

/* ══ Toast ══ */
.lo-notice {
  position: fixed; right: 24px; bottom: 24px; z-index: 3000;
  display: flex; align-items: center; gap: 8px;
  padding: 10px 14px; border-radius: 11px;
  background: var(--lo-surface); border: 1px solid var(--lo-line);
  box-shadow: 0 18px 40px -18px rgba(15, 23, 42, 0.5);
  font-size: 11.5px; font-weight: 700; color: rgb(var(--v-theme-on-surface));
}
.lo-notice.is-good :deep(.v-icon) { color: #10b981; }
.lo-notice.is-bad { border-color: rgba(239, 68, 68, 0.35); }
.lo-notice.is-bad :deep(.v-icon) { color: #ef4444; }
.loToast-enter-active, .loToast-leave-active { transition: opacity 0.18s ease, transform 0.18s ease; }
.loToast-enter-from, .loToast-leave-to { opacity: 0; transform: translateY(8px); }

/* ══ Dark mode tone adjustments ══ */
:global(.v-theme--dark .lo-chip.is-good),
:global(.v-theme--dark .lo-pill.is-good) { color: #34d399; border-color: rgba(52, 211, 153, 0.34); background: rgba(16, 185, 129, 0.14); }
:global(.v-theme--dark .lo-chip.is-warn),
:global(.v-theme--dark .lo-pill.is-warn) { color: #fbbf24; border-color: rgba(251, 191, 36, 0.34); background: rgba(245, 158, 11, 0.14); }
:global(.v-theme--dark .lo-chip.is-bad),
:global(.v-theme--dark .lo-pill.is-bad) { color: #f87171; border-color: rgba(248, 113, 113, 0.34); background: rgba(239, 68, 68, 0.14); }
:global(.v-theme--dark .lo-chip.is-info),
:global(.v-theme--dark .lo-pill.is-info) { color: #93c5fd; border-color: rgba(147, 197, 253, 0.32); background: rgba(37, 99, 235, 0.16); }
:global(.v-theme--dark .lo-btn.is-danger) { color: #f87171; border-color: rgba(248, 113, 113, 0.38); }
:global(.v-theme--dark .lo-link) { color: var(--lo-accent); }
:global(.v-theme--dark .lo-kpi.is-good .lo-kpi-ico),
:global(.v-theme--dark .lo-panel-ico.is-good) { color: #34d399; }
:global(.v-theme--dark .lo-kpi.is-bad .lo-kpi-ico),
:global(.v-theme--dark .lo-panel-ico.is-bad) { color: #f87171; }
:global(.v-theme--dark .lo-kpi.is-bad b) { color: #f87171; }
:global(.v-theme--dark .lo-panel-ico.is-amber) { color: #fbbf24; }
:global(.v-theme--dark .lo-panel-ico.is-indigo) { color: #a5b4fc; }
:global(.v-theme--dark .lo-panel-ico.is-info) { color: #93c5fd; }
:global(.v-theme--dark .lo-panel-ico.is-purple) { color: #d8b4fe; }
:global(.v-theme--dark .lo-foot-hint) { color: #34d399; }
:global(.v-theme--dark .lo-cancel-banner) { color: #f87171; background: rgba(239, 68, 68, 0.12); }
:global(.v-theme--dark .lo-mini-alert) { color: #f87171; background: rgba(239, 68, 68, 0.14); }
:global(.v-theme--dark .lo-invoice-rows b.is-good) { color: #34d399; }
:global(.v-theme--dark .lo-auth-sig) { border-color: rgba(148, 163, 184, 0.28); }
:global(.v-theme--dark .lo-auth-nosig) { border-color: rgba(148, 163, 184, 0.26); }
:global(.v-theme--dark .lo-invoice-rows b.is-bad) { color: #f87171; }
:global(.v-theme--dark .lo-verdict.is-good) { color: #34d399; background: rgba(16, 185, 129, 0.14); border-color: rgba(52, 211, 153, 0.34); }
:global(.v-theme--dark .lo-verdict.is-bad) { color: #f87171; background: rgba(239, 68, 68, 0.14); border-color: rgba(248, 113, 113, 0.34); }
:global(.v-theme--dark .lo-amend-note) { color: #fbbf24; background: rgba(245, 158, 11, 0.14); border-color: rgba(251, 191, 36, 0.32); }
:global(.v-theme--dark .lo-tl li.is-good .lo-tl-dot) { color: #34d399; }
:global(.v-theme--dark .lo-tl li.is-bad .lo-tl-dot) { color: #f87171; }
:global(.v-theme--dark .lo-tl li.is-info .lo-tl-dot) { color: #93c5fd; }
:global(.v-theme--dark .lo-step.is-done .lo-step-node) { color: #34d399; }
:global(.v-theme--dark .lo-head) { box-shadow: 0 1px 2px rgba(0, 0, 0, 0.45), 0 16px 34px -22px rgba(0, 0, 0, 0.9); }
:global(.v-theme--dark .lo-notice) { box-shadow: 0 18px 40px -18px rgba(0, 0, 0, 0.9); }

/* ══ Responsive ══ */
@media (max-width: 1279px) {
  .lo-dlg-grid { grid-template-columns: minmax(0, 1fr); }
}
@media (max-width: 1023px) {
  .lo-flow { flex-wrap: wrap; gap: 8px; padding-bottom: 18px; }
  .lo-step-rail { display: none; }
  .lo-step { flex: 1 1 40%; }
}
@media (max-width: 719px) {
  .lo-head { padding: 14px 15px 10px; }
  .lo-head-title { font-size: 20px; }
  .lo-head-actions { width: 100%; justify-content: flex-start; }
  .lo-kpis { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .lo-result { flex-direction: column; }
  .lo-notice { left: 16px; right: 16px; bottom: 16px; }
  .lo-attach { flex-wrap: wrap; }
  .lo-attach-acts { width: 100%; justify-content: flex-start; padding-left: 48px; }
}

/* ══ Print — a clean clinical report ══ */
@media print {
  :global(.v-app-bar),
  :global(.v-navigation-drawer),
  :global(.v-footer),
  :global(.v-overlay) { display: none !important; }
  .lo-head-actions,
  .lo-panel-tools,
  .lo-test .lo-btn,
  .lo-result-side .lo-link,
  .lo-link,
  .lo-notice,
  .lo-flow-progress { display: none !important; }
  .lo-head { box-shadow: none; border-radius: 0; padding: 0 0 10px; border: 0; border-bottom: 2px solid #0f172a; margin-bottom: 12px; }
  .lo-head::before { display: none; }
  .lo-kpis { grid-template-columns: repeat(4, minmax(0, 1fr)); }
  .lo-kpi,
  .lo-panel { box-shadow: none !important; break-inside: avoid; }
  .lo-page { padding: 0 !important; }
}
</style>
