<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Mail"
      subtitle="Send and receive emails from the homecare team mailbox."
      eyebrow="COMMUNICATION"
      icon="mdi-email-multiple"
      :chips="[
        { icon: 'mdi-server', label: mailbox },
        { icon: 'mdi-email-outline', label: `${unreadCount} unread` }
      ]"
    >
      <template #actions>
        <v-btn variant="text" rounded="pill" color="white" prepend-icon="mdi-cog"
               class="text-none mr-2" to="/homecare/mail/settings">
          <span class="font-weight-medium">Settings</span>
        </v-btn>
        <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-pencil"
               class="text-none" @click="openCompose()">
          <span class="text-teal-darken-2 font-weight-bold">Compose</span>
        </v-btn>
      </template>
    </HomecareHero>

    <!-- Setup required prompt -->
    <v-row v-if="notConfigured" justify="center" class="mt-4">
      <v-col cols="12" md="8" lg="6">
        <v-card rounded="xl" elevation="2" class="pa-6 text-center">
          <v-avatar size="80" color="teal-lighten-5" class="mb-3">
            <v-icon icon="mdi-email-edit-outline" size="44" color="teal" />
          </v-avatar>
          <h2 class="text-h5 font-weight-bold mb-2">Mailbox not configured</h2>
          <p class="text-body-1 text-medium-emphasis mb-4">
            Before you can send or receive emails, an administrator needs to
            add this tenant's mail server credentials (IMAP &amp; SMTP).
          </p>
          <v-alert type="info" variant="tonal" rounded="lg" density="comfortable"
                   class="text-left mb-4">
            You'll need:
            <ul class="mt-1 ms-4">
              <li>Mailbox email address &amp; password</li>
              <li>IMAP host (incoming) and port — usually 993 with SSL</li>
              <li>SMTP host (outgoing) and port — usually 465 with SSL</li>
            </ul>
          </v-alert>
          <v-btn color="teal" variant="flat" size="large" rounded="lg"
                 prepend-icon="mdi-cog" class="text-none"
                 to="/homecare/mail/settings">
            Configure mailbox
          </v-btn>
        </v-card>
      </v-col>
    </v-row>

    <v-row v-else dense>
      <!-- Folders -->
      <v-col cols="12" md="3" lg="2">
        <HomecarePanel title="Folders" icon="mdi-folder-multiple" color="#0d9488">
          <v-list density="compact" class="bg-transparent pa-0" nav>
            <v-list-item
              v-for="f in folders" :key="f.name"
              :active="currentFolder === f.name"
              rounded="lg"
              @click="selectFolder(f.name)"
            >
              <template #prepend>
                <v-icon :icon="folderIcon(f.name)" />
              </template>
              <v-list-item-title>{{ folderLabel(f.name) }}</v-list-item-title>
              <template #append>
                <v-chip v-if="f.unread" size="x-small" color="teal" variant="flat">
                  {{ f.unread }}
                </v-chip>
              </template>
            </v-list-item>
            <v-list-item v-if="!folders.length" class="text-medium-emphasis">
              <v-list-item-title class="text-body-2">Loading…</v-list-item-title>
            </v-list-item>
          </v-list>
          <v-divider class="my-2" />
          <v-btn block variant="tonal" color="teal" rounded="lg"
                 class="text-none" prepend-icon="mdi-refresh"
                 :loading="loading" @click="refresh">Refresh</v-btn>
        </HomecarePanel>
      </v-col>

      <!-- Message list -->
      <v-col cols="12" md="4" lg="4">
        <HomecarePanel
          :title="folderLabel(currentFolder)"
          :subtitle="`${messages.length} of ${total} messages`"
          icon="mdi-email-search" color="#0ea5e9"
        >
          <template #actions>
            <v-text-field
              v-model="search" placeholder="Search…"
              prepend-inner-icon="mdi-magnify"
              density="compact" variant="outlined" hide-details rounded="lg"
              style="max-width:220px;" clearable
              @keydown.enter="loadMessages"
              @click:clear="(search = '') || loadMessages()"
            />
          </template>

          <div v-if="loading && !messages.length" class="text-center py-6">
            <v-progress-circular indeterminate color="teal" />
          </div>

          <EmptyState v-else-if="!messages.length"
            icon="mdi-email-off-outline" title="No messages"
            message="This folder is empty or no messages match your search."
          />

          <v-list v-else lines="three" class="bg-transparent pa-0"
                  style="max-height:70vh;overflow-y:auto;">
            <v-list-item
              v-for="m in messages" :key="m.uid"
              :active="active?.uid === m.uid"
              rounded="lg" class="mb-1 hc-mail-row"
              @click="openMessage(m)"
            >
              <template #prepend>
                <v-avatar size="38" :color="senderColor(m)" variant="tonal">
                  <span class="font-weight-bold">{{ initials(m) }}</span>
                </v-avatar>
              </template>
              <v-list-item-title :class="{ 'font-weight-bold': m.unread }">
                {{ senderName(m) || senderEmail(m) || '(unknown)' }}
              </v-list-item-title>
              <v-list-item-subtitle :class="{ 'font-weight-medium text-high-emphasis': m.unread }">
                {{ m.subject || '(no subject)' }}
              </v-list-item-subtitle>
              <template #append>
                <div class="text-caption text-medium-emphasis text-right">
                  <div>{{ formatDate(m.date) }}</div>
                  <v-icon v-if="m.unread" icon="mdi-circle" size="10" color="teal" class="mt-1" />
                </div>
              </template>
            </v-list-item>
          </v-list>
        </HomecarePanel>
      </v-col>

      <!-- Reading pane -->
      <v-col cols="12" md="5" lg="6">
        <HomecarePanel title="Message" icon="mdi-email-open" color="#6366f1">
          <EmptyState v-if="!active && !loadingMessage"
            icon="mdi-email-outline" title="Select a message"
            message="Pick a message from the list to read it here."
          />
          <div v-else-if="loadingMessage" class="text-center py-8">
            <v-progress-circular indeterminate color="teal" />
          </div>
          <div v-else>
            <div class="d-flex align-start ga-3 mb-3">
              <v-avatar size="44" :color="senderColor(active)" variant="tonal">
                <span class="font-weight-bold">{{ initials(active) }}</span>
              </v-avatar>
              <div class="flex-grow-1 min-w-0">
                <h3 class="text-h6 font-weight-bold mb-1">{{ active.subject || '(no subject)' }}</h3>
                <div class="text-body-2">
                  <strong>{{ senderName(active) || senderEmail(active) }}</strong>
                  <span v-if="senderName(active)" class="text-medium-emphasis">
                    &lt;{{ senderEmail(active) }}&gt;
                  </span>
                </div>
                <div class="text-caption text-medium-emphasis">
                  To: {{ recipientList(active.to) }}
                  <span v-if="active.cc?.length">· Cc: {{ recipientList(active.cc) }}</span>
                </div>
                <div class="text-caption text-medium-emphasis">{{ formatDate(active.date, true) }}</div>
              </div>
              <v-menu>
                <template #activator="{ props: p }">
                  <v-btn icon variant="text" v-bind="p"><v-icon icon="mdi-dots-vertical" /></v-btn>
                </template>
                <v-list density="compact">
                  <v-list-item @click="openCompose('reply')">
                    <template #prepend><v-icon icon="mdi-reply" /></template>
                    <v-list-item-title>Reply</v-list-item-title>
                  </v-list-item>
                  <v-list-item @click="openCompose('replyAll')">
                    <template #prepend><v-icon icon="mdi-reply-all" /></template>
                    <v-list-item-title>Reply all</v-list-item-title>
                  </v-list-item>
                  <v-list-item @click="openCompose('forward')">
                    <template #prepend><v-icon icon="mdi-share" /></template>
                    <v-list-item-title>Forward</v-list-item-title>
                  </v-list-item>
                  <v-divider />
                  <v-list-item @click="markUnread">
                    <template #prepend><v-icon icon="mdi-email-mark-as-unread" /></template>
                    <v-list-item-title>Mark unread</v-list-item-title>
                  </v-list-item>
                  <v-list-item @click="deleteActive" class="text-error">
                    <template #prepend><v-icon icon="mdi-delete" color="error" /></template>
                    <v-list-item-title>Delete</v-list-item-title>
                  </v-list-item>
                </v-list>
              </v-menu>
            </div>

            <v-divider class="mb-3" />

            <div v-if="active.body_html" class="hc-mail-html"
                 v-html="sanitizedHtml(active.body_html)" />
            <pre v-else class="hc-mail-text">{{ active.body_text || '(empty body)' }}</pre>

            <div v-if="active.attachments?.length" class="mt-4">
              <div class="text-subtitle-2 font-weight-bold mb-2">
                <v-icon icon="mdi-paperclip" class="mr-1" />
                Attachments ({{ active.attachments.length }})
              </div>
              <v-row dense>
                <v-col v-for="(a, i) in active.attachments" :key="i" cols="12" sm="6">
                  <v-card variant="outlined" rounded="lg" class="pa-3 d-flex align-center ga-3">
                    <v-icon :icon="fileIcon(a.type)" :color="fileColor(a.type)" size="32" />
                    <div class="flex-grow-1 min-w-0">
                      <div class="text-body-2 font-weight-bold text-truncate">{{ a.name }}</div>
                      <div class="text-caption text-medium-emphasis">
                        {{ a.type }} · {{ formatSize(a.size) }}
                      </div>
                    </div>
                    <v-btn icon variant="text" size="small" @click="downloadAttachment(a)">
                      <v-icon icon="mdi-download" />
                    </v-btn>
                  </v-card>
                </v-col>
              </v-row>
            </div>

            <div class="d-flex ga-2 mt-4">
              <v-btn variant="tonal" color="teal" rounded="lg" class="text-none"
                     prepend-icon="mdi-reply" @click="openCompose('reply')">Reply</v-btn>
              <v-btn variant="text" rounded="lg" class="text-none"
                     prepend-icon="mdi-reply-all" @click="openCompose('replyAll')">Reply all</v-btn>
              <v-btn variant="text" rounded="lg" class="text-none"
                     prepend-icon="mdi-share" @click="openCompose('forward')">Forward</v-btn>
            </div>
          </div>
        </HomecarePanel>
      </v-col>
    </v-row>

    <!-- ───── Compose dialog ───── -->
    <v-dialog v-model="composeOpen" max-width="780" scrollable persistent>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center">
          <v-icon icon="mdi-pencil" class="mr-2" color="teal" />
          {{ composeTitle }}
          <v-spacer />
          <v-btn icon variant="text" @click="composeOpen = false">
            <v-icon icon="mdi-close" />
          </v-btn>
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-text-field v-model="form.to" label="To" placeholder="name@example.com, …"
                        density="comfortable" variant="outlined" rounded="lg"
                        hide-details="auto" class="mb-2" />
          <div class="d-flex ga-2 mb-2">
            <v-btn v-if="!showCc" variant="text" size="small" class="text-none"
                   @click="showCc = true">+ Cc</v-btn>
            <v-btn v-if="!showBcc" variant="text" size="small" class="text-none"
                   @click="showBcc = true">+ Bcc</v-btn>
          </div>
          <v-text-field v-if="showCc" v-model="form.cc" label="Cc"
                        density="comfortable" variant="outlined" rounded="lg"
                        hide-details="auto" class="mb-2" />
          <v-text-field v-if="showBcc" v-model="form.bcc" label="Bcc"
                        density="comfortable" variant="outlined" rounded="lg"
                        hide-details="auto" class="mb-2" />
          <v-text-field v-model="form.subject" label="Subject"
                        density="comfortable" variant="outlined" rounded="lg"
                        hide-details="auto" class="mb-3" />
          <v-textarea v-model="form.body_text" label="Message"
                      rows="12" auto-grow variant="outlined" rounded="lg"
                      hide-details="auto" />

          <v-file-input
            v-model="form.files" multiple chips show-size counter
            label="Attachments (optional)"
            prepend-icon="mdi-paperclip" variant="outlined" rounded="lg"
            density="comfortable" class="mt-3" hide-details="auto"
          />
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-btn variant="text" rounded="lg" class="text-none"
                 @click="composeOpen = false">Cancel</v-btn>
          <v-spacer />
          <v-btn variant="flat" color="teal" rounded="lg" class="text-none"
                 prepend-icon="mdi-send" :loading="sending" @click="sendMail">
            Send
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3500">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
definePageMeta({ layout: 'default' })

