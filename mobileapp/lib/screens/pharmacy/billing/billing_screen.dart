import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../core/api.dart';
import '../../../widgets/common.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

// ── Usage ──
final _usageDashProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/usage-billing/dashboard/');
  return res.data as Map<String, dynamic>;
});

final _usageRangePresetProvider = StateProvider<String>((ref) => 'this_month');
final _customStartProvider = StateProvider<DateTime?>((ref) => null);
final _customEndProvider = StateProvider<DateTime?>((ref) => null);

final _usageRangeProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final preset = ref.watch(_usageRangePresetProvider);
  final params = <String, dynamic>{};
  if (preset == 'custom') {
    final s = ref.watch(_customStartProvider);
    final e = ref.watch(_customEndProvider);
    if (s != null && e != null) {
      params['start'] = DateFormat('yyyy-MM-dd').format(s);
      params['end'] = DateFormat('yyyy-MM-dd').format(e);
    } else {
      params['preset'] = 'this_month';
    }
  } else {
    params['preset'] = preset;
  }
  final res = await dio.get('/usage-billing/range/', queryParameters: params);
  return res.data as Map<String, dynamic>;
});

// ── Invoices ──
final _invSearchProvider = StateProvider<String>((ref) => '');
final _invStatusProvider = StateProvider<String>((ref) => '');
final _invSortProvider = StateProvider<String>((ref) => '-created_at');

final _invoicesProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final params = <String, dynamic>{'page_size': 200};
  final st = ref.watch(_invStatusProvider);
  if (st.isNotEmpty) params['status'] = st;
  params['ordering'] = ref.watch(_invSortProvider);
  final res = await dio.get('/billing/invoices/', queryParameters: params);
  final items = (res.data['results'] as List?) ?? (res.data is List ? res.data as List : []);
  final q = ref.watch(_invSearchProvider).toLowerCase();
  if (q.isEmpty) return items;
  return items.where((inv) =>
    '${inv['invoice_number'] ?? ''}'.toLowerCase().contains(q) ||
    '${inv['patient_name'] ?? ''}'.toLowerCase().contains(q)
  ).toList();
});

// ── Payments ──
final _paySearchProvider = StateProvider<String>((ref) => '');
final _payMethodProvider = StateProvider<String>((ref) => '');

final _paymentsProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final params = <String, dynamic>{'page_size': 200, 'ordering': '-paid_at'};
  final m = ref.watch(_payMethodProvider);
  if (m.isNotEmpty) params['method'] = m;
  final res = await dio.get('/billing/payments/', queryParameters: params);
  final items = (res.data['results'] as List?) ?? (res.data is List ? res.data as List : []);
  final q = ref.watch(_paySearchProvider).toLowerCase();
  if (q.isEmpty) return items;
  return items.where((p) =>
    '${p['reference'] ?? ''}'.toLowerCase().contains(q) ||
    '${p['invoice_number'] ?? ''}'.toLowerCase().contains(q)
  ).toList();
});

// ── Patient search (for invoice form) ──
final _patientQueryProvider = StateProvider<String>((ref) => '');
final _patientSearchProvider = FutureProvider.autoDispose((ref) async {
  final q = ref.watch(_patientQueryProvider);
  if (q.length < 2) return <dynamic>[];
  final dio = ref.read(dioProvider);
  final res = await dio.get('/patients/', queryParameters: {'search': q, 'page_size': 15});
  return (res.data['results'] as List?) ?? [];
});

// ═══════════════════════════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════════════════════════
const _invStatuses = ['draft', 'sent', 'partially_paid', 'paid', 'overdue', 'cancelled'];
const _invStatusLabels = {
  'draft': 'Draft', 'sent': 'Sent', 'paid': 'Paid',
  'partially_paid': 'Partial', 'overdue': 'Overdue', 'cancelled': 'Cancelled',
};

Color _statusColor(String s) => switch (s) {
  'draft' => const Color(0xFF94A3B8),
  'sent' => const Color(0xFF3B82F6),
  'paid' => const Color(0xFF10B981),
  'partially_paid' => const Color(0xFFF59E0B),
  'overdue' => const Color(0xFFEF4444),
  'cancelled' => const Color(0xFF6B7280),
  _ => const Color(0xFF94A3B8),
};

IconData _statusIcon(String s) => switch (s) {
  'draft' => Icons.edit_note_rounded,
  'sent' => Icons.send_rounded,
  'paid' => Icons.check_circle_rounded,
  'partially_paid' => Icons.timelapse_rounded,
  'overdue' => Icons.warning_amber_rounded,
  'cancelled' => Icons.cancel_rounded,
  _ => Icons.receipt_long_rounded,
};

const _payMethods = ['cash', 'mpesa', 'card', 'bank_transfer', 'insurance'];
const _payMethodLabels = {
  'cash': 'Cash', 'mpesa': 'M-Pesa', 'card': 'Card',
  'bank_transfer': 'Bank Transfer', 'insurance': 'Insurance',
};

Color _methodColor(String m) => switch (m) {
  'cash' => const Color(0xFF10B981),
  'mpesa' => const Color(0xFF22C55E),
  'card' => const Color(0xFF6366F1),
  'bank_transfer' => const Color(0xFF3B82F6),
  'insurance' => const Color(0xFF8B5CF6),
  _ => const Color(0xFF94A3B8),
};

IconData _methodIcon(String m) => switch (m) {
  'cash' => Icons.payments_rounded,
  'mpesa' => Icons.phone_android_rounded,
  'card' => Icons.credit_card_rounded,
  'bank_transfer' => Icons.account_balance_rounded,
  'insurance' => Icons.shield_rounded,
  _ => Icons.payment_rounded,
};

String _fmtDate(String? d) {
  if (d == null || d.isEmpty) return '';
  try { return DateFormat('MMM d, yyyy').format(DateTime.parse(d)); } catch (_) { return d; }
}

String _fmtDateShort(DateTime? d) {
  if (d == null) return '...';
  return DateFormat('MMM d').format(d);
}

String _fmtDateTime(String? d) {
  if (d == null || d.isEmpty) return '';
  try { return DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(d)); } catch (_) { return d; }
}

