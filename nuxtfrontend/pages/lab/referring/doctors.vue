<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="indigo-lighten-5" size="48">
        <v-icon color="indigo-darken-2" size="28">mdi-stethoscope</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Referring Doctors</div>
        <div class="text-body-2 text-medium-emphasis">
          External clinicians sending lab work · {{ list.length }} total
        </div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh"
             :loading="r.loading.value" @click="reload">Refresh</v-btn>
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-tray-arrow-down"
             @click="exportCsv">Export</v-btn>
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-tray-arrow-up"
             @click="importDialog = true">Import</v-btn>
      <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openNew">New Doctor</v-btn>
    </div>

    <!-- KPIs -->
    <v-row dense>
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="3">
        <v-card flat rounded="lg" class="kpi pa-4">
          <div class="d-flex align-center">
            <v-avatar :color="k.color + '-lighten-5'" size="40" class="mr-3">
              <v-icon :color="k.color + '-darken-2'">{{ k.icon }}</v-icon>
            </v-avatar>
            <div class="min-width-0">
              <div class="text-overline text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h5 font-weight-bold">{{ k.value }}</div>
              <div v-if="k.hint" class="text-caption text-medium-emphasis">{{ k.hint }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Status pills + facility chips -->
    <v-card flat rounded="lg" class="mt-4 pa-3">
      <div class="d-flex flex-wrap align-center ga-2">
        <v-chip
          v-for="s in statusFilters" :key="s.key"
          :color="statusFilter === s.value ? 'primary' : undefined"
          :variant="statusFilter === s.value ? 'flat' : 'tonal'"
          size="small" @click="statusFilter = s.value"
        >
          {{ s.label }}<span class="ml-2 font-weight-bold">{{ s.count }}</span>
        </v-chip>

        <v-divider vertical class="mx-2" />

        <v-chip
          v-for="f in facilityChips" :key="f.value || 'all-fac'"
          :color="facilityFilter === f.value ? 'indigo' : undefined"
          :variant="facilityFilter === f.value ? 'flat' : 'tonal'"
          size="small" @click="facilityFilter = f.value"
        >
          <v-icon v-if="f.value === null" size="14" start>mdi-hospital-building</v-icon>
          <v-icon v-else size="14" start>mdi-hospital-marker</v-icon>
          {{ f.label }}
          <span v-if="f.count != null" class="ml-2 font-weight-bold">{{ f.count }}</span>
        </v-chip>

        <v-spacer />

        <v-btn-toggle v-model="view" mandatory density="compact" rounded="lg" color="primary">
          <v-btn value="table" icon="mdi-format-list-bulleted" size="small" />
          <v-btn value="grid" icon="mdi-view-grid-outline" size="small" />
        </v-btn-toggle>
      </div>
    </v-card>

    <!-- Filter bar -->
    <v-card flat rounded="lg" class="mt-3 pa-3">
      <v-row dense align="center">
        <v-col cols="12" md="5">
          <v-text-field
            v-model="r.search.value"
            prepend-inner-icon="mdi-magnify"
            placeholder="Search by name, specialty, license, phone or email…"
            variant="outlined" density="compact" hide-details clearable
          />
        </v-col>
        <v-col cols="6" md="3">
          <v-select
            v-model="specialtyFilter" :items="specialtyOptions"
            label="Specialty" variant="outlined" density="compact"
            prepend-inner-icon="mdi-doctor" hide-details clearable
          />
        </v-col>
        <v-col cols="6" md="2">
          <v-select
            v-model="sortBy" :items="sortOptions"
            label="Sort" variant="outlined" density="compact"
            prepend-inner-icon="mdi-sort" hide-details
          />
        </v-col>
        <v-col cols="12" md="2" class="d-flex justify-end">
          <v-btn variant="text" size="small" @click="resetFilters">
            <v-icon start size="16">mdi-filter-remove-outline</v-icon>Reset
          </v-btn>
        </v-col>
      </v-row>
    </v-card>

    <!-- Bulk action bar -->
    <v-slide-y-transition>
      <v-card v-if="selected.length" flat rounded="lg" class="mt-3 pa-3 bulk-bar">
        <div class="d-flex align-center ga-2">
          <v-icon color="primary">mdi-check-all</v-icon>
          <span class="font-weight-medium">{{ selected.length }} selected</span>
          <v-spacer />
          <v-btn size="small" variant="tonal" color="success" prepend-icon="mdi-check-circle"
                 :loading="bulkBusy" @click="bulkSetActive(true)">Activate</v-btn>
          <v-btn size="small" variant="tonal" color="warning" prepend-icon="mdi-cancel"
                 :loading="bulkBusy" @click="bulkSetActive(false)">Deactivate</v-btn>
          <v-btn size="small" variant="tonal" color="primary" prepend-icon="mdi-percent"
                 :loading="bulkBusy" @click="bulkCommissionDialog = true">Set Commission</v-btn>
          <v-btn size="small" variant="tonal" color="error" prepend-icon="mdi-delete"
                 :loading="bulkBusy" @click="bulkDelete">Delete</v-btn>
          <v-btn size="small" variant="text" @click="selected = []">Clear</v-btn>
        </div>
      </v-card>
    </v-slide-y-transition>

    <!-- Table view -->
    <v-card v-if="view === 'table'" flat rounded="lg" class="mt-3">
      <v-data-table
        v-model="selected"
        show-select
        :headers="headers"
        :items="filtered"
        :loading="r.loading.value"
        :items-per-page="20"
        item-value="id"
        hover
        class="doc-table"
        @click:row="(_, { item }) => openDetail(item)"
      >
        <template #loading><v-skeleton-loader type="table-row@5" /></template>
        <template #item.full_name="{ item }">
          <div class="d-flex align-center py-1">
            <v-avatar :color="avatarColor(item.full_name)" size="34" class="mr-2">
              <span class="text-white font-weight-bold">{{ initials(item.full_name) }}</span>
            </v-avatar>
            <div class="min-width-0">
              <div class="font-weight-medium text-truncate">Dr. {{ item.full_name }}</div>
              <div v-if="item.specialty" class="text-caption text-medium-emphasis text-truncate">
                {{ item.specialty }}
              </div>
            </div>
          </div>
        </template>
        <template #item.facility_name="{ item }">
          <div v-if="item.facility_name" class="d-flex align-center">
            <v-icon size="14" color="indigo" class="mr-1">mdi-hospital-building</v-icon>
            <span class="text-truncate" style="max-width:200px">{{ item.facility_name }}</span>
          </div>
          <span v-else class="text-medium-emphasis text-caption">independent</span>
        </template>
        <template #item.contact="{ item }">
          <div class="d-flex flex-column">
            <a v-if="item.phone" :href="`tel:${item.phone}`" class="text-caption text-decoration-none"
               @click.stop>
              <v-icon size="12" class="mr-1">mdi-phone</v-icon>{{ item.phone }}
            </a>
            <a v-if="item.email" :href="`mailto:${item.email}`" class="text-caption text-decoration-none"
               @click.stop>
              <v-icon size="12" class="mr-1">mdi-email</v-icon>{{ item.email }}
            </a>
            <span v-if="!item.phone && !item.email" class="text-medium-emphasis text-caption">—</span>
          </div>
        </template>
        <template #item.license_no="{ value }">
          <span v-if="value" class="font-monospace text-caption">{{ value }}</span>
          <span v-else class="text-medium-emphasis text-caption">—</span>
        </template>
        <template #item.commission_percent="{ value }">
          <v-chip v-if="Number(value) > 0" size="x-small" color="amber-darken-2" variant="tonal">
            {{ Number(value).toFixed(1) }}%
          </v-chip>
          <span v-else class="text-medium-emphasis text-caption">—</span>
        </template>
        <template #item.is_active="{ item }">
          <v-switch
            :model-value="item.is_active" color="success" hide-details density="compact" inset
            class="mt-0" @click.stop @update:model-value="(v) => toggleActive(item, v)"
          />
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end" @click.stop>
            <v-tooltip text="Call" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" :href="item.phone ? `tel:${item.phone}` : undefined"
                       :disabled="!item.phone"
                       icon="mdi-phone-outline" variant="text" size="small" color="success" />
              </template>
            </v-tooltip>
            <v-tooltip text="Email" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" :href="item.email ? `mailto:${item.email}` : undefined"
                       :disabled="!item.email"
                       icon="mdi-email-outline" variant="text" size="small" color="primary" />
              </template>
            </v-tooltip>
            <v-tooltip text="Edit" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-pencil-outline" variant="text" size="small"
                       color="primary" @click="openEdit(item)" />
              </template>
            </v-tooltip>
            <v-menu>
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" />
              </template>
              <v-list density="compact">
                <v-list-item prepend-icon="mdi-eye-outline" title="View details" @click="openDetail(item)" />
                <v-list-item prepend-icon="mdi-content-copy" title="Duplicate" @click="duplicate(item)" />
                <v-list-item prepend-icon="mdi-content-copy" title="Copy contact"
                             @click="copyContact(item)" />
                <v-list-item
                  :prepend-icon="item.is_active ? 'mdi-cancel' : 'mdi-check-circle'"
                  :title="item.is_active ? 'Deactivate' : 'Activate'"
                  @click="toggleActive(item)"
                />
                <v-divider />
                <v-list-item prepend-icon="mdi-delete" title="Delete" base-color="error"
                             @click="confirmDelete(item)" />
              </v-list>
            </v-menu>
          </div>
        </template>
        <template #no-data>
          <div class="pa-8 text-center">
            <v-icon size="56" color="grey-lighten-1">mdi-doctor</v-icon>
            <div class="text-subtitle-1 font-weight-medium mt-2">No doctors found</div>
            <div class="text-body-2 text-medium-emphasis mb-4">
              Adjust your filters or add your first referring doctor.
            </div>
            <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openNew">New Doctor</v-btn>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- Grid view -->
    <div v-else class="mt-3">
      <div v-if="r.loading.value" class="d-flex justify-center pa-12">
        <v-progress-circular indeterminate color="primary" />
      </div>
      <div v-else-if="!filtered.length" class="pa-8 text-center">
        <v-icon size="56" color="grey-lighten-1">mdi-doctor</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-2">No doctors found</div>
        <div class="text-body-2 text-medium-emphasis mb-4">Try adjusting your filters.</div>
        <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openNew">New Doctor</v-btn>
      </div>
      <v-row v-else dense>
        <v-col v-for="d in filtered" :key="d.id" cols="12" sm="6" md="4" lg="3">
          <v-card flat rounded="lg" class="doc-card pa-4 h-100" hover @click="openDetail(d)">
            <div class="doc-band" :style="{ background: avatarHex(d.full_name) }" />
            <div class="d-flex align-center mb-3">
              <v-avatar :color="avatarColor(d.full_name)" size="44" class="mr-3">
                <span class="text-white font-weight-bold">{{ initials(d.full_name) }}</span>
              </v-avatar>
              <div class="min-width-0 flex-grow-1">
                <div class="font-weight-medium text-truncate">Dr. {{ d.full_name }}</div>
                <div v-if="d.specialty" class="text-caption text-medium-emphasis text-truncate">
                  {{ d.specialty }}
                </div>
              </div>
              <v-chip size="x-small" :color="d.is_active ? 'success' : 'grey'" variant="tonal">
                {{ d.is_active ? 'Active' : 'Inactive' }}
              </v-chip>
            </div>

            <div class="doc-meta">
              <div v-if="d.facility_name" class="d-flex align-center text-caption mb-1">
                <v-icon size="14" color="indigo" class="mr-2">mdi-hospital-building</v-icon>
                <span class="text-truncate">{{ d.facility_name }}</span>
              </div>
              <div v-if="d.license_no" class="d-flex align-center text-caption mb-1">
                <v-icon size="14" color="grey" class="mr-2">mdi-card-account-details-outline</v-icon>
                <span class="font-monospace">{{ d.license_no }}</span>
              </div>
              <div v-if="d.phone" class="d-flex align-center text-caption mb-1">
                <v-icon size="14" color="success" class="mr-2">mdi-phone</v-icon>
                <span>{{ d.phone }}</span>
              </div>
              <div v-if="d.email" class="d-flex align-center text-caption mb-1">
                <v-icon size="14" color="primary" class="mr-2">mdi-email</v-icon>
                <span class="text-truncate">{{ d.email }}</span>
              </div>
            </div>

            <v-divider class="my-3" />
            <div class="d-flex align-center justify-space-between">
              <div>
                <div class="text-caption text-medium-emphasis">Commission</div>
                <div class="font-weight-bold text-amber-darken-3">
                  {{ Number(d.commission_percent || 0).toFixed(1) }}%
                </div>
              </div>
              <div class="d-flex" @click.stop>
                <v-btn :href="d.phone ? `tel:${d.phone}` : undefined" :disabled="!d.phone"
                       icon="mdi-phone-outline" variant="text" size="small" color="success" />
                <v-btn :href="d.email ? `mailto:${d.email}` : undefined" :disabled="!d.email"
                       icon="mdi-email-outline" variant="text" size="small" color="primary" />
                <v-btn icon="mdi-pencil-outline" variant="text" size="small" color="primary"
                       @click="openEdit(d)" />
                <v-btn icon="mdi-delete-outline" variant="text" size="small" color="error"
                       @click="confirmDelete(d)" />
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>
    </div>

    <!-- Create / Edit dialog -->
    <v-dialog v-model="formDialog" max-width="780" scrollable persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar color="indigo-lighten-5" size="40" class="mr-3">
            <v-icon color="indigo-darken-2">{{ form.id ? 'mdi-pencil' : 'mdi-plus' }}</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">REFERRING DOCTOR</div>
            <div class="text-h6 font-weight-bold">{{ form.id ? 'Edit doctor' : 'New doctor' }}</div>
          </div>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" @click="formDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          <v-form ref="formRef" @submit.prevent="save">
            <v-row dense>
              <v-col cols="12" sm="8">
                <v-text-field v-model="form.full_name" label="Full name *"
                              placeholder="e.g. Jane Smith"
                              prepend-inner-icon="mdi-account"
                              variant="outlined" density="comfortable" :rules="[required]" />
              </v-col>
              <v-col cols="12" sm="4">
                <v-combobox v-model="form.specialty" :items="specialtyList"
                            label="Specialty" prepend-inner-icon="mdi-doctor"
                            variant="outlined" density="comfortable" />
              </v-col>

              <v-col cols="12" sm="6">
                <v-autocomplete
                  v-model="form.facility" :items="facilities" :loading="fac.loading.value"
                  item-title="name" item-value="id"
                  label="Facility" prepend-inner-icon="mdi-hospital-building"
                  variant="outlined" density="comfortable" clearable
                />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.license_no" label="License No."
                              prepend-inner-icon="mdi-card-account-details-outline"
                              variant="outlined" density="comfortable" />
              </v-col>

              <v-col cols="12" sm="6">
                <v-text-field v-model="form.phone" label="Phone"
                              prepend-inner-icon="mdi-phone"
                              variant="outlined" density="comfortable"
                              :rules="form.phone ? [phoneRule] : []" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.email" label="Email" type="email"
                              prepend-inner-icon="mdi-email"
                              variant="outlined" density="comfortable"
                              :rules="form.email ? [emailRule] : []" />
              </v-col>

              <v-col cols="12" sm="6">
                <v-text-field
                  v-model.number="form.commission_percent" type="number" min="0" max="100" step="0.5"
                  label="Commission %" prepend-inner-icon="mdi-percent"
                  variant="outlined" density="comfortable"
                  hint="Paid to doctor on referred orders"
                  persistent-hint
                />
              </v-col>
              <v-col cols="12" sm="6" class="d-flex align-center">
                <v-switch v-model="form.is_active" color="success" inset hide-details
                          label="Active — can refer patients" />
              </v-col>
            </v-row>
          </v-form>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="formDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" :loading="r.saving.value" @click="save">
            <v-icon start>mdi-content-save</v-icon>{{ form.id ? 'Update Doctor' : 'Create Doctor' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Detail dialog -->
    <v-dialog v-model="detailDialog" max-width="640" scrollable>
      <v-card v-if="detailItem" rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar :color="avatarColor(detailItem.full_name)" size="48" class="mr-3">
            <span class="text-white font-weight-bold">{{ initials(detailItem.full_name) }}</span>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">{{ detailItem.specialty || 'CLINICIAN' }}</div>
            <div class="text-h6 font-weight-bold">Dr. {{ detailItem.full_name }}</div>
          </div>
          <v-spacer />
          <v-chip size="small" :color="detailItem.is_active ? 'success' : 'grey'" variant="tonal" class="mr-2">
            {{ detailItem.is_active ? 'Active' : 'Inactive' }}
          </v-chip>
          <v-btn icon="mdi-close" variant="text" @click="detailDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          <v-list density="compact" class="pa-0">
            <v-list-item v-if="detailItem.facility_name" prepend-icon="mdi-hospital-building"
                         :title="detailItem.facility_name" subtitle="Facility" />
            <v-list-item v-if="detailItem.license_no" prepend-icon="mdi-card-account-details-outline"
                         :title="detailItem.license_no" subtitle="License No." />
            <v-list-item v-if="detailItem.phone" prepend-icon="mdi-phone"
                         :href="`tel:${detailItem.phone}`" :title="detailItem.phone" subtitle="Phone" />
            <v-list-item v-if="detailItem.email" prepend-icon="mdi-email"
                         :href="`mailto:${detailItem.email}`" :title="detailItem.email" subtitle="Email" />
            <v-list-item prepend-icon="mdi-percent" subtitle="Commission rate"
                         :title="`${Number(detailItem.commission_percent || 0).toFixed(1)} %`" />
            <v-list-item prepend-icon="mdi-calendar"
                         :title="formatDate(detailItem.created_at)" subtitle="Added" />
          </v-list>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-btn variant="text" prepend-icon="mdi-content-copy" @click="duplicate(detailItem)">Duplicate</v-btn>
          <v-btn variant="text" prepend-icon="mdi-content-copy" @click="copyContact(detailItem)">Copy</v-btn>
          <v-spacer />
          <v-btn variant="text" @click="detailDialog = false">Close</v-btn>
          <v-btn color="primary" rounded="lg" prepend-icon="mdi-pencil" @click="openEdit(detailItem)">Edit</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Bulk commission dialog -->
    <v-dialog v-model="bulkCommissionDialog" max-width="420" persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-icon color="amber-darken-2" class="mr-2">mdi-percent</v-icon>
          Set commission for {{ selected.length }} doctor(s)
        </v-card-title>
        <v-card-text>
          <v-text-field v-model.number="bulkCommissionValue" type="number" min="0" max="100" step="0.5"
                        label="Commission %" variant="outlined" density="comfortable" autofocus />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="bulkCommissionDialog = false">Cancel</v-btn>
          <v-btn color="primary" :loading="bulkBusy" @click="bulkSetCommission">Apply</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Import dialog -->
    <v-dialog v-model="importDialog" max-width="520">
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-icon color="indigo" class="mr-2">mdi-tray-arrow-up</v-icon>
          Import doctors from CSV
        </v-card-title>
        <v-card-text>
          <p class="text-body-2 text-medium-emphasis mb-3">
            Upload a CSV with columns:
            <code>full_name, specialty, license_no, phone, email, commission_percent, facility</code>.
            The facility column is matched by name (existing facilities only).
          </p>
          <v-file-input v-model="importFile" label="CSV file" accept=".csv" variant="outlined"
                        density="comfortable" prepend-icon="" prepend-inner-icon="mdi-file-delimited" />
          <v-alert v-if="importError" type="error" variant="tonal" density="compact" class="mt-2">
            {{ importError }}
          </v-alert>
          <v-alert v-if="importPreview.length" type="info" variant="tonal" density="compact" class="mt-2">
            Ready to import {{ importPreview.length }} row(s).
          </v-alert>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="importDialog = false">Cancel</v-btn>
          <v-btn color="primary" :loading="importBusy" :disabled="!importPreview.length"
                 @click="runImport">Import</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Delete confirm -->
    <v-dialog v-model="deleteDialog.show" max-width="420" persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center">
          <v-icon color="error" class="mr-2">mdi-alert-circle</v-icon>Delete Doctor
        </v-card-title>
        <v-card-text>
          Delete <strong>Dr. {{ deleteDialog.item?.full_name }}</strong>? This cannot be undone.
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog.show = false">Cancel</v-btn>
          <v-btn color="error" variant="flat" :loading="deleteDialog.busy" @click="doDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'

const r = useResource('/lab/referring-doctors/')
const fac = useResource('/lab/referring-facilities/')

const view = ref('table')
const statusFilter = ref(null)
const facilityFilter = ref(null)
const specialtyFilter = ref(null)
const sortBy = ref('name_asc')
const selected = ref([])
const bulkBusy = ref(false)

const formDialog = ref(false)
const formRef = ref(null)
const form = ref(emptyForm())
const detailDialog = ref(false)
const detailItem = ref(null)
const deleteDialog = reactive({ show: false, item: null, busy: false })
const snack = reactive({ show: false, color: 'success', text: '' })

const bulkCommissionDialog = ref(false)
const bulkCommissionValue = ref(0)

const importDialog = ref(false)
const importFile = ref(null)
const importPreview = ref([])
const importError = ref('')
const importBusy = ref(false)

const specialtyList = [
  'General Practice', 'Pediatrics', 'Internal Medicine', 'Cardiology', 'Endocrinology',
  'Gynecology & Obstetrics', 'Surgery', 'Orthopedics', 'Neurology', 'Dermatology',
  'ENT', 'Ophthalmology', 'Urology', 'Oncology', 'Psychiatry', 'Dentistry',
  'Radiology', 'Pathology', 'Anesthesiology', 'Emergency Medicine',
]

const sortOptions = [
  { title: 'Name (A → Z)', value: 'name_asc' },
  { title: 'Name (Z → A)', value: 'name_desc' },
  { title: 'Commission (high → low)', value: 'commission_desc' },
  { title: 'Commission (low → high)', value: 'commission_asc' },
  { title: 'Newest', value: 'newest' },
  { title: 'Oldest', value: 'oldest' },
]

const headers = [
  { title: 'Doctor', key: 'full_name' },
  { title: 'Facility', key: 'facility_name' },
  { title: 'Contact', key: 'contact', sortable: false },
  { title: 'License', key: 'license_no', width: 130 },
  { title: 'Commission', key: 'commission_percent', width: 120 },
  { title: 'Active', key: 'is_active', width: 90, sortable: false },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 200 },
]

const STATUS_FILTERS = [
  { label: 'All', value: null, key: 'all' },
  { label: 'Active', value: 'active', key: 'active' },
  { label: 'Inactive', value: 'inactive', key: 'inactive' },
  { label: 'Independent', value: 'independent', key: 'independent' },
  { label: 'With facility', value: 'affiliated', key: 'affiliated' },
  { label: 'Earns commission', value: 'with_commission', key: 'with_commission' },
]

const list = computed(() => r.items.value || [])
const facilities = computed(() => fac.items.value || [])

const specialtyOptions = computed(() => {
  const set = new Set(list.value.map(d => d.specialty).filter(Boolean))
  return [...set].sort()
})

const statusFilters = computed(() => {
  const arr = list.value
  const counts = {
    all: arr.length,
    active: arr.filter(d => d.is_active).length,
    inactive: arr.filter(d => !d.is_active).length,
    independent: arr.filter(d => !d.facility).length,
    affiliated: arr.filter(d => !!d.facility).length,
    with_commission: arr.filter(d => Number(d.commission_percent) > 0).length,
  }
  return STATUS_FILTERS.map(s => ({ ...s, count: counts[s.key] }))
})

const facilityChips = computed(() => {
  const counts = list.value.reduce((acc, d) => {
    if (d.facility_name) acc[d.facility_name] = (acc[d.facility_name] || 0) + 1
    return acc
  }, {})
  const tops = Object.entries(counts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 6)
    .map(([name, n]) => {
      const f = facilities.value.find(x => x.name === name)
      return { label: name, value: f?.id ?? name, count: n }
    })
  return [{ label: 'All facilities', value: null }, ...tops]
})

const filtered = computed(() => {
  let arr = r.filtered.value || []
  if (statusFilter.value === 'active') arr = arr.filter(d => d.is_active)
  if (statusFilter.value === 'inactive') arr = arr.filter(d => !d.is_active)
  if (statusFilter.value === 'independent') arr = arr.filter(d => !d.facility)
  if (statusFilter.value === 'affiliated') arr = arr.filter(d => !!d.facility)
  if (statusFilter.value === 'with_commission') arr = arr.filter(d => Number(d.commission_percent) > 0)
  if (facilityFilter.value != null) {
    arr = arr.filter(d => d.facility === facilityFilter.value || d.facility_name === facilityFilter.value)
  }
  if (specialtyFilter.value) arr = arr.filter(d => d.specialty === specialtyFilter.value)
  arr = [...arr]
  switch (sortBy.value) {
    case 'name_desc': arr.sort((a, b) => (b.full_name || '').localeCompare(a.full_name || '')); break
    case 'commission_asc':
      arr.sort((a, b) => Number(a.commission_percent || 0) - Number(b.commission_percent || 0)); break
    case 'commission_desc':
      arr.sort((a, b) => Number(b.commission_percent || 0) - Number(a.commission_percent || 0)); break
    case 'newest': arr.sort((a, b) => new Date(b.created_at || 0) - new Date(a.created_at || 0)); break
    case 'oldest': arr.sort((a, b) => new Date(a.created_at || 0) - new Date(b.created_at || 0)); break
    default: arr.sort((a, b) => (a.full_name || '').localeCompare(b.full_name || ''))
  }
  return arr
})

const kpis = computed(() => {
  const arr = list.value
  const active = arr.filter(d => d.is_active).length
  const facCount = new Set(arr.map(d => d.facility).filter(Boolean)).size
  const indie = arr.filter(d => !d.facility).length
  const withCom = arr.filter(d => Number(d.commission_percent) > 0)
  const avgCom = withCom.length
    ? withCom.reduce((s, d) => s + Number(d.commission_percent || 0), 0) / withCom.length
    : 0
  return [
    { label: 'Total Doctors', value: arr.length, icon: 'mdi-stethoscope', color: 'indigo',
      hint: `${active} active` },
    { label: 'Facilities', value: facCount, icon: 'mdi-hospital-building', color: 'cyan',
      hint: `${indie} independent` },
    { label: 'Earning Commission', value: withCom.length, icon: 'mdi-percent', color: 'amber',
      hint: `${avgCom.toFixed(1)}% avg` },
    { label: 'Specialties', value: specialtyOptions.value.length, icon: 'mdi-doctor', color: 'teal',
      hint: 'distinct fields' },
  ]
})

// ─── Helpers ───
function emptyForm () {
  return {
    id: null, full_name: '', specialty: '', facility: null, license_no: '',
    phone: '', email: '', commission_percent: 0, is_active: true,
  }
}
const required = v => (!!v && String(v).trim() !== '') || 'Required'
const emailRule = v => !v || /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(v) || 'Invalid email'
const phoneRule = v => !v || /^[+\d\s().-]{6,}$/.test(v) || 'Invalid phone'

function initials (name) {
  if (!name) return '?'
  const parts = name.trim().split(/\s+/)
  return ((parts[0]?.[0] || '') + (parts[1]?.[0] || '')).toUpperCase() || '?'
}
const PALETTE = [
  { c: 'indigo-darken-2', h: '#3949ab' },
  { c: 'teal-darken-2', h: '#00897b' },
  { c: 'deep-purple-darken-2', h: '#5e35b1' },
  { c: 'pink-darken-2', h: '#d81b60' },
  { c: 'orange-darken-2', h: '#fb8c00' },
  { c: 'green-darken-2', h: '#43a047' },
  { c: 'red-darken-2', h: '#e53935' },
  { c: 'blue-darken-2', h: '#1e88e5' },
  { c: 'cyan-darken-2', h: '#00acc1' },
  { c: 'brown-darken-2', h: '#6d4c41' },
]
function hashIdx (s) {
  let h = 0
  for (let i = 0; i < (s || '').length; i++) h = (h * 31 + s.charCodeAt(i)) & 0xffffff
  return Math.abs(h) % PALETTE.length
}
function avatarColor (s) { return PALETTE[hashIdx(s)].c }
function avatarHex (s) { return PALETTE[hashIdx(s)].h }

function formatDate (s) {
  if (!s) return '—'
  return new Date(s).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })
}

