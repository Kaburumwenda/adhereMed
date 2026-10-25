<template>
  <v-dialog
    :model-value="modelValue"
    max-width="880"
    persistent
    @update:model-value="close"
  >
    <v-card rounded="xl" class="au-dlg" :style="themeVars">
      <BrandDialogHeader
        :icon="isVerify ? 'mdi-shield-check-outline' : 'mdi-flask-outline'"
        :title="isVerify ? 'Authorise & sign results' : 'Sign as performer'"
        :subtitle="subtitle"
        @close="close(false)"
      >
        <template #actions>
          <span class="au-role-chip">{{ isVerify ? 'VERIFIER' : 'PERFORMER' }}</span>
        </template>
      </BrandDialogHeader>

      <div class="au-body">
        <!-- ── What is being signed ─────────────────────────────────────── -->
        <aside class="au-context">
          <div class="au-ctx-head">
            <span class="au-ctx-eyebrow">SIGNING</span>
            <b>Order #{{ String(orderId).padStart(5, '0') }}</b>
          </div>

          <div class="au-ctx-patient">
            <span class="au-avatar">{{ initials }}</span>
            <div>
              <b>{{ order?.patient_name || 'Patient' }}</b>
              <span>{{ testCount }} test{{ testCount === 1 ? '' : 's' }} · {{ resultedCount }} resulted</span>
            </div>
          </div>

          <ul class="au-ctx-list">
            <li v-if="abnormalCount">
              <v-icon size="12" class="is-bad">mdi-alert-circle-outline</v-icon>
              {{ abnormalCount }} abnormal flag{{ abnormalCount === 1 ? '' : 's' }}
            </li>
            <li>
              <v-icon size="12">mdi-clock-outline</v-icon>
              {{ isVerify ? 'Releases the report to the requesting clinician' : 'Records who ran the assay' }}
            </li>
            <li>
              <v-icon size="12">mdi-lock-outline</v-icon>
              Password and signature are stored with the report
            </li>
          </ul>

          <div v-if="existing" class="au-ctx-existing">
            <span class="au-ctx-eyebrow">CURRENTLY SIGNED</span>
            <div class="au-existing-row">
              <img v-if="existing.signature" :src="existing.signature" alt="" class="au-existing-sig" />
              <div>
                <b>{{ existing.name }}</b>
                <span>{{ existing.title || '—' }}</span>
                <span>{{ relativeTime(existing.signed_at) }}</span>
              </div>
            </div>
            <p class="au-existing-warn">Signing again replaces this signature.</p>
          </div>
        </aside>

        <!-- ── Capture ──────────────────────────────────────────────────── -->
        <div class="au-form">
          <!-- Step 1 — identity -->
          <section class="au-step">
            <header class="au-step-head">
              <span class="au-step-num">1</span>
              <div>
                <b>Who is signing?</b>
                <span>The lab workstation is shared — pick your own name.</span>
              </div>
              <span v-if="selectedStaff" class="au-step-ok">
                <v-icon size="11">mdi-check</v-icon>
              </span>
            </header>

            <div class="au-staff-list" role="listbox">
              <div v-if="loadingStaff" class="au-staff-empty">
                <v-progress-circular indeterminate size="18" width="2" />
                <span>Loading laboratory roster…</span>
              </div>
              <template v-else-if="filteredStaff.length">
                <button
                  v-for="member in filteredStaff"
                  :key="member.id"
                  type="button"
                  role="option"
                  :aria-selected="form.user_id === member.user"
                  class="au-staff"
                  :class="{ 'is-on': form.user_id === member.user }"
                  @click="pickStaff(member)"
                >
                  <span class="au-avatar is-sm">{{ member.avatar_initials }}</span>
                  <span class="au-staff-id">
                    <b>{{ member.full_name }}</b>
                    <span>{{ member.title || member.role_label }}</span>
                  </span>
                  <span v-if="member.has_signature" class="au-badge is-good" title="Signature on file">
                    <v-icon size="11">mdi-draw-pen</v-icon>
                    on file
                  </span>
                  <span
                    v-if="member.is_me || (auth.user?.id && auth.user.id === member.user)"
                    class="au-badge is-me"
                    title="This is the account currently signed in"
                  >
                    <v-icon size="11">mdi-account-check</v-icon>
                    you
                  </span>
                  <span v-if="form.user_id === member.user" class="au-tick">
                    <v-icon size="13">mdi-check-circle</v-icon>
                  </span>
                </button>
              </template>
              <div v-else class="au-staff-empty">
                <v-icon size="16">mdi-account-off-outline</v-icon>
                <span>No {{ isVerify ? 'verifiers' : 'performers' }} on the lab roster yet.</span>
              </div>
            </div>
          </section>

          <!-- Step 2 — identity proof (only needed for someone else) -->
          <section class="au-step" :class="{ 'is-ok': isSelf }">
            <header class="au-step-head">
              <span class="au-step-num">{{ isSelf ? '✓' : '2' }}</span>
              <div>
                <b>{{ isSelf ? 'You are signed in' : "Confirm it's you" }}</b>
                <span v-if="isSelf">
                  {{ signerName || 'Your account' }} — your session already proves it, so just sign below.
                </span>
                <span v-else>
                  Signing for someone else — they must enter their own account password.
                </span>
              </div>
              <span v-if="isSelf" class="au-step-ok">
                <v-icon size="11">mdi-shield-check</v-icon>
              </span>
            </header>

            <div v-if="isSelf" class="au-self-note">
              <v-icon size="14">mdi-account-check-outline</v-icon>
              <span>No password needed — this is your own signed-in account.</span>
            </div>

            <template v-else>
              <v-text-field
                v-model="form.password"
                :type="showPassword ? 'text' : 'password'"
                label="Their account password"
                :placeholder="form.user_id ? 'Enter their password' : 'Pick a name first'"
                variant="outlined"
                density="comfortable"
                hide-details="auto"
                autocomplete="off"
                :disabled="!form.user_id"
                :append-inner-icon="showPassword ? 'mdi-eye-off-outline' : 'mdi-eye-outline'"
                @click:append-inner="showPassword = !showPassword"
                @keydown.enter.prevent="submit"
              />
              <p v-if="fieldError && fieldError.field === 'password'" class="au-error">
                <v-icon size="13">mdi-alert-circle-outline</v-icon>
                {{ fieldError.message }}
              </p>
              <p v-if="form.user_id" class="au-self-warn">
                <v-icon size="12">mdi-alert-outline</v-icon>
                A password is required because you are not {{ signerName || 'this person' }}.
              </p>
            </template>
          </section>

          <!-- Step 3 — signature -->
          <section class="au-step">
            <header class="au-step-head">
              <span class="au-step-num">{{ signStepNumber }}</span>
              <div>
                <b>Your signature</b>
                <span>Ink it on the pad — it is printed on the report.</span>
              </div>
              <div class="au-sig-modes">
                <button type="button" :class="{ 'is-on': sigMode === 'draw' }" @click="setMode('draw')">Draw</button>
                <button
                  type="button"
                  :class="{ 'is-on': sigMode === 'saved' }"
                  :disabled="!savedSignature"
                  @click="setMode('saved')"
                >
                  On file
                </button>
                <button type="button" :class="{ 'is-on': sigMode === 'upload' }" @click="setMode('upload')">Upload</button>
              </div>
            </header>

            <!-- draw -->
            <div v-show="sigMode === 'draw'" class="au-pad-wrap">
              <canvas
                ref="padRef"
                class="au-pad"
                :class="{ 'is-empty': !hasInk }"
                @pointerdown.prevent="startStroke"
                @pointermove.prevent="moveStroke"
                @pointerup="endStroke"
                @pointerleave="endStroke"
                @pointercancel="endStroke"
              />
              <span class="au-pad-guide" aria-hidden="true" />
              <span v-if="!hasInk" class="au-pad-hint">
                <v-icon size="14">mdi-gesture</v-icon>
                Sign here with your mouse, pen or finger
              </span>
              <button v-if="hasInk" type="button" class="au-pad-clear" @click="clearPad">
                <v-icon size="12">mdi-eraser</v-icon>
                Clear
              </button>
            </div>

            <!-- saved -->
            <div v-if="sigMode === 'saved'" class="au-saved">
              <img v-if="savedSignature" :src="savedSignature" alt="Signature on file" />
              <span class="au-saved-note">Using the signature stored on your bench profile.</span>
            </div>

            <!-- upload -->
            <div v-if="sigMode === 'upload'" class="au-upload">
              <button type="button" class="au-upload-btn" @click="fileInput?.click()">
                <v-icon size="18">mdi-cloud-upload-outline</v-icon>
                <b>Upload a signature image</b>
                <span>PNG, JPG or WEBP · transparent background recommended</span>
              </button>
              <input
                ref="fileInput"
                type="file"
                accept="image/png,image/jpeg,image/webp"
                class="au-file"
                @change="onFile"
              />
              <img v-if="uploadedPreview" :src="uploadedPreview" alt="Uploaded signature" class="au-upload-preview" />
            </div>

            <p v-if="fieldError && fieldError.field === 'signature'" class="au-error">
              <v-icon size="13">mdi-alert-circle-outline</v-icon>
              {{ fieldError.message }}
            </p>
          </section>

          <!-- Step 4 — details -->
          <section class="au-step is-plain">
            <div class="au-grid-2">
              <v-text-field
                v-model="form.title"
                label="Title on the report"
                placeholder="e.g. Senior Medical Laboratory Scientist"
                variant="outlined"
                density="compact"
                hide-details="auto"
              />
              <v-text-field
                v-model="form.notes"
                label="Note (optional)"
                placeholder="e.g. Re-ran on analyser 2"
                variant="outlined"
                density="compact"
                hide-details="auto"
              />
            </div>

            <v-checkbox
              v-model="form.save_signature"
              density="compact"
              hide-details
              color="primary"
              class="au-save-sig"
              label="Save this signature to my bench profile for future reports"
            />
          </section>

          <p v-if="fieldError && !fieldError.field" class="au-error">
            <v-icon size="13">mdi-alert-circle-outline</v-icon>
            {{ fieldError.message }}
          </p>
        </div>
      </div>

      <footer class="au-actions">
        <span class="au-actions-hint">
          <v-icon size="13">{{ isSelf ? 'mdi-shield-check-outline' : 'mdi-shield-lock-outline' }}</v-icon>
          {{ isSelf ? 'Signing as your signed-in account' : 'Password + signature required' }} ·
          {{ signerName || '—' }} · {{ nowLabel }}
        </span>
        <v-spacer />
        <button type="button" class="au-btn" :disabled="saving" @click="close(false)">Cancel</button>
        <button
          type="button"
          class="au-btn is-primary"
          :disabled="saving || !canSubmit"
          @click="submit"
        >
          <v-icon size="15" :class="{ 'au-spin': saving }">{{ saving ? 'mdi-loading' : 'mdi-draw-pen' }}</v-icon>
          <span>{{ saving ? 'Signing…' : isVerify ? 'Authorise & sign' : 'Sign as performer' }}</span>
        </button>
      </footer>
    </v-card>
  </v-dialog>
