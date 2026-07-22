// Patient assessment scoring engine + option definitions.
// Dart port of nuxtfrontend/composables/useAssessmentScoring.js,
// mirroring backend/homecare/assessments.py so live form previews
// match what the server computes.

import 'dart:math';

// ── numeric helpers ──
num? _num(dynamic v) {
  if (v == null || v == '') return null;
  final n = num.tryParse(v.toString());
  return n;
}

num? _floatNum(dynamic v) => _num(v);

double _round(double v, [int dp = 1]) {
  final f = pow(10, dp);
  return (v * f).round() / f;
}

// ── Braden Scale (NPIAP) ──────────────────────────────────────────
class BradenSub {
  final String key, label;
  final int min, max;
  const BradenSub(this.key, this.label, this.min, this.max);
}

const List<BradenSub> bradenSubscales = [
  BradenSub('sensory', 'Sensory Perception', 1, 4),
  BradenSub('moisture', 'Moisture', 1, 4),
  BradenSub('activity', 'Activity', 1, 4),
  BradenSub('mobility', 'Mobility', 1, 4),
  BradenSub('nutrition', 'Nutrition', 1, 4),
  BradenSub('friction', 'Friction & Shear', 1, 3),
];

const Map<String, List<(int, String)>> bradenOptions = {
  'sensory': [
    (1, '1 — Completely limited'),
    (2, '2 — Very limited'),
    (3, '3 — Slightly limited'),
    (4, '4 — No impairment'),
  ],
  'moisture': [
    (1, '1 — Constantly moist'),
    (2, '2 — Very moist'),
    (3, '3 — Occasionally moist'),
    (4, '4 — Rarely moist'),
  ],
  'activity': [
    (1, '1 — Bedfast'),
    (2, '2 — Chairfast'),
    (3, '3 — Walks occasionally'),
    (4, '4 — Walks frequently'),
  ],
  'mobility': [
    (1, '1 — Completely immobile'),
    (2, '2 — Very limited'),
    (3, '3 — Slightly limited'),
    (4, '4 — No limitation'),
  ],
  'nutrition': [
    (1, '1 — Very poor'),
    (2, '2 — Probably inadequate'),
    (3, '3 — Adequate'),
    (4, '4 — Excellent'),
  ],
  'friction': [
    (1, '1 — Problem'),
    (2, '2 — Potential problem'),
    (3, '3 — No apparent problem'),
  ],
};

String bradenRiskLabel(num? total) {
  if (total == null) return '';
  if (total <= 9) return 'Severe Risk';
  if (total <= 12) return 'High Risk';
  if (total <= 14) return 'Moderate Risk';
  if (total <= 18) return 'Mild Risk';
  return 'No Risk';
}

Map<String, dynamic> calcBraden(Map payload) {
  final out = <String, dynamic>{};
  int valid = 0, sum = 0;
  bool allValid = true;
  for (final s in bradenSubscales) {
    final v = _num(payload[s.key]);
    out[s.key] = v;
    if (v == null) {
      allValid = false;
    } else {
      valid++;
      sum += v.toInt();
    }
  }
  out['total'] = allValid ? sum : (valid > 0 ? sum : null);
  out['risk_level'] = bradenRiskLabel(out['total']);
  return out;
}

// ── Caprini Score (VTE risk) ─────────────────────────────────────
class CapriniFactor {
  final String key, label;
  final int points;
  const CapriniFactor(this.key, this.label, this.points);
}

