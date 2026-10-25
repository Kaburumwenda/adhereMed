<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center">
        <v-avatar color="teal-lighten-5" size="48" class="mr-3">
          <v-icon color="teal-darken-2" size="28">mdi-tag-multiple</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 font-weight-bold mb-1">Brand Names Catalog</h1>
          <div class="text-body-2 text-medium-emphasis">
            Built-in dictionary of {{ summary.total_brand_entries }} brand names across {{ summary.total_generics_in_dict }} generic ingredients
          </div>
        </div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap: 8px;">
        <v-btn rounded="lg" variant="flat" color="primary" prepend-icon="mdi-refresh" class="text-none" :loading="loading" @click="load">
          Refresh
        </v-btn>
        <v-btn rounded="lg" color="teal-darken-1" variant="flat" class="text-none" prepend-icon="mdi-seed" :loading="seeding" @click="confirmSeed = true">
          Seed brand names
        </v-btn>
        <v-btn rounded="lg" color="teal-darken-1" variant="flat" class="text-none" prepend-icon="mdi-plus" @click="openCreateDialog">
          Create
        </v-btn>
        <v-btn rounded="lg" color="deep-purple" variant="flat" class="text-none" prepend-icon="mdi-database-plus" :loading="seedingAll" :disabled="selectedGenerics.size === 0" @click="confirmSeedAll = true">
          Seed catalog ({{ selectedGenerics.size }})
        </v-btn>
      </div>
    </div>

    <!-- KPIs -->
    <v-row dense class="mb-4">
      <v-col v-for="k in kpiTiles" :key="k.label" cols="6" md="3">
        <v-card rounded="lg" class="pa-4 h-100 kpi-card">
          <div class="d-flex align-start justify-space-between">
            <div>
              <div class="text-caption text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h6 font-weight-bold mt-1">{{ k.value }}</div>
            </div>
            <v-avatar :color="k.color" variant="tonal" rounded="lg" size="40">
              <v-icon size="20">{{ k.icon }}</v-icon>
            </v-avatar>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Search + filter -->
    <v-card flat rounded="xl" border class="pa-3 mb-3">
      <div class="d-flex align-center flex-wrap ga-3">
        <v-text-field
          v-model="search"
          prepend-inner-icon="mdi-magnify"
          placeholder="Search generic name or brand"
          density="comfortable"
          variant="solo-filled"
          flat
          hide-details
          clearable
          style="min-width: 240px; max-width: 360px; flex: 1;"
        />
        <v-btn-toggle v-model="filterStatus" density="compact" rounded="lg" color="primary" divided>
          <v-btn value="all" size="small" class="text-none">All</v-btn>
          <v-btn value="matched" size="small" class="text-none">Matched</v-btn>
          <v-btn value="unmatched" size="small" class="text-none">Unmatched</v-btn>
          <v-btn value="has_brands" size="small" class="text-none">Has brands</v-btn>
          <v-btn value="missing" size="small" class="text-none">Missing</v-btn>
        </v-btn-toggle>
        <v-spacer />
        <v-chip color="primary" variant="tonal">{{ filteredCatalog.length }} shown</v-chip>
        <v-btn size="small" variant="text" class="text-none" prepend-icon="mdi-select-all" @click="selectAllGenerics">Select all</v-btn>
        <v-btn size="small" variant="text" class="text-none" prepend-icon="mdi-select-off" @click="clearSelectedGenerics">Clear</v-btn>
      </div>
    </v-card>

    <!-- Table -->
    <v-card flat rounded="xl" border>
      <v-data-table-server
        v-if="!loading"
        :headers="headers"
        :items="pagedCatalog"
        :items-length="filteredCatalog.length"
        density="comfortable"
        hover
        :items-per-page="itemsPerPage"
        :page="currentPage"
        @update:page="onPageChange"
        @update:items-per-page="onPerPageChange"
      >
        <template #item.row_num="{ item, index }">
          <div class="d-flex align-center" style="gap: 4px;">
            <v-checkbox-btn
              :model-value="selectedGenerics.has(item.key)"
              density="compact"
              hide-details
              color="deep-purple"
              @update:model-value="toggleGeneric(item.key)"
            />
            <span class="text-medium-emphasis text-caption">{{ rowNum(index) }}</span>
          </div>
        </template>
        <template #item.key="{ item }">
          <div class="text-capitalize font-weight-medium">{{ item.key }}</div>
        </template>
        <template #item.brands="{ item }">
          <div class="d-flex flex-wrap ga-1 py-1">
            <v-chip v-for="b in item.brands" :key="b" size="x-small" variant="tonal" color="teal" label>
              {{ b }}
            </v-chip>
          </div>
        </template>
        <template #item.med_generic_name="{ item }">
          <div v-if="item.med_id" class="text-body-2">
            <v-icon size="14" color="success" class="mr-1">mdi-link-variant</v-icon>
            <NuxtLink :to="medicationsLink" class="text-decoration-none text-primary">
              {{ item.med_generic_name }}
            </NuxtLink>
          </div>
          <span v-else class="text-caption text-medium-emphasis">No matching medication</span>
        </template>
        <template #item.has_brands="{ item }">
          <v-chip v-if="item.has_brands" size="x-small" variant="tonal" color="success" prepend-icon="mdi-check">
            {{ item.current_brands.length }} set
          </v-chip>
          <v-chip v-else-if="item.med_id" size="x-small" variant="tonal" color="warning" prepend-icon="mdi-alert">
            Missing
          </v-chip>
          <v-chip v-else size="x-small" variant="tonal" color="grey">N/A</v-chip>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex align-center ga-1">
            <v-btn
              size="small"
              variant="tonal"
              color="teal-darken-1"
              prepend-icon="mdi-pencil"
              class="text-none"
              @click="openEditDialog(item)"
            >
              Edit
            </v-btn>
            <v-btn
              size="small"
              variant="tonal"
              color="primary"
              prepend-icon="mdi-arrow-expand-all"
              class="text-none"
              :loading="expandingKey === item.key"
              @click="expandBrand(item)"
            >
              Expand
            </v-btn>
          </div>
        </template>
        <template #no-data>
          <div class="pa-8 text-center">
            <v-icon size="48" color="grey-lighten-1">mdi-tag-off</v-icon>
            <div class="text-body-1 mt-2">No brand names found</div>
          </div>
        </template>
      </v-data-table-server>
      <div v-else class="d-flex justify-center pa-8">
        <v-progress-circular indeterminate color="primary" size="40" />
      </div>
    </v-card>

    <!-- Seed confirmation dialog -->
    <v-dialog v-model="confirmSeed" max-width="540">
      <v-card rounded="xl">
        <v-card-item>
          <template #prepend>
            <v-avatar color="teal" variant="tonal" size="44">
              <v-icon>mdi-seed</v-icon>
            </v-avatar>
          </template>
          <v-card-title class="font-weight-bold">Seed all brand names?</v-card-title>
        </v-card-item>
        <v-card-text>
          <p class="text-body-2 mb-3">
            This will <strong>overwrite</strong> the brand_names field on all matching medications
            with the built-in dictionary values. Any custom brand names that are not in the dictionary
            will be lost.
          </p>
          <v-alert type="info" variant="tonal" rounded="lg" class="mb-3" density="comfortable">
            <strong>{{ summary.matched_to_medications }}</strong> of {{ summary.total_medications }}
            medications will be updated. {{ summary.unmatched }} dictionary entries have no
            matching medication.
          </v-alert>
          <div class="text-body-2 text-medium-emphasis">
            After seeding, the catalog page will reflect the new brand names immediately.
          </div>
        </v-card-text>
        <v-card-actions class="pa-4 pt-0">
          <v-spacer />
          <v-btn variant="text" @click="confirmSeed = false">Cancel</v-btn>
          <v-btn color="teal-darken-1" variant="flat" prepend-icon="mdi-seed" :loading="seeding" @click="doSeed">
            Yes, seed all brand names
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Seed result dialog -->
    <v-dialog v-model="seedResultDialog" max-width="560">
      <v-card rounded="xl">
        <v-card-item>
          <template #prepend>
            <v-avatar :color="seedHasUpdates ? 'success' : 'info'" variant="tonal" size="44">
              <v-icon>{{ seedIcon }}</v-icon>
            </v-avatar>
          </template>
          <v-card-title class="font-weight-bold">Seed complete</v-card-title>
        </v-card-item>
        <v-card-text v-if="hasSeedResult">
          <v-list density="comfortable">
            <v-list-item prepend-icon="mdi-pill" title="Total medications scanned" :subtitle="seedTotalStr" />
            <v-list-item prepend-icon="mdi-tag-check" title="Updated with brand names" :subtitle="seedUpdatedStr" />
            <v-list-item prepend-icon="mdi-help-circle-outline" title="No matching brand names" :subtitle="seedUnmatchedStr" />
          </v-list>
          <div v-if="hasSeedChanges" class="mt-3">
            <div class="text-caption font-weight-bold mb-1">Sample changes (first 10):</div>
            <div v-for="c in seedChanges" :key="c.id" class="text-caption text-medium-emphasis mb-1">
              <strong>{{ c.name }}</strong>: {{ c.brands.join(", ") }}
            </div>
          </div>
        </v-card-text>
        <v-card-actions class="pa-4 pt-0">
          <v-spacer />
          <v-btn color="primary" variant="flat" @click="closeSeedResult">Done</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Expand dialog — editable variants table -->
    <v-dialog v-model="expandDialog" max-width="1100" scrollable>
      <v-card rounded="xl">
        <v-card-item>
          <template #prepend>
            <v-avatar color="primary" variant="tonal" size="44">
              <v-icon>mdi-arrow-expand-all</v-icon>
            </v-avatar>
          </template>
          <v-card-title class="font-weight-bold">
            Expand: <span class="text-capitalize ml-1">{{ expandGeneric }}</span>
          </v-card-title>
        </v-card-item>

        <v-card-text>
          <p class="text-body-2 mb-3">
            Each selected row will create a separate medication entry.
            <strong>Generic name</strong> stays as <code>{{ expandGeneric }}</code> on its own field.
            Edit the <strong>strength</strong>, <strong>dosage form</strong>, and <strong>unit</strong> for each brand variant.
            Uncheck rows you do not want to create.
          </p>

          <!-- Controls -->
          <div class="d-flex align-center ga-2 mb-3 flex-wrap">
            <v-btn size="small" variant="tonal" prepend-icon="mdi-check-all" class="text-none" @click="selectAll">Select all</v-btn>
            <v-btn size="small" variant="tonal" prepend-icon="mdi-check-none" class="text-none" @click="deselectAll">Deselect all</v-btn>
            <v-spacer />
            <v-chip color="primary" variant="tonal" size="small">
              {{ selectedCount }} selected
            </v-chip>
          </div>

          <v-progress-circular v-if="expandLoading" indeterminate color="primary" size="24" class="d-block mx-auto my-4" />

          <!-- Editable variants table -->
          <v-table v-if="expandVariants.length" density="compact" class="expand-table">
            <thead>
              <tr>
                <th style="width: 50px;"></th>
                <th>Brand</th>
                <th>Strength</th>
                <th>Dosage Form</th>
                <th>Unit</th>
                <th>Preview Name</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(v, i) in expandVariants" :key="i">
                <td>
                  <v-checkbox-btn v-model="v.selected" density="compact" hide-details color="primary" />
                </td>
                <td class="font-weight-medium">{{ v.brand }}</td>
                <td>
                  <v-combobox
                    v-model="v.strength"
                    :items="strengthOptions"
                    density="compact"
                    variant="outlined"
                    hide-details
                    placeholder="500mg"
                    style="min-width: 120px; max-width: 150px;"
                  />
                </td>
                <td>
                  <v-select
                    v-model="v.dosage_form"
                    :items="formChoices"
                    item-value="value"
                    item-title="label"
                    density="compact"
                    variant="outlined"
                    hide-details
                    style="min-width: 120px; max-width: 150px;"
                  />
                </td>
                <td>
                  <v-autocomplete
                    v-model="v.unit"
                    :items="units"
                    item-title="name"
                    item-value="name"
                    density="compact"
                    variant="outlined"
                    hide-details
                    placeholder="Select…"
                    style="min-width: 120px; max-width: 150px;"
                  />
                </td>
                <td>
                  <span class="text-caption text-medium-emphasis">{{ previewName(v) }}</span>
                </td>
              </tr>
            </tbody>
          </v-table>
        </v-card-text>

        <v-card-actions class="pa-4 pt-0">
          <v-spacer />
          <v-btn variant="text" @click="expandDialog = false">Cancel</v-btn>
          <v-btn
            color="primary"
            variant="flat"
            prepend-icon="mdi-check"
            :loading="expandCommitting"
            :disabled="selectedCount === 0"
            @click="commitExpand"
          >
            Create {{ selectedCount }} medication entries
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Expand result dialog -->
    <v-dialog v-model="expandResultDialog" max-width="560">
      <v-card rounded="xl">
        <v-card-item>
          <template #prepend>
            <v-avatar :color="expandResult.errors && expandResult.errors.length ? 'warning' : 'success'" variant="tonal" size="44">
              <v-icon>{{ expandResult.errors && expandResult.errors.length ? 'mdi-alert' : 'mdi-check-circle' }}</v-icon>
            </v-avatar>
          </template>
          <v-card-title class="font-weight-bold">Expansion complete</v-card-title>
        </v-card-item>
        <v-card-text>
          <v-list density="comfortable">
            <v-list-item prepend-icon="mdi-pill-plus" title="Medications created" :subtitle="String(expandResult.created || 0)" />
            <v-list-item v-if="expandResult.errors && expandResult.errors.length" prepend-icon="mdi-alert" title="Errors" :subtitle="String(expandResult.errors.length)" />
          </v-list>
          <div v-if="expandResult.created_items && expandResult.created_items.length" class="mt-3">
            <div class="text-caption font-weight-bold mb-1">Created entries (first 15):</div>
            <div v-for="c in (expandResult.created_items || []).slice(0, 15)" :key="c.brand + c.strength" class="text-caption text-medium-emphasis mb-1">
              <strong>{{ c.name }}</strong> &mdash; {{ c.generic_name }} / {{ c.dosage_form }}
            </div>
          </div>
        </v-card-text>
        <v-card-actions class="pa-4 pt-0">
          <v-spacer />
          <v-btn color="primary" variant="flat" @click="expandResultDialog = false; load()">Done</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Seed all catalog confirmation -->
    <v-dialog v-model="confirmSeedAll" max-width="560">
      <v-card rounded="xl">
        <v-card-item>
          <template #prepend>
            <v-avatar color="deep-purple" variant="tonal" size="44">
              <v-icon>mdi-database-plus</v-icon>
            </v-avatar>
          </template>
          <v-card-title class="font-weight-bold">Seed entire medication catalog?</v-card-title>
        </v-card-item>
        <v-card-text>
          <p class="text-body-2 mb-3">
            This will create separate medication entries for <strong>every brand</strong> of
            <strong>{{ selectedGenerics.size }} selected generic{{ selectedGenerics.size === 1 ? '' : 's' }}</strong>,
            using built-in default strengths and dosage forms.
          </p>
          <v-alert type="info" variant="tonal" rounded="lg" class="mb-3" density="comfortable">
            Brand+strength combos that already exist will be skipped.
          </v-alert>
        </v-card-text>
        <v-card-actions class="pa-4 pt-0">
          <v-spacer />
          <v-btn variant="text" @click="confirmSeedAll = false">Cancel</v-btn>
          <v-btn
            color="deep-purple"
            variant="flat"
            prepend-icon="mdi-database-plus"
            :loading="seedingAll"
            @click="doSeedAllCatalog"
          >
            Yes, create {{ selectedGenerics.size }} catalog {{ selectedGenerics.size === 1 ? 'entry set' : 'entry sets' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Seed all catalog result -->
    <v-dialog v-model="seedAllResultDialog" max-width="600">
      <v-card rounded="xl">
        <v-card-item>
          <template #prepend>
            <v-avatar :color="seedAllResult.created > 0 ? 'success' : 'info'" variant="tonal" size="44">
              <v-icon>{{ seedAllResult.created > 0 ? 'mdi-check-circle' : 'mdi-information' }}</v-icon>
            </v-avatar>
          </template>
          <v-card-title class="font-weight-bold">Catalog seed complete</v-card-title>
        </v-card-item>
        <v-card-text>
          <v-list density="comfortable">
            <v-list-item prepend-icon="mdi-tag-multiple" title="Generics processed" :subtitle="String(seedAllResult.total_generics || 0)" />
            <v-list-item prepend-icon="mdi-format-list-bulleted" title="Total variants" :subtitle="String(seedAllResult.total_variants || 0)" />
            <v-list-item prepend-icon="mdi-pill-plus" title="Medications created" :subtitle="String(seedAllResult.created || 0)" />
            <v-list-item prepend-icon="mdi-skip-next" title="Already existed (skipped)" :subtitle="String(seedAllResult.skipped || 0)" />
          </v-list>
          <div v-if="seedAllResult.per_generic && seedAllResult.per_generic.length" class="mt-3">
            <div class="text-caption font-weight-bold mb-1">Per-generic breakdown (first 20):</div>
            <div v-for="g in seedAllResult.per_generic.slice(0, 20)" :key="g.generic" class="text-caption text-medium-emphasis mb-1">
              <strong class="text-capitalize">{{ g.generic }}</strong>: {{ g.created }} created, {{ g.skipped }} skipped
            </div>
          </div>
        </v-card-text>
        <v-card-actions class="pa-4 pt-0">
          <v-spacer />
          <v-btn color="primary" variant="flat" @click="seedAllResultDialog = false; load()">Done</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.message }}
    </v-snackbar>

    <!-- Create brand entry dialog -->
    <v-dialog v-model="createDialog" max-width="1100" persistent scrollable>
      <v-card rounded="xl">
        <v-card-item>
          <template #prepend>
            <v-avatar color="teal" variant="tonal" size="44">
              <v-icon>mdi-tag-plus</v-icon>
            </v-avatar>
          </template>
          <v-card-title class="font-weight-bold">Create Brand Name Entry</v-card-title>
          <template #append>
            <v-btn icon="mdi-close" variant="text" size="small" @click="createDialog = false" />
          </template>
        </v-card-item>

        <v-card-text>
          <p class="text-body-2 text-medium-emphasis mb-4">
            Add a generic ingredient and its brand (trade) names with individual details.
            Each brand can have its own strength, dosage form, category, and unit.
            Brands with different strength+form combos create separate medication records.
          </p>

          <!-- Generic name -->
          <v-text-field
            v-model="createForm.generic_name"
            label="Generic Name *"
            placeholder="e.g. paracetamol"
            density="comfortable"
            variant="outlined"
            :rules="[v => !!v || 'Generic name is required']"
            class="mb-4"
            style="max-width: 400px;"
          />

          <!-- Add brand bar -->
          <div class="d-flex align-center ga-2 mb-3">
            <div class="text-subtitle-2 font-weight-bold">Brand Entries</div>
            <v-spacer />
            <v-chip color="primary" variant="tonal" size="small">{{ createEntries.length }} brand(s)</v-chip>
          </div>
          <div class="d-flex ga-2 mb-4">
            <v-text-field
              v-model="brandInput"
              label="Add a brand name"
              placeholder="e.g. Panadol"
              density="comfortable"
              variant="outlined"
              hide-details
              style="max-width: 300px;"
              @keyup.enter="addBrand"
            />
            <v-btn variant="flat" color="teal-darken-1" prepend-icon="mdi-plus" @click="addBrand">
              Add Brand
            </v-btn>
          </div>
          <div v-if="createEntries.length === 0 && createFormSubmitted" class="text-error text-caption mb-3">
            At least one brand name is required
          </div>

          <!-- Per-brand details table -->
          <v-table v-if="createEntries.length" density="compact" class="create-table mb-2">
            <thead>
              <tr>
                <th style="width: 44px;"></th>
                <th style="min-width: 140px;">Brand *</th>
                <th style="min-width: 130px;">Strength</th>
                <th style="min-width: 150px;">Dosage Form</th>
                <th style="min-width: 160px;">Category</th>
                <th style="min-width: 120px;">Unit</th>
                <th style="min-width: 140px;">Prescription</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(e, i) in createEntries" :key="i">
                <td>
                  <v-btn icon="mdi-delete" size="x-small" variant="text" color="error" @click="removeBrandEntry(i)" />
                </td>
                <td class="font-weight-medium">{{ e.brand }}</td>
                <td>
                  <v-combobox
                    v-model="e.strength"
                    :items="strengthOptions"
                    density="compact"
                    variant="outlined"
                    hide-details
                    placeholder="500mg"
                    style="min-width: 110px;"
                  />
                </td>
                <td>
                  <v-combobox
                    v-model="e.dosage_form"
                    :items="formChoicesLabel"
                    density="compact"
                    variant="outlined"
                    hide-details
                    placeholder="tablet"
                    style="min-width: 130px;"
                  />
                </td>
                <td>
                  <v-combobox
                    v-model="e.category"
                    :items="categoryChoicesLabel"
                    density="compact"
                    variant="outlined"
                    hide-details
                    placeholder="analgesic"
                    style="min-width: 140px;"
                  />
                </td>
                <td>
                  <v-combobox
                    v-model="e.unit"
                    :items="unitOptions"
                    density="compact"
                    variant="outlined"
                    hide-details
                    placeholder="tab"
                    style="min-width: 100px;"
                  />
                </td>
                <td>
                  <v-switch
                    v-model="e.requires_prescription"
                    density="compact"
                    hide-details
                    color="primary"
                    :label="e.requires_prescription ? 'Yes' : 'No'"
                  />
                </td>
              </tr>
            </tbody>
          </v-table>
        </v-card-text>

        <v-divider />
        <v-card-actions class="pa-4">
          <v-btn variant="text" @click="createDialog = false">Cancel</v-btn>
          <v-spacer />
          <v-btn
            color="teal-darken-1"
            variant="flat"
            prepend-icon="mdi-check"
            :loading="creating"
            :disabled="!createForm.generic_name.trim() || createEntries.length === 0"
            @click="commitCreate"
          >
            {{ createExisting ? 'Update Entry' : 'Create Entry' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Create result dialog -->
    <v-dialog v-model="createResultDialog" max-width="560" scrollable>
      <v-card rounded="xl">
        <v-card-item>
          <template #prepend>
            <v-avatar color="success" variant="tonal" size="44">
              <v-icon>mdi-check-circle</v-icon>
            </v-avatar>
          </template>
          <v-card-title class="font-weight-bold">Entry saved</v-card-title>
        </v-card-item>
        <v-card-text>
          <div class="text-body-1 mb-3">{{ createResult.detail }}</div>
          <div v-if="createResult.brand_names && createResult.brand_names.length" class="d-flex flex-wrap ga-1 mb-3">
            <v-chip v-for="b in createResult.brand_names" :key="b" size="small" variant="tonal" color="teal" label>
              {{ b }}
            </v-chip>
          </div>
          <div v-if="createResult.created_items && createResult.created_items.length" class="mt-2">
            <div class="text-caption font-weight-bold mb-1">Medication records created/updated:</div>
            <div v-for="c in createResult.created_items" :key="c.id" class="text-caption text-medium-emphasis mb-1">
              <strong>{{ c.brand }}</strong> &mdash; {{ c.generic_name }} {{ c.strength }} {{ c.dosage_form }}
            </div>
          </div>
        </v-card-text>
        <v-card-actions class="pa-4 pt-0">
          <v-spacer />
          <v-btn color="primary" variant="flat" @click="createResultDialog = false; load()">Done</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Edit brand entry dialog -->
    <v-dialog v-model="editDialog" max-width="1100" persistent scrollable>
      <v-card rounded="xl">
        <v-card-item>
          <template #prepend>
            <v-avatar color="teal" variant="tonal" size="44">
              <v-icon>mdi-pencil</v-icon>
            </v-avatar>
          </template>
          <v-card-title class="font-weight-bold">
            Edit: <span class="text-capitalize ml-1">{{ editGeneric }}</span>
          </v-card-title>
          <template #append>
            <v-btn icon="mdi-close" variant="text" size="small" @click="editDialog = false" />
          </template>
        </v-card-item>

        <v-card-text>
          <p class="text-body-2 text-medium-emphasis mb-4">
            Add or remove brand names and set individual details for each.
            Brands with different strength+form combos will create separate medication records.
          </p>

          <!-- Add brand bar -->
          <div class="d-flex align-center ga-2 mb-3">
            <div class="text-subtitle-2 font-weight-bold">Brand Entries</div>
            <v-spacer />
            <v-chip color="primary" variant="tonal" size="small">{{ editEntries.length }} brand(s)</v-chip>
          </div>
          <div class="d-flex ga-2 mb-4">
            <v-text-field
              v-model="editBrandInput"
              label="Add a brand name"
              placeholder="e.g. Panadol"
              density="comfortable"
              variant="outlined"
              hide-details
              style="max-width: 300px;"
              @keyup.enter="addEditBrand"
            />
            <v-btn variant="flat" color="teal-darken-1" prepend-icon="mdi-plus" @click="addEditBrand">
              Add Brand
            </v-btn>
          </div>

          <!-- Per-brand details table -->
          <v-table v-if="editEntries.length" density="compact" class="create-table mb-2">
            <thead>
              <tr>
                <th style="width: 44px;"></th>
                <th style="min-width: 140px;">Brand *</th>
                <th style="min-width: 130px;">Strength</th>
                <th style="min-width: 150px;">Dosage Form</th>
                <th style="min-width: 160px;">Category</th>
                <th style="min-width: 120px;">Unit</th>
                <th style="min-width: 140px;">Prescription</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(e, i) in editEntries" :key="i">
                <td>
                  <v-btn icon="mdi-delete" size="x-small" variant="text" color="error" @click="removeEditBrandEntry(i)" />
                </td>
                <td class="font-weight-medium">{{ e.brand }}</td>
                <td>
                  <v-combobox
                    v-model="e.strength"
                    :items="strengthOptions"
                    density="compact"
                    variant="outlined"
                    hide-details
                    placeholder="500mg"
                    style="min-width: 110px;"
                  />
                </td>
                <td>
                  <v-combobox
                    v-model="e.dosage_form"
                    :items="formChoicesLabel"
                    density="compact"
                    variant="outlined"
                    hide-details
                    placeholder="tablet"
                    style="min-width: 130px;"
                  />
                </td>
                <td>
                  <v-combobox
                    v-model="e.category"
                    :items="categoryChoicesLabel"
                    density="compact"
                    variant="outlined"
                    hide-details
                    placeholder="analgesic"
                    style="min-width: 140px;"
                  />
                </td>
                <td>
                  <v-combobox
                    v-model="e.unit"
                    :items="unitOptions"
                    density="compact"
                    variant="outlined"
                    hide-details
                    placeholder="tab"
                    style="min-width: 100px;"
                  />
                </td>
                <td>
                  <v-switch
                    v-model="e.requires_prescription"
                    density="compact"
                    hide-details
                    color="primary"
                    :label="e.requires_prescription ? 'Yes' : 'No'"
                  />
                </td>
              </tr>
            </tbody>
          </v-table>
          <div v-else class="text-center text-medium-emphasis pa-4">
            No brand entries. Add one above.
          </div>
        </v-card-text>

        <v-divider />
        <v-card-actions class="pa-4">
          <v-btn variant="text" @click="editDialog = false">Cancel</v-btn>
          <v-spacer />
          <v-btn
            color="teal-darken-1"
            variant="flat"
            prepend-icon="mdi-check"
            :loading="editing"
            :disabled="editEntries.length === 0"
            @click="commitEdit"
          >
            Save Changes
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Edit result dialog -->
    <v-dialog v-model="editResultDialog" max-width="560" scrollable>
      <v-card rounded="xl">
        <v-card-item>
          <template #prepend>
            <v-avatar color="success" variant="tonal" size="44">
              <v-icon>mdi-check-circle</v-icon>
            </v-avatar>
          </template>
          <v-card-title class="font-weight-bold">Brand entry updated</v-card-title>
        </v-card-item>
        <v-card-text>
          <div class="text-body-1 mb-3">{{ editResult.detail }}</div>
          <div v-if="editResult.brand_names && editResult.brand_names.length" class="d-flex flex-wrap ga-1 mb-3">
            <v-chip v-for="b in editResult.brand_names" :key="b" size="small" variant="tonal" color="teal" label>
              {{ b }}
            </v-chip>
          </div>
          <div v-if="editResult.created_items && editResult.created_items.length" class="mt-2">
            <div class="text-caption font-weight-bold mb-1">Medication records created/updated:</div>
            <div v-for="c in editResult.created_items" :key="c.id" class="text-caption text-medium-emphasis mb-1">
              <strong>{{ c.brand }}</strong> &mdash; {{ c.generic_name }} {{ c.strength }} {{ c.dosage_form }}
            </div>
          </div>
        </v-card-text>
        <v-card-actions class="pa-4 pt-0">
          <v-spacer />
          <v-btn color="primary" variant="flat" @click="editResultDialog = false; load()">Done</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const route = useRoute()

const ns = computed(() => {
  const p = route.path
  if (p.includes('/ims/')) return '/ims'
  if (p.includes('/clinics/')) return '/clinics/catalog'
  return '/pharmacy'
})

const loading = ref(false)
const catalog = ref([])
const summary = ref({
  total_generics_in_dict: 0,
  matched_to_medications: 0,
  unmatched: 0,
  total_medications: 0,
  meds_with_brands: 0,
  meds_without_brands: 0,
  total_brand_entries: 0,
})

const search = ref('')
const filterStatus = ref('all')
const currentPage = ref(1)
const itemsPerPage = ref(50)

const seeding = ref(false)
const confirmSeed = ref(false)
const seedResultDialog = ref(false)
const seedResult = ref({})
const snack = reactive({ show: false, color: 'success', message: '' })

// Seed all catalog state
const seedingAll = ref(false)
const confirmSeedAll = ref(false)
const seedAllResultDialog = ref(false)
const seedAllResult = ref({})
const selectedGenerics = ref(new Set())

// Expand state
const expandDialog = ref(false)
const expandLoading = ref(false)
const expandCommitting = ref(false)
const expandingKey = ref('')
const expandGeneric = ref('')
const expandVariants = ref([])
const formChoices = ref([])
const units = ref([])

const strengthOptions = [
  '1mg', '2mg', '5mg', '10mg', '15mg', '20mg', '25mg', '30mg', '40mg',
  '50mg', '75mg', '100mg', '150mg', '200mg', '250mg', '300mg', '400mg', '500mg',
  '600mg', '750mg', '1000mg', '1g', '2g', '5g',
  '0.5ml', '1ml', '2.5ml', '5ml', '10ml', '15ml', '20ml', '30ml', '50ml', '100ml',
  '100IU', '500IU', '1000IU',
  '5mg/5ml', '10mg/5ml', '125mg/5ml', '200mg/5ml', '250mg/5ml',
  '100mcg', '200mcg', '250mcg', '500mcg',
  '50mg/ml', '100mg/ml',
  '20mg/2ml', '40mg/2ml', '80mg/2ml',
  '75mcg/1hr', '100mcg/hr',
]
const expandResultDialog = ref(false)
const expandResult = ref({})

// Create brand entry state
const createDialog = ref(false)
const creating = ref(false)
const createFormSubmitted = ref(false)
const brandInput = ref('')
const createForm = reactive({
  generic_name: '',
})
const createEntries = ref([])
const createExisting = ref(false)
const createResultDialog = ref(false)
const createResult = ref({})

// Edit brand entry state
const editDialog = ref(false)
const editing = ref(false)
const editGeneric = ref('')
const editMedId = ref(null)
const editBrandInput = ref('')
const editEntries = ref([])
const editResultDialog = ref(false)
const editResult = ref({})

const categoryChoicesLabel = [
  'Analgesic / Pain Reliever', 'Antibiotic', 'Antifungal', 'Antiviral',
  'Antiparasitic', 'Antimalarial', 'Antihypertensive', 'Antidiabetic',
  'Antihistamine', 'Antacid / GI', 'Cardiovascular', 'Respiratory',
  'Central Nervous System', 'Hormonal', 'Vitamin / Supplement', 'Vaccine',
  'Dermatological', 'Ophthalmic', 'Oncology', 'Immunosuppressant', 'NSAID', 'Other',
]
const formChoicesLabel = [
  'Tablet', 'Capsule', 'Syrup', 'Injection', 'Cream', 'Ointment',
  'Drops', 'Inhaler', 'Suppository', 'Suspension', 'Powder', 'Gel',
  'Patch', 'Lozenge', 'Spray', 'Solution', 'Other',
]
const unitOptions = [
  'tab', 'cap', 'ml', 'l', 'mg', 'g', 'kg', 'vial', 'ampoule',
  'sachet', 'tube', 'drop', 'puff', 'patch', 'suppository', 'unit',
]

const medicationsLink = computed(() => ns.value + '/medications')
const seedHasUpdates = computed(() => (seedResult.value.updated ?? 0) > 0)
const seedIcon = computed(() => seedHasUpdates.value ? 'mdi-check-circle' : 'mdi-information')
const hasSeedResult = computed(() => seedResult.value != null && seedResult.value.total != null)
const hasSeedChanges = computed(() => (seedResult.value.changes || []).length > 0)
const seedChanges = computed(() => (seedResult.value.changes || []).slice(0, 10))
const seedTotalStr = computed(() => String(seedResult.value.total ?? ''))
const seedUpdatedStr = computed(() => String(seedResult.value.updated ?? ''))
const seedUnmatchedStr = computed(() => String(seedResult.value.unmatched ?? ''))

const selectedCount = computed(() => expandVariants.value.filter(v => v.selected).length)

const headers = [
  { title: '#', key: 'row_num', sortable: false, width: 60 },
  { title: 'Generic Name', key: 'key', sortable: false },
  { title: 'Brand Names', key: 'brands', sortable: false },
  { title: 'Medication', key: 'med_generic_name', sortable: false },
  { title: 'Status', key: 'has_brands', sortable: false, width: 120 },
  { title: 'Actions', key: 'actions', sortable: false, width: 230 },
]

const kpiTiles = computed(() => [
  { label: 'Dictionary entries', value: summary.value.total_generics_in_dict, icon: 'mdi-tag-multiple', color: 'teal' },
  { label: 'Brand name entries', value: summary.value.total_brand_entries, icon: 'mdi-tag', color: 'blue' },
  { label: 'Matched medications', value: summary.value.matched_to_medications, icon: 'mdi-link-variant', color: 'success' },
  { label: 'Meds without brands', value: summary.value.meds_without_brands, icon: 'mdi-alert-circle-outline', color: 'warning' },
])

const filteredCatalog = computed(() => {
  const q = (search.value || '').toLowerCase().trim()
  return catalog.value.filter(item => {
    if (filterStatus.value === 'matched' && !item.med_id) return false
    if (filterStatus.value === 'unmatched' && item.med_id) return false
    if (filterStatus.value === 'has_brands' && !item.has_brands) return false
    if (filterStatus.value === 'missing' && (!item.med_id || item.has_brands)) return false
    if (!q) return true
    return item.key.toLowerCase().includes(q) ||
           item.brands.some(b => b.toLowerCase().includes(q))
  })
})

const pagedCatalog = computed(() => {
  const start = (currentPage.value - 1) * itemsPerPage.value
  return filteredCatalog.value.slice(start, start + itemsPerPage.value)
})

watch([search, filterStatus], () => { currentPage.value = 1 })

function rowNum(index) {
  return (currentPage.value - 1) * itemsPerPage.value + index + 1
}

function onPageChange(page) { currentPage.value = page }
function onPerPageChange(size) { itemsPerPage.value = size; currentPage.value = 1 }

function previewName(v) {
  if (v.strength) return v.brand + ' ' + v.strength
  return v.brand
}

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get('/medications/brand-names/')
    catalog.value = data.catalog || []
    summary.value = data.summary || summary.value
  } catch (e) {
    notify('Failed to load brand names', 'error')
  } finally {
    loading.value = false
  }
}

