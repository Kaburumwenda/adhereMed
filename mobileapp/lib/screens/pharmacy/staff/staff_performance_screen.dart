import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/api.dart';
import '../../../widgets/common.dart';

// ─── Providers ──────────────────────────────────────
final _periodProvider = StateProvider<String>((ref) => 'last30');
final _searchProvider = StateProvider<String>((ref) => '');

final _perfProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, period) async {
  final dio = ref.read(dioProvider);
  final q = period.startsWith('custom:')
      ? {'date_from': period.split(':')[1], 'date_to': period.split(':')[2]}
      : {'period': period};
  final res = await dio.get('/staff/performance/', queryParameters: q);
  return res.data as Map<String, dynamic>;
});

String _ksh(dynamic v) => 'KSh ${NumberFormat('#,##0').format((double.tryParse('$v') ?? 0).round())}';
String _num(dynamic v) => NumberFormat('#,##0').format(int.tryParse('$v') ?? (double.tryParse('$v')?.round() ?? 0));

class StaffPerformanceScreen extends ConsumerStatefulWidget {
  const StaffPerformanceScreen({super.key});
  @override
  ConsumerState<StaffPerformanceScreen> createState() => _StaffPerformanceScreenState();
}

class _StaffPerformanceScreenState extends ConsumerState<StaffPerformanceScreen> {
  final _searchCtrl = TextEditingController();

  static const _periods = [
    ('today', 'Today'),
    ('yesterday', 'Yesterday'),
    ('last7', '7 Days'),
    ('last30', '30 Days'),
    ('last90', '90 Days'),
    ('year', 'This Year'),
    ('custom', 'Custom'),
  ];