const List<CapriniFactor> capriniFactors = [
  CapriniFactor('age_41_60', 'Age 41–60', 1),
  CapriniFactor('age_61_74', 'Age 61–74', 2),
  CapriniFactor('age_75_plus', 'Age ≥ 75', 3),
  CapriniFactor('bmi_25_plus', 'BMI ≥ 25', 1),
  CapriniFactor('minor_surgery', 'Minor surgery (< 45 min)', 1),
  CapriniFactor('major_surgery_45min', 'Major surgery (> 45 min)', 2),
  CapriniFactor('laparoscopic_surgery_45min', 'Laparoscopic surgery (> 45 min)', 2),
  CapriniFactor('elective_major_orthopedic', 'Elective major orthopedic', 2),
  CapriniFactor('pregnancy_postpartum', 'Pregnancy / postpartum', 1),
  CapriniFactor('history_vte', 'History of VTE', 3),
  CapriniFactor('thrombophilia', 'Thrombophilia', 3),
  CapriniFactor('sepsis', 'Sepsis (< 1 mo)', 1),
  CapriniFactor('malignancy_present', 'Malignancy (present)', 2),
  CapriniFactor('malignancy_previous', 'Malignancy (previous)', 1),
  CapriniFactor('acute_mi', 'Acute MI (< 1 mo)', 1),
  CapriniFactor('congestive_heart_failure', 'Congestive heart failure (< 1 mo)', 1),
  CapriniFactor('bedbound', 'Bedbound > 72 h', 1),
  CapriniFactor('central_venous_access', 'Central venous access', 2),
  CapriniFactor('varicose_veins', 'Varicose veins', 1),
  CapriniFactor('inflammatory_bowel_disease', 'Inflammatory bowel disease', 1),
  CapriniFactor('serious_lung_disease', 'Serious lung disease', 1),
  CapriniFactor('oral_contraceptives', 'Oral contraceptives / HRT', 1),
  CapriniFactor('swollen_leg', 'Swollen leg (current)', 1),
  CapriniFactor('acute_spinal_cord_injury', 'Acute spinal cord injury (< 1 mo)', 3),
];

String capriniRiskLabel(num? points) {
  if (points == null) return '';
  if (points <= 1) return 'Low';
  if (points == 2) return 'Moderate';
  if (points <= 4) return 'High';
  return 'Very High';
}

Map<String, dynamic> calcCaprini(Map payload) {
  final factors = Map<String, bool>.from(payload['factors'] ?? const {});
  int points = 0;
  for (final f in capriniFactors) {
    if (factors[f.key] == true) points += f.points;
  }
  return {
    ...payload,
    'factors': factors,
    'points': points,
    'risk_level': capriniRiskLabel(points),
  };
}

// ── Morse Fall Scale ─────────────────────────────────────────────
const List<(String, String, int)> morseAmbulatoryAid = [
  ('none', 'None / bedrest / wheelchair / nurse-assisted', 0),
  ('crutches', 'Crutches / cane / walker', 15),
  ('furniture', 'Furniture', 30),
];
const List<(String, String, int)> morseGait = [
  ('normal', 'Normal / bedrest / immobile', 0),
  ('weak', 'Weak', 10),
  ('impaired', 'Impaired', 20),
];
const List<(String, String, int)> morseMental = [
  ('oriented', 'Oriented / knows own limitations', 0),
  ('overestimates', 'Overestimates / forgets limitations', 15),
];

String morseRiskLabel(num? score) {
  if (score == null) return '';
  if (score >= 45) return 'High';
  if (score >= 25) return 'Moderate';
  return 'Low';
}

int _morseScoreOf(List<(String, String, int)> opts, String? value) {
  for (final o in opts) {
    if (o.$1 == value) return o.$3;
  }
  return 0;
}

Map<String, dynamic> calcMorse(Map payload) {
  final items = {
    'history_of_falls': (payload['history_of_falls'] == true) ? 15 : 0,
    'secondary_dx': (payload['secondary_dx'] == true) ? 15 : 0,
    'ambulatory_aid': _morseScoreOf(morseAmbulatoryAid, payload['ambulatory_aid']?.toString()),
    'iv_lock': (payload['iv_lock'] == true) ? 15 : 0,
    'gait': _morseScoreOf(morseGait, payload['gait']?.toString()),
    'mental_status': _morseScoreOf(morseMental, payload['mental_status']?.toString()),
  };
  final score = items.values.fold<int>(0, (a, b) => a + b);
  return {...payload, ...items, 'score': score, 'risk_level': morseRiskLabel(score)};
}

// ── MUST (BAPEN malnutrition) ────────────────────────────────────
String mustRiskLabel(num? total) {
  if (total == null) return '';
  if (total >= 2) return 'High';
  if (total == 1) return 'Medium';
  return 'Low';
}

