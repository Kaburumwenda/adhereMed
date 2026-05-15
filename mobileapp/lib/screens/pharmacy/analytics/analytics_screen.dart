import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/api.dart';
import '../../../widgets/common.dart';

// ── helpers ──
double _dbl(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
final _fmt = NumberFormat.compactCurrency(symbol: 'KSH ', decimalDigits: 0);
final _fmtFull = NumberFormat('#,##0', 'en');

const _barColors = [
  Color(0xFF3B82F6), Color(0xFF22C55E), Color(0xFFF59E0B), Color(0xFFEC4899),
  Color(0xFF8B5CF6), Color(0xFF06B6D4), Color(0xFFEF4444), Color(0xFF14B8A6),
  Color(0xFFF97316), Color(0xFF6366F1),
];

// ── Range options ──
enum _RangeKey {
  today, yesterday, last7, last30, last90,
  thisMonth, lastMonth, thisYear, lastYear, custom,
}

String _rangeLabel(_RangeKey k) {
  switch (k) {
    case _RangeKey.today: return 'Today';
    case _RangeKey.yesterday: return 'Yesterday';
    case _RangeKey.last7: return 'Last 7 days';
    case _RangeKey.last30: return 'Last 30 days';
    case _RangeKey.last90: return 'Last 90 days';
    case _RangeKey.thisMonth: return 'This month';
    case _RangeKey.lastMonth: return 'Last month';
    case _RangeKey.thisYear: return 'This year';
    case _RangeKey.lastYear: return 'Last year';
    case _RangeKey.custom: return 'Custom range';
  }
}

({DateTime start, DateTime end}) _resolveRange(_RangeKey key, {DateTime? customStart, DateTime? customEnd}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  switch (key) {
    case _RangeKey.today: return (start: today, end: tomorrow);
    case _RangeKey.yesterday:
      final y = today.subtract(const Duration(days: 1));
      return (start: y, end: today);
    case _RangeKey.last7: return (start: today.subtract(const Duration(days: 6)), end: tomorrow);
    case _RangeKey.last30: return (start: today.subtract(const Duration(days: 29)), end: tomorrow);
    case _RangeKey.last90: return (start: today.subtract(const Duration(days: 89)), end: tomorrow);
    case _RangeKey.thisMonth: return (start: DateTime(now.year, now.month, 1), end: tomorrow);
    case _RangeKey.lastMonth:
      final s = DateTime(now.year, now.month - 1, 1);
      return (start: s, end: DateTime(now.year, now.month, 1));
    case _RangeKey.thisYear: return (start: DateTime(now.year, 1, 1), end: tomorrow);
    case _RangeKey.lastYear:
      return (start: DateTime(now.year - 1, 1, 1), end: DateTime(now.year, 1, 1));
    case _RangeKey.custom:
      if (customStart != null && customEnd != null) {
        return (start: customStart, end: customEnd.add(const Duration(days: 1)));
      }
      return (start: today.subtract(const Duration(days: 29)), end: tomorrow);
  }
}

// ── Raw data provider ──
final _rawDataProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final results = await Future.wait([
    dio.get('/pos/transactions/', queryParameters: {'page_size': 1000}),
    dio.get('/inventory/stocks/', queryParameters: {'page_size': 500}),
  ]);
  final txRaw = results[0].data;
  final stRaw = results[1].data;
  return {
    'transactions': (txRaw is List) ? txRaw : (txRaw?['results'] as List?) ?? [],
    'stocks': (stRaw is List) ? stRaw : (stRaw?['results'] as List?) ?? [],
  };
});

