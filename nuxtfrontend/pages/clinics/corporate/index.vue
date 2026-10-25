<template>
  <v-container fluid class="pa-4 pa-md-6 cp-page">
    <!-- ═══════════════ Header ═══════════════ -->
    <header class="cp-head">
      <div class="cp-head-top">
        <div class="cp-head-icon"><v-icon size="26">mdi-domain</v-icon></div>
        <div class="cp-head-id">
          <div class="cp-head-eyebrow"><span class="cp-dot" />CLINIC · CORPORATE BILLING</div>
          <h1 class="cp-head-title">Corporate dashboard</h1>
          <p class="cp-head-sub">
            Employer accounts, the staff roster eligible for treatment, and the job cards
            that verify them before a visit is billed to the company.
          </p>
        </div>
        <div class="cp-head-actions">
          <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-refresh"
                 :loading="loading" @click="loadAll">Refresh</v-btn>
          <v-btn variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-database-plus-outline"
                 :loading="seeding" @click="seedDemo">Load demo</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus"
                 @click="openCorporate()">Add corporate</v-btn>
        </div>
      </div>

      <div class="cp-head-foot">
        <span class="cp-chip"><v-icon size="13">mdi-domain</v-icon>{{ fmt(kpis.corporates_total) }} companies</span>
        <span class="cp-chip is-good"><v-icon size="13">mdi-check-decagram</v-icon>{{ fmt(kpis.corporates_active) }} active</span>
        <span class="cp-chip"><v-icon size="13">mdi-account-hard-hat</v-icon>{{ fmt(kpis.staff_eligible) }} eligible staff</span>
        <span class="cp-chip" :class="{ 'is-warn': kpis.documents_pending }">
          <v-icon size="13">mdi-file-alert-outline</v-icon>{{ fmt(kpis.documents_pending) }} documents to verify
        </span>
        <span class="cp-chip" :class="{ 'is-warn': kpis.expiring_staff }">
          <v-icon size="13">mdi-clock-alert-outline</v-icon>{{ fmt(kpis.expiring_staff) }} cover expiring
        </span>
        <span class="cp-head-stamp">{{ updatedLabel }}</span>
      </div>
    </header>

    <!-- ═══════════════ KPI tiles ═══════════════ -->
    <section class="cp-kpis">
      <article v-for="k in tiles" :key="k.key" class="cp-kpi" :style="{ '--tone': k.tone }">
        <div class="cp-kpi-top">
          <span class="cp-kpi-icon"><v-icon size="16">{{ k.icon }}</v-icon></span>
          <span class="cp-kpi-label">{{ k.label }}</span>
        </div>
        <div class="cp-kpi-value">{{ k.value }}</div>
        <div class="cp-kpi-sub">{{ k.sub }}</div>
      </article>
    </section>

    <!-- Actions strip -->
    <section class="cp-actions">
      <button type="button" class="cp-action" @click="openStaff()">
        <v-icon size="16">mdi-account-plus-outline</v-icon>
        <span>Add staff to roster</span>
      </button>
      <button type="button" class="cp-action" @click="openBulk()">
        <v-icon size="16">mdi-file-upload-outline</v-icon>
        <span>Upload staff list</span>
      </button>
      <button type="button" class="cp-action" @click="openDocument()">
        <v-icon size="16">mdi-card-account-details-outline</v-icon>
        <span>Upload job card</span>
      </button>
      <span class="cp-actions-note">
        Only verified staff with valid cover appear as eligible for treatment.
      </span>
    </section>

    <!-- ═══════════════ Tabs ═══════════════ -->
    <v-tabs v-model="tab" density="comfortable" class="cp-tabs" color="primary">
      <v-tab value="overview">Companies</v-tab>
      <v-tab value="staff">Staff roster</v-tab>
      <v-tab value="documents">
        Documents
        <v-badge v-if="kpis.documents_pending" :content="kpis.documents_pending" color="error" inline class="ml-2" />
      </v-tab>
    </v-tabs>

    <v-window v-model="tab" class="cp-window">
      <!-- ─── Companies ─── -->
      <v-window-item value="overview">
        <v-text-field v-model="clientSearch" prepend-inner-icon="mdi-magnify"
                      placeholder="Search companies by name, code or contact…"
                      variant="outlined" density="compact" rounded="lg" hide-details
                      clearable class="mb-3" />

        <v-table class="cp-table" hover>
          <thead>
            <tr>
              <th>Company</th>
              <th>Status</th>
              <th>Contract ends</th>
              <th class="text-center">Staff</th>
              <th class="text-center">Eligible</th>
              <th class="text-center">Docs</th>
              <th class="text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="c in filteredClients" :key="c.id">
              <td>
                <div class="cp-company">
                  <span class="cp-company-avatar">{{ initials(c.name) }}</span>
                  <div class="min-w-0">
                    <div class="cp-company-name">{{ c.name }}</div>
                    <div class="cp-company-meta">
                      {{ c.code || 'No code' }} · {{ c.industry || 'General' }}
                      <template v-if="c.contact_person"> · {{ c.contact_person }}</template>
                    </div>
                  </div>
                </div>
              </td>
              <td>
                <v-chip size="x-small" variant="tonal" :color="statusColor(c.status)">
                  {{ c.status_label }}
                </v-chip>
              </td>
              <td>
                <span :class="{ 'cp-warn-text': contractExpiring(c) }">
                  {{ c.contract_end ? formatDate(c.contract_end) : '—' }}
                </span>
              </td>
              <td class="text-center">{{ c.staff_count }}</td>
              <td class="text-center">
                <span class="cp-eligible">{{ c.eligible_count }}</span>
              </td>
              <td class="text-center">
                <v-chip v-if="c.pending_docs" size="x-small" color="warning" variant="tonal">
                  {{ c.pending_docs }}
                </v-chip>
                <span v-else class="text-medium-emphasis">—</span>
              </td>
              <td class="text-right">
                <v-btn icon="mdi-account-group-outline" variant="text" size="small"
                       title="View roster" @click="viewRoster(c)" />
                <v-btn icon="mdi-file-upload-outline" variant="text" size="small"
                       title="Upload document" @click="openDocument(c)" />
                <v-btn v-if="c.status !== 'active'" icon="mdi-check-decagram-outline"
                       variant="text" size="small" color="success" title="Verify company"
                       @click="setCorporateStatus(c, true)" />
                <v-btn v-else icon="mdi-pause-circle-outline" variant="text" size="small"
                       color="warning" title="Suspend" @click="setCorporateStatus(c, false)" />
              </td>
            </tr>
            <tr v-if="!filteredClients.length">
              <td colspan="7">
                <div class="cp-empty">
                  <v-icon size="26">mdi-domain-off</v-icon>
                  <p>No corporate accounts yet. Add one, or load the demo data.</p>
                </div>
              </td>
            </tr>
          </tbody>
        </v-table>
      </v-window-item>

      <!-- ─── Staff roster ─── -->
      <v-window-item value="staff">
        <div class="cp-toolbar">
          <v-select v-model="staffCorporate" :items="corporateOptions" item-title="name"
                    item-value="id" label="Company" variant="outlined" density="compact"
                    rounded="lg" hide-details clearable class="cp-tool" />
          <v-select v-model="staffVerification" :items="verificationOptions" item-title="title"
                    item-value="value" label="Verification" variant="outlined" density="compact"
                    rounded="lg" hide-details clearable class="cp-tool" />
          <v-text-field v-model="staffSearch" prepend-inner-icon="mdi-magnify"
                        placeholder="Search name, staff number, ID…" variant="outlined"
                        density="compact" rounded="lg" hide-details clearable class="cp-tool cp-tool--grow" />
          <v-btn color="primary" variant="flat" rounded="lg" class="text-none"
                 prepend-icon="mdi-account-plus-outline" @click="openStaff()">Add staff</v-btn>
        </div>

        <v-table class="cp-table" hover>
          <thead>
            <tr>
              <th>Staff</th>
              <th>Staff no.</th>
              <th>Company</th>
              <th>Cover until</th>
              <th>Status</th>
              <th>Verification</th>
              <th class="text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="s in filteredStaff" :key="s.id">
              <td>
                <div class="cp-company">
                  <span class="cp-company-avatar cp-company-avatar--sm">{{ initials(s.full_name) }}</span>
                  <div class="min-w-0">
                    <div class="cp-company-name">{{ s.full_name }}</div>
                    <div class="cp-company-meta">
                      {{ s.job_title || 'Staff' }}<template v-if="s.department"> · {{ s.department }}</template>
                    </div>
                  </div>
                </div>
              </td>
              <td><code class="cp-code">{{ s.staff_number }}</code></td>
              <td>{{ s.corporate_name }}</td>
              <td>
                <span :class="{ 'cp-warn-text': coverExpiring(s) }">
                  {{ s.valid_to ? formatDate(s.valid_to) : 'No end date' }}
                </span>
              </td>
              <td>
                <v-chip size="x-small" variant="tonal" :color="s.status === 'active' ? 'success' : 'grey'">
                  {{ s.status_label }}
                </v-chip>
              </td>
              <td>
                <v-chip size="x-small" variant="tonal"
                        :color="verificationColor(s.verification_status)">
                  {{ s.verification_label }}
                </v-chip>
                <div v-if="!s.is_eligible && s.ineligibility_reason" class="cp-reason">
                  {{ s.ineligibility_reason }}
                </div>
              </td>
              <td class="text-right">
                <v-btn v-if="s.verification_status !== 'verified'" icon="mdi-check"
                       variant="text" size="small" color="success" title="Verify staff"
                       @click="verifyStaff(s)" />
                <v-btn v-else icon="mdi-check-decagram" variant="text" size="small"
                       color="success" disabled />
                <v-btn icon="mdi-file-upload-outline" variant="text" size="small"
                       title="Upload job card" @click="openDocument(null, s)" />
              </td>
            </tr>
            <tr v-if="!filteredStaff.length">
              <td colspan="7">
                <div class="cp-empty">
                  <v-icon size="26">mdi-account-off-outline</v-icon>
                  <p>No staff on this roster yet. Add staff or upload the company list.</p>
                </div>
              </td>
            </tr>
          </tbody>
        </v-table>
      </v-window-item>

      <!-- ─── Documents ─── -->
      <v-window-item value="documents">
        <div class="cp-docs">
          <section class="cp-panel">
            <header class="cp-panel-head">
              <div>
                <h2 class="cp-panel-title">Verification documents</h2>
                <p class="cp-panel-hint">Job cards, contracts and authorisation letters</p>
              </div>
              <v-btn variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-plus"
                     @click="openDocument()">Upload</v-btn>
            </header>

            <ul v-if="documents.length" class="cp-doclist">
              <li v-for="d in documents" :key="d.id" class="cp-doc">
                <span class="cp-doc-icon" :class="`cp-doc-icon--${d.status}`">
                  <v-icon size="17">{{ docIcon(d.doc_type) }}</v-icon>
                </span>
                <div class="cp-doc-body">
                  <div class="cp-doc-title">{{ d.title }}</div>
                  <div class="cp-doc-meta">
                    {{ d.corporate_name }}
                    <template v-if="d.staff_name"> · {{ d.staff_name }}</template>
                    · {{ d.doc_type_label }}
                    <template v-if="d.reference"> · {{ d.reference }}</template>
                  </div>
                </div>
                <v-chip size="x-small" variant="tonal" :color="docStatusColor(d.status)">
                  {{ d.status_label }}
                </v-chip>
                <a v-if="d.file_url" :href="d.file_url" target="_blank" rel="noopener"
                   class="cp-doc-link">Open</a>
                <div class="cp-doc-actions">
                  <v-btn v-if="d.status !== 'verified'" icon="mdi-check" variant="text"
                         size="small" color="success" title="Verify" @click="setDocStatus(d, 'verify')" />
                  <v-btn v-if="d.status !== 'rejected'" icon="mdi-close" variant="text"
                         size="small" color="error" title="Reject" @click="setDocStatus(d, 'reject')" />
                </div>
              </li>
            </ul>
            <div v-else class="cp-empty">
              <v-icon size="26">mdi-file-document-outline</v-icon>
              <p>No documents uploaded yet.</p>
            </div>
          </section>

          <aside class="cp-panel cp-panel--side">
            <header class="cp-panel-head">
              <div>
                <h2 class="cp-panel-title">Cover expiring soon</h2>
                <p class="cp-panel-hint">Within the next 30 days</p>
              </div>
            </header>
            <ul v-if="expiringCover.length" class="cp-expiring">
              <li v-for="s in expiringCover" :key="s.id">
                <span class="cp-company-avatar cp-company-avatar--sm">{{ initials(s.full_name) }}</span>
                <div class="min-w-0 flex-grow-1">
                  <div class="cp-company-name">{{ s.full_name }}</div>
                  <div class="cp-company-meta">{{ s.corporate_name }} · {{ s.staff_number }}</div>
                </div>
                <span class="cp-warn-text">{{ formatDate(s.valid_to) }}</span>
              </li>
            </ul>
            <div v-else class="cp-empty cp-empty--sm">
              <v-icon size="22">mdi-check-circle-outline</v-icon>
              <p>No cover expiring in the next 30 days.</p>
            </div>
          </aside>
        </div>
      </v-window-item>
    </v-window>

    <!-- ═══════════════ Corporate dialog ═══════════════ -->
    <v-dialog v-model="corporateDialog" max-width="680" persistent scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-domain" title="Add corporate client"
                           subtitle="Contract terms used when billing staff visits"
                           @close="corporateDialog = false" />
        <v-card-text class="pa-5">
          <v-row dense>
            <v-col cols="12" sm="8">
              <v-text-field v-model="corporateForm.name" label="Company name *" variant="outlined"
                            density="comfortable" rounded="lg" :error-messages="formErrors.name" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model="corporateForm.code" label="Code" variant="outlined"
                            density="comfortable" rounded="lg" placeholder="ACM-001" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="corporateForm.registration_number" label="Registration no."
                            variant="outlined" density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="corporateForm.industry" label="Industry" variant="outlined"
                            density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="corporateForm.contact_person" label="Contact person"
                            variant="outlined" density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="corporateForm.contact_phone" label="Contact phone"
                            variant="outlined" density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-text-field v-model="corporateForm.contact_email" label="Contact email"
                            variant="outlined" density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="corporateForm.address" label="Address" rows="2" auto-grow
                          variant="outlined" density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model.number="corporateForm.discount_rate" type="number" min="0"
                            max="100" label="Discount %" variant="outlined" density="comfortable"
                            rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model.number="corporateForm.payment_terms_days" type="number"
                            min="0" label="Payment terms (days)" variant="outlined"
                            density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="4">
              <v-text-field v-model.number="corporateForm.annual_limit_per_staff" type="number"
                            min="0" label="Yearly cover / staff" variant="outlined"
                            density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="corporateForm.contract_start" type="date"
                            label="Contract start" variant="outlined" density="comfortable"
                            rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="corporateForm.contract_end" type="date"
                            label="Contract end" variant="outlined" density="comfortable"
                            rounded="lg" />
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <div class="d-flex justify-end ga-2 pa-4">
          <v-btn variant="text" class="text-none" @click="corporateDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="saving"
                 prepend-icon="mdi-content-save" @click="saveCorporate">Save company</v-btn>
        </div>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ Staff dialog ═══════════════ -->
    <v-dialog v-model="staffDialog" max-width="680" persistent scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-account-hard-hat" title="Add staff to the roster"
                           subtitle="Only active, verified staff with valid cover are billable"
                           @close="staffDialog = false" />
        <v-card-text class="pa-5">
          <v-row dense>
            <v-col cols="12" sm="7">
              <v-select v-model="staffForm.corporate" :items="corporateOptions" item-title="name"
                        item-value="id" label="Company *" variant="outlined"
                        density="comfortable" rounded="lg" :error-messages="formErrors.corporate" />
            </v-col>
            <v-col cols="12" sm="5">
              <v-text-field v-model="staffForm.staff_number" label="Staff / job card no. *"
                            variant="outlined" density="comfortable" rounded="lg"
                            :error-messages="formErrors.staff_number" />
            </v-col>
            <v-col cols="12" sm="7">
              <v-text-field v-model="staffForm.full_name" label="Full name *" variant="outlined"
                            density="comfortable" rounded="lg" :error-messages="formErrors.full_name" />
            </v-col>
            <v-col cols="12" sm="5">
              <v-select v-model="staffForm.relationship" :items="relationships" item-title="title"
                        item-value="value" label="Relationship" variant="outlined"
                        density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="staffForm.job_title" label="Job title" variant="outlined"
                            density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="staffForm.department" label="Department" variant="outlined"
                            density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="staffForm.phone" label="Phone" variant="outlined"
                            density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="staffForm.email" label="Email" variant="outlined"
                            density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="staffForm.national_id" label="National ID" variant="outlined"
                            density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="staffForm.date_of_birth" type="date" label="Date of birth"
                            variant="outlined" density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="staffForm.valid_from" type="date" label="Cover starts"
                            variant="outlined" density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="staffForm.valid_to" type="date" label="Cover ends"
                            variant="outlined" density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model.number="staffForm.annual_limit" type="number" min="0"
                            label="Yearly cover" variant="outlined" density="comfortable"
                            rounded="lg" hint="0 = use the company default" persistent-hint />
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider />
        <div class="d-flex justify-end ga-2 pa-4">
          <v-btn variant="text" class="text-none" @click="staffDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="saving"
                 prepend-icon="mdi-account-plus" @click="saveStaff">Add to roster</v-btn>
        </div>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ Bulk upload dialog ═══════════════ -->
    <v-dialog v-model="bulkDialog" max-width="620" persistent scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-file-upload-outline" title="Upload staff list"
                           subtitle="CSV with staff_number, full_name, job_title, department"
                           @close="bulkDialog = false" />
        <v-card-text class="pa-5">
          <v-select v-model="bulkCorporate" :items="corporateOptions" item-title="name"
                    item-value="id" label="Company *" variant="outlined" density="comfortable"
                    rounded="lg" class="mb-3" />
          <v-file-input v-model="bulkFile" accept=".csv,text/csv" label="Staff list (CSV)"
                        variant="outlined" density="comfortable" rounded="lg"
                        prepend-icon="mdi-paperclip" show-size @update:model-value="parseCsv" />
          <v-alert v-if="bulkRows.length" type="info" variant="tonal" density="compact"
                   rounded="lg">
            {{ bulkRows.length }} row{{ bulkRows.length === 1 ? '' : 's' }} ready — existing
            staff numbers will be updated.
          </v-alert>
          <v-alert v-if="bulkError" type="error" variant="tonal" density="compact" rounded="lg">
            {{ bulkError }}
          </v-alert>
        </v-card-text>
        <v-divider />
        <div class="d-flex justify-end ga-2 pa-4">
          <v-btn variant="text" class="text-none" @click="bulkDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="saving"
                 :disabled="!bulkCorporate || !bulkRows.length"
                 prepend-icon="mdi-cloud-upload" @click="submitBulk">Upload roster</v-btn>
        </div>
      </v-card>
    </v-dialog>

    <!-- ═══════════════ Document dialog ═══════════════ -->
    <v-dialog v-model="documentDialog" max-width="620" persistent scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader icon="mdi-card-account-details-outline" title="Upload verification document"
                           subtitle="Job card, contract or authorisation letter"
                           @close="documentDialog = false" />
        <v-card-text class="pa-5">
          <v-row dense>
            <v-col cols="12" sm="7">
              <v-select v-model="docForm.corporate" :items="corporateOptions" item-title="name"
                        item-value="id" label="Company *" variant="outlined"
                        density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="5">
              <v-select v-model="docForm.doc_type" :items="docTypes" item-title="title"
                        item-value="value" label="Document type" variant="outlined"
                        density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="7">
              <v-select v-model="docForm.staff" :items="docStaffOptions" item-title="label"
                        item-value="id" label="Staff member (optional)" variant="outlined"
                        density="comfortable" rounded="lg" clearable />
            </v-col>
            <v-col cols="12" sm="5">
              <v-text-field v-model="docForm.reference" label="Reference / job card no."
                            variant="outlined" density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-text-field v-model="docForm.title" label="Title"
                            variant="outlined" density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="docForm.issued_at" type="date" label="Issued on"
                            variant="outlined" density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="docForm.expires_at" type="date" label="Expires on"
                            variant="outlined" density="comfortable" rounded="lg" />
            </v-col>
            <v-col cols="12">
              <v-file-input v-model="docForm.file" label="File (image or PDF)"
                            variant="outlined" density="comfortable" rounded="lg"
                            prepend-icon="mdi-paperclip" accept="image/*,application/pdf"
                            show-size />
            </v-col>
          </v-row>
          <v-alert v-if="docError" type="error" variant="tonal" density="compact"
                   rounded="lg" class="mt-2">{{ docError }}</v-alert>
        </v-card-text>
        <v-divider />
        <div class="d-flex justify-end ga-2 pa-4">
          <v-btn variant="text" class="text-none" @click="documentDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" class="text-none" :loading="saving"
                 :disabled="!docForm.corporate" prepend-icon="mdi-cloud-upload"
                 @click="submitDocument">Upload</v-btn>
        </div>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="4000" rounded="lg">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
