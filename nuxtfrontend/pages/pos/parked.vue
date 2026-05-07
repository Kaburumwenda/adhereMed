<template>
  <div class="pa-4">
    <div class="d-flex align-center mb-4">
      <v-icon size="32" color="warning" class="mr-2">mdi-tray-arrow-up</v-icon>
      <div>
        <h2 class="text-h5 font-weight-bold mb-0">Parked Sales</h2>
        <div class="text-caption text-medium-emphasis">On-hold sales waiting to be resumed</div>
      </div>
      <v-spacer />
      <v-btn-toggle v-model="filter" mandatory density="compact" rounded="lg" variant="outlined" class="mr-2">
        <v-btn value="all" class="text-none">All</v-btn>
        <v-btn value="mine" class="text-none">Mine</v-btn>
      </v-btn-toggle>
      <v-btn variant="tonal" prepend-icon="mdi-refresh" class="text-none" @click="load">Refresh</v-btn>
      <v-btn color="primary" variant="flat" prepend-icon="mdi-cart-variant" class="text-none ml-2" to="/pos/supermarket">
        Smart POS
      </v-btn>
      <v-btn color="primary" variant="tonal" prepend-icon="mdi-point-of-sale" class="text-none ml-1" to="/pos">
        Pharmacy POS
      </v-btn>
    </div>

    <v-text-field
      v-model="search"
      prepend-inner-icon="mdi-magnify"
      placeholder="Search by park # / customer / phone"
      density="comfortable" variant="outlined" hide-details rounded="lg" class="mb-3"
    />

    <v-progress-linear v-if="loading" indeterminate color="primary" class="mb-3" />

    <div v-if="!loading && !filtered.length" class="text-center py-12 text-medium-emphasis">
      <v-icon size="80" color="grey-lighten-1">mdi-tray-remove</v-icon>
      <div class="text-h6 mt-2">No parked sales</div>
      <div class="text-body-2">Parked sales appear here when a cashier puts a sale on hold.</div>
    </div>

    <v-row dense>
      <v-col v-for="p in filtered" :key="p.id" cols="12" md="6" lg="4">
        <v-card rounded="lg" class="parked-card" elevation="2">
          <div class="parked-card-header">
            <div>
              <div class="text-caption" style="opacity:0.85">PARK #</div>
              <div class="text-h6 font-weight-bold">{{ p.park_number }}</div>
            </div>
            <v-chip color="warning" variant="flat" size="small">{{ p.item_count }} items</v-chip>
          </div>
          <v-card-text class="pb-2">
            <div class="d-flex align-center mb-1">
              <v-icon size="16" color="primary" class="mr-2">mdi-account</v-icon>
              <span class="font-weight-medium">{{ p.customer_name || 'Walk-in' }}</span>
              <span v-if="p.customer_phone" class="text-caption text-medium-emphasis ml-2">· {{ p.customer_phone }}</span>
            </div>
            <div class="d-flex align-center mb-1">
              <v-icon size="16" color="grey" class="mr-2">mdi-account-tie</v-icon>
              <span class="text-body-2 text-medium-emphasis">{{ p.cashier_name || '—' }}</span>
            </div>
            <div class="d-flex align-center mb-2">
              <v-icon size="16" color="grey" class="mr-2">mdi-clock-outline</v-icon>
              <span class="text-body-2 text-medium-emphasis">{{ formatTime(p.created_at) }}</span>
            </div>

            <v-divider class="my-2" />

            <div class="parked-items">
              <div v-for="(it, i) in (p.items || []).slice(0, 4)" :key="i" class="d-flex justify-space-between text-body-2 mb-1">
                <span class="text-truncate" style="max-width: 65%;">{{ it.quantity }} × {{ it.name }}</span>
                <span class="text-medium-emphasis">{{ formatMoney(Number(it.selling_price) * Number(it.quantity)) }}</span>
              </div>
              <div v-if="(p.items || []).length > 4" class="text-caption text-medium-emphasis">
                + {{ p.items.length - 4 }} more item(s)…
              </div>
            </div>

            <v-divider class="my-2" />

            <div class="d-flex justify-space-between">
              <span class="text-body-2 text-medium-emphasis">Total</span>
              <span class="text-h6 font-weight-bold text-primary">{{ formatMoney(p.total) }}</span>
            </div>
          </v-card-text>
          <v-card-actions class="px-4 pb-3">
            <v-btn color="success" variant="flat" rounded="lg" prepend-icon="mdi-tray-arrow-up" class="text-none flex-grow-1" @click="resume(p)">
              Resume
            </v-btn>
            <v-btn color="error" variant="tonal" rounded="lg" icon="mdi-delete" size="small" class="ml-2" @click="confirmDelete(p)" />
          </v-card-actions>
        </v-card>
      </v-col>
    </v-row>

    <v-dialog v-model="del.show" max-width="420">
      <v-card rounded="lg" class="pa-4">
        <h3 class="text-h6 font-weight-bold mb-2">Delete parked sale?</h3>
        <p class="text-body-2 text-medium-emphasis mb-4">
          {{ del.target?.park_number }} · {{ del.target?.customer_name || 'Walk-in' }} ·
          {{ formatMoney(del.target?.total || 0) }}. This cannot be undone.
        </p>
        <div class="d-flex justify-end" style="gap:8px">
          <v-btn variant="text" class="text-none" @click="del.show = false">Cancel</v-btn>
          <v-btn color="error" variant="flat" class="text-none" :loading="del.loading" @click="doDelete">Delete</v-btn>
        </div>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2500">{{ snack.text }}</v-snackbar>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { formatMoney } from '~/utils/format'

