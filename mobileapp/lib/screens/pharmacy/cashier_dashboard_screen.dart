import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/api.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common.dart';

// Safe numeric parsing helpers (API may return strings or nums)
double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

// ═══════════════════════════════════════════════════════════════════════════
//  PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Today's sales stats
final _cashierStatsProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/reports/sales-summary/', queryParameters: {'period': 'today'});
  return res.data as Map<String, dynamic>;
});

/// Yesterday's sales for comparison
final _yesterdayStatsProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/reports/sales-summary/', queryParameters: {'period': 'yesterday'});
  return res.data as Map<String, dynamic>;
});

/// Recent transactions (last 20)
final _recentTxProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/pos/transactions/', queryParameters: {'page_size': 20, 'ordering': '-created_at'});
  final data = res.data;
  final list = data is List ? data : (data?['results'] as List?) ?? [];
  return List<Map<String, dynamic>>.from(list);
});

/// Parked sales count
final _parkedSalesProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/pos/parked-sales/', queryParameters: {'page_size': 1});
  final data = res.data;
  if (data is Map && data['count'] != null) return data['count'] as int;
  if (data is List) return (data).length;
  return 0;
});

/// Credit sales summary
final _creditSummaryProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/pos/credits/summary/');
  return res.data as Map<String, dynamic>;
});

// ═══════════════════════════════════════════════════════════════════════════
//  CASHIER DASHBOARD
// ═══════════════════════════════════════════════════════════════════════════

