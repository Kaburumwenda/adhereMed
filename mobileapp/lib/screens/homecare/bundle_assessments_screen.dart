import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import 'hc_common.dart';

// ═════════════════════════════════════════════════════════════════
//  Device-bundle assessment engine — data-driven tri-state forms for
//  Enteral Feeding, Urinary Catheter (CAUTI), Artificial Airway
//  (Tracheostomy + VAP) and CVAD (CLABSI) bundles.
//  Field names mirror backend/homecare/models.py exactly; compliance
//  percentages are computed server-side on save.
// ═════════════════════════════════════════════════════════════════

class BundleSection {
  final String title;
  final IconData icon;
  final List<(String, String)> items; // (fieldKey, label)
  final bool Function(Map<String, dynamic> header)? cond;
  const BundleSection(this.title, this.icon, this.items, {this.cond});
}

class BundleHeaderField {
  final String key;
  final String label;
  final List<(String, String)>? options; // null → free text
  final bool isSwitch;
  const BundleHeaderField(this.key, this.label,
      {this.options, this.isSwitch = false});
}

class BundleFindingGroup {
  final String title;
  final IconData icon;
  final Color color;
  final List<(String, String)> items; // bool fields
  const BundleFindingGroup(this.title, this.icon, this.color, this.items);
}

class BundleScale {
  final String key;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final String endpoint;
  final List<BundleHeaderField> header;
  final List<BundleSection> sections;
  final List<BundleFindingGroup> findings;
  const BundleScale({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.endpoint,
    this.header = const [],
    this.sections = const [],
    this.findings = const [],
  });
}

// ─────────────────────── ENTERAL FEEDING ───────────────────────
const _enteral = BundleScale(
  key: 'enteral_feeding',
  label: 'Enteral Feeding Bundle',
  description: 'NGT / PEG / PEJ maintenance bundle',
  icon: Icons.dining_rounded,
  color: hcAmber,
  endpoint: '/homecare/enteral-feeding-assessments/',
  header: [
    BundleHeaderField('device_type', 'Device type', options: [
      ('ngt', 'Nasogastric (NGT)'),
      ('ogt', 'Orogastric (OGT)'),
      ('peg', 'PEG'),
      ('pej', 'PEJ'),
      ('gj', 'GJ tube'),
      ('j_tube', 'J-tube'),
      ('nj', 'Nasojejunal (NJ)'),
      ('other', 'Other'),
    ]),
    BundleHeaderField('tube_size', 'Tube size (e.g. Fr 16)'),
    BundleHeaderField('insertion_site', 'Insertion site'),
  ],
  sections: [
    BundleSection('Universal maintenance', Icons.checklist_rounded, [
      ('bundle_hand_hygiene', 'Hand hygiene performed'),
      ('bundle_ppe', 'PPE worn appropriately'),
      ('bundle_device_necessity', 'Device necessity reviewed'),
      ('bundle_device_securement', 'Device securement intact'),
      ('bundle_tube_patency', 'Tube patency confirmed'),
      ('bundle_water_flush_protocol', 'Water flush protocol followed'),
      ('bundle_feeding_equipment_check', 'Feeding equipment checked'),
      ('bundle_patient_positioning', 'Patient positioned ≥30°'),
      ('bundle_oral_care', 'Oral care provided'),
      ('bundle_documentation_complete', 'Documentation complete'),
    ]),
    BundleSection('Nasal / oral tube care', Icons.face_rounded, [
      ('bundle_position_verification', 'Tube position verified'),
      ('bundle_nare_care', 'Nare care performed'),
      ('bundle_skin_protection', 'Skin protection in place'),
      ('bundle_nasal_pressure_prevention', 'Nasal pressure-injury prevention'),
    ], cond: _isNasal),
    BundleSection('Stoma tube care (PEG/PEJ/GJ/J)', Icons.circle_outlined, [
      ('bundle_stoma_care', 'Stoma care performed'),
      ('bundle_external_fixation_check', 'External fixation checked'),
      ('bundle_external_length_verify', 'External length verified'),
      ('bundle_tube_rotation', 'Tube rotated (per policy)'),
      ('bundle_dressing_management', 'Dressing managed'),
      ('bundle_buried_bumper', 'Buried bumper check done'),
      ('bundle_peristomal_care', 'Peristomal skin care done'),
    ], cond: _isStomal),
    BundleSection('Safety & education', Icons.school_rounded, [
      ('bundle_med_safety_check', 'Medication safety check'),
      ('bundle_patient_education', 'Patient / caregiver education'),
    ]),
  ],
);

