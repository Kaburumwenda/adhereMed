import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api.dart';
import '../../../widgets/common.dart';

final _adjProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/inventory/adjustments/', queryParameters: {'page_size': 50});
  return (res.data['results'] as List?) ?? [];
});

class AdjustmentsScreen extends ConsumerWidget {
  const AdjustmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adj = ref.watch(_adjProvider);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Adjustments')),
      body: adj.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorRetry(message: 'Failed to load', onRetry: () => ref.invalidate(_adjProvider)),
        data: (items) {
          if (items.isEmpty) return const EmptyState(icon: Icons.tune, title: 'No adjustments');
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_adjProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final a = items[i];
                final change = a['quantity_change'] ?? 0;
                final positive = change > 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(positive ? Icons.add_circle : Icons.remove_circle, color: positive ? Colors.green : Colors.red),
                    title: Text(a['stock_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${a['reason'] ?? ''} • by ${a['adjusted_by_name'] ?? ''}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    trailing: Text('${positive ? '+' : ''}$change', style: TextStyle(fontWeight: FontWeight.w800, color: positive ? Colors.green : Colors.red)),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
