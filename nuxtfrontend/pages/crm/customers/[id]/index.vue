<template>
  <v-container fluid class="pa-3 pa-md-5 crm-page">
    <!-- hero -->
    <div class="crm-hero mb-4" :style="heroTheme">
      <span class="crm-hero-glow" />
      <div class="d-flex flex-wrap align-center justify-space-between ga-3">
        <div class="d-flex align-center" style="gap:16px">
          <v-avatar size="58" :color="avatarColor(name)" variant="flat" class="text-white font-weight-bold" style="font-size: 20px">
            {{ initials(name) }}
          </v-avatar>
          <div>
            <div class="crm-eyebrow">
              <v-icon size="11">mdi-circle</v-icon>
              CUSTOMER · 360° PROFILE
            </div>
            <h1 class="crm-title">
              {{ name || 'Customer' }}
              <v-icon v-if="profile?.is_vip" size="20" color="#fde68a" class="ml-1">mdi-crown-outline</v-icon>
            </h1>
            <div class="crm-sub">
              {{ customer?.phone || '—' }}
              <span v-if="customer?.email"> · {{ customer.email }}</span>
              <span v-if="customer?.branch_name"> · {{ customer.branch_name }}</span>
            </div>
          </div>
        </div>
        <div class="d-flex flex-wrap align-center ga-2">
          <v-btn icon="mdi-arrow-left" variant="text" size="small" class="crm-hero-iconbtn" title="Back" to="/ims/crm/customers" />
          <v-btn icon="mdi-refresh" variant="text" size="small" class="crm-hero-iconbtn" title="Refresh" :loading="loading" @click="load" />
          <v-btn variant="flat" elevation="0" rounded="lg" class="text-none crm-hero-btn-glass" prepend-icon="mdi-pencil" @click="profileDialog = true">
            Edit profile
          </v-btn>
          <v-btn variant="flat" elevation="0" rounded="lg" class="text-none crm-hero-btn-strong" prepend-icon="mdi-plus" @click="openLog()">
            Log activity
          </v-btn>
        </div>
      </div>

      <div class="crm-hero-facts">
        <div class="crm-hero-fact">
          <div class="crm-hero-fact-value">{{ formatMoney(customer?.total_purchases || 0) }}</div>
          <div class="crm-hero-fact-label">lifetime spend</div>
        </div>
        <span class="crm-hero-divider" />
        <div class="crm-hero-fact">
          <div class="crm-hero-fact-value">{{ customer?.visit_count ?? 0 }}</div>
          <div class="crm-hero-fact-label">visits</div>
        </div>
        <span class="crm-hero-divider" />
        <div class="crm-hero-fact">
          <div class="crm-hero-fact-value">{{ (customer?.loyalty_points ?? 0).toLocaleString() }}</div>
          <div class="crm-hero-fact-label">loyalty points</div>
        </div>
        <span class="crm-hero-divider" />
        <div class="crm-hero-fact">
          <div class="crm-hero-fact-value">{{ profile?.health_score ?? 70 }}</div>
          <div class="crm-hero-fact-label">health score</div>
        </div>
        <span class="crm-hero-divider crm-hero-divider-lg" />
        <div class="crm-hero-fact">
          <div class="crm-hero-fact-value">{{ openTickets.length }}</div>
          <div class="crm-hero-fact-label">open cases</div>
        </div>
      </div>
    </div>

    <v-row dense>
      <!-- left column -->
      <v-col cols="12" lg="4">
        <!-- identity -->
        <v-card rounded="xl" border class="mb-3">
          <div class="d-flex align-center pa-4 pb-2" style="gap:10px">
            <v-icon color="primary">mdi-card-account-details-outline</v-icon>
            <div class="text-subtitle-1 font-weight-bold">Profile</div>
          </div>
          <v-divider />
          <v-card-text>
            <div class="crm-kv"><span>Lifecycle</span>
              <v-chip size="x-small" variant="tonal" :color="lifecycleMeta(profile?.lifecycle_stage).color">
                <v-icon start size="11">{{ lifecycleMeta(profile?.lifecycle_stage).icon }}</v-icon>
                {{ lifecycleMeta(profile?.lifecycle_stage).label }}
              </v-chip>
            </div>
            <div class="crm-kv"><span>Segment</span>
              <v-chip v-if="profile?.segment_name" size="x-small" variant="tonal" :style="{ color: profile.segment_color }">{{ profile.segment_name }}</v-chip>
              <strong v-else class="text-medium-emphasis">—</strong>
            </div>
            <div class="crm-kv"><span>Tier</span>
              <v-chip size="x-small" variant="tonal" :color="tierMeta(customer?.loyalty_tier).color">
                <v-icon start size="11">{{ tierMeta(customer?.loyalty_tier).icon }}</v-icon>
                {{ tierMeta(customer?.loyalty_tier).label }}
              </v-chip>
            </div>
            <div class="crm-kv"><span>Owner</span><strong>{{ profile?.owner_name || 'Unassigned' }}</strong></div>
            <div class="crm-kv"><span>Company</span><strong>{{ profile?.company || '—' }}</strong></div>
            <div class="crm-kv"><span>Preferred channel</span><strong>{{ titleCase(profile?.preferred_channel) }}</strong></div>
            <div class="crm-kv"><span>Lead source</span><strong>{{ titleCase(profile?.lead_source) }}</strong></div>
            <div class="crm-kv"><span>Date of birth</span><strong>{{ profile?.date_of_birth || '—' }}</strong></div>
            <div class="crm-kv"><span>Address</span><strong class="text-right">{{ customer?.address || '—' }}</strong></div>
            <v-divider class="my-3" />
            <div class="text-caption text-uppercase font-weight-bold text-medium-emphasis mb-2">Scores</div>
            <div class="mb-2">
              <div class="d-flex justify-space-between text-caption mb-1">
                <span>Health</span><span class="font-weight-bold">{{ profile?.health_score ?? 70 }}/100</span>
              </div>
              <v-progress-linear :model-value="profile?.health_score ?? 70" :color="healthColor(profile?.health_score)" height="7" rounded bg-color="surface-variant" />
            </div>
            <div>
              <div class="d-flex justify-space-between text-caption mb-1">
                <span>Churn risk</span><span class="font-weight-bold">{{ profile?.churn_risk ?? 20 }}%</span>
              </div>
              <v-progress-linear :model-value="profile?.churn_risk ?? 20" :color="riskColor(profile?.churn_risk)" height="7" rounded bg-color="surface-variant" />
            </div>
            <div v-if="profile?.tags?.length" class="d-flex flex-wrap ga-1 mt-3">
              <v-chip v-for="t in profile.tags" :key="t.id" size="x-small" variant="tonal" :style="{ color: t.color }">{{ t.name }}</v-chip>
            </div>
          </v-card-text>
        </v-card>

        <!-- credit -->
        <v-card rounded="xl" border class="mb-3">
          <div class="d-flex align-center pa-4 pb-2" style="gap:10px">
            <v-icon color="deep-purple">mdi-cash-clock</v-icon>
            <div class="text-subtitle-1 font-weight-bold">Credit</div>
          </div>
          <v-divider />
          <v-card-text>
            <div class="crm-kv"><span>Credit limit</span><strong>{{ formatMoney(profile?.credit_limit || 0) }}</strong></div>
            <div class="crm-kv"><span>Outstanding</span><strong :class="Number(profile?.outstanding_balance) > 0 ? 'text-error' : ''">{{ formatMoney(profile?.outstanding_balance || 0) }}</strong></div>
            <div class="crm-kv"><span>Payment terms</span><strong>{{ profile?.payment_terms_days ?? 0 }} days</strong></div>
            <div class="mt-2">
              <v-progress-linear :model-value="creditUsedPct" color="deep-purple" height="8" rounded bg-color="surface-variant" />
              <div class="text-caption text-medium-emphasis mt-1">{{ creditUsedPct }}% of limit used</div>
            </div>
          </v-card-text>
        </v-card>

        <!-- spending trend -->
        <v-card rounded="xl" border>
          <div class="d-flex align-center pa-4 pb-2" style="gap:10px">
            <v-icon color="success">mdi-chart-areaspline</v-icon>
            <div class="text-subtitle-1 font-weight-bold">Spend trend</div>
          </div>
          <v-divider />
          <v-card-text>
            <div class="crm-spark">
              <div v-for="m in trend" :key="m.month" class="crm-spark-col">
                <div class="crm-spark-bar" :style="{ height: barHeight(m.total) + '%' }" />
                <div class="crm-spark-label">{{ m.month.split(' ')[0] }}</div>
              </div>
            </div>
            <div class="d-flex justify-space-between text-caption text-medium-emphasis mt-2">
              <span>Last 6 months</span>
              <span class="font-weight-medium">{{ formatMoney(trendTotal) }}</span>
            </div>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- right column -->
      <v-col cols="12" lg="8">
        <v-card rounded="xl" border class="mb-3">
          <v-tabs v-model="tab" color="primary" density="comfortable" show-arrows>
            <v-tab value="timeline"><v-icon start size="16">mdi-history</v-icon>Activity</v-tab>
            <v-tab value="tickets"><v-icon start size="16">mdi-lifebuoy</v-icon>Tickets<v-chip v-if="openTickets.length" size="x-small" color="error" class="ml-1">{{ openTickets.length }}</v-chip></v-tab>
            <v-tab value="deals"><v-icon start size="16">mdi-chart-timeline-variant-shimmer</v-icon>Deals</v-tab>
            <v-tab value="tasks"><v-icon start size="16">mdi-checkbox-marked-circle-outline</v-icon>Tasks</v-tab>
            <v-tab value="loyalty"><v-icon start size="16">mdi-star-circle-outline</v-icon>Loyalty</v-tab>
            <v-tab value="feedback"><v-icon start size="16">mdi-emoticon-outline</v-icon>Feedback</v-tab>
          </v-tabs>
          <v-divider />
          <v-window v-model="tab">
            <!-- activity -->
            <v-window-item value="timeline">
              <v-card-text>
                <div class="d-flex justify-end mb-2">
                  <v-btn size="small" variant="tonal" color="primary" rounded="lg" class="text-none" prepend-icon="mdi-plus" @click="openLog()">Log activity</v-btn>
                </div>
                <div v-if="data.interactions?.length" class="crm-timeline">
                  <div v-for="i in data.interactions" :key="i.id" class="crm-timeline-item">
                    <div class="crm-timeline-dot" :style="{ background: interactionColor(i.kind) }">
                      <v-icon size="13" color="white">{{ interactionIcon(i.kind) }}</v-icon>
                    </div>
                    <div class="flex-grow-1">
                      <div class="d-flex align-center justify-space-between ga-2 flex-wrap">
                        <span class="text-body-2 font-weight-medium">{{ i.subject }}</span>
                        <span class="text-caption text-medium-emphasis">{{ dt(i.occurred_at) }}</span>
                      </div>
                      <div class="text-caption text-medium-emphasis">
                        {{ interactionLabel(i.kind) }} · {{ titleCase(i.direction) }} · {{ titleCase(i.outcome) }}
                        <span v-if="i.created_by_name"> · {{ i.created_by_name }}</span>
                      </div>
                      <div v-if="i.summary" class="text-body-2 mt-1">{{ i.summary }}</div>
                      <v-chip v-if="i.follow_up_required" size="x-small" variant="tonal" color="amber" class="mt-1">
                        <v-icon start size="11">mdi-clock-outline</v-icon>Follow-up {{ dt(i.follow_up_at) }}
                      </v-chip>
                    </div>
                  </div>
                </div>
                <div v-else class="crm-empty py-8">
                  <v-icon size="40" color="medium-emphasis">mdi-history</v-icon>
                  <div class="text-body-2 font-weight-medium mt-2">No activity yet</div>
                  <div class="text-caption text-medium-emphasis">Log a call, email or meeting to start the timeline.</div>
                </div>
              </v-card-text>
            </v-window-item>

            <!-- tickets -->
            <v-window-item value="tickets">
              <v-card-text>
                <div v-if="data.tickets?.length" class="d-flex flex-column ga-2">
                  <v-card v-for="t in data.tickets" :key="t.id" variant="outlined" rounded="lg" class="pa-3">
                    <div class="d-flex align-center justify-space-between flex-wrap ga-2">
                      <div>
                        <div class="d-flex align-center ga-2">
                          <span class="font-weight-medium">{{ t.subject }}</span>
                          <v-chip size="x-small" variant="tonal" :color="ticketStatus(t.status).color">{{ ticketStatus(t.status).label }}</v-chip>
                          <v-chip size="x-small" variant="tonal" :color="priorityMeta(t.priority).color">{{ priorityMeta(t.priority).label }}</v-chip>
                        </div>
                        <div class="text-caption text-medium-emphasis">{{ t.reference }} · {{ titleCase(t.category) }} · opened {{ dt(t.opened_at) }}</div>
                      </div>
                      <v-btn v-if="!['resolved','closed'].includes(t.status)" size="x-small" variant="tonal" color="success" class="text-none" @click="resolveTicket(t)">Resolve</v-btn>
                    </div>
                    <div v-if="t.description" class="text-body-2 mt-2">{{ t.description }}</div>
                  </v-card>
                </div>
                <div v-else class="crm-empty py-8">
                  <v-icon size="40" color="medium-emphasis">mdi-lifebuoy</v-icon>
                  <div class="text-body-2 font-weight-medium mt-2">No tickets</div>
                  <div class="text-caption text-medium-emphasis">This customer has no support cases.</div>
                </div>
              </v-card-text>
            </v-window-item>

            <!-- deals -->
            <v-window-item value="deals">
              <v-card-text>
                <div v-if="data.opportunities?.length" class="d-flex flex-column ga-2">
                  <v-card v-for="o in data.opportunities" :key="o.id" variant="outlined" rounded="lg" class="pa-3">
                    <div class="d-flex align-center justify-space-between flex-wrap ga-2">
                      <div>
                        <div class="d-flex align-center ga-2">
                          <span class="font-weight-medium">{{ o.title }}</span>
                          <v-chip size="x-small" variant="tonal" :color="stageMeta(o.stage).color">{{ stageMeta(o.stage).label }}</v-chip>
                        </div>
                        <div class="text-caption text-medium-emphasis">
                          {{ o.owner_name || 'Unassigned' }} · {{ o.probability }}% · expected {{ o.expected_close_date || '—' }}
                        </div>
                      </div>
                      <div class="text-right">
                        <div class="font-weight-bold">{{ formatMoney(o.value) }}</div>
                        <div class="text-caption text-medium-emphasis">weighted {{ formatMoney(o.weighted_value) }}</div>
                      </div>
                    </div>
                  </v-card>
                </div>
                <div v-else class="crm-empty py-8">
                  <v-icon size="40" color="medium-emphasis">mdi-chart-timeline-variant-shimmer</v-icon>
                  <div class="text-body-2 font-weight-medium mt-2">No deals</div>
                  <div class="text-caption text-medium-emphasis">No opportunities recorded for this customer.</div>
                </div>
              </v-card-text>
            </v-window-item>

            <!-- tasks -->
            <v-window-item value="tasks">
              <v-card-text>
                <div v-if="data.tasks?.length">
                  <div v-for="t in data.tasks" :key="t.id" class="crm-task-row">
                    <v-checkbox-btn :model-value="t.status === 'done'" color="success" density="compact" hide-details @click="completeTask(t)" />
                    <div class="flex-grow-1">
                      <div class="text-body-2 font-weight-medium" :class="t.status === 'done' ? 'text-decoration-line-through text-medium-emphasis' : ''">{{ t.title }}</div>
                      <div class="text-caption text-medium-emphasis">due {{ dt(t.due_at) }} · {{ t.assigned_to_name || 'Unassigned' }}</div>
                    </div>
                    <v-chip size="x-small" variant="tonal" :color="priorityMeta(t.priority).color">{{ priorityMeta(t.priority).label }}</v-chip>
                  </div>
                </div>
                <div v-else class="crm-empty py-8">
                  <v-icon size="40" color="medium-emphasis">mdi-checkbox-marked-circle-outline</v-icon>
                  <div class="text-body-2 font-weight-medium mt-2">No tasks</div>
                </div>
              </v-card-text>
            </v-window-item>

            <!-- loyalty -->
            <v-window-item value="loyalty">
              <v-card-text>
                <v-row dense class="mb-3">
                  <v-col cols="6" md="3"><div class="crm-stat"><div class="crm-stat-label">Balance</div><div class="crm-stat-value">{{ (customer?.loyalty_points ?? 0).toLocaleString() }}</div></div></v-col>
                  <v-col cols="6" md="3"><div class="crm-stat"><div class="crm-stat-label">Tier</div><div class="crm-stat-value">{{ tierMeta(customer?.loyalty_tier).label }}</div></div></v-col>
                  <v-col cols="6" md="3"><div class="crm-stat"><div class="crm-stat-label">Visits</div><div class="crm-stat-value">{{ customer?.visit_count ?? 0 }}</div></div></v-col>
                  <v-col cols="6" md="3"><div class="crm-stat"><div class="crm-stat-label">Lifetime</div><div class="crm-stat-value">{{ formatMoney(customer?.total_purchases || 0) }}</div></div></v-col>
                </v-row>
                <div class="d-flex justify-end mb-2">
                  <v-btn size="small" variant="tonal" color="deep-purple" rounded="lg" class="text-none" prepend-icon="mdi-plus" @click="pointsDialog = true">Adjust points</v-btn>
                </div>
                <v-table v-if="data.points?.length" density="compact" class="crm-table">
                  <thead><tr><th>Date</th><th>Kind</th><th>Reason</th><th class="text-right">Points</th><th class="text-right">Balance</th></tr></thead>
                  <tbody>
                    <tr v-for="p in data.points" :key="p.id">
                      <td>{{ dt(p.created_at) }}</td>
                      <td><v-chip size="x-small" variant="tonal" :color="p.points > 0 ? 'success' : 'error'">{{ titleCase(p.kind) }}</v-chip></td>
                      <td>{{ p.reason || '—' }}</td>
                      <td class="text-right font-weight-medium" :class="p.points > 0 ? 'text-success' : 'text-error'">{{ p.points > 0 ? '+' : '' }}{{ p.points }}</td>
                      <td class="text-right">{{ p.balance_after }}</td>
                    </tr>
                  </tbody>
                </v-table>
                <div v-else class="crm-empty py-8">
                  <v-icon size="40" color="medium-emphasis">mdi-star-circle-outline</v-icon>
                  <div class="text-body-2 font-weight-medium mt-2">No points activity</div>
                </div>
              </v-card-text>
            </v-window-item>

            <!-- feedback -->
            <v-window-item value="feedback">
              <v-card-text>
                <div v-if="data.feedback?.length" class="d-flex flex-column ga-2">
                  <v-card v-for="f in data.feedback" :key="f.id" variant="outlined" rounded="lg" class="pa-3">
                    <div class="d-flex align-center justify-space-between">
                      <div class="d-flex align-center ga-2">
                        <v-chip size="x-small" variant="tonal" :color="f.score >= 9 ? 'success' : f.score >= 7 ? 'amber' : 'error'">{{ f.score }}</v-chip>
                        <span class="text-body-2 font-weight-medium">{{ titleCase(f.kind) }}</span>
                      </div>
                      <span class="text-caption text-medium-emphasis">{{ dt(f.submitted_at) }}</span>
                    </div>
                    <div v-if="f.comment" class="text-body-2 mt-1">{{ f.comment }}</div>
                  </v-card>
                </div>
                <div v-else class="crm-empty py-8">
                  <v-icon size="40" color="medium-emphasis">mdi-emoticon-outline</v-icon>
                  <div class="text-body-2 font-weight-medium mt-2">No feedback</div>
                  <div class="text-caption text-medium-emphasis">No surveys or reviews recorded yet.</div>
                </div>
              </v-card-text>
            </v-window-item>
          </v-window>
        </v-card>

        <v-card v-if="profile?.notes" rounded="xl" border>
          <div class="d-flex align-center pa-4 pb-2" style="gap:10px">
            <v-icon color="primary">mdi-note-text-outline</v-icon>
            <div class="text-subtitle-1 font-weight-bold">Notes</div>
          </div>
          <v-divider />
          <v-card-text class="text-body-2">{{ profile.notes }}</v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- log activity -->
    <v-dialog v-model="logDialog" max-width="560">
      <v-card rounded="xl">
        <BrandDialogHeader
          icon="mdi-plus"
          :title="`Log activity — ${name}`"
          subtitle="Capture a touchpoint for this customer"
          @close="logDialog = false"
        />
        <v-card-text>
          <div class="d-flex ga-2 mb-2">
            <v-select v-model="logForm.kind" :items="interactionKinds" item-title="label" item-value="value" label="Type" variant="outlined" density="comfortable" />
            <v-select v-model="logForm.direction" :items="directions" item-title="label" item-value="value" label="Direction" variant="outlined" density="comfortable" />
          </div>
          <v-text-field v-model="logForm.subject" label="Subject *" variant="outlined" density="comfortable" class="mb-2" />
          <v-textarea v-model="logForm.summary" label="Notes" rows="3" auto-grow variant="outlined" density="comfortable" class="mb-2" />
          <v-select v-model="logForm.outcome" :items="outcomes" item-title="label" item-value="value" label="Outcome" variant="outlined" density="comfortable" class="mb-2" />
          <v-switch v-model="logForm.follow_up_required" color="primary" density="compact" hide-details label="Schedule follow-up" class="mb-2" />
          <v-text-field v-if="logForm.follow_up_required" v-model="logForm.follow_up_at" type="datetime-local" label="Follow-up at" variant="outlined" density="comfortable" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="logDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" rounded="lg" class="text-none" :loading="saving" @click="saveLog">Save activity</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- edit profile -->
    <v-dialog v-model="profileDialog" max-width="720" scrollable>
      <v-card rounded="xl">
        <BrandDialogHeader
          icon="mdi-pencil"
          title="Edit CRM profile"
          subtitle="Lifecycle, segmentation and credit settings"
          @close="profileDialog = false"
        />
        <v-card-text>
          <v-row dense>
            <v-col cols="12" md="4"><v-select v-model="editForm.lifecycle_stage" :items="lifecycleOptions" item-title="label" item-value="value" label="Lifecycle" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="4"><v-select v-model="editForm.segment" :items="segments" item-title="name" item-value="id" label="Segment" variant="outlined" density="comfortable" clearable /></v-col>
            <v-col cols="12" md="4"><v-select v-model="editForm.preferred_channel" :items="channelOptions" item-title="label" item-value="value" label="Preferred channel" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="4"><v-text-field v-model="editForm.company" label="Company" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="4"><v-text-field v-model="editForm.date_of_birth" type="date" label="Date of birth" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="12" md="4"><v-select v-model="editForm.lead_source" :items="sourceOptions" item-title="label" item-value="value" label="Lead source" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="4"><v-text-field v-model.number="editForm.credit_limit" type="number" step="0.01" label="Credit limit" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="4"><v-text-field v-model.number="editForm.outstanding_balance" type="number" step="0.01" label="Outstanding" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="4"><v-text-field v-model.number="editForm.payment_terms_days" type="number" label="Terms (days)" variant="outlined" density="comfortable" /></v-col>
            <v-col cols="6" md="4"><v-switch v-model="editForm.is_vip" color="amber" density="compact" hide-details label="VIP" /></v-col>
            <v-col cols="6" md="4"><v-switch v-model="editForm.marketing_opt_in" color="success" density="compact" hide-details label="Marketing opt-in" /></v-col>
            <v-col cols="6" md="4"><v-switch v-model="editForm.do_not_contact" color="error" density="compact" hide-details label="Do not contact" /></v-col>
            <v-col cols="12"><v-textarea v-model="editForm.notes" label="Notes" rows="2" auto-grow variant="outlined" density="comfortable" /></v-col>
          </v-row>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="profileDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" rounded="lg" class="text-none" :loading="saving" @click="saveProfile">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- points -->
    <v-dialog v-model="pointsDialog" max-width="460">
      <v-card rounded="xl">
        <BrandDialogHeader
          icon="mdi-star-circle-outline"
          title="Adjust loyalty points"
          subtitle="Earn, redeem or correct a balance"
          @close="pointsDialog = false"
        />
        <v-card-text>
          <v-select v-model="pointsForm.kind" :items="pointsKinds" item-title="label" item-value="value" label="Kind" variant="outlined" density="comfortable" class="mb-2" />
          <v-text-field v-model.number="pointsForm.points" type="number" label="Points (negative to deduct)" variant="outlined" density="comfortable" class="mb-2" />
          <v-text-field v-model="pointsForm.reason" label="Reason" variant="outlined" density="comfortable" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="pointsDialog = false">Cancel</v-btn>
          <v-btn color="deep-purple" variant="flat" rounded="lg" class="text-none" :loading="saving" @click="savePoints">Apply</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" rounded="lg" timeout="3600">{{ snack.text }}</v-snackbar>
  </v-container>