Map<String, dynamic> calcMust(Map payload) {
  final height = _num(payload['height_cm']);
  final weight = _floatNum(payload['weight_kg']);
  double? bmi;
  if (height != null && weight != null) {
    bmi = _round(weight / pow(height / 100, 2), 1);
  }
  final bmiScore = bmi == null ? null : (bmi > 20 ? 0 : (bmi >= 18.5 ? 1 : 2));
  final lossPct = _floatNum(payload['weight_loss_percent']);
  final lossScore =
      lossPct == null ? null : (lossPct < 5 ? 0 : (lossPct <= 10 ? 1 : 2));
  final acuteScore = (payload['acute_no_nutrition'] == true) ? 2 : 0;
  final scores = [bmiScore, lossScore, acuteScore].where((s) => s != null).cast<num>().toList();
  final total = scores.isEmpty ? null : scores.fold<num>(0, (a, b) => a + b);
  return {
    ...payload,
    'height_cm': height,
    'weight_kg': weight,
    'bmi': bmi,
    'bmi_score': bmiScore,
    'weight_loss_percent': lossPct,
    'loss_score': lossScore,
    'acute_score': acuteScore,
    'total_score': total,
    'risk_level': mustRiskLabel(total),
  };
}

// ── CAM (delirium) ───────────────────────────────────────────────
Map<String, dynamic> calcCam(Map payload) {
  final f1 = payload['acute_onset'] == true || payload['fluctuating'] == true;
  final f2 = payload['inattention'] == true;
  final f3 = payload['disorganized_thinking'] == true;
  final f4 = payload['altered_consciousness'] == true;
  final positive = f1 && f2 && (f3 || f4);
  return {
    ...payload,
    'acute_onset': f1,
    'inattention': f2,
    'disorganized_thinking': f3,
    'altered_consciousness': f4,
    'cam_positive': positive,
  };
}

// ── GCS (Glasgow Coma Scale) ─────────────────────────────────────
const List<(int, String)> gcsEye = [
  (4, '4 — Spontaneous'),
  (3, '3 — To speech'),
  (2, '2 — To pain'),
  (1, '1 — None'),
];
const List<(int, String)> gcsVerbal = [
  (5, '5 — Oriented'),
  (4, '4 — Confused'),
  (3, '3 — Inappropriate words'),
  (2, '2 — Incomprehensible sounds'),
  (1, '1 — None'),
];
const List<(int, String)> gcsMotor = [
  (6, '6 — Obeys commands'),
  (5, '5 — Localises to pain'),
  (4, '4 — Withdraws from pain'),
  (3, '3 — Abnormal flexion (decorticate)'),
  (2, '2 — Abnormal extension (decerebrate)'),
  (1, '1 — None'),
];

Map<String, dynamic> calcGcs(Map payload) {
  final eye = _num(payload['eye']);
  final verbal = _num(payload['verbal']);
  final motor = _num(payload['motor']);
  final total = [eye, verbal, motor].every((v) => v != null)
      ? (eye! + verbal! + motor!)
      : null;
  return {
    'eye': eye,
    'verbal': verbal,
    'motor': motor,
    'total': total,
    'category': total != null
        ? (total >= 13 ? 'Mild' : (total >= 9 ? 'Moderate' : 'Severe'))
        : '',
  };
}

// ── Pain (NRS 0–10) ──────────────────────────────────────────────
String painCategory(num? score) {
  if (score == null) return '';
  if (score == 0) return 'None';
  if (score <= 3) return 'Mild';
  if (score <= 6) return 'Moderate';
  return 'Severe';
}

Map<String, dynamic> calcPain(Map payload) {
  final score = _num(payload['score']);
  final before = _num(payload['before']);
  final after = _num(payload['after']);
  return {
    ...payload,
    'score': score,
    'before': before,
    'after': after,
    'score_category': score != null ? painCategory(score) : '',
    'pain_reduced': (before != null && after != null) ? (before - after) : null,
    'reassessment_due': payload['reassessment_due_at'],
  };
}

// ── Disease-Specific Bundles ─────────────────────────────────────
const List<String> edemaLevels = [
  'None', 'Mild (1+)', 'Moderate (2+)', 'Severe (3+)', 'Pitting (4+)'
];

Map<String, dynamic> calcDiabetesBundle(Map payload) => {
      'foot_ulcer': payload['foot_ulcer'] == true,
      'latest_bg': _floatNum(payload['latest_bg']),
      'latest_bg_mmol': _floatNum(payload['latest_bg_mmol']),
      'last_foot_check': payload['last_foot_check'],
      'neuropathy': payload['neuropathy'] == true,
      'insulin_pump': payload['insulin_pump'] == true,
    };

Map<String, dynamic> calcHeartFailureBundle(Map payload) => {
      'daily_weight': _floatNum(payload['daily_weight']),
      'edema': payload['edema'] ?? 'None',
      'sob_at_rest': payload['sob_at_rest'] == true,
      'sob_on_exertion': payload['sob_on_exertion'] == true,
      'orthopnea': payload['orthopnea'] == true,
      'jvd': payload['jvd'] == true,
      'lung_crackles': payload['lung_crackles'] == true,
    };

