import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/api.dart';
import '../../../widgets/common.dart';

// ── helpers ──
double _dbl(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
final _fmt = NumberFormat.compactCurrency(symbol: 'KSH ', decimalDigits: 0);
final _fmtFull = NumberFormat('#,##0', 'en');

// ── data providers ──
final _stocksProvider = FutureProvider.autoDispose<List>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/inventory/stocks/', queryParameters: {'page_size': 500});
  return (res.data['results'] as List?) ?? [];
});

final _categoriesProvider = FutureProvider.autoDispose<List>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/inventory/categories/', queryParameters: {'page_size': 200});
  return (res.data['results'] as List?) ?? [];
});

final _unitsProvider = FutureProvider.autoDispose<List>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/inventory/units/', queryParameters: {'page_size': 200});
  return (res.data['results'] as List?) ?? [];
});

final _adjustmentsProvider = FutureProvider.autoDispose<List>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/inventory/adjustments/', queryParameters: {'page_size': 200, 'ordering': '-created_at'});
  return (res.data['results'] as List?) ?? [];
});

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});
  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> with TickerProviderStateMixin {
  late TabController _tabCtrl;
  String _search = '';
  String _statusFilter = 'all';
  String? _categoryFilter;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _invalidateAll() {
    ref.invalidate(_stocksProvider);
    ref.invalidate(_categoriesProvider);
    ref.invalidate(_unitsProvider);
    ref.invalidate(_adjustmentsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stocksAsync = ref.watch(_stocksProvider);
    final categoriesAsync = ref.watch(_categoriesProvider);
    final unitsAsync = ref.watch(_unitsProvider);
    final adjustmentsAsync = ref.watch(_adjustmentsProvider);

    return Column(children: [
      // ── Header ──
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
        child: Row(children: [
          Text('Inventory', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.refresh_rounded, size: 20), onPressed: _invalidateAll),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 22),
            style: IconButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
            onPressed: () => context.go('/inventory/add'),
          ),
        ]),
      ),

      // ── KPI Strip ──
      stocksAsync.when(
        loading: () => const SizedBox(height: 60),
        error: (_, __) => const SizedBox.shrink(),
        data: (stocks) {
          final totalSku = stocks.length;
          final lowCount = stocks.where((s) => s['is_low_stock'] == true && _dbl(s['total_quantity'] ?? s['quantity']) > 0).length;
          final outCount = stocks.where((s) => _dbl(s['total_quantity'] ?? s['quantity']) <= 0).length;
          final now = DateTime.now();
          final soon = now.add(const Duration(days: 90));
          final expiringCount = stocks.where((s) {
            final exp = DateTime.tryParse((s['expiry_date'] ?? '').toString());
            return exp != null && exp.isBefore(soon) && !exp.isBefore(now);
          }).length;
          final retailValue = stocks.fold<double>(0, (sum, s) => sum + _dbl(s['selling_price']) * _dbl(s['total_quantity'] ?? s['quantity']));

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: SizedBox(
              height: 56,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                _KpiPill(Icons.inventory_2_rounded, '$totalSku', 'SKUs', cs.primary, cs),
                _KpiPill(Icons.warning_amber_rounded, '$lowCount', 'Low stock', Colors.orange, cs),
                _KpiPill(Icons.remove_shopping_cart_rounded, '$outCount', 'Out of stock', Colors.red, cs),
                _KpiPill(Icons.schedule_rounded, '$expiringCount', 'Expiring', const Color(0xFF8B5CF6), cs),
                _KpiPill(Icons.account_balance_wallet_rounded, _fmt.format(retailValue), 'Retail value', const Color(0xFF3B82F6), cs),
              ]),
            ),
          );
        },
      ),

      // ── Tab Bar ──
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(3),
          child: TabBar(
            controller: _tabCtrl,
            indicator: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: cs.primary,
            unselectedLabelColor: cs.onSurfaceVariant,
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            splashBorderRadius: BorderRadius.circular(10),
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(height: 34, text: 'Stocks'),
              Tab(height: 34, text: 'Analysis'),
              Tab(height: 34, text: 'Categories'),
              Tab(height: 34, text: 'Units'),
              Tab(height: 34, text: 'Adjustments'),
            ],
          ),
        ),
      ),

      // ── Tab Views ──
      Expanded(child: TabBarView(
        controller: _tabCtrl,
        children: [
          _StocksTab(
            stocksAsync: stocksAsync, categoriesAsync: categoriesAsync,
            search: _search, statusFilter: _statusFilter, categoryFilter: _categoryFilter,
            searchCtrl: _searchCtrl,
            onSearchChanged: (v) => setState(() => _search = v),
            onStatusChanged: (v) => setState(() => _statusFilter = v),
            onCategoryChanged: (v) => setState(() => _categoryFilter = v),
            onRefresh: () async => ref.invalidate(_stocksProvider),
            onDelete: (id) => _deleteItem('/inventory/stocks/$id/', _stocksProvider),
          ),
          _AnalysisTab(stocksAsync: stocksAsync, onRefresh: _invalidateAll),
          _CategoriesTab(categoriesAsync: categoriesAsync, stocksAsync: stocksAsync, onRefresh: () async => ref.invalidate(_categoriesProvider), onDelete: (id) => _deleteItem('/inventory/categories/$id/', _categoriesProvider), onAdd: () => _showAddCategorySheet()),
          _UnitsTab(unitsAsync: unitsAsync, stocksAsync: stocksAsync, onRefresh: () async => ref.invalidate(_unitsProvider), onDelete: (id) => _deleteItem('/inventory/units/$id/', _unitsProvider), onAdd: () => _showAddUnitSheet()),
          _AdjustmentsTab(adjustmentsAsync: adjustmentsAsync, onRefresh: () async => ref.invalidate(_adjustmentsProvider), onAdd: () => context.push('/inventory/adjustments/add')),
        ],
      )),
    ]);
  }

  Future<void> _deleteItem(String endpoint, ProviderOrFamily provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm delete'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(dioProvider).delete(endpoint);
      ref.invalidate(provider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted successfully')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _showAddCategorySheet() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Add Category', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name *', hintText: 'e.g. Antibiotics', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description', hintText: 'Optional description', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: loading ? null : () async {
                    if (!formKey.currentState!.validate()) return;
                    setSheetState(() => loading = true);
                    try {
                      await ref.read(dioProvider).post('/inventory/categories/', data: {
                        'name': nameCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Failed: $e')));
                      setSheetState(() => loading = false);
                    }
                  },
                  child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Add Category'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );

    nameCtrl.dispose();
    descCtrl.dispose();
    if (result == true) {
      ref.invalidate(_categoriesProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category added')));
    }
  }

  Future<void> _showAddUnitSheet() async {
    final nameCtrl = TextEditingController();
    final abbrCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Add Unit', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name *', hintText: 'e.g. Tablets, Capsules', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: abbrCtrl,
                decoration: const InputDecoration(labelText: 'Abbreviation', hintText: 'e.g. tab, cap, ml', border: OutlineInputBorder()),
                maxLength: 10,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: loading ? null : () async {
                    if (!formKey.currentState!.validate()) return;
                    setSheetState(() => loading = true);
                    try {
                      await ref.read(dioProvider).post('/inventory/units/', data: {
                        'name': nameCtrl.text.trim(),
                        'abbreviation': abbrCtrl.text.trim(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Failed: $e')));
                      setSheetState(() => loading = false);
                    }
                  },
                  child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Add Unit'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );

    nameCtrl.dispose();
    abbrCtrl.dispose();
    if (result == true) {
      ref.invalidate(_unitsProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unit added')));
    }
  }
}

// ══════════════════════════════════════════
// KPI Pill
// ══════════════════════════════════════════
class _KpiPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final ColorScheme cs;
  const _KpiPill(this.icon, this.value, this.label, this.color, this.cs);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface)),
          Text(label, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════
// TAB 0: Stocks
// ══════════════════════════════════════════
class _StocksTab extends StatelessWidget {
  final AsyncValue<List> stocksAsync;
  final AsyncValue<List> categoriesAsync;
  final String search;
  final String statusFilter;
  final String? categoryFilter;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String?> onCategoryChanged;
  final Future<void> Function() onRefresh;
  final Future<void> Function(int id) onDelete;

  const _StocksTab({
    required this.stocksAsync, required this.categoriesAsync,
    required this.search, required this.statusFilter, required this.categoryFilter,
    required this.searchCtrl, required this.onSearchChanged, required this.onStatusChanged,
    required this.onCategoryChanged, required this.onRefresh, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final categories = categoriesAsync.valueOrNull ?? [];

    return stocksAsync.when(
      loading: () => const LoadingShimmer(),
      error: (e, _) => ErrorRetry(message: 'Failed to load stocks', onRetry: onRefresh),
      data: (allStocks) {
        var filtered = allStocks.where((s) {
          if (search.isNotEmpty) {
            final q = search.toLowerCase();
            final name = (s['medication_name'] ?? '').toString().toLowerCase();
            final barcode = (s['barcode'] ?? '').toString().toLowerCase();
            if (!name.contains(q) && !barcode.contains(q)) return false;
          }
          if (statusFilter == 'low_stock' && s['is_low_stock'] != true) return false;
          if (statusFilter == 'out_of_stock' && _dbl(s['total_quantity'] ?? s['quantity']) > 0) return false;
          if (statusFilter == 'in_stock' && (s['is_low_stock'] == true || _dbl(s['total_quantity'] ?? s['quantity']) <= 0)) return false;
          if (categoryFilter != null && '${s['category']}' != categoryFilter) return false;
          return true;
        }).toList();

        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: TextField(
              controller: searchCtrl, onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search medications, barcode...', hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: search.isNotEmpty ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: () { searchCtrl.clear(); onSearchChanged(''); }) : null,
                isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4))),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SizedBox(
              height: 32,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                _FilterChip(label: 'All', selected: statusFilter == 'all', onTap: () => onStatusChanged('all')),
                _FilterChip(label: 'In stock', selected: statusFilter == 'in_stock', onTap: () => onStatusChanged('in_stock'), color: const Color(0xFF22C55E)),
                _FilterChip(label: 'Low stock', selected: statusFilter == 'low_stock', onTap: () => onStatusChanged('low_stock'), color: Colors.orange),
                _FilterChip(label: 'Out of stock', selected: statusFilter == 'out_of_stock', onTap: () => onStatusChanged('out_of_stock'), color: Colors.red),
                if (categories.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(width: 1, height: 20, color: cs.outlineVariant.withValues(alpha: 0.3)),
                  const SizedBox(width: 8),
                  _CategoryDropdown(categories: categories, value: categoryFilter, onChanged: onCategoryChanged, cs: cs),
                ],
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text('${filtered.length} items', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(icon: Icons.inventory_2, title: 'No items match')
                : RefreshIndicator(
                    onRefresh: onRefresh,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _StockCard(item: filtered[i], cs: cs, onDelete: onDelete),
                    ),
                  ),
          ),
        ]);
      },
    );
  }
}

class _StockCard extends StatelessWidget {
  final Map item;
  final ColorScheme cs;
  final Future<void> Function(int id) onDelete;
  const _StockCard({required this.item, required this.cs, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final qty = _dbl(item['total_quantity'] ?? item['quantity']);
    final low = item['is_low_stock'] == true;
    final out = qty <= 0;
    final statusColor = out ? Colors.red : (low ? Colors.orange : const Color(0xFF22C55E));
    final statusLabel = out ? 'Out' : (low ? 'Low' : 'In stock');
    final reorder = _dbl(item['reorder_level']);

    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15))),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go('/inventory/${item['id']}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.medication_rounded, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['medication_name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(children: [
                Text(item['category_name'] ?? 'Uncategorized', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                if (item['unit_abbreviation'] != null) Text(' · ${item['unit_abbreviation']}', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(6)),
                  child: Text(statusLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor)),
                ),
                if (reorder > 0) ...[const SizedBox(width: 6), Text('RL: ${reorder.toInt()}', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant))],
              ]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
              Text('${qty.toInt()}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: statusColor)),
              Text(_fmt.format(_dbl(item['selling_price'])), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ]),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, size: 18, color: cs.onSurfaceVariant),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'view', child: Row(children: [Icon(Icons.visibility_rounded, size: 16), SizedBox(width: 8), Text('View', style: TextStyle(fontSize: 13))])),
                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 16), SizedBox(width: 8), Text('Edit', style: TextStyle(fontSize: 13))])),
                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 16, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(fontSize: 13, color: Colors.red))])),
              ],
              onSelected: (v) {
                if (v == 'view') context.go('/inventory/${item['id']}');
                if (v == 'edit') context.push('/inventory/${item['id']}/edit');
                if (v == 'delete') onDelete(item['id'] as int);
              },
            ),
          ]),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap; final Color? color;
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? c.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? c.withValues(alpha: 0.4) : cs.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? c : cs.onSurfaceVariant)),
        ),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final List categories; final String? value; final ValueChanged<String?> onChanged; final ColorScheme cs;
  const _CategoryDropdown({required this.categories, required this.value, required this.onChanged, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32, padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value, hint: Text('Category', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          isDense: true, icon: const Icon(Icons.expand_more_rounded, size: 16),
          style: TextStyle(fontSize: 11, color: cs.onSurface),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text('All categories', style: TextStyle(fontSize: 11, color: cs.onSurface))),
            ...categories.map((c) => DropdownMenuItem(value: '${c['id']}', child: Text(c['name'] ?? '', style: const TextStyle(fontSize: 11)))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// TAB 1: Categories
// ══════════════════════════════════════════
class _CategoriesTab extends StatefulWidget {
  final AsyncValue<List> categoriesAsync; final AsyncValue<List> stocksAsync;
  final Future<void> Function() onRefresh; final Future<void> Function(int id) onDelete;
  final Future<void> Function() onAdd;
  const _CategoriesTab({required this.categoriesAsync, required this.stocksAsync, required this.onRefresh, required this.onDelete, required this.onAdd});
  @override
  State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<_CategoriesTab> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return widget.categoriesAsync.when(
      loading: () => const LoadingShimmer(),
      error: (e, _) => ErrorRetry(message: 'Failed to load categories', onRetry: widget.onRefresh),
      data: (categories) {
        final stocks = widget.stocksAsync.valueOrNull ?? [];
        final enriched = categories.map((c) {
          final catId = c['id'];
          final catStocks = stocks.where((s) => s['category'] == catId).toList();
          final totalQty = catStocks.fold<double>(0, (sum, s) => sum + _dbl(s['total_quantity'] ?? s['quantity']));
          final totalValue = catStocks.fold<double>(0, (sum, s) => sum + _dbl(s['selling_price']) * _dbl(s['total_quantity'] ?? s['quantity']));
          return {...c, '_stockCount': catStocks.length, '_totalQty': totalQty, '_totalValue': totalValue};
        }).where((c) => _search.isEmpty || (c['name'] ?? '').toString().toLowerCase().contains(_search.toLowerCase())).toList()
          ..sort((a, b) => (b['_totalValue'] as double).compareTo(a['_totalValue'] as double));

        final totalValue = enriched.fold<double>(0, (s, c) => s + (c['_totalValue'] as double));

        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search categories...', hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 20), isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4))),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text('${enriched.length} categories', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('Total: ${_fmt.format(totalValue)}', style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              SizedBox(
                height: 28,
                child: FilledButton.icon(
                  onPressed: widget.onAdd,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add', style: TextStyle(fontSize: 11)),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), textStyle: const TextStyle(fontSize: 11)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: enriched.isEmpty
                ? const EmptyState(icon: Icons.category, title: 'No categories')
                : RefreshIndicator(
                    onRefresh: widget.onRefresh,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount: enriched.length,
                      itemBuilder: (_, i) {
                        final c = enriched[i];
                        final pct = totalValue > 0 ? (c['_totalValue'] as double) / totalValue : 0.0;
                        return Card(
                          elevation: 0, margin: const EdgeInsets.only(bottom: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15))),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Container(width: 36, height: 36, decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.category_rounded, size: 18, color: cs.primary)),
                                const SizedBox(width: 10),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(c['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                  Text('${c['_stockCount']} products · ${(c['_totalQty'] as double).toInt()} units', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                                ])),
                                Text(_fmt.format(c['_totalValue']), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cs.primary)),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert_rounded, size: 16, color: cs.onSurfaceVariant),
                                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                                  itemBuilder: (_) => [const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 16, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(fontSize: 13, color: Colors.red))]))],
                                  onSelected: (v) { if (v == 'delete') widget.onDelete(c['id'] as int); },
                                ),
                              ]),
                              const SizedBox(height: 8),
                              ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: pct, minHeight: 4, backgroundColor: cs.outlineVariant.withValues(alpha: 0.12), color: cs.primary.withValues(alpha: 0.7))),
                              const SizedBox(height: 2),
                              Text('${(pct * 100).toStringAsFixed(1)}% of inventory value', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ]);
      },
    );
  }
}

