<template>
  <div class="pb-bg pa-4 pa-md-6">
    <!-- Hero -->
    <v-card class="pb-hero" rounded="xl" :elevation="0">
      <div class="pb-hero-decor" />
      <div class="d-flex flex-wrap align-center ga-4 pa-6">
        <v-avatar size="56" class="pb-hero-avatar">
          <v-icon icon="mdi-receipt-text-account" size="30" color="white" />
        </v-avatar>
        <div class="flex-grow-1">
          <div class="text-overline text-white font-weight-bold" style="opacity:.85">ADMIN &amp; MANAGEMENT · FINANCIALS</div>
          <h1 class="text-h5 font-weight-bold text-white mt-1">Patient Bills &amp; Payment Plans</h1>
          <p class="text-body-2 text-white mt-1" style="opacity:.9">
            Track every patient bill, outstanding balance, payment plan and recorded payment in one place.
          </p>
        </div>
        <div class="d-flex flex-wrap ga-2">
          <v-chip variant="flat" color="white" class="text-teal-darken-2 font-weight-bold" size="large">
            <v-icon start icon="mdi-receipt-text-multiple" />{{ bills.length }} bills
          </v-chip>
          <v-chip variant="flat" color="white" class="text-amber-darken-2 font-weight-bold" size="large">
            <v-icon start icon="mdi-cash-clock" />{{ money(kpis.outstanding) }} outstanding
          </v-chip>
          <v-chip variant="flat" color="white" class="text-success font-weight-bold" size="large">
            <v-icon start icon="mdi-cash-check" />{{ money(kpis.collected) }} collected
          </v-chip>
          <v-chip variant="flat" color="white" class="text-indigo-darken-2 font-weight-bold" size="large">
            <v-icon start icon="mdi-calendar-sync" />{{ billingTypeLabel }}
          </v-chip>
        </div>
      </div>
    </v-card>

    <!-- KPI strip -->
    <v-row dense class="mt-3">
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Total Billed" :value="money(kpis.billed)" icon="mdi-receipt-text" color="#0d9488" :hint="`${bills.length} bills`" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Collected" :value="money(kpis.collected)" icon="mdi-cash" color="#10b981" :hint="`${kpis.paidCount} paid bills`" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Outstanding" :value="money(kpis.outstanding)" icon="mdi-cash-clock" color="#ef4444" :hint="`${kpis.overdueCount} overdue`" />
      </v-col>
      <v-col cols="6" md="3">
        <HomecareKpiCard label="Collection Rate" :value="kpis.rate + '%'" icon="mdi-chart-arc" color="#f59e0b" :hint="`${plans.length} payment plans`" />
      </v-col>
    </v-row>

    <!-- Tabs -->
    <v-card rounded="xl" :elevation="0" class="mt-3 pb-card">
      <v-tabs v-model="tab" color="teal" density="comfortable" grow class="pb-tabs">
        <v-tab value="bills" class="text-none font-weight-bold"><v-icon start icon="mdi-receipt-text-multiple" />Bills</v-tab>
        <v-tab value="plans" class="text-none font-weight-bold"><v-icon start icon="mdi-calendar-cash" />Payment Plans</v-tab>
        <v-tab value="payments" class="text-none font-weight-bold"><v-icon start icon="mdi-cash-multiple" />Payments</v-tab>
      </v-tabs>
      <v-divider />

      <!-- ── Bills tab ── -->
      <v-tabs-window v-model="tab" class="pa-4 pa-md-5">
        <v-tabs-window-item value="bills">
          <div class="d-flex flex-wrap align-center ga-3 mb-4">
            <v-text-field v-model="billSearch" density="compact" variant="outlined" flat hide-details single-line
                          placeholder="Search bill # or patient…" prepend-inner-icon="mdi-magnify"
                          style="max-width: 280px;" />
            <v-btn-toggle v-model="billStatus" density="compact" rounded="lg" color="teal" variant="outlined">
              <v-btn value="all" size="small" class="text-none">All</v-btn>
              <v-btn value="issued" size="small" class="text-none">Issued</v-btn>
              <v-btn value="partial" size="small" class="text-none">Partial</v-btn>
              <v-btn value="paid" size="small" class="text-none">Paid</v-btn>
              <v-btn value="overdue" size="small" class="text-none">Overdue</v-btn>
            </v-btn-toggle>
            <v-spacer />
            <v-btn variant="flat" rounded="pill" color="success" prepend-icon="mdi-cash-plus"
                   class="text-none" @click="openPayment()"><span class="font-weight-bold">Record Payment</span></v-btn>
            <v-btn variant="flat" rounded="pill" color="teal" prepend-icon="mdi-file-plus"
                   class="text-none" @click="openGenerateBill()"><span class="font-weight-bold">Generate Bill</span></v-btn>
            <v-btn variant="flat" rounded="pill" color="indigo" prepend-icon="mdi-cog-outline"
                   class="text-none" @click="openSettingsDialog()"><span class="font-weight-bold">Bill Settings</span></v-btn>
            <v-btn variant="text" rounded="pill" color="teal" icon="mdi-refresh"
                   :loading="loading" @click="loadBills" />
          </div>

          <v-data-table :headers="billHeaders" :items="filteredBills" :loading="loading" item-value="id"
                        density="comfortable" hover expand-on-click
                        :items-per-page="15" :items-per-page-options="[10, 15, 25, 50]">
            <template #item.bill_number="{ item }">
              <span class="font-weight-bold text-teal-darken-2">{{ item.bill_number }}</span>
            </template>
            <template #item.patient_name="{ item }">
              <div class="d-flex align-center ga-2">
                <v-avatar size="32" color="teal" variant="tonal"><v-icon icon="mdi-account" /></v-avatar>
                <div>
                  <div class="font-weight-medium">{{ item.patient_name }}</div>
                  <div class="text-caption text-medium-emphasis">Patient #{{ item.patient }}</div>
                </div>
              </div>
            </template>
            <template #item.total="{ item }"><span class="font-weight-medium">{{ money(item.total) }}</span></template>
            <template #item.amount_paid="{ item }"><span class="text-success font-weight-medium">{{ money(item.amount_paid) }}</span></template>
            <template #item.balance="{ item }">
              <span :class="item.balance > 0 ? 'text-error font-weight-bold' : 'text-medium-emphasis'">{{ money(item.balance) }}</span>
            </template>
            <template #item.status="{ item }"><StatusChip :status="item.status" /></template>
            <template #item.created_at="{ item }">{{ formatDate(item.created_at) }}</template>
            <template #item.actions="{ item }">
              <div class="d-flex ga-1">
                <v-tooltip text="Record payment">
                  <template #activator="{ props }">
                    <v-btn v-bind="props" size="small" variant="text" color="success" icon="mdi-cash-plus"
                           :disabled="item.status === 'paid' || item.status === 'void'" @click.stop="openPayment(item)" />
                  </template>
                </v-tooltip>
                <v-tooltip text="View details">
                  <template #activator="{ props }">
                    <v-btn v-bind="props" size="small" variant="text" color="teal" icon="mdi-eye"
                           @click.stop="openBillDetail(item)" />
                  </template>
                </v-tooltip>
                <v-tooltip text="Download PDF">
                  <template #activator="{ props }">
                    <v-btn v-bind="props" size="small" variant="text" color="deep-purple" icon="mdi-download"
                           @click.stop="printBill(item)" />
                  </template>
                </v-tooltip>
                <v-tooltip text="Void bill">
                  <template #activator="{ props }">
                    <v-btn v-bind="props" size="small" variant="text" color="error" icon="mdi-file-cancel"
                           :disabled="item.status === 'paid' || item.status === 'void'" @click.stop="voidBill(item)" />
                  </template>
                </v-tooltip>
              </div>
            </template>
            <template #expanded-row="{ item }">
              <tr><td :colspan="billHeaders.length" class="pa-0">
                <div class="pb-expand">
                  <v-row dense>
                    <!-- Category breakdown -->
                    <v-col cols="12" md="5">
                      <div class="text-caption text-uppercase font-weight-bold text-medium-emphasis mb-2">Charge breakdown</div>
                      <div class="d-flex flex-column ga-1">
                        <div v-for="c in billCategories(item)" :key="c.label" class="d-flex align-center">
                          <v-icon :icon="c.icon" :color="c.color" size="18" class="mr-2" />
                          <span class="text-body-2 flex-grow-1">{{ c.label }}</span>
                          <span class="font-weight-medium text-body-2">{{ money(c.value) }}</span>
                        </div>
                        <v-divider class="my-1" />
                        <div class="d-flex align-center">
                          <span class="text-body-2 flex-grow-1 font-weight-bold">Subtotal</span>
                          <span class="font-weight-bold">{{ money(item.subtotal) }}</span>
                        </div>
                        <div class="d-flex align-center"><span class="text-body-2 flex-grow-1">Discount</span><span class="text-success">−{{ money(item.discount) }}</span></div>
                        <div class="d-flex align-center"><span class="text-body-2 flex-grow-1">Tax</span><span class="text-medium-emphasis">+{{ money(item.tax) }}</span></div>
                        <div class="d-flex align-center"><span class="text-body-2 flex-grow-1 font-weight-bold">Total</span><span class="font-weight-bold text-teal-darken-2">{{ money(item.total) }}</span></div>
                      </div>
                    </v-col>
                    <!-- Line items -->
                    <v-col cols="12" md="4">
                      <div class="text-caption text-uppercase font-weight-bold text-medium-emphasis mb-2">Line items</div>
                      <div v-if="(item.line_items || []).length" class="d-flex flex-column ga-1">
                        <div v-for="(li, i) in item.line_items" :key="i" class="d-flex align-center text-body-2">
                          <v-icon :icon="lineItemIcon(li.kind)" size="14" class="mr-2" color="teal" />
                          <span class="flex-grow-1 text-truncate">{{ li.label }}</span>
                          <span class="text-medium-emphasis mr-1">×{{ li.qty }}</span>
                          <span class="font-weight-medium">{{ money(li.amount) }}</span>
                        </div>
                      </div>
                      <EmptyState v-else icon="mdi-format-list-bulleted" title="No line items" dense />
                    </v-col>
                    <!-- Payments -->
                    <v-col cols="12" md="3">
                      <div class="text-caption text-uppercase font-weight-bold text-medium-emphasis mb-2">Payments</div>
                      <div v-if="(item.payments || []).length" class="d-flex flex-column ga-2">
                        <div v-for="p in item.payments" :key="p.id" class="pb-pay">
                          <div class="d-flex align-center">
                            <v-icon :icon="methodIcon(p.method)" :color="methodColor(p.method)" size="16" class="mr-1" />
                            <span class="text-body-2 font-weight-medium">{{ methodLabel(p.method) }}</span>
                            <span class="font-weight-bold ml-auto text-success">{{ money(p.amount) }}</span>
                          </div>
                          <div class="text-caption text-medium-emphasis pl-6">{{ formatDate(p.paid_at) }}<span v-if="p.reference"> · {{ p.reference }}</span></div>
                        </div>
                      </div>
                      <EmptyState v-else icon="mdi-cash-remove" title="No payments" dense />
                    </v-col>
                  </v-row>
                  <div v-if="item.notes" class="mt-3 text-body-2 text-medium-emphasis">
                    <v-icon icon="mdi-note-text-outline" size="16" class="mr-1" />{{ item.notes }}
                  </div>
                </div>
              </td></tr>
            </template>
            <template #no-data>
              <EmptyState icon="mdi-receipt-text-multiple-outline" title="No bills yet"
                          message="Bills are generated per patient. Use a patient's care summary to generate a bill." />
            </template>
          </v-data-table>
        </v-tabs-window-item>

        <!-- ── Payment Plans tab ── -->
        <v-tabs-window-item value="plans">
          <div class="d-flex flex-wrap align-center ga-3 mb-4">
            <v-text-field v-model="planSearch" density="compact" variant="outlined" flat hide-details single-line
                          placeholder="Search patient or plan…" prepend-inner-icon="mdi-magnify" style="max-width: 280px;" />
            <v-btn-toggle v-model="planFilter" density="compact" rounded="lg" color="teal" variant="outlined">
              <v-btn value="all" size="small" class="text-none">All</v-btn>
              <v-btn value="active" size="small" class="text-none">Active</v-btn>
              <v-btn value="inactive" size="small" class="text-none">Inactive</v-btn>
            </v-btn-toggle>
            <v-spacer />
            <v-btn variant="flat" rounded="pill" color="purple" prepend-icon="mdi-plus"
                   class="text-none" @click="openPlanDialog()"><span class="font-weight-bold">New Plan</span></v-btn>
            <v-btn variant="text" rounded="pill" color="teal" icon="mdi-refresh"
                   :loading="planLoading" @click="loadPlans" />
          </div>

          <v-row v-if="filteredPlans.length" dense>
            <v-col v-for="p in filteredPlans" :key="p.id" cols="12" md="6" lg="4">
              <v-card class="pb-plan" :class="{ 'pb-plan--inactive': !p.is_active }" rounded="xl" :elevation="0">
                <div class="d-flex align-start pa-4">
                  <v-avatar size="44" :color="planColor(p.plan_type)" variant="tonal" class="mr-3">
                    <v-icon :icon="planIcon(p.plan_type)" />
                  </v-avatar>
                  <div class="flex-grow-1">
                    <div class="d-flex align-center ga-2">
                      <span class="font-weight-bold">{{ p.patient_name }}</span>
                      <StatusChip :status="p.is_active ? 'active' : 'closed'" :label="p.is_active ? 'Active' : 'Inactive'" />
                    </div>
                    <div class="text-caption text-medium-emphasis">{{ p.plan_type_label }} · since {{ formatDate(p.start_date) }}</div>
                  </div>
                  <v-switch v-if="p.is_active" :model-value="p.auto_bill" density="compact" color="teal" hide-details
                            :label="p.auto_bill ? 'Auto-bill ON' : 'Auto-bill paused'" size="small"
                            :loading="p._toggling"
                            @update:model-value="v => toggleAutoBill(p, v)" />
                </div>
                <v-divider />
                <div class="pa-4">
                  <v-row dense>
                    <v-col cols="6">
                      <div class="text-caption text-uppercase text-medium-emphasis font-weight-bold">Rate</div>
                      <div class="text-h6 font-weight-bold text-teal-darken-2">{{ money(p.rate, p.currency) }}</div>
                      <div class="text-caption text-medium-emphasis">per {{ p.plan_type_label.toLowerCase() }}</div>
                    </v-col>
                    <v-col cols="6">
                      <div class="text-caption text-uppercase text-medium-emphasis font-weight-bold">Accrued</div>
                      <div class="text-h6 font-weight-bold">{{ money(p.accrued_cost, p.currency) }}</div>
                      <div class="text-caption text-medium-emphasis">to date</div>
                    </v-col>
                  </v-row>
                  <v-progress-linear :model-value="planProgress(p)" color="teal" rounded height="6" class="mt-2" />
                  <div class="d-flex justify-space-between text-caption text-medium-emphasis mt-1">
                    <span>Expected: {{ money(p.expected_cost, p.currency) }}</span>
                    <span v-if="p.end_date">Ends {{ formatDate(p.end_date) }}</span>
                    <span v-else>Ongoing</span>
                  </div>
                  <div v-if="p.notes" class="text-body-2 text-medium-emphasis mt-3">
                    <v-icon icon="mdi-note-text-outline" size="16" class="mr-1" />{{ p.notes }}
                  </div>
                </div>
              </v-card>
            </v-col>
          </v-row>
          <EmptyState v-else icon="mdi-calendar-cash-outline" title="No payment plans"
                      message="Active payment plans determine how each patient is billed." />
        </v-tabs-window-item>

        <!-- ── Payments tab ── -->
        <v-tabs-window-item value="payments">
          <div class="d-flex flex-wrap align-center ga-3 mb-4">
            <v-text-field v-model="paySearch" density="compact" variant="outlined" flat hide-details single-line
                          placeholder="Search patient or reference…" prepend-inner-icon="mdi-magnify" style="max-width: 280px;" />
            <v-select v-model="payMethod" :items="methodOptions" density="compact" variant="outlined" flat hide-details
                      single-line label="Method" style="max-width: 160px;" />
            <v-spacer />
            <v-btn variant="flat" rounded="pill" color="success" prepend-icon="mdi-cash-plus"
                   class="text-none" @click="openPayment()"><span class="font-weight-bold">Record Payment</span></v-btn>
            <v-btn variant="text" rounded="pill" color="teal" icon="mdi-refresh"
                   :loading="payLoading" @click="loadPayments" />
          </div>

          <v-data-table :headers="payHeaders" :items="filteredPayments" :loading="payLoading" item-value="id"
                        density="comfortable" hover :items-per-page="15" :items-per-page-options="[10, 15, 25, 50]">
            <template #item.patient_name="{ item }">
              <span class="font-weight-medium">{{ item.patient_name }}</span>
            </template>
            <template #item.bill_number="{ item }">
              <v-chip v-if="item.bill_number" size="small" variant="tonal" color="teal">{{ item.bill_number }}</v-chip>
              <span v-else class="text-medium-emphasis">—</span>
            </template>
            <template #item.amount="{ item }"><span class="font-weight-bold text-success">{{ money(item.amount, item.currency) }}</span></template>
            <template #item.method="{ item }">
              <v-chip size="small" variant="tonal" :color="methodColor(item.method)">
                <v-icon start :icon="methodIcon(item.method)" size="14" />{{ methodLabel(item.method) }}
              </v-chip>
            </template>
            <template #item.paid_at="{ item }">{{ formatDate(item.paid_at) }}</template>
            <template #no-data>
              <EmptyState icon="mdi-cash-remove" title="No payments recorded" />
            </template>
          </v-data-table>
        </v-tabs-window-item>
      </v-tabs-window>
    </v-card>

    <!-- Generate bill dialog -->
    <v-dialog v-model="genDialog" max-width="640">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon icon="mdi-file-plus" color="teal" class="mr-2" />Generate Bill
        </v-card-title>
        <v-card-subtitle class="pt-1 pb-2">Snapshot a patient's accrued charges into a bill.</v-card-subtitle>
        <v-card-text>
          <v-select v-model="genForm.patient" :items="patientOptions" item-title="name" item-value="id"
                    label="Patient" density="compact" :loading="genLoading" return-object
                    @update:model-value="onGenPatientChange" />
          <v-progress-linear v-if="genLoading" indeterminate color="teal" class="my-2" />
          <div v-if="genSummary" class="pb-preview mt-3">
            <div class="text-caption text-uppercase font-weight-bold text-medium-emphasis mb-2">Cost breakdown</div>
            <div class="d-flex flex-column ga-1">
              <div v-for="c in genCategories" :key="c.label" class="d-flex align-center">
                <v-icon :icon="c.icon" :color="c.color" size="18" class="mr-2" />
                <span class="text-body-2 flex-grow-1">{{ c.label }}</span>
                <span class="font-weight-medium text-body-2">{{ money(c.value, genSummary.currency) }}</span>
              </div>
              <v-divider class="my-1" />
              <div class="d-flex align-center">
                <span class="text-body-2 flex-grow-1 font-weight-bold">Subtotal</span>
                <span class="font-weight-bold">{{ money(genSummary.subtotal, genSummary.currency) }}</span>
              </div>
              <div class="d-flex align-center">
                <span class="text-body-2 flex-grow-1">Total paid (to date)</span>
                <span class="text-success">{{ money(genSummary.total_paid, genSummary.currency) }}</span>
              </div>
              <div class="d-flex align-center">
                <span class="text-body-2 flex-grow-1 font-weight-bold text-error">Balance</span>
                <span class="font-weight-bold text-error">{{ money(genSummary.balance, genSummary.currency) }}</span>
              </div>
            </div>
          </div>
          <v-row dense class="mt-1">
            <v-col cols="6"><v-text-field v-model.number="genForm.discount" label="Discount (KSh)" type="number" prefix="KSh" density="compact" /></v-col>
            <v-col cols="6"><v-text-field v-model.number="genForm.tax" label="Tax (KSh)" type="number" prefix="KSh" density="compact" /></v-col>
          </v-row>
          <div class="d-flex align-center justify-space-between pa-3 rounded-lg mt-1 pb-gen-total">
            <span class="font-weight-bold">Bill total</span>
            <span class="text-h6 font-weight-bold text-teal-darken-2">{{ money(genTotal, genSummary?.currency) }}</span>
          </div>
          <v-textarea v-model="genForm.notes" label="Notes" rows="2" density="compact" class="mt-2" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="genDialog = false">Cancel</v-btn>
          <v-btn color="teal" variant="flat" :loading="genSaving" :disabled="!genForm.patient" @click="submitGenerateBill">Generate bill</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Bill settings dialog -->
    <v-dialog v-model="settingsDialog" max-width="560">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon icon="mdi-cog-outline" color="indigo" class="mr-2" />Bill Settings
        </v-card-title>
        <v-card-subtitle class="pt-1 pb-2">
          Choose how often a patient's bills are auto-generated from their active care plans.
        </v-card-subtitle>
        <v-card-text>
          <v-select v-model="settingsForm.patient" :items="patientOptions" item-title="label" item-value="id"
                    label="Patient" density="compact" placeholder="Select a patient…"
                    :loading="settingsPatientLoading"
                    :disabled="settingsSaving"
                    class="mb-2"
                    @update:model-value="onSettingsPatientChange" />
          <template v-if="settingsForm.patient">
            <div class="text-caption text-uppercase font-weight-bold text-medium-emphasis mb-2">Billing type</div>
            <v-item-group v-model="settingsForm.billingType" mandatory>
              <v-row dense>
                <v-col v-for="opt in billingTypeOptions" :key="opt.value" cols="6">
                  <v-item v-slot="{ isSelected, toggle }" :value="opt.value">
                    <v-card @click="toggle" rounded="lg" variant="outlined"
                            :color="isSelected ? 'indigo' : undefined"
                            :class="{ 'pb-bt--active': isSelected }" class="pa-3 d-flex align-center">
                      <v-icon :icon="opt.icon" :color="isSelected ? 'indigo' : 'medium-emphasis'" class="mr-3" />
                      <div class="flex-grow-1">
                        <div class="font-weight-bold" :class="isSelected ? 'text-indigo-darken-2' : ''">{{ opt.title }}</div>
                        <div class="text-caption text-medium-emphasis">{{ opt.hint }}</div>
                      </div>
                      <v-icon v-if="isSelected" icon="mdi-check-circle" color="indigo" />
                    </v-card>
                  </v-item>
                </v-col>
              </v-row>
            </v-item-group>

            <v-alert v-if="settingsForm.billingType === 'manually'" type="info" variant="tonal" density="compact"
                     class="mt-3" icon="mdi-information-outline">
              Bills will not be generated automatically. Use “Generate Bill” to create them on demand.
            </v-alert>

            <v-switch v-model="settingsForm.autoGenerate" label="Enable automatic generation"
                      color="indigo" density="compact" hide-details class="mt-3"
                      :disabled="settingsForm.billingType === 'manually'" />

            <div v-if="settingsObj?.last_run_at" class="text-caption text-medium-emphasis mt-2">
              <v-icon icon="mdi-clock-check-outline" size="14" class="mr-1" />
              Last auto-generation: {{ formatDate(settingsObj.last_run_at) }}
            </div>
          </template>
          <v-alert v-else type="info" variant="tonal" density="compact"
                   icon="mdi-account-arrow-left" class="mt-1">
            Select a patient to view or change their individual billing type.
          </v-alert>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="settingsDialog = false">Cancel</v-btn>
          <v-btn color="indigo" variant="flat" :loading="settingsSaving" :disabled="!settingsForm.patient" @click="submitSettings">Save settings</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Record payment dialog -->
    <v-dialog v-model="payDialog" max-width="560">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon icon="mdi-cash-plus" color="success" class="mr-2" />Record Payment
        </v-card-title>
        <v-card-subtitle class="pt-1 pb-2">
          <span v-if="payForm.billId">Against bill <span class="font-weight-bold text-teal-darken-2">{{ payForm.billNumber }}</span> · Balance <span class="font-weight-bold text-error">{{ money(payForm.balance) }}</span></span>
          <span v-else>Apply to a bill or leave blank to auto-apply to the oldest open bill.</span>
        </v-card-subtitle>
        <v-card-text>
          <v-select v-if="!payForm.lockPatient" v-model="payForm.patientId" :items="patientOptions" item-title="name" item-value="id"
                    label="Patient" density="compact" @update:model-value="refreshBillOptions" />
          <v-select v-model="payForm.billId" :items="payBillOptions" item-title="label" item-value="id"
                    label="Apply to bill (optional)" density="compact" clearable class="mt-3" />
          <v-text-field v-model.number="payForm.amount" label="Amount (KSh)" type="number" prefix="KSh" density="compact" class="mt-3" />
          <v-row dense>
            <v-col cols="6"><v-select v-model="payForm.method" :items="payMethodOptions" label="Method" density="compact" /></v-col>
            <v-col cols="6"><v-text-field v-model="payForm.paidAt" label="Paid at" type="datetime-local" density="compact" /></v-col>
          </v-row>
          <v-text-field v-model="payForm.reference" label="Reference (e.g. M-Pesa code)" density="compact" class="mt-3" />
          <v-textarea v-model="payForm.notes" label="Notes" rows="2" density="compact" class="mt-3" />
          <v-btn v-if="payForm.balance > 0" size="small" variant="text" color="success" class="px-0 mt-1"
                 @click="payForm.amount = payForm.balance">Pay full balance</v-btn>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="payDialog = false">Cancel</v-btn>
          <v-btn color="success" variant="flat" :loading="paySaving" @click="submitPayment">Record payment</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Payment plan dialog -->
    <v-dialog v-model="planDialog" max-width="600">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon icon="mdi-calendar-cash" color="purple" class="mr-2" />{{ planForm.editId ? 'Change Payment Plan' : 'New Payment Plan' }}
        </v-card-title>
        <v-card-text>
          <v-select v-model="planForm.patientId" :items="patientOptions" item-title="name" item-value="id"
                    label="Patient" density="compact" />
          <v-select v-model="planForm.planType" :items="planTypeOptions" item-title="title" item-value="value"
                    label="Plan type" density="compact" class="mt-3" />
          <v-row dense class="mt-1">
            <v-col cols="6"><v-text-field v-model.number="planForm.rate" label="Rate (KSh)" type="number" prefix="KSh" density="compact" /></v-col>
            <v-col cols="6"><v-text-field v-model="planForm.currency" label="Currency" density="compact" /></v-col>
          </v-row>
          <v-row dense>
            <v-col cols="6"><v-text-field v-model="planForm.startDate" label="Start date" type="date" density="compact" /></v-col>
            <v-col cols="6"><v-text-field v-model="planForm.endDate" label="End date (optional)" type="date" density="compact" /></v-col>
          </v-row>
          <v-textarea v-model="planForm.notes" label="Notes" rows="2" density="compact" class="mt-3" />
          <v-switch v-model="planForm.autoBill" label="Auto-bill at end of each period" color="teal" density="compact" hide-details class="mt-1" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="planDialog = false">Cancel</v-btn>
          <v-btn color="purple" variant="flat" :loading="planSaving" :disabled="!planForm.patientId" @click="submitPlan">Save plan</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Bill detail dialog -->
    <v-dialog v-model="detailDialog" max-width="680">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon icon="mdi-receipt-text" color="teal" class="mr-2" />
          <span class="font-weight-bold">{{ detailItem?.bill_number }}</span>
          <StatusChip v-if="detailItem" :status="detailItem.status" class="ml-2" />
          <v-spacer />
          <v-btn v-if="detailItem && detailItem.status !== 'paid' && detailItem.status !== 'void'"
                 variant="text" color="success" prepend-icon="mdi-cash-plus" @click="openPayment(detailItem); detailDialog = false">Payment</v-btn>
          <v-btn variant="text" color="deep-purple" prepend-icon="mdi-download" @click="printBill(detailItem)">Download</v-btn>
        </v-card-title>
        <v-divider />
        <v-card-text v-if="detailItem" class="pt-4">
          <div class="d-flex flex-wrap ga-4 mb-3">
            <div><div class="text-caption text-medium-emphasis">Patient</div><div class="font-weight-medium">{{ detailItem.patient_name }}</div></div>
            <div><div class="text-caption text-medium-emphasis">Issued</div><div>{{ formatDate(detailItem.created_at) }}</div></div>
            <div><div class="text-caption text-medium-emphasis">Generated by</div><div>{{ detailItem.generated_by_name || '—' }}</div></div>
          </div>
          <v-table density="compact" class="bg-transparent">
            <tbody>
              <tr><td>Subtotal</td><td class="text-right">{{ money(detailItem.subtotal) }}</td></tr>
              <tr><td>Discount</td><td class="text-right text-success">−{{ money(detailItem.discount) }}</td></tr>
              <tr><td>Tax</td><td class="text-right">+{{ money(detailItem.tax) }}</td></tr>
              <tr><td class="font-weight-bold">Total</td><td class="text-right font-weight-bold text-teal-darken-2">{{ money(detailItem.total) }}</td></tr>
              <tr><td>Paid</td><td class="text-right text-success">{{ money(detailItem.amount_paid) }}</td></tr>
              <tr><td class="font-weight-bold">Balance</td><td class="text-right font-weight-bold" :class="detailItem.balance > 0 ? 'text-error' : ''">{{ money(detailItem.balance) }}</td></tr>
            </tbody>
          </v-table>
          <div class="text-caption text-uppercase font-weight-bold text-medium-emphasis mt-4 mb-2">Line items</div>
          <v-table v-if="(detailItem.line_items || []).length" density="compact" class="bg-transparent">
            <thead><tr><th class="text-left">Description</th><th class="text-right">Qty</th><th class="text-right">Rate</th><th class="text-right">Amount</th></tr></thead>
            <tbody>
              <tr v-for="(li, i) in detailItem.line_items" :key="i">
                <td>{{ li.label }}</td>
                <td class="text-right">{{ li.qty }}</td>
                <td class="text-right">{{ money(li.rate) }}</td>
                <td class="text-right font-weight-medium">{{ money(li.amount) }}</td>
              </tr>
            </tbody>
          </v-table>
          <EmptyState v-else icon="mdi-format-list-bulleted" title="No line items" dense />
          <div v-if="detailItem.notes" class="mt-3 text-body-2 text-medium-emphasis">
            <v-icon icon="mdi-note-text-outline" size="16" class="mr-1" />{{ detailItem.notes }}
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="detailDialog = false">Close</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <div ref="printArea" class="cc-print-area" style="display:none">
      <div v-if="printContent" class="print-document">
        <div class="print-top-accent" />

        <div class="print-header">
          <div class="print-provider-card">
            <div class="print-provider-brand">
              <img :src="printContent.providerLogo" alt="Homecare logo" class="print-provider-logo" />
              <div>
                <div class="print-eyebrow">Homecare Provider</div>
                <h1 class="print-provider-name">{{ printContent.providerName }}</h1>
                <p v-if="printContent.providerLocation" class="print-provider-sub">{{ printContent.providerLocation }}</p>
              </div>
            </div>
            <div class="print-provider-details">
              <div v-if="printContent.providerAddress">{{ printContent.providerAddress }}</div>
              <div v-if="printContent.providerPhone">{{ printContent.providerPhone }}</div>
              <div v-if="printContent.providerEmail">{{ printContent.providerEmail }}</div>
            </div>
          </div>

          <div class="print-platform-card">
            <div class="print-platform-row">
              <img :src="printContent.platformLogo" alt="AdhereMed logo" class="print-platform-logo" />
              <div class="print-platform-copy">
                <div class="print-platform-name">{{ printContent.platformName }}</div>
                <div class="print-platform-email">{{ printContent.platformEmail }}</div>
              </div>
            </div>
            <div class="print-doc-chip">{{ printContent.title || 'Statement' }}</div>
          </div>
        </div>

        <div class="print-meta-grid">
          <div class="print-meta-card">
            <div class="print-card-title">Patient Details</div>
            <div class="print-detail-grid">
              <div class="print-detail-item">
                <span class="print-detail-label">Patient</span>
                <span class="print-detail-value">{{ printContent.patientName }}</span>
              </div>
              <div class="print-detail-item" v-if="printContent.patientMrn">
                <span class="print-detail-label">MRN</span>
                <span class="print-detail-value">{{ printContent.patientMrn }}</span>
              </div>
            </div>
          </div>

          <div class="print-meta-card">
            <div class="print-card-title">Document Details</div>
            <div class="print-detail-grid">
              <div class="print-detail-item">
                <span class="print-detail-label">Date</span>
                <span class="print-detail-value">{{ printContent.dateLabel }}</span>
              </div>
              <div class="print-detail-item" v-if="printContent.billNumber">
                <span class="print-detail-label">Bill Number</span>
                <span class="print-detail-value">{{ printContent.billNumber }}</span>
              </div>
              <div class="print-detail-item" v-if="printContent.status">
                <span class="print-detail-label">Status</span>
                <span class="print-detail-value" :style="{ color: printContent.statusColor, fontWeight: '700' }">{{ printContent.status }}</span>
              </div>
              <div class="print-detail-item" v-if="printContent.generatedBy">
                <span class="print-detail-label">Generated By</span>
                <span class="print-detail-value">{{ printContent.generatedBy }}</span>
              </div>
            </div>
          </div>
        </div>

        <div v-if="printContent.lineItems && printContent.lineItems.length" class="print-section print-section-spaced">
          <div class="print-section-head">
            <h3 class="print-section-title">Line Items</h3>
            <span class="print-section-caption">Detailed billable items and charges</span>
          </div>
          <table class="print-table">
            <thead>
              <tr><th>Description</th><th class="text-center">Qty</th><th class="text-right">Rate</th><th class="text-right">Amount</th></tr>
            </thead>
            <tbody>
              <tr v-for="(li, i) in printContent.lineItems" :key="i">
                <td>{{ li.label }}</td>
                <td class="text-center">{{ li.qty }} {{ li.unit || '' }}</td>
                <td class="text-right">{{ li.rate || '—' }}</td>
                <td class="text-right">{{ li.amount }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div v-if="printContent.payments && printContent.payments.length" class="print-section print-section-spaced">
          <div class="print-section-head">
            <h3 class="print-section-title">Payments</h3>
            <span class="print-section-caption">Recorded payments against this bill</span>
          </div>
          <table class="print-table">
            <thead>
              <tr><th>Method</th><th class="text-right">Amount</th><th>Reference</th><th>Date</th></tr>
            </thead>
            <tbody>
              <tr v-for="(p, i) in printContent.payments" :key="i">
                <td>{{ p.method }}</td>
                <td class="text-right">{{ p.amount }}</td>
                <td>{{ p.reference }}</td>
                <td>{{ p.date }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="print-bottom-row">
          <div class="print-note-card">
            <div class="print-card-title">Notes</div>
            <p class="print-note-copy">{{ printContent.notes || 'This billing document was generated from the AdhereMed homecare command centre.' }}</p>
          </div>

          <div class="print-summary-card">
            <div class="print-card-title">Financial Summary</div>
            <table class="print-summary-table">
              <tbody>
                <tr v-for="(r, i) in printContent.summary" :key="i" :class="{ 'print-summary-total': r.bold }">
                  <td class="print-summary-label">{{ r.label }}</td>
                  <td class="print-summary-value" :style="r.color ? 'color:' + r.color : ''">{{ r.value }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div class="print-footer">
          <p>{{ printContent.footer || '' }}</p>
          <p class="print-footer-powered">Powered by AdhereMed · info@adheremed.co</p>
        </div>
      </div>
    </div>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2600">{{ snack.text }}</v-snackbar>
  </div>
</template>

<script setup>
import { formatDate, formatMoney } from '~/utils/format'
import adhereMedLogoUrl from '~/assets/images/logo.png'
import defaultLogoUrl from '~/assets/images/hos_default.png'

const { $api } = useNuxtApp()
const auth = useAuthStore()

const tab = ref('bills')
const loading = ref(false)
const planLoading = ref(false)
const payLoading = ref(false)
const snack = reactive({ show: false, text: '', color: 'info' })

// ── Bills ──
const bills = ref([])
const billSearch = ref('')
const billStatus = ref('all')

const billHeaders = [
  { key: 'data-table-expand', title: '' },
  { title: 'Bill #', key: 'bill_number' },
  { title: 'Patient', key: 'patient_name' },
  { title: 'Total', key: 'total', align: 'end' },
  { title: 'Paid', key: 'amount_paid', align: 'end' },
  { title: 'Balance', key: 'balance', align: 'end' },
  { title: 'Status', key: 'status' },
  { title: 'Issued', key: 'created_at' },
  { title: '', key: 'actions', align: 'end', sortable: false },
]

const filteredBills = computed(() => {
  let list = bills.value
  const q = billSearch.value.trim().toLowerCase()
  if (q) {
    list = list.filter(b =>
      (b.bill_number || '').toLowerCase().includes(q) ||
      (b.patient_name || '').toLowerCase().includes(q))
  }
  if (billStatus.value !== 'all') {
    if (billStatus.value === 'overdue') {
      list = list.filter(b => b.balance > 0 && b.status !== 'paid' && b.status !== 'void')
    } else {
      list = list.filter(b => b.status === billStatus.value)
    }
  }
  return list
})

const kpis = computed(() => {
  let billed = 0, collected = 0, outstanding = 0, paidCount = 0, overdueCount = 0
  for (const b of bills.value) {
    if (b.status === 'void') continue
    billed += Number(b.total) || 0
    collected += Number(b.amount_paid) || 0
    if (b.status !== 'paid') {
      outstanding += Number(b.balance) || 0
      if (Number(b.balance) > 0) overdueCount++
    } else paidCount++
  }
  return {
    billed, collected, outstanding, paidCount, overdueCount,
    rate: billed ? Math.round(collected / billed * 100) : 0,
  }
})

// ── Payment plans ──
const plans = ref([])
const planSearch = ref('')
const planFilter = ref('active')

const filteredPlans = computed(() => {
  let list = plans.value
  if (planFilter.value === 'active') list = list.filter(p => p.is_active)
  else if (planFilter.value === 'inactive') list = list.filter(p => !p.is_active)
  const q = planSearch.value.trim().toLowerCase()
  if (q) {
    list = list.filter(p =>
      (p.patient_name || '').toLowerCase().includes(q) ||
      (p.plan_type_label || '').toLowerCase().includes(q))
  }
  return list
})

function planProgress(p) {
  const exp = Number(p.expected_cost) || 0
  const acc = Number(p.accrued_cost) || 0
  if (!exp) return p.is_active ? 100 : 0
  return Math.min(100, Math.round(acc / exp * 100))
}

// ── Payments ──
const payments = ref([])
const paySearch = ref('')
const payMethod = ref('all')

const payHeaders = [
  { title: 'Patient', key: 'patient_name' },
  { title: 'Bill #', key: 'bill_number' },
  { title: 'Amount', key: 'amount', align: 'end' },
  { title: 'Method', key: 'method' },
  { title: 'Reference', key: 'reference' },
  { title: 'Paid', key: 'paid_at' },
]

const methodOptions = [
  { title: 'All methods', value: 'all' },
  { title: 'Cash', value: 'cash' },
  { title: 'M-Pesa', value: 'mpesa' },
  { title: 'Card', value: 'card' },
  { title: 'Bank Transfer', value: 'bank' },
  { title: 'Insurance', value: 'insurance' },
  { title: 'Other', value: 'other' },
]

const filteredPayments = computed(() => {
  let list = payments.value
  if (payMethod.value !== 'all') list = list.filter(p => p.method === payMethod.value)
  const q = paySearch.value.trim().toLowerCase()
  if (q) {
    list = list.filter(p =>
      (p.patient_name || '').toLowerCase().includes(q) ||
      (p.reference || '').toLowerCase().includes(q) ||
      (p.bill_number || '').toLowerCase().includes(q))
  }
  return list
})

// ── Helpers ──
function money(v, cur = 'KES') { return formatMoney(v, cur) }

const billCategories = b => [
  { label: 'Care', value: b.care_total, icon: 'mdi-hand-heart-outline', color: 'teal' },
  { label: 'Equipment', value: b.equipment_total, icon: 'mdi-devices', color: 'cyan' },
  { label: 'Supplies', value: b.supplies_total, icon: 'mdi-package-variant', color: 'purple' },
  { label: 'Medication', value: b.medication_total, icon: 'mdi-pill', color: 'green' },
]

function lineItemIcon(kind) {
  return ({ care: 'mdi-hand-heart-outline', equipment: 'mdi-devices',
           supply: 'mdi-package-variant', medication: 'mdi-pill' })[kind] || 'mdi-circle-medium'
}

const planIcons = {
  hourly: 'mdi-clock-outline', daily: 'mdi-calendar-today', weekly: 'mdi-calendar-week',
  monthly: 'mdi-calendar-month', per_visit: 'mdi-account-check-outline',
  day_time: 'mdi-weather-sunny', night_time: 'mdi-weather-night',
}
function planIcon(t) { return planIcons[t] || 'mdi-calendar-cash' }
function planColor(t) {
  return ({ hourly: 'amber', daily: 'teal', weekly: 'indigo', monthly: 'blue',
           per_visit: 'purple', day_time: 'orange', night_time: 'deep-purple' })[t] || 'teal'
}

const methodMeta = {
  cash: { label: 'Cash', icon: 'mdi-cash', color: 'success' },
  mpesa: { label: 'M-Pesa', icon: 'mdi-cellphone', color: 'green' },
  card: { label: 'Card', icon: 'mdi-credit-card', color: 'blue' },
  bank: { label: 'Bank', icon: 'mdi-bank', color: 'indigo' },
  insurance: { label: 'Insurance', icon: 'mdi-shield-account', color: 'deep-orange' },
  other: { label: 'Other', icon: 'mdi-help-circle', color: 'grey' },
}
function methodLabel(m) { return methodMeta[m]?.label || m }
function methodIcon(m) { return methodMeta[m]?.icon || 'mdi-cash' }
function methodColor(m) { return methodMeta[m]?.color || 'grey' }

// ── Patients (for selectors) ──
const patients = ref([])
const patientOptions = computed(() => patients.value.map(p => {
  const name = p.patient_name || p.user?.full_name || `Patient #${p.id}`
  const adId = p.adheremed_patient_id
  return { id: p.id, name, adheremedId: adId, label: adId ? `${name} · ${adId}` : name }
}))

async function loadPatients() {
  try {
    const { data } = await $api.get('/homecare/patients/')
    patients.value = data?.results || data || []
  } catch { patients.value = [] }
}

const payMethodOptions = methodOptions.filter(o => o.value !== 'all')
const planTypeOptions = [
  { title: 'Hourly', value: 'hourly' },
  { title: 'Daily', value: 'daily' },
  { title: 'Weekly', value: 'weekly' },
  { title: 'Monthly', value: 'monthly' },
  { title: 'Per Visit', value: 'per_visit' },
  { title: 'Day Shift', value: 'day_time' },
  { title: 'Night Shift', value: 'night_time' },
]

// ── Generate bill ──
const genDialog = ref(false)
const genLoading = ref(false)
const genSaving = ref(false)
const genSummary = ref(null)
const genForm = reactive({ patient: null, discount: 0, tax: 0, notes: '' })

function openGenerateBill() {
  genForm.patient = null; genForm.discount = 0; genForm.tax = 0; genForm.notes = ''
  genSummary.value = null
  if (!patients.value.length) loadPatients()
  genDialog.value = true
}

async function onGenPatientChange(patient) {
  if (!patient?.id) { genSummary.value = null; return }
  genLoading.value = true
  try {
    const { data } = await $api.get(`/homecare/patients/${patient.id}/care-summary/`)
    genSummary.value = data
  } catch {
    snack.text = 'Failed to load patient care summary'; snack.color = 'error'; snack.show = true
    genSummary.value = null
  } finally { genLoading.value = false }
}

const genCategories = computed(() => {
  const s = genSummary.value
  if (!s) return []
  return [
    { label: 'Care', value: s.care_total, icon: 'mdi-hand-heart-outline', color: 'teal' },
    { label: 'Equipment', value: s.equipment_total, icon: 'mdi-devices', color: 'cyan' },
    { label: 'Supplies', value: s.supplies_total, icon: 'mdi-package-variant', color: 'purple' },
    { label: 'Medication', value: s.medication_total, icon: 'mdi-pill', color: 'green' },
  ]
})
const genTotal = computed(() => {
  const s = genSummary.value
  if (!s) return 0
  return Math.max(Number(s.subtotal || 0) - Number(genForm.discount || 0) + Number(genForm.tax || 0), 0)
})

async function submitGenerateBill() {
  if (!genForm.patient?.id) return
  genSaving.value = true
  try {
    await $api.post(`/homecare/patients/${genForm.patient.id}/generate-bill/`, {
      discount: genForm.discount, tax: genForm.tax, notes: genForm.notes,
    })
    snack.text = 'Bill generated successfully'; snack.color = 'success'; snack.show = true
    genDialog.value = false
    loadBills()
  } catch (e) {
    snack.text = 'Failed to generate bill: ' + (e?.response?.data?.detail || e.message); snack.color = 'error'; snack.show = true
  } finally { genSaving.value = false }
}

// ── Bill settings ──
const billingTypeOptions = [
  { title: 'Daily', value: 'daily', icon: 'mdi-calendar-today', hint: 'Bills generated every day' },
  { title: 'Weekly', value: 'weekly', icon: 'mdi-calendar-week', hint: 'Every 7 days' },
  { title: 'Monthly', value: 'monthly', icon: 'mdi-calendar-month', hint: 'Every 30 days' },
  { title: 'Quarterly', value: 'quarterly', icon: 'mdi-calendar-clock', hint: 'Every 90 days' },
  { title: 'Yearly', value: 'yearly', icon: 'mdi-calendar-star', hint: 'Every 365 days' },
  { title: 'Manually', value: 'manually', icon: 'mdi-hand-back-right', hint: 'No auto-generation' },
]
const settingsDialog = ref(false)
const settingsSaving = ref(false)
const settingsPatientLoading = ref(false)
const settingsObj = ref(null)
const settingsForm = reactive({ patient: null, billingType: 'daily', autoGenerate: true })

const billingTypeLabel = computed(() => {
  const s = settingsObj.value
  if (!s) return 'Auto-bill'
  if (!s.is_auto_enabled) return 'Manual'
  return (billingTypeOptions.find(o => o.value === s.billing_type)?.title) || s.billing_type_label || 'Auto-bill'
})

async function loadSettings(patientId) {
  if (!patientId) { settingsObj.value = null; return }
  settingsPatientLoading.value = true
  try {
    const { data } = await $api.get('/homecare/billing-settings/', { params: { patient: patientId } })
    settingsObj.value = data
  } catch {
    settingsObj.value = null
    snack.text = 'Failed to load patient billing settings'; snack.color = 'error'; snack.show = true
  } finally { settingsPatientLoading.value = false }
}

function openSettingsDialog() {
  settingsForm.patient = null
  settingsForm.billingType = 'daily'
  settingsForm.autoGenerate = true
  settingsObj.value = null
  if (!patients.value.length) loadPatients()
  settingsDialog.value = true
}

async function onSettingsPatientChange(patientId) {
  settingsObj.value = null
  if (!patientId) return
  await loadSettings(patientId)
  const s = settingsObj.value || {}
  settingsForm.billingType = s.billing_type || 'daily'
  settingsForm.autoGenerate = s.billing_type === 'manually' ? false : (s.auto_generate ?? true)
}

async function submitSettings() {
  if (!settingsForm.patient) return
  settingsSaving.value = true
  try {
    const { data } = await $api.put('/homecare/billing-settings/', {
      patient: settingsForm.patient,
      billing_type: settingsForm.billingType,
      auto_generate: settingsForm.billingType === 'manually' ? false : settingsForm.autoGenerate,
    })
    settingsObj.value = data
    snack.text = 'Bill settings saved'; snack.color = 'success'; snack.show = true
    settingsDialog.value = false
  } catch (e) {
    snack.text = 'Failed to save settings: ' + (e?.response?.data?.detail || e.message); snack.color = 'error'; snack.show = true
  } finally { settingsSaving.value = false }
}

// ── Record payment ──
const payDialog = ref(false)
const paySaving = ref(false)
const payForm = reactive({
  patientId: null, billId: null, billNumber: '', balance: 0, amount: 0,
  method: 'cash', reference: '', paidAt: '', notes: '', lockPatient: false,
})
const payBillOptions = ref([])

function openPayment(bill) {
  if (bill) {
    payForm.patientId = bill.patient
    payForm.billId = bill.id
    payForm.billNumber = bill.bill_number
    payForm.balance = Number(bill.balance) || 0
    payForm.lockPatient = true
    payBillOptions.value = [{ id: bill.id, label: `${bill.bill_number} · ${money(bill.balance)} bal` }]
  } else {
    payForm.patientId = null
    payForm.billId = null
    payForm.billNumber = ''
    payForm.balance = 0
    payForm.lockPatient = false
    payBillOptions.value = []
  }
  payForm.amount = 0
  payForm.method = 'cash'
  payForm.reference = ''
  payForm.notes = ''
  payForm.paidAt = new Date().toISOString().slice(0, 16)
  if (!patients.value.length) loadPatients()
  payDialog.value = true
}

async function refreshBillOptions() {
  payForm.billId = null
  if (!payForm.patientId) { payBillOptions.value = []; return }
  try {
    const { data } = await $api.get(`/homecare/patient-bills/?patient=${payForm.patientId}`)
    const list = data?.results || data || []
    payBillOptions.value = list
      .filter(b => b.status !== 'paid' && b.status !== 'void')
      .map(b => ({ id: b.id, label: `${b.bill_number} · ${money(b.balance)} bal` }))
  } catch { payBillOptions.value = [] }
}

async function submitPayment() {
  if (!payForm.amount || payForm.amount <= 0) {
    snack.text = 'Enter a valid amount'; snack.color = 'warning'; snack.show = true; return
  }
  if (!payForm.patientId) {
    snack.text = 'Select a patient'; snack.color = 'warning'; snack.show = true; return
  }
  paySaving.value = true
  try {
    await $api.post('/homecare/patient-payments/', {
      patient: payForm.patientId,
      amount: payForm.amount,
      method: payForm.method,
      reference: payForm.reference,
      paid_at: payForm.paidAt || new Date().toISOString(),
      notes: payForm.notes,
      bill: payForm.billId || undefined,
    })
    snack.text = 'Payment recorded'; snack.color = 'success'; snack.show = true
    payDialog.value = false
    loadBills(); loadPayments()
  } catch (e) {
    snack.text = 'Failed to record payment: ' + (e?.response?.data?.detail || e.message); snack.color = 'error'; snack.show = true
  } finally { paySaving.value = false }
}

// ── Payment plan ──
const planDialog = ref(false)
const planSaving = ref(false)
const planForm = reactive({ editId: null, patientId: null, planType: 'daily', rate: null, currency: 'KES', startDate: '', endDate: '', notes: '', autoBill: true })

function openPlanDialog(plan) {
  if (plan) {
    planForm.editId = plan.id
    planForm.patientId = plan.patient
    planForm.planType = plan.plan_type
    planForm.rate = plan.rate
    planForm.currency = plan.currency || 'KES'
    planForm.startDate = plan.start_date || ''
    planForm.endDate = plan.end_date || ''
    planForm.notes = plan.notes || ''
    planForm.autoBill = plan.auto_bill
  } else {
    planForm.editId = null
    planForm.patientId = null
    planForm.planType = 'daily'
    planForm.rate = null
    planForm.currency = 'KES'
    planForm.startDate = new Date().toISOString().slice(0, 10)
    planForm.endDate = ''
    planForm.notes = ''
    planForm.autoBill = true
  }
  if (!patients.value.length) loadPatients()
  planDialog.value = true
}

async function submitPlan() {
  if (!planForm.patientId) { snack.text = 'Select a patient'; snack.color = 'warning'; snack.show = true; return }
  if (!planForm.rate && planForm.rate !== 0) { snack.text = 'Enter a rate'; snack.color = 'warning'; snack.show = true; return }
  planSaving.value = true
  try {
    await $api.post('/homecare/care-plans/', {
      patient: planForm.patientId,
      plan_type: planForm.planType,
      rate: planForm.rate,
      currency: planForm.currency || 'KES',
      start_date: planForm.startDate,
      end_date: planForm.endDate || null,
      is_active: true,
      notes: planForm.notes,
      auto_bill: planForm.autoBill,
    })
    snack.text = 'Payment plan saved'; snack.color = 'success'; snack.show = true
    planDialog.value = false
    loadPlans()
  } catch (e) {
    snack.text = 'Failed to save plan: ' + (e?.response?.data?.detail || e.message); snack.color = 'error'; snack.show = true
  } finally { planSaving.value = false }
}

async function toggleAutoBill(plan, next) {
  plan._toggling = true
  try {
    await $api.post(`/homecare/care-plans/${plan.id}/toggle-auto-bill/`, { auto_bill: next })
    plan.auto_bill = next
    snack.text = next ? 'Auto-bill enabled' : 'Auto-bill paused'; snack.color = 'success'; snack.show = true
  } catch {
    snack.text = 'Failed to toggle auto-bill'; snack.color = 'error'; snack.show = true
  } finally { plan._toggling = false }
}

// ── Bill detail ──
const detailDialog = ref(false)
const detailItem = ref(null)
function openBillDetail(bill) { detailItem.value = bill; detailDialog.value = true }

// ── Void ──
async function voidBill(bill) {
  try {
    await $api.post(`/homecare/patient-bills/${bill.id}/void/`)
    snack.text = `Bill ${bill.bill_number} voided`; snack.color = 'success'; snack.show = true
    loadBills()
  } catch {
    snack.text = 'Failed to void bill'; snack.color = 'error'; snack.show = true
  }
}

// ── PDF print ──
const printArea = ref(null)
const printContent = ref(null)
const companyProfile = ref(null)

function absoluteAssetUrl(url) {
  if (!url) return ''
  if (/^(https?:|data:|blob:)/i.test(url)) return url
  if (typeof window !== 'undefined') return new URL(url, window.location.origin).toString()
  return url
}
const facilityLogoUrl = computed(() => absoluteAssetUrl(companyProfile.value?.logo || defaultLogoUrl))
const facilityName = computed(() => auth.tenantName || companyProfile.value?.legal_name || 'AdhereMed Homecare')
const facilityEmail = computed(() => companyProfile.value?.contact_email || auth.user?.email || '')
const facilityPhone = computed(() => companyProfile.value?.contact_phone || '')
const facilityAddress = computed(() => companyProfile.value?.address || '')
const facilityLocation = computed(() => [companyProfile.value?.city, companyProfile.value?.country].filter(Boolean).join(', '))
const platformLogoUrl = computed(() => absoluteAssetUrl(adhereMedLogoUrl))

function buildPrintBase(title, dateLabel, extra) {
  return {
    providerLogo: facilityLogoUrl.value,
    providerName: facilityName.value,
    providerEmail: facilityEmail.value,
    providerPhone: facilityPhone.value,
    providerAddress: facilityAddress.value,
    providerLocation: facilityLocation.value,
    platformLogo: platformLogoUrl.value,
    platformName: 'AdhereMed',
    platformEmail: 'info@adheremed.co',
    title, dateLabel, ...extra,
  }
}

function printBill(bill) {
  if (!bill) return
  const items = (bill.line_items || []).map(li => ({
    label: li.label, qty: li.qty, unit: li.unit || '', rate: li.rate ? money(li.rate) : '—', amount: money(li.amount),
  }))
  const pays = (bill.payments || []).map(p => ({
    method: methodLabel(p.method), amount: money(p.amount), reference: p.reference || '—', date: formatDate(p.paid_at),
  }))
  const statusColor = bill.status === 'paid' ? '#16a34a' : bill.status === 'void' ? '#94a3b8' : '#d97706'
  printContent.value = buildPrintBase(`Bill ${bill.bill_number || ''}`, formatDate(bill.as_of || bill.created_at), {
    billNumber: bill.bill_number,
    status: bill.status_label || bill.status,
    statusColor,
    patientName: bill.patient_name || '—',
    patientMrn: bill.medical_record_number || '',
    summary: [
      ...(Number(bill.subtotal) > 0 ? [{ label: 'Subtotal', value: money(bill.subtotal) }] : []),
      ...(Number(bill.discount) > 0 ? [{ label: 'Discount', value: '-' + money(bill.discount), color: '#ef4444' }] : []),
      ...(Number(bill.tax) > 0 ? [{ label: 'Tax', value: money(bill.tax) }] : []),
      { label: 'Total', value: money(bill.total), bold: true },
      { label: 'Paid', value: money(bill.amount_paid), color: '#16a34a' },
      { label: 'Balance', value: money(bill.balance), bold: true, color: Number(bill.balance) > 0 ? '#ef4444' : '#16a34a' },
    ],
    lineItems: items,
    payments: pays,
    notes: bill.notes || 'Please review the billed services and contact the homecare team for any clarification on charges.',
    generatedBy: bill.generated_by_name || '',
    footer: `Generated ${new Date().toLocaleString()} · ${facilityName.value}`,
  })
  nextTick(() => doPrint())
}

async function doPrint() {
  if (!printArea.value || !printContent.value) return
  const styleText = `
    * { box-sizing: border-box; margin: 0; padding: 0; }
    @page { size: A4; margin: 14mm; }
    body { font-family: 'Segoe UI', Arial, sans-serif; color: #1e293b; background: #e2e8f0; padding: 24px; }
    .print-document { max-width: 860px; margin: 0 auto; padding: 32px 36px 28px; background: #ffffff; border-radius: 24px; box-shadow: 0 28px 80px -36px rgba(15, 23, 42, 0.4); }
    .print-top-accent { height: 10px; border-radius: 999px; background: linear-gradient(90deg, #0f766e 0%, #14b8a6 45%, #0ea5e9 100%); margin-bottom: 24px; }
    .print-header { display: flex; justify-content: space-between; align-items: stretch; gap: 18px; margin-bottom: 20px; }
    .print-provider-card, .print-platform-card, .print-meta-card, .print-note-card, .print-summary-card { background: linear-gradient(180deg, #ffffff 0%, #f8fafc 100%); border: 1px solid #e2e8f0; border-radius: 20px; }
    .print-provider-card { flex: 1.3; padding: 20px; }
    .print-provider-brand { display: flex; align-items: center; gap: 14px; margin-bottom: 14px; }
    .print-provider-logo { width: 68px; height: 68px; border-radius: 18px; object-fit: cover; border: 1px solid #dbeafe; background: #ffffff; }
    .print-eyebrow { font-size: 10px; letter-spacing: 1.6px; text-transform: uppercase; color: #0f766e; font-weight: 700; margin-bottom: 4px; }
    .print-provider-name { font-size: 24px; font-weight: 800; color: #0f172a; line-height: 1.15; }
    .print-provider-sub { font-size: 12px; color: #64748b; margin-top: 4px; }
    .print-provider-details { display: grid; gap: 6px; font-size: 12px; color: #334155; }
    .print-platform-card { width: 250px; padding: 20px; display: flex; flex-direction: column; justify-content: space-between; align-items: flex-end; text-align: right; background: linear-gradient(180deg, #f8fffe 0%, #effcfb 100%); }
    .print-platform-row { display: flex; align-items: center; gap: 12px; }
    .print-platform-logo { width: 54px; height: 54px; object-fit: contain; }
    .print-platform-copy { text-align: right; }
    .print-platform-name { font-size: 22px; font-weight: 800; color: #0f766e; line-height: 1.1; }
    .print-platform-email { font-size: 12px; color: #475569; margin-top: 4px; }
    .print-doc-chip { margin-top: 18px; padding: 10px 14px; border-radius: 999px; background: #0f172a; color: #ffffff; font-size: 11px; font-weight: 700; letter-spacing: 1.2px; text-transform: uppercase; }
    .print-meta-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 18px; margin-bottom: 22px; }
    .print-meta-card { padding: 18px 20px; }
    .print-card-title { font-size: 11px; letter-spacing: 1.4px; text-transform: uppercase; color: #64748b; font-weight: 700; margin-bottom: 12px; }
    .print-detail-grid { display: grid; gap: 10px; }
    .print-detail-item { display: grid; gap: 2px; }
    .print-detail-label { font-size: 11px; color: #64748b; font-weight: 600; }
    .print-detail-value { font-size: 13px; color: #0f172a; font-weight: 600; line-height: 1.4; }
    .print-section { margin-bottom: 12px; }
    .print-section-spaced { margin-top: 10px; }
    .print-section-head { display: flex; justify-content: space-between; align-items: baseline; gap: 12px; margin-bottom: 10px; }
    .print-section-title { font-size: 13px; font-weight: 800; color: #0f172a; text-transform: uppercase; letter-spacing: 1px; }
    .print-section-caption { font-size: 11px; color: #64748b; }
    .print-table { width: 100%; border-collapse: separate; border-spacing: 0; font-size: 12px; overflow: hidden; border: 1px solid #e2e8f0; border-radius: 18px; }
    .print-table thead th { background: linear-gradient(180deg, #f8fafc 0%, #eef2f7 100%); padding: 11px 12px; text-align: left; font-weight: 700; color: #475569; border-bottom: 1px solid #dbe2ea; font-size: 11px; text-transform: uppercase; letter-spacing: 0.8px; }
    .print-table tbody td { padding: 10px 12px; border-bottom: 1px solid #eef2f7; }
    .print-table tbody tr:nth-child(even) { background: #fbfdff; }
    .print-table tbody tr:last-child td { border-bottom: none; }
    .text-center { text-align: center; }
    .text-right { text-align: right; }
    .print-bottom-row { display: grid; grid-template-columns: minmax(0, 1.1fr) minmax(280px, 0.9fr); gap: 18px; align-items: start; margin-top: 22px; }
    .print-note-card, .print-summary-card { padding: 18px 20px; min-height: 100%; }
    .print-note-copy { font-size: 12px; color: #475569; line-height: 1.7; }
    .print-summary-table { width: 100%; border-collapse: collapse; font-size: 13px; }
    .print-summary-table td { padding: 8px 0; border-bottom: 1px solid #e2e8f0; }
    .print-summary-label { font-weight: 600; color: #475569; text-align: left; padding-right: 16px; }
    .print-summary-value { font-weight: 700; text-align: right; }
    .print-summary-total td { font-size: 14px; padding: 12px 0; border-top: 2px solid #0f766e; border-bottom: 2px solid #0f766e; }
    .print-summary-total .print-summary-label { font-weight: 800; color: #0f172a; }
    .print-footer { text-align: center; margin-top: 26px; padding-top: 14px; border-top: 1px solid #e2e8f0; font-size: 10px; color: #94a3b8; }
    .print-footer-powered { font-size: 10px; color: #64748b; margin-top: 6px; letter-spacing: 0.4px; }
    @media (max-width: 780px) {
      body { padding: 0; background: #ffffff; }
      .print-document { padding: 18px; border-radius: 0; box-shadow: none; }
      .print-header, .print-meta-grid, .print-bottom-row { grid-template-columns: 1fr; display: grid; }
      .print-platform-card { width: 100%; align-items: flex-start; text-align: left; }
      .print-platform-copy { text-align: left; }
    }
    @media print { body { -webkit-print-color-adjust: exact; print-color-adjust: exact; } }
  `

  const source = printArea.value.querySelector('.print-document')
  if (!source) return

  const mount = document.createElement('div')
  mount.style.position = 'fixed'
  mount.style.left = '-20000px'
  mount.style.top = '0'
  mount.style.width = '860px'
  mount.style.zIndex = '-1'
  mount.style.background = '#e2e8f0'
  mount.style.padding = '24px'

  const styleEl = document.createElement('style')
  styleEl.textContent = styleText
  const clone = source.cloneNode(true)
  mount.appendChild(styleEl)
  mount.appendChild(clone)
  document.body.appendChild(mount)

  try {
    const [{ default: html2canvas }, { jsPDF }] = await Promise.all([
      import('html2canvas'),
      import('jspdf'),
    ])

    if (document.fonts?.ready) await document.fonts.ready
    const images = Array.from(mount.querySelectorAll('img'))
    await Promise.all(images.map((img) => {
      if (img.complete) return Promise.resolve()
      return new Promise((resolve) => {
        img.addEventListener('load', resolve, { once: true })
        img.addEventListener('error', resolve, { once: true })
      })
    }))

    const canvas = await html2canvas(clone, {
      scale: 2,
      useCORS: true,
      backgroundColor: '#e2e8f0',
      windowWidth: clone.scrollWidth,
    })

    const pdf = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' })
    const pageWidth = pdf.internal.pageSize.getWidth()
    const pageHeight = pdf.internal.pageSize.getHeight()
    const margin = 8
    const contentWidth = pageWidth - margin * 2
    const contentHeight = (canvas.height * contentWidth) / canvas.width
    const pageContentHeight = pageHeight - margin * 2
    const imageData = canvas.toDataURL('image/png')

    let heightLeft = contentHeight
    let position = margin
    pdf.addImage(imageData, 'PNG', margin, position, contentWidth, contentHeight, undefined, 'FAST')
    heightLeft -= pageContentHeight

    while (heightLeft > 0) {
      position -= pageContentHeight
      pdf.addPage()
      pdf.addImage(imageData, 'PNG', margin, position, contentWidth, contentHeight, undefined, 'FAST')
      heightLeft -= pageContentHeight
    }

    const fileName = (printContent.value.billNumber || 'bill').replace(/[^a-zA-Z0-9]+/g, '_').replace(/^_+|_+$/g, '') || 'bill'
    pdf.save(`${fileName}.pdf`)
  } catch (e) {
    snack.text = 'PDF export failed: ' + e.message; snack.color = 'error'; snack.show = true
  } finally {
    document.body.removeChild(mount)
  }
}

// ── Loaders ──
async function loadBills() {
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/patient-bills/')
    bills.value = data?.results || data || []
  } catch {
    snack.text = 'Failed to load bills'; snack.color = 'error'; snack.show = true
    bills.value = []
  } finally { loading.value = false }
}

async function loadPlans() {
  planLoading.value = true
  try {
    const { data } = await $api.get('/homecare/care-plans/')
    plans.value = data?.results || data || []
  } catch {
    snack.text = 'Failed to load payment plans'; snack.color = 'error'; snack.show = true
    plans.value = []
  } finally { planLoading.value = false }
}

async function loadPayments() {
  payLoading.value = true
  try {
    const { data } = await $api.get('/homecare/patient-payments/')
    payments.value = data?.results || data || []
  } catch {
    snack.text = 'Failed to load payments'; snack.color = 'error'; snack.show = true
    payments.value = []
  } finally { payLoading.value = false }
}

async function loadCompanyProfile() {
  try {
    const { data } = await $api.get('/homecare/company-profile/current/')
    companyProfile.value = data || null
  } catch {
    try {
      const { data } = await $api.get('/homecare/company-profile/')
      companyProfile.value = Array.isArray(data) ? (data[0] || null) : data
    } catch { companyProfile.value = null }
  }
}

onMounted(() => { loadBills(); loadPlans(); loadPayments(); loadPatients(); loadCompanyProfile() })
</script>

<style scoped>
.pb-bg {
  background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%);
  min-height: calc(100vh - 64px);
}
:global(.v-theme--dark .pb-bg) { background: linear-gradient(180deg, #0f172a 0%, #111827 100%); }

.pb-hero {
  background: linear-gradient(120deg, #0d9488 0%, #0891b2 45%, #6366f1 100%);
  position: relative;
  overflow: hidden;
}
.pb-hero-decor {
  position: absolute; top: -60px; right: -40px; width: 220px; height: 220px;
  border-radius: 50%; background: rgba(255,255,255,0.10);
}
.pb-hero-avatar {
  background: rgba(255,255,255,0.18);
  backdrop-filter: blur(12px);
  border: 1px solid rgba(255,255,255,0.25);
}

.pb-card { background: white; }
:global(.v-theme--dark .pb-card) { background: #1e293b; }

.pb-expand {
  padding: 16px 20px;
  background: rgba(13,148,136,0.04);
  border-left: 3px solid #0d9488;
  border-radius: 0 12px 12px 0;
}
:global(.v-theme--dark .pb-expand) { background: rgba(255,255,255,0.04); }

.pb-plan {
  background: white;
  border: 1px solid rgba(15,23,42,0.07);
  transition: transform 0.18s ease, box-shadow 0.18s ease;
}
.pb-plan:hover { transform: translateY(-3px); box-shadow: 0 16px 32px -18px rgba(13,148,136,0.4) !important; }
.pb-plan--inactive { opacity: 0.72; }
:global(.v-theme--dark .pb-plan) { background: #1e293b; border-color: rgba(255,255,255,0.08); }

.pb-pay { padding: 4px 0; }
.pb-preview { padding: 12px 16px; background: rgba(13,148,136,0.05); border-radius: 12px; }
:global(.v-theme--dark .pb-preview) { background: rgba(255,255,255,0.04); }
.pb-gen-total { background: rgba(13,148,136,0.08); }
:global(.v-theme--dark .pb-gen-total) { background: rgba(255,255,255,0.06); }

.pb-bt--active { border-width: 2px; background: rgba(99,102,241,0.06); }
:global(.v-theme--dark .pb-bt--active) { background: rgba(255,255,255,0.06); }
</style>
