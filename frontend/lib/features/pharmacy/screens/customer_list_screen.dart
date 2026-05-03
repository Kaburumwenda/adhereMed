import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/search_field.dart';
import '../../pos/repository/customer_repository.dart';
import '../../pos/providers/customer_provider.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  int _page = 1;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(
        customerListProvider((page: _page, search: _search.isEmpty ? null : _search)));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text('Customers',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _showCustomerDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Customer'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SearchField(
            hintText: 'Search customers...',
            onChanged: (v) => setState(() {
              _search = v;
              _page = 1;
            }),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: dataAsync.when(
              loading: () => const Center(child: LoadingWidget()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (data) {
                if (data.results.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.people_outline,
                    title: 'No customers yet',
                    subtitle: 'Add your first customer to get started',
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
                              DataColumn(label: Text('Name')),
                              DataColumn(label: Text('Phone')),
                              DataColumn(label: Text('Email')),
                              DataColumn(label: Text('Visits'), numeric: true),
                              DataColumn(label: Text('Total Spent'), numeric: true),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: data.results.map((c) {
                              return DataRow(cells: [
                                DataCell(Text(c.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500))),
                                DataCell(Text(c.phone ?? '-')),
                                DataCell(Text(c.email ?? '-')),
                                DataCell(Text('${c.visitCount}')),
                                DataCell(Text(
                                    'KSh ${c.totalPurchases.toStringAsFixed(0)}')),
                                DataCell(Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 18),
                                      onPressed: () =>
                                          _showCustomerDialog(context,
                                              customer: c),
                                      tooltip: 'Edit',
                                    ),
                                  ],
                                )),
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

  void _showCustomerDialog(BuildContext context, {Customer? customer}) {
    final nameCtrl = TextEditingController(text: customer?.name ?? '');
    final phoneCtrl = TextEditingController(text: customer?.phone ?? '');
    final emailCtrl = TextEditingController(text: customer?.email ?? '');
    final addressCtrl = TextEditingController(text: customer?.address ?? '');
    final notesCtrl = TextEditingController(text: customer?.notes ?? '');
    final repo = CustomerRepository();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(customer == null ? 'Add Customer' : 'Edit Customer'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Name *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Phone', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Email', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Address', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Notes', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final data = {
                'name': nameCtrl.text.trim(),
                if (phoneCtrl.text.trim().isNotEmpty)
                  'phone': phoneCtrl.text.trim(),
                if (emailCtrl.text.trim().isNotEmpty)
                  'email': emailCtrl.text.trim(),
                if (addressCtrl.text.trim().isNotEmpty)
                  'address': addressCtrl.text.trim(),
                if (notesCtrl.text.trim().isNotEmpty)
                  'notes': notesCtrl.text.trim(),
              };
              try {
                if (customer == null) {
                  await repo.createCustomer(data);
                } else {
                  await repo.updateCustomer(customer.id, data);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                ref.invalidate(customerListProvider);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: Text(customer == null ? 'Create' : 'Update'),
          ),
        ],
      ),
    );
  }
}