// ── Catheter / Central line bundles ─────────────────────────────
const List<String> catheterTypes = ['Foley', 'Suprapubic', 'Condom', 'Intermittent'];
const List<String> lineTypes = [
  'PICC', 'Hickman', 'CVC (non-tunneled)', 'Port-a-cath', 'Midline', 'Dialysis catheter'
];

Map<String, dynamic> calcCatheterBundle(Map payload) => {
      'present': payload['present'] == true,
      'type': payload['type'] ?? 'Foley',
      'insert_date': payload['insert_date'],
      'indication': payload['indication'] ?? '',
      'closed_system_maintained': payload['closed_system_maintained'] != false,
      'bag_below_bladder': payload['bag_below_bladder'] != false,
      'needs_review': payload['needs_review'] == true,
      'next_review_date': payload['next_review_date'],
      'daily_care_performed': payload['daily_care_performed'] == true,
      'bag_emptied': payload['bag_emptied'] == true,
      'last_bag_change': payload['last_bag_change'],
    };

// ── Overall risk aggregation (mirrors assessments.aggregate_risk) ──
String aggregateRisk(
    num? bradenTotal,
    num? capriniPoints,
    num? morseScore,
    num? mustTotal,
    bool camPositive,
    num? painScore) {
  String level = 'low';
  const rank = {'low': 0, 'medium': 1, 'high': 2, 'critical': 3};
  void bump(String l) {
    if (rank[l]! > rank[level]!) level = l;
  }

  if (bradenTotal != null && bradenTotal <= 12) {
    bump('high');
  } else if (bradenTotal != null && bradenTotal <= 18) {
    bump('medium');
  }
  if (capriniPoints != null && capriniPoints >= 5) {
    bump('critical');
  } else if (capriniPoints != null && capriniPoints >= 3) {
    bump('high');
  }
  if (morseScore != null && morseScore >= 45) bump('high');
  if (mustTotal != null && mustTotal >= 2) bump('high');
  if (camPositive) bump('high');
  if (painScore != null && painScore >= 7) bump('high');
  return level;
}

// ── Alert generation (mirrors assessments.generate_alerts) ───────
class AssessmentAlert {
  final String code, category, severity, title, detail;
  final String? recommendation;
  const AssessmentAlert({
    required this.code,
    required this.category,
    required this.severity,
    required this.title,
    required this.detail,
    this.recommendation,
  });
}