/**
 * Corporate dashboard — employer accounts, treatment-eligible staff roster and
 * the verification documents (job cards / authorisation letters) that gate
 * corporate billing at reception.
 */
definePageMeta({ title: 'Corporate' })

const { $api } = useNuxtApp()

const loading = ref(false)
const saving = ref(false)
const seeding = ref(false)
const tab = ref('overview')

const dashboard = ref(null)
const clients = ref([])
const staff = ref([])
const documents = ref([])

const snack = reactive({ show: false, color: 'success', text: '' })
function notify(text, color = 'success') {
  Object.assign(snack, { show: true, color, text })
}

const kpis = computed(() => dashboard.value?.kpis || {})
const expiringCover = computed(() => dashboard.value?.expiring_cover || [])
const updatedLabel = computed(() => {
  const stamp = dashboard.value?.generated_at
  if (!stamp) return ''
  const d = new Date(stamp)
  return `Updated ${d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })}`
})

const tiles = computed(() => [
  {
    key: 'staff', label: 'Eligible staff', tone: '#2f6dff',
    icon: 'mdi-account-check-outline', value: fmt(kpis.value.staff_eligible),
    sub: `${fmt(kpis.value.staff_total)} on rosters`,
  },
  {
    key: 'pending', label: 'Awaiting verification', tone: '#f59e0b',
    icon: 'mdi-account-clock-outline', value: fmt(kpis.value.staff_pending),
    sub: 'staff records to confirm',
  },
  {
    key: 'docs', label: 'Documents to verify', tone: '#a855f7',
    icon: 'mdi-file-alert-outline', value: fmt(kpis.value.documents_pending),
    sub: `${fmt(kpis.value.documents_verified)} verified`,
  },
  {
    key: 'visits', label: 'Corporate visits', tone: '#0ea5e9',
    icon: 'mdi-hospital-building', value: fmt(kpis.value.visits_this_month),
    sub: 'this month',
  },
  {
    key: 'billed', label: 'Billed this month', tone: '#10b981',
    icon: 'mdi-cash-multiple', value: money(kpis.value.billed_this_month),
    sub: 'consultation fees',
  },
  {
    key: 'expiring', label: 'Cover expiring', tone: '#ef4444',
    icon: 'mdi-clock-alert-outline', value: fmt(kpis.value.expiring_staff),
    sub: 'within 30 days',
  },
])