String _fmtMoney(dynamic v) {
  if (v == null) return '0.00';
  final n = double.tryParse(v.toString()) ?? 0;
  return NumberFormat('#,##0.00').format(n);
}

String _fmtNum(dynamic v) {
  if (v == null) return '0';
  final n = int.tryParse(v.toString()) ?? 0;
  return NumberFormat('#,##0').format(n);
}

String _fmtNumAny(dynamic v) {
  if (v == null) return '0';
  final n = double.tryParse(v.toString()) ?? 0;
  return n == n.roundToDouble()
      ? NumberFormat('#,##0').format(n.toInt())
      : NumberFormat('#,##0.#').format(n);
}

const _rangePresets = [
  ('today', 'Today'),
  ('yesterday', 'Yesterday'),
  ('last_7_days', '7 Days'),
  ('last_14_days', '14 Days'),
  ('last_30_days', '30 Days'),
  ('this_month', 'This Month'),
  ('last_month', 'Last Month'),
  ('this_year', 'This Year'),
];

// ═══════════════════════════════════════════════════════════════════════════
//  MAIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});
  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> with TickerProviderStateMixin {
  late final TabController _tabCtrl;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) setState(() => _currentTab = _tabCtrl.index);
    });
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Billing', style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(text: 'Usage'),
            Tab(text: 'Invoices'),
            Tab(text: 'Payments'),
          ],
        ),
      ),
      floatingActionButton: _currentTab == 1
          ? FloatingActionButton.extended(
              onPressed: () => _showInvoiceForm(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Invoice'),
            )
          : null,
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _UsageTab(),
          _InvoicesTab(),
          _PaymentsTab(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 1: USAGE DASHBOARD
// ═══════════════════════════════════════════════════════════════════════════
class _UsageTab extends ConsumerWidget {
  const _UsageTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final dash = ref.watch(_usageDashProvider);
    final range = ref.watch(_usageRangeProvider);
    final preset = ref.watch(_usageRangePresetProvider);

    return RefreshIndicator(
      onRefresh: () async { ref.invalidate(_usageDashProvider); ref.invalidate(_usageRangeProvider); },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          // ── Hero card ──
          dash.when(
            loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => ErrorRetry(message: 'Failed to load usage', onRetry: () => ref.invalidate(_usageDashProvider)),
            data: (d) {
              final cm = d['current_month'] as Map? ?? {};
              final cmp = d['comparison'] as Map? ?? {};
              final requests = cm['total_requests'] ?? d['current_month_requests'] ?? 0;
              final cost = cm['cost_so_far'] ?? d['estimated_cost'] ?? 0;
              final projected = cm['projected_cost'] ?? d['projected_cost'] ?? cost;
              final rate = d['rate'] ?? d['rate_per_1000'];
              final rateInfo = rate is Map
                  ? '${rate['requests_per_unit'] ?? 1000} req = KSH ${rate['unit_cost'] ?? '1.00'}'
                  : 'KSH ${rate ?? 'N/A'} / 1000 req';
              final todayReq = cmp['today_requests'] ?? d['today_requests'] ?? 0;
              final yesterdayReq = cmp['yesterday_requests'] ?? d['yesterday_requests'] ?? 0;
              final avg7 = cmp['trailing_7d_average'] ?? cmp['trailing_7_day_avg'] ?? d['avg_7_day'] ?? 0;

              return Column(children: [
                // ── Main hero ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.primary, cs.primary.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.api_rounded, size: 32, color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    Text(_fmtNum(requests),
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
                    const SizedBox(height: 4),
                    Text('Requests This Month',
                      style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w500)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12)),
                      child: Text(rateInfo,
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),

                const SizedBox(height: 16),

                // ── KPI row ──
                _KpiRow(items: [
                  _Kpi('Cost So Far', 0, const Color(0xFF10B981), money: 'KSH ${_fmtMoney(cost)}'),
                  _Kpi('Projected', 0, const Color(0xFF6366F1), money: 'KSH ${_fmtMoney(projected)}'),
                  _Kpi("Today's", (todayReq is int ? todayReq : int.tryParse('$todayReq') ?? 0), const Color(0xFF3B82F6)),
                  _Kpi('7-Day Avg', (avg7 is int ? avg7 : int.tryParse('$avg7') ?? 0), const Color(0xFFF59E0B)),
                ]),

                const SizedBox(height: 12),

                // ── Comparison tiles ──
                Row(children: [
                  Expanded(child: _ComparisonTile(
                    label: 'Today vs Yesterday',
                    current: todayReq is int ? todayReq : int.tryParse('$todayReq') ?? 0,
                    previous: yesterdayReq is int ? yesterdayReq : int.tryParse('$yesterdayReq') ?? 0,
                  )),
                ]).animate().fadeIn(duration: 400.ms, delay: 200.ms),

                const SizedBox(height: 16),

                // ── Recent bills ──
                if ((d['recent_bills'] as List?)?.isNotEmpty ?? false) ...[
                  Row(children: [
                    Icon(Icons.receipt_long_rounded, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    const Text('Recent Bills', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 10),
                  ...(d['recent_bills'] as List).map((b) => _RecentBillTile(bill: b)),
                ],
              ]);
            },
          ),

          const SizedBox(height: 20),

          // ── Range filter ──
          Row(children: [
            Icon(Icons.date_range_rounded, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            const Text('Usage Range', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._rangePresets.map((p) {
                  final sel = preset == p.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(p.$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: sel ? cs.onPrimary : cs.onSurfaceVariant)),
                      selected: sel,
                      selectedColor: cs.primary,
                      backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => ref.read(_usageRangePresetProvider.notifier).state = p.$1,
                    ),
                  );
                }),
                // ── Custom date range chip ──
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    avatar: preset == 'custom' ? null : Icon(Icons.edit_calendar_rounded, size: 14, color: cs.onSurfaceVariant),
                    label: Text(
                      preset == 'custom'
                          ? '${_fmtDateShort(ref.watch(_customStartProvider))} – ${_fmtDateShort(ref.watch(_customEndProvider))}'
                          : 'Custom',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: preset == 'custom' ? cs.onPrimary : cs.onSurfaceVariant)),
                    selected: preset == 'custom',
                    selectedColor: cs.primary,
                    backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) async {
                      final now = DateTime.now();
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: now.subtract(const Duration(days: 730)),
                        lastDate: now,
                        initialDateRange: DateTimeRange(
                          start: ref.read(_customStartProvider) ?? now.subtract(const Duration(days: 30)),
                          end: ref.read(_customEndProvider) ?? now,
                        ),
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: cs.copyWith(onPrimary: Colors.white),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        ref.read(_customStartProvider.notifier).state = picked.start;
                        ref.read(_customEndProvider.notifier).state = picked.end;
                        ref.read(_usageRangePresetProvider.notifier).state = 'custom';
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Selected range title ──
          Builder(builder: (_) {
            final String title;
            if (preset == 'custom') {
              final s = ref.watch(_customStartProvider);
              final e = ref.watch(_customEndProvider);
              title = '${_fmtDateShort(s)} – ${_fmtDateShort(e)}';
            } else {
              title = _rangePresets.where((p) => p.$1 == preset).firstOrNull?.$2 ?? preset;
            }
            final start = range.valueOrNull?['start']?.toString();
            final end = range.valueOrNull?['end']?.toString();
            final days = range.valueOrNull?['days'];
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
              ),
              child: Row(children: [
                Icon(Icons.date_range_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.primary)),
                  if (start != null && end != null)
                    Text('${_fmtDate(start)} → ${_fmtDate(end)}${days != null ? '  •  $days days' : ''}',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ])),
              ]),
            );
          }),

          const SizedBox(height: 14),

          // ── Range data ──
          range.when(
            loading: () => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const SizedBox.shrink(),
            data: (r) {
              final totalReq = r['total_requests'] ?? 0;
              final dailyAvg = r['daily_average'] ?? 0;
              final rangeCost = r['cost'] ?? r['total_cost'] ?? 0;
              final peak = r['peak_day'] ?? r['peak'];
              final daily = (r['daily'] as List?) ?? (r['daily_breakdown'] as List?) ?? [];

              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Summary tiles
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: _RangeStat(label: 'Total Requests', value: _fmtNum(totalReq), color: const Color(0xFF3B82F6))),
                      Expanded(child: _RangeStat(label: 'Daily Average', value: _fmtNumAny(dailyAvg), color: const Color(0xFF8B5CF6))),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _RangeStat(label: 'Cost', value: 'KSH ${_fmtMoney(rangeCost)}', color: const Color(0xFF10B981))),
                      Expanded(child: _RangeStat(
                        label: 'Peak Day',
                        value: peak is Map ? '${_fmtNumAny(peak['request_count'] ?? peak['count'])} on ${_fmtDate(peak['date']?.toString())}' : '${peak ?? 'N/A'}',
                        color: const Color(0xFFF59E0B),
                      )),
                    ]),
                  ]),
                ).animate().fadeIn(duration: 300.ms),

                // ── Mini bar chart (daily breakdown) ──
                if (daily.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(children: [
                    const Icon(Icons.bar_chart_rounded, size: 18, color: Color(0xFF6366F1)),
                    const SizedBox(width: 8),
                    const Text('Daily Distribution', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 120,
                    child: _MiniBarChart(data: daily),
                  ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                ],
              ]);
            },
          ),
        ],
      ),
    );
  }
}

