import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../pos/providers/sales_analytics_provider.dart';

class TopProductSalesScreen extends ConsumerStatefulWidget {
  const TopProductSalesScreen({super.key});

  @override
  ConsumerState<TopProductSalesScreen> createState() =>
      _TopProductSalesScreenState();
}

class _TopProductSalesScreenState
    extends ConsumerState<TopProductSalesScreen> {
  String _period = 'month';

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(salesAnalyticsProvider((period: _period, branchId: null)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Top Product Sales',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'today', label: Text('Today')),
                  ButtonSegment(value: 'week', label: Text('Week')),
                  ButtonSegment(value: 'month', label: Text('Month')),
                  ButtonSegment(value: 'year', label: Text('Year')),
                ],
                selected: {_period},
                onSelectionChanged: (v) => setState(() => _period = v.first),
              ),
            ],
          ),
          const SizedBox(height: 24),

          salesAsync.when(
            loading: () => const Center(child: LoadingWidget()),
            error: (e, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load data: $e'),
              ),
            ),
            data: (sales) {
              final topItems =
                  sales['top_selling_items'] as List<dynamic>? ?? [];
              final totalRevenue =
                  (sales['total_revenue'] as num?)?.toDouble() ?? 0;
              return _buildContent(context, topItems, totalRevenue);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, List<dynamic> items, double periodRevenue) {
    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 48, color: AppColors.textSecondary),
                SizedBox(height: 16),
                Text('No product sales data for this period',
                    style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    final totalQty =
        items.fold<int>(0, (sum, i) => sum + (i['total_qty'] as int? ?? 0));
    final totalRevenue = items.fold<double>(
        0, (sum, i) => sum + (i['total_revenue'] as num? ?? 0).toDouble());
    final topProduct =
        items.isNotEmpty ? items.first['medication_name'] ?? '-' : '-';
    final topProductRevenue = items.isNotEmpty
        ? (items.first['total_revenue'] as num?)?.toDouble() ?? 0
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary cards
        LayoutBuilder(builder: (context, constraints) {
          final crossCount = constraints.maxWidth > 900
              ? 4
              : constraints.maxWidth > 600
                  ? 2
                  : 1;
          final cardWidth =
              (constraints.maxWidth - (crossCount - 1) * 16) / crossCount;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: cardWidth,
                child: _SummaryCard(
                  icon: Icons.emoji_events,
                  title: 'Top Product',
                  value: topProduct as String,
                  color: AppColors.warning,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _SummaryCard(
                  icon: Icons.attach_money,
                  title: 'Top Product Revenue',
                  value: 'KSh ${_formatNumber(topProductRevenue)}',
                  color: AppColors.success,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _SummaryCard(
                  icon: Icons.shopping_bag,
                  title: 'Total Units (Top 10)',
                  value: '$totalQty',
                  color: AppColors.secondary,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _SummaryCard(
                  icon: Icons.monetization_on,
                  title: 'Revenue (Top 10)',
                  value: 'KSh ${_formatNumber(totalRevenue)}',
                  color: AppColors.primary,
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 24),

        // Ranking + Performance side-by-side
        LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: _buildProductRanking(context, items, totalRevenue)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildRevenueContribution(
                        context, items, periodRevenue)),
              ],
            );
          }
          return Column(
            children: [
              _buildProductRanking(context, items, totalRevenue),
              const SizedBox(height: 16),
              _buildRevenueContribution(context, items, periodRevenue),
            ],
          );
        }),
        const SizedBox(height: 24),

        // Full details table
        _buildProductTable(context, items, totalRevenue),
      ],
    );
  }

  Widget _buildProductRanking(
      BuildContext context, List<dynamic> items, double totalRevenue) {
    final medals = ['🥇', '🥈', '🥉'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Product Ranking',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 20),
            ...items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final name = item['medication_name'] ?? 'Unknown';
              final category = item['category_name'] ?? 'Uncategorized';
              final qty = item['total_qty'] ?? 0;
              final revenue =
                  (item['total_revenue'] as num?)?.toDouble() ?? 0;
              final pct =
                  totalRevenue > 0 ? revenue / totalRevenue : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: i < 3
                        ? AppColors.warning.withValues(alpha: 0.05)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: i < 3
                          ? AppColors.warning.withValues(alpha: 0.2)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Center(
                          child: i < 3
                              ? Text(medals[i],
                                  style: const TextStyle(fontSize: 20))
                              : Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Text('${i + 1}',
                                        style: TextStyle(
                                            color: AppColors.secondary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name as String,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(category as String,
                                      style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 10)),
                                ),
                                const SizedBox(width: 8),
                                Text('$qty units',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('KSh ${_formatNumber(revenue)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          Text('${(pct * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueContribution(
      BuildContext context, List<dynamic> items, double periodRevenue) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Revenue Contribution',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'How each top product contributes to total period revenue',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 20),
            ...items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final name = item['medication_name'] ?? 'Unknown';
              final revenue =
                  (item['total_revenue'] as num?)?.toDouble() ?? 0;
              final pct =
                  periodRevenue > 0 ? revenue / periodRevenue : 0.0;

              final colors = [
                AppColors.success,
                AppColors.primary,
                AppColors.secondary,
                AppColors.warning,
                AppColors.error,
                const Color(0xFF8B5CF6),
                const Color(0xFFEC4899),
                const Color(0xFF06B6D4),
                const Color(0xFFF97316),
                const Color(0xFF84CC16),
              ];
              final color = colors[i % colors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name as String,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        Text('${(pct * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: color)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 8,
                        backgroundColor: color.withValues(alpha: 0.1),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (periodRevenue > 0) ...[
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Period Revenue',
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          fontSize: 12)),
                  Text('KSh ${_formatNumber(periodRevenue)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductTable(
      BuildContext context, List<dynamic> items, double totalRevenue) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.table_chart,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('Product Details',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const Spacer(),
                Text('Top ${items.length} products',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('Rank')),
                  DataColumn(label: Text('Product')),
                  DataColumn(label: Text('Category')),
                  DataColumn(label: Text('Qty Sold'), numeric: true),
                  DataColumn(label: Text('Revenue'), numeric: true),
                  DataColumn(label: Text('Share'), numeric: true),
                  DataColumn(label: Text('Avg Price'), numeric: true),
                ],
                rows: items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final name = item['medication_name'] ?? 'Unknown';
                  final category =
                      item['category_name'] ?? 'Uncategorized';
                  final qty = item['total_qty'] ?? 0;
                  final revenue =
                      (item['total_revenue'] as num?)?.toDouble() ?? 0;
                  final pct = totalRevenue > 0
                      ? (revenue / totalRevenue * 100)
                      : 0.0;
                  final avgPrice =
                      qty > 0 ? revenue / (qty as int) : 0.0;

                  return DataRow(cells: [
                    DataCell(
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: i < 3
                              ? AppColors.warning.withValues(alpha: 0.15)
                              : AppColors.secondary
                                  .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text('${i + 1}',
                              style: TextStyle(
                                  color: i < 3
                                      ? AppColors.warning
                                      : AppColors.secondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                      ),
                    ),
                    DataCell(Text(name as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(category as String,
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12)),
                    )),
                    DataCell(Text('$qty')),
                    DataCell(Text(
                        'KSh ${_formatNumber(revenue)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${pct.toStringAsFixed(1)}%',
                          style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                    )),
                    DataCell(
                        Text('KSh ${_formatNumber(avgPrice)}')),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(dynamic value) {
    final num n = value is num ? value : (double.tryParse('$value') ?? 0);
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    } else if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }
    return n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2);
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(value,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
