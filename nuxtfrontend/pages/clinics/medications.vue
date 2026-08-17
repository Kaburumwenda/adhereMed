<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Medications" subtitle="Medication catalog and drug management"
      icon="mdi-pill" color="indigo">
      <template #actions>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
          :loading="r.loading.value" @click="load">Refresh</v-btn>
        <v-btn variant="outlined" rounded="lg" class="text-none" prepend-icon="mdi-alert"
          @click="interactionDialog = true">Check Interactions</v-btn>
        <v-btn color="indigo" rounded="lg" class="text-none" prepend-icon="mdi-plus"
          @click="openNew">New Medication</v-btn>
      </template>
    </PageHeader>

    <!-- ── Filter bar ────────────────────────────────────────────── -->
    <v-card flat rounded="lg" class="filter-bar mb-3 pa-3">
      <v-row dense align="center">
        <v-col cols="12" md="4">
          <v-text-field v-model="r.search.value" prepend-inner-icon="mdi-magnify"
            placeholder="Search by name, brand, abbreviation, code…"
            variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="categoryFilter" :items="categoryOptions"
            label="Category" variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="formFilter" :items="formOptions"
            label="Dosage Form" variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="2">
          <v-select v-model="statusFilter" :items="statusOptions"
            label="Status" variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="6" md="1">
          <v-select v-model="rxFilter" :items="rxOptions"
            label="Rx" variant="outlined" density="compact" hide-details clearable />
        </v-col>
        <v-col cols="12" md="1" class="d-flex align-center justify-end">
          <v-btn-toggle v-model="view" mandatory density="compact" rounded="lg" color="indigo">
            <v-btn value="grid" icon="mdi-view-grid" size="small" />
            <v-btn value="table" icon="mdi-format-list-bulleted" size="small" />
          </v-btn-toggle>
        </v-col>
      </v-row>
      <div v-if="activeFilters" class="px-1 pt-2 d-flex flex-wrap ga-2">
        <v-chip v-if="categoryFilter" size="small" closable @click:close="categoryFilter = null"
          variant="tonal" color="indigo" class="text-capitalize">
          <v-icon start size="14">mdi-tag</v-icon>Category: {{ categoryFilter.replace(/_/g, ' ') }}
        </v-chip>
        <v-chip v-if="formFilter" size="small" closable @click:close="formFilter = null"
          variant="tonal" color="teal" class="text-capitalize">
          <v-icon start size="14">mdi-pill</v-icon>Form: {{ formFilter }}
        </v-chip>
        <v-chip v-if="statusFilter" size="small" closable @click:close="statusFilter = null"
          variant="tonal" :color="statusFilter === 'active' ? 'success' : 'error'" class="text-capitalize">
          <v-icon start size="14">{{ statusFilter === 'active' ? 'mdi-check-circle' : 'mdi-close-circle' }}</v-icon>
          Status: {{ statusFilter }}
        </v-chip>
        <v-chip v-if="rxFilter" size="small" closable @click:close="rxFilter = null"
          variant="tonal" color="warning">
          <v-icon start size="14">mdi-prescription</v-icon>{{ rxFilter === 'rx' ? 'Prescription only' : 'OTC' }}
        </v-chip>
        <v-btn size="small" variant="text" class="text-none"
          prepend-icon="mdi-filter-remove" @click="clearFilters">Clear all</v-btn>
      </div>
    </v-card>

    <!-- ── Quick KPI Cards ──────────────────────────────────────── -->
    <v-row dense class="mb-3">
      <v-col v-for="k in kpis" :key="k.label" cols="6" md="3">
        <v-card rounded="lg" variant="outlined" class="kpi-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis font-weight-medium">{{ k.label }}</div>
              <div class="text-h4 font-weight-bold" :class="`text-${k.color}`">{{ k.value }}</div>
            </div>
            <v-avatar :color="k.color + '-lighten-5'" variant="tonal" size="48">
              <v-icon :color="k.color" size="24">{{ k.icon }}</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ── Distribution Stat Cards ──────────────────────────────── -->
    <v-row dense class="mb-3">
      <!-- Category Distribution -->
      <v-col cols="12" md="6">
        <v-card rounded="lg" variant="outlined" class="dist-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <span class="text-caption text-medium-emphasis font-weight-medium">CATEGORY DISTRIBUTION</span>
            <v-icon size="16" color="medium-emphasis">mdi-tag-multiple</v-icon>
          </div>
          <div v-if="categoryDist.length" class="d-flex flex-column ga-2 mb-2" style="max-height: 200px; overflow-y: auto">
            <div v-for="c in categoryDist" :key="c.key" class="d-flex align-center ga-2">
              <v-icon size="16" :color="c.color">{{ categoryIcon(c.key) }}</v-icon>
              <span class="text-body-2 font-weight-medium flex-shrink-0 text-capitalize" style="width: 130px">{{ c.key.replace(/_/g, ' ') }}</span>
              <div class="status-bar-track flex-1 rounded-pill overflow-hidden">
                <div class="status-bar-fill rounded-pill" :style="{ width: `${c.pct}%`, background: c.colorHex }" />
              </div>
              <span class="text-body-2 font-weight-bold" :class="`text-${c.color}`" style="width: 28px; text-align: right">{{ c.count }}</span>
            </div>
          </div>
          <div v-else class="text-center text-caption text-medium-emphasis py-4">No medications found</div>
          <div class="text-caption text-medium-emphasis mt-2">{{ totalMedications }} medications total</div>
        </v-card>
      </v-col>

      <!-- Dosage Form + Rx Breakdown -->
      <v-col cols="12" md="6">
        <v-card rounded="lg" variant="outlined" class="dist-card pa-4 h-100">
          <div class="d-flex align-center justify-space-between mb-3">
            <span class="text-caption text-medium-emphasis font-weight-medium">DOSAGE FORM BREAKDOWN</span>
            <v-icon size="16" color="medium-emphasis">mdi-pill-multiple</v-icon>
          </div>
          <div class="d-flex flex-wrap ga-2 mb-3">
            <v-chip v-for="f in formDist" :key="f.key" size="small" variant="tonal"
              :color="f.color" class="text-capitalize">
              <v-icon start size="14">{{ formIcon(f.key) }}</v-icon>
              {{ f.key }} <span class="font-weight-bold ml-1">{{ f.count }}</span>
            </v-chip>
          </div>
          <v-divider class="mb-3" />
          <div class="d-flex align-center ga-4">
            <div class="flex-1 text-center">
              <v-icon color="warning" size="32" class="mb-1">mdi-prescription</v-icon>
              <div class="text-h5 font-weight-bold text-warning">{{ rxCount }}</div>
              <div class="text-caption text-medium-emphasis">Prescription</div>
            </div>
            <v-divider vertical />
            <div class="flex-1 text-center">
              <v-icon color="success" size="32" class="mb-1">mdi-pill-off</v-icon>
              <div class="text-h5 font-weight-bold text-success">{{ otcCount }}</div>
              <div class="text-caption text-medium-emphasis">OTC</div>
            </div>
            <v-divider vertical />
            <div class="flex-1 text-center">
              <v-icon color="error" size="32" class="mb-1">mdi-shield-lock</v-icon>
              <div class="text-h5 font-weight-bold text-error">{{ controlledCount }}</div>
              <div class="text-caption text-medium-emphasis">Controlled</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ── Results ───────────────────────────────────────────────── -->
    <div v-if="r.loading.value" class="d-flex justify-center pa-12">
      <v-progress-circular indeterminate color="indigo" size="48" />
    </div>

    <!-- Empty state -->
    <div v-else-if="!filteredMedications.length" class="pa-10 text-center">
      <v-icon size="64" color="grey-lighten-1">mdi-pill</v-icon>
      <div class="text-subtitle-1 font-weight-medium mt-3">No medications found</div>
      <div class="text-body-2 text-medium-emphasis mb-4">
        {{ activeFilters ? 'Try adjusting your filters.' : 'Create your first medication to get started.' }}
      </div>
      <v-btn v-if="!activeFilters" color="indigo" rounded="lg"
        prepend-icon="mdi-plus" class="text-none" @click="openNew">New Medication</v-btn>
      <v-btn v-else variant="text" rounded="lg" class="text-none"
        prepend-icon="mdi-filter-remove" @click="clearFilters">Clear filters</v-btn>
    </div>

    <!-- Grid view -->
    <div v-else-if="view === 'grid'" class="med-grid">
      <v-row dense>
        <v-col v-for="med in filteredMedications" :key="med.id" cols="12" sm="6" md="4" lg="3">
          <v-card rounded="lg" variant="outlined" class="med-card h-100"
            :class="{ 'med-card-inactive': !med.is_active }"
            @click="openEdit(med)">
            <div class="med-card-banner" :class="med.is_active ? 'med-banner-active' : 'med-banner-inactive'">
              <div class="d-flex align-center justify-space-between pa-3">
                <v-avatar :color="med.requires_prescription ? 'warning' : 'success'" variant="tonal" size="40">
                  <v-icon :color="med.requires_prescription ? 'warning' : 'success'" size="20">{{ formIcon(med.dosage_form) }}</v-icon>
                </v-avatar>
                <div class="d-flex ga-1">
                  <v-chip v-if="med.requires_prescription" size="x-small" variant="flat" color="warning">
                    <v-icon start size="10">mdi-prescription</v-icon>Rx
                  </v-chip>
                  <v-chip v-if="med.controlled_substance_class" size="x-small" variant="flat" color="error">
                    <v-icon start size="10">mdi-shield-lock</v-icon>{{ med.controlled_substance_class }}
                  </v-chip>
                  <v-chip size="x-small" variant="flat"
                    :color="med.is_active ? 'success' : 'error'">
                    <v-icon start size="10">{{ med.is_active ? 'mdi-check' : 'mdi-close' }}</v-icon>
                  </v-chip>
                </div>
              </div>
            </div>
            <v-card-text class="pa-3 pt-2">
              <div class="text-subtitle-1 font-weight-bold mb-1 text-truncate">{{ med.generic_name }}</div>
              <div class="text-caption text-medium-emphasis mb-1">
                {{ med.strength || '—' }} {{ med.unit || '' }} · {{ med.dosage_form || '—' }}
              </div>
              <div v-if="med.brand_names && med.brand_names.length" class="text-caption font-weight-medium text-indigo mb-2 text-truncate">
                {{ Array.isArray(med.brand_names) ? med.brand_names.join(', ') : med.brand_names }}
              </div>
              <div v-else class="text-caption text-medium-emphasis mb-2">No brand names</div>
              <v-divider class="mb-2" />
              <div class="d-flex align-center ga-2 mb-1">
                <v-icon size="14" color="indigo">{{ categoryIcon(med.category) }}</v-icon>
                <span class="text-caption text-capitalize">{{ med.category?.replace(/_/g, ' ') }}</span>
                <v-spacer />
                <v-chip v-if="med.abbreviation" size="x-small" variant="outlined" color="teal">{{ med.abbreviation }}</v-chip>
              </div>
              <div class="d-flex align-center ga-2">
                <v-icon size="14" color="medium-emphasis">mdi-barcode</v-icon>
                <span class="text-caption text-medium-emphasis text-truncate">{{ med.product_code || 'No code' }}</span>
              </div>
            </v-card-text>
            <v-card-actions class="px-3 pb-3 pt-0" @click.stop>
              <v-btn icon="mdi-eye" variant="text" size="small" color="indigo"
                @click="openDetail(med)" />
              <v-btn icon="mdi-pencil" variant="text" size="small" color="indigo"
                @click="openEdit(med)" />
              <v-btn icon="mdi-delete" variant="text" size="small" color="error"
                @click="confirmDelete(med)" />
              <v-spacer />
              <v-btn icon variant="text" size="small"
                @click="toggleActive(med)">
                <v-icon>{{ med.is_active ? 'mdi-toggle-switch-off' : 'mdi-toggle-switch' }}</v-icon>
                <v-tooltip activator="parent" location="top">
                  {{ med.is_active ? 'Deactivate' : 'Activate' }}
                </v-tooltip>
              </v-btn>
            </v-card-actions>
          </v-card>
        </v-col>
      </v-row>
    </div>

    <!-- Table view -->
    <v-card v-else flat rounded="lg" class="results-card">
      <v-data-table
        :headers="headers"
        :items="filteredMedications"
        :items-per-page="20"
        item-value="id"
        hover
        @click:row="(_, { item }) => openEdit(item)"
        class="medications-table">
        <template #item.generic_name="{ item }">
          <div class="d-flex align-center ga-2">
            <v-avatar :color="item.requires_prescription ? 'warning-lighten-5' : 'success-lighten-5'" variant="tonal" size="32">
              <v-icon :color="item.requires_prescription ? 'warning' : 'success'" size="16">{{ formIcon(item.dosage_form) }}</v-icon>
            </v-avatar>
            <div>
              <div class="font-weight-medium">{{ item.generic_name }}</div>
              <div v-if="item.brand_names && item.brand_names.length" class="text-caption text-medium-emphasis text-truncate" style="max-width: 200px">
                {{ Array.isArray(item.brand_names) ? item.brand_names.join(', ') : item.brand_names }}
              </div>
            </div>
          </div>
        </template>
        <template #item.category="{ value }">
          <v-chip size="small" variant="tonal" color="indigo" class="text-capitalize">
            <v-icon start size="14">{{ categoryIcon(value) }}</v-icon>
            {{ value ? value.replace(/_/g, ' ') : '—' }}
          </v-chip>
        </template>
        <template #item.dosage_form="{ value }">
          <div class="d-flex align-center ga-1">
            <v-icon size="14" color="teal">{{ formIcon(value) }}</v-icon>
            <span class="text-capitalize">{{ value || '—' }}</span>
          </div>
        </template>
        <template #item.strength="{ item }">
          {{ item.strength || '—' }}{{ item.unit ? ' ' + item.unit : '' }}
        </template>
        <template #item.requires_prescription="{ value }">
          <v-chip size="x-small" variant="tonal" :color="value ? 'warning' : 'success'">
            <v-icon start size="12">{{ value ? 'mdi-prescription' : 'mdi-pill-off' }}</v-icon>
            {{ value ? 'Rx' : 'OTC' }}
          </v-chip>
        </template>
        <template #item.is_active="{ item }">
          <v-chip size="small" variant="tonal"
            :color="item.is_active ? 'success' : 'error'"
            class="font-weight-medium">
            <v-icon start size="14">{{ item.is_active ? 'mdi-check-circle' : 'mdi-close-circle' }}</v-icon>
            {{ item.is_active ? 'Active' : 'Inactive' }}
          </v-chip>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex justify-end" @click.stop>
            <v-btn icon="mdi-eye" variant="text" size="small" color="indigo"
              @click="openDetail(item)" />
            <v-btn icon="mdi-pencil" variant="text" size="small" color="indigo"
              @click="openEdit(item)" />
            <v-btn icon="mdi-delete" variant="text" size="small" color="error"
              @click="confirmDelete(item)" />
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- ═══ New/Edit medication dialog ═══════════════════════════════ -->
    <v-dialog v-model="dialog" max-width="900" persistent scrollable>
      <v-card rounded="lg">
        <v-card-title class="text-h6 d-flex align-center">
          <v-avatar :color="editing ? 'indigo-lighten-5' : 'indigo'" variant="tonal" size="36" class="mr-3">
            <v-icon :color="editing ? 'indigo' : 'white'">{{ editing ? 'mdi-pill-edit' : 'mdi-pill-plus' }}</v-icon>
          </v-avatar>
          {{ editing ? 'Edit Medication' : 'New Medication' }}
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-form ref="formRef" @submit.prevent="save">
            <v-row dense>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.generic_name" label="Generic Name" required
                  variant="outlined" density="compact" prepend-inner-icon="mdi-pill"
                  placeholder="e.g. Paracetamol, Amoxicillin"
                  :rules="req" />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field v-model="form.product_code" label="Product Code"
                  variant="outlined" density="compact" prepend-inner-icon="mdi-barcode"
                  placeholder="e.g. PM05ASA003" />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field v-model="form.abbreviation" label="Abbreviation"
                  variant="outlined" density="compact" prepend-inner-icon="mdi-tag"
                  placeholder="e.g. PCM, AMOX" />
              </v-col>
              <v-col cols="6" md="4">
                <v-select v-model="form.category" :items="categoryOptions"
                  label="Category" variant="outlined" density="compact"
                  prepend-inner-icon="mdi-tag-multiple" />
              </v-col>
              <v-col cols="6" md="4">
                <v-text-field v-model="form.subcategory" label="Subcategory"
                  variant="outlined" density="compact"
                  prepend-inner-icon="mdi-tag-outline" />
              </v-col>
              <v-col cols="6" md="4">
                <v-select v-model="form.dosage_form" :items="formOptions"
                  label="Dosage Form" variant="outlined" density="compact"
                  prepend-inner-icon="mdi-pill-multiple" />
              </v-col>
              <v-col cols="6" md="4">
                <v-text-field v-model="form.strength" label="Strength"
                  variant="outlined" density="compact" prepend-inner-icon="mdi-scale"
                  placeholder="e.g. 500mg, 5mg/5ml" />
              </v-col>
              <v-col cols="6" md="4">
                <v-text-field v-model="form.unit" label="Unit"
                  variant="outlined" density="compact" prepend-inner-icon="mdi-ruler"
                  placeholder="e.g. tablets, ml, vials" />
              </v-col>
              <v-col cols="12" md="4">
                <v-text-field v-model="brandNamesText" label="Brand Names (comma-separated)"
                  variant="outlined" density="compact" prepend-inner-icon="mdi-label"
                  placeholder="e.g. Panadol, Tylenol, Calpol" />
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="form.description" label="Description"
                  variant="outlined" density="compact" rows="2" auto-grow
                  prepend-inner-icon="mdi-text"
                  placeholder="Brief description of the medication" />
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="form.side_effects" label="Side Effects"
                  variant="outlined" density="compact" rows="2" auto-grow
                  prepend-inner-icon="mdi-alert-outline"
                  placeholder="Known side effects" />
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="form.contraindications" label="Contraindications"
                  variant="outlined" density="compact" rows="2" auto-grow
                  prepend-inner-icon="mdi-cancel"
                  placeholder="Conditions where this medication should not be used" />
              </v-col>
              <v-col cols="12">
                <v-textarea v-model="form.interactions" label="Interaction Notes"
                  variant="outlined" density="compact" rows="2" auto-grow
                  prepend-inner-icon="mdi-link-variant"
                  placeholder="Free-text interaction notes" />
              </v-col>
              <v-col cols="6" md="3">
                <v-switch v-model="form.requires_prescription" label="Prescription required"
                  color="warning" density="compact" hide-details />
              </v-col>
              <v-col cols="6" md="3">
                <v-switch v-model="form.is_active" label="Active"
                  color="success" density="compact" hide-details />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field v-model="form.controlled_substance_class" label="Controlled Substance Class"
                  variant="outlined" density="compact" prepend-inner-icon="mdi-shield-lock"
                  placeholder="e.g. Schedule II, Class B" />
              </v-col>
            </v-row>
            <v-alert v-if="r.error.value" type="error" variant="tonal" density="compact" class="mt-3">
              {{ r.error.value }}
            </v-alert>
          </v-form>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="dialog = false">Cancel</v-btn>
          <v-btn color="indigo" rounded="lg" class="text-none" :loading="r.saving.value"
            prepend-icon="mdi-content-save" @click="save">
            {{ editing ? 'Update' : 'Create' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══ Detail dialog ═════════════════════════════════════════════ -->
    <v-dialog v-model="detailDialog" max-width="700" scrollable>
      <v-card rounded="lg">
        <v-card-title class="text-h6 d-flex align-center">
          <v-avatar color="indigo-lighten-5" variant="tonal" size="36" class="mr-3">
            <v-icon color="indigo">{{ formIcon(detailItem?.dosage_form) }}</v-icon>
          </v-avatar>
          {{ detailItem?.generic_name || 'Medication' }}
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4" v-if="detailItem">
          <v-row dense>
            <v-col cols="6"><strong>Strength:</strong> {{ detailItem.strength || '—' }} {{ detailItem.unit || '' }}</v-col>
            <v-col cols="6"><strong>Form:</strong> <span class="text-capitalize">{{ detailItem.dosage_form || '—' }}</span></v-col>
            <v-col cols="6"><strong>Category:</strong> <span class="text-capitalize">{{ detailItem.category?.replace(/_/g, ' ') || '—' }}</span></v-col>
            <v-col cols="6" v-if="detailItem.subcategory"><strong>Subcategory:</strong> {{ detailItem.subcategory }}</v-col>
            <v-col cols="6" v-if="detailItem.product_code"><strong>Product Code:</strong> {{ detailItem.product_code }}</v-col>
            <v-col cols="6" v-if="detailItem.abbreviation"><strong>Abbreviation:</strong> {{ detailItem.abbreviation }}</v-col>
            <v-col cols="12" v-if="detailItem.brand_names && detailItem.brand_names.length">
              <strong>Brand Names:</strong> {{ Array.isArray(detailItem.brand_names) ? detailItem.brand_names.join(', ') : detailItem.brand_names }}
            </v-col>
            <v-col cols="6">
              <strong>Prescription:</strong>
              <v-chip size="x-small" variant="tonal" :color="detailItem.requires_prescription ? 'warning' : 'success'" class="ml-1">
                {{ detailItem.requires_prescription ? 'Rx required' : 'OTC' }}
              </v-chip>
            </v-col>
            <v-col cols="6" v-if="detailItem.controlled_substance_class">
              <strong>Controlled:</strong> <v-chip size="x-small" variant="flat" color="error">{{ detailItem.controlled_substance_class }}</v-chip>
            </v-col>
          </v-row>
          <v-divider class="my-3" />
          <div v-if="detailItem.description">
            <div class="text-caption text-medium-emphasis font-weight-medium mb-1">DESCRIPTION</div>
            <div class="text-body-2">{{ detailItem.description }}</div>
          </div>
          <div v-if="detailItem.side_effects" class="mt-3">
            <div class="text-caption text-medium-emphasis font-weight-medium mb-1">SIDE EFFECTS</div>
            <div class="text-body-2">{{ detailItem.side_effects }}</div>
          </div>
          <div v-if="detailItem.contraindications" class="mt-3">
            <div class="text-caption text-medium-emphasis font-weight-medium mb-1">CONTRAINDICATIONS</div>
            <div class="text-body-2">{{ detailItem.contraindications }}</div>
          </div>
          <div v-if="detailItem.interactions" class="mt-3">
            <div class="text-caption text-medium-emphasis font-weight-medium mb-1">INTERACTION NOTES</div>
            <div class="text-body-2">{{ detailItem.interactions }}</div>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" @click="detailDialog = false">Close</v-btn>
          <v-btn color="indigo" rounded="lg" prepend-icon="mdi-pencil" @click="detailDialog = false; openEdit(detailItem)">Edit</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══ Drug Interaction Checker ════════════════════════════════ -->
    <v-dialog v-model="interactionDialog" max-width="700" scrollable>
      <v-card rounded="lg">
        <v-card-title class="text-h6 d-flex align-center">
          <v-avatar color="error-lighten-5" variant="tonal" size="36" class="mr-3">
            <v-icon color="error">mdi-alert-circle</v-icon>
          </v-avatar>
          Drug Interaction Checker
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-autocomplete v-model="interactionMeds" :items="medSelectOptions"
            label="Select medications to check" variant="outlined" density="compact"
            multiple chips closable-chips prepend-inner-icon="mdi-pill-multiple"
            placeholder="Search and select 2+ medications" :loading="r.loading.value" />
          <v-alert v-if="interactionResult" :type="interactionResult.highest_severity ? 'warning' : 'success'" variant="tonal" class="mt-3">
            <div v-if="interactionResult.interactions.length" class="font-weight-medium mb-2">
              Found {{ interactionResult.count }} interaction{{ interactionResult.count > 1 ? 's' : '' }} — Highest severity: <strong class="text-capitalize">{{ interactionResult.highest_severity }}</strong>
            </div>
            <div v-else class="font-weight-medium">No interactions found between selected medications.</div>
          </v-alert>
          <div v-if="interactionResult && interactionResult.interactions.length" class="mt-3 d-flex flex-column ga-2">
            <v-card v-for="(ix, i) in interactionResult.interactions" :key="i" variant="outlined" rounded="lg" class="pa-3">
              <div class="d-flex align-center justify-space-between mb-1">
                <div class="font-weight-medium">{{ ix.drug_a_name }} ↔ {{ ix.drug_b_name }}</div>
                <v-chip size="small" variant="flat" :color="severityColor(ix.severity)" class="text-capitalize">
                  <v-icon start size="14">{{ severityIcon(ix.severity) }}</v-icon>{{ ix.severity }}
                </v-chip>
              </div>
              <div class="text-body-2 text-medium-emphasis">{{ ix.description }}</div>
              <div v-if="ix.clinical_advice" class="text-caption mt-1">
                <v-icon size="14" color="info">mdi-lightbulb</v-icon> {{ ix.clinical_advice }}
              </div>
            </v-card>
          </div>
          <v-alert v-if="interactionError" type="error" variant="tonal" class="mt-3">{{ interactionError }}</v-alert>
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" rounded="lg" class="text-none" @click="interactionDialog = false">Close</v-btn>
          <v-btn color="error" rounded="lg" class="text-none" prepend-icon="mdi-magnify-scan"
            :loading="interactionLoading" :disabled="interactionMeds.length < 2" @click="checkInteractions">Check</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══ Delete confirmation dialog ═══════════════════════════════ -->
    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Delete Medication</v-card-title>
        <v-card-text>
          <div class="d-flex align-center mb-3">
            <v-avatar color="error-lighten-5" size="40" class="mr-3" variant="tonal">
              <v-icon color="error">mdi-delete-alert</v-icon>
            </v-avatar>
            <div>
              Are you sure you want to delete
              <strong>{{ deleteTarget?.generic_name || 'this medication' }}</strong>?
              <div class="text-caption text-medium-emphasis mt-1">This action cannot be undone.</div>
            </div>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" rounded="lg" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" :loading="r.saving.value" @click="performDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Snackbar ─────────────────────────────────────────────── -->
    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
import { formatDate } from '~/utils/format'

const r = useResource('/medications/')
const { $api } = useNuxtApp()

const req = [v => !!v || 'Required']

const view = ref('grid')
const categoryFilter = ref(null)
const formFilter = ref(null)
const statusFilter = ref(null)
const rxFilter = ref(null)

const categoryOptions = [
  { title: 'Analgesic', value: 'analgesic' },
  { title: 'Antibiotic', value: 'antibiotic' },
  { title: 'Antifungal', value: 'antifungal' },
  { title: 'Antiviral', value: 'antiviral' },
  { title: 'Antiparasitic', value: 'antiparasitic' },
  { title: 'Antimalarial', value: 'antimalarial' },
  { title: 'Antihypertensive', value: 'antihypertensive' },
  { title: 'Antidiabetic', value: 'antidiabetic' },
  { title: 'Antihistamine', value: 'antihistamine' },
  { title: 'Antacid', value: 'antacid' },
  { title: 'Cardiovascular', value: 'cardiovascular' },
  { title: 'Respiratory', value: 'respiratory' },
  { title: 'CNS', value: 'cns' },
  { title: 'Hormone', value: 'hormone' },
  { title: 'Vitamin', value: 'vitamin' },
  { title: 'Vaccine', value: 'vaccine' },
  { title: 'Dermatological', value: 'dermatological' },
  { title: 'Ophthalmic', value: 'ophthalmic' },
  { title: 'Oncology', value: 'oncology' },
  { title: 'Immunosuppressant', value: 'immunosuppressant' },
  { title: 'NSAID', value: 'nsaid' },
  { title: 'Other', value: 'other' },
]

const formOptions = [
  { title: 'Tablet', value: 'tablet' },
  { title: 'Capsule', value: 'capsule' },
  { title: 'Syrup', value: 'syrup' },
  { title: 'Injection', value: 'injection' },
  { title: 'Cream', value: 'cream' },
  { title: 'Ointment', value: 'ointment' },
  { title: 'Drops', value: 'drops' },
  { title: 'Inhaler', value: 'inhaler' },
  { title: 'Suppository', value: 'suppository' },
  { title: 'Suspension', value: 'suspension' },
  { title: 'Powder', value: 'powder' },
  { title: 'Gel', value: 'gel' },
  { title: 'Patch', value: 'patch' },
  { title: 'Lozenge', value: 'lozenge' },
  { title: 'Spray', value: 'spray' },
  { title: 'Solution', value: 'solution' },
  { title: 'Other', value: 'other' },
]

const statusOptions = [
  { title: 'Active', value: 'active' },
  { title: 'Inactive', value: 'inactive' },
]

const rxOptions = [
  { title: 'Prescription only', value: 'rx' },
  { title: 'OTC', value: 'otc' },
]

const headers = [
  { title: 'Name', key: 'generic_name', sortable: false },
  { title: 'Category', key: 'category', width: 150, sortable: false },
  { title: 'Form', key: 'dosage_form', width: 120, sortable: false },
  { title: 'Strength', key: 'strength', width: 130, sortable: false },
  { title: 'Rx', key: 'requires_prescription', width: 80, sortable: false },
  { title: 'Status', key: 'is_active', width: 110, sortable: false },
  { title: 'Created', key: 'created_at', width: 120 },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 130 },
]

// ── Computed / derived ──────────────────────────────────────────
const activeFilters = computed(() =>
  categoryFilter.value || formFilter.value || statusFilter.value || rxFilter.value || r.search.value,
)

function clearFilters() {
  categoryFilter.value = null
  formFilter.value = null
  statusFilter.value = null
  rxFilter.value = null
  r.search.value = ''
}

const filteredMedications = computed(() => {
  let list = r.filtered.value
  if (categoryFilter.value) list = list.filter(m => m.category === categoryFilter.value)
  if (formFilter.value) list = list.filter(m => m.dosage_form === formFilter.value)
  if (statusFilter.value === 'active') list = list.filter(m => m.is_active)
  if (statusFilter.value === 'inactive') list = list.filter(m => !m.is_active)
  if (rxFilter.value === 'rx') list = list.filter(m => m.requires_prescription)
  if (rxFilter.value === 'otc') list = list.filter(m => !m.requires_prescription)
  return list
})

const totalMedications = computed(() => filteredMedications.value.length)

// ── KPIs ────────────────────────────────────────────────────────
const kpis = computed(() => {
  const list = r.items.value
  return [
    { label: 'Total', value: list.length, icon: 'mdi-pill', color: 'indigo' },
    { label: 'Active', value: list.filter(m => m.is_active).length, icon: 'mdi-check-circle', color: 'success' },
    { label: 'Prescription', value: list.filter(m => m.requires_prescription).length, icon: 'mdi-prescription', color: 'warning' },
    { label: 'Controlled', value: list.filter(m => m.controlled_substance_class).length, icon: 'mdi-shield-lock', color: 'error' },
  ]
})

// ── Stat distributions ───────────────────────────────────────────
const categoryDist = computed(() => {
  const list = filteredMedications.value
  const map = new Map()
  list.forEach(m => {
    const cat = m.category || 'other'
    map.set(cat, (map.get(cat) || 0) + 1)
  })
  const total = list.length || 1
  const colors = ['indigo', 'teal', 'warning', 'success', 'error', 'info', 'purple', 'pink', 'orange', 'cyan']
  const colorHex = ['#6366f1', '#0d9488', '#f59e0b', '#22c55e', '#ef4444', '#3b82f6', '#a855f7', '#ec4899', '#f97316', '#06b6d4']
  const arr = [...map.entries()].map(([key, count], i) => ({
    key,
    count,
    pct: (count / total) * 100,
    color: colors[i % colors.length],
    colorHex: colorHex[i % colorHex.length],
  }))
  arr.sort((a, b) => b.count - a.count)
  return arr
})

const formDist = computed(() => {
  const list = filteredMedications.value
  const map = new Map()
  list.forEach(m => {
    const f = m.dosage_form || 'other'
    map.set(f, (map.get(f) || 0) + 1)
  })
  const colors = ['indigo', 'teal', 'warning', 'success', 'error', 'info', 'purple', 'pink', 'orange', 'cyan', 'amber', 'deep-orange', 'blue-grey', 'light-blue', 'lime', 'brown', 'grey']
  return [...map.entries()].map(([key, count], i) => ({
    key,
    count,
    color: colors[i % colors.length],
  })).sort((a, b) => b.count - a.count)
})

const rxCount = computed(() => filteredMedications.value.filter(m => m.requires_prescription).length)
const otcCount = computed(() => filteredMedications.value.filter(m => !m.requires_prescription).length)
const controlledCount = computed(() => filteredMedications.value.filter(m => m.controlled_substance_class).length)

// ── Icon helpers ────────────────────────────────────────────────
function categoryIcon(cat) {
  const map = {
    analgesic: 'mdi-pill',
    antibiotic: 'mdi-bacteria',
    antifungal: 'mdi-shield-outline',
    antiviral: 'mdi-shield-virus',
    antiparasitic: 'mdi-bug',
    antimalarial: 'mdi-mosquito',
    antihypertensive: 'mdi-heart-pulse',
    antidiabetic: 'mdi-water',
    antihistamine: 'mdi-allergy',
    antacid: 'mdi-cup',
    cardiovascular: 'mdi-heart',
    respiratory: 'mdi-lungs',
    cns: 'mdi-brain',
    hormone: 'mdi-endocrine-system' ,  // fallback
    vitamin: 'mdi-leaf',
    vaccine: 'mdi-needle',
    dermatological: 'mdi-hand-right-outline',
    ophthalmic: 'mdi-eye',
    oncology: 'mdi-ribbon',
    immunosuppressant: 'mdi-shield-off',
    nsaid: 'mdi-pill-multiple',
    other: 'mdi-pill',
  }
  return map[cat] || 'mdi-pill'
}

function formIcon(f) {
  const map = {
    tablet: 'mdi-pill',
    capsule: 'mdi-pill',
    syrup: 'mdi-bottle-tonic',
    injection: 'mdi-needle',
    cream: 'mdi-tube',
    ointment: 'mdi-tube',
    drops: 'mdi-eyedropper',
    inhaler: 'mdi-inhaler',
    suppository: 'mdi-pill',
    suspension: 'mdi-bottle-tonic',
    powder: 'mdi-flask',
    gel: 'mdi-tube',
    patch: 'mdi-sticker',
    lozenge: 'mdi-candy',
    spray: 'mdi-spray',
    solution: 'mdi-flask',
    other: 'mdi-pill',
  }
  return map[f] || 'mdi-pill'
}

function severityColor(s) {
  return { minor: 'info', moderate: 'warning', major: 'error', contraindicated: 'red-darken-4' }[s] || 'grey'
}
function severityIcon(s) {
  return { minor: 'mdi-information', moderate: 'mdi-alert', major: 'mdi-alert-circle', contraindicated: 'mdi-cancel' }[s] || 'mdi-circle-medium'
}

// ── New/Edit dialog ─────────────────────────────────────────────
const dialog = ref(false)
const editing = ref(null)
const formRef = ref(null)
const detailDialog = ref(false)
const detailItem = ref(null)
const brandNamesText = ref('')

const blankForm = () => ({
  generic_name: '',
  product_code: '',
  abbreviation: '',
  brand_names: [],
  category: '',
  subcategory: '',
  dosage_form: '',
  strength: '',
  unit: '',
  description: '',
  requires_prescription: true,
  controlled_substance_class: '',
  side_effects: '',
  contraindications: '',
  interactions: '',
  is_active: true,
})
const form = reactive(blankForm())

function openNew() {
  editing.value = null
  Object.assign(form, blankForm())
  brandNamesText.value = ''
  dialog.value = true
}

function openEdit(item) {
  editing.value = item.id
  Object.assign(form, {
    generic_name: item.generic_name || '',
    product_code: item.product_code || '',
    abbreviation: item.abbreviation || '',
    brand_names: item.brand_names || [],
    category: item.category || '',
    subcategory: item.subcategory || '',
    dosage_form: item.dosage_form || '',
    strength: item.strength || '',
    unit: item.unit || '',
    description: item.description || '',
    requires_prescription: item.requires_prescription !== false,
    controlled_substance_class: item.controlled_substance_class || '',
    side_effects: item.side_effects || '',
    contraindications: item.contraindications || '',
    interactions: item.interactions || '',
    is_active: item.is_active !== false,
  })
  brandNamesText.value = Array.isArray(item.brand_names) ? item.brand_names.join(', ') : ''
  dialog.value = true
}

function openDetail(item) {
  detailItem.value = item
  detailDialog.value = true
}

async function save() {
  const v = await formRef.value?.validate()
  if (v?.valid === false) return
  const payload = { ...form }
  payload.brand_names = brandNamesText.value
    ? brandNamesText.value.split(',').map(s => s.trim()).filter(Boolean)
    : []
  try {
    if (editing.value) {
      await r.update(editing.value, payload)
      snack.text = 'Medication updated successfully'
    } else {
      await r.create(payload)
      snack.text = 'Medication created successfully'
    }
    snack.color = 'success'
    snack.show = true
    dialog.value = false
    await load()
  } catch {}
}

// ── Toggle active ───────────────────────────────────────────────
async function toggleActive(med) {
  try {
    await r.update(med.id, { is_active: !med.is_active })
    snack.text = `${med.generic_name} ${!med.is_active ? 'activated' : 'deactivated'}`
    snack.color = 'success'
    snack.show = true
    await load()
  } catch {
    snack.text = r.error.value || 'Failed to update medication.'
    snack.color = 'error'
    snack.show = true
  }
}

// ── Delete ──────────────────────────────────────────────────────
const deleteDialog = ref(false)
const deleteTarget = ref(null)

function confirmDelete(item) {
  deleteTarget.value = item
  deleteDialog.value = true
}

async function performDelete() {
  try {
    await r.remove(deleteTarget.value.id)
    snack.text = 'Medication deleted'
    snack.color = 'success'
    snack.show = true
    deleteDialog.value = false
    await load()
  } catch {
    snack.text = r.error.value || 'Failed to delete medication.'
    snack.color = 'error'
    snack.show = true
  }
}

// ── Drug Interaction Checker ────────────────────────────────────
const interactionDialog = ref(false)
const interactionMeds = ref([])
const interactionResult = ref(null)
const interactionError = ref('')
const interactionLoading = ref(false)

const medSelectOptions = computed(() =>
  r.items.value.map(m => ({
    title: `${m.generic_name} ${m.strength || ''} (${m.dosage_form || '—'})`.trim(),
    value: m.id,
  })),
)

async function checkInteractions() {
  if (interactionMeds.value.length < 2) return
  interactionLoading.value = true
  interactionError.value = ''
  interactionResult.value = null
  try {
    const res = await $api.post('/medications/check-interactions/', {
      medication_ids: interactionMeds.value,
    })
    interactionResult.value = res.data
  } catch (e) {
    interactionError.value = e?.response?.data?.detail || 'Failed to check interactions.'
  } finally {
    interactionLoading.value = false
  }
}

const snack = reactive({ show: false, color: 'success', text: '' })

function load() {
  r.list({ page_size: 1000, ordering: 'generic_name' })
}

onMounted(() => load())
</script>

<style scoped>
.kpi-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.filter-bar { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); }
.results-card { border: 1px solid rgba(var(--v-theme-on-surface), 0.06); overflow: hidden; }
.medications-table :deep(tbody tr) { cursor: pointer; }