bool _isNasal(Map<String, dynamic> h) =>
    ['ngt', 'ogt', 'nj'].contains(h['device_type']);
bool _isStomal(Map<String, dynamic> h) =>
    ['peg', 'pej', 'gj', 'j_tube'].contains(h['device_type']);

// ─────────────────────── URINARY CATHETER ───────────────────────
const _urinary = BundleScale(
  key: 'urinary_catheter',
  label: 'Urinary Catheter Bundle',
  description: 'CAUTI-prevention maintenance bundle',
  icon: Icons.water_drop_rounded,
  color: hcBlue,
  endpoint: '/homecare/urinary-catheter-assessments/',
  header: [
    BundleHeaderField('catheter_type', 'Catheter type', options: [
      ('foley', 'Indwelling (Foley)'),
      ('three_way', 'Three-way irrigation'),
      ('suprapubic', 'Suprapubic'),
      ('intermittent', 'Intermittent'),
      ('external', 'External device'),
      ('other', 'Other'),
    ]),
    BundleHeaderField('current_indication', 'Current indication'),
  ],
  sections: [
    BundleSection('Necessity & hygiene', Icons.verified_rounded, [
      ('bundle_necessity_reviewed', 'Necessity reviewed today'),
      ('bundle_necessity_indicated', 'Catheter still indicated'),
      ('bundle_hand_hygiene_before', 'Hand hygiene before'),
      ('bundle_hand_hygiene_after', 'Hand hygiene after'),
      ('bundle_ppe_gloves', 'Gloves worn'),
    ]),
    BundleSection('Meatal / periurethral care', Icons.clean_hands_rounded, [
      ('bundle_meatal_hygiene_done', 'Meatal hygiene performed'),
      ('bundle_meatal_cleansed', 'Cleansed soap & water'),
      ('bundle_meatal_no_antiseptic', 'No antiseptics used'),
      ('bundle_meatal_dried', 'Area dried'),
      ('bundle_meatal_skin_intact', 'Skin intact'),
    ]),
    BundleSection('Securement', Icons.push_pin_rounded, [
      ('bundle_securement_intact', 'Securement device intact'),
      ('bundle_securement_proper', 'Properly positioned'),
      ('bundle_securement_no_traction', 'No traction on catheter'),
      ('bundle_securement_comfort', 'Patient comfortable'),
    ]),
    BundleSection('Drainage system', Icons.linear_scale_rounded, [
      ('bundle_drain_closed', 'Closed system maintained'),
      ('bundle_drain_no_disconnect', 'No unnecessary disconnections'),
      ('bundle_drain_secure', 'Connections secure'),
      ('bundle_drain_no_leaks', 'No leaks'),
      ('bundle_bag_below_bladder', 'Bag below bladder'),
      ('bundle_bag_not_floor', 'Bag not touching floor'),
      ('bundle_bag_tubing_unobstructed', 'Tubing unobstructed'),
      ('bundle_bag_no_loops', 'No dependent loops'),
      ('bundle_bag_flow_adequate', 'Urine flow adequate'),
    ]),
    BundleSection('Emptying & specimens', Icons.science_rounded, [
      ('bundle_empty_clean', 'Emptied with clean technique'),
      ('bundle_empty_port_clean', 'Drainage port cleaned'),
      ('bundle_empty_container', 'Separate clean container'),
      ('bundle_empty_output_doc', 'Output documented'),
      ('bundle_specimen_port', 'Specimen via sampling port'),
      ('bundle_specimen_aseptic', 'Aseptic specimen technique'),
      ('bundle_specimen_doc', 'Specimen documented'),
    ]),
    BundleSection('Patient education', Icons.school_rounded, [
      ('bundle_edu_fever', 'Report fever'),
      ('bundle_edu_chills', 'Report chills'),
      ('bundle_edu_pain', 'Report pain'),
      ('bundle_edu_leakage', 'Report leakage'),
      ('bundle_edu_low_output', 'Report low output'),
      ('bundle_edu_hematuria', 'Report blood in urine'),
      ('bundle_edu_foul_urine', 'Report foul urine'),
      ('bundle_edu_blockage', 'Report blockage'),
      ('bundle_edu_understanding', 'Understanding confirmed'),
    ]),
    BundleSection('Hydration & I/O', Icons.local_drink_rounded, [
      ('bundle_hydration_encouraged', 'Hydration encouraged'),
      ('bundle_hydration_restriction', 'Restrictions observed'),
      ('bundle_io_urine_recorded', 'Urine output recorded'),
      ('bundle_io_intake_recorded', 'Intake recorded'),
      ('bundle_io_balance_reviewed', 'Fluid balance reviewed'),
    ]),
  ],
  findings: [
    BundleFindingGroup(
        'Site findings', Icons.visibility_rounded, hcAmber, [
      ('site_redness', 'Redness'),
      ('site_swelling', 'Swelling'),
      ('site_pain', 'Pain'),
      ('site_bleeding', 'Bleeding'),
      ('site_discharge', 'Discharge'),
      ('site_meatal_irritation', 'Meatal irritation'),
      ('site_skin_breakdown', 'Skin breakdown'),
    ]),
    BundleFindingGroup(
        'Patient symptoms', Icons.sick_rounded, hcRed, [
      ('patient_fever', 'Fever'),
      ('patient_chills', 'Chills'),
      ('patient_dysuria', 'Dysuria'),
      ('patient_abdominal_pain', 'Abdominal pain'),
      ('patient_flank_pain', 'Flank pain'),
      ('patient_confusion', 'New confusion'),
      ('patient_rigors', 'Rigors'),
      ('patient_malaise', 'Malaise'),
    ]),
    BundleFindingGroup(
        'Complications', Icons.report_problem_rounded, hcRed, [
      ('complication_suspected_cauti', 'Suspected CAUTI'),
      ('complication_blockage', 'Blockage'),
      ('complication_leakage', 'Leakage'),
      ('complication_hematuria', 'Hematuria'),
      ('complication_spasms', 'Bladder spasms'),
      ('complication_dislodgement', 'Dislodgement'),
      ('complication_encrustation', 'Encrustation'),
      ('complication_trauma', 'Trauma'),
    ]),
  ],
);

