<template>
  <v-container fluid class="pa-3 pa-md-5">
    <div class="d-flex align-center justify-space-between mb-4 ga-3 flex-wrap">
      <div class="d-flex align-center ga-3">
        <v-btn icon="mdi-arrow-left" variant="text" to="/clinics/front-desk" />
        <div>
          <div class="d-flex align-center ga-2 flex-wrap">
            <h1 class="text-h5 font-weight-bold ma-0">{{ visit?.patient_name || 'Visit' }}</h1>
            <v-chip size="small" variant="tonal" color="primary">{{ visit?.visit_number }}</v-chip>
            <v-chip size="small" variant="tonal" :color="stageColor">{{ visit?.stage_label }}</v-chip>
            <v-chip v-if="visit?.queue_number" size="small" variant="tonal" prepend-icon="mdi-ticket-confirmation">
              Queue {{ visit.queue_number }}
            </v-chip>
          </div>
          <div class="text-body-2 text-medium-emphasis">
            {{ visit?.patient_number }}
            <span v-if="visit?.patient_gender"> · {{ visit.patient_gender }}</span>
            <span v-if="age !== null"> · {{ age }} years</span>
            <span v-if="visit?.doctor_name"> · {{ visit.doctor_name }}</span>
          </div>
        </div>
      </div>
      <div class="d-flex align-center ga-2">
        <v-chip v-if="visit?.is_open" variant="tonal" :color="lateWait ? 'error' : 'warning'"
                prepend-icon="mdi-timer-sand">
          Waiting {{ visit.waiting_minutes }} min
        </v-chip>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
               :loading="loading" @click="loadAll">Refresh</v-btn>
      </div>
    </div>

    <v-alert v-if="error" type="error" variant="tonal" density="compact" rounded="lg" class="mb-4">
      {{ error }}
    </v-alert>

    <v-skeleton-loader v-if="!visit && loading" type="article" />

    <template v-else-if="visit">
      <!-- ── Journey stepper ─────────────────────────────────────── -->
      <v-card rounded="lg" variant="outlined" class="mb-4 pa-4">
        <div class="fdj-steps">
          <div v-for="(step, i) in steps" :key="step.key" class="fdj-step"
               :class="[`fdj-step--${step.state}`]">
            <div class="fdj-step__dot">
              <v-icon v-if="step.state === 'done'" size="16">mdi-check</v-icon>
              <span v-else>{{ i + 1 }}</span>
            </div>
            <div class="fdj-step__label">{{ step.label }}</div>
            <div class="fdj-step__hint">{{ step.hint }}</div>
            <div v-if="i < steps.length - 1" class="fdj-step__line" />
          </div>
        </div>
      </v-card>

      <v-row class="align-start">
        <!-- ═══════════ LEFT ═══════════ -->
        <v-col cols="12" lg="8">
          <!-- ── Action panel ─────────────────────────────────────── -->
          <v-card rounded="lg" elevation="0" class="fdj-panel mb-4">
            <div class="fdj-panel__head">
              <div class="d-flex align-center ga-2">
                <v-icon size="18" :color="stageColor">{{ stageIcon }}</v-icon>
                <span class="font-weight-bold">Next step</span>
              </div>
              <v-chip size="small" variant="tonal" :color="stageColor">{{ visit.stage_label }}</v-chip>
            </div>
            <v-divider />

            <div class="pa-4">
              <!-- REGISTERED -->
              <template v-if="visit.stage === 'registered'">
                <v-row dense>
                  <v-col cols="12" sm="5">
                    <v-text-field v-model.number="feeAmount" type="number" min="0"
                                  :prefix="settings.currency" label="Consultation fee"
                                  variant="outlined" density="comfortable" />
                  </v-col>
                  <v-col cols="12" sm="7" class="d-flex align-center ga-2 flex-wrap">
                    <v-btn color="primary" class="text-none" prepend-icon="mdi-cash-plus"
                           :loading="busy === 'charge'" @click="chargeFee">
                      Charge & send to billing
                    </v-btn>
                    <v-btn variant="tonal" color="grey-darken-1" class="text-none"
                           prepend-icon="mdi-cash-off" :loading="busy === 'waive'" @click="waiveFee">
                      Waive fee
                    </v-btn>
                  </v-col>
                </v-row>
                <div class="text-caption text-medium-emphasis mt-2">
                  Charging raises an invoice at reception. The patient can pay at reception or be
                  sent to the billing office.
                </div>
                <v-btn variant="text" class="text-none mt-1" prepend-icon="mdi-skip-next"
                       :loading="busy === 'skip'" @click="skipPayment">
                  Skip payment (exempt / pre-paid)
                </v-btn>
              </template>

              <!-- AWAITING PAYMENT -->
              <template v-else-if="visit.stage === 'awaiting_payment'">
                <v-row dense>
                  <v-col cols="12" sm="3">
                    <v-text-field v-model.number="pay.amount" type="number" min="0"
                                  :prefix="settings.currency" label="Amount"
                                  variant="outlined" density="comfortable" />
                  </v-col>
                  <v-col cols="12" sm="3">
                    <v-select v-model="pay.method" :items="paymentMethods" label="Method"
                              variant="outlined" density="comfortable" />
                  </v-col>
                  <v-col cols="12" sm="3">
                    <v-text-field v-model="pay.reference" label="Reference"
                                  variant="outlined" density="comfortable" />
                  </v-col>
                  <v-col cols="12" sm="3" class="d-flex align-center">
                    <v-btn color="success" block class="text-none" prepend-icon="mdi-cash-register"
                           :loading="busy === 'pay'" @click="collectPayment">Collect</v-btn>
                  </v-col>
                </v-row>
                <div class="d-flex align-center justify-space-between mt-3 flex-wrap ga-2">
                  <div class="text-body-2">
                    Invoice <strong>{{ visit.invoice_number || '—' }}</strong>
                    · Balance <strong>{{ formatMoney(visit.invoice_balance, settings.currency) }}</strong>
                  </div>
                  <v-btn variant="tonal" color="grey-darken-1" class="text-none" size="small"
                         prepend-icon="mdi-cash-off" :loading="busy === 'waive'" @click="waiveFee">
                    Waive fee
                  </v-btn>
                </div>
              </template>

              <!-- PAID -->
              <template v-else-if="visit.stage === 'paid'">
                <div class="d-flex align-center justify-space-between flex-wrap ga-3">
                  <div class="text-body-2">
                    Fee settled<span v-if="visit.payment_method"> via {{ visit.payment_method }}</span>.
                    Send the patient to triage for vitals.
                  </div>
                  <v-btn color="deep-orange" class="text-none" prepend-icon="mdi-heart-pulse"
                         :loading="busy === 'triage'" @click="startTriage">Send to triage</v-btn>
                </div>
              </template>

              <!-- TRIAGE -->
              <template v-else-if="visit.stage === 'triage'">
                <v-row dense>
                  <v-col cols="12" sm="4">
                    <v-select v-model="triage.esi_level" :items="esiOptions" label="ESI level"
                              variant="outlined" density="comfortable" />
                  </v-col>
                  <v-col cols="12" sm="4">
                    <v-text-field v-model="triage.chief_complaint" label="Chief complaint"
                                  variant="outlined" density="comfortable" />
                  </v-col>
                  <v-col cols="12" sm="4">
                    <v-text-field v-model.number="triage.pain_scale" type="number" min="0" max="10"
                                  label="Pain score (0–10)" variant="outlined" density="comfortable" />
                  </v-col>
                  <v-col v-for="v in vitalFields" :key="v.key" cols="6" sm="3">
                    <v-text-field v-model="triage.vital_signs[v.key]" :label="v.label"
                                  :suffix="v.unit" variant="outlined" density="comfortable" />
                  </v-col>
                  <v-col cols="12" sm="6">
                    <v-select v-model="triage.doctor" :items="doctorItems" item-title="label"
                              item-value="id" label="Assign doctor" variant="outlined" density="comfortable"
                              prepend-inner-icon="mdi-stethoscope" />
                  </v-col>
                  <v-col cols="12" sm="6">
                    <v-select v-model="triage.avpu" :items="avpuOptions" label="AVPU"
                              variant="outlined" density="comfortable" />
                  </v-col>
                  <v-col cols="12">
                    <v-textarea v-model="triage.notes" label="Nursing notes" rows="2" auto-grow
                                variant="outlined" density="comfortable" />
                  </v-col>
                </v-row>
                <div class="d-flex justify-end ga-2 mt-2">
                  <v-btn variant="text" class="text-none" @click="openTriagePage">Open full triage</v-btn>
                  <v-btn color="primary" class="text-none" prepend-icon="mdi-clipboard-check"
                         :loading="busy === 'triage-complete'" @click="completeTriage">
                    Complete triage & queue for doctor
                  </v-btn>
                </div>
              </template>

              <!-- AWAITING DOCTOR -->
              <template v-else-if="visit.stage === 'awaiting_doctor'">
                <v-row dense class="align-center">
                  <v-col cols="12" sm="6">
                    <v-select v-model="doctorId" :items="doctorItems" item-title="label" item-value="id"
                              label="Doctor" variant="outlined" density="comfortable"
                              prepend-inner-icon="mdi-stethoscope" />
                  </v-col>
                  <v-col cols="12" sm="6" class="d-flex ga-2 flex-wrap">
                    <v-btn variant="tonal" class="text-none" :loading="busy === 'assign'"
                           prepend-icon="mdi-account-check" @click="assignDoctor">Assign</v-btn>
                    <v-btn color="success" class="text-none" :loading="busy === 'consult'"
                           prepend-icon="mdi-stethoscope" @click="startConsultation">
                      Start consultation
                    </v-btn>
                  </v-col>
                </v-row>
              </template>

              <!-- IN CONSULTATION / REVIEW -->
              <template v-else-if="visit.stage === 'in_consultation' || visit.stage === 'review'">
                <div class="fdj-actions">
                  <v-btn color="purple" class="text-none" prepend-icon="mdi-flask-outline"
                         @click="openLabDialog">Order lab tests</v-btn>
                  <v-btn color="pink" class="text-none" prepend-icon="mdi-pill"
                         @click="openRxDialog">Prescribe medication</v-btn>
                  <v-btn color="green-darken-2" variant="tonal" class="text-none"
                         prepend-icon="mdi-check-decagram" @click="openDischarge">Discharge</v-btn>
                  <v-btn v-if="visit.consultation" variant="text" class="text-none"
                         prepend-icon="mdi-open-in-new"
                         :to="`/clinics/consultations/${visit.consultation}`">
                    Open encounter
                  </v-btn>
                </div>
              </template>

              <!-- IN LAB -->
              <template v-else-if="visit.stage === 'in_lab'">
                <div class="text-body-2 mb-3">
                  The laboratory is processing this patient's tests. Results can be entered here
                  when ready — the doctor is notified automatically.
                </div>
                <div class="fdj-actions">
                  <v-btn variant="tonal" class="text-none" prepend-icon="mdi-play"
                         :loading="busy === 'lab-start'" @click="labStart">Sample received / processing</v-btn>
                  <v-btn color="purple" class="text-none" prepend-icon="mdi-upload"
                         @click="openResultDialog">Enter / upload results</v-btn>
                </div>
              </template>

              <!-- LAB READY -->
              <template v-else-if="visit.stage === 'lab_ready'">
                <div class="d-flex align-center justify-space-between flex-wrap ga-3">
                  <div class="text-body-2">Lab results are in. The doctor should review them.</div>
                  <div class="d-flex ga-2 flex-wrap">
                    <v-btn color="blue" class="text-none" prepend-icon="mdi-clipboard-search-outline"
                           :loading="busy === 'review'" @click="startReview">Start review</v-btn>
                    <v-btn color="pink" variant="tonal" class="text-none" prepend-icon="mdi-pill"
                           @click="openRxDialog">Prescribe</v-btn>
                    <v-btn color="green-darken-2" variant="tonal" class="text-none"
                           prepend-icon="mdi-check-decagram" @click="openDischarge">Discharge</v-btn>
                  </div>
                </div>
              </template>

              <!-- PRESCRIBED -->
              <template v-else-if="visit.stage === 'prescribed'">
                <div class="d-flex align-center justify-space-between flex-wrap ga-3">
                  <div class="text-body-2">
                    Prescription issued. Send it to the pharmacy or discharge the patient.
                  </div>
                  <div class="d-flex ga-2 flex-wrap">
                    <v-btn color="pink" variant="tonal" class="text-none" prepend-icon="mdi-pill-multiple"
                           :loading="busy === 'pharmacy'" @click="sendToPharmacy">Send to pharmacy</v-btn>
                    <v-btn color="green-darken-2" class="text-none" prepend-icon="mdi-check-decagram"
                           @click="openDischarge">Discharge</v-btn>
                  </div>
                </div>
              </template>

              <!-- DISCHARGED -->
              <template v-else-if="visit.stage === 'discharged'">
                <div class="d-flex align-center justify-space-between flex-wrap ga-2">
                  <div>
                    <div class="font-weight-bold">Visit closed — {{ visit.outcome_label || 'Discharged' }}</div>
                    <div class="text-body-2 text-medium-emphasis">
                      {{ visit.discharge_summary || 'No discharge summary recorded.' }}
                    </div>
                    <div v-if="visit.follow_up_date" class="text-caption text-medium-emphasis mt-1">
                      Follow-up: {{ formatDate(visit.follow_up_date) }}
                    </div>
                  </div>
                  <v-btn variant="outlined" class="text-none" prepend-icon="mdi-printer"
                         @click="printSummary">Print summary</v-btn>
                </div>
              </template>

              <!-- CANCELLED -->
              <template v-else-if="visit.stage === 'cancelled'">
                <div class="text-body-2 text-medium-emphasis">This visit was cancelled.</div>
              </template>

              <!-- ARRIVED -->
              <template v-else>
                <div class="d-flex align-center justify-space-between flex-wrap ga-3">
                  <div class="text-body-2">Patient has arrived — confirm registration to continue.</div>
                  <v-btn color="primary" class="text-none" prepend-icon="mdi-account-check"
                         :loading="busy === 'register'" @click="completeRegistration">Confirm registration</v-btn>
                </div>
              </template>
            </div>
          </v-card>

          <!-- ── Clinical summary ─────────────────────────────────── -->
          <v-card v-if="triage && (triage.vital_signs || triage.esi_level)" rounded="lg" variant="outlined" class="mb-4">
            <div class="fdj-panel__head">
              <div class="d-flex align-center ga-2">
                <v-icon size="18" color="deep-orange">mdi-heart-pulse</v-icon>
                <span class="font-weight-bold">Triage &amp; vitals</span>
              </div>
              <v-chip v-if="visit.triage_esi" size="small" variant="tonal" :color="esiColor(visit.triage_esi)">
                ESI {{ visit.triage_esi }}
              </v-chip>
            </div>
            <v-divider />
            <div class="pa-4">
              <v-row dense>
                <v-col v-for="v in triageVitals" :key="v.label" cols="6" sm="3">
                  <div class="fdj-metric">
                    <div class="fdj-metric__label">{{ v.label }}</div>
                    <div class="fdj-metric__value">{{ v.value || '—' }}<span class="fdj-metric__unit">{{ v.unit }}</span></div>
                  </div>
                </v-col>
              </v-row>
              <div v-if="visit.chief_complaint" class="text-body-2 mt-3">
                <strong>Complaint:</strong> {{ visit.chief_complaint }}
              </div>
            </div>
          </v-card>

          <!-- ── Lab orders & results ─────────────────────────────── -->
          <v-card v-if="visit.lab_orders?.length" rounded="lg" variant="outlined" class="mb-4">
            <div class="fdj-panel__head">
              <div class="d-flex align-center ga-2">
                <v-icon size="18" color="purple">mdi-flask-outline</v-icon>
                <span class="font-weight-bold">Laboratory</span>
              </div>
              <v-btn v-if="visit.lab_report_url" size="small" variant="text" class="text-none"
                     prepend-icon="mdi-file-download" :href="visit.lab_report_url" target="_blank">
                Report file
              </v-btn>
            </div>
            <v-divider />
            <div class="pa-4">
              <div v-for="order in visit.lab_orders" :key="order.id" class="mb-3">
                <div class="d-flex align-center justify-between flex-wrap ga-2 mb-1">
                  <div class="font-weight-medium">
                    Order #{{ order.id }} · {{ (order.test_names || []).join(', ') }}
                  </div>
                  <div class="d-flex ga-1">
                    <v-chip size="x-small" variant="tonal" :color="order.status === 'completed' ? 'success' : 'warning'">
                      {{ order.status }}
                    </v-chip>
                    <v-chip size="x-small" variant="tonal" :color="order.priority === 'stat' ? 'error' : 'grey'">
                      {{ order.priority }}
                    </v-chip>
                  </div>
                </div>
                <v-table v-if="order.results?.length" density="compact" class="fdj-table">
                  <thead>
                    <tr><th>Test</th><th>Result</th><th>Unit</th><th>Flag</th></tr>
                  </thead>
                  <tbody>
                    <tr v-for="r in order.results" :key="r.id">
                      <td>{{ r.test_name }}</td>
                      <td class="font-weight-medium">{{ r.result_value }}</td>
                      <td>{{ r.unit || '—' }}</td>
                      <td>
                        <v-chip v-if="r.is_abnormal" size="x-small" color="error" variant="tonal">Abnormal</v-chip>
                        <span v-else class="text-caption text-medium-emphasis">Normal</span>
                      </td>
                    </tr>
                  </tbody>
                </v-table>
                <div v-else class="text-caption text-medium-emphasis">No results captured yet.</div>
              </div>
            </div>
          </v-card>

          <!-- ── Prescriptions ────────────────────────────────────── -->
          <v-card v-if="visit.prescriptions?.length" rounded="lg" variant="outlined" class="mb-4">
            <div class="fdj-panel__head">
              <div class="d-flex align-center ga-2">
                <v-icon size="18" color="pink">mdi-pill</v-icon>
                <span class="font-weight-bold">Prescriptions</span>
              </div>
            </div>
            <v-divider />
            <div class="pa-4">
              <div v-for="rx in visit.prescriptions" :key="rx.id" class="mb-3">
                <div class="d-flex align-center justify-between flex-wrap ga-2">
                  <div class="font-weight-medium">Rx #{{ rx.id }} · {{ rx.doctor_name }}</div>
                  <v-chip size="x-small" variant="tonal" color="pink">{{ rx.status }}</v-chip>
                </div>
                <v-table density="compact" class="fdj-table mt-1">
                  <thead>
                    <tr><th>Medication</th><th>Dosage</th><th>Frequency</th><th>Duration</th><th>Qty</th></tr>
                  </thead>
                  <tbody>
                    <tr v-for="item in rx.items" :key="item.id">
                      <td>{{ item.medication_name || item.custom_medication_name }}</td>
                      <td>{{ item.dosage || '—' }}</td>
                      <td>{{ item.frequency || '—' }}</td>
                      <td>{{ item.duration || '—' }}</td>
                      <td>{{ item.quantity }}</td>
                    </tr>
                  </tbody>
                </v-table>
              </div>
            </div>
          </v-card>

          <!-- ── Payment ──────────────────────────────────────────── -->
          <v-card rounded="lg" variant="outlined" class="mb-4">
            <div class="fdj-panel__head">
              <div class="d-flex align-center ga-2">
                <v-icon size="18" color="green-darken-2">mdi-cash-multiple</v-icon>
                <span class="font-weight-bold">Billing</span>
              </div>
              <v-chip size="small" variant="tonal" :color="paymentColor">{{ visit.payment_status_label }}</v-chip>
            </div>
            <v-divider />
            <div class="pa-4">
              <v-row dense>
                <v-col cols="6" sm="3">
                  <div class="fdj-metric">
                    <div class="fdj-metric__label">Fee</div>
                    <div class="fdj-metric__value">{{ formatMoney(visit.consultation_fee, settings.currency) }}</div>
                  </div>
                </v-col>
                <v-col cols="6" sm="3">
                  <div class="fdj-metric">
                    <div class="fdj-metric__label">Invoiced</div>
                    <div class="fdj-metric__value">{{ formatMoney(visit.invoice_total, settings.currency) }}</div>
                  </div>
                </v-col>
                <v-col cols="6" sm="3">
                  <div class="fdj-metric">
                    <div class="fdj-metric__label">Balance</div>
                    <div class="fdj-metric__value">{{ formatMoney(visit.invoice_balance, settings.currency) }}</div>
                  </div>
                </v-col>
                <v-col cols="6" sm="3">
                  <div class="fdj-metric">
                    <div class="fdj-metric__label">Invoice</div>
                    <div class="fdj-metric__value text-body-2">{{ visit.invoice_number || '—' }}</div>
                  </div>
                </v-col>
              </v-row>
              <v-btn v-if="visit.invoice" variant="text" class="text-none mt-2" size="small"
                     prepend-icon="mdi-receipt-text-outline"
                     :to="`/clinics/invoices/${visit.invoice}`">
                Open invoice
              </v-btn>
            </div>
          </v-card>
        </v-col>

        <!-- ═══════════ RIGHT: patient + timeline ═══════════ -->
        <v-col cols="12" lg="4">
          <v-card rounded="lg" variant="outlined" class="mb-4">
            <div class="fdj-panel__head">
              <div class="d-flex align-center ga-2">
                <v-icon size="18" color="primary">mdi-account-circle</v-icon>
                <span class="font-weight-bold">Patient</span>
              </div>
              <v-btn size="small" variant="text" class="text-none" prepend-icon="mdi-open-in-new"
                     :to="`/clinics/patients/${visit.patient}`">Profile</v-btn>
            </div>
            <v-divider />
            <div class="pa-4">
              <div class="fdj-row"><span>Phone</span><strong>{{ visit.patient_phone || '—' }}</strong></div>
              <div class="fdj-row"><span>Patient no.</span><strong>{{ visit.patient_number }}</strong></div>
              <div class="fdj-row"><span>AdhereMed ID</span><strong>{{ visit.patient_id_code || '—' }}</strong></div>
              <div class="fdj-row"><span>Date of birth</span><strong>{{ formatDate(visit.patient_dob) }}</strong></div>
              <div v-if="visit.patient_allergies?.length" class="mt-3">
                <div class="text-caption text-medium-emphasis mb-1">Allergies</div>
                <div class="d-flex flex-wrap ga-1">
                  <v-chip v-for="a in visit.patient_allergies" :key="a" size="x-small" color="error" variant="tonal">
                    {{ a }}
                  </v-chip>
                </div>
              </div>
            </div>
          </v-card>

          <v-card rounded="lg" variant="outlined">
            <div class="fdj-panel__head">
              <div class="d-flex align-center ga-2">
                <v-icon size="18" color="blue-grey">mdi-timeline-clock-outline</v-icon>
                <span class="font-weight-bold">Journey timeline</span>
              </div>
            </div>
            <v-divider />
            <div class="pa-4">
              <div v-for="(ev, i) in visit.events" :key="ev.id" class="fdj-event">
                <div class="fdj-event__dot" />
                <div v-if="i < visit.events.length - 1" class="fdj-event__line" />
                <div class="fdj-event__body">
                  <div class="fdj-event__title">{{ ev.action_label || ev.action }}</div>
                  <div v-if="ev.note" class="fdj-event__note">{{ ev.note }}</div>
                  <div class="fdj-event__meta">
                    {{ ev.stage_label }} · {{ formatStamp(ev.created_at) }}<span v-if="ev.actor_name"> · {{ ev.actor_name }}</span>
                  </div>
                </div>
              </div>
              <div v-if="!visit.events?.length" class="text-caption text-medium-emphasis">
                No activity recorded yet.
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>
    </template>

    <!-- ═══════════ Lab order dialog ═══════════ -->
    <v-dialog v-model="labDialog" max-width="640">
      <v-card rounded="lg">
        <BrandDialogHeader icon="mdi-flask-outline" title="Order lab tests" @close="labDialog = false" />
        <div class="pa-4">
          <v-autocomplete v-model="labForm.test_ids" v-model:search="labSearch" :items="labItems"
                          :loading="labLoading" item-title="label" item-value="id" label="Tests"
                          variant="outlined" density="comfortable" multiple chips closable-chips
                          prepend-inner-icon="mdi-flask-outline" no-data-text="No test found"
                          @update:search="onLabSearch" />
          <v-row dense class="mt-2">
            <v-col cols="12" sm="6">
              <v-select v-model="labForm.priority" :items="labPriorities" label="Priority"
                        variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" sm="6" class="d-flex align-center">
              <v-checkbox v-model="labForm.add_to_invoice" density="compact" hide-details
                          label="Add test prices to invoice" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="labForm.clinical_notes" label="Clinical notes" rows="2" auto-grow
                          variant="outlined" density="comfortable" />
            </v-col>
          </v-row>
          <v-alert v-if="dialogError" type="error" variant="tonal" density="compact" class="mt-2">
            {{ dialogError }}
          </v-alert>
        </div>
        <v-divider />
        <div class="d-flex justify-end ga-2 pa-4">
          <v-btn variant="text" class="text-none" @click="labDialog = false">Cancel</v-btn>
          <v-btn color="purple" class="text-none" :loading="busy === 'order-lab'" @click="submitLabOrder">
            Send to lab
          </v-btn>
        </div>
      </v-card>
    </v-dialog>

    <!-- ═══════════ Lab results dialog ═══════════ -->
    <v-dialog v-model="resultDialog" max-width="720">
      <v-card rounded="lg">
        <BrandDialogHeader icon="mdi-clipboard-pulse" title="Lab results" @close="resultDialog = false" />
        <div class="pa-4">
          <div v-for="test in resultTests" :key="test.id" class="mb-3">
            <div class="font-weight-medium mb-1">{{ test.label }}</div>
            <div class="d-flex ga-2 flex-wrap">
              <v-text-field v-model="resultForm[test.id].result_value" label="Result"
                            variant="outlined" density="compact" hide-details style="max-width: 200px" />
              <v-text-field v-model="resultForm[test.id].unit" label="Unit"
                            variant="outlined" density="compact" hide-details style="max-width: 140px" />
              <v-checkbox v-model="resultForm[test.id].is_abnormal" density="compact" hide-details
                          label="Abnormal" />
            </div>
            <v-text-field v-model="resultForm[test.id].comments" label="Comment"
                          variant="outlined" density="compact" hide-details class="mt-2" />
          </div>
          <v-file-input v-model="resultFile" label="Attach report (PDF / image)"
                        accept=".pdf,image/*" variant="outlined" density="comfortable"
                        prepend-icon="mdi-paperclip" class="mt-3" />
          <v-alert v-if="dialogError" type="error" variant="tonal" density="compact" class="mt-2">
            {{ dialogError }}
          </v-alert>
        </div>
        <v-divider />
        <div class="d-flex justify-end ga-2 pa-4">
          <v-btn variant="text" class="text-none" @click="resultDialog = false">Cancel</v-btn>
          <v-btn color="purple" class="text-none" :loading="busy === 'lab-complete'"
                 @click="submitLabResults">Complete & notify doctor</v-btn>
        </div>
      </v-card>
    </v-dialog>

    <!-- ═══════════ Prescription dialog ═══════════ -->
    <v-dialog v-model="rxDialog" max-width="820">
      <v-card rounded="lg">
        <BrandDialogHeader icon="mdi-pill-plus" title="Prescribe medication" @close="rxDialog = false" />
        <div class="pa-4">
          <div v-for="(item, i) in rxForm.items" :key="i" class="fdj-rx-row">
            <v-text-field v-model="item.medication_name" label="Medication" variant="outlined"
                          density="compact" hide-details />
            <v-text-field v-model="item.dosage" label="Dosage" placeholder="500 mg"
                          variant="outlined" density="compact" hide-details />
            <v-text-field v-model="item.frequency" label="Frequency" placeholder="3× daily"
                          variant="outlined" density="compact" hide-details />
            <v-text-field v-model="item.duration" label="Duration" placeholder="7 days"
                          variant="outlined" density="compact" hide-details />
            <v-text-field v-model.number="item.quantity" type="number" min="1" label="Qty"
                          variant="outlined" density="compact" hide-details />
            <v-btn icon="mdi-delete-outline" variant="text" size="small" color="error"
                   @click="rxForm.items.splice(i, 1)" />
          </div>
          <v-btn variant="tonal" class="text-none mt-2" prepend-icon="mdi-plus"
                 @click="addRxItem">Add medication</v-btn>
          <v-textarea v-model="rxForm.notes" label="Notes to pharmacist" rows="2" auto-grow
                      variant="outlined" density="comfortable" class="mt-3" />
          <v-alert v-if="dialogError" type="error" variant="tonal" density="compact" class="mt-2">
            {{ dialogError }}
          </v-alert>
        </div>
        <v-divider />
        <div class="d-flex justify-end ga-2 pa-4">
          <v-btn variant="text" class="text-none" @click="rxDialog = false">Cancel</v-btn>
          <v-btn color="pink" class="text-none" :loading="busy === 'prescribe'" @click="submitPrescription">
            Issue prescription
          </v-btn>
        </div>
      </v-card>
    </v-dialog>

    <!-- ═══════════ Discharge dialog ═══════════ -->
    <v-dialog v-model="dischargeDialog" max-width="620">
      <v-card rounded="lg">
        <BrandDialogHeader icon="mdi-door-open" title="Discharge patient" @close="dischargeDialog = false" />
        <div class="pa-4">
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-select v-model="dischargeForm.outcome" :items="outcomeOptions"
                        label="Outcome" variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="dischargeForm.follow_up_date" type="date" label="Follow-up date"
                            variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="dischargeForm.discharge_summary" label="Discharge summary"
                          rows="3" auto-grow variant="outlined" density="comfortable" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="dischargeForm.treatment_plan" label="Treatment plan / advice"
                          rows="2" auto-grow variant="outlined" density="comfortable" />
            </v-col>
          </v-row>
          <v-alert v-if="dialogError" type="error" variant="tonal" density="compact" class="mt-2">
            {{ dialogError }}
          </v-alert>
        </div>
        <v-divider />
        <div class="d-flex justify-end ga-2 pa-4">
          <v-btn variant="text" class="text-none" @click="dischargeDialog = false">Cancel</v-btn>
          <v-btn color="green-darken-2" class="text-none" :loading="busy === 'discharge'"
                 @click="submitDischarge">Discharge</v-btn>
        </div>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3500">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { useRoute } from '#app'
