import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../inventory/providers/stock_adjustment_provider.dart';
import '../../pos/providers/sales_analytics_provider.dart';
import '../providers/branch_provider.dart';

class PharmacyReportsScreen extends ConsumerStatefulWidget {
  const PharmacyReportsScreen({super.key});

  @override
  ConsumerState<PharmacyReportsScreen> createState() =>
      _PharmacyReportsScreenState();
}

class _PharmacyReportsScreenState
    extends ConsumerState<PharmacyReportsScreen> {
  String _period = 'month';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _exportingPdf = false;
  final _nf = NumberFormat('#,##0', 'en_US');

  static double _d(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
  static int _i(dynamic v) =>
      v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

  bool get _isCustomRange => _dateFrom != null && _dateTo != null;

  ({String period, int? branchId, String? dateFrom, String? dateTo})
      _providerParams(int? branchId) {
    final fmt = DateFormat('yyyy-MM-dd');
    return (
      period: _period,
      branchId: branchId,
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
      builder: (context, child) => Theme(
        data: Theme.of(context),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dateFrom = picked.start;
        _dateTo = picked.end;
      });
    }
  }

  void _clearDateRange() {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
    });
  }

  String _fmt(dynamic v) => 'KSh ${_nf.format(_d(v).toInt())}';

  String _fmtK(double v) {
    if (v >= 1_000_000) return '${(v / 1_000_000).toStringAsFixed(1)}M';
    if (v >= 1_000) return '${(v / 1_000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  String get _periodLabel {
    if (_isCustomRange) {
      final fmt = DateFormat('dd MMM yyyy');
      return '${fmt.format(_dateFrom!)} – ${fmt.format(_dateTo!)}';
    }
    switch (_period) {
      case 'today':
        return 'Today';
      case 'week':
        return 'This Week';
      case 'year':
        return 'This Year';
      default:
        return 'This Month';
    }
  }

  // ─── PDF Export ──────────────────────────────────────────────────────────────

  Future<void> _downloadPdf() async {
    final activeBranch = ref.read(activeBranchProvider);
    final salesAsync = ref.read(salesAnalyticsProvider(_providerParams(activeBranch?.id)));
    final inventoryAsync = ref.read(inventoryAnalyticsProvider);
    final sales = salesAsync.valueOrNull;
    final inv = inventoryAsync.valueOrNull;

    if (sales == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sales data is not yet loaded. Please wait.')),
      );
      return;
    }

    setState(() => _exportingPdf = true);
    try {
      final doc = pw.Document();
      final now = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());

      final revenue = _d(sales['total_revenue']);
      final discount = _d(sales['total_discount']);
      final txns = _i(sales['transaction_count']);
      final avg = _d(sales['avg_transaction']);
      final daily = (sales['daily_sales'] as List? ?? []);
      final topItems = (sales['top_selling_items'] as List? ?? []);
      final catSales = (sales['category_sales'] as List? ?? []);

      final sortedDaily = [...daily]
        ..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));

      final primaryColor = PdfColor.fromHex('0D9488');
      final headerBg = PdfColor.fromHex('F0FDFA');
      const borderColor = PdfColors.grey300;

      pw.TableRow makeHeaderRow(List<String> cols) => pw.TableRow(
            decoration: pw.BoxDecoration(color: primaryColor),
            children: cols
                .map((c) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: pw.Text(c,
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                              color: PdfColors.white)),
                    ))
                .toList(),
          );

      pw.TableRow makeDataRow(List<String> cells, {bool shaded = false}) =>
          pw.TableRow(
            decoration: shaded
                ? pw.BoxDecoration(color: PdfColor.fromHex('F8FAFC'))
                : null,
            children: cells
                .map((c) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      child: pw.Text(c,
                          style: const pw.TextStyle(fontSize: 9.5)),
                    ))
                .toList(),
          );

      pw.Widget sectionTitle(String title) => pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 6),
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(title,
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
          );

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (_) => pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: headerBg,
              border: pw.Border.all(color: primaryColor, width: 1.5),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Pharmacy Report — $_periodLabel',
                        style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor)),
                    pw.SizedBox(height: 3),
                    pw.Text('Generated: $now',
                        style: pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          ),
          build: (ctx) => [
            // ── Sales Summary ──
            sectionTitle('Sales Summary'),
            pw.Table(
              border: pw.TableBorder.all(color: borderColor, width: 0.5),
              children: [
                makeHeaderRow(['Metric', 'Value']),
                makeDataRow(['Total Revenue', _fmt(revenue)]),
                makeDataRow(['Total Transactions', '$txns'], shaded: true),
                makeDataRow(['Average Transaction', _fmt(avg)]),
                makeDataRow(['Total Discounts', _fmt(discount)], shaded: true),
              ],
            ),
            pw.SizedBox(height: 18),

            // ── Top Products ──
            if (topItems.isNotEmpty) ...[
              sectionTitle('Top Selling Products'),
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                columnWidths: const {
                  0: pw.FixedColumnWidth(28),
                  1: pw.FlexColumnWidth(3),
                  2: pw.FlexColumnWidth(2),
                  3: pw.FixedColumnWidth(48),
                },
                children: [
                  makeHeaderRow(['#', 'Product', 'Revenue', 'Units']),
                  ...topItems.take(10).toList().asMap().entries.map(
                        (e) => makeDataRow(
                          [
                            '${e.key + 1}',
                            '${e.value['medication_name'] ?? 'Unknown'}',
                            _fmt(e.value['total_revenue']),
                            '${_i(e.value['total_qty'])}',
                          ],
                          shaded: e.key.isOdd,
                        ),
                      ),
                ],
              ),
              pw.SizedBox(height: 18),
            ],

            // ── Category Breakdown ──
            if (catSales.isNotEmpty) ...[
              sectionTitle('Category Breakdown'),
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                children: [
                  makeHeaderRow(['Category', 'Revenue', 'Units']),
                  ...catSales.asMap().entries.map(
                        (e) => makeDataRow(
                          [
                            '${e.value['category_name'] ?? 'Uncategorised'}',
                            _fmt(e.value['total_revenue']),
                            '${_i(e.value['total_qty'])}',
                          ],
                          shaded: e.key.isOdd,
                        ),
                      ),
                ],
              ),
              pw.SizedBox(height: 18),
            ],

            // ── Inventory Health ──
            if (inv != null) ...[
              sectionTitle('Inventory Health'),
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                children: [
                  makeHeaderRow(['Metric', 'Value']),
                  makeDataRow(
                      ['Total Items', '${_i(inv['total_items'])}']),
                  makeDataRow(
                      ['Low Stock', '${_i(inv['low_stock_count'])}'],
                      shaded: true),
                  makeDataRow(
                      ['Out of Stock', '${_i(inv['out_of_stock'])}']),
                  makeDataRow(
                      ['Expired Batches', '${_i(inv['expired_batches'])}'],
                      shaded: true),
                  makeDataRow([
                    'Total Cost Value',
                    _fmt(inv['total_cost_value'] ?? 0),
                  ]),
                  makeDataRow([
                    'Total Retail Value',
                    _fmt(inv['total_retail_value'] ?? 0),
                  ], shaded: true),
                ],
              ),
              pw.SizedBox(height: 18),
            ],

            // ── Daily Breakdown ──
            if (sortedDaily.isNotEmpty) ...[
              sectionTitle('Daily Breakdown (Last 30 Days)'),
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                columnWidths: const {
                  0: pw.FixedColumnWidth(80),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FixedColumnWidth(70),
                },
                children: [
                  makeHeaderRow(['Date', 'Revenue', 'Transactions']),
                  ...sortedDaily.take(30).toList().asMap().entries.map(
                        (e) => makeDataRow(
                          [
                            '${e.value['date'] ?? ''}',
                            _fmt(e.value['revenue']),
                            '${_i(e.value['count'])}',
                          ],
                          shaded: e.key.isOdd,
                        ),
                      ),
                ],
              ),
            ],
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (_) async => doc.save());
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final activeBranch = ref.watch(activeBranchProvider);
    final salesAsync = ref.watch(salesAnalyticsProvider(_providerParams(activeBranch?.id)));
    final inventoryAsync = ref.watch(inventoryAnalyticsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = (constraints.maxWidth - 48.0).clamp(200.0, 2000.0);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              _buildHeader(cw),
              const SizedBox(height: 24),

              // ── Sales KPIs ───────────────────────────────────────────────
              salesAsync.when(
                loading: () => const Center(child: LoadingWidget()),
                error: (e, _) => _ErrorCard(message: 'Sales data unavailable: $e'),
                data: (sales) => _buildSalesContent(sales, cw),
              ),
              const SizedBox(height: 20),

              // ── Inventory Health ─────────────────────────────────────────
              inventoryAsync.when(
                loading: () => const SizedBox(
                  height: 120,
                  child: Center(child: LoadingWidget()),
                ),
                error: (e, _) =>
                    _ErrorCard(message: 'Inventory data unavailable: $e'),
                data: (inv) => _buildInventorySection(inv, cw),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(double cw) {
    final downloadBtn = _exportingPdf
        ? SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              ),
            ),
          )
        : OutlinedButton.icon(
            onPressed: _downloadPdf,
            icon: const Icon(Icons.download_outlined, size: 17),
            label: const Text('PDF'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: const TextStyle(fontSize: 13),
            ),
          );

    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPeriodSelector(),
        const SizedBox(width: 8),
        _buildDateRangeButton(),
        const SizedBox(width: 10),
        downloadBtn,
      ],
    );

    if (cw > 640) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Reports',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text('Business intelligence & analytics',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
          controls,
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Reports',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text('Business intelligence & analytics',
            style:
                TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 12),
        controls,
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in [
            ('today', 'Today'),
            ('week', 'Week'),
            ('month', 'Month'),
            ('year', 'Year'),
          ])
            _PeriodTab(
              label: e.$2,
              selected: _period == e.$1,
              onTap: () => setState(() => _period = e.$1),
            ),
        ],
      ),
    );
  }

  Widget _buildDateRangeButton() {
    final fmt = DateFormat('dd MMM');
    if (_isCustomRange) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: _pickDateRange,
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(8)),
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
              borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 8),
                child: Icon(Icons.close,
                    size: 14, color: AppColors.primary),
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

  // ─── Sales content ───────────────────────────────────────────────────────────

  Widget _buildSalesContent(Map<String, dynamic> sales, double cw) {
    final revenue = _d(sales['total_revenue']);
    final discount = _d(sales['total_discount']);
    final txns = _i(sales['transaction_count']);
    final avg = _d(sales['avg_transaction']);
    final daily = (sales['daily_sales'] as List? ?? []);
    final topItems = (sales['top_selling_items'] as List? ?? []);
    final catSales = (sales['category_sales'] as List? ?? []);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildKpiRow(revenue, discount, txns, avg, cw),
        const SizedBox(height: 20),
        _buildChartsRow(daily, topItems, cw),
        const SizedBox(height: 20),
        _buildTopProductsSection(topItems),
        const SizedBox(height: 20),
        _buildCategorySection(catSales, cw),
        const SizedBox(height: 20),
        _buildDailyTable(daily),
      ],
    );
  }

  // ─── KPI Row ─────────────────────────────────────────────────────────────────

  Widget _buildKpiRow(
      double revenue, double discount, int txns, double avg, double cw) {
    final cols = cw > 900
        ? 4
        : cw > 600
            ? 2
            : 1;
    final w = (cw - (cols - 1) * 12) / cols;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: w,
          child: _KpiCard(
            icon: Icons.payments_outlined,
            title: 'Revenue',
            value: _fmt(revenue),
            subtitle: _periodLabel,
            color: AppColors.primary,
          ),
        ),
        SizedBox(
          width: w,
          child: _KpiCard(
            icon: Icons.receipt_long_outlined,
            title: 'Transactions',
            value: '$txns',
            subtitle: _periodLabel,
            color: AppColors.secondary,
          ),
        ),
        SizedBox(
          width: w,
          child: _KpiCard(
            icon: Icons.trending_up_outlined,
            title: 'Avg. Sale',
            value: _fmt(avg),
            subtitle: 'per transaction',
            color: AppColors.success,
          ),
        ),
        SizedBox(
          width: w,
          child: _KpiCard(
            icon: Icons.local_offer_outlined,
            title: 'Discounts',
            value: _fmt(discount),
            subtitle: _periodLabel,
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }

  // ─── Charts Row ──────────────────────────────────────────────────────────────

  Widget _buildChartsRow(
      List daily, List topItems, double cw) {
    if (cw > 800) {
      final w1 = cw * 0.58 - 6;
      final w2 = cw * 0.42 - 6;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: w1, child: _buildRevenueTrendCard(daily)),
          const SizedBox(width: 12),
          SizedBox(width: w2, child: _buildTopBarCard(topItems)),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRevenueTrendCard(daily),
        const SizedBox(height: 12),
        _buildTopBarCard(topItems),
      ],
    );
  }

  Widget _buildRevenueTrendCard(List daily) {
    final sorted = [...daily]
      ..sort((a, b) => '${a['date']}'.compareTo('${b['date']}'));
    final spots = sorted
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), _d(e.value['revenue'])))
        .toList();
    final rawMax =
        spots.isEmpty ? 0.0 : spots.map((s) => s.y).reduce(math.max);
    final maxY = rawMax > 0 ? rawMax * 1.25 : 1000.0;

    return _ChartCard(
      title: 'Revenue Trend',
      subtitle: '$_periodLabel — daily',
      icon: Icons.show_chart_rounded,
      child: spots.isEmpty
          ? _emptyChart('No sales data')
          : LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withValues(alpha: 0.08),
                    ),
                  ),
                ],
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 54,
                      getTitlesWidget: (v, _) => Text(
                        _fmtK(v),
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 9),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval:
                          math.max(1.0, (spots.length / 5).ceilToDouble()),
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= sorted.length) {
                          return const SizedBox.shrink();
                        }
                        final parts =
                            '${sorted[idx]['date']}'.split('-');
                        final label = parts.length >= 3
                            ? '${parts[2]}/${parts[1]}'
                            : '${sorted[idx]['date']}';
                        return Text(label,
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 8.5));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.border.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: spots.length <= 1
                    ? 1.0
                    : (spots.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
              ),
            ),
    );
  }

  Widget _buildTopBarCard(List items) {
    final top5 = items.take(5).toList();
    final rawMax = top5.isEmpty
        ? 0.0
        : top5.map((e) => _d(e['total_revenue'])).reduce(math.max);
    final maxY = rawMax > 0 ? rawMax * 1.25 : 1000.0;

    const barColors = [
      Color(0xFF0D9488),
      Color(0xFF6366F1),
      Color(0xFF22C55E),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
    ];

    return _ChartCard(
      title: 'Top 5 Products',
      subtitle: 'By revenue — $_periodLabel',
      icon: Icons.bar_chart_rounded,
      child: top5.isEmpty
          ? _emptyChart('No sales data')
          : BarChart(
              BarChartData(
                barGroups: top5.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: _d(e.value['total_revenue']),
                        color: barColors[e.key % barColors.length],
                        width: 22,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 54,
                      getTitlesWidget: (v, _) => Text(
                        _fmtK(v),
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 9),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= top5.length) {
                          return const SizedBox.shrink();
                        }
                        final name = '${top5[idx]['medication_name']}';
                        final short = name.length > 8
                            ? '${name.substring(0, 7)}\u2026'
                            : name;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(short,
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 8.5)),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.border.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                maxY: maxY,
              ),
            ),
    );
  }

  Widget _emptyChart(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_outlined, size: 36, color: AppColors.border),
          const SizedBox(height: 8),
          Text(msg,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  // ─── Inventory Health ────────────────────────────────────────────────────────

  Widget _buildInventorySection(Map<String, dynamic> inv, double cw) {
    final total = _i(inv['total_items']);
    final low = _i(inv['low_stock_count']);
    final out = _i(inv['out_of_stock']);
    final expired = _i(inv['expired_batches']);
    final inStock = math.max(0, total - low - out);

    final pieWidget = SizedBox(
      width: 170,
      height: 170,
      child: _buildPieChart(inStock, low, out, expired),
    );
    final legend = _buildPieLegend(inStock, low, out, expired);
    final grid = _buildInventoryGrid(inv);

    return _SectionCard(
      title: 'Inventory Health',
      icon: Icons.inventory_2_outlined,
      child: cw > 680
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                pieWidget,
                const SizedBox(width: 16),
                legend,
                const SizedBox(width: 24),
                Container(width: 1, height: 100, color: AppColors.border),
                const SizedBox(width: 24),
                Expanded(child: grid),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                    height: 160,
                    child: _buildPieChart(inStock, low, out, expired)),
                const SizedBox(height: 12),
                legend,
                const SizedBox(height: 16),
                grid,
              ],
            ),
    );
  }

  Widget _buildPieChart(int inStock, int low, int out, int expired) {
    final total = inStock + low + out + expired;
    if (total == 0) {
      return Center(
        child: Text('No inventory data',
            style:
                TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      );
    }
    return PieChart(
      PieChartData(
        sections: [
          if (inStock > 0)
            PieChartSectionData(
              value: inStock.toDouble(),
              color: AppColors.success,
              title: '$inStock',
              radius: 60,
              titleStyle: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
          if (low > 0)
            PieChartSectionData(
              value: low.toDouble(),
              color: AppColors.warning,
              title: '$low',
              radius: 60,
              titleStyle: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
          if (out > 0)
            PieChartSectionData(
              value: out.toDouble(),
              color: AppColors.error,
              title: '$out',
              radius: 60,
              titleStyle: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
          if (expired > 0)
            PieChartSectionData(
              value: expired.toDouble(),
              color: const Color(0xFF7C3AED),
              title: '$expired',
              radius: 60,
              titleStyle: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
        ],
        centerSpaceRadius: 30,
        sectionsSpace: 2,
      ),
    );
  }

  Widget _buildPieLegend(int inStock, int low, int out, int expired) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LegendDot(color: AppColors.success, label: 'In Stock ($inStock)'),
        const SizedBox(height: 8),
        _LegendDot(color: AppColors.warning, label: 'Low Stock ($low)'),
        const SizedBox(height: 8),
        _LegendDot(color: AppColors.error, label: 'Out of Stock ($out)'),
        const SizedBox(height: 8),
        _LegendDot(
            color: const Color(0xFF7C3AED), label: 'Expired ($expired)'),
      ],
    );
  }

  Widget _buildInventoryGrid(Map<String, dynamic> inv) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MiniStatTile(
          icon: Icons.inventory_2_rounded,
          label: 'Total Items',
          value: '${_i(inv['total_items'])}',
          color: AppColors.primary,
        ),
        _MiniStatTile(
          icon: Icons.monetization_on_outlined,
          label: 'Cost Value',
          value: _fmt(inv['total_cost_value'] ?? 0),
          color: AppColors.textSecondary,
        ),
        _MiniStatTile(
          icon: Icons.sell_outlined,
          label: 'Retail Value',
          value: _fmt(inv['total_retail_value'] ?? 0),
          color: AppColors.success,
        ),
        _MiniStatTile(
          icon: Icons.event_busy_outlined,
          label: 'Expired Batches',
          value: '${_i(inv['expired_batches'])}',
          color: AppColors.error,
        ),
      ],
    );
  }

  // ─── Top Products ─────────────────────────────────────────────────────────────

  Widget _buildTopProductsSection(List items) {
    final top10 = items.take(10).toList();
    final maxRev = top10.isEmpty
        ? 1.0
        : top10.map((e) => _d(e['total_revenue'])).reduce(math.max);

    return _SectionCard(
      title: 'Top Selling Products',
      icon: Icons.emoji_events_outlined,
      trailing: Text(_periodLabel,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      child: top10.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No sales data yet',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 32),
                    Expanded(
                      child: Text('Product',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                    ),
                    SizedBox(
                      width: 80,
                      child: Text('Revenue',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text('Units',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 4),
                ...top10.asMap().entries.map((e) {
                  final rank = e.key + 1;
                  final rev = _d(e.value['total_revenue']);
                  final qty = _i(e.value['total_qty']);
                  final name =
                      '${e.value['medication_name'] ?? 'Unknown'}';
                  return _ProductRankRow(
                    rank: rank,
                    name: name,
                    revenue: _fmt(rev),
                    qty: qty,
                    fraction:
                        maxRev > 0 ? (rev / maxRev).clamp(0.0, 1.0) : 0.0,
                  );
                }),
              ],
            ),
    );
  }

  // ─── Category Breakdown ───────────────────────────────────────────────────────

  Widget _buildCategorySection(List catSales, double cw) {
    if (catSales.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      title: 'Category Breakdown',
      icon: Icons.category_outlined,
      trailing: Text(_periodLabel,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: catSales.map<Widget>((cat) {
          final rev = _d(cat['total_revenue']);
          final qty = _i(cat['total_qty']);
          final name = '${cat['category_name'] ?? 'Uncategorised'}';
          final maxRev = catSales
              .map((c) => _d(c['total_revenue']))
              .reduce(math.max);
          final fraction =
              maxRev > 0 ? (rev / maxRev).clamp(0.0, 1.0) : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_fmt(rev),
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary)),
                              const SizedBox(width: 12),
                              Text('$qty units',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 5,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation(
                              AppColors.secondary.withValues(alpha: 0.7)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Daily Table ──────────────────────────────────────────────────────────────

  Widget _buildDailyTable(List daily) {
    final sorted = [...daily]
      ..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));

    return _SectionCard(
      title: 'Daily Breakdown',
      icon: Icons.calendar_today_outlined,
      trailing: Text(_periodLabel,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      child: sorted.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No daily data',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                    AppColors.primary.withValues(alpha: 0.05)),
                dataRowMinHeight: 36,
                dataRowMaxHeight: 42,
                columnSpacing: 28,
                columns: [
                  DataColumn(
                    label: Text('Date',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            fontSize: 13)),
                  ),
                  DataColumn(
                    label: Text('Revenue',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            fontSize: 13)),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text('Transactions',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            fontSize: 13)),
                    numeric: true,
                  ),
                ],
                rows: sorted.take(30).map((day) {
                  return DataRow(cells: [
                    DataCell(Text('${day['date'] ?? ''}',
                        style: const TextStyle(fontSize: 13))),
                    DataCell(Text(_fmt(day['revenue']),
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                            fontSize: 13))),
                    DataCell(Text('${_i(day['count'])}',
                        style: const TextStyle(fontSize: 13))),
                  ]);
                }).toList(),
              ),
            ),
    );
  }
}

