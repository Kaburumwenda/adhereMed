<template>
  <v-container fluid class="pa-4 pa-md-6">
    <!-- Header -->
    <div class="d-flex align-center flex-wrap ga-3 mb-5">
      <v-avatar color="indigo-lighten-5" size="48">
        <v-icon color="indigo-darken-2" size="28">mdi-shield-account</v-icon>
      </v-avatar>
      <div>
        <div class="text-h5 font-weight-bold">Lab insurance</div>
        <div class="text-body-2 text-medium-emphasis">
          Claims, providers &amp; insured receivables for the laboratory
        </div>
      </div>
      <v-spacer />
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-refresh"
             :loading="loading" @click="loadAll">Refresh</v-btn>
      <v-btn variant="outlined" rounded="lg" prepend-icon="mdi-tray-arrow-down"
             @click="exportClaims">Export</v-btn>
      <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus"
             @click="openClaim()">New claim</v-btn>
    </div>

    <!-- KPIs -->
    <v-row dense class="mb-1">
      <v-col v-for="k in kpiTiles" :key="k.label" cols="6" md="3">
        <v-card flat rounded="lg" class="kpi pa-3">
          <div class="d-flex align-center">
            <v-avatar :color="k.color + '-lighten-5'" size="40" class="mr-3">
              <v-icon :color="k.color + '-darken-2'" size="22">{{ k.icon }}</v-icon>
            </v-avatar>
            <div class="min-width-0">
              <div class="text-overline text-medium-emphasis">{{ k.label }}</div>
              <div class="text-h6 font-weight-bold">{{ k.value }}</div>
              <div class="text-caption text-medium-emphasis">{{ k.sub }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Section pills (replaces tabs) -->
    <v-card flat rounded="lg" class="section-pills pa-2 mt-3 mb-3">
      <v-chip-group v-model="tab" mandatory selected-class="text-primary">
        <v-chip v-for="s in sectionPills" :key="s.value" :value="s.value"
                size="small" filter variant="tonal" :color="s.color">
          <v-icon size="14" start>{{ s.icon }}</v-icon>{{ s.label }}
        </v-chip>
      </v-chip-group>
    </v-card>

    <!-- ============== OVERVIEW ============== -->
    <template v-if="tab === 'overview'">
      <v-row dense class="mb-3">
        <v-col cols="12" md="6">
          <v-card flat class="pa-4 h-100 section-card" rounded="lg">
            <div class="d-flex align-center mb-3">
              <v-icon color="indigo" class="mr-2">mdi-chart-pie</v-icon>
              <div class="text-subtitle-1 font-weight-medium">Claims by status</div>
            </div>
            <div v-if="!claims.length" class="text-medium-emphasis text-center py-6">
              No claims recorded yet.
            </div>
            <div v-else>
              <div v-for="row in claimsByStatus" :key="row.key" class="mb-3">
                <div class="d-flex align-center mb-1">
                  <v-icon size="14" :color="claimStatusColor(row.key)" class="mr-2">mdi-circle</v-icon>
                  <span class="text-body-2 font-weight-medium text-capitalize">
                    {{ claimStatusLabel(row.key) }}
                  </span>
                  <v-spacer />
                  <span class="text-body-2">
                    {{ row.count }} · <strong>{{ fmtMoney(row.amount) }}</strong>
                  </span>
                </div>
                <v-progress-linear :model-value="row.pct" :color="claimStatusColor(row.key)" height="8" rounded />
              </div>
            </div>
          </v-card>
        </v-col>
        <v-col cols="12" md="6">
          <v-card flat class="pa-4 h-100 section-card" rounded="lg">
            <div class="d-flex align-center mb-3">
              <v-icon color="purple" class="mr-2">mdi-domain</v-icon>
              <div class="text-subtitle-1 font-weight-medium">Top providers by exposure</div>
              <v-spacer />
              <v-btn size="small" variant="text" color="primary" @click="tab = 'providers'">View all</v-btn>
            </div>
            <div v-if="!topProviders.length" class="text-medium-emphasis text-center py-6">
              No providers yet
            </div>
            <v-list v-else density="compact" class="pa-0">
              <v-list-item v-for="p in topProviders" :key="p.name" class="px-0">
                <template #prepend>
                  <v-avatar size="32" color="purple" variant="tonal">
                    <v-icon size="16">mdi-domain</v-icon>
                  </v-avatar>
                </template>
                <v-list-item-title class="text-body-2 font-weight-medium">{{ p.name }}</v-list-item-title>
                <v-list-item-subtitle class="text-caption">
                  {{ p.count }} claim(s) · approved {{ fmtMoney(p.approved) }}
                </v-list-item-subtitle>
                <template #append>
                  <div class="text-right">
                    <div class="font-weight-bold">{{ fmtMoney(p.outstanding) }}</div>
                    <div class="text-caption text-error">outstanding</div>
                  </div>
                </template>
              </v-list-item>
            </v-list>
          </v-card>
        </v-col>
      </v-row>

      <v-row dense>
        <v-col cols="12" md="7">
          <v-card flat class="pa-4 section-card" rounded="lg">
            <div class="d-flex align-center mb-3">
              <v-icon color="error" class="mr-2">mdi-alert-circle-outline</v-icon>
              <div class="text-subtitle-1 font-weight-medium">Recent rejected / pending claims</div>
              <v-spacer />
              <v-btn size="small" variant="text" color="primary" @click="tab = 'claims'">View all</v-btn>
            </div>
            <div v-if="!attentionClaims.length" class="text-medium-emphasis text-center py-4">
              All clear — no pending or rejected claims.
            </div>
            <v-list v-else density="compact" class="pa-0">
              <v-list-item v-for="c in attentionClaims" :key="c.id" class="px-0" @click="openClaim(c)">
                <template #prepend>
                  <v-avatar size="32" :color="claimStatusColor(c.status)" variant="tonal">
                    <v-icon size="16">{{ claimStatusIcon(c.status) }}</v-icon>
                  </v-avatar>
                </template>
                <v-list-item-title class="text-body-2 font-weight-medium">
                  {{ c.reference }} · {{ c.member_name }}
                </v-list-item-title>
                <v-list-item-subtitle class="text-caption">
                  {{ providerName(c) }} · {{ fmtDate(c.created_at) }}
                  <span v-if="c.rejection_reason" class="text-error"> · {{ c.rejection_reason }}</span>
                </v-list-item-subtitle>
                <template #append>
                  <span class="font-weight-bold">{{ fmtMoney(c.claim_amount) }}</span>
                </template>
              </v-list-item>
            </v-list>
          </v-card>
        </v-col>
        <v-col cols="12" md="5">
          <v-card flat class="pa-4 h-100 section-card" rounded="lg">
            <div class="d-flex align-center mb-3">
              <v-icon color="teal" class="mr-2">mdi-receipt-text-outline</v-icon>
              <div class="text-subtitle-1 font-weight-medium">Insured lab invoices (unbilled)</div>
              <v-spacer />
              <v-btn size="small" variant="text" color="primary" @click="tab = 'invoices'">View all</v-btn>
            </div>
            <div v-if="!unclaimedInsuredInvoices.length" class="text-medium-emphasis text-center py-4">
              All insured invoices have claims.
            </div>
            <v-list v-else density="compact" class="pa-0">
              <v-list-item v-for="inv in unclaimedInsuredInvoices.slice(0, 6)" :key="inv.id" class="px-0">
                <template #prepend>
                  <v-avatar size="32" color="teal" variant="tonal">
                    <v-icon size="16">mdi-receipt-text</v-icon>
                  </v-avatar>
                </template>
                <v-list-item-title class="text-body-2 font-weight-medium">
                  {{ inv.invoice_number }} · {{ patientLabel(inv) }}
                </v-list-item-title>
                <v-list-item-subtitle class="text-caption">
                  {{ inv.insurance_scheme || '—' }} · {{ fmtDate(inv.created_at) }}
                </v-list-item-subtitle>
                <template #append>
                  <v-btn size="x-small" color="primary" variant="tonal"
                         prepend-icon="mdi-plus" @click="openClaimFromInvoice(inv)">
                    Claim
                  </v-btn>
                </template>
              </v-list-item>
            </v-list>
          </v-card>
        </v-col>
      </v-row>
    </template>

    <!-- ============== CLAIMS ============== -->
    <template v-if="tab === 'claims'">
      <v-card flat class="pa-3 mb-3 section-card" rounded="lg">
        <div class="d-flex flex-wrap align-center" style="gap:8px">
          <v-text-field
            v-model="claimSearch"
            density="compact" hide-details variant="outlined" rounded="lg"
            prepend-inner-icon="mdi-magnify"
            placeholder="Search reference / member / invoice" persistent-placeholder
            style="max-width:320px"
          />
          <v-select
            v-model="claimStatusFilter"
            :items="claimStatusOptions" item-title="label" item-value="value"
            density="compact" hide-details variant="outlined" rounded="lg" clearable
            placeholder="Status" persistent-placeholder style="max-width:200px"
          />
          <v-select
            v-model="claimProviderFilter"
            :items="providerOptions" item-title="name" item-value="id"
            density="compact" hide-details variant="outlined" rounded="lg" clearable
            placeholder="Provider" persistent-placeholder style="max-width:240px"
          />
          <v-spacer />
          <v-chip color="primary" variant="tonal">
            Total: <strong class="ml-1">{{ fmtMoney(filteredClaims.reduce((s,c)=>s+Number(c.claim_amount||0),0)) }}</strong>
          </v-chip>
        </div>
      </v-card>

      <v-card flat rounded="lg" class="section-card">
        <v-data-table
          class="acct-table"
          :headers="claimHeaders"
          :items="filteredClaims"
          :loading="loading"
          density="comfortable"
          items-per-page="25"
        >
          <template #[`item.reference`]="{ item }">
            <div class="font-weight-bold">{{ item.reference || '—' }}</div>
            <div class="text-caption text-medium-emphasis">{{ fmtDate(item.created_at) }}</div>
          </template>
          <template #[`item.provider`]="{ item }">{{ providerName(item) }}</template>
          <template #[`item.member`]="{ item }">
            <div>{{ item.member_name }}</div>
            <div class="text-caption text-medium-emphasis">{{ item.member_number }}</div>
          </template>
          <template #[`item.invoice_number`]="{ item }">{{ item.invoice_number || '—' }}</template>
          <template #[`item.claim_amount`]="{ item }">{{ fmtMoney(item.claim_amount) }}</template>
          <template #[`item.approved_amount`]="{ item }">{{ fmtMoney(item.approved_amount) }}</template>
          <template #[`item.outstanding`]="{ item }">
            <strong :class="claimOutstanding(item) > 0 ? 'text-error' : 'text-success'">
              {{ fmtMoney(claimOutstanding(item)) }}
            </strong>
          </template>
          <template #[`item.status`]="{ item }">
            <v-chip size="x-small" :color="claimStatusColor(item.status)" variant="flat" class="text-capitalize">
              {{ claimStatusLabel(item.status) }}
            </v-chip>
          </template>
          <template #[`item.actions`]="{ item }">
            <v-menu>
              <template #activator="{ props }">
                <v-btn icon="mdi-dots-vertical" size="small" variant="text" v-bind="props" />
              </template>
              <v-list density="compact">
                <v-list-item @click="openClaim(item)">
                  <template #prepend><v-icon>mdi-eye</v-icon></template>
                  <v-list-item-title>View / edit</v-list-item-title>
                </v-list-item>
                <v-list-item v-if="item.status === 'draft'" @click="submitClaim(item)">
                  <template #prepend><v-icon color="primary">mdi-send</v-icon></template>
                  <v-list-item-title>Submit</v-list-item-title>
                </v-list-item>
                <v-list-item v-if="['submitted','under_review'].includes(item.status)" @click="openApprove(item)">
                  <template #prepend><v-icon color="success">mdi-check</v-icon></template>
                  <v-list-item-title>Approve</v-list-item-title>
                </v-list-item>
                <v-list-item v-if="['submitted','under_review','partially_approved'].includes(item.status)"
                             @click="openReject(item)">
                  <template #prepend><v-icon color="error">mdi-close</v-icon></template>
                  <v-list-item-title>Reject</v-list-item-title>
                </v-list-item>
                <v-list-item v-if="['approved','partially_approved'].includes(item.status)"
                             @click="openPayment(item)">
                  <template #prepend><v-icon color="primary">mdi-cash-plus</v-icon></template>
                  <v-list-item-title>Record payment</v-list-item-title>
                </v-list-item>
              </v-list>
            </v-menu>
          </template>
        </v-data-table>
      </v-card>
    </template>

    <!-- ============== PROVIDERS ============== -->
    <template v-if="tab === 'providers'">
      <v-card flat class="pa-3 mb-3 section-card" rounded="lg">
        <div class="d-flex flex-wrap align-center" style="gap:8px">
          <v-text-field
            v-model="providerSearch"
            density="compact" hide-details variant="outlined" rounded="lg"
            prepend-inner-icon="mdi-magnify"
            placeholder="Search providers" persistent-placeholder
            style="max-width:280px"
          />
          <v-spacer />
          <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="openProvider()">Add provider</v-btn>
        </div>
      </v-card>

      <v-card flat rounded="lg" class="section-card">
        <v-data-table
          class="acct-table"
          :headers="providerHeaders"
          :items="filteredProviders"
          :loading="loading"
          density="comfortable"
          items-per-page="25"
        >
          <template #[`item.name`]="{ item }">
            <div class="font-weight-bold">{{ item.name }}</div>
            <div class="text-caption text-medium-emphasis">{{ item.code || '—' }}</div>
          </template>
          <template #[`item.contact`]="{ item }">
            <div>{{ item.contact_person || '—' }}</div>
            <div class="text-caption text-medium-emphasis">
              {{ item.phone || '' }} {{ item.email ? '· ' + item.email : '' }}
            </div>
          </template>
          <template #[`item.payment_terms_days`]="{ item }">{{ item.payment_terms_days }}d</template>
          <template #[`item.discount_rate`]="{ item }">{{ Number(item.discount_rate || 0).toFixed(2) }}%</template>
          <template #[`item.is_active`]="{ item }">
            <v-chip size="x-small" :color="item.is_active ? 'success' : 'grey'" variant="tonal">
              {{ item.is_active ? 'Active' : 'Inactive' }}
            </v-chip>
          </template>
          <template #[`item.actions`]="{ item }">
            <v-btn icon="mdi-pencil" size="small" variant="text" @click="openProvider(item)" />
          </template>
        </v-data-table>
      </v-card>
    </template>

    <!-- ============== OUTSTANDING ============== -->
    <template v-if="tab === 'outstanding'">
      <v-row dense class="mb-3">
        <v-col v-for="b in agingBuckets" :key="b.label" cols="6" md="3">
          <v-card variant="tonal" :color="b.color" rounded="lg" class="pa-3 text-center">
            <div class="text-caption text-uppercase">{{ b.label }}</div>
            <div class="text-h6 font-weight-bold">{{ fmtMoney(b.total) }}</div>
            <div class="text-caption">{{ b.count }} claim(s)</div>
          </v-card>
        </v-col>
      </v-row>

      <v-card flat rounded="lg" class="section-card">
        <v-data-table
          class="acct-table"
          :headers="outstandingHeaders"
          :items="outstandingClaims"
          :loading="loading"
          density="comfortable"
          items-per-page="25"
        >
          <template #[`item.reference`]="{ item }">
            <div class="font-weight-bold">{{ item.reference }}</div>
            <div class="text-caption text-medium-emphasis">{{ fmtDate(item.submitted_at || item.created_at) }}</div>
          </template>
          <template #[`item.provider`]="{ item }">{{ providerName(item) }}</template>
          <template #[`item.member`]="{ item }">{{ item.member_name }}</template>
          <template #[`item.outstanding`]="{ item }">
            <strong class="text-error">{{ fmtMoney(claimOutstanding(item)) }}</strong>
          </template>
          <template #[`item.days`]="{ item }">{{ daysSinceSubmit(item) }}d</template>
          <template #[`item.bucket`]="{ item }">
            <v-chip size="x-small" :color="agingColor(daysSinceSubmit(item))" variant="tonal">
              {{ agingLabel(daysSinceSubmit(item)) }}
            </v-chip>
          </template>
          <template #[`item.actions`]="{ item }">
            <v-btn size="small" color="primary" variant="tonal"
                   prepend-icon="mdi-cash-plus" @click="openPayment(item)">Payment</v-btn>
          </template>
        </v-data-table>
      </v-card>
    </template>

    <!-- ============== INSURED INVOICES ============== -->
    <template v-if="tab === 'invoices'">
      <v-card flat class="pa-3 mb-3 section-card" rounded="lg">
        <div class="d-flex flex-wrap align-center" style="gap:8px">
          <v-text-field
            v-model="invoiceSearch"
            density="compact" hide-details variant="outlined" rounded="lg"
            prepend-inner-icon="mdi-magnify"
            placeholder="Search invoice / patient" persistent-placeholder
            style="max-width:300px"
          />
          <v-select
            v-model="invoiceClaimedFilter"
            :items="[
              { value: 'all', label: 'All insured' },
              { value: 'unclaimed', label: 'Without claim' },
              { value: 'claimed', label: 'Claim filed' },
            ]"
            item-title="label" item-value="value"
            density="compact" hide-details variant="outlined" rounded="lg"
            persistent-placeholder style="max-width:200px"
          />
        </div>
      </v-card>

      <v-card flat rounded="lg" class="section-card">
        <v-data-table
          class="acct-table"
          :headers="invoiceHeaders"
          :items="filteredInsuredInvoices"
          :loading="loading"
          density="comfortable"
          items-per-page="25"
        >
          <template #[`item.invoice_number`]="{ item }">
            <div class="font-weight-bold">{{ item.invoice_number }}</div>
            <div class="text-caption text-medium-emphasis">{{ fmtDate(item.created_at) }}</div>
          </template>
          <template #[`item.patient`]="{ item }">{{ patientLabel(item) }}</template>
          <template #[`item.scheme`]="{ item }">{{ item.insurance_scheme || '—' }}</template>
          <template #[`item.total`]="{ item }">{{ fmtMoney(item.total) }}</template>
          <template #[`item.balance`]="{ item }">
            <strong :class="invoiceBalance(item) > 0 ? 'text-error' : 'text-success'">
              {{ fmtMoney(invoiceBalance(item)) }}
            </strong>
          </template>
          <template #[`item.claim`]="{ item }">
            <v-chip v-if="invoiceHasClaim(item)" size="x-small" color="success" variant="tonal">
              <v-icon start size="14">mdi-check</v-icon>Filed
            </v-chip>
            <v-chip v-else size="x-small" color="warning" variant="tonal">
              <v-icon start size="14">mdi-alert</v-icon>None
            </v-chip>
          </template>
          <template #[`item.actions`]="{ item }">
            <v-btn v-if="!invoiceHasClaim(item)" size="small" color="primary" variant="tonal"
                   prepend-icon="mdi-plus" @click="openClaimFromInvoice(item)">File claim</v-btn>
          </template>
        </v-data-table>
      </v-card>
    </template>

    <!-- ── Claim dialog ────────────────────────────────────────────── -->
    <v-dialog v-model="claimDialog" max-width="820" persistent scrollable>
      <v-card v-if="claimForm" rounded="lg">
        <v-card-title class="pa-4 d-flex align-center ga-3">
          <v-avatar color="indigo-lighten-5" size="36">
            <v-icon color="indigo-darken-2" size="20">mdi-shield-account</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">Insurance claim</div>
            <div class="text-h6 font-weight-bold">
              {{ claimForm.id ? `Claim ${claimForm.reference || ''}` : 'New claim' }}
            </div>
          </div>
          <v-spacer />
          <v-chip v-if="claimForm.status" size="small"
                  :color="claimStatusColor(claimForm.status)" variant="tonal" class="text-capitalize">
            {{ claimStatusLabel(claimForm.status) }}
          </v-chip>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-row dense>
            <v-col cols="12" md="6">
              <v-select
                v-model="claimForm.provider"
                :items="providers" item-title="name" item-value="id"
                label="Insurance provider" variant="outlined" density="compact" rounded="lg"
                persistent-placeholder hide-details required
              />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="claimForm.scheme_name" label="Scheme name"
                            variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="claimForm.member_name" label="Member name"
                            variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details required />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="claimForm.member_number" label="Member number"
                            variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details required />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="claimForm.invoice_number" label="Lab invoice #"
                            variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model.number="claimForm.claim_amount" type="number" label="Claim amount"
                            variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details required />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="claimForm.diagnosis" label="Diagnosis / clinical justification"
                          variant="outlined" density="compact" rounded="lg"
                          rows="2" persistent-placeholder hide-details />
            </v-col>
            <v-col cols="12">
              <div class="d-flex align-center mb-2">
                <div class="text-subtitle-2 font-weight-bold">Items</div>
                <v-chip size="x-small" variant="tonal" class="ml-2">{{ claimForm.items.length }}</v-chip>
                <v-spacer />
                <v-btn size="small" variant="text" prepend-icon="mdi-plus" @click="addItem">Add item</v-btn>
              </div>
              <v-table density="compact">
                <thead>
                  <tr>
                    <th>Description</th>
                    <th class="text-right" style="width:90px">Qty</th>
                    <th class="text-right" style="width:130px">Unit price</th>
                    <th class="text-right" style="width:130px">Total</th>
                    <th style="width:40px"></th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="(it, idx) in claimForm.items" :key="idx">
                    <td><v-text-field v-model="it.description" density="compact" hide-details variant="plain" /></td>
                    <td><v-text-field v-model.number="it.quantity" type="number" density="compact" hide-details variant="plain"
                                      @update:model-value="recalcItem(it)" /></td>
                    <td><v-text-field v-model.number="it.unit_price" type="number" density="compact" hide-details variant="plain"
                                      @update:model-value="recalcItem(it)" /></td>
                    <td class="text-right">{{ fmtMoney(it.total) }}</td>
                    <td>
                      <v-btn icon="mdi-close" size="x-small" variant="text" @click="claimForm.items.splice(idx, 1)" />
                    </td>
                  </tr>
                  <tr v-if="!claimForm.items.length">
                    <td colspan="5" class="text-center text-medium-emphasis py-3">No items</td>
                  </tr>
                </tbody>
              </v-table>
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="claimForm.notes" label="Notes"
                          variant="outlined" density="compact" rounded="lg"
                          rows="2" persistent-placeholder hide-details />
            </v-col>
          </v-row>
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" @click="claimDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" prepend-icon="mdi-content-save-outline"
                 :loading="claimSaving" @click="saveClaim">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Approve dialog ──────────────────────────────────────────── -->
    <v-dialog v-model="approveDialog" max-width="480" persistent>
      <v-card v-if="actionTarget" rounded="lg">
        <v-card-title class="pa-4 d-flex align-center ga-3">
          <v-avatar color="green-lighten-5" size="36">
            <v-icon color="green-darken-2" size="20">mdi-check</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">{{ actionTarget.reference }}</div>
            <div class="text-h6 font-weight-bold">Approve claim</div>
          </div>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-card flat class="pa-3 mb-3 notes-card">
            <div class="text-caption text-medium-emphasis">Claim amount</div>
            <div class="text-h6 font-weight-bold">{{ fmtMoney(actionTarget.claim_amount) }}</div>
          </v-card>
          <v-text-field v-model.number="actionForm.approved_amount" type="number"
                        label="Approved amount" variant="outlined" density="compact" rounded="lg"
                        persistent-placeholder hide-details />
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" @click="approveDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" prepend-icon="mdi-shield-check"
                 :loading="actionSaving" @click="confirmApprove">Approve</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Reject dialog ───────────────────────────────────────────── -->
    <v-dialog v-model="rejectDialog" max-width="480" persistent>
      <v-card v-if="actionTarget" rounded="lg">
        <v-card-title class="pa-4 d-flex align-center ga-3">
          <v-avatar color="red-lighten-5" size="36">
            <v-icon color="red-darken-2" size="20">mdi-close</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">{{ actionTarget.reference }}</div>
            <div class="text-h6 font-weight-bold">Reject claim</div>
          </div>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-textarea v-model="actionForm.reason" label="Rejection reason"
                      placeholder="Explain why this claim is being rejected…" persistent-placeholder
                      variant="outlined" density="compact" rounded="lg" rows="3" hide-details />
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" @click="rejectDialog = false">Cancel</v-btn>
          <v-btn color="error" rounded="lg" prepend-icon="mdi-close-circle"
                 :loading="actionSaving" @click="confirmReject">Reject</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Payment dialog ──────────────────────────────────────────── -->
    <v-dialog v-model="paymentDialog" max-width="500" persistent>
      <v-card v-if="actionTarget" rounded="lg">
        <v-card-title class="pa-4 d-flex align-center ga-3">
          <v-avatar color="green-lighten-5" size="36">
            <v-icon color="green-darken-2" size="20">mdi-cash-plus</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">{{ actionTarget.reference }}</div>
            <div class="text-h6 font-weight-bold">Record payment</div>
          </div>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-card flat class="pa-3 mb-3 notes-card">
            <div class="text-caption text-medium-emphasis">Outstanding</div>
            <div class="text-h6 font-weight-bold">{{ fmtMoney(claimOutstanding(actionTarget)) }}</div>
          </v-card>
          <v-text-field v-model.number="actionForm.amount" type="number" label="Amount"
                        variant="outlined" density="compact" rounded="lg"
                        persistent-placeholder hide-details class="mb-3" />
          <v-text-field v-model="actionForm.reference" label="Payment reference"
                        placeholder="Receipt / transaction id" persistent-placeholder
                        variant="outlined" density="compact" rounded="lg" hide-details />
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" @click="paymentDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" prepend-icon="mdi-content-save-outline"
                 :loading="actionSaving" @click="confirmPayment">Save payment</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ── Provider dialog ─────────────────────────────────────────── -->
    <v-dialog v-model="providerDialog" max-width="680" persistent scrollable>
      <v-card v-if="providerForm" rounded="lg">
        <v-card-title class="pa-4 d-flex align-center ga-3">
          <v-avatar color="purple-lighten-5" size="36">
            <v-icon color="purple-darken-2" size="20">mdi-domain</v-icon>
          </v-avatar>
          <div>
            <div class="text-overline text-medium-emphasis">Insurance provider</div>
            <div class="text-h6 font-weight-bold">
              {{ providerForm.id ? 'Edit provider' : 'New provider' }}
            </div>
          </div>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-row dense>
            <v-col cols="12" md="8">
              <v-text-field v-model="providerForm.name" label="Name"
                            variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details required />
            </v-col>
            <v-col cols="12" md="4">
              <v-text-field v-model="providerForm.code" label="Code"
                            variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="providerForm.contact_person" label="Contact person"
                            variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="providerForm.phone" label="Phone"
                            variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="providerForm.email" label="Email"
                            variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="providerForm.claim_email" label="Claims email"
                            variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model.number="providerForm.payment_terms_days" type="number"
                            label="Payment terms (days)"
                            variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model.number="providerForm.discount_rate" type="number"
                            label="Discount %"
                            variant="outlined" density="compact" rounded="lg"
                            persistent-placeholder hide-details />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="providerForm.address" label="Address"
                          variant="outlined" density="compact" rounded="lg"
                          rows="2" persistent-placeholder hide-details />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="providerForm.notes" label="Notes"
                          variant="outlined" density="compact" rounded="lg"
                          rows="2" persistent-placeholder hide-details />
            </v-col>
            <v-col cols="12">
              <v-switch v-model="providerForm.is_active" label="Active"
                        color="success" inset density="compact" hide-details />
            </v-col>
          </v-row>
        </v-card-text>
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" @click="providerDialog = false">Cancel</v-btn>
          <v-btn color="primary" rounded="lg" prepend-icon="mdi-content-save-outline"
                 :loading="providerSaving" @click="saveProvider">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" :timeout="2400">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const route = useRoute()

