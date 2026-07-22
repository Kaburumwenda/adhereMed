import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/api.dart';
import '../hc_common.dart';
import 'hc_analytics_common.dart';

// ═════════════════════════════════════════════════════════════════
//  Pages 7–9: Financials · Insurance · Equipment
// ═════════════════════════════════════════════════════════════════

// ───────────────────────────────────────────────────────────────
//  PAGE 7 — Financial Analytics
// ───────────────────────────────────────────────────────────────
class HcAnalyticsFinancialsScreen extends ConsumerStatefulWidget {
  const HcAnalyticsFinancialsScreen({super.key});
  @override
  ConsumerState<HcAnalyticsFinancialsScreen> createState() =>
      _HcAnalyticsFinancialsScreenState();
}

class _HcAnalyticsFinancialsScreenState
    extends ConsumerState<HcAnalyticsFinancialsScreen> {
  Map<String, dynamic> _data = {};
  bool _loading = false;
  String _revenueRange = '30d';
  String _search = '';
  final Set<int> _expanded = {};

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref
          .read(dioProvider)
          .get('/homecare/analytics/financials/', queryParameters: {'range': '30d'});
      _data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      _revenueRange = '30d';
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadChart(String range) async {
    setState(() => _loading = true);
    try {
      final res = await ref
          .read(dioProvider)
          .get('/homecare/analytics/financials/', queryParameters: {'range': range});
      final d = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      if (d.containsKey('revenue_trend')) _data['revenue_trend'] = d['revenue_trend'];
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
    final cs = Theme.of(context).colorScheme;
    final revTrend = (d['revenue_trend'] as List?)?.cast<Map>() ?? [];
    final byStatus = (d['by_status'] as Map?)?.cast<String, dynamic>() ?? {};
    final byMethod = (d['by_method'] as Map?)?.cast<String, dynamic>() ?? {};
    final catTotals = (d['category_totals'] as Map?)?.cast<String, dynamic>() ?? {};
    final patientRev = (d['patient_revenue'] as List?)?.cast<Map>() ?? [];

    final collectedVals = revTrend.map((e) => (e['collected'] as num?) ?? 0).toList();
    final billedVals = revTrend.map((e) => (e['billed'] as num?) ?? 0).toList();
    final revLabels = revTrend.map((e) => (e['date'] ?? '').toString().substring(5)).toList();

    final statusSegs = <({String label, num value, Color color})>[
      (label: 'Draft', value: byStatus['draft'] ?? 0, color: hcSlate),
      (label: 'Issued', value: byStatus['issued'] ?? 0, color: hcBlue),
      (label: 'Partial', value: byStatus['partial'] ?? 0, color: hcAmber),
      (label: 'Paid', value: byStatus['paid'] ?? 0, color: hcGreen),
      (label: 'Void', value: byStatus['void'] ?? 0, color: hcRed),
    ];
    final billTotal = byStatus.values.fold<num>(0, (a, b) => a + (b as num));

    final methodEntries = [
      ('Cash', 'cash', Icons.payments_rounded, hcGreen),
      ('M-Pesa', 'mpesa', Icons.phone_iphone_rounded, hcTeal),
      ('Card', 'card', Icons.credit_card_rounded, hcBlue),
      ('Bank', 'bank', Icons.account_balance_rounded, hcIndigo),
      ('Insurance', 'insurance', Icons.shield_rounded, const Color(0xFFF97316)),
      ('Other', 'other', Icons.more_horiz_rounded, hcSlate),
    ];
    final methodMax = byMethod.values.fold<num>(0, (a, v) {
      final m = (v as Map?)?.cast<String, dynamic>() ?? {};
      final t = (m['total'] as num?) ?? 0;
      return a > t ? a : t;
    });
    final methodSafeMax = methodMax > 0 ? methodMax : 1;

    final catLabels = ['Care', 'Equipment', 'Supplies', 'Medication'];
    final catValues = <num>[catTotals['care'] ?? 0, catTotals['equipment'] ?? 0, catTotals['supplies'] ?? 0, catTotals['medication'] ?? 0];
    final catColors = [hcTeal, const Color(0xFF06B6D4), hcPurple, hcGreen];

    final filteredRev = _search.isEmpty
        ? patientRev
        : patientRev.where((p) =>
            (p['name'] ?? '').toString().toLowerCase().contains(_search) ||
            (p['mrn'] ?? '').toString().toLowerCase().contains(_search)).toList();

    Color billStatusColor(String? s) => switch (s) {
          'draft' => hcSlate,
          'issued' => hcBlue,
          'partial' => hcAmber,
          'paid' => hcGreen,
          'void' => hcRed,
          _ => hcSlate,
        };

    String methodLabel(String m) => switch (m) {
          'cash' => 'Cash',
          'mpesa' => 'M-Pesa',
          'card' => 'Card',
          'bank' => 'Bank',
          'insurance' => 'Insurance',
          _ => m,
        };
    Color methodColor(String m) => switch (m) {
          'cash' => hcGreen,
          'mpesa' => hcTeal,
          'card' => hcBlue,
          'bank' => hcIndigo,
          'insurance' => const Color(0xFFF97316),
          _ => hcSlate,
        };

    final kpis = <({String label, String value, IconData icon, Color color, String? hint})>[
      (label: 'Total Billed', value: hcMoney(d['total_billed']), icon: Icons.receipt_long_rounded, color: hcTeal, hint: null),
      (label: 'Total Collected', value: hcMoney(d['total_collected']), icon: Icons.payments_rounded, color: hcGreen, hint: null),
      (label: 'Outstanding', value: hcMoney(d['outstanding']), icon: Icons.pending_rounded, color: hcRed, hint: null),
      (label: 'Collection Rate', value: '${d['collection_rate'] ?? 0}%', icon: Icons.percent_rounded, color: hcAmber, hint: null),
    ];

    return HcAnalyticsPage(
      currentPath: '/homecare/analytics/financials',
      title: 'Financial Analytics',
      subtitle: 'Revenue, outstanding balances & payment methods',
      heroIcon: Icons.payments_rounded,
      heroGradient: const [Color(0xFFB45309), Color(0xFFF59E0B), Color(0xFFFBBF24)],
      heroChips: [
        HcHeroChip(icon: Icons.payments_rounded, label: hcMoney(d['total_collected'])),
        HcHeroChip(icon: Icons.pending_rounded, label: hcMoney(d['outstanding'])),
        HcHeroChip(icon: Icons.percent_rounded, label: '${d['collection_rate'] ?? 0}% collection'),
        HcHeroChip(icon: Icons.trending_up_rounded, label: hcMoney(d['monthly_revenue'])),
      ],
      loading: _loading,
      onRefresh: _load,
      body: [
        const SizedBox(height: 8),
        HcKpiGrid(items: kpis),
        const SizedBox(height: 8),
        HcPanel(
          title: 'Revenue trend (${rangeLabel(_revenueRange)})',
          subtitle: 'Daily billed vs collected',
          icon: Icons.area_chart_rounded,
          color: hcAmber,
          action: HcRangeSelector(
              value: _revenueRange,
              onChanged: (v) {
                setState(() => _revenueRange = v);
                _loadChart(v);
              }),
          child: collectedVals.isEmpty
              ? const HcEmptyState(icon: Icons.area_chart_rounded, title: 'No revenue data')
              : HcLineChart(
                  series: [
                    (label: 'Collected', color: hcGreen, values: collectedVals),
                    (label: 'Billed', color: hcAmber, values: billedVals),
                  ],
                  labels: revLabels,
                  height: 240,
                  scrollable: true,
                  yFormatter: (v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.round().toString(),
                ),
        ),
        HcPanel(
          title: 'Bill status',
          subtitle: 'Bills by status',
          icon: Icons.assignment_rounded,
          color: hcIndigo,
          child: statusSegs.every((s) => s.value == 0)
              ? const HcEmptyState(icon: Icons.assignment_rounded, title: 'No bill data')
              : Column(children: [
                  Center(child: HcDonutRing(segments: statusSegs, centerValue: '$billTotal', centerLabel: 'bills')),
                  const SizedBox(height: 8),
                  for (final s in statusSegs) HcLegendRow(label: s.label, value: s.value, color: s.color),
                ]),
        ),
        HcPanel(
          title: 'Payment methods',
          subtitle: 'Revenue by payment method',
          icon: Icons.credit_card_rounded,
          color: hcBlue,
          child: Column(children: [
            for (final m in methodEntries)
              ..._buildMethodBar(m, byMethod, methodSafeMax, cs),
            if (byMethod.values.every((v) => ((v as Map?)?['count'] ?? 0) == 0))
              const HcEmptyState(icon: Icons.credit_card_off_rounded, title: 'No payments yet'),
          ]),
        ),
        HcPanel(
          title: 'Billing categories',
          subtitle: 'Revenue by charge type',
          icon: Icons.category_rounded,
          color: hcPurple,
          child: catValues.every((v) => v == 0)
              ? const HcEmptyState(icon: Icons.category_rounded, title: 'No category data')
              : HcBarChart(groups: catValues.map((v) => [v]).toList(), labels: catLabels, colors: catColors, height: 220),
        ),
        HcPanel(
          title: 'Revenue analysis',
          subtitle: 'Per-patient billed, collected & overdue',
          icon: Icons.account_balance_wallet_rounded,
          color: hcTeal,
          action: SizedBox(width: 160, child: HcSearchField(hintText: 'Search…', onChanged: (v) => setState(() => _search = v.toLowerCase()))),
          child: filteredRev.isEmpty
              ? const HcEmptyState(icon: Icons.account_balance_wallet_rounded, title: 'No patient revenue data')
              : Column(children: [
                  for (var i = 0; i < filteredRev.length; i++)
                    _buildRevRow(filteredRev[i], i, cs, billStatusColor, methodLabel, methodColor),
                ]),
        ),
      ],
    );
  }

  List<Widget> _buildMethodBar(
      (String, String, IconData, Color) m, Map byMethod, num maxVal, ColorScheme cs) {
    final v = (byMethod[m.$2] as Map?)?.cast<String, dynamic>() ?? {};
    final count = (v['count'] as num?) ?? 0;
    if (count == 0) return [];
    final total = (v['total'] as num?) ?? 0;
    final pct = (total / maxVal * 100).round();
    return [
      HcProgressBarRow(label: m.$1, value: count, pct: pct, color: m.$4, icon: m.$3, trailing: hcMoney(total)),
    ];
  }

  Widget _buildRevRow(
      Map p, int idx, ColorScheme cs, Color Function(String?) billStatusColor, String Function(String) methodLabel, Color Function(String) methodColor) {
    final id = p['id'] as int? ?? idx;
    final isExp = _expanded.contains(id);
    final bills = (p['bills'] as List?)?.cast<Map>() ?? [];
    return Column(children: [
      InkWell(
        onTap: () => setState(() {
          if (_expanded.contains(id)) {
            _expanded.remove(id);
          } else {
            _expanded.add(id);
          }
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Icon(isExp ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text('${idx + 1}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            const SizedBox(width: 8),
            Expanded(child: Text((p['name'] ?? '—').toString(), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text('${p['bill_count'] ?? 0}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            const SizedBox(width: 8),
            SizedBox(width: 70, child: Text(hcMoney(p['total_billed']), textAlign: TextAlign.end, style: const TextStyle(fontSize: 11))),
            const SizedBox(width: 8),
            SizedBox(width: 70, child: Text(hcMoney(p['amount_paid']), textAlign: TextAlign.end, style: TextStyle(fontSize: 11, color: hcGreen))),
            const SizedBox(width: 8),
            SizedBox(width: 70, child: Text(hcMoney(p['outstanding']), textAlign: TextAlign.end, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ((p['outstanding'] as num?) ?? 0) > 0 ? hcRed : cs.onSurfaceVariant))),
            const SizedBox(width: 8),
            if ((p['overdue_count'] ?? 0) != 0)
              HcStatusChip(label: '${p['overdue_count']}', color: hcRed)
            else
              Text('—', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ]),
        ),
      ),
      if (isExp)
        Container(
          margin: const EdgeInsets.only(left: 32, bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: hcTeal.withValues(alpha: 0.04),
              border: Border(left: BorderSide(width: 3, color: hcTeal)),
              borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${bills.length} bill(s) for ${p['name'] ?? '—'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final b in bills)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(width: 80, child: Text((b['bill_number'] ?? '—').toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                  SizedBox(width: 60, child: Text(hcMoney(b['total']), textAlign: TextAlign.end, style: const TextStyle(fontSize: 11))),
                  const SizedBox(width: 8),
                  SizedBox(width: 60, child: Text(hcMoney(b['amount_paid']), textAlign: TextAlign.end, style: TextStyle(fontSize: 11, color: hcGreen))),
                  const SizedBox(width: 8),
                  SizedBox(width: 60, child: Text(hcMoney(b['balance']), textAlign: TextAlign.end, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ((b['balance'] as num?) ?? 0) > 0 ? hcRed : cs.onSurfaceVariant))),
                  const SizedBox(width: 8),
                  HcStatusChip(label: hcLabel(b['status']?.toString()), color: billStatusColor(b['status']?.toString())),
                  const SizedBox(width: 8),
                  Expanded(child: Wrap(spacing: 4, runSpacing: 4, children: [
                    for (final pay in (b['payments'] as List?)?.cast<Map>() ?? [])
                      HcStatusChip(label: '${methodLabel((pay['method'] ?? '').toString())} · ${hcMoney(pay['amount'])}', color: methodColor((pay['method'] ?? '').toString())),
                  ])),
                ]),
              ),
            if (bills.isEmpty) Text('No bills', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ]),
        ),
    ]);
  }
}

// ───────────────────────────────────────────────────────────────
//  PAGE 8 — Insurance Claims Analytics
// ───────────────────────────────────────────────────────────────
class HcAnalyticsInsuranceScreen extends ConsumerStatefulWidget {
  const HcAnalyticsInsuranceScreen({super.key});
  @override
  ConsumerState<HcAnalyticsInsuranceScreen> createState() =>
      _HcAnalyticsInsuranceScreenState();
}

class _HcAnalyticsInsuranceScreenState
    extends ConsumerState<HcAnalyticsInsuranceScreen> {
  Map<String, dynamic> _data = {};
  bool _loading = false;
  String _trendRange = '30d';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref
          .read(dioProvider)
          .get('/homecare/analytics/insurance/', queryParameters: {'range': '30d'});
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
          .get('/homecare/analytics/insurance/', queryParameters: {'range': range});
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
    final byStatus = (d['by_status'] as Map?)?.cast<String, dynamic>() ?? {};
    final byType = (d['by_type'] as Map?)?.cast<String, dynamic>() ?? {};
    final trend = (d['trend'] as List?)?.cast<Map>() ?? [];

    final statusSegs = <({String label, num value, Color color})>[
      (label: 'Draft', value: byStatus['draft'] ?? 0, color: hcSlate),
      (label: 'Submitted', value: byStatus['submitted'] ?? 0, color: hcBlue),
      (label: 'Approved', value: byStatus['approved'] ?? 0, color: hcGreen),
      (label: 'Denied', value: byStatus['denied'] ?? 0, color: hcRed),
      (label: 'Partial', value: byStatus['partial'] ?? 0, color: hcAmber),
      (label: 'Paid', value: byStatus['paid'] ?? 0, color: hcTeal),
    ];

    final typeLabels = ['Visit', 'Medication', 'Teleconsult', 'Procedure', 'Other'];
    final typeValues = <num>[byType['visit'] ?? 0, byType['medication'] ?? 0, byType['teleconsult'] ?? 0, byType['procedure'] ?? 0, byType['other'] ?? 0];
    final typeColors = [hcTeal, hcGreen, hcBlue, hcPurple, hcSlate];

    final trendVals = trend.map((e) => (e['count'] as num?) ?? 0).toList();
    final trendLabels = trend.map((e) => (e['date'] ?? '').toString().substring(5)).toList();

    final kpis = <({String label, String value, IconData icon, Color color, String? hint})>[
      (label: 'Total Claims', value: '${d['total'] ?? 0}', icon: Icons.shield_rounded, color: const Color(0xFFF97316), hint: null),
      (label: 'Pending', value: '${d['pending_count'] ?? 0}', icon: Icons.pending_rounded, color: hcAmber, hint: hcMoney(d['pending_value'])),
      (label: 'Approval Rate', value: '${d['approval_rate'] ?? 0}%', icon: Icons.percent_rounded, color: hcGreen, hint: null),
      (label: 'Total Requested', value: hcMoney(d['total_requested']), icon: Icons.payments_rounded, color: hcTeal, hint: null),
    ];

    return HcAnalyticsPage(
      currentPath: '/homecare/analytics/insurance',
      title: 'Insurance Claims',
      subtitle: 'Claim volumes, approval rates & pending value',
      heroIcon: Icons.shield_rounded,
      heroGradient: const [Color(0xFFC2410C), Color(0xFFF97316), Color(0xFFFB923C)],
      heroChips: [
        HcHeroChip(icon: Icons.shield_rounded, label: '${d['total'] ?? 0} claims'),
        HcHeroChip(icon: Icons.pending_rounded, label: '${d['pending_count'] ?? 0} pending'),
        HcHeroChip(icon: Icons.percent_rounded, label: '${d['approval_rate'] ?? 0}% approval'),
        HcHeroChip(icon: Icons.payments_rounded, label: hcMoney(d['total_approved'])),
      ],
      loading: _loading,
      onRefresh: _load,
      body: [
        const SizedBox(height: 8),
        HcKpiGrid(items: kpis),
        const SizedBox(height: 8),
        HcPanel(
          title: 'Claims by status',
          icon: Icons.assignment_rounded,
          color: const Color(0xFFF97316),
          child: statusSegs.every((s) => s.value == 0)
              ? const HcEmptyState(icon: Icons.assignment_rounded, title: 'No claim data')
              : Column(children: [
                  Center(child: HcDonutRing(segments: statusSegs, centerValue: '${d['total'] ?? 0}', centerLabel: 'claims')),
                  const SizedBox(height: 8),
                  for (final s in statusSegs) HcLegendRow(label: s.label, value: s.value, color: s.color),
                ]),
        ),
        HcPanel(
          title: 'Claims by type',
          icon: Icons.category_rounded,
          color: hcIndigo,
          child: typeValues.every((v) => v == 0)
              ? const HcEmptyState(icon: Icons.category_rounded, title: 'No type data')
              : HcBarChart(groups: typeValues.map((v) => [v]).toList(), labels: typeLabels, colors: typeColors, height: 220),
        ),
        HcPanel(
          title: 'Amounts',
          subtitle: 'Requested vs approved',
          icon: Icons.payments_rounded,
          color: hcGreen,
          child: Column(children: [
            HcStatTile(label: 'Total Requested', value: hcMoney(d['total_requested']), color: hcTeal),
            const SizedBox(height: 10),
            HcStatTile(label: 'Total Approved', value: hcMoney(d['total_approved']), color: hcGreen),
            const SizedBox(height: 10),
            HcStatTile(label: 'Pending Value', value: hcMoney(d['pending_value']), color: hcAmber),
          ]),
        ),
        HcPanel(
          title: 'Claims trend (${rangeLabel(_trendRange)})',
          subtitle: 'New claims per day',
          icon: Icons.bar_chart_rounded,
          color: const Color(0xFFF97316),
          action: HcRangeSelector(
              value: _trendRange,
              onChanged: (v) {
                setState(() => _trendRange = v);
                _loadChart(v);
              }),
          child: trendVals.isEmpty
              ? const HcEmptyState(icon: Icons.bar_chart_rounded, title: 'No trend data')
              : HcBarChart(groups: trendVals.map((v) => [v]).toList(), labels: trendLabels, colors: [const Color(0xFFF97316)], height: 200, scrollable: true),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────
//  PAGE 9 — Equipment Hire Analytics
// ───────────────────────────────────────────────────────────────
class HcAnalyticsEquipmentScreen extends ConsumerStatefulWidget {
  const HcAnalyticsEquipmentScreen({super.key});
  @override
  ConsumerState<HcAnalyticsEquipmentScreen> createState() =>
      _HcAnalyticsEquipmentScreenState();
}

class _HcAnalyticsEquipmentScreenState
    extends ConsumerState<HcAnalyticsEquipmentScreen> {
  Map<String, dynamic> _data = {};
  bool _loading = false;
  String _range = '30d';
  String _search = '';
  String? _abcFilter;
  int _abcPage = 1;
  static const _pageSize = 15;

  List _records = [];
  int _recordsCount = 0;
  int _recordsPage = 1;
  static const _recordsPageSize = 15;
  bool _recordsLoading = false;
  String _recordsSearch = '';
  String? _recordsStatus;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{'range': _range};
      if (_range == 'custom') {
        params['from'] = _customFrom;
        params['to'] = _customTo;
      }
      final res = await ref.read(dioProvider).get('/homecare/analytics/equipment-hire/', queryParameters: params);
      _data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _customFrom = '';
  String _customTo = '';
  DateTimeRange? _customRange;

  Future<void> _loadRecords() async {
    setState(() => _recordsLoading = true);
    try {
      final params = <String, dynamic>{
        'page': _recordsPage,
        'page_size': _recordsPageSize,
        'ordering': '-assigned_at',
        'range': _range,
      };
      if (_range == 'custom') {
        params['from'] = _customFrom;
        params['to'] = _customTo;
      }
      if (_recordsSearch.isNotEmpty) params['search'] = _recordsSearch;
      if (_recordsStatus != null) params['status'] = _recordsStatus;
      final res = await ref.read(dioProvider).get('/homecare/device-assignments/', queryParameters: params);
      final d = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      _records = (d['results'] as List?) ?? [];
      _recordsCount = (d['count'] as int?) ?? 0;
    } catch (_) {
      _records = [];
      _recordsCount = 0;
    }
    if (mounted) setState(() => _recordsLoading = false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _loadRecords();
    });
  }

  Color gradeColor(String g) => switch (g) {
        'A' => hcGreen,
        'B' => hcAmber,
        'C' => hcSlate,
        _ => hcTeal,
      };
  String gradeLabel(String g) => switch (g) {
        'A' => 'Vital few',
        'B' => 'Useful many',
        'C' => 'Trivial many',
        _ => '',
      };
  String gradeDesc(String g) => switch (g) {
        'A' => 'Top 80% of hire revenue',
        'B' => 'Next 15% of hire revenue',
        'C' => 'Bottom 5% of hire revenue',
        _ => '',
      };

  Color typeColor(String t) => switch (t) {
        'oximeter' => hcRed,
        'bp_monitor' => hcBlue,
        'glucometer' => hcAmber,
        'thermometer' => const Color(0xFFF97316),
        'oxygen' => const Color(0xFF06B6D4),
        'nebulizer' => const Color(0xFF14B8A6),
        'bed' => hcPurple,
        'wheelchair' => hcIndigo,
        'walker' => hcTeal,
        'suction' => hcSlate,
        'ventilator' => const Color(0xFFDC2626),
        'infusion_pump' => const Color(0xFF3B82F6),
        'ecg' => const Color(0xFFE11D48),
        _ => hcPurple,
      };

  String periodShort(String? p) => switch (p) {
        'hourly' => 'hr',
        'daily' => 'day',
        'weekly' => 'wk',
        'monthly' => 'mo',
        _ => p ?? 'day',
      };

  Color returnColor(String? c) {
    if (c == null) return hcSlate;
    final s = c.toLowerCase();
    if (s.contains('good')) return hcGreen;
    if (s.contains('fair')) return hcBlue;
    if (s.contains('damage') || s.contains('repair') || s.contains('lost')) return hcRed;
    return hcSlate;
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final cs = Theme.of(context).colorScheme;
    final abcSummary = (d['abc_summary'] as List?)?.cast<Map>() ?? [];
    final topEquipment = (d['top_equipment'] as List?)?.cast<Map>() ?? [];
    final byType = (d['by_type'] as List?)?.cast<Map>() ?? [];
    final hireTrend = (d['hire_trend'] as Map?)?.cast<String, dynamic>() ?? {};

    final abcFiltered = topEquipment.where((p) {
      if (_abcFilter != null && p['grade'] != _abcFilter) return false;
      if (_search.isNotEmpty && !(p['name'] ?? '').toString().toLowerCase().contains(_search) && !(p['device_type_label'] ?? '').toString().toLowerCase().contains(_search)) return false;
      return true;
    }).toList();
    final abcPageCount = (abcFiltered.length / _pageSize).ceil().clamp(1, 99999);
    final abcStart = (_abcPage - 1) * _pageSize;
    final abcPaged = abcFiltered.skip(abcStart).take(_pageSize).toList();

    final typeSegs = <({String label, num value, Color color})>[
      for (final t in byType)
        if (((t['revenue'] as num?) ?? 0) > 0)
          (label: (t['label'] ?? t['type'] ?? '—').toString(), value: (t['revenue'] as num?) ?? 0, color: typeColor((t['type'] ?? '').toString())),
    ]..sort((a, b) => b.value.compareTo(a.value));
    final typeSegsTop = typeSegs.take(8).toList();

    final top7 = [...topEquipment]..sort((a, b) => ((b['revenue'] as num?) ?? 0).compareTo((a['revenue'] as num?) ?? 0));
    final top7List = top7.take(7).toList();
    final topVals = top7List.map((p) => (p['revenue'] as num?) ?? 0).toList();
    final topLabels = top7List.map((p) {
      final name = (p['name'] ?? '—').toString();
      return name.length > 16 ? '${name.substring(0, 16)}…' : name;
    }).toList();
    final topColors = top7List.map((p) => gradeColor((p['grade'] ?? 'A').toString())).toList();

    final hireVals = (hireTrend['values'] as List?)?.map((v) => (v as num?) ?? 0).toList() ?? [];
    final hireLabels = (hireTrend['labels'] as List?)?.map((v) => v.toString()).toList() ?? [];

    final kpis = <({String label, String value, IconData icon, Color color, String? hint})>[
      (label: 'Hire Revenue', value: hcMoney(d['total_hire_revenue']), icon: Icons.payments_rounded, color: hcTeal, hint: null),
      (label: 'Total Hires', value: '${d['total_hires'] ?? 0}', icon: Icons.repeat_rounded, color: hcBlue, hint: '${d['devices_with_hires'] ?? 0} devices'),
      (label: 'Active Hires', value: '${d['active_hires'] ?? 0}', icon: Icons.local_shipping_rounded, color: hcPurple, hint: hcMoney(d['deposits_held'])),
      (label: 'Avg / Hire', value: hcMoney(d['avg_revenue_per_hire']), icon: Icons.timeline_rounded, color: hcAmber, hint: '${d['rentable_devices'] ?? 0} rentable'),
    ];

    return HcAnalyticsPage(
      currentPath: '/homecare/analytics/equipment',
      title: 'Equipment Hire Analytics',
      subtitle: 'Rental performance, ABC/Pareto classification & hire history',
      heroIcon: Icons.devices_rounded,
      heroGradient: const [Color(0xFF0E7490), Color(0xFF06B6D4), Color(0xFF22D3EE)],
      heroChips: [
        HcHeroChip(icon: Icons.payments_rounded, label: hcMoney(d['total_hire_revenue'])),
        HcHeroChip(icon: Icons.repeat_rounded, label: '${d['total_hires'] ?? 0} hires'),
        HcHeroChip(icon: Icons.local_shipping_rounded, label: '${d['active_hires'] ?? 0} active'),
        HcHeroChip(icon: Icons.devices_rounded, label: '${d['devices_with_hires'] ?? 0} devices'),
      ],
      loading: _loading,
      onRefresh: () async { await _load(); await _loadRecords(); },
      body: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: HcRangeSelector(
            value: _range,
            customRange: _customRange,
            onCustomRange: (range) {
              if (range != null) {
                setState(() {
                  _customRange = range;
                  _customFrom = DateFormat('yyyy-MM-dd').format(range.start);
                  _customTo = DateFormat('yyyy-MM-dd').format(range.end);
                });
              }
            },
            onChanged: (v) {
              setState(() {
                _range = v;
                _abcPage = 1;
              });
              _load();
              _recordsPage = 1;
              _loadRecords();
            },
          ),
        ),
        const SizedBox(height: 8),
        HcKpiGrid(items: kpis),
        const SizedBox(height: 8),
        if (abcSummary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: abcSummary.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final g = abcSummary[i];
                  return SizedBox(
                    width: MediaQuery.of(context).size.width * 0.42 + 30,
                    child: _buildAbcCard(g, cs),
                  );
                },
              ),
            ),
          ),
        HcPanel(
          title: 'Equipment performance — ABC Analysis (Pareto)',
          subtitle: 'Devices ranked by hire revenue',
          icon: Icons.sort_rounded,
          color: hcTeal,
          child: abcPaged.isEmpty
              ? const HcEmptyState(icon: Icons.devices_rounded, title: 'No hire data', message: 'No equipment generated hire revenue in this period')
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: HcSearchField(hintText: 'Search device…', onChanged: (v) => setState(() { _search = v.toLowerCase(); _abcPage = 1; })),
                  ),
                  if (_abcFilter != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: HcStatusChip(label: 'Class $_abcFilter only', color: gradeColor(_abcFilter!), icon: Icons.filter_alt_rounded),
                    ),
                  for (var i = 0; i < abcPaged.length; i++) ...[
                    if (i > 0) const Divider(height: 1, thickness: 0.5),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _buildAbcTile(abcPaged[i], abcStart + i + 1, cs),
                    ),
                  ],
                  if (abcFiltered.length > _pageSize)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: _abcPage > 1 ? () => setState(() => _abcPage--) : null, iconSize: 20),
                        Text('$abcPageCount pages · ${abcFiltered.length} rows', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                        IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: _abcPage < abcPageCount ? () => setState(() => _abcPage++) : null, iconSize: 20),
                      ]),
                    ),
                ]),
        ),
        HcPanel(
          title: 'Revenue by type',
          subtitle: 'Hire earnings per device category',
          icon: Icons.category_rounded,
          color: hcPurple,
          child: byType.isEmpty
              ? const HcEmptyState(icon: Icons.category_rounded, title: 'No data')
              : Column(children: [
                  Center(child: HcDonutRing(segments: typeSegsTop, size: 170, centerValue: hcMoney(d['total_hire_revenue']), centerLabel: 'total')),
                  const SizedBox(height: 12),
                  for (final t in byType)
                    if (((t['revenue'] as num?) ?? 0) > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          Container(width: 9, height: 9, decoration: BoxDecoration(color: typeColor((t['type'] ?? '').toString()), shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(child: Text((t['label'] ?? t['type'] ?? '—').toString(), style: const TextStyle(fontSize: 12))),
                          Text('${t['devices'] ?? 0}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                          const SizedBox(width: 8),
                          Text('${t['hires'] ?? 0}', style: const TextStyle(fontSize: 11.5)),
                          const SizedBox(width: 8),
                          SizedBox(width: 60, child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (t['revenue'] as num? ?? 0) / (typeSegs.isEmpty ? 1 : typeSegs.first.value), minHeight: 5, color: typeColor((t['type'] ?? '').toString())))),
                          const SizedBox(width: 8),
                          Text(hcMoney(t['revenue']), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                ]),
        ),
        HcPanel(
          title: 'Top 7 equipment by hire revenue',
          subtitle: 'Highest-earning devices',
          icon: Icons.emoji_events_rounded,
          color: hcTeal,
          child: topVals.isEmpty
              ? const HcEmptyState(icon: Icons.devices_rounded, title: 'No hires in this period')
              : HcBarChart(groups: topVals.map((v) => [v]).toList(), labels: topLabels, colors: topColors, height: 260, showValues: true, yFormatter: (v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.round().toString()),
        ),
        HcPanel(
          title: 'Hire activity',
          subtitle: 'Hires started per day',
          icon: Icons.show_chart_rounded,
          color: hcBlue,
          child: hireVals.isEmpty || !hireVals.any((v) => v > 0)
              ? const HcEmptyState(icon: Icons.show_chart_rounded, title: 'No activity')
              : HcLineChart(
                  series: [(label: 'Hires', color: hcBlue, values: hireVals)],
                  labels: hireLabels,
                  height: 220,
                  scrollable: true,
                ),
        ),
        HcPanel(
          title: 'Hire records',
          subtitle: 'Complete device hire history',
          icon: Icons.history_rounded,
          color: hcBlue,
          child: _records.isEmpty && !_recordsLoading
              ? const HcEmptyState(icon: Icons.devices_rounded, title: 'No hire records')
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Expanded(
                        child: SizedBox(
                          width: 120,
                          child: HcSearchField(hintText: 'Search…', onChanged: (v) { _recordsSearch = v; _recordsPage = 1; _loadRecords(); }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String?>(
                        value: _recordsStatus,
                        underline: const SizedBox.shrink(),
                        isDense: true,
                        hint: const Text('Filter', style: TextStyle(fontSize: 11)),
                        icon: const Icon(Icons.filter_alt_rounded, size: 16),
                        items: const [DropdownMenuItem(value: null, child: Text('All')), DropdownMenuItem(value: 'active', child: Text('Active')), DropdownMenuItem(value: 'returned', child: Text('Returned'))],
                        onChanged: (v) { setState(() => _recordsStatus = v); _recordsPage = 1; _loadRecords(); },
                      ),
                    ]),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 8,
                      dataRowMinHeight: 40,
                      dataRowMaxHeight: 48,
                      headingRowHeight: 36,
                      columns: const [
                        DataColumn(label: Text('#', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
                        DataColumn(label: Text('Device', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
                        DataColumn(label: Text('Hired to', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
                        DataColumn(label: Text('Period', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
                        DataColumn(label: Text('Rate', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)), numeric: true),
                        DataColumn(label: Text('Charge', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)), numeric: true),
                        DataColumn(label: Text('Started', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
                        DataColumn(label: Text('Status', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
                        DataColumn(label: Text('')),
                      ],
                      rows: [
                        for (var i = 0; i < _records.length; i++)
                          DataRow(cells: [
                            DataCell(Text('${(_recordsPage - 1) * _recordsPageSize + i + 1}', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant))),
                            DataCell(SizedBox(width: 100, child: Text((_records[i]['device_name'] ?? '—').toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis))),
                            DataCell(SizedBox(width: 80, child: Row(children: [
                              Icon(_records[i]['hire_to_type'] == 'facility' ? Icons.local_hospital_rounded : Icons.person_rounded, size: 12, color: cs.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Expanded(child: Text((_records[i]['hire_to_name'] ?? _records[i]['patient_name'] ?? _records[i]['facility_name'] ?? '—').toString(), style: const TextStyle(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ]))),
                            DataCell(Text((_records[i]['hire_period_label'] ?? '—').toString(), style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant))),
                            DataCell(Text(_records[i]['hire_rate'] != null ? '${hcMoney(_records[i]['hire_rate'])}/${periodShort(_records[i]['hire_period']?.toString())}' : '—', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant))),
                            DataCell(Text(_records[i]['total_charged'] != null ? hcMoney(_records[i]['total_charged']) : _records[i]['estimated_charge'] != null ? '~${hcMoney(_records[i]['estimated_charge'])}' : '—', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                            DataCell(Text(hcDate(_records[i]['assigned_at']), style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant))),
                            DataCell(_records[i]['returned_at'] != null
                                ? HcStatusChip(label: hcLabel(_records[i]['return_condition']?.toString()) != '—' ? hcLabel(_records[i]['return_condition']?.toString()) : 'Returned', color: returnColor(_records[i]['return_condition']?.toString()))
                                : const HcStatusChip(label: 'Active', color: hcBlue)),
                            DataCell(IconButton(icon: const Icon(Icons.visibility_outlined, size: 16, color: hcTeal), onPressed: () => _showRecordDialog(_records[i]), padding: EdgeInsets.zero, constraints: const BoxConstraints())),
                          ]),
                      ],
                    ),
                  ),
                  if (_recordsLoading) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
                  if (_recordsCount > _recordsPageSize)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: _recordsPage > 1 ? () { setState(() => _recordsPage--); _loadRecords(); } : null, iconSize: 20),
                        Text('$recordsPageCount pages · $_recordsCount rows', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                        IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: _recordsPage < recordsPageCount ? () { setState(() => _recordsPage++); _loadRecords(); } : null, iconSize: 20),
                      ]),
                    ),
                ]),
        ),
      ],
    );
  }

  int get recordsPageCount => (_recordsCount / _recordsPageSize).ceil().clamp(1, 99999);

  void _showRecordDialog(Map r) {
    showDialog(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        final returnedAt = r['returned_at'];
        final isReturned = returnedAt != null;
        return AlertDialog(
          title: Text((r['device_name'] ?? '—').toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _dialogRow('Hired to', (r['hire_to_name'] ?? r['patient_name'] ?? r['facility_name'] ?? '—').toString(), cs),
            _dialogRow('Period', (r['hire_period_label'] ?? '—').toString(), cs),
            _dialogRow('Rate', r['hire_rate'] != null ? '${hcMoney(r['hire_rate'])}/${periodShort(r['hire_period']?.toString())}' : '—', cs),
            _dialogRow('Total charged', r['total_charged'] != null ? hcMoney(r['total_charged']) : r['estimated_charge'] != null ? '~${hcMoney(r['estimated_charge'])}' : '—', cs),
            _dialogRow('Started', hcDate(r['assigned_at']), cs),
            if (isReturned) ...[
              _dialogRow('Returned', hcDate(returnedAt), cs),
              _dialogRow('Condition', hcLabel(r['return_condition']?.toString()), cs),
            ] else
              _dialogRow('Status', 'Active', cs),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        );
      },
    );
  }

  Widget _dialogRow(String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildAbcTile(Map p, int rank, ColorScheme cs) {
    final grade = (p['grade'] ?? 'A').toString();
    final cumPct = ((p['cumulative_pct'] as num?) ?? 0).toDouble();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: gradeColor(grade).withValues(alpha: 0.14), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('$rank', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: gradeColor(grade))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text((p['name'] ?? '—').toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
            HcStatusChip(label: (p['device_type_label'] ?? '—').toString(), color: hcPurple),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.repeat_rounded, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text('${p['hire_count'] ?? 0} hires', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const Spacer(),
            Text(hcMoney(p['revenue']), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: hcTeal)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: cumPct / 100, minHeight: 6, color: gradeColor(grade)),
              ),
            ),
            const SizedBox(width: 8),
            Text('${cumPct.toStringAsFixed(1)}% cum', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            const SizedBox(width: 8),
            HcStatusChip(label: 'Class $grade', color: gradeColor(grade)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildAbcCard(Map g, ColorScheme cs) {
    final grade = (g['grade'] ?? 'A').toString();
    final isFiltered = _abcFilter == grade;
    return Card(
      margin: EdgeInsets.zero,
      color: isFiltered ? gradeColor(grade).withValues(alpha: 0.12) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() {
          _abcFilter = isFiltered ? null : grade;
          _abcPage = 1;
        }),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: gradeColor(grade), shape: BoxShape.circle), alignment: Alignment.center, child: Text(grade, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Class $grade — ${gradeLabel(grade)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                Text(gradeDesc(grade), style: TextStyle(fontSize: 9.5, color: cs.onSurfaceVariant)),
              ])),
              if (isFiltered) Icon(Icons.filter_alt_rounded, size: 16, color: gradeColor(grade)),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _abcStat('${g['count'] ?? 0}', 'Devices', cs),
              _abcStat(hcMoney(g['revenue']), 'Revenue', cs),
              _abcStat('${((g['pct'] as num?) ?? 0).toStringAsFixed(1)}%', 'of total', cs),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _abcStat(String value, String label, ColorScheme cs) {
    return Column(children: [
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      Text(label, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
    ]);
  }
}