List<AssessmentAlert> generateAlerts(Map session) {
  final alerts = <AssessmentAlert>[];
  final bt = _num(session['braden_total']);
  final bradenRisk = (session['braden']?['risk_level'] ?? '').toString();
  if (bt != null && bt <= 18) {
    final sev = bt <= 12 ? 'critical' : (bt <= 14 ? 'high' : 'warning');
    alerts.add(AssessmentAlert(
      code: 'BRADEN_RISK',
      category: 'pressure',
      severity: sev,
      title: 'Pressure injury risk',
      detail:
          'Braden total $bt ($bradenRisk). Implement pressure-relief measures and skin care bundle.',
      recommendation:
          'Reposition every 2 h, pressure-relieving mattress, skin moisture management (NPIAP).',
    ));
  }
  final cp = _num(session['caprini_points']);
  final capriniRisk = (session['vte_caprini']?['risk_level'] ?? '').toString();
  if (cp != null && cp >= 3) {
    final sev = cp >= 5 ? 'critical' : 'high';
    alerts.add(AssessmentAlert(
      code: 'VTE_RISK',
      category: 'vte',
      severity: sev,
      title: 'Venous thromboembolism risk',
      detail:
          'Caprini score $cp ($capriniRisk). Consider pharmacological / mechanical prophylaxis.',
      recommendation:
          'Assess for anticoagulation or compression stockings per physician order.',
    ));
  }
  final ms = _num(session['morse_score']);
  final morseRisk = (session['falls']?['risk_level'] ?? '').toString();
  if (ms != null && ms >= 45) {
    alerts.add(AssessmentAlert(
      code: 'FALLS_RISK',
      category: 'falls',
      severity: 'high',
      title: 'High falls risk',
      detail: 'Morse score $ms ($morseRisk). Implement falls-prevention care plan.',
      recommendation:
          'Bed alarm, non-slip footwear, toileting schedule, review sedating medications.',
    ));
  }
  final mt = _num(session['must_score']);
  final mustRisk = (session['must']?['risk_level'] ?? '').toString();
  if (mt != null && mt >= 2) {
    alerts.add(AssessmentAlert(
      code: 'MALNUTRITION',
      category: 'nutrition',
      severity: 'high',
      title: 'Malnutrition risk',
      detail: 'MUST score $mt ($mustRisk). Refer to dietitian for nutritional support.',
      recommendation:
          'Dietitian referral, oral nutritional supplements, reassess per care setting.',
    ));
  }
  if (session['cam_positive'] == true) {
    alerts.add(AssessmentAlert(
      code: 'DELIRIUM',
      category: 'delirium',
      severity: 'critical',
      title: 'Delirium detected (CAM positive)',
      detail:
          'CAM is positive — acute confusional state. Alert physician for medical review.',
      recommendation:
          'Physician review, identify and treat underlying cause, orient patient, address sensory deficits.',
    ));
  }
  final ps = _num(session['pain_score']);
  if (ps != null && ps >= 7) {
    final sev = ps >= 9 ? 'critical' : 'high';
    alerts.add(AssessmentAlert(
      code: 'SEVERE_PAIN',
      category: 'pain',
      severity: sev,
      title: 'Severe pain',
      detail: 'Pain score $ps/10. Provide analgesia and reassess in 30–60 min.',
      recommendation:
          'Administer prescribed analgesia, reassess 30–60 min post-intervention.',
    ));
  }
  final cb = (session['catheter_bundle'] ?? {}) as Map;
  if (cb['present'] == true && cb['needs_review'] == true) {
    alerts.add(AssessmentAlert(
      code: 'CATHETER_REVIEW',
      category: 'device',
      severity: 'warning',
      title: 'Catheter removal review',
      detail:
          'Catheter may no longer be needed — review indication for prompt removal (CDC).',
      recommendation:
          'Assess daily whether catheter is still indicated; remove ASAP when no longer needed.',
    ));
  }
  final clb = (session['central_line_bundle'] ?? {}) as Map;
  if (clb['present'] == true && clb['needs_removal'] == true) {
    alerts.add(AssessmentAlert(
      code: 'LINE_REMOVAL',
      category: 'device',
      severity: 'warning',
      title: 'Central line removal review',
      detail:
          'Central line may no longer be needed — review for prompt removal (CDC CLABSI).',
      recommendation: 'Remove promptly when no longer needed to prevent CLABSI.',
    ));
  }
  final db = (session['disease_bundles'] ?? {}) as Map;
  if (db['diabetes']?['foot_ulcer'] == true) {
    alerts.add(AssessmentAlert(
      code: 'DIABETIC_FOOT_ULCER',
      category: 'other',
      severity: 'high',
      title: 'Diabetic foot ulcer detected',
      detail:
          'Foot inspection positive for ulcer. Initiate wound care and refer to podiatry.',
      recommendation:
          'Daily foot inspection, offloading, wound care, blood glucose optimisation.',
    ));
  }
  if (db['heart_failure']?['sob_at_rest'] == true ||
      db['heart_failure']?['orthopnea'] == true) {
    alerts.add(AssessmentAlert(
      code: 'HEART_FAILURE_DECOMPENSATION',
      category: 'other',
      severity: 'high',
      title: 'Heart failure decompensation signs',
      detail:
          'Patient reports dyspnoea at rest or orthopnea. Assess volume status and notify physician.',
      recommendation:
          'Daily weight, fluid restriction, adjust diuretics, monitor for pulmonary oedema.',
    ));
  }
  return alerts;
}

