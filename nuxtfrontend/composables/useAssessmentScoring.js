// Patient Assessment scoring engine + option definitions.
// Mirrors backend/homecare/assessments.py so the live form preview
// matches what the server computes (Braden, Caprini, Morse, MUST, CAM, Pain).
// Premium upgrade: GCS consciousness, disease-specific bundles,
// pain reassessment timer, CDC bundle guideline summaries.

// ── Braden Scale (NPIAP) ──────────────────────────────────────────
export const BRADEN_SUBSCALES = [
  { key: 'sensory', label: 'Sensory Perception', min: 1, max: 4 },
  { key: 'moisture', label: 'Moisture', min: 1, max: 4 },
  { key: 'activity', label: 'Activity', min: 1, max: 4 },
  { key: 'mobility', label: 'Mobility', min: 1, max: 4 },
  { key: 'nutrition', label: 'Nutrition', min: 1, max: 4 },
  { key: 'friction', label: 'Friction & Shear', min: 1, max: 3 },
]

export const BRADEN_OPTIONS = {
  sensory: [
    { value: 1, label: '1 — Completely limited' },
    { value: 2, label: '2 — Very limited' },
    { value: 3, label: '3 — Slightly limited' },
    { value: 4, label: '4 — No impairment' },
  ],
  moisture: [
    { value: 1, label: '1 — Constantly moist' },
    { value: 2, label: '2 — Very moist' },
    { value: 3, label: '3 — Occasionally moist' },
    { value: 4, label: '4 — Rarely moist' },
  ],
  activity: [
    { value: 1, label: '1 — Bedfast' },
    { value: 2, label: '2 — Chairfast' },
    { value: 3, label: '3 — Walks occasionally' },
    { value: 4, label: '4 — Walks frequently' },
  ],
  mobility: [
    { value: 1, label: '1 — Completely immobile' },
    { value: 2, label: '2 — Very limited' },
    { value: 3, label: '3 — Slightly limited' },
    { value: 4, label: '4 — No limitation' },
  ],
  nutrition: [
    { value: 1, label: '1 — Very poor' },
    { value: 2, label: '2 — Probably inadequate' },
    { value: 3, label: '3 — Adequate' },
    { value: 4, label: '4 — Excellent' },
  ],
  friction: [
    { value: 1, label: '1 — Problem' },
    { value: 2, label: '2 — Potential problem' },
    { value: 3, label: '3 — No apparent problem' },
  ],
}

export function bradenRiskLabel(total) {
  if (total == null) return ''
  if (total <= 9) return 'Severe Risk'
  if (total <= 12) return 'High Risk'
  if (total <= 14) return 'Moderate Risk'
  if (total <= 18) return 'Mild Risk'
  return 'No Risk'
}

export function calcBraden(payload = {}) {
  const out = {}
  let valid = 0, sum = 0, allValid = true
  for (const s of BRADEN_SUBSCALES) {
    const v = num(payload[s.key])
    out[s.key] = v
    if (v == null) allValid = false
    else { valid++; sum += v }
  }
  out.total = allValid ? sum : (valid ? sum : null)
  out.risk_level = out.total != null ? bradenRiskLabel(out.total) : ''
  return out
}

