import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api.dart';
import '../../../widgets/common.dart';

final _detailProvider = FutureProvider.autoDispose.family<Map, int>((ref, id) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/inventory/stocks/$id/');
  return res.data;
});

class StockDetailScreen extends ConsumerWidget {
  final int id;
  const StockDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(_detailProvider(id));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit',
            onPressed: () => context.push('/inventory/$id/edit'),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorRetry(message: 'Failed to load', onRetry: () => ref.invalidate(_detailProvider(id))),
        data: (item) {
          final batches = (item['batches'] as List?) ?? [];
          final low = item['is_low_stock'] == true;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(14)),
                        child: Icon(Icons.medication, color: cs.primary, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item['medication_name'] ?? '', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        Text(item['medication_id'] ?? '', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                      ])),
                    ]),
                    if (low) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                          SizedBox(width: 6),
                          Text('Low Stock', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600, fontSize: 13)),
                        ]),
                      ),
                    ],
                  ]),
                ),
              ),
              const SizedBox(height: 12),

              // Info grid
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    _infoRow('Category', item['category_name'] ?? 'N/A'),
                    _infoRow('Unit', item['unit_name'] ?? 'N/A'),
                    _infoRow('Selling Price', 'KSH ${item['selling_price']}'),
                    _infoRow('Cost Price', 'KSH ${item['cost_price']}'),
                    _infoRow('Total Quantity', '${item['total_quantity']}'),
                    _infoRow('Reorder Level', '${item['reorder_level']}'),
                    _infoRow('Barcode', item['barcode'] ?? 'N/A'),
                    _infoRow('Rx Required', item['prescription_required'] ?? 'none'),
                    _infoRow('Location', item['location_in_store'] ?? 'N/A'),
                  ]),
                ),
              ),
              const SizedBox(height: 16),

              // Batches
              Text('Batches (${batches.length})', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (batches.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No batches'))))
              else
                ...batches.map((b) {
                  final expired = b['is_expired'] == true;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(expired ? Icons.error : Icons.check_circle, color: expired ? Colors.red : Colors.green),
                      title: Text('Batch: ${b['batch_number'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Qty: ${b['quantity_remaining']}/${b['quantity_received']}  •  Exp: ${b['expiry_date'] ?? 'N/A'}'),
                      trailing: Text('KSH ${b['cost_price_per_unit']}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(flex: 2, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
        Expanded(flex: 3, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
      ]),
    );
  }
}
