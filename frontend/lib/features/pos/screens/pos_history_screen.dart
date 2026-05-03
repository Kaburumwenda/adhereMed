import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/models/paginated_response.dart';
import '../../../core/utils/web_print_stub.dart'
    if (dart.library.html) '../../../core/utils/web_print_web.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/stat_card.dart';
import '../models/pos_transaction_model.dart';
import '../providers/sales_analytics_provider.dart';
import '../repository/pos_repository.dart';

class POSHistoryScreen extends ConsumerStatefulWidget {
  const POSHistoryScreen({super.key});

  @override
  ConsumerState<POSHistoryScreen> createState() => _POSHistoryScreenState();
}

class _POSHistoryScreenState extends ConsumerState<POSHistoryScreen>
    with SingleTickerProviderStateMixin {
  final _repo = POSRepository();
  late final TabController _tabController;

  // Transactions tab state
  PaginatedResponse<POSTransaction>? _data;
  List<POSTransaction>? _todayData;
  bool _loading = true;
  String? _error;
  int _page = 1;
  String _search = '';
  String? _paymentFilter;

  // Overview tab state
  String _analyticsPeriod = 'week';

  static const _paymentMethods = ['cash', 'card', 'mpesa'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final allResult = await _repo.getTransactions(
        page: _page,
        search: _search.isEmpty ? null : _search,
      );
      final todayResult = await _repo.getTodayTransactions();
      setState(() {
        _data = allResult;
        _todayData = todayResult;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatCurrency(double amount) =>
      'KSh ${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},')}';

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatShortDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return dateStr;
    }
  }

  double get _todayTotal =>
      _todayData?.fold<double>(0.0, (s, t) => s + t.totalAmount) ?? 0;

  double get _todayAvg {
    final count = _todayData?.length ?? 0;
    return count == 0 ? 0 : _todayTotal / count;
  }

  Color _paymentColor(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return AppColors.success;
      case 'card':
        return AppColors.primary;
      case 'mpesa':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  List<POSTransaction> get _filteredResults {
    if (_data == null) return [];
    if (_paymentFilter == null) return _data!.results;
    return _data!.results
        .where((t) => t.paymentMethod.toLowerCase() == _paymentFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sales History',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text('POS transactions & analytics',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.go('/pos'),
                icon: const Icon(Icons.point_of_sale, size: 16),
                label: const Text('Go to POS'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Transactions'),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildTransactionsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    final analyticsAsync = ref.watch(salesAnalyticsProvider((period: _analyticsPeriod, branchId: null)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTodayCards(),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bar_chart_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Revenue Trend',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      SegmentedButton<String>(
                        style: SegmentedButton.styleFrom(
                          textStyle: const TextStyle(fontSize: 12),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        segments: const [
                          ButtonSegment(
                              value: 'week', label: Text('7 Days')),
                          ButtonSegment(
                              value: 'month', label: Text('30 Days')),
                        ],
                        selected: {_analyticsPeriod},
                        onSelectionChanged: (v) =>
                            setState(() => _analyticsPeriod = v.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  analyticsAsync.when(
                    loading: () => const SizedBox(
                        height: 200,
                        child: Center(child: LoadingWidget())),
                    error: (e, _) => SizedBox(
                        height: 100,
                        child: Center(
                            child: Text('Failed to load chart data',
                                style: TextStyle(
                                    color: AppColors.textSecondary)))),
                    data: (data) => _buildBarChart(
                        data['daily_sales'] as List<dynamic>? ?? []),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          analyticsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (data) => LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 700) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: _buildPaymentBreakdown(
                              data['payment_breakdown'] as List? ?? [])),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _buildTopItems(
                              data['top_selling_items'] as List? ?? [])),
                    ],
                  );
                }
                return Column(children: [
                  _buildPaymentBreakdown(
                      data['payment_breakdown'] as List? ?? []),
                  const SizedBox(height: 16),
                  _buildTopItems(
                      data['top_selling_items'] as List? ?? []),
                ]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayCards() {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 600;
      final cards = [
        StatCard(
          icon: Icons.trending_up,
          title: "Today's Revenue",
          value: _loading ? '...' : _formatCurrency(_todayTotal),
          color: AppColors.success,
        ),
        StatCard(
          icon: Icons.receipt_long,
          title: "Today's Transactions",
          value: _loading ? '...' : '${_todayData?.length ?? 0}',
          color: AppColors.primary,
        ),
        StatCard(
          icon: Icons.calculate_outlined,
          title: 'Avg. Transaction',
          value: _loading ? '...' : _formatCurrency(_todayAvg),
          color: AppColors.secondary,
        ),
      ];
      if (wide) {
        return Row(
          children: cards
              .map<Widget>((c) => Expanded(child: c))
              .toList()
              .fold<List<Widget>>([], (acc, w) {
            if (acc.isNotEmpty) acc.add(const SizedBox(width: 16));
            acc.add(w);
            return acc;
          }),
        );
      }
      return Column(
          children: cards
              .fold<List<Widget>>([], (acc, w) {
                if (acc.isNotEmpty) acc.add(const SizedBox(height: 12));
                acc.add(w);
                return acc;
              }));
    });
  }

  Widget _buildBarChart(List<dynamic> dailySales) {
    if (dailySales.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text('No sales data for this period',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    final maxRevenue = dailySales
        .map((e) => (e['revenue'] as num?)?.toDouble() ?? 0.0)
        .fold(0.0, (a, b) => a > b ? a : b);

    final barGroups = dailySales.asMap().entries.map((entry) {
      final i = entry.key;
      final revenue = (entry.value['revenue'] as num?)?.toDouble() ?? 0.0;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: revenue,
            color: AppColors.primary,
            width: dailySales.length <= 7 ? 28 : 16,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    return SizedBox(
      height: 220,
      child: BarChart(
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
                      _formatShortDate(
                          dailySales[i]['date']?.toString()),
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
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final day = dailySales[group.x];
                final date =
                    _formatShortDate(day['date']?.toString());
                final revenue =
                    (day['revenue'] as num?)?.toDouble() ?? 0.0;
                final count = day['count'] ?? 0;
                return BarTooltipItem(
                  '$date\n',
                  TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      fontSize: 12),
                  children: [
                    TextSpan(
                      text: _formatCurrency(revenue),
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
      ),
    );
  }

  Widget _buildPaymentBreakdown(List<dynamic> breakdown) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.pie_chart_outline,
                  color: AppColors.secondary, size: 18),
              const SizedBox(width: 8),
              Text('Payment Methods',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 16),
            if (breakdown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No data',
                    style: TextStyle(color: AppColors.textSecondary)),
              )
            else
              ...breakdown.map((item) {
                final method =
                    (item['payment_method'] as String?) ?? 'unknown';
                final count = item['count'] ?? 0;
                final total =
                    (item['total'] as num?)?.toDouble() ?? 0.0;
                final color = _paymentColor(method);
                final methodLabel = method == 'mpesa'
                    ? 'M-Pesa'
                    : method.isNotEmpty
                        ? method[0].toUpperCase() + method.substring(1)
                        : method;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          method == 'cash'
                              ? Icons.payments_outlined
                              : method == 'mpesa'
                                  ? Icons.phone_android
                                  : Icons.credit_card,
                          color: color,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(methodLabel,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13)),
                            Text('$count transactions',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                      Text(_formatCurrency(total),
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

  Widget _buildTopItems(List<dynamic> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.emoji_events_outlined,
                  color: AppColors.warning, size: 18),
              const SizedBox(width: 8),
              Text('Top Selling Items',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 16),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No data',
                    style: TextStyle(color: AppColors.textSecondary)),
              )
            else
              ...items.take(6).toList().asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final name =
                    (item['medication_name'] as String?) ?? 'Unknown';
                final qty = item['total_qty'] ?? 0;
                final revenue =
                    (item['total_revenue'] as num?)?.toDouble() ?? 0.0;
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
                              : AppColors.border,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: i < 3
                                  ? AppColors.warning
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis),
                            Text('$qty units sold',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Text(_formatCurrency(revenue),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SearchField(
                  hintText: 'Search by receipt or customer...',
                  onChanged: (value) {
                    _search = value;
                    _page = 1;
                    _loadData();
                  },
                ),
              ),
              const SizedBox(width: 12),
              _PaymentFilterDropdown(
                value: _paymentFilter,
                methods: _paymentMethods,
                onChanged: (val) => setState(() {
                  _paymentFilter = val;
                  _page = 1;
                }),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Refresh',
                onPressed: _loadData,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_loading && _data != null)
            Row(
              children: [
                _InfoChip(
                    label: '${_data!.count} total',
                    icon: Icons.receipt_long_outlined),
                const SizedBox(width: 8),
                if (_todayData != null)
                  _InfoChip(
                      label: '${_todayData!.length} today',
                      icon: Icons.today_outlined,
                      color: AppColors.success),
              ],
            ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const LoadingWidget()
                : _error != null
                    ? app_error.AppErrorWidget(
                        message: _error!, onRetry: _loadData)
                    : _data == null || _filteredResults.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.receipt_long_outlined,
                            title: 'No transactions found',
                            subtitle: 'Completed sales will appear here.',
                          )
                        : Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SingleChildScrollView(
                                      child: DataTable(
                                        headingRowColor:
                                            WidgetStateProperty.all(
                                                AppColors.background),
                                        dataRowMinHeight: 52,
                                        dataRowMaxHeight: 52,
                                        columnSpacing: 20,
                                        columns: const [
                                          DataColumn(
                                              label: Text('Receipt #',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600))),
                                          DataColumn(
                                              label: Text('Customer',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600))),
                                          DataColumn(
                                              label: Text('Payment',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600))),
                                          DataColumn(
                                              label: Text('Items',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600)),
                                              numeric: true),
                                          DataColumn(
                                              label: Text('Total',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600)),
                                              numeric: true),
                                          DataColumn(
                                              label: Text('Served By',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600))),
                                          DataColumn(
                                              label: Text('Date',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600))),
                                          DataColumn(label: Text('')),
                                        ],
                                        rows: _filteredResults
                                            .map(_buildRow)
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_data!.count > _data!.results.length)
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                          top: BorderSide(
                                              color: AppColors.border)),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Page $_page',
                                          style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 13),
                                        ),
                                        Row(children: [
                                          OutlinedButton.icon(
                                            onPressed: _data!.previous != null
                                                ? () {
                                                    _page--;
                                                    _loadData();
                                                  }
                                                : null,
                                            icon: const Icon(
                                                Icons.chevron_left,
                                                size: 16),
                                            label: const Text('Prev'),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            onPressed: _data!.next != null
                                                ? () {
                                                    _page++;
                                                    _loadData();
                                                  }
                                                : null,
                                            icon: const Icon(
                                                Icons.chevron_right,
                                                size: 16),
                                            label: const Text('Next'),
                                            iconAlignment:
                                                IconAlignment.end,
                                          ),
                                        ]),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  DataRow _buildRow(POSTransaction t) {
    final color = _paymentColor(t.paymentMethod);
    final label = t.paymentMethod == 'mpesa'
        ? 'M-Pesa'
        : t.paymentMethod.isNotEmpty
            ? t.paymentMethod[0].toUpperCase() + t.paymentMethod.substring(1)
            : t.paymentMethod;
    return DataRow(cells: [
      DataCell(Text(t.receiptNumber ?? '#${t.id}',
          style: const TextStyle(fontWeight: FontWeight.w500))),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              (t.customerName?.isNotEmpty == true ? t.customerName! : 'W')[0].toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Text(t.customerName ?? 'Walk-in'),
        ],
      )),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ),
      DataCell(
          Text('${t.items.length}', textAlign: TextAlign.right)),
      DataCell(Text(_formatCurrency(t.totalAmount),
          style: const TextStyle(fontWeight: FontWeight.w600))),
      DataCell(Text(t.servedBy ?? '-')),
      DataCell(Text(_formatDate(t.createdAt),
          style:
              TextStyle(fontSize: 12, color: AppColors.textSecondary))),
      DataCell(IconButton(
        icon: Icon(Icons.visibility_outlined,
            size: 18, color: AppColors.primary),
        onPressed: () => _showDetailDialog(t),
        tooltip: 'View details',
      )),
    ]);
  }

  void _printReceipt(POSTransaction t) {
    if (!kIsWeb) return;
    final items = t.items.map((item) => '''
      <tr>
        <td style="padding:4px 8px">${item.medicationName ?? 'Item'}</td>
        <td style="padding:4px 8px;text-align:center">${item.quantity}</td>
        <td style="padding:4px 8px;text-align:right">${_formatCurrency(item.unitPrice)}</td>
        <td style="padding:4px 8px;text-align:right">${_formatCurrency(item.lineTotal)}</td>
      </tr>''').join('');

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <title>Receipt ${t.receiptNumber ?? '#${t.id}'}</title>
  <style>
    body { font-family: monospace; max-width: 400px; margin: 0 auto; padding: 20px; }
    h2, h3 { text-align: center; margin: 4px 0; }
    .divider { border-top: 1px dashed #000; margin: 8px 0; }
    table { width: 100%; border-collapse: collapse; font-size: 13px; }
    th { text-align: left; padding: 4px 8px; border-bottom: 1px solid #000; }
    .total-row td { font-weight: bold; border-top: 1px solid #000; padding-top: 8px; }
    .footer { text-align: center; margin-top: 16px; font-size: 12px; }
    @media print { body { margin: 0; } }
  </style>
</head>
<body>
  <h2>PHARMACY RECEIPT</h2>
  <div class="divider"></div>
  <p style="font-size:12px;margin:2px 0">Receipt: <b>${t.receiptNumber ?? '#${t.id}'}</b></p>
  <p style="font-size:12px;margin:2px 0">Date: ${_formatDate(t.createdAt)}</p>
  <p style="font-size:12px;margin:2px 0">Customer: ${t.customerName ?? 'Walk-in'}${t.customerPhone != null ? ' (${t.customerPhone})' : ''}</p>
  <p style="font-size:12px;margin:2px 0">Served by: ${t.servedBy ?? '-'}</p>
  <div class="divider"></div>
  <table>
    <thead><tr>
      <th>Item</th><th style="text-align:center">Qty</th>
      <th style="text-align:right">Price</th><th style="text-align:right">Total</th>
    </tr></thead>
    <tbody>$items</tbody>
    <tfoot>
      <tr><td colspan="3" style="text-align:right;padding:4px 8px">Subtotal</td><td style="text-align:right;padding:4px 8px">${_formatCurrency(t.subtotal)}</td></tr>
      ${t.discount > 0 ? '<tr><td colspan="3" style="text-align:right;padding:4px 8px">Discount</td><td style="text-align:right;padding:4px 8px">- ${_formatCurrency(t.discount)}</td></tr>' : ''}
      ${t.taxAmount > 0 ? '<tr><td colspan="3" style="text-align:right;padding:4px 8px">Tax</td><td style="text-align:right;padding:4px 8px">${_formatCurrency(t.taxAmount)}</td></tr>' : ''}
      <tr class="total-row"><td colspan="3" style="text-align:right;padding:4px 8px">TOTAL</td><td style="text-align:right;padding:4px 8px">${_formatCurrency(t.totalAmount)}</td></tr>
      <tr><td colspan="3" style="text-align:right;padding:4px 8px">Payment</td><td style="text-align:right;padding:4px 8px">${t.paymentMethod.toUpperCase()}</td></tr>
      ${t.amountTendered > 0 ? '<tr><td colspan="3" style="text-align:right;padding:4px 8px">Tendered</td><td style="text-align:right;padding:4px 8px">${_formatCurrency(t.amountTendered)}</td></tr><tr><td colspan="3" style="text-align:right;padding:4px 8px">Change</td><td style="text-align:right;padding:4px 8px">${_formatCurrency(t.changeGiven)}</td></tr>' : ''}
    </tfoot>
  </table>
  <div class="divider"></div>
  <div class="footer">Thank you for your business!</div>
  <script>window.onload = function() { window.print(); }</script>
</body>
</html>''';

    openPrintWindow(htmlContent);
  }

  void _showDetailDialog(POSTransaction t) {
    final color = _paymentColor(t.paymentMethod);
    final label = t.paymentMethod == 'mpesa'
        ? 'M-Pesa'
        : t.paymentMethod.isNotEmpty
            ? t.paymentMethod[0].toUpperCase() + t.paymentMethod.substring(1)
            : t.paymentMethod;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.receipt_long,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.receiptNumber ?? 'Receipt #${t.id}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(_formatDate(t.createdAt),
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(label,
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => Navigator.of(ctx).pop()),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel(ctx, 'Customer Info'),
                      const SizedBox(height: 8),
                      _detailRow('Customer', t.customerName ?? 'Walk-in'),
                      if (t.customerPhone != null)
                        _detailRow('Phone', t.customerPhone!),
                      _detailRow('Served By', t.servedBy ?? '-'),
                      const SizedBox(height: 16),
                      _sectionLabel(ctx, 'Items (${t.items.length})'),
                      const SizedBox(height: 8),
                      if (t.items.isEmpty)
                        Text('No items',
                            style:
                                TextStyle(color: AppColors.textSecondary))
                      else
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: t.items
                                .asMap()
                                .entries
                                .map((e) => _buildItemRow(e.value,
                                    e.key == t.items.length - 1))
                                .toList(),
                          ),
                        ),
                      const SizedBox(height: 16),
                      _sectionLabel(ctx, 'Summary'),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            _detailRow(
                                'Subtotal', _formatCurrency(t.subtotal)),
                            if (t.discount > 0)
                              _detailRow('Discount',
                                  '- ${_formatCurrency(t.discount)}',
                                  valueColor: AppColors.success),
                            if (t.taxAmount > 0)
                              _detailRow(
                                  'Tax', _formatCurrency(t.taxAmount)),
                            const Divider(height: 16),
                            _detailRow('Total', _formatCurrency(t.totalAmount),
                                bold: true),
                            if (t.amountTendered > 0) ...[
                              _detailRow('Tendered',
                                  _formatCurrency(t.amountTendered)),
                              _detailRow('Change',
                                  _formatCurrency(t.changeGiven)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (kIsWeb)
                      OutlinedButton.icon(
                        onPressed: () => _printReceipt(t),
                        icon: const Icon(Icons.print_outlined, size: 16),
                        label: const Text('Print Receipt'),
                      ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemRow(POSItem item, bool isLast) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(item.medicationName ?? 'Item',
                style: const TextStyle(fontSize: 13)),
          ),
          Text('${item.quantity} ×',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 6),
          SizedBox(
            width: 80,
            child: Text(_formatCurrency(item.unitPrice),
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 90,
            child: Text(_formatCurrency(item.lineTotal),
                textAlign: TextAlign.end,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext ctx, String text) => Text(
        text,
        style: Theme.of(ctx)
            .textTheme
            .labelLarge
            ?.copyWith(color: AppColors.textSecondary),
      );

  Widget _detailRow(String label, String value,
      {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  fontSize: bold ? 15 : 13,
                  color: valueColor,
                )),
          ),
        ],
      ),
    );
  }
}

class _PaymentFilterDropdown extends StatelessWidget {
  final String? value;
  final List<String> methods;
  final ValueChanged<String?> onChanged;

  const _PaymentFilterDropdown({
    required this.value,
    required this.methods,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButton<String>(
          value: value,
          hint: const Text('All Methods', style: TextStyle(fontSize: 13)),
          items: [
            const DropdownMenuItem(
                value: null,
                child:
                    Text('All Methods', style: TextStyle(fontSize: 13))),
            ...methods.map((m) => DropdownMenuItem(
                value: m,
                child: Text(
                    m == 'mpesa'
                        ? 'M-Pesa'
                        : m.isNotEmpty
                            ? m[0].toUpperCase() + m.substring(1)
                            : m,
                    style: const TextStyle(fontSize: 13)))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;

  const _InfoChip({required this.label, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: c, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