// ══════════════════════════════════════════
// TAB 2: Units
// ══════════════════════════════════════════
class _UnitsTab extends StatefulWidget {
  final AsyncValue<List> unitsAsync; final AsyncValue<List> stocksAsync;
  final Future<void> Function() onRefresh; final Future<void> Function(int id) onDelete;
  final Future<void> Function() onAdd;
  const _UnitsTab({required this.unitsAsync, required this.stocksAsync, required this.onRefresh, required this.onDelete, required this.onAdd});
  @override
  State<_UnitsTab> createState() => _UnitsTabState();
}

class _UnitsTabState extends State<_UnitsTab> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return widget.unitsAsync.when(
      loading: () => const LoadingShimmer(),
      error: (e, _) => ErrorRetry(message: 'Failed to load units', onRetry: widget.onRefresh),
      data: (units) {
        final stocks = widget.stocksAsync.valueOrNull ?? [];
        final enriched = units.map((u) {
          final unitStocks = stocks.where((s) => s['unit'] == u['id']).toList();
          return {...u, '_usageCount': unitStocks.length};
        }).where((u) {
          if (_search.isEmpty) return true;
          final q = _search.toLowerCase();
          return (u['name'] ?? '').toString().toLowerCase().contains(q) || (u['abbreviation'] ?? '').toString().toLowerCase().contains(q);
        }).toList()..sort((a, b) => (b['_usageCount'] as int).compareTo(a['_usageCount'] as int));

        final maxUsage = enriched.isNotEmpty ? enriched.fold<int>(0, (m, u) => (u['_usageCount'] as int) > m ? (u['_usageCount'] as int) : m) : 1;

        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search units...', hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 20), isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4))),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text('${enriched.length} units', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
              const Spacer(),
              SizedBox(
                height: 28,
                child: FilledButton.icon(
                  onPressed: widget.onAdd,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add', style: TextStyle(fontSize: 11)),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), textStyle: const TextStyle(fontSize: 11)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: enriched.isEmpty
                ? const EmptyState(icon: Icons.straighten, title: 'No units')
                : RefreshIndicator(
                    onRefresh: widget.onRefresh,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount: enriched.length,
                      itemBuilder: (_, i) {
                        final u = enriched[i];
                        final usage = (u['_usageCount'] as int);
                        final pct = maxUsage > 0 ? usage / maxUsage : 0.0;
                        return Card(
                          elevation: 0, margin: const EdgeInsets.only(bottom: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15))),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
                                child: Center(child: Text(u['abbreviation'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF8B5CF6)))),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(u['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Row(children: [
                                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: pct, minHeight: 4, backgroundColor: cs.outlineVariant.withValues(alpha: 0.12), color: const Color(0xFF8B5CF6).withValues(alpha: 0.6)))),
                                  const SizedBox(width: 8),
                                  Text('$usage products', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                                ]),
                              ])),
                              PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert_rounded, size: 16, color: cs.onSurfaceVariant),
                                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                                itemBuilder: (_) => [const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 16, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(fontSize: 13, color: Colors.red))]))],
                                onSelected: (v) { if (v == 'delete') widget.onDelete(u['id'] as int); },
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ]);
      },
    );
  }
}

