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
import '../models/lab_order_model.dart';
import '../repository/lab_repository.dart';

class LabOrderListScreen extends ConsumerStatefulWidget {
  const LabOrderListScreen({super.key});

  @override
  ConsumerState<LabOrderListScreen> createState() =>
      _LabOrderListScreenState();
}

class _LabOrderListScreenState extends ConsumerState<LabOrderListScreen> {
  final _repo = LabRepository();
  PaginatedResponse<LabOrder>? _data;
  bool _loading = true;
  String? _error;
  int _page = 1;
  String _search = '';
  String _statusFilter = 'all';
  String _priorityFilter = 'all';

  static const _statuses = [
    'all', 'pending', 'sample_collected', 'processing', 'completed', 'cancelled',
  ];
  static const _priorities = ['all', 'routine', 'urgent', 'stat'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _repo.getOrders(
        page: _page,
        search: _search.isEmpty ? null : _search,
        status: _statusFilter == 'all' ? null : _statusFilter,
        priority: _priorityFilter == 'all' ? null : _priorityFilter,
      );
      setState(() { _data = result; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'stat':
        return AppColors.error;
      case 'urgent':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
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
                    Text('Lab Orders',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Manage laboratory test orders and results',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.push('/lab-orders/new'),
                icon: const Icon(Icons.add),
                label: const Text('New Lab Order'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SearchField(
                  hintText: 'Search lab orders...',
                  onChanged: (v) { _search = v; _page = 1; _loadData(); },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  initialValue: _statusFilter,
                  decoration: const InputDecoration(labelText: 'Status', isDense: true),
                  items: _statuses
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s == 'all'
                                ? 'All Statuses'
                                : s.replaceAll('_', ' ').toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (v) { _statusFilter = v ?? 'all'; _page = 1; _loadData(); },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String>(
                  initialValue: _priorityFilter,
                  decoration: const InputDecoration(labelText: 'Priority', isDense: true),
                  items: _priorities
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p == 'all' ? 'All Priorities' : p.toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (v) { _priorityFilter = v ?? 'all'; _page = 1; _loadData(); },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const LoadingWidget()
                : _error != null
                    ? app_error.AppErrorWidget(message: _error!, onRetry: _loadData)
                    : _data == null || _data!.results.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.science_outlined,
                            title: 'No lab orders found',
                            subtitle: 'Create a new lab order to get started.',
                          )
                        : Card(
                            child: Column(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SingleChildScrollView(
                                      child: DataTable(
                                        headingRowColor: WidgetStateProperty.all(AppColors.background),
                                        columns: const [
                                          DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Patient', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Tests', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Ordered By', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Priority', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600))),
                                        ],
                                        rows: _data!.results.map((o) {
                                          final tests = o.testNames?.join(', ') ?? '-';
                                          return DataRow(cells: [
                                            DataCell(Text(o.createdAt?.split('T').first ?? '-')),
                                            DataCell(Text(o.patientName ?? 'ID: ${o.patientId}')),
                                            DataCell(SizedBox(
                                              width: 200,
                                              child: Text(tests, maxLines: 1, overflow: TextOverflow.ellipsis),
                                            )),
                                            DataCell(Text(o.orderedByName ?? '-')),
                                            DataCell(StatusBadge(
                                              status: o.priority,
                                              overrideColor: _priorityColor(o.priority),
                                            )),
                                            DataCell(StatusBadge(status: o.status)),
                                            DataCell(Row(children: [
                                              IconButton(
                                                icon: const Icon(Icons.visibility_outlined, size: 20),
                                                onPressed: () => context.push('/lab-orders/${o.id}'),
                                                tooltip: 'View',
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined, size: 20),
                                                onPressed: () => context.push('/lab-orders/${o.id}/edit'),
                                                tooltip: 'Edit',
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                                                onPressed: () => _deleteOrder(o),
                                                tooltip: 'Delete',
                                              ),
                                            ])),
                                          ]);
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                                _pagination(),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _pagination() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${_data!.count} total records',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Row(children: [
            TextButton(
              onPressed: _data!.previous != null ? () { _page--; _loadData(); } : null,
              child: const Text('Previous'),
            ),
            const SizedBox(width: 8),
            Text('Page $_page', style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _data!.next != null ? () { _page++; _loadData(); } : null,
              child: const Text('Next'),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _deleteOrder(LabOrder o) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Lab Order'),
        content: Text('Delete lab order #${o.id}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await _repo.deleteOrder(o.id);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lab order deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