import { formatDate, formatMoney, formatStamp } from '~/utils/format'

const route = useRoute()
const { $api } = useNuxtApp()

const visitId = computed(() => route.params.id)
const loading = ref(false)
const error = ref('')
const busy = ref('')
const visit = ref(null)
const settings = ref({ consultation_fee: 0, currency: 'KES' })

const snack = reactive({ show: false, color: 'success', text: '' })
function notify(text, color = 'success') {
  Object.assign(snack, { show: true, color, text })
}

const age = computed(() => {
  if (!visit.value?.patient_dob) return null
  const dob = new Date(visit.value.patient_dob)
  if (isNaN(dob)) return null
  return Math.floor((Date.now() - dob.getTime()) / 31557600000)
})
const lateWait = computed(() => (visit.value?.waiting_minutes || 0) >= 30)

// ── Stage presentation ───────────────────────────────────────────────
const STAGE_STYLE = {
  arrived: { icon: 'mdi-door-open', color: 'blue-grey' },
  registered: { icon: 'mdi-account-check', color: 'indigo' },
  awaiting_payment: { icon: 'mdi-cash-clock', color: 'orange-darken-2' },
  paid: { icon: 'mdi-cash-check', color: 'teal' },
  triage: { icon: 'mdi-heart-pulse', color: 'deep-orange' },
  awaiting_doctor: { icon: 'mdi-clock-alert-outline', color: 'amber-darken-3' },
  in_consultation: { icon: 'mdi-stethoscope', color: 'green-darken-1' },
  in_lab: { icon: 'mdi-flask-outline', color: 'purple' },
  lab_ready: { icon: 'mdi-file-check-outline', color: 'purple-darken-1' },
  review: { icon: 'mdi-clipboard-search-outline', color: 'blue' },
  prescribed: { icon: 'mdi-pill', color: 'pink' },
  discharged: { icon: 'mdi-check-decagram', color: 'green-darken-2' },
  cancelled: { icon: 'mdi-cancel', color: 'grey' }
}
const stageColor = computed(() => STAGE_STYLE[visit.value?.stage]?.color || 'grey')
const stageIcon = computed(() => STAGE_STYLE[visit.value?.stage]?.icon || 'mdi-circle-outline')
const paymentColor = computed(() => ({
  unpaid: 'orange-darken-2', partial: 'amber-darken-3', paid: 'green-darken-2', waived: 'grey'
}[visit.value?.payment_status] || 'grey'))