// ══════════════════════════════════════════
// TAB 3: Adjustments
// ══════════════════════════════════════════
class _AdjustmentsTab extends StatefulWidget {
  final AsyncValue<List> adjustmentsAsync;
  final Future<void> Function() onRefresh;
  final VoidCallback onAdd;
  const _AdjustmentsTab({required this.adjustmentsAsync, required this.onRefresh, required this.onAdd});
  @override
  State<_AdjustmentsTab> createState() => _AdjustmentsTabState();
}

class _AdjustmentsTabState extends State<_AdjustmentsTab> {
  String _search = '';
  String _reasonFilter = 'all';

  static const _reasons = ['all', 'count_correction', 'damaged', 'expired', 'received', 'returned', 'theft', 'other'];
  static const _reasonLabels = <String, String>{
    'all': 'All', 'count_correction': 'Count', 'damaged': 'Damaged', 'expired': 'Expired',
    'received': 'Received', 'returned': 'Returned', 'theft': 'Theft', 'other': 'Other',
  };
  static const _reasonColors = <String, Color>{
    'count_correction': Color(0xFF3B82F6), 'damaged': Color(0xFFEF4444), 'expired': Color(0xFFF59E0B),
    'received': Color(0xFF22C55E), 'returned': Color(0xFF8B5CF6), 'theft': Color(0xFFDC2626), 'other': Color(0xFF64748B),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return widget.adjustmentsAsync.when(
      loading: () => const LoadingShimmer(),
      error: (e, _) => ErrorRetry(message: 'Failed to load adjustments', onRetry: widget.onRefresh),
      data: (adjustments) {
        final filtered = adjustments.where((a) {
          if (_search.isNotEmpty && !(a['stock_name'] ?? a['medication_name'] ?? '').toString().toLowerCase().contains(_search.toLowerCase())) return false;
          if (_reasonFilter != 'all' && a['reason'] != _reasonFilter) return false;
          return true;
        }).toList();

        final Map<String, int> reasonCounts = {};
        for (final a in adjustments) { final r = (a['reason'] ?? 'other').toString(); reasonCounts[r] = (reasonCounts[r] ?? 0) + 1; }

        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search adjustments...', hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 20), isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4))),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(children: [
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: ListView(scrollDirection: Axis.horizontal, children: _reasons.map((r) {
                    final count = r == 'all' ? adjustments.length : (reasonCounts[r] ?? 0);
                    return _FilterChip(label: '${_reasonLabels[r]} ($count)', selected: _reasonFilter == r, onTap: () => setState(() => _reasonFilter = r), color: _reasonColors[r]);
                  }).toList()),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 28,
                child: FilledButton.icon(
                  onPressed: widget.onAdd,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('New', style: TextStyle(fontSize: 11)),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), textStyle: const TextStyle(fontSize: 11)),
                ),
              ),
            ]),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(icon: Icons.tune, title: 'No adjustments')
                : RefreshIndicator(
                    onRefresh: widget.onRefresh,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final a = filtered[i];
                        final qtyChange = _dbl(a['quantity_change']);
                        final isAdd = qtyChange >= 0;
                        final reason = (a['reason'] ?? 'other').toString();
                        final reasonColor = _reasonColors[reason] ?? const Color(0xFF64748B);
                        final date = DateTime.tryParse((a['created_at'] ?? '').toString());
                        final fmtDate = date != null ? DateFormat('MMM d, yyyy · HH:mm').format(date) : '';

                        return Card(
                          elevation: 0, margin: const EdgeInsets.only(bottom: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15))),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(color: (isAdd ? const Color(0xFF22C55E) : Colors.red).withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
                                child: Icon(isAdd ? Icons.add_rounded : Icons.remove_rounded, size: 18, color: isAdd ? const Color(0xFF22C55E) : Colors.red),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(a['stock_name'] ?? a['medication_name'] ?? 'Unknown', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Row(children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(color: reasonColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                                    child: Text(_reasonLabels[reason] ?? reason, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: reasonColor)),
                                  ),
                                  if (a['adjusted_by_name'] != null) ...[const SizedBox(width: 6), Text(a['adjusted_by_name'].toString(), style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant))],
                                ]),
                                if (fmtDate.isNotEmpty) ...[const SizedBox(height: 2), Text(fmtDate, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant))],
                              ])),
                              Text('${isAdd ? '+' : ''}${qtyChange.toInt()}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isAdd ? const Color(0xFF22C55E) : Colors.red)),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ]);
      },
    );
  }
}

