import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/api.dart';
import '../../../widgets/common.dart';

// ─── Providers ──────────────────────────────────────
final _periodProvider = StateProvider<String>((ref) => 'month');
final _tabProvider = StateProvider<int>((ref) => 0);

final _reportsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, period) async {
  final dio = ref.read(dioProvider);
  final q = period.startsWith('custom:')
      ? {'date_from': period.split(':')[1], 'date_to': period.split(':')[2]}
      : {'period': period};
  final results = await Future.wait([
    dio.get('/reports/sales-summary/', queryParameters: q).then((r) => r.data).catchError((_) => null),
    dio.get('/reports/top-products/', queryParameters: q).then((r) => r.data).catchError((_) => null),
    dio.get('/reports/cashier-performance/', queryParameters: q).then((r) => r.data).catchError((_) => null),
    dio.get('/reports/profit-loss/', queryParameters: q).then((r) => r.data).catchError((_) => null),
    dio.get('/reports/inventory-valuation/').then((r) => r.data).catchError((_) => null),
    dio.get('/reports/expiry/').then((r) => r.data).catchError((_) => null),
    dio.get('/reports/low-stock/').then((r) => r.data).catchError((_) => null),
  ]);
  return {
    'sales': results[0],
    'top': results[1],
    'cashiers': results[2],
    'pnl': results[3],
    'inventory': results[4],
    'expiry': results[5],
    'lowstock': results[6],
  };
});

String _ksh(dynamic v) => 'KSh ${NumberFormat('#,##0').format((double.tryParse('$v') ?? 0).round())}';
String _num(dynamic v) => NumberFormat('#,##0').format(int.tryParse('$v') ?? (double.tryParse('$v')?.round() ?? 0));
String _pct(dynamic v) => '${(double.tryParse('$v') ?? 0).toStringAsFixed(1)}%';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  static const _periods = [
    ('today', 'Today'),
    ('yesterday', 'Yesterday'),
    ('last7', '7 Days'),
    ('last30', '30 Days'),
    ('last90', '90 Days'),
    ('week', 'This Week'),
    ('month', 'This Month'),
    ('year', 'This Year'),
    ('custom', 'Custom'),
  ];

  static const _tabs = [
    (Icons.receipt_rounded, 'Sales'),
    (Icons.emoji_events_rounded, 'Top'),
    (Icons.badge_rounded, 'Cashiers'),
    (Icons.account_balance_rounded, 'P&L'),
    (Icons.inventory_2_rounded, 'Inventory'),
    (Icons.schedule_rounded, 'Expiry'),
    (Icons.warning_rounded, 'Low Stock'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) ref.read(_tabProvider.notifier).state = _tabCtrl.index;
    });
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

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

  void _showPdfPreview(BuildContext context, Map<String, dynamic> data, String period, int tabIndex) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _PdfPreviewPage(data: data, period: period, tabIndex: tabIndex),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(_periodProvider);
    final data = ref.watch(_reportsProvider(period));
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports Dashboard'),
        actions: [
          if (data.valueOrNull != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: 'Export PDF',
              onPressed: () => _showPdfPreview(context, data.valueOrNull!, period, ref.read(_tabProvider)),
            ),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => ref.invalidate(_reportsProvider(period))),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerHeight: 0,
          tabs: _tabs.map((t) => Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(t.$1, size: 16), const SizedBox(width: 6), Text(t.$2)]))).toList(),
        ),
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
          error: (e, _) => ErrorRetry(message: 'Failed to load reports', onRetry: () => ref.invalidate(_reportsProvider(period))),
          data: (d) => TabBarView(
            controller: _tabCtrl,
            children: [
              _SalesTab(d: d['sales'], cs: cs, isDark: isDark),
              _TopProductsTab(d: d['top'], cs: cs),
              _CashiersTab(d: d['cashiers'], cs: cs),
              _PnlTab(d: d['pnl'], cs: cs),
              _InventoryTab(d: d['inventory'], cs: cs),
              _ExpiryTab(d: d['expiry'], cs: cs),
              _LowStockTab(d: d['lowstock'], cs: cs),
            ],
          ),
        )),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════
