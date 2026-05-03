import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/search_field.dart';

class _Specialization {
  final int id;
  final String name;
  final String description;
  final bool isActive;

  _Specialization({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
  });

  factory _Specialization.fromJson(Map<String, dynamic> json) =>
      _Specialization(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? true,
      );
}

class SpecializationListScreen extends ConsumerStatefulWidget {
  const SpecializationListScreen({super.key});

  @override
  ConsumerState<SpecializationListScreen> createState() =>
      _SpecializationListScreenState();
}

class _SpecializationListScreenState
    extends ConsumerState<SpecializationListScreen> {
  final Dio _dio = ApiClient.instance;
  List<_Specialization> _items = [];
  bool _loading = true;
  String? _error;
  String _search = '';

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
      final params = <String, dynamic>{};
      if (_search.isNotEmpty) params['search'] = _search;
      final response =
          await _dio.get('/staff/specializations/', queryParameters: params);
      final results = response.data['results'] as List<dynamic>? ??
          (response.data is List ? response.data as List : []);
      setState(() {
        _items = results
            .map((e) => _Specialization.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _showFormDialog({_Specialization? item}) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final descCtrl = TextEditingController(text: item?.description ?? '');
    bool isActive = item?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title:
              Text(item != null ? 'Edit Specialization' : 'Add Specialization'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (v) => setDialogState(() => isActive = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  final data = {
                    'name': nameCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'is_active': isActive,
                  };
                  if (item != null) {
                    await _dio.patch('/staff/specializations/${item.id}/',
                        data: data);
                  } else {
                    await _dio.post('/staff/specializations/', data: data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } on DioException catch (e) {
                  final msg = e.response?.data is Map
                      ? (e.response!.data as Map)
                          .values
                          .map((v) => v is List ? v.join(', ') : '$v')
                          .join('\n')
                      : (e.message ?? 'Error');
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                          content: Text(msg),
                          backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: Text(item != null ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _deleteItem(_Specialization item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Specialization'),
        content: Text(
            'Delete "${item.name}"? Staff using this specialization will be unlinked.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _dio.delete('/staff/specializations/${item.id}/');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Specialization deleted'),
                backgroundColor: AppColors.success),
          );
        }
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to delete: $e'),
                backgroundColor: AppColors.error),
          );
        }
      }
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
                    Text('Specializations',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Manage pharmacy staff specializations',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showFormDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Specialization'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SearchField(
            hintText: 'Search specializations...',
            onChanged: (v) {
              _search = v;
              _loadData();
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: LoadingWidget())
                : _error != null
                    ? Center(child: Text('Error: $_error'))
                    : _items.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.school_outlined,
                            title: 'No specializations',
                            subtitle: 'Add specializations for your staff',
                            actionLabel: 'Add Specialization',
                            onAction: () => _showFormDialog(),
                          )
                        : Card(
                            child: ListView.separated(
                              itemCount: _items.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: item.isActive
                                        ? AppColors.primary
                                            .withValues(alpha: 0.1)
                                        : AppColors.textSecondary
                                            .withValues(alpha: 0.1),
                                    child: Icon(
                                      Icons.school_outlined,
                                      color: item.isActive
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                      size: 20,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Text(item.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w500)),
                                      if (!item.isActive) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.textSecondary
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text('Inactive',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color:
                                                    AppColors.textSecondary,
                                              )),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: item.description.isNotEmpty
                                      ? Text(item.description,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis)
                                      : null,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined,
                                            size: 20),
                                        tooltip: 'Edit',
                                        onPressed: () =>
                                            _showFormDialog(item: item),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline,
                                            size: 20,
                                            color: AppColors.error),
                                        tooltip: 'Delete',
                                        onPressed: () => _deleteItem(item),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