// ── Filters ─────────────────────────────────────────────────────────
const clientSearch = ref('')
const staffCorporate = ref(null)
const staffVerification = ref(null)
const staffSearch = ref('')

const verificationOptions = [
  { title: 'Pending', value: 'pending' },
  { title: 'Verified', value: 'verified' },
  { title: 'Rejected', value: 'rejected' },
]

const corporateOptions = computed(() =>
  clients.value.map(c => ({ id: c.id, name: c.name, code: c.code })))

const filteredClients = computed(() => {
  const q = clientSearch.value.trim().toLowerCase()
  if (!q) return clients.value
  return clients.value.filter(c =>
    `${c.name} ${c.code} ${c.contact_person} ${c.industry}`.toLowerCase().includes(q))
})

const filteredStaff = computed(() => {
  const q = staffSearch.value.trim().toLowerCase()
  let rows = staff.value
  if (staffCorporate.value) rows = rows.filter(s => s.corporate === staffCorporate.value)
  if (staffVerification.value) {
    rows = rows.filter(s => s.verification_status === staffVerification.value)
  }
  if (q) {
    rows = rows.filter(s =>
      `${s.full_name} ${s.staff_number} ${s.national_id} ${s.phone} ${s.job_title}`
        .toLowerCase().includes(q))
  }
  return rows
})