// PDF PREVIEW & BUILDER
// ════════════════════════════════════════════════════
class _PdfPreviewPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final String period;
  final int tabIndex;
  const _PdfPreviewPage({required this.data, required this.period, required this.tabIndex});

  static const _tabNames = ['Sales Summary', 'Top Products', 'Cashier Performance', 'Profit & Loss', 'Inventory Valuation', 'Expiry Report', 'Low Stock'];

  String get _periodLabel {
    if (period.startsWith('custom:')) {
      final parts = period.split(':');
      return '${parts[1]} to ${parts[2]}';
    }
    return {
      'today': 'Today', 'yesterday': 'Yesterday', 'last7': 'Last 7 Days',
      'last30': 'Last 30 Days', 'last90': 'Last 90 Days', 'week': 'This Week',
      'month': 'This Month', 'year': 'This Year',
    }[period] ?? period;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${_tabNames[tabIndex]} — PDF')),
      body: PdfPreview(
        build: (_) => _buildPdf(),
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: 'AdhereMed_${_tabNames[tabIndex].replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      ),
    );
  }

  Future<Uint8List> _buildPdf() async {
    final pdf = pw.Document();
    final theme = pw.ThemeData.withFont(
      base: await PdfGoogleFonts.interRegular(),
      bold: await PdfGoogleFonts.interBold(),
    );

    final accent = PdfColor.fromHex('#6366F1');
    final green = PdfColor.fromHex('#22C55E');
    final red = PdfColor.fromHex('#EF4444');
    final grey = PdfColor.fromHex('#6B7280');
    final lightBg = PdfColor.fromHex('#F9FAFB');

    pw.Widget header() => pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(color: accent, borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('AdhereMed', style: pw.TextStyle(color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(_tabNames[tabIndex], style: pw.TextStyle(color: PdfColors.white.shade(0.85), fontSize: 12)),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('Period: $_periodLabel', style: pw.TextStyle(color: PdfColors.white.shade(0.9), fontSize: 10)),
          pw.SizedBox(height: 2),
          pw.Text('Generated: ${DateFormat('MMM d, yyyy HH:mm').format(DateTime.now())}', style: pw.TextStyle(color: PdfColors.white.shade(0.7), fontSize: 9)),
        ]),
      ]),
    );

    pw.Widget kpiRow(List<(String, String)> items) => pw.Row(
      children: items.map((kpi) => pw.Expanded(child: pw.Container(
        margin: const pw.EdgeInsets.all(4),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(color: lightBg, borderRadius: pw.BorderRadius.circular(6), border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB'))),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(kpi.$1, style: pw.TextStyle(fontSize: 8, color: grey)),
          pw.SizedBox(height: 3),
          pw.Text(kpi.$2, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ]),
      ))).toList(),
    );

    pw.Widget tableHeader(List<String> cols, {List<int>? flex}) {
      return pw.Container(
        color: PdfColor.fromHex('#F3F4F6'),
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: pw.Row(children: cols.asMap().entries.map((e) => pw.Expanded(
          flex: flex != null ? flex[e.key] : 1,
          child: pw.Text(e.value, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: grey)),
        )).toList()),
      );
    }

    pw.Widget tableRow(List<String> cols, {List<int>? flex, PdfColor? highlightColor}) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromHex('#F3F4F6')))),
        child: pw.Row(children: cols.asMap().entries.map((e) => pw.Expanded(
          flex: flex != null ? flex[e.key] : 1,
          child: pw.Text(e.value, style: pw.TextStyle(fontSize: 9, color: highlightColor)),
        )).toList()),
      );
    }

    switch (tabIndex) {
      case 0: // Sales
        final sales = data['sales'];
        if (sales != null) {
          final pos = sales['pos'] ?? {};
          final disp = sales['dispensing'] ?? {};
          final pmPos = (sales['payment_mix_pos'] as List?) ?? [];
          final pmDisp = (sales['payment_mix_dispensing'] as List?) ?? [];

          pdf.addPage(pw.MultiPage(theme: theme, pageFormat: PdfPageFormat.a4, build: (ctx) => [
            header(),
            pw.SizedBox(height: 16),
            kpiRow([('Transactions', _num(sales['combined_count'])), ('Total Revenue', _ksh(sales['combined_revenue'])), ('POS Revenue', _ksh(pos['revenue'])), ('Dispensing', _ksh(disp['revenue']))]),
            pw.SizedBox(height: 20),
            if (pmPos.isNotEmpty) ...[
              pw.Text('POS Payment Mix', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              tableHeader(['Method', 'Count', 'Revenue', '% Share'], flex: [3, 1, 2, 1]),
              ...pmPos.map((r) {
                final rev = double.tryParse('${r['revenue'] ?? 0}') ?? 0;
                final total = pmPos.fold<double>(0, (s, x) => s + (double.tryParse('${x['revenue'] ?? 0}') ?? 0));
                return tableRow(['${r['payment_method'] ?? ''}', '${r['count'] ?? 0}', _ksh(rev), total > 0 ? '${(rev / total * 100).toStringAsFixed(1)}%' : '0%'], flex: [3, 1, 2, 1]);
              }),
              pw.SizedBox(height: 16),
            ],
            if (pmDisp.isNotEmpty) ...[
              pw.Text('Dispensing Payment Mix', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              tableHeader(['Method', 'Count', 'Revenue', '% Share'], flex: [3, 1, 2, 1]),
              ...pmDisp.map((r) {
                final rev = double.tryParse('${r['revenue'] ?? 0}') ?? 0;
                final total = pmDisp.fold<double>(0, (s, x) => s + (double.tryParse('${x['revenue'] ?? 0}') ?? 0));
                return tableRow(['${r['payment_method'] ?? ''}', '${r['count'] ?? 0}', _ksh(rev), total > 0 ? '${(rev / total * 100).toStringAsFixed(1)}%' : '0%'], flex: [3, 1, 2, 1]);
              }),
            ],
          ]));
        }
        break;

      case 1: // Top Products
        final top = data['top'];
        if (top != null) {
          final items = (top['items'] as List?) ?? [];
          pdf.addPage(pw.MultiPage(theme: theme, pageFormat: PdfPageFormat.a4, build: (ctx) => [
            header(),
            pw.SizedBox(height: 16),
            pw.Text('${items.length} Top Selling Medications', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            tableHeader(['#', 'Medication', 'Qty Sold', 'Orders', 'Revenue'], flex: [1, 5, 2, 1, 3]),
            ...items.asMap().entries.map((e) => tableRow([
              '${e.key + 1}', '${e.value['medication_name'] ?? ''}', _num(e.value['quantity']), '${e.value['orders'] ?? 0}', _ksh(e.value['revenue']),
            ], flex: [1, 5, 2, 1, 3])),
          ]));
        }
        break;

      case 2: // Cashiers
        final c = data['cashiers'];
        if (c != null) {
          final cashiers = (c['cashiers'] as List?) ?? [];
          pdf.addPage(pw.MultiPage(theme: theme, pageFormat: PdfPageFormat.a4, build: (ctx) => [
            header(),
            pw.SizedBox(height: 16),
            pw.Text('${cashiers.length} Cashiers', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            tableHeader(['Cashier', 'Transactions', 'Discount', 'Avg Basket', 'Revenue'], flex: [4, 2, 2, 2, 3]),
            ...cashiers.map((cs) => tableRow([
              '${cs['name'] ?? ''}', '${cs['transactions'] ?? 0}', _ksh(cs['discount']), _ksh(cs['avg_basket']), _ksh(cs['revenue']),
            ], flex: [4, 2, 2, 2, 3])),
          ]));
        }
        break;

      case 3: // P&L
        final pnl = data['pnl'];
        if (pnl != null) {
          final net = double.tryParse('${pnl['net_profit'] ?? 0}') ?? 0;
          final margin = double.tryParse('${pnl['gross_margin_pct'] ?? 0}') ?? 0;
          pdf.addPage(pw.MultiPage(theme: theme, pageFormat: PdfPageFormat.a4, build: (ctx) => [
            header(),
            pw.SizedBox(height: 16),
            kpiRow([('Revenue', _ksh(pnl['revenue'])), ('COGS', _ksh(pnl['cogs'])), ('Gross Profit', _ksh(pnl['gross_profit'])), ('Net Profit', _ksh(net))]),
            pw.SizedBox(height: 20),
            pw.Text('Income Statement', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            _pdfPnlRow('POS Revenue', _ksh(pnl['pos_revenue'])),
            _pdfPnlRow('Dispensing Revenue', _ksh(pnl['dispensing_revenue'])),
            pw.Divider(color: PdfColor.fromHex('#E5E7EB')),
            _pdfPnlRow('Total Revenue', _ksh(pnl['revenue']), bold: true),
            _pdfPnlRow('Cost of Goods Sold', '(${_ksh(pnl['cogs'])})', color: red),
            pw.Divider(color: PdfColor.fromHex('#E5E7EB')),
            _pdfPnlRow('Gross Profit', _ksh(pnl['gross_profit']), bold: true, color: green),
            _pdfPnlRow('Gross Margin', '${_pct(margin)}', color: margin >= 30 ? green : PdfColor.fromHex('#F59E0B')),
            _pdfPnlRow('Operating Expenses', '(${_ksh(pnl['expenses'])})', color: red),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: net >= 0 ? PdfColor.fromHex('#F0FDF4') : PdfColor.fromHex('#FEF2F2'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Net Profit', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text(_ksh(net), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: net >= 0 ? green : red)),
              ]),
            ),
          ]));
        }
        break;

      case 4: // Inventory
        final inv = data['inventory'];
        if (inv != null) {
          final cats = (inv['by_category'] as List?) ?? [];
          pdf.addPage(pw.MultiPage(theme: theme, pageFormat: PdfPageFormat.a4, build: (ctx) => [
            header(),
            pw.SizedBox(height: 16),
            kpiRow([('SKUs', _num(inv['sku_count'])), ('Units', _num(inv['unit_count'])), ('Cost Value', _ksh(inv['cost_value'])), ('Margin', _ksh(inv['potential_margin']))]),
            pw.SizedBox(height: 20),
            if (cats.isNotEmpty) ...[
              pw.Text('By Category (${cats.length})', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              tableHeader(['Category', 'Units', 'Cost Value', 'Sale Value'], flex: [4, 2, 2, 2]),
              ...cats.map((c) => tableRow([
                '${c['category'] ?? ''}', _num(c['units']), _ksh(c['cost']), _ksh(c['sale']),
              ], flex: [4, 2, 2, 2])),
            ],
          ]));
        }
        break;

      case 5: // Expiry
        final exp = data['expiry'];
        if (exp != null) {
          final batches = (exp['batches'] as List?) ?? [];
          pdf.addPage(pw.MultiPage(theme: theme, pageFormat: PdfPageFormat.a4, build: (ctx) => [
            header(),
            pw.SizedBox(height: 16),
            kpiRow([('Batches Expiring', '${exp['count'] ?? 0}'), ('Horizon', '${exp['days_horizon'] ?? 90} days'), ('Expired Loss', _ksh(exp['expired_loss_value']))]),
            pw.SizedBox(height: 20),
            if (batches.isNotEmpty) ...[
              pw.Text('Expiring Batches (${batches.length})', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              tableHeader(['Medication', 'Batch', 'Qty', 'Expiry Date', 'Days Left', 'Cost'], flex: [4, 2, 1, 2, 1, 2]),
              ...batches.map((b) {
                final daysLeft = int.tryParse('${b['days_left'] ?? 0}') ?? 0;
                return tableRow([
                  '${b['medication_name'] ?? ''}', '${b['batch_number'] ?? ''}', '${b['quantity_remaining'] ?? 0}',
                  '${b['expiry_date'] ?? ''}', daysLeft < 0 ? 'EXPIRED' : '${daysLeft}d', _ksh(b['cost_value']),
                ], flex: [4, 2, 1, 2, 1, 2], highlightColor: daysLeft < 0 ? red : null);
              }),
            ],
          ]));
        }
        break;

      case 6: // Low Stock
        final ls = data['lowstock'];
        if (ls != null) {
          final items = (ls['items'] as List?) ?? [];
          pdf.addPage(pw.MultiPage(theme: theme, pageFormat: PdfPageFormat.a4, build: (ctx) => [
            header(),
            pw.SizedBox(height: 16),
            kpiRow([('Items Below Reorder', '${ls['count'] ?? 0}'), ('Est. Reorder Value', _ksh(ls['estimated_reorder_value']))]),
            pw.SizedBox(height: 20),
            if (items.isNotEmpty) ...[
              pw.Text('Low Stock Items (${items.length})', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              tableHeader(['Medication', 'Category', 'On Hand', 'Reorder Lv', 'Reorder Qty', 'Est. Cost'], flex: [4, 2, 1, 2, 2, 2]),
              ...items.map((it) => tableRow([
                '${it['medication_name'] ?? ''}', '${it['category'] ?? ''}', '${it['quantity'] ?? 0}',
                '${it['reorder_level'] ?? 0}', '${it['reorder_quantity'] ?? 0}', _ksh(it['estimated_reorder_cost']),
              ], flex: [4, 2, 1, 2, 2, 2], highlightColor: (int.tryParse('${it['quantity'] ?? 0}') ?? 0) == 0 ? red : null)),
            ],
          ]));
        }
        break;
    }

    // Fallback if nothing was added
    if (pdf.document.pdfPageList.pages.isEmpty) {
      pdf.addPage(pw.Page(theme: theme, build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        header(),
        pw.SizedBox(height: 40),
        pw.Center(child: pw.Text('No data available for this report.', style: pw.TextStyle(fontSize: 14, color: grey))),
      ])));
    }

    return pdf.save();
  }

  static pw.Widget _pdfPnlRow(String label, String value, {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 11, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════
// SALES TAB
// ════════════════════════════════════════════════════
class _SalesTab extends StatelessWidget {
  final dynamic d;
  final ColorScheme cs;
  final bool isDark;
  const _SalesTab({required this.d, required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (d == null) return const EmptyState(icon: Icons.receipt_rounded, title: 'No sales data');
    final pos = d['pos'] ?? {};
    final disp = d['dispensing'] ?? {};
    final dailyPos = (d['daily_pos'] as List?) ?? [];
    final pmPos = (d['payment_mix_pos'] as List?) ?? [];
    final pmDisp = (d['payment_mix_dispensing'] as List?) ?? [];

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 80), children: [
        // KPI row
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.8,
          children: [
            _KPI(icon: Icons.receipt_rounded, color: const Color(0xFF6366F1), label: 'Transactions', value: _num(d['combined_count'])),
            _KPI(icon: Icons.payments_rounded, color: const Color(0xFF22C55E), label: 'Revenue', value: _ksh(d['combined_revenue'])),
            _KPI(icon: Icons.point_of_sale_rounded, color: const Color(0xFF14B8A6), label: 'POS Revenue', value: _ksh(pos['revenue'])),
            _KPI(icon: Icons.local_pharmacy_rounded, color: const Color(0xFF3B82F6), label: 'Dispensing', value: _ksh(disp['revenue'])),
          ],
        ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: 16),

        // Revenue trend chart
        if (dailyPos.isNotEmpty) ...[
          _ChartCard(
            title: 'Revenue Trend',
            icon: Icons.show_chart_rounded,
            iconColor: const Color(0xFF22C55E),
            child: SizedBox(height: 180, child: _buildLineChart(dailyPos, cs)),
          ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
          const SizedBox(height: 16),
        ],

        // Payment mix
        if (pmPos.isNotEmpty)
          _PaymentMixCard(title: 'POS Payment Mix', data: pmPos, color: const Color(0xFF22C55E), cs: cs).animate().fadeIn(delay: 200.ms, duration: 400.ms),
        if (pmDisp.isNotEmpty) ...[
          const SizedBox(height: 12),
          _PaymentMixCard(title: 'Dispensing Payment Mix', data: pmDisp, color: const Color(0xFF3B82F6), cs: cs).animate().fadeIn(delay: 250.ms, duration: 400.ms),
        ],
      ]),
    );
  }

  Widget _buildLineChart(List data, ColorScheme cs) {
    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), (double.tryParse('${e.value['revenue'] ?? 0}') ?? 0));
    }).toList();
    final labels = data.map((d) {
      try { return DateFormat('MMM d').format(DateTime.parse('${d['date']}')); } catch (_) { return ''; }
    }).toList();

    return LineChart(LineChartData(
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant.withValues(alpha: 0.15), strokeWidth: 1)),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, _) => Text(_kshCompact(v), style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)))),
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
      lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(
        getTooltipItems: (spots) => spots.map((s) => LineTooltipItem('${labels[s.x.toInt()]}\n${_ksh(s.y)}', const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11))).toList(),
      )),
    ));
  }
}

