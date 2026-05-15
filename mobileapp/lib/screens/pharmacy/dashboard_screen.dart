import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/api.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common.dart';

final _pharmacyProfileProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/pharmacy-profile/profile/');
  final data = res.data;
  if (data is List) return data.isNotEmpty ? data[0] : <String, dynamic>{};
  if (data?['results'] is List) {
    final list = data['results'] as List;
    return list.isNotEmpty ? list[0] : <String, dynamic>{};
  }
  return data ?? <String, dynamic>{};
});

final _dashProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final results = await Future.wait([
    dio.get('/inventory/analytics/'),
    dio.get('/usage-billing/dashboard/'),
    dio.get('/usage-billing/referral/stats/'),
  ]);
  return {
    'inventory': results[0].data,
    'billing': results[1].data,
    'referral': results[2].data,
  };
});

// Sales comparison provider: today vs yesterday, month vs year
final _salesCompareProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final results = await Future.wait([
    dio.get('/reports/sales-summary/', queryParameters: {'period': 'today'}),
    dio.get('/reports/sales-summary/', queryParameters: {'period': 'yesterday'}),
    dio.get('/reports/sales-summary/', queryParameters: {'period': 'month'}),
    dio.get('/reports/sales-summary/', queryParameters: {'period': 'year'}),
  ]);
  return {
    'today': results[0].data,
    'yesterday': results[1].data,
    'month': results[2].data,
    'year': results[3].data,
  };
});

// Sales trend chart provider with date filter
final _trendPeriod = StateProvider<String>((ref) => 'last7');

final _trendProvider = FutureProvider.autoDispose.family<Map, String>((ref, period) async {
  final dio = ref.read(dioProvider);
  final Map<String, dynamic> params = {};
  if (period.startsWith('custom:')) {
    final parts = period.split(':');
    params['date_from'] = parts[1];
    params['date_to'] = parts[2];
  } else {
    params['period'] = period;
  }
  final res = await dio.get('/reports/sales-summary/', queryParameters: params);
  return res.data;
});

// Top selling products provider
final _topProductsProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/pos/analytics/', queryParameters: {'period': 'month'});
  return (res.data['top_selling_items'] as List?) ?? [];
});