</template>

<script setup>
const props = defineProps({
  modelValue: { type: Boolean, default: false },
  orderId: { type: [Number, String], required: true },
  /** 'performed' | 'verified' */
  role: { type: String, default: 'verified' },
  order: { type: Object, default: null },
  /** Existing signer object from order.authorization.performed / .verified */
  existing: { type: Object, default: null },
})

const emit = defineEmits(['update:modelValue', 'signed'])

const { $api } = useNuxtApp()
const brand = useBranding()
const auth = useAuthStore()

const isVerify = computed(() => props.role === 'verified')

const themeVars = computed(() => ({
  '--au-accent': brand.primary.value,
  '--au-on-accent': brand.onPrimary.value,
  '--au-accent-ink': brand.ink.value,
  '--au-accent-soft': brand.tint('primary', 0.18),
  '--au-accent-ring': brand.tint('primary', 0.24),
}))

/* ── State ────────────────────────────────────────────────────────────── */
const roster = ref([])
const loadingStaff = ref(false)
const saving = ref(false)
const showPassword = ref(false)
const sigMode = ref('draw')
const hasInk = ref(false)
const uploadedPreview = ref('')
const fieldError = ref(null)
const padRef = ref(null)
const fileInput = ref(null)

const form = reactive({
  user_id: null,
  password: '',
  title: '',
  notes: '',
  save_signature: true,
})

