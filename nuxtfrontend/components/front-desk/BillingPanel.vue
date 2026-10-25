<template>
  <section class="rx-card bp">
    <header class="rx-card-head">
      <span class="rx-step" :class="{ 'rx-step--done': complete }">
        <v-icon v-if="complete" size="15">mdi-check</v-icon>
        <template v-else>{{ step }}</template>
      </span>
      <div class="min-w-0">
        <div class="rx-card-title">Billing</div>
        <div class="rx-card-sub">
          Who pays, how they pay, and whether to settle the consultation fee now
        </div>
      </div>
      <v-chip size="x-small" variant="tonal" :color="complete ? 'success' : 'grey'" class="ml-auto">
        {{ money(chargeable) }}
      </v-chip>
    </header>

    <div class="rx-card-body">
      <!-- Payer -->
      <div class="rx-sublabel">Payer</div>
      <div class="bp-payers">
        <button
          v-for="p in payers"
          :key="p.value"
          type="button"
          class="bp-payer"
          :class="{ 'bp-payer--on': state.payer === p.value }"
          :aria-pressed="state.payer === p.value"
          @click="setPayer(p.value)"
        >
          <span class="bp-payer-icon"><v-icon size="18">{{ p.icon }}</v-icon></span>
          <span class="bp-payer-body">
            <span class="bp-payer-title">{{ p.title }}</span>
            <span class="bp-payer-sub">{{ p.subtitle }}</span>
          </span>
          <v-icon v-if="state.payer === p.value" class="bp-payer-check" size="17">
            mdi-check-circle
          </v-icon>
        </button>
      </div>

      <!-- Amount + method -->
      <v-row dense class="mt-2">
        <v-col cols="12" :sm="state.payer === 'corporate' ? 12 : 6">
          <v-text-field
            v-model.number="state.consultation_fee"
            type="number"
            min="0"
            :label="`Consultation fee (${currency})`"
            variant="outlined"
            density="comfortable"
            rounded="lg"
            prepend-inner-icon="mdi-cash"
            :disabled="state.payer === 'waiver'"
            :error-messages="errors.consultation_fee"
            hint="Set to 0 for a free visit"
            persistent-hint
          />
        </v-col>
        <v-col v-if="state.payer !== 'corporate'" cols="12" sm="6">
          <v-select
            v-model="state.payment_method"
            :items="methods"
            item-title="title"
            item-value="value"
            :item-props="methodProps"
            label="Payment method"
            variant="outlined"
            density="comfortable"
            rounded="lg"
            prepend-inner-icon="mdi-credit-card-outline"
            :disabled="state.payer === 'waiver'"
            hide-details
          />
        </v-col>
      </v-row>

      <!-- Insurance detail -->
      <template v-if="state.payer === 'insurance'">
        <div class="rx-sublabel mt-4">Insurance cover</div>
        <v-row dense>
          <v-col cols="12" sm="6">
            <v-text-field v-model="state.insurance_provider" label="Provider"
                          variant="outlined" density="comfortable" rounded="lg"
                          prepend-inner-icon="mdi-shield-check-outline" />
          </v-col>
          <v-col cols="12" sm="6">
            <v-text-field v-model="state.insurance_number" label="Policy / member number"
                          variant="outlined" density="comfortable" rounded="lg"
                          prepend-inner-icon="mdi-barcode" />
          </v-col>
        </v-row>
      </template>

      <!-- Corporate verification -->
      <template v-if="state.payer === 'corporate'">
        <div class="rx-sublabel mt-4">Company &amp; staff verification</div>
        <v-row dense>
          <v-col cols="12" sm="7">
            <v-select v-model="state.corporate" :items="corporateOptions"
                      item-title="label" item-value="id" label="Corporate client *"
                      variant="outlined" density="comfortable" rounded="lg"
                      prepend-inner-icon="mdi-domain" :loading="loadingCorporates"
                      no-data-text="No corporate accounts — add one in the corporate dashboard"
                      :error-messages="errors.corporate"
                      @update:model-value="onCorporateChange" />
          </v-col>
          <v-col cols="12" sm="5">
            <v-text-field v-model="state.corporate_staff_number" label="Job card / staff no. *"
                          variant="outlined" density="comfortable" rounded="lg"
                          prepend-inner-icon="mdi-card-account-details-outline"
                          :error-messages="errors.corporate_staff_number" />
          </v-col>
        </v-row>

        <div class="bp-verify">
          <div class="bp-verify-head">
            <div class="min-w-0">
              <div class="bp-verify-title">Verify company &amp; patient details</div>
              <div class="bp-verify-sub">
                Checks the contract, the staff roster, identity details and the job card on file.
              </div>
            </div>
            <v-btn size="small" rounded="lg" class="text-none bp-verify-btn"
                   variant="flat" :loading="verifying"
                   :disabled="!state.corporate || !state.corporate_staff_number"
                   prepend-icon="mdi-shield-search" @click="verifyCorporate">
              Verify
            </v-btn>
          </div>

          <ul v-if="verification?.checks?.length" class="bp-checks">
            <li v-for="c in verification.checks" :key="c.key"
                class="bp-check" :class="c.passed ? 'bp-check--ok' : 'bp-check--bad'">
              <v-icon size="15">{{ c.passed ? 'mdi-check-circle' : 'mdi-alert-circle' }}</v-icon>
              <div class="min-w-0">
                <div class="bp-check-label">{{ c.label }}</div>
                <div class="bp-check-detail">{{ c.detail }}</div>
              </div>
            </li>
          </ul>

          <div v-if="verification" class="bp-verdict" :class="verification.verified ? 'is-ok' : 'is-bad'">
            <v-icon size="15">{{ verification.verified ? 'mdi-shield-check' : 'mdi-shield-alert' }}</v-icon>
            <span>{{ verification.message }}</span>
          </div>
        </div>

        <v-row dense class="mt-2">
          <v-col cols="12" sm="6">
            <v-text-field v-model="state.corporate_authorisation" label="Job card reference"
                          variant="outlined" density="comfortable" rounded="lg"
                          prepend-inner-icon="mdi-pound-box-outline" hide-details />
          </v-col>
          <v-col cols="12" sm="6">
            <v-file-input v-model="jobCardFile" label="Attach job card / verification"
                          variant="outlined" density="comfortable" rounded="lg"
                          prepend-icon="mdi-paperclip" accept="image/*,application/pdf"
                          :loading="uploadingDoc" show-size hide-details
                          @update:model-value="uploadJobCard" />
          </v-col>
        </v-row>
        <div class="bp-doc-line" :class="{ 'is-ok': !!state.corporate_document }">
          <v-icon size="14">{{ state.corporate_document ? 'mdi-file-check-outline' : 'mdi-file-question-outline' }}</v-icon>
          <span>
            {{ state.corporate_document
              ? `Attached: ${state.corporate_document_name || 'job card'}`
              : 'No job card attached yet — upload it or record the reference.' }}
          </span>
        </div>
      </template>

      <!-- Waiver reason -->
      <template v-if="state.payer === 'waiver'">
        <v-text-field v-model="state.waiver_reason" label="Reason for waiving the fee *"
                      variant="outlined" density="comfortable" rounded="lg" class="mt-2"
                      prepend-inner-icon="mdi-note-alert-outline"
                      :error-messages="errors.waiver_reason"
                      hint="Recorded on the visit audit trail"
                      persistent-hint />
      </template>

      <!-- Settle at reception -->
      <div v-if="state.payer !== 'waiver' && state.payer !== 'corporate'" class="bp-settle mt-4">
        <div class="bp-settle-head">
          <div>
            <div class="bp-settle-title">Collect payment at reception</div>
            <div class="bp-settle-sub">
              {{ state.collectNow
                ? 'A payment is recorded immediately and the visit moves to paid.'
                : 'Raises the invoice and sends the patient to the billing desk.' }}
            </div>
          </div>
          <v-switch v-model="state.collectNow" color="primary" density="compact"
                    hide-details inset :aria-label="'Collect payment at reception'" />
        </div>

        <v-row v-if="state.collectNow" dense class="mt-1">
          <v-col cols="12" sm="6">
            <v-text-field v-model="state.payment_reference"
                          :label="referenceLabel"
                          variant="outlined" density="comfortable" rounded="lg"
                          prepend-inner-icon="mdi-pound-box-outline"
                          :disabled="state.payment_method === 'cash'"
                          :hint="state.payment_method === 'cash'
                            ? 'Cash needs no reference'
                            : 'Transaction code from the receipt or statement'"
                          persistent-hint />
          </v-col>
          <v-col cols="12" sm="6">
            <div class="bp-total">
              <span class="bp-total-label">Amount to collect</span>
              <span class="bp-total-value">{{ money(chargeable) }}</span>
            </div>
          </v-col>
        </v-row>
      </div>

      <div v-if="state.payer === 'corporate'" class="bp-total bp-total--invoice">
        <span class="bp-total-label">Billed to the company</span>
        <span class="bp-total-value">{{ money(chargeable) }}</span>
      </div>

      <div class="rx-law-note">
        <v-icon size="14">mdi-information-outline</v-icon>
        <span v-if="state.payer === 'corporate'">
          Corporate visits are invoiced to the employer on the contracted terms — nothing is
          collected from the patient at reception.
        </span>
        <span v-else>
          Payments post against this visit's invoice. A part payment keeps the visit open
          and the balance visible on the front-desk board.
        </span>
      </div>
    </div>
  </section>