// ── Mini bar chart ──
class _MiniBarChart extends StatelessWidget {
  const _MiniBarChart({required this.data});
  final List data;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (data.isEmpty) return const SizedBox.shrink();
    int maxVal = 1;
    for (final d in data) {
      final v = d['request_count'] ?? d['count'] ?? 0;
      if (v is int && v > maxVal) maxVal = v;
    }
    // Show max 30 bars to avoid cramming
    final display = data.length > 30 ? data.sublist(data.length - 30) : data;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: display.asMap().entries.map((e) {
        final d = e.value;
        final v = d['request_count'] ?? d['count'] ?? 0;
        final pct = (v is int ? v : 0) / maxVal;
        final date = d['date']?.toString() ?? '';
        return Expanded(
          child: Tooltip(
            message: '${_fmtDate(date)}: ${_fmtNum(v)}',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Container(
                height: (pct * 100).clamp(4, 100).toDouble(),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.3 + pct * 0.7),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Comparison tile ──
class _ComparisonTile extends StatelessWidget {
  const _ComparisonTile({required this.label, required this.current, required this.previous});
  final String label;
  final int current;
  final int previous;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final diff = previous > 0 ? ((current - previous) / previous * 100) : 0.0;
    final isUp = diff > 0;
    final diffColor = isUp ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(children: [
            Text(_fmtNum(current), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
            Text('vs ${_fmtNum(previous)}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ]),
        ])),
        if (previous > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: diffColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 14, color: diffColor),
              const SizedBox(width: 2),
              Text('${diff.abs().toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: diffColor)),
            ]),
          ),
      ]),
    );
  }
}

// ── Recent bill tile ──
class _RecentBillTile extends StatelessWidget {
  const _RecentBillTile({required this.bill});
  final dynamic bill;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = '${bill['status'] ?? 'DRAFT'}'.toLowerCase();
    final sc = status == 'paid' ? const Color(0xFF10B981) : status == 'issued' ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.receipt_rounded, size: 18, color: sc),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${bill['month_name'] ?? ''} ${bill['year'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text('${_fmtNum(bill['total_requests'])} requests',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('KSH ${_fmtMoney(bill['amount'])}',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: sc)),
          _StatusChip(label: status.toUpperCase(), color: sc),
        ]),
      ]),
    );
  }
}

// ── Range stat ──
class _RangeStat extends StatelessWidget {
  const _RangeStat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
      textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
      textAlign: TextAlign.center),
  ]);
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 2: INVOICES
// ═══════════════════════════════════════════════════════════════════════════
class _InvoicesTab extends ConsumerStatefulWidget {
  const _InvoicesTab();
  @override
  ConsumerState<_InvoicesTab> createState() => _InvoicesTabState();
}

