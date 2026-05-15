<template>
  <v-container fluid class="pa-3 pa-md-5">
    <!-- Header -->
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div>
        <h1 class="text-h5 text-md-h4 font-weight-bold mb-1">{{ $t('reports.title') }}</h1>
        <div class="text-body-2 text-medium-emphasis">{{ rangeLabel }} · select a report to open</div>
      </div>
      <div class="d-flex align-center mt-2 mt-md-0" style="gap:8px">
        <v-select
          v-model="rangeKey"
          :items="rangeOptions"
          item-title="label"
          item-value="key"
          density="compact"
          variant="outlined"
          color="primary"
          rounded="lg"
          hide-details
          prepend-inner-icon="mdi-calendar-range"
          style="min-width: 220px"
          @update:model-value="onRangeChange"
        />
      </div>
    </div>

    <!-- Custom range dialog -->
    <v-dialog v-model="customDialog" max-width="420">
      <v-card rounded="lg">
        <v-card-title class="text-h6">Custom date range</v-card-title>
        <v-card-text>
          <v-text-field v-model="customStart" label="Start date" type="date" variant="outlined" density="compact" hide-details class="mb-3" />
          <v-text-field v-model="customEnd" label="End date" type="date" variant="outlined" density="compact" hide-details />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" class="text-none" @click="customDialog = false">{{ $t('common.cancel') }}</v-btn>
          <v-btn color="primary" variant="flat" class="text-none" :disabled="!customStart || !customEnd" @click="applyCustom">Apply</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Report catalog -->
    <v-row dense>
      <v-col v-for="r in reports" :key="r.key" cols="12" sm="6" md="4">
        <v-card
          rounded="lg"
          class="pa-4 h-100 report-card"
          hover
          @click="openReport(r.key)"
        >
          <div class="d-flex align-start">
            <v-avatar :color="r.color" variant="tonal" rounded="lg" size="48" class="mr-3">
              <v-icon :color="r.color">{{ r.icon }}</v-icon>
            </v-avatar>
            <div class="flex-grow-1">
              <h3 class="text-subtitle-1 font-weight-bold">{{ r.label }}</h3>
              <p class="text-body-2 text-medium-emphasis mb-0">{{ r.desc }}</p>
            </div>
          </div>
          <div class="d-flex align-center mt-3" style="gap:6px">
            <v-chip size="x-small" variant="tonal" color="grey">{{ r.scope }}</v-chip>
            <v-spacer />
            <v-btn variant="text" size="small" class="text-none" append-icon="mdi-arrow-right" @click.stop="openReport(r.key)">Open</v-btn>
          </div>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

import { ref, computed } from 'vue'
import { REPORT_CATALOG, RANGE_OPTIONS, resolveRange, startOfDay, addDays } from '~/utils/reportsCatalog'

const router = useRouter()

const reports = REPORT_CATALOG
const rangeOptions = RANGE_OPTIONS

const rangeKey = ref('30d')
const customDialog = ref(false)
const customStart = ref('')
const customEnd = ref('')
const customRange = ref(null)

const activeRange = computed(() => resolveRange(rangeKey.value, customRange.value))
const rangeLabel = computed(() => activeRange.value.label)

function onRangeChange(val) {
  if (val === 'custom') {
    if (!customStart.value) customStart.value = activeRange.value.start.toISOString().slice(0, 10)
    if (!customEnd.value) customEnd.value = addDays(activeRange.value.end, -1).toISOString().slice(0, 10)
    customDialog.value = true
  }
}
function applyCustom() {
  const s = startOfDay(new Date(customStart.value))
  const e = addDays(startOfDay(new Date(customEnd.value)), 1)
  if (e <= s) return
  const fmt = (d) => d.toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' })
  customRange.value = { start: s, end: e, label: `${fmt(s)} – ${fmt(addDays(e, -1))}` }
  rangeKey.value = 'custom'
  customDialog.value = false
}

function openReport(key) {
  const query = { range: rangeKey.value }
  if (rangeKey.value === 'custom' && customRange.value) {
    query.start = customStart.value
    query.end = customEnd.value
  }
  router.push({ path: `/reports/${key}`, query })
}
</script>

<style scoped>
.report-card { transition: transform 0.15s ease, box-shadow 0.15s ease, border-color 0.15s ease; cursor: pointer; border: 1px solid transparent; }
.report-card:hover { transform: translateY(-2px); box-shadow: 0 6px 18px rgba(0,0,0,0.06); border-color: rgba(var(--v-theme-primary), 0.4); }
</style>