const STEPS = [
  { key: 'register', label: 'Reception', hint: 'Arrival & registration', at: 'registered_at' },
  { key: 'billing', label: 'Billing', hint: 'Consultation fee', at: 'paid_at' },
  { key: 'triage', label: 'Triage', hint: 'Vitals & ESI', at: 'triage_completed_at' },
  { key: 'doctor', label: 'Doctor', hint: 'Assignment', at: 'doctor_assigned_at' },
  { key: 'assess', label: 'Assessment', hint: 'Clinical review', at: 'consultation_started_at' },
  { key: 'lab', label: 'Laboratory', hint: 'Tests & samples', at: 'lab_completed_at' },
  { key: 'results', label: 'Results', hint: 'Doctor review', at: 'review_started_at' },
  { key: 'rx', label: 'Prescription', hint: 'Medication', at: 'prescribed_at' },
  { key: 'discharge', label: 'Discharge', hint: 'Visit closed', at: 'discharged_at' }
]

const steps = computed(() => {
  const v = visit.value || {}
  return STEPS.map((s, i) => {
    let state = 'todo'
    if (v[s.at]) state = 'done'
    if (s.key === 'register' && v.stage === 'registered') state = 'current'
    if (s.key === 'billing' && ['awaiting_payment'].includes(v.stage)) state = 'current'
    if (s.key === 'triage' && v.stage === 'triage') state = 'current'
    if (s.key === 'doctor' && v.stage === 'awaiting_doctor') state = 'current'
    if (s.key === 'assess' && v.stage === 'in_consultation') state = 'current'
    if (s.key === 'lab' && v.stage === 'in_lab') state = 'current'
    if (s.key === 'results' && ['lab_ready', 'review'].includes(v.stage)) state = 'current'
    if (s.key === 'discharge' && v.stage === 'prescribed') state = 'current'
    if (v.stage === 'discharged') { state = 'done' }
    if (v.stage === 'cancelled') { state = 'todo' }
    if (state === 'todo' && v[s.at]) state = 'done'
    // A doctor may prescribe straight from the results screen without an
    // explicit review step — treat that as results reviewed.
    if (s.key === 'results' && v.prescribed_at) state = 'done'
    return { ...s, state, index: i }
  })
})

