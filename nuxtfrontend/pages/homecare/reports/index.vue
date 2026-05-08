<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Reports" icon="mdi-chart-box" subtitle="Operational analytics for your homecare service." />
    <StatGrid :stats="stats" :md="2" />
    <v-row class="mt-2">
      <v-col cols="12" md="8">
        <v-card rounded="xl" class="pa-4">
          <h3 class="text-h6 font-weight-bold mb-3">Adherence trend (last 7 days)</h3>
          <BarChart :values="trendValues" :labels="trendLabels" color="#0ea5a4" :height="240" />
        </v-card>
      </v-col>
      <v-col cols="12" md="4">
        <v-card rounded="xl" class="pa-4 text-center">
          <h3 class="text-h6 font-weight-bold mb-3">Today's dose status</h3>
          <DonutRing :segments="doseSegments" :size="180" :thickness="18">
            <div class="text-h4 font-weight-bold">{{ summary?.today_doses?.total || 0 }}</div>
          </DonutRing>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>
<script setup>
const { $api } = useNuxtApp()
const summary = ref(null)
const stats = computed(() => {
  const k = summary.value?.kpis || {}
  return [
    { title: 'Active patients', value: k.active_patients ?? 0, icon: 'mdi-account-multiple', color: 'teal' },
    { title: 'On duty', value: `${k.caregivers_on_duty ?? 0}/${k.caregivers_total ?? 0}`, icon: 'mdi-account-heart', color: 'indigo' },
    { title: 'Adherence today', value: k.adherence_today != null ? k.adherence_today + '%' : '—', icon: 'mdi-pill', color: 'success' },
    { title: 'Open escalations', value: k.open_escalations ?? 0, icon: 'mdi-alert', color: 'error' }
  ]
})
const trendValues = computed(() => (summary.value?.adherence_trend || []).map(d => d.rate))
const trendLabels = computed(() => (summary.value?.adherence_trend || []).map(d => d.date.slice(5)))
const doseSegments = computed(() => {
  const t = summary.value?.today_doses || {}
  return [
    { label: 'Taken', value: t.taken || 0, color: 'success' },
    { label: 'Pending', value: t.pending || 0, color: 'info' },
    { label: 'Missed', value: t.missed || 0, color: 'error' },
    { label: 'Skipped', value: t.skipped || 0, color: 'grey' }
  ]
})
onMounted(async () => {
  const { data } = await $api.get('/homecare/dashboard/summary/')
  summary.value = data
})
</script>
