<template>
  <v-container fluid class="pa-4 pa-md-6 exp-cat-shell">
    <PageHeader :title="$t('expenseCategories.title')" icon="mdi-shape" subtitle="Group expenses for reporting and analytics">
      <template #actions>
        <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left" to="/expenses">{{ $t('common.back') }}</v-btn>
        <v-btn color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus" @click="openNew">{{ $t('expenseCategories.newCategory') }}</v-btn>
      </template>
    </PageHeader>

    <v-card rounded="lg" class="pa-3 mb-3">
      <v-text-field
        v-model="search" placeholder="Search categories…" variant="solo-filled" density="comfortable"
        hide-details flat rounded="lg" prepend-inner-icon="mdi-magnify" bg-color="surface" clearable
      />
    </v-card>

    <div v-if="loading" class="text-center py-12">
      <v-progress-circular indeterminate color="primary" />
    </div>
    <template v-else-if="!filtered.length">
      <EmptyState icon="mdi-shape-outline" title="No categories" message="Create one to start grouping expenses, or pick a suggestion below.">
        <template #actions>
          <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openNew">{{ $t('expenseCategories.newCategory') }}</v-btn>
        </template>
      </EmptyState>
      <v-card rounded="lg" class="pa-4 mt-3">
        <div class="text-subtitle-2 font-weight-bold mb-1">Quick add common categories</div>
        <div class="text-caption text-medium-emphasis mb-3">Click to create instantly.</div>
        <div class="d-flex flex-wrap" style="gap:8px">
          <v-chip v-for="p in commonCategories" :key="p.name" :prepend-icon="p.icon"
                  :color="p.color" variant="tonal" :disabled="quickBusy"
                  @click="quickCreate(p)">
            {{ p.name }}
          </v-chip>
        </div>
      </v-card>
    </template>

    <v-row v-else dense>
      <v-col v-for="c in filtered" :key="c.id" cols="12" sm="6" md="4">
        <v-card rounded="lg" class="pa-4 cat-card">
          <div class="d-flex align-center mb-2">
            <v-avatar :color="c.color || 'primary'" size="36" class="mr-3"><v-icon color="white">mdi-shape</v-icon></v-avatar>
            <div class="flex-grow-1">
              <div class="text-h6 font-weight-bold">{{ c.name }}</div>
              <div class="text-caption text-medium-emphasis">{{ c.is_active ? 'Active' : 'Inactive' }}</div>
            </div>
            <v-btn icon="mdi-pencil" size="x-small" variant="text" @click="openEdit(c)" />
            <v-btn icon="mdi-delete-outline" size="x-small" variant="text" color="error" @click="confirmDelete(c)" />
          </div>
          <div v-if="c.description" class="text-body-2 text-medium-emphasis mb-2">{{ c.description }}</div>
          <v-divider class="my-2" />
          <div class="d-flex justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis">{{ $t('expenses.title') }}</div>
              <div class="font-weight-bold">{{ c.expense_count || 0 }}</div>
            </div>
            <div class="text-end">
              <div class="text-caption text-medium-emphasis">Total spent</div>
              <div class="font-weight-bold text-primary">{{ formatMoney(c.total_spent || 0) }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <v-dialog v-model="dialog.show" max-width="520" persistent>
      <v-card rounded="lg">
        <v-card-title class="text-subtitle-1 font-weight-bold">{{ dialog.editing ? 'Edit Category' : 'New Category' }}</v-card-title>
        <v-card-text>
          <template v-if="!dialog.editing">
            <div class="text-caption text-medium-emphasis mb-1">Suggestions</div>
            <div class="d-flex flex-wrap mb-3" style="gap:6px">
              <v-chip v-for="p in commonCategories" :key="p.name" :prepend-icon="p.icon"
                      :color="p.color" variant="tonal" size="small"
                      @click="applyPreset(p)">
                {{ p.name }}
              </v-chip>
            </div>
          </template>
          <v-text-field v-model="dialog.form.name" label="Name *" :rules="[v => !!v || 'Required']" />
          <v-textarea v-model="dialog.form.description" label="Description" rows="2" auto-grow />
          <v-text-field v-model="dialog.form.color" label="Color (hex)" placeholder="#6366f1">
            <template #prepend-inner>
              <v-avatar :color="dialog.form.color || 'grey-lighten-2'" size="22" />
            </template>
          </v-text-field>
          <div class="text-caption text-medium-emphasis mb-1">Quick picks</div>
          <div class="d-flex flex-wrap mb-3" style="gap:6px">
            <v-tooltip v-for="c in colorPresets" :key="c.value" :text="c.name" location="top">
              <template #activator="{ props }">
                <v-btn
                  v-bind="props"
                  :color="c.value"
                  size="x-small"
                  icon
                  variant="flat"
                  :class="dialog.form.color === c.value ? 'border-md border-primary' : ''"
                  @click="dialog.form.color = c.value"
                >
                  <v-icon v-if="dialog.form.color === c.value" size="14" color="white">mdi-check</v-icon>
                </v-btn>
              </template>
            </v-tooltip>
          </div>
          <v-checkbox v-model="dialog.form.is_active" label="Active" hide-details />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="dialog.show = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="primary" variant="flat" :loading="dialog.busy" :disabled="!dialog.form.name" @click="save">{{ $t('common.save') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-dialog v-model="del.show" max-width="400" persistent>
      <v-card rounded="lg">
        <v-card-title class="text-subtitle-1 font-weight-bold">Delete Category</v-card-title>
        <v-card-text>{{ $t('common.delete') }}<b>{{ del.cat?.name }}</b>?</v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="del.show = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="error" variant="flat" :loading="del.busy" @click="doDelete">{{ $t('common.delete') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

import { useResource } from '~/composables/useResource'
import { formatMoney } from '~/utils/format'

const r = useResource('/expenses/categories/')
const search = ref('')
const loading = computed(() => r.loading.value)
const filtered = computed(() => {
  const q = search.value.toLowerCase().trim()
  return (r.items.value || []).filter(c => !q || (c.name || '').toLowerCase().includes(q))
})

const snack = reactive({ show: false, color: 'success', text: '' })
const dialog = reactive({ show: false, editing: false, busy: false, form: { name: '', description: '', color: '', is_active: true }, id: null })
const del = reactive({ show: false, cat: null, busy: false })

const commonCategories = [
  { name: 'Rent', icon: 'mdi-home-city', color: '#6366f1', description: 'Office or shop rent payments' },
  { name: 'Utilities', icon: 'mdi-flash', color: '#f59e0b', description: 'Electricity, water, internet' },
  { name: 'Salaries', icon: 'mdi-account-cash', color: '#22c55e', description: 'Staff salaries and wages' },
  { name: 'Supplies', icon: 'mdi-package-variant', color: '#06b6d4', description: 'Office and consumable supplies' },
  { name: 'Equipment', icon: 'mdi-tools', color: '#64748b', description: 'Equipment purchases and maintenance' },
  { name: 'Transport', icon: 'mdi-truck', color: '#3b82f6', description: 'Fuel, deliveries and travel' },
  { name: 'Marketing', icon: 'mdi-bullhorn', color: '#ec4899', description: 'Advertising and promotions' },
  { name: 'Maintenance', icon: 'mdi-wrench', color: '#a855f7', description: 'Repairs and upkeep' },
  { name: 'Insurance', icon: 'mdi-shield-check', color: '#14b8a6', description: 'Business insurance premiums' },
  { name: 'Taxes', icon: 'mdi-bank', color: '#ef4444', description: 'Government taxes and levies' },
  { name: 'Licenses', icon: 'mdi-certificate', color: '#84cc16', description: 'Permits and licenses' },
  { name: 'Miscellaneous', icon: 'mdi-dots-horizontal-circle', color: '#94a3b8', description: 'Other uncategorized expenses' },
]

const quickBusy = ref(false)
async function quickCreate(p) {
  quickBusy.value = true
  try {
    await r.create({ name: p.name, description: p.description, color: p.color, is_active: true })
    snack.text = `${p.name} added`; snack.color = 'success'; snack.show = true
    await r.list()
  } catch (e) {
    snack.text = e?.response?.data?.detail || e?.response?.data?.name?.[0] || 'Add failed.'
    snack.color = 'error'; snack.show = true
  } finally { quickBusy.value = false }
}
function applyPreset(p) {
  dialog.form.name = p.name
  dialog.form.description = p.description
  dialog.form.color = p.color
}

const colorPresets = [
  { name: 'Indigo', value: '#6366f1' },
  { name: 'Blue', value: '#3b82f6' },
  { name: 'Cyan', value: '#06b6d4' },
  { name: 'Teal', value: '#14b8a6' },
  { name: 'Green', value: '#22c55e' },
  { name: 'Lime', value: '#84cc16' },
  { name: 'Amber', value: '#f59e0b' },
  { name: 'Orange', value: '#f97316' },
  { name: 'Red', value: '#ef4444' },
  { name: 'Pink', value: '#ec4899' },
  { name: 'Purple', value: '#a855f7' },
  { name: 'Slate', value: '#64748b' },
]

function openNew() {
  dialog.editing = false; dialog.id = null
  dialog.form = { name: '', description: '', color: '', is_active: true }
  dialog.show = true
}
function openEdit(c) {
  dialog.editing = true; dialog.id = c.id
  dialog.form = { name: c.name, description: c.description, color: c.color, is_active: c.is_active }
  dialog.show = true
}
async function save() {
  dialog.busy = true
  try {
    if (dialog.editing) await r.update(dialog.id, dialog.form)
    else await r.create(dialog.form)
    snack.text = 'Saved'; snack.color = 'success'; snack.show = true
    dialog.show = false
    await r.list()
  } catch (e) {
    snack.text = e?.response?.data?.detail || e?.message || 'Save failed.'; snack.color = 'error'; snack.show = true
  } finally { dialog.busy = false }
}
function confirmDelete(c) { del.cat = c; del.show = true }
async function doDelete() {
  del.busy = true
  try {
    await r.remove(del.cat.id)
    snack.text = 'Deleted'; snack.color = 'success'; snack.show = true
    del.show = false
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Delete failed.'; snack.color = 'error'; snack.show = true
  } finally { del.busy = false }
}

onMounted(() => r.list())
</script>

<style scoped>
.exp-cat-shell { max-width: 1300px; margin: 0 auto; }
.cat-card { border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity)); transition: transform .15s, box-shadow .15s; }
.cat-card:hover { transform: translateY(-2px); box-shadow: 0 6px 16px rgba(0,0,0,0.06); }
</style>
