import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/lab_order_model.dart';
import '../repository/lab_repository.dart';

class LabOrderFormScreen extends ConsumerStatefulWidget {
  final String? orderId;
  const LabOrderFormScreen({super.key, this.orderId});

  @override
  ConsumerState<LabOrderFormScreen> createState() => _LabOrderFormScreenState();
}

class _LabOrderFormScreenState extends ConsumerState<LabOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = LabRepository();

  // Patient search
  final _patientSearchCtrl = TextEditingController();
  int? _selectedPatientId;
  String? _selectedPatientName;
  List<Map<String, dynamic>> _patientResults = [];
  bool _searchingPatients = false;
  Timer? _debounce;

  final _notesCtrl = TextEditingController();
  String _priority = 'routine';
  String _status = 'pending';
  bool _isHomeCollection = false;
  bool _loading = false;
  bool _initialLoading = false;

  List<LabTestCatalog> _catalogTests = [];
  List<int> _selectedTestIds = [];
  bool _catalogLoading = true;

  bool get _isEditing => widget.orderId != null;

  static const _priorities = [
    ('routine', 'Routine'),
    ('urgent', 'Urgent'),
    ('stat', 'STAT'),
  ];

  static const _statuses = [
    ('pending', 'Pending'),
    ('sample_collected', 'Sample Collected'),
    ('processing', 'Processing'),
    ('completed', 'Completed'),
    ('cancelled', 'Cancelled'),
  ];

  @override
  void initState() {
    super.initState();
    _loadCatalog();
    if (_isEditing) _loadOrder();
  }

  @override
  void dispose() {
    _patientSearchCtrl.dispose();
    _notesCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final tests = await _repo.getAllCatalogTests();
      setState(() { _catalogTests = tests; _catalogLoading = false; });
    } catch (e) {
      setState(() => _catalogLoading = false);
    }
  }

  Future<void> _searchPatients(String query) async {
    if (query.length < 2) {
      setState(() => _patientResults = []);
      return;
    }
    setState(() => _searchingPatients = true);
    try {
      final response = await ApiClient.instance
          .get('/patients/', queryParameters: {'search': query, 'page_size': 10});
      final results = (response.data['results'] as List?) ?? [];
      setState(() {
        _patientResults = results
            .map<Map<String, dynamic>>((p) => {
                  'id': p['id'],
                  'name':
                      '${p['user']?['first_name'] ?? ''} ${p['user']?['last_name'] ?? ''}'
                          .trim(),
                  'patient_number': p['patient_number'] ?? '',
                })
            .toList();
      });
    } catch (_) {}
    if (mounted) setState(() => _searchingPatients = false);
  }

  void _onPatientSearchChanged(String value) {
    if (_selectedPatientId != null && value != _selectedPatientName) {
      _selectedPatientId = null;
      _selectedPatientName = null;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchPatients(value);
    });
  }

  void _selectPatient(Map<String, dynamic> patient) {
    setState(() {
      _selectedPatientId = patient['id'] as int;
      _selectedPatientName = patient['name'] as String;
      _patientSearchCtrl.text = _selectedPatientName!;
      _patientResults = [];
    });
  }

  Future<void> _loadOrder() async {
    setState(() => _initialLoading = true);
    try {
      final o = await _repo.getOrder(int.parse(widget.orderId!));
      _selectedPatientId = o.patientId;
      _selectedPatientName = 'Patient #${o.patientId}';
      _patientSearchCtrl.text = _selectedPatientName!;
      _notesCtrl.text = o.clinicalNotes ?? '';
      _priority = o.priority;
      _status = o.status;
      _isHomeCollection = o.isHomeCollection;
      _selectedTestIds = o.testIds?.toList() ?? [];
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
    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please search and select a patient')),
      );
      return;
    }
    if (_selectedTestIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one test')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final data = {
        'patient': _selectedPatientId,
        'test_ids': _selectedTestIds,
        'priority': _priority,
        'status': _status,
        'clinical_notes': _notesCtrl.text,
        'is_home_collection': _isHomeCollection,
      };
      if (_isEditing) {
        await _repo.updateOrder(int.parse(widget.orderId!), data);
      } else {
        await _repo.createOrder(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEditing ? 'Order updated' : 'Order created')));
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
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 8),
                Text(
                  _isEditing ? 'Edit Lab Order' : 'New Lab Order',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Basic info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order Details',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    // Patient search
                    TextFormField(
                      controller: _patientSearchCtrl,
                      decoration: InputDecoration(
                        labelText: 'Search patient by name...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchingPatients
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2)))
                            : _selectedPatientId != null
                                ? Icon(Icons.check_circle, color: AppColors.success)
                                : null,
                      ),
                      onChanged: _onPatientSearchChanged,
                      validator: (_) => _selectedPatientId == null
                          ? 'Please search and select a patient'
                          : null,
                    ),
                    if (_patientResults.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _patientResults.length,
                          itemBuilder: (context, index) {
                            final p = _patientResults[index];
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                child: Text(
                                  ((p['name'] as String?) ?? '?').characters.first.toUpperCase(),
                                  style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12),
                                ),
                              ),
                              title: Text(p['name'] as String? ?? ''),
                              subtitle: Text(
                                'ID: ${p['id']} • ${p['patient_number']}',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              onTap: () => _selectPatient(p),
                            );
                          },
                        ),
                      ),
                    if (_selectedPatientId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Chip(
                          avatar: Icon(Icons.person, size: 16, color: AppColors.primary),
                          label: Text('$_selectedPatientName (ID: $_selectedPatientId)'),
                          onDeleted: () => setState(() {
                            _selectedPatientId = null;
                            _selectedPatientName = null;
                            _patientSearchCtrl.clear();
                          }),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: 200,
                          child: DropdownButtonFormField<String>(
                            initialValue: _priority,
                            decoration: const InputDecoration(labelText: 'Priority'),
                            items: _priorities
                                .map((t) =>
                                    DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _priority = v ?? 'routine'),
                          ),
                        ),
                        if (_isEditing)
                          SizedBox(
                            width: 200,
                            child: DropdownButtonFormField<String>(
                              initialValue: _status,
                              decoration: const InputDecoration(labelText: 'Status'),
                              items: _statuses
                                  .map((t) =>
                                      DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _status = v ?? 'pending'),
                            ),
                          ),
                        SizedBox(
                          width: 200,
                          child: SwitchListTile(
                            title: const Text('Home Collection'),
                            value: _isHomeCollection,
                            onChanged: (v) =>
                                setState(() => _isHomeCollection = v),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: TextFormField(
                            controller: _notesCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Clinical Notes'),
                            maxLines: 3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Test selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Select Tests',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        if (_selectedTestIds.isNotEmpty)
                          Text('${_selectedTestIds.length} selected',
                              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_catalogLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_catalogTests.isEmpty)
                      Center(
                        child: Text('No tests available in catalog.',
                            style: TextStyle(color: AppColors.textSecondary)),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _catalogTests.map((test) {
                          final selected = _selectedTestIds.contains(test.id);
                          return FilterChip(
                            label: Text(
                              '${test.code} - ${test.name}',
                              style: TextStyle(
                                fontSize: 13,
                                color: selected ? Colors.white : null,
                              ),
                            ),
                            selected: selected,
                            selectedColor: AppColors.primary,
                            checkmarkColor: Colors.white,
                            onSelected: (v) {
                              setState(() {
                                if (v) {
                                  _selectedTestIds.add(test.id);
                                } else {
                                  _selectedTestIds.remove(test.id);
                                }
                              });
                            },
                          );
                        }).toList(),
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
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_isEditing ? 'Update Order' : 'Create Order'),
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
