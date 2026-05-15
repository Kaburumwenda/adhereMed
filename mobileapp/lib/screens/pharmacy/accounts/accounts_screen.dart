import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/api.dart';
import '../../../widgets/common.dart';

// ── Date range filter ──
final _periodProvider = StateProvider<String>((ref) => 'last30');

DateTime _startFor(String period) {
  final now = DateTime.now();
  switch (period) {
    case 'today':
      return DateTime(now.year, now.month, now.day);
    case 'yesterday':
      return DateTime(now.year, now.month, now.day - 1);
    case '7d':
      return now.subtract(const Duration(days: 7));
    case 'last30':
      return now.subtract(const Duration(days: 30));
    case 'mtd':
      return DateTime(now.year, now.month, 1);
    case '90d':
      return now.subtract(const Duration(days: 90));
    case 'ytd':
      return DateTime(now.year, 1, 1);
    default:
      return now.subtract(const Duration(days: 30));
  }
}

// ── Data providers ──
final _accountsDataProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, period) async {
  final dio = ref.read(dioProvider);
  final start = DateFormat('yyyy-MM-dd').format(_startFor(period));
  final end = DateFormat('yyyy-MM-dd').format(DateTime.now());

  final results = await Future.wait([
    dio.get('/pos/transactions/', queryParameters: {'status': 'completed', 'page_size': 500, 'date_from': start, 'date_to': end}),
    dio.get('/billing/invoices/', queryParameters: {'page_size': 500}),
    dio.get('/billing/payments/', queryParameters: {'page_size': 500, 'created_at_after': start}),
    dio.get('/expenses/expenses/', queryParameters: {'page_size': 500}),
    dio.get('/usage-billing/dashboard/'),
    dio.get('/pos/credits/', queryParameters: {'page_size': 500}),
    dio.get('/reports/inventory-valuation/'),
  ]);

  final posTxns = _list(results[0].data);
  final invoices = _list(results[1].data);
  final payments = _list(results[2].data);
  final expenses = _list(results[3].data);
  final billing = results[4].data as Map? ?? {};
  final credits = _list(results[5].data);
  final inventory = results[6].data as Map? ?? {};

  return {
    'posTxns': posTxns,
    'invoices': invoices,
    'payments': payments,
    'expenses': expenses,
    'billing': billing,
    'credits': credits,
    'inventory': inventory,
    'start': start,
    'end': end,
  };
});

List _list(dynamic d) {
  if (d is List) return d;
  if (d is Map && d['results'] is List) return d['results'] as List;
  return [];
}

double _dbl(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;

final _fmt = NumberFormat.compactCurrency(symbol: 'KSH ', decimalDigits: 0);
final _fmtFull = NumberFormat('#,##0', 'en');

// ══════════════════════════════════════════
// Main Screen
// ══════════════════════════════════════════
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(_periodProvider);
    final data = ref.watch(_accountsDataProvider(period));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Receivables'),
            Tab(text: 'Payables'),
            Tab(text: 'Transactions'),
            Tab(text: 'Profit & Loss'),
            Tab(text: 'Balance Sheet'),
            Tab(text: 'General Ledger'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.date_range_rounded),
            tooltip: 'Date range',
            onSelected: (v) => ref.read(_periodProvider.notifier).state = v,
            itemBuilder: (_) => [
              _menuItem('today', 'Today', period),
              _menuItem('yesterday', 'Yesterday', period),
              _menuItem('7d', 'Last 7 Days', period),
              _menuItem('last30', 'Last 30 Days', period),
              _menuItem('mtd', 'Month to Date', period),
              _menuItem('90d', 'Last 90 Days', period),
              _menuItem('ytd', 'Year to Date', period),
            ],
          ),
        ],
      ),
      body: data.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorRetry(message: 'Failed to load accounts', onRetry: () => ref.invalidate(_accountsDataProvider(period))),
        data: (d) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(_accountsDataProvider(period)),
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _OverviewTab(data: d),
              _ReceivablesTab(data: d),
              _PayablesTab(data: d),
              _TransactionsTab(data: d),
              _ProfitLossTab(data: d),
              _BalanceSheetTab(data: d),
              _GeneralLedgerTab(data: d),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, String label, String current) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        if (current == value) Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.primary) else const SizedBox(width: 18),
        const SizedBox(width: 8),
        Text(label),
      ]),
    );
  }
}

