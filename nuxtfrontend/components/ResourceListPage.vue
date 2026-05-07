<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader v-if="showHeader" :title="title" :icon="icon" :subtitle="subtitle">
      <template #actions>
        <v-btn
          v-if="createPath || $slots['create-action']"
          color="primary"
          rounded="lg"
          class="text-none"
          prepend-icon="mdi-plus"
          :to="createPath"
        >
          {{ createLabel }}
        </v-btn>
        <slot name="create-action" />
      </template>
    </PageHeader>

    <v-card rounded="lg">
      <v-card-text class="pb-0">
        <v-text-field
          v-model="resource.search.value"
          prepend-inner-icon="mdi-magnify"
          placeholder="Search…"
          variant="outlined"
          density="compact"
          hide-details
          clearable
          class="mb-2"
        />
      </v-card-text>

      <v-data-table
        :headers="headers"
        :items="resource.filtered.value"
        :loading="resource.loading.value"
        :items-per-page="20"
        item-value="id"
        class="elevation-0"
      >
        <template #loading>
          <v-skeleton-loader type="table-row@5" />
        </template>

        <template v-for="slot in slotNames" #[slot.key]="scope" :key="slot.key">
          <slot :name="slot.name" v-bind="scope" />
        </template>

        <template v-if="rowClick || $slots.actions" #item.actions="{ item }">
          <div class="d-flex justify-end">
            <slot name="actions" :item="item">
              <v-btn
                v-if="detailPath"
                icon="mdi-eye"
                variant="text"
                size="small"
                @click.stop="$router.push(detailPath(item))"
              />
              <v-btn
                v-if="editPath"
                icon="mdi-pencil"
                variant="text"
                size="small"
                @click.stop="$router.push(editPath(item))"
              />
              <v-btn
                v-if="deletable"
                icon="mdi-delete"
                variant="text"
                size="small"
                color="error"
                @click.stop="confirmDelete(item)"
              />
            </slot>
          </div>
        </template>

        <template #no-data>
          <EmptyState
            :icon="emptyIcon"
            :title="emptyTitle"
            :message="emptyMessage"
          />
        </template>
      </v-data-table>
    </v-card>

    <v-dialog v-model="deleteDialog" max-width="420">
      <v-card rounded="lg">
        <v-card-title>Delete {{ singular }}?</v-card-title>
        <v-card-text>This action cannot be undone.</v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog = false">Cancel</v-btn>
          <v-btn color="error" :loading="resource.saving.value" @click="doDelete">Delete</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snackbar.show" :color="snackbar.color" location="top right" timeout="3000">
      {{ snackbar.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useSlots } from 'vue'

const props = defineProps({
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
  icon: { type: String, default: '' },
  resource: { type: Object, required: true },
  headers: { type: Array, required: true },
  createPath: { type: String, default: '' },
  createLabel: { type: String, default: 'New' },
  detailPath: { type: Function, default: null },
  editPath: { type: Function, default: null },
  deletable: { type: Boolean, default: true },
  singular: { type: String, default: 'item' },
  emptyIcon: { type: String, default: 'mdi-inbox-outline' },
  emptyTitle: { type: String, default: 'No records yet' },
  emptyMessage: { type: String, default: '' },
  rowClick: { type: Boolean, default: false },
  showHeader: { type: Boolean, default: true }
})

const slots = useSlots()
const slotNames = computed(() =>
  Object.keys(slots)
    .filter(n => n.startsWith('cell-'))
    .map(n => ({ name: n, key: 'item.' + n.slice(5) }))
)

const deleteDialog = ref(false)
const target = ref(null)
const snackbar = reactive({ show: false, color: 'success', text: '' })

function confirmDelete(item) {
  target.value = item
  deleteDialog.value = true
}

async function doDelete() {
  try {
    await props.resource.remove(target.value.id)
    snackbar.text = `${props.singular} deleted`
    snackbar.color = 'success'
  } catch (e) {
    snackbar.text = props.resource.error.value || 'Delete failed'
    snackbar.color = 'error'
  }
  snackbar.show = true
  deleteDialog.value = false
}

onMounted(() => props.resource.list())
</script>
