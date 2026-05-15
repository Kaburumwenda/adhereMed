import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api.dart';
import 'barcode_scanner_dialog.dart';

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

final _detailProvider = FutureProvider.autoDispose.family<Map, int>((ref, id) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/inventory/stocks/$id/');
  return res.data;
});

class EditStockScreen extends ConsumerStatefulWidget {
  final int id;
  const EditStockScreen({super.key, required this.id});
  @override
  ConsumerState<EditStockScreen> createState() => _EditStockScreenState();
}

class _EditStockScreenState extends ConsumerState<EditStockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _abbreviation = TextEditingController();
  final _sellingPrice = TextEditingController();
  final _costPrice = TextEditingController();
  final _taxPercent = TextEditingController();
  final _discountPercent = TextEditingController();
  final _reorderLevel = TextEditingController();
  final _reorderQty = TextEditingController();
  final _location = TextEditingController();
  final _barcode = TextEditingController();

  int? _categoryId;
  int? _unitId;
  String _prescriptionRequired = 'none';
  bool _isActive = true;
  bool _loading = false;
  bool _initialized = false;

  static const _rxOptions = ['none', 'optional', 'required'];

  @override
  void dispose() {
    _name.dispose();
    _abbreviation.dispose();
    _sellingPrice.dispose();
    _costPrice.dispose();
    _taxPercent.dispose();
    _discountPercent.dispose();
    _reorderLevel.dispose();
    _reorderQty.dispose();
    _location.dispose();
    _barcode.dispose();
    super.dispose();
  }

  void _populateFields(Map item) {
    if (_initialized) return;
    _initialized = true;
    _name.text = item['medication_name'] ?? '';
    _abbreviation.text = item['abbreviation'] ?? '';
    _sellingPrice.text = '${item['selling_price'] ?? ''}';
    _costPrice.text = '${item['cost_price'] ?? ''}';
    _taxPercent.text = '${item['tax_percent'] ?? '0'}';
    _discountPercent.text = '${item['discount_percent'] ?? '0'}';
    _reorderLevel.text = '${item['reorder_level'] ?? '10'}';
    _reorderQty.text = '${item['reorder_quantity'] ?? '0'}';
    _location.text = item['location_in_store'] ?? '';
    _barcode.text = item['barcode'] ?? '';
    _categoryId = item['category'];
    _unitId = item['unit'];
    _prescriptionRequired = item['prescription_required'] ?? 'none';
    _isActive = item['is_active'] ?? true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/inventory/stocks/${widget.id}/', data: {
        'medication_name': _name.text.trim(),
        'abbreviation': _abbreviation.text.trim(),
        'selling_price': _sellingPrice.text.trim(),
        'cost_price': _costPrice.text.trim(),
        'tax_percent': _taxPercent.text.trim(),
        'discount_percent': _discountPercent.text.trim(),
        'reorder_level': int.tryParse(_reorderLevel.text) ?? 10,
        'reorder_quantity': int.tryParse(_reorderQty.text) ?? 0,
        'location_in_store': _location.text.trim(),
        'barcode': _barcode.text.trim(),
        'prescription_required': _prescriptionRequired,
        'is_active': _isActive,
        if (_categoryId != null) 'category': _categoryId,
        if (_unitId != null) 'unit': _unitId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock item updated')));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(_detailProvider(widget.id));
    final categories = ref.watch(_categoriesProvider);
    final units = ref.watch(_unitsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Stock Item'),
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
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text('Failed to load: $e', style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => ref.invalidate(_detailProvider(widget.id)), child: const Text('Retry')),
        ])),
        data: (item) {
          _populateFields(item);
          final catList = categories.valueOrNull ?? [];
          final unitList = units.valueOrNull ?? [];

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Basic Info ──
                _SectionHeader('Basic Information'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _name,
                  decoration: _inputDecoration('Medication Name *', Icons.medication_rounded),
                  validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _abbreviation,
                  decoration: _inputDecoration('Abbreviation', Icons.short_text_rounded),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: catList.any((c) => c['id'] == _categoryId) ? _categoryId : null,
                      decoration: _inputDecoration('Category', Icons.category_rounded),
                      isExpanded: true,
                      items: catList.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['name'] ?? '', style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (v) => setState(() => _categoryId = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: unitList.any((u) => u['id'] == _unitId) ? _unitId : null,
                      decoration: _inputDecoration('Unit', Icons.straighten_rounded),
                      isExpanded: true,
                      items: unitList.map<DropdownMenuItem<int>>((u) => DropdownMenuItem(value: u['id'] as int, child: Text(u['name'] ?? '', style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (v) => setState(() => _unitId = v),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),

                // ── Pricing ──
                _SectionHeader('Pricing'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextFormField(
                    controller: _sellingPrice, keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Selling Price *', Icons.sell_rounded),
                    validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(
                    controller: _costPrice, keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Cost Price', Icons.money_rounded),
                  )),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextFormField(
                    controller: _taxPercent, keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Tax %', Icons.percent_rounded),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(
                    controller: _discountPercent, keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Discount %', Icons.discount_rounded),
                  )),
                ]),
                const SizedBox(height: 20),

                // ── Stock Settings ──
                _SectionHeader('Stock Settings'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextFormField(
                    controller: _reorderLevel, keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Reorder Level', Icons.warning_amber_rounded),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(
                    controller: _reorderQty, keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Reorder Qty', Icons.add_shopping_cart_rounded),
                  )),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextFormField(
                    controller: _barcode,
                    decoration: _inputDecoration('Barcode', Icons.qr_code_rounded),
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
                TextFormField(
                  controller: _location,
                  decoration: _inputDecoration('Location in Store', Icons.location_on_rounded),
                ),
                const SizedBox(height: 20),

                // ── Options ──
                _SectionHeader('Options'),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _prescriptionRequired,
                  decoration: _inputDecoration('Prescription Required', Icons.receipt_long_rounded),
                  items: _rxOptions.map((o) => DropdownMenuItem(value: o, child: Text(o[0].toUpperCase() + o.substring(1), style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() => _prescriptionRequired = v ?? 'none'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Active', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(_isActive ? 'Item is visible and sellable' : 'Item is hidden', style: const TextStyle(fontSize: 12)),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                const SizedBox(height: 24),

                // ── Info card ──
                Card(
                  elevation: 0,
                  color: cs.primaryContainer.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        'Quantity is managed via stock adjustments and batches. Use the Adjustments tab to correct stock levels.',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, height: 1.4),
                      )),
                    ]),
                  ),
                ),
                const SizedBox(height: 32),

                FilledButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded),
                  label: const Text('Update Item'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13),
      prefixIcon: Icon(icon, size: 20),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5))),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Container(width: 3, height: 16, decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface)),
    ]);
  }
}