/// Count of unsettled credit sales
final _creditCountProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/pos/credits/summary/');
  final data = res.data as Map<String, dynamic>;
  final total = (data['count'] as int?) ?? 0;
  // Subtract settled from total using by_status
  final byStatus = (data['by_status'] as List?) ?? [];
  final settledCount = byStatus
      .where((s) => s['status'] == 'settled')
      .fold<int>(0, (sum, s) => sum + ((s['count'] as int?) ?? 0));
  return total - settledCount;
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final dash = ref.watch(_dashProvider);
    final cs = Theme.of(context).colorScheme;
    final now = DateFormat('EEEE, MMM d').format(DateTime.now());
    final greeting = _greeting();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(_dashProvider),
      edgeOffset: 0,
      child: CustomScrollView(
        slivers: [
          // ── Hero header ──
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF202020),
                          const Color(0xFF2D2D2D),
                        ]
                      : [
                          const Color(0xFFF8FAFC),
                          const Color(0xFFFFFFFF),
                        ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                border: Border(
                  bottom: BorderSide(color: isDark ? cs.outlineVariant.withValues(alpha: 0.15) : cs.outlineVariant.withValues(alpha: 0.1)),
                ),
              ),
              child: Stack(children: [
                // Decorative orbs
                Positioned(right: -40, top: -40, child: Container(
                  width: 150, height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? cs.primary.withValues(alpha: 0.06) : cs.primary.withValues(alpha: 0.04),
                  ),
                )),
                Positioned(left: -20, bottom: 30, child: Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? cs.tertiary.withValues(alpha: 0.05) : cs.tertiary.withValues(alpha: 0.03),
                  ),
                )),
                // Content
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? cs.primary.withValues(alpha: 0.1)
                                    : cs.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.calendar_today_rounded, size: 11, color: isDark ? cs.onSurfaceVariant : cs.onSurfaceVariant),
                                const SizedBox(width: 5),
                                Text(now, style: TextStyle(
                                  color: isDark ? cs.onSurfaceVariant : cs.onSurfaceVariant,
                                  fontSize: 11, fontWeight: FontWeight.w500,
                                )),
                              ]),
                            ).animate().fadeIn(duration: 300.ms),
                            const SizedBox(height: 10),
                            Text('$greeting 👋', style: TextStyle(
                              color: isDark ? cs.onSurfaceVariant : cs.onSurfaceVariant,
                              fontSize: 14, fontWeight: FontWeight.w400,
                            )).animate().fadeIn(duration: 400.ms),
                            const SizedBox(height: 2),
                            Text(auth.user?.fullName ?? '', style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                              fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5,
                            )).animate().fadeIn(duration: 500.ms).slideX(begin: -0.03),
                          ]),
                        ),
                        Builder(builder: (_) {
                          final profile = ref.watch(_pharmacyProfileProvider);
                          final logoUrl = profile.valueOrNull?['logo']?.toString() ?? '';
                          return Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? cs.primary.withValues(alpha: 0.4) : cs.primary.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: isDark ? cs.primaryContainer.withValues(alpha: 0.3) : cs.primary.withValues(alpha: 0.1),
                              backgroundImage: logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
                              child: logoUrl.isNotEmpty
                                  ? null
                                  : Text(
                                      auth.user?.initials ?? '?',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cs.primary),
                                    ),
                            ),
                          );
                        }).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.85, 0.85)),
                      ]),
                      const SizedBox(height: 22),

                      // Quick Actions grid
                      GridView.count(
                        crossAxisCount: 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.82,
                        children: [
                          _QuickAction(icon: Icons.storefront_rounded, label: 'POS', onTap: () => context.go('/pos')),
                          _QuickAction(icon: Icons.point_of_sale_rounded, label: 'Sales', onTap: () => context.go('/sales')),
                          _QuickAction(icon: Icons.inventory_2_rounded, label: 'Inventory', onTap: () => context.go('/inventory')),
                          _QuickAction(icon: Icons.analytics_rounded, label: 'Analytics', onTap: () => context.go('/analytics')),
                          _QuickAction(icon: Icons.assessment_rounded, label: 'Reports', onTap: () => context.go('/reports')),
                          _QuickAction(icon: Icons.account_balance_rounded, label: 'Accounts', onTap: () => context.go('/accounts')),
                          _QuickAction(
                            icon: Icons.credit_card_rounded,
                            label: 'Credit',
                            onTap: () => context.go('/credits'),
                            badgeProvider: _creditCountProvider,
                          ),
                          _QuickAction(icon: Icons.shopping_cart_rounded, label: 'Purchase\nOrders', onTap: () => context.go('/purchase-orders')),
                        ],
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
          ),

          // ── Body ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Sales Analytics Section ──
                _SalesAnalyticsSection(),
                const SizedBox(height: 28),

                // ── Stock Health Section ──
                _StockHealthSection(),
                const SizedBox(height: 28),

                dash.when(
                  loading: () => const LoadingShimmer(lines: 4),
                  error: (e, _) => ErrorRetry(message: 'Failed to load dashboard', onRetry: () => ref.invalidate(_dashProvider)),
                  data: (data) {
                    final bill = data['billing'] ?? {};
                    final refData = data['referral'] ?? {};

                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // ── Top 10 Products ──
                      _TopProductsSection(),
                      const SizedBox(height: 28),

                      // ── Adhere Coins ──
                      _SectionTitle(title: 'Adhere Coins', icon: Icons.monetization_on_outlined),
                      const SizedBox(height: 12),
                      _CoinCard(
                        balance: '${refData['coin_balance'] ?? 0}',
                        referrals: refData['referral_count'] ?? 0,
                        totalEarned: refData['total_earned'] ?? 0,
                        onTap: () => context.go('/referral'),
                      ).animate().fadeIn(duration: 500.ms, delay: 200.ms).slideY(begin: 0.06),
                      const SizedBox(height: 28),

                      // ── Activity / API ──
                      _SectionTitle(title: 'API Usage', icon: Icons.api_rounded),
                      const SizedBox(height: 12),
                      _ApiUsageCard(
                        requests: _fmt((bill['current_month'] ?? {})['total_requests'] ?? 0),
                        cost: '${(bill['current_month'] ?? {})['cost_so_far'] ?? '0'}',
                        onTap: () => context.go('/billing'),
                      ).animate().fadeIn(duration: 500.ms, delay: 250.ms).slideY(begin: 0.06),
                      const SizedBox(height: 14),
                      _ApiWeeklyChart(dailyData: (bill['daily_last_30_days'] as List?) ?? []),
                    ]);
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _fmt(dynamic n) => NumberFormat.compact().format(n is int ? n : int.tryParse('$n') ?? 0);
}



