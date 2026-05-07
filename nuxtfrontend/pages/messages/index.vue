<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Messages" icon="mdi-chat" subtitle="Your conversations" />
    <v-card rounded="lg">
      <v-list lines="two">
        <EmptyState v-if="!conversations.length && !loading" icon="mdi-chat-outline" title="No conversations" message="Start a conversation by messaging a doctor." />
        <v-list-item v-for="c in conversations" :key="c.id" :to="`/messages/${c.id}`">
          <template #prepend>
            <v-avatar color="primary" variant="tonal"><v-icon>mdi-account</v-icon></v-avatar>
          </template>
          <v-list-item-title>{{ c.other_party_name || 'Conversation' }}</v-list-item-title>
          <v-list-item-subtitle class="text-truncate">{{ c.last_message || 'No messages yet' }}</v-list-item-subtitle>
          <template #append>
            <div class="text-caption text-medium-emphasis">{{ formatDateTime(c.last_message_at) }}</div>
          </template>
        </v-list-item>
      </v-list>
    </v-card>
  </v-container>
</template>

<script setup>
import { formatDateTime } from '~/utils/format'
const { $api } = useNuxtApp()
const conversations = ref([])
const loading = ref(true)
onMounted(async () => {
  conversations.value = await $api.get('/messaging/conversations/').then(r => r.data?.results || r.data || []).catch(() => [])
  loading.value = false
})
</script>