// ── Caprini Score (VTE risk) ─────────────────────────────────────
export const CAPRINI_FACTORS = [
  { key: 'age_41_60', label: 'Age 41–60', points: 1 },
  { key: 'age_61_74', label: 'Age 61–74', points: 2 },
  { key: 'age_75_plus', label: 'Age ≥ 75', points: 3 },
  { key: 'bmi_25_plus', label: 'BMI ≥ 25', points: 1 },
  { key: 'minor_surgery', label: 'Minor surgery (< 45 min)', points: 1 },
  { key: 'major_surgery_45min', label: 'Major surgery (> 45 min)', points: 2 },
  { key: 'laparoscopic_surgery_45min', label: 'Laparoscopic surgery (> 45 min)', points: 2 },
  { key: 'elective_major_orthopedic', label: 'Elective major orthopedic', points: 2 },
  { key: 'pregnancy_postpartum', label: 'Pregnancy / postpartum', points: 1 },
  { key: 'history_vte', label: 'History of VTE', points: 3 },
  { key: 'thrombophilia', label: 'Thrombophilia', points: 3 },
  { key: 'sepsis', label: 'Sepsis (< 1 mo)', points: 1 },
  { key: 'malignancy_present', label: 'Malignancy (present)', points: 2 },
  { key: 'malignancy_previous', label: 'Malignancy (previous)', points: 1 },
  { key: 'acute_mi', label: 'Acute MI (< 1 mo)', points: 1 },
  { key: 'congestive_heart_failure', label: 'Congestive heart failure (< 1 mo)', points: 1 },
  { key: 'bedbound', label: 'Bedbound > 72 h', points: 1 },
  { key: 'central_venous_access', label: 'Central venous access', points: 2 },
  { key: 'varicose_veins', label: 'Varicose veins', points: 1 },
  { key: 'inflammatory_bowel_disease', label: 'Inflammatory bowel disease', points: 1 },
  { key: 'serious_lung_disease', label: 'Serious lung disease', points: 1 },
  { key: 'oral_contraceptives', label: 'Oral contraceptives / HRT', points: 1 },
  { key: 'swollen_leg', label: 'Swollen leg (current)', points: 1 },
  { key: 'acute_spinal_cord_injury', label: 'Acute spinal cord injury (< 1 mo)', points: 3 },
]

export function capriniRiskLabel(points) {
  if (points == null) return ''
  if (points <= 1) return 'Low'
  if (points === 2) return 'Moderate'
  if (points <= 4) return 'High'
  return 'Very High'
}

export function calcCaprini(payload = {}) {
  const factors = payload.factors || {}
  let points = 0
  for (const f of CAPRINI_FACTORS) {
    if (factors[f.key]) points += f.points
  }
  return { ...payload, factors, points, risk_level: capriniRiskLabel(points) }
}

// ── Morse Fall Scale ─────────────────────────────────────────────
export const MORSE_AMBULATORY_AID = [
  { value: 'none', label: 'None / bedrest / wheelchair / nurse-assisted', score: 0 },
  { value: 'crutches', label: 'Crutches / cane / walker', score: 15 },
  { value: 'furniture', label: 'Furniture', score: 30 },
]
export const MORSE_GAIT = [
  { value: 'normal', label: 'Normal / bedrest / immobile', score: 0 },
  { value: 'weak', label: 'Weak', score: 10 },
  { value: 'impaired', label: 'Impaired', score: 20 },
]
export const MORSE_MENTAL = [
  { value: 'oriented', label: 'Oriented / knows own limitations', score: 0 },
  { value: 'overestimates', label: 'Overestimates / forgets limitations', score: 15 },
]

export function morseRiskLabel(score) {
  if (score == null) return ''
  if (score >= 45) return 'High'
  if (score >= 25) return 'Moderate'
  return 'Low'
}

export function calcMorse(payload = {}) {
  const items = {
    history_of_falls: payload.history_of_falls ? 15 : 0,
    secondary_dx: payload.secondary_dx ? 15 : 0,
    ambulatory_aid: (MORSE_AMBULATORY_AID.find(a => a.value === payload.ambulatory_aid)?.score) ?? 0,
    iv_lock: payload.iv_lock ? 15 : 0,
    gait: (MORSE_GAIT.find(g => g.value === payload.gait)?.score) ?? 0,
    mental_status: (MORSE_MENTAL.find(m => m.value === payload.mental_status)?.score) ?? 0,
  }
  const score = Object.values(items).reduce((a, b) => a + b, 0)
  return { ...payload, ...items, score, risk_level: morseRiskLabel(score) }
}

// ── MUST (BAPEN malnutrition) ────────────────────────────────────
export function mustRiskLabel(total) {
  if (total == null) return ''
  if (total >= 2) return 'High'
  if (total === 1) return 'Medium'
  return 'Low'
}

