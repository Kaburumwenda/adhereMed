import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../models/purchase_order_model.dart';
import '../repository/purchase_order_repository.dart';

class PurchaseOrderDetailScreen extends ConsumerStatefulWidget {
  final int orderId;
  const PurchaseOrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<PurchaseOrderDetailScreen> createState() =>
      _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState
    extends ConsumerState<PurchaseOrderDetailScreen> {
  final _repo = PurchaseOrderRepository();
  PurchaseOrder? _order;
  bool _loading = true;
  String? _error;

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
      final order = await _repo.getPurchaseOrder(widget.orderId);
      setState(() {
        _order = order;
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

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return dateStr;
    }
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingWidget();
    if (_error != null) {
      return app_error.AppErrorWidget(message: _error!, onRetry: _loadData);
    }
    final order = _order!;
    final statusColor = _statusColor(order.status);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Purchase Order ${order.poNumber ?? ''}',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Order Details',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  order.status[0].toUpperCase() + order.status.substring(1),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Order info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Divider(height: 32),
                  _infoRow('PO Number', order.poNumber ?? '-'),
                  _infoRow('Supplier', order.supplierName ?? '-'),
                  _infoRow('Status',
                      order.status[0].toUpperCase() + order.status.substring(1)),
                  _infoRow('Date', _formatDate(order.createdAt)),
                  _infoRow('Total Amount', _formatCurrency(order.totalAmount)),
                  if (order.notes != null && order.notes!.isNotEmpty)
                    _infoRow('Notes', order.notes!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Items table
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Items',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  order.items.isEmpty
                      ? Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No items in this order',
                              style:
                                  TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                                AppColors.background),
                            columns: const [
                              DataColumn(
                                  label: Text('Medication',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600))),
                              DataColumn(
                                  label: Text('Quantity',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  numeric: true),
                              DataColumn(
                                  label: Text('Unit Cost',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600))),
                              DataColumn(
                                  label: Text('Total Cost',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600))),
                            ],
                            rows: order.items.map((item) {
                              return DataRow(cells: [
                                DataCell(
                                    Text(item.medicationName ?? '-')),
                                DataCell(Text('${item.quantity}')),
                                DataCell(
                                    Text(_formatCurrency(item.unitCost))),
                                DataCell(
                                    Text(_formatCurrency(item.totalCost))),
                              ]);
                            }).toList(),
                          ),
                        ),
                  if (order.items.isNotEmpty) ...[
                    const Divider(height: 32),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Total: ${_formatCurrency(order.totalAmount)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
