import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import 'hc_common.dart';

// ── Scale registry (mirrors web ASSESSMENT_TYPES core set) ──
const kScales = [
  ('braden', 'Braden Scale', 'Pressure injury risk (6–23)',
      Icons.airline_seat_flat_rounded, hcAmber, '/homecare/braden-assessments/'),
  ('morse', 'Morse Fall Scale', 'Falls risk (0–125)',
      Icons.elderly_rounded, hcRose, '/homecare/morse-assessments/'),
  ('must', 'MUST', 'Malnutrition screening',
      Icons.restaurant_rounded, hcGreen, '/homecare/must-assessments/'),
  ('cam', 'CAM', 'Delirium screening',
      Icons.psychology_rounded, hcPurple, '/homecare/cam-assessments/'),
  ('gcs', 'Glasgow Coma Scale', 'Consciousness (3–15)',
      Icons.visibility_rounded, hcIndigo, '/homecare/gcs-assessments/'),
  ('pain', 'Pain (NRS)', 'Numeric rating 0–10',
      Icons.sick_rounded, hcRed, '/homecare/pain-assessments/'),
  ('skin_care', 'Skin Care Bundle', 'q4h pressure-care protocol',
      Icons.healing_rounded, hcTeal, '/homecare/skin-care-assessments/'),
  ('diabetes_bundle', 'Diabetes Bundle', 'Glucose & ketones round',
      Icons.bloodtype_rounded, hcBlue, '/homecare/diabetes-bundle-assessments/'),
  ('hf_bundle', 'Heart Failure Bundle', 'Weight, fluid & SpO₂',
      Icons.favorite_rounded, hcRose, '/homecare/hf-bundle-assessments/'),
  ('caprini', 'Caprini Score', 'VTE risk factors',
      Icons.bloodtype_outlined, hcAmber, '/homecare/caprini-assessments/'),
  ('pivc', 'PIVC (VIP Score)', 'IV cannula phlebitis check',
      Icons.colorize_rounded, hcIndigo, '/homecare/pivc-assessments/'),
];

final _sessionsProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/assessment-sessions/',
      params: {'ordering': '-assessed_at', 'page_size': 100});
});

final _assessPatientsProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/patients/',
      params: {'is_active': 'true', 'page_size': 200});
});

final _summaryProvider =
    FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/homecare/assessment-sessions/summary/');
  return (res.data is Map)
      ? res.data as Map
      : <String, dynamic>{};
});

const _riskOptions = [
  ('all', 'All risks'),
  ('low', 'Low'),
  ('medium', 'Medium'),
  ('high', 'High'),
  ('critical', 'Critical'),
];
const _typeOptions = [
  ('all', 'All types'),
  ('initial', 'Initial'),
  ('head_to_toe', 'Head-to-Toe'),
  ('reassessment', 'Reassessment'),
  ('admission', 'Admission'),
  ('discharge', 'Discharge'),
];

const _tealGrad = [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)];

/// Assessments hub — mirrors the web /homecare/assessments page:
/// hero, KPI cards, and a filterable sessions table with score columns.
class HomecareAssessmentsScreen extends ConsumerStatefulWidget {
  const HomecareAssessmentsScreen({super.key});

  @override
  ConsumerState<HomecareAssessmentsScreen> createState() =>
      _HomecareAssessmentsScreenState();
}

