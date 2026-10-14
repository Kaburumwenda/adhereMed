<template>
  <NuxtLayout name="auth">
    <div class="docs-root">
      <div class="brand-gradient bg-fill" />
      <div class="blob blob-1" />
      <div class="blob blob-2" />

      <!-- Top nav -->
      <div class="top-nav d-flex align-center px-4 px-md-12 py-3">
        <div class="d-flex align-center" style="cursor:pointer" @click="$router.push('/welcome')">
          <BrandLogo :size="32" class="mr-3" />
          <BrandMark :size="18" bold-color="white" light-color="white" />
        </div>
        <v-spacer />
        <v-btn variant="text" class="text-none nav-btn" prepend-icon="mdi-arrow-left"
               @click="$router.push('/welcome')">
          Back
        </v-btn>
        <v-btn variant="outlined" class="text-none nav-btn-outline mr-2" rounded="lg"
               @click="$router.push('/login')">
          Sign In
        </v-btn>
        <v-btn color="white" class="text-none nav-btn-print" rounded="lg"
               @click="print()">
          <v-icon class="mr-1" size="18">mdi-printer</v-icon> Print
        </v-btn>
      </div>

      <!-- Tab bar -->
      <div class="docs-tabbar d-flex justify-center px-4 py-1">
        <v-tabs v-model="tab" bg-color="transparent" color="white" slider-color="#5EEAD4"
                density="comfortable" class="docs-tabs" grow>
          <v-tab value="pharmacy" class="text-none" prepend-icon="mdi-pill">Pharmacy</v-tab>
          <v-tab value="homecare" class="text-none" prepend-icon="mdi-home-heart">Homecare</v-tab>
          <v-tab value="lab" class="text-none" prepend-icon="mdi-flask">Laboratory</v-tab>
          <v-tab value="inventory" class="text-none" prepend-icon="mdi-warehouse">Inventory / Warehouse</v-tab>
        </v-tabs>
      </div>

      <v-container class="docs-container py-6 py-md-8" style="position:relative;z-index:2;max-width:1280px;">
        <!-- Hero -->
        <div class="docs-hero mb-6">
          <div class="docs-hero-glow" />
          <div class="docs-hero-content pa-6 pa-md-10">
            <div class="d-flex align-center mb-3 flex-wrap ga-2">
              <v-chip color="white" variant="flat" size="small" class="hero-chip">
                <v-icon size="14" start>mdi-book-open-variant</v-icon> User Guide
              </v-chip>
              <v-chip color="white" variant="outlined" size="small" class="hero-chip-outline">v1.0 · {{ today }}</v-chip>
              <v-chip v-if="tab === 'pharmacy'" color="white" variant="outlined" size="small" class="hero-chip-outline">
                <v-icon size="14" start>mdi-pill</v-icon> Pharmacy
              </v-chip>
              <v-chip v-else-if="tab === 'homecare'" color="white" variant="outlined" size="small" class="hero-chip-outline">
                <v-icon size="14" start>mdi-home-heart</v-icon> Homecare
              </v-chip>
              <v-chip v-else-if="tab === 'lab'" color="white" variant="outlined" size="small" class="hero-chip-outline">
                <v-icon size="14" start>mdi-flask</v-icon> Laboratory
              </v-chip>
              <v-chip v-else color="white" variant="outlined" size="small" class="hero-chip-outline">
                <v-icon size="14" start>mdi-warehouse</v-icon> Inventory / Warehouse
              </v-chip>
            </div>
            <Transition name="fade-up" mode="out-in" appear>
              <div :key="tab">
                <h2 class="docs-hero-title">{{ heroTitle }}</h2>
                <p class="docs-hero-sub">{{ heroSubtitle }}</p>
              </div>
            </Transition>
          </div>
        </div>

        <v-row dense>
          <!-- TOC -->
          <v-col cols="12" md="3">
            <div class="docs-toc-wrap sticky-toc">
              <div class="docs-toc">
                <div class="toc-overline mb-2">Contents</div>
                <v-list density="compact" nav class="bg-transparent toc-list">
                  <v-list-item v-for="s in sections" :key="s.id"
                               :href="`#${s.id}`" :title="s.title"
                               :prepend-icon="s.icon" rounded="lg"
                               class="toc-item" />
                </v-list>
              </div>
            </div>
          </v-col>

          <!-- Body -->
          <v-col cols="12" md="9">
            <TransitionGroup name="section-list" tag="div">
              <div v-for="s in sections" :key="s.id" :id="s.id"
                   class="docs-section-wrap mb-4">
                <div class="docs-section pa-5 pa-md-7">
                  <div class="d-flex align-center mb-4">
                    <div class="section-icon-wrap" :style="{ '--section-color': sectionColor(s) }">
                      <v-icon :color="s.color || 'teal'" size="24">{{ s.icon }}</v-icon>
                    </div>
                    <div class="ml-3">
                      <div class="text-h5 font-weight-bold section-title">{{ s.title }}</div>
                      <div v-if="s.tagline" class="text-caption section-tagline">{{ s.tagline }}</div>
                    </div>
                  </div>
                  <div v-html="s.body" class="docs-body" />
                  <div v-if="s.tips?.length" class="mt-4 docs-tips">
                    <div v-for="(t, i) in s.tips" :key="i" class="docs-tip"
                         :class="`docs-tip--${t.type || 'info'}`">
                      <v-icon size="18" class="docs-tip-icon">
                        {{ tipIcon(t.type) }}
                      </v-icon>
                      <div v-html="t.text" class="docs-tip-text" />
                    </div>
                  </div>
                </div>
              </div>
            </TransitionGroup>

            <div class="docs-support-card">
              <v-icon size="28" color="teal" class="mr-3">mdi-lifebuoy</v-icon>
              <div>
                <div class="text-body-1 font-weight-medium">Need more help?</div>
                <div class="text-body-2 text-medium-emphasis">
                  Reach support at
                  <a href="mailto:support@adheremed.com" class="docs-link">support@adheremed.com</a>
                </div>
              </div>
            </div>
          </v-col>
        </v-row>
      </v-container>
    </div>
  </NuxtLayout>
</template>

<script setup>
definePageMeta({ layout: false })

const today = new Date().toLocaleDateString(undefined, { year: 'numeric', month: 'short' })
function print() { if (typeof window !== 'undefined') window.print() }

const route = useRoute()
const router = useRouter()
const VALID_TABS = ['pharmacy', 'homecare', 'lab', 'inventory']
const tab = ref(VALID_TABS.includes(route.query.tab) ? route.query.tab : 'pharmacy')
watch(tab, (v) => {
  router.replace({ query: { ...route.query, tab: v } })
})

const heroTitle = computed(() => {
  if (tab.value === 'homecare') return 'AdhereMed Homecare Platform'
  if (tab.value === 'lab') return 'AdhereMed Laboratory Platform'
  if (tab.value === 'inventory') return 'AdhereMed Inventory / Warehouse Platform'
  return 'AdhereMed Pharmacy Platform'
})
const heroSubtitle = computed(() => {
  if (tab.value === 'homecare') return 'A comprehensive user guide covering every homecare module — from patient enrolment and care plans to medication doses, vitals, and teleconsult.'
  if (tab.value === 'lab') return 'A comprehensive user guide covering every lab module — from requisitions and accessioning to results, QC, instruments, billing and the referring network.'
  if (tab.value === 'inventory') return 'A comprehensive user guide covering every warehouse module — from stock items and batches to transfers, cycle counts, controlled substances, bulk edits and analytics.'
  return 'A comprehensive user guide covering every pharmacy module — from POS and inventory to deliveries, branches, purchase orders, and analytics.'
})

const sections = computed(() => {
  if (tab.value === 'homecare') return homecareSections
  if (tab.value === 'lab') return labSections
  if (tab.value === 'inventory') return inventorySections
  return pharmacySections
})

function sectionColor(s) {
  const map = { teal: '#0d9488', success: '#16a34a', indigo: '#6366f1', 'amber-darken-2': '#b45309',
    primary: '#2f6dff', purple: '#9333ea', error: '#dc2626', info: '#0ea5e9', pink: '#db2777' }
  return map[s.color] || '#0d9488'
}
function tipIcon(type) {
  if (type === 'warning') return 'mdi-alert-outline'
  if (type === 'success') return 'mdi-check-circle-outline'
  if (type === 'error') return 'mdi-alert-circle-outline'
  return 'mdi-information-outline'
}