// ─── Actions ───
function openNew () { form.value = emptyForm(); formDialog.value = true }
function openEdit (it) {
  form.value = { ...emptyForm(), ...it }
  detailDialog.value = false
  formDialog.value = true
}
function openDetail (it) { detailItem.value = it; detailDialog.value = true }
function duplicate (it) {
  form.value = {
    ...emptyForm(), ...it, id: null,
    full_name: `${it.full_name} (Copy)`,
    license_no: '',
  }
  detailDialog.value = false
  formDialog.value = true
}
async function copyContact (it) {
  const txt = [
    `Dr. ${it.full_name}`,
    it.specialty,
    it.facility_name,
    it.phone && `Phone: ${it.phone}`,
    it.email && `Email: ${it.email}`,
    it.license_no && `License: ${it.license_no}`,
  ].filter(Boolean).join('\n')
  try {
    await navigator.clipboard.writeText(txt)
    notify('Contact copied to clipboard')
  } catch { notify('Copy failed', 'error') }
}
async function save () {
  const { valid } = (await formRef.value?.validate?.()) || { valid: true }
  if (!valid) return
  try {
    const payload = {
      ...form.value,
      commission_percent: Number(form.value.commission_percent || 0),
    }
    if (payload.id) await r.update(payload.id, payload)
    else await r.create(payload)
    formDialog.value = false
    notify(`Doctor ${form.value.id ? 'updated' : 'created'} successfully`)
    await r.list()
  } catch (e) { notify(r.error.value || 'Save failed', 'error') }
}
async function toggleActive (it, value) {
  const next = value === undefined ? !it.is_active : value
  try {
    await r.update(it.id, { is_active: next })
    it.is_active = next
    notify(`Doctor ${next ? 'activated' : 'deactivated'}`)
  } catch (e) { notify(r.error.value || 'Update failed', 'error') }
}
function confirmDelete (it) { deleteDialog.item = it; deleteDialog.show = true }
async function doDelete () {
  deleteDialog.busy = true
  try {
    await r.remove(deleteDialog.item.id)
    notify('Doctor deleted')
    deleteDialog.show = false
    detailDialog.value = false
  } catch (e) { notify(r.error.value || 'Delete failed', 'error') }
  finally { deleteDialog.busy = false }
}

