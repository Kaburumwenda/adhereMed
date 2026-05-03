import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/status_badge.dart';
import '../providers/lab_exchange_provider.dart';

class LabExchangeDetailScreen extends ConsumerStatefulWidget {
  final String exchangeId;
  const LabExchangeDetailScreen({super.key, required this.exchangeId});

  @override
  ConsumerState<LabExchangeDetailScreen> createState() =>
      _LabExchangeDetailScreenState();
}

class _LabExchangeDetailScreenState
    extends ConsumerState<LabExchangeDetailScreen> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final id = int.tryParse(widget.exchangeId) ?? 0;
    final detailAsync = ref.watch(labExchangeDetailProvider(id));

    return Scaffold(
      body: detailAsync.when(
        loading: () => const Center(child: LoadingWidget()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (order) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back + title
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/lab-exchange'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lab Request #${order.id}',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    StatusBadge(status: order.statusDisplay),
                  ],
                ),
                const SizedBox(height: 24),

                // Info cards
                LayoutBuilder(builder: (ctx, c) {
                  if (c.maxWidth > 800) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildPatientCard(context, order)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildSourceCard(context, order)),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _buildPatientCard(context, order),
                      const SizedBox(height: 16),
                      _buildSourceCard(context, order),
                    ],
                  );
                }),
                const SizedBox(height: 16),

                // Tests
                _buildTestsCard(context, order),
                const SizedBox(height: 16),

                // Clinical notes
                if (order.clinicalNotes != null &&
                    order.clinicalNotes!.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Clinical Notes',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text(order.clinicalNotes!),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Results (if completed)
                if (order.results != null && order.results!.isNotEmpty)
                  _buildResultsCard(context, order),

                // Actions
                const SizedBox(height: 24),
                if (order.status == 'pending')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : () => _acceptOrder(id),
                      icon: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check),
                      label: const Text('Accept This Request'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),

                if (order.status == 'accepted' ||
                    order.status == 'sample_collected' ||
                    order.status == 'processing') ...[
                  Row(
                    children: [
                      if (order.status == 'accepted')
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _loading
                                ? null
                                : () => _updateStatus(id, 'sample_collected'),
                            icon: const Icon(Icons.colorize),
                            label: const Text('Mark Sample Collected'),
                          ),
                        ),
                      if (order.status == 'sample_collected') ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _loading
                                ? null
                                : () => _updateStatus(id, 'processing'),
                            icon: const Icon(Icons.hourglass_bottom),
                            label: const Text('Mark Processing'),
                          ),
                        ),
                      ],
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _loading
                              ? null
                              : () =>
                                  _showSubmitResultsDialog(context, order),
                          icon: const Icon(Icons.done_all),
                          label: const Text('Submit Results'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPatientCard(BuildContext context, dynamic order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patient Information',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _InfoRow(label: 'Name', value: order.patientName),
            if (order.patientPhone != null && order.patientPhone!.isNotEmpty)
              _InfoRow(label: 'Phone', value: order.patientPhone!),
            _InfoRow(label: 'Priority', value: order.priorityDisplay),
            if (order.isHomeCollection)
              _InfoRow(
                  label: 'Collection',
                  value:
                      'Home Collection${order.collectionAddress != null ? ' — ${order.collectionAddress}' : ''}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceCard(BuildContext context, dynamic order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request Source',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _InfoRow(
                label: 'Hospital/Clinic',
                value: order.sourceTenantName ?? 'Unknown'),
            _InfoRow(
                label: 'Ordering Doctor',
                value: order.orderingDoctorName ?? '--'),
            if (order.labTenantName != null)
              _InfoRow(label: 'Assigned Lab', value: order.labTenantName!),
            _InfoRow(label: 'Status', value: order.statusDisplay),
          ],
        ),
      ),
    );
  }

  Widget _buildTestsCard(BuildContext context, dynamic order) {
    final tests = order.tests as List<Map<String, dynamic>>;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Requested Tests',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (tests.isEmpty)
              const Text('No tests specified')
            else
              ...tests.map((t) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.biotech,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  t['test_name']?.toString() ??
                                      t['name']?.toString() ??
                                      'Unknown Test',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                              if (t['code'] != null)
                                Text('Code: ${t['code']}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                              if (t['specimen_type'] != null)
                                Text('Specimen: ${t['specimen_type']}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard(BuildContext context, dynamic order) {
    final results = order.results as List<Map<String, dynamic>>;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 20),
                const SizedBox(width: 8),
                Text('Results',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Test')),
                  DataColumn(label: Text('Result')),
                  DataColumn(label: Text('Unit')),
                  DataColumn(label: Text('Abnormal')),
                  DataColumn(label: Text('Comments')),
                ],
                rows: results
                    .map((r) => DataRow(cells: [
                          DataCell(Text(
                              r['test_name']?.toString() ?? 'Unknown')),
                          DataCell(Text(
                              r['result_value']?.toString() ?? '--')),
                          DataCell(
                              Text(r['unit']?.toString() ?? '')),
                          DataCell(
                            r['is_abnormal'] == true
                                ? const Icon(Icons.warning,
                                    color: Colors.red, size: 18)
                                : const Icon(Icons.check,
                                    color: Colors.green, size: 18),
                          ),
                          DataCell(Text(
                              r['comments']?.toString() ?? '')),
                        ]))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptOrder(int id) async {
    setState(() => _loading = true);
    try {
      await ref
          .read(labExchangeRepositoryProvider)
          .acceptLabExchange(id);
      ref.invalidate(labExchangeDetailProvider(id));
      ref.invalidate(labExchangeListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order accepted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(int id, String newStatus) async {
    setState(() => _loading = true);
    try {
      await ref
          .read(labExchangeRepositoryProvider)
          .updateLabExchange(id, {'status': newStatus});
      ref.invalidate(labExchangeDetailProvider(id));
      ref.invalidate(labExchangeListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Status updated to ${newStatus.replaceAll('_', ' ')}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSubmitResultsDialog(BuildContext context, dynamic order) {
    final tests = order.tests as List<Map<String, dynamic>>;
    final controllers = <String, Map<String, TextEditingController>>{};

    for (final t in tests) {
      final name = t['test_name']?.toString() ?? t['name']?.toString() ?? '';
      controllers[name] = {
        'result': TextEditingController(),
        'unit': TextEditingController(),
        'comments': TextEditingController(),
      };
    }

    final abnormals = <String, bool>{};
    for (final name in controllers.keys) {
      abnormals[name] = false;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Submit Results'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: controllers.entries
                    .map((entry) => Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(entry.key,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextField(
                                      controller: entry.value['result'],
                                      decoration: const InputDecoration(
                                        labelText: 'Result *',
                                        contentPadding:
                                            EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: entry.value['unit'],
                                      decoration: const InputDecoration(
                                        labelText: 'Unit',
                                        contentPadding:
                                            EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: entry.value['comments'],
                                decoration: const InputDecoration(
                                  labelText: 'Comments',
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Checkbox(
                                    value: abnormals[entry.key] ?? false,
                                    onChanged: (v) => setDialogState(() =>
                                        abnormals[entry.key] = v ?? false),
                                  ),
                                  const Text('Abnormal'),
                                ],
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final results = <Map<String, dynamic>>[];
                for (final entry in controllers.entries) {
                  final resultValue =
                      entry.value['result']!.text.trim();
                  if (resultValue.isEmpty) continue;
                  results.add({
                    'test_name': entry.key,
                    'result_value': resultValue,
                    'unit': entry.value['unit']!.text.trim(),
                    'is_abnormal': abnormals[entry.key] ?? false,
                    'comments': entry.value['comments']!.text.trim(),
                  });
                }
                if (results.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Please enter at least one result')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                await _submitResults(order.id, results);
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitResults(
      int id, List<Map<String, dynamic>> results) async {
    setState(() => _loading = true);
    try {
      await ref
          .read(labExchangeRepositoryProvider)
          .submitResults(id, results);
      ref.invalidate(labExchangeDetailProvider(id));
      ref.invalidate(labExchangeListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Results submitted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