const docStaffOptions = computed(() => {
  const corporate = docForm.corporate
  return staff.value
    .filter(s => !corporate || s.corporate === corporate)
    .map(s => ({ id: s.id, label: `${s.full_name} · ${s.staff_number}` }))
})

// ── Data loading ────────────────────────────────────────────────────
function rowsOf(payload) {
  return Array.isArray(payload) ? payload : (payload?.results || [])
}

async function loadDashboard() {
  try {
    const { data } = await $api.get('/corporate/dashboard/')
    dashboard.value = data
  } catch {
    dashboard.value = null
  }
}

async function loadClients() {
  try {
    const { data } = await $api.get('/corporate/clients/', { params: { page_size: 200 } })
    clients.value = rowsOf(data)
  } catch {
    clients.value = []
  }
}

async function loadStaff() {
  try {
    const { data } = await $api.get('/corporate/staff/', { params: { page_size: 500 } })
    staff.value = rowsOf(data)
  } catch {
    staff.value = []
  }
}

async function loadDocuments() {
  try {
    const { data } = await $api.get('/corporate/documents/', { params: { page_size: 200 } })
    documents.value = rowsOf(data)
  } catch {
    documents.value = []
  }
}

async function loadAll() {
  loading.value = true
  await Promise.all([loadDashboard(), loadClients(), loadStaff(), loadDocuments()])
  loading.value = false
}