async function doSeed() {
  seeding.value = true
  try {
    const { data } = await $api.post('/medications/brand-names/seed/')
    seedResult.value = data
    confirmSeed.value = false
    seedResultDialog.value = true
    if (data.updated > 0) notify(data.updated + ' medication(s) updated with brand names')
  } catch (e) {
    const msg = e?.response?.data?.detail || 'Seed failed'
    notify(msg, 'error')
  } finally {
    seeding.value = false
  }
}

function closeSeedResult() {
  seedResultDialog.value = false
  load()
}

async function doSeedAllCatalog() {
  seedingAll.value = true
  try {
    const genericsList = Array.from(selectedGenerics.value)
    const { data } = await $api.post('/medications/brand-names/expand-all/', {
      generics: genericsList,
    })
    seedAllResult.value = data
    confirmSeedAll.value = false
    seedAllResultDialog.value = true
    if (data.created) {
      notify(data.created + ' medication entries created')
    }
  } catch (e) {
    const msg = e?.response?.data?.detail || 'Failed to seed catalog'
    notify(msg, 'error')
  } finally {
    seedingAll.value = false
  }
}

function toggleGeneric(key) {
  const next = new Set(selectedGenerics.value)
  if (next.has(key)) {
    next.delete(key)
  } else {
    next.add(key)
  }
  selectedGenerics.value = next
}