class _InvoicesTabState extends ConsumerState<_InvoicesTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  Timer? _debounce;

  @override
  void dispose() { _debounce?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final data = ref.watch(_invoicesProvider);
    final statusFilter = ref.watch(_invStatusProvider);

    return Column(children: [
      // ── Stats ──
      data.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (items) {
          double totalIssued = 0, totalPaid = 0, totalOutstanding = 0, totalOverdue = 0;
          for (final inv in items) {
            final total = double.tryParse('${inv['total'] ?? 0}') ?? 0;
            final paid = double.tryParse('${inv['amount_paid'] ?? 0}') ?? 0;
            final bal = double.tryParse('${inv['balance'] ?? 0}') ?? (total - paid);
            totalIssued += total;
            totalPaid += paid;
            if (bal > 0) totalOutstanding += bal;
            if (inv['status'] == 'overdue') totalOverdue += bal;
          }
          return _KpiRow(items: [
            _Kpi('Issued', 0, const Color(0xFF6366F1), money: _fmtMoney(totalIssued)),
            _Kpi('Collected', 0, const Color(0xFF10B981), money: _fmtMoney(totalPaid)),
            _Kpi('Outstanding', 0, const Color(0xFFF59E0B), money: _fmtMoney(totalOutstanding)),
            _Kpi('Overdue', 0, const Color(0xFFEF4444), money: _fmtMoney(totalOverdue)),
          ]);
        },
      ),

      // ── Search + filters ──
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Row(children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search invoices...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true, filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () => ref.read(_invSearchProvider.notifier).state = v);
              },
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Badge(
              isLabelVisible: statusFilter.isNotEmpty,
              child: Icon(Icons.filter_list_rounded, color: statusFilter.isNotEmpty ? cs.primary : null),
            ),
            onSelected: (v) => ref.read(_invStatusProvider.notifier).state = v,
            itemBuilder: (_) => [
              const PopupMenuItem(value: '', child: Text('All Statuses')),
              ..._invStatuses.map((s) => PopupMenuItem(
                value: s,
                child: Row(children: [
                  Icon(_statusIcon(s), size: 16, color: _statusColor(s)),
                  const SizedBox(width: 8),
                  Text(_invStatusLabels[s] ?? s),
                ]),
              )),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded, size: 22),
            onSelected: (v) => ref.read(_invSortProvider.notifier).state = v,
            itemBuilder: (_) => const [
              PopupMenuItem(value: '-created_at', child: Text('Newest First')),
              PopupMenuItem(value: 'created_at', child: Text('Oldest First')),
              PopupMenuItem(value: '-total', child: Text('Total ↓')),
              PopupMenuItem(value: 'due_date', child: Text('Due Date')),
            ],
          ),
        ]),
      ),
      const SizedBox(height: 4),
      const Divider(height: 1),

      Expanded(
        child: data.when(
          loading: () => const LoadingShimmer(),
          error: (e, _) => ErrorRetry(message: 'Failed to load invoices', onRetry: () => ref.invalidate(_invoicesProvider)),
          data: (items) {
            if (items.isEmpty) return const EmptyState(icon: Icons.receipt_long_rounded, title: 'No invoices found');
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(_invoicesProvider),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: items.length,
                itemBuilder: (_, i) => _InvoiceCard(inv: items[i], ref: ref)
                  .animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: (40 * i).clamp(0, 400))).slideY(begin: 0.05, end: 0),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ── Invoice Card ──
class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.inv, required this.ref});
  final dynamic inv;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = inv['status'] ?? 'draft';
    final sc = _statusColor(status);
    final total = double.tryParse('${inv['total'] ?? 0}') ?? 0;
    final paid = double.tryParse('${inv['amount_paid'] ?? 0}') ?? 0;
    final balance = double.tryParse('${inv['balance'] ?? 0}') ?? (total - paid);
    final dueDate = inv['due_date']?.toString();
    final isOverdue = status == 'overdue' || (dueDate != null && DateTime.tryParse(dueDate)?.isBefore(DateTime.now()) == true && balance > 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showInvoiceDetail(context, inv, ref),
        onLongPress: () => _showInvoiceActions(context, inv, ref),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(children: [
            Container(
              width: 5, height: 120,
              decoration: BoxDecoration(
                color: sc,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Icon(_statusIcon(status), color: sc, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(inv['invoice_number'] ?? '#${inv['id']}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(inv['patient_name'] ?? 'N/A',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    ])),
                    _StatusChip(label: _invStatusLabels[status] ?? status, color: sc),
                  ]),
                  const SizedBox(height: 10),
                  // financial row
                  Row(children: [
                    _MoneyLabel(label: 'Total', amount: inv['total'], color: const Color(0xFF3B82F6)),
                    const SizedBox(width: 12),
                    _MoneyLabel(label: 'Paid', amount: inv['amount_paid'], color: const Color(0xFF10B981)),
                    const SizedBox(width: 12),
                    _MoneyLabel(label: 'Balance', amount: balance, color: balance > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    if (dueDate != null) ...[
                      Icon(Icons.calendar_today_rounded, size: 12, color: isOverdue ? const Color(0xFFEF4444) : cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('Due: ${_fmtDate(dueDate)}',
                        style: TextStyle(fontSize: 11, color: isOverdue ? const Color(0xFFEF4444) : cs.onSurfaceVariant,
                          fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w400)),
                    ],
                    const Spacer(),
                    if (balance > 0)
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _showRecordPaymentDialog(context, ref, inv),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.add_card_rounded, size: 14, color: Color(0xFF10B981)),
                            SizedBox(width: 4),
                            Text('Pay', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                          ]),
                        ),
                      ),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 3: PAYMENTS
// ═══════════════════════════════════════════════════════════════════════════
class _PaymentsTab extends ConsumerStatefulWidget {
  const _PaymentsTab();
  @override
  ConsumerState<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends ConsumerState<_PaymentsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  Timer? _debounce;

  @override
  void dispose() { _debounce?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final data = ref.watch(_paymentsProvider);
    final methodFilter = ref.watch(_payMethodProvider);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search payments...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true, filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () => ref.read(_paySearchProvider.notifier).state = v);
              },
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Badge(
              isLabelVisible: methodFilter.isNotEmpty,
              child: Icon(Icons.filter_list_rounded, color: methodFilter.isNotEmpty ? cs.primary : null),
            ),
            onSelected: (v) => ref.read(_payMethodProvider.notifier).state = v,
            itemBuilder: (_) => [
              const PopupMenuItem(value: '', child: Text('All Methods')),
              ..._payMethods.map((m) => PopupMenuItem(
                value: m,
                child: Row(children: [
                  Icon(_methodIcon(m), size: 16, color: _methodColor(m)),
                  const SizedBox(width: 8),
                  Text(_payMethodLabels[m] ?? m),
                ]),
              )),
            ],
          ),
        ]),
      ),
      const SizedBox(height: 8),
      const Divider(height: 1),
      Expanded(
        child: data.when(
          loading: () => const LoadingShimmer(),
          error: (e, _) => ErrorRetry(message: 'Failed to load payments', onRetry: () => ref.invalidate(_paymentsProvider)),
          data: (items) {
            if (items.isEmpty) return const EmptyState(icon: Icons.payments_rounded, title: 'No payments found');
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(_paymentsProvider),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: items.length,
                itemBuilder: (_, i) => _PaymentCard(payment: items[i])
                  .animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: (40 * i).clamp(0, 400))).slideY(begin: 0.05, end: 0),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ── Payment Card ──
class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});
  final dynamic payment;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final method = payment['method'] ?? 'cash';
    final mc = _methodColor(method);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: mc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(_methodIcon(method), color: mc, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('KSH ${_fmtMoney(payment['amount'])}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 2),
            Row(children: [
              _StatusChip(label: _payMethodLabels[method] ?? method, color: mc),
              if ((payment['reference'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(child: Text('Ref: ${payment['reference']}',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ]),
            const SizedBox(height: 4),
            Row(children: [
              if ((payment['invoice_number'] ?? '').toString().isNotEmpty)
                Text('${payment['invoice_number']}',
                  style: TextStyle(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(_fmtDateTime(payment['paid_at']?.toString()),
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ]),
            if ((payment['received_by_name'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('by ${payment['received_by_name']}',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ),
          ])),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  INVOICE DETAIL
// ═══════════════════════════════════════════════════════════════════════════
void _showInvoiceDetail(BuildContext context, dynamic inv, WidgetRef ref) {
  final cs = Theme.of(context).colorScheme;
  final status = inv['status'] ?? 'draft';
  final sc = _statusColor(status);
  final items = (inv['items'] as List?) ?? [];
  final payments = (inv['payments'] as List?) ?? [];
  final balance = double.tryParse('${inv['balance'] ?? 0}') ?? 0;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: ListView(
          controller: scrollCtrl,
          padding: EdgeInsets.zero,
          children: [
            // ── Hero ──
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [sc.withValues(alpha: 0.15), sc.withValues(alpha: 0.03)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(_statusIcon(status), size: 32, color: sc)),
                const SizedBox(height: 12),
                Text(inv['invoice_number'] ?? 'Invoice #${inv['id']}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: cs.onSurface)),
                const SizedBox(height: 6),
                _StatusChip(label: _invStatusLabels[status] ?? status, color: sc),
              ]),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _InfoTile(icon: Icons.person_rounded, label: 'Patient', value: inv['patient_name'] ?? 'N/A'),
                _InfoTile(icon: Icons.calendar_today_rounded, label: 'Created', value: _fmtDateTime(inv['created_at']?.toString())),
                if (inv['due_date'] != null)
                  _InfoTile(icon: Icons.event_rounded, label: 'Due Date', value: _fmtDate(inv['due_date']?.toString())),

                // ── Financial breakdown ──
                const SizedBox(height: 8),
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Column(children: [
                    _FinRow(label: 'Subtotal', value: inv['subtotal']),
                    if ((double.tryParse('${inv['tax'] ?? 0}') ?? 0) > 0)
                      _FinRow(label: 'Tax', value: inv['tax']),
                    if ((double.tryParse('${inv['discount'] ?? 0}') ?? 0) > 0)
                      _FinRow(label: 'Discount', value: inv['discount'], isNeg: true),
                    Divider(color: cs.outlineVariant.withValues(alpha: 0.3), height: 16),
                    _FinRow(label: 'Total', value: inv['total'], bold: true, color: const Color(0xFF3B82F6)),
                    _FinRow(label: 'Amount Paid', value: inv['amount_paid'], color: const Color(0xFF10B981)),
                    _FinRow(label: 'Balance', value: balance, bold: true, color: balance > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
                  ]),
                ),

                // ── Line items ──
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('Line Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  ...items.asMap().entries.map((e) {
                    final it = e.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 26, height: 26,
                          decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: Center(child: Text('${e.key + 1}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6366F1)))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(it['description'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('${it['quantity'] ?? 1} × KSH ${_fmtMoney(it['unit_price'])}',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        ])),
                        Text('KSH ${_fmtMoney(it['total'])}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ]),
                    );
                  }),
                ],

                // ── Payment history ──
                if (payments.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('Payment History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  ...payments.map((p) {
                    final method = p['method'] ?? 'cash';
                    final mc = _methodColor(method);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: mc.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: mc.withValues(alpha: 0.2)),
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: mc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: Icon(_methodIcon(method), size: 16, color: mc),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('KSH ${_fmtMoney(p['amount'])}', style: TextStyle(fontWeight: FontWeight.w700, color: mc, fontSize: 14)),
                          Text('${_payMethodLabels[method] ?? method}${(p['reference'] ?? '').toString().isNotEmpty ? ' • ${p['reference']}' : ''}',
                            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                          Text(_fmtDateTime(p['paid_at']?.toString()),
                            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                        ])),
                      ]),
                    );
                  }),
                ],

                // ── Notes ──
                if ((inv['notes'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFFF0F9FF), borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.2))),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.note_rounded, size: 16, color: Color(0xFF0369A1)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(inv['notes'], style: const TextStyle(fontSize: 13, color: Color(0xFF0369A1)))),
                    ]),
                  ),
                ],

                // ── Action buttons ──
                const SizedBox(height: 20),
                if (balance > 0) ...[
                  FilledButton.icon(
                    onPressed: () { Navigator.pop(ctx); _showRecordPaymentDialog(context, ref, inv); },
                    icon: const Icon(Icons.add_card_rounded, size: 18),
                    label: const Text('Record Payment'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(children: [
                  if (status == 'draft')
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () { Navigator.pop(ctx); _showInvoiceForm(context, ref, invoice: inv); },
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    )),
                  if (status == 'draft') ...[
                    const SizedBox(width: 12),
                    Expanded(child: FilledButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _markSent(context, ref, inv['id']);
                      },
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Mark as Sent'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    )),
                  ],
                ]),
              ]),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Financial row in detail ──