// ══════════════════════════════════════════
// TAB 4: Analysis
// ══════════════════════════════════════════
class _AnalysisTab extends StatelessWidget {
  final AsyncValue<List> stocksAsync;
  final VoidCallback onRefresh;
  const _AnalysisTab({required this.stocksAsync, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return stocksAsync.when(
      loading: () => const LoadingShimmer(),
      error: (e, _) => ErrorRetry(message: 'Failed to load', onRetry: onRefresh),
      data: (stocks) {
        final now = DateTime.now();
        final totalCost = stocks.fold<double>(0, (s, x) => s + _dbl(x['cost_price']) * _dbl(x['total_quantity'] ?? x['quantity']));
        final totalRetail = stocks.fold<double>(0, (s, x) => s + _dbl(x['selling_price']) * _dbl(x['total_quantity'] ?? x['quantity']));
        final totalUnits = stocks.fold<int>(0, (s, x) => s + _dbl(x['total_quantity'] ?? x['quantity']).toInt());
        final profitMargin = totalCost > 0 ? ((totalRetail - totalCost) / totalCost * 100) : 0.0;

        final inStock = stocks.where((s) => _dbl(s['total_quantity'] ?? s['quantity']) > 0 && s['is_low_stock'] != true).length;
        final lowStock = stocks.where((s) => s['is_low_stock'] == true && _dbl(s['total_quantity'] ?? s['quantity']) > 0).length;
        final outOfStock = stocks.where((s) => _dbl(s['total_quantity'] ?? s['quantity']) <= 0).length;
        final healthTotal = stocks.isNotEmpty ? stocks.length : 1;

        final expired = stocks.where((s) { final e = DateTime.tryParse((s['expiry_date'] ?? '').toString()); return e != null && e.isBefore(now); }).length;
        final exp30 = stocks.where((s) { final e = DateTime.tryParse((s['expiry_date'] ?? '').toString()); return e != null && !e.isBefore(now) && e.isBefore(now.add(const Duration(days: 30))); }).length;
        final exp60 = stocks.where((s) { final e = DateTime.tryParse((s['expiry_date'] ?? '').toString()); return e != null && !e.isBefore(now.add(const Duration(days: 30))) && e.isBefore(now.add(const Duration(days: 60))); }).length;
        final exp90 = stocks.where((s) { final e = DateTime.tryParse((s['expiry_date'] ?? '').toString()); return e != null && !e.isBefore(now.add(const Duration(days: 60))) && e.isBefore(now.add(const Duration(days: 90))); }).length;

        final Map<String, double> catValues = {};
        for (final s in stocks) { final cat = (s['category_name'] ?? 'Uncategorized').toString(); catValues[cat] = (catValues[cat] ?? 0) + _dbl(s['selling_price']) * _dbl(s['total_quantity'] ?? s['quantity']); }
        final catEntries = catValues.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final catMax = catEntries.isNotEmpty ? catEntries[0].value : 1.0;

        final reorderItems = stocks.where((s) { final q = _dbl(s['total_quantity'] ?? s['quantity']); final rl = _dbl(s['reorder_level']); return rl > 0 && q <= rl; }).toList()
          ..sort((a, b) { final ar = _dbl(a['reorder_level']) > 0 ? _dbl(a['total_quantity'] ?? a['quantity']) / _dbl(a['reorder_level']) : 1.0; final br = _dbl(b['reorder_level']) > 0 ? _dbl(b['total_quantity'] ?? b['quantity']) / _dbl(b['reorder_level']) : 1.0; return ar.compareTo(br); });

        final topByValue = List.from(stocks)..sort((a, b) { final av = _dbl(a['selling_price']) * _dbl(a['total_quantity'] ?? a['quantity']); final bv = _dbl(b['selling_price']) * _dbl(b['total_quantity'] ?? b['quantity']); return bv.compareTo(av); });

        final soon90 = now.add(const Duration(days: 90));
        final expiringItems = stocks.where((s) { final e = DateTime.tryParse((s['expiry_date'] ?? '').toString()); return e != null && e.isBefore(soon90); }).toList()
          ..sort((a, b) { final ea = DateTime.tryParse((a['expiry_date'] ?? '').toString()) ?? now; final eb = DateTime.tryParse((b['expiry_date'] ?? '').toString()) ?? now; return ea.compareTo(eb); });

        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            children: [
              const _SectionLabel('Inventory Valuation'),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _ValuationCard('Cost Value', _fmt.format(totalCost), Icons.money_rounded, const Color(0xFF3B82F6), cs)),
                const SizedBox(width: 8),
                Expanded(child: _ValuationCard('Retail Value', _fmt.format(totalRetail), Icons.sell_rounded, const Color(0xFF22C55E), cs)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _ValuationCard('Total Units', _fmtFull.format(totalUnits), Icons.widgets_rounded, const Color(0xFF8B5CF6), cs)),
                const SizedBox(width: 8),
                Expanded(child: _ValuationCard('Margin', '${profitMargin.toStringAsFixed(1)}%', Icons.trending_up_rounded, const Color(0xFFF59E0B), cs)),
              ]),
              const SizedBox(height: 20),

              const _SectionLabel('Stock Health'),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(height: 16, child: Row(children: [
                        Expanded(flex: (inStock * 100 ~/ healthTotal).clamp(1, 100), child: Container(color: const Color(0xFF22C55E))),
                        if (lowStock > 0) Expanded(flex: (lowStock * 100 ~/ healthTotal).clamp(1, 100), child: Container(color: const Color(0xFFF59E0B))),
                        if (outOfStock > 0) Expanded(flex: (outOfStock * 100 ~/ healthTotal).clamp(1, 100), child: Container(color: const Color(0xFFEF4444))),
                      ])),
                    ),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                      _HealthLegend('In stock', inStock, const Color(0xFF22C55E), cs),
                      _HealthLegend('Low stock', lowStock, const Color(0xFFF59E0B), cs),
                      _HealthLegend('Out', outOfStock, const Color(0xFFEF4444), cs),
                    ]),
                  ]),
                ),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 20),

              const _SectionLabel('Expiry Risk Timeline'),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _ExpiryBucket('Expired', expired, Colors.red, cs),
                    _ExpiryBucket('30 days', exp30, Colors.orange, cs),
                    _ExpiryBucket('60 days', exp60, const Color(0xFFF59E0B), cs),
                    _ExpiryBucket('90 days', exp90, const Color(0xFF3B82F6), cs),
                  ]),
                ),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 20),

              const _SectionLabel('Value by Category'),
              const SizedBox(height: 8),
              ...catEntries.take(8).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  SizedBox(width: 90, child: Text(e.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: catMax > 0 ? e.value / catMax : 0, minHeight: 14, backgroundColor: cs.outlineVariant.withValues(alpha: 0.08), color: cs.primary.withValues(alpha: 0.6)))),
                  const SizedBox(width: 8),
                  SizedBox(width: 70, child: Text(_fmt.format(e.value), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                ]),
              )),
              const SizedBox(height: 20),

              const _SectionLabel('Reorder Priority'),
              const SizedBox(height: 4),
              Text('Items at or below reorder level', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              const SizedBox(height: 8),
              if (reorderItems.isEmpty)
                _emptyMini('All items above reorder levels', cs)
              else
                ...reorderItems.take(10).map((s) {
                  final q = _dbl(s['total_quantity'] ?? s['quantity']);
                  final rl = _dbl(s['reorder_level']);
                  final ratio = rl > 0 ? q / rl : 1.0;
                  final urgencyColor = ratio <= 0 ? Colors.red : (ratio <= 0.5 ? Colors.orange : const Color(0xFFF59E0B));
                  return Card(
                    elevation: 0, margin: const EdgeInsets.only(bottom: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.12))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: urgencyColor, shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s['medication_name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('Stock: ${q.toInt()} / RL: ${rl.toInt()}', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                        ])),
                        Text('Need ${(rl - q).toInt().clamp(0, 999999)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: urgencyColor)),
                      ]),
                    ),
                  );
                }),
              const SizedBox(height: 20),

              const _SectionLabel('Top Items by Value'),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Row(children: [
                      const Expanded(flex: 4, child: Text('Product', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                      const Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                      const Expanded(flex: 2, child: Text('Value', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                    ]),
                    const Divider(height: 14),
                    ...topByValue.take(10).map((s) {
                      final q = _dbl(s['total_quantity'] ?? s['quantity']);
                      final v = _dbl(s['selling_price']) * q;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          Expanded(flex: 4, child: Text(s['medication_name'] ?? '', style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Expanded(flex: 1, child: Text('${q.toInt()}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), textAlign: TextAlign.right)),
                          Expanded(flex: 2, child: Text(_fmt.format(v), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                        ]),
                      );
                    }),
                  ]),
                ),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 20),

              const _SectionLabel('Expiring ≤ 90 days'),
              const SizedBox(height: 8),
              if (expiringItems.isEmpty)
                _emptyMini('No items expiring within 90 days', cs)
              else
                ...expiringItems.take(10).map((s) {
                  final exp = DateTime.tryParse((s['expiry_date'] ?? '').toString());
                  final daysLeft = exp != null ? exp.difference(now).inDays : 0;
                  final isExpired = daysLeft < 0;
                  final expColor = isExpired ? Colors.red : (daysLeft <= 30 ? Colors.orange : const Color(0xFFF59E0B));
                  return Card(
                    elevation: 0, margin: const EdgeInsets.only(bottom: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.12))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s['medication_name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('Qty: ${_dbl(s['total_quantity'] ?? s['quantity']).toInt()} · ${exp != null ? DateFormat('MMM d, yyyy').format(exp) : ''}', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                        ])),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: expColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                          child: Text(isExpired ? 'Expired' : '${daysLeft}d', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: expColor)),
                        ),
                      ]),
                    ),
                  );
                }),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyMini(String msg, ColorScheme cs) => Card(
    elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(msg, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)))),
  );
}

// ── Shared widgets ──
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface));
}

class _ValuationCard extends StatelessWidget {
  final String label; final String value; final IconData icon; final Color color; final ColorScheme cs;
  const _ValuationCard(this.label, this.value, this.icon, this.color, this.cs);
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0, color: color.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: color.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: color)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: cs.onSurface)),
          ])),
        ]),
      ),
    );
  }
}

class _HealthLegend extends StatelessWidget {
  final String label; final int count; final Color color; final ColorScheme cs;
  const _HealthLegend(this.label, this.count, this.color, this.cs);
  @override
  Widget build(BuildContext context) => Column(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(height: 4),
    Text('$count', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface)),
    Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
  ]);
}

class _ExpiryBucket extends StatelessWidget {
  final String label; final int count; final Color color; final ColorScheme cs;
  const _ExpiryBucket(this.label, this.count, this.color, this.cs);
  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      width: 42, height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: count > 0 ? 0.14 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: count > 0 ? 0.3 : 0.1)),
      ),
      child: Center(child: Text('$count', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: count > 0 ? color : cs.onSurfaceVariant))),
    ),
    const SizedBox(height: 4),
    Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
  ]);
}
