import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api.dart';

final _stocksProvider = FutureProvider.autoDispose<List>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/inventory/stocks/', queryParameters: {'page_size': 5000});
  return (res.data['results'] as List?) ?? [];
});

class AddAdjustmentScreen extends ConsumerStatefulWidget {
  const AddAdjustmentScreen({super.key});
  @override
  ConsumerState<AddAdjustmentScreen> createState() => _AddAdjustmentScreenState();
}

class _AddAdjustmentScreenState extends ConsumerState<AddAdjustmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController(text: '1');
  final _notesCtrl = TextEditingController();
  Map<String, dynamic>? _selectedStock;
  String _reason = 'count_correction';
  bool _isAdd = true;
  bool _loading = false;

  static const _reasons = <String, String>{
    'count_correction': 'Count Correction',
    'damage': 'Damage',
    'theft': 'Theft',
    'expiry': 'Expiry',
    'return_to_supplier': 'Return to Supplier',
    'other': 'Other',
  };

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStock == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a stock item')));
      return;
    }

    setState(() => _loading = true);
    final absQty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final qtyChange = _isAdd ? absQty : -absQty;

    try {
      await ref.read(dioProvider).post('/inventory/adjustments/', data: {
        'stock': _selectedStock!['id'],
        'reason': _reason,
        'quantity_change': qtyChange,
        'notes': _notesCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adjustment created')));
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
    final stocksAsync = ref.watch(_stocksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('New Adjustment')),
      body: stocksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load stocks: $e')),
        data: (stocks) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── Stock Selection ──
              Text('Stock Item *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 8),
              Autocomplete<Map<String, dynamic>>(
                displayStringForOption: (s) => s['medication_name'] ?? '',
                optionsBuilder: (text) {
                  if (text.text.isEmpty) return stocks.cast<Map<String, dynamic>>();
                  final q = text.text.toLowerCase();
                  return stocks.cast<Map<String, dynamic>>().where((s) =>
                    (s['medication_name'] ?? '').toString().toLowerCase().contains(q));
                },
                onSelected: (s) => setState(() => _selectedStock = s),
                fieldViewBuilder: (ctx, ctrl, focus, onSubmit) => TextField(
                  controller: ctrl,
                  focusNode: focus,
                  decoration: InputDecoration(
                    hintText: 'Search stock items...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
                optionsViewBuilder: (ctx, onSelected, options) => Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (_, i) {
                          final s = options.elementAt(i);
                          final qty = (s['total_quantity'] ?? s['quantity'] ?? 0);
                          return ListTile(
                            dense: true,
                            title: Text(s['medication_name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: Text('On hand: $qty', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                            onTap: () => onSelected(s),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              if (_selectedStock != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Icon(Icons.check_circle_rounded, size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${_selectedStock!['medication_name']} — On hand: ${_selectedStock!['total_quantity'] ?? _selectedStock!['quantity'] ?? 0}', style: TextStyle(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w600))),
                  ]),
                ),
              ],
              const SizedBox(height: 20),

              // ── Reason ──
              Text('Reason *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _reason,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                items: _reasons.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) { if (v != null) setState(() => _reason = v); },
              ),
              const SizedBox(height: 20),

              // ── Direction ──
              Text('Direction *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isAdd = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _isAdd ? const Color(0xFF22C55E).withValues(alpha: 0.12) : cs.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _isAdd ? const Color(0xFF22C55E) : cs.outlineVariant.withValues(alpha: 0.3), width: _isAdd ? 2 : 1),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_rounded, size: 20, color: _isAdd ? const Color(0xFF22C55E) : cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text('Add', style: TextStyle(fontSize: 14, fontWeight: _isAdd ? FontWeight.w700 : FontWeight.w500, color: _isAdd ? const Color(0xFF22C55E) : cs.onSurfaceVariant)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isAdd = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: !_isAdd ? Colors.red.withValues(alpha: 0.12) : cs.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: !_isAdd ? Colors.red : cs.outlineVariant.withValues(alpha: 0.3), width: !_isAdd ? 2 : 1),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.remove_rounded, size: 20, color: !_isAdd ? Colors.red : cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text('Remove', style: TextStyle(fontSize: 14, fontWeight: !_isAdd ? FontWeight.w700 : FontWeight.w500, color: !_isAdd ? Colors.red : cs.onSurfaceVariant)),
                      ]),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 20),

              // ── Quantity ──
              Text('Quantity *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter quantity',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Quantity is required';
                  final n = int.tryParse(v.trim());
                  if (n == null || n <= 0) return 'Enter a positive number';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── Notes ──
              Text('Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Optional notes...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
              const SizedBox(height: 28),

              // ── Submit ──
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create Adjustment', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