// ── Screen ──
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> with TickerProviderStateMixin {
  late TabController _tabCtrl;
  _RangeKey _rangeKey = _RangeKey.last30;
  DateTime? _customStart;
  DateTime? _customEnd;
  String _topMetric = 'revenue';

  List _txAll = [];
  List _stocks = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  List get _inRange {
    final r = _resolveRange(_rangeKey, customStart: _customStart, customEnd: _customEnd);
    return _txAll.where((t) {
      final d = DateTime.tryParse((t['created_at'] ?? t['date'] ?? '').toString());
      if (d == null) return false;
      return !d.isBefore(r.start) && d.isBefore(r.end);
    }).toList();
  }

  List get _inPrevRange {
    final r = _resolveRange(_rangeKey, customStart: _customStart, customEnd: _customEnd);
    final days = r.end.difference(r.start).inDays;
    final prevStart = r.start.subtract(Duration(days: days));
    return _txAll.where((t) {
      final d = DateTime.tryParse((t['created_at'] ?? t['date'] ?? '').toString());
      if (d == null) return false;
      return !d.isBefore(prevStart) && d.isBefore(r.start);
    }).toList();
  }

  double _revenue(List txns) => txns.fold<double>(0, (s, t) => s + _dbl(t['total'] ?? t['total_amount']));
  int? _delta(double current, double previous) =>
      previous > 0 ? ((current - previous) / previous * 100).round() : null;

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _customStart != null && _customEnd != null
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _customStart = picked.start;
        _customEnd = picked.end;
        _rangeKey = _RangeKey.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(_rawDataProvider);
    final cs = Theme.of(context).colorScheme;

    return data.when(
      loading: () => const LoadingShimmer(),
      error: (e, _) => ErrorRetry(message: 'Failed to load analytics', onRetry: () => ref.invalidate(_rawDataProvider)),
      data: (d) {
        _txAll = d['transactions'] as List;
        _stocks = d['stocks'] as List;
        final filtered = _inRange;
        final prevFiltered = _inPrevRange;
        final r = _resolveRange(_rangeKey, customStart: _customStart, customEnd: _customEnd);
        final rangeDays = r.end.difference(r.start).inDays;

        return Column(children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
            child: Row(children: [
              Text('Analytics', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
              // Range dropdown
              Expanded(
                child: DropdownButtonFormField<_RangeKey>(
                  initialValue: _rangeKey,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.outlineVariant)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4))),
                    prefixIcon: const Icon(Icons.calendar_today_rounded, size: 16),
                    prefixIconConstraints: const BoxConstraints(minWidth: 32),
                  ),
                  style: TextStyle(fontSize: 12, color: cs.onSurface),
                  icon: const Icon(Icons.expand_more_rounded, size: 18),
                  isExpanded: true,
                  items: _RangeKey.values.map((k) => DropdownMenuItem(value: k, child: Text(_rangeLabel(k), style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) {
                    if (v == _RangeKey.custom) {
                      _pickCustomRange();
                    } else if (v != null) {
                      setState(() => _rangeKey = v);
                    }
                  },
                ),
              ),
              IconButton(icon: const Icon(Icons.refresh_rounded, size: 20), onPressed: () => ref.invalidate(_rawDataProvider)),
            ]),
          ),

          // ── Tab Bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(3),
              child: TabBar(
                controller: _tabCtrl,
                indicator: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: cs.primary,
                unselectedLabelColor: cs.onSurfaceVariant,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                splashBorderRadius: BorderRadius.circular(10),
                tabs: const [
                  Tab(height: 36, text: 'Overview'),
                  Tab(height: 36, text: 'Products'),
                  Tab(height: 36, text: 'Categories'),
                ],
              ),
            ),
          ),

          // ── Tab Views ──
          Expanded(child: TabBarView(
            controller: _tabCtrl,
            children: [
              // ── TAB 0: Overview ──
              RefreshIndicator(
                onRefresh: () async => ref.invalidate(_rawDataProvider),
                child: _buildOverview(context, cs, filtered, prevFiltered, rangeDays),
              ),
              // ── TAB 1: Products ──
              _ProductsTab(filtered: filtered, stocks: _stocks, rangeDays: rangeDays, txAll: _txAll),
              // ── TAB 2: Categories ──
              _CategoriesTab(filtered: filtered, stocks: _stocks, rangeDays: rangeDays, txAll: _txAll),
            ],
          )),
        ]);
      },
    );
  }

  Widget _buildOverview(BuildContext context, ColorScheme cs, List filtered, List prevFiltered, int rangeDays) {
    final totalRevenue = _revenue(filtered);
    final prevRevenue = _revenue(prevFiltered);
    final totalOrders = filtered.length;
    final prevOrders = prevFiltered.length;
    final aov = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;
    final uniqueCustomers = filtered
        .map((t) => (t['customer_name'] ?? '').toString().trim().toLowerCase())
        .where((n) => n.isNotEmpty && n != 'walk-in')
        .toSet().length;

    final r = _resolveRange(_rangeKey, customStart: _customStart, customEnd: _customEnd);
    final Map<String, double> dayRevenue = {};
    final Map<String, int> dayOrders = {};
    for (final t in filtered) {
      final ds = (t['created_at'] ?? t['date'] ?? '').toString();
      if (ds.length < 10) continue;
      final key = ds.substring(0, 10);
      dayRevenue[key] = (dayRevenue[key] ?? 0) + _dbl(t['total'] ?? t['total_amount']);
      dayOrders[key] = (dayOrders[key] ?? 0) + 1;
    }
    final allDates = <String>[];
    for (int i = 0; i < rangeDays; i++) {
      allDates.add(DateFormat('yyyy-MM-dd').format(r.start.add(Duration(days: i))));
    }

    final Map<String, int> paymentCounts = {};
    for (final t in filtered) {
      final m = (t['payment_method'] ?? 'other').toString().toLowerCase();
      paymentCounts[m] = (paymentCounts[m] ?? 0) + 1;
    }
    final paymentEntries = paymentCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final paymentTotal = totalOrders > 0 ? totalOrders : 1;

    final hourCounts = List<int>.filled(24, 0);
    for (final t in filtered) {
      final d = DateTime.tryParse((t['created_at'] ?? '').toString());
      if (d != null) hourCounts[d.hour]++;
    }
    final maxHour = hourCounts.reduce((a, b) => a > b ? a : b);

    final Map<String, Map<String, dynamic>> productMap = {};
    for (final t in filtered) {
      for (final it in ((t['items'] as List?) ?? [])) {
        final name = (it['product_name'] ?? it['name'] ?? it['medication_name'] ?? 'Item').toString();
        final qty = (it['quantity'] ?? 1) as num;
        final rev = _dbl(it['total'] ?? it['subtotal'] ?? (_dbl(it['unit_price']) * qty.toDouble()));
        final cat = (it['category_name'] ?? it['category'] ?? 'Other').toString();
        final cur = productMap[name] ?? {'name': name, 'qty': 0.0, 'revenue': 0.0, 'category': cat};
        cur['qty'] = (cur['qty'] as double) + qty.toDouble();
        cur['revenue'] = (cur['revenue'] as double) + rev;
        productMap[name] = cur;
      }
    }
    final topProducts = productMap.values.toList()
      ..sort((a, b) => _topMetric == 'qty'
          ? (b['qty'] as double).compareTo(a['qty'] as double)
          : (b['revenue'] as double).compareTo(a['revenue'] as double));
    final topSlice = topProducts.take(10).toList();
    final topMax = topSlice.isNotEmpty
        ? (_topMetric == 'qty' ? topSlice[0]['qty'] as double : topSlice[0]['revenue'] as double)
        : 1.0;

    final Map<String, double> categoryMap = {};
    for (final t in filtered) {
      for (final it in ((t['items'] as List?) ?? [])) {
        final cat = (it['category_name'] ?? it['category'] ?? 'Other').toString();
        final rev = _dbl(it['total'] ?? it['subtotal'] ?? (_dbl(it['unit_price']) * _dbl(it['quantity'] ?? 1)));
        categoryMap[cat] = (categoryMap[cat] ?? 0) + rev;
      }
    }
    final categoryEntries = categoryMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final categorySlice = categoryEntries.take(8).toList();
    final categoryTotal = categorySlice.fold<double>(0, (s, e) => s + e.value);

    final inventoryValue = _stocks.fold<double>(0, (s, x) => s + _dbl(x['cost_price']) * _dbl(x['total_quantity'] ?? x['quantity']));
    final inventorySellValue = _stocks.fold<double>(0, (s, x) => s + _dbl(x['selling_price']) * _dbl(x['total_quantity'] ?? x['quantity']));
    final totalUnits = _stocks.fold<int>(0, (s, x) => s + _dbl(x['total_quantity'] ?? x['quantity']).toInt());
    final lowStock = _stocks.where((s) {
      final q = _dbl(s['total_quantity'] ?? s['quantity']);
      final rl = _dbl(s['reorder_level']);
      return q <= 0 || (rl > 0 && q <= rl);
    }).toList()..sort((a, b) => _dbl(a['total_quantity'] ?? a['quantity']).compareTo(_dbl(b['total_quantity'] ?? b['quantity'])));
    final now = DateTime.now();
    final soon = now.add(const Duration(days: 60));
    final expiring = _stocks.where((s) {
      final exp = DateTime.tryParse((s['expiry_date'] ?? '').toString());
      return exp != null && exp.isBefore(soon);
    }).toList()..sort((a, b) {
      final ea = DateTime.tryParse((a['expiry_date'] ?? '').toString()) ?? now;
      final eb = DateTime.tryParse((b['expiry_date'] ?? '').toString()) ?? now;
      return ea.compareTo(eb);
    });

    final Map<String, Map<String, dynamic>> custMap = {};
    for (final t in filtered) {
      final name = (t['customer_name'] ?? '').toString().trim();
      if (name.isEmpty || name.toLowerCase() == 'walk-in') continue;
      final cur = custMap[name] ?? {'name': name, 'orders': 0, 'spent': 0.0};
      cur['orders'] = (cur['orders'] as int) + 1;
      cur['spent'] = (cur['spent'] as double) + _dbl(t['total'] ?? t['total_amount']);
      custMap[name] = cur;
    }
    final topCustomers = custMap.values.toList()..sort((a, b) => (b['spent'] as double).compareTo(a['spent'] as double));

    final Map<String, Map<String, dynamic>> cashierMap = {};
    for (final t in filtered) {
      final name = (t['cashier_name'] ?? t['created_by_name'] ?? t['user_name'] ?? 'Unknown').toString();
      final cur = cashierMap[name] ?? {'name': name, 'count': 0, 'revenue': 0.0};
      cur['count'] = (cur['count'] as int) + 1;
      cur['revenue'] = (cur['revenue'] as double) + _dbl(t['total'] ?? t['total_amount']);
      cashierMap[name] = cur;
    }
    final cashierStats = cashierMap.values.toList()..sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.45,
          children: [
            _KpiChip(icon: Icons.payments_rounded, color: cs.primary, title: 'Revenue', value: _fmt.format(totalRevenue), delta: _delta(totalRevenue, prevRevenue), hint: 'vs prior ${rangeDays}d'),
            _KpiChip(icon: Icons.receipt_long_rounded, color: const Color(0xFF3B82F6), title: 'Transactions', value: '$totalOrders', delta: _delta(totalOrders.toDouble(), prevOrders.toDouble())),
            _KpiChip(icon: Icons.trending_up_rounded, color: const Color(0xFF22C55E), title: 'Avg. Order', value: _fmt.format(aov)),
            _KpiChip(icon: Icons.people_rounded, color: const Color(0xFF8B5CF6), title: 'Unique Customers', value: '$uniqueCustomers'),
          ],
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 20),
        const _SectionLabel('Revenue trend'),
        const SizedBox(height: 4),
        Text('Daily revenue · ${_rangeLabel(_rangeKey)}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        _RevenueTrendChart(dates: allDates, dayRevenue: dayRevenue),
        const SizedBox(height: 20),
        const _SectionLabel('Payment methods'),
        const SizedBox(height: 8),
        _PaymentMixCard(entries: paymentEntries, total: paymentTotal, totalOrders: totalOrders),
        const SizedBox(height: 20),
        const _SectionLabel('Orders per day'),
        const SizedBox(height: 4),
        Text('Volume of transactions over time', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        _OrdersBarChart(dates: allDates, dayOrders: dayOrders),
        const SizedBox(height: 20),
        const _SectionLabel('Hour of day · sales heatmap'),
        const SizedBox(height: 4),
        Text('When customers buy most', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        _HourHeatmap(counts: hourCounts, maxVal: maxHour),
        const SizedBox(height: 20),
        Row(children: [
          const Expanded(child: _SectionLabel('Top selling products')),
          ToggleButtons(
            isSelected: [_topMetric == 'revenue', _topMetric == 'qty'],
            onPressed: (i) => setState(() => _topMetric = i == 0 ? 'revenue' : 'qty'),
            borderRadius: BorderRadius.circular(8),
            constraints: const BoxConstraints(minHeight: 30, minWidth: 64),
            textStyle: const TextStyle(fontSize: 11),
            children: const [Text('Revenue'), Text('Qty')],
          ),
        ]),
        const SizedBox(height: 8),
        _TopProductsTable(products: topSlice, maxVal: topMax, metric: _topMetric),
        const SizedBox(height: 20),
        const _SectionLabel('Sales by category'),
        const SizedBox(height: 8),
        _CategoryDonut(categories: categorySlice, total: categoryTotal),
        const SizedBox(height: 20),
        const _SectionLabel('Inventory'),
        const SizedBox(height: 8),
        _InventoryValueCard(costValue: inventoryValue, sellValue: inventorySellValue, units: totalUnits, skus: _stocks.length),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _AlertListCard(title: 'Low stock', count: lowStock.length, chipColor: Colors.orange, items: lowStock.take(6).toList(), nameKey: 'medication_name', valueBuilder: (s) => '${_dbl(s['total_quantity'] ?? s['quantity']).toInt()} left')),
          const SizedBox(width: 8),
          Expanded(child: _AlertListCard(title: 'Expiring', count: expiring.length, chipColor: Colors.red, items: expiring.take(6).toList(), nameKey: 'medication_name', valueBuilder: (s) {
            final exp = DateTime.tryParse((s['expiry_date'] ?? '').toString());
            if (exp == null) return '';
            return '${exp.difference(now).inDays}d';
          })),
        ]),
        const SizedBox(height: 20),
        const _SectionLabel('Top customers'),
        const SizedBox(height: 8),
        if (topCustomers.isEmpty)
          _emptyCard('No repeat customers yet')
        else
          ...topCustomers.take(6).map((c) => Card(
            elevation: 0, margin: const EdgeInsets.only(bottom: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
            child: ListTile(
              dense: true,
              leading: CircleAvatar(radius: 18, backgroundColor: cs.primaryContainer, child: Text(_initials(c['name'] as String), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary))),
              title: Text(c['name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text('${c['orders']} order${(c['orders'] as int) > 1 ? 's' : ''}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              trailing: Text(_fmt.format(c['spent']), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.primary)),
            ),
          )),
        const SizedBox(height: 20),
        const _SectionLabel('Cashier performance'),
        const SizedBox(height: 8),
        if (cashierStats.isEmpty)
          _emptyCard('No cashier data')
        else
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Row(children: [
                  const Expanded(flex: 3, child: Text('Cashier', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                  const Expanded(flex: 1, child: Text('Sales', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                  const Expanded(flex: 2, child: Text('Revenue', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                  const Expanded(flex: 2, child: Text('AOV', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                ]),
                const Divider(height: 14),
                ...cashierStats.take(8).map((c) {
                  final cashierAov = (c['count'] as int) > 0 ? (c['revenue'] as double) / (c['count'] as int) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(flex: 3, child: Text(c['name'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Expanded(flex: 1, child: Text('${c['count']}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text(_fmt.format(c['revenue']), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text(_fmt.format(cashierAov), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant), textAlign: TextAlign.right)),
                    ]),
                  );
                }),
              ]),
            ),
          ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 100),
      ],
    );
  }

  String _initials(String name) =>
      name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).map((p) => p[0]).take(2).join().toUpperCase();

  Widget _emptyCard(String msg) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(msg, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)))),
  );
}