// ─────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────

// ── Sales Analytics Section ──
class _SalesAnalyticsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compare = ref.watch(_salesCompareProvider);
    final period = ref.watch(_trendPeriod);
    final trend = ref.watch(_trendProvider(period));
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = NumberFormat.compactCurrency(symbol: 'KSH ', decimalDigits: 0);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Section title
      _SectionTitle(title: 'Sales Analytics', icon: Icons.trending_up_rounded),
      const SizedBox(height: 14),

      // ── Today vs Yesterday ──
      compare.when(
        loading: () => const LoadingShimmer(lines: 2),
        error: (e, _) => ErrorRetry(message: 'Failed to load sales', onRetry: () => ref.invalidate(_salesCompareProvider)),
        data: (d) {
          final todayRev = _toDouble(d['today']?['combined_revenue']);
          final yesterdayRev = _toDouble(d['yesterday']?['combined_revenue']);
          final monthRev = _toDouble(d['month']?['combined_revenue']);
          final yearRev = _toDouble(d['year']?['combined_revenue']);
          final todayCount = (d['today']?['combined_count'] ?? 0) as int;
          final yesterdayCount = (d['yesterday']?['combined_count'] ?? 0) as int;

          final dayDelta = yesterdayRev > 0 ? ((todayRev - yesterdayRev) / yesterdayRev * 100) : 0.0;

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Today vs Yesterday cards
            Row(children: [
              Expanded(child: _CompareCard(
                title: 'Today',
                value: fmt.format(todayRev),
                subValue: '$todayCount orders',
                delta: dayDelta,
                icon: Icons.today_rounded,
                accentColor: cs.primary,
                isDark: isDark,
              ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.05)),
              const SizedBox(width: 12),
              Expanded(child: _CompareCard(
                title: 'Yesterday',
                value: fmt.format(yesterdayRev),
                subValue: '$yesterdayCount orders',
                icon: Icons.history_rounded,
                accentColor: cs.secondary,
                isDark: isDark,
              ).animate().fadeIn(duration: 400.ms, delay: 50.ms).slideX(begin: 0.05)),
            ]),
            const SizedBox(height: 12),

            // Month vs Year cards
            Row(children: [
              Expanded(child: _CompareCard(
                title: 'This Month',
                value: fmt.format(monthRev),
                icon: Icons.calendar_month_rounded,
                accentColor: Colors.orange.shade600,
                isDark: isDark,
              ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideX(begin: -0.05)),
              const SizedBox(width: 12),
              Expanded(child: _CompareCard(
                title: 'This Year',
                value: fmt.format(yearRev),
                icon: Icons.date_range_rounded,
                accentColor: Colors.purple.shade500,
                isDark: isDark,
              ).animate().fadeIn(duration: 400.ms, delay: 150.ms).slideX(begin: 0.05)),
            ]),
          ]);
        },
      ),
      const SizedBox(height: 22),

      // ── Sales Trend Chart ──
      Row(children: [
        _SectionTitle(title: 'Sales Trend', icon: Icons.show_chart_rounded),
        const Spacer(),
        TextButton.icon(
          onPressed: () => _showCustomRange(context, ref),
          icon: const Icon(Icons.calendar_today, size: 14),
          label: const Text('Custom', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _FilterChip(label: 'Today', value: 'today', selected: period, onSelected: (v) => ref.read(_trendPeriod.notifier).state = v),
            _FilterChip(label: '7 Days', value: 'last7', selected: period, onSelected: (v) => ref.read(_trendPeriod.notifier).state = v),
            _FilterChip(label: '30 Days', value: 'last30', selected: period, onSelected: (v) => ref.read(_trendPeriod.notifier).state = v),
            _FilterChip(label: '90 Days', value: 'last90', selected: period, onSelected: (v) => ref.read(_trendPeriod.notifier).state = v),
            _FilterChip(label: 'This Year', value: 'year', selected: period, onSelected: (v) => ref.read(_trendPeriod.notifier).state = v),
          ],
        ),
      ),
      const SizedBox(height: 14),

      // Chart card
      trend.when(
        loading: () => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => SizedBox(height: 200, child: ErrorRetry(message: 'Failed to load chart', onRetry: () => ref.invalidate(_trendProvider(period)))),
        data: (d) {
          final dailyPos = (d['daily_pos'] as List?) ?? [];
          final dailyDisp = (d['daily_dispensing'] as List?) ?? [];

          // Merge POS + Dispensing by date
          final Map<String, double> merged = {};
          for (final e in dailyPos) {
            final date = e['date'] as String;
            merged[date] = (merged[date] ?? 0) + _toDouble(e['revenue']);
          }
          for (final e in dailyDisp) {
            final date = e['date'] as String;
            merged[date] = (merged[date] ?? 0) + _toDouble(e['revenue']);
          }
          final sortedDates = merged.keys.toList()..sort();
          final spots = sortedDates.asMap().entries.map((e) => FlSpot(e.key.toDouble(), merged[e.value]!)).toList();

          final totalRev = _toDouble(d['combined_revenue']);
          final totalCount = d['combined_count'] ?? 0;

          if (spots.isEmpty) {
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
              child: const SizedBox(height: 180, child: Center(child: Text('No sales data for this period'))),
            );
          }

          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Summary row
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Total Revenue', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
                    Text(NumberFormat.compactCurrency(symbol: 'KSH ', decimalDigits: 0).format(totalRev),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(10)),
                    child: Text('$totalCount orders', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary)),
                  ),
                ]),
                const SizedBox(height: 20),

                // Chart
                LayoutBuilder(
                  builder: (context, constraints) {
                    const double minPointSpacing = 48;
                    final chartWidth = spots.length > 7
                        ? (spots.length * minPointSpacing).clamp(constraints.maxWidth, double.infinity)
                        : constraints.maxWidth;

                    final chart = SizedBox(
                      width: chartWidth,
                      height: 180,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: _calcInterval(spots),
                            getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant.withValues(alpha: 0.15), strokeWidth: 1),
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(sideTitles: SideTitles(
                              showTitles: true, reservedSize: 50,
                              getTitlesWidget: (v, _) => Text(NumberFormat.compact().format(v), style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                            )),
                            bottomTitles: AxisTitles(sideTitles: SideTitles(
                              showTitles: true, reservedSize: 28,
                              interval: 1,
                              getTitlesWidget: (v, _) {
                                final idx = v.toInt();
                                if (idx < 0 || idx >= sortedDates.length) return const SizedBox();
                                final d = sortedDates[idx];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(d.length >= 10 ? DateFormat('dd/MM').format(DateTime.parse(d)) : d,
                                    style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                                );
                              },
                            )),
                          ),
                          borderData: FlBorderData(show: false),
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (_) => isDark ? cs.surfaceContainerHighest : cs.inverseSurface,
                              getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                                'KSH ${NumberFormat.compact().format(s.y)}',
                                TextStyle(color: isDark ? cs.onSurface : cs.onInverseSurface, fontWeight: FontWeight.w600, fontSize: 12),
                              )).toList(),
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              preventCurveOverShooting: true,
                              color: cs.primary,
                              barWidth: 2.5,
                              isStrokeCapRound: true,
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [cs.primary.withValues(alpha: 0.25), cs.primary.withValues(alpha: 0.0)],
                                ),
                              ),
                              dotData: FlDotData(
                                show: spots.length <= 14,
                                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 3, color: cs.primary, strokeWidth: 1.5, strokeColor: cs.surface),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );

                    if (chartWidth > constraints.maxWidth) {
                      return SizedBox(
                        height: 200,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: chart,
                        ),
                      );
                    }
                    return chart;
                  },
                ),
              ]),
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 200.ms);
        },
      ),
    ]);
  }

  double _toDouble(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;

  double _calcInterval(List<FlSpot> spots) {
    if (spots.isEmpty) return 1;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    if (maxY <= 0) return 1;
    return (maxY / 4).ceilToDouble();
  }

  void _showCustomRange(BuildContext context, WidgetRef ref) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: DateTime.now().subtract(const Duration(days: 7)), end: DateTime.now()),
    );
    if (range != null) {
      final from = DateFormat('yyyy-MM-dd').format(range.start);
      final to = DateFormat('yyyy-MM-dd').format(range.end);
      // Use custom range via the provider - we'll use a special key
      ref.read(_trendPeriod.notifier).state = 'custom:$from:$to';
    }
  }
}