String _kshCompact(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
  return v.toInt().toString();
}

// ════════════════════════════════════════════════════
// TOP PRODUCTS TAB
// ════════════════════════════════════════════════════
class _TopProductsTab extends StatelessWidget {
  final dynamic d;
  final ColorScheme cs;
  const _TopProductsTab({required this.d, required this.cs});

  @override
  Widget build(BuildContext context) {
    if (d == null) return const EmptyState(icon: Icons.emoji_events_rounded, title: 'No data');
    final items = (d['items'] as List?) ?? [];
    if (items.isEmpty) return const EmptyState(icon: Icons.emoji_events_rounded, title: 'No sales in this period');

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 80), children: [
      _SectionHeader(icon: Icons.emoji_events_rounded, title: 'Top Selling Medications', count: items.length, color: const Color(0xFFF59E0B)),
      const SizedBox(height: 10),
      ...items.asMap().entries.map((e) {
        final i = e.key;
        final item = e.value;
        final rank = i + 1;
        final medal = rank <= 3;
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.12))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: medal ? [const Color(0xFFF59E0B), const Color(0xFF9CA3AF), const Color(0xFFCD7F32)][i].withValues(alpha: 0.15) : cs.surfaceContainerHighest,
                ),
                child: Center(child: Text('#$rank', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: medal ? [const Color(0xFFF59E0B), const Color(0xFF6B7280), const Color(0xFFCD7F32)][i] : cs.onSurfaceVariant))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${item['medication_name'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Wrap(spacing: 6, runSpacing: 2, children: [
                  _TinyChip('${_num(item['quantity'])} sold', const Color(0xFF6366F1)),
                  _TinyChip('${item['orders'] ?? 0} orders', const Color(0xFF3B82F6)),
                ]),
              ])),
              Text(_ksh(item['revenue']), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cs.primary)),
            ]),
          ),
        ).animate().fadeIn(delay: (50 * i).ms, duration: 300.ms);
      }),
    ]);
  }
}