  void _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now()),
    );
    if (range != null) {
      final s = DateFormat('yyyy-MM-dd').format(range.start);
      final e = DateFormat('yyyy-MM-dd').format(range.end);
      ref.read(_periodProvider.notifier).state = 'custom:$s:$e';
    }
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(_periodProvider);
    final data = ref.watch(_perfProvider(period));
    final search = ref.watch(_searchProvider).toLowerCase();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Performance'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => ref.invalidate(_perfProvider(period))),
        ],
      ),
      body: Column(children: [
        // Period chips
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: _periods.map((p) {
              final selected = period == p.$1 || (p.$1 == 'custom' && period.startsWith('custom:'));
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  selected: selected,
                  label: Text(p.$2, style: const TextStyle(fontSize: 11)),
                  onSelected: (_) {
                    if (p.$1 == 'custom') { _pickCustomRange(); } else { ref.read(_periodProvider.notifier).state = p.$1; }
                  },
                ),
              );
            }).toList(),
          ),
        ),

        // Body
        Expanded(child: data.when(
          loading: () => const LoadingShimmer(),
          error: (e, _) => ErrorRetry(message: 'Failed to load performance', onRetry: () => ref.invalidate(_perfProvider(period))),
          data: (d) {
            final leaderboard = (d['leaderboard'] as List?) ?? [];
            final dailyRevenue = (d['daily'] as List?) ?? [];
            final paymentBreakdown = (d['by_payment'] as List?) ?? [];
            final totals = d['totals'] as Map<String, dynamic>? ?? {};

            // Filter leaderboard
            final filtered = search.isEmpty
                ? leaderboard
                : leaderboard.where((s) => '${s['name'] ?? ''}'.toLowerCase().contains(search) || '${s['email'] ?? ''}'.toLowerCase().contains(search)).toList();

            return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 80), children: [
              // KPI cards
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.9,
                children: [
                  _KPI(icon: Icons.payments_rounded, color: const Color(0xFF22C55E), label: 'Total Revenue', value: _ksh(totals['revenue'])),
                  _KPI(icon: Icons.shopping_bag_rounded, color: const Color(0xFF6366F1), label: 'Items Sold', value: _num(totals['items_sold'])),
                  _KPI(icon: Icons.people_rounded, color: const Color(0xFF3B82F6), label: 'Active Staff', value: _num(totals['active_staff'])),
                  _KPI(icon: Icons.block_rounded, color: const Color(0xFFEF4444), label: 'Voided Sales', value: _num(totals['voided_count'])),
                ],
              ).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: 16),

              // Revenue trend
              if (dailyRevenue.isNotEmpty) ...[
                _buildRevenueTrend(dailyRevenue, cs),
                const SizedBox(height: 16),
              ],

              // Payment breakdown
              if (paymentBreakdown.isNotEmpty) ...[
                _buildPaymentBreakdown(paymentBreakdown, cs),
                const SizedBox(height: 16),
              ],

              // Top 3 podium
              if (filtered.length >= 3) ...[
                _buildPodium(filtered.take(3).toList(), cs),
                const SizedBox(height: 16),
              ],

              // Leaderboard search
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search leaderboard...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (v) => ref.read(_searchProvider.notifier).state = v,
                ),
              ),

              // Leaderboard header
              Row(children: [
                const Icon(Icons.emoji_events_rounded, size: 18, color: Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                const Text('Leaderboard', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text('${filtered.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B))),
                ),
              ]),
              const SizedBox(height: 10),

              // Leaderboard items
              ...filtered.asMap().entries.map((e) {
                final i = e.key;
                final s = e.value;
                return _LeaderboardCard(staff: s, rank: i + 1, cs: cs).animate().fadeIn(delay: (30 * i).clamp(0, 300).ms, duration: 250.ms);
              }),

              if (filtered.isEmpty)
                const Padding(padding: EdgeInsets.only(top: 20), child: EmptyState(icon: Icons.search_off_rounded, title: 'No matches')),
            ]);
          },
        )),
      ]),
    );
  }

  Widget _buildRevenueTrend(List data, ColorScheme cs) {
    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), (double.tryParse('${e.value['revenue'] ?? 0}') ?? 0));
    }).toList();
    final labels = data.map((d) {
      try { return DateFormat('MMM d').format(DateTime.parse('${d['date']}')); } catch (_) { return ''; }
    }).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.show_chart_rounded, size: 18, color: Color(0xFF22C55E)),
            const SizedBox(width: 8),
            const Text('Daily Revenue', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            height: 160,
            child: LineChart(LineChartData(
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant.withValues(alpha: 0.15), strokeWidth: 1)),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, _) => Text(_compact(v), style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)))),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, interval: (spots.length / 4).ceilToDouble().clamp(1, 100), getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                  return Text(labels[i], style: TextStyle(fontSize: 8, color: cs.onSurfaceVariant));
                })),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots, isCurved: true, preventCurveOverShooting: true,
                  color: const Color(0xFF22C55E), barWidth: 2.5,
                  belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFF22C55E).withValues(alpha: 0.2), const Color(0xFF22C55E).withValues(alpha: 0)])),
                  dotData: FlDotData(show: spots.length <= 15),
                ),
              ],
            )),
          ),
        ]),
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
  }

  Widget _buildPaymentBreakdown(List data, ColorScheme cs) {
    final total = data.fold<double>(0, (s, r) => s + (double.tryParse('${r['total'] ?? r['revenue'] ?? 0}') ?? 0));
    final colors = [const Color(0xFF6366F1), const Color(0xFF22C55E), const Color(0xFFF59E0B), const Color(0xFF3B82F6), const Color(0xFFEF4444), const Color(0xFF8B5CF6)];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.pie_chart_rounded, size: 18, color: Color(0xFF6366F1)),
            const SizedBox(width: 8),
            const Text('Payment Methods', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          ...data.asMap().entries.map((e) {
            final r = e.value;
            final rev = double.tryParse('${r['total'] ?? r['revenue'] ?? 0}') ?? 0;
            final pct = total > 0 ? rev / total : 0.0;
            final color = colors[e.key % colors.length];
            final method = '${r['payment_method'] ?? r['method'] ?? 'Other'}';

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(method[0].toUpperCase() + method.substring(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  Text(_ksh(rev), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurface)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: pct, backgroundColor: color.withValues(alpha: 0.08), color: color, minHeight: 8),
                  )),
                  const SizedBox(width: 8),
                  Text('${(pct * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                ]),
              ]),
            );
          }),
        ]),
      ),
    ).animate().fadeIn(delay: 150.ms, duration: 400.ms);
  }

  Widget _buildPodium(List top3, ColorScheme cs) {
    final medals = [
      (const Color(0xFFF59E0B), Icons.emoji_events_rounded, '1st'),
      (const Color(0xFF9CA3AF), Icons.emoji_events_rounded, '2nd'),
      (const Color(0xFFCD7F32), Icons.emoji_events_rounded, '3rd'),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.military_tech_rounded, size: 18, color: Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            const Text('Top Performers', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (top3.length > 1) _podiumItem(top3[1], medals[1], cs, height: 70),
              _podiumItem(top3[0], medals[0], cs, height: 90),
              if (top3.length > 2) _podiumItem(top3[2], medals[2], cs, height: 55),
            ],
          ),
        ]),
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  Widget _podiumItem(Map<String, dynamic> s, (Color, IconData, String) medal, ColorScheme cs, {double height = 70}) {
    final name = '${s['name'] ?? 'Unknown'}';
    final initials = name.split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();

    return Column(children: [
      Icon(medal.$2, color: medal.$1, size: 22),
      Text(medal.$3, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: medal.$1)),
      const SizedBox(height: 6),
      CircleAvatar(
        radius: 20,
        backgroundColor: medal.$1.withValues(alpha: 0.12),
        child: Text(initials, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: medal.$1)),
      ),
      const SizedBox(height: 4),
      SizedBox(width: 80, child: Text(name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis)),
      Text(_ksh(s['revenue']), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: cs.primary)),
      Container(
        width: 80, height: height,
        margin: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(
          color: medal.$1.withValues(alpha: 0.12),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
      ),
    ]);
  }
}