// ── Vitals ───────────────────────────────────────────────────────────
const vitalFields = [
  { key: 'bp', label: 'Blood pressure', unit: 'mmHg' },
  { key: 'temp', label: 'Temperature', unit: '°C' },
  { key: 'pulse', label: 'Pulse', unit: 'bpm' },
  { key: 'resp_rate', label: 'Resp. rate', unit: '/min' },
  { key: 'spo2', label: 'SpO₂', unit: '%' },
  { key: 'weight', label: 'Weight', unit: 'kg' },
  { key: 'height', label: 'Height', unit: 'cm' },
  { key: 'blood_sugar', label: 'Blood sugar', unit: 'mmol/L' }
]
const triage = reactive({
  esi_level: null, chief_complaint: '', pain_scale: 0, avpu: 'alert',
  doctor: null, notes: '', vital_signs: {}
})
const triageVitals = computed(() =>
  vitalFields
    .map(f => ({ label: f.label, unit: f.unit, value: visit.value?.triage_vitals?.[f.key] }))
    .filter(v => v.value !== undefined && v.value !== null && v.value !== '')
)

function esiColor(level) {
  if (level <= 2) return 'red-darken-2'
  if (level === 3) return 'orange-darken-2'
  return 'green-darken-1'
}
const esiOptions = [
  { title: '1 · Resuscitation', value: 1 },
  { title: '2 · Emergent', value: 2 },
  { title: '3 · Urgent', value: 3 },
  { title: '4 · Less urgent', value: 4 },
  { title: '5 · Non-urgent', value: 5 }
]
const avpuOptions = [
  { title: 'Alert', value: 'alert' },
  { title: 'Responds to voice', value: 'voice' },
  { title: 'Responds to pain', value: 'pain' },
  { title: 'Unresponsive', value: 'unresponsive' }
]
const paymentMethods = [
  { title: 'Cash', value: 'cash' },
  { title: 'Card', value: 'card' },
  { title: 'M-Pesa', value: 'mpesa' },
  { title: 'Insurance', value: 'insurance' },
  { title: 'Bank transfer', value: 'bank_transfer' }
]
const outcomeOptions = [
  { title: 'Discharged home', value: 'discharged' },
  { title: 'Referred', value: 'referred' },
  { title: 'Admitted', value: 'admitted' },
  { title: 'Observation', value: 'observation' },
  { title: 'Left against advice', value: 'left_ama' },
  { title: 'Deceased', value: 'deceased' }
]

