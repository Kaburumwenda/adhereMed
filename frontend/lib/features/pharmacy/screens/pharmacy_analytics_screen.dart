import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../pos/providers/sales_analytics_provider.dart';
import '../../inventory/providers/stock_adjustment_provider.dart';

class PharmacyAnalyticsScreen extends ConsumerStatefulWidget {
  const PharmacyAnalyticsScreen({super.key});

  @override
  ConsumerState<PharmacyAnalyticsScreen> createState() =>
      _PharmacyAnalyticsScreenState();
}

class _PharmacyAnalyticsScreenState
    extends ConsumerState<PharmacyAnalyticsScreen> {
  String _period = 'month';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  int? _touchedPieIndex;
  int? _touchedCostPieIndex;

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
    final inventoryAsync = ref.watch(inventoryAnalyticsProvider);

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
                  'Analytics',
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

          // Sales Analytics
          salesAsync.when(
            loading: () => const Center(child: LoadingWidget()),
            error: (e, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load sales analytics: $e'),
              ),
            ),
            data: (sales) => _buildSalesSection(context, sales),
          ),
          const SizedBox(height: 24),

          // Inventory Analytics
          inventoryAsync.when(
            loading: () => const Center(child: LoadingWidget()),
            error: (e, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load inventory analytics: $e'),
              ),
            ),
            data: (inventory) => _buildInventorySection(context, inventory),
          ),
        ],
      ),
    );
  }

  // ─── Sales Section ──────────────────────────────────────────────────────────

  Widget _buildSalesSection(BuildContext context, Map<String, dynamic> sales) {
    final totalRevenue = (sales['total_revenue'] as num?)?.toDouble() ?? 0;
    final totalDiscount = (sales['total_discount'] as num?)?.toDouble() ?? 0;
    final txCount = sales['transaction_count'] ?? 0;
    final avgTx = (sales['avg_transaction'] as num?)?.toDouble() ?? 0;
    final paymentBreakdown = sales['payment_breakdown'] as List<dynamic>? ?? [];
    final topItems = sales['top_selling_items'] as List<dynamic>? ?? [];
    final categorySales = sales['category_sales'] as List<dynamic>? ?? [];
    final dailySales = sales['daily_sales'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sales Overview',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),

        // Stat cards
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
                child: StatCard(
                  icon: Icons.attach_money,
                  title: 'Total Revenue',
                  value: 'KSh ${_formatNumber(totalRevenue)}',
                  color: AppColors.success,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: StatCard(
                  icon: Icons.receipt_long,
                  title: 'Transactions',
                  value: '$txCount',
                  color: AppColors.primary,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: StatCard(
                  icon: Icons.trending_up,
                  title: 'Avg. Transaction',
                  value: 'KSh ${_formatNumber(avgTx)}',
                  color: AppColors.secondary,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: StatCard(
                  icon: Icons.discount_outlined,
                  title: 'Total Discounts',
                  value: 'KSh ${_formatNumber(totalDiscount)}',
                  color: AppColors.warning,
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 24),

        // Bar chart + Donut chart side by side
        LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    flex: 3,
                    child: _buildDailyBarChart(context, dailySales)),
                const SizedBox(width: 16),
                Expanded(
                    flex: 2,
                    child: _buildRevenueDonut(
                        context, totalRevenue, totalDiscount)),
              ],
            );
          }
          return Column(children: [
            _buildDailyBarChart(context, dailySales),
            const SizedBox(height: 16),
            _buildRevenueDonut(context, totalRevenue, totalDiscount),
          ]);
        }),
        const SizedBox(height: 24),

        // Payment Breakdown + Category Sales side by side
        LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child:
                        _buildPaymentBreakdown(context, paymentBreakdown)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildCategorySales(context, categorySales)),
              ],
            );
          }
          return Column(
            children: [
              _buildPaymentBreakdown(context, paymentBreakdown),
              const SizedBox(height: 16),
              _buildCategorySales(context, categorySales),
            ],
          );
        }),
        const SizedBox(height: 24),

        // Top Selling Items (full width)
        _buildTopItems(context, topItems),
      ],
    );
  }

  // ─── Daily Revenue Bar Chart ────────────────────────────────────────────────

  Widget _buildDailyBarChart(BuildContext context, List<dynamic> dailySales) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.bar_chart_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text('Daily Revenue',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ]),
            const SizedBox(height: 20),
            if (dailySales.isEmpty)
              SizedBox(
                height: 160,
                child: Center(
                    child: Text('No data for this period',
                        style:
                            TextStyle(color: AppColors.textSecondary))),
              )
            else
              SizedBox(
                height: 220,
                child: _BarChart(dailySales: dailySales),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Revenue vs Discount Donut ──────────────────────────────────────────────

  Widget _buildRevenueDonut(
      BuildContext context, double totalRevenue, double totalDiscount) {
    final netRevenue = (totalRevenue - totalDiscount).clamp(0.0, double.infinity);
    final hasData = totalRevenue > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.donut_large, color: AppColors.secondary, size: 18),
              const SizedBox(width: 8),
              const Text('Revenue Breakdown',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ]),
            const SizedBox(height: 20),
            if (!hasData)
              const SizedBox(
                height: 160,
                child: Center(child: Text('No revenue data')),
              )
            else
              SizedBox(
                height: 200,
                child: Row(
                  children: [
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 45,
                          pieTouchData: PieTouchData(
                            touchCallback: (event, response) {
                              setState(() {
                                _touchedPieIndex = response
                                    ?.touchedSection
                                    ?.touchedSectionIndex;
                              });
                            },
                          ),
                          sections: [
                            PieChartSectionData(
                              value: netRevenue,
                              color: AppColors.success,
                              radius: _touchedPieIndex == 0 ? 60 : 52,
                              title:
                                  '${(netRevenue / totalRevenue * 100).toStringAsFixed(1)}%',
                              titleStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            PieChartSectionData(
                              value: totalDiscount,
                              color: AppColors.warning,
                              radius: _touchedPieIndex == 1 ? 60 : 52,
                              title: totalDiscount > 0
                                  ? '${(totalDiscount / totalRevenue * 100).toStringAsFixed(1)}%'
                                  : '',
                              titleStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LegendItem(
                            color: AppColors.success,
                            label: 'Net Revenue',
                            value: 'KSh ${_formatNumber(netRevenue)}'),
                        const SizedBox(height: 12),
                        _LegendItem(
                            color: AppColors.warning,
                            label: 'Discounts',
                            value: 'KSh ${_formatNumber(totalDiscount)}'),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Payment Breakdown ──────────────────────────────────────────────────────

  Widget _buildPaymentBreakdown(
      BuildContext context, List<dynamic> breakdown) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payment Methods',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 16),
            if (breakdown.isEmpty)
              Text('No data', style: TextStyle(color: AppColors.textSecondary)),
            ...breakdown.map((item) {
              final method =
                  (item['payment_method'] as String?)?.toUpperCase() ?? '?';
              final count = item['count'] ?? 0;
              final total = item['total'] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                          child: Text(
                              method.isNotEmpty ? method.substring(0, 1) : '?',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(method,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 13)),
                          Text('$count transactions',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    Text('KSh ${_formatNumber(total)}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ─── Top Items ──────────────────────────────────────────────────────────────

  Widget _buildTopItems(BuildContext context, List<dynamic> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events, color: AppColors.warning, size: 20),
                const SizedBox(width: 8),
                const Text('Top Selling Items',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16)),
                const Spacer(),
                Text('${items.length} items',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No sales data for this period')),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text('#')),
                    DataColumn(label: Text('Item')),
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Qty Sold'), numeric: true),
                    DataColumn(label: Text('Revenue'), numeric: true),
                  ],
                  rows: items.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    final name = item['medication_name'] ?? 'Unknown';
                    final category =
                        item['category_name'] ?? 'Uncategorized';
                    final qty = item['total_qty'] ?? 0;
                    final revenue = item['total_revenue'] ?? 0;
                    return DataRow(cells: [
                      DataCell(Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color:
                              AppColors.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                            child: Text('${i + 1}',
                                style: TextStyle(
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                      )),
                      DataCell(Text(name as String,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(category as String,
                            style: TextStyle(
                                color: AppColors.primary, fontSize: 12)),
                      )),
                      DataCell(Text('$qty')),
                      DataCell(Text('KSh ${_formatNumber(revenue)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600))),
                    ]);
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Category Sales ─────────────────────────────────────────────────────────

  Widget _buildCategorySales(
      BuildContext context, List<dynamic> categories) {
    final totalRevenue = categories.fold<double>(
        0, (sum, c) => sum + (c['total_revenue'] as num? ?? 0).toDouble());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sales by Category',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 16),
            if (categories.isEmpty)
              Text('No data',
                  style: TextStyle(color: AppColors.textSecondary)),
            ...categories.map((cat) {
              final name = cat['category_name'] ?? 'Unknown';
              final revenue =
                  (cat['total_revenue'] as num?)?.toDouble() ?? 0;
              final qty = cat['total_qty'] ?? 0;
              final itemCount = cat['item_count'] ?? 0;
              final pct =
                  totalRevenue > 0 ? (revenue / totalRevenue) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.secondary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                              child: Icon(Icons.category,
                                  size: 18, color: AppColors.secondary)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name as String,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13)),
                              Text('$itemCount sales · $qty units',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('KSh ${_formatNumber(revenue)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text('${(pct * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor:
                            AppColors.secondary.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.secondary),
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

  // ─── Inventory Section ──────────────────────────────────────────────────────

  Widget _buildInventorySection(
      BuildContext context, Map<String, dynamic> data) {
    final costValue =
        (data['total_cost_value'] as num?)?.toDouble() ?? 0;
    final retailValue =
        (data['total_retail_value'] as num?)?.toDouble() ?? 0;
    final potentialProfit =
        (data['potential_profit'] as num?)?.toDouble() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Inventory Overview',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
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
                child: StatCard(
                  icon: Icons.inventory_2,
                  title: 'Total Items',
                  value: '${data['total_items'] ?? 0}',
                  color: AppColors.primary,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: StatCard(
                  icon: Icons.warning_amber,
                  title: 'Low Stock',
                  value: '${data['low_stock_count'] ?? 0}',
                  color: AppColors.warning,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: StatCard(
                  icon: Icons.remove_shopping_cart,
                  title: 'Out of Stock',
                  value: '${data['out_of_stock'] ?? 0}',
                  color: AppColors.error,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: StatCard(
                  icon: Icons.event_busy,
                  title: 'Expiring (30 days)',
                  value: '${data['expiring_30_days'] ?? 0}',
                  color: AppColors.warning,
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 16),

        // Cost vs Retail value bar + Profit pie side by side
        LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    flex: 3,
                    child: _buildInventoryValueBars(
                        context, costValue, retailValue, potentialProfit)),
                const SizedBox(width: 16),
                Expanded(
                    flex: 2,
                    child: _buildCostVsProfitPie(
                        context, costValue, potentialProfit)),
              ],
            );
          }
          return Column(children: [
            _buildInventoryValueBars(
                context, costValue, retailValue, potentialProfit),
            const SizedBox(height: 16),
            _buildCostVsProfitPie(context, costValue, potentialProfit),
          ]);
        }),
      ],
    );
  }

  // ─── Inventory Value Bar Chart ──────────────────────────────────────────────

  Widget _buildInventoryValueBars(BuildContext context, double costValue,
      double retailValue, double potentialProfit) {
    final maxVal = retailValue > 0 ? retailValue : 1.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.bar_chart, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text('Inventory Value',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: maxVal * 1.2,
                  barGroups: [
                    BarChartGroupData(x: 0, barRods: [
                      BarChartRodData(
                        toY: costValue,
                        color: AppColors.textSecondary,
                        width: 40,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ]),
                    BarChartGroupData(x: 1, barRods: [
                      BarChartRodData(
                        toY: retailValue,
                        color: AppColors.primary,
                        width: 40,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ]),
                    BarChartGroupData(x: 2, barRods: [
                      BarChartRodData(
                        toY: potentialProfit,
                        color: AppColors.success,
                        width: 40,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ]),
                  ],
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) =>
                        FlLine(color: AppColors.border, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 56,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          return Text(
                            value >= 1000000
                                ? '${(value / 1000000).toStringAsFixed(1)}M'
                                : value >= 1000
                                    ? '${(value / 1000).toStringAsFixed(0)}K'
                                    : value.toStringAsFixed(0),
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          const labels = ['Cost', 'Retail', 'Profit'];
                          final i = value.toInt();
                          if (i < 0 || i >= labels.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(labels[i],
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500)),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppColors.surface,
                      tooltipBorder: BorderSide(color: AppColors.border),
                      getTooltipItem: (group, _, rod, __) {
                        const labels = [
                          'Cost Value',
                          'Retail Value',
                          'Potential Profit'
                        ];
                        return BarTooltipItem(
                          '${labels[group.x]}\n',
                          TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              fontSize: 12),
                          children: [
                            TextSpan(
                              text: 'KSh ${_formatNumber(rod.toY)}',
                              style: TextStyle(
                                  color: rod.color,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendItem(
                    color: AppColors.textSecondary,
                    label: 'Cost',
                    value: 'KSh ${_formatNumber(costValue)}'),
                const SizedBox(width: 16),
                _LegendItem(
                    color: AppColors.primary,
                    label: 'Retail',
                    value: 'KSh ${_formatNumber(retailValue)}'),
                const SizedBox(width: 16),
                _LegendItem(
                    color: AppColors.success,
                    label: 'Profit',
                    value: 'KSh ${_formatNumber(potentialProfit)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Cost vs Profit Pie Chart ───────────────────────────────────────────────

  Widget _buildCostVsProfitPie(
      BuildContext context, double costValue, double potentialProfit) {
    final total = costValue + potentialProfit;
    final hasData = total > 0;
    final margin = total > 0 ? (potentialProfit / total * 100) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.pie_chart, color: AppColors.success, size: 18),
              const SizedBox(width: 8),
              const Text('Revenue vs Profit',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ]),
            const SizedBox(height: 8),
            Text(
              'Based on current inventory valuation',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 20),
            if (!hasData)
              const SizedBox(
                height: 160,
                child: Center(child: Text('No inventory data')),
              )
            else
              Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 50,
                            pieTouchData: PieTouchData(
                              touchCallback: (event, response) {
                                setState(() {
                                  _touchedCostPieIndex = response
                                      ?.touchedSection
                                      ?.touchedSectionIndex;
                                });
                              },
                            ),
                            sections: [
                              PieChartSectionData(
                                value: costValue,
                                color: AppColors.textSecondary,
                                radius: _touchedCostPieIndex == 0 ? 62 : 54,
                                title: '',
                              ),
                              PieChartSectionData(
                                value: potentialProfit,
                                color: AppColors.success,
                                radius: _touchedCostPieIndex == 1 ? 62 : 54,
                                title: '',
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${margin.toStringAsFixed(1)}%',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success),
                            ),
                            Text('margin',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LegendItem(
                          color: AppColors.textSecondary,
                          label: 'Cost',
                          value: 'KSh ${_formatNumber(costValue)}'),
                      const SizedBox(width: 16),
                      _LegendItem(
                          color: AppColors.success,
                          label: 'Profit',
                          value: 'KSh ${_formatNumber(potentialProfit)}'),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

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

// ─── Extracted stateless bar chart widget ──────────────────────────────────

class _BarChart extends StatelessWidget {
  final List<dynamic> dailySales;
  const _BarChart({required this.dailySales});

  String _shortDate(String? s) {
    if (s == null) return '';
    try {
      final dt = DateTime.parse(s);
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxRevenue = dailySales
        .map((e) => (e['revenue'] as num?)?.toDouble() ?? 0.0)
        .fold(0.0, (a, b) => a > b ? a : b);

    final barGroups = dailySales.asMap().entries.map((entry) {
      final i = entry.key;
      final revenue =
          (entry.value['revenue'] as num?)?.toDouble() ?? 0.0;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: revenue,
            color: AppColors.primary,
            width: dailySales.length <= 7 ? 28 : 14,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        maxY: maxRevenue * 1.2,
        barGroups: barGroups,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(
                  value >= 1000
                      ? '${(value / 1000).toStringAsFixed(1)}k'
                      : value.toStringAsFixed(0),
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textSecondary),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= dailySales.length) {
                  return const SizedBox.shrink();
                }
                if (dailySales.length > 14 && i % 3 != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _shortDate(dailySales[i]['date']?.toString()),
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textSecondary),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.surface,
            tooltipBorder: BorderSide(color: AppColors.border),
            getTooltipItem: (group, _, rod, __) {
              final day = dailySales[group.x];
              final date = _shortDate(day['date']?.toString());
              final revenue = (day['revenue'] as num?)?.toDouble() ?? 0.0;
              final count = day['count'] ?? 0;
              return BarTooltipItem(
                '$date\n',
                TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 12),
                children: [
                  TextSpan(
                    text: 'KSh ${revenue >= 1000 ? '${(revenue / 1000).toStringAsFixed(1)}K' : revenue.toStringAsFixed(0)}',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                  ),
                  TextSpan(
                    text: '\n$count txns',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Legend item ─────────────────────────────────────────────────────────────

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _LegendItem(
      {required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
