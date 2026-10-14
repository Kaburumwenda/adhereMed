<template>
  <v-container fluid class="pa-3 pa-md-5">
    <div class="d-flex flex-wrap align-center justify-space-between mb-4">
      <div class="d-flex align-center" style="gap:14px">
        <v-avatar color="info" variant="tonal" rounded="lg" size="52">
          <v-icon size="28">mdi-share-variant</v-icon>
        </v-avatar>
        <div>
          <h1 class="text-h5 text-md-h4 font-weight-bold mb-0">Shared with Me</h1>
          <div class="text-body-2 text-medium-emphasis">Documents others have shared with you</div>
        </div>
      </div>
      <v-btn variant="tonal" prepend-icon="mdi-arrow-left" rounded="lg" class="text-none" @click="navigateTo('/documents')">Back to Documents</v-btn>
    </div>

    <v-card rounded="lg" elevation="0" class="overflow-hidden" style="border:1px solid rgba(0,0,0,0.06)">
      <v-progress-linear v-if="loading" color="primary" indeterminate />

      <div v-if="!loading && !items.length" class="pa-10 text-center text-medium-emphasis">
        <v-icon size="64" color="grey">mdi-share-variant-off</v-icon>
        <div class="text-h6 mt-3">No shared documents</div>
      </div>

      <div v-else class="table-wrap">
        <table class="inv-table">
          <thead>
            <tr>
              <th class="row-num">#</th>
              <th>Document</th>
              <th>Shared by</th>
              <th>Permission</th>
              <th>Shared on</th>
              <th class="text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(row, i) in items" :key="row.id" class="inv-row-click" @click="navigateTo(`/documents/${row.id}`)">
              <td class="row-num text-medium-emphasis">{{ i + 1 }}</td>
              <td>
                <div class="d-flex align-center" style="gap:10px">
                  <v-avatar color="info" variant="tonal" rounded="lg" size="34">
                    <v-icon size="18">mdi-file-document-outline</v-icon>
                  </v-avatar>
                  <div>
                    <div class="font-weight-medium">{{ row.title }}</div>
                    <div class="text-caption text-medium-emphasis">{{ row.reference_number || `DOC-${row.id}` }}</div>
                  </div>
                </div>
              </td>
              <td class="text-medium-emphasis">{{ row.uploaded_by_name || '—' }}</td>
              <td>
                <v-chip size="small" variant="tonal" color="info">{{ row.permission || 'view' }}</v-chip>
              </td>
              <td class="text-medium-emphasis">{{ formatStamp(row.created_at) }}</td>
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
const loading = ref(false)
const items = ref([])

onMounted(async () => {
  loading.value = true
  try {
    const { data } = await $api.get('/documents/documents/shared_with_me/')
    items.value = data?.results || data || []
  } catch (e) {
    console.error(e)
  } finally {
    loading.value = false
  }
})
</script>
