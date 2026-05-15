import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api.dart';
import '../../../widgets/common.dart';

final _expensesProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/expenses/expenses/', queryParameters: {'page_size': 50});
  return (res.data['results'] as List?) ?? [];
});

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(_expensesProvider);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      body: expenses.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorRetry(message: 'Failed to load', onRetry: () => ref.invalidate(_expensesProvider)),
        data: (items) {
          if (items.isEmpty) return const EmptyState(icon: Icons.receipt, title: 'No expenses');
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_expensesProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final e = items[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.red.withValues(alpha: 0.1), child: const Icon(Icons.receipt, color: Colors.red)),
                    title: Text(e['description'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${e['category_name'] ?? 'Other'} • ${e['date'] ?? ''}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    trailing: Text('KSH ${e['amount']}', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red.shade700)),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/expenses/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }
}