function selectAllGenerics() {
  const next = new Set()
  filteredCatalog.value.forEach(item => next.add(item.key))
  selectedGenerics.value = next
}

function clearSelectedGenerics() {
  selectedGenerics.value = new Set()
}

async function expandBrand(item) {
  expandGeneric.value = item.key
  expandingKey.value = item.key
  expandDialog.value = true
  expandLoading.value = true
  expandVariants.value = []
  try {
    const { data } = await $api.post('/medications/brand-names/expand/', {
      generic_name: item.key,
    })
    expandVariants.value = data.variants || []
    formChoices.value = data.form_choices || []
  } catch (e) {
    const msg = e?.response?.data?.detail || 'Failed to load variants'
    notify(msg, 'error')
    expandDialog.value = false
  } finally {
    expandLoading.value = false
    expandingKey.value = ''
  }
}

function selectAll() {
  expandVariants.value.forEach(v => { v.selected = true })
}

function deselectAll() {
  expandVariants.value.forEach(v => { v.selected = false })
}

async function commitExpand() {
  expandCommitting.value = true
  try {
    const selected = expandVariants.value
      .filter(v => v.selected)
      .map(v => ({
        brand: v.brand,
        strength: v.strength,
        dosage_form: v.dosage_form,
        unit: v.unit,
      }))
    const { data } = await $api.post('/medications/brand-names/expand/', {
      generic_name: expandGeneric.value,
      variants: selected,
    })
    expandResult.value = data
    expandDialog.value = false
    expandResultDialog.value = true
    if (data.created) {
      notify(data.created + ' medication entries created')
    }
  } catch (e) {
    const msg = e?.response?.data?.detail || 'Failed to create medications'
    notify(msg, 'error')
  } finally {
    expandCommitting.value = false
  }
}

