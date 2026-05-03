import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/models/paginated_response.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../models/department_model.dart';
import '../repository/department_repository.dart';

class DepartmentListScreen extends ConsumerStatefulWidget {
  const DepartmentListScreen({super.key});

  @override
  ConsumerState<DepartmentListScreen> createState() =>
      _DepartmentListScreenState();
}

class _DepartmentListScreenState
    extends ConsumerState<DepartmentListScreen> {
  final _repo = DepartmentRepository();
  PaginatedResponse<Department>? _data;
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
      final result = await _repo.getList(
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

  Future<void> _delete(int id) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Department',
      content: 'Are you sure you want to delete this department?',
    );
    if (!confirmed || !mounted) return;
    try {
      await _repo.delete(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Department deleted')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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
                      'Departments',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage hospital departments',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.push('/departments/new'),
                icon: const Icon(Icons.add),
                label: const Text('Add Department'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SearchField(
            hintText: 'Search departments...',
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
                        message: _error!, onRetry: _loadData)
                    : _data == null || _data!.results.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.business_outlined,
                            title: 'No departments found',
                            subtitle: 'Add a department to get started.',
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
                                          DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600))),
                                        ],
                                        rows: _data!.results.map((d) {
                                          return DataRow(cells: [
                                            DataCell(Text(d.name)),
                                            DataCell(Text(d.description ?? '-')),
                                            DataCell(StatusBadge(
                                              status: d.isActive ? 'active' : 'inactive',
                                            )),
                                            DataCell(Row(children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined, size: 20),
                                                onPressed: () => context.push('/departments/${d.id}/edit'),
                                                tooltip: 'Edit',
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                                                onPressed: () => _delete(d.id),
                                                tooltip: 'Delete',
                                              ),
                                            ])),
                                          ]);
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${_data!.count} total records',
                                          style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 13)),
                                      Row(children: [
                                        TextButton(
                                          onPressed: _data!.previous != null
                                              ? () {
                                                  _page--;
                                                  _loadData();
                                                }
                                              : null,
                                          child: const Text('Previous'),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('Page $_page',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w500)),
                                        const SizedBox(width: 8),
                                        TextButton(
                                          onPressed: _data!.next != null
                                              ? () {
                                                  _page++;
                                                  _loadData();
                                                }
                                              : null,
                                          child: const Text('Next'),
                                        ),
                                      ]),
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
}
