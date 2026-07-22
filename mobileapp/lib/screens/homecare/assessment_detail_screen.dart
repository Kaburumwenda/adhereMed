import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import 'assessment_scoring.dart';
import 'hc_common.dart';

/// Assessment detail view — mirrors the web
/// /homecare/assessments/[id] page.
class HomecareAssessmentDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const HomecareAssessmentDetailScreen({super.key, required this.id});

  @override
  ConsumerState<HomecareAssessmentDetailScreen> createState() =>
      _HomecareAssessmentDetailScreenState();
}

class _HomecareAssessmentDetailScreenState
    extends ConsumerState<HomecareAssessmentDetailScreen> {
  Map? _session;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/homecare/assessment-sessions/${widget.id}/');
      setState(() => _session = res.data is Map ? res.data as Map : null);
    } catch (_) {
      setState(() => _error = 'Could not load assessment');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Assessment')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 44, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error ?? 'Not found'),
            const SizedBox(height: 12),
            FilledButton.icon(
                onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ]),
        ),
      );
    }
    final s = _session!;
    final ini = (s['initial_survey'] ?? {}) as Map;
    final h2t = (s['head_to_toe'] ?? {}) as Map;
    final alerts = generateAlerts({
      'braden_total': s['braden_total'],
      'caprini_points': s['caprini_points'],
      'morse_score': s['morse_score'],
      'must_score': s['must_score'],
      'cam_positive': s['cam_positive'],
      'pain_score': s['pain_score'],
      'braden': s['braden'] ?? {},
      'vte_caprini': s['vte_caprini'] ?? {},
      'falls': s['falls'] ?? {},
      'must': s['must'] ?? {},
      'catheter_bundle': s['catheter_bundle'] ?? {},
      'central_line_bundle': s['central_line_bundle'] ?? {},
      'disease_bundles': s['disease_bundles'] ?? {},
    });
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _hero(s, alerts.length),
            HcPanel(
              title: 'Initial Survey',
              subtitle: 'Arrival + vital signs + primary survey',
              icon: Icons.account_circle_rounded,
              color: hcTeal,
              child: Column(children: [
                _row('Temperature', ini['temperature'] != null ? '${ini['temperature']} °C' : '—'),
                _row('Blood Pressure',
                    ini['systolic_bp'] != null ? '${ini['systolic_bp']}/${ini['diastolic_bp']} mmHg' : '—'),
                _row('Heart Rate', ini['heart_rate'] != null ? '${ini['heart_rate']} bpm' : '—'),
                _row('Respiratory Rate',
                    ini['respiratory_rate'] != null ? '${ini['respiratory_rate']} /min' : '—'),
                _row('SpO₂', ini['spo2'] != null ? '${ini['spo2']}%' : '—'),
                _row('Consciousness', ini['consciousness']?.toString() ?? '—'),
                _row('Pain Score', _painDisplay(ini['pain_score'])),
                _row('Skin Integrity', ini['skin_integrity']?.toString() ?? '—'),
                _row('Skin Moisture', ini['skin_moisture']?.toString() ?? '—'),
                _row('Chief concern', ini['chief_concern']?.toString() ?? '—'),
                _row('General appearance', ini['general_appearance']?.toString() ?? '—'),
                _row('Recent falls', ini['recent_falls']?.toString() ?? '—'),
                _row('Devices', _devices(ini)),
                _row('Allergies', ini['allergies']?.toString() ?? '—'),
              ]),
            ),
            HcPanel(
              title: 'Head-to-Toe',
              subtitle: 'Systematic body systems survey',
              icon: Icons.accessibility_new_rounded,
              color: hcBlue,
              child: Column(children: [
                _row('Orientation',
                    'Time: ${_bool(h2t['oriented_time'])} · Place: ${_bool(h2t['oriented_place'])} · Person: ${_bool(h2t['oriented_person'])}'),
                _row('Mobility', h2t['mobility_level']?.toString() ?? '—'),
                _row('Heart Rhythm', h2t['heart_rhythm']?.toString() ?? '—'),
                _row('Peripheral pulses', h2t['peripheral_pulses']?.toString() ?? '—'),
                _row('Breath Sounds', h2t['breath_sounds']?.toString() ?? '—'),
                _row('Respiratory Effort', h2t['resp_effort']?.toString() ?? '—'),
                if (h2t['on_oxygen'] == true)
                  _row('Oxygen', '${h2t['oxygen_flow_lpm'] ?? '—'} LPM via ${h2t['oxygen_mode'] ?? '—'}'),
                _row('Abdomen',
                    '${h2t['abdomen_shape'] ?? '—'} · Bowel: ${h2t['bowel_sounds'] ?? '—'}'),
                _row('Continence',
                    'Urinary: ${h2t['urinary_continence'] ?? '—'} · Bowel: ${h2t['bowel_continence'] ?? '—'}'),
                if (h2t['any_wounds'] == true)
                  _row('Wounds', '${(h2t['wound_descriptions'] as List?)?.length ?? 0} wound(s) noted'),
              ]),
            ),
            HcPanel(
              title: 'Risk Scores',
              subtitle: 'Validated scales at a glance',
              icon: Icons.shield_rounded,
              color: hcPurple,
              child: Column(children: [
                _riskRow('Braden (pressure)', s['braden_total'], '/23',
                    s['braden']?['risk_level']?.toString() ?? '', _bradenColor(s['braden_total'])),
                _riskRow('Caprini (VTE)', s['caprini_points'], 'pts',
                    s['vte_caprini']?['risk_level']?.toString() ?? '', _capriniColor(s['caprini_points'])),
                _riskRow('Morse (falls)', s['morse_score'], '/125',
                    s['falls']?['risk_level']?.toString() ?? '', _morseColor(s['morse_score'])),
                _riskRow('MUST (nutrition)', s['must_score'], '/6',
                    s['must']?['risk_level']?.toString() ?? '', _mustColor(s['must_score'])),
                _riskRow('CAM (delirium)', s['cam_positive'] == true ? 'Pos' : 'Neg', '',
                    s['cam_positive'] == true ? 'Delirium' : 'Normal',
                    s['cam_positive'] == true ? hcRed : hcGreen),
                _riskRow('Pain (NRS)', s['pain_score'], '/10',
                    painCategory(_n(s['pain_score'])), _painColor(s['pain_score'])),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _hex(riskMeta[s['overall_risk_level']]?.hex ?? '#64748b'),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.shield_rounded, color: Colors.white),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('OVERALL RISK LEVEL',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                      Text(
                          (s['overall_risk_label']?.toString().isNotEmpty == true
                              ? s['overall_risk_label'].toString()
                              : (riskMeta[s['overall_risk_level']]?.label ??
                                  s['overall_risk_level']?.toString() ??
                                  'Unknown')),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    ]),
                  ]),
                ),
              ]),
            ),
            if (alerts.isNotEmpty)
              HcPanel(
                title: 'Clinical Alerts (${alerts.length})',
                subtitle: 'Threshold-triggered notifications requiring action',
                icon: Icons.notifications_active_rounded,
                color: hcRed,
                child: Column(children: [
                  for (final a in alerts)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (a.severity == 'critical' || a.severity == 'high'
                            ? hcRed
                            : hcAmber).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(
                              a.severity == 'critical'
                                  ? Icons.dangerous_rounded
                                  : Icons.warning_amber_rounded,
                              size: 16,
                              color: a.severity == 'critical' ? hcRed : hcAmber),
                          const SizedBox(width: 6),
                          Text(a.title,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(width: 6),
                          Text(a.code,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ]),
                        Text(a.detail, style: const TextStyle(fontSize: 12)),
                        if (a.recommendation != null)
                          Text('℞ ${a.recommendation}',
                              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                      ]),
                    ),
                ]),
              ),
            _scaleBreakdowns(s),
            if ((s['notes']?.toString() ?? '').isNotEmpty)
              HcPanel(
                title: 'Notes',
                subtitle: null,
                icon: Icons.note_alt_rounded,
                color: hcSlate,
                child: Text(s['notes'].toString(), style: const TextStyle(fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }

  // ── Hero ──
  Widget _hero(Map s, int alertCount) {
    final risk = s['overall_risk_level']?.toString() ?? '';
    final riskColor = _hex(riskMeta[risk]?.hex ?? '#64748b');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hcTeal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: hcTeal.withValues(alpha: 0.22)),
            ),
            child: const Icon(Icons.assignment_rounded, color: hcTeal, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('CLINICAL ASSESSMENT',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: hcTeal)),
              Text(s['patient_name']?.toString() ?? 'Patient Assessment',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ]),
          ),
          TextButton.icon(
            onPressed: () => context.go('/homecare/assessments'),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Back'),
          ),
        ]),
        const SizedBox(height: 8),
        Text(
            '${s['session_type_label'] ?? hcLabel(s['session_type']?.toString())} · ${hcDateTime(s['assessed_at'])} · by ${s['assessed_by_name']?.toString().isEmpty == false ? s['assessed_by_name'] : '—'}',
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          HcStatusChip(
              label: s['session_type_label']?.toString() ??
                  hcLabel(s['session_type']?.toString()),
              color: hcTeal),
          if (risk.isNotEmpty)
            HcStatusChip(
                label: (s['overall_risk_label']?.toString().isNotEmpty == true
                        ? s['overall_risk_label'].toString()
                        : risk)
                    .toUpperCase(),
                color: riskColor),
          if (alertCount > 0)
            HcStatusChip(
                label: '$alertCount alert${alertCount == 1 ? '' : 's'}',
                color: hcRed,
                icon: Icons.notification_important_rounded),
        ]),
      ]),
    );
  }

  // ── Scale breakdowns (accordion) ──
  Widget _scaleBreakdowns(Map s) {
    final panels = <Widget>[];
    if (s['braden'] != null) {
      panels.add(_expandTile(
        title: 'Braden Scale — Pressure Ulcer Risk',
        icon: Icons.airline_seat_flat_rounded,
        color: _bradenColor(s['braden_total']),
        chip: '${s['braden_total']} · ${s['braden']?['risk_level'] ?? ''}',
        child: Column(
          children: [
            for (final sub in bradenSubscales)
              _row(sub.label, '${s['braden']?[sub.key] ?? '—'}'),
          ],
        ),
      ));
    }
    if (s['vte_caprini'] != null) {
      panels.add(_expandTile(
        title: 'Caprini Score — VTE Risk',
        icon: Icons.bloodtype_rounded,
        color: _capriniColor(s['caprini_points']),
        chip: '${s['caprini_points']} · ${s['vte_caprini']?['risk_level'] ?? ''}',
        child: Column(
          children: [
            for (final f in capriniFactors)
              _row('${f.label} (${f.points}pt)',
                  (s['vte_caprini']?['factors']?[f.key] == true) ? 'Present' : '—'),
          ],
        ),
      ));
    }
    if (s['falls'] != null) {
      panels.add(_expandTile(
        title: 'Morse Fall Scale',
        icon: Icons.elderly_rounded,
        color: _morseColor(s['morse_score']),
        chip: '${s['morse_score']} · ${s['falls']?['risk_level'] ?? ''}',
        child: Column(children: [
          _row('History of falls', s['falls']?['history_of_falls'] == true ? '15' : '0'),
          _row('Secondary diagnosis', s['falls']?['secondary_dx'] == true ? '15' : '0'),
          _row('Ambulatory aid', s['falls']?['ambulatory_aid']?.toString() ?? '—'),
          _row('IV / heparin lock', s['falls']?['iv_lock'] == true ? '15' : '0'),
          _row('Gait', s['falls']?['gait']?.toString() ?? '—'),
          _row('Mental status', s['falls']?['mental_status']?.toString() ?? '—'),
        ]),
      ));
    }
    if (s['must'] != null) {
      panels.add(_expandTile(
        title: 'MUST — Malnutrition Risk',
        icon: Icons.restaurant_rounded,
        color: _mustColor(s['must_score']),
        chip: '${s['must_score']} · ${s['must']?['risk_level'] ?? ''}',
        child: Column(children: [
          _row('BMI', s['must']?['bmi']?.toString() ?? '—'),
          _row('Weight loss', s['must']?['weight_loss_percent'] != null
              ? '${s['must']['weight_loss_percent']}%'
              : '—'),
          _row('Acute illness / no intake >5d',
              _bool(s['must']?['acute_no_nutrition'])),
        ]),
      ));
    }
    if (s['cam'] != null) {
      panels.add(_expandTile(
        title: 'CAM — Delirium Screen',
        icon: Icons.psychology_rounded,
        color: s['cam_positive'] == true ? hcRed : hcGreen,
        chip: s['cam_positive'] == true ? 'POSITIVE' : 'Negative',
        child: Column(children: [
          _row('Acute onset / fluctuating', _bool(s['cam']?['acute_onset'])),
          _row('Inattention', _bool(s['cam']?['inattention'])),
          _row('Disorganised thinking', _bool(s['cam']?['disorganized_thinking'])),
          _row('Altered consciousness', _bool(s['cam']?['altered_consciousness'])),
        ]),
      ));
    }
    final cb = (s['catheter_bundle'] ?? {}) as Map;
    if (cb['present'] == true) {
      panels.add(_expandTile(
        title: 'Catheter Bundle (CAUTI Prevention)',
        icon: Icons.water_drop_rounded,
        color: hcBlue,
        chip: cb['needs_review'] == true ? 'Review due' : 'Indicated',
        child: Column(children: [
          _row('Type', cb['type']?.toString() ?? '—'),
          _row('Insertion date', cb['insert_date']?.toString() ?? '—'),
          _row('Indication', cb['indication']?.toString() ?? '—'),
          _row('Closed system maintained', _bool(cb['closed_system_maintained'])),
          _row('Bag below bladder', _bool(cb['bag_below_bladder'])),
          _row('Needs review', _bool(cb['needs_review'])),
        ]),
      ));
    }
    final clb = (s['central_line_bundle'] ?? {}) as Map;
    if (clb['present'] == true) {
      panels.add(_expandTile(
        title: 'Central Line Bundle (CLABSI Prevention)',
        icon: Icons.colorize_rounded,
        color: hcPurple,
        chip: clb['needs_removal'] == true ? 'Review due' : 'Indicated',
        child: Column(children: [
          _row('Type', clb['type']?.toString() ?? '—'),
          _row('Insertion site', clb['insert_site']?.toString() ?? '—'),
          _row('Maximal barrier used', _bool(clb['maximal_barrier'])),
          _row('Hub scrub protocol', _bool(clb['hub_scrub'])),
          _row('Needs removal', _bool(clb['needs_removal'])),
        ]),
      ));
    }
    final vb = (s['ventilator_bundle'] ?? {}) as Map;
    if (vb['present'] == true) {
      panels.add(_expandTile(
        title: 'Ventilator Bundle (VAP Prevention)',
        icon: Icons.air_rounded,
        color: hcRed,
        child: Column(children: [
          _row('Head of bed ≥30°', _bool(vb['head_of_bed_elevated'])),
          _row('Daily SBT', _bool(vb['daily_sbt'])),
          _row('Sedation vacation', _bool(vb['sedation_vacation'])),
          _row('Oral care performed', _bool(vb['oral_care'])),
          _row('Settings', vb['vent_settings']?.toString() ?? '—'),
        ]),
      ));
    }
    final wb = (s['wound_bundle'] ?? {}) as Map;
    if (wb['present'] == true) {
      panels.add(_expandTile(
        title: 'Wound / Pressure Injury Bundle — NPIAP',
        icon: Icons.healing_rounded,
        color: hcAmber,
        child: Column(children: [
          _row('Turn schedule', 'Every ${wb['turn_schedule_hours'] ?? '—'} h'),
          _row('Special mattress', _bool(wb['special_mattress'])),
          _row('Barrier cream', _bool(wb['barrier_cream'])),
          if ((wb['wound_details'] as List?)?.isNotEmpty == true)
            ...(wb['wound_details'] as List)
                .map((w) => _row('• ${(w as Map)['location']}', '${w['type']} (${w['size']})')),
        ]),
      ));
    }
    final db = (s['disease_bundles'] ?? {}) as Map;
    final dm = (db['diabetes'] ?? {}) as Map;
    if (dm['foot_ulcer'] != null || dm['latest_bg'] != null) {
      panels.add(_expandTile(
        title: 'Diabetes Bundle',
        icon: Icons.water_drop_rounded,
        color: hcBlue,
        child: Column(children: [
          _row('Foot ulcer', _bool(dm['foot_ulcer'])),
          _row('Neuropathy', _bool(dm['neuropathy'])),
          if (dm['latest_bg'] != null) _row('Blood glucose', '${dm['latest_bg']} mg/dL'),
          if (dm['latest_bg_mmol'] != null)
            _row('Blood glucose (mmol/L)', '${dm['latest_bg_mmol']} mmol/L'),
          _row('Insulin pump', _bool(dm['insulin_pump'])),
          if (dm['last_foot_check'] != null)
            _row('Last foot inspection', dm['last_foot_check'].toString()),
        ]),
      ));
    }
    final hf = (db['heart_failure'] ?? {}) as Map;
    if (hf['daily_weight'] != null || (hf['edema']?.toString() ?? 'None') != 'None') {
      panels.add(_expandTile(
        title: 'Heart Failure Bundle',
        icon: Icons.favorite_rounded,
        color: hcRed,
        child: Column(children: [
          if (hf['daily_weight'] != null) _row('Daily weight', '${hf['daily_weight']} kg'),
          _row('Edema', hf['edema']?.toString() ?? 'None'),
          _row('SOB at rest', _bool(hf['sob_at_rest'])),
          _row('SOB on exertion', _bool(hf['sob_on_exertion'])),
          _row('Orthopnea', _bool(hf['orthopnea'])),
          _row('JVD', _bool(hf['jvd'])),
          _row('Lung crackles', _bool(hf['lung_crackles'])),
        ]),
      ));
    }

    if (panels.isEmpty) return const SizedBox();
    return HcPanel(
      title: 'Detailed Scale Breakdowns',
      subtitle: 'Individual component scores per validated tool',
      icon: Icons.bar_chart_rounded,
      color: hcGreen,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: EdgeInsets.zero,
          title: const Text('Expand all scales',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          children: panels,
        ),
      ),
    );
  }

  // ── helpers ──
  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 140,
            child: Text(label,
                style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant))),
        Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _riskRow(String label, dynamic score, String unit, String riskLabel, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            if (riskLabel.isNotEmpty)
              Text(riskLabel, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w700)),
          ]),
        ),
        Text('${score ?? '—'}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        if (unit.isNotEmpty)
          Text(unit, style: TextStyle(fontSize: 11, color: color)),
      ]),
    );
  }

  Widget _expandTile({
    required String title,
    required IconData icon,
    required Color color,
    String? chip,
    required Widget child,
  }) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        if (chip != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(7)),
            child: Text(chip,
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
      ]),
      children: [Padding(padding: const EdgeInsets.only(top: 4), child: child)],
    );
  }

  String _painDisplay(dynamic v) =>
      v == null ? '—' : '$v/10';
  String _devices(Map ini) {
    final d = <String>[];
    if (ini['has_catheter'] == true) d.add('Catheter');
    if (ini['has_central_line'] == true) d.add('Central line');
    if (ini['has_ventilator'] == true) d.add('Ventilator');
    if (ini['has_wound'] == true) d.add('Wound');
    return d.isEmpty ? 'None' : d.join(', ');
  }

  String _bool(dynamic v) => v == true ? 'Yes' : 'No';

  Color _bradenColor(dynamic v) {
    final n = _n(v);
    if (n == null) return hcSlate;
    if (n <= 12) return hcRed;
    if (n <= 18) return hcAmber;
    return hcGreen;
  }

  Color _capriniColor(dynamic v) {
    final n = _n(v);
    if (n == null) return hcSlate;
    if (n >= 5) return hcRed;
    if (n >= 3) return hcAmber;
    return hcGreen;
  }

  Color _morseColor(dynamic v) {
    final n = _n(v);
    if (n == null) return hcSlate;
    if (n >= 45) return hcRed;
    if (n >= 25) return hcAmber;
    return hcGreen;
  }

  Color _mustColor(dynamic v) {
    final n = _n(v);
    if (n == null) return hcSlate;
    if (n >= 2) return hcRed;
    if (n == 1) return hcAmber;
    return hcGreen;
  }

  Color _painColor(dynamic v) {
    final n = _n(v);
    if (n == null) return hcSlate;
    if (n >= 7) return hcRed;
    if (n >= 4) return hcAmber;
    return hcGreen;
  }

  num? _n(dynamic v) {
    if (v == null) return null;
    return num.tryParse(v.toString());
  }

  Color _hex(String hex) {
    final c = hex.replaceAll('#', '');
    return Color(int.parse('FF$c', radix: 16));
  }
}
