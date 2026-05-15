<template>
  <v-container fluid class="pa-3 pa-md-5">
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <h1 class="text-h5 font-weight-bold"><v-icon class="mr-1">mdi-bell</v-icon>Notifications</h1>
      <div class="d-flex" style="gap:8px">
        <v-btn variant="tonal" rounded="lg" class="text-none" @click="markAllRead">Mark All Read</v-btn>
        <v-btn variant="tonal" rounded="lg" class="text-none" prepend-icon="mdi-refresh" :loading="loading" @click="load">Refresh</v-btn>
      </div>
    </div>

    <v-card rounded="lg" border>
      <v-list v-if="notifications.length" class="bg-transparent">
        <v-list-item v-for="n in notifications" :key="n.id" :class="{ 'bg-blue-lighten-5': !n.read }" class="px-4">
          <template #prepend>
            <v-avatar :color="n.read ? 'grey' : 'primary'" variant="tonal" size="36">
              <v-icon size="20">{{ n.icon || 'mdi-bell' }}</v-icon>
            </v-avatar>
          </template>
          <v-list-item-title class="text-body-2" :class="{ 'font-weight-bold': !n.read }">{{ n.title || n.message }}</v-list-item-title>
          <v-list-item-subtitle class="text-caption">{{ formatDate(n.created_at) }}</v-list-item-subtitle>
          <template #append>
            <v-btn v-if="!n.read" icon="mdi-check" size="x-small" variant="text" @click="markRead(n.id)" />
          </template>
        </v-list-item>
      </v-list>
      <div v-else class="pa-6 text-center text-body-2 text-medium-emphasis">No notifications</div>
    </v-card>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()
const loading = ref(false)
const notifications = ref([])

function formatDate(d) { return d ? new Date(d).toLocaleString(undefined, { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }) : '—' }

async function markRead(id) {
  try { await $api.patch(`/notifications/${id}/`, { read: true }); await load() } catch { }
}
async function markAllRead() {
  try { await $api.post('/notifications/mark-all-read/'); await load() } catch { }
}

async function load() {
  loading.value = true
  try {
    const res = await $api.get('/notifications/?page_size=100&ordering=-created_at')
    notifications.value = res.data?.results || res.data || []
  } catch { notifications.value = [] }
  loading.value = false
}
onMounted(load)
</script>