const inventorySections = [
  {
    id: 'ims-getting-started',
    title: 'Getting Started',
    icon: 'mdi-rocket-launch',
    color: 'teal',
    tagline: 'Navigate the warehouse module and orient yourself.',
    body: `
      <p>After signing in as an <b>Inventory / Warehouse</b> tenant, you land on the <b>Inventory</b> hub page.</p>
      <ul>
        <li><b>Sidebar</b> — primary navigation between modules: Overview, Stock Items, Stock Alerts, Adjustments, Stock Analysis, Stock Take, Branch Transfers, Stock Movements, Controlled Register, Bulk Upload, Excel Import/Export.</li>
        <li><b>Top bar</b> — global search, notifications, theme toggle, and profile menu.</li>
        <li><b>Branch switcher</b> — if your warehouse operates across multiple branches, switch context from the top bar.</li>
        <li><b>Roles</b> — features are gated by role: <i>tenant_admin</i>, <i>inventory_admin</i>, <i>branch_admin</i>, <i>storekeeper</i>. RBAC capabilities control who can edit, delete, approve transfers, and more.</li>
      </ul>`,
    tips: [
      { type: 'info', text: '<b>Tip:</b> The default classification "Routine" is auto-created for every new tenant so you can start adding stock immediately.' },
    ],
  },
  {
    id: 'ims-overview',
    title: 'Overview Dashboard',
    icon: 'mdi-view-dashboard-outline',
    color: 'primary',
    tagline: 'Real-time warehouse snapshot — stock, expiry, procurement, fulfilment, sales.',
    body: `
      <p>The <b>Overview</b> page (<code>/inventory/overview</code>) provides a live picture of your warehouse health across multiple dimensions.</p>
      <h4>KPI strip</h4>
      <ul>
        <li><b>Stock health</b> — total items, low stock, out of stock, healthy, total units on hand</li>
        <li><b>Expiry</b> — batches expiring ≤30 days, ≤90 days, and already expired</li>
        <li><b>Deliveries</b> — items to be packed, to be shipped / in transit</li>
        <li><b>Procurement</b> — items received, received GRNs, open purchase orders</li>
        <li><b>Sales</b> — units sold, revenue</li>
      </ul>
      <h4>Chart cards</h4>
      <ol>
        <li><b>Stock Health</b> — donut chart (Healthy / Low / Out segments) with summary stats and quick link to manage stock items</li>
        <li><b>Expiry</b> — three list items (≤30d, ≤90d, expired) with colour-coded day counts and navigation links</li>
        <li><b>Outbound fulfilment</b> — to-be-pack and to-ship counts with links to deliveries</li>
        <li><b>Inbound procurement</b> — items received, received GRNs, open POs with link to purchase orders</li>
        <li><b>Sales</b> — units sold, revenue, and a recent completed sales table (transaction #, customer, total)</li>
      </ol>
      <h4>Bottom tables</h4>
      <ul>
        <li><b>Top moving items</b> — ranked by quantity sold and revenue</li>
        <li><b>Dead stock</b> — items with no movement, showing idle days ("never" if no sale recorded)</li>
        <li><b>Recent stock movements</b> — mixed ledger of the latest inflows, outflows, and transfers</li>
      </ul>`,
    tips: [
      { type: 'info', text: '<b>Tip:</b> Use the date preset chips (Today, 7d, 30d, 90d, YTD, Custom) to scope the dashboard to a specific period.' },
    ],
  },
  {
    id: 'ims-stock-items',
    title: 'Stock Items & Batches',
    icon: 'mdi-package-variant-closed',
    color: 'amber-darken-2',
    tagline: 'Create, manage, and track items with batch-level FEFO control.',
    body: `
      <p>The <b>Stock Items</b> page (<code>/inventory</code>) is the main hub. It shows five tabs: <b>Stocks</b>, <b>Categories</b>, <b>Classifications</b>, <b>Units</b>, and <b>Adjustments</b>.</p>
      <h4>Creating a stock item</h4>
      <ol>
        <li>Click <b>Add Stock</b> to open the stock form.</li>
        <li>Fill in <b>Medication Name</b> — the system auto-fills generic name, strength, dosage form, and brand from the global medication catalog when possible.</li>
        <li>Select <b>Category</b>, <b>Classification</b>, <b>Unit</b>, and <b>Branch</b>.</li>
        <li>Set <b>Cost Price</b>, <b>Selling Price</b>, <b>Tax %</b>, <b>Discount %</b>.</li>
        <li>Set <b>Reorder Level</b> and <b>Reorder Quantity</b> for automated low-stock alerts.</li>
        <li>Optionally enter <b>Barcode</b>, <b>Location in Store</b> (shelf/bin), <b>Items per Unit</b>, and <b>Prescription Required</b> (none / recommended / required).</li>
        <li>Save — a unique <code>MED-#####</code> medication ID is auto-generated.</li>
      </ol>
      <h4>Batch management (FEFO)</h4>
      <p>Each stock item holds one or more <b>batches</b>. A batch records:</p>
      <ul>
        <li>Batch number, quantity received, quantity remaining</li>
        <li>Cost price per unit, expiry date, received date, supplier</li>
        <li>Branch (physical location of the batch)</li>
      </ul>
      <p>Batches are ordered by expiry date (First-Expiry-First-Out). When stock is sold, adjusted, or transferred, the system drains from the nearest-expiry batch first.</p>
      <div class="docs-csv-table">
        <table>
          <thead><tr><th>Batch #</th><th>Qty Received</th><th>Qty Remaining</th><th>Expiry</th><th>Cost/Unit</th></tr></thead>
          <tbody>
            <tr><td>BN-001</td><td>500</td><td>320</td><td style="color:#dc2626">12 Nov 2026</td><td>KSh 12.00</td></tr>
            <tr><td>BN-002</td><td>1,000</td><td>1,000</td><td style="color:#16a34a">15 Mar 2027</td><td>KSh 11.50</td></tr>
            <tr><td>BN-003</td><td>750</td><td>700</td><td style="color:#16a34a">08 Aug 2027</td><td>KSh 10.80</td></tr>
          </tbody>
        </table>
        <div class="docs-csv-caption">Example: Batch ledger for Paracetamol 500mg — FEFO drains BN-001 first</div>
      </div>
      <h4>Stock statuses</h4>
      <ul>
        <li><b>In stock</b> — total quantity > reorder level</li>
        <li><b>Low stock</b> — total quantity ≤ reorder level (amber chip)</li>
        <li><b>Out of stock</b> — total quantity = 0 (red chip)</li>
      </ul>
      <p>The <b>available quantity</b> = total quantity − committed quantity (reserved by paid/partially-paid sales orders).</p>`,
    tips: [
      { type: 'warning', text: '<b>Committed stock:</b> When a sales order is partially or fully paid, the reserved units are deducted from available stock but remain in total quantity until dispatched.' },
      { type: 'success', text: '<b>Auto-fill:</b> If you type a medication name that matches the global catalog, the system auto-populates generic name, strength, dosage form, and brand names.' },
    ],
  },
  {
    id: 'ims-categories',
    title: 'Categories, Classifications & Units',
    icon: 'mdi-tag-multiple-outline',
    color: 'indigo',
    tagline: 'Organise stock with taxonomy for filtering and analytics.',
    body: `
      <h4>Categories</h4>
      <p>Group stock items by therapeutic or functional category (e.g. Analgesics, Antibiotics, Antimalarials). Each category shows SKU count, total units on hand, retail value, and share % with a progress bar.</p>
      <h4>Classifications</h4>
      <p>Classify items by handling type: <b>Routine</b> (auto-created default), <b>Emergency</b>, <b>Cold Chain</b>, <b>Controlled</b>, or any custom classification. Toggle active/inactive. Used in filtering and analytics.</p>
      <h4>Units of Measure</h4>
      <p>Define units such as <i>tablets</i> (tab), <i>capsules</i> (cap), <i>millilitres</i> (ml), <i>milligrams</i> (mg). Each unit shows the SKU count and total on-hand quantity.</p>
      <div class="docs-csv-table">
        <table>
          <thead><tr><th>Category</th><th>SKUs</th><th>Units on Hand</th><th>Retail Value</th><th>Share</th></tr></thead>
          <tbody>
            <tr><td>Analgesics</td><td>24</td><td>8,420</td><td>KSh 421,000</td><td>32%</td></tr>
            <tr><td>Antibiotics</td><td>18</td><td>3,150</td><td>KSh 283,500</td><td>22%</td></tr>
            <tr><td>Antimalarials</td><td>12</td><td>2,800</td><td>KSh 196,000</td><td>15%</td></tr>
            <tr><td>Antacids</td><td>9</td><td>1,900</td><td>KSh 85,500</td><td>7%</td></tr>
          </tbody>
        </table>
        <div class="docs-csv-caption">Example: Category breakdown from the Categories tab</div>
      </div>`,
  },
  {
    id: 'ims-stock-movements',
    title: 'Stock Movements Ledger',
    icon: 'mdi-swap-horizontal',
    color: 'info',
    tagline: 'Full audit trail of every inflow, outflow, and transfer.',
    body: `
      <p>The <b>Stock Movements</b> page (<code>/inventory/stock-movements</code>) tracks every stock transaction with a running balance audit trail.</p>
      <h4>Four analytical tabs</h4>
      <ol>
        <li><b>Movement ledger</b> — full detail table: item + batch, direction chip (inflow / outflow / transfer), reference, reason, quantity change (+/−), value change, quantity before, quantity after, user, notes, timestamp</li>
        <li><b>Per item</b> — aggregated per-item: total inflow, outflow, transfer, net change</li>
        <li><b>Transfers</b> — transfer-specific KPIs (sent, received, variance, cycle time), by-route table (source → dest with variance), by-item table</li>
        <li><b>Visualization</b> — daily movement trend (area chart), movement reasons donut, inflow vs outflow grouped bars, top movers list</li>
      </ol>
      <h4>KPI tiles</h4>
      <ul>
        <li><b>Total Inflow</b> — units and value</li>
        <li><b>Total Outflow</b> — units and value</li>
        <li><b>Net Change</b> — units and value</li>
        <li><b>Transfers</b> — units and total movement count</li>
      </ul>
      <div class="docs-chart-placeholder">
        <div class="docs-chart-row">
          <div class="docs-mini-chart">
            <div class="docs-mini-chart-icon"><v-icon>mdi-chart-areaspline</v-icon></div>
            <div class="docs-mini-chart-label">Daily movement trend</div>
            <div class="docs-mini-bars">
              <span style="height:30%"></span><span style="height:55%"></span><span style="height:42%"></span>
              <span style="height:70%"></span><span style="height:60%"></span><span style="height:85%"></span>
              <span style="height:50%"></span><span style="height:75%"></span><span style="height:65%"></span>
              <span style="height:90%"></span><span style="height:45%"></span><span style="height:60%"></span>
            </div>
          </div>
          <div class="docs-mini-chart">
            <div class="docs-mini-chart-icon"><v-icon>mdi-chart-donut</v-icon></div>
            <div class="docs-mini-chart-label">Movement reasons</div>
            <div class="docs-mini-donut">
              <div class="docs-donut-ring" style="--p1: 35%; --p2: 25%; --p3: 20%; --p4: 20%"></div>
            </div>
          </div>
          <div class="docs-mini-chart">
            <div class="docs-mini-chart-icon"><v-icon>mdi-chart-bar</v-icon></div>
            <div class="docs-mini-chart-label">Inflow vs outflow</div>
            <div class="docs-mini-bars-group">
              <span><i style="height:40%"></i><i style="height:65%"></i></span>
              <span><i style="height:55%"></i><i style="height:30%"></i></span>
              <span><i style="height:70%"></i><i style="height:45%"></i></span>
              <span><i style="height:50%"></i><i style="height:60%"></i></span>
              <span><i style="height:35%"></i><i style="height:75%"></i></span>
            </div>
          </div>
        </div>
      </div>
      <h4>Filters</h4>
      <ul>
        <li>Item autocomplete, type (inflow / outflow / transfer), reason dropdown, text search</li>
        <li>Date range chips: 7d, 30d, 90d, YTD, Custom</li>
      </ul>
      <h4>Export</h4>
      <p>Export the filtered ledger to <b>PDF</b> or <b>CSV</b> for reporting.</p>`,
    tips: [
      { type: 'info', text: '<b>Tip:</b> The per-item tab is useful for reconciling net stock changes — filter to a single item to see its complete movement history.' },
    ],
  },
  {
    id: 'ims-stock-analysis',
    title: 'Stock Analysis & Valuation',
    icon: 'mdi-chart-box-outline',
    color: 'purple',
    tagline: 'Inventory health, valuation, expiry risk, and movement analytics.',
    body: `
      <p>The <b>Stock Analysis</b> page (<code>/inventory/stock-analysis</code>) computes analytics from your full stock list and adjustment history.</p>
      <h4>KPI cards (5)</h4>
      <ol>
        <li><b>Total SKUs</b> — item count + total units on hand</li>
        <li><b>Inventory cost (before tax)</b> — Σ(qty × cost_price)</li>
        <li><b>Retail value (inc. tax)</b> — Σ(qty × selling_price) + profit potential</li>
        <li><b>Retail value (exc. tax)</b> — Retail minus computed VAT per item, with expected profit excl. VAT</li>
        <li><b>Needs attention</b> — low + out of stock count, with OOS chip and low/expiring breakdown</li>
      </ol>
      <h4>Charts & visualizations</h4>
      <div class="docs-chart-placeholder">
        <div class="docs-chart-row">
          <div class="docs-mini-chart">
            <div class="docs-mini-chart-icon"><v-icon>mdi-chart-donut</v-icon></div>
            <div class="docs-mini-chart-label">Stock health</div>
            <div class="docs-mini-donut">
              <div class="docs-donut-ring docs-donut--health" style="--p1: 72%; --p2: 18%; --p3: 10%"></div>
            </div>
            <div class="docs-chart-legend">
              <span><i class="dot" style="background:#16a34a"></i> In stock 72%</span>
              <span><i class="dot" style="background:#f59e0b"></i> Low 18%</span>
              <span><i class="dot" style="background:#dc2626"></i> Out 10%</span>
            </div>
          </div>
          <div class="docs-mini-chart">
            <div class="docs-mini-chart-icon"><v-icon>mdi-chart-bar</v-icon></div>
            <div class="docs-mini-chart-label">Value by category (top 10)</div>
            <div class="docs-mini-bars">
              <span style="height:85%;background:#6366f1"></span>
              <span style="height:70%;background:#6366f1"></span>
              <span style="height:55%;background:#6366f1"></span>
              <span style="height:42%;background:#6366f1"></span>
              <span style="height:35%;background:#6366f1"></span>
              <span style="height:28%;background:#6366f1"></span>
              <span style="height:22%;background:#6366f1"></span>
              <span style="height:18%;background:#6366f1"></span>
            </div>
          </div>
          <div class="docs-mini-chart">
            <div class="docs-mini-chart-icon"><v-icon>mdi-calendar-alert</v-icon></div>
            <div class="docs-mini-chart-label">Expiry risk timeline</div>
            <div class="docs-mini-bars">
              <span style="height:15%;background:#dc2626"></span>
              <span style="height:25%;background:#f59e0b"></span>
              <span style="height:40%;background:#eab308"></span>
              <span style="height:55%;background:#84cc16"></span>
              <span style="height:70%;background:#22c55e"></span>
              <span style="height:85%;background:#16a34a"></span>
            </div>
            <div class="docs-chart-legend">
              <span>Expired</span><span>&lt;30d</span><span>90d</span><span>180d</span><span>1yr</span><span>&gt;1yr</span>
            </div>
          </div>
        </div>
      </div>
      <h4>Valuation overview</h4>
      <p>Side-by-side comparison: <b>Cost</b> vs <b>Retail (excl. tax)</b> vs <b>Potential profit</b>, with an area chart showing category value distribution.</p>
      <h4>Adjustment reasons donut</h4>
      <p>Visual breakdown of adjustment reasons: Damage, Theft, Expiry, Count Correction, Return to Supplier, Other — with legend.</p>
      <h4>Reorder priority table</h4>
      <p>Items at or below reorder level, showing on-hand quantity, reorder level, and status chip. Sorted by urgency.</p>
      <div class="docs-csv-table">
        <table>
          <thead><tr><th>Item</th><th>On Hand</th><th>Reorder Level</th><th>Status</th></tr></thead>
          <tbody>
            <tr><td>Amoxicillin 250mg</td><td>5</td><td>20</td><td><span style="color:#dc2626;font-weight:700">OUT</span></td></tr>
            <tr><td>Metformin 500mg</td><td>8</td><td>15</td><td><span style="color:#f59e0b;font-weight:700">LOW</span></td></tr>
            <tr><td>Omeprazole 20mg</td><td>12</td><td>15</td><td><span style="color:#f59e0b;font-weight:700">LOW</span></td></tr>
            <tr><td>Paracetamol 500mg</td><td>320</td><td>50</td><td><span style="color:#16a34a;font-weight:700">OK</span></td></tr>
          </tbody>
        </table>
        <div class="docs-csv-caption">Example: Reorder priority table — sorted by urgency</div>
      </div>
      <h4>Expiring within 90 days</h4>
      <p>Detailed list of batches expiring soon: item, batch number, quantity, days left (colour-coded chip), expiry date.</p>`,
    tips: [
      { type: 'warning', text: '<b>Expiry risk:</b> The timeline chart buckets batches into 6 expiry ranges. Red = expired, amber = ≤30 days. Act on expired and short-dated batches first.' },
      { type: 'success', text: '<b>Profit insight:</b> The valuation overview shows your potential profit margin at a glance — useful for procurement planning.' },
    ],
  },
  {
    id: 'ims-stock-take',
    title: 'Stock Take / Cycle Count',
    icon: 'mdi-clipboard-check-outline',
    color: 'pink',
    tagline: 'Create counts, enter physical quantities, and auto-reconcile variances.',
    body: `
      <p>The <b>Stock Take</b> page (<code>/inventory/stock-take</code>) manages cycle counts and reconciliation.</p>
      <h4>Workflow</h4>
      <ol>
        <li><b>Create count</b> — enter a name (e.g. "Monthly count — Oct 2026"), optionally select Branch and Category to scope. Click create.</li>
        <li><b>Generate sheet</b> — the system auto-populates count lines with current expected (system) quantities for every matching stock item.</li>
        <li><b>Enter physical counts</b> — open the count detail dialog. For each item, enter the <b>Counted</b> quantity in the editable field. The <b>Variance</b> (counted − expected) and <b>Value</b> (variance × cost) are auto-calculated.</li>
        <li><b>Save counts</b> — save progress at any time. You can resume and re-save multiple times before completing.</li>
        <li><b>Complete & Reconcile</b> — click <b>Complete</b> to finalise. The system creates <code>count_correction</code> StockAdjustments for each variance line:
          <ul>
            <li>Positive variance → stock added (creates a synthetic batch for the surplus)</li>
            <li>Negative variance → stock removed using FEFO drain</li>
          </ul>
        </li>
      </ol>
      <h4>KPIs</h4>
      <ul>
        <li>Total Counts, In Progress, Completed, Variance Value (KSh)</li>
      </ul>
      <div class="docs-csv-table">
        <table>
          <thead><tr><th>Reference</th><th>Name</th><th>Progress</th><th>Variance</th><th>Status</th></tr></thead>
          <tbody>
            <tr><td>CNT-001</td><td>Monthly count — Oct 2026</td><td>240 / 240</td><td style="color:#dc2626">−12 units (KSh 144)</td><td><span style="color:#16a34a">Completed</span></td></tr>
            <tr><td>CNT-002</td><td>Antibiotics spot check</td><td>18 / 45</td><td>—</td><td><span style="color:#0ea5e9">In Progress</span></td></tr>
            <tr><td>CNT-003</td><td>Q3 Annual count</td><td>0 / 0</td><td>—</td><td><span style="color:#94a3b8">Draft</span></td></tr>
          </tbody>
        </table>
        <div class="docs-csv-caption">Example: Stock take list — reference auto-generated as CNT-#####</div>
      </div>`,
    tips: [
      { type: 'info', text: '<b>Tip:</b> Scope your count by category to make large inventories manageable — do antibiotics one day, analgesics the next.' },
      { type: 'warning', text: '<b>Reconciliation is irreversible:</b> Once you click Complete, count-correction adjustments are created and the count status changes to Completed. Review variances carefully before completing.' },
    ],
  },
  {
    id: 'ims-transfers',
    title: 'Branch Transfers',
    icon: 'mdi-truck-fast-outline',
    color: 'success',
    tagline: 'Move stock between warehouses with approval, receipt, and variance tracking.',
    body: `
      <p>The <b>Branch Transfers</b> page (<code>/inventory/transfers</code>) manages stock movement between warehouse locations.</p>
      <h4>Status flow</h4>
      <div class="docs-flow-diagram">
        <span class="docs-flow-step">Draft</span>
        <span class="docs-flow-arrow">→</span>
        <span class="docs-flow-step">Requested</span>
        <span class="docs-flow-arrow">→</span>
        <span class="docs-flow-step docs-flow-step--active">In Transit</span>
        <span class="docs-flow-arrow">→</span>
        <span class="docs-flow-step docs-flow-step--done">Completed</span>
      </div>
      <h4>Creating a transfer</h4>
      <ol>
        <li>Click <b>New Transfer</b>.</li>
        <li>Select <b>Source warehouse</b> and <b>Destination warehouse</b> (must be different).</li>
        <li>Search and add line items — the autocomplete shows on-hand, cost, and unit for each item.</li>
        <li>Enter the <b>quantity to send</b> per line. Warnings appear if qty exceeds available stock.</li>
        <li>Add a reason/notes (optional, with quick-pick reason chips).</li>
        <li>Click <b>Save Draft</b> or <b>Submit for Approval</b>.</li>
      </ol>
      <h4>Approval & shipping</h4>
      <p>When a transfer is approved, the system:</p>
      <ul>
        <li>Atomically deducts stock from the source branch (creates <code>sales_order</code> type adjustments)</li>
        <li>Books the stock onto a <code>TRF-{reference}</code> batch</li>
        <li>Sets status to <b>In Transit</b> and records the shipped timestamp</li>
        <li>Sends notification to the requester</li>
      </ul>
      <h4>Receiving</h4>
      <p>At the destination warehouse, the receiving clerk:</p>
      <ul>
        <li>Opens the transfer detail and clicks <b>Receive</b></li>
        <li>Enters the actual quantity received per line (with All/None quick buttons)</li>
        <li>Notes any per-item discrepancies (e.g. "2 units damaged")</li>
        <li>Confirms receipt — the system books received quantities into the destination branch and records variance</li>
      </ul>
      <h4>KPIs (6 cards)</h4>
      <p>Total transfers, Draft, Requested, In Transit, Completed, Cancelled.</p>
      <div class="docs-csv-table">
        <table>
          <thead><tr><th>Reference</th><th>Route</th><th>Items</th><th>Value</th><th>Status</th></tr></thead>
          <tbody>
            <tr><td>TRF-001</td><td>Main WH → Branch A</td><td>5 items, 200 units</td><td>KSh 4,200</td><td><span style="color:#16a34a">Completed</span></td></tr>
            <tr><td>TRF-002</td><td>Branch A → Branch B</td><td>3 items, 80 units</td><td>KSh 1,800</td><td><span style="color:#0ea5e9">In Transit</span></td></tr>
            <tr><td>TRF-003</td><td>Main WH → Branch B</td><td>8 items, 350 units</td><td>KSh 6,500</td><td><span style="color:#f59e0b">Requested</span></td></tr>
          </tbody>
        </table>
        <div class="docs-csv-caption">Example: Transfer list — reference auto-generated as TRF-#####</div>
      </div>`,
    tips: [
      { type: 'warning', text: '<b>Short receipts:</b> If received qty < sent qty, the variance is recorded but no stock is automatically adjusted at the source — investigate discrepancies manually.' },
      { type: 'success', text: '<b>CSV export:</b> Use the Export button to download the full transfer list with line items for offline reconciliation.' },
    ],
  },
  {
    id: 'ims-adjustments',
    title: 'Stock Adjustments',
    icon: 'mdi-scale-balance',
    color: 'error',
    tagline: 'Record quantity corrections with reason codes and full audit trail.',
    body: `
      <p>The <b>Adjustments</b> feature (<code>/inventory/adjustments/new</code>) records manual stock corrections with reason codes.</p>
      <h4>Creating an adjustment</h4>
      <ol>
        <li>Select a <b>stock item</b> (required) and optionally a specific <b>batch</b>.</li>
        <li>Enter <b>quantity change</b> — positive for additions, negative for removals.</li>
        <li>Choose a <b>reason</b>:</li>
        <li>Add <b>notes</b> (optional) with details.</li>
        <li>Save — the adjustment is recorded with the current user and timestamp.</li>
      </ol>
      <h4>Reason codes</h4>
      <div class="docs-csv-table">
        <table>
          <thead><tr><th>Reason</th><th>Use Case</th><th>Qty Direction</th></tr></thead>
          <tbody>
            <tr><td><span class="docs-reason-chip" style="background:#fee2e2;color:#dc2626">Damage</span></td><td>Items damaged in storage or transit</td><td>− (negative)</td></tr>
            <tr><td><span class="docs-reason-chip" style="background:#fef3c7;color:#d97706">Theft</span></td><td>Reported theft or unexplained loss</td><td>− (negative)</td></tr>
            <tr><td><span class="docs-reason-chip" style="background:#fee2e2;color:#dc2626">Expiry</span></td><td>Beyond shelf life — destroy expired batches</td><td>− (negative)</td></tr>
            <tr><td><span class="docs-reason-chip" style="background:#dbeafe;color:#2563eb">Count Correction</span></td><td>Reconciliation from stock take</td><td>± (either)</td></tr>
            <tr><td><span class="docs-reason-chip" style="background:#f3e8ff;color:#9333ea">Return to Supplier</span></td><td>Send stock back to supplier</td><td>− (negative)</td></tr>
            <tr><td><span class="docs-reason-chip" style="background:#dcfce7;color:#16a34a">Sales Order</span></td><td>Auto-generated by transfer dispatch</td><td>− (negative)</td></tr>
            <tr><td><span class="docs-reason-chip" style="background:#f1f5f9;color:#64748b">Other</span></td><td>Any other reason with notes</td><td>± (either)</td></tr>
          </tbody>
        </table>
        <div class="docs-csv-caption">Adjustment reason codes and their typical usage</div>
      </div>
      <p>Every adjustment is visible in the <b>Adjustments</b> tab on the main Stock Items page, showing item, reason chip with colour/icon, quantity change (±), notes, adjusted by, and timestamp.</p>`,
    tips: [
      { type: 'warning', text: '<b>Audit trail:</b> All adjustments are permanent records — they cannot be deleted. If you make a mistake, create a compensating adjustment with an explanatory note.' },
    ],
  },
  {
    id: 'ims-bulk-edit',
    title: 'Bulk Edit & Delete',
    icon: 'mdi-table-edit',
    color: 'indigo',
    tagline: 'Spreadsheet-style mass editing and deletion of stock items.',
    body: `
      <p>The <b>Bulk</b> page (<code>/inventory/bulk</code>) lets you edit or delete many stock items at once — ideal for price updates, reassignments, or cleanup.</p>
      <h4>Edit mode</h4>
      <p>A spreadsheet with inline-editable cells. The following fields are editable:</p>
      <ul>
        <li><b>Text fields</b> — medication name, location, barcode</li>
        <li><b>Dropdowns</b> — category, unit, prescription required (none / recommended / required)</li>
        <li><b>Numbers</b> — cost price, selling price, discount %, reorder level, reorder quantity, on-hand quantity, items per unit</li>
        <li><b>Toggle</b> — active (enable/disable stock item)</li>
      </ul>
      <p>Changed rows are highlighted (dirty tracking). Click <b>Save All</b> to commit — the backend whitelist only accepts approved fields. Changing the on-hand quantity creates a <code>count_correction</code> adjustment automatically.</p>
      <h4>Delete mode</h4>
      <p>Toggle to Delete mode, select rows by checkbox, and click the floating delete button. This sends a <code>bulk-delete</code> request. Only <code>tenant_admin</code> and <code>inventory_admin</code> roles can delete.</p>
      <h4>KPI strip</h4>
      <ul>
        <li>Total Items, Visible, Selected, Unsaved changes (edit) / To Remove (delete)</li>
      </ul>
      <h4>Features</h4>
      <ul>
        <li>Configurable page sizes: 25 / 50 / 100 / 200 rows per page</li>
        <li>Fullscreen toggle for wide spreadsheets</li>
        <li>Discard changes button to revert unsaved edits</li>
        <li>Floating save/delete button on mobile</li>
      </ul>`,
    tips: [
      { type: 'info', text: '<b>Tip:</b> Use Bulk Edit for seasonal price updates — sort by category, filter, and update prices in a single Save All operation.' },
      { type: 'warning', text: '<b>Quantity changes create adjustments:</b> Editing the on-hand quantity doesn\'t silently overwrite — it creates a count_correction adjustment so the audit trail remains intact.' },
    ],
  },
  {
    id: 'ims-excel',
    title: 'Excel Import & Export',
    icon: 'mdi-file-excel-outline',
    color: 'success',
    tagline: 'Move inventory in and out of AdhereMed with spreadsheets.',
    body: `
      <p>The <b>Excel</b> page (<code>/inventory/excel</code>) supports full bulk import and export of stock items.</p>
      <h4>Export</h4>
      <ul>
        <li><b>Import Template (.xlsx)</b> — styled spreadsheet with headers, an example row, dropdowns for Branch / Classification / Prescription, and an instructions sheet</li>
        <li><b>Export to Excel (.xlsx)</b> — full inventory with all fields</li>
        <li><b>Export CSV</b> — lightweight flat-file export</li>
        <li><b>Export PDF</b> — formatted print-ready report</li>
      </ul>
      <h4>Import workflow</h4>
      <div class="docs-flow-diagram">
        <span class="docs-flow-step">1. Download template</span>
        <span class="docs-flow-arrow">→</span>
        <span class="docs-flow-step">2. Fill rows</span>
        <span class="docs-flow-arrow">→</span>
        <span class="docs-flow-step">3. Upload & preview</span>
        <span class="docs-flow-arrow">→</span>
        <span class="docs-flow-step">4. Review & edit</span>
        <span class="docs-flow-arrow">→</span>
        <span class="docs-flow-step docs-flow-step--done">5. Commit</span>
      </div>
      <ol>
        <li>Download the import template and fill in your stock data.</li>
        <li><b>Drag & drop</b> or browse for the file (up to ~5,000 rows).</li>
        <li>The system parses and validates — each row gets a status: <span style="color:#16a34a">new</span>, <span style="color:#0ea5e9">update</span>, or <span style="color:#dc2626">error</span>.</li>
        <li>Review the editable table — fix errors, add missing fields, remove unwanted rows. Summary chips show total / new / updates / errors.</li>
        <li>Submit → the system creates new stock items, updates existing ones, and auto-creates categories, classifications, and units if they don't exist.</li>
      </ol>
      <h4>Matching logic</h4>
      <p>Items are matched by <b>(medication_name, branch)</b> — the same item name in different warehouses creates separate entries. Categories, classifications, and units are auto-created if they don't already exist.</p>
      <h4>CSV template columns</h4>
      <div class="docs-csv-table">
        <table>
          <thead><tr><th>Column</th><th>Required</th><th>Example</th></tr></thead>
          <tbody>
            <tr><td>Medication Name</td><td>✓</td><td>Paracetamol 500mg</td></tr>
            <tr><td>Brand</td><td>—</td><td>Panadol</td></tr>
            <tr><td>Generic</td><td>—</td><td>Paracetamol</td></tr>
            <tr><td>Strength</td><td>—</td><td>500mg</td></tr>
            <tr><td>Dosage Form</td><td>—</td><td>tablet</td></tr>
            <tr><td>Branch</td><td>✓ (new items)</td><td>Main Warehouse</td></tr>
            <tr><td>Category</td><td>—</td><td>Analgesics</td></tr>
            <tr><td>Classification</td><td>—</td><td>Routine</td></tr>
            <tr><td>Unit</td><td>—</td><td>tablets</td></tr>
            <tr><td>Sell Price</td><td>—</td><td>15.00</td></tr>
            <tr><td>Cost Price</td><td>—</td><td>10.50</td></tr>
            <tr><td>Qty</td><td>—</td><td>500</td></tr>
            <tr><td>Reorder Level</td><td>—</td><td>50</td></tr>
            <tr><td>Barcode</td><td>—</td><td>5901234123457</td></tr>
            <tr><td>Rx</td><td>—</td><td>none</td></tr>
            <tr><td>Active</td><td>—</td><td>TRUE</td></tr>
          </tbody>
        </table>
        <div class="docs-csv-caption">Import template columns — auto-generated by the downloadable template</div>
      </div>`,
    tips: [
      { type: 'info', text: '<b>Tip:</b> Download the template first — it includes dropdown validation for Branch, Classification, and Prescription fields, plus an instructions sheet with column descriptions.' },
      { type: 'success', text: '<b>Auto-create:</b> If you reference a category, classification, or unit that doesn\'t exist yet, the import automatically creates it. No need to set up taxonomy in advance.' },
    ],
  },
  {
    id: 'ims-controlled-register',
    title: 'Controlled Substance Register',
    icon: 'mdi-shield-account-lock-outline',
    color: 'error',
    tagline: 'Regulatory-grade audit trail for controlled and scheduled medications.',
    body: `
      <p>The <b>Controlled Register</b> page (<code>/inventory/controlled-register</code>) maintains a regulatory-grade log for all controlled substances (Schedule I–V).</p>
      <h4>KPIs</h4>
      <ul>
        <li>Total Entries, Dispensed count, Received count, Destroyed count</li>
      </ul>
      <h4>Filters</h4>
      <ul>
        <li>Medication name, Action (all / dispensed / received / adjusted / destroyed / transferred / returned), Schedule (I–V), Date from, Date to</li>
      </ul>
      <h4>Log table</h4>
      <p>Each entry records:</p>
      <ul>
        <li>Date/time, medication name (with schedule chip), action chip (colour-coded)</li>
        <li>Quantity (±), balance after, batch number</li>
        <li>Patient (name + ID), prescriber (name + prescription reference)</li>
        <li>Recorded by user</li>
      </ul>
      <h4>Manual entry</h4>
      <p>Create entries manually with: medication name, schedule, action, quantity, batch number, balance after, patient name, patient ID, prescriber name, prescription reference, and notes.</p>
      <div class="docs-csv-table">
        <table>
          <thead><tr><th>Date</th><th>Medication</th><th>Action</th><th>Qty</th><th>Balance</th><th>Patient</th></tr></thead>
          <tbody>
            <tr><td>Oct 12, 14:30</td><td>Morphine 10mg <span style="font-size:10px;color:#dc2626">(Sched II)</span></td><td><span class="docs-reason-chip" style="background:#dbeafe;color:#2563eb">Dispensed</span></td><td>−5</td><td>120</td><td>John Doe</td></tr>
            <tr><td>Oct 12, 09:15</td><td>Fentanyl 50mcg <span style="font-size:10px;color:#dc2626">(Sched II)</span></td><td><span class="docs-reason-chip" style="background:#dcfce7;color:#16a34a">Received</span></td><td>+100</td><td>200</td><td>—</td></tr>
            <tr><td>Oct 11, 16:45</td><td>Morphine 10mg <span style="font-size:10px;color:#dc2626">(Sched II)</span></td><td><span class="docs-reason-chip" style="background:#fee2e2;color:#dc2626">Destroyed</span></td><td>−10</td><td>125</td><td>—</td></tr>
          </tbody>
        </table>
        <div class="docs-csv-caption">Example: Controlled substance register — printable for regulatory auditing</div>
      </div>
      <p>Entries are also auto-generated by the system when controlled medications are dispensed via POS, received via purchase orders, or transferred between branches.</p>`,
    tips: [
      { type: 'warning', text: '<b>Regulatory compliance:</b> The controlled register is designed for pharmacy board inspection. Use the Print function to generate a hard copy for auditors.' },
    ],
  },
  {
    id: 'ims-insights',
    title: 'Item Insights & PDF Reports',
    icon: 'mdi-chart-line-variant',
    color: 'teal',
    tagline: 'Deep-dive analytics per stock item with branded PDF export.',
    body: `
      <p>Each stock item has a dedicated <b>Insights</b> view (<code>/inventory/stocks/{id}</code>) and a downloadable PDF report.</p>
      <h4>Insights view includes</h4>
      <ul>
        <li><b>Opening stock</b> — quantity at the start of the selected period</li>
        <li><b>Period movements</b> — received (inflow), sold (outflow), returned, adjusted, transferred</li>
        <li><b>Purchase history</b> — every GRN with price tracking (shows price evolution)</li>
        <li><b>Recent sales</b> — latest transactions with customer and quantity</li>
        <li><b>Full movement ledger</b> — running balances with every transaction</li>
        <li><b>Batch list</b> — all active batches with expiry dates and FEFO ordering</li>
        <li><b>Daily trends</b> — area chart of net daily stock movement</li>
      </ul>
      <h4>PDF report</h4>
      <p>Click the report icon to download a branded PDF (<code>GET /inventory/stocks/{id}/report-pdf/</code>) — generated with ReportLab, including tenant branding, item details, movement history, and batch breakdown.</p>`,
    tips: [
      { type: 'info', text: '<b>Tip:</b> Use the period selector (Today, 7d, 30d, 90d, YTD, Custom) on the insights page to scope analytics to a specific reporting window.' },
    ],
  },
  {
    id: 'ims-rbac',
    title: 'Roles & Permissions (RBAC)',
    icon: 'mdi-shield-account',
    color: 'primary',
    tagline: 'Capability-based access control for warehouse operations.',
    body: `
      <p>The inventory module uses AdhereMed's <b>Role-Based Access Control</b> (RBAC) system with a capability matrix.</p>
      <div class="docs-csv-table">
        <table>
          <thead><tr><th>Capability</th><th>Admin</th><th>Inv. Admin</th><th>Branch Admin</th><th>Storekeeper</th></tr></thead>
          <tbody>
            <tr><td>View stock items</td><td>✓</td><td>✓</td><td>✓ (own branch)</td><td>✓</td></tr>
            <tr><td>Create / edit stock</td><td>✓</td><td>✓</td><td>✓ (own branch)</td><td>✗</td></tr>
            <tr><td>Delete stock</td><td>✓</td><td>✓</td><td>✗</td><td>✗</td></tr>
            <tr><td>Bulk edit / delete</td><td>✓</td><td>✓</td><td>✓ (edit)</td><td>✗</td></tr>
            <tr><td>Approve transfers</td><td>✓</td><td>✓</td><td>✓ (own)</td><td>✗</td></tr>
            <tr><td>Receive transfers</td><td>✓</td><td>✓</td><td>✓ (own)</td><td>✓</td></tr>
            <tr><td>Stock take — complete</td><td>✓</td><td>✓</td><td>✓</td><td>✗</td></tr>
            <tr><td>Excel import</td><td>✓</td><td>✓</td><td>✗</td><td>✗</td></tr>
          </tbody>
        </table>
        <div class="docs-csv-caption">RBAC capability matrix — roles can be customised per tenant</div>
      </div>
      <h4>Custom roles</h4>
      <p>Tenant admins can create custom roles with specific capabilities via the <b>RBAC</b> settings. Built-in roles can be overridden but not deleted.</p>`,
  },
  {
    id: 'ims-troubleshooting',
    title: 'Troubleshooting',
    icon: 'mdi-lifebuoy',
    color: 'error',
    tagline: 'Common issues and their solutions.',
    body: `
      <ul>
        <li><b>Low stock alert not firing</b> — check that <code>reorder_level</code> is set on the stock item. Items with <code>reorder_level = 0</code> never trigger low stock.</li>
        <li><b>Batch not draining on sale</b> — only batches with <code>quantity_remaining > 0</code> are eligible. Check for expired batches that still have remaining quantity — they drain first via FEFO.</li>
        <li><b>Transfer won't approve</b> — ensure source branch has sufficient available stock (total − committed). Items committed to paid sales orders are reserved.</li>
        <li><b>Stock take variance shows 0 for all items</b> — you may have forgotten to click <b>Generate Sheet</b> before entering counts. The sheet populates expected quantities from the system.</li>
        <li><b>Excel import errors</b> — check that <b>Medication Name</b> is not empty and <b>Branch</b> is specified for new items. The error column in the preview table explains each failure.</li>
        <li><b>Available quantity lower than total</b> — this is expected. Available = total − committed. Check open sales orders for reservations.</li>
        <li><b>Cannot delete a stock item</b> — the item may be referenced by historical batches, adjustments, or transfers. Set <code>is_active = false</code> instead to hide it from POS while preserving audit history.</li>
      </ul>`,
  },
]