async function seedDemo() {
  seeding.value = true
  try {
    await $api.post('/corporate/dashboard/seed-demo/')
    notify('Demo corporate accounts loaded.')
    await loadAll()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Could not load demo data.', 'error')
  } finally {
    seeding.value = false
  }
}

// ── Corporate dialog ────────────────────────────────────────────────
const corporateDialog = ref(false)
const formErrors = reactive({})
const corporateForm = reactive(blankCorporate())

function blankCorporate() {
  return {
    name: '', code: '', registration_number: '', industry: '',
    contact_person: '', contact_phone: '', contact_email: '', address: '',
    discount_rate: 0, payment_terms_days: 30, annual_limit_per_staff: 0,
    contract_start: '', contract_end: '',
  }
}

function openCorporate() {
  Object.assign(corporateForm, blankCorporate())
  Object.keys(formErrors).forEach(k => delete formErrors[k])
  corporateDialog.value = true
}

async function saveCorporate() {
  Object.keys(formErrors).forEach(k => delete formErrors[k])
  if (!corporateForm.name.trim()) {
    formErrors.name = 'A company name is required'
    return
  }
  saving.value = true
  try {
    await $api.post('/corporate/clients/', {
      ...corporateForm,
      contract_start: corporateForm.contract_start || null,
      contract_end: corporateForm.contract_end || null,
      status: 'pending',
    })
    notify('Corporate client added — pending verification.')
    corporateDialog.value = false
    await loadAll()
  } catch (e) {
    const d = e?.response?.data
    if (d && typeof d === 'object') {
      Object.entries(d).forEach(([k, v]) => {
        formErrors[k] = Array.isArray(v) ? v[0] : String(v)
      })
    }
    notify('Could not save the company.', 'error')
  } finally {
    saving.value = false
  }
}

async function setCorporateStatus(corporate, approved) {
  try {
    await $api.post(`/corporate/clients/${corporate.id}/verify-status/`, { approved })
    notify(approved ? `${corporate.name} verified.` : `${corporate.name} suspended.`)
    await loadAll()
  } catch {
    notify('Could not update the company status.', 'error')
  }
}

function viewRoster(corporate) {
  staffCorporate.value = corporate.id
  tab.value = 'staff'
}

// ── Staff dialog ────────────────────────────────────────────────────
const staffDialog = ref(false)
const staffForm = reactive(blankStaff())

function blankStaff() {
  return {
    corporate: null, staff_number: '', full_name: '',
    relationship: 'employee', job_title: '', department: '',
    phone: '', email: '', national_id: '', date_of_birth: '',
    valid_from: '', valid_to: '', annual_limit: 0,
  }
}

