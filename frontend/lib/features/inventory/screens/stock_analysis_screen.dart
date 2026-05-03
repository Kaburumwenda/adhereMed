import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/stock_model.dart';
import '../repository/inventory_repository.dart';

class StockAnalysisScreen extends ConsumerStatefulWidget {
  const StockAnalysisScreen({super.key});

  @override
  ConsumerState<StockAnalysisScreen> createState() => _StockAnalysisScreenState();
}

class _StockAnalysisScreenState extends ConsumerState<StockAnalysisScreen> {
  final _repo = InventoryRepository();

  bool _loading = true;
  String? _error;
  // Scroll control for jumping to sections
  final _lowStockKey = GlobalKey();
  final _expiryKey = GlobalKey();

  void _scrollTo(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut);
      }
    });
  }

  Map<String, dynamic> _analytics = {};
  List<MedicationStock> _lowStock = [];
  List<StockBatch> _expiringSoon = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _repo.getAnalytics(),
        _repo.getLowStock(),
        _repo.getExpiringSoon(days: 90),
      ]);
      setState(() {
        _analytics = results[0] as Map<String, dynamic>;
        _lowStock = (results[1] as dynamic).results as List<MedicationStock>;
        _expiringSoon = results[2] as List<StockBatch>;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _currency(dynamic v) {
    final n = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
    return 'KSh ${NumberFormat('#,##0.00').format(n)}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.analytics_outlined, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stock Analysis',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text('Inventory health, valuation & expiry overview',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_loading)
            const Expanded(child: Center(child: LoadingWidget()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, style: TextStyle(color: AppColors.error)),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _loadAll, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── KPI Cards ──────────────────────────────────────────
                    _SectionTitle('Overview'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _KpiCard(
                          label: 'Total Items',
                          value: '${_analytics['total_items'] ?? 0}',
                          icon: Icons.inventory_2_outlined,
                          color: AppColors.primary,
                          onTap: () => context.push('/inventory'),
                        ),
                        _KpiCard(
                          label: 'Low Stock',
                          value: '${_analytics['low_stock_count'] ?? 0}',
                          icon: Icons.warning_amber_outlined,
                          color: Colors.orange,
                          onTap: () => _scrollTo(_lowStockKey),
                        ),
                        _KpiCard(
                          label: 'Out of Stock',
                          value: '${_analytics['out_of_stock'] ?? 0}',
                          icon: Icons.remove_shopping_cart_outlined,
                          color: AppColors.error,
                          onTap: () => context.push('/alerts'),
                        ),
                        _KpiCard(
                          label: 'Expiring ≤30d',
                          value: '${_analytics['expiring_30_days'] ?? 0}',
                          icon: Icons.hourglass_bottom_outlined,
                          color: Colors.deepOrange,
                          onTap: () => _scrollTo(_expiryKey),
                        ),
                        _KpiCard(
                          label: 'Expiring ≤90d',
                          value: '${_analytics['expiring_90_days'] ?? 0}',
                          icon: Icons.hourglass_top_outlined,
                          color: Colors.amber.shade700,
                          onTap: () => _scrollTo(_expiryKey),
                        ),
                        _KpiCard(
                          label: 'Expired Batches',
                          value: '${_analytics['expired_batches'] ?? 0}',
                          icon: Icons.dangerous_outlined,
                          color: AppColors.error,
                          onTap: () => _scrollTo(_expiryKey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Valuation ─────────────────────────────────────────
                    _SectionTitle('Stock Valuation'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _ValuationCard(
                          label: 'Cost Value',
                          value: _currency(_analytics['total_cost_value']),
                          icon: Icons.price_check_outlined,
                          color: AppColors.primary,
                        ),
                        _ValuationCard(
                          label: 'Retail Value',
                          value: _currency(_analytics['total_retail_value']),
                          icon: Icons.storefront_outlined,
                          color: AppColors.success,
                        ),
                        _ValuationCard(
                          label: 'Potential Profit',
                          value: _currency(_analytics['potential_profit']),
                          icon: Icons.trending_up_outlined,
                          color: Colors.teal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Low Stock Items ───────────────────────────────────
                    if (_lowStock.isNotEmpty) ...[
                      Row(
                        children: [
                          _SectionTitle('Low Stock Items', key: _lowStockKey),
                          const Spacer(),
                          TextButton(
                            onPressed: () => context.push('/alerts'),
                            child: const Text('View All Alerts'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Card(
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppColors.border),
                        ),
                        elevation: 0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Column(
                            children: [
                              for (int i = 0; i < _lowStock.take(10).length; i++) ...[
                                if (i > 0) Divider(height: 1, color: AppColors.border),
                                _LowStockTile(
                                  stock: _lowStock[i],
                                  onTap: () => context.push('/inventory/${_lowStock[i].id}'),
                                ),
                              ],
                              if (_lowStock.length > 10) ...[
                                Divider(height: 1, color: AppColors.border),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    '+ ${_lowStock.length - 10} more low-stock items',
                                    style: TextStyle(
                                        color: AppColors.textSecondary, fontSize: 13),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ── Expiring Batches ──────────────────────────────────
                    if (_expiringSoon.isNotEmpty) ...[
                      _SectionTitle('Expiring Soon (next 90 days)', key: _expiryKey),
                      const SizedBox(height: 8),
                      Card(
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppColors.border),
                        ),
                        elevation: 0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Column(
                            children: [
                              for (int i = 0; i < _expiringSoon.take(10).length; i++) ...[
                                if (i > 0) Divider(height: 1, color: AppColors.border),
                                _ExpiryTile(batch: _expiringSoon[i]),
                              ],
                              if (_expiringSoon.length > 10) ...[
                                Divider(height: 1, color: AppColors.border),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    '+ ${_expiringSoon.length - 10} more expiring batches',
                                    style: TextStyle(
                                        color: AppColors.textSecondary, fontSize: 13),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Section Title ──────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold));
  }
}

// ─── KPI Card ───────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: color,
                          height: 1.1)),
                  Text(label,
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}

// ─── Valuation Card ─────────────────────────────────────────────────────────

class _ValuationCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ValuationCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Low Stock Tile ──────────────────────────────────────────────────────────

class _LowStockTile extends StatelessWidget {
  final MedicationStock stock;
  final VoidCallback onTap;

  const _LowStockTile({required this.stock, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final qty = stock.totalQuantity ?? 0;
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.orange.withValues(alpha: 0.12),
        child: Icon(Icons.warning_amber_outlined,
            size: 18, color: Colors.orange.shade700),
      ),
      title: Text(stock.medicationName,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(stock.categoryName ?? 'No category',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('$qty units',
              style: TextStyle(
                  color: qty == 0 ? AppColors.error : Colors.orange.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          Text('Reorder at ${stock.reorderLevel}',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ─── Expiry Tile ────────────────────────────────────────────────────────────

class _ExpiryTile extends StatelessWidget {
  final StockBatch batch;
  const _ExpiryTile({required this.batch});

  DateTime? get _expiryDt => batch.expiryDate.isNotEmpty
      ? DateTime.tryParse(batch.expiryDate)
      : null;

  @override
  Widget build(BuildContext context) {
    final expiry = _expiryDt != null
        ? DateFormat('dd MMM yyyy').format(_expiryDt!)
        : '—';
    final daysLeft = _expiryDt != null
        ? _expiryDt!.difference(DateTime.now()).inDays
        : null;
    final urgentColor = daysLeft != null && daysLeft <= 30
        ? AppColors.error
        : Colors.amber.shade700;

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: urgentColor.withValues(alpha: 0.12),
        child: Icon(Icons.hourglass_bottom_outlined,
            size: 18, color: urgentColor),
      ),
      title: Text(batch.stockName ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text('Batch: ${batch.batchNumber}  ·  Qty: ${batch.quantityRemaining}',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(expiry,
              style: TextStyle(
                  color: urgentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          if (daysLeft != null)
            Text('$daysLeft days left',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