const pharmacySections = [
  {
    id: 'getting-started',
    title: 'Getting Started',
    icon: 'mdi-rocket-launch',
    color: 'teal',
    tagline: 'Sign in, navigate, and orient yourself.',
    body: `
      <p>After signing in you land on the <b>Dashboard</b>, which surfaces today's KPIs:
      sales, transactions, low-stock counts, pending deliveries, and shift status.</p>
      <ul>
        <li><b>Sidebar</b> — primary navigation between modules. Pinned modules appear at the top.</li>
        <li><b>Top bar</b> — global search, notifications, theme toggle (light/dark), and your profile menu.</li>
        <li><b>Branch switcher</b> — if your pharmacy has multiple branches, switch context from the top bar.</li>
        <li><b>Roles</b> — features are gated by role: <i>super_admin</i>, <i>tenant_admin</i>, <i>pharmacist</i>, <i>cashier</i>, <i>driver</i>.</li>
      </ul>`,
    tips: [
      { type: 'info', text: '<b>Tip:</b> Press <kbd>Ctrl</kbd>+<kbd>K</kbd> in any module that supports search to focus the search box.' },
    ],
  },
  {
    id: 'pos',
    title: 'Point of Sale (POS)',
    icon: 'mdi-cash-register',
    color: 'success',
    tagline: 'Sell, accept payments, print receipts.',
    body: `
      <p>The POS is your daily sales terminal. Open a <b>shift</b> with an opening float before selling, and close it at end of day to generate a Z-report.</p>
      <h4>Selling</h4>
      <ol>
        <li>Search for an item by name, barcode, or SKU.</li>
        <li>Click the item to add it to the cart. Adjust quantity, discount, or unit price inline.</li>
        <li>Choose a <b>customer</b> (walk-in by default) and a <b>payment method</b>: Cash, Card, M-Pesa, Insurance, or Split.</li>
        <li>For Insurance, select the scheme; the eligible portion is deducted automatically.</li>
        <li>Click <b>Charge</b>. A receipt dialog appears — print or close. Stock is decremented and a transaction is recorded.</li>
      </ol>
      <h4>Held / parked sales</h4>
      <p>Use <b>Hold</b> to park a cart and resume it later (e.g., the customer is fetching their card). Held carts persist across shift sessions.</p>
      <h4>Refunds & voids</h4>
      <p>Open the transaction in <i>POS → History</i>, click the row, and choose <b>Refund</b> or <b>Void</b>. Refunds restore stock; voids do not.</p>`,
    tips: [
      { type: 'warning', text: '<b>Shift required:</b> sales are blocked until you open a shift. Cashiers can only see their own shifts.' },
      { type: 'success', text: 'Receipts now show your tenant name and a <i>Powered by AdhereMed</i> footer.' },
    ],
  },
  {
    id: 'pos-history',
    title: 'POS History & Analytics',
    icon: 'mdi-history',
    color: 'indigo',
    tagline: 'Audit, search, export.',
    body: `
      <p><i>POS → History</i> lists every transaction with filters by date, payment method, cashier, and customer.</p>
      <ul>
        <li>The numbered table shows transaction #, time, items, totals, and status. Click a row to expand the line items.</li>
        <li><b>Export</b> downloads CSV of the filtered set.</li>
        <li><b>Analytics</b> button opens the deeper analytics dashboard (revenue trends, payment mix, hour-of-day, top products).</li>
        <li>Click the receipt icon to reprint. Both the dialog and the printed copy use the tenant name.</li>
      </ul>`,
  },
  {
    id: 'inventory',
    title: 'Inventory & Stock',
    icon: 'mdi-package-variant-closed',
    color: 'amber-darken-2',
    tagline: 'Items, batches, transfers, counts.',
    body: `
      <p>Manage every medication and consumable in one place.</p>
      <h4>Catalog</h4>
      <ul>
        <li><b>Stocks</b> — the master list. Each item has cost, selling price, discount %, reorder level, category, unit, and on-hand quantity.</li>
        <li><b>Categories</b> and <b>Units</b> — create taxonomy used across forms and reports.</li>
        <li><b>Batches</b> — every receipt creates a batch with quantity, cost, and expiry. Stock movements are deducted FIFO by expiry.</li>
      </ul>
      <h4>Bulk editor</h4>
      <p><i>Inventory → Bulk</i> opens a spreadsheet-style editor. Use <b>?mode=edit</b> to inline-edit name, category, unit, prices, reorder level, and quantity for many rows at once. Use <b>?mode=delete</b> to multi-select and remove items.</p>
      <h4>Transfers</h4>
      <p>Move stock between branches. The source branch's quantity decreases when the transfer is created; the destination's increases on receipt.</p>
      <h4>Stock counts</h4>
      <p>Create a count, optionally scoped to a branch and category. Enter physical counts; variances are highlighted with monetary impact.</p>`,
    tips: [
      { type: 'info', text: 'Low-stock items appear with a red pill in any list. The dashboard <i>Low stock</i> KPI links directly here.' },
    ],
  },
  {
    id: 'purchase-orders',
    title: 'Purchase Orders',
    icon: 'mdi-cart-arrow-down',
    color: 'primary',
    tagline: 'Procure stock from suppliers, track GRNs.',
    body: `
      <p>Use POs to formalize stock procurement.</p>
      <h4>Creating a PO</h4>
      <ol>
        <li>Pick a supplier (or type a name to create a new one).</li>
        <li>Add items. For each: pick from existing stocks <i>or</i> type a new item name to auto-create on save.</li>
        <li>Enter quantity, <b>unit cost</b>, optional <b>selling price</b>, discount %, batch #, and expiry date.</li>
        <li>The form shows a live <b>profit margin</b> chip per line and a Projected Revenue / Projected Profit / Margin % summary at the bottom.</li>
        <li>Save as <i>Draft</i>, <i>Sent</i>, or <i>Received</i>. Saving as Received automatically creates batches and updates stock cost & selling price.</li>
      </ol>
      <h4>Returning a PO</h4>
      <p>Open the PO and click <b>Return</b>. A preview shows which units have already been consumed; check <b>Force return</b> to remove only the remaining stock. Selling and cost prices are reverted to their pre-PO values.</p>
      <h4>Goods Received Notes (GRN)</h4>
      <p>For partial deliveries, mark the PO as <i>Partially Received</i> and create GRNs as goods arrive.</p>`,
    tips: [
      { type: 'success', text: 'Profit margin colors: green ≥ 30%, blue ≥ 15%, amber ≥ 0%, red < 0%.' },
    ],
  },
  {
    id: 'accounts',
    title: 'Accounts',
    icon: 'mdi-bank',
    color: 'teal-darken-2',
    tagline: 'Income, expenses, receivables & payables — your full financial position.',
    body: `
      <p>The <i>Accounts</i> module unifies your financial picture across the pharmacy. Open it from the sidebar and switch tabs from the toolbar (or via URL: <code>/accounts?tab=...</code>).</p>
      <h4>Overview</h4>
      <ul>
        <li><b>KPI cards</b> — total revenue, total expenses, net profit/loss, outstanding receivables, outstanding payables, and AdhereMed platform consumption charges for the selected period.</li>
        <li><b>Top receivables</b> and <b>top payables</b> lists with quick links into the full tabs.</li>
        <li><b>Date range selector</b> — Today, Last 7 days, Month to date, Last 90 days, Year to date, or a custom range. The chosen range filters every tab.</li>
      </ul>
      <h4>Receivables</h4>
      <p>Money owed to you — unpaid POS invoices, insurance claims awaiting reimbursement, and customer credit. Aging buckets (current, 1–30, 31–60, 60+ days) highlight risk. Click an invoice to view detail or record a payment.</p>
      <h4>Payables</h4>
      <p>Money you owe — supplier invoices from received POs, expense bills, and platform charges. Aging buckets show overdue amounts. Mark a payable as paid to clear it from the queue.</p>
      <h4>Transactions</h4>
      <p>A unified ledger of every cash movement: POS sales, refunds, expense payments, supplier payments, transfers, and adjustments. Filter by type, account, payment method, and date. Export to CSV.</p>
      <h4>Profit &amp; Loss</h4>
      <p>Income statement for the selected range: revenue (by stream — POS, services, deliveries), cost of goods sold (from batches), gross profit, operating expenses (by category), and net profit. Compare with the previous period for trend.</p>
      <h4>Balance Sheet</h4>
      <p>Snapshot of your financial position as of the selected date. Three sections:</p>
      <ul>
        <li><b>Assets</b> — cash on hand &amp; in bank, receivables, inventory at cost (from current batches), and fixed assets.</li>
        <li><b>Liabilities</b> — payables, supplier balances, platform charges due, and any loans.</li>
        <li><b>Equity</b> — owner's capital plus retained earnings (cumulative net profit). The sheet always satisfies <code>Assets = Liabilities + Equity</code>.</li>
      </ul>
      <p>Switch the <i>As of</i> date to view a historic balance sheet; export to CSV or PDF for filings.</p>
      <h4>General Ledger</h4>
      <p>Double-entry ledger view of every account (Cash, Bank, Receivables, Payables, Sales Revenue, COGS, each Expense category, etc.). For each account you see opening balance, period debits, period credits, and closing balance.</p>
      <ul>
        <li>Click an account to drill into its <b>journal entries</b> with date, source document (POS #, PO #, expense ID), counterpart account, debit/credit, and running balance.</li>
        <li>Filter by account type (Asset, Liability, Equity, Income, Expense), date range, or text search on memo.</li>
        <li>Use <b>Trial Balance</b> from the toolbar to verify total debits equal total credits before closing a period.</li>
        <li>Manual journal entries can be posted from the <b>+ Entry</b> button (admin only) for adjustments such as depreciation or accruals.</li>
      </ul>
      <h4>Exports</h4>
      <p>Use the <b>Export</b> menu in the toolbar to download Receivables, Payables, Transactions, P&amp;L, Balance Sheet, or General Ledger as CSV for accountants or external bookkeeping tools.</p>`,
    tips: [
      { type: 'info', text: '<b>Tip:</b> AdhereMed platform consumption charges appear as a recurring payable; settle them from the Payables tab to keep service active.' },
      { type: 'warning', text: 'Receivables &amp; payables are derived from POS, claims, POs, and expenses — record those accurately and the financials reconcile automatically.' },
    ],
  },
  {
    id: 'dispensing-prescriptions',
    title: 'Dispensing & Prescriptions',
    icon: 'mdi-pill',
    color: 'pink',
    tagline: 'Fulfill prescriptions safely.',
    body: `
      <p>Prescriptions can originate from in-house consultations or external uploads.</p>
      <ul>
        <li><b>Pending</b> — queue awaiting dispense. Pick batches per item; stock moves are recorded.</li>
        <li><b>Counsel</b> — capture dispensing notes (dosage instructions, warnings) printed on the label.</li>
        <li><b>Substitutions</b> — when an item is out of stock, choose a substitute; the original Rx is preserved for audit.</li>
        <li><b>Dispensed history</b> — search by patient, prescriber, or date range.</li>
      </ul>`,
  },
  {
    id: 'pharmacy-profile-branches',
    title: 'Pharmacy Profile & Branches',
    icon: 'mdi-store',
    color: 'blue',
    tagline: 'Tenant settings, branches, geo data.',
    body: `
      <p><i>Settings → Pharmacy Profile</i> stores your business name, license number, logo, hours, services, delivery radius, and insurance acceptance.</p>
      <h4>Branches</h4>
      <p>Create one branch per physical location. The address field accepts <b>three input methods</b>:</p>
      <ol>
        <li><b>Manual entry</b> — just type into the textarea.</li>
        <li><b>Google Places search</b> — type to autocomplete and pick a result; latitude, longitude, and place name are saved.</li>
        <li><b>Pick on map</b> — opens a draggable Google Map. Search, drop the marker, or use GPS. Toggle fullscreen for precision.</li>
      </ol>
      <p>Mark exactly one branch as <b>Main</b>. Inactive branches are excluded from POS, transfers, and reports.</p>`,
    tips: [
      { type: 'info', text: 'Branch coordinates power delivery distance, store-finder UIs, and route optimization.' },
    ],
  },
  {
    id: 'deliveries',
    title: 'Deliveries',
    icon: 'mdi-moped',
    color: 'deep-purple',
    tagline: 'Last-mile fulfillment with GPS.',
    body: `
      <p>Each POS transaction with a delivery component creates a delivery record.</p>
      <h4>Workflow</h4>
      <ol>
        <li><b>Create</b> — link the POS transaction (searchable, or enter manually). Capture recipient name, phone, address, and delivery fee.</li>
        <li><b>Address</b> uses the same picker as branches: manual, Places search, or "use my location" GPS. Lat/lng are stored.</li>
        <li><b>Assign driver</b> — pick a staff user or type a free-text driver name (combobox accepts both).</li>
        <li><b>Status flow</b>: Pending → Assigned → In Transit → Delivered (or Failed / Cancelled).</li>
        <li><b>Detail</b> view shows GPS chip and "Open in Maps" link.</li>
      </ol>`,
  },
  {
    id: 'reports-analytics',
    title: 'Reports & Analytics',
    icon: 'mdi-chart-line',
    color: 'cyan',
    tagline: 'Insights into sales, profit, stock health.',
    body: `
      <p>The <b>Reports</b> hub bundles ready-made reports keyed by URL (e.g. <code>/reports/sales</code>). Each report supports date-range filters, branch scope, and CSV export.</p>
      <ul>
        <li><b>Sales</b> — gross / net / tax / discount, grouped by day, cashier, payment method, or category.</li>
        <li><b>Profit</b> — revenue minus cost from batches; per item and per category.</li>
        <li><b>Stock</b> — on-hand value, expiring batches (30/60/90 days), slow movers, dead stock.</li>
        <li><b>Purchases</b> — PO totals by supplier, lead times, and outstanding GRNs.</li>
        <li><b>Deliveries</b> — completion rate, average time, driver performance.</li>
      </ul>
      <p><b>Analytics</b> dashboard provides charts: revenue trend, payment mix, hour-of-day heatmap, and top products. Use the date picker in the toolbar.</p>`,
  },
  {
    id: 'staff-shifts',
    title: 'Staff & Shifts',
    icon: 'mdi-account-group',
    color: 'orange',
    tagline: 'Users, roles, cash drawers.',
    body: `
      <p>Manage staff under <i>Staff</i>: invite users, set role, assign branch and specialization, activate/deactivate.</p>
      <h4>POS shifts</h4>
      <ul>
        <li>Each cashier opens a shift with an opening float.</li>
        <li>Sales and payments accrue against the shift.</li>
        <li>Closing the shift requires entering the counted cash; variance is recorded automatically.</li>
        <li>The Z-report summarizes totals by payment method and item categories.</li>
      </ul>`,
  },
  {
    id: 'billing-insurance',
    title: 'Billing & Insurance',
    icon: 'mdi-shield-check',
    color: 'green',
    tagline: 'Schemes, claims, commissions.',
    body: `
      <p>Configure accepted insurance providers under <i>Settings → Insurance</i>. Each provider has its own price list, allowed items, and claim format.</p>
      <ul>
        <li>At POS, choose the insurance scheme; eligible portion is calculated and the patient covers the balance.</li>
        <li><b>Claims</b> screen tracks submitted, approved, rejected, and paid claims with timestamps and amounts.</li>
        <li><b>Commissions</b> — track partner / referrer commissions on dispensed items.</li>
      </ul>`,
  },
  {
    id: 'expenses',
    title: 'Expenses',
    icon: 'mdi-cash-minus',
    color: 'red',
    tagline: 'Track operating costs.',
    body: `
      <p>Record expenses by category (rent, utilities, salaries, marketing, etc.). Attach receipts. Recurring expenses can be templated. Expense totals are netted against revenue in the Profit report.</p>`,
  },
  {
    id: 'notifications-messaging',
    title: 'Notifications & Messaging',
    icon: 'mdi-bell-ring',
    color: 'purple',
    tagline: 'Stay informed.',
    body: `
      <p>The bell icon in the top bar shows recent system events: low stock, expiring batches, new prescriptions, delivery updates, shift reminders. Click an item to jump to the source. Use <i>Settings → Notifications</i> to mute categories or change channels (in-app, email, SMS).</p>`,
  },
  {
    id: 'tips-troubleshooting',
    title: 'Tips & Troubleshooting',
    icon: 'mdi-lifebuoy',
    color: 'blue-grey',
    tagline: 'Common issues and quick fixes.',
    body: `
      <ul>
        <li><b>Maps don't load</b> — the Google Maps API key may be invalid or domain-restricted. Contact support.</li>
        <li><b>Receipt doesn't print</b> — check browser pop-up blocker; allow pop-ups for the site.</li>
        <li><b>Stock looks wrong</b> — open the item, view <i>Batches</i>, and verify recent PO/GRN entries. Returns reverse stock and prices.</li>
        <li><b>Can't open a shift</b> — close any prior open shift first; only one shift per cashier per branch.</li>
        <li><b>Permission denied</b> — your role doesn't allow the page. Ask an admin to elevate your role under Staff.</li>
      </ul>`,
  },
]

