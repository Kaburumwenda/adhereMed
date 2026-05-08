<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 960px;">
    <PageHeader :title="isEdit ? 'Edit Tenant' : 'New Tenant'" icon="mdi-domain">
      <template #actions>
        <v-btn
          variant="text"
          rounded="lg"
          class="text-none"
          prepend-icon="mdi-arrow-left"
          to="/superadmin/tenants"
        >Back</v-btn>
      </template>
    </PageHeader>

    <v-form ref="formRef" @submit.prevent="onSubmit">
      <!-- Tenant Information -->
      <v-card rounded="lg" variant="outlined" class="mb-4 overflow-hidden">
        <div class="px-4 py-3 d-flex align-center" style="background-color: rgba(var(--v-theme-primary), 0.08);">
          <v-icon icon="mdi-office-building" size="18" color="primary" class="mr-2" />
          <span class="text-subtitle-2 font-weight-bold text-primary">Tenant Information</span>
        </div>
        <div class="pa-4">
          <v-row dense>
            <v-col cols="12">
              <v-text-field
                v-model="form.name"
                label="Facility Name *"
                :rules="req"
                variant="outlined"
                density="comfortable"
                @update:model-value="onNameChange"
              />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field
                v-model="form.slug"
                label="Slug *"
                hint="e.g. city_hospital"
                persistent-hint
                :rules="req"
                :disabled="isEdit"
                variant="outlined"
                density="comfortable"
                @update:model-value="onSlugInput"
              />
            </v-col>
            <v-col cols="12" sm="6">
              <v-select
                v-model="form.type"
                :items="typeOptions"
                label="Type *"
                :rules="req"
                :disabled="isEdit"
                variant="outlined"
                density="comfortable"
              />
            </v-col>
            <v-col v-if="!isEdit" cols="12">
              <v-text-field
                v-model="form.domain"
                label="Domain *"
                hint="e.g. city_hospital.adheremed.com"
                persistent-hint
                :rules="req"
                variant="outlined"
                density="comfortable"
              />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field
                v-model="form.city"
                label="City"
                variant="outlined"
                density="comfortable"
              />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field
                v-model="form.country"
                label="Country"
                variant="outlined"
                density="comfortable"
              />
            </v-col>
            <v-col cols="12">
              <v-textarea
                v-model="form.address"
                label="Address"
                rows="2"
                auto-grow
                variant="outlined"
                density="comfortable"
              />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field
                v-model="form.phone"
                label="Phone"
                type="tel"
                variant="outlined"
                density="comfortable"
              />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field
                v-model="form.email"
                label="Email"
                type="email"
                variant="outlined"
                density="comfortable"
              />
            </v-col>
            <v-col cols="12">
              <v-text-field
                v-model="form.website"
                label="Website"
                placeholder="https://"
                variant="outlined"
                density="comfortable"
              />
            </v-col>
            <v-col v-if="isEdit" cols="12">
              <v-switch
                v-model="form.is_active"
                label="Active"
                color="primary"
                inset
                hide-details
              />
            </v-col>
          </v-row>
        </div>
      </v-card>

      <!-- Admin User (create only) -->
      <v-card v-if="!isEdit" rounded="lg" variant="outlined" class="mb-4 overflow-hidden">
        <div class="px-4 py-3 d-flex align-center" style="background-color: rgba(var(--v-theme-secondary), 0.08);">
          <v-icon icon="mdi-shield-account" size="18" color="secondary" class="mr-2" />
          <span class="text-subtitle-2 font-weight-bold text-secondary">Admin User</span>
        </div>
        <div class="pa-4">
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-text-field
                v-model="form.admin_first_name"
                label="First Name *"
                :rules="req"
                variant="outlined"
                density="comfortable"
              />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field
                v-model="form.admin_last_name"
                label="Last Name *"
                :rules="req"
                variant="outlined"
                density="comfortable"
              />
            </v-col>
            <v-col cols="12">
              <v-text-field
                v-model="form.admin_email"
                label="Admin Email *"
                type="email"
                :rules="req"
                variant="outlined"
                density="comfortable"
              />
            </v-col>
            <v-col cols="12">
              <v-text-field
                v-model="form.admin_password"
                label="Password (leave blank to auto-generate)"
                :type="showPassword ? 'text' : 'password'"
                :append-inner-icon="showPassword ? 'mdi-eye-off' : 'mdi-eye'"
                variant="outlined"
                density="comfortable"
                :rules="passwordRules"
                @click:append-inner="showPassword = !showPassword"
              />
            </v-col>
          </v-row>
        </div>
      </v-card>

      <v-alert
        v-if="topError"
        type="error"
        variant="tonal"
        density="compact"
        class="mb-4"
      >{{ topError }}</v-alert>

      <div class="d-flex justify-end ga-2">
        <v-btn variant="text" rounded="lg" class="text-none" to="/superadmin/tenants">Cancel</v-btn>
        <v-btn
          type="submit"
          color="primary"
          rounded="lg"
          class="text-none"
          :loading="saving"
          prepend-icon="mdi-content-save"
        >{{ isEdit ? 'Save Changes' : 'Create Tenant' }}</v-btn>
      </div>
    </v-form>

    <!-- Created confirmation -->
    <v-dialog v-model="createdDialog.show" max-width="460" persistent>
      <v-card rounded="lg">
        <v-card-title class="d-flex align-center">
          <v-icon icon="mdi-check-circle" color="success" class="mr-2" />
          Tenant Created
        </v-card-title>
        <v-card-text>
          <p class="mb-3"><strong>{{ createdDialog.name }}</strong> has been created.</p>
          <v-alert type="info" variant="tonal" density="compact" class="mb-2">
            <div class="text-subtitle-2 mb-1">Admin credentials</div>
            <div><strong>Email:</strong> {{ createdDialog.email }}</div>
            <div><strong>Password:</strong> {{ createdDialog.password }}</div>
          </v-alert>
          <p class="text-caption text-medium-emphasis ma-0">
            Save these credentials — the password will not be shown again.
          </p>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn color="primary" variant="flat" rounded="lg" class="text-none" @click="onDoneCreated">Done</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useResource } from '~/composables/useResource'

