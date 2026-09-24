// Tenant-aware API endpoints.
// Inventory / warehouse tenants get their own independent /ims API
// namespace and never call the pharmacy endpoints. Other tenant types
// keep using their existing (pharmacy) endpoints.
import { computed } from 'vue'
import { useAuthStore } from '~/stores/auth'

export function useTenantEndpoints() {
  const auth = useAuthStore()
  const isInventory = computed(() => auth.tenantType === 'inventory')

  return {
    isInventory,

    // Branches (warehouses) CRUD
    branches: computed(() =>
      isInventory.value ? '/ims/branches/' : '/pharmacy-profile/branches/'),

    // Business profile (name, license, hours, services)
    profile: computed(() =>
      isInventory.value ? '/ims/profile/' : '/pharmacy-profile/profile/'),

    // Deliveries (sales fulfilment)
    deliveries: computed(() =>
      isInventory.value ? '/ims/deliveries/' : '/pharmacy-profile/deliveries/'),

    // Setup / seed catalog
    setupSeed: computed(() =>
      isInventory.value ? '/ims/setup/seed/' : '/pharmacy-profile/setup/seed/'),
    setupSeedRun: computed(() =>
      isInventory.value ? '/ims/setup/seed/run/' : '/pharmacy-profile/setup/seed/run/'),
  }
}
