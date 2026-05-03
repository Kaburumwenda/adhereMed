import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../../../core/widgets/status_badge.dart';
import '../models/ward_model.dart';
import '../repository/ward_repository.dart';

class WardDetailScreen extends ConsumerStatefulWidget {
  final String wardId;
  const WardDetailScreen({super.key, required this.wardId});

  @override
  ConsumerState<WardDetailScreen> createState() => _WardDetailScreenState();
}

class _WardDetailScreenState extends ConsumerState<WardDetailScreen> {
  final _repo = WardRepository();
  Ward? _ward;
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
      final ward = await _repo.getWard(int.parse(widget.wardId));
      setState(() { _ward = ward; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingWidget();
    if (_error != null) {
      return app_error.AppErrorWidget(message: _error!, onRetry: _loadData);
    }
    final w = _ward!;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(w.name,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                StatusBadge(status: w.isActive ? 'active' : 'inactive'),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => context.push('/wards/${w.id}/edit'),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Ward info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ward Information',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 32,
                      runSpacing: 12,
                      children: [
                        _info('Type', w.type.toUpperCase()),
                        _info('Floor', w.floor ?? '-'),
                        _info('Capacity', '${w.capacity} beds'),
                        _info('Available Beds', '${w.availableBeds ?? "-"}'),
                        _info('Daily Rate', '\$${w.dailyRate.toStringAsFixed(2)}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Beds section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Beds',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: () async {
                            await _showAddBedDialog();
                            _loadData();
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Bed'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (w.beds == null || w.beds!.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('No beds added yet.',
                              style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: w.beds!.map((bed) {
                          final color = _bedStatusColor(bed.status);
                          return Card(
                            color: color.withValues(alpha: 0.1),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bed_outlined, color: color, size: 28),
                                  const SizedBox(height: 4),
                                  Text('Bed ${bed.bedNumber}',
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  StatusBadge(status: bed.status),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value) {
    return SizedBox(
      width: 180,
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

  Color _bedStatusColor(String status) {
    switch (status) {
      case 'available':
        return AppColors.success;
      case 'occupied':
        return AppColors.error;
      case 'maintenance':
        return AppColors.warning;
      case 'reserved':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  Future<void> _showAddBedDialog() async {
    final bedNumberCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Bed'),
        content: TextField(
          controller: bedNumberCtrl,
          decoration: const InputDecoration(labelText: 'Bed Number'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (bedNumberCtrl.text.isNotEmpty) {
                await _repo.createBed({
                  'ward': int.parse(widget.wardId),
                  'bed_number': bedNumberCtrl.text,
                  'status': 'available',
                });
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    bedNumberCtrl.dispose();
  }
}
