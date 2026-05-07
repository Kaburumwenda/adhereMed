<template>
  <ResourceDetailPage :resource="r" title="Lab Order" icon="mdi-microscope" back-path="/lab-orders" :edit-path="`/lab-orders/${id}/edit`" :load-id="id">
    <template #default="{ item }">
      <v-card v-if="item" rounded="lg" class="pa-6">
        <div class="d-flex align-center justify-space-between mb-4">
          <div>
            <div class="text-h5 font-weight-bold">{{ item.test_name }}</div>
            <div class="text-body-2 text-medium-emphasis">{{ item.patient_name }}</div>
          </div>
          <StatusChip :status="item.status" />
        </div>
        <InfoGrid :item="item" :fields="[{key:'priority',label:'Priority'},{key:'notes',label:'Notes',md:12},{key:'results',label:'Results',md:12}]" />
      </v-card>
    </template>
  </ResourceDetailPage>
</template>

<script setup>
import { useResource } from '~/composables/useResource'
const route = useRoute()
const id = computed(() => route.params.id)
const r = useResource('/lab/orders/')
</script>