// ════════════════════════════════════════════════════
// CASHIERS TAB
// ════════════════════════════════════════════════════
class _CashiersTab extends StatelessWidget {
  final dynamic d;
  final ColorScheme cs;
  const _CashiersTab({required this.d, required this.cs});

  @override
  Widget build(BuildContext context) {
    if (d == null) return const EmptyState(icon: Icons.badge_rounded, title: 'No data');
    final cashiers = (d['cashiers'] as List?) ?? [];
    if (cashiers.isEmpty) return const EmptyState(icon: Icons.badge_rounded, title: 'No cashier data');

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 80), children: [
      _SectionHeader(icon: Icons.badge_rounded, title: 'Cashier Performance', count: cashiers.length, color: const Color(0xFF8B5CF6)),
      const SizedBox(height: 10),
      ...cashiers.asMap().entries.map((e) {
        final i = e.key;
        final c = e.value;
        final name = '${c['name'] ?? 'Unknown'}';
        final initials = name.split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.12))),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                child: Text(initials, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _TinyChip('${c['transactions'] ?? 0} txns', const Color(0xFF6366F1)),
                  _TinyChip('Disc: ${_ksh(c['discount'])}', const Color(0xFFEF4444)),
                  _TinyChip('Avg: ${_ksh(c['avg_basket'])}', const Color(0xFF14B8A6)),
                ]),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_ksh(c['revenue']), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.primary)),
                Text('revenue', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
              ]),
            ]),
          ),
        ).animate().fadeIn(delay: (50 * i).ms, duration: 300.ms);
      }),
    ]);
  }
}

