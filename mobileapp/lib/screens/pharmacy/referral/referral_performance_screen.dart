import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/api.dart';
import '../../../widgets/common.dart';

final _periodProvider = StateProvider<String>((ref) => '30d');

final _perfProvider = FutureProvider.autoDispose.family<Map, String>((ref, period) async {
  final dio = ref.read(dioProvider);
  final params = <String, dynamic>{};
  if (period.startsWith('custom:')) {
    final parts = period.split(':');
    params['start'] = parts[1];
    params['end'] = parts[2];
  } else {
    params['preset'] = period;
  }
  final res = await dio.get('/usage-billing/referral/performance/', queryParameters: params);
  return res.data;
});

String _fmt(dynamic v) {
  final n = double.tryParse('$v') ?? 0;
  if (n >= 1000) return NumberFormat.compact().format(n);
  return NumberFormat('#,##0.##').format(n);
}

class ReferralPerformanceScreen extends ConsumerStatefulWidget {
  const ReferralPerformanceScreen({super.key});

  @override
  ConsumerState<ReferralPerformanceScreen> createState() => _ReferralPerformanceScreenState();
}

class _ReferralPerformanceScreenState extends ConsumerState<ReferralPerformanceScreen> {
  static const _presets = [
    ('today', 'Today'),
    ('yesterday', 'Yesterday'),
    ('7d', '7 Days'),
    ('30d', '30 Days'),
    ('90d', '90 Days'),
    ('this_month', 'This Month'),
    ('last_month', 'Last Month'),
    ('custom', 'Custom'),
  ];

  DateTime? _customStart;
  DateTime? _customEnd;

  void _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _customStart != null && _customEnd != null
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now()),
    );
    if (range != null) {
      setState(() {
        _customStart = range.start;
        _customEnd = range.end;
      });
      final s = DateFormat('yyyy-MM-dd').format(range.start);
      final e = DateFormat('yyyy-MM-dd').format(range.end);
      ref.read(_periodProvider.notifier).state = 'custom:$s:$e';
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(_periodProvider);
    final data = ref.watch(_perfProvider(period));
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Image.asset('assets/images/adhere_coin.png', width: 24, height: 24),
          const SizedBox(width: 8),
          const Text('Performance'),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => ref.invalidate(_perfProvider(period))),
        ],
      ),
      body: Column(children: [
        // ── Period Chips ──
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: _presets.map((p) {
              final selected = period == p.$1 || (p.$1 == 'custom' && period.startsWith('custom:'));
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  selected: selected,
                  label: Text(p.$2, style: const TextStyle(fontSize: 12)),
                  onSelected: (_) {
                    if (p.$1 == 'custom') {
                      _pickCustomRange();
                    } else {
                      ref.read(_periodProvider.notifier).state = p.$1;
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),

        // ── Body ──
        Expanded(
          child: data.when(
            loading: () => const LoadingShimmer(),
            error: (e, _) => ErrorRetry(message: 'Failed to load', onRetry: () => ref.invalidate(_perfProvider(period))),
            data: (d) {
              final summary = d['summary'] ?? {};
              final trends = d['trends'] ?? {};
              final dailyEarned = (trends['daily_earned'] as List?) ?? [];
              final dailyReferrals = (trends['daily_referrals'] as List?) ?? [];
              final typeBreakdown = (d['type_breakdown'] as List?) ?? [];
              final topReferrals = (d['top_referrals'] as List?) ?? [];
              final recentTx = (d['recent_transactions'] as List?) ?? [];

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(_perfProvider(period)),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: [
                    // ── Summary KPIs ──
                    _SummaryKPIs(summary: summary, cs: cs).animate().fadeIn(duration: 300.ms),
                    const SizedBox(height: 20),

                    // ── Coins Earned Chart ──
                    if (dailyEarned.isNotEmpty) ...[
                      _EarnedChart(data: dailyEarned, cs: cs, isDark: isDark).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                      const SizedBox(height: 16),
                    ],

                    // ── New Referrals Chart ──
                    if (dailyReferrals.isNotEmpty) ...[
                      _ReferralsBarChart(data: dailyReferrals, cs: cs, isDark: isDark).animate().fadeIn(delay: 150.ms, duration: 400.ms),
                      const SizedBox(height: 16),
                    ],

                    // ── Type Breakdown ──
                    if (typeBreakdown.isNotEmpty) ...[
                      _TypeBreakdownCard(data: typeBreakdown, cs: cs).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                      const SizedBox(height: 16),
                    ],

                    // ── Top Referrals ──
                    if (topReferrals.isNotEmpty) ...[
                      _TopReferralsCard(data: topReferrals, cs: cs).animate().fadeIn(delay: 250.ms, duration: 400.ms),
                      const SizedBox(height: 16),
                    ],

                    // ── Recent Transactions ──
                    if (recentTx.isNotEmpty) ...[
                      _RecentTransactionsCard(data: recentTx, cs: cs, count: summary['transactions'] ?? 0).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                    ],

                    if (dailyEarned.isEmpty && dailyReferrals.isEmpty && typeBreakdown.isEmpty && topReferrals.isEmpty && recentTx.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: EmptyState(icon: Icons.bar_chart_rounded, title: 'No activity in this period', subtitle: 'Try a different date range.'),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ────────────────────────────────────────────────────
// Summary KPI Cards
// ────────────────────────────────────────────────────
class _SummaryKPIs extends StatelessWidget {
  final Map summary;
  final ColorScheme cs;
  const _SummaryKPIs({required this.summary, required this.cs});

  @override
  Widget build(BuildContext context) {
    final kpis = [
      (Icons.arrow_downward_rounded, const Color(0xFF22C55E), 'Earned', _fmt(summary['coins_earned'])),
      (Icons.arrow_upward_rounded, const Color(0xFF3B82F6), 'Redeemed', _fmt(summary['coins_redeemed'])),
      (Icons.functions_rounded, const Color(0xFF6366F1), 'Net', _fmt(summary['net_coins'])),
      (Icons.swap_horiz_rounded, const Color(0xFF8B5CF6), 'Transactions', '${summary['transactions'] ?? 0}'),
      (Icons.person_add_rounded, const Color(0xFFF59E0B), 'New Referrals', '${summary['new_referrals'] ?? 0}'),
      (Icons.account_balance_wallet_rounded, const Color(0xFF22C55E), 'Balance', _fmt(summary['total_balance'])),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.95,
      children: kpis.map((k) {
        final (icon, color, label, value) = k;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: color.withValues(alpha: 0.06),
            border: Border.all(color: color.withValues(alpha: 0.12)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.12)),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cs.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant), maxLines: 1),
          ]),
        );
      }).toList(),
    );
  }
}

// ────────────────────────────────────────────────────
// Coins Earned Line Chart
// ────────────────────────────────────────────────────
class _EarnedChart extends StatelessWidget {
  final List data;
  final ColorScheme cs;
  final bool isDark;
  const _EarnedChart({required this.data, required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final spots = data.asMap().entries.map((e) {
      final amt = double.tryParse('${e.value['amount'] ?? 0}') ?? 0;
      return FlSpot(e.key.toDouble(), amt);
    }).toList();
    final labels = data.map((d) => DateFormat('MMM d').format(DateTime.parse('${d['date']}'))).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.show_chart_rounded, size: 18, color: Color(0xFF22C55E)),
            const SizedBox(width: 8),
            const Text('Coins Earned Over Time', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(LineChartData(
              gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: _calcInterval(spots), getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant.withValues(alpha: 0.15), strokeWidth: 1)),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36, getTitlesWidget: (v, _) => Text(_fmt(v), style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)))),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: (spots.length / 4).ceilToDouble().clamp(1, 100), getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                  return Text(labels[i], style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant));
                })),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  preventCurveOverShooting: true,
                  color: const Color(0xFF22C55E),
                  barWidth: 2.5,
                  belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFF22C55E).withValues(alpha: 0.2), const Color(0xFF22C55E).withValues(alpha: 0)])),
                  dotData: FlDotData(show: spots.length <= 15),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                    '${labels[s.x.toInt()]}\n${_fmt(s.y)}',
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
                  )).toList(),
                ),
              ),
            )),
          ),
        ]),
      ),
    );
  }

  double _calcInterval(List<FlSpot> spots) {
    if (spots.isEmpty) return 1;
    final max = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    if (max <= 0) return 1;
    return (max / 4).ceilToDouble().clamp(1, double.infinity);
  }
}