const emptyPad = () => {
  const canvas = padRef.value
  if (!canvas) return
  const ratio = window.devicePixelRatio || 1
  const rect = canvas.getBoundingClientRect()
  canvas.width = Math.max(1, Math.round(rect.width * ratio))
  canvas.height = Math.max(1, Math.round(rect.height * ratio))
  const ctx = canvas.getContext('2d')
  ctx.setTransform(ratio, 0, 0, ratio, 0, 0)
  ctx.clearRect(0, 0, rect.width, rect.height)
  ctx.lineWidth = 2.4
  ctx.lineCap = 'round'
  ctx.lineJoin = 'round'
  ctx.strokeStyle = '#0F172A'
  hasInk.value = false
}

/* ── Staff ────────────────────────────────────────────────────────────── */
const selectedStaff = computed(
  () => roster.value.find((m) => m.user === form.user_id) || null,
)
const signerName = computed(() => selectedStaff.value?.full_name || '')
const savedSignature = computed(() => selectedStaff.value?.signature_url || '')

/**
 * The signed-in user signing for themselves only needs to draw a signature —
 * the JWT session already proves who they are. Anyone else on the shared bench
 * must also re-enter their own account password.
 */
const isSelf = computed(() => {
  if (!form.user_id) return false
  if (selectedStaff.value?.is_me) return true
  return Boolean(auth.user?.id && auth.user.id === form.user_id)
})
const requiresPassword = computed(() => Boolean(form.user_id) && !isSelf.value)
const signStepNumber = computed(() => (requiresPassword.value ? '3' : '2'))