// ════════════════════════════════════════════════════
// PROFIT & LOSS TAB
// ════════════════════════════════════════════════════
class _PnlTab extends StatelessWidget {
  final dynamic d;
  final ColorScheme cs;
  const _PnlTab({required this.d, required this.cs});

  @override
  Widget build(BuildContext context) {
    if (d == null) return const EmptyState(icon: Icons.account_balance_rounded, title: 'No data');

    final netProfit = double.tryParse('${d['net_profit'] ?? 0}') ?? 0;
    final grossMargin = double.tryParse('${d['gross_margin_pct'] ?? 0}') ?? 0;
    final isPositive = netProfit >= 0;

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 80), children: [
      // KPIs
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.8,
        children: [
          _KPI(icon: Icons.payments_rounded, color: const Color(0xFF6366F1), label: 'Revenue', value: _ksh(d['revenue'])),
          _KPI(icon: Icons.shopping_cart_rounded, color: const Color(0xFFEF4444), label: 'COGS', value: _ksh(d['cogs'])),
          _KPI(icon: Icons.trending_up_rounded, color: const Color(0xFF22C55E), label: 'Gross Profit', value: _ksh(d['gross_profit'])),
          _KPI(icon: isPositive ? Icons.emoji_events_rounded : Icons.trending_down_rounded, color: isPositive ? const Color(0xFF22C55E) : const Color(0xFFEF4444), label: 'Net Profit', value: _ksh(netProfit)),
        ],
      ).animate().fadeIn(duration: 300.ms),
      const SizedBox(height: 16),

