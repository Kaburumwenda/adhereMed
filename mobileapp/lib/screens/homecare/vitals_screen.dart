import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import 'hc_common.dart';

final _vitalsProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/homecare/vitals/');
  final data = res.data;
  return data is List ? data : ((data?['results'] as List?) ?? []);
});

final _vitalsPatientsProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/patients/',
      params: {'is_active': 'true', 'page_size': 200});
});

final _vitalsSearch = StateProvider.autoDispose((_) => '');

Color news2Color(num? n) {
  if (n == null) return hcSlate;
  if (n >= 7) return hcRed;
  if (n >= 5) return hcAmber;
  if (n > 0) return hcBlue;
  return hcGreen;
}

// ── NEWS2 (RCP 2017) scoring — Dart port of useAssessmentScoring.js ──
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

class News2Row {
  final String key;
  final IconData icon;
  final String label;
  final String value;
  final int score;
  const News2Row(this.key, this.icon, this.label, this.value, this.score);
}

class News2Result {
  final int total;
  final bool hasRed;
  final String riskLabel;
  final Color riskColor;
  final List<News2Row> breakdown;
  const News2Result(
      this.total, this.hasRed, this.riskLabel, this.riskColor, this.breakdown);
}

News2Result calcNews2({
  num? rr,
  num? spo2,
  bool scale2 = false,
  String? oxygen,
  num? systolic,
  num? heartRate,
  num? temperature,
  String? consciousness,
}) {
  final sRR = scoreRR(rr);
  final sSpo2 = scale2
      ? scoreSpO2Scale2(spo2, oxygen == 'Supplemental O₂')
      : scoreSpO2Scale1(spo2);
  final sOxygen = scoreOxygen(oxygen);
  final sSbp = scoreSBP(systolic);
  final sHr = scoreHR(heartRate);
  final sTemp = scoreTemp(temperature);
  final sCons = scoreConsciousness(consciousness);
  final total =
      sRR + sSpo2 + sOxygen + sSbp + sHr + sTemp + sCons;
  final hasRed = [sRR, sSpo2, sOxygen, sSbp, sHr, sTemp, sCons]
      .any((s) => s >= 3);
  String riskLabel;
  Color riskColor;
  if (total == 0) {
    riskLabel = 'Low';
    riskColor = hcGreen;
  } else if (total <= 4 && !hasRed) {
    riskLabel = 'Low – Medium';
    riskColor = hcBlue;
  } else if (total <= 6 || hasRed) {
    riskLabel = 'Medium';
    riskColor = hcAmber;
  } else {
    riskLabel = 'High';
    riskColor = hcRed;
  }
  final breakdown = <News2Row>[
    News2Row('rr', Icons.air_rounded, 'Respiratory rate',
        rr != null ? '$rr /min' : '—', sRR),
    News2Row('spo2', Icons.water_drop_rounded,
        'SpO₂ (Scale ${scale2 ? 2 : 1})', spo2 != null ? '$spo2 %' : '—', sSpo2),
    News2Row('oxygen', Icons.gas_meter_rounded, 'Supplemental O₂',
        oxygen ?? 'Room air', sOxygen),
    News2Row('sbp', Icons.monitor_heart_rounded, 'Systolic BP',
        systolic != null ? '$systolic mmHg' : '—', sSbp),
    News2Row('hr', Icons.favorite_rounded, 'Heart rate',
        heartRate != null ? '$heartRate bpm' : '—', sHr),
    News2Row('temp', Icons.thermostat_rounded, 'Temperature',
        temperature != null ? '$temperature °C' : '—', sTemp),
    News2Row('consciousness', Icons.psychology_rounded, 'Consciousness',
        (consciousness == null || consciousness.isEmpty)
            ? 'Alert'
            : consciousness, sCons),
  ];
  return News2Result(total, hasRed, riskLabel, riskColor, breakdown);
}

