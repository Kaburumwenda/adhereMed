<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader title="Messages" subtitle="Internal messaging" icon="mdi-chat" color="primary">
      <template #actions>
        <v-btn color="primary" rounded="lg" prepend-icon="mdi-plus" @click="dialog = true">New Message</v-btn>
      </template>
    </PageHeader>

    <v-row dense>
      <v-col cols="12" md="4">
        <v-card rounded="lg" max-height="600" class="overflow-y-auto">
          <v-list density="compact">
            <v-list-item v-for="m in r.filtered.value" :key="m.id" :active="selected?.id === m.id" @click="selected = m"
              :prepend-icon="m.is_read ? 'mdi-email-open' : 'mdi-email'" :subtitle="formatDateTime(m.created_at)">
              <v-list-item-title>{{ m.subject || m.title || 'No subject' }}</v-list-item-title>
              <v-list-item-subtitle>{{ m.sender_name || m.sender || '—' }}</v-list-item-subtitle>
              <template v-if="!m.is_read" #append><v-chip size="x-small" color="primary" variant="tonal">New</v-chip></template>
            </v-list-item>
            <div v-if="!r.loading.value && !r.items.value.length" class="text-center pa-8 text-medium-emphasis">
              No messages
            </div>
          </v-list>
        </v-card>
      </v-col>
      <v-col cols="12" md="8">
        <v-card rounded="lg" min-height="400" class="pa-4" v-if="selected">
          <div class="d-flex align-center justify-space-between mb-3">
            <h3 class="text-h6 font-weight-bold">{{ selected.subject || selected.title || 'No subject' }}</h3>
            <v-chip v-if="!selected.is_read" size="small" color="primary" variant="tonal">Unread</v-chip>
          </div>
          <div class="text-caption text-medium-emphasis mb-2">From: {{ selected.sender_name || selected.sender || '—' }} • {{ formatDateTime(selected.created_at) }}</div>
          <v-divider class="mb-3" />
          <div class="text-body-1" style="white-space: pre-wrap;">{{ selected.body || selected.content || selected.message || '—' }}</div>
          <v-divider class="my-3" />
          <v-btn variant="text" prepend-icon="mdi-reply" @click="dialog = true; replyTo = selected">Reply</v-btn>
          <v-btn variant="text" color="error" prepend-icon="mdi-delete" @click="deleteMsg(selected)">Delete</v-btn>
        </v-card>
        <v-card v-else rounded="lg" min-height="400" class="d-flex align-center justify-center">
          <div class="text-center text-medium-emphasis">
            <v-icon size="64" class="mb-2">mdi-email-outline</v-icon>
            <div class="text-h6">Select a message to read</div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <v-dialog v-model="dialog" max-width="600">
      <v-card rounded="lg">
        <v-card-title class="text-h6">{{ replyTo ? 'Reply' : 'New Message' }}</v-card-title>
        <v-card-text>
          <v-form>
            <v-text-field v-if="!replyTo" v-model="msgForm.recipient" label="To (user email or ID)" variant="outlined" density="compact" class="mb-2" />
            <v-text-field v-model="msgForm.subject" label="Subject" variant="outlined" density="compact" class="mb-2" />
            <v-textarea v-model="msgForm.body" label="Message" variant="outlined" density="compact" rows="4" />
          </v-form>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="dialog = false; replyTo = null">Cancel</v-btn>
          <v-btn color="primary" :loading="r.saving.value" @click="send">Send</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup>
import { formatDateTime } from '~/utils/format'
const r = useResource('/messaging/messages/')
const { $api } = useNuxtApp()
const selected = ref(null)
const dialog = ref(false)
const replyTo = ref(null)
const msgForm = reactive({ recipient: '', subject: '', body: '' })
onMounted(() => r.list({ page_size: 1000 }))

async function send() {
  try {
    const payload = { ...msgForm }
    if (replyTo.value) payload.subject = 'Re: ' + (replyTo.value.subject || '')
    await r.create(payload)
    dialog.value = false
    replyTo.value = null
    Object.assign(msgForm, { recipient: '', subject: '', body: '' })
    r.list({ page_size: 1000 })
  } catch {}
}
async function deleteMsg(m) {
  try { await r.remove(m.id); selected.value = null; r.list({ page_size: 1000 }) } catch {}
}
</script>