// ══════════════════════════════════════════
// 1. OVERVIEW TAB
// ══════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _OverviewTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final posTxns = data['posTxns'] as List;
    final payments = data['payments'] as List;
    final expenses = data['expenses'] as List;
    final billing = data['billing'] as Map;
    final invoices = data['invoices'] as List;

    // Compute KPIs
    final posIncome = posTxns.fold<double>(0, (s, t) => s + _dbl(t['total_amount'] ?? t['total']));
    final paymentIncome = payments.fold<double>(0, (s, p) => s + _dbl(p['amount']));
    final totalIncome = posIncome + paymentIncome;
    final totalExpenses = expenses.fold<double>(0, (s, e) => s + _dbl(e['amount']));
    final netCashFlow = totalIncome - totalExpenses;

    final outstanding = invoices
        .where((i) => i['status'] != 'PAID' && i['status'] != 'CANCELLED')
        .fold<double>(0, (s, i) => s + _dbl(i['total']) - _dbl(i['amount_paid']));

    // Payment method breakdown
    final Map<String, double> methodMap = {};
    for (final t in posTxns) {
      final method = (t['payment_method'] ?? 'cash').toString().toLowerCase();
      methodMap[method] = (methodMap[method] ?? 0) + _dbl(t['total_amount'] ?? t['total']);
    }
    for (final p in payments) {
      final method = (p['payment_method'] ?? 'cash').toString().toLowerCase();
      methodMap[method] = (methodMap[method] ?? 0) + _dbl(p['amount']);
    }

    // Top outstanding receivables
    final outstandingInvoices = invoices
        .where((i) => i['status'] != 'PAID' && i['status'] != 'CANCELLED')
        .toList()
      ..sort((a, b) => (_dbl(b['total']) - _dbl(b['amount_paid'])).compareTo(_dbl(a['total']) - _dbl(a['amount_paid'])));
    final top5Receivables = outstandingInvoices.take(5).toList();

    // Top pending expenses
    final pendingExpenses = expenses.where((e) => e['status'] == 'PENDING' || e['status'] == 'APPROVED').toList()
      ..sort((a, b) => _dbl(b['amount']).compareTo(_dbl(a['amount'])));
    final top5Payables = pendingExpenses.take(5).toList();

    // API billing
    final currentMonth = billing['current_month'] ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // KPI cards
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10, crossAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            _KpiCard(label: 'Income', value: _fmt.format(totalIncome), icon: Icons.trending_up_rounded, color: const Color(0xFF22C55E)),
            _KpiCard(label: 'Expenses', value: _fmt.format(totalExpenses), icon: Icons.trending_down_rounded, color: Colors.red.shade500),
            _KpiCard(label: 'Net Cash Flow', value: _fmt.format(netCashFlow), icon: Icons.account_balance_wallet_rounded, color: netCashFlow >= 0 ? const Color(0xFF2DD4BF) : Colors.red),
            _KpiCard(label: 'Outstanding', value: _fmt.format(outstanding), icon: Icons.pending_actions_rounded, color: Colors.orange.shade600),
          ],
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 20),

        // Cash flow trend chart
        _SectionLabel('Cash Flow Trend'),
        const SizedBox(height: 8),
        _CashFlowChart(posTxns: posTxns, payments: payments, expenses: expenses),
        const SizedBox(height: 20),

        // Cash position by payment method
        _SectionLabel('Cash Position by Method'),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: methodMap.entries.map((e) {
                final pct = totalIncome > 0 ? (e.value / totalIncome * 100) : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(_methodLabel(e.key), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface)),
                      Text('${_fmtFull.format(e.value)} (${pct.toStringAsFixed(1)}%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: pct / 100, minHeight: 6, backgroundColor: cs.outlineVariant.withValues(alpha: 0.15), valueColor: AlwaysStoppedAnimation(_methodColor(e.key))),
                    ),
                  ]),
                );
              }).toList(),
            ),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
        const SizedBox(height: 20),

        // Top outstanding receivables
        _SectionLabel('Top Outstanding Receivables'),
        const SizedBox(height: 8),
        if (top5Receivables.isEmpty)
          _emptyCard('No outstanding receivables')
        else
          ...top5Receivables.map((inv) {
            final balance = _dbl(inv['total']) - _dbl(inv['amount_paid']);
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15))),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: cs.primaryContainer, child: Icon(Icons.receipt_long_rounded, color: cs.primary, size: 20)),
                title: Text(inv['invoice_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text(inv['patient_name'] ?? '', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                trailing: Text(_fmt.format(balance), style: TextStyle(fontWeight: FontWeight.w700, color: Colors.orange.shade700, fontSize: 13)),
              ),
            );
          }),
        const SizedBox(height: 20),

        // Top pending payables
        _SectionLabel('Top Pending Payables'),
        const SizedBox(height: 8),
        if (top5Payables.isEmpty)
          _emptyCard('No pending payables')
        else
          ...top5Payables.map((exp) => Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15))),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.red.withValues(alpha: 0.1), child: Icon(Icons.payment_rounded, color: Colors.red.shade600, size: 20)),
                  title: Text(exp['title'] ?? exp['description'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(exp['category_name'] ?? 'Other', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  trailing: Text(_fmt.format(_dbl(exp['amount'])), style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red.shade700, fontSize: 13)),
                ),
              )),
        const SizedBox(height: 20),

        // API usage
        _SectionLabel('API Usage & Billing'),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _infoRow('Requests this month', '${currentMonth['total_requests'] ?? 0}', cs),
              _infoRow('Cost so far', 'KSH ${currentMonth['cost_so_far'] ?? 0}', cs),
              _infoRow('Projected cost', 'KSH ${currentMonth['projected_cost'] ?? 0}', cs),
              _infoRow('Daily average', '${currentMonth['daily_average_so_far'] ?? 0}', cs),
            ]),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _emptyCard(String msg) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(padding: const EdgeInsets.all(20), child: Center(child: Text(msg, style: const TextStyle(fontSize: 13)))),
      );

  Widget _infoRow(String label, String value, ColorScheme cs) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface)),
        ]),
      );

  String _methodLabel(String m) {
    switch (m) {
      case 'cash': return 'Cash';
      case 'mpesa': return 'M-Pesa';
      case 'card': return 'Card';
      case 'bank_transfer': return 'Bank Transfer';
      case 'insurance': return 'Insurance';
      case 'cheque': return 'Cheque';
      case 'credit': return 'Credit';
      default: return m[0].toUpperCase() + m.substring(1);
    }
  }

  Color _methodColor(String m) {
    switch (m) {
      case 'cash': return const Color(0xFF22C55E);
      case 'mpesa': return const Color(0xFF4ADE80);
      case 'card': return const Color(0xFF3B82F6);
      case 'bank_transfer': return const Color(0xFF6366F1);
      case 'insurance': return const Color(0xFFF59E0B);
      case 'credit': return Colors.orange;
      default: return const Color(0xFF8B5CF6);
    }
  }
}

