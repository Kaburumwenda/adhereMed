import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import 'hc_common.dart';

// ── Providers ──
final _plansProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/treatment-plans/', params: {'page_size': 200});
});

final _patientsProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/patients/', params: {'page_size': 200});
});

// ── Constants ──
const _tpPurple = Color(0xFF7C3AED);
const _tpPurpleDark = Color(0xFF6D28D9);

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

const _statusOptions = [
  ('active', 'Active'),
  ('paused', 'Paused'),
  ('completed', 'Completed'),
  ('cancelled', 'Cancelled'),
];

const _statusBoard = [
  ('active', 'Active', hcGreen, Icons.play_circle_rounded),
  ('paused', 'Paused', hcAmber, Icons.pause_circle_rounded),
  ('completed', 'Completed', hcBlue, Icons.check_circle_rounded),
  ('cancelled', 'Cancelled', hcSlate, Icons.cancel_rounded),
];

// ── Helpers ──
Color _statusColor(String? s) => switch (s) {
      'active' => hcGreen,
      'paused' => hcAmber,
      'completed' => hcBlue,
      'cancelled' => hcSlate,
      _ => hcSlate,
    };

String _statusLabel(String? s) => switch (s) {
      'active' => 'Active',
      'paused' => 'Paused',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => hcLabel(s),
    };

IconData _statusIcon(String? s) => switch (s) {
      'active' => Icons.play_circle_rounded,
      'paused' => Icons.pause_circle_rounded,
      'completed' => Icons.check_circle_rounded,
      'cancelled' => Icons.cancel_rounded,
      _ => Icons.circle_outlined,
    };