const relationships = [
  { title: 'Employee', value: 'employee' },
  { title: 'Spouse', value: 'spouse' },
  { title: 'Child', value: 'child' },
  { title: 'Dependant', value: 'dependant' },
]

function openStaff(corporate = null) {
  Object.assign(staffForm, blankStaff(), {
    corporate: corporate?.id || staffCorporate.value || null,
  })
  Object.keys(formErrors).forEach(k => delete formErrors[k])
  staffDialog.value = true
}

async function saveStaff() {
  Object.keys(formErrors).forEach(k => delete formErrors[k])
  if (!staffForm.corporate) formErrors.corporate = 'Choose the company'
  if (!staffForm.staff_number.trim()) formErrors.staff_number = 'Job card number is required'
  if (!staffForm.full_name.trim()) formErrors.full_name = 'Full name is required'
  if (Object.keys(formErrors).length) return

  saving.value = true
  try {
    await $api.post('/corporate/staff/', {
      ...staffForm,
      date_of_birth: staffForm.date_of_birth || null,
      valid_from: staffForm.valid_from || null,
      valid_to: staffForm.valid_to || null,
      verification_status: 'pending',
    })
    notify('Staff member added to the roster.')
    staffDialog.value = false
    await loadAll()
  } catch (e) {
    const d = e?.response?.data
    if (d && typeof d === 'object') {
      Object.entries(d).forEach(([k, v]) => {
        formErrors[k] = Array.isArray(v) ? v[0] : String(v)
      })
    }
    notify('Could not add the staff member.', 'error')
  } finally {
    saving.value = false
  }
}

async function verifyStaff(row) {
  try {
    await $api.post(`/corporate/staff/${row.id}/verify/`)
    notify(`${row.full_name} verified — eligible for treatment.`)
    await loadAll()
  } catch {
    notify('Could not verify this staff record.', 'error')
  }
}

// ── Bulk upload ─────────────────────────────────────────────────────
const bulkDialog = ref(false)
const bulkCorporate = ref(null)
const bulkFile = ref(null)
const bulkRows = ref([])
const bulkError = ref('')

function openBulk() {
  bulkCorporate.value = staffCorporate.value || null
  bulkFile.value = null
  bulkRows.value = []
  bulkError.value = ''
  bulkDialog.value = true
}

function parseCsv(file) {
  bulkRows.value = []
  bulkError.value = ''
  const picked = Array.isArray(file) ? file[0] : file
  if (!picked) return
  const reader = new FileReader()
  reader.onload = () => {
    const text = String(reader.result || '')
    const lines = text.split(/\r?\n/).filter(l => l.trim())
    if (lines.length < 2) {
      bulkError.value = 'The CSV needs a header row plus at least one staff record.'
      return
    }
    const headers = lines[0].split(',').map(h => h.trim().toLowerCase())
    const rows = []
    for (const line of lines.slice(1)) {
      const cells = line.split(',').map(c => c.trim())
      const row = {}
      headers.forEach((h, i) => { row[h] = cells[i] || '' })
      const staffNumber = row.staff_number || row.staff_no || row.employee_number || ''
      const fullName = row.full_name || row.name || ''
      if (!staffNumber || !fullName) continue
      rows.push({
        staff_number: staffNumber,
        full_name: fullName,
        job_title: row.job_title || row.title || '',
        department: row.department || '',
        phone: row.phone || '',
        email: row.email || '',
        national_id: row.national_id || row.id_number || '',
      })
    }
    if (!rows.length) {
      bulkError.value = 'No rows had both staff_number and full_name.'
      return
    }
    bulkRows.value = rows
  }
  reader.readAsText(picked)
}

async function submitBulk() {
  if (!bulkCorporate.value || !bulkRows.value.length) return
  saving.value = true
  try {
    const { data } = await $api.post('/corporate/staff/bulk-upload/', {
      corporate: bulkCorporate.value,
      rows: bulkRows.value,
    })
    notify(`${data.created} staff added, ${data.updated} updated.`)
    bulkDialog.value = false
    await loadAll()
  } catch (e) {
    bulkError.value = e?.response?.data?.detail || 'Could not upload the roster.'
  } finally {
    saving.value = false
  }
}

// ── Documents ───────────────────────────────────────────────────────
const documentDialog = ref(false)
const docError = ref('')
const docForm = reactive(blankDocument())

const docTypes = [
  { title: 'Job card', value: 'job_card' },
  { title: 'Service contract', value: 'contract' },
  { title: 'Authorisation letter', value: 'authorisation_letter' },
  { title: 'Staff list', value: 'staff_list' },
  { title: 'Tax certificate', value: 'tax_certificate' },
  { title: 'Other', value: 'other' },
]

function blankDocument() {
  return {
    corporate: null, staff: null, doc_type: 'job_card', title: '',
    reference: '', issued_at: '', expires_at: '', file: null,
  }
}

function openDocument(corporate = null, staffRow = null) {
  Object.assign(docForm, blankDocument(), {
    corporate: corporate?.id || staffRow?.corporate || staffCorporate.value || null,
    staff: staffRow?.id || null,
    doc_type: staffRow ? 'job_card' : 'contract',
    title: staffRow ? `Job card — ${staffRow.full_name}` : '',
  })
  docError.value = ''
  documentDialog.value = true
}

async function submitDocument() {
  docError.value = ''
  saving.value = true
  try {
    const form = new FormData()
    form.append('corporate', docForm.corporate)
    if (docForm.staff) form.append('staff', docForm.staff)
    form.append('doc_type', docForm.doc_type)
    if (docForm.title) form.append('title', docForm.title)
    if (docForm.reference) form.append('reference', docForm.reference)
    if (docForm.issued_at) form.append('issued_at', docForm.issued_at)
    if (docForm.expires_at) form.append('expires_at', docForm.expires_at)
    const picked = Array.isArray(docForm.file) ? docForm.file[0] : docForm.file
    if (picked) form.append('file', picked)

    await $api.post('/corporate/documents/', form)
    notify('Document uploaded — pending verification.')
    documentDialog.value = false
    await loadAll()
  } catch (e) {
    docError.value = e?.response?.data?.detail || 'Could not upload the document.'
  } finally {
    saving.value = false
  }
}