// ── Stock Health Section ──
class _StockHealthSection extends ConsumerWidget {
  const _StockHealthSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(_dashProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionTitle(title: 'Stock Health', icon: Icons.health_and_safety_outlined),
      const SizedBox(height: 12),
      dash.when(
        loading: () => const LoadingShimmer(lines: 4),
        error: (e, _) => const SizedBox(),
        data: (data) {
          final inv = data['inventory'] ?? {};
          final total = _d(inv['total_items'] ?? inv['total_products']);
          final low = _d(inv['low_stock_count']);
          final oos = _d(inv['out_of_stock']);
          final healthy = (total - low - oos).clamp(0.0, double.infinity);
          final exp30 = _d(inv['expiring_30_days'] ?? inv['expiring_soon']);
          final exp90 = _d(inv['expiring_90_days']);
          final expired = _d(inv['expired_batches']);

          final stockSegments = <_ChartSegment>[
            _ChartSegment('In Stock', healthy, const Color(0xFF22C55E)),
            _ChartSegment('Low Stock', low, Colors.orange.shade600),
            _ChartSegment('Out of Stock', oos, Colors.red.shade600),
          ];

          final expirySegments = <_ChartSegment>[
            _ChartSegment('Expired', expired, Colors.red.shade700),
            _ChartSegment('Expiring 30d', exp30, Colors.orange.shade600),
            _ChartSegment('Expiring 90d', exp90, Colors.amber.shade600),
          ];

          return Column(children: [
            // Stock distribution donut
            _DonutCard(
              title: 'Stock Distribution',
              subtitle: '${total.toInt()} total items',
              segments: stockSegments,
              isDark: isDark,
              cs: cs,
            ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05),
            const SizedBox(height: 14),
            // Expiry status donut
            _DonutCard(
              title: 'Expiry Status',
              subtitle: '${(exp30 + exp90 + expired).toInt()} items need attention',
              segments: expirySegments,
              isDark: isDark,
              cs: cs,
            ).animate().fadeIn(duration: 500.ms, delay: 100.ms).slideY(begin: 0.05),
          ]);
        },
      ),
    ]);
  }

  double _d(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
}

