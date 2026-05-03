import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/models/paginated_response.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/search_field.dart';
import '../models/purchase_order_model.dart';
import '../repository/purchase_order_repository.dart';

class PurchaseOrderListScreen extends ConsumerStatefulWidget {
  const PurchaseOrderListScreen({super.key});

  @override
  ConsumerState<PurchaseOrderListScreen> createState() =>
      _PurchaseOrderListScreenState();
}

class _PurchaseOrderListScreenState
    extends ConsumerState<PurchaseOrderListScreen> {
  final _repo = PurchaseOrderRepository();
  PaginatedResponse<PurchaseOrder>? _data;
  bool _loading = true;
  String? _error;
  int _page = 1;
  String _search = '';
  String? _statusFilter;

  static const _statuses = ['draft', 'submitted', 'approved', 'received', 'cancelled'];

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
      final result = await _repo.getPurchaseOrders(
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

  String _formatCurrency(double amount) {
    return 'KSh ${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},')}';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return AppColors.textSecondary;
      case 'submitted':
        return AppColors.warning;
      case 'approved':
        return AppColors.primary;
      case 'received':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

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
                      'Purchase Orders',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage medication purchase orders',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.push('/purchase-orders/new'),
                icon: const Icon(Icons.add),
                label: const Text('Create PO'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SearchField(
                  hintText: 'Search purchase orders...',
                  onChanged: (value) {
                    _search = value;
                    _page = 1;
                    _loadData();
                  },
                ),
              ),
              const SizedBox(width: 16),
              DropdownButtonHideUnderline(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    hint: const Text('All Statuses'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('All Statuses')),
                      ..._statuses.map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s[0].toUpperCase() + s.substring(1)))),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _statusFilter = val;
                        _page = 1;
                      });
                      _loadData();
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const LoadingWidget()
                : _error != null
                    ? app_error.AppErrorWidget(
                        message: _error!,
                        onRetry: _loadData,
                      )
                    : _data == null || _filteredResults.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.receipt_long_outlined,
                            title: 'No purchase orders found',
                            subtitle:
                                'Create a purchase order to get started.',
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
                                          DataColumn(
                                              label: Text('PO Number',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600))),
                                          DataColumn(
                                              label: Text('Supplier',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600))),
                                          DataColumn(
                                              label: Text('Total Amount',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600))),
                                          DataColumn(
                                              label: Text('Status',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600))),
                                          DataColumn(
                                              label: Text('Date',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600))),
                                          DataColumn(
                                              label: Text('Actions',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600))),
                                        ],
                                        rows: _filteredResults
                                            .map(_buildRow)
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_data!.count > _data!.results.length)
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        TextButton(
                                          onPressed: _data!.previous != null
                                              ? () {
                                                  _page--;
                                                  _loadData();
                                                }
                                              : null,
                                          child: const Text('Previous'),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16),
                                          child: Text('Page $_page'),
                                        ),
                                        TextButton(
                                          onPressed: _data!.next != null
                                              ? () {
                                                  _page++;
                                                  _loadData();
                                                }
                                              : null,
                                          child: const Text('Next'),
                                        ),
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

  List<PurchaseOrder> get _filteredResults {
    if (_data == null) return [];
    if (_statusFilter == null) return _data!.results;
    return _data!.results
        .where((po) => po.status.toLowerCase() == _statusFilter)
        .toList();
  }

  DataRow _buildRow(PurchaseOrder po) {
    final color = _statusColor(po.status);
    return DataRow(cells: [
      DataCell(Text(po.poNumber ?? '-')),
      DataCell(Text(po.supplierName ?? '-')),
      DataCell(Text(_formatCurrency(po.totalAmount))),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            po.status[0].toUpperCase() + po.status.substring(1),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      DataCell(Text(_formatDate(po.createdAt))),
      DataCell(
        IconButton(
          icon: const Icon(Icons.visibility_outlined, size: 20),
          onPressed: () => context.push('/purchase-orders/${po.id}'),
          tooltip: 'View',
        ),
      ),
    ]);
  }
}