// ══════════════════════════════════════════
// 2. RECEIVABLES TAB
// ══════════════════════════════════════════
class _ReceivablesTab extends ConsumerWidget {
  final Map<String, dynamic> data;
  const _ReceivablesTab({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final invoices = data['invoices'] as List;
    final credits = data['credits'] as List;
    final now = DateTime.now();

    // Aging buckets
    int notDue = 0, bucket1_30 = 0, bucket31_60 = 0, bucket60plus = 0;
    for (final inv in invoices) {
      if (inv['status'] == 'PAID' || inv['status'] == 'CANCELLED') continue;
      final due = DateTime.tryParse(inv['due_date'] ?? '');
      if (due == null || due.isAfter(now)) {
        notDue++;
      } else {
        final days = now.difference(due).inDays;
        if (days <= 30) {
          bucket1_30++;
        } else if (days <= 60) {
          bucket31_60++;
        } else {
          bucket60plus++;
        }
      }
    }

    final unpaidInvoices = invoices.where((i) => i['status'] != 'PAID' && i['status'] != 'CANCELLED').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Aging cards
        Row(children: [
          Expanded(child: _AgingCard(label: 'Not Due', count: notDue, color: const Color(0xFF22C55E))),
          const SizedBox(width: 8),
          Expanded(child: _AgingCard(label: '1-30d', count: bucket1_30, color: Colors.orange)),
          const SizedBox(width: 8),
          Expanded(child: _AgingCard(label: '31-60d', count: bucket31_60, color: Colors.red.shade400)),
          const SizedBox(width: 8),
          Expanded(child: _AgingCard(label: '60d+', count: bucket60plus, color: Colors.red.shade700)),
        ]).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 20),

        // Invoices
        _SectionLabel('Invoices'),
        const SizedBox(height: 8),
        if (unpaidInvoices.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No outstanding invoices'))))
        else
          ...unpaidInvoices.map((inv) {
            final total = _dbl(inv['total']);
            final paid = _dbl(inv['amount_paid']);
            final balance = total - paid;
            final dueStr = inv['due_date'] ?? '';
            final due = DateTime.tryParse(dueStr);
            final isOverdue = due != null && due.isBefore(now);
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15))),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(inv['invoice_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(inv['patient_name'] ?? '', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    ])),
                    if (isOverdue)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text('Overdue', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.red.shade700)),
                      ),
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(8)),
                      child: Text(inv['status'] ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.primary)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    _miniStat('Total', _fmt.format(total), cs),
                    const SizedBox(width: 16),
                    _miniStat('Paid', _fmt.format(paid), cs),
                    const SizedBox(width: 16),
                    _miniStat('Balance', _fmt.format(balance), cs),
                    const Spacer(),
                    if (dueStr.isNotEmpty) Text('Due: ${_shortDate(dueStr)}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  ]),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showRecordPayment(context, ref, inv),
                      icon: const Icon(Icons.payment_rounded, size: 16),
                      label: const Text('Record Payment', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ]),
              ),
            );
          }),

        // POS Credit Sales
        if (credits.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionLabel('POS Credit Sales'),
          const SizedBox(height: 8),
          ...credits.map((c) {
            final total = _dbl(c['total_amount'] ?? c['total']);
            final paid = _dbl(c['amount_paid']);
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15))),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: Colors.blue.withValues(alpha: 0.1), child: Icon(Icons.credit_card, color: Colors.blue.shade600, size: 20)),
                title: Text(c['receipt_number'] ?? c['customer_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text(c['customer_name'] ?? '', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_fmt.format(total - paid), style: TextStyle(fontWeight: FontWeight.w700, color: Colors.orange.shade700, fontSize: 13)),
                  Text('of ${_fmt.format(total)}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ]),
              ),
            );
          }),
        ],
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _miniStat(String label, String val, ColorScheme cs) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
        Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface)),
      ]);

  void _showRecordPayment(BuildContext context, WidgetRef ref, Map inv) {
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    String method = 'cash';
    final cs = Theme.of(context).colorScheme;
    final balance = _dbl(inv['total']) - _dbl(inv['amount_paid']);
    amountCtrl.text = balance.toStringAsFixed(0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outline.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Record Payment', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            Text('Invoice ${inv['invoice_number']}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(labelText: 'Amount', prefixText: 'KSH '),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: method,
              decoration: const InputDecoration(labelText: 'Payment Method'),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'mpesa', child: Text('M-Pesa')),
                DropdownMenuItem(value: 'card', child: Text('Card')),
                DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                DropdownMenuItem(value: 'insurance', child: Text('Insurance')),
              ],
              onChanged: (v) => setSheetState(() => method = v!),
            ),
            const SizedBox(height: 12),
            TextField(controller: refCtrl, decoration: const InputDecoration(labelText: 'Reference (optional)')),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  try {
                    final dio = ref.read(dioProvider);
                    await dio.post('/billing/invoices/${inv['id']}/record_payment/', data: {
                      'amount': double.tryParse(amountCtrl.text) ?? 0,
                      'payment_method': method,
                      'reference': refCtrl.text,
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    ref.invalidate(_accountsDataProvider);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded')));
                  } catch (e) {
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('Record Payment'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  String _shortDate(String d) {
    final dt = DateTime.tryParse(d);
    if (dt == null) return d;
    return DateFormat('dd/MM/yy').format(dt);
  }
}

// ══════════════════════════════════════════
// 3. PAYABLES TAB
// ══════════════════════════════════════════
class _PayablesTab extends ConsumerWidget {
  final Map<String, dynamic> data;
  const _PayablesTab({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final expenses = data['expenses'] as List;
    final now = DateTime.now();

    int pending = 0, approved = 0, overdue = 0, paid = 0;
    for (final e in expenses) {
      final status = e['status'] ?? '';
      if (status == 'PENDING') pending++;
      if (status == 'APPROVED') approved++;
      if (status == 'PAID') paid++;
      final due = DateTime.tryParse(e['due_date'] ?? '');
      if (due != null && due.isBefore(now) && status != 'PAID' && status != 'REJECTED') overdue++;
    }

    final actionable = expenses.where((e) => e['status'] != 'PAID' && e['status'] != 'REJECTED').toList()
      ..sort((a, b) => _dbl(b['amount']).compareTo(_dbl(a['amount'])));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Bucket cards
        Row(children: [
          Expanded(child: _AgingCard(label: 'Pending', count: pending, color: Colors.orange)),
          const SizedBox(width: 8),
          Expanded(child: _AgingCard(label: 'Approved', count: approved, color: Colors.blue)),
          const SizedBox(width: 8),
          Expanded(child: _AgingCard(label: 'Overdue', count: overdue, color: Colors.red)),
          const SizedBox(width: 8),
          Expanded(child: _AgingCard(label: 'Paid', count: paid, color: const Color(0xFF22C55E))),
        ]).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 16),

        // Add expense button
        FilledButton.icon(
          onPressed: () => context.go('/expenses/add'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New Expense'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),

        if (actionable.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No actionable expenses'))))
        else
          ...actionable.map((exp) {
            final status = exp['status'] ?? '';
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15))),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(exp['title'] ?? exp['description'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('${exp['category_name'] ?? 'Other'} • ${exp['vendor_name'] ?? ''}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    ])),
                    Text(_fmt.format(_dbl(exp['amount'])), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.red.shade600)),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    _statusChip(status, cs),
                    if (exp['payment_method'] != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(8)),
                        child: Text(exp['payment_method'] ?? '', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                      ),
                    ],
                    const Spacer(),
                    Text(exp['date'] ?? '', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  ]),
                  const SizedBox(height: 10),
                  // Action buttons
                  Row(children: [
                    if (status == 'PENDING') ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _action(context, ref, exp['id'], 'approve'),
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF22C55E), side: const BorderSide(color: Color(0xFF22C55E)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          child: const Text('Approve', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _action(context, ref, exp['id'], 'reject'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          child: const Text('Reject', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                    if (status == 'APPROVED') ...[
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _action(context, ref, exp['id'], 'mark_paid'),
                          child: const Text('Mark as Paid', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ]),
                ]),
              ),
            );
          }),
        const SizedBox(height: 100),
      ],
    );
  }

  Future<void> _action(BuildContext context, WidgetRef ref, dynamic id, String action) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/expenses/expenses/$id/$action/');
      ref.invalidate(_accountsDataProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Expense ${action.replaceAll('_', ' ')}d')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _statusChip(String status, ColorScheme cs) {
    Color bg, fg;
    switch (status) {
      case 'PENDING':
        bg = Colors.orange.withValues(alpha: 0.1);
        fg = Colors.orange.shade700;
      case 'APPROVED':
        bg = Colors.blue.withValues(alpha: 0.1);
        fg = Colors.blue.shade700;
      case 'REJECTED':
        bg = Colors.red.withValues(alpha: 0.1);
        fg = Colors.red.shade700;
      default:
        bg = const Color(0xFF22C55E).withValues(alpha: 0.1);
        fg = const Color(0xFF22C55E);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

// ══════════════════════════════════════════
// 4. TRANSACTIONS TAB
// ══════════════════════════════════════════
class _TransactionsTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TransactionsTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final posTxns = data['posTxns'] as List;
    final payments = data['payments'] as List;
    final expenses = data['expenses'] as List;

    // Build unified ledger
    final List<Map<String, dynamic>> ledger = [];

    for (final t in posTxns) {
      ledger.add({
        'type': 'income',
        'date': t['created_at'] ?? t['date'] ?? '',
        'description': 'POS Sale #${t['receipt_number'] ?? t['id']}',
        'method': t['payment_method'] ?? 'cash',
        'reference': t['receipt_number'] ?? '',
        'amount': _dbl(t['total_amount'] ?? t['total']),
      });
    }
    for (final p in payments) {
      ledger.add({
        'type': 'income',
        'date': p['created_at'] ?? p['date'] ?? '',
        'description': 'Invoice Payment',
        'method': p['payment_method'] ?? 'cash',
        'reference': p['reference'] ?? '',
        'amount': _dbl(p['amount']),
      });
    }
    for (final e in expenses) {
      if (e['status'] == 'PAID') {
        ledger.add({
          'type': 'expense',
          'date': e['paid_at'] ?? e['date'] ?? '',
          'description': e['title'] ?? e['description'] ?? 'Expense',
          'method': e['payment_method'] ?? '',
          'reference': e['reference'] ?? '',
          'amount': _dbl(e['amount']),
        });
      }
    }

    ledger.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

    if (ledger.isEmpty) {
      return const Center(child: EmptyState(icon: Icons.receipt_long_rounded, title: 'No transactions'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: ledger.length,
      itemBuilder: (ctx, i) {
        final tx = ledger[i];
        final isIncome = tx['type'] == 'income';
        final amount = tx['amount'] as double;
        final dateStr = tx['date'] as String;
        final dt = DateTime.tryParse(dateStr);
        final formattedDate = dt != null ? DateFormat('dd MMM, HH:mm').format(dt) : dateStr;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.1))),
          child: ListTile(
            dense: true,
            leading: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isIncome ? const Color(0xFF22C55E).withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(isIncome ? 'IN' : 'OUT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isIncome ? const Color(0xFF22C55E) : Colors.red)),
            ),
            title: Text(tx['description'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Row(children: [
              Text(formattedDate, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              if ((tx['method'] as String).isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(4)),
                  child: Text(tx['method'] as String, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                ),
              ],
            ]),
            trailing: Text(
              '${isIncome ? '+' : '-'}${_fmt.format(amount)}',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isIncome ? const Color(0xFF22C55E) : Colors.red),
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════
// 5. PROFIT & LOSS TAB
// ══════════════════════════════════════════
class _ProfitLossTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ProfitLossTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final posTxns = data['posTxns'] as List;
    final payments = data['payments'] as List;
    final expenses = data['expenses'] as List;

    // Income breakdown
    final posRevenue = posTxns.fold<double>(0, (s, t) => s + _dbl(t['total_amount'] ?? t['total']));
    final posTax = posTxns.fold<double>(0, (s, t) => s + _dbl(t['tax'] ?? t['tax_amount'] ?? 0));
    final posDiscount = posTxns.fold<double>(0, (s, t) => s + _dbl(t['discount'] ?? t['discount_amount'] ?? 0));
    final invoicePayments = payments.fold<double>(0, (s, p) => s + _dbl(p['amount']));
    final grossIncome = posRevenue + invoicePayments;
    final netRevenue = grossIncome - posTax;

    // Expense breakdown by category
    final Map<String, double> expByCategory = {};
    double totalExp = 0;
    for (final e in expenses) {
      if (e['status'] == 'REJECTED') continue;
      final cat = e['category_name'] ?? 'Other';
      final amt = _dbl(e['amount']);
      expByCategory[cat] = (expByCategory[cat] ?? 0) + amt;
      totalExp += amt;
    }
    final sortedCats = expByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final netPL = netRevenue - totalExp;
    final margin = grossIncome > 0 ? (netPL / grossIncome * 100) : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // P&L Summary strip
        Card(
          elevation: 0,
          color: netPL >= 0 ? const Color(0xFF22C55E).withValues(alpha: 0.08) : Colors.red.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Text(netPL >= 0 ? 'Net Profit' : 'Net Loss', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(_fmt.format(netPL.abs()), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: netPL >= 0 ? const Color(0xFF22C55E) : Colors.red)),
              const SizedBox(height: 10),
              Wrap(spacing: 16, runSpacing: 8, alignment: WrapAlignment.center, children: [
                _plPill('Gross Income', _fmt.format(grossIncome), cs),
                _plPill('VAT', _fmt.format(posTax), cs),
                _plPill('Net Revenue', _fmt.format(netRevenue), cs),
                _plPill('Expenses', _fmt.format(totalExp), cs),
                _plPill('Margin', '${margin.toStringAsFixed(1)}%', cs),
              ]),
            ]),
          ),
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 20),

        // Income breakdown
        _SectionLabel('Income'),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _plRow('POS Sales', posRevenue, grossIncome, const Color(0xFF22C55E), cs),
              _plRow('Invoice Payments', invoicePayments, grossIncome, Colors.blue, cs),
              if (posTax > 0) ...[
                const Divider(height: 20),
                _plInfoRow('VAT Collected', '- ${_fmt.format(posTax)}', cs, color: Colors.orange),
              ],
              if (posDiscount > 0)
                _plInfoRow('Discounts Given', '- ${_fmt.format(posDiscount)}', cs, color: Colors.red),
              const Divider(height: 20),
              _plInfoRow('Net Revenue', _fmt.format(netRevenue), cs, bold: true),
            ]),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
        const SizedBox(height: 20),

        // Expense breakdown
        _SectionLabel('Expenses by Category'),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...sortedCats.map((e) => _plRow(e.key, e.value, totalExp, Colors.red.shade400, cs)),
                if (sortedCats.isEmpty) Center(child: Text('No expenses', style: TextStyle(color: cs.onSurfaceVariant))),
                const Divider(height: 20),
                _plInfoRow('Total Expenses', _fmt.format(totalExp), cs, bold: true),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _plPill(String label, String value, ColorScheme cs) => Column(children: [
        Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface)),
      ]);

  Widget _plRow(String label, double value, double total, Color barColor, ColorScheme cs) {
    final pct = total > 0 ? (value / total * 100) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: cs.onSurface))),
          Text('${_fmt.format(value)} (${pct.toStringAsFixed(1)}%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: pct / 100, minHeight: 5, backgroundColor: cs.outlineVariant.withValues(alpha: 0.15), valueColor: AlwaysStoppedAnimation(barColor)),
        ),
      ]),
    );
  }

  Widget _plInfoRow(String label, String value, ColorScheme cs, {Color? color, bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: cs.onSurface)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color ?? cs.onSurface)),
        ]),
      );
}