/// Vitals & NEWS2: recent observations with record + auto-escalation.
class HomecareVitalsScreen extends ConsumerWidget {
  const HomecareVitalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vitals = ref.watch(_vitalsProvider);
    final query = ref.watch(_vitalsSearch);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'record-vitals',
        onPressed: () => _openRecordSheet(context, ref),
        backgroundColor: hcRose,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.monitor_heart_rounded),
        label: const Text('Record'),
      ),
      body: HcAsyncBody(
        value: vitals,
        onRefresh: () async => ref.refresh(_vitalsProvider.future),
        builder: (list) {
          var rows = list.cast<Map>().toList();
          if (query.isNotEmpty) {
            final q = query.toLowerCase();
            rows = rows
                .where((v) => (v['patient_name'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(q))
                .toList();
          }
          final high =
              rows.where((v) => ((v['news2'] as num?) ?? 0) >= 5).length;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              HcHero(
                eyebrow: 'CLINICAL MONITORING',
                title: 'Vitals & NEWS2',
                subtitle:
                    'Observations auto-score NEWS2 and escalate when unsafe',
                icon: Icons.monitor_heart_rounded,
                gradient: const [
                  Color(0xFF9F1239),
                  Color(0xFFE11D48),
                  Color(0xFFF43F5E)
                ],
                chips: [
                  HcHeroChip(
                      icon: Icons.list_alt_rounded,
                      label: '${rows.length} readings'),
                  HcHeroChip(
                      icon: Icons.warning_amber_rounded,
                      label: '$high medium/high'),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: (v) =>
                      ref.read(_vitalsSearch.notifier).state = v,
                  decoration: InputDecoration(
                    hintText: 'Search patient…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: Text('No vitals recorded yet.')),
                )
              else
                ...rows.take(80).map((v) {
                  final news2 = v['news2'] as num?;
                  final c = news2Color(news2);
                  return Card(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                    color: c.withValues(alpha: 0.12),
                                    shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: Text('${news2 ?? '—'}',
                                    style: TextStyle(
                                        color: c,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          v['patient_name']?.toString() ??
                                              '—',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13.5)),
                                      Text(hcDateTime(v['recorded_at']),
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant)),
                                    ]),
                              ),
                              HcStatusChip(
                                  label: 'NEWS2 ${news2 ?? '—'}', color: c),
                            ]),
                            const SizedBox(height: 8),
                            Wrap(spacing: 6, runSpacing: 6, children: [
                              for (final t in [
                                ('BP',
                                    '${v['systolic'] ?? '—'}/${v['diastolic'] ?? '—'}'),
                                ('HR', '${v['pulse'] ?? '—'}'),
                                ('SpO₂', '${v['spo2'] ?? '—'}%'),
                                ('T', '${v['temperature'] ?? '—'}°'),
                                ('RR', '${v['rr'] ?? '—'}'),
                                if (v['glucose'] != null)
                                  ('Glu', '${v['glucose']}'),
                              ])
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                  child: Text('${t.$1} ${t.$2}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700)),
                                ),
                            ]),
                          ]),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  void _openRecordSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const RecordVitalsSheet(),
    ).then((saved) {
      if (saved == true) ref.invalidate(_vitalsProvider);
    });
  }
}

/// Record vitals bottom sheet — POSTs to /homecare/vitals/ which
/// auto-computes NEWS2 and opens an escalation when unsafe.
/// Pass [existing] to edit/update a previously-recorded vitals entry.
class RecordVitalsSheet extends ConsumerStatefulWidget {
  final int? patientId;
  final Map? existing;
  const RecordVitalsSheet({super.key, this.patientId, this.existing});

  @override
  ConsumerState<RecordVitalsSheet> createState() => _RecordVitalsSheetState();
}

class _RecordVitalsSheetState extends ConsumerState<RecordVitalsSheet> {
  late int? _patientId = widget.patientId ?? widget.existing?['patient'] as int?;
  final _systolic = TextEditingController();
  final _diastolic = TextEditingController();
  final _pulse = TextEditingController();
  final _temp = TextEditingController();
  final _spo2 = TextEditingController();
  final _rr = TextEditingController();
  final _glucose = TextEditingController();
  final _weight = TextEditingController();
  final _notes = TextEditingController();
  bool _scale2 = false;
  String _oxygen = 'Room air';
  String? _oxygenDelivery;
  String _consciousness = 'A';
  bool _saving = false;

  bool get _isEditing => widget.existing != null;
  int? get _editId => widget.existing?['id'] as int?;

  static const _oxygenDeliveryModes = [
    'Nasal cannula',
    'Simple face mask',
    'Venturi mask',
    'Non-rebreather mask',
    'Partial rebreather mask',
    'High-flow nasal cannula (HFNC)',
    'CPAP',
    'BiPAP / NIV',
    'Tracheostomy mask',
    'T-piece',
    'Nebuliser',
    'Oxygen hood / headbox',
    'Oxygen tent',
    'Mechanical ventilation',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _systolic.text = e['systolic']?.toString() ?? '';
      _diastolic.text = e['diastolic']?.toString() ?? '';
      _pulse.text = e['pulse']?.toString() ?? '';
      _temp.text = e['temperature']?.toString() ?? '';
      _spo2.text = e['spo2']?.toString() ?? '';
      _rr.text = e['rr']?.toString() ?? '';
      _glucose.text = e['glucose']?.toString() ?? '';
      _weight.text = e['weight']?.toString() ?? '';
      _notes.text = _readNote(e['notes']);
      _scale2 = e['scale2'] == true;
      final o = e['oxygen'];
      _oxygen = (o == true || o == 'Supplemental O₂')
          ? 'Supplemental O₂'
          : 'Room air';
      _oxygenDelivery = e['oxygen_delivery']?.toString();
      final c = e['consciousness']?.toString();
      _consciousness = (c != null && c.isNotEmpty) ? c : 'A';
    }
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