// ─────────────────────── ARTIFICIAL AIRWAY ───────────────────────
const _airway = BundleScale(
  key: 'artificial_airway',
  label: 'Artificial Airway',
  description: 'Tracheostomy + VAP assessment',
  icon: Icons.air_rounded,
  color: Color(0xFF455A64),
  endpoint: '/homecare/artificial-airway-assessments/',
  header: [
    BundleHeaderField('airway_device', 'Airway device', options: [
      ('tracheostomy', 'Tracheostomy'),
      ('ett', 'Endotracheal tube'),
      ('laryngectomy', 'Laryngectomy'),
    ]),
    BundleHeaderField('mechanically_ventilated', 'Mechanically ventilated',
        isSwitch: true),
    BundleHeaderField('is_cuffed', 'Cuffed tube', isSwitch: true),
    BundleHeaderField('inner_cannula_present', 'Inner cannula present',
        isSwitch: true),
    BundleHeaderField('tube_size', 'Tube size'),
  ],
  sections: [
    BundleSection('Infection prevention', Icons.clean_hands_rounded, [
      ('t_hand_hygiene_before', 'Hand hygiene before'),
      ('t_gloves_worn', 'Gloves worn'),
      ('t_ppe_used', 'PPE used'),
      ('t_hand_hygiene_after', 'Hand hygiene after'),
    ], cond: _showTrach),
    BundleSection('Tube assessment', Icons.linear_scale_rounded, [
      ('t_tube_position_correct', 'Position correct'),
      ('t_tube_patent', 'Tube patent'),
      ('t_tube_intact', 'Tube intact'),
      ('t_tube_unobstructed', 'Unobstructed'),
      ('t_tube_secured', 'Secured'),
      ('t_tube_no_air_leak', 'No air leak'),
      ('t_tube_no_visible_damage', 'No visible damage'),
    ], cond: _showTrach),
    BundleSection('Stoma assessment', Icons.circle_outlined, [
      ('t_stoma_skin_clean', 'Skin clean'),
      ('t_stoma_skin_dry', 'Skin dry'),
      ('t_stoma_no_redness', 'No redness'),
      ('t_stoma_no_swelling', 'No swelling'),
      ('t_stoma_no_bleeding', 'No bleeding'),
      ('t_stoma_no_discharge', 'No discharge'),
      ('t_stoma_no_granulation', 'No granulation'),
      ('t_stoma_no_pressure_injury', 'No pressure injury'),
      ('t_stoma_pain_absent', 'Pain absent'),
    ], cond: _showTrach),
    BundleSection('Securement', Icons.push_pin_rounded, [
      ('t_secure_neck_ties_intact', 'Neck ties intact'),
      ('t_secure_correct_tightness', 'Correct tightness'),
      ('t_secure_finger_spacing', '1–2 finger spacing'),
      ('t_secure_no_pressure_injury', 'No pressure injury'),
    ], cond: _showTrach),
    BundleSection('Inner cannula', Icons.tune_rounded, [
      ('t_inner_clean', 'Inner cannula clean'),
      ('t_inner_patent', 'Inner cannula patent'),
      ('t_inner_changed_today', 'Changed / cleaned today'),
    ], cond: _showInner),
    BundleSection('Cuff', Icons.circle_rounded, [
      ('t_cuff_inflated', 'Cuff inflated'),
      ('t_cuff_pressure_measured', 'Pressure measured'),
      ('t_cuff_pressure_in_range', 'Pressure 20–30 cmH₂O'),
      ('t_cuff_air_leak_absent', 'No air leak'),
      ('t_cuff_pilot_balloon_intact', 'Pilot balloon intact'),
    ], cond: _showCuff),
    BundleSection('Humidification & suction', Icons.water_rounded, [
      ('t_humid_prescribed', 'Humidification prescribed'),
      ('t_humid_functioning', 'Humidification functioning'),
      ('t_suction_available', 'Suction available'),
      ('t_suction_pressure_checked', 'Suction pressure checked'),
      ('t_suction_catheter_available', 'Catheters available'),
      ('t_suction_correct_size', 'Correct catheter size'),
    ], cond: _showTrach),
    BundleSection('Emergency equipment (critical)', Icons.emergency_rounded, [
      ('t_emerg_same_size_tube', 'Same-size spare tube'),
      ('t_emerg_smaller_tube', 'Smaller spare tube'),
      ('t_emerg_obturator', 'Obturator'),
      ('t_emerg_bag_valve_mask', 'Bag-valve-mask'),
      ('t_emerg_oxygen', 'Oxygen available'),
      ('t_emerg_call_bell', 'Call bell in reach'),
    ], cond: _showTrach),
    BundleSection('Communication & docs', Icons.record_voice_over_rounded, [
      ('t_comm_method_assessed', 'Communication method assessed'),
      ('t_doc_bundle_complete', 'Documentation complete'),
      ('t_doc_education_completed', 'Education completed'),
    ], cond: _showTrach),
    // ── VAP (mechanically ventilated) ──
    BundleSection('VAP — Head of bed', Icons.bed_rounded, [
      ('v_hob_30_45_maintained', 'HOB 30–45° maintained'),
    ], cond: _showVap),
    BundleSection('VAP — Oral care', Icons.mood_rounded, [
      ('v_oral_care_completed', 'Oral care completed'),
      ('v_oral_teeth_cleaned', 'Teeth cleaned'),
      ('v_oral_chlorhexidine_used', 'Chlorhexidine used'),
      ('v_oral_secretions_removed', 'Secretions removed'),
    ], cond: _showVap),
    BundleSection('VAP — Airway & sedation', Icons.air_rounded, [
      ('v_airway_tube_secure', 'Tube secure'),
      ('v_airway_position_correct', 'Position correct'),
      ('v_airway_cuff_pressure_target', 'Cuff pressure at target'),
      ('v_sedation_daily_review', 'Daily sedation review'),
      ('v_sedation_interruption', 'Sedation interruption trialled'),
      ('v_weaning_readiness_assessed', 'Weaning readiness assessed'),
    ], cond: _showVap),
    BundleSection('VAP — Suction & circuit', Icons.sync_rounded, [
      ('v_suction_need_assessed', 'Suction need assessed'),
      ('v_suction_secretions_removed', 'Secretions removed'),
      ('v_circuit_intact', 'Circuit intact'),
      ('v_circuit_condensation_managed', 'Condensation managed'),
      ('v_asp_head_elevated', 'Head elevated for feeds'),
      ('v_doc_bundle_complete', 'VAP documentation complete'),
    ], cond: _showVap),
  ],
);

