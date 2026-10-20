<template>
  <v-container fluid class="pa-3 pa-md-5 crm-page">
    <CrmHero
      icon="mdi-account-group-outline"
      eyebrow="IMS · CUSTOMER CRM · SEGMENTS"
      title="Customer Segments"
      subtitle="Group customers into cohorts for targeting, pricing and campaigns — static lists or rule-based audiences."
      :facts="heroFacts"
    >
      <template #actions>
        <v-btn icon="mdi-refresh" variant="text" size="small" class="crm-hero-iconbtn" title="Refresh" :loading="loading" @click="load" />
        <v-btn variant="flat" elevation="0" rounded="lg" class="text-none crm-hero-btn-strong" prepend-icon="mdi-plus" @click="openCreate">
          New segment
        </v-btn>
      </template>
    </CrmHero>

    <v-row dense>
      <v-col v-for="s in segments" :key="s.id" cols="12" sm="6" lg="4" xl="3">
        <v-card rounded="xl" border class="crm-seg h-100" @click="openMembers(s)">
          <div class="d-flex align-center justify-space-between">
            <div class="d-flex align-center" style="gap:10px">
              <div class="crm-seg-icon" :style="{ background: s.color + '1f', color: s.color }">
                <v-icon size="20">{{ s.icon || 'mdi-account-group-outline' }}</v-icon>
              </div>
              <div>
                <div class="crm-seg-name">{{ s.name }}</div>
                <div class="text-caption text-medium-emphasis">{{ s.code || titleCase(s.kind) }}</div>
              </div>
            </div>
            <v-chip size="x-small" :color="s.is_active ? 'success' : 'grey'" variant="tonal" class="font-weight-bold">
              {{ s.is_active ? 'Active' : 'Inactive' }}
            </v-chip>
          </div>

          <div v-if="s.description" class="text-caption text-medium-emphasis mt-2">{{ s.description }}</div>

          <v-divider class="my-3" />

          <div class="d-flex align-center justify-space-between">
            <div>
              <div class="crm-seg-label">Members</div>
              <div class="crm-seg-value">{{ s.member_count }}</div>
            </div>
            <div class="text-right">
              <div class="crm-seg-label">Type</div>
              <div class="crm-seg-value">{{ titleCase(s.kind) }}</div>
            </div>
            <v-btn icon="mdi-pencil" size="x-small" variant="text" @click.stop="openEdit(s)" />
          </div>
        </v-card>
      </v-col>
      <v-col v-if="!segments.length" cols="12">
        <v-card rounded="xl" border>
          <div class="crm-empty pa-8">
            <v-icon size="46" color="medium-emphasis">mdi-account-group-outline</v-icon>
            <div class="text-body-1 font-weight-medium mt-2">No segments yet</div>
            <div class="text-caption text-medium-emphasis">Create a segment to target a cohort of customers.</div>
            <v-btn class="text-none mt-3" color="primary" variant="tonal" rounded="lg" prepend-icon="mdi-plus" @click="openCreate">New segment</v-btn>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- form -->
    <v-dialog v-model="formDialog" max-width="560">
      <v-card rounded="xl">
        <BrandDialogHeader
          :icon="editing ? 'mdi-pencil' : 'mdi-plus'"
          :title="editing ? 'Edit segment' : 'New segment'"
          subtitle="Group customers by shared traits"
          @close="formDialog = false"
        />
        <v-card-text>
          <v-text-field v-model="form.name" label="Segment name *" variant="outlined" density="comfortable" class="mb-2" />
          <v-text-field v-model="form.code" label="Code" variant="outlined" density="comfortable" class="mb-2" />
          <v-textarea v-model="form.description" label="Description" rows="2" auto-grow variant="outlined" density="comfortable" class="mb-2" />
          <div class="d-flex ga-2 mb-2">
            <v-select v-model="form.kind" :items="kindOptions" item-title="label" item-value="value" label="Kind" variant="outlined" density="comfortable" />
            <v-text-field v-model="form.color" type="color" label="Colour" variant="outlined" density="comfortable" />
          </div>
          <v-text-field v-model="form.icon" label="Icon (mdi-…)" variant="outlined" density="comfortable" prepend-inner-icon="mdi-emoticon-outline" class="mb-2" />
          <v-switch v-model="form.is_active" color="success" density="compact" hide-details label="Active" />
        </v-card-text>
        <v-card-actions>
          <v-btn v-if="editing" variant="text" color="error" class="text-none" prepend-icon="mdi-trash-can-outline" @click="remove">Delete</v-btn>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="formDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" rounded="lg" class="text-none" :loading="saving" @click="save">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- members -->
    <v-dialog v-model="membersDialog" max-width="720" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader
          :icon="activeSegment?.icon || 'mdi-account-group-outline'"
          :title="`${activeSegment?.name || 'Segment'} — members`"
          subtitle="Click a member to open their 360° profile"
          @close="membersDialog = false"
        >
          <template #actions>
            <v-chip size="small" variant="flat" class="bdh-chip-solid font-weight-bold">{{ members.length }}</v-chip>
          </template>
        </BrandDialogHeader>
        <v-card-text v-if="members.length">
          <div v-for="m in members" :key="m.id" class="crm-member" @click="goCustomer(m.id)">
            <v-avatar size="30" :color="avatarColor(m.name)" variant="flat" class="text-white" style="font-size: 11px">{{ initials(m.name) }}</v-avatar>
            <div class="flex-grow-1">
              <div class="text-body-2 font-weight-medium">{{ m.name }}</div>
              <div class="text-caption text-medium-emphasis">{{ m.phone }} · {{ m.loyalty_tier }}</div>
            </div>
            <v-chip size="x-small" variant="tonal" :color="lifecycleMeta(m.lifecycle_stage).color">{{ lifecycleMeta(m.lifecycle_stage).label }}</v-chip>
            <span class="text-caption font-weight-medium">{{ formatMoney(m.total_purchases) }}</span>
          </div>
        </v-card-text>
        <div v-else class="crm-empty pa-6">
          <v-icon size="38" color="medium-emphasis">mdi-account-off-outline</v-icon>
          <div class="text-caption text-medium-emphasis mt-2">No members assigned to this segment yet.</div>
        </div>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="membersDialog = false">Close</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" rounded="lg" timeout="3400">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