      // Income Statement Card
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15))),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.description_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              const Text('Income Statement', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 16),
            _PnlRow(label: 'POS Revenue', value: _ksh(d['pos_revenue']), cs: cs),
            _PnlRow(label: 'Dispensing Revenue', value: _ksh(d['dispensing_revenue']), cs: cs),
            Divider(color: cs.outlineVariant.withValues(alpha: 0.2), height: 16),
            _PnlRow(label: 'Total Revenue', value: _ksh(d['revenue']), cs: cs, bold: true),
            _PnlRow(label: 'Cost of Goods Sold', value: '(${_ksh(d['cogs'])})', cs: cs, negative: true),
            Divider(color: cs.outlineVariant.withValues(alpha: 0.2), height: 16),
            _PnlRow(label: 'Gross Profit', value: _ksh(d['gross_profit']), cs: cs, bold: true, positive: true),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: grossMargin >= 30 ? const Color(0xFF22C55E).withValues(alpha: 0.1) : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Margin: ${_pct(grossMargin)}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: grossMargin >= 30 ? const Color(0xFF22C55E) : const Color(0xFFF59E0B))),
              ),
            ),
            _PnlRow(label: 'Operating Expenses', value: '(${_ksh(d['expenses'])})', cs: cs, negative: true),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isPositive ? const Color(0xFF22C55E).withValues(alpha: 0.08) : const Color(0xFFEF4444).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Net Profit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                Text(_ksh(netProfit), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isPositive ? const Color(0xFF22C55E) : const Color(0xFFEF4444))),
              ]),
            ),
          ]),
        ),
      ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
    ]);
  }
}