class _FinRow extends StatelessWidget {
  const _FinRow({required this.label, required this.value, this.bold = false, this.color, this.isNeg = false});
  final String label;
  final dynamic value;
  final bool bold;
  final Color? color;
  final bool isNeg;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: color ?? cs.onSurface)),
        Text('${isNeg ? '-' : ''}KSH ${_fmtMoney(value)}',
          style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: color ?? cs.onSurface)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  INVOICE ACTIONS (long press)
// ═══════════════════════════════════════════════════════════════════════════
void _showInvoiceActions(BuildContext context, dynamic inv, WidgetRef ref) {
  final status = inv['status'] ?? 'draft';
  final balance = double.tryParse('${inv['balance'] ?? 0}') ?? 0;
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: const Icon(Icons.visibility_rounded, color: Color(0xFF3B82F6)),
            title: const Text('View Details'),
            onTap: () { Navigator.pop(ctx); _showInvoiceDetail(context, inv, ref); }),
          if (balance > 0)
            ListTile(
              leading: const Icon(Icons.add_card_rounded, color: Color(0xFF10B981)),
              title: const Text('Record Payment'),
              onTap: () { Navigator.pop(ctx); _showRecordPaymentDialog(context, ref, inv); }),
          if (status == 'draft') ...[
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: Color(0xFFF59E0B)),
              title: const Text('Edit'),
              onTap: () { Navigator.pop(ctx); _showInvoiceForm(context, ref, invoice: inv); }),
            ListTile(
              leading: const Icon(Icons.send_rounded, color: Color(0xFF3B82F6)),
              title: const Text('Mark as Sent'),
              onTap: () { Navigator.pop(ctx); _markSent(context, ref, inv['id']); }),
          ],
          if (status != 'cancelled' && status != 'paid')
            ListTile(
              leading: const Icon(Icons.cancel_rounded, color: Color(0xFFF59E0B)),
              title: const Text('Cancel Invoice'),
              onTap: () { Navigator.pop(ctx); _cancelInvoice(context, ref, inv['id']); }),
          ListTile(
            leading: const Icon(Icons.delete_rounded, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () { Navigator.pop(ctx); _deleteInvoice(context, ref, inv['id']); }),
        ]),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  INVOICE STATUS ACTIONS
