<template>
  <v-container fluid class="pa-0 pa-md-4 d-flex flex-column" style="height: calc(100vh - 64px);">
    <v-toolbar density="compact" rounded="lg" class="ma-md-0 mx-md-4 mt-md-2">
      <v-btn icon="mdi-arrow-left" variant="text" to="/messages" />
      <v-avatar color="primary" variant="tonal" class="ml-1"><v-icon>mdi-account</v-icon></v-avatar>
      <v-toolbar-title class="ml-2">{{ conv?.other_party_name || 'Conversation' }}</v-toolbar-title>
    </v-toolbar>

    <v-card flat class="flex-grow-1 d-flex flex-column overflow-hidden mx-md-4 my-2" rounded="lg">
      <div ref="scroller" class="flex-grow-1 overflow-y-auto pa-4">
        <EmptyState v-if="!messages.length && !loading" icon="mdi-chat-outline" title="No messages yet" message="Send a message to start the conversation." />
        <div v-for="m in messages" :key="m.id" class="d-flex mb-2" :class="m.is_mine ? 'justify-end' : 'justify-start'">
          <v-card :color="m.is_mine ? 'primary' : 'surface-variant'" :variant="m.is_mine ? 'flat' : 'tonal'" rounded="lg" class="pa-3" max-width="75%">
            <div class="text-body-2">{{ m.content }}</div>
            <div class="text-caption text-medium-emphasis mt-1 text-right">{{ formatTime(m.created_at) }}</div>
          </v-card>
        </div>
      </div>

      <v-divider />
      <div class="pa-3 d-flex">
        <v-text-field v-model="text" placeholder="Type a message…" density="compact" variant="outlined" hide-details @keyup.enter="send" />
        <v-btn icon="mdi-send" color="primary" class="ml-2" :loading="sending" @click="send" />
      </div>
    </v-card>
  </v-container>
</template>

<script setup>
const route = useRoute()
const { $api } = useNuxtApp()
const id = computed(() => route.params.id)
const conv = ref(null)
const messages = ref([])
const text = ref('')
const sending = ref(false)
const loading = ref(true)
const scroller = ref(null)

async function load() {
  conv.value = await $api.get(`/messaging/conversations/${id.value}/`).then(r => r.data).catch(() => null)
  messages.value = await $api.get(`/messaging/conversations/${id.value}/messages/`).then(r => r.data?.results || r.data || []).catch(() => [])
  loading.value = false
  await nextTick()
  if (scroller.value) scroller.value.scrollTop = scroller.value.scrollHeight
}

async function send() {
  if (!text.value.trim()) return
  sending.value = true
  try {
    const res = await $api.post(`/messaging/conversations/${id.value}/messages/`, { content: text.value })
    messages.value.push({ ...res.data, is_mine: true })
    text.value = ''
    await nextTick()
    if (scroller.value) scroller.value.scrollTop = scroller.value.scrollHeight
  } finally { sending.value = false }
}

function formatTime(v) { return v ? new Date(v).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '' }

let timer
onMounted(() => {
  load()
  timer = setInterval(load, 8000)
})
onBeforeUnmount(() => clearInterval(timer))
</script>
