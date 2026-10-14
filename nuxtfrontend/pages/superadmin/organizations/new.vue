<template>
  <v-container fluid class="pa-4 pa-md-6" style="max-width: 800px;">
    <PageHeader title="New Organization" icon="mdi-sitemap">
      <template #actions>
        <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left" to="/superadmin/organizations">
          Back
        </v-btn>
      </template>
    </PageHeader>

    <v-card rounded="xl" variant="outlined" class="pa-6">
      <v-form ref="formRef" @submit.prevent="onSubmit">
        <!-- Basic info -->
        <div class="text-subtitle-1 font-weight-bold mb-4">Organization Details</div>
        <v-row dense>
          <v-col cols="12" md="8">
            <v-text-field
              v-model="form.name"
              label="Organization Name *"
              variant="outlined"
              density="compact"
              :rules="[v => !!v || 'Required']"
              prepend-inner-icon="mdi-sitemap"
            />
          </v-col>
          <v-col cols="12" md="4">
            <v-text-field
              v-model="form.slug"
              label="Slug (optional)"
              variant="outlined"
              density="compact"
              hint="Auto-generated if blank"
              persistent-hint
            />
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field
              v-model="form.email"
              label="Contact Email"
              variant="outlined"
              density="compact"
              prepend-inner-icon="mdi-email-outline"
            />
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field
              v-model="form.phone"
              label="Phone"
              variant="outlined"
              density="compact"
              prepend-inner-icon="mdi-phone-outline"
            />
          </v-col>
          <v-col cols="12">
            <v-text-field
              v-model="form.address"
              label="Address"
              variant="outlined"
              density="compact"
            />
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field
              v-model="form.city"
              label="City"
              variant="outlined"
              density="compact"
            />
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field
              v-model="form.country"
              label="Country"
              variant="outlined"
              density="compact"
              readonly
            />
          </v-col>
          <v-col cols="12">
            <v-text-field
              v-model="form.website"
              label="Website"
              variant="outlined"
              density="compact"
              prepend-inner-icon="mdi-web"
            />
          </v-col>
        </v-row>

        <!-- Admin users -->
        <div class="text-subtitle-1 font-weight-bold mt-6 mb-3">Organization Admins</div>
        <p class="text-body-2 text-medium-emphasis mb-3">
          Add one or more existing users who should have admin access to this organization.
        </p>
        <div class="d-flex ga-2 mb-2">
          <v-text-field
            v-model="newAdminEmail"
            label="Admin email"
            variant="outlined"
            density="compact"
            prepend-inner-icon="mdi-email-outline"
            :error-messages="adminEmailError"
            @keyup.enter="addAdminEmail"
          />
          <v-btn
            color="primary"
            rounded="lg"
            class="text-none"
            prepend-icon="mdi-plus"
            @click="addAdminEmail"
          >Add</v-btn>
        </div>
        <div v-if="adminEmails.length" class="d-flex flex-wrap ga-2 mb-4">
          <v-chip
            v-for="(email, i) in adminEmails"
            :key="i"
            closable
            color="info"
            variant="tonal"
            @click:close="adminEmails.splice(i, 1)"
          >
            <v-icon start size="16">mdi-account-tie</v-icon>
            {{ email }}
          </v-chip>
        </div>
        <div v-else class="text-caption text-medium-emphasis mb-4">
          No admin users added yet. At least one is recommended.
        </div>

        <!-- Link tenants -->
        <div class="text-subtitle-1 font-weight-bold mt-6 mb-3">Link Tenants</div>
        <p class="text-body-2 text-medium-emphasis mb-3">
          Select existing tenants (facilities) to link to this organization. You can link more later.
        </p>

        <div v-if="tenantsLoading" class="d-flex justify-center py-4">
          <v-progress-circular indeterminate color="primary" />
        </div>
        <div v-else-if="availableTenants.length === 0" class="text-center text-medium-emphasis py-4">
          <v-icon size="40" class="mb-2">mdi-domain-off</v-icon>
          <p>No unlinked tenants available. All tenants are already in an organization.</p>
        </div>
        <v-row v-else dense>
          <v-col
            v-for="t in availableTenants"
            :key="t.id"
            cols="12"
            sm="6"
          >
            <v-card
              rounded="lg"
              :variant="selectedTenantIds.includes(t.id) ? 'flat' : 'outlined'"
              :color="selectedTenantIds.includes(t.id) ? 'primary' : undefined"
              class="cursor-pointer pa-3"
              @click="toggleTenant(t.id)"
            >
              <div class="d-flex align-center ga-3">
                <v-avatar :color="typeColor(t.type)" variant="tonal" size="40">
                  <v-icon>{{ typeIcon(t.type) }}</v-icon>
                </v-avatar>
                <div class="flex-grow-1">
                  <div class="text-subtitle-2 font-weight-bold">{{ t.name }}</div>
                  <div class="text-caption text-capitalize text-medium-emphasis">{{ t.type }}</div>
                </div>
                <v-icon v-if="selectedTenantIds.includes(t.id)" color="primary">mdi-check-circle</v-icon>
              </div>
            </v-card>
          </v-col>
        </v-row>

        <!-- Submit -->
        <div class="d-flex justify-end ga-2 mt-6">
          <v-btn variant="text" rounded="lg" class="text-none" to="/superadmin/organizations">Cancel</v-btn>
          <v-btn
            color="primary"
            rounded="lg"
            class="text-none px-8"
            type="submit"
            :loading="saving"
            prepend-icon="mdi-check"
          >
            Create Organization
          </v-btn>
        </div>
      </v-form>
    </v-card>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="4000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