export function calcMust(payload = {}) {
  const height = num(payload.height_cm)
  const weight = floatNum(payload.weight_kg)
  let bmi = null
  if (height && weight) bmi = round(weight / Math.pow(height / 100, 2), 1)
  const bmiScore = bmi == null ? null : (bmi > 20 ? 0 : bmi >= 18.5 ? 1 : 2)
  const lossPct = floatNum(payload.weight_loss_percent)
  const lossScore = lossPct == null ? null : (lossPct < 5 ? 0 : lossPct <= 10 ? 1 : 2)
  const acuteScore = payload.acute_no_nutrition ? 2 : 0
  const scores = [bmiScore, lossScore, acuteScore].filter(s => s != null)
  const total = scores.length ? scores.reduce((a, b) => a + b, 0) : null
  return {
    ...payload, height_cm: height, weight_kg: weight, bmi, bmi_score: bmiScore,
    weight_loss_percent: lossPct, loss_score: lossScore, acute_score: acuteScore,
    total_score: total, risk_level: mustRiskLabel(total),
  }
}

// ── CAM (delirium) ───────────────────────────────────────────────
export function calcCam(payload = {}) {
  const f1 = !!(payload.acute_onset || payload.fluctuating)
  const f2 = !!payload.inattention
  const f3 = !!payload.disorganized_thinking
  const f4 = !!payload.altered_consciousness
  const positive = f1 && f2 && (f3 || f4)
  return { ...payload, acute_onset: f1, inattention: f2, disorganized_thinking: f3, altered_consciousness: f4, cam_positive: positive }
}

// ── GCS (Glasgow Coma Scale) ─────────────────────────────────────
export const GCS_EYE = [
  { value: 4, label: '4 — Spontaneous' },
  { value: 3, label: '3 — To speech' },
  { value: 2, label: '2 — To pain' },
  { value: 1, label: '1 — None' },
]
export const GCS_VERBAL = [
  { value: 5, label: '5 — Oriented' },
  { value: 4, label: '4 — Confused' },
  { value: 3, label: '3 — Inappropriate words' },
  { value: 2, label: '2 — Incomprehensible sounds' },
  { value: 1, label: '1 — None' },
]
export const GCS_MOTOR = [
  { value: 6, label: '6 — Obeys commands' },
  { value: 5, label: '5 — Localises to pain' },
  { value: 4, label: '4 — Withdraws from pain' },
  { value: 3, label: '3 — Abnormal flexion (decorticate)' },
  { value: 2, label: '2 — Abnormal extension (decerebrate)' },
  { value: 1, label: '1 — None' },
]

export function calcGcs(payload = {}) {
  const eye = num(payload.eye)
  const verbal = num(payload.verbal)
  const motor = num(payload.motor)
  const total = [eye, verbal, motor].every(v => v != null) ? eye + verbal + motor : null
  return {
    eye: eye ?? null,
    verbal: verbal ?? null,
    motor: motor ?? null,
    total,
    category: total != null ? (total >= 13 ? 'Mild' : total >= 9 ? 'Moderate' : 'Severe') : '',
  }
}

// ── Pain (NRS 0–10) ──────────────────────────────────────────────
export function painCategory(score) {
  if (score == null) return ''
  if (score === 0) return 'None'
  if (score <= 3) return 'Mild'
  if (score <= 6) return 'Moderate'
  return 'Severe'
}

export function calcPain(payload = {}) {
  const score = num(payload.score)
  const before = num(payload.before)
  const after = num(payload.after)
  return {
    ...payload,
    score,
    before,
    after,
    score_category: score != null ? painCategory(score) : '',
    pain_reduced: (before != null && after != null) ? (before - after) : null,
    reassessment_due: payload.reassessment_due_at || null,
  }
}

// ── Disease-Specific Bundles ─────────────────────────────────────
export const EDEMA_LEVELS = ['None', 'Mild (1+)', 'Moderate (2+)', 'Severe (3+)', 'Pitting (4+)']

export function calcDiabetesBundle(payload = {}) {
  return {
    foot_ulcer: !!payload.foot_ulcer,
    latest_bg: floatNum(payload.latest_bg),
    latest_bg_mmol: floatNum(payload.latest_bg_mmol),
    last_foot_check: payload.last_foot_check || null,
    neuropathy: !!payload.neuropathy,
    insulin_pump: !!payload.insulin_pump,
  }
}

