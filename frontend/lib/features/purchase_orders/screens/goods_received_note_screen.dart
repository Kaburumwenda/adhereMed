import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/purchase_order_model.dart';
import '../repository/purchase_order_repository.dart';

class GoodsReceivedNoteScreen extends ConsumerStatefulWidget {
  final int orderId;
  const GoodsReceivedNoteScreen({super.key, required this.orderId});

  @override
  ConsumerState<GoodsReceivedNoteScreen> createState() =>
      _GoodsReceivedNoteScreenState();
}

class _GoodsReceivedNoteScreenState
    extends ConsumerState<GoodsReceivedNoteScreen> {
  final _repo = PurchaseOrderRepository();
  final _notesCtrl = TextEditingController();

  PurchaseOrder? _order;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Per-item received qty controllers
  final List<TextEditingController> _qtyControllers = [];
  // Per-item batch number controllers
  final List<TextEditingController> _batchControllers = [];
  // Per-item expiry date
  final List<DateTime?> _expiryDates = [];

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (final c in _qtyControllers) {
      c.dispose();
    }
    for (final c in _batchControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadOrder() async {
    try {
      final order = await _repo.getPurchaseOrder(widget.orderId);
      if (mounted) {
        setState(() {
          _order = order;
          _loading = false;
          _qtyControllers.clear();
          _batchControllers.clear();
          _expiryDates.clear();
          for (final item in order.items) {
            _qtyControllers
                .add(TextEditingController(text: '${item.quantity}'));
            _batchControllers.add(TextEditingController());
            _expiryDates.add(null);
          }
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

  Future<void> _pickExpiry(int index) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _expiryDates[index] = picked);
    }
  }

  Future<void> _submit() async {
    if (_order == null) return;

    // Validate each batch number
    for (int i = 0; i < _order!.items.length; i++) {
      if (_batchControllers[i].text.trim().isEmpty) {
        setState(() => _error = 'Please enter batch number for all items.');
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final itemsReceived = _order!.items.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;
        return {
          'medication_stock_id': item.medicationStockId,
          'medication_name': item.medicationName ?? '',
          'qty_ordered': item.quantity,
          'qty_received': int.tryParse(_qtyControllers[i].text) ?? 0,
          'batch_number': _batchControllers[i].text.trim(),
          'unit_cost': item.unitCost,
          if (_expiryDates[i] != null)
            'expiry_date':
                _expiryDates[i]!.toIso8601String().split('T').first,
        };
      }).toList();

      await _repo.createGRN({
        'purchase_order': widget.orderId,
        'items_received': itemsReceived,
        'notes': _notesCtrl.text.trim(),
      });

      // Update PO status to received
      await _repo.updatePurchaseOrder(widget.orderId, {'status': 'received'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Goods received successfully. Stock updated.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Select date';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: LoadingWidget()));

    if (_error != null && _order == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: AppColors.error, size: 40),
              const SizedBox(height: 12),
              Text(_error!),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: _loadOrder, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final order = _order!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Receive Goods',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text('PO: ${order.poNumber ?? '#${order.id}'}',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 24),

          // Order Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _InfoChip(
                      label: 'Supplier',
                      value: order.supplierName ?? 'Unknown'),
                  const SizedBox(width: 24),
                  _InfoChip(
                      label: 'Items',
                      value: '${order.items.length}'),
                  const SizedBox(width: 24),
                  _InfoChip(
                      label: 'Total Value',
                      value:
                          'KSh ${order.totalAmount.toStringAsFixed(2)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Items
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Items Received',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                    'Confirm quantities and enter batch numbers for each item.',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(order.items.length, (i) {
                    final item = order.items[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('${i + 1}',
                                  style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.medicationName ?? 'Item ${i + 1}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14),
                              ),
                            ),
                            Text(
                              'Ordered: ${item.quantity}',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          LayoutBuilder(builder: (ctx, cs) {
                            final wide = cs.maxWidth > 500;
                            final qtyField = TextFormField(
                              controller: _qtyControllers[i],
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Qty Received *',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                isDense: true,
                              ),
                            );
                            final batchField = TextField(
                              controller: _batchControllers[i],
                              decoration: const InputDecoration(
                                labelText: 'Batch Number *',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                isDense: true,
                              ),
                            );
                            final expiryField = InkWell(
                              onTap: () => _pickExpiry(i),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Expiry Date',
                                  border: OutlineInputBorder(),
                                  suffixIcon:
                                      Icon(Icons.calendar_today, size: 16),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  isDense: true,
                                ),
                                child: Text(
                                  _formatDate(_expiryDates[i]),
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: _expiryDates[i] != null
                                          ? null
                                          : AppColors.textSecondary),
                                ),
                              ),
                            );
                            if (wide) {
                              return Row(children: [
                                Expanded(child: qtyField),
                                const SizedBox(width: 12),
                                Expanded(child: batchField),
                                const SizedBox(width: 12),
                                Expanded(child: expiryField),
                              ]);
                            }
                            return Column(children: [
                              qtyField,
                              const SizedBox(height: 8),
                              batchField,
                              const SizedBox(height: 8),
                              expiryField,
                            ]);
                          }),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Notes
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes / Remarks',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(Icons.error_outline, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_error!,
                        style: TextStyle(color: AppColors.error))),
              ]),
            ),
          ],
          const SizedBox(height: 24),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _saving ? null : () => context.pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline),
                label: const Text('Confirm Receipt'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }
}