String _compact(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
  return v.toInt().toString();
}

// ════════════════════════════════════════════════════
// LEADERBOARD CARD
// ════════════════════════════════════════════════════
class _LeaderboardCard extends StatelessWidget {
  final Map<String, dynamic> staff;
  final int rank;
  final ColorScheme cs;
  const _LeaderboardCard({required this.staff, required this.rank, required this.cs});

  @override
  Widget build(BuildContext context) {
    final name = '${staff['name'] ?? 'Unknown'}';
    final initials = name.split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
    final email = '${staff['email'] ?? ''}';
    final role = '${staff['role'] ?? ''}'.replaceAll('_', ' ');
    final branch = '${staff['branch'] ?? ''}';
    final medal = rank <= 3;
    final medalColors = [const Color(0xFFF59E0B), const Color(0xFF9CA3AF), const Color(0xFFCD7F32)];

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.12))),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          // Rank badge
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: medal ? medalColors[rank - 1].withValues(alpha: 0.15) : cs.surfaceContainerHighest,
            ),
            child: Center(child: Text('#$rank', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: medal ? medalColors[rank - 1] : cs.onSurfaceVariant))),
          ),
          const SizedBox(width: 10),

          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
            child: Text(initials, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6366F1))),
          ),
          const SizedBox(width: 10),

          // Info
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (email.isNotEmpty)
              Text(email, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Wrap(spacing: 4, runSpacing: 2, children: [
              if (role.isNotEmpty) _chip(role, const Color(0xFF3B82F6)),
              if (branch.isNotEmpty) _chip(branch, const Color(0xFF06B6D4)),
              _chip('${staff['transactions'] ?? 0} txns', const Color(0xFF6366F1)),
              _chip('${staff['items_sold'] ?? 0} items', const Color(0xFF8B5CF6)),
            ]),
            if (staff['active_days'] != null || staff['last_sale'] != null) ...[
              const SizedBox(height: 2),
              Wrap(spacing: 4, runSpacing: 2, children: [
                if (staff['active_days'] != null) _chip('${staff['active_days']}d active', Colors.grey),
                if (staff['discounts'] != null) _chip('Disc: ${_ksh(staff['discounts'])}', const Color(0xFFEF4444)),
                if (staff['voids'] != null && (int.tryParse('${staff['voids']}') ?? 0) > 0) _chip('${staff['voids']} voids', const Color(0xFFEF4444)),
              ]),
            ],
          ])),

          // Revenue
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_ksh(staff['revenue']), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cs.primary)),
            Text('Avg: ${_ksh(staff['avg_per_txn'])}', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
          ]),
        ]),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w500)),
  );
}

// ════════════════════════════════════════════════════
// KPI
// ════════════════════════════════════════════════════
class _KPI extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value;
  const _KPI({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withValues(alpha: 0.05),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.12)),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
      ]),
    );
  }
}