</template>

<script setup>
/**
 * Billing card for reception registration.
 *
 * Shared by the "existing patient" and "new patient" flows so a walk-in and a
 * brand-new record are charged the same way. The parent owns the reactive
 * object (its properties are read and written directly) because the same
 * values are submitted with the visit.
 */
const props = defineProps({
  state: { type: Object, required: true },
  currency: { type: String, default: 'KES' },
  errors: { type: Object, default: () => ({}) },
  step: { type: [Number, String], default: '' },
  allowWaiver: { type: Boolean, default: true },
  /** Patient identity used for corporate verification. */
  patient: { type: Object, default: () => ({}) },
})

const { $api } = useNuxtApp()

const payers = computed(() => {
  const base = [
    { value: 'self', title: 'Self pay', subtitle: 'Patient settles the bill', icon: 'mdi-account-cash' },
    { value: 'insurance', title: 'Insurance', subtitle: 'Cover billed to the scheme', icon: 'mdi-shield-account' },
    { value: 'corporate', title: 'Corporate', subtitle: 'Employer pays — verify the job card', icon: 'mdi-domain' },
  ]
  if (props.allowWaiver) {
    base.push({ value: 'waiver', title: 'Waiver', subtitle: 'Fee waived — reason required', icon: 'mdi-gift-open-outline' })
  }
  return base
})