// ── Full session recalculation ───────────────────────────────────
Map<String, dynamic> recalcSession(Map form) {
  final braden = calcBraden(Map<String, dynamic>.from(form['braden'] ?? const {}));
  final vteCaprini =
      calcCaprini(Map<String, dynamic>.from(form['vte_caprini'] ?? const {}));
  final falls = calcMorse(Map<String, dynamic>.from(form['falls'] ?? const {}));
  final must = calcMust(Map<String, dynamic>.from(form['must'] ?? const {}));
  final cam = calcCam(Map<String, dynamic>.from(form['cam'] ?? const {}));
  final pain = calcPain(Map<String, dynamic>.from(form['pain'] ?? const {}));
  final db = (form['disease_bundles'] ?? {}) as Map;
  final diabetes = calcDiabetesBundle(Map<String, dynamic>.from(db['diabetes'] ?? const {}));
  final heartFailure =
      calcHeartFailureBundle(Map<String, dynamic>.from(db['heart_failure'] ?? const {}));
  return {
    ...form,
    'braden': braden,
    'vte_caprini': vteCaprini,
    'falls': falls,
    'must': must,
    'cam': cam,
    'pain': pain,
    'braden_total': braden['total'],
    'caprini_points': vteCaprini['points'],
    'morse_score': falls['score'],
    'must_score': must['total_score'],
    'pain_score': pain['score'],
    'cam_positive': cam['cam_positive'],
    'overall_risk_level': aggregateRisk(
      braden['total'], vteCaprini['points'], falls['score'],
      must['total_score'], cam['cam_positive'] == true, pain['score'],
    ),
    'alerts_triggered': generateAlerts({
      'braden_total': braden['total'],
      'caprini_points': vteCaprini['points'],
      'morse_score': falls['score'],
      'must_score': must['total_score'],
      'cam_positive': cam['cam_positive'],
      'pain_score': pain['score'],
      'braden': braden,
      'vte_caprini': vteCaprini,
      'falls': falls,
      'must': must,
      'catheter_bundle': form['catheter_bundle'] ?? const {},
      'central_line_bundle': form['central_line_bundle'] ?? const {},
      'disease_bundles': {'diabetes': diabetes, 'heart_failure': heartFailure},
    }),
  };
}

// ── Shared option lists for the form ─────────────────────────────
const List<String> arrivalModes = ['Home visit', 'Clinic visit', 'Ambulance', 'Transfer', 'Telehealth'];
const List<String> avpu = ['Alert', 'Verbal', 'Pain', 'Unresponsive'];
const List<String> skinIntegrity = ['Intact', 'Redness', 'Ulcer', 'Other'];
const List<String> skinMoisture = ['Dry', 'Normal', 'Excessive'];
const List<String> mobilityLevels = ['Bedbound', 'Walks with help', 'Independent'];
const List<String> heartRhythms = ['Normal Sinus', 'AFib', 'Other'];
const List<String> peripheralPulses = ['Present', 'Weak', 'Absent'];
const List<String> breathSounds = ['Clear', 'Crackles', 'Wheezes', 'Other'];
const List<String> respEfforts = ['Normal', 'Laboured'];
const List<String> oxygenModes = [
  'Nasal cannula', 'Simple face mask', 'Venturi mask', 'Non-rebreather mask',
  'High-flow nasal cannula', 'CPAP', 'BiPAP / NIV', 'Tracheostomy mask'
];
const List<String> abdomenShapes = ['Soft', 'Distended'];
const List<String> bowelSounds = ['Normal', 'Hypoactive', 'Hyperactive'];
const List<String> continence = ['Continent', 'Incontinent'];
const List<String> nutritionAssist = ['Independent', 'Needs Help'];

const List<String> oxygenDeliveryModes = [
  'Nasal cannula', 'Simple face mask', 'Venturi mask',
  'Non-rebreather mask', 'Partial rebreather mask',
  'High-flow nasal cannula (HFNC)', 'CPAP', 'BiPAP / NIV',
  'Tracheostomy mask', 'T-piece', 'Nebuliser',
  'Oxygen hood / headbox', 'Oxygen tent', 'Mechanical ventilation',
];

const List<(String, String)> sessionTypes = [
  ('initial', 'Initial Assessment'),
  ('head_to_toe', 'Head-to-Toe Baseline'),
  ('reassessment', 'Reassessment'),
  ('admission', 'Admission'),
  ('discharge', 'Discharge'),
];

// ── NEWS2 (RCP 2017) Vital Signs Scoring ──────────────────────────
int scoreRR(num? v) {
  if (v == null) return 0;
  if (v <= 8) return 3;
  if (v <= 11) return 1;
  if (v <= 20) return 0;
  if (v <= 24) return 2;
  return 3;
}

int scoreSpO2Scale1(num? v) {
  if (v == null) return 0;
  if (v <= 91) return 3;
  if (v <= 93) return 2;
  if (v <= 95) return 1;
  return 0;
}

