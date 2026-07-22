import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api.dart';
import '../../providers/auth_provider.dart';
import 'assessments_screen.dart' show RecordAssessmentSheet;
import 'bundle_assessments_screen.dart'
    show BundleAssessmentSheet, BundleScale, kBundleScales;
import 'docs_tab.dart' show HomecareDocsTab;
import 'dose_action_sheet.dart';
import 'hc_common.dart';
import 'vitals_screen.dart'
    show RecordVitalsSheet, news2Color, calcNews2, News2Result;

// ── Providers (per patient id) ──
final _summaryProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, int>((ref, id) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/homecare/patients/$id/care-summary/');
  return res.data as Map<String, dynamic>;
});

final _pcVitalsProvider =
    FutureProvider.autoDispose.family<List, int>((ref, id) async {
  final dio = ref.read(dioProvider);
  final res =
      await dio.get('/homecare/vitals/', queryParameters: {'patient': id});
  final data = res.data;
  return data is List ? data : ((data?['results'] as List?) ?? []);
});

final _pcDosesProvider =
    FutureProvider.autoDispose.family<List, int>((ref, id) async {
  final dio = ref.read(dioProvider);
  try {
    await dio.post('/homecare/doses/auto_expire/');
  } catch (_) {}
  return hcFetchAll(ref, '/homecare/doses/',
      params: {'schedule__patient': id, 'page_size': 200});
});

final _pcNotesProvider =
    FutureProvider.autoDispose.family<List, int>((ref, id) async {
  return hcFetchAll(ref, '/homecare/notes/',
      params: {'patient': id, 'page_size': 100});
});

final _pcPlansProvider =
    FutureProvider.autoDispose.family<List, int>((ref, id) async {
  return hcFetchAll(ref, '/homecare/treatment-plans/',
      params: {'patient': id, 'page_size': 50});
});

final _pcLinesProvider =
    FutureProvider.autoDispose.family<List, int>((ref, id) async {
  return hcFetchAll(ref, '/homecare/drains-lines/',
      params: {'patient': id, 'active': 'true', 'page_size': 100});
});

// ── Assessment worklist (draft assessment-sessions) ──
final _pcWorklistProvider =
    FutureProvider.autoDispose.family<List, int>((ref, id) async {
  return hcFetchAll(ref, '/homecare/assessment-sessions/',
      params: {'patient': id, 'status': 'draft', 'page_size': 100});
});

// Per-type assessment history (mirrors web ASSESSMENT_TYPE_ENDPOINTS)
final _pcAssessHistoryProvider =
    FutureProvider.autoDispose.family<List, (int, String)>((ref, key) async {
  final (pid, typeKey) = key;
  final ep = _assessTypeEndpoints[typeKey];
  if (ep == null) return const [];
  return hcFetchAll(ref, ep,
      params: {'patient': pid, 'ordering': '-assessed_at', 'page_size': 50});
});

/// Assessment component definition (mirrors nuxtfrontend ASSESSMENT_TYPES).
class _AssessType {
  final String key;
  final String? scaleKey; // → RecordAssessmentSheet
  final String? bundleKey; // → BundleAssessmentSheet
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final String frequency;
  final List<String> freqOptions;
  const _AssessType({
    required this.key,
    this.scaleKey,
    this.bundleKey,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.frequency,
    required this.freqOptions,
  });
}

const _assessTypes = <_AssessType>[
  _AssessType(key: 'braden', scaleKey: 'braden', label: 'Braden Scale', description: 'Pressure injury risk', icon: Icons.airline_seat_flat_rounded, color: hcAmber, frequency: 'Every 12 hrs', freqOptions: ['Every 4 hrs', 'Every 6 hrs', 'Every 8 hrs', 'Every 12 hrs', 'Every 24 hrs']),
  _AssessType(key: 'caprini', scaleKey: 'caprini', label: 'Caprini Score', description: 'VTE risk assessment', icon: Icons.bloodtype_outlined, color: hcRed, frequency: 'Every 24 hrs', freqOptions: ['Every 12 hrs', 'Every 24 hrs', 'Every 48 hrs']),
  _AssessType(key: 'morse', scaleKey: 'morse', label: 'Morse Fall Scale', description: 'Fall risk screening', icon: Icons.elderly_rounded, color: hcRose, frequency: 'Every 24 hrs', freqOptions: ['Every 12 hrs', 'Every 24 hrs', 'Every 48 hrs']),
  _AssessType(key: 'must', scaleKey: 'must', label: 'MUST', description: 'Malnutrition screening', icon: Icons.restaurant_rounded, color: hcGreen, frequency: 'Every 24 hrs', freqOptions: ['Every 24 hrs', 'Every 48 hrs', 'Every week']),
  _AssessType(key: 'cam', scaleKey: 'cam', label: 'CAM (Confusion)', description: 'Delirium assessment', icon: Icons.psychology_rounded, color: hcPurple, frequency: 'Every 24 hrs', freqOptions: ['Every 12 hrs', 'Every 24 hrs', 'Every 48 hrs']),
  _AssessType(key: 'diabetes_bundle', scaleKey: 'diabetes_bundle', label: 'Diabetes Bundle', description: 'Glucose monitoring & insulin', icon: Icons.bloodtype_rounded, color: hcBlue, frequency: 'Every 12 hrs', freqOptions: ['Every 4 hrs', 'Every 6 hrs', 'Every 8 hrs', 'Every 12 hrs', 'Every 24 hrs']),
  _AssessType(key: 'hf_bundle', scaleKey: 'hf_bundle', label: 'Heart Failure Bundle', description: 'Fluid status, weight, SpO₂', icon: Icons.favorite_rounded, color: hcRose, frequency: 'Every 12 hrs', freqOptions: ['Every 8 hrs', 'Every 12 hrs', 'Every 24 hrs']),
  _AssessType(key: 'skin_care', scaleKey: 'skin_care', label: 'Skin Care Bundle', description: 'q4h pressure-care protocol', icon: Icons.healing_rounded, color: hcRed, frequency: 'Every 4 hrs', freqOptions: ['Every 2 hrs', 'Every 4 hrs', 'Every 6 hrs', 'Every 8 hrs']),
  _AssessType(key: 'pain_reassess', scaleKey: 'pain', label: 'Pain Reassessment', description: 'Post-intervention pain score', icon: Icons.sick_rounded, color: hcRed, frequency: 'Every 8 hrs', freqOptions: ['Every 4 hrs', 'Every 6 hrs', 'Every 8 hrs', 'Every 12 hrs']),
  _AssessType(key: 'gcs', scaleKey: 'gcs', label: 'GCS', description: 'Level of consciousness', icon: Icons.visibility_rounded, color: hcIndigo, frequency: 'Every 12 hrs', freqOptions: ['Every 4 hrs', 'Every 6 hrs', 'Every 12 hrs', 'Every 24 hrs']),
  _AssessType(key: 'pivc', scaleKey: 'pivc', label: 'PIVC Assessment', description: 'Peripheral IV — VIP score', icon: Icons.colorize_rounded, color: hcIndigo, frequency: 'Every 8 hrs', freqOptions: ['Every 4 hrs', 'Every 6 hrs', 'Every 8 hrs', 'Every 12 hrs', 'Every 24 hrs']),
  _AssessType(key: 'enteral_feeding', bundleKey: 'enteral_feeding', label: 'Enteral Feeding', description: 'Enteral device maintenance', icon: Icons.dining_rounded, color: hcAmber, frequency: 'Every 8 hrs', freqOptions: ['Every 4 hrs', 'Every 6 hrs', 'Every 8 hrs', 'Every 12 hrs', 'Every 24 hrs']),
  _AssessType(key: 'urinary_catheter', bundleKey: 'urinary_catheter', label: 'Urinary Catheter', description: 'CAUTI prevention bundle', icon: Icons.water_drop_rounded, color: hcTeal, frequency: 'Every 24 hrs', freqOptions: ['Every 8 hrs', 'Every 12 hrs', 'Every 24 hrs', 'Every 48 hrs']),
  _AssessType(key: 'artificial_airway', bundleKey: 'artificial_airway', label: 'Artificial Airway', description: 'Tracheostomy & VAP bundle', icon: Icons.air_rounded, color: Color(0xFF455A64), frequency: 'Every 8 hrs', freqOptions: ['Every 4 hrs', 'Every 6 hrs', 'Every 8 hrs', 'Every 12 hrs', 'Every 24 hrs']),
];

const _assessTypeEndpoints = <String, String>{
  'braden': '/homecare/braden-assessments/',
  'caprini': '/homecare/caprini-assessments/',
  'morse': '/homecare/morse-assessments/',
  'must': '/homecare/must-assessments/',
  'cam': '/homecare/cam-assessments/',
  'pain_reassess': '/homecare/pain-assessments/',
  'skin_care': '/homecare/skin-care-assessments/',
  'gcs': '/homecare/gcs-assessments/',
  'diabetes_bundle': '/homecare/diabetes-bundle-assessments/',
  'hf_bundle': '/homecare/hf-bundle-assessments/',
  'pivc': '/homecare/pivc-assessments/',
  'enteral_feeding': '/homecare/enteral-feeding-assessments/',
  'urinary_catheter': '/homecare/urinary-catheter-assessments/',
  'artificial_airway': '/homecare/artificial-airway-assessments/',
};

_AssessType? _assessType(String key) {
  for (final t in _assessTypes) {
    if (t.key == key) return t;
  }
  return null;
}

int _freqMs(String freq) {
  if (freq.isEmpty) return 1 << 30;
  final m = freq.toLowerCase();
  if (m.contains('once')) return 1 << 30;
  final num =
      int.tryParse(RegExp(r'\d+').firstMatch(m)?.group(0) ?? '') ?? 4;
  if (m.contains('hour')) return num * 3600000;
  if (m.contains('day')) return num * 86400000;
  if (m.contains('week')) return num * 604800000;
  return num * 12 * 3600000;
}

class _AssessStatus {
  final String label;
  final Color color;
  final IconData icon;
  final int? progressPct;
  final Color progressColor;
  const _AssessStatus(
      this.label, this.color, this.icon, this.progressPct, this.progressColor);
}

_AssessStatus _computeStatus(DateTime? lastDone, String frequency) {
  if (lastDone == null) {
    return const _AssessStatus('Not started', hcSlate,
        Icons.radio_button_unchecked_rounded, null, hcGreen);
  }
  final freq = _freqMs(frequency);
  if (freq >= 1 << 30) {
    return const _AssessStatus(
        'Done', hcGreen, Icons.check_circle_rounded, null, hcGreen);
  }
  final elapsed =
      DateTime.now().millisecondsSinceEpoch - lastDone.millisecondsSinceEpoch;
  final pct = (elapsed / freq * 100).clamp(0, 100).round();
  if (elapsed >= freq) {
    return _AssessStatus('Overdue', hcRed, Icons.error_rounded, pct, hcRed);
  } else if (elapsed >= freq * 0.7) {
    return _AssessStatus(
        'Due soon', hcAmber, Icons.access_time_rounded, pct, hcAmber);
  }
  return _AssessStatus(
      'On track', hcTeal, Icons.hourglass_top_rounded, pct, hcGreen);
}

(String, Color) _scoreLine(String key, Map? latest) {
  if (latest == null) return ('', hcSlate);
  if (key == 'braden') {
    final t = latest['total'];
    final tn = t is num ? t : num.tryParse('$t');
    if (tn == null) return ('', hcSlate);
    final c = tn <= 12 ? hcRed : tn <= 18 ? hcAmber : hcGreen;
    final risk = latest['risk_level']?.toString();
    return ('$tn / 23${risk != null && risk.isNotEmpty ? ' · $risk' : ''}', c);
  }
  if (key == 'morse') {
    final s = latest['score'];
    final sn = s is num ? s : num.tryParse('$s');
    if (sn == null) return ('', hcSlate);
    final c = sn >= 45 ? hcRed : sn >= 25 ? hcAmber : hcGreen;
    return ('$sn / 125', c);
  }
  final score = latest['score'] ?? latest['total'] ?? latest['total_score'];
  if (score == null) return ('', hcSlate);
  return ('$score', hcTeal);
}

String _resultText(String key, Map item) {
  switch (key) {
    case 'braden':
      return item['total'] != null
          ? 'Braden ${item['total']}/23${item['risk_level'] != null ? ' · ${item['risk_level']}' : ''}'
          : 'Braden completed';
    case 'caprini':
      return item['points'] != null
          ? 'Caprini ${item['points']} pts'
          : 'Caprini completed';
    case 'morse':
      return item['score'] != null
          ? 'Morse ${item['score']}/125'
          : 'Morse completed';
    case 'must':
      return item['total_score'] != null
          ? 'MUST ${item['total_score']}/6'
          : 'MUST completed';
    case 'cam':
      return item['cam_positive'] == true ? 'CAM positive' : 'CAM negative';
    case 'gcs':
      return item['total'] != null
          ? 'GCS ${item['total']}/15'
          : 'GCS completed';
    case 'pivc':
      return item['vip_score'] != null
          ? 'VIP ${item['vip_score']}/5${item['vip_label'] != null ? ' — ${item['vip_label']}' : ''}'
          : 'PIVC completed';
    case 'skin_care':
      return 'Skin care ${item['completed_count'] ?? 0}/6 tasks';
    case 'pain_reassess':
      return item['score'] != null
          ? 'Pain ${item['score']}/10'
          : 'Pain completed';
    case 'diabetes_bundle':
      return 'Diabetes bundle';
    case 'hf_bundle':
      return 'Heart failure bundle';
    case 'enteral_feeding':
      return 'Enteral ${item['bundle_compliance_pct'] ?? '—'}%';
    case 'urinary_catheter':
      return 'Urinary ${item['bundle_compliance_pct'] ?? '—'}%';
    case 'artificial_airway':
      return 'Airway ${item['overall_compliance_pct'] ?? item['trach_compliance_pct'] ?? '—'}%';
    default:
      return 'Assessment completed';
  }
}

const _skinCareLabels = <String, String>{
  'reposition': 'Repositioned (q4h turn)',
  'surface': 'Support surface checked',
  'moisture': 'Moisture managed',
  'nutrition': 'Nutrition / hydration reviewed',
  'heels': 'Heels floated / offloaded',
  'inspect': 'Skin inspected head-to-toe',
};

/// Returns the labels of tri-state bundle items marked "yes" on the record.
List<String> _bundleDoneItems(String bundleKey, Map item) {
  BundleScale? scale;
  for (final b in kBundleScales) {
    if (b.key == bundleKey) {
      scale = b;
      break;
    }
  }
  if (scale == null) return const [];
  final labelOf = <String, String>{};
  for (final s in scale.sections) {
    for (final it in s.items) {
      labelOf[it.$1] = it.$2;
    }
  }
  final done = <String>[];
  item.forEach((k, v) {
    if (v == 'yes') {
      final lbl = labelOf[k];
      if (lbl != null) done.add(lbl);
    }
  });
  return done;
}

