import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api.dart';
import '../hc_common.dart';
import 'hc_analytics_common.dart';

// ═════════════════════════════════════════════════════════════════
//  Pages 4–6: Visits · Adherence · Escalations
// ═════════════════════════════════════════════════════════════════

// ───────────────────────────────────────────────────────────────
//  PAGE 4 — Visit Analytics
// ───────────────────────────────────────────────────────────────
class HcAnalyticsVisitsScreen extends ConsumerStatefulWidget {
  const HcAnalyticsVisitsScreen({super.key});
  @override
  ConsumerState<HcAnalyticsVisitsScreen> createState() =>
      _HcAnalyticsVisitsScreenState();
}

class _HcAnalyticsVisitsScreenState
    extends ConsumerState<HcAnalyticsVisitsScreen> {
  Map<String, dynamic> _data = {};
  bool _loading = false;
  String _trendRange = '30d';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref
          .read(dioProvider)
          .get('/homecare/analytics/visits/', queryParameters: {'range': '30d'});
      _data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      _trendRange = '30d';
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadChart(String range) async {
    setState(() => _loading = true);
    try {
      final res = await ref
          .read(dioProvider)
          .get('/homecare/analytics/visits/', queryParameters: {'range': range});
      final d = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      if (d.containsKey('trend')) _data['trend'] = d['trend'];
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
    final trend = (d['trend'] as List?)?.cast<Map>() ?? [];
    final byStatus = (d['by_status'] as Map?)?.cast<String, dynamic>() ?? {};
    final byShift = (d['by_shift_type'] as Map?)?.cast<String, dynamic>() ?? {};

    final trendGroups = trend
        .map((e) => [(e['completed'] as num?) ?? 0, (e['missed'] as num?) ?? 0])
        .toList();
    final trendLabels =
        trend.map((e) => (e['date'] ?? '').toString().substring(5)).toList();

    final statusSegs = <({String label, num value, Color color})>[
      (label: 'Scheduled', value: byStatus['scheduled'] ?? 0, color: hcBlue),
      (label: 'Checked In', value: byStatus['checked_in'] ?? 0, color: hcTeal),
      (label: 'Completed', value: byStatus['completed'] ?? 0, color: hcGreen),
      (label: 'Missed', value: byStatus['missed'] ?? 0, color: hcRed),
      (label: 'Cancelled', value: byStatus['cancelled'] ?? 0, color: hcSlate),
    ];

    final shiftEntries = [
      ('Single Visit', 'visit', Icons.directions_walk_rounded, hcTeal),
      ('Live-in', 'live_in', Icons.home_rounded, hcPurple),
      ('On Call', 'on_call', Icons.phone_in_talk_rounded, hcAmber),
    ];
    final sTotal = byShift.values.fold<num>(0, (a, b) => a + (b as num));
    final sSafeTotal = sTotal > 0 ? sTotal : 1;

    final kpis =
        <({String label, String value, IconData icon, Color color, String? hint})>[
      (label: 'Visits (30d)', value: '${d['total_30d'] ?? 0}', icon: Icons.event_note_rounded, color: hcPurple, hint: null),
      (label: 'Completion Rate', value: '${d['completion_rate'] ?? 0}%', icon: Icons.check_circle_rounded, color: hcGreen, hint: '${d['completed'] ?? 0} completed'),
      (label: 'Miss Rate', value: '${d['miss_rate'] ?? 0}%', icon: Icons.cancel_rounded, color: hcRed, hint: '${d['missed'] ?? 0} missed'),
      (label: 'Avg Duration', value: '${d['avg_duration_hours'] ?? 0}h', icon: Icons.timer_rounded, color: hcBlue, hint: '${d['reassignments'] ?? 0} reassignments'),
    ];

    return HcAnalyticsPage(
      currentPath: '/homecare/analytics/visits',
      title: 'Visit Analytics',
      subtitle: 'Schedule completion, miss rates & shift breakdown',
      heroIcon: Icons.event_note_rounded,
      heroGradient: const [Color(0xFF7C3AED), Color(0xFF8B5CF6), Color(0xFFA78BFA)],
      heroChips: [
        HcHeroChip(icon: Icons.event_note_rounded, label: '${d['total_30d'] ?? 0} visits (30d)'),
        HcHeroChip(icon: Icons.check_circle_rounded, label: '${d['completion_rate'] ?? 0}% complete'),
        HcHeroChip(icon: Icons.cancel_rounded, label: '${d['miss_rate'] ?? 0}% miss'),
        HcHeroChip(icon: Icons.timer_rounded, label: '${d['avg_duration_hours'] ?? 0}h avg'),
      ],
      loading: _loading,
      onRefresh: _load,
      body: [
        const SizedBox(height: 8),
        HcKpiGrid(items: kpis),
        const SizedBox(height: 8),
        HcPanel(
          title: '${rangeLabel(_trendRange)} visit trend',
          subtitle: 'Completed vs missed per day',
          icon: Icons.bar_chart_rounded,
          color: hcPurple,
          action: HcRangeSelector(
              value: _trendRange,
              onChanged: (v) {
                setState(() => _trendRange = v);
                _loadChart(v);
              }),
          child: trendGroups.isEmpty
              ? const HcEmptyState(icon: Icons.bar_chart_rounded, title: 'No visit data')
              : Column(children: [
                  HcBarChart(groups: trendGroups, labels: trendLabels, colors: [hcGreen, hcRed], height: 220, scrollable: true),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _LegendDot(color: hcGreen, label: 'Completed'),
                    const SizedBox(width: 16),
                    _LegendDot(color: hcRed, label: 'Missed'),
                  ]),
                ]),
        ),
        HcPanel(
          title: 'Visit status',
          icon: Icons.assignment_rounded,
          color: hcIndigo,
          child: statusSegs.every((s) => s.value == 0)
              ? const HcEmptyState(icon: Icons.assignment_rounded, title: 'No status data')
              : Column(children: [
                  Center(child: HcDonutRing(segments: statusSegs, centerValue: '${d['total_30d'] ?? 0}', centerLabel: 'visits')),
                  const SizedBox(height: 8),
                  for (final s in statusSegs) HcLegendRow(label: s.label, value: s.value, color: s.color),
                ]),
        ),
        HcPanel(
          title: 'Shift types',
          subtitle: 'Distribution by shift type',
          icon: Icons.swap_horiz_rounded,
          color: hcBlue,
          child: sTotal == 0
              ? const HcEmptyState(icon: Icons.swap_horiz_rounded, title: 'No data')
              : Column(children: [
                  for (final s in shiftEntries)
                    HcProgressBarRow(
                      label: s.$1,
                      value: byShift[s.$2] ?? 0,
                      pct: (((byShift[s.$2] ?? 0) as num) / sSafeTotal * 100).round(),
                      color: s.$4,
                      icon: s.$3,
                    ),
                ]),
        ),
        HcPanel(
          title: 'Visit summary',
          icon: Icons.fact_check_rounded,
          color: hcGreen,
          child: Column(children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                HcStatTile(label: 'Completed', value: '${d['completed'] ?? 0}', color: hcGreen),
                HcStatTile(label: 'Missed', value: '${d['missed'] ?? 0}', color: hcRed),
                HcStatTile(label: 'Cancelled', value: '${d['cancelled'] ?? 0}', color: hcAmber),
                HcStatTile(label: 'Reassigned', value: '${d['reassignments'] ?? 0}', color: hcBlue),
              ],
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Average visit duration', style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              HcStatusChip(label: '${d['avg_duration_hours'] ?? 0} hours', color: hcBlue, icon: Icons.timer_rounded),
            ]),
          ]),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────