class _HomecareAssessmentsScreenState
    extends ConsumerState<HomecareAssessmentsScreen> {
  final _search = TextEditingController();
  String _riskFilter = 'all';
  String _typeFilter = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Map> _filtered(List<dynamic> rows) {
    final q = _search.text.trim().toLowerCase();
    return rows.cast<Map>().where((s) {
      if (_riskFilter != 'all' &&
          (s['overall_risk_level'] ?? '').toString() != _riskFilter) {
        return false;
      }
      if (_typeFilter != 'all' &&
          (s['session_type'] ?? '').toString() != _typeFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return [
        s['patient_name']?.toString(),
        s['medical_record_number']?.toString(),
        s['assessed_by_name']?.toString(),
      ]
          .where((e) => e != null && e.isNotEmpty)
          .join(' ')
          .toLowerCase()
          .contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(_sessionsProvider);
    final summary = ref.watch(_summaryProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'record-assessment',
        onPressed: () => context.go('/homecare/assessments/new'),
        backgroundColor: hcTeal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New assessment'),
      ),
      body: HcAsyncBody(
        value: sessions,
        onRefresh: () async => ref.refresh(_sessionsProvider.future),
        builder: (list) {
          final rows = _filtered(list);
          final sum = summary.valueOrNull ?? const <String, dynamic>{};
          final byRisk = (sum['by_risk'] as Map?) ?? const {};
          final highCrit =
              ((byRisk['high'] ?? 0) as num).toInt() +
              ((byRisk['critical'] ?? 0) as num).toInt();
          final lastAt = sum['last_assessed_at']?.toString();

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              HcHero(
                eyebrow: 'CLINICAL ASSESSMENTS',
                title: 'Patient Assessments',
                subtitle:
                    'Structured nursing assessments — initial survey, head-to-toe baseline, validated risk scales, device & disease care bundles.',
                icon: Icons.assignment_rounded,
                gradient: _tealGrad,
                chips: [
                  HcHeroChip(
                      icon: Icons.assignment_rounded,
                      label:
                          '${sum['total'] ?? rows.length} sessions'),
                  HcHeroChip(
                      icon: Icons.notification_important_rounded,
                      label: '${sum['open_alerts'] ?? 0} open alerts'),
                  HcHeroChip(
                      icon: Icons.verified_rounded,
                      label: '${sum['signed'] ?? 0} signed'),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.6,
                  children: [
                    HcKpi(
                      label: 'Total assessments',
                      value: '${sum['total'] ?? rows.length}',
                      icon: Icons.assignment_rounded,
                      color: hcTeal,
                    ),
                    HcKpi(
                      label: 'High / critical risk',
                      value: highCrit == 0 ? '—' : '$highCrit',
                      icon: Icons.shield_rounded,
                      color: hcRed,
                    ),
                    HcKpi(
                      label: 'Open alerts',
                      value: '${sum['open_alerts'] ?? 0}',
                      icon: Icons.notifications_active_rounded,
                      color: hcAmber,
                    ),
                    HcKpi(
                      label: 'Last assessment',
                      value: lastAt == null || lastAt.isEmpty
                          ? '—'
                          : hcDateTime(lastAt),
                      icon: Icons.schedule_rounded,
                      color: hcPurple,
                    ),
                  ],
                ),
              ),
              HcPanel(
                title: 'Assessment sessions',
                subtitle: 'All patient assessments · newest first',
                icon: Icons.assignment_rounded,
                color: hcTeal,
                action: IconButton(
                  tooltip: 'New assessment',
                  onPressed: () => context.go('/homecare/assessments/new'),
                  icon: const Icon(Icons.add_circle_rounded, color: hcTeal),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              prefixIcon:
                                  Icon(Icons.search_rounded, size: 20),
                              hintText: 'Search patient…',
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          icon: Icons.shield_rounded,
                          value: _riskFilter,
                          options: _riskOptions,
                          onChanged: (v) =>
                              setState(() => _riskFilter = v),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          icon: Icons.filter_alt_rounded,
                          value: _typeFilter,
                          options: _typeOptions,
                          onChanged: (v) =>
                              setState(() => _typeFilter = v),
                        ),
                      ]),
                    ),
                    if (rows.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Column(children: [
                          Icon(Icons.assignment_outlined,
                              size: 44,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                          const SizedBox(height: 8),
                          const Text(
                              'No assessment sessions yet. Tap New assessment to begin.'),
                        ]),
                      )
                    else
                      ...rows.map((s) => _SessionTile(s: s)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Score-chip colour helpers (mirrors web scoring thresholds).
Color _bradenColor(num? v) {
  if (v == null) return hcSlate;
  if (v <= 12) return hcRed;
  if (v <= 18) return hcAmber;
  return hcGreen;
}

Color _morseColor(num? v) {
  if (v == null) return hcSlate;
  if (v >= 45) return hcRed;
  if (v >= 25) return hcAmber;
  return hcGreen;
}

Color _capriniColor(num? v) {
  if (v == null) return hcSlate;
  if (v >= 5) return hcRed;
  if (v >= 3) return hcAmber;
  if (v == 2) return hcBlue;
  return hcGreen;
}

Color _mustColor(num? v) {
  if (v == null) return hcSlate;
  if (v >= 2) return hcRed;
  if (v == 1) return hcAmber;
  return hcGreen;
}

Color _painColor(num? v) {
  if (v == null) return hcSlate;
  if (v >= 7) return hcRed;
  if (v >= 4) return hcAmber;
  return hcGreen;
}

/// Compact dropdown filter chip used in the sessions panel header.
class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;
  const _FilterChip(
      {required this.icon,
      required this.value,
      required this.options,
      required this.onChanged});

  String get _label =>
      options.firstWhere((o) => o.$1 == value, orElse: () => options.first).$2;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Filter',
      onSelected: onChanged,
      itemBuilder: (_) => options
          .map((o) => PopupMenuItem(
              value: o.$1,
              child: Row(children: [
                Icon(o.$1 == value ? Icons.check_rounded : Icons.circle_outlined,
                    size: 16),
                const SizedBox(width: 8),
                Text(o.$2),
              ])))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(_label, style: const TextStyle(fontSize: 13)),
          const Icon(Icons.arrow_drop_down_rounded, size: 18),
        ]),
      ),
    );
  }
}

/// A single session row — mirrors the web table columns (patient, type,
/// assessed, by, Braden/Morse/Caprini/MUST/Pain scores, risk, alerts).
class _SessionTile extends StatelessWidget {
  final Map s;
  const _SessionTile({required this.s});

  Widget _score(String key, num? v, Color Function(num?) color) {
    if (v == null) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: color(v).withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(7)),
      child: Text('$v',
          style: TextStyle(
              color: color(v), fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final risk = (s['overall_risk_level'] ?? '').toString();
    final alertCount = (s['alert_count'] ?? 0) as num;
    final braden = s['braden_total'] as num?;
    final morse = s['morse_score'] as num?;
    final caprini = s['caprini_points'] as num?;
    final must = s['must_score'] as num?;
    final pain = s['pain_score'] as num?;
    final by = (s['assessed_by_name'] ?? '').toString();
    final scores = [
      ('Braden', braden, _bradenColor),
      ('Morse', morse, _morseColor),
      ('Caprini', caprini, _capriniColor),
      ('MUST', must, _mustColor),
      ('Pain', pain, _painColor),
    ].where((e) => e.$2 != null).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/homecare/assessments/${s['id']}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            HcAvatar(
              name: s['patient_name']?.toString() ?? s['patient']?.toString(),
              size: 40,
              color: hcRiskColor(risk.isEmpty ? 'low' : risk),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                          s['patient_name']?.toString() ??
                              'Patient #${s['patient']}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                    if (risk.isNotEmpty)
                      HcStatusChip(
                          label: risk.toUpperCase(),
                          color: hcRiskColor(risk)),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    HcStatusChip(
                      label: hcLabel(s['session_type_label']?.toString() ??
                          s['session_type']?.toString()),
                      color: hcTeal,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(hcDateTime(s['assessed_at']),
                          style: TextStyle(
                              fontSize: 11.5,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ),
                  ]),
                  if (by.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text('by $by',
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                  if (s['medical_record_number'] != null) ...[
                    const SizedBox(height: 3),
                    Text('${s['medical_record_number']}',
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                  if (scores.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final sc in scores)
                          Tooltip(
                            message: sc.$1,
                            child: _score(sc.$1, sc.$2, sc.$3),
                          ),
                      ],
                    ),
                  ],
                  if (alertCount > 0) ...[
                    const SizedBox(height: 8),
                    HcStatusChip(
                      label: '$alertCount alert${alertCount == 1 ? '' : 's'}',
                      color: hcRed,
                      icon: Icons.notification_important_rounded,
                    ),
                  ],
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Record sheet for the core scales. Creates an AssessmentSession
/// (episode) then posts the scale row — scoring happens server-side.
class RecordAssessmentSheet extends ConsumerStatefulWidget {
  final String scaleKey;
  final int? patientId;
  const RecordAssessmentSheet(
      {super.key, required this.scaleKey, this.patientId});

  @override
  ConsumerState<RecordAssessmentSheet> createState() =>
      _RecordAssessmentSheetState();
}

class _RecordAssessmentSheetState
    extends ConsumerState<RecordAssessmentSheet> {
  late int? _patientId = widget.patientId;
  final _notes = TextEditingController();
  bool _saving = false;

  // Braden subscales (label, min..max)
  final Map<String, int?> _braden = {
    'sensory': null, 'moisture': null, 'activity': null,
    'mobility': null, 'nutrition': null, 'friction': null,
  };
  // Morse
  bool _morseHistory = false;
  bool _morseSecondaryDx = false;
  String _morseAid = 'none';
  bool _morseIv = false;
  String _morseGait = 'normal';
  String _morseMental = 'oriented';
  // MUST
  final _mustHeight = TextEditingController();
  final _mustWeight = TextEditingController();
  final _mustLoss = TextEditingController();
  bool _mustAcute = false;
  // CAM
  bool _camOnset = false, _camInattention = false;
  bool _camDisorganized = false, _camAltered = false;
  // GCS
  int? _gcsEyes, _gcsVerbal, _gcsMotor;
  // Pain (NRS)
  int _painScore = 0;
  // Skin care bundle (6 tasks)
  final Map<String, bool> _skin = {
    'reposition': false, 'surface': false, 'moisture': false,
    'nutrition': false, 'heels': false, 'inspect': false,
  };
  // Diabetes bundle
  final _dmGlucose = TextEditingController();
  final _dmKetones = TextEditingController();
  // HF bundle
  final _hfWeight = TextEditingController();
  final _hfFluid = TextEditingController();
  final _hfSpo2 = TextEditingController();
  // Caprini
  final _capriniAge = TextEditingController();
  final Map<String, bool> _capriniFactors = {
    'minor_surgery': false, 'major_surgery': false, 'chf': false,
    'sepsis': false, 'copd': false, 'bed_rest': false,
    'malignancy': false, 'prior_vte': false, 'obesity': false,
    'oral_contraceptives': false, 'pregnancy': false, 'stroke': false,
  };
  // PIVC — server computes the VIP score from these findings
  final _pivcSite = TextEditingController();
  final _pivcGauge = TextEditingController();
  String _pivcPain = 'none';
  String _pivcErythema = 'none';
  String _pivcSwelling = 'none';
  String _pivcWarmth = 'normal';
  String _pivcInduration = 'none';
  String _pivcCord = 'no';
  String _pivcDrainage = 'none';

  (String, String, Color, IconData) get _meta {
    final s = kScales.firstWhere((s) => s.$1 == widget.scaleKey);
    return (s.$2, s.$6, s.$5, s.$4);
  }

  Future<void> _submit() async {
    if (_patientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a patient first.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      final nowIso = DateTime.now().toUtc().toIso8601String();
      // 1. episode
      final sessionRes =
          await dio.post('/homecare/assessment-sessions/', data: {
        'patient': _patientId,
        'session_type': 'reassessment',
        'assessed_at': nowIso,
      });
      final episodeId = sessionRes.data['id'];
      // 2. scale row
      final payload = <String, dynamic>{
        'episode': episodeId,
        'patient': _patientId,
        'assessed_at': nowIso,
        'notes': _notes.text.trim(),
        ..._scalePayload(),
      };
      await dio.post(_meta.$2, data: payload);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_meta.$1} recorded.')));
      }
    } catch (e) {
      String msg = 'Could not save assessment.';
      try {
        final data = (e as dynamic).response?.data;
        if (data is Map && data.isNotEmpty) {
          final first = data.entries.first;
          msg =
              '${first.key}: ${first.value is List ? (first.value as List).first : first.value}';
        }
      } catch (_) {}
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Map<String, dynamic> _scalePayload() => switch (widget.scaleKey) {
        'braden' => {..._braden},
        'morse' => {
            'history_of_falls': _morseHistory,
            'secondary_dx': _morseSecondaryDx,
            'ambulatory_aid': _morseAid,
            'iv_lock': _morseIv,
            'gait': _morseGait,
            'mental_status': _morseMental,
          },
        'must' => {
            if (_mustHeight.text.isNotEmpty)
              'height_cm': int.tryParse(_mustHeight.text),
            if (_mustWeight.text.isNotEmpty)
              'weight_kg': double.tryParse(_mustWeight.text),
            if (_mustLoss.text.isNotEmpty)
              'weight_loss_percent': double.tryParse(_mustLoss.text),
            'acute_no_nutrition': _mustAcute,
          },
        'cam' => {
            'acute_onset': _camOnset,
            'inattention': _camInattention,
            'disorganized_thinking': _camDisorganized,
            'altered_consciousness': _camAltered,
          },
        'gcs' => {
            if (_gcsEyes != null) 'eyes': _gcsEyes,
            if (_gcsVerbal != null) 'verbal': _gcsVerbal,
            if (_gcsMotor != null) 'motor': _gcsMotor,
          },
        'pain' => {'tool_type': 'nrs', 'score': _painScore, 'has_pain': _painScore > 0},
        'skin_care' => {..._skin},
        'diabetes_bundle' => {
            if (_dmGlucose.text.isNotEmpty)
              'glucose': double.tryParse(_dmGlucose.text),
            if (_dmKetones.text.isNotEmpty)
              'ketones': double.tryParse(_dmKetones.text),
          },
        'hf_bundle' => {
            if (_hfWeight.text.isNotEmpty)
              'weight_kg': double.tryParse(_hfWeight.text),
            if (_hfFluid.text.isNotEmpty)
              'fluid_balance_ml': int.tryParse(_hfFluid.text),
            if (_hfSpo2.text.isNotEmpty)
              'spo2': int.tryParse(_hfSpo2.text),
          },
        'caprini' => {
            if (_capriniAge.text.isNotEmpty)
              'age': int.tryParse(_capriniAge.text),
            'factors': _capriniFactors,
          },
        'pivc' => {
            if (_pivcSite.text.trim().isNotEmpty)
              'catheter_site': _pivcSite.text.trim(),
            if (_pivcGauge.text.trim().isNotEmpty)
              'gauge': _pivcGauge.text.trim(),
            'pain_level': _pivcPain,
            'erythema': _pivcErythema,
            'swelling': _pivcSwelling,
            'warmth': _pivcWarmth,
            'induration': _pivcInduration,
            'palpable_cord': _pivcCord,
            'drainage_type': _pivcDrainage,
          },
        _ => {},
      };

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(_assessPatientsProvider);
    final meta = _meta;

    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(meta.$4, color: meta.$3),
              const SizedBox(width: 8),
              Text(meta.$1,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
            const SizedBox(height: 14),
            if (widget.patientId == null)
              patients.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Could not load patients'),
                data: (list) => DropdownButtonFormField<int>(
                  initialValue: _patientId,
                  decoration: const InputDecoration(labelText: 'Patient *'),
                  items: list
                      .cast<Map>()
                      .map((p) => DropdownMenuItem<int>(
                            value: p['id'] as int,
                            child: Text(
                                (p['patient_name'] ?? '#${p['id']}')
                                    .toString(),
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _patientId = v),
                ),
              ),
            const SizedBox(height: 12),
            ..._buildScaleFields(meta.$3),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: meta.$3),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 18),
                label: const Text('Save assessment'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildScaleFields(Color color) {
    switch (widget.scaleKey) {
      case 'braden':
        const items = [
          ('sensory', 'Sensory perception', 1, 4),
          ('moisture', 'Moisture', 1, 4),
          ('activity', 'Activity', 1, 4),
          ('mobility', 'Mobility', 1, 4),
          ('nutrition', 'Nutrition', 1, 4),
          ('friction', 'Friction & shear', 1, 3),
        ];
        return [
          for (final it in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                    child: Text(it.$2,
                        style: const TextStyle(fontSize: 13))),
                SegmentedButton<int>(
                  segments: [
                    for (var v = it.$3; v <= it.$4; v++)
                      ButtonSegment(value: v, label: Text('$v')),
                  ],
                  selected:
                      _braden[it.$1] != null ? {_braden[it.$1]!} : {},
                  emptySelectionAllowed: true,
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() =>
                      _braden[it.$1] = s.isEmpty ? null : s.first),
                  style: const ButtonStyle(
                      visualDensity: VisualDensity.compact),
                ),
              ]),
            ),
        ];
      case 'morse':
        return [
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _morseHistory,
              title: const Text('History of falling',
                  style: TextStyle(fontSize: 13.5)),
              onChanged: (v) => setState(() => _morseHistory = v)),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _morseSecondaryDx,
              title: const Text('Secondary diagnosis',
                  style: TextStyle(fontSize: 13.5)),
              onChanged: (v) => setState(() => _morseSecondaryDx = v)),
          DropdownButtonFormField<String>(
            initialValue: _morseAid,
            decoration: const InputDecoration(labelText: 'Ambulatory aid'),
            items: const [
              DropdownMenuItem(value: 'none', child: Text('None / bed rest')),
              DropdownMenuItem(
                  value: 'crutches', child: Text('Crutches / cane / walker')),
              DropdownMenuItem(
                  value: 'furniture', child: Text('Holds furniture')),
            ],
            onChanged: (v) => setState(() => _morseAid = v ?? 'none'),
          ),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _morseIv,
              title: const Text('IV / heparin lock',
                  style: TextStyle(fontSize: 13.5)),
              onChanged: (v) => setState(() => _morseIv = v)),
          DropdownButtonFormField<String>(
            initialValue: _morseGait,
            decoration: const InputDecoration(labelText: 'Gait'),
            items: const [
              DropdownMenuItem(value: 'normal', child: Text('Normal')),
              DropdownMenuItem(value: 'weak', child: Text('Weak')),
              DropdownMenuItem(value: 'impaired', child: Text('Impaired')),
            ],
            onChanged: (v) => setState(() => _morseGait = v ?? 'normal'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _morseMental,
            decoration: const InputDecoration(labelText: 'Mental status'),
            items: const [
              DropdownMenuItem(
                  value: 'oriented', child: Text('Oriented to ability')),
              DropdownMenuItem(
                  value: 'overestimates',
                  child: Text('Overestimates / forgets limits')),
            ],
            onChanged: (v) =>
                setState(() => _morseMental = v ?? 'oriented'),
          ),
        ];
      case 'must':
        return [
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _mustHeight,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Height', suffixText: 'cm'))),
            const SizedBox(width: 8),
            Expanded(
                child: TextField(
                    controller: _mustWeight,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Weight', suffixText: 'kg'))),
          ]),
          const SizedBox(height: 10),
          TextField(
              controller: _mustLoss,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Unplanned weight loss (3–6 mo)',
                  suffixText: '%')),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _mustAcute,
              title: const Text(
                  'Acutely ill & no intake for >5 days',
                  style: TextStyle(fontSize: 13.5)),
              onChanged: (v) => setState(() => _mustAcute = v)),
        ];
      case 'cam':
        return [
          for (final it in [
            ('Acute onset / fluctuating course', _camOnset,
                (bool v) => _camOnset = v),
            ('Inattention', _camInattention, (bool v) => _camInattention = v),
            ('Disorganized thinking', _camDisorganized,
                (bool v) => _camDisorganized = v),
            ('Altered level of consciousness', _camAltered,
                (bool v) => _camAltered = v),
          ])
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: it.$2,
              title: Text(it.$1, style: const TextStyle(fontSize: 13.5)),
              onChanged: (v) => setState(() => it.$3(v)),
            ),
        ];
      case 'gcs':
        return [
          _GcsPicker(
              label: 'Eye opening (1–4)',
              max: 4,
              value: _gcsEyes,
              onChanged: (v) => setState(() => _gcsEyes = v)),
          _GcsPicker(
              label: 'Verbal response (1–5)',
              max: 5,
              value: _gcsVerbal,
              onChanged: (v) => setState(() => _gcsVerbal = v)),
          _GcsPicker(
              label: 'Motor response (1–6)',
              max: 6,
              value: _gcsMotor,
              onChanged: (v) => setState(() => _gcsMotor = v)),
          if (_gcsEyes != null && _gcsVerbal != null && _gcsMotor != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  'Total: ${_gcsEyes! + _gcsVerbal! + _gcsMotor!} / 15',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: color)),
            ),
        ];
      case 'pain':
        return [
          Text('Pain score: $_painScore / 10',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 15, color: color)),
          Slider(
            value: _painScore.toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            label: '$_painScore',
            activeColor: color,
            onChanged: (v) => setState(() => _painScore = v.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('No pain', style: TextStyle(fontSize: 11)),
              Text('Worst possible', style: TextStyle(fontSize: 11)),
            ],
          ),
        ];
      case 'skin_care':
        const labels = {
          'reposition': 'Repositioned (q4h turn)',
          'surface': 'Support surface checked',
          'moisture': 'Moisture managed',
          'nutrition': 'Nutrition / hydration reviewed',
          'heels': 'Heels floated / offloaded',
          'inspect': 'Skin inspected head-to-toe',
        };
        return [
          for (final k in _skin.keys)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _skin[k],
              title: Text(labels[k] ?? k,
                  style: const TextStyle(fontSize: 13)),
              onChanged: (v) => setState(() => _skin[k] = v ?? false),
            ),
        ];
      case 'diabetes_bundle':
        return [
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _dmGlucose,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Glucose', suffixText: 'mmol/L'))),
            const SizedBox(width: 8),
            Expanded(
                child: TextField(
                    controller: _dmKetones,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Ketones', suffixText: 'mmol/L'))),
          ]),
        ];
      case 'hf_bundle':
        return [
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _hfWeight,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Weight', suffixText: 'kg'))),
            const SizedBox(width: 8),
            Expanded(
                child: TextField(
                    controller: _hfSpo2,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'SpO₂', suffixText: '%'))),
          ]),
          const SizedBox(height: 10),
          TextField(
              controller: _hfFluid,
              keyboardType:
                  const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                  labelText: 'Fluid balance (24h)', suffixText: 'ml')),
        ];
      case 'caprini':
        const labels = {
          'minor_surgery': 'Minor surgery planned',
          'major_surgery': 'Major surgery (<1 month)',
          'chf': 'Congestive heart failure',
          'sepsis': 'Sepsis (<1 month)',
          'copd': 'COPD / abnormal pulmonary function',
          'bed_rest': 'Bed rest / restricted mobility',
          'malignancy': 'Malignancy (present or previous)',
          'prior_vte': 'Prior VTE / DVT / PE',
          'obesity': 'BMI > 25',
          'oral_contraceptives': 'Oral contraceptives / HRT',
          'pregnancy': 'Pregnancy or postpartum',
          'stroke': 'Stroke (<1 month)',
        };
        return [
          TextField(
              controller: _capriniAge,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Age', suffixText: 'yrs')),
          const SizedBox(height: 8),
          for (final k in _capriniFactors.keys)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _capriniFactors[k],
              title: Text(labels[k] ?? k,
                  style: const TextStyle(fontSize: 13)),
              onChanged: (v) =>
                  setState(() => _capriniFactors[k] = v ?? false),
            ),
        ];
      case 'pivc':
        Widget pick(String label, String value, List<(String, String)> opts,
            ValueChanged<String> onChanged) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DropdownButtonFormField<String>(
              initialValue: value,
              decoration: InputDecoration(labelText: label),
              items: opts
                  .map((o) => DropdownMenuItem(
                      value: o.$1, child: Text(o.$2)))
                  .toList(),
              onChanged: (v) => onChanged(v ?? value),
            ),
          );
        }

        return [
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _pivcSite,
                    decoration: const InputDecoration(
                        labelText: 'Site (e.g. L forearm)'))),
            const SizedBox(width: 8),
            SizedBox(
                width: 100,
                child: TextField(
                    controller: _pivcGauge,
                    decoration:
                        const InputDecoration(labelText: 'Gauge'))),
          ]),
          const SizedBox(height: 10),
          pick('Pain', _pivcPain, const [
            ('none', 'None'),
            ('palpation', 'On palpation'),
            ('during_infusion', 'During infusion'),
            ('constant', 'Constant'),
            ('severe', 'Severe'),
          ], (v) => setState(() => _pivcPain = v)),
          pick('Erythema (redness)', _pivcErythema, const [
            ('none', 'None'),
            ('localized_lt_1cm', 'Localized <1 cm'),
            ('moderate_gt_1cm', 'Moderate >1 cm'),
            ('along_vein', 'Along vein'),
            ('extensive', 'Extensive'),
          ], (v) => setState(() => _pivcErythema = v)),
          pick('Swelling', _pivcSwelling, const [
            ('none', 'None'),
            ('mild', 'Mild'),
            ('moderate', 'Moderate'),
            ('severe', 'Severe'),
            ('entire_limb', 'Entire limb'),
          ], (v) => setState(() => _pivcSwelling = v)),
          pick('Warmth', _pivcWarmth, const [
            ('normal', 'Normal'),
            ('slightly_warm', 'Slightly warm'),
            ('moderately_warm', 'Moderately warm'),
            ('very_warm', 'Very warm'),
          ], (v) => setState(() => _pivcWarmth = v)),
          pick('Induration', _pivcInduration, const [
            ('none', 'None'),
            ('localized', 'Localized'),
            ('along_vein', 'Along vein'),
            ('extensive', 'Extensive'),
          ], (v) => setState(() => _pivcInduration = v)),
          pick('Palpable venous cord', _pivcCord, const [
            ('no', 'No'),
            ('lt_2.5cm', '< 2.5 cm'),
            ('gt_2.5cm', '> 2.5 cm'),
          ], (v) => setState(() => _pivcCord = v)),
          pick('Drainage', _pivcDrainage, const [
            ('none', 'None'),
            ('serous', 'Serous'),
            ('blood', 'Blood'),
            ('purulent', 'Purulent'),
          ], (v) => setState(() => _pivcDrainage = v)),
          Text('The VIP score (0–5) is computed automatically on save.',
              style: TextStyle(fontSize: 11, color: color)),
        ];
      default:
        return [];
    }
  }
}

class _GcsPicker extends StatelessWidget {
  final String label;
  final int max;
  final int? value;
  final ValueChanged<int?> onChanged;
  const _GcsPicker(
      {required this.label,
      required this.max,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 4),
        SegmentedButton<int>(
          segments: [
            for (var v = 1; v <= max; v++)
              ButtonSegment(value: v, label: Text('$v')),
          ],
          selected: value != null ? {value!} : {},
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          onSelectionChanged: (s) => onChanged(s.isEmpty ? null : s.first),
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        ),
      ]),
    );
  }
}