</template>

<script setup>
import { formatMoney } from '~/utils/format'
import {
  avatarColor, crmPriority, healthColor, initials, lifecycleMeta, riskColor,
  stageMeta, tierMeta, ticketStatus, useCrm,
} from '~/composables/useCrm'

definePageMeta({ layout: 'default' })

const route = useRoute()
const { $api } = useNuxtApp()
const brand = useBranding()
const { customer360, segments: fetchSegments, unpack } = useCrm()
const priorityMeta = crmPriority

const loading = ref(false)
const saving = ref(false)
const data = ref({})
const tab = ref('timeline')
const segments = ref([])
const snack = reactive({ show: false, color: 'success', text: '' })

const logDialog = ref(false)
const profileDialog = ref(false)
const pointsDialog = ref(false)

const logForm = reactive({
  kind: 'call', direction: 'outbound', subject: '', summary: '',
  outcome: 'connected', follow_up_required: false, follow_up_at: '',
})
const editForm = ref({})
const pointsForm = reactive({ kind: 'bonus', points: 0, reason: '' })

const lifecycleOptions = [
  { value: 'lead', label: 'Lead' }, { value: 'prospect', label: 'Prospect' },
  { value: 'active', label: 'Active' }, { value: 'at_risk', label: 'At risk' },
  { value: 'dormant', label: 'Dormant' }, { value: 'churned', label: 'Churned' },
]
const channelOptions = [
  { value: 'phone', label: 'Phone' }, { value: 'sms', label: 'SMS' },
  { value: 'email', label: 'Email' }, { value: 'whatsapp', label: 'WhatsApp' },
  { value: 'in_person', label: 'In person' },
]
const sourceOptions = [
  { value: 'walk_in', label: 'Walk-in' }, { value: 'referral', label: 'Referral' },
  { value: 'website', label: 'Website' }, { value: 'social', label: 'Social media' },
  { value: 'campaign', label: 'Campaign' }, { value: 'partner', label: 'Partner' },
  { value: 'outbound', label: 'Outbound' }, { value: 'other', label: 'Other' },
]
const interactionKinds = [
  { value: 'call', label: 'Phone call' }, { value: 'email', label: 'Email' },
  { value: 'sms', label: 'SMS' }, { value: 'whatsapp', label: 'WhatsApp' },
  { value: 'meeting', label: 'Meeting' }, { value: 'visit', label: 'Site visit' },
  { value: 'note', label: 'Note' }, { value: 'complaint', label: 'Complaint' },
]
const directions = [
  { value: 'inbound', label: 'Inbound' }, { value: 'outbound', label: 'Outbound' },
  { value: 'internal', label: 'Internal' },
]
const outcomes = [
  { value: 'connected', label: 'Connected' }, { value: 'no_answer', label: 'No answer' },
  { value: 'left_message', label: 'Left message' }, { value: 'resolved', label: 'Resolved' },
  { value: 'follow_up', label: 'Follow-up required' }, { value: 'no_action', label: 'No action' },
]
const pointsKinds = [
  { value: 'bonus', label: 'Bonus' }, { value: 'adjust', label: 'Adjustment' },
  { value: 'earn', label: 'Earned' }, { value: 'redeem', label: 'Redeemed' },
]

