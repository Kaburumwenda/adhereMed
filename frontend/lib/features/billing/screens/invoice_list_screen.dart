import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/models/paginated_response.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/invoice_model.dart';
import '../repository/billing_repository.dart';

class InvoiceListScreen extends ConsumerStatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  ConsumerState<InvoiceListScreen> createState() =>
      _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  final _repo = BillingRepository();
  PaginatedResponse<Invoice>? _data;
  bool _loading = true;
  String? _error;
  int _page = 1;
  String _search = '';

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
      final result = await _repo.getList(
        page: _page,
        search: _search.isEmpty ? null : _search,
      );
      setState(() {
        _data = result;
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
      'KSh ${amount.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invoices',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage billing and invoices',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.push('/billing/new'),
                icon: const Icon(Icons.add),
                label: const Text('New Invoice'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SearchField(
            hintText: 'Search invoices...',
            onChanged: (value) {
              _search = value;
              _page = 1;
              _loadData();
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const LoadingWidget()
                : _error != null
                    ? app_error.AppErrorWidget(
                        message: _error!, onRetry: _loadData)
                    : _data == null || _data!.results.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.receipt_long_outlined,
                            title: 'No invoices found',
                          )
                        : Card(
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
                                        columns: const [
                                          DataColumn(label: Text('Invoice #', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Patient', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                                          DataColumn(label: Text('Paid', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                                          DataColumn(label: Text('Balance', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600))),
                                        ],
                                        rows: _data!.results.map((inv) {
                                          return DataRow(cells: [
                                            DataCell(Text(inv.invoiceNumber ?? '#${inv.id}')),
                                            DataCell(Text(inv.patientName ?? 'ID: ${inv.patientId}')),
                                            DataCell(Text(_formatCurrency(inv.totalAmount))),
                                            DataCell(Text(_formatCurrency(inv.amountPaid))),
                                            DataCell(Text(
                                              _formatCurrency(inv.balanceDue),
                                              style: TextStyle(
                                                color: inv.balanceDue > 0
                                                    ? AppColors.error
                                                    : AppColors.success,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            )),
                                            DataCell(StatusBadge(status: inv.status)),
                                            DataCell(Text(inv.createdAt?.split('T').first ?? '-')),
                                            DataCell(Row(children: [
                                              IconButton(
                                                icon: const Icon(Icons.visibility_outlined, size: 20),
                                                onPressed: () => context.push('/billing/${inv.id}'),
                                                tooltip: 'View',
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined, size: 20),
                                                onPressed: () => context.push('/billing/${inv.id}/edit'),
                                                tooltip: 'Edit',
                                              ),
                                              if (inv.balanceDue > 0)
                                                IconButton(
                                                  icon: Icon(Icons.payment_outlined, size: 20, color: AppColors.success),
                                                  onPressed: () => context.push('/billing/${inv.id}'),
                                                  tooltip: 'Pay',
                                                ),
                                              IconButton(
                                                icon: Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                                                onPressed: () => _deleteInvoice(inv),
                                                tooltip: 'Delete',
                                              ),
                                            ])),
                                          ]);
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${_data!.count} total records',
                                          style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 13)),
                                      Row(children: [
                                        TextButton(
                                          onPressed: _data!.previous != null
                                              ? () {
                                                  _page--;
                                                  _loadData();
                                                }
                                              : null,
                                          child: const Text('Previous'),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('Page $_page',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w500)),
                                        const SizedBox(width: 8),
                                        TextButton(
                                          onPressed: _data!.next != null
                                              ? () {
                                                  _page++;
                                                  _loadData();
                                                }
                                              : null,
                                          child: const Text('Next'),
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

  Future<void> _deleteInvoice(Invoice inv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: Text('Delete invoice ${inv.invoiceNumber ?? '#${inv.id}'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await _repo.delete(inv.id);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invoice deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
