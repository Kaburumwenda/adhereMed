<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Referral Management" icon="mdi-account-arrow-right" subtitle="Platform-wide referral program — profiles, referral chains & performance">
      <template #actions>
        <v-btn variant="tonal" prepend-icon="mdi-refresh" class="text-none" :loading="refreshing" @click="loadAll">
          Refresh
        </v-btn>
      </template>
    </PageHeader>

    <!-- KPI Strip -->
    <v-row dense class="mb-5">
      <v-col cols="6" sm="4" md="2">
        <v-card rounded="xl" class="kpi-card kpi-gradient-blue pa-4" elevation="0">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="primary" variant="tonal" rounded="lg" size="42">
              <v-icon size="22">mdi-account-group</v-icon>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis font-weight-medium text-uppercase">Profiles</div>
              <div class="text-h5 font-weight-black">{{ stats.total_profiles || 0 }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" sm="4" md="2">
        <v-card rounded="xl" class="kpi-card kpi-gradient-green pa-4" elevation="0">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="success" variant="tonal" rounded="lg" size="42">
              <v-icon size="22">mdi-link-variant</v-icon>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis font-weight-medium text-uppercase">Total Referrals</div>
              <div class="text-h5 font-weight-black">{{ stats.total_referrals || 0 }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" sm="4" md="2">
        <v-card rounded="xl" class="kpi-card kpi-gradient-amber pa-4" elevation="0">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="amber-darken-2" variant="tonal" rounded="lg" size="42">
              <v-icon size="22">mdi-check-circle</v-icon>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis font-weight-medium text-uppercase">Active</div>
              <div class="text-h5 font-weight-black">{{ stats.active_referrals || 0 }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" sm="4" md="2">
        <v-card rounded="xl" class="kpi-card kpi-gradient-purple pa-4" elevation="0">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="purple" variant="tonal" rounded="lg" size="42">
              <v-icon size="22">mdi-arrow-up-bold-circle</v-icon>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis font-weight-medium text-uppercase">Coins Earned</div>
              <div class="text-h5 font-weight-black">{{ Number(stats.total_coins_earned || 0).toLocaleString() }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" sm="4" md="2">
        <v-card rounded="xl" class="kpi-card kpi-gradient-red pa-4" elevation="0">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="error" variant="tonal" rounded="lg" size="42">
              <v-icon size="22">mdi-arrow-down-bold-circle</v-icon>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis font-weight-medium text-uppercase">Redeemed</div>
              <div class="text-h5 font-weight-black">{{ Number(stats.total_coins_redeemed || 0).toLocaleString() }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
      <v-col cols="6" sm="4" md="2">
        <v-card rounded="xl" class="kpi-card kpi-gradient-teal pa-4" elevation="0">
          <div class="d-flex align-center" style="gap:10px">
            <v-avatar color="teal" variant="tonal" rounded="lg" size="42">
              <v-icon size="22">mdi-chart-bar</v-icon>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis font-weight-medium text-uppercase">Avg/Tenant</div>
              <div class="text-h5 font-weight-black">{{ stats.avg_referrals_per_tenant || 0 }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- Tabs -->
    <v-card rounded="xl" elevation="0" class="mb-4" style="border:1px solid rgba(var(--v-border-color), 0.12)">
      <v-tabs v-model="tab" color="primary" density="comfortable" class="px-2 pt-1">
        <v-tab value="referrals" class="text-none">
          <v-icon start size="20">mdi-link-variant</v-icon> Referral Chains
        </v-tab>
        <v-tab value="profiles" class="text-none">
          <v-icon start size="20">mdi-account-group</v-icon> Profiles
        </v-tab>
        <v-tab value="history" class="text-none">
          <v-icon start size="20">mdi-history</v-icon> Earnings History
        </v-tab>
        <v-tab value="projections" class="text-none">
          <v-icon start size="20">mdi-chart-timeline-variant</v-icon> Monthly Projections
        </v-tab>
        <v-tab value="leaderboard" class="text-none">
          <v-icon start size="20">mdi-trophy</v-icon> Leaderboard
        </v-tab>
        <v-tab value="leaderboard" class="text-none">
          <v-icon start size="20">mdi-trophy</v-icon> Leaderboard
        </v-tab>
      </v-tabs>
    </v-card>

    <!-- Tab Content -->
    <v-window v-model="tab">
      <!-- REFERRAL CHAINS -->
      <v-window-item value="referrals">
        <v-card rounded="xl" elevation="0" style="border:1px solid rgba(var(--v-border-color), 0.12)">
          <v-card-title class="d-flex flex-wrap align-center pa-4" style="gap:10px">
            <v-icon class="mr-2" color="primary">mdi-link-variant</v-icon>
            All Referrals
            <v-chip size="small" variant="tonal" color="primary" class="ml-2">{{ referrals.length }}</v-chip>
            <v-spacer />
            <v-select
              v-model="statusFilter"
              :items="statusOptions"
              density="compact" variant="outlined" rounded="lg" hide-details
              style="max-width: 160px"
              prepend-inner-icon="mdi-filter-variant"
            />
            <v-text-field
              v-model="refSearch"
              density="compact" variant="outlined" rounded="lg" hide-details
              placeholder="Search..."
              prepend-inner-icon="mdi-magnify"
              style="max-width: 240px"
              clearable
            />
          </v-card-title>
          <v-divider />
          <v-progress-linear v-if="loadingRefs" indeterminate color="primary" />
          <v-data-table
            :headers="refHeaders"
            :items="filteredReferrals"
            :items-per-page="15"
            density="comfortable"
            hover
            class="ref-table"
          >
            <template #item.referrer_name="{ item }">
              <div class="d-flex align-center py-1" style="gap:8px">
                <v-avatar :color="tenantColor(item.referrer)" variant="tonal" rounded="lg" size="34">
                  <span class="text-caption font-weight-bold">{{ (item.referrer_name || '?')[0] }}</span>
                </v-avatar>
                <div>
                  <div class="font-weight-medium">{{ item.referrer_name }}</div>
                  <div class="text-caption text-medium-emphasis">{{ item.referrer_type }}</div>
                </div>
              </div>
            </template>
            <template #item.referred_name="{ item }">
              <div class="d-flex align-center py-1" style="gap:8px">
                <v-avatar :color="tenantColor(item.referred)" variant="tonal" rounded="lg" size="34">
                  <span class="text-caption font-weight-bold">{{ (item.referred_name || '?')[0] }}</span>
                </v-avatar>
                <div>
                  <div class="font-weight-medium">{{ item.referred_name }}</div>
                  <div class="text-caption text-medium-emphasis">{{ item.referred_type }}</div>
                </div>
              </div>
            </template>
            <template #item.status="{ item }">
              <v-chip :color="statusColor(item.status)" variant="tonal" size="small" class="font-weight-bold text-uppercase">
                <v-icon start size="14">{{ statusIcon(item.status) }}</v-icon>
                {{ item.status }}
              </v-chip>
            </template>
            <template #item.bonus_awarded="{ item }">
              <v-icon :color="item.bonus_awarded ? 'success' : 'grey'" size="20">
                {{ item.bonus_awarded ? 'mdi-check-circle' : 'mdi-close-circle' }}
              </v-icon>
            </template>
            <template #item.coins_from_usage="{ item }">
              <span class="font-weight-medium">{{ Number(item.coins_from_usage).toLocaleString() }}</span>
            </template>
            <template #item.created_at="{ item }">
              <span class="text-medium-emphasis">{{ formatDate(item.created_at) }}</span>
            </template>
            <template #item.actions="{ item }">
              <v-btn icon="mdi-pencil" variant="text" size="small" @click="openEditReferral(item)" />
            </template>
          </v-data-table>
        </v-card>
      </v-window-item>

      <!-- PROFILES -->
      <v-window-item value="profiles">
        <v-card rounded="xl" elevation="0" style="border:1px solid rgba(var(--v-border-color), 0.12)">
          <v-card-title class="d-flex flex-wrap align-center pa-4" style="gap:10px">
            <v-icon class="mr-2" color="primary">mdi-account-group</v-icon>
            Referral Profiles
            <v-chip size="small" variant="tonal" color="primary" class="ml-2">{{ profiles.length }}</v-chip>
            <v-spacer />
            <v-text-field
              v-model="profileSearch"
              density="compact" variant="outlined" rounded="lg" hide-details
              placeholder="Search tenant or code..."
              prepend-inner-icon="mdi-magnify"
              style="max-width: 280px"
              clearable
            />
          </v-card-title>
          <v-divider />
          <v-progress-linear v-if="loadingProfiles" indeterminate color="primary" />
          <v-data-table
            :headers="profileHeaders"
            :items="filteredProfiles"
            :items-per-page="15"
            density="comfortable"
            hover
            class="ref-table"
          >
            <template #item.tenant_name="{ item }">
              <div class="d-flex align-center py-1" style="gap:8px">
                <v-avatar :color="tenantColor(item.tenant)" variant="tonal" rounded="lg" size="34">
                  <span class="text-caption font-weight-bold">{{ (item.tenant_name || '?')[0] }}</span>
                </v-avatar>
                <div>
                  <div class="font-weight-medium">{{ item.tenant_name }}</div>
                  <div class="text-caption text-medium-emphasis">{{ item.tenant_type }}</div>
                </div>
              </div>
            </template>
            <template #item.referral_code="{ item }">
              <div class="d-flex align-center" style="gap:6px">
                <v-chip color="primary" variant="flat" size="small" class="font-weight-bold font-mono">
                  {{ item.referral_code }}
                </v-chip>
                <v-btn icon="mdi-content-copy" variant="text" size="x-small" @click="copyCode(item.referral_code)" />
              </div>
            </template>
            <template #item.coin_balance="{ item }">
              <v-chip :color="Number(item.coin_balance) > 0 ? 'amber-darken-2' : 'grey'" variant="flat" size="small" class="font-weight-bold">
                {{ Number(item.coin_balance).toLocaleString() }} KES
              </v-chip>
            </template>
            <template #item.total_earned="{ item }">
              <span class="text-success font-weight-medium">+{{ Number(item.total_earned).toLocaleString() }}</span>
            </template>
            <template #item.total_redeemed="{ item }">
              <span class="text-error font-weight-medium">-{{ Number(item.total_redeemed).toLocaleString() }}</span>
            </template>
            <template #item.referral_count="{ item }">
              <v-chip v-if="item.referral_count > 0" color="success" variant="tonal" size="small">
                {{ item.referral_count }}
              </v-chip>
              <span v-else class="text-medium-emphasis">0</span>
            </template>
            <template #item.tenant_is_active="{ item }">
              <v-icon :color="item.tenant_is_active ? 'success' : 'error'" size="20">
                {{ item.tenant_is_active ? 'mdi-check-circle' : 'mdi-close-circle' }}
              </v-icon>
            </template>
            <template #item.actions="{ item }">
              <v-btn icon="mdi-refresh" variant="text" size="small" color="primary" title="Regenerate code" @click="confirmRegenerate(item)" />
            </template>
          </v-data-table>
        </v-card>
      </v-window-item>

      <!-- EARNINGS HISTORY -->
      <v-window-item value="history">
        <v-card rounded="xl" elevation="0" style="border:1px solid rgba(var(--v-border-color), 0.12)">
          <v-card-title class="d-flex flex-wrap align-center pa-4" style="gap:10px">
            <v-icon class="mr-2" color="primary">mdi-history</v-icon>
            Coins Earned from Each Referred Tenant
            <v-chip size="small" variant="tonal" color="primary" class="ml-2">{{ earningsHistory.referral_summaries?.length || 0 }} pairs</v-chip>
            <v-spacer />
            <v-chip variant="tonal" color="info" size="small" prepend-icon="mdi-information">
              1 coin per 1,000 requests
            </v-chip>
            <v-text-field
              v-model="historySearch"
              density="compact" variant="outlined" rounded="lg" hide-details
              placeholder="Search referrer or referred..."
              prepend-inner-icon="mdi-magnify"
              style="max-width: 280px"
              clearable
            />
          </v-card-title>
          <v-divider />
          <v-progress-linear v-if="loadingHistory" indeterminate color="primary" />

          <!-- Per-referral usage earnings cards -->
          <div class="pa-4">
            <v-row dense class="mb-4">
              <v-col cols="12" sm="6" md="4" v-for="(summary, idx) in filteredSummaries" :key="idx">
                <v-card rounded="lg" variant="outlined" class="h-100 history-card overflow-hidden">
                  <!-- Header -->
                  <div class="pa-4 pb-2">
                    <div class="d-flex align-center mb-2" style="gap:10px">
                      <v-avatar :color="tenantColor(summary.referrer_id)" variant="tonal" rounded="lg" size="38">
                        <span class="text-caption font-weight-bold">{{ (summary.referrer_name || '?')[0] }}</span>
                      </v-avatar>
                      <div class="flex-grow-1">
                        <div class="font-weight-bold text-body-2">{{ summary.referrer_name }}</div>
                        <div class="text-caption text-medium-emphasis">
                          <v-icon size="12" class="mr-1">mdi-arrow-right</v-icon>earns from <strong>{{ summary.referred_name }}</strong>
                        </div>
                      </div>
                      <v-chip :color="statusColor(summary.status)" variant="tonal" size="x-small" class="text-uppercase font-weight-bold">
                        {{ summary.status }}
                      </v-chip>
                    </div>
                  </div>

                  <!-- Usage Stats -->
                  <div class="px-4 pb-3">
                    <div class="d-flex align-center justify-space-between rounded-lg pa-3" style="background: rgba(var(--v-theme-success), 0.08)">
                      <div class="text-center">
                        <div class="text-h5 font-weight-black text-success">{{ Number(summary.coins_from_usage).toLocaleString() }}</div>
                        <div class="text-caption text-medium-emphasis">coins earned</div>
                      </div>
                      <v-divider vertical class="mx-2" />
                      <div class="text-center">
                        <div class="text-h6 font-weight-black">{{ Number(summary.tracked_requests).toLocaleString() }}</div>
                        <div class="text-caption text-medium-emphasis">requests made</div>
                      </div>
                      <v-divider vertical class="mx-2" />
                      <div class="text-center">
                        <div class="text-h6 font-weight-black text-primary">{{ Number(summary.total_earned_from_referred).toLocaleString() }}</div>
                        <div class="text-caption text-medium-emphasis">total KES</div>
                      </div>
                    </div>
                  </div>

                  <!-- Progress to next coin -->
                  <div class="px-4 pb-3" v-if="summary.tracked_requests > 0">
                    <div class="text-caption text-medium-emphasis mb-1 d-flex justify-space-between">
                      <span>Progress to next coin</span>
                      <span class="font-weight-bold">{{ 1000 - (summary.requests_to_next_coin || 0) === 1000 ? 1000 : 1000 - (summary.requests_to_next_coin || 0) }}/1000</span>
                    </div>
                    <v-progress-linear
                      :model-value="((1000 - (summary.requests_to_next_coin || 0)) / 1000) * 100"
                      color="success"
                      rounded
                      height="6"
                      bg-color="grey-lighten-3"
                    />
                  </div>

                  <!-- Footer info -->
                  <v-divider />
                  <div class="d-flex align-center pa-3 px-4" style="gap:12px; background: rgba(var(--v-border-color), 0.03)">
                    <v-chip size="x-small" variant="tonal" :color="summary.bonus_awarded ? 'success' : 'grey'">
                      <v-icon start size="12">{{ summary.bonus_awarded ? 'mdi-check' : 'mdi-clock' }}</v-icon>
                      {{ summary.bonus_awarded ? 'Bonus paid' : 'Bonus pending' }}
                    </v-chip>
                    <v-spacer />
                    <span class="text-caption text-medium-emphasis">{{ formatDate(summary.created_at) }}</span>
                  </div>
                </v-card>
              </v-col>
              <v-col v-if="!filteredSummaries.length" cols="12">
                <div class="text-center pa-8 text-medium-emphasis">
                  <v-icon size="48" color="grey-lighten-1">mdi-history</v-icon>
                  <div class="text-body-1 mt-2">No referral earnings recorded yet</div>
                  <div class="text-caption mt-1">Referrers earn 1 coin for every 1,000 API requests their referred tenants make</div>
                </div>
              </v-col>
            </v-row>

            <!-- Recent transactions table -->
            <v-card rounded="lg" variant="outlined" v-if="(earningsHistory.recent_transactions || []).length">
              <v-card-title class="d-flex align-center pa-3 text-body-1">
                <v-icon class="mr-2" size="20" color="primary">mdi-format-list-bulleted</v-icon>
                Earning Transactions
                <v-chip size="x-small" variant="tonal" color="primary" class="ml-2">{{ earningsHistory.total_records || 0 }}</v-chip>
              </v-card-title>
              <v-divider />
              <v-data-table
                :headers="historyTxHeaders"
                :items="earningsHistory.recent_transactions || []"
                :items-per-page="10"
                density="comfortable"
                hover
                class="ref-table"
              >
                <template #item.referrer_name="{ item }">
                  <div class="d-flex align-center" style="gap:8px">
                    <v-avatar :color="tenantColor(item.referrer_id)" variant="tonal" rounded="lg" size="30">
                      <span class="text-caption font-weight-bold">{{ (item.referrer_name || '?')[0] }}</span>
                    </v-avatar>
                    <span class="font-weight-medium">{{ item.referrer_name }}</span>
                  </div>
                </template>
                <template #item.referred_name="{ item }">
                  <span class="font-weight-medium">{{ item.referred_name }}</span>
                </template>
                <template #item.type="{ item }">
                  <v-chip :color="item.type === 'bonus' ? 'purple' : 'success'" variant="tonal" size="x-small" class="text-uppercase font-weight-bold">
                    {{ item.type }}
                  </v-chip>
                </template>
                <template #item.amount="{ item }">
                  <span class="font-weight-bold text-success">+{{ Number(item.amount).toLocaleString() }} KES</span>
                </template>
                <template #item.created_at="{ item }">
                  <span class="text-medium-emphasis">{{ formatDate(item.created_at) }}</span>
                </template>
              </v-data-table>
            </v-card>
          </div>
        </v-card>
      </v-window-item>

      <!-- MONTHLY PROJECTIONS -->
      <v-window-item value="projections">
        <v-card rounded="xl" elevation="0" style="border:1px solid rgba(var(--v-border-color), 0.12)">
          <v-card-title class="d-flex align-center pa-4">
            <v-icon class="mr-2" color="primary">mdi-chart-timeline-variant</v-icon>
            Monthly Trends & Projections
          </v-card-title>
          <v-divider />
          <v-progress-linear v-if="loadingProjections" indeterminate color="primary" />

          <div class="pa-4">
            <!-- Summary strip -->
            <v-row dense class="mb-5">
              <v-col cols="6" sm="3">
                <v-card rounded="lg" class="pa-3 text-center kpi-gradient-green" elevation="0">
                  <div class="text-caption text-medium-emphasis text-uppercase font-weight-medium">This Month</div>
                  <div class="text-h5 font-weight-black text-success">{{ Number(projectionData.summary?.this_month_earned || 0).toLocaleString() }}</div>
                  <div class="text-caption">KES earned</div>
                </v-card>
              </v-col>
              <v-col cols="6" sm="3">
                <v-card rounded="lg" class="pa-3 text-center kpi-gradient-blue" elevation="0">
                  <div class="text-caption text-medium-emphasis text-uppercase font-weight-medium">Last Month</div>
                  <div class="text-h5 font-weight-black">{{ Number(projectionData.summary?.last_month_earned || 0).toLocaleString() }}</div>
                  <div class="text-caption">KES earned</div>
                </v-card>
              </v-col>
              <v-col cols="6" sm="3">
                <v-card rounded="lg" class="pa-3 text-center" :class="momGrowthColor" elevation="0">
                  <div class="text-caption text-medium-emphasis text-uppercase font-weight-medium">MoM Growth</div>
                  <div class="text-h5 font-weight-black">
                    <v-icon v-if="projectionData.summary?.mom_growth_percent !== null" size="20" :color="projectionData.summary?.mom_growth_percent >= 0 ? 'success' : 'error'">
                      {{ projectionData.summary?.mom_growth_percent >= 0 ? 'mdi-trending-up' : 'mdi-trending-down' }}
                    </v-icon>
                    {{ projectionData.summary?.mom_growth_percent !== null ? `${projectionData.summary.mom_growth_percent}%` : '—' }}
                  </div>
                  <div class="text-caption">month over month</div>
                </v-card>
              </v-col>
              <v-col cols="6" sm="3">
                <v-card rounded="lg" class="pa-3 text-center kpi-gradient-purple" elevation="0">
                  <div class="text-caption text-medium-emphasis text-uppercase font-weight-medium">Avg Monthly</div>
                  <div class="text-h5 font-weight-black">{{ Number(projectionData.summary?.avg_monthly || 0).toLocaleString() }}</div>
                  <div class="text-caption">KES avg</div>
                </v-card>
              </v-col>
            </v-row>

            <!-- Monthly history timeline -->
            <v-card rounded="lg" variant="outlined" class="mb-4">
              <v-card-title class="d-flex align-center pa-3 text-body-1">
                <v-icon class="mr-2" size="20" color="success">mdi-chart-bar</v-icon>
                Monthly Earnings History
              </v-card-title>
              <v-divider />
              <div class="pa-4" v-if="(projectionData.history || []).length">
                <div class="timeline-chart">
                  <div
                    v-for="(m, i) in projectionData.history"
                    :key="i"
                    class="timeline-bar-wrapper"
                  >
                    <div class="text-caption text-medium-emphasis mb-1 text-center">{{ m.month_label }}</div>
                    <div class="timeline-bar-bg">
                      <div
                        class="timeline-bar"
                        :style="{ height: barHeight(m.total_earned) + '%' }"
                      />
                    </div>
                    <div class="text-caption font-weight-bold text-center mt-1">{{ Number(m.total_earned).toLocaleString() }}</div>
                    <div class="text-caption text-medium-emphasis text-center">
                      {{ m.new_referrals }} ref · {{ m.transaction_count }} tx
                    </div>
                  </div>
                </div>
              </div>
              <div v-else class="text-center pa-8 text-medium-emphasis">
                <v-icon size="48" color="grey-lighten-1">mdi-chart-bar</v-icon>
                <div class="text-body-1 mt-2">No monthly data yet</div>
              </div>
            </v-card>

            <!-- Projections -->
            <v-card rounded="lg" variant="outlined">
              <v-card-title class="d-flex align-center pa-3 text-body-1">
                <v-icon class="mr-2" size="20" color="amber-darken-2">mdi-crystal-ball</v-icon>
                3-Month Forecast
              </v-card-title>
              <v-divider />
              <v-list v-if="(projectionData.projections || []).length" lines="two" class="pa-2">
                <v-list-item
                  v-for="(p, i) in projectionData.projections"
                  :key="i"
                  rounded="lg"
                  class="mb-1"
                >
                  <template #prepend>
                    <v-avatar color="amber-darken-2" variant="tonal" rounded="lg" size="44">
                      <v-icon size="22">mdi-calendar-month</v-icon>
                    </v-avatar>
                  </template>
                  <v-list-item-title class="font-weight-bold">{{ p.month_label }}</v-list-item-title>
                  <v-list-item-subtitle>
                    Projected: <span class="text-success font-weight-bold">{{ Number(p.projected_earned).toLocaleString() }} KES</span>
                    · Confidence:
                    <v-chip :color="p.confidence === 'high' ? 'success' : 'warning'" variant="tonal" size="x-small" class="text-uppercase font-weight-bold">
                      {{ p.confidence }}
                    </v-chip>
                  </v-list-item-subtitle>
                  <template #append>
                    <div class="text-h6 font-weight-black text-amber-darken-2">
                      {{ Number(p.projected_earned).toLocaleString() }}
                    </div>
                  </template>
                </v-list-item>
              </v-list>
              <div v-else class="text-center pa-8 text-medium-emphasis">
                <v-icon size="48" color="grey-lighten-1">mdi-crystal-ball</v-icon>
                <div class="text-body-1 mt-2">Not enough data for projections</div>
                <div class="text-caption">Need at least 1 month of earnings data</div>
              </div>
            </v-card>
          </div>
        </v-card>
      </v-window-item>

      <!-- LEADERBOARD -->
      <v-window-item value="leaderboard">
        <v-card rounded="xl" elevation="0" style="border:1px solid rgba(var(--v-border-color), 0.12)">
          <v-card-title class="d-flex align-center pa-4">
            <v-icon class="mr-2" color="amber-darken-2">mdi-trophy</v-icon>
            Top Referrers
          </v-card-title>
          <v-divider />
          <v-list lines="two" class="pa-2">
            <v-list-item
              v-for="(r, i) in stats.top_referrers || []"
              :key="i"
              rounded="lg"
              class="mb-1"
            >
              <template #prepend>
                <v-avatar
                  :color="i < 3 ? ['amber-darken-2', 'grey-lighten-1', 'deep-orange'][i] : 'primary'"
                  variant="tonal"
                  rounded="lg"
                  size="44"
                >
                  <span class="text-h6 font-weight-black">{{ i + 1 }}</span>
                </v-avatar>
              </template>
              <v-list-item-title class="font-weight-bold">{{ r.tenant_name }}</v-list-item-title>
              <v-list-item-subtitle>
                {{ r.referral_count }} referral{{ r.referral_count !== 1 ? 's' : '' }} ·
                <span class="text-success">{{ Number(r.total_earned).toLocaleString() }} earned</span> ·
                Balance: {{ Number(r.coin_balance).toLocaleString() }} KES
              </v-list-item-subtitle>
              <template #append>
                <div class="text-center">
                  <div class="text-h6 font-weight-black" :class="i < 3 ? 'text-amber-darken-2' : ''">{{ r.referral_count }}</div>
                  <div class="text-caption text-medium-emphasis">refs</div>
                </div>
              </template>
            </v-list-item>
            <v-list-item v-if="!(stats.top_referrers || []).length">
              <div class="text-center pa-8 text-medium-emphasis w-100">
                <v-icon size="48" color="grey-lighten-1">mdi-trophy-outline</v-icon>
                <div class="text-body-1 mt-2">No referrals yet</div>
              </div>
            </v-list-item>
          </v-list>
        </v-card>
      </v-window-item>
    </v-window>

    <!-- EDIT REFERRAL DIALOG -->
    <v-dialog v-model="editRefDialog" max-width="480" persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center pa-5 pb-2">
          <v-icon color="primary" class="mr-2">mdi-pencil</v-icon>
          Edit Referral
        </v-card-title>
        <v-card-text class="px-5">
          <div class="mb-4">
            <div class="text-body-2 text-medium-emphasis">Referrer</div>
            <div class="font-weight-bold">{{ editRefForm.referrer_name }}</div>
          </div>
          <div class="mb-4">
            <div class="text-body-2 text-medium-emphasis">Referred</div>
            <div class="font-weight-bold">{{ editRefForm.referred_name }}</div>
          </div>
          <v-select
            v-model="editRefForm.status"
            :items="[{title:'Active', value:'active'},{title:'Pending', value:'pending'},{title:'Expired', value:'expired'}]"
            label="Status"
            density="compact" variant="outlined" rounded="lg"
            prepend-inner-icon="mdi-flag"
            class="mb-3"
          />
          <v-switch v-model="editRefForm.bonus_awarded" label="Bonus Awarded" color="success" density="compact" hide-details />
        </v-card-text>
        <v-card-actions class="pa-5 pt-2">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="editRefDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" rounded="lg" class="text-none" :loading="savingRef" @click="saveReferral">
            Save
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- REGENERATE CODE CONFIRM -->
    <v-dialog v-model="regenDialog" max-width="420">
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center pa-5 pb-2">
          <v-icon color="warning" class="mr-2">mdi-alert-circle</v-icon>
          Regenerate Code
        </v-card-title>
        <v-card-text class="px-5">
          This will invalidate the current referral code for <strong>{{ regenProfile?.tenant_name }}</strong>.
          Any shared links with the old code will stop working.
        </v-card-text>
        <v-card-actions class="pa-5 pt-0">
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="regenDialog = false">Cancel</v-btn>
          <v-btn color="warning" variant="flat" rounded="lg" class="text-none" :loading="regenerating" @click="doRegenerate">
            Regenerate
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Snackbar -->
    <v-snackbar v-model="snack.show" :color="snack.color" rounded="lg" location="top">
      {{ snack.text }}
      <template #actions>
        <v-btn variant="text" @click="snack.show = false">Close</v-btn>
      </template>
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'

const { $api } = useNuxtApp()

// State
const tab = ref('referrals')
const stats = ref({})
const referrals = ref([])
const profiles = ref([])
const refreshing = ref(false)
const loadingRefs = ref(false)
const loadingProfiles = ref(false)

const refSearch = ref('')
const profileSearch = ref('')
const historySearch = ref('')
const statusFilter = ref('all')

// History & Projections
const earningsHistory = ref({})
const projectionData = ref({})
const loadingHistory = ref(false)
const loadingProjections = ref(false)

// Dialogs
const editRefDialog = ref(false)
const regenDialog = ref(false)
const savingRef = ref(false)
const regenerating = ref(false)
const regenProfile = ref(null)
const editRefForm = reactive({ id: null, referrer_name: '', referred_name: '', status: '', bonus_awarded: false })

const snack = reactive({ show: false, text: '', color: 'success' })

// Options
const statusOptions = [
  { title: 'All statuses', value: 'all' },
  { title: 'Active', value: 'active' },
  { title: 'Pending', value: 'pending' },
  { title: 'Expired', value: 'expired' },
]

const refHeaders = [
  { title: 'Referrer', key: 'referrer_name', sortable: true },
  { title: 'Referred', key: 'referred_name', sortable: true },
  { title: 'Status', key: 'status', sortable: true },
  { title: 'Bonus', key: 'bonus_awarded', align: 'center' },
  { title: 'Coins from Usage', key: 'coins_from_usage', align: 'end' },
  { title: 'Date', key: 'created_at', sortable: true },
  { title: '', key: 'actions', sortable: false, align: 'end', width: '60px' },
]

const profileHeaders = [
  { title: 'Tenant', key: 'tenant_name', sortable: true },
  { title: 'Code', key: 'referral_code' },
  { title: 'Balance', key: 'coin_balance', sortable: true, align: 'end' },
  { title: 'Earned', key: 'total_earned', sortable: true, align: 'end' },
  { title: 'Redeemed', key: 'total_redeemed', sortable: true, align: 'end' },
  { title: 'Referrals', key: 'referral_count', sortable: true, align: 'center' },
  { title: 'Active', key: 'tenant_is_active', align: 'center' },
  { title: '', key: 'actions', sortable: false, align: 'end', width: '60px' },
]

const historyTxHeaders = [
  { title: 'Referrer', key: 'referrer_name', sortable: true },
  { title: 'From Referred', key: 'referred_name', sortable: true },
  { title: 'Type', key: 'type' },
  { title: 'Amount', key: 'amount', align: 'end', sortable: true },
  { title: 'Reason', key: 'reason' },
  { title: 'Date', key: 'created_at', sortable: true },
]

// Computed
const filteredReferrals = computed(() => {
  let arr = referrals.value
  if (statusFilter.value !== 'all') arr = arr.filter(r => r.status === statusFilter.value)
  const q = (refSearch.value || '').toLowerCase()
  if (q) arr = arr.filter(r =>
    (r.referrer_name || '').toLowerCase().includes(q) ||
    (r.referred_name || '').toLowerCase().includes(q)
  )
  return arr
})

const filteredProfiles = computed(() => {
  const q = (profileSearch.value || '').toLowerCase()
  if (!q) return profiles.value
  return profiles.value.filter(p =>
    (p.tenant_name || '').toLowerCase().includes(q) ||
    (p.referral_code || '').toLowerCase().includes(q)
  )
})

const filteredSummaries = computed(() => {
  const summaries = earningsHistory.value.referral_summaries || []
  const q = (historySearch.value || '').toLowerCase()
  if (!q) return summaries
  return summaries.filter(s =>
    (s.referrer_name || '').toLowerCase().includes(q) ||
    (s.referred_name || '').toLowerCase().includes(q)
  )
})

const momGrowthColor = computed(() => {
  const g = projectionData.value.summary?.mom_growth_percent
  if (g === null || g === undefined) return 'kpi-gradient-amber'
  return g >= 0 ? 'kpi-gradient-green' : 'kpi-gradient-red'
})

function barHeight(value) {
  const history = projectionData.value.history || []
  const max = Math.max(...history.map(h => h.total_earned), 1)
  return Math.max((value / max) * 100, 5)
}

// Helpers
function notify(text, color = 'success') { snack.text = text; snack.color = color; snack.show = true }

function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
}

const _colors = ['primary', 'success', 'info', 'warning', 'error', 'purple', 'teal', 'amber-darken-2', 'deep-orange', 'indigo']
function tenantColor(id) { return _colors[(Number(id) || 0) % _colors.length] }

function statusColor(s) {
  return { active: 'success', pending: 'warning', expired: 'grey' }[s] || 'default'
}
function statusIcon(s) {
  return { active: 'mdi-check-circle', pending: 'mdi-clock-outline', expired: 'mdi-close-circle' }[s] || 'mdi-help-circle'
}

function copyCode(code) {
  navigator.clipboard?.writeText(code)
  notify(`Copied: ${code}`)
}

// API
async function loadStats() {
  try {
    const { data } = await $api.get('/superadmin/referrals/stats/')
    stats.value = data
  } catch { /* ignore */ }
}

async function loadReferrals() {
  loadingRefs.value = true
  try {
    const { data } = await $api.get('/superadmin/referrals/')
    referrals.value = data?.results || data || []
  } catch { referrals.value = [] }
  finally { loadingRefs.value = false }
}

async function loadProfiles() {
  loadingProfiles.value = true
  try {
    const { data } = await $api.get('/superadmin/referrals/profiles/')
    profiles.value = data?.results || data || []
  } catch { profiles.value = [] }
  finally { loadingProfiles.value = false }
}

async function loadAll() {
  refreshing.value = true
  await Promise.all([loadStats(), loadReferrals(), loadProfiles(), loadHistory(), loadProjections()])
  refreshing.value = false
}

async function loadHistory() {
  loadingHistory.value = true
  try {
    const { data } = await $api.get('/superadmin/referrals/earnings-history/')
    earningsHistory.value = data || {}
  } catch { earningsHistory.value = {} }
  finally { loadingHistory.value = false }
}

async function loadProjections() {
  loadingProjections.value = true
  try {
    const { data } = await $api.get('/superadmin/referrals/monthly-projections/')
    projectionData.value = data || {}
  } catch { projectionData.value = {} }
  finally { loadingProjections.value = false }
}

// Edit Referral
function openEditReferral(item) {
  Object.assign(editRefForm, {
    id: item.id,
    referrer_name: item.referrer_name,
    referred_name: item.referred_name,
    status: item.status,
    bonus_awarded: item.bonus_awarded,
  })
  editRefDialog.value = true
}

async function saveReferral() {
  savingRef.value = true
  try {
    await $api.patch(`/superadmin/referrals/${editRefForm.id}/`, {
      status: editRefForm.status,
      bonus_awarded: editRefForm.bonus_awarded,
    })
    notify('Referral updated')
    editRefDialog.value = false
    loadReferrals()
    loadStats()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to update', 'error')
  } finally { savingRef.value = false }
}

// Regenerate code
function confirmRegenerate(profile) {
  regenProfile.value = profile
  regenDialog.value = true
}

async function doRegenerate() {
  regenerating.value = true
  try {
    const { data } = await $api.post(`/superadmin/referrals/profiles/${regenProfile.value.id}/regenerate-code/`)
    notify(`New code: ${data.referral_code}`)
    regenDialog.value = false
    loadProfiles()
  } catch (e) {
    notify(e?.response?.data?.detail || 'Failed to regenerate', 'error')
  } finally { regenerating.value = false }
}

// Init
onMounted(loadAll)
</script>

<style scoped>
.kpi-card {
  border: 1px solid rgba(var(--v-border-color), 0.08);
  transition: transform 0.2s, box-shadow 0.2s;
}
.kpi-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 24px rgba(0,0,0,0.08);
}
.kpi-gradient-blue { background: linear-gradient(135deg, rgba(33,150,243,0.08), rgba(33,150,243,0.02)); }
.kpi-gradient-green { background: linear-gradient(135deg, rgba(76,175,80,0.08), rgba(76,175,80,0.02)); }
.kpi-gradient-amber { background: linear-gradient(135deg, rgba(255,193,7,0.08), rgba(255,193,7,0.02)); }
.kpi-gradient-purple { background: linear-gradient(135deg, rgba(156,39,176,0.08), rgba(156,39,176,0.02)); }
.kpi-gradient-red { background: linear-gradient(135deg, rgba(244,67,54,0.08), rgba(244,67,54,0.02)); }
.kpi-gradient-teal { background: linear-gradient(135deg, rgba(0,150,136,0.08), rgba(0,150,136,0.02)); }

.ref-table :deep(th) {
  font-weight: 700 !important;
  text-transform: uppercase;
  font-size: 11px !important;
  letter-spacing: 0.05em;
}

.font-mono { font-family: 'JetBrains Mono', 'Fira Code', monospace !important; letter-spacing: 0.1em; }

.history-card {
  transition: transform 0.2s, box-shadow 0.2s;
}
.history-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 20px rgba(0,0,0,0.08);
}

.timeline-chart {
  display: flex;
  align-items: flex-end;
  gap: 12px;
  overflow-x: auto;
  padding: 8px 0;
  min-height: 200px;
}
.timeline-bar-wrapper {
  display: flex;
  flex-direction: column;
  align-items: center;
  flex: 1;
  min-width: 60px;
}
.timeline-bar-bg {
  width: 32px;
  height: 120px;
  background: rgba(var(--v-theme-surface-variant), 0.3);
  border-radius: 6px;
  position: relative;
  overflow: hidden;
  display: flex;
  align-items: flex-end;
}
.timeline-bar {
  width: 100%;
  background: linear-gradient(180deg, rgb(var(--v-theme-success)), rgba(var(--v-theme-success), 0.6));
  border-radius: 6px;
  transition: height 0.5s ease;
}
</style>
