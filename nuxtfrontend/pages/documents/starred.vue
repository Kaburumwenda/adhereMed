<template>
  <v-container fluid class="pa-3 pa-md-5">
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center" style="gap:14px">
        <v-avatar color="warning" variant="tonal" rounded="lg" size="52">
          <v-icon size="28">mdi-star</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 text-md-h4 font-weight-bold mb-0">Starred Documents</h1>
          <div class="text-body-2 text-medium-emphasis">Your favorite documents for quick access</div>
        </div>
      </div>
      <v-btn variant="tonal" prepend-icon="mdi-arrow-left" rounded="lg" class="text-none" @click="navigateTo('/documents')">Back to Documents</v-btn>
    </div>

    <v-card rounded="lg" elevation="0" class="overflow-hidden" style="border:1px solid rgba(0,0,0,0.06)">
      <v-progress-linear v-if="loading" color="primary" indeterminate />

      <div v-if="!loading && !items.length" class="pa-10 text-center text-medium-emphasis">
        <v-icon size="64" color="grey">mdi-star-off</v-icon>
        <div class="text-h6 mt-3">No starred documents</div>
        <div class="text-body-2">Star documents for quick access here.</div>
      </div>

      <div v-else class="table-wrap">
        <table class="inv-table">
          <thead>
            <tr>
              <th class="row-num">#</th>
              <th>Document</th>
              <th>Category</th>
              <th>Status</th>
              <th>Updated</th>
              <th class="text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(row, i) in items" :key="row.id" class="inv-row-click" @click="navigateTo(`/documents/${row.id}`)">
              <td class="row-num text-medium-emphasis">{{ i + 1 }}</td>
              <td>
                <div class="d-flex align-center" style="gap:10px">
                  <v-avatar color="warning" variant="tonal" rounded="lg" size="34">
                    <v-icon size="18">mdi-file-document-outline</v-icon>
                  </v-avatar>
                  <div>
                    <div class="font-weight-medium">{{ row.title }}</div>
                    <div class="text-caption text-medium-emphasis">{{ row.reference_number || `DOC-${row.id}` }}</div>
                  </div>
                </div>
              </td>
              <td>
                <v-chip v-if="row.category_name" size="x-small" variant="tonal" color="primary">{{ row.category_name }}</v-chip>
                <span v-else class="text-medium-emphasis text-caption">—</span>
              </td>
              <td>
                <span class="status-pill" :class="`status-${row.status}`">{{ statusLabel(row.status) }}</span>
              </td>
              <td class="text-medium-emphasis">{{ formatStamp(row.updated_at) }}</td>
              <td class="text-right">
                <v-btn variant="text" icon="mdi-eye-outline" size="small" @click.stop="navigateTo(`/documents/${row.id}`)" />
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

const { $api } = useNuxtApp()
const docRes = useResource('/documents/documents/')
const loading = computed(() => docRes.loading.value)
const items = ref([])

function statusLabel(s) {
  const map = { draft: 'Draft', in_review: 'In Review', approved: 'Approved', published: 'Published', archived: 'Archived', expired: 'Expired' }
  return map[s] || s
}

onMounted(async () => {
  try {
    const { data } = await $api.get('/documents/documents/starred/')
    items.value = data?.results || data || []
  } catch (e) { console.error(e) }
})
</script>

<style scoped>
.status-pill {
  display: inline-flex; align-items: center; gap: 4px;
  padding: 2px 10px; border-radius: 20px; font-size: 0.75rem; font-weight: 600; white-space: nowrap;
}
.status-draft { background: #f5f5f5; color: #666; }
.status-in_review { background: #fff8e1; color: #f57c00; }
.status-approved { background: #e8f5e9; color: #2e7d32; }
.status-published { background: #e3f2fd; color: #1565c0; }
.status-archived { background: #efebe9; color: #795548; }
.status-expired { background: #ffebee; color: #c62828; }
</style>