List<(String, String, IconData, Color)> _transitionsFor(String? status) {
  switch (status) {
    case 'active':
      return const [
        ('paused', 'Pause', Icons.pause_rounded, hcAmber),
        ('completed', 'Complete', Icons.check_rounded, hcBlue),
        ('cancelled', 'Cancel', Icons.cancel_rounded, hcSlate),
      ];
    case 'paused':
      return const [
        ('active', 'Resume', Icons.play_arrow_rounded, hcGreen),
        ('cancelled', 'Cancel', Icons.cancel_rounded, hcSlate),
      ];
    case 'completed':
      return const [
        ('active', 'Reactivate', Icons.restart_alt_rounded, hcGreen),
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

String _fmtDate(dynamic d) {
  if (d == null) return '—';
  final dt = DateTime.tryParse(d.toString());
  if (dt == null) return '—';
  return hcDate(dt.toIso8601String());
}

String _fmtDateTime(dynamic d) {
  if (d == null) return '—';
  final dt = DateTime.tryParse(d.toString());
  if (dt == null) return '—';
  return hcDateTime(dt.toIso8601String());
}

String _durationLabel(Map p) {
  final startStr = p['start_date'];
  if (startStr == null) return '—';
  final start = DateTime.tryParse(startStr.toString());
  if (start == null) return '—';
  final endStr = p['end_date'];
  final end = endStr != null ? DateTime.tryParse(endStr.toString()) : DateTime.now();
  if (end == null) return '—';
  final days = end.difference(start).inDays;
  if (days < 0) return '—';
  if (days < 31) return '$days day(s)';
  if (days < 365) return '${(days / 7).round()} week(s)';
  return '${(days / 365).toStringAsFixed(1)} year(s)';
}

int _planProgress(Map p) {
  if (p['status'] == 'completed' || p['status'] == 'cancelled') return 100;
  final startStr = p['start_date'];
  final endStr = p['end_date'];
  if (startStr == null || endStr == null) return 25;
  final start = DateTime.tryParse(startStr.toString());
  final end = DateTime.tryParse(endStr.toString());
  if (start == null || end == null) return 25;
  if (end.millisecondsSinceEpoch <= start.millisecondsSinceEpoch) return 100;
  final now = DateTime.now().millisecondsSinceEpoch;
  final s = start.millisecondsSinceEpoch;
  final e = end.millisecondsSinceEpoch;
  if (now >= e) return 100;
  if (now <= s) return 0;
  return ((now - s) / (e - s) * 100).round().clamp(0, 100);
}

List<String> _parseGoals(dynamic goals) {
  if (goals is List) {
    return goals.map((g) {
      if (g is String) return g;
      if (g is Map) return g['text']?.toString() ?? g['goal']?.toString() ?? '';
      return '';
    }).where((s) => s.isNotEmpty).toList();
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

String _patientName(Map p) {
  if (p['user'] is Map) {
    final u = p['user'] as Map;
    final name = u['full_name']?.toString() ?? 'Patient';
    final mrn = p['medical_record_number']?.toString();
    return mrn != null && mrn.isNotEmpty ? '$name · $mrn' : name;
  }
  return 'Patient #${p['id']}';
}

List<String> _smartGoalOptions(String diagnosis) {
  final dx = diagnosis.toLowerCase().trim();
  final matched = <String>[];
  final generic = [
    '100% medication adherence verified weekly',
    'No hospital readmission within 30 days of discharge',
    'Independent in activities of daily living (ADLs) within 8 weeks',
    'Patient verbalises understanding of condition within 2 weeks',
    'Caregiver demonstrates safe care technique within 1 week',
    'Pain score ≤3/10 within 2 weeks',
    'Achieve restful sleep ≥6 hours/night within 4 weeks',
  ];
  if (dx.isNotEmpty) {
    final diagMap = <String, List<String>>{
      'diabetes': [
        'Achieve HbA1c <7.0% within 3 months',
        'Maintain fasting blood glucose 4.4–7.0 mmol/L within 12 weeks',
        'Demonstrate correct insulin self-administration within 2 weeks',
        'Daily blood glucose monitoring logged for 90 days',
        'No hypoglycaemic episodes (<3.9 mmol/L) over 8 weeks',
        'Adopt diabetic diet plan within 4 weeks',
      ],
      'hypertension': [
        'Reduce blood pressure to <130/80 mmHg within 8 weeks',
        'Daily home BP readings logged for 12 weeks',
        'Reduce daily salt intake to <5 g within 4 weeks',
        'Achieve 150 minutes of moderate exercise weekly within 8 weeks',
      ],
      'heart': [
        'No hospital readmission for cardiac cause within 30 days',
        'Maintain weight gain <1 kg/day over 12 weeks',
        'Tolerate 10 minutes of light activity without dyspnoea within 6 weeks',
        'Adhere to fluid restriction (1.5 L/day) verified weekly',
        'NYHA class improved by 1 grade within 12 weeks',
      ],
      'copd': [
        'Improve oxygen saturation to ≥95% on room air within 4 weeks',
        'Demonstrate correct inhaler technique within 1 week',
        'Reduce exacerbations to zero over the next 3 months',
        'Walk 6 minutes without desaturation <90% within 8 weeks',
        'Smoking cessation maintained for 90 days',
      ],
      'stroke': [
        'Walk independently for 15 minutes daily within 6 weeks',
        'Regain independent feeding within 4 weeks',
        'Improve Barthel Index score by 20 points within 12 weeks',
        'Achieve clear speech in short sentences within 8 weeks',
        'Caregiver demonstrates safe transfer technique within 1 week',
      ],
      'wound': [
        'Achieve full wound closure within 4 weeks',
        'Reduce wound size by 50% within 2 weeks',
        'No signs of wound infection over 30 days',
        'Maintain skin integrity — no new pressure ulcers over 90 days',
        'Pain score at dressing change ≤2/10 within 2 weeks',
      ],
      'surgery': [
        'Resume light home exercises 3×/week within 6 weeks',
        'Wound healing without complications by week 4',
        'Pain score ≤3/10 within 2 weeks',
        'Independent in ADLs within 6 weeks',
        'No post-surgical infection over 30 days',
      ],
      'kidney': [
        'Adhere to renal diet (low K, low Na, low PO4) within 4 weeks',
        'Maintain fluid restriction (1 L/day) verified weekly',
        'Attend 100% of scheduled dialysis sessions over 90 days',
        'Maintain dry weight within 1 kg of target over 12 weeks',
      ],
      'cancer': [
        'Pain score ≤3/10 within 2 weeks',
        'Maintain oral intake ≥1500 kcal/day over 4 weeks',
        'Patient and family report comfort and dignity weekly',
        'Manage nausea — ≤1 episode/day within 2 weeks',
        'Advance care plan documented within 2 weeks',
      ],
      'demen': [
        'Reduce fall incidents to zero over the next 3 months',
        'Caregiver completes safety training within 2 weeks',
        'Maintain stable weight (±2 kg) over 12 weeks',
        'Engage in cognitive stimulation activity 5×/week',
        'No wandering incidents over 90 days',
      ],
      'mental': [
        'Stable mood with PHQ-9 score <10 within 8 weeks',
        'Achieve restful sleep ≥6 hours/night within 4 weeks',
        'Attend 100% of scheduled counselling sessions over 12 weeks',
        'Resume one social/recreational activity weekly within 4 weeks',
      ],
      'matern': [
        'Establish exclusive breastfeeding within 1 week',
        'Newborn gains ≥150 g/week over first 6 weeks',
        'Mother attends 100% of postnatal visits',
        'No signs of postpartum depression at 6-week assessment',
      ],
      'nutrition': [
        'Increase oral fluid intake to 1.5–2 L/day within 2 weeks',
        'Gain 0.5 kg/week until target weight reached',
        'Consume ≥1800 kcal/day verified by food diary',
        'Improve serum albumin to ≥35 g/L within 12 weeks',
      ],
      'fall': [
        'Walk independently for 15 minutes daily within 6 weeks',
        'Reduce fall incidents to zero over the next 3 months',
        'Independent in transfers within 4 weeks',
        'Climb 10 stairs unaided within 8 weeks',
        'Pain score ≤3/10 within 2 weeks',
      ],
    };
    for (final entry in diagMap.entries) {
      if (dx.contains(entry.key)) {
        matched.addAll(entry.value);
      }
    }
  }
  final seen = <String>{};
  final out = <String>[];
  for (final g in [...matched, ...generic]) {
    if (!seen.contains(g)) {
      seen.add(g);
      out.add(g);
    }
  }
  return out;
}

// ═════════════════ MAIN SCREEN ═════════════════
class HomecareTreatmentPlansScreen extends ConsumerStatefulWidget {
  const HomecareTreatmentPlansScreen({super.key});

  @override
  ConsumerState<HomecareTreatmentPlansScreen> createState() =>
      _HomecareTreatmentPlansScreenState();
}

class _HomecareTreatmentPlansScreenState
    extends ConsumerState<HomecareTreatmentPlansScreen> {
  final _search = TextEditingController();
  String _statusFilter = 'all';
  int? _patientFilter;
  bool _isBoard = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Map> _filterPlans(List<Map> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((p) {
      if (_patientFilter != null && p['patient'] != _patientFilter) return false;
      if (_statusFilter != 'all' && p['status'] != _statusFilter) return false;
      if (q.isEmpty) return true;
      return [p['title'], p['diagnosis'], p['patient_name']]
          .whereType<String>()
          .any((s) => s.toLowerCase().contains(q));
    }).toList();
  }

  void _openCreate() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _PlanFormSheet(),
    ).then((saved) {
      if (saved == true) ref.invalidate(_plansProvider);
    });
  }

  void _openEdit(Map plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PlanFormSheet(editing: plan),
    ).then((saved) {
      if (saved == true) ref.invalidate(_plansProvider);
    });
  }

  void _openDetail(Map plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PlanDetailSheet(plan: plan, onEdit: _openEdit),
    ).then((changed) {
      if (changed == true) ref.invalidate(_plansProvider);
    });
  }

  Future<void> _changeStatus(Map plan, String status) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/homecare/treatment-plans/${plan['id']}/', data: {'status': status});
      ref.invalidate(_plansProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Status updated to ${_statusLabel(status)}'), backgroundColor: hcGreen));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Status update failed'), backgroundColor: hcRed));
      }
    }
  }

  Future<void> _confirmDelete(Map plan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: hcRed),
          SizedBox(width: 8),
          Text('Delete plan?'),
        ]),
        content: const Text(
            'This permanently removes the plan and any unscheduled doses linked to it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: hcRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/homecare/treatment-plans/${plan['id']}/');
      ref.invalidate(_plansProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Plan deleted'), backgroundColor: hcGreen));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Delete failed'), backgroundColor: hcRed));
      }
    }
  }

  void _openActionMenu(Map plan) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.visibility_outlined),
            title: const Text('View'),
            onTap: () {
              Navigator.pop(context);
              _openDetail(plan);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit'),
            onTap: () {
              Navigator.pop(context);
              _openEdit(plan);
            },
          ),
          const Divider(height: 1),
          for (final t in _transitionsFor(plan['status']?.toString()))
            ListTile(
              leading: Icon(t.$3, color: t.$4),
              title: Text(t.$2),
              onTap: () {
                Navigator.pop(context);
                _changeStatus(plan, t.$1);
              },
            ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: hcRed),
            title: const Text('Delete', style: TextStyle(color: hcRed)),
            onTap: () {
              Navigator.pop(context);
              _confirmDelete(plan);
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(_plansProvider);
    final screenW = MediaQuery.of(context).size.width;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: _tpPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New plan'),
      ),
      body: HcAsyncBody(
        value: plans,
        onRefresh: () async => ref.refresh(_plansProvider.future),
        builder: (list) {
          final all = list.cast<Map>().toList();
          final filtered = _filterPlans(all);
          final activeCount = all.where((p) => p['status'] == 'active').length;
          final pausedCount = all.where((p) => p['status'] == 'paused').length;
          final completedCount = all.where((p) => p['status'] == 'completed').length;
          final medCount = all.fold(0, (n, p) => n + ((p['medication_count'] ?? 0) as int));

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              // ── Hero ──
              HcHero(
                eyebrow: 'CARE PLANNING',
                title: 'Treatment Plans',
                subtitle: 'Personalised care plans linking diagnoses, goals and medication regimens.',
                icon: Icons.assignment_rounded,
                gradient: const [_tpPurple, _tpPurpleDark, Color(0xFF5B21B6)],
                chips: [
                  HcHeroChip(icon: Icons.play_circle_rounded, label: '$activeCount active'),
                  HcHeroChip(icon: Icons.medication_rounded, label: '$medCount medications'),
                  HcHeroChip(icon: Icons.check_circle_rounded, label: '$completedCount completed'),
                ],
              ),

              // ── KPI strip — responsive row ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(children: [
                  Expanded(child: HcKpi(label: 'Active', value: '$activeCount', icon: Icons.play_circle_rounded, color: hcGreen)),
                  const SizedBox(width: 8),
                  Expanded(child: HcKpi(label: 'Paused', value: '$pausedCount', icon: Icons.pause_circle_rounded, color: hcAmber)),
                  const SizedBox(width: 8),
                  Expanded(child: HcKpi(label: 'Done', value: '$completedCount', icon: Icons.check_circle_rounded, color: hcBlue)),
                  const SizedBox(width: 8),
                  Expanded(child: HcKpi(label: 'Meds', value: '$medCount', icon: Icons.medication_rounded, color: hcPurple)),
                ]),
              ),

              // ── Filters ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Column(children: [
                  // Search + view toggle
                  Row(children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: TextField(
                          controller: _search,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search_rounded, size: 18),
                            hintText: 'Search…',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Theme.of(context).dividerColor),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ViewToggle(isBoard: _isBoard, onChanged: (v) => setState(() => _isBoard = v)),
                  ]),
                  const SizedBox(height: 8),
                  // Status + Patient filters
                  Row(children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: DropdownButtonFormField<String>(
                          value: _statusFilter,
                          isExpanded: true,
                          isDense: true,
                          decoration: _filterDeco(context, 'Status', Icons.flag_outlined),
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('All statuses', overflow: TextOverflow.ellipsis)),
                            for (final s in _statusOptions)
                              DropdownMenuItem(value: s.$1, child: Text(s.$2, overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Consumer(builder: (_, ref, __) {
                        final patientList = ref.watch(_patientsProvider).valueOrNull ?? [];
                        return SizedBox(
                          height: 44,
                          child: DropdownButtonFormField<int?>(
                            value: _patientFilter,
                            isExpanded: true,
                            isDense: true,
                            decoration: _filterDeco(context, 'Patient', Icons.person_outline),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All patients', overflow: TextOverflow.ellipsis)),
                              for (final p in patientList.cast<Map>())
                                DropdownMenuItem(
                                  value: p['id'] as int?,
                                  child: Text(_patientName(p), overflow: TextOverflow.ellipsis),
                                ),
                            ],
                            onChanged: (v) => setState(() => _patientFilter = v),
                          ),
                        );
                      }),
                    ),
                  ]),
                ]),
              ),

              const SizedBox(height: 12),

              // ── Board / List ──
              if (_isBoard)
                _BoardView(
                  plans: filtered,
                  colWidth: screenW > 600 ? 300 : screenW * 0.82,
                  onTap: _openDetail,
                  onMenu: _openActionMenu,
                )
              else
                _ListView(
                  plans: filtered,
                  onTap: _openDetail,
                  onMenu: _openActionMenu,
                ),
            ],
          );
        },
      ),
    );
  }

  InputDecoration _filterDeco(BuildContext context, String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      prefixIcon: Icon(icon, size: 16),
      prefixIconConstraints: const BoxConstraints(minWidth: 36),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).dividerColor),
      ),
    );
  }
}