List<(String, String)> _metrics(String key, Map item) {
  final m = <(String, String)>[];
  void add(String label, dynamic v, [String suffix = '']) {
    if (v == null) return;
    final s = v.toString();
    if (s.isEmpty) return;
    m.add((label, suffix.isEmpty ? s : '$s$suffix'));
  }

  void list(String label, dynamic v) {
    if (v is List && v.isNotEmpty) m.add((label, v.join(', ')));
  }

  switch (key) {
    case 'braden':
      if (item['total'] != null) add('Total', item['total'], '/23');
      if (item['risk_level'] != null) add('Risk', item['risk_level']);
      const sub = {
        'sensory': 'Sensory',
        'moisture': 'Moisture',
        'activity': 'Activity',
        'mobility': 'Mobility',
        'nutrition': 'Nutrition',
        'friction': 'Friction',
      };
      for (final k in sub.keys) {
        if (item[k] != null) add(sub[k]!, item[k]);
      }
      break;
    case 'caprini':
      if (item['points'] != null) add('Points', item['points']);
      if (item['risk_level'] != null) add('Risk', item['risk_level']);
      break;
    case 'morse':
      if (item['score'] != null) add('Score', item['score'], '/125');
      if (item['risk_level'] != null) add('Risk', item['risk_level']);
      break;
    case 'must':
      if (item['total_score'] != null)
        add('Score', item['total_score'], '/6');
      if (item['bmi'] != null) add('BMI', item['bmi']);
      if (item['risk_level'] != null) add('Risk', item['risk_level']);
      break;
    case 'cam':
      add('Result', item['cam_positive'] == true ? 'Positive' : 'Negative');
      break;
    case 'gcs':
      if (item['total'] != null) add('Total', item['total'], '/15');
      if (item['eyes'] != null) add('Eye', item['eyes']);
      if (item['verbal'] != null) add('Verbal', item['verbal']);
      if (item['motor'] != null) add('Motor', item['motor']);
      break;
    case 'pivc':
      if (item['vip_score'] != null) add('VIP', item['vip_score'], '/5');
      if (item['vip_label'] != null) add('Stage', item['vip_label']);
      if (item['catheter_site'] != null) {
        add('Site',
            '${item['catheter_site']}${item['gauge'] != null ? ' · ${item['gauge']}' : ''}');
      }
      if (item['pain_score_nrs'] != null)
        add('Pain', item['pain_score_nrs'], '/10');
      if (item['bundle_compliance_pct'] != null)
        add('Compliance', item['bundle_compliance_pct'], '%');
      if (item['catheter_removed'] == true)
        add('Removed', item['removal_reason'] ?? 'Yes');
      break;
    case 'skin_care':
      final completed = item['completed_items'];
      final count =
          item['completed_count'] ?? (completed is List ? completed.length : 0);
      add('Completed', count, '/6');
      if (completed is List) {
        for (final c in completed) {
          final lbl = _skinCareLabels[c.toString()] ?? c.toString();
          m.add(('✓ $lbl', ''));
        }
      }
      break;
    case 'pain_reassess':
      final tool = item['tool_type']?.toString() ?? 'nrs';
      const toolLbl = {
        'nrs': 'NRS',
        'vas': 'VAS',
        'faces': 'FACES',
        'flacc': 'FLACC',
        'painad': 'PAINAD',
      };
      if (item['score'] != null)
        add('Score', '${item['score']} [${toolLbl[tool] ?? 'NRS'}]', '/10');
      if (item['score_category'] != null) add('Category', item['score_category']);
      if (item['has_pain'] == true) {
        add('Pain present', 'Yes');
      } else if (item['has_pain'] == false) {
        add('Pain present', 'No');
      }
      if (item['worst_pain_24h'] != null)
        add('Worst (24h)', item['worst_pain_24h'], '/10');
      if (item['least_pain_24h'] != null)
        add('Least (24h)', item['least_pain_24h'], '/10');
      if (item['average_pain'] != null)
        add('Average', item['average_pain'], '/10');
      if (item['acceptable_pain_goal'] != null)
        add('Goal', item['acceptable_pain_goal'], '/10');
      if (item['vas_mm'] != null) add('VAS', item['vas_mm'], 'mm');
      if (item['faces_choice'] != null)
        add('FACES', item['faces_choice'], '/10');
      if (item['flacc_total'] != null)
        add('FLACC total', item['flacc_total'], '/10');
      if (item['painad_total'] != null)
        add('PAINAD total', item['painad_total'], '/10');
      list('Worse by', item['provocation_factors']);
      list('Relieved by', item['palliation_factors']);
      list('Quality', item['quality_descriptors']);
      if (item['quality_other'] != null) add('Other quality', item['quality_other']);
      list('Location', item['pain_locations']);
      if (item['has_radiation'] == true)
        add('Radiates', item['radiation_pathway'] ?? 'Yes');
      if (item['onset_type'] != null) add('Onset', item['onset_type']);
      if (item['pain_pattern'] != null) add('Pattern', item['pain_pattern']);
      if (item['pain_duration'] != null) add('Duration', item['pain_duration']);
      if (item['pain_frequency'] != null)
        add('Frequency', item['pain_frequency']);
      if (item['impact_sleep'] != null)
        add('Sleep impact', item['impact_sleep'] == true ? 'Yes' : 'No');
      if (item['impact_adl'] != null)
        add('ADL impact', item['impact_adl'] == true ? 'Yes' : 'No');
      if (item['impact_mood'] != null)
        add('Mood impact', item['impact_mood'] == true ? 'Yes' : 'No');
      if (item['impact_appetite'] != null)
        add('Appetite impact', item['impact_appetite'] == true ? 'Yes' : 'No');
      if (item['impact_other'] != null) add('Other impact', item['impact_other']);
      if (item['pre_treatment_score'] != null ||
          item['post_treatment_score'] != null) {
        add('Treatment',
            '${item['pre_treatment_score'] ?? '?'} → ${item['post_treatment_score'] ?? '?'}');
      }
      if (item['treatment_given'] != null)
        add('Intervention', item['treatment_given']);
      break;
    case 'diabetes_bundle':
      if (item['glucose'] != null) add('Glucose', item['glucose'], ' mmol/L');
      if (item['ketones'] != null) add('Ketones', item['ketones'], ' mmol/L');
      break;
    case 'hf_bundle':
      if (item['weight_kg'] != null) add('Weight', item['weight_kg'], ' kg');
      if (item['fluid_balance_ml'] != null)
        add('Fluid balance', item['fluid_balance_ml'], ' ml');
      if (item['spo2'] != null) add('SpO₂', item['spo2'], '%');
      break;
    case 'enteral_feeding':
    case 'urinary_catheter':
    case 'artificial_airway':
      if (key == 'enteral_feeding') {
        final dev = item['device_type_label'] ??
            item['device_type']?.toString().toUpperCase();
        if (dev != null) add('Device', dev);
        if (item['tube_size'] != null) add('Size', item['tube_size']);
      }
      if (key == 'urinary_catheter') {
        if (item['catheter_type'] != null) add('Type', item['catheter_type']);
        if (item['catheter_day'] != null) add('Day', item['catheter_day']);
      }
      if (key == 'artificial_airway') {
        final dev = item['airway_device_label'] ?? item['airway_device'];
        if (dev != null) add('Device', dev);
        if (item['mechanically_ventilated'] == true) add('Ventilated', 'Yes');
        if (item['trach_compliance_pct'] != null)
          add('Trach', item['trach_compliance_pct'], '%');
        if (item['vap_compliance_pct'] != null)
          add('VAP', item['vap_compliance_pct'], '%');
        if (item['overall_compliance_pct'] != null)
          add('Overall', item['overall_compliance_pct'], '%');
        if (item['emergency_equipment_incomplete'] == true)
          add('Alert', 'Emergency equipment incomplete');
        if (item['device_removed'] == true)
          add('Removed', item['removal_reason'] ?? 'Yes');
      }
      if (item['bundle_compliance_pct'] != null)
        add('Compliance', item['bundle_compliance_pct'], '%');
      if (item['device_removed'] == true && key != 'artificial_airway')
        add('Removed', item['removal_reason'] ?? 'Yes');
      for (final d in _bundleDoneItems(key, item)) {
        m.add(('✓ $d', ''));
      }
      break;
  }
  return m;
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

Map _parseNotes(dynamic v) {
  if (v == null) return {};
  try {
    final p = jsonDecode(v.toString());
    if (p is Map) return Map.from(p);
  } catch (_) {}
  return {};
}

String _readNote(dynamic v) {
  if (v == null) return '';
  final s = v.toString().trim();
  if (s.isEmpty) return '';
  try {
    final p = jsonDecode(s);
    if (p is Map) return p['note']?.toString().trim() ?? '';
  } catch (_) {}
  return s;
}

/// Mobile Patient Command Centre — role-aware tabs.
class HomecarePatientCareDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const HomecarePatientCareDetailScreen({super.key, required this.id});

  @override
  ConsumerState<HomecarePatientCareDetailScreen> createState() =>
      _HomecarePatientCareDetailScreenState();
}

class _HomecarePatientCareDetailScreenState
    extends ConsumerState<HomecarePatientCareDetailScreen>
    with SingleTickerProviderStateMixin {
  bool get _isAdmin => ref.read(authProvider).user?.role != 'caregiver';

  late final List<(String, IconData)> _tabs = [
    ('Overview', Icons.dashboard_rounded),
    ('Assessments', Icons.assignment_rounded),
    ('Vitals', Icons.monitor_heart_rounded),
    ('Doses', Icons.medication_rounded),
    ('Meds', Icons.medication_liquid_rounded),
    ('Lines', Icons.device_hub_rounded),
    if (_isAdmin) ('Supplies', Icons.inventory_2_rounded),
    ('Notes', Icons.note_alt_rounded),
    ('Plan', Icons.article_rounded),
    ('Docs', Icons.folder_rounded),
    if (_isAdmin) ('Billing', Icons.receipt_long_rounded),
  ];
  late final TabController _tab =
      TabController(length: _tabs.length, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(_summaryProvider(widget.id));
    ref.invalidate(_pcVitalsProvider(widget.id));
    ref.invalidate(_pcDosesProvider(widget.id));
    ref.invalidate(_pcNotesProvider(widget.id));
    ref.invalidate(_pcPlansProvider(widget.id));
    ref.invalidate(_pcLinesProvider(widget.id));
    ref.invalidate(_pcWorklistProvider(widget.id));
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(_summaryProvider(widget.id));
    final patient =
        (summary.valueOrNull?['patient'] as Map?) ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(patient['name']?.toString() ?? 'Patient',
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Text(patient['medical_record_number']?.toString() ?? '',
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _refreshAll),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _tabs
              .map((t) => Tab(icon: Icon(t.$2, size: 18), text: t.$1))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _OverviewTab(id: widget.id, isAdmin: _isAdmin),
          _AssessmentsTab(id: widget.id),
          _VitalsTab(id: widget.id),
          _DosesTab(id: widget.id),
          _MedsTab(id: widget.id, isAdmin: _isAdmin),
          _LinesTab(id: widget.id),
          if (_isAdmin) _SuppliesTab(id: widget.id),
          _NotesTab(id: widget.id),
          _PlanTab(id: widget.id),
          _DocsTab(id: widget.id),
          if (_isAdmin) _BillingTab(id: widget.id),
        ],
      ),
    );
  }
}

// ═════════════════ OVERVIEW ═════════════════
class _OverviewTab extends ConsumerWidget {
  final int id;
  final bool isAdmin;
  const _OverviewTab({required this.id, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(_summaryProvider(id));
    final vitals = ref.watch(_pcVitalsProvider(id));

    return HcAsyncBody(
      value: summary,
      onRefresh: () async => ref.refresh(_summaryProvider(id).future),
      builder: (s) {
        final latest =
            (vitals.valueOrNull?.isNotEmpty ?? false)
                ? vitals.valueOrNull!.first as Map
                : null;
        final news2 = latest?['news2'] as num?;
        final meds = (s['medications'] as List?) ?? [];
        final activeMeds =
            meds.cast<Map>().where((m) => m['is_active'] == true).length;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.3,
              children: [
                HcKpi(
                    label: 'NEWS2',
                    value: '${news2 ?? '—'}',
                    icon: Icons.monitor_heart_rounded,
                    color: news2Color(news2)),
                HcKpi(
                    label: 'Active meds',
                    value: '$activeMeds',
                    icon: Icons.medication_rounded,
                    color: hcPurple),
                HcKpi(
                    label: 'Risk level',
                    value: hcLabel(
                        (s['patient'] as Map?)?['risk_level']?.toString()),
                    icon: Icons.shield_rounded,
                    color: hcRiskColor(
                        (s['patient'] as Map?)?['risk_level']?.toString())),
                if (isAdmin)
                  HcKpi(
                      label: 'Balance',
                      value: hcMoney(s['balance'],
                          currency:
                              (s['currency'] ?? 'KSh').toString()),
                      icon: Icons.account_balance_wallet_rounded,
                      color: (double.tryParse('${s['balance']}') ?? 0) > 0
                          ? hcRed
                          : hcGreen)
                else
                  HcKpi(
                      label: 'Supplies',
                      value: '${((s['supplies'] as List?) ?? []).length}',
                      icon: Icons.inventory_2_rounded,
                      color: hcAmber),
              ],
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24))),
                    builder: (_) => RecordVitalsSheet(patientId: id),
                  ).then((_) {
                    ref.invalidate(_pcVitalsProvider(id));
                  }),
                  icon: const Icon(Icons.monitor_heart_rounded, size: 18),
                  label: const Text('Record vitals'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24))),
                    builder: (_) =>
                        RecordAssessmentSheet(scaleKey: 'braden', patientId: id),
                  ),
                  icon: const Icon(Icons.assignment_add, size: 18),
                  label: const Text('Assess'),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            if (latest != null)
              HcPanel(
                title: 'Latest vitals',
                subtitle: hcDateTime(latest['recorded_at']),
                icon: Icons.monitor_heart_rounded,
                color: hcRose,
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final t in [
                    ('BP',
                        '${latest['systolic'] ?? '—'}/${latest['diastolic'] ?? '—'}'),
                    ('HR', '${latest['pulse'] ?? '—'}'),
                    ('SpO₂', '${latest['spo2'] ?? '—'}%'),
                    ('Temp', '${latest['temperature'] ?? '—'}°C'),
                    ('RR', '${latest['rr'] ?? '—'}'),
                  ])
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          color: hcRose.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(children: [
                        Text(t.$2,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14)),
                        Text(t.$1, style: const TextStyle(fontSize: 10)),
                      ]),
                    ),
                ]),
              ),
          ],
        );
      },
    );
  }
}

// ═════════════════ VITALS ═════════════════
class _VitalsTab extends ConsumerStatefulWidget {
  final int id;
  const _VitalsTab({required this.id});

  @override
  ConsumerState<_VitalsTab> createState() => _VitalsTabState();
}

class _VitalsTabState extends ConsumerState<_VitalsTab> {
  int? _selectedId;

  Map? _selectedOrLatest(List list) {
    if (list.isEmpty) return null;
    if (_selectedId != null) {
      for (final item in list) {
        if ((item as Map)['id'] == _selectedId) return item;
      }
    }
    return list.first as Map;
  }

  void _openRecordSheet({Map? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) =>
          RecordVitalsSheet(patientId: widget.id, existing: existing),
    ).then((saved) {
      if (saved == true) {
        ref.invalidate(_pcVitalsProvider(widget.id));
      }
    });
  }

  Future<void> _deleteVital(Map v) async {
    final vid = v['id'];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete vitals record?'),
        content: Text(
            'Delete the record from ${hcDateTime(v['recorded_at'])}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: hcRed),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/homecare/vitals/$vid/');
      if (mounted) {
        if (_selectedId == vid) {
          setState(() => _selectedId = null);
        }
        ref.invalidate(_pcVitalsProvider(widget.id));
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vitals record deleted.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete record.')));
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final vitals = ref.watch(_pcVitalsProvider(widget.id));
    final list = vitals.valueOrNull ?? const [];
    final sel = _selectedOrLatest(list);
    final news2 = sel?['news2'] as num?;

    // Vitals schedule (mirrors nuxtfrontend vitalsFrequency)
    String freqLabel;
    int freqMs;
    if (news2 == null) {
      freqLabel = 'q4h (default)';
      freqMs = 4 * 3600000;
    } else if (news2 >= 7) {
      freqLabel = 'Continuous';
      freqMs = 15 * 60000;
    } else if (news2 >= 5) {
      freqLabel = 'Hourly';
      freqMs = 3600000;
    } else if (news2 >= 3) {
      freqLabel = 'q2h';
      freqMs = 2 * 3600000;
    } else {
      freqLabel = 'q4h';
      freqMs = 4 * 3600000;
    }
    final lastTs = sel != null
        ? DateTime.tryParse(sel['recorded_at']?.toString() ?? '')
        : null;
    final nextTs = lastTs?.add(Duration(milliseconds: freqMs));
    final elapsed = lastTs == null
        ? 0
        : DateTime.now().millisecondsSinceEpoch - lastTs.millisecondsSinceEpoch;
    final pct = (elapsed / freqMs * 100).clamp(0, 100).round();
    final progressColor = pct >= 90
        ? hcRed
        : pct >= 70
            ? hcAmber
            : pct >= 50
                ? hcBlue
                : hcGreen;
    final urgencyText = pct >= 100
        ? 'OVERDUE!'
        : pct >= 90
            ? 'Due now'
            : pct >= 70
                ? 'Due soon'
                : 'On schedule';
    final urgencyColor = pct >= 90
        ? hcRed
        : pct >= 70
            ? hcAmber
            : hcGreen;

    // NEWS2 breakdown for selected vitals
    News2Result? breakdown;
    if (sel != null) {
      breakdown = calcNews2(
        rr: sel['rr'] as num?,
        spo2: sel['spo2'] as num?,
        scale2: sel['scale2'] == true,
        oxygen: sel['oxygen'] == true || sel['oxygen'] == 'Supplemental O₂'
            ? 'Supplemental O₂'
            : 'Room air',
        systolic: sel['systolic'] as num?,
        heartRate: sel['pulse'] as num?,
        temperature: sel['temperature'] as num?,
        consciousness: sel['consciousness']?.toString(),
      );
    }
    final riskColor = news2 == null
        ? hcSlate
        : news2 >= 7
            ? hcRed
            : news2 >= 5
                ? hcAmber
                : news2 > 0
                    ? hcBlue
                    : hcGreen;
    final riskLabel = news2 == null
        ? 'No data'
        : news2 >= 7
            ? 'High'
            : news2 >= 5
                ? 'Medium'
                : news2 > 0
                    ? 'Low – Medium'
                    : 'Low';

    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'pc-vitals-${widget.id}',
        backgroundColor: hcRose,
        foregroundColor: Colors.white,
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (_) => RecordVitalsSheet(patientId: widget.id),
        ).then((_) => ref.invalidate(_pcVitalsProvider(widget.id))),
        child: const Icon(Icons.add_rounded),
      ),
      body: HcAsyncBody(
        value: vitals,
        onRefresh: () async => ref.refresh(_pcVitalsProvider(widget.id).future),
        builder: (_) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
          children: [
            // ── NEWS2 Monitoring card ──
            Card(
              margin: const EdgeInsets.only(bottom: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              color: hcBlue.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NEWS2 MONITORING',
                        style: TextStyle(
                            color: hcBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    Row(children: [
                      // Gauge
                      SizedBox(
                        width: 96,
                        height: 96,
                        child: Stack(alignment: Alignment.center, children: [
                          SizedBox(
                            width: 96,
                            height: 96,
                            child: CircularProgressIndicator(
                              value: ((news2 ?? 0) / 20).clamp(0, 1),
                              strokeWidth: 8,
                              backgroundColor:
                                  hcSlate.withValues(alpha: 0.15),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(riskColor),
                            ),
                          ),
                          Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${news2 ?? '—'}',
                                    style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: riskColor)),
                                Text('/ 20',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant)),
                              ]),
                        ]),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: riskColor,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text('$riskLabel Risk',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(height: 8),
                              Row(children: [
                                Icon(Icons.schedule_rounded,
                                    size: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                                const SizedBox(width: 4),
                                Expanded(
                                    child: Text(freqLabel,
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant))),
                              ]),
                              const SizedBox(height: 3),
                              Row(children: [
                                Icon(Icons.update_rounded,
                                    size: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                                const SizedBox(width: 4),
                                Expanded(
                                    child: Text(
                                        'Next due: ${nextTs != null ? hcDateTime(nextTs.toIso8601String()) : 'Now'}',
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant))),
                              ]),
                            ]),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    // Countdown bar
                    if (lastTs != null) ...[
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Last: ${hcDateTime(sel?['recorded_at'])}',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                            Text(
                                'Next: ${nextTs != null ? hcTime(nextTs.toIso8601String()) : 'Now'}',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                          ]),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: pct / 100,
                          minHeight: 7,
                          backgroundColor: hcSlate.withValues(alpha: 0.12),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(progressColor),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text('$urgencyText · $pct%',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: urgencyColor)),
                      const SizedBox(height: 14),
                    ],
                    // Scale Breakdown
                    Text('Scale Breakdown',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface)),
                    const SizedBox(height: 8),
                    if (breakdown != null)
                      for (final b in breakdown.breakdown)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3.5),
                          child: Row(children: [
                            Icon(b.icon,
                                size: 16,
                                color: b.score >= 3
                                    ? hcRed
                                    : b.score > 0
                                        ? hcAmber
                                        : hcSlate),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(b.label,
                                    style:
                                        const TextStyle(fontSize: 11.5))),
                            Text(b.value,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: (b.score >= 3
                                        ? hcRed
                                        : b.score > 0
                                            ? hcAmber
                                            : hcGreen)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text('${b.score}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: b.score >= 3
                                          ? hcRed
                                          : b.score > 0
                                              ? hcAmber
                                              : hcGreen)),
                            ),
                          ]),
                        )
                    else
                      Text('Record vitals to see NEWS2 breakdown.',
                          style: TextStyle(
                              fontSize: 11.5,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                  ],
                ),
              ),
            ),
            // ── Vitals History card ──
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              color: hcTeal.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.show_chart_rounded, color: hcTeal, size: 18),
                      const SizedBox(width: 8),
                      const Text('Vitals History',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24))),
                          builder: (_) =>
                              RecordVitalsSheet(patientId: widget.id),
                        ).then((_) =>
                            ref.invalidate(_pcVitalsProvider(widget.id))),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Record'),
                        style: TextButton.styleFrom(
                            foregroundColor: hcTeal,
                            visualDensity: VisualDensity.compact),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                            child: Text('No vitals recorded yet.',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant))),
                      )
                    else
                      Table(
                        columnWidths: const {
                          0: FlexColumnWidth(2.0),
                          1: IntrinsicColumnWidth(),
                          2: FlexColumnWidth(1.1),
                          3: IntrinsicColumnWidth(),
                          4: IntrinsicColumnWidth(),
                          5: IntrinsicColumnWidth(),
                          6: IntrinsicColumnWidth(),
                        },
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        children: [
                          TableRow(
                              decoration: BoxDecoration(
                                  border: Border(
                                      bottom: BorderSide(
                                          color: hcSlate
                                              .withValues(alpha: 0.2)))),
                              children: [
                                for (final h in [
                                  'Date/Time',
                                  'NEWS2',
                                  'BP',
                                  'RR',
                                  'Pulse',
                                  'Temp',
                                  'SpO₂'
                                ])
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: 6, right: 6),
                                    child: Text(h,
                                        style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant)),
                                  ),
                              ]),
                          for (final item in list)
                            TableRow(children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() =>
                                    _selectedId = item['id'] as int?),
                                onLongPress: () {
                                  final v = item;
                                  showModalBottomSheet(
                                    context: context,
                                    showDragHandle: true,
                                    builder: (sheetCtx) => SafeArea(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            leading: const Icon(
                                                Icons.edit_rounded,
                                                color: hcTeal),
                                            title: const Text('Edit record'),
                                            onTap: () {
                                              Navigator.pop(sheetCtx);
                                              _openRecordSheet(existing: v);
                                            },
                                          ),
                                          ListTile(
                                            leading: Icon(
                                                Icons.delete_outline_rounded,
                                                color: hcRed),
                                            title: const Text('Delete record'),
                                            onTap: () {
                                              Navigator.pop(sheetCtx);
                                              _deleteVital(v);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 7, horizontal: 0),
                                  child: Text(
                                      hcDateTime(
                                          (item as Map)['recorded_at']),
                                      style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: _selectedId ==
                                                  (item)['id']
                                              ? FontWeight.w800
                                              : FontWeight.w400)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 7),
                                child: _News2Chip(
                                    news2: item['news2'] as num?),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 7),
                                child: Text(
                                    '${item['systolic'] ?? '—'}/${item['diastolic'] ?? '—'}',
                                    style:
                                        const TextStyle(fontSize: 10.5)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 7),
                                child: Text('${item['rr'] ?? '—'}',
                                    style:
                                        const TextStyle(fontSize: 10.5)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 7),
                                child: Text('${item['pulse'] ?? '—'}',
                                    style:
                                        const TextStyle(fontSize: 10.5)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 7),
                                child: Text(
                                    '${item['temperature'] ?? '—'}',
                                    style:
                                        const TextStyle(fontSize: 10.5)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 7),
                                child: Text('${item['spo2'] ?? '—'}%',
                                    style:
                                        const TextStyle(fontSize: 10.5)),
                              ),
                            ]),
                  ],
                ),
              ]),
            ),
              ),
          ],
        ),
      ),
    );
  }
}