/* ── Distribution Cards ── */
.dist-card { overflow: hidden; }
.flex-1 { flex: 1; }
.flex-shrink-0 { flex-shrink: 0; }

/* Status bars */
.status-bar-track { height: 10px; background: rgba(var(--v-theme-on-surface), 0.06); }
.status-bar-fill { height: 100%; min-width: 4px; transition: width 0.3s ease; }

/* ── Medication Cards ── */
.med-grid { min-height: 200px; }
.med-card {
  cursor: pointer;
  transition: box-shadow 0.2s, transform 0.15s;
  overflow: hidden;
}
.med-card:hover {
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.08);
  transform: translateY(-2px);
}
.med-card-inactive { opacity: 0.7; }
.med-card-banner { padding: 0; }
.med-banner-active {
  background: linear-gradient(135deg, rgba(99, 102, 241, 0.08), rgba(99, 102, 241, 0.02));
  border-bottom: 1px solid rgba(99, 102, 241, 0.08);
}
.med-banner-inactive {
  background: linear-gradient(135deg, rgba(158, 158, 158, 0.08), rgba(158, 158, 158, 0.02));
  border-bottom: 1px solid rgba(158, 158, 158, 0.08);
}

/* Text truncation helpers */
.text-truncate-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  text-overflow: ellipsis;
}
</style>
