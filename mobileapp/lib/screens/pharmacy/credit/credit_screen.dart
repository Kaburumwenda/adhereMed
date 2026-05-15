import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../core/api.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/common.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════════════════════════

String _fmt(dynamic v) {
  final n = double.tryParse('$v') ?? 0;
  return NumberFormat.currency(symbol: 'KES ', decimalDigits: 0).format(n);
}

Color _statusColor(String? s) => switch (s?.toLowerCase()) {
      'open' => const Color(0xFFF59E0B),
      'partial' => const Color(0xFF3B82F6),
      'settled' => const Color(0xFF10B981),
      'overdue' => const Color(0xFFEF4444),
      _ => const Color(0xFF6B7280),
    };

IconData _statusIcon(String? s) => switch (s?.toLowerCase()) {
      'open' => Icons.access_time_rounded,
      'partial' => Icons.pie_chart_rounded,
      'settled' => Icons.check_circle_outline_rounded,
      'overdue' => Icons.warning_amber_rounded,
      _ => Icons.help_outline_rounded,
    };

String _statusLabel(String? s) => switch (s?.toLowerCase()) {
      'open' => 'Open',
      'partial' => 'Partial',
      'settled' => 'Settled',
      'overdue' => 'Overdue',
      _ => s ?? '',
    };

Color _pmColor(String? m) => switch (m?.toLowerCase()) {
      'cash' => const Color(0xFF10B981),
      'mpesa' => const Color(0xFF059669),
      'card' => const Color(0xFF3B82F6),
      'insurance' => const Color(0xFFF59E0B),
      _ => const Color(0xFF6B7280),
    };

// ═══════════════════════════════════════════════════════════════════════════
//  PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

final _periodFilter = StateProvider<String>((_) => 'all');
final _statusFilter = StateProvider<String?>((_) => null);

// ═══════════════════════════════════════════════════════════════════════════
//  CREDIT SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class CreditScreen extends ConsumerStatefulWidget {
  const CreditScreen({super.key});
  @override
  ConsumerState<CreditScreen> createState() => _CreditScreenState();
}