class _ChartSegment {
  final String label;
  final double value;
  final Color color;
  const _ChartSegment(this.label, this.value, this.color);
}

class _DonutCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_ChartSegment> segments;
  final bool isDark;
  final ColorScheme cs;

  const _DonutCard({
    required this.title,
    required this.subtitle,
    required this.segments,
    required this.isDark,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<double>(0, (s, e) => s + e.value);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          Row(children: [
            // Donut chart
            SizedBox(
              width: 120,
              height: 120,
              child: total == 0
                  ? Center(child: Text('No data', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)))
                  : PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 32,
                        startDegreeOffset: -90,
                        sections: segments.where((s) => s.value > 0).map((s) {
                          final pct = (s.value / total * 100);
                          return PieChartSectionData(
                            value: s.value,
                            color: s.color,
                            radius: 22,
                            title: '${pct.toStringAsFixed(0)}%',
                            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                            titlePositionPercentageOffset: 0.55,
                          );
                        }).toList(),
                      ),
                    ),
            ),
            const SizedBox(width: 20),
            // Legend
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: segments.map((s) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(3)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(s.label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      ),
                      Text(
                        '${s.value.toInt()}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface),
                      ),
                    ]),
                  );
                }).toList(),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Top Products Section ──
class _TopProductsSection extends ConsumerWidget {
  const _TopProductsSection();