// ══════════════════════════════════════════
// Cash Flow Chart Widget
// ══════════════════════════════════════════
class _CashFlowChart extends StatelessWidget {
  final List posTxns;
  final List payments;
  final List expenses;
  const _CashFlowChart({required this.posTxns, required this.payments, required this.expenses});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Aggregate daily income & expense
    final Map<String, double> dailyIncome = {};
    final Map<String, double> dailyExpense = {};

    for (final t in posTxns) {
      final d = _dateOnly(t['created_at'] ?? t['date'] ?? '');
      if (d.isEmpty) continue;
      dailyIncome[d] = (dailyIncome[d] ?? 0) + _dbl(t['total_amount'] ?? t['total']);
    }
    for (final p in payments) {
      final d = _dateOnly(p['created_at'] ?? p['date'] ?? '');
      if (d.isEmpty) continue;
      dailyIncome[d] = (dailyIncome[d] ?? 0) + _dbl(p['amount']);
    }
    for (final e in expenses) {
      if (e['status'] != 'PAID') continue;
      final d = _dateOnly(e['paid_at'] ?? e['date'] ?? '');
      if (d.isEmpty) continue;
      dailyExpense[d] = (dailyExpense[d] ?? 0) + _dbl(e['amount']);
    }

    final allDates = {...dailyIncome.keys, ...dailyExpense.keys}.toList()..sort();
    if (allDates.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
        child: const SizedBox(height: 100, child: Center(child: Text('No data for this period'))),
      );
    }

    final incomeSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];
    for (int i = 0; i < allDates.length; i++) {
      incomeSpots.add(FlSpot(i.toDouble(), dailyIncome[allDates[i]] ?? 0));
      expenseSpots.add(FlSpot(i.toDouble(), dailyExpense[allDates[i]] ?? 0));
    }

    double maxY = 0;
    for (final s in incomeSpots) { if (s.y > maxY) maxY = s.y; }
    for (final s in expenseSpots) { if (s.y > maxY) maxY = s.y; }
    if (maxY == 0) maxY = 100;
    final double interval = (maxY / 4).ceilToDouble().clamp(1.0, double.infinity);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _legendDot(const Color(0xFF22C55E), 'Income'),
            const SizedBox(width: 16),
            _legendDot(Colors.red, 'Expenses'),
          ]),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            const double minSpacing = 48;
            final chartWidth = allDates.length > 7
                ? (allDates.length * minSpacing).clamp(constraints.maxWidth, double.infinity)
                : constraints.maxWidth;

            final chart = SizedBox(
              width: chartWidth,
              height: 180,
              child: LineChart(LineChartData(
                maxY: maxY * 1.15,
                gridData: FlGridData(
                  show: true, drawVerticalLine: false,
                  horizontalInterval: interval,
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
                      if (idx < 0 || idx >= allDates.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(DateFormat('dd/MM').format(DateTime.parse(allDates[idx])), style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
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
                      TextStyle(color: s.barIndex == 0 ? const Color(0xFF22C55E) : Colors.red, fontWeight: FontWeight.w600, fontSize: 12),
                    )).toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: incomeSpots, isCurved: true, preventCurveOverShooting: true,
                    color: const Color(0xFF22C55E), barWidth: 2.5, isStrokeCapRound: true,
                    belowBarData: BarAreaData(show: true, gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [const Color(0xFF22C55E).withValues(alpha: 0.2), const Color(0xFF22C55E).withValues(alpha: 0.0)],
                    )),
                    dotData: FlDotData(show: allDates.length <= 14),
                  ),
                  LineChartBarData(
                    spots: expenseSpots, isCurved: true, preventCurveOverShooting: true,
                    color: Colors.red, barWidth: 2.5, isStrokeCapRound: true,
                    belowBarData: BarAreaData(show: true, gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.red.withValues(alpha: 0.15), Colors.red.withValues(alpha: 0.0)],
                    )),
                    dotData: FlDotData(show: allDates.length <= 14),
                  ),
                ],
              )),
            );

            if (chartWidth > constraints.maxWidth) {
              return SizedBox(height: 200, child: SingleChildScrollView(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), child: chart));
            }
            return chart;
          }),
        ]),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 50.ms);
  }

  Widget _legendDot(Color c, String label) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 6),
    Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
  ]);

  String _dateOnly(String s) {
    if (s.isEmpty) return '';
    return s.length >= 10 ? s.substring(0, 10) : s;
  }
}

