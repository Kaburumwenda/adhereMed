<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width:920px;">
    <PageHeader :title="title" :icon="icon" :subtitle="subtitle">
      <template #actions>
        <v-btn
          variant="text"
          rounded="lg"
          class="text-none"
          prepend-icon="mdi-arrow-left"
          :to="backPath"
        >{{ $t('common.back') }}</v-btn>
      </template>
    </PageHeader>

    <v-card rounded="lg" class="pa-4 pa-md-6">
      <v-form ref="formRef" @submit.prevent="onSubmit">
        <slot :form="model" :errors="errors" />

        <v-alert v-if="topError" type="error" variant="tonal" density="compact" class="mt-4">
          {{ topError }}
        </v-alert>

        <div class="d-flex justify-end ga-2 mt-6">
          <v-btn variant="text" rounded="lg" class="text-none" :to="backPath">{{ $t('common.cancel') }}</v-btn>
          <v-btn
            type="submit"
            color="primary"
            rounded="lg"
            class="text-none"
            :loading="saving"
            prepend-icon="mdi-content-save"
          >{{ saveLabel || $t('common.save') }}</v-btn>
        </div>
      </v-form>
    </v-card>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { useI18n } from 'vue-i18n'
const { t } = useI18n()

const props = defineProps({
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
  icon: { type: String, default: '' },
  backPath: { type: String, required: true },
  resource: { type: Object, required: true },
  initial: { type: Object, default: () => ({}) },
  loadId: { type: [String, Number, null], default: null },
  saveLabel: { type: String, default: '' },
  transform: { type: Function, default: (v) => v }
})
const emit = defineEmits(['saved'])

const model = reactive({ ...props.initial })
const errors = ref({})
const saving = computed(() => props.resource.saving.value)
const topError = ref('')
const formRef = ref(null)
const snack = reactive({ show: false, color: 'success', text: '' })

onMounted(async () => {
  if (props.loadId) {
    const data = await props.resource.get(props.loadId)
    if (data) {
      Object.keys(props.initial).forEach(k => {
        if (data[k] !== undefined) model[k] = data[k]
      })
      // include any extra fields
      Object.keys(data).forEach(k => {
        if (model[k] === undefined) model[k] = data[k]
      })
    }
  }
})

async function onSubmit() {
  topError.value = ''
  errors.value = {}
  const v = await formRef.value.validate()
  if (v?.valid === false) return
  try {
    const payload = props.transform({ ...model })
    const result = props.loadId
      ? await props.resource.update(props.loadId, payload)
      : await props.resource.create(payload)
    snack.text = t('common.saved')
    snack.color = 'success'
    snack.show = true
    emit('saved', result)
  } catch (e) {
    const data = e?.response?.data
    if (data && typeof data === 'object' && !data.detail) errors.value = data
    topError.value = props.resource.error.value || t('common.saveFailed')
  }
}
</script>
