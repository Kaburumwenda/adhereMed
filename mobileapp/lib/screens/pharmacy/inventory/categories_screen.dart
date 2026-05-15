import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api.dart';
import '../../../widgets/common.dart';

final _catsProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/inventory/categories/', queryParameters: {'page_size': 100});
  return (res.data['results'] as List?) ?? [];
});

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(_catsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: cats.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorRetry(message: 'Failed to load', onRetry: () => ref.invalidate(_catsProvider)),
        data: (items) {
          if (items.isEmpty) return const EmptyState(icon: Icons.category, title: 'No categories');
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_catsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final c = items[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${c['name']?[0] ?? ''}'.toUpperCase())),
                    title: Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(c['description'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
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