class _News2Chip extends StatelessWidget {
  final num? news2;
  const _News2Chip({this.news2});

  @override
  Widget build(BuildContext context) {
    if (news2 == null) return const Text('—', style: TextStyle(fontSize: 10.5));
    final c = news2Color(news2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$news2',
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w800, color: c)),
    );
  }
}

// ═════════════════ DOSES ═════════════════
// ═════════════════ DOSES (mirrors nuxtfrontend /homecare/doses) ═════════════════

class _DoseGroup {
  final String key;
  final String label;
  final int ts;
  final List<Map> list = [];
  _DoseGroup(this.key, this.label, this.ts);
}

IconData _doseStatusIcon(String s) => switch (s) {
      'pending' => Icons.schedule_rounded,
      'taken' => Icons.check_circle_rounded,
      'missed' => Icons.warning_rounded,
      'skipped' => Icons.skip_next_rounded,
      'not_given' => Icons.cancel_rounded,
      'overdue' => Icons.warning_amber_rounded,
      _ => Icons.circle,
    };

String _doseStatusDisplay(String s) => switch (s) {
      'pending' => 'Pending',
      'taken' => 'Documented',
      'missed' => 'Missed',
      'skipped' => 'Skipped',
      'not_given' => 'Not given',
      'overdue' => 'Overdue',
      _ => s,
    };

Color _auditColor(String action) => switch (action) {
      'document' => hcGreen,
      'skip' => hcAmber,
      'not_given' => hcRed,
      'mark_missed' => hcRed,
      'auto_missed' => hcAmber,
      'edit_assessment' => hcTeal,
      _ => hcSlate,
    };

class _DosesTab extends ConsumerStatefulWidget {
  final int id;
  const _DosesTab({required this.id});

  @override
  ConsumerState<_DosesTab> createState() => _DosesTabState();
}

class _DosesTabState extends ConsumerState<_DosesTab> {
  final _search = TextEditingController();
  String _statusFilter = 'all';
  String _dateRange = 'last7';
  DateTime? _customFrom;
  DateTime? _customTo;
  final Set<int> _expanded = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  (DateTime?, DateTime?) _rangeFor(String range) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (range) {
      case 'today':
        return (today, today.add(const Duration(days: 1)));
      case 'yesterday':
        return (today.subtract(const Duration(days: 1)), today);
      case 'last7':
        return (
          today.subtract(const Duration(days: 6)),
          today.add(const Duration(days: 1))
        );
      case 'last30':
        return (
          today.subtract(const Duration(days: 29)),
          today.add(const Duration(days: 1))
        );
      case 'thisMonth':
        return (
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999),
        );
      case 'upcoming':
        return (now, null);
      case 'overdue':
        return (null, now);
      case 'custom':
        return (
          _customFrom != null
              ? DateTime(_customFrom!.year, _customFrom!.month, _customFrom!.day)
              : null,
          _customTo != null
              ? DateTime(_customTo!.year, _customTo!.month, _customTo!.day,
                  23, 59, 59, 999)
              : null,
        );
      default:
        return (null, null);
    }
  }

  void _openAction(Map dose, String actionType) {
    final mapped = switch (actionType) {
      'taken' => 'document',
      _ => actionType,
    };
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DoseActionSheet(
        dose: dose,
        actionType: mapped,
        onDone: () => ref.invalidate(_pcDosesProvider(widget.id)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doses = ref.watch(_pcDosesProvider(widget.id));
    return HcAsyncBody(
      value: doses,
      onRefresh: () async => ref.refresh(_pcDosesProvider(widget.id).future),
      builder: (list) {
        final all = list.cast<Map>().toList();
        final taken = all.where((d) => d['status'] == 'taken').length;
        final missed = all.where((d) => d['status'] == 'missed').length;
        final pending =
            all.where((d) => d['status'] == 'pending').length;
        final total = all.length;
        final finalized = taken + missed;
        final adherence =
            finalized > 0 ? (taken / finalized * 100).round() : 0;

        final q = _search.text.trim().toLowerCase();
        final (fromDate, toDate) = _rangeFor(_dateRange);
        final filtered = all.where((d) {
          if (_statusFilter != 'all' && d['status'] != _statusFilter) {
            return false;
          }
          if (_dateRange == 'overdue' && d['status'] != 'pending') {
            return false;
          }
          final scheduled = d['scheduled_at'];
          if (scheduled != null && (fromDate != null || toDate != null)) {
            final dt = DateTime.tryParse(scheduled.toString())?.toLocal();
            if (dt != null) {
              if (fromDate != null && dt.isBefore(fromDate)) return false;
              if (toDate != null && dt.isAfter(toDate)) return false;
            }
          }
          if (q.isEmpty) return true;
          return [
            d['medication_name'],
            d['schedule_medication'],
            d['dose'],
          ].any((v) => (v ?? '').toString().toLowerCase().contains(q));
        }).toList()
          ..sort((a, b) => (a['scheduled_at'] ?? '')
              .toString()
              .compareTo((b['scheduled_at'] ?? '').toString()));

        final groups = <_DoseGroup>[];
        final groupMap = <String, _DoseGroup>{};
        for (final d in filtered) {
          final dt =
              DateTime.tryParse(d['scheduled_at']?.toString() ?? '');
          if (dt == null) continue;
          final dtl = dt.toLocal();
          final key =
              '${dtl.year}-${dtl.month}-${dtl.day}-${dtl.hour}';
          final label =
              DateFormat('EEE dd MMM · HH:mm').format(dtl);
          var g = groupMap[key];
          if (g == null) {
            g = _DoseGroup(key, label, dtl.millisecondsSinceEpoch);
            groupMap[key] = g;
            groups.add(g);
          }
          g.list.add(d);
        }
        groups.sort((a, b) => a.ts.compareTo(b.ts));

        final statusRows = const [
          ('pending', 'Pending'),
          ('taken', 'Documented'),
          ('missed', 'Missed'),
          ('skipped', 'Skipped'),
          ('not_given', 'Not given'),
          ('overdue', 'Overdue'),
        ];

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
          children: [
            // ── KPI strip ──
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.92,
              children: [
                _DoseKpi(
                    label: 'Total',
                    value: '$total',
                    color: hcSlate,
                    icon: Icons.medication_rounded,
                    bar: 1.0),
                _DoseKpi(
                    label: 'Pending',
                    value: '$pending',
                    color: hcAmber,
                    icon: Icons.schedule_rounded,
                    bar: total > 0 ? pending / total : 0),
                _DoseKpi(
                    label: 'Taken',
                    value: '$taken',
                    color: hcGreen,
                    icon: Icons.check_circle_rounded,
                    bar: total > 0 ? taken / total : 0),
                _DoseKpi(
                    label: 'Missed',
                    value: '$missed',
                    color: hcRed,
                    icon: Icons.cancel_rounded,
                    bar: total > 0 ? missed / total : 0),
              ],
            ),
            const SizedBox(height: 12),

            // ── Status breakdown panel ──
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                            color: hcPurple.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.donut_large_rounded,
                            color: hcPurple, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text('Status breakdown',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: hcTeal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999)),
                        child: Text('$adherence% adherence',
                            style: TextStyle(
                                color: hcTeal,
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    for (final r in statusRows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: _StatusRow(
                          label: r.$2,
                          count: all
                              .where((d) => d['status'] == r.$1)
                              .length,
                          total: total,
                          color: hcDoseStatusColor(r.$1),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Search ──
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search medication…',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),

            // ── Date range filter chips ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final f in const [
                  ('today', 'Today'),
                  ('yesterday', 'Yesterday'),
                  ('last7', '7 days'),
                  ('last30', '30 days'),
                  ('thisMonth', 'This month'),
                  ('upcoming', 'Upcoming'),
                  ('overdue', 'Overdue'),
                  ('all', 'All'),
                  ('custom', 'Custom…'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: _dateRange == f.$1,
                      label: Text(f.$2),
                      onSelected: (_) =>
                          setState(() => _dateRange = f.$1),
                    ),
                  ),
              ]),
            ),

            // ── Custom date pickers ──
            if (_dateRange == 'custom') ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _customFrom ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now()
                            .add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _customFrom = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text(
                          _customFrom != null
                              ? DateFormat('dd MMM yyyy')
                                  .format(_customFrom!)
                              : 'From',
                          style: TextStyle(
                              fontSize: 13,
                              color: _customFrom != null
                                  ? null
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                        ),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _customTo ?? _customFrom ?? DateTime.now(),
                        firstDate: _customFrom ?? DateTime(2020),
                        lastDate: DateTime.now()
                            .add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _customTo = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(children: [
                        Icon(Icons.event_rounded,
                            size: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text(
                          _customTo != null
                              ? DateFormat('dd MMM yyyy')
                                  .format(_customTo!)
                              : 'To',
                          style: TextStyle(
                              fontSize: 13,
                              color: _customTo != null
                                  ? null
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                        ),
                      ]),
                    ),
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 8),

            // ── Status filter chips ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final f in const [
                  ('all', 'All'),
                  ('pending', 'Pending'),
                  ('taken', 'Taken'),
                  ('missed', 'Missed'),
                  ('skipped', 'Skipped'),
                  ('not_given', 'Not given'),
                  ('overdue', 'Overdue'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: _statusFilter == f.$1,
                      label: Text(f.$2),
                      onSelected: (_) =>
                          setState(() => _statusFilter = f.$1),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                  '${filtered.length} dose${filtered.length != 1 ? 's' : ''}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant)),
            ),

            // ── Dose list grouped by time ──
            if (groups.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: Text('No doses match the filters.')),
              )
            else
              ...groups.map((g) => _buildGroup(g)),
          ],
        );
      },
    );
  }

  Widget _buildGroup(_DoseGroup g) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Row(children: [
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: hcTeal, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: hcTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.schedule_rounded, size: 13, color: hcTeal),
                const SizedBox(width: 4),
                Text(g.label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: hcTeal)),
              ]),
            ),
            const SizedBox(width: 4),
            Expanded(child: Container(height: 1, color: hcSlate.withValues(alpha: 0.15))),
            const SizedBox(width: 8),
            Text('${g.list.length} dose${g.list.length != 1 ? 's' : ''}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: hcSlate)),
          ]),
        ),
        ...g.list.map((d) => _buildDoseCard(d)),
      ],
    );
  }

  Widget _buildDoseCard(Map d) {
    final status = d['status']?.toString() ?? '';
    final color = hcDoseStatusColor(status);
    final icon = _doseStatusIcon(status);
    final isExpanded = _expanded.contains(d['id']);
    final isPending = status == 'pending' || status == 'overdue';
    final audit = (d['audit_log'] as List?) ?? const [];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 3, color: color),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row ──
                Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(
                              d['medication_name']?.toString() ??
                                  d['schedule_medication']
                                      ?.toString() ??
                                  'Medication',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5),
                            ),
                          ),
                          const SizedBox(width: 6),
                          HcStatusChip(
                              label: _doseStatusDisplay(status),
                              color: color,
                              icon: icon),
                        ]),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (d['auto_missed'] == true)
                              _TinyChip(
                                  icon: Icons.smart_toy_rounded,
                                  label: 'Auto',
                                  color: hcAmber),
                            if ((d['dose'] ?? '')
                                .toString()
                                .isNotEmpty)
                              _TinyChip(
                                  icon: Icons.medication_rounded,
                                  label:
                                      '${d['dose']} ${d['dose_unit'] ?? ''}',
                                  color: hcSlate),
                          ],
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 8),

                // ── Meta info ──
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _MetaItem(
                        icon: Icons.calendar_today_rounded,
                        text:
                            'Scheduled ${hcDateTime(d['scheduled_at'])}'),
                    if (d['administered_at'] != null)
                      _MetaItem(
                          icon: Icons.check_circle_rounded,
                          text:
                              'Given ${hcDateTime(d['administered_at'])}',
                          color: hcGreen),
                    if ((d['administered_by_name'] ?? '')
                        .toString()
                        .isNotEmpty)
                      _MetaItem(
                        icon: Icons.person_rounded,
                        text:
                            'by ${d['administered_by_name']}${(d['administered_by_role'] ?? '').toString().isNotEmpty ? ' (${d['administered_by_role']})' : ''}',
                      ),
                  ],
                ),

                // ── Reason ──
                if ((d['reason'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: hcAmber.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Icon(Icons.message_rounded,
                          size: 12, color: hcAmber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Reason: ${d['reason']}',
                            style: TextStyle(
                                fontSize: 11, color: hcAmber)),
                      ),
                    ]),
                  ),
                ],

                // ── Actions ──
                const SizedBox(height: 8),
                Row(children: [
                  if (isPending) ...[
                    _DoseActionBtn(
                        label: 'Document',
                        icon: Icons.check_circle_rounded,
                        color: hcGreen,
                        onTap: () => _openAction(d, 'taken')),
                    const SizedBox(width: 6),
                    _DoseActionBtn(
                        label: 'Skip',
                        icon: Icons.skip_next_rounded,
                        color: hcAmber,
                        onTap: () => _openAction(d, 'skip')),
                    const SizedBox(width: 6),
                    _DoseActionBtn(
                        label: 'Not given',
                        icon: Icons.cancel_rounded,
                        color: hcRed,
                        onTap: () => _openAction(d, 'not_given')),
                    const SizedBox(width: 6),
                    _DoseActionBtn(
                        label: 'Edit',
                        icon: Icons.edit_rounded,
                        color: hcBlue,
                        onTap: () => _openAction(d, 'edit')),
                  ] else ...[
                    _DoseActionBtn(
                        label: 'Edit assessment',
                        icon: Icons.edit_rounded,
                        color: hcBlue,
                        onTap: () => _openAction(d, 'edit')),
                  ],
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                        isExpanded
                            ? Icons.expand_less_rounded
                            : Icons.history_rounded,
                        size: 18),
                    onPressed: () => setState(() {
                      if (isExpanded) {
                        _expanded.remove(d['id']);
                      } else {
                        _expanded.add(d['id']);
                      }
                    }),
                  ),
                ]),

                // ── Audit trail ──
                if (isExpanded) ...[
                  const Divider(height: 16),
                  Row(children: [
                    Icon(Icons.history_rounded, size: 12, color: hcSlate),
                    const SizedBox(width: 4),
                    Text('AUDIT TRAIL',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: hcSlate)),
                  ]),
                  const SizedBox(height: 8),
                  if (audit.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text('No history yet.',
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    )
                  else
                    ...audit.cast<Map>().asMap().entries.map((entry) {
                      final i = entry.key;
                      final log = entry.value;
                      final aColor =
                          _auditColor(log['action']?.toString() ?? '');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Timeline dot + line
                            SizedBox(
                              width: 20,
                              child: Column(children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                      color: aColor,
                                      shape: BoxShape.circle),
                                ),
                                if (i < audit.length - 1)
                                  Container(
                                    width: 2,
                                    height: 28,
                                    color: hcSlate.withValues(alpha: 0.15),
                                  ),
                              ]),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Text(
                                      (log['by_name'] ?? 'system')
                                          .toString(),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2),
                                      decoration: BoxDecoration(
                                          color: aColor
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(5)),
                                      child: Text(
                                        (log['action'] ?? '')
                                            .toString(),
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: aColor),
                                      ),
                                    ),
                                    if (log['status_to'] != null) ...[
                                      const SizedBox(width: 6),
                                      Text('→ ${_doseStatusDisplay(log['status_to'].toString())}',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: hcDoseStatusColor(
                                                  log['status_to']
                                                      ?.toString()),
                                              fontWeight:
                                                  FontWeight.w600)),
                                    ],
                                  ]),
                                  const SizedBox(height: 2),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 2,
                                    children: [
                                      Text(hcDateTime(log['at']),
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant)),
                                      if (log['dose_to'] != null)
                                        Text(
                                          '· dose ${log['dose_from'] ?? '—'} → ${log['dose_to']}',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant)),
                                      if (log['reason'] != null)
                                        Text('· ${log['reason']}',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DoseKpi extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final double bar;
  const _DoseKpi(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon,
      required this.bar});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(children: [
              Icon(icon, size: 15, color: color),
              const Spacer(),
              Text(value,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ]),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(label.toUpperCase(),
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant)),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: bar.clamp(0, 1),
                minHeight: 3,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;
  const _StatusRow(
      {required this.label,
      required this.count,
      required this.total,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total * 100).round() : 0;
    return Column(
      children: [
        Row(children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Text('$count',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          SizedBox(
              width: 36,
              child: Text('$pct%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant))),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (pct / 100).clamp(0, 1),
            minHeight: 4,
            backgroundColor: color.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _TinyChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _TinyChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(5)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _MetaItem({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: c),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 11, color: c)),
    ]);
  }
}

class _DoseActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _DoseActionBtn(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: FilledButton.tonal(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          visualDensity: VisualDensity.compact,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

// ═════════════════ MEDICATION SCHEDULES ═════════════════
// ═════════════════ MEDICATION SCHEDULES (mirrors nuxtfrontend patient-care medications tab) ═════════════════
class _MedsTab extends ConsumerWidget {
  final int id;
  final bool isAdmin;
  const _MedsTab({required this.id, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(_summaryProvider(id));
    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'pc-med-$id',
        backgroundColor: hcPurple,
        foregroundColor: Colors.white,
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (_) => MedicationScheduleSheet(patientId: id),
        ).then((saved) {
          if (saved == true) ref.invalidate(_summaryProvider(id));
        }),
        child: const Icon(Icons.add_rounded),
      ),
      body: HcAsyncBody(
        value: summary,
        onRefresh: () async => ref.refresh(_summaryProvider(id).future),
        builder: (s) {
        final meds = ((s['medications'] as List?) ?? []).cast<Map>();
        final medTotal = hcMoney(s['medication_total']);
        final activeCount = meds.where((m) => m['is_active'] == true).length;
        final takenCount =
            meds.fold(0, (sum, m) => sum + (m['doses_taken'] as int? ?? 0));
        final pendingCount =
            meds.fold(0, (sum, m) => sum + (m['doses_pending'] as int? ?? 0));
        final missedCount =
            meds.fold(0, (sum, m) => sum + (m['doses_missed'] as int? ?? 0));
        final attentionList = meds
            .where((m) =>
                (m['doses_missed'] as int? ?? 0) > 0 ||
                (m['doses_pending'] as int? ?? 0) > 0)
            .toList();
        final adherenceSignal = (takenCount + missedCount) > 0
            ? ((takenCount / (takenCount + missedCount)) * 100).round()
            : 100;
        final withUnitCost =
            meds.where((m) => m['unit_cost'] != null).length;

        if (meds.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.medication_liquid_rounded,
                    size: 48, color: hcSlate.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                const Text('No medication schedules recorded for this patient.',
                    style: TextStyle(color: hcSlate)),
              ],
            ),
          );
        }

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
          children: [
            // ── Header ──
            Row(children: [
              Icon(Icons.medication_liquid_rounded, color: const Color(0xFFD81B60), size: 22),
              const SizedBox(width: 8),
              const Text('Medication Schedule Monitoring',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: const Color(0xFFE91E63).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7)),
                child: Text('${meds.length} schedules',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD81B60))),
              ),
              if (isAdmin) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: hcTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7)),
                  child: Text(medTotal,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: hcTeal)),
                ),
              ],
            ]),
            const SizedBox(height: 12),

            // ── KPI row ──
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.85,
              children: [
                _MedKpi(
                  label: 'Active schedules',
                  value: '$activeCount',
                  icon: Icons.medication_rounded,
                  color: const Color(0xFFD81B60),
                ),
                _MedKpi(
                  label: 'Doses taken',
                  value: '$takenCount',
                  icon: Icons.check_circle_rounded,
                  color: hcGreen,
                ),
                _MedKpi(
                  label: 'Pending doses',
                  value: '$pendingCount',
                  icon: Icons.schedule_rounded,
                  color: hcAmber,
                ),
                _MedKpi(
                  label: 'Missed doses',
                  value: '$missedCount',
                  icon: Icons.warning_rounded,
                  color: missedCount > 0 ? hcRed : hcSlate,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Therapy Schedule Board ──
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.format_list_bulleted_rounded,
                          color: const Color(0xFFD81B60), size: 18),
                      const SizedBox(width: 8),
                      const Text('Therapy Schedule Board',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                      const Spacer(),
                      Text('Adherence & cost',
                          style: TextStyle(
                              fontSize: 10.5,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ]),
                    const SizedBox(height: 10),
                    // Table header
                    _MedTableHeader(isAdmin: isAdmin),
                    const SizedBox(height: 4),
                    ...meds.map((m) => _MedTableRow(m: m, isAdmin: isAdmin)),
                  ],
                ),
              ),
            ),

            // ── Clinical Attention ──
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              color: (missedCount > 0 ? hcRed : hcBlue).withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.medical_services_rounded,
                          color: missedCount > 0 ? hcRed : hcBlue, size: 18),
                      const SizedBox(width: 8),
                      const Text('Clinical Attention',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13.5)),
                    ]),
                    const SizedBox(height: 10),
                    if (attentionList.isEmpty)
                      Text('No medication schedules currently need intervention.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant))
                    else
                      ...attentionList.map((m) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Expanded(
                                      child: Text(
                                          m['medication_name']?.toString() ??
                                              '—',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                          color:
                                              ((m['doses_missed'] as int? ??
                                                          0) >
                                                      0
                                                  ? hcRed
                                                  : hcAmber)
                                                  .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                      child: Text(
                                          (m['doses_missed'] as int? ?? 0) > 0
                                              ? '${m['doses_missed']} missed'
                                              : '${m['doses_pending']} pending',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  (m['doses_missed'] as int? ??
                                                              0) >
                                                          0
                                                      ? hcRed
                                                      : hcAmber)),
                                    ),
                                  ]),
                                  const SizedBox(height: 4),
                                  Text(
                                      '${m['dose'] ?? ''} · ${hcLabel(m['route_label']?.toString() ?? m['route']?.toString())}'
                                      '${isAdmin && m['unit_cost'] != null ? ' · unit ${hcMoney(m['unit_cost'])}' : ''}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant)),
                                ],
                              ),
                            ),
                          )),
                  ],
                ),
              ),
            ),

            // ── Medication Costing (admin only) ──
            if (isAdmin)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.account_balance_rounded,
                            color: hcTeal, size: 18),
                        const SizedBox(width: 8),
                        const Text('Medication Costing',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 13.5)),
                      ]),
                      const SizedBox(height: 12),
                      _MedCostRow(
                          label: 'Accrued medication cost',
                          value: medTotal,
                          valueColor: hcTeal),
                      const SizedBox(height: 8),
                      _MedCostRow(
                          label: 'Schedules with unit cost',
                          value: '$withUnitCost'),
                      const SizedBox(height: 8),
                      _MedCostRow(
                        label: 'Adherence signal',
                        value: '$adherenceSignal%',
                        valueColor: adherenceSignal >= 85
                            ? hcGreen
                            : adherenceSignal >= 60
                                ? hcAmber
                                : hcRed,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
      ),
    );
  }
}