const feeAmount = ref(0)
const pay = reactive({ amount: 0, method: 'cash', reference: '' })
const doctorId = ref(null)
const doctors = ref([])
const doctorItems = computed(() =>
  doctors.value.map(d => ({ id: d.id, label: `${d.full_name}${d.role ? ` · ${d.role.replace('_', ' ')}` : ''}` }))
)

// ── Load ─────────────────────────────────────────────────────────────
async function loadVisit() {
  const { data } = await $api.get(`/visits/${visitId.value}/`)
  visit.value = data
  settings.value = {
    ...settings.value,
    consultation_fee: Number(data.consultation_fee || settings.value.consultation_fee || 0),
  }
  feeAmount.value = Number(data.consultation_fee || 0)
  pay.amount = Number(data.invoice_balance ?? data.consultation_fee ?? 0)
  doctorId.value = data.doctor || null
  if (data.triage_vitals) Object.assign(triage.vital_signs, data.triage_vitals)
  triage.chief_complaint = data.chief_complaint || ''
  return data
}

async function loadSettings() {
  try {
    const { data } = await $api.get('/visits/settings/')
    settings.value = { ...settings.value, ...data }
  } catch { /* non-fatal */ }
}

async function loadDoctors() {
  try {
    const { data } = await $api.get('/auth/staff/', {
      params: { roles: 'doctor,clinical_officer,dentist', page_size: 500 }
    })
    doctors.value = data?.results || data || []
  } catch { doctors.value = [] }
}

