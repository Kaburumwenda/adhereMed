import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../../../core/widgets/empty_state_widget.dart';
import '../../inventory/models/stock_model.dart';
import '../../inventory/repository/inventory_repository.dart';
import '../../suppliers/repository/supplier_repository.dart';
import '../../suppliers/models/supplier_model.dart';
import '../../purchase_orders/repository/purchase_order_repository.dart';

class PharmacyAlertsScreen extends ConsumerStatefulWidget {
  const PharmacyAlertsScreen({super.key});

  @override
  ConsumerState<PharmacyAlertsScreen> createState() =>
      _PharmacyAlertsScreenState();
}

class _PharmacyAlertsScreenState
    extends ConsumerState<PharmacyAlertsScreen>
    with SingleTickerProviderStateMixin {
  final _inventoryRepo = InventoryRepository();
  final _supplierRepo = SupplierRepository();
  final _poRepo = PurchaseOrderRepository();

  late final TabController _tabController;

  List<MedicationStock>? _lowStock;
  List<StockBatch>? _expiring30;
  List<StockBatch>? _expiring90;
  bool _loading = true;
  String? _error;
  int _expiryDays = 30;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _inventoryRepo.getLowStock(),
        _inventoryRepo.getExpiringSoon(days: 30),
        _inventoryRepo.getExpiringSoon(days: 90),
      ]);
      if (mounted) {
        setState(() {
          _lowStock =
              (results[0] as dynamic).results as List<MedicationStock>;
          _expiring30 = results[1] as List<StockBatch>;
          _expiring90 = results[2] as List<StockBatch>;
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

  List<StockBatch> get _currentExpiring =>
      _expiryDays == 30 ? (_expiring30 ?? []) : (_expiring90 ?? []);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.notifications_active_outlined,
                    color: AppColors.error, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pharmacy Alerts',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text(
                      'Monitor low stock and expiring medications',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Summary Stat Cards ───────────────────────────────────────────────
          if (!_loading && _lowStock != null)
            Row(children: [
              _AlertStat(
                icon: Icons.inventory_2_outlined,
                label: 'Low Stock',
                value: '${_lowStock!.length}',
                color: AppColors.warning,
                onTap: () => _tabController.animateTo(0),
              ),
              const SizedBox(width: 12),
              _AlertStat(
                icon: Icons.event_busy_outlined,
                label: 'Expiring (30d)',
                value: '${_expiring30?.length ?? 0}',
                color: AppColors.error,
                onTap: () {
                  setState(() => _expiryDays = 30);
                  _tabController.animateTo(1);
                },
              ),
              const SizedBox(width: 12),
              _AlertStat(
                icon: Icons.event_note_outlined,
                label: 'Expiring (90d)',
                value: '${_expiring90?.length ?? 0}',
                color: AppColors.primary,
                onTap: () {
                  setState(() => _expiryDays = 90);
                  _tabController.animateTo(1);
                },
              ),
              const SizedBox(width: 12),
              _AlertStat(
                icon: Icons.check_circle_outline,
                label: 'Total Monitored',
                value: '${(_lowStock?.length ?? 0) + (_expiring90?.length ?? 0)}',
                color: AppColors.success,
                onTap: () => _tabController.animateTo(0),
              ),
            ]),

          if (!_loading && _lowStock != null) const SizedBox(height: 16),

          // ── Tab Bar ──────────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(
                  child: Row(children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 16, color: AppColors.warning),
                    const SizedBox(width: 6),
                    const Text('Low Stock'),
                    if (!_loading && (_lowStock?.isNotEmpty == true)) ...[
                      const SizedBox(width: 6),
                      _Badge(
                          count: _lowStock!.length,
                          color: AppColors.warning),
                    ],
                  ]),
                ),
                Tab(
                  child: Row(children: [
                    Icon(Icons.event_busy_outlined,
                        size: 16, color: AppColors.error),
                    const SizedBox(width: 6),
                    const Text('Expiring Soon'),
                    if (!_loading && (_expiring30?.isNotEmpty == true)) ...[
                      const SizedBox(width: 6),
                      _Badge(
                          count: _expiring30!.length,
                          color: AppColors.error),
                    ],
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: _loading
                ? const Center(child: LoadingWidget())
                : _error != null
                    ? app_error.AppErrorWidget(
                        message: _error!, onRetry: _loadData)
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildLowStockTab(),
                          _buildExpiryTab(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // ─── Low Stock Tab ──────────────────────────────────────────────────────────

  Widget _buildLowStockTab() {
    final items = _lowStock ?? [];
    if (items.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.check_circle_outline,
        title: 'All Stock Levels OK',
        subtitle: 'No items are below their reorder level.',
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final stock = items[i];
        final qty = stock.totalQuantity ?? 0;
        final level = stock.reorderLevel;
        final pct = level > 0 ? (qty / level).clamp(0.0, 1.0) : 0.0;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.inventory_2_outlined,
                        color: AppColors.warning, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stock.medicationName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        Text(stock.categoryName ?? 'Uncategorized',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: qty == 0
                              ? AppColors.error.withValues(alpha: 0.1)
                              : AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          qty == 0 ? 'OUT OF STOCK' : 'LOW STOCK',
                          style: TextStyle(
                              color: qty == 0
                                  ? AppColors.error
                                  : AppColors.warning,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$qty / $level units',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor:
                        AppColors.warning.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        qty == 0 ? AppColors.error : AppColors.warning),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.push('/inventory/${stock.id}'),
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('View'),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () =>
                          _showReorderDialog(context, stock),
                      icon: const Icon(Icons.add_shopping_cart, size: 16),
                      label: const Text('Reorder'),
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Expiry Tab ─────────────────────────────────────────────────────────────

  Widget _buildExpiryTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day filter chips
        Row(children: [
          const Text('Show items expiring within:',
              style: TextStyle(fontSize: 13)),
          const SizedBox(width: 12),
          ChoiceChip(
            label: const Text('30 days'),
            selected: _expiryDays == 30,
            onSelected: (_) => setState(() => _expiryDays = 30),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('90 days'),
            selected: _expiryDays == 90,
            onSelected: (_) => setState(() => _expiryDays = 90),
          ),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: _currentExpiring.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.event_available_outlined,
                  title: 'No Expiring Items',
                  subtitle:
                      'No batches expiring within $_expiryDays days.',
                )
              : ListView.separated(
                  itemCount: _currentExpiring.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) =>
                      _ExpiryCard(batch: _currentExpiring[i]),
                ),
        ),
      ],
    );
  }

  // ─── Reorder Dialog ──────────────────────────────────────────────────────────

  void _showReorderDialog(BuildContext context, MedicationStock stock) {
    showDialog(
      context: context,
      builder: (ctx) => _ReorderDialog(
        stock: stock,
        supplierRepo: _supplierRepo,
        poRepo: _poRepo,
        onCreated: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Draft purchase order created for ${stock.medicationName}.'),
              backgroundColor: AppColors.success,
            ),
          );
        },
      ),
    );
  }
}