int scoreSpO2Scale2(num? v, bool onO2) {
  if (v == null) return 0;
  if (v <= 83) return 3;
  if (v <= 85) return 2;
  if (v <= 87) return 1;
  if (v <= 92) return 0;
  if (!onO2) return 0;
  if (v <= 94) return 1;
  if (v <= 96) return 2;
  return 3;
}

int scoreOxygen(String? o) => o == 'Supplemental O₂' ? 2 : 0;

int scoreSBP(num? v) {
  if (v == null) return 0;
  if (v <= 90) return 3;
  if (v <= 100) return 2;
  if (v <= 110) return 1;
  if (v <= 219) return 0;
  return 3;
}

int scoreHR(num? v) {
  if (v == null) return 0;
  if (v <= 40) return 3;
  if (v <= 50) return 1;
  if (v <= 90) return 0;
  if (v <= 110) return 1;
  if (v <= 130) return 2;
  return 3;
}

int scoreTemp(num? v) {
  if (v == null) return 0;
  if (v <= 35.0) return 3;
  if (v <= 36.0) return 1;
  if (v <= 38.0) return 0;
  if (v <= 39.0) return 1;
  return 2;
}

int scoreConsciousness(String? c) =>
    (c == 'A' || c == 'Alert') ? 0 : 3;

class News2Result {
  final int rr, spo2, oxygen, sbp, hr, temp, consciousness, total;
  final bool hasRed, willEscalate;
  final String riskLabel;
  final String clinicalPathway;
  const News2Result({
    required this.rr,
    required this.spo2,
    required this.oxygen,
    required this.sbp,
    required this.hr,
    required this.temp,
    required this.consciousness,
    required this.total,
    required this.hasRed,
    required this.willEscalate,
    required this.riskLabel,
    required this.clinicalPathway,
  });
}

News2Result calcNews2(Map vitals) {
  final rr = scoreRR(_num(vitals['respiratory_rate']));
  final onO2 = vitals['oxygen'] == 'Supplemental O₂';
  final spo2 = vitals['scale2'] == true
      ? scoreSpO2Scale2(_num(vitals['spo2']), onO2)
      : scoreSpO2Scale1(_num(vitals['spo2']));
  final oxygen = scoreOxygen(vitals['oxygen']?.toString());
  final sbp = scoreSBP(_num(vitals['systolic_bp']));
  final hr = scoreHR(_num(vitals['heart_rate']));
  final temp = scoreTemp(_num(vitals['temperature']));
  final consciousness = scoreConsciousness(vitals['consciousness']?.toString());
  final total = rr + spo2 + oxygen + sbp + hr + temp + consciousness;
  final hasRed = [rr, spo2, oxygen, sbp, hr, temp, consciousness].any((s) => s >= 3);
  String riskLabel;
  if (total == 0) {
    riskLabel = 'Low';
  } else if (total <= 4 && !hasRed) {
    riskLabel = 'Low – Medium';
  } else if (total <= 6 || hasRed) {
    riskLabel = 'Medium';
  } else {
    riskLabel = 'High';
  }
  final willEscalate = total >= 5 || hasRed;
  final clinicalPathway = total >= 7
      ? 'URGENT: Escalate to senior clinician immediately.'
      : (total >= 5 || hasRed
          ? 'ALERT: Inform RN / physician. Review within 30 min.'
          : (total >= 3
              ? 'MONITOR: Continue routine observation.'
              : 'LOW: Routine monitoring per care plan.'));
  return News2Result(
    rr: rr,
    spo2: spo2,
    oxygen: oxygen,
    sbp: sbp,
    hr: hr,
    temp: temp,
    consciousness: consciousness,
    total: total,
    hasRed: hasRed,
    willEscalate: willEscalate,
    riskLabel: riskLabel,
    clinicalPathway: clinicalPathway,
  );
}

// ── RISK_META ────────────────────────────────────────────────────
class RiskMeta {
  final String label, hex;
  const RiskMeta({required this.label, required this.hex});
}

const Map<String, RiskMeta> riskMeta = {
  'low': RiskMeta(label: 'Low', hex: '#059669'),
  'medium': RiskMeta(label: 'Medium', hex: '#0284C7'),
  'high': RiskMeta(label: 'High', hex: '#d97706'),
  'critical': RiskMeta(label: 'Critical', hex: '#b91c1c'),
};

