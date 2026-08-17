/**
 * NEWS2 (National Early Warning Score) calculation
 * Based on RR, SpO2 (airway), SBP, Pulse, Consciousness (AVPU), Temperature
 */

export function calculateNEWS2(vitals) {
  if (!vitals) return 0
  let score = 0

  // Respiratory Rate
  const rr = Number(vitals.respiratory_rate || vitals.rr || 0)
  if (rr >= 25) score += 3
  else if (rr >= 21) score += 2
  else if (rr <= 8 || (rr >= 12 && rr <= 20)) score += rr <= 8 ? 3 : 0
  else if (rr === 0) score += 0
  else if (rr >= 9 && rr <= 11) score += 1

  // SpO2 (Scale 1 — air)
  const spo2 = Number(vitals.oxygen_saturation || vitals.spo2 || 0)
  if (spo2 === 0) score += 0
  else if (spo2 <= 91) score += 3
  else if (spo2 <= 93) score += 2
  else if (spo2 >= 94 && spo2 <= 95) score += 1
  else if (spo2 >= 96 && spo2 <= 100) score += 0

  // Systolic BP
  const sbp = Number(vitals.bp_systolic || vitals.systolic || vitals.bp?.systolic || 0)
  if (sbp === 0) score += 0
  else if (sbp <= 90) score += 3
  else if (sbp <= 100) score += 2
  else if (sbp <= 110) score += 1
  else if (sbp >= 220) score += 3

  // Pulse
  const pulse = Number(vitals.heart_rate || vitals.pulse || 0)
  if (pulse === 0) score += 0
  else if (pulse <= 40) score += 3
  else if (pulse <= 50) score += 1
  else if (pulse >= 131) score += 3
  else if (pulse >= 111) score += 2
  else if (pulse >= 91 && pulse <= 110) score += 1

  // Consciousness (AVPU)
  const avpu = vitals.avpu || 'alert'
  if (avpu === 'unresponsive' || avpu === 'pain') score += 3
  else if (avpu === 'voice') score += 3

  // Temperature
  const temp = Number(vitals.temperature || 0)
  if (temp === 0) score += 0
  else if (temp <= 35) score += 3
  else if (temp >= 39.1) score += 2
  else if (temp >= 38.1) score += 1
  else if (temp >= 36.1 && temp <= 38) score += 0
  else if (temp >= 35.1 && temp <= 36) score += 1

  return score
}

export function news2Category(score) {
  if (score === 0) return { label: 'Low', color: 'success', variant: 'tonal', description: 'Normal range — routine monitoring' }
  if (score >= 1 && score <= 4) return { label: 'Low-Medium', color: 'warning', variant: 'tonal', description: 'Ward-based response — RN review' }
  if (score >= 5 && score <= 6) return { label: 'Medium', color: 'orange', variant: 'tonal', description: 'Urgent ward-based review' }
  if (score >= 7) return { label: 'High', color: 'error', variant: 'flat', description: 'Emergency assessment — ICU/critical care' }
  return { label: '—', color: 'grey', variant: 'tonal', description: '' }
}

export function suggestedESIFromNEWS2(score) {
  if (score >= 7) return 1  // Resuscitation
  if (score >= 5) return 2  // Emergent
  if (score >= 1) return 3  // Urgent
  return 4                  // Less Urgent
}

export function calculateBMI(weightKg, heightCm) {
  if (!weightKg || !heightCm) return null
  const m = heightCm / 100
  if (m === 0) return null
  return +(weightKg / (m * m)).toFixed(1)
}

export function bmiCategory(bmi) {
  if (!bmi) return ''
  if (bmi < 18.5) return { label: 'Underweight', color: 'info' }
  if (bmi < 25) return { label: 'Normal', color: 'success' }
  if (bmi < 30) return { label: 'Overweight', color: 'warning' }
  return { label: 'Obese', color: 'error' }
}

export function news2Color(score) {
  if (score >= 7) return 'error'
  if (score >= 5) return 'orange'
  if (score >= 1) return 'warning'
  return 'success'
}

export function esiColor(level) {
  return ['', 'error', 'orange', 'warning', 'info', 'success'][level] || 'grey'
}

export function esiLabel(level) {
  return ['', 'Resuscitation', 'Emergent', 'Urgent', 'Less Urgent', 'Non-Urgent'][level] || '—'
}