class _MedKpi extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MedKpi(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _MedTableHeader extends StatelessWidget {
  final bool isAdmin;
  const _MedTableHeader({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labelStyle = TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant);
    return Row(children: [
      const Expanded(flex: 3, child: Text('Medication', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
      Expanded(flex: 2, child: Text('Dose / Route', style: labelStyle)),
      Expanded(flex: 2, child: Text('Status', style: labelStyle)),
      SizedBox(width: isAdmin ? 32 : 28, child: Text('T', style: labelStyle, textAlign: TextAlign.center)),
      SizedBox(width: isAdmin ? 32 : 28, child: Text('P', style: labelStyle, textAlign: TextAlign.center)),
      SizedBox(width: isAdmin ? 32 : 28, child: Text('M', style: labelStyle, textAlign: TextAlign.center)),
      if (isAdmin) SizedBox(width: 56, child: Text('Cost', style: labelStyle, textAlign: TextAlign.right)),
    ]);
  }
}

class _MedTableRow extends StatelessWidget {
  final Map m;
  final bool isAdmin;
  const _MedTableRow({required this.m, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final isActive = m['is_active'] == true;
    final missed = m['doses_missed'] as int? ?? 0;
    final taken = m['doses_taken'] as int? ?? 0;
    final pending = m['doses_pending'] as int? ?? 0;
    final chipColor = isActive ? hcTeal : hcSlate;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
              top: BorderSide(
                  color: hcSlate.withValues(alpha: 0.08), width: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Medication name + instructions
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m['medication_name']?.toString() ?? '—',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 12.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((m['instructions'] ?? '').toString().isNotEmpty)
                      Text(m['instructions'].toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                  ],
                ),
              ),
              // Dose / Route
              Expanded(
                flex: 2,
                child: Text(
                  '${m['dose'] ?? ''} · ${hcLabel(m['route_label']?.toString() ?? m['route']?.toString())}',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              // Status
              Expanded(
                flex: 2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: chipColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5)),
                  child: Text(isActive ? 'Active' : 'Completed',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: chipColor)),
                ),
              ),
              // Taken
              SizedBox(
                width: isAdmin ? 32 : 28,
                child: _MedCountChip(value: '$taken', color: hcGreen),
              ),
              // Pending
              SizedBox(
                width: isAdmin ? 32 : 28,
                child: _MedCountChip(value: '$pending', color: hcAmber),
              ),
              // Missed
              SizedBox(
                width: isAdmin ? 32 : 28,
                child: _MedCountChip(
                    value: '$missed', color: missed > 0 ? hcRed : hcSlate),
              ),
              // Cost
              if (isAdmin)
                SizedBox(
                  width: 56,
                  child: Text(
                    m['amount'] != null ? hcMoney(m['amount']) : '—',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MedCountChip extends StatelessWidget {
  final String value;
  final Color color;
  const _MedCountChip({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(5)),
        child: Text(value,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ),
    );
  }
}

class _MedCostRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _MedCostRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label,
          style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const Spacer(),
      Text(value,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: valueColor)),
    ]);
  }
}

// ═════════════════ MEDICATION SCHEDULE FORM (mirrors nuxtfrontend medications/new.vue) ═════════════════

const _medCatalog = <(String, List<String>)>[
  ('Analgesics & Antipyretics', ['Paracetamol', 'Ibuprofen', 'Diclofenac', 'Naproxen', 'Aspirin', 'Tramadol', 'Codeine', 'Morphine']),
  ('Antibiotics', ['Amoxicillin', 'Amoxicillin/Clavulanate', 'Azithromycin', 'Ciprofloxacin', 'Doxycycline', 'Metronidazole', 'Ceftriaxone', 'Erythromycin', 'Cloxacillin', 'Cotrimoxazole']),
  ('Antihypertensives', ['Amlodipine', 'Lisinopril', 'Losartan', 'Enalapril', 'Hydrochlorothiazide', 'Atenolol', 'Bisoprolol', 'Carvedilol', 'Methyldopa', 'Nifedipine']),
  ('Antidiabetics', ['Metformin', 'Glibenclamide', 'Gliclazide', 'Insulin (Mixtard 30/70)', 'Insulin Glargine', 'Insulin Regular', 'Sitagliptin', 'Empagliflozin']),
  ('Cardiac & Lipid', ['Atorvastatin', 'Simvastatin', 'Rosuvastatin', 'Clopidogrel', 'Warfarin', 'Apixaban', 'Digoxin', 'Isosorbide Dinitrate']),
  ('Diuretics', ['Furosemide', 'Spironolactone', 'Hydrochlorothiazide', 'Indapamide']),
  ('Respiratory', ['Salbutamol', 'Salbutamol Inhaler', 'Beclomethasone Inhaler', 'Budesonide/Formoterol', 'Ipratropium', 'Montelukast', 'Theophylline', 'Prednisolone']),
  ('GI & Antiemetic', ['Omeprazole', 'Pantoprazole', 'Esomeprazole', 'Ranitidine', 'Famotidine', 'Ondansetron', 'Metoclopramide', 'Loperamide', 'Lactulose']),
  ('Endocrine & Hormones', ['Levothyroxine', 'Carbimazole', 'Hydrocortisone', 'Prednisolone', 'Dexamethasone']),
  ('Neuro & Psych', ['Amitriptyline', 'Sertraline', 'Fluoxetine', 'Citalopram', 'Diazepam', 'Lorazepam', 'Carbamazepine', 'Sodium Valproate', 'Phenytoin', 'Levetiracetam', 'Risperidone', 'Olanzapine', 'Haloperidol', 'Donepezil']),
  ('Allergy & Antihistamine', ['Cetirizine', 'Loratadine', 'Chlorpheniramine', 'Diphenhydramine']),
  ('Antimalarials & Antiparasitic', ['Artemether/Lumefantrine', 'Quinine', 'Albendazole', 'Mebendazole']),
  ('Topical & Wound', ['Hydrocortisone Cream', 'Silver Sulfadiazine', 'Povidone-Iodine', 'Mupirocin Ointment', 'Clotrimazole Cream']),
  ('Vitamins & Supplements', ['Folic Acid', 'Ferrous Sulphate', 'Vitamin B Complex', 'Vitamin D3', 'Calcium Carbonate', 'Multivitamin', 'Zinc Sulphate']),
];

const _medRoutes = <(String, String)>[
  ('oral', 'Oral'), ('iv', 'IV'), ('im', 'Intramuscular'), ('sc', 'Subcutaneous'),
  ('topical', 'Topical'), ('inhaled', 'Inhaled'), ('sublingual', 'Sublingual'),
  ('rectal', 'Rectal'), ('ophthalmic', 'Ophthalmic'), ('otic', 'Otic (ear)'),
  ('nasal', 'Nasal'), ('vaginal', 'Vaginal'), ('transdermal', 'Transdermal'), ('other', 'Other'),
];

const _doseChips = [
  '125 mg', '250 mg', '500 mg', '1 g', '5 mg', '10 mg', '20 mg', '25 mg',
  '50 mg', '75 mg', '100 mg', '1 tab', '2 tabs', '½ tab', '5 mL', '10 mL',
  '15 mL', '1 puff', '2 puffs', '2 drops', '4 IU', '8 IU', '10 IU',
];

class _MedFrequency {
  final String value;
  final String title;
  final List<String>? times;
  const _MedFrequency(this.value, this.title, this.times);
}