// ═══════════════════════════════════════════════════════════════════════════
Future<void> _markSent(BuildContext context, WidgetRef ref, int id) async {
  try {
    await ref.read(dioProvider).patch('/billing/invoices/$id/', data: {'status': 'sent'});
    ref.invalidate(_invoicesProvider);
    if (context.mounted) _snack(context, 'Invoice marked as sent', const Color(0xFF3B82F6));
  } on DioException catch (e) { if (context.mounted) _snackErr(context, e); }
}

Future<void> _cancelInvoice(BuildContext context, WidgetRef ref, int id) async {
  final ok = await _confirm(context, 'Cancel Invoice?', 'This will cancel the invoice.');
  if (!ok || !context.mounted) return;
  try {
    await ref.read(dioProvider).patch('/billing/invoices/$id/', data: {'status': 'cancelled'});
    ref.invalidate(_invoicesProvider);
    if (context.mounted) _snack(context, 'Invoice cancelled', const Color(0xFF6B7280));
  } on DioException catch (e) { if (context.mounted) _snackErr(context, e); }
}

Future<void> _deleteInvoice(BuildContext context, WidgetRef ref, int id) async {
  final ok = await _confirm(context, 'Delete Invoice?', 'This cannot be undone.');
  if (!ok || !context.mounted) return;
  try {
    await ref.read(dioProvider).delete('/billing/invoices/$id/');
    ref.invalidate(_invoicesProvider);
    if (context.mounted) _snack(context, 'Invoice deleted', Colors.grey);
  } catch (_) { if (context.mounted) _snack(context, 'Failed to delete', Colors.red); }
}

// ═══════════════════════════════════════════════════════════════════════════
//  RECORD PAYMENT DIALOG
// ═══════════════════════════════════════════════════════════════════════════
void _showRecordPaymentDialog(BuildContext context, WidgetRef ref, dynamic inv) {
  final balance = double.tryParse('${inv['balance'] ?? 0}') ?? 0;
  final amountCtrl = TextEditingController(text: balance.toStringAsFixed(2));
  final refCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  String method = 'cash';

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.add_card_rounded, size: 20, color: Color(0xFF10B981)),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('Record Payment')),
        ]),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Amount
          TextField(
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: 'KSH ',
              suffixIcon: TextButton(
                onPressed: () => amountCtrl.text = balance.toStringAsFixed(2),
                child: const Text('Full', style: TextStyle(fontSize: 12)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Method
          DropdownButtonFormField<String>(
            value: method,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Payment Method'),
            items: _payMethods.map((m) => DropdownMenuItem(
              value: m,
              child: Row(children: [
                Icon(_methodIcon(m), size: 18, color: _methodColor(m)),
                const SizedBox(width: 8),
                Text(_payMethodLabels[m] ?? m),
              ]),
            )).toList(),
            onChanged: (v) => setDialogState(() => method = v ?? 'cash'),
          ),
          const SizedBox(height: 14),
          TextField(controller: refCtrl,
            decoration: const InputDecoration(labelText: 'Reference (optional)', hintText: 'M-Pesa code, cheque #...')),
          const SizedBox(height: 14),
          TextField(controller: notesCtrl, maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notes (optional)')),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF0F9FF), borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Invoice Balance:', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Text('KSH ${_fmtMoney(balance)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ]),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(dioProvider).post('/billing/invoices/${inv['id']}/record_payment/', data: {
                  'amount': double.tryParse(amountCtrl.text) ?? 0,
                  'method': method,
                  'reference': refCtrl.text,
                  'notes': notesCtrl.text,
                });
                ref.invalidate(_invoicesProvider);
                ref.invalidate(_paymentsProvider);
                if (context.mounted) _snack(context, 'Payment recorded', const Color(0xFF10B981));
              } on DioException catch (e) { if (context.mounted) _snackErr(context, e); }
            },
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Record'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
          ),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  CREATE / EDIT INVOICE