// ══════════════════════════════════════════
// 6. BALANCE SHEET TAB
// ══════════════════════════════════════════
class _BalanceSheetTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _BalanceSheetTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final invoices = data['invoices'] as List;
    final expenses = data['expenses'] as List;
    final credits = data['credits'] as List;
    final posTxns = data['posTxns'] as List;
    final payments = data['payments'] as List;
    final billing = data['billing'] as Map;
    final inventory = data['inventory'] as Map;

    // ── ASSETS ──
    // Cash & equivalents by method
    final Map<String, double> cashByMethod = {};
    for (final t in posTxns) {
      final m = (t['payment_method'] ?? 'cash').toString().toLowerCase();
      cashByMethod[m] = (cashByMethod[m] ?? 0) + _dbl(t['total_amount'] ?? t['total']);
    }
    for (final p in payments) {
      final m = (p['payment_method'] ?? 'cash').toString().toLowerCase();
      cashByMethod[m] = (cashByMethod[m] ?? 0) + _dbl(p['amount']);
    }
    // Subtract paid expenses
    for (final e in expenses) {
      if (e['status'] == 'PAID') {
        final m = (e['payment_method'] ?? 'cash').toString().toLowerCase();
        cashByMethod[m] = (cashByMethod[m] ?? 0) - _dbl(e['amount']);
      }
    }
    final totalCash = cashByMethod.values.fold<double>(0, (s, v) => s + v);

    // Accounts receivable
    double arCurrent = 0, arOverdue = 0;
    final now = DateTime.now();
    for (final inv in invoices) {
      if (inv['status'] == 'PAID' || inv['status'] == 'CANCELLED') continue;
      final bal = _dbl(inv['total']) - _dbl(inv['amount_paid']);
      final due = DateTime.tryParse(inv['due_date'] ?? '');
      if (due != null && due.isBefore(now)) {
        arOverdue += bal;
      } else {
        arCurrent += bal;
      }
    }
    for (final c in credits) {
      arCurrent += _dbl(c['total_amount'] ?? c['total']) - _dbl(c['amount_paid']);
    }
    final totalAR = arCurrent + arOverdue;

    // Inventory
    final inventoryCost = _dbl(inventory['cost_value']);
    final inventoryRetail = _dbl(inventory['sale_value']);

    final totalAssets = totalCash + totalAR + inventoryCost;

    // ── LIABILITIES ──
    // Accounts payable
    double apVendor = 0;
    for (final e in expenses) {
      if (e['status'] != 'PAID' && e['status'] != 'REJECTED') {
        apVendor += _dbl(e['amount']);
      }
    }
    // API bills outstanding
    final recentBills = (billing['recent_bills'] as List?) ?? [];
    double apBills = 0;
    for (final b in recentBills) {
      if (b['status'] != 'PAID') apBills += _dbl(b['amount'] ?? b['cost']);
    }

    // VAT collected
    final vatCollected = posTxns.fold<double>(0, (s, t) => s + _dbl(t['tax'] ?? t['tax_amount'] ?? 0));

    final totalLiabilities = apVendor + apBills + vatCollected;

    // ── EQUITY ──
    final equity = totalAssets - totalLiabilities;

    // Ratios
    final currentRatio = totalLiabilities > 0 ? (totalAssets / totalLiabilities) : 0.0;
    final debtEquity = equity > 0 ? (totalLiabilities / equity) : 0.0;
    final netMargin = (totalCash + totalAR) > 0 ? (equity / (totalCash + totalAR) * 100) : 0.0;
    final arDays = totalAR > 0 && totalCash > 0 ? (totalAR / (totalCash / 30)).clamp(0.0, 999.0) : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Equation strip
        Card(
          elevation: 0,
          color: cs.primaryContainer.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(child: _eqCol('Assets', totalAssets, cs)),
              Text('=', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: cs.primary)),
              Expanded(child: _eqCol('Liabilities', totalLiabilities, cs)),
              Text('+', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: cs.primary)),
              Expanded(child: _eqCol('Equity', equity, cs)),
            ]),
          ),
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 20),

        // Assets
        _SectionLabel('Assets'),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _bsHeader('Cash & Equivalents', _fmt.format(totalCash), cs),
              ...cashByMethod.entries.map((e) => _bsRow(_methodLabel(e.key), _fmt.format(e.value), cs)),
              const Divider(height: 20),
              _bsHeader('Accounts Receivable', _fmt.format(totalAR), cs),
              _bsRow('Current', _fmt.format(arCurrent), cs),
              _bsRow('Overdue', _fmt.format(arOverdue), cs, color: Colors.red),
              const Divider(height: 20),
              _bsHeader('Inventory', _fmt.format(inventoryCost), cs),
              _bsRow('At cost', _fmt.format(inventoryCost), cs),
              _bsRow('At retail', _fmt.format(inventoryRetail), cs, color: const Color(0xFF22C55E)),
              const Divider(height: 20),
              _bsTotal('Total Assets', totalAssets, cs),
            ]),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
        const SizedBox(height: 16),

        // Liabilities
        _SectionLabel('Liabilities'),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _bsRow('Accounts Payable (Vendors)', _fmt.format(apVendor), cs),
              _bsRow('Accounts Payable (API Bills)', _fmt.format(apBills), cs),
              _bsRow('VAT Collected', _fmt.format(vatCollected), cs),
              const Divider(height: 20),
              _bsTotal('Total Liabilities', totalLiabilities, cs),
            ]),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
        const SizedBox(height: 16),

        // Equity
        _SectionLabel('Equity'),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _bsTotal('Total Equity', equity, cs),
            ]),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
        const SizedBox(height: 20),

        // Financial Ratios
        _SectionLabel('Financial Health Ratios'),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10, crossAxisSpacing: 10,
          childAspectRatio: 1.8,
          children: [
            _RatioCard(label: 'Current Ratio', value: currentRatio.toStringAsFixed(2), good: currentRatio >= 1),
            _RatioCard(label: 'Debt / Equity', value: debtEquity.toStringAsFixed(2), good: debtEquity < 1),
            _RatioCard(label: 'Net Margin', value: '${netMargin.toStringAsFixed(1)}%', good: netMargin > 0),
            _RatioCard(label: 'AR Days', value: arDays.toStringAsFixed(0), good: arDays < 45),
          ],
        ).animate().fadeIn(duration: 400.ms, delay: 250.ms),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _eqCol(String label, double value, ColorScheme cs) => Column(children: [
    Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
    const SizedBox(height: 2),
    Text(_fmt.format(value), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface)),
  ]);

  Widget _bsHeader(String label, String value, ColorScheme cs) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.onSurface)),
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.primary)),
    ]),
  );

  Widget _bsRow(String label, String value, ColorScheme cs, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('  $label', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color ?? cs.onSurface)),
    ]),
  );

  Widget _bsTotal(String label, double value, ColorScheme cs) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface)),
      Text(_fmt.format(value), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: cs.primary)),
    ],
  );

  String _methodLabel(String m) {
    switch (m) {
      case 'cash': return 'Cash';
      case 'mpesa': return 'M-Pesa';
      case 'card': return 'Card';
      case 'bank_transfer': return 'Bank Transfer';
      case 'insurance': return 'Insurance';
      default: return m[0].toUpperCase() + m.substring(1);
    }
  }
}

