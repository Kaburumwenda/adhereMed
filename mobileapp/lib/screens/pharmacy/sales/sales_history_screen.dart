import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/api.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/common.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════
final _salesProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/pos/transactions/', queryParameters: {'page_size': 2000});
  final data = res.data;
  final list = data is List ? data : (data?['results'] as List?) ?? [];
  return List<Map<String, dynamic>>.from(list);
});

final _searchProvider = StateProvider.autoDispose((_) => '');
final _paymentFilter = StateProvider.autoDispose<String?>((_) => null);
final _statusFilter = StateProvider.autoDispose<String?>((_) => null);
final _cashierFilter = StateProvider.autoDispose<String?>((_) => null);
final _branchFilter = StateProvider.autoDispose<String?>((_) => null);
final _dateRange = StateProvider.autoDispose<String>((_) => 'all');
final _customFrom = StateProvider.autoDispose<DateTime?>((_) => null);
final _customTo = StateProvider.autoDispose<DateTime?>((_) => null);
final _visibleCount = StateProvider.autoDispose((_) => 20);
const _loadBatch = 20;

// ═══════════════════════════════════════════════════════════════════════════
//  CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════
const _paymentMethods = ['cash', 'card', 'mpesa', 'insurance', 'credit'];
const _statuses = ['completed', 'cancelled', 'suspended', 'pending'];

final _dateRanges = {
  'all': 'All Time',
  'today': 'Today',
  'yesterday': 'Yesterday',
  '7d': 'Last 7 Days',
  '30d': 'Last 30 Days',
  'month': 'This Month',
  'last_month': 'Last Month',
  'custom': 'Custom Range',
};

Color _paymentColor(String? m) => switch (m?.toLowerCase()) {
  'cash' => const Color(0xFF10B981),
  'mpesa' => const Color(0xFF059669),
  'card' => const Color(0xFF3B82F6),
  'insurance' => const Color(0xFFF59E0B),
  'credit' => const Color(0xFFEC4899),
  _ => const Color(0xFF6B7280),
};

Color _statusColor(String? s) => switch (s?.toLowerCase()) {
  'completed' => const Color(0xFF10B981),
  'pending' => const Color(0xFFF59E0B),
  'cancelled' || 'voided' || 'refunded' => const Color(0xFFEF4444),
  'suspended' => const Color(0xFF6B7280),
  _ => const Color(0xFF6B7280),
};

IconData _paymentIcon(String? m) => switch (m?.toLowerCase()) {
  'cash' => Icons.payments_rounded,
  'mpesa' => Icons.phone_android_rounded,
  'card' => Icons.credit_card_rounded,
  'insurance' => Icons.health_and_safety_rounded,
  'credit' => Icons.access_time_rounded,
  _ => Icons.payment_rounded,
};