const filteredStaff = computed(() => roster.value)

async function loadRoster() {
  loadingStaff.value = true
  try {
    const { data } = await $api.get('/lab/staff/', { params: { role: props.role } })
    roster.value = data?.results || []
  } catch {
    roster.value = []
  } finally {
    loadingStaff.value = false
  }
}

function pickStaff(member) {
  const switching = form.user_id !== member.user
  form.user_id = member.user
  form.title = member.title || member.role_label || ''
  fieldError.value = null
  // A password typed for one person must never carry over to another.
  if (switching) form.password = ''
  // Prefer the signature already on file for a fast, consistent sign-off.
  if (member.has_signature) {
    sigMode.value = 'saved'
  } else if (sigMode.value === 'saved') {
    sigMode.value = 'draw'
  }
}

/* ── Signature pad ────────────────────────────────────────────────────── */
let drawing = false

function startStroke(event) {
  const canvas = padRef.value
  if (!canvas) return
  canvas.setPointerCapture?.(event.pointerId)
  const ctx = canvas.getContext('2d')
  const rect = canvas.getBoundingClientRect()
  drawing = true
  hasInk.value = true
  ctx.beginPath()
  ctx.moveTo(event.clientX - rect.left, event.clientY - rect.top)
}

function moveStroke(event) {
  if (!drawing) return
  const ctx = padRef.value.getContext('2d')
  const rect = padRef.value.getBoundingClientRect()
  ctx.lineTo(event.clientX - rect.left, event.clientY - rect.top)
  ctx.stroke()
}

function endStroke(event) {
  if (!drawing) return
  drawing = false
  padRef.value?.releasePointerCapture?.(event.pointerId)
}

function clearPad() {
  emptyPad()
}

function setMode(mode) {
  sigMode.value = mode
  fieldError.value = null
  if (mode === 'draw') nextTick(() => emptyPad())
}

function onFile(event) {
  const file = event.target.files?.[0]
  if (!file) return
  if (!/^image\/(png|jpeg|webp)$/.test(file.type)) {
    fieldError.value = { field: 'signature', message: 'Upload a PNG, JPG or WEBP image.' }
    return
  }
  if (file.size > 4 * 1024 * 1024) {
    fieldError.value = { field: 'signature', message: 'That image is larger than 4 MB.' }
    return
  }
  const reader = new FileReader()
  reader.onload = () => {
    uploadedPreview.value = String(reader.result || '')
    fieldError.value = null
  }
  reader.readAsDataURL(file)
  event.target.value = ''
}

const signaturePayload = computed(() => {
  if (sigMode.value === 'saved') return null // reuse whatever is on file
  if (sigMode.value === 'upload') return uploadedPreview.value || null
  if (!hasInk.value || !padRef.value) return null
  try {
    return padRef.value.toDataURL('image/png')
  } catch {
    return null
  }
})

const hasSignature = computed(() => {
  if (sigMode.value === 'saved') return Boolean(savedSignature.value)
  return Boolean(signaturePayload.value)
})

const canSubmit = computed(
  () =>
    Boolean(form.user_id) &&
    hasSignature.value &&
    (isSelf.value || Boolean(form.password)),
)

