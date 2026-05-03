import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/status_badge.dart';
import '../providers/lab_exchange_provider.dart';

class LabExchangeListScreen extends ConsumerStatefulWidget {
  const LabExchangeListScreen({super.key});

  @override
  ConsumerState<LabExchangeListScreen> createState() =>
      _LabExchangeListScreenState();
}

class _LabExchangeListScreenState
    extends ConsumerState<LabExchangeListScreen> {
  int _page = 1;
  String _search = '';
  String? _status;
  String? _priority;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(labExchangeListProvider((
      page: _page,
      search: _search.isEmpty ? null : _search,
      status: _status,
      priority: _priority,
    )));

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Lab Requests',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () => ref.invalidate(labExchangeListProvider),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filters
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 280,
                  child: SearchField(
                    hintText: 'Search by patient or doctor...',
                    onChanged: (v) => setState(() {
                      _search = v;
                      _page = 1;
                    }),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                      DropdownMenuItem(
                          value: 'pending', child: Text('Pending')),
                      DropdownMenuItem(
                          value: 'accepted', child: Text('Accepted')),
                      DropdownMenuItem(
                          value: 'sample_collected',
                          child: Text('Sample Collected')),
                      DropdownMenuItem(
                          value: 'processing', child: Text('Processing')),
                      DropdownMenuItem(
                          value: 'completed', child: Text('Completed')),
                      DropdownMenuItem(
                          value: 'cancelled', child: Text('Cancelled')),
                    ],
                    onChanged: (v) => setState(() {
                      _status = v;
                      _page = 1;
                    }),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    initialValue: _priority,
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                      DropdownMenuItem(
                          value: 'routine', child: Text('Routine')),
                      DropdownMenuItem(
                          value: 'urgent', child: Text('Urgent')),
                      DropdownMenuItem(value: 'stat', child: Text('STAT')),
                    ],
                    onChanged: (v) => setState(() {
                      _priority = v;
                      _page = 1;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Table
            Expanded(
              child: ordersAsync.when(
                loading: () => const Center(child: LoadingWidget()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (data) {
                  if (data.results.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.biotech_outlined,
                      title: 'No lab requests found',
                      subtitle: 'Lab requests from hospitals will appear here.',
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStatePropertyAll(
                                AppColors.primary.withValues(alpha: 0.05)),
                            columns: const [
                              DataColumn(label: Text('Patient')),
                              DataColumn(label: Text('From')),
                              DataColumn(label: Text('Doctor')),
                              DataColumn(label: Text('Tests')),
                              DataColumn(label: Text('Priority')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: data.results.map((order) {
                              final testNames = order.tests
                                  .map((t) =>
                                      t['test_name']?.toString() ?? '')
                                  .where((t) => t.isNotEmpty)
                                  .toList();
                              return DataRow(cells: [
                                DataCell(Text(order.patientName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500))),
                                DataCell(Text(
                                    order.sourceTenantName ?? 'Unknown')),
                                DataCell(Text(
                                    order.orderingDoctorName ?? '--')),
                                DataCell(
                                  SizedBox(
                                    width: 200,
                                    child: Text(
                                      testNames.join(', '),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ),
                                DataCell(_PriorityChip(
                                    priority: order.priority)),
                                DataCell(StatusBadge(
                                    status: order.statusDisplay)),
                                DataCell(Text(_formatDate(order.createdAt))),
                                DataCell(Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                          Icons.visibility_outlined,
                                          size: 18),
                                      tooltip: 'View',
                                      onPressed: () => context.push(
                                          '/lab-exchange/${order.id}'),
                                    ),
                                  ],
                                )),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Pagination
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _page > 1
                                ? () => setState(() => _page--)
                                : null,
                          ),
                          Text('Page $_page'),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: data.next != null
                                ? () => setState(() => _page++)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }
}

class _PriorityChip extends StatelessWidget {
  final String priority;
  const _PriorityChip({required this.priority});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (priority) {
      case 'stat':
        color = AppColors.error;
        break;
      case 'urgent':
        color = AppColors.warning;
        break;
      default:
        color = AppColors.primary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        priority.toUpperCase(),
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