class CashierDashboardScreen extends ConsumerWidget {
  const CashierDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateFormat('EEEE, MMM d').format(DateTime.now());
    final greeting = _greeting();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_cashierStatsProvider);
        ref.invalidate(_yesterdayStatsProvider);
        ref.invalidate(_recentTxProvider);
        ref.invalidate(_parkedSalesProvider);
        ref.invalidate(_creditSummaryProvider);
      },
      child: CustomScrollView(
        slivers: [
          // ── Hero Header ──
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF0A0A0A), const Color(0xFF111111)]
                      : [const Color(0xFFF8FAFC), const Color(0xFFFFFFFF)],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF1F1F1F) : cs.outlineVariant.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Date + greeting
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.calendar_today_rounded, size: 11, color: cs.onSurfaceVariant),
                        const SizedBox(width: 5),
                        Text(now, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w500)),
                      ]),
                    ).animate().fadeIn(duration: 300.ms),
                    const SizedBox(height: 10),
                    Text('$greeting 👋', style: TextStyle(
                      color: cs.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.w400,
                    )).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: 2),
                    Text(auth.user?.fullName ?? 'Cashier', style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5,
                    )).animate().fadeIn(duration: 500.ms).slideX(begin: -0.03),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cs.tertiary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Cashier', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.tertiary)),
                    ),
                    const SizedBox(height: 24),

                    // ── Open POS Button ──
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: () => context.go('/pos'),
                        icon: const Icon(Icons.storefront_rounded, size: 24),
                        label: const Text('Open POS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.05),
                    const SizedBox(height: 14),

                    // ── Quick Actions ──
                    Row(children: [
                      Expanded(child: _QuickActionChip(
                        icon: Icons.history_rounded,
                        label: 'Sales History',
                        onTap: () => context.go('/sales'),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _QuickActionChip(
                        icon: Icons.pause_circle_outline_rounded,
                        label: 'Parked Sales',
                        badge: ref.watch(_parkedSalesProvider).valueOrNull ?? 0,
                        onTap: () => context.go('/pos/parked'),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _QuickActionChip(
                        icon: Icons.credit_card_rounded,
                        label: 'Credits',
                        onTap: () => context.go('/credits'),
                      )),
                    ]).animate().fadeIn(duration: 500.ms, delay: 200.ms),
                  ]),
                ),
              ),
            ),
          ),

          // ── Body ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Today's Performance ──
                _TodayPerformanceSection(),
                const SizedBox(height: 24),

                // ── Credit Summary ──
                _CreditSummaryCard(),
                const SizedBox(height: 24),

                // ── Recent Transactions ──
                _RecentTransactionsSection(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TODAY'S PERFORMANCE
// ═══════════════════════════════════════════════════════════════════════════

class _TodayPerformanceSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(_cashierStatsProvider);
    final yesterdayAsync = ref.watch(_yesterdayStatsProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = NumberFormat('#,##0');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.trending_up_rounded, size: 20, color: cs.primary),
        const SizedBox(width: 8),
        Text("Today's Performance", style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
        )),
      ]),
      const SizedBox(height: 14),

      todayAsync.when(
        loading: () => const LoadingShimmer(lines: 2),
        error: (e, _) => ErrorRetry(message: 'Failed to load stats', onRetry: () => ref.invalidate(_cashierStatsProvider)),
        data: (today) {
          final todayRevenue = _toDouble(today['total_revenue']);
          final todayCount = _toInt(today['total_transactions']);
          final todayItems = _toInt(today['total_items_sold']);

          // Yesterday comparison
          final yesterday = yesterdayAsync.valueOrNull;
          final yesterdayRevenue = _toDouble(yesterday?['total_revenue']);
          final revenueChange = yesterdayRevenue > 0
              ? ((todayRevenue - yesterdayRevenue) / yesterdayRevenue * 100).round()
              : 0;

          return Column(children: [
            // Main revenue card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [cs.primary.withValues(alpha: 0.15), cs.primary.withValues(alpha: 0.05)]
                      : [cs.primary.withValues(alpha: 0.08), cs.primary.withValues(alpha: 0.02)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text("Today's Revenue", style: TextStyle(
                    color: cs.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500,
                  )),
                  const Spacer(),
                  if (revenueChange != 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (revenueChange > 0 ? Colors.green : Colors.red).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          revenueChange > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                          size: 12,
                          color: revenueChange > 0 ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${revenueChange.abs()}% vs yesterday',
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: revenueChange > 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ]),
                    ),
                ]),
                const SizedBox(height: 8),
                Text(
                  'KES ${fmt.format(todayRevenue)}',
                  style: TextStyle(
                    fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  _MiniStat(icon: Icons.receipt_long_rounded, label: 'Sales', value: '$todayCount', color: cs.primary),
                  const SizedBox(width: 20),
                  _MiniStat(icon: Icons.shopping_bag_rounded, label: 'Items Sold', value: fmt.format(todayItems), color: cs.tertiary),
                  const SizedBox(width: 20),
                  _MiniStat(
                    icon: Icons.speed_rounded,
                    label: 'Avg Sale',
                    value: todayCount > 0 ? 'KES ${fmt.format(todayRevenue / todayCount)}' : '—',
                    color: Colors.orange,
                  ),
                ]),
              ]),
            ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.04),

            const SizedBox(height: 12),

            // Payment method breakdown
            if ((today['by_payment_method'] as List?)?.isNotEmpty == true)
              _PaymentBreakdown(methods: List<Map<String, dynamic>>.from(today['by_payment_method'] ?? [])),
          ]);
        },
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CREDIT SUMMARY
// ═══════════════════════════════════════════════════════════════════════════

class _CreditSummaryCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditAsync = ref.watch(_creditSummaryProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return creditAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        final totalOwed = _toDouble(data['total_outstanding']);
        final count = _toInt(data['count']);
        if (count == 0 && totalOwed == 0) return const SizedBox.shrink();

        final fmt = NumberFormat('#,##0');
        return InkWell(
          onTap: () => context.go('/credits'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.orange.withValues(alpha: 0.08) : Colors.orange.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.credit_card_rounded, color: Colors.orange, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Outstanding Credits', style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13, color: cs.onSurface,
                )),
                const SizedBox(height: 2),
                Text('$count unsettled · KES ${fmt.format(totalOwed)} owed', style: TextStyle(
                  fontSize: 12, color: cs.onSurfaceVariant,
                )),
              ])),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ]),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  RECENT TRANSACTIONS
// ═══════════════════════════════════════════════════════════════════════════