async function setDocStatus(doc, action) {
  try {
    await $api.post(`/corporate/documents/${doc.id}/${action}/`, action === 'reject'
      ? { reason: 'Rejected by clinic' }
      : {})
    notify(action === 'verify' ? 'Document verified.' : 'Document rejected.')
    await loadAll()
  } catch {
    notify('Could not update the document.', 'error')
  }
}

// ── Helpers ─────────────────────────────────────────────────────────
function fmt(n) {
  return (Number(n) || 0).toLocaleString('en-US')
}

function money(n) {
  const v = Number(n) || 0
  if (!v) return 'KES 0'
  if (Math.abs(v) >= 1_000_000) return `KES ${(v / 1_000_000).toFixed(1)}M`
  if (Math.abs(v) >= 1_000) return `KES ${(v / 1_000).toFixed(0)}K`
  return `KES ${v.toFixed(0)}`
}

function formatDate(value) {
  if (!value) return '—'
  const d = new Date(`${value}T00:00:00`)
  if (Number.isNaN(d.getTime())) return value
  return d.toLocaleDateString('en-US', { day: 'numeric', month: 'short', year: 'numeric' })
}

function initials(name) {
  const parts = String(name || '?').trim().split(/\s+/).filter(Boolean)
  return ((parts[0]?.[0] || '') + (parts[1]?.[0] || '')).toUpperCase() || '?'
}

function statusColor(status) {
  return {
    active: 'success', pending: 'warning', suspended: 'error', expired: 'grey',
  }[status] || 'grey'
}

function verificationColor(status) {
  return { verified: 'success', pending: 'warning', rejected: 'error' }[status] || 'grey'
}

function docStatusColor(status) {
  return { verified: 'success', pending: 'warning', rejected: 'error' }[status] || 'grey'
}

function docIcon(type) {
  return {
    job_card: 'mdi-card-account-details-outline',
    contract: 'mdi-file-sign',
    authorisation_letter: 'mdi-email-seal-outline',
    staff_list: 'mdi-format-list-bulleted',
    tax_certificate: 'mdi-certificate-outline',
  }[type] || 'mdi-file-document-outline'
}

function contractExpiring(c) {
  if (!c.contract_end) return false
  const end = new Date(`${c.contract_end}T00:00:00`).getTime()
  return end - Date.now() < 30 * 24 * 3600 * 1000
}

function coverExpiring(s) {
  if (!s.valid_to) return false
  const end = new Date(`${s.valid_to}T00:00:00`).getTime()
  return end - Date.now() < 30 * 24 * 3600 * 1000
}

onMounted(loadAll)
</script>

<style scoped>
.min-w-0 { min-width: 0; }
.cp-page { width: 100%; }

