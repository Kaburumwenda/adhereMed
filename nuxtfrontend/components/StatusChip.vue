<template>
  <v-chip
    :color="color"
    :variant="variant"
    size="small"
    :prepend-icon="icon"
    class="text-capitalize"
  >
    {{ label || (status || '').replace(/_/g, ' ') || '—' }}
  </v-chip>
</template>

<script setup>
const props = defineProps({
  status: { type: String, default: '' },
  label: { type: String, default: '' },
  variant: { type: String, default: 'tonal' }
})

const map = {
  active: { color: 'success', icon: 'mdi-check-circle' },
  pending: { color: 'warning', icon: 'mdi-clock-outline' },
  completed: { color: 'success', icon: 'mdi-check-circle' },
  cancelled: { color: 'error', icon: 'mdi-cancel' },
  canceled: { color: 'error', icon: 'mdi-cancel' },
  paid: { color: 'success', icon: 'mdi-cash-check' },
  unpaid: { color: 'warning', icon: 'mdi-cash-remove' },
  partial: { color: 'warning', icon: 'mdi-cash-clock' },
  draft: { color: 'grey', icon: 'mdi-file-document-edit' },
  open: { color: 'info', icon: 'mdi-folder-open' },
  closed: { color: 'grey', icon: 'mdi-folder' },
  in_progress: { color: 'info', icon: 'mdi-progress-clock' },
  scheduled: { color: 'info', icon: 'mdi-calendar-clock' },
  confirmed: { color: 'success', icon: 'mdi-calendar-check' },
  no_show: { color: 'error', icon: 'mdi-calendar-remove' },
  ordered: { color: 'info', icon: 'mdi-clipboard-text' },
  collected: { color: 'info', icon: 'mdi-test-tube' },
  resulted: { color: 'success', icon: 'mdi-file-chart' },
  approved: { color: 'success', icon: 'mdi-check' },
  rejected: { color: 'error', icon: 'mdi-close-circle' },
  dispensed: { color: 'success', icon: 'mdi-pill' },
  delivered: { color: 'success', icon: 'mdi-truck-check' },
  shipped: { color: 'info', icon: 'mdi-truck' },
  received: { color: 'success', icon: 'mdi-package-check' },
  returned: { color: 'error', icon: 'mdi-undo-variant' },
  partial: { color: 'warning', icon: 'mdi-progress-alert' },
  quoted: { color: 'info', icon: 'mdi-cash' },
  high: { color: 'error', icon: 'mdi-alert' },
  medium: { color: 'warning', icon: 'mdi-alert-outline' },
  low: { color: 'success', icon: 'mdi-check' },
  urgent: { color: 'error', icon: 'mdi-alert-octagon' },
  routine: { color: 'info', icon: 'mdi-clipboard-text' },
  stat: { color: 'error', icon: 'mdi-flash' }
}

const meta = computed(() => map[props.status] || { color: 'grey', icon: 'mdi-circle-medium' })
const color = computed(() => meta.value.color)
const icon = computed(() => meta.value.icon)
</script>
