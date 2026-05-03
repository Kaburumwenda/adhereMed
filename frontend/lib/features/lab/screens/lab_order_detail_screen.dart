import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../../../core/widgets/status_badge.dart';
import '../models/lab_order_model.dart';
import '../repository/lab_repository.dart';

class LabOrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  const LabOrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<LabOrderDetailScreen> createState() =>
      _LabOrderDetailScreenState();
}

class _LabOrderDetailScreenState extends ConsumerState<LabOrderDetailScreen> {
  final _repo = LabRepository();
  LabOrder? _order;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final o = await _repo.getOrder(int.parse(widget.orderId));
      setState(() { _order = o; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _sendToLab(int orderId) async {
    try {
      await _repo.sendToLab(orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lab order sent to external lab successfully')),
        );
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
    if (_loading) return const LoadingWidget();
    if (_error != null) {
      return app_error.AppErrorWidget(message: _error!, onRetry: _loadData);
    }
    final o = _order!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Lab Order #${o.id}',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              StatusBadge(status: o.status),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => context.push('/lab-orders/${o.id}/edit'),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _sendToLab(o.id),
                icon: const Icon(Icons.send, size: 18),
                label: const Text('Send to Lab'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Order info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order Information',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 32,
                    runSpacing: 12,
                    children: [
                      _info('Patient', o.patientName ?? 'ID: ${o.patientId}'),
                      _info('Ordered By', o.orderedByName ?? '-'),
                      _info('Priority', o.priority.toUpperCase()),
                      _info('Date', o.createdAt?.split('T').first ?? '-'),
                      if (o.isHomeCollection)
                        _info('Home Collection', 'Yes'),
                    ],
                  ),
                  if (o.testNames != null && o.testNames!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Tests Ordered',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: o.testNames!.map((t) => Chip(
                        label: Text(t, style: const TextStyle(fontSize: 13)),
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      )).toList(),
                    ),
                  ],
                  if (o.clinicalNotes != null && o.clinicalNotes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Clinical Notes',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(o.clinicalNotes!),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Results
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Results',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (o.results == null || o.results!.isEmpty)
                        FilledButton.icon(
                          onPressed: () => _addResult(o),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Result'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (o.results == null || o.results!.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('No results recorded yet.',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(AppColors.background),
                        columns: const [
                          DataColumn(label: Text('Test', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('Result', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('Unit', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('Abnormal', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('Performed By', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('Comments', style: TextStyle(fontWeight: FontWeight.w600))),
                        ],
                        rows: o.results!.map((r) {
                          return DataRow(cells: [
                            DataCell(Text(r.testName ?? '-')),
                            DataCell(Text(r.resultValue,
                                style: TextStyle(
                                  color: r.isAbnormal ? AppColors.error : null,
                                  fontWeight: r.isAbnormal ? FontWeight.w600 : null,
                                ))),
                            DataCell(Text(r.unit ?? '-')),
                            DataCell(r.isAbnormal
                                ? Icon(Icons.warning_amber, color: AppColors.error, size: 18)
                                : Icon(Icons.check_circle_outline, color: AppColors.success, size: 18)),
                            DataCell(Text(r.performedByName ?? '-')),
                            DataCell(Text(r.comments ?? '-')),
                          ]);
                        }).toList(),
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

  Widget _info(String label, String value) {
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _addResult(LabOrder order) async {
    final resultCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final commentsCtrl = TextEditingController();
    bool isAbnormal = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Result'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: resultCtrl,
                  decoration: const InputDecoration(labelText: 'Result Value'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: unitCtrl,
                  decoration: const InputDecoration(labelText: 'Unit'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Abnormal'),
                  value: isAbnormal,
                  onChanged: (v) => setDialogState(() => isAbnormal = v),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commentsCtrl,
                  decoration: const InputDecoration(labelText: 'Comments'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (resultCtrl.text.isNotEmpty) {
                  await _repo.createResult({
                    'order': order.id,
                    'result_value': resultCtrl.text,
                    'unit': unitCtrl.text,
                    'is_abnormal': isAbnormal,
                    'comments': commentsCtrl.text,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    resultCtrl.dispose();
    unitCtrl.dispose();
    commentsCtrl.dispose();
  }
}