  News2Result get _news2 => calcNews2(
        rr: num.tryParse(_rr.text),
        spo2: num.tryParse(_spo2.text),
        scale2: _scale2,
        oxygen: _oxygen,
        systolic: num.tryParse(_systolic.text),
        heartRate: num.tryParse(_pulse.text),
        temperature: num.tryParse(_temp.text),
        consciousness: _consciousness,
      );

  void _recalc() => setState(() {});

  List<String> get _missingRequired {
    final missing = <String>[];
    if (_rr.text.isEmpty) missing.add('Resp rate');
    if (_spo2.text.isEmpty) missing.add('SpO₂');
    if (_systolic.text.isEmpty) missing.add('Systolic BP');
    if (_pulse.text.isEmpty) missing.add('Heart rate');
    if (_temp.text.isEmpty) missing.add('Temperature');
    return missing;
  }

  Future<void> _submit() async {
    if (_patientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a patient first.')));
      return;
    }
    final missing = _missingRequired;
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Required: ${missing.join(', ')}')));
      return;
    }
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      final news2 = _news2.total;
      final payload = <String, dynamic>{
        'patient': _patientId,
        if (_systolic.text.isNotEmpty)
          'systolic': num.tryParse(_systolic.text),
        if (_diastolic.text.isNotEmpty)
          'diastolic': num.tryParse(_diastolic.text),
        if (_pulse.text.isNotEmpty) 'pulse': num.tryParse(_pulse.text),
        if (_temp.text.isNotEmpty) 'temperature': num.tryParse(_temp.text),
        if (_spo2.text.isNotEmpty) 'spo2': num.tryParse(_spo2.text),
        if (_rr.text.isNotEmpty) 'rr': num.tryParse(_rr.text),
        if (_glucose.text.isNotEmpty)
          'glucose': num.tryParse(_glucose.text),
        if (_weight.text.isNotEmpty) 'weight': num.tryParse(_weight.text),
        'scale2': _scale2,
        'oxygen': _oxygen,
        if (_oxygenDelivery != null) 'oxygen_delivery': _oxygenDelivery,
        'consciousness': _consciousness,
        'news2': news2,
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      };
      dynamic res;
      if (_isEditing) {
        res = await dio
            .patch('/homecare/vitals/$_editId/', data: payload);
      } else {
        res = await dio.post('/homecare/vitals/', data: payload);
      }
      if (mounted) {
        final respNews2 = res.data?['news2'] ?? news2;
        final escalated = res.data?['escalated'] == true;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing
              ? 'Vitals updated — NEWS2 $respNews2.'
              : escalated
                  ? 'Recorded — NEWS2 $respNews2. Escalation opened!'
                  : 'Vitals recorded — NEWS2 $respNews2.'),
          backgroundColor: escalated && !_isEditing ? hcRed : null,
        ));
      }
    } catch (e) {
      String msg = _isEditing
          ? 'Could not update vitals.'
          : 'Could not record vitals.';
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

  @override
  void dispose() {
    _systolic.dispose();
    _diastolic.dispose();
    _pulse.dispose();
    _temp.dispose();
    _spo2.dispose();
    _rr.dispose();
    _glucose.dispose();
    _weight.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(_vitalsPatientsProvider);
    final n = _news2;

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
            Text(_isEditing ? 'Edit vitals' : 'Record vitals',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Fields marked * are required. NEWS2 is scored automatically on save.',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 14),
            // ── Aggregate NEWS2 panel ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    n.riskColor.withValues(alpha: 0.18),
                    n.riskColor.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: n.riskColor.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AGGREGATE NEWS2',
                      style: TextStyle(
                          color: n.riskColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('${n.total}',
                          style: TextStyle(
                              color: n.riskColor,
                              fontSize: 38,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(width: 6),
                      Text('/ 20',
                          style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: n.riskColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('${n.riskLabel} risk',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  for (final b in n.breakdown)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
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
                                style: const TextStyle(fontSize: 12))),
                        Text(b.value,
                            style: TextStyle(
                                fontSize: 11.5,
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
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: b.score >= 3
                                      ? hcRed
                                      : b.score > 0
                                          ? hcAmber
                                          : hcGreen)),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
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
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: _rr,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _recalc(),
                      decoration: InputDecoration(
                          labelText: 'Resp rate *',
                          suffixText: '/min',
                          helperText:
                              'Score: ${scoreRR(num.tryParse(_rr.text))}'))),
              const SizedBox(width: 8),
              Expanded(
                  child: TextField(
                      controller: _spo2,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _recalc(),
                      decoration: InputDecoration(
                          labelText: 'SpO₂ *',
                          suffixText: '%',
                          helperText:
                              'Score: ${_scale2 ? scoreSpO2Scale2(num.tryParse(_spo2.text), _oxygen == 'Supplemental O₂') : scoreSpO2Scale1(num.tryParse(_spo2.text))}'))),
            ]),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _scale2,
              title: const Text('SpO₂ Scale 2 (hypercapnic / COPD target 88–92%)',
                  style: TextStyle(fontSize: 12.5)),
              onChanged: (v) => setState(() => _scale2 = v),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                  child: DropdownButtonFormField<String>(
                initialValue: _oxygen,
                decoration: InputDecoration(
                    labelText: 'Oxygen *',
                    helperText: 'Score: ${scoreOxygen(_oxygen)}'),
                items: const [
                  DropdownMenuItem(
                      value: 'Room air', child: Text('Room air')),
                  DropdownMenuItem(
                      value: 'Supplemental O₂', child: Text('Supplemental O₂')),
                ],
                onChanged: (v) => setState(() => _oxygen = v ?? 'Room air'),
              )),
              const SizedBox(width: 8),
              Expanded(
                child: _oxygen == 'Supplemental O₂'
                    ? DropdownButtonFormField<String>(
                        initialValue: _oxygenDelivery,
                        decoration:
                            const InputDecoration(labelText: 'Delivery mode'),
                        items: _oxygenDeliveryModes
                            .map((m) =>
                                DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _oxygenDelivery = v),
                      )
                    : Container(),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: DropdownButtonFormField<String>(
                initialValue: _consciousness,
                decoration: InputDecoration(
                    labelText: 'ACVPU *',
                    helperText:
                        'Score: ${scoreConsciousness(_consciousness)}'),
                items: const [
                  DropdownMenuItem(value: 'A', child: Text('A - Alert')),
                  DropdownMenuItem(
                      value: 'C', child: Text('C - New confusion')),
                  DropdownMenuItem(value: 'V', child: Text('V - Voice')),
                  DropdownMenuItem(value: 'P', child: Text('P - Pain')),
                  DropdownMenuItem(value: 'U', child: Text('U - Unresponsive')),
                ],
                onChanged: (v) => setState(() => _consciousness = v ?? 'A'),
              )),
              const SizedBox(width: 8),
              Expanded(
                  child: TextField(
                      controller: _systolic,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _recalc(),
                      decoration: InputDecoration(
                          labelText: 'Systolic BP *',
                          suffixText: 'mmHg',
                          helperText:
                              'Score: ${scoreSBP(num.tryParse(_systolic.text))}'))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: _diastolic,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Diastolic BP',
                          suffixText: 'mmHg',
                          helperText: 'Recorded (not scored)'))),
              const SizedBox(width: 8),
              Expanded(
                  child: TextField(
                      controller: _pulse,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _recalc(),
                      decoration: InputDecoration(
                          labelText: 'Heart rate *',
                          suffixText: 'bpm',
                          helperText:
                              'Score: ${scoreHR(num.tryParse(_pulse.text))}'))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: _temp,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      onChanged: (_) => _recalc(),
                      decoration: InputDecoration(
                          labelText: 'Temperature *',
                          suffixText: '°C',
                          helperText:
                              'Score: ${scoreTemp(num.tryParse(_temp.text))}'))),
              const SizedBox(width: 8),
              Expanded(
                  child: TextField(
                      controller: _glucose,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Glucose',
                          suffixText: 'mmol/L',
                          helperText: 'Optional'))),
            ]),
            const SizedBox(height: 10),
            TextField(
                controller: _weight,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Weight',
                    suffixText: 'kg',
                    helperText: 'Optional')),
            const SizedBox(height: 10),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: hcRose),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.monitor_heart_rounded, size: 18),
                label: Text(_isEditing ? 'Update vitals' : 'Save & score NEWS2'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
