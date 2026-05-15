import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api.dart';
import '../../../widgets/common.dart';

final _returnsProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/dispensing/returns/', queryParameters: {'page_size': 50});
  return (res.data['results'] as List?) ?? [];
});

class DispenseReturnsScreen extends ConsumerWidget {
  const DispenseReturnsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_returnsProvider);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Dispense Returns')),
      body: data.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorRetry(message: 'Failed to load', onRetry: () => ref.invalidate(_returnsProvider)),
        data: (items) {
          if (items.isEmpty) return const EmptyState(icon: Icons.assignment_return, title: 'No returns');
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_returnsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final r = items[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Color(0x1AFF9800), child: Icon(Icons.assignment_return, color: Colors.orange)),
                    title: Text(r['medication_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Qty: ${r['quantity']} • ${r['reason'] ?? ''}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    trailing: Text(r['date'] ?? '', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
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
