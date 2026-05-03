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
import '../models/radiology_model.dart';
import '../repository/radiology_repository.dart';

class RadiologyOrderListScreen extends ConsumerStatefulWidget {
  const RadiologyOrderListScreen({super.key});

  @override
  ConsumerState<RadiologyOrderListScreen> createState() =>
      _RadiologyOrderListScreenState();
}

class _RadiologyOrderListScreenState
    extends ConsumerState<RadiologyOrderListScreen> {
  final _repo = RadiologyRepository();
  PaginatedResponse<RadiologyOrder>? _data;
  bool _loading = true;
  String? _error;
  int _page = 1;
  String _search = '';
  String _statusFilter = 'all';
  String _typeFilter = 'all';

  static const _statuses = ['all', 'pending', 'in_progress', 'completed', 'cancelled'];
  static const _imagingTypes = [
    'all', 'xray', 'ct', 'mri', 'ultrasound', 'mammogram', 'fluoroscopy', 'other',
  ];
  static const _typeLabels = {
    'xray': 'X-Ray', 'ct': 'CT Scan', 'mri': 'MRI',
    'ultrasound': 'Ultrasound', 'mammogram': 'Mammogram',
    'fluoroscopy': 'Fluoroscopy', 'other': 'Other',
  };

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
        imagingType: _typeFilter == 'all' ? null : _typeFilter,
      );
      setState(() { _data = result; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
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
                    Text('Radiology Orders',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Manage imaging orders and results',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.push('/radiology/new'),
                icon: const Icon(Icons.add),
                label: const Text('New Order'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SearchField(
                  hintText: 'Search orders...',
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
                width: 180,
                child: DropdownButtonFormField<String>(
                  initialValue: _typeFilter,
                  decoration: const InputDecoration(labelText: 'Imaging Type', isDense: true),
                  items: _imagingTypes
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s == 'all' ? 'All Types' : _typeLabels[s] ?? s),
                          ))
                      .toList(),
                  onChanged: (v) { _typeFilter = v ?? 'all'; _page = 1; _loadData(); },
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
                            icon: Icons.image_outlined,
                            title: 'No radiology orders',
                            subtitle: 'Create a new imaging order to get started.',
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
                                          DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Body Part', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Priority', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Ordered By', style: TextStyle(fontWeight: FontWeight.w600))),
                                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600))),
                                        ],
                                        rows: _data!.results.map((o) {
                                          return DataRow(cells: [
                                            DataCell(Text(o.createdAt?.split('T').first ?? '-')),
                                            DataCell(Text(o.patientName ?? 'ID: ${o.patientId}')),
                                            DataCell(Text(_typeLabels[o.imagingType] ?? o.imagingType)),
                                            DataCell(Text(o.bodyPart)),
                                            DataCell(StatusBadge(status: o.priority)),
                                            DataCell(StatusBadge(status: o.status)),
                                            DataCell(Text(o.orderedByName ?? '-')),
                                            DataCell(Row(children: [
                                              IconButton(
                                                icon: const Icon(Icons.visibility_outlined, size: 20),
                                                onPressed: () => context.push('/radiology/${o.id}'),
                                                tooltip: 'View',
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined, size: 20),
                                                onPressed: () => context.push('/radiology/${o.id}/edit'),
                                                tooltip: 'Edit',
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                                                onPressed: () => _delete(o),
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

  Future<void> _delete(RadiologyOrder o) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Radiology Order'),
        content: Text('Delete ${_typeLabels[o.imagingType] ?? o.imagingType} order for ${o.patientName}?'),
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
            const SnackBar(content: Text('Order deleted')),
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
