<template>
  <v-container fluid class="pa-4 pa-md-6 ds-page" :style="themeVars">
    <!-- ═══════════════ Header ═══════════════ -->
    <header class="ds-head">
      <div class="ds-head-top">
        <div class="ds-head-icon">
          <v-icon size="26">mdi-store</v-icon>
        </div>

        <div class="ds-head-id">
          <div class="ds-head-eyebrow">
            <span class="ds-live-dot"></span>
            CLINIC · DRUG STORES &amp; MEDICATION
          </div>
          <h1 class="ds-head-title">Drug stores</h1>
          <p class="ds-head-sub">{{ headSub }}</p>
        </div>

        <div class="ds-head-actions">
          <button type="button" class="ds-btn" :disabled="loading || !stores.length" @click="exportCsv">
            <v-icon size="15">mdi-tray-arrow-down</v-icon>
            <span>Export</span>
          </button>
          <button type="button" class="ds-btn" :disabled="loading" @click="loadAll">
            <v-icon size="15" :class="{ 'ds-spin': loading }">mdi-refresh</v-icon>
            <span>Refresh</span>
          </button>
          <button type="button" class="ds-btn is-primary" @click="openCreate">
            <v-icon size="16">mdi-plus</v-icon>
            <span>Add drug store</span>
          </button>
        </div>
      </div>

      <div class="ds-head-foot">
        <span class="ds-chip">
          <v-icon size="13">mdi-store-outline</v-icon>
          {{ fmt(stores.length) }} drug store{{ stores.length === 1 ? '' : 's' }}
        </span>
        <span class="ds-chip">
          <v-icon size="13">mdi-office-building-marker</v-icon>
          {{ fmt(branchCount) }} clinic branch{{ branchCount === 1 ? '' : 'es' }}
        </span>
        <span class="ds-chip">
          <v-icon size="13">mdi-pill-multiple</v-icon>
          {{ fmt(totalMeds) }} medications
        </span>
        <span class="ds-chip" :class="totalLow ? 'ds-chip is-warn' : 'is-good'">
          <v-icon size="13">mdi-alert-outline</v-icon>
          {{ fmt(totalLow) }} low stock
        </span>
        <span v-if="profile?.license_number" class="ds-chip">
          <v-icon size="13">mdi-card-account-details-outline</v-icon>
          Licence {{ profile.license_number }}
        </span>
        <span class="ds-head-stamp">{{ updatedLabel }}</span>
      </div>
    </header>

    <!-- ═══════════════ KPI tiles ═══════════════ -->
    <div class="ds-kpis">
      <article
        v-for="k in kpiTiles"
        :key="k.key"
        class="ds-kpi"
        :style="{ '--tone': k.tone }"
        role="button"
        tabindex="0"
        @click="statusFilter = k.filter"
        @keydown.enter.prevent="statusFilter = k.filter"
      >
        <div class="ds-kpi-top">
          <span class="ds-kpi-icon"><v-icon size="16">{{ k.icon }}</v-icon></span>
          <span class="ds-kpi-label">{{ k.label }}</span>
        </div>
        <div class="ds-kpi-value">{{ k.value }}</div>
        <div class="ds-kpi-sub">{{ k.sub }}</div>
      </article>
    </div>

    <!-- ═══════════════ Toolbar ═══════════════ -->
    <section class="ds-toolbar">
      <v-text-field
        v-model="search"
        prepend-inner-icon="mdi-magnify"
        placeholder="Search stores by name, clinic branch, area, phone or email…"
        variant="outlined"
        density="compact"
        rounded="lg"
        hide-details
        clearable
        class="ds-search"
      />

      <v-select
        v-model="statusFilter"
        :items="statusOptions"
        variant="outlined"
        density="compact"
        rounded="lg"
        hide-details
        class="ds-filter"
      />

      <v-select
        v-model="siteFilter"
        :items="siteFilterOptions"
        variant="outlined"
        density="compact"
        rounded="lg"
        hide-details
        class="ds-filter"
      />

      <v-select
        v-model="sortKey"
        :items="sortOptions"
        variant="outlined"
        density="compact"
        rounded="lg"
        hide-details
        class="ds-filter"
      />

      <div class="ds-viewtoggle">
        <button type="button" :class="{ 'is-on': view === 'grid' }" title="Card view" @click="view = 'grid'">
          <v-icon size="17">mdi-view-grid-outline</v-icon>
        </button>
        <button type="button" :class="{ 'is-on': view === 'table' }" title="Table view" @click="view = 'table'">
          <v-icon size="17">mdi-format-list-bulleted</v-icon>
        </button>
      </div>
    </section>

    <!-- ═══════════════ Loading ═══════════════ -->
    <div v-if="loading && !stores.length" class="ds-grid">
      <div v-for="n in 6" :key="n" class="ds-skel"></div>
    </div>

    <!-- ═══════════════ Empty ═══════════════ -->
    <section v-else-if="!filteredStores.length" class="ds-empty">
      <div class="ds-empty-icon">
        <v-icon size="34">mdi-store-plus-outline</v-icon>
      </div>
      <template v-if="!stores.length">
        <h2>No drug store yet</h2>
        <p>
          Every clinic branch dispenses through its own drug store. Add the first outlet and its
          medication list will live right here.
        </p>
        <button type="button" class="ds-btn is-primary" @click="openCreate">
          <v-icon size="16">mdi-plus</v-icon>
          <span>Add your first drug store</span>
        </button>
      </template>
      <template v-else>
        <h2>No store matches this filter</h2>
        <p>Try a different search term, clinic branch or status.</p>
        <button type="button" class="ds-btn" @click="clearFilters">
          <v-icon size="15">mdi-filter-remove-outline</v-icon>
          <span>Clear filters</span>
        </button>
      </template>
    </section>

    <!-- ═══════════════ Card grid ═══════════════ -->
    <div v-else-if="view === 'grid'" class="ds-grid">
      <article
        v-for="store in filteredStores"
        :key="store.id"
        class="ds-card"
        :class="{ 'is-main': store.is_main, 'is-off': !store.is_active, 'is-selected': selectedId === store.id }"
        @click="selectStore(store)"
      >
        <div class="ds-card-top">
          <span class="ds-card-glyph">
            <v-icon size="20">{{ store.is_main ? 'mdi-store-check' : 'mdi-store-outline' }}</v-icon>
          </span>

          <div class="ds-card-titles">
            <h2 :title="store.name">{{ store.name }}</h2>
            <span v-if="store.site_name" class="ds-card-place">
              <v-icon size="12">mdi-office-building-marker</v-icon>{{ store.site_name }}
            </span>
            <span v-else-if="store.place_name" class="ds-card-place">
              <v-icon size="12">mdi-map-marker-outline</v-icon>{{ store.place_name }}
            </span>
            <span v-else class="ds-card-place is-faint">No clinic branch linked</span>
          </div>

          <span v-if="store.is_main" class="ds-badge is-main">
            <v-icon size="11">mdi-star</v-icon>Main
          </span>
          <span v-else class="ds-badge" :class="store.is_active ? 'is-on' : 'is-off'">
            {{ store.is_active ? 'Active' : 'Inactive' }}
          </span>
        </div>

        <div class="ds-card-body">
          <div class="ds-card-meds">
            <div>
              <span>Medications</span>
              <strong>{{ fmt(store.medication_count) }}</strong>
            </div>
            <div>
              <span>Units</span>
              <strong>{{ fmt(store.total_units) }}</strong>
            </div>
            <div>
              <span>Low</span>
              <strong :class="{ 'is-warn': store.low_stock_count }">{{ fmt(store.low_stock_count) }}</strong>
            </div>
            <div>
              <span>Out</span>
              <strong :class="{ 'is-bad': store.out_of_stock_count }">{{ fmt(store.out_of_stock_count) }}</strong>
            </div>
          </div>

          <div class="ds-row">
            <v-icon size="14">mdi-map</v-icon>
            <span :class="{ 'is-faint': !store.address }">{{ store.address || 'No address recorded' }}</span>
          </div>
          <div class="ds-row">
            <v-icon size="14">mdi-phone-outline</v-icon>
            <span :class="{ 'is-faint': !store.phone }">{{ store.phone || 'No phone number' }}</span>
          </div>
        </div>

        <footer class="ds-card-foot">
          <v-switch
            :model-value="store.is_active"
            color="success"
            density="compact"
            hide-details
            inset
            class="ds-switch"
            :loading="busyId === store.id"
            @click.stop
            @update:model-value="(v) => toggleActive(store, v)"
          />
          <span class="ds-card-foot-label">{{ store.is_active ? 'Dispensing' : 'Paused' }}</span>

          <v-spacer />

          <button type="button" class="ds-mini" title="View medications" @click.stop="selectStore(store)">
            <v-icon size="15">mdi-pill-multiple</v-icon>
          </button>
          <button
            type="button"
            class="ds-mini"
            :class="{ 'is-starred': store.is_main }"
            :disabled="store.is_main || busyId === store.id"
            :title="store.is_main ? 'Already the main store' : 'Make this the main store'"
            @click.stop="setMain(store)"
          >
            <v-icon size="15">{{ store.is_main ? 'mdi-star' : 'mdi-star-outline' }}</v-icon>
          </button>
          <button type="button" class="ds-mini" title="Edit store" @click.stop="openEdit(store)">
            <v-icon size="15">mdi-pencil-outline</v-icon>
          </button>
          <button type="button" class="ds-mini is-danger" title="Remove store" @click.stop="askDelete(store)">
            <v-icon size="15">mdi-trash-can-outline</v-icon>
          </button>
        </footer>
      </article>
    </div>

    <!-- ═══════════════ Table ═══════════════ -->
    <v-card v-else flat rounded="lg" class="ds-table-card">
      <v-data-table
        :headers="headers"
        :items="filteredStores"
        :loading="loading"
        item-value="id"
        hover
        :items-per-page="25"
        :items-per-page-options="[10, 25, 50, 100]"
        @click:row="(_, { item }) => selectStore(item)"
      >
        <template #item.name="{ item }">
          <div class="ds-cell-name">
            <span class="ds-cell-glyph" :class="{ 'is-main': item.is_main }">
              <v-icon size="16">{{ item.is_main ? 'mdi-store-check' : 'mdi-store-outline' }}</v-icon>
            </span>
            <div class="min-width-0">
              <div class="ds-cell-title">{{ item.name }}</div>
              <div v-if="item.site_name" class="ds-cell-sub">
                <v-icon size="11">mdi-office-building-marker</v-icon>{{ item.site_name }}
              </div>
              <div v-else-if="item.place_name" class="ds-cell-sub">{{ item.place_name }}</div>
            </div>
          </div>
        </template>

        <template #item.clinic_branch="{ item }">
          <span v-if="item.site_name" class="ds-cell-wrap">{{ item.site_name }}</span>
          <span v-else class="ds-dash">Unlinked</span>
        </template>

        <template #item.medication_count="{ item }">
          <div class="ds-cell-meds">
            <span class="ds-mono">{{ fmt(item.medication_count) }}</span>
            <span v-if="item.low_stock_count" class="ds-pill is-warn">{{ item.low_stock_count }} low</span>
            <span v-if="item.out_of_stock_count" class="ds-pill is-bad">{{ item.out_of_stock_count }} out</span>
          </div>
        </template>

        <template #item.total_units="{ value }">
          <span class="ds-mono">{{ fmt(value) }}</span>
        </template>

        <template #item.is_active="{ item }">
          <v-switch
            :model-value="item.is_active"
            color="success"
            density="compact"
            hide-details
            inset
            class="ds-switch"
            :loading="busyId === item.id"
            @update:model-value="(v) => toggleActive(item, v)"
            @click.stop
          />
        </template>

        <template #item.actions="{ item }">
          <div class="ds-cell-actions" @click.stop>
            <button type="button" class="ds-mini" title="View medications" @click="selectStore(item)">
              <v-icon size="15">mdi-pill-multiple</v-icon>
            </button>
            <button
              type="button"
              class="ds-mini"
              :class="{ 'is-starred': item.is_main }"
              :disabled="item.is_main"
              :title="item.is_main ? 'Already the main store' : 'Make main store'"
              @click="setMain(item)"
            >
              <v-icon size="15">{{ item.is_main ? 'mdi-star' : 'mdi-star-outline' }}</v-icon>
            </button>
            <button type="button" class="ds-mini" title="Edit" @click="openEdit(item)">
              <v-icon size="15">mdi-pencil-outline</v-icon>
            </button>
            <button type="button" class="ds-mini is-danger" title="Remove" @click="askDelete(item)">
              <v-icon size="15">mdi-trash-can-outline</v-icon>
            </button>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- ═══════════════ Selected store · medication ═══════════════ -->
    <section v-if="selectedStore" class="ds-meds">
      <header class="ds-meds-head">
        <span class="ds-meds-glyph">
          <v-icon size="19">mdi-pill-multiple</v-icon>
        </span>

        <div class="ds-meds-id">
          <div class="ds-meds-eyebrow">
            MEDICATION IN
            <span v-if="selectedStore.site_name" class="ds-meds-branch">{{ selectedStore.site_name }}</span>
          </div>
          <h2>{{ selectedStore.name }}</h2>
          <p>
            {{ fmt(selectedMedTotals.count) }} medication{{ selectedMedTotals.count === 1 ? '' : 's' }} ·
            {{ fmt(selectedMedTotals.units) }} units on hand ·
            stock value {{ money(selectedMedTotals.value) }}
          </p>
        </div>

        <div class="ds-meds-actions">
          <button type="button" class="ds-btn" @click="selectedId = null">
            <v-icon size="15">mdi-close</v-icon>
            <span>Close</span>
          </button>
          <button type="button" class="ds-btn is-primary" @click="openAddMedication">
            <v-icon size="15">mdi-pill-plus</v-icon>
            <span>Add medication</span>
          </button>
        </div>
      </header>

      <div class="ds-meds-tools">
        <v-text-field
          v-model="medSearch"
          prepend-inner-icon="mdi-magnify"
          placeholder="Search this store's medication…"
          variant="outlined"
          density="compact"
          rounded="lg"
          hide-details
          clearable
          class="ds-search"
        />
        <v-select
          v-model="medStatus"
          :items="medStatusOptions"
          variant="outlined"
          density="compact"
          rounded="lg"
          hide-details
          class="ds-filter"
        />
        <v-select
          v-model="medCategory"
          :items="medCategoryOptions"
          variant="outlined"
          density="compact"
          rounded="lg"
          hide-details
          clearable
          class="ds-filter"
        />
      </div>

      <div v-if="medsLoading" class="ds-meds-loading">
        <v-progress-linear indeterminate color="primary" rounded height="3" />
      </div>

      <div v-else-if="!filteredMeds.length" class="ds-meds-empty">
        <v-icon size="28">mdi-pill-off</v-icon>
        <strong>{{ meds.length ? 'No medication matches this filter' : 'No medication in this store yet' }}</strong>
        <span v-if="!meds.length">
          Add the drugs this branch dispenses — they become available to prescriptions immediately.
        </span>
        <span v-else>Clear the search or filters to see the full list.</span>
        <button v-if="!meds.length" type="button" class="ds-btn is-primary" @click="openAddMedication">
          <v-icon size="15">mdi-pill-plus</v-icon>
          <span>Add medication</span>
        </button>
      </div>

      <div v-else class="ds-medtable-wrap">
        <table class="ds-medtable">
          <thead>
            <tr>
              <th class="ds-mth-name">Medication</th>
              <th>Form / strength</th>
              <th>Category</th>
              <th class="ds-mth-num">On hand</th>
              <th class="ds-mth-num">Reorder</th>
              <th class="ds-mth-num">Price</th>
              <th>Status</th>
              <th class="ds-mth-act"></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="med in filteredMeds" :key="med.id">
              <td>
                <div class="ds-med-name">
                  <span class="ds-med-glyph" :class="`is-${med.status}`">
                    <v-icon size="14">{{ formIcon(med.dosage_form) }}</v-icon>
                  </span>
                  <div class="min-width-0">
                    <div class="ds-med-title">{{ med.name }}</div>
                    <div v-if="med.abbreviation || med.barcode" class="ds-med-sub">
                      {{ med.abbreviation }}<template v-if="med.abbreviation && med.barcode"> · </template>{{ med.barcode }}
                    </div>
                  </div>
                </div>
              </td>
              <td>
                <span class="ds-cell-wrap">
                  {{ labelForm(med.dosage_form) }}<template v-if="med.strength"> · {{ med.strength }}</template>
                </span>
              </td>
              <td>
                <span class="ds-cell-wrap">{{ med.category || '—' }}</span>
              </td>
              <td class="ds-mtd-num">
                <span class="ds-mono" :class="`is-${med.status}`">{{ fmt(med.on_hand) }}</span>
                <span v-if="med.committed_qty" class="ds-med-note">{{ med.committed_qty }} committed</span>
              </td>
              <td class="ds-mtd-num">
                <span class="ds-mono">{{ fmt(med.reorder_level) }}</span>
              </td>
              <td class="ds-mtd-num">
                <span class="ds-mono">{{ money(med.selling_price) }}</span>
              </td>
              <td>
                <span class="ds-pill" :class="statusClass(med.status)">{{ statusLabel(med.status) }}</span>
              </td>
              <td class="ds-mth-act">
                <div class="ds-cell-actions">
                  <button type="button" class="ds-mini" title="Restock in Inventory"
                          @click="openInventory(med)">
                    <v-icon size="15">mdi-tray-plus</v-icon>
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <footer class="ds-meds-foot">
        <span>{{ fmt(filteredMeds.length) }} of {{ fmt(meds.length) }} shown</span>
        <v-spacer />
        <button type="button" class="ds-link" @click="openInventory()">
          Manage stock in Inventory
          <v-icon size="13">mdi-arrow-top-right</v-icon>
        </button>
      </footer>
    </section>

    <!-- ═══════════════ Dispensing profile ═══════════════ -->
    <section class="ds-profile">
      <header class="ds-profile-head">
        <span class="ds-profile-icon"><v-icon size="17">mdi-clipboard-text-outline</v-icon></span>
        <div class="ds-profile-titles">
          <h2>Dispensing profile</h2>
          <p>Licence, opening hours and services shared by every store in this clinic network</p>
        </div>
        <button type="button" class="ds-btn" @click="navigateTo('/clinics/settings')">
          <v-icon size="15">mdi-cog-outline</v-icon>
          <span>Manage in settings</span>
        </button>
      </header>

      <div v-if="profile" class="ds-profile-body">
        <div class="ds-profile-block">
          <span class="ds-profile-label">Facility</span>
          <strong>{{ profile.name || auth.tenantName || 'Clinic' }}</strong>
          <span v-if="profile.license_number" class="ds-profile-note">
            Licence {{ profile.license_number }}
          </span>
          <span v-else class="ds-profile-note is-faint">No licence recorded</span>
        </div>

        <div class="ds-profile-block">
          <span class="ds-profile-label">Opening hours</span>
          <div class="ds-hours">
            <span v-for="d in hoursRows" :key="d.key" class="ds-hour" :class="{ 'is-closed': !d.open }">
              <b>{{ d.short }}</b>
              <span>{{ d.open ? `${d.from}–${d.to}` : 'Closed' }}</span>
            </span>
          </div>
        </div>

        <div class="ds-profile-block">
          <span class="ds-profile-label">Services</span>
          <div v-if="profile.services?.length" class="ds-tags">
            <span v-for="s in profile.services" :key="s" class="ds-tag">{{ s }}</span>
          </div>
          <span v-else class="ds-profile-note is-faint">No services listed</span>
        </div>

        <div class="ds-profile-block">
          <span class="ds-profile-label">Delivery</span>
          <strong>{{ money(profile.delivery_fee) }}</strong>
          <span class="ds-profile-note">
            {{ profile.delivery_radius_km ? `${profile.delivery_radius_km} km radius` : 'No delivery radius set' }}
          </span>
          <span class="ds-profile-note" :class="{ 'is-faint': !profile.accepts_insurance }">
            {{ profile.accepts_insurance ? `${profile.insurance_providers?.length || 0} insurers accepted` : 'No insurance accepted' }}
          </span>
        </div>
      </div>

      <div v-else class="ds-profile-empty">
        <v-icon size="22">mdi-alert-circle-outline</v-icon>
        <span>
          No dispensing profile yet. Set the clinic licence, hours and services in
          <button type="button" class="ds-link" @click="navigateTo('/clinics/settings')">Clinic settings</button>
          so prescriptions can be dispensed.
        </span>
      </div>
    </section>

    <!-- ═══════════════ Add / edit store dialog ═══════════════ -->
    <v-dialog v-model="formOpen" max-width="640" persistent scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader
          :icon="editing ? 'mdi-pencil-outline' : 'mdi-store-plus-outline'"
          :title="editing ? 'Edit drug store' : 'Add drug store'"
          :subtitle="editing
            ? 'Update this outlet’s branch, identity and contact details'
            : 'Register a dispensing outlet for a clinic branch'"
          @close="closeForm"
        >
          <template #actions>
            <span class="ds-dialog-chip">{{ form.is_main ? 'Main store' : 'Branch store' }}</span>
          </template>
        </BrandDialogHeader>

        <v-card-text class="pt-4">
          <div class="ds-form-note">
            <v-icon size="15">mdi-information-outline</v-icon>
            <span>
              Each drug store belongs to one clinic branch and holds that branch's medication.
              Admins see every store across every branch; staff only see the store they are assigned to.
            </span>
          </div>

          <div class="ds-field">
            <label class="ds-label">Clinic branch <span class="ds-req">*</span></label>
            <v-select
              v-model="form.site"
              :items="siteOptions"
              item-title="label"
              item-value="value"
              placeholder="Select the clinic branch this store dispenses for"
              variant="outlined"
              density="comfortable"
              rounded="lg"
              prepend-inner-icon="mdi-office-building-marker"
              hide-details="auto"
              :error-messages="errors.site"
            />
          </div>

          <div class="ds-field">
            <label class="ds-label">Store name <span class="ds-req">*</span></label>
            <v-text-field
              v-model="form.name"
              placeholder="e.g. CityCare Main Pharmacy"
              variant="outlined"
              density="comfortable"
              rounded="lg"
              prepend-inner-icon="mdi-store-outline"
              hide-details="auto"
              :error-messages="errors.name"
            />
          </div>

          <div class="ds-field-row">
            <div class="ds-field">
              <label class="ds-label">Area</label>
              <v-text-field
                v-model="form.place_name"
                placeholder="e.g. Kilimani"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                prepend-inner-icon="mdi-map-marker-outline"
                hide-details
              />
            </div>
            <div class="ds-field">
              <label class="ds-label">Phone</label>
              <v-text-field
                v-model="form.phone"
                placeholder="+254 700 000 000"
                variant="outlined"
                density="comfortable"
                rounded="lg"
                prepend-inner-icon="mdi-phone-outline"
                hide-details
              />
            </div>
          </div>

          <div class="ds-field">
            <label class="ds-label">Email</label>
            <v-text-field
              v-model="form.email"
              placeholder="store@clinic.co"
              type="email"
              variant="outlined"
              density="comfortable"
              rounded="lg"
              prepend-inner-icon="mdi-email-outline"
              hide-details="auto"
              :error-messages="errors.email"
            />
          </div>

          <div class="ds-field">
            <label class="ds-label">Address</label>
            <v-textarea
              v-model="form.address"
              placeholder="Street, building, floor…"
              rows="2"
              auto-grow
              variant="outlined"
              density="comfortable"
              rounded="lg"
              prepend-inner-icon="mdi-map-outline"
              hide-details
            />
          </div>

          <div class="ds-toggle-row">
            <div class="ds-toggle">
              <div>
                <strong>Active store</strong>
                <span>Inactive stores stay on record but cannot dispense</span>
              </div>
              <v-switch v-model="form.is_active" color="success" density="compact" hide-details inset />
            </div>
            <div class="ds-toggle">
              <div>
                <strong>Main store</strong>
                <span>Used as the default outlet for new prescriptions</span>
              </div>
              <v-switch v-model="form.is_main" color="amber-darken-3" density="compact" hide-details inset />
            </div>
          </div>
        </v-card-text>

        <v-divider />

        <v-card-actions class="px-5 py-3">
          <v-btn variant="text" rounded="lg" class="text-none" :disabled="saving" @click="closeForm">
            Cancel
          </v-btn>
          <v-spacer />
          <v-btn
            color="primary"
            variant="flat"
            rounded="lg"
            class="text-none"
            :loading="saving"
            :prepend-icon="editing ? 'mdi-content-save-outline' : 'mdi-plus'"
            @click="save"
          >
            {{ editing ? 'Save changes' : 'Add drug store' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ Add medication dialog ═══════════════ -->
    <v-dialog v-model="medOpen" max-width="680" persistent scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader
          icon="mdi-pill-plus"
          title="Add medication"
          :subtitle="`Stock a medication in ${selectedStore?.name || 'this drug store'}`"
          @close="closeAddMedication"
        >
          <template #actions>
            <span class="ds-dialog-chip">{{ selectedStore?.site_name || 'Store stock' }}</span>
          </template>
        </BrandDialogHeader>

        <v-card-text class="pt-4">
          <div class="ds-form-note">
            <v-icon size="15">mdi-information-outline</v-icon>
            <span>
              This adds the medication to this branch's drug store and makes it available to
              prescriptions. Prices and batches are tracked per store.
            </span>
          </div>

          <div class="ds-field">
            <label class="ds-label">Medication name <span class="ds-req">*</span></label>
            <v-autocomplete
              v-model="medForm.name"
              :items="catalogOptions"
              item-title="title"
              item-value="title"
              placeholder="e.g. Amoxicillin 500mg"
              variant="outlined"
              density="comfortable"
              rounded="lg"
              prepend-inner-icon="mdi-pill"
              hide-details="auto"
              :error-messages="medErrors.name"
              @update:model-value="onCatalogPick"
            />
          </div>

          <div class="ds-field-row">
            <div class="ds-field">
              <label class="ds-label">Strength</label>
              <v-text-field v-model="medForm.strength" placeholder="500mg"
                variant="outlined" density="comfortable" rounded="lg"
                prepend-inner-icon="mdi-scale" hide-details />
            </div>
            <div class="ds-field">
              <label class="ds-label">Dosage form</label>
              <v-select v-model="medForm.dosage_form" :items="formOptions"
                variant="outlined" density="comfortable" rounded="lg"
                prepend-inner-icon="mdi-pill-multiple" hide-details />
            </div>
          </div>

          <div class="ds-field-row">
            <div class="ds-field">
              <label class="ds-label">Category</label>
              <v-select v-model="medForm.category" :items="categoryOptions"
                item-title="name" item-value="id" variant="outlined"
                density="comfortable" rounded="lg" clearable
                prepend-inner-icon="mdi-tag-multiple" hide-details />
            </div>
            <div class="ds-field">
              <label class="ds-label">Unit</label>
              <v-select v-model="medForm.unit" :items="unitOptions"
                item-title="name" item-value="id" variant="outlined"
                density="comfortable" rounded="lg" clearable
                prepend-inner-icon="mdi-ruler" hide-details />
            </div>
          </div>

          <div class="ds-field-row">
            <div class="ds-field">
              <label class="ds-label">Selling price <span class="ds-req">*</span></label>
              <v-text-field v-model.number="medForm.selling_price" type="number" min="0" step="0.01"
                placeholder="0.00" variant="outlined" density="comfortable" rounded="lg"
                prepend-inner-icon="mdi-cash" hide-details="auto"
                :error-messages="medErrors.selling_price" />
            </div>
            <div class="ds-field">
              <label class="ds-label">Opening quantity</label>
              <v-text-field v-model.number="medForm.initial_quantity" type="number" min="0" step="1"
                placeholder="0" variant="outlined" density="comfortable" rounded="lg"
                prepend-inner-icon="mdi-counter" hide-details />
            </div>
          </div>

          <div class="ds-field-row">
            <div class="ds-field">
              <label class="ds-label">Reorder level</label>
              <v-text-field v-model.number="medForm.reorder_level" type="number" min="0" step="1"
                variant="outlined" density="comfortable" rounded="lg"
                prepend-inner-icon="mdi-alert-outline" hide-details />
            </div>
            <div class="ds-field">
              <label class="ds-label">Batch number</label>
              <v-text-field v-model="medForm.batch_number" placeholder="Auto"
                variant="outlined" density="comfortable" rounded="lg"
                prepend-inner-icon="mdi-barcode" hide-details />
            </div>
          </div>

          <div class="ds-field">
            <label class="ds-label">Expiry date</label>
            <v-text-field v-model="medForm.expiry_date" type="date"
              variant="outlined" density="comfortable" rounded="lg"
              prepend-inner-icon="mdi-calendar-clock" hide-details />
          </div>
        </v-card-text>

        <v-divider />

        <v-card-actions class="px-5 py-3">
          <v-btn variant="text" rounded="lg" class="text-none" :disabled="medSaving" @click="closeAddMedication">
            Cancel
          </v-btn>
          <v-spacer />
          <v-btn
            color="primary"
            variant="flat"
            rounded="lg"
            class="text-none"
            :loading="medSaving"
            prepend-icon="mdi-plus"
            @click="saveMedication"
          >
            Add medication
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ Delete confirm ═══════════════ -->
    <v-dialog v-model="deleteOpen" max-width="440">
      <v-card rounded="xl">
        <BrandDialogHeader
          icon="mdi-trash-can-outline"
          title="Remove drug store"
          :subtitle="deleteTarget?.name || ''"
          @close="deleteOpen = false"
        />
        <v-card-text class="pt-4">
          <p class="ds-confirm-text">
            This removes <strong>{{ deleteTarget?.name }}</strong> from the clinic network. Stores
            that still hold medication or stock-transfer history cannot be removed — deactivate them instead.
          </p>
        </v-card-text>
        <v-card-actions class="px-5 py-3">
          <v-btn variant="text" rounded="lg" class="text-none" @click="deleteOpen = false">Cancel</v-btn>
          <v-spacer />
          <v-btn
            color="error"
            variant="flat"
            rounded="lg"
            class="text-none"
            :loading="deleting"
            prepend-icon="mdi-trash-can-outline"
            @click="confirmDelete"
          >
            Remove store
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="bottom right" rounded="lg" timeout="4200">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useAuthStore } from '~/stores/auth'

const { $api } = useNuxtApp()
const auth = useAuthStore()
const brand = useBranding()

const branchesApi = '/pharmacy-profile/branches/'
const profileApi = '/pharmacy-profile/profile/'

// ── State ───────────────────────────────────────────────────────────────
const stores = ref([])
const profile = ref(null)
const loading = ref(false)
const saving = ref(false)
const deleting = ref(false)
const busyId = ref(null)
const updatedAt = ref(null)
const now = ref(Date.now())

const search = ref('')
const statusFilter = ref('all')
const siteFilter = ref('all')
const sortKey = ref('main')
const view = ref('grid')

const sites = ref([])          // clinic branches
const categories = ref([])
const units = ref([])
const catalog = ref([])        // medication catalog (for the autocomplete)

const selectedId = ref(null)
const meds = ref([])
const medsLoading = ref(false)
const medSearch = ref('')
const medStatus = ref('all')
const medCategory = ref(null)

const formOpen = ref(false)
const editing = ref(null)
const errors = reactive({ name: '', email: '', site: '' })
const form = reactive(blankForm())

const medOpen = ref(false)
const medSaving = ref(false)
const medErrors = reactive({ name: '', selling_price: '' })
const medForm = reactive(blankMedForm())

const deleteOpen = ref(false)
const deleteTarget = ref(null)

const snack = reactive({ show: false, color: 'success', text: '' })
function notify(text, color = 'success') {
  Object.assign(snack, { show: true, color, text })
}

const statusOptions = [
  { title: 'All stores', value: 'all' },
  { title: 'Active', value: 'active' },
  { title: 'Inactive', value: 'inactive' },
  { title: 'Main store', value: 'main' },
]

const sortOptions = [
  { title: 'Main first', value: 'main' },
  { title: 'Name A–Z', value: 'name' },
  { title: 'Most stock', value: 'stock' },
  { title: 'Newest first', value: 'newest' },
]

const medStatusOptions = [
  { title: 'All stock', value: 'all' },
  { title: 'In stock', value: 'ok' },
  { title: 'Low stock', value: 'low' },
  { title: 'Out of stock', value: 'out' },
]

const formOptions = [
  { title: 'Tablet', value: 'tablet' },
  { title: 'Capsule', value: 'capsule' },
  { title: 'Syrup', value: 'syrup' },
  { title: 'Suspension', value: 'suspension' },
  { title: 'Injection', value: 'injection' },
  { title: 'Cream', value: 'cream' },
  { title: 'Ointment', value: 'ointment' },
  { title: 'Gel', value: 'gel' },
  { title: 'Drops', value: 'drops' },
  { title: 'Inhaler', value: 'inhaler' },
  { title: 'Suppository', value: 'suppository' },
  { title: 'Powder', value: 'powder' },
  { title: 'Spray', value: 'spray' },
  { title: 'Solution', value: 'solution' },
  { title: 'Patch', value: 'patch' },
  { title: 'Lozenge', value: 'lozenge' },
  { title: 'Other', value: 'other' },
]

const days = [
  { key: 'mon', short: 'Mon' }, { key: 'tue', short: 'Tue' }, { key: 'wed', short: 'Wed' },
  { key: 'thu', short: 'Thu' }, { key: 'fri', short: 'Fri' }, { key: 'sat', short: 'Sat' },
  { key: 'sun', short: 'Sun' },
]

const headers = [
  { title: 'Store', key: 'name', sortable: true },
  { title: 'Clinic branch', key: 'clinic_branch', sortable: false },
  { title: 'Medication', key: 'medication_count', sortable: false, width: 190 },
  { title: 'Units', key: 'total_units', sortable: false, width: 90 },
  { title: 'Active', key: 'is_active', sortable: false, width: 90 },
  { title: '', key: 'actions', sortable: false, width: 140 },
]

const themeVars = computed(() => ({
  '--ds-accent': brand.primary.value,
  '--ds-on-accent': brand.onPrimary.value,
  '--ds-accent-ink': brand.ink.value,
  '--ds-accent-soft': brand.tint('primary', 0.18),
  '--ds-accent-ring': brand.tint('primary', 0.24),
}))

// ── Derived ─────────────────────────────────────────────────────────────
const activeCount = computed(() => stores.value.filter(s => s.is_active).length)
const mainStore = computed(() => stores.value.find(s => s.is_main) || null)
const totalMeds = computed(() => stores.value.reduce((n, s) => n + (s.medication_count || 0), 0))
const totalLow = computed(() => stores.value.reduce((n, s) => n + (s.low_stock_count || 0), 0))
const branchCount = computed(() => {
  const set = new Set(stores.value.map(s => s.site).filter(Boolean))
  return set.size || sites.value.length
})

const selectedStore = computed(() =>
  stores.value.find(s => s.id === selectedId.value) || null,
)

const headSub = computed(() => {
  if (!stores.value.length) {
    return 'Every clinic branch dispenses through its own drug store — add the first one below.'
  }
  return `${activeCount.value} of ${stores.value.length} store${stores.value.length === 1 ? '' : 's'} dispensing · ` +
    `${fmt(totalMeds.value)} medication line${totalMeds.value === 1 ? '' : 's'} tracked across ` +
    `${branchCount.value} clinic branch${branchCount.value === 1 ? '' : 'es'}.`
})

const updatedLabel = computed(() => {
  if (!updatedAt.value) return 'Not synced yet'
  const mins = Math.floor((now.value - updatedAt.value) / 60000)
  if (mins < 1) return 'Synced just now'
  if (mins < 60) return `Synced ${mins}m ago`
  return `Synced ${Math.floor(mins / 60)}h ago`
})

const kpiTiles = computed(() => [
  {
    key: 'total', label: 'Drug stores', icon: 'mdi-store-marker-outline', tone: '#2f6dff',
    value: fmt(stores.value.length), sub: 'one per clinic branch', filter: 'all',
  },
  {
    key: 'active', label: 'Dispensing now', icon: 'mdi-check-decagram-outline', tone: '#10b981',
    value: fmt(activeCount.value), sub: 'active outlets', filter: 'active',
  },
  {
    key: 'meds', label: 'Medications', icon: 'mdi-pill-multiple', tone: '#8b5cf6',
    value: fmt(totalMeds.value), sub: 'stock lines across stores', filter: 'all',
  },
  {
    key: 'low', label: 'Low stock', icon: 'mdi-alert-outline', tone: '#f59e0b',
    value: fmt(totalLow.value), sub: 'need replenishing', filter: 'all',
  },
])

const siteOptions = computed(() =>
  sites.value
    .filter(s => s.is_active !== false)
    .map(s => ({
      value: s.id,
      label: `${s.name}${s.is_hq ? ' (HQ)' : ''}${s.code ? ` · ${s.code}` : ''}${s.has_store && editing.value?.site !== s.id ? ' · has store' : ''}`,
    })),
)

const siteFilterOptions = computed(() => {
  const seen = new Map()
  for (const s of stores.value) {
    if (s.site && !seen.has(s.site)) seen.set(s.site, s.site_name || `Branch ${s.site}`)
  }
  return [
    { title: 'All clinic branches', value: 'all' },
    ...[...seen.entries()].map(([value, title]) => ({ title, value: String(value) })),
  ]
})

const filteredStores = computed(() => {
  const q = search.value.trim().toLowerCase()
  let rows = stores.value.filter((s) => {
    if (statusFilter.value === 'active' && !s.is_active) return false
    if (statusFilter.value === 'inactive' && s.is_active) return false
    if (statusFilter.value === 'main' && !s.is_main) return false
    if (siteFilter.value !== 'all' && String(s.site) !== String(siteFilter.value)) return false
    if (!q) return true
    return [s.name, s.site_name, s.place_name, s.address, s.phone, s.email]
      .some(v => String(v || '').toLowerCase().includes(q))
  })

  rows = [...rows]
  if (sortKey.value === 'name') rows.sort((a, b) => String(a.name).localeCompare(String(b.name)))
  else if (sortKey.value === 'newest') rows.sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
  else if (sortKey.value === 'stock') rows.sort((a, b) => (b.medication_count || 0) - (a.medication_count || 0))
  else rows.sort((a, b) => Number(b.is_main) - Number(a.is_main) || String(a.name).localeCompare(String(b.name)))
  return rows
})

const hoursRows = computed(() => {
  const hours = profile.value?.operating_hours || {}
  return days.map((d) => {
    const slot = hours[d.key] || {}
    return { key: d.key, short: d.short, open: !!slot.open, from: slot.from || '—', to: slot.to || '—' }
  })
})

// ── Medication derived ──────────────────────────────────────────────────
const selectedMedTotals = computed(() => {
  let count = 0, units = 0, value = 0, low = 0, out = 0
  for (const m of meds.value) {
    count += 1
    units += m.on_hand || 0
    value += m.stock_value || 0
    if (m.status === 'low') low += 1
    if (m.status === 'out') out += 1
  }
  return { count, units, value, low, out }
})

const medCategoryOptions = computed(() => {
  const set = new Set(meds.value.map(m => m.category).filter(Boolean))
  return [...set].sort()
})

const filteredMeds = computed(() => {
  const q = medSearch.value.trim().toLowerCase()
  return meds.value.filter((m) => {
    if (medStatus.value !== 'all' && m.status !== medStatus.value) return false
    if (medCategory.value && m.category !== medCategory.value) return false
    if (!q) return true
    return [m.name, m.generic_name, m.abbreviation, m.barcode, m.strength, m.category, m.dosage_form]
      .some(v => String(v || '').toLowerCase().includes(q))
  })
})

const catalogOptions = computed(() =>
  catalog.value.map(m => ({ title: m.title })).slice(0, 300),
)

// ── Formatting ──────────────────────────────────────────────────────────
function fmt(n) {
  return (Number(n) || 0).toLocaleString('en-US')
}
function money(n) {
  const v = Number(n) || 0
  if (!v) return '—'
  return `KES ${v.toLocaleString('en-US', { maximumFractionDigits: 2 })}`
}
function labelForm(v) {
  if (!v) return '—'
  const found = formOptions.find(o => o.value === v)
  return found ? found.title : String(v).replace(/_/g, ' ')
}
function formIcon(f) {
  const map = {
    tablet: 'mdi-pill', capsule: 'mdi-pill', syrup: 'mdi-bottle-tonic',
    suspension: 'mdi-bottle-tonic', injection: 'mdi-needle', cream: 'mdi-tube',
    ointment: 'mdi-tube', gel: 'mdi-tube', drops: 'mdi-eyedropper',
    inhaler: 'mdi-inhaler', suppository: 'mdi-pill', powder: 'mdi-flask',
    spray: 'mdi-spray', solution: 'mdi-flask', patch: 'mdi-sticker',
    lozenge: 'mdi-candy', other: 'mdi-pill',
  }
  return map[f] || 'mdi-pill'
}
function statusLabel(s) {
  return { ok: 'In stock', low: 'Low', out: 'Out' }[s] || '—'
}
function statusClass(s) {
  return { ok: 'is-good', low: 'is-warn', out: 'is-bad' }[s] || ''
}

function blankForm() {
  return {
    site: null,
    name: '', place_name: '', phone: '', email: '', address: '',
    is_main: false, is_active: true,
  }
}
function blankMedForm() {
  return {
    name: '', strength: '', dosage_form: 'tablet', category: null, unit: null,
    selling_price: '', initial_quantity: 0, reorder_level: 10,
    batch_number: '', expiry_date: '',
  }
}

// ── Data ────────────────────────────────────────────────────────────────
function rowsOf(payload) {
  if (Array.isArray(payload)) return payload
  return payload?.results || []
}

async function loadStores({ silent = false } = {}) {
  if (!silent) loading.value = true
  try {
    const { data } = await $api.get(branchesApi, {
      params: { page_size: 500, ordering: 'name' },
    })
    stores.value = rowsOf(data)
    updatedAt.value = Date.now()
    now.value = Date.now()
    // Keep the open store in sync after a refresh.
    if (selectedId.value && !stores.value.some(s => s.id === selectedId.value)) {
      selectedId.value = null
      meds.value = []
    }
  } catch (e) {
    if (!silent) notify(apiMessage(e, 'Could not load drug stores.'), 'error')
  } finally {
    if (!silent) loading.value = false
  }
}

async function loadProfile() {
  try {
    const { data } = await $api.get(profileApi, { params: { page_size: 1 } })
    const list = rowsOf(data)
    profile.value = list.length ? list[0] : null
  } catch {
    profile.value = null
  }
}

async function loadSites() {
  try {
    const { data } = await $api.get(`${branchesApi}clinic-branches/`)
    sites.value = rowsOf(data)
  } catch {
    sites.value = []
  }
}

async function loadLookups() {
  const [cat, unit, meds] = await Promise.all([
    $api.get('/inventory/categories/', { params: { page_size: 500 } }).catch(() => null),
    $api.get('/inventory/units/', { params: { page_size: 500 } }).catch(() => null),
    $api.get('/medications/', { params: { page_size: 1000, ordering: 'generic_name' } }).catch(() => null),
  ])
  categories.value = cat ? rowsOf(cat.data) : []
  units.value = unit ? rowsOf(unit.data) : []
  const catalogRows = meds ? rowsOf(meds.data) : []
  catalog.value = catalogRows.map(m => ({
    id: m.id,
    title: [m.generic_name, m.strength].filter(Boolean).join(' '),
    generic_name: m.generic_name,
    strength: m.strength,
    dosage_form: m.dosage_form,
  }))
}

async function loadMedications(storeId) {
  if (!storeId) {
    meds.value = []
    return
  }
  medsLoading.value = true
  try {
    const { data } = await $api.get(`${branchesApi}${storeId}/medications/`)
    meds.value = data?.results || []
  } catch (e) {
    meds.value = []
    notify(apiMessage(e, 'Could not load this store’s medication.'), 'error')
  } finally {
    medsLoading.value = false
  }
}

async function loadAll() {
  await Promise.all([loadStores(), loadProfile(), loadSites()])
  if (selectedId.value) await loadMedications(selectedId.value)
}

async function selectStore(store) {
  selectedId.value = store.id
  medSearch.value = ''
  medStatus.value = 'all'
  medCategory.value = null
  await loadMedications(store.id)
  if (import.meta.client) {
    await nextTick()
    document.querySelector('.ds-meds')?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }
}

// ── Validation ──────────────────────────────────────────────────────────
function validate() {
  errors.name = form.name.trim() ? '' : 'A store name is required.'
  errors.site = form.site ? '' : 'Choose the clinic branch this store belongs to.'
  const email = form.email.trim()
  errors.email = !email || /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
    ? ''
    : 'Enter a valid email address.'
  return !errors.name && !errors.email && !errors.site
}

// ── Store CRUD ──────────────────────────────────────────────────────────
function openCreate() {
  editing.value = null
  Object.assign(form, blankForm(), { is_main: !stores.value.length })
  // Pre-select the first branch that has no store yet.
  const free = sites.value.find(s => !s.has_store)
  form.site = free ? free.id : (sites.value[0]?.id || null)
  errors.name = ''
  errors.email = ''
  errors.site = ''
  formOpen.value = true
}

function openEdit(store) {
  editing.value = store
  Object.assign(form, blankForm(), {
    site: store.site || null,
    name: store.name || '',
    place_name: store.place_name || '',
    phone: store.phone || '',
    email: store.email || '',
    address: store.address || '',
    is_main: !!store.is_main,
    is_active: store.is_active !== false,
  })
  errors.name = ''
  errors.email = ''
  errors.site = ''
  formOpen.value = true
}

function closeForm() {
  if (saving.value) return
  formOpen.value = false
  editing.value = null
}

function payload() {
  return {
    site: form.site,
    name: form.name.trim(),
    place_name: form.place_name.trim(),
    phone: form.phone.trim(),
    email: form.email.trim(),
    address: form.address.trim(),
    is_active: !!form.is_active,
    is_main: !!form.is_main,
  }
}

async function save() {
  if (!validate()) return
  saving.value = true
  try {
    if (editing.value) {
      const { data } = await $api.patch(`${branchesApi}${editing.value.id}/`, payload())
      if (data?.is_main) await demoteOthers(data.id)
      notify(`${data?.name || 'Drug store'} updated.`)
    } else {
      const { data } = await $api.post(branchesApi, payload())
      if (data?.is_main) await demoteOthers(data.id)
      notify(`${data?.name || 'Drug store'} added to the clinic.`)
    }
    formOpen.value = false
    editing.value = null
    await Promise.all([loadStores({ silent: true }), loadSites()])
  } catch (e) {
    notify(apiMessage(e, 'Could not save the drug store.'), 'error')
  } finally {
    saving.value = false
  }
}

async function demoteOthers(mainId) {
  const others = stores.value.filter(s => s.is_main && s.id !== mainId)
  await Promise.all(others.map(s =>
    $api.patch(`${branchesApi}${s.id}/`, { is_main: false }).catch(() => null)))
}

async function toggleActive(store, value) {
  busyId.value = store.id
  try {
    await $api.patch(`${branchesApi}${store.id}/`, { is_active: !!value })
    store.is_active = !!value
    notify(`${store.name} is ${value ? 'now dispensing' : 'paused'}.`)
  } catch (e) {
    notify(apiMessage(e, 'Could not update this store.'), 'error')
  } finally {
    busyId.value = null
  }
}

async function setMain(store) {
  if (store.is_main) return
  busyId.value = store.id
  try {
    await demoteOthers(store.id)
    await $api.patch(`${branchesApi}${store.id}/`, { is_main: true })
    notify(`${store.name} is now the main store.`)
    await loadStores({ silent: true })
  } catch (e) {
    notify(apiMessage(e, 'Could not set the main store.'), 'error')
  } finally {
    busyId.value = null
  }
}

function askDelete(store) {
  deleteTarget.value = store
  deleteOpen.value = true
}

async function confirmDelete() {
  if (!deleteTarget.value) return
  deleting.value = true
  try {
    await $api.delete(`${branchesApi}${deleteTarget.value.id}/`)
    notify(`${deleteTarget.value.name} removed.`)
    if (selectedId.value === deleteTarget.value.id) {
      selectedId.value = null
      meds.value = []
    }
    deleteOpen.value = false
    deleteTarget.value = null
    await Promise.all([loadStores({ silent: true }), loadSites()])
  } catch (e) {
    notify(apiMessage(e, 'Could not remove this store.'), 'error')
  } finally {
    deleting.value = false
  }
}

// ── Add medication ──────────────────────────────────────────────────────
async function openAddMedication() {
  Object.assign(medForm, blankMedForm())
  medErrors.name = ''
  medErrors.selling_price = ''
  if (!categories.value.length || !units.value.length) await loadLookups()
  medOpen.value = true
}

function closeAddMedication() {
  if (medSaving.value) return
  medOpen.value = false
}

function onCatalogPick(title) {
  const hit = catalog.value.find(c => c.title === title)
  if (!hit) return
  medForm.strength = hit.strength || ''
  if (hit.dosage_form) medForm.dosage_form = hit.dosage_form
}

function validateMed() {
  medErrors.name = medForm.name.trim() ? '' : 'A medication name is required.'
  const price = Number(medForm.selling_price)
  medErrors.selling_price = Number.isFinite(price) && price >= 0 && medForm.selling_price !== ''
    ? ''
    : 'Enter a selling price.'
  return !medErrors.name && !medErrors.selling_price
}

async function saveMedication() {
  if (!validateMed() || !selectedStore.value) return
  medSaving.value = true
  try {
    const body = {
      branch: selectedStore.value.id,
      medication_name: medForm.name.trim(),
      generic_name: medForm.name.trim(),
      strength: medForm.strength || '',
      dosage_form: medForm.dosage_form || '',
      selling_price: Number(medForm.selling_price),
      cost_price: 0,
      reorder_level: Number(medForm.reorder_level) || 0,
      initial_quantity: Number(medForm.initial_quantity) || 0,
      batch_number: medForm.batch_number || '',
      is_active: true,
    }
    if (medForm.category) body.category = medForm.category
    if (medForm.unit) body.unit = medForm.unit
    if (medForm.expiry_date) body.expiry_date = medForm.expiry_date

    await $api.post('/inventory/stocks/', body)
    notify(`${medForm.name.trim()} added to ${selectedStore.value.name}.`)
    medOpen.value = false
    await Promise.all([loadMedications(selectedStore.value.id), loadStores({ silent: true })])
  } catch (e) {
    notify(apiMessage(e, 'Could not add this medication.'), 'error')
  } finally {
    medSaving.value = false
  }
}

function openInventory(med) {
  const q = med?.name || ''
  navigateTo({ path: '/clinics/inventory', query: q ? { q } : {} })
}

// ── Helpers ─────────────────────────────────────────────────────────────
function apiMessage(e, fallback) {
  const data = e?.response?.data
  if (typeof data === 'string' && data) return data
  if (data?.detail) return data.detail
  if (data && typeof data === 'object') {
    const first = Object.entries(data)[0]
    if (first) {
      const [field, value] = first
      return `${field.replace(/_/g, ' ')}: ${Array.isArray(value) ? value.join(', ') : value}`
    }
  }
  return e?.message || fallback
}

function clearFilters() {
  search.value = ''
  statusFilter.value = 'all'
  siteFilter.value = 'all'
}

// ── Export ──────────────────────────────────────────────────────────────
function exportCsv() {
  if (!import.meta.client) return
  const rows = [[
    'Store', 'Clinic branch', 'Area', 'Address', 'Phone', 'Email',
    'Main', 'Active', 'Medications', 'Units', 'Low stock', 'Out of stock',
  ]]
  filteredStores.value.forEach((s) => {
    rows.push([
      s.name || '', s.site_name || '', s.place_name || '', s.address || '', s.phone || '', s.email || '',
      s.is_main ? 'Yes' : 'No', s.is_active ? 'Yes' : 'No',
      s.medication_count ?? 0, s.total_units ?? 0, s.low_stock_count ?? 0, s.out_of_stock_count ?? 0,
    ])
  })

  // When a store is open, append its medication list so one export covers both.
  if (selectedStore.value && meds.value.length) {
    rows.push([])
    rows.push([`Medication in ${selectedStore.value.name}`])
    rows.push(['Name', 'Form', 'Strength', 'Category', 'On hand', 'Reorder level', 'Price', 'Status'])
    meds.value.forEach((m) => {
      rows.push([
        m.name || '', labelForm(m.dosage_form), m.strength || '', m.category || '',
        m.on_hand ?? 0, m.reorder_level ?? 0, m.selling_price ?? 0, statusLabel(m.status),
      ])
    })
  }

  const csv = rows
    .map(row => row.map(cell => `"${String(cell ?? '').replace(/"/g, '""')}"`).join(','))
    .join('\r\n')
  const blob = new Blob([`\ufeff${csv}`], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = `clinic-drug-stores-${new Date().toISOString().slice(0, 10)}.csv`
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
  URL.revokeObjectURL(url)
  notify('Drug store list exported.', 'success')
}

// ── Lifecycle ───────────────────────────────────────────────────────────
onMounted(async () => {
  const route = useRoute()
  // Deep link from elsewhere: /clinics/drug-stores?store=<id> or ?q=<name>
  const storeParam = route.query.store
  const q = route.query.q
  if (typeof q === 'string' && q.trim()) search.value = q.trim()

  await loadAll()

  if (storeParam) {
    const target = stores.value.find(s => String(s.id) === String(storeParam))
    if (target) selectStore(target)
  } else if (stores.value.length === 1) {
    // Single-branch clinics land straight in their store's medication.
    selectStore(stores.value[0])
  }

  void loadLookups()
})
</script>

<style scoped>
.min-width-0 { min-width: 0; }

/* ══ Page tokens ═══════════════════════════════════════════════════════ */
.ds-page {
  width: 100%;
  --ds-line: rgba(var(--v-theme-on-surface), 0.09);
  --ds-line-soft: rgba(var(--v-theme-on-surface), 0.06);
  --ds-muted: rgba(var(--v-theme-on-surface), 0.6);
  --ds-faint: rgba(var(--v-theme-on-surface), 0.44);
  --ds-surface: rgb(var(--v-theme-surface));
  --ds-raise: rgba(var(--v-theme-on-surface), 0.035);
}

/* ══ Header ════════════════════════════════════════════════════════════ */
.ds-head {
  position: relative;
  border-radius: 18px;
  padding: 17px 20px 12px;
  margin-bottom: 14px;
  background: var(--ds-surface);
  border: 1px solid var(--ds-line);
  box-shadow: 0 10px 30px rgba(15, 23, 42, 0.055);
  overflow: hidden;
}
.ds-head::before {
  content: '';
  position: absolute;
  inset: 0 auto 0 0;
  width: 4px;
  background: linear-gradient(180deg, var(--ds-accent), var(--ds-accent-soft));
}
.ds-head-top { display: flex; align-items: center; gap: 14px; flex-wrap: wrap; min-width: 0; }
.ds-head-icon {
  width: 50px; height: 50px; border-radius: 15px;
  display: grid; place-items: center; flex-shrink: 0;
  color: var(--ds-accent-ink);
  background: color-mix(in srgb, var(--ds-accent) 12%, transparent);
  border: 1px solid color-mix(in srgb, var(--ds-accent) 22%, transparent);
}
.ds-head-id { flex: 1; min-width: 220px; }
.ds-head-eyebrow {
  display: inline-flex; align-items: center; gap: 6px;
  font-size: 9.5px; font-weight: 800; letter-spacing: 1.4px;
  text-transform: uppercase; color: var(--ds-faint);
}
.ds-head-title { margin: 3px 0 2px; font-size: 24px; line-height: 1.15; font-weight: 800; letter-spacing: -0.4px; }
.ds-head-sub { margin: 0; font-size: 12.5px; line-height: 1.45; color: var(--ds-muted); }
.ds-head-actions { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; justify-content: flex-end; }
.ds-head-foot {
  display: flex; align-items: center; gap: 7px; flex-wrap: wrap;
  margin-top: 13px; padding-top: 11px;
  border-top: 1px solid var(--ds-line-soft);
}
.ds-head-stamp { margin-left: auto; font-size: 10.5px; font-weight: 700; color: var(--ds-faint); white-space: nowrap; }
.ds-live-dot {
  width: 7px; height: 7px; border-radius: 50%;
  background: #22c55e;
  animation: dsPulse 2s infinite;
}
@keyframes dsPulse {
  0% { box-shadow: 0 0 0 0 rgba(34, 197, 94, 0.5); }
  70% { box-shadow: 0 0 0 6px rgba(34, 197, 94, 0); }
  100% { box-shadow: 0 0 0 0 rgba(34, 197, 94, 0); }
}

.ds-chip {
  display: inline-flex; align-items: center; gap: 5px;
  height: 25px; padding: 0 9px; border-radius: 999px;
  border: 1px solid var(--ds-line); background: var(--ds-raise);
  font-size: 10.5px; font-weight: 700; color: var(--ds-muted);
  white-space: nowrap; max-width: 280px; overflow: hidden; text-overflow: ellipsis;
}
.ds-chip.is-good { color: #047857; border-color: rgba(16, 185, 129, 0.28); background: rgba(16, 185, 129, 0.08); }
.ds-chip.is-warn { color: #b45309; border-color: rgba(245, 158, 11, 0.3); background: rgba(245, 158, 11, 0.09); }

.ds-btn {
  display: inline-flex; align-items: center; gap: 6px;
  height: 36px; padding: 0 13px; border-radius: 10px;
  border: 1px solid var(--ds-line);
  background: transparent;
  color: rgb(var(--v-theme-on-surface));
  font-family: inherit; font-size: 12.5px; font-weight: 700;
  cursor: pointer; white-space: nowrap;
  transition: background 0.15s ease, transform 0.15s ease, opacity 0.15s ease;
}
.ds-btn:hover:not(:disabled) { background: rgba(var(--v-theme-on-surface), 0.045); transform: translateY(-1px); }
.ds-btn:disabled { opacity: 0.5; cursor: not-allowed; }
.ds-btn.is-primary {
  background: var(--ds-accent); color: var(--ds-on-accent);
  border-color: transparent; box-shadow: 0 7px 18px var(--ds-accent-ring);
}
/* Keep the solid fill on hover — the generic hover rule would otherwise win
   on specificity and leave a white label on a transparent background. */
.ds-btn.is-primary:hover:not(:disabled) {
  background: var(--ds-accent);
  color: var(--ds-on-accent);
  border-color: transparent;
  filter: brightness(1.06);
}
.ds-btn.is-primary:active:not(:disabled) { filter: brightness(0.96); }
.ds-spin { animation: dsSpin 0.9s linear infinite; }
@keyframes dsSpin { to { transform: rotate(360deg); } }

/* ══ KPIs ══════════════════════════════════════════════════════════════ */
.ds-kpis {
  display: grid; grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 11px; margin-bottom: 14px;
}
.ds-kpi {
  position: relative; padding: 12px 14px 11px;
  border-radius: 15px; background: var(--ds-surface);
  border: 1px solid var(--ds-line); cursor: pointer; overflow: hidden;
  transition: transform 0.16s ease, box-shadow 0.16s ease, border-color 0.16s ease;
}
.ds-kpi::before {
  content: ''; position: absolute; inset: 0 auto 0 0;
  width: 3px; background: var(--tone); opacity: 0.72;
}
.ds-kpi:hover {
  transform: translateY(-2px);
  border-color: color-mix(in srgb, var(--tone) 36%, transparent);
  box-shadow: 0 10px 24px color-mix(in srgb, var(--tone) 13%, transparent);
}
.ds-kpi-top { display: flex; align-items: center; gap: 7px; margin-bottom: 6px; }
.ds-kpi-icon {
  width: 27px; height: 27px; border-radius: 9px;
  display: grid; place-items: center; flex-shrink: 0;
  color: var(--tone); background: color-mix(in srgb, var(--tone) 12%, transparent);
}
.ds-kpi-label {
  font-size: 9.5px; font-weight: 800; letter-spacing: 0.7px;
  text-transform: uppercase; color: var(--ds-faint);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.ds-kpi-value {
  font-size: 23px; font-weight: 800; line-height: 1.1; letter-spacing: -0.4px;
  color: var(--tone); font-variant-numeric: tabular-nums;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.ds-kpi-sub {
  margin-top: 2px; font-size: 10.5px; font-weight: 600; color: var(--ds-muted);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}

/* ══ Toolbar ═══════════════════════════════════════════════════════════ */
.ds-toolbar, .ds-meds-tools {
  display: flex; align-items: center; gap: 9px; flex-wrap: wrap;
  padding: 10px 12px; margin-bottom: 14px;
  border-radius: 14px; border: 1px solid var(--ds-line); background: var(--ds-surface);
}
.ds-search { flex: 1 1 300px; min-width: 190px; }
.ds-filter { flex: 0 1 168px; min-width: 130px; }
.ds-toolbar :deep(.v-field), .ds-meds-tools :deep(.v-field) { font-size: 12.5px; }

.ds-viewtoggle {
  display: inline-flex; gap: 2px; padding: 3px;
  border-radius: 10px; border: 1px solid var(--ds-line); background: var(--ds-raise);
}
.ds-viewtoggle button {
  width: 30px; height: 28px; display: grid; place-items: center;
  border: 0; border-radius: 8px; background: transparent;
  color: var(--ds-muted); cursor: pointer;
  transition: background 0.15s ease, color 0.15s ease;
}
.ds-viewtoggle button.is-on {
  background: var(--ds-surface); color: var(--ds-accent);
  box-shadow: 0 1px 5px rgba(15, 23, 42, 0.12);
}

/* ══ Grid + cards ══════════════════════════════════════════════════════ */
.ds-grid {
  display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 12px; margin-bottom: 14px;
}
.ds-skel {
  height: 232px; border-radius: 15px; border: 1px solid var(--ds-line-soft);
  background: linear-gradient(100deg,
    rgba(var(--v-theme-on-surface), 0.04) 20%,
    rgba(var(--v-theme-on-surface), 0.08) 38%,
    rgba(var(--v-theme-on-surface), 0.04) 56%);
  background-size: 220% 100%;
  animation: dsShimmer 1.4s ease-in-out infinite;
}
@keyframes dsShimmer {
  0% { background-position: 120% 0; }
  100% { background-position: -40% 0; }
}

.ds-card {
  display: flex; flex-direction: column;
  border-radius: 15px; border: 1px solid var(--ds-line);
  background: var(--ds-surface); overflow: hidden; cursor: pointer;
  transition: transform 0.16s ease, box-shadow 0.16s ease, border-color 0.16s ease;
}
.ds-card:hover {
  transform: translateY(-2px);
  border-color: color-mix(in srgb, var(--ds-accent) 30%, transparent);
  box-shadow: 0 12px 26px rgba(15, 23, 42, 0.09);
}
.ds-card.is-main { border-color: rgba(245, 158, 11, 0.4); }
.ds-card.is-off { opacity: 0.82; }
.ds-card.is-selected {
  border-color: var(--ds-accent);
  box-shadow: 0 0 0 1px var(--ds-accent-soft), 0 14px 30px rgba(15, 23, 42, 0.12);
}

.ds-card-top {
  display: flex; align-items: flex-start; gap: 10px;
  padding: 12px 13px 10px;
  border-bottom: 1px solid var(--ds-line-soft);
  background: linear-gradient(180deg, rgba(var(--v-theme-on-surface), 0.022), transparent);
}
.ds-card-glyph {
  width: 38px; height: 38px; border-radius: 11px;
  display: grid; place-items: center; flex-shrink: 0;
  color: var(--ds-accent-ink);
  background: color-mix(in srgb, var(--ds-accent) 12%, transparent);
  border: 1px solid color-mix(in srgb, var(--ds-accent) 20%, transparent);
}
.ds-card.is-main .ds-card-glyph {
  color: #b45309; background: rgba(245, 158, 11, 0.14); border-color: rgba(245, 158, 11, 0.28);
}
.ds-card-titles { flex: 1; min-width: 0; }
.ds-card-titles h2 {
  margin: 0; font-size: 13.5px; font-weight: 800; line-height: 1.25; letter-spacing: -0.1px;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.ds-card-place {
  display: inline-flex; align-items: center; gap: 3px; margin-top: 2px;
  font-size: 10.5px; font-weight: 700; color: var(--ds-muted);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 100%;
}
.ds-card-place.is-faint { color: var(--ds-faint); font-weight: 600; }

.ds-badge {
  display: inline-flex; align-items: center; gap: 3px;
  height: 21px; padding: 0 7px; border-radius: 999px;
  font-size: 9px; font-weight: 800; letter-spacing: 0.3px; text-transform: uppercase;
  white-space: nowrap; flex-shrink: 0; border: 1px solid transparent;
}
.ds-badge.is-main { color: #92400e; background: rgba(245, 158, 11, 0.16); border-color: rgba(245, 158, 11, 0.3); }
.ds-badge.is-on { color: #047857; background: rgba(16, 185, 129, 0.13); border-color: rgba(16, 185, 129, 0.25); }
.ds-badge.is-off { color: var(--ds-faint); background: rgba(var(--v-theme-on-surface), 0.06); border-color: var(--ds-line-soft); }

.ds-card-body {
  display: flex; flex-direction: column; gap: 6px;
  padding: 11px 13px; flex: 1; min-width: 0;
}
.ds-card-meds {
  display: grid; grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 6px; padding-bottom: 9px; margin-bottom: 3px;
  border-bottom: 1px solid var(--ds-line-soft);
}
.ds-card-meds > div { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
.ds-card-meds span {
  font-size: 8.5px; font-weight: 800; letter-spacing: 0.5px;
  text-transform: uppercase; color: var(--ds-faint);
}
.ds-card-meds strong {
  font-size: 14px; font-weight: 800; font-variant-numeric: tabular-nums;
  color: rgb(var(--v-theme-on-surface));
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.ds-card-meds strong.is-warn { color: #b45309; }
.ds-card-meds strong.is-bad { color: #b91c1c; }

.ds-row {
  display: flex; align-items: flex-start; gap: 7px;
  font-size: 11px; line-height: 1.45; color: var(--ds-muted); min-width: 0;
}
.ds-row .v-icon { color: var(--ds-faint); flex-shrink: 0; margin-top: 1px; }
.ds-row span { min-width: 0; overflow-wrap: anywhere; }
.ds-row span.is-faint { color: var(--ds-faint); font-style: italic; }

.ds-card-foot {
  display: flex; align-items: center; gap: 6px;
  padding: 7px 11px 8px;
  border-top: 1px solid var(--ds-line-soft);
  background: rgba(var(--v-theme-on-surface), 0.02);
}
.ds-card-foot-label {
  font-size: 9.5px; font-weight: 800; letter-spacing: 0.4px;
  text-transform: uppercase; color: var(--ds-faint);
}
.ds-switch { flex-shrink: 0; }
.ds-switch :deep(.v-switch__track) { opacity: 0.9; }

.ds-mini {
  width: 28px; height: 28px; display: grid; place-items: center;
  border-radius: 8px; border: 1px solid transparent; background: transparent;
  color: var(--ds-muted); cursor: pointer;
  transition: background 0.15s ease, color 0.15s ease, border-color 0.15s ease;
}
.ds-mini:hover:not(:disabled) {
  background: rgba(var(--v-theme-on-surface), 0.06);
  border-color: var(--ds-line);
  color: rgb(var(--v-theme-on-surface));
}
.ds-mini:disabled { opacity: 0.42; cursor: not-allowed; }
.ds-mini.is-starred { color: #d97706; }
.ds-mini.is-danger:hover:not(:disabled) { color: #dc2626; background: rgba(239, 68, 68, 0.1); border-color: rgba(239, 68, 68, 0.22); }

/* ══ Store table ═══════════════════════════════════════════════════════ */
.ds-table-card { margin-bottom: 14px; overflow: hidden; }
.ds-table-card :deep(.v-data-table__th) { font-size: 10.5px !important; }
.ds-cell-name { display: flex; align-items: center; gap: 9px; min-width: 0; padding: 2px 0; }
.ds-cell-glyph {
  width: 30px; height: 30px; border-radius: 9px;
  display: grid; place-items: center; flex-shrink: 0;
  color: var(--ds-muted); background: rgba(var(--v-theme-on-surface), 0.06);
}
.ds-cell-glyph.is-main { color: #b45309; background: rgba(245, 158, 11, 0.14); }
.ds-cell-title { font-size: 12px; font-weight: 700; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.ds-cell-sub {
  display: inline-flex; align-items: center; gap: 3px;
  font-size: 9.5px; font-weight: 700; color: var(--ds-faint);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.ds-cell-wrap { font-size: 11px; color: var(--ds-muted); overflow-wrap: anywhere; }
.ds-cell-actions { display: flex; align-items: center; gap: 2px; }
.ds-cell-meds { display: flex; align-items: center; gap: 5px; flex-wrap: wrap; }
.ds-mono { font-size: 11px; font-weight: 700; font-variant-numeric: tabular-nums; }
.ds-dash { color: var(--ds-faint); }

.ds-pill {
  display: inline-flex; align-items: center;
  height: 18px; padding: 0 6px; border-radius: 999px;
  font-size: 9px; font-weight: 800; letter-spacing: 0.3px; text-transform: uppercase;
  white-space: nowrap;
  color: var(--ds-muted); background: rgba(var(--v-theme-on-surface), 0.06);
}
.ds-pill.is-good { color: #047857; background: rgba(16, 185, 129, 0.13); }
.ds-pill.is-warn { color: #b45309; background: rgba(245, 158, 11, 0.16); }
.ds-pill.is-bad { color: #b91c1c; background: rgba(239, 68, 68, 0.11); }

/* ══ Selected store · medication ═══════════════════════════════════════ */
.ds-meds {
  border-radius: 16px; border: 1px solid var(--ds-line);
  background: var(--ds-surface); overflow: hidden; margin-bottom: 14px;
  animation: dsMedIn 0.24s ease both;
}
@keyframes dsMedIn {
  from { opacity: 0; transform: translateY(6px); }
  to { opacity: 1; transform: translateY(0); }
}
.ds-meds-head {
  display: flex; align-items: center; gap: 11px; flex-wrap: wrap;
  padding: 13px 14px 12px;
  border-bottom: 1px solid var(--ds-line-soft);
  background: linear-gradient(180deg, rgba(var(--v-theme-on-surface), 0.025), transparent);
}
.ds-meds-glyph {
  width: 38px; height: 38px; border-radius: 11px; flex-shrink: 0;
  display: grid; place-items: center;
  color: #6d28d9; background: rgba(139, 92, 246, 0.13);
  border: 1px solid rgba(139, 92, 246, 0.24);
}
.ds-meds-id { flex: 1; min-width: 200px; }
.ds-meds-eyebrow {
  display: inline-flex; align-items: center; gap: 6px;
  font-size: 9px; font-weight: 800; letter-spacing: 1.2px;
  text-transform: uppercase; color: var(--ds-faint);
}
.ds-meds-branch {
  display: inline-flex; align-items: center;
  height: 18px; padding: 0 7px; border-radius: 999px;
  font-size: 9px; letter-spacing: 0.3px;
  color: var(--ds-accent-ink);
  background: color-mix(in srgb, var(--ds-accent) 11%, transparent);
  border: 1px solid color-mix(in srgb, var(--ds-accent) 22%, transparent);
  text-transform: none;
}
.ds-meds-id h2 { margin: 2px 0 1px; font-size: 15.5px; font-weight: 800; letter-spacing: -0.2px; }
.ds-meds-id p { margin: 0; font-size: 11px; color: var(--ds-muted); }
.ds-meds-actions { display: flex; align-items: center; gap: 7px; }

.ds-meds-tools { margin: 12px 14px 0; }

.ds-meds-loading { padding: 18px 14px; }
.ds-meds-empty {
  display: flex; flex-direction: column; align-items: center; gap: 5px;
  padding: 34px 20px; text-align: center;
  color: var(--ds-muted);
}
.ds-meds-empty .v-icon { color: var(--ds-faint); margin-bottom: 3px; }
.ds-meds-empty strong { font-size: 13px; font-weight: 800; color: rgb(var(--v-theme-on-surface)); }
.ds-meds-empty span { font-size: 11.5px; line-height: 1.5; max-width: 46ch; }
.ds-meds-empty .ds-btn { margin-top: 8px; }

.ds-medtable-wrap { overflow-x: auto; padding: 12px 14px 4px; }
.ds-medtable { width: 100%; border-collapse: collapse; }
.ds-medtable thead th {
  padding: 7px 9px; text-align: left;
  font-size: 9px; font-weight: 800; letter-spacing: 0.7px; text-transform: uppercase;
  color: var(--ds-faint); border-bottom: 1px solid var(--ds-line); white-space: nowrap;
}
.ds-medtable tbody tr { border-bottom: 1px solid var(--ds-line-soft); transition: background 0.13s ease; }
.ds-medtable tbody tr:last-child { border-bottom: 0; }
.ds-medtable tbody tr:hover { background: rgba(var(--v-theme-on-surface), 0.025); }
.ds-medtable td { padding: 8px 9px; vertical-align: middle; }
.ds-mth-name { width: 30%; }
.ds-mth-num { text-align: right; }
.ds-mtd-num { text-align: right; white-space: nowrap; }
.ds-mth-act { width: 44px; }

.ds-med-name { display: flex; align-items: center; gap: 8px; min-width: 0; }
.ds-med-glyph {
  width: 26px; height: 26px; border-radius: 8px; flex-shrink: 0;
  display: grid; place-items: center;
  color: var(--ds-muted); background: rgba(var(--v-theme-on-surface), 0.055);
}
.ds-med-glyph.is-ok { color: #047857; background: rgba(16, 185, 129, 0.12); }
.ds-med-glyph.is-low { color: #b45309; background: rgba(245, 158, 11, 0.16); }
.ds-med-glyph.is-out { color: #b91c1c; background: rgba(239, 68, 68, 0.1); }
.ds-med-title {
  font-size: 12px; font-weight: 700;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.ds-med-sub {
  font-size: 9.5px; font-weight: 700; color: var(--ds-faint);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.ds-med-note { display: block; font-size: 9px; color: var(--ds-faint); font-weight: 600; }
.ds-mono.is-ok { color: #047857; }
.ds-mono.is-low { color: #b45309; }
.ds-mono.is-out { color: #b91c1c; }

.ds-meds-foot {
  display: flex; align-items: center; gap: 8px;
  padding: 10px 14px 11px;
  border-top: 1px solid var(--ds-line-soft);
  font-size: 10.5px; font-weight: 700; color: var(--ds-faint);
}

/* ══ Empty ═════════════════════════════════════════════════════════════ */
.ds-empty {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: 6px; padding: 44px 20px; margin-bottom: 14px;
  border-radius: 16px; border: 1px dashed var(--ds-line);
  background: var(--ds-raise); text-align: center;
}
.ds-empty-icon {
  width: 62px; height: 62px; border-radius: 18px;
  display: grid; place-items: center; margin-bottom: 4px;
  color: var(--ds-accent);
  background: color-mix(in srgb, var(--ds-accent) 10%, transparent);
  border: 1px solid color-mix(in srgb, var(--ds-accent) 20%, transparent);
}
.ds-empty h2 { margin: 0; font-size: 16px; font-weight: 800; letter-spacing: -0.2px; }
.ds-empty p { margin: 0 0 8px; max-width: 520px; font-size: 12px; line-height: 1.55; color: var(--ds-muted); }

/* ══ Dispensing profile ════════════════════════════════════════════════ */
.ds-profile { border-radius: 16px; border: 1px solid var(--ds-line); background: var(--ds-surface); overflow: hidden; }
.ds-profile-head {
  display: flex; align-items: center; gap: 10px; flex-wrap: wrap;
  padding: 11px 14px; border-bottom: 1px solid var(--ds-line-soft);
  background: linear-gradient(180deg, rgba(var(--v-theme-on-surface), 0.025), transparent);
}
.ds-profile-icon {
  width: 30px; height: 30px; border-radius: 9px;
  display: grid; place-items: center; flex-shrink: 0;
  color: #0d9488; background: rgba(13, 148, 136, 0.11);
}
.ds-profile-titles { flex: 1; min-width: 160px; }
.ds-profile-titles h2 { margin: 0; font-size: 13px; font-weight: 800; }
.ds-profile-titles p { margin: 1px 0 0; font-size: 10.5px; color: var(--ds-faint); line-height: 1.35; }

.ds-profile-body {
  display: grid; grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 16px; padding: 13px 14px 15px;
}
.ds-profile-block { display: flex; flex-direction: column; gap: 3px; min-width: 0; }
.ds-profile-label {
  font-size: 8.5px; font-weight: 800; letter-spacing: 0.6px;
  text-transform: uppercase; color: var(--ds-faint);
}
.ds-profile-block strong { font-size: 13px; font-weight: 800; letter-spacing: -0.1px; }
.ds-profile-note { font-size: 10.5px; color: var(--ds-muted); font-weight: 600; }
.ds-profile-note.is-faint { color: var(--ds-faint); font-style: italic; font-weight: 600; }

.ds-hours { display: flex; flex-wrap: wrap; gap: 4px; }
.ds-hour {
  display: inline-flex; flex-direction: column; gap: 0;
  padding: 3px 6px; border-radius: 7px;
  border: 1px solid var(--ds-line-soft); background: var(--ds-raise);
  font-size: 9px; line-height: 1.3; font-variant-numeric: tabular-nums;
}
.ds-hour b { font-size: 8.5px; font-weight: 800; color: var(--ds-faint); letter-spacing: 0.3px; }
.ds-hour.is-closed { opacity: 0.55; }

.ds-tags { display: flex; flex-wrap: wrap; gap: 4px; }
.ds-tag {
  display: inline-flex; align-items: center;
  height: 20px; padding: 0 7px; border-radius: 999px;
  font-size: 9.5px; font-weight: 700;
  color: var(--ds-accent-ink);
  background: color-mix(in srgb, var(--ds-accent) 10%, transparent);
  border: 1px solid color-mix(in srgb, var(--ds-accent) 20%, transparent);
  max-width: 100%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}

.ds-profile-empty {
  display: flex; align-items: flex-start; gap: 8px;
  padding: 14px; font-size: 11.5px; line-height: 1.55; color: var(--ds-muted);
}
.ds-profile-empty .v-icon { color: #f59e0b; flex-shrink: 0; margin-top: 1px; }
.ds-link {
  display: inline-flex; align-items: center; gap: 4px;
  border: 0; background: none; padding: 0;
  font-family: inherit; font-size: inherit; font-weight: 800;
  color: var(--ds-accent); cursor: pointer;
  text-decoration: underline; text-underline-offset: 2px;
}

/* ══ Dialog form ═══════════════════════════════════════════════════════ */
.ds-dialog-chip {
  display: inline-flex; align-items: center;
  height: 22px; padding: 0 8px; border-radius: 999px;
  font-size: 9.5px; font-weight: 800; letter-spacing: 0.3px; text-transform: uppercase;
  background: rgba(255, 255, 255, 0.18);
  border: 1px solid rgba(255, 255, 255, 0.32);
  color: #fff; white-space: nowrap;
}
.ds-form-note {
  display: flex; align-items: flex-start; gap: 8px;
  padding: 9px 11px; margin-bottom: 14px;
  border-radius: 10px; border: 1px solid var(--ds-line-soft); background: var(--ds-raise);
  font-size: 11px; line-height: 1.5; color: var(--ds-muted);
}
.ds-form-note .v-icon { color: var(--ds-accent); flex-shrink: 0; margin-top: 1px; }

.ds-field { margin-bottom: 12px; min-width: 0; }
.ds-field-row { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
.ds-label {
  display: block; margin-bottom: 5px;
  font-size: 10.5px; font-weight: 800; letter-spacing: 0.5px;
  text-transform: uppercase; color: var(--ds-faint);
}
.ds-req { color: #dc2626; }

.ds-toggle-row { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-top: 2px; }
.ds-toggle {
  display: flex; align-items: center; justify-content: space-between; gap: 10px;
  padding: 9px 11px; border-radius: 11px;
  border: 1px solid var(--ds-line-soft); background: var(--ds-raise); min-width: 0;
}
.ds-toggle div { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
.ds-toggle strong { font-size: 11.5px; font-weight: 800; }
.ds-toggle span { font-size: 9.5px; line-height: 1.35; color: var(--ds-faint); }

.ds-confirm-text { margin: 0; font-size: 12.5px; line-height: 1.6; color: var(--ds-muted); }
.ds-confirm-text strong { color: rgb(var(--v-theme-on-surface)); }

/* ══ Responsive ════════════════════════════════════════════════════════ */
@media (max-width: 1199px) {
  .ds-profile-body { grid-template-columns: repeat(2, minmax(0, 1fr)); }
}
@media (max-width: 959px) {
  .ds-kpis { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .ds-head-actions { width: 100%; justify-content: flex-start; }
  .ds-head-stamp { margin-left: 0; }
}
@media (max-width: 767px) {
  .ds-kpi-value { font-size: 19px; }
  .ds-head-title { font-size: 20px; }
  .ds-search { flex-basis: 100%; }
  .ds-filter { flex: 1 1 140px; }
  .ds-grid { grid-template-columns: minmax(0, 1fr); }
  .ds-profile-body { grid-template-columns: minmax(0, 1fr); gap: 12px; }
  .ds-field-row, .ds-toggle-row { grid-template-columns: minmax(0, 1fr); }
  .ds-meds-actions { width: 100%; }
}
</style>