const heroTheme = computed(() => ({
  '--hero-deep': brand.secondary.value,
  '--hero-main': brand.primary.value,
  '--hero-accent': brand.gradientStops.value[2],
  '--hero-ink': brand.ink.value,
  '--hero-glow': brand.tint('primary', 0.3),
  '--hero-glow-2': brand.tint('accent', 0.2),
  '--hero-shadow': brand.shadow.value,
}))

const customer = computed(() => data.value.customer || {})
const profile = computed(() => data.value.profile || {})
const name = computed(() => customer.value.name || '')
const trend = computed(() => data.value.spend_trend || [])
const trendTotal = computed(() => trend.value.reduce((a, m) => a + (m.total || 0), 0))
const trendMax = computed(() => Math.max(1, ...trend.value.map((m) => m.total || 0)))
const openTickets = computed(() => (data.value.tickets || []).filter((t) => !['resolved', 'closed'].includes(t.status)))

const creditUsedPct = computed(() => {
  const limit = Number(profile.value.credit_limit) || 0
  const used = Number(profile.value.outstanding_balance) || 0
  if (!limit) return 0
  return Math.min(100, Math.round((used / limit) * 100))
})

const interactionMetaMap = {
  call: { label: 'Phone call', icon: 'mdi-phone-outline', color: '#2563eb' },
  email: { label: 'Email', icon: 'mdi-email-outline', color: '#4f46e5' },
  sms: { label: 'SMS', icon: 'mdi-message-text-outline', color: '#0891b2' },
  whatsapp: { label: 'WhatsApp', icon: 'mdi-whatsapp', color: '#16a34a' },
  meeting: { label: 'Meeting', icon: 'mdi-account-group-outline', color: '#7c3aed' },
  visit: { label: 'Site visit', icon: 'mdi-map-marker-outline', color: '#0d9488' },
  note: { label: 'Note', icon: 'mdi-note-text-outline', color: '#64748b' },
  complaint: { label: 'Complaint', icon: 'mdi-alert-outline', color: '#dc2626' },
}