const tab = ref(route.query.tab || 'overview')
const sectionPills = [
  { value: 'overview',    label: 'Overview',         color: 'primary',     icon: 'mdi-view-dashboard-outline' },
  { value: 'claims',      label: 'Claims',           color: 'indigo',      icon: 'mdi-file-document-multiple' },
  { value: 'providers',   label: 'Providers',        color: 'purple',      icon: 'mdi-domain' },
  { value: 'outstanding', label: 'Outstanding',      color: 'deep-orange', icon: 'mdi-cash-clock' },
  { value: 'invoices',    label: 'Insured Invoices', color: 'teal',        icon: 'mdi-receipt-text' },
]
const loading = ref(false)
const claims = ref([])
const providers = ref([])
const invoices = ref([])
const stats = ref(null)

const snack = ref({ show: false, color: 'success', text: '' })
const notify = (text, color = 'success') => { snack.value = { show: true, color, text } }

function pickRows(settled) {
  if (settled.status !== 'fulfilled') return []
  const d = settled.value?.data
  return d?.results || (Array.isArray(d) ? d : [])
}

async function loadAll() {
  loading.value = true
  try {
    const [cl, pr, inv, st] = await Promise.allSettled([
      $api.get('/insurance/claims/', { params: { page_size: 500, ordering: '-created_at' } }),
      $api.get('/insurance/providers/', { params: { page_size: 500 } }),
      $api.get('/lab/invoices/', { params: { page_size: 500, payer_type: 'insurance', ordering: '-created_at' } }),
      $api.get('/insurance/claims/stats/'),
    ])
    claims.value = pickRows(cl)
    providers.value = pickRows(pr)
    invoices.value = pickRows(inv)
    stats.value = st.status === 'fulfilled' ? st.value?.data : null
  } catch {
    notify('Failed to load insurance data', 'error')
  } finally {
    loading.value = false
  }
}
onMounted(loadAll)
watch(() => route.query.tab, v => { if (v) tab.value = v })