definePageMeta({ layout: 'default' })

const { $api } = useNuxtApp()
const router = useRouter()
const route = useRoute()
const sourceIsPharmacy = computed(() => (route.query?.source || '') === 'pharmacy')

const items = ref([])
const loading = ref(false)
const search = ref('')
const filter = ref('all')
const snack = reactive({ show: false, text: '', color: 'success' })
const del = reactive({ show: false, target: null, loading: false })

async function load() {
  loading.value = true
  try {
    const url = filter.value === 'mine'
      ? '/pos/parked-sales/?mine=1&page_size=200'
      : '/pos/parked-sales/?page_size=200'
    const res = await $api.get(url)
    items.value = res.data?.results || res.data || []
  } catch (e) {
    items.value = []
    flash('Failed to load parked sales', 'error')
  } finally {
    loading.value = false
  }
}
onMounted(load)
watch(filter, load)

const filtered = computed(() => {
  const q = search.value.toLowerCase().trim()
  if (!q) return items.value
  return items.value.filter(p =>
    (p.park_number || '').toLowerCase().includes(q) ||
    (p.customer_name || '').toLowerCase().includes(q) ||
    (p.customer_phone || '').toLowerCase().includes(q)
  )
})

function flash(text, color = 'success') { snack.text = text; snack.color = color; snack.show = true }
function formatTime(t) {
  if (!t) return ''
  const d = new Date(t)
  return d.toLocaleString(undefined, { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })
}

function resume(p) {
  if (sourceIsPharmacy.value) {
    try { sessionStorage.setItem('pharm_resume_parked', JSON.stringify(p)) } catch (e) {}
    router.push('/pos')
  } else {
    try { sessionStorage.setItem('smkt_resume_parked', JSON.stringify(p)) } catch (e) {}
    router.push('/pos/supermarket')
  }
}

function confirmDelete(p) { del.target = p; del.show = true }
async function doDelete() {
  if (!del.target) return
  del.loading = true
  try {
    await $api.delete(`/pos/parked-sales/${del.target.id}/`)
    items.value = items.value.filter(x => x.id !== del.target.id)
    flash('Parked sale deleted')
    del.show = false
  } catch (e) {
    flash('Failed to delete', 'error')
  } finally {
    del.loading = false
  }
}
</script>

<style scoped>
.parked-card { border-top: 4px solid #f59e0b; transition: transform 0.15s, box-shadow 0.15s; }
.parked-card:hover { transform: translateY(-2px); box-shadow: 0 8px 24px rgba(0,0,0,0.12) !important; }
.parked-card-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 14px 16px;
  background: linear-gradient(135deg, #f59e0b, #f97316);
  color: white;
}
.parked-items { max-height: 110px; overflow: hidden; }
</style>