const { $api } = useNuxtApp()

const folders = ref([])
const currentFolder = ref('INBOX')
const messages = ref([])
const total = ref(0)
const loading = ref(false)
const loadingMessage = ref(false)
const active = ref(null)
const search = ref('')
const notConfigured = ref(false)

const composeOpen = ref(false)
const composeMode = ref('new') // new | reply | replyAll | forward
const showCc = ref(false)
const showBcc = ref(false)
const sending = ref(false)
const form = reactive({ to: '', cc: '', bcc: '', subject: '', body_text: '', files: [] })

const snack = reactive({ show: false, text: '', color: 'info' })

const mailbox = computed(() => folders.value?.[0]?.name ? 'Mailbox connected' : 'Connecting…')
const unreadCount = computed(() =>
  folders.value.reduce((s, f) => s + (f.unread || 0), 0))

const composeTitle = computed(() => ({
  new: 'New message',
  reply: 'Reply',
  replyAll: 'Reply all',
  forward: 'Forward',
})[composeMode.value] || 'New message')

// ─────── helpers
function notify(text, color = 'info') {
  snack.text = text; snack.color = color; snack.show = true
}
function folderIcon(name) {
  const n = (name || '').toLowerCase()
  if (n.includes('sent')) return 'mdi-send'
  if (n.includes('draft')) return 'mdi-file-document-outline'
  if (n.includes('trash') || n.includes('deleted')) return 'mdi-trash-can'
  if (n.includes('spam') || n.includes('junk')) return 'mdi-email-alert'
  if (n.includes('archive')) return 'mdi-archive'
  return 'mdi-inbox'
}
function folderLabel(name) {
  if (!name) return 'Inbox'
  const map = { 'INBOX': 'Inbox', 'INBOX.Sent': 'Sent', 'Sent': 'Sent',
    'INBOX.Drafts': 'Drafts', 'Drafts': 'Drafts',
    'INBOX.Trash': 'Trash', 'Trash': 'Trash',
    'INBOX.Spam': 'Spam', 'Junk': 'Spam' }
  return map[name] || name
}
function senderName(m) { return m?.from?.[0]?.name || '' }
function senderEmail(m) { return m?.from?.[0]?.email || '' }
function initials(m) {
  const n = senderName(m) || senderEmail(m) || '?'
  return n.split(/[\s@.]+/).filter(Boolean).slice(0, 2)
    .map(p => p[0]?.toUpperCase()).join('') || '?'
}
function senderColor(m) {
  const colors = ['teal', 'indigo', 'purple', 'deep-orange', 'cyan', 'pink', 'green']
  const key = (senderEmail(m) || '').split('@')[0] || ''
  let h = 0
  for (let i = 0; i < key.length; i++) h = (h * 31 + key.charCodeAt(i)) >>> 0
  return colors[h % colors.length]
}
function recipientList(arr) {
  return (arr || []).map(a => a.name ? `${a.name} <${a.email}>` : a.email).join(', ')
}
function formatDate(iso, full = false) {
  if (!iso) return ''
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return iso
  if (full) return d.toLocaleString()
  const now = new Date()
  if (d.toDateString() === now.toDateString()) {
    return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
  }
  return d.toLocaleDateString([], { month: 'short', day: 'numeric' })
}
function formatSize(bytes) {
  if (!bytes) return '0 B'
  const u = ['B', 'KB', 'MB', 'GB']
  let i = 0; let n = bytes
  while (n >= 1024 && i < u.length - 1) { n /= 1024; i++ }
  return `${n.toFixed(n >= 10 || i === 0 ? 0 : 1)} ${u[i]}`
}
function fileIcon(type) {
  const t = (type || '').toLowerCase()
  if (t.startsWith('image/')) return 'mdi-image'
  if (t === 'application/pdf') return 'mdi-file-pdf-box'
  if (t.includes('word') || t.includes('document')) return 'mdi-file-word-box'
  if (t.includes('excel') || t.includes('sheet')) return 'mdi-file-excel-box'
  if (t.startsWith('text/')) return 'mdi-file-document-outline'
  return 'mdi-file-outline'
}
function fileColor(type) {
  const t = (type || '').toLowerCase()
  if (t.startsWith('image/')) return 'blue'
  if (t === 'application/pdf') return 'red'
  if (t.includes('word')) return 'indigo'
  if (t.includes('excel')) return 'green'
  return 'grey'
}
function sanitizedHtml(html) {
  if (!html) return ''
  // Strip script/style blocks and event handlers; remove javascript: URLs.
  let h = String(html)
  h = h.replace(/<\s*(script|style|iframe|object|embed)[^>]*>[\s\S]*?<\s*\/\s*\1\s*>/gi, '')
  h = h.replace(/\son\w+\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)/gi, '')
  h = h.replace(/\s(href|src)\s*=\s*("javascript:[^"]*"|'javascript:[^']*')/gi, ' $1="#"')
  return h
}

