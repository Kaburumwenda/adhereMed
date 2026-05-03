import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/search_field.dart';
import '../repository/delivery_repository.dart';
import '../providers/delivery_provider.dart';

class DeliveryListScreen extends ConsumerStatefulWidget {
  const DeliveryListScreen({super.key});

  @override
  ConsumerState<DeliveryListScreen> createState() => _DeliveryListScreenState();
}

class _DeliveryListScreenState extends ConsumerState<DeliveryListScreen> {
  int _page = 1;
  String _search = '';
  String? _statusFilter;

  static const _statuses = [
    null,
    'pending',
    'assigned',
    'in_transit',
    'delivered',
    'failed',
    'cancelled',
  ];

  static const _statusLabels = {
    null: 'All',
    'pending': 'Pending',
    'assigned': 'Assigned',
    'in_transit': 'In Transit',
    'delivered': 'Delivered',
    'failed': 'Failed',
    'cancelled': 'Cancelled',
  };

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'assigned':
        return AppColors.secondary;
      case 'in_transit':
        return AppColors.primary;
      case 'delivered':
        return AppColors.success;
      case 'failed':
        return AppColors.error;
      case 'cancelled':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(deliveryListProvider((
      page: _page,
      search: _search.isEmpty ? null : _search,
      status: _statusFilter,
    )));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Deliveries',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // Filters
          Row(
            children: [
              Expanded(
                child: SearchField(
                  hintText: 'Search deliveries...',
                  onChanged: (v) => setState(() {
                    _search = v;
                    _page = 1;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String?>(
                value: _statusFilter,
                items: _statuses
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(_statusLabels[s] ?? 'All'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() {
                  _statusFilter = v;
                  _page = 1;
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: dataAsync.when(
              loading: () => const Center(child: LoadingWidget()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (data) {
                if (data.results.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.local_shipping_outlined,
                    title: 'No deliveries yet',
                    subtitle: 'Delivery records will appear here',
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: Card(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Transaction')),
                              DataColumn(label: Text('Recipient')),
                              DataColumn(label: Text('Phone')),
                              DataColumn(label: Text('Address')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Fee'), numeric: true),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: data.results.map((d) {
                              return DataRow(cells: [
                                DataCell(Text(d.transactionNumber ?? '#${d.transaction}')),
                                DataCell(Text(d.recipientName)),
                                DataCell(Text(d.recipientPhone)),
                                DataCell(ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 200),
                                  child: Text(d.deliveryAddress,
                                      overflow: TextOverflow.ellipsis),
                                )),
                                DataCell(Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _statusColor(d.status)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(d.statusLabel,
                                      style: TextStyle(
                                          color: _statusColor(d.status),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                )),
                                DataCell(Text(
                                    'KSh ${d.deliveryFee.toStringAsFixed(0)}')),
                                DataCell(
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 18),
                                    itemBuilder: (_) => [
                                      if (d.status == 'pending')
                                        const PopupMenuItem(
                                            value: 'assigned',
                                            child: Text('Mark Assigned')),
                                      if (d.status == 'assigned')
                                        const PopupMenuItem(
                                            value: 'in_transit',
                                            child: Text('Mark In Transit')),
                                      if (d.status == 'in_transit')
                                        const PopupMenuItem(
                                            value: 'delivered',
                                            child: Text('Mark Delivered')),
                                      if (d.status != 'delivered' &&
                                          d.status != 'cancelled')
                                        const PopupMenuItem(
                                            value: 'cancelled',
                                            child: Text('Cancel')),
                                    ],
                                    onSelected: (newStatus) =>
                                        _updateStatus(d.id, newStatus),
                                  ),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    if (data.count > data.results.length)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: _page > 1
                                  ? () => setState(() => _page--)
                                  : null,
                              child: const Text('Previous'),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text('Page $_page'),
                            ),
                            TextButton(
                              onPressed: data.next != null
                                  ? () => setState(() => _page++)
                                  : null,
                              child: const Text('Next'),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(int id, String status) async {
    try {
      await DeliveryRepository().updateStatus(id, status);
      ref.invalidate(deliveryListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Delivery status updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