/* ── Context ──────────────────────────────────────────────────────────── */
const testCount = computed(() => props.order?.test_names?.length || 0)
const resultedCount = computed(() => props.order?.results?.length || 0)
const abnormalCount = computed(
  () => (props.order?.results || []).filter((r) => r.is_abnormal).length,
)
const initials = computed(() => {
  const parts = String(props.order?.patient_name || '?').split(/\s+/).filter(Boolean)
  return (parts.slice(0, 2).map((p) => p[0].toUpperCase()).join('') || '?')
})

const subtitle = computed(() => {
  const parts = []
  if (props.order?.patient_name) parts.push(props.order.patient_name)
  parts.push(`${testCount.value} test${testCount.value === 1 ? '' : 's'}`)
  if (isVerify.value) parts.push('releases the final report')
  else parts.push('records the bench performer')
  return parts.join(' · ')
})

function relativeTime(value) {
  if (!value) return '—'
  const diff = Date.now() - new Date(value).getTime()
  const minutes = Math.round(Math.abs(diff) / 60000)
  if (minutes < 1) return 'just now'
  if (minutes < 60) return diff >= 0 ? `${minutes}m ago` : `in ${minutes}m`
  const hours = Math.round(minutes / 60)
  if (hours < 24) return diff >= 0 ? `${hours}h ago` : `in ${hours}h`
  return new Date(value).toLocaleDateString(undefined, { day: 'numeric', month: 'short' })
}

const nowLabel = new Date().toLocaleString(undefined, {
  day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit',
})

/* ── Submit ───────────────────────────────────────────────────────────── */
function resetForm() {
  form.user_id = null
  form.password = ''
  form.title = ''
  form.notes = ''
  form.save_signature = true
  fieldError.value = null
  uploadedPreview.value = ''
  hasInk.value = false
  sigMode.value = 'draw'
  showPassword.value = false
}

function close(value = false) {
  if (saving.value) return
  emit('update:modelValue', Boolean(value))
}

async function submit() {
  if (saving.value || !canSubmit.value) return
  fieldError.value = null
  saving.value = true
  try {
    const { data } = await $api.post(`/lab/orders/${props.orderId}/sign/`, {
      role: props.role,
      user_id: form.user_id,
      // Self-signing relies on the session, so no password is sent.
      password: requiresPassword.value ? form.password : '',
      signature: signaturePayload.value,
      title: form.title,
      notes: form.notes,
      save_signature: form.save_signature,
    })
    emit('signed', data)
    emit('update:modelValue', false)
    resetForm()
  } catch (error) {
    const payload = error?.response?.data || {}
    fieldError.value = {
      field: payload.field || null,
      message: payload.detail || 'Could not record the signature.',
    }
  } finally {
    saving.value = false
  }
}

/* ── Lifecycle ────────────────────────────────────────────────────────── */
watch(
  () => props.modelValue,
  async (open) => {
    if (!open) return
    fieldError.value = null
    await loadRoster()
    // On a shared workstation the logged-in user is often not the signer, but
    // when they *are* on the roster it saves a click to preselect them.
    const me = roster.value.find((m) => m.user === auth.user?.id)
    if (me && !form.user_id) pickStaff(me)
    nextTick(() => {
      if (sigMode.value === 'draw') emptyPad()
    })
  },
)

watch(sigMode, (mode) => {
  if (mode === 'draw') nextTick(() => emptyPad())
})

onMounted(() => {
  window.addEventListener('resize', () => {
    if (props.modelValue && sigMode.value === 'draw') clearPad()
  })
})
</script>

<style scoped>
/* ══ Tokens ══ */
.au-dlg {
  --au-line: rgba(var(--v-theme-on-surface), 0.1);
  --au-line-soft: rgba(var(--v-theme-on-surface), 0.06);
  --au-muted: rgba(var(--v-theme-on-surface), 0.6);
  --au-faint: rgba(var(--v-theme-on-surface), 0.44);
  --au-surface: rgb(var(--v-theme-surface));
  --au-raise: rgba(var(--v-theme-on-surface), 0.035);
  display: flex;
  flex-direction: column;
  max-height: calc(100vh - 48px);
  overflow: hidden;
}

