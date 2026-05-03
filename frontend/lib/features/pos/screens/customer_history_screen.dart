import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/models/paginated_response.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../../../core/widgets/empty_state_widget.dart';
import '../../pos/models/pos_transaction_model.dart';
import '../../pos/repository/pos_repository.dart';

class CustomerHistoryScreen extends ConsumerStatefulWidget {
  final String customerPhone;
  final String customerName;

  const CustomerHistoryScreen({
    super.key,
    required this.customerPhone,
    required this.customerName,
  });

  @override
  ConsumerState<CustomerHistoryScreen> createState() =>
      _CustomerHistoryScreenState();
}

class _CustomerHistoryScreenState
    extends ConsumerState<CustomerHistoryScreen> {
  final _repo = POSRepository();

  PaginatedResponse<POSTransaction>? _data;
  bool _loading = true;
  String? _error;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repo.getTransactions(
        page: _page,
        search: widget.customerPhone,
      );
      if (mounted) {
        setState(() {
          _data = result;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  double get _totalSpend {
    if (_data == null) return 0;
    return _data!.results
        .fold<double>(0, (sum, t) => sum + t.totalAmount);
  }

  int get _totalItems {
    if (_data == null) return 0;
    return _data!.results
        .fold<int>(0, (sum, t) => sum + t.items.length);
  }

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

  String _formatCurrency(double amount) =>
      'KSh ${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},')}';

  Color _paymentColor(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return AppColors.success;
      case 'mpesa':
        return AppColors.primary;
      case 'card':
        return AppColors.secondary;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.customerName.isNotEmpty
        ? widget.customerName
            .trim()
            .split(' ')
            .take(2)
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
            .join()
        : '?';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.customerName,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text(widget.customerPhone,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 14)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 24),

          // Summary cards
          if (!_loading && _data != null)
            LayoutBuilder(builder: (context, constraints) {
              final cardWidth = constraints.maxWidth > 800
                  ? (constraints.maxWidth - 32) / 3
                  : constraints.maxWidth > 500
                      ? (constraints.maxWidth - 16) / 2
                      : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _SummaryCard(
                      icon: Icons.receipt_long,
                      label: 'Total Transactions',
                      value: '${_data!.count}',
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _SummaryCard(
                      icon: Icons.attach_money,
                      label: 'Total Spend (this page)',
                      value: _formatCurrency(_totalSpend),
                      color: AppColors.success,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _SummaryCard(
                      icon: Icons.medication_outlined,
                      label: 'Items Purchased',
                      value: '$_totalItems',
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              );
            }),

          const SizedBox(height: 24),

          // Transaction timeline
          Text('Transaction History',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          if (_loading)
            const Center(child: LoadingWidget())
          else if (_error != null)
            app_error.AppErrorWidget(
                message: _error!, onRetry: _loadData)
          else if (_data == null || _data!.results.isEmpty)
            const EmptyStateWidget(
              icon: Icons.receipt_long_outlined,
              title: 'No Transactions Found',
              subtitle: 'No purchase history for this customer.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _data!.results.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final tx = _data!.results[i];
                return _TransactionCard(
                  transaction: tx,
                  formatDate: _formatDate,
                  formatCurrency: _formatCurrency,
                  paymentColor: _paymentColor,
                );
              },
            ),

          // Pagination
          if (_data != null &&
              (_data!.previous != null || _data!.next != null))
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _data!.previous != null
                        ? () {
                            setState(() => _page--);
                            _loadData();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Page $_page',
                      style:
                          const TextStyle(fontWeight: FontWeight.w500)),
                  IconButton(
                    onPressed: _data!.next != null
                        ? () {
                            setState(() => _page++);
                            _loadData();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Summary Card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: color)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Transaction Card ─────────────────────────────────────────────────────────

class _TransactionCard extends StatefulWidget {
  final POSTransaction transaction;
  final String Function(String?) formatDate;
  final String Function(double) formatCurrency;
  final Color Function(String) paymentColor;

  const _TransactionCard({
    required this.transaction,
    required this.formatDate,
    required this.formatCurrency,
    required this.paymentColor,
  });

  @override
  State<_TransactionCard> createState() => _TransactionCardState();
}

class _TransactionCardState extends State<_TransactionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final color = widget.paymentColor(tx.paymentMethod);

    return Card(
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.receipt_outlined,
                      color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.receiptNumber ?? '#${tx.id}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        widget.formatDate(tx.createdAt),
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      widget.formatCurrency(tx.totalAmount),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        tx.paymentMethod.toUpperCase(),
                        style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary,
                ),
              ]),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ...tx.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Icon(Icons.medication_outlined,
                              size: 14,
                              color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.medicationName ?? 'Unknown',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text(
                            '${item.quantity} × ${widget.formatCurrency(item.unitPrice)}',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.formatCurrency(item.lineTotal),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                        ]),
                      )),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Served by: ${tx.servedBy ?? '-'}',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