// ────────────────────────────────────────────────────
// New Referrals Bar Chart
// ────────────────────────────────────────────────────
class _ReferralsBarChart extends StatelessWidget {
  final List data;
  final ColorScheme cs;
  final bool isDark;
  const _ReferralsBarChart({required this.data, required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final labels = data.map((d) => DateFormat('MMM d').format(DateTime.parse('${d['date']}'))).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.group_add_rounded, size: 18, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 8),
            const Text('New Referrals Over Time', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: BarChart(BarChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                  if (labels.length > 10 && i % (labels.length ~/ 5) != 0) return const SizedBox.shrink();
                  return Text(labels[i], style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant));
                })),
              ),
              borderData: FlBorderData(show: false),
              barGroups: data.asMap().entries.map((e) {
                final count = (e.value['count'] as num?)?.toDouble() ?? 0;
                return BarChartGroupData(x: e.key, barRods: [
                  BarChartRodData(
                    toY: count,
                    width: data.length > 15 ? 6 : 12,
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)]),
                  ),
                ]);
              }).toList(),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                    '${labels[group.x]}\n${rod.toY.toInt()} referrals',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
                  ),
                ),
              ),
            )),
          ),
        ]),
      ),
    );
  }
}

// ────────────────────────────────────────────────────
// Type Breakdown
// ────────────────────────────────────────────────────
class _TypeBreakdownCard extends StatelessWidget {
  final List data;
  final ColorScheme cs;
  const _TypeBreakdownCard({required this.data, required this.cs});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.fold<double>(0, (m, t) {
      final v = double.tryParse('${t['total'] ?? 0}') ?? 0;
      return v > m ? v : m;
    }).clamp(1, double.infinity);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.donut_large_rounded, size: 18, color: Color(0xFF6366F1)),
            const SizedBox(width: 8),
            const Text('Coin Breakdown', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          ...data.map((item) {
            final type = '${item['type'] ?? ''}';
            final total = double.tryParse('${item['total'] ?? 0}') ?? 0;
            final count = item['count'] ?? 0;
            final pct = total / maxVal;

            final color = switch (type) {
              'earned' => const Color(0xFF22C55E),
              'bonus' => const Color(0xFFF59E0B),
              'redeemed' => const Color(0xFF3B82F6),
              _ => Colors.grey,
            };

            final icon = switch (type) {
              'earned' => Icons.arrow_downward_rounded,
              'bonus' => Icons.star_rounded,
              'redeemed' => Icons.arrow_upward_rounded,
              _ => Icons.swap_horiz_rounded,
            };

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 6),
                  Text('${type[0].toUpperCase()}${type.substring(1)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  const Spacer(),
                  Text(_fmt(total), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cs.onSurface)),
                  const SizedBox(width: 6),
                  Text('(${count}x)', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: pct, backgroundColor: color.withValues(alpha: 0.08), color: color, minHeight: 8),
                ),
              ]),
            );
          }),
        ]),
      ),
    );
  }
}