// ═════════════════ VIEW TOGGLE ═════════════════
class _ViewToggle extends StatelessWidget {
  final bool isBoard;
  final ValueChanged<bool> onChanged;
  const _ViewToggle({required this.isBoard, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _segBtn(context, Icons.view_column_rounded, isBoard, () => onChanged(true)),
        Container(width: 1, height: 20, color: Theme.of(context).dividerColor),
        _segBtn(context, Icons.view_list_rounded, !isBoard, () => onChanged(false)),
      ]),
    );
  }

  Widget _segBtn(BuildContext context, IconData icon, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Icon(icon, size: 18,
            color: selected ? _tpPurple : Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

// ═════════════════ BOARD VIEW ═════════════════
class _BoardView extends StatelessWidget {
  final List<Map> plans;
  final double colWidth;
  final ValueChanged<Map> onTap;
  final ValueChanged<Map> onMenu;
  const _BoardView({required this.plans, required this.colWidth, required this.onTap, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final col in _statusBoard) ...[
              SizedBox(
                width: colWidth,
                child: _BoardColumn(
                  status: col.$1,
                  label: col.$2,
                  color: col.$3,
                  icon: col.$4,
                  plans: plans.where((p) => p['status'] == col.$1).toList(),
                  onTap: onTap,
                  onMenu: onMenu,
                ),
              ),
              const SizedBox(width: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _BoardColumn extends StatelessWidget {
  final String status;
  final String label;
  final Color color;
  final IconData icon;
  final List<Map> plans;
  final ValueChanged<Map> onTap;
  final ValueChanged<Map> onMenu;
  const _BoardColumn({
    required this.status, required this.label, required this.color, required this.icon,
    required this.plans, required this.onTap, required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: color.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.08)),
          child: Row(children: [
            CircleAvatar(radius: 12, backgroundColor: color, child: Icon(icon, color: Colors.white, size: 12)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
              child: Text('${plans.length}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        // Cards
        if (plans.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Icon(Icons.inbox_rounded, size: 24, color: color.withValues(alpha: 0.3)),
              const SizedBox(height: 4),
              Text('No ${label.toLowerCase()} plans', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          )
        else
          Padding(
            padding: const EdgeInsets.all(6),
            child: Column(children: [
              for (final p in plans)
                _PlanCard(plan: p, color: color, onTap: () => onTap(p), onMenu: () => onMenu(p)),
            ]),
          ),
      ]),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Map plan;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onMenu;
  const _PlanCard({required this.plan, required this.color, required this.onTap, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    final progress = _planProgress(plan);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Title + menu
              Row(children: [
                Container(width: 3, height: 28, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(plan['title']?.toString() ?? '—',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ),
                InkWell(
                  onTap: onMenu,
                  borderRadius: BorderRadius.circular(14),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.more_vert_rounded, size: 16),
                  ),
                ),
              ]),
              // Diagnosis
              if ((plan['diagnosis'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.medical_services_outlined, size: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(plan['diagnosis'].toString(),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                ]),
              ],
              // Patient
              const SizedBox(height: 3),
              Row(children: [
                Icon(Icons.person_outline, size: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(plan['patient_name']?.toString() ?? '—',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              ]),
              // Progress
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress / 100,
                  minHeight: 5,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.12),
                ),
              ),
              // Footer: dates + med count
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.calendar_today_outlined, size: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 2),
                Flexible(child: Text(_fmtDate(plan['start_date']), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, color: Theme.of(context).colorScheme.onSurfaceVariant))),
                if (plan['end_date'] != null) ...[
                  Icon(Icons.arrow_forward_rounded, size: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 1),
                  Flexible(child: Text(_fmtDate(plan['end_date']), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, color: Theme.of(context).colorScheme.onSurfaceVariant))),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: hcPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.medication_rounded, size: 9, color: hcPurple),
                    const SizedBox(width: 2),
                    Text('${plan['medication_count'] ?? 0}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: hcPurple)),
                  ]),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ═════════════════ LIST VIEW ═════════════════
class _ListView extends StatelessWidget {
  final List<Map> plans;
  final ValueChanged<Map> onTap;
  final ValueChanged<Map> onMenu;
  const _ListView({required this.plans, required this.onTap, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(children: [
            Icon(Icons.assignment_outlined, size: 40, color: hcSlate.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            const Text('No treatment plans yet', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Create the first care plan for a patient.', style: TextStyle(fontSize: 12, color: hcSlate)),
          ]),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        for (final p in plans)
          _ListCard(plan: p, onTap: () => onTap(p), onMenu: () => onMenu(p)),
      ]),
    );
  }
}

class _ListCard extends StatelessWidget {
  final Map plan;
  final VoidCallback onTap;
  final VoidCallback onMenu;
  const _ListCard({required this.plan, required this.onTap, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    final status = plan['status']?.toString();
    final color = _statusColor(status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Status avatar
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_statusIcon(status), color: color, size: 20),
              ),
              const SizedBox(width: 10),
              // Content
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Title + status chip
                Row(children: [
                  Expanded(
                    child: Text(plan['title']?.toString() ?? '—',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  ),
                  HcStatusChip(label: _statusLabel(status), color: color),
                ]),
                // Diagnosis
                if ((plan['diagnosis'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(plan['diagnosis'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
                // Patient
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.person_outline, size: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Expanded(child: Text(plan['patient_name']?.toString() ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant))),
                ]),
                // Footer: dates + meds
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.calendar_today_outlined, size: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Flexible(child: Text(_fmtDate(plan['start_date']), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant))),
                  if (plan['end_date'] != null) ...[
                    Icon(Icons.arrow_forward_rounded, size: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 1),
                    Flexible(child: Text(_fmtDate(plan['end_date']), maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant))),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: hcPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.medication_rounded, size: 9, color: hcPurple),
                      const SizedBox(width: 2),
                      Text('${plan['medication_count'] ?? 0}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: hcPurple)),
                    ]),
                  ),
                ]),
              ])),
              // Menu
              InkWell(
                onTap: onMenu,
                borderRadius: BorderRadius.circular(14),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.more_vert_rounded, size: 18),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ═════════════════ CREATE / EDIT SHEET ═════════════════
class _PlanFormSheet extends ConsumerStatefulWidget {
  final Map? editing;
  const _PlanFormSheet({this.editing});

  @override
  ConsumerState<_PlanFormSheet> createState() => _PlanFormSheetState();
}

class _PlanFormSheetState extends ConsumerState<_PlanFormSheet> {
  late final TextEditingController _titleCtl = TextEditingController(text: widget.editing?['title']?.toString() ?? '');
  late final TextEditingController _diagnosisCtl = TextEditingController(text: widget.editing?['diagnosis']?.toString() ?? '');
  final _notesCtl = TextEditingController();
  final _goalCtl = TextEditingController();
  int? _patientId;
  late String _status;
  late String _startDate;
  String _endDate = '';
  final List<String> _goals = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.editing?['status']?.toString() ?? 'active';
    _startDate = widget.editing?['start_date']?.toString() ?? DateTime.now().toIso8601String().substring(0, 10);
    _endDate = widget.editing?['end_date']?.toString() ?? '';
    _goals.addAll(_parseGoals(widget.editing?['goals']));
    if (widget.editing != null) {
      _patientId = widget.editing!['patient'] as int?;
      _notesCtl.text = widget.editing!['notes']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _diagnosisCtl.dispose();
    _notesCtl.dispose();
    _goalCtl.dispose();
    super.dispose();
  }

  void _onPatientSelected(Map p) {
    setState(() {
      _patientId = p['id'] as int?;
      final dx = p['primary_diagnosis']?.toString() ?? '';
      if (dx.isNotEmpty && _diagnosisCtl.text.isEmpty) {
        _diagnosisCtl.text = dx;
      }
      if (_titleCtl.text.isEmpty && dx.isNotEmpty) {
        _titleCtl.text = '$dx Care Plan';
      }
    });
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
        if (isStart) { _startDate = s; } else { _endDate = s; }
      });
    }
  }

  Future<void> _save() async {
    final isEdit = widget.editing != null;
    if (_titleCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan title is required')));
      return;
    }
    if (!isEdit && _patientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Patient is required')));
      return;
    }
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      final payload = {
        if (_patientId != null) 'patient': _patientId,
        'title': _titleCtl.text.trim(),
        'diagnosis': _diagnosisCtl.text.trim(),
        'status': _status,
        'start_date': _startDate,
        'end_date': _endDate.isEmpty ? null : _endDate,
        'goals': _goals,
        'notes': _notesCtl.text.trim(),
      };
      if (isEdit) {
        await dio.patch('/homecare/treatment-plans/${widget.editing!['id']}/', data: payload);
      } else {
        await dio.post('/homecare/treatment-plans/', data: payload);
      }
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEdit ? 'Plan updated' : 'Plan created'), backgroundColor: hcGreen));
      }
    } catch (e) {
      String msg = 'Save failed';
      try {
        final data = (e as dynamic).response?.data;
        if (data is Map) msg = data.values.toString();
      } catch (_) {}
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: hcRed));
      }
    }
  }

  InputDecoration _fieldDeco(String label, IconData icon, {String? helper}) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
      prefixIcon: Icon(icon, size: 20),
      helperText: helper,
      isDense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editing != null;
    final suggestions = _smartGoalOptions(_diagnosisCtl.text);
    final patients = ref.watch(_patientsProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
        title: Text(isEdit ? 'Edit Plan' : 'Create Treatment Plan', style: const TextStyle(fontSize: 16)),
        backgroundColor: _tpPurple,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Patient selector
            if (!isEdit) ...[
              DropdownButtonFormField<int>(
                value: _patientId,
                isExpanded: true,
                decoration: _fieldDeco('Patient *', Icons.person_outline_rounded),
                items: [
                  for (final p in patients.cast<Map>())
                    DropdownMenuItem(value: p['id'] as int?, child: Text(_patientName(p), overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  _onPatientSelected(patients.cast<Map>().firstWhere((x) => x['id'] == v));
                },
              ),
              const SizedBox(height: 12),
            ],

            // Title with autocomplete
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _titleCtl.text),
              optionsBuilder: (tev) {
                if (tev.text.isEmpty) return _planTitleOptions;
                return _planTitleOptions.where((o) => o.toLowerCase().contains(tev.text.toLowerCase()));
              },
              onSelected: (v) => setState(() => _titleCtl.text = v),
              fieldViewBuilder: (_, controller, focusNode, onSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: _fieldDeco('Plan title *', Icons.title_rounded, helper: 'Pick a template or type your own'),
                  onChanged: (v) => _titleCtl.text = v,
                  onSubmitted: (_) => onSubmitted(),
                );
              },
            ),
            const SizedBox(height: 12),

            // Diagnosis
            TextField(
              controller: _diagnosisCtl,
              decoration: _fieldDeco('Primary diagnosis', Icons.medical_services_rounded,
                  helper: _patientId != null && _diagnosisCtl.text.isNotEmpty ? 'Auto-filled from patient record' : null),
            ),
            const SizedBox(height: 12),

            // Status + dates row
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _status,
                  isExpanded: true,
                  decoration: _fieldDeco('Status', Icons.flag_rounded),
                  items: [for (final s in _statusOptions) DropdownMenuItem(value: s.$1, child: Text(s.$2, overflow: TextOverflow.ellipsis))],
                  onChanged: (v) => setState(() => _status = v ?? 'active'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(true),
                  child: InputDecorator(
                    decoration: _fieldDeco('Start *', Icons.calendar_today_rounded),
                    child: Text(hcDate(_startDate), style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // End date
            InkWell(
              onTap: () => _pickDate(false),
              child: InputDecorator(
                decoration: _fieldDeco('Target end date', Icons.event_rounded),
                child: Text(_endDate.isNotEmpty ? hcDate(_endDate) : 'Optional',
                    style: TextStyle(fontSize: 13, color: _endDate.isEmpty ? hcSlate : null),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(height: 16),

            // Goals
            Text('Care goals', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            if (_goals.isNotEmpty) ...[
              Wrap(spacing: 5, runSpacing: 5, children: [
                for (final g in _goals)
                  Chip(
                    label: Text(g, style: const TextStyle(fontSize: 11)),
                    onDeleted: () => setState(() => _goals.remove(g)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: hcTeal.withValues(alpha: 0.1),
                  ),
              ]),
              const SizedBox(height: 6),
            ],
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _goalCtl,
                  decoration: InputDecoration(
                    hintText: 'Add a SMART goal…',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) => _addGoal(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _tpPurple, minimumSize: const Size(48, 44)),
                onPressed: _addGoal,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(''),
              ),
            ]),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Suggestions', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Wrap(spacing: 4, runSpacing: 4, children: [
                for (final s in suggestions.take(6))
                  ActionChip(
                    label: Text(s, style: const TextStyle(fontSize: 10)),
                    onPressed: () => setState(() => _goals.add(s)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ]),
            ],
            const SizedBox(height: 16),

            // Notes
            TextField(
              controller: _notesCtl,
              maxLines: 3,
              decoration: _fieldDeco('Clinical notes', Icons.note_alt_rounded),
            ),
            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _tpPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(isEdit ? Icons.save_rounded : Icons.add_rounded, size: 18),
                label: Text(isEdit ? 'Save changes' : 'Create plan'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═════════════════ DETAIL SHEET ═════════════════
class _PlanDetailSheet extends ConsumerStatefulWidget {
  final Map plan;
  final void Function(Map) onEdit;
  const _PlanDetailSheet({required this.plan, required this.onEdit});

  @override
  ConsumerState<_PlanDetailSheet> createState() => _PlanDetailSheetState();
}

class _PlanDetailSheetState extends ConsumerState<_PlanDetailSheet>
    with TickerProviderStateMixin {
  late TabController _tab;
  List<Map> _medications = [];
  bool _loadingMeds = false;
  bool _changingStatus = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _loadMedications();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadMedications() async {
    setState(() => _loadingMeds = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/homecare/medication-schedules/', queryParameters: {
        'treatment_plan': widget.plan['id'],
        'page_size': 100,
      });
      final data = res.data;
      final list = data is Map ? data['results'] : data;
      if (mounted) setState(() => _medications = (list as List?)?.cast<Map>() ?? []);
    } catch (_) {}
    if (mounted) setState(() => _loadingMeds = false);
  }

  Future<void> _changeStatus(String status) async {
    setState(() => _changingStatus = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/homecare/treatment-plans/${widget.plan['id']}/', data: {'status': status});
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Status updated to ${_statusLabel(status)}'), backgroundColor: hcGreen));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Status update failed'), backgroundColor: hcRed));
      }
    }
    if (mounted) setState(() => _changingStatus = false);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final status = plan['status']?.toString();
    final statusColor = _statusColor(status);
    final goals = _parseGoals(plan['goals']);
    final medCount = _medications.length;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Column(
            children: [
              // ── Gradient hero ──
              Container(
                padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 8, 0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [statusColor, statusColor.withValues(alpha: 0.65)],
                  ),
                ),
                child: Column(children: [
                  // Top row
                  Row(children: [
                    CircleAvatar(radius: 22, backgroundColor: Colors.white, child: Icon(_statusIcon(status), color: statusColor, size: 22)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${_statusLabel(status).toUpperCase()} PLAN',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                      const SizedBox(height: 2),
                      Text(plan['title']?.toString() ?? '—',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ])),
                    IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
                  ]),
                  const SizedBox(height: 8),
                  // Patient + diagnosis
                  Row(children: [
                    Icon(Icons.person_outline, size: 11, color: Colors.white.withValues(alpha: 0.8)),
                    const SizedBox(width: 3),
                    Flexible(child: Text(plan['patient_name']?.toString() ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5))),
                    const SizedBox(width: 6),
                    Icon(Icons.medical_services_outlined, size: 11, color: Colors.white.withValues(alpha: 0.8)),
                    const SizedBox(width: 3),
                    Flexible(child: Text(plan['diagnosis']?.toString() ?? 'No diagnosis', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5))),
                  ]),
                  const SizedBox(height: 8),
                  // Chips
                  Wrap(spacing: 5, runSpacing: 4, children: [
                    _detailChip(Icons.calendar_today_rounded, _fmtDate(plan['start_date'])),
                    if (plan['end_date'] != null)
                      _detailChip(Icons.event_rounded, _fmtDate(plan['end_date'])),
                    _detailChip(Icons.medication_rounded, '$medCount meds'),
                    _detailChip(Icons.track_changes_rounded, '${goals.length} goals'),
                  ]),
                  // Tabs
                  TabBar(
                    controller: _tab,
                    indicatorColor: Colors.white,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
                    labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: const TextStyle(fontSize: 11),
                    tabAlignment: TabAlignment.start,
                    isScrollable: true,
                    padding: const EdgeInsets.only(top: 8),
                    tabs: const [
                      Tab(icon: Icon(Icons.dashboard_rounded, size: 14), text: 'Overview'),
                      Tab(icon: Icon(Icons.medication_rounded, size: 14), text: 'Meds'),
                      Tab(icon: Icon(Icons.track_changes_rounded, size: 14), text: 'Goals'),
                      Tab(icon: Icon(Icons.note_alt_rounded, size: 14), text: 'Notes'),
                    ],
                  ),
                ]),
              ),

              // ── Tab content ──
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _buildOverviewTab(plan, status),
                    _buildMedsTab(),
                    _buildGoalsTab(goals),
                    _buildNotesTab(plan),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: Colors.white),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildOverviewTab(Map plan, String? status) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Info card
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            _infoRow('Status', child: HcStatusChip(label: _statusLabel(status), color: _statusColor(status))),
            _infoRow('Diagnosis', text: plan['diagnosis']?.toString() ?? '—'),
            _infoRow('Duration', text: _durationLabel(plan)),
            _infoRow('Start', text: _fmtDate(plan['start_date'])),
            _infoRow('Target end', text: plan['end_date'] != null ? _fmtDate(plan['end_date']) : 'Open-ended'),
            _infoRow('Last updated', text: _fmtDateTime(plan['updated_at'])),
          ]),
        ),
        const SizedBox(height: 16),
        // Status transitions
        Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in _transitionsFor(status))
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: t.$4.withValues(alpha: 0.12),
                foregroundColor: t.$4,
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(0, 36),
              ),
              onPressed: _changingStatus ? null : () => _changeStatus(t.$1),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(t.$3, size: 14), const SizedBox(width: 4), Text(t.$2, style: const TextStyle(fontSize: 12))]),
            ),
        ]),
        const SizedBox(height: 16),
        // Edit button
        SizedBox(
          width: double.infinity, height: 46,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: hcIndigo, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () { Navigator.pop(context); widget.onEdit(widget.plan); },
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: const Text('Edit plan'),
          ),
        ),
      ]),
    );
  }

  Widget _infoRow(String label, {String? text, Widget? child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 90, child: Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant))),
        Expanded(child: child ?? Text(text ?? '—', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5))),
      ]),
    );
  }

  Widget _buildMedsTab() {
    if (_loadingMeds) return const Center(child: CircularProgressIndicator(color: _tpPurple));
    if (_medications.isEmpty) {
      return _emptyState(Icons.medication_rounded, 'No medications scheduled', 'Add a medication schedule from the prescriptions module.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _medications.length,
      itemBuilder: (_, i) {
        final m = _medications[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hcPurple.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            CircleAvatar(radius: 18, backgroundColor: hcPurple.withValues(alpha: 0.12), child: const Icon(Icons.medication_rounded, color: hcPurple, size: 16)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${m['medication_name'] ?? '—'} · ${m['dose'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              const SizedBox(height: 2),
              Text('${m['route_label'] ?? m['route'] ?? ''} · ${_medFrequency(m)}${m['instructions'] != null && m['instructions'].toString().isNotEmpty ? ' · ${m['instructions']}' : ''}',
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ])),
            HcStatusChip(label: m['is_active'] == true ? 'Active' : 'Stopped', color: m['is_active'] == true ? hcGreen : hcSlate),
          ]),
        );
      },
    );
  }

  Widget _buildGoalsTab(List<String> goals) {
    if (goals.isEmpty) return _emptyState(Icons.track_changes_rounded, 'No goals defined', 'Edit the plan to add SMART care goals.');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: goals.length,
      itemBuilder: (_, i) {
        final isLast = i == goals.length - 1;
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 28, child: Column(children: [
              Container(width: 22, height: 22, decoration: const BoxDecoration(color: hcTeal, shape: BoxShape.circle), child: const Icon(Icons.track_changes_rounded, color: Colors.white, size: 11)),
              if (!isLast) Expanded(child: Container(width: 2, color: hcTeal.withValues(alpha: 0.2))),
            ])),
            const SizedBox(width: 10),
            Expanded(child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Goal ${i + 1}', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(goals[i], style: const TextStyle(fontSize: 12.5)),
              ]),
            )),
          ]),
        );
      },
    );
  }

  Widget _buildNotesTab(Map plan) {
    final notes = plan['notes']?.toString() ?? '';
    if (notes.isEmpty) return _emptyState(Icons.note_alt_outlined, 'No clinical notes', 'Notes added to the plan will appear here.');
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Text(notes, style: const TextStyle(fontSize: 13, height: 1.5)));
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 40, color: hcSlate.withValues(alpha: 0.4)),
      const SizedBox(height: 8),
      Text(title, style: const TextStyle(color: hcSlate, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(fontSize: 11, color: hcSlate), textAlign: TextAlign.center),
    ]));
  }
}