// ══════════════════════════════════════════
// Section Label
// ══════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800));
}

// ══════════════════════════════════════════
// KPI Chip
// ══════════════════════════════════════════
class _KpiChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final int? delta;
  final String? hint;
  const _KpiChip({required this.icon, required this.color, required this.title, required this.value, this.delta, this.hint});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: color),
            ),
            const Spacer(),
            if (delta != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (delta! >= 0 ? const Color(0xFF22C55E) : Colors.red).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(delta! >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      size: 12, color: delta! >= 0 ? const Color(0xFF22C55E) : Colors.red),
                  Text('${delta!.abs()}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: delta! >= 0 ? const Color(0xFF22C55E) : Colors.red)),
                ]),
              ),
          ]),
          const Spacer(),
          Text(title, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: cs.onSurface)),
          if (hint != null) Text(hint!, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════
// Revenue Trend (Area chart, scrollable)
// ══════════════════════════════════════════
class _RevenueTrendChart extends StatelessWidget {
  final List<String> dates;
  final Map<String, double> dayRevenue;
  const _RevenueTrendChart({required this.dates, required this.dayRevenue});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (dates.isEmpty) return _emptyChartCard(cs);

    final spots = <FlSpot>[];
    for (int i = 0; i < dates.length; i++) {
      spots.add(FlSpot(i.toDouble(), dayRevenue[dates[i]] ?? 0));
    }
    double maxY = spots.fold<double>(0, (m, s) => s.y > m ? s.y : m);
    if (maxY == 0) maxY = 100;
    final interval = (maxY / 4).ceilToDouble().clamp(1.0, double.infinity);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
        child: LayoutBuilder(builder: (ctx, box) {
          const double minSpacing = 28;
          final chartWidth = dates.length > 15
              ? (dates.length * minSpacing).clamp(box.maxWidth, double.infinity)
              : box.maxWidth;

          final chart = SizedBox(
            width: chartWidth,
            height: 200,
            child: LineChart(LineChartData(
              maxY: maxY * 1.15,
              gridData: FlGridData(
                show: true, drawVerticalLine: false, horizontalInterval: interval,
                getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant.withValues(alpha: 0.15), strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true, reservedSize: 50, interval: interval,
                  getTitlesWidget: (v, _) => Text(NumberFormat.compact().format(v), style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                )),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true, reservedSize: 28, interval: 1,
                  getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= dates.length) return const SizedBox();
                    if (dates.length > 14 && idx % (dates.length ~/ 7) != 0 && idx != dates.length - 1) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(DateFormat('dd/MM').format(DateTime.parse(dates[idx])), style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                    );
                  },
                )),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => cs.surface,
                  getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                    'KSH ${NumberFormat.compact().format(s.y)}',
                    TextStyle(color: const Color(0xFF3B82F6), fontWeight: FontWeight.w600, fontSize: 12),
                  )).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots, isCurved: true, preventCurveOverShooting: true,
                  color: const Color(0xFF3B82F6), barWidth: 2.5, isStrokeCapRound: true,
                  belowBarData: BarAreaData(show: true, gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [const Color(0xFF3B82F6).withValues(alpha: 0.2), const Color(0xFF3B82F6).withValues(alpha: 0.0)],
                  )),
                  dotData: FlDotData(show: dates.length <= 14),
                ),
              ],
            )),
          );

          if (chartWidth > box.maxWidth) {
            return SizedBox(height: 220, child: SingleChildScrollView(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), child: chart));
          }
          return chart;
        }),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _emptyChartCard(ColorScheme cs) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: const SizedBox(height: 100, child: Center(child: Text('No revenue data'))),
  );
}

// ══════════════════════════════════════════
// Payment Mix (Donut + legend)
// ══════════════════════════════════════════
class _PaymentMixCard extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  final int total;
  final int totalOrders;
  const _PaymentMixCard({required this.entries, required this.total, required this.totalOrders});

  static const _palette = <String, Color>{
    'cash': Color(0xFF22C55E),
    'mpesa': Color(0xFF16A34A),
    'card': Color(0xFF3B82F6),
    'insurance': Color(0xFF8B5CF6),
    'bank_transfer': Color(0xFF06B6D4),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (entries.isEmpty) return _emptyCard(cs);

    final sections = entries.map((e) {
      final pct = (e.value / total * 100).roundToDouble();
      return PieChartSectionData(
        value: pct,
        color: _palette[e.key] ?? const Color(0xFF94A3B8),
        radius: 28,
        title: '',
      );
    }).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          SizedBox(
            height: 160,
            child: Stack(alignment: Alignment.center, children: [
              PieChart(PieChartData(
                sections: sections,
                centerSpaceRadius: 44,
                sectionsSpace: 2,
                startDegreeOffset: -90,
              )),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Transactions', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                Text('$totalOrders', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: cs.onSurface)),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          ...entries.map((e) {
            final pct = (e.value / total * 100).round();
            final color = _palette[e.key] ?? const Color(0xFF94A3B8);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 8),
                Expanded(child: Text(_label(e.key), style: const TextStyle(fontSize: 13))),
                Text('${e.value}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                SizedBox(width: 36, child: Text('$pct%', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), textAlign: TextAlign.right)),
              ]),
            );
          }),
        ]),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  String _label(String k) {
    switch (k) {
      case 'cash': return 'Cash';
      case 'mpesa': return 'M-Pesa';
      case 'card': return 'Card';
      case 'insurance': return 'Insurance';
      case 'bank_transfer': return 'Bank Transfer';
      default: return k.isNotEmpty ? k[0].toUpperCase() + k.substring(1) : k;
    }
  }

  Widget _emptyCard(ColorScheme cs) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No payment data'))),
  );
}

