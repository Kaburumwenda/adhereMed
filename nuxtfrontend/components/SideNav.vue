<template>
  <v-navigation-drawer
    v-model="drawer"
    :rail="rail && !mobile"
    :permanent="!mobile"
    :temporary="mobile"
    :width="260"
    :rail-width="72"
    color="surface"
    border
  >
    <!-- Logo / Brand -->
    <div class="d-flex align-center px-4" style="height:68px;">
      <BrandLogo :size="38" />
      <div v-if="!rail || mobile" class="ml-3">
        <BrandMark :size="17" />
      </div>
    </div>
    <v-divider />

    <!-- Sections -->
    <v-list nav density="compact" class="py-2">
      <template v-for="(section, sIdx) in sections" :key="sIdx">
        <v-list-subheader
          v-if="section.label && (!rail || mobile)"
          class="text-caption font-weight-bold"
          style="letter-spacing:1.2px;"
        >
          <v-icon size="6" color="primary" class="mr-2">mdi-circle</v-icon>
          {{ section.label }}
        </v-list-subheader>
        <v-divider v-else-if="section.label && rail && !mobile" class="my-2 mx-4" />

        <template v-for="item in section.items" :key="item.path + item.label">
          <!-- Group with children -->
          <v-list-group v-if="item.children?.length" :value="item.label">
            <template #activator="{ props }">
              <v-list-item
                v-bind="props"
                :prepend-icon="item.icon"
                :title="(!rail || mobile) ? item.label : ''"
              />
            </template>
            <v-list-item
              v-for="child in item.children"
              :key="child.path"
              :prepend-icon="child.icon"
              :title="child.label"
              :to="child.path"
              :active="route.path === child.path"
            />
          </v-list-group>

          <!-- Plain link -->
          <v-list-item
            v-else
            :prepend-icon="item.icon"
            :title="(!rail || mobile) ? item.label : ''"
            :to="item.path"
            :active="route.path === item.path"
          />
        </template>
      </template>
    </v-list>

    <template #append>
      <div class="pa-2">
        <v-btn
          v-if="!mobile"
          block
          variant="tonal"
          size="small"
          :prepend-icon="rail ? 'mdi-chevron-right' : 'mdi-chevron-left'"
          @click="$emit('toggle-rail')"
        >
          <span v-if="!rail">Collapse</span>
        </v-btn>
      </div>
      <v-divider />
      <div class="pa-3">
        <div
          class="d-flex align-center pa-3 rounded-lg"
          style="background: rgba(13,148,136,0.06); border: 1px solid rgba(13,148,136,0.12);"
        >
          <v-avatar size="32" class="brand-gradient-soft">
            <span class="text-white font-weight-bold">{{ initial }}</span>
          </v-avatar>
          <div v-if="!rail || mobile" class="ml-3 flex-grow-1 text-truncate">
            <div class="text-body-2 font-weight-medium text-truncate">{{ userName || 'User' }}</div>
            <div class="text-caption text-medium-emphasis text-truncate">{{ formatRole(userRole) }}</div>
          </div>
          <v-btn icon="mdi-logout" variant="text" size="small" color="error" @click="$emit('logout')" />
        </div>
      </div>
    </template>
  </v-navigation-drawer>
</template>

<script setup>
import { getNavSections } from '~/utils/nav'
import { filterNavSections } from '~/utils/permissions'

const props = defineProps({
  modelValue: { type: Boolean, default: true },
  rail: { type: Boolean, default: false },
  mobile: { type: Boolean, default: false },
  userName: { type: String, default: '' },
  userRole: { type: String, default: '' },
  tenantType: { type: String, default: null }
})
const emit = defineEmits(['update:modelValue', 'toggle-rail', 'logout'])

const drawer = computed({
  get: () => props.modelValue,
  set: (v) => emit('update:modelValue', v)
})

const route = useRoute()

const sections = computed(() => filterNavSections(getNavSections(props.userRole, props.tenantType), props.userRole))

const initial = computed(() => (props.userName?.[0] || 'U').toUpperCase())

function formatRole(r) {
  if (!r) return ''
  return r.split('_').map(w => w[0].toUpperCase() + w.slice(1)).join(' ')
}
</script>
