import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../inventory/models/stock_model.dart';
import '../../inventory/repository/inventory_repository.dart';
import '../../suppliers/models/supplier_model.dart';
import '../../suppliers/repository/supplier_repository.dart';
import '../repository/purchase_order_repository.dart';

class PurchaseOrderFormScreen extends ConsumerStatefulWidget {
  const PurchaseOrderFormScreen({super.key});

  @override
  ConsumerState<PurchaseOrderFormScreen> createState() =>
      _PurchaseOrderFormScreenState();
}

class _PurchaseOrderFormScreenState
    extends ConsumerState<PurchaseOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _poRepo = PurchaseOrderRepository();
  final _supplierRepo = SupplierRepository();
  final _inventoryRepo = InventoryRepository();

  List<Supplier> _suppliers = [];
  Supplier? _selectedSupplier;
  DateTime? _expectedDelivery;
  final _notesCtrl = TextEditingController();

  final List<_LineItem> _lineItems = [];
  bool _loadingSuppliers = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    _addLine(); // start with one empty line
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (final li in _lineItems) {
      li.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    try {
      final result = await _supplierRepo.getSuppliers(page: 1);
      if (mounted) {
        setState(() {
          _suppliers = result.results;
          _loadingSuppliers = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingSuppliers = false);
    }
  }

  void _addLine() {
    setState(() => _lineItems.add(_LineItem()));
  }

  void _removeLine(int index) {
    setState(() {
      _lineItems[index].dispose();
      _lineItems.removeAt(index);
    });
  }

  double get _totalCost => _lineItems.fold(0, (sum, li) {
        final qty = double.tryParse(li.qtyCtrl.text) ?? 0;
        final price = double.tryParse(li.priceCtrl.text) ?? 0;
        return sum + (qty * price);
      });

  String _formatCurrency(double amount) =>
      'KSh ${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},')}';

  Future<void> _submit({String status = 'draft'}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSupplier == null) {
      setState(() => _error = 'Please select a supplier.');
      return;
    }
    if (_lineItems.isEmpty ||
        !_lineItems.any((li) => li.stockId != null)) {
      setState(() => _error = 'Add at least one item.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final items = _lineItems
          .where((li) => li.stockId != null)
          .map((li) => {
                'medication_stock_id': li.stockId,
                'name': li.stockName ?? '',
                'qty': int.tryParse(li.qtyCtrl.text) ?? 1,
                'unit_cost':
                    double.tryParse(li.priceCtrl.text) ?? 0,
                'total': ((double.tryParse(li.qtyCtrl.text) ?? 0) *
                    (double.tryParse(li.priceCtrl.text) ?? 0)),
              })
          .toList();

      final data = {
        'supplier': _selectedSupplier!.id,
        'status': status,
        'items': items,
        'total_cost': _totalCost,
        'notes': _notesCtrl.text.trim(),
        if (_expectedDelivery != null)
          'expected_delivery':
              _expectedDelivery!.toIso8601String().split('T').first,
      };

      await _poRepo.createPurchaseOrder(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'sent'
                ? 'Purchase order sent to supplier.'
                : 'Purchase order saved as draft.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _expectedDelivery ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _expectedDelivery = picked);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back)),
                const SizedBox(width: 8),
                Text('New Purchase Order',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),

            // Supplier + Delivery date
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Order Details',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 16),
                    LayoutBuilder(builder: (context, constraints) {
                      final wide = constraints.maxWidth > 600;
                      final supplierField = _loadingSuppliers
                          ? const Center(child: LoadingWidget())
                          : DropdownButtonFormField<Supplier>(
                              initialValue: _selectedSupplier,
                              decoration: const InputDecoration(
                                labelText: 'Supplier *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.business),
                              ),
                              items: _suppliers
                                  .map((s) => DropdownMenuItem(
                                      value: s, child: Text(s.name)))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedSupplier = v),
                              validator: (v) =>
                                  v == null ? 'Required' : null,
                            );
                      final dateField = InkWell(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Expected Delivery',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _expectedDelivery != null
                                ? '${_expectedDelivery!.day.toString().padLeft(2, '0')}/'
                                    '${_expectedDelivery!.month.toString().padLeft(2, '0')}/'
                                    '${_expectedDelivery!.year}'
                                : 'Select date',
                            style: TextStyle(
                                color: _expectedDelivery != null
                                    ? null
                                    : AppColors.textSecondary),
                          ),
                        ),
                      );
                      if (wide) {
                        return Row(children: [
                          Expanded(child: supplierField),
                          const SizedBox(width: 16),
                          Expanded(child: dateField),
                        ]);
                      }
                      return Column(children: [
                        supplierField,
                        const SizedBox(height: 12),
                        dateField,
                      ]);
                    }),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Line Items
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Items',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _addLine,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Item'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_lineItems.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('No items added yet.',
                              style: TextStyle(
                                  color: AppColors.textSecondary)),
                        ),
                      )
                    else
                      ...List.generate(
                          _lineItems.length,
                          (i) => _LineItemRow(
                                lineItem: _lineItems[i],
                                index: i,
                                inventoryRepo: _inventoryRepo,
                                onRemove: () => _removeLine(i),
                                onChanged: () => setState(() {}),
                              )),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Total:',
                            style: TextStyle(
                                color: AppColors.textSecondary)),
                        const SizedBox(width: 12),
                        Text(
                          _formatCurrency(_totalCost),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppColors.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error!,
                            style: TextStyle(color: AppColors.error))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _saving ? null : () => context.pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _submit(status: 'draft'),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save as Draft'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _submit(status: 'sent'),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send),
                  label: const Text('Send to Supplier'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Line Item ────────────────────────────────────────────────────────────────

class _LineItem {
  int? stockId;
  String? stockName;
  final TextEditingController qtyCtrl = TextEditingController(text: '1');
  final TextEditingController priceCtrl = TextEditingController();

  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

// ─── Line Item Row ────────────────────────────────────────────────────────────

class _LineItemRow extends StatefulWidget {
  final _LineItem lineItem;
  final int index;
  final InventoryRepository inventoryRepo;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _LineItemRow({
    required this.lineItem,
    required this.index,
    required this.inventoryRepo,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_LineItemRow> createState() => _LineItemRowState();
}

class _LineItemRowState extends State<_LineItemRow> {
  final _searchCtrl = TextEditingController();
  List<MedicationStock> _suggestions = [];
  bool _searching = false;
  MedicationStock? _selected;

  @override
  void initState() {
    super.initState();
    if (widget.lineItem.stockName != null) {
      _searchCtrl.text = widget.lineItem.stockName!;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final result = await widget.inventoryRepo
          .getStocks(page: 1, search: q);
      if (mounted) {
        setState(() {
          _suggestions = result.results;
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _select(MedicationStock stock) {
    setState(() {
      _selected = stock;
      _suggestions = [];
      _searchCtrl.text = stock.medicationName;
      widget.lineItem.stockId = stock.id;
      widget.lineItem.stockName = stock.medicationName;
      // Pre-fill cost price
      if (stock.costPrice > 0 &&
          widget.lineItem.priceCtrl.text.isEmpty) {
        widget.lineItem.priceCtrl.text =
            stock.costPrice.toStringAsFixed(2);
      }
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final lineTotal =
        (double.tryParse(widget.lineItem.qtyCtrl.text) ?? 0) *
            (double.tryParse(widget.lineItem.priceCtrl.text) ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 600;
        final itemSearch = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search medication stock...',
                prefixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2)),
                      )
                    : const Icon(Icons.search, size: 18),
                suffixIcon: _selected != null
                    ? Icon(Icons.check_circle,
                        color: AppColors.success, size: 18)
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                isDense: true,
              ),
              onChanged: _search,
            ),
            if (_suggestions.isNotEmpty)
              Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    itemBuilder: (_, i) {
                      final s = _suggestions[i];
                      return ListTile(
                        dense: true,
                        title: Text(s.medicationName,
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                          'Cost: KSh ${s.costPrice.toStringAsFixed(2)} · '
                          'Stock: ${s.totalQuantity ?? 0}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () => _select(s),
                      );
                    },
                  ),
                ),
              ),
          ],
        );

        final qtyField = TextFormField(
          controller: widget.lineItem.qtyCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Qty *',
            border: OutlineInputBorder(),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Req';
            if ((int.tryParse(v) ?? 0) <= 0) return '>0';
            return null;
          },
          onChanged: (_) => widget.onChanged(),
        );

        final priceField = TextFormField(
          controller: widget.lineItem.priceCtrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Unit Cost *',
            prefixText: 'KSh ',
            border: OutlineInputBorder(),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Req';
            if ((double.tryParse(v) ?? -1) < 0) return '≥0';
            return null;
          },
          onChanged: (_) => widget.onChanged(),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                    child: Text('${widget.index + 1}',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold))),
              ),
              const Spacer(),
              if (lineTotal > 0)
                Text(
                  'KSh ${lineTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.success),
                ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: widget.onRemove,
                icon: Icon(Icons.delete_outline,
                    color: AppColors.error, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                    minWidth: 32, minHeight: 32),
              ),
            ]),
            const SizedBox(height: 8),
            if (wide)
              Row(children: [
                Expanded(flex: 3, child: itemSearch),
                const SizedBox(width: 12),
                Expanded(child: qtyField),
                const SizedBox(width: 12),
                Expanded(child: priceField),
              ])
            else
              Column(children: [
                itemSearch,
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: qtyField),
                  const SizedBox(width: 8),
                  Expanded(child: priceField),
                ]),
              ]),
          ],
        );
      }),
    );
  }
}