export function calcHeartFailureBundle(payload = {}) {
  return {
    daily_weight: floatNum(payload.daily_weight),
    edema: payload.edema || 'None',
    sob_at_rest: !!payload.sob_at_rest,
    sob_on_exertion: !!payload.sob_on_exertion,
    orthopnea: !!payload.orthopnea,
    jvd: !!payload.jvd,
    lung_crackles: !!payload.lung_crackles,
  }
}

// ── Catheter bundle with CDC daily-care fields ───────────────────
export const CATHETER_TYPE = ['Foley', 'Suprapubic', 'Condom', 'Intermittent']
export const LINE_TYPE = ['PICC', 'Hickman', 'CVC (non-tunneled)', 'Port-a-cath', 'Midline', 'Dialysis catheter']

export function calcCatheterBundle(payload = {}) {
  return {
    present: !!payload.present,
    type: payload.type || 'Foley',
    insert_date: payload.insert_date || null,
    indication: payload.indication || '',
    closed_system_maintained: payload.closed_system_maintained !== false,
    bag_below_bladder: payload.bag_below_bladder !== false,
    needs_review: !!payload.needs_review,
    next_review_date: payload.next_review_date || null,
    daily_care_performed: !!payload.daily_care_performed,
    bag_emptied: !!payload.bag_emptied,
    last_bag_change: payload.last_bag_change || null,
  }
}

// ── Overall risk aggregation (mirrors assessments.aggregate_risk) ──
export function aggregateRisk(bradenTotal, capriniPoints, morseScore, mustTotal, camPositive, painScore) {
  let level = 'low'
  const bump = (l) => {
    const rank = { low: 0, medium: 1, high: 2, critical: 3 }
    if (rank[l] > rank[level]) level = l
  }
  if (bradenTotal != null && bradenTotal <= 12) bump('high')
  else if (bradenTotal != null && bradenTotal <= 18) bump('medium')
  if (capriniPoints != null && capriniPoints >= 5) bump('critical')
  else if (capriniPoints != null && capriniPoints >= 3) bump('high')
  if (morseScore != null && morseScore >= 45) bump('high')
  if (mustTotal != null && mustTotal >= 2) bump('high')
  if (camPositive) bump('high')
  if (painScore != null && painScore >= 7) bump('high')
  return level
}