/* ── Header ── */
.cp-head {
  border-radius: 18px;
  padding: 18px 20px 14px;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
  box-shadow: 0 14px 34px -26px rgba(15, 23, 42, 0.4);
}
.cp-head-top { display: flex; align-items: center; gap: 14px; flex-wrap: wrap; }
.cp-head-icon {
  width: 52px; height: 52px; border-radius: 15px; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
  color: #fff;
  background: linear-gradient(135deg, var(--brand-primary, #2f6dff), var(--brand-secondary, #143ce1));
  box-shadow: 0 10px 24px -14px rgba(47, 109, 255, 0.8);
}
.cp-head-id { min-width: 0; flex: 1 1 320px; }
.cp-head-eyebrow {
  display: inline-flex; align-items: center; gap: 6px;
  font-size: 10px; font-weight: 800; letter-spacing: 1.3px; text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.5);
}
.cp-dot {
  width: 6px; height: 6px; border-radius: 50%; background: #10b981;
  box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.18);
}
.cp-head-title { font-size: 1.45rem; font-weight: 800; letter-spacing: -0.4px; margin: 1px 0; }
.cp-head-sub {
  font-size: 12.5px; line-height: 1.4; max-width: 78ch;
  color: rgba(var(--v-theme-on-surface), 0.6);
}
.cp-head-actions { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
.cp-head-foot {
  display: flex; align-items: center; gap: 8px; flex-wrap: wrap;
  margin-top: 14px; padding-top: 12px;
  border-top: 1px solid rgba(var(--v-theme-on-surface), 0.08);
}
.cp-chip {
  display: inline-flex; align-items: center; gap: 6px;
  padding: 4px 10px; border-radius: 999px;
  font-size: 11.5px; font-weight: 650;
  color: rgba(var(--v-theme-on-surface), 0.72);
  background: rgba(var(--v-theme-on-surface), 0.05);
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
  white-space: nowrap;
}
.cp-chip.is-good { color: #047857; background: rgba(16, 185, 129, 0.1); border-color: rgba(16, 185, 129, 0.28); }
.cp-chip.is-warn { color: #b45309; background: rgba(245, 158, 11, 0.12); border-color: rgba(245, 158, 11, 0.3); }
.cp-head-stamp { margin-left: auto; font-size: 11px; color: rgba(var(--v-theme-on-surface), 0.45); }

/* ── KPIs ── */
.cp-kpis {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(168px, 1fr));
  gap: 10px; margin-top: 14px;
}
.cp-kpi {
  --tone: #2f6dff;
  position: relative; overflow: hidden;
  padding: 13px 14px 12px; border-radius: 13px;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
  transition: transform 0.16s ease, box-shadow 0.16s ease;
}
.cp-kpi::before {
  content: ''; position: absolute; left: 0; top: 0; bottom: 0; width: 3px;
  background: var(--tone); opacity: 0.85;
}
.cp-kpi:hover { transform: translateY(-1px); box-shadow: 0 10px 24px rgba(15, 23, 42, 0.08); }
.cp-kpi-top { display: flex; align-items: center; gap: 7px; }
.cp-kpi-icon { color: var(--tone); display: flex; }
.cp-kpi-label {
  font-size: 10px; font-weight: 800; letter-spacing: 0.7px; text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.5);
}
.cp-kpi-value { font-size: 1.4rem; font-weight: 800; letter-spacing: -0.4px; margin-top: 6px; }
.cp-kpi-sub { font-size: 11px; color: rgba(var(--v-theme-on-surface), 0.5); }

/* ── Actions strip ── */
.cp-actions {
  display: flex; align-items: center; gap: 8px; flex-wrap: wrap;
  margin-top: 14px; padding: 9px 12px; border-radius: 12px;
  background: rgba(var(--v-theme-on-surface), 0.025);
  border: 1px dashed rgba(var(--v-theme-on-surface), 0.16);
}
.cp-action {
  display: inline-flex; align-items: center; gap: 7px;
  padding: 7px 11px; border-radius: 9px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.1);
  background: rgb(var(--v-theme-surface));
  font-family: inherit; font-size: 12px; font-weight: 650;
  color: rgb(var(--v-theme-on-surface));
  cursor: pointer;
  transition: border-color 0.16s ease, transform 0.16s ease;
}
.cp-action:hover {
  transform: translateY(-1px);
  border-color: color-mix(in srgb, var(--brand-primary, #2f6dff) 40%, transparent);
}
.cp-action .v-icon { color: var(--brand-primary, #2f6dff); }
.cp-actions-note { margin-left: auto; font-size: 11px; color: rgba(var(--v-theme-on-surface), 0.45); }

.cp-tabs { margin-top: 10px; border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.08); }
.cp-window { padding-top: 14px; }

/* ── Tables ── */
.cp-table { background: transparent; }
.cp-table :deep(th) {
  font-size: 10px !important; font-weight: 800 !important;
  letter-spacing: 0.7px; text-transform: uppercase;
  color: rgba(var(--v-theme-on-surface), 0.45) !important;
}
.cp-company { display: flex; align-items: center; gap: 10px; }
.cp-company-avatar {
  width: 34px; height: 34px; border-radius: 10px; flex-shrink: 0;
  display: grid; place-items: center;
  font-size: 11.5px; font-weight: 800;
  color: var(--brand-primary, #2f6dff);
  background: color-mix(in srgb, var(--brand-primary, #2f6dff) 12%, transparent);
}
.cp-company-avatar--sm { width: 28px; height: 28px; border-radius: 8px; font-size: 10.5px; }
.cp-company-name { font-size: 12.5px; font-weight: 700; }
.cp-company-meta { font-size: 11px; color: rgba(var(--v-theme-on-surface), 0.55); }
.cp-eligible { font-weight: 800; color: #047857; }
.cp-code {
  font-size: 11px; padding: 2px 6px; border-radius: 5px;
  background: rgba(var(--v-theme-on-surface), 0.06);
}
.cp-warn-text { color: #b45309; font-weight: 700; }
.cp-reason {
  margin-top: 3px; font-size: 10.5px; line-height: 1.25;
  color: #b45309; max-width: 34ch;
}

/* ── Toolbar ── */
.cp-toolbar { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; margin-bottom: 12px; }
.cp-tool { max-width: 240px; }
.cp-tool--grow { flex: 1 1 260px; max-width: none; }

/* ── Docs ── */
.cp-docs { display: grid; grid-template-columns: minmax(0, 1.6fr) minmax(0, 1fr); gap: 14px; }
@media (max-width: 1023px) { .cp-docs { grid-template-columns: minmax(0, 1fr); } }
.cp-panel {
  border-radius: 14px; padding: 14px 16px;
  background: rgb(var(--v-theme-surface));
  border: 1px solid rgba(var(--v-theme-on-surface), 0.09);
}
.cp-panel-head {
  display: flex; align-items: flex-start; justify-content: space-between; gap: 10px;
  margin-bottom: 10px;
}
.cp-panel-title { font-size: 0.95rem; font-weight: 750; }
.cp-panel-hint { font-size: 11.5px; color: rgba(var(--v-theme-on-surface), 0.55); }
.cp-doclist { list-style: none; margin: 0; padding: 0; }
.cp-doc {
  display: flex; align-items: center; gap: 10px;
  padding: 9px 2px; border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.07);
}
.cp-doc:last-child { border-bottom: 0; }
.cp-doc-icon {
  width: 32px; height: 32px; border-radius: 9px; flex-shrink: 0;
  display: grid; place-items: center;
  color: #b45309; background: rgba(245, 158, 11, 0.14);
}
.cp-doc-icon--verified { color: #047857; background: rgba(16, 185, 129, 0.14); }
.cp-doc-icon--rejected { color: #b91c1c; background: rgba(239, 68, 68, 0.14); }
.cp-doc-body { min-width: 0; flex: 1; }
.cp-doc-title { font-size: 12.5px; font-weight: 700; }
.cp-doc-meta { font-size: 11px; color: rgba(var(--v-theme-on-surface), 0.55); }
.cp-doc-link {
  font-size: 11px; font-weight: 700; text-decoration: none;
  color: var(--brand-primary, #2f6dff);
}
.cp-doc-actions { display: flex; gap: 2px; }
.cp-expiring { list-style: none; margin: 0; padding: 0; }
.cp-expiring li { display: flex; align-items: center; gap: 9px; padding: 7px 0; }
.cp-expiring li + li { border-top: 1px solid rgba(var(--v-theme-on-surface), 0.07); }

.cp-empty {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: 6px; padding: 30px 12px; text-align: center;
  color: rgba(var(--v-theme-on-surface), 0.45);
}
.cp-empty--sm { padding: 18px 10px; }
.cp-empty p { margin: 0; font-size: 12px; }
</style>