// ══════════════════════════════════════════
// Orders Bar Chart
// ══════════════════════════════════════════
class _OrdersBarChart extends StatelessWidget {
  final List<String> dates;
  final Map<String, int> dayOrders;
  const _OrdersBarChart({required this.dates, required this.dayOrders});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (dates.isEmpty) return const SizedBox();

    final bars = <BarChartGroupData>[];
    double maxY = 0;
    for (int i = 0; i < dates.length; i++) {
      final v = (dayOrders[dates[i]] ?? 0).toDouble();
      if (v > maxY) maxY = v;
      bars.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(toY: v, width: dates.length > 30 ? 4 : 10, color: const Color(0xFF22C55E),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(3), topRight: Radius.circular(3))),
      ]));
    }
    if (maxY == 0) maxY = 5;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
        child: LayoutBuilder(builder: (ctx, box) {
          const double minSpacing = 20;
          final chartWidth = dates.length > 15
              ? (dates.length * minSpacing).clamp(box.maxWidth, double.infinity)
              : box.maxWidth;

          final chart = SizedBox(
            width: chartWidth,
            height: 180,
            child: BarChart(BarChartData(
              maxY: maxY * 1.2,
              barGroups: bars,
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant.withValues(alpha: 0.15), strokeWidth: 1)),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)))),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true, reservedSize: 28, interval: 1,
                  getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= dates.length) return const SizedBox();
                    if (dates.length > 14 && idx % (dates.length ~/ 7) != 0 && idx != dates.length - 1) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Transform.rotate(angle: -0.5, child: Text(DateFormat('dd/MM').format(DateTime.parse(dates[idx])), style: TextStyle(fontSize: 8, color: cs.onSurfaceVariant))),
                    );
                  },
                )),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => cs.surface,
                  getTooltipItem: (group, _, rod, __) => BarTooltipItem('${rod.toY.toInt()} orders', TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ),
            )),
          );

          if (chartWidth > box.maxWidth) {
            return SizedBox(height: 200, child: SingleChildScrollView(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), child: chart));
          }
          return chart;
        }),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ══════════════════════════════════════════
// Hour Heatmap
// ══════════════════════════════════════════
class _HourHeatmap extends StatelessWidget {
  final List<int> counts;
  final int maxVal;
  const _HourHeatmap({required this.counts, required this.maxVal});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final peak = maxVal > 0 ? maxVal : 1;