function openCreateDialog() {
  createForm.generic_name = ''
  createEntries.value = []
  brandInput.value = ''
  createFormSubmitted.value = false
  createExisting.value = false
  createDialog.value = true
}

function addBrand() {
  const b = brandInput.value.trim()
  if (!b) return
  const lower = b.toLowerCase()
  if (!createEntries.value.some(x => x.brand.toLowerCase() === lower)) {
    createEntries.value.push({
      brand: b,
      strength: '',
      dosage_form: '',
      category: '',
      unit: '',
      requires_prescription: false,
    })
  }
  brandInput.value = ''
}

function removeBrandEntry(i) {
  createEntries.value.splice(i, 1)
}

function lowerLabel(label) {
  return String(label || '').split(' / ')[0].trim().toLowerCase()
}

async function commitCreate() {
  createFormSubmitted.value = true
  if (!createForm.generic_name.trim() || createEntries.value.length === 0) return
  creating.value = true
  try {
    // Check if medication already exists
    const existing = catalog.value.find(c => c.key.toLowerCase() === createForm.generic_name.trim().toLowerCase())
    createExisting.value = !!existing
    const entries = createEntries.value.map(e => ({
      brand: e.brand,
      strength: e.strength || '',
      dosage_form: lowerLabel(e.dosage_form),
      category: lowerLabel(e.category),
      unit: e.unit || '',
      requires_prescription: e.requires_prescription,
    }))
    const payload = {
      generic_name: createForm.generic_name.trim(),
      entries,
    }
    const { data } = await $api.post('/medications/brand-names/create/', payload)
    createResult.value = data
    createDialog.value = false
    createResultDialog.value = true
    notify(data.detail || 'Brand entry saved')
  } catch (e) {
    const msg = e?.response?.data?.detail || 'Failed to create brand entry'
    notify(msg, 'error')
  } finally {
    creating.value = false
  }
}