const _medFrequencies = <_MedFrequency>[
  _MedFrequency('OD', 'Once daily (OD)', ['08:00']),
  _MedFrequency('BD', 'Twice daily (BD)', ['08:00', '20:00']),
  _MedFrequency('TDS', 'Three times daily (TDS)', ['08:00', '14:00', '20:00']),
  _MedFrequency('QID', 'Four times daily (QID)', ['06:00', '12:00', '18:00', '22:00']),
  _MedFrequency('Q4H', 'Every 4 hours', ['00:00', '04:00', '08:00', '12:00', '16:00', '20:00']),
  _MedFrequency('Q6H', 'Every 6 hours', ['00:00', '06:00', '12:00', '18:00']),
  _MedFrequency('Q8H', 'Every 8 hours', ['08:00', '16:00', '00:00']),
  _MedFrequency('Q12H', 'Every 12 hours', ['08:00', '20:00']),
  _MedFrequency('AM', 'In the morning', ['08:00']),
  _MedFrequency('NOON', 'At noon', ['12:00']),
  _MedFrequency('PM', 'In the evening', ['18:00']),
  _MedFrequency('NOCTE', 'At bedtime', ['22:00']),
  _MedFrequency('WEEKLY', 'Once weekly', ['08:00']),
  _MedFrequency('PRN', 'As needed (PRN)', []),
  _MedFrequency('STAT', 'Stat (one-off)', ['08:00']),
  _MedFrequency('CUSTOM', 'Custom', null),
];

const _commonTimes = [
  '06:00', '08:00', '10:00', '12:00', '14:00', '16:00', '18:00', '20:00', '22:00',
];

const _instructionChips = [
  'Take with food', 'Take on empty stomach', 'Take with plenty of water',
  'Avoid grapefruit juice', 'Avoid alcohol', 'Do not crush or chew',
  'Shake well before use', 'Refrigerate after opening',
  'May cause drowsiness', 'Take at bedtime',
  'Complete the full course', 'Stop and call clinician if rash develops',
  'Monitor blood pressure', 'Monitor blood glucose',
  'Apply thinly to affected area', 'For external use only',
  'Rinse mouth after inhaler use',
];

const _durationPresets = <(int, String)>[
  (5, '5 days'), (7, '1 week'), (14, '2 weeks'),
  (30, '1 month'), (90, '3 months'), (0, 'Ongoing'),
];

/// Bottom-sheet form to create a medication schedule for a patient.
class MedicationScheduleSheet extends ConsumerStatefulWidget {
  final int patientId;
  const MedicationScheduleSheet({super.key, required this.patientId});

  @override
  ConsumerState<MedicationScheduleSheet> createState() =>
      _MedicationScheduleSheetState();
}

class _MedicationScheduleSheetState
    extends ConsumerState<MedicationScheduleSheet> {
  final _medName = TextEditingController();
  final _dose = TextEditingController();
  final _instructions = TextEditingController();
  String _route = 'oral';
  String _frequency = 'OD';
  List<String> _times = const ['08:00'];
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _requiresCaregiver = false;
  bool _active = true;
  bool _saving = false;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _medName.dispose();
    _dose.dispose();
    _instructions.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFrequencyChanged(String value) {
    final f = _medFrequencies.firstWhere((f) => f.value == value);
    setState(() {
      _frequency = value;
      if (f.times != null) {
        _times = List.from(f.times!);
      }
    });
  }

  void _toggleTime(String t) {
    setState(() {
      if (_times.contains(t)) {
        _times = _times.where((x) => x != t).toList()..sort();
      } else {
        _times = [..._times, t]..sort();
      }
    });
  }

  void _applyDuration(int days) {
    if (days == 0) {
      setState(() => _endDate = null);
      return;
    }
    setState(() {
      _endDate = _startDate.add(Duration(days: days - 1));
    });
  }

  void _appendInstruction(String text) {
    final cur = _instructions.text.trim();
    if (cur.toLowerCase().contains(text.toLowerCase())) return;
    _instructions.text = cur.isEmpty ? text : '$cur. $text';
  }

  Future<void> _save() async {
    if (_medName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medication name is required.')));
      return;
    }
    if (_dose.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dose is required.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/homecare/medication-schedules/', data: {
        'patient': widget.patientId,
        'medication_name': _medName.text.trim(),
        'dose': _dose.text.trim(),
        'route': _route,
        'frequency_cron': '',
        'times_of_day': _times,
        'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
        'end_date': _endDate != null
            ? DateFormat('yyyy-MM-dd').format(_endDate!)
            : null,
        'instructions': _instructions.text.trim(),
        'requires_caregiver': _requiresCaregiver,
        'is_active': _active,
      });
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Schedule created.')));
      }
    } catch (e) {
      String msg = 'Could not create schedule.';
      try {
        final data = (e as dynamic).response?.data;
        if (data is Map) {
          msg = data.values.map((v) => v.toString()).join('; ');
        }
      } catch (_) {}
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: Scaffold(
          body: Column(children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF6D28D9), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.medication_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NEW SCHEDULE',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4)),
                        const Text('Create medication schedule',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                      ],
                    )),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ]),
            ),
            // ── Scrollable form ──
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Section: Medication & dose ──
                      _FormSection(
                        icon: Icons.medication_rounded,
                        color: hcPurple,
                        title: 'Medication & dose',
                        child: Column(children: [
                          Autocomplete<String>(
                            optionsBuilder: (textEditingValue) {
                              final q = textEditingValue.text.toLowerCase();
                              if (q.isEmpty) return const Iterable.empty();
                              return _medCatalog
                                  .expand((c) => c.$2)
                                  .where((m) => m.toLowerCase().contains(q))
                                  .take(20);
                            },
                            onSelected: (v) => _medName.text = v,
                            fieldViewBuilder: (_, controller, focusNode, onSubmitted) {
                              controller.text = _medName.text;
                              controller.addListener(() {
                                _medName.text = controller.text;
                              });
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  labelText: 'Medication *',
                                  prefixIcon: Icon(Icons.medication_rounded),
                                  hintText: 'Search medication…',
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: _route,
                            decoration: const InputDecoration(
                              labelText: 'Route',
                              prefixIcon: Icon(Icons.colorize_rounded),
                            ),
                            items: _medRoutes
                                .map((r) => DropdownMenuItem(
                                    value: r.$1, child: Text(r.$2)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _route = v ?? 'oral'),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _dose,
                            decoration: const InputDecoration(
                              labelText: 'Dose *',
                              prefixIcon: Icon(Icons.scale_rounded),
                              hintText: 'e.g. 500 mg, 10 mL, 1 tab',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (final d in _doseChips)
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _dose.text = d),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _dose.text == d
                                          ? hcPurple
                                          : hcPurple.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Text(d,
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: _dose.text == d
                                                ? Colors.white
                                                : hcPurple)),
                                  ),
                                ),
                            ],
                          ),
                        ]),
                      ),

                      // ── Section: Frequency & timing ──
                      _FormSection(
                        icon: Icons.repeat_rounded,
                        color: hcIndigo,
                        title: 'Frequency & timing',
                        child: Column(children: [
                          DropdownButtonFormField<String>(
                            initialValue: _frequency,
                            decoration: const InputDecoration(
                              labelText: 'Frequency',
                              prefixIcon: Icon(Icons.repeat_rounded),
                            ),
                            items: _medFrequencies
                                .map((f) => DropdownMenuItem(
                                    value: f.value, child: Text(f.title)))
                                .toList(),
                            onChanged: (v) =>
                                _onFrequencyChanged(v ?? 'OD'),
                          ),
                          const SizedBox(height: 10),
                          Text('Times of day',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurfaceVariant)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (final t in _commonTimes)
                                FilterChip(
                                  label: Text(t),
                                  selected: _times.contains(t),
                                  onSelected: (_) => _toggleTime(t),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                          if (_times.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('PRN (as needed) — no fixed times',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: cs.onSurfaceVariant)),
                            ),
                        ]),
                      ),

                      // ── Section: Schedule window ──
                      _FormSection(
                        icon: Icons.calendar_month_rounded,
                        color: hcTeal,
                        title: 'Schedule window',
                        child: Column(children: [
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _startDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setState(() => _startDate = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Start date *',
                                prefixIcon:
                                    Icon(Icons.calendar_month_rounded),
                              ),
                              child: Text(
                                  DateFormat('dd MMM yyyy').format(_startDate)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _endDate ?? _startDate,
                                firstDate: _startDate,
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setState(() => _endDate = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'End date (optional)',
                                prefixIcon: Icon(Icons.event_rounded),
                              ),
                              child: Text(_endDate != null
                                  ? DateFormat('dd MMM yyyy')
                                      .format(_endDate!)
                                  : 'Ongoing'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (final d in _durationPresets)
                                GestureDetector(
                                  onTap: () => _applyDuration(d.$1),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: hcTeal.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(7),
                                      border: _endDate != null &&
                                          d.$1 > 0 &&
                                          _endDate!.difference(_startDate).inDays ==
                                              d.$1 - 1
                                          ? Border.all(color: hcTeal, width: 1.5)
                                          : null,
                                    ),
                                    child: Text(d.$2,
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: hcTeal)),
                                  ),
                                ),
                            ],
                          ),
                        ]),
                      ),

                      // ── Section: Instructions ──
                      _FormSection(
                        icon: Icons.info_rounded,
                        color: hcAmber,
                        title: 'Instructions',
                        child: Column(children: [
                          TextField(
                            controller: _instructions,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Patient/caregiver instructions',
                              prefixIcon: Icon(Icons.note_rounded),
                              hintText:
                                  'e.g. Take with food. Avoid grapefruit juice.',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (final i in _instructionChips)
                                GestureDetector(
                                  onTap: () => _appendInstruction(i),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: hcAmber.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      Icon(Icons.add_rounded, size: 12, color: hcAmber),
                                      const SizedBox(width: 2),
                                      Text(i, style: TextStyle(fontSize: 10, color: hcAmber)),
                                    ]),
                                  ),
                                ),
                            ],
                          ),
                        ]),
                      ),

                      // ── Section: Status & administration ──
                      _FormSection(
                        icon: Icons.flag_rounded,
                        color: hcGreen,
                        title: 'Status & administration',
                        child: Column(children: [
                          Row(children: [
                            const Text('Active'),
                            const Spacer(),
                            Switch(
                              value: _active,
                              onChanged: (v) => setState(() => _active = v),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(children: [
                            Expanded(
                              child: Text(
                                'Requires caregiver to administer',
                                style: TextStyle(fontSize: 13, color: cs.onSurface),
                              ),
                            ),
                            Switch(
                              value: _requiresCaregiver,
                              activeTrackColor: hcAmber.withValues(alpha: 0.3),
                              onChanged: (v) => setState(() => _requiresCaregiver = v),
                            ),
                          ],
                          ),
                        ]),
                      ),

                      const SizedBox(height: 20),

                      // ── Save button ──
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: hcPurple,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_rounded, size: 20),
                          label: Text(_saving ? 'Saving…' : 'Create schedule',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final Widget child;
  const _FormSection(
      {required this.icon,
      required this.color,
      required this.title,
      required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(title.toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: color)),
          ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ═════════════════ DRAINS & LINES ═════════════════
class _LinesTab extends ConsumerWidget {
  final int id;
  const _LinesTab({required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(_pcLinesProvider(id));
    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'pc-line-$id',
        backgroundColor: hcIndigo,
        foregroundColor: Colors.white,
        onPressed: () => _openRegisterLine(context, ref),
        child: const Icon(Icons.add_rounded),
      ),
      body: HcAsyncBody(
        value: lines,
        onRefresh: () async => ref.refresh(_pcLinesProvider(id).future),
        builder: (list) {
          final rows = list.cast<Map>();
          if (rows.isEmpty) {
            return const Center(child: Text('No active drains or lines.'));
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            itemBuilder: (_, i) {
              final l = rows[i];
              final overdue = l['is_overdue'] == true;
              final days = l['days_in_situ'];
              final maxDays = l['max_days'];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.device_hub_rounded,
                              color: overdue ? hcRed : hcIndigo),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                                (l['name'] ?? l['line_type_label'] ?? '—')
                                    .toString(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5)),
                          ),
                          HcStatusChip(
                              label: overdue ? 'OVERDUE' : 'ACTIVE',
                              color: overdue ? hcRed : hcGreen),
                          const SizedBox(width: 6),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.logout_rounded,
                                size: 18, color: hcRed),
                            tooltip: 'Remove line',
                            onPressed: () =>
                                _removeLine(context, ref, l),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                            '${l['line_type_label'] ?? ''}'
                            '${(l['site'] ?? '').toString().isNotEmpty ? ' · ${l['site']}' : ''}'
                            ' · inserted ${hcDate(l['insert_date'])}',
                            style: const TextStyle(fontSize: 11.5)),
                        if (days != null && maxDays != null) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ((days as num) / (maxDays as num))
                                  .clamp(0, 1)
                                  .toDouble(),
                              minHeight: 6,
                              color: overdue ? hcRed : hcTeal,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text('$days / $maxDays days in situ',
                              style: const TextStyle(fontSize: 10.5)),
                        ],
                      ]),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _removeLine(
      BuildContext context, WidgetRef ref, Map line) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove drain / line'),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(labelText: 'Removal reason'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: hcRed),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/homecare/drains-lines/${line['id']}/remove/',
          data: {'removal_reason': reason.text.trim()});
      ref.invalidate(_pcLinesProvider(id));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not remove line.')));
      }
    }
  }

  void _openRegisterLine(BuildContext context, WidgetRef ref) {
    final name = TextEditingController();
    final site = TextEditingController();
    final indication = TextEditingController();
    String lineType = 'catheter';
    bool saving = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Register drain / line',
                  style:
                      TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: lineType,
                decoration: const InputDecoration(labelText: 'Type *'),
                items: const [
                  DropdownMenuItem(
                      value: 'catheter', child: Text('Urinary catheter')),
                  DropdownMenuItem(
                      value: 'central_line', child: Text('Central line')),
                  DropdownMenuItem(value: 'picc', child: Text('PICC')),
                  DropdownMenuItem(
                      value: 'iv_peripheral',
                      child: Text('IV peripheral')),
                  DropdownMenuItem(
                      value: 'wound_drain', child: Text('Wound drain')),
                  DropdownMenuItem(
                      value: 'nasogastric', child: Text('Nasogastric tube')),
                  DropdownMenuItem(
                      value: 'chest_tube', child: Text('Chest tube')),
                  DropdownMenuItem(
                      value: 'ventilator', child: Text('Ventilator')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) =>
                    setSheetState(() => lineType = v ?? 'catheter'),
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: name,
                  decoration:
                      const InputDecoration(labelText: 'Name / ID')),
              const SizedBox(height: 10),
              TextField(
                  controller: site,
                  decoration: const InputDecoration(
                      labelText: 'Insertion site')),
              const SizedBox(height: 10),
              TextField(
                  controller: indication,
                  decoration:
                      const InputDecoration(labelText: 'Indication')),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: hcIndigo),
                  onPressed: saving
                      ? null
                      : () async {
                          setSheetState(() => saving = true);
                          try {
                            final dio = ref.read(dioProvider);
                            await dio
                                .post('/homecare/drains-lines/', data: {
                              'patient': id,
                              'line_type': lineType,
                              'name': name.text.trim(),
                              'site': site.text.trim(),
                              'indication': indication.text.trim(),
                              'insert_date': DateTime.now()
                                  .toIso8601String()
                                  .substring(0, 10),
                            });
                            ref.invalidate(_pcLinesProvider(id));
                            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                          } catch (_) {
                            setSheetState(() => saving = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Could not register line.')));
                            }
                          }
                        },
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Register'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════ SUPPLIES (admin) ═════════════════
class _SuppliesTab extends ConsumerWidget {
  final int id;
  const _SuppliesTab({required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(_summaryProvider(id));
    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'pc-supply-$id',
        backgroundColor: hcAmber,
        foregroundColor: Colors.white,
        onPressed: () => _openAddSupply(context, ref),
        child: const Icon(Icons.add_rounded),
      ),
      body: HcAsyncBody(
        value: summary,
        onRefresh: () async => ref.refresh(_summaryProvider(id).future),
        builder: (s) {
          final supplies = ((s['supplies'] as List?) ?? []).cast<Map>();
          final currency = (s['currency'] ?? 'KSh').toString();
          if (supplies.isEmpty) {
            return const Center(child: Text('No supplies on record.'));
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: supplies.length,
            itemBuilder: (_, i) {
              final sp = supplies[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_rounded,
                      color: hcAmber),
                  title: Text(sp['name']?.toString() ?? '—',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13)),
                  subtitle: Text(
                      '${hcLabel(sp['category_label']?.toString() ?? sp['category']?.toString())} · ${sp['quantity'] ?? 1} ${sp['unit'] ?? 'unit'}'
                      '${sp['replace_due'] != null ? ' · replace ${hcDate(sp['replace_due'])}' : ''}',
                      style: const TextStyle(fontSize: 11.5)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(hcMoney(sp['total_cost'], currency: currency),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 12)),
                      HcStatusChip(
                          label: sp['billable'] == true
                              ? 'BILLABLE'
                              : 'INCLUDED',
                          color: sp['billable'] == true
                              ? hcTeal
                              : hcSlate),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openAddSupply(BuildContext context, WidgetRef ref) {
    final name = TextEditingController();
    final qty = TextEditingController(text: '1');
    final price = TextEditingController();
    final maxDays = TextEditingController();
    String category = 'other';
    bool billable = true;
    bool saving = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add medical supply',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 12),
                TextField(
                    controller: name,
                    decoration:
                        const InputDecoration(labelText: 'Supply name *')),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final c in const [
                    ('feeding', 'Feeding'),
                    ('catheter', 'Catheter'),
                    ('wound', 'Wound'),
                    ('iv', 'IV'),
                    ('respiratory', 'Respiratory'),
                    ('incontinence', 'Incontinence'),
                    ('diabetic', 'Diabetic'),
                    ('hygiene', 'Hygiene'),
                    ('other', 'Other'),
                  ])
                    ChoiceChip(
                      selected: category == c.$1,
                      label: Text(c.$2),
                      onSelected: (_) =>
                          setSheetState(() => category = c.$1),
                    ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: qty,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Quantity'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                          controller: price,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Unit price',
                              prefixText: 'KSh '))),
                ]),
                const SizedBox(height: 10),
                TextField(
                    controller: maxDays,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Max use days (optional)')),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: billable,
                  title: const Text('Billable',
                      style: TextStyle(fontSize: 13.5)),
                  onChanged: (v) => setSheetState(() => billable = v),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style:
                        FilledButton.styleFrom(backgroundColor: hcAmber),
                    onPressed: saving
                        ? null
                        : () async {
                            if (name.text.trim().isEmpty) return;
                            setSheetState(() => saving = true);
                            try {
                              final dio = ref.read(dioProvider);
                              await dio.post(
                                  '/homecare/medical-supplies/',
                                  data: {
                                    'patient': id,
                                    'name': name.text.trim(),
                                    'category': category,
                                    'quantity':
                                        int.tryParse(qty.text) ?? 1,
                                    'unit_price':
                                        double.tryParse(price.text) ?? 0,
                                    if (maxDays.text.isNotEmpty)
                                      'max_use_days':
                                          int.tryParse(maxDays.text),
                                    'billable': billable,
                                  });
                              ref.invalidate(_summaryProvider(id));
                              if (sheetCtx.mounted) {
                                Navigator.pop(sheetCtx);
                              }
                            } catch (_) {
                              setSheetState(() => saving = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Could not add supply.')));
                              }
                            }
                          },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Add supply'),
                  ),
                ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════ NOTES ═════════════════
class _NotesTab extends ConsumerWidget {
  final int id;
  const _NotesTab({required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(_pcNotesProvider(id));
    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'pc-note-$id',
        backgroundColor: hcTeal,
        foregroundColor: Colors.white,
        onPressed: () => _openAddNote(context, ref),
        child: const Icon(Icons.add_rounded),
      ),
      body: HcAsyncBody(
        value: notes,
        onRefresh: () async => ref.refresh(_pcNotesProvider(id).future),
        builder: (list) {
          final rows = list.cast<Map>().toList()
            ..sort((a, b) => (b['recorded_at'] ?? '')
                .toString()
                .compareTo((a['recorded_at'] ?? '').toString()));
          if (rows.isEmpty) {
            return const Center(child: Text('No care notes yet.'));
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            itemBuilder: (_, i) {
              final n = rows[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          HcAvatar(
                              name: n['caregiver_name']?.toString(),
                              size: 32,
                              color: hcTeal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      n['caregiver_name']?.toString() ??
                                          '—',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.5)),
                                  Text(hcDateTime(n['recorded_at']),
                                      style:
                                          const TextStyle(fontSize: 10.5)),
                                ]),
                          ),
                          HcStatusChip(
                              label:
                                  hcLabel(n['category']?.toString()),
                              color: hcBlue),
                        ]),
                        const SizedBox(height: 8),
                        Text(n['content']?.toString() ?? '',
                            style: const TextStyle(fontSize: 12.5)),
                      ]),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openAddNote(BuildContext context, WidgetRef ref) {
    final content = TextEditingController();
    String category = 'observation';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add care note',
                  style:
                      TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                for (final c in const [
                  ('observation', 'Observation'),
                  ('incident', 'Incident'),
                  ('general', 'General'),
                ])
                  ChoiceChip(
                    selected: category == c.$1,
                    label: Text(c.$2),
                    onSelected: (_) =>
                        setSheetState(() => category = c.$1),
                  ),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: content,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Note *',
                    hintText: 'What did you observe or do?'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: hcTeal),
                  onPressed: () async {
                    if (content.text.trim().isEmpty) return;
                    try {
                      final dio = ref.read(dioProvider);
                      // caregiver FK is stamped server-side from the acting user
                      final me = await dio
                          .get('/homecare/caregivers/me/')
                          .catchError((_) => throw Exception());
                      await dio.post('/homecare/notes/', data: {
                        'patient': id,
                        'caregiver': me.data['id'],
                        'category': category,
                        'content': content.text.trim(),
                      });
                      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      ref.invalidate(_pcNotesProvider(id));
                    } catch (_) {
                      if (sheetCtx.mounted) {
                        ScaffoldMessenger.of(sheetCtx).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Could not save note (caregiver profile required).')));
                      }
                    }
                  },
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Save note'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════ TREATMENT PLAN ═════════════════