// ═══════════════════════════════════════════════════════════════════════════
void _showInvoiceForm(BuildContext context, WidgetRef ref, {dynamic invoice}) {
  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _InvoiceFormSheet(ref: ref, invoice: invoice));
}

class _InvoiceFormSheet extends ConsumerStatefulWidget {
  const _InvoiceFormSheet({required this.ref, this.invoice});
  final WidgetRef ref;
  final dynamic invoice;
  @override
  ConsumerState<_InvoiceFormSheet> createState() => _InvoiceFormSheetState();
}

class _InvoiceFormSheetState extends ConsumerState<_InvoiceFormSheet> {
  late final TextEditingController _notesCtrl;
  late final TextEditingController _taxCtrl;
  late final TextEditingController _discountCtrl;
  final _patientSearchCtrl = TextEditingController();
  int? _selectedPatientId;
  String? _selectedPatientName;
  String _status = 'draft';
  DateTime? _dueDate;
  bool _saving = false;
  Timer? _patientDebounce;
  final List<Map<String, TextEditingController>> _items = [];

  bool get _isEdit => widget.invoice != null;

  @override
  void initState() {
    super.initState();
    final inv = widget.invoice;
    _notesCtrl = TextEditingController(text: inv?['notes'] ?? '');
    _taxCtrl = TextEditingController(text: '${inv?['tax'] ?? 0}');
    _discountCtrl = TextEditingController(text: '${inv?['discount'] ?? 0}');
    _selectedPatientId = inv?['patient'];
    _selectedPatientName = inv?['patient_name'];
    _status = inv?['status'] ?? 'draft';
    if (inv?['due_date'] != null) _dueDate = DateTime.tryParse(inv['due_date']);

    final existing = (inv?['items'] as List?) ?? [];
    for (final it in existing) {
      _items.add({
        'description': TextEditingController(text: it['description'] ?? ''),
        'quantity': TextEditingController(text: '${it['quantity'] ?? 1}'),
        'unit_price': TextEditingController(text: '${it['unit_price'] ?? ''}'),
      });
    }
    if (_items.isEmpty) _addItem();
  }

  void _addItem() => setState(() => _items.add({
    'description': TextEditingController(),
    'quantity': TextEditingController(text: '1'),
    'unit_price': TextEditingController(),
  }));

  void _removeItem(int i) => setState(() { for (final c in _items[i].values) c.dispose(); _items.removeAt(i); });

  double get _subtotal {
    double s = 0;
    for (final m in _items) {
      final qty = int.tryParse(m['quantity']!.text) ?? 0;
      final price = double.tryParse(m['unit_price']!.text) ?? 0;
      s += qty * price;
    }
    return s;
  }

  double get _total => _subtotal + (double.tryParse(_taxCtrl.text) ?? 0) - (double.tryParse(_discountCtrl.text) ?? 0);

