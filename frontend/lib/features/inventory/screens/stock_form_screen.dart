import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../models/stock_model.dart';
import '../repository/inventory_repository.dart';

class StockFormScreen extends ConsumerStatefulWidget {
  final int? stockId;
  const StockFormScreen({super.key, this.stockId});

  @override
  ConsumerState<StockFormScreen> createState() => _StockFormScreenState();
}

class _StockFormScreenState extends ConsumerState<StockFormScreen> {
  final _repo = InventoryRepository();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _initialLoading = false;
  String? _error;

  final _medicationNameCtrl = TextEditingController();
  final _sellingPriceCtrl = TextEditingController();
  final _costPriceCtrl = TextEditingController();
  final _reorderLevelCtrl = TextEditingController(text: '10');
  final _reorderQtyCtrl = TextEditingController(text: '20');
  final _locationCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _initialQtyCtrl = TextEditingController();
  final _batchNumberCtrl = TextEditingController();
  DateTime? _expiryDate;
  bool _isActive = true;
  String _prescriptionRequired = 'none';
  int? _selectedCategory;
  int? _selectedUnit;
  List<Category> _categories = [];
  List<Unit> _units = [];
  List<StockBatch> _existingBatches = [];

  // Per-batch inline editing
  int? _editingBatchId;
  final _batchEditQtyCtrl = TextEditingController();
  final _batchEditNumberCtrl = TextEditingController();
  DateTime? _batchEditExpiry;

