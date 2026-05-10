<template>
  <div class="hc-bg pa-4 pa-md-6">
    <HomecareHero
      title="Clinical Protocols"
      subtitle="Evidence-based pathways your care team can follow at the bedside."
      eyebrow="CLINICAL GOVERNANCE"
      icon="mdi-clipboard-pulse"
      :chips="[
        { icon: 'mdi-shield-check', label: 'Peer reviewed' },
        { icon: 'mdi-update',       label: 'Versioned' }
      ]"
    >
      <template #actions>
        <v-btn variant="flat" rounded="pill" color="white" prepend-icon="mdi-plus"
               class="text-none" @click="openNew">
          <span class="text-teal-darken-2 font-weight-bold">New protocol</span>
        </v-btn>
      </template>
    </HomecareHero>

    <!-- ───────────── Quick stats ───────────── -->
    <v-row class="mb-1" dense>
      <v-col v-for="s in summary" :key="s.label" cols="6" md="3">
        <v-card class="hc-stat pa-4 h-100" rounded="xl" :elevation="0">
          <div class="d-flex align-center ga-3">
            <v-avatar size="44" :color="s.color" variant="tonal">
              <v-icon :icon="s.icon" />
            </v-avatar>
            <div>
              <div class="text-h6 font-weight-bold">{{ s.value }}</div>
              <div class="text-caption text-medium-emphasis">{{ s.label }}</div>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <!-- ───────────── Filters ───────────── -->
    <HomecarePanel title="Library" subtitle="Browse common clinical protocols and SOPs"
                   icon="mdi-bookshelf" color="#0d9488">
      <v-row dense class="mb-2">
        <v-col cols="12" md="4">
          <v-text-field v-model="search" prepend-inner-icon="mdi-magnify"
                        placeholder="Search protocols, conditions, codes…"
                        density="compact" variant="outlined" hide-details rounded="lg" />
        </v-col>
        <v-col cols="12" md="3">
          <v-select v-model="filterCategory" :items="categoryList" label="Category"
                    density="compact" variant="outlined" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="12" md="3">
          <v-select v-model="filterAcuity" :items="acuityList" label="Acuity"
                    density="compact" variant="outlined" hide-details clearable rounded="lg" />
        </v-col>
        <v-col cols="12" md="2">
          <v-btn-toggle v-model="view" mandatory density="comfortable" rounded="lg"
                        color="teal" class="w-100">
            <v-btn value="grid" icon><v-icon icon="mdi-view-grid" /></v-btn>
            <v-btn value="list" icon><v-icon icon="mdi-view-list" /></v-btn>
          </v-btn-toggle>
        </v-col>
      </v-row>

      <!-- Grid view -->
      <v-row v-if="view === 'grid'" dense>
        <v-col v-for="p in filtered" :key="p.id" cols="12" md="6" lg="4">
          <v-card class="hc-protocol h-100" rounded="xl" :elevation="0"
                  @click="openProtocol(p)">
            <div class="hc-protocol-band" :style="{ background: p.color }" />
            <div class="pa-4">
              <div class="d-flex align-center ga-2 mb-2">
                <v-avatar size="40" :color="p.color" variant="flat" class="hc-protocol-icon">
                  <v-icon :icon="p.icon" color="white" />
                </v-avatar>
                <div class="flex-grow-1 min-w-0">
                  <div class="text-subtitle-1 font-weight-bold text-truncate">{{ p.title }}</div>
                  <div class="text-caption text-medium-emphasis">{{ p.code }} · v{{ p.version }}</div>
                </div>
                <v-chip size="x-small" :color="acuityColor(p.acuity)" variant="tonal">
                  {{ p.acuity }}
                </v-chip>
              </div>
              <p class="text-body-2 text-medium-emphasis mb-3" style="min-height:42px;">
                {{ p.summary }}
              </p>
              <div class="d-flex flex-wrap ga-1 mb-3">
                <v-chip v-for="t in p.tags" :key="t" size="x-small" variant="tonal" color="grey">
                  {{ t }}
                </v-chip>
              </div>
              <div class="d-flex align-center text-caption text-medium-emphasis">
                <v-icon icon="mdi-account-tie" size="14" class="mr-1" />
                {{ p.owner }}
                <v-spacer />
                <v-icon icon="mdi-update" size="14" class="mr-1" />
                {{ p.updated }}
              </div>
            </div>
          </v-card>
        </v-col>
      </v-row>

      <!-- List view -->
      <v-list v-else lines="two" class="bg-transparent">
        <v-list-item v-for="p in filtered" :key="p.id" rounded="lg"
                     class="hc-protocol-row mb-2" @click="openProtocol(p)">
          <template #prepend>
            <v-avatar size="40" :color="p.color" variant="flat">
              <v-icon :icon="p.icon" color="white" />
            </v-avatar>
          </template>
          <v-list-item-title class="font-weight-bold">{{ p.title }}</v-list-item-title>
          <v-list-item-subtitle class="text-truncate">
            {{ p.code }} · {{ p.summary }}
          </v-list-item-subtitle>
          <template #append>
            <v-chip size="x-small" :color="acuityColor(p.acuity)" variant="tonal" class="mr-2">
              {{ p.acuity }}
            </v-chip>
            <v-chip size="x-small" variant="tonal" color="grey">v{{ p.version }}</v-chip>
          </template>
        </v-list-item>
      </v-list>

      <EmptyState v-if="!filtered.length" icon="mdi-clipboard-text-off"
                  title="No protocols match"
                  message="Try changing the filters or search terms." />
    </HomecarePanel>

    <!-- ───────────── Protocol drawer ───────────── -->
    <v-dialog v-model="dialog" max-width="900" scrollable>
      <v-card v-if="active" rounded="xl" class="overflow-hidden">
        <div class="hc-detail-hero pa-5" :style="{ background: detailGradient(active.color) }">
          <div class="d-flex align-center ga-3">
            <v-avatar size="56" color="white" variant="flat">
              <v-icon :icon="active.icon" :color="active.color" size="28" />
            </v-avatar>
            <div class="flex-grow-1 text-white min-w-0">
              <div class="text-overline" style="opacity:.85;">
                {{ active.category }} · v{{ active.version }}
              </div>
              <h2 class="text-h5 font-weight-bold ma-0">{{ active.title }}</h2>
              <div class="text-body-2" style="opacity:.85;">{{ active.code }} · {{ active.owner }}</div>
            </div>
            <v-btn icon variant="text" color="white" @click="dialog = false">
              <v-icon icon="mdi-close" />
            </v-btn>
          </div>
          <div class="d-flex flex-wrap ga-2 mt-3">
            <v-chip size="small" color="white" variant="flat" class="text-grey-darken-3">
              <v-icon icon="mdi-pulse" size="14" class="mr-1" /> {{ active.acuity }} acuity
            </v-chip>
            <v-chip v-for="t in active.tags" :key="t" size="small" color="white" variant="outlined">
              {{ t }}
            </v-chip>
          </div>
        </div>

        <v-card-text class="pa-5">
          <h4 class="text-subtitle-1 font-weight-bold mb-2">
            <v-icon icon="mdi-target" color="teal" class="mr-1" /> Indication
          </h4>
          <p class="text-body-2 mb-4">{{ active.indication }}</p>

          <h4 class="text-subtitle-1 font-weight-bold mb-2">
            <v-icon icon="mdi-format-list-numbered" color="indigo" class="mr-1" />
            Steps
          </h4>
          <v-timeline density="comfortable" side="end" line-thickness="2"
                      line-color="grey-lighten-2" class="mb-4">
            <v-timeline-item v-for="(s, i) in active.steps" :key="i" size="small"
                             :dot-color="active.color">
              <template #icon>
                <span class="text-caption font-weight-bold text-white">{{ i + 1 }}</span>
              </template>
              <div class="text-body-2 font-weight-bold">{{ s.title }}</div>
              <div class="text-caption text-medium-emphasis">{{ s.detail }}</div>
            </v-timeline-item>
          </v-timeline>

          <v-row dense>
            <v-col cols="12" md="6">
              <h4 class="text-subtitle-1 font-weight-bold mb-2">
                <v-icon icon="mdi-pill" color="purple" class="mr-1" /> Medications
              </h4>
              <v-list density="compact" class="pa-0 bg-transparent">
                <v-list-item v-for="m in active.medications" :key="m.name"
                             :title="m.name" :subtitle="m.dose" />
                <EmptyState v-if="!active.medications?.length" icon="mdi-pill-off"
                            title="No medications listed" />
              </v-list>
            </v-col>
            <v-col cols="12" md="6">
              <h4 class="text-subtitle-1 font-weight-bold mb-2">
                <v-icon icon="mdi-alert-octagram" color="error" class="mr-1" />
                Red flags / escalate if
              </h4>
              <v-list density="compact" class="pa-0 bg-transparent">
                <v-list-item v-for="r in active.redFlags" :key="r">
                  <template #prepend>
                    <v-icon icon="mdi-alert" color="error" size="18" />
                  </template>
                  <v-list-item-title class="text-body-2">{{ r }}</v-list-item-title>
                </v-list-item>
              </v-list>
            </v-col>
          </v-row>

          <v-divider class="my-4" />
          <div class="text-caption text-medium-emphasis">
            <v-icon icon="mdi-book-open-variant" size="14" class="mr-1" />
            Reference: {{ active.reference }}
          </div>
        </v-card-text>

        <v-card-actions class="pa-4">
          <v-btn variant="text" rounded="lg" prepend-icon="mdi-printer" class="text-none"
                 @click="printProtocol">Print</v-btn>
          <v-spacer />
          <v-btn variant="tonal" rounded="lg" color="teal" prepend-icon="mdi-clipboard-check"
                 class="text-none" @click="applyToPatient">Apply to patient</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" location="top right" timeout="2500">
      {{ snack.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
const router = useRouter()
const search = ref('')
const filterCategory = ref(null)
const filterAcuity = ref(null)
const view = ref('grid')
const dialog = ref(false)
const active = ref(null)
const snack = reactive({ show: false, text: '', color: 'info' })

// ─── Static, professionally-curated protocol library ───
const protocols = [
  {
    id: 1, code: 'PR-001', version: '1.4', category: 'Sepsis',
    title: 'Sepsis Six (Adult)', acuity: 'Critical',
    color: '#dc2626', icon: 'mdi-bacteria',
    owner: 'ICU Lead · Dr. Mwangi',
    updated: 'Updated 2 days ago',
    tags: ['Adult', 'Sepsis', 'Bundle'],
    summary: 'Deliver three and take three within one hour of suspected sepsis.',
    indication: 'Suspected sepsis with NEWS2 ≥ 5, qSOFA ≥ 2, or clinical concern.',
    steps: [
      { title: 'Give high-flow oxygen', detail: 'Target SpO₂ 94–98% (88–92% if COPD).' },
      { title: 'Take blood cultures', detail: 'Before antibiotics if no delay >45 min.' },
      { title: 'IV broad-spectrum antibiotics', detail: 'Per local antimicrobial stewardship.' },
      { title: 'IV fluid resuscitation', detail: '30 mL/kg crystalloid bolus over 3 hours.' },
      { title: 'Measure serum lactate', detail: 'Repeat if initial >2 mmol/L.' },
      { title: 'Monitor urine output', detail: 'Hourly via catheter; target ≥0.5 mL/kg/h.' }
    ],
    medications: [
      { name: 'Ceftriaxone', dose: '2 g IV stat' },
      { name: 'Hartmann’s solution', dose: '30 mL/kg IV bolus' }
    ],
    redFlags: ['Lactate > 4 mmol/L', 'Persistent hypotension after fluids', 'AMS / GCS drop',
               'Mottling, anuria'],
    reference: 'NICE NG51 / Surviving Sepsis Campaign 2021'
  },
  {
    id: 2, code: 'PR-002', version: '2.1', category: 'Cardiology',
    title: 'Acute Chest Pain Pathway', acuity: 'High',
    color: '#ea580c', icon: 'mdi-heart-pulse',
    owner: 'Cardiology · Dr. Otieno',
    updated: 'Updated last week',
    tags: ['ACS', 'ECG', 'Triage'],
    summary: 'Rapid triage and risk stratification for adult chest pain.',
    indication: 'Adult patient with non-traumatic chest pain or anginal equivalent.',
    steps: [
      { title: '12-lead ECG within 10 min', detail: 'Compare to prior if available.' },
      { title: 'Aspirin 300 mg PO chewed', detail: 'Unless contraindicated.' },
      { title: 'IV access + bloods', detail: 'Troponin, FBC, U&E, glucose.' },
      { title: 'Continuous cardiac monitoring', detail: 'Defib pads on standby.' },
      { title: 'GTN spray sublingual', detail: 'If SBP > 90 and no PDE5i in 24 h.' },
      { title: 'Risk score (HEART)', detail: 'Refer cath lab if STEMI / high risk.' }
    ],
    medications: [
      { name: 'Aspirin', dose: '300 mg PO' },
      { name: 'GTN', dose: '400 mcg SL PRN' },
      { name: 'Morphine', dose: '2.5–5 mg IV titrated' }
    ],
    redFlags: ['ST-elevation on ECG', 'Hypotension', 'New murmur', 'Syncope'],
    reference: 'ESC 2023 NSTE-ACS / Kenya MoH Cardiology Guideline'
  },
  {
    id: 3, code: 'PR-003', version: '1.0', category: 'Respiratory',
    title: 'Asthma Exacerbation (Adult)', acuity: 'High',
    color: '#0891b2', icon: 'mdi-lungs',
    owner: 'Respiratory · Dr. Kamau',
    updated: 'Updated 1 month ago',
    tags: ['Asthma', 'Nebuliser', 'Adult'],
    summary: 'Stepwise management of acute asthma in the adult patient.',
    indication: 'Acute breathlessness, wheeze, PEF < 75% personal best.',
    steps: [
      { title: 'Assess severity', detail: 'PEF, SpO₂, RR, ability to speak in sentences.' },
      { title: 'Oxygen 94–98%', detail: 'Use Venturi or NRBM as needed.' },
      { title: 'Salbutamol 5 mg neb', detail: 'Repeat every 15 min; back-to-back if severe.' },
      { title: 'Ipratropium 0.5 mg neb', detail: 'Add if severe or life-threatening.' },
      { title: 'Steroids', detail: 'Prednisolone 40 mg PO or hydrocortisone 100 mg IV.' },
      { title: 'Magnesium sulphate', detail: '1.2–2 g IV over 20 min for life-threatening.' }
    ],
    medications: [
      { name: 'Salbutamol nebulised', dose: '5 mg in O₂' },
      { name: 'Ipratropium nebulised', dose: '0.5 mg' },
      { name: 'Prednisolone', dose: '40 mg PO OD × 5 days' }
    ],
    redFlags: ['Silent chest', 'SpO₂ < 92%', 'Exhaustion', 'PEF < 33%'],
    reference: 'BTS/SIGN 2019 Asthma Guideline'
  },
  {
    id: 4, code: 'PR-004', version: '1.2', category: 'Endocrine',
    title: 'Diabetic Ketoacidosis (DKA)', acuity: 'Critical',
    color: '#7c3aed', icon: 'mdi-water-percent',
    owner: 'Endocrine · Dr. Wanjiku',
    updated: 'Updated 3 weeks ago',
    tags: ['Diabetes', 'DKA', 'Insulin'],
    summary: 'Fluid + insulin + potassium replacement protocol for DKA.',
    indication: 'Glucose >11, ketones ≥3 (or urine ≥2+), pH <7.3 / HCO₃ <15.',
    steps: [
      { title: '0.9% NaCl bolus', detail: '1 L over 1 h, then titrated.' },
      { title: 'Fixed-rate insulin', detail: '0.1 U/kg/h IV (Actrapid).' },
      { title: 'Monitor K+ hourly', detail: 'Replace once <5.5 mmol/L.' },
      { title: 'Add 10% dextrose', detail: 'When glucose <14 mmol/L.' },
      { title: 'Hourly capillary glucose & ketones', detail: 'Aim ketone fall ≥0.5/h.' },
      { title: 'VTE prophylaxis', detail: 'Once euvolaemic.' }
    ],
    medications: [
      { name: 'Sodium chloride 0.9%', dose: '1 L over 1 h' },
      { name: 'Insulin (Actrapid)', dose: '0.1 U/kg/h IV' },
      { name: 'KCl', dose: '40 mmol/L if K 3.5–5.5' }
    ],
    redFlags: ['GCS drop', 'Cerebral oedema signs (esp. paeds)', 'Anuria',
               'Persistent acidosis after 6 h'],
    reference: 'JBDS-IP DKA Guideline 2023'
  },
  {
    id: 5, code: 'PR-005', version: '1.0', category: 'Neurology',
    title: 'Acute Stroke (FAST)', acuity: 'Critical',
    color: '#1d4ed8', icon: 'mdi-brain',
    owner: 'Neurology · Dr. Njoroge',
    updated: 'Updated last week',
    tags: ['Stroke', 'Thrombolysis', 'FAST'],
    summary: 'Time-critical assessment for suspected stroke and TIA.',
    indication: 'Sudden-onset focal neurological deficit; FAST positive.',
    steps: [
      { title: 'Note exact onset time', detail: 'Or last-known-well.' },
      { title: 'NIHSS assessment', detail: 'Document baseline score.' },
      { title: 'Capillary glucose', detail: 'Exclude hypoglycaemia mimic.' },
      { title: 'Urgent CT head (non-contrast)', detail: 'Within 1 h of arrival.' },
      { title: 'Consider thrombolysis', detail: 'If <4.5 h and no contraindications.' },
      { title: 'Stroke team referral', detail: 'For thrombectomy / unit admission.' }
    ],
    medications: [
      { name: 'Alteplase', dose: '0.9 mg/kg IV (10% bolus)' },
      { name: 'Aspirin', dose: '300 mg PO/PR (after CT excludes haemorrhage)' }
    ],
    redFlags: ['GCS drop', 'New seizure', 'Vomiting + headache (haemorrhage)'],
    reference: 'NICE NG128 Stroke / WSO Guidelines'
  },
  {
    id: 6, code: 'PR-006', version: '1.1', category: 'Maternity',
    title: 'Postpartum Haemorrhage', acuity: 'Critical',
    color: '#db2777', icon: 'mdi-baby-carriage',
    owner: 'Obstetrics · Dr. Achieng',
    updated: 'Updated 2 weeks ago',
    tags: ['PPH', 'Maternity', 'Bleeding'],
    summary: '4 T’s approach to postpartum haemorrhage.',
    indication: 'Blood loss >500 mL vaginal / >1000 mL c-section, or symptomatic.',
    steps: [
      { title: 'Call for help', detail: 'Senior midwife, obstetrician, anaesthetist.' },
      { title: 'ABC + 2 large-bore IV', detail: 'Bloods incl. crossmatch 4 units.' },
      { title: 'Uterine massage + empty bladder', detail: 'Identify cause (4T).' },
      { title: 'Uterotonics', detail: 'Oxytocin → ergometrine → carboprost → misoprostol.' },
      { title: 'Tranexamic acid 1 g IV', detail: 'Within 3 h of bleed onset.' },
      { title: 'Escalate to theatre', detail: 'Bakri balloon, B-Lynch, hysterectomy.' }
    ],
    medications: [
      { name: 'Oxytocin', dose: '5 IU IV slow + 40 IU in 500 mL infusion' },
      { name: 'Ergometrine', dose: '500 mcg IM (avoid in HTN)' },
      { name: 'Tranexamic acid', dose: '1 g IV' }
    ],
    redFlags: ['Ongoing bleeding > 1500 mL', 'Hypotension', 'Tachycardia >120',
               'Signs of DIC'],
    reference: 'WHO PPH Guideline 2022 / RCOG GTG 52'
  },
  {
    id: 7, code: 'PR-007', version: '1.0', category: 'Wound Care',
    title: 'Pressure Ulcer Prevention', acuity: 'Routine',
    color: '#0d9488', icon: 'mdi-bandage',
    owner: 'Tissue Viability · S/N Mwende',
    updated: 'Updated last month',
    tags: ['Homecare', 'SSKIN', 'Skin'],
    summary: 'SSKIN bundle for bedbound and limited-mobility patients.',
    indication: 'Braden ≤18 or any patient on bedrest >48 h.',
    steps: [
      { title: 'Skin assessment', detail: 'Daily inspection of bony prominences.' },
      { title: 'Surface', detail: 'Pressure-redistributing mattress / cushion.' },
      { title: 'Keep moving', detail: 'Reposition q2h; small shifts hourly.' },
      { title: 'Incontinence care', detail: 'Barrier cream, prompt changes.' },
      { title: 'Nutrition', detail: 'Protein 1.2–1.5 g/kg/day; refer dietitian if MUST ≥2.' }
    ],
    medications: [
      { name: 'Barrier cream', dose: 'Apply with each pad change' }
    ],
    redFlags: ['New non-blanching erythema', 'Broken skin', 'Foul odour / exudate'],
    reference: 'NICE CG179 Pressure Ulcers'
  },
  {
    id: 8, code: 'PR-008', version: '1.0', category: 'Palliative',
    title: 'Symptom Control – End of Life', acuity: 'Routine',
    color: '#475569', icon: 'mdi-hand-heart',
    owner: 'Palliative · Dr. Hassan',
    updated: 'Updated 1 week ago',
    tags: ['Palliative', 'Comfort', 'Anticipatory'],
    summary: 'Anticipatory prescribing for the last days of life.',
    indication: 'Patient in last days of life (recognised by MDT).',
    steps: [
      { title: 'Stop non-essential meds', detail: 'Review all routes.' },
      { title: 'Convert to syringe driver', detail: 'If unable to swallow.' },
      { title: 'Pain – morphine', detail: '2.5–5 mg SC PRN; baseline if opioid-naïve.' },
      { title: 'Nausea – haloperidol', detail: '0.5–1.5 mg SC PRN.' },
      { title: 'Secretions – hyoscine butylbromide', detail: '20 mg SC PRN, max 120 mg/24 h.' },
      { title: 'Agitation – midazolam', detail: '2.5–5 mg SC PRN.' }
    ],
    medications: [
      { name: 'Morphine sulfate', dose: '2.5–5 mg SC PRN' },
      { name: 'Midazolam', dose: '2.5–5 mg SC PRN' },
      { name: 'Hyoscine butylbromide', dose: '20 mg SC PRN' }
    ],
    redFlags: ['Uncontrolled pain after 4 doses', 'Distress despite anxiolytic',
               'Family request for review'],
    reference: 'NICE NG31 Care of Dying Adults'
  },
  {
    id: 9, code: 'PR-009', version: '1.0', category: 'Infection',
    title: 'Suspected Tuberculosis', acuity: 'Moderate',
    color: '#16a34a', icon: 'mdi-virus',
    owner: 'Infectious Diseases · Dr. Karanja',
    updated: 'Updated 3 weeks ago',
    tags: ['TB', 'Isolation', 'Public Health'],
    summary: 'Initial workup and isolation pathway for suspected TB.',
    indication: 'Cough >2 weeks + weight loss, fever, night sweats, or contact.',
    steps: [
      { title: 'Place in isolation', detail: 'Negative-pressure room if available; mask.' },
      { title: 'Sputum × 3 (incl. early morning)', detail: 'GeneXpert MTB/RIF + AFB.' },
      { title: 'CXR', detail: 'Look for cavitation, infiltrates, effusion.' },
      { title: 'HIV test + screen contacts', detail: 'Per national TB policy.' },
      { title: 'Notify public health', detail: 'Mandatory disease notification.' },
      { title: 'Start RIPE if confirmed', detail: 'Per body weight banding.' }
    ],
    medications: [
      { name: 'Rifampicin / Isoniazid / Pyrazinamide / Ethambutol', dose: 'Per Kenya TB programme' }
    ],
    redFlags: ['Massive haemoptysis', 'Resp failure', 'Drug-resistant suspicion'],
    reference: 'WHO TB Guidelines 2023 / NTLD-P Kenya'
  },
  {
    id: 10, code: 'PR-010', version: '1.3', category: 'Anaphylaxis',
    title: 'Anaphylaxis (Adult & Paediatric)', acuity: 'Critical',
    color: '#e11d48', icon: 'mdi-allergy',
    owner: 'Emergency · Dr. Owino',
    updated: 'Updated 5 days ago',
    tags: ['Allergy', 'Adrenaline', 'ABCDE'],
    summary: 'Immediate management of suspected anaphylaxis with adrenaline-first approach.',
    indication: 'Sudden airway / breathing / circulation problem with skin changes after likely trigger.',
    steps: [
      { title: 'Remove trigger if possible', detail: 'Stop infusions, brush off stings.' },
      { title: 'Call resus team & lay patient flat', detail: 'Legs raised; pregnant – left lateral.' },
      { title: 'IM adrenaline', detail: 'Adult 500 mcg (0.5 mL of 1:1000); child 6–12 yr 300 mcg; <6 yr 150 mcg. Repeat after 5 min.' },
      { title: 'High-flow oxygen', detail: '15 L/min via NRBM; intubate if airway compromise.' },
      { title: 'IV fluid bolus', detail: 'Adult 500–1000 mL crystalloid; child 10 mL/kg.' },
      { title: 'Reassess and observe ≥6 h', detail: 'Risk of biphasic reaction; refer allergy clinic.' }
    ],
    medications: [
      { name: 'Adrenaline 1:1000', dose: '500 mcg IM (adult)' },
      { name: 'Hydrocortisone', dose: '200 mg IV (no longer first-line; consider in refractory)' },
      { name: 'Chlorphenamine', dose: '10 mg IV/IM (after stabilisation)' }
    ],
    redFlags: ['Stridor / hoarseness', 'Hypotension despite 2 doses adrenaline',
               'Loss of consciousness', 'Pregnancy with anaphylaxis'],
    reference: 'Resuscitation Council UK 2021 / EAACI Guideline'
  },
  {
    id: 11, code: 'PR-011', version: '1.0', category: 'Paediatrics',
    title: 'Paediatric Fever (0–5 years)', acuity: 'Moderate',
    color: '#f59e0b', icon: 'mdi-baby-face-outline',
    owner: 'Paediatrics · Dr. Wambui',
    updated: 'Updated 2 weeks ago',
    tags: ['Paeds', 'Traffic light', 'Fever'],
    summary: 'NICE traffic-light triage for the febrile child under 5.',
    indication: 'Child <5 years with axillary T ≥ 37.5 °C.',
    steps: [
      { title: 'Measure full vitals', detail: 'Tympanic/axillary T, HR, RR, SpO₂, CRT.' },
      { title: 'Apply traffic-light tool', detail: 'Colour, activity, respiratory, circulation, other.' },
      { title: 'Identify focus of infection', detail: 'ENT, chest, urine, skin, meningism.' },
      { title: 'Septic screen if Red', detail: 'FBC, CRP, blood culture, urine, ± LP, CXR.' },
      { title: 'Antipyretic for distress', detail: 'Paracetamol 15 mg/kg or ibuprofen 10 mg/kg.' },
      { title: 'Safety-net or admit', detail: 'Red → admit; Amber → senior review; Green → home with advice.' }
    ],
    medications: [
      { name: 'Paracetamol', dose: '15 mg/kg PO 4–6 hrly (max 60 mg/kg/24 h)' },
      { name: 'Ibuprofen', dose: '10 mg/kg PO 6–8 hrly (avoid if dehydrated/asthma)' },
      { name: 'Ceftriaxone', dose: '50 mg/kg IV (if sepsis suspected)' }
    ],
    redFlags: ['Non-blanching rash', 'Bulging fontanelle', 'Grunting / chest indrawing',
               'CRT ≥3 s', 'Reduced consciousness', 'Age <3 months with T ≥38 °C'],
    reference: 'NICE NG143 Fever in under 5s'
  },
  {
    id: 12, code: 'PR-012', version: '1.0', category: 'Paediatrics',
    title: 'Severe Acute Malnutrition (IMCI)', acuity: 'High',
    color: '#a16207', icon: 'mdi-food-off',
    owner: 'Paediatrics · Dr. Mwende',
    updated: 'Updated last month',
    tags: ['IMCI', 'F-75', 'Nutrition'],
    summary: 'Inpatient stabilisation of children with SAM per WHO 10-step plan.',
    indication: 'MUAC <115 mm, WFH <-3 SD, or bilateral pitting oedema.',
    steps: [
      { title: 'Treat / prevent hypoglycaemia', detail: '50 mL of 10% dextrose PO/NG or IV.' },
      { title: 'Treat / prevent hypothermia', detail: 'Kangaroo care, blankets, warm room.' },
      { title: 'Cautious rehydration', detail: 'ReSoMal 5 mL/kg q30 min × 2 h, NEVER routine IV.' },
      { title: 'Correct electrolytes', detail: 'Extra K, Mg; restrict Na.' },
      { title: 'Treat infection empirically', detail: 'Amoxicillin or ampicillin + gentamicin.' },
      { title: 'Start feeding F-75', detail: 'Small frequent feeds; transition to F-100/RUTF.' }
    ],
    medications: [
      { name: 'Amoxicillin', dose: '15 mg/kg PO TDS × 5 days' },
      { name: 'Ampicillin + Gentamicin', dose: 'IV per WHO weight bands' },
      { name: 'Vitamin A', dose: 'Single dose per age (only if eye signs / measles)' }
    ],
    redFlags: ['Refeeding syndrome', 'Heart failure during rehydration',
               'Persistent hypoglycaemia', 'Hypothermia <35 °C'],
    reference: 'WHO Pocket Book of Hospital Care for Children 2013 (rev. 2024)'
  },
  {
    id: 13, code: 'PR-013', version: '1.1', category: 'Endocrine',
    title: 'Hypoglycaemia Management', acuity: 'High',
    color: '#9333ea', icon: 'mdi-water',
    owner: 'Diabetes Team · S/N Achieng',
    updated: 'Updated last week',
    tags: ['Hypo', 'Diabetes', 'Glucose'],
    summary: 'Adult hypoglycaemia (BG < 4 mmol/L) treatment ladder.',
    indication: 'Capillary glucose <4 mmol/L, with or without symptoms.',
    steps: [
      { title: 'Check capillary BG & ABC', detail: 'Confirm before treating.' },
      { title: 'Conscious & cooperative', detail: '15–20 g fast-acting carb (e.g. 4 glucose tabs).' },
      { title: 'Conscious but uncooperative', detail: '1.5–2 tubes Glucogel buccally.' },
      { title: 'Unconscious / NBM', detail: '150 mL 10% dextrose IV over 15 min, or 1 mg glucagon IM.' },
      { title: 'Recheck in 15 min', detail: 'Repeat treatment up to 3 cycles; escalate if persists.' },
      { title: 'Long-acting carbohydrate', detail: 'Sandwich / biscuits once BG ≥4 mmol/L.' }
    ],
    medications: [
      { name: '10% dextrose', dose: '150 mL IV over 15 min' },
      { name: 'Glucagon', dose: '1 mg IM (one dose only)' }
    ],
    redFlags: ['Refractory after 3 cycles', 'Suspected sulfonylurea / alcohol cause',
               'Reduced GCS', 'Seizure'],
    reference: 'JBDS-IP Hypoglycaemia in Adults 2023'
  },
  {
    id: 14, code: 'PR-014', version: '1.0', category: 'Gastroenterology',
    title: 'Upper GI Bleed', acuity: 'High',
    color: '#b91c1c', icon: 'mdi-stomach',
    owner: 'Gastroenterology · Dr. Mutua',
    updated: 'Updated 2 weeks ago',
    tags: ['Haematemesis', 'Variceal', 'Endoscopy'],
    summary: 'Resuscitation and risk stratification for acute upper GI bleed.',
    indication: 'Haematemesis, melaena, or significant drop in Hb with shock.',
    steps: [
      { title: 'ABC + 2 large-bore IV', detail: 'Bloods incl. crossmatch 4 units, INR.' },
      { title: 'Calculate Glasgow-Blatchford', detail: 'Score ≥6 → endoscopy within 24 h.' },
      { title: 'Resuscitate to MAP ≥65', detail: 'Crystalloid + transfuse if Hb <70 g/L.' },
      { title: 'Reverse anticoagulation', detail: 'Vitamin K, PCC if on warfarin; idarucizumab for dabigatran.' },
      { title: 'Pre-endoscopy meds', detail: 'IV PPI; in suspected variceal: terlipressin + ceftriaxone.' },
      { title: 'Urgent endoscopy', detail: 'Within 24 h; <12 h if unstable / variceal.' }
    ],
    medications: [
      { name: 'Pantoprazole', dose: '80 mg IV bolus then 8 mg/h infusion' },
      { name: 'Terlipressin', dose: '2 mg IV q4h (variceal)' },
      { name: 'Ceftriaxone', dose: '1 g IV OD × 7 days (variceal)' }
    ],
    redFlags: ['Ongoing haematemesis', 'SBP <90', 'Lactate >4',
               'Failure of endoscopic haemostasis'],
    reference: 'NICE CG141 Acute Upper GI Bleed'
  },
  {
    id: 15, code: 'PR-015', version: '1.0', category: 'Surgery',
    title: 'Acute Abdomen Triage', acuity: 'High',
    color: '#c2410c', icon: 'mdi-stethoscope',
    owner: 'General Surgery · Dr. Kibet',
    updated: 'Updated 3 weeks ago',
    tags: ['Surgery', 'Abdomen', 'Triage'],
    summary: 'Structured workup of the patient with severe abdominal pain.',
    indication: 'Severe abdominal pain ≥6 h or peritonitic features.',
    steps: [
      { title: 'NEWS2 + analgesia', detail: 'IV morphine titrated; antiemetic.' },
      { title: 'IV access + bloods', detail: 'FBC, U&E, LFT, amylase, lactate, lipase, CRP, βhCG (women), G&S.' },
      { title: 'Imaging', detail: 'Erect CXR + AXR; CT abdo/pelvis if peritonitic / >65 y.' },
      { title: 'NBM + IV fluids', detail: 'Until surgical review.' },
      { title: 'Antibiotics if sepsis', detail: 'Co-amoxiclav + metronidazole (per local).' },
      { title: 'Senior surgical review', detail: 'Within 1 h for peritonitis or shock.' }
    ],
    medications: [
      { name: 'Morphine', dose: '2.5–5 mg IV titrated' },
      { name: 'Co-amoxiclav', dose: '1.2 g IV TDS' },
      { name: 'Metronidazole', dose: '500 mg IV TDS' }
    ],
    redFlags: ['Rigid / silent abdomen', 'Hypotension', 'Bilious vomiting',
               'Suspected ruptured AAA in >55 y'],
    reference: 'RCS Eng. Emergency General Surgery Standards'
  },
  {
    id: 16, code: 'PR-016', version: '1.0', category: 'Mental Health',
    title: 'Acute Behavioural Disturbance', acuity: 'High',
    color: '#6366f1', icon: 'mdi-head-cog-outline',
    owner: 'Psychiatry · Dr. Said',
    updated: 'Updated last week',
    tags: ['De-escalation', 'Sedation', 'Safety'],
    summary: 'Safe management of the acutely agitated or aggressive patient.',
    indication: 'Severe agitation risking harm to self, staff or others.',
    steps: [
      { title: 'Ensure team safety', detail: 'Call security, clear environment, exit route.' },
      { title: 'Verbal de-escalation', detail: 'Calm tone, single spokesperson, offer choices.' },
      { title: 'Rule out medical cause', detail: 'Glucose, hypoxia, infection, intoxication, head injury.' },
      { title: 'Offer oral medication', detail: 'Lorazepam 1–2 mg PO ± promethazine 25 mg PO.' },
      { title: 'IM rapid tranquillisation', detail: 'Lorazepam 2 mg IM; or haloperidol 5 mg + promethazine 25 mg IM.' },
      { title: 'Monitor & document', detail: 'BP, RR, SpO₂, sedation score q15 min for 1 h.' }
    ],
    medications: [
      { name: 'Lorazepam', dose: '1–2 mg PO/IM (max 4 mg in 24 h)' },
      { name: 'Haloperidol', dose: '5 mg IM (avoid in QT prolong / Parkinson’s)' },
      { name: 'Promethazine', dose: '25–50 mg IM' }
    ],
    redFlags: ['Over-sedation (RASS ≤-3)', 'Airway compromise',
               'QTc >500 ms', 'Suspected NMS'],
    reference: 'NICE NG10 Violence and Aggression'
  },
  {
    id: 17, code: 'PR-017', version: '1.0', category: 'Renal',
    title: 'Acute Kidney Injury (AKI)', acuity: 'Moderate',
    color: '#0ea5e9', icon: 'mdi-water-outline',
    owner: 'Nephrology · Dr. Njeri',
    updated: 'Updated 2 weeks ago',
    tags: ['AKI', 'Fluids', 'Nephrotoxins'],
    summary: 'STOP-AKI bundle: identify, optimise, refer.',
    indication: 'Creatinine ↑ ≥26 µmol/L in 48 h or ≥1.5× baseline; or UO <0.5 mL/kg/h ×6 h.',
    steps: [
      { title: 'Stage AKI (KDIGO 1–3)', detail: 'Use baseline creatinine and urine output.' },
      { title: 'Assess volume status', detail: 'Postural BP, JVP, lung bases, IVC US.' },
      { title: 'Sepsis 6 if infected', detail: 'Treat underlying cause.' },
      { title: 'Stop nephrotoxins', detail: 'NSAIDs, ACEi/ARB, metformin, diuretics, contrast.' },
      { title: 'Cautious fluid challenge', detail: '250–500 mL crystalloid; reassess.' },
      { title: 'Refer renal if Stage 3 / refractory', detail: 'Consider RRT for AEIOU indications.' }
    ],
    medications: [
      { name: 'Hartmann’s solution', dose: '500 mL IV bolus' },
      { name: 'Furosemide', dose: 'Only for fluid overload, not for AKI itself' }
    ],
    redFlags: ['K+ >6.5 mmol/L', 'pH <7.15', 'Pulmonary oedema',
               'Pericardial rub', 'Uraemic encephalopathy'],
    reference: 'NICE NG148 / KDIGO AKI Guideline 2012'
  },
  {
    id: 18, code: 'PR-018', version: '1.2', category: 'Infection',
    title: 'Catheter-Associated UTI Prevention', acuity: 'Routine',
    color: '#22c55e', icon: 'mdi-medical-bag',
    owner: 'IPC · S/N Achieng',
    updated: 'Updated 3 weeks ago',
    tags: ['CAUTI', 'IPC', 'Bundle'],
    summary: 'Insertion + maintenance bundle to prevent catheter UTIs.',
    indication: 'Any patient with an indwelling urinary catheter.',
    steps: [
      { title: 'Confirm indication daily', detail: 'Remove ASAP if no longer required.' },
      { title: 'Aseptic insertion', detail: 'Hand hygiene, sterile gloves, sterile field.' },
      { title: 'Closed drainage system', detail: 'Bag below bladder, never on floor.' },
      { title: 'Perineal care BD', detail: 'Soap and water; no antiseptic.' },
      { title: 'Sample correctly', detail: 'From sampling port after disinfection, never from bag.' },
      { title: 'Document & audit', detail: 'Insertion date, indication, removal date.' }
    ],
    medications: [
      { name: 'No prophylactic antibiotics', dose: 'Avoid unless documented infection' }
    ],
    redFlags: ['Cloudy / foul-smelling urine + fever', 'Suprapubic / loin pain',
               'New confusion in elderly', 'Catheter blockage'],
    reference: 'IPC Kenya / NICE QS61'
  },
  {
    id: 19, code: 'PR-019', version: '1.0', category: 'Wound Care',
    title: 'Diabetic Foot Ulcer', acuity: 'Moderate',
    color: '#0f766e', icon: 'mdi-foot-print',
    owner: 'Diabetes / Vascular · Dr. Kiprono',
    updated: 'Updated last month',
    tags: ['Diabetes', 'Ulcer', 'Offloading'],
    summary: 'Multidisciplinary management of the diabetic foot ulcer.',
    indication: 'Any new or non-healing foot wound in a diabetic patient.',
    steps: [
      { title: 'Classify (SINBAD / Wagner)', detail: 'Document size, depth, infection, ischaemia.' },
      { title: 'Vascular assessment', detail: 'Pulses, ABPI, refer if absent.' },
      { title: 'Probe to bone test', detail: 'Positive → suspect osteomyelitis; X-ray.' },
      { title: 'Sharp debridement', detail: 'Remove callus and slough.' },
      { title: 'Offloading device', detail: 'Total-contact cast or removable boot.' },
      { title: 'Infection control', detail: 'Swab if signs of infection; antibiotics per culture.' }
    ],
    medications: [
      { name: 'Flucloxacillin', dose: '500 mg PO QDS (mild infection)' },
      { name: 'Co-amoxiclav', dose: '625 mg PO TDS or 1.2 g IV TDS (moderate–severe)' }
    ],
    redFlags: ['Spreading cellulitis', 'Crepitus / necrosis (gas gangrene)',
               'Critical limb ischaemia', 'Systemic sepsis'],
    reference: 'NICE NG19 Diabetic Foot Problems / IWGDF 2023'
  },
  {
    id: 20, code: 'PR-020', version: '1.0', category: 'Critical Care',
    title: 'Massive Transfusion Protocol', acuity: 'Critical',
    color: '#7f1d1d', icon: 'mdi-water-pump',
    owner: 'Anaesthesia · Dr. Mohammed',
    updated: 'Updated 1 week ago',
    tags: ['MTP', 'Trauma', 'Haemorrhage'],
    summary: 'Balanced 1:1:1 transfusion for major haemorrhage.',
    indication: 'ABC score ≥2, expected ≥10 units RBC in 24 h, or shock index >1.4.',
    steps: [
      { title: 'Activate MTP – call blood bank', detail: 'Senior clinician declares MTP.' },
      { title: 'Permissive hypotension', detail: 'Target SBP 80–90 (90–100 if TBI).' },
      { title: 'Tranexamic acid', detail: '1 g IV over 10 min within 3 h, then 1 g over 8 h.' },
      { title: 'Issue Pack 1', detail: '4 RBC : 4 FFP : 1 platelet pool.' },
      { title: 'Repeat near-patient testing', detail: 'ABG, ROTEM/TEG, fibrinogen, Ca²⁺ q30 min.' },
      { title: 'Source control', detail: 'Theatre / IR within 1 h; deactivate MTP when stable.' }
    ],
    medications: [
      { name: 'Tranexamic acid', dose: '1 g IV bolus + 1 g over 8 h' },
      { name: 'Calcium chloride 10%', dose: '10 mL IV after every 4 units RBC' },
      { name: 'Cryoprecipitate / fibrinogen', dose: 'Target fibrinogen >1.5 g/L (>2 in obstetric)' }
    ],
    redFlags: ['Lethal triad: acidosis, coagulopathy, hypothermia',
               'Hyperkalaemia from stored blood', 'Citrate toxicity (low Ca)',
               'Failure to identify source within 60 min'],
    reference: 'NICE NG39 Major Trauma / NHSBT MTP Guidance'
  },
  {
    id: 21, code: 'PR-021', version: '1.0', category: 'Cardiology',
    title: 'Acute Decompensated Heart Failure', acuity: 'High',
    color: '#0369a1', icon: 'mdi-heart-broken',
    owner: 'Cardiology · Dr. Otieno',
    updated: 'Updated 2 weeks ago',
    tags: ['Heart failure', 'Pulmonary oedema', 'Diuretics'],
    summary: 'LMNOP approach to acute pulmonary oedema and decompensated HF.',
    indication: 'Acute breathlessness with crackles, raised JVP, ± peripheral oedema.',
    steps: [
      { title: 'Sit up, oxygen if SpO₂ <94%', detail: 'NIV (CPAP) early if persistent hypoxia.' },
      { title: 'IV access + bloods + ECG', detail: 'Troponin, BNP, U&E, FBC, TFT.' },
      { title: 'IV loop diuretic', detail: 'Furosemide 40–80 mg IV (or 2.5× home dose).' },
      { title: 'GTN infusion if SBP >110', detail: '10–200 mcg/min titrated.' },
      { title: 'Daily weights + strict I/O', detail: 'Catheterise if accurate UO needed.' },
      { title: 'Investigate trigger', detail: 'ACS, AF, infection, non-compliance, anaemia.' }
    ],
    medications: [
      { name: 'Furosemide', dose: '40–80 mg IV (or infusion 5–10 mg/h)' },
      { name: 'GTN infusion', dose: '10–200 mcg/min IV' },
      { name: 'Morphine', dose: '2.5 mg IV (use sparingly)' }
    ],
    redFlags: ['SBP <90 with peripheral shutdown (cardiogenic shock)',
               'SpO₂ <90% on NRBM', 'Anuria despite diuretics',
               'New STEMI on ECG'],
    reference: 'ESC 2021 Heart Failure Guidelines'
  },
  {
    id: 22, code: 'PR-022', version: '1.0', category: 'Neurology',
    title: 'Status Epilepticus (Adult)', acuity: 'Critical',
    color: '#4338ca', icon: 'mdi-flash',
    owner: 'Neurology · Dr. Njoroge',
    updated: 'Updated 5 days ago',
    tags: ['Seizure', 'Benzodiazepine', 'EEG'],
    summary: 'Time-staged anticonvulsant ladder for convulsive status epilepticus.',
    indication: 'Continuous seizure ≥5 min or recurrent seizures without recovery.',
    steps: [
      { title: '0–5 min: ABC, position, oxygen', detail: 'Capillary glucose, IV access, bloods incl. AED levels.' },
      { title: '5–10 min: First benzodiazepine', detail: 'Lorazepam 4 mg IV, or midazolam 10 mg IM/buccal.' },
      { title: '10–20 min: Second benzodiazepine', detail: 'Repeat once if still seizing.' },
      { title: '20–40 min: Second-line AED', detail: 'Levetiracetam 60 mg/kg or sodium valproate 40 mg/kg IV.' },
      { title: '40+ min: Refractory – call ICU', detail: 'Intubate; thiopentone or propofol infusion.' },
      { title: 'Continuous EEG when refractory', detail: 'Identify NCSE; treat underlying cause.' }
    ],
    medications: [
      { name: 'Lorazepam', dose: '4 mg IV (repeat once at 10 min)' },
      { name: 'Levetiracetam', dose: '60 mg/kg IV over 10 min' },
      { name: 'Sodium valproate', dose: '40 mg/kg IV over 10 min' }
    ],
    redFlags: ['Hypoxia / aspiration', 'Hypoglycaemia', 'Pregnancy (eclampsia)',
               'Refractory after 2 second-line agents'],
    reference: 'ILAE 2023 / NICE NG217'
  }
]

const categoryList = computed(() => [...new Set(protocols.map(p => p.category))].sort())
const acuityList = ['Routine', 'Moderate', 'High', 'Critical']

const filtered = computed(() => {
  const q = (search.value || '').toLowerCase()
  return protocols.filter(p => {
    if (filterCategory.value && p.category !== filterCategory.value) return false
    if (filterAcuity.value && p.acuity !== filterAcuity.value) return false
    if (q) {
      const blob = `${p.title} ${p.code} ${p.summary} ${(p.tags || []).join(' ')}`.toLowerCase()
      if (!blob.includes(q)) return false
    }
    return true
  })
})

const summary = computed(() => [
  { label: 'Total protocols', value: protocols.length, icon: 'mdi-clipboard-text', color: 'teal' },
  { label: 'Categories',      value: categoryList.value.length, icon: 'mdi-shape', color: 'indigo' },
  { label: 'Critical pathways', value: protocols.filter(p => p.acuity === 'Critical').length,
    icon: 'mdi-alert-octagram', color: 'error' },
  { label: 'Last update',     value: 'Today', icon: 'mdi-update', color: 'purple' }
])

function acuityColor(a) {
  return ({ Routine: 'success', Moderate: 'info', High: 'warning', Critical: 'error' })[a] || 'grey'
}
function detailGradient(c) {
  return `linear-gradient(135deg, ${c} 0%, ${c}cc 60%, ${c}aa 100%)`
}
function openProtocol(p) {
  active.value = p
  dialog.value = true
}
function openNew() {
  snack.text = 'Custom protocol authoring coming soon.'
  snack.color = 'info'
  snack.show = true
}
function printProtocol() { window.print() }
function applyToPatient() {
  dialog.value = false
  router.push('/homecare/patients')
}
</script>

<style scoped>
.hc-bg { background:
  linear-gradient(135deg, rgba(13,148,136,0.06) 0%, rgba(2,132,199,0.04) 100%);
  min-height: calc(100vh - 64px);
}
.hc-stat {
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
}
:global(.v-theme--dark) .hc-stat {
  background: rgb(30, 41, 59);
  border-color: rgba(255,255,255,0.08);
}

.hc-protocol {
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
  cursor: pointer;
  transition: transform 0.18s ease, box-shadow 0.18s ease;
  position: relative;
  overflow: hidden;
}
.hc-protocol:hover {
  transform: translateY(-2px);
  box-shadow: 0 18px 40px -22px rgba(15,23,42,0.25);
}
.hc-protocol-band { height: 6px; }
.hc-protocol-icon { box-shadow: 0 6px 18px -8px rgba(0,0,0,0.35); }

:global(.v-theme--dark) .hc-protocol {
  background: rgb(30, 41, 59);
  border-color: rgba(255,255,255,0.08);
}

.hc-protocol-row {
  background: white;
  border: 1px solid rgba(15,23,42,0.06);
  cursor: pointer;
}
.hc-protocol-row:hover { background: rgba(13,148,136,0.04); }
:global(.v-theme--dark) .hc-protocol-row { background: rgb(30, 41, 59); }

.hc-detail-hero { color: white; }
</style>