  @override
  void dispose() {
    _notesCtrl.dispose(); _taxCtrl.dispose(); _discountCtrl.dispose(); _patientSearchCtrl.dispose();
    _patientDebounce?.cancel();
    for (final m in _items) for (final c in m.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = _isEdit ? const Color(0xFFF59E0B) : const Color(0xFF6366F1);
    final patientResults = ref.watch(_patientSearchProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.92, maxChildSize: 0.95, minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Row(children: [
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.receipt_long_rounded, color: accent, size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Text(_isEdit ? 'Edit Invoice' : 'New Invoice', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 16),
              const Divider(height: 1),
            ]),
          ),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(20),
              children: [
                // ── Patient search ──
                Text('Patient *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
                const SizedBox(height: 6),
                if (_selectedPatientName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      Icon(Icons.person_rounded, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_selectedPatientName!, style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary))),
                      if (!_isEdit) InkWell(
                        onTap: () => setState(() { _selectedPatientId = null; _selectedPatientName = null; }),
                        child: Icon(Icons.close_rounded, size: 18, color: cs.onSurfaceVariant),
                      ),
                    ]),
                  )
                else ...[
                  TextField(
                    controller: _patientSearchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search patient by name...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true, filled: true,
                      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    style: const TextStyle(fontSize: 14),
                    onChanged: (v) {
                      _patientDebounce?.cancel();
                      _patientDebounce = Timer(const Duration(milliseconds: 250), () =>
                        ref.read(_patientQueryProvider.notifier).state = v);
                    },
                  ),
                  patientResults.when(
                    loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (patients) {
                      if (patients.isEmpty) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(top: 4),
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outlineVariant),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: patients.length,
                          itemBuilder: (_, i) {
                            final p = patients[i];
                            final name = '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: cs.primaryContainer,
                                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.primary)),
                              ),
                              title: Text(name.isNotEmpty ? name : 'Patient', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: Text('${p['patient_number'] ?? ''}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                              onTap: () {
                                setState(() {
                                  _selectedPatientId = p['id'];
                                  _selectedPatientName = name;
                                  _patientSearchCtrl.clear();
                                });
                                ref.read(_patientQueryProvider.notifier).state = '';
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],

                const SizedBox(height: 16),
                // Due date
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _dueDate = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Due Date',
                      isDense: true, filled: true,
                      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                    ),
                    child: Text(_dueDate != null ? DateFormat('MMM d, yyyy').format(_dueDate!) : 'Select date',
                      style: TextStyle(fontSize: 14, color: _dueDate != null ? cs.onSurface : cs.onSurfaceVariant)),
                  ),
                ),

                // ── Line items ──
                const SizedBox(height: 24),
                Row(children: [
                  const Icon(Icons.list_alt_rounded, size: 18, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Line Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add', style: TextStyle(fontSize: 13))),
                ]),
                const SizedBox(height: 8),
                ..._items.asMap().entries.map((e) => _LineItemCard(
                  index: e.key, ctrls: e.value,
                  onRemove: _items.length > 1 ? () => _removeItem(e.key) : null,
                  onChanged: () => setState(() {}),
                )),

                // ── Totals ──
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Column(children: [
                    _FinRow(label: 'Subtotal', value: _subtotal, color: const Color(0xFF3B82F6)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: TextField(
                        controller: _taxCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(labelText: 'Tax', prefixText: 'KSH ', isDense: true, filled: true,
                          fillColor: cs.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
                        style: const TextStyle(fontSize: 14),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(
                        controller: _discountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(labelText: 'Discount', prefixText: 'KSH ', isDense: true, filled: true,
                          fillColor: cs.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
                        style: const TextStyle(fontSize: 14),
                      )),
                    ]),
                    const Divider(height: 20),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('TOTAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      Text('KSH ${_fmtMoney(_total)}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF6366F1))),
                    ]),
                  ]),
                ),

                const SizedBox(height: 16),
                _buildField('Notes', _notesCtrl, maxLines: 2, hint: 'Additional notes...'),

                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(_isEdit ? Icons.save_rounded : Icons.add_rounded, size: 18),
                  label: Text(_saving ? 'Saving...' : (_isEdit ? 'Save Changes' : 'Create Invoice')),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, {String? hint, int maxLines = 1, TextInputType? keyboard}) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
      const SizedBox(height: 6),
      TextField(controller: ctrl, maxLines: maxLines, keyboardType: keyboard,
        decoration: InputDecoration(hintText: hint, isDense: true, filled: true,
          fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
        style: const TextStyle(fontSize: 14)),
    ]);
  }

  Future<void> _submit() async {
    if (_selectedPatientId == null) { _snack(context, 'Select a patient', Colors.orange); return; }
    if (_items.isEmpty) { _snack(context, 'Add at least one item', Colors.orange); return; }
    setState(() => _saving = true);
    try {
      final dio = widget.ref.read(dioProvider);
      final body = {
        'patient': _selectedPatientId,
        'status': _status,
        'items': _items.map((m) {
          final qty = int.tryParse(m['quantity']!.text) ?? 1;
          final price = double.tryParse(m['unit_price']!.text) ?? 0;
          return {
            'description': m['description']!.text,
            'quantity': qty,
            'unit_price': price,
            'total': qty * price,
          };
        }).toList(),
        'tax': double.tryParse(_taxCtrl.text) ?? 0,
        'discount': double.tryParse(_discountCtrl.text) ?? 0,
        'notes': _notesCtrl.text,
      };
      if (_dueDate != null) body['due_date'] = DateFormat('yyyy-MM-dd').format(_dueDate!);
      if (_isEdit) {
        await dio.patch('/billing/invoices/${widget.invoice['id']}/', data: body);
      } else {
        await dio.post('/billing/invoices/', data: body);
      }
      widget.ref.invalidate(_invoicesProvider);
      if (mounted) {
        Navigator.pop(context);
        _snack(context, _isEdit ? 'Invoice updated' : 'Invoice created', const Color(0xFF10B981));
      }
    } on DioException catch (e) {
      if (mounted) _snackErr(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Line item form card ──
class _LineItemCard extends StatelessWidget {
  const _LineItemCard({required this.index, required this.ctrls, this.onRemove, this.onChanged});
  final int index;
  final Map<String, TextEditingController> ctrls;
  final VoidCallback? onRemove;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 24, height: 24,
            decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Center(child: Text('${index + 1}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6366F1))))),
          const SizedBox(width: 8),
          Text('Item ${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (onRemove != null) IconButton(icon: const Icon(Icons.remove_circle_rounded, color: Colors.red, size: 20), onPressed: onRemove, visualDensity: VisualDensity.compact),
        ]),
        const SizedBox(height: 8),
        TextField(controller: ctrls['description'],
          decoration: InputDecoration(labelText: 'Description *', isDense: true, filled: true, fillColor: cs.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
          style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        Row(children: [
          SizedBox(width: 70, child: TextField(
            controller: ctrls['quantity'],
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => onChanged?.call(),
            decoration: InputDecoration(labelText: 'Qty', isDense: true, filled: true, fillColor: cs.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
            style: const TextStyle(fontSize: 14),
          )),
          const SizedBox(width: 10),
          Expanded(child: TextField(
            controller: ctrls['unit_price'],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged?.call(),
            decoration: InputDecoration(labelText: 'Unit Price', isDense: true, filled: true, fillColor: cs.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
            style: const TextStyle(fontSize: 14),
          )),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Builder(builder: (_) {
              final qty = int.tryParse(ctrls['quantity']!.text) ?? 0;
              final price = double.tryParse(ctrls['unit_price']!.text) ?? 0;
              return Text('KSH ${_fmtMoney(qty * price)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12));
            }),
          ),
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
    child: Text(label.toUpperCase(),
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
  );
}

class _MoneyLabel extends StatelessWidget {
  const _MoneyLabel({required this.label, required this.amount, required this.color});
  final String label;
  final dynamic amount;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Text('$label: ', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    Text(_fmtMoney(amount), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
  ]);
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.items});
  final List<_Kpi> items;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: items.map((k) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: k.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: k.color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Text(k.money ?? '${k.value}',
              style: TextStyle(fontSize: k.money != null ? 13 : 20, fontWeight: FontWeight.w800, color: k.color),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(k.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: k.color.withValues(alpha: 0.8)),
              textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      )).toList(),
    ),
  ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
}

class _Kpi {
  const _Kpi(this.label, this.value, this.color, {this.money});
  final String label;
  final int value;
  final Color color;
  final String? money;
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: cs.primary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ])),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════════════════════════
Future<bool> _confirm(BuildContext context, String title, String content) async {
  return await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
    title: Text(title), content: Text(content),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
    ],
  )) ?? false;
}

void _snack(BuildContext context, String msg, Color color) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, backgroundColor: color));
}

void _snackErr(BuildContext context, DioException e) {
  final d = e.response?.data;
  String msg = 'Request failed';
  if (d is Map) {
    final parts = <String>[];
    for (final entry in d.entries) {
      final val = entry.value;
      parts.add(val is List ? '${entry.key}: ${val.join(', ')}' : '${entry.key}: $val');
    }
    if (parts.isNotEmpty) msg = parts.join('\n');
  } else if (d is String && d.isNotEmpty) { msg = d; }
  _snack(context, msg, Colors.red);
}
