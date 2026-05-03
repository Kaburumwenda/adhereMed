import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/models/paginated_response.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../models/supplier_model.dart';
import '../repository/supplier_repository.dart';

class SupplierListScreen extends ConsumerStatefulWidget {
  const SupplierListScreen({super.key});

  @override
  ConsumerState<SupplierListScreen> createState() =>
      _SupplierListScreenState();
}

class _SupplierListScreenState extends ConsumerState<SupplierListScreen> {
  final _repo = SupplierRepository();
  PaginatedResponse<Supplier>? _data;
  bool _loading = true;
  String? _error;
  int _page = 1;
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
      final result = await _repo.getSuppliers(
        page: _page,
        search: _search.isEmpty ? null : _search,
      );
      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _deleteSupplier(Supplier supplier) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Supplier',
      content: 'Are you sure you want to delete "${supplier.name}"?',
    );
    if (!confirmed) return;
    try {
      await _repo.deleteSupplier(supplier.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Supplier deleted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
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
                    Text(
                      'Suppliers',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage medication suppliers',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.push('/suppliers/new'),
                icon: const Icon(Icons.add),
                label: const Text('Add Supplier'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SearchField(
            hintText: 'Search suppliers...',
            onChanged: (value) {
              _search = value;
              _page = 1;
              _loadData();
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const LoadingWidget()
                : _error != null
                    ? app_error.AppErrorWidget(
                        message: _error!,
                        onRetry: _loadData,
                      )
                    : _data == null || _data!.results.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.local_shipping_outlined,
                            title: 'No suppliers found',
                            subtitle: 'Add a supplier to get started.',
                          )
                        : Card(
                            child: Column(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SingleChildScrollView(
                                      child: DataTable(
                                        headingRowColor:
                                            WidgetStateProperty.all(
                                                AppColors.background),
                                        columns: const [
                                          DataColumn(
                                              label: Text('Name',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600))),
                                          DataColumn(
                                              label: Text('Contact Person',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600))),
                                          DataColumn(
                                              label: Text('Email',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600))),
                                          DataColumn(
                                              label: Text('Phone',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600))),
                                          DataColumn(
                                              label: Text('Status',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600))),
                                          DataColumn(
                                              label: Text('Actions',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600))),
                                        ],
                                        rows: _data!.results
                                            .map(_buildRow)
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_data!.count > _data!.results.length)
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        TextButton(
                                          onPressed: _data!.previous != null
                                              ? () {
                                                  _page--;
                                                  _loadData();
                                                }
                                              : null,
                                          child: const Text('Previous'),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16),
                                          child: Text('Page $_page'),
                                        ),
                                        TextButton(
                                          onPressed: _data!.next != null
                                              ? () {
                                                  _page++;
                                                  _loadData();
                                                }
                                              : null,
                                          child: const Text('Next'),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  DataRow _buildRow(Supplier s) {
    return DataRow(cells: [
      DataCell(Text(s.name)),
      DataCell(Text(s.contactPerson ?? '-')),
      DataCell(Text(s.email ?? '-')),
      DataCell(Text(s.phone ?? '-')),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: s.isActive
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.textSecondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            s.isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              color: s.isActive ? AppColors.success : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      DataCell(Row(
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => context.push('/suppliers/${s.id}/edit'),
            tooltip: 'Edit',
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20,
                color: AppColors.error),
            onPressed: () => _deleteSupplier(s),
            tooltip: 'Delete',
          ),
        ],
      )),
    ]);
  }
}