// ── Helpers ──────────────────────────────────────────────────────
const fmtMoney = (v) => 'KSh ' + Number(v || 0).toLocaleString(undefined, { maximumFractionDigits: 2 })
const fmtDate = (v) => v ? new Date(v).toLocaleDateString() : '—'
const claimOutstanding = (c) => Math.max(0, Number(c.approved_amount || 0) - Number(c.paid_amount || 0))
const invoiceBalance = (i) => Math.max(0, Number(i.total || 0) - Number(i.amount_paid || 0))
const patientLabel = (i) => i.patient_name || i.patient?.full_name || `Patient #${i.patient || ''}`
const providerName = (c) => c.provider_name || providers.value.find(p => p.id === c.provider)?.name || '—'

const claimStatusOptions = [
  { value: 'draft', label: 'Draft' },
  { value: 'submitted', label: 'Submitted' },
  { value: 'under_review', label: 'Under Review' },
  { value: 'approved', label: 'Approved' },
  { value: 'partially_approved', label: 'Partially Approved' },
  { value: 'rejected', label: 'Rejected' },
  { value: 'paid', label: 'Paid' },
]
const claimStatusLabel = (s) => claimStatusOptions.find(o => o.value === s)?.label || s
function claimStatusColor(s) {
  return ({
    draft: 'grey', submitted: 'blue', under_review: 'cyan',
    approved: 'success', partially_approved: 'amber',
    rejected: 'error', paid: 'teal',
  })[s] || 'grey'
}
function claimStatusIcon(s) {
  return ({
    draft: 'mdi-pencil', submitted: 'mdi-send', under_review: 'mdi-eye',
    approved: 'mdi-check', partially_approved: 'mdi-check-circle-outline',
    rejected: 'mdi-close', paid: 'mdi-cash-check',
  })[s] || 'mdi-file'
}