// ── Alert generation (mirrors assessments.generate_alerts) ───────
export function generateAlerts(session) {
  const alerts = []
  const bt = session.braden_total
  const bradenRisk = session.braden?.risk_level || ''
  if (bt != null && bt <= 18) {
    const sev = bt <= 12 ? 'critical' : bt <= 14 ? 'high' : 'warning'
    alerts.push({
      code: 'BRADEN_RISK', category: 'pressure', severity: sev,
      title: 'Pressure injury risk',
      detail: `Braden total ${bt} (${bradenRisk}). Implement pressure-relief measures and skin care bundle.`,
      threshold: 'Braden ≤ 18', value: `${bt} – ${bradenRisk}`,
      recommendation: 'Reposition every 2 h, pressure-relieving mattress, skin moisture management (NPIAP).',
    })
  }
  const cp = session.caprini_points
  const capriniRisk = session.vte_caprini?.risk_level || ''
  if (cp != null && cp >= 3) {
    const sev = cp >= 5 ? 'critical' : 'high'
    alerts.push({
      code: 'VTE_RISK', category: 'vte', severity: sev,
      title: 'Venous thromboembolism risk',
      detail: `Caprini score ${cp} (${capriniRisk}). Consider pharmacological / mechanical prophylaxis.`,
      threshold: 'Caprini ≥ 3', value: `${cp} – ${capriniRisk}`,
      recommendation: 'Assess for anticoagulation or compression stockings per physician order.',
    })
  }
  const ms = session.morse_score
  const morseRisk = session.falls?.risk_level || ''
  if (ms != null && ms >= 45) {
    alerts.push({
      code: 'FALLS_RISK', category: 'falls', severity: 'high',
      title: 'High falls risk',
      detail: `Morse score ${ms} (${morseRisk}). Implement falls-prevention care plan.`,
      threshold: 'Morse ≥ 45', value: `${ms} – ${morseRisk}`,
      recommendation: 'Bed alarm, non-slip footwear, toileting schedule, review sedating medications.',
    })
  }
  const mt = session.must_score
  const mustRisk = session.must?.risk_level || ''
  if (mt != null && mt >= 2) {
    alerts.push({
      code: 'MALNUTRITION', category: 'nutrition', severity: 'high',
      title: 'Malnutrition risk',
      detail: `MUST score ${mt} (${mustRisk}). Refer to dietitian for nutritional support.`,
      threshold: 'MUST ≥ 2', value: `${mt} – ${mustRisk}`,
      recommendation: 'Dietitian referral, oral nutritional supplements, reassess per care setting.',
    })
  }
  if (session.cam_positive) {
    alerts.push({
      code: 'DELIRIUM', category: 'delirium', severity: 'critical',
      title: 'Delirium detected (CAM positive)',
      detail: 'CAM is positive — acute confusional state. Alert physician for medical review.',
      threshold: 'CAM positive', value: 'Positive',
      recommendation: 'Physician review, identify and treat underlying cause, orient patient, address sensory deficits.',
    })
  }
  const ps = session.pain_score
  if (ps != null && ps >= 7) {
    const sev = ps >= 9 ? 'critical' : 'high'
    alerts.push({
      code: 'SEVERE_PAIN', category: 'pain', severity: sev,
      title: 'Severe pain',
      detail: `Pain score ${ps}/10. Provide analgesia and reassess in 30–60 min.`,
      threshold: 'Pain ≥ 7', value: `${ps}/10`,
      recommendation: 'Administer prescribed analgesia, reassess 30–60 min post-intervention.',
    })
  }
  const cb = session.catheter_bundle || {}
  if (cb.present && cb.needs_review) {
    alerts.push({
      code: 'CATHETER_REVIEW', category: 'device', severity: 'warning',
      title: 'Catheter removal review',
      detail: 'Catheter may no longer be needed — review indication for prompt removal (CDC).',
      threshold: 'Catheter still needed = No', value: 'Review due',
      recommendation: 'Assess daily whether catheter is still indicated; remove ASAP when no longer needed.',
    })
  }
  const clb = session.central_line_bundle || {}
  if (clb.present && clb.needs_removal) {
    alerts.push({
      code: 'LINE_REMOVAL', category: 'device', severity: 'warning',
      title: 'Central line removal review',
      detail: 'Central line may no longer be needed — review for prompt removal (CDC CLABSI).',
      threshold: 'Line still needed = No', value: 'Review due',
      recommendation: 'Remove promptly when no longer needed to prevent CLABSI.',
    })
  }
  // Disease-specific alerts
  const db = session.disease_bundles || {}
  if (db.diabetes?.foot_ulcer) {
    alerts.push({
      code: 'DIABETIC_FOOT_ULCER', category: 'other', severity: 'high',
      title: 'Diabetic foot ulcer detected',
      detail: 'Foot inspection positive for ulcer. Initiate wound care and refer to podiatry.',
      threshold: 'Foot ulcer present', value: 'Positive',
      recommendation: 'Daily foot inspection, offloading, wound care, blood glucose optimisation.',
    })
  }
  if (db.heart_failure?.sob_at_rest || db.heart_failure?.orthopnea) {
    alerts.push({
      code: 'HEART_FAILURE_DECOMPENSATION', category: 'other', severity: 'high',
      title: 'Heart failure decompensation signs',
      detail: 'Patient reports dyspnoea at rest or orthopnea. Assess volume status and notify physician.',
      threshold: 'SOB at rest or orthopnea', value: 'Positive',
      recommendation: 'Daily weight, fluid restriction, adjust diuretics, monitor for pulmonary oedema.',
    })
  }
  return alerts
}

// ── Full session recalculation ───────────────────────────────────
export function recalcSession(form) {
  const braden = calcBraden(form.braden || {})
  const vte_caprini = calcCaprini(form.vte_caprini || {})
  const falls = calcMorse(form.falls || {})
  const must = calcMust(form.must || {})
  const cam = calcCam(form.cam || {})
  const pain = calcPain(form.pain || {})
  return {
    ...form,
    braden, vte_caprini, falls, must, cam, pain,
    braden_total: braden.total,
    caprini_points: vte_caprini.points,
    morse_score: falls.score,
    must_score: must.total_score,
    pain_score: pain.score,
    cam_positive: cam.cam_positive,
    overall_risk_level: aggregateRisk(
      braden.total, vte_caprini.points, falls.score,
      must.total_score, cam.cam_positive, pain.score,
    ),
    alerts_triggered: generateAlerts({
      braden_total: braden.total, caprini_points: vte_caprini.points,
      morse_score: falls.score, must_score: must.total_score,
      cam_positive: cam.cam_positive, pain_score: pain.score,
      braden, vte_caprini, falls, must,
      catheter_bundle: form.catheter_bundle || {},
      central_line_bundle: form.central_line_bundle || {},
      disease_bundles: form.disease_bundles || {},
    }),
  }
}

