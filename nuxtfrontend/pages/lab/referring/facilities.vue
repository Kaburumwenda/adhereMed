<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="indigo-lighten-5" size="48">
        <v-icon color="indigo-darken-2" size="28">mdi-hospital-building</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Referring Facilities</div>
        <div class="text-body-2 text-medium-emphasis">
          Hospitals, clinics &amp; partners that send work to your lab · {{ list.length }} total
        </div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh"
             :loading="r.loading.value" @click="reload">Refresh</v-btn>
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-tray-arrow-down"
             @click="exportCsv">Export</v-btn>
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-tray-arrow-up"
             @click="importDialog = true">Import</v-btn>
      <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openNew">New Facility</v-btn>
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

    <!-- Status pills -->
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
          v-for="t in topFacilityTypes" :key="t.value || 'all-type'"
          :color="typeFilter === t.value ? 'indigo' : undefined"
          :variant="typeFilter === t.value ? 'flat' : 'tonal'"
          size="small" @click="typeFilter = t.value"
        >
          <v-icon size="14" start>{{ typeIcon(t.value) }}</v-icon>
          {{ t.label }}
          <span v-if="t.count != null" class="ml-2 font-weight-bold">{{ t.count }}</span>
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
            placeholder="Search by name, contact person, phone, email or address…"
            variant="outlined" density="compact" hide-details clearable
          />
        </v-col>
        <v-col cols="6" md="3">
          <v-select
            v-model="discountFilter" :items="discountOptions"
            label="Discount" variant="outlined" density="compact"
            prepend-inner-icon="mdi-tag-outline" hide-details clearable
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
          <v-btn size="small" variant="tonal" color="primary" prepend-icon="mdi-tag-outline"
                 :loading="bulkBusy" @click="bulkDiscountDialog = true">Set Discount</v-btn>
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
        class="fac-table"
        @click:row="(_, { item }) => openDetail(item)"
      >
        <template #loading><v-skeleton-loader type="table-row@5" /></template>
        <template #item.name="{ item }">
          <div class="d-flex align-center py-1">
            <v-avatar :color="avatarColor(item.name)" size="34" class="mr-2">
              <v-icon size="18" color="white">{{ typeIcon(facilityType(item)) }}</v-icon>
            </v-avatar>
            <div class="min-width-0">
              <div class="font-weight-medium text-truncate">{{ item.name }}</div>
              <div class="text-caption text-medium-emphasis text-truncate" style="max-width:280px">
                <span v-if="item.contact_person">{{ item.contact_person }} · </span>
                <span class="text-capitalize">{{ facilityType(item) }}</span>
              </div>
            </div>
          </div>
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
        <template #item.address="{ value }">
          <span v-if="value" class="text-caption text-truncate d-inline-block" style="max-width:240px"
                :title="value">{{ value }}</span>
          <span v-else class="text-medium-emphasis text-caption">—</span>
        </template>
        <template #item.doctors_count="{ item }">
          <v-chip size="x-small" :color="(item._doctorCount || 0) > 0 ? 'indigo' : 'grey'" variant="tonal">
            <v-icon size="12" start>mdi-stethoscope</v-icon>
            {{ item._doctorCount || 0 }}
          </v-chip>
        </template>
        <template #item.discount_percent="{ value }">
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
            <v-tooltip text="Map" location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" :href="item.address ? mapUrl(item.address) : undefined"
                       target="_blank" :disabled="!item.address"
                       icon="mdi-map-marker-outline" variant="text" size="small" color="error" />
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
                <v-list-item prepend-icon="mdi-stethoscope" title="View doctors" @click="viewDoctors(item)" />
                <v-list-item prepend-icon="mdi-content-copy" title="Duplicate" @click="duplicate(item)" />
                <v-list-item prepend-icon="mdi-content-copy" title="Copy contact" @click="copyContact(item)" />
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
            <v-icon size="56" color="grey-lighten-1">mdi-hospital-building</v-icon>
            <div class="text-subtitle-1 font-weight-medium mt-2">No facilities found</div>
            <div class="text-body-2 text-medium-emphasis mb-4">
              Adjust your filters or add your first referring facility.
            </div>
            <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openNew">New Facility</v-btn>
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
        <v-icon size="56" color="grey-lighten-1">mdi-hospital-building</v-icon>
        <div class="text-subtitle-1 font-weight-medium mt-2">No facilities found</div>
        <div class="text-body-2 text-medium-emphasis mb-4">Try adjusting your filters.</div>
        <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openNew">New Facility</v-btn>
      </div>
      <v-row v-else dense>
        <v-col v-for="f in filtered" :key="f.id" cols="12" sm="6" md="4" lg="3">
          <v-card flat rounded="lg" class="fac-card pa-4 h-100" hover @click="openDetail(f)">
            <div class="fac-band" :style="{ background: avatarHex(f.name) }" />
            <div class="d-flex align-center mb-3">
              <v-avatar :color="avatarColor(f.name)" size="44" class="mr-3">
                <v-icon size="22" color="white">{{ typeIcon(facilityType(f)) }}</v-icon>
              </v-avatar>
              <div class="min-width-0 flex-grow-1">
                <div class="font-weight-medium text-truncate">{{ f.name }}</div>
                <div class="text-caption text-medium-emphasis text-capitalize">
                  {{ facilityType(f) }}
                </div>
              </div>
              <v-chip size="x-small" :color="f.is_active ? 'success' : 'grey'" variant="tonal">
                {{ f.is_active ? 'Active' : 'Inactive' }}
              </v-chip>
            </div>

            <div class="fac-meta">
              <div v-if="f.contact_person" class="d-flex align-center text-caption mb-1">
                <v-icon size="14" color="indigo" class="mr-2">mdi-account</v-icon>
                <span class="text-truncate">{{ f.contact_person }}</span>
              </div>
              <div v-if="f.phone" class="d-flex align-center text-caption mb-1">
                <v-icon size="14" color="success" class="mr-2">mdi-phone</v-icon>
                <span>{{ f.phone }}</span>
              </div>
              <div v-if="f.email" class="d-flex align-center text-caption mb-1">
                <v-icon size="14" color="primary" class="mr-2">mdi-email</v-icon>
                <span class="text-truncate">{{ f.email }}</span>
              </div>
              <div v-if="f.address" class="d-flex align-center text-caption mb-1">
                <v-icon size="14" color="error" class="mr-2">mdi-map-marker</v-icon>
                <span class="text-truncate">{{ f.address }}</span>
              </div>
            </div>

            <v-divider class="my-3" />
            <div class="d-flex align-center justify-space-between">
              <div class="d-flex ga-2">
                <v-chip size="x-small" :color="(f._doctorCount || 0) > 0 ? 'indigo' : 'grey'" variant="tonal">
                  <v-icon size="12" start>mdi-stethoscope</v-icon>{{ f._doctorCount || 0 }} doctors
                </v-chip>
                <v-chip v-if="Number(f.discount_percent) > 0" size="x-small" color="amber-darken-2" variant="tonal">
                  <v-icon size="12" start>mdi-tag</v-icon>{{ Number(f.discount_percent).toFixed(1) }}%
                </v-chip>
              </div>
              <div class="d-flex" @click.stop>
                <v-btn :href="f.phone ? `tel:${f.phone}` : undefined" :disabled="!f.phone"
                       icon="mdi-phone-outline" variant="text" size="small" color="success" />
                <v-btn :href="f.email ? `mailto:${f.email}` : undefined" :disabled="!f.email"
                       icon="mdi-email-outline" variant="text" size="small" color="primary" />
                <v-btn icon="mdi-pencil-outline" variant="text" size="small" color="primary"
                       @click="openEdit(f)" />
                <v-btn icon="mdi-delete-outline" variant="text" size="small" color="error"
                       @click="confirmDelete(f)" />
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
            <div class="text-overline text-medium-emphasis">REFERRING FACILITY</div>
            <div class="text-h6 font-weight-bold">{{ form.id ? 'Edit facility' : 'New facility' }}</div>
          </div>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" @click="formDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          <v-form ref="formRef" @submit.prevent="save">
            <v-row dense>
              <v-col cols="12">
                <v-text-field v-model="form.name" label="Facility name *"
                              placeholder="e.g. Aga Khan Clinic — Westlands"
                              prepend-inner-icon="mdi-hospital-building"
                              variant="outlined" density="comfortable" :rules="[required]" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field v-model="form.contact_person" label="Contact person"
                              prepend-inner-icon="mdi-account"
                              variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12" sm="6">
                <v-text-field
                  v-model.number="form.discount_percent" type="number" min="0" max="100" step="0.5"
                  label="Discount %" prepend-inner-icon="mdi-tag-outline"
                  variant="outlined" density="comfortable"
                  hint="Applied to lab orders from this facility"
                  persistent-hint
                />
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
              <v-col cols="12">
                <v-textarea v-model="form.address" label="Address" rows="2" auto-grow
                            prepend-inner-icon="mdi-map-marker-outline"
                            variant="outlined" density="comfortable" />
              </v-col>
              <v-col cols="12">
                <v-switch v-model="form.is_active" color="success" inset hide-details
                          label="Active — accepting referrals" />
              </v-col>
            </v-row>
          </v-form>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-spacer />
          <v-btn variant="text" @click="formDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" :loading="r.saving.value" @click="save">
            <v-icon start>mdi-content-save</v-icon>{{ form.id ? 'Update Facility' : 'Create Facility' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Detail dialog -->
    <v-dialog v-model="detailDialog" max-width="720" scrollable>
      <v-card v-if="detailItem" rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-avatar :color="avatarColor(detailItem.name)" size="48" class="mr-3">
            <v-icon size="24" color="white">{{ typeIcon(facilityType(detailItem)) }}</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis text-capitalize">
              {{ facilityType(detailItem) }}
            </div>
            <div class="text-h6 font-weight-bold">{{ detailItem.name }}</div>
          </div>
          <v-spacer />
          <v-chip size="small" :color="detailItem.is_active ? 'success' : 'grey'" variant="tonal" class="mr-2">
            {{ detailItem.is_active ? 'Active' : 'Inactive' }}
          </v-chip>
          <v-btn icon="mdi-close" variant="text" @click="detailDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-5">
          <v-row dense>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Discount</div>
              <div class="text-h6 font-weight-bold text-amber-darken-3">
                {{ Number(detailItem.discount_percent || 0).toFixed(1) }}%
              </div>
            </v-col>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Referring doctors</div>
              <div class="text-h6 font-weight-bold text-indigo-darken-2">
                {{ detailItem._doctorCount || 0 }}
              </div>
            </v-col>
          </v-row>
          <v-divider class="my-3" />
          <v-list density="compact" class="pa-0">
            <v-list-item v-if="detailItem.contact_person" prepend-icon="mdi-account"
                         :title="detailItem.contact_person" subtitle="Contact person" />
            <v-list-item v-if="detailItem.phone" prepend-icon="mdi-phone"
                         :href="`tel:${detailItem.phone}`" :title="detailItem.phone" subtitle="Phone" />
            <v-list-item v-if="detailItem.email" prepend-icon="mdi-email"
                         :href="`mailto:${detailItem.email}`" :title="detailItem.email" subtitle="Email" />
            <v-list-item v-if="detailItem.address" prepend-icon="mdi-map-marker"
                         :href="mapUrl(detailItem.address)" target="_blank"
                         :title="detailItem.address" subtitle="Address (open in maps)" />
            <v-list-item prepend-icon="mdi-calendar"
                         :title="formatDate(detailItem.created_at)" subtitle="Added" />
          </v-list>

          <template v-if="facilityDoctors.length">
            <v-divider class="my-3" />
            <div class="d-flex align-center mb-2">
              <v-icon color="indigo" class="mr-2">mdi-stethoscope</v-icon>
              <span class="text-subtitle-2 font-weight-bold">Referring doctors</span>
              <v-spacer />
              <v-chip size="small" color="indigo" variant="tonal">{{ facilityDoctors.length }}</v-chip>
            </div>
            <v-list density="compact" class="pa-0">
              <v-list-item v-for="d in facilityDoctors" :key="d.id"
                           :title="`Dr. ${d.full_name}`"
                           :subtitle="[d.specialty, d.phone].filter(Boolean).join(' · ')">
                <template #prepend>
                  <v-avatar :color="avatarColor(d.full_name)" size="30">
                    <span class="text-caption text-white font-weight-bold">{{ initials(d.full_name) }}</span>
                  </v-avatar>
                </template>
                <template #append>
                  <v-chip v-if="Number(d.commission_percent) > 0" size="x-small"
                          color="amber-darken-2" variant="tonal">
                    {{ Number(d.commission_percent).toFixed(1) }}%
                  </v-chip>
                </template>
              </v-list-item>
            </v-list>
          </template>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-3">
          <v-btn variant="text" prepend-icon="mdi-stethoscope" @click="viewDoctors(detailItem)">Doctors</v-btn>
          <v-btn variant="text" prepend-icon="mdi-content-copy" @click="copyContact(detailItem)">Copy</v-btn>
          <v-spacer />
          <v-btn variant="text" @click="detailDialog = false">Close</v-btn>
          <v-btn color="primary" rounded="lg" prepend-icon="mdi-pencil" @click="openEdit(detailItem)">Edit</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Bulk discount dialog -->
    <v-dialog v-model="bulkDiscountDialog" max-width="420" persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-icon color="amber-darken-2" class="mr-2">mdi-tag</v-icon>
          Set discount for {{ selected.length }} facility(ies)
        </v-card-title>
        <v-card-text>
          <v-text-field v-model.number="bulkDiscountValue" type="number" min="0" max="100" step="0.5"
                        label="Discount %" variant="outlined" density="comfortable" autofocus />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="bulkDiscountDialog = false">Cancel</v-btn>
          <v-btn color="primary" :loading="bulkBusy" @click="bulkSetDiscount">Apply</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Import dialog -->
    <v-dialog v-model="importDialog" max-width="520">
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center pa-4">
          <v-icon color="indigo" class="mr-2">mdi-tray-arrow-up</v-icon>
          Import facilities from CSV
        </v-card-title>
        <v-card-text>
          <p class="text-body-2 text-medium-emphasis mb-3">
            Upload a CSV with columns:
            <code>name, contact_person, phone, email, address, discount_percent</code>.
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
    <v-dialog v-model="deleteDialog.show" max-width="460" persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center">
          <v-icon color="error" class="mr-2">mdi-alert-circle</v-icon>Delete Facility
        </v-card-title>
        <v-card-text>
          Delete <strong>{{ deleteDialog.item?.name }}</strong>?
          <div v-if="(deleteDialog.item?._doctorCount || 0) > 0" class="mt-2">
            <v-alert type="warning" variant="tonal" density="compact">
              {{ deleteDialog.item._doctorCount }} referring doctor(s) are linked to this facility.
              They will become independent.
            </v-alert>
          </div>
          <div class="mt-2 text-caption text-medium-emphasis">This cannot be undone.</div>
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

const r = useResource('/lab/referring-facilities/')
const docs = useResource('/lab/referring-doctors/')
const router = useRouter()

const view = ref('table')
const statusFilter = ref(null)
const typeFilter = ref(null)
const discountFilter = ref(null)
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

const bulkDiscountDialog = ref(false)
const bulkDiscountValue = ref(0)

const importDialog = ref(false)
const importFile = ref(null)
const importPreview = ref([])
const importError = ref('')
const importBusy = ref(false)

const sortOptions = [
  { title: 'Name (A → Z)', value: 'name_asc' },
  { title: 'Name (Z → A)', value: 'name_desc' },
  { title: 'Discount (high → low)', value: 'discount_desc' },
  { title: 'Discount (low → high)', value: 'discount_asc' },
  { title: 'Most doctors', value: 'doctors_desc' },
  { title: 'Newest', value: 'newest' },
  { title: 'Oldest', value: 'oldest' },
]

const discountOptions = [
  { title: 'No discount', value: 'none' },
  { title: '0–5%', value: 'low' },
  { title: '5–15%', value: 'mid' },
  { title: '15%+', value: 'high' },
]

const headers = [
  { title: 'Facility', key: 'name' },
  { title: 'Contact', key: 'contact', sortable: false },
  { title: 'Address', key: 'address', sortable: false },
  { title: 'Doctors', key: 'doctors_count', width: 110 },
  { title: 'Discount', key: 'discount_percent', width: 110 },
  { title: 'Active', key: 'is_active', width: 90, sortable: false },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 240 },
]

const STATUS_FILTERS = [
  { label: 'All', value: null, key: 'all' },
  { label: 'Active', value: 'active', key: 'active' },
  { label: 'Inactive', value: 'inactive', key: 'inactive' },
  { label: 'With doctors', value: 'with_doctors', key: 'with_doctors' },
  { label: 'No contact', value: 'no_contact', key: 'no_contact' },
  { label: 'Discounted', value: 'discounted', key: 'discounted' },
]

// ─── Type inference (heuristic from name) ───
const TYPE_META = {
  hospital: { icon: 'mdi-hospital-building', match: ['hospital', 'medical center', 'medical centre'] },
  clinic: { icon: 'mdi-medical-bag', match: ['clinic', 'health centre', 'health center', 'dispensary'] },
  pharmacy: { icon: 'mdi-pill', match: ['pharmacy', 'chemist', 'drugstore'] },
  lab: { icon: 'mdi-flask-outline', match: ['lab', 'laboratory'] },
  dental: { icon: 'mdi-tooth-outline', match: ['dental', 'dentist'] },
  imaging: { icon: 'mdi-radioactive', match: ['imaging', 'radiology', 'scan'] },
  other: { icon: 'mdi-domain', match: [] },
}
function facilityType (f) {
  const n = (f?.name || '').toLowerCase()
  for (const [type, meta] of Object.entries(TYPE_META)) {
    if (meta.match.some(m => n.includes(m))) return type
  }
  return 'other'
}
function typeIcon (t) { return TYPE_META[t]?.icon || 'mdi-domain' }

// ─── Lists & enrichment ───
const list = computed(() => {
  const counts = {}
  for (const d of docs.items.value || []) {
    if (d.facility) counts[d.facility] = (counts[d.facility] || 0) + 1
  }
  return (r.items.value || []).map(f => ({ ...f, _doctorCount: counts[f.id] || 0 }))
})

const facilityDoctors = computed(() => {
  if (!detailItem.value) return []
  return (docs.items.value || []).filter(d => d.facility === detailItem.value.id)
})

const statusFilters = computed(() => {
  const arr = list.value
  const counts = {
    all: arr.length,
    active: arr.filter(f => f.is_active).length,
    inactive: arr.filter(f => !f.is_active).length,
    with_doctors: arr.filter(f => (f._doctorCount || 0) > 0).length,
    no_contact: arr.filter(f => !f.phone && !f.email).length,
    discounted: arr.filter(f => Number(f.discount_percent) > 0).length,
  }
  return STATUS_FILTERS.map(s => ({ ...s, count: counts[s.key] }))
})

const topFacilityTypes = computed(() => {
  const counts = list.value.reduce((acc, f) => {
    const t = facilityType(f)
    acc[t] = (acc[t] || 0) + 1
    return acc
  }, {})
  const tops = Object.entries(counts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 6)
    .map(([t, n]) => ({ label: t, value: t, count: n }))
  return [{ label: 'all types', value: null }, ...tops]
})

const filtered = computed(() => {
  // Apply r.search manually so we can search additional fields beyond what useResource handles
  const q = (r.search.value || '').toLowerCase().trim()
  let arr = list.value
  if (q) {
    arr = arr.filter(f =>
      [f.name, f.contact_person, f.phone, f.email, f.address]
        .filter(Boolean).some(s => String(s).toLowerCase().includes(q))
    )
  }
  if (statusFilter.value === 'active') arr = arr.filter(f => f.is_active)
  if (statusFilter.value === 'inactive') arr = arr.filter(f => !f.is_active)
  if (statusFilter.value === 'with_doctors') arr = arr.filter(f => (f._doctorCount || 0) > 0)
  if (statusFilter.value === 'no_contact') arr = arr.filter(f => !f.phone && !f.email)
  if (statusFilter.value === 'discounted') arr = arr.filter(f => Number(f.discount_percent) > 0)
  if (typeFilter.value) arr = arr.filter(f => facilityType(f) === typeFilter.value)
  if (discountFilter.value) {
    arr = arr.filter(f => {
      const d = Number(f.discount_percent || 0)
      if (discountFilter.value === 'none') return d === 0
      if (discountFilter.value === 'low') return d > 0 && d <= 5
      if (discountFilter.value === 'mid') return d > 5 && d <= 15
      if (discountFilter.value === 'high') return d > 15
      return true
    })
  }
  arr = [...arr]
  switch (sortBy.value) {
    case 'name_desc': arr.sort((a, b) => (b.name || '').localeCompare(a.name || '')); break
    case 'discount_asc':
      arr.sort((a, b) => Number(a.discount_percent || 0) - Number(b.discount_percent || 0)); break
    case 'discount_desc':
      arr.sort((a, b) => Number(b.discount_percent || 0) - Number(a.discount_percent || 0)); break
    case 'doctors_desc':
      arr.sort((a, b) => (b._doctorCount || 0) - (a._doctorCount || 0)); break
    case 'newest': arr.sort((a, b) => new Date(b.created_at || 0) - new Date(a.created_at || 0)); break
    case 'oldest': arr.sort((a, b) => new Date(a.created_at || 0) - new Date(b.created_at || 0)); break
    default: arr.sort((a, b) => (a.name || '').localeCompare(b.name || ''))
  }
  return arr
})

const kpis = computed(() => {
  const arr = list.value
  const active = arr.filter(f => f.is_active).length
  const totalDocs = arr.reduce((s, f) => s + (f._doctorCount || 0), 0)
  const discounted = arr.filter(f => Number(f.discount_percent) > 0)
  const avgDisc = discounted.length
    ? discounted.reduce((s, f) => s + Number(f.discount_percent || 0), 0) / discounted.length
    : 0
  const types = new Set(arr.map(facilityType)).size
  return [
    { label: 'Total Facilities', value: arr.length, icon: 'mdi-hospital-building', color: 'indigo',
      hint: `${active} active` },
    { label: 'Referring Doctors', value: totalDocs, icon: 'mdi-stethoscope', color: 'cyan',
      hint: 'across all facilities' },
    { label: 'On Discount', value: discounted.length, icon: 'mdi-tag', color: 'amber',
      hint: `${avgDisc.toFixed(1)}% avg` },
    { label: 'Facility Types', value: types, icon: 'mdi-shape', color: 'teal',
      hint: 'distinct categories' },
  ]
})

// ─── Helpers ───
function emptyForm () {
  return {
    id: null, name: '', contact_person: '', phone: '', email: '',
    address: '', discount_percent: 0, is_active: true,
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
function mapUrl (addr) { return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(addr)}` }

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
    name: `${it.name} (Copy)`,
  }
  detailDialog.value = false
  formDialog.value = true
}
async function copyContact (it) {
  const txt = [
    it.name,
    it.contact_person && `Contact: ${it.contact_person}`,
    it.phone && `Phone: ${it.phone}`,
    it.email && `Email: ${it.email}`,
    it.address && `Address: ${it.address}`,
  ].filter(Boolean).join('\n')
  try {
    await navigator.clipboard.writeText(txt)
    notify('Contact copied to clipboard')
  } catch { notify('Copy failed', 'error') }
}
function viewDoctors (it) {
  router.push({ path: '/lab/referring/doctors', query: { facility: it.id } })
}
async function save () {
  const { valid } = (await formRef.value?.validate?.()) || { valid: true }
  if (!valid) return
  try {
    const payload = {
      ...form.value,
      discount_percent: Number(form.value.discount_percent || 0),
    }
    if (payload.id) await r.update(payload.id, payload)
    else await r.create(payload)
    formDialog.value = false
    notify(`Facility ${form.value.id ? 'updated' : 'created'} successfully`)
    await r.list()
  } catch (e) { notify(r.error.value || 'Save failed', 'error') }
}
async function toggleActive (it, value) {
  const next = value === undefined ? !it.is_active : value
  try {
    await r.update(it.id, { is_active: next })
    it.is_active = next
    notify(`Facility ${next ? 'activated' : 'deactivated'}`)
  } catch (e) { notify(r.error.value || 'Update failed', 'error') }
}
function confirmDelete (it) { deleteDialog.item = it; deleteDialog.show = true }
async function doDelete () {
  deleteDialog.busy = true
  try {
    await r.remove(deleteDialog.item.id)
    notify('Facility deleted')
    deleteDialog.show = false
    detailDialog.value = false
    await docs.list()
  } catch (e) { notify(r.error.value || 'Delete failed', 'error') }
  finally { deleteDialog.busy = false }
}

// ─── Bulk ───
async function bulkSetActive (active) {
  bulkBusy.value = true
  try {
    await Promise.all(selected.value.map(id => r.update(id, { is_active: active })))
    notify(`${selected.value.length} facility(ies) ${active ? 'activated' : 'deactivated'}`)
    selected.value = []
    await r.list()
  } catch (e) { notify(r.error.value || 'Bulk update failed', 'error') }
  finally { bulkBusy.value = false }
}
async function bulkSetDiscount () {
  bulkBusy.value = true
  try {
    const value = Number(bulkDiscountValue.value || 0)
    await Promise.all(selected.value.map(id => r.update(id, { discount_percent: value })))
    notify(`Discount set to ${value}% for ${selected.value.length} facility(ies)`)
    bulkDiscountDialog.value = false
    selected.value = []
    await r.list()
  } catch (e) { notify(r.error.value || 'Bulk update failed', 'error') }
  finally { bulkBusy.value = false }
}
async function bulkDelete () {
  if (!confirm(`Delete ${selected.value.length} facility(ies)? Linked doctors will become independent.`)) return
  bulkBusy.value = true
  try {
    await Promise.all(selected.value.map(id => r.remove(id)))
    notify(`${selected.value.length} facility(ies) deleted`)
    selected.value = []
    await docs.list()
  } catch (e) { notify(r.error.value || 'Bulk delete failed', 'error') }
  finally { bulkBusy.value = false }
}

// ─── Misc ───
function resetFilters () {
  statusFilter.value = null
  typeFilter.value = null
  discountFilter.value = null
  sortBy.value = 'name_asc'
  r.search.value = ''
}
function reload () { r.list(); docs.list() }
function notify (text, color = 'success') { snack.text = text; snack.color = color; snack.show = true }

function exportCsv () {
  const rows = filtered.value
  if (!rows.length) return
  const cols = ['name', 'type', 'contact_person', 'phone', 'email', 'address',
    'discount_percent', 'doctors', 'active']
  const esc = v => `"${String(v ?? '').replace(/"/g, '""')}"`
  const body = rows.map(f => [
    esc(f.name), esc(facilityType(f)), esc(f.contact_person),
    esc(f.phone), esc(f.email), esc(f.address),
    Number(f.discount_percent || 0), f._doctorCount || 0, f.is_active ? 'yes' : 'no',
  ].join(',')).join('\n')
  const blob = new Blob([cols.join(',') + '\n' + body], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `referring-facilities_${new Date().toISOString().slice(0, 10)}.csv`
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
    if (!('name' in rows[0])) { importError.value = 'Missing "name" column'; return }
    importPreview.value = rows
  } catch (e) { importError.value = 'Could not read file' }
})