  static const _barColors = [
    Color(0xFF2DD4BF), // teal
    Color(0xFF3B82F6), // blue
    Color(0xFF22C55E), // green
    Color(0xFFF59E0B), // amber
    Color(0xFF8B5CF6), // purple
    Color(0xFF0EA5E9), // sky
    Color(0xFFEC4899), // pink
    Color(0xFFF97316), // orange
    Color(0xFF14B8A6), // teal-dark
    Color(0xFF6366F1), // indigo
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topProducts = ref.watch(_topProductsProvider);
    final cs = Theme.of(context).colorScheme;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionTitle(title: 'Top Selling Products', icon: Icons.trending_up_rounded),
      const SizedBox(height: 12),
      topProducts.when(
        loading: () => const LoadingShimmer(lines: 6),
        error: (e, _) => const SizedBox(),
        data: (items) {
          if (items.isEmpty) {
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
              child: const SizedBox(height: 120, child: Center(child: Text('No sales data this month'))),
            );
          }

          final maxRev = items.fold<double>(0.0, (m, p) {
            final rev = (p['total_revenue'] is num) ? (p['total_revenue'] as num).toDouble() : double.tryParse('${p['total_revenue']}') ?? 0;
            return rev > m ? rev : m;
          });

          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(items.length, (i) {
                  final p = items[i];
                  final name = p['medication_name'] ?? 'Item';
                  final qty = (p['total_qty'] is num) ? (p['total_qty'] as num).toInt() : int.tryParse('${p['total_qty']}') ?? 0;
                  final rev = (p['total_revenue'] is num) ? (p['total_revenue'] as num).toDouble() : double.tryParse('${p['total_revenue']}') ?? 0;
                  final pct = maxRev > 0 ? (rev / maxRev) : 0.0;
                  final barColor = _barColors[i % _barColors.length];

                  return Padding(
                    padding: EdgeInsets.only(bottom: i < items.length - 1 ? 14 : 0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text('${i + 1}. ', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
                        Expanded(
                          child: Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface), overflow: TextOverflow.ellipsis),
                        ),
                        Text(
                          NumberFormat.compactCurrency(symbol: 'KSH ', decimalDigits: 0).format(rev),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 7,
                          backgroundColor: cs.outlineVariant.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation(barColor),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text('$qty units sold', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    ]),
                  ).animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: 50 * i)).slideX(begin: 0.03);
                }),
              ),
            ),
          ).animate().fadeIn(duration: 500.ms);
        },
      ),
    ]);
  }
}

// ── Compare Card ──
class _CompareCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subValue;
  final double? delta;
  final IconData icon;
  final Color accentColor;
  final bool isDark;
  const _CompareCard({required this.title, required this.value, required this.icon, required this.accentColor, required this.isDark, this.subValue, this.delta});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: accentColor),
          ),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
        ]),
        const SizedBox(height: 12),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cs.onSurface, letterSpacing: -0.5)),
        if (subValue != null) ...[
          const SizedBox(height: 2),
          Text(subValue!, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
        if (delta != null && delta != 0) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: delta! > 0 ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(delta! > 0 ? Icons.trending_up : Icons.trending_down, size: 12, color: delta! > 0 ? Colors.green : Colors.red),
              const SizedBox(width: 3),
              Text('${delta!.abs().toStringAsFixed(1)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: delta! > 0 ? Colors.green : Colors.red)),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ── Filter Chip ──
class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onSelected;
  const _FilterChip({required this.label, required this.value, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isActive = selected == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isActive ? cs.primary : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => onSelected(value),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Text(label, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
            )),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: cs.primary),
      ),
      const SizedBox(width: 10),
      Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3)),
    ]);
  }
}