function openEditDialog(item) {
  editGeneric.value = item.key
  editMedId.value = item.med_id
  editBrandInput.value = ''
  // Pre-populate entries from the dictionary brands for this generic
  const brands = item.brands || []
  editEntries.value = brands.map(b => ({
    brand: b,
    strength: '',
    dosage_form: '',
    category: '',
    unit: '',
    requires_prescription: false,
  }))
  editDialog.value = true
}

function addEditBrand() {
  const b = editBrandInput.value.trim()
  if (!b) return
  const lower = b.toLowerCase()
  if (!editEntries.value.some(x => x.brand.toLowerCase() === lower)) {
    editEntries.value.push({
      brand: b,
      strength: '',
      dosage_form: '',
      category: '',
      unit: '',
      requires_prescription: false,
    })
  }
  editBrandInput.value = ''
}

function removeEditBrandEntry(i) {
  editEntries.value.splice(i, 1)
}

async function commitEdit() {
  if (editEntries.value.length === 0) return
  editing.value = true
  try {
    const entries = editEntries.value.map(e => ({
      brand: e.brand,
      strength: e.strength || '',
      dosage_form: lowerLabel(e.dosage_form),
      category: lowerLabel(e.category),
      unit: e.unit || '',
      requires_prescription: e.requires_prescription,
    }))
    const payload = {
      generic_name: editGeneric.value.trim(),
      entries,
    }
    const { data } = await $api.post('/medications/brand-names/create/', payload)
    editResult.value = data
    editDialog.value = false
    editResultDialog.value = true
    notify(data.detail || 'Brand entry updated')
  } catch (e) {
    const msg = e?.response?.data?.detail || 'Failed to update brand entry'
    notify(msg, 'error')
  } finally {
    editing.value = false
  }
}