class _PnlRow extends StatelessWidget {
  final String label, value;
  final ColorScheme cs;
  final bool bold, positive, negative;
  const _PnlRow({required this.label, required this.value, required this.cs, this.bold = false, this.positive = false, this.negative = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: cs.onSurface)),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        color: positive ? const Color(0xFF22C55E) : negative ? const Color(0xFFEF4444) : cs.onSurface)),
    ]),
  );
}

// ════════════════════════════════════════════════════
// INVENTORY TAB
// ════════════════════════════════════════════════════
class _InventoryTab extends StatelessWidget {
  final dynamic d;
  final ColorScheme cs;
  const _InventoryTab({required this.d, required this.cs});

  @override
  Widget build(BuildContext context) {
    if (d == null) return const EmptyState(icon: Icons.inventory_2_rounded, title: 'No data');
    final cats = (d['by_category'] as List?) ?? [];

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 80), children: [
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.8,
        children: [
          _KPI(icon: Icons.category_rounded, color: const Color(0xFF3B82F6), label: 'SKUs', value: _num(d['sku_count'])),
          _KPI(icon: Icons.layers_rounded, color: const Color(0xFF06B6D4), label: 'Units in Stock', value: _num(d['unit_count'])),
          _KPI(icon: Icons.payments_rounded, color: const Color(0xFFF59E0B), label: 'Cost Value', value: _ksh(d['cost_value'])),
          _KPI(icon: Icons.trending_up_rounded, color: const Color(0xFF22C55E), label: 'Potential Margin', value: _ksh(d['potential_margin'])),
        ],
      ).animate().fadeIn(duration: 300.ms),
      const SizedBox(height: 16),

      if (cats.isNotEmpty) ...[
        _SectionHeader(icon: Icons.category_rounded, title: 'By Category', count: cats.length, color: const Color(0xFF3B82F6)),
        const SizedBox(height: 10),
        ...cats.asMap().entries.map((e) {
          final i = e.key;
          final c = e.value;
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.1))),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${c['category'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text('${_num(c['units'])} units', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_ksh(c['sale']), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.primary)),
                  Text('Cost: ${_ksh(c['cost'])}', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                ]),
              ]),
            ),
          ).animate().fadeIn(delay: (30 * i).ms, duration: 250.ms);
        }),
      ],
    ]);
  }
}

// ════════════════════════════════════════════════════
// EXPIRY TAB
// ════════════════════════════════════════════════════
class _ExpiryTab extends StatelessWidget {
  final dynamic d;
  final ColorScheme cs;
  const _ExpiryTab({required this.d, required this.cs});

  @override
  Widget build(BuildContext context) {
    if (d == null) return const EmptyState(icon: Icons.schedule_rounded, title: 'No data');
    final batches = (d['batches'] as List?) ?? [];

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 80), children: [
      // Warning banner
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 20),
          const SizedBox(width: 10),
          Expanded(child: RichText(text: TextSpan(style: TextStyle(fontSize: 12, color: cs.onSurface), children: [
            TextSpan(text: '${d['count'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: ' batches expiring within '),
            TextSpan(text: '${d['days_horizon'] ?? 90}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const TextSpan(text: ' days'),
          ]))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('Loss: ${_ksh(d['expired_loss_value'])}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
          ),
        ]),
      ).animate().fadeIn(duration: 300.ms),
      const SizedBox(height: 12),

