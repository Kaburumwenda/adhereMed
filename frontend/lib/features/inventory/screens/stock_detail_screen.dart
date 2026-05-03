import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../models/stock_model.dart';
import '../repository/inventory_repository.dart';

class StockDetailScreen extends ConsumerStatefulWidget {
  final int stockId;
  const StockDetailScreen({super.key, required this.stockId});

  @override
  ConsumerState<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends ConsumerState<StockDetailScreen> {
  final _repo = InventoryRepository();
  MedicationStock? _stock;
  bool _loading = true;
  String? _error;

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
      final stock = await _repo.getStock(widget.stockId);
      setState(() {
        _stock = stock;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    return 'KSh ${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingWidget();
    if (_error != null) {
      return app_error.AppErrorWidget(message: _error!, onRetry: _loadData);
    }
    final stock = _stock!;
    final qty = stock.totalQuantity ?? 0;
    final isLow = stock.isLowStock == true;
    final isOut = qty == 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero Header Card ────────────────────────────────────────────────
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Colored top strip
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.75),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white),
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.medication_outlined,
                            color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stock.medicationName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (stock.categoryName != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                stock.categoryName!,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Status chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isOut
                              ? AppColors.error
                              : isLow
                                  ? AppColors.warning
                                  : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOut
                                  ? Icons.remove_shopping_cart_outlined
                                  : isLow
                                      ? Icons.warning_amber_rounded
                                      : Icons.check_circle_outline,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isOut
                                  ? 'Out of Stock'
                                  : isLow
                                      ? 'Low Stock'
                                      : 'In Stock',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Action buttons row
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.push('/inventory/${stock.id}/edit'),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Metric Cards ────────────────────────────────────────────────────
          Row(
            children: [
              _MetricCard(
                icon: Icons.inventory_2_outlined,
                label: 'Total Qty',
                value: '$qty',
                color: isOut
                    ? AppColors.error
                    : isLow
                        ? AppColors.warning
                        : AppColors.primary,
              ),
              const SizedBox(width: 12),
              _MetricCard(
                icon: Icons.sell_outlined,
                label: 'Selling Price',
                value: _formatCurrency(stock.sellingPrice),
                color: AppColors.success,
              ),
              const SizedBox(width: 12),
              _MetricCard(
                icon: Icons.payments_outlined,
                label: 'Cost Price',
                value: _formatCurrency(stock.costPrice),
                color: AppColors.warning,
              ),
              const SizedBox(width: 12),
              _MetricCard(
                icon: Icons.low_priority_outlined,
                label: 'Reorder Level',
                value: '${stock.reorderLevel}',
                color: AppColors.error,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Stock Information (2-column grid) ───────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.info_outline,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Stock Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ]),
                  const Divider(height: 24),
                  _InfoGrid(items: [
                    _InfoItem('Medication Name', stock.medicationName),
                    _InfoItem('Medication ID', stock.medicationId),
                    _InfoItem('Category', stock.categoryName ?? '-'),
                    _InfoItem(
                        'Unit', stock.unitAbbreviation ?? stock.unitName ?? '-'),
                    _InfoItem(
                        'Selling Price', _formatCurrency(stock.sellingPrice)),
                    _InfoItem('Cost Price', _formatCurrency(stock.costPrice)),
                    _InfoItem('Reorder Level', '${stock.reorderLevel}'),
                    _InfoItem('Reorder Quantity', '${stock.reorderQuantity}'),
                    _InfoItem('Location', stock.locationInStore ?? '-'),
                    _InfoItem('Total Quantity', '$qty'),
                    _InfoItem(
                        'Status', stock.isActive ? 'Active' : 'Inactive'),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Batch Cards ─────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.view_list_outlined,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Batch Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${stock.batches.length} batch${stock.batches.length == 1 ? '' : 'es'}',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ]),
                  const Divider(height: 24),
                  if (stock.batches.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Column(children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 36,
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.4)),
                          const SizedBox(height: 8),
                          Text('No batches available',
                              style: TextStyle(
                                  color: AppColors.textSecondary)),
                        ]),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: stock.batches.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) =>
                          _BatchCard(batch: stock.batches[i]),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Metric Card ──────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Info Grid (2-column) ─────────────────────────────────────────────────────

class _InfoItem {
  final String label;
  final String value;
  const _InfoItem(this.label, this.value);
}

class _InfoGrid extends StatelessWidget {
  final List<_InfoItem> items;
  const _InfoGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    // Pair items into rows
    final rows = <List<_InfoItem>>[];
    for (var i = 0; i < items.length; i += 2) {
      rows.add([
        items[i],
        if (i + 1 < items.length) items[i + 1],
      ]);
    }
    return Column(
      children: rows.map((pair) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(child: _InfoCell(item: pair[0])),
              if (pair.length > 1) ...[
                const SizedBox(width: 16),
                Expanded(child: _InfoCell(item: pair[1])),
              ] else
                const Expanded(child: SizedBox()),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final _InfoItem item;
  const _InfoCell({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 3),
          Text(
            item.value,
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Batch Card ───────────────────────────────────────────────────────────────

class _BatchCard extends StatelessWidget {
  final StockBatch batch;
  const _BatchCard({required this.batch});

  String _formatCurrency(double amount) {
    return 'KSh ${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},')}';
  }

  @override
  Widget build(BuildContext context) {
    int? daysLeft;
    if (batch.expiryDate.isNotEmpty) {
      try {
        final expiry = DateTime.parse(batch.expiryDate);
        daysLeft = expiry.difference(DateTime.now()).inDays;
      } catch (_) {}
    }

    final expired = batch.isExpired || (daysLeft != null && daysLeft <= 0);
    final expiringSoon =
        !expired && daysLeft != null && daysLeft <= 30;
    final statusColor = expired
        ? AppColors.error
        : expiringSoon
            ? AppColors.warning
            : AppColors.success;
    final statusLabel = expired
        ? 'Expired'
        : expiringSoon
            ? '${daysLeft}d left'
            : 'Valid';

    final pct = batch.quantityReceived > 0
        ? (batch.quantityRemaining / batch.quantityReceived).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
        color: expired
            ? AppColors.error.withValues(alpha: 0.03)
            : expiringSoon
                ? AppColors.warning.withValues(alpha: 0.03)
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Batch ${batch.batchNumber}',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      expired
                          ? Icons.cancel_outlined
                          : expiringSoon
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline,
                      color: statusColor,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Details row
          Row(
            children: [
              _BatchDetail(
                label: 'Received',
                value: '${batch.quantityReceived}',
                icon: Icons.input_outlined,
              ),
              const SizedBox(width: 8),
              _BatchDetail(
                label: 'Remaining',
                value: '${batch.quantityRemaining}',
                icon: Icons.inventory_2_outlined,
              ),
              const SizedBox(width: 8),
              _BatchDetail(
                label: 'Cost/Unit',
                value: _formatCurrency(batch.costPricePerUnit),
                icon: Icons.payments_outlined,
              ),
              const SizedBox(width: 8),
              _BatchDetail(
                label: 'Expiry',
                value: batch.expiryDate,
                icon: Icons.event_outlined,
                valueColor: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Stock level bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Stock level',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                  Text(
                    '${(pct * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 5,
                  backgroundColor:
                      AppColors.border.withValues(alpha: 0.5),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BatchDetail extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _BatchDetail({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 11, color: AppColors.textSecondary),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 10)),
          ]),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
