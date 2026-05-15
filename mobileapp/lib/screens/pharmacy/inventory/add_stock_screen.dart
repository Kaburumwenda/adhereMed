import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api.dart';
import 'barcode_scanner_dialog.dart';

// ── data providers ──
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

double _dbl(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;

String _generateSku() {
  final r = Random();
  return 'SKU-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}-${r.nextInt(900) + 100}';
}

String _generateBatch() {
  final now = DateTime.now();
  final r = Random();
  return 'B${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${r.nextInt(9000) + 1000}';
}

class AddStockScreen extends ConsumerStatefulWidget {
  const AddStockScreen({super.key});
  @override
  ConsumerState<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends ConsumerState<AddStockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _qty = TextEditingController(text: '0');
  final _reorderLevel = TextEditingController(text: '0');
  final _reorderQty = TextEditingController(text: '0');
  final _costPrice = TextEditingController();
  final _taxPercent = TextEditingController(text: '0');
  final _sellingPrice = TextEditingController();
  final _discountPercent = TextEditingController(text: '0');
  final _batch = TextEditingController();
  final _barcode = TextEditingController();
  final _description = TextEditingController();
  DateTime? _expiryDate;
  int? _categoryId;
  int? _unitId;
  bool _isActive = true;
  bool _loading = false;
  bool _reorderAutoCalc = true;

  // Catalog search
  List<Map<String, dynamic>> _catalogResults = [];
  bool _catalogSearching = false;
  bool _catalogSearchDone = false;
  bool _catalogItemSelected = false;
  bool _duplicateFound = false;
  Map<String, dynamic>? _duplicateItem;

  @override
  void initState() {
    super.initState();
    _sku.text = _generateSku();
    _batch.text = _generateBatch();
    _expiryDate = DateTime.now().add(const Duration(days: 365 * 5));
    _qty.addListener(_onQtyChanged);
  }

  @override
  void dispose() {
    _qty.removeListener(_onQtyChanged);
    _name.dispose(); _sku.dispose(); _qty.dispose(); _reorderLevel.dispose();
    _reorderQty.dispose(); _costPrice.dispose(); _taxPercent.dispose();
    _sellingPrice.dispose(); _discountPercent.dispose(); _batch.dispose();
    _barcode.dispose(); _description.dispose();
    super.dispose();
  }

  void _onQtyChanged() {
    if (!_reorderAutoCalc) return;
    final q = int.tryParse(_qty.text) ?? 0;
    _reorderLevel.text = '${(q * 0.3).round()}';
    _reorderQty.text = '${(q * 0.5).round()}';
  }

  Future<void> _searchCatalog(String query) async {
    if (query.length < 2) { setState(() { _catalogResults = []; _catalogSearchDone = false; _catalogItemSelected = false; }); return; }
    setState(() { _catalogSearching = true; _catalogItemSelected = false; });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/medications/search/', queryParameters: {'q': query});
      final results = (res.data as List?)?.cast<Map<String, dynamic>>() ?? [];
      setState(() { _catalogResults = results; _catalogSearching = false; _catalogSearchDone = true; });
    } catch (_) {
      setState(() { _catalogSearching = false; _catalogSearchDone = true; });
    }
  }

  Future<void> _checkDuplicate(String name) async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/inventory/stocks/', queryParameters: {'search': name, 'page_size': 5});
      final results = (res.data['results'] as List?) ?? [];
      final dup = results.where((s) => (s['medication_name'] ?? '').toString().toLowerCase() == name.toLowerCase()).toList();
      setState(() { _duplicateFound = dup.isNotEmpty; _duplicateItem = dup.isNotEmpty ? Map.from(dup.first) : null; });
    } catch (_) {}
  }

  void _selectCatalogItem(Map<String, dynamic> item) {
    setState(() {
      _name.text = item['generic_name'] ?? '';
      _description.text = item['description'] ?? '';
      _catalogResults = [];
      _catalogItemSelected = true;
      _catalogSearchDone = false;
    });
    _checkDuplicate(_name.text);
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  // ── profit calculations ──
  double get _costVal => _dbl(_costPrice.text);
  double get _taxVal => _dbl(_taxPercent.text);
  double get _sellVal => _dbl(_sellingPrice.text);
  double get _discVal => _dbl(_discountPercent.text);
  double get _taxPerUnit => _costVal * _taxVal / 100;
  double get _margin => _sellVal - _costVal - _taxPerUnit;
  double get _marginPct => _sellVal > 0 ? (_margin / _sellVal * 100) : 0;
  int get _qtyVal => int.tryParse(_qty.text) ?? 0;
  double get _totalProfit => _margin * _qtyVal;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_duplicateFound) {
      final proceed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
        title: const Text('Duplicate item'),
        content: const Text('An item with this name already exists in inventory. Continue anyway?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
        ],
      ));
      if (proceed != true) return;
    }
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/inventory/stocks/', data: {
        'medication_name': _name.text.trim(),
        'abbreviation': _sku.text.trim(),
        'selling_price': _sellingPrice.text.trim(),
        'cost_price': _costPrice.text.trim(),
        'tax_percent': _taxPercent.text.trim(),
        'discount_percent': _discountPercent.text.trim(),
        'initial_quantity': int.tryParse(_qty.text) ?? 0,
        'batch_number': _batch.text.trim(),
        'reorder_level': int.tryParse(_reorderLevel.text) ?? 0,
        'reorder_quantity': int.tryParse(_reorderQty.text) ?? 0,
        'barcode': _barcode.text.trim(),
        'is_active': _isActive,
        if (_categoryId != null) 'category': _categoryId,
        if (_unitId != null) 'unit': _unitId,
        if (_expiryDate != null) 'expiry_date': DateFormat('yyyy-MM-dd').format(_expiryDate!),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock item added'), behavior: SnackBarBehavior.floating));
        context.go('/inventory');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final categories = ref.watch(_categoriesProvider).valueOrNull ?? [];
    final units = ref.watch(_unitsProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Stock Item'),
        actions: [
          TextButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary))
                : Icon(Icons.check_rounded, color: cs.primary),
            label: Text('Save', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            // ── Duplicate warning ──
            if (_duplicateFound && _duplicateItem != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Duplicate item found', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.orange)),
                    const SizedBox(height: 2),
                    Text('"${_duplicateItem!['medication_name']}" already exists with qty ${_duplicateItem!['total_quantity'] ?? 0}.', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  ])),
                  TextButton(
                    onPressed: () { if (_duplicateItem?['id'] != null) context.go('/inventory/${_duplicateItem!['id']}'); },
                    child: const Text('View', style: TextStyle(fontSize: 11)),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
            ],

            // ══════════════ SECTION 1: Item Details ══════════════
            _SectionHeader('Item Details', Icons.medication_rounded),
            const SizedBox(height: 12),

            // Medication name with catalog search
            TextFormField(
              controller: _name,
              decoration: _dec('Item Name *', Icons.medication_rounded).copyWith(
                suffixIcon: _catalogSearching ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
              ),
              validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
              onChanged: (v) {
                _searchCatalog(v);
                if (v.length >= 3) _checkDuplicate(v);
              },
            ),
            if (_catalogResults.isNotEmpty) Container(
              constraints: const BoxConstraints(maxHeight: 180),
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: ListView.separated(
                shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _catalogResults.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.15)),
                itemBuilder: (_, i) {
                  final item = _catalogResults[i];
                  return ListTile(
                    dense: true, visualDensity: VisualDensity.compact,
                    leading: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.medication_rounded, size: 16, color: cs.primary),
                    ),
                    title: Text(item['generic_name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text('${item['category'] ?? ''} · ${item['dosage_form'] ?? ''} · ${item['strength'] ?? ''}', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                    onTap: () => _selectCatalogItem(item),
                  );
                },
              ),
            ),
            // ── Not in catalog banner ──
            if (_catalogSearchDone && _catalogResults.isEmpty && !_catalogItemSelected && _name.text.length >= 2) ...[  
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF3B82F6), size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Item not found in catalog', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF3B82F6))),
                    const SizedBox(height: 4),
                    Text(
                      'No matching medication found for "${_name.text}". Please add it to the Medication Catalog first so it can be referenced across prescriptions, dispensing, and inventory.',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 30,
                      child: FilledButton.tonalIcon(
                        onPressed: () => context.push('/catalog'),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Go to Catalog', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      ),
                    ),
                  ])),
                ]),
              ),
            ],
            // ── Selected from catalog confirmation ──
            if (_catalogItemSelected) ...[  
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 16),
                  const SizedBox(width: 8),
                  Text('Selected from medication catalog', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                ]),
              ),
            ],
            const SizedBox(height: 12),

            // SKU
            Row(children: [
              Expanded(child: TextFormField(
                controller: _sku, readOnly: true,
                decoration: _dec('SKU / Code', Icons.qr_code_2_rounded),
              )),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() => _sku.text = _generateSku()),
                icon: Icon(Icons.refresh_rounded, size: 20, color: cs.primary),
                tooltip: 'Regenerate',
                style: IconButton.styleFrom(backgroundColor: cs.primaryContainer.withValues(alpha: 0.3)),
              ),
            ]),
            const SizedBox(height: 12),

            // Barcode
            Row(children: [
              Expanded(child: TextFormField(
                controller: _barcode,
                decoration: _dec('Barcode', Icons.qr_code_rounded),
              )),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () async {
                  final result = await showBarcodeScannerDialog(context);
                  if (result != null) setState(() => _barcode.text = result);
                },
                icon: Icon(Icons.camera_alt_rounded, size: 20, color: cs.primary),
                tooltip: 'Scan barcode',
                style: IconButton.styleFrom(backgroundColor: cs.primaryContainer.withValues(alpha: 0.3)),
              ),
            ]),
            const SizedBox(height: 12),

            // Category + Unit
            Row(children: [
              Expanded(child: DropdownButtonFormField<int>(
                initialValue: _categoryId,
                decoration: _dec('Category', Icons.category_rounded),
                isExpanded: true,
                items: categories.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['name'] ?? '', style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _categoryId = v),
              )),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<int>(
                initialValue: _unitId,
                decoration: _dec('Unit', Icons.straighten_rounded),
                isExpanded: true,
                items: units.map<DropdownMenuItem<int>>((u) => DropdownMenuItem(value: u['id'] as int, child: Text(u['name'] ?? '', style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _unitId = v),
              )),
            ]),
            const SizedBox(height: 12),

            // Active toggle
            SwitchListTile(
              title: const Text('Active', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(_isActive ? 'Item visible and sellable' : 'Item hidden from POS', style: const TextStyle(fontSize: 11)),
              value: _isActive, onChanged: (v) => setState(() => _isActive = v),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4), dense: true,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(height: 20),

            // ══════════════ SECTION 2: Stock Levels ══════════════
            _SectionHeader('Stock Levels', Icons.inventory_2_rounded),
            const SizedBox(height: 12),
            TextFormField(
              controller: _qty, keyboardType: TextInputType.number,
              decoration: _dec('Initial Quantity *', Icons.add_box_rounded),
              validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _reorderLevel, keyboardType: TextInputType.number,
                decoration: _dec('Reorder Level', Icons.warning_amber_rounded).copyWith(
                  suffixIcon: !_reorderAutoCalc ? IconButton(
                    icon: Icon(Icons.restart_alt_rounded, size: 18, color: cs.primary), tooltip: 'Auto-calculate',
                    onPressed: () { setState(() => _reorderAutoCalc = true); _onQtyChanged(); },
                  ) : null,
                ),
                onChanged: (_) { if (_reorderAutoCalc) setState(() => _reorderAutoCalc = false); },
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: _reorderQty, keyboardType: TextInputType.number,
                decoration: _dec('Reorder Qty', Icons.add_shopping_cart_rounded).copyWith(
                  suffixIcon: !_reorderAutoCalc ? IconButton(
                    icon: Icon(Icons.restart_alt_rounded, size: 18, color: cs.primary), tooltip: 'Auto-calculate',
                    onPressed: () { setState(() => _reorderAutoCalc = true); _onQtyChanged(); },
                  ) : null,
                ),
                onChanged: (_) { if (_reorderAutoCalc) setState(() => _reorderAutoCalc = false); },
              )),
            ]),
            if (_reorderAutoCalc) Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text('Auto: RL = 30% of qty, RQ = 50% of qty', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
            ),
            const SizedBox(height: 20),

            // ══════════════ SECTION 3: Pricing ══════════════
            _SectionHeader('Pricing', Icons.attach_money_rounded),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _costPrice, keyboardType: TextInputType.number,
                decoration: _dec('Unit Cost (Before Tax) *', Icons.money_rounded),
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                onChanged: (_) => setState(() {}),
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: _taxPercent, keyboardType: TextInputType.number,
                decoration: _dec('VAT / Tax %', Icons.percent_rounded),
                onChanged: (_) => setState(() {}),
              )),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _sellingPrice, keyboardType: TextInputType.number,
                decoration: _dec('Selling Price *', Icons.sell_rounded),
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                onChanged: (_) => setState(() {}),
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: _discountPercent, keyboardType: TextInputType.number,
                decoration: _dec('Default Discount %', Icons.discount_rounded),
                onChanged: (_) => setState(() {}),
              )),
            ]),
            const SizedBox(height: 12),

            // ── Live Profit Analysis ──
            if (_costVal > 0 && _sellVal > 0) _buildProfitAnalysis(cs),
            const SizedBox(height: 20),

            // ══════════════ SECTION 4: Batch & Expiry ══════════════
            _SectionHeader('Batch & Expiry', Icons.event_rounded),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _batch, readOnly: true,
                decoration: _dec('Batch Number', Icons.confirmation_number_rounded),
              )),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() => _batch.text = _generateBatch()),
                icon: Icon(Icons.refresh_rounded, size: 20, color: cs.primary),
                tooltip: 'Regenerate',
                style: IconButton.styleFrom(backgroundColor: cs.primaryContainer.withValues(alpha: 0.3)),
              ),
            ]),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickExpiryDate,
              child: InputDecorator(
                decoration: _dec('Expiry Date', Icons.event_rounded).copyWith(
                  suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (_expiryDate != null) IconButton(icon: Icon(Icons.clear_rounded, size: 18, color: cs.onSurfaceVariant), onPressed: () => setState(() => _expiryDate = null)),
                    Icon(Icons.calendar_today_rounded, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                  ]),
                ),
                child: Text(
                  _expiryDate != null ? DateFormat('MMM d, yyyy').format(_expiryDate!) : 'Select expiry date',
                  style: TextStyle(fontSize: 13, color: _expiryDate != null ? cs.onSurface : cs.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ══════════════ SECTION 5: Additional Details ══════════════
            _SectionHeader('Additional Details', Icons.description_rounded),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description, maxLines: 3,
              decoration: _dec('Description / Notes', Icons.notes_rounded),
            ),
            const SizedBox(height: 32),

            // ── Submit ──
            FilledButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded),
              label: const Text('Create Stock Item'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitAnalysis(ColorScheme cs) {
    final marginColor = _margin >= 0 ? const Color(0xFF22C55E) : Colors.red;
    final fmt = NumberFormat('#,##0.00', 'en');
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.analytics_rounded, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Text('Profit Analysis', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cs.onSurface)),
          ]),
          const SizedBox(height: 10),
          _profitRow('Tax per unit', 'KSH ${fmt.format(_taxPerUnit)}', cs.onSurface, cs),
          _profitRow('Margin per unit', 'KSH ${fmt.format(_margin)}', marginColor, cs),
          _profitRow('Margin %', '${_marginPct.toStringAsFixed(1)}%', marginColor, cs),
          if (_qtyVal > 0) _profitRow('Total profit ($_qtyVal units)', 'KSH ${fmt.format(_totalProfit)}', marginColor, cs),
          if (_discVal > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, size: 12, color: Colors.orange),
                const SizedBox(width: 6),
                Text('Discount of $_discVal% will reduce effective selling price to KSH ${fmt.format(_sellVal * (1 - _discVal / 100))}', style: const TextStyle(fontSize: 10, color: Colors.orange)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _profitRow(String label, String value, Color valColor, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: valColor)),
      ]),
    );
  }

  InputDecoration _dec(String label, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label, labelStyle: const TextStyle(fontSize: 13),
      prefixIcon: Icon(icon, size: 20),
      isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  final IconData icon;
  const _SectionHeader(this.text, this.icon);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: cs.primary),
      ),
      const SizedBox(width: 10),
      Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: cs.onSurface)),
    ]);
  }
}