// ─── Bulk ───
async function bulkSetActive (active) {
  bulkBusy.value = true
  try {
    await Promise.all(selected.value.map(id => r.update(id, { is_active: active })))
    notify(`${selected.value.length} doctor(s) ${active ? 'activated' : 'deactivated'}`)
    selected.value = []
    await r.list()
  } catch (e) { notify(r.error.value || 'Bulk update failed', 'error') }
  finally { bulkBusy.value = false }
}
async function bulkSetCommission () {
  bulkBusy.value = true
  try {
    const value = Number(bulkCommissionValue.value || 0)
    await Promise.all(selected.value.map(id => r.update(id, { commission_percent: value })))
    notify(`Commission set to ${value}% for ${selected.value.length} doctor(s)`)
    bulkCommissionDialog.value = false
    selected.value = []
    await r.list()
  } catch (e) { notify(r.error.value || 'Bulk update failed', 'error') }
  finally { bulkBusy.value = false }
}
async function bulkDelete () {
  if (!confirm(`Delete ${selected.value.length} doctor(s)? This cannot be undone.`)) return
  bulkBusy.value = true
  try {
    await Promise.all(selected.value.map(id => r.remove(id)))
    notify(`${selected.value.length} doctor(s) deleted`)
    selected.value = []
  } catch (e) { notify(r.error.value || 'Bulk delete failed', 'error') }
  finally { bulkBusy.value = false }
}