const homecareSections = [
  {
    id: 'hc-getting-started',
    title: 'Getting Started',
    icon: 'mdi-rocket-launch',
    color: 'teal',
    tagline: 'Sign in, navigate the homecare workspace.',
    body: `
      <p>Homecare tenants land on a dashboard tuned to in-home patient care: today's visits, due doses, overdue vitals, open escalations, and unread messages.</p>
      <ul>
        <li><b>Roles</b>: <i>tenant_admin</i> / <i>homecare_admin</i> manage everything; <i>caregiver</i> sees only "My Day" / assigned patients; <i>patient</i> sees the family-portal experience.</li>
        <li><b>Sidebar</b> groups: <i>Patients</i>, <i>Care Team</i>, <i>Schedules</i>, <i>Medications</i>, <i>Telehealth &amp; Alerts</i>, <i>Family &amp; Admin</i>, <i>Analytics</i>, <i>Clinical Tools</i>.</li>
        <li>Use the branch / company switcher in the top bar if your homecare provider operates multiple companies.</li>
      </ul>`,
  },
  {
    id: 'hc-patients',
    title: 'Patients',
    icon: 'mdi-account-group',
    color: 'blue',
    tagline: 'Enrol, profile, and manage patient records.',
    body: `
      <p><i>Patients → All Patients</i> lists every enrolled patient with quick filters by status, primary caregiver, and condition.</p>
      <h4>Enrolling a patient</h4>
      <ol>
        <li>Click <b>Enrol Patient</b> and complete demographics, address, emergency contacts, allergies, and primary diagnosis.</li>
        <li>Attach insurance details if applicable.</li>
        <li>Assign a primary caregiver and care team members on the right-rail.</li>
        <li>Save — the patient appears in the list and on the assigned caregivers' My Day.</li>
      </ol>
      <p>The patient detail page hosts tabs for Overview, Treatment Plan, Medications, Doses, Vitals, Notes, Consents, and Insurance — each linking back to its dedicated module.</p>`,
    tips: [
      { type: 'info', text: 'Use <b>Care Pathways</b> to apply a templated bundle of plans, medications, and vitals schedules at enrolment.' },
    ],
  },
  {
    id: 'hc-care-team',
    title: 'Care Team & Caregivers',
    icon: 'mdi-account-tie',
    color: 'indigo',
    tagline: 'Staff, assignments, scope of work.',
    body: `
      <p><i>Caregivers</i> manages the workforce: nurses, midwives, caregivers. Each caregiver has a profile with skills, certifications, working hours, and active patient load.</p>
      <h4>Assignments</h4>
      <p><i>Assignments</i> creates the link between a caregiver and a patient with start/end dates and role (primary, backup, specialist). Assignments power scheduling defaults, dose responsibility, and escalation routing.</p>`,
  },
  {
    id: 'hc-schedules',
    title: 'Schedules & Visits',
    icon: 'mdi-calendar-clock',
    color: 'deep-purple',
    tagline: 'Plan, track, and complete in-home visits.',
    body: `
      <p>Two views over the same data:</p>
      <ul>
        <li><b>Visit list</b> — sortable table of upcoming, in-progress, and completed visits with caregiver, patient, time, and status.</li>
        <li><b>Calendar</b> — day / week / month view with drag-to-reschedule.</li>
      </ul>
      <h4>Workflow</h4>
      <ol>
        <li>Create a visit (or it is auto-generated from the patient's care pathway / dose schedule).</li>
        <li>Caregiver checks in (GPS captured), performs tasks, records vitals/notes/doses.</li>
        <li>Checks out — visit is marked Completed; a note appears on the patient timeline.</li>
      </ol>
      <p><b>My Day</b> is the caregiver-focused view of today's visits with quick-action buttons.</p>`,
  },
  {
    id: 'hc-treatment-plans',
    title: 'Treatment Plans & Care Pathways',
    icon: 'mdi-clipboard-text',
    color: 'cyan-darken-2',
    tagline: 'Goals, interventions, review cycles.',
    body: `
      <p>A treatment plan groups goals, interventions, and review dates for a patient.</p>
      <ul>
        <li>Create from a blank plan or apply a <b>Care Pathway</b> template.</li>
        <li>Each goal has a target, measurement method, and due date. Mark progress as you review.</li>
        <li>Plans are versioned — every revision keeps an audit trail of who changed what and when.</li>
        <li>Generate a printable plan summary to share with the patient.</li>
      </ul>`,
  },
  {
    id: 'hc-medications-doses',
    title: 'Medications & Doses (MAR)',
    icon: 'mdi-pill',
    color: 'pink',
    tagline: 'Adherence, scheduling, administration record.',
    body: `
      <p><b>Medications</b> hosts a patient's active medication list with dose, route, frequency, indication, and start/stop dates.</p>
      <h4>Doses (MAR)</h4>
      <p>Each scheduled dose appears in <i>Doses</i> as a tile with status: Due, Given, Refused, Missed, Held. Caregivers tap to record administration, capture witness PIN, and add notes.</p>
      <ul>
        <li><b>Drug interactions</b> are checked at prescribe-time — alerts surface in the prescription form.</li>
        <li>Late doses raise an <b>Escalation</b> automatically per the patient's risk band.</li>
        <li>Adherence % is calculated nightly and shown on the patient overview and reports.</li>
      </ul>`,
    tips: [
      { type: 'warning', text: '<b>PIN required</b> for high-alert medications. Configure which classes need a PIN under <i>Clinical Catalog</i>.' },
    ],
  },
  {
    id: 'hc-prescriptions',
    title: 'Prescriptions',
    icon: 'mdi-prescription',
    color: 'pink-darken-2',
    tagline: 'Issue, refill, share with pharmacies.',
    body: `
      <p>Prescribers create prescriptions linked to the patient and treatment plan. Each Rx supports refills, electronic share with partner pharmacies, and printing.</p>`,
  },
  {
    id: 'hc-vitals',
    title: 'Vitals & Observations',
    icon: 'mdi-heart-pulse',
    color: 'red',
    tagline: 'Capture, trend, alert.',
    body: `
      <p>Capture BP, HR, SpO2, temperature, glucose, weight, pain score, and custom observations.</p>
      <ul>
        <li>Out-of-range values are highlighted; severe values trigger an <b>EWS</b> recalculation and may auto-create an escalation.</li>
        <li>Trend charts on the patient overview show 7-day / 30-day windows.</li>
        <li>Set per-patient observation schedules (e.g. BP twice daily) and the system generates due reminders.</li>
      </ul>`,
  },
  {
    id: 'hc-notes-consents',
    title: 'Care Notes & Consents',
    icon: 'mdi-note-edit',
    color: 'orange',
    tagline: 'Document and authorise.',
    body: `
      <p><b>Care Notes</b> capture narrative documentation per visit: SOAP-style or free-form, with attachments. Notes are immutable once signed; addenda can be added.</p>
      <p><b>Consents</b> stores patient-signed forms (treatment, telehealth, photography, data sharing). Each consent has a scope, expiry, and PDF copy.</p>`,
  },
  {
    id: 'hc-teleconsult',
    title: 'Teleconsult',
    icon: 'mdi-video',
    color: 'blue-darken-2',
    tagline: 'Video visits with patients and family.',
    body: `
      <p>Schedule a teleconsult from the patient detail or directly under <i>Teleconsult</i>. The system generates a one-tap join link for the patient/family and adds the visit to the caregiver's calendar. Notes and recordings (if consented) attach back to the patient timeline.</p>`,
  },
  {
    id: 'hc-escalations',
    title: 'Escalations & Inbox',
    icon: 'mdi-alert-octagram',
    color: 'red-darken-2',
    tagline: 'Triage urgent issues.',
    body: `
      <p><b>Escalations</b> queue surfaces urgent items: missed high-risk doses, abnormal vitals, EWS spikes, and caregiver SOS. Each escalation has severity, owner, status, and resolution notes.</p>
      <p><b>Inbox</b> consolidates internal messages from family, caregivers, and the system. Use it as a daily action queue.</p>`,
    tips: [
      { type: 'warning', text: 'Configure escalation routing rules under <i>Clinical Protocols</i> so the right person is notified instantly.' },
    ],
  },
  {
    id: 'hc-mail',
    title: 'Mail',
    icon: 'mdi-email',
    color: 'indigo-darken-2',
    tagline: 'Provider email, in-context.',
    body: `
      <p>The Mail module connects an SMTP/IMAP mailbox to your homecare workspace, so referrals, reports, and family correspondence live alongside clinical records. Configure server settings under <i>Mail Settings</i>.</p>`,
  },
  {
    id: 'hc-insurance-billing',
    title: 'Insurance & Billing',
    icon: 'mdi-shield-account',
    color: 'green-darken-2',
    tagline: 'Coverage, claims, invoices.',
    body: `
      <p><b>Insurance</b> stores each patient's schemes, member numbers, coverage caps, and pre-authorisations. Eligibility is checked when scheduling chargeable services.</p>
      <p><b>Billing</b> generates invoices from completed visits and dispensed medications. Submit to insurers, track claim status, and record payments.</p>`,
  },
  {
    id: 'hc-equipment',
    title: 'Equipment',
    icon: 'mdi-medical-bag',
    color: 'amber-darken-2',
    tagline: 'Loaned devices and consumables.',
    body: `
      <p>Track devices issued to patients (oxygen concentrators, infusion pumps, monitors): serial number, issue date, expected return, and maintenance schedule. Alerts fire when service is due.</p>`,
  },
  {
    id: 'hc-clinical-tools',
    title: 'Clinical Tools',
    icon: 'mdi-clipboard-pulse',
    color: 'teal-darken-2',
    tagline: 'Protocols, EWS, drug interactions, catalog.',
    body: `
      <ul>
        <li><b>Clinical Protocols</b> — guideline templates that drive escalation routing, dose checks, and observation schedules.</li>
        <li><b>EWS Scoring</b> — configurable Early Warning Score with per-band actions.</li>
        <li><b>Drug Interactions</b> — reference database used at prescribing time.</li>
        <li><b>Clinical Catalog</b> — master lists of medications, vitals types, observation forms, and care pathway templates.</li>
      </ul>`,
  },
  {
    id: 'hc-reports-audit',
    title: 'Reports & Audit',
    icon: 'mdi-chart-box',
    color: 'cyan',
    tagline: 'Performance and compliance.',
    body: `
      <p><b>Reports</b> covers visit completion, adherence %, vitals coverage, escalation MTTR, caregiver workload, and revenue. Filter by date, branch, caregiver, or patient cohort. Export CSV.</p>
      <p><b>Audit Log</b> records every clinical and administrative action (who, what, when, before/after). Use it for incident review and accreditation evidence.</p>`,
  },
  {
    id: 'hc-company-profile',
    title: 'Company Profile',
    icon: 'mdi-domain',
    color: 'blue-grey-darken-2',
    tagline: 'Tenant settings.',
    body: `
      <p>Set company name, license, logo, address, working hours, and service catalog. These appear on patient invoices, family-portal headers, and public pages.</p>`,
  },
  {
    id: 'hc-tips',
    title: 'Tips & Troubleshooting',
    icon: 'mdi-lifebuoy',
    color: 'blue-grey',
    tagline: 'Common issues and quick fixes.',
    body: `
      <ul>
        <li><b>Caregiver can't see a patient</b> — verify an active <i>Assignment</i> exists with today in its date range.</li>
        <li><b>Doses not appearing</b> — ensure the medication has an active schedule and a start date today or earlier.</li>
        <li><b>Family member can't log in</b> — re-send the invite from the patient's <i>Family</i> tab.</li>
        <li><b>Escalation didn't route</b> — check the relevant clinical protocol's notification rules and that the on-call user is active.</li>
      </ul>`,
  },
]