function notify(message, color) {
  Object.assign(snack, { show: true, color: color || 'success', message })
}

async function loadUnits() {
  try {
    const { data } = await $api.get('/inventory/units/', { params: { page_size: 1000 } })
    units.value = data?.results ?? data ?? []
  } catch (e) {
    // silently fail — units dropdown will just be empty
  }
}

onMounted(() => {
  load()
  loadUnits()
  loadFormChoices()
})

async function loadFormChoices() {
  if (formChoices.value.length) return
  formChoices.value = [
    { label: 'Tablet', value: 'tablet' },
    { label: 'Capsule', value: 'capsule' },
    { label: 'Syrup', value: 'syrup' },
    { label: 'Injection', value: 'injection' },
    { label: 'Cream', value: 'cream' },
    { label: 'Ointment', value: 'ointment' },
    { label: 'Drops', value: 'drops' },
    { label: 'Inhaler', value: 'inhaler' },
    { label: 'Suppository', value: 'suppository' },
    { label: 'Suspension', value: 'suspension' },
    { label: 'Powder', value: 'powder' },
    { label: 'Gel', value: 'gel' },
    { label: 'Patch', value: 'patch' },
    { label: 'Lozenge', value: 'lozenge' },
    { label: 'Spray', value: 'spray' },
    { label: 'Solution', value: 'solution' },
  ]
}
</script>

<style scoped>
.kpi-card {
  transition: transform 0.15s ease, box-shadow 0.15s ease;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.kpi-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 18px rgba(0, 0, 0, 0.06);
}
.expand-table :deep(td),
.expand-table :deep(th) {
  padding: 4px 8px;
  vertical-align: middle;
}
.create-table :deep(td),
.create-table :deep(th) {
  padding: 6px 8px;
  vertical-align: middle;
}
</style>