function interactionLabel(k) { return interactionMetaMap[k]?.label || k }
function interactionIcon(k) { return interactionMetaMap[k]?.icon || 'mdi-note-outline' }
function interactionColor(k) { return interactionMetaMap[k]?.color || '#64748b' }

function titleCase(v) {
  return String(v || '').replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())
}

function dt(v) {
  if (!v) return '—'
  const d = new Date(v)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
}

function barHeight(v) {
  const n = Number(v) || 0
  return Math.max(3, Math.round((n / trendMax.value) * 100))
}

async function load() {
  loading.value = true
  try {
    const { data: d } = await customer360(route.params.id)
    data.value = d
    editForm.value = { ...d.profile }
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Failed to load customer' }
  } finally {
    loading.value = false
  }
}

async function loadLookups() {
  try {
    const seg = await fetchSegments({ page_size: 200 })
    segments.value = unpack(seg)
  } catch { /* optional */ }
}

function openLog() {
  logForm.subject = ''
  logForm.summary = ''
  logForm.follow_up_required = false
  logForm.follow_up_at = ''
  logDialog.value = true
}

async function saveLog() {
  if (!logForm.subject) {
    snack.value = { show: true, color: 'error', text: 'Subject is required' }
    return
  }
  saving.value = true
  try {
    const body = {
      customer: Number(route.params.id),
      kind: logForm.kind,
      direction: logForm.direction,
      subject: logForm.subject,
      summary: logForm.summary,
      outcome: logForm.outcome,
      follow_up_required: logForm.follow_up_required,
      occurred_at: new Date().toISOString(),
    }
    if (logForm.follow_up_required && logForm.follow_up_at) {
      body.follow_up_at = new Date(logForm.follow_up_at).toISOString()
    }
    await $api.post('/crm/interactions/', body)
    logDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Activity logged' }
    await load()
  } catch (e) {
    const d = e?.response?.data
    snack.value = { show: true, color: 'error', text: d && typeof d === 'object' ? Object.values(d).flat().join(' ') : 'Failed to log activity' }
  } finally {
    saving.value = false
  }
}