const labSections = [
  {
    id: 'lab-getting-started',
    title: 'Getting Started',
    icon: 'mdi-rocket-launch',
    body: `
      <p>Welcome to the AdhereMed Laboratory tenant. The platform is built for modern, professional medical labs serving walk-in patients, hospital wards, and external referring clinicians.</p>
      <ul>
        <li><b>Dashboard</b> — quick KPIs of orders, specimens, pending verification, STAT, QC and instruments.</li>
        <li><b>Sidebar</b> — grouped by Lab Operations, Catalog &amp; Referring, Quality &amp; Equipment, Billing &amp; Finance, and Admin &amp; Analytics.</li>
        <li><b>Roles</b> — Tenant Admin, Lab Admin, Lab Tech. Admin areas (Staff, Branches, Settings, Reports) are gated.</li>
      </ul>
      <p>Recommended first-time setup: create your test catalog &rarr; build panels &rarr; register instruments &rarr; add referring doctors and facilities &rarr; design a default report template.</p>`,
  },
  {
    id: 'lab-test-catalog',
    title: 'Test Catalog',
    icon: 'mdi-flask-outline',
    body: `
      <p>The catalog defines every individual test you offer. Each test includes a unique code, name, department, specimen type, turnaround time, reference range, units and price.</p>
      <ul>
        <li>Open <b>Test Catalog &rarr; Tests</b> from the sidebar.</li>
        <li>Click <b>New Test</b>. Enter Code (e.g. <code>CBC</code>), Name (Complete Blood Count), Department, Specimen, Reference Range, Price.</li>
        <li>Toggle <b>Active</b> off to retire a test without deleting historical data.</li>
      </ul>`,
  },
  {
    id: 'lab-panels',
    title: 'Panels',
    icon: 'mdi-package-variant',
    body: `
      <p>Panels are convenient bundles of tests offered at a single price (e.g. <i>Liver Function Tests</i>, <i>Renal Profile</i>).</p>
      <ul>
        <li>Open <b>Test Catalog &rarr; Panels</b> and click <b>New Panel</b>.</li>
        <li>Pick the member tests, set a panel price, and mark Active.</li>
        <li>When creating a requisition, selecting a panel auto-adds all of its tests.</li>
      </ul>`,
  },
  {
    id: 'lab-requisitions',
    title: 'Requisitions',
    icon: 'mdi-clipboard-text-clock',
    body: `
      <p>A requisition is the formal request for one or more lab tests on a patient.</p>
      <ul>
        <li>Open <b>Requisitions</b> &rarr; <b>New Requisition</b>.</li>
        <li>Select the patient, set priority (Routine / Urgent / STAT), pick tests and/or panels.</li>
        <li>Optionally attach a referring doctor and/or facility, payer type, and clinical notes.</li>
        <li>Save to create the order. The system creates an <code>order-extras</code> record to capture referrals and payer info.</li>
      </ul>`,
  },
  {
    id: 'lab-accessioning',
    title: 'Accessioning &amp; Specimens',
    icon: 'mdi-barcode-scan',
    body: `
      <p>Every physical sample is registered as a <b>specimen</b>. The system auto-generates an <b>accession number</b> in the format <code>A{YYMMDD}{seq}</code> on creation.</p>
      <ul>
        <li>Open <b>Accessioning</b> &rarr; <b>Register Specimen</b>.</li>
        <li>Pick the lab order, container type (EDTA, plain, urine cup, swab, etc.), volume and storage location.</li>
        <li>Status flow: <code>registered &rarr; collected &rarr; received &rarr; in_process &rarr; disposed</code>; or <code>rejected</code> at any point.</li>
        <li>Use the <b>Receive</b> button when the sample reaches the bench. Use <b>Reject</b> with a reason when a sample is unsuitable (haemolysed, clotted, insufficient).</li>
      </ul>`,
  },
  {
    id: 'lab-worklist',
    title: 'Worklists',
    icon: 'mdi-test-tube',
    body: `
      <p>The worklist is the technologist's view of work in progress, grouped by status (Pending, Collected, Processing, Completed). Each row jumps directly to the result entry screen.</p>`,
  },
  {
    id: 'lab-results',
    title: 'Results &amp; Verification',
    icon: 'mdi-file-chart',
    body: `
      <p>Open <b>Results &amp; Reports</b>, choose an order, then enter values for each test. The reference range is shown as a guide; tick <b>Abnormal</b> where appropriate. Saving creates or updates a <code>LabResult</code> for each test.</p>
      <ul>
        <li>Every change is logged in <b>Result Audits</b> with the previous and new value plus a reason.</li>
        <li>A senior tech or pathologist can <b>verify</b> results before release.</li>
      </ul>`,
  },
  {
    id: 'lab-qc',
    title: 'Quality Control',
    icon: 'mdi-chart-bell-curve-cumulative',
    body: `
      <p>Daily QC runs are recorded per instrument and test. Choose a level (Low, Normal, High), enter the lot number, expected, measured, and SD. The result is classified as Pass, Warn or Fail.</p>
      <p>QC failures should block release of patient results on that instrument until corrective action is documented.</p>`,
  },
  {
    id: 'lab-instruments',
    title: 'Instruments &amp; Maintenance',
    icon: 'mdi-cog-transfer',
    body: `
      <p>Track every analyzer with its model, manufacturer, serial number and department. Use the status field to mark <b>Active</b>, <b>Maintenance</b>, <b>Offline</b> or <b>Retired</b>. Record the last and next service dates to plan preventive maintenance.</p>`,
  },
  {
    id: 'lab-referring',
    title: 'Referring Network',
    icon: 'mdi-stethoscope',
    body: `
      <p>Maintain external clinicians and the facilities they belong to. Each doctor can have a commission percent; each facility can have a contracted discount percent that flows into invoicing.</p>`,
  },
  {
    id: 'lab-billing',
    title: 'Billing &amp; Invoicing',
    icon: 'mdi-receipt-text',
    body: `
      <p>Invoices are auto-numbered <code>INV{YYMMDD}{seq}</code>. They link to a lab order and patient, with a payer type (Self, Insurance, Facility, Corporate). Add line items per test or panel.</p>
      <ul>
        <li>Use the <b>Pay</b> action to record cash, M-Pesa, card, bank or insurance payments.</li>
        <li><code>amount_paid</code> and <code>status</code> (Draft, Issued, Partial, Paid, Void) are recomputed automatically.</li>
      </ul>`,
  },
  {
    id: 'lab-home-visits',
    title: 'Home Sample Visits',
    icon: 'mdi-home-import-outline',
    body: `
      <p>Schedule lab tech visits to a patient's address for sample collection. Track the assigned tech, scheduled date/time, status and completion timestamp. Use this for chronic-care monitoring and home-based collections.</p>`,
  },
  {
    id: 'lab-templates',
    title: 'Report Templates',
    icon: 'mdi-printer-pos',
    body: `
      <p>Design the look of printed reports. Each template has header HTML (logo, lab name, accreditation), footer HTML (disclaimers, contact), and a signatory (name, title, optional signature image). Mark one as <b>Default</b> for use on all reports.</p>`,
  },
  {
    id: 'lab-analytics',
    title: 'Reports &amp; Analytics',
    icon: 'mdi-chart-box',
    body: `
      <p>The dashboard surfaces same-day KPIs. Use the global Reports module for revenue trends, test mix by department, turnaround-time distributions, rejection rates, and referring-source contribution.</p>`,
  },
  {
    id: 'lab-roles',
    title: 'Roles &amp; Permissions',
    icon: 'mdi-shield-account',
    body: `
      <ul>
        <li><b>Tenant / Lab Admin</b> — full access including settings, billing, staff, branches.</li>
        <li><b>Lab Tech</b> — accessioning, worklist, results, QC, instruments. Cannot edit prices, branches or staff.</li>
      </ul>`,
  },
  {
    id: 'lab-troubleshooting',
    title: 'Troubleshooting',
    icon: 'mdi-lifebuoy',
    body: `
      <ul>
        <li><b>Specimen won't accept Receive</b> — only specimens in status <code>collected</code> can be received. Update the status first.</li>
        <li><b>Invoice balance not updating</b> — payments are recorded via the dedicated action; manually editing the invoice doesn't recompute totals.</li>
        <li><b>Cannot delete a test in catalog</b> — it's referenced by historical orders. Toggle <b>Active</b> off instead.</li>
        <li><b>QC tab empty</b> — register an instrument first, then log a QC run against it.</li>
      </ul>`,
  },
]
</script>