async function runImport () {
  importBusy.value = true
  let ok = 0, fail = 0
  try {
    for (const row of importPreview.value) {
      try {
        await r.create({
          name: row.name,
          contact_person: row.contact_person || '',
          phone: row.phone || '',
          email: row.email || '',
          address: row.address || '',
          discount_percent: Number(row.discount_percent || 0),
          is_active: true,
        })
        ok++
      } catch { fail++ }
    }
    notify(`Imported ${ok} facility(ies)${fail ? `, ${fail} failed` : ''}`, fail ? 'warning' : 'success')
    importDialog.value = false
    importFile.value = null
    importPreview.value = []
    await r.list()
  } finally { importBusy.value = false }
}

onMounted(() => { r.list(); docs.list() })
</script>

<style scoped>
.kpi { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.fac-table :deep(tbody tr) { cursor: pointer; }
.fac-card {
  position: relative;
  overflow: hidden;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
  cursor: pointer;
  transition: transform 120ms ease, box-shadow 120ms ease;
}
.fac-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.06); }
.fac-band {
  position: absolute; top: 0; left: 0; right: 0; height: 3px;
}
.fac-meta a { color: inherit; }
.bulk-bar {
  border: 1px solid rgba(var(--v-theme-primary), 0.2);
  background: rgba(var(--v-theme-primary), 0.04);
}
.min-width-0 { min-width: 0; }
</style>