// ══════════════════════════════════════════
// 7. GENERAL LEDGER TAB
// ══════════════════════════════════════════
class _GeneralLedgerTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _GeneralLedgerTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final posTxns = data['posTxns'] as List;
    final payments = data['payments'] as List;
    final expenses = data['expenses'] as List;
    final invoices = data['invoices'] as List;
    final inventory = data['inventory'] as Map;

    // Chart of accounts structure
    // Cash & Bank, Accounts Receivable, Inventory, AP, VAT, Sales Revenue, COGS, Operating Expenses
    final posRevenue = posTxns.fold<double>(0, (s, t) => s + _dbl(t['total_amount'] ?? t['total']));
    final invoiceRevenue = payments.fold<double>(0, (s, p) => s + _dbl(p['amount']));
    final posTax = posTxns.fold<double>(0, (s, t) => s + _dbl(t['tax'] ?? t['tax_amount'] ?? 0));
    final totalExpPaid = expenses.where((e) => e['status'] == 'PAID').fold<double>(0, (s, e) => s + _dbl(e['amount']));
    final totalExpPending = expenses.where((e) => e['status'] != 'PAID' && e['status'] != 'REJECTED').fold<double>(0, (s, e) => s + _dbl(e['amount']));
    final arTotal = invoices.where((i) => i['status'] != 'PAID' && i['status'] != 'CANCELLED')
        .fold<double>(0, (s, i) => s + _dbl(i['total']) - _dbl(i['amount_paid']));
    final invCost = _dbl(inventory['cost_value']);

    // Trial balance entries
    final accounts = <_LedgerAccount>[
      _LedgerAccount('Cash & Bank', posRevenue + invoiceRevenue - totalExpPaid, 0, 'Asset'),
      _LedgerAccount('Accounts Receivable', arTotal, 0, 'Asset'),
      _LedgerAccount('Inventory', invCost, 0, 'Asset'),
      _LedgerAccount('Accounts Payable', 0, totalExpPending, 'Liability'),
      _LedgerAccount('VAT Payable', 0, posTax, 'Liability'),
      _LedgerAccount('Sales Revenue', 0, posRevenue + invoiceRevenue, 'Revenue'),
      _LedgerAccount('Operating Expenses', totalExpPaid, 0, 'Expense'),
    ];

    final totalDebit = accounts.fold<double>(0, (s, a) => s + a.debit);
    final totalCredit = accounts.fold<double>(0, (s, a) => s + a.credit);

    // Journal entries
    final List<Map<String, dynamic>> journal = [];
    for (final t in posTxns) {
      final amt = _dbl(t['total_amount'] ?? t['total']);
      final tax = _dbl(t['tax'] ?? t['tax_amount'] ?? 0);
      journal.add({'date': t['created_at'] ?? t['date'] ?? '', 'ref': 'POS #${t['receipt_number'] ?? t['id']}', 'source': 'POS', 'desc': 'POS Sale', 'account': 'Cash & Bank', 'debit': amt, 'credit': 0.0});
      journal.add({'date': t['created_at'] ?? t['date'] ?? '', 'ref': 'POS #${t['receipt_number'] ?? t['id']}', 'source': 'POS', 'desc': 'POS Sale', 'account': 'Sales Revenue', 'debit': 0.0, 'credit': amt - tax});
      if (tax > 0) {
        journal.add({'date': t['created_at'] ?? t['date'] ?? '', 'ref': 'POS #${t['receipt_number'] ?? t['id']}', 'source': 'POS', 'desc': 'VAT', 'account': 'VAT Payable', 'debit': 0.0, 'credit': tax});
      }
    }
    for (final p in payments) {
      final amt = _dbl(p['amount']);
      journal.add({'date': p['created_at'] ?? p['date'] ?? '', 'ref': p['reference'] ?? '', 'source': 'Invoice', 'desc': 'Invoice Payment', 'account': 'Cash & Bank', 'debit': amt, 'credit': 0.0});
      journal.add({'date': p['created_at'] ?? p['date'] ?? '', 'ref': p['reference'] ?? '', 'source': 'Invoice', 'desc': 'Invoice Payment', 'account': 'Accounts Receivable', 'debit': 0.0, 'credit': amt});
    }
    for (final e in expenses) {
      if (e['status'] == 'PAID') {
        final amt = _dbl(e['amount']);
        journal.add({'date': e['paid_at'] ?? e['date'] ?? '', 'ref': e['reference'] ?? '', 'source': 'Expense', 'desc': e['title'] ?? e['description'] ?? 'Expense', 'account': 'Operating Expenses', 'debit': amt, 'credit': 0.0});
        journal.add({'date': e['paid_at'] ?? e['date'] ?? '', 'ref': e['reference'] ?? '', 'source': 'Expense', 'desc': e['title'] ?? e['description'] ?? 'Expense', 'account': 'Cash & Bank', 'debit': 0.0, 'credit': amt});
      }
    }
    journal.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

    // Debit vs Credit bar chart data
    final barData = accounts.where((a) => a.debit > 0 || a.credit > 0).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Trial Balance
        _SectionLabel('Trial Balance'),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // Header
              Row(children: [
                Expanded(flex: 3, child: Text('Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant))),
                Expanded(flex: 2, child: Text('Debit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('Credit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('Net', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant), textAlign: TextAlign.right)),
              ]),
              const Divider(height: 16),
              ...accounts.map((a) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(flex: 3, child: Text(a.name, style: TextStyle(fontSize: 13, color: cs.onSurface))),
                  Expanded(flex: 2, child: Text(a.debit > 0 ? _fmtFull.format(a.debit) : '-', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant), textAlign: TextAlign.right)),
                  Expanded(flex: 2, child: Text(a.credit > 0 ? _fmtFull.format(a.credit) : '-', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant), textAlign: TextAlign.right)),
                  Expanded(flex: 2, child: Text(_fmtFull.format(a.debit - a.credit), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: (a.debit - a.credit) >= 0 ? const Color(0xFF22C55E) : Colors.red), textAlign: TextAlign.right)),
                ]),
              )),
              const Divider(height: 16),
              Row(children: [
                Expanded(flex: 3, child: Text('Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cs.onSurface))),
                Expanded(flex: 2, child: Text(_fmtFull.format(totalDebit), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurface), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(_fmtFull.format(totalCredit), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurface), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(_fmtFull.format(totalDebit - totalCredit), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.primary), textAlign: TextAlign.right)),
              ]),
            ]),
          ),
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 20),

        // Debit vs Credit chart
        _SectionLabel('Debit vs Credit'),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _legendDot(const Color(0xFF3B82F6), 'Debit'),
                const SizedBox(width: 16),
                _legendDot(const Color(0xFFF59E0B), 'Credit'),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: BarChart(BarChartData(
                  barGroups: List.generate(barData.length, (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(toY: barData[i].debit, width: 12, color: const Color(0xFF3B82F6), borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4))),
                      BarChartRodData(toY: barData[i].credit, width: 12, color: const Color(0xFFF59E0B), borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4))),
                    ],
                  )),
                  gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant.withValues(alpha: 0.15), strokeWidth: 1)),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: (v, _) => Text(NumberFormat.compact().format(v), style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)))),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= barData.length) return const SizedBox();
                      return Padding(padding: const EdgeInsets.only(top: 6), child: Text(barData[idx].shortName, style: TextStyle(fontSize: 8, color: cs.onSurfaceVariant), textAlign: TextAlign.center));
                    })),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => cs.surface,
                      getTooltipItem: (group, _, rod, rodIdx) => BarTooltipItem(
                        '${rodIdx == 0 ? 'Dr' : 'Cr'}: ${_fmtFull.format(rod.toY)}',
                        TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600, fontSize: 11),
                      ),
                    ),
                  ),
                )),
              ),
            ]),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
        const SizedBox(height: 20),

        // Journal Entries
        _SectionLabel('Journal Entries'),
        const SizedBox(height: 8),
        if (journal.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No journal entries'))))
        else
          ...journal.take(50).map((j) {
            final isDebit = (j['debit'] as double) > 0;
            final amount = isDebit ? j['debit'] as double : j['credit'] as double;
            final dateStr = j['date'] as String;
            final dt = DateTime.tryParse(dateStr);
            final fmtDate = dt != null ? DateFormat('dd MMM').format(dt) : dateStr;
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.1))),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  SizedBox(width: 48, child: Text(fmtDate, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: _sourceColor(j['source'] as String).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(j['source'] as String, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _sourceColor(j['source'] as String))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(j['desc'] as String, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(j['account'] as String, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    if (isDebit)
                      Text('Dr ${_fmtFull.format(amount)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6)))
                    else
                      Text('Cr ${_fmtFull.format(amount)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B))),
                  ]),
                ]),
              ),
            );
          }),

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _legendDot(Color c, String label) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 6),
    Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
  ]);

  Color _sourceColor(String s) {
    switch (s) {
      case 'POS': return const Color(0xFF22C55E);
      case 'Invoice': return const Color(0xFF3B82F6);
      case 'Expense': return Colors.red;
      default: return Colors.grey;
    }
  }
}

class _LedgerAccount {
  final String name;
  final double debit;
  final double credit;
  final String type;
  const _LedgerAccount(this.name, this.debit, this.credit, this.type);

  String get shortName {
    if (name.length <= 8) return name;
    return name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').join();
  }
}

class _RatioCard extends StatelessWidget {
  final String label;
  final String value;
  final bool good;
  const _RatioCard({required this.label, required this.value, required this.good});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: good ? const Color(0xFF22C55E) : Colors.orange.shade600)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════
// Shared Widgets
// ══════════════════════════════════════════
class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cs.onSurface, letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

class _AgingCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _AgingCard({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(children: [
          Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface));
}