<style scoped>
/* ── Root & Background ── */
.docs-root { position: relative; min-height: 100vh; overflow-x: hidden; }
.brand-gradient {
  position: absolute; inset: 0;
  background:
    radial-gradient(900px 500px at 80% -10%, rgba(56, 189, 248, 0.12), transparent 60%),
    radial-gradient(700px 400px at 0% 20%, rgba(94, 234, 212, 0.08), transparent 55%),
    linear-gradient(160deg, #0F766E 0%, #0d9488 35%, #0EA5E9 100%);
  z-index: 0;
}
.bg-fill { z-index: 0; }
.blob { position: absolute; border-radius: 50%; filter: blur(70px); opacity: 0.22; z-index: 1; }
.blob-1 { width: 380px; height: 380px; background: #5EEAD4; top: -80px; left: -80px; animation: float-orb 20s ease-in-out infinite; }
.blob-2 { width: 480px; height: 480px; background: #38BDF8; bottom: -120px; right: -120px; animation: float-orb 24s ease-in-out infinite reverse; }
@keyframes float-orb {
  0%, 100% { transform: translate(0, 0) scale(1); }
  50% { transform: translate(40px, -30px) scale(1.08); }
}

/* ── Top Nav ── */
.top-nav {
  position: relative; z-index: 3;
  display: flex; align-items: center; gap: 8px;
}
.nav-btn { color: rgba(255,255,255,0.9) !important; }
.nav-btn-outline {
  color: #fff !important;
  border-color: rgba(255,255,255,0.5);
}
.nav-btn-print {
  color: #0F766E !important;
  font-weight: 600;
}

/* ── Tab Bar ── */
.docs-tabbar {
  position: relative; z-index: 2;
  background: linear-gradient(180deg, rgba(15, 118, 110, 0.92), rgba(13, 148, 136, 0.82));
  backdrop-filter: blur(6px);
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}
.docs-tabs :deep(.v-tab) {
  color: rgba(255, 255, 255, 0.75) !important;
  font-weight: 600;
  letter-spacing: 0.03em;
  text-transform: none;
  border-radius: 10px;
  margin: 0 4px;
  transition: all 0.25s;
}
.docs-tabs :deep(.v-tab:hover) { color: #fff !important; }
.docs-tabs :deep(.v-tab--selected) {
  color: #fff !important;
  font-weight: 700;
}
.docs-tabs :deep(.v-tab--selected)::after {
  content: '';
  display: block;
  width: 30px;
  height: 3px;
  background: #5EEAD4;
  border-radius: 3px;
  margin: 4px auto 0;
}
.docs-tabs :deep(.v-tab__overlay) { background: rgba(255, 255, 255, 0.06); border-radius: 10px; }
.docs-tabs :deep(.v-slider-track) { display: none; }

/* ── Hero ── */
.docs-hero {
  position: relative;
  border-radius: 20px;
  overflow: hidden;
  background:
    linear-gradient(135deg, rgba(15, 118, 110, 0.95), rgba(14, 165, 233, 0.90));
  backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.15);
  box-shadow: 0 12px 40px rgba(15, 118, 110, 0.22);
}
.docs-hero-glow {
  position: absolute;
  top: -60%; right: -30%;
  width: 400px; height: 400px;
  background: radial-gradient(circle, rgba(94, 234, 212, 0.15), transparent 70%);
  pointer-events: none;
}
.docs-hero-content { position: relative; z-index: 1; }
.hero-chip {
  color: #0F766E !important;
  font-weight: 700;
}
.hero-chip-outline {
  color: #fff !important;
  border-color: rgba(255, 255, 255, 0.45) !important;
}
.docs-hero-title {
  font-size: clamp(1.5rem, 4vw, 2.3rem);
  font-weight: 800;
  color: #fff;
  margin: 0 0 8px;
  line-height: 1.2;
}
.docs-hero-sub {
  font-size: clamp(0.95rem, 1.8vw, 1.15rem);
  color: rgba(255, 255, 255, 0.88);
  margin: 0;
  max-width: 900px;
  line-height: 1.5;
}

/* ── TOC Sidebar ── */
.docs-toc-wrap { position: sticky; top: 16px; }
.docs-toc {
  background: rgba(255, 255, 255, 0.97);
  border-radius: 16px;
  border: 1px solid rgba(15, 118, 110, 0.12);
  padding: 14px;
  box-shadow: 0 4px 20px rgba(15, 23, 42, 0.05);
}
.sticky-toc { position: sticky; top: 16px; }
.toc-overline {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: #0F766E;
}
.toc-item {
  border-radius: 10px !important;
  margin: 2px 0;
  transition: all 0.2s;
}
.docs-toc :deep(.v-list-item-title) { color: #1e293b !important; font-weight: 500; font-size: 13.5px; }
.docs-toc :deep(.v-list-item) { color: #1e293b !important; }
.docs-toc :deep(.v-list-item .v-icon) { color: #0d9488 !important; font-size: 18px; }
.docs-toc :deep(.v-list-item:hover) {
  background: rgba(13, 148, 136, 0.08);
  transform: translateX(2px);
}

/* ── Section Cards ── */
.docs-section-wrap { scroll-margin-top: 80px; }
.docs-section {
  background: rgba(255, 255, 255, 0.98);
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 16px;
  padding: 24px 28px;
  box-shadow: 0 2px 12px rgba(15, 23, 42, 0.04);
  transition: box-shadow 0.3s, transform 0.3s, border-color 0.3s;
}
.docs-section:hover {
  box-shadow: 0 8px 30px rgba(15, 23, 42, 0.08);
  border-color: rgba(13, 148, 136, 0.2);
  transform: translateY(-2px);
}
.section-icon-wrap {
  width: 48px; height: 48px;
  border-radius: 14px;
  display: flex; align-items: center; justify-content: center;
  background: color-mix(in srgb, var(--section-color, #0d9488) 12%, transparent);
  border: 1px solid color-mix(in srgb, var(--section-color, #0d9488) 25%, transparent);
  flex-shrink: 0;
}
.section-title { color: #0F172A; font-size: 1.3rem !important; line-height: 1.3; }
.section-tagline { color: rgba(15, 23, 42, 0.5) !important; font-style: italic; margin-top: 2px; }

/* ── Body Typography ── */
.docs-body {
  font-size: 14.5px;
  line-height: 1.7;
  color: rgba(15, 23, 42, 0.78);
}
.docs-body :deep(h4) {
  margin: 16px 0 6px;
  font-size: 15px;
  font-weight: 700;
  color: #0d9488;
  padding-left: 10px;
  border-left: 3px solid #5EEAD4;
}
.docs-body :deep(p) { margin: 8px 0; }
.docs-body :deep(ul),
.docs-body :deep(ol) {
  margin: 8px 0 8px 4px;
  padding-left: 20px;
}
.docs-body :deep(li) {
  margin: 5px 0;
  padding-left: 4px;
}
.docs-body :deep(li::marker) { color: #0d9488; }
.docs-body :deep(code),
.docs-body :deep(kbd) {
  background: rgba(13, 148, 136, 0.08);
  border: 1px solid rgba(13, 148, 136, 0.18);
  border-radius: 5px;
  padding: 2px 7px;
  font-size: 12.5px;
  font-family: ui-monospace, "SF Mono", Menlo, monospace;
  color: #0d9488;
}
.docs-body :deep(kbd) {
  background: rgba(15, 23, 42, 0.08);
  border-color: rgba(15, 23, 42, 0.15);
  color: #1e293b;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
}
.docs-body :deep(a) { color: #0d9488; text-decoration: none; font-weight: 500; }
.docs-body :deep(a:hover) { text-decoration: underline; }
.docs-body :deep(strong) { color: #0F172A; }

/* ── Tip boxes ── */
.docs-tips { display: flex; flex-direction: column; gap: 10px; }
.docs-tip {
  display: flex; align-items: flex-start; gap: 10px;
  padding: 12px 16px;
  border-radius: 12px;
  font-size: 13.5px;
  line-height: 1.55;
}
.docs-tip--info {
  background: rgba(14, 165, 233, 0.07);
  border: 1px solid rgba(14, 165, 233, 0.18);
}
.docs-tip--info .docs-tip-icon { color: #0ea5e9; }
.docs-tip--warning {
  background: rgba(245, 158, 11, 0.08);
  border: 1px solid rgba(245, 158, 11, 0.22);
}
.docs-tip--warning .docs-tip-icon { color: #d97706; }
.docs-tip--success {
  background: rgba(34, 197, 94, 0.07);
  border: 1px solid rgba(34, 197, 94, 0.18);
}
.docs-tip--success .docs-tip-icon { color: #16a34a; }
.docs-tip--error {
  background: rgba(239, 68, 68, 0.07);
  border: 1px solid rgba(239, 68, 68, 0.18);
}
.docs-tip--error .docs-tip-icon { color: #dc2626; }
.docs-tip-text { color: rgba(15, 23, 42, 0.75); }
.docs-tip-text :deep(b) { color: #0F172A; }

/* ── Support card ── */
.docs-support-card {
  display: flex; align-items: center;
  padding: 20px 28px;
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.97);
  border: 1px solid rgba(15, 23, 42, 0.08);
  box-shadow: 0 2px 12px rgba(15, 23, 42, 0.04);
}
.docs-link { color: #0d9488; font-weight: 600; text-decoration: none; }
.docs-link:hover { text-decoration: underline; }

/* ── Transitions ── */
.fade-up-enter-active { transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1); }
.fade-up-enter-from { opacity: 0; transform: translateY(12px); }
.section-list-enter-active { transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1); }
.section-list-enter-from { opacity: 0; transform: translateY(16px); }

/* ── Dark mode ── */
:global(.v-theme--dark .brand-gradient) {
  background:
    radial-gradient(900px 500px at 80% -10%, rgba(56, 189, 248, 0.10), transparent 60%),
    radial-gradient(700px 400px at 0% 20%, rgba(94, 234, 212, 0.06), transparent 55%),
    linear-gradient(160deg, #0f1f1d 0%, #0c2a28 35%, #0a1929 100%);
}
:global(.v-theme--dark .docs-hero) {
  background: linear-gradient(135deg, rgba(15, 118, 110, 0.45), rgba(14, 165, 233, 0.35));
  border-color: rgba(255, 255, 255, 0.1);
}
:global(.v-theme--dark .docs-tabbar) {
  background: linear-gradient(180deg, rgba(15, 118, 110, 0.5), rgba(13, 148, 136, 0.35));
}
:global(.v-theme--dark .docs-toc) {
  background: rgba(30, 41, 59, 0.9);
  border-color: rgba(255, 255, 255, 0.08);
}
:global(.v-theme--dark .docs-toc .v-list-item-title),
:global(.v-theme--dark .docs-toc .v-list-item) { color: #e2e8f0 !important; }
:global(.v-theme--dark .toc-overline) { color: #5EEAD4; }
:global(.v-theme--dark .docs-section) {
  background: rgba(30, 41, 59, 0.88);
  border-color: rgba(255, 255, 255, 0.08);
}
:global(.v-theme--dark .docs-section:hover) {
  box-shadow: 0 8px 30px rgba(0, 0, 0, 0.3);
}
:global(.v-theme--dark .section-title) { color: #f1f5f9 !important; }
:global(.v-theme--dark .section-tagline) { color: rgba(255, 255, 255, 0.5) !important; }
:global(.v-theme--dark .docs-body) { color: rgba(255, 255, 255, 0.75); }
:global(.v-theme--dark .docs-body h4) { color: #5EEAD4; }
:global(.v-theme--dark .docs-body strong) { color: #f1f5f9; }
:global(.v-theme--dark .docs-body code),
:global(.v-theme--dark .docs-body kbd) {
  background: rgba(94, 234, 212, 0.1);
  border-color: rgba(94, 234, 212, 0.2);
  color: #5EEAD4;
}
:global(.v-theme--dark .docs-body kbd) {
  background: rgba(255, 255, 255, 0.08);
  color: #e2e8f0;
}
:global(.v-theme--dark .docs-support-card) {
  background: rgba(30, 41, 59, 0.88);
  border-color: rgba(255, 255, 255, 0.08);
}
:global(.v-theme--dark .docs-tip--info) { background: rgba(14, 165, 233, 0.08); border-color: rgba(14, 165, 233, 0.2); }
:global(.v-theme--dark .docs-tip--warning) { background: rgba(245, 158, 11, 0.08); }
:global(.v-theme--dark .docs-tip--success) { background: rgba(34, 197, 94, 0.08); }
:global(.v-theme--dark .docs-tip-text) { color: rgba(255, 255, 255, 0.7); }
:global(.v-theme--dark .docs-tip-text b) { color: #f1f5f9; }

/* ── CSV tables ── */
.docs-csv-table { margin: 14px 0; overflow-x: auto; overflow: hidden; border-radius: 12px; border: 1px solid rgba(15, 23, 42, 0.1); }
.docs-csv-table table { width: 100%; border-collapse: collapse; background: rgba(13, 148, 136, 0.02); }
.docs-csv-table thead th {
  background: rgba(13, 148, 136, 0.08);
  color: #0d9488;
  font-weight: 700;
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  padding: 10px 14px;
  text-align: left;
  border-bottom: 1px solid rgba(13, 148, 136, 0.15);
}
.docs-csv-table tbody td {
  padding: 9px 14px;
  font-size: 13.5px;
  border-bottom: 1px solid rgba(15, 23, 42, 0.04);
  color: rgba(15, 23, 42, 0.8);
}
.docs-csv-table tbody tr:hover { background: rgba(13, 148, 136, 0.04); }
.docs-csv-table tbody tr:last-child td { border-bottom: none; }
.docs-csv-caption {
  padding: 8px 14px;
  font-size: 11.5px;
  font-style: italic;
  color: rgba(15, 23, 42, 0.5);
  text-align: center;
}
:global(.v-theme--dark .docs-csv-table) { border-color: rgba(255, 255, 255, 0.08); }
:global(.v-theme--dark .docs-csv-table table) { background: rgba(255, 255, 255, 0.02); }
:global(.v-theme--dark .docs-csv-table thead th) { background: rgba(94, 234, 212, 0.1); color: #5EEAD4; border-color: rgba(94, 234, 212, 0.15); }
:global(.v-theme--dark .docs-csv-table tbody td) { color: rgba(255, 255, 255, 0.75); border-color: rgba(255, 255, 255, 0.04); }
:global(.v-theme--dark .docs-csv-table tbody tr:hover) { background: rgba(94, 234, 212, 0.05); }
:global(.v-theme--dark .docs-csv-caption) { color: rgba(255, 255, 255, 0.4); }

/* ── Flow diagrams ── */
.docs-flow-diagram {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 6px;
  margin: 14px 0;
  padding: 14px 16px;
  border-radius: 12px;
  background: rgba(13, 148, 136, 0.04);
  border: 1px solid rgba(13, 148, 136, 0.12);
}
.docs-flow-step {
  display: inline-flex;
  align-items: center;
  padding: 6px 14px;
  border-radius: 10px;
  font-size: 13px;
  font-weight: 600;
  background: rgba(15, 23, 42, 0.06);
  color: rgba(15, 23, 42, 0.7);
  white-space: nowrap;
}
.docs-flow-step--active {
  background: rgba(14, 165, 233, 0.12);
  color: #0ea5e9;
  border: 1px solid rgba(14, 165, 233, 0.25);
}
.docs-flow-step--done {
  background: rgba(34, 197, 94, 0.12);
  color: #16a34a;
  border: 1px solid rgba(34, 197, 94, 0.25);
}
.docs-flow-arrow {
  font-size: 16px;
  color: rgba(15, 23, 42, 0.3);
  font-weight: 700;
}
:global(.v-theme--dark .docs-flow-diagram) { background: rgba(255, 255, 255, 0.03); border-color: rgba(255, 255, 255, 0.08); }
:global(.v-theme--dark .docs-flow-step) { background: rgba(255, 255, 255, 0.06); color: rgba(255, 255, 255, 0.65); }
:global(.v-theme--dark .docs-flow-step--active) { background: rgba(14, 165, 233, 0.15); color: #38bdf8; }
:global(.v-theme--dark .docs-flow-step--done) { background: rgba(34, 197, 94, 0.15); color: #4ade80; }
:global(.v-theme--dark .docs-flow-arrow) { color: rgba(255, 255, 255, 0.25); }

/* ── Chart placeholders ── */
.docs-chart-placeholder {
  margin: 16px 0;
  border-radius: 14px;
  padding: 20px;
  background: rgba(15, 23, 42, 0.02);
  border: 1px solid rgba(15, 23, 42, 0.06);
}
.docs-chart-row {
  display: flex;
  gap: 16px;
  flex-wrap: wrap;
  justify-content: center;
}
.docs-mini-chart {
  flex: 1;
  min-width: 180px;
  max-width: 240px;
  padding: 16px;
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.6);
  border: 1px solid rgba(15, 23, 42, 0.06);
  text-align: center;
}
.docs-mini-chart-icon { color: #0d9488; margin-bottom: 4px; }
.docs-mini-chart-label { font-size: 12px; font-weight: 600; color: rgba(15, 23, 42, 0.6); margin-bottom: 12px; text-transform: uppercase; letter-spacing: 0.04em; }
.docs-mini-bars { display: flex; align-items: flex-end; gap: 4px; height: 60px; justify-content: center; }
.docs-mini-bars span {
  width: 8px;
  min-height: 4px;
  border-radius: 3px 3px 0 0;
  background: #0d9488;
  transition: height 0.3s;
}
.docs-mini-bars-group { display: flex; align-items: flex-end; gap: 10px; height: 60px; justify-content: center; }
.docs-mini-bars-group span { display: flex; align-items: flex-end; gap: 2px; }
.docs-mini-bars-group span i {
  width: 8px;
  border-radius: 3px 3px 0 0;
  display: block;
}
.docs-mini-bars-group span i:first-child { background: #22c55e; }
.docs-mini-bars-group span i:last-child { background: #f59e0b; }
.docs-mini-donut { display: flex; justify-content: center; align-items: center; height: 60px; }
.docs-donut-ring {
  width: 56px; height: 56px; border-radius: 50%;
  background: conic-gradient(
    #16a34a 0% var(--p1),
    #f59e0b var(--p1) calc(var(--p1) + var(--p2)),
    #dc2626 calc(var(--p1) + var(--p2)) calc(var(--p1) + var(--p2) + var(--p3)),
    #64748b calc(var(--p1) + var(--p2) + var(--p3)) 100%
  );
  position: relative;
}
.docs-donut-ring::after {
  content: '';
  position: absolute;
  inset: 12px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.9);
}
.docs-donut--health {
  background: conic-gradient(
    #16a34a 0% 72%,
    #f59e0b 72% 90%,
    #dc2626 90% 100%
  );
}
.docs-chart-legend {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  justify-content: center;
  margin-top: 8px;
  font-size: 11px;
  color: rgba(15, 23, 42, 0.5);
}
.docs-chart-legend span { display: flex; align-items: center; gap: 4px; }
.docs-chart-legend .dot { width: 8px; height: 8px; border-radius: 50%; display: inline-block; }
:global(.v-theme--dark .docs-chart-placeholder) { background: rgba(255, 255, 255, 0.02); border-color: rgba(255, 255, 255, 0.06); }
:global(.v-theme--dark .docs-mini-chart) { background: rgba(255, 255, 255, 0.04); border-color: rgba(255, 255, 255, 0.06); }
:global(.v-theme--dark .docs-mini-chart-label) { color: rgba(255, 255, 255, 0.5); }
:global(.v-theme--dark .docs-mini-bars span) { background: #5EEAD4; }
:global(.v-theme--dark .docs-donut-ring::after) { background: rgba(30, 41, 59, 0.9); }
:global(.v-theme--dark .docs-chart-legend) { color: rgba(255, 255, 255, 0.4); }

/* ── Reason chips ── */
.docs-reason-chip {
  display: inline-block;
  padding: 2px 10px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 600;
  white-space: nowrap;
}

@media print {
  .top-nav, .sticky-toc, .blob, .brand-gradient, .docs-tabbar { display: none !important; }
  .docs-section, .docs-hero, .docs-toc { box-shadow: none !important; border: none !important; }
  .docs-root { background: white; }
}
</style>