const _tpPurple = Color(0xFF7C3AED);
const _tpPurpleDark = Color(0xFF6D28D9);

Color _tpStatusColor(String? s) => switch (s) {
      'active' => hcGreen,
      'paused' => hcAmber,
      'completed' => hcBlue,
      'cancelled' => hcSlate,
      _ => hcSlate,
    };

String _tpStatusLabel(String? s) => switch (s) {
      'active' => 'Active',
      'paused' => 'Paused',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => hcLabel(s),
    };

const _tpStatusOptions = <(String, String)>[
  ('Active', 'active'),
  ('Paused', 'paused'),
  ('Completed', 'completed'),
  ('Cancelled', 'cancelled'),
];

List<(String, String, IconData, Color)> _tpTransitionsFor(String? status) {
  switch (status) {
    case 'active':
      return const [
        ('paused', 'Pause', Icons.pause_rounded, hcAmber),
        ('completed', 'Complete', Icons.check_rounded, hcGreen),
        ('cancelled', 'Cancel', Icons.cancel_rounded, hcSlate),
      ];
    case 'paused':
      return const [
        ('active', 'Resume', Icons.play_arrow_rounded, hcGreen),
        ('cancelled', 'Cancel', Icons.cancel_rounded, hcSlate),
      ];
    case 'cancelled':
      return const [
        ('active', 'Reactivate', Icons.restart_alt_rounded, hcGreen),
      ];
    default:
      return const [];
  }
}

const _planTitleOptions = [
  'Diabetes Management Plan',
  'Hypertension Care Plan',
  'Post-Surgical Recovery Plan',
  'Wound Care Plan',
  'Palliative Care Plan',
  'Stroke Rehabilitation Plan',
  'Chronic Kidney Disease Plan',
  'COPD Management Plan',
  'Heart Failure Care Plan',
  'Dementia Support Plan',
  'Elderly Daily Living Support',
  'Maternal & Newborn Care Plan',
  'Paediatric Home Care Plan',
  'Mental Health Support Plan',
  'Physiotherapy & Mobility Plan',
  'Nutritional Support Plan',
  'Medication Adherence Plan',
];

List<String> _tpSmartGoalOptions(String diagnosis) {
  final dx = diagnosis.toLowerCase().trim();
  final goals = <String>[
    '100% medication adherence verified weekly',
    'No hospital readmission within 30 days of discharge',
    'Independent in activities of daily living (ADLs) within 8 weeks',
    'Pain score ≤3/10 within 2 weeks',
    'Achieve restful sleep ≥6 hours/night within 4 weeks',
  ];
  if (dx.isNotEmpty) {
    if (dx.contains('diabetes') || dx.contains(' dm')) {
      goals.addAll([
        'Achieve HbA1c <7.0% within 3 months',
        'Daily blood glucose monitoring logged for 90 days',
      ]);
    }
    if (dx.contains('hypertension') || dx.contains('htn')) {
      goals.addAll([
        'Reduce blood pressure to <130/80 mmHg within 8 weeks',
        'Daily home BP readings logged for 12 weeks',
      ]);
    }
    if (dx.contains('heart') || dx.contains('cardiac')) {
      goals.addAll([
        'No hospital readmission for cardiac cause within 30 days',
        'NYHA class improved by 1 grade within 12 weeks',
      ]);
    }
    if (dx.contains('copd') || dx.contains('asthma')) {
      goals.addAll([
        'Improve oxygen saturation to ≥95% on room air within 4 weeks',
        'Smoking cessation maintained for 90 days',
      ]);
    }
    if (dx.contains('stroke') || dx.contains('cva')) {
      goals.addAll([
        'Walk independently for 15 minutes daily within 6 weeks',
        'Improve Barthel Index score by 20 points within 12 weeks',
      ]);
    }
    if (dx.contains('wound') || dx.contains('ulcer')) {
      goals.addAll([
        'Achieve full wound closure within 4 weeks',
        'No signs of wound infection over 30 days',
      ]);
    }
  }
  return goals;
}

String _goalText(dynamic g) {
  if (g is String) return g;
  if (g is Map) return g['text']?.toString() ?? g['goal']?.toString() ?? '';
  return '';
}

List<String> _parseGoals(dynamic goals) {
  if (goals is List) {
    return goals.map(_goalText).where((s) => s.isNotEmpty).toList();
  }
  return [];
}

String _medFrequency(Map m) {
  if (m['frequency_cron'] != null && m['frequency_cron'].toString().isNotEmpty) {
    return m['frequency_cron'].toString();
  }
  if (m['times_of_day'] is List && (m['times_of_day'] as List).isNotEmpty) {
    return (m['times_of_day'] as List).join(', ');
  }
  return 'As needed';
}

class _PlanTab extends ConsumerWidget {
  final int id;
  const _PlanTab({required this.id});

  void _openCreateSheet(BuildContext context, WidgetRef ref) {
    final summary = ref.read(_summaryProvider(id)).valueOrNull;
    final diagnosis =
        (summary?['patient'] as Map?)?['primary_diagnosis']?.toString() ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PlanCreateSheet(patientId: id, initialDiagnosis: diagnosis),
    ).then((saved) {
      if (saved == true) ref.invalidate(_pcPlansProvider(id));
    });
  }

  void _openViewSheet(BuildContext context, WidgetRef ref, Map plan,
      Map<int, List<Map>> tpMedsMap) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PlanViewSheet(
        patientId: id,
        plan: plan,
        meds: tpMedsMap[plan['id'] as int?] ?? [],
      ),
    ).then((changed) {
      if (changed == true) ref.invalidate(_pcPlansProvider(id));
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(_pcPlansProvider(id));
    final summary = ref.watch(_summaryProvider(id));

    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'pc-plan-$id',
        backgroundColor: _tpPurple,
        foregroundColor: Colors.white,
        onPressed: () => _openCreateSheet(context, ref),
        child: const Icon(Icons.add_rounded),
      ),
      body: HcAsyncBody(
        value: plans,
        onRefresh: () async => ref.refresh(_pcPlansProvider(id).future),
        builder: (list) {
          final rows = list.cast<Map>();
          final allMeds = ((summary.valueOrNull?['medications'] as List?) ?? [])
              .cast<Map>()
              .where((m) => m['is_active'] == true)
              .toList();
          final tpMedsMap = <int, List<Map>>{};
          for (final m in allMeds) {
            final pid = m['treatment_plan'] as int?;
            if (pid != null) {
              tpMedsMap.putIfAbsent(pid, () => []).add(m);
            }
          }
          final activePlans = rows.where((p) => p['status'] == 'active');
          final pausedPlans = rows.where((p) => p['status'] == 'paused');
          final completedPlans = rows.where((p) => p['status'] == 'completed');
          final totalPending =
              allMeds.fold(0, (s, m) => s + (m['upcoming_doses'] as int? ?? 0));
          final caregiver =
              (summary.valueOrNull?['caregivers'] as Map?)?['primary'];
          final caregiverName =
              caregiver is Map ? caregiver['name']?.toString() : null;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
            children: [
              // ── Header ──
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_tpPurple, _tpPurpleDark]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.assignment_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Treatment Plan',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text('Diagnosis, goals, medications & progress',
                          style: TextStyle(fontSize: 11, color: hcSlate)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              // ── Stats cards ──
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.2,
                children: [
                  HcKpi(
                      label: 'Active Plans',
                      value: '${activePlans.length}',
                      icon: Icons.check_circle_rounded,
                      color: hcGreen),
                  HcKpi(
                      label: 'Paused',
                      value: '${pausedPlans.length}',
                      icon: Icons.pause_circle_rounded,
                      color: hcAmber),
                  HcKpi(
                      label: 'Med Schedules',
                      value: '${allMeds.length}',
                      icon: Icons.medication_rounded,
                      color: hcTeal),
                  HcKpi(
                      label: 'Completed',
                      value: '${completedPlans.length}',
                      icon: Icons.flag_rounded,
                      color: hcSlate),
                ],
              ),
              const SizedBox(height: 14),
              // ── Plan cards ──
              if (rows.isEmpty)
                _buildEmptyState(context, ref)
              else
                ...rows.map((p) => _buildPlanCard(context, ref, p, tpMedsMap)),
              const SizedBox(height: 14),
              // ── Active Medications ──
              if (allMeds.isNotEmpty) ...[
                _buildActiveMedsCard(context, allMeds),
                const SizedBox(height: 14),
              ],
              // ── Plan Summary ──
              _buildSummaryCard(context, ref, rows, allMeds, totalPending, caregiverName),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.assignment_outlined, size: 48, color: hcSlate.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          const Text('No treatment plans', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text(
              'Create a treatment plan to define care goals and medication schedules.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: hcSlate)),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _tpPurple),
            onPressed: () => _openCreateSheet(context, ref),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create First Plan'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
      BuildContext context, WidgetRef ref, Map p, Map<int, List<Map>> tpMedsMap) {
    final status = p['status']?.toString();
    final goals = _parseGoals(p['goals']);
    final planMeds = tpMedsMap[p['id'] as int?] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: _tpPurple.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Title row
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _tpPurple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.assignment_rounded, color: _tpPurple, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Text(p['title']?.toString() ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  HcStatusChip(
                      label: _tpStatusLabel(status), color: _tpStatusColor(status)),
                  if (p['medication_count'] != null && (p['medication_count'] as num) > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _tpPurple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.medication_rounded, size: 11, color: _tpPurple),
                        const SizedBox(width: 3),
                        Text('${p['medication_count']} meds',
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w700, color: _tpPurple)),
                      ]),
                    ),
                ],
              ),
            ),
          ]),
          if ((p['diagnosis'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(p['diagnosis'].toString(),
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          // Dates
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              Icon(Icons.calendar_today_rounded,
                  size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(hcDate(p['start_date']),
                  style: TextStyle(
                      fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              if (p['end_date'] != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.event_rounded,
                    size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(hcDate(p['end_date']),
                    style: TextStyle(
                        fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ]),
          ),
          // Goals
          if (goals.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Goals', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final g in goals)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: hcTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.track_changes_rounded, size: 10, color: hcTeal),
                      const SizedBox(width: 3),
                      Text(g, style: const TextStyle(fontSize: 10, color: hcTeal)),
                    ]),
                  ),
              ],
            ),
          ],
          // Expandable meds
          if (planMeds.isNotEmpty) ...[
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 0),
              dense: true,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              title: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.medication_rounded, size: 14, color: _tpPurple),
                const SizedBox(width: 4),
                Text('Medication Schedules (${planMeds.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
              children: [
                for (final m in planMeds)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _tpPurple.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(m['medication_name']?.toString() ?? '—',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          Text('${m['dose'] ?? ''} · ${m['route'] ?? ''} · ${_medFrequency(m)}',
                              style: TextStyle(
                                  fontSize: 10.5,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        HcStatusChip(
                            label: m['is_active'] == true ? 'Active' : 'Inactive',
                            color: m['is_active'] == true ? hcGreen : hcSlate),
                        Text('${m['upcoming_doses'] ?? 0} pending',
                            style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ]),
                    ]),
                  ),
              ],
            ),
          ],
          // Actions
          const SizedBox(height: 8),
          Row(children: [
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                  backgroundColor: _tpPurple,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact),
              onPressed: () => _openViewSheet(context, ref, p, tpMedsMap),
              child: const Text('View', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                  backgroundColor: _tpPurple.withValues(alpha: 0.12),
                  foregroundColor: _tpPurple,
                  visualDensity: VisualDensity.compact),
              onPressed: () => _openViewSheet(context, ref, p, tpMedsMap),
              child: const Text('Edit', style: TextStyle(fontSize: 12)),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildActiveMedsCard(BuildContext context, List<Map> meds) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: _tpPurple.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.medication_liquid_rounded, color: _tpPurple, size: 18),
            const SizedBox(width: 8),
            const Text('Active Medications',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _tpPurple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${meds.length} active',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _tpPurple)),
            ),
          ]),
          const SizedBox(height: 10),
          for (final m in meds.take(8))
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _tpPurple.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _tpPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.medication_rounded, color: _tpPurple, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m['medication_name']?.toString() ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('${m['dose'] ?? ''} · ${m['route_label'] ?? m['route'] ?? ''}',
                        style: TextStyle(
                            fontSize: 10.5,
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${m['upcoming_doses'] ?? 0} due',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: m['is_active'] == true ? hcGreen : hcSlate)),
                  Text(_medFrequency(m),
                      style: TextStyle(
                          fontSize: 9.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ]),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, WidgetRef ref, List<Map> rows,
      List<Map> allMeds, int totalPending, String? caregiverName) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.bar_chart_rounded, color: _tpPurple, size: 18),
            const SizedBox(width: 8),
            const Text('Plan Summary',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ]),
          const SizedBox(height: 10),
          _summaryRow('Total plans', '${rows.length}'),
          _summaryRow('Active medication schedules', '${allMeds.length}', valueColor: hcGreen),
          _summaryRow('Pending doses', '$totalPending', valueColor: hcAmber),
          const Divider(height: 16),
          _summaryRow('Caregivers assigned', caregiverName ?? '—'),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: _tpPurple),
              onPressed: () => context.push('/homecare/treatment-plans'),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Open Treatment Plans'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: hcSlate)),
        Text(value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: valueColor)),
      ]),
    );
  }
}