const methods = [
  { value: 'cash', title: 'Cash', icon: 'mdi-cash' },
  { value: 'card', title: 'Card', icon: 'mdi-credit-card' },
  { value: 'mpesa', title: 'M-Pesa', icon: 'mdi-cellphone' },
  { value: 'bank_transfer', title: 'Bank transfer', icon: 'mdi-bank' },
  { value: 'insurance', title: 'Insurance cover', icon: 'mdi-shield-check' },
]

function methodProps(item) {
  return { prependIcon: item?.icon }
}

const chargeable = computed(() => {
  if (props.state.payer === 'waiver') return 0
  return Number(props.state.consultation_fee) || 0
})

// ── Corporate verification ───────────────────────────────────────────
const corporates = ref([])
const loadingCorporates = ref(false)
const verifying = ref(false)
const uploadingDoc = ref(false)
const jobCardFile = ref(null)

const corporateOptions = computed(() =>
  corporates.value.map(c => ({
    id: c.id,
    label: `${c.name}${c.code ? ` · ${c.code}` : ''}`,
  })))

const verification = computed(() => props.state.corporate_verification || null)

async function loadCorporates() {
  loadingCorporates.value = true
  try {
    const { data } = await $api.get('/corporate/clients/', {
      params: { page_size: 200, is_active: 'true' },
    })
    corporates.value = Array.isArray(data) ? data : (data?.results || [])
  } catch {
    corporates.value = []
  } finally {
    loadingCorporates.value = false
  }
}

function onCorporateChange() {
  // A new company invalidates any earlier verification.
  props.state.corporate_verification = null
  props.state.corporate_verified = false
  props.state.corporate_staff = null
  props.state.corporate_document = null
  props.state.corporate_document_name = ''
}