// ── KPIs ─────────────────────────────────────────────────────────
const totalClaimed = computed(() => claims.value.reduce((s, c) => s + Number(c.claim_amount || 0), 0))
const totalApproved = computed(() => claims.value.reduce((s, c) => s + Number(c.approved_amount || 0), 0))
const totalPaid = computed(() => claims.value.reduce((s, c) => s + Number(c.paid_amount || 0), 0))
const totalOutstanding = computed(() => claims.value.reduce((s, c) => s + claimOutstanding(c), 0))

const kpiTiles = computed(() => [
  { label: 'Claims', value: claims.value.length, sub: `${claims.value.filter(c => c.status === 'draft').length} draft`,
    icon: 'mdi-file-document-multiple', color: 'indigo' },
  { label: 'Claimed', value: fmtMoney(totalClaimed.value),
    sub: `Approved ${fmtMoney(totalApproved.value)}`,
    icon: 'mdi-cash-fast', color: 'primary' },
  { label: 'Paid', value: fmtMoney(totalPaid.value),
    sub: totalApproved.value > 0
      ? `${((totalPaid.value / totalApproved.value) * 100).toFixed(1)}% of approved`
      : '—',
    icon: 'mdi-cash-check', color: 'success' },
  { label: 'Outstanding', value: fmtMoney(totalOutstanding.value),
    sub: `${claims.value.filter(c => claimOutstanding(c) > 0).length} open`,
    icon: 'mdi-cash-clock', color: 'error' },
])

