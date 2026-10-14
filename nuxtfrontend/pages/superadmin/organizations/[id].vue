<template>
  <v-container fluid class="pa-4 pa-md-6">
    <PageHeader :title="org?.name || 'Organization'" icon="mdi-sitemap" :subtitle="org?.slug">
      <template #actions>
        <v-btn variant="text" rounded="lg" class="text-none" prepend-icon="mdi-arrow-left" to="/superadmin/organizations">
          Back
        </v-btn>
      </template>
    </PageHeader>

    <div v-if="loading" class="d-flex justify-center py-16">
      <v-progress-circular indeterminate size="48" color="primary" />
    </div>

    <template v-else-if="org">
      <!-- Info card -->
      <v-card rounded="xl" variant="outlined" class="mb-4">
        <v-card-text>
          <v-row dense>
            <v-col cols="12" md="6">
              <div class="text-caption text-medium-emphasis">Contact Email</div>
              <div class="text-body-1">{{ org.email || '—' }}</div>
            </v-col>
            <v-col cols="12" md="6">
              <div class="text-caption text-medium-emphasis">Phone</div>
              <div class="text-body-1">{{ org.phone || '——' }}</div>
            </v-col>
            <v-col cols="12" md="6">
              <div class="text-caption text-medium-emphasis">Address</div>
              <div class="text-body-1">{{ org.address || '—' }}</div>
            </v-col>
            <v-col cols="12" md="4">
              <div class="text-caption text-medium-emphasis">City</div>
              <div class="text-body-1">{{ org.city || '—' }}</div>
            </v-col>
            <v-col cols="12" md="2">
              <div class="text-caption text-medium-emphasis">Country</div>
              <div class="text-body-1">{{ org.country }}</div>
            </v-col>
            <v-col cols="12" md="6">
              <div class="text-caption text-medium-emphasis">Website</div>
              <div class="text-body-1">
                <a v-if="org.website" :href="org.website" target="_blank">{{ org.website }}</a>
                <span v-else>—</span>
              </div>
            </v-col>
            <v-col cols="12" md="6">
              <div class="text-caption text-medium-emphasis">Status</div>
              <v-chip size="small" :color="org.is_active ? 'success' : 'grey'" variant="tonal">
                {{ org.is_active ? 'Active' : 'Inactive' }}
              </v-chip>
            </v-col>
          </v-row>
        </v-card-text>
      </v-card>

      <v-row>
        <!-- Left: Linked tenants -->
        <v-col cols="12" md="7">
          <v-card rounded="xl" variant="outlined" class="mb-4">
            <v-card-title class="d-flex align-center">
              <v-icon class="mr-2" color="primary">mdi-domain-multiple</v-icon>
              Linked Tenants
              <span class="ml-2 text-caption text-medium-emphasis">({{ org.linked_tenants?.length || 0 }})</span>
            </v-card-title>

            <v-divider />

            <v-card-text class="pa-0">
              <v-list v-if="org.linked_tenants && org.linked_tenants.length">
                <v-list-item
                  v-for="t in org.linked_tenants"
                  :key="t.id"
                  class="px-4"
                >
                  <template #prepend>
                    <v-avatar :color="typeColor(t.type)" variant="tonal" size="40">
                      <v-icon>{{ typeIcon(t.type) }}</v-icon>
                    </v-avatar>
                  </template>
                  <v-list-item-title class="font-weight-medium">{{ t.name }}</v-list-item-title>
                  <v-list-item-subtitle class="text-capitalize">{{ t.type }} · {{ t.schema_name }}</v-list-item-subtitle>
                  <template #append>
                    <v-chip
                      v-if="!t.is_active"
                      size="x-small" variant="flat" color="grey"
                      class="mr-2"
                    >Tenant Inactive</v-chip>
                    <v-btn
                      icon="mdi-link-off"
                      variant="text"
                      size="small"
                      color="error"
                      :loading="unlinking === t.id"
                      title="Unlink from org"
                      @click.stop="unlinkTenant(t)"
                    />
                  </template>
                </v-list-item>
              </v-list>
              <div v-else class="text-center text-medium-emphasis py-8">
                <v-icon size="40" class="mb-2">mdi-domain-off</v-icon>
                <p>No tenants linked yet.</p>
              </div>
            </v-card-text>

            <!-- Link new tenant -->
            <v-divider />
            <v-card-text>
              <div class="text-subtitle-2 font-weight-bold mb-2">Link a Tenant</div>
              <div v-if="unlinkedLoading" class="d-flex justify-center py-2">
                <v-progress-circular indeterminate size="24" color="primary" />
              </div>
              <div v-else-if="unlinkedTenants.length === 0" class="text-caption text-medium-emphasis">
                All tenants are already linked to organizations.
              </div>
              <div v-else class="d-flex align-center ga-2">
                <v-select
                  v-model="linkTenantId"
                  :items="unlinkedTenants"
                  item-title="name"
                  item-value="id"
                  label="Select tenant"
                  variant="outlined"
                  density="compact"
                  hide-details
                  style="max-width: 320px;"
                >
                  <template #item="{ item, props }">
                    <v-list-item v-bind="props">
                      <template #prepend>
                        <v-icon :color="typeColor(item.raw.type)">{{ typeIcon(item.raw.type) }}</v-icon>
                      </template>
                      <v-list-item-subtitle class="text-capitalize">{{ item.raw.type }}</v-list-item-subtitle>
                    </v-list-item>
                  </template>
                </v-select>
                <v-btn
                  color="primary"
                  rounded="lg"
                  class="text-none"
                  prepend-icon="mdi-link-plus"
                  :disabled="!linkTenantId"
                  :loading="linking"
                  @click="linkTenant"
                >Link</v-btn>
              </div>
            </v-card-text>
          </v-card>
        </v-col>

        <!-- Right: Admin users -->
        <v-col cols="12" md="5">
          <v-card rounded="xl" variant="outlined" class="mb-4">
            <v-card-title class="d-flex align-center">
              <v-icon class="mr-2" color="info">mdi-account-tie</v-icon>
              Organization Admins
            </v-card-title>
            <v-divider />
            <v-card-text class="pa-0">
              <v-list v-if="org.admin_users && org.admin_users.length">
                <v-list-item
                  v-for="u in org.admin_users"
                  :key="u.id"
                  class="px-4"
                >
                  <template #prepend>
                    <v-avatar color="info" variant="tonal" size="40">
                      <v-icon>mdi-account</v-icon>
                    </v-avatar>
                  </template>
                  <v-list-item-title class="font-weight-medium">{{ u.email }}</v-list-item-title>
                  <v-list-item-subtitle>{{ u.first_name }} {{ u.last_name }}</v-list-item-subtitle>
                  <template #append>
                    <v-btn
                      icon="mdi-account-remove"
                      variant="text"
                      size="small"
                      color="error"
                      :loading="removingAdmin === u.id"
                      title="Remove admin"
                      @click.stop="removeAdmin(u)"
                    />
                  </template>
                </v-list-item>
              </v-list>
              <div v-else class="text-center text-medium-emphasis py-8">
                <v-icon size="40" class="mb-2">mdi-account-tie-outline</v-icon>
                <p>No admin users assigned.</p>
              </div>
            </v-card-text>

            <!-- Add admin -->
            <v-divider />
            <v-card-text>
              <div class="text-subtitle-2 font-weight-bold mb-2">Designate New Admin</div>
              <div class="d-flex align-center ga-2">
                <v-text-field
                  v-model="adminEmail"
                  label="User email"
                  variant="outlined"
                  density="compact"
                  hide-details
                  prepend-inner-icon="mdi-email-outline"
                  style="max-width: 280px;"
                />
                <v-btn
                  color="info"
                  rounded="lg"
                  class="text-none"
                  prepend-icon="mdi-account-plus"
                  :disabled="!adminEmail"
                  :loading="addingAdmin"
                  @click="addAdmin"
                >Set Admin</v-btn>
              </div>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>
    </template>

    <div v-else class="text-center py-16">
      <v-icon size="64" color="grey-lighten-1">mdi-sitemap-off</v-icon>
      <p class="text-body-1 text-medium-emphasis mt-2">Organization not found.</p>
    </div>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup>