const route = useRoute()
const router = useRouter()
const loadId = computed(() => route.params.id || null)
const isEdit = computed(() => !!loadId.value)

const r = useResource('/superadmin/tenants/')
const saving = computed(() => r.saving.value)

const typeOptions = [
  { title: 'Hospital', value: 'hospital' },
  { title: 'Pharmacy', value: 'pharmacy' },
  { title: 'Lab', value: 'lab' },
  { title: 'Homecare', value: 'homecare' }
]

const req = [(v) => (!!v && String(v).trim().length > 0) || 'Required']
const passwordRules = [
  (v) => !v || String(v).length >= 8 || 'Min 8 characters'
]

const form = reactive({
  name: '',
  slug: '',
  type: 'hospital',
  domain: '',
  city: '',
  country: 'Somalia',
  address: '',
  phone: '',
  email: '',
  website: '',
  is_active: true,
  // admin user (create only)
  admin_first_name: '',
  admin_last_name: '',
  admin_email: '',
  admin_password: ''
})

const formRef = ref(null)
const showPassword = ref(false)
const topError = ref('')
const snack = reactive({ show: false, color: 'success', text: '' })
const createdDialog = reactive({ show: false, name: '', email: '', password: '' })

let slugTouched = false

function slugify(s) {
  return String(s || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
}

function onNameChange(v) {
  if (isEdit.value) return
  if (!slugTouched) {
    const slug = slugify(v)
    form.slug = slug
    form.domain = slug ? `${slug}.adheremed.com` : ''
  }
}

function onSlugInput() {
  if (!isEdit.value) slugTouched = true
}

onMounted(async () => {
  if (isEdit.value) {
    const data = await r.get(loadId.value)
    if (data) {
      Object.keys(form).forEach((k) => {
        if (data[k] !== undefined && data[k] !== null) form[k] = data[k]
      })
    }
  }
})

async function onSubmit() {
  topError.value = ''
  const v = await formRef.value.validate()
  if (v?.valid === false) return

  try {
    if (isEdit.value) {
      const payload = {
        name: form.name.trim(),
        address: (form.address || '').trim(),
        city: (form.city || '').trim(),
        country: (form.country || '').trim(),
        phone: (form.phone || '').trim(),
        email: (form.email || '').trim(),
        website: (form.website || '').trim(),
        is_active: form.is_active
      }
      await r.update(loadId.value, payload)
      snack.text = 'Tenant updated'
      snack.color = 'success'
      snack.show = true
      router.push('/superadmin/tenants')
    } else {
      const payload = {
        name: form.name.trim(),
        slug: form.slug.trim(),
        type: form.type,
        domain: form.domain.trim(),
        address: (form.address || '').trim(),
        city: (form.city || '').trim(),
        country: (form.country || '').trim(),
        phone: (form.phone || '').trim(),
        email: (form.email || '').trim(),
        website: (form.website || '').trim(),
        admin_email: form.admin_email.trim(),
        admin_first_name: form.admin_first_name.trim(),
        admin_last_name: form.admin_last_name.trim()
      }
      if (form.admin_password) payload.admin_password = form.admin_password
      const result = await r.create(payload)
      const tenantName = result?.tenant?.name || form.name.trim()
      const adminEmail = result?.admin_user?.email || form.admin_email.trim()
      const generated = result?.admin_user?.generated_password
      createdDialog.name = tenantName
      createdDialog.email = adminEmail
      createdDialog.password = form.admin_password || generated || '(auto-generated)'
      createdDialog.show = true
    }
  } catch (e) {
    const data = e?.response?.data
    if (data && typeof data === 'object') {
      const firstKey = Object.keys(data)[0]
      const firstVal = firstKey ? data[firstKey] : null
      const msg = Array.isArray(firstVal) ? firstVal[0] : firstVal
      topError.value = data.detail || (firstKey ? `${firstKey}: ${msg}` : 'Save failed.')
    } else {
      topError.value = r.error.value || 'Save failed.'
    }
  }
}

function onDoneCreated() {
  createdDialog.show = false
  router.push('/superadmin/tenants')
}
</script>