// ─────── data
async function loadFolders() {
  try {
    const { data } = await $api.get('/homecare/mail/folders/')
    folders.value = (data?.folders || [])
      .sort((a, b) => (a.name === 'INBOX' ? -1 : b.name === 'INBOX' ? 1 : a.name.localeCompare(b.name)))
    notConfigured.value = false
  } catch (e) {
    if (e.response?.status === 503) {
      notConfigured.value = true
    } else {
      notify(e.response?.data?.detail || 'Failed to load folders', 'error')
    }
  }
}

async function loadMessages() {
  if (notConfigured.value) return
  loading.value = true
  try {
    const { data } = await $api.get('/homecare/mail/messages/', {
      params: { folder: currentFolder.value, limit: 50, search: search.value || undefined },
    })
    messages.value = data?.items || []
    total.value = data?.total || 0
  } catch (e) {
    if (e.response?.status === 503) {
      notConfigured.value = true
    } else {
      notify(e.response?.data?.detail || 'Failed to load messages', 'error')
    }
  } finally {
    loading.value = false
  }
}

function selectFolder(name) {
  currentFolder.value = name
  active.value = null
  loadMessages()
}

async function openMessage(m) {
  loadingMessage.value = true
  active.value = { ...m }
  try {
    const { data } = await $api.get(`/homecare/mail/messages/${m.uid}/`, {
      params: { folder: currentFolder.value },
    })
    active.value = data
    // Locally mark seen
    const row = messages.value.find(x => x.uid === m.uid)
    if (row && row.unread) {
      row.unread = false
      const f = folders.value.find(x => x.name === currentFolder.value)
      if (f && f.unread) f.unread = Math.max(0, f.unread - 1)
    }
  } catch (e) {
    notify(e.response?.data?.detail || 'Failed to load message', 'error')
  } finally {
    loadingMessage.value = false
  }
}