const route = useRoute()
const { $api } = useNuxtApp()

const orgId = route.params.id

const org = ref(null)
const loading = ref(true)
const unlinkedTenants = ref([])
const unlinkedLoading = ref(false)
const linkTenantId = ref(null)
const linking = ref(false)
const unlinking = ref(null)
const adminEmail = ref('')
const addingAdmin = ref(false)
const removingAdmin = ref(null)
const snack = reactive({ show: false, color: 'success', text: '' })

async function load() {
  loading.value = true
  try {
    const { data } = await $api.get(`/organizations/admin/${orgId}/`)
    org.value = data
    await loadUnlinkedTenants()
  } catch (e) {
    snack.text = 'Failed to load organization'
    snack.color = 'error'
    snack.show = true
  } finally {
    loading.value = false
  }
}

async function loadUnlinkedTenants() {
  unlinkedLoading.value = true
  try {
    const { data } = await $api.get('/organizations/admin/unlinked-tenants/')
    unlinkedTenants.value = data
  } catch (e) {
    unlinkedTenants.value = []
  } finally {
    unlinkedLoading.value = false
  }
}

async function linkTenant() {
  if (!linkTenantId.value) return
  linking.value = true
  try {
    await $api.post(`/organizations/admin/${orgId}/link-tenant/`, { tenant_id: linkTenantId.value })
    snack.text = 'Tenant linked successfully'
    snack.color = 'success'
    snack.show = true
    linkTenantId.value = null
    await load()
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to link tenant'
    snack.color = 'error'
    snack.show = true
  } finally {
    linking.value = false
  }
}

async function unlinkTenant(t) {
  unlinking.value = t.id
  try {
    await $api.post(`/organizations/admin/${orgId}/unlink-tenant/`, { tenant_id: t.id })
    snack.text = `${t.name} unlinked`
    snack.color = 'success'
    snack.show = true
    await load()
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to unlink tenant'
    snack.color = 'error'
    snack.show = true
  } finally {
    unlinking.value = null
  }
}

async function addAdmin() {
  if (!adminEmail.value) return
  addingAdmin.value = true
  try {
    await $api.post(`/organizations/admin/${orgId}/set-admin/`, { user_email: adminEmail.value })
    snack.text = 'Admin assigned successfully'
    snack.color = 'success'
    snack.show = true
    adminEmail.value = ''
    await load()
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to set admin'
    snack.color = 'error'
    snack.show = true
  } finally {
    addingAdmin.value = false
  }
}

async function removeAdmin(u) {
  removingAdmin.value = u.id
  try {
    await $api.post(`/organizations/admin/${orgId}/remove-admin/`, { user_id: u.id })
    snack.text = 'Admin removed'
    snack.color = 'success'
    snack.show = true
    await load()
  } catch (e) {
    snack.text = e?.response?.data?.detail || 'Failed to remove admin'
    snack.color = 'error'
    snack.show = true
  } finally {
    removingAdmin.value = null
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

onMounted(load)
</script>