async function loadAll() {
  loading.value = true
  error.value = ''
  try {
    await Promise.all([loadVisit(), loadSettings(), loadDoctors()])
  } catch (e) {
    error.value = extractError(e)
  } finally {
    loading.value = false
  }
}

onMounted(loadAll)

// ── Actions ──────────────────────────────────────────────────────────
async function call(path, payload = {}) {
  busy.value = path
  error.value = ''
  try {
    const { data } = await $api.post(`/visits/${visitId.value}/${path}/`, payload)
    visit.value = data
    notify('Done')
    return data
  } catch (e) {
    error.value = extractError(e)
    notify(extractError(e), 'error')
    return null
  } finally {
    busy.value = ''
  }
}

async function completeRegistration() {
  await call('register', {})
}

async function chargeFee() {
  const data = await call('charge-fee', { amount: feeAmount.value })
  if (data) pay.amount = Number(data.invoice_balance ?? feeAmount.value)
}

async function waiveFee() {
  const reason = window.prompt('Reason for waiving the fee?', 'Waived at reception')
  if (reason === null) return
  await call('waive-fee', { reason })
}

async function skipPayment() {
  await call('skip-payment', { reason: 'Pre-paid / exempt' })
}

async function collectPayment() {
  await call('collect-payment', {
    amount: pay.amount, method: pay.method, reference: pay.reference
  })
}