    // Group into periods
    final periods = <(String, int, int)>[
      ('Morning', 6, 12),
      ('Afternoon', 12, 17),
      ('Evening', 17, 21),
      ('Night', 21, 24),
      ('Late Night', 0, 6),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Full 24h bar row
          SizedBox(
            height: 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(24, (h) {
                final intensity = counts[h] / peak;
                return Expanded(child: Tooltip(
                  message: '${h.toString().padLeft(2, '0')}:00 - ${counts[h]} sales',
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    height: 10 + (intensity * 46),
                    decoration: BoxDecoration(
                      color: Color.lerp(cs.outlineVariant.withValues(alpha: 0.2), const Color(0xFF3B82F6), intensity),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                  ),
                ));
              }),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('00', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
              Text('06', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
              Text('12', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
              Text('18', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
              Text('23', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),
          // Period summaries
          Wrap(
            spacing: 8, runSpacing: 6,
            children: periods.map((p) {
              final total = List.generate(p.$3 - p.$2, (i) => counts[p.$2 + i]).fold<int>(0, (s, v) => s + v);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
                child: Text('${p.$1}: $total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // Legend ramp
          Row(children: [
            Text('Less', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
            const SizedBox(width: 4),
            ...List.generate(5, (i) => Container(
              width: 14, height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: Color.lerp(cs.outlineVariant.withValues(alpha: 0.2), const Color(0xFF3B82F6), i / 4),
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            const SizedBox(width: 4),
            Text('More', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
          ]),
        ]),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ══════════════════════════════════════════
// Top Products Table
// ══════════════════════════════════════════
class _TopProductsTable extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final double maxVal;
  final String metric;
  const _TopProductsTable({required this.products, required this.maxVal, required this.metric});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (products.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No sales yet'))),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          // Header
          Row(children: [
            const SizedBox(width: 24),
            const Expanded(flex: 4, child: Text('Product', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
            const Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
            const Expanded(flex: 2, child: Text('Revenue', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
          ]),
          const Divider(height: 14),
          ...products.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            final val = metric == 'qty' ? p['qty'] as double : p['revenue'] as double;
            final pct = maxVal > 0 ? (val / maxVal * 100) : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(children: [
                Row(children: [
                  SizedBox(width: 24, child: Text('${i + 1}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))),
                  Expanded(flex: 4, child: Text(p['name'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Expanded(flex: 1, child: Text('${(p['qty'] as double).toInt()}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant), textAlign: TextAlign.right)),
                  Expanded(flex: 2, child: Text(_fmt.format(p['revenue']), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 5,
                    backgroundColor: cs.outlineVariant.withValues(alpha: 0.15),
                    color: _barColors[i % _barColors.length],
                  ),
                ),
              ]),
            );
          }),
        ]),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ══════════════════════════════════════════
// Category Donut
// ══════════════════════════════════════════
class _CategoryDonut extends StatelessWidget {
  final List<MapEntry<String, double>> categories;
  final double total;
  const _CategoryDonut({required this.categories, required this.total});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (categories.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No category data'))),
      );
    }

    final sections = categories.asMap().entries.map((e) {
      final pct = total > 0 ? (e.value.value / total * 100) : 0.0;
      return PieChartSectionData(
        value: pct,
        color: _barColors[e.key % _barColors.length],
        radius: 28,
        title: '',
      );
    }).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          SizedBox(
            height: 170,
            child: Stack(alignment: Alignment.center, children: [
              PieChart(PieChartData(
                sections: sections,
                centerSpaceRadius: 44,
                sectionsSpace: 2,
                startDegreeOffset: -90,
              )),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Total', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                Text(_fmt.format(total), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: cs.onSurface)),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          ...categories.asMap().entries.map((e) {
            final color = _barColors[e.key % _barColors.length];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 8),
                Expanded(child: Text(e.value.key, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text(_fmt.format(e.value.value), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            );
          }),
        ]),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ══════════════════════════════════════════
// Inventory Value Card
// ══════════════════════════════════════════
class _InventoryValueCard extends StatelessWidget {
  final double costValue;
  final double sellValue;
  final int units;
  final int skus;
  const _InventoryValueCard({required this.costValue, required this.sellValue, required this.units, required this.skus});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Inventory value', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface)),
          const SizedBox(height: 8),
          Text(_fmt.format(costValue), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: cs.primary)),
          Text('at cost · across $skus SKUs', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          const Divider(height: 20),
          _row('Selling value', _fmt.format(sellValue), cs),
          _row('Potential margin', _fmt.format(sellValue - costValue), cs, color: const Color(0xFF22C55E)),
          _row('Total units', _fmtFull.format(units), cs),
        ]),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _row(String label, String value, ColorScheme cs, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color ?? cs.onSurface)),
    ]),
  );
}

// ══════════════════════════════════════════
// Alert List Card (low stock / expiring)
// ══════════════════════════════════════════
class _AlertListCard extends StatelessWidget {
  final String title;
  final int count;
  final Color chipColor;
  final List items;
  final String nameKey;
  final String Function(dynamic) valueBuilder;
  const _AlertListCard({required this.title, required this.count, required this.chipColor, required this.items, required this.nameKey, required this.valueBuilder});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: chipColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: chipColor)),
            ),
          ]),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Icon(Icons.check_circle_outline_rounded, color: cs.onSurfaceVariant.withValues(alpha: 0.4), size: 28)),
            )
          else
            ...items.map((s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: Text(
                  (s[nameKey] ?? s['name'] ?? '').toString(),
                  style: const TextStyle(fontSize: 11),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: chipColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(valueBuilder(s), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: chipColor)),
                ),
              ]),
            )),
        ]),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ══════════════════════════════════════════
// Products Tab
// ══════════════════════════════════════════
class _ProductsTab extends StatefulWidget {
  final List filtered;
  final List stocks;
  final int rangeDays;
  final List txAll; // all-time for never-sold
  const _ProductsTab({required this.filtered, required this.stocks, required this.rangeDays, required this.txAll});

  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab> with TickerProviderStateMixin {
  late TabController _sub;
  String _sortBy = 'revenue';
  int _slowThreshold = 3;
  String? _abcGradeFilter;

  @override
  void initState() {
    super.initState();
    _sub = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() { _sub.dispose(); super.dispose(); }

  // Aggregate products from filtered transactions
  List<Map<String, dynamic>> _aggregateProducts(List txns) {
    final Map<String, Map<String, dynamic>> m = {};
    final Set<String> orderProducts = {};
    for (final t in txns) {
      final txId = '${t['id']}';
      for (final it in ((t['items'] as List?) ?? [])) {
        final name = (it['product_name'] ?? it['name'] ?? it['medication_name'] ?? 'Item').toString();
        final qty = _dbl(it['quantity'] ?? 1);
        final rev = _dbl(it['total'] ?? it['subtotal'] ?? (_dbl(it['unit_price']) * qty));
        final cat = (it['category_name'] ?? it['category'] ?? 'Other').toString();
        final cur = m[name] ?? {'name': name, 'qty': 0.0, 'revenue': 0.0, 'orders': 0, 'category': cat};
        cur['qty'] = (cur['qty'] as double) + qty;
        cur['revenue'] = (cur['revenue'] as double) + rev;
        final key = '$txId|$name';
        if (!orderProducts.contains(key)) {
          orderProducts.add(key);
          cur['orders'] = (cur['orders'] as int) + 1;
        }
        m[name] = cur;
      }
    }
    final list = m.values.toList();
    final totalRev = list.fold<double>(0, (s, p) => s + (p['revenue'] as double));
    for (final p in list) {
      p['avgPrice'] = (p['qty'] as double) > 0 ? (p['revenue'] as double) / (p['qty'] as double) : 0.0;
      p['share'] = totalRev > 0 ? (p['revenue'] as double) / totalRev * 100 : 0.0;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allProducts = _aggregateProducts(widget.filtered);
    final totalRevenue = allProducts.fold<double>(0, (s, p) => s + (p['revenue'] as double));
    final totalUnits = allProducts.fold<double>(0, (s, p) => s + (p['qty'] as double)).toInt();

    // All-time sold names for never-sold
    final Set<String> allTimeSold = {};
    for (final t in widget.txAll) {
      for (final it in ((t['items'] as List?) ?? [])) {
        allTimeSold.add((it['product_name'] ?? it['name'] ?? it['medication_name'] ?? '').toString().toLowerCase());
      }
    }
    // Sold names in range
    final Set<String> soldInRange = {};
    for (final p in allProducts) { soldInRange.add((p['name'] as String).toLowerCase()); }

    // Slow moving: stock > 0 AND sold <= threshold in range
    final slowMoving = <Map<String, dynamic>>[];
    for (final s in widget.stocks) {
      final stock = _dbl(s['total_quantity'] ?? s['quantity']);
      if (stock <= 0) continue;
      final name = (s['medication_name'] ?? s['name'] ?? '').toString().toLowerCase();
      final sold = allProducts.where((p) => (p['name'] as String).toLowerCase() == name).toList();
      final qtySold = sold.isNotEmpty ? (sold[0]['qty'] as double) : 0.0;
      final revenue = sold.isNotEmpty ? (sold[0]['revenue'] as double) : 0.0;
      if (qtySold <= _slowThreshold) {
        final dailyRate = widget.rangeDays > 0 ? qtySold / widget.rangeDays : 0.0;
        final daysOfStock = dailyRate > 0 ? (stock / dailyRate).round() : -1; // -1 = infinity
        slowMoving.add({'name': s['medication_name'] ?? s['name'] ?? '', 'category': s['category_name'] ?? 'Other', 'stock': stock, 'qtySold': qtySold, 'revenue': revenue, 'costValue': _dbl(s['cost_price']) * stock, 'daysOfStock': daysOfStock});
      }
    }
    slowMoving.sort((a, b) => (b['costValue'] as double).compareTo(a['costValue'] as double));
    final slowStockValue = slowMoving.fold<double>(0, (s, p) => s + (p['costValue'] as double));

    // Never sold: in catalog but never in any POS transaction
    final neverSold = widget.stocks.where((s) {
      final name = (s['medication_name'] ?? s['name'] ?? '').toString().toLowerCase();
      return !allTimeSold.contains(name);
    }).toList();
    neverSold.sort((a, b) => (_dbl(b['cost_price']) * _dbl(b['total_quantity'] ?? b['quantity']))
        .compareTo(_dbl(a['cost_price']) * _dbl(a['total_quantity'] ?? a['quantity'])));
    final neverSoldValue = neverSold.fold<double>(0, (s, x) => s + _dbl(x['cost_price']) * _dbl(x['total_quantity'] ?? x['quantity']));

    // Dead stock: has stock but zero sales in period
    final deadStock = widget.stocks.where((s) {
      final stock = _dbl(s['total_quantity'] ?? s['quantity']);
      if (stock <= 0) return false;
      final name = (s['medication_name'] ?? s['name'] ?? '').toString().toLowerCase();
      return !soldInRange.contains(name);
    }).toList();
    deadStock.sort((a, b) => (_dbl(b['cost_price']) * _dbl(b['total_quantity'] ?? b['quantity']))
        .compareTo(_dbl(a['cost_price']) * _dbl(a['total_quantity'] ?? a['quantity'])));
    final deadStockValue = deadStock.fold<double>(0, (s, x) => s + _dbl(x['cost_price']) * _dbl(x['total_quantity'] ?? x['quantity']));

    // ABC analysis
    final sorted = List<Map<String, dynamic>>.from(allProducts)..sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
    double cumPct = 0;
    for (final p in sorted) {
      cumPct += (p['share'] as double);
      p['cumPct'] = cumPct;
      p['grade'] = cumPct <= 80 ? 'A' : (cumPct <= 95 ? 'B' : 'C');
    }
    final aCount = sorted.where((p) => p['grade'] == 'A').length;
    final bCount = sorted.where((p) => p['grade'] == 'B').length;
    final cCount = sorted.where((p) => p['grade'] == 'C').length;
    final aRev = sorted.where((p) => p['grade'] == 'A').fold<double>(0, (s, p) => s + (p['revenue'] as double));
    final bRev = sorted.where((p) => p['grade'] == 'B').fold<double>(0, (s, p) => s + (p['revenue'] as double));
    final cRev = sorted.where((p) => p['grade'] == 'C').fold<double>(0, (s, p) => s + (p['revenue'] as double));

    return Column(children: [
      // KPIs
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: SizedBox(
          height: 54,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            _MiniKpi('Products', '${allProducts.length}', Icons.inventory_2_rounded, cs),
            _MiniKpi('Units', '$totalUnits', Icons.widgets_rounded, cs),
            _MiniKpi('Revenue', _fmt.format(totalRevenue), Icons.payments_rounded, cs),
            _MiniKpi('Slow', '${slowMoving.length}', Icons.speed_rounded, cs, chipColor: Colors.orange),
            _MiniKpi('Never sold', '${neverSold.length}', Icons.block_rounded, cs, chipColor: Colors.red),
          ]),
        ),
      ),
      // Sub tabs
      TabBar(
        controller: _sub,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        indicatorSize: TabBarIndicatorSize.label,
        tabs: [
          const Tab(text: 'ABC Analysis'),
          const Tab(text: 'Top Products'),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('Slow Moving'),
            const SizedBox(width: 4),
            _tabChip(slowMoving.length, Colors.orange),
          ])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('Never Sold'),
            const SizedBox(width: 4),
            _tabChip(neverSold.length, Colors.red),
          ])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('Dead Stock'),
            const SizedBox(width: 4),
            _tabChip(deadStock.length, Colors.red),
          ])),
        ],
      ),
      Expanded(child: TabBarView(controller: _sub, children: [
        // ── ABC Analysis ──
        _buildAbc(cs, sorted, aCount, bCount, cCount, aRev, bRev, cRev, totalRevenue),
        // ── Top Products ──
        _buildTopProducts(cs, allProducts, totalRevenue),
        // ── Slow Moving ──
        _buildSlowMoving(cs, slowMoving, slowStockValue),
        // ── Never Sold ──
        _buildNeverSold(cs, neverSold, neverSoldValue),
        // ── Dead Stock ──
        _buildDeadStock(cs, deadStock, deadStockValue),
      ])),
    ]);
  }

  Widget _buildTopProducts(ColorScheme cs, List<Map<String, dynamic>> products, double totalRevenue) {
    final sorted = List<Map<String, dynamic>>.from(products)
      ..sort((a, b) => (b[_sortBy] as num).compareTo(a[_sortBy] as num));
    final top = sorted.take(20).toList();
    final maxVal = top.isNotEmpty ? (top[0][_sortBy] as num).toDouble() : 1.0;

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 80), children: [
      // Sort toggle
      Row(children: [
        const Expanded(child: _SectionLabel('Top 20 products')),
        ToggleButtons(
          isSelected: [_sortBy == 'revenue', _sortBy == 'qty', _sortBy == 'orders'],
          onPressed: (i) => setState(() => _sortBy = ['revenue', 'qty', 'orders'][i]),
          borderRadius: BorderRadius.circular(8),
          constraints: const BoxConstraints(minHeight: 28, minWidth: 56),
          textStyle: const TextStyle(fontSize: 10),
          children: const [Text('Revenue'), Text('Qty'), Text('Orders')],
        ),
      ]),
      const SizedBox(height: 8),
      // Product list
      ...top.asMap().entries.map((e) {
        final i = e.key;
        final p = e.value;
        final pct = maxVal > 0 ? ((p[_sortBy] as num).toDouble() / maxVal * 100) : 0.0;
        return Card(
          elevation: 0, margin: const EdgeInsets.only(bottom: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.12))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                SizedBox(width: 22, child: Text('${i + 1}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600))),
                Expanded(child: Text(p['name'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text(_fmt.format(p['revenue']), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                const SizedBox(width: 22),
                Text(p['category'] as String, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                const Spacer(),
                Text('${(p['qty'] as double).toInt()} units · ${p['orders']} orders', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: pct / 100, minHeight: 4, backgroundColor: cs.outlineVariant.withValues(alpha: 0.12), color: _barColors[i % _barColors.length]),
              ),
            ]),
          ),
        );
      }),
    ]);
  }

  Widget _buildSlowMoving(ColorScheme cs, List<Map<String, dynamic>> items, double totalValue) {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 80), children: [
      // Threshold control
      Row(children: [
        const Expanded(child: _SectionLabel('Slow Moving')),
        SizedBox(width: 100, child: TextFormField(
          initialValue: '$_slowThreshold',
          decoration: InputDecoration(isDense: true, labelText: 'Max qty', contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 12),
          onChanged: (v) { final n = int.tryParse(v); if (n != null && n > 0) setState(() => _slowThreshold = n); },
        )),
      ]),
      if (items.isNotEmpty) ...[
        const SizedBox(height: 8),
        _AlertBanner('${items.length} slow-moving products · ${_fmt.format(totalValue)} tied up', Colors.orange),
      ],
      const SizedBox(height: 8),
      if (items.isEmpty)
        const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No slow-moving products')))
      else
        ...items.take(25).toList().asMap().entries.map((e) {
          final i = e.key; final p = e.value;
          final dos = p['daysOfStock'] as int;
          final dosText = dos < 0 ? '∞' : '$dos';
          final dosColor = dos < 0 || dos > 180 ? Colors.red : (dos > 90 ? Colors.orange : const Color(0xFF3B82F6));
          return Card(
            elevation: 0, margin: const EdgeInsets.only(bottom: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.12))),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                SizedBox(width: 22, child: Text('${i + 1}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['name'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('Stock: ${(p['stock'] as double).toInt()} · Sold: ${(p['qtySold'] as double).toInt()} · ${_fmt.format(p['costValue'])}', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: dosColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text('${dosText}d', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: dosColor)),
                ),
              ]),
            ),
          );
        }),
    ]);
  }

  Widget _buildNeverSold(ColorScheme cs, List items, double totalValue) {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 80), children: [
      const _SectionLabel('Never Sold'),
      if (items.isNotEmpty) ...[
        const SizedBox(height: 8),
        _AlertBanner('${items.length} products never sold · ${_fmt.format(totalValue)} locked', Colors.red),
      ],
      const SizedBox(height: 8),
      if (items.isEmpty)
        const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('All products have sales')))
      else
        ...items.take(25).toList().asMap().entries.map((e) {
          final i = e.key; final s = e.value;
          final stock = _dbl(s['total_quantity'] ?? s['quantity']);
          final costVal = _dbl(s['cost_price']) * stock;
          return Card(
            elevation: 0, margin: const EdgeInsets.only(bottom: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.12))),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                SizedBox(width: 22, child: Text('${i + 1}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((s['medication_name'] ?? s['name'] ?? '').toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('Stock: ${stock.toInt()} · Cost: ${_fmt.format(_dbl(s['cost_price']))} · Sell: ${_fmt.format(_dbl(s['selling_price']))}', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                ])),
                Text(_fmt.format(costVal), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.red.shade400)),
              ]),
            ),
          );
        }),
    ]);
  }

  Widget _buildAbc(ColorScheme cs, List<Map<String, dynamic>> sorted, int aCount, int bCount, int cCount, double aRev, double bRev, double cRev, double totalRevenue) {
    final displayed = _abcGradeFilter != null ? sorted.where((p) => p['grade'] == _abcGradeFilter).toList() : sorted;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 80), children: [
      const _SectionLabel('ABC Analysis'),
      const SizedBox(height: 4),
      Text('A ≤ 80% cumulative revenue · B ≤ 95% · C > 95%', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      const SizedBox(height: 12),
      // Summary cards
      Row(children: [
        Expanded(child: _AbcCard('A', aCount, aRev, totalRevenue, const Color(0xFF22C55E), cs, selected: _abcGradeFilter == 'A', onTap: () => setState(() => _abcGradeFilter = _abcGradeFilter == 'A' ? null : 'A'))),
        const SizedBox(width: 8),
        Expanded(child: _AbcCard('B', bCount, bRev, totalRevenue, const Color(0xFFF59E0B), cs, selected: _abcGradeFilter == 'B', onTap: () => setState(() => _abcGradeFilter = _abcGradeFilter == 'B' ? null : 'B'))),
        const SizedBox(width: 8),
        Expanded(child: _AbcCard('C', cCount, cRev, totalRevenue, const Color(0xFFEF4444), cs, selected: _abcGradeFilter == 'C', onTap: () => setState(() => _abcGradeFilter = _abcGradeFilter == 'C' ? null : 'C'))),
      ]),
      if (_abcGradeFilter != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            Text('Showing grade $_abcGradeFilter · ${displayed.length} items', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.primary)),
            const Spacer(),
            GestureDetector(onTap: () => setState(() => _abcGradeFilter = null), child: Text('Clear', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.error))),
          ]),
        ),
      const SizedBox(height: 12),
      // Table
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(children: [
              const SizedBox(width: 24),
              const Expanded(flex: 4, child: Text('Product', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
              const Expanded(flex: 2, child: Text('Revenue', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
              const Expanded(flex: 2, child: Text('Cum %', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
              const SizedBox(width: 28),
            ]),
            const Divider(height: 14),
            ...displayed.take(25).toList().asMap().entries.map((e) {
              final i = e.key; final p = e.value;
              final grade = p['grade'] as String;
              final gradeColor = grade == 'A' ? const Color(0xFF22C55E) : (grade == 'B' ? const Color(0xFFF59E0B) : Colors.red);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(width: 24, child: Text('${i + 1}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))),
                  Expanded(flex: 4, child: Text(p['name'] as String, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Expanded(flex: 2, child: Text(_fmt.format(p['revenue']), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                  Expanded(flex: 2, child: Text('${(p['cumPct'] as double).toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), textAlign: TextAlign.right)),
                  SizedBox(width: 28, child: Center(child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: gradeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                    child: Text(grade, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: gradeColor)),
                  ))),
                ]),
              );
            }),
          ]),
        ),
      ).animate().fadeIn(duration: 400.ms),
    ]);
  }

  Widget _buildDeadStock(ColorScheme cs, List items, double totalValue) {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 80), children: [
      const _SectionLabel('Dead Stock'),
      if (items.isNotEmpty) ...[
        const SizedBox(height: 8),
        _AlertBanner('${items.length} dead stock items · ${_fmt.format(totalValue)} idle capital', Colors.red),
      ],
      const SizedBox(height: 8),
      if (items.isEmpty)
        const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No dead stock found')))
      else
        ...items.take(25).toList().asMap().entries.map((e) {
          final i = e.key; final s = e.value;
          final stock = _dbl(s['total_quantity'] ?? s['quantity']);
          final costVal = _dbl(s['cost_price']) * stock;
          final potentialRev = _dbl(s['selling_price']) * stock;
          return Card(
            elevation: 0, margin: const EdgeInsets.only(bottom: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.12))),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                SizedBox(width: 22, child: Text('${i + 1}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((s['medication_name'] ?? s['name'] ?? '').toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('Stock: ${stock.toInt()} · Cost: ${_fmt.format(costVal)}', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                ])),
                Text(_fmt.format(potentialRev), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
              ]),
            ),
          );
        }),
    ]);
  }

  Widget _tabChip(int count, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
    child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c)),
  );
}