//  PAGE 5 — Adherence Analytics
// ───────────────────────────────────────────────────────────────
class HcAnalyticsAdherenceScreen extends ConsumerStatefulWidget {
  const HcAnalyticsAdherenceScreen({super.key});
  @override
  ConsumerState<HcAnalyticsAdherenceScreen> createState() =>
      _HcAnalyticsAdherenceScreenState();
}

class _HcAnalyticsAdherenceScreenState
    extends ConsumerState<HcAnalyticsAdherenceScreen> {
  Map<String, dynamic> _data = {};
  bool _loading = false;
  String _trendRange = '30d';
  String _doseRange = '30d';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref
          .read(dioProvider)
          .get('/homecare/analytics/adherence/', queryParameters: {'range': '30d'});
      _data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      _trendRange = _doseRange = '30d';
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadChart(String chart, String range) async {
    setState(() => _loading = true);
    try {
      final res = await ref
          .read(dioProvider)
          .get('/homecare/analytics/adherence/', queryParameters: {'range': range});
      final d = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      if (chart == 'trend' && d.containsKey('trend')) _data['trend'] = d['trend'];
      if (chart == 'dose' && d.containsKey('breakdown')) _data['breakdown'] = d['breakdown'];
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
    final breakdown = (d['breakdown'] as Map?)?.cast<String, dynamic>() ?? {};
    final trend = (d['trend'] as List?)?.cast<Map>() ?? [];
    final best = (d['best_patients'] as List?)?.cast<Map>() ?? [];
    final worst = (d['worst_patients'] as List?)?.cast<Map>() ?? [];

    final trendRates = trend.map((e) => (e['rate'] as num?) ?? 0).toList();
    final trendLabels = trend.map((e) => (e['date'] ?? '').toString().substring(5)).toList();
    final avg = trendRates.isNotEmpty ? trendRates.reduce((a, b) => a + b) ~/ trendRates.length : 0;
    final bestRate = trendRates.isNotEmpty ? trendRates.reduce((a, b) => a > b ? a : b) : 0;
    final worstRate = trendRates.isNotEmpty ? trendRates.reduce((a, b) => a < b ? a : b) : 0;

    final doseSegs = <({String label, num value, Color color})>[
      (label: 'Taken', value: breakdown['taken'] ?? 0, color: hcGreen),
      (label: 'Missed', value: breakdown['missed'] ?? 0, color: hcRed),
      (label: 'Skipped', value: breakdown['skipped'] ?? 0, color: hcAmber),
      (label: 'Refused', value: breakdown['refused'] ?? 0, color: hcSlate),
      (label: 'Not Given', value: breakdown['not_given'] ?? 0, color: const Color(0xFFEA580C)),
      (label: 'Pending', value: breakdown['pending'] ?? 0, color: hcBlue),
    ];

    Color rateColor(num rate) {
      if (rate >= 90) return hcGreen;
      if (rate >= 75) return hcAmber;
      if (rate >= 50) return const Color(0xFFEA580C);
      return hcRed;
    }

    final kpis =
        <({String label, String value, IconData icon, Color color, String? hint})>[
      (label: 'Adherence Rate (30d)', value: '${d['rate'] ?? 0}%', icon: Icons.percent_rounded, color: hcGreen, hint: null),
      (label: 'Doses (30d)', value: '${breakdown['total'] ?? 0}', icon: Icons.medication_rounded, color: hcTeal, hint: null),
      (label: 'Doses Taken', value: '${breakdown['taken'] ?? 0}', icon: Icons.check_circle_rounded, color: hcGreen, hint: null),
      (label: 'Doses Missed', value: '${breakdown['missed'] ?? 0}', icon: Icons.warning_amber_rounded, color: hcRed, hint: null),
    ];

    return HcAnalyticsPage(
      currentPath: '/homecare/analytics/adherence',
      title: 'Medication Adherence',
      subtitle: 'Dose-by-dose tracking, trends & per-patient performance',
      heroIcon: Icons.medication_rounded,
      heroGradient: const [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
      heroChips: [
        HcHeroChip(icon: Icons.percent_rounded, label: '${d['rate'] ?? 0}% adherence'),
        HcHeroChip(icon: Icons.medication_rounded, label: '${breakdown['total'] ?? 0} doses (30d)'),
        HcHeroChip(icon: Icons.people_alt_rounded, label: '${d['total_patients_tracked'] ?? 0} tracked'),
        HcHeroChip(icon: Icons.vaccines_rounded, label: '${d['caregiver_administered'] ?? 0} by caregiver'),
      ],
      loading: _loading,
      onRefresh: _load,
      body: [
        const SizedBox(height: 8),
        HcKpiGrid(items: kpis),
        const SizedBox(height: 8),
        HcPanel(
          title: '${rangeLabel(_trendRange)} adherence trend',
          subtitle: 'Daily adherence %',
          icon: Icons.show_chart_rounded,
          color: hcGreen,
          action: HcRangeSelector(
              value: _trendRange,
              onChanged: (v) {
                setState(() => _trendRange = v);
                _loadChart('trend', v);
              }),
          child: trendRates.isEmpty
              ? const HcEmptyState(icon: Icons.show_chart_rounded, title: 'No trend data')
              : Column(children: [
                  HcLineChart(series: [(label: 'Adherence %', color: hcGreen, values: trendRates)], labels: trendLabels, height: 220, minY: 0, maxY: 100, yFormatter: (v) => '${v.round()}%', scrollable: true),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    HcStatusChip(label: 'Avg: $avg%', color: hcTeal),
                    HcStatusChip(label: 'Best: $bestRate%', color: hcGreen),
                    HcStatusChip(label: 'Worst: $worstRate%', color: hcRed),
                  ]),
                ]),
        ),
        HcPanel(
          title: 'Dose outcomes (${rangeLabel(_doseRange)})',
          subtitle: 'All doses',
          icon: Icons.medication_rounded,
          color: hcTeal,
          action: HcRangeSelector(
              value: _doseRange,
              onChanged: (v) {
                setState(() => _doseRange = v);
                _loadChart('dose', v);
              }),
          child: doseSegs.every((s) => s.value == 0)
              ? const HcEmptyState(icon: Icons.medication_rounded, title: 'No dose data')
              : Column(children: [
                  Center(child: HcDonutRing(segments: doseSegs, size: 170, centerValue: '${d['rate'] ?? 0}%', centerLabel: 'adherence')),
                  const SizedBox(height: 8),
                  for (final s in doseSegs) HcLegendRow(label: s.label, value: s.value, color: s.color),
                ]),
        ),
        HcPanel(
          title: 'Best adherers',
          subtitle: 'Top adherence (min 5 doses)',
          icon: Icons.emoji_events_rounded,
          color: hcGreen,
          child: best.isEmpty
              ? const HcEmptyState(icon: Icons.emoji_events_outlined, title: 'No data')
              : Column(children: [
                  for (var i = 0; i < best.length; i++)
                    HcRankTile(
                      rank: i + 1,
                      title: (best[i]['name'] ?? '—').toString(),
                      subtitle: '${best[i]['total'] ?? 0} doses',
                      rankColor: hcGreen,
                      trailing: HcStatusChip(label: '${best[i]['rate'] ?? 0}%', color: rateColor((best[i]['rate'] as num?) ?? 0)),
                    ),
                ]),
        ),
        HcPanel(
          title: 'Needs attention',
          subtitle: 'Lowest adherence (min 5 doses)',
          icon: Icons.warning_amber_rounded,
          color: hcRed,
          child: worst.isEmpty
              ? const HcEmptyState(icon: Icons.check_circle_rounded, title: 'All on track')
              : Column(children: [
                  for (var i = 0; i < worst.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        const Icon(Icons.warning_amber_rounded, size: 18, color: hcRed),
                        const SizedBox(width: 8),
                        Expanded(child: Text((worst[i]['name'] ?? '—').toString(), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                        Text('${worst[i]['total'] ?? 0}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        const SizedBox(width: 8),
                        Text('${((worst[i]['total'] ?? 0) as num) - ((worst[i]['taken'] ?? 0) as num)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: hcRed)),
                        const SizedBox(width: 8),
                        HcStatusChip(label: '${worst[i]['rate'] ?? 0}%', color: rateColor((worst[i]['rate'] as num?) ?? 0)),
                      ]),
                    ),
                ]),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────
//  PAGE 6 — Escalation Analytics
// ───────────────────────────────────────────────────────────────
class HcAnalyticsEscalationsScreen extends ConsumerStatefulWidget {
  const HcAnalyticsEscalationsScreen({super.key});
  @override
  ConsumerState<HcAnalyticsEscalationsScreen> createState() =>
      _HcAnalyticsEscalationsScreenState();
}

class _HcAnalyticsEscalationsScreenState
    extends ConsumerState<HcAnalyticsEscalationsScreen> {
  Map<String, dynamic> _data = {};
  bool _loading = false;
  String _severityRange = '30d';
  String _trendRange = '30d';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref
          .read(dioProvider)
          .get('/homecare/analytics/escalations/', queryParameters: {'range': '30d'});
      _data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      _severityRange = _trendRange = '30d';
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadChart(String chart, String range) async {
    setState(() => _loading = true);
    try {
      final res = await ref
          .read(dioProvider)
          .get('/homecare/analytics/escalations/', queryParameters: {'range': range});
      final d = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      if (chart == 'severity') {
        if (d.containsKey('by_severity')) _data['by_severity'] = d['by_severity'];
        if (d.containsKey('total_30d')) _data['total_30d'] = d['total_30d'];
      }
      if (chart == 'trend' && d.containsKey('trend')) _data['trend'] = d['trend'];
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
    final bySev = (d['by_severity'] as Map?)?.cast<String, dynamic>() ?? {};
    final byStatus = (d['by_status'] as Map?)?.cast<String, dynamic>() ?? {};
    final topReasons = (d['top_reasons'] as List?)?.cast<Map>() ?? [];
    final trend = (d['trend'] as List?)?.cast<Map>() ?? [];

    final sevSegs = <({String label, num value, Color color})>[
      (label: 'Low', value: bySev['low'] ?? 0, color: hcBlue),
      (label: 'Medium', value: bySev['medium'] ?? 0, color: hcAmber),
      (label: 'High', value: bySev['high'] ?? 0, color: hcRed),
      (label: 'Critical', value: bySev['critical'] ?? 0, color: const Color(0xFFEA580C)),
    ];

    final statusEntries = [
      ('Open', 'open', Icons.warning_amber_rounded, hcRed),
      ('Acknowledged', 'acknowledged', Icons.notifications_active_rounded, hcAmber),
      ('Resolved', 'resolved', Icons.check_circle_rounded, hcGreen),
    ];
    final sTotal = byStatus.values.fold<num>(0, (a, b) => a + (b as num));
    final sSafeTotal = sTotal > 0 ? sTotal : 1;

    final trendGroups =
        trend.map((e) => [(e['triggered'] as num?) ?? 0, (e['resolved'] as num?) ?? 0]).toList();
    final trendLabels =
        trend.map((e) => (e['date'] ?? '').toString().substring(5)).toList();

    final kpis =
        <({String label, String value, IconData icon, Color color, String? hint})>[
      (label: 'Open Escalations', value: '${d['open'] ?? 0}', icon: Icons.warning_amber_rounded, color: hcRed, hint: null),
      (label: 'Acknowledged', value: '${d['acknowledged'] ?? 0}', icon: Icons.notifications_active_rounded, color: hcAmber, hint: null),
      (label: 'Total (30d)', value: '${d['total_30d'] ?? 0}', icon: Icons.stacked_bar_chart_rounded, color: hcPurple, hint: null),
      (label: 'Avg Resolution', value: '${d['avg_resolution_hours'] ?? 0}h', icon: Icons.timer_rounded, color: hcGreen, hint: null),
    ];

    return HcAnalyticsPage(
      currentPath: '/homecare/analytics/escalations',
      title: 'Escalation Analytics',
      subtitle: 'Alert severity, resolution times & recurring triggers',
      heroIcon: Icons.warning_amber_rounded,
      heroGradient: const [Color(0xFFDC2626), Color(0xFFEF4444), Color(0xFFF87171)],
      heroChips: [
        HcHeroChip(icon: Icons.warning_amber_rounded, label: '${d['open'] ?? 0} open'),
        HcHeroChip(icon: Icons.notifications_active_rounded, label: '${d['acknowledged'] ?? 0} acknowledged'),
        HcHeroChip(icon: Icons.stacked_bar_chart_rounded, label: '${d['total_30d'] ?? 0} in 30d'),
        HcHeroChip(icon: Icons.timer_rounded, label: '${d['avg_resolution_hours'] ?? 0}h avg resolve'),
      ],
      loading: _loading,
      onRefresh: _load,
      body: [
        const SizedBox(height: 8),
        HcKpiGrid(items: kpis),
        const SizedBox(height: 8),
        HcPanel(
          title: 'Severity distribution (${rangeLabel(_severityRange)})',
          subtitle: 'Escalations by severity',
          icon: Icons.warning_amber_rounded,
          color: hcRed,
          action: HcRangeSelector(
              value: _severityRange,
              onChanged: (v) {
                setState(() => _severityRange = v);
                _loadChart('severity', v);
              }),
          child: sevSegs.every((s) => s.value == 0)
              ? const HcEmptyState(icon: Icons.warning_amber_rounded, title: 'No severity data')
              : Column(children: [
                  Center(child: HcDonutRing(segments: sevSegs, centerValue: '${d['total_30d'] ?? 0}', centerLabel: 'alerts')),
                  const SizedBox(height: 8),
                  for (final s in sevSegs) HcLegendRow(label: s.label, value: s.value, color: s.color),
                ]),
        ),
        HcPanel(
          title: 'Status breakdown',
          icon: Icons.assignment_rounded,
          color: hcIndigo,
          child: sTotal == 0
              ? const HcEmptyState(icon: Icons.assignment_rounded, title: 'No status data')
              : Column(children: [
                  for (final s in statusEntries)
                    HcProgressBarRow(
                      label: s.$1,
                      value: byStatus[s.$2] ?? 0,
                      pct: (((byStatus[s.$2] ?? 0) as num) / sSafeTotal * 100).round(),
                      color: s.$4,
                      icon: s.$3,
                    ),
                ]),
        ),
        HcPanel(
          title: 'Top triggers',
          subtitle: 'Most common escalation reasons',
          icon: Icons.notification_important_rounded,
          color: const Color(0xFFF97316),
          child: topReasons.isEmpty
              ? const HcEmptyState(icon: Icons.notifications_off_rounded, title: 'No triggers')
              : Column(children: [
                  for (var i = 0; i < topReasons.length; i++)
                    HcRankTile(
                      rank: i + 1,
                      title: (topReasons[i]['reason'] ?? '—').toString(),
                      subtitle: '${topReasons[i]['count'] ?? 0} occurrences',
                      rankColor: const Color(0xFFF97316),
                      trailing: HcStatusChip(label: '${topReasons[i]['count'] ?? 0}', color: const Color(0xFFF97316)),
                    ),
                ]),
        ),
        HcPanel(
          title: 'Escalation trend (${rangeLabel(_trendRange)})',
          subtitle: 'Triggered vs resolved per day',
          icon: Icons.timeline_rounded,
          color: hcRed,
          action: HcRangeSelector(
              value: _trendRange,
              onChanged: (v) {
                setState(() => _trendRange = v);
                _loadChart('trend', v);
              }),
          child: trendGroups.isEmpty
              ? const HcEmptyState(icon: Icons.timeline_rounded, title: 'No trend data')
              : Column(children: [
                  HcBarChart(groups: trendGroups, labels: trendLabels, colors: [hcRed, hcGreen], height: 220, scrollable: true),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _LegendDot(color: hcRed, label: 'Triggered'),
                    const SizedBox(width: 16),
                    _LegendDot(color: hcGreen, label: 'Resolved'),
                  ]),
                ]),
        ),
      ],
    );
  }
}

// ── Shared legend dot ──
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12)),
    ]);
  }
}