async function startTriage() {
  await call('start-triage', {})
}

async function completeTriage() {
  await call('complete-triage', {
    esi_level: triage.esi_level,
    chief_complaint: triage.chief_complaint,
    pain_scale: triage.pain_scale,
    avpu: triage.avpu,
    notes: triage.notes,
    vital_signs: triage.vital_signs,
    doctor: triage.doctor || doctorId.value || null
  })
}

async function assignDoctor() {
  if (!doctorId.value) { notify('Select a doctor first', 'warning'); return }
  await call('assign-doctor', { doctor: doctorId.value })
}

async function startConsultation() {
  if (doctorId.value && doctorId.value !== visit.value?.doctor) {
    await call('assign-doctor', { doctor: doctorId.value })
  }
  await call('start-consultation', {})
}

async function startReview() {
  await call('start-review', {})
}

async function sendToPharmacy() {
  await call('send-to-pharmacy', {})
}

function openTriagePage() {
  if (visit.value?.triage) navigateTo(`/clinics/triage/workspace/${visit.value.triage}`)
  else navigateTo('/clinics/triage')
}

// ── Lab ──────────────────────────────────────────────────────────────
const labDialog = ref(false)
const labLoading = ref(false)
const labSearch = ref('')
const labItems = ref([])
const labForm = reactive({ test_ids: [], priority: 'routine', clinical_notes: '', add_to_invoice: false })
const labPriorities = [
  { title: 'Routine', value: 'routine' },
  { title: 'Urgent', value: 'urgent' },
  { title: 'STAT', value: 'stat' }
]

async function loadLabCatalog(q = '') {
  labLoading.value = true
  try {
    const { data } = await $api.get('/lab/catalog/', {
      params: { search: q || undefined, page_size: 100, is_active: true }
    })
    const rows = data?.results || data || []
    labItems.value = rows.map(t => ({
      id: t.id,
      label: `${t.name}${t.code ? ` (${t.code})` : ''}${Number(t.price) ? ` · ${formatMoney(t.price, settings.value.currency)}` : ''}`
    }))
  } catch {
    labItems.value = []
  } finally {
    labLoading.value = false
  }
}

function openLabDialog() {
  dialogError.value = ''
  labForm.test_ids = []
  labForm.priority = 'routine'
  labForm.clinical_notes = ''
  labForm.add_to_invoice = !!settings.value.auto_invoice_lab_tests
  labDialog.value = true
  if (!labItems.value.length) loadLabCatalog()
}

let labTimer = null
function onLabSearch(q) {
  clearTimeout(labTimer)
  labTimer = setTimeout(() => loadLabCatalog(q), 300)
}

async function submitLabOrder() {
  dialogError.value = ''
  if (!labForm.test_ids.length) { dialogError.value = 'Select at least one test.'; return }
  const data = await call('order-lab', {
    test_ids: labForm.test_ids,
    priority: labForm.priority,
    clinical_notes: labForm.clinical_notes,
    add_to_invoice: labForm.add_to_invoice
  })
  if (data) labDialog.value = false
}

// ── Lab results ──────────────────────────────────────────────────────
const resultDialog = ref(false)
const resultFile = ref(null)
const resultForm = reactive({})
const resultTests = computed(() => {
  const order = visit.value?.lab_orders?.[0]
  if (!order) return []
  const tests = order.tests || []
  return tests.map(t => ({ id: t, label: (order.test_names || [])[tests.indexOf(t)] || `Test ${t}` }))
})

function openResultDialog() {
  dialogError.value = ''
  const order = visit.value?.lab_orders?.[0]
  Object.keys(resultForm).forEach(k => delete resultForm[k])
  const ids = order?.tests || []
  ids.forEach(id => {
    resultForm[id] = { result_value: '', unit: '', is_abnormal: false, comments: '' }
  })
  resultFile.value = null
  resultDialog.value = true
}