// ── Overview groupings ───────────────────────────────────────────
const claimsByStatus = computed(() => {
  const map = new Map()
  claims.value.forEach(c => {
    const k = c.status || 'draft'
    const cur = map.get(k) || { key: k, count: 0, amount: 0 }
    cur.count += 1
    cur.amount += Number(c.claim_amount || 0)
    map.set(k, cur)
  })
  const total = Array.from(map.values()).reduce((s, r) => s + r.amount, 0) || 1
  return Array.from(map.values())
    .map(r => ({ ...r, pct: Math.round((r.amount / total) * 100) }))
    .sort((a, b) => b.amount - a.amount)
})

const topProviders = computed(() => {
  const map = new Map()
  claims.value.forEach(c => {
    const name = providerName(c)
    const cur = map.get(name) || { name, count: 0, claimed: 0, approved: 0, outstanding: 0 }
    cur.count += 1
    cur.claimed += Number(c.claim_amount || 0)
    cur.approved += Number(c.approved_amount || 0)
    cur.outstanding += claimOutstanding(c)
    map.set(name, cur)
  })
  return Array.from(map.values()).sort((a, b) => b.outstanding - a.outstanding).slice(0, 6)
})

const attentionClaims = computed(() =>
  claims.value
    .filter(c => ['draft', 'submitted', 'under_review', 'rejected'].includes(c.status))
    .sort((a, b) => String(b.created_at).localeCompare(String(a.created_at)))
    .slice(0, 6)
)