// ── Alert Stat Card ───────────────────────────────────────────────────────────

class _AlertStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _AlertStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),   // Container
    ),     // InkWell
  ),       // Material
);
  }
}

// ─── Expiry Card ──────────────────────────────────────────────────────────────

class _ExpiryCard extends StatelessWidget {
  final StockBatch batch;
  const _ExpiryCard({required this.batch});

  @override
  Widget build(BuildContext context) {
    int? daysLeft;
    if (batch.expiryDate.isNotEmpty) {
      try {
        final expiry = DateTime.parse(batch.expiryDate);
        daysLeft = expiry.difference(DateTime.now()).inDays;
      } catch (_) {}
    }

    final urgent = (daysLeft ?? 999) <= 30;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: urgent
                    ? AppColors.error.withValues(alpha: 0.1)
                    : AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.event_busy_outlined,
                  color: urgent ? AppColors.error : AppColors.warning,
                  size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(batch.stockName ?? 'Unknown Medication',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('Batch: ${batch.batchNumber}',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    'Expires: ${batch.expiryDate}',
                    style: TextStyle(
                        color: urgent ? AppColors.error : AppColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: urgent
                        ? AppColors.error.withValues(alpha: 0.1)
                        : AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    daysLeft != null
                        ? daysLeft <= 0
                            ? 'EXPIRED'
                            : '${daysLeft}d left'
                        : 'CHECK',
                    style: TextStyle(
                        color:
                            urgent ? AppColors.error : AppColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                Text('Qty: ${batch.quantityRemaining}',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Alert Badge ──────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final int count;
  final Color color;
  const _Badge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ─── Reorder Dialog ───────────────────────────────────────────────────────────

class _ReorderDialog extends StatefulWidget {
  final MedicationStock stock;
  final SupplierRepository supplierRepo;
  final PurchaseOrderRepository poRepo;
  final VoidCallback onCreated;

  const _ReorderDialog({
    required this.stock,
    required this.supplierRepo,
    required this.poRepo,
    required this.onCreated,
  });

  @override
  State<_ReorderDialog> createState() => _ReorderDialogState();
}

class _ReorderDialogState extends State<_ReorderDialog> {
  List<Supplier> _suppliers = [];
  Supplier? _selected;
  bool _loadingSuppliers = true;
  bool _saving = false;
  String? _error;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
        text: '${widget.stock.reorderQuantity}');
    _priceCtrl = TextEditingController(
        text: widget.stock.costPrice.toStringAsFixed(2));
    _loadSuppliers();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    try {
      final result = await widget.supplierRepo.getSuppliers();
      if (mounted) {
        setState(() {
          _suppliers = result.results;
          _loadingSuppliers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSuppliers = false);
    }
  }

  Future<void> _createDraftPO() async {
    if (_selected == null) {
      setState(() => _error = 'Please select a supplier.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final qty = int.tryParse(_qtyCtrl.text) ?? 1;
      final price = double.tryParse(_priceCtrl.text) ?? 0;
      await widget.poRepo.createPurchaseOrder({
        'supplier': _selected!.id,
        'status': 'draft',
        'items': [
          {
            'medication_stock_id': widget.stock.id,
            'name': widget.stock.medicationName,
            'qty': qty,
            'unit_cost': price,
            'total': qty * price,
          }
        ],
        'total_cost': qty * price,
        'notes':
            'Auto-generated reorder for low stock: ${widget.stock.medicationName}',
      });
      widget.onCreated();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reorder: ${widget.stock.medicationName}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'Current stock: ${widget.stock.totalQuantity ?? 0} · '
                'Reorder level: ${widget.stock.reorderLevel}',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              if (_loadingSuppliers)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<Supplier>(
                  initialValue: _selected,
                  decoration: const InputDecoration(
                    labelText: 'Supplier *',
                    border: OutlineInputBorder(),
                  ),
                  items: _suppliers
                      .map((s) =>
                          DropdownMenuItem(value: s, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _selected = v),
                ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Qty to Order',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Unit Cost (KSh)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ]),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(color: AppColors.error, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : _createDraftPO,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add_shopping_cart, size: 16),
                    label: const Text('Create Draft PO'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
