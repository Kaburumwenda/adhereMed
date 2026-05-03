import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../../../core/widgets/status_badge.dart';
import '../models/radiology_model.dart';
import '../repository/radiology_repository.dart';

class RadiologyOrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  const RadiologyOrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<RadiologyOrderDetailScreen> createState() =>
      _RadiologyOrderDetailScreenState();
}

class _RadiologyOrderDetailScreenState
    extends ConsumerState<RadiologyOrderDetailScreen> {
  final _repo = RadiologyRepository();
  RadiologyOrder? _order;
  bool _loading = true;
  String? _error;

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
      final order = await _repo.getOrder(int.parse(widget.orderId));
      setState(() { _order = order; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingWidget();
    if (_error != null) return app_error.AppErrorWidget(message: _error!, onRetry: _loadData);
    final o = _order!;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${_typeLabels[o.imagingType] ?? o.imagingType} — ${o.bodyPart}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                StatusBadge(status: o.status),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => context.push('/radiology/${o.id}/edit'),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
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
                        _row('Patient', o.patientName ?? 'ID: ${o.patientId}'),
                        _row('Ordered By', o.orderedByName ?? '-'),
                        _row('Imaging Type', _typeLabels[o.imagingType] ?? o.imagingType),
                        _row('Body Part', o.bodyPart),
                        _row('Priority', o.priority.toUpperCase()),
                        _row('Date', o.createdAt?.split('T').first ?? '-'),
                      ],
                    ),
                    if (o.clinicalIndication != null && o.clinicalIndication!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('Clinical Indication',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(o.clinicalIndication!),
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
                        if (o.result == null)
                          FilledButton.icon(
                            onPressed: () => _addResult(o),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Result'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (o.result == null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('No result recorded yet.',
                              style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      )
                    else ...[
                      _row('Radiologist', o.result!.radiologistName ?? '-'),
                      const SizedBox(height: 12),
                      Text('Findings',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(o.result!.findings),
                      if (o.result!.impression != null && o.result!.impression!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('Impression',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(o.result!.impression!),
                      ],
                      if (o.result!.imageUrl != null && o.result!.imageUrl!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('Image URL',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(o.result!.imageUrl!, style: TextStyle(color: AppColors.primary)),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return SizedBox(
      width: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Future<void> _addResult(RadiologyOrder order) async {
    final findingsCtrl = TextEditingController();
    final impressionCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Result'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: findingsCtrl,
                decoration: const InputDecoration(labelText: 'Findings'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: impressionCtrl,
                decoration: const InputDecoration(labelText: 'Impression'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (findingsCtrl.text.isNotEmpty) {
                await _repo.createResult({
                  'order': order.id,
                  'findings': findingsCtrl.text,
                  'impression': impressionCtrl.text,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    findingsCtrl.dispose();
    impressionCtrl.dispose();
  }
}