async function markUnread() {
  if (!active.value) return
  try {
    await $api.post(`/homecare/mail/messages/${active.value.uid}/seen/`,
      { folder: currentFolder.value, seen: false })
    const row = messages.value.find(x => x.uid === active.value.uid)
    if (row) row.unread = true
    notify('Marked as unread', 'success')
  } catch (e) {
    notify(e.response?.data?.detail || 'Failed', 'error')
  }
}

async function deleteActive() {
  if (!active.value) return
  if (!confirm('Delete this message?')) return
  try {
    await $api.delete(`/homecare/mail/messages/${active.value.uid}/`, {
      params: { folder: currentFolder.value },
    })
    messages.value = messages.value.filter(x => x.uid !== active.value.uid)
    active.value = null
    notify('Message deleted', 'success')
  } catch (e) {
    notify(e.response?.data?.detail || 'Delete failed', 'error')
  }
}

async function refresh() {
  await Promise.all([loadFolders(), loadMessages()])
}

function downloadAttachment(a) {
  const link = document.createElement('a')
  link.href = `data:${a.type};base64,${a.data}`
  link.download = a.name || 'attachment'
  document.body.appendChild(link)
  link.click()
  link.remove()
}

// ─────── compose
function quoteBody(m) {
  const who = `${senderName(m) || ''} <${senderEmail(m)}>`.trim()
  const date = formatDate(m.date, true)
  const body = m.body_text || sanitizedHtml(m.body_html).replace(/<[^>]+>/g, '')
  return `\n\n--- On ${date}, ${who} wrote: ---\n` +
    body.split('\n').map(l => `> ${l}`).join('\n')
}