// ── Claims tab ───────────────────────────────────────────────────
const claimSearch = ref('')
const claimStatusFilter = ref(null)
const claimProviderFilter = ref(null)
const providerOptions = computed(() => providers.value)

const claimHeaders = [
  { title: 'Reference', key: 'reference' },
  { title: 'Provider', key: 'provider', sortable: false },
  { title: 'Member', key: 'member', sortable: false },
  { title: 'Invoice', key: 'invoice_number' },
  { title: 'Claimed', key: 'claim_amount', align: 'end' },
  { title: 'Approved', key: 'approved_amount', align: 'end' },
  { title: 'Outstanding', key: 'outstanding', align: 'end' },
  { title: 'Status', key: 'status' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 60 },
]

const filteredClaims = computed(() => {
  const q = claimSearch.value.toLowerCase()
  return claims.value.filter(c => {
    if (claimStatusFilter.value && c.status !== claimStatusFilter.value) return false
    if (claimProviderFilter.value && c.provider !== claimProviderFilter.value) return false
    if (!q) return true
    return (c.reference || '').toLowerCase().includes(q) ||
           (c.member_name || '').toLowerCase().includes(q) ||
           (c.member_number || '').toLowerCase().includes(q) ||
           (c.invoice_number || '').toLowerCase().includes(q)
  })
})

