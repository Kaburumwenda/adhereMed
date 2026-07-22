import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api.dart';
import '../hc_common.dart';
import 'hc_analytics_common.dart';

// ═════════════════════════════════════════════════════════════════
//  Pages 1–3: Overview · Patients · Workforce/Caregivers
// ═════════════════════════════════════════════════════════════════

// ───────────────────────────────────────────────────────────────
//  PAGE 1 — Analytics Overview
// ───────────────────────────────────────────────────────────────
class HcAnalyticsOverviewScreen extends ConsumerStatefulWidget {
  const HcAnalyticsOverviewScreen({super.key});
  @override
  ConsumerState<HcAnalyticsOverviewScreen> createState() =>
      _HcAnalyticsOverviewScreenState();
}

class _HcAnalyticsOverviewScreenState
    extends ConsumerState<HcAnalyticsOverviewScreen> {
  Map<String, dynamic> _data = {};
  bool _loading = false;
  String _adherenceRange = '30d';
  String _doseRange = '30d';
  String _visitRange = '30d';
  String _revenueRange = '30d';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioProvider).get(
        '/homecare/analytics/overview/',
        queryParameters: {'range': '30d'},
      );
      _data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      _adherenceRange = _doseRange = _visitRange = _revenueRange = '30d';
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadChart(String chart, String range) async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioProvider).get(
        '/homecare/analytics/overview/',
        queryParameters: {'range': range},
      );
      final d = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      final keys = {
        'adherence': 'adherence_trend',
        'dose': 'dose_breakdown',
        'visit': 'visit_trend',
        'revenue': 'revenue_trend',
      };
      final key = keys[chart]!;
      if (d.containsKey(key)) _data[key] = d[key];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final k = (_data['kpis'] as Map?)?.cast<String, dynamic>() ?? {};
    final db = (_data['dose_breakdown'] as Map?)?.cast<String, dynamic>() ?? {};
    final aTrend = (_data['adherence_trend'] as List?)?.cast<Map>() ?? [];
    final vTrend = (_data['visit_trend'] as List?)?.cast<Map>() ?? [];
    final rTrend = (_data['revenue_trend'] as List?)?.cast<Map>() ?? [];

    final aVals = aTrend.map((e) => (e['rate'] as num?) ?? 0).toList();
    final avg = aVals.isNotEmpty ? aVals.reduce((a, b) => a + b) ~/ aVals.length : 0;
    final best = aVals.isNotEmpty ? aVals.reduce((a, b) => a > b ? a : b) : 0;
    final worst = aVals.isNotEmpty ? aVals.reduce((a, b) => a < b ? a : b) : 0;

    final doseSegs = <({String label, num value, Color color})>[
      (label: 'Taken', value: db['taken'] ?? 0, color: hcGreen),
      (label: 'Pending', value: db['pending'] ?? 0, color: hcBlue),
      (label: 'Missed', value: db['missed'] ?? 0, color: hcRed),
      (label: 'Skipped', value: db['skipped'] ?? 0, color: hcAmber),
      (label: 'Refused', value: db['refused'] ?? 0, color: hcSlate),
    ];

    final visitGroups = vTrend.map((e) => [(e['completed'] as num?) ?? 0, (e['missed'] as num?) ?? 0]).toList();
    final visitLabels = vTrend.map((e) => (e['date'] ?? '').toString().substring(5)).toList();

    final rVals = rTrend.map((e) => (e['amount'] as num?) ?? 0).toList();
    final rLabels = rTrend.map((e) => (e['date'] ?? '').toString().substring(5)).toList();

    final kpis = <({String label, String value, IconData icon, Color color, String? hint})>[
      (label: 'Active Patients', value: '${k['active_patients'] ?? 0}', icon: Icons.people_alt_rounded, color: hcTeal, hint: '${k['total_patients'] ?? 0} total'),
      (label: 'Adherence (30d)', value: '${k['adherence_30d'] ?? 0}%', icon: Icons.medication_rounded, color: hcGreen, hint: '${k['adherence_today'] ?? 0}% today'),
      (label: 'Visits Done (30d)', value: '${k['visits_completed_30d'] ?? 0}', icon: Icons.event_available_rounded, color: hcIndigo, hint: '${k['visits_today'] ?? 0} today'),
      (label: 'Open Escalations', value: '${k['escalations_open'] ?? 0}', icon: Icons.warning_amber_rounded, color: hcRed, hint: '${k['escalations_30d'] ?? 0} in 30d'),
      (label: 'Monthly Revenue', value: hcMoney(k['monthly_revenue']), icon: Icons.payments_rounded, color: hcAmber, hint: '${hcMoney(k['outstanding'])} outstanding'),
      (label: 'Open Claims', value: '${k['claims_open'] ?? 0}', icon: Icons.shield_rounded, color: const Color(0xFFF97316), hint: '${k['claims_30d'] ?? 0} new'),
      (label: 'Equipment Util.', value: '${k['utilisation'] ?? 0}%', icon: Icons.devices_rounded, color: const Color(0xFF06B6D4), hint: '${k['devices_available'] ?? 0} available'),
      (label: 'Teleconsults', value: '${k['teleconsults_30d'] ?? 0}', icon: Icons.videocam_rounded, color: hcPurple, hint: 'last 30 days'),
    ];

    return HcAnalyticsPage(
      currentPath: '/homecare/analytics',
      title: 'Analytics Command Centre',
      subtitle: 'Real-time view of operational health across the programme',
      heroIcon: Icons.analytics_rounded,
      heroChips: [
        HcHeroChip(icon: Icons.people_alt_rounded, label: '${k['active_patients'] ?? 0} active'),
        HcHeroChip(icon: Icons.medication_rounded, label: '${k['adherence_today'] ?? 0}% adherence'),
        HcHeroChip(icon: Icons.payments_rounded, label: '${hcMoney(k['monthly_revenue'])}/mo'),
      ],
      loading: _loading,
      onRefresh: _load,
      body: [
        const SizedBox(height: 8),
        HcKpiGrid(items: kpis),
        const SizedBox(height: 8),
        HcPanel(
          title: '${rangeLabel(_adherenceRange)} adherence trend',
          subtitle: '% of doses documented on time',
          icon: Icons.show_chart_rounded,
          color: hcTeal,
          action: HcRangeSelector(value: _adherenceRange, onChanged: (v) { setState(() => _adherenceRange = v); _loadChart('adherence', v); }),
          child: aVals.isEmpty
              ? const HcEmptyState(icon: Icons.show_chart_rounded, title: 'No adherence data')
              : Column(children: [
                  HcLineChart(series: [(label: 'Adherence', color: hcTeal, values: aVals)], labels: aTrend.map((e) => (e['date'] ?? '').toString().substring(5)).toList(), height: 200, minY: 0, maxY: 100, yFormatter: (v) => '${v.round()}%', scrollable: true),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    HcStatusChip(label: 'Avg: $avg%', color: hcTeal),
                    HcStatusChip(label: 'Best: $best%', color: hcGreen),
                    HcStatusChip(label: 'Worst: $worst%', color: hcRed),
                    HcStatusChip(label: '${k['adherence_30d'] ?? 0}% overall', color: hcBlue),
                  ]),
                ]),
        ),
        HcPanel(
          title: 'Dose outcomes (${rangeLabel(_doseRange)})',
          subtitle: 'All scheduled doses',
          icon: Icons.medication_rounded,
          color: hcGreen,
          action: HcRangeSelector(value: _doseRange, onChanged: (v) { setState(() => _doseRange = v); _loadChart('dose', v); }),
          child: doseSegs.every((s) => s.value == 0)
              ? const HcEmptyState(icon: Icons.medication_rounded, title: 'No dose data')
              : Column(children: [
                  Center(child: HcDonutRing(segments: doseSegs, centerValue: '${db['total'] ?? 0}', centerLabel: 'doses')),
                  const SizedBox(height: 8),
                  for (final s in doseSegs) HcLegendRow(label: s.label, value: s.value, color: s.color),
                ]),
        ),
        HcPanel(
          title: 'Visit activity (${rangeLabel(_visitRange)})',
          subtitle: 'Completed vs missed visits',
          icon: Icons.event_note_rounded,
          color: hcIndigo,
          action: HcRangeSelector(value: _visitRange, onChanged: (v) { setState(() => _visitRange = v); _loadChart('visit', v); }),
          child: visitGroups.isEmpty
              ? const HcEmptyState(icon: Icons.event_note_rounded, title: 'No visit data')
              : Column(children: [
                  HcBarChart(groups: visitGroups, labels: visitLabels, colors: [hcGreen, hcRed], height: 200, scrollable: true),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    HcStatusChip(label: '${k['visits_completed_30d'] ?? 0} done', color: hcGreen),
                    HcStatusChip(label: '${k['visits_missed_30d'] ?? 0} missed', color: hcRed),
                    HcStatusChip(label: '${k['visits_today'] ?? 0} today', color: hcBlue),
                  ]),
                ]),
        ),
        HcPanel(
          title: 'Revenue collected (${rangeLabel(_revenueRange)})',
          subtitle: 'Daily payments received',
          icon: Icons.payments_rounded,
          color: hcAmber,
          action: HcRangeSelector(value: _revenueRange, onChanged: (v) { setState(() => _revenueRange = v); _loadChart('revenue', v); }),
          child: rVals.isEmpty
              ? const HcEmptyState(icon: Icons.payments_rounded, title: 'No revenue data')
              : Column(children: [
                  HcLineChart(series: [(label: 'Revenue', color: hcAmber, values: rVals)], labels: rLabels, height: 180, yFormatter: (v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.round().toString(), scrollable: true),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    HcStatusChip(label: hcMoney(k['total_collected_30d']), color: hcGreen),
                    HcStatusChip(label: '${hcMoney(k['outstanding'])} outstanding', color: hcAmber),
                  ]),
                ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('Analytics domains', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.3, crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: _domainTiles.length,
            itemBuilder: (context, i) {
              final d = _domainTiles[i];
              return Card(
                margin: EdgeInsets.zero,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.go(d.$3),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(gradient: LinearGradient(colors: [d.$4, Color.lerp(d.$4, Colors.black, 0.15)!]), borderRadius: BorderRadius.circular(12)),
                        child: Icon(d.$2, color: Colors.white, size: 22),
                      ),
                      const SizedBox(height: 10),
                      Text(d.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      Text(d.$5, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

const _domainTiles = <(String, IconData, String, Color, String)>[
  ('Patients', Icons.people_alt_rounded, '/homecare/analytics/patients', hcBlue, 'Demographics & risk'),
  ('Equipment', Icons.devices_rounded, '/homecare/analytics/equipment', Color(0xFF06B6D4), 'Device utilisation'),
  ('Financials', Icons.payments_rounded, '/homecare/analytics/financials', hcAmber, 'Billing & revenue'),
  ('Workforce', Icons.volunteer_activism_rounded, '/homecare/analytics/caregivers', hcIndigo, 'Caregiver performance'),
  ('Visits', Icons.event_note_rounded, '/homecare/analytics/visits', hcPurple, 'Schedules & completion'),
  ('Adherence', Icons.medication_rounded, '/homecare/analytics/adherence', hcGreen, 'Medication tracking'),
  ('Escalations', Icons.warning_amber_rounded, '/homecare/analytics/escalations', hcRed, 'Alerts & resolution'),
  ('Insurance', Icons.shield_rounded, '/homecare/analytics/insurance', Color(0xFFF97316), 'Claims & approval'),
];

// ───────────────────────────────────────────────────────────────
//  PAGE 2 — Patient Analytics
// ───────────────────────────────────────────────────────────────
class HcAnalyticsPatientsScreen extends ConsumerStatefulWidget {
  const HcAnalyticsPatientsScreen({super.key});
  @override
  ConsumerState<HcAnalyticsPatientsScreen> createState() =>
      _HcAnalyticsPatientsScreenState();
}

class _HcAnalyticsPatientsScreenState
    extends ConsumerState<HcAnalyticsPatientsScreen> {
  Map<String, dynamic> _data = {};
  bool _loading = false;
  String _enrolmentRange = '30d';
  String _search = '';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioProvider).get(
        '/homecare/analytics/patients/',
        queryParameters: {'range': '30d'},
      );
      _data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      _enrolmentRange = '30d';
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadChart(String range) async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioProvider).get(
        '/homecare/analytics/patients/',
        queryParameters: {'range': range},
      );
      final d = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      if (d.containsKey('enrolment_trend')) _data['enrolment_trend'] = d['enrolment_trend'];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final risk = (d['risk'] as Map?)?.cast<String, dynamic>() ?? {};
    final gender = (d['gender'] as Map?)?.cast<String, dynamic>() ?? {};
    final ageGroups = (d['age_groups'] as Map?)?.cast<String, dynamic>() ?? {};
    final enrolTrend = (d['enrolment_trend'] as List?)?.cast<Map>() ?? [];
    final topDiag = (d['top_diagnoses'] as List?)?.cast<Map>() ?? [];
    final patients = (d['patients'] as List?)?.cast<Map>() ?? [];

    final riskSegs = <({String label, num value, Color color})>[
      (label: 'Low', value: risk['low'] ?? 0, color: hcGreen),
      (label: 'Medium', value: risk['medium'] ?? 0, color: hcAmber),
      (label: 'High', value: risk['high'] ?? 0, color: hcRed),
      (label: 'Critical', value: risk['critical'] ?? 0, color: const Color(0xFFEA580C)),
    ];

    final genderEntries = [
      ('Male', 'male', Icons.male_rounded, hcBlue),
      ('Female', 'female', Icons.female_rounded, const Color(0xFFEC4899)),
      ('Other', 'other', Icons.transgender_rounded, hcPurple),
      ('Unknown', 'unknown', Icons.help_outline_rounded, hcSlate),
    ];
    final gTotal = gender.values.fold<num>(0, (a, b) => a + (b as num));
    final gSafeTotal = gTotal > 0 ? gTotal : 1;

    final ageLabels = ageGroups.keys.toList();
    final ageValues = ageGroups.values.map((v) => (v as num?) ?? 0).toList();

    final enrolVals = enrolTrend.map((e) => (e['count'] as num?) ?? 0).toList();
    final enrolLabels = enrolTrend.map((e) => (e['date'] ?? '').toString().substring(5)).toList();
    final enrolTotal = enrolVals.fold<num>(0, (a, b) => a + b);

    final filteredPatients = _search.isEmpty
        ? patients
        : patients.where((p) =>
            (p['name'] ?? '').toString().toLowerCase().contains(_search) ||
            (p['mrn'] ?? '').toString().toLowerCase().contains(_search) ||
            (p['primary_diagnosis'] ?? '').toString().toLowerCase().contains(_search)).toList();

    final kpis = <({String label, String value, IconData icon, Color color, String? hint})>[
      (label: 'Total Patients', value: '${d['total'] ?? 0}', icon: Icons.people_alt_rounded, color: hcTeal, hint: null),
      (label: 'Active', value: '${d['active'] ?? 0}', icon: Icons.check_circle_rounded, color: hcGreen, hint: null),
      (label: 'Assigned', value: '${d['assigned'] ?? 0}', icon: Icons.assignment_ind_rounded, color: hcIndigo, hint: '${d['unassigned'] ?? 0} unassigned'),
      (label: 'Discharged', value: '${d['discharged'] ?? 0}', icon: Icons.person_off_rounded, color: hcSlate, hint: null),
    ];

    return HcAnalyticsPage(
      currentPath: '/homecare/analytics/patients',
      title: 'Patient Analytics',
      subtitle: 'Demographics, risk stratification, enrolment & diagnosis',
      heroIcon: Icons.people_alt_rounded,
      heroGradient: const [Color(0xFF0284C7), Color(0xFF0EA5E9), Color(0xFF38BDF8)],
      heroChips: [
        HcHeroChip(icon: Icons.people_rounded, label: '${d['total'] ?? 0} patients'),
        HcHeroChip(icon: Icons.check_circle_rounded, label: '${d['active'] ?? 0} active'),
        HcHeroChip(icon: Icons.assignment_ind_rounded, label: '${d['assigned'] ?? 0} assigned'),
      ],
      loading: _loading,
      onRefresh: _load,
      body: [
        const SizedBox(height: 8),
        HcKpiGrid(items: kpis),
        const SizedBox(height: 8),
        HcPanel(
          title: 'Risk stratification',
          subtitle: 'Patients by risk level',
          icon: Icons.warning_amber_rounded,
          color: hcRed,
          child: riskSegs.every((s) => s.value == 0)
              ? const HcEmptyState(icon: Icons.warning_amber_rounded, title: 'No risk data')
              : Column(children: [
                  Center(child: HcDonutRing(segments: riskSegs, centerValue: '${d['total'] ?? 0}', centerLabel: 'patients')),
                  const SizedBox(height: 8),
                  for (final s in riskSegs) HcLegendRow(label: s.label, value: s.value, color: s.color),
                ]),
        ),
        HcPanel(
          title: 'Gender distribution',
          icon: Icons.wc_rounded,
          color: hcPurple,
          child: gTotal == 0
              ? const HcEmptyState(icon: Icons.wc_rounded, title: 'No data')
              : Column(children: [
                  for (final g in genderEntries)
                    HcProgressBarRow(
                      label: g.$1,
                      value: gender[g.$2] ?? 0,
                      pct: (((gender[g.$2] ?? 0) as num) / gSafeTotal * 100).round(),
                      color: g.$4,
                      icon: g.$3,
                    ),
                ]),
        ),
        HcPanel(
          title: 'Age groups',
          icon: Icons.cake_rounded,
          color: hcBlue,
          child: ageValues.isEmpty
              ? const HcEmptyState(icon: Icons.cake_rounded, title: 'No age data')
              : HcBarChart(groups: ageValues.map((v) => [v]).toList(), labels: ageLabels, colors: [hcBlue], height: 200),
        ),
        HcPanel(
          title: 'Enrolment trend (${rangeLabel(_enrolmentRange)})',
          subtitle: 'New patients enrolled per day',
          icon: Icons.person_add_rounded,
          color: hcGreen,
          action: HcRangeSelector(value: _enrolmentRange, onChanged: (v) { setState(() => _enrolmentRange = v); _loadChart(v); }),
          child: enrolVals.isEmpty
              ? const HcEmptyState(icon: Icons.person_add_rounded, title: 'No enrolment data')
              : Column(children: [
                  HcBarChart(groups: enrolVals.map((v) => [v]).toList(), labels: enrolLabels, colors: [hcGreen], height: 200, scrollable: true),
                  const SizedBox(height: 8),
                  HcStatusChip(label: '$enrolTotal enrolled', color: hcGreen),
                ]),
        ),
        HcPanel(
          title: 'Top diagnoses',
          subtitle: 'Most common primary diagnoses',
          icon: Icons.medical_information_rounded,
          color: hcPurple,
          child: topDiag.isEmpty
              ? const HcEmptyState(icon: Icons.medical_information_rounded, title: 'No diagnoses data')
              : Column(children: [
                  for (var i = 0; i < topDiag.length; i++)
                    HcRankTile(
                      rank: i + 1,
                      title: (topDiag[i]['name'] ?? '—').toString(),
                      subtitle: '${topDiag[i]['count'] ?? 0} patients',
                      rankColor: hcPurple,
                      trailing: HcStatusChip(label: '${topDiag[i]['count'] ?? 0}', color: hcPurple),
                    ),
                ]),
        ),
        HcPanel(
          title: 'Patient analysis',
          subtitle: 'Per-patient breakdown',
          icon: Icons.people_outline_rounded,
          color: hcTeal,
          action: SizedBox(width: 160, child: HcSearchField(hintText: 'Search…', onChanged: (v) => setState(() => _search = v.toLowerCase()))),
          child: filteredPatients.isEmpty
              ? const HcEmptyState(icon: Icons.people_outline_rounded, title: 'No patients found')
              : HcPaginatedTable(
                  headers: ['#', 'Patient', 'MRN', 'Gender', 'Age', 'Risk', 'Diagnosis', 'Caregiver', 'Status'],
                  rows: [
                    for (var i = 0; i < filteredPatients.length; i++)
                      [
                        Text('${i + 1}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        Text((filteredPatients[i]['name'] ?? '—').toString(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                        Text((filteredPatients[i]['mrn'] ?? '—').toString(), style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        Text(hcLabel(filteredPatients[i]['gender']?.toString())),
                        Text('${filteredPatients[i]['age'] ?? '—'}', style: const TextStyle(fontSize: 11.5)),
                        HcStatusChip(label: hcLabel(filteredPatients[i]['risk_level']?.toString()), color: hcRiskColor(filteredPatients[i]['risk_level']?.toString())),
                        SizedBox(width: 120, child: Text((filteredPatients[i]['primary_diagnosis'] ?? '—').toString(), style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 80, child: Text((filteredPatients[i]['assigned_caregiver'] ?? 'Unassigned').toString(), style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        HcStatusChip(label: filteredPatients[i]['is_active'] == true ? 'Active' : 'Discharged', color: filteredPatients[i]['is_active'] == true ? hcGreen : hcSlate),
                      ],
                  ],
                ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────
//  PAGE 3 — Workforce / Caregiver Analytics
// ───────────────────────────────────────────────────────────────
class HcAnalyticsCaregiversScreen extends ConsumerStatefulWidget {
  const HcAnalyticsCaregiversScreen({super.key});
  @override
  ConsumerState<HcAnalyticsCaregiversScreen> createState() =>
      _HcAnalyticsCaregiversScreenState();
}

class _HcAnalyticsCaregiversScreenState
    extends ConsumerState<HcAnalyticsCaregiversScreen> {
  Map<String, dynamic> _data = {};
  bool _loading = false;
  String _leadersRange = '30d';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioProvider).get(
        '/homecare/analytics/workforce/',
        queryParameters: {'range': '30d'},
      );
      _data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      _leadersRange = '30d';
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadChart(String range) async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioProvider).get(
        '/homecare/analytics/workforce/',
        queryParameters: {'range': range},
      );
      final d = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      if (d.containsKey('visit_leaders')) _data['visit_leaders'] = d['visit_leaders'];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final byCat = (d['by_category'] as Map?)?.cast<String, dynamic>() ?? {};
    final byStatus = (d['by_status'] as Map?)?.cast<String, dynamic>() ?? {};
    final topCg = (d['top_caregivers'] as List?)?.cast<Map>() ?? [];
    final leaders = (d['visit_leaders'] as List?)?.cast<Map>() ?? [];
    final total = d['total'] ?? 0;
    final available = d['available'] ?? 0;
    final availPct = total > 0 ? ((available as num) / total * 100).round() : 0;

    final catSegs = <({String label, num value, Color color})>[
      (label: 'Nurse', value: byCat['nurse'] ?? 0, color: hcTeal),
      (label: 'Health Care Assistant', value: byCat['hca'] ?? 0, color: hcBlue),
    ];

    final statusEntries = [
      ('Active', 'active', Icons.check_circle_rounded, hcGreen),
      ('On Leave', 'on_leave', Icons.calendar_view_week_rounded, hcAmber),
      ('Suspended', 'suspended', Icons.cancel_rounded, hcRed),
      ('Terminated', 'terminated', Icons.person_remove_rounded, hcSlate),
    ];
    final sTotal = byStatus.values.fold<num>(0, (a, b) => a + (b as num));
    final sSafeTotal = sTotal > 0 ? sTotal : 1;

    final maxVisits = leaders.isNotEmpty ? leaders.map((l) => (l['visits'] as num?) ?? 0).reduce((a, b) => a > b ? a : b) : 1;
    final maxSafe = maxVisits > 0 ? maxVisits : 1;

    final leaderColors = [hcAmber, hcPurple, hcTeal, hcBlue, const Color(0xFFEC4899), hcIndigo, hcGreen, const Color(0xFF06B6D4), const Color(0xFFF97316), const Color(0xFF7C3AED)];

    final kpis = <({String label, String value, IconData icon, Color color, String? hint})>[
      (label: 'Total Caregivers', value: '${d['total'] ?? 0}', icon: Icons.volunteer_activism_rounded, color: hcIndigo, hint: null),
      (label: 'Active', value: '${d['active'] ?? 0}', icon: Icons.check_circle_rounded, color: hcGreen, hint: '${d['on_leave'] ?? 0} on leave'),
      (label: 'On Duty Now', value: '${d['on_duty'] ?? 0}', icon: Icons.login_rounded, color: hcBlue, hint: '${d['available'] ?? 0} available'),
      (label: 'Avg Rating', value: '${d['avg_rating'] ?? 0}', icon: Icons.star_rounded, color: hcAmber, hint: '${d['total_visits'] ?? 0} total visits'),
    ];

    return HcAnalyticsPage(
      currentPath: '/homecare/analytics/caregivers',
      title: 'Workforce Analytics',
      subtitle: 'Caregiver composition, availability & performance',
      heroIcon: Icons.volunteer_activism_rounded,
      heroGradient: const [Color(0xFF4F46E5), Color(0xFF6366F1), Color(0xFF818CF8)],
      heroChips: [
        HcHeroChip(icon: Icons.people_rounded, label: '${d['total'] ?? 0} caregivers'),
        HcHeroChip(icon: Icons.check_circle_rounded, label: '${d['active'] ?? 0} active'),
        HcHeroChip(icon: Icons.star_rounded, label: '${d['avg_rating'] ?? 0} avg rating'),
        HcHeroChip(icon: Icons.login_rounded, label: '${d['on_duty'] ?? 0} on duty'),
      ],
      loading: _loading,
      onRefresh: _load,
      body: [
        const SizedBox(height: 8),
        HcKpiGrid(items: kpis),
        const SizedBox(height: 8),
        HcPanel(
          title: 'By category',
          subtitle: 'Nurse vs Health Care Assistant',
          icon: Icons.badge_rounded,
          color: hcIndigo,
          child: catSegs.every((s) => s.value == 0)
              ? const HcEmptyState(icon: Icons.badge_rounded, title: 'No data')
              : Column(children: [
                  Center(child: HcDonutRing(segments: catSegs, centerValue: '$total', centerLabel: 'staff')),
                  const SizedBox(height: 8),
                  for (final s in catSegs) HcLegendRow(label: s.label, value: s.value, color: s.color),
                ]),
        ),
        HcPanel(
          title: 'Employment status',
          icon: Icons.work_rounded,
          color: hcGreen,
          child: sTotal == 0
              ? const HcEmptyState(icon: Icons.work_rounded, title: 'No data')
              : Column(children: [
                  for (final s in statusEntries)
                    HcProgressBarRow(label: s.$1, value: byStatus[s.$2] ?? 0, pct: (((byStatus[s.$2] ?? 0) as num) / sSafeTotal * 100).round(), color: s.$4, icon: s.$3),
                ]),
        ),
        HcPanel(
          title: 'Availability',
          icon: Icons.event_available_rounded,
          color: hcBlue,
          child: Column(children: [
            Center(child: Column(children: [
              Text('$available', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: hcTeal)),
              Text('available caregivers', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ])),
            const SizedBox(height: 10),
            ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: availPct / 100, minHeight: 8, color: hcTeal)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('$available available', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Text('${(total as num).toInt() - available.toInt()} unavailable', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ]),
        ),
        HcPanel(
          title: 'Top caregivers by visits',
          subtitle: 'All-time visit leaders',
          icon: Icons.emoji_events_rounded,
          color: hcAmber,
          child: topCg.isEmpty
              ? const HcEmptyState(icon: Icons.emoji_events_outlined, title: 'No data yet')
              : Column(children: [
                  for (var i = 0; i < topCg.length; i++)
                    HcRankTile(
                      rank: i + 1,
                      title: (topCg[i]['name'] ?? '—').toString(),
                      subtitle: hcCategoryLabel(topCg[i]['category']?.toString()),
                      rankColor: hcAmber,
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.star_rounded, size: 14, color: hcAmber),
                        const SizedBox(width: 2),
                        Text('${topCg[i]['rating'] ?? 0}', style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 10),
                        Text('${topCg[i]['total_visits'] ?? 0}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                ]),
        ),
        HcPanel(
          title: 'Visit leaders (${rangeLabel(_leadersRange)})',
          subtitle: 'Most visits in selected period',
          icon: Icons.military_tech_rounded,
          color: hcPurple,
          action: HcRangeSelector(value: _leadersRange, onChanged: (v) { setState(() => _leadersRange = v); _loadChart(v); }),
          child: leaders.isEmpty
              ? const HcEmptyState(icon: Icons.military_tech_outlined, title: 'No visits recorded')
              : Column(children: [
                  for (var i = 0; i < leaders.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Container(width: 36, height: 36, decoration: BoxDecoration(color: leaderColors[i % leaderColors.length].withValues(alpha: 0.14), shape: BoxShape.circle), alignment: Alignment.center, child: Text('${i + 1}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: leaderColors[i % leaderColors.length]))),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text((leaders[i]['name'] ?? '—').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                          Text('${leaders[i]['visits'] ?? 0} visits completed', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ])),
                        SizedBox(width: 60, child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: ((leaders[i]['visits'] as num?) ?? 0) / maxSafe, minHeight: 6, color: hcPurple))),
                        const SizedBox(width: 8),
                        Text('${leaders[i]['visits'] ?? 0}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                ]),
        ),
      ],
    );
  }
}