// ── Shared option lists for the form ─────────────────────────────
export const ARRIVAL_MODES = ['Home visit', 'Clinic visit', 'Ambulance', 'Transfer', 'Telehealth']
export const AVPU = ['Alert', 'Verbal', 'Pain', 'Unresponsive']
export const SKIN_INTEGRITY = ['Intact', 'Redness', 'Ulcer', 'Other']
export const SKIN_MOISTURE = ['Dry', 'Normal', 'Excessive']
export const MOBILITY_LEVEL = ['Bedbound', 'Walks with help', 'Independent']
export const HEART_RHYTHM = ['Normal Sinus', 'AFib', 'Other']
export const PERIPHERAL_PULSES = ['Present', 'Weak', 'Absent']
export const BREATH_SOUNDS = ['Clear', 'Crackles', 'Wheezes', 'Other']
export const RESP_EFFORT = ['Normal', 'Laboured']
export const OXYGEN_MODE = ['Nasal cannula', 'Simple face mask', 'Venturi mask', 'Non-rebreather mask', 'High-flow nasal cannula', 'CPAP', 'BiPAP / NIV', 'Tracheostomy mask']
export const ABDOMEN_SHAPE = ['Soft', 'Distended']
export const BOWEL_SOUNDS = ['Normal', 'Hypoactive', 'Hyperactive']
export const CONTINENCE = ['Continent', 'Incontinent']
export const NUTRITION_ASSIST = ['Independent', 'Needs Help']

export const RISK_META = {
  low: { color: 'success', hex: '#059669', label: 'Low' },
  medium: { color: 'info', hex: '#0284c7', label: 'Medium' },
  high: { color: 'warning', hex: '#d97706', label: 'High' },
  critical: { color: 'error', hex: '#b91c1c', label: 'Critical' },
}

export const SEVERITY_META = {
  info: { color: 'info', icon: 'mdi-information', hex: '#0284c7' },
  warning: { color: 'warning', icon: 'mdi-alert', hex: '#d97706' },
  high: { color: 'error', icon: 'mdi-alert-octagram', hex: '#dc2626' },
  critical: { color: 'error', icon: 'mdi-alert-octagon', hex: '#b91c1c' },
}

// ── NEWS2 (RCP 2017) Vital Signs Scoring ──────────────────────────
export function scoreRR(v) {
  if (v == null || isNaN(v)) return 0
  if (v <= 8) return 3
  if (v <= 11) return 1
  if (v <= 20) return 0
  if (v <= 24) return 2
  return 3
}
export function scoreSpO2Scale1(v) {
  if (v == null || isNaN(v)) return 0
  if (v <= 91) return 3
  if (v <= 93) return 2
  if (v <= 95) return 1
  return 0
}
export function scoreSpO2Scale2(v, onO2) {
  if (v == null || isNaN(v)) return 0
  if (v <= 83) return 3
  if (v <= 85) return 2
  if (v <= 87) return 1
  if (v <= 92) return 0
  if (!onO2) return 0
  if (v <= 94) return 1
  if (v <= 96) return 2
  return 3
}
export function scoreOxygen(o) { return o === 'Supplemental O₂' ? 2 : 0 }
export function scoreSBP(v) {
  if (v == null || isNaN(v)) return 0
  if (v <= 90) return 3
  if (v <= 100) return 2
  if (v <= 110) return 1
  if (v <= 219) return 0
  return 3
}
export function scoreHR(v) {
  if (v == null || isNaN(v)) return 0
  if (v <= 40) return 3
  if (v <= 50) return 1
  if (v <= 90) return 0
  if (v <= 110) return 1
  if (v <= 130) return 2
  return 3
}
export function scoreTemp(v) {
  if (v == null || isNaN(v)) return 0
  if (v <= 35.0) return 3
  if (v <= 36.0) return 1
  if (v <= 38.0) return 0
  if (v <= 39.0) return 1
  return 2
}
export function scoreConsciousness(c) { return c === 'A' || c === 'Alert' ? 0 : 3 }