function openCompose(mode = 'new') {
  composeMode.value = mode
  showCc.value = false; showBcc.value = false
  form.to = ''; form.cc = ''; form.bcc = ''
  form.subject = ''; form.body_text = ''; form.files = []

  if (mode !== 'new' && active.value) {
    const a = active.value
    if (mode === 'reply') {
      form.to = senderEmail(a)
    } else if (mode === 'replyAll') {
      form.to = senderEmail(a)
      const ccs = (a.cc || []).map(x => x.email).filter(Boolean)
      const tos = (a.to || []).map(x => x.email).filter(Boolean)
      form.cc = [...tos, ...ccs].join(', ')
      if (form.cc) showCc.value = true
    } else if (mode === 'forward') {
      form.to = ''
    }
    const subj = a.subject || ''
    const prefix = mode === 'forward' ? 'Fwd: ' : 'Re: '
    form.subject = subj.toLowerCase().startsWith(prefix.toLowerCase().trim())
      ? subj : prefix + subj
    form.body_text = quoteBody(a)
    form._inReplyTo = a.message_id || ''
  }
  composeOpen.value = true
}

async function readFileAsBase64(file) {
  return new Promise((resolve, reject) => {
    const r = new FileReader()
    r.onload = () => {
      const result = String(r.result || '')
      const idx = result.indexOf(',')
      resolve({
        name: file.name,
        type: file.type || 'application/octet-stream',
        size: file.size,
        data: idx >= 0 ? result.slice(idx + 1) : result,
      })
    }
    r.onerror = reject
    r.readAsDataURL(file)
  })
}