// ══════════════════════════════════════════
// Categories Tab
// ══════════════════════════════════════════
class _CategoriesTab extends StatefulWidget {
  final List filtered;
  final List stocks;
  final int rangeDays;
  final List txAll;
  const _CategoriesTab({required this.filtered, required this.stocks, required this.rangeDays, required this.txAll});

  @override
  State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<_CategoriesTab> with TickerProviderStateMixin {
  late TabController _sub;
  final int _slowThreshold = 3;
  String? _abcGradeFilter;

  @override
  void initState() {
    super.initState();
    _sub = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() { _sub.dispose(); super.dispose(); }

  List<Map<String, dynamic>> _aggregateCategories(List txns) {
    final Map<String, Map<String, dynamic>> m = {};
    for (final t in txns) {
      final txId = '${t['id']}';
      final Set<String> seenCat = {};
      for (final it in ((t['items'] as List?) ?? [])) {
        final cat = (it['category_name'] ?? it['category'] ?? 'Other').toString();
        final qty = _dbl(it['quantity'] ?? 1);
        final rev = _dbl(it['total'] ?? it['subtotal'] ?? (_dbl(it['unit_price']) * qty));
        final prodName = (it['product_name'] ?? it['name'] ?? it['medication_name'] ?? 'Item').toString();
        final cur = m[cat] ?? {'name': cat, 'qty': 0.0, 'revenue': 0.0, 'orders': 0, 'products': <String>{}};
        cur['qty'] = (cur['qty'] as double) + qty;
        cur['revenue'] = (cur['revenue'] as double) + rev;
        (cur['products'] as Set<String>).add(prodName);
        if (!seenCat.contains('$txId|$cat')) {
          seenCat.add('$txId|$cat');
          cur['orders'] = (cur['orders'] as int) + 1;
        }
        m[cat] = cur;
      }
    }
    final totalRev = m.values.fold<double>(0, (s, c) => s + (c['revenue'] as double));
    return m.values.map((c) {
      final productCount = (c['products'] as Set<String>).length;
      return {
        'name': c['name'],
        'qty': c['qty'],
        'revenue': c['revenue'],
        'orders': c['orders'],
        'productCount': productCount,
        'avgOrder': (c['orders'] as int) > 0 ? (c['revenue'] as double) / (c['orders'] as int) : 0.0,
        'share': totalRev > 0 ? (c['revenue'] as double) / totalRev * 100 : 0.0,
      };
    }).toList()..sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allCategories = _aggregateCategories(widget.filtered);
    final totalRevenue = allCategories.fold<double>(0, (s, c) => s + (c['revenue'] as double));
    final totalUnits = allCategories.fold<double>(0, (s, c) => s + (c['qty'] as double)).toInt();

    // Stock by category
    final Map<String, Map<String, dynamic>> stockByCat = {};
    for (final s in widget.stocks) {
      final cat = (s['category_name'] ?? 'Uncategorized').toString().toLowerCase();
      final cur = stockByCat[cat] ?? {'totalStock': 0.0, 'costValue': 0.0, 'potentialRev': 0.0, 'count': 0};
      final stock = _dbl(s['total_quantity'] ?? s['quantity']);
      cur['totalStock'] = (cur['totalStock'] as double) + stock;
      cur['costValue'] = (cur['costValue'] as double) + _dbl(s['cost_price']) * stock;
      cur['potentialRev'] = (cur['potentialRev'] as double) + _dbl(s['selling_price']) * stock;
      cur['count'] = (cur['count'] as int) + 1;
      stockByCat[cat] = cur;
    }

    // All-time sold category names
    final Set<String> allTimeSoldCats = {};
    for (final t in widget.txAll) {
      for (final it in ((t['items'] as List?) ?? [])) {
        allTimeSoldCats.add((it['category_name'] ?? it['category'] ?? 'Other').toString().toLowerCase());
      }
    }
    final Set<String> soldCatsInRange = allCategories.map((c) => (c['name'] as String).toLowerCase()).toSet();

    // Slow moving categories
    final slowCats = <Map<String, dynamic>>[];
    for (final e in stockByCat.entries) {
      if ((e.value['totalStock'] as double) <= 0) continue;
      final sold = allCategories.where((c) => (c['name'] as String).toLowerCase() == e.key).toList();
      final qtySold = sold.isNotEmpty ? (sold[0]['qty'] as double) : 0.0;
      final revenue = sold.isNotEmpty ? (sold[0]['revenue'] as double) : 0.0;
      if (qtySold <= _slowThreshold) {
        slowCats.add({'name': e.key, 'products': e.value['count'], 'totalStock': e.value['totalStock'], 'qtySold': qtySold, 'revenue': revenue, 'costValue': e.value['costValue']});
      }
    }
    slowCats.sort((a, b) => (b['costValue'] as double).compareTo(a['costValue'] as double));

    // Never sold categories
    final neverSoldCats = stockByCat.entries.where((e) => !allTimeSoldCats.contains(e.key)).map((e) => {
      'name': e.key, 'products': e.value['count'], 'totalStock': e.value['totalStock'], 'costValue': e.value['costValue'], 'potentialRev': e.value['potentialRev'],
    }).toList()..sort((a, b) => (b['costValue'] as double).compareTo(a['costValue'] as double));

    // Dead stock categories
    final deadCats = stockByCat.entries.where((e) => (e.value['totalStock'] as double) > 0 && !soldCatsInRange.contains(e.key)).map((e) => {
      'name': e.key, 'products': e.value['count'], 'totalStock': e.value['totalStock'], 'costValue': e.value['costValue'], 'potentialRev': e.value['potentialRev'],
    }).toList()..sort((a, b) => (b['costValue'] as double).compareTo(a['costValue'] as double));

    // ABC
    final sortedCats = List<Map<String, dynamic>>.from(allCategories);
    double cumPct = 0;
    for (final c in sortedCats) {
      cumPct += (c['share'] as double);
      c['cumPct'] = cumPct;
      c['grade'] = cumPct <= 80 ? 'A' : (cumPct <= 95 ? 'B' : 'C');
    }

    final topCatName = allCategories.isNotEmpty ? allCategories[0]['name'] as String : '—';

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: SizedBox(
          height: 54,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            _MiniKpi('Categories', '${allCategories.length}', Icons.category_rounded, cs),
            _MiniKpi('Revenue', _fmt.format(totalRevenue), Icons.payments_rounded, cs),
            _MiniKpi('Units', '$totalUnits', Icons.widgets_rounded, cs),
            _MiniKpi('Slow', '${slowCats.length}', Icons.speed_rounded, cs, chipColor: Colors.orange),
            _MiniKpi('Top', topCatName, Icons.star_rounded, cs, chipColor: const Color(0xFF22C55E)),
          ]),
        ),
      ),
      TabBar(
        controller: _sub,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        indicatorSize: TabBarIndicatorSize.label,
        tabs: [
          const Tab(text: 'ABC Analysis'),
          const Tab(text: 'Categories'),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [const Text('Slow Moving'), const SizedBox(width: 4), _tabChip(slowCats.length, Colors.orange)])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [const Text('Never Sold'), const SizedBox(width: 4), _tabChip(neverSoldCats.length, Colors.red)])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [const Text('Dead Stock'), const SizedBox(width: 4), _tabChip(deadCats.length, Colors.red)])),
        ],
      ),
      Expanded(child: TabBarView(controller: _sub, children: [
        // ABC
        _buildCatAbc(cs, sortedCats, totalRevenue),
        // Categories list with donut
        _buildCategoriesList(cs, allCategories, totalRevenue),
        // Slow
        _buildCatList(cs, 'Slow Moving Categories', slowCats, Colors.orange, showSold: true),
        // Never sold
        _buildCatList(cs, 'Never Sold Categories', neverSoldCats, Colors.red),
        // Dead
        _buildCatList(cs, 'Dead Stock Categories', deadCats, Colors.red),
      ])),
    ]);
  }

  Widget _buildCatAbc(ColorScheme cs, List<Map<String, dynamic>> sorted, double totalRevenue) {
    final aCount = sorted.where((c) => c['grade'] == 'A').length;
    final bCount = sorted.where((c) => c['grade'] == 'B').length;
    final cCount = sorted.where((c) => c['grade'] == 'C').length;
    final aRev = sorted.where((c) => c['grade'] == 'A').fold<double>(0, (s, c) => s + (c['revenue'] as double));
    final bRev = sorted.where((c) => c['grade'] == 'B').fold<double>(0, (s, c) => s + (c['revenue'] as double));
    final cRev = sorted.where((c) => c['grade'] == 'C').fold<double>(0, (s, c) => s + (c['revenue'] as double));
    final displayed = _abcGradeFilter != null ? sorted.where((c) => c['grade'] == _abcGradeFilter).toList() : sorted;

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 80), children: [
      const _SectionLabel('ABC Analysis'),
      const SizedBox(height: 4),
      Text('A ≤ 80% cumulative · B ≤ 95% · C > 95%', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _AbcCard('A', aCount, aRev, totalRevenue, const Color(0xFF22C55E), cs, selected: _abcGradeFilter == 'A', onTap: () => setState(() => _abcGradeFilter = _abcGradeFilter == 'A' ? null : 'A'))),
        const SizedBox(width: 8),
        Expanded(child: _AbcCard('B', bCount, bRev, totalRevenue, const Color(0xFFF59E0B), cs, selected: _abcGradeFilter == 'B', onTap: () => setState(() => _abcGradeFilter = _abcGradeFilter == 'B' ? null : 'B'))),
        const SizedBox(width: 8),
        Expanded(child: _AbcCard('C', cCount, cRev, totalRevenue, const Color(0xFFEF4444), cs, selected: _abcGradeFilter == 'C', onTap: () => setState(() => _abcGradeFilter = _abcGradeFilter == 'C' ? null : 'C'))),
      ]),
      if (_abcGradeFilter != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            Text('Showing grade $_abcGradeFilter · ${displayed.length} items', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.primary)),
            const Spacer(),
            GestureDetector(onTap: () => setState(() => _abcGradeFilter = null), child: Text('Clear', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.error))),
          ]),
        ),
      const SizedBox(height: 12),
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(children: [
              const SizedBox(width: 24),
              const Expanded(flex: 3, child: Text('Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
              const Expanded(flex: 2, child: Text('Revenue', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
              const Expanded(flex: 2, child: Text('Cum %', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
              const SizedBox(width: 28),
            ]),
            const Divider(height: 14),
            ...displayed.take(25).toList().asMap().entries.map((e) {
              final i = e.key; final c = e.value;
              final grade = c['grade'] as String;
              final gc = grade == 'A' ? const Color(0xFF22C55E) : (grade == 'B' ? const Color(0xFFF59E0B) : Colors.red);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(width: 24, child: Text('${i + 1}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))),
                  Expanded(flex: 3, child: Text(c['name'] as String, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Expanded(flex: 2, child: Text(_fmt.format(c['revenue']), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                  Expanded(flex: 2, child: Text('${(c['cumPct'] as double).toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), textAlign: TextAlign.right)),
                  SizedBox(width: 28, child: Center(child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: gc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                    child: Text(grade, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: gc)),
                  ))),
                ]),
              );
            }),
          ]),
        ),
      ).animate().fadeIn(duration: 400.ms),
    ]);
  }

  Widget _buildCategoriesList(ColorScheme cs, List<Map<String, dynamic>> categories, double totalRevenue) {
    // Donut segments: top 7 + Other
    final top7 = categories.take(7).toList();
    final rest = categories.skip(7).toList();
    final otherRev = rest.fold<double>(0, (s, c) => s + (c['revenue'] as double));

    final segments = <MapEntry<String, double>>[];
    for (final c in top7) {
      segments.add(MapEntry(c['name'] as String, c['revenue'] as double));
    }
    if (rest.isNotEmpty) {
      segments.add(MapEntry('Other (${rest.length})', otherRev));
    }

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 80), children: [
      const _SectionLabel('Revenue distribution'),
      const SizedBox(height: 8),
      _CategoryDonut(categories: segments, total: totalRevenue),
      const SizedBox(height: 16),
      const _SectionLabel('All categories'),
      const SizedBox(height: 8),
      ...categories.asMap().entries.map((e) {
        final i = e.key; final c = e.value;
        return Card(
          elevation: 0, margin: const EdgeInsets.only(bottom: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.12))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                SizedBox(width: 22, child: Text('${i + 1}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600))),
                Expanded(child: Text(c['name'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text(_fmt.format(c['revenue']), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                const SizedBox(width: 22),
                Text('${c['productCount']} products · ${(c['qty'] as double).toInt()} units · ${c['orders']} orders', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                const Spacer(),
                Text('${(c['share'] as double).toStringAsFixed(1)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.primary)),
              ]),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: (c['share'] as double) / 100, minHeight: 4, backgroundColor: cs.outlineVariant.withValues(alpha: 0.12), color: _barColors[i % _barColors.length]),
              ),
            ]),
          ),
        );
      }),
    ]);
  }

  Widget _buildCatList(ColorScheme cs, String title, List<Map<String, dynamic>> items, Color alertColor, {bool showSold = false}) {
    final totalValue = items.fold<double>(0, (s, c) => s + (c['costValue'] as double));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 80), children: [
      _SectionLabel(title),
      if (items.isNotEmpty) ...[
        const SizedBox(height: 8),
        _AlertBanner('${items.length} categories · ${_fmt.format(totalValue)} tied up', alertColor),
      ],
      const SizedBox(height: 8),
      if (items.isEmpty)
        const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('None found')))
      else
        ...items.take(25).toList().asMap().entries.map((e) {
          final i = e.key; final c = e.value;
          return Card(
            elevation: 0, margin: const EdgeInsets.only(bottom: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.12))),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                SizedBox(width: 22, child: Text('${i + 1}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((c['name'] as String).isNotEmpty ? (c['name'] as String)[0].toUpperCase() + (c['name'] as String).substring(1) : '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${c['products']} products · Stock: ${(c['totalStock'] as double).toInt()}${showSold ? ' · Sold: ${(c['qtySold'] as double).toInt()}' : ''}', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                ])),
                Text(_fmt.format(c['costValue']), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: alertColor)),
              ]),
            ),
          );
        }),
    ]);
  }

  Widget _tabChip(int count, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
    child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c)),
  );
}