async function verifyCorporate() {
  if (!props.state.corporate) return
  verifying.value = true
  try {
    const { data } = await $api.post(
      `/corporate/clients/${props.state.corporate}/verify-patient/`,
      {
        staff_number: props.state.corporate_staff_number || '',
        patient: props.patient?.id || props.patient?.patient || null,
        first_name: props.patient?.first_name || '',
        last_name: props.patient?.last_name || '',
        date_of_birth: props.patient?.date_of_birth || null,
        national_id: props.patient?.national_id || '',
        phone: props.patient?.phone || '',
        full_name: props.patient?.full_name || '',
      },
    )
    props.state.corporate_verification = data
    props.state.corporate_verified = !!data.verified
    props.state.corporate_staff = data.staff_id || null
    if (data.staff?.staff_number) {
      props.state.corporate_authorisation =
        props.state.corporate_authorisation || data.staff.staff_number
    }
  } catch (e) {
    props.state.corporate_verification = {
      verified: false,
      message: e?.response?.data?.detail || 'Could not verify the corporate cover.',
      checks: [],
    }
    props.state.corporate_verified = false
  } finally {
    verifying.value = false
  }
}

async function uploadJobCard(file) {
  const picked = Array.isArray(file) ? file[0] : file
  if (!picked || !props.state.corporate) return
  uploadingDoc.value = true
  try {
    const form = new FormData()
    form.append('corporate', props.state.corporate)
    if (props.state.corporate_staff) form.append('staff', props.state.corporate_staff)
    form.append('doc_type', 'job_card')
    form.append('title', `Job card — ${picked.name}`)
    if (props.state.corporate_authorisation) {
      form.append('reference', props.state.corporate_authorisation)
    }
    form.append('file', picked)
    const { data } = await $api.post('/corporate/documents/', form)
    props.state.corporate_document = data.id
    props.state.corporate_document_name = picked.name
  } catch {
    props.state.corporate_document = null
    props.state.corporate_document_name = ''
  } finally {
    uploadingDoc.value = false
  }
}

const complete = computed(() => {
  if (props.state.payer === 'waiver') return !!String(props.state.waiver_reason || '').trim()
  if (props.state.payer === 'corporate') {
    return !!props.state.corporate
      && !!props.state.corporate_verified
      && (!!props.state.corporate_document || !!String(props.state.corporate_authorisation || '').trim())
  }
  if (chargeable.value <= 0) return true
  return !!props.state.payment_method
})

const referenceLabel = computed(() =>
  props.state.payment_method === 'mpesa'
    ? 'M-Pesa code'
    : props.state.payment_method === 'card'
      ? 'Card / terminal reference'
      : 'Payment reference')

function money(n) {
  const v = Number(n) || 0
  return `${props.currency} ${v.toLocaleString('en-US', { maximumFractionDigits: 0 })}`
}

function setPayer(value) {
  props.state.payer = value
  if (value === 'waiver') {
    props.state.collectNow = false
    props.state.payment_method = ''
  } else if (value === 'corporate') {
    props.state.collectNow = false
    props.state.payment_method = ''
  } else if (value === 'insurance') {
    props.state.payment_method = 'insurance'
    props.state.collectNow = false
  } else if (!props.state.payment_method || props.state.payment_method === 'insurance') {
    props.state.payment_method = 'cash'
    props.state.collectNow = true
  }
}

onMounted(loadCorporates)
</script>

<style scoped>
.rx-card {
  border-radius: 16px;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
  overflow: hidden;
}
.rx-card-head {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 14px 18px;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.07);
  background: rgba(var(--v-theme-on-surface), 0.015);
}
.rx-card-title { font-size: 0.94rem; font-weight: 700; line-height: 1.25; }
.rx-card-sub {
  font-size: 11.5px;
  color: rgba(var(--v-theme-on-surface), 0.55);
  line-height: 1.35;
}
.rx-card-body { padding: 18px; }
.rx-step {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 27px;
  height: 27px;
  border-radius: 9px;
  flex-shrink: 0;
  font-size: 12.5px;
  font-weight: 800;
  color: var(--brand-primary, rgb(var(--v-theme-primary)));
  background: color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 11%, transparent);
}
.rx-step--done {
  color: #fff;
  background: #16a34a;
}
.rx-sublabel {
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: 0.7px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.5);
  margin-bottom: 8px;
}
.rx-law-note {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  margin-top: 14px;
  padding: 9px 12px;
  border-radius: 11px;
  font-size: 11.5px;
  line-height: 1.4;
  color: rgba(var(--v-theme-on-surface), 0.62);
  background: rgba(var(--v-theme-on-surface), 0.035);
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
}