// ═══════════════════════════════════════════════════════════════════════════
//  SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key});
  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(_visibleCount.notifier).update((c) => c + _loadBatch);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sales = ref.watch(_salesProvider);
    final search = ref.watch(_searchProvider).toLowerCase();
    final payment = ref.watch(_paymentFilter);
    final status = ref.watch(_statusFilter);
    final cashier = ref.watch(_cashierFilter);
    final branch = ref.watch(_branchFilter);
    final dateRange = ref.watch(_dateRange);

    // Reset visible count when filters change
    ref.listen(_searchProvider, (_, __) => ref.read(_visibleCount.notifier).state = _loadBatch);
    ref.listen(_paymentFilter, (_, __) => ref.read(_visibleCount.notifier).state = _loadBatch);
    ref.listen(_statusFilter, (_, __) => ref.read(_visibleCount.notifier).state = _loadBatch);
    ref.listen(_cashierFilter, (_, __) => ref.read(_visibleCount.notifier).state = _loadBatch);
    ref.listen(_branchFilter, (_, __) => ref.read(_visibleCount.notifier).state = _loadBatch);
    ref.listen(_dateRange, (_, __) => ref.read(_visibleCount.notifier).state = _loadBatch);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => ref.invalidate(_salesProvider)),
        ],
      ),
      body: sales.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorRetry(message: 'Failed to load sales', onRetry: () => ref.invalidate(_salesProvider)),
        data: (allSales) {
          // Apply date filter first
          final dated = _filterByDate(allSales, dateRange, ref);

          // Apply search & filters
          final filtered = dated.where((s) {
            if (search.isNotEmpty) {
              final txn = (s['transaction_number'] ?? '').toString().toLowerCase();
              final cust = (s['customer_name'] ?? '').toString().toLowerCase();
              final phone = (s['customer_phone'] ?? '').toString().toLowerCase();
              if (!txn.contains(search) && !cust.contains(search) && !phone.contains(search)) return false;
            }
            if (payment != null && s['payment_method'] != payment) return false;
            if (status != null && s['status'] != status) return false;
            if (cashier != null && _cashierName(s) != cashier) return false;
            if (branch != null) {
              final sb = s['branch_name']?.toString() ?? '';
              if (sb != branch) return false;
            }
            return true;
          }).toList();

          // KPIs from filtered data
          final completed = filtered.where((s) => s['status'] == 'completed').toList();
          final voided = filtered.where((s) => s['status'] == 'cancelled' || s['status'] == 'voided').length;
          final revenue = completed.fold<double>(0, (a, s) => a + (double.tryParse('${s['total']}') ?? 0));
          final discount = completed.fold<double>(0, (a, s) => a + (double.tryParse('${s['discount']}') ?? 0));
          int totalItems = 0;
          final productSet = <String>{};
          for (final s in completed) {
            final items = s['items'] as List? ?? [];
            for (final it in items) {
              totalItems += (it['quantity'] as num?)?.toInt() ?? 0;
              final name = it['medication_name']?.toString();
              if (name != null) productSet.add(name);
            }
          }
          final aov = completed.isNotEmpty ? revenue / completed.length : 0.0;
          final cur = NumberFormat('#,##0.00');

          return RefreshIndicator(
            onRefresh: () async { ref.invalidate(_salesProvider); ref.read(_visibleCount.notifier).state = _loadBatch; },
            child: ListView(controller: _scrollCtrl, padding: const EdgeInsets.all(16), children: [
              // ── KPI Row ──
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                _KpiCard(icon: Icons.receipt_long_rounded, color: const Color(0xFF3B82F6),
                  title: 'Transactions', value: '${filtered.length}',
                  sub: '${completed.length} completed · $voided voided'),
                const SizedBox(width: 10),
                _KpiCard(icon: Icons.trending_up_rounded, color: const Color(0xFF10B981),
                  title: 'Net Revenue', value: cur.format(revenue),
                  sub: 'Discount: ${cur.format(discount)}'),
                const SizedBox(width: 10),
                _KpiCard(icon: Icons.shopping_bag_rounded, color: const Color(0xFF8B5CF6),
                  title: 'Items Sold', value: '$totalItems',
                  sub: '${productSet.length} unique products'),
                const SizedBox(width: 10),
                _KpiCard(icon: Icons.calculate_rounded, color: const Color(0xFFF59E0B),
                  title: 'Avg. Order', value: cur.format(aov),
                  sub: '${completed.length} orders'),
              ])).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 16),

              // ── Search ──
              TextField(
                onChanged: (v) => ref.read(_searchProvider.notifier).state = v,
                decoration: InputDecoration(
                  hintText: 'Search receipt #, customer...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true, filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                style: const TextStyle(fontSize: 14),
              ).animate().fadeIn(duration: 300.ms, delay: 50.ms),
              const SizedBox(height: 12),

              // ── Filters ──
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                // Date range
                _FilterChip(
                  label: dateRange == 'custom'
                    ? () {
                        final f = ref.watch(_customFrom);
                        final t = ref.watch(_customTo);
                        final fmt = DateFormat('MMM dd');
                        if (f != null && t != null) return '${fmt.format(f)} – ${fmt.format(t)}';
                        return 'Custom';
                      }()
                    : _dateRanges[dateRange] ?? 'All Time',
                  icon: dateRange == 'custom' ? Icons.date_range_rounded : Icons.calendar_today_rounded,
                  isActive: dateRange != 'all',
                  onTap: () => _showDateRangeSheet(context, ref),
                ),
                const SizedBox(width: 8),
                // Payment method
                _FilterChip(
                  label: payment != null ? payment!.toUpperCase() : 'Payment',
                  icon: Icons.payment_rounded,
                  isActive: payment != null,
                  onTap: () => _showFilterSheet(context, ref, 'Payment Method', _paymentMethods, _paymentFilter),
                ),
                const SizedBox(width: 8),
                // Status
                _FilterChip(
                  label: status != null ? _cap(status!) : 'Status',
                  icon: Icons.circle_rounded,
                  isActive: status != null,
                  onTap: () => _showFilterSheet(context, ref, 'Status', _statuses, _statusFilter),
                ),
                const SizedBox(width: 8),
                // Cashier (dynamic from data)
                _FilterChip(
                  label: cashier ?? 'Cashier',
                  icon: Icons.person_rounded,
                  isActive: cashier != null,
                  onTap: () {
                    final cashiers = allSales.map((s) => _cashierName(s)).where((n) => n != '-').toSet().toList()..sort();
                    _showDynamicFilterSheet(context, ref, 'Cashier', cashiers, _cashierFilter, Icons.person_rounded);
                  },
                ),
                const SizedBox(width: 8),
                // Branch (dynamic from data)
                _FilterChip(
                  label: branch ?? 'Branch',
                  icon: Icons.store_rounded,
                  isActive: branch != null,
                  onTap: () {
                    final branches = allSales.map((s) {
                      return s['branch_name']?.toString() ?? '';
                    }).where((n) => n.isNotEmpty).toSet().toList()..sort();
                    _showDynamicFilterSheet(context, ref, 'Branch', branches, _branchFilter, Icons.store_rounded);
                  },
                ),
                if (payment != null || status != null || cashier != null || branch != null || dateRange != 'all') ...[
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.clear_rounded, size: 16),
                    label: const Text('Clear', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      ref.read(_paymentFilter.notifier).state = null;
                      ref.read(_statusFilter.notifier).state = null;
                      ref.read(_cashierFilter.notifier).state = null;
                      ref.read(_branchFilter.notifier).state = null;
                      ref.read(_dateRange.notifier).state = 'all';
                    },
                  ),
                ],
              ])).animate().fadeIn(duration: 300.ms, delay: 100.ms),
              const SizedBox(height: 16),

              // ── Results header ──
              Row(children: [
                Text('${filtered.length} transactions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _exportCsv(context, filtered),
                  icon: const Icon(Icons.table_chart_rounded, size: 16),
                  label: const Text('CSV', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => _exportPdf(context, ref, filtered),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  label: const Text('PDF', style: TextStyle(fontSize: 12)),
                ),
              ]),
              const SizedBox(height: 8),

              // ── Sales list ──
              if (filtered.isEmpty)
                const EmptyState(icon: Icons.receipt_long_rounded, title: 'No transactions found')
              else ...[              
                ...(() {
                  final visible = ref.watch(_visibleCount);
                  final shown = filtered.take(visible).toList();
                  return shown.asMap().entries.map((e) {
                    final i = e.key;
                    final s = e.value;
                    return _SaleCard(sale: s, onTap: () => _showSaleDetail(context, ref, s))
                      .animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: (30 * i).clamp(0, 300)));
                  });
                })(),
                // Loading indicator / end message
                if (ref.watch(_visibleCount) < filtered.length)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: SizedBox(width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary))),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text(
                      'Showing all ${filtered.length} transactions',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    )),
                  ),
              ],
              const SizedBox(height: 80),
            ]),
          );
        },
      ),
    );
  }

  // ── Date filtering ──
  List<Map<String, dynamic>> _filterByDate(List<Map<String, dynamic>> sales, String range, WidgetRef ref) {
    if (range == 'all') return sales;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? from;
    DateTime? to;

    switch (range) {
      case 'today': from = today;
      case 'yesterday': from = today.subtract(const Duration(days: 1)); to = today;
      case '7d': from = today.subtract(const Duration(days: 7));
      case '30d': from = today.subtract(const Duration(days: 30));
      case 'month': from = DateTime(now.year, now.month, 1);
      case 'last_month':
        from = DateTime(now.year, now.month - 1, 1);
        to = DateTime(now.year, now.month, 1);
      case 'custom':
        from = ref.read(_customFrom);
        to = ref.read(_customTo)?.add(const Duration(days: 1));
    }
    if (from == null) return sales;
    return sales.where((s) {
      final d = DateTime.tryParse(s['created_at']?.toString() ?? '');
      if (d == null) return false;
      if (d.isBefore(from!)) return false;
      if (to != null && d.isAfter(to)) return false;
      return true;
    }).toList();
  }

  // ── Filter bottom sheet ──
  void _showFilterSheet(BuildContext context, WidgetRef ref, String title, List<String> options, AutoDisposeStateProvider<String?> provider) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Flexible(child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.clear_all_rounded),
              title: const Text('All'),
              selected: ref.read(provider) == null,
              onTap: () { ref.read(provider.notifier).state = null; Navigator.pop(context); },
            ),
            ...options.map((o) => ListTile(
              leading: title == 'Payment Method'
                ? Icon(_paymentIcon(o), color: _paymentColor(o))
                : Icon(Icons.circle, size: 12, color: _statusColor(o)),
              title: Text(_cap(o)),
              selected: ref.read(provider) == o,
              onTap: () { ref.read(provider.notifier).state = o; Navigator.pop(context); },
            )),
          ]))),
        ]),
      ),
    );
  }

  // ── Dynamic filter sheet (cashier/branch) ──
  void _showDynamicFilterSheet(BuildContext context, WidgetRef ref, String title, List<String> options, AutoDisposeStateProvider<String?> provider, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Flexible(child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.clear_all_rounded),
              title: const Text('All'),
              selected: ref.read(provider) == null,
              onTap: () { ref.read(provider.notifier).state = null; Navigator.pop(context); },
            ),
            if (options.isEmpty)
              ListTile(
                leading: Icon(Icons.info_outline_rounded, color: cs.onSurfaceVariant),
                title: Text('No ${title.toLowerCase()}s found', style: TextStyle(color: cs.onSurfaceVariant)),
              )
            else
              ...options.map((o) => ListTile(
                leading: Icon(icon, size: 20, color: ref.read(provider) == o ? cs.primary : cs.onSurfaceVariant),
                title: Text(o),
                selected: ref.read(provider) == o,
                onTap: () { ref.read(provider.notifier).state = o; Navigator.pop(context); },
              )),
          ]))),
        ]),
      ),
    );
  }

  // ── Date range sheet ──
  void _showDateRangeSheet(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final current = ref.read(_dateRange);
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Date Range', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Flexible(child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            ..._dateRanges.entries.map((e) => ListTile(
              leading: Icon(
                e.key == 'all' ? Icons.all_inclusive_rounded
                  : e.key == 'custom' ? Icons.date_range_rounded
                  : Icons.calendar_today_rounded,
                color: current == e.key ? cs.primary : cs.onSurfaceVariant, size: 20),
              title: Text(e.value),
              subtitle: e.key == 'custom' && current == 'custom'
                ? Builder(builder: (_) {
                    final f = ref.read(_customFrom);
                    final t = ref.read(_customTo);
                    if (f == null && t == null) return const SizedBox.shrink();
                    final fmt = DateFormat('MMM dd, yyyy');
                    return Text('${f != null ? fmt.format(f) : '...'} — ${t != null ? fmt.format(t) : '...'}',
                      style: TextStyle(fontSize: 11, color: cs.primary));
                  })
                : null,
              selected: current == e.key,
              onTap: () {
                if (e.key == 'custom') {
                  Navigator.pop(context);
                  _showCustomDatePicker(context, ref);
                } else {
                  ref.read(_dateRange.notifier).state = e.key;
                  Navigator.pop(context);
                }
              },
            )),
          ]))),
        ]),
      ),
    );
  }

  // ── Custom date picker ──
  void _showCustomDatePicker(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: ref.read(_customFrom) ?? now.subtract(const Duration(days: 7)),
        end: ref.read(_customTo) ?? now,
      ),
      builder: (ctx, child) {
        final cs = Theme.of(ctx).colorScheme;
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: cs.copyWith(
              primary: cs.primary,
              onPrimary: cs.onPrimary,
              surface: cs.surface,
              onSurface: cs.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && context.mounted) {
      ref.read(_customFrom.notifier).state = picked.start;
      ref.read(_customTo.notifier).state = picked.end;
      ref.read(_dateRange.notifier).state = 'custom';
    }
  }

  // ── Sale detail sheet ──
  void _showSaleDetail(BuildContext context, WidgetRef ref, Map<String, dynamic> sale) {
    final cs = Theme.of(context).colorScheme;
    final cur = NumberFormat('#,##0.00');
    final items = (sale['items'] as List?) ?? [];
    final pmColor = _paymentColor(sale['payment_method']);
    final stColor = _statusColor(sale['status']);

    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.4,
        builder: (ctx, scrollCtrl) => Container(
          decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            // Header
            Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0), child: Column(children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Row(children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF3B82F6), size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(sale['transaction_number'] ?? '-', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(_fmtDate(sale['created_at']), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ])),
                IconButton(icon: const Icon(Icons.receipt_rounded, size: 20),
                  tooltip: 'View Receipt',
                  onPressed: () => _showReceipt(context, ref, sale)),
              ]),
              const SizedBox(height: 12), const Divider(height: 1),
            ])),

            // Body
            Expanded(child: ListView(controller: scrollCtrl, padding: const EdgeInsets.all(20), children: [
              // Status & Payment row
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: stColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(_cap(sale['status'] ?? ''), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: stColor))),
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: pmColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_paymentIcon(sale['payment_method']), size: 14, color: pmColor),
                    const SizedBox(width: 4),
                    Text(_cap(sale['payment_method'] ?? ''), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: pmColor)),
                  ])),
              ]),
              const SizedBox(height: 16),

              // Info rows
              _DetailRow(label: 'Customer', value: sale['customer_name'] ?? 'Walk-in'),
              if ((sale['customer_phone'] ?? '').toString().isNotEmpty)
                _DetailRow(label: 'Phone', value: sale['customer_phone']),
              _DetailRow(label: 'Cashier', value: _cashierName(sale)),
              if ((sale['payment_reference'] ?? '').toString().isNotEmpty)
                _DetailRow(label: 'Reference', value: sale['payment_reference']),
              const SizedBox(height: 16),

              // Items
              Text('Items (${items.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ...items.asMap().entries.map((e) {
                final it = e.value as Map;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Container(width: 32, height: 32, decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Center(child: Text('${e.key + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.primary)))),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(it['medication_name'] ?? '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('${it['quantity']} × ${cur.format(double.tryParse('${it['unit_price']}') ?? 0)}',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    ])),
                    Text(cur.format(double.tryParse('${it['total_price']}') ?? 0),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                );
              }),
              const SizedBox(height: 16),

              // Totals
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.1))),
                child: Column(children: [
                  _TotalRow(label: 'Subtotal', value: cur.format(double.tryParse('${sale['subtotal']}') ?? 0)),
                  if ((double.tryParse('${sale['tax']}') ?? 0) > 0)
                    _TotalRow(label: 'Tax', value: cur.format(double.tryParse('${sale['tax']}') ?? 0)),
                  if ((double.tryParse('${sale['discount']}') ?? 0) > 0)
                    _TotalRow(label: 'Discount', value: '-${cur.format(double.tryParse('${sale['discount']}') ?? 0)}', isDiscount: true),
                  const Divider(height: 16),
                  _TotalRow(label: 'Total', value: cur.format(double.tryParse('${sale['total']}') ?? 0), isBold: true),
                ]),
              ),
              const SizedBox(height: 20),
            ])),
          ]),
        ),
      ),
    );
  }

  // ── Receipt dialog ──
  void _showReceipt(BuildContext context, WidgetRef ref, Map<String, dynamic> sale) {
    final cs = Theme.of(context).colorScheme;
    final cur = NumberFormat('#,##0.00');
    final auth = ref.read(authProvider);
    final items = (sale['items'] as List?) ?? [];

    showDialog(context: context, builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Store name
          Icon(Icons.local_pharmacy_rounded, size: 32, color: cs.primary),
          const SizedBox(height: 8),
          Text(auth.user?.tenantName ?? 'AdhereMed', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Receipt', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const Divider(height: 20),

          // Meta
          _ReceiptLine('Receipt #', sale['transaction_number'] ?? '-'),
          _ReceiptLine('Date', _fmtDate(sale['created_at'])),
          _ReceiptLine('Cashier', _cashierName(sale)),
          if ((sale['customer_name'] ?? '').toString().isNotEmpty)
            _ReceiptLine('Customer', sale['customer_name']),
          const Divider(height: 20),

          // Items header
          Row(children: [
            const Expanded(flex: 4, child: Text('Item', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
            const Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
            const Expanded(flex: 2, child: Text('Total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
          ]),
          const Divider(height: 12),
          ...items.map((it) {
            final m = it as Map;
            return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
              Expanded(flex: 4, child: Text(m['medication_name'] ?? '-', style: const TextStyle(fontSize: 12))),
              Expanded(flex: 1, child: Text('${m['quantity']}', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text(cur.format(double.tryParse('${m['total_price']}') ?? 0),
                style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
            ]));
          }),
          const Divider(height: 20),

          // Totals
          _ReceiptLine('Subtotal', cur.format(double.tryParse('${sale['subtotal']}') ?? 0)),
          if ((double.tryParse('${sale['tax']}') ?? 0) > 0)
            _ReceiptLine('Tax', cur.format(double.tryParse('${sale['tax']}') ?? 0)),
          if ((double.tryParse('${sale['discount']}') ?? 0) > 0)
            _ReceiptLine('Discount', '-${cur.format(double.tryParse('${sale['discount']}') ?? 0)}'),
          const SizedBox(height: 4),
          Row(children: [
            const Expanded(child: Text('TOTAL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
            Text(cur.format(double.tryParse('${sale['total']}') ?? 0),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 4),
          _ReceiptLine('Payment', _cap(sale['payment_method'] ?? '')),
          const Divider(height: 20),
          Text('Thank you for your purchase!', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Close'),
          )),
        ])),
      ),
    ));
  }

  // ── CSV Export ──
  void _exportCsv(BuildContext context, List<Map<String, dynamic>> sales) {
    final cur = NumberFormat('#,##0.00');
    final buf = StringBuffer('Receipt #,Date,Customer,Phone,Cashier,Payment,Items,Subtotal,Tax,Discount,Total,Status\n');
    for (final s in sales) {
      final items = (s['items'] as List?) ?? [];
      final qty = items.fold<int>(0, (a, it) => a + (((it as Map)['quantity'] as num?)?.toInt() ?? 0).abs());
      buf.writeln([
        s['transaction_number'] ?? '',
        _fmtDate(s['created_at']),
        (s['customer_name'] ?? '').toString().replaceAll(',', ' '),
        s['customer_phone'] ?? '',
        _cashierName(s).replaceAll(',', ' '),
        s['payment_method'] ?? '',
        qty,
        s['subtotal'] ?? 0,
        s['tax'] ?? 0,
        s['discount'] ?? 0,
        s['total'] ?? 0,
        s['status'] ?? '',
      ].join(','));
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    _snack(context, 'CSV copied to clipboard (${sales.length} rows)', const Color(0xFF10B981));
  }

  // ── PDF Export ──
  void _exportPdf(BuildContext context, WidgetRef ref, List<Map<String, dynamic>> sales) async {
    final auth = ref.read(authProvider);
    final cur = NumberFormat('#,##0.00');

    // Load assets
    final pharmaLogo = await rootBundle.load('assets/images/hos_default.png');
    final adhereLogo = await rootBundle.load('assets/images/logo_nobg.png');
    final pharmaLogoImg = pw.MemoryImage(pharmaLogo.buffer.asUint8List());
    final adhereLogoImg = pw.MemoryImage(adhereLogo.buffer.asUint8List());

    // Pharmacy info (from auth user)
    final pharmaName = auth.user?.tenantName ?? auth.user?.tenantSchema ?? 'Pharmacy';
    final pharmaEmail = 'info@example.com';
    final pharmaLocation = 'Kenya';

    // KPI summary
    final completed = sales.where((s) => s['status'] == 'completed').toList();
    final voided = sales.where((s) => s['status'] == 'cancelled' || s['status'] == 'voided').length;
    final revenue = completed.fold<double>(0, (a, s) => a + (double.tryParse('${s['total']}') ?? 0));
    final discount = completed.fold<double>(0, (a, s) => a + (double.tryParse('${s['discount']}') ?? 0));
    final tax = completed.fold<double>(0, (a, s) => a + (double.tryParse('${s['tax']}') ?? 0));
    int totalItems = 0;
    for (final s in completed) {
      for (final it in (s['items'] as List? ?? [])) {
        totalItems += ((it as Map)['quantity'] as num?)?.toInt() ?? 0;
      }
    }
    final aov = completed.isNotEmpty ? revenue / completed.length : 0.0;

    final pdf = pw.Document();
    final dateRange = ref.read(_dateRange);
    final dateLabel = _dateRanges[dateRange] ?? 'All Time';
    final now = DateFormat('MMM dd, yyyy · HH:mm').format(DateTime.now());

    // Colors
    const primary = PdfColor.fromInt(0xFF1565C0);
    const primaryLight = PdfColor.fromInt(0xFFE3F2FD);
    const dark = PdfColor.fromInt(0xFF1A1A1A);
    const grey = PdfColor.fromInt(0xFF6B7280);
    const lightGrey = PdfColor.fromInt(0xFFF3F4F6);
    const success = PdfColor.fromInt(0xFF10B981);
    const danger = PdfColor.fromInt(0xFFEF4444);
    const white = PdfColors.white;

    // Chunk transactions for multi-page
    const rowsPerPage = 28;
    final chunks = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < sales.length; i += rowsPerPage) {
      chunks.add(sales.sublist(i, (i + rowsPerPage).clamp(0, sales.length)));
    }
    if (chunks.isEmpty) chunks.add([]);

    for (var pageIdx = 0; pageIdx < chunks.length; pageIdx++) {
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) {
          final children = <pw.Widget>[];

          // ── Header (first page only) ──
          if (pageIdx == 0) {
            children.add(pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left: Pharmacy
                pw.Expanded(child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 48, height: 48,
                      child: pw.Image(pharmaLogoImg, fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('$pharmaName', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: dark)),
                        pw.SizedBox(height: 2),
                        pw.Text('$pharmaEmail', style: const pw.TextStyle(fontSize: 9, color: grey)),
                        pw.Text('$pharmaLocation', style: const pw.TextStyle(fontSize: 9, color: grey)),
                      ],
                    ),
                  ],
                )),
                // Right: AdhereMed
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('AdhereMed', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primary)),
                        pw.SizedBox(height: 2),
                        pw.Text('info@adheremed.org', style: const pw.TextStyle(fontSize: 9, color: grey)),
                        pw.Text('Kenya', style: const pw.TextStyle(fontSize: 9, color: grey)),
                      ],
                    ),
                    pw.SizedBox(width: 10),
                    pw.Container(
                      width: 48, height: 48,
                      child: pw.Image(adhereLogoImg, fit: pw.BoxFit.contain),
                    ),
                  ],
                ),
              ],
            ));

            children.add(pw.SizedBox(height: 16));
            children.add(pw.Container(height: 2, color: primary));
            children.add(pw.SizedBox(height: 16));

            // Title
            children.add(pw.Center(child: pw.Text('Sales Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: dark))));
            children.add(pw.SizedBox(height: 4));
            children.add(pw.Center(child: pw.Text('Period: $dateLabel  •  Generated: $now', style: const pw.TextStyle(fontSize: 9, color: grey))));
            children.add(pw.SizedBox(height: 16));

            // Summary cards
            children.add(pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: primaryLight,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(children: [
                _pdfSummaryCell('Transactions', '${sales.length}', '${completed.length} completed'),
                _pdfSummaryCell('Net Revenue', cur.format(revenue), 'Tax: ${cur.format(tax)}'),
                _pdfSummaryCell('Items Sold', '$totalItems', 'Discount: ${cur.format(discount)}'),
                _pdfSummaryCell('Avg Order', cur.format(aov), '$voided voided'),
              ]),
            ));
            children.add(pw.SizedBox(height: 16));
          } else {
            // Continuation header
            children.add(pw.Row(children: [
              pw.Text('Sales Report (cont.)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: dark)),
              pw.Spacer(),
              pw.Text('$pharmaName', style: const pw.TextStyle(fontSize: 9, color: grey)),
            ]));
            children.add(pw.SizedBox(height: 8));
          }

          // ── Table ──
          final chunk = chunks[pageIdx];
          final startRow = pageIdx * rowsPerPage;
          children.add(pw.TableHelper.fromTextArray(
            context: ctx,
            headerAlignment: pw.Alignment.centerLeft,
            cellAlignment: pw.Alignment.centerLeft,
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: white),
            cellStyle: const pw.TextStyle(fontSize: 7.5, color: dark),
            headerDecoration: const pw.BoxDecoration(color: primary),
            headerPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            oddRowDecoration: const pw.BoxDecoration(color: lightGrey),
            headers: ['#', 'Date', 'Receipt #', 'Customer', 'Payment', 'Items', 'Total', 'Status'],
            data: chunk.asMap().entries.map((e) {
              final i = startRow + e.key + 1;
              final s = e.value;
              final items = (s['items'] as List?) ?? [];
              final qty = items.fold<int>(0, (a, it) => a + (((it as Map)['quantity'] as num?)?.toInt() ?? 0));
              return [
                '$i',
                _fmtDateShort(s['created_at']),
                s['transaction_number'] ?? '-',
                (s['customer_name'] ?? '').toString().isNotEmpty ? s['customer_name'] : 'Walk-in',
                _cap(s['payment_method'] ?? ''),
                '$qty',
                cur.format(double.tryParse('${s['total']}') ?? 0),
                _cap(s['status'] ?? ''),
              ];
            }).toList(),
          ));

          // Footer
          children.add(pw.Spacer());
          children.add(pw.Divider(color: grey, thickness: 0.5));
          children.add(pw.SizedBox(height: 4));
          children.add(pw.Row(children: [
            pw.Text('Generated by AdhereMed', style: const pw.TextStyle(fontSize: 8, color: grey)),
            pw.Spacer(),
            pw.Text('Page ${pageIdx + 1} of ${chunks.length}', style: const pw.TextStyle(fontSize: 8, color: grey)),
          ]));

          return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children);
        },
      ));
    }

    if (!context.mounted) return;
    await Printing.layoutPdf(onLayout: (_) => pdf.save(), name: 'Sales_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');
  }

  static pw.Widget _pdfSummaryCell(String title, String value, String sub) {
    const dark = PdfColor.fromInt(0xFF1A1A1A);
    const grey = PdfColor.fromInt(0xFF6B7280);
    const primary = PdfColor.fromInt(0xFF1565C0);
    return pw.Expanded(child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 8, color: grey)),
        pw.SizedBox(height: 3),
        pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: primary)),
        pw.SizedBox(height: 2),
        pw.Text(sub, style: const pw.TextStyle(fontSize: 7, color: grey)),
      ],
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.icon, required this.color, required this.title, required this.value, required this.sub});
  final IconData icon; final Color color; final String title, value, sub;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 160, padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color)),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant))),
        ]),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(sub, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({required this.sale, required this.onTap});
  final Map<String, dynamic> sale; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cur = NumberFormat('#,##0.00');
    final pm = sale['payment_method']?.toString();
    final st = sale['status']?.toString();
    final pmColor = _paymentColor(pm);
    final stColor = _statusColor(st);
    final items = (sale['items'] as List?) ?? [];
    final qty = items.fold<int>(0, (a, it) => a + (((it as Map)['quantity'] as num?)?.toInt() ?? 0));
    final total = double.tryParse('${sale['total']}') ?? 0;

    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4))),
          child: Column(children: [
            // Color band
            Container(height: 3, decoration: BoxDecoration(
              color: stColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(14)))),
            Padding(padding: const EdgeInsets.all(14), child: Column(children: [
              // Top row: receipt # + date
              Row(children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF3B82F6))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(sale['transaction_number'] ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(_fmtDate(sale['created_at']), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(cur.format(total), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  Text('$qty items', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ]),
              ]),
              const SizedBox(height: 10),

              // Bottom row: customer + chips
              Row(children: [
                Icon(Icons.person_rounded, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(child: Text(
                  (sale['customer_name'] ?? '').toString().isNotEmpty ? sale['customer_name'] : 'Walk-in',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
                // Payment chip
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: pmColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_paymentIcon(pm), size: 12, color: pmColor),
                    const SizedBox(width: 3),
                    Text(_cap(pm ?? ''), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: pmColor)),
                  ])),
                const SizedBox(width: 6),
                // Status chip
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: stColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(_cap(st ?? ''), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: stColor))),
              ]),
            ])),
          ]),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.icon, required this.isActive, required this.onTap});
  final String label; final IconData icon; final bool isActive; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? cs.primary.withValues(alpha: 0.1) : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? cs.primary.withValues(alpha: 0.3) : Colors.transparent)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: isActive ? cs.primary : cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isActive ? cs.primary : cs.onSurfaceVariant)),
          if (isActive) ...[
            const SizedBox(width: 4),
            Icon(Icons.check_circle_rounded, size: 14, color: cs.primary),
          ],
        ]),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label; final dynamic value;
  @override Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
      SizedBox(width: 90, child: Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500))),
      Expanded(child: Text('$value', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
    ]));
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value, this.isBold = false, this.isDiscount = false});
  final String label; final String value; final bool isBold; final bool isDiscount;
  @override Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontSize: isBold ? 14 : 12,
        fontWeight: isBold ? FontWeight.w800 : FontWeight.w500, color: isBold ? cs.onSurface : cs.onSurfaceVariant))),
      Text(value, style: TextStyle(fontSize: isBold ? 14 : 12,
        fontWeight: isBold ? FontWeight.w800 : FontWeight.w600, color: isDiscount ? const Color(0xFF10B981) : cs.onSurface)),
    ]));
  }
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine(this.label, this.value);
  final String label; final String value;
  @override Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ]));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════════════════════════
String _cap(String s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}';

String _fmtDate(dynamic d) {
  if (d == null) return '-';
  final dt = DateTime.tryParse(d.toString());
  if (dt == null) return d.toString();
  return DateFormat('MMM dd, yyyy · HH:mm').format(dt.toLocal());
}

String _fmtDateShort(dynamic d) {
  if (d == null) return '-';
  final dt = DateTime.tryParse(d.toString());
  if (dt == null) return d.toString();
  return DateFormat('dd/MM/yy HH:mm').format(dt.toLocal());
}

String _cashierName(Map s) {
  final name = s['cashier_name'];
  if (name != null && name.toString().trim().isNotEmpty) return name.toString().trim();
  final cashier = s['cashier'];
  if (cashier is Map) {
    final fn = cashier['first_name'] ?? '';
    final ln = cashier['last_name'] ?? '';
    if (fn.toString().isNotEmpty || ln.toString().isNotEmpty) return '$fn $ln'.trim();
    return cashier['email']?.toString() ?? '-';
  }
  return '-';
}

void _snack(BuildContext c, String m, Color co) =>
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating, backgroundColor: co));