bool _showTrach(Map<String, dynamic> h) =>
    h['airway_device'] == 'tracheostomy' ||
    h['airway_device'] == 'laryngectomy';
bool _showInner(Map<String, dynamic> h) =>
    _showTrach(h) && h['inner_cannula_present'] == true;
bool _showCuff(Map<String, dynamic> h) =>
    _showTrach(h) && h['is_cuffed'] == true;
bool _showVap(Map<String, dynamic> h) =>
    h['mechanically_ventilated'] == true &&
    (h['airway_device'] == 'ett' || h['airway_device'] == 'tracheostomy');

// ─────────────────────── CVAD ───────────────────────
const _cvad = BundleScale(
  key: 'cvad',
  label: 'CVAD Care Bundle',
  description: 'Central line CLABSI-prevention bundle',
  icon: Icons.settings_input_component_rounded,
  color: Color(0xFFC62828),
  endpoint: '/homecare/cvad-assessments/',
  header: [
    BundleHeaderField('device_type', 'Device type', options: [
      ('cvc', 'CVC'),
      ('picc', 'PICC'),
      ('midline', 'Midline'),
      ('dialysis', 'Dialysis catheter'),
      ('tunneled', 'Tunneled line'),
      ('port', 'Implanted port'),
      ('other', 'Other'),
    ]),
    BundleHeaderField('insertion_site', 'Insertion site'),
  ],
  sections: [
    BundleSection('Necessity & hygiene', Icons.verified_rounded, [
      ('bundle_necessity_reviewed', 'Line necessity reviewed'),
      ('bundle_necessity_indicated', 'Line still indicated'),
      ('bundle_hand_hygiene_before', 'Hand hygiene before'),
      ('bundle_hand_hygiene_after', 'Hand hygiene after'),
      ('bundle_aseptic_technique', 'Aseptic technique'),
    ]),
    BundleSection('Site & dressing', Icons.healing_rounded, [
      ('bundle_site_assessed', 'Site assessed'),
      ('bundle_site_no_infection', 'No infection signs at site'),
      ('bundle_dressing_intact', 'Dressing intact'),
      ('bundle_dressing_clean_dry', 'Dressing clean & dry'),
      ('bundle_dressing_dated', 'Dressing dated'),
      ('bundle_securement_intact', 'Securement intact'),
    ]),
    BundleSection('Patency & lumens', Icons.linear_scale_rounded, [
      ('bundle_patency_flush', 'Flushes easily'),
      ('bundle_patency_blood_return', 'Blood return present'),
      ('bundle_patency_no_resistance', 'No resistance'),
      ('bundle_lumens_labeled', 'Lumens labeled'),
      ('bundle_aseptic_access', 'Aseptic access technique'),
      ('bundle_needleless_connector', 'Needleless connectors in place'),
    ]),
    BundleSection('Hub disinfection', Icons.sanitizer_rounded, [
      ('bundle_hub_scrubbed', 'Hub scrubbed'),
      ('bundle_hub_scrub_duration', 'Scrub 15 sec'),
      ('bundle_hub_dried', 'Hub air-dried'),
      ('bundle_caps_changed', 'Caps changed per policy'),
    ]),
    BundleSection('Surveillance & education', Icons.school_rounded, [
      ('bundle_no_systemic_infection', 'No systemic infection signs'),
      ('bundle_no_mechanical_complication', 'No mechanical complication'),
      ('bundle_patient_educated', 'Patient educated'),
      ('bundle_patient_understands', 'Understanding confirmed'),
      ('bundle_documented', 'Documented'),
      ('bundle_handover_complete', 'Handover complete'),
    ]),
  ],
  findings: [
    BundleFindingGroup('Site findings', Icons.visibility_rounded, hcAmber, [
      ('site_redness', 'Redness'),
      ('site_swelling', 'Swelling'),
      ('site_tenderness', 'Tenderness'),
      ('site_warmth', 'Warmth'),
      ('site_drainage', 'Drainage'),
      ('site_purulent_drainage', 'Purulent drainage'),
      ('site_bleeding', 'Bleeding'),
    ]),
    BundleFindingGroup('Systemic signs', Icons.sick_rounded, hcRed, [
      ('patient_fever', 'Fever'),
      ('patient_chills', 'Chills'),
      ('patient_rigors', 'Rigors'),
      ('patient_hypotension', 'Hypotension'),
      ('patient_malaise', 'Malaise'),
    ]),
    BundleFindingGroup(
        'Mechanical complications', Icons.report_problem_rounded, hcRed, [
      ('complication_migration', 'Migration'),
      ('complication_leakage', 'Leakage'),
      ('complication_occlusion', 'Occlusion'),
      ('complication_damage', 'Damage'),
      ('complication_dislodgement', 'Dislodgement'),
      ('complication_thrombosis', 'Thrombosis'),
    ]),
  ],
);