/* Payer tiles */
.bp-payers {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
  gap: 9px;
}
.bp-payer {
  position: relative;
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 11px 12px;
  border-radius: 12px;
  border: 1.5px solid rgba(var(--v-theme-on-surface), 0.1);
  background: transparent;
  text-align: left;
  cursor: pointer;
  transition: border-color 0.16s ease, background 0.16s ease, transform 0.16s ease;
}
.bp-payer:hover {
  border-color: color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 40%, transparent);
  transform: translateY(-1px);
}
.bp-payer--on {
  border-color: var(--brand-primary, rgb(var(--v-theme-primary)));
  background: color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 6%, transparent);
}
.bp-payer-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  border-radius: 9px;
  flex-shrink: 0;
  color: rgba(var(--v-theme-on-surface), 0.45);
  background: rgba(var(--v-theme-on-surface), 0.06);
  transition: all 0.16s ease;
}
.bp-payer--on .bp-payer-icon {
  color: #fff;
  background: var(--brand-primary, rgb(var(--v-theme-primary)));
}
.bp-payer-body { display: flex; flex-direction: column; min-width: 0; }
.bp-payer-title { font-size: 0.84rem; font-weight: 700; line-height: 1.2; }
.bp-payer-sub {
  font-size: 10.5px;
  line-height: 1.3;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.bp-payer-check {
  position: absolute;
  top: 8px;
  right: 8px;
  color: var(--brand-primary, rgb(var(--v-theme-primary)));
}

.bp-settle {
  padding: 12px 14px;
  border-radius: 12px;
  border: 1px dashed rgba(var(--v-theme-on-surface), 0.16);
  background: rgba(var(--v-theme-on-surface), 0.02);
}
.bp-settle-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}
.bp-settle-title { font-size: 0.85rem; font-weight: 700; }
.bp-settle-sub {
  font-size: 11.5px;
  line-height: 1.35;
  color: rgba(var(--v-theme-on-surface), 0.58);
  max-width: 46ch;
}
.bp-total {
  display: flex;
  flex-direction: column;
  justify-content: center;
  height: 100%;
  padding: 10px 14px;
  border-radius: 11px;
  background: color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 7%, transparent);
  border: 1px solid color-mix(in srgb, var(--brand-primary, rgb(var(--v-theme-primary))) 24%, transparent);
}
.bp-total-label {
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.6px;
  text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.bp-total-value {
  font-size: 1.15rem;
  font-weight: 800;
  color: var(--brand-primary, rgb(var(--v-theme-primary)));
}
.bp-total--invoice { margin-top: 14px; }

/* ── Corporate verification ── */
.bp-verify {
  margin-top: 12px;
  padding: 12px 14px;
  border-radius: 12px;
  border: 1px dashed rgba(var(--v-theme-on-surface), 0.16);
  background: rgba(var(--v-theme-on-surface), 0.02);
}
.bp-verify-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}
.bp-verify-title { font-size: 0.86rem; font-weight: 750; }
.bp-verify-sub {
  font-size: 11.5px;
  line-height: 1.35;
  color: rgba(var(--v-theme-on-surface), 0.58);
  max-width: 48ch;
}
.bp-verify-btn {
  background: var(--brand-primary, rgb(var(--v-theme-primary))) !important;
  color: #fff !important;
  font-weight: 700;
  flex-shrink: 0;
}
.bp-checks {
  list-style: none;
  margin: 11px 0 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 7px;
}
.bp-check {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  font-size: 11.5px;
  line-height: 1.35;
}
.bp-check--ok { color: #047857; }
.bp-check--bad { color: #b45309; }
.bp-check-label { font-weight: 750; }
.bp-check-detail { color: rgba(var(--v-theme-on-surface), 0.6); font-weight: 500; }
.bp-verdict {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  margin-top: 11px;
  padding: 8px 11px;
  border-radius: 10px;
  font-size: 11.5px;
  font-weight: 650;
  line-height: 1.35;
}
.bp-verdict.is-ok { color: #047857; background: rgba(16, 185, 129, 0.1); }
.bp-verdict.is-bad { color: #b45309; background: rgba(245, 158, 11, 0.12); }
.bp-doc-line {
  display: flex;
  align-items: center;
  gap: 7px;
  margin-top: 8px;
  font-size: 11px;
  color: rgba(var(--v-theme-on-surface), 0.55);
}
.bp-doc-line.is-ok { color: #047857; }
</style>
