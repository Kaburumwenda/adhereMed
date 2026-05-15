import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api.dart';
import '../../../widgets/common.dart';

final _dispensingProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/dispensing/', queryParameters: {'page_size': 50});
  return (res.data['results'] as List?) ?? [];
});

class DispensingScreen extends ConsumerWidget {
  const DispensingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_dispensingProvider);
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(_dispensingProvider),
      child: data.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorRetry(message: 'Failed to load', onRetry: () => ref.invalidate(_dispensingProvider)),
        data: (items) {
          if (items.isEmpty) return const EmptyState(icon: Icons.receipt_long, title: 'No dispensing records');
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final d = items[i];
              final status = d['status'] ?? 'pending';
              Color sc = Colors.orange;
              if (status == 'dispensed') sc = Colors.green;
              if (status == 'cancelled') sc = Colors.red;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: sc.withValues(alpha: 0.12),
                    child: Icon(Icons.receipt_long, color: sc, size: 20),
                  ),
                  title: Text(d['patient_name'] ?? 'Patient', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${d['medication_name'] ?? ''} • Qty: ${d['quantity'] ?? 0}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                    child: Text(status.toString().toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: sc)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