// ══════════════════════════════════════════
// Shared mini widgets
// ══════════════════════════════════════════
class _MiniKpi extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final ColorScheme cs;
  final Color? chipColor;
  const _MiniKpi(this.label, this.value, this.icon, this.cs, {this.chipColor});

  @override
  Widget build(BuildContext context) {
    final c = chipColor ?? cs.primary;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.15)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cs.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ]),
    );
  }
}

class _AbcCard extends StatelessWidget {
  final String grade;
  final int count;
  final double revenue;
  final double totalRevenue;
  final Color color;
  final ColorScheme cs;
  final bool selected;
  final VoidCallback? onTap;
  const _AbcCard(this.grade, this.count, this.revenue, this.totalRevenue, this.color, this.cs, {this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = totalRevenue > 0 ? (revenue / totalRevenue * 100).round() : 0;
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: selected ? 2 : 0,
        color: selected ? color.withValues(alpha: 0.16) : color.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: color.withValues(alpha: selected ? 0.6 : 0.2), width: selected ? 2 : 1)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Text(grade, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 4),
            Text('$count items', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            Text('$pct%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface)),
            Text(_fmt.format(revenue), style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final String text;
  final Color color;
  const _AlertBanner(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(Icons.warning_amber_rounded, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color))),
      ]),
    );
  }
}