  bool get _isEditing => widget.stockId != null;

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
    if (_isEditing) _loadStock();
  }

  Future<void> _loadDropdowns() async {
    try {
      final cats = await _repo.getCategories();
      final units = await _repo.getUnits();
      if (mounted) {
        setState(() {
          _categories = cats;
          _units = units;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _medicationNameCtrl.dispose();
    _sellingPriceCtrl.dispose();
    _costPriceCtrl.dispose();
    _reorderLevelCtrl.dispose();
    _reorderQtyCtrl.dispose();
    _locationCtrl.dispose();
    _barcodeCtrl.dispose();
    _initialQtyCtrl.dispose();
    _batchNumberCtrl.dispose();
    _batchEditQtyCtrl.dispose();
    _batchEditNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStock() async {
    setState(() => _initialLoading = true);
    try {
      final stock = await _repo.getStock(widget.stockId!);
      _medicationNameCtrl.text = stock.medicationName;
      _sellingPriceCtrl.text = stock.sellingPrice.toString();
      _costPriceCtrl.text = stock.costPrice.toString();
      _reorderLevelCtrl.text = stock.reorderLevel.toString();
      _reorderQtyCtrl.text = stock.reorderQuantity.toString();
      _locationCtrl.text = stock.locationInStore ?? '';
      _barcodeCtrl.text = stock.barcode ?? '';
      _isActive = stock.isActive;
      _prescriptionRequired = stock.prescriptionRequired;
      _selectedCategory = stock.category;
      _selectedUnit = stock.unit;
      _existingBatches = stock.batches;
      setState(() => _initialLoading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _initialLoading = false;
      });
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Batch read row (non-editing) ─────────────────────────────────────────
  Widget _buildBatchReadRow(StockBatch b) {
    return Row(children: [
      Icon(
        b.isExpired ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
        color: b.isExpired ? AppColors.error : AppColors.primary,
        size: 18,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Batch ${b.batchNumber}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            Text(
              'Qty: ${b.quantityRemaining}/${b.quantityReceived}  ·  Expires: ${b.expiryDate}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
      if (b.isExpired)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('EXPIRED',
              style: TextStyle(
                  color: AppColors.error,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ),
      const SizedBox(width: 8),
      IconButton(
        icon: Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
        tooltip: 'Edit batch',
        visualDensity: VisualDensity.compact,
        onPressed: () {
          setState(() {
            _editingBatchId = b.id;
            _batchEditQtyCtrl.text = b.quantityRemaining.toString();
            _batchEditNumberCtrl.text = b.batchNumber;
            if (b.expiryDate.isNotEmpty) {
              final parts = b.expiryDate.split('-');
              if (parts.length == 3) {
                _batchEditExpiry = DateTime(
                  int.parse(parts[0]),
                  int.parse(parts[1]),
                  int.parse(parts[2]),
                );
              }
            }
          });
        },
      ),
    ]);
  }

  // ── Batch inline edit fields ─────────────────────────────────────────────
  Widget _buildBatchEditFields(StockBatch b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.edit, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text('Editing Batch',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.primary)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: _batchEditNumberCtrl,
              decoration: const InputDecoration(
                labelText: 'Batch Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag_outlined),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: _batchEditQtyCtrl,
              decoration: const InputDecoration(
                labelText: 'Quantity Remaining',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers_outlined),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _batchEditExpiry ??
                  DateTime.now().add(const Duration(days: 365)),
              firstDate: DateTime(2000),
              lastDate: DateTime.now().add(const Duration(days: 3650)),
              helpText: 'Select Expiry Date',
            );
            if (picked != null) setState(() => _batchEditExpiry = picked);
          },
          child: AbsorbPointer(
            child: TextFormField(
              decoration: InputDecoration(
                labelText: 'Expiry Date',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.event_outlined),
                isDense: true,
                suffixIcon: _batchEditExpiry != null
                    ? Icon(Icons.check_circle_outline,
                        color: AppColors.success, size: 18)
                    : const Icon(Icons.calendar_today, size: 18),
              ),
              controller: TextEditingController(
                text: _batchEditExpiry != null
                    ? _formatDate(_batchEditExpiry!)
                    : '',
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Cancel'),
              onPressed: () => setState(() {
                _editingBatchId = null;
                _batchEditExpiry = null;
              }),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.save_outlined, size: 16),
              label: const Text('Save'),
              onPressed: () async {
                final qty = int.tryParse(_batchEditQtyCtrl.text.trim());
                if (qty == null) return;
                final data = <String, dynamic>{
                  'batch_number': _batchEditNumberCtrl.text.trim(),
                  'quantity_remaining': qty,
                  if (_batchEditExpiry != null)
                    'expiry_date': _formatDate(_batchEditExpiry!),
                };
                try {
                  await _repo.updateBatch(b.id, data);
                  setState(() => _editingBatchId = null);
                  await _loadStock();
                } catch (e) {
                  setState(() => _error = e.toString());
                }
              },
            ),
          ),
        ]),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = {
        'medication_name': _medicationNameCtrl.text.trim(),
        'selling_price': double.parse(_sellingPriceCtrl.text),
        'cost_price': double.parse(_costPriceCtrl.text),
        'reorder_level': int.parse(_reorderLevelCtrl.text),
        'reorder_quantity': int.parse(_reorderQtyCtrl.text),
        'location_in_store': _locationCtrl.text.trim(),
        'barcode': _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
        'prescription_required': _prescriptionRequired,
        'is_active': _isActive,
        'category': _selectedCategory,
        'unit': _selectedUnit,
      };
      if (!_isEditing) {
        if (_initialQtyCtrl.text.isNotEmpty) {
          data['initial_quantity'] = int.parse(_initialQtyCtrl.text);
        }
        if (_batchNumberCtrl.text.trim().isNotEmpty) {
          data['batch_number'] = _batchNumberCtrl.text.trim();
        }
        if (_expiryDate != null) {
          data['expiry_date'] = _formatDate(_expiryDate!);
        }
      }
      if (_isEditing) {
        await _repo.updateStock(widget.stockId!, data);
        // Add new batch if fields are filled
        if (_initialQtyCtrl.text.isNotEmpty && _expiryDate != null) {
          await _repo.createBatch({
            'stock': widget.stockId,
            'batch_number': _batchNumberCtrl.text.trim().isNotEmpty
                ? _batchNumberCtrl.text.trim()
                : 'BATCH-${DateTime.now().millisecondsSinceEpoch}',
            'quantity_received': int.parse(_initialQtyCtrl.text),
            'quantity_remaining': int.parse(_initialQtyCtrl.text),
            'cost_price_per_unit': double.parse(_costPriceCtrl.text),
            'expiry_date': _formatDate(_expiryDate!),
          });
        }
      } else {
        await _repo.createStock(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Stock item ${_isEditing ? 'updated' : 'created'} successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_initialLoading) return const LoadingWidget();
    if (_error != null && _initialLoading) {
      return app_error.AppErrorWidget(message: _error!, onRetry: _loadStock);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero Header ────────────────────────────────────────────────
            Card(
              clipBehavior: Clip.antiAlias,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 20, 20, 20),
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
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _isEditing
                            ? Icons.edit_outlined
                            : Icons.add_box_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? 'Edit Stock Item' : 'Add Stock Item',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _isEditing
                              ? 'Update medication stock details'
                              : 'Register a new medication in inventory',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
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
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.error_outline, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style:
                            TextStyle(color: AppColors.error, fontSize: 13)),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 20),

            // ── Section 1: Basic Information ───────────────────────────────
            _SectionCard(
              icon: Icons.medication_outlined,
              title: 'Basic Information',
              children: [
                TextFormField(
                  controller: _medicationNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Medication Name *',
                    hintText: 'e.g. Paracetamol 500mg',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_pharmacy_outlined),
                    helperText:
                        'A unique Medication ID will be auto-generated',
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<int>(
                            value: null, child: Text('None')),
                        ..._categories.map((c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (v) => setState(() => _selectedCategory = v),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedUnit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.straighten_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<int>(
                            value: null, child: Text('None')),
                        ..._units.map((u) => DropdownMenuItem(
                              value: u.id,
                              child: Text(
                                '${u.name}${u.abbreviation != null && u.abbreviation!.isNotEmpty ? ' (${u.abbreviation})' : ''}',
                              ),
                            )),
                      ],
                      onChanged: (v) => setState(() => _selectedUnit = v),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _locationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Location in Store',
                    hintText: 'e.g. Shelf A3, Refrigerator',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _barcodeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Barcode / SKU',
                    hintText: 'Optional — scan or enter manually',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.qr_code_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                // Prescription required
                DropdownButtonFormField<String>(
                  value: _prescriptionRequired,
                  decoration: const InputDecoration(
                    labelText: 'Prescription Required',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description_outlined),
                    helperText:
                        'Does this medication require a doctor\'s prescription?',
                    helperMaxLines: 2,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'none',
                      child: Row(children: [
                        Icon(Icons.check_circle_outline,
                            size: 16, color: Colors.green),
                        SizedBox(width: 8),
                        Text('None — no prescription needed'),
                      ]),
                    ),
                    DropdownMenuItem(
                      value: 'recommended',
                      child: Row(children: [
                        Icon(Icons.info_outline,
                            size: 16, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Recommended'),
                      ]),
                    ),
                    DropdownMenuItem(
                      value: 'required',
                      child: Row(children: [
                        Icon(Icons.warning_amber_outlined,
                            size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Required — must have prescription'),
                      ]),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _prescriptionRequired = v ?? 'none'),
                ),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(
                      _isActive
                          ? Icons.toggle_on_outlined
                          : Icons.toggle_off_outlined,
                      color: _isActive
                          ? AppColors.success
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Active',
                              style: TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 14)),
                          Text(
                            _isActive
                                ? 'Item is available for sale'
                                : 'Item is disabled',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                      activeColor: AppColors.success,
                    ),
                  ]),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Section 2: Pricing ─────────────────────────────────────────
            _SectionCard(
              icon: Icons.payments_outlined,
              title: 'Pricing',
              children: [
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sellingPriceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Selling Price *',
                        prefixText: 'KSh ',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.sell_outlined),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      controller: _costPriceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Cost Price *',
                        prefixText: 'KSh ',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.shopping_bag_outlined),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                ]),
              ],
            ),

            const SizedBox(height: 16),

            // ── Section 3: Reorder Settings ────────────────────────────────
            _SectionCard(
              icon: Icons.low_priority_outlined,
              title: 'Reorder Settings',
              children: [
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _reorderLevelCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reorder Level *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.warning_amber_outlined),
                        helperText: 'Alert when qty falls below this',
                        helperMaxLines: 2,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      controller: _reorderQtyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reorder Quantity *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.add_shopping_cart_outlined),
                        helperText: 'Units to order when restocking',
                        helperMaxLines: 2,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                ]),
              ],
            ),

            const SizedBox(height: 16),

            // ── Section 4: Batch ───────────────────────────────────────────
            _SectionCard(
              icon: Icons.view_list_outlined,
              title: _isEditing ? 'Batch Management' : 'Initial Stock Batch',
              subtitle: _isEditing
                  ? null
                  : 'Optionally add an opening batch with quantity and expiry',
              children: [
                if (_isEditing && _existingBatches.isNotEmpty) ...[
                  ...(_existingBatches.map((b) {
                    final isEditingThis = _editingBatchId == b.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isEditingThis
                              ? AppColors.primary.withValues(alpha: 0.04)
                              : b.isExpired
                                  ? AppColors.error.withValues(alpha: 0.05)
                                  : AppColors.background,
                          border: Border.all(
                            color: isEditingThis
                                ? AppColors.primary.withValues(alpha: 0.4)
                                : b.isExpired
                                    ? AppColors.error.withValues(alpha: 0.3)
                                    : AppColors.border,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: isEditingThis
                            ? _buildBatchEditFields(b)
                            : _buildBatchReadRow(b),
                      ),
                    );
                  })),
                  const Divider(height: 24),
                  Text(
                    'Add New Batch',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_isEditing && _existingBatches.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(children: [
                      Icon(Icons.info_outline,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text('No batches yet — add one below',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                    ]),
                  ),
                ],
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _initialQtyCtrl,
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.numbers_outlined),
                        hintText: _isEditing ? 'Required' : 'Optional',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      controller: _batchNumberCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Batch Number',
                        hintText: 'Auto-generated if empty',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.tag_outlined),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 3650)),
                      helpText: 'Select Expiry Date',
                    );
                    if (picked != null) setState(() => _expiryDate = picked);
                  },
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Expiry Date',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.event_outlined),
                        suffixIcon: _expiryDate != null
                            ? Icon(Icons.check_circle_outline,
                                color: AppColors.success, size: 18)
                            : const Icon(Icons.calendar_today, size: 18),
                        hintText: 'Tap to select',
                      ),
                      controller: TextEditingController(
                        text: _expiryDate != null
                            ? _formatDate(_expiryDate!)
                            : '',
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Save Button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _loading ? null : _save,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(_isEditing
                        ? Icons.save_outlined
                        : Icons.add_circle_outline),
                label: Text(
                  _isEditing ? 'Update Stock Item' : 'Save Stock Item',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Section Card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ]),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(
                  subtitle!,
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ],
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}