class _CoinCard extends StatelessWidget {
  final String balance;
  final int referrals;
  final dynamic totalEarned;
  final VoidCallback onTap;
  const _CoinCard({required this.balance, required this.referrals, required this.totalEarned, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Colors.amber.shade700, Colors.orange.shade600, Colors.deepOrange.shade400],
            ),
          ),
          child: Stack(children: [
            // Decorative circles
            Positioned(right: -20, top: -20, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)))),
            Positioned(right: 30, bottom: -30, child: Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)))),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                // Coin icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Image.asset('assets/images/adhere_coin.png', width: 36, height: 36),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('COIN BALANCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.75), letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text(balance, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(children: [
                    Text('$referrals', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                    Text('Referrals', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.8))),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ApiUsageCard extends StatelessWidget {
  final String requests;
  final String cost;
  final VoidCallback onTap;
  const _ApiUsageCard({required this.requests, required this.cost, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3))),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [cs.primary, cs.tertiary]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.api_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(requests, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              const SizedBox(height: 2),
              Text('Requests this month', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
              child: Text('$cost KSH', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cs.primary)),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: cs.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}

class _ApiWeeklyChart extends StatelessWidget {
  final List dailyData;
  const _ApiWeeklyChart({required this.dailyData});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    // Get start of this week (Monday)
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekDays = List.generate(7, (i) {
      final d = monday.add(Duration(days: i));
      return DateFormat('yyyy-MM-dd').format(d);
    });
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Build a map from date string -> request_count
    final Map<String, int> dataMap = {};
    for (final entry in dailyData) {
      final date = entry['date']?.toString() ?? '';
      final count = (entry['request_count'] is num) ? (entry['request_count'] as num).toInt() : int.tryParse('${entry['request_count']}') ?? 0;
      dataMap[date] = count;
    }

    final bars = <BarChartGroupData>[];
    double maxY = 0;
    for (int i = 0; i < 7; i++) {
      final val = (dataMap[weekDays[i]] ?? 0).toDouble();
      if (val > maxY) maxY = val;
      bars.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: val,
          width: 20,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [cs.primary.withValues(alpha: 0.6), cs.primary],
          ),
        ),
      ]));
    }

    if (maxY == 0) maxY = 10;
    final double interval = (maxY / 4).ceilToDouble().clamp(1.0, double.infinity);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('This Week', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.onSurface)),
          const SizedBox(height: 4),
          Text('Daily API requests', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxY * 1.15,
                barGroups: bars,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant.withValues(alpha: 0.15), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: interval,
                    getTitlesWidget: (v, _) => Text(NumberFormat.compact().format(v), style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                  )),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= 7) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(dayLabels[idx], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant)),
                      );
                    },
                  )),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => cs.surface,
                    getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                      '${rod.toY.toInt()} requests',
                      TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 300.ms);
  }
}

class _QuickAction extends ConsumerWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final AutoDisposeFutureProvider<int>? badgeProvider;
  const _QuickAction({required this.icon, required this.label, required this.onTap, this.badgeProvider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badgeCount = badgeProvider != null ? ref.watch(badgeProvider!).valueOrNull : null;

    Widget iconWidget = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? cs.primary.withValues(alpha: 0.15)
            : cs.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: cs.primary, size: 22),
    );

    if (badgeCount != null && badgeCount > 0) {
      iconWidget = Badge(
        label: Text('$badgeCount',
            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFFEF4444),
        child: iconWidget,
      );
    }

    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : cs.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : cs.primary.withValues(alpha: 0.08)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            iconWidget,
            const SizedBox(height: 8),
            Text(label, style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
            ), textAlign: TextAlign.center),
          ]),
        ),
    );
  }
}