async function saveProfile() {
  if (!profile.value?.id) return
  saving.value = true
  try {
    const f = editForm.value
    await $api.patch(`/crm/profiles/${profile.value.id}/`, {
      lifecycle_stage: f.lifecycle_stage,
      segment: f.segment || null,
      preferred_channel: f.preferred_channel,
      lead_source: f.lead_source,
      company: f.company,
      date_of_birth: f.date_of_birth || null,
      credit_limit: Number(f.credit_limit) || 0,
      outstanding_balance: Number(f.outstanding_balance) || 0,
      payment_terms_days: Number(f.payment_terms_days) || 0,
      is_vip: !!f.is_vip,
      marketing_opt_in: !!f.marketing_opt_in,
      do_not_contact: !!f.do_not_contact,
      notes: f.notes,
    })
    profileDialog.value = false
    snack.value = { show: true, color: 'success', text: 'Profile updated' }
    await load()
  } catch (e) {
    const d = e?.response?.data
    snack.value = { show: true, color: 'error', text: d && typeof d === 'object' ? Object.values(d).flat().join(' ') : 'Failed to update profile' }
  } finally {
    saving.value = false
  }
}

async function savePoints() {
  if (!pointsForm.points) {
    snack.value = { show: true, color: 'error', text: 'Enter a non-zero point amount' }
    return
  }
  saving.value = true
  try {
    await $api.post('/crm/points/', {
      customer: Number(route.params.id),
      kind: pointsForm.kind,
      points: Number(pointsForm.points),
      reason: pointsForm.reason,
    })
    pointsDialog.value = false
    pointsForm.points = 0
    pointsForm.reason = ''
    snack.value = { show: true, color: 'success', text: 'Points adjusted' }
    await load()
  } catch (e) {
    snack.value = { show: true, color: 'error', text: e?.response?.data?.detail || 'Failed to adjust points' }
  } finally {
    saving.value = false
  }
}