export function calcNews2(vitals) {
  const rr = scoreRR(vitals.respiratory_rate)
  const spo2 = vitals.scale2
    ? scoreSpO2Scale2(vitals.spo2, vitals.oxygen === 'Supplemental O₂')
    : scoreSpO2Scale1(vitals.spo2)
  const oxygen = scoreOxygen(vitals.oxygen)
  const sbp = scoreSBP(vitals.systolic_bp)
  const hr = scoreHR(vitals.heart_rate)
  const temp = scoreTemp(vitals.temperature)
  const consciousness = scoreConsciousness(vitals.consciousness)
  const total = rr + spo2 + oxygen + sbp + hr + temp + consciousness
  const hasRed = [rr, spo2, oxygen, sbp, hr, temp, consciousness].some(s => s >= 3)
  let riskLabel = 'Low', riskColor = 'success', riskHex = '#059669'
  if (total === 0) { riskLabel = 'Low'; riskColor = 'success'; riskHex = '#059669' }
  else if (total <= 4 && !hasRed) { riskLabel = 'Low – Medium'; riskColor = 'info'; riskHex = '#0284c7' }
  else if (total <= 6 || hasRed) { riskLabel = 'Medium'; riskColor = 'warning'; riskHex = '#d97706' }
  else { riskLabel = 'High'; riskColor = 'error'; riskHex = '#b91c1c' }
  const willEscalate = total >= 5 || hasRed
  return {
    rr, spo2, oxygen, sbp, hr, temp, consciousness,
    total, hasRed, risk: { label: riskLabel, color: riskColor, hex: riskHex },
    willEscalate,
    breakdown: [
      { key: 'rr', icon: 'mdi-lungs', label: 'Respiratory rate', value: vitals.respiratory_rate != null ? `${vitals.respiratory_rate} /min` : '—', score: rr },
      { key: 'spo2', icon: 'mdi-water-percent', label: `SpO₂ (Scale ${vitals.scale2 ? 2 : 1})`, value: vitals.spo2 != null ? `${vitals.spo2} %` : '—', score: spo2 },
      { key: 'oxygen', icon: 'mdi-gas-cylinder', label: 'Supplemental O₂', value: vitals.oxygen || 'Room air', score: oxygen },
      { key: 'sbp', icon: 'mdi-heart-pulse', label: 'Systolic BP', value: vitals.systolic_bp != null ? `${vitals.systolic_bp} mmHg` : '—', score: sbp },
      { key: 'hr', icon: 'mdi-heart', label: 'Heart rate', value: vitals.heart_rate != null ? `${vitals.heart_rate} bpm` : '—', score: hr },
      { key: 'temp', icon: 'mdi-thermometer', label: 'Temperature', value: vitals.temperature != null ? `${vitals.temperature} °C` : '—', score: temp },
      { key: 'consciousness', icon: 'mdi-brain', label: 'Consciousness', value: vitals.consciousness || 'Alert', score: consciousness },
    ],
    clinicalPathway: total >= 7
      ? 'URGENT: Escalate to senior clinician immediately. Consider transfer to higher-acuity setting. Increase monitoring to q1h.'
      : total >= 5 || hasRed
        ? 'ALERT: Inform registered nurse / physician. Increase monitoring frequency. Review within 30 min.'
        : total >= 3
          ? 'MONITOR: Continue routine observation. Escalate if trend worsens.'
          : 'LOW: Routine monitoring per care plan.',
  }
}

export const OXYGEN_DELIVERY_MODES = [
  'Nasal cannula', 'Simple face mask', 'Venturi mask',
  'Non-rebreather mask', 'Partial rebreather mask',
  'High-flow nasal cannula (HFNC)', 'CPAP', 'BiPAP / NIV',
  'Tracheostomy mask', 'T-piece', 'Nebuliser',
  'Oxygen hood / headbox', 'Oxygen tent', 'Mechanical ventilation',
]

