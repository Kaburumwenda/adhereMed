import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../pos/providers/sales_analytics_provider.dart';

class CategorySalesScreen extends ConsumerStatefulWidget {
  const CategorySalesScreen({super.key});

  @override
  ConsumerState<CategorySalesScreen> createState() =>
      _CategorySalesScreenState();
}

class _CategorySalesScreenState extends ConsumerState<CategorySalesScreen> {
  String _period = 'month';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  bool get _isCustomRange => _dateFrom != null && _dateTo != null;

  ({String period, int? branchId, String? dateFrom, String? dateTo})
      _providerParams() {
    final fmt = DateFormat('yyyy-MM-dd');
    return (
      period: _period,
      branchId: null,
      dateFrom: _isCustomRange ? fmt.format(_dateFrom!) : null,
      dateTo: _isCustomRange ? fmt.format(_dateTo!) : null,
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: (_dateFrom != null && _dateTo != null)
          ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _dateFrom = picked.start;
        _dateTo = picked.end;
      });
    }
  }

  void _clearDateRange() =>
      setState(() { _dateFrom = null; _dateTo = null; });

  Widget _buildDateRangeButton() {
    final fmt = DateFormat('dd MMM');
    if (_isCustomRange) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: _pickDateRange,
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.date_range,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Text(
                      '${fmt.format(_dateFrom!)} – ${fmt.format(_dateTo!)}',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            Container(
                width: 1,
                height: 24,
                color: AppColors.primary.withValues(alpha: 0.3)),
            InkWell(
              onTap: _clearDateRange,
              borderRadius:
                  const BorderRadius.horizontal(right: Radius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 8),
                child:
                    Icon(Icons.close, size: 14, color: AppColors.primary),
              ),
            ),
          ],
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: _pickDateRange,
      icon: const Icon(Icons.date_range, size: 15),
      label: const Text('Date Range'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        side: BorderSide(color: AppColors.border),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        textStyle: const TextStyle(fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(salesAnalyticsProvider(_providerParams()));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  'Category Sales Analysis',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  _buildDateRangeButton(),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'today', label: Text('Today')),
                      ButtonSegment(value: 'week', label: Text('Week')),
                      ButtonSegment(value: 'month', label: Text('Month')),
                      ButtonSegment(value: 'year', label: Text('Year')),
                    ],
                    selected: {_period},
                    onSelectionChanged: (v) =>
                        setState(() => _period = v.first),
                  ),
                ],
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
              final categories =
                  sales['category_sales'] as List<dynamic>? ?? [];
              return _buildContent(context, categories);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<dynamic> categories) {
    if (categories.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.category_outlined,
                    size: 48, color: AppColors.textSecondary),
                SizedBox(height: 16),
                Text('No category sales data for this period',
                    style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    final totalRevenue = categories.fold<double>(
        0, (sum, c) => sum + (c['total_revenue'] as num? ?? 0).toDouble());
    final totalQty = categories.fold<int>(
        0, (sum, c) => sum + (c['total_qty'] as int? ?? 0));
    final totalSales = categories.fold<int>(
        0, (sum, c) => sum + (c['item_count'] as int? ?? 0));
    final topCategory =
        categories.isNotEmpty ? categories.first['category_name'] ?? '-' : '-';

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
                  icon: Icons.category,
                  title: 'Categories',
                  value: '${categories.length}',
                  color: AppColors.primary,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _SummaryCard(
                  icon: Icons.attach_money,
                  title: 'Total Revenue',
                  value: 'KSh ${_formatNumber(totalRevenue)}',
                  color: AppColors.success,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _SummaryCard(
                  icon: Icons.shopping_bag,
                  title: 'Total Units Sold',
                  value: '$totalQty',
                  color: AppColors.secondary,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _SummaryCard(
                  icon: Icons.emoji_events,
                  title: 'Top Category',
                  value: topCategory as String,
                  color: AppColors.warning,
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 24),

        // Category breakdown cards + table
        LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child:
                        _buildCategoryBreakdown(context, categories, totalRevenue)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildCategoryDistribution(
                        context, categories, totalRevenue)),
              ],
            );
          }
          return Column(
            children: [
              _buildCategoryBreakdown(context, categories, totalRevenue),
              const SizedBox(height: 16),
              _buildCategoryDistribution(context, categories, totalRevenue),
            ],
          );
        }),
        const SizedBox(height: 24),

        // Full table
        _buildCategoryTable(context, categories, totalRevenue, totalSales),
      ],
    );
  }

  Widget _buildCategoryBreakdown(
      BuildContext context, List<dynamic> categories, double totalRevenue) {
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.success,
      AppColors.warning,
      AppColors.error,
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF06B6D4),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Revenue by Category',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 20),
            ...categories.asMap().entries.map((entry) {
              final i = entry.key;
              final cat = entry.value;
              final name = cat['category_name'] ?? 'Unknown';
              final revenue =
                  (cat['total_revenue'] as num?)?.toDouble() ?? 0;
              final pct = totalRevenue > 0 ? revenue / totalRevenue : 0.0;
              final color = colors[i % colors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(name as String,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 13)),
                        ),
                        Text('${(pct * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                        const SizedBox(width: 8),
                        Text('KSh ${_formatNumber(revenue)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 8,
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

  Widget _buildCategoryDistribution(
      BuildContext context, List<dynamic> categories, double totalRevenue) {
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.success,
      AppColors.warning,
      AppColors.error,
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF06B6D4),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Category Performance',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 20),
            ...categories.asMap().entries.map((entry) {
              final i = entry.key;
              final cat = entry.value;
              final name = cat['category_name'] ?? 'Unknown';
              final revenue =
                  (cat['total_revenue'] as num?)?.toDouble() ?? 0;
              final qty = cat['total_qty'] ?? 0;
              final itemCount = cat['item_count'] ?? 0;
              final avgPerSale =
                  itemCount > 0 ? revenue / itemCount : 0.0;
              final color = colors[i % colors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                            child: Icon(Icons.category,
                                size: 20, color: color)),
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
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _MiniStat(
                                    label: 'Units', value: '$qty'),
                                const SizedBox(width: 16),
                                _MiniStat(
                                    label: 'Sales', value: '$itemCount'),
                                const SizedBox(width: 16),
                                _MiniStat(
                                    label: 'Avg/Sale',
                                    value:
                                        'KSh ${_formatNumber(avgPerSale)}'),
                              ],
                            ),
                          ],
                        ),
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

  Widget _buildCategoryTable(BuildContext context, List<dynamic> categories,
      double totalRevenue, int totalSales) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.table_chart, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('Category Details',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const Spacer(),
                Text('${categories.length} categories',
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
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Category')),
                  DataColumn(label: Text('Units Sold'), numeric: true),
                  DataColumn(label: Text('Sales Count'), numeric: true),
                  DataColumn(label: Text('Revenue'), numeric: true),
                  DataColumn(label: Text('Share'), numeric: true),
                  DataColumn(label: Text('Avg/Sale'), numeric: true),
                ],
                rows: categories.asMap().entries.map((entry) {
                  final i = entry.key;
                  final cat = entry.value;
                  final name = cat['category_name'] ?? 'Unknown';
                  final qty = cat['total_qty'] ?? 0;
                  final itemCount = cat['item_count'] ?? 0;
                  final revenue =
                      (cat['total_revenue'] as num?)?.toDouble() ?? 0;
                  final pct =
                      totalRevenue > 0 ? (revenue / totalRevenue * 100) : 0.0;
                  final avgPerSale =
                      itemCount > 0 ? revenue / itemCount : 0.0;
                  return DataRow(cells: [
                    DataCell(Text('${i + 1}')),
                    DataCell(Text(name as String,
                        style:
                            const TextStyle(fontWeight: FontWeight.w500))),
                    DataCell(Text('$qty')),
                    DataCell(Text('$itemCount')),
                    DataCell(Text('KSh ${_formatNumber(revenue)}',
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${pct.toStringAsFixed(1)}%',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                    )),
                    DataCell(Text('KSh ${_formatNumber(avgPerSale)}')),
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
                          fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 10)),
        Text(value,
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
      ],
    );
  }
}
