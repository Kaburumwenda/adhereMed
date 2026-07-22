import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../providers/auth_provider.dart';
import 'assessment_scoring.dart';
import 'hc_common.dart';

/// New comprehensive assessment — mirrors the web
/// /homecare/assessments/new wizard (6-step stepper).
class HomecareAssessmentNewScreen extends ConsumerStatefulWidget {
  const HomecareAssessmentNewScreen({super.key});

  @override
  ConsumerState<HomecareAssessmentNewScreen> createState() =>
      _HomecareAssessmentNewScreenState();
}

class _HomecareAssessmentNewScreenState
    extends ConsumerState<HomecareAssessmentNewScreen> {
  late final Map<String, dynamic> _form = emptyForm();
  int _step = 1;
  static const int _maxStep = 6;
  bool _saving = false;
  final _pinCtrl = TextEditingController();
  final _patients = <Map>[];

  static const _steps = [
    ('Patient & Vitals', Icons.account_circle_rounded),
    ('Head-to-Toe', Icons.accessibility_new_rounded),
    ('Risk Scales', Icons.shield_rounded),
    ('Bundles', Icons.medical_services_rounded),
    ('Disease Bundles', Icons.favorite_rounded),
    ('Review & Save', Icons.check_circle_rounded),
  ];

  Map get _ini => _form['initial_survey'] as Map;
  Map get _h2t => _form['head_to_toe'] as Map;
  Map get _braden => _form['braden'] as Map;
  Map get _caprini => _form['vte_caprini'] as Map;
  Map get _falls => _form['falls'] as Map;
  Map get _must => _form['must'] as Map;
  Map get _cam => _form['cam'] as Map;
  Map get _pain => _form['pain'] as Map;
  Map get _catheter => _form['catheter_bundle'] as Map;
  Map get _cl => _form['central_line_bundle'] as Map;
  Map get _vent => _form['ventilator_bundle'] as Map;
  Map get _wound => _form['wound_bundle'] as Map;
  Map get _db => _form['disease_bundles'] as Map;
  Map get _diabetes => _db['diabetes'] as Map;
  Map get _hf => _db['heart_failure'] as Map;

  void _set(Map m, String k, dynamic v) => setState(() => m[k] = v);

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/homecare/patients/',
          queryParameters: {'is_active': 'true', 'page_size': 500});
      final data = res.data;
      final list = data is List ? data : (data['results'] as List? ?? []);
      setState(() => _patients.addAll(list.cast<Map>()));
    } catch (_) {}
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_form['patient'] == null) {
      _toast('Please select a patient', isError: true);
      return;
    }
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty) {
      _toast('Please enter your staff PIN to sign', isError: true);
      return;
    }
    final myPin = ref.read(authProvider).user?.pin;
    if (myPin != null && myPin.isNotEmpty && pin != myPin) {
      _toast('PIN does not match', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      final braden = calcBraden(Map.from(_braden));
      final caprini = calcCaprini(Map.from(_caprini));
      final falls = calcMorse(Map.from(_falls));
      final must = calcMust(Map.from(_must));
      final cam = calcCam(Map.from(_cam));
      final pain = calcPain(Map.from(_pain));
      final news2 = calcNews2(Map.from(_ini));
      final diabetes = calcDiabetesBundle(Map.from(_diabetes));
      final heartFailure = calcHeartFailureBundle(Map.from(_hf));
      final catheter = _ini['has_catheter'] == true
          ? calcCatheterBundle({...Map.from(_catheter), 'present': true})
          : {'present': false};
      final vent = _ini['has_ventilator'] == true
          ? {...Map.from(_vent), 'present': true}
          : {'present': false};
      final cl = _ini['has_central_line'] == true
          ? {...Map.from(_cl), 'present': true}
          : {'present': false};
      final wound = (_ini['has_wound'] == true || _h2t['any_wounds'] == true)
          ? {...Map.from(_wound), 'present': true}
          : {'present': false};

      final payload = {
        'patient': _form['patient'],
        'session_type': _form['session_type'],
        'arrival': {
          'arrival_timestamp': DateTime.now().toUtc().toIso8601String(),
          'arrival_mode': (_form['arrival'] ?? {})['arrival_mode'] ?? 'Home visit',
        },
        'initial_survey': Map.from(_ini),
        'head_to_toe': Map.from(_h2t),
        'braden': braden,
        'vte_caprini': caprini,
        'falls': falls,
        'must': must,
        'cam': cam,
        'pain': pain,
        'news2': {'total': news2.total, 'risk': news2.riskLabel, 'scores': {}},
        'disease_bundles': {'diabetes': diabetes, 'heart_failure': heartFailure},
        'catheter_bundle': catheter,
        'ventilator_bundle': vent,
        'central_line_bundle': cl,
        'wound_bundle': wound,
        'notes': _form['notes'] ?? '',
        'pin': pin,
      };
      final res = await dio.post('/homecare/assessment-sessions/', data: payload);
      final id = res.data['id'];
      if (mounted) {
        _toast('Assessment saved successfully');
        context.go('/homecare/assessments/$id');
      }
    } catch (e) {
      String msg = 'Failed to save assessment';
      try {
        final data = (e as dynamic).response?.data;
        if (data is Map && data.isNotEmpty) {
          final first = data.entries.first;
          msg =
              '${first.key}: ${first.value is List ? (first.value as List).first : first.value}';
        } else if (data is String) {
          msg = data;
        }
      } catch (_) {}
      if (mounted) {
        _toast(msg, isError: true);
        setState(() => _saving = false);
      }
    }
  }

  void _toast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? hcRed : hcTeal,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _hero(),
          _progress(),
          Card(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _buildStep(_step),
              ),
            ),
          ),
          _nav(),
        ],
      ),
    );
  }

  // ── Hero ──
  Widget _hero() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C3D3A), Color(0xFF0D9488), Color(0xFF0EA5A4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: hcTeal.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 12)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextButton.icon(
          onPressed: () => context.go('/homecare/assessments'),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 18),
          label: const Text('Back to assessments',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
        ),
        const Text('New Assessment',
            style: TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
            'Comprehensive nursing assessment per WHO/CDC guidelines — structured survey, validated risk scales, evidence-based bundles',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
        const SizedBox(height: 12),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999)),
            child: Text('Step $_step / $_maxStep',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Text(_steps[_step - 1].$1,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
        ]),
      ]),
    );
  }

  // ── Step progress chips ──
  Widget _progress() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < _maxStep; i++)
            GestureDetector(
              onTap: () => setState(() => _step = i + 1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: i <= _step - 1
                      ? hcTeal
                      : hcTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_steps[i].$2,
                      size: 14,
                      color: i <= _step - 1 ? Colors.white : hcTeal),
                  const SizedBox(width: 5),
                  Text(_steps[i].$1,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: i <= _step - 1 ? Colors.white : hcTeal)),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  // ── Step body ──
  Widget _buildStep(int step) {
    return switch (step) {
      1 => _step1(),
      2 => _step2(),
      3 => _step3(),
      4 => _step4(),
      5 => _step5(),
      6 => _step6(),
      _ => const SizedBox(),
    };
  }

  // Step 1 — Patient & Arrival + Vitals + Primary Survey
  Widget _step1() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHead('Patient & Arrival',
          'Identify patient and record arrival details', Icons.account_circle_rounded, hcTeal),
      DropdownButtonFormField<int>(
        initialValue: _form['patient'] as int?,
        decoration: const InputDecoration(labelText: 'Patient *', prefixIcon: Icon(Icons.person)),
        items: _patients
            .map((p) => DropdownMenuItem<int>(
                  value: p['id'] as int,
                  child: Text(
                    ((p['patient_name'] ?? p['user']?['full_name'] ?? '#${p['id']}')
                            .toString()) +
                        (p['medical_record_number'] != null
                            ? ' · ${p['medical_record_number']}'
                            : ''),
                    overflow: TextOverflow.ellipsis,
                  ),
                ))
            .toList(),
        onChanged: (v) => _set(_form, 'patient', v),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: _Dropdown(
            label: 'Mode of arrival',
            value: (_form['arrival'] ?? {})['arrival_mode'] ?? 'Home visit',
            options: arrivalModes,
            onChanged: (v) => setState(() {
              _form['arrival'] ??= {};
              _form['arrival']['arrival_mode'] = v;
            }),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Dropdown(
            label: 'Session type',
            value: _form['session_type'] ?? 'initial',
            options: sessionTypes.map((s) => s.$1).toList(),
            optionLabels: {for (final s in sessionTypes) s.$1: s.$2},
            onChanged: (v) => _set(_form, 'session_type', v),
          ),
        ),
      ]),
      const SizedBox(height: 18),
      _sectionHead('Vital Signs', 'Core measurements with NEWS2 clinical pathway',
          Icons.monitor_heart_rounded, hcBlue),
      Row(children: [
        Expanded(child: _numField(_ini, 'respiratory_rate', 'Respiratory rate (/min)')),
        const SizedBox(width: 8),
        Expanded(child: _numField(_ini, 'spo2', 'SpO₂ (%)')),
      ]),
      SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        value: _ini['scale2'] == true,
        title: const Text('SpO₂ Scale 2 (hypercapnic / COPD target 88–92%)', style: TextStyle(fontSize: 13)),
        onChanged: (v) => _set(_ini, 'scale2', v),
      ),
      Row(children: [
        Expanded(
          child: _Dropdown(
            label: 'Oxygen',
            value: _ini['oxygen'] ?? 'Room air',
            options: const ['Room air', 'Supplemental O₂'],
            onChanged: (v) => _set(_ini, 'oxygen', v),
          ),
        ),
        if (_ini['oxygen'] == 'Supplemental O₂') ...[
          const SizedBox(width: 8),
          Expanded(
            child: _Dropdown(
              label: 'Mode of delivery',
              value: _ini['oxygen_delivery'],
              options: oxygenDeliveryModes,
              onChanged: (v) => _set(_ini, 'oxygen_delivery', v),
            ),
          ),
        ],
      ]),
      Row(children: [
        Expanded(
          child: _Dropdown(
            label: 'ACVPU consciousness',
            value: _ini['consciousness'] ?? 'Alert',
            options: avpu,
            onChanged: (v) => _set(_ini, 'consciousness', v),
          ),
        ),
      ]),
      Row(children: [
        Expanded(child: _numField(_ini, 'systolic_bp', 'Systolic BP (mmHg)')),
        const SizedBox(width: 8),
        Expanded(child: _numField(_ini, 'diastolic_bp', 'Diastolic BP (mmHg)')),
      ]),
      Row(children: [
        Expanded(child: _numField(_ini, 'heart_rate', 'Heart rate (bpm)')),
        const SizedBox(width: 8),
        Expanded(child: _numField(_ini, 'temperature', 'Temperature (°C)', decimal: true)),
      ]),
      Row(children: [
        Expanded(child: _numField(_ini, 'glucose', 'Glucose (mmol/L)', decimal: true)),
        const SizedBox(width: 8),
        Expanded(child: _numField(_ini, 'weight', 'Weight (kg)', decimal: true)),
      ]),
      Row(children: [
        Expanded(child: _numField(_ini, 'pain_score', 'Pain (0–10)', max: 10)),
      ]),
      _news2Panel(),
      const SizedBox(height: 14),
      _sectionHead('Primary Survey', 'Initial checks and safety questions per WHO/CDC',
          Icons.shield_rounded, hcPurple),
      _textarea(_ini, 'chief_concern', 'Chief concern / reason for visit'),
      _textarea(_ini, 'general_appearance', 'General appearance'),
      Row(children: [
        Expanded(
          child: _Dropdown(
            label: 'Skin integrity',
            value: _ini['skin_integrity'] ?? 'Intact',
            options: skinIntegrity,
            onChanged: (v) => _set(_ini, 'skin_integrity', v),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Dropdown(
            label: 'Skin moisture',
            value: _ini['skin_moisture'] ?? 'Normal',
            options: skinMoisture,
            onChanged: (v) => _set(_ini, 'skin_moisture', v),
          ),
        ),
      ]),
      _numField(_ini, 'recent_falls', 'Falls (12 mo)'),
      Wrap(
        spacing: 4,
        children: [
          _checkChip(_ini, 'has_catheter', 'Catheter'),
          _checkChip(_ini, 'has_central_line', 'Central line'),
          _checkChip(_ini, 'has_ventilator', 'Ventilator'),
          _checkChip(_ini, 'has_wound', 'Wound'),
        ],
      ),
      _txtField(_ini, 'allergies', 'Allergies'),
      _txtField(_ini, 'current_meds', 'Current medications'),
    ]);
  }

  Widget _news2Panel() {
    final n = calcNews2(Map.from(_ini));
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hcBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hcBlue.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('AGGREGATE NEWS2',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: hcBlue)),
          const Spacer(),
          if (n.willEscalate)
            HcStatusChip(label: 'Escalate', color: hcRed, icon: Icons.priority_high_rounded),
        ]),
        Text('${n.total}',
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: hcBlue)),
        HcStatusChip(label: '${n.riskLabel} risk', color: hcBlue),
        const SizedBox(height: 8),
        Text(n.clinicalPathway, style: const TextStyle(fontSize: 12)),
      ]),
    );
  }

  // Step 2 — Head-to-Toe
  Widget _step2() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHead('Neuro & General', 'Neurological status, orientation, mobility',
          Icons.psychology_rounded, hcPurple),
      Wrap(
        spacing: 4,
        children: [
          _checkChip(_h2t, 'oriented_time', 'Oriented to time'),
          _checkChip(_h2t, 'oriented_place', 'Oriented to place'),
          _checkChip(_h2t, 'oriented_person', 'Oriented to person'),
          _checkChip(_h2t, 'pupil_reactive', 'Pupils reactive'),
        ],
      ),
      Row(children: [
        Expanded(
          child: _Dropdown(
            label: 'Mobility',
            value: _h2t['mobility_level'] ?? 'Independent',
            options: mobilityLevels,
            onChanged: (v) => _set(_h2t, 'mobility_level', v),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _txtField(_h2t, 'speech', 'Speech issues')),
      ]),
      _sectionHead('Eyes / ENT / Oral', 'Vision, hearing, oral health',
          Icons.visibility_rounded, hcBlue, top: 14),
      _txtField(_h2t, 'vision_problems', 'Vision'),
      _txtField(_h2t, 'hearing_problems', 'Hearing'),
      _txtField(_h2t, 'oral_status', 'Oral health'),
      _sectionHead('Cardiovascular', 'Heart rhythm, peripheral perfusion',
          Icons.favorite_rounded, hcRed, top: 14),
      Row(children: [
        Expanded(
          child: _Dropdown(
            label: 'Heart rhythm',
            value: _h2t['heart_rhythm'] ?? 'Normal Sinus',
            options: heartRhythms,
            onChanged: (v) => _set(_h2t, 'heart_rhythm', v),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Dropdown(
            label: 'Peripheral pulses',
            value: _h2t['peripheral_pulses'] ?? 'Present',
            options: peripheralPulses,
            onChanged: (v) => _set(_h2t, 'peripheral_pulses', v),
          ),
        ),
      ]),
      _sectionHead('Respiratory', 'Breath sounds, effort, oxygen therapy',
          Icons.air_rounded, hcTeal, top: 14),
      Row(children: [
        Expanded(
          child: _Dropdown(
            label: 'Breath sounds',
            value: _h2t['breath_sounds'] ?? 'Clear',
            options: breathSounds,
            onChanged: (v) => _set(_h2t, 'breath_sounds', v),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Dropdown(
            label: 'Resp. effort',
            value: _h2t['resp_effort'] ?? 'Normal',
            options: respEfforts,
            onChanged: (v) => _set(_h2t, 'resp_effort', v),
          ),
        ),
      ]),
      SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        value: _h2t['on_oxygen'] == true,
        title: const Text('On oxygen', style: TextStyle(fontSize: 13)),
        onChanged: (v) => _set(_h2t, 'on_oxygen', v),
      ),
      if (_h2t['on_oxygen'] == true)
        Row(children: [
          Expanded(child: _numField(_h2t, 'oxygen_flow_lpm', 'O₂ flow (LPM)', decimal: true)),
          const SizedBox(width: 8),
          Expanded(
            child: _Dropdown(
              label: 'O₂ mode',
              value: _h2t['oxygen_mode'],
              options: oxygenModes,
              onChanged: (v) => _set(_h2t, 'oxygen_mode', v),
            ),
          ),
        ]),
      _sectionHead('Abdomen / GI', 'Abdominal assessment, bowel function',
          Icons.restaurant_rounded, hcAmber, top: 14),
      Row(children: [
        Expanded(
          child: _Dropdown(
            label: 'Abdomen shape',
            value: _h2t['abdomen_shape'] ?? 'Soft',
            options: abdomenShapes,
            onChanged: (v) => _set(_h2t, 'abdomen_shape', v),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Dropdown(
            label: 'Bowel sounds',
            value: _h2t['bowel_sounds'] ?? 'Normal',
            options: bowelSounds,
            onChanged: (v) => _set(_h2t, 'bowel_sounds', v),
          ),
        ),
      ]),
      _sectionHead('Continence & Nutrition', 'Bladder, bowel control, feeding ability',
          Icons.accessibility_rounded, hcTeal, top: 14),
      Row(children: [
        Expanded(
          child: _Dropdown(
            label: 'Urinary continence',
            value: _h2t['urinary_continence'] ?? 'Continent',
            options: continence,
            onChanged: (v) => _set(_h2t, 'urinary_continence', v),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Dropdown(
            label: 'Bowel continence',
            value: _h2t['bowel_continence'] ?? 'Continent',
            options: continence,
            onChanged: (v) => _set(_h2t, 'bowel_continence', v),
          ),
        ),
      ]),
      Row(children: [
        Expanded(
          child: _Dropdown(
            label: 'Nutrition assist',
            value: _h2t['nutrition_assist'] ?? 'Independent',
            options: nutritionAssist,
            onChanged: (v) => _set(_h2t, 'nutrition_assist', v),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _checkChip(_h2t, 'dysphagia', 'Dysphagia')),
      ]),
      _sectionHead('Skin / Wounds', 'Full skin check — pressure points, wounds',
          Icons.healing_rounded, hcRed, top: 14),
      _checkChip(_h2t, 'any_wounds', 'Has wounds / pressure injuries'),
      if (_h2t['any_wounds'] == true)
        _textarea(_h2t, 'wound_descriptions_raw',
            'Wound descriptions (location, size, type — one per line)'),
    ]);
  }

  // Step 3 — Risk Scales
  Widget _step3() {
    final bradenPrev = calcBraden(Map.from(_braden));
    final capriniPrev = calcCaprini(Map.from(_caprini));
    final morsePrev = calcMorse(Map.from(_falls));
    final mustPrev = calcMust(Map.from(_must));
    final camPrev = calcCam(Map.from(_cam));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHead('Braden Scale', 'Pressure ulcer risk (NPIAP)',
          Icons.airline_seat_flat_rounded, hcTeal),
      for (final s in bradenSubscales)
        _Dropdown(
          label: s.label,
          value: _braden[s.key],
          options: bradenOptions[s.key]!.map((o) => o.$1).toList(),
          optionLabels: {for (final o in bradenOptions[s.key]!) o.$1: o.$2},
          onChanged: (v) => _set(_braden, s.key, v),
        ),
      _scoreBanner(
        bradenPrev['total'],
        'Braden total: ${bradenPrev['total'] ?? '—'}/23 — ${bradenPrev['risk_level']}',
        bradenPrev['total'] == null
            ? null
            : (bradenPrev['total'] <= 12
                ? hcRed
                : (bradenPrev['total'] <= 18 ? hcAmber : hcGreen)),
      ),
      _sectionHead('Caprini Score', 'VTE risk assessment',
          Icons.bloodtype_rounded, hcPurple, top: 14),
      _numField(_caprini, 'age', 'Age'),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final f in capriniFactors)
            FilterChip(
              label: Text('${f.label} (${f.points}pt)', style: const TextStyle(fontSize: 11)),
              selected: (_caprini['factors'] ?? {})[f.key] == true,
              onSelected: (sel) => setState(() {
                _caprini['factors'] ??= <String, bool>{};
                (_caprini['factors'] as Map)[f.key] = sel;
              }),
              selectedColor: hcPurple.withValues(alpha: 0.2),
            ),
        ],
      ),
      _scoreBanner(
        capriniPrev['points'],
        'Caprini: ${capriniPrev['points'] ?? 0} pts — ${capriniPrev['risk_level']}',
        capriniPrev['points'] == null
            ? null
            : (capriniPrev['points'] >= 5
                ? hcRed
                : (capriniPrev['points'] >= 3 ? hcAmber : hcGreen)),
      ),
      _sectionHead('Morse Fall Scale', 'Falls risk (CDC/STEADI)',
          Icons.elderly_rounded, hcAmber, top: 14),
      Wrap(children: [
        _checkChip(_falls, 'history_of_falls', 'Fall history'),
        _checkChip(_falls, 'secondary_dx', 'Secondary diagnosis'),
        _checkChip(_falls, 'iv_lock', 'IV / heparin lock'),
      ]),
      _Dropdown(
        label: 'Ambulatory aid',
        value: _falls['ambulatory_aid'] ?? 'none',
        options: morseAmbulatoryAid.map((a) => a.$1).toList(),
        optionLabels: {for (final a in morseAmbulatoryAid) a.$1: a.$2},
        onChanged: (v) => _set(_falls, 'ambulatory_aid', v),
      ),
      Row(children: [
        Expanded(
          child: _Dropdown(
            label: 'Gait',
            value: _falls['gait'] ?? 'normal',
            options: morseGait.map((g) => g.$1).toList(),
            optionLabels: {for (final g in morseGait) g.$1: g.$2},
            onChanged: (v) => _set(_falls, 'gait', v),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Dropdown(
            label: 'Mental status',
            value: _falls['mental_status'] ?? 'oriented',
            options: morseMental.map((m) => m.$1).toList(),
            optionLabels: {for (final m in morseMental) m.$1: m.$2},
            onChanged: (v) => _set(_falls, 'mental_status', v),
          ),
        ),
      ]),
      _scoreBanner(
        morsePrev['score'],
        'Morse: ${morsePrev['score'] ?? 0}/125 — ${morsePrev['risk_level']}',
        morsePrev['score'] == null
            ? null
            : (morsePrev['score'] >= 45 ? hcRed : (morsePrev['score'] >= 25 ? hcAmber : hcGreen)),
      ),
      _sectionHead('MUST', 'Malnutrition risk (BAPEN)',
          Icons.restaurant_rounded, hcRed, top: 14),
      Row(children: [
        Expanded(child: _numField(_must, 'height_cm', 'Height (cm)')),
        const SizedBox(width: 8),
        Expanded(child: _numField(_must, 'weight_kg', 'Weight (kg)', decimal: true)),
      ]),
      Row(children: [
        Expanded(child: _numField(_must, 'weight_loss_percent', 'Weight loss %', decimal: true)),
        const SizedBox(width: 8),
        Expanded(child: _checkChip(_must, 'acute_no_nutrition', 'Acute illness / no intake >5d')),
      ]),
      _scoreBanner(
        mustPrev['total_score'],
        'MUST: ${mustPrev['total_score'] ?? '—'}/6 — ${mustPrev['risk_level']}'
            '${mustPrev['bmi'] != null ? '  (BMI ${mustPrev['bmi']})' : ''}',
        mustPrev['total_score'] == null
            ? null
            : (mustPrev['total_score'] >= 2
                ? hcRed
                : (mustPrev['total_score'] == 1 ? hcAmber : hcGreen)),
      ),
      _sectionHead('CAM — Delirium Screen', 'Confusion Assessment Method',
          Icons.psychology_rounded, hcPurple, top: 14),
      Wrap(spacing: 4, children: [
        _checkChip(_cam, 'acute_onset', 'Acute onset'),
        _checkChip(_cam, 'fluctuating', 'Fluctuating course'),
        _checkChip(_cam, 'inattention', 'Inattention'),
        _checkChip(_cam, 'disorganized_thinking', 'Disorganised thinking'),
        _checkChip(_cam, 'altered_consciousness', 'Altered consciousness'),
      ]),
      if (camPrev['cam_positive'] == true)
        _scoreBanner(1, 'CAM Positive — Delirium detected. Physician review required.', hcRed),
    ]);
  }

  // Step 4 — Device & Care Bundles
  Widget _step4() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHead('Device & Care Bundles',
          'Evidence-based bundles per CDC/IHI/NPIAP guidelines',
          Icons.medical_services_rounded, hcTeal),
      if (_ini['has_catheter'] == true) ...[
        _bundleHeader('Catheter Bundle (CAUTI Prevention) — CDC', Icons.water_drop_rounded, hcBlue),
        _Dropdown(
          label: 'Type',
          value: _catheter['type'] ?? 'Foley',
          options: catheterTypes,
          onChanged: (v) => _set(_catheter, 'type', v),
        ),
        Row(children: [
          Expanded(child: _dateField(_catheter, 'insert_date', 'Insertion date')),
          const SizedBox(width: 8),
          Expanded(child: _dateField(_catheter, 'next_review_date', 'Next review')),
        ]),
        _txtField(_catheter, 'indication', 'Indication (required — CDC: restrict use)'),
        Wrap(spacing: 4, children: [
          _checkChip(_catheter, 'closed_system_maintained', 'Closed system maintained'),
          _checkChip(_catheter, 'bag_below_bladder', 'Bag below bladder'),
          _checkChip(_catheter, 'needs_review', 'May no longer be needed'),
          _checkChip(_catheter, 'daily_care_performed', 'Daily care performed'),
          _checkChip(_catheter, 'bag_emptied', 'Bag emptied this shift'),
        ]),
      ],
      if (_ini['has_central_line'] == true) ...[
        _bundleHeader('Central Line Bundle (CLABSI Prevention) — CDC', Icons.colorize_rounded, hcPurple),
        _Dropdown(
          label: 'Type',
          value: _cl['type'] ?? 'PICC',
          options: lineTypes,
          onChanged: (v) => _set(_cl, 'type', v),
        ),
        Row(children: [
          Expanded(child: _dateField(_cl, 'insert_date', 'Insertion date')),
          const SizedBox(width: 8),
          Expanded(child: _txtField(_cl, 'insert_site', 'Insertion site')),
        ]),
        Wrap(spacing: 4, children: [
          _checkChip(_cl, 'maximal_barrier', 'Maximal barrier used'),
          _checkChip(_cl, 'hub_scrub', 'Hub scrub protocol'),
          _checkChip(_cl, 'needs_removal', 'May no longer be needed'),
        ]),
      ],
      if (_ini['has_ventilator'] == true) ...[
        _bundleHeader('Ventilator Bundle (VAP Prevention) — IHI', Icons.air_rounded, hcRed),
        Wrap(spacing: 4, children: [
          _checkChip(_vent, 'head_of_bed_elevated', 'Head of bed ≥30°'),
          _checkChip(_vent, 'daily_sbt', 'Daily SBT'),
          _checkChip(_vent, 'sedation_vacation', 'Sedation vacation'),
          _checkChip(_vent, 'oral_care', 'Oral care performed'),
        ]),
        _txtField(_vent, 'vent_settings', 'Ventilator settings'),
      ],
      if (_ini['has_wound'] == true || _h2t['any_wounds'] == true) ...[
        _bundleHeader('Wound / Pressure Injury Bundle — NPIAP', Icons.healing_rounded, hcAmber),
        _numField(_wound, 'turn_schedule_hours', 'Turn schedule (hours)'),
        Wrap(spacing: 4, children: [
          _checkChip(_wound, 'special_mattress', 'Special mattress'),
          _checkChip(_wound, 'barrier_cream', 'Barrier cream'),
        ]),
      ],
      if (_ini['has_catheter'] != true &&
          _ini['has_central_line'] != true &&
          _ini['has_ventilator'] != true &&
          _ini['has_wound'] != true &&
          _h2t['any_wounds'] != true)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              'No devices or wounds flagged in the initial survey.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ),
    ]);
  }

  // Step 5 — Disease-Specific Bundles
  Widget _step5() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHead('Diabetes Bundle', 'Foot checks, glucose monitoring',
          Icons.water_drop_rounded, hcBlue),
      Wrap(spacing: 4, children: [
        _checkChip(_diabetes, 'foot_ulcer', 'Foot ulcer detected'),
        _checkChip(_diabetes, 'neuropathy', 'Neuropathy'),
        _checkChip(_diabetes, 'insulin_pump', 'Insulin pump'),
      ]),
      Row(children: [
        Expanded(child: _numField(_diabetes, 'latest_bg', 'Latest blood glucose (mg/dL)')),
        const SizedBox(width: 8),
        Expanded(child: _numField(_diabetes, 'latest_bg_mmol', 'Latest BG (mmol/L)', decimal: true)),
      ]),
      _dateField(_diabetes, 'last_foot_check', 'Last foot inspection date'),
      if (_diabetes['foot_ulcer'] == true)
        _scoreBanner(1,
            'Foot ulcer present — Initiate wound care, offload pressure, optimise blood glucose, refer to podiatry.',
            hcAmber),
      _sectionHead('Heart Failure Bundle', 'Volume status assessment, daily monitoring',
          Icons.favorite_rounded, hcRed, top: 14),
      _numField(_hf, 'daily_weight', 'Daily weight (kg)', decimal: true),
      _Dropdown(
        label: 'Edema level',
        value: _hf['edema'] ?? 'None',
        options: edemaLevels,
        onChanged: (v) => _set(_hf, 'edema', v),
      ),
      Wrap(spacing: 4, children: [
        _checkChip(_hf, 'sob_at_rest', 'SOB at rest'),
        _checkChip(_hf, 'sob_on_exertion', 'SOB on exertion'),
        _checkChip(_hf, 'orthopnea', 'Orthopnea'),
        _checkChip(_hf, 'jvd', 'JVD'),
        _checkChip(_hf, 'lung_crackles', 'Lung crackles'),
      ]),
      if (_hf['sob_at_rest'] == true || _hf['orthopnea'] == true)
        _scoreBanner(
            1,
            'Heart failure decompensation signs — Assess volume status, check daily weight trend, notify physician.',
            hcAmber),
    ]);
  }

  // Step 6 — Review & Submit
  Widget _step6() {
    final braden = calcBraden(Map.from(_braden));
    final caprini = calcCaprini(Map.from(_caprini));
    final morse = calcMorse(Map.from(_falls));
    final must = calcMust(Map.from(_must));
    final cam = calcCam(Map.from(_cam));
    final painScore = _num(_pain, 'score');
    final risk = aggregateRisk(braden['total'], caprini['points'], morse['score'],
        must['total_score'], cam['cam_positive'] == true, painScore);
    final patientName = _patients
        .firstWhere((p) => p['id'] == _form['patient'], orElse: () => {})['patient_name'];
    final alerts = generateAlerts({
      'braden_total': braden['total'],
      'caprini_points': caprini['points'],
      'morse_score': morse['score'],
      'must_score': must['total_score'],
      'cam_positive': cam['cam_positive'],
      'pain_score': painScore,
      'braden': braden,
      'vte_caprini': caprini,
      'falls': morse,
      'must': must,
      'catheter_bundle': {
        'present': _ini['has_catheter'] == true,
        'needs_review': _catheter['needs_review'] == true,
      },
      'central_line_bundle': {
        'present': _ini['has_central_line'] == true,
        'needs_removal': _cl['needs_removal'] == true,
      },
      'disease_bundles': {'diabetes': _diabetes, 'heart_failure': _hf},
    });
    final scores = [
      ('Braden', braden['total'], '/23'),
      ('Caprini', caprini['points'], 'pts'),
      ('Morse', morse['score'], '/125'),
      ('MUST', must['total_score'], '/6'),
      ('CAM', cam['cam_positive'] == true ? 'Pos' : 'Neg', ''),
      ('Pain', painScore, '/10'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHead('Review & Submit', 'Verify all data before signing',
          Icons.check_circle_rounded, hcGreen),
      Card(
        color: hcTeal.withValues(alpha: 0.06),
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('PATIENT',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: hcTeal)),
            Text(patientName?.toString() ?? '—',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text('${hcLabel(_form['session_type']?.toString())} · ${(_form['arrival'] ?? {})['arrival_mode'] ?? '—'}',
                style: const TextStyle(fontSize: 12)),
          ]),
        ),
      ),
      Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: (riskMeta[risk]?.hex).toString().isEmpty
              ? hcSlate
              : _hex((riskMeta[risk]?.hex)!).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(Icons.shield_rounded, color: _hex(riskMeta[risk]?.hex ?? '#64748b')),
          const SizedBox(width: 8),
          Text('Computed Risk Level',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _hex(riskMeta[risk]?.hex ?? '#64748b'))),
          const Spacer(),
          Text((riskMeta[risk]?.label ?? risk).toUpperCase(),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _hex(riskMeta[risk]?.hex ?? '#64748b'))),
        ]),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in scores)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${s.$1} ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text('${s.$2 ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                Text(s.$3, style: const TextStyle(fontSize: 11)),
              ]),
            ),
        ],
      ),
      if (alerts.isNotEmpty) ...[
        const SizedBox(height: 12),
        for (final a in alerts)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (a.severity == 'critical' || a.severity == 'high'
                  ? hcRed
                  : hcAmber).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: (a.severity == 'critical' || a.severity == 'high'
                  ? hcRed
                  : hcAmber).withValues(alpha: 0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(a.severity == 'critical' ? Icons.dangerous_rounded : Icons.warning_amber_rounded,
                    size: 16, color: a.severity == 'critical' ? hcRed : hcAmber),
                const SizedBox(width: 6),
                Text(a.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
              Text(a.detail, style: const TextStyle(fontSize: 12)),
              if (a.recommendation != null)
                Text('℞ ${a.recommendation}',
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
            ]),
          ),
      ],
      const SizedBox(height: 8),
      Row(children: [
        const Icon(Icons.key_rounded, size: 18, color: hcTeal),
        const SizedBox(width: 6),
        const Text('Staff verification required to sign this assessment',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 8),
      TextField(
        controller: _pinCtrl,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 12,
        decoration: const InputDecoration(
          labelText: 'Your staff PIN',
          prefixIcon: Icon(Icons.key_rounded),
          counterText: '',
        ),
      ),
      _textarea(_form, 'notes', 'Additional clinical notes (optional)'),
    ]);
  }

  // ── Navigation ──
  Widget _nav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(children: [
        if (_step > 1)
          TextButton.icon(
            onPressed: () => setState(() => _step--),
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('Previous'),
          ),
        const Spacer(),
        if (_step < _maxStep)
          FilledButton.icon(
            onPressed: () => setState(() => _step++),
            style: FilledButton.styleFrom(backgroundColor: hcTeal),
            icon: const Icon(Icons.chevron_right_rounded, size: 18),
            label: const Text('Next'),
          )
        else
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: hcGreen),
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(_saving ? 'Saving…' : 'Save Assessment'),
          ),
      ]),
    );
  }

  // ── Reusable field helpers ──
  Widget _sectionHead(String title, String subtitle, IconData icon, Color color,
      {double top = 0}) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 8),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
      ]),
    );
  }

  Widget _bundleHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
        ),
      ]),
    );
  }

  Widget _scoreBanner(num? show, String text, Color? color) {
    if (show == null) return const SizedBox();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: (color ?? hcSlate).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: (color ?? hcSlate).withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
    );
  }

  Widget _numField(Map m, String key, String label, {bool decimal = false, num? max}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: TextEditingController(text: m[key]?.toString()),
        keyboardType:
            decimal ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number,
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: (v) => m[key] = decimal ? double.tryParse(v) : int.tryParse(v),
      ),
    );
  }

  Widget _txtField(Map m, String key, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: TextEditingController(text: m[key]?.toString() ?? ''),
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: (v) => m[key] = v,
      ),
    );
  }

  Widget _textarea(Map m, String key, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: TextEditingController(text: m[key]?.toString() ?? ''),
        maxLines: 2,
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: (v) => m[key] = v,
      ),
    );
  }

  Widget _dateField(Map m, String key, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: TextEditingController(text: m[key]?.toString() ?? ''),
        readOnly: true,
        decoration: InputDecoration(labelText: label, isDense: true, suffixIcon: const Icon(Icons.event_rounded, size: 18)),
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (d != null) {
            final s = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
            setState(() => m[key] = s);
          }
        },
      ),
    );
  }

  Widget _checkChip(Map m, String key, String label) {
    final selected = m[key] == true;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (v) => setState(() => m[key] = v),
      selectedColor: hcTeal.withValues(alpha: 0.2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    );
  }

  num? _num(Map m, String k) {
    final v = m[k];
    if (v == null) return null;
    return num.tryParse(v.toString());
  }

  Color _hex(String hex) {
    final c = hex.replaceAll('#', '');
    return Color(int.parse('FF$c', radix: 16));
  }
}

// ── Dropdown helper ──
class _Dropdown extends StatelessWidget {
  final String label;
  final dynamic value;
  final List<dynamic> options;
  final Map<dynamic, String>? optionLabels;
  final ValueChanged<dynamic> onChanged;
  const _Dropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.optionLabels,
  });

  String _labelOf(dynamic v) =>
      (optionLabels != null && optionLabels!.containsKey(v)) ? optionLabels![v]! : '$v';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<dynamic>(
        initialValue: value,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: options
            .map((o) => DropdownMenuItem<dynamic>(
                  value: o,
                  child: Text(_labelOf(o), overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