const kBundleScales = [_enteral, _urinary, _airway, _cvad];

final _bundlePatientsProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/patients/',
      params: {'is_active': 'true', 'page_size': 200});
});

/// Opens the device-bundle record sheet.
void showBundleAssessmentSheet(BuildContext context, BundleScale scale,
    {int? patientId}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => BundleAssessmentSheet(scale: scale, patientId: patientId),
  );
}

class BundleAssessmentSheet extends ConsumerStatefulWidget {
  final BundleScale scale;
  final int? patientId;
  const BundleAssessmentSheet(
      {super.key, required this.scale, this.patientId});

  @override
  ConsumerState<BundleAssessmentSheet> createState() =>
      _BundleAssessmentSheetState();
}

class _BundleAssessmentSheetState
    extends ConsumerState<BundleAssessmentSheet> {
  late int? _patientId = widget.patientId;
  final _notes = TextEditingController();
  final Map<String, dynamic> _header = {};
  final Map<String, String> _triState = {}; // fieldKey → yes/no/na
  final Map<String, bool> _findings = {};
  final Map<String, TextEditingController> _textCtrls = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final h in widget.scale.header) {
      if (h.isSwitch) {
        _header[h.key] = h.key == 'mechanically_ventilated' ? false : true;
      } else if (h.options != null) {
        _header[h.key] = h.options!.first.$1;
      } else {
        _textCtrls[h.key] = TextEditingController();
      }
    }
  }

  List<BundleSection> get _visibleSections => widget.scale.sections
      .where((s) => s.cond == null || s.cond!(_header))
      .toList();

  int get _answered => _triState.values.where((v) => v.isNotEmpty).length;
  int get _yes => _triState.values.where((v) => v == 'yes').length;
  int get _applicable =>
      _triState.values.where((v) => v == 'yes' || v == 'no').length;
  int get _livePct =>
      _applicable > 0 ? (_yes / _applicable * 100).round() : 100;

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
      final sessionRes =
          await dio.post('/homecare/assessment-sessions/', data: {
        'patient': _patientId,
        'session_type': 'reassessment',
        'assessed_at': nowIso,
      });
      final payload = <String, dynamic>{
        'episode': sessionRes.data['id'],
        'patient': _patientId,
        'assessed_at': nowIso,
        'notes': _notes.text.trim(),
        ..._header,
        for (final e in _textCtrls.entries)
          if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
        for (final e in _triState.entries)
          if (e.value.isNotEmpty) e.key: e.value,
        ..._findings,
      };
      await dio.post(widget.scale.endpoint, data: payload);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.scale.label} recorded.')));
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

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(_bundlePatientsProvider);
    final scale = widget.scale;
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      builder: (_, controller) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: scale.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(scale.icon, color: scale.color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(scale.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15.5)),
                    Text(scale.description,
                        style: TextStyle(
                            fontSize: 11.5, color: cs.onSurfaceVariant)),
                  ]),
            ),
            // Live compliance chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: (_livePct >= 80 ? hcGreen : hcAmber)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999)),
              child: Text('$_livePct% · $_answered answered',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _livePct >= 80 ? hcGreen : hcAmber)),
            ),
          ]),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(controller: controller, children: [
              if (widget.patientId == null)
                patients.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Could not load patients'),
                  data: (list) => DropdownButtonFormField<int>(
                    initialValue: _patientId,
                    decoration:
                        const InputDecoration(labelText: 'Patient *'),
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
              // Header fields
              for (final h in scale.header)
                if (h.isSwitch)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: _header[h.key] == true,
                    title: Text(h.label,
                        style: const TextStyle(fontSize: 13.5)),
                    onChanged: (v) => setState(() => _header[h.key] = v),
                  )
                else if (h.options != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DropdownButtonFormField<String>(
                      initialValue: _header[h.key] as String?,
                      decoration: InputDecoration(labelText: h.label),
                      items: h.options!
                          .map((o) => DropdownMenuItem(
                              value: o.$1, child: Text(o.$2)))
                          .toList(),
                      onChanged: (v) => setState(() =>
                          _header[h.key] = v ?? h.options!.first.$1),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: _textCtrls[h.key],
                      decoration: InputDecoration(labelText: h.label),
                    ),
                  ),
              // Tri-state sections
              for (final section in _visibleSections) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
                  child: Row(children: [
                    Icon(section.icon, size: 16, color: scale.color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(section.title.toUpperCase(),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: scale.color)),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                      onPressed: () => setState(() {
                        for (final it in section.items) {
                          _triState[it.$1] = 'yes';
                        }
                      }),
                      child: const Text('All yes',
                          style: TextStyle(fontSize: 11)),
                    ),
                  ]),
                ),
                for (final item in section.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Expanded(
                          child: Text(item.$2,
                              style: const TextStyle(fontSize: 12.5))),
                      _TriState(
                        value: _triState[item.$1] ?? '',
                        onChanged: (v) =>
                            setState(() => _triState[item.$1] = v),
                      ),
                    ]),
                  ),
              ],
              // Finding groups (bool chips)
              for (final g in scale.findings) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
                  child: Row(children: [
                    Icon(g.icon, size: 16, color: g.color),
                    const SizedBox(width: 6),
                    Text(g.title.toUpperCase(),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: g.color)),
                  ]),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: g.items
                      .map((f) => FilterChip(
                            selected: _findings[f.$1] == true,
                            label: Text(f.$2,
                                style: const TextStyle(fontSize: 12)),
                            selectedColor: g.color.withValues(alpha: 0.18),
                            checkmarkColor: g.color,
                            onSelected: (v) =>
                                setState(() => _findings[f.$1] = v),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                      backgroundColor: scale.color,
                      padding: const EdgeInsets.symmetric(vertical: 13)),
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
              const SizedBox(height: 8),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _TriState extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _TriState({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(String v, String label, Color color) {
      final selected = value == v;
      return GestureDetector(
        onTap: () => onChanged(selected ? '' : v),
        child: Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.16)
                : Colors.transparent,
            border: Border.all(
                color: selected
                    ? color
                    : Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? color
                      : Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      chip('yes', 'Yes', hcGreen),
      chip('no', 'No', hcRed),
      chip('na', 'N/A', hcSlate),
    ]);
  }
}