// ── View / Edit sheet ──
class _PlanViewSheet extends ConsumerStatefulWidget {
  final int patientId;
  final Map plan;
  final List<Map> meds;
  const _PlanViewSheet({
    required this.patientId,
    required this.plan,
    required this.meds,
  });

  @override
  ConsumerState<_PlanViewSheet> createState() => _PlanViewSheetState();
}

class _PlanViewSheetState extends ConsumerState<_PlanViewSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _editMode = false;
  bool _saving = false;

  late final _titleCtl = TextEditingController(text: widget.plan['title'] ?? '');
  late final _diagnosisCtl = TextEditingController(text: widget.plan['diagnosis'] ?? '');
  late final _notesCtl = TextEditingController(text: widget.plan['notes'] ?? '');
  late String _startDate = widget.plan['start_date']?.toString() ?? '';
  late String _endDate = widget.plan['end_date']?.toString() ?? '';
  late String _status = widget.plan['status']?.toString() ?? 'active';
  late List<String> _goals;
  final _goalCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _goals = _parseGoals(widget.plan['goals']);
  }

  @override
  void dispose() {
    _tab.dispose();
    _titleCtl.dispose();
    _diagnosisCtl.dispose();
    _notesCtl.dispose();
    _goalCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final s = picked.toIso8601String().substring(0, 10);
      setState(() {
        if (isStart) {
          _startDate = s;
        } else {
          _endDate = s;
        }
      });
    }
  }

  Future<void> _changeStatus(String newStatus) async {
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/homecare/treatment-plans/${widget.plan['id']}/',
          data: {'status': newStatus});
      ref.invalidate(_pcPlansProvider(widget.patientId));
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Plan ${_tpStatusLabel(newStatus).toLowerCase()} successfully')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to update plan status.')));
      }
    }
  }

  Future<void> _saveEdit() async {
    if (_titleCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Plan title is required')));
      return;
    }
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/homecare/treatment-plans/${widget.plan['id']}/', data: {
        'title': _titleCtl.text.trim(),
        'diagnosis': _diagnosisCtl.text.trim(),
        'start_date': _startDate,
        'end_date': _endDate.isEmpty ? null : _endDate,
        'status': _status,
        'goals': _goals,
        'notes': _notesCtl.text.trim(),
      });
      ref.invalidate(_pcPlansProvider(widget.patientId));
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Plan updated successfully')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to save plan.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_editMode) return _buildEditForm(context);

    final plan = widget.plan;
    final status = plan['status']?.toString();
    final goals = _parseGoals(plan['goals']);

    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Gradient header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_tpPurple, _tpPurpleDark]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(children: [
                Row(children: [
                  const Icon(Icons.assignment_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(plan['title']?.toString() ?? 'Treatment Plan',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  HcStatusChip(
                      label: _tpStatusLabel(status), color: _tpStatusColor(status)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ]),
                const SizedBox(height: 8),
                TabBar(
                  controller: _tab,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  tabs: const [
                    Tab(icon: Icon(Icons.dashboard_rounded, size: 16), text: 'Overview'),
                    Tab(icon: Icon(Icons.medication_rounded, size: 16), text: 'Medications'),
                    Tab(icon: Icon(Icons.track_changes_rounded, size: 16), text: 'Goals'),
                  ],
                ),
              ]),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _buildOverviewTab(context, plan, status, goals),
                  _buildMedsTab(context),
                  _buildGoalsTab(context, goals),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context, Map plan, String? status, List<String> goals) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Chips
        Wrap(spacing: 6, runSpacing: 6, children: [
          _tpChip(Icons.calendar_today_rounded, hcDate(plan['start_date'])),
          if (plan['end_date'] != null)
            _tpChip(Icons.event_rounded, hcDate(plan['end_date'])),
          _tpChip(Icons.medication_rounded, '${widget.meds.length} medications'),
          _tpChip(Icons.track_changes_rounded, '${goals.length} goals'),
        ]),
        const SizedBox(height: 16),
        // Two-column grid
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Diagnosis',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(plan['diagnosis']?.toString() ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 12),
              Text('Status',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              HcStatusChip(label: _tpStatusLabel(status), color: _tpStatusColor(status)),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Start Date',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(hcDate(plan['start_date']),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 12),
              Text('Target End',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(plan['end_date'] != null ? hcDate(plan['end_date']) : 'Open-ended',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ),
        ]),
        if ((plan['notes'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Clinical Notes',
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(plan['notes'].toString(), style: const TextStyle(fontSize: 12)),
        ],
        const Divider(height: 28),
        // Status transition buttons
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final tr in _tpTransitionsFor(status))
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                  backgroundColor: tr.$4.withValues(alpha: 0.12),
                  foregroundColor: tr.$4,
                  visualDensity: VisualDensity.compact),
              onPressed: _saving ? null : () => _changeStatus(tr.$1),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(tr.$3, size: 15),
                const SizedBox(width: 4),
                Text(tr.$2, style: const TextStyle(fontSize: 12)),
              ]),
            ),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _tpPurple),
            onPressed: () => setState(() => _editMode = true),
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: const Text('Edit Plan'),
          ),
        ),
      ]),
    );
  }

  Widget _buildMedsTab(BuildContext context) {
    if (widget.meds.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.medication_rounded, size: 40, color: hcSlate.withValues(alpha: 0.4)),
          const SizedBox(height: 8),
          const Text('No medications scheduled', style: TextStyle(color: hcSlate)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: widget.meds.length,
      itemBuilder: (_, i) {
        final m = widget.meds[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _tpPurple.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _tpPurple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.medication_rounded, color: _tpPurple, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${m['medication_name'] ?? '—'} · ${m['dose'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                Text(
                    '${m['route_label'] ?? m['route'] ?? ''} · ${_medFrequency(m)}'
                    '${m['instructions'] != null && m['instructions'].toString().isNotEmpty ? ' · ${m['instructions']}' : ''}',
                    style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
            ),
            HcStatusChip(
                label: m['is_active'] == true ? 'Active' : 'Stopped',
                color: m['is_active'] == true ? hcGreen : hcSlate),
          ]),
        );
      },
    );
  }

  Widget _buildGoalsTab(BuildContext context, List<String> goals) {
    if (goals.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.track_changes_rounded, size: 40, color: hcSlate.withValues(alpha: 0.4)),
          const SizedBox(height: 8),
          const Text('No goals defined', style: TextStyle(color: hcSlate)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: goals.length,
      itemBuilder: (_, i) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _tpPurple.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: hcTeal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.track_changes_rounded, color: hcTeal, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Goal ${i + 1}',
                    style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                Text(goals[i], style: const TextStyle(fontSize: 13)),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildEditForm(BuildContext context) {
    final suggestions = _tpSmartGoalOptions(_diagnosisCtl.text);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => setState(() => _editMode = false),
        ),
        title: const Text('Edit Plan'),
        backgroundColor: _tpPurple,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: _titleCtl,
              decoration: const InputDecoration(
                labelText: 'Plan title *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _diagnosisCtl,
              decoration: const InputDecoration(
                labelText: 'Diagnosis',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.medical_services_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(true),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Start date',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today_rounded),
                    ),
                    child: Text(_startDate.isNotEmpty ? hcDate(_startDate) : '—',
                        style: const TextStyle(fontSize: 14)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(false),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'End date',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.event_rounded),
                    ),
                    child: Text(_endDate.isNotEmpty ? hcDate(_endDate) : '—',
                        style: const TextStyle(fontSize: 14)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flag_rounded),
              ),
              items: [
                for (final s in _tpStatusOptions)
                  DropdownMenuItem(value: s.$2, child: Text(s.$1)),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'active'),
            ),
            const SizedBox(height: 12),
            // Goals editor
            Text('Goals',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            if (_goals.isNotEmpty)
              Wrap(spacing: 5, runSpacing: 5, children: [
                for (final g in _goals)
                  Chip(
                    label: Text(g, style: const TextStyle(fontSize: 11)),
                    onDeleted: () => setState(() => _goals.remove(g)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: hcTeal.withValues(alpha: 0.1),
                  ),
              ]),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _goalCtl,
                  decoration: const InputDecoration(
                    hintText: 'Add a SMART goal…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addGoal(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: FilledButton.styleFrom(backgroundColor: _tpPurple),
                onPressed: _addGoal,
                icon: const Icon(Icons.add_rounded),
              ),
            ]),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Suggestions',
                  style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Wrap(spacing: 5, runSpacing: 5, children: [
                for (final s in suggestions.take(6))
                  ActionChip(
                    label: Text(s, style: const TextStyle(fontSize: 10)),
                    onPressed: () => setState(() => _goals.add(s)),
                    visualDensity: VisualDensity.compact,
                  ),
              ]),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Clinical notes',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note_alt_rounded),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _editMode = false),
                  child: const Text('Cancel'),
                ),
              ),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _tpPurple),
                  onPressed: _saving ? null : _saveEdit,
                  child: _saving
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Changes'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  void _addGoal() {
    final g = _goalCtl.text.trim();
    if (g.isNotEmpty && !_goals.contains(g)) {
      setState(() {
        _goals.add(g);
        _goalCtl.clear();
      });
    }
  }

  Widget _tpChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _tpPurple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: _tpPurple),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _tpPurple)),
      ]),
    );
  }
}

// ── Create sheet ──
class _PlanCreateSheet extends ConsumerStatefulWidget {
  final int patientId;
  final String initialDiagnosis;
  const _PlanCreateSheet({required this.patientId, required this.initialDiagnosis});

  @override
  ConsumerState<_PlanCreateSheet> createState() => _PlanCreateSheetState();
}

class _PlanCreateSheetState extends ConsumerState<_PlanCreateSheet> {
  final _titleCtl = TextEditingController();
  late final _diagnosisCtl = TextEditingController(text: widget.initialDiagnosis);
  final _notesCtl = TextEditingController();
  final _goalCtl = TextEditingController();
  late String _startDate = DateTime.now().toIso8601String().substring(0, 10);
  String _endDate = '';
  final List<String> _goals = [];
  bool _saving = false;
  String? _titleError;

