import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/stat_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../pos/repository/sales_analytics_repository.dart';
import '../../inventory/repository/inventory_repository.dart';
import '../../../core/network/api_client.dart';

final _dashboardDataProvider = FutureProvider.autoDispose<_DashboardData>((ref) async {
  final dio = ApiClient.instance;

  // Fetch all data in parallel, catching individual failures
  final results = await Future.wait<dynamic>([
    SalesAnalyticsRepository()
        .getSalesAnalytics(period: 'today')
        .catchError((_) => <String, dynamic>{}),
    SalesAnalyticsRepository()
        .getSalesAnalytics(period: 'month')
        .catchError((_) => <String, dynamic>{}),
    InventoryRepository()
        .getAnalytics()
        .catchError((_) => <String, dynamic>{}),
    dio
        .get('/pos/transactions/today/')
        .then((r) => r.data as List<dynamic>)
        .catchError((_) => <dynamic>[]),
    dio
        .get('/inventory/stocks/low_stock/')
        .then((r) => r.data['results'] as List<dynamic>? ?? <dynamic>[])
        .catchError((_) => <dynamic>[]),
    dio
        .get('/inventory/stocks/expiring_soon/',
            queryParameters: {'days': 30})
        .then((r) => r.data as List<dynamic>)
        .catchError((_) => <dynamic>[]),
    // Additional data for trend computation and Action Center
    SalesAnalyticsRepository()
        .getSalesAnalytics(period: 'week')
        .catchError((_) => <String, dynamic>{}),
    dio
        .get('/exchange/pharmacy/orders/',
            queryParameters: {'status': 'pending', 'page_size': 1})
        .then((r) {
          final d = r.data;
          if (d is Map) {
            return (d['count'] as num?)?.toInt() ??
                (d['results'] is List ? (d['results'] as List).length : 0);
          }
          if (d is List) return d.length;
          return 0;
        })
        .catchError((_) => 0),
  ]);

  return _DashboardData(
    todaySales: results[0] as Map<String, dynamic>,
    monthSales: results[1] as Map<String, dynamic>,
    inventoryStats: results[2] as Map<String, dynamic>,
    todayTransactions: results[3] as List<dynamic>,
    lowStock: results[4] as List<dynamic>,
    expiringSoon: results[5] as List<dynamic>,
    weekSales: results[6] as Map<String, dynamic>,
    pendingOrdersCount: results[7] as int,
  );
});

class _DashboardData {
  final Map<String, dynamic> todaySales;
  final Map<String, dynamic> monthSales;
  final Map<String, dynamic> inventoryStats;
  final List<dynamic> todayTransactions;
  final List<dynamic> lowStock;
  final List<dynamic> expiringSoon;
  final Map<String, dynamic> weekSales;
  final int pendingOrdersCount;
  _DashboardData({
    required this.todaySales,
    required this.monthSales,
    required this.inventoryStats,
    required this.todayTransactions,
    required this.lowStock,
    required this.expiringSoon,
    required this.weekSales,
    required this.pendingOrdersCount,
  });
}