class _CreditScreenState extends ConsumerState<CreditScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _credits = [];
  Map<String, dynamic> _summary = {};
  String _search = '';
  String? _error;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final period = ref.read(_periodFilter);
      final status = ref.read(_statusFilter);

      final params = <String, dynamic>{'page_size': 500};
      if (period == 'custom') {
        if (_dateFrom != null) {
          params['date_from'] = DateFormat('yyyy-MM-dd').format(_dateFrom!);
        }
        if (_dateTo != null) {
          params['date_to'] = DateFormat('yyyy-MM-dd').format(_dateTo!);
        }
      } else if (period != 'all') {
        params['period'] = period;
      }
      if (status != null) params['status'] = status;

      final results = await Future.wait([
        dio.get('/pos/credits/summary/', queryParameters: params),
        dio.get('/pos/credits/', queryParameters: params),
      ]);

      final summaryData = results[0].data as Map<String, dynamic>;
      final creditsData = results[1].data;
      final list = creditsData is List
          ? creditsData
          : (creditsData?['results'] as List?) ?? [];

      setState(() {
        _summary = summaryData;
        _credits = List<Map<String, dynamic>>.from(list);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load credits';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _credits;
    final q = _search.toLowerCase();
    return _credits.where((c) {
      final name = (c['customer_name'] ?? '').toString().toLowerCase();
      final phone = (c['customer_phone'] ?? '').toString().toLowerCase();
      final txn = (c['transaction_number'] ?? '').toString().toLowerCase();
      return name.contains(q) || phone.contains(q) || txn.contains(q);
    }).toList();
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? Colors.red.shade700 : null,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final period = ref.watch(_periodFilter);
    final statusF = ref.watch(_statusFilter);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Credit Sales',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: LoadingShimmer(lines: 6))
          : _error != null
              ? ErrorRetry(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(slivers: [
                    // KPI Cards
                    SliverToBoxAdapter(
                        child: _buildSummaryCards(cs, isDark)),
                    // Filters
                    SliverToBoxAdapter(
                        child: _buildFilters(cs, isDark, period, statusF)),
                    // Search
                    SliverToBoxAdapter(child: _buildSearchBar(cs, isDark)),
                    // List
                    _filtered.isEmpty
                        ? SliverFillRemaining(
                            child: EmptyState(
                              icon: Icons.credit_card_off_rounded,
                              title: 'No credit sales',
                              subtitle: statusF != null
                                  ? 'No ${_statusLabel(statusF).toLowerCase()} credits found.'
                                  : 'No credit sales for this period.',
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            sliver: SliverList.separated(
                              itemCount: _filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) =>
                                  _buildCreditCard(_filtered[i], cs, isDark),
                            ),
                          ),
                  ]),
                ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  SUMMARY CARDS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildSummaryCards(ColorScheme cs, bool isDark) {
    final count = _summary['count'] ?? 0;
    final totalCredit = _summary['total_credit'] ?? 0;
    final totalPaid = _summary['total_paid'] ?? 0;
    final totalBalance = _summary['total_balance'] ?? 0;
    final overdueCount = _summary['overdue_count'] ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(children: [
        Row(children: [
          Expanded(
              child: _kpiCard('Credit Sales', '$count',
                  Icons.receipt_long_rounded, cs.primary, cs, isDark)),
          const SizedBox(width: 10),
          Expanded(
              child: _kpiCard('Total Credit', _fmt(totalCredit),
                  Icons.account_balance_wallet_rounded, const Color(0xFF8B5CF6), cs, isDark)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _kpiCard('Collected', _fmt(totalPaid),
                  Icons.check_circle_rounded, const Color(0xFF10B981), cs, isDark)),
          const SizedBox(width: 10),
          Expanded(
              child: _kpiCard(
                  'Outstanding',
                  _fmt(totalBalance),
                  Icons.warning_amber_rounded,
                  const Color(0xFFEF4444),
                  cs,
                  isDark,
                  badge: overdueCount > 0 ? '$overdueCount overdue' : null)),
        ]),
      ]).animate().fadeIn(duration: 300.ms),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color,
      ColorScheme cs, bool isDark,
      {String? badge}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          const Spacer(),
          if (badge != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(badge,
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEF4444))),
            ),
        ]),
        const SizedBox(height: 10),
        Text(value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: cs.onSurface)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  FILTERS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildFilters(
      ColorScheme cs, bool isDark, String period, String? statusF) {
    const periods = [
      {'value': 'all', 'label': 'All'},
      {'value': 'today', 'label': 'Today'},
      {'value': 'week', 'label': 'Week'},
      {'value': 'month', 'label': 'Month'},
      {'value': 'custom', 'label': 'Custom'},
    ];
    const statuses = [
      {'value': 'open', 'label': 'Open'},
      {'value': 'partial', 'label': 'Partial'},
      {'value': 'settled', 'label': 'Settled'},
      {'value': 'overdue', 'label': 'Overdue'},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(children: [
        // Period chips
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: periods.map((p) {
              final sel = period == p['value'];
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  avatar: p['value'] == 'custom'
                      ? Icon(Icons.date_range_rounded,
                          size: 14,
                          color: sel ? Colors.white : cs.onSurfaceVariant)
                      : null,
                  label: Text(
                      p['value'] == 'custom' && sel && _dateFrom != null
                          ? '${DateFormat('MMM d').format(_dateFrom!)} – ${_dateTo != null ? DateFormat('MMM d').format(_dateTo!) : 'now'}'
                          : p['label']!,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : cs.onSurfaceVariant)),
                  selected: sel,
                  onSelected: (_) async {
                    if (p['value'] == 'custom') {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: _dateFrom != null
                            ? DateTimeRange(
                                start: _dateFrom!,
                                end: _dateTo ?? DateTime.now())
                            : null,
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: cs,
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() {
                          _dateFrom = picked.start;
                          _dateTo = picked.end;
                        });
                        ref.read(_periodFilter.notifier).state = 'custom';
                        _load();
                      }
                    } else {
                      setState(() {
                        _dateFrom = null;
                        _dateTo = null;
                      });
                      ref.read(_periodFilter.notifier).state = p['value']!;
                      _load();
                    }
                  },
                  selectedColor: cs.primary,
                  checkmarkColor: Colors.white,
                  backgroundColor: cs.onSurface.withValues(alpha: 0.06),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide.none),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        // Status chips
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text('All Status',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusF == null
                              ? Colors.white
                              : cs.onSurfaceVariant)),
                  selected: statusF == null,
                  onSelected: (_) {
                    ref.read(_statusFilter.notifier).state = null;
                    _load();
                  },
                  selectedColor: cs.primary,
                  checkmarkColor: Colors.white,
                  backgroundColor: cs.onSurface.withValues(alpha: 0.06),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide.none),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              ...statuses.map((s) {
                final sel = statusF == s['value'];
                final color = _statusColor(s['value']);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    avatar: Icon(_statusIcon(s['value']),
                        size: 14,
                        color: sel ? Colors.white : color),
                    label: Text(s['label']!,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : color)),
                    selected: sel,
                    onSelected: (_) {
                      ref.read(_statusFilter.notifier).state =
                          sel ? null : s['value']!;
                      _load();
                    },
                    selectedColor: color,
                    checkmarkColor: Colors.white,
                    backgroundColor: color.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide.none),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }),
            ],
          ),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  SEARCH
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildSearchBar(ColorScheme cs, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          hintText: 'Search by customer, phone, or txn #...',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          filled: true,
          fillColor: cs.onSurface.withValues(alpha: 0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  CREDIT CARD
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildCreditCard(
      Map<String, dynamic> c, ColorScheme cs, bool isDark) {
    final name = (c['customer_name'] ?? 'Walk-in').toString();
    final phone = (c['customer_phone'] ?? '').toString();
    final txnNum = (c['transaction_number'] ?? '').toString();
    final status = (c['status'] ?? 'open').toString();
    final total = double.tryParse('${c['total_amount']}') ?? 0;
    final paid = double.tryParse('${c['partial_paid_amount']}') ?? 0;
    final balance = double.tryParse('${c['balance_amount']}') ?? 0;
    final dueDate = c['due_date'] != null
        ? DateTime.tryParse(c['due_date'].toString())
        : null;
    final createdAt = c['created_at'] != null
        ? DateTime.tryParse(c['created_at'].toString())
        : null;
    final notes = (c['notes'] ?? '').toString();
    final cashier = (c['cashier_name'] ?? '').toString();
    final sColor = _statusColor(status);

    final isOverdue = dueDate != null &&
        dueDate.isBefore(DateTime.now()) &&
        balance > 0 &&
        status != 'settled';

    // Progress bar
    final progress = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTap: () => _showDetailSheet(c),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOverdue
                ? Colors.red.withValues(alpha: 0.3)
                : sColor.withValues(alpha: 0.15),
            width: isOverdue ? 1.5 : 1,
          ),
        ),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: sColor.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.person_rounded,
                            size: 14, color: cs.primary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (phone.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text('· $phone',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant)),
                        ],
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        Text(txnNum,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurfaceVariant)),
                        if (createdAt != null) ...[
                          const SizedBox(width: 8),
                          Text(
                              DateFormat('MMM d, y').format(createdAt.toLocal()),
                              style: TextStyle(
                                  fontSize: 10,
                                  color: cs.onSurfaceVariant)),
                        ],
                      ]),
                    ]),
              ),
              // Status chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: sColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_statusIcon(status), size: 12, color: sColor),
                  const SizedBox(width: 4),
                  Text(_statusLabel(status),
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: sColor)),
                ]),
              ),
            ]),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(children: [
              // Amounts row
              Row(children: [
                _amountCol('Total', _fmt(total), cs),
                _amountCol('Paid', _fmt(paid), cs,
                    color: const Color(0xFF10B981)),
                _amountCol('Balance', _fmt(balance), cs,
                    color: balance > 0
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981)),
              ]),
              const SizedBox(height: 10),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: cs.onSurface.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation(
                      progress >= 1.0
                          ? const Color(0xFF10B981)
                          : const Color(0xFF3B82F6)),
                ),
              ),
              const SizedBox(height: 8),
              // Due date + cashier
              Row(children: [
                if (dueDate != null) ...[
                  Icon(
                      isOverdue
                          ? Icons.warning_amber_rounded
                          : Icons.calendar_today_rounded,
                      size: 12,
                      color: isOverdue ? Colors.red : cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                      'Due: ${DateFormat('MMM d, y').format(dueDate)}',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: isOverdue ? FontWeight.w700 : FontWeight.w400,
                          color: isOverdue
                              ? Colors.red
                              : cs.onSurfaceVariant)),
                ],
                if (cashier.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.badge_rounded,
                      size: 12, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(cashier,
                      style: TextStyle(
                          fontSize: 10, color: cs.onSurfaceVariant)),
                ],
              ]),
              if (notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    Icon(Icons.note_rounded,
                        size: 12, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(notes,
                          style: TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ),
            ]),
          ),

          // Actions
          if (status != 'settled')
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _showPaymentDialog(c),
                  icon: const Icon(Icons.payment_rounded, size: 16),
                  label: const Text('Record Payment',
                      style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _amountCol(String label, String value, ColorScheme cs,
      {Color? color}) {
    return Expanded(
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color ?? cs.onSurface)),
        Text(label,
            style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  DETAIL SHEET
  // ═══════════════════════════════════════════════════════════════════════

  void _showDetailSheet(Map<String, dynamic> c) async {
    final cs = Theme.of(context).colorScheme;
    final dio = ref.read(dioProvider);

    // Load payment history
    List<Map<String, dynamic>> payments = [];
    try {
      final res = await dio.get('/pos/credits/${c['id']}/payments/');
      final data = res.data;
      payments = List<Map<String, dynamic>>.from(
          data is List ? data : (data?['results'] as List?) ?? []);
    } catch (_) {}

    if (!mounted) return;

    final name = (c['customer_name'] ?? 'Walk-in').toString();
    final phone = (c['customer_phone'] ?? '').toString();
    final txnNum = (c['transaction_number'] ?? '').toString();
    final status = (c['status'] ?? 'open').toString();
    final total = double.tryParse('${c['total_amount']}') ?? 0;
    final paid = double.tryParse('${c['partial_paid_amount']}') ?? 0;
    final balance = double.tryParse('${c['balance_amount']}') ?? 0;
    final dueDate = c['due_date']?.toString() ?? '';
    final notes = (c['notes'] ?? '').toString();
    final sColor = _statusColor(status);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2))),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: sColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(_statusIcon(status),
                      color: sColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Credit Details',
                            style: Theme.of(ctx)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        Text(txnNum,
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant)),
                      ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: sColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(_statusLabel(status),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: sColor)),
                ),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // Customer info
                  _detailRow(Icons.person_rounded, 'Customer', name, cs),
                  if (phone.isNotEmpty)
                    _detailRow(Icons.phone_rounded, 'Phone', phone, cs),
                  if (dueDate.isNotEmpty)
                    _detailRow(Icons.calendar_today_rounded, 'Due Date',
                        dueDate, cs),
                  const SizedBox(height: 16),

                  // Amounts
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14)),
                    child: Column(children: [
                      _amountRow('Total Amount', _fmt(total), cs),
                      _amountRow('Paid', _fmt(paid), cs,
                          color: const Color(0xFF10B981)),
                      const Divider(height: 16),
                      _amountRow('Balance', _fmt(balance), cs,
                          color: balance > 0
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
                          bold: true),
                    ]),
                  ),

                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _detailRow(Icons.note_rounded, 'Notes', notes, cs),
                  ],

                  // Payment history
                  if (payments.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Payment History',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: cs.onSurface)),
                    const SizedBox(height: 10),
                    ...payments.map((p) {
                      final paidAt = p['paid_at'] != null
                          ? DateTime.tryParse(p['paid_at'].toString())
                          : null;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: _pmColor(p['payment_method']?.toString())
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.payment_rounded,
                                size: 16,
                                color: _pmColor(
                                    p['payment_method']?.toString())),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(_fmt(p['amount']),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13)),
                                  Row(children: [
                                    Text(
                                        (p['payment_method'] ?? '')
                                            .toString()
                                            .toUpperCase(),
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: cs.onSurfaceVariant)),
                                    if ((p['reference'] ?? '')
                                        .toString()
                                        .isNotEmpty) ...[
                                      Text(
                                          ' · ${p['reference']}',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color:
                                                  cs.onSurfaceVariant)),
                                    ],
                                  ]),
                                  if ((p['recorded_by_name'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    Text(
                                        'by ${p['recorded_by_name']}',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color:
                                                cs.onSurfaceVariant)),
                                ]),
                          ),
                          if (paidAt != null)
                            Text(
                                DateFormat('MMM d\nh:mm a')
                                    .format(paidAt.toLocal()),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: cs.onSurfaceVariant)),
                        ]),
                      );
                    }),
                  ],

                  // Record payment button
                  if (status != 'settled') ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showPaymentDialog(c);
                        },
                        icon: const Icon(Icons.payment_rounded),
                        label: const Text('Record Payment'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _detailRow(
      IconData icon, String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(
            width: 70,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12, color: cs.onSurfaceVariant))),
        Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Widget _amountRow(String label, String value, ColorScheme cs,
      {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child:
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
        Text(value,
            style: TextStyle(
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: color ?? cs.onSurface)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  RECORD PAYMENT DIALOG
  // ═══════════════════════════════════════════════════════════════════════

  void _showPaymentDialog(Map<String, dynamic> c) {
    final cs = Theme.of(context).colorScheme;
    final balance = double.tryParse('${c['balance_amount']}') ?? 0;
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String method = 'cash';
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          final amount = double.tryParse(amountCtrl.text) ?? 0;
          final newBalance = balance - amount;
          final isFullSettle = amount >= balance && amount > 0;
          final canSubmit = amount > 0 && amount <= balance && !saving;

          return Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(
                24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: const Color(0xFF10B981)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.payment_rounded,
                        color: Color(0xFF10B981), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Record Payment',
                              style: Theme.of(ctx)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          Text(
                              'Balance: ${_fmt(balance)}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant)),
                        ]),
                  ),
                ]),
                const SizedBox(height: 20),

                // Quick amount chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      label: Text('Full (${_fmt(balance)})',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: cs.primary)),
                      onPressed: () {
                        amountCtrl.text =
                            balance.toStringAsFixed(0);
                        setSheet(() {});
                      },
                    ),
                    ...[25, 50, 75].map((pct) {
                      final amt = balance * pct / 100;
                      return ActionChip(
                        label: Text('$pct%',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                        onPressed: () {
                          amountCtrl.text =
                              amt.toStringAsFixed(0);
                          setSheet(() {});
                        },
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 16),

                // Amount
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount *',
                    prefixIcon:
                        const Icon(Icons.attach_money_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: cs.surfaceContainerLow,
                  ),
                  onChanged: (_) => setSheet(() {}),
                ),
                const SizedBox(height: 12),

                // Payment method
                DropdownButtonFormField<String>(
                  value: method,
                  decoration: InputDecoration(
                    labelText: 'Payment Method',
                    prefixIcon: const Icon(Icons.payment_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: cs.surfaceContainerLow,
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(
                        value: 'mpesa', child: Text('M-Pesa')),
                    DropdownMenuItem(
                        value: 'card', child: Text('Card')),
                    DropdownMenuItem(
                        value: 'insurance',
                        child: Text('Insurance')),
                  ],
                  onChanged: (v) =>
                      setSheet(() => method = v ?? 'cash'),
                ),
                const SizedBox(height: 12),

                // Reference
                TextField(
                  controller: refCtrl,
                  decoration: InputDecoration(
                    labelText: 'Reference (optional)',
                    prefixIcon: const Icon(Icons.receipt_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: cs.surfaceContainerLow,
                  ),
                ),
                const SizedBox(height: 12),

                // Notes
                TextField(
                  controller: notesCtrl,
                  decoration: InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: const Icon(Icons.note_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: cs.surfaceContainerLow,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Balance preview
                if (amount > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isFullSettle
                          ? const Color(0xFF10B981)
                              .withValues(alpha: 0.1)
                          : const Color(0xFF3B82F6)
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isFullSettle
                              ? const Color(0xFF10B981)
                              : const Color(0xFF3B82F6),
                          width: 1),
                    ),
                    child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              isFullSettle
                                  ? 'Fully settled!'
                                  : 'New balance',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isFullSettle
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF3B82F6))),
                          Text(
                              isFullSettle
                                  ? _fmt(0)
                                  : _fmt(newBalance.clamp(0, double.infinity)),
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isFullSettle
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF3B82F6))),
                        ]),
                  ),
                const SizedBox(height: 20),

                // Buttons
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12))),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: canSubmit
                          ? () async {
                              setSheet(() => saving = true);
                              try {
                                final dio =
                                    ref.read(dioProvider);
                                await dio.post(
                                  '/pos/credits/${c['id']}/record_payment/',
                                  data: {
                                    'amount': amount,
                                    'payment_method': method,
                                    'reference':
                                        refCtrl.text.trim(),
                                    'notes':
                                        notesCtrl.text.trim(),
                                  },
                                );
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                                _snack(
                                    'Payment of ${_fmt(amount)} recorded');
                                _load();
                              } catch (e) {
                                setSheet(
                                    () => saving = false);
                                String msg =
                                    'Failed to record payment';
                                try {
                                  final dioErr =
                                      e as dynamic;
                                  if (dioErr.response?.data
                                      is Map) {
                                    msg = (dioErr.response
                                                    ?.data[
                                                'detail'] ??
                                            msg)
                                        .toString();
                                  }
                                } catch (_) {}
                                _snack(msg,
                                    isError: true);
                              }
                            }
                          : null,
                      icon: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                          : const Icon(
                              Icons.check_circle_rounded),
                      label: Text(
                          isFullSettle
                              ? 'Settle Credit'
                              : 'Record Payment',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      style: FilledButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12))),
                    ),
                  ),
                ]),
              ]),
            ),
          );
        });
      },
    );
  }
}