async function submitLabResults() {
  dialogError.value = ''
  busy.value = 'lab-complete'
  try {
    const rows = Object.entries(resultForm).map(([test, r]) => ({ test: Number(test), ...r }))
    const fd = new FormData()
    fd.append('results', JSON.stringify(rows))
    const file = Array.isArray(resultFile.value) ? resultFile.value[0] : resultFile.value
    if (file) fd.append('lab_report', file)
    const { data } = await $api.post(`/visits/${visitId.value}/lab-complete/`, fd, {
      headers: { 'Content-Type': 'multipart/form-data' }
    })
    visit.value = data
    resultDialog.value = false
    notify('Lab results saved — doctor notified')
  } catch (e) {
    dialogError.value = extractError(e)
  } finally {
    busy.value = ''
  }
}

async function labStart() {
  await call('lab-start', { status: 'processing' })
}

// ── Prescription ─────────────────────────────────────────────────────
const rxDialog = ref(false)
const rxForm = reactive({ items: [], notes: '' })

function addRxItem() {
  rxForm.items.push({
    medication_name: '', dosage: '', frequency: '', duration: '',
    quantity: 1, instructions: '', is_custom: false
  })
}

function openRxDialog() {
  dialogError.value = ''
  rxForm.items = []
  rxForm.notes = ''
  addRxItem()
  rxDialog.value = true
}

async function submitPrescription() {
  dialogError.value = ''
  const items = rxForm.items.filter(i => i.medication_name?.trim())
  if (!items.length) { dialogError.value = 'Add at least one medication.'; return }
  const data = await call('prescribe', { items, notes: rxForm.notes })
  if (data) rxDialog.value = false
}

// ── Discharge ────────────────────────────────────────────────────────
const dischargeDialog = ref(false)
const dischargeForm = reactive({
  outcome: 'discharged', discharge_summary: '', treatment_plan: '', follow_up_date: ''
})

function openDischarge() {
  dialogError.value = ''
  dischargeForm.outcome = 'discharged'
  dischargeForm.discharge_summary = ''
  dischargeForm.treatment_plan = ''
  dischargeForm.follow_up_date = ''
  dischargeDialog.value = true
}

async function submitDischarge() {
  dialogError.value = ''
  const data = await call('discharge', {
    outcome: dischargeForm.outcome,
    discharge_summary: dischargeForm.discharge_summary,
    treatment_plan: dischargeForm.treatment_plan,
    follow_up_date: dischargeForm.follow_up_date || null
  })
  if (data) dischargeDialog.value = false
}

function printSummary() {
  if (!import.meta.client) return
  window.print()
}

// ── Errors ───────────────────────────────────────────────────────────
const dialogError = ref('')
function extractError(e) {
  const d = e?.response?.data
  if (!d) return e?.message || 'Something went wrong'
  if (typeof d === 'string') return d
  if (d.detail) return d.detail
  return Object.entries(d).map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(' ') : v}`).join(' · ')
}
</script>

<style scoped>
.fdj-panel { border: 1px solid rgba(var(--v-theme-on-surface), 0.08); }
.fdj-panel__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 16px;
}
.fdj-actions { display: flex; flex-wrap: wrap; gap: 8px; }

/* Stepper */
.fdj-steps {
  display: flex;
  align-items: flex-start;
  gap: 0;
  overflow-x: auto;
  padding-bottom: 4px;
}
.fdj-step {
  position: relative;
  flex: 1 1 0;
  min-width: 92px;
  text-align: center;
  padding: 0 4px;
}
.fdj-step__dot {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  margin: 0 auto 6px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.75rem;
  font-weight: 700;
  background: rgba(var(--v-theme-on-surface), 0.08);
  color: rgba(var(--v-theme-on-surface), 0.6);
}
.fdj-step--done .fdj-step__dot { background: #16a34a; color: #fff; }
.fdj-step--current .fdj-step__dot {
  background: rgb(var(--v-theme-primary));
  color: #fff;
  box-shadow: 0 0 0 4px rgba(var(--v-theme-primary), 0.18);
}
.fdj-step__label { font-size: 0.72rem; font-weight: 700; }
.fdj-step__hint { font-size: 0.62rem; color: rgba(var(--v-theme-on-surface), 0.5); }
.fdj-step__line {
  position: absolute;
  top: 14px;
  left: 50%;
  width: 100%;
  height: 2px;
  background: rgba(var(--v-theme-on-surface), 0.1);
  z-index: -1;
}
.fdj-step--done .fdj-step__line { background: #16a34a; }

/* Metrics */
.fdj-metric__label {
  font-size: 0.65rem;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.fdj-metric__value { font-size: 1rem; font-weight: 700; }
.fdj-metric__unit { font-size: 0.7rem; font-weight: 400; margin-left: 2px; }

/* Rows */
.fdj-row {
  display: flex;
  justify-content: space-between;
  gap: 10px;
  font-size: 0.8rem;
  padding: 4px 0;
  border-bottom: 1px dashed rgba(var(--v-theme-on-surface), 0.08);
}
.fdj-row span { color: rgba(var(--v-theme-on-surface), 0.55); }

/* Timeline */
.fdj-event { position: relative; padding: 0 0 16px 22px; }
.fdj-event__dot {
  position: absolute;
  left: 4px;
  top: 4px;
  width: 9px;
  height: 9px;
  border-radius: 50%;
  background: rgb(var(--v-theme-primary));
}
.fdj-event__line {
  position: absolute;
  left: 8px;
  top: 16px;
  bottom: 0;
  width: 1px;
  background: rgba(var(--v-theme-on-surface), 0.12);
}
.fdj-event__title { font-size: 0.78rem; font-weight: 700; text-transform: capitalize; }
.fdj-event__note { font-size: 0.74rem; }
.fdj-event__meta { font-size: 0.66rem; color: rgba(var(--v-theme-on-surface), 0.5); }

/* Rx rows */
.fdj-rx-row {
  display: grid;
  grid-template-columns: 2fr 1fr 1fr 1fr 70px 40px;
  gap: 8px;
  margin-bottom: 8px;
  align-items: center;
}

.fdj-table { font-size: 0.78rem; }
.fdj-dialog-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 18px;
}

@media print {
  .v-btn, .fdj-stepper, .fdj-actions { display: none !important; }
}
</style>