// ────────────────────────────────────────────────────
// Top Referrals
// ────────────────────────────────────────────────────
class _TopReferralsCard extends StatelessWidget {
  final List data;
  final ColorScheme cs;
  const _TopReferralsCard({required this.data, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.emoji_events_rounded, size: 18, color: Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            const Text('Top Performing Referrals', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          ...data.asMap().entries.map((e) {
            final i = e.key;
            final r = e.value;
            final name = '${r['referred_name'] ?? ''}';
            final status = '${r['status'] ?? ''}';
            final active = status == 'active';
            final requests = int.tryParse('${r['tracked_requests'] ?? 0}') ?? 0;
            final coins = _fmt(r['coins_from_usage']);
            final date = r['created_at'] != null ? DateFormat('MMM d, yyyy').format(DateTime.parse('${r['created_at']}')) : '';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: i < 3 ? const Color(0xFFF59E0B).withValues(alpha: 0.04) : Colors.transparent,
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.12)),
              ),
              child: Row(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < 3 ? const Color(0xFFF59E0B).withValues(alpha: 0.15) : cs.surfaceContainerHighest,
                  ),
                  child: Center(child: Text('#${i + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: i < 3 ? const Color(0xFFF59E0B) : cs.onSurfaceVariant))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Wrap(spacing: 6, runSpacing: 2, children: [
                    _TinyChip('$coins coins', const Color(0xFFF59E0B)),
                    _TinyChip('${NumberFormat.compact().format(requests)} req', const Color(0xFF3B82F6)),
                    if (date.isNotEmpty) _TinyChip(date, Colors.grey),
                  ]),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF22C55E).withValues(alpha: 0.1) : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: active ? const Color(0xFF22C55E) : const Color(0xFFF59E0B))),
                ),
              ]),
            );
          }),
        ]),
      ),
    );
  }
}

// ────────────────────────────────────────────────────
// Recent Transactions
// ────────────────────────────────────────────────────
class _RecentTransactionsCard extends StatelessWidget {
  final List data;
  final ColorScheme cs;
  final dynamic count;
  const _RecentTransactionsCard({required this.data, required this.cs, required this.count});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.history_rounded, size: 18, color: Color(0xFF3B82F6)),
            const SizedBox(width: 8),
            const Text('Recent Transactions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text('$count', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6))),
            ),
          ]),
          const SizedBox(height: 12),
          ...data.map((t) {
            final type = '${t['type'] ?? ''}';
            final earned = type == 'earned' || type == 'bonus';
            final amount = _fmt(t['amount']);
            final reason = '${t['reason'] ?? ''}';
            final related = '${t['related_tenant_name'] ?? ''}';
            final date = t['created_at'] != null ? DateFormat('MMM d, h:mm a').format(DateTime.parse('${t['created_at']}')) : '';

            final (icon, color) = switch (type) {
              'earned' => (Icons.arrow_downward_rounded, const Color(0xFF22C55E)),
              'bonus' => (Icons.star_rounded, const Color(0xFFF59E0B)),
              'redeemed' => (Icons.arrow_upward_rounded, const Color(0xFF3B82F6)),
              _ => (Icons.swap_horiz_rounded, Colors.grey),
            };

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.08)),
              ),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.1)),
                  child: Icon(icon, size: 14, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(type, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
                    ),
                    if (related.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Expanded(child: Text(related, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ]),
                  if (reason.isNotEmpty)
                    Text(reason, style: TextStyle(fontSize: 11, color: cs.onSurface, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (date.isNotEmpty)
                    Text(date, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                ])),
                Text('${earned ? '+' : '-'}$amount', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: earned ? const Color(0xFF22C55E) : const Color(0xFFEF4444))),
              ]),
            );
          }),
        ]),
      ),
    );
  }
}

class _TinyChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TinyChip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
    child: Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w500)),
  );
}
