import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api.dart';

double _dbl(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
final _moneyFmt = NumberFormat.compactCurrency(symbol: 'KSH ', decimalDigits: 0);
final _moneyFull = NumberFormat('#,##0.00', 'en');

final _suppliersProvider = FutureProvider.autoDispose<List>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/suppliers/', queryParameters: {'page_size': 500});
  return (res.data['results'] as List?) ?? [];
});

final _stocksProvider = FutureProvider.autoDispose<List>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/inventory/stocks/', queryParameters: {'page_size': 1000});
  return (res.data['results'] as List?) ?? [];
});

class NewPurchaseOrderScreen extends ConsumerStatefulWidget {
  const NewPurchaseOrderScreen({super.key});
  @override
  ConsumerState<NewPurchaseOrderScreen> createState() => _NewPurchaseOrderScreenState();
}

class _NewPurchaseOrderScreenState extends ConsumerState<NewPurchaseOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  int? _supplierId;
  String? _supplierName;
  DateTime? _expectedDelivery;
  String _status = 'draft';
  final _notesCtrl = TextEditingController();
  final List<_POItem> _items = [];
  bool _loading = false;

  static const _statusOptions = <String, String>{
    'draft': 'Draft', 'sent': 'Sent', 'received': 'Received',
    'partial': 'Partially Received', 'cancelled': 'Cancelled',
  };

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (final it in _items) {
      it.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() => _items.add(_POItem()));
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  double get _totalCost => _items.fold(0.0, (s, it) => s + it.lineTotalWithTax);
  double get _subtotal => _items.fold(0.0, (s, it) => s + it.lineTotal);
  double get _totalTax => _items.fold(0.0, (s, it) => s + it.lineTax);
  int get _totalQty => _items.fold(0, (s, it) => s + (int.tryParse(it.qtyCtrl.text) ?? 0));
  double get _avgUnitCost => _totalQty > 0 ? _subtotal / _totalQty : 0;
  double get _projectedRevenue => _items.fold(0.0, (s, it) => s + it.lineRevenue);
  double get _projectedProfit => _projectedRevenue - _totalCost;
  double get _profitMarginPct => _projectedRevenue > 0 ? (_projectedProfit / _projectedRevenue) * 100 : 0;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_supplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a supplier')));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one item')));
      return;
    }

    setState(() => _loading = true);

    final itemsData = _items.map((it) => {
      'medication_stock_id': it.stockId,
      'name': it.name,
      'qty': int.tryParse(it.qtyCtrl.text) ?? 0,
      'unit_cost': _dbl(it.unitCostCtrl.text),
      'unit_selling_price': _dbl(it.sellingPriceCtrl.text),
      'discount_percent': _dbl(it.discountCtrl.text),
      'tax_percent': _dbl(it.taxCtrl.text),
      'batch_number': it.batchCtrl.text.trim(),
      'expiry_date': it.expiryDate != null ? DateFormat('yyyy-MM-dd').format(it.expiryDate!) : null,
    }).toList();

    try {
      await ref.read(dioProvider).post('/purchase-orders/orders/', data: {
        'supplier': _supplierId,
        'status': _status,
        'expected_delivery': _expectedDelivery != null ? DateFormat('yyyy-MM-dd').format(_expectedDelivery!) : null,
        'notes': _notesCtrl.text.trim(),
        'items': itemsData,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase order created')));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final suppliersAsync = ref.watch(_suppliersProvider);
    final stocksAsync = ref.watch(_stocksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('New Purchase Order')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Order Details Card ──
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.description_rounded, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    const Text('Order Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 16),

                  // Supplier
                  suppliersAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Failed to load suppliers'),
                    data: (suppliers) => Autocomplete<Map<String, dynamic>>(
                      displayStringForOption: (s) => s['name'] ?? '',
                      optionsBuilder: (text) {
                        if (text.text.isEmpty) return suppliers.cast<Map<String, dynamic>>();
                        final q = text.text.toLowerCase();
                        return suppliers.cast<Map<String, dynamic>>().where((s) => (s['name'] ?? '').toString().toLowerCase().contains(q));
                      },
                      onSelected: (s) => setState(() { _supplierId = s['id'] as int; _supplierName = s['name'] as String; }),
                      fieldViewBuilder: (ctx, ctrl, focus, onSubmit) => TextFormField(
                        controller: ctrl,
                        focusNode: focus,
                        decoration: InputDecoration(
                          labelText: 'Supplier *',
                          hintText: 'Search suppliers...',
                          prefixIcon: const Icon(Icons.local_shipping_rounded, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (_) => _supplierId == null ? 'Select a supplier' : null,
                      ),
                      optionsViewBuilder: (ctx, onSelected, options) {
                        final width = MediaQuery.of(ctx).size.width - 72;
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4, borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxHeight: 200, maxWidth: width),
                              child: ListView.builder(
                                padding: EdgeInsets.zero, shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (_, i) {
                                final s = options.elementAt(i);
                                return ListTile(dense: true, title: Text(s['name'] ?? ''), onTap: () => onSelected(s));
                              },
                            ),
                          ),
                        ),
                      );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Expected Delivery + Status
                  Row(children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365 * 2)), initialDate: _expectedDelivery ?? DateTime.now().add(const Duration(days: 7)));
                          if (d != null) setState(() => _expectedDelivery = d);
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Expected Delivery',
                            prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(_expectedDelivery != null ? DateFormat('MMM d, yyyy').format(_expectedDelivery!) : 'Select date', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: _expectedDelivery != null ? cs.onSurface : cs.onSurfaceVariant)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _status,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          prefixIcon: const Icon(Icons.flag_rounded, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: _statusOptions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (v) { if (v != null) setState(() => _status = v); },
                      ),
                    ),
                  ]),

                  if (_status == 'received') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        const Icon(Icons.info_rounded, size: 16, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Saving with Received status will create stock batches and update quantities.', style: TextStyle(fontSize: 11, color: cs.onSurface))),
                      ]),
                    ),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 12),

            // ── Items Card ──
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.inventory_2_rounded, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    const Text('Items', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    if (_items.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(6)),
                        child: Text('${_items.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary)),
                      ),
                    ],
                    const Spacer(),
                    SizedBox(
                      height: 32,
                      child: FilledButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add Item', style: TextStyle(fontSize: 11)),
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  if (_items.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(children: [
                          Icon(Icons.shopping_cart_outlined, size: 36, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                          const SizedBox(height: 8),
                          Text('No items yet', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        ]),
                      ),
                    )
                  else
                    ...List.generate(_items.length, (i) => _ItemRow(
                      index: i,
                      item: _items[i],
                      stocks: stocksAsync.valueOrNull ?? [],
                      cs: cs,
                      onRemove: () => _removeItem(i),
                      onChanged: () => setState(() {}),
                    )),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            // ── Notes ──
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Optional notes...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Summary ──
            if (_items.isNotEmpty)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.receipt_long_rounded, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text('Order Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(children: [
                      // Row 1: Items, Qty, Subtotal, VAT
                      Row(children: [
                        Expanded(child: _SummaryCell('Items', '${_items.length}')),
                        Expanded(child: _SummaryCell('Total Qty', '$_totalQty')),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: _SummaryCell('Subtotal (excl. VAT)', 'KSH ${_moneyFull.format(_subtotal)}')),
                        Expanded(child: _SummaryCell('VAT Tax', 'KSH ${_moneyFull.format(_totalTax)}', valueColor: const Color(0xFFF59E0B))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: _SummaryCell('Avg. Unit Cost', 'KSH ${_moneyFull.format(_avgUnitCost)}')),
                        Expanded(child: _SummaryCellHighlight('Total Cost', 'KSH ${_moneyFull.format(_totalCost)}', cs.primary)),
                      ]),
                      const Divider(height: 20),
                      Row(children: [
                        Expanded(child: _SummaryCell('Projected Revenue', 'KSH ${_moneyFull.format(_projectedRevenue)}')),
                        Expanded(child: _SummaryCell('Projected Profit', 'KSH ${_moneyFull.format(_projectedProfit)}', valueColor: _projectedProfit >= 0 ? const Color(0xFF22C55E) : Colors.red)),
                      ]),
                      const SizedBox(height: 8),
                      _SummaryCell('Profit Margin', '${_profitMarginPct.toStringAsFixed(1)}%', valueColor: _profitMarginPct >= 0 ? const Color(0xFF22C55E) : Colors.red),
                    ]),
                  ),
                ]),
              ),
            const SizedBox(height: 20),

            // ── Submit ──
            SizedBox(
              width: double.infinity, height: 48,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Create Purchase Order', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// PO Item model
// ══════════════════════════════════════════
class _POItem {
  int? stockId;
  String name = '';
  final qtyCtrl = TextEditingController(text: '1');
  final unitCostCtrl = TextEditingController(text: '0');
  final sellingPriceCtrl = TextEditingController(text: '0');
  final discountCtrl = TextEditingController(text: '0');
  final taxCtrl = TextEditingController(text: '0');
  final batchCtrl = TextEditingController();
  DateTime? expiryDate;

  // Previous values from existing stock (for comparison)
  double? prevCost;
  double? prevSellPrice;
  int? currentStock;

  double get lineTotal {
    final qty = int.tryParse(qtyCtrl.text) ?? 0;
    final cost = _dbl(unitCostCtrl.text);
    return qty * cost;
  }

  double get lineTax {
    final pct = _dbl(taxCtrl.text);
    return pct > 0 ? lineTotal * pct / 100 : 0;
  }

  double get lineTotalWithTax => lineTotal + lineTax;

  double get effectiveSelling {
    final sell = _dbl(sellingPriceCtrl.text);
    final disc = _dbl(discountCtrl.text);
    return sell * (1 - disc / 100);
  }

  double get lineRevenue {
    final qty = int.tryParse(qtyCtrl.text) ?? 0;
    return qty * effectiveSelling;
  }

  double get lineProfit => lineRevenue - lineTotal;

  double get marginPct {
    final sell = effectiveSelling;
    if (sell <= 0) return 0;
    return ((sell - _dbl(unitCostCtrl.text)) / sell) * 100;
  }

  void dispose() {
    qtyCtrl.dispose();
    unitCostCtrl.dispose();
    sellingPriceCtrl.dispose();
    discountCtrl.dispose();
    taxCtrl.dispose();
    batchCtrl.dispose();
  }
}

// ══════════════════════════════════════════
// Item Row Widget
// ══════════════════════════════════════════
class _ItemRow extends StatelessWidget {
  final int index;
  final _POItem item;
  final List stocks;
  final ColorScheme cs;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _ItemRow({
    required this.index, required this.item, required this.stocks,
    required this.cs, required this.onRemove, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final margin = item.marginPct;
    final marginColor = margin >= 30 ? const Color(0xFF22C55E) : margin >= 15 ? const Color(0xFF3B82F6) : margin >= 0 ? const Color(0xFFF59E0B) : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Center(child: Text('${index + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary))),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(item.name.isNotEmpty ? item.name : 'Item ${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (item.lineTotal > 0) Text(_moneyFmt.format(item.lineTotalWithTax), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cs.primary)),
          const SizedBox(width: 4),
          InkWell(onTap: onRemove, borderRadius: BorderRadius.circular(6), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close_rounded, size: 16, color: Colors.red))),
        ]),
        const SizedBox(height: 10),

        // Stock autocomplete
        Autocomplete<Map<String, dynamic>>(
          displayStringForOption: (s) => s['medication_name'] ?? '',
          optionsBuilder: (text) {
            if (text.text.isEmpty) return stocks.cast<Map<String, dynamic>>();
            final q = text.text.toLowerCase();
            return stocks.cast<Map<String, dynamic>>().where((s) => (s['medication_name'] ?? '').toString().toLowerCase().contains(q));
          },
          onSelected: (s) {
            item.stockId = s['id'] as int;
            item.name = s['medication_name'] ?? '';
            item.unitCostCtrl.text = '${s['cost_price'] ?? 0}';
            item.sellingPriceCtrl.text = '${s['selling_price'] ?? 0}';
            item.taxCtrl.text = '${s['tax_percent'] ?? 0}';
            item.discountCtrl.text = '${s['discount_percent'] ?? 0}';
            item.prevCost = _dbl(s['cost_price']);
            item.prevSellPrice = _dbl(s['selling_price']);
            item.currentStock = (_dbl(s['total_quantity'] ?? s['quantity'])).toInt();
            onChanged();
          },
          fieldViewBuilder: (ctx, ctrl, focus, onSubmit) => TextField(
            controller: ctrl, focusNode: focus,
            decoration: InputDecoration(
              hintText: 'Search stock items...',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            style: const TextStyle(fontSize: 12),
          ),
          optionsViewBuilder: (ctx, onSelected, options) {
            final width = MediaQuery.of(ctx).size.width - 80;
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4, borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 250, maxWidth: width),
                  child: ListView.builder(
                    padding: EdgeInsets.zero, shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (_, i) {
                      final s = options.elementAt(i);
                      final stockQty = s['total_quantity'] ?? s['quantity'] ?? 0;
                      final isOut = _dbl(stockQty) <= 0;
                      return ListTile(
                        dense: true,
                        title: Text(s['medication_name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Wrap(spacing: 4, runSpacing: 2, children: [
                          _MiniChip('Cost ${s['cost_price']}', cs.primary),
                          _MiniChip('Sell ${s['selling_price']}', const Color(0xFF22C55E)),
                          if (_dbl(s['tax_percent']) > 0) _MiniChip('VAT ${s['tax_percent']}%', const Color(0xFFF59E0B)),
                          if (_dbl(s['discount_percent']) > 0) _MiniChip('${s['discount_percent']}% off', const Color(0xFF8B5CF6)),
                          _MiniChip('Stock $stockQty', isOut ? Colors.red : const Color(0xFF64748B)),
                        ]),
                        onTap: () => onSelected(s),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),

        // Previous prices & stock info chips
        if (item.stockId != null) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: [
            if (item.prevCost != null) _InfoChip(Icons.history_rounded, 'Prev Cost: ${_moneyFmt.format(item.prevCost!)}', cs.primary),
            if (item.prevSellPrice != null) _InfoChip(Icons.sell_rounded, 'Prev Sell: ${_moneyFmt.format(item.prevSellPrice!)}', const Color(0xFF22C55E)),
            if (item.currentStock != null) _InfoChip(Icons.inventory_rounded, 'In stock: ${item.currentStock}', const Color(0xFF3B82F6)),
            _InfoChip(Icons.add_circle_outline_rounded, '+${int.tryParse(item.qtyCtrl.text) ?? 0} after save', const Color(0xFF22C55E)),
          ]),
        ],
        const SizedBox(height: 8),

        // Qty + Unit Cost row
        Row(children: [
          Expanded(child: _SmallField(ctrl: item.qtyCtrl, label: 'Qty', type: TextInputType.number, onChanged: onChanged)),
          const SizedBox(width: 8),
          Expanded(child: _SmallField(ctrl: item.unitCostCtrl, label: 'Unit Cost', type: TextInputType.number, onChanged: onChanged)),
          const SizedBox(width: 8),
          Expanded(child: _SmallField(ctrl: item.sellingPriceCtrl, label: 'Sell Price', type: TextInputType.number, onChanged: onChanged)),
        ]),
        const SizedBox(height: 8),

        // Discount + Tax + Batch
        Row(children: [
          Expanded(child: _SmallField(ctrl: item.discountCtrl, label: 'Disc %', type: TextInputType.number, onChanged: onChanged)),
          const SizedBox(width: 8),
          Expanded(child: _SmallField(ctrl: item.taxCtrl, label: 'VAT %', type: TextInputType.number, onChanged: onChanged)),
          const SizedBox(width: 8),
          Expanded(child: _SmallField(ctrl: item.batchCtrl, label: 'Batch #', onChanged: onChanged)),
        ]),
        const SizedBox(height: 8),

        // Expiry date
        InkWell(
          onTap: () async {
            final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365 * 10)), initialDate: item.expiryDate ?? DateTime.now().add(const Duration(days: 365)));
            if (d != null) { item.expiryDate = d; onChanged(); }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Expiry Date',
              prefixIcon: const Icon(Icons.event_rounded, size: 16),
              isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              item.expiryDate != null ? DateFormat('MMM d, yyyy').format(item.expiryDate!) : 'Select',
              style: TextStyle(fontSize: 12, color: item.expiryDate != null ? cs.onSurface : cs.onSurfaceVariant),
            ),
          ),
        ),

        // Margin / Profit / VAT / Line total chips
        if (item.lineTotal > 0) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, alignment: WrapAlignment.end, children: [
            _MetricChip(Icons.trending_up_rounded, 'Margin ${margin.toStringAsFixed(1)}%', marginColor),
            _MetricChip(Icons.attach_money_rounded, 'Profit ${_moneyFmt.format(item.lineProfit)}', item.lineProfit >= 0 ? const Color(0xFF22C55E) : Colors.red),
            if (item.lineTax > 0) _MetricChip(Icons.percent_rounded, 'VAT ${_moneyFmt.format(item.lineTax)}', const Color(0xFFF59E0B)),
          ]),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Line total', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
              Text('KSH ${_moneyFull.format(item.lineTotalWithTax)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: cs.primary)),
              if (item.lineTax > 0) Text('incl. ${_moneyFmt.format(item.lineTax)} VAT', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _SmallField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final TextInputType? type;
  final VoidCallback onChanged;
  const _SmallField({required this.ctrl, required this.label, this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      style: const TextStyle(fontSize: 12),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String text; final Color color;
  const _MiniChip(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon; final String text; final Color color;
  const _InfoChip(this.icon, this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon; final String text; final Color color;
  const _MetricChip(this.icon, this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  final String label; final String value; final Color? valueColor;
  const _SummaryCell(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: valueColor ?? cs.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class _SummaryCellHighlight extends StatelessWidget {
  final String label; final String value; final Color color;
  const _SummaryCellHighlight(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 9, color: color)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}