async function resolveTicket(t) {
  try {
    await $api.post(`/crm/tickets/${t.id}/resolve/`, {})
    snack.value = { show: true, color: 'success', text: 'Ticket resolved' }
    await load()
  } catch {
    snack.value = { show: true, color: 'error', text: 'Failed to resolve ticket' }
  }
}

async function completeTask(t) {
  if (t.status === 'done') return
  try {
    await $api.post(`/crm/tasks/${t.id}/complete/`)
    snack.value = { show: true, color: 'success', text: 'Task completed' }
    await load()
  } catch {
    snack.value = { show: true, color: 'error', text: 'Failed to complete task' }
  }
}

onMounted(async () => {
  await loadLookups()
  await load()
})
</script>

<style scoped>
.crm-page { max-width: 1680px; margin: 0 auto; }
.crm-hero {
  position: relative; overflow: hidden; border-radius: 18px;
  padding: 20px 22px 16px; color: #fff;
  background: linear-gradient(120deg, var(--hero-deep, #143ce1) 0%, var(--hero-main, #2f6dff) 52%, var(--hero-accent, #37d6ff) 100%);
  box-shadow: var(--hero-shadow, 0 14px 34px rgba(47,109,255,.24));
}
.crm-hero-glow { position: absolute; width: 320px; height: 320px; border-radius: 50%; right: -100px; top: -160px; background: radial-gradient(circle, var(--hero-glow, rgba(255,255,255,.28)), transparent 68%); pointer-events: none; }
.crm-eyebrow { display: inline-flex; align-items: center; gap: 6px; font-size: 10px; font-weight: 700; letter-spacing: 1.4px; text-transform: uppercase; color: rgba(255,255,255,.78); }
.crm-title { font-size: 25px; line-height: 1.15; font-weight: 800; letter-spacing: -.2px; margin: 2px 0; }
.crm-sub { font-size: 13px; color: rgba(255,255,255,.82); }
.crm-hero-iconbtn { color: #fff !important; }
.crm-hero-btn-strong { background: #fff !important; color: var(--hero-ink, #143ce1) !important; font-weight: 700 !important; border: 1px solid rgba(255,255,255,.95) !important; }
.crm-hero-btn-glass { background: rgba(255,255,255,.16) !important; color: #fff !important; font-weight: 600 !important; border: 1px solid rgba(255,255,255,.34) !important; backdrop-filter: blur(6px); }
.crm-hero-facts { position: relative; display: flex; align-items: center; flex-wrap: wrap; gap: 18px; margin-top: 16px; padding-top: 14px; border-top: 1px solid rgba(255,255,255,.22); }
.crm-hero-fact-value { font-size: 18px; font-weight: 800; line-height: 1.1; }
.crm-hero-fact-label { font-size: 11px; color: rgba(255,255,255,.78); text-transform: uppercase; letter-spacing: .5px; }
.crm-hero-divider { width: 1px; height: 26px; background: rgba(255,255,255,.24); }
.crm-kv { display: flex; align-items: center; justify-content: space-between; gap: 10px; padding: 4px 0; font-size: 13px; }
.crm-kv span { color: rgba(var(--v-theme-on-surface), .62); }
.crm-stat { border: 1px solid rgba(var(--v-border-color), .16); border-radius: 12px; padding: 10px 12px; }
.crm-stat-label { font-size: 10px; text-transform: uppercase; letter-spacing: .4px; color: rgba(var(--v-theme-on-surface), .58); }
.crm-stat-value { font-size: 17px; font-weight: 800; }
.crm-spark { display: flex; align-items: flex-end; gap: 6px; height: 92px; }
.crm-spark-col { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: flex-end; height: 100%; gap: 4px; }
.crm-spark-bar { width: 100%; border-radius: 6px 6px 3px 3px; background: linear-gradient(180deg, rgba(13,148,136,.85), rgba(13,148,136,.35)); min-height: 3px; }
.crm-spark-label { font-size: 9.5px; color: rgba(var(--v-theme-on-surface), .55); }
.crm-timeline-item { display: flex; gap: 12px; padding: 8px 0; border-bottom: 1px solid rgba(var(--v-border-color), .1); }
.crm-timeline-item:last-child { border-bottom: none; }
.crm-timeline-dot { width: 26px; height: 26px; border-radius: 8px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.crm-task-row { display: flex; align-items: center; gap: 8px; padding: 6px 0; border-bottom: 1px solid rgba(var(--v-border-color), .1); }
.crm-task-row:last-child { border-bottom: none; }
.crm-table :deep(th) { font-size: 11px; text-transform: uppercase; letter-spacing: .4px; }
.crm-empty { display: flex; flex-direction: column; align-items: center; text-align: center; }
</style>
