import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/search_field.dart';
import '../repository/stock_adjustment_repository.dart';
import '../providers/stock_adjustment_provider.dart';
import '../repository/inventory_repository.dart';
import '../models/stock_model.dart';

class StockAdjustmentScreen extends ConsumerStatefulWidget {
  const StockAdjustmentScreen({super.key});

  @override
  ConsumerState<StockAdjustmentScreen> createState() =>
      _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState
    extends ConsumerState<StockAdjustmentScreen> {
  int _page = 1;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(stockAdjustmentListProvider(
        (page: _page, search: _search.isEmpty ? null : _search)));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Stock Adjustments',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _showAdjustmentDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('New Adjustment'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SearchField(
            hintText: 'Search adjustments...',
            onChanged: (v) => setState(() {
              _search = v;
              _page = 1;
            }),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: dataAsync.when(
              loading: () => const Center(child: LoadingWidget()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (data) {
                if (data.results.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.tune_outlined,
                    title: 'No adjustments yet',
                    subtitle: 'Stock adjustments will appear here',
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: Card(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Medication')),
                              DataColumn(label: Text('Quantity'), numeric: true),
                              DataColumn(label: Text('Reason')),
                              DataColumn(label: Text('Adjusted By')),
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Notes')),
                            ],
                            rows: data.results.map((a) {
                              final isPositive = a.quantityChange > 0;
                              return DataRow(cells: [
                                DataCell(Text(a.stockName ?? '#${a.stock}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500))),
                                DataCell(Text(
                                  '${isPositive ? '+' : ''}${a.quantityChange}',
                                  style: TextStyle(
                                    color: isPositive
                                        ? AppColors.success
                                        : AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )),
                                DataCell(Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(a.reasonLabel,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                )),
                                DataCell(
                                    Text(a.adjustedByName ?? '-')),
                                DataCell(Text(_formatDate(a.createdAt))),
                                DataCell(ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 200),
                                  child: Text(a.notes ?? '-',
                                      overflow: TextOverflow.ellipsis),
                                )),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    if (data.count > data.results.length)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: _page > 1
                                  ? () => setState(() => _page--)
                                  : null,
                              child: const Text('Previous'),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text('Page $_page'),
                            ),
                            TextButton(
                              onPressed: data.next != null
                                  ? () => setState(() => _page++)
                                  : null,
                              child: const Text('Next'),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAdjustmentDialog(BuildContext context) {
    final qtyCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String reason = 'count_correction';
    MedicationStock? selectedStock;
    List<MedicationStock> stocks = [];
    bool loading = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (loading) {
            InventoryRepository()
                .getStocks(page: 1)
                .then((result) {
              setDialogState(() {
                stocks = result.results;
                loading = false;
              });
            }).catchError((e) {
              setDialogState(() => loading = false);
            });
          }
          return AlertDialog(
            title: const Text('New Stock Adjustment'),
            content: SizedBox(
              width: 400,
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<MedicationStock>(
                            decoration: const InputDecoration(
                                labelText: 'Medication *',
                                border: OutlineInputBorder()),
                            items: stocks
                                .map((s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s.medicationName),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setDialogState(() => selectedStock = v),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: qtyCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Quantity Change *',
                              helperText:
                                  'Use negative for deductions (e.g. -5)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                signed: true),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                                labelText: 'Reason *',
                                border: OutlineInputBorder()),
                            initialValue: reason,
                            items: const [
                              DropdownMenuItem(
                                  value: 'damage', child: Text('Damage')),
                              DropdownMenuItem(
                                  value: 'theft', child: Text('Theft')),
                              DropdownMenuItem(
                                  value: 'expiry', child: Text('Expiry')),
                              DropdownMenuItem(
                                  value: 'count_correction',
                                  child: Text('Count Correction')),
                              DropdownMenuItem(
                                  value: 'return_to_supplier',
                                  child: Text('Return to Supplier')),
                              DropdownMenuItem(
                                  value: 'other', child: Text('Other')),
                            ],
                            onChanged: (v) =>
                                setDialogState(() => reason = v ?? reason),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: notesCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Notes',
                                border: OutlineInputBorder()),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (selectedStock == null || qtyCtrl.text.trim().isEmpty) {
                    return;
                  }
                  final data = {
                    'stock': selectedStock!.id,
                    'quantity_change': int.tryParse(qtyCtrl.text.trim()) ?? 0,
                    'reason': reason,
                    if (notesCtrl.text.trim().isNotEmpty)
                      'notes': notesCtrl.text.trim(),
                  };
                  try {
                    await StockAdjustmentRepository().createAdjustment(data);
                    if (ctx.mounted) Navigator.pop(ctx);
                    ref.invalidate(stockAdjustmentListProvider);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
