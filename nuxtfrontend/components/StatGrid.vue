<template>
  <v-row class="ma-0">
    <v-col v-for="s in stats" :key="s.title" cols="12" sm="6" :md="md">
      <v-card rounded="lg" class="stat-card-bar pa-4" :class="`stat-bar-${s.color}`">
        <!-- Top mini bar chart (sparkline-style) -->
        <div v-if="s.bars?.length" class="stat-bars mb-3">
          <div
            v-for="(b, i) in s.bars"
            :key="i"
            class="stat-bar-item"
            :style="{ height: `${barHeight(b, s.bars)}%` }"
            :class="{ 'stat-bar-active': i === s.bars.length - 1 }"
          />
        </div>
        <div class="d-flex align-center mb-2">
          <v-avatar size="40" :color="s.color" variant="tonal" class="mr-3">
            <v-icon :color="s.color">{{ s.icon }}</v-icon>
          </v-avatar>
          <div class="flex-1">
            <span class="text-body-2 text-medium-emphasis">{{ s.title }}</span>
            <div class="d-flex align-center ga-1">
              <span class="text-h4 font-weight-bold">{{ s.value }}</span>
              <v-chip
                v-if="s.trend != null"
                size="x-small"
                :color="s.trend > 0 ? 'success' : s.trend < 0 ? 'error' : 'grey'"
                variant="tonal"
                class="font-weight-bold"
              >
                <v-icon start size="12">{{ s.trend > 0 ? 'mdi-trending-up' : s.trend < 0 ? 'mdi-trending-down' : 'mdi-minus' }}</v-icon>
                {{ Math.abs(s.trend) }}%
              </v-chip>
            </div>
          </div>
        </div>
        <div v-if="s.hint" class="text-caption text-medium-emphasis mt-1">{{ s.hint }}</div>
      </v-card>
    </v-col>
  </v-row>
</template>

<script setup>
defineProps({
  stats: { type: Array, required: true },
  md: { type: [Number, String], default: 3 }
})

function barHeight(val, bars) {
  const max = Math.max(...bars, 1)
  const min = Math.min(...bars, 0)
  const range = max - min || 1
  return Math.max(8, ((val - min) / range) * 100)
}
</script>

<style scoped>
.stat-card-bar {
  position: relative;
  overflow: hidden;
}

.stat-bars {
  display: flex;
  align-items: flex-end;
  gap: 4px;
  height: 56px;
  padding: 2px 0;
}

.stat-bar-item {
  flex: 1;
  min-width: 6px;
  border-radius: 3px 3px 0 0;
  background: currentColor;
  opacity: 0.3;
  transition: opacity 0.2s ease, height 0.3s ease;
}

.stat-bar-active {
  opacity: 0.7;
  border-radius: 3px 3px 0 0;
}

.stat-bar-item:hover {
  opacity: 0.5;
}

/* Color-mapped bars */
.stat-bar-primary .stat-bar-item { color: rgb(var(--v-theme-primary)); }
.stat-bar-info .stat-bar-item { color: rgb(var(--v-theme-info)); }
.stat-bar-success .stat-bar-item { color: rgb(var(--v-theme-success)); }
.stat-bar-warning .stat-bar-item { color: rgb(var(--v-theme-warning)); }
.stat-bar-error .stat-bar-item { color: rgb(var(--v-theme-error)); }
.stat-bar-purple .stat-bar-item { color: rgb(var(--v-theme-purple)); }

/* Top accent bar */
.stat-card-bar::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 3px;
  opacity: 0.7;
}
.stat-bar-primary::before { background: rgb(var(--v-theme-primary)); }
.stat-bar-info::before { background: rgb(var(--v-theme-info)); }
.stat-bar-success::before { background: rgb(var(--v-theme-success)); }
.stat-bar-warning::before { background: rgb(var(--v-theme-warning)); }
.stat-bar-error::before { background: rgb(var(--v-theme-error)); }
.stat-bar-purple::before { background: rgb(var(--v-theme-purple)); }

.flex-1 { flex: 1; }
</style>