import { avatarColor, initials, lifecycleMeta, useCrm } from '~/composables/useCrm'

definePageMeta({ layout: 'default' })

const { $api } = useNuxtApp()
const { segments: fetchSegments, segmentMembers, customerStats, unpack } = useCrm()

const loading = ref(false)
const saving = ref(false)
const segments = ref([])
const stats = ref({})
const snack = reactive({ show: false, color: 'success', text: '' })

const formDialog = ref(false)
const editing = ref(false)
const form = ref(blank())

const membersDialog = ref(false)
const activeSegment = ref(null)
const members = ref([])

const kindOptions = [
  { value: 'static', label: 'Static list' },
  { value: 'dynamic', label: 'Rule based' },
]

const heroFacts = computed(() => [
  { value: segments.value.length, label: 'segments' },
  { value: segments.value.filter((s) => s.is_active).length, label: 'active' },
  { value: segments.value.reduce((a, s) => a + (s.member_count || 0), 0), label: 'total members' },
  { value: stats.value.total_customers ?? 0, label: 'customers' },
])

function titleCase(v) {
  return String(v || '').replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())
}

function blank() {
  return {
    name: '', code: '', description: '', kind: 'static',
    color: '#0d9488', icon: 'mdi-account-group-outline', is_active: true,
  }
}

async function load() {
  loading.value = true
  try {
    const [list, st] = await Promise.all([fetchSegments({ page_size: 200 }), customerStats()])
    segments.value = unpack(list)
    stats.value = st.data || {}
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Failed to load segments' }
  } finally {
    loading.value = false
  }
}

function openCreate() {
  editing.value = false
  form.value = blank()
  formDialog.value = true
}

function openEdit(s) {
  editing.value = true
  form.value = { ...blank(), ...s }
  formDialog.value = true
}

async function openMembers(s) {
  activeSegment.value = s
  members.value = []
  membersDialog.value = true
  try {
    const { data } = await segmentMembers(s.id)
    members.value = data || []
  } catch { /* ignore */ }
}

function goCustomer(id) {
  navigateTo(`/ims/crm/customers/${id}`)
}

async function save() {
  if (!form.value.name) {
    snack.value = { show: true, color: 'error', text: 'Segment name is required' }
    return
  }
  saving.value = true
  try {
    if (editing.value && form.value.id) {
      await $api.patch(`/crm/segments/${form.value.id}/`, form.value)
      snack.value = { show: true, color: 'success', text: 'Segment updated' }
    } else {
      await $api.post('/crm/segments/', form.value)
      snack.value = { show: true, color: 'success', text: 'Segment created' }
    }
    formDialog.value = false
    await load()
  } catch (e) {
    const d = e?.response?.data
    snack.value = { show: true, color: 'error', text: d && typeof d === 'object' ? Object.values(d).flat().join(' ') : 'Save failed' }
  } finally {
    saving.value = false
  }
}

async function remove() {
  if (!form.value.id) return
  try {
    await $api.delete(`/crm/segments/${form.value.id}/`)
    formDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Segment deleted' }
    await load()
  } catch {
    snack.value = { show: true, color: 'error', text: 'Failed to delete segment' }
  }
}

onMounted(load)
</script>

<style scoped>
.crm-page { max-width: 1680px; margin: 0 auto; }
.crm-hero-iconbtn { color: #fff !important; }
.crm-hero-btn-strong { background: #fff !important; color: var(--hero-ink, #143ce1) !important; font-weight: 700 !important; border: 1px solid rgba(255,255,255,.95) !important; }
.crm-seg { padding: 14px; cursor: pointer; transition: box-shadow .16s, transform .16s; }
.crm-seg:hover { box-shadow: 0 8px 22px rgba(0,0,0,.09); transform: translateY(-1px); }
.crm-seg-icon { width: 40px; height: 40px; border-radius: 12px; display: flex; align-items: center; justify-content: center; }
.crm-seg-name { font-size: 14px; font-weight: 800; }
.crm-seg-label { font-size: 10px; text-transform: uppercase; letter-spacing: .4px; color: rgba(var(--v-theme-on-surface), .58); }
.crm-seg-value { font-size: 14px; font-weight: 700; }
.crm-member { display: flex; align-items: center; gap: 10px; padding: 8px 0; border-bottom: 1px solid rgba(var(--v-border-color), .1); cursor: pointer; }
.crm-member:last-child { border-bottom: none; }
.crm-member:hover { background: rgba(var(--v-theme-primary), .04); }
.crm-empty { display: flex; flex-direction: column; align-items: center; text-align: center; }
</style>
