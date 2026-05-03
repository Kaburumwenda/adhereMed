import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../repository/billing_repository.dart';

class InvoiceFormScreen extends ConsumerStatefulWidget {
  final String? invoiceId;
  const InvoiceFormScreen({super.key, this.invoiceId});

  @override
  ConsumerState<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends ConsumerState<InvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = BillingRepository();

  final _patientIdCtrl = TextEditingController();
  final _subtotalCtrl = TextEditingController(text: '0');
  final _taxCtrl = TextEditingController(text: '0');
  final _discountCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  String _status = 'draft';
  DateTime? _dueDate;

  // Line items
  final List<Map<String, TextEditingController>> _items = [];

  bool _loading = false;
  bool _initialLoading = false;

  bool get _isEditing => widget.invoiceId != null;

  @override
  void initState() {
    super.initState();
    _dueDate = DateTime.now().add(const Duration(days: 30));
    if (_isEditing) {
      _loadInvoice();
    } else {
      _addItem();
    }
  }

  @override
  void dispose() {
    _patientIdCtrl.dispose();
    _subtotalCtrl.dispose();
    _taxCtrl.dispose();
    _discountCtrl.dispose();
    _notesCtrl.dispose();
    for (final item in _items) {
      for (final c in item.values) { c.dispose(); }
    }
    super.dispose();
  }

  void _addItem() {
    _items.add({
      'description': TextEditingController(),
      'quantity': TextEditingController(text: '1'),
      'unit_price': TextEditingController(text: '0'),
      'total': TextEditingController(text: '0'),
    });
    setState(() {});
  }

  void _removeItem(int index) {
    for (final c in _items[index].values) { c.dispose(); }
    _items.removeAt(index);
    _recalculate();
    setState(() {});
  }

  void _recalculate() {
    double subtotal = 0;
    for (final item in _items) {
      final qty = int.tryParse(item['quantity']!.text) ?? 0;
      final price = double.tryParse(item['unit_price']!.text) ?? 0;
      final total = qty * price;
      item['total']!.text = total.toStringAsFixed(2);
      subtotal += total;
    }
    _subtotalCtrl.text = subtotal.toStringAsFixed(2);
  }

  Future<void> _loadInvoice() async {
    setState(() => _initialLoading = true);
    try {
      final inv = await _repo.getDetail(int.parse(widget.invoiceId!));
      _patientIdCtrl.text = '${inv.patientId ?? ''}';
      _subtotalCtrl.text = inv.subtotal.toStringAsFixed(2);
      _taxCtrl.text = inv.taxAmount.toStringAsFixed(2);
      _discountCtrl.text = inv.discount.toStringAsFixed(2);
      _notesCtrl.text = inv.notes ?? '';
      _status = inv.status;
      if (inv.dueDate != null) _dueDate = DateTime.tryParse(inv.dueDate!);
      // Load existing items
      if (inv.items != null) {
        for (final i in inv.items!) {
          final item = i as Map<String, dynamic>;
          _items.add({
            'description': TextEditingController(text: item['description'] ?? ''),
            'quantity': TextEditingController(text: '${item['quantity'] ?? 1}'),
            'unit_price': TextEditingController(text: '${item['unit_price'] ?? 0}'),
            'total': TextEditingController(text: '${item['total'] ?? 0}'),
          });
        }
      }
      if (_items.isEmpty) _addItem();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _initialLoading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    _recalculate();

    final subtotal = double.tryParse(_subtotalCtrl.text) ?? 0;
    final tax = double.tryParse(_taxCtrl.text) ?? 0;
    final discount = double.tryParse(_discountCtrl.text) ?? 0;

    try {
      final data = {
        'patient': int.tryParse(_patientIdCtrl.text),
        'items': _items
            .map((i) => {
                  'description': i['description']!.text,
                  'quantity': int.tryParse(i['quantity']!.text) ?? 1,
                  'unit_price': double.tryParse(i['unit_price']!.text) ?? 0,
                  'total': double.tryParse(i['total']!.text) ?? 0,
                })
            .toList(),
        'subtotal': subtotal,
        'tax': tax,
        'discount': discount,
        'total': subtotal + tax - discount,
        'status': _status,
        'notes': _notesCtrl.text,
        if (_dueDate != null)
          'due_date': '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}',
      };
      if (_isEditing) {
        await _repo.update(int.parse(widget.invoiceId!), data);
      } else {
        await _repo.create(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEditing ? 'Invoice updated' : 'Invoice created')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) return const LoadingWidget();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
                const SizedBox(width: 8),
                Text(_isEditing ? 'Edit Invoice' : 'New Invoice',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),

              // Patient & status
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: 200,
                        child: TextFormField(
                          controller: _patientIdCtrl,
                          decoration: const InputDecoration(labelText: 'Patient ID'),
                          keyboardType: TextInputType.number,
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        child: DropdownButtonFormField<String>(
                          initialValue: _status,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: const [
                            DropdownMenuItem(value: 'draft', child: Text('Draft')),
                            DropdownMenuItem(value: 'sent', child: Text('Sent')),
                            DropdownMenuItem(value: 'paid', child: Text('Paid')),
                            DropdownMenuItem(value: 'partially_paid', child: Text('Partially Paid')),
                            DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                            DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                          ],
                          onChanged: (v) => setState(() => _status = v ?? 'draft'),
                        ),
                      ),
                      SizedBox(
                        width: 250,
                        child: InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _dueDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (d != null) setState(() => _dueDate = d);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Due Date'),
                            child: Text(
                              _dueDate != null
                                  ? '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}'
                                  : 'Select date',
                              style: TextStyle(
                                color: _dueDate != null
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Line items
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Line Items',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: _addItem,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Item'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...List.generate(_items.length, (i) {
                        final item = _items[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: item['description'],
                                  decoration: const InputDecoration(
                                      labelText: 'Description', isDense: true),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 80,
                                child: TextFormField(
                                  controller: item['quantity'],
                                  decoration: const InputDecoration(
                                      labelText: 'Qty', isDense: true),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => _recalculate(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 100,
                                child: TextFormField(
                                  controller: item['unit_price'],
                                  decoration: const InputDecoration(
                                      labelText: 'Price', isDense: true),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => _recalculate(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 100,
                                child: TextFormField(
                                  controller: item['total'],
                                  decoration: const InputDecoration(
                                      labelText: 'Total', isDense: true),
                                  readOnly: true,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, size: 18, color: AppColors.error),
                                onPressed: () => _removeItem(i),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Totals
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: 150,
                        child: TextFormField(
                          controller: _subtotalCtrl,
                          decoration: const InputDecoration(labelText: 'Subtotal'),
                          readOnly: true,
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: TextFormField(
                          controller: _taxCtrl,
                          decoration: const InputDecoration(labelText: 'Tax'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: TextFormField(
                          controller: _discountCtrl,
                          decoration: const InputDecoration(labelText: 'Discount'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: TextFormField(
                          controller: _notesCtrl,
                          decoration: const InputDecoration(labelText: 'Notes'),
                          maxLines: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  FilledButton(
                    onPressed: _loading ? null : _save,
                    child: _loading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isEditing ? 'Update Invoice' : 'Create Invoice'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
    );
  }
}