class PharmacyDashboardScreen extends ConsumerWidget {
  const PharmacyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final dashboardAsync = ref.watch(_dashboardDataProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome + refresh
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.tenantName ?? 'Pharmacy Dashboard',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Welcome back, ${user?.firstName ?? 'Pharmacist'} — here\'s your overview for today',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(_dashboardDataProvider),
              ),
            ],
          ),
          const SizedBox(height: 24),

          dashboardAsync.when(
            loading: () => _buildSkeletonDashboard(),
            error: (e, _) => _buildFallbackDashboard(context, ref),
            data: (data) => _buildLiveDashboard(context, ref, data),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveDashboard(BuildContext context, WidgetRef ref, _DashboardData data) {
    final sales = data.todaySales;
    final month = data.monthSales;
    final week = data.weekSales;
    final inv = data.inventoryStats;
    final txCount = (sales['transaction_count'] as num?)?.toInt() ?? 0;
    final revenue = (sales['total_revenue'] as num?)?.toDouble() ?? 0;
    final avgTx = sales['avg_transaction'] ?? 0;
    final totalDiscount = sales['total_discount'] ?? 0;
    final lowStockCount = inv['low_stock_count'] ?? 0;
    final expiringCount = inv['expiring_30_days'] ?? 0;
    final outOfStock = inv['out_of_stock'] ?? 0;
    final totalItems = inv['total_items'] ?? 0;
    final retailValue = inv['total_retail_value'] ?? 0;
    final costValue = inv['total_cost_value'] ?? 0;
    final profit = inv['potential_profit'] ?? 0;
    final expiredBatches = inv['expired_batches'] ?? 0;
    final paymentBreakdown =
        sales['payment_breakdown'] as List<dynamic>? ?? [];
    final topItems = sales['top_selling_items'] as List<dynamic>? ?? [];
    final categorySales = sales['category_sales'] as List<dynamic>? ?? [];
    final monthlyRevenue = month['total_revenue'] ?? 0;
    final monthlyTxCount = month['transaction_count'] ?? 0;

    // Trend deltas vs 7-day average
    final weekRevenue = (week['total_revenue'] as num?)?.toDouble() ?? 0;
    final weekTxCount = (week['transaction_count'] as num?)?.toInt() ?? 0;
    final weekDailyRevAvg = weekRevenue / 7;
    final weekDailyTxAvg = weekTxCount / 7;
    final revTrend = weekDailyRevAvg > 0
        ? ((revenue - weekDailyRevAvg) / weekDailyRevAvg * 100)
        : null;
    final txTrend = weekDailyTxAvg > 0
        ? ((txCount - weekDailyTxAvg) / weekDailyTxAvg * 100)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Action Center ──
        _buildActionCenter(context, ref, data),

        // ── Row 1: Today's Sales KPIs ──
        Text('Today\'s Performance',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final crossCount = constraints.maxWidth > 1100
              ? 6
              : constraints.maxWidth > 700
                  ? 3
                  : 2;
          final cardWidth =
              (constraints.maxWidth - (crossCount - 1) * 12) / crossCount;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                  width: cardWidth,
                  child: StatCard(
                      icon: Icons.receipt_long,
                      title: 'Transactions',
                      value: '$txCount',
                      color: AppColors.primary,
                      trend: txTrend,
                      trendLabel: 'vs 7-day avg',
                      onTap: () => context.push('/pos/history'))),
              SizedBox(
                  width: cardWidth,
                  child: StatCard(
                      icon: Icons.attach_money,
                      title: 'Revenue',
                      value: 'KSh ${_fmt(revenue)}',
                      color: AppColors.success,
                      trend: revTrend,
                      trendLabel: 'vs 7-day avg',
                      onTap: () => context.push('/pos/history'))),
              SizedBox(
                  width: cardWidth,
                  child: StatCard(
                      icon: Icons.trending_up,
                      title: 'Avg Sale',
                      value: 'KSh ${_fmt(avgTx)}',
                      color: AppColors.secondary,
                      onTap: () => context.push('/analytics'))),
              SizedBox(
                  width: cardWidth,
                  child: StatCard(
                      icon: Icons.discount_outlined,
                      title: 'Discounts',
                      value: 'KSh ${_fmt(totalDiscount)}',
                      color: AppColors.warning,
                      onTap: () => context.push('/pos/history'))),
              SizedBox(
                  width: cardWidth,
                  child: StatCard(
                      icon: Icons.calendar_month,
                      title: 'Month Revenue',
                      value: 'KSh ${_fmt(monthlyRevenue)}',
                      color: const Color(0xFF8B5CF6),
                      onTap: () => context.push('/analytics'))),
              SizedBox(
                  width: cardWidth,
                  child: StatCard(
                      icon: Icons.shopping_cart,
                      title: 'Month Sales',
                      value: '$monthlyTxCount',
                      color: const Color(0xFFEC4899),
                      onTap: () => context.push('/pos/history'))),
            ],
          );
        }),
        const SizedBox(height: 24),

        // ── Row 2: Inventory KPIs ──
        Text('Inventory Status',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final crossCount = constraints.maxWidth > 1100
              ? 6
              : constraints.maxWidth > 700
                  ? 3
                  : 2;
          final cardWidth =
              (constraints.maxWidth - (crossCount - 1) * 12) / crossCount;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                  width: cardWidth,
                  child: StatCard(
                      icon: Icons.inventory_2,
                      title: 'Total Items',
                      value: '$totalItems',
                      color: AppColors.primary,
                      onTap: () => context.push('/inventory'))),
              SizedBox(
                  width: cardWidth,
                  child: StatCard(
                      icon: Icons.warning_amber,
                      title: 'Low Stock',
                      value: '$lowStockCount',
                      color: AppColors.warning,
                      onTap: () => context.push('/alerts'))),
              SizedBox(
                  width: cardWidth,
                  child: StatCard(
                      icon: Icons.remove_shopping_cart,
                      title: 'Out of Stock',
                      value: '$outOfStock',
                      color: AppColors.error,
                      onTap: () => context.push('/inventory'))),
              SizedBox(
                  width: cardWidth,
                  child: StatCard(
                      icon: Icons.event_busy,
                      title: 'Expiring (30d)',
                      value: '$expiringCount',
                      color: const Color(0xFFF97316),
                      onTap: () => context.push('/alerts'))),
              SizedBox(
                  width: cardWidth,
                  child: StatCard(
                      icon: Icons.delete_outline,
                      title: 'Expired',
                      value: '$expiredBatches',
                      color: AppColors.error,
                      onTap: () => context.push('/alerts'))),
              SizedBox(
                  width: cardWidth,
                  child: StatCard(
                      icon: Icons.monetization_on,
                      title: 'Stock Value',
                      value: 'KSh ${_fmt(retailValue)}',
                      color: AppColors.success,
                      onTap: () => context.push('/inventory'))),
            ],
          );
        }),
        const SizedBox(height: 24),

        // ── Quick Actions ──
        Text('Quick Actions',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickAction(
                icon: Icons.point_of_sale_outlined,
                label: 'New Sale',
                color: AppColors.primary,
                onTap: () => context.push('/pos')),
            _QuickAction(
                icon: Icons.inventory_2_outlined,
                label: 'Add Stock',
                color: AppColors.success,
                onTap: () => context.push('/inventory/new')),
            _QuickAction(
                icon: Icons.analytics_outlined,
                label: 'Analytics',
                color: AppColors.secondary,
                onTap: () => context.push('/analytics')),
            _QuickAction(
                icon: Icons.assessment_outlined,
                label: 'Reports',
                color: AppColors.warning,
                onTap: () => context.push('/reports')),
            _QuickAction(
                icon: Icons.local_shipping_outlined,
                label: 'Suppliers',
                color: const Color(0xFF8B5CF6),
                onTap: () => context.push('/suppliers')),
            _QuickAction(
                icon: Icons.shopping_cart_outlined,
                label: 'Purchase Orders',
                color: const Color(0xFF06B6D4),
                onTap: () => context.push('/purchase-orders')),
          ],
        ),
        const SizedBox(height: 24),

        // ── Row 3: Payment Breakdown + Top Selling + Category Sales ──
        LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth > 1000) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: _buildPaymentBreakdown(context, paymentBreakdown)),
                const SizedBox(width: 16),
                Expanded(child: _buildTopSellingItems(context, topItems)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildCategorySales(context, categorySales)),
              ],
            );
          }
          if (constraints.maxWidth > 600) {
            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildPaymentBreakdown(
                        context, paymentBreakdown)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildTopSellingItems(context, topItems)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildCategorySales(context, categorySales),
              ],
            );
          }
          return Column(
            children: [
              _buildPaymentBreakdown(context, paymentBreakdown),
              const SizedBox(height: 16),
              _buildTopSellingItems(context, topItems),
              const SizedBox(height: 16),
              _buildCategorySales(context, categorySales),
            ],
          );
        }),
        const SizedBox(height: 24),

        // ── Row 4: Stock Valuation ──
        _buildStockValuation(context, costValue, retailValue, profit),
        const SizedBox(height: 24),

        // ── Row 5: Low Stock Alerts + Expiring Soon + Today's Transactions ──
        LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth > 1000) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: _buildLowStockAlerts(context, data.lowStock)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildExpiringSoon(context, data.expiringSoon)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildTodayTransactions(
                        context, data.todayTransactions)),
              ],
            );
          }
          if (constraints.maxWidth > 600) {
            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildLowStockAlerts(
                        context, data.lowStock)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildExpiringSoon(
                        context, data.expiringSoon)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTodayTransactions(context, data.todayTransactions),
              ],
            );
          }
          return Column(
            children: [
              _buildLowStockAlerts(context, data.lowStock),
              const SizedBox(height: 16),
              _buildExpiringSoon(context, data.expiringSoon),
              const SizedBox(height: 16),
              _buildTodayTransactions(context, data.todayTransactions),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildPaymentBreakdown(
      BuildContext context, List<dynamic> breakdown) {
    final methodIcons = <String, IconData>{
      'cash': Icons.payments_outlined,
      'card': Icons.credit_card_outlined,
      'mpesa': Icons.phone_android_outlined,
      'insurance': Icons.health_and_safety_outlined,
    };
    final methodColors = <String, Color>{
      'cash': AppColors.success,
      'card': AppColors.secondary,
      'mpesa': const Color(0xFF22C55E),
      'insurance': const Color(0xFF8B5CF6),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payment, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('Payment Methods',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 16),
            if (breakdown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: Text('No payments today',
                        style: TextStyle(color: AppColors.textSecondary))),
              ),
            ...breakdown.map((item) {
              final method =
                  (item['payment_method'] as String?) ?? 'cash';
              final count = item['count'] ?? 0;
              final total = item['total'] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (methodColors[method] ?? AppColors.primary)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(methodIcons[method] ?? Icons.payment,
                          size: 18,
                          color: methodColors[method] ?? AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(method.toUpperCase(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('$count transactions',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                    Text('KSh ${_fmt(total)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSellingItems(BuildContext context, List<dynamic> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events,
                    size: 18, color: AppColors.warning),
                const SizedBox(width: 8),
                const Text('Top Selling Today',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/analytics/top-products'),
                  child: const Text('View All', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: Text('No sales today',
                        style: TextStyle(color: AppColors.textSecondary))),
              ),
            ...items.take(5).toList().asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final name = item['medication_name'] ?? 'Unknown';
              final qty = item['total_qty'] ?? 0;
              final revenue = item['total_revenue'] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: i < 3
                            ? AppColors.warning.withValues(alpha: 0.15)
                            : AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                          child: Text('${i + 1}',
                              style: TextStyle(
                                  color: i < 3
                                      ? AppColors.warning
                                      : AppColors.secondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name as String,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                          Text('$qty units',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10)),
                        ],
                      ),
                    ),
                    Text('KSh ${_fmt(revenue)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySales(BuildContext context, List<dynamic> categories) {
    final totalRevenue = categories.fold<double>(
        0, (sum, c) => sum + (c['total_revenue'] as num? ?? 0).toDouble());

    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.success,
      AppColors.warning,
      AppColors.error,
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category,
                    size: 18, color: AppColors.secondary),
                const SizedBox(width: 8),
                const Text('Sales by Category',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/analytics/categories'),
                  child: const Text('View All', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (categories.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: Text('No category data',
                        style: TextStyle(color: AppColors.textSecondary))),
              ),
            ...categories.take(5).toList().asMap().entries.map((entry) {
              final i = entry.key;
              final cat = entry.value;
              final name = cat['category_name'] ?? 'Unknown';
              final revenue =
                  (cat['total_revenue'] as num?)?.toDouble() ?? 0;
              final pct = totalRevenue > 0 ? revenue / totalRevenue : 0.0;
              final color = colors[i % colors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(name as String,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis)),
                        Text('${(pct * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                        const SizedBox(width: 8),
                        Text('KSh ${_fmt(revenue)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 5,
                        backgroundColor: color.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStockValuation(
      BuildContext context, dynamic costValue, dynamic retailValue, dynamic profit) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('Stock Valuation',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 600 ? 3 : 1;
              final cardWidth =
                  (constraints.maxWidth - (crossCount - 1) * 12) / crossCount;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cost Value',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('KSh ${_fmt(costValue)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 20)),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Retail Value',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('KSh ${_fmt(retailValue)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: AppColors.success)),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Potential Profit',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('KSh ${_fmt(profit)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiringSoon(BuildContext context, dynamic expiringData) {
    final List items = (expiringData is List) ? expiringData : [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_busy,
                    size: 18, color: Color(0xFFF97316)),
                const SizedBox(width: 8),
                const Text('Expiring Soon',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: Text('No items expiring soon',
                        style: TextStyle(color: AppColors.textSecondary))),
              ),
            ...items.take(5).map((item) {
              final name = item is Map
                  ? (item['stock_name'] ?? item['medication_name'] ?? '?')
                  : '$item';
              final batch = item is Map ? (item['batch_number'] ?? '') : '';
              final expiry = item is Map ? (item['expiry_date'] ?? '') : '';
              final qty = item is Map ? (item['quantity_remaining'] ?? 0) : 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Color(0xFFF97316), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$name',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis),
                          Text('Batch: $batch',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$qty left',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: Color(0xFFF97316))),
                        Text('$expiry',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // == Skeleton loader =====================================================
  Widget _buildSkeletonDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SkeletonBox(height: 110, radius: 12),
        const SizedBox(height: 24),
        _SkeletonBox(height: 16, width: 180),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (_, c) {
          final cols = c.maxWidth > 1100 ? 6 : c.maxWidth > 700 ? 3 : 2;
          final w = (c.maxWidth - (cols - 1) * 12) / cols;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(
                6, (_) => SizedBox(width: w, child: _SkeletonBox(height: 90, radius: 12))),
          );
        }),
        const SizedBox(height: 24),
        _SkeletonBox(height: 16, width: 150),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (_, c) {
          final cols = c.maxWidth > 1100 ? 6 : c.maxWidth > 700 ? 3 : 2;
          final w = (c.maxWidth - (cols - 1) * 12) / cols;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(
                6, (_) => SizedBox(width: w, child: _SkeletonBox(height: 90, radius: 12))),
          );
        }),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (_, c) {
          if (c.maxWidth > 1000) {
            return Row(
              children: [
                Expanded(child: _SkeletonBox(height: 200, radius: 12)),
                const SizedBox(width: 16),
                Expanded(child: _SkeletonBox(height: 200, radius: 12)),
                const SizedBox(width: 16),
                Expanded(child: _SkeletonBox(height: 200, radius: 12)),
              ],
            );
          }
          return _SkeletonBox(height: 200, radius: 12);
        }),
      ],
    );
  }

  // == Action Center ========================================================
  Widget _buildActionCenter(BuildContext context, WidgetRef ref, _DashboardData data) {
    final inv = data.inventoryStats;
    final outOfStock = (inv['out_of_stock'] as num?)?.toInt() ?? 0;
    final expiring7 = data.expiringSoon.where((e) {
      if (e is! Map) return false;
      final expiry = e['expiry_date'] as String? ?? '';
      if (expiry.isEmpty) return false;
      try {
        final d = DateTime.parse(expiry);
        return d.difference(DateTime.now()).inDays <= 7;
      } catch (_) {
        return false;
      }
    }).length;
    final lowStockCount = (inv['low_stock_count'] as num?)?.toInt() ?? 0;
    final pendingOrders = data.pendingOrdersCount;

    final alerts = <_AlertItem>[
      if (outOfStock > 0)
        _AlertItem(
          icon: Icons.remove_shopping_cart_outlined,
          label: '$outOfStock item${outOfStock > 1 ? 's' : ''} out of stock — action needed',
          severity: _AlertSeverity.critical,
          onTap: () => context.push('/inventory'),
        ),
      if (expiring7 > 0)
        _AlertItem(
          icon: Icons.event_busy_outlined,
          label: '$expiring7 batch${expiring7 > 1 ? 'es' : ''} expiring within 7 days',
          severity: _AlertSeverity.critical,
          onTap: () => context.push('/inventory'),
        ),
      if (pendingOrders > 0)
        _AlertItem(
          icon: Icons.local_shipping_outlined,
          label: '$pendingOrders pending patient order${pendingOrders > 1 ? 's' : ''} awaiting processing',
          severity: _AlertSeverity.warning,
          onTap: () => context.push('/pharmacy-orders'),
        ),
      if (lowStockCount > 0)
        _AlertItem(
          icon: Icons.inventory_outlined,
          label: '$lowStockCount item${lowStockCount > 1 ? 's' : ''} running low — consider reordering',
          severity: _AlertSeverity.warning,
          onTap: () => context.push('/inventory'),
        ),
    ];

    if (alerts.isEmpty) return const SizedBox.shrink();

    final hasCritical = alerts.any((a) => a.severity == _AlertSeverity.critical);
    final accentColor = hasCritical ? AppColors.error : AppColors.warning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.notifications_active_outlined, size: 18, color: accentColor),
            const SizedBox(width: 8),
            Text('Action Required',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15, color: accentColor)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${alerts.length} alert${alerts.length > 1 ? 's' : ''}',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: accentColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          color: accentColor.withValues(alpha: 0.03),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: accentColor.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: alerts.asMap().entries.map((entry) {
              final i = entry.key;
              final alert = entry.value;
              final severityColor = alert.severity == _AlertSeverity.critical
                  ? AppColors.error
                  : AppColors.warning;
              final BorderRadius inkRadius;
              if (alerts.length == 1) {
                inkRadius = BorderRadius.circular(12);
              } else if (i == 0) {
                inkRadius = const BorderRadius.vertical(top: Radius.circular(12));
              } else if (i == alerts.length - 1) {
                inkRadius = const BorderRadius.vertical(bottom: Radius.circular(12));
              } else {
                inkRadius = BorderRadius.zero;
              }
              return Column(
                children: [
                  if (i > 0)
                    Divider(height: 1, color: AppColors.border.withValues(alpha: 0.4)),
                  InkWell(
                    borderRadius: inkRadius,
                    onTap: alert.onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: severityColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(alert.icon, size: 17, color: severityColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(alert.label,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary)),
                          ),
                          Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // == Fallback (offline / error) ============================================
  Widget _buildFallbackDashboard(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final crossCount = constraints.maxWidth > 900 ? 4 : constraints.maxWidth > 600 ? 2 : 1;
            final cardWidth = (constraints.maxWidth - (crossCount - 1) * 16) / crossCount;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(width: cardWidth, child: StatCard(icon: Icons.point_of_sale_outlined, title: "Today's Sales", value: '--', color: AppColors.primary)),
                SizedBox(width: cardWidth, child: StatCard(icon: Icons.attach_money_outlined, title: 'Revenue (Today)', value: '--', color: AppColors.success)),
                SizedBox(width: cardWidth, child: StatCard(icon: Icons.warning_amber_outlined, title: 'Low Stock Items', value: '--', color: AppColors.warning)),
                SizedBox(width: cardWidth, child: StatCard(icon: Icons.event_busy_outlined, title: 'Expiring (30 days)', value: '--', color: AppColors.error)),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Icon(Icons.cloud_off_outlined, size: 44, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                Text(
                  'Could not load dashboard data',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Check your connection and try again.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(_dashboardDataProvider),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLowStockAlerts(BuildContext context, List<dynamic> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_outlined, size: 20, color: AppColors.warning),
                const SizedBox(width: 8),
                const Text('Low Stock Alerts', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              Text('No low stock items', style: TextStyle(color: AppColors.textSecondary)),
            ...items.take(5).map((item) {
              final name = item is Map
                  ? (item['medication_name'] ?? '?')
                  : '$item';
              final qty = item is Map ? (item['total_quantity'] ?? 0) : 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: (qty is int && qty < 10) ? AppColors.error : AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text('$name', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                    Text('$qty left', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: (qty is int && qty < 10) ? AppColors.error : AppColors.warning)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayTransactions(BuildContext context, List<dynamic> txData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_outlined, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text("Today's Transactions", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            if (txData.isEmpty)
              Text('No transactions today', style: TextStyle(color: AppColors.textSecondary)),
            ...txData.take(5).map((tx) {
              final ref = tx is Map
                  ? (tx['transaction_number'] ?? '#${tx['id']}')
                  : '$tx';
              final customer = tx is Map
                  ? (tx['customer_name']?.toString().isNotEmpty == true
                      ? tx['customer_name']
                      : 'Walk-in')
                  : 'Walk-in';
              final amount = tx is Map ? (tx['total'] ?? 0) : 0;
              final method = tx is Map ? (tx['payment_method'] ?? '') : '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.shopping_bag_outlined, size: 16, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$customer', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          Text('$ref', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('KSh ${_fmt(amount)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('$method', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic value) {
    final num n = value is num ? value : (double.tryParse('$value') ?? 0);
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2);
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
            color: color.withValues(alpha: 0.05),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Alert helper types ─────────────────────────────────────────────────────
enum _AlertSeverity { critical, warning }

class _AlertItem {
  final IconData icon;
  final String label;
  final _AlertSeverity severity;
  final VoidCallback onTap;
  const _AlertItem({
    required this.icon,
    required this.label,
    required this.severity,
    required this.onTap,
  });
}

// ── Animated skeleton shimmer box ─────────────────────────────────────────
class _SkeletonBox extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;
  const _SkeletonBox({required this.height, this.width, this.radius = 8});

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.35, end: 0.75).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.border.withValues(alpha: _anim.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