// ── Providers tab ────────────────────────────────────────────────
const providerSearch = ref('')
const providerHeaders = [
  { title: 'Name', key: 'name' },
  { title: 'Contact', key: 'contact', sortable: false },
  { title: 'Terms', key: 'payment_terms_days', align: 'end' },
  { title: 'Discount', key: 'discount_rate', align: 'end' },
  { title: 'Status', key: 'is_active' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 60 },
]
const filteredProviders = computed(() => {
  const q = providerSearch.value.toLowerCase()
  if (!q) return providers.value
  return providers.value.filter(p =>
    (p.name || '').toLowerCase().includes(q) ||
    (p.code || '').toLowerCase().includes(q) ||
    (p.contact_person || '').toLowerCase().includes(q)
  )
})

// ── Outstanding tab ──────────────────────────────────────────────
const outstandingClaims = computed(() =>
  claims.value
    .filter(c => claimOutstanding(c) > 0 && c.status !== 'rejected')
    .sort((a, b) => daysSinceSubmit(b) - daysSinceSubmit(a))
)
const outstandingHeaders = [
  { title: 'Reference', key: 'reference' },
  { title: 'Provider', key: 'provider', sortable: false },
  { title: 'Member', key: 'member', sortable: false },
  { title: 'Outstanding', key: 'outstanding', align: 'end' },
  { title: 'Days', key: 'days', align: 'end' },
  { title: 'Bucket', key: 'bucket' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 130 },
]
function daysSinceSubmit(c) {
  const d = new Date(c.submitted_at || c.created_at)
  return Math.max(0, Math.floor((Date.now() - d.getTime()) / 86400000))
}
function agingLabel(d) {
  if (d <= 30) return '0–30'
  if (d <= 60) return '31–60'
  if (d <= 90) return '61–90'
  return '90+'
}
function agingColor(d) {
  if (d <= 30) return 'success'
  if (d <= 60) return 'amber'
  if (d <= 90) return 'orange'
  return 'error'
}
const agingBuckets = computed(() => {
  const buckets = [
    { label: '0–30', color: 'success', total: 0, count: 0 },
    { label: '31–60', color: 'amber', total: 0, count: 0 },
    { label: '61–90', color: 'orange', total: 0, count: 0 },
    { label: '90+', color: 'error', total: 0, count: 0 },
  ]
  outstandingClaims.value.forEach(c => {
    const d = daysSinceSubmit(c)
    let idx = 3
    if (d <= 30) idx = 0
    else if (d <= 60) idx = 1
    else if (d <= 90) idx = 2
    buckets[idx].total += claimOutstanding(c)
    buckets[idx].count += 1
  })
  return buckets
})

// ── Insured invoices tab ─────────────────────────────────────────
const invoiceSearch = ref('')
const invoiceClaimedFilter = ref('all')
const invoiceHeaders = [
  { title: 'Invoice', key: 'invoice_number' },
  { title: 'Patient', key: 'patient', sortable: false },
  { title: 'Scheme', key: 'scheme' },
  { title: 'Total', key: 'total', align: 'end' },
  { title: 'Balance', key: 'balance', align: 'end' },
  { title: 'Claim', key: 'claim' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: 130 },
]
const insuredInvoices = computed(() => invoices.value.filter(i => i.payer_type === 'insurance'))
function invoiceHasClaim(inv) {
  return claims.value.some(c => c.invoice_number === inv.invoice_number)
}
const filteredInsuredInvoices = computed(() => {
  const q = invoiceSearch.value.toLowerCase()
  return insuredInvoices.value.filter(i => {
    if (invoiceClaimedFilter.value === 'unclaimed' && invoiceHasClaim(i)) return false
    if (invoiceClaimedFilter.value === 'claimed' && !invoiceHasClaim(i)) return false
    if (!q) return true
    return (i.invoice_number || '').toLowerCase().includes(q) ||
           patientLabel(i).toLowerCase().includes(q)
  })
})
const unclaimedInsuredInvoices = computed(() => insuredInvoices.value.filter(i => !invoiceHasClaim(i)))

// ── Claim dialog ─────────────────────────────────────────────────
const claimDialog = ref(false)
const claimForm = ref(null)
const claimSaving = ref(false)
function openClaim(c = null) {
  if (c) {
    claimForm.value = {
      ...c,
      items: Array.isArray(c.items) ? JSON.parse(JSON.stringify(c.items)) : [],
    }
  } else {
    claimForm.value = {
      provider: null, member_name: '', member_number: '', scheme_name: '',
      diagnosis: '', invoice_number: '', items: [], notes: '',
      claim_amount: 0, status: 'draft',
    }
  }
  claimDialog.value = true
}
function openClaimFromInvoice(inv) {
  const items = (inv.items || []).map(it => ({
    description: it.description || '', quantity: Number(it.qty || 1),
    unit_price: Number(it.unit_price || 0),
    total: Number(it.amount || (Number(it.qty || 1) * Number(it.unit_price || 0))),
  }))
  claimForm.value = {
    provider: null,
    member_name: patientLabel(inv),
    member_number: '',
    scheme_name: inv.insurance_scheme || '',
    diagnosis: '',
    invoice_number: inv.invoice_number,
    items,
    claim_amount: items.reduce((s, x) => s + x.total, Number(inv.total || 0) - items.reduce((s, x) => s + x.total, 0) || 0) || Number(inv.total || 0),
    notes: `Auto-filed from lab invoice ${inv.invoice_number}`,
    status: 'draft',
  }
  // Recompute claim_amount cleanly
  claimForm.value.claim_amount = items.reduce((s, x) => s + Number(x.total || 0), 0) || Number(inv.total || 0)
  claimDialog.value = true
}
function addItem() {
  claimForm.value.items.push({ description: '', quantity: 1, unit_price: 0, total: 0 })
}
function recalcItem(it) {
  it.total = Number(it.quantity || 0) * Number(it.unit_price || 0)
  // Auto-update claim amount
  claimForm.value.claim_amount = claimForm.value.items
    .reduce((s, x) => s + Number(x.total || 0), 0) || claimForm.value.claim_amount
}
async function saveClaim() {
  claimSaving.value = true
  try {
    const payload = { ...claimForm.value }
    if (payload.id) {
      await $api.patch(`/insurance/claims/${payload.id}/`, payload)
    } else {
      await $api.post('/insurance/claims/', payload)
    }
    notify('Claim saved')
    claimDialog.value = false
    await loadAll()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to save claim', 'error')
  } finally { claimSaving.value = false }
}