// ── helpers ──────────────────────────────────────────────────────
function num(v) {
  if (v === null || v === undefined || v === '') return null
  const n = Number(v)
  return Number.isNaN(n) ? null : n
}
function floatNum(v) {
  if (v === null || v === undefined || v === '') return null
  const n = Number(v)
  return Number.isNaN(n) ? null : n
}
function round(v, dp = 1) {
  const f = Math.pow(10, dp)
  return Math.round(v * f) / f
}

export function emptyForm() {
  return {
    patient: null,
    session_type: 'initial',
    status: 'completed',
    notes: '',
    arrival: { arrival_timestamp: new Date().toISOString(), arrival_mode: 'Home visit' },
    initial_survey: {
      temperature: null, systolic_bp: null, diastolic_bp: null, heart_rate: null,
      respiratory_rate: null, spo2: null, scale2: false,
      oxygen: 'Room air', oxygen_delivery: null,
      consciousness: 'Alert',
      gcs_eye: null, gcs_verbal: null, gcs_motor: null,
      glucose: null, weight: null,
      chief_concern: '', general_appearance: '', pain_score: null,
      pain_before: null, pain_after: null, last_pain_meds: null,
      reassessment_due_at: null,
      skin_integrity: 'Intact', skin_moisture: 'Normal',
      recent_falls: 0, has_catheter: false, has_central_line: false,
      has_ventilator: false, has_wound: false, allergies: '', current_meds: '',
    },
    head_to_toe: {
      oriented_time: null, oriented_place: null, oriented_person: null,
      pupil_reactive: null, speech: '', mobility_level: 'Independent',
      vision_problems: '', hearing_problems: '', oral_status: '',
      heart_rhythm: 'Normal Sinus', peripheral_pulses: 'Present',
      breath_sounds: 'Clear', resp_effort: 'Normal', on_oxygen: false,
      oxygen_flow_lpm: null, oxygen_mode: null,
      abdomen_shape: 'Soft', bowel_sounds: 'Normal',
      joint_deformities: '', any_wounds: false, wound_descriptions: [],
      wound_descriptions_raw: '',
      urinary_continence: 'Continent', bowel_continence: 'Continent',
      nutrition_assist: 'Independent', dysphagia: false,
    },
    braden: { sensory: null, moisture: null, activity: null, mobility: null, nutrition: null, friction: null },
    vte_caprini: { age: null, factors: {} },
    falls: { history_of_falls: false, secondary_dx: false, ambulatory_aid: 'none', iv_lock: false, gait: 'normal', mental_status: 'oriented' },
    must: { height_cm: null, weight_kg: null, weight_loss_percent: null, acute_no_nutrition: false },
    cam: { acute_onset: false, fluctuating: false, inattention: false, disorganized_thinking: false, altered_consciousness: false },
    pain: { score: null, before: null, after: null, last_pain_meds: null, reassessment_due_at: null },
    disease_bundles: {
      diabetes: { foot_ulcer: false, latest_bg: null, latest_bg_mmol: null, last_foot_check: null, neuropathy: false, insulin_pump: false },
      heart_failure: { daily_weight: null, edema: 'None', sob_at_rest: false, sob_on_exertion: false, orthopnea: false, jvd: false, lung_crackles: false },
    },
    catheter_bundle: {
      present: false, type: 'Foley', insert_date: null, indication: '',
      closed_system_maintained: true, bag_below_bladder: true, needs_review: false,
      next_review_date: null, daily_care_performed: false, bag_emptied: false, last_bag_change: null,
    },
    ventilator_bundle: { present: false, head_of_bed_elevated: false, daily_sbt: false, sedation_vacation: false, oral_care: false, vent_settings: '' },
    central_line_bundle: { present: false, type: 'PICC', insert_date: null, insert_site: '', dressing_change_date: null, maximal_barrier: true, hub_scrub: true, needs_removal: false, last_accessed_by: '', last_access_date: null },
    wound_bundle: { present: false, wound_details: [], turn_schedule_hours: 2, special_mattress: false, barrier_cream: false },
  }
}
