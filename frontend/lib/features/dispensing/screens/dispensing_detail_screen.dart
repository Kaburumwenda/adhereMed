import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../models/dispensing_model.dart';
import '../repository/dispensing_repository.dart';

class DispensingDetailScreen extends ConsumerStatefulWidget {
  final int recordId;
  const DispensingDetailScreen({super.key, required this.recordId});

  @override
  ConsumerState<DispensingDetailScreen> createState() =>
      _DispensingDetailScreenState();
}

class _DispensingDetailScreenState
    extends ConsumerState<DispensingDetailScreen> {
  final _repo = DispensingRepository();
  DispensingRecord? _record;
  bool _loading = true;
  String? _error;

  // Per-item dispensed state (mutable copy)
  late List<bool> _itemDispensed;
  bool _savingItems = false;

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
      final record = await _repo.getRecord(widget.recordId);
      if (mounted) {
        setState(() {
          _record = record;
          _itemDispensed = record.items.map((i) => i.dispensed).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.warning;
      case 'dispensed':
        return AppColors.success;
      case 'partial':
        return AppColors.primary;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Future<void> _saveDispensed() async {
    if (_record == null) return;
    setState(() => _savingItems = true);
    try {
      final items = _record!.items.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;
        return {
          'id': item.id,
          'medication_stock': item.medicationStockId,
          'medication_name': item.medicationName ?? '',
          'quantity': item.quantity,
          'dispensed': _itemDispensed[i],
        };
      }).toList();

      // Determine new status based on items
      final allDispensed = _itemDispensed.every((d) => d);
      final anyDispensed = _itemDispensed.any((d) => d);
      final newStatus = allDispensed
          ? 'dispensed'
          : anyDispensed
              ? 'partial'
              : 'pending';

      await _repo.updateRecord(widget.recordId, {
        'items_dispensed': items,
        'status': newStatus,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(allDispensed
                ? 'All items marked as dispensed.'
                : 'Partial dispensing saved.'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingItems = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingWidget();
    if (_error != null) {
      return app_error.AppErrorWidget(message: _error!, onRetry: _loadData);
    }
    final record = _record!;
    final statusColor = _statusColor(record.status);
    final dispensedCount = _itemDispensed.where((d) => d).length;
    final canSave = record.status != 'dispensed' && record.status != 'cancelled';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dispensing Record #${record.id}',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dispensing Details',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  record.status.isNotEmpty
                      ? record.status[0].toUpperCase() +
                          record.status.substring(1)
                      : record.status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Record Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Divider(height: 32),
                  _infoRow('Patient', record.patientName ?? '-'),
                  _infoRow(
                      'Exchange Ref',
                      record.prescriptionExchangeId != null
                          ? '#${record.prescriptionExchangeId}'
                          : '-'),
                  _infoRow(
                      'Status',
                      record.status.isNotEmpty
                          ? record.status[0].toUpperCase() +
                              record.status.substring(1)
                          : record.status),
                  _infoRow('Dispensed By', record.dispensedBy ?? '-'),
                  _infoRow('Date', _formatDate(record.createdAt)),
                  if (record.notes != null && record.notes!.isNotEmpty)
                    _infoRow('Notes', record.notes!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Items with toggle
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(
                      'Dispensed Items',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$dispensedCount / ${record.items.length} dispensed',
                      style: TextStyle(
                          color: dispensedCount == record.items.length
                              ? AppColors.success
                              : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  if (canSave)
                    Text(
                      'Toggle items to mark as dispensed or pending.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  const SizedBox(height: 16),
                  record.items.isEmpty
                      ? Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No items in this record',
                              style: TextStyle(
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      : Column(
                          children: record.items.asMap().entries.map((entry) {
                            final i = entry.key;
                            final item = entry.value;
                            final dispensed = _itemDispensed[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: dispensed
                                    ? AppColors.success
                                        .withValues(alpha: 0.05)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: dispensed
                                      ? AppColors.success
                                          .withValues(alpha: 0.3)
                                      : AppColors.border,
                                ),
                              ),
                              child: Row(children: [
                                Icon(
                                  dispensed
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: dispensed
                                      ? AppColors.success
                                      : AppColors.textSecondary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.medicationName ?? '-',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: dispensed
                                              ? AppColors.textPrimary
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Qty: ${item.quantity}',
                                        style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                if (canSave)
                                  Switch(
                                    value: dispensed,
                                    onChanged: (v) => setState(
                                        () => _itemDispensed[i] = v),
                                    activeThumbColor: AppColors.success,
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: dispensed
                                          ? AppColors.success
                                              .withValues(alpha: 0.1)
                                          : AppColors.warning
                                              .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      dispensed ? 'Dispensed' : 'Pending',
                                      style: TextStyle(
                                        color: dispensed
                                            ? AppColors.success
                                            : AppColors.warning,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ]),
                            );
                          }).toList(),
                        ),

                  if (canSave && record.items.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => setState(() {
                            _itemDispensed = List.filled(
                                record.items.length, true);
                          }),
                          child: const Text('Mark All Dispensed'),
                        ),
                        FilledButton.icon(
                          onPressed: _savingItems ? null : _saveDispensed,
                          icon: _savingItems
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_outlined, size: 16),
                          label: const Text('Save Dispensing'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