class _RecentTransactionsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(_recentTxProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = NumberFormat('#,##0');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.receipt_long_rounded, size: 20, color: cs.primary),
        const SizedBox(width: 8),
        Text('Recent Sales', style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
        )),
        const Spacer(),
        TextButton.icon(
          onPressed: () => context.go('/sales'),
          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
          label: const Text('View All', style: TextStyle(fontSize: 12)),
        ),
      ]),
      const SizedBox(height: 10),

      txAsync.when(
        loading: () => const LoadingShimmer(lines: 4),
        error: (e, _) => ErrorRetry(message: 'Failed to load transactions', onRetry: () => ref.invalidate(_recentTxProvider)),
        data: (transactions) {
          if (transactions.isEmpty) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(children: [
                Icon(Icons.receipt_long_outlined, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                Text('No sales yet today', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('Open POS to start selling', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
              ]),
            );
          }

          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: transactions.take(10).toList().asMap().entries.map((entry) {
                  final i = entry.key;
                  final tx = entry.value;
                  final total = _toDouble(tx['total']);
                  final method = tx['payment_method'] ?? 'cash';
                  final itemCount = (tx['items'] as List?)?.length ?? 0;
                  final createdAt = tx['created_at'] ?? '';
                  final time = createdAt.isNotEmpty
                      ? DateFormat('HH:mm').format(DateTime.tryParse(createdAt)?.toLocal() ?? DateTime.now())
                      : '';
                  final receiptNo = tx['receipt_number'] ?? '#${tx['id']}';

                  return Container(
                    decoration: BoxDecoration(
                      color: i.isEven
                          ? (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.transparent)
                          : (isDark ? Colors.transparent : cs.surfaceContainerHighest.withValues(alpha: 0.2)),
                    ),
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _methodColor(method).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_methodIcon(method), size: 20, color: _methodColor(method)),
                      ),
                      title: Row(children: [
                        Expanded(child: Text(receiptNo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                        Text('KES ${fmt.format(total)}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cs.primary)),
                      ]),
                      subtitle: Row(children: [
                        Text('$itemCount item${itemCount != 1 ? 's' : ''} · $method', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                        const Spacer(),
                        Text(time, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 200.ms);
        },
      ),
    ]);
  }

  static Color _methodColor(String method) {
    switch (method) {
      case 'mpesa': return Colors.green;
      case 'card': return Colors.blue;
      case 'insurance': return Colors.purple;
      case 'credit': return Colors.orange;
      default: return Colors.teal;
    }
  }

  static IconData _methodIcon(String method) {
    switch (method) {
      case 'mpesa': return Icons.phone_android_rounded;
      case 'card': return Icons.credit_card_rounded;
      case 'insurance': return Icons.health_and_safety_rounded;
      case 'credit': return Icons.account_balance_wallet_rounded;
      default: return Icons.payments_rounded;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;
  const _QuickActionChip({required this.icon, required this.label, required this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainerHighest.withValues(alpha: 0.5) : cs.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Badge(
            isLabelVisible: badge > 0,
            label: Text('$badge', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
            backgroundColor: cs.error,
            child: Icon(icon, size: 22, color: cs.primary),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurface), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
            Text(label, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
      ]),
    );
  }
}

class _PaymentBreakdown extends StatelessWidget {
  final List<Map<String, dynamic>> methods;
  const _PaymentBreakdown({required this.methods});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = NumberFormat('#,##0');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHighest.withValues(alpha: 0.3) : cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('By Payment Method', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: methods.map((m) {
          final method = m['payment_method'] ?? m['method'] ?? '';
          final amount = _toDouble(m['total'] ?? m['amount']);
          final count = _toInt(m['count']);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _color(method).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _color(method).withValues(alpha: 0.2)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_icon(method), size: 14, color: _color(method)),
              const SizedBox(width: 6),
              Text('$method ($count)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _color(method))),
              const SizedBox(width: 6),
              Text('KES ${fmt.format(amount)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurface)),
            ]),
          );
        }).toList()),
      ]),
    ).animate().fadeIn(duration: 400.ms, delay: 150.ms);
  }

  Color _color(String m) {
    switch (m.toLowerCase()) {
      case 'mpesa': return Colors.green;
      case 'card': return Colors.blue;
      case 'insurance': return Colors.purple;
      case 'credit': return Colors.orange;
      default: return Colors.teal;
    }
  }

  IconData _icon(String m) {
    switch (m.toLowerCase()) {
      case 'mpesa': return Icons.phone_android_rounded;
      case 'card': return Icons.credit_card_rounded;
      case 'insurance': return Icons.health_and_safety_rounded;
      case 'credit': return Icons.account_balance_wallet_rounded;
      default: return Icons.payments_rounded;
    }
  }
}
