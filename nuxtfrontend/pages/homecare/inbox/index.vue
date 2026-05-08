<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Inbox"
      subtitle="Messages from patients, caregivers and family members."
      eyebrow="COMMUNICATION"
      icon="mdi-inbox"
      :chips="[{ icon: 'mdi-bell', label: `${unread} unread` }]"
    />

    <v-row class="mt-1">
      <v-col cols="12" md="4">
        <HomecarePanel title="Threads" subtitle="Latest first" icon="mdi-message-text" color="#0d9488">
          <template #actions>
            <v-btn-toggle v-model="filter" density="compact" rounded="lg" color="teal" variant="outlined">
              <v-btn value="all" size="small" class="text-none">All</v-btn>
              <v-btn value="unread" size="small" class="text-none">Unread</v-btn>
            </v-btn-toggle>
          </template>
          <div class="hc-list" style="max-height:540px;overflow-y:auto;">
            <div v-for="t in filteredThreads" :key="t.id" class="hc-list-row"
                 :class="{ 'hc-list-row--active': active?.id === t.id }" @click="open(t)">
              <v-avatar size="40" color="teal" variant="tonal">
                <span class="font-weight-bold">{{ initials(t.title) }}</span>
              </v-avatar>
              <div class="flex-grow-1 min-w-0">
                <div class="d-flex align-center">
                  <div class="text-body-2 font-weight-bold text-truncate flex-grow-1">{{ t.title }}</div>
                  <span class="text-caption text-medium-emphasis">{{ formatRelative(t.updated_at) }}</span>
                </div>
                <div class="text-caption text-medium-emphasis text-truncate">{{ t.preview }}</div>
              </div>
              <v-badge v-if="!t.read" dot color="error" inline />
            </div>
            <EmptyState v-if="!filteredThreads.length" icon="mdi-inbox" title="Inbox empty" />
          </div>
        </HomecarePanel>
      </v-col>
      <v-col cols="12" md="8">
        <HomecarePanel
          :title="active?.title || 'Select a conversation'"
          :subtitle="active ? `with ${active.with || 'team'}` : ''"
          icon="mdi-chat"
          color="#0ea5e9"
        >
          <div v-if="active" class="hc-thread">
            <div v-for="m in messages" :key="m.id" class="hc-msg" :class="{ 'hc-msg--mine': m.is_mine }">
              <div class="hc-msg-bubble">
                <div class="text-body-2">{{ m.body }}</div>
                <div class="text-caption text-medium-emphasis mt-1">{{ formatRelative(m.created_at) }}</div>
              </div>
            </div>
          </div>
          <EmptyState v-else icon="mdi-chat-outline" title="No conversation selected" />
          <v-divider v-if="active" class="my-3" />
          <div v-if="active" class="d-flex ga-2">
            <v-text-field v-model="reply" placeholder="Type a message…" density="compact" variant="outlined" hide-details
                          @keydown.enter="send" />
            <v-btn color="teal" icon="mdi-send" @click="send" />
          </div>
        </HomecarePanel>
      </v-col>
    </v-row>
  </div>
</template>

<script setup>
const { $api } = useNuxtApp()
const threads = ref([])
const active = ref(null)
const messages = ref([])
const reply = ref('')
const filter = ref('all')

const unread = computed(() => threads.value.filter(t => !t.read).length)
const filteredThreads = computed(() => filter.value === 'unread'
  ? threads.value.filter(t => !t.read) : threads.value)

function initials(t) { return (t || '?').split(' ').slice(0,2).map(w => w[0]).join('').toUpperCase() }
function formatRelative(iso) {
  if (!iso) return ''
  const diff = (Date.now() - new Date(iso).getTime()) / 1000
  if (diff < 60) return 'now'
  if (diff < 3600) return `${Math.floor(diff/60)}m`
  if (diff < 86400) return `${Math.floor(diff/3600)}h`
  return `${Math.floor(diff/86400)}d`
}

async function load() {
  try {
    const { data } = await $api.get('/messaging/threads/', { params: { context: 'homecare' } })
    threads.value = data?.results || data || []
  } catch { threads.value = [] }
}
async function open(t) {
  active.value = t
  try {
    const { data } = await $api.get(`/messaging/threads/${t.id}/messages/`)
    messages.value = data?.results || data || []
  } catch { messages.value = [] }
}
async function send() {
  if (!reply.value.trim() || !active.value) return
  const body = reply.value
  reply.value = ''
  try {
    await $api.post(`/messaging/threads/${active.value.id}/messages/`, { body })
    open(active.value)
  } catch { /* */ }
}
onMounted(load)
</script>

<style scoped>
.hc-bg { background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%); min-height: calc(100vh - 64px); }
.hc-list { display: flex; flex-direction: column; gap: 4px; }
.hc-list-row {
  display: flex; align-items: center; gap: 12px;
  padding: 10px; border-radius: 10px; cursor: pointer;
  transition: background 0.15s ease;
}
.hc-list-row:hover { background: rgba(13,148,136,0.06); }
.hc-list-row--active { background: rgba(13,148,136,0.12); }
.hc-thread { display: flex; flex-direction: column; gap: 10px; max-height: 480px; overflow-y: auto; padding: 4px; }
.hc-msg { display: flex; }
.hc-msg--mine { justify-content: flex-end; }
.hc-msg-bubble {
  max-width: 70%; padding: 10px 14px; border-radius: 16px;
  background: rgba(15,23,42,0.05);
}
.hc-msg--mine .hc-msg-bubble {
  background: linear-gradient(135deg, #0d9488, #0284c7); color: white;
}
.hc-msg--mine .hc-msg-bubble .text-medium-emphasis { color: rgba(255,255,255,0.7) !important; }
.min-w-0 { min-width: 0; }
</style>
