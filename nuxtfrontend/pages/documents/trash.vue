<template>
  <v-container fluid class="pa-3 pa-md-5">
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center" style="gap:14px">
        <v-avatar color="error" variant="tonal" rounded="lg" size="52">
          <v-icon size="28">mdi-trash-can</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 text-md-h4 font-weight-bold mb-0">Trash</h1>
          <div class="text-body-2 text-medium-emphasis">Deleteddocuments can be restored or permanently removed</div>
        </div>
      </div>
      <v-btn variant="tonal" prepend-icon="mdi-arrow-left" rounded="lg" class="text-none" @click="navigateTo('/documents')">Back to Documents</v-btn>
    </div>

    <v-card rounded="lg" elevation="0" class="overflow-hidden" style="border:1px solid rgba(0,0,0,0.06)">
      <v-progress-linear v-if="loading" color="primary" indeterminate />

      <div v-if="!loading && !items.length" class="pa-10 text-center text-medium-emphasis">
        <v-icon size="64" color="grey">mdi-trash-can-off</v-icon>
        <div class="text-h6 mt-3">Trash is empty</div>
      </div>

      <div v-else class="table-wrap">
        <table class="inv-table">
          <thead>
            <tr>
              <th class="row-num">#</th>
              <th>Document</th>
              <th>Deleted at</th>
              <th class="text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(row, i) in items" :key="row.id">
              <td class="row-num text-medium-emphasis">{{ i + 1 }}</td>
              <td>
                <div class="d-flex align-center" style="gap:10px">
                  <v-avatar color="grey" variant="tonal" rounded="lg" size="34">
                    <v-icon size="18">mdi-file-document-outline</v-icon>
                  </v-avatar>
                  <div>
                    <div class="font-weight-medium">{{ row.title }}</div>
                    <div class="text-caption text-medium-emphasis">{{ row.reference_number || `DOC-${row.id}` }}</div>
                  </div>
                </div>
              </td>
              <td class="text-medium-emphasis">{{ formatStamp(row.deleted_at) }}</td>
              <td class="text-right">
                <v-menu offset="4">
                  <template #activator="{ props }">
                    <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" />
                  </template>
                  <v-list density="compact" min-width="180">
                    <v-list-item prepend-icon="mdi-restore" title="Restore" @click="restoreDoc(row)" />
                    <v-list-item v-if="canDelete" prepend-icon="mdi-delete-forever" title="Delete permanently" @click="purgeDoc(row)" />
                  </v-list>
                </v-menu>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </v-card>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useResource } from '~/composables/useResource'
import { formatStamp } from '~/utils/format'
import { useAuthStore } from '~/stores/auth'
import { ADMIN_ROLES } from '~/utils/permissions'

const auth = useAuthStore()
const canDelete = computed(() => ADMIN_ROLES.has(auth.role))
const { $api } = useNuxtApp()

const loading = ref(false)
const items = ref([])

async function reload() {
  loading.value = true
  try {
    const { data } = await $api.get('/documents/documents/trash/')
    items.value = data?.results || data || []
  } catch (e) {
    console.error(e)
  } finally {
    loading.value = false
  }
}

onMounted(reload)

async function restoreDoc(row) {
  try {
    await $api.post(`/documents/documents/${row.id}/restore/`)
    reload()
  } catch (e) { console.error(e) }
}

async function purgeDoc(row) {
  if (!confirm('Permanently delete this document? This cannot be undone.')) return
  try {
    await $api.delete(`/documents/documents/${row.id}/`)
    reload()
  } catch (e) { console.error(e) }
}
</script>