// ── emptyForm ────────────────────────────────────────────────────
Map<String, dynamic> emptyForm() {
  return {
    'patient': null,
    'session_type': 'initial',
    'status': 'completed',
    'notes': '',
    'arrival': {
      'arrival_timestamp': DateTime.now().toUtc().toIso8601String(),
      'arrival_mode': 'Home visit',
    },
    'initial_survey': {
      'temperature': null, 'systolic_bp': null, 'diastolic_bp': null,
      'heart_rate': null, 'respiratory_rate': null, 'spo2': null,
      'scale2': false, 'oxygen': 'Room air', 'oxygen_delivery': null,
      'consciousness': 'Alert', 'gcs_eye': null, 'gcs_verbal': null,
      'gcs_motor': null, 'glucose': null, 'weight': null,
      'chief_concern': '', 'general_appearance': '', 'pain_score': null,
      'pain_before': null, 'pain_after': null, 'last_pain_meds': null,
      'reassessment_due_at': null, 'skin_integrity': 'Intact',
      'skin_moisture': 'Normal', 'recent_falls': 0,
      'has_catheter': false, 'has_central_line': false,
      'has_ventilator': false, 'has_wound': false,
      'allergies': '', 'current_meds': '',
    },
    'head_to_toe': {
      'oriented_time': null, 'oriented_place': null, 'oriented_person': null,
      'pupil_reactive': null, 'speech': '', 'mobility_level': 'Independent',
      'vision_problems': '', 'hearing_problems': '', 'oral_status': '',
      'heart_rhythm': 'Normal Sinus', 'peripheral_pulses': 'Present',
      'breath_sounds': 'Clear', 'resp_effort': 'Normal', 'on_oxygen': false,
      'oxygen_flow_lpm': null, 'oxygen_mode': null,
      'abdomen_shape': 'Soft', 'bowel_sounds': 'Normal',
      'joint_deformities': '', 'any_wounds': false,
      'wound_descriptions': <Map<String, String>>[],
      'wound_descriptions_raw': '',
      'urinary_continence': 'Continent', 'bowel_continence': 'Continent',
      'nutrition_assist': 'Independent', 'dysphagia': false,
    },
    'braden': {
      'sensory': null, 'moisture': null, 'activity': null,
      'mobility': null, 'nutrition': null, 'friction': null,
    },
    'vte_caprini': {'age': null, 'factors': <String, bool>{}},
    'falls': {
      'history_of_falls': false, 'secondary_dx': false,
      'ambulatory_aid': 'none', 'iv_lock': false,
      'gait': 'normal', 'mental_status': 'oriented',
    },
    'must': {
      'height_cm': null, 'weight_kg': null,
      'weight_loss_percent': null, 'acute_no_nutrition': false,
    },
    'cam': {
      'acute_onset': false, 'fluctuating': false, 'inattention': false,
      'disorganized_thinking': false, 'altered_consciousness': false,
    },
    'pain': {
      'score': null, 'before': null, 'after': null,
      'last_pain_meds': null, 'reassessment_due_at': null,
    },
    'disease_bundles': {
      'diabetes': {
        'foot_ulcer': false, 'latest_bg': null, 'latest_bg_mmol': null,
        'last_foot_check': null, 'neuropathy': false, 'insulin_pump': false,
      },
      'heart_failure': {
        'daily_weight': null, 'edema': 'None', 'sob_at_rest': false,
        'sob_on_exertion': false, 'orthopnea': false,
        'jvd': false, 'lung_crackles': false,
      },
    },
    'catheter_bundle': {
      'present': false, 'type': 'Foley', 'insert_date': null, 'indication': '',
      'closed_system_maintained': true, 'bag_below_bladder': true,
      'needs_review': false, 'next_review_date': null,
      'daily_care_performed': false, 'bag_emptied': false, 'last_bag_change': null,
    },
    'ventilator_bundle': {
      'present': false, 'head_of_bed_elevated': false, 'daily_sbt': false,
      'sedation_vacation': false, 'oral_care': false, 'vent_settings': '',
    },
    'central_line_bundle': {
      'present': false, 'type': 'PICC', 'insert_date': null, 'insert_site': '',
      'dressing_change_date': null, 'maximal_barrier': true, 'hub_scrub': true,
      'needs_removal': false, 'last_accessed_by': '', 'last_access_date': null,
    },
    'wound_bundle': {
      'present': false, 'wound_details': <Map<String, String>>[],
      'turn_schedule_hours': 2, 'special_mattress': false, 'barrier_cream': false,
    },
  };
}