// ─── Misc ───
function resetFilters () {
  statusFilter.value = null
  facilityFilter.value = null
  specialtyFilter.value = null
  sortBy.value = 'name_asc'
  r.search.value = ''
}
function reload () { r.list(); fac.list() }
function notify (text, color = 'success') { snack.text = text; snack.color = color; snack.show = true }

function exportCsv () {
  const rows = filtered.value
  if (!rows.length) return
  const cols = ['full_name', 'specialty', 'facility', 'license_no', 'phone', 'email', 'commission_percent', 'active']
  const esc = v => `"${String(v ?? '').replace(/"/g, '""')}"`
  const body = rows.map(d => [
    esc(d.full_name), esc(d.specialty), esc(d.facility_name),
    esc(d.license_no), esc(d.phone), esc(d.email),
    Number(d.commission_percent || 0), d.is_active ? 'yes' : 'no',
  ].join(',')).join('\n')
  const blob = new Blob([cols.join(',') + '\n' + body], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `referring-doctors_${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

// ─── Import ───
function parseCsv (text) {
  const lines = text.split(/\r?\n/).filter(l => l.trim())
  if (!lines.length) return []
  const split = (line) => {
    const out = []; let cur = ''; let q = false
    for (let i = 0; i < line.length; i++) {
      const c = line[i]
      if (q) {
        if (c === '"' && line[i + 1] === '"') { cur += '"'; i++ }
        else if (c === '"') q = false
        else cur += c
      } else {
        if (c === '"') q = true
        else if (c === ',') { out.push(cur); cur = '' }
        else cur += c
      }
    }
    out.push(cur)
    return out.map(s => s.trim())
  }
  const header = split(lines[0]).map(h => h.toLowerCase())
  return lines.slice(1).map(line => {
    const cells = split(line)
    const row = {}
    header.forEach((h, i) => { row[h] = cells[i] ?? '' })
    return row
  })
}

watch(importFile, async (f) => {
  importError.value = ''
  importPreview.value = []
  if (!f) return
  const file = Array.isArray(f) ? f[0] : f
  if (!file) return
  try {
    const text = await file.text()
    const rows = parseCsv(text)
    if (!rows.length) { importError.value = 'CSV is empty'; return }
    if (!('full_name' in rows[0])) { importError.value = 'Missing "full_name" column'; return }
    importPreview.value = rows
  } catch (e) { importError.value = 'Could not read file' }
})

async function runImport () {
  importBusy.value = true
  let ok = 0, fail = 0
  try {
    for (const row of importPreview.value) {
      try {
        const facId = row.facility
          ? facilities.value.find(f => f.name?.toLowerCase() === row.facility.toLowerCase())?.id ?? null
          : null
        await r.create({
          full_name: row.full_name,
          specialty: row.specialty || '',
          license_no: row.license_no || '',
          phone: row.phone || '',
          email: row.email || '',
          commission_percent: Number(row.commission_percent || 0),
          facility: facId,
          is_active: true,
        })
        ok++
      } catch { fail++ }
    }
    notify(`Imported ${ok} doctor(s)${fail ? `, ${fail} failed` : ''}`, fail ? 'warning' : 'success')
    importDialog.value = false
    importFile.value = null
    importPreview.value = []
    await r.list()
  } finally { importBusy.value = false }
}

onMounted(() => { r.list(); fac.list() })
</script>

<style scoped>
.kpi { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.doc-table :deep(tbody tr) { cursor: pointer; }
.doc-card {
  position: relative;
  overflow: hidden;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  cursor: pointer;
  transition: transform 120ms ease, box-shadow 120ms ease;
}
.doc-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.06); }
.doc-band {
  position: absolute; top: 0; left: 0; right: 0; height: 3px;
}
.doc-meta a { color: inherit; }
.bulk-bar {
  border: 1px solid rgba(var(--v-theme-primary), 0.2);
  background: rgba(var(--v-theme-primary), 0.04);
}
.min-width-0 { min-width: 0; }
.font-monospace { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
</style>