  @override
  void dispose() {
    _titleCtl.dispose();
    _diagnosisCtl.dispose();
    _notesCtl.dispose();
    _goalCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final s = picked.toIso8601String().substring(0, 10);
      setState(() {
        if (isStart) {
          _startDate = s;
        } else {
          _endDate = s;
        }
      });
    }
  }

  void _addGoal() {
    final g = _goalCtl.text.trim();
    if (g.isNotEmpty && !_goals.contains(g)) {
      setState(() {
        _goals.add(g);
        _goalCtl.clear();
      });
    }
  }

  Future<void> _create() async {
    if (_titleCtl.text.trim().isEmpty) {
      setState(() => _titleError = 'Plan title is required');
      return;
    }
    setState(() {
      _saving = true;
      _titleError = null;
    });
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/homecare/treatment-plans/', data: {
        'patient': widget.patientId,
        'title': _titleCtl.text.trim(),
        'diagnosis': _diagnosisCtl.text.trim(),
        'start_date': _startDate,
        'end_date': _endDate.isEmpty ? null : _endDate,
        'status': 'active',
        'goals': _goals,
        'notes': _notesCtl.text.trim(),
      });
      ref.invalidate(_pcPlansProvider(widget.patientId));
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Treatment plan created successfully')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to create plan.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _tpSmartGoalOptions(_diagnosisCtl.text);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_titleCtl.text.isEmpty ? 'Create Treatment Plan' : _titleCtl.text),
        backgroundColor: _tpPurple,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Title with suggestions dropdown
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _titleCtl.text),
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) return _planTitleOptions;
                return _planTitleOptions
                    .where((o) => o.toLowerCase().contains(textEditingValue.text.toLowerCase()));
              },
              onSelected: (v) => setState(() => _titleCtl.text = v),
              fieldViewBuilder: (_, controller, focusNode, onSubmitted) {
                _titleCtl.text = controller.text;
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'Plan title *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.title_rounded),
                    errorText: _titleError,
                    hintText: 'Pick a template or type your own',
                  ),
                  onChanged: (v) => _titleCtl.text = v,
                  onSubmitted: (_) => onSubmitted(),
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _diagnosisCtl,
              decoration: const InputDecoration(
                labelText: 'Primary diagnosis',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.medical_services_rounded),
                helperText: 'Auto-filled from patient record',
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(true),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Start date *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today_rounded),
                    ),
                    child: Text(hcDate(_startDate), style: const TextStyle(fontSize: 14)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(false),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'End date',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.event_rounded),
                    ),
                    child: Text(_endDate.isNotEmpty ? hcDate(_endDate) : 'Optional',
                        style: TextStyle(fontSize: 14, color: _endDate.isEmpty ? hcSlate : null)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            // Goals
            Text('Care goals',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            if (_goals.isNotEmpty)
              Wrap(spacing: 5, runSpacing: 5, children: [
                for (final g in _goals)
                  Chip(
                    label: Text(g, style: const TextStyle(fontSize: 11)),
                    onDeleted: () => setState(() => _goals.remove(g)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: hcTeal.withValues(alpha: 0.1),
                  ),
              ]),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _goalCtl,
                  decoration: const InputDecoration(
                    hintText: 'Add a SMART goal…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addGoal(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: FilledButton.styleFrom(backgroundColor: _tpPurple),
                onPressed: _addGoal,
                icon: const Icon(Icons.add_rounded),
              ),
            ]),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Suggestions',
                  style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Wrap(spacing: 5, runSpacing: 5, children: [
                for (final s in suggestions.take(6))
                  ActionChip(
                    label: Text(s, style: const TextStyle(fontSize: 10)),
                    onPressed: () => setState(() => _goals.add(s)),
                    visualDensity: VisualDensity.compact,
                  ),
              ]),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Clinical notes',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note_alt_rounded),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _tpPurple),
                onPressed: _saving ? null : _create,
                icon: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_saving ? 'Creating…' : 'Create Plan'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═════════════════ DOCUMENTS ═════════════════
class _DocsTab extends StatelessWidget {
  final int id;
  const _DocsTab({required this.id});

  @override
  Widget build(BuildContext context) => HomecareDocsTab(patientId: id);
}

// ═════════════════ BILLING (admin only) ═════════════════
class _BillingTab extends ConsumerWidget {
  final int id;
  const _BillingTab({required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(_summaryProvider(id));
    return HcAsyncBody(
      value: summary,
      onRefresh: () async => ref.refresh(_summaryProvider(id).future),
      builder: (s) {
        final currency = (s['currency'] ?? 'KSh').toString();
        final bills = ((s['bills'] as List?) ?? []).cast<Map>();
        final payments = ((s['payments'] as List?) ?? []).cast<Map>();
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.4,
              children: [
                HcKpi(
                    label: 'Cost to date',
                    value: hcMoney(s['subtotal'], currency: currency),
                    icon: Icons.payments_rounded,
                    color: hcTeal),
                HcKpi(
                    label: 'Total paid',
                    value: hcMoney(s['total_paid'], currency: currency),
                    icon: Icons.check_circle_rounded,
                    color: hcGreen),
                HcKpi(
                    label: 'Balance',
                    value: hcMoney(s['balance'], currency: currency),
                    icon: Icons.account_balance_wallet_rounded,
                    color: (double.tryParse('${s['balance']}') ?? 0) > 0
                        ? hcRed
                        : hcSlate),
                HcKpi(
                    label: 'Care plan',
                    value: hcMoney(s['care_total'], currency: currency),
                    icon: Icons.volunteer_activism_rounded,
                    color: hcPurple),
              ],
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _generateBill(context, ref),
                  style: FilledButton.styleFrom(backgroundColor: hcTeal),
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  label: const Text('Generate bill'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _openRecordPayment(context, ref, currency),
                  icon: const Icon(Icons.paid_rounded, size: 18),
                  label: const Text('Record payment'),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            HcPanel(
              title: 'Cost breakdown',
              icon: Icons.pie_chart_rounded,
              color: hcTeal,
              child: Column(children: [
                for (final row in [
                  ('Care plan', s['care_total']),
                  ('Equipment', s['equipment_total']),
                  ('Supplies', s['supplies_total']),
                  ('Medications', s['medication_total']),
                  ('Subtotal', s['subtotal']),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(
                          child: Text(row.$1,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: row.$1 == 'Subtotal'
                                      ? FontWeight.w800
                                      : FontWeight.w500))),
                      Text(hcMoney(row.$2, currency: currency),
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: row.$1 == 'Subtotal'
                                  ? FontWeight.w800
                                  : FontWeight.w600)),
                    ]),
                  ),
              ]),
            ),
            HcPanel(
              title: 'Bills',
              subtitle: '${bills.length} generated',
              icon: Icons.receipt_long_rounded,
              color: hcBlue,
              child: bills.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Center(child: Text('No bills generated.')),
                    )
                  : Column(
                      children: bills.take(10).map((b) {
                        final status = b['status']?.toString();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const Icon(Icons.description_rounded,
                              color: hcBlue, size: 20),
                          title: Text(b['bill_number']?.toString() ?? '—',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5)),
                          subtitle: Text(hcDate(b['as_of']),
                              style: const TextStyle(fontSize: 11)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(hcMoney(b['total'], currency: currency),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12)),
                              HcStatusChip(
                                  label: hcLabel(status),
                                  color: status == 'paid'
                                      ? hcGreen
                                      : status == 'partial'
                                          ? hcAmber
                                          : hcBlue),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            HcPanel(
              title: 'Payments',
              subtitle: '${payments.length} recorded',
              icon: Icons.paid_rounded,
              color: hcGreen,
              child: payments.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Center(child: Text('No payments recorded.')),
                    )
                  : Column(
                      children: payments.take(10).map((p) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const Icon(Icons.paid_rounded,
                              color: hcGreen, size: 20),
                          title: Text(
                              hcMoney(p['amount'], currency: currency),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5)),
                          subtitle: Text(
                              '${hcLabel(p['method']?.toString())} · ${hcDateTime(p['paid_at'])}',
                              style: const TextStyle(fontSize: 11)),
                        );
                      }).toList(),
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _generateBill(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Generate bill'),
        content: const Text(
            "Snapshot the patient's current charges into a new bill?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Generate')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final dio = ref.read(dioProvider);
      final res =
          await dio.post('/homecare/patients/$id/generate-bill/', data: {});
      ref.invalidate(_summaryProvider(id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Bill ${res.data?['bill_number'] ?? ''} generated.')));
      }
    } catch (e) {
      String msg = 'Could not generate bill.';
      try {
        final data = (e as dynamic).response?.data;
        if (data is Map && data['detail'] != null) {
          msg = data['detail'].toString();
        }
      } catch (_) {}
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  void _openRecordPayment(
      BuildContext context, WidgetRef ref, String currency) {
    final amount = TextEditingController();
    final reference = TextEditingController();
    final notes = TextEditingController();
    String method = 'cash';
    bool saving = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Record payment',
                  style:
                      TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 14),
              TextField(
                controller: amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: 'Amount *', prefixText: '$currency '),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final m in const [
                  ('cash', 'Cash'),
                  ('mpesa', 'M-Pesa'),
                  ('card', 'Card'),
                  ('bank', 'Bank'),
                  ('insurance', 'Insurance'),
                  ('other', 'Other'),
                ])
                  ChoiceChip(
                    selected: method == m.$1,
                    label: Text(m.$2),
                    onSelected: (_) => setSheetState(() => method = m.$1),
                  ),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: reference,
                decoration: const InputDecoration(
                    labelText: 'Reference (receipt / txn code)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notes,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: hcGreen),
                  onPressed: saving
                      ? null
                      : () async {
                          final amt = double.tryParse(amount.text);
                          if (amt == null || amt <= 0) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Enter a valid amount.')));
                            return;
                          }
                          setSheetState(() => saving = true);
                          try {
                            final dio = ref.read(dioProvider);
                            await dio.post('/homecare/patient-payments/',
                                data: {
                                  'patient': id,
                                  'amount': amt,
                                  'method': method,
                                  if (reference.text.trim().isNotEmpty)
                                    'reference': reference.text.trim(),
                                  if (notes.text.trim().isNotEmpty)
                                    'notes': notes.text.trim(),
                                });
                            ref.invalidate(_summaryProvider(id));
                            if (sheetCtx.mounted) {
                              Navigator.pop(sheetCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Payment recorded.')));
                            }
                          } catch (_) {
                            setSheetState(() => saving = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Could not record payment.')));
                            }
                          }
                        },
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.paid_rounded, size: 18),
                  label: const Text('Save payment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════ ASSESSMENTS (worklist) ═════════════════
class _WorkEntry {
  final String key;
  final _AssessType type;
  final String frequency;
  final String startedAt;
  final dynamic backendId;
  const _WorkEntry(
      {required this.key,
      required this.type,
      required this.frequency,
      required this.startedAt,
      required this.backendId});
}

class _AssessmentsTab extends ConsumerStatefulWidget {
  final int id;
  const _AssessmentsTab({required this.id});

  @override
  ConsumerState<_AssessmentsTab> createState() => _AssessmentsTabState();
}

class _AssessmentsTabState extends ConsumerState<_AssessmentsTab> {
  String? _selectedKey;

  @override
  Widget build(BuildContext context) {
    final worklist = ref.watch(_pcWorklistProvider(widget.id));
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'pc-assess-${widget.id}',
        onPressed: () => _openAddAssessment(context),
        backgroundColor: hcTeal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add assessment'),
      ),
      body: HcAsyncBody(
        value: worklist,
        onRefresh: () async =>
            ref.refresh(_pcWorklistProvider(widget.id).future),
        builder: (sessions) => _buildBody(context, sessions.cast<Map>()),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<Map> sessions) {
    final entries = <_WorkEntry>[];
    for (final s in sessions) {
      final meta = _parseNotes(s['notes']);
      final key = meta['worklist_key']?.toString();
      if (key == null) continue;
      final type = _assessType(key);
      if (type == null) continue;
      final freq = (meta['frequency']?.toString().isNotEmpty ?? false)
          ? meta['frequency'].toString()
          : type.frequency;
      entries.add(_WorkEntry(
        key: key,
        type: type,
        frequency: freq,
        startedAt: s['assessed_at']?.toString() ?? '',
        backendId: s['id'],
      ));
    }
    if (entries.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.assignment_outlined, size: 48, color: hcSlate),
          const SizedBox(height: 12),
          const Text('No assessments in worklist'),
          const SizedBox(height: 4),
          const Text('Tap "Add assessment" to start tracking',
              style: TextStyle(fontSize: 12, color: hcSlate)),
        ]),
      );
    }
    final selectedKey = _selectedKey ?? entries.first.key;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: hcTeal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.assignment_rounded,
                color: hcTeal, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Assessment Worklist',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text('${entries.length} components · track, complete, monitor',
                    style: const TextStyle(fontSize: 11, color: hcSlate)),
              ])),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 12, runSpacing: 6, children: const [
          _Legend(Color(0xFF059669), 'On track'),
          _Legend(hcAmber, 'Due soon'),
          _Legend(hcRed, 'Overdue'),
          _Legend(hcSlate, 'Not started'),
        ]),
        const SizedBox(height: 14),
        for (final e in entries) _entryCard(context, e, selectedKey == e.key),
      ],
    );
  }

  Widget _entryCard(BuildContext context, _WorkEntry e, bool selected) {
    final histAsync =
        ref.watch(_pcAssessHistoryProvider((widget.id, e.key)));
    final hist = histAsync.valueOrNull?.cast<Map>() ?? const <Map>[];
    final lastItem = hist.isEmpty ? null : hist.first;
    final lastDone =
        lastItem == null ? null : _parseDate(lastItem['assessed_at']);
    final status = _computeStatus(lastDone, e.frequency);
    final (score, scoreColor) = _scoreLine(e.key, lastItem);
    final type = e.type;
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _selectedKey = selected ? null : e.key),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: type.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child:
                      Icon(type.icon, color: type.color, size: 20)),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(type.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13.5)),
                    Text(type.description,
                        style: const TextStyle(fontSize: 11, color: hcSlate)),
                    if (status.progressPct != null) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                              value: (status.progressPct! / 100).clamp(0, 1),
                              minHeight: 4,
                              color: status.progressColor,
                              backgroundColor:
                                  cs.outlineVariant.withValues(alpha: 0.3))),
                    ] else if (score.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(score,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: scoreColor))),
                  ])),
              const SizedBox(width: 8),
              HcStatusChip(
                  label: status.label.toUpperCase(), color: status.color),
            ]),
          ),
        ),
        if (selected)
          _detail(context, e, type, hist, lastDone, status, score, scoreColor),
      ]),
    );
  }

  Widget _detail(BuildContext context, _WorkEntry e, _AssessType type,
      List<Map> hist, DateTime? lastDone, _AssessStatus status, String score,
      Color scoreColor) {
    final nextDue = (lastDone != null && status.progressPct != null)
        ? lastDone.add(Duration(milliseconds: _freqMs(e.frequency)))
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Divider(height: 1),
        const SizedBox(height: 10),
        Row(children: [
          _tile(Icons.refresh_rounded, 'Frequency', e.frequency),
          _tile(Icons.history_rounded, 'Last done',
              lastDone != null ? hcDateTime(lastDone) : 'Never'),
          _tile(Icons.event_available_rounded, 'Next due',
              nextDue != null ? hcDateTime(nextDue) : '—'),
          _tile(status.progressPct != null ? Icons.show_chart_rounded : Icons.check_circle_rounded,
              'Status', status.progressPct != null ? '${status.progressPct}%' : status.label),
        ]),
        if (score.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(Icons.insights_rounded, color: scoreColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Current score',
                          style: const TextStyle(fontSize: 11, color: hcSlate)),
                      Text(score,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: scoreColor)),
                    ])),
              ])),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: hcTeal),
                  onPressed: () => _doRecord(context, type),
                  icon: Icon(
                      lastDone != null
                          ? Icons.refresh_rounded
                          : Icons.play_arrow_rounded,
                      size: 18),
                  label: Text(lastDone != null ? 'Redo' : 'Do now'))),
          const SizedBox(width: 8),
          OutlinedButton.icon(
              onPressed: () => _openHistory(context, type),
              icon: const Icon(Icons.history_rounded, size: 18),
              label: const Text('History')),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          const Icon(Icons.history_rounded, size: 16, color: hcTeal),
          const SizedBox(width: 6),
          Text('Recent records',
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 12.5, color: hcSlate)),
          const Spacer(),
          if (hist.length > 5)
            TextButton(
                onPressed: () => _openHistory(context, type),
                child: const Text('All',
                    style: TextStyle(fontSize: 12))),
        ]),
        const SizedBox(height: 8),
        if (hist.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No records yet',
                  style: TextStyle(fontSize: 12, color: hcSlate)))
        else
          for (int i = 0; i < hist.length && i < 5; i++)
            _historyItem(hist[i], type.key, isFirst: i == 0, compact: true),
      ]),
    );
  }

  Widget _tile(IconData icon, String label, String value) {
    return Expanded(
        child: Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
                color: hcSlate.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 16, color: hcTeal),
                  const SizedBox(height: 4),
                  Text(label,
                      style: const TextStyle(fontSize: 9.5, color: hcSlate)),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ])));
  }

  Widget _historyItem(Map item, String key,
      {bool isFirst = false, bool compact = false}) {
    final result = _resultText(key, item);
    final ts = hcDateTime(item['assessed_at']);
    final staff = item['assessed_by_name']?.toString() ??
        item['caregiver_name']?.toString() ??
        '';
    final metrics = _metrics(key, item);
    final notes = _readNote(item['notes']);
    final shown = compact && metrics.length > 5 ? metrics.sublist(0, 5) : metrics;
    final extra = compact && metrics.length > 5 ? metrics.length - 5 : 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: isFirst
              ? hcTeal.withValues(alpha: 0.06)
              : hcSlate.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isFirst
                  ? hcTeal.withValues(alpha: 0.3)
                  : hcSlate.withValues(alpha: 0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(result,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12.5))),
          if (isFirst) HcStatusChip(label: 'LATEST', color: hcTeal),
        ]),
        const SizedBox(height: 2),
        Text(ts + (staff.isNotEmpty ? ' · $staff' : ''),
            style: const TextStyle(fontSize: 10.5, color: hcSlate)),
        if (shown.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in shown)
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: hcTeal.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(m.$2.isEmpty ? m.$1 : '${m.$1}: ${m.$2}',
                          style: const TextStyle(fontSize: 10.5))),
                if (extra > 0)
                  Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 3),
                      child: Text('+$extra more',
                          style: const TextStyle(
                              fontSize: 10.5, color: hcSlate))),
              ]),
        ],
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(notes, style: const TextStyle(fontSize: 10.5, color: hcSlate)),
        ],
      ]),
    );
  }

  // ── Add assessment flow ──
  void _openAddAssessment(BuildContext context) {
    final worklist = ref.read(_pcWorklistProvider(widget.id)).valueOrNull;
    final entries = <_WorkEntry>[];
    for (final s in (worklist?.cast<Map>() ?? const [])) {
      final meta = _parseNotes(s['notes']);
      final key = meta['worklist_key']?.toString();
      if (key == null) continue;
      final type = _assessType(key);
      if (type == null) continue;
      entries.add(_WorkEntry(
          key: key,
          type: type,
          frequency: meta['frequency']?.toString() ?? type.frequency,
          startedAt: s['assessed_at']?.toString() ?? '',
          backendId: s['id']));
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Add assessment component',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            Flexible(
                child: GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    childAspectRatio: 0.82,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    children: [
                  for (final t in _assessTypes)
                    _typeGridCard(context, sheetCtx, t,
                        inList: entries.any((e) => e.key == t.key)),
                ])),
            TextButton(
                onPressed: () => Navigator.pop(sheetCtx),
                child: const Text('Done')),
            const SizedBox(height: 4),
          ]),
        ),
      ),
    );
  }

  Widget _typeGridCard(BuildContext parentCtx, BuildContext sheetCtx,
      _AssessType t,
      {required bool inList}) {
    return Material(
      color: t.color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.pop(sheetCtx);
          _openConfig(parentCtx, t, inList: inList);
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(t.icon, color: t.color, size: 22),
                const SizedBox(height: 6),
                Text(t.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: t.color)),
                if (inList)
                  const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.check_circle_rounded,
                          size: 12, color: hcTeal)),
              ]),
        ),
      ),
    );
  }

  void _openConfig(BuildContext context, _AssessType type,
      {required bool inList}) {
    DateTime start = DateTime.now();
    String freq = type.frequency;
    String customFreq = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, ss) {
          final chosen = customFreq.isNotEmpty ? customFreq : freq;
          return Padding(
            padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(type.icon, color: type.color),
                    const SizedBox(width: 8),
                    Text(type.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                  ]),
                  const SizedBox(height: 4),
                  Text(type.description,
                      style: const TextStyle(fontSize: 12, color: hcSlate)),
                  const SizedBox(height: 14),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_rounded),
                      title: const Text('Start time'),
                      subtitle: Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(start)),
                      trailing: const Icon(Icons.edit_rounded, size: 20),
                      onTap: () async {
                        final d = await showDatePicker(
                            context: ctx,
                            initialDate: start,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100));
                        if (d != null) {
                          if (!ctx.mounted) return;
                          final t = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.fromDateTime(start));
                          if (t != null) {
                            ss(() => start = DateTime(
                                d.year, d.month, d.day, t.hour, t.minute));
                          }
                        }
                      }),
                  const SizedBox(height: 6),
                  const Text('Frequency',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final f in type.freqOptions)
                          ChoiceChip(
                              label: Text(f),
                              selected: freq == f && customFreq.isEmpty,
                              onSelected: (_) =>
                                  ss(() { freq = f; customFreq = ''; })),
                      ]),
                  const SizedBox(height: 10),
                  TextField(
                      decoration: const InputDecoration(
                          labelText: 'Custom frequency',
                          hintText: 'e.g. Every 3 hrs'),
                      onChanged: (v) => ss(() => customFreq = v.trim())),
                  const SizedBox(height: 16),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: hcTeal),
                          onPressed: () =>
                              _confirmAdd(ctx, type, start, chosen, inList),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: Text(
                              inList ? 'Update schedule' : 'Add to worklist'))),
                ]),
          );
        },
      ),
    );
  }

  Future<void> _confirmAdd(BuildContext ctx, _AssessType type, DateTime start,
      String freq, bool inList) async {
    Navigator.pop(ctx);
    try {
      final dio = ref.read(dioProvider);
      final startIso = start.toUtc().toIso8601String();
      final notes = jsonEncode({'worklist_key': type.key, 'frequency': freq});
      // Reuse the existing draft session for this type if present.
      final worklist = ref.read(_pcWorklistProvider(widget.id)).valueOrNull;
      final sessions = worklist?.cast<Map>() ?? const [];
      Map? existing;
      for (final s in sessions) {
        final meta = _parseNotes(s['notes']);
        if (meta['worklist_key']?.toString() == type.key) {
          existing = s;
          break;
        }
      }
      if (existing != null && existing['id'] != null) {
        await dio.patch('/homecare/assessment-sessions/${existing['id']}/',
            data: {'assessed_at': startIso, 'notes': notes});
      } else {
        await dio.post('/homecare/assessment-sessions/', data: {
          'patient': widget.id,
          'session_type': 'reassessment',
          'status': 'draft',
          'assessed_at': startIso,
          'notes': notes,
        });
      }
      ref.invalidate(_pcWorklistProvider(widget.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(inList
                ? '${type.label} schedule updated'
                : '${type.label} added to worklist')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save assessment schedule.')));
      }
    }
  }

  // ── Record / history ──
  void _doRecord(BuildContext context, _AssessType type) {
    final shape = const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)));
    void after(Future<dynamic> f) {
      f.then((saved) {
        if (saved == true) {
          ref.invalidate(_pcAssessHistoryProvider((widget.id, type.key)));
          ref.invalidate(_pcWorklistProvider(widget.id));
        }
      });
    }

    if (type.scaleKey != null) {
      final f = showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: shape,
          builder: (_) => RecordAssessmentSheet(
              scaleKey: type.scaleKey!, patientId: widget.id));
      after(f);
    } else if (type.bundleKey != null) {
      final scale =
          kBundleScales.firstWhere((b) => b.key == type.bundleKey);
      final f = showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: shape,
          builder: (_) =>
              BundleAssessmentSheet(scale: scale, patientId: widget.id));
      after(f);
    }
  }

  void _openHistory(BuildContext context, _AssessType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (ctx, c) => Material(
          color: Theme.of(ctx).scaffoldBackgroundColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
          child: Consumer(builder: (ctx, ref, _) {
            final hist = ref
                    .watch(_pcAssessHistoryProvider((widget.id, type.key)))
                    .valueOrNull
                    ?.cast<Map>() ??
                const <Map>[];
            return Column(children: [
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Icon(type.icon, color: type.color),
                    const SizedBox(width: 8),
                    Text('History · ${type.label}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                  ])),
              const Divider(height: 1),
              if (hist.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No records yet',
                        style: TextStyle(color: hcSlate)))
              else
                Expanded(
                    child: ListView.builder(
                        controller: c,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: hist.length,
                        itemBuilder: (_, i) =>
                            _historyItem(hist[i], type.key, isFirst: i == 0))),
            ]);
          }),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.circle, size: 9, color: color),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: hcSlate)),
    ]);
  }
}



// update the vitals tab to look similar to vitals & NEWS2 in nuxtfrontend homecare, route: /homecare/patient-care/5, also update the record vitals to show Aggregate NEWS2 as in nuxtfrontend