async function sendMail() {
  if (!form.to.trim()) { notify('Please enter at least one recipient', 'warning'); return }
  sending.value = true
  try {
    const files = Array.isArray(form.files) ? form.files : (form.files ? [form.files] : [])
    const attachments = []
    for (const f of files) {
      // size guard 10 MB per file
      if (f.size > 10 * 1024 * 1024) {
        notify(`Attachment ${f.name} exceeds 10 MB`, 'warning')
        sending.value = false
        return
      }
      attachments.push(await readFileAsBase64(f))
    }
    await $api.post('/homecare/mail/send/', {
      to: form.to, cc: form.cc, bcc: form.bcc,
      subject: form.subject, body_text: form.body_text,
      attachments,
      in_reply_to: form._inReplyTo || undefined,
    })
    notify('Message sent', 'success')
    composeOpen.value = false
    if (currentFolder.value.toLowerCase().includes('sent')) loadMessages()
  } catch (e) {
    notify(e.response?.data?.detail || 'Failed to send message', 'error')
  } finally {
    sending.value = false
  }
}

onMounted(async () => {
  await loadFolders()
  await loadMessages()
})
</script>

<style scoped>
.hc-bg {
  background: linear-gradient(135deg, rgba(13,148,136,0.06) 0%, rgba(2,132,199,0.04) 100%);
  min-height: calc(100vh - 64px);
}
.hc-mail-row { background: white; border: 1px solid rgba(15,23,42,0.06); }
.hc-mail-row:hover { background: rgba(13,148,136,0.04); }
:global(.v-theme--dark) .hc-mail-row {
  background: rgb(30, 41, 59);
  border-color: rgba(255,255,255,0.08);
}
.hc-mail-text {
  white-space: pre-wrap;
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  font-size: 0.875rem;
  line-height: 1.5;
}
.hc-mail-html :deep(img) { max-width: 100%; height: auto; }
.hc-mail-html :deep(table) { max-width: 100%; }
.hc-mail-html :deep(a) { color: rgb(13,148,136); }
</style>