async function submitClaim(c) {
  try {
    await $api.post(`/insurance/claims/${c.id}/submit/`)
    notify('Claim submitted')
    await loadAll()
  } catch { notify('Failed to submit', 'error') }
}

// ── Action dialogs ───────────────────────────────────────────────
const actionTarget = ref(null)
const actionForm = ref({})
const actionSaving = ref(false)
const approveDialog = ref(false)
const rejectDialog = ref(false)
const paymentDialog = ref(false)

function openApprove(c) {
  actionTarget.value = c
  actionForm.value = { approved_amount: Number(c.claim_amount || 0) }
  approveDialog.value = true
}
async function confirmApprove() {
  actionSaving.value = true
  try {
    await $api.post(`/insurance/claims/${actionTarget.value.id}/approve/`, actionForm.value)
    notify('Claim approved')
    approveDialog.value = false
    await loadAll()
  } catch { notify('Failed to approve', 'error') }
  finally { actionSaving.value = false }
}

function openReject(c) {
  actionTarget.value = c
  actionForm.value = { reason: '' }
  rejectDialog.value = true
}
async function confirmReject() {
  actionSaving.value = true
  try {
    await $api.post(`/insurance/claims/${actionTarget.value.id}/reject/`, actionForm.value)
    notify('Claim rejected')
    rejectDialog.value = false
    await loadAll()
  } catch { notify('Failed to reject', 'error') }
  finally { actionSaving.value = false }
}

function openPayment(c) {
  actionTarget.value = c
  actionForm.value = { amount: claimOutstanding(c), reference: '' }
  paymentDialog.value = true
}
async function confirmPayment() {
  actionSaving.value = true
  try {
    await $api.post(`/insurance/claims/${actionTarget.value.id}/record-payment/`, actionForm.value)
    notify('Payment recorded')
    paymentDialog.value = false
    await loadAll()
  } catch { notify('Failed to record payment', 'error') }
  finally { actionSaving.value = false }
}

// ── Provider dialog ──────────────────────────────────────────────
const providerDialog = ref(false)
const providerForm = ref(null)
const providerSaving = ref(false)
function openProvider(p = null) {
  providerForm.value = p
    ? { ...p }
    : { name: '', code: '', contact_person: '', phone: '', email: '',
        claim_email: '', payment_terms_days: 30, discount_rate: 0,
        address: '', notes: '', is_active: true }
  providerDialog.value = true
}
async function saveProvider() {
  providerSaving.value = true
  try {
    if (providerForm.value.id) {
      await $api.patch(`/insurance/providers/${providerForm.value.id}/`, providerForm.value)
    } else {
      await $api.post('/insurance/providers/', providerForm.value)
    }
    notify('Provider saved')
    providerDialog.value = false
    await loadAll()
  } catch { notify('Failed to save provider', 'error') }
  finally { providerSaving.value = false }
}

// ── Export ──────────────────────────────────────────────────────
function exportClaims() {
  if (!filteredClaims.value.length) return notify('Nothing to export', 'warning')
  const rows = filteredClaims.value.map(c => ({
    reference: c.reference, provider: providerName(c),
    member_name: c.member_name, member_number: c.member_number,
    invoice: c.invoice_number, scheme: c.scheme_name,
    claimed: c.claim_amount, approved: c.approved_amount, paid: c.paid_amount,
    outstanding: claimOutstanding(c), status: c.status,
    submitted_at: c.submitted_at, created_at: c.created_at,
  }))
  const keys = Object.keys(rows[0])
  const escape = (v) => `"${String(v ?? '').replace(/"/g, '""')}"`
  const csv = [keys.join(',')].concat(rows.map(r => keys.map(k => escape(r[k])).join(','))).join('\n')
  const blob = new Blob([csv], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = `lab-insurance-claims-${new Date().toISOString().slice(0, 10)}.csv`; a.click()
  URL.revokeObjectURL(url)
}
</script>

<style scoped>
.kpi {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.section-card {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.section-pills {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.06);
}
.notes-card {
  background: rgba(var(--v-theme-warning), 0.06);
  border: 1px solid rgba(var(--v-theme-warning), 0.2);
}
.min-width-0 { min-width: 0; }
.acct-table :deep(tbody tr) { cursor: pointer; }
.acct-table :deep(tbody tr:hover) { background:#eef2ff !important; }
.acct-table :deep(tbody tr:hover > td),
.acct-table :deep(tbody tr:hover > td *) {
  background-color: transparent !important;
  color:#0f172a !important;
}
.acct-table :deep(tbody tr:hover > td .text-medium-emphasis),
.acct-table :deep(tbody tr:hover > td .text-caption) {
  color:#475569 !important;
}
.acct-table :deep(tbody tr:hover .v-chip) { filter: none !important; }
</style>