// ─── Period Tab ───────────────────────────────────────────────────────────────

class _PeriodTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodTab(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── KPI Card ─────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String title, value, subtitle;
  final Color color;

  const _KpiCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              Container(
                width: 7,
                height: 7,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 3),
          Text(title,
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(subtitle,
              style:
                  TextStyle(color: color.withValues(alpha: 0.75), fontSize: 11)),
        ],
      ),
    );
  }
}

// ─── Chart Card ───────────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: AppColors.primary),
              const SizedBox(width: 7),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(height: 210, child: child),
        ],
      ),
    );
  }
}

// ─── Section Card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 12),
            child: Row(
              children: [
                Icon(icon, size: 17, color: AppColors.primary),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }
}

// ─── Mini Stat Tile ───────────────────────────────────────────────────────────

class _MiniStatTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;

  const _MiniStatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: color)),
              Text(label,
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Legend Dot ───────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ─── Product Rank Row ─────────────────────────────────────────────────────────

class _ProductRankRow extends StatelessWidget {
  final int rank, qty;
  final String name, revenue;
  final double fraction;

  const _ProductRankRow({
    required this.rank,
    required this.name,
    required this.revenue,
    required this.qty,
    required this.fraction,
  });

  static String _medal(int r) =>
      r == 1 ? '🥇' : r == 2 ? '🥈' : '🥉';

  @override
  Widget build(BuildContext context) {
    final rankColor = rank == 1
        ? const Color(0xFFD97706)
        : rank == 2
            ? const Color(0xFF94A3B8)
            : rank == 3
                ? const Color(0xFFB45309)
                : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              rank <= 3 ? _medal(rank) : '#$rank',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: rank <= 3 ? 16 : 12,
                  color: rankColor),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 4,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation(
                        AppColors.primary.withValues(alpha: 0.65)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(revenue,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.primary)),
          ),
          SizedBox(
            width: 60,
            child: Text('$qty units',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ─── Error Card ───────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