const { $api } = useNuxtApp()

const formRef = ref(null)
const saving = ref(false)
const tenantsLoading = ref(true)
const availableTenants = ref([])
const selectedTenantIds = ref([])
const newAdminEmail = ref('')
const adminEmails = ref([])
const adminEmailError = ref('')

const form = reactive({
  name: '',
  slug: '',
  email: '',
  phone: '',
  address: '',
  city: '',
  country: 'Kenya',
  website: '',
  is_active: true,
})

const snack = reactive({ show: false, color: 'success', text: '' })

const emailRe = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

function addAdminEmail() {
  const email = newAdminEmail.value.trim()
  if (!email) return
  if (!emailRe.test(email)) {
    adminEmailError.value = 'Please enter a valid email address.'
    return
  }
  if (adminEmails.value.includes(email)) {
    adminEmailError.value = 'This email is already in the list.'
    return
  }
  adminEmails.value.push(email)
  newAdminEmail.value = ''
  adminEmailError.value = ''
}

async function loadUnlinkedTenants() {
  tenantsLoading.value = true
  try {
    const { data } = await $api.get('/organizations/admin/unlinked-tenants/')
    availableTenants.value = data
  } catch (e) {
    availableTenants.value = []
  } finally {
    tenantsLoading.value = false
  }
}

function toggleTenant(id) {
  const idx = selectedTenantIds.value.indexOf(id)
  if (idx >= 0) {
    selectedTenantIds.value.splice(idx, 1)
  } else {
    selectedTenantIds.value.push(id)
  }
}

async function onSubmit() {
  const { valid } = await formRef.value.validate()
  if (!valid) return

  saving.value = true
  try {
    const payload = { ...form, tenant_ids: selectedTenantIds.value, admin_emails: adminEmails.value }
    const { data } = await $api.post('/organizations/admin/', payload)
    snack.text = `Organization "${data.name}" created successfully!`
    snack.color = 'success'
    snack.show = true
    setTimeout(() => navigateTo('/superadmin/organizations'), 1500)
  } catch (e) {
    snack.text = e?.response?.data?.detail || JSON.stringify(e?.response?.data) || 'Failed to create organization'
    snack.color = 'error'
    snack.show = true
  } finally {
    saving.value = false
  }
}

function typeIcon(type) {
  return {
    pharmacy: 'mdi-pill', lab: 'mdi-test-tube', homecare: 'mdi-home-heart',
    clinic: 'mdi-stethoscope', radiology_center: 'mdi-radiology',
    inventory: 'mdi-warehouse', hospital: 'mdi-hospital-building',
  }[type] || 'mdi-domain'
}

function typeColor(type) {
  return {
    pharmacy: 'green', lab: 'purple', homecare: 'pink', inventory: 'amber-darken-2',
    clinic: 'teal', hospital: 'red', radiology_center: 'indigo',
  }[type] || 'primary'
}

onMounted(loadUnlinkedTenants)
</script>