      ...batches.asMap().entries.map((e) {
        final i = e.key;
        final b = e.value;
        final daysLeft = int.tryParse('${b['days_left'] ?? 0}') ?? 0;
        final expired = daysLeft < 0;
        final urgent = daysLeft < 30 && !expired;
        final color = expired ? const Color(0xFFEF4444) : urgent ? const Color(0xFFF59E0B) : const Color(0xFFF59E0B);

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.1))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${b['medication_name'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Wrap(spacing: 6, runSpacing: 2, children: [
                  _TinyChip('Batch: ${b['batch_number'] ?? '—'}', Colors.grey),
                  _TinyChip('Qty: ${b['quantity_remaining'] ?? 0}', const Color(0xFF3B82F6)),
                  _TinyChip('${b['expiry_date'] ?? ''}', Colors.grey),
                ]),
              ])),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(expired ? 'EXPIRED' : '${daysLeft}d', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                ),
                const SizedBox(height: 4),
                Text(_ksh(b['cost_value']), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
              ]),
            ]),
          ),
        ).animate().fadeIn(delay: (20 * i).ms, duration: 250.ms);
      }),

      if (batches.isEmpty)
        const EmptyState(icon: Icons.check_circle_rounded, title: 'No expiring stock', subtitle: 'All batches are well within shelf life.'),
    ]);
  }
}

// ════════════════════════════════════════════════════
// LOW STOCK TAB
// ════════════════════════════════════════════════════
class _LowStockTab extends StatelessWidget {
  final dynamic d;
  final ColorScheme cs;
  const _LowStockTab({required this.d, required this.cs});

  @override
  Widget build(BuildContext context) {
    if (d == null) return const EmptyState(icon: Icons.warning_rounded, title: 'No data');
    final items = (d['items'] as List?) ?? [];

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 80), children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          const Icon(Icons.info_rounded, color: Color(0xFF3B82F6), size: 20),
          const SizedBox(width: 10),
          Expanded(child: RichText(text: TextSpan(style: TextStyle(fontSize: 12, color: cs.onSurface), children: [
            TextSpan(text: '${d['count'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const TextSpan(text: ' items below reorder level'),
          ]))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('Reorder: ${_ksh(d['estimated_reorder_value'])}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
          ),
        ]),
      ).animate().fadeIn(duration: 300.ms),
      const SizedBox(height: 12),

      ...items.asMap().entries.map((e) {
        final i = e.key;
        final it = e.value;
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.1))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${it['medication_name'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Wrap(spacing: 6, runSpacing: 2, children: [
                  if ((it['category'] ?? '').toString().isNotEmpty) _TinyChip('${it['category']}', Colors.grey),
                  _TinyChip('Reorder Lv: ${it['reorder_level'] ?? 0}', const Color(0xFFF59E0B)),
                  _TinyChip('Reorder Qty: ${it['reorder_quantity'] ?? 0}', const Color(0xFF6366F1)),
                ]),
              ])),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text('${it['quantity'] ?? 0}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                ),
                const SizedBox(height: 4),
                Text(_ksh(it['estimated_reorder_cost']), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
              ]),
            ]),
          ),
        ).animate().fadeIn(delay: (20 * i).ms, duration: 250.ms);
      }),

      if (items.isEmpty)
        const EmptyState(icon: Icons.check_circle_rounded, title: 'Stock levels healthy', subtitle: 'All items are above reorder level.'),
    ]);
  }
}

// ════════════════════════════════════════════════════
// SHARED WIDGETS
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

class _ChartCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  const _ChartCard({required this.title, required this.icon, required this.iconColor, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          child,
        ]),
      ),
    );
  }
}

class _PaymentMixCard extends StatelessWidget {
  final String title;
  final List data;
  final Color color;
  final ColorScheme cs;
  const _PaymentMixCard({required this.title, required this.data, required this.color, required this.cs});

  @override
  Widget build(BuildContext context) {
    final total = data.fold<double>(0, (s, r) => s + (double.tryParse('${r['revenue'] ?? 0}') ?? 0));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.pie_chart_rounded, size: 18, color: color),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          ...data.map((r) {
            final rev = double.tryParse('${r['revenue'] ?? 0}') ?? 0;
            final pct = total > 0 ? rev / total : 0.0;
            final method = '${r['payment_method'] ?? 'Other'}';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
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
                  SizedBox(width: 64, child: Text('${(pct * 100).toStringAsFixed(1)}% · ${r['count'] ?? 0}', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant), textAlign: TextAlign.right)),
                ]),
              ]),
            );
          }),
        ]),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final Color color;
  const _SectionHeader({required this.icon, required this.title, required this.count, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: color),
    const SizedBox(width: 8),
    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    const SizedBox(width: 8),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    ),
  ]);
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