.au-role-chip {
  display: inline-flex;
  align-items: center;
  height: 22px;
  padding: 0 9px;
  border-radius: 999px;
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 1px;
  color: #fff;
  background: rgba(255, 255, 255, 0.18);
  border: 1px solid rgba(255, 255, 255, 0.3);
}

/* ══ Body ══ */
.au-body {
  flex: 1 1 auto;
  min-height: 0;
  overflow-y: auto;
  display: grid;
  grid-template-columns: 236px minmax(0, 1fr);
  gap: 0;
}

/* ── Context rail ── */
.au-context {
  padding: 16px;
  border-right: 1px solid var(--au-line-soft);
  background: var(--au-raise);
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.au-ctx-eyebrow {
  font-size: 8.5px;
  font-weight: 800;
  letter-spacing: 1.1px;
  text-transform: uppercase;
  color: var(--au-faint);
}
.au-ctx-head { display: flex; flex-direction: column; gap: 1px; }
.au-ctx-head b { font-size: 15px; font-weight: 800; letter-spacing: -0.3px; }

.au-ctx-patient { display: flex; align-items: center; gap: 9px; }
.au-ctx-patient > div { display: flex; flex-direction: column; line-height: 1.3; min-width: 0; }
.au-ctx-patient b { font-size: 12px; font-weight: 800; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.au-ctx-patient span { font-size: 10px; font-weight: 700; color: var(--au-faint); }

.au-avatar {
  width: 34px;
  height: 34px;
  border-radius: 10px;
  flex-shrink: 0;
  display: grid;
  place-items: center;
  font-size: 11.5px;
  font-weight: 800;
  color: var(--au-accent-ink);
  background: color-mix(in srgb, var(--au-accent) 13%, transparent);
  border: 1px solid color-mix(in srgb, var(--au-accent) 24%, transparent);
}
.au-avatar.is-sm { width: 30px; height: 30px; border-radius: 9px; font-size: 10.5px; }

.au-ctx-list { list-style: none; margin: 0; padding: 0; display: grid; gap: 7px; }
.au-ctx-list li {
  display: flex;
  align-items: flex-start;
  gap: 6px;
  font-size: 10.5px;
  font-weight: 600;
  line-height: 1.45;
  color: var(--au-muted);
}
.au-ctx-list li :deep(.v-icon) { color: var(--au-accent); margin-top: 1px; }
.au-ctx-list li :deep(.v-icon.is-bad) { color: #b91c1c; }

.au-ctx-existing {
  margin-top: auto;
  padding: 9px 10px;
  border-radius: 10px;
  border: 1px solid var(--au-line);
  background: var(--au-surface);
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.au-existing-row { display: flex; align-items: center; gap: 8px; }
.au-existing-row > div { display: flex; flex-direction: column; line-height: 1.3; min-width: 0; }
.au-existing-row b { font-size: 11px; font-weight: 800; }
.au-existing-row span { font-size: 9.5px; font-weight: 600; color: var(--au-faint); }
.au-existing-sig {
  width: 46px;
  height: 30px;
  object-fit: contain;
  border-radius: 6px;
  background: #fff;
  border: 1px solid var(--au-line);
}
.au-existing-warn {
  margin: 0;
  font-size: 9.5px;
  font-weight: 700;
  color: #b45309;
}

/* ── Form column ── */
.au-form { padding: 16px 18px; display: flex; flex-direction: column; gap: 14px; }

.au-step {
  border: 1px solid var(--au-line);
  border-radius: 13px;
  padding: 12px 13px;
  background: var(--au-surface);
}
.au-step.is-plain { border-style: dashed; background: transparent; }
.au-step-head { display: flex; align-items: center; gap: 9px; margin-bottom: 10px; }
.au-step-num {
  width: 21px;
  height: 21px;
  border-radius: 7px;
  flex-shrink: 0;
  display: grid;
  place-items: center;
  font-size: 10px;
  font-weight: 800;
  color: var(--au-on-accent);
  background: var(--au-accent);
  box-shadow: 0 4px 10px var(--au-accent-ring);
}
.au-step-head > div { display: flex; flex-direction: column; line-height: 1.3; min-width: 0; }
.au-step-head b { font-size: 12px; font-weight: 800; }
.au-step-head span { font-size: 10px; font-weight: 600; color: var(--au-faint); }
.au-step-ok {
  margin-left: auto;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  color: #047857;
  background: rgba(16, 185, 129, 0.14);
}
.au-step.is-ok {
  border-color: rgba(16, 185, 129, 0.34);
  background: rgba(16, 185, 129, 0.06);
}
.au-step.is-ok .au-step-num {
  background: #047857;
  box-shadow: 0 4px 10px rgba(16, 185, 129, 0.28);
}
.au-self-note {
  display: flex;
  align-items: center;
  gap: 7px;
  padding: 9px 11px;
  border-radius: 10px;
  font-size: 10.5px;
  font-weight: 700;
  color: #047857;
  background: rgba(16, 185, 129, 0.1);
  border: 1px solid rgba(16, 185, 129, 0.26);
}
.au-self-warn {
  display: flex;
  align-items: center;
  gap: 5px;
  margin: 8px 0 0;
  font-size: 9.5px;
  font-weight: 700;
  color: #b45309;
}

/* Staff picker */
.au-staff-list {
  display: grid;
  gap: 5px;
  max-height: 168px;
  overflow-y: auto;
}
.au-staff {
  display: flex;
  align-items: center;
  gap: 9px;
  width: 100%;
  padding: 6px 8px;
  border-radius: 10px;
  border: 1px solid var(--au-line);
  background: var(--au-raise);
  cursor: pointer;
  text-align: left;
  font-family: inherit;
  transition: border-color 0.15s ease, background 0.15s ease;
}
.au-staff:hover { border-color: color-mix(in srgb, var(--au-accent) 40%, transparent); }
.au-staff.is-on {
  border-color: color-mix(in srgb, var(--au-accent) 62%, transparent);
  background: color-mix(in srgb, var(--au-accent) 8%, transparent);
}
.au-staff-id { flex: 1; min-width: 0; display: flex; flex-direction: column; line-height: 1.3; }
.au-staff-id b { font-size: 11.5px; font-weight: 800; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.au-staff-id span { font-size: 9.5px; font-weight: 600; color: var(--au-faint); }
.au-badge {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  height: 18px;
  padding: 0 6px;
  border-radius: 999px;
  font-size: 8.5px;
  font-weight: 800;
  letter-spacing: 0.3px;
  text-transform: uppercase;
}
.au-badge.is-good {
  color: #047857;
  background: rgba(16, 185, 129, 0.12);
  border: 1px solid rgba(16, 185, 129, 0.28);
}
.au-badge.is-me {
  color: var(--au-accent-ink);
  background: color-mix(in srgb, var(--au-accent) 14%, transparent);
  border: 1px solid color-mix(in srgb, var(--au-accent) 30%, transparent);
}
.au-tick { color: var(--au-accent); display: grid; place-items: center; }
.au-staff-empty {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px;
  border-radius: 10px;
  border: 1px dashed var(--au-line);
  font-size: 10.5px;
  font-weight: 700;
  color: var(--au-faint);
}

/* Signature modes */
.au-sig-modes {
  margin-left: auto;
  display: inline-flex;
  padding: 2px;
  gap: 2px;
  border-radius: 9px;
  border: 1px solid var(--au-line);
  background: var(--au-raise);
}
.au-sig-modes button {
  height: 22px;
  padding: 0 9px;
  border: 0;
  border-radius: 7px;
  background: transparent;
  cursor: pointer;
  font-family: inherit;
  font-size: 10px;
  font-weight: 800;
  color: var(--au-muted);
  transition: background 0.15s ease, color 0.15s ease;
}
.au-sig-modes button:disabled { opacity: 0.4; cursor: not-allowed; }
.au-sig-modes button:hover:not(:disabled) { color: rgb(var(--v-theme-on-surface)); }
.au-sig-modes button.is-on {
  background: var(--au-surface);
  color: rgb(var(--v-theme-on-surface));
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.12);
}

/* Pad */
.au-pad-wrap {
  position: relative;
  border-radius: 11px;
  border: 1.5px dashed var(--au-line);
  background: #fff;
  overflow: hidden;
}
.au-pad {
  display: block;
  width: 100%;
  height: 132px;
  cursor: crosshair;
  touch-action: none;
}
.au-pad-guide {
  position: absolute;
  left: 22px;
  right: 22px;
  bottom: 34px;
  border-bottom: 1px dashed rgba(15, 23, 42, 0.18);
  pointer-events: none;
}
.au-pad-hint {
  position: absolute;
  inset: auto 0 12px 0;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 5px;
  font-size: 10px;
  font-weight: 700;
  color: #64748b;
  pointer-events: none;
}
.au-pad-clear {
  position: absolute;
  top: 7px;
  right: 7px;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  height: 22px;
  padding: 0 8px;
  border-radius: 7px;
  border: 1px solid rgba(15, 23, 42, 0.12);
  background: rgba(255, 255, 255, 0.92);
  cursor: pointer;
  font-family: inherit;
  font-size: 9.5px;
  font-weight: 800;
  color: #475569;
}
.au-pad-clear:hover { color: #0f172a; }

/* Saved signature */
.au-saved {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  padding: 10px;
  border-radius: 11px;
  border: 1px solid rgba(16, 185, 129, 0.28);
  background: rgba(16, 185, 129, 0.06);
}
.au-saved img { max-height: 78px; max-width: 260px; object-fit: contain; }
.au-saved-note { font-size: 9.5px; font-weight: 700; color: #047857; }

/* Upload */
.au-upload { display: flex; flex-direction: column; gap: 8px; }
.au-upload-btn {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 3px;
  padding: 14px;
  border-radius: 11px;
  border: 1.5px dashed var(--au-line);
  background: var(--au-raise);
  cursor: pointer;
  font-family: inherit;
  color: var(--au-muted);
  transition: border-color 0.15s ease, background 0.15s ease;
}
.au-upload-btn:hover {
  border-color: color-mix(in srgb, var(--au-accent) 50%, transparent);
  background: color-mix(in srgb, var(--au-accent) 6%, transparent);
}
.au-upload-btn b { font-size: 11px; font-weight: 800; color: rgb(var(--v-theme-on-surface)); }
.au-upload-btn span { font-size: 9.5px; font-weight: 600; }
.au-file { display: none; }
.au-upload-preview {
  max-height: 78px;
  max-width: 240px;
  object-fit: contain;
  align-self: center;
  background: #fff;
  border-radius: 8px;
  padding: 4px;
}

.au-grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.au-save-sig { margin-top: 4px; }
.au-save-sig :deep(.v-label) { font-size: 11px; font-weight: 600; }

.au-error {
  display: flex;
  align-items: center;
  gap: 5px;
  margin: 8px 0 0;
  font-size: 10.5px;
  font-weight: 700;
  color: #b91c1c;
}

/* ── Footer ── */
.au-actions {
  flex: 0 0 auto;
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
  padding: 11px 18px;
  border-top: 1px solid var(--au-line-soft);
  background: var(--au-raise);
}
.au-actions-hint {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  font-size: 9.5px;
  font-weight: 700;
  color: var(--au-faint);
}
.au-spin { animation: auSpin 0.9s linear infinite; }
@keyframes auSpin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}
.au-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  height: 34px;
  padding: 0 13px;
  border-radius: 9px;
  border: 1px solid var(--au-line);
  background: transparent;
  color: rgb(var(--v-theme-on-surface));
  font-family: inherit;
  font-size: 12px;
  font-weight: 700;
  cursor: pointer;
  white-space: nowrap;
  transition: background 0.15s ease, transform 0.15s ease, opacity 0.15s ease;
}
.au-btn:hover:not(:disabled) { background: var(--au-raise); transform: translateY(-1px); }
.au-btn:disabled { opacity: 0.45; cursor: not-allowed; }
.au-btn.is-primary {
  background: var(--au-accent);
  color: var(--au-on-accent);
  border-color: transparent;
  box-shadow: 0 7px 18px var(--au-accent-ring);
}
.au-btn.is-primary:hover:not(:disabled) {
  background: var(--au-accent);
  color: var(--au-on-accent);
  filter: brightness(1.06);
}
.au-btn.is-primary :deep(.v-icon) { color: inherit; }
.au-btn :deep(.mdi-loading) { animation: auSpin 0.9s linear infinite; }
@keyframes auSpin { to { transform: rotate(360deg); } }

/* ══ Responsive ══ */
@media (max-width: 860px) {
  .au-body { grid-template-columns: minmax(0, 1fr); }
  .au-context { border-right: 0; border-bottom: 1px solid var(--au-line-soft); }
  .au-ctx-existing { margin-top: 0; }
  .au-grid-2 { grid-template-columns: minmax(0, 1fr); }
}
</style>
